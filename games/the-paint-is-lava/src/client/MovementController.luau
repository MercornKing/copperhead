--!strict
--[[
	MovementController: sprint, wall-run and grapple (Direction §4).

	Everything runs on the owning client for zero-latency feel (Roblox gives each client
	physics ownership of its own character). The server is told the movement state and the
	grapple anchor so it can apply the paint rule to them: hostile walls hurt wall-runners,
	hostile anchors hurt anyone hanging from them.

	Chains are the point: jump -> wall-run -> wall-jump -> grapple -> release -> aerial shot.

	Controls (keyboard / gamepad / touch):
		Shift / L3        sprint
		Space / A         jump; during a wall-run, wall-jump; while grappling, release + hop
		E / L2 / button   grapple (hold); release to let go
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tuning = require(Shared.Config.Tuning)
local Net = require(Shared.Net)

local player = Players.LocalPlayer
local WR = Tuning.Movement.WallRun
local GR = Tuning.Movement.Grapple

local MovementController = {}

type Mode = "None" | "Air" | "WallRun" | "Grapple"

local humanoid: Humanoid? = nil
local root: BasePart? = nil
local mode: Mode = "None"
local reportedMode: Mode = "None"
local sprinting = false
local speedMultiplier = 1

-- wall-run
local wallNormal = Vector3.zero
local wallPart: BasePart? = nil
local wallStart = 0
local lastWallPart: BasePart? = nil
local lastWallEnd = 0
local runVelocity: LinearVelocity? = nil
local cameraRoll = 0
local targetRoll = 0

-- grapple
local rope: RopeConstraint? = nil
local anchorAttachment: Attachment? = nil
local ropeBeam: Beam? = nil
local grappleStart = 0
local lastGrappleEnd = 0
local grappleHeld = false

local arenaParams = RaycastParams.new()
arenaParams.FilterType = Enum.RaycastFilterType.Include

function MovementController.Mode(): Mode
	return mode
end

-- WeaponController sets this from the held weapon's MoveSpeedMultiplier.
function MovementController.SetSpeedMultiplier(m: number)
	speedMultiplier = m
end

local function report()
	if mode ~= reportedMode then
		reportedMode = mode
		Net.Event("MoveState"):FireServer(mode)
	end
end

local function airborne(): boolean
	local h = humanoid
	if not h then
		return false
	end
	local s = h:GetState()
	return h.FloorMaterial == Enum.Material.Air
		or s == Enum.HumanoidStateType.Freefall
		or s == Enum.HumanoidStateType.Jumping
end

-- Wall-run ------------------------------------------------------------------------------

local function stopWallRun()
	if runVelocity then
		runVelocity:Destroy()
		runVelocity = nil
	end
	if mode == "WallRun" then
		mode = if airborne() then "Air" else "None"
		lastWallPart = wallPart
		lastWallEnd = os.clock()
	end
	wallPart = nil
	targetRoll = 0
end

local function findWall(): (RaycastResult?, number)
	local r = root
	if not r then
		return nil, 0
	end
	local right = r.CFrame.RightVector
	for _, side in { 1, -1 } do
		local hit = workspace:Raycast(r.Position, right * side * WR.DetectDistance, arenaParams)
		if hit and math.abs(hit.Normal.Y) < 0.25 then
			return hit, side
		end
	end
	return nil, 0
end

local function tryStartWallRun()
	local r, h = root, humanoid
	if not r or not h or mode ~= "Air" then
		return
	end
	-- Must be pushing forward and already moving.
	local flatVel = Vector3.new(r.AssemblyLinearVelocity.X, 0, r.AssemblyLinearVelocity.Z)
	if flatVel.Magnitude < WR.MinEntrySpeed or h.MoveDirection.Magnitude < 0.5 then
		return
	end
	local hit, side = findWall()
	if not hit then
		return
	end
	local part = hit.Instance :: BasePart
	if part == lastWallPart and os.clock() - lastWallEnd < WR.ReattachCooldown * 4 then
		return
	end
	if os.clock() - lastWallEnd < WR.ReattachCooldown then
		return
	end

	wallNormal = Vector3.new(hit.Normal.X, 0, hit.Normal.Z).Unit
	wallPart = part
	wallStart = os.clock()
	mode = "WallRun"
	targetRoll = -side * math.rad(WR.CameraTiltDegrees)

	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = r:FindFirstChild("RootAttachment") :: Attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.MaxForce = 1e6
	lv.Parent = r
	runVelocity = lv
end

local function updateWallRun()
	local r, h, lv = root, humanoid, runVelocity
	if not r or not h or not lv then
		stopWallRun()
		return
	end
	local hit = findWall()
	local timeUp = os.clock() - wallStart > WR.MaxDuration
	if not hit or timeUp or not airborne() or h.MoveDirection.Magnitude < 0.3 then
		stopWallRun()
		return
	end
	wallNormal = Vector3.new(hit.Normal.X, 0, hit.Normal.Z).Unit
	-- Run along the wall in whichever direction we're already heading.
	local along = r.AssemblyLinearVelocity - wallNormal * r.AssemblyLinearVelocity:Dot(wallNormal)
	along = Vector3.new(along.X, 0, along.Z)
	if along.Magnitude < 0.1 then
		along = r.CFrame.LookVector - wallNormal * r.CFrame.LookVector:Dot(wallNormal)
	end
	along = along.Unit
	lv.VectorVelocity = along * WR.Speed - wallNormal * 2 + Vector3.new(0, -WR.SinkSpeed, 0)
end

local function wallJump()
	local r = root
	if not r then
		return
	end
	local along = r.AssemblyLinearVelocity
	along = Vector3.new(along.X, 0, along.Z)
	stopWallRun()
	r.AssemblyLinearVelocity = wallNormal * WR.JumpOffSpeed + Vector3.new(0, WR.JumpUpSpeed, 0) + along * 0.8
	mode = "Air"
end

-- Grapple -------------------------------------------------------------------------------

local function stopGrapple(hop: boolean)
	if rope then
		rope:Destroy()
		rope = nil
	end
	if anchorAttachment then
		anchorAttachment:Destroy()
		anchorAttachment = nil
	end
	if ropeBeam then
		ropeBeam:Destroy()
		ropeBeam = nil
	end
	if mode == "Grapple" then
		mode = "Air"
		lastGrappleEnd = os.clock()
		Net.Event("GrappleRelease"):FireServer()
		local r = root
		if hop and r then
			r.AssemblyLinearVelocity += Vector3.new(0, 30, 0)
		end
	end
end

local function startGrapple()
	local r, h = root, humanoid
	local camera = workspace.CurrentCamera
	if not r or not h or not camera or h.Health <= 0 then
		return
	end
	if os.clock() - lastGrappleEnd < GR.Cooldown or mode == "Grapple" then
		return
	end
	local origin = camera.CFrame.Position
	local hit = workspace:Raycast(origin, camera.CFrame.LookVector * GR.Range, arenaParams)
	if not hit then
		return
	end
	stopWallRun()

	local anchor = Instance.new("Attachment")
	anchor.Name = "LocalGrappleAnchor"
	anchor.WorldPosition = hit.Position
	anchor.Parent = workspace.Terrain
	anchorAttachment = anchor

	local rootAttachment = r:FindFirstChild("RootAttachment") :: Attachment
	local c = Instance.new("RopeConstraint")
	c.Attachment0 = rootAttachment
	c.Attachment1 = anchor
	c.Length = (hit.Position - r.Position).Magnitude
	c.WinchEnabled = true
	c.WinchTarget = GR.MinLength
	c.WinchSpeed = GR.ReelSpeed
	c.WinchForce = GR.ReelForce
	c.WinchResponsiveness = 60
	c.Visible = false
	c.Parent = r
	rope = c

	local beam = Instance.new("Beam")
	beam.Attachment0 = rootAttachment
	beam.Attachment1 = anchor
	beam.Width0 = 0.15
	beam.Width1 = 0.15
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(Color3.fromRGB(250, 250, 255))
	beam.Parent = anchor
	ropeBeam = beam

	-- Lift off so the humanoid's ground friction doesn't fight the winch.
	h:ChangeState(Enum.HumanoidStateType.Freefall)
	r.AssemblyLinearVelocity += Vector3.new(0, 12, 0)

	mode = "Grapple"
	grappleStart = os.clock()
	Net.Event("GrappleAttach"):FireServer(hit.Instance, hit.Position, hit.Normal)
end

-- Input ---------------------------------------------------------------------------------

local function onGrappleAction(_name: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		grappleHeld = true
		startGrapple()
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		grappleHeld = false
		stopGrapple(false)
	end
	return Enum.ContextActionResult.Sink
end

local function onSprintAction(_name: string, state: Enum.UserInputState)
	sprinting = state == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Pass
end

local function onJumpRequest()
	if mode == "WallRun" then
		wallJump()
	elseif mode == "Grapple" then
		stopGrapple(true)
	end
end

local function bindCharacter(newCharacter: Model)
	stopWallRun()
	stopGrapple(false)
	humanoid = newCharacter:WaitForChild("Humanoid") :: Humanoid
	root = newCharacter:WaitForChild("HumanoidRootPart") :: BasePart
	mode = "None"
	reportedMode = "None"
	local h = humanoid :: Humanoid
	h.Died:Connect(function()
		stopWallRun()
		stopGrapple(false)
	end)
end

local function step(_dt: number)
	local h, r = humanoid, root
	if not h or not r or h.Health <= 0 then
		return
	end

	local base = if sprinting and h.MoveDirection.Magnitude > 0
		then Tuning.Movement.SprintSpeed
		else Tuning.Movement.WalkSpeed
	h.WalkSpeed = base * speedMultiplier

	if mode == "Grapple" then
		local attached = os.clock() - grappleStart
		if not grappleHeld or attached > GR.MaxAttachSeconds then
			stopGrapple(false)
		end
	elseif mode == "WallRun" then
		updateWallRun()
	else
		mode = if airborne() then "Air" else "None"
		if mode == "Air" then
			tryStartWallRun()
		end
	end
	report()
end

local function tiltCamera(dt: number)
	cameraRoll += (targetRoll - cameraRoll) * math.min(1, dt * 10)
	local camera = workspace.CurrentCamera
	if camera and math.abs(cameraRoll) > 0.001 then
		camera.CFrame *= CFrame.Angles(0, 0, cameraRoll)
	end
end

function MovementController.Init()
	task.spawn(function()
		local arena = workspace:WaitForChild("Arena")
		arenaParams.FilterDescendantsInstances = { arena }
	end)

	player.CharacterAdded:Connect(bindCharacter)
	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end

	ContextActionService:BindAction("Grapple", onGrappleAction, true, Enum.KeyCode.E, Enum.KeyCode.ButtonL2)
	ContextActionService:SetTitle("Grapple", "Hook")
	ContextActionService:SetPosition("Grapple", UDim2.new(1, -170, 1, -150))
	ContextActionService:BindAction("Sprint", onSprintAction, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	UserInputService.JumpRequest:Connect(onJumpRequest)

	-- The server draws everyone's rope for other players; we already draw ours locally.
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "GrappleRope_" .. player.UserId then
			for _, d in child:GetDescendants() do
				if d:IsA("Beam") then
					d.Enabled = false
				end
			end
		end
	end)

	RunService.Heartbeat:Connect(step)
	RunService:BindToRenderStep("WallRunTilt", Enum.RenderPriority.Camera.Value + 1, tiltCamera)
end

return MovementController

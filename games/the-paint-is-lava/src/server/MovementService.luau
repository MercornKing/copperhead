--!strict
--[[
	MovementService: the server's view of client-driven movement.

	Roblox simulates each character's physics on its owner's client, so wall-running and
	grappling run client-side for responsiveness (client/MovementController). The server:
		- records each player's movement state (for hazard checks, stats, animations),
		- validates and records grapple anchors, so HazardService can damage players
		  hooked onto hostile paint,
		- shows everyone else the grapple rope,
		- measures wall-run distance and grapple count for achievements.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tuning = require(Shared.Config.Tuning)
local Net = require(Shared.Net)

local MovementService = {}

local S: any
local arena: Instance
local arenaParams = RaycastParams.new()
arenaParams.FilterType = Enum.RaycastFilterType.Include

export type Grapple = {
	Part: BasePart,
	Position: Vector3,
	Normal: Vector3,
	Since: number,
	Visual: Instance?,
	Distance: number, -- how far away the anchor was when attached
}

local VALID_STATES = { None = true, Air = true, WallRun = true, Grapple = true }

local states: { [Player]: string } = {}
local grapples: { [Player]: Grapple } = {}
local lastAttach: { [Player]: number } = {}
local lastPos: { [Player]: Vector3 } = {}
local wallRunCarry: { [Player]: number } = {}
local lastStateMsg: { [Player]: number } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Server-side check: nothing to stand on just below the character.
local function airborneOnServer(root: BasePart): boolean
	return workspace:Raycast(root.Position, Vector3.new(0, -4.5, 0), arenaParams) == nil
end

-- Server-side check: a wall close beside the character (as a wall-run needs).
local function wallBeside(root: BasePart): boolean
	local reach = root.CFrame.RightVector * (Tuning.Movement.WallRun.DetectDistance + 1)
	for _, dir in { reach, -reach } do
		local hit = workspace:Raycast(root.Position, dir, arenaParams)
		if hit and math.abs(hit.Normal.Y) < 0.3 then
			return true
		end
	end
	return false
end

function MovementService.StateOf(player: Player): string
	return states[player] or "None"
end

function MovementService.GrappleOf(player: Player): Grapple?
	return grapples[player]
end

-- Airborne, wall-running or grappling: counts toward "aerial" achievements. The client's
-- claim alone is not trusted; the server confirms there is no ground under them.
function MovementService.IsAerial(player: Player): boolean
	if grapples[player] then
		return true
	end
	local s = states[player]
	local root = rootOf(player)
	return (s == "Air" or s == "WallRun") and root ~= nil and airborneOnServer(root)
end

local function setState(player: Player, state: string)
	states[player] = state
	local character = player.Character
	if character then
		character:SetAttribute("MoveState", state)
	end
end

local function clearGrapple(player: Player)
	local g = grapples[player]
	if g then
		grapples[player] = nil
		if g.Visual then
			g.Visual:Destroy()
		end
		-- Only real grapples count toward achievements: a proper distance, held a moment.
		if g.Distance >= 10 and os.clock() - g.Since >= 0.5 and player.Parent == Players then
			S.Progression.AddStat(player, "Grapples", 1)
		end
	end
end

local function makeRopeVisual(player: Player, position: Vector3): Instance?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local holder = Instance.new("Folder")
	holder.Name = "GrappleRope_" .. player.UserId
	holder:SetAttribute("OwnerUserId", player.UserId)

	local a0 = Instance.new("Attachment")
	a0.Name = "GrappleFrom"
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "GrappleTo"
	a1.WorldPosition = position
	a1.Parent = workspace.Terrain

	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 0.18
	beam.Width1 = 0.18
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(Color3.fromRGB(250, 250, 255))
	beam.LightEmission = 0.3
	beam.Segments = 1
	beam:SetAttribute("OwnerUserId", player.UserId)
	beam.Parent = holder

	-- Clean both attachments up with the folder.
	holder.Destroying:Connect(function()
		a0:Destroy()
		a1:Destroy()
	end)
	holder.Parent = workspace
	return holder
end

local function onAttach(player: Player, part: unknown, position: unknown, normal: unknown)
	if typeof(part) ~= "Instance" or typeof(position) ~= "Vector3" or typeof(normal) ~= "Vector3" then
		return
	end
	local p = part :: Instance
	if not p:IsA("BasePart") or not p:IsDescendantOf(arena) then
		return
	end
	local now = os.clock()
	if now - (lastAttach[player] or 0) < Tuning.Movement.Grapple.Cooldown * 0.8 then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local pos = position :: Vector3
	if (pos - root.Position).Magnitude > Tuning.Movement.Grapple.Range + 12 then
		return
	end
	-- The anchor must actually be on (or right at) the claimed part.
	local localPos = (p :: BasePart).CFrame:PointToObjectSpace(pos)
	local half = (p :: BasePart).Size / 2 + Vector3.new(1, 1, 1)
	if math.abs(localPos.X) > half.X or math.abs(localPos.Y) > half.Y or math.abs(localPos.Z) > half.Z then
		return
	end

	local n = normal :: Vector3
	if n.Magnitude ~= n.Magnitude or n.Magnitude < 0.5 then
		return
	end
	clearGrapple(player)
	lastAttach[player] = now
	grapples[player] = {
		Part = p :: BasePart,
		Position = pos,
		Normal = n.Unit,
		Since = now,
		Visual = makeRopeVisual(player, pos),
		Distance = (pos - root.Position).Magnitude,
	}
	setState(player, "Grapple")
end

local function onRelease(player: Player)
	clearGrapple(player)
	if states[player] == "Grapple" then
		setState(player, "Air")
	end
end

local function onMoveState(player: Player, state: unknown)
	if typeof(state) ~= "string" or not VALID_STATES[state :: string] then
		return
	end
	local now = os.clock()
	if now - (lastStateMsg[player] or 0) < 0.05 then
		return
	end
	lastStateMsg[player] = now
	if state ~= "Grapple" and grapples[player] then
		clearGrapple(player)
	end
	setState(player, state :: string)
end

function MovementService.Init(services: any, arenaRoot: Instance)
	S = services
	arena = arenaRoot
	arenaParams.FilterDescendantsInstances = { arenaRoot }
end

function MovementService.Start()
	Net.Event("GrappleAttach").OnServerEvent:Connect(onAttach)
	Net.Event("GrappleRelease").OnServerEvent:Connect(onRelease)
	Net.Event("MoveState").OnServerEvent:Connect(onMoveState)

	local function reset(player: Player)
		clearGrapple(player)
		states[player] = "None"
		lastPos[player] = nil
	end

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			reset(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		reset(player)
		states[player] = nil
		lastAttach[player] = nil
		wallRunCarry[player] = nil
		lastStateMsg[player] = nil
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.2 then
			return
		end
		local window = elapsed
		elapsed = 0
		local now = os.clock()
		for player, state in states do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local pos = root.Position
				local prev = lastPos[player]
				lastPos[player] = pos
				-- Count wall-run distance only when the server also sees a wall and no floor.
				if state == "WallRun" and prev and wallBeside(root) and airborneOnServer(root) then
					-- Cap per-window distance at a plausible wall-run speed to resist spoofing.
					local d = math.min((pos - prev).Magnitude, Tuning.Movement.WallRun.Speed * window * 1.5)
					wallRunCarry[player] = (wallRunCarry[player] or 0) + d
					if wallRunCarry[player] >= 10 then
						S.Progression.AddStat(player, "WallRunDistance", math.floor(wallRunCarry[player]))
						wallRunCarry[player] -= math.floor(wallRunCarry[player])
					end
				end
			end
			local g = grapples[player]
			if g and now - g.Since > Tuning.Movement.Grapple.MaxAttachSeconds + 1 then
				onRelease(player)
			end
		end
	end)
end

return MovementService

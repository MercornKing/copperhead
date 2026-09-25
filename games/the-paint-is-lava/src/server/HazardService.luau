--!strict
--[[
	HazardService: "touch enemy paint and you take damage" (Direction §2).

	Every tick the server probes around each living player with short rays: down (feet),
	up (head), and a ring at chest and shin height (walls). Add the grapple anchor if they
	are hooked on. If ANY touched cell is hostile, they take damage at one flat rate.

	There are deliberately no per-verb rules. Walking, landing, wall-running, brushing a
	ceiling and hanging from a grapple are all just "touching a surface", so they all
	follow the same rule without special cases.

	Damage is credited to whoever last painted the cell, so traps earn eliminations.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tuning = require(Shared.Config.Tuning)
local Factions = require(Shared.Paint.Factions)

local HazardService = {}

local S: any
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include

local RING = 8
local ringDirs: { Vector3 } = {}
for i = 0, RING - 1 do
	local a = i / RING * 2 * math.pi
	table.insert(ringDirs, Vector3.new(math.cos(a), 0, math.sin(a)))
end

-- Returns (touchingHostile, creditedPainter).
function HazardService.Probe(player: Player): (boolean, Player?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not humanoid or not root or humanoid.Health <= 0 then
		return false, nil
	end
	local faction = S.Match.FactionOf(player)
	local slack = Tuning.Hazard.ContactSlack
	local pos = root.Position
	local halfHeight = root.Size.Y / 2

	local hostile, painter = false, nil :: Player?
	local function check(result: RaycastResult?)
		if not result or hostile then
			return
		end
		local owner, cell = S.Paint.FactionAtHit(result.Instance :: BasePart, result.Position, result.Normal)
		if cell and Factions.Hurts(owner, faction) then
			hostile = true
			painter = S.Paint.PainterOf(cell)
		end
	end

	-- Feet and head. The foot ray has a floor so it also works on rigs with HipHeight 0 (R6).
	local footReach = math.max(humanoid.HipHeight + halfHeight, 3) + slack
	check(workspace:Raycast(pos, Vector3.new(0, -footReach, 0), params))
	check(workspace:Raycast(pos, Vector3.new(0, halfHeight + 1.6 + slack, 0), params))

	-- Walls at chest and shin height (covers wall-running on either side).
	local shin = pos - Vector3.new(0, humanoid.HipHeight * 0.6, 0)
	local reach = root.Size.X / 2 + 0.4 + slack
	for i, dir in ringDirs do
		check(workspace:Raycast(pos, dir * reach, params))
		if i % 2 == 1 then
			check(workspace:Raycast(shin, dir * reach, params))
		end
	end

	-- Wall-running latches onto walls from further out than the body ring reaches, so
	-- probe sideways to the full wall-run detection distance while running.
	if S.Movement.StateOf(player) == "WallRun" then
		local side = root.CFrame.RightVector * (Tuning.Movement.WallRun.DetectDistance + slack)
		check(workspace:Raycast(pos, side, params))
		check(workspace:Raycast(pos, -side, params))
	end

	-- Grappling onto hostile paint hurts for as long as you stay attached.
	local grapple = S.Movement.GrappleOf(player)
	if grapple and not hostile then
		local owner, cell = S.Paint.FactionAtHit(grapple.Part, grapple.Position, grapple.Normal)
		if cell and Factions.Hurts(owner, faction) then
			hostile = true
			painter = S.Paint.PainterOf(cell)
		end
	end

	return hostile, painter
end

function HazardService.Init(services: any, paintableFolder: Instance)
	S = services
	params.FilterDescendantsInstances = { paintableFolder }
end

function HazardService.Start()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < Tuning.Hazard.TickInterval then
			return
		end
		local tick = elapsed
		elapsed = 0
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character and S.Match.FactionOf(player) ~= 0 then
				local hostile, painter = HazardService.Probe(player)
				if character:GetAttribute("InHazard") ~= hostile then
					character:SetAttribute("InHazard", hostile)
				end
				if hostile then
					local attacker = painter
					if attacker and not Factions.AreEnemies(S.Match.FactionOf(attacker), S.Match.FactionOf(player)) then
						attacker = nil -- painter since switched sides; nobody gets credit
					end
					S.Combat.DealDamage(player, Tuning.Hazard.DamagePerSecond * tick, attacker, "Hazard", "Paint", nil)
				end
			end
		end
	end)
end

return HazardService

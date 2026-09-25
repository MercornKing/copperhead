--!strict
--[[
	DevTools: Studio-only helpers for solo playtesting. Inert on live servers.

	Hostile painter: while you are alone in a Studio playtest, splashes environment-owned
	(always hostile) paint on random floors and walls so the core rule can be felt:
	walk on it, wall-run along it, grapple onto it, and it hurts.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tuning = require(Shared.Config.Tuning)
local Factions = require(Shared.Paint.Factions)

local DevTools = {}

local S: any
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include

local function splashSomewhere()
	local target: RaycastResult? = nil
	if math.random() < 0.6 then
		-- A floor or platform, straight down from the sky.
		local origin = Vector3.new(math.random(-110, 110), 80, math.random(-75, 75))
		target = workspace:Raycast(origin, Vector3.new(0, -120, 0), params)
	else
		-- A wall, sideways from somewhere in the middle of the arena.
		local angle = math.random() * 2 * math.pi
		local origin = Vector3.new(math.random(-40, 40), math.random(4, 16), math.random(-30, 30))
		target = workspace:Raycast(origin, Vector3.new(math.cos(angle), 0, math.sin(angle)) * 150, params)
	end
	if target then
		S.Paint.PaintSphere(target.Position, 7, Factions.ENVIRONMENT, nil, target.Normal)
	end
end

function DevTools.Init(services: any, paintableFolder: Instance)
	S = services
	params.FilterDescendantsInstances = { paintableFolder }
end

function DevTools.Start()
	if not RunService:IsStudio() or not Tuning.Dev.StudioHostilePainter then
		return
	end
	warn("[DevTools] Studio hostile painter is ON (solo playtests only). Disable in Tuning.Dev.")
	task.spawn(function()
		while true do
			task.wait(Tuning.Dev.HostilePaintInterval)
			local phase = S.Match.Phase()
			if #Players:GetPlayers() == 1 and (phase == "Active" or phase == "Intermission") then
				splashSomewhere()
			end
		end
	end)
end

return DevTools

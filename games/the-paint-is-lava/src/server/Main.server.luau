--!strict
--[[
	Server entry point. Builds the arena, then initialises and starts every service.
	Services find each other through the shared `S` table, so there are no require cycles.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Validate = require(Shared.Validate)
local Tuning = require(Shared.Config.Tuning)
local Weapons = require(Shared.Config.Weapons)
local Cosmetics = require(Shared.Config.Cosmetics)
local Characters = require(Shared.Config.Characters)
local Achievements = require(Shared.Config.Achievements)
local Season = require(Shared.Config.Season)

local ArenaBuilder = require(script.Parent.ArenaBuilder)
local CanvasYard = require(script.Parent.Maps.CanvasYard)

-- Refuse to run on a catalog that breaks the non-negotiables (cosmetics only, readable
-- paint, every weapon paints). The same checks run in the offline test suite.
local problems = {}
for _, list in
	{
		Validate.Cosmetics(Cosmetics, Achievements, Season),
		Validate.Characters(Characters, Cosmetics),
		Validate.Weapons(Weapons, Tuning.Loadout),
	}
do
	for _, p in list do
		table.insert(problems, p)
	end
end
if #problems > 0 then
	error("[ThePaintIsLava] config validation failed:\n  " .. table.concat(problems, "\n  "))
end

Net.Init()
local built = ArenaBuilder.Build(CanvasYard)

local S = {
	PlayerData = require(script.Parent.PlayerData),
	Paint = require(script.Parent.PaintService),
	Match = require(script.Parent.MatchService),
	Combat = require(script.Parent.CombatService),
	Hazard = require(script.Parent.HazardService),
	Movement = require(script.Parent.MovementService),
	Progression = require(script.Parent.Progression),
	Character = require(script.Parent.CharacterService),
	DevTools = require(script.Parent.DevTools),
}

S.PlayerData.Init()
S.Paint.Init(built.Paintable)
S.Match.Init(S, CanvasYard)
S.Combat.Init(S)
S.Hazard.Init(S, built.Paintable)
S.Movement.Init(S, built.Root)
S.Progression.Init(S)
S.Character.Init(S)
S.DevTools.Init(S, built.Paintable)

-- Start order: listeners first, then the match loop (which spawns players).
S.Paint.Start()
S.Progression.Start()
S.Character.Start()
S.Combat.Start()
S.Hazard.Start()
S.Movement.Start()
S.PlayerData.Start()
S.Match.Start()
S.DevTools.Start()

print("[ThePaintIsLava] server ready on " .. CanvasYard.Name)

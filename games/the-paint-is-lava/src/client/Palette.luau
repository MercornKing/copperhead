--!strict
--[[
	Palette: perspective-relative colours (Direction §9).

	For THIS viewer: paint owned by my faction is Safe (green), every other faction's paint
	is Danger (red). Two players looking at the same wall see opposite colours, and both
	are right about whether it hurts them.

	The colour-blind palette keeps the same meaning with blue/orange.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tuning = require(Shared.Config.Tuning)
local Factions = require(Shared.Paint.Factions)
local Signal = require(Shared.Signal)

local player = Players.LocalPlayer

local Palette = {}
-- Fires when the viewer's faction or palette choice changes (everything must recolour).
Palette.Changed = Signal.new() :: Signal.Signal<>

function Palette.MyFaction(): number
	return (player:GetAttribute("Faction") :: number?) or 0
end

function Palette.Colors(): { Safe: Color3, Danger: Color3 }
	if player:GetAttribute("ColorblindPalette") == true then
		return Tuning.Colors.ColorblindSafe
	end
	return Tuning.Colors.Standard
end

function Palette.ForRelation(relation: Factions.Relation): Color3
	local c = Palette.Colors()
	if relation == "Friendly" then
		return c.Safe
	elseif relation == "Hostile" then
		return c.Danger
	end
	return Tuning.Colors.Neutral
end

-- Colour of paint owned by `owner`, as seen by this player.
function Palette.ForFaction(owner: number): Color3
	return Palette.ForRelation(Factions.Relation(owner, Palette.MyFaction()))
end

function Palette.Init()
	player:GetAttributeChangedSignal("Faction"):Connect(function()
		Palette.Changed:Fire()
	end)
	player:GetAttributeChangedSignal("ColorblindPalette"):Connect(function()
		Palette.Changed:Fire()
	end)
end

return Palette

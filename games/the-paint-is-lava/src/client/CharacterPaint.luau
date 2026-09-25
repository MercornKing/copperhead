--!strict
--[[
	CharacterPaint: players visibly fill up with paint as they take hits (Direction §3, §13).
	No injury, no gore: a coloured overlay whose strength follows lost health, in the
	perspective colour of whoever painted them (your paint on an enemy looks green to you).
	Roblox renders at most 31 Highlights at once, which is plenty at playable lobby sizes.
]]

local Players = game:GetService("Players")

local Palette = require(script.Parent.Palette)

local CharacterPaint = {}

local tracked: { [Model]: Highlight } = {}

local function refresh(character: Model)
	local highlight = tracked[character]
	if not highlight then
		return
	end
	local level = (character:GetAttribute("PaintLevel") :: number?) or 0
	local by = (character:GetAttribute("PaintedBy") :: number?) or 0
	highlight.FillColor = Palette.ForFaction(by)
	highlight.FillTransparency = 1 - math.clamp(level, 0, 1) * 0.7
	highlight.Enabled = level > 0.03
end

local function track(character: Model)
	if tracked[character] then
		return
	end
	local h = Instance.new("Highlight")
	h.Name = "PaintCoat"
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Enabled = false
	h.Adornee = character
	h.Parent = character
	tracked[character] = h
	character:GetAttributeChangedSignal("PaintLevel"):Connect(function()
		refresh(character)
	end)
	character:GetAttributeChangedSignal("PaintedBy"):Connect(function()
		refresh(character)
	end)
	character.Destroying:Connect(function()
		tracked[character] = nil
	end)
	refresh(character)
end

function CharacterPaint.Init()
	local function onPlayer(p: Player)
		-- Your own coat shows as the screen-edge flash and health bar instead.
		if p == Players.LocalPlayer then
			return
		end
		p.CharacterAdded:Connect(track)
		if p.Character then
			track(p.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Palette.Changed:Connect(function()
		for character in tracked do
			refresh(character)
		end
	end)
end

return CharacterPaint

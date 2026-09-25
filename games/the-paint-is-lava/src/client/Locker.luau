--!strict
--[[
	Locker (press L): choose your character and cosmetics, see your season pass, and set
	accessibility options. Everything here is cosmetic; nothing changes how you play.
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared.Config.Cosmetics)
local Characters = require(Shared.Config.Characters)
local Achievements = require(Shared.Config.Achievements)
local Net = require(Shared.Net)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local Locker = {}

local CATEGORY_ORDER = {
	{ "CharacterSkin", "Character" },
	{ "Headwear", "Headwear" },
	{ "WeaponSkin", "Weapon skin" },
	{ "Brush", "Brush" },
	{ "Banner", "Banner" },
	{ "PaintEffect", "Splat style" },
	{ "Emote", "Emote" },
	{ "VictoryPose", "Victory pose" },
	{ "ProfileIcon", "Icon" },
}

local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(180, 185, 200),
	Rare = Color3.fromRGB(90, 160, 255),
	Epic = Color3.fromRGB(180, 110, 255),
	Legendary = Color3.fromRGB(255, 190, 50),
}

local gui: ScreenGui
local root: Frame
local grid: ScrollingFrame
local header: TextLabel
local passLabel: TextLabel
local passBar: Frame
local premiumButton: TextButton
local colorblindButton: TextButton
local profile: any = nil
local category = "CharacterSkin"

local achievementNames: { [string]: string } = {}
for _, a in Achievements do
	achievementNames[a.Id] = a.DisplayName
end
local characterBlurbs: { [string]: string } = {}
for _, c in Characters do
	characterBlurbs[c.Id] = c.Personality
end

local function unlockHint(item: Cosmetics.Cosmetic): string
	local u = item.Unlock
	if u.Source == "Achievement" then
		return "Achievement: " .. (achievementNames[u.Ref :: string] or "?")
	elseif u.Source == "FreePass" then
		return "Free pass tier " .. tostring(u.Ref)
	elseif u.Source == "PremiumPass" then
		return "Premium pass tier " .. tostring(u.Ref)
	elseif u.Source == "Purchase" then
		return if u.Ref == 0 then "Shop (coming soon)" else "Shop"
	end
	return ""
end

local function owns(id: string): boolean
	if not profile then
		return false
	end
	return table.find(profile.Owned, id) ~= nil
end

local function button(text: string, props: { [string]: any }): TextButton
	props.Text = text
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextSize = props.TextSize or 16
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(50, 54, 76)
	props.AutoButtonColor = true
	props.BorderSizePixel = 0
	local b = UI.new("TextButton", props)
	UI.corner(8).Parent = b
	return b
end

local function refreshGrid()
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local equipped = profile and profile.Equipped[category]
	for _, item in Cosmetics.List do
		if item.Category == category then
			local have = owns(item.Id)
			local card = button("", {
				Size = UDim2.fromOffset(170, 96),
				BackgroundColor3 = if item.Id == equipped
					then Color3.fromRGB(70, 90, 150)
					else Color3.fromRGB(38, 40, 58),
				Parent = grid,
			})
			UI.stroke(RARITY_COLORS[item.Rarity] or Color3.new(1, 1, 1), if item.Id == equipped then 3 else 1.5).Parent =
				card
			local swatch = item.Visual.Color or item.Visual.Torso or item.Visual.BristleColor
			if swatch then
				local s = UI.new("Frame", {
					Size = UDim2.fromOffset(18, 18),
					Position = UDim2.new(1, -26, 0, 8),
					BackgroundColor3 = swatch,
					BorderSizePixel = 0,
					Parent = card,
				})
				UI.corner(9).Parent = s
			end
			UI.label({
				Text = item.DisplayName,
				TextSize = 15,
				TextWrapped = true,
				Size = UDim2.new(1, -40, 0, 40),
				Position = UDim2.fromOffset(10, 6),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Parent = card,
			})
			UI.label({
				Text = if have
					then (if item.Id == equipped then "Equipped" else item.Rarity)
					else "🔒 " .. unlockHint(item),
				TextSize = 12,
				Font = Enum.Font.Gotham,
				TextWrapped = true,
				TextColor3 = if have then RARITY_COLORS[item.Rarity] else Color3.fromRGB(200, 200, 210),
				Size = UDim2.new(1, -20, 0, 34),
				Position = UDim2.new(0, 10, 1, -40),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = card,
			})
			card.Activated:Connect(function()
				if have then
					Net.Event("Equip"):FireServer(item.Category, item.Id)
				elseif item.Unlock.Source == "Purchase" and item.Unlock.Ref ~= 0 then
					MarketplaceService:PromptProductPurchase(player, item.Unlock.Ref :: number)
				end
			end)
		end
	end

	local note = ""
	if category == "CharacterSkin" then
		local skin = equipped and Cosmetics.ById[equipped]
		local blurb = skin and characterBlurbs[skin.Visual.Character]
		note = "All characters play identically." .. (if blurb then "  " .. blurb else "")
	elseif category == "WeaponSkin" or category == "Brush" then
		note = "Weapon looks apply on your next respawn."
	elseif category == "PaintEffect" then
		note = "Changes the shape of your splashes only. Paint is always green (yours) or red (theirs)."
	end
	header.Text = note
end

local function refreshPass()
	if not profile then
		return
	end
	local s = profile.Season
	passLabel.Text =
		string.format("%s · Tier %d / %d%s", s.Name, s.Tier, s.Tiers, if s.Premium then " · Premium" else "")
	passBar.Size = UDim2.fromScale(math.clamp((s.XP % s.XPPerTier) / s.XPPerTier, 0, 1), 1)
	premiumButton.Visible = s.PremiumAvailable and not s.Premium
	local cb = profile.Settings.ColorblindPalette == true
	colorblindButton.Text = "Colour-blind paint: " .. (if cb then "ON" else "OFF")
end

local function build()
	gui = UI.new(
		"ScreenGui",
		{ Name = "Locker", ResetOnSpawn = false, Enabled = false, Parent = player:WaitForChild("PlayerGui") }
	)
	root = UI.new("Frame", {
		Size = UDim2.fromOffset(820, 560),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(22, 24, 36),
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Parent = gui,
	})
	UI.corner(14).Parent = root
	UI.new("UISizeConstraint", { MaxSize = Vector2.new(820, 560), Parent = root })
	UI.new("UIScale", { Parent = root })

	-- A modal button frees the mouse from first-person lock while the Locker is open.
	button("✕", { Size = UDim2.fromOffset(36, 36), Position = UDim2.new(1, -46, 0, 10), Modal = true, Parent = root }).Activated:Connect(
		function()
			gui.Enabled = false
		end
	)
	UI.label({
		Text = "LOCKER",
		TextSize = 26,
		Size = UDim2.fromOffset(200, 36),
		Position = UDim2.fromOffset(20, 12),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = root,
	})

	local tabs = UI.new("Frame", {
		Size = UDim2.new(0, 160, 1, -130),
		Position = UDim2.fromOffset(20, 60),
		BackgroundTransparency = 1,
		Parent = root,
	})
	UI.new("UIListLayout", { Padding = UDim.new(0, 6), Parent = tabs })
	for _, entry in CATEGORY_ORDER do
		button(entry[2], { Size = UDim2.new(1, 0, 0, 36), Parent = tabs }).Activated:Connect(function()
			category = entry[1]
			refreshGrid()
		end)
	end

	header = UI.label({
		Text = "",
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextWrapped = true,
		Size = UDim2.new(1, -220, 0, 34),
		Position = UDim2.fromOffset(196, 56),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = root,
	})
	grid = UI.new("ScrollingFrame", {
		Size = UDim2.new(1, -216, 1, -170),
		Position = UDim2.fromOffset(196, 94),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = root,
	})
	UI.new(
		"UIGridLayout",
		{ CellSize = UDim2.fromOffset(170, 96), CellPadding = UDim2.fromOffset(10, 10), Parent = grid }
	)

	-- Season pass strip.
	local strip = UI.new("Frame", {
		Size = UDim2.new(1, -40, 0, 56),
		Position = UDim2.new(0, 20, 1, -66),
		BackgroundColor3 = Color3.fromRGB(34, 36, 52),
		BorderSizePixel = 0,
		Parent = root,
	})
	UI.corner(10).Parent = strip
	passLabel = UI.label({
		Text = "",
		TextSize = 16,
		Size = UDim2.new(0.5, 0, 0, 24),
		Position = UDim2.fromOffset(12, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = strip,
	})
	local back = UI.new("Frame", {
		Size = UDim2.new(0.5, -12, 0, 8),
		Position = UDim2.new(0, 12, 0, 36),
		BackgroundColor3 = Color3.fromRGB(60, 62, 80),
		BorderSizePixel = 0,
		Parent = strip,
	})
	passBar = UI.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(255, 200, 60),
		BorderSizePixel = 0,
		Parent = back,
	})
	premiumButton = button("Get Premium Pass", {
		Size = UDim2.fromOffset(170, 36),
		Position = UDim2.new(1, -380, 0.5, -18),
		BackgroundColor3 = Color3.fromRGB(200, 150, 30),
		Visible = false,
		Parent = strip,
	})
	premiumButton.Activated:Connect(function()
		if profile and profile.Season.PremiumGamePassId ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, profile.Season.PremiumGamePassId)
		end
	end)
	colorblindButton = button(
		"Colour-blind paint: OFF",
		{ Size = UDim2.fromOffset(190, 36), Position = UDim2.new(1, -200, 0.5, -18), Parent = strip }
	)
	colorblindButton.Activated:Connect(function()
		if profile then
			Net.Event("SetSetting"):FireServer("ColorblindPalette", not (profile.Settings.ColorblindPalette == true))
		end
	end)
end

function Locker.Toggle()
	gui.Enabled = not gui.Enabled
	if gui.Enabled then
		refreshGrid()
		refreshPass()
	end
end

function Locker.Init()
	build()
	Net.Event("ProfileSync").OnClientEvent:Connect(function(view: any)
		profile = view
		if gui.Enabled then
			refreshGrid()
		end
		refreshPass()
	end)
	ContextActionService:BindAction("Locker", function(_, state)
		if state == Enum.UserInputState.Begin then
			Locker.Toggle()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.L, Enum.KeyCode.ButtonSelect)
	ContextActionService:SetTitle("Locker", "Locker")
	ContextActionService:SetPosition("Locker", UDim2.new(0, 20, 0, 80))
end

return Locker

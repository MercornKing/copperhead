--!strict
--[[
	Hud: everything on screen during play.

		crosshair + hit marker         centre
		health, hazard warning         bottom-left / screen edges
		weapon, paint tank, bombs      bottom-right
		mode, timer, score             top-centre
		kill feed                      top-right
		toasts, results, respawn       centre panels
		controls hint                  bottom-centre

	The hazard warning is driven by the server's InHazard flag on your character, so it
	is exactly as true as the damage you're taking.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared.Config.Weapons)
local Net = require(Shared.Net)
local UI = require(script.Parent.UI)
local Palette = require(script.Parent.Palette)
local WeaponController = require(script.Parent.WeaponController)

local player = Players.LocalPlayer

local Hud = {}

local gui: ScreenGui
local state: Folder
local refs: { [string]: any } = {}
local hitMarkerT = 0
local damageFlashT = 0
local feed: { Frame } = {}

local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromRGB(20, 22, 34)

local function panel(props: { [string]: any }): Frame
	props.BackgroundColor3 = props.BackgroundColor3 or PANEL
	props.BackgroundTransparency = props.BackgroundTransparency or 0.35
	props.BorderSizePixel = 0
	local f = UI.new("Frame", props)
	UI.corner(10).Parent = f
	return f
end

local function build()
	gui = UI.new("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Hazard vignette: four edge gradients in the current danger colour.
	local vignette =
		UI.new("Frame", { Name = "Vignette", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	refs.vignetteEdges = {}
	for _, spec in
		{
			{ UDim2.fromScale(1, 0.18), UDim2.fromScale(0, 0), 90 },
			{ UDim2.fromScale(1, 0.18), UDim2.fromScale(0, 0.82), 270 },
			{ UDim2.fromScale(0.14, 1), UDim2.fromScale(0, 0), 0 },
			{ UDim2.fromScale(0.14, 1), UDim2.fromScale(0.86, 0), 180 },
		} :: { { any } }
	do
		local edge = UI.new("Frame", {
			Size = spec[1],
			Position = spec[2],
			BorderSizePixel = 0,
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			Parent = vignette,
		})
		UI.new("UIGradient", {
			Rotation = spec[3],
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
			Parent = edge,
		})
		table.insert(refs.vignetteEdges, edge)
	end
	refs.hazardText = UI.label({
		Text = "ENEMY PAINT!",
		TextSize = 30,
		Size = UDim2.new(0, 400, 0, 40),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.66, 0),
		Visible = false,
		Parent = gui,
	})

	-- Crosshair + hit marker.
	local cross = UI.new("Frame", {
		Name = "Crosshair",
		Size = UDim2.fromOffset(36, 36),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	for _, spec in
		{
			{ UDim2.fromOffset(2, 8), UDim2.new(0.5, -1, 0, 0) },
			{ UDim2.fromOffset(2, 8), UDim2.new(0.5, -1, 1, -8) },
			{ UDim2.fromOffset(8, 2), UDim2.new(0, 0, 0.5, -1) },
			{ UDim2.fromOffset(8, 2), UDim2.new(1, -8, 0.5, -1) },
			{ UDim2.fromOffset(4, 4), UDim2.new(0.5, -2, 0.5, -2) },
		}
	do
		UI.new(
			"Frame",
			{ Size = spec[1], Position = spec[2], BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = cross }
		)
	end
	refs.hitMarker = UI.label({
		Text = "✕",
		TextSize = 34,
		Size = UDim2.fromOffset(40, 40),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = gui,
	})

	-- Health.
	local healthPanel = panel({ Size = UDim2.fromOffset(300, 56), Position = UDim2.new(0, 24, 1, -80), Parent = gui })
	refs.healthLabel = UI.label({
		Text = "100",
		TextSize = 26,
		Size = UDim2.new(0, 60, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = healthPanel,
	})
	local barBack = UI.new("Frame", {
		Size = UDim2.new(1, -90, 0, 14),
		Position = UDim2.new(0, 76, 0.5, -7),
		BackgroundColor3 = Color3.fromRGB(60, 60, 70),
		BorderSizePixel = 0,
		Parent = healthPanel,
	})
	UI.corner(7).Parent = barBack
	refs.healthBar = UI.new(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = barBack }
	)
	UI.corner(7).Parent = refs.healthBar

	-- Weapon.
	local weaponPanel =
		panel({ Size = UDim2.fromOffset(300, 86), Position = UDim2.new(1, -324, 1, -110), Parent = gui })
	refs.weaponName = UI.label({
		Text = "",
		TextSize = 18,
		Size = UDim2.new(1, -24, 0, 24),
		Position = UDim2.fromOffset(12, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = weaponPanel,
	})
	refs.ammo = UI.label({
		Text = "",
		TextSize = 30,
		Size = UDim2.new(1, -24, 0, 34),
		Position = UDim2.fromOffset(12, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = weaponPanel,
	})
	refs.grenades = UI.label({
		Text = "",
		TextSize = 18,
		Size = UDim2.new(0, 120, 0, 24),
		Position = UDim2.new(1, -132, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = weaponPanel,
	})
	local reloadBack = UI.new("Frame", {
		Size = UDim2.new(1, -24, 0, 6),
		Position = UDim2.new(0, 12, 1, -14),
		BackgroundColor3 = Color3.fromRGB(60, 60, 70),
		BorderSizePixel = 0,
		Parent = weaponPanel,
	})
	refs.reloadBar = UI.new(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = reloadBack }
	)

	-- Match banner.
	local top = panel({
		Size = UDim2.fromOffset(460, 66),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Parent = gui,
	})
	refs.modeLabel = UI.label({
		Text = "",
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 6),
		Parent = top,
	})
	refs.scoreLabel = UI.label({
		Text = "",
		TextSize = 24,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 28),
		RichText = true,
		Parent = top,
	})

	-- Kill feed.
	refs.feed = UI.new("Frame", {
		Size = UDim2.fromOffset(340, 200),
		Position = UDim2.new(1, -356, 0, 12),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.new("UIListLayout", {
		Padding = UDim.new(0, 4),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = refs.feed,
	})

	-- Toast.
	refs.toast = panel({
		Size = UDim2.fromOffset(420, 70),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Visible = false,
		Parent = gui,
	})
	refs.toastTitle = UI.label({
		Text = "",
		TextSize = 20,
		Size = UDim2.new(1, -20, 0, 28),
		Position = UDim2.fromOffset(10, 8),
		Parent = refs.toast,
	})
	refs.toastBody = UI.label({
		Text = "",
		TextSize = 15,
		Font = Enum.Font.Gotham,
		Size = UDim2.new(1, -20, 0, 24),
		Position = UDim2.fromOffset(10, 38),
		Parent = refs.toast,
	})

	-- Centre message (respawn countdown, phase banners).
	refs.centre = UI.label({
		Text = "",
		TextSize = 28,
		Size = UDim2.new(0, 700, 0, 40),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Parent = gui,
	})

	-- Results.
	refs.results = panel({
		Size = UDim2.fromOffset(520, 380),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 0.12,
		Visible = false,
		Parent = gui,
	})
	refs.resultsTitle = UI.label({
		Text = "",
		TextSize = 34,
		Size = UDim2.new(1, 0, 0, 50),
		Position = UDim2.fromOffset(0, 14),
		Parent = refs.results,
	})
	refs.resultsBody = UI.label({
		Text = "",
		TextSize = 18,
		Font = Enum.Font.Gotham,
		RichText = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -40, 1, -80),
		Position = UDim2.fromOffset(20, 70),
		TextWrapped = true,
		Parent = refs.results,
	})

	-- Controls hint.
	UI.label({
		Text = "LMB fire · R reload · G bomb · E grapple · Shift sprint · Space wall-jump · 1-5 weapons · L locker",
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextTransparency = 0.25,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -22),
		Parent = gui,
	})
end

local function fmtTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function colorHex(c: Color3): string
	return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

local function updateMatch()
	local phase = state:GetAttribute("Phase") :: string? or "Waiting"
	local modeName = state:GetAttribute("ModeName") :: string? or ""
	local endsAt = state:GetAttribute("EndsAt") :: number? or 0
	local remaining = endsAt - workspace:GetServerTimeNow()
	local timer = if endsAt > 0 then fmtTime(remaining) else ""

	if phase == "Waiting" then
		refs.modeLabel.Text = "Waiting for players · free paint"
	elseif phase == "Intermission" then
		refs.modeLabel.Text = "Warm-up · " .. modeName .. " starts in " .. timer
	elseif phase == "Results" then
		refs.modeLabel.Text = "Results · next match in " .. timer
	else
		refs.modeLabel.Text = modeName .. " · " .. timer
	end

	local myFaction = Palette.MyFaction()
	if state:GetAttribute("HasTeams") then
		local s1 = state:GetAttribute("TeamScore1") :: number? or 0
		local s2 = state:GetAttribute("TeamScore2") :: number? or 0
		local n1 = state:GetAttribute("TeamName1") :: string? or "Team 1"
		local n2 = state:GetAttribute("TeamName2") :: string? or "Team 2"
		local safe, danger = colorHex(Palette.Colors().Safe), colorHex(Palette.Colors().Danger)
		local c1 = if myFaction == 1 then safe else danger
		local c2 = if myFaction == 2 then safe else danger
		refs.scoreLabel.Text =
			string.format('<font color="%s">%s %d</font>  —  <font color="%s">%d %s</font>', c1, n1, s1, c2, s2, n2)
	else
		local ls = player:FindFirstChild("leaderstats")
		local mine = ls and ls:FindFirstChild("Eliminations") :: IntValue?
		local leaderName = state:GetAttribute("LeaderName") :: string? or ""
		local leaderScore = state:GetAttribute("LeaderScore") :: number? or 0
		refs.scoreLabel.Text =
			string.format("You %d  ·  Leader %s %d", if mine then mine.Value else 0, leaderName, leaderScore)
	end
end

local function update(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local colors = Palette.Colors()

	-- Health.
	if humanoid then
		local frac = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		refs.healthLabel.Text = tostring(math.ceil(humanoid.Health))
		refs.healthBar.Size = UDim2.fromScale(frac, 1)
		refs.healthBar.BackgroundColor3 = if frac > 0.35 then WHITE else colors.Danger
	end

	-- Hazard.
	local inHazard = character ~= nil
		and character:GetAttribute("InHazard") == true
		and humanoid ~= nil
		and humanoid.Health > 0
	local pulse = 0.35 + 0.25 * math.sin(os.clock() * 12)
	damageFlashT = math.max(0, damageFlashT - dt * 3)
	for _, edge in refs.vignetteEdges do
		edge.BackgroundColor3 = colors.Danger
		edge.BackgroundTransparency = if inHazard then pulse else 1 - damageFlashT * 0.6
	end
	refs.hazardText.Visible = inHazard
	refs.hazardText.TextColor3 = colors.Danger

	-- Weapon.
	local ws = WeaponController.State()
	if ws then
		refs.weaponName.Text = ws.WeaponName
		refs.ammo.Text = if ws.IsMelee
			then "∞"
			elseif ws.Reloading then "Refilling…"
			else string.format("%d / %d", ws.Ammo, ws.Magazine)
		refs.reloadBar.Size = UDim2.fromScale(ws.ReloadProgress, 1)
		refs.grenades.Text = "Bombs " .. ws.Grenades
	else
		refs.weaponName.Text = ""
		refs.ammo.Text = ""
		refs.grenades.Text = ""
	end

	-- Hit marker.
	hitMarkerT = math.max(0, hitMarkerT - dt * 4)
	refs.hitMarker.TextTransparency = 1 - hitMarkerT
	refs.hitMarker.TextColor3 = colors.Safe

	-- Respawn message.
	refs.centre.Text = if humanoid and humanoid.Health <= 0 then "Splatted! Respawning…" else ""

	updateMatch()
end

local function addFeed(killer: string, victim: string, weaponId: string, banner: Color3?)
	local weapon = Weapons[weaponId]
	local how = if weapon then weapon.DisplayName else "enemy paint"
	local row = panel({
		Size = UDim2.fromOffset(340, 28),
		BackgroundTransparency = 0.4,
		LayoutOrder = -math.floor(os.clock() * 100),
	})
	if banner then
		UI.new("Frame", { Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = banner, BorderSizePixel = 0, Parent = row })
	end
	UI.label({
		Text = killer .. "  ▸ " .. how .. " ▸  " .. victim,
		TextSize = 15,
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	row.Parent = refs.feed
	table.insert(feed, row)
	if #feed > 5 then
		local oldest = table.remove(feed, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	task.delay(6, function()
		local i = table.find(feed, row)
		if i then
			table.remove(feed, i)
			row:Destroy()
		end
	end)
end

local function showToast(title: string, body: string)
	refs.toastTitle.Text = title
	refs.toastBody.Text = body
	refs.toast.Visible = true
	refs.toast.BackgroundTransparency = 0.2
	task.delay(3.5, function()
		if refs.toastTitle.Text == title then
			refs.toast.Visible = false
		end
	end)
end

local function showResults(r: any)
	refs.resultsTitle.Text = if r.Won then "VICTORY" else "Match over"
	refs.resultsTitle.TextColor3 = if r.Won then Palette.Colors().Safe else WHITE
	local lines = {
		string.format("<b>%s</b> · winner: <b>%s</b>", r.ModeName, r.WinnerName ~= "" and r.WinnerName or "—"),
		"",
		string.format("Place #%d   ·   %d eliminations   ·   %d splats taken", r.Place, r.Eliminations, r.Deaths),
		string.format("Cells painted: %d", r.PaintCells),
		string.format(
			'<font color="%s">+%d XP</font>   ·   Season tier %d (%d%%)',
			colorHex(Palette.Colors().Safe),
			r.XP,
			r.Tier,
			math.floor(r.TierProgress * 100)
		),
		"",
		"<b>Top players</b>",
	}
	for i, row in r.Board do
		if i > 6 then
			break
		end
		table.insert(lines, string.format("%d. %s — %d / %d", row.Place, row.Name, row.Eliminations, row.Deaths))
	end
	refs.resultsBody.Text = table.concat(lines, "\n")
	refs.results.Visible = true
end

function Hud.Init()
	state = ReplicatedStorage:WaitForChild("MatchState") :: Folder
	build()

	Net.Event("HitConfirm").OnClientEvent:Connect(function(_amount: number, eliminated: boolean)
		hitMarkerT = 1
		if eliminated then
			refs.hitMarker.TextSize = 48
			TweenService:Create(refs.hitMarker, TweenInfo.new(0.3), { TextSize = 34 }):Play()
		end
	end)
	Net.Event("DamageTaken").OnClientEvent:Connect(function(amount: number, kind: string)
		if kind ~= "Hazard" then
			damageFlashT = math.min(1, damageFlashT + amount / 40)
		end
	end)
	Net.Event("KillFeed").OnClientEvent:Connect(addFeed)
	Net.Event("Toast").OnClientEvent:Connect(showToast)
	Net.Event("MatchResults").OnClientEvent:Connect(showResults)
	state:GetAttributeChangedSignal("Phase"):Connect(function()
		if state:GetAttribute("Phase") ~= "Results" then
			refs.results.Visible = false
		end
		if state:GetAttribute("Phase") == "Active" then
			showToast(
				state:GetAttribute("ModeName") :: string? or "Match",
				state:GetAttribute("ModeBlurb") :: string? or ""
			)
		end
	end)

	RunService.RenderStepped:Connect(update)
end

return Hud

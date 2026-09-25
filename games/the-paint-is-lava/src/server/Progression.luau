--!strict
--[[
	Progression: cosmetics, achievements, the seasonal pass and purchases.

	Ownership is COMPUTED, not granted: a pass cosmetic is owned when your season tier
	reaches it (premium ones also need the pass), an achievement cosmetic when the
	achievement is unlocked. Only direct purchases are stored. That keeps profiles small
	and makes it impossible for the pass and the catalog to drift apart.

	Nothing here touches gameplay stats (Direction §15). XP only ever unlocks cosmetics.
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tuning = require(Shared.Config.Tuning)
local Cosmetics = require(Shared.Config.Cosmetics)
local Achievements = require(Shared.Config.Achievements)
local Season = require(Shared.Config.Season)
local Net = require(Shared.Net)

local Progression = {}

local S: any

local SETTINGS: { [string]: string } = { ColorblindPalette = "boolean" }

local function profileOf(player: Player): any
	return S.PlayerData.Get(player)
end

function Progression.Owns(profile: any, cosmeticId: string): boolean
	local item = Cosmetics.ById[cosmeticId]
	if not item then
		return false
	end
	local unlock = item.Unlock
	if unlock.Source == "Default" then
		return true
	elseif unlock.Source == "Achievement" then
		return profile.Achievements[unlock.Ref :: string] ~= nil
	elseif unlock.Source == "FreePass" then
		return Season.TierForXP(profile.Season.XP) >= (unlock.Ref :: number)
	elseif unlock.Source == "PremiumPass" then
		return profile.Season.Premium and Season.TierForXP(profile.Season.XP) >= (unlock.Ref :: number)
	elseif unlock.Source == "Purchase" then
		return profile.Owned[cosmeticId] == true
	end
	return false
end

-- Equipped cosmetic per category, falling back to defaults (and to defaults if an item
-- is no longer owned, e.g. a premium item after the season rolls over).
function Progression.Equipped(player: Player): { [string]: string }
	local profile = profileOf(player)
	local out: { [string]: string } = {}
	for category, defaultId in Cosmetics.Defaults do
		local id = profile and profile.Equipped[category]
		out[category] = if id and Progression.Owns(profile, id) then id else defaultId
	end
	return out
end

function Progression.BannerColor(player: Player): Color3?
	local item = Cosmetics.ById[Progression.Equipped(player).Banner]
	return item and item.Visual.Color
end

local function view(player: Player, profile: any): any
	local owned: { string } = {}
	for _, item in Cosmetics.List do
		if Progression.Owns(profile, item.Id) then
			table.insert(owned, item.Id)
		end
	end
	local tier = Season.TierForXP(profile.Season.XP)
	return {
		Owned = owned,
		Equipped = Progression.Equipped(player),
		Level = math.floor(profile.XP / Tuning.Progression.AccountLevelXP) + 1,
		Season = {
			Name = Season.DisplayName,
			Tier = tier,
			Tiers = Season.Tiers,
			XP = profile.Season.XP,
			XPPerTier = Season.XPPerTier,
			Premium = profile.Season.Premium,
			PremiumAvailable = Season.PremiumGamePassId ~= 0,
			PremiumGamePassId = Season.PremiumGamePassId,
		},
		Stats = profile.Stats,
		Achievements = profile.Achievements,
		Settings = profile.Settings,
	}
end

function Progression.Sync(player: Player)
	local profile = profileOf(player)
	if profile then
		Net.Event("ProfileSync"):FireClient(player, view(player, profile))
		player:SetAttribute("ColorblindPalette", profile.Settings.ColorblindPalette == true)
		player:SetAttribute("PaintEffect", Progression.Equipped(player).PaintEffect)
	end
end

local function toast(player: Player, title: string, body: string)
	Net.Event("Toast"):FireClient(player, title, body)
end

local function checkAchievements(player: Player, profile: any, stat: string)
	for _, a in Achievements do
		if a.Stat == stat and not profile.Achievements[a.Id] and (profile.Stats[stat] or 0) >= a.Threshold then
			profile.Achievements[a.Id] = os.time()
			local reward = a.Reward and Cosmetics.ById[a.Reward]
			toast(
				player,
				"Achievement: " .. a.DisplayName,
				if reward then "Unlocked " .. reward.DisplayName else a.Description
			)
			Progression.Sync(player)
		end
	end
end

function Progression.AddStat(player: Player, stat: string, amount: number)
	local profile = profileOf(player)
	if not profile or amount == 0 then
		return
	end
	profile.Stats[stat] = (profile.Stats[stat] or 0) + amount
	checkAchievements(player, profile, stat)
end

export type MatchSummary = {
	Mode: string,
	Won: boolean,
	Place: number,
	Eliminations: number,
	Deaths: number,
	PaintCells: number,
}

function Progression.AwardMatch(
	player: Player,
	summary: MatchSummary
): { XP: number, Tier: number, TierProgress: number }
	local profile = profileOf(player)
	if not profile then
		return { XP = 0, Tier = 0, TierProgress = 0 }
	end
	local p = Tuning.Progression
	local xp = p.XPPerMatch
		+ summary.Eliminations * p.XPPerElimination
		+ (if summary.Won then p.XPPerWin else 0)
		+ math.floor(summary.PaintCells / 100) * p.XPPer100PaintCells

	local tierBefore = Season.TierForXP(profile.Season.XP)
	profile.XP += xp
	profile.Season.XP += xp
	local tierAfter = Season.TierForXP(profile.Season.XP)

	Progression.AddStat(player, "MatchesPlayed", 1)
	Progression.AddStat(player, "PaintCells", summary.PaintCells)
	if summary.Won then
		Progression.AddStat(player, "Wins", 1)
	end

	if tierAfter > tierBefore then
		toast(player, "Season tier " .. tierAfter .. "!", "New cosmetics may be waiting in your Locker (L).")
	end
	Progression.Sync(player)
	return {
		XP = xp,
		Tier = tierAfter,
		TierProgress = (profile.Season.XP % Season.XPPerTier) / Season.XPPerTier,
	}
end

-- Kill bookkeeping for lifetime stats and achievements.
local function onEliminated(victim: Player, killer: Player?, weaponId: string, cause: string)
	if S.Match.Phase() ~= "Active" then
		return
	end
	Progression.AddStat(victim, "Deaths", 1)
	if not killer or killer == victim then
		return
	end
	Progression.AddStat(killer, "Eliminations", 1)
	if cause == "Hazard" then
		Progression.AddStat(killer, "HazardEliminations", 1)
	end
	if weaponId == "Paintbrush" then
		Progression.AddStat(killer, "BrushEliminations", 1)
	end
	if S.Movement.IsAerial(killer) then
		Progression.AddStat(killer, "AerialEliminations", 1)
	end
end

local function onEquip(player: Player, category: unknown, id: unknown)
	if typeof(category) ~= "string" or typeof(id) ~= "string" then
		return
	end
	local profile = profileOf(player)
	local item = Cosmetics.ById[id :: string]
	if not profile or not item or item.Category ~= category or not Progression.Owns(profile, id :: string) then
		return
	end
	profile.Equipped[category :: string] = id :: string
	S.Character.ApplyCosmetics(player)
	Progression.Sync(player)
end

local function onSetting(player: Player, key: unknown, value: unknown)
	if typeof(key) ~= "string" or SETTINGS[key :: string] == nil or typeof(value) ~= SETTINGS[key :: string] then
		return
	end
	local profile = profileOf(player)
	if profile then
		profile.Settings[key :: string] = value
		Progression.Sync(player)
	end
end

-- Purchases -----------------------------------------------------------------------------

local function refreshPremium(player: Player)
	if Season.PremiumGamePassId == 0 then
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Season.PremiumGamePassId)
	end)
	local profile = profileOf(player)
	if ok and owns and profile and not profile.Season.Premium then
		profile.Season.Premium = true
		Progression.Sync(player)
	end
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local profile = player and profileOf(player)
	if not player or not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseKey = tostring(receipt.PurchaseId)
	if profile.Receipts[purchaseKey] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local granted = false
	for _, item in Cosmetics.List do
		if item.Unlock.Source == "Purchase" and item.Unlock.Ref ~= 0 and item.Unlock.Ref == receipt.ProductId then
			profile.Owned[item.Id] = true
			granted = true
			toast(player, "Purchased", item.DisplayName)
		end
	end
	if not granted then
		warn("[Progression] receipt for unknown product " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	profile.Receipts[purchaseKey] = true
	S.PlayerData.Save(player, false)
	Progression.Sync(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Progression.Init(services: any)
	S = services
end

function Progression.Start()
	S.PlayerData.Loaded:Connect(function(player: Player)
		refreshPremium(player)
		Progression.Sync(player)
	end)
	S.Match.Eliminated:Connect(onEliminated)
	Net.Event("Equip").OnServerEvent:Connect(onEquip)
	Net.Event("SetSetting").OnServerEvent:Connect(onSetting)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == Season.PremiumGamePassId then
			local profile = profileOf(player)
			if profile then
				profile.Season.Premium = true
				toast(player, "Premium pass unlocked", "Thanks! Premium rewards are now in your Locker.")
				Progression.Sync(player)
			end
		end
	end)
	MarketplaceService.ProcessReceipt = processReceipt
end

return Progression

--!strict
--[[
	Seasonal battle pass (Direction §17). Two tracks:
		Free    cosmetics earned by playing
		Premium extra cosmetics for pass owners
	The premium track adds cosmetic CHOICE, never gameplay strength. Tier rewards are the
	cosmetics whose Unlock is FreePass/PremiumPass with a matching tier number (see
	Cosmetics.luau), so the pass cannot drift out of sync with the catalog.

	All sizes are PLACEHOLDER (§22 precise battle-pass size, season duration).
]]

local Season = {
	Id = "S1",
	DisplayName = "Season 1: Fresh Coat",
	Tiers = 30,
	XPPerTier = 600,
	-- Roblox game pass id for the premium track. 0 = not configured yet: the premium
	-- purchase button stays hidden and premium rewards cannot be claimed.
	PremiumGamePassId = 0,
}

function Season.TierForXP(xp: number): number
	return math.clamp(math.floor(xp / Season.XPPerTier), 0, Season.Tiers)
end

return Season

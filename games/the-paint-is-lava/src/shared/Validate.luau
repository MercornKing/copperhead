--!strict
--[[
	Validate: machine-checked guard rails for the non-negotiables.

	1. Cosmetics only (Direction §15): no cosmetic, character or pass reward may carry a
	   gameplay field. Checked by key whitelist AND a blocklist of gameplay words, so a
	   stat can't sneak in under an innocent category.
	2. Readability (Direction §9, §14): paint effects may never recolour paint.
	3. Referential integrity: every pass tier, achievement and reward points at something
	   that exists.

	Run by the test suite (tests/validate.spec.luau) and by the server at boot, which
	refuses to start a match on a catalog that fails.
]]

local Validate = {}

local GAMEPLAY_WORDS = {
	"damage",
	"health",
	"speed",
	"jump",
	"firerate",
	"range",
	"ammo",
	"magazine",
	"reload",
	"spread",
	"radius",
	"grapple",
	"wallrun",
	"armor",
	"xpmultiplier",
	"boost",
	"cooldown",
	"hitbox",
	"scale",
	"size",
}

local function mentionsGameplay(key: string): boolean
	local k = string.lower(key)
	for _, word in GAMEPLAY_WORDS do
		if string.find(k, word, 1, true) then
			return true
		end
	end
	return false
end

local function contains(list: { string }, value: string): boolean
	for _, v in list do
		if v == value then
			return true
		end
	end
	return false
end

function Validate.Cosmetics(catalog: any, achievements: { any }, season: any): { string }
	local errors: { string } = {}
	local seen: { [string]: boolean } = {}
	local achievementIds: { [string]: boolean } = {}
	for _, a in achievements do
		achievementIds[a.Id] = true
	end

	local allowedEntryKeys = { "Id", "DisplayName", "Category", "Rarity", "Unlock", "Visual" }

	for _, item in catalog.List do
		local label = tostring(item.Id)
		if seen[item.Id] then
			table.insert(errors, label .. ": duplicate id")
		end
		seen[item.Id] = true

		for key in item do
			if not contains(allowedEntryKeys, key) then
				table.insert(errors, label .. ": unexpected field '" .. tostring(key) .. "'")
			end
		end

		local allowedVisual = catalog.Categories[item.Category]
		if not allowedVisual then
			table.insert(errors, label .. ": unknown category '" .. tostring(item.Category) .. "'")
		else
			for key in item.Visual do
				if not contains(allowedVisual, key) then
					table.insert(
						errors,
						label .. ": visual key '" .. tostring(key) .. "' not allowed for " .. item.Category
					)
				end
				if mentionsGameplay(key) then
					table.insert(errors, label .. ": visual key '" .. tostring(key) .. "' looks like a gameplay stat")
				end
			end
		end

		if item.Category == "PaintEffect" then
			for key, value in item.Visual do
				if typeof(value) == "Color3" or string.find(string.lower(key), "colo", 1, true) then
					table.insert(errors, label .. ": paint effects must not change paint colour")
				end
			end
		end

		local unlock = item.Unlock
		if unlock.Source == "Achievement" then
			if not achievementIds[unlock.Ref] then
				table.insert(errors, label .. ": unknown achievement '" .. tostring(unlock.Ref) .. "'")
			end
		elseif unlock.Source == "FreePass" or unlock.Source == "PremiumPass" then
			if typeof(unlock.Ref) ~= "number" or unlock.Ref < 1 or unlock.Ref > season.Tiers then
				table.insert(errors, label .. ": pass tier out of range")
			end
		elseif unlock.Source == "Purchase" then
			if typeof(unlock.Ref) ~= "number" then
				table.insert(errors, label .. ": purchase needs a numeric product id (0 = unconfigured)")
			end
		elseif unlock.Source ~= "Default" then
			table.insert(errors, label .. ": unknown unlock source '" .. tostring(unlock.Source) .. "'")
		end
	end

	for category, id in catalog.Defaults do
		local item = catalog.ById[id]
		if not item then
			table.insert(errors, "default " .. category .. " '" .. id .. "' does not exist")
		elseif item.Unlock.Source ~= "Default" then
			table.insert(errors, "default " .. category .. " '" .. id .. "' must be free for everyone")
		end
	end

	for _, a in achievements do
		if a.Reward and not catalog.ById[a.Reward] then
			table.insert(errors, "achievement " .. a.Id .. ": reward '" .. a.Reward .. "' does not exist")
		end
	end

	return errors
end

function Validate.Characters(characters: { any }, catalog: any): { string }
	local errors: { string } = {}
	local allowed = { "Id", "DisplayName", "Personality", "BodyColors", "Signature", "AccentColor" }
	for _, ch in characters do
		for key in ch do
			if not contains(allowed, key) then
				table.insert(
					errors,
					tostring(ch.Id) .. ": characters are cosmetic only, '" .. tostring(key) .. "' not allowed"
				)
			end
		end
		local hasDefaultSkin = false
		for _, item in catalog.List do
			if
				item.Category == "CharacterSkin"
				and item.Visual.Character == ch.Id
				and item.Unlock.Source == "Default"
			then
				hasDefaultSkin = true
			end
		end
		if not hasDefaultSkin then
			table.insert(errors, tostring(ch.Id) .. ": needs a free default CharacterSkin")
		end
	end
	for _, item in catalog.List do
		if item.Category == "CharacterSkin" then
			local found = false
			for _, ch in characters do
				if ch.Id == item.Visual.Character then
					found = true
				end
			end
			if not found then
				table.insert(errors, item.Id .. ": skin for unknown character")
			end
		end
	end
	return errors
end

function Validate.Weapons(weapons: { [string]: any }, loadout: { string }): { string }
	local errors: { string } = {}
	local numeric = {
		"DirectDamage",
		"SplashDamage",
		"SplashRadius",
		"PaintRadius",
		"FireRate",
		"Spread",
		"Range",
		"ProjectileSpeed",
		"Gravity",
		"MagazineSize",
		"ReloadTime",
		"MoveSpeedMultiplier",
	}
	for id, w in weapons do
		if w.Id ~= id then
			table.insert(errors, id .. ": Id field must match key")
		end
		for _, field in numeric do
			local v = w[field]
			if typeof(v) ~= "number" or v < 0 or v ~= v then
				table.insert(errors, id .. ": " .. field .. " must be a non-negative number")
			end
		end
		if typeof(w.FireRate) == "number" and w.FireRate <= 0 then
			table.insert(errors, id .. ": FireRate must be positive")
		end
		if w.PaintRadius == 0 then
			table.insert(errors, id .. ": every weapon must paint (Direction §6)")
		end
		if w.Kind == "Projectile" and (w.ProjectileSpeed <= 0 or w.Pellets < 1) then
			table.insert(errors, id .. ": projectile weapons need speed and at least one pellet")
		end
		if w.Kind == "Thrown" and (w.Fuse == nil or w.Bounciness == nil) then
			table.insert(errors, id .. ": thrown weapons need Fuse and Bounciness")
		end
		if w.Kind == "Melee" and (w.Reach == nil or w.ArcDegrees == nil or w.SwipeRays == nil) then
			table.insert(errors, id .. ": melee weapons need Reach, ArcDegrees and SwipeRays")
		end
	end
	for _, id in loadout do
		if not weapons[id] then
			table.insert(errors, "loadout weapon '" .. id .. "' does not exist")
		end
	end
	return errors
end

return Validate

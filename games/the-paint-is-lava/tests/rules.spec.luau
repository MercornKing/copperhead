return function(t: any)
	local describe, it, expect = t.describe, t.it, t.expect
	local Vector3 = t.Vector3
	local Ballistics = t.Load("src/shared/Ballistics.luau")
	local Validate = t.Load("src/shared/Validate.luau")
	local Cosmetics = t.Load("src/shared/Config/Cosmetics.luau")
	local Characters = t.Load("src/shared/Config/Characters.luau")
	local Achievements = t.Load("src/shared/Config/Achievements.luau")
	local Season = t.Load("src/shared/Config/Season.luau")
	local Weapons = t.Load("src/shared/Config/Weapons.luau")
	local Tuning = t.Load("src/shared/Config/Tuning.luau")
	local Modes = t.Load("src/shared/Config/Modes.luau")

	describe("Ballistics", function()
		it("spread stays inside the weapon's cone", function()
			local dir = Vector3.new(0.3, 0.2, -1).Unit
			for _ = 1, 500 do
				local d = Ballistics.Spread(dir, 4, math.random)
				local angle = math.deg(math.acos(math.clamp(d:Dot(dir), -1, 1)))
				expect(angle).toBeAtMost(4.0001)
			end
		end)
		it("zero spread is perfectly accurate", function()
			local dir = Vector3.new(0, 0, -1)
			expect((Ballistics.Spread(dir, 0, math.random) - dir).Magnitude).toBeNear(0)
		end)
		it("gravity pulls projectiles down", function()
			local p, v = Ballistics.Step(Vector3.new(0, 10, 0), Vector3.new(100, 0, 0), 50, 0.1)
			expect(v.Y).toBeNear(-5)
			expect(p.Y).toBeAtMost(10)
			expect(p.X).toBeNear(10)
		end)
		it("splash falls off and stops at the radius", function()
			expect(Ballistics.SplashDamage(50, 10, 0)).toBeNear(50)
			expect(Ballistics.SplashDamage(50, 10, 10)).toBeNear(20)
			expect(Ballistics.SplashDamage(50, 10, 10.01)).toBe(0)
		end)
		it("bounces reflect and lose energy", function()
			local v = Ballistics.Bounce(Vector3.new(10, -10, 0), Vector3.new(0, 1, 0), 0.5)
			expect(v.Y).toBeNear(5)
			expect(v.X).toBeNear(5)
		end)
	end)

	describe("Non-negotiables: cosmetics only, readable paint", function()
		it("the shipped cosmetic catalog passes", function()
			expect(Validate.Cosmetics(Cosmetics, Achievements, Season)).toBeEmpty()
		end)
		it("the shipped characters are cosmetic only", function()
			expect(Validate.Characters(Characters, Cosmetics)).toBeEmpty()
		end)
		it("the shipped weapons and loadout are well formed and all paint", function()
			expect(Validate.Weapons(Weapons, Tuning.Loadout)).toBeEmpty()
		end)
		it("rejects a cosmetic that sneaks in a gameplay stat", function()
			local bad = table.clone(Cosmetics.List)
			table.insert(bad, {
				Id = "pay_to_win",
				DisplayName = "Golden Gun",
				Category = "WeaponSkin",
				Rarity = "Legendary",
				Unlock = { Source = "Purchase", Ref = 0 },
				Visual = { Color = t.Color3.new(1, 1, 0), DamageBonus = 5 },
			})
			local catalog =
				{ List = bad, ById = Cosmetics.ById, Categories = Cosmetics.Categories, Defaults = Cosmetics.Defaults }
			expect(#Validate.Cosmetics(catalog, Achievements, Season)).toBeAtLeast(1)
		end)
		it("rejects an extra top-level field on a cosmetic", function()
			local bad = table.clone(Cosmetics.List)
			table.insert(bad, {
				Id = "sneaky",
				DisplayName = "Sneaky",
				Category = "Banner",
				Rarity = "Common",
				Unlock = { Source = "Default" },
				Visual = {},
				Stats = { Health = 10 },
			})
			local catalog =
				{ List = bad, ById = Cosmetics.ById, Categories = Cosmetics.Categories, Defaults = Cosmetics.Defaults }
			expect(#Validate.Cosmetics(catalog, Achievements, Season)).toBeAtLeast(1)
		end)
		it("rejects a paint effect that recolours paint", function()
			local bad = table.clone(Cosmetics.List)
			table.insert(bad, {
				Id = "fx_rainbow",
				DisplayName = "Rainbow",
				Category = "PaintEffect",
				Rarity = "Epic",
				Unlock = { Source = "Default" },
				Visual = { SplatStyle = t.Color3.new(1, 0, 1) },
			})
			local catalog =
				{ List = bad, ById = Cosmetics.ById, Categories = Cosmetics.Categories, Defaults = Cosmetics.Defaults }
			expect(#Validate.Cosmetics(catalog, Achievements, Season)).toBeAtLeast(1)
		end)
		it("rejects a character with a gameplay difference", function()
			local bad = table.clone(Characters)
			local fast = table.clone(Characters[1])
			fast.WalkSpeed = 30
			table.insert(bad, fast)
			expect(#Validate.Characters(bad, Cosmetics)).toBeAtLeast(1)
		end)
		it("rejects a weapon that does not paint", function()
			local bad = table.clone(Weapons)
			local w = table.clone(Weapons.Pistol)
			w.PaintRadius = 0
			bad.Pistol = w
			expect(#Validate.Weapons(bad, Tuning.Loadout)).toBeAtLeast(1)
		end)
		it("safe and danger colours are clearly distinct in both palettes", function()
			for _, palette in { Tuning.Colors.Standard, Tuning.Colors.ColorblindSafe } do
				local a, b = palette.Safe, palette.Danger
				local diff = math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B)
				expect(diff).toBeAtLeast(0.8)
			end
		end)
		it("team identity colours are never close to either paint palette", function()
			local s, cb = Tuning.Colors.Standard, Tuning.Colors.ColorblindSafe
			for _, team in Modes.TeamDeathmatch.Teams do
				local col = team.IdentityColor
				for _, paint in { s.Safe, s.Danger, cb.Safe, cb.Danger } do
					local diff = math.abs(col.R - paint.R) + math.abs(col.G - paint.G) + math.abs(col.B - paint.B)
					expect(diff).toBeAtLeast(0.35)
				end
			end
		end)
	end)

	describe("Readability of characters", function()
		local s, cb = Tuning.Colors.Standard, Tuning.Colors.ColorblindSafe
		local paints = { s.Safe, s.Danger, cb.Safe, cb.Danger }
		local function farFromPaint(label: string, col: any)
			for _, paint in paints do
				local diff = math.abs(col.R - paint.R) + math.abs(col.G - paint.G) + math.abs(col.B - paint.B)
				if diff < 0.3 then
					error(label .. " is too close to a paint colour")
				end
			end
		end
		it("launch character bodies never look like paint", function()
			for _, ch in Characters do
				farFromPaint(ch.Id .. " torso", ch.BodyColors.Torso)
				farFromPaint(ch.Id .. " arms", ch.BodyColors.Arms)
				farFromPaint(ch.Id .. " legs", ch.BodyColors.Legs)
			end
		end)
		it("character skins never look like paint", function()
			for _, item in Cosmetics.List do
				if item.Category == "CharacterSkin" then
					for _, part in { "Torso", "Arms", "Legs" } do
						if item.Visual[part] then
							farFromPaint(item.Id .. " " .. part, item.Visual[part])
						end
					end
				end
			end
		end)
	end)

	describe("Season pass", function()
		it("maps XP to tiers and caps at the last tier", function()
			expect(Season.TierForXP(0)).toBe(0)
			expect(Season.TierForXP(Season.XPPerTier)).toBe(1)
			expect(Season.TierForXP(Season.XPPerTier * 1000)).toBe(Season.Tiers)
		end)
		it("has a free-track reward somewhere, so non-payers progress too", function()
			local free = 0
			for _, item in Cosmetics.List do
				if item.Unlock.Source == "FreePass" then
					free += 1
				end
			end
			expect(free).toBeAtLeast(3)
		end)
	end)
end

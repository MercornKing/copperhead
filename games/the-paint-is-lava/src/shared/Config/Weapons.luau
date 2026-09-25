--!strict
--[[
	Weapons: every weapon fires paint (Direction §6). There is no parallel bullet system.

	Balance is two-sided (Direction §7): each weapon is tuned for what it does to PLAYERS
	(DirectDamage, SplashDamage, FireRate, Spread, Range) and for what it does to the
	ARENA (PaintRadius, SplashRadius, Pellets). A weapon does not need the highest damage
	to be strategically strong.

	All numbers are PLACEHOLDER starting points (§22 exact weapon roster, time-to-kill).
	See docs/TUNING.md for the balancing framework and the playtest questions per weapon.

	Field reference:
		Kind            "Projectile" (guns/launcher), "Thrown" (grenade), "Melee" (brush)
		DirectDamage    damage on a direct hit to a hostile player
		SplashDamage    max damage to hostiles inside SplashRadius (falls off with distance)
		SplashRadius    radius of player splash damage (0 = none)
		PaintRadius     radius of surface coverage per impact (studs)
		FireRate        shots per second
		Automatic       hold to fire
		Pellets         projectiles per shot
		Spread          cone half-angle in degrees (accuracy)
		Range           max travel distance before the paint blob evaporates (studs)
		ProjectileSpeed studs per second
		Gravity         downward acceleration on the projectile (studs/s^2)
		MagazineSize    paint shots per tank
		ReloadTime      seconds to refill the tank
		MoveSpeedMultiplier  walk-speed multiplier while this weapon is held
		Fuse            (Thrown) seconds until burst
		Bounciness      (Thrown) fraction of speed kept per bounce
		Reach, ArcDegrees, SwipeRays  (Melee) hit reach, swipe width, paint rays per swipe
]]

export type WeaponStats = {
	Id: string,
	DisplayName: string,
	Kind: "Projectile" | "Thrown" | "Melee",
	DirectDamage: number,
	SplashDamage: number,
	SplashRadius: number,
	PaintRadius: number,
	FireRate: number,
	Automatic: boolean,
	Pellets: number,
	Spread: number,
	Range: number,
	ProjectileSpeed: number,
	Gravity: number,
	MagazineSize: number,
	ReloadTime: number,
	MoveSpeedMultiplier: number,
	Fuse: number?,
	Bounciness: number?,
	Reach: number?,
	ArcDegrees: number?,
	SwipeRays: number?,
	-- Visual only: base colour of the neutral weapon model before cosmetics.
	ModelColor: Color3,
}

local Weapons: { [string]: WeaponStats } = {
	-- Responsive and accurate; paints very little. A duelling tool.
	Pistol = {
		Id = "Pistol",
		DisplayName = "Splat Pistol",
		Kind = "Projectile",
		DirectDamage = 24,
		SplashDamage = 0,
		SplashRadius = 0,
		PaintRadius = 1.6,
		FireRate = 4,
		Automatic = false,
		Pellets = 1,
		Spread = 0.6,
		Range = 260,
		ProjectileSpeed = 420,
		Gravity = 0,
		MagazineSize = 12,
		ReloadTime = 1.2,
		MoveSpeedMultiplier = 1,
		ModelColor = Color3.fromRGB(70, 74, 92),
	},

	-- All-rounder: solid damage, medium lines of paint.
	Rifle = {
		Id = "Rifle",
		DisplayName = "Streak Rifle",
		Kind = "Projectile",
		DirectDamage = 17,
		SplashDamage = 0,
		SplashRadius = 0,
		PaintRadius = 2.4,
		FireRate = 8,
		Automatic = true,
		Pellets = 1,
		Spread = 1.4,
		Range = 320,
		ProjectileSpeed = 380,
		Gravity = 20,
		MagazineSize = 30,
		ReloadTime = 1.8,
		MoveSpeedMultiplier = 0.95,
		ModelColor = Color3.fromRGB(62, 84, 140),
	},

	-- Paints fast in thin, less efficient lines; weak per hit.
	MachineGun = {
		Id = "MachineGun",
		DisplayName = "Spray Hose",
		Kind = "Projectile",
		DirectDamage = 9,
		SplashDamage = 0,
		SplashRadius = 0,
		PaintRadius = 1.4,
		FireRate = 15,
		Automatic = true,
		Pellets = 1,
		Spread = 4,
		Range = 180,
		ProjectileSpeed = 300,
		Gravity = 45,
		MagazineSize = 90,
		ReloadTime = 2.8,
		MoveSpeedMultiplier = 0.85,
		ModelColor = Color3.fromRGB(120, 72, 160),
	},

	-- Very slow, huge coverage: turns a landing zone into a trap in one shot.
	Launcher = {
		Id = "Launcher",
		DisplayName = "Bucket Launcher",
		Kind = "Projectile",
		DirectDamage = 45,
		SplashDamage = 40,
		SplashRadius = 10,
		PaintRadius = 11,
		FireRate = 0.8,
		Automatic = false,
		Pellets = 1,
		Spread = 0.3,
		Range = 400,
		ProjectileSpeed = 140,
		Gravity = 30,
		MagazineSize = 3,
		ReloadTime = 3,
		MoveSpeedMultiplier = 0.8,
		ModelColor = Color3.fromRGB(230, 170, 40),
	},

	-- Area denial: bounces, then bursts over a wide area.
	Grenade = {
		Id = "Grenade",
		DisplayName = "Paint Bomb",
		Kind = "Thrown",
		DirectDamage = 0,
		SplashDamage = 55,
		SplashRadius = 12,
		PaintRadius = 13,
		FireRate = 1,
		Automatic = false,
		Pellets = 1,
		Spread = 0,
		Range = 1000,
		ProjectileSpeed = 90,
		Gravity = 110,
		MagazineSize = 1,
		ReloadTime = 0,
		MoveSpeedMultiplier = 1,
		Fuse = 1.6,
		Bounciness = 0.45,
		ModelColor = Color3.fromRGB(255, 255, 255),
	},

	-- Almost no range, big immediate swipe of paint around the player.
	Paintbrush = {
		Id = "Paintbrush",
		DisplayName = "Big Brush",
		Kind = "Melee",
		DirectDamage = 50,
		SplashDamage = 0,
		SplashRadius = 0,
		PaintRadius = 3.2,
		FireRate = 1.6,
		Automatic = false,
		Pellets = 1,
		Spread = 0,
		Range = 9,
		ProjectileSpeed = 0,
		Gravity = 0,
		MagazineSize = math.huge,
		ReloadTime = 0,
		MoveSpeedMultiplier = 1.1,
		Reach = 8,
		ArcDegrees = 100,
		SwipeRays = 7,
		ModelColor = Color3.fromRGB(180, 120, 80),
	},
}

return Weapons

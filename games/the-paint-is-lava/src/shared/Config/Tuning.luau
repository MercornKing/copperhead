--!strict
--[[
	Tuning: every gameplay number lives here, in one place, so playtests can change feel
	without touching code.

	Values marked PLACEHOLDER are deliberately NOT decided yet (Game Direction §22). They
	are starting points to make the first playable build testable, nothing more. Change
	them from playtest evidence, then record the decision in docs/TUNING.md.

	Rule: nothing in here may ever be altered by a cosmetic, a purchase, or a character
	choice. Characters are mechanically identical (Direction §11); monetization is
	cosmetics only (Direction §15).
]]

local Tuning = {}

Tuning.Paint = {
	-- World-space size (studs) of one paint cell. Smaller = crisper paint, more cells to sync.
	CellSize = 3,
	-- Cells render this far off the surface to avoid z-fighting.
	SurfaceOffset = 0.06,
	-- How often the server flushes batched paint changes to clients (seconds).
	BroadcastInterval = 0.05,
	-- Max bytes per snapshot chunk sent to a joining player.
	SnapshotChunkBytes = 30000,
	-- PLACEHOLDER (§22 "whether paint naturally disappears"): 0 = paint is permanent
	-- until repainted. Any positive number = seconds before a cell fades to unpainted.
	DecaySeconds = 0,
	-- PLACEHOLDER (§22 "how quickly paint can be replaced"): 1 = one hit repaints a cell.
	-- Values above 1 mean a cell needs this many overlapping hits to flip owner.
	HitsToFlip = 1,
}

Tuning.Health = {
	MaxHealth = 100, -- PLACEHOLDER (§22 exact health values)
	RegenDelay = 5, -- PLACEHOLDER seconds after last damage before regen starts
	RegenPerSecond = 12, -- PLACEHOLDER
}

Tuning.Hazard = {
	-- PLACEHOLDER (§22 hostile-paint damage rate): damage per second while touching any
	-- enemy paint. One flat rate for floors, walls, ceilings, wall-runs and grapples:
	-- the rule is "red hurts", with no per-surface exceptions (Direction §2).
	DamagePerSecond = 22,
	-- How often the server probes every player for contact (seconds).
	TickInterval = 0.1,
	-- Extra reach beyond the character's body used by contact probes (studs).
	ContactSlack = 0.75,
}

Tuning.Movement = {
	WalkSpeed = 20,
	SprintSpeed = 28,
	JumpPower = 55,
	AirControl = 1, -- reserved; Roblox humanoids already give full air control

	WallRun = {
		Speed = 34,
		MinEntrySpeed = 10, -- horizontal speed needed to latch onto a wall
		MaxDuration = 1.8,
		SinkSpeed = 3, -- studs/s downward drift while running
		DetectDistance = 3.2,
		JumpOffSpeed = 40, -- push away from wall on jump
		JumpUpSpeed = 48,
		ReattachCooldown = 0.25,
		CameraTiltDegrees = 9,
	},

	Grapple = {
		Range = 140,
		ReelSpeed = 70, -- studs/s the rope shortens while held
		ReelForce = 60000,
		MinLength = 6,
		MaxAttachSeconds = 4,
		Cooldown = 0.6,
	},
}

Tuning.Match = {
	-- PLACEHOLDER (§22 player counts). The code supports up to 253 independent factions;
	-- the actual cap is the Roblox server size set in Game Settings > Places.
	MinPlayersToStart = 2,
	IntermissionSeconds = 15,
	ResultsSeconds = 12,
	ModeRotation = { "TeamDeathmatch", "FreeForAll" },
	-- Solo testing in Studio: start a match with a single player.
	AllowSoloInStudio = true,
}

Tuning.Respawn = {
	Delay = 3, -- PLACEHOLDER (§22 respawn rules)
	SpawnProtection = 2, -- seconds of ForceField after spawning
	-- Spawns this close to a hostile player are avoided when possible.
	SafeRadius = 40,
}

Tuning.Grenade = {
	Count = 2, -- per life. PLACEHOLDER
}

-- Studio-only helpers for solo playtests. Never active in live servers.
Tuning.Dev = {
	-- Sprays "enemy" paint around the arena while you play alone in Studio, so you can
	-- feel hostile-paint damage on floors, walls and grapple anchors without a second player.
	StudioHostilePainter = true,
	HostilePaintInterval = 2.5,
}

-- Reserve paint is unlimited for the first build (§22 "weapon ammunition limits").
Tuning.ReserveAmmoUnlimited = true

-- Default loadout: every player gets the same kit (no pay-to-win, no class split yet).
Tuning.Loadout = { "Rifle", "MachineGun", "Launcher", "Pistol", "Paintbrush" }

Tuning.Progression = {
	-- Match XP only ever unlocks cosmetics. There is no XP boost for sale (Direction §15).
	XPPerMatch = 100,
	XPPerElimination = 25,
	XPPerWin = 150,
	XPPer100PaintCells = 10,
	AccountLevelXP = 1000,
}

-- Perspective-relative paint colors (Direction §9). Friendly/own paint is always the
-- "safe" color and every hostile faction is the single "danger" color.
Tuning.Colors = {
	Standard = {
		Safe = Color3.fromRGB(46, 214, 92),
		Danger = Color3.fromRGB(236, 48, 60),
	},
	-- Accessibility: red/green colour-vision deficiency affects roughly 1 in 12 men.
	-- Same meaning, different hues. Players can toggle this in the Locker.
	ColorblindSafe = {
		Safe = Color3.fromRGB(40, 150, 255),
		Danger = Color3.fromRGB(255, 150, 20),
	},
	Neutral = Color3.fromRGB(226, 228, 236),
}

return Tuning

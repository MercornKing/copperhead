--!strict
--[[
	Canvas Yard: the first test arena (working title). Built from data so designers and
	agents can iterate on layout without hand-placing parts in Studio.

	Design intent (Direction §5): open, multi-axis, and full of surfaces whose ownership
	changes how people move.
		- Raised team bases with two ways down (ramps, jump-off ledges).
		- Mid lanes of long parallel walls for wall-run chains; paint one to cut the lane.
		- A central tower with a high ring of platforms; grapple anchors above it.
		- A roofed tunnel so ceilings matter, and a high bridge route over the middle.
		- Low cover in the open plaza for ground fights.
	Environment colours are muted and avoid both paint palettes so paint always reads (§9).

	Coordinates: floor top at y = 0, arena spans x -120..120, z -80..80.
]]

export type PartSpec = {
	Name: string,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Material: Enum.Material?,
	Faces: string?, -- paintable faces, nil = all
	Paintable: boolean,
	Anchor: boolean?, -- grapple anchor (marked visually)
}

export type MapSpec = {
	Name: string,
	Parts: { PartSpec },
	TeamSpawns: { { CFrame } },
	FreeSpawns: { CFrame },
	LobbySpawn: CFrame,
}

local STONE = Color3.fromRGB(232, 232, 240)
local SLATE = Color3.fromRGB(196, 200, 214)
-- Muted accents only: paint (green/red, or blue/orange in colour-blind mode) must always
-- be the most saturated thing in view.
local BLUE = Color3.fromRGB(162, 170, 198) -- periwinkle grey
local PURPLE = Color3.fromRGB(176, 156, 214) -- soft lavender
local SUN = Color3.fromRGB(236, 224, 176) -- sand
local STEEL = Color3.fromRGB(90, 96, 116)

local parts: { PartSpec } = {}

local function block(name: string, size: Vector3, cf: CFrame, color: Color3, faces: string?, paintable: boolean?)
	table.insert(parts, {
		Name = name,
		Size = size,
		CFrame = cf,
		Color = color,
		Faces = faces,
		Paintable = paintable ~= false,
	})
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

-- Mirror across the x = 0 plane, for symmetrical team halves.
local function mirrored(cf: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

local function both(name: string, size: Vector3, cf: CFrame, color: Color3, faces: string?)
	block(name .. "A", size, cf, color, faces)
	block(name .. "B", size, mirrored(cf), color, faces)
end

-- Ground and boundary ------------------------------------------------------------------
block("Floor", Vector3.new(240, 4, 160), at(0, -2, 0), STONE, "Top")
block("WallNorth", Vector3.new(248, 44, 4), at(0, 20, -82), SLATE, "Back")
block("WallSouth", Vector3.new(248, 44, 4), at(0, 20, 82), SLATE, "Front")
block("WallWest", Vector3.new(4, 44, 160), at(-122, 20, 0), SLATE, "Right")
block("WallEast", Vector3.new(4, 44, 160), at(122, 20, 0), SLATE, "Left")

-- Team bases: raised decks, a front ramp and a side ramp each --------------------------
both("BaseDeck", Vector3.new(28, 8, 56), at(-104, 4, 0), SLATE)
both("BaseBackWall", Vector3.new(4, 20, 56), at(-116, 18, 0), BLUE)
local rampAngle = math.rad(-18)
both("BaseRampFront", Vector3.new(26, 2, 14), at(-78, 3.2, 0) * CFrame.Angles(0, 0, rampAngle), SLATE)
both("BaseRampSide", Vector3.new(14, 2, 24), at(-104, 3.2, 38) * CFrame.Angles(math.rad(18), 0, 0), SLATE)
both("BaseCoverLeft", Vector3.new(4, 5, 10), at(-92, 10.5, -18), PURPLE)
both("BaseCoverRight", Vector3.new(4, 5, 10), at(-92, 10.5, 18), PURPLE)

-- Wall-run lanes: two pairs of long walls, north and south of centre --------------------
for _, z in { -50, -38, 38, 50 } do
	block("LaneWall" .. z, Vector3.new(64, 18, 2), at(0, 9, z), if math.abs(z) == 50 then BLUE else PURPLE)
end
-- Short staggered walls leading into the lanes from each base.
both("LaneLeadInN", Vector3.new(26, 14, 2), at(-58, 7, -44), SLATE)
both("LaneLeadInS", Vector3.new(26, 14, 2), at(-58, 7, 44), SLATE)

-- Central tower and high ring -----------------------------------------------------------
block("Tower", Vector3.new(14, 34, 14), at(0, 17, 0), STEEL)
block("TowerTop", Vector3.new(22, 2, 22), at(0, 35, 0), SUN)
for i = 0, 3 do
	local angle = i * math.pi / 2 + math.pi / 4
	local x, z = math.cos(angle) * 30, math.sin(angle) * 30
	block("RingPlatform" .. i, Vector3.new(12, 2, 12), at(x, 22, z), SUN)
end

-- High bridge route: base roof -> floating steps -> tower top ---------------------------
both("BaseRoof", Vector3.new(20, 2, 28), at(-104, 26, 0), BLUE)
both("SkyStep1", Vector3.new(12, 2, 12), at(-80, 30, 0), SUN)
both("SkyStep2", Vector3.new(12, 2, 12), at(-62, 32, 0), SUN)
both("SkyStep3", Vector3.new(10, 2, 10), at(-47, 34, 0), SUN)
both("SkyBridge", Vector3.new(34, 2, 6), at(-24, 35, 0), SLATE)

-- Covered tunnel along the south edge: ceilings are paintable too ----------------------
block("TunnelRoof", Vector3.new(70, 3, 16), at(0, 13.5, 68), SLATE, "Top,Bottom")
block("TunnelInnerWall", Vector3.new(70, 12, 2), at(0, 6, 59), BLUE, "Front,Back")

-- Open plaza cover ----------------------------------------------------------------------
for _, spec in
	{
		{ -30, -18 },
		{ -22, 20 },
		{ 30, 18 },
		{ 22, -20 },
		{ -44, 0 },
		{ 44, 0 },
	}
do
	block("Cover" .. spec[1] .. "_" .. spec[2], Vector3.new(8, 5, 3), at(spec[1], 2.5, spec[2]), PURPLE)
end
both("Pillar", Vector3.new(6, 26, 6), at(-40, 13, -66), SLATE)
both("PillarS", Vector3.new(6, 26, 6), at(-40, 13, 66), SLATE)

-- Grapple anchors: hanging blocks you can only reach with the hook. Paint them to deny.
for _, pos in
	{
		Vector3.new(0, 52, -30),
		Vector3.new(0, 52, 30),
		Vector3.new(-50, 48, 0),
		Vector3.new(50, 48, 0),
		Vector3.new(-70, 44, -60),
		Vector3.new(70, 44, 60),
		Vector3.new(-70, 44, 60),
		Vector3.new(70, 44, -60),
	}
do
	table.insert(parts, {
		Name = "Anchor",
		Size = Vector3.new(5, 5, 5),
		CFrame = CFrame.new(pos),
		Color = Color3.fromRGB(255, 244, 214), -- glowing warm white, easy to spot
		Paintable = true,
		Anchor = true,
	})
end

-- Spawns --------------------------------------------------------------------------------
local teamA: { CFrame } = {}
for _, z in { -20, -8, 8, 20 } do
	table.insert(teamA, CFrame.lookAt(Vector3.new(-106, 11, z), Vector3.new(0, 11, z)))
end
local teamB: { CFrame } = {}
for _, cf in teamA do
	teamB[#teamB + 1] =
		CFrame.lookAt(Vector3.new(-cf.Position.X, cf.Position.Y, cf.Position.Z), Vector3.new(0, 11, cf.Position.Z))
end

local free: { CFrame } = {}
for _, cf in teamA do
	table.insert(free, cf)
end
for _, cf in teamB do
	table.insert(free, cf)
end
for _, pos in
	{
		Vector3.new(0, 3, -66),
		Vector3.new(0, 3, 30),
		Vector3.new(-60, 3, -20),
		Vector3.new(60, 3, 20),
		Vector3.new(-21, 25, -21),
		Vector3.new(21, 25, 21),
		Vector3.new(0, 38, 0),
	}
do
	table.insert(free, CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0) + Vector3.new(0.01, 0, 0)))
end

local map: MapSpec = {
	Name = "Canvas Yard",
	Parts = parts,
	TeamSpawns = { teamA, teamB },
	FreeSpawns = free,
	LobbySpawn = CFrame.new(0, 38, 0),
}

return map

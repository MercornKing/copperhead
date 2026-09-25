--!strict
--[[
	PaintRenderer: draws the arena's paint for this player.

	Keeps a mirror of the server's paint state and shows each painted cell as a thin tile
	just off its surface, coloured by perspective (Palette). Tiles live in a client-only
	folder, are pooled, and never collide, cast shadows or block raycasts.

	Upgrade path for larger arenas: per-surface EditableImage textures instead of tiles
	(see docs/ARCHITECTURE.md §Rendering).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tuning = require(Shared.Config.Tuning)
local Net = require(Shared.Net)
local PaintRegistry = require(Shared.Paint.PaintRegistry)
local PaintState = require(Shared.Paint.PaintState)
local PaintCodec = require(Shared.Paint.PaintCodec)
local Factions = require(Shared.Paint.Factions)
local Palette = require(script.Parent.Palette)

local PaintRenderer = {}

local registry: PaintRegistry.Registry? = nil
local mirror: PaintState.State? = nil
local tiles: { [number]: Part } = {}
local pool: { Part } = {}
local layer: Folder
local pendingBeforeReady: { buffer } = {}

local TILE_THICKNESS = 0.08
local TILE_GROW = 1.04 -- slight overlap so neighbouring tiles read as one continuous coat

-- Tiny deterministic per-cell shade so large areas look painted, not flat.
local function shade(cell: number, color: Color3): Color3
	local h = ((cell * 2654435761) % 997) / 997
	if h < 0.5 then
		return color:Lerp(Color3.new(0, 0, 0), (0.5 - h) * 0.12)
	end
	return color:Lerp(Color3.new(1, 1, 1), (h - 0.5) * 0.16)
end

local function takeTile(): Part
	local tile = table.remove(pool)
	if tile then
		return tile
	end
	local p = Instance.new("Part")
	p.Name = "Paint"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function draw(cell: number, owner: number)
	local reg = registry
	if not reg then
		return
	end
	local tile = tiles[cell]
	if owner == Factions.NONE then
		if tile then
			tiles[cell] = nil
			tile.Parent = nil
			table.insert(pool, tile)
		end
		return
	end
	if not tile then
		local frame, su, sv = PaintRegistry.CellFrame(reg, cell)
		if not frame then
			return
		end
		local t = takeTile()
		t.Size = Vector3.new(su * TILE_GROW, TILE_THICKNESS, sv * TILE_GROW)
		-- Tiny per-cell height jitter stops overlapping edges from z-fighting.
		local lift = Tuning.Paint.SurfaceOffset + ((cell % 7) * 0.002)
		t.CFrame = frame * CFrame.new(0, lift, 0)
		t.Parent = layer
		tiles[cell] = t
		tile = t
	end
	(tile :: Part).Color = shade(cell, Palette.ForFaction(owner))
end

local function apply(cell: number, owner: number)
	local m = mirror
	if m and PaintState.Set(m, cell, owner) then
		draw(cell, owner)
	elseif m and owner ~= 0 and not tiles[cell] then
		draw(cell, owner)
	end
end

local function recolorAll()
	local m = mirror
	if not m then
		return
	end
	for cell, tile in tiles do
		tile.Color = shade(cell, Palette.ForFaction(PaintState.Get(m, cell)))
	end
end

-- Relation of the surface at a raycast hit, from this player's point of view.
function PaintRenderer.RelationAt(part: BasePart, position: Vector3, normal: Vector3): Factions.Relation
	local reg, m = registry, mirror
	if not reg or not m then
		return "None"
	end
	local cell = PaintRegistry.CellFromHit(reg, part, position, normal)
	if not cell then
		return "None"
	end
	return Factions.Relation(PaintState.Get(m, cell), Palette.MyFaction())
end

function PaintRenderer.Layer(): Folder
	return layer
end

function PaintRenderer.Init()
	layer = Instance.new("Folder")
	layer.Name = "PaintLayer"
	layer.Parent = workspace

	-- Deltas can arrive before the registry is ready; buffer them.
	Net.Event("PaintDelta").OnClientEvent:Connect(function(data: buffer)
		if not mirror then
			table.insert(pendingBeforeReady, data)
			return
		end
		PaintCodec.DecodeDelta(data, apply)
	end)
	Net.Event("PaintSnapshot").OnClientEvent:Connect(function(chunk: buffer)
		if mirror then
			PaintCodec.DecodeSnapshotChunk(chunk, apply)
		end
	end)
	Palette.Changed:Connect(recolorAll)
end

function PaintRenderer.Start()
	task.spawn(function()
		local arena = workspace:WaitForChild("Arena")
		local reg = PaintRegistry.Mirror(arena:WaitForChild("Paintable"))
		registry = reg
		mirror = PaintState.new(reg.Total)
		for _, data in pendingBeforeReady do
			PaintCodec.DecodeDelta(data, apply)
		end
		table.clear(pendingBeforeReady)
		Net.Event("RequestPaintSnapshot"):FireServer()

		-- The arena is rebuilt only on server restart, but guard against it anyway.
		arena.Destroying:Connect(function()
			for _, tile in tiles do
				tile:Destroy()
			end
			table.clear(tiles)
			registry, mirror = nil, nil
		end)
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("Faction"):Connect(recolorAll)
end

return PaintRenderer

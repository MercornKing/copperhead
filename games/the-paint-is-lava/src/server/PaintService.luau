--!strict
--[[
	PaintService: the authoritative owner of every paint cell.

	- Weapons call PaintSphere(); the service flips cells, remembers who painted them (so a
	  trap elimination credits the painter), and batches changes.
	- Every BroadcastInterval it sends one compact delta to all clients.
	- A joining client asks for a snapshot once its renderer is ready.
	- Optional decay (Tuning.Paint.DecaySeconds) fades old paint when enabled.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tuning = require(Shared.Config.Tuning)
local Net = require(Shared.Net)
local PaintRegistry = require(Shared.Paint.PaintRegistry)
local PaintState = require(Shared.Paint.PaintState)
local PaintCodec = require(Shared.Paint.PaintCodec)

local PaintService = {}

local registry: PaintRegistry.Registry
local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Include
local state: PaintState.State
local painterOf: { [number]: Player } = {}
local paintedAt: { [number]: number } = {}
local dirty: { [number]: boolean } = {}
local dirtyCount = 0
local matchPaint: { [Player]: number } = {}
local lastSnapshot: { [Player]: number } = {}

local function markDirty(cell: number)
	if not dirty[cell] then
		dirty[cell] = true
		dirtyCount += 1
	end
end

function PaintService.Init(paintableFolder: Instance)
	registry = PaintRegistry.Assign(paintableFolder, Tuning.Paint.CellSize)
	-- Line of sight is blocked by all solid arena geometry, paintable or not.
	losParams.FilterDescendantsInstances = { paintableFolder.Parent or paintableFolder }
	state = PaintState.new(registry.Total)
	print(string.format("[Paint] %d paintable parts, %d cells", #registry.Entries, registry.Total))
end

function PaintService.Registry(): PaintRegistry.Registry
	return registry
end

-- True when nothing solid in the arena lies between two points.
function PaintService.LineOfSight(from: Vector3, to: Vector3): boolean
	local offset = to - from
	local hit = workspace:Raycast(from, offset, losParams)
	return hit == nil or (hit.Position - from).Magnitude >= offset.Magnitude - 0.05
end

--[[
	Paint every surface within `radius` of `point` that is visible from it, for `faction`.
	Pass the surface `normal` for impacts so the burst starts just off the surface.
	Returns the number of cells whose owner changed.
]]
function PaintService.PaintSphere(
	point: Vector3,
	radius: number,
	faction: number,
	painter: Player?,
	normal: Vector3?
): number
	if faction == 0 then
		return 0
	end
	local origin = if normal then point + normal * 0.3 else point
	local now = os.clock()
	local changed = 0
	for _, cell in PaintRegistry.CellsInSphere(registry, origin, radius, losParams) do
		local flipped, previous = PaintState.Hit(state, cell, faction, Tuning.Paint.HitsToFlip)
		if flipped or previous == faction then
			if painter then
				painterOf[cell] = painter
			end
			paintedAt[cell] = now
		end
		if flipped then
			changed += 1
			markDirty(cell)
		end
	end
	if painter and changed > 0 then
		matchPaint[painter] = (matchPaint[painter] or 0) + changed
	end
	if radius >= 6 then
		Net.Event("PaintImpact"):FireAllClients(point, radius, faction)
	end
	return changed
end

-- Owner faction and cell id at a raycast hit, or (0, nil) if the surface isn't paintable.
function PaintService.FactionAtHit(part: BasePart, position: Vector3, normal: Vector3): (number, number?)
	local cell = PaintRegistry.CellFromHit(registry, part, position, normal)
	if not cell then
		return 0, nil
	end
	return PaintState.Get(state, cell), cell
end

function PaintService.PainterOf(cell: number): Player?
	local p = painterOf[cell]
	if p and p.Parent == Players then
		return p
	end
	return nil
end

function PaintService.Coverage(faction: number): number
	return PaintState.Count(state, faction)
end

-- Per-player cells painted since the last call; resets the tally.
function PaintService.TakeMatchPaint(): { [Player]: number }
	local out = matchPaint
	matchPaint = {}
	return out
end

local function sendSnapshot(target: Player?)
	local chunks = PaintCodec.EncodeSnapshot(state.Owner, state.Total, Tuning.Paint.SnapshotChunkBytes)
	local event = Net.Event("PaintSnapshot")
	for index, chunk in chunks do
		if target then
			event:FireClient(target, chunk, index, #chunks)
		else
			event:FireAllClients(chunk, index, #chunks)
		end
	end
end

-- Remove all paint (new match). Clients receive a fresh snapshot.
function PaintService.Clear()
	PaintState.Clear(state)
	table.clear(painterOf)
	table.clear(paintedAt)
	table.clear(dirty)
	dirtyCount = 0
	sendSnapshot(nil)
end

-- Remove one faction's paint (used when a Free-for-All faction id must be recycled).
function PaintService.ClearFaction(faction: number)
	for cell = 0, state.Total - 1 do
		if PaintState.Get(state, cell) == faction then
			PaintState.Set(state, cell, 0)
			painterOf[cell] = nil
			markDirty(cell)
		end
	end
end

local function flush()
	if dirtyCount == 0 then
		return
	end
	local cells: { number } = {}
	local factions: { number } = {}
	for cell in dirty do
		table.insert(cells, cell)
		table.insert(factions, PaintState.Get(state, cell))
	end
	table.clear(dirty)
	dirtyCount = 0
	Net.Event("PaintDelta"):FireAllClients(PaintCodec.EncodeDelta(cells, factions))
end

local function decay()
	local lifetime = Tuning.Paint.DecaySeconds
	if lifetime <= 0 then
		return
	end
	local cutoff = os.clock() - lifetime
	for cell, t in paintedAt do
		if t < cutoff then
			paintedAt[cell] = nil
			painterOf[cell] = nil
			if PaintState.Set(state, cell, 0) then
				markDirty(cell)
			end
		end
	end
end

function PaintService.Start()
	Net.Event("RequestPaintSnapshot").OnServerEvent:Connect(function(player: Player)
		local now = os.clock()
		if lastSnapshot[player] and now - lastSnapshot[player] < 5 then
			return
		end
		lastSnapshot[player] = now
		sendSnapshot(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastSnapshot[player] = nil
		matchPaint[player] = nil
	end)

	local sinceFlush, sinceDecay = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		sinceFlush += dt
		sinceDecay += dt
		if sinceFlush >= Tuning.Paint.BroadcastInterval then
			sinceFlush = 0
			flush()
		end
		if sinceDecay >= 0.5 then
			sinceDecay = 0
			decay()
		end
	end)
end

return PaintService

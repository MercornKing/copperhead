--!strict
--[[
	PaintState: the arena's paint as two flat byte arrays.
		Owner[cell]    faction id (0 = unpainted)
		Strength[cell] how many more hostile hits the cell can absorb before flipping
	The server holds the authoritative copy; every client holds a mirror fed by PaintCodec.
	One byte per cell keeps even a very large arena to tens of kilobytes.
]]

local PaintState = {}

export type State = {
	Owner: buffer,
	Strength: buffer,
	Total: number,
	Counts: { [number]: number }, -- cells owned per faction
}

function PaintState.new(total: number): State
	return {
		Owner = buffer.create(math.max(total, 1)),
		Strength = buffer.create(math.max(total, 1)),
		Total = total,
		Counts = {},
	}
end

function PaintState.Get(state: State, cell: number): number
	if cell < 0 or cell >= state.Total then
		return 0
	end
	return buffer.readu8(state.Owner, cell)
end

local function setOwner(state: State, cell: number, owner: number, previous: number)
	buffer.writeu8(state.Owner, cell, owner)
	if previous ~= 0 then
		state.Counts[previous] = (state.Counts[previous] or 1) - 1
	end
	if owner ~= 0 then
		state.Counts[owner] = (state.Counts[owner] or 0) + 1
	end
end

-- Force a cell to an owner (client mirror, clears, snapshots). Returns true if it changed.
function PaintState.Set(state: State, cell: number, owner: number): boolean
	if cell < 0 or cell >= state.Total then
		return false
	end
	local previous = buffer.readu8(state.Owner, cell)
	buffer.writeu8(state.Strength, cell, if owner == 0 then 0 else 1)
	if previous == owner then
		return false
	end
	setOwner(state, cell, owner, previous)
	return true
end

--[[
	Apply one paint hit from `faction`. With hitsToFlip = 1 every hit repaints the cell.
	Higher values make contested territory take several hits to steal, while repeated
	friendly hits "thicken" your own paint up to that cap.
	Returns (ownerChanged, previousOwner).
]]
function PaintState.Hit(state: State, cell: number, faction: number, hitsToFlip: number): (boolean, number)
	if cell < 0 or cell >= state.Total or faction == 0 then
		return false, 0
	end
	local previous = buffer.readu8(state.Owner, cell)
	local strength = buffer.readu8(state.Strength, cell)
	local cap = math.clamp(hitsToFlip, 1, 255)

	if previous == faction then
		buffer.writeu8(state.Strength, cell, math.min(cap, strength + 1))
		return false, previous
	end

	if previous ~= 0 and strength > 1 then
		buffer.writeu8(state.Strength, cell, strength - 1)
		return false, previous
	end

	buffer.writeu8(state.Strength, cell, 1)
	setOwner(state, cell, faction, previous)
	return true, previous
end

function PaintState.Clear(state: State)
	buffer.fill(state.Owner, 0, 0)
	buffer.fill(state.Strength, 0, 0)
	table.clear(state.Counts)
end

function PaintState.Count(state: State, faction: number): number
	return state.Counts[faction] or 0
end

return PaintState

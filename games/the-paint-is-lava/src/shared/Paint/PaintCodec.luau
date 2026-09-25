--!strict
--[[
	PaintCodec: compact wire formats for paint.

	Delta (sent ~20x/second while paint is changing):
		repeated { u32 cellId, u8 faction }                5 bytes per changed cell
	Snapshot chunk (sent once to a joining player, split across events):
		u32 startCell, then repeated { u8 faction, u32 runLength }
	Run-length encoding makes a mostly-unpainted arena nearly free to send.
]]

local PaintCodec = {}

local DELTA_STRIDE = 5
local RUN_STRIDE = 5

export type Change = { number } -- { cellId, faction }

function PaintCodec.EncodeDelta(cells: { number }, factions: { number }): buffer
	local n = #cells
	local out = buffer.create(n * DELTA_STRIDE)
	for i = 1, n do
		local at = (i - 1) * DELTA_STRIDE
		buffer.writeu32(out, at, cells[i])
		buffer.writeu8(out, at + 4, factions[i])
	end
	return out
end

function PaintCodec.DecodeDelta(data: buffer, apply: (cell: number, faction: number) -> ())
	local n = buffer.len(data) // DELTA_STRIDE
	for i = 0, n - 1 do
		local at = i * DELTA_STRIDE
		apply(buffer.readu32(data, at), buffer.readu8(data, at + 4))
	end
end

-- Split the owner array into RLE chunks no larger than maxBytes each.
function PaintCodec.EncodeSnapshot(owner: buffer, total: number, maxBytes: number): { buffer }
	local chunks: { buffer } = {}
	local runsPerChunk = math.max(1, (maxBytes - 4) // RUN_STRIDE)

	local runFactions: { number } = {}
	local runLengths: { number } = {}
	local chunkStart = 0

	local function flush()
		if #runFactions == 0 then
			return
		end
		local out = buffer.create(4 + #runFactions * RUN_STRIDE)
		buffer.writeu32(out, 0, chunkStart)
		for i = 1, #runFactions do
			local at = 4 + (i - 1) * RUN_STRIDE
			buffer.writeu8(out, at, runFactions[i])
			buffer.writeu32(out, at + 1, runLengths[i])
		end
		table.insert(chunks, out)
		table.clear(runFactions)
		table.clear(runLengths)
	end

	local cell = 0
	while cell < total do
		local faction = buffer.readu8(owner, cell)
		local length = 1
		while cell + length < total and buffer.readu8(owner, cell + length) == faction do
			length += 1
		end
		if #runFactions == 0 then
			chunkStart = cell
		end
		table.insert(runFactions, faction)
		table.insert(runLengths, length)
		cell += length
		if #runFactions >= runsPerChunk then
			flush()
		end
	end
	flush()
	return chunks
end

function PaintCodec.DecodeSnapshotChunk(data: buffer, apply: (cell: number, faction: number) -> ())
	local cell = buffer.readu32(data, 0)
	local runs = (buffer.len(data) - 4) // RUN_STRIDE
	for i = 0, runs - 1 do
		local at = 4 + i * RUN_STRIDE
		local faction = buffer.readu8(data, at)
		local length = buffer.readu32(data, at + 1)
		for c = cell, cell + length - 1 do
			apply(c, faction)
		end
		cell += length
	end
end

return PaintCodec

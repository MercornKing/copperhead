--!strict
--[[
	PaintRegistry: binds PaintGrid layouts to the real paintable parts in the arena.

	The server builds it once after the arena is generated, stamping every part with a
	PaintOffset attribute and the folder with the totals. Clients rebuild the identical
	registry from those replicated attributes, so both sides agree on every cell id
	without ever sending geometry over the network.
]]

local PaintGrid = require(script.Parent.PaintGrid)

local PaintRegistry = {}

export type Entry = {
	Part: BasePart,
	Layout: PaintGrid.PartLayout,
}

export type Registry = {
	Folder: Instance,
	Entries: { Entry },
	ByPart: { [BasePart]: Entry },
	Total: number,
	CellSize: number,
	Overlap: OverlapParams,
	Raycast: RaycastParams,
}

local function collectParts(folder: Instance): { BasePart }
	local parts: { BasePart } = {}
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	return parts
end

local function makeQueryParams(folder: Instance): (OverlapParams, RaycastParams)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { folder }
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Include
	ray.FilterDescendantsInstances = { folder }
	return overlap, ray
end

local function finish(folder: Instance, entries: { Entry }, total: number, cellSize: number): Registry
	table.sort(entries, function(a, b)
		return a.Layout.Offset < b.Layout.Offset
	end)
	local byPart: { [BasePart]: Entry } = {}
	for _, e in entries do
		byPart[e.Part] = e
	end
	local overlap, ray = makeQueryParams(folder)
	return {
		Folder = folder,
		Entries = entries,
		ByPart = byPart,
		Total = total,
		CellSize = cellSize,
		Overlap = overlap,
		Raycast = ray,
	}
end

-- Server: assign offsets in a stable order and publish them as attributes.
function PaintRegistry.Assign(folder: Instance, cellSize: number): Registry
	local parts = collectParts(folder)
	table.sort(parts, function(a, b)
		local ia = (a:GetAttribute("PaintIndex") :: number?) or 0
		local ib = (b:GetAttribute("PaintIndex") :: number?) or 0
		if ia ~= ib then
			return ia < ib
		end
		return a:GetFullName() < b:GetFullName()
	end)

	local entries: { Entry } = {}
	local cursor = 0
	for _, part in parts do
		local mask = PaintGrid.ParseFaceMask(part:GetAttribute("PaintFaces") :: string?)
		local layout = PaintGrid.Layout(part.Size, cellSize, mask, cursor)
		part:SetAttribute("PaintOffset", cursor)
		cursor += layout.CellCount
		table.insert(entries, { Part = part, Layout = layout })
	end

	folder:SetAttribute("PaintCellSize", cellSize)
	folder:SetAttribute("PaintTotalCells", cursor)
	folder:SetAttribute("PaintPartCount", #parts)
	folder:SetAttribute("PaintReady", true)
	return finish(folder, entries, cursor, cellSize)
end

-- Client: wait for the server's stamp and every part to replicate, then mirror it.
function PaintRegistry.Mirror(folder: Instance): Registry
	while folder:GetAttribute("PaintReady") ~= true do
		folder.AttributeChanged:Wait()
	end
	local expected = folder:GetAttribute("PaintPartCount") :: number
	local parts = collectParts(folder)
	while #parts < expected do
		task.wait(0.1)
		parts = collectParts(folder)
	end

	local cellSize = folder:GetAttribute("PaintCellSize") :: number
	local entries: { Entry } = {}
	for _, part in parts do
		local offset = part:GetAttribute("PaintOffset") :: number?
		if offset then
			local mask = PaintGrid.ParseFaceMask(part:GetAttribute("PaintFaces") :: string?)
			table.insert(entries, { Part = part, Layout = PaintGrid.Layout(part.Size, cellSize, mask, offset) })
		end
	end
	return finish(folder, entries, folder:GetAttribute("PaintTotalCells") :: number, cellSize)
end

-- Cell under a raycast hit (part + world position + world normal).
function PaintRegistry.CellFromHit(reg: Registry, part: BasePart, position: Vector3, normal: Vector3): number?
	local entry = reg.ByPart[part]
	if not entry then
		return nil
	end
	local cf = part.CFrame
	local face = PaintGrid.FaceFromLocalNormal(cf:VectorToObjectSpace(normal))
	return PaintGrid.CellAt(entry.Layout, face, cf:PointToObjectSpace(position))
end

-- Every cell on every paintable surface within `radius` of a world point.
function PaintRegistry.CellsInSphere(reg: Registry, point: Vector3, radius: number): { number }
	local out: { number } = {}
	-- Pad the broadphase slightly so a hit landing exactly on a face edge still finds it.
	local parts = workspace:GetPartBoundsInRadius(point, radius + 0.5, reg.Overlap)
	for _, part in parts do
		local entry = reg.ByPart[part]
		if entry then
			PaintGrid.CellsInSphere(entry.Layout, part.CFrame:PointToObjectSpace(point), radius, out)
		end
	end
	return out
end

-- World frame and size of a cell, for rendering. Returns nil for an unknown id.
function PaintRegistry.CellFrame(reg: Registry, cell: number): (CFrame?, number, number)
	local entry = PaintGrid.FindOwner(reg.Entries, function(e: Entry)
		return e.Layout
	end, cell)
	if not entry then
		return nil, 0, 0
	end
	local center, face, su, sv = PaintGrid.CellGeometry(entry.Layout, cell)
	if not center or not face then
		return nil, 0, 0
	end
	local localFrame = CFrame.fromMatrix(center, face.U, face.N, face.V)
	return entry.Part.CFrame * localFrame, su, sv
end

return PaintRegistry

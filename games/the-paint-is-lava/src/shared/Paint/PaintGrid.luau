--!strict
--[[
	PaintGrid: pure geometry that turns paintable parts into a flat array of paint cells.

	Every paintable block part is split per face into a grid of roughly CellSize-stud cells.
	Each cell gets a global integer id, so the whole arena's paint state is one byte array
	(see PaintState). Server and clients compute identical layouts from the part's Size and
	its PaintOffset attribute, so only (cellId, faction) pairs ever cross the network.

	Face frames are right-handed (U x N = V) so a cell's render CFrame is
	CFrame.fromMatrix(center, U, N, V).
]]

local PaintGrid = {}

export type Face = {
	Name: string,
	N: Vector3, -- outward normal (part-local)
	U: Vector3, -- in-plane axis 1
	V: Vector3, -- in-plane axis 2
}

local FACES: { Face } = {
	{ Name = "Top", N = Vector3.new(0, 1, 0), U = Vector3.new(1, 0, 0), V = Vector3.new(0, 0, 1) },
	{ Name = "Bottom", N = Vector3.new(0, -1, 0), U = Vector3.new(1, 0, 0), V = Vector3.new(0, 0, -1) },
	{ Name = "Right", N = Vector3.new(1, 0, 0), U = Vector3.new(0, 0, 1), V = Vector3.new(0, 1, 0) },
	{ Name = "Left", N = Vector3.new(-1, 0, 0), U = Vector3.new(0, 0, -1), V = Vector3.new(0, 1, 0) },
	{ Name = "Back", N = Vector3.new(0, 0, 1), U = Vector3.new(-1, 0, 0), V = Vector3.new(0, 1, 0) },
	{ Name = "Front", N = Vector3.new(0, 0, -1), U = Vector3.new(1, 0, 0), V = Vector3.new(0, 1, 0) },
}
PaintGrid.Faces = FACES

-- A hit point may sit this far "inside" a face (float error) and still count as on it.
-- Kept small so paint never bleeds through to the far side of a wall.
local INSIDE_TOLERANCE = 0.35

export type SurfaceLayout = {
	Face: number,
	Offset: number, -- global id of this face's first cell
	NU: number,
	NV: number,
	CU: number, -- actual cell size along U
	CV: number,
	HalfN: number,
	SizeU: number,
	SizeV: number,
}

export type PartLayout = {
	Offset: number,
	CellCount: number,
	Surfaces: { [number]: SurfaceLayout }, -- keyed by face index; missing = not paintable
}

local function axisExtent(size: Vector3, axis: Vector3): number
	return math.abs(size.X * axis.X) + math.abs(size.Y * axis.Y) + math.abs(size.Z * axis.Z)
end

-- "Top,Right" -> { [1] = true, [3] = true }. nil/empty = every face.
function PaintGrid.ParseFaceMask(mask: string?): { [number]: boolean }?
	if mask == nil or mask == "" or mask == "All" then
		return nil
	end
	local set: { [number]: boolean } = {}
	for name in string.gmatch(mask, "[^,%s]+") do
		for index, face in FACES do
			if face.Name == name then
				set[index] = true
			end
		end
	end
	return set
end

function PaintGrid.Layout(size: Vector3, cellSize: number, faceMask: { [number]: boolean }?, offset: number): PartLayout
	local surfaces: { [number]: SurfaceLayout } = {}
	local cursor = offset
	for index, face in FACES do
		if faceMask == nil or faceMask[index] then
			local sizeU = axisExtent(size, face.U)
			local sizeV = axisExtent(size, face.V)
			local nu = math.max(1, math.ceil(sizeU / cellSize - 1e-6))
			local nv = math.max(1, math.ceil(sizeV / cellSize - 1e-6))
			surfaces[index] = {
				Face = index,
				Offset = cursor,
				NU = nu,
				NV = nv,
				CU = sizeU / nu,
				CV = sizeV / nv,
				HalfN = axisExtent(size, face.N) / 2,
				SizeU = sizeU,
				SizeV = sizeV,
			}
			cursor += nu * nv
		end
	end
	return { Offset = offset, CellCount = cursor - offset, Surfaces = surfaces }
end

-- Face whose outward normal best matches a part-local normal.
function PaintGrid.FaceFromLocalNormal(normal: Vector3): number
	local best, bestDot = 1, -math.huge
	for index, face in FACES do
		local d = face.N:Dot(normal)
		if d > bestDot then
			best, bestDot = index, d
		end
	end
	return best
end

-- Global cell id at a part-local point on the given face, or nil if that face isn't paintable.
function PaintGrid.CellAt(layout: PartLayout, faceIndex: number, localPoint: Vector3): number?
	local s = layout.Surfaces[faceIndex]
	if not s then
		return nil
	end
	local face = FACES[faceIndex]
	local pu = localPoint:Dot(face.U) + s.SizeU / 2
	local pv = localPoint:Dot(face.V) + s.SizeV / 2
	local i = math.clamp(math.floor(pu / s.CU), 0, s.NU - 1)
	local j = math.clamp(math.floor(pv / s.CV), 0, s.NV - 1)
	return s.Offset + j * s.NU + i
end

--[[
	Append every cell of this part whose centre lies within `radius` of `localPoint`
	(part-local). Only faces the point is on or in front of are considered, so a blast on
	one side of a wall never paints the other side. The cell directly under the point is
	always included, so even tiny-radius weapons leave a mark.
]]
function PaintGrid.CellsInSphere(layout: PartLayout, localPoint: Vector3, radius: number, out: { number })
	for index, s in layout.Surfaces do
		local face = FACES[index]
		local d = localPoint:Dot(face.N) - s.HalfN
		if d >= -INSIDE_TOLERANCE and d <= radius then
			local dn = math.max(d, 0)
			local rp = math.sqrt(math.max(radius * radius - dn * dn, 0))
			local pu = localPoint:Dot(face.U) + s.SizeU / 2
			local pv = localPoint:Dot(face.V) + s.SizeV / 2

			local i0 = math.max(0, math.floor((pu - rp) / s.CU))
			local i1 = math.min(s.NU - 1, math.floor((pu + rp) / s.CU))
			local j0 = math.max(0, math.floor((pv - rp) / s.CV))
			local j1 = math.min(s.NV - 1, math.floor((pv + rp) / s.CV))

			local onFace = pu >= 0 and pu <= s.SizeU and pv >= 0 and pv <= s.SizeV
			local ci = math.clamp(math.floor(pu / s.CU), 0, s.NU - 1)
			local cj = math.clamp(math.floor(pv / s.CV), 0, s.NV - 1)
			local containingAdded = false

			local rp2 = rp * rp
			for j = j0, j1 do
				local dv = (j + 0.5) * s.CV - pv
				for i = i0, i1 do
					local du = (i + 0.5) * s.CU - pu
					if du * du + dv * dv <= rp2 then
						table.insert(out, s.Offset + j * s.NU + i)
						if i == ci and j == cj then
							containingAdded = true
						end
					end
				end
			end

			if onFace and not containingAdded and d <= math.max(1, radius * 0.5) then
				table.insert(out, s.Offset + cj * s.NU + ci)
			end
		end
	end
end

-- Part-local geometry of one cell, for rendering.
function PaintGrid.CellGeometry(layout: PartLayout, cellId: number): (Vector3?, Face?, number, number)
	for index, s in layout.Surfaces do
		local localId = cellId - s.Offset
		if localId >= 0 and localId < s.NU * s.NV then
			local face = FACES[index]
			local i = localId % s.NU
			local j = localId // s.NU
			local center = face.N * s.HalfN
				+ face.U * (-s.SizeU / 2 + (i + 0.5) * s.CU)
				+ face.V * (-s.SizeV / 2 + (j + 0.5) * s.CV)
			return center, face, s.CU, s.CV
		end
	end
	return nil, nil, 0, 0
end

--[[
	Registry helper: given layouts sorted by Offset, find which one owns a global id.
	Binary search, O(log parts).
]]
function PaintGrid.FindOwner<T>(sorted: { T }, getLayout: (T) -> PartLayout, cellId: number): T?
	local lo, hi = 1, #sorted
	while lo <= hi do
		local mid = (lo + hi) // 2
		local layout = getLayout(sorted[mid])
		if cellId < layout.Offset then
			hi = mid - 1
		elseif cellId >= layout.Offset + layout.CellCount then
			lo = mid + 1
		else
			return sorted[mid]
		end
	end
	return nil
end

return PaintGrid

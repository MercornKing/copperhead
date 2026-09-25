return function(t: any)
	local describe, it, expect = t.describe, t.it, t.expect
	local Vector3 = t.Vector3
	local PaintGrid = t.Load("src/shared/Paint/PaintGrid.luau")
	local PaintState = t.Load("src/shared/Paint/PaintState.luau")
	local PaintCodec = t.Load("src/shared/Paint/PaintCodec.luau")
	local Factions = t.Load("src/shared/Paint/Factions.luau")

	describe("Factions: your paint is safe, enemy paint hurts", function()
		it("unpainted is neutral", function()
			expect(Factions.Relation(0, 3)).toBe("None")
			expect(Factions.Hurts(0, 3)).toBeFalsy()
		end)
		it("own faction paint is friendly and safe", function()
			expect(Factions.Relation(3, 3)).toBe("Friendly")
			expect(Factions.Hurts(3, 3)).toBeFalsy()
		end)
		it("any other faction's paint is hostile, however many factions exist", function()
			for owner = 1, 254 do
				if owner ~= 7 then
					expect(Factions.Relation(owner, 7)).toBe("Hostile")
					expect(Factions.Hurts(owner, 7)).toBeTruthy()
				end
			end
		end)
		it("players without a faction are never considered enemies", function()
			expect(Factions.AreEnemies(0, 2)).toBeFalsy()
			expect(Factions.AreEnemies(1, 1)).toBeFalsy()
			expect(Factions.AreEnemies(1, 2)).toBeTruthy()
		end)
		it("environment paint is hostile to every player faction", function()
			for f = 1, 253 do
				expect(Factions.Hurts(Factions.ENVIRONMENT, f)).toBeTruthy()
			end
		end)
		it("the default allocator never hands out the environment faction", function()
			local a = Factions.NewAllocator()
			local last = nil
			for _ = 1, 300 do
				local id = a:Allocate()
				if id then
					last = id
				end
			end
			expect(last).toBe(253)
		end)
		it("allocator hands out unique ids and reuses released ones", function()
			local a = Factions.NewAllocator(1, 3)
			expect(a:Allocate()).toBe(1)
			expect(a:Allocate()).toBe(2)
			expect(a:Allocate()).toBe(3)
			expect(a:Allocate()).toBe(nil)
			a:Release(2)
			expect(a:InUse()).toBe(2)
			expect(a:Allocate()).toBe(2)
		end)
	end)

	describe("PaintGrid layout", function()
		it("face frames are right-handed so render CFrames never mirror", function()
			for _, face in PaintGrid.Faces do
				local cross = face.U:Cross(face.N)
				expect((cross - face.V).Magnitude).toBeNear(0)
			end
		end)
		it("counts cells per face and honours the face mask", function()
			local all = PaintGrid.Layout(Vector3.new(12, 3, 6), 3, nil, 0)
			-- top/bottom 4x2, right/left 2x1, back/front 4x1
			expect(all.CellCount).toBe(8 + 8 + 2 + 2 + 4 + 4)
			local top = PaintGrid.Layout(Vector3.new(12, 3, 6), 3, PaintGrid.ParseFaceMask("Top"), 100)
			expect(top.CellCount).toBe(8)
			expect(top.Surfaces[1].Offset).toBe(100)
			expect(top.Surfaces[2]).toBe(nil)
		end)
		it("stretches cells to fit sizes that are not multiples of the cell size", function()
			local l = PaintGrid.Layout(Vector3.new(10, 1, 10), 3, PaintGrid.ParseFaceMask("Top"), 0)
			expect(l.Surfaces[1].NU).toBe(4)
			expect(l.Surfaces[1].CU).toBeNear(2.5)
		end)
		it("maps a local normal to the right face", function()
			expect(PaintGrid.FaceFromLocalNormal(Vector3.new(0, 1, 0))).toBe(1)
			expect(PaintGrid.FaceFromLocalNormal(Vector3.new(0.1, -0.9, 0))).toBe(2)
			expect(PaintGrid.FaceFromLocalNormal(Vector3.new(0, 0, -1))).toBe(6)
		end)
		it("CellAt and CellGeometry agree", function()
			local l = PaintGrid.Layout(Vector3.new(30, 2, 30), 3, nil, 0)
			for faceIndex = 1, 6 do
				local s = l.Surfaces[faceIndex]
				for cell = s.Offset, s.Offset + s.NU * s.NV - 1, 7 do
					local center = PaintGrid.CellGeometry(l, cell)
					expect(PaintGrid.CellAt(l, faceIndex, center)).toBe(cell)
				end
			end
		end)
	end)

	describe("PaintGrid splash coverage", function()
		-- A 1-stud-thick wall standing on the XY plane: Back face at z=+0.5, Front at z=-0.5.
		local wall = PaintGrid.Layout(Vector3.new(30, 12, 1), 3, nil, 0)

		local function facesOf(cells: { number })
			local faces = {}
			for _, cell in cells do
				for index, s in wall.Surfaces do
					if cell >= s.Offset and cell < s.Offset + s.NU * s.NV then
						faces[index] = true
					end
				end
			end
			return faces
		end

		it("paint never bleeds through to the far side of a wall", function()
			local out = {}
			PaintGrid.CellsInSphere(wall, Vector3.new(0, 0, -0.5), 6, out)
			local faces = facesOf(out)
			expect(faces[6]).toBeTruthy() -- Front: hit side
			expect(faces[5]).toBe(nil) -- Back: far side
		end)
		it("a tiny radius still marks the cell it hit", function()
			local out = {}
			PaintGrid.CellsInSphere(wall, Vector3.new(4.2, 1.1, -0.5), 0.1, out)
			expect(#out).toBe(1)
			expect(out[1]).toBe(PaintGrid.CellAt(wall, 6, Vector3.new(4.2, 1.1, -0.5)))
		end)
		it("coverage grows with radius (launcher paints more than pistol)", function()
			local small, big = {}, {}
			PaintGrid.CellsInSphere(wall, Vector3.new(0, 0, -0.5), 1.6, small)
			PaintGrid.CellsInSphere(wall, Vector3.new(0, 0, -0.5), 11, big)
			expect(#big).toBeAtLeast(#small * 10)
		end)
		it("a burst in front of a wall paints it without touching the back", function()
			local out = {}
			PaintGrid.CellsInSphere(wall, Vector3.new(0, 0, -4), 6, out)
			local faces = facesOf(out)
			expect(faces[6]).toBeTruthy()
			expect(faces[5]).toBe(nil)
		end)
		it("a burst out of range paints nothing", function()
			local out = {}
			PaintGrid.CellsInSphere(wall, Vector3.new(0, 0, -20), 6, out)
			expect(#out).toBe(0)
		end)
		it("finds the owning part by global id", function()
			local layouts = {
				PaintGrid.Layout(Vector3.new(6, 1, 6), 3, nil, 0),
			}
			layouts[2] = PaintGrid.Layout(Vector3.new(6, 1, 6), 3, nil, layouts[1].CellCount)
			local id = function(l)
				return l
			end
			expect(PaintGrid.FindOwner(layouts, id, 0)).toBe(layouts[1])
			expect(PaintGrid.FindOwner(layouts, id, layouts[1].CellCount)).toBe(layouts[2])
			expect(PaintGrid.FindOwner(layouts, id, 10000)).toBe(nil)
		end)
	end)

	describe("PaintState", function()
		it("one hit repaints a cell when HitsToFlip = 1 and keeps counts", function()
			local s = PaintState.new(10)
			expect(PaintState.Hit(s, 3, 1, 1)).toBe(true)
			expect(PaintState.Get(s, 3)).toBe(1)
			expect(PaintState.Hit(s, 3, 2, 1)).toBe(true)
			expect(PaintState.Get(s, 3)).toBe(2)
			expect(PaintState.Count(s, 1)).toBe(0)
			expect(PaintState.Count(s, 2)).toBe(1)
		end)
		it("thick paint takes several hostile hits to flip", function()
			local s = PaintState.new(4)
			PaintState.Hit(s, 0, 1, 3)
			PaintState.Hit(s, 0, 1, 3)
			PaintState.Hit(s, 0, 1, 3) -- strength 3
			expect(PaintState.Hit(s, 0, 2, 3)).toBe(false)
			expect(PaintState.Hit(s, 0, 2, 3)).toBe(false)
			expect(PaintState.Hit(s, 0, 2, 3)).toBe(true)
			expect(PaintState.Get(s, 0)).toBe(2)
		end)
		it("ignores out-of-range cells and clears", function()
			local s = PaintState.new(2)
			expect(PaintState.Hit(s, 5, 1, 1)).toBe(false)
			PaintState.Set(s, 1, 4)
			PaintState.Clear(s)
			expect(PaintState.Get(s, 1)).toBe(0)
			expect(PaintState.Count(s, 4)).toBe(0)
		end)
	end)

	describe("PaintCodec", function()
		it("round-trips deltas", function()
			local data = PaintCodec.EncodeDelta({ 0, 70000, 4294967295 }, { 1, 254, 0 })
			local got = {}
			PaintCodec.DecodeDelta(data, function(cell, faction)
				table.insert(got, cell .. ":" .. faction)
			end)
			expect(table.concat(got, ",")).toBe("0:1,70000:254,4294967295:0")
		end)
		it("round-trips a snapshot split into many chunks", function()
			local total = 5000
			local s = PaintState.new(total)
			for cell = 0, total - 1 do
				if cell % 7 == 0 or (cell > 1000 and cell < 1500) then
					PaintState.Set(s, cell, (cell % 5) + 1)
				end
			end
			local chunks = PaintCodec.EncodeSnapshot(s.Owner, total, 200)
			expect(#chunks).toBeAtLeast(2)
			local mirror = PaintState.new(total)
			for _, chunk in chunks do
				expect(buffer.len(chunk)).toBeAtMost(200)
				PaintCodec.DecodeSnapshotChunk(chunk, function(cell, faction)
					PaintState.Set(mirror, cell, faction)
				end)
			end
			for cell = 0, total - 1 do
				if PaintState.Get(mirror, cell) ~= PaintState.Get(s, cell) then
					error("mismatch at cell " .. cell)
				end
			end
		end)
		it("an empty arena snapshot is tiny", function()
			local s = PaintState.new(100000)
			local chunks = PaintCodec.EncodeSnapshot(s.Owner, 100000, 30000)
			expect(#chunks).toBe(1)
			expect(buffer.len(chunks[1])).toBe(9)
		end)
	end)
end

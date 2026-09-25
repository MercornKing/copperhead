return function(t: any)
	local describe, it, expect = t.describe, t.it, t.expect
	local map = t.Load("src/server/Maps/CanvasYard.luau")
	local PaintGrid = t.Load("src/shared/Paint/PaintGrid.luau")
	local Tuning = t.Load("src/shared/Config/Tuning.luau")

	describe("Canvas Yard map", function()
		it("stays inside the paint cell budget", function()
			local total = 0
			for _, p in map.Parts do
				if p.Paintable then
					total += PaintGrid.Layout(p.Size, Tuning.Paint.CellSize, PaintGrid.ParseFaceMask(p.Faces), total).CellCount
				end
			end
			print(string.format("    Canvas Yard: %d paintable parts, %d cells", #map.Parts, total))
			expect(total).toBeAtMost(40000)
		end)
		it("every paintable part is thick enough that paint can't bleed through", function()
			for _, p in map.Parts do
				if p.Paintable then
					local thinnest = math.min(p.Size.X, p.Size.Y, p.Size.Z)
					if thinnest < 1 then
						error(p.Name .. " is only " .. thinnest .. " studs thick")
					end
				end
			end
		end)
		it("has spawns for both teams and plenty for free-for-all", function()
			expect(#map.TeamSpawns).toBe(2)
			expect(#map.TeamSpawns[1]).toBeAtLeast(4)
			expect(#map.TeamSpawns[2]).toBe(#map.TeamSpawns[1])
			expect(#map.FreeSpawns).toBeAtLeast(12)
		end)
		it("has grapple anchors and long wall-run walls", function()
			local anchors, longWalls = 0, 0
			for _, p in map.Parts do
				if p.Anchor then
					anchors += 1
				end
				local length = math.max(p.Size.X, p.Size.Z)
				if p.Size.Y >= 12 and length >= 50 and math.min(p.Size.X, p.Size.Z) <= 4 then
					longWalls += 1
				end
			end
			expect(anchors).toBeAtLeast(4)
			expect(longWalls).toBeAtLeast(4)
		end)
		it("team halves mirror each other", function()
			for i, cf in map.TeamSpawns[1] do
				local other = map.TeamSpawns[2][i]
				expect(other.Position.X).toBeNear(-cf.Position.X)
				expect(other.Position.Z).toBeNear(cf.Position.Z)
			end
		end)
	end)
end

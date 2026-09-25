--[[
	Run every *.spec.luau file:  lune run tests/run.luau   (from games/the-paint-is-lava)
	Exits non-zero on any failure so CI can gate on it.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local Harness = require("./harness")

local specs = {}
for _, name in fs.readDir("tests") do
	if string.match(name, "%.spec%.luau$") then
		table.insert(specs, name)
	end
end
table.sort(specs)

for _, name in specs do
	local spec = require("./" .. string.gsub(name, "%.luau$", "")) :: any
	spec(Harness)
end

local r = Harness.Results()
for _, failure in r.failures do
	print("FAIL " .. failure)
end
print(string.format("%d passed, %d failed (%d spec files)", r.passed, r.failed, #specs))
process.exit(if r.failed > 0 then 1 else 0)

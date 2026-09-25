--[[
	Offline test harness (runs under Lune, no Roblox Studio needed).

	Loads game modules exactly as written for Roblox: `script.Parent.X` resolves to files
	on disk and Roblox datatypes (Vector3, CFrame, Color3, BrickColor, Enum) come from
	Lune's Roblox library. Only pure modules are tested here; anything that needs a live
	DataModel is covered by the in-Studio playtest plan (docs/PLAYTEST_PLAN.md).
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any

local Harness = {}

local cache: { [string]: any } = {}
local loadFile: (path: string) -> any

-- Lune's fs calls yield, and yielding inside __index is not allowed, so index the source
-- tree once up front and resolve `script.Parent.X` against this table.
local files: { [string]: boolean } = {}
local dirs: { [string]: boolean } = {}
local function indexTree(dir: string)
	dirs[dir] = true
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			indexTree(path)
		else
			files[path] = true
		end
	end
end
indexTree("src")

local function dirname(path: string): string
	return string.match(path, "^(.*)/[^/]+$") or "."
end

local function scriptShimFor(path: string): any
	return setmetatable({ __path = path, __kind = "module" }, {
		__index = function(self, key)
			if key == "Parent" then
				return Harness.DirShim(dirname(path))
			end
			return nil
		end,
	})
end

function Harness.DirShim(dir: string): any
	return setmetatable({ __path = dir, __kind = "dir" }, {
		__index = function(_self, key: string)
			if key == "Parent" then
				return Harness.DirShim(dirname(dir))
			end
			local file = dir .. "/" .. key .. ".luau"
			if files[file] then
				return scriptShimFor(file)
			end
			local sub = dir .. "/" .. key
			if dirs[sub] then
				return Harness.DirShim(sub)
			end
			error("harness: no module or folder '" .. key .. "' in " .. dir)
		end,
	})
end

local function shimRequire(target: any): any
	if type(target) == "table" and rawget(target, "__kind") == "module" then
		return loadFile(rawget(target, "__path"))
	end
	error("harness: unsupported require target " .. tostring(target))
end

loadFile = function(path: string): any
	if cache[path] ~= nil then
		return cache[path]
	end
	local source = fs.readFile(path)
	local chunk = luau.load(source, {
		debugName = path,
		environment = {
			script = scriptShimFor(path),
			require = shimRequire,
			Vector3 = roblox.Vector3,
			CFrame = roblox.CFrame,
			Color3 = roblox.Color3,
			BrickColor = roblox.BrickColor,
			Enum = roblox.Enum,
		},
	})
	local result = chunk()
	cache[path] = result
	return result
end

Harness.Load = loadFile
Harness.Vector3 = roblox.Vector3
Harness.CFrame = roblox.CFrame
Harness.Color3 = roblox.Color3

-- Minimal test DSL -------------------------------------------------------------------

local results = { passed = 0, failed = 0, failures = {} :: { string } }
local currentSuite = ""

function Harness.describe(name: string, body: () -> ())
	currentSuite = name
	body()
end

function Harness.it(name: string, body: () -> ())
	local ok, err = pcall(body)
	if ok then
		results.passed += 1
	else
		results.failed += 1
		table.insert(results.failures, currentSuite .. " > " .. name .. "\n    " .. tostring(err))
	end
end

local function fmt(v: any): string
	return tostring(v)
end

function Harness.expect(actual: any)
	return {
		toBe = function(expected: any)
			if actual ~= expected then
				error("expected " .. fmt(expected) .. ", got " .. fmt(actual), 2)
			end
		end,
		toBeTruthy = function()
			if not actual then
				error("expected truthy, got " .. fmt(actual), 2)
			end
		end,
		toBeFalsy = function()
			if actual then
				error("expected falsy, got " .. fmt(actual), 2)
			end
		end,
		toBeNear = function(expected: number, epsilon: number?)
			if math.abs(actual - expected) > (epsilon or 1e-4) then
				error("expected ~" .. fmt(expected) .. ", got " .. fmt(actual), 2)
			end
		end,
		toBeAtMost = function(limit: number)
			if actual > limit then
				error("expected <= " .. fmt(limit) .. ", got " .. fmt(actual), 2)
			end
		end,
		toBeAtLeast = function(limit: number)
			if actual < limit then
				error("expected >= " .. fmt(limit) .. ", got " .. fmt(actual), 2)
			end
		end,
		toBeEmpty = function()
			if #actual ~= 0 then
				error("expected empty list, got:\n      " .. table.concat(actual, "\n      "), 2)
			end
		end,
	}
end

function Harness.Results()
	return results
end

return Harness

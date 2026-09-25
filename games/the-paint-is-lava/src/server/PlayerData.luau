--!strict
--[[
	PlayerData: persistent profiles in Roblox DataStores.

	- One key per user, versioned schema, missing fields filled from defaults on load.
	- A light session lock stops two servers writing the same profile at once.
	- Autosave every AUTOSAVE seconds, on leave, and on shutdown.
	- If DataStores are unavailable (Studio without API access enabled, or an outage) the
	  player gets a temporary in-memory profile and a warning; nothing is saved.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Signal)
local Season = require(Shared.Config.Season)

local PlayerData = {}
PlayerData.Loaded = Signal.new() :: Signal.Signal<Player, any>

local STORE_NAME = "PaintIsLava_Profiles_v1"
local AUTOSAVE = 120
local LOCK_STALE_SECONDS = 600

export type Profile = {
	Version: number,
	XP: number,
	Season: { Id: string, XP: number, Premium: boolean },
	Owned: { [string]: boolean },
	Equipped: { [string]: string },
	Stats: { [string]: number },
	Achievements: { [string]: number },
	Settings: { [string]: any },
	Receipts: { [string]: boolean },
}

local function defaults(): Profile
	return {
		Version = 1,
		XP = 0,
		Season = { Id = Season.Id, XP = 0, Premium = false },
		Owned = {},
		Equipped = {},
		Stats = {
			Eliminations = 0,
			Deaths = 0,
			Wins = 0,
			MatchesPlayed = 0,
			WallRunDistance = 0,
			Grapples = 0,
			AerialEliminations = 0,
			PaintCells = 0,
			HazardEliminations = 0,
			BrushEliminations = 0,
		},
		Achievements = {},
		Settings = { ColorblindPalette = false },
		Receipts = {},
	}
end

-- Fill in anything missing (new fields added after a profile was created).
local function reconcile(target: { [any]: any }, template: { [any]: any })
	for k, v in template do
		if target[k] == nil then
			target[k] = if type(v) == "table" then table.clone(v) else v
		elseif type(v) == "table" and type(target[k]) == "table" then
			reconcile(target[k], v)
		end
	end
end

local store: DataStore? = nil
local profiles: { [Player]: Profile } = {}
local persistent: { [Player]: boolean } = {}

local function key(player: Player): string
	return "u_" .. player.UserId
end

local function tryStore(): DataStore?
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		return result
	end
	warn("[PlayerData] DataStores unavailable, using temporary profiles: " .. tostring(result))
	return nil
end

local function load(player: Player)
	local profile: Profile = defaults()
	local saved = false
	local ds = store
	if ds then
		for attempt = 1, 5 do
			saved = false
			local ok, err = pcall(function()
				ds:UpdateAsync(key(player), function(record: any)
					record = record or {}
					local lock = record.Lock
					if
						lock
						and lock.JobId ~= game.JobId
						and os.time() - (lock.Time or 0) < LOCK_STALE_SECONDS
						and attempt < 5
					then
						return nil -- locked by another server; retry shortly
					end
					record.Lock = { JobId = game.JobId, Time = os.time() }
					if record.Data then
						profile = record.Data
					end
					saved = true
					return record
				end)
			end)
			if ok and saved then
				break
			end
			if not ok then
				warn("[PlayerData] load failed for " .. player.Name .. ": " .. tostring(err))
			end
			task.wait(2)
		end
	end

	reconcile(profile :: any, defaults() :: any)
	if profile.Season.Id ~= Season.Id then
		-- New season: season XP restarts; premium must be re-bought for the new pass.
		profile.Season = { Id = Season.Id, XP = 0, Premium = false }
	end
	if player.Parent ~= Players then
		return
	end
	profiles[player] = profile
	persistent[player] = saved
	if ds and not saved then
		warn("[PlayerData] " .. player.Name .. " is on a temporary profile this session")
	end
	PlayerData.Loaded:Fire(player, profile)
end

function PlayerData.Save(player: Player, release: boolean)
	local profile = profiles[player]
	local ds = store
	if not profile or not ds or not persistent[player] then
		return
	end
	local ok, err = pcall(function()
		ds:UpdateAsync(key(player), function(record: any)
			record = record or {}
			if record.Lock and record.Lock.JobId ~= game.JobId then
				return nil -- another server took over; don't clobber its data
			end
			record.Data = profile
			record.Lock = if release then nil else { JobId = game.JobId, Time = os.time() }
			return record
		end)
	end)
	if not ok then
		warn("[PlayerData] save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

function PlayerData.Get(player: Player): Profile?
	return profiles[player]
end

-- Yield until the profile is ready (or timeout). Returns nil on timeout.
function PlayerData.WaitFor(player: Player, timeout: number): Profile?
	local deadline = os.clock() + timeout
	while not profiles[player] and os.clock() < deadline and player.Parent == Players do
		task.wait(0.1)
	end
	return profiles[player]
end

function PlayerData.Init()
	store = tryStore()
end

function PlayerData.Start()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		PlayerData.Save(player, true)
		profiles[player] = nil
		persistent[player] = nil
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				PlayerData.Save(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE)
			for player in profiles do
				task.spawn(PlayerData.Save, player, false)
			end
		end
	end)
end

return PlayerData

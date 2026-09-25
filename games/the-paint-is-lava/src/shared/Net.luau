--!strict
--[[
	Net: every RemoteEvent in the game, declared in one place.

	Direction key:  C->S = client asks server,  S->C = server tells client(s).
	The server treats every C->S payload as untrusted and validates types, rates and ranges.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NAMES = {
	-- Paint
	"PaintDelta", -- S->C buffer of changed cells
	"PaintSnapshot", -- S->C (chunk: buffer, index: number, count: number)
	"RequestPaintSnapshot", -- C->S client renderer is ready for the full state
	"PaintImpact", -- S->C (position, radius, faction) splash effect
	-- Combat
	"Fire", -- C->S (weaponId, origin, directions {Vector3})
	"Reload", -- C->S (weaponId)
	"ThrowGrenade", -- C->S (origin, direction)
	"Swing", -- C->S (lookDirection) paintbrush
	"ProjectileFired", -- S->C (shooterUserId, weaponId, origin, velocity) for visuals
	"AmmoSync", -- S->C (weaponId, ammo, reloading, grenades)
	"HitConfirm", -- S->C to shooter (damage, eliminated)
	"DamageTaken", -- S->C to victim (amount, kind "Direct"|"Splash"|"Hazard", fromPosition?)
	"KillFeed", -- S->C (killerName, victimName, weaponId, killerBanner)
	-- Movement
	"MoveState", -- C->S ("None"|"WallRun"|"Grapple"|"Air")
	"GrappleAttach", -- C->S (part, position, normal)
	"GrappleRelease", -- C->S
	-- Match / meta
	"MatchResults", -- S->C results table
	"ProfileSync", -- S->C profile view for the Locker
	"Equip", -- C->S (category, cosmeticId)
	"SetSetting", -- C->S (key, value)
	"Toast", -- S->C (title, body) achievement unlocked, tier reached, etc.
}

local Net = {}
local events: { [string]: RemoteEvent } = {}

local function folder(): Instance
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild("Remotes")
		if existing then
			return existing
		end
		local f = Instance.new("Folder")
		f.Name = "Remotes"
		f.Parent = ReplicatedStorage
		return f
	end
	return ReplicatedStorage:WaitForChild("Remotes")
end

function Net.Init()
	local f = folder()
	for _, name in NAMES do
		if RunService:IsServer() then
			local e = f:FindFirstChild(name) :: RemoteEvent?
			if not e then
				local created = Instance.new("RemoteEvent")
				created.Name = name
				created.Parent = f
				e = created
			end
			events[name] = e :: RemoteEvent
		else
			events[name] = f:WaitForChild(name) :: RemoteEvent
		end
	end
end

function Net.Event(name: string): RemoteEvent
	local e = events[name]
	assert(e, "Unknown or uninitialised remote: " .. name)
	return e
end

return Net

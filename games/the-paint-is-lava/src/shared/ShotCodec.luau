--!strict
--[[
	ShotCodec: every projectile fired during one server frame, packed into one buffer, so
	a 24-player firefight costs one remote event per frame instead of one per pellet.

	Per shot (33 bytes):  f64 shooterUserId, u8 weaponIndex, 3x f32 origin, 3x f32 velocity
]]

local Weapons = require(script.Parent.Config.Weapons)

local ShotCodec = {}

local STRIDE = 33

-- Stable weapon <-> index mapping, identical on server and client.
local ids: { string } = {}
for id in Weapons do
	table.insert(ids, id)
end
table.sort(ids)
local indexOf: { [string]: number } = {}
for i, id in ids do
	indexOf[id] = i
end

export type Shot = {
	UserId: number,
	WeaponId: string,
	Origin: Vector3,
	Velocity: Vector3,
}

function ShotCodec.Encode(shots: { Shot }): buffer
	local out = buffer.create(#shots * STRIDE)
	for i, shot in shots do
		local at = (i - 1) * STRIDE
		buffer.writef64(out, at, shot.UserId)
		buffer.writeu8(out, at + 8, indexOf[shot.WeaponId] or 0)
		buffer.writef32(out, at + 9, shot.Origin.X)
		buffer.writef32(out, at + 13, shot.Origin.Y)
		buffer.writef32(out, at + 17, shot.Origin.Z)
		buffer.writef32(out, at + 21, shot.Velocity.X)
		buffer.writef32(out, at + 25, shot.Velocity.Y)
		buffer.writef32(out, at + 29, shot.Velocity.Z)
	end
	return out
end

function ShotCodec.Decode(data: buffer, each: (shot: Shot) -> ())
	for i = 0, buffer.len(data) // STRIDE - 1 do
		local at = i * STRIDE
		local weaponId = ids[buffer.readu8(data, at + 8)]
		if weaponId then
			each({
				UserId = buffer.readf64(data, at),
				WeaponId = weaponId,
				Origin = Vector3.new(
					buffer.readf32(data, at + 9),
					buffer.readf32(data, at + 13),
					buffer.readf32(data, at + 17)
				),
				Velocity = Vector3.new(
					buffer.readf32(data, at + 21),
					buffer.readf32(data, at + 25),
					buffer.readf32(data, at + 29)
				),
			})
		end
	end
end

-- A Vector3 that is finite and roughly unit length (rejects NaN/inf from clients).
function ShotCodec.IsUnitish(v: any): boolean
	if typeof(v) ~= "Vector3" then
		return false
	end
	local m = v.Magnitude
	return m == m and m > 0.5 and m < 1.5
end

-- A Vector3 whose components are all finite.
function ShotCodec.IsFinite(v: any): boolean
	if typeof(v) ~= "Vector3" then
		return false
	end
	local m = v.Magnitude
	return m == m and m < math.huge
end

return ShotCodec

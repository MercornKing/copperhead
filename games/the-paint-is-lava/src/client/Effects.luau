--!strict
--[[
	Effects: paint projectiles in flight, splats and bursts. Visual only; the server decides
	every hit. Projectiles follow the same Ballistics maths as the server, so what you see
	is where the paint lands.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared.Config.Weapons)
local Cosmetics = require(Shared.Config.Cosmetics)
local Ballistics = require(Shared.Ballistics)
local Net = require(Shared.Net)
local Palette = require(script.Parent.Palette)

local player = Players.LocalPlayer

local Effects = {}

type Blob = {
	Part: Part,
	Weapon: Weapons.WeaponStats,
	Velocity: Vector3,
	Travelled: number,
	Born: number,
	Faction: number,
	Owner: number,
}

local SIZES: { [string]: number } = {
	Pistol = 0.35,
	Rifle = 0.4,
	MachineGun = 0.3,
	Launcher = 1.3,
	Grenade = 0.9,
}

local folder: Folder
local blobs: { Blob } = {}
local pool: { Part } = {}
local emitterAttachment: Attachment
local splatEmitter: ParticleEmitter
local starEmitter: ParticleEmitter
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function takePart(): Part
	local p = table.remove(pool)
	if p then
		return p
	end
	local n = Instance.new("Part")
	n.Shape = Enum.PartType.Ball
	n.Material = Enum.Material.Neon
	n.Anchored = true
	n.CanCollide = false
	n.CanQuery = false
	n.CanTouch = false
	n.CastShadow = false
	return n
end

local function release(p: Part)
	p.Parent = nil
	table.insert(pool, p)
end

local function myPaintEffect(): string
	local profileEffect = player:GetAttribute("PaintEffect") :: string?
	local item = profileEffect and Cosmetics.ById[profileEffect]
	return if item then item.Visual.SplatStyle or "Classic" else "Classic"
end

-- Burst of paint droplets at a point.
function Effects.Splat(position: Vector3, color: Color3, amount: number, stars: boolean?)
	emitterAttachment.WorldPosition = position
	local emitter = if stars then starEmitter else splatEmitter
	emitter.Color = ColorSequence.new(color)
	emitter:Emit(math.clamp(math.floor(amount), 1, 80))
end

function Effects.SpawnProjectile(
	ownerUserId: number,
	faction: number,
	weaponId: string,
	origin: Vector3,
	velocity: Vector3
)
	local weapon = Weapons[weaponId]
	if not weapon then
		return
	end
	local part = takePart()
	local size = SIZES[weaponId] or 0.4
	part.Size = Vector3.new(size, size, size)
	part.Color = Palette.ForFaction(faction)
	part.CFrame = CFrame.new(origin)
	part.Parent = folder
	table.insert(blobs, {
		Part = part,
		Weapon = weapon,
		Velocity = velocity,
		Travelled = 0,
		Born = os.clock(),
		Faction = faction,
		Owner = ownerUserId,
	})
end

local function impact(b: Blob, at: Vector3)
	local stars = b.Owner == player.UserId and myPaintEffect() == "Stars"
	Effects.Splat(at, Palette.ForFaction(b.Faction), 4 + b.Weapon.PaintRadius * 2, stars)
end

local function stepAll(dt: number)
	local ignore: { Instance } = { folder }
	local layer = workspace:FindFirstChild("PaintLayer")
	if layer then
		table.insert(ignore, layer)
	end
	local camera = workspace.CurrentCamera
	if camera then
		table.insert(ignore, camera)
	end
	local now = os.clock()
	for i = #blobs, 1, -1 do
		local b = blobs[i]
		local weapon = b.Weapon
		local pos = b.Part.Position
		local remove = now - b.Born > 8
		if weapon.Kind == "Thrown" and now - b.Born >= (weapon.Fuse or 1.5) then
			Effects.Splat(pos, Palette.ForFaction(b.Faction), 60)
			remove = true
		end
		if not remove then
			local newPos, newVel = Ballistics.Step(pos, b.Velocity, weapon.Gravity, dt)
			local shooter = Players:GetPlayerByUserId(b.Owner)
			local list = table.clone(ignore)
			if shooter and shooter.Character then
				table.insert(list, shooter.Character)
			end
			rayParams.FilterDescendantsInstances = list
			local hit = workspace:Raycast(pos, newPos - pos, rayParams)
			if hit then
				if weapon.Kind == "Thrown" and not Players:GetPlayerFromCharacter(hit.Instance.Parent) then
					b.Velocity = Ballistics.Bounce(newVel, hit.Normal, weapon.Bounciness or 0.4)
					b.Part.CFrame = CFrame.new(hit.Position + hit.Normal * 0.25)
				else
					impact(b, hit.Position)
					remove = true
				end
			else
				b.Travelled += (newPos - pos).Magnitude
				b.Velocity = newVel
				b.Part.CFrame = CFrame.new(newPos)
				if weapon.Kind ~= "Thrown" and b.Travelled > weapon.Range then
					remove = true
				end
			end
		end
		if remove then
			release(b.Part)
			table.remove(blobs, i)
		end
	end
end

local function makeEmitter(texture: string, parent: Instance): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Enabled = false
	e.Lifetime = NumberRange.new(0.25, 0.6)
	e.Speed = NumberRange.new(8, 22)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -60, 0)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0.6),
	})
	e.LightEmission = 0.2
	e.Parent = parent
	return e
end

function Effects.Init()
	folder = Instance.new("Folder")
	folder.Name = "PaintFx"
	folder.Parent = workspace

	emitterAttachment = Instance.new("Attachment")
	emitterAttachment.Name = "PaintFxEmitter"
	emitterAttachment.Parent = workspace.Terrain
	splatEmitter = makeEmitter("rbxasset://textures/particles/smoke_main.dds", emitterAttachment)
	starEmitter = makeEmitter("rbxasset://textures/particles/sparkles_main.dds", emitterAttachment)

	Net.Event("ProjectileFired").OnClientEvent
		:Connect(function(userId: number, weaponId: string, origin: Vector3, velocity: Vector3)
			if userId == player.UserId then
				return -- our own shots were drawn the instant we fired
			end
			local shooter = Players:GetPlayerByUserId(userId)
			local faction = shooter and (shooter:GetAttribute("Faction") :: number?) or 0
			Effects.SpawnProjectile(userId, faction, weaponId, origin, velocity)
		end)

	Net.Event("PaintImpact").OnClientEvent:Connect(function(position: Vector3, radius: number, faction: number)
		Effects.Splat(position, Palette.ForFaction(faction), radius * 4)
	end)

	RunService.RenderStepped:Connect(stepAll)
end

return Effects

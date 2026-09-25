--!strict
--[[
	CombatService: server-authoritative weapons.

	Clients send intent (fire / reload / throw / swing). The server validates it (weapon
	held, rate of fire, ammo, plausible origin), simulates every paint projectile itself,
	and resolves both halves of every shot (Direction §3):
		- hit a hostile player  -> damage (+ splash for explosive weapons)
		- hit the arena         -> paint the surface (+ splash damage for explosive weapons)
	Missing a player is never wasted: the paint still lands and changes the map.

	Latency note: shots are simulated from the moment the server receives them, without
	lag compensation. Good enough for the prototype; see docs/ARCHITECTURE.md §Netcode.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tuning = require(Shared.Config.Tuning)
local Weapons = require(Shared.Config.Weapons)
local Net = require(Shared.Net)
local Ballistics = require(Shared.Ballistics)
local Factions = require(Shared.Paint.Factions)
local WeaponModels = require(Shared.WeaponModels)
local ShotCodec = require(Shared.ShotCodec)

local CombatService = {}

local S: any

type DamageRecord = { Attacker: Player?, WeaponId: string, Kind: string, Time: number }

type PlayerCombat = {
	Ammo: { [string]: number },
	ReloadingUntil: { [string]: number },
	LastShot: { [string]: number },
	Tokens: { [string]: number },
	Grenades: number,
	LastGrenade: number,
	LastDamage: DamageRecord?,
	LastHurt: number,
}

type Projectile = {
	Owner: Player,
	Faction: number,
	Weapon: Weapons.WeaponStats,
	Position: Vector3,
	Velocity: Vector3,
	Travelled: number,
	Born: number,
	Ignore: { Instance },
}

local combat: { [Player]: PlayerCombat } = {}
local projectiles: { Projectile } = {}
local pendingShots: { ShotCodec.Shot } = {}

local ORIGIN_TOLERANCE = 4.5 -- studs from the head (first-person camera sits there)
local BURST_TOKENS = 2 -- fire-rate bucket size: absorbs network jitter, not sustained cheating
local MAX_PROJECTILE_LIFE = 8
local KILL_CREDIT_WINDOW = 12

local function stateFor(player: Player): PlayerCombat
	local s = combat[player]
	if not s then
		s = {
			Ammo = {},
			ReloadingUntil = {},
			LastShot = {},
			Tokens = {},
			Grenades = Tuning.Grenade.Count,
			LastGrenade = 0,
			LastDamage = nil,
			LastHurt = 0,
		}
		combat[player] = s
	end
	return s
end

local function aliveCharacter(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not root then
		return nil, nil, nil
	end
	return character, humanoid, root
end

local function playerFromPart(part: Instance): Player?
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local p = Players:GetPlayerFromCharacter(model)
		if p then
			return p
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function syncAmmo(player: Player, weaponId: string)
	local s = stateFor(player)
	Net.Event("AmmoSync")
		:FireClient(player, weaponId, s.Ammo[weaponId] or 0, (s.ReloadingUntil[weaponId] or 0) > os.clock(), s.Grenades)
end

-- Damage --------------------------------------------------------------------------------

--[[
	The one entry point for all damage: direct hits, splash and hostile paint.
	Spawn protection (ForceField) and the Results phase block it.
]]
function CombatService.DealDamage(
	victim: Player,
	amount: number,
	attacker: Player?,
	kind: "Direct" | "Splash" | "Hazard",
	weaponId: string,
	fromPosition: Vector3?
)
	if amount <= 0 or not S.Match.CombatEnabled() then
		return
	end
	local character, humanoid = aliveCharacter(victim)
	if not character or not humanoid or character:FindFirstChildOfClass("ForceField") then
		return
	end

	local s = stateFor(victim)
	s.LastHurt = os.clock()
	s.LastDamage = { Attacker = attacker, WeaponId = weaponId, Kind = kind :: string, Time = os.clock() }

	local before = humanoid.Health
	humanoid:TakeDamage(amount)
	local eliminated = before > 0 and humanoid.Health <= 0

	-- Paint accumulates on the victim; clients colour it by perspective (Direction §13).
	character:SetAttribute("PaintLevel", 1 - humanoid.Health / humanoid.MaxHealth)
	if attacker then
		character:SetAttribute("PaintedBy", S.Match.FactionOf(attacker))
	end

	Net.Event("DamageTaken"):FireClient(victim, amount, kind, fromPosition)
	if attacker and attacker ~= victim and kind ~= "Hazard" then
		Net.Event("HitConfirm"):FireClient(attacker, amount, eliminated)
	end
end

-- Who gets credit for this death: last damager within the credit window.
function CombatService.KillerOf(victim: Player): (Player?, string, string)
	local s = combat[victim]
	local rec = s and s.LastDamage
	if rec and os.clock() - rec.Time <= KILL_CREDIT_WINDOW then
		local attacker = rec.Attacker
		if attacker and attacker.Parent ~= Players then
			attacker = nil
		end
		return attacker, rec.WeaponId, rec.Kind
	end
	return nil, "Paint", "Hazard"
end

-- Splash damage to hostiles in radius who can be seen from the burst (walls block it).
local function splash(
	center: Vector3,
	normal: Vector3?,
	weapon: Weapons.WeaponStats,
	owner: Player,
	faction: number,
	exclude: Player?
)
	if weapon.SplashRadius <= 0 or weapon.SplashDamage <= 0 then
		return
	end
	local from = if normal then center + normal * 0.3 else center
	for _, other in Players:GetPlayers() do
		if other ~= exclude and Factions.AreEnemies(faction, S.Match.FactionOf(other)) then
			local _, _, root = aliveCharacter(other)
			if root and S.Paint.LineOfSight(from, root.Position) then
				local dmg = Ballistics.SplashDamage(
					weapon.SplashDamage,
					weapon.SplashRadius,
					(root.Position - center).Magnitude
				)
				if dmg > 0 then
					CombatService.DealDamage(other, dmg, owner, "Splash", weapon.Id, center)
				end
			end
		end
	end
end

-- Projectiles ---------------------------------------------------------------------------

local function spawnProjectile(owner: Player, weapon: Weapons.WeaponStats, origin: Vector3, direction: Vector3)
	local character = owner.Character
	table.insert(projectiles, {
		Owner = owner,
		Faction = S.Match.FactionOf(owner),
		Weapon = weapon,
		Position = origin,
		Velocity = direction * weapon.ProjectileSpeed,
		Travelled = 0,
		Born = os.clock(),
		Ignore = if character then { character } else {},
	})
	table.insert(pendingShots, {
		UserId = owner.UserId,
		WeaponId = weapon.Id,
		Origin = origin,
		Velocity = direction * weapon.ProjectileSpeed,
	})
end

local function burst(p: Projectile, at: Vector3)
	S.Paint.PaintSphere(at, p.Weapon.PaintRadius, p.Faction, p.Owner)
	splash(at, nil, p.Weapon, p.Owner, p.Faction, nil)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- Advance one projectile. Returns false when it should be removed.
local function step(p: Projectile, dt: number): boolean
	local weapon = p.Weapon
	local now = os.clock()
	if now - p.Born > MAX_PROJECTILE_LIFE then
		return false
	end
	if weapon.Kind == "Thrown" and now - p.Born >= (weapon.Fuse or 1.5) then
		burst(p, p.Position)
		return false
	end

	local newPos, newVel = Ballistics.Step(p.Position, p.Velocity, weapon.Gravity, dt)
	local segment = newPos - p.Position

	-- Up to 3 passes so paint flies through teammates instead of stopping on them.
	for _ = 1, 3 do
		rayParams.FilterDescendantsInstances = p.Ignore
		local hit = workspace:Raycast(p.Position, segment, rayParams)
		if not hit then
			break
		end
		local victim = playerFromPart(hit.Instance)
		if victim then
			local alive = aliveCharacter(victim) ~= nil
			if alive and victim ~= p.Owner and Factions.AreEnemies(p.Faction, S.Match.FactionOf(victim)) then
				CombatService.DealDamage(victim, weapon.DirectDamage, p.Owner, "Direct", weapon.Id, p.Position)
				if weapon.SplashRadius > 0 then
					S.Paint.PaintSphere(hit.Position, weapon.PaintRadius, p.Faction, p.Owner, hit.Normal)
					splash(hit.Position, hit.Normal, weapon, p.Owner, p.Faction, victim)
				end
				return false
			end
			-- Teammates and bodies of the eliminated don't stop paint.
			local character = victim.Character
			if character then
				table.insert(p.Ignore, character)
			end
		elseif weapon.Kind == "Thrown" then
			p.Position = hit.Position + hit.Normal * 0.25
			p.Velocity = Ballistics.Bounce(newVel, hit.Normal, weapon.Bounciness or 0.4)
			return true
		else
			S.Paint.PaintSphere(hit.Position, weapon.PaintRadius, p.Faction, p.Owner, hit.Normal)
			splash(hit.Position, hit.Normal, weapon, p.Owner, p.Faction, nil)
			return false
		end
	end

	p.Travelled += segment.Magnitude
	p.Position, p.Velocity = newPos, newVel
	if weapon.Kind ~= "Thrown" and p.Travelled > weapon.Range then
		return false
	end
	-- Fell out of the world.
	return newPos.Y > workspace.FallenPartsDestroyHeight
end

-- Input handlers ------------------------------------------------------------------------

local function equippedWeapon(player: Player, weaponId: string): Weapons.WeaponStats?
	local character = aliveCharacter(player)
	if not character then
		return nil
	end
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool or tool:GetAttribute("WeaponId") ~= weaponId then
		return nil
	end
	return Weapons[weaponId]
end

-- The shot must start near the head and on the same side of any wall as the player.
local function plausibleOrigin(player: Player, origin: Vector3): boolean
	local _, _, root = aliveCharacter(player)
	if not root or not ShotCodec.IsFinite(origin) then
		return false
	end
	local head = root.Position + Vector3.new(0, 1.5, 0)
	return (head - origin).Magnitude <= ORIGIN_TOLERANCE and S.Paint.LineOfSight(head, origin)
end

-- Token-bucket rate limit: sustained rate can never exceed the weapon's FireRate.
local function takeToken(s: PlayerCombat, key: string, rate: number): boolean
	local now = os.clock()
	local last = s.LastShot[key] or 0
	local tokens = math.min(BURST_TOKENS, (s.Tokens[key] or BURST_TOKENS) + (now - last) * rate)
	s.LastShot[key] = now
	if tokens < 1 then
		s.Tokens[key] = tokens
		return false
	end
	s.Tokens[key] = tokens - 1
	return true
end

local function beginReload(player: Player, weapon: Weapons.WeaponStats)
	local s = stateFor(player)
	local id = weapon.Id
	if (s.ReloadingUntil[id] or 0) > os.clock() or (s.Ammo[id] or 0) >= weapon.MagazineSize then
		syncAmmo(player, id) -- tell a client that got ahead of us what the real state is
		return
	end
	s.ReloadingUntil[id] = os.clock() + weapon.ReloadTime
	syncAmmo(player, id)
	task.delay(weapon.ReloadTime, function()
		if combat[player] == s then
			s.Ammo[id] = weapon.MagazineSize
			s.ReloadingUntil[id] = nil
			syncAmmo(player, id)
		end
	end)
end

local function onFire(player: Player, weaponId: unknown, origin: unknown, directions: unknown)
	if typeof(weaponId) ~= "string" or typeof(origin) ~= "Vector3" or typeof(directions) ~= "table" then
		return
	end
	local id = weaponId :: string
	local weapon = equippedWeapon(player, id)
	if not weapon or weapon.Kind ~= "Projectile" or S.Match.FactionOf(player) == 0 then
		if Weapons[id] and stateFor(player).Ammo[id] then
			syncAmmo(player, id) -- the client predicted a shot we won't honour; correct it
		end
		return
	end
	local dirs = directions :: { any }
	local valid = #dirs == weapon.Pellets
	for _, d in dirs do
		valid = valid and ShotCodec.IsUnitish(d)
	end
	local s = stateFor(player)
	-- Every rejection re-syncs ammo so the client's predicted count never drifts.
	if
		not valid
		or (s.ReloadingUntil[id] or 0) > os.clock()
		or (s.Ammo[id] or 0) <= 0
		or not plausibleOrigin(player, origin :: Vector3)
		or not takeToken(s, id, weapon.FireRate)
	then
		syncAmmo(player, id)
		return
	end

	s.Ammo[id] -= 1
	for _, d in dirs do
		spawnProjectile(player, weapon, origin :: Vector3, (d :: Vector3).Unit)
	end
	if s.Ammo[id] <= 0 then
		beginReload(player, weapon)
	end
end

local function onReload(player: Player, weaponId: unknown)
	if typeof(weaponId) ~= "string" then
		return
	end
	local weapon = equippedWeapon(player, weaponId)
	if weapon and weapon.Kind == "Projectile" then
		beginReload(player, weapon)
	end
end

local function onThrow(player: Player, origin: unknown, direction: unknown)
	local s = stateFor(player)
	local now = os.clock()
	local weapon = Weapons.Grenade
	if
		typeof(origin) ~= "Vector3"
		or not ShotCodec.IsUnitish(direction)
		or s.Grenades <= 0
		or now - s.LastGrenade < 1 / weapon.FireRate
		or S.Match.FactionOf(player) == 0
		or not plausibleOrigin(player, origin :: Vector3)
	then
		Net.Event("AmmoSync"):FireClient(player, "Grenade", s.Grenades, false, s.Grenades)
		return
	end
	s.Grenades -= 1
	s.LastGrenade = now
	-- Slight upward lob so grenades arc naturally.
	local dir = ((direction :: Vector3).Unit + Vector3.new(0, 0.25, 0)).Unit
	spawnProjectile(player, weapon, origin :: Vector3, dir)
	Net.Event("AmmoSync"):FireClient(player, "Grenade", s.Grenades, false, s.Grenades)
end

local function onSwing(player: Player, look: unknown)
	if not ShotCodec.IsUnitish(look) then
		return
	end
	local weapon = equippedWeapon(player, "Paintbrush")
	if not weapon or S.Match.FactionOf(player) == 0 then
		return
	end
	if not takeToken(stateFor(player), "Paintbrush", weapon.FireRate) then
		return
	end

	local character, _, root = aliveCharacter(player)
	if not character or not root then
		return
	end
	local faction = S.Match.FactionOf(player)
	local reach = weapon.Reach or 8
	local halfArc = math.rad((weapon.ArcDegrees or 90) / 2)
	local lookDir = (look :: Vector3).Unit
	local flat = Vector3.new(lookDir.X, 0, lookDir.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else root.CFrame.LookVector
	local eye = root.Position + Vector3.new(0, 1.5, 0)

	-- Players inside the swipe arc, with line of sight.
	local los = RaycastParams.new()
	los.FilterType = Enum.RaycastFilterType.Include
	los.FilterDescendantsInstances = { workspace:FindFirstChild("Arena") :: Instance }
	for _, other in Players:GetPlayers() do
		if other ~= player and Factions.AreEnemies(faction, S.Match.FactionOf(other)) then
			local _, _, otherRoot = aliveCharacter(other)
			if otherRoot then
				local offset = otherRoot.Position - eye
				local flatOffset = Vector3.new(offset.X, 0, offset.Z)
				local angle = if flatOffset.Magnitude > 0.01
					then math.acos(math.clamp(flatOffset.Unit:Dot(flat), -1, 1))
					else 0
				if offset.Magnitude <= reach + 1.5 and angle <= halfArc and not workspace:Raycast(eye, offset, los) then
					CombatService.DealDamage(other, weapon.DirectDamage, player, "Direct", weapon.Id, eye)
				end
			end
		end
	end

	-- The brush physically paints: a fan of strokes ahead, low and level, plus underfoot.
	local rays = weapon.SwipeRays or 5
	for i = 0, rays - 1 do
		local t = if rays > 1 then i / (rays - 1) else 0.5
		local yaw = -halfArc + t * 2 * halfArc
		local dir = (CFrame.fromAxisAngle(Vector3.yAxis, yaw) * flat)
		for _, pitch in { -0.9, -0.25, 0.35 } do
			local rayDir = (dir + Vector3.new(0, pitch, 0)).Unit * (reach + 3)
			local hit = workspace:Raycast(eye, rayDir, los)
			if hit then
				S.Paint.PaintSphere(hit.Position, weapon.PaintRadius, faction, player, hit.Normal)
			end
		end
	end
	local under = workspace:Raycast(root.Position, Vector3.new(0, -8, 0), los)
	if under then
		S.Paint.PaintSphere(under.Position, weapon.PaintRadius, faction, player, under.Normal)
	end
end

-- Lifecycle -----------------------------------------------------------------------------

-- Called by MatchService after every (re)spawn: fresh ammo, grenades and weapons.
function CombatService.OnSpawned(player: Player, character: Model)
	local s = stateFor(player)
	table.clear(s.ReloadingUntil)
	table.clear(s.LastShot)
	table.clear(s.Tokens)
	s.LastDamage = nil
	s.Grenades = Tuning.Grenade.Count
	for _, id in Tuning.Loadout do
		local weapon = Weapons[id]
		if weapon then
			s.Ammo[id] = weapon.MagazineSize
		end
	end
	character:SetAttribute("PaintLevel", 0)

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		backpack:ClearAllChildren()
		local equipped = S.Progression.Equipped(player)
		for _, id in Tuning.Loadout do
			local weapon = Weapons[id]
			if weapon then
				local tool = WeaponModels.BuildTool(weapon, equipped)
				tool.Parent = backpack
			end
		end
	end
	for _, id in Tuning.Loadout do
		syncAmmo(player, id)
	end
end

local function regenTick(dt: number)
	local now = os.clock()
	for player, s in combat do
		if now - s.LastHurt >= Tuning.Health.RegenDelay then
			local character, humanoid = aliveCharacter(player)
			if character and humanoid and humanoid.Health < humanoid.MaxHealth then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + Tuning.Health.RegenPerSecond * dt)
				character:SetAttribute("PaintLevel", 1 - humanoid.Health / humanoid.MaxHealth)
			end
		end
	end
end

function CombatService.Init(services: any)
	S = services
end

function CombatService.Start()
	Net.Event("Fire").OnServerEvent:Connect(onFire)
	Net.Event("Reload").OnServerEvent:Connect(onReload)
	Net.Event("ThrowGrenade").OnServerEvent:Connect(onThrow)
	Net.Event("Swing").OnServerEvent:Connect(onSwing)

	Players.PlayerRemoving:Connect(function(player)
		combat[player] = nil
	end)

	local regenAccumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		if #pendingShots > 0 then
			Net.Event("ProjectileFired"):FireAllClients(ShotCodec.Encode(pendingShots))
			table.clear(pendingShots)
		end
		for i = #projectiles, 1, -1 do
			local ok, keep = pcall(step, projectiles[i], dt)
			if not ok or not keep then
				if not ok then
					warn("[Combat] projectile error: " .. tostring(keep))
				end
				table.remove(projectiles, i)
			end
		end
		regenAccumulator += dt
		if regenAccumulator >= 0.25 then
			regenTick(regenAccumulator)
			regenAccumulator = 0
		end
	end)
end

return CombatService

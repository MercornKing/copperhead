--!strict
--[[
	WeaponController: turns input into paint.

	Predicts locally (ammo, rate of fire, projectile visuals) so shooting feels instant,
	and sends intent to the server, which is authoritative. AmmoSync corrects any drift.

	Controls:
		Mouse1 / R2 / touch Fire    fire (hold for automatic weapons); swing the brush
		R / X                       reload
		G / D-pad up / touch Bomb   throw a paint bomb
		1-5 / L1-R1 (hotbar)        switch weapon (L1/R1 left free for Roblox's hotbar)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared.Config.Weapons)
local Tuning = require(Shared.Config.Tuning)
local Net = require(Shared.Net)
local Ballistics = require(Shared.Ballistics)
local Effects = require(script.Parent.Effects)
local ViewModel = require(script.Parent.ViewModel)
local MovementController = require(script.Parent.MovementController)
local Palette = require(script.Parent.Palette)

local player = Players.LocalPlayer

local WeaponController = {}

local current: Weapons.WeaponStats? = nil
local firing = false
local ammo: { [string]: number } = {}
local reloadingUntil: { [string]: number } = {}
local lastShot: { [string]: number } = {}
local grenades = Tuning.Grenade.Count
local lastGrenade = 0

export type HudState = {
	WeaponName: string,
	Ammo: number,
	Magazine: number,
	Reloading: boolean,
	ReloadProgress: number,
	Grenades: number,
	IsMelee: boolean,
}

function WeaponController.State(): HudState?
	local w = current
	if not w then
		return nil
	end
	local now = os.clock()
	local untilT = reloadingUntil[w.Id] or 0
	return {
		WeaponName = w.DisplayName,
		Ammo = ammo[w.Id] or 0,
		Magazine = w.MagazineSize,
		Reloading = untilT > now,
		ReloadProgress = if untilT > now and w.ReloadTime > 0 then 1 - (untilT - now) / w.ReloadTime else 1,
		Grenades = grenades,
		IsMelee = w.Kind == "Melee",
	}
end

local function alive(): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function aim(): (Vector3, Vector3)
	local camera = workspace.CurrentCamera :: Camera
	return camera.CFrame.Position, camera.CFrame.LookVector
end

-- Visual start point near the gun muzzle; the server simulates from the camera.
local function muzzle(origin: Vector3): Vector3
	local camera = workspace.CurrentCamera :: Camera
	return origin + camera.CFrame.LookVector * 2 + camera.CFrame.RightVector * 0.8 - camera.CFrame.UpVector * 0.6
end

local function reload()
	local w = current
	if not w or w.Kind ~= "Projectile" then
		return
	end
	local now = os.clock()
	if (reloadingUntil[w.Id] or 0) > now or (ammo[w.Id] or 0) >= w.MagazineSize then
		return
	end
	reloadingUntil[w.Id] = now + w.ReloadTime
	Net.Event("Reload"):FireServer(w.Id)
end

local function fire()
	local w = current
	if not w or not alive() or Palette.MyFaction() == 0 then
		return
	end
	local now = os.clock()
	if now - (lastShot[w.Id] or 0) < 1 / w.FireRate then
		return
	end

	if w.Kind == "Melee" then
		lastShot[w.Id] = now
		local _, look = aim()
		Net.Event("Swing"):FireServer(look)
		ViewModel.Swing()
		return
	end

	if (reloadingUntil[w.Id] or 0) > now then
		return
	end
	if (ammo[w.Id] or 0) <= 0 then
		reload()
		return
	end

	lastShot[w.Id] = now
	ammo[w.Id] -= 1
	local origin, look = aim()
	local dirs: { Vector3 } = {}
	for i = 1, w.Pellets do
		dirs[i] = Ballistics.Spread(look, w.Spread, math.random)
	end
	Net.Event("Fire"):FireServer(w.Id, origin, dirs)
	for _, d in dirs do
		Effects.SpawnProjectile(player.UserId, Palette.MyFaction(), w.Id, muzzle(origin), d * w.ProjectileSpeed)
	end
	ViewModel.Kick(math.clamp(w.DirectDamage / 60, 0.08, 0.8))
	if ammo[w.Id] <= 0 then
		-- The server auto-reloads when it also reaches zero; asking explicitly covers the
		-- case where it dropped one of our shots and still thinks there's paint left.
		reloadingUntil[w.Id] = now + w.ReloadTime
		Net.Event("Reload"):FireServer(w.Id)
	end
	if not w.Automatic then
		firing = false
	end
end

local function throwGrenade()
	if grenades <= 0 or not alive() or Palette.MyFaction() == 0 then
		return
	end
	local now = os.clock()
	local w = Weapons.Grenade
	if now - lastGrenade < 1 / w.FireRate then
		return
	end
	lastGrenade = now
	grenades -= 1
	local origin, look = aim()
	Net.Event("ThrowGrenade"):FireServer(origin, look)
	local dir = (look + Vector3.new(0, 0.25, 0)).Unit
	Effects.SpawnProjectile(player.UserId, Palette.MyFaction(), "Grenade", muzzle(origin), dir * w.ProjectileSpeed)
end

local function equip(tool: Tool)
	local id = tool:GetAttribute("WeaponId") :: string?
	local w = id and Weapons[id]
	if not w then
		return
	end
	current = w
	firing = false
	MovementController.SetSpeedMultiplier(w.MoveSpeedMultiplier)
	ViewModel.Show(tool)
end

local function unequip()
	current = nil
	firing = false
	MovementController.SetSpeedMultiplier(1)
	ViewModel.Hide()
end

local function bindCharacter(character: Model)
	unequip()
	grenades = Tuning.Grenade.Count
	table.clear(reloadingUntil)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			equip(child)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and current and child:GetAttribute("WeaponId") == current.Id then
			unequip()
		end
	end)
	-- Start with the first weapon in hand.
	task.delay(0.5, function()
		local backpack = player:FindFirstChildOfClass("Backpack")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if backpack and humanoid and not character:FindFirstChildOfClass("Tool") then
			local first = backpack:FindFirstChildOfClass("Tool")
			if first then
				humanoid:EquipTool(first)
			end
		end
	end)
end

function WeaponController.Init()
	player.CharacterAdded:Connect(bindCharacter)
	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end

	ContextActionService:BindAction("Fire", function(_, state)
		if state == Enum.UserInputState.Begin then
			firing = true
			fire()
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			firing = false
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("Fire", "Fire")
	ContextActionService:SetPosition("Fire", UDim2.new(1, -110, 1, -230))

	ContextActionService:BindAction("Reload", function(_, state)
		if state == Enum.UserInputState.Begin then
			reload()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("Reload", "Reload")
	ContextActionService:SetPosition("Reload", UDim2.new(1, -230, 1, -230))

	ContextActionService:BindAction("Grenade", function(_, state)
		if state == Enum.UserInputState.Begin then
			throwGrenade()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.G, Enum.KeyCode.DPadUp)
	ContextActionService:SetTitle("Grenade", "Bomb")
	ContextActionService:SetPosition("Grenade", UDim2.new(1, -290, 1, -150))

	Net.Event("AmmoSync").OnClientEvent:Connect(function(weaponId: string, count: number, reloading: boolean, g: number)
		grenades = g
		if weaponId ~= "Grenade" then
			ammo[weaponId] = count
			if not reloading then
				reloadingUntil[weaponId] = nil
			end
		end
	end)

	RunService.Heartbeat:Connect(function()
		local w = current
		if firing and w and w.Automatic then
			fire()
		end
	end)
end

return WeaponController

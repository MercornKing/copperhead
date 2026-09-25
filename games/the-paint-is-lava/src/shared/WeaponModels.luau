--!strict
--[[
	WeaponModels: procedural stand-in models for every weapon, built as Roblox Tools.

	These are greybox art: readable silhouettes (pistol, rifle, hose, launcher, brush)
	coloured by the player's equipped WeaponSkin / Brush cosmetic. The asset brief in
	docs/ASSET_BRIEFS.md describes the final models that replace them.

	Held parts are Massless and CanQuery = false, so a weapon (or its skin) can never change
	a character's hitbox or weight (Direction §11, §15).
]]

local Cosmetics = require(script.Parent.Config.Cosmetics)

local WeaponModels = {}

type PartDef = {
	Size: Vector3,
	Offset: CFrame,
	Role: "Body" | "Accent" | "Tank" | "Bristle" | "Handle",
	Shape: Enum.PartType?,
}

local CYL_Z = CFrame.Angles(0, math.rad(90), 0) -- cylinders run along X; turn them along Z

local SHAPES: { [string]: { PartDef } } = {
	Pistol = {
		{
			Size = Vector3.new(0.35, 0.9, 0.45),
			Offset = CFrame.new(0, -0.55, 0.35) * CFrame.Angles(math.rad(-12), 0, 0),
			Role = "Accent",
		},
		{
			Size = Vector3.new(0.9, 0.22, 0.22),
			Offset = CFrame.new(0, 0.05, -0.85) * CYL_Z,
			Role = "Accent",
			Shape = Enum.PartType.Cylinder,
		},
		{
			Size = Vector3.new(0.55, 0.55, 0.55),
			Offset = CFrame.new(0, 0.45, 0.2),
			Role = "Tank",
			Shape = Enum.PartType.Ball,
		},
	},
	Rifle = {
		{
			Size = Vector3.new(0.35, 0.9, 0.45),
			Offset = CFrame.new(0, -0.6, 0.5) * CFrame.Angles(math.rad(-12), 0, 0),
			Role = "Accent",
		},
		{ Size = Vector3.new(0.4, 0.55, 1.1), Offset = CFrame.new(0, -0.1, 1.7), Role = "Accent" },
		{
			Size = Vector3.new(1.4, 0.25, 0.25),
			Offset = CFrame.new(0, 0.1, -2),
			Role = "Accent",
			Shape = Enum.PartType.Cylinder,
		},
		{
			Size = Vector3.new(0.8, 0.8, 0.8),
			Offset = CFrame.new(0, 0.6, 0.1),
			Role = "Tank",
			Shape = Enum.PartType.Ball,
		},
	},
	MachineGun = {
		{
			Size = Vector3.new(0.35, 0.9, 0.45),
			Offset = CFrame.new(0, -0.65, 0.7) * CFrame.Angles(math.rad(-12), 0, 0),
			Role = "Accent",
		},
		{
			Size = Vector3.new(0.9, 1.2, 1.2),
			Offset = CFrame.new(0, -0.6, -0.4) * CYL_Z * CFrame.Angles(0, 0, 0),
			Role = "Tank",
			Shape = Enum.PartType.Cylinder,
		},
		{
			Size = Vector3.new(1.6, 0.4, 0.4),
			Offset = CFrame.new(0, 0.05, -2.1),
			Role = "Accent",
			Shape = Enum.PartType.Cylinder,
		},
	},
	Launcher = {
		{ Size = Vector3.new(0.35, 0.9, 0.45), Offset = CFrame.new(0, -0.8, 0.3), Role = "Accent" },
		{
			Size = Vector3.new(1.1, 1.5, 1.5),
			Offset = CFrame.new(0, 0.1, -2.1) * CYL_Z,
			Role = "Tank",
			Shape = Enum.PartType.Cylinder,
		},
	},
	Paintbrush = {
		{ Size = Vector3.new(0.5, 0.4, 0.5), Offset = CFrame.new(0, 0, -1.6), Role = "Accent" },
		{ Size = Vector3.new(1.0, 0.45, 1.3), Offset = CFrame.new(0, 0, -2.4), Role = "Bristle" },
	},
	Grenade = {},
}

local BODY_SIZE: { [string]: Vector3 } = {
	Pistol = Vector3.new(0.4, 0.5, 1.4),
	Rifle = Vector3.new(0.45, 0.6, 2.8),
	MachineGun = Vector3.new(0.6, 0.7, 3),
	Launcher = Vector3.new(0.9, 0.9, 3.2),
	Paintbrush = Vector3.new(0.25, 0.25, 2.8),
	Grenade = Vector3.new(0.8, 0.8, 0.8),
}

local function styleHeld(part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function materialFrom(value: any): Enum.Material
	if typeof(value) == "string" then
		local ok, result = pcall(function()
			return (Enum.Material :: any)[value]
		end)
		if ok and result then
			return result
		end
	end
	return Enum.Material.SmoothPlastic
end

-- Visual styling for a weapon from the equipped cosmetics ({ [category] = cosmeticId }).
local function palette(weapon: any, equipped: { [string]: string }?)
	local body, accent, material = weapon.ModelColor, Color3.fromRGB(240, 240, 245), Enum.Material.SmoothPlastic
	local bristle, handle = Color3.fromRGB(250, 250, 250), Color3.fromRGB(150, 100, 60)
	if equipped then
		local skin = Cosmetics.ById[equipped.WeaponSkin or ""]
		if skin and weapon.Kind ~= "Melee" then
			body = skin.Visual.Color or body
			accent = skin.Visual.Accent or accent
			material = materialFrom(skin.Visual.Material)
		end
		local brush = Cosmetics.ById[equipped.Brush or ""]
		if brush and weapon.Kind == "Melee" then
			bristle = brush.Visual.BristleColor or bristle
			handle = brush.Visual.HandleColor or handle
		end
	end
	return body, accent, material, bristle, handle
end

-- Build the visual parts of a weapon under `parent`, all welded to the returned handle.
function WeaponModels.BuildParts(weapon: any, equipped: { [string]: string }?, parent: Instance): BasePart
	local body, accent, material, bristle, handleColor = palette(weapon, equipped)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = BODY_SIZE[weapon.Id] or Vector3.new(0.5, 0.5, 2)
	handle.Color = if weapon.Kind == "Melee" then handleColor else body
	handle.Material = material
	if weapon.Id == "Grenade" then
		handle.Shape = Enum.PartType.Ball
	end
	styleHeld(handle)
	handle.Parent = parent

	local shapes: { PartDef } = SHAPES[weapon.Id] or {}
	for i, def in shapes do
		local p = Instance.new("Part")
		p.Name = def.Role .. i
		p.Size = def.Size
		if def.Shape then
			p.Shape = def.Shape
		end
		if def.Role == "Tank" then
			-- Paint canister: neutral glass so it never reads as safe or danger.
			p.Color = Color3.fromRGB(235, 240, 255)
			p.Material = Enum.Material.Glass
			p.Transparency = 0.25
		elseif def.Role == "Bristle" then
			p.Color = bristle
			p.Material = Enum.Material.Fabric
		else
			p.Color = if weapon.Kind == "Melee" then Color3.fromRGB(200, 200, 210) else accent
			p.Material = if weapon.Kind == "Melee" then Enum.Material.Metal else material
		end
		styleHeld(p)
		p.CFrame = handle.CFrame * def.Offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = p
		weld.Parent = p
		p.Parent = parent
	end
	return handle
end

function WeaponModels.BuildTool(weapon: any, equipped: { [string]: string }?): Tool
	local tool = Instance.new("Tool")
	tool.Name = weapon.DisplayName
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = true
	tool.ToolTip = weapon.DisplayName
	tool:SetAttribute("WeaponId", weapon.Id)
	-- Barrel runs along the handle's -Z, which the default grip points forward.
	tool.Grip = CFrame.new(0, 0, 0.3)
	WeaponModels.BuildParts(weapon, equipped, tool)
	return tool
end

return WeaponModels

--!strict
--[[
	ArenaBuilder: turns a map data module (server/Maps/*) into parts in Workspace.

	Layout:
		Workspace.Arena
			Paintable/   every surface that takes paint (floors, walls, ceilings, anchors)
			Solid/       geometry that never takes paint (none in Canvas Yard; kept for
			             glass, hazards-free zones, decorative props)
]]

local Lighting = game:GetService("Lighting")

local ArenaBuilder = {}

export type Built = {
	Root: Folder,
	Paintable: Folder,
	Map: any,
}

local function styleLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.2
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 165)
	Lighting.Ambient = Color3.fromRGB(90, 90, 105)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.3
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.25
		atmosphere.Haze = 0.6
		atmosphere.Color = Color3.fromRGB(210, 220, 255)
		atmosphere.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.4
		bloom.Size = 20
		bloom.Threshold = 1.4
		bloom.Parent = Lighting
	end
end

function ArenaBuilder.Build(map: any): Built
	local existing = workspace:FindFirstChild("Arena")
	if existing then
		existing:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = "Arena"
	root:SetAttribute("MapName", map.Name)

	local paintable = Instance.new("Folder")
	paintable.Name = "Paintable"
	paintable.Parent = root

	local solid = Instance.new("Folder")
	solid.Name = "Solid"
	solid.Parent = root

	for index, spec in map.Parts do
		local part = Instance.new("Part")
		part.Name = spec.Name
		part.Anchored = true
		part.Size = spec.Size
		part.CFrame = spec.CFrame
		part.Color = spec.Color
		part.Material = spec.Material or Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if spec.Anchor then
			part.Material = Enum.Material.Neon
			part:SetAttribute("GrappleAnchor", true)
			local light = Instance.new("PointLight")
			light.Range = 14
			light.Brightness = 1.5
			light.Color = spec.Color
			light.Parent = part
		end
		if spec.Paintable then
			part:SetAttribute("PaintIndex", index)
			if spec.Faces then
				part:SetAttribute("PaintFaces", spec.Faces)
			end
			part.Parent = paintable
		else
			part.Parent = solid
		end
	end

	root.Parent = workspace
	styleLighting()
	return { Root = root, Paintable = paintable, Map = map }
end

return ArenaBuilder

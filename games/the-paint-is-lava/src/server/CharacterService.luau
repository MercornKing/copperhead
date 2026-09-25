--!strict
--[[
	CharacterService: every character is the same body wearing different clothes.

	- Gameplay stats are (re)stamped from Tuning on every spawn, whoever you pick
	  (Direction §11). Nothing cosmetic can reach these lines.
	- Players' own Roblox avatars are not loaded (StarterPlayer.LoadCharacterAppearance =
	  false), so everyone shares the default rig and hitbox; identity comes from the launch
	  characters and cosmetics instead.
	- Cosmetic parts are Massless and CanQuery = false: they can't be shot, can't block,
	  and weigh nothing.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tuning = require(Shared.Config.Tuning)
local Characters = require(Shared.Config.Characters)
local Cosmetics = require(Shared.Config.Cosmetics)

local CharacterService = {}

local S: any

local charactersById: { [string]: Characters.CharacterDef } = {}
for _, def in Characters do
	charactersById[def.Id] = def
end

function CharacterService.EnforceStats(humanoid: Humanoid)
	humanoid.MaxHealth = Tuning.Health.MaxHealth
	humanoid.Health = Tuning.Health.MaxHealth
	humanoid.WalkSpeed = Tuning.Movement.WalkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Tuning.Movement.JumpPower
end

local function cosmeticPart(name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	return p
end

local function attach(folder: Instance, head: BasePart, part: BasePart, offset: CFrame)
	part.CFrame = head.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = part
	weld.Parent = part
	part.Parent = folder
end

-- Procedural headwear until the art pass delivers meshes (docs/ASSET_BRIEFS.md).
local function buildHeadwear(folder: Instance, head: BasePart, shape: string, color: Color3, accent: Color3)
	local cyl = CFrame.Angles(0, 0, math.rad(90)) -- cylinders along X -> along Y
	if shape == "Visor" then
		attach(folder, head, cosmeticPart("Visor", Vector3.new(1.3, 0.35, 0.3), accent), CFrame.new(0, 0.15, -0.6))
		attach(folder, head, cosmeticPart("Band", Vector3.new(1.35, 0.2, 1.3), color), CFrame.new(0, 0.2, 0))
	elseif shape == "Bucket" then
		attach(
			folder,
			head,
			cosmeticPart("Bucket", Vector3.new(0.9, 1.4, 1.4), color, Enum.PartType.Cylinder),
			CFrame.new(0, 0.95, 0) * cyl
		)
		attach(folder, head, cosmeticPart("Drip", Vector3.new(0.25, 0.5, 0.25), accent), CFrame.new(0.55, 0.6, -0.4))
	elseif shape == "Beret" then
		attach(
			folder,
			head,
			cosmeticPart("Beret", Vector3.new(0.3, 1.5, 1.5), color, Enum.PartType.Cylinder),
			CFrame.new(0.15, 0.7, 0) * cyl * CFrame.Angles(0, 0, math.rad(8))
		)
		attach(folder, head, cosmeticPart("Stem", Vector3.new(0.12, 0.25, 0.12), accent), CFrame.new(0.15, 0.95, 0))
	elseif shape == "Headphones" then
		attach(folder, head, cosmeticPart("Arc", Vector3.new(1.5, 0.2, 0.3), color), CFrame.new(0, 0.7, 0))
		attach(
			folder,
			head,
			cosmeticPart("CupL", Vector3.new(0.3, 0.6, 0.6), accent, Enum.PartType.Cylinder),
			CFrame.new(-0.7, 0.1, 0)
		)
		attach(
			folder,
			head,
			cosmeticPart("CupR", Vector3.new(0.3, 0.6, 0.6), accent, Enum.PartType.Cylinder),
			CFrame.new(0.7, 0.1, 0)
		)
	elseif shape == "Propeller" then
		attach(
			folder,
			head,
			cosmeticPart("Cap", Vector3.new(0.5, 1.3, 1.3), color, Enum.PartType.Cylinder),
			CFrame.new(0, 0.7, 0) * cyl
		)
		attach(folder, head, cosmeticPart("Blade", Vector3.new(1.6, 0.06, 0.25), accent), CFrame.new(0, 1.05, 0))
	elseif shape == "Crown" then
		for i = 0, 4 do
			local a = i / 5 * 2 * math.pi
			attach(
				folder,
				head,
				cosmeticPart("Point" .. i, Vector3.new(0.3, 0.5, 0.3), color),
				CFrame.new(math.cos(a) * 0.5, 0.9, math.sin(a) * 0.5)
			)
		end
	elseif shape == "Cone" then
		attach(folder, head, cosmeticPart("Cone", Vector3.new(0.8, 1.2, 0.8), color), CFrame.new(0, 1.1, 0))
		attach(
			folder,
			head,
			cosmeticPart("Stripe", Vector3.new(0.85, 0.2, 0.85), Color3.new(1, 1, 1)),
			CFrame.new(0, 1.1, 0)
		)
	end
end

function CharacterService.ApplyCosmetics(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not character or not head then
		return
	end
	local equipped = S.Progression.Equipped(player)

	local skin = Cosmetics.ById[equipped.CharacterSkin]
	local def = charactersById[skin and skin.Visual.Character or ""] or Characters[1]
	player:SetAttribute("CharacterId", def.Id)

	local colors = character:FindFirstChildOfClass("BodyColors") or Instance.new("BodyColors")
	local v: { [string]: any } = if skin then skin.Visual else {}
	local head3 = v.Head or def.BodyColors.Head
	local torso = v.Torso or def.BodyColors.Torso
	local arms = v.Arms or def.BodyColors.Arms
	local legs = v.Legs or def.BodyColors.Legs
	colors.HeadColor3 = head3
	colors.TorsoColor3 = torso
	colors.LeftArmColor3 = arms
	colors.RightArmColor3 = arms
	colors.LeftLegColor3 = legs
	colors.RightLegColor3 = legs
	colors.Parent = character

	local old = character:FindFirstChild("Cosmetics")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Cosmetics"
	folder.Parent = character

	local hat = Cosmetics.ById[equipped.Headwear]
	if hat and hat.Visual.Shape and hat.Visual.Shape ~= "None" then
		buildHeadwear(folder, head, hat.Visual.Shape, hat.Visual.Color or def.AccentColor, def.AccentColor)
	else
		buildHeadwear(folder, head, def.Signature, torso, def.AccentColor)
	end
end

function CharacterService.Init(services: any)
	S = services
end

function CharacterService.Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
			CharacterService.EnforceStats(humanoid)
			if not character:FindFirstChild("Head") then
				character:WaitForChild("Head", 5)
			end
			CharacterService.ApplyCosmetics(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return CharacterService

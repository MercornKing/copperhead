--!strict
--[[
	ViewModel: the first-person weapon in the bottom-right of the screen, with walk bob,
	recoil kick and a brush swipe. Built from the same parts as the held Tool so weapon
	skins show in first person too.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local ViewModel = {}

local model: Model? = nil
local sourceTool: Tool? = nil
local kick = 0
local swingT = 1
local bobT = 0

local OFFSET = CFrame.new(0.95, -0.9, -1.7)

local function clear()
	if model then
		model:Destroy()
		model = nil
	end
	sourceTool = nil
end

function ViewModel.Show(tool: Tool)
	clear()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local m = Instance.new("Model")
	m.Name = "ViewModel"
	local handle: BasePart? = nil
	for _, d in tool:GetChildren() do
		if d:IsA("BasePart") then
			local copy = d:Clone()
			for _, w in copy:GetChildren() do
				if w:IsA("WeldConstraint") then
					w:Destroy()
				end
			end
			copy.Anchored = true
			copy.CanCollide = false
			copy.CanQuery = false
			copy.CanTouch = false
			copy.CastShadow = false
			copy.Parent = m
			if d.Name == "Handle" then
				handle = copy
			end
		end
	end
	if not handle then
		m:Destroy()
		return
	end
	m.PrimaryPart = handle
	m.Parent = camera
	model = m
	sourceTool = tool
end

function ViewModel.Hide()
	clear()
end

function ViewModel.Kick(amount: number)
	kick = math.min(kick + amount, 1)
end

function ViewModel.Swing()
	swingT = 0
end

local function render(dt: number)
	local m, camera = model, workspace.CurrentCamera
	if not m or not camera then
		return
	end
	-- Keep the third-person tool hidden locally so it never doubles up with the view model.
	local tool = sourceTool
	if tool then
		for _, d in tool:GetChildren() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
			end
		end
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local moving = humanoid and humanoid.MoveDirection.Magnitude > 0.1 and humanoid.FloorMaterial ~= Enum.Material.Air
	bobT += dt * (if moving then 9 else 2)
	local bobAmp = if moving then 0.06 else 0.015
	local bob = CFrame.new(math.sin(bobT) * bobAmp, math.abs(math.cos(bobT)) * bobAmp, 0)

	kick = math.max(0, kick - dt * 6)
	local recoil = CFrame.new(0, 0, kick * 0.35) * CFrame.Angles(kick * 0.25, 0, 0)

	swingT = math.min(1, swingT + dt * 5)
	local s = math.sin(swingT * math.pi)
	local swing = CFrame.Angles(-s * 0.6, s * 1.1, s * 0.4)

	m:PivotTo(camera.CFrame * OFFSET * bob * recoil * swing)
end

function ViewModel.Init()
	RunService:BindToRenderStep("ViewModel", Enum.RenderPriority.Camera.Value + 2, render)
	player.CharacterRemoving:Connect(clear)
end

return ViewModel

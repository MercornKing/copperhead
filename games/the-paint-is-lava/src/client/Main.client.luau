--!strict
-- Client entry point: wires up rendering, input, movement and interface.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

Net.Init()

local Palette = require(script.Parent.Palette)
local PaintRenderer = require(script.Parent.PaintRenderer)
local Effects = require(script.Parent.Effects)
local ViewModel = require(script.Parent.ViewModel)
local MovementController = require(script.Parent.MovementController)
local WeaponController = require(script.Parent.WeaponController)
local CharacterPaint = require(script.Parent.CharacterPaint)
local Hud = require(script.Parent.Hud)
local Locker = require(script.Parent.Locker)

Palette.Init()
PaintRenderer.Init()
PaintRenderer.Start()
Effects.Init()
ViewModel.Init()
MovementController.Init()
WeaponController.Init()
CharacterPaint.Init()
Hud.Init()
Locker.Init()

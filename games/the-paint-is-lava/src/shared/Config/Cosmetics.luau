--!strict
--[[
	Cosmetic catalog (Direction §14-§17). Cosmetics change how things LOOK, never how they
	PLAY. Validate.luau rejects any entry carrying a gameplay field, and rejects any paint
	effect that tries to recolour paint (green = safe / red = danger must stay readable).

	Unlock sources:
		Default      owned by everyone
		Achievement  earned by an achievement (Ref = achievement id)
		FreePass     free battle-pass track (Ref = tier number)
		PremiumPass  paid battle-pass track (Ref = tier number)
		Purchase     direct purchase (Ref = Roblox developer product id, 0 = not yet configured)

	Visual payloads are interpreted by the cosmetic appliers. Asset ids (animations, images,
	meshes) are 0 until the art pass; the appliers skip anything not yet configured.
]]

export type Unlock = {
	Source: "Default" | "Achievement" | "FreePass" | "PremiumPass" | "Purchase",
	Ref: (string | number)?,
}

export type Cosmetic = {
	Id: string,
	DisplayName: string,
	Category: string,
	Rarity: "Common" | "Rare" | "Epic" | "Legendary",
	Unlock: Unlock,
	Visual: { [string]: any },
}

-- Categories and the only Visual keys each may use.
local Categories: { [string]: { string } } = {
	CharacterSkin = { "Character", "Torso", "Arms", "Legs", "Head" },
	Headwear = { "Shape", "Color", "Material" },
	WeaponSkin = { "Color", "Material", "Accent" },
	Brush = { "BristleColor", "HandleColor" },
	Banner = { "Color", "Pattern", "Image" },
	Emote = { "AnimationId" },
	VictoryPose = { "AnimationId" },
	ProfileIcon = { "Image", "Color" },
	-- Paint effects may change splat SHAPE and sparkle only. No colour keys, ever.
	PaintEffect = { "SplatStyle", "Sparkle" },
}

local function c(
	id: string,
	name: string,
	category: string,
	rarity: "Common" | "Rare" | "Epic" | "Legendary",
	unlock: Unlock,
	visual: { [string]: any }
): Cosmetic
	return {
		Id = id,
		DisplayName = name,
		Category = category,
		Rarity = rarity,
		Unlock = unlock,
		Visual = visual,
	}
end

local DEFAULT: Unlock = { Source = "Default" }
local function ach(ref: string): Unlock
	return { Source = "Achievement", Ref = ref }
end
local function free(tier: number): Unlock
	return { Source = "FreePass", Ref = tier }
end
local function premium(tier: number): Unlock
	return { Source = "PremiumPass", Ref = tier }
end
local function buy(productId: number): Unlock
	return { Source = "Purchase", Ref = productId }
end

local list: { Cosmetic } = {
	-- Character skins (one default per launch character plus alternates)
	c("skin_dash_default", "Dash: Classic", "CharacterSkin", "Common", DEFAULT, { Character = "Dash" }),
	c("skin_blot_default", "Blot: Classic", "CharacterSkin", "Common", DEFAULT, { Character = "Blot" }),
	c("skin_juno_default", "Juno: Classic", "CharacterSkin", "Common", DEFAULT, { Character = "Juno" }),
	c("skin_rook_default", "Rook: Classic", "CharacterSkin", "Common", DEFAULT, { Character = "Rook" }),
	c("skin_dash_midnight", "Dash: Midnight Run", "CharacterSkin", "Rare", free(4), {
		Character = "Dash",
		Torso = Color3.fromRGB(25, 25, 60),
		Arms = Color3.fromRGB(25, 25, 60),
		Legs = Color3.fromRGB(10, 10, 20),
	}),
	c("skin_blot_sunset", "Blot: Sunset Splash", "CharacterSkin", "Epic", premium(5), {
		Character = "Blot",
		Torso = Color3.fromRGB(255, 175, 200),
		Arms = Color3.fromRGB(255, 200, 80),
		Legs = Color3.fromRGB(120, 40, 120),
	}),
	c("skin_juno_porcelain", "Juno: Porcelain", "CharacterSkin", "Legendary", premium(30), {
		Character = "Juno",
		Torso = Color3.fromRGB(245, 245, 255),
		Arms = Color3.fromRGB(170, 150, 230),
		Legs = Color3.fromRGB(245, 245, 255),
	}),
	c("skin_rook_steel", "Rook: Steelworks", "CharacterSkin", "Rare", buy(0), {
		Character = "Rook",
		Torso = Color3.fromRGB(150, 155, 170),
		Arms = Color3.fromRGB(150, 155, 170),
		Legs = Color3.fromRGB(40, 45, 60),
	}),

	-- Headwear (procedural shapes until the art pass)
	c("hat_none", "Bare Head", "Headwear", "Common", DEFAULT, { Shape = "None" }),
	c("hat_paint_bucket", "Paint Bucket", "Headwear", "Common", ach("first_elimination"), {
		Shape = "Bucket",
		Color = Color3.fromRGB(240, 240, 250),
	}),
	c("hat_propeller", "Propeller Cap", "Headwear", "Rare", free(10), {
		Shape = "Propeller",
		Color = Color3.fromRGB(60, 140, 255),
	}),
	c("hat_crown", "Drip Crown", "Headwear", "Legendary", premium(20), {
		Shape = "Crown",
		Color = Color3.fromRGB(255, 205, 50),
		Material = "Foil",
	}),
	c("hat_traffic_cone", "Traffic Cone", "Headwear", "Rare", buy(0), {
		Shape = "Cone",
		Color = Color3.fromRGB(255, 140, 30),
	}),

	-- Weapon skins
	c("wskin_factory", "Factory Finish", "WeaponSkin", "Common", DEFAULT, {}),
	c("wskin_bubblegum", "Bubblegum", "WeaponSkin", "Common", free(2), {
		Color = Color3.fromRGB(255, 150, 210),
		Material = "SmoothPlastic",
	}),
	c("wskin_chrome", "Chrome Drip", "WeaponSkin", "Epic", premium(10), {
		Color = Color3.fromRGB(210, 215, 225),
		Material = "Foil",
	}),
	c("wskin_marble", "Gallery Marble", "WeaponSkin", "Rare", ach("paint_10k"), {
		Color = Color3.fromRGB(235, 232, 225),
		Material = "Marble",
	}),
	c("wskin_neon_night", "Neon Night", "WeaponSkin", "Epic", buy(0), {
		Color = Color3.fromRGB(40, 20, 80),
		Material = "SmoothPlastic",
		Accent = Color3.fromRGB(120, 220, 255),
	}),

	-- Paintbrush designs
	c("brush_house", "House Brush", "Brush", "Common", DEFAULT, {}),
	c("brush_broom", "Street Broom", "Brush", "Rare", free(15), {
		BristleColor = Color3.fromRGB(200, 170, 90),
		HandleColor = Color3.fromRGB(110, 70, 40),
	}),
	c("brush_calligraphy", "Master Calligrapher", "Brush", "Legendary", ach("brush_master"), {
		BristleColor = Color3.fromRGB(30, 30, 30),
		HandleColor = Color3.fromRGB(180, 40, 160),
	}),

	-- Banners (shown on the kill feed and results screen)
	c("banner_plain", "Blank Canvas", "Banner", "Common", DEFAULT, { Color = Color3.fromRGB(80, 90, 120) }),
	c(
		"banner_skyline",
		"Skyline",
		"Banner",
		"Rare",
		free(7),
		{ Color = Color3.fromRGB(60, 120, 220), Pattern = "Stripes" }
	),
	c("banner_wallrunner", "Wall Runner", "Banner", "Rare", ach("wallrun_5k"), {
		Color = Color3.fromRGB(110, 60, 200),
		Pattern = "Chevrons",
	}),
	c("banner_champion", "Season Champion", "Banner", "Legendary", premium(25), {
		Color = Color3.fromRGB(255, 200, 40),
		Pattern = "Sunburst",
	}),

	-- Emotes and victory poses (animation ids arrive with the animation pass)
	c("emote_wave", "Wave", "Emote", "Common", DEFAULT, { AnimationId = 0 }),
	c("emote_brush_twirl", "Brush Twirl", "Emote", "Rare", free(12), { AnimationId = 0 }),
	c("emote_splat_dance", "Splat Dance", "Emote", "Epic", premium(15), { AnimationId = 0 }),
	c("pose_thumbs_up", "Thumbs Up", "VictoryPose", "Common", DEFAULT, { AnimationId = 0 }),
	c("pose_masterpiece", "Masterpiece", "VictoryPose", "Epic", ach("win_25"), { AnimationId = 0 }),

	-- Profile icons
	c("icon_drop", "Drop", "ProfileIcon", "Common", DEFAULT, { Color = Color3.fromRGB(80, 160, 255) }),
	c("icon_grapple", "Hook", "ProfileIcon", "Rare", ach("grapple_500"), { Color = Color3.fromRGB(255, 180, 60) }),

	-- Paint effects: shape and sparkle only, colour stays perspective green/red.
	c("fx_classic", "Classic Splat", "PaintEffect", "Common", DEFAULT, { SplatStyle = "Classic" }),
	c("fx_stars", "Star Splat", "PaintEffect", "Epic", premium(18), { SplatStyle = "Stars", Sparkle = true }),
}

local byId: { [string]: Cosmetic } = {}
for _, item in list do
	byId[item.Id] = item
end

-- Default equipped item per category for a brand-new profile.
local Defaults: { [string]: string } = {
	CharacterSkin = "skin_dash_default",
	Headwear = "hat_none",
	WeaponSkin = "wskin_factory",
	Brush = "brush_house",
	Banner = "banner_plain",
	Emote = "emote_wave",
	VictoryPose = "pose_thumbs_up",
	ProfileIcon = "icon_drop",
	PaintEffect = "fx_classic",
}

return {
	List = list,
	ById = byId,
	Categories = Categories,
	Defaults = Defaults,
}

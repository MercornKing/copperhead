--!strict
--[[
	Launch characters (Direction §11). Every character is MECHANICALLY IDENTICAL: same rig,
	same hitbox, same health, same speed, same wall-run and grapple, same weapons.
	A character is identity and personality only: colours, a signature piece of headwear,
	a one-line personality. Names and personalities are placeholders for creative approval.

	Only visual fields are allowed here; Validate.luau enforces that in the test suite.
]]

export type BodyColors = {
	Head: Color3,
	Torso: Color3,
	Arms: Color3,
	Legs: Color3,
}

export type CharacterDef = {
	Id: string,
	DisplayName: string,
	Personality: string,
	BodyColors: BodyColors,
	-- Procedural headwear shape (see client/server CosmeticBuilder). Asset-based models
	-- replace these once the art pass lands.
	Signature: string,
	AccentColor: Color3,
}

local Characters: { CharacterDef } = {
	{
		Id = "Dash",
		DisplayName = "Dash",
		Personality = "Never stops moving. Thinks walls are just sideways floors.",
		BodyColors = {
			Head = Color3.fromRGB(255, 204, 153),
			Torso = Color3.fromRGB(80, 70, 175),
			Arms = Color3.fromRGB(80, 70, 175),
			Legs = Color3.fromRGB(30, 40, 70),
		},
		Signature = "Visor",
		AccentColor = Color3.fromRGB(255, 220, 60),
	},
	{
		Id = "Blot",
		DisplayName = "Blot",
		Personality = "Cheerful chaos. Measures success in square studs covered.",
		BodyColors = {
			Head = Color3.fromRGB(160, 110, 80),
			Torso = Color3.fromRGB(230, 205, 80),
			Arms = Color3.fromRGB(230, 205, 80),
			Legs = Color3.fromRGB(90, 60, 140),
		},
		Signature = "Bucket",
		AccentColor = Color3.fromRGB(255, 255, 255),
	},
	{
		Id = "Juno",
		DisplayName = "Juno",
		Personality = "Calm, precise, three moves ahead. Every brush stroke is a signature.",
		BodyColors = {
			Head = Color3.fromRGB(110, 70, 50),
			Torso = Color3.fromRGB(150, 90, 230),
			Arms = Color3.fromRGB(150, 90, 230),
			Legs = Color3.fromRGB(240, 240, 250),
		},
		Signature = "Beret",
		AccentColor = Color3.fromRGB(40, 200, 230),
	},
	{
		Id = "Rook",
		DisplayName = "Rook",
		Personality = "Holds the high ground and refuses to give it back.",
		BodyColors = {
			Head = Color3.fromRGB(230, 180, 140),
			Torso = Color3.fromRGB(60, 64, 80),
			Arms = Color3.fromRGB(60, 64, 80),
			Legs = Color3.fromRGB(190, 140, 70),
		},
		Signature = "Headphones",
		AccentColor = Color3.fromRGB(255, 120, 200),
	},
}

return Characters

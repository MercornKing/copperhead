--!strict
--[[
	Launch game modes (Direction §8). Both use the same rule: your faction's paint is safe,
	every other faction's paint hurts. A "faction" is a team in Team Deathmatch and a single
	player in Free-for-All, so one code path serves both (and later multi-team modes, §10).
]]

export type TeamDef = {
	Name: string,
	-- Identity colour for scoreboards and nameplates only. Never used for paint, and
	-- deliberately far from both paint palettes (green/red and colour-blind blue/orange)
	-- so it can't be confused with safe/danger.
	IdentityColor: Color3,
	BrickColor: BrickColor,
}

export type ModeDef = {
	Id: string,
	DisplayName: string,
	Teams: { TeamDef }?, -- nil = every player is their own faction
	DurationSeconds: number, -- PLACEHOLDER (§22 exact match duration)
	ScoreLimit: number, -- PLACEHOLDER (§22 scoring values); eliminations to win
	-- Paint coverage breaks ties when eliminations are level at time-out. PLACEHOLDER.
	CoverageTiebreak: boolean,
	Blurb: string,
}

local Modes: { [string]: ModeDef } = {
	TeamDeathmatch = {
		Id = "TeamDeathmatch",
		DisplayName = "Team Deathmatch",
		Teams = {
			{
				Name = "Gold",
				IdentityColor = Color3.fromRGB(255, 210, 60),
				BrickColor = BrickColor.new("Bright yellow"),
			},
			{
				Name = "Violet",
				IdentityColor = Color3.fromRGB(150, 90, 255),
				BrickColor = BrickColor.new("Royal purple"),
			},
		},
		DurationSeconds = 480,
		ScoreLimit = 50,
		CoverageTiebreak = true,
		Blurb = "Two teams. Win the fight and the floor.",
	},
	FreeForAll = {
		Id = "FreeForAll",
		DisplayName = "Free-for-All",
		Teams = nil,
		DurationSeconds = 420,
		ScoreLimit = 20,
		CoverageTiebreak = true,
		Blurb = "Everyone for themselves. Green is yours. Everything red is someone else's.",
	},
}

return Modes

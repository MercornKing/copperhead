--!strict
--[[
	Achievements and milestones (Direction §16). Each watches one lifetime stat and awards
	a cosmetic. The final set is a design task for later; these prove the pipeline and
	cover the categories the direction names: eliminations, movement, grapple plays,
	paint coverage, wins and weapon mastery.

	Stats are tracked in PlayerData.Stats (server/PlayerData.luau).
]]

export type Achievement = {
	Id: string,
	DisplayName: string,
	Description: string,
	Stat: string,
	Threshold: number,
	Reward: string?, -- cosmetic id
}

local Achievements: { Achievement } = {
	{
		Id = "first_elimination",
		DisplayName = "First Splat",
		Description = "Eliminate an opponent.",
		Stat = "Eliminations",
		Threshold = 1,
		Reward = "hat_paint_bucket",
	},
	{
		Id = "trap_setter",
		DisplayName = "The Floor Is Yours",
		Description = "Eliminate 10 opponents with your paint on the ground, walls or anchors.",
		Stat = "HazardEliminations",
		Threshold = 10,
	},
	{
		Id = "wallrun_5k",
		DisplayName = "Sideways Sprinter",
		Description = "Wall-run 5,000 studs.",
		Stat = "WallRunDistance",
		Threshold = 5000,
		Reward = "banner_wallrunner",
	},
	{
		Id = "grapple_500",
		DisplayName = "Hooked",
		Description = "Land 500 grapples.",
		Stat = "Grapples",
		Threshold = 500,
		Reward = "icon_grapple",
	},
	{
		Id = "aerial_25",
		DisplayName = "Death From Above",
		Description = "Eliminate 25 opponents while airborne, wall-running or grappling.",
		Stat = "AerialEliminations",
		Threshold = 25,
	},
	{
		Id = "paint_10k",
		DisplayName = "Wall-to-Wall",
		Description = "Paint 10,000 cells.",
		Stat = "PaintCells",
		Threshold = 10000,
		Reward = "wskin_marble",
	},
	{
		Id = "win_25",
		DisplayName = "Masterpiece",
		Description = "Win 25 matches.",
		Stat = "Wins",
		Threshold = 25,
		Reward = "pose_masterpiece",
	},
	{
		Id = "brush_master",
		DisplayName = "Old Master",
		Description = "Eliminate 50 opponents with the Paintbrush.",
		Stat = "BrushEliminations",
		Threshold = 50,
		Reward = "brush_calligraphy",
	},
}

return Achievements

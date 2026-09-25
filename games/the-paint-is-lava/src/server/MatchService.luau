--!strict
--[[
	MatchService: match lifecycle, factions, teams, spawning and scoring.

	Phases:
		Waiting      not enough players; free roam with paint so the arena is never dead
		Intermission warm-up with the next mode's factions; nothing counts
		Active       the match: eliminations score, paint is cleared at the start
		Results      damage off, results + XP shown, then back to Intermission

	Replicated state lives in attributes on ReplicatedStorage.MatchState so clients can read
	it without extra remotes. Each player's faction is the "Faction" attribute on the Player.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tuning = require(Shared.Config.Tuning)
local Modes = require(Shared.Config.Modes)
local Net = require(Shared.Net)
local Factions = require(Shared.Paint.Factions)
local Signal = require(Shared.Signal)

type Phase = "Waiting" | "Intermission" | "Active" | "Results"

local MatchService = {}
MatchService.Eliminated = Signal.new() :: Signal.Signal<Player, Player?, string, string>

local S: any
local map: any
local stateFolder: Folder
local phase: Phase = "Waiting"
local mode: Modes.ModeDef = Modes.TeamDeathmatch
local rotationIndex = 0
local teamInstances: { Team } = {}
local allocator = Factions.NewAllocator()
local releasedThisMatch: { number } = {}
local teamScores: { [number]: number } = {}
local respawnTokens: { [Player]: number } = {}

local function setState(key: string, value: any)
	stateFolder:SetAttribute(key, value)
end

function MatchService.Phase(): Phase
	return phase
end

function MatchService.Mode(): Modes.ModeDef
	return mode
end

function MatchService.FactionOf(player: Player): number
	return (player:GetAttribute("Faction") :: number?) or 0
end

-- Can this player take and deal damage right now?
function MatchService.CombatEnabled(): boolean
	return phase ~= "Results"
end

-- Leaderstats (shows in Roblox's built-in player list) ---------------------------------

local function stat(player: Player, name: string): IntValue?
	local ls = player:FindFirstChild("leaderstats")
	return ls and ls:FindFirstChild(name) :: IntValue?
end

local function ensureLeaderstats(player: Player)
	if player:FindFirstChild("leaderstats") then
		return
	end
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, name in { "Eliminations", "Deaths" } do
		local v = Instance.new("IntValue")
		v.Name = name
		v.Parent = ls
	end
	ls.Parent = player
end

local function resetScores()
	table.clear(teamScores)
	for _, player in Players:GetPlayers() do
		local e, d = stat(player, "Eliminations"), stat(player, "Deaths")
		if e then
			e.Value = 0
		end
		if d then
			d.Value = 0
		end
	end
	setState("TeamScore1", 0)
	setState("TeamScore2", 0)
	setState("LeaderName", "")
	setState("LeaderScore", 0)
end

-- Factions ------------------------------------------------------------------------------

local function teamCounts(): { number }
	local counts = {}
	for i = 1, #teamInstances do
		counts[i] = 0
	end
	for _, player in Players:GetPlayers() do
		local f = MatchService.FactionOf(player)
		if counts[f] then
			counts[f] += 1
		end
	end
	return counts
end

local function assignFaction(player: Player)
	if mode.Teams then
		local counts = teamCounts()
		local best = 1
		for i, c in counts do
			if c < counts[best] then
				best = i
			end
		end
		player.Neutral = false
		player.Team = teamInstances[best]
		player:SetAttribute("Faction", best)
	else
		local id = allocator:Allocate()
		if not id then
			-- Lobby larger than 253 players: recycle an id whose owner left, wiping their paint.
			id = table.remove(releasedThisMatch, 1)
			if id then
				S.Paint.ClearFaction(id)
			end
		end
		player.Neutral = true
		(player :: any).Team = nil
		player:SetAttribute("Faction", id or 0)
	end
end

local function setupTeams()
	for _, t in teamInstances do
		t:Destroy()
	end
	table.clear(teamInstances)
	if mode.Teams then
		for i, def in mode.Teams do
			local team = Instance.new("Team")
			team.Name = def.Name
			team.TeamColor = def.BrickColor
			team.AutoAssignable = false
			team:SetAttribute("Faction", i)
			team.Parent = Teams
			teamInstances[i] = team
			setState("TeamName" .. i, def.Name)
		end
	end
end

local function assignAll()
	allocator:Reset()
	table.clear(releasedThisMatch)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Faction", 0)
	end
	-- Shuffle so teams aren't decided by join order.
	local list = Players:GetPlayers()
	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end
	for _, player in list do
		assignFaction(player)
	end
end

-- Spawning ------------------------------------------------------------------------------

local function hostilePositions(forFaction: number): { Vector3 }
	local out = {}
	for _, other in Players:GetPlayers() do
		local f = MatchService.FactionOf(other)
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and Factions.AreEnemies(f, forFaction) then
			table.insert(out, root.Position)
		end
	end
	return out
end

local function pickSpawn(player: Player): CFrame
	local faction = MatchService.FactionOf(player)
	local candidates: { CFrame } = map.FreeSpawns
	if mode.Teams and map.TeamSpawns[faction] then
		candidates = map.TeamSpawns[faction]
	end
	local enemies = hostilePositions(faction)
	local safe: { CFrame } = {}
	local best, bestScore = candidates[1], -math.huge
	for _, cf in candidates do
		local nearest = math.huge
		for _, pos in enemies do
			nearest = math.min(nearest, (pos - cf.Position).Magnitude)
		end
		if nearest >= Tuning.Respawn.SafeRadius then
			table.insert(safe, cf)
		end
		if nearest > bestScore then
			best, bestScore = cf, nearest
		end
	end
	if #safe > 0 then
		return safe[math.random(#safe)]
	end
	return best
end

function MatchService.Spawn(player: Player)
	if player.Parent ~= Players then
		return
	end
	respawnTokens[player] = (respawnTokens[player] or 0) + 1
	if MatchService.FactionOf(player) == 0 then
		assignFaction(player)
	end
	local cf = pickSpawn(player)
	player:LoadCharacterAsync()
	local character = player.Character
	if not character then
		return
	end
	character:PivotTo(cf + Vector3.new(0, 3, 0))
	local shield = Instance.new("ForceField")
	shield.Visible = true
	shield.Parent = character
	task.delay(Tuning.Respawn.SpawnProtection, function()
		if shield.Parent then
			shield:Destroy()
		end
	end)
	S.Combat.OnSpawned(player, character)
end

local function spawnAll()
	for _, player in Players:GetPlayers() do
		task.spawn(MatchService.Spawn, player)
	end
end

local function scheduleRespawn(player: Player)
	local token = (respawnTokens[player] or 0) + 1
	respawnTokens[player] = token
	task.delay(Tuning.Respawn.Delay, function()
		if respawnTokens[player] == token and player.Parent == Players then
			MatchService.Spawn(player)
		end
	end)
end

-- Scoring -------------------------------------------------------------------------------

local function refreshLeader()
	local leader, top = nil :: Player?, -1
	for _, player in Players:GetPlayers() do
		local e = stat(player, "Eliminations")
		if e and e.Value > top then
			leader, top = player, e.Value
		end
	end
	setState("LeaderName", if leader then leader.DisplayName else "")
	setState("LeaderScore", math.max(top, 0))
end

local function onDied(victim: Player)
	local killer, weaponId, cause = S.Combat.KillerOf(victim)
	local counting = phase == "Active"

	if counting then
		local d = stat(victim, "Deaths")
		if d then
			d.Value += 1
		end
		if killer and killer ~= victim then
			local e = stat(killer, "Eliminations")
			if e then
				e.Value += 1
			end
			local f = MatchService.FactionOf(killer)
			if mode.Teams then
				teamScores[f] = (teamScores[f] or 0) + 1
				setState("TeamScore" .. f, teamScores[f])
			end
			refreshLeader()
		end
	end

	local killerName = if killer then killer.DisplayName else "The Paint"
	local banner = if killer then S.Progression.BannerColor(killer) else nil
	Net.Event("KillFeed"):FireAllClients(killerName, victim.DisplayName, weaponId, banner)
	MatchService.Eliminated:Fire(victim, killer, weaponId, cause)
	scheduleRespawn(victim)
end

local function scoreLimitReached(): boolean
	if mode.Teams then
		for _, score in teamScores do
			if score >= mode.ScoreLimit then
				return true
			end
		end
		return false
	end
	for _, player in Players:GetPlayers() do
		local e = stat(player, "Eliminations")
		if e and e.Value >= mode.ScoreLimit then
			return true
		end
	end
	return false
end

-- Winning faction: most eliminations, then (optionally) most paint coverage.
local function winningFaction(): number
	local scores: { [number]: number } = {}
	if mode.Teams then
		for i = 1, #teamInstances do
			scores[i] = teamScores[i] or 0
		end
	else
		for _, player in Players:GetPlayers() do
			local e = stat(player, "Eliminations")
			scores[MatchService.FactionOf(player)] = if e then e.Value else 0
		end
	end
	local best, bestScore, bestCoverage = 0, -1, -1
	for f, score in scores do
		local coverage = if mode.CoverageTiebreak then S.Paint.Coverage(f) else 0
		if score > bestScore or (score == bestScore and coverage > bestCoverage) then
			best, bestScore, bestCoverage = f, score, coverage
		end
	end
	return best
end

local function finishMatch()
	local winner = winningFaction()
	local paint = S.Paint.TakeMatchPaint()
	local ranking = Players:GetPlayers()
	table.sort(ranking, function(a, b)
		local ea, eb = stat(a, "Eliminations"), stat(b, "Eliminations")
		return (if ea then ea.Value else 0) > (if eb then eb.Value else 0)
	end)

	local winnerName = ""
	if mode.Teams then
		winnerName = mode.Teams[winner] and mode.Teams[winner].Name or ""
	else
		for _, player in ranking do
			if MatchService.FactionOf(player) == winner then
				winnerName = player.DisplayName
			end
		end
	end

	local board = {}
	for place, player in ranking do
		local e, d = stat(player, "Eliminations"), stat(player, "Deaths")
		table.insert(board, {
			Name = player.DisplayName,
			Eliminations = if e then e.Value else 0,
			Deaths = if d then d.Value else 0,
			Place = place,
		})
	end

	for place, player in ranking do
		local e, d = stat(player, "Eliminations"), stat(player, "Deaths")
		local summary = {
			Mode = mode.Id,
			Won = MatchService.FactionOf(player) == winner,
			Place = place,
			Eliminations = if e then e.Value else 0,
			Deaths = if d then d.Value else 0,
			PaintCells = paint[player] or 0,
		}
		local award = S.Progression.AwardMatch(player, summary)
		Net.Event("MatchResults"):FireClient(player, {
			ModeName = mode.DisplayName,
			WinnerName = winnerName,
			Won = summary.Won,
			Place = place,
			Eliminations = summary.Eliminations,
			Deaths = summary.Deaths,
			PaintCells = summary.PaintCells,
			XP = award.XP,
			Tier = award.Tier,
			TierProgress = award.TierProgress,
			Board = board,
		})
	end
end

-- Lifecycle -----------------------------------------------------------------------------

local function enoughPlayers(): boolean
	local n = #Players:GetPlayers()
	if n >= Tuning.Match.MinPlayersToStart then
		return true
	end
	return n >= 1 and Tuning.Match.AllowSoloInStudio and RunService:IsStudio()
end

local function countdown(seconds: number, abort: (() -> boolean)?)
	setState("EndsAt", workspace:GetServerTimeNow() + seconds)
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if abort and abort() then
			return
		end
		task.wait(0.25)
	end
end

local function setPhase(p: Phase)
	phase = p
	setState("Phase", p)
end

local function chooseMode()
	rotationIndex = rotationIndex % #Tuning.Match.ModeRotation + 1
	mode = Modes[Tuning.Match.ModeRotation[rotationIndex]]
	setState("Mode", mode.Id)
	setState("ModeName", mode.DisplayName)
	setState("ModeBlurb", mode.Blurb)
	setState("ScoreLimit", mode.ScoreLimit)
	setState("HasTeams", mode.Teams ~= nil)
end

local function loop()
	while true do
		if not enoughPlayers() then
			setPhase("Waiting")
			setState("EndsAt", 0)
			while not enoughPlayers() do
				task.wait(1)
			end
		end

		chooseMode()
		setupTeams()
		assignAll()
		resetScores()
		setPhase("Intermission")
		spawnAll()
		countdown(Tuning.Match.IntermissionSeconds)

		if enoughPlayers() then
			S.Paint.Clear()
			S.Paint.TakeMatchPaint()
			resetScores()
			setPhase("Active")
			spawnAll()
			countdown(mode.DurationSeconds, function()
				return scoreLimitReached() or #Players:GetPlayers() == 0
			end)

			setPhase("Results")
			finishMatch()
			countdown(Tuning.Match.ResultsSeconds)
			S.Paint.Clear()
		end
	end
end

function MatchService.Init(services: any, builtMap: any)
	S = services
	map = builtMap
	local folder = Instance.new("Folder")
	folder.Name = "MatchState"
	folder.Parent = ReplicatedStorage
	stateFolder = folder
	setState("MapName", map.Name)
	setPhase("Waiting")
end

function MatchService.Start()
	local function onPlayer(player: Player)
		ensureLeaderstats(player)
		player:SetAttribute("Faction", 0)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
			humanoid.Died:Connect(function()
				onDied(player)
			end)
		end)
		if phase ~= "Waiting" or enoughPlayers() then
			assignFaction(player)
		end
		-- Wait for the profile so the character spawns wearing the right cosmetics.
		S.PlayerData.WaitFor(player, 10)
		MatchService.Spawn(player)
	end

	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		respawnTokens[player] = nil
		if not mode.Teams then
			local f = MatchService.FactionOf(player)
			if f ~= 0 then
				-- Keep their paint hostile to everyone for the rest of the match; recycle
				-- the id only if the pool runs dry.
				table.insert(releasedThisMatch, f)
			end
		end
	end)

	task.spawn(loop)
end

return MatchService

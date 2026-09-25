--!strict
--[[
	Factions: who owns paint and who it hurts.

	Paint ownership is always a faction id. In Team Deathmatch a faction is a team; in
	Free-for-All it is a single player; a future 4x2 mode is simply 4 factions (§10).
	0 means "no owner" (unpainted). Ids fit in one byte: up to 253 independent player
	factions per server (254 is reserved for environment paint), far above any sensible
	lobby size.

	Relation() is the single source of the core rule (Direction §2):
		your paint is safe, enemy paint hurts.
	It is also what drives perspective colouring (Direction §9): Friendly renders as the
	safe colour, Hostile as the danger colour, for every viewer independently.
]]

local Factions = {}

Factions.NONE = 0
Factions.MAX = 254
-- Reserved owner for paint that belongs to no player (Studio test painter, future map
-- hazards/events). Hostile to everyone. Player factions use 1..MAX-1.
Factions.ENVIRONMENT = 254

export type Relation = "None" | "Friendly" | "Hostile"

-- How a surface owned by `owner` relates to a player in `viewer`'s faction.
function Factions.Relation(owner: number, viewer: number): Relation
	if owner == Factions.NONE then
		return "None"
	end
	if viewer ~= Factions.NONE and owner == viewer then
		return "Friendly"
	end
	return "Hostile"
end

-- True when paint owned by `owner` damages a player in faction `victim`.
function Factions.Hurts(owner: number, victim: number): boolean
	return Factions.Relation(owner, victim) == "Hostile"
end

-- True when two players may damage each other (no friendly fire in the launch modes).
function Factions.AreEnemies(a: number, b: number): boolean
	return a ~= Factions.NONE and b ~= Factions.NONE and a ~= b
end

export type Allocator = {
	Allocate: (self: Allocator) -> number?,
	Release: (self: Allocator, id: number) -> (),
	Reset: (self: Allocator) -> (),
	InUse: (self: Allocator) -> number,
}

-- Hands out unique faction ids for Free-for-All. Released ids are reused lowest-first.
function Factions.NewAllocator(first: number?, last: number?): Allocator
	local lo = first or 1
	local hi = last or (Factions.MAX - 1)
	local used: { [number]: boolean } = {}
	local count = 0

	local allocator = {}

	function allocator.Allocate(_self: Allocator): number?
		for id = lo, hi do
			if not used[id] then
				used[id] = true
				count += 1
				return id
			end
		end
		return nil
	end

	function allocator.Release(_self: Allocator, id: number)
		if used[id] then
			used[id] = nil
			count -= 1
		end
	end

	function allocator.Reset(_self: Allocator)
		table.clear(used)
		count = 0
	end

	function allocator.InUse(_self: Allocator): number
		return count
	end

	return (allocator :: any) :: Allocator
end

return Factions

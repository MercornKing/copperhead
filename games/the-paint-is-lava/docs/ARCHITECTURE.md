# Architecture

How the Roblox build implements the [Game Direction](GAME_DIRECTION.md). Written for agents and engineers picking up the next task; the creative director does not need to read this.

## Layout

| Path | Roblox location | Role |
| --- | --- | --- |
| `src/shared/` | `ReplicatedStorage.Shared` | Config, paint engine, maths, remotes; used by server and client |
| `src/server/` | `ServerScriptService.Server` | Authoritative game systems |
| `src/client/` | `StarterPlayerScripts.Client` | Rendering, input, movement, HUD, Locker |
| `src/character/` | `StarterCharacterScripts` | Replaces Roblox's default health regen |
| `tests/` | not shipped | Offline tests under Lune |

`default.project.json` is the Rojo project. `rojo build` produces a place file; `rojo serve` live-syncs into Studio.

## The paint engine (the part that matters most)

**Cells.** Every paintable part is split per face into a grid of about `Tuning.Paint.CellSize` studs (`shared/Paint/PaintGrid.luau`). Each cell has a global integer id. Face frames are right-handed so a cell's render frame never mirrors. Geometry is pure maths, unit-tested.

**State.** The whole arena's paint is one byte per cell (`shared/Paint/PaintState.luau`): the owner faction id, 0 for unpainted. A second byte stores strength for the optional "takes N hits to flip" rule. Canvas Yard has about 15,000 cells (checked by the map test against a 40,000 budget), so the full state is about 15 KB.

**Factions.** Ownership is a faction id, never a colour (`shared/Paint/Factions.luau`). A faction is a team in TDM and a single player in FFA; a future 4x2 mode is simply four factions. `Factions.Relation(owner, viewer)` is the only place the core rule is written: None, Friendly or Hostile. Ids 1 to 253 are players/teams; 254 is reserved for environment paint (the Studio test painter, future map events).

**Agreement without geometry on the wire.** The server stamps each paintable part with a `PaintOffset` attribute and the folder with totals (`shared/Paint/PaintRegistry.luau`). Clients rebuild the identical layout from replicated part sizes and those attributes, so only `(cellId, faction)` pairs are ever sent.

**Replication.** `server/PaintService.luau` batches changed cells and flushes every `BroadcastInterval` (50 ms) as a packed buffer: 5 bytes per changed cell. A joining client asks for a snapshot once its renderer is ready; the snapshot is run-length encoded and chunked, so an empty arena costs 9 bytes.

**Painting.** Weapons call `PaintService.PaintSphere(point, radius, faction, painter)`. A broadphase finds nearby paintable parts; per face, only cells whose centres fall inside the sphere and which the point is on or in front of are painted, so paint never bleeds through a wall. The directly hit cell is always painted, so tiny-radius weapons still leave a mark.

**Rendering.** `client/PaintRenderer.luau` mirrors the state and draws each painted cell as a thin, pooled, non-colliding tile, coloured by perspective (`client/Palette.luau`): Friendly is the safe colour, Hostile the danger colour. Changing faction or palette recolours in place. Per-cell shade variation keeps big areas from looking flat.

## The hazard rule

`server/HazardService.luau` probes every living player 10 times a second with short rays: feet, head, and a ring at chest and shin height, plus the grapple anchor if hooked. Any hostile cell touched means damage at one flat rate (`Tuning.Hazard.DamagePerSecond`). There are no per-verb rules: walking, landing, wall-running, touching a ceiling and hanging from a grapple are all "touching a surface" (Direction §2). Damage is credited to the last painter of the touched cell, so traps earn eliminations. The server also sets `InHazard` on the character, which drives the HUD warning, so the warning is exactly as true as the damage.

## Combat

`server/CombatService.luau` is authoritative. Clients send intent (`Fire`, `Reload`, `ThrowGrenade`, `Swing`); the server checks the weapon is actually held, rate of fire (20% jitter tolerance), ammo, and that the origin is near the character, then simulates every projectile with the same `shared/Ballistics.luau` the client uses for visuals. A hit on a hostile player deals direct damage (plus splash for explosive weapons); a hit on the arena paints it (plus splash damage). Paint flies through teammates. All damage, including hazard damage, goes through one `DealDamage` function that honours spawn protection and the Results phase.

The client predicts ammo and rate of fire and draws its own projectiles instantly; `AmmoSync` corrects drift.

## Movement

Roblox gives each client physics ownership of its own character, so movement runs client-side for zero latency (`client/MovementController.luau`):

- **Sprint:** walk-speed change, multiplied by the held weapon's `MoveSpeedMultiplier`.
- **Wall-run:** airborne, pushing forward, moving fast enough, wall within reach on the left or right: a `LinearVelocity` drives the character along the wall with a slight sink, capped by `MaxDuration`. Jump pushes off the wall. Camera rolls toward the wall.
- **Grapple:** camera raycast to any arena geometry within range; a `RopeConstraint` with the winch enabled gives both pull and swing. Release on key-up, jump (with a hop), or `MaxAttachSeconds`.

The client reports its movement state and grapple anchor to `server/MovementService.luau`, which validates the anchor (part is in the arena, point is on the part, within range), draws the rope for everyone else, and hands the anchor to the hazard check. It also measures wall-run distance and grapple count for achievements.

## Matches

`server/MatchService.luau` runs Waiting → Intermission (warm-up with the upcoming mode's factions) → Active → Results, rotating modes from `Tuning.Match.ModeRotation`. Phase, mode, timer and scores replicate as attributes on `ReplicatedStorage.MatchState`; each player's faction is the `Faction` attribute on the Player. Eliminations and deaths also populate `leaderstats`, so Roblox's built-in player list works as a scoreboard. Spawn selection prefers spawns at least `SafeRadius` from any hostile. Paint is cleared at match start and after results.

## Progression and cosmetics

`server/PlayerData.luau` persists profiles in a DataStore with a light session lock, autosave, and save on leave/shutdown. It falls back to temporary profiles when DataStores are unavailable (Studio without API access).

`server/Progression.luau` computes ownership instead of granting it: pass items are owned when your tier reaches them (premium also needs the pass), achievement items when the achievement is unlocked; only direct purchases are stored. Premium is a Roblox game pass; direct cosmetic purchases are developer products handled idempotently in `ProcessReceipt`. Product and pass ids are `0` (unconfigured) until the store is set up.

**Cosmetics-only is enforced by code, not convention.** `shared/Validate.luau` rejects any cosmetic or character carrying a gameplay field, any paint effect that recolours paint, any weapon that doesn't paint, and any dangling reference. It runs in the test suite and at server boot; the server refuses to start on a failing catalog. `server/CharacterService.luau` restamps health, speed and jump from `Tuning` on every spawn; players' own avatars are not loaded, so every character shares one rig and hitbox; cosmetic and weapon parts are massless and not raycastable.

## Scale

"Architecturally as many players as possible" (Direction §22) shaped these choices:

- One byte per cell and 253 player factions per server; FFA ids are recycled only if the pool runs dry.
- Paint traffic scales with how much paint changes, not with player count: one batched delta per 50 ms for everyone.
- Hazard probes cost about 20 short raycasts per player per tick against a small include-list.
- Projectiles are simulated server-side as plain data (no parts), so a firefight costs maths, not instances.

The practical cap is the Roblox server size set in Game Settings and what stays readable. Measure before raising it (see [PLAYTEST_PLAN.md](PLAYTEST_PLAN.md)).

## Known limits and next steps

| Area | Current | Next |
| --- | --- | --- |
| Netcode | No lag compensation; server simulates from receipt | Rewind hit-validation for direct hits if fast targets feel unfair |
| Rendering | One tile part per painted cell | Per-surface `EditableImage` textures for bigger maps or finer cells |
| Anti-cheat | Server validates remotes; movement is client-owned (Roblox norm) | Server-side speed/teleport checks; grapple state inferred from motion |
| Grapple visuals | Server rope for others, local rope for self | Proper hook model and reel animation |
| Art | Procedural greybox weapons, headwear and characters | Assets per [ASSET_BRIEFS.md](ASSET_BRIEFS.md) |
| Animation | Default Roblox animations; emotes and poses have no animation ids | Animation pass (wall-run, grapple, brush swipe, emotes) |
| Audio | None | Paint splats, hits, hazard sizzle, wall-run and grapple sounds |

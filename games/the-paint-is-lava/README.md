# The Paint Is Lava (Roblox)

A colourful, family-friendly first-person movement shooter where every weapon fires paint. Your paint is safe; enemy paint hurts. Shoot opponents, or paint the floors, walls and ceilings to turn the arena against them, while grappling and wall-running through a vertical map.

This folder is the Roblox build, developed alongside the Meta Horizon version. The design source of truth is [docs/GAME_DIRECTION.md](docs/GAME_DIRECTION.md).

## Status: first playable prototype

Everything in the launch scope (Direction §18) exists in greybox form and runs end to end: warm-up → match → results → XP → cosmetics. It has been type-checked, unit-tested and built into a place file, but it has **not yet been played in Roblox Studio**; that is the next step ([docs/PLAYTEST_PLAN.md](docs/PLAYTEST_PLAN.md), Session 0).

| Launch scope (§18) | In this build |
| --- | --- |
| Paint gun mechanics, direct paint damage, environmental paint | Server-authoritative paint projectiles; every hit either damages or paints |
| Hostile-surface damage | One rule for floors, walls, ceilings, wall-runs and grapples |
| Health and eliminations | Health, regen, spawn protection, kill credit (including paint traps), kill feed |
| First-person movement, jumping, grappling, wall-running, chaining | Sprint, wall-run with wall-jump, rope-and-winch grapple with swing |
| Fully paintable surfaces, open vertical map | Canvas Yard: bases, wall-run lanes, tower, sky bridge, tunnel, grapple anchors |
| Weapon archetypes | Pistol, rifle, spray hose, bucket launcher, paint bomb, big brush |
| Team Deathmatch, Free-for-All | Both, rotating, with perspective green/red paint |
| Several visual characters, identical gameplay | Four characters; stats locked by code |
| Cosmetics, unlocks, achievements, free and premium progression | Locker, 34 cosmetics, 8 achievements, 30-tier season pass (store ids to be configured) |

Art, animation and audio are placeholders; see [docs/ASSET_BRIEFS.md](docs/ASSET_BRIEFS.md).

## Play it in Roblox Studio

**Option A: open the place file.** Build it (below) or download `ThePaintIsLava.rbxl` from the latest CI run's artifacts, open it in Roblox Studio, press **Play**.

**Option B: live sync (for development).** Install [Rokit](https://github.com/rojo-rbx/rokit), then:

```bash
cd games/the-paint-is-lava
rokit install                                   # rojo, stylua, lune, luau-lsp
rojo build default.project.json -o ThePaintIsLava.rbxl
rojo serve                                      # then connect from the Rojo Studio plugin
```

Playing alone in Studio starts a match immediately, and a Studio-only test painter sprays enemy paint so you can feel the hazard rule without a second player. For multiplayer, use Studio's **Test → Clients and Servers**.

### Controls

| Action | Keyboard / mouse | Gamepad | Touch |
| --- | --- | --- | --- |
| Fire / brush swipe | Left mouse | R2 | Fire button |
| Reload | R | X | Reload button |
| Paint bomb | G | D-pad up | Bomb button |
| Grapple (hold) | E | L2 | Hook button |
| Sprint | Shift | L3 | |
| Jump / wall-jump / release grapple | Space | A | Jump |
| Switch weapon | 1 to 5 | L1 / R1 (Roblox hotbar) | Hotbar |
| Locker (cosmetics, season pass, colour-blind paint) | L | Select | Locker button |

## Publishing to Roblox (when ready)

1. Publish the place from Studio (File → Publish to Roblox) as a new experience.
2. Game Settings → Security: enable **Studio Access to API Services** so profiles save when testing in Studio.
3. Game Settings → Places: set the server size (start at 12; see the playtest plan before raising it).
4. Monetization: create a game pass for the premium season track and put its id in `src/shared/Config/Season.luau` (`PremiumGamePassId`); create developer products for shop cosmetics and put their ids in `src/shared/Config/Cosmetics.luau`. Until then, premium and shop items are hidden or locked.

## For agents and developers

| Doc | What it covers |
| --- | --- |
| [docs/GAME_DIRECTION.md](docs/GAME_DIRECTION.md) | The creative direction (source of truth) |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | How each system works, scale choices, known limits |
| [docs/TUNING.md](docs/TUNING.md) | Every undecided number, where it lives, balancing framework |
| [docs/PLAYTEST_PLAN.md](docs/PLAYTEST_PLAN.md) | Test sessions with pass conditions |
| [docs/ASSET_BRIEFS.md](docs/ASSET_BRIEFS.md) | Art, animation and audio briefs |

Checks (all run in CI on changes to this folder):

```bash
lune run tests/run.luau                         # offline unit tests (paint engine, rules, map, catalogs)
rojo sourcemap default.project.json -o sourcemap.json --include-non-scripts
luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --defs=globalTypes.d.luau src/
stylua --check src tests
rojo build default.project.json -o ThePaintIsLava.rbxl
```

`globalTypes.d.luau` (Roblox API types) comes from the [luau-lsp repository](https://github.com/JohnnyMorganz/luau-lsp/tree/main/scripts); CI downloads it.

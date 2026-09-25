# Tuning and Balancing

Every number that shapes feel lives in two files, so a playtest note can become a change in minutes:

- `src/shared/Config/Tuning.luau`: paint, health, hazard, movement, match, respawn, progression, colours.
- `src/shared/Config/Weapons.luau`: every weapon's player-side and arena-side stats.

Nothing cosmetic, purchased or character-specific can touch either file (Direction §11, §15); the test suite enforces it.

## The undecided list (Direction §22)

Each item is a working placeholder so the build is playable. None is a decision. Record the decision here when playtests settle it.

| Direction §22 item | Where it lives | Placeholder | Decided |
| --- | --- | --- | --- |
| Maximum player count | Roblox Game Settings (server size); code supports 253 factions | Test at 8, 12, 16 | |
| Team sizes | Follows server size; teams auto-balance | Even split | |
| Health values | `Tuning.Health.MaxHealth` | 100 | |
| Time-to-kill | Emerges from health and `Weapons.*.DirectDamage` / `FireRate` | Rifle about 0.75 s, pistol about 1.25 s | |
| Hostile-paint damage rate | `Tuning.Hazard.DamagePerSecond` | 22 / s (about 4.5 s to eliminate) | |
| How quickly paint can be replaced | `Tuning.Paint.HitsToFlip` | 1 (any hit repaints) | |
| Whether paint naturally disappears | `Tuning.Paint.DecaySeconds` | 0 (permanent until repainted) | |
| Weapon ammunition limits | `Weapons.*.MagazineSize`, `Tuning.ReserveAmmoUnlimited` | Magazines, unlimited reserve | |
| Respawn rules | `Tuning.Respawn` | 3 s delay, 2 s spawn protection | |
| Match duration | `Modes.*.DurationSeconds` | TDM 8 min, FFA 7 min | |
| Scoring values | `Modes.*.ScoreLimit`, `CoverageTiebreak` | TDM 50, FFA 20; paint coverage breaks ties | |
| Launch weapon roster | `Tuning.Loadout` | Rifle, Spray Hose, Bucket Launcher, Splat Pistol, Big Brush, plus Paint Bombs | |
| Number of launch characters | `Config/Characters.luau` | 4 | |
| Battle-pass size / season length | `Config/Season.luau` | 30 tiers, 600 XP each | |
| Multi-team colour handling | Not built (Direction §10) | n/a | |
| Class design | Not built (Direction §12) | n/a | |
| Roblox monetization implementation | `Season.PremiumGamePassId`, developer product ids in `Config/Cosmetics.luau` | Game pass for premium; products for direct cosmetics; ids unset | |

## Weapon balancing framework (Direction §7)

A weapon has two jobs: pressure players and reshape the arena. Score each weapon on both axes at every playtest.

| Weapon | Player job | Arena job | Key stats |
| --- | --- | --- | --- |
| Splat Pistol | Accurate duelling, finishing | Tiny marks | `DirectDamage` 24, `FireRate` 4, `PaintRadius` 1.6, `Spread` 0.6° |
| Streak Rifle | All-rounder | Medium lines | 17 dmg, 8/s, radius 2.4, slight drop |
| Spray Hose | Weak per hit, suppressive | Paints fast but thin and wasteful | 9 dmg, 15/s, radius 1.4, 4° spread, heavy drop |
| Bucket Launcher | Burst damage, splash | Huge areas: turns a landing zone into a trap | 45 direct + 40 splash, 0.8/s, radius 11 |
| Paint Bomb | Area denial | Wide burst after bouncing | 55 splash, radius 13, 1.6 s fuse, 2 per life |
| Big Brush | High close-range damage | Big swipe right around you, plus underfoot | 50 dmg, reach 8, 100° arc |

Two derived numbers are worth tracking per weapon:

- **Time-to-kill** = `ceil(MaxHealth / DirectDamage) / FireRate` (ignoring misses and regen).
- **Paint rate** ≈ `PaintRadius² × FireRate`: the arena area a weapon can claim per second. The launcher's low fire rate is offset by its huge radius; the hose's high fire rate by its small one.

A weapon that tops both columns is overpowered. A weapon that tops neither needs a job.

## Playtest questions per system

- **Hazard:** Is red paint scary but survivable? Can you cross a short red strip on purpose to take a shortcut? (Target: yes, at a cost.) Is being trapped ever hopeless? (Target: no; grapple or a brush swipe should always offer an out.)
- **Paint replacement:** Can a team retake a lost corridor in about 5 to 10 seconds of focused effort? If never, raise coverage or add `HitsToFlip` only for defenders' benefit; if trivially, lower coverage.
- **Wall-run:** Can an average player chain two walls in the lanes within their first match? Does painting a lane wall visibly change routes?
- **Grapple:** Does the hook feel like an escape and an attack tool, not a teleport? Does grappling a red anchor feel like a deliberate risk?
- **Readability:** In FFA with 8+ players, can testers always say whether the surface ahead hurts? (Target: instant, 100%.)
- **Time-to-kill:** Do fights feel like Call of Duty pace (fast) without feeling random?

## Changing a number

1. Edit the value in `Tuning.luau` or `Weapons.luau`.
2. Run the offline tests (`lune run tests/run.luau`); they catch broken or invalid configs.
3. Playtest, then record the outcome in the table above.

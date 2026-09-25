# Playtest Plan

The loop from Direction §21: implement → **test** → **review** → correct → approve. This page is the "test" and "review" steps. Each check has a pass condition; anything that fails becomes the next agent task.

## Session 0: solo smoke test in Studio (15 minutes)

Open the place in Roblox Studio and press Play. You are alone, so a Studio-only "hostile painter" sprays enemy-owned paint around the arena every few seconds (turn it off in `Tuning.Dev`).

| # | Check | Pass |
| --- | --- | --- |
| 0.1 | You spawn on a team deck in first person holding the Streak Rifle | Yes |
| 0.2 | Shooting a wall leaves green paint; the Spray Hose leaves thin lines, the Bucket Launcher a huge patch | Visibly different coverage |
| 0.3 | Red patches appear over time (hostile painter) | Yes |
| 0.4 | Standing on red: health drains, screen edges pulse, "ENEMY PAINT!" shows | All three |
| 0.5 | Wall-run along a lane wall (jump at it while holding forward), then press Space to wall-jump | Works within a few tries |
| 0.6 | Wall-run along a wall with red on it | Takes damage while running |
| 0.7 | Hold E to grapple a yellow anchor; release to fly | Pull plus swing, lands you high |
| 0.8 | Grapple a red surface and hang | Takes damage while attached |
| 0.9 | Paint over red with your own paint, then stand on it | Safe again |
| 0.10 | Big Brush swipe paints a wide patch in front and under you | Yes |
| 0.11 | Throw a Paint Bomb (G); it bounces, then bursts | Yes |
| 0.12 | Press L: change character and headwear; toggle colour-blind paint | Look changes; paint turns blue/orange |
| 0.13 | Warm-up → match → results screen with XP | Full loop completes |

## Session 1: two to four players (Studio "Local Server" test or a private server)

In Studio, use Test → Clients and Servers with 2 to 4 players.

| # | Check | Pass |
| --- | --- | --- |
| 1.1 | Each player sees their own team's paint green and the other team's red, on the same wall | Opposite colours per viewer |
| 1.2 | Direct hits reduce health, show a hit marker for the shooter, and tint the victim | All three |
| 1.3 | Teammates' paint is safe; enemy paint hurts | Yes |
| 1.4 | Eliminations update the player list and team score; kill feed names the weapon | Yes |
| 1.5 | Eliminated by standing in someone's paint: they get the elimination credit | Yes |
| 1.6 | FFA round: every other player's paint is red to you | Yes |
| 1.7 | Late joiner sees all existing paint correctly | Yes |

## Session 2: feel review (creative director)

Play at least three full matches, then answer on a 1 to 5 scale. Anything below 4 is a task.

1. Does every firefight change where people can move? (Direction §20)
2. Is "green safe, red hurts" instant, even at speed and in FFA?
3. Does movement chaining feel fluid (jump → wall-run → jump → grapple → aerial shot)?
4. Is combat pace close to the intended Call of Duty / Titanfall energy?
5. Does missing a shot still feel useful because of the paint it leaves?
6. Is painting the world satisfying in itself?
7. Is it family-friendly throughout?

## Session 3: scale and readability

Run public or private servers at 8, 12 and 16 players (raise the server size in Game Settings). Record:

- Server heartbeat (Developer Console → Server Stats) stays near 60.
- Client frame rate on a mid-range phone stays above 30 with the arena heavily painted.
- Network receive stays comfortable (Developer Console → Network) during a big firefight.
- Readability questions from Session 2 still score 4+.

The highest player count that passes everything is the launch cap for that mode.

## Filing results

For each failed check, file one task with: the check number, what happened, expected result, and a clip or screenshot. Agents pick those up next.

# The Paint Is Lava: Consolidated Game Direction (Roblox)

This is the design source of truth for the Roblox build. It mirrors the creative director's consolidated direction, with Roblox referenced wherever the original names Meta Horizon. When this document and the code disagree, this document wins; update the code or bring the change back here for approval.

Section numbers (§1 to §22) are referenced throughout the code and the other docs.

## 1. High-level concept

The Paint Is Lava is a fast-paced, family-friendly, first-person multiplayer shooter built for the Roblox platform.

The central mechanic is that paint is both ammunition and territory control.

Players don't merely shoot other players. Their weapons continuously alter the arena by covering floors, walls, ceilings, structures, and traversal routes in paint. That paint then affects where opponents can safely move.

The intended experience combines:

- fast FPS gunplay;
- high-mobility traversal;
- dynamic territory control;
- vertical and horizontal level design;
- instantly understandable rules;
- colorful, non-gory combat;
- competitive multiplayer;
- cosmetic progression rather than pay-to-win progression.

The broad feel takes inspiration from the speed and immediacy of games such as Call of Duty and the movement freedom of Titanfall, while the paint-control system gives the game its own identity.

## 2. Core gameplay rule

The simplest expression of the game is:

> Your paint is safe. Enemy paint hurts.

This should remain consistent throughout the game.

Players can paint essentially all major traversable surfaces: floors, walls, ceilings, platforms, vertical structures, and other appropriate level geometry.

Enemy paint becomes a temporary environmental hazard. Touching hostile paint causes damage regardless of how the player interacts with that surface. That includes:

- walking across it;
- running across it;
- landing on it;
- wall-running across it;
- touching it during traversal;
- grappling onto it and remaining attached.

A player grappling to an enemy-painted surface therefore continues taking damage while attached to it. Likewise, wall-running along hostile paint damages the player just as running over hostile paint on the floor would.

The aim is to avoid arbitrary exceptions. Players should very quickly learn:

> Green/good surface = safe. Red/bad surface = dangerous.

## 3. Paint as combat

Paint serves two functions simultaneously.

### Direct combat

Hitting an opposing player with paint:

- visibly colors them;
- reduces their health;
- provides normal FPS-style combat feedback.

There is no realistic injury or gore.

### Environmental combat

Missing an opponent isn't necessarily wasted ammunition. Paint hitting the environment:

- changes ownership/control of that surface;
- creates hazardous terrain for enemies;
- blocks or discourages routes;
- can interfere with wall-running;
- can interfere with grappling;
- can create traps;
- can protect routes for allies;
- can reshape the tactical state of the arena.

This means players with different skill profiles can contribute differently. A very accurate player can focus on direct eliminations. Another player may be excellent at controlling routes and repainting the battlefield. A movement-focused player may exploit vertical routes and unconventional attack angles.

## 4. Movement system

Movement is one of the main pillars rather than simply a way of getting between firefights.

The game should support fluid combinations of running, jumping, aerial movement, grappling, wall-running, vertical traversal and lateral traversal.

### Grappling hook

Players have access to a grappling hook as a fundamental traversal mechanic. It allows players to:

- escape dangerous painted floors;
- rapidly change elevation;
- cross gaps;
- reach platforms;
- swing or pull themselves toward geometry;
- attack from unexpected angles;
- chain movement together.

The grappling hook itself participates in the paint system. Grappling onto hostile-painted geometry causes damage while the player remains attached. That prevents grappling from becoming a universal escape button that ignores territory control.

### Wall-running

Titanfall-style wall-running is another core movement requirement. Players should be able to use long walls and vertical structures as genuine movement lanes rather than treating walls as mere boundaries.

Wall-running should combine naturally with sequences such as:

> jump → wall-run → jump → grapple → aerial attack → land/reposition

Hostile-painted walls damage wall-runners. Consequently, painting a wall isn't simply cosmetic territory capture: it can remove or weaken one of the opponent's movement routes.

## 5. Level-design philosophy

Maps need to be designed around the interaction between paint and movement. They should generally be more open than traditional corridor-heavy FPS maps and offer meaningful gameplay on multiple axes.

Good maps should contain:

- horizontal routes;
- vertical routes;
- open sightlines;
- cover;
- high ground;
- long wall-running surfaces;
- grapple points;
- platforms;
- alternative routes;
- aerial attack opportunities;
- places where repainting a surface meaningfully changes player behavior.

The arena should gradually evolve during a match. Instead of players merely moving around a static map, they are constantly altering which routes are safe. That's one of the game's most important differentiators.

## 6. Weapon philosophy

The game can use familiar shooter weapon archetypes so players immediately understand their general purpose. The current intended arsenal includes:

- pistols;
- rifles;
- machine guns;
- RPG/launcher-style weapons;
- grenades;
- melee;
- a paintbrush as the primary melee concept.

Every weapon ultimately uses paint. There should not be a parallel conventional bullet/explosive combat system.

An RPG, for example, fires an explosive paint projectile rather than a lethal military rocket. A grenade distributes paint over an area. A paintbrush attacks at close range while physically applying paint.

## 7. Weapon balancing

Weapon balance isn't simply about damage-per-second. Each weapon affects both players and territory, so balancing needs to account for both.

The major variables identified are:

- direct player damage;
- radius/splash damage;
- paint coverage per shot;
- rate of fire;
- effective range;
- accuracy.

Additional balancing controls can include magazine capacity, reload time, projectile velocity, movement while firing, ammo availability, projectile trajectory and splash radius.

That creates interesting tradeoffs. A launcher might have a very low fire rate but paint a huge section of floor or wall. A machine gun might paint rapidly but in thin, less efficient lines. A pistol may have limited environmental coverage while being responsive and accurate against players. The paintbrush might have almost no range but create a large paint swipe immediately around the player.

So a weapon doesn't have to have the highest direct damage to be strategically powerful.

## 8. Launch game modes

Two core launch modes are agreed.

### Team Deathmatch

This is likely to be the primary/default competitive experience. Players are divided into two teams. Teammate paint is safe. Enemy paint is hazardous. Players therefore fight both for eliminations and for usable territory.

The exact player count will depend on what proves technically and ergonomically appropriate on Roblox.

### Free-for-All Deathmatch

Everyone fights everyone. Each player is independently hostile to every other player.

The maximum player count remains to be determined through platform testing and gameplay readability. Paint readability becomes particularly important here because technically many different players could have different colors. That leads to the perspective-based color system.

## 9. Paint readability

Rather than requiring players to remember a large set of team or player colors, the game should strongly consider a perspective-relative paint visualization system.

From the player's own perspective:

- your paint / friendly paint = green;
- all hostile paint = red.

This can remain true even if the underlying game internally tracks different ownership colors.

The major benefit is instant readability. Players don't need to stop and think:

> "Was purple player three or player five?"

They only need to know:

> "Green is safe. Red hurts me."

This is particularly valuable given how quickly players will be moving.

A more complicated color representation could still be used in spectator mode, scoreboards, replays, cosmetic presentation and team identification. But moment-to-moment hazard recognition should remain extremely easy.

## 10. Multi-team modes

Multi-team play is not required for the initial launch. It is a possible later expansion. One example discussed is four teams of two in an eight-player match.

Multi-team play introduces additional UX questions because treating every opponent as simply red makes it harder to determine which opposing team owns a surface. That doesn't necessarily prevent the system from working (the paint is hazardous regardless), but strategic information may matter in certain game modes.

So multi-team paint visualization should be solved when that mode is actually developed rather than complicating the launch game unnecessarily.

## 11. Player characters at launch

The game should launch with a handful of selectable characters. However, all launch characters are mechanically equivalent.

Choosing a character should not affect health, movement speed, wall-running, grappling, damage, weapon performance or abilities.

At launch, characters exist for identity, personality, aesthetic preference and cosmetic customization.

This dramatically simplifies balance and prevents monetization from becoming entangled with competitive power.

## 12. Potential future classes

Class-based gameplay is something that may be explored later, particularly within team modes. Possible future classes could differentiate players according to weapon selection, mobility emphasis, territory painting capability, support roles, offensive roles and defensive roles.

However, this is deliberately not part of the initial character system. First establish whether the universal movement/combat system is fun. Only after the weapon roster, player counts and team gameplay are understood properly should classes be considered.

## 13. Visual direction

The game should be colorful, friendly, energetic, readable, stylized and family-appropriate.

Combat should feel impactful without relying on realistic violence. Damage can instead be communicated through paint accumulation, HUD feedback, animation, audio, hit effects, color effects and character reactions.

The paint itself should be visually satisfying because painting the world is one of the main rewards of firing a weapon.

## 14. Cosmetic customization

Customization is intended to be a major part of the game's progression and commercial model. Both characters and weapons should be cosmetically customizable. Launch should include a meaningful initial range rather than only one or two token cosmetics.

Potential cosmetic categories include:

- character skins;
- outfits;
- headwear/accessories;
- weapon skins;
- weapon model treatments;
- paint-gun appearances;
- paintbrush designs;
- banners;
- emotes;
- victory poses;
- player profile cosmetics;
- potentially cosmetic paint effects where competitive readability is preserved.

Anything that changes the appearance of paint itself must be handled carefully so that it doesn't interfere with the green-safe/red-dangerous gameplay language.

## 15. Monetization

The game's monetization principle is non-negotiable: cosmetics only.

Purchasing something must never improve damage, health, mobility, grappling, wall-running, weapon stats, ammo, progression speed in ways that create combat power, or competitive capability.

No pay-to-win mechanics.

Monetization should primarily come from character cosmetics, weapon cosmetics, seasonal cosmetic content and paid battle-pass content.

The exact commerce implementation will need to match whatever monetization capabilities Roblox supports when it is implemented.

## 16. Free progression

Not all cosmetics should require payment. Players should be able to earn cosmetic rewards through ordinary play: gameplay milestones, achievements and a free battle-pass track.

This gives players meaningful progression even if they never spend money.

Examples could eventually include achievements for eliminations, movement accomplishments, wall-run distance, successful grapple plays, paint coverage, match wins and weapon mastery. The exact achievement set can be designed later.

## 17. Seasonal battle pass

The game should support a seasonal content model. Each season can include:

- **Free track:** cosmetics earned through gameplay.
- **Paid track:** additional premium cosmetics. The paid pass provides more cosmetic choice, not gameplay strength.

A season also gives a natural structure for introducing new cosmetics, maps, weapons, limited modes, events, themes and challenges.

Gameplay-affecting additions shouldn't require players to buy the pass.

## 18. Launch scope versus future scope

One of the most important development decisions is not to build everything at once. The initial game concentrates on:

- **Combat:** paint gun mechanics; direct paint damage; environmental paint; hostile-surface damage; health/elimination system.
- **Movement:** first-person movement; jumping; grappling; wall-running; movement chaining.
- **World:** fully paintable gameplay surfaces; open horizontal/vertical map design.
- **Weapons:** enough archetypes to demonstrate different paint/combat behaviors.
- **Modes:** Team Deathmatch; Free-for-All.
- **Characters:** several visual character options; identical gameplay behavior.
- **Progression:** cosmetics; unlocks; achievements/milestones; free progression; premium seasonal cosmetic progression where platform support permits.

## 19. Beyond launch

Once the core game is demonstrably fun, expansion can include:

- **Additional modes:** multi-team battles; four-team configurations; one-on-one/duel modes; other objective modes.
- **Additional weapons:** more unusual ways of applying paint rather than simply reskinning standard guns.
- **Classes:** potential team-oriented roles once the weapon ecosystem is sufficiently developed.
- **More movement interactions:** provided they strengthen rather than overwhelm the grapple/wall-run foundation.
- **More maps:** especially maps built around different movement identities, for example huge vertical drops, wall-running, grapple traversal, close quarters, or long-range paint control.
- **Seasons:** regular cosmetic and content releases.
- **Events:** temporary modes or special map rules.

## 20. Important design principle: don't dilute the central mechanic

Whenever something is considered for addition, the test should be:

> Does this make painting the arena, controlling space, moving through that space, or fighting over that space more interesting?

If it doesn't, be cautious about adding it.

The strongest part of the concept is not simply "an FPS with paint." It is:

> An FPS where every firefight physically changes the movement map for everyone involved.

A firefight on a wall-running route can remove that route. An explosion can turn a safe landing zone into a trap. A player can paint beneath someone before they land. A team can secure a movement corridor. An opponent can repaint it. A grappling escape route can suddenly become dangerous.

That's the behavior the whole design should reinforce.

## 21. Development philosophy

The creative director's role is primarily creative director/product owner rather than programmer, providing the vision, thematic direction, art direction, gameplay decisions, approvals, validation, and subjective judgment about whether something actually feels right.

The development process should be as agentic as practical. The agent's role is to turn those decisions into specifications, system designs, prompts, implementation tasks, asset briefs, balancing frameworks, test plans, troubleshooting instructions and iteration plans. Roblox's available creation tools and AI capabilities (alongside coding agents working from this repository) should then handle as much implementation work as possible.

The intended workflow is therefore:

> Vision → specification → agentic implementation → test → review → correction → approval → next system.

## 22. Things deliberately not locked yet

Several details should not be prematurely decided:

- exact maximum player count (architecturally as many as possible is preferred, considered from the start);
- exact team sizes;
- exact health values;
- time-to-kill;
- hostile-paint damage rate;
- how quickly paint can be replaced;
- whether paint naturally disappears;
- weapon ammunition limits;
- respawn rules;
- exact match duration;
- scoring values;
- exact weapon roster at launch;
- exact number of launch characters;
- precise battle-pass size;
- season duration;
- multi-team color handling;
- future class design;
- exact Roblox monetization implementation.

Those should come from prototyping and testing rather than arbitrary numbers decided before there is a playable build. In this build every one of them is a named, commented placeholder in one config file; see [TUNING.md](TUNING.md).

## The current elevator pitch

The Paint Is Lava is a colorful, family-friendly multiplayer first-person movement shooter where every weapon fires paint. Shoot opponents directly for damage or paint the floors, walls and ceilings to turn the arena itself against them. Grapple, jump and wall-run through highly vertical maps, but touch enemy paint and you'll take damage. Every firefight redraws the battlefield.

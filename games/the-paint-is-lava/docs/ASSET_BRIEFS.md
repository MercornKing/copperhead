# Asset Briefs

Everything in the current build is procedural greybox so the game is playable before any art exists. These briefs describe what replaces it. Each can be handed to an artist or to Roblox Studio's AI tools as-is. All assets must follow Direction §13: colourful, friendly, stylized, family-appropriate, no realistic violence.

## Global rules for every asset

- **Never paint-coloured.** Characters, weapons, maps and UI avoid the safe and danger hues (green and red, and the colour-blind blue and orange), so paint is always the most saturated thing in view. The test suite checks character and team colours against both palettes. Team identity colours are Gold and Violet and appear only on trims, nameplates and scoreboards.
- **Neutral, light surfaces** for everything paintable, so both paint colours pop.
- **Silhouette first.** Every weapon must be identifiable by shape alone at 30 studs.
- **Performance:** mobile-friendly triangle counts and texture sizes; Roblox `SurfaceAppearance` only where it clearly earns its cost.
- **Cosmetics never change hitboxes.** Headwear, skins and weapon models are visual only; the game makes them massless and unshootable.

## Characters (Direction §11)

Four launch characters on one shared rig (Roblox R15 proportions, identical scale). Personalities are placeholders for approval.

| Character | Personality | Signature piece | Palette |
| --- | --- | --- | --- |
| Dash | Never stops moving; thinks walls are sideways floors | Sport visor | Indigo, navy, sun-yellow trim |
| Blot | Cheerful chaos; measures success in square studs covered | Upturned paint bucket hat with a drip | Mustard, plum, white |
| Juno | Calm, precise, three moves ahead | Artist's beret | Lavender, white, teal trim |
| Rook | Holds the high ground and won't give it back | Chunky headphones | Charcoal, ochre, pink trim |

Deliverables per character: outfit meshes/textures, signature accessory, portrait for the Locker, and reactions for paint hits (flinch, "splatted" knock-back pose). No blood, wounds or ragdoll gore; eliminations read as "splatted and out".

## Weapons (Direction §6)

Every weapon visibly carries paint: a translucent canister or tank that reads as "paint" without being green or red (neutral glass; the paint inside is implied, not coloured).

| Weapon | Silhouette | Notes |
| --- | --- | --- |
| Splat Pistol | Compact toy-like pistol, small round canister on top | Snappy recoil |
| Streak Rifle | Long body, stock, top-mounted spherical tank | The "default" look |
| Spray Hose | Chunky body, drum tank underneath, long nozzle | Hose-like, sprays thin streams |
| Bucket Launcher | Shoulder tube ending in a paint bucket | Fires a spinning paint bucket that bursts |
| Paint Bomb | Round canister with a pull-tab | Bounces, wobbles, bursts |
| Big Brush | Oversized house-painting brush | Wide swipe animation; bristles leave a streak |

Each weapon needs a first-person view model (arms plus weapon) and a third-person model with a grip matching Roblox's right-hand tool grip. Weapon skins (`Config/Cosmetics.luau`, category `WeaponSkin`) recolour the body and trim only.

## Paint

- Splats: soft, glossy, slightly raised blobs with drip edges; tile seams hidden.
- Projectiles: glossy blobs with a short trail, coloured by the viewer's perspective (green if yours, red if hostile).
- Impact particles: droplets and a flat splat decal flash.
- Hazard feedback: a quick "sizzle" shimmer on the player's screen edges when touching enemy paint, never gore.
- Cosmetic splat styles (category `PaintEffect`) may change shape (stars, hearts, brush strokes) but never colour.

## Map: Canvas Yard (working title)

An outdoor "paint factory yard": clean concrete, pale stone and steel, with a sunny, playful feel. Keep the current layout (it is designed around movement; see `src/server/Maps/CanvasYard.luau`) and dress it:

- Team decks as loading docks with Gold/Violet trims.
- Lane walls as long billboard walls (blank canvases) inviting paint.
- Central tower as a water-tower-style paint silo.
- Grapple anchors as bright hanging paint cans with a clear hook point.
- Tunnel as a covered conveyor hall.

## UI

Chunky rounded panels, bold sans-serif, high contrast. HUD elements stay at screen edges to keep the centre clear. The hazard warning uses the danger colour; everything else stays neutral.

## Audio (not yet in the build)

Squelchy splats scaled by weapon, a satisfying "thwip" for the grapple, rhythmic footfalls for wall-running, a warning sizzle loop while touching enemy paint, and bright, upbeat match music.

# Lomas Pompón: the east biome for kids, weather-first (La Nube Tormenta)

**Status: concept only. Nothing here is approved, built, placed in Studio or played.** One of several candidate concepts for the bright east biome asked for on 2026-11-09 (one open world: La Silueta's forest to the west, a permanent safe social hub in the centre, a cute biome for kids to the east, joined side by side). Every number is a hypothesis in the same sense as `docs/mechanics/wildbound-economy-p0.md`: a starting value for the tuning panel and the simulator, not a balanced result. Design and code stay in English; in-game names and player strings are neutral Spanish.

**Angle of this concept:** the weather is the beast. La Nube Tormenta is a grumpy cartoon cloud whose shadow is the only dark thing in a pastel world, and whose lightning is telegraphed by a bright spot inside that shadow. Everything a child needs to read is shape, colour and position, never gore, never darkness.

**Originality:** every name and creature below is invented for Wildbound. No character, species, place or item name is taken from any existing game.

## Quick path

| You are | Read | Then |
| --- | --- | --- |
| The user | Sections 1, 5 and 6, then section 10 | Pick this concept or a sibling; answer the questions in section 10 |
| Atmosphere writer | Section 2 | Add the rows and the `Dawn` light key to `WildboundAtmosphere` test-first |
| Layout planner | Sections 3 and 8 | `tools/plan_lomas_layout.py` after the forest planner's pattern |
| Gameplay designer | Sections 5, 6 and 7 | Nothing here authorizes code; section 5 lists the rule changes it needs |

## 1. Identity

| Item | Proposal |
| --- | --- |
| Name | **Lomas Pompón** ("pompom hills"): round pastel hills dotted with giant mushrooms whose caps look like pompoms from the hub |
| Promise to a 7-year-old | A sunny meadow where creatures bounce, nothing is dark, and the only trouble is a grumpy cloud you can always walk away from |
| Promise to the game | The free, bright counterpart of the forest: same rules (one hunter per player, fair strike, hide, safe zones, rarity by distance), half the tension, twice the colour. Players who tire of the fog have a place to earn and show off without leaving the world |
| Contrast with the forest | The forest hides distance with mist; the Lomas show everything to the horizon and hide only the strike timing. The forest is grey-green and cold; the Lomas are mint, lavender and coral, warm at every hour. La Silueta is tall and silent; La Nube is wide, low and loud (grumbles, sneezes, a tuba-like sigh) |
| Size | A 400 x 400 stud sector east of the hub, the same footprint as the P0 forest, so one planner and one kit scale serve both |
| Mood by zone | **Prado** (the open hills, most of the sector): calm, creatures everywhere, no threat. **Tormenta** (the eastern third around La Nube's home pond): her shadow drifts here, the rarer creatures live here. **Sol** (sun circles): no strikes, stamina regen x2, the gate and the plaza are permanent ones |

## 2. Palette ramps and atmosphere rows

### Terrain and prop palette (material names, hex)

| Name | Hex | Used on |
| --- | --- | --- |
| `LP_Grass` | `A8E6B0` | Hill tops, the base ground colour |
| `LP_Lavender` | `D9C8F0` | Hill shoulders and slopes, so every hill reads as a shape |
| `LP_Path` | `F5E6C8` | The cream path from the gate to the plaza and the pond |
| `LP_Stem` | `FFF4E0` | Mushroom stems, fence posts |
| `LP_Cap_Coral` | `F28B9B` | Mushroom caps, group A |
| `LP_Cap_Sky` | `8FD3F4` | Mushroom caps, group B |
| `LP_Cap_Butter` | `F9E27A` | Mushroom caps, group C; also the sunflower petals |
| `LP_Spot` | `FFFFFF` | Cap spots, cloud puffs |
| `LP_Pond` | `B9B3CF` | The grey-lilac pond that is La Nube's home: the only desaturated ground colour, on purpose |
| `LP_Wood` | `C98F5A` | Gate, fences, signs |
| `LP_Neon_Sun` | `FFD23F` | Sun-circle rings and the strike ring. The only emissive material, so "glowing yellow" has one meaning |
| `LP_Cloud_Grey` | `B4A8D2` | La Nube's body. Lilac-grey, never charcoal |
| `LP_Cloud_Belly` | `8C7FB0` | La Nube's underside, her darkest colour |

Rule kept from the expansion bible: one mesh object, one material, `Neon` only in the material name of the emissive part. Neon hex values are starting points; `F08C2E` once rendered yellow, so check the sun ring in a capture before pinning it.

### Atmosphere rows, in the `WildboundAtmosphere` style

`ROWS[zone][time] = { density, offset, haze, fogStart, fogEnd }`. The forest's dread rows sit at density 0.68 to 0.88 and fogEnd 48 to 140; these stay under 0.40 and above 300, so the hills are visible from the gate at every hour. Night here is cozy blue, not black: the floors below are stricter than the forest's.

```lua
-- Proposal for WildboundAtmosphere.ROWS (new zones). Blended by the same KEYS and the same lerp.
lomas    = { Day = { 0.22, 0.10, 1.2, 160, 520 }, Dusk = { 0.28, 0.08, 1.6, 120, 420 },
             Night = { 0.34, 0.05, 2.0, 90, 320 }, Dawn = { 0.26, 0.08, 1.4, 130, 460 } },
tormenta = { Day = { 0.30, 0.08, 1.8, 120, 420 }, Dusk = { 0.36, 0.06, 2.2, 90, 340 },
             Night = { 0.40, 0.04, 2.6, 70, 280 }, Dawn = { 0.34, 0.06, 2.0, 100, 380 } },
sol      = { Day = { 0.16, 0.12, 0.8, 200, 600 }, Dusk = { 0.20, 0.10, 1.0, 160, 520 },
             Night = { 0.24, 0.08, 1.2, 130, 440 }, Dawn = { 0.18, 0.10, 0.9, 180, 560 } },
```

`LIGHT[time]` for the Lomas (the module today keys `Dusk` for both twilights; this biome needs a real `Dawn` key, warmer than `Dusk`):

```lua
-- Proposal for a LIGHT table scoped to the Lomas. ambientWeight 1 everywhere: the biome owns its light.
Day   = { atmosphere = { 214, 236, 255 }, fog = { 236, 244, 255 }, ambient = { 150, 160, 175 }, outdoor = { 170, 182, 196 },
          ambientWeight = 1, brightness = 1.0,  exposure = 0.10,  flashlight = { 0, 55, 60 } },
Dusk  = { atmosphere = { 255, 196, 170 }, fog = { 255, 214, 190 }, ambient = { 140, 120, 140 }, outdoor = { 160, 136, 160 },
          ambientWeight = 1, brightness = 0.85, exposure = 0.0,   flashlight = { 0, 55, 60 } },
Night = { atmosphere = { 96, 118, 180 },  fog = { 120, 140, 200 }, ambient = { 92, 106, 152 },  outdoor = { 104, 120, 170 },
          ambientWeight = 1, brightness = 0.75, exposure = -0.10, flashlight = { 1.0, 40, 70 } },
Dawn  = { atmosphere = { 255, 220, 200 }, fog = { 255, 232, 216 }, ambient = { 150, 140, 150 }, outdoor = { 170, 160, 170 },
          ambientWeight = 1, brightness = 0.9,  exposure = 0.05,  flashlight = { 0, 55, 60 } },
```

| Floor (Lomas only) | Value | Why |
| --- | --- | --- |
| `density` at most | 0.45 | The forest allows 0.9; here mist is weather dressing, never a blindfold |
| `fogEnd` at least | 250 | A child on a phone sees the next mushroom and the gate at every hour |
| `ambient` channel minimum at Night | 90 | Cozy blue has a readable floor; `WildboundAtmosphere.FLOORS` would gain a `nightAmbientMin` |
| `brightness` at least | 0.7 | Night never dips to the forest's 0.4 |
| La Nube's shadow darkens the ground under her | x0.80 of the current colour, radius 20 | Enough to read "her shadow", never below the floor above (client-only decal tint) |

**Storm weather is local, not global.** La Nube carries her own drizzle (a small particle emitter under her, client side) and her own shadow disc. The sky over the Lomas never goes grey as a whole; a storm in this biome is always "that cloud over there", which is what makes it readable.

**Crossing between biomes.** `Atmosphere.at(clockTime, zone, reduced)` already blends by zone; the hub gets its own `hub` row (between `camp` and `sol`) and the east gate blends `hub` to `lomas` over the 30 studs of the gate path. The same client code serves both biomes; only the zone resolver learns the new sectors.

## 3. Terrain and prop vocabulary

**Terrain.** Rolling hills 6 to 14 studs high, slopes under 25 degrees so walking never slows, with cream paths in the valleys. The hub plaza, the east gate path and the pond rim are flat. No water you can fall into; the pond is a shallow decal-topped disc. No walls: the sector edge is a row of very large mushrooms and a low fence, as the forest edge is trees.

**Kit `LP_` (eight props).** Sizes are X x Y x Z in studs, triangle targets follow the kit range (120 to 640). Tags follow `docs/design/wildbound-expansion-bible.md` section 5.2.

| Asset | Size | Tris | Parts | Form | Tags |
| --- | --- | --- | --- | --- | --- |
| `LP_GiantMushroom` | 18 x 18 x 22 | 420 | Stem: LP_Stem (160); Cap: LP_Cap_* (200); Spots: LP_Spot (60) | Fat stem, dome cap wider than the stem by 3x, five raised spots. The cap is the biome's **roof**: standing under it hides you from La Nube | `occluder` (the stem only, so sight lines stay honest); `roof` (cap underside box, new tag: a sky ray from a player head hitting it reads as covered) |
| `LP_PompomTree` | 10 x 10 x 16 | 300 | Trunk: LP_Wood (100); Pompoms: LP_Cap_* (200) | Thin trunk with three round pompom clusters, the "tree" of this biome | `roof` on the top pompom |
| `LP_MushroomRing` | 7 x 7 x 1.2 | 150 | Caps: LP_Cap_* (120); Stems: LP_Stem (30) | Ring of nine small mushrooms, a creature nest marker | `tiny` 1.5 |
| `LP_PuffFlower` | 4 x 4 x 2.5 | 90 | Stems: LP_Grass (40); Puffs: LP_Spot (50) | Five dandelion-like puffs, gives the common material Pelusa | `gather` at (0, -2, 1.5); `tiny` 3 |
| `LP_SunflowerPost` | 3 x 3 x 8 | 160 | Post: LP_Wood (60); Flower: LP_Cap_Butter (70); Ring: LP_Neon_Sun (30) | Tall sunflower on a post with a glowing ring at the base. Four of them mark every sun circle | None; the sun ring is drawn at runtime by the Refugio system |
| `LP_HillBoulder` | 6 x 5 x 4 | 120 | Rock: LP_Lavender (120) | Smooth pastel boulder, a landmark and a creature perch | None (no `occluder`: La Nube sees from above anyway) |
| `LP_RainbowGate` | 30 x 10 x 18 | 560 | Posts: LP_Wood (300); Arch: LP_Cap_Coral, LP_Cap_Sky, LP_Cap_Butter as three thin bands (260) | The east gate arch: two posts with a three-band arch. A child sees "rainbow door" from the hub | clear 16 x 11; limit 32 x 16 |
| `LP_Pinwheel` | 2 x 2 x 4 | 110 | Stick: LP_Wood (30); Wheel: LP_Cap_* (80) | Pinwheel on a stick. Decoration along paths, and the shape of the distraction item (section 5) | `tiny` 4 |

**Plan mix (hypothesis, under the forest's 207 instances):** 48 giant mushrooms (16 per cap colour), 30 pompom trees, 12 mushroom rings, 40 puff flowers, 24 sunflower posts (6 sun circles x 4), 20 boulders, 1 rainbow gate, 16 pinwheels: 191 instances. Giant mushrooms grow in size and density toward the pond so the "roof" count rises exactly where La Nube hunts; the planner enforces at least one roof within 25 studs of any point in the Tormenta zone, as the forest planner enforces hide spots near nests.

**Materials of the biome (two, like the forest's three):**

| Material | Where | Carried as | Intended use |
| --- | --- | --- | --- |
| Pelusa (fluff) | Puff flowers, Prado and Tormenta | Pouch | Pinwheel recipe, Lomas skill nodes |
| Espora Brillante (bright spore) | Giant mushrooms in the Tormenta zone only, any hour (this biome has no night-only resource; see X6 in the bible) | Bag item | Rarer recipes and the corral upgrades |

## 4. Five creatures

All five share the Lumipol scale (`WildboundSpecies.LOOKS.Lumipol.size` is 3 x 2 x 2.4 studs; a cría is 0.55 of that) and the primitive stand-in rule (body, accent, two eyes, glow) until rigs are approved. Round bodies, eyes at least a quarter of the head, no teeth. Rarity follows the W2 distance bands from La Nube's home pond: Común beyond 120 studs, Rara 80 to 120, Épica 45 to 80, Legendaria under 45 and only from the event egg.

| Name | Rarity | Look (body, accent, eye, glow hex) | Behaviour (one sentence) | Corral earning, Esencia per minute |
| --- | --- | --- | --- | --- |
| **Chispín** | Común | Butter-yellow ball with a single lightning-shaped tuft (`F9E27A`, `F2B84B`, `3A2E22`, `FFF1A8`) | Hops in short arcs and squeaks twice when La Nube's shadow comes within 40 studs, so a wild one is a free early warning for everyone near it. | 0.3 |
| **Musgón** | Común | Mint moss dome on four stubby feet (`A8E6B0`, `6FBF8A`, `2B3A30`, `C9F5D0`) | Dozes under mushroom caps and waddles to the nearest roof when it rains, teaching by example where cover is. | 0.3 |
| **Rocinela** | Rara | White cloud-fleece puff that floats a hand above the grass (`FFFFFF`, `D9C8F0`, `4A3F6B`, `F2ECFF`) | Drifts slowly downwind of La Nube and settles in sun circles, so following one often leads a child to safety. | 0.6 |
| **Hongolín** | Épica | Walking coral mushroom cap with glowing spots and tiny legs (`F28B9B`, `FFF4E0`, `3A2E22`, `FFD7DE`) | Stays near the pond rim and, when startled, spreads its cap so a nearby player under it counts as roofed for 3 s. | 1.2 |
| **Relampino** | Legendaria | Small lilac storm-puff with a sunny round face and harmless sparks (`B4A8D2`, `FFD23F`, `2B2440`, `FFF1A8`) | Hatches only from the Huevo de Tormenta, circles its owner crackling, and as a companion makes La Nube sneeze once per chase (section 5). | 2.5 |

**Corral income and the no-AFK contract.** `wildbound-economy-p0.md` AFK-1 says no quantity grows from time alone. Corral income as the user describes it does grow with time, so this concept proposes the narrowest honest version and flags it as a decision for the parent, not a settled rule:

| Rule | Proposal |
| --- | --- |
| Accrual | Per creature placed in the corral, at the rate above, only while the owner is in the server |
| Cap | Each creature holds at most 20 minutes of accrual (6 Esencia for a Chispín, 50 for a Relampino); then it stops, so an idle hour pays the same as 20 minutes |
| Collection | A prompt at the corral, "Recoger Esencia", pays the held amount; nothing is credited without that server-observed action |
| Slots | 4 free corral slots at the start; more slots are a hub upgrade (section 9) |
| Scale | A full starter corral of four Común earns 1.2 per minute, about a fifth of the simulated active income (about 6 to 7 Esencia per minute from `tools/simulate_economy.py`), so the corral is pocket money, never a reason to stop playing |

Capture uses the same calm-ring rule as Lumipol (hold still 4.5 s inside the ring, moving breaks it), with cuter feedback: the ring is a daisy chain, success plays a giggle. No new capture mechanic is needed for the first five.

## 5. The beast: La Nube Tormenta

### Look

A wide, low cumulus about 14 studs across and 8 tall, floating with her belly 10 studs above the ground. Lilac-grey body (`LP_Cloud_Grey`), a darker belly (`LP_Cloud_Belly`), two round eyes that are closed lines when calm and wide circles when hunting, thick frowning eyebrows, and cheeks that puff up before a bolt. Under her: a soft shadow disc (radius 20, tint x0.80) and a few falling drops. No mouth with teeth, no red, no black. She is the only grey thing in the biome and the only thing that casts a visible shadow, so a child finds her in one glance.

### Senses

She is weather: she sees anyone standing **under open sky** within her detection range. The server casts one ray straight up from the player's head (against `CanQuery` parts tagged `roof`, built as invisible boxes from the kit report); a hit means covered. Range 40 studs by day, 48 at Night (the biome's only night change; her speed does not rise). She does not hear footsteps or care about flashlights. A crackling event egg in the bag adds 10 studs to her range on that player.

### Per-player hunter

As planned for La Silueta (plan F2): one Nube per player, bound to its owner, capped by `MAX_HUNTERS`. Others see your Nube faint. Her home is the pond at the eastern end; her leash is 90 studs from the pond, and she strikes only targets inside the Tormenta zone, so the Prado and the gate path can never see a bolt. Same shape as `Rules.inTerritory` and `Rules.validTarget`, with a second home and a second zone.

### Hunt rule, state by state

| State | Chip (Spanish) | Rule | Tell |
| --- | --- | --- | --- |
| Calma | none | Drifts between 6 pond waypoints at 6 studs/s, eyes closed | Her shadow slides over the grass; drops fall |
| Gruñido (notice) | "La Nube te vio" | 1.5 s after a valid sighting; no movement toward you yet | Eyes open, eyebrows drop, cheeks puff, a low grumble; the shadow deepens one step |
| Persecución (chase) | "¡La Nube te sigue!" | Follows at **14 studs/s**, under walk speed 16; memory 2 s after losing sight; gives up past 60 studs or after 12 s, then Desinflada | She leans forward; drizzle thickens; a tuba-like hum rises. Wild Chispín within 40 studs squeak |
| Relámpago (strike telegraph) | "¡Rayo! Sal del círculo" | From within 12 studs: a **sun ring of radius 6 appears on the ground where you stand at that instant**, and it does not move. **Telegraph 1.0 s** (tunable 0.8 to 1.5; the 0.8 s fair-strike floor is a contract). The bolt lands in the ring at the end | The ring is the bright spot inside her shadow: "where the light is, the lightning falls". It pulses twice, a rising zip sound plays, the chip is large with a bolt icon |
| Chispazo (hit) | "¡Chispazo!" | Only if you are inside the ring at impact and every fair-strike gate passed (A to E, the attack id, the acknowledgement). Consequence follows D6 exactly: first hit drops one unwarded bag item next to you (owner-only, 30 s) and marks you; a second hit while marked ends the trip | Hair stands up, soot puffs, a sneeze. No blood, no scream |
| Empapado (defeat) | "¡Te empapaste!" | The loss rule of the economy applies unchanged (20 percent of carried stacks, unwarded bag items). You reappear dry at the east gate's sun circle with the defeat summary and a towel icon | Rain on the screen for 2 s, then sun |
| Desinflada (give up) | "La Nube se aburrió" | After a strike, a lost quarry or 12 s of chase: she sighs, shrinks to 0.8 scale for 3 s and drifts home for 10 s, unable to acquire | Visible relief for the child: the frown turns to a pout |
| Estornudo (stagger) | "¡Achís!" | A Relampino companion's spark (its pulse, 30 s cooldown) within 15 studs: she sneezes, 1.2 s unable to move or strike, once per chase | A big sneeze; her drops scatter |

**Why it stays fair.** Chase speed 14 is below walk speed 16 and far below the 24 sprint, so walking away always works and the pressure is only that she flies over props and cuts corners. The strike ring is fixed where you stood; leaving a 6-stud radius at walking speed takes 0.4 s against a 1.0 s telegraph, and even a child who hesitates half a second still escapes. Bolt cooldown 3 s. Every strike passes the same gates as La Silueta (persistent model, dwell, target-only warning with attack id and acknowledgement, staged consequence, preload); each failed gate cancels and counts. She never enters a sun circle, never strikes under a roof, never follows into the hub, never strikes within 9 studs of a spawn pad.

**How a 7-year-old reads the threat without horror.** Four cues, each enough alone: (1) the only grey thing in a pastel world is coming; (2) the only dark patch on the ground is her shadow, and you are in it; (3) a yellow ring under your feet means step out, and the ring never chases; (4) a big icon chip in big words. Sound is comic (grumble, tuba hum, sneeze, zip), never a scream, and the game works muted. A sign at the gate shows three pictograms: cloud with frown, arrow to mushroom; yellow ring, arrow out; sunflower ring, a smile. The consequence is soot and getting soaked, and the hero gets up at the gate with a towel.

### Escapes and defeats, all free

| Way | Rule |
| --- | --- |
| **Roof** (hide) | Stand under any giant mushroom cap or pompom tree: the sky ray is blocked, she loses you after the 2 s memory, circles sadly for 4 s, then Desinflada. Unlike the forest hide spots there is no prompt and no dwell: cover is just standing under something, which a child learns from Musgón |
| **Sun circle** (safe zone) | Rings of four sunflower posts with a glowing `LP_Neon_Sun` ring, radius 12: no strikes, no acquisition, stamina regen x2. Two permanent (the east gate, the Plaza del Molino halfway to the pond) plus 2 to 3 random ones rerolled on the 5-minute wave clock from a candidate set that never includes the pond rim, exactly the W4 Refugio rule with sunflowers instead of totem poles |
| **Pinwheel** (distraction) | Craftable item (8 Pelusa, 1 Espora Brillante, 6 Esencia; hold 2). Place it: La Nube cannot resist blowing a pinwheel and hovers over it for 8 s, during which she acquires nobody. Noise and movement by the placer are still visible to other hunters' owners; nothing is global |
| **Walk away** | 16 beats 14, always. Sprint ends it in two seconds |
| **Companion sneeze** | A Relampino companion spends its pulse to make her sneeze once per chase (1.2 s stagger). A Chispín companion only squeaks earlier (warning at 50 studs instead of 40). Lumipol's pulse does nothing here, as Lumipol stays the forest's revealer |

### Profile shape

Follows `WildboundWorldRules.CREATURE_PROFILES`; the night scope and the second home are rule changes, not data:

```lua
NubeTormenta = table.freeze({
	name = "NubeTormenta", specialBehaviorId = "Nube", visualScaleKey = "NUBE_VISUAL_SCALE",
	base = table.freeze({ speed = 14, detectionRange = 40 }),
	night = table.freeze({ scope = "Tormenta", speed = 14, detectionRange = 48 }),
}),
```

Rule changes needed (each with contracts first): a second home and zone (`HOME` becomes per guardian), a `roof` sky-ray sense next to the sight ray, a fixed-ring strike resolution (impact checks "inside the ring", not "within 7 studs of the guardian"), the `Estornudo` stagger, and `MAX_HUNTERS` across both biomes. Tunables for the dev panel: `NUBE_TELEGRAPH_SECONDS` 1.0 (floor 0.8), `NUBE_RING_RADIUS` 6, `NUBE_CHASE_SPEED` 14 (ceiling 15.5, under walk 16), `NUBE_MEMORY_SECONDS` 2, `NUBE_MAX_CHASE_SECONDS` 12, `NUBE_GIVE_UP_DISTANCE` 60, `NUBE_LEASH` 90, `NUBE_DETECTION` 40/48, `NUBE_VISUAL_SCALE` 1.0.

## 6. Special biome egg event: Huevo de Tormenta

| Item | Proposal |
| --- | --- |
| Clock | Every 20 minutes, first at minute 5 (same cadence as the forest event, offset by 10 minutes so the two never overlap) |
| Announcement | Server banner "¡Huevo de Tormenta en Lomas Pompón!" to every player, plus a distant thunderclap. A **rainbow** rises from the east gate and arcs to the nest, visible from the hub: the navigation is a picture, not a compass number |
| Where | On the cap of the **Seta Trueno**, the tallest giant mushroom (26 studs), standing in the pond's shallows 15 studs from La Nube's home: a Legendaria point by the W2 bands. A spiral of small caps up the stem is the way up; the climb is in open sky |
| Window | 5 minutes, then the egg vanishes with a soft pop and the rainbow fades |
| Claimant | One per server per event; the first "Tomar el huevo" hold (3 s) takes it |
| While active | La Nube is **Enfurruñada**: chase 15 (still under 16), telegraph 0.9 (still above 0.8), detection 44/52, and she patrols around the Seta Trueno instead of the pond loop. The egg crackles in the bag: +10 detection on its carrier until it is banked |
| The egg | Lilac with a yellow zigzag band, `LP_Cloud_Grey` and `LP_Neon_Sun`. Walking with it uses the egg speeds of `wildbound-capture.md` |
| Payoff | Banked at the hub incubator, hatch time 300 s (the common 90 s times about three), hatches **Relampino**, the biome's Legendaria and its only source. Esencia at extraction: the Heart egg row (14) |
| Fairness | A child who sees the rainbow but is not first still gains: while the event runs, Épica spawns in the Tormenta zone double, so the trip pays even without the egg |

## 7. Loop in this biome

Enter through the Portón del Arcoíris; the first 25 studs are a sun circle. Catch Chispín and Musgón in the Prado at no risk and learn the ring (first catch in about 15 s from the gate, keeping the K1 to K4 hook). Follow the cream path to the Plaza del Molino (permanent sun circle, a crafting bench for pinwheels, a bulletin for the event clock). Go on toward the pond for Rocinela and Hongolín under La Nube's shadow, learning roofs, rings and the walk-away. Return to the hub to bank, incubate, put creatures in the corral and spend. Every 20 minutes a rainbow invites you to the Seta Trueno.

Expected expedition length is the economy floor's concern: the biome is 400 studs across like the forest, holds the same gather holds (3 s Prado, 4 s Tormenta edge, 6 s pond rim) and the same walk penalties, so it is a candidate for `tools/simulate_economy.py` with a second zone table, not a new simulator.

## 8. How the biome joins the hub

The user's direction: one open world, the hub in the centre, the forest to the west, the Lomas to the east, side by side.

| Element | Proposal |
| --- | --- |
| Frame | One world frame with the hub centre at (0, 0). The forest sector is centred at (-300, 0), the Lomas sector at (+300, 0), each 400 x 400. The hub is a 200-stud disc between them. Everything in the existing forest moves as one `PivotTo` of its root (the P0 map and the forest dressing already move as a unit); its local coordinates, zones and tests keep working with one offset |
| East gate | `LP_RainbowGate` at (+100, 0), on the hub's east rim, over a 14-stud cream path. A permanent sun circle (radius 25) is centred on the gate, so the hub's safe zone and the biome's first sun circle overlap and there is never a strip where neither rule applies |
| West gate | The forest's mirror: a `FK_RootArch` at (-100, 0) and the camp's safe circle. Symmetry is deliberate: a child sees "dark door left, rainbow door right" from the plaza |
| Join without a seam | Terrain blends over the 30-stud gate path: the hub's warm sand becomes `LP_Path` cream; mushrooms start small at the gate and grow toward the pond; the atmosphere blends `hub` to `lomas` over the same 30 studs; the audio bed crossfades from the hub's murmur to birdsong and wind chimes |
| Rules at the join | Zone resolver: `hub` (safe, no hunters, no strikes), then `sol` at the gate, then `prado`, then `tormenta`. La Nube's leash (90 from the pond at about +460) cannot reach the gate (+100), so no rule has to be checked twice |
| What the hub shows of the biome | The corral and the trophy display face east, so creatures from the Lomas are shown toward their biome; the event rainbow is visible from the plaza |
| Offline pattern | `tools/plan_lomas_layout.py` (same shape as `plan_forest_layout.py`: route nodes, zones, prop envelopes, seed, JSON + SVG + PNG under `assets/maps/lomas-layout/`), `tools/build-lomas-kit.py` + `tools/test_lomas_kit.py` through `biome_kit_spec.py`, an export to Luau like `export_forest_layout_luau.py`. Tests: every Tormenta point has a roof within 25 studs, no sun-circle candidate inside the pond rim, the gate clear 16 x 11, at least one roof and one sun circle on the direct path from the gate to the pond |

## 9. Hooks for the economy and the hub (design only)

The economy and monetization design lives elsewhere; this list only names where the Lomas attach, so the shop design can reference them. No price, no Robux value, no purchase flow is proposed here, and nothing below may be implemented before the Creator Hub, `ProcessReceipt` and persistence decisions the user still has to make.

| Hook | Free path | Convenience candidate (for the monetization doc to weigh) |
| --- | --- | --- |
| Corral slots | 4 free; slots 5 to 8 bought with Esencia at rising cost | Extra slots |
| Pinwheel | Crafted from Lomas materials | A pinwheel pack |
| Hatch time of the storm egg | 300 s, free | A speed-up was ruled out once in `wildbound-incubator.md` ("paying to speed a hatch, never"); the user's new direction reopens it, so the parent must decide, not this document |
| Lomas skill nodes | Esencia + Pelusa: "Pies de nube" (walk 17 in the Lomas only, La Nube stays 14), "Ojo de sol" (strike ring telegraph shown 0.2 s earlier, capped by the 0.8 floor on her side, not yours), "Bolsillo de espora" (bag +1 in the Lomas) | None: skills stay earned |
| Cosmetics | Cap-colour ribbons for corral creatures by playing | Cosmetic ribbons |

Everything here must obey the kids-audience and monetization policies the parent listed: clear prices, no paid randomness, convenience over power, and a free path that always exists.

## 10. Open questions for the user

| # | Question | Default if unanswered |
| --- | --- | --- |
| S1 | Corral accrual breaks AFK-1 as written. Accept the capped, collect-in-person version in section 4, or keep income only from trips? | Capped version, 20-minute cap |
| S2 | Does a hit in the Lomas use the forest's exact loss rule (20 percent of stacks, unwarded items), or a softer kids rule (one item, no stacks)? | Same rule, one sentence everywhere |
| S3 | Can a Relampino companion enter the forest and make La Silueta sneeze? | No: each companion ability belongs to its biome |
| S4 | Should other players see your Nube faint (as planned for La Silueta) or not at all? | Faint |
| S5 | Is "Lomas Pompón" the name, or "Pradera Pompón"? | Lomas Pompón |

## 11. What is not verified

Nothing in this document has been measured: no instance or triangle budget on a device, no telegraph timing with a child, no readability of the strike ring on a phone in sunlight, no corral rate against the simulator, no phone taps (never possible so far in this project). The claim that a fixed 6-stud ring plus a 1.0 s telegraph is always escapable is arithmetic at walk speed 16 on flat ground; slopes, lag and a thumb on a phone are the tests that would falsify it. The free toolbox search for stand-in models (mushrooms, a cloud) was not run for this concept; when it is, only ids returned by `search_asset` may be used, shown to the user before any insertion.

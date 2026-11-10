# Pradera Arcoíris: the east biome for kids, with La Nube Gruñona

**Status: design synthesis plus an offline kit. Nothing here is approved as a game rule, placed in Studio, played or measured on a device.** Written 2026-11-09 from the user's direction of that day (one open world: La Silueta's forest to the west, a permanent safe social hub in the centre, a bright biome for kids to the east, joined side by side, creatures that earn Esencia in a corral, a free path that always exists and Robux offers that shorten it) and from the three concept documents in `docs/design/kids-biome-concepts/` (`bee.md`, `mimo.md`, `storm.md`) after two independent judgments. Every number is a hypothesis for the tuning panel and the simulator. Design and code are English; in-game names and player strings are neutral Spanish. No monetization is implemented or authorized by this document.

**User decision, 2026-11-10:** the east biome is Pradera Arcoíris and its permanent beast is La Nube Gruñona, as below. **La Abeja Reina** (from `kids-biome-concepts/bee.md`) is the beast of the 20-minute biome event only: she wakes when the event egg appears, guards it at La Colmena for its 5-minute window, then sleeps again (section 6). Her ground never touches la Nube's, so one player is never hunted by two beasts at once. The open-world plan now reads this document's kit (`docs/design/wildbound-open-world-hub.md`).

**Originality:** every name below (biome, beast, creatures, places, items, chips) was invented for Wildbound and checked against the three concepts for collisions. The word Pompón, which named a creature in two concepts and the biome in the third, is not used anywhere.

## Quick path

| You are | Read | Then |
| --- | --- | --- |
| The user | Sections 1, 5, 9 and 10, then section 14 | Answer the questions in section 14, one at a time |
| Map builder | Sections 3, 8 and 11 | Regenerate with the two tools; the Luau module is ready to paste when the parent authorizes a Studio edit |
| Gameplay designer | Sections 4, 5, 6 and 13 | Nothing here authorizes code; section 13 lists the rule changes it needs |
| Economy writer | Sections 9 and 10 | Extend `tools/simulate_economy.py` before any corral or price number becomes a rule |

## 0. How this synthesis was decided

Two judges scored the three concepts and disagreed on the winner.

| Concept | Judge A | Judge B | Mean |
| --- | ---: | ---: | ---: |
| `storm.md` (weather beast, fixed lightning ring) | 7.0 | 8.5 | 7.75 |
| `bee.md` (sound hunter, night sleeper) | 7.5 | 7.5 | 7.5 |
| `mimo.md` (plush that copies a creature) | 8.5 | 6.0 | 7.25 |

The base is **storm's world and beast**, for the reasons both judges agreed on even when they ranked it differently: it is the cheapest beast to build and run (no pathfinding, a trivial rig, one sky ray per player), the kindest to phones (one emissive material, no light field), the most legible to a seven-year-old without reading or sound (a fixed yellow ring where you stood, a roof you simply stand under), and the only concept that arrived with a plan mix, a test list and a rule-change inventory ready for the offline pattern. Judge A's case for the mimic was that its beast lives inside the capture loop; that is kept as the event twist (section 6), not as the biome's beast, because both judges flagged the disguise as the weakest readability premise for a child on a phone and the heaviest art cost.

Grafts, in the order both judgments asked for them:

| # | From | Graft | Where |
| --- | --- | --- | --- |
| 1 | bee | Kids consequence: no defeat screen, no stack loss, damage off even in private damage mode; a hit parks one item, a second hit is a short flight back to the gate | 5.5 |
| 2 | bee | Cansarla: a non-violent win that sends her home | 5.6 |
| 3 | bee | Night is the safe time east: she naps over the pond with halved senses | 5.3 |
| 4 | bee | Fed, capped, collect-in-person corral windows, the only version that respects AFK-1's spirit | 9 |
| 5 | bee | One ability with a downside per creature, and the explicit rule that rare is not power | 4 |
| 6 | bee | Corral slots as the free rising-Esencia ladder, extra slots as a convenience candidate for the user to decide | 9, 10, 14 |
| 7 | mimo | The two-eggs-on-the-pedestal puzzle for the biome event, and "copies cast no shadow" as its tell | 6 |
| 8 | mimo | Blink and breathe idle on every real creature; the still one is never real | 4 |
| 9 | mimo | Pinwheels found in the world as well as crafted, so the distraction has a no-crafting free path | 5.6 |
| 10 | mimo | First safe spot and first catch both visible from the arch; icon-first signs | 3, 7, 8 |
| 11 | storm | Fixed ground ring, rainbow event beacon, wild-creature early warning, pictogram gate sign, "dark door left, rainbow door right" | 5, 6, 7, 8 |

## 1. Identity

| Item | Decision |
| --- | --- |
| Name | **Pradera Arcoíris**. The rainbow is the gate from the hub, the beacon of the event and the three cap colours a child sees from the plaza |
| Prefix | `PA_` (assets, kit, Luau folders) |
| Beast | **La Nube Gruñona**, "la Nube" for short: a grumpy lilac-grey cartoon cloud whose shadow is the only dark thing in a pastel world |
| Promise to a 7-year-old | A sunny meadow where creatures bounce, nothing is dark, and the only trouble is a grumpy cloud you can always walk away from |
| Promise to the game | The free, bright counterpart of the forest with the same rules (one hunter per player, fair strike, hide, safe zones, rarity by distance, 5-minute waves, 20-minute event) and half the tension |
| Contrast with the forest | The forest hides distance with mist; the Pradera shows the far edge at every hour and hides only the strike timing. La Silueta is tall, silent and worst at Night; la Nube is wide, low, loud (grumbles, a tuba-like hum, a sneeze) and asleep at Night |
| Core verbs for a child | Walk, look up, step out of the circle, stand under a mushroom, collect, bring home |
| What never happens here | No darkness, no fog wall, no blood, no scream, no jump scare, no defeat screen, no stack loss, no damage even with the private damage mode on |
| Sector | 400 x 400 studs centred at world (+300, 0); the hub centre is the origin (safe circle of radius 60); the forest sector is its mirror at (-300, 0) |
| Mood by zone | **Prado** (open hills, most of the sector): no threat. **Tormenta** (within 110 studs of her pond): her shadow drifts here, the rarer creatures live here. **Sol** (sun circles): no strikes, no acquisition, stamina regen x2; the gate and the Plaza del Molino are permanent ones |

## 2. Palette and atmosphere

### Material palette (one colour per part; also the `palette` table of the Luau builder)

| Name | Hex | Used on |
| --- | --- | --- |
| `PA_Grass` | `A8E6B0` | Floor, hill tops |
| `PA_Lavender` | `D9C8F0` | Hill shoulders, boulders |
| `PA_Path` | `F5E6C8` | The cream path gate to pond, nest straw |
| `PA_Stem` | `FFF4E0` | Mushroom stems, ring stems |
| `PA_Cap_Coral` | `F28B9B` | Caps and puffs, group A; the Seta Trueno |
| `PA_Cap_Sky` | `8FD3F4` | Caps and puffs, group B |
| `PA_Cap_Butter` | `F9E27A` | Caps and puffs, group C; sunflower petals |
| `PA_Spot` | `FFFFFF` | Cap spots, puff flowers, pinwheel hubs |
| `PA_Pond` | `B9B3CF` | The grey-lilac pond: the only desaturated ground colour, on purpose |
| `PA_Wood` | `C98F5A` | Gate posts, sign posts, nest beds, trunks |
| `PA_Neon_Sun` | `FFD23F` | Sun-circle rings, the strike ring, the event pedestal. The only emissive material, so "glowing yellow" has one meaning |
| `PA_Cloud_Grey` | `B4A8D2` | La Nube's body |
| `PA_Cloud_Belly` | `8C7FB0` | Her underside, her darkest colour |

Rule kept from the expansion bible: one part, one material; Neon only in the one glowing role. `F08C2E` once rendered yellow in the forest, so the sun hex is a starting point to check in a capture.

### Atmosphere rows, in the `WildboundAtmosphere` style

`ROWS[zone][time] = { density, offset, haze, fogStart, fogEnd }`. The forest's dread rows sit at density 0.68 to 0.88 and fogEnd 48 to 140; these stay under 0.40 and above 280, so the hills are visible from the gate at every hour.

```lua
-- Proposal for new zones; blended by the same KEYS and lerp. Needs a real Dawn key (today Dawn blends to Day).
prado    = { Day = { 0.22, 0.10, 1.2, 160, 520 }, Dusk = { 0.28, 0.08, 1.6, 120, 420 },
             Night = { 0.34, 0.05, 2.0, 90, 320 }, Dawn = { 0.26, 0.08, 1.4, 130, 460 } },
tormenta = { Day = { 0.30, 0.08, 1.8, 120, 420 }, Dusk = { 0.36, 0.06, 2.2, 90, 340 },
             Night = { 0.40, 0.04, 2.6, 70, 280 }, Dawn = { 0.34, 0.06, 2.0, 100, 380 } },
sol      = { Day = { 0.16, 0.12, 0.8, 200, 600 }, Dusk = { 0.20, 0.10, 1.0, 160, 520 },
             Night = { 0.24, 0.08, 1.2, 130, 440 }, Dawn = { 0.18, 0.10, 0.9, 180, 560 } },
```

| Time | atmosphere | fog | ambient | outdoor | brightness | exposure | flashlight |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Day | 214, 236, 255 | 236, 244, 255 | 150, 160, 175 | 170, 182, 196 | 1.0 | 0.10 | 0, 55, 60 (off) |
| Dusk | 255, 196, 170 | 255, 214, 190 | 140, 120, 140 | 160, 136, 160 | 0.85 | 0.0 | 0, 55, 60 (off) |
| Night | 96, 118, 180 | 120, 140, 200 | 92, 106, 152 | 104, 120, 170 | 0.75 | -0.10 | 1.0, 40, 70 (soft) |
| Dawn | 255, 220, 200 | 255, 232, 216 | 150, 140, 150 | 170, 160, 170 | 0.9 | 0.05 | 0, 55, 60 (off) |

| Floor (Pradera only) | Value | Why |
| --- | --- | --- |
| `density` at most | 0.45 | Mist is weather dressing here, never a blindfold |
| `fogEnd` at least | 250 | A child on a phone sees the next mushroom and the gate at every hour |
| `ambient` channel minimum at Night | 90 | Cozy blue has a readable floor; a `nightAmbientMin` would join `WildboundAtmosphere.FLOORS` |
| `brightness` at least | 0.7 | Night never dips to the forest's 0.4 |
| Her shadow | x0.80 of the ground colour, radius 20, client-only | Enough to read "her shadow", never below the floor above |

Storm weather is local: she carries her own drizzle emitter and shadow disc. The sky over the Pradera never goes grey as a whole; a storm here is always "that cloud over there".

## 3. Terrain and the `PA_` kit

**Terrain.** Seven rolling hills (sphere caps 6 to 10 studs high, rim slope 24.3 to 24.6 degrees, so walking never slows), a flat cream path from the gate to the pond rim (14 studs wide, 315 studs long, about 20 s at walk speed), a shallow grey-lilac pond of radius 28 at the east end that is her home, and no walls: the sector edge is a line of mushrooms and puff trees. No water you can fall into.

**Kit.** Nine props, all primitives in the Luau builder (no MeshParts, no uploads). Sizes are at scale 1; "parts" is what the builder emits per instance.

| Asset | Size (x, y, z) | Parts | Form | Tags and role |
| --- | --- | ---: | --- | --- |
| `PA_GiantMushroom` | 18 x 18 x 18, cap 9 studs radius | 8 | Fat stem, squashed dome cap three times the stem's width, five raised spots. Caps grow toward the pond (scale 0.8 far from her, about 1.25 at the rim) | Stem collides and blocks sight (`occluder`); the cap carries an invisible `Roof` box (`CanQuery` on, tag `WildboundRoof`): standing under it hides you from la Nube |
| `PA_PuffTree` | 10 x 13 x 10 | 5 | Thin trunk with three round puffs in the cap colours, the "tree" of this biome | Trunk collides and blocks sight; `Roof` box on the top puff |
| `PA_MushroomRing` | 7 x 1 x 7 | 12 | Ring of six small mushrooms | `tiny`, decoration; a creature likes to nap in one |
| `PA_PuffFlower` | 4 x 3 x 4 | 4 | Three dandelion-like white puffs on a stem; gives **Pelusa** | `gather`, attribute `Gather = Pelusa`; `tiny` 3 |
| `PA_SunflowerPost` | 3 x 7 x 3 | 4 | A sunflower on a post with a glowing sun bead at the base, its face turned to the circle centre. Four mark every sun circle | Attribute `SunCircle = <id>`; the glowing ring itself is a separate `SunRing` part the Refugio system can toggle |
| `PA_HillBoulder` | 6 x 5 x 4 | 1 | Smooth lavender boulder; half of them perch on the hills | Collides; a creature perch |
| `PA_RainbowGate` | 30 x 13 x 3 | 23 | Two wood posts 17.9 studs apart with a three-band coral, sky and butter arch 11.9 studs clear | The **Portón del Arcoíris**; `clear` 16 x 11 is met |
| `PA_Pinwheel` | 2 x 4 x 2 | 6 | Pinwheel on a stick along the path; also the shape of the **Molinillo** distraction item | `tiny` 4; attribute `Distraction = Molinillo` |
| `PA_SetaTrueno` | 26 x 26 x 26 | 17 | The tallest mushroom, in the pond's shallows 15 studs from her home, with a spiral of eight small caps up the stem (in open sky) and a butter-yellow crown on top: a lookout a child can climb. It is no longer the event pedestal (the event egg is at La Colmena, section 6) | Collides; `Roof` under the cap; `LookoutMarker` at the top |

**Planned mix (seed 20261109, written by the planner):** 48 giant mushrooms (16 per cap colour), 30 puff trees, 12 mushroom rings, 40 puff flowers in 8 patches, 32 sunflower posts (8 circles x 4), 20 boulders, 1 gate, 16 pinwheels, 1 Seta Trueno: **200 instances**, **1,259 primitive parts** with the nests, circles, hills, path, signs, beast placeholder and markers. The forest plan is 207 instances and 512 MeshParts; this is more parts and far fewer triangles, and **neither has been measured on a device**.

**Rules the planner enforces (and `tools/test_plan_pradera_layout.py` re-derives):** every point of the Tormenta zone outside the pond has a roof edge within 25 studs (1,065 grid points, 0 uncovered); at least four caps lean over the path so cover is taught on the way in; mushrooms in the Tormenta zone are larger than in the Prado (mean 1.17 against 0.98); no sun-circle candidate within 60 studs of her home or on the pond rim; nothing but the Seta Trueno in the pond; nests on flat ground with 10 studs of clearance (the event nest at La Colmena included); the first nest within 80 studs of the gate; La Colmena's 45-stud leash disc at least 15 studs outside the Tormenta zone, 5 studs outside every sun circle and 3 studs from the path's edge, and no sun-circle candidate placed closer than that; hills clear of the path, the circles and the nests; every instance's `y` equals the hill formula under it.

**Materials of the biome (two):**

| Material | Where | Carried as | Intended use |
| --- | --- | --- | --- |
| Pelusa (fluff) | Puff flowers; six of the eight patches beside the path, two inside her ground | Pouch | Feeds the corral window (section 9), Molinillo recipe, Pradera skill nodes |
| Espora Brillante (bright spore) | Giant mushrooms inside the Tormenta zone, any hour (this biome has no night-only resource) | Bag item | Rarer recipes and corral upgrades |

## 4. Five creatures

All at Lumipol scale (`WildboundSpecies.LOOKS.Lumipol.size` 3 x 2 x 2.4; a cría is 0.55), round bodies, eyes at least a quarter of the head, no teeth, the primitive stand-in rule (body, accent, two eyes, glow) until rigs are approved. Every real creature **blinks** (eyes close 0.1 s every 3 to 5 s) and **breathes** (scale 1.00 to 1.04); a thing that never moves is never a creature here, which is the tell the event reuses. Rarity follows the W2 bands from her pond: Común beyond 120 studs, Rara 80 to 120, Épica 45 to 80, Legendaria under 45 and only from the event egg. Capture is the Lumipol calm ring (hold still 4.5 s inside the ring); the ring is a daisy chain here and success plays a giggle.

| Name | Rarity | Nest (sector x, z) and parents | Look (body, accent, eye, glow) | Behaviour | Corral, Esencia per minute |
| --- | --- | --- | --- | --- | --- |
| **Chispín** | Común | N1 (-125, -30), 2 adults, 68 studs from the gate: the first catch | Butter-yellow ball with one lightning-shaped tuft (`F9E27A`, `F2B84B`, `3A2E22`, `FFF1A8`) | Hops in short arcs and squeaks twice when her shadow comes within 40 studs, so a wild one is a free early warning | 0.5 |
| **Musgón** | Común | N2 (-30, -70), 2 adults | Mint moss dome on four stubby feet (`A8E6B0`, `6FBF8A`, `2B3A30`, `C9F5D0`) | Dozes under caps and waddles to the nearest roof when it drizzles, teaching cover by example | 0.5 |
| **Esponjín** | Rara | N3 (60, 50), 3 adults, 103 studs from her home | White cloud-fleece puff floating a hand above the grass (`FFFFFF`, `D9C8F0`, `4A3F6B`, `F2ECFF`) | Drifts downwind of her and settles in sun circles, so following one often leads a child to safety | 1.0 |
| **Hongolín** | Épica | N4 (100, -45), 3 adults, 67 studs from her home, on the pond side | Walking coral cap with glowing spots and tiny legs (`F28B9B`, `FFF4E0`, `3A2E22`, `FFD7DE`) | Stays near the pond rim and spreads its cap when startled | 2.0 |
| **Relampino** | Legendaria | N5 at La Colmena, sector (-75, 75), world (225, 75), on flat ground, no parents: event only | Small lilac storm-puff with a sunny round face and harmless sparks (`B4A8D2`, `FFD23F`, `2B2440`, `FFF1A8`) | Hatches only from the Huevo Real that La Abeja Reina guards (section 6), circles its owner crackling | 4.0 |

**Abilities (each needs code; none exists). Every one has a downside, and none solves the beast:**

| Species | Ability | Effect | Duration, cooldown | Downside | Does not solve |
| --- | --- | --- | --- | --- | --- |
| Chispín | Chillido | Warning at 55 studs instead of 40 | Passive while companion | Its squeak spooks wild creatures within 20 studs for 10 s, so captures near her get harder | A ring already drawn |
| Musgón | Techito | Owner counts as roofed where they stand | 3 s, 45 s | Owner walks at 10 for 4 s afterwards (it is heavy) | A second bolt |
| Esponjín | Brisa | Owner walks at 18 in the Pradera | 6 s, 40 s | Owner cannot sprint while it runs | Being inside the ring at impact |
| Hongolín | Sombrilla | Everyone within 4 studs of the owner counts as roofed | 3 s, 45 s | Its spots glow: her detection on the owner +10 for 10 s afterwards | Hiding from a chase already on |
| Relampino | Achís | A spark makes her sneeze: 1.2 s unable to move or strike | Once per chase, 30 s | The owner's lamp goes out for 10 s at Night | Anything a roof does not already do |

**Why rare is not simply better.** Chispín's warning is the single most useful thing against her and it is Común. Relampino is Legendaria because it is hard to get, not because it wins: a sneeze does what any mushroom cap does for free. Hongolín shares cover with friends, which is social, not stronger. This keeps the user's rule that the free path is always viable.

## 5. The beast: La Nube Gruñona

### 5.1 Look

A wide, low cumulus about 14 studs across and 8 tall, floating with her belly 10 studs above the ground. Lilac-grey body, a darker belly, two round eyes that are closed lines when calm and wide circles when hunting, thick frowning eyebrows, cheeks that puff before a bolt. Under her: a soft shadow disc (radius 20) and a few falling drops. No mouth with teeth, no red, no black. She is the only grey thing in the biome and the only thing that casts a visible shadow, so a child finds her in one glance. The Luau builder places a parts-only placeholder (five puffs, belly, eyes, brows, shadow, six waypoints) at her home.

### 5.2 Senses

She is weather: she sees anyone standing **under open sky** within her detection range. The server casts one ray straight up from the player's head against `CanQuery` parts tagged `WildboundRoof`; a hit means covered. Range 40 studs by day, dusk and dawn. She does not hear footsteps, does not care about flashlights, and never reads the camera. The event egg in a bag does not change her senses (the event is La Abeja Reina's, section 6). Cost: one upward ray per player per 5 Hz tick, about 40 rays a second for eight players.

### 5.3 Where and when

| Rule | Decision |
| --- | --- |
| Home | The pond at sector (150, 0), world (450, 0) |
| Strike zone (`tormenta`) | Within 110 studs of the pond. She strikes only targets inside it, so the Prado, the plaza and the gate path can never see a bolt |
| Leash | 90 studs from the pond; the gate is 336 studs away, so no rule has to be checked twice near the hub |
| Per-player hunter | As planned for La Silueta (F2): one Nube per player, bound to its owner, capped by `MAX_HUNTERS`; others see your Nube faint (user decision S4) |
| Day, Dusk, Dawn | Awake: drifts between six pond waypoints at 6 studs/s, eyes closed, drops falling |
| **Night** | **Asleep** over the pond: snoring visibly ("Zzz" puffs), detection halved to 20, she acquires nobody beyond it and wakes only for a player inside 25 studs of the pond or anyone climbing the Seta Trueno, for 20 s, then sleeps again. Night is the safe time east, the mirror of the forest where Night is worst, so the one world has a rhythm a child can plan around (user decision S3) |

### 5.4 Hunt rule, state by state

| State | Chip (Spanish) | Rule | Tell |
| --- | --- | --- | --- |
| Calma | none | Pond loop at 6 studs/s, eyes closed | Her shadow slides over the grass; drops fall |
| Gruñido (notice) | "La Nube te vio" | 1.5 s after a valid sighting; no movement toward you yet | Eyes open, brows drop, cheeks puff, a low grumble; the shadow deepens one step |
| Persecución (chase) | "¡La Nube te sigue!" | Follows at **14 studs/s**, under walk speed 16; memory 2 s after losing sight; gives up past 60 studs or after 12 s | She leans forward; drizzle thickens; a tuba-like hum rises. Wild Chispín within 40 studs squeak |
| Relámpago (telegraph) | "¡Rayo! Sal del círculo" | From within 12 studs: a **sun ring of radius 6 appears where you stand at that instant and never moves**. Telegraph **1.0 s** (tunable 0.8 to 1.5; the 0.8 s fair-strike floor is a contract). The bolt lands in the ring at the end | The ring is the bright spot inside her shadow: "where the light is, the lightning falls". It pulses twice, a rising zip plays, the chip is large with a bolt icon |
| Chispazo (hit) | "¡Chispazo!" | Only if you are inside the ring at impact and every fair-strike gate passed (persistent model, dwell, target-only warning with attack id and acknowledgement, staged consequence, preload). Consequence in 5.5 | Hair stands up, soot puffs, a sneeze. No blood, no scream |
| Ráfaga (second hit while marked) | "¡Ráfaga! De vuelta al portón" | A gust carries the child 3 s back to the gate's sun circle. Consequence in 5.5 | A giggle, pinwheels spin, rain on the screen for 2 s, then sun |
| Desinflada (give up) | "La Nube se aburrió" | After a strike, a lost quarry or 12 s of chase: she sighs, shrinks to 0.8 for 3 s and drifts home for 10 s, unable to acquire | The frown turns to a pout |
| Bostezo (Cansarla) | "La Nube bostezó" | Three pinwheel distractions or roof dodges in one chase: she yawns and drifts home to nap for 60 s | A huge yawn, "Zzz" puffs |
| Estornudo (stagger) | "¡Achís!" | A Relampino companion's spark within 15 studs: 1.2 s unable to move or strike, once per chase | Her drops scatter |
| Duerme (Night) | "La Nube duerme" | Section 5.3 | Closed eyes, snoring, pale belly |

**Why it stays fair (arithmetic, not measured).** Chase speed 14 is below walk 16 and far below sprint 24, so walking away always works; her only pressure is that she flies over props. Leaving a fixed 6-stud ring at walk speed takes 0.4 s against a 1.0 s telegraph; a child who hesitates half a second still escapes. Bolt cooldown 3 s. She never enters a sun circle, never strikes under a roof, never follows into the hub, never strikes within 9 studs of a spawn pad.

### 5.5 Consequence: the kids rule

This replaces the forest's loss rule inside the Pradera (user decision S2, defaulting to the kids rule as both judgments asked).

| Hit | Consequence | Recovery |
| --- | --- | --- |
| First (Chispazo) | Marks you (soot on the avatar, yellow drips at the screen edge, never red) and **parks one unwarded bag item next to you**, owner-only, visible with an arrow, for 120 s. Pouch materials are never touched | Pick it up; the mark clears in 5 s inside a sun circle |
| Second while marked (Ráfaga) | A 3 s gust to the gate's sun circle. **No defeat screen, no stack loss, no "lost" summary**: the summary says where your things are. Carried bag items drop where the gust began and wait 120 s | Walk back. The mark is gone on arrival |

Nothing is ever destroyed by la Nube. Damage stays off in this biome even in private damage mode. The cost is time and a walk, which is what a seven-year-old can understand and a parent can accept. The server-side move of the Ráfaga must pass the same stall-cancel gates as a strike, or it becomes a griefing tool on a stalled server.

### 5.6 Escapes and the win, all free

| Way | Rule |
| --- | --- |
| **Roof** (hide) | Stand under any giant mushroom cap or puff tree crown: the sky ray is blocked, she loses you after the 2 s memory, circles sadly for 4 s, then Desinflada. No prompt, no dwell; cover is just standing under something, which Musgón teaches |
| **Sun circle** (safe zone) | Rings of four sunflower posts with a glowing `PA_Neon_Sun` ring, radius 12 (the gate's is 25): no strikes, no acquisition, stamina regen x2. Two permanent (gate, Plaza del Molino) plus 2 to 3 of six candidates rerolled on the 5-minute wave clock (W4), never within 60 studs of her home. Three candidates sit inside the Tormenta zone, so safety exists where she hunts |
| **Molinillo** (distraction) | A pinwheel item: crafted (8 Pelusa, 1 Espora Brillante, 6 Esencia; hold 2) **or found** under mushroom rings (one per ring per wave, no crafting needed). Placed, she cannot resist blowing on it and hovers over it for 8 s, acquiring nobody |
| **Walk away** | 16 beats 14, always. Sprint ends it in two seconds |
| **Cansarla** (the win) | Three distractions or roof dodges in one chase: "La Nube bostezó", 60 s nap. A child without Relampino still beats her, and gets 3 Esencia once per wave |
| **Companion sneeze** | Relampino's spark, once per chase. Lumipol's pulse does nothing here: Lumipol stays the forest's revealer |

### 5.7 Profile shape and tunables

```lua
-- Proposal only. The night scope, the second home and the sky-ray sense are rule changes, not data.
NubeGrunona = table.freeze({
	name = "NubeGrunona", specialBehaviorId = "Nube", visualScaleKey = "NUBE_VISUAL_SCALE",
	base = table.freeze({ speed = 14, detectionRange = 40 }),
	night = table.freeze({ scope = "Tormenta", speed = 14, detectionRange = 20, asleep = true }),
}),
```

Tunables for the dev panel: `NUBE_TELEGRAPH_SECONDS` 1.0 (floor 0.8), `NUBE_RING_RADIUS` 6, `NUBE_CHASE_SPEED` 14 (ceiling 15.5), `NUBE_MEMORY_SECONDS` 2, `NUBE_MAX_CHASE_SECONDS` 12, `NUBE_GIVE_UP_DISTANCE` 60, `NUBE_LEASH` 90, `NUBE_DETECTION` 40 / 20 asleep, `NUBE_NAP_SECONDS` 60, `NUBE_CANSARLA_COUNT` 3, `NUBE_VISUAL_SCALE` 1.0.

## 6. Evento: la Abeja Reina

User decision, 2026-11-10. La Nube Gruñona is the biome's only permanent beast. **La Abeja Reina** (adapted from `kids-biome-concepts/bee.md`) is the beast of the 20-minute biome event: she sleeps inside her hive at all other times, wakes when the event egg appears, guards it for the 5-minute window, then goes back to sleep. The numbers below are generated by `tools/plan_pradera_layout.py` into the `abeja_event` block of `pradera-layout-v1.json` and re-derived by `check_abeja_event` in `tools/test_plan_pradera_layout.py`; every one of them is a hypothesis for the tuning panel and a playtest.

### 6.1 Where: La Colmena

| Item | Decision |
| --- | --- |
| Hive and egg point | **La Colmena**, sector (-75, 75), world **(225, 75)**: a flat glade south of the cream path whose nearest solid prop is 45 studs away (the planner keeps at least 10, the wild-nest rule). The event nest N5 (Relampino) stands in its centre on a wax pedestal. The hive itself (stacked wax tiers in the `PA_` palette) is a kit follow-up: the generated module places only the nest and its `EventNestMarker` |
| Distances | 237 studs from la Nube's pond, 134 from the gate, 70 from the Plaza del Molino, 181 from the hub's east gate, 137 from the open-world ring road |
| Announcement | Banner "¡Huevo Real en La Colmena!" to every player, a distant cheerful trumpet-buzz, and a **rainbow** that rises from the gate and arcs to La Colmena, visible from the hub plaza: the navigation is a picture. The Plaza del Molino bulletin shows the countdown |
| The egg | The **Huevo Real**: lilac with a yellow zigzag and a honey-gold band, rocking gently and casting a shadow. It hatches **Relampino**, the biome's Legendaria and its only source. "Tomar el huevo" is a 3 s hold; the first player to finish it claims it (one claimant per server per event) |
| The two-egg puzzle (from mimo) | A **Huevo de Cera** sits beside it: matte wax, perfectly still, no shadow. Taking it melts it into honey: Pegajoso (below) for 6 s, no sting, nothing dropped. Tells are shape, motion and shadow, so they work muted and colour-blind; the chip "Algo no cuadra…" appears at 6 studs for readers |

### 6.2 When: tied to the event clock

| Moment | What she does |
| --- | --- |
| Event clock | The egg appears at 300 s and every 1,200 s after, and stays 300 s (`first_seconds`, `period_seconds`, `window_seconds`). The offset against the forest event is still open (gaps document, section 2.5) |
| Outside the window | **Asleep inside the hive.** No Abeja exists for anybody; the glade is ordinary meadow and spawns nothing (the open-world seeds keep 48 studs clear of the egg) |
| Egg appears | **Despierta**: a 3 s wake-up (yawn, stretch, crown glints, "¡Bzz!"). She cannot notice or strike while waking, so nobody is caught by the alarm |
| Window open | **Guardia**: she loops the egg at radius 18 at 7 studs/s and hunts by sound (6.4) |
| Egg claimed and carried past her leash, or window ends | **Vuelve a dormir**: a 4 s yawn and "Zzz" back into the hive. A telegraph in progress at that instant is cancelled, never resolved |
| Night | The event still runs. She wakes, but her hearing is halved (`ABEJA_NIGHT_HEARING_SCALE` 0.5) and the glade is lantern-lit, matching the Pradera's "Night is the safe time east" |

### 6.3 Her ground, and why it never meets anything safe or la Nube's

| Radius around the egg | Studs | Rule |
| --- | ---: | --- |
| Patrol | 18 | Her guard loop |
| **Guard (strike zone, "colmenar")** | **35** | She acquires, telegraphs and stings only players inside it |
| Leash | 45 | She never flies farther from the egg; walking out of it ends every hunt |
| Wake | 70 | Your own Abeja exists only while you are this close during the window |

Checked by the planner and its tests on every seed: her 45-stud leash disc stays **82 studs outside la Nube's 110-stud strike zone** (at least 15 required), **13 studs outside the nearest sun circle** (the Plaza del Molino; at least 5 required for every sun circle, the gate's 25-stud circle and every rerolled candidate included, and no candidate is ever placed closer), **12 studs from the cream path's edge** (at least 3 required) and inside the sector. In the open-world plan she is a third strike zone: no world road and no Refugio candidate lies inside her guard radius or her leash (`check_no_road_or_refugio_inside_any_strike_zone`), and no two strike zones overlap (`check_strike_zones_never_overlap`).

### 6.4 Senses and hunt (from the bee concept)

She **hears**, never sees: the server derives a noise radius from what each player did at 5 Hz, never from a client report. Walking 30 studs, sprinting 55, a jump landing 70, a failed capture 55; **standing still is silent (0)**, and so is the 3 s "Tomar el huevo" hold. She ignores roofs, flashlights and the camera. So the event teaches the one trick la Nube does not: la Nube is "look up and stand under a cap", the Abeja is "freeze when she turns". A child who sneaks in while she is on the far side of her loop and freezes when she comes round wins without a sting.

| State | Chip (Spanish) | Rule | Tell |
| --- | --- | --- | --- |
| Guardia | none | Loop at radius 18, 7 studs/s | Yellow and brown stripes, half-closed smiling eyes, a low hum |
| Te oyó | "Te oyó" (ear icon) | A player inside her guard radius made noise within her hearing: she stops for 1.0 s, no movement | Antennae snap toward the sound, a "?" puff, stripes flash orange once, the hum stops |
| Te busca | "Te busca" (eyes icon) | Flies to the last heard point at **10 studs/s** (under walk 16), memory 3 s, never past her leash | Orange stripes, a buzz that rises in pitch (never volume) as she nears |
| ¡Zum! (telegraph) | "¡Zum! Sal de la línea" | Within 9 studs of a heard target: she hovers, rises 3 studs and a **6-stud lane is drawn on the grass to the target**. Telegraph **1.2 s** (floor 0.8, a contract). Target-only warning with attack id and acknowledgement, every fair-strike gate of the forest | Stripes pulse orange, the lane and a honey ring glow, the buzz climbs to a whistle |
| Picotazo (sting) | "¡Plof!" | She dives along the lane at most 12 studs and cannot turn; only a target still in the lane at impact is stung | A soft "plof" and a honey splat |
| Después | none | 2.5 s cooldown, dizzy stars | Hovers, wide open |
| Te perdió | "Te perdió" (check icon) | 3 s with nothing heard, or the target left her leash: a shrug, then back to her loop | "¿?" puff, stripes fade to yellow |
| Duerme | "La Reina duerme" (moon icon) | Section 6.2 | Closed eyes, "Zzz", pale stripes |

**Why it stays fair (arithmetic, not measured).** Her search speed 10 is under walk 16, so walking away always works, and 10 studs past her guard rim she must stop. Leaving the 3-stud half-lane takes 0.19 s at walk speed and 0.33 s at the honey speed 9, against a 1.2 s telegraph. Standing still is always silent. She never strikes outside her guard radius, never enters a sun circle (none is within reach), never comes near the gate, the path or the hub, and is asleep for 15 of every 20 minutes.

### 6.5 The sting: honey, never damage

The Pradera's kids rule (section 5.5) applies; damage stays off even in private damage mode.

| Sting | Consequence | Recovery |
| --- | --- | --- |
| First (Pegajoso) | Honey: walk speed **9 for 6 s** (kept above 8 so the shared `carrySpeed > 8` contract holds), yellow drips at the screen edge (never red), and **one unwarded bag item is parked next to you** for 120 s, owner-only, with an arrow. Pouch materials are never touched. **If you carry the Huevo Real, it drops at your feet** and waits 120 s, still claimable by anyone: the event stays winnable | A sun circle or the hub washes the honey off on entry; it also wears off |
| Second while Pegajoso (Vuelo de vuelta) | She scoops you up, giggling, and flies you **3 s to the Plaza del Molino** (the nearest permanent sun circle, 70 studs). Carried bag items drop where the sting happened and wait 120 s. **No defeat screen, no stack loss, no "lost" summary**: the summary says where your things are. The server-side move passes the same stall-cancel gates as la Nube's Ráfaga | Walk back; the honey is gone on arrival |

Nothing is ever destroyed by the Abeja. The cost is time and a short walk.

### 6.6 How a child reads it

Four cues, each enough alone: (1) a giant smiling bee, the only striped thing in the biome, appears only while the rainbow is up; (2) her stripes are her mood: yellow is calm, orange means she heard you; (3) a glowing lane on the grass means step sideways, and the lane never moves; (4) a big icon chip in big words. The banner's second line teaches the rule once: "Si no te mueves, no te oye." Sound is comic (hum, "¡hm!", buzz, "¡plof!", giggle), never a scream; the event works muted. `WildboundFear.client.luau` effects stay off in the Pradera.

### 6.7 Per-player rule

| Rule | Decision |
| --- | --- |
| One Abeja per player | Like la Nube and La Silueta (F2): your Abeja hears and targets only you; others see it faint (S4). It exists only while the event runs **and** you are within 70 studs of the egg; it flies back into the hive when you leave or the window ends |
| Never two beasts on one player | La Colmena's whole leash disc lies outside la Nube's strike zone, so a player inside the Abeja's guard radius is always outside la Nube's: at any instant at most one beast can target a player, in normal play and during the event. La Nube keeps hunting her own ground as usual during the event |
| `MAX_HUNTERS` | A player's Nube and Abeja never hunt at once, but both may exist; whether the idle one despawns is the open hunter-lifecycle question (gaps document, M5). Eight players at the egg mean eight Abejas over one glade: pathing cost and readability are to be measured |
| Claimant | One per server per event, as before; a sting drops the egg where it was carried, so the event is never lost to a sting |
| Payoff | Banked at the hub incubator; hatches **Relampino**; Esencia at extraction: the Heart egg row (14). Per-egg hatch time against the incubator's single `HATCH_SECONDS` is still open (gaps document, section 2.5) |
| Fairness for the rest | While the event runs, Épica spawns in the Tormenta zone double, so a child who is not first still profits from the trip, with la Nube as the only beast there |

### 6.8 Tunables (dev tuning schema, proposal)

| Key | Value | Range to expose | Note |
| --- | ---: | --- | --- |
| `ABEJA_GUARD_RADIUS` | 35 | 25 to 40 | Must keep the planner's clearances; regenerate the plan after a change |
| `ABEJA_LEASH` | 45 | guard + 5 to 50 | Same |
| `ABEJA_PATROL_RADIUS` | 18 | 10 to 25 | |
| `ABEJA_WAKE_RADIUS` | 70 | 55 to 90 | Per-player spawn distance |
| `ABEJA_WAKE_SECONDS` / `ABEJA_SLEEP_SECONDS` | 3 / 4 | 2 to 5 | No notice or strike while waking |
| `ABEJA_PATROL_SPEED` / `ABEJA_CHASE_SPEED` | 7 / 10 | chase ceiling 15.5 | Chase stays under walk 16 |
| `ABEJA_HEAR_WALK` / `ABEJA_HEAR_SPRINT` / `ABEJA_HEAR_STILL` | 30 / 55 / 0 | still is always 0 | Jump landing 70, failed capture 55 |
| `ABEJA_NIGHT_HEARING_SCALE` | 0.5 | 0.4 to 1.0 | |
| `ABEJA_NOTICE_SECONDS` / `ABEJA_MEMORY_SECONDS` | 1.0 / 3 | | |
| `ABEJA_TELEGRAPH_SECONDS` | 1.2 | 0.8 to 1.5 | 0.8 s floor is the fair-strike contract |
| `ABEJA_LANE_WIDTH` / `ABEJA_DIVE_LENGTH` | 6 / 12 | | |
| `ABEJA_COOLDOWN_SECONDS` | 2.5 | | Reuses `ATTACK_COOLDOWN` |
| `ABEJA_STICKY_SPEED` / `ABEJA_STICKY_SECONDS` | 9 / 6 | speed above 8 | `carrySpeed > 8` contract |
| `ABEJA_PARK_SECONDS` | 120 | | Parked item and dropped egg |
| Event clock | 300 / 1200 / 300 s | | First, period, window |

## 7. Loop in this biome, and how a child reads it

Enter through the Portón del Arcoíris; the first 25 studs are a sun circle and the pictogram sign stands beside it. Chispín's nest is 68 studs in and visible from the arch, so the first catch happens in about 15 s (the K1 to K4 hook). Follow the cream path under four leaning caps to the Plaza del Molino (permanent sun circle, a bench for Molinillos, a bulletin for the event clock). Go on toward the pond for Esponjín and Hongolín under her shadow, learning roofs, rings and the walk-away. Return to the hub to bank, incubate, put creatures in the corral and spend. Every 20 minutes a rainbow points to La Colmena, where La Abeja Reina wakes to guard the Huevo Real for five minutes.

Four cues, each enough alone: (1) the only grey thing in a pastel world is coming; (2) the only dark patch on the ground is her shadow, and you are in it; (3) a yellow ring under your feet means step out, and the ring never chases; (4) a big icon chip in big words. Sound is comic (grumble, tuba hum, sneeze, zip), never a scream, and the game works muted. The gate sign shows three pictograms and three short lines: grey cloud, arrow to a mushroom; yellow ring, arrow out; sunflowers, a smile. `WildboundFear.client.luau` effects are off inside the Pradera: no camera shake, no screen darkening, no heartbeat.

## 8. How the biome joins the hub

Rewritten 2026-11-10 to match the open-world plan (`docs/design/wildbound-open-world-hub.md`, generated by `tools/plan_open_world_layout.py`, which now reads this biome's layout JSON).

| Element | Decision |
| --- | --- |
| Frame | One world frame with the hub centre at (0, 0). The hub is a safe circle of **radius 60**. The forest sector is centred at (-300, 0), the Pradera at (+300, 0), each 400 x 400; a 40-stud transition band lies between the hub circle and each sector (east: x 60 to 100). The existing forest moves as one `PivotTo` of its root |
| East gate | `PA_RainbowGate` at sector (-186, 0), **world (114, 0)**, over the cream path. The path starts at world (105, 0), and a 45-stud connector joins it to the hub's east gate at (60, 0). A permanent sun circle of radius 25 is centred on the gate, covering world x 89 to 139. It does **not** touch the hub's safe circle: the 29 studs from x 60 to 89 are transition ground that is neither safe nor hunted, which is harmless because la Nube's strike zone starts at x 340 and La Colmena's centre lies 64 studs south of the path |
| West gate | The forest's mirror is the hub's west gate (-60, 0); the "Umbral del Bosque" road leads to the forest shelter at (-195, 125). A child still sees "dark door left, rainbow door right" from the plaza |
| Join without a seam | Terrain blends over the transition and the first studs of the path: the hub's warm sand becomes `PA_Path` cream; mushrooms start small at the gate and grow toward the pond; the atmosphere blends `hub` to `prado`; the audio bed crossfades from the hub's murmur to birdsong and wind chimes |
| Rules at the join | Zone resolver: `hub` (safe), the transition (no rule), then `sol` at the gate and the plaza, then `prado`, then `tormenta` (within 110 of world (450, 0)); `colmena` (within 35 of world (225, 75)) only while the event runs. Her leash (90) ends 246 studs short of the gate |
| Ring road | The open world's beast-free ring passes the Pradera at z ±212 and, on the east, at x 590: 140 studs from her pond, outside her 110-stud strike zone and her 90-stud leash. The Pradera has no ring spoke of its own; its players reach the ring through the hub's north and south spokes |
| What the hub shows | The corral and the trophy display face east, so Pradera creatures are shown toward their biome; the event rainbow is visible from the plaza |

## 9. The corral and Esencia

The user's direction: creatures earn the local currency for their owner. The economy's AFK contract (`wildbound-economy-p0.md`, AFK-1, AFK-2: nothing grows from time alone) conflicts with a per-minute corral as written. The narrowest honest version, from the bee concept, keeps the direction and the spirit of the contract:

| Rule | Decision |
| --- | --- |
| Who produces | Only creatures placed in the owner's corral at the hub |
| When | Only while the owner is in the server and alive. Nothing accrues offline (DataStore is forbidden today anyway) |
| Fed first | A creature produces only after the owner feeds it one Pelusa at the corral prompt ("Dar pelusa"), which opens a 20-minute window. One gathered material, one server-observed action, one window |
| Cap | Each creature holds at most 20 minutes of output ("Lleno"). The owner must walk to the corral and hold "Recoger Esencia" to bank it; nothing is credited without that action |
| Rates | 0.5 / 0.5 / 1.0 / 2.0 / 4.0 Esencia per minute by species (section 4). A full starter corral of four Común makes 2 per minute, against about 6 to 7 per minute for the simulated active archetypes, so the corral is pocket money, never a reason to stop playing |
| Slots | 4 free at the start; slots 5 to 8 cost **60 / 150 / 350 / 800 Esencia** (the rising free ladder). Whether extra slots may also be a convenience offer is the user's call (section 14, S1) |
| Display | The corral is also the show: every placed creature is visible to visitors, and the trophy display beside it holds the rarest one of each biome |
| Simulation | `tools/simulate_economy.py` gains a `corral` input before any number is trusted; the 180 s greedy expedition floor must still hold |

## 10. Economy and monetization hooks (design only)

The user wants a strong, honest incentive in the Steal-an-Egg manner: the free path always exists but each step costs more, and a Robux offer shortens the path without ever being the only path. Nothing below is implemented or authorized: Developer Products need the user's Creator Hub setup, `ProcessReceipt` and saved progress, and DataStore is currently forbidden; `monetization` stays `"none"` in the tuning JSON.

Policy rules every row must keep: clear prices in Robux shown before any purchase, no deception, no paid randomness or loot boxes, convenience over power, a free path that is always viable, nothing that changes la Nube's rules, the telegraph or the strike.

| Hook | Free path (Esencia, rising) | Convenience candidate (Robux, later) | Why it is honest |
| --- | --- | --- | --- |
| Corral slots 5 to 8 | 60 / 150 / 350 / 800 | The same slot, bought earlier | The slot is identical; paying buys time, not output. User decision S1 |
| Molinillo | Found under mushroom rings, or crafted | A pack of five, same item | Never stronger than the found one |
| Guantes de captura (I1) | Crafted: calm meter +30 % | The same glove, bought earlier | Never stronger than the crafted one |
| Hatch time of the storm egg | 300 s | A speed-up was ruled out once in `wildbound-incubator.md`; the user's new direction reopens it | User decision S5; if yes, cap it at halving the wait so the event stays a shared beat |
| Pradera skill nodes | Esencia + Pelusa: "Pies de nube" (walk 17 in the Pradera only, she stays 14), "Ojo de sol" (ring shown 0.2 s earlier on your side; her 0.8 floor is untouched), "Bolsillo de espora" (bag +1 in the Pradera) at 40 / 100 / 220 | None: skills stay earned | Power is never sold |
| Cosmetics | Cap-colour ribbons for corral creatures by playing | Ribbons, hats for Chispín | Cosmetic only |

How the incentive grows: the Esencia ladder roughly doubles per step (60, 150, 350, 800) while the active income stays about 6 to 7 per minute, so the fourth extra slot is an hour of play and the offer to skip it is worth considering; the third is twenty minutes and most children will earn it. That curve, not a wall, is the Steal-an-Egg lesson the user named. The simulator must confirm the hours before any price is written.

## 11. The offline kit

| File | What it is |
| --- | --- |
| `tools/plan_pradera_layout.py` | The seeded planner: terrain (hills, pond, path), the 200 prop instances, five nests with sleeping parents, eight sun circles, her home and waypoints, the hub frame. Writes JSON, SVG and PNG under `assets/maps/pradera-layout/` |
| `tools/test_plan_pradera_layout.py` | 24 contracts (section 3 and La Colmena's clearances of section 6), on the default seed and two others |
| `assets/maps/pradera-layout/pradera-layout-v1.json` | The single source of truth; `.svg` and `.png` are the readable plan |
| `tools/build-pradera-kit.py` | Renders the JSON into the Luau builder and writes `assets/maps/pradera-layout/pradera-kit-report.json` (exact part counts, palette, sign copy, module Adler-32). `--check` exits 1 when the module is stale |
| `tools/test_build_pradera_kit.py` | 13 contracts: every instance is a row once, the data block equals the plan, Spanish signs present, palette equals section 2, colliders and query parts only where section 3 allows, Luau blocks balance, parts under the cap, the written module and report are fresh |
| `tools/build-wildbound-pradera-map.luau` | **Generated.** `Builder.build(parent, origin?)` builds `WildboundPradera` detached, pivots it to the hub frame (default world +300, 0, 0) and attaches it once complete; refuses a second. Folders: `Ground`, `Paths`, one per prop, `Nests` (tag `WildboundPraderaNest`, attributes `Species`, `Rarity`, `EventOnly`, a `NestMarker` primary part and sleeping `Adult` models with `Asleep = true`), `SunCircles` (tag `WildboundSunCircle`, `Permanent`, `Radius`, `Label`), `NubeGrunona` (tag `WildboundPraderaBeast`, waypoints), `Signs` (Spanish copy with `SignKey`), `Markers`. Everything anchored and untouched; only floor, hills, path, pond, stems, trunks, the Seta Trueno, gate posts, boulders and steps collide; only floor, hills, stems, trunks and the `Roof` boxes answer queries |

Regenerate: `python -I -B tools/plan_pradera_layout.py` then `python -I -B tools/build-pradera-kit.py`; test with `python -I -B -m unittest discover -s tools -p "test_*pradera*.py"`. **The module has not been run in Studio** (another workflow owns Studio); when the parent authorizes it, paste it as a ModuleScript and compare the Adler-32 printed by the generator, then build into a detached folder first.

## 12. Free toolbox candidates (stand-ins only, nothing inserted)

Found with `search_asset` (scope `creator_store`, free only, Model) on 2026-11-09 against the Studio instance "Experiencia sin título (placeId 122652861404212)"; a second unnamed instance was listed and not used. Read-only: nothing was inserted, no `execute_luau`, no Play. Every id below is copied from a search result; none was invented. Thumbnails are 420 x 420 PNGs fetched from `https://thumbnails.roblox.com/v1/assets?assetIds=<id>&size=420x420&format=Png` and saved under `assets/exports/toolbox-candidates/`. Part counts, hidden scripts, licence and moderation state are unverified for every row; the kit precedent is to build our own, so these are for the user to pick a look or to use as blockout stand-ins.

| Role | assetId | Name (listing) | Creator | What the thumbnail shows | Image |
| --- | --- | --- | --- | --- | --- |
| Trees | 12538989129 | Low poly tree | tastybrekfast | Round faceted green crown on a short trunk; closest to `PA_PuffTree` | `pradera-trees-12538989129.png` |
| Trees | 137666971315705 | Low-poly Tree Nature Plant Forest Pack Trees Palm | Content Deleted - 158552482 | Larger faceted crown, listing states 2 parts, about 14 x 21 x 20 studs, no scripts; deleted creator | `pradera-trees-137666971315705.png` |
| Trees | 98450608726573 | Cartoony Tree | Pixora Games | Yellow-green lobed crown on a brown trunk, the brightest of the three | `pradera-trees-98450608726573.png` |
| Mushrooms (bonus) | 135813134693520 | Giant Mushrooms Cute Low Poly Decor Colorful Magic | SkaterNANightfalln17 | A group of blue, red and purple spotted caps on pale stems: the `PA_GiantMushroom` look almost exactly | `pradera-mushrooms-135813134693520.png` |
| Mushrooms (bonus) | 85000305113185 | mushroom Aesthetic Spotted Magic Colorful Low Poly | Ech0XJlChillF16 | A pink glowing cap over a teal base with fireflies; a whole vignette, heavier | `pradera-mushrooms-85000305113185.png` |
| Mushrooms (bonus) | 111570074691577 | Giant Red Mushroom Forest Colorful Low Poly Red | WarpEwIcenwJelly29 | A blocky brick-built red cap on a grey stem; the weakest match, kept for comparison | `pradera-mushrooms-111570074691577.png` |
| Flowers | 71587366353052 | Dandelion Flower Yellow Sand Plant Decor Flowers | Quicwhir9711 | A yellow dandelion head on a green stem; closest to `PA_PuffFlower` before it seeds | `pradera-flowers-71587366353052.png` |
| Flowers | 140544340129423 | Low Poly Sunflower Simple Happy Flower Model | rooxide03 | Tall low-poly sunflower with leaves; a `PA_SunflowerPost` stand-in | `pradera-flowers-140544340129423.png` |
| Flowers | 90462381837546 | Low Poly Daisy | rooxide03 | White daisy with a dark centre; a cheap scatter flower | `pradera-flowers-90462381837546.png` |
| Creatures | 101714199933694 | CartoonSlime | Jasonawesome511 | Bright green round slime with big eyes, blush and a sprout: the Chispín or Musgón read | `pradera-creatures-101714199933694.png` |
| Creatures | 9668706268 | Low poly Duck | arijonas123456 | Faceted yellow duckling with black eyes; a good scale and cuteness reference | `pradera-creatures-9668706268.png` |
| Creatures | 9217733809 | Slime | FREEQUNNE | Green blob with two huge black eyes; a Hongolín-like silhouette once recoloured | `pradera-creatures-9217733809.png` |
| Beast | 134685504688203 | Low Poly Cloud Sky Weather Cartoon Fluffy | Pix_elNeon7354 | Faceted white cloud; recolour to lilac-grey and add eyes | `pradera-beast-134685504688203.png` |
| Beast | 51785155 | cloud with thunder | BARNICLEB0Y | Pale blue cloud with three yellow bolts; the most readable "storm" icon | `pradera-beast-51785155.png` |
| Beast | 35159365 | Thunder Cloud- TRANSFORMER888 | TRANSFORMER888 | Dark charcoal cloud with two bolts; too dark for the palette, kept as a shape reference | `pradera-beast-35159365.png` |

Searched and dropped (no image kept): the "cute low poly pet creature round" and "cute chick bird" queries returned mostly unrelated listings (houses, meme morphs, a sparkle fish); `159351114` is a 1,708-part brick cloud; `1043162704` ("NUBE:Tormentoso") is a grey cloud over a bolt tornado, less friendly than the three kept; two more sunflowers (`117846607273409`, `82256921061710`) and a second duck (`4685210528`) duplicated kept rows.

## 13. Code implications (not authorizations)

| Need | Where it lands | Why |
| --- | --- | --- |
| Dawn key | `WildboundAtmosphere.luau` `KEYS` | Section 2 has a real Dawn row |
| Biome-aware zones, second home, second leash, `tormenta` and `sol` | `WildboundWorldRules.luau` (`zone`, `inTerritory`, `clampTerritory`) | One home and one rectangle today |
| Sky-ray roof sense | `WildboundWorld.server.luau` beside the sight ray; reads tag `WildboundRoof` | Section 5.2 |
| Fixed-ring strike resolution | `WildboundFairStrike.luau` (impact checks "inside the ring", not "within 7 studs of the guardian") | Section 5.4 |
| Sleep state, `asleep` key, `"Tormenta"` scope, Cansarla counter, Estornudo | `WildboundWorldRules.luau` profiles, `WildboundGuardianBrain.luau` | Sections 5.3, 5.6 |
| Kids consequence and the Ráfaga move | `WildboundFairStrike.luau` staged consequence, `WildboundState.luau` drop rules | Section 5.5; damage off here even in private damage mode |
| Corral with fed windows and a collect prompt | `WildboundState.luau`, `WildboundEconomyConfig.luau` via the tuning JSON, `simulate_economy.py` | Section 9; the AFK contract is the user's call |
| Species data and abilities | `WildboundSpecies.luau` gains five looks with a `rarity` field (W2 adds the field); abilities need `Rules.tryAbility` to accept new actions | Section 4 |
| Sun circles as Refugios | The W4 Refugio system reads `WildboundSunCircle` models | Section 5.6 |
| Every number in the dev tuning schema | `WildboundTuningSchema.luau` | Project rule for all new constants |
| `MAX_HUNTERS` across both biomes | F2 | Three per-player beast kinds (Silueta, Nube, Abeja) must share one cap |
| La Abeja Reina as the event beast | A hearing module (`WildboundNoise.luau`, server samples at 5 Hz) feeding `Hunt.step`; an event clock that wakes and sleeps her; per-player spawn inside the wake radius; the lane telegraph and dive through `WildboundFairStrike.luau`; Pegajoso and the dropped event egg in `WildboundState.luau`; every `ABEJA_*` value in the tuning schema | Section 6 |
| La Colmena hive model | `tools/build-pradera-kit.py` (a `PA_Colmena` landmark beside the event nest) | Section 6.1; the generated module places only the nest today |

## 14. Open questions for the user (one at a time, later)

| # | Question | Default if unanswered |
| --- | --- | --- |
| S1 | Corral slots 5 to 8: the rising Esencia ladder only, or also a convenience offer for the same slot? | Ladder only, until the user says otherwise |
| S2 | Does a hit in the Pradera use the kids rule of section 5.5, or the forest's exact loss rule? | Kids rule |
| S3 | Does la Nube nap at Night (Night safe east, worst west), or stay awake all cycle? | Naps |
| S4 | Do other players see your Nube faint, or not at all? | Faint |
| S5 | May the storm egg's 300 s hatch be shortened for Robux (reopening `wildbound-incubator.md`)? | No, until the user says otherwise |
| S6 | Is the name Pradera Arcoíris, or another? | **Answered 2026-11-10: Pradera Arcoíris, with La Nube Gruñona as the beast and La Abeja Reina as the event beast** |
| S7 | Is the event egg the "Huevo Real" hatching Relampino, or should the event Legendaria become a bee-themed creature? | Huevo Real, Relampino |

## 15. What is not verified

Nothing in this document has been measured: no instance or part budget on a device, no telegraph timing with a child, no readability of the strike ring, of the Abeja's lane or of the two-egg tells on a phone in sunlight, no test of whether a child reads "freeze when she turns", no corral rate or price against the simulator, no phone taps, and no Studio run of the generated module. The claim that a fixed 6-stud ring plus a 1.0 s telegraph is always escapable is arithmetic at walk speed 16 on flat ground; slopes, lag and a thumb on a phone are the tests that would falsify it. The thumbnail descriptions are of 420-pixel images, not of the models inside.

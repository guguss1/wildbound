# Kids biome concept, beast first: La Abeja Reina and the Pradera Zumbona

**Status: concept only. Nothing here is approved, built, imported, simulated or played.** Written 2026-11-09 from the user's direction of the same day (one open world, a safe social hub in the centre, La Silueta's forest to the west, a bright biome for kids to the east, joined side by side). Every number is a hypothesis to test; every Spanish name is a proposal the user can rename. No monetization is implemented or authorized by this document.

Angle of this concept: the **beast comes first**. La Abeja Reina (a huge, smiling bee that hunts by sound, and whose honey slows you) is designed first, and the meadow, its creatures and its rules are built around what she needs to be fair, readable and funny for a seven-year-old.

## 1. What this concept rests on (verified in the repo, with paths)

| Fact | Where | Why it matters here |
| --- | --- | --- |
| Atmosphere rows are `{ density, offset, haze, fogStart, fogEnd }` per zone and time, plus a per-time light row `atmosphere, fog, ambient, outdoor, ambientWeight, brightness, exposure, flashlight`; keys are Day, Dusk and Night, and Dawn is only a blend back to Day | `src/wildbound/WildboundAtmosphere.luau:8-29` | Section 3 writes the Pradera rows in the same shape. A real Dawn row needs a Dawn key added to `KEYS`, a code change this document does not authorize |
| Forest rows are dark on purpose: open Day fogEnd 140, Night fogEnd 60, Night ambient (22, 28, 46), brightness 0.4 | `WildboundAtmosphere.luau:9-21` | The Pradera must sit far above these on every axis, so a child never reads it as "the scary side" |
| Lumipol adult is 3 x 2 x 2.4 studs; a cria is 0.55 of an adult; species are primitives until an upload is approved | `src/wildbound/WildboundSpecies.luau:20-34` | The five creatures in section 5 are authored at that scale |
| Fair-strike warning lead is 0.8 s; Silueta's telegraph is 0.9 s; chase memory, give-up 100, strike only inside the territory | `src/wildbound/WildboundFairStrike.luau:14`; `WildboundWorldRules.luau:17-28` | La Abeja Reina inherits every gate and uses a longer telegraph |
| Hiding is a pure module: a hidden player cannot be acquired or struck; discovery needs a dwell near the spot | `src/wildbound/WildboundHide.luau:6-21`, `:83-97` | Bell flowers reuse it unchanged |
| Hunt policy is per quarry with a 0.4 s scan and a challenger switch | `src/wildbound/WildboundSiluetaHunt.luau` | The bee's hunt reuses the policy; only the observation ("heard" instead of "seen") changes |
| One home, one fog rectangle, one night scope `"Fog"`, abilities limited to Flashlight and LumipolPulse | `WildboundWorldRules.luau:20`, `:115-120`, `:147-156`, `:227` | A second biome needs rule changes, not data. Listed in section 11 as implications, not authorizations |
| The camp currency is Esencia in player text; the code id is still `ember`; it is never lost and never purchasable | `WildboundEconomyConfig.luau:31`; commit `8d17be6` | Section 5 earns Esencia; nothing here makes it purchasable |
| No AFK path: no quantity grows from time alone (AFK-1, AFK-2) | `docs/mechanics/wildbound-economy-p0.md:409-422`; `WildboundEconomyConfig.luau:252-257` | A corral that earns per minute conflicts with this contract. Section 5.3 proposes how to keep both, and flags it as a user decision |
| Other biomes exist only as offline planners and kits: `tools/plan_<biome>_layout.py`, `tools/build-<biome>-kit.py`, JSON, SVG, PNG, never wired to Studio | `tools/plan_living_forest_layout.py:1-15`; `docs/design/wildbound-expansion-bible.md` sections 5.1 to 5.8 | The Pradera follows the same pattern (section 12) |
| Fog Forest plan: 207 instances, 74,996 triangles, **never measured on a device** | `docs/design/wildbound-expansion-bible.md:25` | Budgets below are caps under that plan and are unmeasured |

Originality check: the bee, the meadow, the creatures and every name below are new. No existing game's characters, names or mechanics are reused; the "hunts by sound" idea is a general one and is given its own look (a queen who cannot see well and listens with her antennae) and its own rules.

## 2. Identity

| Item | Proposal |
| --- | --- |
| Biome name (Spanish, player-facing) | **Pradera Zumbona**. Alternatives if the user prefers: Pradera Miel, Campo de las Campanillas |
| Prefix (assets, code) | `PZ_` |
| One line | A warm, rolling flower meadow where everything is round and bright, a giant smiling bee rules the far hill, and the whole game is about being quiet, not being brave |
| Mood against the forest | The forest hides things in mist and darkness; the Pradera hides nothing. You always see the bee. What you control is how much noise you make |
| Core verbs for a child | Walk softly, listen, hide in a flower, splash through water, collect, bring home |
| What never happens here | No darkness, no fog wall, no damage, no defeat screen, no blood, no jump scare, no sudden appearance, no chase music. Even with the private damage mode on, this biome deals none |
| Sector | 400 x 400 studs east of the hub (section 10). Walk across about 25 s at 16 studs/s |
| Budget (hypothesis, unmeasured) | 190 instances, 40,000 triangles, under the forest plan on purpose |

## 3. Palette ramps, in the WildboundAtmosphere row style

Three zones, like the forest's `open`, `fog` and `camp`: `pradera` (the open meadow), `colmenar` (the bee's ground, the last 110 studs around the hive, a little golden with pollen haze) and `porton` (the gate strip that blends into the hub). Rows are `{ density, offset, haze, fogStart, fogEnd }`. Every row keeps `fogEnd >= 400` and `density <= 0.36`, so the far side of the sector is always visible; the forest's playable floors (`fogStart 15, fogEnd 45`) are irrelevant here because nothing comes near them.

```lua
-- Proposal, not code. Same shape as WildboundAtmosphere ROWS. Night is cozy blue, never black.
local PRADERA_ROWS = {
	pradera  = { Day = { 0.20, 0.32, 0.5, 140, 1000 }, Dusk = { 0.26, 0.28, 0.9, 110, 700 },
	             Night = { 0.32, 0.22, 1.1, 80, 480 },  Dawn = { 0.24, 0.30, 0.8, 120, 800 } },
	colmenar = { Day = { 0.28, 0.26, 1.2, 90, 600 },   Dusk = { 0.32, 0.24, 1.4, 80, 520 },
	             Night = { 0.36, 0.20, 1.5, 70, 420 },  Dawn = { 0.30, 0.26, 1.3, 90, 560 } },
	porton   = { Day = { 0.22, 0.30, 0.6, 120, 900 },  Dusk = { 0.28, 0.26, 1.0, 100, 640 },
	             Night = { 0.34, 0.20, 1.2, 75, 440 },  Dawn = { 0.26, 0.28, 0.9, 110, 720 } },
}
```

Light rows (RGB 0 to 255, as in `LIGHT`). `ambientWeight 1` everywhere because the place's own Ambient is tuned for the forest. The flashlight stays off by day and is a soft lamp at night; fireflies and lantern flowers do the lighting.

| Time | atmosphere | fog | ambient | outdoor | brightness | exposure | flashlight (brightness, range, angle) | Feel |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Day | 255, 244, 214 | 236, 232, 204 | 150, 158, 150 | 176, 184, 168 | 1.6 | 0.15 | 0, 40, 60 | Honey-yellow sun, soft white haze, long views |
| Dusk | 255, 196, 150 | 240, 190, 170 | 138, 118, 132 | 160, 136, 150 | 1.2 | 0.05 | 0.8, 40, 60 | Peach and lilac, flower lanterns start to glow |
| Night | 120, 150, 215 | 96, 122, 190 | 72, 84, 128 | 84, 98, 146 | 0.85 | 0 | 1.5, 40, 60 | **Cozy blue**: a storybook night, stars, fireflies, the hive glows warm. Everything still readable at 400 studs |
| Dawn | 255, 214, 190 | 244, 220, 208 | 128, 128, 140 | 150, 148, 160 | 1.3 | 0.1 | 0.3, 40, 60 | Pink and cream, dew sparkles |

Comparison the user asked for: forest Night ambient is (22, 28, 46) at brightness 0.4; Pradera Night ambient is (72, 84, 128) at 0.85, about three times brighter, and fogEnd 480 against the forest's 60. `REDUCED_BLEND` is not needed here; the Pradera is already the reduced mode.

Material palette (hex, one material per part, as in `build-forest-kit.py`). Neon hex values are starting points: the forest found `F08C2E` rendered yellow (`odd/tasks/fog-forest-visual-kit.md:65`), so every Neon value is checked in a capture.

| Name | Hex | Used on |
| --- | --- | --- |
| `PZ_Grass` | `8FD35A` | Meadow ground, hills |
| `PZ_GrassDeep` | `5FAE48` | Clover rings, shade under sunflowers |
| `PZ_Petal_Pink` | `F5A3C7` | Bell flowers, Pompón |
| `PZ_Petal_Blue` | `7FB8F0` | Bell flowers, stream flowers |
| `PZ_Petal_Yellow` | `FFD54A` | Sunflowers, the bee's stripes (calm) |
| `PZ_Honey` | `F2A33A` | Honey pools, the honey shelf, the bee's stripes (hunting) |
| `PZ_Wax` | `F7E3A1` | Hive tower, log hives |
| `PZ_HiveBrown` | `B8793A` | Hive tower bands, the bee's dark stripes |
| `PZ_Bark` | `9A6B45` | Log hives, gate posts, toadstool stems |
| `PZ_Stone` | `B9B5A6` | Stepping stones |
| `PZ_Water` | `7FD6E8` | Stream and dew pools (box parts, not meshes) |
| `PZ_Neon_Pollen` | `FFE27A` | Pollen puffs, event egg glow, the bee's antenna tips |
| `PZ_Neon_Firefly` | `BFFF9A` | Lantern flowers at night |

## 4. Terrain and prop vocabulary

Terrain: three soft hills (4 to 9 studs high, slopes walkable without jumping), one stream crossing the sector north to south with two fords and four stepping-stone lines, a shallow dew pool near the gate, and the hive hill in the east. Water is a 12-stud strip that slows walking to 10 studs/s (the Living Forest rule, `wildbound-expansion-bible.md:77`), washes honey off in 1 s, and **the bee never crosses it** (section 6). Paths are 14-stud trails of lighter grass, not dirt.

Props follow the kit rules of `wildbound-expansion-bible.md` 5.1 and the tests of 5.2 (one mesh object, one material, pivot at ground, Neon parts own their mesh, FBX from Blender). Eight props, one more than the other kits because the gate belongs to this biome.

| Asset | Size (studs) | Tris | Parts: material (tris) | Form | Tags and clearance | Extra tests |
| --- | --- | --- | --- | --- | --- | --- |
| `PZ_GiantSunflower` | 10 x 10 x 22 | 420 | Stalk: PZ_GrassDeep (120); Leaves: PZ_Grass (120); Face: PZ_HiveBrown (60); Petals: PZ_Petal_Yellow (120) | Thick straight stalk, two big leaves, a wide flat face turned toward the path. The landmark tree of the meadow | `occluder` stalk 2 x 2, height 14 (blocks the bee's line to a hidden child only for sight checks that other systems may run; hearing ignores it) | O1; face min Z 14 |
| `PZ_BellFlower` | 7 x 7 x 9 | 360 | Stem: PZ_GrassDeep (80); Bell: PZ_Petal_Pink or PZ_Petal_Blue (220); Clapper: PZ_Neon_Pollen (60) | A hanging bell as big as a child, open at the bottom. **Hide spot** (reuses `WildboundHide`); the clapper glows while someone is inside | `hide` point at (0, 0, 0.5); clear inside 4 x 6 | Interior free of triangles; clapper is the only Neon part |
| `PZ_CloverRing` | 16 x 16 x 0.6 | 140 | Clover: PZ_GrassDeep (110); Dew: PZ_Water (30) | A ring of four-leaf clovers around a bare circle. **Refugio** (safe ring): no stings, honey off, stamina regen x2 | `walk` top Z 0.6; `tiny` 0.8; `safe` radius 8 | W1, N1 |
| `PZ_HoneyPool` | 12 x 12 x 0.8 | 120 | Honey: PZ_Honey (90); Rim: PZ_Wax (30) | A glossy puddle of honey with a wax rim. Walking in it slows to 9 for 4 s after leaving (`Pegajoso`) and makes a loud squelch (noise 55) | `walk` top Z 0.8; `tiny` 1.0; `hazard` honey | W1, N1 |
| `PZ_LogHive` | 8 x 6 x 7 | 300 | Log: PZ_Bark (180); Wax: PZ_Wax (80); Drip: PZ_Honey (40) | A hollow log with wax combs spilling out one end. Gather point for Cera | `gather` at (0, -3, 2.5) | R1 |
| `PZ_PollenPuff` | 4 x 4 x 3 | 90 | Puff: PZ_Neon_Pollen (70); Stem: PZ_GrassDeep (20) | A round glowing dandelion head. Gather point for Polen; gathering it puffs a visible cloud (noise 40) | `gather` at (0, 0, 2.5); `tiny` 3.2 | R1, N1 |
| `PZ_Toadstool` | 5 x 5 x 4 | 110 | Cap: PZ_Petal_Pink (70); Stem: PZ_Wax (40) | A squat mushroom stool, step-on height. Children climb these to see over flowers | `walk` top Z 4 | W1 |
| `PZ_FlowerArch` | 30 x 14 x 18 | 540 | Posts: PZ_Bark (240); Vines: PZ_Grass (180); Flowers: PZ_Petal_Pink, as a second object `PZ_FlowerArch_Flowers` (120) | Two trunks with a vine lintel heavy with flowers. **Portón de Flores**, the east gate of the hub | clear 16 x 11; limit 32 x 16 | P1, P2 |

The hive itself, `PZ_HiveTower` (30 x 30 x 40, 900 tris: Wax body in stacked rounded tiers, HiveBrown bands, one Neon_Pollen doorway), is a single landmark built once, like the forest's ruin, not a kit prop placed by the planner.

Planned mix for the sector (hypothesis, sums to 190 instances and about 36,000 triangles): 22 sunflowers, 18 bell flowers, 6 clover rings, 8 honey pools, 10 log hives, 70 pollen puffs, 54 toadstools, 1 arch, 1 hive tower. Pollen puffs and toadstools are tiny and cheap, so the count can look high while the budget stays low.

## 5. Five cute creatures

All at Lumipol scale (adult inside 3 x 2 x 2.4 studs, cria 0.55), round bodies, big eyes, flat shading, one Neon part each, R1 rigs (4 to 7 bones). Rarity names are the four the user asked for. "Band" is the spawn distance band from the hive, reusing the W2 rule of the approved plan (Común > 120 studs, Rara 80 to 120, Épica 45 to 80, Legendaria < 45).

| Species | Rarity | Band | Silhouette and colours | Behaviour (one sentence) | Esencia on banking (proposal, mirrors `creatureEmberByTier`) | Earns in the corral |
| --- | --- | --- | --- | --- | --- | --- |
| **Pompón** | Común | Pradera | A pink fuzzy ball with two stub feet, one antenna and a Neon_Pollen nose | It rolls toward anyone who stands still near flowers and sneezes a puff of pollen that the bee hears | 6 (plus the 4 first-steal bonus, like the forest) | 0.5 / min |
| **Trebolín** | Común | Pradera | A four-leaf clover with legs, a dewdrop for an eye, deep green with a Neon_Firefly dew | It flips its own leaf over itself and freezes whenever it hears someone sprint, so it teaches "quiet" by example | 6 | 0.5 / min |
| **Caracolimón** | Rara | Colmenar edge | A snail with a lemon-yellow shell, a soft Neon_Pollen rim and sleepy eyes | It moves slowly and leaves a slippery trail that children slide along, which is loud but fun | 10 | 1.0 / min |
| **Mariposol** | Épica | Colmenar | A butterfly whose wings are two sunflower faces, brown body, Neon_Pollen wing dots | Its wings open toward the sun and fold shut at Night, so it is only catchable by day, inside the bee's ground | 14 | 2.0 / min |
| **Rocionela** | Legendaria | Jardín (event only) | A tiny cloud-sheep, cream and pale blue, with a Neon_Firefly rain fringe | It only hatches from the Huevo de Jalea Real (section 8) and drizzles dew wherever it walks | 22 | 4.0 / min |

Abilities (each needs code; none exists, as the bible notes for every ability):

| Species | Ability | Effect | Duration, cooldown | Downside | Does not solve |
| --- | --- | --- | --- | --- | --- |
| Pompón | Estornudo | A noise lure (noise 60) at a spot 25 studs away, so the bee flies there | Instant, 45 s | Your own noise stays | A bee already diving |
| Trebolín | Pasito | Owner's walk noise 30 becomes 20 | 8 s, 40 s | Owner cannot sprint while it runs | Jump landings and failed captures |
| Caracolimón | Baba | A 10-stud slippery strip the owner slides along at 20 studs/s | 6 s, 60 s | Sliding is loud (noise 55) | Steering while sliding |
| Mariposol | Girasol | Marks the bee's hearing circle on the ground for everyone nearby | 6 s, 45 s | Owner glows, so other players see where you are | Making you quieter |
| Rocionela | Llovizna | Washes honey off the owner where they stand | Instant, 90 s | Puts out your flashlight lamp for 10 s at Night | A second sting |

### 5.1 Why rare is not simply better here

Pompón's lure is the single most useful tool against the bee and it is Común. Rocionela is Legendaria because it is hard to get, not because it wins: Llovizna does what any stream does for free. Mariposol shows information that a careful child already reads from the bee's face. This keeps the user's rule that the free path is always viable.

### 5.2 Capture methods (one thumb, no sub-frame timing)

| Species | Method | Window |
| --- | --- | --- |
| Pompón | Stand still within 10 studs for 5 s; it rolls to you; tap | 5 s stillness, like the Lumipol calm meter |
| Trebolín | Walk, never sprint, to within 4 studs; tap before it flips (it flips 1 s after any sprint it hears within 20 studs) | No timer |
| Caracolimón | Follow its trail to the end, where it rests; tap | No timer, 30 s session |
| Mariposol | Wait until its wings open fully (a 3 s cycle), then tap; tapping on closed wings makes it flutter 10 studs away | 1.5 s open window, every 3 s |
| Rocionela | Hatch the event egg at the hub incubator; it is never wild | None |

### 5.3 The corral and the AFK contract (needs a user decision)

The user's direction says creatures earn Esencia for their owner. Today the economy has a contract that nothing grows from time alone (AFK-1, AFK-2). A corral that pays per minute breaks that contract as written. Proposal to keep both the direction and the spirit of the contract:

| Rule | Proposal |
| --- | --- |
| Who produces | Only creatures placed in the owner's corral at the hub (4 slots at start) |
| When | Only while the owner is in the server and alive. Nothing accrues offline |
| Fed first | A creature produces only after the owner feeds it one Polen at the corral prompt ("Dar polen"), which opens a 20-minute production window. One gathered material, one server-observed action, one window |
| Cap | Each creature stores at most 20 minutes of output ("Panal lleno"). The owner must walk to the corral and hold "Recoger Esencia" to bank it |
| Rates | The table above. A full starter corral of two Común, one Rara and one Épica makes 4 Esencia per minute, against about 7 per minute for the balanced forest archetype in the simulator (`wildbound-economy-p0.md:448-452`), so active play stays the main income |
| Simulation | `tools/simulate_economy.py` gains a `corral` input before any number is trusted; the 180 s expedition floor must still hold |

The rates are a hypothesis. If the user wants a pure idle corral instead, the AFK contract and its tests change, and this document must say so.

## 6. The beast: La Abeja Reina

### 6.1 Look

A queen bee the size of a small bus: body 14 studs long, 9 studs tall at the thorax, wingspan 20, hovering 6 studs over the grass. Round, soft shapes: no stinger drawn (she "bumps", the sting is implied by the honey), no fangs, no claws. A huge calm smile under two big half-closed eyes, a crown of wax, antennae with glowing pollen tips. Her stripes are her mood meter: `PZ_Petal_Yellow` and `PZ_HiveBrown` when calm, shifting to `PZ_Honey` orange when she hears you. Four stubby legs tucked up like a sleepy cat. She is **always visible**: no transparency, no fog, no streaming trick. Measured guardian budgets are 1,288 triangles and 18 bones for La Silueta (`wildbound-expansion-bible.md:28`); she gets 1,400 triangles and 14 bones (Root, Body, Head, Crown, AntL, AntR, WingFL, WingFR, WingBL, WingBR, Leg x4).

### 6.2 What she senses: sound, never sight, never camera

She hears. The server samples every player's position at 5 Hz and derives a noise radius from what they did, exactly the Yeti proposal's shape (`wildbound-expansion-bible.md:275-279`), never a client report:

| Action | Noise radius (studs) |
| --- | --- |
| Standing still, or crouch-walk "De puntillas" (HUD toggle, server sets speed 8) | 0 |
| Walking at 16 | 30 |
| Sprinting at 24 | 55 |
| Jump landing | 70 |
| Failed capture, Caracolimón slide, honey pool squelch | 55 to 80 |
| Pompón sneeze, gathering a pollen puff | 60, 40, at the puff's position |

A player inside her hearing circle is "heard" this step. Hearing replaces `visible` in `Hunt.step`; the hunt policy (memory, challenger switch, give-up) is reused as is.

### 6.3 Where she lives and when

| Rule | Proposal |
| --- | --- |
| Home | The hive tower, east hill of the sector |
| Ground (`colmenar`) | 110 studs around the hive. She hunts only there and strikes only there, like `HOME_LEASH` |
| Pursuit leash | 130 studs. She may follow a heard child a little way out but never sting outside her ground |
| Never | Across water, into a clover ring, through the Portón de Flores, into the hub |
| Day, Dusk, Dawn | Awake: slow patrol loops over the hive garden at 7 studs/s |
| Night | **Asleep** in the hive doorway, snoring visibly ("Zzz" particles), stripes pale. Her hearing radii are halved and she wakes only for noise 55 or more within 25 studs, for 20 s, then goes back to sleep. Night is the safe time here, the mirror of the forest where Night is the worst time |

Per-player hunter, like the approved F2 for La Silueta: one Abeja Reina instance per player (`MAX_HUNTERS` 8), bound to its owner, faint to others. For a seven-year-old this means "the bee that chases me is mine", and a sibling cannot lead it onto them.

### 6.4 The hunt, step by step, and why it stays fair

| Phase | What she does | What the child sees and hears | Time |
| --- | --- | --- | --- |
| Tranquila | Patrols, hums a low tune | Yellow stripes, eyes half closed, smile | until heard |
| Te oyó | Stops, antennae snap toward the sound, one "?" puff over her head, stripes turn orange | Chip: **Te oyó**. Hum stops, one short "¡hm!" | 1.0 s, no movement |
| Te busca | Flies toward the last heard point at 10 studs/s (below walk 16, above crouch 8), memory 4 s | Chip: **Te busca**. Buzz rises in pitch with her closeness, never in volume | up to 12 s |
| ¡Zum! (telegraph) | Within 9 studs of a heard child: hovers still, rises 3 studs, stripes pulse orange, a 6-stud-wide lane is drawn on the grass to the child, the ground ring turns honey-colour, the buzz pitch climbs to a whistle | Chip: **¡Zum!** plus the lane. Target-only warning with acknowledgement (gate C) | **1.2 s**, above the 0.8 s floor and Silueta's 0.9 s on purpose, because the audience is younger |
| Picotazo | Dives along the lane at 20 studs/s for at most 12 studs, cannot turn | A soft "¡Plof!" and a honey splat | 0.6 s |
| Después | Hovers 2.5 s, dizzy stars, wide open; a second telegraph needs 2.5 s (`ATTACK_COOLDOWN` reused) | Chip clears | 2.5 s |
| Se rinde | 3 s with nothing heard: a shrug, "¿?" puff, slow circle for 4 s, then home at 7 | Chip: **Te perdió** | 7 s |

Fairness math (calculated, not measured): stepping out of the 3-stud half lane takes 0.19 s at 16 studs/s and 0.33 s at the honey speed of 9, against a 1.2 s telegraph. Her search speed 10 is below walking 16, so a child who simply walks away is never caught; the only way to be stung is to keep making noise near her, and the honey makes that a lesson, not a punishment. Every fair-strike gate of the forest applies (persistent model, dwell, target-only warning with acknowledgement, staged consequence, preload); a failed gate cancels the sting and counts it.

### 6.5 Consequence: honey, never damage

| Sting | Consequence | Recovery |
| --- | --- | --- |
| First | **Pegajoso**: honey covers the child, walk speed 9 for 6 s (kept above 8 so the shared `carrySpeed > 8` contract holds), yellow drips on the screen edge instead of any red, and **one bag item drops** (never pouch materials, the D6 rule). She carries the dropped item to the **Estante de miel**, a shelf on the hive, where it waits 120 s | Water washes honey off in 1 s; a clover ring or the hub washes it on entry; Rocionela's Llovizna washes it anywhere. The item is recovered by walking to the shelf, quietly |
| Second, while still Pegajoso | **Vuelo de vuelta**: she scoops the child up and flies them to the Portón de Flores in 4 s, giggling. Carried bag items drop where the sting happened and wait 120 s. No health change, no defeat screen, no loss summary of "lost" things: the summary says **where** things are | Walk back. Honey is gone on arrival |

Nothing is ever destroyed by the bee. The cost is time and a walk, which is what a seven-year-old can understand and a parent can accept.

### 6.6 How she is escaped or sent home

| Counterplay | How | Free? |
| --- | --- | --- |
| **Quieto** | Stand still (no movement, no jump) for 3 s: silence, so she loses you. The HUD teaches it once: "Si no te mueves, no te oye." | Yes, always |
| **De puntillas** | Crouch-walk at 8 makes no noise; slower than her 10, so it is for sneaking, not fleeing | Yes |
| **Agua** | She never crosses the stream or the dew pool; wading washes honey off | Yes |
| **Campanilla** | Enter a bell flower (hide spot, `WildboundHide` rules: not while seen, 45 s max, 8 s cooldown). She cannot hear inside; she finds you only by dwelling at the bell, which she does only if you were heard entering | Yes |
| **Anillo de trébol** | A clover ring is a Refugio: no stings, honey off, stamina regen x2. The hub is one big ring | Yes |
| **Distracción** | Pompón's Estornudo, or a crafted **Tarro de miel** (recipe below) thrown up to 20 studs: she lands on it and eats for 8 s, stripes back to yellow | Pompón is Común; the jar needs Cera and Polen, both gathered outside her ground |
| **Cansarla** | Three distractions, or being led over water twice, in one hunt: she yawns, says "Uf", and flies home to nap for 60 s. Chip: **La Reina se fue a dormir**. This is the biome's "win" against the beast, with no violence | Yes |

Flashlight has no effect on her, so the forest's tool does not transfer; that is deliberate, so each side teaches its own trick.

### 6.7 Profile shape, following `WildboundWorldRules.luau:147-156`

```lua
-- Proposal only; `detectionRange` is her hearing circle for a walking player, the noise table scales it.
AbejaReina = table.freeze({
	name = "AbejaReina", specialBehaviorId = "AbejaReina", visualScaleKey = "ABEJA_VISUAL_SCALE",
	base = table.freeze({ speed = 10, detectionRange = 30 }),
	night = table.freeze({ scope = "Colmenar", speed = 10, detectionRange = 15, asleep = true }),
}),
```

`asleep` and a `"Colmenar"` scope are new keys, so this needs rule changes and contracts first, as the bible says for every new guardian.

## 7. How a seven-year-old reads the threat without horror

| Cue channel | Calm | Heard you | Looking for you | ¡Zum! | Lost you | Asleep |
| --- | --- | --- | --- | --- | --- | --- |
| Face | Smile, eyes half closed | Eyes wide, "?" puff | Eyebrows down, cheeks puffed, still smiling | Eyes shut tight, cheeks huge | Shrug, "¿?" puff | Eyes closed, "Zzz" |
| Stripes | Yellow and brown | Orange flash once | Orange | Orange pulsing | Fading to yellow | Pale yellow |
| Sound | Low hum | Hum stops, "¡hm!" | Buzz pitch rises with closeness | Whistle | Sigh | Snore |
| Ground | Nothing | Nothing | Her hearing circle shown faint (Mariposol makes it bright) | Honey ring and 6-stud lane | Nothing | Nothing |
| HUD chip (Spanish, with icon) | none | **Te oyó** (ear icon) | **Te busca** (eyes icon) | **¡Zum!** (lightning icon) | **Te perdió** (check icon) | **Duerme** (moon icon) |

Rules for the cues: every state is readable with sound off (face plus chip plus ground), with colour off (shape plus text), and on a phone (chip is the existing `WildboundHudView` chip budget). Fear is replaced by comedy: the dizzy stars, the "¡Plof!", the giggle on the flight back. No camera shake, no screen darkening, no heartbeat audio; `WildboundFear.client.luau` effects are off inside the Pradera. The honey screen edge is the one "hit" feedback and it is yellow and silly.

## 8. The special biome egg event: Huevo de Jalea Real

Follows the approved W3 shape (every 20 minutes, first at minute 5, visible 5 minutes, one claimant, banner plus distant call).

| Item | Proposal |
| --- | --- |
| Banner (Spanish) | "¡Huevo de Jalea Real en la Pradera Zumbona!" with a small bee icon; a distant trumpet-like buzz from the hive direction |
| Where | One of three Legendaria points inside the **Jardín de la Colmena**, the flower ring within 45 studs of the hive tower, chosen at random |
| What it looks like | A cream egg with a honey-gold cap and a `PZ_Neon_Pollen` glow, on a wax pedestal, visible from 200 studs |
| What changes while it is up | La Abeja Reina circles the Jardín tightly at 7 (patrol radius 30 instead of her usual loop), so noise discipline is the whole challenge. At Night she stays asleep but the Jardín is lit so it is visible |
| Carrying it | An egg in the bag at the egg walk speed of `wildbound-capture.md`; the honey rule and the drop rule apply. The egg is the one thing she never carries to the shelf: it drops where you stand and waits 120 s, so the event stays claimable |
| Banking | At the hub incubator; it hatches **Rocionela** (Legendaria), the only way to get her |
| Esencia | 22 on banking (Legendaria row), plus the event banner credit on the wave board |

## 9. Materials, recipes and the biome's place in the economy

Three gathered materials, mirroring Fogbark, Glowmoss and Nightbloom, with the risk gate inverted: the rare one is a **day** material inside the bee's ground, because that is when she is awake.

| Material | Where | Carried as | Use |
| --- | --- | --- | --- |
| Polen | Pollen puffs, everywhere; 85 % in the open meadow | Pouch | Feeds the corral; Tarro de miel |
| Cera | Log hives, mostly in the colmenar | Pouch | Tarro de miel; Botas de trébol |
| Jalea | Jardín de la Colmena only, Day, Dusk and Dawn only (she is awake) | Bag item, one slot per bundle | Tier 2 skills of the Pradera branch; the egg event pedestal accepts one Jalea for a 30 s "calm" that makes her nap, once per event |

| Recipe | Cost (hypothesis) | Effect |
| --- | --- | --- |
| Tarro de miel | 6 Cera, 6 Polen | Throwable lure, 8 s eat, one use. Cap 3 |
| Botas de trébol | 20 Cera, 10 Polen, 40 Esencia | Permanent: walk noise 30 becomes 22 |

Where the user's monetization direction would sit **in this biome, as design only**: corral slots 5 to 8 (free at rising Esencia cost 60, 150, 350, 800, or a convenience offer), incubator speed for the Huevo de Jalea Real, and hats for Pompón. Every one of them is a shortcut on a free path that exists; none is a wall, none is random, none changes the bee's rules or the sting. No purchase, product id or price is implemented or authorized by this document; `monetization` stays `"none"` in the tuning JSON until the user sets up Creator Hub, `ProcessReceipt` and saved progress, and DataStore is currently forbidden.

## 10. How the biome joins the hub: the east gate

The user's direction is one open world: hub in the centre, forest west, Pradera east, joined side by side. Coordinates below are a proposal in a new world frame where the hub centre is the origin; the existing forest geometry would be re-based west, which is a planner task, not a Studio task.

| Element | Proposal |
| --- | --- |
| Hub safe circle | Radius 45 at (0, 0): incubator, corral, trophy display, shops and skill board, no hunters of any kind |
| **Portón de Flores** | `PZ_FlowerArch` at (70, 0), facing east, 16 x 11 clear. The forest's west gate is its mirror (a dead-tree arch at (-70, 0)) |
| Transition strip | x 70 to 110: the `porton` atmosphere rows blend by x from the hub rows to the `pradera` rows, so the sky warms as you walk east and cools as you walk west. One sunflower every 15 studs lines the trail so the biome is visible from the hub |
| Sector | x 110 to 510, z -200 to 200. Hive tower at (430, -40). Jardín within 45 of it. The stream runs from (260, -200) to (300, 200) with fords at z -60 and z 90 |
| First-minute hook | A guaranteed Común egg (Pompón) within 40 studs east of the gate on server open, so the first catch happens in about 15 s, the K1 to K4 hook of the forest |
| Band distances | Measured from the hive, as W2: Común beyond 120, Rara 80 to 120, Épica 45 to 80, Legendaria under 45 |
| Safe rings | 6 clover rings placed by the planner, never inside the colmenar, re-rolled on the 5-minute wave clock like the forest's Refugios (W4); the one nearest the gate is fixed |
| Bee leash at the gate | Her 130-stud pursuit leash ends 190 studs short of the arch, so she is never seen near the hub |
| Sound carries both ways | A failed capture in the strip is heard by nobody dangerous; the forest's Silueta is a sight hunter and the bee is far. The strip is the quiet middle |

Zone functions today are hard-coded to one fog rectangle and one home (`WildboundWorldRules.luau:115-120`). A biome-aware `zone(x, z)` that returns `{ biome, band, safe }` is the first rule change this concept needs; the forest's existing contracts must stay green through it.

## 11. Code implications (not authorizations)

| Need | Where it lands | Why |
| --- | --- | --- |
| Dawn key in atmosphere | `WildboundAtmosphere.luau` `KEYS` | Section 3 has a real Dawn row; today Dawn is a blend to Day |
| Biome-aware zones, second home, second leash | `WildboundWorldRules.luau` | One home and one rectangle today |
| Hearing observation | A new pure module, `WildboundNoise.luau`, feeding `Hunt.step` in place of `visible` | Server position samples at 5 Hz, as section 6.2 |
| Sleep state, `asleep` key, `"Colmenar"` scope | `WildboundWorldRules.luau` profiles, `WildboundGuardianBrain.luau` | Section 6.3 |
| Honey consequence, Estante de miel, Vuelo de vuelta | `WildboundFairStrike.luau` staged consequence, `WildboundState.luau` drop rules | Section 6.5. Damage stays off here even in private damage mode |
| Corral production with fed windows and a collect prompt | `WildboundState.luau`, `WildboundEconomyConfig.luau` via the tuning JSON, `simulate_economy.py` | Section 5.3; the AFK contract is the user's call |
| Species data | `WildboundSpecies.luau` gains five looks with a `rarity` field (the approved W2 adds the field) | Section 5 |
| Every number in the dev tuning schema | `WildboundTuningSchema.luau` | Project rule for all new constants |

## 12. What to build next, in the offline pattern

1. `tools/plan_pradera_zumbona_layout.py` and `tools/test_pradera_zumbona_layout.py`: the planner from section 4 and 10, writing `assets/maps/pradera-zumbona-layout/pradera-zumbona-layout-v1.json`, SVG and PNG, standard library only, with a seed, following `tools/plan_living_forest_layout.py`. Tests: instance and triangle caps, the clover rings outside the colmenar, the stream never inside the Jardín, the hive at least 190 studs from the arch, the first-minute egg within 40 studs of the gate, every hide spot at least 8 studs from a honey pool.
2. `tools/build-pradera-zumbona-kit.py` and `tools/test_pradera_zumbona_kit.py`: the eight props of section 4 under the bible's G1 to G14 tests plus the conditional ones named per row.
3. `tools/build-species-rigs.py` gains the five species specs; `tools/build-guardian-rigs.py` gains `GD_AbejaReina`.
4. `tools/simulate_economy.py` gains the corral, Polen, Cera and Jalea, and must keep the 180 s greedy floor.
5. Toolbox proposals via `search_asset` (free only, ids only from results, screenshots for the user) for a bee, a sunflower and a bell flower, as placeholders until the kit exists. No insertion before the user picks.

## 13. Open questions for the user (one at a time, later)

1. Biome name: Pradera Zumbona, Pradera Miel or Campo de las Campanillas.
2. Corral production: fed 20-minute windows collected by hand (keeps the AFK spirit), or a pure idle corral (changes the AFK contract and its tests).
3. Telegraph 1.2 s for the bee, or the forest's 0.9 s for parity.
4. Night sleep for the bee (Night is the safe time east, the dangerous time west), or awake all cycle.
5. Whether the Pradera's fear effects are simply off, or a softer set exists for older children.

## 14. Unverified

Everything above. In particular: no atmosphere row has been rendered, so the "cozy blue" night is a number, not a look; no budget was measured on any device; no child has played anything; the 1.2 s telegraph, the honey speed 9, the noise radii, the corral rates and the recipe costs are untested; the hearing model's cost at 5 Hz for eight per-player bees is uncalculated; and whether a seven-year-old reads "stand still to escape" as fun or as unfair is exactly the thing only a playtest can answer.

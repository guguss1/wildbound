# Wildbound forest aesthetic reference (research, read-only)

Date: 2026-11-09. Status: research and proposal. Nothing here is approved, built, inserted or committed.

The user likes the look of the first forest map of *99 Nights in the Forest* (Grandma's Favourite Games) and wants Wildbound's fog forest to learn from it without being a copy. This note (1) records what reads well in that reference and why, as hypotheses, (2) lists what Wildbound already has, (3) proposes an original direction that adds to it, (4) gives a build plan for a later "Forest look" writer, and (5) lists free toolbox candidates found read-only with `search_asset`.

Per `AGENTS.md`, screenshots and video advice are hypotheses to test, not requirements. No model, name, character, music or UI of the reference is to be copied; the reference only informs proportions, contrast and prop vocabulary, and everything proposed below is authored in our own kit.

## 0. Sources and what could not be verified

Public web sources fetched on 2026-11-09 (text only; this agent could not view the game's stills or video frames, so every visual claim is marked V = verified in text, or H = hypothesis from the game's publicly circulated look that the user should check against a real screenshot):

- Roblox games API, `https://games.roblox.com/v1/games?universeIds=7326934954`: title "99 Nights in the Forest", creator group Grandma's Favourite Games (verified), genre Survival, 25 players per server, description "Build a camp with friends. Something is watching you." (V)
- Experience page `https://www.roblox.com/games/126509999114328` (same title, creator and description). (V)
- `https://games.gg/es/99-nights-in-the-forest/`: calm days in quiet clearings under clear skies, shadows deepen at night, the campfire is the refuge and main light, flashlights and torches stun or repel the Deer and the Owl, abandoned cabins and structures, players plant trees around camp as walls, "light and sound, not just the Roblox block style" build suspense. (V)
- `https://rblxguide.com/games/99-nights-in-the-forest/updates/map-locations-guide`: the campfire is the permanent safe zone the Deer will not enter while it burns, the crafting bench, base furniture and farm plots sit at camp, rescued children's tents appear at the campfire, the Forest is the hub connecting other biomes, landmarks include a Watchtower, a Fishing Cabin near water, Abandoned Pillars, a Mineshaft and locked caves, chests spawn through the forest, a crafted map shows the campfire and biome borders. (V)
- `https://rblxguide.com/games/99-nights-in-the-forest/updates/beginner-guide-survive-day-1-10`: the forest is dark at night and the campfire is the only safe place; players watch the sun and return before dark; the Deer is unkillable, 35 walkspeed, flashlight beams stun it; hunger bar drains constantly; sack capacity in slots. (V)
- `https://rblxguide.com/games/99-nights-in-the-forest/locations`: Abandoned Pillars and a Windmill are tagged Forest; the campfire is "reliably present". (V)
- `https://rblxguide.com/games/99-nights-in-the-forest/updates/99-nights-the-forest-wakes-up-update-2026`: seven new default structures gave the map "noticeably more density", a Sawmill, improved Dilapidated Building. (V)
- `https://www.kinzoo.com/blog/is-99-nights-in-the-forest-safe-for-kids-a-parents-age-by-age-guide`: "a towering deer creature resembling the Wendigo", "No blood, no gore", eerie audio, nights "considerably creepier". (V)
- `https://www.gosugamers.net/entertainment/news/77777-99-nights-in-the-forest-how-this-endless-roblox-game-had-me-addicted-in-2025`: no flashy visuals or big budget, open-world forest, upgrading the campfire expands the map, the base grows from a bare shack, about one real hour per hundred days. (V)
- Fan recreations on Sketchfab (`.../99-nights-in-the-forest-nature-assets-08123c7e...`, CC BY 4.0, and `.../99-nights-in-the-forest-trees-rocks-and-bush-49df725e...`): a tree, rock and bush set at 132 triangles and 88 vertices. Weak, second-hand evidence that the vocabulary is tiny-poly. (V for the counts, not for the game's own meshes)
- CGTrader fan model of the Deer (search snippet only): tagged stylized, cartoon, creepy, about 5,460 polygons. (snippet, unverified)

Could not be fetched (blocked for this agent: HTTP 402/403/405): the Fandom wiki (`99-nights-in-the-forest.fandom.com`, including Biomes, Forest and Campfire pages and the raw/api endpoints), Sportskeeda guides, ExitLag's guide, Printables and MakerWorld fan tree models. No image, video frame or in-game screenshot was viewed. Everything marked H below is therefore a hypothesis about tree silhouettes, canopy shapes, trunk proportions, palette by time of day, ground texture and UI layout, written from the game's widely shared look, and must be checked by the user against a screenshot before a writer builds on it.

## 1. What reads well in the reference, and why (hypotheses)

1. **One warm point in a cold field.** Every source agrees the campfire is the refuge, the main light and the return point (V). Visually that means a single warm, saturated pool against a desaturated blue-green forest, so the player can always find "home" by value and hue alone, no HUD needed. The fire grows when upgraded (V), so the beacon scales with progress. Hypothesis: the warm/cold split is the single strongest readability device in the game.
2. **Day is safe and legible, night is near-blind.** Days are calm clearings under clear skies; at night shadows deepen and the forest is dark (V). The contrast between phases is large, which makes the sun's position a mechanic (players watch it to return in time, V). Hypothesis: the day palette is flat, bright and slightly pastel; the night palette is a deep blue-black with the campfire and flashlight as the only sources, so the fear is darkness rather than detail.
3. **Tiny-poly props, big silhouettes.** Fan recreations are 100-200 triangles per set (V), guides describe the look as blocky with light and sound doing the work (V). Hypothesis: trees are two-material props (bark + one flat canopy colour), canopies are either stacked cones or one-to-three rounded faceted lobes, trunks are short and thick relative to the canopy (about 1:3 to 1:4 trunk height to total height), with the trunk visible as a clean dark column so an axe target reads from far away. The silhouette carries the tree, not shading or texture.
4. **Props are verbs.** Logs and stumps come from chopping, berry bushes feed, chests reward, tents mark rescued children at camp (V for chests, tents, chopping and food). Hypothesis: almost every prop in the first map is interactable or a trace of an interaction, which keeps the vocabulary short (trees, stumps, logs, rocks, bushes, chests, cabins, tents) and makes the world legible: if it is there, it means something.
5. **Landmarks are tall and sparse.** Watchtower, Windmill, Abandoned Pillars, Fishing Cabin near water, Mineshaft, locked caves (V). Hypothesis: each landmark is a different silhouette class (tower, blades, columns, hut on water, dark hole), spaced so one is visible from most clearings, which replaces a minimap for first-time players.
6. **Horror by absence and scale.** "Something is watching you" (V), a towering deer creature (V), no gore (V), cultist chants heard between the trees (V). Hypothesis: the forest itself stays friendly-looking; the dread comes from darkness, sound and one oversized silhouette, not from gore props. This is compatible with Wildbound's kids-plus-horror brief.
7. **UI stays small and bottom-anchored** (H): a hotbar of item slots, a hunger bar, a day counter; large flat icons on dark rounded panels that survive a phone screen. Unverified beyond "hunger bar" and "sack slots" (V).

## 2. What Wildbound already has

Mapped read-only from the repo on 2026-11-09:

- **Fog Forest kit (FK_, six props)** authored in Blender by `tools/build-forest-kit.py`: `FK_Evergreen` (tiered spruce skirt on a crooked spine), `FK_DeadTree` (forked crown, snapped pale tip), `FK_FallenLog` (torn end, shelf fungi), `FK_RootArch`, `FK_RuinDoorway`, `FK_LanternMarker` (stake, crossarm, hanging lantern and empty cage). Exports in `assets/exports/forest-kit/*.fbx`. Palette (sRGB): Pine `2B4034`, Bark `4C3226`, Moss `6B7036`, Charcoal `55585D`, PaleWood `BE9C70`, Fungus `A06A3A`, Rope `9C8152`, Iron `2C2D30`, LanternGlass `F08C2E` (emission 0.75). One mesh per material, pivot at ground level, 1 unit = 1 stud.
- **Layout** from `tools/plan_forest_layout.py` (seed 20261107, `forest-layout-v1`): 207 instances (130 evergreens, 42 dead trees, 17 logs, 1 root arch, 1 ruined doorway, 16 lanterns) on a 400 x 400 map; fog rectangle x -45..165, z -165..35; guardian home (0, -85) with an 80-stud leash; camp at (-140, 140) with a 35-stud safe circle; the 14-stud route camp -> clearing -> ruin -> nest -> marsh -> shelter. Cover trunks are placed first around the nest; only `FK_Evergreen_Trunk` and `FK_DeadTree_Wood` block sight (`docs/maps/wildbound-p0.md`).
- **Dressing** by `tools/dress-wildbound-forest.luau` from `ServerStorage.WildboundAssets.ForestKit` templates and `ServerStorage.WildboundForestLayout` (exported by `tools/export_forest_layout_luau.py`), tested by `tests/WildboundForestDress_Test.luau` (24/24).
- **Camp** (`Builder.buildCamp`): a 40-stud sand disc, refuge hut with canvas roof, four display pedestals, chest, upgrade board with lantern, incubator, two lantern posts, six shadowless warm lights RGB 255,176,96. Kit lanterns carry a PointLight RGB 255,165,85, brightness 1.0, range 18 (16 of them, cold-reading against the camp).
- **Atmosphere** (`src/wildbound/WildboundAtmosphere.luau`, tests in `tests/WildboundAtmosphere_Test.luau`): zones open/fog/camp, keys Day 6-18, Dusk 19, Night 20-29, Dusk 29.5, Day 30 (dawn reuses the Dusk row). Dread-pass fog: open Day density 0.68 / fogEnd 140, Night 0.82 / 60; fog zone Night 0.88 / 48; camp Night 0.72 / 100. Colours: Day fog 150,158,152 and atmosphere 170,176,170; Dusk fog 58,58,74; Night fog 14,18,28 with ambient 22,28,46. Playable floors fogStart 15, fogEnd 45. Flashlight is a head SpotLight, brightness 0 by day and 5 at night.
- **Living Forest kit (LF_)**, biome 2, offline only (`tools/build-living-forest-kit.py`): Broadleaf, LogBridge, HollowArch, ResinStump, TrailPost, StreamStone, FlowerClump; warm palette, no fog (`docs/design/wildbound-expansion-bible.md`). Never imported.
- **Horror actors** that the look must serve: La Silueta (tall, grin when hunting, per-player in the approved plan), sleeping parents at nests, fair-strike telegraph >= 0.8 s, hide spots (bushes), Lumipol cover rule (canopies never block sight).

What is missing against the reference: no broadleaf or pale tree family in the fog forest (only one evergreen and one dead tree), no ground-level prop layer (stumps, rocks, mushrooms, bushes, wood piles), no Dawn key, no camp-hub silhouette beyond primitives, no horror accents in the kit, and no biome-variant tints (Niebla, Escarcha, Ceniza, Floración) for the 5-minute wave clock.

## 3. An original direction for Wildbound's forest

Working name: **"Bosque de los Veladores"** (the watchers' forest). Three ideas make it ours rather than a copy: the forest is *tall and leaning* (everything bends toward the route, as if listening), the night has *two* lights instead of one (the warm camp and a cold teal fungus glow that marks the way back but never means safety), and the horror leaves *traces* (claw marks, empty nests, abandoned camps) in a forest that otherwise looks gentle.

### 3.1 Three tree families, each with its own silhouette

| Family | Role | Silhouette (phone-readable at 40 studs) | Trunk | Materials | Sight rule |
| --- | --- | --- | --- | --- | --- |
| **Pino Velador** (revised `FK_Evergreen`) | Wall and lookout. Edge ring and dense fog interior. | Very tall and narrow: height 26-34, three or four offset skirts, the top skirt always leaning 6-10 degrees toward the nearest route segment (the "listening" lean). Boughs end in long points so the outline is a serrated spindle, never a cone. | Clean dark column 3-4 wide at eye height, visible for 7+ studs under the first skirt so it reads as a trunk, not a bush. | Bark `4C3226`, Pine `2B4034`, a lighter Pine tip `3B5A44` on the top skirt only (new) | Trunk blocks sight (as today). |
| **Roble Encorvado** (new `FK_HunchOak`) | Cover and hide. Clearings, nest approaches, route bends. | Short and wide: height 14-18, one heavy lopsided canopy made of three to five faceted lobes that overhang one side like a shoulder, canopy underside always a darker band so it reads as a roof. Knuckle roots on the heavy side. | Thick, leaning, 4-5 wide, splits into two limbs under the canopy. | Bark `4C3226`, Oak leaf `556B3A` (new, warmer than Pine so the two families separate by hue, not only by shape), Moss `6B7036` on the heavy side | Trunk blocks sight; the canopy never does (Lumipol cover rule). The overhang is a planned hide shadow at night. |
| **Abedul Pálido** (new `FK_PaleBirch`) | Threshold marker. Grows only inside and at the edge of La Silueta's territory and around the biome-event point. | Thin and tall: height 18-24, pale trunk with dark bands, two or three small high canopies, often in clumps of three with one snapped. By night the pale trunks are the brightest non-emissive thing in the fog, so the player learns "pale trunks = her ground" without a sign. | 1.5-2 wide, PaleWood `BE9C70` with Charcoal `55585D` bands. | PaleWood, Charcoal, sparse Pine canopy | Does not block sight (too thin), so it never breaks the nest sight lanes. |

`FK_DeadTree` stays as the dead state and becomes the **Ceniza** variant of the other families (see 3.5), not a separate family.

Why three: the reference reads with essentially one friendly canopy type (H); Wildbound needs three because each family carries a gameplay meaning (wall, hide, warning). This is the main point where we add rather than copy.

### 3.2 Palette ramps by time of day (consistent with the horror fog)

All colours sRGB. The forest base colours stay fixed on the props; the ramps live in `WildboundAtmosphere.luau` (fog/atmosphere/ambient) plus one new per-time canopy tint applied client-side to the canopy materials only (never to trunks, so sight blockers never change value). Day and Night keep the dread-pass densities; only colours and a new Dawn key are added.

| Key | Clock | Fog colour | Atmosphere colour | Ambient / outdoor | Canopy tint (multiply) | Camp light | Intent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Day | 6-18 | 150,158,152 (keep) | 170,176,170 (keep) | place's own (keep) | 1.00, 1.00, 0.96 | 255,176,96 at brightness 0.6 | Grey-green mist, flat and calm; the camp fire is barely needed. |
| Dusk | 19 | 92,74,84 (warmer than today's 58,58,74) | 120,96,100 | 46,52,66 / 54,60,76 (keep) | 0.92, 0.80, 0.78 | 255,160,80 at 1.0 | A short mauve hour so the player sees the light leave; the canopy goes brick-dark before the fog goes blue. |
| Night | 20-29 | 14,18,28 (keep) | 40,48,64 (keep) | 22,28,46 / 26,32,52 (keep) | 0.55, 0.62, 0.75 | 255,150,70 at 1.4 | Near-blind blue. Two light families: warm camp and lanterns, cold teal fungus (3.3). |
| **Dawn** (new key at 29.5, replacing the Dusk reuse) | 29.5-30 | 150,140,136 | 176,168,160 | 58,56,60 / 70,66,66 | 1.00, 0.94, 0.88 | 255,176,96 at 0.8 | A pale peach-grey with long haze (haze 4.0, fogEnd 110 in open): the fog lifts before the colour returns, which is the relief beat after a night. |

Rules: fog zone keeps `FOG_ZONE_DARKEN` 0.92; the playable floors (fogStart 15, fogEnd 45, ramp 3) are untouched; `reduced` mode keeps the flashlight untouched as today. Dawn is a new key, so `KEYS` becomes Day 6, Day 18, Dusk 19, Night 20, Night 29, Dawn 29.5, Day 30.

### 3.3 Our own prop set (ground layer)

All authored in `tools/build-forest-kit.py` style: faceted, one mesh per material, pivot at ground, no textures, no third-party geometry.

| Prop | Look | Gameplay meaning | Count target |
| --- | --- | --- | --- |
| `FK_AxeStump` | Low stump with a wedge cut and a split, pale heartwood ring, moss on the north face | Reads as "someone was here"; seat at camp; spawn-graph `height` 1 point for eggs | 30 scattered, 8 at camp as seats |
| `FK_MossBoulder` (3 sizes) | Faceted boulder, flat top, moss cap `6B7036` dripping on one side; Charcoal body | Sight cover at eye height only on the large size (CanQuery on for L), spawn point (rocks) | 40 |
| `FK_LanternFungus` | Cluster of five to nine flat-capped fungi on a log or root, caps emissive teal `3FB8A6` at 0.35, stems PaleWood | The second night light: breadcrumbs along the route every 30-40 studs, never inside the territory, so cold light means "path", warm light means "safe" | 24 |
| `FK_BerryThicket` | Round faceted bush 5 x 4, dark leaf `2F4A33`, eight to twelve berry spheres `8E2A3A` (dark red, not candy) | Hide spot (existing bush rule), gather node | 36 |
| `FK_WoodPile` | Five short logs stacked under a lashed rope | Camp dressing and material node | 6 at camp, 4 at the shelter |
| `FK_RopeMarker` | Short stake with a rope ring and one wooden tag | Route hint between lanterns by day (lanterns carry the night) | 20 |
| `FK_CollapsedHide` | Old hunter's hide: two leaning poles, torn canvas `9C8152`, a rotten crate | Landmark in the open zone; a story beat ("others tried") | 2 |

### 3.4 Horror accents (traces, not gore)

- **Claw marks** (`FK_ClawMark`, geometry not decal): three parallel gouges of PaleWood set 0.1 into trunk faces at 4-6 studs height, only on trees within 60 studs of La Silueta's home and on one tree per Refugio approach. Pale on dark bark, so the flashlight finds them first.
- **Bone piles** (`FK_BonePile`): a few long faceted bones and one small round skull of an unknown animal (never a deer, never human), PaleWood with Charcoal shadow, set in the grass by pale birches. Three near the heart of the territory.
- **Abandoned camps** (`FK_ColdCamp`): a ring of Charcoal stones with grey ash, a fallen lantern (glass unlit, `FK_LanternMarker` variant with emission 0), a torn pack. One in the fog zone, one by the marsh. These are the negative of the player's camp: same shapes, no light. That contrast is the horror.
- **Empty nests**: the existing nest shapes without eggs, moss-grown, as decoys inside the territory.
- **Hanging charms** (`FK_Charm`): short rope with three small wooden tags and a feather, on branches of the hunched oaks near the ruin; they turn slowly (client tween) so the stillness has one moving thing.
- **The lean.** Every tree inside the fog zone leans 4-8 degrees toward the route; outside, trees stand straight. Players will not consciously see it, but the fog zone will feel wrong.

### 3.5 Biome variants on the 5-minute wave clock (phase 1: tints only)

| Variant | Fog colour shift | Canopy tint | Ground accent | Extra |
| --- | --- | --- | --- | --- |
| Niebla (default) | as 3.2 | as 3.2 | none | fungus glow 0.35 |
| Escarcha | +12 blue, -8 red | 0.86, 0.92, 1.00 | frost rims (PaleWood emission 0.1 on skirt tips) | fungus glow 0.2, breath particles off by default |
| Ceniza | -10 all, warmer | 0.70, 0.62, 0.58 | `FK_DeadTree` swaps in for 20 % of oaks | lantern glass redder `E0702A` |
| Floración | +6 red, +4 green | 1.00, 0.96, 1.00 | `FK_BerryThicket` gains pale blossom spheres | fungus glow 0.5 |

Geometry does not change between variants except the Ceniza swap, so the spawn graph and sight lanes stay valid.

### 3.6 Camp hub treatment

- Keep the 40-stud sand disc and the six warm lights, and add a real **fire**: a stone ring of eight Charcoal blocks, three crossed logs, a faceted flame (three nested emissive cones, `F08C2E` and `FFD27A`, scaled by a 0.9-1.1 flicker on Heartbeat) and a smoke column of six slow particles visible from 150 studs by day. The smoke is the day beacon; the glow is the night beacon.
- Two **Pino Velador gateposts** at each route exit, lanterns hung between them, so leaving camp always passes under a frame (the "threshold" beat the arch and doorway already do deeper in).
- Eight `FK_AxeStump` seats in a ring at 6 studs from the fire, two `FK_WoodPile`, the existing refuge, board, chest, display and incubator.
- Camp canopy rule: no canopy over the disc, so the warm light pools on sand and the sky stays open; the forest edge starts at 22 studs with hunched oaks (dark undersides facing the fire), so the camp is a bright bowl in a dark ring.
- Camp light stays RGB 255,176,96; the kit lanterns stay 255,165,85 at range 18 so they read as "ours but colder"; fungus is the only teal.

### 3.7 Phone readability rules

- Every prop must be identifiable as a 48-pixel silhouette on a 375-pixel-wide screen at 40 studs in Night fog (fogEnd floor 45). Test by rendering the kit sheet at 1/8 scale and checking the three families and seven props are still distinguishable by outline alone.
- Three value bands per prop at most (trunk, canopy, accent). Canopy undersides are always the darkest band so trees read as volumes against fog.
- Hue separates families: Pine (blue-green), Oak (yellow-green), Birch (pale). Never rely on texture or small detail.
- Only two emissive colours exist in the forest: warm `F08C2E` family (camp, lanterns) and teal `3FB8A6` (fungus). Teal never appears inside the territory; warm never appears outside camp, shelter and the lantern line.
- No prop smaller than 2 studs in any axis except berries and tags, which are accents on a larger prop.
- Any new client tint runs once per key change, not per frame; the flame flicker is the only per-frame effect and runs on the camp model only.

## 4. Build plan for the later "Forest look" writer (after the user picks)

Route: delegated writer, TDD RED -> GREEN, work-unit commits on `codex/wildbound-first-playable`, no Studio edits without the user's instance confirmation, no uploads without approval.

1. **Kit geometry** (`tools/build-forest-kit.py`, `tools/test_forest_kit.py`): add `FK_HunchOak`, `FK_PaleBirch`, `FK_AxeStump`, `FK_MossBoulder_S/M/L`, `FK_LanternFungus`, `FK_BerryThicket`, `FK_WoodPile`, `FK_RopeMarker`, `FK_ClawMark`, `FK_BonePile`, `FK_ColdCamp`, `FK_Charm`; revise `FK_Evergreen` (taller, offset skirts, lean parameter); add palette rows Pine tip `3B5A44`, Oak leaf `556B3A`, Dark leaf `2F4A33`, Berry `8E2A3A`, Teal glass `FK_Neon_FungusGlass` `3FB8A6` emission 0.35. Tests: closure, triangle budget (trees <= 900 tris, ground props <= 300), pivot at ground, one mesh per material, trunk core radius measured for `PROPS`, no vertex below 0. Export FBX to `assets/exports/forest-kit/`, update `forest-kit-upload-manifest.json`, regenerate the sheet and lineup PNGs. Uploads to Roblox remain a user decision.
2. **Layout** (`tools/plan_forest_layout.py`, `tools/test_plan_forest_layout.py`): add `PROPS` rows from the new kit report; add regions and counts (`OAK_COUNTS` at route bends and nest approaches, `BIRCH_COUNTS` inside the territory and a 20-stud band outside it, ground layer counts from 3.3); fungus breadcrumb rule (30-40 studs apart along the route, never inside the territory, never within 10 studs of a lantern); claw marks only within 60 studs of home; lean field toward the route inside the fog rectangle. Keep the invariants: no solid inside the 10-stud route clearance, patrol loop walkable, nest sight lanes E/N open and S/W blocked, canopies never query. Bump to `forest-layout-v2` and keep v1 on disk.
3. **Export and dress** (`tools/export_forest_layout_luau.py`, `tools/dress-wildbound-forest.luau`, `tests/WildboundForestDress_Test.luau`): extend the template list and the query whitelist (`FK_HunchOak_Trunk`, `FK_MossBoulder_L_Rock` query on; everything else off); lean applied as pitch toward the layout's `lean_deg` field; fungus and cold-camp lanterns carry their own PointLight rows (teal range 12, brightness 0.6; cold camp none). Tests: counts per prop, query set, light counts and colours, camp disc has no canopy, pivot clearance from routes.
4. **Atmosphere** (`src/wildbound/WildboundAtmosphere.luau`, `tests/WildboundAtmosphere_Test.luau`): add the Dawn key and row set from 3.2, keep floors and reduced-mode contracts, add `Atmosphere.variant(name)` returning the fog shift and canopy tint from 3.5, and `Atmosphere.canopyTint(clockTime, variant)`; the world client applies the tint to canopy materials only. Tests: Dawn blends from Night to Day without crossing the floors, variants are pure and freeze-safe, trunk colours never change, unknown variant falls back to Niebla. Every new number goes in the dev tuning schema.
5. **Camp** (`tools/build-wildbound-p0-map.luau`, `tests/WildboundP0Map_Test.luau`): fire ring, flame, smoke, stump seats, wood piles and gateposts under the existing 20-stud and 8-stud spacing rules, lights still 4-8 warm shadowless, no new collider within 5 studs of spawn. Flame flicker on a client script bound to the camp model.
6. **Play check** (Studio MCP, user-confirmed instance, screenshots to `assets/exports/forest-kit/captures/`): day, dusk, night, dawn and each variant from the camp and from the nest; phone preset in the device emulator; check the three families separate at 40 studs, the teal line reads at night without competing with the camp, claw marks are visible under the flashlight, and frame time stays within the current budget with 300+ instances.
7. **Docs**: update `docs/maps/wildbound-p0.md` (dressing totals, query set), `docs/ui/wildbound-world.md` (Dawn and variant rows with captures), and the feature document in `odd/tasks/` with route, trigger evidence and commits.

Estimated authored changed lines: kit 700-900, layout 250, dress 150, atmosphere 120, camp 200, tests 400; so this is three or four work-unit commits and will exceed the 400-line delivery heuristic. Recommend `ask-on-risk` with slices kit -> layout+dress -> atmosphere+camp.

## 5. Free toolbox candidates (read-only search, for the user to pick)

Searched 2026-11-09 with `search_asset` (scope `creator_store`, free only, Model) on the Studio instance named "Experiencia sin título (placeId 122652861404212)" after `list_roblox_studios`; a second instance with no name was listed and not used. Nothing was inserted; no `execute_luau`, no Play. Thumbnails came from `https://thumbnails.roblox.com/v1/assets?assetIds=<id>&size=420x420&format=Png` and are saved under `assets/exports/toolbox-candidates/`. These are reference or placeholder options; the direction in section 3 is to author our own kit, so any pick here should be a stand-in for a prop we have not built yet, and each must be opened and inspected in Studio (parts, scripts, licence text) before use. Every ID below is copied from a search result; none was invented.

| Role | assetId | Name | Creator | Free | Thumbnail | Notes from the thumbnail and description |
| --- | ---: | --- | --- | --- | --- | --- |
| Stylized trees | 8559395722 | Low-Poly Pine Trees Asset Pack | Cliosow | yes | `forest-trees-8559395722.png` | Four-tier faceted spruce with flat skirts, two greens, short trunk; closest to the Pino Velador read. Description says it includes snowy variants (useful for Escarcha). |
| Stylized trees | 8973577087 | Low Poly Pine Tree Set | spinmaster243 | yes | `forest-trees-8973577087.png` | Tall, very narrow serrated spruces with dark trunks and a textured dark green; three heights. The "spindle" silhouette this note proposes. Textured, so check material count. |
| Stylized trees | 137855240779954 | Low Poly Dead Tree Horror Forest Spooky Decor Pine | Voltbe0854 | yes | `forest-trees-137855240779954.png` | Single-mesh dead tree, 20 x 23 x 18 studs, forked clawed limbs; a Ceniza stand-in. We already have `FK_DeadTree`, so only if the user wants a second dead silhouette. |
| Rocks / logs | 2128776869 | Low Poly Rock Pack [FREE] | FracturedSkies | yes | `forest-rocks-logs-2128776869.png` | Ten faceted grey rocks, two values, clean silhouettes. Description asks for credit. Good moss-boulder reference. |
| Rocks / logs | 85389927254160 | Low Poly Stylized Rock Pack | FatihSultanMehmed44 | yes | `forest-rocks-logs-85389927254160.png` | A very large grid of rocks in grey, brown, blue-grey and mossy tints; heavy as a whole model, pick a few. |
| Rocks / logs | 5273429987 | Low Poly Tree, Log, Debris, Bush and Stump | B0boYah | yes | `forest-rocks-logs-5273429987.png` | Thumbnail renders untextured grey and includes animal shapes, so the contents are unclear; description promises stumps, logs and debris with wedge collisions. Inspect before considering. |
| Mushrooms / foliage | 5345641987 | Low Poly Mushroom Pack | gavinpgamer6199 | yes | `forest-mushrooms-foliage-5345641987.png` | Tall thin-stemmed brick-red caps and small blue-teal clusters; the teal cluster is close to the `FK_LanternFungus` read. "No credit needed" per description. |
| Mushrooms / foliage | 4644085527 | Low Poly Mushrooms | CyrilTBFD | yes | `forest-mushrooms-foliage-4644085527.png` | Three faceted red-cap mushrooms, recolourable per description. Clean low-poly shapes. |
| Mushrooms / foliage | 13411585468 | Low-Poly Mushroom V2 | DinosaurioLOCOOvd0s | yes | `forest-mushrooms-foliage-13411585468.png` | Single smooth red cap with white spots; cartoon and bright, better for Floración or the kids' biome than for the fog forest. |
| Camp props | 11319964899 | Camp fire | MathewOnii | yes | `forest-camp-props-11319964899.png` | Three thick logs on a ring of dark faceted stones with fire and smoke particles; close to the fire ring in 3.6. Check the particle budget. |
| Camp props | 3632483829 | Campfire And Sits | ExtremelyPickle | yes | `forest-camp-props-3632483829.png` | Small stone fire ring plus two notched log benches; the log seats are a quick stand-in for stump seats. |
| Camp props | 14963743762 | Low Poly Lantern | ItzRoVoider | yes | `forest-camp-props-14963743762.png` | Plain black faceted lantern frame, no glass or light in the thumbnail; would need our glass and PointLight. We already have `FK_LanternMarker`. |

Not shortlisted on purpose: several near-identical "Low Poly Camp Tent Campfire" uploads from accounts with generated-looking names, a bush pack from a creator named "model_ripper", and packs by "Content Deleted" creators (the account no longer exists, so licence and provenance cannot be checked). For berry bushes no clean free candidate came up in two searches; authoring `FK_BerryThicket` is the recommendation.

## Recommended direction in five lines

1. Keep the reference's one lesson that matters: a single warm camp against a cold, near-blind forest, with silhouettes doing the work instead of texture.
2. Make it ours with three tree families (tall leaning Pino Velador, hunched cover oak, pale territory birch), each tied to a gameplay meaning.
3. Add a second, cold night light (teal fungus breadcrumbs) that means "path", never "safe", so night navigation is readable on phones without a minimap.
4. Put the horror in traces (claw marks, bone piles, cold abandoned camps, leaning trees, slow charms) inside an otherwise gentle forest; no gore.
5. Add a Dawn key and four wave-clock variant tints in `WildboundAtmosphere.luau` without changing geometry, so sight lanes, spawn graph and economy floors stay valid.

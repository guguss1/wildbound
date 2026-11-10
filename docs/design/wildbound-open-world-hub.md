# Wildbound open world: hub, forest west, Pradera east (design)

**Status: design only, unvalidated. Nothing here is built in Studio, played or measured on a device.** Written 2026-11-09 for the user's direction of the same day: one open world with a permanent safe social hub in the centre, La Silueta's fog forest on the west side and a bright biome for kids on the east side, joined side by side rather than as separate places. Every number is a hypothesis for a later Studio writer and for playtests. No code was changed: section 11 lists the exact changes a writer must make.

The plan is generated, not drawn by hand: `tools/plan_open_world_layout.py` emits `assets/maps/open-world/layout-v1.json` (plus `.svg` and `.png`), and `tools/test_plan_open_world_layout.py` re-derives every rule below from the saved JSON. Run `python -I -B tools/plan_open_world_layout.py` to regenerate and `python -I -B -m unittest discover -s tools -p test_plan_open_world_layout.py` to check it.

## Quick path

| You are | Read |
| --- | --- |
| The user | Sections 1, 2 and 12 (decisions), then the picture `assets/maps/open-world/layout-v1.png` |
| The Studio writer | Sections 2 to 7, then 11 (exact code changes) and 10 (streaming) |
| The economy or monetization designer | Sections 2.3, 9 and 12; this document places things, it prices nothing |
| The Pradera biome writer | Section 4 and `docs/design/wildbound-biome-2-proposal.md` |

## 1. The world in one picture

Frame: studs, origin at the hub centre, x east, z south (the forest planners' convention). The whole world is 1040 x 450 studs ("about 1000 x 450": the extra 40 are the ring road's margin past the two biome squares).

| Piece | Where | Size | What it is |
| --- | --- | --- | --- |
| Hub | circle at (0, 0) | radius 60 (wall at 58) | Permanent safe zone and social centre: spawn, incubator, corral, trophies, Esencia board, skill tree, refuge, chest |
| West transition | x -100 to -60, z -45 to 45 | 40 x 90 | Evergreens thin into grass; fog density ramps from 0 at the hub wall to the forest value at the fog edge (x -135) |
| Forest block | square x -500 to -100, z -200 to 200 | 400 x 400 | The current fog forest, translated by (-300, 0) as one block: layout, islands, relief, hide spots, routes, camp, shelter, fog rectangle and La Silueta's home all move together |
| East transition | x 60 to 100, z -45 to 45 | 40 x 90 | Hub paving breaks into flower clumps and pale grass; warm light ramps up |
| Pradera region | square x 100 to 500, z -200 to 200 | 400 x 400 | The kids' biome (recommended "Pradera Luminosa" with La Abeja Reina, `wildbound-biome-2-proposal.md`), drafted here as a route, an outpost, a beast rectangle and a seed grid; its kit and props come from its own planner |
| Ring road | closed loop at z +/-212 and x +/-510 | 2,860 studs, 14 wide | Beast-free loop around everything, with spokes to the hub (N, S), the forest camp and the Pradera outpost. About 3 minutes to walk all of it |

Walking distances at 16 studs/s: hub west gate to the forest shelter 186 studs (12 s), hub gate to the forest camp 405 studs (25 s), hub east gate to the Pradera outpost 300 studs (19 s), east gate to the tutorial nest 67 studs (4 s).

Why a translation and not a mirror or a rebuild: every forest rule that was measured locally (nest sight lines, lantern rhythm, island wake radii, relief slopes, hide-spot spacing, gather slots, ambush anchors, the economy route of 798 studs) depends only on relative positions, and a translation keeps every pairwise distance (the test `check_islands_relief_and_hide_spots_are_pure_translations` pins this). The cost is that the forest camp ends up on the far side from the hub; section 3 turns that into a feature.

## 2. The hub

Radius 60 is the `Rules.zone` safe circle. Inside: a paved plaza ring (radius 25 to 35) with the spawn in its middle, a station band (radius 36 to 56) and a hedge wall at 58 with four 16-stud gates (W, E, N, S). Four 14-stud spokes run from the plaza ring to the gates. Rules the planner enforces: every station footprint stays inside the band, at least 10 studs from each spoke and at least 8 studs from every other station; the extra spawn pads stay inside the plaza, clear of the default 9-stud spawn pad.

### 2.1 Stations

| Station (player name) | Centre (x, z) | Footprint | Holds | Reuses |
| --- | --- | --- | --- | --- |
| Incubadora | (-32.5, -32.5) | circle r 6 | 3 visible egg slots, prompt "Incubar huevo" | `WildboundIncubator`, the camp incubator (delivery E) |
| Corral | (36.6, -28.6), yaw 128 | 22 x 13 rectangle | 8 pens. Registered creatures idle and hover here so they can be seen by everyone; a pen plaque shows the owner and what the creature earned | Companion looks from `WildboundSpecies.LOOKS`, display pedestals (B4) |
| Refugio | (16.4, -45.1) | circle r 5 | Registration hut: "Registrar criatura", card, equip | `WildboundRefuge`, the camp refuge |
| Cofre | (-15.7, -43.2) | circle r 3 | Storage chest: "Guardar en el cofre" (extraction and banking) | The camp chest |
| Puesto | (-43.2, -15.7) | circle r 4 | Reserved stall marker for the convenience-offer design. No purchase flow, no `MarketplaceService`, nothing for sale | Nothing yet |
| Tablero de Esencia | (-23.0, 39.8), yaw 30 | 8 x 3 board | Esencia balance, what each corral creature earned this session, the wave board top 3 | The camp upgrade board, the planned wave board (G2) |
| Árbol de habilidades | (-39.8, 23.0) | circle r 4.5 | Skill tree kiosk (`Learn`) and upgrades (`Upgrade`) | `WildboundCampView` skills and upgrades |
| Trofeos 1 to 5 | arc r 50, bearings 15 to 75 degrees, south-east | 5 plinths r 2 | Trophy display: first of a species, biome event eggs, PI-1 theft. One plinth per trophy, plaque with owner and date (session-only until M6) | Display pedestals (B4) |

The hub holds the same four sinks as the camp (`Craft`, `Upgrade`, `Learn`, arm and disarm), so the camp's `sinks.campRange` 20 rule becomes "within 20 studs of a hub station or inside the camp circle" (section 11).

### 2.2 Spawn

New characters spawn on the default `SpawnLocation` at the origin (the 12 x 12 pad that `Rules.SPAWN_PAD_*` already protects) or on one of four 4 x 4 pads at radius 16 (bearings 0, 90, 180, 270). **All pads face east**, toward the Pradera: a new player's first sight is the bright side and its tutorial nest 160 studs away, not the fog. The forest gate is behind them, and its sign names it.

### 2.3 Why the social things are here and not at the camp

The user asked for a centre that is social, incubates, keeps creatures visible in a corral and shows trophies. The camp's refuge, chest, board and incubator are duplicated, not moved: the forest camp keeps working as the deep-west outpost (section 3.3), so nothing built so far breaks, and the hub is where the two sides' players meet. Creatures in the corral are the visible proof of progress the user wants for kids; the Esencia they earn for their owner is decided by the economy design, not here. This document only reserves where that is shown (the pen plaque and the board) and where a convenience offer could stand (the Puesto), and builds no purchase.

## 3. West: the forest block

### 3.1 What moves, by how much

`forest_world = forest_local + (-300, 0)`. The JSON files under `assets/maps/forest-layout/` stay in the forest's local frame; the open-world layout carries the translated copies that matter for zone rules and shows the rest as a block.

| Forest fact | Local | World |
| --- | --- | --- |
| La Silueta's home | (0, -85) | (-300, -85) |
| Fog rectangle | x -45..165, z -165..35 | x -345..-135, z -165..35 |
| Territory (leash 80) | reaches x 80 | reaches x -220 |
| Chase leash 100 | reaches x 100 | reaches x -200 |
| Camp safe circle r 35 | (-140, 140) | (-440, 140) |
| Shelter safe circle r 22 | (105, 125) | (-195, 125) |
| Islands I1..I5 | (-95, 75) ... (60, -135) | (-395, 75) ... (-240, -135) |
| Ambush anchors, gather slots, relief segments, hide spots, patrol diamond, pillars | as today | each +(-300, 0) |

The fog rectangle's east edge (x -135) stays 75 studs from the hub wall and 35 studs from the west transition, so the hub never sees fog and La Silueta never has a reason to look at it.

### 3.2 The forest threshold ("Umbral del Bosque")

The connector `umbral_oeste` runs hub west gate (-60, 0) → (-100, 20) → the shelter (-195, 125), 186 studs, entirely outside the fog rectangle (tested). So a player entering the forest from the hub reaches a safe circle with the capsule before any fog, and from the shelter the existing route continues to the marsh (island 3) or, the long way, to the camp (island 1). Two spokes complete the block: `espolon_campamento` from the camp (-440, 140) straight south to the ring road, and the ring itself.

These roads cut through the forest's edge-wall trees. The planner lists exactly which props go, with the 10-stud clearance the forest planner uses: `FK_Evergreen_086`, `FK_Evergreen_093`, `FK_Evergreen_119`, `FK_FallenLog_017`, `FK_LanternMarker_006` (threshold) and `FK_Evergreen_092` (camp spoke). 201 of 207 props stay; the ring road touches none. The dress script removes them the way the island planner's `removedTrees` list does.

### 3.3 The first steal on the west side

New players spawn at the hub, 340 studs from island 1. The forest keeps its tutorial island where it is, and gains a second Safe-tier hook near the threshold: **"Claro del Umbral"** at (-115, -60), 81 studs from the forest gate (5 s), outside the fog, with 16.9 studs of clear floor around it (the planner searched the forest's east strip for the spot nearest 85 studs from the gate with at least 16 studs to every prop footprint and 20 to every road). It is a Lumipol nest with island 1's rules (first-capture only, meter capped at 95 during the first steal, wake 12 / 15). Island 1 keeps its data and serves players who come round by the ring road or the camp. The forest camp becomes "Campamento del Bosque", the deep outpost: it still registers, banks, incubates and sells, and the ring road spoke makes it reachable without crossing the fog.

## 4. East: the Pradera region

A 400 x 400 square so both sides are the same size, with the biome itself free to use 300 x 300 of it as the biome-2 proposal drafts. Everything below is a draft for the Pradera planner and uses forest-shaped rules so one `Rules` module can hold both sides.

| Element | World | Note |
| --- | --- | --- |
| Gate | (100, 0) | End of the east connector (60, 0) → (100, 0), 40 studs |
| Draft route loop | gate (100, 0) → brotes (150, -45) → arroyo (215, -110) → colina (300, -150) → nido (400, -60) → estanque (420, 60) → outpost (330, 130) → pradera (200, 100) → gate | 898 studs, 56 s; the same shape as the forest loop: safe nest first, the beast's ground as a short cut, a long safe road home |
| Tutorial nest "Prado de los Brotes" | (150, -45) | 67 studs from the gate (4 s), Safe tier, species pending the creature design; the east first-steal hook |
| Outpost safe circle r 22 | (330, 130) | The Pradera's shelter: capsule banking, a lantern ring; spoke to the ring road |
| Beast home | (400, -60) | Deep east, 340 studs from the hub wall |
| Beast rectangle | x 300..495, z -165..60 | The analog of the fog rectangle: the beast roams, clamps and may strike only inside it. The biome proposal recommends a 60-stud territory; this layout keeps 80 (the forest value) as the conservative band and the writer sets the smaller one if the user picks it |

The region's west half (x 100 to 300) has no beast at all. That is the kids' tutorial ground: tutorial nest, flower fields, Común and Rara seeds.

## 5. Transitions and the ring road

Both transitions are 40 x 90 bands that are not biome and not hub: one dressing set thins into the other over 40 studs, the ground material blends, and the client lighting region interpolates. Nothing spawns in them except the connector lanterns.

The ring road is the "free world" promise: a 14-stud loop outside both biome squares (every sample of it is outside both beast rectangles and more than 100 studs from both homes, so no beast can hunt or strike on it), with lanterns in the forest's cold amber on the west half and the Pradera's warm pink-white on the east half, alternating sides every 45 to 55 studs like the forest route. Spokes: N and S from the hub gates (152 studs each), the forest camp (72) and the Pradera outpost (82). It is long on purpose: a player who wants to avoid every beast can, slowly; the short way is always through a beast's ground.

## 6. Zones: how `Rules.zone` maps the world

| Question | Today | In the open world |
| --- | --- | --- |
| Safe | camp (-140, 140) r 35 or shelter (105, 125) r 22 | hub (0, 0) r 60, camp (-440, 140) r 35, shelter (-195, 125) r 22, Pradera outpost (330, 130) r 22, plus the active Refugios (a server list, 2-3 discs of radius 8 per side, rerolled on the wave clock) |
| Fog | one rectangle x -45..165, z -165..35 | the forest rectangle x -345..-135, z -165..35 ("fog") and the Pradera rectangle x 300..495, z -165..60 ("roam"); each belongs to one beast |
| Territory | fog and not safe and within 80 of (0, -85) | per beast: inside its rectangle, not safe, within its leash of its home |
| Region | none | `forest` (x < -100), `transition` (-100..-60 and 60..100), `hub` (inside r 60), `pradera` (x > 100), `road` (abs z > 200) |
| Spawn pad | (0, 0) r 9 | unchanged; it is now inside the hub, which is safe anyway |

**Leash bands, or how the two beasts stay on their sides.** La Silueta can strike only inside her territory (x at most -220) and follow a hunt only to her chase leash (x at most -200); her rectangle clamps every goal to x at most -135. The Pradera beast mirrors this from x 300 (chase), 320 (territory) and its rectangle. Between x -200 and 300 lies the beast-free band: the whole hub, both transitions, the Pradera's west half and the entire ring road. The tests pin these numbers (`check_leash_bands`, `check_ring_road`).

## 7. Random Refugios: candidate sets

Rules (W4 of the plan): never inside a territory, so at least 110 studs from a beast's home (the chase leash plus 10); at least 20 studs outside every permanent safe circle and the hub; a disc of radius 8 that stays 15 studs from every road centreline and 9 studs from every forest prop footprint; 20 studs inside the region square; at least 60 studs between candidates of one set. The planner samples a 10-stud grid, picks 9 well-spread points per side (farthest-point sampling from a seeded start) and deals them into three sets of three sorted by bearing, so each set spreads around its region. The server picks a set per wave, then 2 or 3 of its candidates.

| Side | Set | Candidates (x, z) and zone |
| --- | --- | --- |
| West | F-A | FA1 (-460, -10) outside, FA2 (-120, -20) outside, FA3 (-260, 180) outside |
| West | F-B | FB1 (-430, -160) outside, FB2 (-120, 150) outside, FB3 (-380, 120) outside |
| West | F-C | FC1 (-140, -180) outside, FC2 (-240, 60) outside, FC3 (-370, 0) outside |
| East | P-A | PA1 (120, -50) outside, PA2 (480, -180) outside, PA3 (330, 30) roam, beyond the leash |
| East | P-B | PB1 (190, -180) outside, PB2 (480, 20) roam, beyond the leash, PB3 (270, 180) outside |
| East | P-C | PC1 (330, -150) roam, beyond the leash, PC2 (480, 180) outside, PC3 (130, 100) outside |

A Refugio inside a beast rectangle but beyond its chase leash is the "safe path" the economy already relies on (fog beyond the leash); the forest side produced none because its edge strips are the only ground that far from home.

## 8. Spawn-graph seeds (W1 input)

Seeds are candidate spawn points for eggs and crías, tagged for the spawn clock: `kind`, `x`, `z`, `height`, `zone`, `distance_home` and the rarity `tier` by the W2 bands (Legendaria under 45 studs from the beast's home, Épica 45 to 80, Rara 80 to 120, Común beyond 120). None sits inside a safe circle or the hub.

| Side | Count | Kinds | Tiers |
| --- | --- | --- | --- |
| West | 348 | 168 tree bases (4 studs from the pivot toward the route), 126 canopies (evergreens, height 0.6 x tree height), 16 logs, 5 nests (the islands), 33 trail edges (10 studs off the route every 40) | 27 Legendaria, 55 Épica, 68 Rara, 198 Común |
| East | 123 | 122 meadow grid points (30-stud grid, 8-stud jitter, 10 studs off every road) and the tutorial nest | 4 Legendaria, 14 Épica, 20 Rara, 85 Común |

Legendaria and Épica seeds west of x -345 (outside the fog rectangle but within 80 of home) carry `zone: outside`; the spawn clock should filter on both fields. The east grid is a stand-in until the Pradera kit exists; the Pradera planner replaces it with tree, mushroom and log seeds in the same shape.

## 9. The first minute on each side

| Time | East (default) | West (if the player turns round) |
| --- | --- | --- |
| 0 to 5 s | Spawn facing east; the east gate sign and the bright meadow beyond | The west gate sign "Bosque de la Silueta" behind |
| 5 to 15 s | Walk 160 studs: gate, 40-stud transition, 67 studs of flowers to "Prado de los Brotes" | Walk 140 studs: gate, transition, the threshold road, "Claro del Umbral" on the right |
| 15 to 45 s | Steal the first cría with the Gentle windows (island 1's rules) | Same, Lumipol |
| 45 to 90 s | Walk back, register at the hub Refugio, the cría appears in the Corral, +Esencia on the Tablero | Same |
| 90 to 120 s | First upgrade at the Árbol de habilidades; the card teases the next nest | Same; the card names the shelter and island 3 |

Both hooks are 67 and 81 studs from their gates, close to island 1's 88 from the forest spawn that the islands design measured. The hub-to-nest walk adds the 60-stud hub radius, so the first steal lands at about 30 to 50 s instead of 15 to 45; the funnel's "first steal within 60 s" stays the target to measure.

## 10. Streaming and performance

Facts from the code: streaming stays on, `WildboundFlags.streamingMinRadius` is 64 and must equal the place's `StreamingMinRadius`; damage never follows streaming; La Silueta is `ModelStreamingMode.Persistent`. The forest plan is 74,996 triangles and 512 MeshParts, never measured on a phone.

| Setting or budget | Recommendation | Why |
| --- | --- | --- |
| `StreamingTargetRadius` | 420 (default 1024) | From the hub, 420 reaches both transitions and about a third of each region, never both beasts' grounds; 1024 would stream almost the whole 1040-stud world |
| `StreamingMinRadius` | 64, unchanged | The dwell gate reads it |
| `StreamOutBehavior` | Opportunistic | Regions beyond the target radius are released without memory pressure |
| Persistent models | La Silueta, the Pradera beast, the hub stations and signs | Beasts for the fair-strike gates; the hub so a player who spawns never sees an empty plaza |
| Triangle caps | forest 74,996 (plan), Pradera 40,000, hub 12,000, ring road and connectors 6,000 | About 133,000 in the place, under the bible's 240,000 warning; a player streams roughly 60,000 at once with radius 420 |
| Part caps | hub 400 parts, each road segment one part per straight run (8 ring segments, 6 connectors) | Keep the hub cheap: it is always loaded |
| Lighting | client regions by x: forest (x < -100) cold fog rows, hub and transitions neutral, Pradera (x > 100) warm rows; interpolate across the 40-stud transitions | Extends the existing client lighting by region instead of per place |
| Audio | the forest's distant steps and the Pradera ambience each fade to 0 by the hub wall | One mixer, two regions |

What this does not know: phone memory at 133,000 triangles, how a lighting region swap feels in motion, and whether 420 is low enough on low-end devices. Measure at M1.5 before trusting any of it.

## 11. Exact code changes for a later Studio writer (not made here)

Order matters: rules and tests first, then data, then the builder, then Play. Every new constant goes in the dev tuning schema with a default equal to the module's value.

| # | File | Change |
| --- | --- | --- |
| 1 | `tests/WildboundWorldRules_Test.luau` | Update the pins first (observe RED): `HOME_X, HOME_Z` to (-300, -85); the fog rectangle to (-345, -135, -165, 35); the safe circles to the four in section 6; add cases for `Rules.region`, the hub circle and the Pradera beast |
| 2 | `src/wildbound/WildboundWorldRules.luau` | Add `Rules.FOREST_OFFSET_X, FOREST_OFFSET_Z = -300, 0` and `Rules.toWorld(x, z)`; set `HOME_X, HOME_Z = -300, -85`; add `Rules.HUB_X, HUB_Z, HUB_RADIUS = 0, 0, 60`; `Rules.zone` safe = hub or camp (-440, 140) r 35 or shelter (-195, 125) r 22 or outpost (330, 130) r 22 or any active Refugio (`Rules.setRefugios(list)`), fog = the translated rectangle; `clampTerritory` clamps to the translated rectangle; add `Rules.region(x, z)`; add a `BEASTS` table keyed `Silueta` and `Pradera` with `home`, `rect`, `leash`, `chaseLeash`, and make `inTerritory`, `clampTerritory`, `validTarget` and `pursuit` take a beast key (default `Silueta`, so every current call keeps its behaviour) |
| 3 | `src/wildbound/WildboundTuningSchema.luau` | Add `HUB_RADIUS` 60 (40 to 90), `REFUGIO_RADIUS` 8 (6 to 14), `REFUGIO_COUNT` 3 (2 to 3), `PRADERA_LEASH` 80 (40 to 100), `STREAMING_TARGET_RADIUS` is a place property, not tunable |
| 4 | `src/wildbound/WildboundAmbush.luau` | Anchors through `Rules.toWorld` (or add -300 to each x): Home (-300, -85), NestSide (-260, -125), RuinEast (-245, -38), RuinWest (-330, -45), WestHollow (-340, -110), SouthGrove (-260, -140) |
| 5 | `src/wildbound/WildboundIsland.luau`, `WildboundRelief.luau`, `WildboundHide.luau`, `WildboundGatherField.luau` | Read their coordinates through `Rules.toWorld` at load so `WildboundIslandLayout.luau`, the relief module, `hide-spots-v1.json` and the economy JSON's gather `slots` stay in the forest frame and need no regeneration. `tools/export_economy_config_luau.py` and its drift test stay untouched |
| 6 | `src/wildbound/WildboundWorld.server.luau` | `home` already comes from `Rules.HOME_*`; the patrol diamond is relative; the guardian spawn, the show crest and the `clampTerritory` calls pass the beast key. Second guardian instance for the Pradera beast behind the biome's own module when that work lands (F2 per-player hunters apply to both) |
| 7 | `src/wildbound/WildboundServer.server.luau` | Spawn pivot: `campCenter.Position + (0, 4, 10)` becomes the hub spawn pad (`HubCenter` marker) facing +x; `State.atCamp` and the `NotAtCamp` refusals accept "within 20 studs of a hub station or inside the camp circle"; registration and the chest accept the hub `RefugeMarker`/`ExtractionMarker` twins (markers get a `Site` attribute `hub` or `camp`); the corral server fills 8 pens from registered companions (one per owner, newest first, session-only) |
| 8 | `src/wildbound/WildboundText.luau` | New neutral Spanish strings: `Plaza`, `Incubadora`, `Corral`, `Trofeos`, `Puesto`, `Umbral del Bosque`, `Bosque de la Silueta`, `Pradera Luminosa` (pending B1), `Campamento del Bosque`, `Claro del Umbral`, `Prado de los Brotes`, `Refugio temporal`, `Ver corral`, and the gate signs; the `SignKey` attribute pattern of the camp applies |
| 9 | `src/wildbound/WildboundWorld.client.luau`, `WildboundAtmosphere.luau` | Lighting and fog by `Rules.region`; interpolate over the transitions; the Pradera rows from the biome-2 proposal under a biome key |
| 10 | `tools/build-wildbound-p0-map.luau`, `tools/dress-wildbound-forest.luau` | Build the forest as today in its local frame, then `PivotTo` the whole `WildboundP0` root by (-300, 0, 0) before attaching (the forest doc already says `PivotTo`, never `TranslateBy`, for dressed roots); the dress script skips the six removed ids |
| 11 | New `tools/build-wildbound-hub.luau` and `tools/export_open_world_luau.py` | Export `hub`, `connectors`, `ring_road`, `transitions`, `refugio_sets`, `hooks` and `zone_rules` from `layout-v1.json` to a `WildboundOpenWorldLayout` module (same Adler-32 check as the forest layout export); the hub builder reads it: plaza disc, ring, spokes, wall with gates, stations as primitive stand-ins with `CanQuery` and `CanTouch` off and only bases colliding, six warm lights, signs with `SignKey`. `tests/WildboundHub_Test.luau` repeats the planner's three rules (band, spoke clearance, station gap) in Studio |
| 12 | `tools/simulate_economy.py` | The route length it reads (798) is the forest loop and still holds for forest trips that bank at the camp or shelter; add a hub-based trip (threshold to island 3 and back, about 540 studs) and the Pradera loop once its tiers exist; keep the 180 s greedy median floor |
| 13 | Studio place properties | `StreamingTargetRadius` 420, `StreamOutBehavior` Opportunistic, `StreamingMinRadius` 64 (must match `WildboundFlags.streamingMinRadius`); the default `SpawnLocation` stays at the origin |
| 14 | `odd/tasks/wildbound-capture-extraction-horror.md`, `docs/maps/wildbound-p0.md` | Record the block translation and the hub; the forest doc's coordinates are local from then on and say so |

Not in this list on purpose: anything in `MarketplaceService`, DataStore, Developer Products or prices. The Puesto is a marker.

## 12. Decisions for the user

| ID | Decision | Recommendation |
| --- | --- | --- |
| OW1 | Accept the translation (-300, 0) and the hub at the origin with radius 60 | Yes; the forest keeps every measured rule |
| OW2 | Keep the forest camp as a full outpost (register, bank, sell) or make the hub the only shop | Keep it: nothing built breaks and the deep west stays worth a trip |
| OW3 | Spawn facing east (Pradera first) | Yes, for kids; the forest sign is behind them |
| OW4 | Add "Claro del Umbral" as a second Safe nest | Yes; island 1 is 340 studs from the spawn now |
| OW5 | Ring road at full perimeter (2,860 studs) or only the inner half-loops | Full ring; it is the free-world promise and costs flat parts only |
| OW6 | Pradera leash 80 (this layout) or 60 (biome-2 proposal) | 60 if the user picks La Abeja Reina; the band here already holds at 80 |
| OW7 | Corral pens 8, trophies 5 | Start there; measure phone frame time with 8 hovering pets before raising |

## 13. What is verified and what is not

Verified by `tools/test_plan_open_world_layout.py` (18 tests, three seeds): schema and frame; regions, hub and transitions do not overlap; the forest rules moved by exactly (-300, 0); islands, relief and hide spots are pure translations with pairwise distances kept; the removed props are exactly the ones under the two new roads and the ring touches none; the ring road is closed, 14 wide, inside the world, outside both beast rectangles and beyond both chase leashes everywhere; the connectors join what they name and the threshold never enters the fog; hub stations obey the band, spoke and gap rules and all spawn pads face east; the leash bands; Refugio sets (2-3 sets, 2-3 candidates, every clearance); both hooks (band from the gate, Safe, outside, clearances); seeds (tier from distance, zone, no safe circles, canopy and base counts, trail offsets); determinism; the committed JSON matches the generator; outputs written. The full `tools` suite keeps its one known failure (`test_lumipol_v2.test_v1_files_are_unchanged`).

Not verified: anything in Studio or Play (this workflow was read-only toward Studio by rule), phone readability of the hub signs and the corral, any frame time or memory number, whether kids read "east first", whether 2,860 studs of ring road feel free or empty, and every economy effect of a longer walk home. The Pradera half is a draft until its planner and the user's B1 to B5 decisions exist.

# Wildbound open world: biome placement and Edit-mode builders

**Status: offline only.** Everything here was generated and checked by Python tests. Nothing was built in Studio, played, or measured on a device. Written 2026-11-10.

## Quick path

| You are | Read |
| --- | --- |
| The next Studio writer | Section 4 (run order), then section 6 (what is unverified) |
| The user | Section 7 (decisions and uploads) |
| Anyone changing the hub | Section 5 (regenerate after `Rules.HUB_*` changes) |

## 1. How the forest kit reached Studio, and the route every builder follows

| Kit | Route into Studio | Evidence |
| --- | --- | --- |
| Forest kit (`FK_`) | Blender FBX exports, uploaded as six Model assets (approved), kept as templates in `ServerStorage.WildboundAssets.ForestKit`. `tools/dress-wildbound-forest.luau` clones a template by prop name, removes its `PackageLink`, scales it and pivots it | `assets/exports/forest-kit/forest-kit-upload-manifest.json`, `docs/maps/wildbound-p0.md` (forest dress section) |
| Pradera (`PA_`) | Primitive parts built by Luau, no meshes | `tools/build-wildbound-pradera-map.luau` header |
| Cryptic ruins, demon abyss, frozen mountains, living forest, rock caves, volcanic lands | **Never uploaded.** FBX files exist in `assets/exports/<biome>-kit/`; each kit report says `roblox_scale_verified: false` and "never imported into Roblox" | Kit reports in `assets/blender/<biome>-kit/` |

Every new builder uses the forest kit's route and nothing else: for each prop it looks for a template Model with the prop's name in `ServerStorage.WildboundAssets.<Kit>` (`CrypticRuinsKit`, `DemonAbyssKit`, `FrozenMountainsKit`, `LivingForestKit`, `RockCavesKit`, `VolcanicLandsKit`) and clones it the same way. **None of these folders exists today, so every prop builds as a primitive-part fallback** (Part, WedgePart; Ball and Cylinder shapes). No asset id is written anywhere, no MeshPart is created, nothing is uploaded. Each prop model carries the attribute `AssetRoute` (`template` or `primitive`); each root carries `PrimitiveProps` and `TemplateProps` counts.

The fallback is generated from each kit report, so it keeps the measured sizes, colours and gameplay boxes:

| Fallback piece | Source in the kit report | Collides | Blocks sight rays (`CanQuery`) |
| --- | --- | --- | --- |
| Walls, columns, piers, tunnel walls | `occluders` | yes | yes |
| Stairs, stepping stones, floating rocks, bridges, plinths, tunnel floors | `collision_boxes` (with yaw and ramp pitch) | yes | no |
| Arch lintels and piers | `clearance` (gap and height) | yes | piers only |
| Tunnel roofs and shoulders | above the 10-stud clearance, top 18 | yes | yes |
| Trees (trunk cylinder plus crown balls), spires, stones, mounds, posts, vents | `size`, `bbox`, part colours | trunks and bases | trunks only |
| Glyphs, rifts, crystals, magma | parts with emission, as Neon | never | never |

Kit frame to plan frame: local x = -Blender x, local z = Blender y, height = Blender z (the layout planners' convention). A test walks every trail centreline and checks that no colliding fallback piece below head height stands on it.

## 2. Placement around the hub

`tools/plan_open_world_layout.py` writes `assets/maps/open-world/biome-placement-v1.json` for the hub in `src/wildbound/WildboundWorldRules.luau` (`Rules.HUB_X, HUB_Z, HUB_RADIUS`). This copy was made for the hub at **(282, -3), radius 90** (since HF-T3; it was made for the preview hub at (0, 600) before).

Rules: the west and east squares keep a 40-stud transition from the hub rim (at the original radius 60 they land on the `layout-v1.json` offsets, -300 and +300). North and south clear the west and east squares by a 40-stud gap; each diagonal clears its two neighbours by 40. Every square is axis-aligned and turned by a quarter turn so that its entry gate (the first node of its own route) faces the hub. Pantano and Cementerio, the next biomes (`docs/design/wildbound-combined-plan.md` sections 4 and 6), take the north and south slots, next to the hub.

| Biome | Name (neutral Spanish, proposal) | Slot | World centre | Yaw | Size | Entry gate (world) | Road from the rim | Root model | Builder |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `forest` | Bosque de la Silueta | W | (-18, -3) | 0 | 400 | (182, 17) | none: the hub's W gate trail | `WildboundP0` | existing P0 builder and dress; measured square (west slot (-48, -3) kept as `slot_world_centre`) |
| `pradera` | Pradera Arcoíris | E | (612, -3) | 0 | 400 | (417, -3) | 45 | `WildboundPradera` | existing `tools/build-wildbound-pradera-map.luau` |
| `living-forest` | Pantano | N | (282, -443) | 90 | 400 | (352, -258) | 176 | `WildboundLivingForest` | `tools/build-wildbound-living-forest-map.luau` |
| `cryptic-ruins` | Cementerio | S | (282, 387) | 180 | 300 | (402, 247) | 196 | `WildboundCrypticRuins` | `tools/build-wildbound-cryptic-ruins-map.luau` |
| `demon-abyss` | Abismo | NW | (-108, -393) | 90 | 300 | (17, -253) | 352 | `WildboundDemonAbyss` | `tools/build-wildbound-demon-abyss-map.luau` |
| `frozen-mountains` | Montañas Heladas | NE | (772, -493) | 0 | 500 | (547, -303) | 391 | `WildboundFrozenMountains` | `tools/build-wildbound-frozen-mountains-map.luau` |
| `volcanic-lands` | Tierras Volcánicas | SW | (-108, 437) | 180 | 400 | (82, 307) | 347 | `WildboundVolcanicLands` | `tools/build-wildbound-volcanic-lands-map.luau` |
| `rock-caves` | Cuevas de Roca | SE | (622, 387) | 270 | 300 | (522, 247) | 316 | `WildboundRockCaves` | `tools/build-wildbound-rock-caves-map.luau` |

Roads (14 studs wide, `tools/build-wildbound-open-world-roads.luau`, root `WildboundOpenWorldRoads`) run from the hub rim through the corridors between squares to each gate. A diagonal road leaves the hub between the west and east squares and turns at the corner where its two corridors meet. Where a north or south road and a diagonal road come within a road width, they share a node (a junction). Tests check that no road enters another biome or the hub disc, and that roads meet only at shared junctions.

**The real forest square (measured in Studio).** `WildboundP0`'s Floor part is centred at (-18, -3), 400 x 400, so the forest really covers x -218..182, z -203..197 (props reach x 189.3), 30 studs east of the west slot. The planner takes it as `MEASURED_FOREST` (CLI `--forest X Z SIZE`, default the measured square; `--slot-forest` ignores it). Why: the old forest road ran its last 30 studs on the forest floor (double floor), and the north-west and south-west roads passed the forest's corners (182, -203) and (182, 197) with zero clearance. Now: every other square keeps its slot (each still clears the real forest by the 40-stud gap; the planner refuses otherwise); there is no open-world forest road, because the hub's own W gate trail already runs from the W gate to the forest's east edge at (182, 17) and a second 14-stud road beside it would start at the hedge, not a gate; the north-west and south-west roads turn into their corridors at x 191 (forest edge + half width 7 + 2), so no road strip comes within 2 studs of the real forest or of any square but its own entry, and past its rim node no road strip touches the hub floor (radius 92). 7 roads, 24 slabs.

A layout point (x, z) lands at `world_centre + (x cos r + z sin r, -x sin r + z cos r)`, which is what `root:PivotTo(CFrame.new(x, 0.5, z) * CFrame.Angles(0, math.rad(yaw), 0))` does; every floor top is at 0.5.

## 3. What each builder makes

| Folder | Contents |
| --- | --- |
| `Anchor` | Invisible 1-stud PrimaryPart at the layout origin |
| `Ground` | The floor (demon abyss: a 10-stud bank cut on a 6-stud grid around the three chasms, with a dark drop floor 10 studs down), the trail as path slabs (rock caves: the two daylight legs only; demon abyss: never across a chasm), living forest stream water |
| `Props/<prop name>` | One Model per layout instance, named by its layout id |
| `Zones` | Invisible, non-colliding, non-query, 40 studs tall. `Region` (the square), and hazards: `Chasm` (demon abyss), `Vent` (volcanic, with phase and cycle attributes), `Rockfall` (rock caves lanes), `NoTrack` (frozen mountains, overhangs and shelves), `Stream` (living forest, `WalkSpeed` 10 as data) |
| `Markers` | Invisible markers: `GateMarker`, `ExitMarker`, the named route nodes, the frozen mountains `YetiHomeMarker`, El Vigía's chain (`VigiaChain_01` to `14`), rock caves points of interest |
| `Signs` | One sign beside the entry with the biome's Spanish name |

Tags: root `WildboundBiome`; zones `WildboundBiomeZone` and, for hazards, `WildboundBiomeHazard`; the gate marker `WildboundBiomeGate`; roads `WildboundOpenWorldRoad`. Attributes on the root: `Biome`, `BuilderKey`, `DisplayName`, `GeneratedBy`, `Placement`, `Seed`, `PartCount`. **No game code reads these tags yet**: today the game decides zones with `Rules.zone` (the forest's fog rectangle, the camp, the shelter, the hub disc). They are hooks for the region work (gaps document, step S1 and M6). No builder adds a script, a sound, a light or a beast.

Estimated part counts: cryptic ruins about 220, demon abyss about 360, volcanic lands about 440, frozen mountains about 550, living forest about 610, rock caves about 1,110 (the 26 tunnel modules carry most of it), roads 24 slabs and 8 gate markers.

## 4. How to run (Edit mode, one script each)

Before any Studio edit, verify the Studio instance and place and get the user's confirmation (`AGENTS.md`).

1. Paste each builder's source into a ModuleScript under `ServerStorage.WildboundBiomeBuilders` (create the Folder). Suggested names: `CrypticRuins`, `DemonAbyss`, `FrozenMountains`, `LivingForest`, `RockCaves`, `VolcanicLands`, `OpenWorldRoads`. Compare the source's Adler-32 with `python tools/biome_map_builder.py` output after pasting.
2. Run one line per biome in the command bar:

```lua
require(game.ServerStorage.WildboundBiomeBuilders.LivingForest).run()   -- tools/build-wildbound-living-forest-map.luau
require(game.ServerStorage.WildboundBiomeBuilders.CrypticRuins).run()   -- tools/build-wildbound-cryptic-ruins-map.luau
require(game.ServerStorage.WildboundBiomeBuilders.DemonAbyss).run()     -- tools/build-wildbound-demon-abyss-map.luau
require(game.ServerStorage.WildboundBiomeBuilders.FrozenMountains).run() -- tools/build-wildbound-frozen-mountains-map.luau
require(game.ServerStorage.WildboundBiomeBuilders.VolcanicLands).run()  -- tools/build-wildbound-volcanic-lands-map.luau
require(game.ServerStorage.WildboundBiomeBuilders.RockCaves).run()      -- tools/build-wildbound-rock-caves-map.luau
require(game.ServerStorage.WildboundBiomeBuilders.OpenWorldRoads).run() -- tools/build-wildbound-open-world-roads.luau
```

`run()` refuses outside Edit mode; requires `ServerScriptService.WildboundWorldRules` and refuses if its hub differs from the one the module was generated for (it only warns if the module is missing); builds the new root detached; then removes the old root only if it has the same name, `GeneratedBy = tools/biome_map_builder.py` and the same `BuilderKey`. Anything else with that name makes it refuse. A failure midway leaves the place as it was. The build is one undo step (ChangeHistoryService recording). `build(parent, origin)` builds anywhere for tests.

The Pradera builder predates the placement: its default origin is its old hub-frame offset (300, 0). In the open world, pass the placement origin (its PrimaryPart is the floor centre, top at 0.5) and replace its root yourself:

```lua
local old = workspace:FindFirstChild('WildboundPradera')
if old and old:GetAttribute('Biome') == 'PraderaArcoiris' then old:Destroy() end
require(game.ServerStorage.WildboundPraderaBuilder).build(workspace, CFrame.new(612, 0, -3))
```

(`WildboundPraderaBuilder` is a suggested name: use wherever `tools/build-wildbound-pradera-map.luau` is deployed.)

**Order:** do not build the north and north-west biomes (living forest, demon abyss) while the forest still sits at the world origin: the north square (x -200 to 200, z -40 to 360) overlaps the unshifted forest (x and z -200 to 200). Build them after the forest shift (gaps document step S1) has moved the forest to the placement, (-330, 600). The south and east biomes and the Pradera do not touch the unshifted forest.

## 5. Regenerate after the hub changes

The placement follows the hub. After `Rules.HUB_X`, `HUB_Z` or `HUB_RADIUS` changes (the hub expansion plans radius 100, `docs/design/wildbound-hub-expansion.md`), run:

```text
python tools/plan_open_world_layout.py --placement-only
python tools/biome_map_builder.py
python -I -B -m unittest discover -s tools -p "test_*.py"
```

`test_plan_open_world_placement` fails until the placement is regenerated, and every builder's `run()` refuses a mismatched hub. `--hub X Z R` previews another hub without touching the rules. At radius 100 the forest slot's centre moves to (-58, -3) and the Pradera to (622, -3).

## 6. What is unverified

- Nothing was run in Studio. No Luau was executed (no runtime offline); the tests read the generated source (field counts, block balance, forbidden calls, placement constants).
- The kit-frame mapping and box yaw sign are the planners' convention, not checked against an imported FBX. The ramp pitch sign of `CR_StairRun` is inferred from its landing box.
- Fallback look: trees, spires and arches are blockout shapes, readable but not the kit art. Rock caves tunnel bends are many small roof and shell slabs over the measured floor segments; seams and lighting inside are unseen.
- Jumps: demon abyss route rocks sit flush with the bank with 6-stud hops (the planner's figure, no jump test). The drop floor 10 studs down has no way back up and no respawn: falling recovery is gameplay that does not exist yet.
- Living forest water does not slow anyone (no script); the `WalkSpeed` attribute is data only. Vents, rockfall and sinking rocks do nothing.
- Road ends at the hub rim are not lined up with the hub builder's own gates or wall openings; the hub (v1 or v2) may need openings at the road bearings.
- Streaming, performance (about 3,300 new parts with roads), mobile readability and lighting per biome are not measured.

## 7. Decisions and uploads for the user

| # | Decision | Recommendation |
| --- | --- | --- |
| P1 | The diagonal assignment (demon abyss NW, frozen mountains NE, volcanic lands SW, rock caves SE) | Keep: the harsher biomes stay on the forest side, the milder ones near the Pradera |
| P2 | The Spanish names (Pantano, Cementerio, Abismo, Montañas Heladas, Tierras Volcánicas, Cuevas de Roca) | Keep for now; no trademark search was done |
| P3 | The forest's world position: resolved by measurement, the forest stays at (-18, -3) and the planner routes around it (`MEASURED_FOREST`) | Re-measure and pass `--forest X Z SIZE` if the forest is ever moved |
| P4 | Optional upload of the six kits' FBX files (the forest kit's route) for mesh art instead of the fallback | Only with explicit approval; the builders pick templates up without a code change once they sit in `ServerStorage.WildboundAssets.<Kit>` |
| P5 | `layout-v1.json`'s ring road (z +-212, hub radius 60 frame) crosses the north and south biomes at today's hub; it is not part of this placement | Retire it in favour of the per-biome roads |

# Wildbound P0: Fog Forest greybox

## Intended loop

An editable 400 × 400 stud square, centered at the origin, with ground top at Y = 0.5. The 14-stud-wide route connects camp (-140, 140) → Lumipol clearing (-95, 75) → ruin (0, -85) → egg nest (110, -130) → marsh (115, 15) → shelter (105, 125) → camp (X, Z coordinates). This is a prototype route, not a measured traversal time or final world boundary.

## Landmarks and markers

| Marker | X | Y | Z |
| --- | ---: | ---: | ---: |
| CampCenter | -140 | 1.5 | 140 |
| ExtractionMarker | -146 | 1.5 | 140 |
| HatchMarker | -135 | 1.5 | 146 |
| ProtectionMarker | -135 | 1.5 | 134 |
| LumipolMarker | -95 | 1.5 | 75 |
| GuardianMarker | 0 | 1.5 | -85 |
| EggMarker | 110 | 1.5 | -130 |

Markers are invisible, anchored, non-colliding placeholders; they are not spawn points or gameplay implementations. The amber camp, cyan clearing beacon, stone ruin/nest, teal pool, and shelter are primitive stand-ins. Trees use a fixed seed; decorations do not collide. Route sightlines and landmark readability require playtesting, not inference from this design.

## Construction and safety

`tools/build-wildbound-p0-map.luau` exports `build(parent)`. It refuses an existing `WildboundP0`, builds a detached editable Model, then attaches it to the supplied parent. It never removes unrelated content or alters Terrain, Lighting, spawn settings, or assets. The ground and paths are collidable; cosmetic geometry is not. The geometry is a greybox without boundary walls; players can leave it unless the surrounding environment prevents that. It does not set global fog.

## Pending verification and assets

- Run the standalone `tests/WildboundP0Map_Test.luau` contract in an authorized Studio environment; RED/GREEN and all runtime checks remain pending.
- Walk the loop; assess path joins, camp clearance, collision, sightlines, NPC navigation, touch readability and frame rate on PC/mobile. No measured travel time or device results yet.
- Replace primitive creature, trees, camp, ruin, nest and shelter with approved original assets after visual review. Decide boundary treatment and atmosphere separately; do not change global settings without authorization.

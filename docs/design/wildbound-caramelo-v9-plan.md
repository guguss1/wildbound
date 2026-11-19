# Caramelo v9: the longer kingdom and the chocolate river five times wider (plan, 2026-11-18)

Owner's words (2026-11-18): "y agranda mas el bioma caramelo a lo largo, el rio necesito qeu sea 5 veces su ancho asi es navegable por la balsa". Later the same day: "que todos los biomas tengan el mismo tamaño, pero ahora hacelos mas largos aun. Lo del rio de chocolate que vaya de una punta a la otra (o sea como esta, pero que llegue al final de esos costados)".

Standing rules that apply:
- no questions to the owner (decide and record);
- one task at a time;
- never touch SistemaSonriente;
- no asset uploads: only the existing kit models and primitive parts.

The parent's decisions PD1..PD6 are taken as given:
- every big4 arm becomes 600 x 1200, and this task does Caramelo only;
- Caramelo grows east only, and the arm becomes x 412..1612;
- the river runs along the length, 50..120 wide, and the raft sails it end to end;
- bridges let the raft pass;
- more than 2 docks;
- a live migration on the v8 pattern.

The task log is `odd/tasks/wildbound-caramelo-v9.md`.

**Conventions.**
- Every coordinate is plot-local unless marked "world". world = local + (672, -3).
- "+z" is what the code comments call north. It is world south, the Pueblo Gatito side.

**How this plan was checked.**
- The numbers come from a C# port of the WildboundCandyV3Layout and WildboundCandyLayout geometry. It ports `riverDistance`, `liquidDistance` with the v9 plot clip, `nearBridge`/`onBridge`, `routeDistance`, the rectangle `depth`, `Current.flow` and `kitPoint`.
- It runs these rules: V3-2..V3-17, the Layout_Test nest rules (including the CH3 syrup discs), Nests_Test CH1 (including every pair of posts at least 30 apart), guardian binding, the BeastSites pond and hive rules, Life CL3/CL5, Island IS1, and the v9 flood fills (barrier, raft reach, current smoothness).
- Result: **0 failures**.
- Checker: `docs/handoff/caramelo-v9/tools/v9-checker-geo9/Geo9.cs`, run with `run.ps1` in the same folder. Output: `out.txt` beside it.
- It is a port, not the Luau suites. The suites must pass in Studio before the real run.

## What is there today (repo, read 2026-11-18)

**Plot**
- World x 412..932, z -263..257. Local CENTRE (672, -3), HALF 260, square depth rings.
- Cloud band x 932..948 (Collider at 940).
- Annex strips z -303..-263 and 257..297 to x 1012. The Baseplate reaches x 1024; past it is void.

**River**
- 24 points, 10..24 wide, length 500.8. It runs north to south across the plot's short axis, from M1's waterfall at the +z edge to the -z edge.
- V3-14 makes it a barrier between the entrance and the Gran Torta.
- 2 docks.
- 5 bridges, each a 2D wall for the raft.

**Gran Torta** at local x 148.2. The plaza ends 53.8 studs from the east edge (the GT rule: "the cake with the princess at the end").

**Nests and posts**
- 28 nests (13 Comun, 11 Rara, 3 Epica, 1 Legendaria).
- 24 creature posts: 8 home posts and 16 extra.

**Saved part count:** 2072 (v8 record).

At x5 on today's course, 9 nests, 8 posts, dock B, the island and two route legs drown, and point 23 leaves the plot (r6.md). The river therefore gets a new course.

## Decisions (CL-D1..CL-D18)

### CL-D1, the plot

CENTRE (672, -3) and HALF 260 stay. One new number goes in:

- `Layout.V9 = { GROWTH = 600, OLD_EAST = 260 }`.
- `Layout.EAST = HALF + V9.GROWTH = 860`.
- HALF now means the west half-length and the z half-length.

| Item | Local | World |
|---|---|---|
| Plot | x -260..860, z -260..260 | x 412..1532, z -263..257 (1120 x 520) |
| Cloud band | x 860..876 | x 1532..1548, Collider centre 1540 |
| Arm | | x 412..1612, z -303..297 (64 studs of arm past the band, as today) |

- `Layout.depth(x, z) = min(x + HALF, EAST - x, HALF - |z|)`.
  - Examples: depth(0, 0) = 260, depth(-260, 0) = 0, depth(860, 0) = 0, depth(800, 0) = 60, depth(300, 250) = 10, depth(39, -195) = 65 (the ring pin holds).
- The rarity rings keep their numbers:
  - Comun 0..97.5;
  - Rara 97.5..208;
  - Epica and Legendaria 208..260.
- In the west only L1's depth changes (213.2 → 231.4), and it stays in its ring.

**Why CENTRE is kept.** Every west literal keeps its value:
- 24 nests and 24 posts;
- `Sites.MEADOW_CENTRE`;
- the Portal station (640.8, -3);
- the Pradera marker;
- the TrapCake spots;
- the Life copies.

Moving CENTRE would shift all of them by 300. Only the readers of the east edge change (see the file list).

### CL-D2, versions and marks

| Item | Value |
|---|---|
| `Layout.VERSION` | stays 3 (V3Builder asserts it) |
| `V3.VERSION` | 4 → **5**, so the v3..v8 tools refuse to run |
| New copy | `V3.V9 = { EAST = 860 }`, pinned equal to the layout by V3-1, like `V3.V8.HALF` |
| Root mark | `CaramelV9` (`V3.V9_MARK`) |
| Backup | `CaramelV9Backup` |
| Archive | `CaramelV9Archived` |
| Restore archive | `CaramelV9Reverted` |
| Summary attribute | `WildboundCaramelV9Summary` |
| Recordings | "CaramelV9" and "CaramelV9Restore" |

### CL-D3, the river: one long west-to-east river from M1's waterfall to the east edge

**Course.**
- It starts at M1's kit outlet in the south-west corner.
- It runs as a 50..64-wide channel along the -z edge of the west half.
- It turns into a straight 60-wide north-south reach at x 470: the bridged crossing and the barrier.
- It widens to 90..120 along the +z edge in the east and ends on the east edge, under the cloud wall.
- Length 1412.2; average width 76.7 by length; the west legs (points 2..9) average 63.5.
- Wet area 111,084 sq studs, 19.1 % of the plot (today 13,088).
- It flows west to east.
- Full table in "Data: river".

**Width.** The west channel is held to 64 by the kept left route. Its bottom leg sits at z -182 and must keep liquid ≥ 7, so the band can reach no higher than z -189. The east reaches 120 = 5 x today's 24. Point 1 (20) is exempt, as point 1 is today.

**Plot clip.** `V3.liquidDistance` ends with `return math.max(best, -V3.plotDepth(x, z))`. Nothing outside the plot is chocolate, for the raft, wading, the current or any clearance. This removes the 60-stud capsule past the mouth.
- `V3.plotDepth(x, z) = min(x + V8.HALF, V9.EAST - x, V8.HALF - |z|)`.

**Joint drums match the rule.**
- New pure helper `V3.jointRadius(i) = max(w[i-1], w[i], w[i+1]) / 2`, skipping missing neighbours.
- `layLiquid` lays each joint drum at that radius instead of `w[i]/2`, so the laid chocolate equals the rule's capsules at every width step.
- Still no drum at the last point. The part count is unchanged.

**Basins.** Each river dock gets a small lake disc ("basin"), wholly inside the river band. Every dock tip therefore sits at least LAKE_BLEND (8) inside a disc, and the current there is LAKE_SPEED 1.5. See CL-D8.

### CL-D4, the source: M1 moves to the south-west corner, bigger

M1 is `CV3_IceCreamMountain_L`.

| Item | Value |
|---|---|
| Scale | 0.45 → **0.75** |
| r | 54 x 0.75 = 40.5 |
| Height | 90.431 x 0.75 = 67.82 |
| Position | local (-219.8, -219.8), world (452.2, -222.8) |
| Faces | RIVER[2] (-150, -224): yaw -1.5107 rad |

- It closes the corner: depth 40.2 ≥ r - 0.5 = 40.0, so it overhangs both edges by 0.3. Its old north-edge spot is left to the relaid edge fill.

**Kit offsets become data.**
- `V3.M1_KIT = { outlet = {0.5653, -49.6671}, pool = {0.5653, -37.6671}, poolRadius = 11, fall = {0.5653, -31.0} }`, copied from `WildboundCandyV3KitSpec` and pinned by a test.
- New `V3.kitPoint(x, z, yaw, scale, X, Z)` places them.
- `withM1`, `M1_DX`, `M1_DZ` and `RIVER_V7` go. A frozen `V3.M1_V8` record (today's M1 row) stays for the regression pin.

**Derived pieces.**

| Piece | Local | Details |
|---|---|---|
| POOL | (-191.58, -221.07) | r 8.25 |
| WATERFALL | (-196.57, -220.77) | width 11.67 (7/0.45 x 0.75), top 25.29 (33.72 x 0.75), 5 streaks, flowSpeed 12, faces the pool |
| RIVER[1] (outlet) | (-182.59, -221.61) | width 20 (12/0.45 x 0.75) |

**Foot basin.** Point 1's joint drum is r 25 (max(20, 50)/2). It reaches to 12.3 studs from M1's pivot, so the kit pool and the lowest front skirt lie under a wide foot basin and the fall lands in it. This is chosen over a smaller drum: a smaller drum would leave rule chocolate that is not laid on M1's slope.

**Flock height.** `Life.MIN_ALT` 46 → **72** (67.82 + 4).

### CL-D5, the river stays a barrier

The rule changes from V3-14's "every z line meets chocolate west of the boss" to a flood fill. On a 2-stud grid of in-plot cells with liquid ≥ 0, M1's footprint is solid and bridges are ignored. **From the entrance it never reaches the Torta.** Measured: 79,364 dry cells on the entrance bank.

**Entrance bank** holds:
- the west half and the wedge x 260..440;
- docks A and B;
- the new nests C14, C15, R12..R15;
- the dead-end strip north of the east stretch.

**Cake bank** holds:
- x ≥ 500 below the east stretch, and the 3..55-stud strip south of the west channel;
- the Torta, docks C and D;
- the nests E4..E6, C16..C19, R16..R19.

**Dry links between the banks:** only the three bridges. Otherwise players wade or take the raft.

**Limit.** The barrier holds inside the plot only, as today. The annex strips beside both long sides and the ground west of x 412 can still be walked round (r6.md D1). See risk 8.

### CL-D6, routes

Path width 14.

| Route | Points (local) | Notes |
|---|---|---|
| main | (-260,0) (-143,0) (0,0) (690.2,0) | last point = TORTA.x - plaza 58; the avenue is 950.2 long |
| left | unchanged | |
| right | unchanged | |
| deep | unchanged | |
| **south** (new) | (300,0) (320,-125) (640,-125) (670,-200) | |
| **north** (new) | (300,0) (320,125) (620,125) | |

- `ROUTE_ORDER` = main, left, right, deep, south, north.
- `RETURN_ROUTES` stays {left, right}.
- New named point `Layout.EAST_FORK = (300, 0)`, world (972, -3), where the far routes leave the avenue. It is 448.2 from the boss, against the ≥ 112 safe-point rule.

**Every route point has x < TORTA.x (GT1).**

**Least liquid off the bridges:**

| Route | Least liquid | Where |
|---|---|---|
| left | 10.00 | (40, -182) |
| north | 10.00 | (575, 125) |
| main | 32.38 | |
| south | 33.00 | |

**Landmarks along the avenue** (gaps ≤ 230 studs):

| Landmark | x |
|---|---|
| entrance | -260 |
| licorice arch | -161.2 |
| fork | -143 |
| portal | -31.2 |
| junction | 0 |
| H4 and M2 | about 232 |
| east fork with H8 | 300..380 |
| Main bridge | 470 |
| H10's caramel tower | 530 |
| E4/E5 | 560..580 |
| the plaza | 690.2 |
| the Gran Torta | 748.2 |

### CL-D7, three raised bridges the raft passes under

**Build:** `V3.BRIDGE_BUILD = { width 15, deck 12.5, ramp 28, gapWidth 8, sideRamp 28, pier = { size 2, inset 1 } }`. Every row has `gaps = {}`, so there are no side ramps.
- Ramps: atan(12.5/28) = 24.06° ≤ 25°.
- Deck underside: 12.5 - 0.4 - 3.5 (LIQUID.depth) = **8.6** above the chocolate surface, at least `V3.RAFT.clearance = 8`.
- The kit raft's top is 6.64 + 0.15 bob = 6.79, so there are 1.81 studs over it. A seated rider's head (about +6) clears by about 2.6.

**Three rows,** all square to the straight 60-wide reach at x 470:

| Id | Route, leg | at | Deck length | Deck centre local / world | Footprint along the leg | Cookie |
|---|---|---|---|---|---|---|
| Top | north, (320,125)→(620,125) | 150 | 68 | (470,125) / (1142,122) | 88..212 of 300 | yes |
| Main | main, (0,0)→(690.2,0) | 470 | 68 | (470,0) / (1142,-3) | 408..532 of 690.2 | **never breaks** |
| Bottom | south, (320,-125)→(640,-125) | 150 | 68 | (470,-125) / (1142,-128) | 88..212 of 320 | yes |

**Piers.** `layBridge` adds 4 per bridge: blocks 2 x 12.1 x 2 at along ±33 and across ±6.5, standing from the floor top to the deck's underside, so kids can see the raft fits under. That makes 7 + 4 = 11 parts per bridge.

**Cookie bridges.**
- `Cookie.IDS` stays {"Top", "Bottom"}.
- `Cookie.SINK` 7 → **14** (> deck 12.5 + 0.4).
- FALL_SECONDS stays 1.2.
- Waders under a deck never trigger it: FEET_SLACK is measured against floorTop + deck.

**Retired:** today's 5 bridges (Top, RightLast, Main, LeftLast, Bottom) are archived with the old water. The ids RightLast and LeftLast no longer exist.

### CL-D8, raft and four docks

**Raft code** (`src/wildbound/WildboundCandyRaft.luau`), 2 changes:
- `area.inside` becomes:
  ```lua
  local blocks = V3.raftBlocks or V3.nearBridge
  return V3.liquidDistance(lx, lz) <= -r and not blocks(lx, lz, r)
  ```
  A fake layout without `raftBlocks` keeps bridges as walls, so RF4 and RF16 stay unchanged.
- `Raft.new`: `homeDock = (type(homeDock) == "number" and docks[homeDock] ~= nil) and homeDock or 1`. It still needs ≥ 2 docks. The `dockedAt` comment changes from "1 or 2" to "an index".

**V3 helpers.**
- `V3.raftBlocks(x, z, reach)` is true near a bridge whose `deck - 0.4 - LIQUID.depth < RAFT.clearance`. In v9 there are none, so it is always false.
- The plot edge needs nothing extra: the plot clip makes outside the plot dry, so the raft stops with its centre 3 inside the edge, at local x 857.
- `V3.RAFT = { asset = "CV3_BananaRaft", homeDock = 1, clearance = 8 }`.
- `V3.DOCKS` become plain local rows; `withDisc` goes.
- RaftService, the call points (one per dock, a call teleports) and the 8 s respawn to dock A are unchanged.

**Reach.** From dock A's tip the raft reaches **all 25,703** hull cells (2-stud grid, liquid ≤ -3), including all four tips, the pool, and x -204..856.

**Docks.** Each tip sits 10 studs inside its disc (≥ 8), and the current at each tip is 1.50.

| Dock | Stand → tip, local | World stand → tip | Stand-tip / deck | Stand liquid | Tip liquid | Ramp foot liquid | Disc | Bank |
|---|---|---|---|---|---|---|---|---|
| A (home) | (-150,-187)→(-150,-210) | (522,-190)→(522,-213) | 23 / 18 | 5.00 | -18.00 | 15.00 | basin A | entrance |
| B | (240,-186)→(240,-208) | (912,-189)→(912,-211) | 22 / 17 | 5.92 | -16.04 | 15.89 | basin B | entrance |
| C | (670,104)→(670,128) | (1342,101)→(1342,125) | 24 / 19 | 14.00 | -10.00 | 24.00 | lake disc 1 | cake |
| D | (815,124)→(815,148) | (1487,121)→(1487,145) | 24 / 19 | 11.00 | -13.00 | 21.00 | basin D | cake |

- Tips are at least 50 apart.
- No tip is within 6 of a bridge.

**Trip times** along the centreline (raft SPEED 20, current ±4 on the river legs):
- Dock A tip ≈ 32.7, B ≈ 422.7, C ≈ 1222, D ≈ 1367 studs from the source.
- A→D is 1334 studs: about **56 s downstream** (24 studs/s) and about **83 s upstream** (16), the trip home.
- Walking the avenue from the plaza to the entrance is 950 studs, 59 s at 16.
- So the raft is the toy and the off-road crossing, not the fastest way home. This is recorded as risk 2.

### CL-D9, the Gran Torta, boss and tower move +600

`TORTA = point(fromV7Local(114, 0).x + V9.GROWTH, 0)` = (748.2, 0), r 42. Plaza 58, territory 76, perception 36 and whip 22 are kept.

| Item | Local | World |
|---|---|---|
| TORTA / BOSS centre | (748.2, 0) | (1420.2, -3) |
| BOSS home | (698.2, 0) | (1370.2, -3) |
| Glaze puddles (v8 offsets kept) | (748.2,52), (804.2,9), (709.2,34) | (1420.2,49), (1476.2,6), (1381.2,31) |
| Summit nest T1 | (748.2, 9.4) | (1420.2, 6.4) |

- The plaza ends 53.8 from the east edge, as in v8 (≤ 60). The territory edge is at depth 35.8 (≥ 10).
- Liquid at the boss is 135.0 (≥ 76): the east stretch is 195 away, less its half width 60.
- `Builder.layoutKey(Layout)` = "748.2,0,42".
- Tower, stair (derived) and Markers are relaid on the v8 path.
- `Sites.FIXED.bossHome` = (1370.2, -3), `bossTerritory` = (1420.2, -3). AMBUSH.bossClearStuds 126 is measured from the new territory centre.
- The Portal stays at local (-31.2, 0) / world (640.8, -3); `WildboundPortal.luau` does not change.

### CL-D10, nests: 28 → 45 (19 Comun, 19 Rara, 6 Epica, 1 Legendaria) plus T1

- **Kept, 24:** C1-C5, C7, C9, C11, C12, R1-R11, E1-E3, L1. L1 stays event-only.
- **Moved, 4 (swallowed by the channel):** C6, C8, C10, C13, through a new `nestAt(id, rarity, x, z)` helper that takes v9 local literals with no 1.3 scaling. C13 moves to the north side, so its post is no longer within 30 of candyPostR6.
- **New, 17:** C14-C19, R12-R19, E4-E6.

**Every nest passes:**
- liquid ≥ 6;
- route 11..52;
- at least 20 from any other nest;
- at least 48 from the Torta;
- x < 748.2;
- inside its depth ring;
- syrup discs ≥ r + 6;
- keep-clears ≥ r + 20.

New and moved nests also pass ≥ 96 from the boss (E6 115.4 is the closest) and ≥ 80 from the entrance.

**Reward lean.**
- All 3 new Epica (E4, E5, E6) are on the cake bank. Their mean x is 593.3, against 465.0 for the new Rara and 519.2 for the new Comun.
- The ring rule keeps the new Comun on the edge strips, so no Comun-below-Rara order is required.
- E1-E3 and L1 stay put.
- `HouseNests.RARITY` adds H8 "Comun", H9 "Rara", H10 "Rara".

### CL-D11, creature posts (`WildboundPraderaSites`)

**Moved posts.** The four posts of the moved nests move with them, written with a new helper `besideLocal(lx, lz, dx, dz)` = MEADOW_CENTRE + (lx + dx, lz + dz).

**Third extra post per creature.** EXTRA_POSTS goes 16 → 24 rows, so there are 32 posts with the 8 home posts. The three guardians' new posts guard E4, R16 and E5.

**Guardian binding.** Guarded nests go 9 → 12, each bound at 8.5..14.4 (BIND_RADIUS 20).

**CH1 holds for all 24 extras:**
- nearest nest 8..16 and its own, none shared;
- route between 11 and the creature's wake radius;
- depth ≥ leash;
- boss distance ≥ 76 + reach;
- entrance distance ≥ 30 + reach;
- at least 100 from the creature's home;
- syrup discs ≥ r + 2;
- every pair of posts at least 30 apart (closest: candyPostC7/candyPostC13 at 38.7).

**AMBUSH** gets `east = 860`. `ambushRoll`:
- refuses a player when `lx < -half or lx > east or |lz| > half`;
- refuses a spot when `min(sx + half, east - sx, half - |sz|) < edgeStuds`.

Every other number stays.

### CL-D12, houses, mountains, hills, keep-clears

**Houses: 7 → 10.**
- H3 and H6 move out of the channel.
- H8 (Sweet), H9 (Choco) and H10 (Caramel tower) are new.
- There is still a house in every quarter.
- Every door passes: at least 4 from the chocolate, depth ≥ 5, at least 4 from every piece.

**Mountains.**
- M1 moves (CL-D4).
- M5 gives M1 its corner and moves to the east.
- M7 (L 0.45) and M8 (M 0.4) are new.
- M2, M3, M4 and M6 are unchanged.

**Pink hills.** All six re-anchor to x = EAST - 2 = 858 (they straddle the edge) at new z values that keep clear of the mouth.

**KEEP_CLEAR.** Only the pond and hive rows remain. The stale "Cloud gate to Caramelo Este" row (250, 0) goes (PGM-D8).

**Unchanged:** licorice (-161.2, 0), cake (-195, 145.6), and BACKDROP (empty).

### CL-D13, ground, cloud wall, strips, big4 rows

**`Ground.Floor`** stays one part, because Ambience, Life and FlyersService read it. Size (1120, 1, 520), centre world (972, 0, -3), top 0.5.
- Fresh-build `Builder.build`: `Vector3.new(L.HALF + L.EAST, 1, 2 * L.HALF)` at `world((L.EAST - L.HALF) / 2, top - 0.5, 0)`.

**`East.plan(L, V3)`** (V3 is optional and defaults to ServerStorage's). New constants: `East.TAIL = 64` and `East.EDGE_WALL = 4`.

| Part | World rectangle | Status |
|---|---|---|
| Ground.Floor (band + tail) | x 1532..1612, z -263..257 | resized (was the band only) |
| CloudWall.Collider | x 1538..1542, z -271..265, 80 tall | moved |
| CloudWall.Veil | x 1532..1548, z -271..265 | moved |
| CloudWall.CapNorth | x 1538..1612, z 261..265 | resized (ends at the arm, no longer at `space.maxX`) |
| CloudWall.CapSouth | x 1538..1612, z -271..-267 | resized |
| CloudWall.SideWallNorth | x 1020..1616, z 297..301, 80 tall, invisible, solid | **new** |
| CloudWall.SideWallSouth | x 1020..1616, z -307..-303 | **new** |
| CloudWall.EndWall | x 1612..1616, z -307..301 | **new** |
| CloudWall.MouthGuard | x 1532..1538, z 132..252, 80 tall, invisible, solid | **new** |
| CloudWall.MouthSheet | x 1532..1612, z 132..252, 3.5 thick at the river surface, V3.LIQUID colour, no collide/query/touch | **new** |

- The side walls and the end wall stop falls into the void past the Baseplate's x 1024 along the stretched strips.
- The MouthGuard closes the 6-stud gap between the plot edge and the Collider across the mouth, so the barrier holds to the wall.
- The MouthSheet is decor: the river is seen flowing on under the cloud to the arm's end.
- The mouth parts are planned only when V3's last river point lies on the east edge. Their z span comes from it: 195 ± 60, world 132..252.
- `plan().space` and `shift` stay as legacy formulas for annexMove, annexGround and the old tools.
- New `plan().arm` = x 412..1612, z -303..297.
- `East.build` already creates missing specs, so it conforms 5 parts and creates 5.

**Annex strips.** New pure `East.stripPlan(L, slabs)` resizes the two strips of `Workspace.WildboundCandyAnnex_Big4` to x 412..1612, keeping their z ranges. It finds them by geometry: x 412..1012 ± 1, z -303..-263 and 257..297 ± 1. 0 new parts.

**Big4 Meadow row (Studio only).** In the big4 `WildboundBiomes` and `WildboundBiomeLight` `AREAS_BIG4`, the Meadow row goes from x 412..1012 to **412..1612**; z -303..297 is unchanged.

### CL-D14, client systems

**Life**
- New `Life.EAST = 860`.
- `plotFrame` anchors on the floor's **west edge**: `x = x - sizeX/2 + Life.HALF`. The grown floor gives 972 - 560 + 260 = 672; today's floor gives 672 too.
- HOUSES: the 10 rows.
- FLOCKS and FISH become plain v9 literal rows. `scaled()` and `LAKE_DISC_V7` are no longer applied to them.
- `MIN_ALT` = 72.
- Flowers unchanged.

**Ambience:** `PLOT_FALLBACK.maxX` 932 → 1532. The live floor's bounds follow on their own.

**No change:** the CloudWall client (finds the Veil by name), Current client, Raft client, Sky (follows the Studio big4 row).

### CL-D15, server systems

**`Duq.plotDepth`** = `Layout.depth(x - CENTRE.x, z - CENTRE.z)`. Without it the queen would "Vanish" east of x 932.

**Flyers**
- `inside` uses `bounds.halfX or bounds.half` for x.
- `hiveSpotOk` takes an optional `opts.liquid(lx, lz)` and returns "Chocolate" when it is < `LAKE_MARGIN_STUDS` (4).
- Measured: 55 of 383 valid candidates sit in or within 4 of the chocolate, beside the bridges and over the channel.

**FlyersService**
- Centre on the floor's west edge, as Life.
- Bounds `{ x = 972, z = -3, half = 260, halfX = 560 }`.
- Passes `V3.liquidDistance`, requiring `ServerStorage.WildboundCandyV3Layout`.

**No change:** Current, Wade, CookieBridgeService, RaftService, Nests, Smarts (it reads the live Collider), TrapCake, Portal.

**Re-planned at server start:** HideSpots, Grass, Traps, Island and HouseNests. They read the layout, so the new routes and houses are included.

### CL-D16, part budget

| Constant | Old → new |
|---|---|
| `V3.BIOME_PART_CAP` | 2800 → **3400** |
| `V3.V9_PART_TARGET` | new, **3100**: the real run refuses above it |
| `V3.MAX_NEW_PARTS` | 1300 → **1600** |
| `V3.EDGE.maxParts` | stays 600 |

Details in "Part budget".

### CL-D17, the migration tool

`tools/wildbound-caramelo-v9-migrate.luau`:
- dry run first;
- backup, then archive; nothing is destroyed but the probe;
- one recording;
- idempotent;
- RESTORE mode.

Most of the rebuild is the existing, tested `V3Builder.layAll(relay = true)` plus the v8 relays. Details in "Migration".

### CL-D18, what stays

**Positions and records**
- CENTRE, HALF and the Portal.
- The Pradera marker, and the pond and hive keep-clears.
- The TrapCake spots: riverside liquid ≥ 10 holds.
- The Licorice and the cake.
- The dead `Layout.LAKE` syrup discs and `Layout.BRIDGE`, still read by a fresh `Builder.build` and Flyers. They are checked: every moved nest and post clears them.
- `KittenPark.GATE_CORRIDOR`, a one-shot record.

**Old tools and checks**
- The v3..v8 tools: they refuse on VERSION 5.
- `test_caramelo_v3.py`: already stale.

**Rules and names**
- `Cookie.IDS`.
- `RETURN_ROUTES`.
- `Current` tuning: RIVER_SPEED 4, LAKE_SPEED 1.5, JOIN 6, EDGE 2.

## Data tables

### River (`V3.RIVER`, source → mouth; a leg is as wide as its wider end)

| # | Local x, z | w | World | depth - w/2 | Joint drum r | Note |
|---|---|---|---|---|---|---|
| 1 | (-182.59, -221.61) | 20 | (489.41, -224.61) | 28.39 | 25 | M1 outlet: kitPoint, exempt |
| 2 | (-150, -224) | 50 | (522, -227) | 11 | 32 | M1 faces it; dock A |
| 3 | (-60, -225) | 64 | (612, -228) | 3 | 32 | |
| 4 | (40, -224) | 64 | (712, -227) | 4 | 32 | |
| 5 | (140, -225) | 64 | (812, -228) | 3 | 32 | |
| 6 | (240, -224) | 64 | (912, -227) | 4 | 32 | dock B |
| 7 | (330, -218) | 64 | (1002, -221) | 10 | 32 | |
| 8 | (400, -210) | 60 | (1072, -213) | 20 | 32 | bend |
| 9 | (445, -200) | 60 | (1117, -203) | 30 | 30 | |
| 10 | (470, -175) | 60 | (1142, -178) | 55 | 30 | reach starts |
| 11 | (470, 175) | 60 | (1142, 172) | 55 | 45 | reach ends (350 long; the 3 bridges) |
| 12 | (510, 200) | 90 | (1182, 197) | 15 | 55 | |
| 13 | (575, 195) | 110 | (1247, 192) | 10 | 60 | |
| 14 | (650, 195) | 120 | (1322, 192) | 5 | 60 | |
| 15 | (760, 195) | 120 | (1432, 192) | 5 | 60 | |
| 16 | (860, 195) | 120 | (1532, 192) | edge | none | mouth, on the east edge |

**Source pieces**

| Piece | Local | World | Size |
|---|---|---|---|
| POOL | (-191.58, -221.07) | (480.42, -224.07) | r 8.25 |
| WATERFALL | (-196.57, -220.77) | (475.43, -223.77) | width 11.67, top 25.29 |

**Lake (`V3.LAKE`, order matters: 1 and 2 are the lake proper)**

| Disc | Local | r | World | Role |
|---|---|---|---|---|
| 1 | (670, 170) | 52 | (1342, 167) | the harbour lake: island, platforms, dock C |
| 2 | (580, 172) | 34 | (1252, 169) | west lobe |
| 3 | (-150, -222) | 22 | (522, -225) | basin A (rim at least 8.0 inside the band) |
| 4 | (240, -222) | 24 | (912, -225) | basin B (rim at least 6.06 inside) |
| 5 | (815, 170) | 32 | (1487, 167) | basin D (rim at least 3.0 inside) |

**Island and platforms**

| Piece | Local | Size | World | Placement |
|---|---|---|---|---|
| Island I1 | (690, 150) | r 6, flat 4, foot 9.9 | (1362, 147) | channel all round (foot + 3) at liquid ≤ -3; foot at least 15 from every tip and at least 20 from every stand |
| CookieM | (580, 170) | r 6.7 | | in disc 2 |
| CookieL | (650, 180) | r 11.7 | | in disc 1 |
| CookieS | (700, 185) | r 3.9 | | in disc 1 |
| CookieS | (630, 150) | r 3.9 | | in disc 1 |

All platforms are at least 2 apart, at least 4 off the island's foot and off every bridge.

**Current.** The worst direction change is 9.35°/stud at (520, 145), over 219,467 checks (CU4 limit 15). The current is 1.50 at every disc centre and dock tip. 12 legs are open (midpoint off every disc).

### Routes and bridges

See CL-D6 and CL-D7.

**Route lengths:**

| Route | Length |
|---|---|
| main | 950.2 |
| left | 586.1 |
| right | 515.2 |
| deep | 31.2 |
| south | 527.4 |
| north | 426.6 |

**Each bridge** (all three alike):
- the wet span (liquid ≤ 1) reaches |along| 31, under a deck half of 34;
- liquid at the deck ends is 4.0;
- the pier footprints are at liquid ≥ 2.0.

### Nests (45 + T1)

**Kept (24).** Local, then world.

| Id | Rarity | Local | World |
|---|---|---|---|
| C1 | Comun | (-208, -23.4) | (464, -26.4) |
| C2 | Comun | (-182, 31.2) | (490, 28.2) |
| C3 | Comun | (-117, -171.6) | (555, -174.6) |
| C4 | Comun | (-80.6, 169) | (591.4, 166) |
| C5 | Comun | (78, 197.6) | (750, 194.6) |
| C7 | Comun | (6.5, 184.6) | (678.5, 181.6) |
| C9 | Comun | (-175.5, -80.6) | (496.5, -83.6) |
| C11 | Comun | (-39, 195) | (633, 192) |
| C12 | Comun | (-169, -130) | (503, -133) |
| R1 | Rara | (-101.4, -39) | (570.6, -42) |
| R2 | Rara | (-101.4, 44.2) | (570.6, 41.2) |
| R3 | Rara | (-58.5, -120.9) | (613.5, -123.9) |
| R4 | Rara | (-26, 123.5) | (646, 120.5) |
| R5 | Rara | (114.4, 145.6) | (786.4, 142.6) |
| R6 | Rara | (124.8, -158.6) | (796.8, -161.6) |
| R7 | Rara | (-150.8, 75.4) | (521.2, 72.4) |
| R8 | Rara | (-143, 123.5) | (529, 120.5) |
| R9 | Rara | (-78, 91) | (594, 88) |
| R10 | Rara | (-13, -58.5) | (659, -61.5) |
| R11 | Rara | (46.8, 96.2) | (718.8, 93.2) |
| E1 | Epica | (-44.2, -26) | (627.8, -29) |
| E2 | Epica | (-44.2, 31.2) | (627.8, 28.2) |
| E3 | Epica | (0, 46.8) | (672, 43.8) |
| L1 | Legendaria (event-only) | (46.8, -28.6) | (718.8, -31.6) |

**Moved (4, `nestAt`)**

| Id | Rarity | New local | New world | Was (local) | Depth | Route | Liquid |
|---|---|---|---|---|---|---|---|
| C6 | Comun | (55, -168) | (727, -171) | (13, -210.6) | 92.0 | 14.0 | 24.1 |
| C8 | Comun | (105, -183) | (777, -186) | (78, -221) | 77.0 | 24.8 | 9.65 |
| C10 | Comun | (-52, -167) | (620, -170) | (-78, -210.6) | 93.0 | 15.0 | 25.9 |
| C13 | Comun | (35, 190) | (707, 187) | (130, -195) | 70.0 | 34.0 | 382.0 |

**New (17)**

| Id | Rarity | Local | World | Depth | Route | Bank |
|---|---|---|---|---|---|---|
| C14 | Comun | (340, -166) | (1012, -169) | 94 | 41.0 | entrance |
| C15 | Comun | (350, 166) | (1022, 163) | 94 | 41.0 | entrance |
| C16 | Comun | (530, -170) | (1202, -173) | 90 | 45.0 | cake |
| C17 | Comun | (620, -172) | (1292, -175) | 88 | 36.0 | cake |
| C18 | Comun | (700, -215) | (1372, -218) | 45 | 33.5 | cake |
| C19 | Comun | (575, -172) | (1247, -175) | 88 | 47.0 | cake |
| R12 | Rara | (280, -80) | (952, -83) | 180 | 32.4 | entrance |
| R13 | Rara | (280, 80) | (952, 77) | 180 | 32.4 | entrance |
| R14 | Rara | (400, -150) | (1072, -153) | 110 | 25.0 | entrance |
| R15 | Rara | (410, 150) | (1082, 147) | 110 | 25.0 | entrance |
| R16 | Rara | (600, -80) | (1272, -83) | 180 | 45.0 | cake |
| R17 | Rara | (660, -95) | (1332, -98) | 165 | 36.1 | cake |
| R18 | Rara | (560, 95) | (1232, 92) | 165 | 30.0 | cake |
| R19 | Rara | (530, -80) | (1202, -83) | 180 | 45.0 | cake |
| E4 | Epica | (560, -40) | (1232, -43) | 220 | 40.0 | cake |
| E5 | Epica | (580, 40) | (1252, 37) | 220 | 40.0 | cake |
| E6 | Epica | (640, -40) | (1312, -43) | 220 | 40.0 | cake |

### Creature posts (`Sites.FIXED`, world)

**Moved and new posts**

| Key | Creature | Role | Written as | Local | World |
|---|---|---|---|---|---|
| candyPostC6 | Mielita | extra | besideLocal(55,-168, 0,12) | (55, -156) | (727, -159) |
| candyPostC8 | Tortidragon | extra, guards C8 | besideLocal(105,-183, -8,9) | (97, -174) | (769, -177) |
| candyPostC10 | Flanin | extra | besideLocal(-52,-167, 12,8) | (-40, -159) | (632, -162) |
| candyPostC13 | Mielita | extra | besideLocal(35,190, 10,8) | (45, 198) | (717, 195) |
| candyPostE4 | Gomibu | extra, guards E4 | besideLocal(560,-40, 0,12) | (560, -28) | (1232, -31) |
| candyPostR16 | Flanfuria | extra, guards R16 | besideLocal(600,-80, 0,-12) | (600, -92) | (1272, -95) |
| candyPostE5 | Tortidragon | extra, guards E5 | besideLocal(580,40, 0,-12) | (580, 28) | (1252, 25) |
| candyPostR12 | Mochimiau | extra | besideLocal(280,-80, 12,0) | (292, -80) | (964, -83) |
| candyPostC16 | Canelin | extra | besideLocal(530,-170, 0,12) | (530, -158) | (1202, -161) |
| candyPostR13 | GatoRepartidor | extra | besideLocal(280,80, 12,0) | (292, 80) | (964, 77) |
| candyPostC18 | Mielita | extra | besideLocal(700,-215, -12,0) | (688, -215) | (1360, -218) |
| candyPostR15 | Flanin | extra | besideLocal(410,150, -12,0) | (398, 150) | (1070, 147) |
| bossHome | Don Glaseon | | CENTRE + BOSS.home | (698.2, 0) | (1370.2, -3) |
| bossTerritory | Don Glaseon | | CENTRE + BOSS | (748.2, 0) | (1420.2, -3) |

**EXTRA_POSTS gain 8 rows** (third round): Gomibu candyPostE4, Flanfuria candyPostR16, Tortidragon candyPostE5, Mochimiau candyPostR12, Canelin candyPostC16, GatoRepartidor candyPostR13, Mielita candyPostC18, Flanin candyPostR15.

**Each creature's three extras:**

| Creature | Extra posts |
|---|---|
| Gomibu | C7, E3, E4 |
| Flanfuria | R6, R8, R16 |
| Tortidragon | C8, R9, E5 |
| Mochimiau | C9, R10, R12 |
| Canelin | R7, C11, C16 |
| GatoRepartidor | R5, R11, R13 |
| Mielita | C6, C13, C18 |
| Flanin | C10, C12, R15 |

All other FIXED rows are unchanged.

### Houses (`V3.HOUSES`; Life copies them exactly)

| Id | Kit, scale | r | Local | World | Status | liquid - r | Door (liquid / depth) |
|---|---|---|---|---|---|---|---|
| H1 | Sweet 1.4 | 28 | (-192.4, 215.8) | (479.6, 212.8) | kept | 381.8 | 384.4 / 68.1 |
| H2 | CaramelTower 1, turn 180 | 15 | (-130, 227.5) | (542, 224.5) | kept | 404.7 | 436.1 / 16.0 |
| H3 | Choco 1.4 | 22.4 | (-10, -118) | (662, -121) | moved from (-205.4, -195) | 52.1 | 100.8 / 168.3 |
| H4 | Sweet 1 | 20 | (231.4, 130) | (903.4, 127) | kept | 177.8 | 220.7 / 141.8 |
| H5 | CaramelTower 1.4, turn 180 | 21 | (-218.4, -106.6) | (453.6, -109.6) | kept | 74.5 | 94.3 / 19.1 |
| H6 | Choco 1 | 16 | (45, -125) | (717, -128) | moved from (195, -221) | 51.0 | 85.8 / 153.8 |
| H7 | Sweet 1 | 20 | (143, 231.4) | (815, 228.4) | kept | 266.8 | 296.5 / 49.0 |
| H8 | Sweet 1 | 20 | (380, -60) | (1052, -63) | new | 40.0 | 83.7 / 203.7 |
| H9 | Choco 1 | 16 | (600, -200) | (1272, -203) | new | 86.4 | 82.6 / 66.3 |
| H10 | CaramelTower 1, turn 180 | 15 | (530, 70) | (1202, 67) | new | 15.0 | 48.8 / 187.5 |

### Mountains (`V3.MOUNTAINS`)

| Id | Kit, scale | r | Local | World | Status |
|---|---|---|---|---|---|
| M1 | L 0.75 | 40.5 (height 67.82) | (-219.8, -219.8) | (452.2, -222.8) | moved, the source |
| M2 | M 0.4 | 14.2 | (234, -117) | (906, -120) | kept |
| M3 | M 0.37 | 13.1 | (98.8, 243.1) | (770.8, 240.1) | kept |
| M4 | M 0.37 | 13.1 | (214.5, -156) | (886.5, -159) | kept |
| M5 | M 0.37 | 13.1 | (800, -236) | (1472, -239) | moved from (-241.8, -241.8); faces the Torta |
| M6 | M 0.37 | 13.1 | (-243.1, 243.1) | (428.9, 240.1) | kept |
| M7 | L 0.45 | 24.3 (height 40.7) | (790, -170) | (1462, -173) | new; faces the Torta |
| M8 | M 0.4 | 14.2 (height 24.1) | (300, 230) | (972, 227) | new; faces EAST_FORK |

### Pink hills (`V3.CRYSTAL_HILLS`, x 858, world x 1530)

| Hill | z | Scale | r | liquid - r | Boss distance - r |
|---|---|---|---|---|---|
| Hill_1 | -247 | 0.5 | 17.75 | 346.9 | 252.6 |
| Hill_2 | -190 | 0.45 | 16 | 309.0 | 203.4 |
| Hill_3 | -125 | 0.5 | 17.75 | 242.3 | 148.6 |
| Hill_4 | -60 | 0.45 | 16 | 179.0 | 109.1 |
| Hill_5 | 60 | 0.45 | 16 | 59.0 | 109.1 |
| Hill_6 | 105 | 0.28 | 9.94 | 20.1 | 142.0 |

### Life rows (local)

**FLOCKS** (id, centre, r, alt). F1..F6 keep their dir, phase and colour.

| Flock | Centre | r | alt | Status | Liquid at centre |
|---|---|---|---|---|---|
| F1 | (-156, 52) | 26 | 76 | | 244.1 |
| F2 | (-104, -65) | 24 | 79 | | 127.5 |
| F3 | (78, 195) | 22 | 75 | | 347.5 |
| F4 | (169, -143) | 22 | 78 | | 49.7 |
| F5 | (-90, -140) | 20 | 76 | moved off the channel | 52.7 |
| F6 | (195, 156) | 20 | 80 | | 230.7 |
| F7 | (380, -110) | 24 | 77 | new; dir 1, phase 2.0, colour {120, 215, 90} | 60.0 |
| F8 | (620, -50) | 22 | 79 | new; dir -1, phase 4.5, colour {255, 205, 60} | 120.0 |

Every bird stays within y 72..92 (MIN_ALT .. MIN_ALT + 20), at least 5 inside the rectangle, at least 10 off the chocolate and off the houses.

**FISH** (id, x, z, heading in radians, along (cos, sin)). Every jump stays at least 3 inside the chocolate (the worst point is -18.46), is off the bridges and their ramps (+3), the platforms (+3), the island (+3), and at least 8 from the dock tips.

| Fish | Point | Heading |
|---|---|---|
| River_W1 | (-100, -224) | 0 |
| River_W2 | (60, -226) | 0 |
| River_W3 | (300, -220) | 0.07 |
| River_M1 | (470, -60) | 1.5708 |
| River_M2 | (470, 60) | 1.5708 |
| Lake_1 | (600, 160) | 0.2 |
| Lake_2 | (655, 140) | 0 |
| Lake_3 | (700, 215) | 0 |
| Lake_4 | (620, 205) | -0.2 |
| River_E1 | (780, 190) | 0 |

### Landmarks

Along the walk: the entrance arch (-161.2, 0), the Portal (-31.2, 0), the junction (0, 0), H4 with M2, the east fork (300, 0), the Main bridge (470, 0), the harbour lake with the island (670, 170), H10's tower (530, 70), and the Gran Torta tower (748.2, 0).

M1's 67.8-stud waterfall mountain stands in the south-west corner, seen from the entrance. The river pours into the cloud wall at world (1532, 192).

## Tight spots, with the arithmetic

| Spot | Arithmetic | Margin |
|---|---|---|
| M1 in the plot | depth(-219.8, -219.8) = 260 - 219.8 = 40.2; rule ≥ r - 0.5 = 40.0 | 0.2; exact literals, not computed, and it is what closes the corner |
| River starts in the pool | outlet to pool = (49.6671 - 37.6671) x 0.75 = 9.00; rule ≤ 8.25 + 1 = 9.25 | 0.25 |
| Waterfall | fall to M1 = 31.0 x 0.75 = 23.25 < 40.5; fall to pool = 6.67 x 0.75 = 5.00 < 8.25; top 25.29 within 15..67.82 | |
| Point 3 in the plot | depth(-60, -225) = 35; 35 - 64/2 = 3.0; rule ≥ 2 (point 5 the same) | 1.0 |
| Left route over the channel | (40, -182) to RIVER[4] (40, -224): 42 - 32 = 10.0; rule ≥ 7 | 3.0 |
| North route by the east stretch | (575, 125) to point 13 (575, 195), leg 13-14 r 60: 70 - 60 = 10.0; rule ≥ 7 | 3.0 |
| Top bridge against the bend | leg 11-12 capsule r 45 round (470, 175); at z 125 the route is 50 away, so liquid < 7 only where \|Δx\| ≤ √(52² - 50²) = 14.3, inside the deck's ±34 | 19.7 |
| Every deck's span | the reach is 60 wide: wet ±30, liquid ≤ 1 to ±31, deck ±34; deck ends at liquid 4.0; piers at liquid ≥ 2.0 | 3 |
| Bridge clearance | 12.5 - 0.4 - 3.5 = 8.6 ≥ 8; raft top 6.79 | 1.81 over the raft |
| Nest C8 | (105, -183) to leg 4-5 ≈ 41.65; 41.65 - 32 = 9.65; rule ≥ 6 | 3.65 |
| Post candyNestC3 (kept) | (-129, -179.6) to leg 2-3 ≈ 44.63; 44.63 - 32 = 12.63; rule ≥ 8 | 4.63 |
| Dock B stand | (240, -186) to leg 6-7: 37.92 - 32 = 5.92 > 0 (on land) | |
| Dock A tip | (-150, -210) to basin A (-150, -222) r 22: 12 from centre, so 10 inside; rule ≥ 8 | 2 |
| Nest C14 ring | depth(340, -166) = 260 - 166 = 94 ≤ 97.5 (C15 the same) | 3.5 |
| E4..E6 ring | depth 220 ≥ 208 | 12 |
| Syrup, nest C10 | (-52, -167) to (-26, -176) r 16: √(26² + 9²) = 27.51 ≥ 22 | 5.51 |
| Syrup, post candyPostC10 | (-40, -159) to (-26, -176): √(14² + 17²) = 22.02 ≥ 18 | 4.02 |
| Syrup, nest C6 | (55, -168) to (26, -176): 30.08 ≥ 22; to (0, -162) r 24: 55.3 ≥ 30 | |
| Posts apart | candyPostC8 (97, -174) to candyPostR6 (131.8, -153.6): √(34.8² + 20.4²) = 40.34; closest pair overall C7/C13 38.7; rule ≥ 30 | 8.7 |
| H10 | (530, 70) r 15; the reach edge is at x 500: 30 - 15 = 15 ≥ 2 | 13 |
| Boss ground | liquid at (748.2, 0) = 195 - 60 = 135.0 ≥ 76; plaza depth 860 - 806.2 = 53.8 ≤ 60; territory depth 860 - 824.2 = 35.8 ≥ 10 | |
| Pre-existing, unchanged | candyPostE3 route 38.61 ≤ wake 40 (1.39); licorice foot route clearance 4.92 ≥ 3 (1.92) | |

## Part budget (estimate; the dry run measures it)

Saved `Candy_Bioma_v1` starts at 2072.

| Item | Change | Basis |
|---|---|---|
| Water | -35 | river 15 joints + 15 legs x 3 (block, 2 banks) + pool = 61; lake 5; bridges 3 x 11 = 33; docks 4 x 4 = 16; total 115 against 150 |
| Paths | +11 | 19 legs + 19 drums = 38, against 27 |
| Boss, Markers, Tower | 0 | relaid at the same counts (Tower 126) |
| Nests | +34..+102 | 17 markers at 2..6 parts |
| Houses | +195 | Sweet about 32, Choco about 53, Tower about 110 |
| Mountains | +53 | M7 about 27, M8 about 26 (M1's rescale and M5's move: 0) |
| Bank filler | +166 | the 1412-stud river at bankEvery 22 |
| Edge and interior fill | +260 net | relaid under EDGE.maxParts 600 across the grown plot; old EdgeFill archived |
| Props displaced by the new chocolate | -150 | mostly the -z edge band of the west half |

**Totals**
- Saved ≈ **2640 ± 300**.
- Runtime adds about 280 (hide spots, grass, traps, island, raft, house nests), for about **2920** in Play.
- `Candy_Este_v1` goes 5 → 10 parts.

**Limits**
- The cap goes to 3400. The real run refuses an estimate above `V9_PART_TARGET` 3100.
- `layAll` pieces plus filler ≈ 1390, within MAX_NEW_PARTS 1600.
- On a fresh build, watch `Builder.MAX_PARTS` 1450 (17 more nests, 11 path parts). Raise it to 1550 only if Builder_Test fails.
- Density falls from 7.7 to about 4.5 parts per 1000 sq studs.

## File-by-file changes

### tools/

**`WildboundCandyLayout.luau`**
- `V9`, `EAST`, rectangle `depth`, `EAST_FORK`.
- `TORTA.x + V9.GROWTH`.
- The main route's end follows the Torta.
- `nestAt`: 4 moved and 17 new NESTS.
- Routes `south` and `north` and their `ROUTE_ORDER` rows.
- KEEP_CLEAR loses the gate row.
- The plot comment becomes 412..1532.

**`WildboundCandyV3Layout.luau`**
- `VERSION` 5, `V9 = { EAST }`, `V9_MARK`.
- `M1_KIT`, `M1_V8` record, `kitPoint`.
- MOUNTAINS (M1, M5, M7, M8).
- POOL, WATERFALL and RIVER[1] by `kitPoint`.
- RIVER: 16 points.
- LAKE: 5 discs.
- `jointRadius`.
- BRIDGE_BUILD (deck 12.5, ramp 28, pier) and BRIDGE_ROWS (3, gaps {}).
- HOUSES (10).
- DOCKS (4, plain rows), `RAFT.clearance`.
- PLATFORMS, ISLANDS, CRYSTAL_HILLS (x = EAST - 2).
- `plotDepth` and the plot clip in `liquidDistance`; `raftBlocks`.
- BIOME_PART_CAP, V9_PART_TARGET, MAX_NEW_PARTS.
- BACKDROP comment.
- Remove `withM1`, `M1_DX`/`M1_DZ`, `RIVER_V7`, `RIVER_TOP_Z` and `withDisc` docks.

**`WildboundCandyV3Builder.luau`**
- `layLiquid` drums use `V3.jointRadius(i)`.
- `layBridge` lays the 4 piers when `BRIDGE_BUILD.pier` is set.
- The edge hills' 4 edges and the edge-fill and interior grid run x -HALF..EAST.
- No new planner: the tool reuses `planV5` and `layAll`.

**`WildboundCandyBuilder.luau`** (fresh build only)
- Floor line 1160.
- Scatter x `-HALF + 10 .. EAST - 42`.
- The east hill band `x > L.EAST - 42`.
- Z bands unchanged.

**`WildboundCandyEast.luau`**
- `plan(L, V3)` reads `L.EAST`.
- `TAIL`, `EDGE_WALL`.
- Caps to the arm's end; side walls, end wall, MouthGuard, MouthSheet.
- `plan().arm`.
- `stripPlan`.

**Other tools**
- `WildboundCandyDuquesa.luau`: `plotDepth` via `Layout.depth`; the "54 studs from the east edge" comment re-checked (53.8 kept).
- `WildboundCandyFlyers.luau`: `halfX` bounds; the "Chocolate" hive rule.
- `WildboundCandyHouseNests.luau`: RARITY H8 Comun, H9 Rara, H10 Rara.
- **New** `wildbound-caramelo-v9-migrate.luau`.
- `studio-fresh-runner.luau` and the deploy manifest: rows for the v9 tool and `WildboundCandyV9Migrate_Test`.

### src/wildbound/

**`WildboundPraderaSites.luau`**
- `besideLocal`.
- FIXED: 4 moved posts, 8 new posts, boss posts.
- EXTRA_POSTS: +8 rows and the comment (third round).
- AMBUSH `east`, with the rectangle tests in `ambushRoll`.

**`WildboundCandyLife.luau`**
- `EAST`.
- `plotFrame` from the west edge.
- HOUSES (10).
- FLOCKS and FISH as v9 literals.
- `MIN_ALT` 72.
- Drop `LAKE_DISC_V7` and the fish scaling.

**Others**
- `WildboundCandyAmbience.luau`: `PLOT_FALLBACK.maxX` 1532.
- `WildboundCandyRaft.luau`: the `area` fallback and `Raft.new` homeDock (2 lines plus a comment).
- `WildboundCandyCookieBridge.luau`: `SINK` 14 and its comment.
- `WildboundCandyFlyersService.server.luau`: west-edge centre, `halfX` bounds, `liquid = V3.liquidDistance`.

### Studio-only copies (separate hunks, not in this worktree)

**Big4 Meadow row**
- Big4 `WildboundBiomes` and `WildboundBiomeLight` `AREAS_BIG4`: the Meadow row becomes x 412..1612.
- Their Studio-only suites take the same number: big4 `WildboundBiomeLight_Test`, `WildboundBig4Map_Test` and the big4 `WildboundBeastSight_Test`.

**Live map**
- `Workspace.WildboundCandyAnnex_Big4`'s two strips are resized by the tool.

### Docs

- This plan.
- The task log `odd/tasks/wildbound-caramelo-v9.md` (its own file; `wildbound-caramelo-v2.md` gets a pointer).
- The overview's §3 and §13 rows.

### Untouched

- Portal, TrapCake, Current, Wade, RaftService, CookieBridgeService, Nests, Smarts.
- KittenPark: `GATE_CORRIDOR` and its one-shot archive step. That step's `space` now covers x 1548..2068, which includes the new tail; the tool refuses to run again (PGM-D8).
- The v3..v8 tools.
- `test_caramelo_v3.py`.

## Migration: `tools/wildbound-caramelo-v9-migrate.luau`

### Setup and guards (v8 skeleton)

**Defaults and modes**
- `DRY_RUN = true`, `RESTORE = false`.
- Edit mode only.
- Modules come from fresh clones (`module()`).

**Asserts**
- `Layout.VERSION == 3`, `Layout.EAST == 860`, `Layout.HALF == 260`, `Layout.TORTA.x == 748.2`.
- `V3.VERSION == 5`, `V3.V9.EAST == 860`.
- `V3Builder.layAll`, `planV5`, `WATER_FOLDERS`.
- `Builder.layPaths`, `layBoss`, `layMarkers`, `syncTower`, `syncNests`, `syncNestPositions`, `layoutKey`, `treeKeepOut`.
- `East.build`, `East.stripPlan`.
- `Duq.seatPivot`.
- `Sites.FIXED.candyPostE4`, so that `treeKeepOut` sees the new posts.

**Preconditions**
- `Workspace.Candy_Bioma_v1` carries `CaramelV8`.
- If it already carries `CaramelV9`, the tool reports "already" and stops.

**Refusals, in both dry and real runs**
- Any SistemaSonriente part meets x 932..1616, z -307..301. SistemaSonriente is never touched anywhere.
- The two annex strips are not both found.
- The estimate is above `V3.V9_PART_TARGET` (3100).

### Plan (read only; the dry run prints it)

- **P1.** Archive Paths, Boss, Markers, Tower, Ground.Plaza and Nest_T1, plus any saved runtime folders (HideSpots, LicoriceGrass, CaramelTraps, LakeIslands).
- **P2.** Archive `V3Builder.planV5(root, Layout, V3)` under the v9 layout:
  - the water folders;
  - every Trees, Filler or EdgeFill model and every kit prop that stands in the v9 chocolate, on or by a bridge, or on a piece or hill.
- **P3.** Archive every other `CaramelV3` child except Trees, so the `layAll` relay may run: Mountains (M1 included), Waterfall, Houses, Licorice, Cake, Platforms, Filler, EdgeFill.
- **P4.** Archive any annex prop whose pivot lies in the growth area x 932..1532, z -263..257.
- **P5.** List anything else in the growth area as a warning; it is not touched.
- **P6.** Probe:
  - lay Paths, Boss, Markers and `layAll` into a detached scratch root;
  - count, then `:Destroy` it, the tool's only Destroy;
  - estimate = partsBefore - archived + relaid + 126 (Tower).

### Real run

One recording, "CaramelV9", inside `task.delay` and `pcall`, committed on success and cancelled on failure.

0. **Backup.** Clone `Candy_Bioma_v1`, `Candy_Este_v1`, `WildboundCandyAnnex_Big4` and the queen preview into `ServerStorage.WildboundMapArchive.CaramelV9Backup`. An existing backup is kept, with a warning.
1. **Floor.** `Ground.Floor` → size (1120, 1, 520) at (972, 0, -3).
2. **Archive.** Archive the plan into `CaramelV9Archived`.
3. **Torta.** Slide the `GranTorta` pivot +600 to world (1420.2, -3). Set `LayoutKey = Builder.layoutKey(Layout)` ("748.2,0,42").
4. **Relay.**
   - `layBoss`, `layPaths` (6 routes), `layMarkers`.
   - `V3Builder.layAll(root, { Layout, V3, kitV3, kitSpec, Kit, library, keepOut = Builder.treeKeepOut(Layout), relay = true })`. This lays the mountains with M1's waterfall at 0.75, the river with its pool, the lake and basins, the 3 raised bridges with piers, the 4 docks, 10 houses, licorice, cake, platforms, bank filler, pink hills and edge and interior fill. The old Trees are kept.
   - `syncTower` (Tower and T1).
   - `syncNestPositions` moves C6, C8, C10 and C13.
   - `syncNests` adds the 17 new markers.
5. **Queen preview.** Move it to `Duq.seatPivot`.
6. **Strips.** `East.stripPlan` resizes both annex strips to x 412..1612.
7. **Cloud wall.** `East.build(Workspace, Layout, V3)` conforms 5 parts and creates 5.
8. **Marks.**
   - Set `root.CaramelV9 = 1`.
   - Publish `WildboundCaramelV9Summary` as JSON: archived, relaid, created, partsBefore, partsAfter, estimate, target, overCap.
   - A second `East.build` must report created 0 and changed 0.

**Not touched:** the Portal, the Pradera marker, the TrapCake spots, Pueblo Gatito, the other arms.

**Re-planned at server start:** the island, hide spots, grass, traps, house nests (H3/H6 follow, and H8-H10 get one each) and the raft.

**Idempotent and reversible**
- A second run says "already".
- A failure is cancelled.
- Ctrl+Z works in the same session.
- `RESTORE = true` needs the `CaramelV9` mark and the backup. It moves the live roots into `WildboundMapArchive.CaramelV9Reverted` and clones the backups back, in one recording, "CaramelV9Restore". It goes with a git revert of the v9 modules.

### Deploy order

1. Deploy the modules and patch the Studio big4 rows.
2. Run every suite below in Studio.
3. Dry run.
4. Real run, in the same Edit session.
5. Play checks:
   - walk to world x 1530;
   - sail from dock A to the mouth and back, under all 3 bridges;
   - call the raft from dock D;
   - crack Top with an egg while hunted;
   - stand under a raised deck while a creature hunts you (ground rays);
   - bees over the bridges;
   - the wall clamp;
   - walk the stretched strips to x 1612 (walls);
   - the MouthSheet look;
   - M1 and its foot basin;
   - the part count in Play.
6. The owner saves.

## Test plan

### Deliberately changed (CL-Dn notes in each suite)

**WildboundCandyLayout_Test**
- S2: plot 412..1532 inside the arm (≤ 1612), `EAST` 860; CENTRE and HALF unchanged.
- Rings: the rectangle depth examples.
- S4: territory by the rectangle depth; `EAST_FORK` added to the safe points.
- S5 and CH3 / GT2 counts: 45 (19/19/6/1), 44 live.
- GT1: same rule (plaza ≤ 60 from the east edge), now 53.8 via the rectangle.
- V8-D1: the Torta pin 148.2 → 748.2 (the transform stays as a record).
- K-D2: the gate row is gone; 2 KEEP_CLEAR rows.

**WildboundCandyV3Layout_Test**
- V3-1: VERSION 5; `V9` copy; `M1_KIT` pinned to KitSpec.
- V3-2:
  - the river leaves M1's outlet in the south-west corner and ends on the east edge;
  - widths ≥ 50 except point 1;
  - widest ≥ 100;
  - length ≥ 1300;
  - `depth - w/2 ≥ 2` but at the last point;
  - samples wet where depth > 0.5.
- V3-3: the waterfall numbers via `kitPoint`.
- V3-4: crossed routes main, north, south; one raised deck per crossed leg; every route sample at liquid ≤ 0 on a deck, < 7 on a deck or ramp.
- V3-7: 5..10 houses, every quarter.
- V3-8: ≥ 3 docks on both banks; tips ≥ 50 apart; homeDock valid.
- V3-9: platforms in discs 1 and 2.
- V3-12: no bridge has gaps; sideRamp ≤ 25°.
- V3-13: 4 docks as stand, ramp and deck.
- V3-14: rewritten as the barrier flood fill (CL-D5).
- V3-15: hills at x = EAST - 2.
- V3-16: the backdrop and record checks use `EAST`.
- V3-17: v9 widths (points 3-7 = 64, 8-11 = 60, 12 = 90, 13 = 110, 14-16 = 120); 5 discs with their radii; decks 68; open hull water ≥ 90,000 one-stud cells (port: 102,390).
- V3-18: v8 pins → v9 pins (RIVER[1], [10], [11], [16], the bridge centres, the dock rows).

**WildboundCandyRaft_Test**
- RF1: the real layout has ≥ 3 docks; homeDock is any valid index.
- RF15: every river point but the last floats a hull.
- RF4 and RF16 unchanged (fallback).

**WildboundCandyCurrent_Test**
- CU2: ≥ 10 open legs (12); the outlet flows east.
- CU3: the dry points (-150,0), (150,100), (100,-50), (-100,-50) and (60,150) stay dry; discs flow downstream (vx > 0).
- CU4: the grid covers the whole plot, base points every 2 studs, neighbours 1 stud away.
- CU5: legs 6 and 10.
- CU6 and CU7: `#V3.DOCKS`.
- CU8: leg 7; starts (-100,-224), (470,60), (700,190).

**Other changed suites**
- **CookieBridge_Test:** CB1, CB4, CB7, CB8 and CB11 junction ids become {"Main"}. CB10 passes with SINK 14.
- **Island_Test:** IS1 and IS2 re-run (they hold by construction); IS3 uses `#V3.DOCKS`.
- **V3Builder_Test:** B4 docks = `#V3.DOCKS`; the part formula with piers; the RIVER and DOCKS index uses at 419, 445, 594 and 677.
- **Life_Test:**
  - CL1: 10 houses, `EAST`;
  - CL3: rectangle bounds `x + reach ≤ EAST - 5`, MIN_ALT 72;
  - CL4: houses equal V3;
  - CL5: the v9 fish;
  - line 148: rectangle;
  - CL7 / line 251: `plotFrame(700, 0, -50, 400, 1, 400).x == 760`.
- **Ambience_Test** 152-157: fallback 412..1532.
- **East_Test:** every 932, 940, 948 and 1468 literal → 1532, 1540, 1548 and 1612. The v8-tool source pins stay.
- **Duquesa_Test** 216, 303, 306, 546-557: east probe at CENTRE.x + EAST + 5; summit +600.
- **Builder_Test** 108: floor size and position.
- **Grass_Test** 178, **HideSpots_Test** 140, **Traps_Test** 214: edge probe (EAST - 2, 60); rectangular fake floors.
- **Nests_Test:**
  - 473: EAST + 60;
  - 569: AMBUSH `east`;
  - 725: `post.x < 1532`;
  - EXTRA_POSTS 16 → 24;
  - guardian map 9 → 12;
  - CH3 live 27 → 44.
- **HouseNests_Test:** H8-H10 rarities.
- **BeastDonGlaseon_Test** 403-416: 770.2 → 1370.2, 820.2 → 1420.2.
- **Studio-only:** big4 BiomeLight_Test, Big4Map_Test, BeastSight_Test (Meadow maxX 1612).

**Re-run expecting a pass:** BeastSites_Test, Tower_Test, Wade_Test (deck heights), Portal_Test, TrapCake_Test, Flyers_Test, Smarts_Test, Kittens_Test, KittenPark_Test.

### New

**Layout_Test**
- V9-1: EAST and the depth examples; Torta = v8 + 600; plaza 53.8; CENTRE and ENTRANCE unchanged.
- V9-2: the 17 new nests are live, in their rings, reachable, ≥ 96 from the boss and ≥ 80 from the entrance.
- V9-3: south and north start at `EAST_FORK` on the avenue, lie west of the Torta, keep ≥ 83 from the boss and stay at depth ≥ 20.
- V9-4: the 3 new Epica are on the cake bank; their mean x exceeds the new Rara's and Comun's.

**V3Layout_Test**
- V3-19: raised bridges. Underside ≥ RAFT.clearance; ramps ≤ 25°; no gaps; wet span inside the deck; deck ends and piers dry.
- V3-20: `raftBlocks`. The real bridges never block; a fake low bridge does; outside the plot liquid ≥ 0.
- V3-21: the barrier flood fill, and the banks of the docks (A, B entrance; C, D cake).
- V3-22: raft reach from dock 1's tip to every hull cell, every tip, the pool and x ≥ EAST - 5.
- V3-23: every tip ≥ LAKE_BLEND inside a disc; basins 3-5 inside the band.
- V3-24: POOL, WATERFALL and RIVER[1] equal `kitPoint` of M1. `kitPoint` at the `M1_V8` row reproduces the v8 pool (-8.44, 219.36) within 0.01.
- V3-25: `jointRadius` = max of the neighbours' widths / 2; no drum at the last point.

**Other suites**
- **Raft_Test** RF17: homeDock 3 and 4 accepted; 0, 5, nil and 1.5 → 1.
- **Raft_Test** RF18: `area` uses `raftBlocks`; a fake layout without it keeps bridge walls.
- **Current_Test** CU11: flows west → east; 1.5 at every dock tip and disc centre.
- **V3Builder_Test**
  - B-V9-1: `layLiquid` uses `jointRadius`;
  - B-V9-2: 4 piers per raised bridge on dry land;
  - B-V9-3: the edge fill and filler reach x > HALF.
- **East_Test**
  - E-V9-1: the v9 plan numbers and the 10 parts;
  - E-V9-2: `stripPlan` (found by geometry, 0 new parts);
  - E-V9-3: the mouth parts appear only when the river ends on the edge, with z from its last point.
- **Flyers_Test**
  - FL-V9-1: `halfX` bounds;
  - FL-V9-2: the "Chocolate" hive rule.
- **Life_Test** CL10: the west-edge frame keeps flocks and fish where the layout puts them on the grown floor.
- **Nests_Test** NS-V9: the AMBUSH rectangle; the third round of posts; the 12 guardian binds.
- **Duquesa_Test** DQ-V9: rectangle `plotDepth`; no "Vanish" at local x 800.

**New suite `WildboundCandyV9Migrate_Test`** (source pins):
- MG9-1: DRY_RUN true, RESTORE false.
- MG9-2: the Edit-mode assert.
- MG9-3: needs CaramelV8; reports "already" with CaramelV9.
- MG9-4: the backup, archive and reverted names; the recordings "CaramelV9" and "CaramelV9Restore".
- MG9-5: exactly one `:Destroy`; the SistemaSonriente bounds refusal; the target refusal.
- MG9-6: fresh-clone `module()`; the VERSION and EAST asserts; uses `planV5`, the `layAll` relay, `stripPlan` and `East.build`.

## Open risks

1. **Width.** The west channel is 50..64 (63.5 average over its legs; 76.7 overall), the low end of 5x. Widening it means moving the left route's bottom leg and nests C3, C10 and C12.
2. **The raft home is slow.** The flow runs away from home: about 83 s upstream from dock D to dock A, against 59 s walking the avenue. If the owner wants a raft escape home, the cheap lever is RIVER_SPEED or the raft's SPEED, tuned in Play.
3. **Long walks.** The cake is at world x 1420, and the only return portal is still at the hub side (640.8, -3).
4. **Part count and performance are estimates.** About 2640 saved and about 2920 runtime. Mobile, frame rate and StreamingEnabled reach are unknown.
5. **Bridge clearance and refuge.**
   - Clearance is inferred from the kit raft's measured height; the seated avatar's head is not in the repo (estimated 2.6 to spare).
   - Creatures' ground rays may hit a raised deck, so the strip under a bridge could act as a refuge. This is a Play check.
   - A cookie fall is now 12.5 studs, with no fall damage.
6. **M1 at 0.75 has never been seen.** Its foot basin (drum r 25) covers the kit pool and the front skirt. The kit's translucent pool may fight the laid drum.
7. **Tight literal margins.** M1 depth 0.2, outlet to pool 0.25, points 3 and 5 at 1.0. They are exact literals and safe numerically, but any later nudge of M1 or the channel must re-run V3-2 and V3-3.
8. **The barrier holds inside the plot only, as today.**
   - The annex strips along both long sides (40 wide) and the ground west of x 412 can be walked round.
   - M1's real mesh may be narrower than its r 40.5.
9. **SistemaSonriente.** Its x extent is unknown; the tool refuses if it meets the growth area.
10. **Studio-only big4 rows** are hand patches. The wb-big4 branch drift continues.
11. **Seeded relay.** The `layAll` relay re-lays the west's filler, edge fill and houses at seeded spots, which changes the look in the west.
12. **Sparser runtime.** Hide spots, grass and traps keep their TARGET counts over 2.15x the area. +8 encounters add server load.
13. **Chocolate share 19.1 %.** That makes a bee refuge and a wading penalty; ground creatures are not slowed.
14. **Nothing has run in Studio yet.** The C# port is the only verification. The suites, the flood fills, CU4 and the budget must run in Studio.

## Left for later, deliberately

- **PD1, the other three arms.** Forest W, Mountains N and Pueblo Gatito S grow to 600 x 1200 as their own tasks; until then they look shorter than Caramelo. This plan does not touch them, their annexes or their Biomes rows.
- A second portal station in the east, which needs a Portal module change.
- Invisible walls along the plot's long sides, to make the barrier absolute.
- Removing the dead `Layout.LAKE` / `Layout.BRIDGE` syrup data and its tests.
- Refreshing `test_caramelo_v3.py`, which needs Python.
- Tuning: the river's flow direction and speed, and `Cookie.FALL_SECONDS`.
- Classic (non-big4) mode, which stays unsupported for Caramelo v9.
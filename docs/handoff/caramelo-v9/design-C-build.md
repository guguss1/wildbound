# Caramelo v9, the safest-build design: a longer plot and a river 5 times wider that the raft sails end to end

Everything here is local to the plot unless it says "world" (world = local + (672, -3)). In the code's convention +z is "north". In big4 terms +z faces Pueblo Gatito and -z faces the Mountains arm.

I checked the geometry with a C# port of the V3Layout helpers: capsule `riverDistance`, `liquidDistance`, `nearBridge`, `onBridge`, `routeDistance`, the rectangle `depth`, the clearances and current flow. It runs every rule of V3-2..V3-17 and the Layout_Test nest rules, plus four flood fills: the barrier, raft reach, current smoothness and Life. Result: **0 failures**.
- Script: `C:\Users\Agustina\AppData\Local\Temp\claude\80e2a77a287fbcbe\6e13884a-c13d-46c1-86d0-627c2213786c\scratchpad\und\v9safe\Geo.cs`
- Runner: `...\v9safe\run.ps1` in the same folder. Run it with the en-US culture.
- It is a port, not the Luau suites. The suites must still run in Studio.

## 0. Decisions (V9-D1..D12)

| Id | Decision |
|---|---|
| D1 | Plot = **CENTRE kept (672, -3) and one new number, `Layout.EAST = 860`**. HALF stays 260: it is now the west half-length and the z half-length. The plot is world x 412..1532, z -263..257 (1120 x 520). |
| D2 | `depth(x, z) = min(x + HALF, EAST - x, HALF - abs(z))` (distance to the nearest edge of the rectangle). |
| D3 | The river runs west to east. It starts at the source mountain M1 (L kit, scale 0.6) in the south-west corner. It runs as a 50..64-wide channel along the -z edge (west half), turns into a straight 60-wide north-south reach at x 470, and widens to 120 along the +z edge to its mouth on the east edge (under the cloud wall). It is 1408.7 long. It stays a barrier: the entrance and the Gran Torta are on opposite banks. |
| D4 | Three **raised bridges** cross the north-south reach at right angles: Top (cookie), Main (never breaks) and Bottom (cookie). Each has deck top 12.5, ramps 28, deck 64 and no rail gaps. The raft passes under all of them. |
| D5 | Raft code changes by 2 lines. `Raft.area` uses `V3.raftBlocks` when the layout has it (a low deck or the plot edge blocks), otherwise `V3.nearBridge`. `Raft.new` accepts any valid homeDock index. |
| D6 | **Four docks** (A, B, C, D). Each tip sits â‰¥ 8 studs inside a lake disc. The three river docks get small "basin" lake discs, so the current is 1.5 at every tip and the existing docking rules and tests hold. |
| D7 | The Gran Torta, boss, tower, glaze, summit nest T1 and avenue end move **+600 in x**. Their relation to the east edge is kept: the plaza ends 53.8 studs from it. Their relays reuse the v8 path (LayoutKey, then syncTower). |
| D8 | The west half stays as it is. Only what the new chocolate swallows moves: nests C6, C8, C10, C13 (and their posts), houses H3 and H6, and mountain M5, whose corner M1 takes. |
| D9 | +17 nests in the east half (6 Comun, 8 Rara, 3 Epica): 28 â†’ 45. +8 extra creature posts (EXTRA_POSTS 16 â†’ 24): one per candy creature. +3 houses (H8..H10), +2 mountains (M7, M8). Two new routes, `south` and `north`. |
| D10 | One grown `Ground.Floor` part (no second floor part). The cloud wall moves to world x 1532..1548. Its floor gets a 64-stud tail to x 1612. The two annex strips are resized to x 412..1612. The big4 Meadow row (Studio only) grows to x 1612. |
| D11 | Part cap 2800 â†’ 3400. New target 3100 for the saved estimate. The dry run measures it and the real run refuses above the target. |
| D12 | Migration `tools/wildbound-caramelo-v9-migrate.luau`: needs CaramelV8, marks CaramelV9, has a dry run, a backup, an archive, one undo step, and a RESTORE mode. Most of the rebuild is one `V3Builder.layAll(relay = true)` call, an existing and tested path. |

## 1. Plot representation, and why

- **Kept:** `CENTRE (672, -3)` and `HALF 260`, now meaning the west half-length and the z half-length. Also kept: `ENTRANCE (-HALF, 0)`, the PORTAL, `FLOOR_TOP`, and `Layout.VERSION 3` (V3Builder asserts it).
- **Added:**
  - `Layout.V9 = { GROWTH = 600, OLD_EAST = 260 }`
  - `Layout.EAST = HALF + V9.GROWTH = 860`
  - `V3.V9 = { EAST = 860 }`, a copy pinned by V3-1, like `V3.V8.HALF`
- **Why not move CENTRE:** every local literal would shift by -300. That includes 28 nests, 26 posts, `Sites.MEADOW_CENTRE`, the Portal station literal (640.8, -3), the Pradera marker, `Life.CENTRE`, the TrapCake spots, the Life flocks, fish and houses, and PortalService. With CENTRE kept, none of these change.
- **Why not HALF_X/HALF_Z:** the west edge is pinned and growth is east only. One number for the east edge is the smallest change: every z use and west use of HALF stays correct.
- **Only the east-edge readers change:**
  - `Layout.depth`
  - the Builder floor line (:1160)
  - V3Builder edge fill and filler hills
  - V3 CRYSTAL_HILLS and the raft's plot clamp
  - `East.plan`
  - FlyersService bounds
  - `Duq.plotDepth`
  - `Sites.AMBUSH`
  - Life (bounds, frame)
  - the Ambience fallback
- **Rarity rings are unchanged** with the new depth: 0-97.5 Comun, 97.5-208 Rara, 208-260 Epica and Legendaria.
  - In the west half only L1's depth changes (213.2 â†’ 231.4), and it stays in its ring.
  - `depth(39, -195) = 65`, `depth(-260, 0) = 0` and `depth(0, 0) = 260` all still hold.

## 2. The river

### Points

Width w is the band width at the point. A leg is as wide as its wider end.

| # | Local x, z | w | World | Note |
|---|---|---|---|---|
| 1 | (-176.12, -224.13) | 30 | (495.88, -227.13) | outlet, derived: `kitPoint(M1, yaw, 0.6, 0.5653, -86.7)` |
| 2 | (-125, -221) | 50 | (547, -224) | M1 faces this point |
| 3 | (-60, -225) | 64 | (612, -228) | |
| 4 | (40, -224) | 64 | (712, -227) | |
| 5 | (140, -225) | 64 | (812, -228) | |
| 6 | (240, -224) | 64 | (912, -227) | |
| 7 | (330, -218) | 64 | (1002, -221) | |
| 8 | (400, -210) | 60 | (1072, -213) | bend |
| 9 | (445, -200) | 60 | (1117, -203) | |
| 10 | (470, -175) | 60 | (1142, -178) | start of the straight north-south reach |
| 11 | (470, 175) | 60 | (1142, 172) | end of the reach (350 long) |
| 12 | (510, 205) | 90 | (1182, 202) | |
| 13 | (575, 200) | 110 | (1247, 197) | |
| 14 | (650, 198) | 120 | (1322, 195) | |
| 15 | (760, 196) | 120 | (1432, 193) | |
| 16 | (860, 194) | 120 | (1532, 191) | mouth, on the east edge (depth 0) |

### Width profile
- 30 at the outlet (exempt, as point 1 is today).
- 50 â†’ 64 along the -z edge in the west.
- 60 for the bridged reach.
- 90 â†’ 120 in the east (= 5 Ã— today's 24).
- The west channel is capped at 64 by the kept left route. Its bottom leg sits at z -182, and a route must stay â‰¥ 7 from the chocolate. The band can then reach no higher than z -189; the plot edge leaves room for 69, and I chose 64.
- **Average width 76.6.** Widening the west part to 120 would need the left route's bottom leg moved north and C3, C6, C10 and C12 moved. See risks.

### Source
- **M1:** `CV3_IceCreamMountain_L`, scale 0.6, r 32.4, height 54.26, at local (-228, -228) / world (444, -231).
  - It faces RIVER[2]: yaw -1.6387.
  - Depth = min(32, 1088, 32) = 32 â‰¥ r - 0.5 (31.9). Its footprint reaches past both the west edge and the -z edge by 0.4, which closes the corner (the barrier rule).
- **POOL:** the layout's own basin at kit (0.5653, -60) â†’ (-192.11, -225.22), r 20.
  - It covers the kit's own pool (22.6 out, r 6.6) and the fall.
  - It is laid as today, as the `Choco_Pool` drum.
- **WATERFALL:** kit (0.5653, -31) â†’ (-209.47, -226.40), width 9.33 (7 Ã— 0.6/0.45), top 20.23 (33.72 Ã— 0.6), faces the pool, 5 streaks, flowSpeed 12.
- **Check:** the fall is 17.40 from the pool centre (< 20). RIVER[1] is 16.03 from the pool centre (â‰¤ r + 1). V3-3 passes unchanged: W.top 20.23 â‰¥ 15 and < 54.26.
- **Code:** V3 replaces `withM1` with `V3.kitPoint` at load. There are no literals for POOL, WATERFALL or RIVER[1].

### Mouth and banks
- The last point (860, 194) lies on the east edge. The laid leg block stops at x 860, under the Veil.
- Banks inside the plot: `depth - w/2` â‰¥ 2 at every point except the last. The tightest is point 14: 62 - 60 = 2.0. Banks are still laid at w/2 + 1.2.

### Builder fix for "invisible chocolate"
In `layLiquid`, a joint drum's radius becomes `max(w_prev, w, w_next) / 2` (it was `w/2`). The laid shape then equals the rule's capsule at every width step: 20 studs at point 12, 15 at point 2, 10 at point 13. The part count is unchanged.

### Lake (5 discs)
The `V3.LAKE` order matters: [1] and [2] are the lake proper.

| Disc | Local x, z | r | Role |
|---|---|---|---|
| 1 | (670, 170) | 52 | the big lake: platforms, island, dock C |
| 2 | (580, 172) | 34 | west lobe |
| 3 | (-160, -222) | 20 | basin A |
| 4 | (240, -222) | 24 | basin B |
| 5 | (815, 170) | 32 | basin D |

- The basins lie wholly inside the river band.
- The current at all 4 dock tips and at all 5 disc centres is 1.500.

### Island and platforms
- **Island I1:** (690, 150), r 6, flat 4, foot 9.9; world (1362, 147). The raft channel all round (foot + 3) is wet â‰¤ -3.
- **Platforms:**
  - CookieM (580, 170) r 6.7, in disc 2
  - CookieL (650, 180) r 11.7, in disc 1
  - CookieS (700, 185) r 3.9, in disc 1
  - CookieS (630, 150) r 3.9, in disc 1

### Current
Unchanged code: JOIN 6, EDGE 2, speed 4 on the river, 1.5 in the lake. The flow runs west to east. The worst direction change over the whole plot is **7.30Â°/stud** at (527, 149), over 220,484 checks (CU4's limit is 15).

## 3. Barrier and banks

There is a new rule. A dry flood fill on a 2-stud grid starts at the entrance. It counts cells inside the plot with liquid â‰¥ 0, treats M1's footprint as solid and ignores bridges. **It never reaches the Torta.**

| Bank | Contents |
|---|---|
| Entrance bank | the west half, the east wedge x 260..440, docks A and B, nests C14, C15, R12-R15, E4 |
| Cake bank | x â‰¥ 500 below the +z reach: the Torta, docks C and D, nests C16-C19, R16-R19, E5, E6 |

The only dry links between the banks are the three bridges. The other ways across are wading and the raft.

## 4. Routes

Path width 14.

| Route | Points | Notes |
|---|---|---|
| main | (-260,0) (-143,0) (0,0) (690.2,0) | The last point is TORTA.x - 58. The avenue leg is 690.2 long. |
| left | unchanged | |
| right | unchanged | |
| deep | unchanged | |
| south (new) | (300,0) (320,-125) (640,-125) (670,-200) | |
| north (new) | (300,0) (320,125) (620,125) | |

- `ROUTE_ORDER` = main, left, right, deep, south, north.
- `RETURN_ROUTES` stays left, right.
- Every route point has x < TORTA.x (GT1).
- Least liquid on a route, off the bridges: left 10.00 at (40, -182) (needs â‰¥ 7); north 13.00 at (580, 125); south 31; main 30.4.

## 5. Bridges

- **Build:** `BRIDGE_BUILD = { width 15, deck 12.5, ramp 28, gapWidth 8, sideRamp 28 }`. Every row has `gaps = {}`.
  - Ramps: atan(12.5 / 28) = **24.06Â°** (â‰¤ 25).
  - Deck underside: 12.1 above the floor, which is 8.6 above the surface.
  - Raft top: surface + 6.64 + 0.15 bob. Clearance **1.8**. The seated rider's head (about +6) clears by about 2.6.
- **New field:** `V3.RAFT.clearance = 8`. A deck whose (deck - 0.4 - 3.5) < 8 is a wall for the raft. None are in v9.

| Id | Route | From â†’ to | at | Length | Deck centre local / world |
|---|---|---|---|---|---|
| Top | north | (320,125)â†’(620,125) | 150 | 64 | (470,125) / (1142,122) |
| Main | main | (0,0)â†’(690.2,0) | 470 | 64 | (470,0) / (1142,-3) |
| Bottom | south | (320,-125)â†’(640,-125) | 150 | 64 | (470,-125) / (1142,-128) |

- **Arithmetic for the spans:**
  - Over the 60-wide reach, liquid â‰¤ 1 runs to |along| 31. The deck half is 32 (V3-17-style rule, margin 1). The deck ends sit at liquid +2.0, so the ramps are on land.
  - Each bridge takes 64 + 2Â·28 = 120 studs of route; the shortest leg it sits on is 300 (on-leg rule).
  - Top versus the bend: the capsule of leg 11-12 is r 45 around (470, 175). At z 125 it is 50 away, so the route centreline there is at liquid 5 (< 7). Such points must be on a bridge: they lie within |Î”x| â‰¤ âˆš(52Â² - 50Â²) = 14.3, inside the deck's Â±32.
- **Cookie bridges:**
  - Ids Top and Bottom are kept, so `Cookie.IDS` is unchanged.
  - `Cookie.SINK` 7 â†’ **14** (> 12.5 + 0.4).
  - Main is the one that never breaks. RightLast and LeftLast no longer exist.

## 6. Docks and the raft

| Dock | Stand â†’ tip, local | World stand â†’ tip | Stand-tip / deck | Stand liquid | Tip liquid | Ramp foot | Bank |
|---|---|---|---|---|---|---|---|
| A (home) | (-160,-187)â†’(-160,-210) | (512,-190)â†’(512,-213) | 23 / 18 | 11.08 | -11.88 | 21.06 | entrance |
| B | (240,-186)â†’(240,-208) | (912,-189)â†’(912,-211) | 22 / 17 | 5.92 | -16.04 | 15.89 | entrance |
| C | (670,104)â†’(670,128) | (1342,101)â†’(1342,125) | 24 / 19 | 14.00 | -10.00 | 24.00 | cake |
| D | (815,124)â†’(815,148) | (1487,121)â†’(1487,145) | 24 / 19 | 10.89 | -13.11 | 20.88 | cake |

- **Rows:** `V3.DOCKS` become plain local rows (no `withDisc`). `V3.RAFT = { asset "CV3_BananaRaft", homeDock 1, clearance 8 }`.
- **`WildboundCandyRaft.luau` changes:**
  - `area.inside` becomes: `local blocks = V3.raftBlocks or V3.nearBridge` â€¦ `return V3.liquidDistance(lx, lz) <= -r and not blocks(lx, lz, r)`.
  - `Raft.new` becomes: `homeDock = (type(homeDock) == "number" and docks[homeDock] ~= nil) and homeDock or 1`.
  - Fake layouts without `raftBlocks` keep bridges as walls, so RF4 and RF16 are unchanged.
- **New V3 helpers:**
  - `V3.plotDepth(x, z)` (rectangle, from `V3.V8.HALF` and `V3.V9.EAST`).
  - `V3.raftBlocks(x, z, reach)`: true when `plotDepth < reach`, so the raft never sails past x 857 into the band. Also true when it is near a bridge whose underside is below the raft clearance (none in v9).
- **Reach (flood fill):** from A's tip, the raft reaches **all 25,635 hull cells** on the 2-stud grid. That includes the pool, docks B, C and D, and x from -208 to 856.
- **Unchanged:** RaftService, the call points (one per dock), the call (it teleports, so no path is needed) and the 8 s respawn to home dock A.

## 7. Gran Torta, boss, tower

| Item | Local | World |
|---|---|---|
| TORTA (r 42) | (748.2, 0) | (1420.2, -3) |
| BOSS centre | (748.2, 0) | (1420.2, -3) |
| BOSS home | (698.2, 0) | (1370.2, -3) |
| Glaze puddles | (748.2, 52), (804.2, 9), (709.2, 34) | (1420.2, 49), (1476.2, 6), (1381.2, 31) |
| Summit T1 | (748.2, 9.4) | (1420.2, 6.4) |

- TORTA.x = `fromV7Local(114) + V9.GROWTH`. Plaza 58 and territory 76 are kept. The stair is derived (67 steps).
- The plaza ends 53.8 from the east edge (as in v8). The territory ends 35.8 from it.
- Liquid at the boss centre is 135.1 (â‰¥ 76). The nearest chocolate is disc 1: âˆš(78.2Â² + 170Â²) - 52 = 135.1. The plaza edge is 77.1 from the chocolate.
- **PraderaSites:** bossHome (1370.2, -3), bossTerritory (1420.2, -3). AMBUSH.bossClearStuds 126 is measured from the new territory centre.
- **Portal:** unchanged at (-31.2, 0) / world (640.8, -3), so `WildboundPortal.luau` does not change.

## 8. Nests (45)

Each row is id, rarity, local, world. The checker's least margins are in section 14.

**Unchanged (24):**
- C1 (-208,-23.4)
- C2 (-182,31.2)
- C3 (-117,-171.6)
- C4 (-80.6,169)
- C5 (78,197.6)
- C7 (6.5,184.6)
- C9 (-175.5,-80.6)
- C11 (-39,195)
- C12 (-169,-130)
- R1 (-101.4,-39)
- R2 (-101.4,44.2)
- R3 (-58.5,-120.9)
- R4 (-26,123.5)
- R5 (114.4,145.6)
- R6 (124.8,-158.6)
- R7 (-150.8,75.4)
- R8 (-143,123.5)
- R9 (-78,91)
- R10 (-13,-58.5)
- R11 (46.8,96.2)
- E1 (-44.2,-26)
- E2 (-44.2,31.2)
- E3 (0,46.8)
- L1 (46.8,-28.6), still event-only

**Moved (4)**, using a new `nestAt(id, rarity, x, z)` helper with v9 local literals:

| Nest | New local | New world | Was |
|---|---|---|---|
| C6 Comun | (13, -166) | (685, -169) | (13, -210.6) |
| C8 Comun | (110, -178) | (782, -181) | (78, -221) |
| C10 Comun | (-40, -166) | (632, -169) | (-78, -210.6) |
| C13 Comun | (150, -172) | (822, -175) | (130, -195) |

**New (17):**

| Nest | Local | World |
|---|---|---|
| C14 Comun | (340, -164) | (1012, -167) |
| C15 Comun | (350, 166) | (1022, 163) |
| C16 Comun | (530, -170) | (1202, -173) |
| C17 Comun | (620, -172) | (1292, -175) |
| C18 Comun | (700, -215) | (1372, -218) |
| C19 Comun | (575, -172) | (1247, -175) |
| R12 Rara | (280, -80) | (952, -83) |
| R13 Rara | (280, 80) | (952, 77) |
| R14 Rara | (400, -150) | (1072, -153) |
| R15 Rara | (410, 150) | (1082, 147) |
| R16 Rara | (600, -75) | (1272, -78) |
| R17 Rara | (660, -95) | (1332, -98) |
| R18 Rara | (560, 95) | (1232, 92) |
| R19 Rara | (530, -80) | (1202, -83) |
| E4 Epica | (370, 38) | (1042, 35) |
| E5 Epica | (580, 40) | (1252, 37) |
| E6 Epica | (650, -40) | (1322, -43) |

**Totals:** 19 Comun, 19 Rara, 6 Epica, 1 Legendaria (plus T1 on the summit). All are live, all have x < 748.2, all are â‰¥ 96 from the boss (territory + 20), â‰¥ 80 from the entrance and â‰¥ 20 apart.

**House nests** get `HouseNests.RARITY` entries: H8 Comun, H9 Rara, H10 Rara.

## 9. Creature posts (`WildboundPraderaSites`)

- **Moved with their nests** (offsets kept), written with a new helper `besideLocal(lx, lz, dx, dz)` = MEADOW_CENTRE + local + offset:
  - candyPostC6 (675, -161)
  - candyPostC8 (777, -169)
  - candyPostC10 (644, -161)
  - candyPostC13 (810, -174)
  - bossHome and bossTerritory as in section 7
- **New FIXED keys and EXTRA_POSTS rows** (third round, one per creature):

| Key | World | Creature |
|---|---|---|
| candyPostE4 | (1054, 35) | Gomibu |
| candyPostR16 | (1260, -78) | Flanfuria |
| candyPostE5 | (1264, 37) | Tortidragon |
| candyPostR12 | (964, -83) | Mochimiau |
| candyPostC16 | (1202, -161) | Canelin |
| candyPostR13 | (964, 77) | GatoRepartidor |
| candyPostC18 | (1360, -218) | Mielita |
| candyPostR15 | (1070, 147) | Flanin |

- Each is 12 from its nest. The three guardian posts bind E4, R16 and E5 at 12.0 (BIND_RADIUS 20).
- The nearest other post is â‰¥ 99.3 away.
- **AMBUSH:** add `east = 860`. `ambushRoll` changes:
  - inside means `lx >= -half and lx <= east and abs(lz) <= half`;
  - the spot is refused when `min(sx + half, east - sx, half - abs(sz)) < edgeStuds`.

## 10. Houses, mountains and other pieces

**Houses** (Life copies these exactly):

| House | Kit, scale | Local | r | Status |
|---|---|---|---|---|
| H1 | Sweet 1.4 | (-192.4, 215.8) | 28 | unchanged |
| H2 | Tower 1, turn 180 | (-130, 227.5) | 15 | unchanged |
| H3 | Choco 1.4 | (-10, -118) | 22.4 | moved, was (-205.4, -195) |
| H4 | Sweet 1 | (231.4, 130) | 20 | unchanged |
| H5 | Tower 1.4, turn 180 | (-218.4, -106.6) | 21 | unchanged |
| H6 | Choco 1 | (45, -125) | 16 | moved, was (195, -221) |
| H7 | Sweet 1 | (143, 231.4) | 20 | unchanged |
| H8 | Sweet 1 | (380, -60) | 20 | new |
| H9 | Choco 1 | (600, -200) | 16 | new |
| H10 | Tower 1, turn 180 | (530, 70) | 15 | new |

There is still a house in every quarter. All doors pass (â‰¥ 4 from the chocolate, depth â‰¥ 5).

**Mountains:**

| Mountain | Kit, scale | Local | r | Status |
|---|---|---|---|---|
| M1 | L 0.6 | (-228, -228) | 32.4 | source, see section 2 |
| M2 | | (234, -117) | 14.2 | unchanged |
| M3 | | (98.8, 243.1) | 13.1 | unchanged |
| M4 | | (214.5, -156) | 13.1 | unchanged |
| M5 | M 0.37 | (800, -236) | 13.1 | moved |
| M6 | | (-243.1, 243.1) | 13.1 | unchanged |
| M7 | L 0.45 | (790, -170) | 24.3 | new, height 40.7 |
| M8 | M 0.4 | (300, 230) | 14.2 | new, height 24.1 |

**Other pieces:**
- Licorice (-161.2, 0) and Cake (-195, 145.6): unchanged.
- **CRYSTAL_HILLS**, at x = EAST - 2 = 858 (they straddle the edge):
  - Hill_1 z -247, scale .5, r 17.75
  - Hill_2 z -190, scale .45, r 16
  - Hill_3 z -125, scale .5, r 17.75
  - Hill_4 z -60, scale .45, r 16
  - Hill_5 z 60, scale .45, r 16
  - Hill_6 z 105, scale .28, r 9.94
- **KEEP_CLEAR:** the pond and hive rows only. The stale "Cloud gate" row is dropped (PGM-D8).
- **Backdrop:** stays empty.

## 11. Ground, wall, strips, big4, portal

- **Ground.Floor** (one part): Size (1120, 1, 520) at world (972, 0, -3), top 0.5. Also `Builder.build` :1160 becomes `Vector3.new(L.HALF + L.EAST, 1, 2 * L.HALF)` at `world((L.EAST - L.HALF) / 2, top - 0.5, 0)`.
- **`East.plan`:**
  - `plot.maxX = cx + (L.EAST or half)`.
  - Band x 1532..1548, z -271..265. Collider and Veil centre x 1540.
  - New `East.TAIL = 64`: ground = x 1532..1612, z -263..257.
  - Caps x 1538..2068 at z 261..265 and z -271..-267 (`space` is legacy: 1548..2068, shift 1136).
  - New `plan.arm` = x 412..1612, z -303..297.
  - New pure `East.stripPlan(L, slabs)`: it resizes the two annex strips, found by geometry (x 412..1012 Â± 1, z -303..-263 and 257..297 Â± 1), to x 412..1612. 0 new parts.
- **big4 Meadow row** (Studio-only copies of WildboundBiomes and WildboundBiomeLight `AREAS_BIG4`): x 412..1012 â†’ **412..1612**, z -303..297 unchanged. The same number goes in their Studio-only suites.
- **Portal:** no change.

## 12. Client systems

- **Ambience:** reads `Ground.Floor` bounds, so it covers 412..1532 by itself. `PLOT_FALLBACK.maxX` 932 â†’ 1532.
- **Life:**
  - `plotFrame` is anchored on the floor's **west edge**: `x = x - sizeX/2 + Life.HALF`. The grown floor's centre (972) is no longer used.
  - Adds `Life.EAST = 860`.
  - HOUSES: the 10 rows above.
  - `MIN_ALT` 46 â†’ 59 (M1 is 54.26, plus 4).
  - **Flocks** (centre, r, alt):
    - F1 (-156, 52) r 26, alt 63
    - F2 (-104, -65) r 24, alt 66
    - F3 (78, 195) r 22, alt 62
    - F4 (169, -143) r 22, alt 65
    - F5 (-90, -140) r 20, alt 63 (moved off the river)
    - F6 (195, 156) r 20, alt 67
    - F7 (380, -110) r 24, alt 64 (new)
    - F8 (620, -50) r 22, alt 66 (new)
    - All are â‰¥ 49.7 from the chocolate.
  - **Fish** (heading in brackets):
    - River_W1 (-100, -224) [0]
    - River_W2 (60, -226) [0]
    - River_W3 (300, -220) [0.07]
    - River_M1 (470, -60) [1.5708]
    - River_M2 (470, 60) [1.5708]
    - Lake_1 (600, 160) [0.2]
    - Lake_2 (655, 140) [0]
    - Lake_3 (700, 215) [0]
    - Lake_4 (620, 205) [-0.2]
    - River_E1 (780, 190) [0]
    - Every jump passes: â‰¥ 3 inside the chocolate, off bridges, platforms, the island and docks. 2 are in the lake.
  - Flowers: unchanged.
- **CloudWall client and Sky:** no change. The Veil is found by name; the sky follows the Studio big4 row.

## 13. Server systems

| Module | Change |
|---|---|
| `WildboundCandyDuquesa.plotDepth` | `Layout.depth(x - CENTRE.x, z - CENTRE.z)`. Without this, the queen would "Vanish" east of x 932. |
| `WildboundCandyFlyers` | (a) `inBounds` uses `bounds.halfX or bounds.half` for x. (b) `hiveSpotOk` takes an optional `liquid(lx, lz)` and returns "Chocolate" when it is < LAKE_MARGIN_STUDS. My check found 52 of 387 valid hive candidates in or near the chocolate (by the bridges and along the left route over the channel). |
| FlyersService | Centre anchored on the floor's west edge. Bounds `{ x = 972, z = -3, half = 260, halfX = 560 }`. Passes `V3.liquidDistance` (requires ServerStorage.WildboundCandyV3Layout). |
| Smarts and Duquesa wall clamps | No change; they read the live Collider. |
| Current, Wade, CookieBridgeService, RaftService, Nests, TrapCake, Portal | No change. |
| HideSpots, Grass, Traps, Island, HouseNests | Re-plan at server start from the layout. Their candidates follow `ROUTE_ORDER`, so the new routes are included. |

## 14. Clearance check: tight spots, with the arithmetic

Leg capsule radius = max(w_a, w_b)/2. All of these pass.

- **Post candyNestC3 (-129, -179.6), margin 1.59 (needs 8):**
  - It lies before leg 2-3 starts, so the nearest point is RIVER[2] (-125, -221): âˆš(4Â² + 41.4Â²) = 41.59. Leg 2-3 has r 32, so 41.59 - 32 = **9.59** â‰¥ 8.
  - Via leg 1-2 (r 25): cross distance 41.59 - 25 = 16.59.
- **Left route at (40, -182) against leg 3-4:** RIVER[4] (40, -224) gives 42 - 32 = **10.0** â‰¥ 7.
- **C14 depth 96.0:** inside the Comun ring (â‰¤ 97.5), margin 1.5. Liquid via leg 7-8: cross 52.5 - 32 = 20.5.
- **E6 (650, -40):** depth min(910, 210, 220) = 210 â‰¥ 208, margin 2.
- **R16:** route distance 50.0 â‰¤ 52, margin 2.
- **C8 (110, -178):** leg 4-5 gives about 46.7 - 32 = **14.7** â‰¥ 6.
- **C13:** 20.9. **R15:** 60 - 30 = 30 from the reach; via leg 11-12, âˆš(60Â² + 25Â²) - 45 = **20.0**.
- **Dock B stand:** 38 - 32 = 5.92 > 0, so it is on land.
- **Island:** foot to every tip â‰¥ 15 and to every stand â‰¥ 20.
- **North route end (620, 125) against disc 1:** âˆš(50Â² + 45Â²) - 52 = 15.27 â‰¥ 7.
- **M1:** depth 32 against r - 0.5 = 31.9.
- **Pre-existing, unchanged:** the licorice foot is 4.92 from the route (needs â‰¥ 3).

## 15. Part budget

**Saved Candy_Bioma_v1 estimate**, starting from 2072 (the v8 record): 2072, then:

| Item | Change | Basis |
|---|---|---|
| Water | -47 | river 16 points: 15 joints + 45 leg parts + pool = 61; 5 discs; 3 bridges Ã— 7 = 21; 4 docks Ã— 4 = 16; total 103 against 150 |
| Paths | +11 | 19 drums + 19 legs = 38, against 27 |
| Nests | about +34..85 | 17 new |
| Houses | about +195 | kit pieces + colliders: Sweet about 32, Choco about 53, Tower about 110 |
| Mountains | about +52 | M7 and M8, about 26 each |
| Bank and house filler | about +166 | the bank filler grows with the 1408-stud river (about 66 bank samples) |
| Edge fill, net | about +260 | relaid under its 600 budget; the old EdgeFill props folder is archived |
| Displaced trees | about -150 | the -z edge band in the west |

- Saved total â‰ˆ **2600 Â± 300**. Runtime â‰ˆ +280, so about 2900 in Play.
- New constants:
  - `V3.BIOME_PART_CAP` 2800 â†’ **3400**
  - `V3.V9_PART_TARGET = 3100` (= cap - 300 for runtime). The dry-run estimate must be â‰¤ this, or the real run refuses.
  - `V3.MAX_NEW_PARTS` 1300 â†’ **1600** (layAll pieces + filler is about 1390 by the same arithmetic)
  - `V3.EDGE.maxParts` stays 600.
- Watch `Builder.MAX_PARTS` 1450 on a fresh build (17 more nests, 11 path parts). Raise it to 1550 only if Builder_Test fails.

## 16. Files that change

**tools/**
- **`WildboundCandyLayout.luau`:** `V9`, `EAST`, rectangle `depth`; `TORTA.x + GROWTH`; `nestAt` + 4 moved + 17 new NESTS; routes `south` and `north` and their `ROUTE_ORDER` entries; drop the KEEP_CLEAR gate row.
- **`WildboundCandyV3Layout.luau`:**
  - `VERSION` 4 â†’ 5; `V9 = { EAST }`; `V9_MARK "CaramelV9"`.
  - MOUNTAINS (M1, M5, M7, M8); POOL, WATERFALL and RIVER[1] via `kitPoint`; RIVER (16 points); LAKE (5).
  - BRIDGE_BUILD; BRIDGE_ROWS (3).
  - HOUSES (10, final local numbers).
  - DOCKS (4); RAFT.clearance; PLATFORMS; ISLANDS; CRYSTAL_HILLS.
  - Caps and target; `plotDepth`; `raftBlocks`.
- **`WildboundCandyV3Builder.luau`:** the joint drum radius rule; the filler hills and edge-fill grid reach `L.EAST`. No new planner: the tool reuses `planV5`.
- **`WildboundCandyBuilder.luau`:** line 1160 (floor) only.
- **`WildboundCandyEast.luau`:** `plan` reads `L.EAST`; `TAIL`; `arm`; `stripPlan`.
- **`WildboundCandyDuquesa.luau`:** `plotDepth`.
- **`WildboundCandyFlyers.luau`:** `halfX` and the liquid hive rule.
- **`WildboundCandyHouseNests.luau`:** RARITY for H8..H10.
- **New:** `wildbound-caramelo-v9-migrate.luau`.
- **`studio-fresh-runner.luau`:** a SPECS row for the new suite.

**src/wildbound/**
- `WildboundPraderaSites.luau`: FIXED, EXTRA_POSTS, AMBUSH.
- `WildboundCandyLife.luau`: see section 12.
- `WildboundCandyAmbience.luau`: the fallback.
- `WildboundCandyRaft.luau`: 2 lines.
- `WildboundCandyCookieBridge.luau`: SINK 14 and the comment.
- `WildboundCandyFlyersService.server.luau`.

**Studio-only:** the big4 Biomes and BiomeLight rows and their suites.

**Docs:** `docs/design/wildbound-caramelo-v9-plan.md`, and a "Caramelo v9" section in `odd/tasks/wildbound-caramelo-v2.md`.

**Untouched:** Portal, TrapCake, Current, Wade, RaftService, CookieBridgeService, Nests, Smarts, KittenPark (its stale `GATE_CORRIDOR` and one-shot archive step are harmless now: `space` lies in the void), the v3/v4/v5/v8 tools (they refuse on VERSION 5), and `test_caramelo_v3.py` (already stale).

## 17. Migration: `tools/wildbound-caramelo-v9-migrate.luau`

**Setup and guards (v8 skeleton):**
- `DRY_RUN = true`, `RESTORE = false`. Edit mode only. Modules are loaded from fresh clones.
- It asserts:
  - `Layout.EAST == 860`, `HALF == 260`, `TORTA.x == 748.2`;
  - `V3.VERSION == 5`;
  - `V3Builder.layAll`, `planV5`, `WATER_FOLDERS`;
  - the Builder relays;
  - `East.build` and `stripPlan`;
  - `Duq.seatPivot`;
  - the deployed `Sites.FIXED.candyPostE4` (so `treeKeepOut` sees the new posts).
- It needs the root mark `CaramelV8`. If `CaramelV9` is already set it reports `already` and stops.
- Names: summary attribute `WildboundCaramelV9Summary`; backup `CaramelV9Backup`; archive `CaramelV9Archived`; ChangeHistory recording "CaramelV9".

**Refusals:**
- SistemaSonriente has any part within x 932..1612, z -303..297.
- The two annex strips are not both found.
- The estimate is above `V9_PART_TARGET`.

**Plan (read only; the dry run reports it):**
- Archive Paths, Boss, Markers, Tower, Ground.Plaza and Nest_T1, plus any saved runtime folders (HideSpots, LicoriceGrass, CaramelTraps, LakeIslands).
- Archive `planV5(root, Layout, V3)`: the water folders and the Trees, Filler, EdgeFill and old-kit props that stand in the v9 chocolate, by a bridge, or on a piece or hill.
- Archive every other `CaramelV3` child except Trees.
- Archive any annex prop whose pivot is inside the grown plot.
- List what else occupies the growth area. These are warnings; they are not touched.
- Probe: lay Paths, Boss and Markers, plus `layAll` into a detached scratch root, count, then `:Destroy` it once (the only Destroy). Estimate = before - archived + relaid + 126 (Tower).

**Real run (deferred thread, one recording, pcall, Cancel on failure):**
- 0. Backup clones of Candy_Bioma_v1, Candy_Este_v1, WildboundCandyAnnex_Big4 and the queen preview. An existing backup is kept, with a warning.
- 1. Ground.Floor â†’ (1120, 1, 520) at (972, 0, -3).
- 2. Archive the plan.
- 3. GranTorta is slid to (1420.2, -3) with its LayoutKey set to `Builder.layoutKey(Layout)`.
- 4. Relay:
  - `layBoss`, `layPaths`, `layMarkers`;
  - `V3Builder.layAll(root, { Layout, V3, kitV3, kitSpec, Kit, library, keepOut = Builder.treeKeepOut(Layout), relay = true })`. This lays the mountains with M1's waterfall, the river, lake, basins, bridges, docks, houses, licorice, cake, platforms, filler, edge hills and edge fill. Trees are kept.
  - `syncTower` (Tower and T1);
  - `syncNestPositions` (moves C6, C8, C10, C13);
  - `syncNests` (adds the 17 new nests).
- 5. The queen preview goes to `Duq.seatPivot`. An Edit raft goes to dock A's tip.
- 6. The annex strips are resized (`stripPlan`).
- 7. `East.build` conforms the floor and tail, the Collider, the Veil and the caps (0 new parts).
- 8. `root.CaramelV9 = 1`. The summary lists counts and the parts after.

**Idempotent and reversible:**
- A second run reports `already`.
- A failure is undone (Cancel).
- Ctrl+Z in the same session undoes it.
- `RESTORE = true` (needs the CaramelV9 mark and the backup) moves the live roots into `WildboundMapArchive.CaramelV9Reverted` and clones the backups back, as one recording "CaramelV9Restore". Restore goes with a git revert of the v9 modules.

**Deploy order:**
1. Modules and the Studio big4 rows.
2. The suites.
3. The dry run.
4. The real run, in the same Edit session.
5. Play checks: walk to x 1530; sail from A to the mouth and back under the 3 bridges; call the raft from D; crack Top; bees; music at the east edge; the wall clamp; the part count in Play.
6. The owner saves.

## 18. Tests

### Changed deliberately

**Layout_Test**
- S2/V8-D1: plot 412..1532 inside the arm (â‰¤ 1612); EAST 860.
- S5/CH3/GT2 count: 28 â†’ 45 (19/19/6/1).
- V8-D1 case: the TORTA pin 148.2 â†’ 748.2.
- K-D2: the gate row is gone (2 KEEP_CLEAR rows).

**V3Layout_Test**
- V3-1: VERSION 5, V9 copy.
- V3-2: M1 in the south-west corner; ends on the east edge; minimum width 50 (point 1 exempt).
- V3-4: crossed main, north, south.
- V3-7: 5..10 houses.
- V3-8: â‰¥ 3 docks, on both banks.
- V3-12: no bridge has gaps.
- V3-14: rewritten barrier.
- V3-15: x = EAST - 2.
- V3-17: v9 widths, lake, bridge lengths 64; open hull water over the whole plot â‰¥ 90,000 one-stud cells, where my port counts about 102,500.
- V3-18: v8 pins â†’ v9 pins.

**Raft_Test**
- RF1: â‰¥ 3 real docks; any valid homeDock.
- RF15: every river point except the last floats a hull. The Aâ€“B line is kept.

**Current_Test**
- CU2: â‰¥ 10 open legs (my port counts 12); the outlet flows east.
- CU3: discs flow downstream with vx > 0 (it was "drains south").
- CU4: grid over the whole plot.
- CU5: legs 6 and 10.
- CU8: leg 7; starts (-100, -224), (470, 60), (700, 190); afloat uses `raftBlocks`.

**CookieBridge_Test**
- CB1, CB4, CB7, CB8: the junction ids become {"Main"}.
- CB10 is unchanged; it passes with SINK 14.

**V3Builder_Test:** B4 docks = `#V3.DOCKS`.

**Life_Test**
- CL1: 10 houses, EAST.
- CL3 and CL4: rectangle bounds.
- CL7: `plotFrame(700, 0, -50, 400, 1, 400).x` = 760.

**Other suites**
- Ambience_Test 152-157: fallback 412..1532.
- East_Test: every 932, 940, 948 and 1468 literal â†’ the v9 plan numbers. The v8-tool source pins stay.
- Duquesa_Test 546-557: east probe â†’ CENTRE.x + EAST + 5.
- Builder_Test 108: floor size and position.
- Grass_Test 178, HideSpots_Test 140, Traps_Test 214: edge probe â†’ (EAST - 2, 60).
- Nests_Test: 473 (EAST + 60); 569 (+ AMBUSH.east); 725 (post.x < 1532); any EXTRA_POSTS count (16 â†’ 24).
- BeastDonGlaseon_Test 403-416: 770.2 â†’ 1370.2 and 820.2 â†’ 1420.2 (the probes shift +600).
- Studio-only big4 BiomeLight, Big4Map and BeastSight suites: Meadow maxX 1612.

**Re-run expecting a pass:** Island_Test (IS1-IS3 hold by construction: docks 1 and 2 sit in basins on a straight channel), BeastSites_Test (live raycasts), Tower_Test, Wade_Test, Portal_Test, HouseNests_Test, TrapCake_Test, Builder fresh-build MAX_PARTS.

### New tests

- **Layout_Test**
  - V9-1: EAST, depth samples (860,0) â†’ 0, (800,0) â†’ 60, (300,250) â†’ 10; Torta = v8 + 600; plaza 53.8 from the edge; CENTRE and ENTRANCE unchanged.
  - V9-2: the 17 nests: ids, live, rings, reachable, â‰¥ 96 from the boss.
  - V9-3: the north and south routes start on the avenue and lie west of the Torta.
- **V3Layout_Test**
  - V3-19: raised bridges: underside â‰¥ RAFT.clearance, ramps â‰¤ 25Â°, no gaps, every deck spans its river Â±L/2.
  - V3-20: `raftBlocks`: the plot clamp; a fake low bridge blocks; the real ones do not.
  - V3-21: barrier flood fill, and the banks of the docks.
  - V3-22: raft reach flood fill from dock 1 to every tip, the pool and x â‰¥ EAST - 5.
  - V3-23: every dock tip â‰¥ LAKE_BLEND inside a disc; the basins inside the band.
  - V3-24: POOL, WATERFALL and RIVER[1] equal the M1 `kitPoint` values.
- **Raft_Test**
  - RF17: homeDock 3 and 4 are accepted; 0, 5, nil and 1.5 â†’ 1.
  - RF18: `area` uses `raftBlocks`; a fake layout without it keeps bridge walls.
- **Current_Test CU11:** flows west â†’ east; 1.5 at every dock tip.
- **V3Builder_Test B-V9:** joint radius = max of its legs' widths / 2; filler and edge fill reach x > HALF.
- **East_Test E-V9:** plan numbers, `stripPlan`.
- **Flyers_Test:** `halfX` bounds; the chocolate hive rule.
- **Life_Test CL10:** the west-edge frame.
- **Nests_Test / PraderaSites NS-V9:** the AMBUSH rectangle; 24 extras; the guardian binds.
- **Duquesa_Test DQ-V9:** rectangle `plotDepth`.
- **New suite `WildboundCandyV9Migrate_Test`** (source pins):
  - DRY_RUN true and RESTORE false by default;
  - Edit-mode assert;
  - needs CaramelV8, reports `already` with CaramelV9;
  - backup and archive names;
  - recordings CaramelV9 and CaramelV9Restore;
  - exactly one `:Destroy`;
  - the SistemaSonriente refusal;
  - fresh-clone `module()`;
  - VERSION 5 and EAST 860 asserts;
  - uses `planV5`, `layAll` relay, `stripPlan` and `East.build`.

## 19. Open risks

1. **Width.** The west channel is 50..64 (average 76.6 overall), not 120. Widening it means moving the left route's bottom leg and nests C3, C6, C10 and C12.
2. **Long walks.** The cake is now at world x 1420. The only return portal is still at (640.8, -3). A second portal station in the east would mean a Portal module change; it is a follow-up.
3. **Part count.** The figures are estimates (about 2600 saved, about 2900 runtime). The cap is raised to 3400. Mobile, streaming and frame rate are untested; StreamingEnabled is unknown.
4. **Clearance under the bridges.** It is inferred from the kit's measured raft height; the seated avatar's height is not in the repo. A cookie fall is now 12.5 studs (no fall damage).
5. **Invisible chocolate.** It remains past the mouth (local x 860..920, into the band; the Collider at 864 stops players) and behind RIVER[1] (on M1's front slope).
6. **Docking.** At river docks the raft must come from upstream or across. The basins keep the current at 1.5.
7. **Studio-only big4 rows** are hand patches. The wb-big4 branch drift continues.
8. **Hives.** The chocolate rule needs FlyersService to require V3Layout. Bee density halves (MAX_HIVES 8).
9. **SistemaSonriente's x is unknown.** The tool refuses if it is in the growth area.
10. **Falls.** Players can now fall at the strip ends (x 1612), as they can today at x 1024.
11. **Seeded re-placement.** The filler and edge-fill props in the west half move (seeded relay).
12. **Sparser runtime.** Hide spots, grass and traps keep their TARGET counts over twice the area. The +8 encounters add server load.
13. **Kit at scale 0.6.** M1 has not been seen at that scale. MIN_ALT is raised to 59.
14. **Nothing ran in Studio.** My C# port is the only verification. CU4, the flood fills and the budget must be run in Studio.
15. **Classic mode** stays unsupported.


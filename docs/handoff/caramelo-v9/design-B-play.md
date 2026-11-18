# Wildbound Caramelo v9 design: the long kingdom and the raft highway

**Angle: best game.** The core loop of "steal an egg" stays the same: you go deep, you take an egg, and you carry it home. v9 adds:
- **Depth = reward and danger.** Rarity rises with distance from the hub. All 6 Epica nests and the Legendaria nest sit in the last third of the plot, around the boss.
- **The river is an S-shaped chocolate highway.** It flows *toward* the hub. Downstream the raft does 24 studs/s, which is faster than any candy creature's chase speed (20â€“23). It is the safe way home, not the fast one: walking is about as quick, but a walker gets caught. Upstream the raft does 16.
- **Three parallel lanes cross the river at two meanders, on six raised bridges.** The raft passes under every bridge. The four lane bridges are cookie bridges; the two avenue bridges never break.
- **Landmarks pace the walk** about every 150â€“250 studs: entrance, licorice arch, fork, junction/portal, Puente Medio, the Prado Alto meadow and pond, the lake with the island, Puente Hondo, the Gate, the Gran Torta tower, and M1's waterfall.

**Verification.** I checked every number below with a PowerShell geometry checker. It copies the repo rules: capsule `riverDistance`, `liquidDistance`, `nearBridge`/`onBridge`, and the V3-4/5/6/7/8/9/15 rules. It also covers the extra-post rules of `Nests_Test` CH1, guardian binding, the BeastSites S7 reach rules, and route wetness on 2-stud samples. Checker files:
- `C:\Users\Agustina\AppData\Local\Temp\claude\80e2a77a287fbcbe\6e13884a-c13d-46c1-86d0-627c2213786c\scratchpad\und\v9check.ps1` (the data)
- `C:\Users\Agustina\AppData\Local\Temp\claude\80e2a77a287fbcbe\6e13884a-c13d-46c1-86d0-627c2213786c\scratchpad\und\v9run.ps1` (the checks)

The final run gives 0 failures, apart from 6 "centreline" samples that lie on the lake island. Those are dry by design; V3-2 already allows samples on an island. The last full output is in `...\scratchpad\und\out1.txt`. No repo files were edited and no Studio tools were used.

**Convention.** All positions are plot-local, with world = local + (672, âˆ’3). "+z" is the code's "north" (world south, toward Pueblo Gatito); "âˆ’z" is world north. I say +z / âˆ’z throughout.

---

## 1. Plot rectangle: keep CENTRE and add an east extension

**Layout**
- `CENTRE` stays (672, âˆ’3).
- `HALF` stays 260 and now means "the west half and the z half".
- New `Layout.PLOT = {minX = âˆ’260, maxX = 860, minZ = âˆ’260, maxZ = 260}`.
- World plot: x 412..1532 (1120 long), z âˆ’263..257 (520 wide).
- Cloud band and Collider: x 1532..1548. The arm runs to x 1612, as in PD2.

**Why this way.** It is the option that changes the fewest literals:
- `ENTRANCE = (âˆ’HALF, 0)` stays.
- The Portal station (640.8, âˆ’3) stays, so `WildboundPortal` needs no edit.
- `PraderaSites.MEADOW_CENTRE`, the world positions of every kept nest and post, and the three trap-cake spots all stay.
- M1 and the plot's z edges keep using HALF.

Changing the CENTRE (to 972) instead would shift every local literal by 300 studs.

**What changes**
- `Layout.depth(x, z) = min(x âˆ’ PLOT.minX, PLOT.maxX âˆ’ x, z âˆ’ PLOT.minZ, PLOT.maxZ âˆ’ z)`. Today's values stay the same in the west: depth(0,0) = 260, depth(âˆ’260,0) = 0. New examples: depth(800,0) = 60 and depth(300,250) = 10.
- `V3.V8.HALF` becomes a copy `V3.PLOT`, which V3-1 pins equal to the layout's.
- Everything that used HALF as the *east* edge now uses `PLOT.maxX`:
  - the crystal hills (`x = PLOT.maxX âˆ’ 2 = 858`);
  - the Builder scatter ranges (`PLOT.minX + 10 .. PLOT.maxX âˆ’ 42`) and the z bands, which keep Â±HALF;
  - the V3Builder edge hills and the edge-fill grid (the four edges come from PLOT);
  - `East.plan`;
  - Duquesa `plotDepth` (now `Layout.depth`), Flyers and FlyersService bounds (PLOT), and `PraderaSites.AMBUSH`. AMBUSH's `half` becomes `plot = PLOT` and the square test becomes a rectangle test; `edgeStuds` stays 10 and is measured with the rectangle depth.

**Versions**
- `Layout.VERSION` stays 3, the same precedent as V8-D1.
- `V3.VERSION` goes 4 â†’ 5, so the older migrations refuse to run.
- New marks: `V3.V9_MARK = "CaramelV9"` and the root attribute `CaramelV9 = 1`.
- `Builder.layoutKey` becomes "745,0,42" (the Torta moves).

**Ground.Floor** stays one part. Size 1120 Ã— 1 Ã— 520, centre world (972, 0, âˆ’3), top 0.5. It must remain a single part, because `Ambience` and `Life` read exactly this part.

## 2. Spine, boss, tower and portal

| Item | Local | World | Notes |
|---|---|---|---|
| ENTRANCE | (âˆ’260, 0) | (412, âˆ’3) | kept |
| LICORICE arch | (âˆ’161.2, 0) | (510.8, âˆ’3) | kept |
| FORK | (âˆ’143, 0) | | kept |
| JUNCTION | (0, 0) | | kept |
| PORTAL | (âˆ’31.2, 0) | (640.8, âˆ’3) | kept, still the "return near home" portal |
| **GATE** (new named point) | (600, 0) | (1272, âˆ’3) | 145 from the boss â‰¥ 76 + 36 = 112, so it is out of his sight |
| **TORTA** | (745, 0), r 42 | (1417, âˆ’3) | moves to the new east end |
| BOSS | centre = Torta; plaza 58, territory 76, perception 36, whip 22 | | |
| BOSS home | (695, 0) | | 8 studs from the avenue end (â‰¤ 10) |
| Plaza edge (end of the avenue) | (687, 0) | | |
| TOWER, stair, glaze puddles, summit T1 | T1 at (745, 9.4) | | every v8 offset from the Torta kept |

- Plaza far edge: 803, which is 57 from the east edge (â‰¤ 60).
- Territory reaches x 821: depth 39 â‰¥ 10.
- `liquidDistance(Torta) = 155.1` â‰¥ 76.
- Every route point and nest has x < 803 (the new GT1).

## 3. The river (source in the east, mouth on the west edge)

**Source mountain M1**
- `CV3_IceCreamMountain_L` at (811.4, 200), scale 0.45 â†’ **0.9**.
- r = 54 Ã— 0.9 = 48.6; height 81.4, taller than the 65.3 tower.
- x + r = 860, so it touches the east edge (the new "M1 on the east edge" rule).
- It faces RIVER[2] (700, 195): unit vector u = (âˆ’0.99900, âˆ’0.04484).
- The kit offsets scale with s = 0.9:
  - outlet at 49.7s ahead â†’ RIVER[1] (766.71, 197.99);
  - pool at 37.7s ahead, r 11s â†’ `POOL` (777.50, 198.48), r 9.9;
  - waterfall at 31.0s ahead â†’ `WATERFALL` (783.53, 198.75), width 14, top 30.35 (33.72s; < 81.4 and â‰¥ 15), 5 streaks, flowSpeed 12, facing the pool.
- V3-2 needs dist(RIVER[1], POOL) â‰¤ POOL.r + 1: 10.8 â‰¤ 10.9.

**`V3.RIVER`** (source â†’ mouth; a leg is as wide as its wider end):

| # | x | z | w | Meaning |
|---|---|---|---|---|
| 1 | 766.71 | 197.99 | 50 | M1 outlet |
| 2 | 700 | 195 | 80 | M1 faces it |
| 3 | 600 | 190 | 90 | east stretch |
| 4 | 545 | 165 | 60 | bend |
| 5 | 510 | 120 | 60 | **stretch A** (Hondo crossing), straight down x 510 |
| 6 | 510 | âˆ’125 | 60 | |
| 7 | 485 | âˆ’170 | 70 | bend into the lake |
| 8 | 430 | âˆ’190 | 100 | lake |
| 9 | 330 | âˆ’195 | 120 | lake (widest) |
| 10 | 255 | âˆ’172 | 80 | |
| 11 | 215 | âˆ’125 | 60 | **stretch B** (Medio crossing), straight up x 215 |
| 12 | 215 | 130 | 60 | |
| 13 | 185 | 190 | 70 | bend (moved from (180, 185) to free post R5) |
| 14 | 90 | 205 | 70 | west stretch |
| 15 | âˆ’80 | 205 | 60 | |
| 16 | âˆ’260 | 205 | 60 | **mouth, on the west edge** (world (412, 202)) |

**Overall measures**
- Length 1647.9 (today 500.8). Widths 50â€“120, 5 Ã— today's range.
- Edge rule `depth âˆ’ w/2 â‰¥ 2` for every point but the last. Tightest is R9: 65 âˆ’ 60 = 5.
- Wet area 129,400 sq studs, 22.2 % of the plot. Hull-floating area 121,000.

**Lake**
- `LAKE` discs: 1 at (370, âˆ’180), r 70 (top edge z âˆ’110); 2 at (290, âˆ’192), r 45.
- `ISLANDS` I1 at (395, âˆ’185), r 6, flat 4, foot 9.9. It lies inside disc 1 (25.5 + 9.9 â‰¤ 70), with the 120-wide river all round it.
- `PLATFORMS`:
  - CookieM (300, âˆ’205), r 6.7, in disc 2;
  - CookieL (345, âˆ’165), r 11.7;
  - CookieS (400, âˆ’150), r 3.9;
  - CookieS (330, âˆ’215), r 3.9.
  - All inside a disc, â‰¥ 2 apart, â‰¥ 4 off the island foot, and off every bridge.

**Barrier (V3-14, rotated).** Every column x = âˆ’258..858 meets chocolate, except under M1, so you cannot walk from the west to the middle or from the middle to the east without a bridge, wading or the raft. The middle region (x 245..480) is a peninsula enclosed by stretches A and B.

**Two new rules (no invisible chocolate)**
1. `V3.liquidDistance` ends with `max(best, âˆ’V3.plotDepth(x, z))`, so nothing outside the plot is chocolate. This kills the 30-stud capsule past the mouth for the raft, wading, the current and the clearances. The raft stops HULL 3 inside the edge.
2. In `layLiquid`, each joint drum is laid at radius `max(w[iâˆ’1], w[i], w[i+1]) / 2` instead of `w[i] / 2`. That drum is exactly the union of the two capsule ends, so every point the rules call wet is laid wet. Width steps today leave crescents of up to 20 studs at 5x.

Banks stay at w/2 + 1.2. The part count does not change.

## 4. Routes (all 14 wide)

| Route | Points (local) |
|---|---|
| main | (âˆ’260,0) (âˆ’143,0) (0,0) (600,0) (687,0) |
| left | (âˆ’143,0) (âˆ’130,âˆ’104) (âˆ’65,âˆ’182) (65,âˆ’182) (117,âˆ’143) (0,0) â€” **unchanged** |
| right | (âˆ’143,0) (âˆ’117,91) (âˆ’52,156) (52,156) (104,130) (0,0) â€” **unchanged** |
| deep | (0,0) (âˆ’31.2,0) â€” unchanged |
| **lake** (new, âˆ’z lane) | (117,âˆ’143) (150,âˆ’70) (600,âˆ’70) (700,âˆ’150) (790,âˆ’150) |
| **alto** (new, +z lane) | (104,130) (150,100) (600,100) (720,115) |
| **gate** (new, cross road) | (600,100) (600,0) (600,âˆ’70) |

- `ROUTE_ORDER`: main, left, right, deep, lake, alto, gate.
- `RETURN_ROUTES` = left, right (unchanged tests). New `FAR_ROUTES` = lake, alto, gate.
- Every sample of left, right, lake, alto and gate is â‰¥ 83 from the boss (territory + 7).
- Every route sample with liquid â‰¤ 0 is on a deck. Every sample with liquid < 7 is on a deck or a ramp.
- Lengths: the avenue from the entrance to the plaza is 947 studs (about 59 s at walk 16).

## 5. Bridges: raised, so the raft passes under

**`BRIDGE_BUILD`**
- width 15
- **deck 12** (top over the floor; was 4.1)
- **ramp 26**: atan(12/26) = 24.78Â° â‰¤ 25Â°
- gapWidth 8, sideRamp 26 (unused)
- **gaps = {} on every bridge** (raised decks have no side ramps)

**Clearance arithmetic**
- Underside = 12 âˆ’ 0.4 âˆ’ 3.5 = 8.1 above the surface.
- The kit raft top is about 6.64 + 0.15 bob; a seated head is about 5.5â€“6.
- New `V3.RAFT.clearance = 8`, so these bridges pass.

**Raft code**
- `Raft.area` uses a new `V3.raftBlocked(x, z, r)`. It is `nearBridge` restricted to bridges whose `deck âˆ’ 0.4 âˆ’ LIQUID.depth < RAFT.clearance`; v9 has none.
- `nearBridge` keeps its meaning for pieces, props and dock tips.

**Decor.** 4 "Pier" blocks per bridge (2 Ã— 11.6 Ã— 2, solid) under the deck corners at along = Â±32, across = Â±6.5. They stand on the bank: the chocolate edge is at Â±30.

| Id | Route | Leg | at | Deck centre (local / world) | Length | Cookie |
|---|---|---|---|---|---|---|
| Medio | main | (0,0)â†’(600,0) | 215 | (215,0) / (887,âˆ’3) | 68 | no |
| Hondo | main | (0,0)â†’(600,0) | 510 | (510,0) / (1182,âˆ’3) | 68 | no |
| LagoMedio | lake | (150,âˆ’70)â†’(600,âˆ’70) | 65 | (215,âˆ’70) | 68 | **yes** |
| LagoHondo | lake | same leg | 360 | (510,âˆ’70) | 68 | **yes** |
| AltoMedio | alto | (150,100)â†’(600,100) | 65 | (215,100) | 68 | **yes** |
| AltoHondo | alto | same leg | 360 | (510,100) | 68 | **yes** |

**Fit on the legs.** Each footprint runs along at Â± (34 + 26) = Â±60:
- Medio: 155..275 âŠ‚ 0..600.
- Hondo: 450..570 âŠ‚ 0..600.
- Lake and alto bridges at 65: 5..125 âŠ‚ 0..450. At 360: 300..420 âŠ‚ 0..450.

**Wet span (tight spot).** Every crossing is square to a straight 60-wide stretch, so the band is Â±30 and liquid â‰¤ 1 is Â±31 against a deck of Â±34 (3 studs of margin). Bend capsules do not widen it:
- around R12, a capsule of r 35: at z 100 it is wet only where |x âˆ’ 215| â‰¤ âˆš(35Â² âˆ’ 30Â²) = 18.0;
- around R5, r 30: at z 100, |x âˆ’ 510| â‰¤ âˆš(30Â² âˆ’ 20Â²) = 22.4;
- around R11 (r 40) and R6 (r 35), measured at z âˆ’70: the distance is 55, which is more than r, so no extra wet.

Bridges on parallel lanes are 70â€“100 apart, so footprints cannot overlap.

**Cookie bridges**
- `Cookie.IDS = {"LagoMedio", "LagoHondo", "AltoMedio", "AltoHondo"}`. The avenue always has a safe crossing.
- `Cookie.SINK` 7 â†’ **13**: CB10 needs > deck + 0.4 = 12.4.
- FEET_SLACK 1.5 still separates the deck from a wader, who is now 8.5 studs lower.
- A fall is 8.5 studs into the chocolate, and the faller wades at 0.6 Ã— speed.

## 6. Docks and raft

**`V3.DOCKS`** are now free rows (no `withDisc`):

| Id | Name | Stand | Tip | World tip | Stand liquid | Tip liquid |
|---|---|---|---|---|---|---|
| A (home) | Boca | (âˆ’150, 162) | (âˆ’150, 186) | (522, 183) | +13.0 | âˆ’11.0 |
| B | Medio | (168, 40) | (195, 40) | (867, 37) | +17.0 | âˆ’10.0 |
| C | Lago | (370, âˆ’98) | (370, âˆ’124) | (1042, âˆ’127) | +12.0 | âˆ’14.0 |
| D | Fuente | (690, 140) | (690, 166) | (1362, 163) | +9.4 | âˆ’16.5 |

- Every tip is â‰¤ âˆ’6 and not `nearBridge(tip, 6)`. Every ramp foot is on land.
- Dock D, tight: its stand is 54.43 from the R3â€“R2 leg (90 wide), so 54.43 âˆ’ 45 = 9.43.
- Dock C's ramp foot (370, âˆ’88) is 18 from the lake lane, which leaves 7.5 â‰¥ 3 after r and the path's half width.

**`RAFT`** = {asset "CV3_BananaRaft", homeDock = 1, clearance = 8}. Dock is unchanged.

**Code**
- `Raft.new`: homeDock accepts any integer 1..#docks (it was clamped to 1 or 2). It still needs â‰¥ 2 docks.
- The `dockedAt` comment changes.
- The service and call points already iterate every dock.
- A call still teleports, so 4 docks need no path.

**Trip times.** River from tip D to tip A â‰ˆ 1500 studs: 62 s downstream (24 studs/s) and 94 s upstream (16). The raft out-runs every candy chase speed only downstream.

**Current.** Unchanged: RIVER_SPEED 4, LAKE 1.5, JOIN 6, EDGE 2. Dock C's tip lies 56 inside disc 1, so its flow is 1.5. Tips A, B and D are on river legs at 4, which is still â‰¤ DOCK_SPEED.

## 7. Nests: 38 floor nests (+10) plus T1

Counts: Comun 13 â†’ 14, Rara 11 â†’ 17, Epica 3 â†’ **6**, Legendaria 1. Mean x by rarity: Comun 81, Rara 147, Epica 699, Legendaria 795.

**Kept as they are (20):**
- C1 (âˆ’208,âˆ’23.4), C2 (âˆ’182,31.2), C3 (âˆ’117,âˆ’171.6), C6 (13,âˆ’210.6), C8 (78,âˆ’221), C9 (âˆ’175.5,âˆ’80.6), C10 (âˆ’78,âˆ’210.6), C12 (âˆ’169,âˆ’130), C13 (130,âˆ’195)
- R1 (âˆ’101.4,âˆ’39), R2 (âˆ’101.4,44.2), R3 (âˆ’58.5,âˆ’120.9), R4 (âˆ’26,123.5), R5 (114.4,145.6), R6 (124.8,âˆ’158.6), R7 (âˆ’150.8,75.4), R8 (âˆ’143,123.5), R9 (âˆ’78,91), R10 (âˆ’13,âˆ’58.5), R11 (46.8,96.2)

**Moved (8).** C4, C5, C7 and C11 were swallowed by the river. E1, E2, E3 and L1 move deep on purpose.

| Id | Rarity | Local | World |
|---|---|---|---|
| C4 | Comun | (300,âˆ’35) | (972,âˆ’38) |
| C5 | Comun | (300,50) | (972,47) |
| C7 | Comun | (440,45) | (1112,42) |
| C11 | Comun | (440,âˆ’35) | (1112,âˆ’38) |
| E1 | Epica | (650,âˆ’150) | (1322,âˆ’153) |
| E2 | Epica | (735,âˆ’200) | (1407,âˆ’203) |
| E3 | Epica | (690,âˆ’95) | (1362,âˆ’98) |
| L1 | Legendaria, event-only | (795,âˆ’115) | (1467,âˆ’118) |

**New (10):**

| Id | Rarity | Local | World |
|---|---|---|---|
| C14 | Comun | (370,50) | (1042,47) |
| R12 | Rara | (370,âˆ’35) | (1042,âˆ’38) |
| R13 | Rara | (285,145) | (957,142) |
| R14 | Rara | (445,150) | (1117,147) |
| R15 | Rara | (560,50) | (1232,47) |
| R16 | Rara | (650,135) | (1322,132) |
| R17 | Rara | (575,âˆ’35) | (1247,âˆ’38) |
| E4 | Epica | (560,âˆ’115) | (1232,âˆ’118) |
| E5 | Epica | (760,120) | (1432,117) |
| E6 | Epica | (800,âˆ’200) | (1472,âˆ’203) |

**Checks that pass for every nest**
- liquid â‰¥ 6
- route 11..52
- â‰¥ 20 from any other nest
- â‰¥ 48 from the Torta
- â‰¥ 96 from the boss (E3 109.8, the closest)
- off the pond (â‰¥ 68) and off the hive (â‰¥ 43)

**Tight spots**
- R16: 57.43 âˆ’ 45 = 12.4 from the river.
- E4: âˆš(50Â² + 10Â²) âˆ’ 35 = 16.0.
- R15: 50 âˆ’ 30 = 20.

**New rarity rule** (replaces the square depth rings): Comun x â‰¤ 450; Epica and Legendaria x â‰¥ 540; mean x rises Comun < Rara < Epica.

## 8. Creature posts (`WildboundPraderaSites`)

**FIXED becomes v9 rows.** Each post is `beside9(nestLocalX, nestLocalZ, dx, dz)` = MEADOW_CENTRE + nest + offset. Every kept post keeps its v8 nest offset.

**Moved with their nest:**

| Post | Creature, role | Local | World |
|---|---|---|---|
| candyNestC4 | Mielita HOME | (292,âˆ’23) | (964,âˆ’26) |
| candyNestR4 | Flanin HOME, by C5 | (306,64) | (978,61) |
| candyPostC7 | Gomibu extra, guards C7 | (447,36) | |
| candyPostC11 | Canelin extra | (440,âˆ’47) | |
| candyPostE3 | Gomibu extra, guards E3 | (678,âˆ’95) | |

**New third extra post per creature** (`EXTRA_POSTS` 24 â†’ 32, PER = 3):

| Key | Creature | Nest + offset | Local | World |
|---|---|---|---|---|
| candyPostE1 | Gomibu, guards E1 | E1 + (âˆ’8, 10) | (642,âˆ’140) | (1314,âˆ’143) |
| candyPostE4 | Flanfuria, guards E4 | E4 + (10, 6) | (570,âˆ’109) | (1242,âˆ’112) |
| candyPostE5 | Tortidragon, guards E5 | E5 + (âˆ’8, 8) | (752,128) | (1424,125) |
| candyPostR12 | Mochimiau | R12 + (0, âˆ’12) | (370,âˆ’47) | |
| candyPostR15 | Canelin | R15 + (12, 0) | (572,50) | |
| candyPostR16 | Flanin | R16 + (âˆ’12, âˆ’6) | (638,129) | |
| candyPostR17 | Mielita | R17 + (12, âˆ’6) | (587,âˆ’41) | |
| candyPostR14 | GatoRepartidor | R14 + (0, âˆ’12) | (445,138) | |

- **Boss posts:** `bossHome` (1367, âˆ’3), `bossTerritory` (1417, âˆ’3).
- **Guardian binding** (12 posts; was 9): C1, R1, C3, C7, R6, C8, E3, R8, R9, **E1, E4, E5**. Each binds its own nest at 8.5â€“14.4 (â‰¤ 20, inside wake and leash).
- **CH1 rules all pass for the 32 extra posts:**
  - nearest nest 8â€“16 and their own (none shared);
  - route 11..wake;
  - depth â‰¥ leash;
  - boss â‰¥ 76 + reach (candyPostE3 116.2 â‰¥ 106; E5 128.2 â‰¥ 111);
  - entrance â‰¥ 30 + reach;
  - â‰¥ 100 from the creature's home;
  - all 40 posts â‰¥ 30 apart.
- **Tight spots**
  - candyPostR5 liquid: segment distance 43.74 âˆ’ 35 = **8.74** â‰¥ 8. This is why R13 moved from (180,185) to (185,190); before, it was 6.2 and failed.
  - candyPostE4: route 39.0 against wake 40.
  - candyPostR14: route 38.0 against wake 40.
  - candyPostR9 (unchanged): route 36.1 against wake 40.
- **AMBUSH:** `half` becomes `plot` (PLOT). `bossClearStuds` 126 is measured from the new territory centre.

**Pond and hive move.** Move the Pradera marker to CENTRE (672, âˆ’3) in migration step 9, so OFFSETS become plot-local and the default (no-marker) sites equal the live ones.

| Offset | New value (plot-local) | KEEP_CLEAR row | Checks |
|---|---|---|---|
| pond | **(360, 192)** | r 26, Prado Alto | route 92 â‰¥ 67; nearest nest 88.5 â‰¥ 68; boss 430 â‰¥ 136; depth 68 |
| colmena | **(âˆ’230, âˆ’150)** | r 10 | route 110 â‰¥ 42; nest 64.2 â‰¥ 43; entrance 153 > 70; depth 30 |
| gate | (âˆ’222.3, 143) | | same world spot as today |
| plaza | (âˆ’32.5, 161.2) | | same world spot as today |

The "Cloud gate to Caramelo Este" KEEP_CLEAR row is removed (PGM-D8).

## 9. Houses, mountains, hills, licorice and cake

All of these pass V3-6/7/15: nests â‰¥ 8 + r, posts â‰¥ 6 + r, route â‰¥ 3 + r + 7, boss â‰¥ 76 + r, the edge, liquid â‰¥ 2 + r, off bridges, pieces â‰¥ 2 apart, doors clear.

| Id | Asset | Scale, r | Local | World | Note |
|---|---|---|---|---|---|
| H1 | SweetHouse | 1.4, 28 | (285, 210) | (957, 207) | Prado Alto |
| H2 | CaramelTower | 1, 15, turn 180 | (445, 215) | (1117, 212) | Prado Alto |
| H3 | ChocoHouse | 1.4, 22.4 | (âˆ’205.4, âˆ’195) | | kept |
| H4 | SweetHouse | 1, 20 | (560, âˆ’205) | (1232, âˆ’208) | liquid âˆ’ r 12.8 |
| H5 | CaramelTower | 1.4, 21, turn 180 | (âˆ’218.4, âˆ’106.6) | | kept |
| H6 | ChocoHouse | 1, 16 | (828, âˆ’55) | (1500, âˆ’58) | "last refuge"; boss âˆ’ r 83.6 |
| H7 | SweetHouse | 1, 20 | (âˆ’20, 70) | (652, 67) | the WN quarter |

Every quarter (EN, ES, WN, WS) has a house.

| Mountain | Scale, r | Local |
|---|---|---|
| M1 | 0.9, 48.6 | (811.4, 200) |
| M2 | 0.4, 14.2 | (838, âˆ’238) |
| M3 | 0.37, 13.1 | (370, 246); depth 14 â‰¥ 12.6 |
| M4 | 0.37, 13.1 | (135, âˆ’245) |
| M5 | 0.37, 13.1 | (âˆ’241.8, âˆ’241.8), kept |
| M6 | 0.37, 13.1 | (âˆ’246, âˆ’48); entrance âˆ’ r 36.8 |

- **Crystal hills** at x 858, scales from Hill_1 to Hill_6:

| Hill | z | Scale |
|---|---|---|
| Hill_1 | âˆ’200 | 0.5 |
| Hill_2 | âˆ’130 | 0.45 |
| Hill_3 | âˆ’10 | 0.5 |
| Hill_4 | 50 | 0.5 |
| Hill_5 | 110 | 0.28 |
| Hill_6 | 150 | 0.28 |

- **Licorice** (âˆ’161.2, 0) and **cake** (âˆ’195, 145.6) are kept. The cake base is 59.4 âˆ’ 30 âˆ’ 18 = 11.4 from the mouth stretch.
- `BACKDROP` stays empty.

## 10. Edges, cloud wall, caps and ground (`East.plan` v9, 5 â†’ 11 parts)

| Part | Rectangle (world) | Status |
|---|---|---|
| Plot | x 412..1532 | |
| Band and Veil | x 1532..1548, z âˆ’271..265 | |
| Collider | centre x 1540 (face 1538..1542) | |
| Floor under the band | x 1532..1548, z âˆ’263..257 | |
| CapNorth | x 1538..1612, z 261..265 | resized |
| CapSouth | x 1538..1612, z âˆ’271..âˆ’267 | resized |
| StripNorth floor | x 1012..1612, z 257..297, top 0.5 | **new** |
| StripSouth floor | x 1012..1612, z âˆ’303..âˆ’263, top 0.5 | **new** |
| EndPad | x 1548..1612, z âˆ’263..257 | **new** |
| SideWallNorth | x 1012..1616, z 297..301, 80 tall, invisible | **new** |
| SideWallSouth | x 1012..1616, z âˆ’307..âˆ’303, 80 tall, invisible | **new** |
| EndWall | x 1612..1616, z âˆ’303..297, invisible | **new** |

- Without the new strips and walls, the plot's long sides past the Baseplate (x 1024) border void.
- `East.build` already creates missing specs, so this is data only.
- `space` is kept as a formula for the old helpers.
- The creature clamp reads the live Collider, so it moves with it.

## 11. Client systems

- **Ambience:** reads the live `Ground.Floor`, so it covers the whole new plot. `PLOT_FALLBACK` becomes 412..1532, âˆ’263..257.
- **Life:**
  - `plotFrame` must anchor to the floor's **west edge**: centre.x = floor.minX âˆ’ PLOT.minX = 412 + 260 = 672. Otherwise every flock and fish shifts 300 studs east.
  - Copies to update: CENTRE, PLOT and HOUSES (the v9 rows).
  - **FLOCKS** (all checked: â‰¥ 10 off the chocolate, houses, the Torta and the edge):

| Flock | Centre | r | Status |
|---|---|---|---|
| F1 | (âˆ’156, 52) | 26 | kept |
| F2 | (âˆ’104, âˆ’65) | 24 | kept |
| F3 | (360, 40) | 22 | moved |
| F4 | (60, âˆ’120) | 22 | moved |
| F5 | (âˆ’104, âˆ’208) | 20 | kept |
| F6 | (680, âˆ’80) | 20 | moved |
| F7 | (360, 140) | 20 | new |
| F8 | (660, âˆ’205) | 22 | new |

  - `MIN_ALT` 46 â†’ **88**, to clear M1 at 81.4.
  - **FISH_SPOTS** (13; start and end at liquid â‰¤ âˆ’3, off bridges, â‰¥ 8 from dock tips; Lake_2 is 11.7 from tip C):

| Spot | Point | Heading |
|---|---|---|
| River_E1 | (740, 196.5) | âˆ’3.097 |
| River_E2 | (650, 192.5) | âˆ’3.092 |
| River_A1 | (510, 50) | âˆ’1.5708 |
| River_A2 | (510, âˆ’35) | âˆ’1.5708 |
| Lake_1 | (440, âˆ’170) | âˆ’2.9 |
| Lake_2 | (360, âˆ’130) | âˆ’3.0 |
| Lake_3 | (330, âˆ’195) | âˆ’3.092 |
| Lake_4 | (280, âˆ’200) | 2.9 |
| River_B1 | (215, âˆ’35) | 1.5708 |
| River_B2 | (215, 50) | 1.5708 |
| River_W1 | (40, 205) | Ï€ |
| River_W2 | (âˆ’60, 205) | Ï€ |
| River_W3 | (âˆ’200, 205) | Ï€ |

- **Sky, HUD and light:** these follow the big4 Meadow row. Patch the Studio-only `WildboundBiomes` and `WildboundBiomeLight` `AREAS_BIG4` Meadow maxX 1012 â†’ **1612**.

## 12. Part budget (estimate; not measured in Studio)

| Change | Parts |
|---|---|
| Water: river 15 joints + 15 legs + 30 banks + pool = 61; lake 2; bridges 6 Ã— 11 = 66; docks 4 Ã— 4 = 16 | 145 (today 150) |
| Paths: 20 drums + 23 legs | 43 (+16) |
| Nests (assuming ~6 per kit nest) | +60 |
| Bank filler: archive the old v8-river filler, re-lay every 30 studs | about +160 net |
| Edge and interior fill for the extension (own budget `EDGE_V9.maxParts` 450) | +450 |
| Props archived in the new chocolate | about âˆ’50 |

- Bioma: 2072 â†’ about **2700â€“2750 saved**.
- East: 5 â†’ 11.
- Raise `BIOME_PART_CAP` 2800 â†’ **3400**. New `V9_PART_TARGET` **3200** for the dry-run estimate (still report-only, like v8).
- Density falls from 7.7 to about 4.7 parts per 1000 sq studs.

## 13. Migration: `tools/wildbound-caramelo-v9-migrate.luau`

Same pattern as v8:
- `DRY_RUN = true` by default, Edit mode only.
- Fresh module clones, with asserts for `V3.VERSION == 5`, `Layout.PLOT`, and the exports listed below.
- Needs root `CaramelV8`. If `CaramelV9` is already set, it returns "already".
- Summary goes to `WildboundCaramelV9Summary`.
- `CaramelV9Backup` / `CaramelV9Archived` under `ServerStorage.WildboundMapArchive`. Nothing is destroyed.
- One recording "CaramelV9" inside `task.delay` and `pcall`, committed or cancelled.
- SistemaSonriente is refused everywhere. **New:** its bounds are read; if they meet the new plot, the strips or the walls, the real run aborts.

**Steps**
- **0. Backup:** clones of `Candy_Bioma_v1`, `Candy_Este_v1` and the Pradera marker.
- **1. Floor:** `Ground.Floor` becomes 1120 Ã— 1 Ã— 520 at (972, 0, âˆ’3).
- **2. Archive and relay:**
  - Paths, Boss with Ground.Plaza, and Markers (`layPaths`, `layBoss`, `layMarkers`).
  - CaramelV3 River, Lake, Bridges and Docks (`layWater`).
  - Waterfall (new export `layWaterfall`).
  - M1: archive it and relay at scale 0.9 (new export `layMountain`). The kit collision parts are built at that scale.
  - Tower plus Nest_T1: archive first, then `syncTower` at the new LayoutKey. This avoids its Destroy.
  - Runtime folders saved by mistake.
- **3. Snap to layout spots:**
  - by MountainId: M2, M3, M4, M6 (M5 stays);
  - by HouseId: H1, H2, H4, H6, H7 (H3 and H5 stay);
  - by PlatformIndex: 1â€“4;
  - by CrystalSpot: the hills;
  - GranTorta to CENTRE + TORTA (LayoutKey "745,0,42");
  - the queen preview to `Duq.seatPivot`;
  - the Frutillon summit.
  - Licorice, cake and portal are unchanged.
- **4. Nests:**
  - `syncNestPositions` moves C4, C5, C7, C11, E1, E2, E3 and L1.
  - `syncNests` adds the 10 new markers. The server's CH3 start step would also add them.
- **5. Props stay where they are** (identity, no transform). Archive any old-kit prop or CaramelV3 Trees/EdgeFill/Filler piece that is:
  - in the chocolate (`V3.clearOfPieces`);
  - on a route (+3) or a bridge footprint;
  - within 8 of a nest or 6 of a post.
  - Archive **all** bank filler of the v8 river. Use the `V3.RIVER_V8` record, kept as data: anything within w/2 + 7 + reach of it.
- **6. Lay:**
  - bank filler along the v9 river (new export `layBankFiller`, bankEvery 30);
  - edge and interior fill for local x â‰¥ 215 (`EDGE_V9`, seeded, budget 450).
- **7.** `East.build(v9)`: 6 parts conformed, 6 created.
- **8.** Annex untouched (its strips stay at x 412..1012).
- **9.** Pradera marker to (672, âˆ’3).
- **10.** Root `CaramelV9 = 1`.

**Dry run.** It probes the relays in a detached scratch model (one `:Destroy`, as in v8) and reports moved, snapped, archived, the new nests, the part estimate against 3200, and SistemaSonriente overlap.

**Other files to patch together**
- Studio-only big4 Biomes and BiomeLight rows.
- `Builder.build`, a fresh build: floor from PLOT, scatter from PLOT. The legacy `Layout.LAKE`/`BRIDGE` syrup data stays as dead data.

## 14. Tests

**Deliberately changed**

- **WildboundCandyLayout_Test**
  - S2 adds PLOT: world 412..1532, inside the arm 412..1612. CENTRE and HALF stay.
  - S4 corridor adds GATE.
  - S5 count: 38 (14 / 17 / 6 / 1).
  - The rarity rings are replaced by the x-depth bands.
  - GT1: x < T.x + plaza; plaza â‰¤ 60 from PLOT.maxX.
  - S4 territory uses the rectangle depth.
  - V8-D1: the Torta 148.2 â†’ 745 and the pond values; the transform stays as a record.
  - **K-D2 is removed**; it becomes "KEEP_CLEAR = pond and hive at the v9 spots".
- **WildboundCandyV3Layout_Test**
  - V3-1: VERSION 5; PLOT equal to the layout's.
  - V3-2: the river ends on the **west** edge; M1 on the **east** edge; length â‰¥ 1500; w â‰¥ 50; widest â‰¥ 100.
  - V3-14: rotated to x columns.
  - V3-4: deck â‰¥ depth + 0.4 + clearance; crossed routes are main, lake and alto.
  - V3-8: â‰¥ 4 docks; home is the dock nearest the entrance.
  - V3-12: raised bridges have no gaps.
  - V3-15: x = PLOT.maxX âˆ’ 2.
  - V3-16: the v7 record uses PLOT.
  - V3-17 and V3-18 become the v9 pins.
- **Raft_Test:** RF1 (4 docks, any homeDock); RF4 and RF16 (only a low bridge is a wall; the raft passes under a raised one); RF15 (w â‰¥ 60; a sail path).
- **Current_Test:**
  - CU2: 15 legs.
  - CU3: the dry points still hold â€” (âˆ’150,0), (150,100), (100,âˆ’50), (âˆ’100,âˆ’50) and (60,150) are all dry; river tips have flow â‰¤ 4; lake tip C has 1.5.
  - CU4: grid becomes x âˆ’258..858, z âˆ’258..258.
  - CU5 and CU9: legs 5 (stretch A) and 14.
  - CU6 and CU7: 4 docks.
  - CU8: start points (690,166), (370,âˆ’124), (âˆ’150,186).
- **Island_Test:** IS1â€“IS3 use disc 1 at (370,âˆ’180) and 4 docks.
- **CookieBridge_Test:** the four ids; SINK 13.
- **Life_Test:** CL1 (PLOT copies), CL3, CL4, CL5 (the new flocks and fish), and a new plotFrame west-edge case.
- **Ambience_Test:** fallback x up to 1532.
- **East_Test:** every 932, 940, 948 and 1468 literal becomes 1532, 1540, 1548 and 1612; add the 6 new parts.
- **Duquesa_Test:** the rectangle depth and the summit.
- **Builder_Test:** floor 1120 Ã— 520.
- **Grass, HideSpots, Traps and Island tests:** rectangular fixture floors.
- **Nests_Test:**
  - 9 â†’ 12 guardian posts and the new binding map;
  - CH1 PER 3 (32 extra);
  - CH3 live floor nests 27 â†’ 37;
  - the V8-D1 pairs become the v9 pairs;
  - AMBUSH.plot.
- **BeastSites S7, Abeja KB-3, Nube:** the marker at CENTRE and the new default pond and hive.
- **V3Builder_Test:** part counts (piers, 16 points, 4 docks), the RIVER and DOCKS indices, and the joint radius rule.
- **Studio-only:** big4 BiomeLight_Test, Big4Map_Test and BeastSight_Test (maxX 1612).
- **Re-check only:** Tower_Test, Flyers_Test and Portal_Test (the Portal is unchanged).
- `KittenPark_Test:485` GATE_CORRIDOR stays a one-shot record.

**New**
- **V9-1:** the PLOT rectangle and the depth examples.
- **V9-2:** the river reaches both ends; widths 50â€“120; every x column meets chocolate.
- **V9-3:** a BFS over the raft's area on a 2-stud grid (hull 3) links all 4 dock tips and passes under all 6 decks.
- **V9-4:** raised-bridge clearance â‰¥ 8; ramps â‰¤ 25Â°; SINK > deck + 0.4.
- **V9-5:** â‰¥ 4 docks; the home dock is nearest the entrance; tips â‰¥ 50 apart; each stand â‰¤ 70 from a route.
- **V9-6:** the depth-reward bands and the rising means.
- **V9-7:** no chocolate outside the plot; joint drums cover the capsules.
- **V9-8:** East v9, including the closing strips and walls.
- **V9-9:** static checks on the migration tool (needs CaramelV8, sets CaramelV9, one `:Destroy`, the SistemaSonriente guard).

## 15. Open risks

1. **SistemaSonriente's x extent is unknown.** If it lies in x 932..1612, the v9 plot cannot be laid. The dry run must check this first.
2. **Studio-only big4 copies.** Without the Meadow maxX 1612 patch, there is no Meadow tag, light or summoning past x 1012.
3. **Raft clearance.** 8.1 studs of clearance is an estimate: the kit top and the seated head height are unverified.
4. **M1's outlet looks small.** The kit outlet at scale 0.9 is about 24 wide and feeds a 50-wide river; the joint drum paints over the mountain's front skirt from about 20 studs in front of its pivot.
5. **Balance and timing.**
   - 22 % of the plot is chocolate: a bee refuge and a wading penalty.
   - The raft is not faster than walking. The river is 1.6 Ã— the avenue's length, so the raft's value is out-running chasers downstream. If it should also be quicker, try RIVER_SPEED/CURRENT_MAX 6 in play.
   - One raft for the whole server means contention.
6. **Distance from the hub.** The Torta is about 1135 studs from the hub centre. StreamingEnabled and its radius are unknown, and walking home on foot takes about 60 s or more.
7. **CU4 bend smoothness** with JOIN 6 is not run. If it fails, JOIN 6 â†’ 10.
8. **Tight margins to watch in play:**
   - candyPostR5 liquid 8.74;
   - post route vs wake: E4 39/40, R14 38/40;
   - bridge decks have 3 studs over the wet span;
   - dock D stand 9.4 from the river;
   - H6's door opens about 70 studs from the boss, at the territory edge, by intent.
9. **Sneak strip.** A 5â€“10-stud dry strip remains behind the lake (z âˆ’250..âˆ’260), and the annex strip sits beyond it. The barrier is about columns, not absolute, as it is today.
10. **Old fill in the west.** Old props along the vanished v8 river course in the west half stay unless they are bank filler. That needs a visual check, as does the white-3D-view issue noted after v8.
11. **Estimates and tools.** Part counts are estimates, and `test_caramelo_v3.py` stays stale (no Python here).
12. **Arm sizes.** PD1 (all arms 1200 long) is done for Caramelo only; the other three arms will look shorter until their tasks run.

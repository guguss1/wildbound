# Gran Torta at the east end, 1.6x bigger (GT plan, 2026-11-16)

Owner request: "the cake with the princess at the end, and much bigger". Plan only; nothing built. Coordinates are local to the Caramelo plot (`WildboundCandyLayout`, +x east), starting values to be confirmed by the GT tests (adjust by up to 5 studs if a rule fails). Everything stays inside the 400 x 400 plot, so classic and big4 modes and the big4 annex need no change.

## Target numbers

- `TORTA` (0,0) r 26 -> (114,0) r 42. Tier scale literal `26 / 36` in `Layout.TOWER` -> `Layout.TORTA.radius / 36`. Tiers: r 42 / 32.7 / 23.3 / 14, tops 21 / 38.5 / 53.7 / 65.3. Stair: 21 + 18 + 16 + 12 = 67 steps, all rises <= 1.
- `BOSS`: centre (114,0), plaza 44 -> 58, territory 62 -> 76, home (-34,0) -> (64,0). `WildboundBeastConfig` DonGlaseon `TerritoryRadiusStuds` 62 -> 76.
- `spinPeriodSeconds` 90 -> 140 (rim speed stays under 2 studs/s).
- Summit nest T1: TORTA + (0, 9.4), scale 0.7 -> 1.0. Frutillon `RING_STUDS` 6.3 -> 10.
- Glaze puddles: (114,52), (165,8), (75,34).
- `JUNCTION` (130,0) -> (0,0). `PORTAL` (160,0) -> (-24,0); `WildboundPortal` caramelo station world (772,-3) -> (588,-3).
- Routes:
  - main: (-200,0), (-110,0), (0,0), (56,0) (the avenue to the plaza edge)
  - left: (-110,0), (-100,-80), (-50,-140), (50,-140), (90,-110), (0,0)
  - right: (-110,0), (-90,70), (-40,120), (40,120), (80,100), (0,0)
  - deep: (0,0), (-24,0)
- Nests moved: C5 (128,44) -> (60,152); C8 (140,-70) -> (60,-170); E2 (20,36) -> (-34,24); R3 (60,-110) -> (-45,-93); R4 (62,84) -> (-20,95). The rest stay.
- `WildboundPraderaSites.FIXED` (world): bossHome (578,-3) -> (676,-3); bossTerritory (612,-3) -> (726,-3); candyNestR3 (664,-101) -> (579,-86); candyNestR4 (664,71) -> (678,163) (Flanin's home post, now beside C5; key name kept); candyPostC8 (744,-83) -> (667,-161). `OFFSETS.pond` (150,0) -> (150,40) and `KEEP_CLEAR` pond (165,110) -> (165,150). `AMBUSH.bossClearStuds` 112 -> 126.
- La Duquesa: `plotDepth` ignores the east edge (the cake is now 58 studs from it, so stepping past it must not end her rage).
- Freed centre: a junction clearing with a seeded backfill (about 8 cotton trees, 2 cookie or cream trees, 6 gumdrops) and two pairs of giant lollipops framing the avenue at x 20 and 40.
- Unchanged: lake, bridge, trap cakes, donut gate, sugar hills, La Abeja's hive, the other 11 posts, BiomeLight bounds.

## Tests

- New `GT` cases: Layout GT1-GT6 (cake is the end of the biome; radius 40-44 with no hidden scale; plaza holds the stair, territory inside the plot; junction out of the boss's sight; portal out of reach; summit and glaze relative to TORTA), Tower GT7 (walkable stair, summit fit), Builder GT8-GT12 (`syncTower` rebuilds on a `LayoutKey` mismatch; `lay*` helpers equal `build`; `syncNestPositions`; `syncCentre` idempotent; migration plan on a fake v2 build), Duquesa GT13 (east edge does not end the rage).
- Re-pin on purpose: Layout S4 territory depth (>= 75 -> >= 10) and S4 portal; Tower CT1 stale decoy literal and CT2 spin period; Nests CH4 ambush check point; BeastDonGlaseon literals 578/612/585/600 -> 676/726/681/696; BeastSites S7 pond; PortalService station 772 -> 588.

## Live map: migration, not a rebuild

One-shot Edit-mode tool `tools/wildbound-caramelo-cake-move.luau`, modelled on `tools/wildbound-caramelo-tree-resize.luau`: `DRY_RUN` first, one undo step, guarded by a `CakeMoveV1` attribute, backup of `Candy_Bioma_v1` into `ServerStorage.WildboundMapArchive.CakeMoveBackup`.

Builder helpers (also used by `Builder.build`): `layPaths`, `layBoss`, `layMarkers`, `placeTorta`, `syncNestPositions`, `syncCentre` (seed + 2, guard `CaramelCentreFillV1`), `cakeMovePlan`; `syncTower` writes `LayoutKey = "x,z,r"` and rebuilds the Tower and Nest_T1 on a mismatch.

Order: backup; place the cake; destroy Tower and Nest_T1 and run `syncTower`; rebuild plaza, Boss folder, Paths, Markers; move the portal; `syncNestPositions`; archive (never delete) props that fail the new rules; `syncCentre`; root attributes `LayoutVersion = 3`, `CakeMoveV1`.

Checks after: the suites above plus Kit, Nests, Frutillon, Flyers, Glaze, TrapCake, Smarts, Portal, BiomeLight, Big4Map; live-map geometry (open floor on nests, posts and pond; cake proxy r 42 at world (726,-3); steps equal `stairSteps()`; territory attribute 76; portal within 2 studs of (588,-3)); Play walk (three lanes, climb 67 steps, steal T1, rage, boss fight on the new plaza, trap cake, hive chase to the no-go zone, portal home, big4 to classic and back).

## Risks

- Baseline first: Canelin's current post may already fail `WildboundCandyBeastSites_Test` CC4.
- Which live props get archived (dry run, rule-based, archive instead of delete, backup).
- Moved posts must be open floor on the live map.
- The climb is longer (67 steps): tune after a walk (`GLAZE_EVERY` 7 -> 10 if too hard).
- Tight margins: junction 114 from the boss against 112 needed; route legs about 88 against 83.

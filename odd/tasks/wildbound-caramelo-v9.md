# Caramelo v9: the longer kingdom and the river five times wider

## Objective

Owner's words (2026-11-18):
- "y agranda mas el bioma caramelo a lo largo, el rio necesito qeu sea 5 veces su ancho asi es navegable por la balsa"
- Later: "que todos los biomas tengan el mismo tamaño, pero ahora hacelos mas largos aun. Lo del rio de chocolate que vaya de una punta a la otra (o sea como esta, pero que llegue al final de esos costados)"

Caramelo grows east to a 600 x 1200 big4 arm. The chocolate river runs the biome's length, end to end, five times as wide, and the banana raft sails it from one end to the other.

The plan is `docs/design/wildbound-caramelo-v9-plan.md` (CL-D1..CL-D18). The research, the three designs, the judges and the checkers are in `docs/handoff/caramelo-v9/`.

## Scope

- **In:**
  - Caramelo only: the plot, river, bridges, docks, raft code, nests, posts, houses, mountains, cloud wall, strips, client and server readers;
  - the big4 Meadow row (Studio-only copies);
  - the v9 migration tool.
- **Out, later tasks:**
  - the other three arms to 600 x 1200 (PD1);
  - the park's look;
  - the micro-phases;
  - classic mode.

## Parent decisions (PD1..PD6)

- **PD1.** All four big4 arms become 600 wide x 1200 long, outward. Caramelo goes first; the others are their own tasks.
- **PD2.** Caramelo grows east only.
  - The arm is x 412..1612, z -303..297.
  - The plot is x 412..1532, the cloud band x 1532..1548, and 64 studs of arm lie past it.
- **PD3.** The river runs along the length (x), end to end, keeping its look. It is 50..120 wide, and the raft sails it end to end.
- **PD4.** Bridges let the raft pass: raised decks.
- **PD5.** More than 2 docks.
- **PD6.** A live migration (v9) on the v8 pattern.

## Decisions taken for the user

- **The design.** Three independent designs were judged:
  - "least churn" (A);
  - "best game" (B);
  - "safest build" (C).

  C won with two of three judges: build risk 7.5 against A 6.5 and B 3.5, owner fit 8 against B 7 and A 5. The correctness judge preferred B (7) with C's mechanisms grafted on, and C scored 6 there.

  The final plan is C, with the judges' grafts:
  - the plot clip in `liquidDistance`;
  - side and end walls;
  - raft-reach and barrier flood fills;
  - no hives over chocolate;
  - a bigger M1 waterfall;
  - Epica nests on the cake bank;
  - piers under the raised decks;
  - basins under the river docks;
  - the `raftBlocks` fallback;
  - RESTORE.

  The synthesis also fixed C's two test failures:
  - posts closer than 30;
  - nests in the old syrup discs.
- **The river flows west to east.** The raft is the toy and the off-road crossing, not the fast way home: about 83 s upstream against 59 s walking. This is recorded as risk 2, and the lever is RIVER_SPEED or the raft's SPEED, tuned in Play.
- **The task log is its own file,** this one. `wildbound-caramelo-v2.md` is already very long.

## Checklist (all Done 2026-11-18; evidence below)

| ID | Task | Status |
|---|---|---|
| CL-D1 | Plot: `Layout.EAST = 860`, rectangle depth, CENTRE and HALF kept | Done |
| CL-D2 | Versions and marks (V3 VERSION 5, CaramelV9) | Done |
| CL-D3 | The river: 16 points, 50..120, plot clip, joint drums, basins | Done |
| CL-D4 | M1 source in the south-west corner at 0.75, kit offsets as data | Done |
| CL-D5 | The barrier as a flood fill | Done |
| CL-D6 | Routes: main to the moved Torta, new south and north, EAST_FORK | Done |
| CL-D7 | Three raised bridges with piers; Cookie.SINK 14 | Done |
| CL-D8 | Raft: `raftBlocks` fallback, any homeDock; 4 docks | Done |
| CL-D9 | Gran Torta, boss and tower +600 | Done |
| CL-D10 | Nests 28 → 45 | Done |
| CL-D11 | Creature posts: 4 moved, 8 new, AMBUSH east | Done |
| CL-D12 | Houses 10, mountains M1/M5/M7/M8, hills, KEEP_CLEAR | Done |
| CL-D13 | Ground, cloud wall, side and end walls, mouth, strips, big4 Meadow row | Done |
| CL-D14 | Client: Life, Ambience | Done |
| CL-D15 | Server: Duquesa, Flyers, FlyersService | Done |
| CL-D16 | Part budget (cap 3400, target 3100, MAX_NEW_PARTS 1600) | Done |
| CL-D17 | Migration tool `tools/wildbound-caramelo-v9-migrate.luau` and its suite | Done |
| CL-D18 | What stays (Portal, TrapCake, the v3..v8 tools) | Done |

All CL-D1..CL-D18 rows above are **Done (2026-11-18)**:
- code `11d035c`, fixes `791744d`;
- Studio suites;
- the real migration;
- solo Play checks (below).

### Decisions taken for the user (deploy)

- **Fresh-build cap raised.** `Builder.MAX_PARTS` went from 1450 to 1550. A fresh build measured 1470 in Studio, and the plan's budget section allowed this.
- **The queen's edge test moved.** In `WildboundCandyDuquesa_Test` RC6, the thief now leaves by the -z edge level with her seat. The west gate is out of her 20-second reach now that the Torta is 600 studs further east.
- **Big4Map_Test, a Studio-only copy, follows the longer arm.**
  - Caramelo's square is 1200 long and may end at x 1612.
  - The annex-plan case compares against the v8 square (x 412..1012): the growth comes from the plot's own floor and the stretched strips, not from the annex plan.
  - The other three arms keep 600.
- **Repo-only and Studio-only patches.**
  - `WildboundKittenPark_Test` KP7's fixtures moved +600 with the legacy second space.
  - `WildboundCandyEast_Test`'s header now matches the runner.
  - The big4 Meadow row is x 412..1612 in the Studio copies of WildboundBiomes and WildboundBiomeLight. The BiomeLight_Test comment was updated.

### Evidence

- **Deploy.**
  - Before writing, 37 Studio scripts matched commit `1988543` by fingerprint.
  - Hunks were applied to 36 scripts, and 2 new scripts were created: the `WildboundCandyV9Migrate_Test` module and the `WildboundCaramelV9Migrate` Script, which is disabled.
  - All 38 matched `11d035c`, and the two later fixes matched `791744d`.
- **Suites, fresh Play server VM:**
  - CandyLayout 28/0, CandyV3Layout 25/0, CandyRaft 18/0, CandyWade 6/0, CandyCookieBridge 15/0, CandyCurrent 12/0;
  - CandyLife 10/0, CandyEast 13/0, CandyV9Migrate 6/0, KittenPark 13/0, GatitoArea 4/0;
  - BeastSight (big4) 8/0, Big4Map 20/0, BiomeLight (big4) 12/0;
  - CandyV3Builder 22/0, CandyHouseNests 5/0, CandyHideSpots 16/0, CandyGrass 12/0, CandyTraps 12/0, CandyIsland 10/0;
  - CandyAmbience 14/0, CandyDuquesa 26/0 after the RC6 fix, CandyNests 27/0, BeastDonGlaseon 24/0, CandyFlyers 25/0;
  - Portal 12/0, PortalService 15/0, CandyTrapCake 11/0, CandySmarts 26/0, CandyKittens 7/0, CandyKittenArt 5/0;
  - CandyTower 9/0, CandyFrutillon 6/0, CandyGlaze 7/0, BeastDirector 53/0, BeastWiring 53/0, CandySky 4/0;
  - CandyBuilder 28/0 after the cap.
  - CandyBeastSites is 11/1. Its one failure is CC4, which already failed before v9 (a candy critter post close to a route, this time Mochimiau at 29.4).
- **Repo Python tests:** 20 failures, the same 20 as the previous commit, so none are new.
- **Migration.**
  - The dry run reported 2072 parts before and an estimate of 2799, against the 3100 target, with no warnings or refusals.
  - The real run made the backup `WildboundMapArchive.CaramelV9Backup` and archived 1469 parts. It left 2798 bioma parts and 10 Candy_Este_v1 parts, moved nests C6, C8, C10 and C13, and created 17 new nests.
  - Both annex strips were resized to x 412..1612.
  - A second run reported "already".
- **Live map, read in Edit.**
  - The floor is 1120 x 520 at (972, -3). The river has 61 parts, the lake 5, the bridges 33 and the docks 16.
  - The three bridges are at x 1142 with the deck top at y 13.0.
  - The docks are A (522, -194), B (912, -193), C (1342, 106) and D (1487, 126).
  - The Torta stands at (1420.2, -3) with LayoutKey "748.2,0,42".
  - Candy_Este_v1 has Collider x 1538..1542, the caps to 1612, SideWallNorth/South, EndWall at x 1612, MouthGuard, MouthSheet, and the Floor x 1532..1612.
- **Play, solo:**
  - The raft spawned at dock A's tip (522, -213).
  - Rays along the whole river centreline, at heights 3.5, 5.5 and 6.8 and offsets ±4, hit 0 collidable parts.
  - Under the three bridges at raft height the way is clear.
  - The ground is solid at x 1500, 1525 and 1600 and on both stretched strips. The character stood at y 3.6 at (1500, -150), (1525, 0), (1600, ±280), (1420, 60) and (1300, -100).
  - Rays met SideWallNorth at z 297, SideWallSouth at z -303, the EndWall at x 1612 and the Collider at x 1538.
  - The big4 biome at (1420, -3) is Meadow with the Caramelo preset, and (1600, 0) is Meadow.
- **Not seen:**
  - a person steering the raft end to end;
  - a creature under a raised deck;
  - the look of M1 at scale 0.75 and of the MouthSheet (3D captures render white);
  - the part count on a phone.

## Next step

- The owner plays it: sail from dock A to dock D under the three bridges, walk to the Torta and judge the look. The owner saves the place.
- Then the next tasks: the other three arms to 600 x 1200 (PD1), the park's look, the micro-phases.

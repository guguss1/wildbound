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

## Checklist

| ID | Task | Status |
|---|---|---|
| CL-D1 | Plot: `Layout.EAST = 860`, rectangle depth, CENTRE and HALF kept | Not started |
| CL-D2 | Versions and marks (V3 VERSION 5, CaramelV9) | Not started |
| CL-D3 | The river: 16 points, 50..120, plot clip, joint drums, basins | Not started |
| CL-D4 | M1 source in the south-west corner at 0.75, kit offsets as data | Not started |
| CL-D5 | The barrier as a flood fill | Not started |
| CL-D6 | Routes: main to the moved Torta, new south and north, EAST_FORK | Not started |
| CL-D7 | Three raised bridges with piers; Cookie.SINK 14 | Not started |
| CL-D8 | Raft: `raftBlocks` fallback, any homeDock; 4 docks | Not started |
| CL-D9 | Gran Torta, boss and tower +600 | Not started |
| CL-D10 | Nests 28 → 45 | Not started |
| CL-D11 | Creature posts: 4 moved, 8 new, AMBUSH east | Not started |
| CL-D12 | Houses 10, mountains M1/M5/M7/M8, hills, KEEP_CLEAR | Not started |
| CL-D13 | Ground, cloud wall, side and end walls, mouth, strips, big4 Meadow row | Not started |
| CL-D14 | Client: Life, Ambience | Not started |
| CL-D15 | Server: Duquesa, Flyers, FlyersService | Not started |
| CL-D16 | Part budget (cap 3400, target 3100, MAX_NEW_PARTS 1600) | Not started |
| CL-D17 | Migration tool `tools/wildbound-caramelo-v9-migrate.luau` and its suite | Not started |
| CL-D18 | What stays (Portal, TrapCake, the v3..v8 tools) | Not started |

## Evidence

(none yet)

## Next step

Write the tests and code (CL-D1..CL-D17), review them, then deploy to Studio following the plan's "Deploy order".

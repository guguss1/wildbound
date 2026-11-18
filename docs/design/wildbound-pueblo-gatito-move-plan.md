# Pueblo Gatito moves to the south arm (plan, 2026-11-18)

Owner's words (2026-11-18), after step 1 made the park its own biome
(`docs/design/wildbound-pueblo-gatito-biome-plan.md`): "Sí, movelo". This is step 2 of the approved order: the park moves
from behind Caramelo's cloud wall to its own side of the hub. The task log is `odd/tasks/wildbound-pueblo-gatito.md`.

## What is there today (Studio, read 2026-11-18)

The map is in big4 mode: four arms round the hub at (277, -3).

| Arm | Squares (x, z) | Contents |
|---|---|---|
| West | -418..182, -303..297 | Forest |
| East | 412..1012, -303..297 | Caramelo; behind its cloud wall at x 940 sits the park, x 948..1468, past the ground's x 1024 edge |
| North | -3..597, -943..-343 | Frozen Mountains decor |
| South | -3..597, 337..937 | Volcanic Lands decor (`WildboundVolcanicLands_Big4`) |

**The south arm.**
- The Volcanic Lands decor is 440 parts: Paths, Props, Signs, Markers, Zones and Ground.
- No game code reads it. Only the big4 tools mention it: `WildboundBig4Annex`, `WildboundMapModeSwitch`, `WildboundBig4Map_Test` and `MiedoRioBuilder`.
- It lies on `Apron_Volcanic`, 648 x 648 at (297, 637), top 0.32.
- Nothing else has a part in it. SistemaSonriente spans z -264..264 only.

**The road.** The big4 south road runs from the hub down x 282 to z 324.5 (`Road_big4_volcanic-lands_1`). From there three more pieces detour east and south to a gate marker at (582, 442).

## Decisions (PGM-D1..PGM-D9)

- **PGM-D1, one park frame.** A new shared module `ReplicatedStorage.WildboundGatitoArea` (`src/wildbound/WildboundGatitoArea.luau`) holds the park's frame:
  - origin (282, 600), yaw -90;
  - local +x runs from the gate (lx -260) to the far end (lx +260) and points to world +z (south, away from the hub); local +z points to world -x;
  - world(lx, lz) = (282 - lz, 600 + lx);
  - the floor square is x 22..542, z 340..860, inside the arm (3 studs from the arm's edge on the gate side, 25 west, 55 east, 77 south) and on the apron (27 to 101 studs inside it);
  - the gate arch at local (-254, 0) stands at world (282, 346), 21 studs south of the road's end.

  Every park position becomes park-local and is turned to world through this module:
  - KittenPark's nests, posts, chests, portal and arrival;
  - `WildboundPraderaSites.EAST_FIXED`;
  - `WildboundCandyKittens.PARK`.

  `WildboundPortal`'s "parque" station is the exception: that module stays pure, so it holds the world literals (239, 372) and yaw 0, and Portal_Test checks them against Area.

  `Area.V1` keeps the old frame (origin (1208, -3), yaw 0), so a K-D table value v converts with `Area.localOfV1`. The yaw is a multiple of 90 with exact trigonometry, so world numbers stay exact.
- **PGM-D2, its own root.**
  - The park moves into `Workspace.PuebloGatito_v1` (`Area.ROOT_NAME`): `Ground.Floor` (its own 520 x 520 green grass floor, laid by `WildboundKittenPark.buildGround`), `Park` and `Nests`.
  - `Workspace.Candy_Este_v1` keeps only the cloud wall, which is Caramelo's.
  - `WildboundCandyNests.PARK_ROOT` becomes `"PuebloGatito_v1"`. The server still reads it as a sibling of `Candy_Bioma_v1`, both under Workspace.
  - The resting service's floor ray reads `PuebloGatito_v1.Ground`.
- **PGM-D3, the biome square is the arm.**
  - The CandyEast square (tag unchanged, key `pueblo-gatito`) becomes the whole south arm, x -3..597, z 337..937, so the HUD says Pueblo Gatito on the apron round the park too, as Meadow covers Caramelo's apron.
  - In the big4 copies (Studio only) it replaces the Volcanic row of `AREAS_BIG4`.
  - In the classic copies it is the first row of `AREAS`.
  - The old 932..1468 row goes.
  - The light presets and the `Biomes.at` rule are unchanged; the arm does not overlap Caramelo's square.
- **PGM-D4, everything park-local.**
  - KittenPark:
    - `Park.NESTS` (ids, posts, chests, guards), `PORTAL` and `ARRIVAL` become local, taken from the K-D values through `Area.localOfV1`;
    - `plan()` takes its centre, floor top and square from Area instead of `WildboundCandyEast.plan`;
    - `build()` places every item at `Area.pivot(lx, lz, yaw)`;
    - `syncNests()` places nests the same way.
  - `Sites.EAST_FIXED` keeps its keys; its values come from `Area.world(...)` of the local posts.
  - The "parque" station is local (-228, 43) with local yaw 90, which is world (239, 372) with yaw 0.
  - `Kittens.PARK` = `Area.rect()`.
  - The four kittens, their zones of 60, their music, light and texts are unchanged.
- **PGM-D5, Caramelo's cloud wall closes.** With the park gone, the wall is Caramelo's own east edge, ahead of the longer-Caramelo task:
  - `WildboundCandyEast` drops the gate, so the Collider spans the whole band again;
  - `ColliderSouth` leaves the plan, and the move tool archives it;
  - the floor covers the band only, back in the plot's pink SmoothPlastic;
  - the caps and the Veil are unchanged.

  The cloud client's park face stays in the code: harmless, because nobody stands east of the wall now.
- **PGM-D6, the volcanic decor is archived.**
  - `Workspace.WildboundVolcanicLands_Big4` is reparented, whole, into `ServerStorage.WildboundMapArchive.GatitoSouthVolcanic`.
  - The road pieces 2-4 and the gate marker stay: they only lead round the park's east side. This is noted for the look step.
- **PGM-D7, the move tool.**
  - `tools/wildbound-pueblo-gatito-move.luau` is kept in Studio as the disabled Script `ServerStorage.WildboundPuebloGatitoMove`. It follows the KittenParkBuild pattern: DRY_RUN first, then one ChangeHistory recording, "PuebloGatitoMove", inside `task.delay`.
  - It runs only when `Candy_Este_v1` is marked KittenPark and no `PuebloGatito_v1` is marked moved.
  - Real run:
    1. back up `Candy_Este_v1` into `WildboundMapArchive.GatitoMoveBackup`;
    2. create `PuebloGatito_v1` and reparent `Candy_Este_v1.Park` and `.Nests` into it;
    3. `Park.buildGround`, `Park.build` (it conforms every moved part to the new frame) and `Park.syncNests`;
    4. archive the volcanic decor;
    5. `East.build(Workspace, Layout)`, then archive `CloudWall.ColliderSouth`;
    6. mark `PuebloGatito_v1` (`PuebloGatito = Area.VERSION`, `Key = "pueblo-gatito"`) and `Candy_Este_v1` (`KittenParkMoved = 1`);
    7. publish a JSON summary with part counts, and with a second `Park.build` that must report created 0 and changed 0.
  - Nothing is destroyed.
- **PGM-D8, what stays.**
  - The internal tag `CandyEast`.
  - The nest ids `GatitoK1..K8`.
  - The kittens' rows, posts by key, zones and guards.
  - Caramelo's `KEEP_CLEAR` gate row: harmless; the longer-Caramelo task takes it out.
  - The creature wall clamp (`Smarts.WALL_ROOT` stays `Candy_Este_v1`).
  - The old KittenParkBuild tool: kept as a record; it refuses to run again.
- **PGM-D9, docs.** The task file, the overview §3.1/§3.4/§13 rows and the biome plan's "Not in step 1" entry.

## Walk home

The hub is at (282, -3). The park's nests stand at z 430..750, so a carried egg walks 430-750 studs home, down the road. Before the move it was 830-985 studs through Caramelo.

## Tests

- New: `tests/WildboundGatitoArea_Test.luau` (GA1..GA4).
- Every suite that pins a park world number gets a "Deliberately changed (PGM-Dn)" note: KittenPark, CandyKittens, CandyKittenArt, Portal, BiomeLight, CandySky, CandyEast, CandyNests (PARK_ROOT).
- Deploy manifest and fresh-runner rows: the new module, its suite and the move tool.

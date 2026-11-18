# Caramelo v8: a bigger kingdom and a second space behind a cloud wall

Owner request (2026-11-17): "I want to make the Reino Caramelo map a bit bigger, in width and in length, so there is
more space between things: they are very close together. I want you to make another space of the same size, separated
by clouds: an invisible wall with a cloud texture that you can see through." Answered: "yes, start the map".

Status: plan written by the parent and decided for the owner. No code yet. Decisions are recorded in
`odd/tasks/wildbound-caramelo-v2.md` ("Caramelo v8").

## Facts this plan rests on

- Studio (b15ce60a, place 122652861404212) is in **big4 map mode** (`workspace.WildboundMapMode = "big4"`).
- Studio's WildboundBiomes and WildboundBiomeLight are the big4 copies from the unmerged branch `agus/big4-map`
  (worktree `E:\juego roblox\wb-big4`). In big4, the Meadow (Caramelo) square is x 412..1012, z -303..297 (600 x 600).
  The classic square stays x 412..812, z -203..197.
- **Ground.** `WildboundBig4Ground` ends at world x 1024. East of it is void.
- **Neighbours of the big4 Meadow square:**
  - Volcanic (x -3..597, z 337..937) and Frozen (x -3..597, z -943..-343).
  - Big4 roads at z 310..324 (x 275..625) and at x 275..289.
  - No road inside the square except `Road_pradera_1` (x 387..424, z -3), which ends at the Caramelo entrance (world 412, -3).
- **`WildboundCandyAnnex_Big4`** (719 parts) holds:
  - 3 candy ground slabs: x 812..1012 and two z strips;
  - 716 scattered prop parts filling the big4 square around the 400 x 400 Caramelo plot.
- **Part counts.**
  - `Candy_Bioma_v1` has 2188 parts saved in the place.
  - Its runtime count was about 2466 at the last Play start (grass off). The cap is 2800, but nothing enforces it.

## Decisions

### D1. The bigger plot: scale 1.3 about the centre, entrance fixed

- `Layout.HALF` goes 200 -> 260 and `Layout.CENTRE` goes (612, -3) -> (672, -3).
  - The plot becomes world x 412..932, z -263..257 (520 x 520).
  - The entrance stays at world (412, -3) on the hub road: local (-260, 0) = -HALF, so Layout_Test S1 still holds.
- The new plot fits inside the big4 Meadow square, so no AREAS row changes for the plot itself.
- **Classic mode is not supported by the bigger plot.** It would overlap the classic Caves and Mountains squares by about
  20 studs. The bigger Caramelo targets big4 mode, which is the live mode.
- **The transform.** Every v7 local point `p` (relative to the old centre) becomes `1.3 * p` relative to the new
  centre. A v7 world point `(x, z)` becomes `(672 + 1.3 * (x - 612), -3 + 1.3 * (z + 3))`. Layout exposes it:
  `Layout.V8 = { S = 1.3, OLD_CENTRE = { x = 612, z = -3 }, OLD_HALF = 200 }`, plus
  `Layout.fromV7Local(x, z)` and `Layout.fromV7World(x, z)` (pure; returns the new local or world x, z).
- **Positions scale; sizes do not.** The owner asked for more space between things, not bigger things. These stay as
  they are:
  - houses, mountains and their radii;
  - nests, the Torta and its tower and stair, bridge deck lengths, river widths;
  - every gameplay radius (plaza 58, territory 76, zones, clearances).
- **Re-anchored to the edge instead of scaled:**
  - ENTRANCE = (-HALF, 0);
  - the river's last point stays on the south edge (depth 0);
  - M1 stays at `HALF - r`, so the north barrier stays closed;
  - CRYSTAL_HILLS x = HALF - 2;
  - Sites.AMBUSH half = HALF and entrance = ENTRANCE;
  - builder scatter ranges become functions of HALF.
- **Translated with their parent (keep the offset):**
  - TOWER.glaze puddles move with the Torta;
  - BOSS.home moves with BOSS;
  - POOL, WATERFALL and the first river points move with M1's kit outlet;
  - each `WildboundPraderaSites.FIXED` post moves with its paired nest (keeps the 8-16 stud spacing);
  - bossHome = CENTRE + BOSS.home, bossTerritory = CENTRE + BOSS;
  - the portal station = CENTRE + PORTAL.
- **The water.**
  - River points scale, and the junction arc's radius 30.5 scales to about 39.7.
  - BRIDGE_ROWS `at` (stud distance along each leg) scales with the leg so the bridges still land on the river.
  - Every bridge must stay square to the river, and each dock tip must stay at least 6 inside the chocolate. The suites
    decide.
- **Literal copies to update together:**
  - `WildboundCandyLife.luau` (CENTRE, HALF, houses, flocks, flowers, fish);
  - `WildboundPortal.luau` (station);
  - `WildboundPraderaSites.luau` (MEADOW_CENTRE, FIXED, AMBUSH);
  - `WildboundCandyTrapCake.luau` (spots).
- **`V3.VERSION` 3 -> 4,** so the older migrations refuse to run.

### D2. The second space: "Caramelo Este", the same size, behind the cloud band

- A cloud band 16 studs wide runs along the plot's east edge, world x 932..948, for the plot's whole length (z -263..257)
  plus 8 at each end.
- The second space is the playable square east of it: world x 948..1468, z -263..257 (520 x 520), centre (1208, -3).
- **Ground.** One floor part covers the band and the space (x 932..1468, 536 x 520), with the same colour and
  FLOOR_TOP 0.5 as the plot. It is named `Floor` inside its own root `Workspace.Candy_Este_v1`, so the readers that look
  up `Candy_Bioma_v1.Ground.Floor` keep finding the first plot.
- **Content for now.** The annex props that the bigger plot covers move east into the second space, keeping their spread
  (0 new parts). No nests, creatures or eggs yet: the space is for the next steps (the owner's micro-phases).
- **Biome tag.** A new AREAS row `CandyEast` (key `caramelo-este`), x 932..1468, z -263..257, goes in both Biomes and
  BiomeLight, classic and big4 tables. BiomeLight TAG_PRESET maps `CandyEast` to "Caramelo", so the pink sky, light and
  clouds hold there. The Meadow-only creature rules do not apply there.

### D3. The cloud wall: you see through it, nobody crosses it

- **Parts in `Candy_Este_v1.CloudWall`:**
  - `Collider`: an invisible block, 4 thick and 80 tall, centred at x 940, as long as the band. Anchored, CanCollide
    true, CanQuery true, CanTouch false, CastShadow false, Transparency 1, Role "solid", never tagged WildboundBeastPass.
  - `Veil`: 16 thick, 80 tall, same length. ForceField material, cloud pink (255, 226, 240). CanCollide, CanQuery and
    CanTouch all false. The player sees through it.
- **Cloud look.** A client LocalScript, `WildboundCandyCloudWall.client.luau`, puts ParticleEmitters on the Veil:
  - texture `rbxasset://textures/particles/smoke_main.dds` (built in, no upload), slow big puffs, pink-white;
  - "Efectos suaves" (the world gui's Reduced) lowers the rate;
  - the emitters go away when the script goes.
- **Creatures never cross.** Creatures move by code, so the collider alone is not enough:
  - **Encounter creatures:** `Smarts.outsideWall` clamps any point east of `wallX - margin` back to it.
    `world.keepOut` in WildboundBeasts.server applies it after every step, BEFORE its `#discs == 0` early return.
  - **La Duquesa:** her service applies the same clamp. `Duq.plotDepth` counts the east edge again: the Torta's plaza
    now ends 54 studs from it, so the reason it was ignored (GT13) is gone.
  - **Bees:** their square bounds (the plot) already lose a target across the wall. No hive is placed east.
- Creature sight already treats a queryable collider as a blocker (RespectCanCollide false). The Veil is CanQuery false
  so it never blocks rays.

### D4. The live map: a v8 migration

`tools/wildbound-caramelo-v8-migrate.luau` follows the v5 pattern:
- a DRY_RUN first;
- a backup to `ServerStorage.WildboundMapArchive.CaramelV8Backup`;
- an `CaramelV8Archived` folder;
- one ChangeHistory recording, "CaramelV8";
- the root mark `CaramelV8 = 1` (it needs `CaramelV5`);
- a JSON summary.

It does this:
1. Grows `Ground.Floor` to 520 x 520 at the new centre (0 new parts).
2. Moves every saved model and part under `Candy_Bioma_v1` by pivot with `fromV7World`, keeping each piece's rotation
   and height. This covers:
   - trees, props, gumdrops, sweets, lollipops, the centre fill, filler and edge fill;
   - houses, mountains, licorice, cake, platforms, backdrop, edge hills;
   - the portal, the waterfall, the nests, the GranTorta with its LayoutKey set to the new key, and the queen's preview
     model.
3. Archives and lays again what is stretched geometry: the Paths, Boss with Ground.Plaza, the Markers, the water
   (River, Lake, Bridges, Docks via `layWater`) and the Tower (`syncTower`, through the new layout key).
4. Moves the annex props inside the new plot (x 412..932, z -263..257) into the second space by
   `(x + 536, z)`, and archives the annex ground slabs that the new floor covers.
5. Lays `Candy_Este_v1` (floor and CloudWall).
6. Reports the part counts of both roots before and after.

What runs at server start re-plans by itself from the new layout and the live map: the hide spots, traps, island, house
nests and the bees' hives.

## Work split (at most 3 non-Studio writers at once; one writer per file set)

- **A: layout data.** `tools/WildboundCandyLayout.luau`, `tools/WildboundCandyV3Layout.luau` and their suites
  (Layout_Test, V3Layout_Test, Builder_Test where it pins HALF), plus `tools/WildboundCandyBuilder.luau` scatter ranges.
- **B: satellites (after A).** `src/wildbound/WildboundPraderaSites.luau`, `WildboundCandyLife.luau`,
  `WildboundPortal.luau`, `tools/WildboundCandyTrapCake.luau`, and the suites that pin them (Life, Portal, Nests,
  BeastSites, TrapCake, Current, HideSpots, Grass, Traps, Island, Raft literals).
- **C: two spaces.**
  - `src/wildbound/WildboundBiomes.luau` and `WildboundBiomeLight.luau` (the CandyEast row), `WildboundCandySmarts.luau`
    (`outsideWall`), `tools/WildboundCandyDuquesa.luau` (plotDepth), the wall clamp hunks for
    `WildboundBeasts.server.luau` and `WildboundCandyDuquesaService.server.luau`;
  - a new `tools/WildboundCandyEast.luau` (pure plan plus build of the second floor and the CloudWall);
  - a new `src/wildbound/WildboundCandyCloudWall.client.luau`, `tools/wildbound-caramelo-v8-migrate.luau`, and the
    suites for all of it;
  - `tools/studio-fresh-runner.luau` SPECS for the new suites.
- **Parent:** Studio only. Fingerprints, hunk deploys, the migration's dry run and real run, Play checks, the task doc.

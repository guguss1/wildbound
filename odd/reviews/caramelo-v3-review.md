# Caramelo v3 review (commit 6d9c036, diff f5dae59..6d9c036)

Read-only review of `src`, `tests`, `tools` (Luau + `tools/export_caramelo_v3_kit_spec.py`) and
`docs/design/wildbound-caramelo-v3-plan.md`. Nothing was run (no Studio, no Python). Every geometry claim below was
recomputed by hand from `WildboundCandyV3Layout`, `WildboundCandyLayout` and `WildboundPraderaSites`.

## Summary

- **Blockers: none found.** No runtime error, wrong API name, wrong argument order, broken require path or mid-line
  `--` comment was found in the changed Luau. Every require path matches `tools/deploy_manifest.py`
  (`ServerStorage.WildboundCandyLayout`, `ServerStorage.WildboundCandyV3Layout`, `ServerStorage.WildboundCandyV3KitSpec`,
  `ReplicatedStorage.WildboundCandyRaft`, `ReplicatedStorage.WildboundText`, `ReplicatedStorage.WildboundNetwork`). The
  fresh-runner specs match the suites' parameter order.
- **Raft security is correct.** The client can send only `{ action = "Leave" }` (`Raft.request`), at most one every
  0.5 s per player (`Raft.allowed`), and only the current rider is served. No client position is trusted: boarding uses
  the server's root position and pivot. The rate-limit table is cleared on `PlayerRemoving`. There is no
  MarketplaceService or purchase code anywhere in the diff.
- **The migration tool is safe.** It refuses Play, refuses a root that already has the mark, and refuses
  `SistemaSonriente`. It never calls `:Destroy()`: everything goes to the archive by reparenting. It runs inside one
  ChangeHistory recording, which is cancelled on any error.
- **The river geometry is clean.** Nests are at least 6.6 studs from the chocolate (closest: C8), posts at least
  10 studs (closest: post C6), and trap cakes, the boss ground, the stair, the portal, the entrance and `KEEP_CLEAR`
  are all clear. The only place a route meets the chocolate is the bridge (|x| <= 44, ramps to 51).
- **The suites should pass as written.** I traced every assertion in `WildboundCandyV3Layout_Test`,
  `WildboundCandyV3Builder_Test`, `WildboundCandyRaft_Test` and the `WildboundCandyAmbience_Test` changes against the
  code, and found no contradiction. The live suites `WildboundCandyBeastSites_Test` (ground rays at posts and nests),
  `WildboundCandyBuilder_Test` (scratch builds only) and `WildboundCandyTower_Test` are not hit by the new parts.
  Two conditions apply: the chocolate, banks and decor must stay `CanQuery = false`, and the posts must be in
  `keepOut` (see m1).
- **The real risks are gameplay ones on the live map** (Major 1 to 4): creatures and houses or the bridge, the
  documented re-run path, and filler that ignores the props already on the map.

## Blocker

None.

## Major

### M1. Houses, the tower's upper floors, roofs and mountains interact badly with the candy creatures' movement
- Where: `tools/WildboundCandyV3Builder.luau:263-284`, `:561-579`, `:541-559` (placeholder roof `Roof` solid at
  floor+14..15; kit `Collision_Roof_*`, `Collision_Upper_Floor_*`, `Collision_Ceiling_*`, `Collision_Balcony_Floor` all
  get Role floor/solid via `applySpec` `:170-189`). They meet `src/wildbound/WildboundBeasts.server.luau:146-149`
  (`groundAt` casts down from `refY + 20` against every colliding part), `src/wildbound/WildboundBeastEncounters.luau:76-85`
  (`walk` snaps `pos.y` to that ground) and `src/wildbound/WildboundCandySmarts.luau:250-269` (`steer` treats any
  colliding part 2.5 studs up as a wall).
- Scenario: a player carrying an egg runs into a house (H1 to H7). The chasing critter's `steer` sees the walls and
  circles or reports "boxed in". When it does walk over the footprint, `groundAt` from `floor + 20` hits the roof
  (placeholder: 15.5 world) or an upper floor or ceiling below 20 studs. The critter teleports onto the roof, above
  the player. The flat distance is then about 0, but the height checks (`hitHeight`, `maxStep = 12`) fail, so no
  attack lands. Houses become safe rooms, against "creatures keep chasing until the base" (plan V3-D17).
  `world.landing` for ambushes (CH4) can also drop a critter on a roof or a mountain top.
- Fix: before the real migration, playtest a chase into a placeholder house and into a kit tower. Then do one of
  these:
  - (a) Give every v3 roof, ceiling and upper-floor collider a `Relief`-style exclusion: put them in a folder
    `CaramelV3.Overhead`, which `refreshFilter` adds to the `params` exclusion and which `groundAt` ignores.
  - (b) Accept houses as havens, but record that as a new decision (V3-D18) in the plan, with an owner sign-off,
    because it reverses RC.

### M2. The documented re-run path loses every swapped tree and La Nube's roofs
- Where: `tools/wildbound-caramelo-v3-migrate.luau:9-11` ("swapped for the kit later by archiving CaramelV3 and
  running again after clearing the mark"), `tools/WildboundCandyV3Builder.luau:836-841, 899-912` (new trees go into
  `root.CaramelV3.Trees`, each old tree is archived, and its `Roof` is moved into the new tree).
- Scenario: the kit arrives after a placeholder run. The parent follows the documented path: archive `CaramelV3`,
  clear the mark, run again. `swapTrees` then finds no old cotton, cream or cookie trees, because they are in
  `CaramelV3Archived`. The new trees, with every `WildboundRoof` disc, left with the archived `CaramelV3`. The map ends
  with no trees at the swapped spots and no La Nube cover.
- Fix: choose one.
  - Make `swapTrees` also upgrade placeholder trees already in `CaramelV3.Trees`: those with `Placeholder = true`
    and the `CaramelTreeV3` attribute. Keep `Trees` out of the "archive the folder" step, and document it.
  - Ship a `tools/wildbound-caramelo-v3-undo.luau` that moves the old trees back from `CaramelV3Archived` and returns
    each Roof to its old tree before the batch is archived.
  - At minimum, remove the re-run sentence from the tool header and the plan, until one of the two exists.

### M3. The bridge is a 102-stud wall across the lake for players, and a long detour for critters
- Where: `tools/WildboundCandyV3Builder.luau:494-503` (deck slab from floor+1.8 to floor+2.2, solid rails from
  floor+2.2 to floor+4.4 along both deck edges for the full 88 studs). Layout: `tools/WildboundCandyV3Layout.luau:87`.
- Scenario: the old crossing was flat biscuit tiles sunk to a low step (`WildboundCandyBuilder.luau:1164-1168`). A
  player wading north or south through the lake can no longer get past the bridge for its whole length:
  - The deck edge is at hip and root height, so the HumanoidRootPart (about floor+2 to floor+4) cannot pass under it.
  - The rail stands on top of the deck edge, so stepping up means a jump of more than 4.4 studs.
  
  This hits egg runs from C6 (10,-162) and C10 (-60,-162), and the posts C6 and C10 just south of the bridge. The
  critters' `castLane` sees the rails as walls, so a chase across the lake from the south slides along the rail
  towards a ramp end. The detour is up to 50 studs each way. The plan says the chocolate is walk-through (V3-D6), and
  "one bridge keeps every route walkable" only covers the east-west route.
- Fix: choose one.
  - Lift the deck so a player passes under it (deck bottom at least floor+6, with longer ramps).
  - Leave two or three 8-stud gaps in each rail, with a low step (a 1-stud `floor` block) beside the deck.
  - Accept the barrier, but record it in the plan and add a south-north crossing to the Play checklist (step 7).

### M4. The filler and the hills ignore the props already on the live map
- Where: `tools/WildboundCandyV3Builder.luau:391-411` (`openSpot` checks only layout data: routes, nests, boss,
  portal, entrance, `KEEP_CLEAR`, `keepOut`, the v3 pieces and the filler's own `taken`) and `:643-720` (bank props,
  three per house, six hills: solid placeholder mountains of r about 7 and up to 12 studs tall, or the kit medium
  mountain at 0.2). `swapTrees` nudges `:868-893` likewise ignore the filler.
- Scenario: on the real map (about 1300 parts of cotton trees, lollipops, gumdrops, sweets and sugar hills), a hill or
  a candy prop is laid straight onto an existing tree trunk, a gumdrop or a sugar hill, and the place is saved like
  that. A nudged new tree can also land inside a filler prop. The scratch suites cannot see this, because they build
  on an empty Model.
- Fix: in `layFiller`, seed `taken` with every Model pivot in `PROP_FOLDERS` that `plan` kept, using each one's
  measured reach (`V3Builder.measureTree(m).trunk` or `canopy * 0.7`). Or add a
  `workspace:GetPartBoundsInRadius(spot, reach, overlap)` check against `root` (`RespectCanCollide`). Pass the filler's
  `taken` list into `swapTrees` and reject tree spots that overlap it.

## Minor

### m1. Posts are protected only if `treeKeepOut` found the Sites module
`tools/WildboundCandyBuilder.luau:411-424` adds the posts only when `ServerScriptService.WildboundPraderaSites` and
`ReplicatedStorage.WildboundBeastConfig` are both present and `require` succeeds. The migration
(`tools/wildbound-caramelo-v3-migrate.luau:90`) does not check this. With an empty post list, filler, hills and nudged
trees may land within 4 studs of a post, and `WildboundCandyBeastSites_Test` (T4, CC4, CH1) then fails on the live map.
Fix: in the migration, assert that `keepOut` holds one entry per `Sites.FIXED` key (26 posts plus the trap cakes), and
report `keepOut` in the summary.

### m2. The dry run cannot catch the part budget
`tools/wildbound-caramelo-v3-migrate.luau:100-109` runs `plan` and `swapTrees` but not `layAll`. The
`report.parts <= V3.MAX_NEW_PARTS` assert (`WildboundCandyV3Builder.luau:755`) and `overCap` only show up in the real
run, after a full build. A rough count with both kits is 1100 to 1200 parts: two kit towers of about 90 colliders plus
meshes each, six mountains and six hills of the kit, and about 30 filler props. That is close to 1300. Fix: in the dry
run, call `layAll` into a detached `Instance.new("Model")`, report `laid.parts`, then let it be collected (it is never
parented, so nothing is destroyed on the map).

### m3. An existing backup is kept silently
`tools/wildbound-caramelo-v3-migrate.luau:130-132`: if `CaramelV3Backup` is left over from an older attempt or an older
map, the new run keeps it, and a later restore would bring back a stale map. Fix: name the backup with the root's
`PartCount` or a timestamp, or refuse (with a summary error) when one exists and its `LayoutVersion` or `CakeMoveV1`
differs from the root's.

### m4. The command bar may use stale module versions
`tools/wildbound-caramelo-v3-migrate.luau:38-41` requires the live ModuleScripts directly. If a fix to
`WildboundCandyV3Builder` or `V3Layout` is deployed after a dry run in the same Studio session, the command bar may
reuse the cached module; this is why the repo has the fresh runner. Fix: require `:Clone()`s, as
`studio-fresh-runner.luau` does, or note in the plan that Studio is restarted between deploy and run.

### m5. Dock B's ramp reaches into H6
`tools/WildboundCandyV3Builder.luau:526`: the ramp foot is at `stand - dir * 7`, about (162.4, -172.5) local. That is
17.6 studs from H6's centre (180, -172), and the 6-stud ramp's edge is 14.6 studs from it, inside H6's 16-stud
footprint. The house's front corner and its fence are likely to clip the ramp. `V3.pieces()` (`V3Layout.luau:236-238`)
models a dock only as a 3-stud disc at the stand, so V3-6 cannot see this. Fix: model each dock as its
stand-to-ramp-foot segment (or two discs) in `V3.pieces()`. Then move H6 about 4 studs east or south, or shorten the
ramp to 5 studs.

### m6. Raft: setting a rider down, the docked look, and motion
Where: `src/wildbound/WildboundCandyRaftService.server.luau`.
- `:34` and `:208-213` put the rider at `FLOOR_TOP + 3`, while the dock deck top is at `surface + 0.4`
  (floor + 1.7). The root lands about 1.6 studs inside the deck and physics pops it out. Use `V3.surfaceY(FLOOR_TOP) +
  0.4 + 3`.
- The dock deck runs 1.5 studs past the tip (`V3Builder.luau:523`), so it pokes through the docked hull (the raft's
  pivot is the tip), and the hull hangs over the bank. Shorten the deck to end 4 studs before the tip.
- `:197-222` calls `PivotTo` on the anchored raft every Heartbeat, even when docked (for the bob). Each of its parts
  replicates at the network rate without interpolation, so the rider's own view of the ride will look choppy. Bob and
  smooth the raft on the client, and move the server raft only while it is sailing or adrift.
- There is no way to call the raft back. Once it waits at dock B, a player at dock A has to wade (V3-D6 allows it).
  Note this in the plan, or add a "call" prompt on each stand.

### m7. `plan` misses props beside the bridge and on the dock decks and ramps
`tools/WildboundCandyV3Builder.luau:789` uses `V3.onBridge(x, z)` with no reach. Docks are only their stand disc. A
tree whose crown hangs over the deck, or that stands on a dock ramp, stays. Fix: test `onBridge` against the prop's
`solid` reach, and add each dock's deck segment to `pieces()` (see m5).

### m8. Small accuracy points
- `tools/WildboundCandyV3Builder.luau:861-865`: the measured prototype trees go through `ctx.counted`, so
  `swap.parts` overstates by the prototypes' parts. Count them in a separate context.
- `tools/WildboundCandyV3Builder.luau:457-458`: `WATERFALL.top = 19` is used as a world Y, not as an offset from
  `FLOOR_TOP`. It is right only because `FLOOR_TOP` is 0.5 and the kit ledge is 18.5. Use `ctx.top + W.top - 0.5`, or
  store the ledge height (18.5) and add `ctx.top`.
- `docs/design/wildbound-caramelo-v3-plan.md:44-45` says the river is "about 330 studs". The polyline is 253.7 studs
  (V3-2 asserts at least 250). Fix the number.
- The houses carry no `WildboundRoof` tag, so a player inside one is still "uncovered" for La Nube's sky ray. If
  houses should shelter from it, tag each roof collider. Otherwise, record that they do not.
- `tools/export_caramelo_v3_kit_spec.py:35-37`: the frame (X, Y, Z) = (-x, z, y) is a proper rotation, and the
  yaw/pitch signs and the `fromOrientation` order check out. It still depends on the FBX import keeping that
  convention. Default Blender FBX export (forward -Z, up Y) gives (x, z, -y), which is 180 degrees off. The plan's
  "check one house and M1 in Studio" step must happen before the real migration, not after.

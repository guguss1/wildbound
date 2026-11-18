REPORT: how the live Caramelo map is built and migrated (read only; no files edited, no Studio tools used)

All paths are under E:\juego roblox\wb-first-playable.

== 0. Facts that change the premise ==
- The river does not run along x. It runs north to south. It starts at M1's outlet on the north edge (V3 RIVER[1] = withM1(-8.36,154.08), about local z +214), runs round the junction's east side, goes through the lake, and ends on the south edge (z = -HALF). Sources: tools/WildboundCandyV3Layout.luau:109-160, and :85, which gives M1_DX,M1_DZ = (-1.2, +60).
- Test V3-14 (tests/WildboundCandyV3Layout_Test.luau:107-121) requires the river to be a barrier: every z line must meet chocolate west of the cake's territory. So making the plot longer in x does not make the river longer. A longer, navigable river means a new course.
- The plot is a square with one HALF:
  - Layout.HALF = 260 and CENTRE = (672, -3) (tools/WildboundCandyLayout.luau:24-26).
  - depth() = HALF - max(|x|, |z|) (:231-233).
  - ENTRANCE = (-HALF, 0) (:60).
  - V3Layout keeps its own copy, V3.V8 = { S = 1.3, HALF = 260, OLD_HALF = 200 } (V3Layout:42). Test V3-1 pins that it equals Layout.HALF (V3Layout_Test:54-56).
  - Layout_Test S2 pins HALF 260 and CENTRE 672, and asserts the plot stays inside the big4 Meadow square, x <= 1012 and z -303..297 (tests/WildboundCandyLayout_Test.luau:39-50). A plot that grows east past x 1012 breaks S2 and needs the big4 Biomes row changed.
- HALF appears 62 times in 15 tools/src files, among them Builder 14, V3Layout 9, v8 migrate 8 and V3Builder 6. A non-square plot means splitting HALF into an x half and a z half in all of them.
- KEEP_CLEAR still holds the gate row { x = 250, z = 0, r = 16, "Cloud gate to Caramelo Este" } (Layout.luau:125). PGM-D8 says the longer-Caramelo task removes it (docs/design/wildbound-pueblo-gatito-move-plan.md:90).

== 1. The migration pattern, step by step ==
The chain so far: cake-move (mark CakeMoveV1) -> v3 -> v4 -> v5 -> v8. There are no v6 or v7 map migrations. v6 (the island) and the runtime pieces re-plan at server start.

Files:
- tools/wildbound-caramelo-cake-move.luau (MARK CakeMoveV1, :40)
- tools/wildbound-caramelo-v3-migrate.luau (needs CakeMoveV1 and LayoutVersion 3, :99)
- tools/wildbound-caramelo-v4-migrate.luau (needs V3.VERSION == 2, :74)
- tools/wildbound-caramelo-v5-migrate.luau (needs V3.VERSION == 3, :70)
- tools/wildbound-caramelo-v8-migrate.luau (needs V3.VERSION == 4 and HALF == 260, :101-104)

Every version bump of V3Layout makes the older tools refuse to run. A v9 tool would need V3.VERSION 5 and a new mark.

The v8 steps (tools/wildbound-caramelo-v8-migrate.luau):
a. DRY_RUN = true by default (:47).
   - Edit mode only: assert not RunService:IsRunning() (:50).
b. It loads fresh module clones through module(), which does require(found:Clone()) (:69-75).
   - If the clone fails it falls back to the cached require (:74).
   - It asserts each dependency (:100-122): the Layout (V8, fromV7World, HALF 260), V3 VERSION 4, V3Builder.layWater, Builder.layPaths / layBoss / layMarkers / syncTower / syncNestPositions / layoutKey, Kit and WildboundAssets.CandyKit, East.build and annexGround, Duq.seatPivot and Frut.summit.
c. Preconditions (:123-128):
   - Workspace.Candy_Bioma_v1 exists and is not SistemaSonriente;
   - the root has CaramelV3 and a CaramelV3 folder;
   - the root has CaramelV5.
d. Idempotency (:144-149): if the root already has CaramelV8, it publishes the summary with already = true and the mark, and returns.
e. Summary (:140-142, :87-93):
   - Fields: dryRun, already, version, half, archived, snapped, moved, warnings, cap, and partsBefore {bioma, annex, east}.
   - Published as JSON to ServerStorage attribute "WildboundCaramelV8Summary", to _G.WildboundCaramelV8Summary, and to print.
f. Dry run (:468-491):
   - It runs makePlan, sonriente(), annexPlan and describe.
   - probe() lays Paths, Boss, Markers, the water and East into a detached scratch Model, counts the parts, then destroys it (:450-466). This is the only :Destroy in the tool; East_Test pins that there is exactly one (tests/WildboundCandyEast_Test.luau:411-413).
   - partsEstimate = before - archived + relaid + towerEstimate.
   - overCap = estimate > V3.BIOME_PART_CAP.
g. Real run:
   - The attribute is set to "pending" first (:494).
   - task.delay(0.5) (:496), because execute_luau is already a recording.
   - ChangeHistoryService:TryBeginRecording("CaramelV8"). If that fails, the summary says "nothing was changed" (:497-503).
   - Everything runs in a pcall. FinishRecording uses Commit on success and Cancel on failure; a failure is reported as "failed and undone" (:584-586).
h. Archive and backup folders (:505-532):
   - ServerStorage.WildboundMapArchive.CaramelV8Archived: everything archived is reparented here, never destroyed (:538-540).
   - ServerStorage.WildboundMapArchive.CaramelV8Backup: holds clones of root, annex, queen and pradera.
   - If a backup folder already exists, it is kept, no new backup is made, and a warning is added (:518-520).
i. Order of the real run:
   - 0: backup.
   - Plans computed before any change (:534-537).
   - 1: Floor resized to HALF*2 x HALF*2 at CENTRE (:542-547). This is square-only code.
   - 2/3: archive, move, then the relays (:549-561):
     - torta LayoutKey;
     - layBoss, layPaths, layMarkers, layWater;
     - syncTower (only if a GranTorta exists);
     - syncNestPositions.
   - Queen and raft (:563-566).
   - 4: annex archives, moves and resizes (:568-574).
   - 5: East.build (:576).
   - 5b: Pradera marker (:579-580).
   - 6: root:SetAttribute("CaramelV8", 1) (:582).
   - partsAfter and overCap are computed after the recording (:587-589).
j. SistemaSonriente refusal:
   - forbidden() is true for the name, or for any descendant of it (:76-78).
   - It is checked on the root (:125), on the annex, queen and pradera (:131-136), in every plan walk (:180, :190, :214, :226) and in archive (:539).
   - sonriente() reads its parts read-only, as avoid discs of radius max(size)/2 + 4 (:291-300). Annex props that would land on it are archived (:351-353). A warning is added if it stands on the new floors (:441-445).
- v3, v4 and v5 follow the same skeleton: their own SUMMARY_ATTRIBUTE, a <Ver>Backup holding a clone of the root only, a <Ver>Archived folder, one recording and a root mark. v8 adds the annex, the Pradera marker and the queen to the backup.

How v8 moves pieces (makePlan, :177-288):
- Each piece moves by pivot to Layout.fromV7World(pivot), keeping its rotation and height through slid() (:154-156).
- It snaps to its layout spot when SPOTS names it (:164-174):
  - Mountains by MountainId;
  - Houses by HouseId;
  - Platforms by PlatformIndex;
  - EdgeHills by CrystalSpot;
  - the LicoriceArch;
  - the CakeModular.
- Fixed targets: GranTorta goes to CENTRE + TORTA and Portal to CENTRE + PORTAL (:258-261).
- The Waterfall moves by M1's delta (:274-278).
- A piece whose target x is greater than EAST_EDGE = CENTRE.x + HALF is archived (:206-208). Only the east side is checked; nothing checks north or south overflow.
- HANDLED, which the general walk skips: Ground, Paths, Boss, Markers, Tower, GranTorta, Portal, Nests, CaramelV3 (:64-65).
- RELAID: Paths, Boss, Markers, Tower are archived and laid again (:62, :236-239), together with Ground.Plaza (:241-247).
- The summit nest Nest_T1 is archived and relaid by syncTower (:250-253).
- RUNTIME folders are archived if found saved: HideSpots, LicoriceGrass, CaramelTraps, LakeIslands (:63).
- The CaramelV3 water folders (River, Lake, Bridges, Docks) are archived for layWater (:264-273).

Recorded v8 result (odd/tasks/wildbound-caramelo-v2.md:824-830):
- 242 pieces moved, 30 archived (14 of them backdrop pieces).
- Relaid: Paths 27, Boss 26, Markers 15, water 150, Tower 126 parts.
- Annex: 70 props moved, 6 archived, 2 slabs resized.
- Pradera marker (627, 107) -> (691.5, 140).
- Parts: bioma 2188 -> 2072, annex 719 -> 698, east 5. Runtime in Play: 2350 (:837-838).

== 2. What the builders lay, and the part budgets ==
A fresh build, Builder.build (tools/WildboundCandyBuilder.luau:1085-1397):
- Ground.Floor: one block HALF*2 x 1 x HALF*2 (:1160). Square.
- Paths (layPaths): one glaze joint drum per unique route point plus one block per leg, PATH_WIDTH 14 (:762-784).
- GranTorta (placeTorta): the kit's CakeTower scaled to TORTA.radius 42, carrying LayoutKey (:837-844).
- Ground.Plaza and Boss (layBoss): plaza drum r 58, BossTerritory r 76, and 12 posts with 12 caps, 26 parts (:788-810).
- Lake: Syrup discs and CookieBridge tiles. These are the old lake, archived by v3.
- Nests: the kit Nest per Layout.NESTS entry, 28 floor nests (:1179-1190).
- Entrance: posts, sign, 2 giant lollipops, DonutGate.
- Lollipops, CottonTrees, Gumdrops (30), Sweets, the extra trees (syncTrees), SugarHills (an empty folder).
- Portal and the centre fill (syncCentre).
- Markers (layMarkers): 15 (:813-833).
- Scatter ranges use HALF: rng(-HALF+10, HALF-42) (:1278), the plant bands (:1315-1316) and the avenue slots Ã— V8.S (:507-509).
- The tower is outside build: Builder.syncTower (:168-284) lays the stair (67 steps), the turntables, the Spin dollops (16 per turning tier), the Glaze discs and the summit nest. It carries LayoutKey "x,z,radius" (:77-79).
  - Caution: if an old Tower has a different key, syncTower Destroys it and the summit nest (:178-181). It does not archive them. v8 avoids this by archiving the Tower first.

The v3 batch, V3Builder.layAll (tools/WildboundCandyV3Builder.luau:978-1057). It lays into CaramelV3:
- Mountains (kit or placeholder; MountainId; tagged overhead);
- River, Lake and pool (layLiquid);
- Waterfall (layWaterfall: Foam, 5 Streaks, and Sheet/Lip when it is a placeholder);
- Bridges, Docks;
- Houses (HouseId, Interior);
- Licorice, Cake, Platforms (on pedestals);
- Trees (an empty folder for the swap and the edge fill);
- Filler: bank candy every 22 studs along riverSamples, 3 per house, 4 edge hills;
- EdgeHills at CRYSTAL_HILLS (x = HALF - 2);
- Backdrop: V3.BACKDROP is empty in v8 (V3Layout:410);
- EdgeFill: a jittered band plus the interior, with its own 600-part budget.

The water, layWater (V3Builder:1604-1630). It refuses if any of River, Lake, Bridges or Docks is present (:1612-1614). It builds detached, parents at the end, and sets the live CaramelV3 Version and PartCount. What it lays:
- River (layLiquid, :468-507), for each RIVER point:
  - a Choco_Joint drum of radius w/2, unless the point is on the edge;
  - per leg, a Choco_River block as wide as the wider end (V5-D14);
  - per leg, two Bank_ blocks, 2.4 wide, at Â±(w/2 + 1.2);
  - all decor and liquid, walk-through, depth 3.5 (V3.LIQUID, V3Layout:75).
  - Choco_Pool: a drum at POOL, r 4.95.
- Lake: one drum per V3.LAKE disc. Today 2 discs: r 34.5 at local (10.4, -127.4) and r 18 at (-18.2, -148.2).
- Bridges (layBridge, :549-596), per V3.BRIDGES entry:
  - Deck (width 15, top 4.1 over the floor);
  - 2 end ramps of 9;
  - rails and caps between the gaps;
  - side ramps in each gap;
  - attributes Route, BridgeId, DeckY.
  - BRIDGE_BUILD is at V3Layout:201 and the rows at :205-229. Top and Bottom are 28 long with gaps {0}; RightLast, Main and LeftLast are 11 long with no gaps.
- Docks (layDocks, :606-634), per V3.DOCKS entry: Deck, Ramp, 2 Posts, tag WildboundCandyRaftDock, StandX/Z, DeckY. Today 2 docks, A and B (V3Layout:263-275); RAFT.homeDock = 1.

My count of today's water: River 23 joints + 23 legs Ã— 3 + 1 pool = 93; Lake 2; Bridges 13 + 13 + 7 + 7 + 7 = 47; Docks 2 Ã— 4 = 8. Total 150, which matches the recorded "water 150".
- The count does not grow with width: a wider river or longer decks use the same number of parts.
- It grows only with more river points (3 per leg), more bridges (7 to 13 each) and more docks (4 each).

Part budgets:
- Builder.MAX_PARTS = 1450: asserted in a fresh build (Builder:15, :1374).
- V3.MAX_NEW_PARTS = 1300: asserted in layAll (V3Layout:426; V3Builder:1040).
- V3.EDGE.maxParts = 600 (V3Layout:383).
- V3.BIOME_PART_CAP = 2800 and V3.V4_PART_TARGET = 2700 (V3Layout:427-430). Only reported (overCap); nothing enforces them (v8 plan line 26).
- East: 5 parts.
- Live after v8: 2072 saved, 2350 runtime.

== 3. Regenerated vs moved, for a longer plot and a 5x river ==
Needs code changes before anything can be laid:
- The river is today's data: widths 10 to 24, so 50 to 120 at 5x.
- The v3-2 test requires depth(p) - w/2 >= 2 for every point except the last (V3Layout_Test:91). At w 120, the centreline must stay 62 or more studs from every edge.
- Each joint is a drum of radius w/2, so at a bend it becomes a disc of radius 30 to 60.
- The pool (r 4.95) and M1's kit outlet (RIVER[1], w 12) are sized for a narrow start.
- Every bridge must sit on one straight route leg with its deck and ramps inside the leg (V3-4, V3Layout_Test:136-186). Decks must cover a 50 to 120 wide channel. Today's 11-stud junction bridges sit on legs of about 90 studs.
- Raft.area treats any bridge footprint (deck, ramps, side ramps) as a wall: `V3.liquidDistance(lx, lz) <= -r and not V3.nearBridge(lx, lz, r)` (src/wildbound/WildboundCandyRaft.luau:78-85). Raised bridges need V3.nearBridge or Raft.area changed.
- Docks are layout rows; adding a row adds a dock (4 parts) through layDocks.

Regenerated from the layout (archive first, then call the existing helper):
- Paths (layPaths, refuses an existing folder);
- Boss + Ground.Plaza (layBoss);
- Markers (layMarkers);
- CaramelV3 River, Lake, Bridges, Docks (layWater);
- Tower + summit nest (syncTower; relaid when LayoutKey changes, which happens whenever the TORTA x/z/radius changes);
- Candy_Este_v1 (East.build re-conforms Floor, Collider, Veil and caps in place to the new plan, with 0 new parts and no deletions; East.luau:273-301).

Not covered by any exported helper:
- The Waterfall: layWaterfall is local and only layAll calls it (V3Builder:512, :1008). layWater does not relay it.
- The bank Filler: only layAll lays it, along riverSamples (:792-804). v5 only archived bank props in the wider river and laid none.

Re-planned by themselves at server start (no migration step needed; archived if found saved):
- HideSpots: read V3.liquidDistance and the live River and Lake parts (tools/WildboundCandyHideSpots.luau:14-15, :131, :477-481).
- House nests: read the live houses and move a nest more than 0.5 off its spot (tools/WildboundCandyHouseNests.luau:1-10, :158-164).
- Traps, LicoriceGrass, LakeIslands (island I1 is V3.ISLANDS, which moves with lake disc 1; V3Layout:319-324).
- The Edit raft is rebuilt in Play at homeDock by RaftService.

Moved by pivot (the v8 move logic; a v9 needs a new transform in place of fromV7World):
- the old-kit prop folders: CottonTrees, Lollipops, Sweets, Gumdrops, Entrance, the centre fill;
- CaramelV3 Trees, Filler, EdgeFill;
- the Nests: floor nests snap through syncNestPositions (Builder:848-864); house nests are re-seated at start;
- the queen preview (Duq.seatPivot);
- the Pradera marker (WildboundPraderaSites offsets are relative to it);
- an Edit raft.

Snapped to new layout spots (data must be updated first):
- Mountains (M1 must stay on the north edge and close the barrier);
- Houses, Platforms (they float in lake discs), EdgeHills (x = HALF - 2), LicoriceArch, CakeModular;
- GranTorta and Portal (fixed targets);
- Waterfall (moved by M1's delta).

After moving, props in the new chocolate must be archived. V3Builder.planV5 does this (:1558-1598), but only for PROP_FOLDERS and CaramelV3 Trees/Filler/EdgeFill. By design it never checks nests, houses, mountains, cake, licorice, platforms, waterfall or edge hills (:1556-1557). The layout tests must keep those off the chocolate:
- V3-5: nests 6 or more from the liquid, posts 8, trap cakes 10, boss territory, stair, portal 16, entrance 28, KEEP_CLEAR (V3Layout_Test:188-210);
- V3-6: piece clearances.

Floor: v8 resizes it square (migrate:545). A non-square plot needs Size.X â‰  Size.Z and a new CENTRE. Builder.build's floor line (:1160) and the scatter ranges need the same change.

== 4. The big4 annex around Caramelo ==
- Workspace.WildboundCandyAnnex_Big4 held 719 parts before v8: 3 slabs plus 716 prop parts (v8 plan:21-23).
- v8 step 4 (migrate:303-370; East.annexMove :146-151; East.annexGround :167-212):
  - props inside the plot moved by (x + 536, z), East plan shift = 2*HALF + 16;
  - props in the band were archived;
  - a moved prop within 6 studs (APART) of another, or over SistemaSonriente, was archived;
  - props elsewhere (the strips) were kept.
- The floors were treated as one rectangle, x plot.minX..space.maxX (412..1468) by the plot's z. Because it spanned the slabs' x range, the slab overlapping each strip most was resized to that strip and the rest archived.
  - Test fixture (East_Test:302-312): Floor_Big4_2 -> x 412..1012, z -303..-263; Floor_Big4_3 -> x 412..1012, z 257..297; Floor_Big4_1 (x 812..1012) archived.
  - Recorded: 2 slabs resized (caramelo-v2.md:828). The live slab names were not confirmed; only the fixture names are known.
- Then the KittenPark build archived all 91 annex props whose pivot lay in the second space into WildboundMapArchive.KittenParkAnnex (tools/WildboundKittenPark.luau:1551-1565; odd/tasks/wildbound-pueblo-gatito.md:148, :160). No slab moved.
- What the annex holds now: the two strip slabs plus whatever props stand in the strips. I could not determine the current annex part count.
- How the strips relate to the wall and the ground:
  - The strips' top is level with the plot floor; they were resized so they do not fight it.
  - CloudWall CapNorth (x 938..1468, z 261..265) and CapSouth (x 938..1468, z -271..-267) cross the strips at x 938 and beyond, so nobody walks round the wall on a strip (East.luau:22-26, :91-96; East_Test:105-106).
  - The strips end at x 1012, the grey Baseplate (WildboundBig4Ground) at x 1024, and east of that is void (v8 plan:16; East.luau:24-26).
- For a longer plot:
  - Growing east moves wallX = CENTRE.x + HALF + 8; East.build re-conforms the wall and caps (0 new parts).
  - Any plot floor east of 1024 is the plot's own Floor part. The strips and Baseplate would not reach past x 1012/1024 north and south of it. I did not check whether the plot's north and south edges have a wall.
  - Growing in z would overlap the strips. annexGround handles that only when the floors span the slabs' whole x range; otherwise it lists overlaps.
  - The annexGround and annexMove rectangles depend on HALF being square (plot and space are both CENTRE Â± HALF).
- WildboundBig4Annex itself is not in this worktree (big4 branch agus/big4-map), so I could not read the slab source.

== 5. Risks recorded by v8 ==
- Warnings the summary can carry (migrate:418-445, :518-520, :559):
  - no annex;
  - no Ground.Floor ("not grown");
  - an older backup kept ("check it before any restore");
  - no GranTorta, so the Tower was not relaid;
  - the Pradera marker not at its v7 pivot, or missing (the sites fall back to MEADOW_CENTRE);
  - SistemaSonriente on the new floors.
- Annex notes: a turned slab is left as it is, a slab sharing a name with another is left, a slab still meeting the floors is listed (:315-318, :330-332).
- overCap against 2800 is reported, not enforced (:485, :588).
- The plan doc says:
  - classic mode is unsupported; the plot would overlap the classic Caves and Mountains squares by about 20 studs (v8 plan:36-37);
  - the cap is not enforced (v8 plan:26);
  - four literal copies must be updated together: WildboundCandyLife, WildboundPortal, WildboundPraderaSites, WildboundCandyTrapCake (v8 plan:66-70).
- The task log (caramelo-v2.md):
  - the big4 Biomes and BiomeLight copies were patched in Studio only as hunks, so the big4 branch needs the same lines when it merges (:801-807);
  - fixer amendments were needed for the end caps, the empty backdrop and the Pradera marker (:808-811);
  - island I1 was shrunk to keep the raft channel, IS1 margin 0.44 (:812-813);
  - not checked: how anything looks; Studio's 3D view rendered white after the migration (:842-843).
- Structural risks in the code:
  - syncTower Destroys a stale Tower (Builder:178-181);
  - module() can fall back to a cached require (migrate:74);
  - only the east side is checked for overflow (migrate:206).
- PGM-D5 closed the wall "ahead of the longer-Caramelo task" (pueblo-gatito-move-plan.md:64-70). East.plan still returns space and shift, which only the annex, v8 and KittenPark code read (East.luau:6-10).

== Could not determine ==
- The live annex slab names and the annex's current part count.
- SistemaSonriente's x extent: only z -264..264 is documented.
- Whether the plot's north and south edges are walled.
- Today's exact river length; V3-2 only requires 340 or more.
- WildboundBig4Annex / WildboundBig4Ground source (not in this worktree).


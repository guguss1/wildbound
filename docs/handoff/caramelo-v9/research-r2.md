RAFT AND WATER GAMEPLAY IN CARAMELO: RESEARCH REPORT (read-only, no files edited, no Studio used)

Coordinates: "plot" means local to Layout.CENTRE = (672, -3) (tools/WildboundCandyLayout.luau:24), with HALF = 260 (:25). FLOOR_TOP = 0.5 (:51). The chocolate surface is at world Y 4.0, which is floor + LIQUID.depth 3.5 (tools/WildboundCandyV3Layout.luau:75, 503-505). I computed the v8 numbers below from the v7 literals Ã— 1.3 and the withM1/withDisc offsets in V3Layout.

Orientation fact you need first: the river runs north to south along z, not along x. It goes from plot (-9.56, 214.08) to (39, -260), and its centreline stays between plot x -13.2 and +39.65 (world x about 659..712). Making the biome longer along x does not make the river longer unless the river is rerouted.

v8 river points (x, z, width): 1 (-9.56, 214.08, 12); 2 (-13.2, 198, 19); 3 (-13, 170.3, 19.5); 4 (-11.7, 160, 24); 5 (-3.9, 135.2, 24); 6 (6.5, 106.6, 24); 7 (14.3, 80.6, 24); 8 (16.9, 70.2, 24); 9 (15.6, 65, 16); 10 (15.6, 57.2, 10); 11 (14.63, 39.09, 10); 12 (24.78, 30.97, 10); 13 (35.74, 17.17, 10); 14 (39.65, 0, 10); 15 (35.84, -16.98, 10); 16 (25.10, -30.68, 10); 17 (15.04, -38.91, 10); 18 (15.6, -54.6, 14); 19 (22.1, -75.4, 20); 20 (18.2, -117, 24); 21 (31.2, -162.5, 24); 22 (35.1, -182, 24); 23 (37.7, -221, 24); 24 (39, -260, 24). Source: V3Layout.luau:123-160.

Lake discs: disc 1 at (10.4, -127.4), r 34.5; disc 2 at (-18.2, -148.2), r 18 (:181-190). Island I1 at (18.9, -102.4), r 6 (:319-324).

(1) HOW THE RAFT MOVES
- The raft is scripted, not physics. Every Heartbeat the server steps pure rules and calls model:PivotTo (WildboundCandyRaftService.server.luau:147-150 and 256-290). Every part is Anchored, CanCollide/CanTouch/CanQuery false (:49-51, 71, 84). The VehicleSeat has MaxSpeed/Torque/TurnSpeed 0 (:104). The server reads seat.ThrottleFloat and seat.SteerFloat (W/S, A/D, touch thumbstick) from the seated rider only (:263-266). The client only sends {action="Leave"} (client :88-90), validated by Raft.request and Raft.allowed with REQUEST_GAP 0.5 s (WildboundCandyRaft.luau:45, 300-311).
- Steering is free anywhere inside Raft.area; there is no path. The constants are in WildboundCandyRaft.luau:28-51:
  - SPEED 20 studs/s; REVERSE 7.5; ACCEL 6 /sÂ²; BRAKE 10 /sÂ²; DRAG 3 /sÂ².
  - TURN_RATE 70Â°/s (1.2217 rad/s) at speed â‰¥ TURN_FULL 6. Below that the turn rate scales with |speed|/6, floored at TURN_MIN 0.3, so a still raft spins at 21Â°/s.
  - The turn is reversed when going astern (:263-265). dt is capped at 0.5 s (:241).
  - Derived (my arithmetic): turning radius is 16.4 studs at 20 studs/s and 4.9 studs from 1.8 to 6 studs/s. A full-speed U-turn needs about a 33-stud circle; today's 24-wide river leaves only 18 studs for the hull centre. 0 to 20 takes 3.33 s over 33 studs; coasting from 20 to 0 under drag takes 6.7 s over 67 studs.
- Movement rule, shift() (:197-219): the raft tries the whole step. If that fails it tries the x-only part, then the z-only part, each only if it keeps SLIDE_SHARE 0.1 of the step ("Slid", which brakes it). Otherwise it is "Blocked" and speed goes to 0 (:267). This is a point check at the new position, not a swept check.
- Current: while Sailing or Adrift, a second shift adds flow Ã— dt through the same rule, capped at CURRENT_MAX 4 (:94-101, 229-232, 269, 281). Ground speed is therefore 24 downstream and 16 upstream on the river legs.
- Size of BalsaBananaSplit:
  - Kit CV3_BananaRaft bounding box: 8.64 Ã— 7.90 Ã— 14.2 (tools/WildboundCandyV3KitSpec.luau:132).
  - Hull collider: 7 Ã— 1.94 Ã— 12.4 at y -0.28, so it spans pivot -1.25 to +0.69 (:10-14). The bow scoops collider reaches +3.7 (:59-63). The seat anchor is at (0, 1.2, 1.6) (:128-131).
  - Placeholder: Hull 7 Ã— 1.9 Ã— 12.4, with a cherry top at +3.9 (Service :88-91).
  - The pivot sits on the chocolate surface (world Y 4.0) plus a bob of Â±0.15 with a 2.4 s period, and it bobs only while moving (Service :147-149; Raft :51, 314-317).
  - The rules treat the hull as a circle of HULL 3 studs (:36), smaller than the real half-width 3.5 and half-length 6.2. The visual hull can therefore overhang a bank or a bridge footprint by up to about 3 studs.
- States: Docked, Boarding (DEPART_SECONDS 1), Sailing, Adrift (RESPAWN_SECONDS 8, then teleport home), Called (CALL_SECONDS 3, then teleported to the caller's dock; it does not sail there: "V4-D11-R1 ... no path", :175-187, 290-293). One rider only.

(2) WHAT Raft.area IS
- WildboundCandyRaft.luau:78-90: inside(x, z, r) is true when V3.liquidDistance(lx, lz) <= -r and not V3.nearBridge(lx, lz, r). Here lx, lz are world minus centre, and r = HULL 3, or 0 within ARM_STUDS 9 of a dock tip (:200-203). flow(x, z) is Current.flow(V3, lx, lz).
- The service builds it as Raft.area(V3, Layout.CENTRE, Current.flow) (Service :36).
- V3.liquidDistance (V3Layout.luau:471-476) is the minimum of:
  - riverDistance: for each leg, the distance to the centreline segment minus max(a.w, b.w)/2 (:445-452). Each leg counts as wide as its wider end.
  - the pool disc (r 4.95);
  - the two lake discs.
  It is then maxed with minus the island distance, so islands count as dry.
- The builder lays each leg as a non-colliding block max(w)-wide Ã— 3.5 deep (V3Builder.luau:468-506) to match. It also lays decor banks at w/2 + 1.2 (:490).
- So the hull-centre band is w - 6: 18 studs on the 24-wide legs, 8 on the 14-wide leg 17-18, and 4 on the 10-wide junction arc.
- Today the only water the raft can reach from its docks is the lake plus legs 17-21. It runs from just south of the LeftLast bridge (plot z about -41) to just north of the Bottom bridge's footprint (z -162.5). Nothing outside that is reachable, because the bridges wall it off.

(3) WHY BRIDGES BLOCK, AND WHAT CLEARANCE A RAISED BRIDGE WOULD NEED
- The block is purely 2D: V3.nearBridge (V3Layout.luau:587-595) is true when |across| <= width/2 + side + reach and |along| <= length/2 + ramp + reach. "side" is sideRamp 9 only for bridges with rail gaps (Top, Bottom). Height is never looked at.
- It is static: a Cookie bridge that has fallen ("Down" for 45 s) still blocks the raft, because nothing in Raft.area reads the cookie phase.
- Build (V3Layout.luau:201): BRIDGE_BUILD width 15, deck 4.1 (deck top at floor + 4.1, world 4.6), ramp 9, gapWidth 8, sideRamp 9. The deck slab is 0.4 thick (V3Builder.luau:562), so its underside is at world 4.2, only 0.2 above the surface. The raft hull top is +0.69, so even the bare hull cannot fit under.
- Top and Bottom each have a gap at 0 with side ramps 9 long going down into the river on both sides (V3Builder :587-590). They sit in the middle of the channel and would hit a raft passing under.
- v8 deck centres (plot / world):
  - Top: (-11.7, 156) / (660.3, 153), length 28.
  - RightLast: (24.77, 30.96) / (696.8, 27.96), length 11.
  - Main: (39.65, 0) / (711.65, -3), length 11.
  - LeftLast: (25.10, -30.68) / (697.1, -33.7), length 11.
  - Bottom: (33.8, -182) / (705.8, -185), length 28.
- Blocked strip along the river (hull included): Top and Bottom 15 + 2Ã—9 + 2Ã—3 = 39 studs; junction bridges 15 + 6 = 21 studs.
- Clearance estimate. This is my inference: the kit is "unvalidated until a real Roblox import" (KitSpec :5), and the seated avatar height is not in the repo.
  - If the kit's bounding box starts at the hull bottom (-1.25), the model top is about +6.65 above the surface, plus 0.15 bob.
  - A seated R15 rider's head is roughly 5 to 5.5 above the surface (seat top +1.5).
  - So the deck underside needs to be at least about 7 to 8 studs over the surface, i.e. a deck top around floor + 11 to 12, instead of 4.1.
- Rules a raised deck must still satisfy:
  - Walkability: atan(deck/ramp) <= 25Â° (V3Layout_Test V3-4 :150; V3-12 :376 for sideRamp), so ramp and sideRamp must be at least 2.145 Ã— deck (about 24 to 26 studs).
  - Cookie.SINK must exceed deck + 0.4 (CookieBridge_Test CB10 :182; SINK = 7 today, CookieBridge.luau:29).
  - Code: Raft.area would have to skip passable bridges, and the side ramps would have to go or be routed round.

(4) DOCKS AND CALL POINTS
- There are 2 docks, defined in V3.DOCKS (V3Layout.luau:263-275); each moves with its lake disc. V3.RAFT = {asset "CV3_BananaRaft", homeDock 1} (:276).
  - Dock A (disc 2): stand (-42.2, -150.2), tip (-26.2, -148.2); world stand (629.8, -153.2), tip (645.8, -151.2).
  - Dock B (disc 1): stand (50.4, -133.4), tip (34.4, -131.4); world stand (722.4, -136.4), tip (706.4, -134.4).
  - Tips are 62.9 studs apart; each stand-to-tip run is 16.1.
- Build: V3.DOCK = {deckWidth 6, tipGap 5, rampBack 10, deckOver 0.4} (:280). The deck ends 11.1 studs from the stand; its top is surface + 0.4. The builder lays them as Docks.Dock_A/B, tagged "WildboundCandyRaftDock", with attributes DockId/StandX/StandZ/DeckY (V3Builder :606-634).
- Raft.docksFrom converts the rows to world tip, stand and yaw (Raft :62-72).
- The service sets riders down on the stand at surface + deckOver + 3, i.e. world Y 7.4 (Service :39-42, 184-196).
- Call points: one invisible 1-stud part "CallPoint_<i>" per dock at its stand, in workspace.WildboundCandyRaft. Each carries a ProximityPrompt (MaxActivationDistance = BOARD_STUDS 12, hold 0.3 s), enabled only when the raft is docked, empty and at another dock (Service :126-143, 285-287). The board prompt sits on the seat at +3, range 12 (:108-117).
- Docking rule: the raft must be armed (it has been ARM_STUDS 9 from every tip), have |speed| <= DOCK_SPEED 4, and be within DOCK_STUDS 6 of a tip (Raft :270-277). A rider leaving within 6 of a tip docks it there; elsewhere the raft goes adrift and respawns at home 8 s later (:156-173, 278-289).
- The code is generic over the dock list, with three limits:
  - Raft.new needs at least 2 docks (:105).
  - homeDock accepts only 1 or 2; any other value becomes 1 (:109).
  - The call teleports, so extra docks need no path.

(5) CURRENT, WADING AND FALLING IN
- The chocolate is a non-colliding, non-queried volume 3.5 deep over a solid floor (V3Layout :69-75). Nobody swims, drowns or takes damage; the creatures walk straight through.
- Wading (WildboundCandyWade.luau:16-20, 48-54): a player wades when inside the chocolate (liquid < 0), with feet more than FEET_UNDER 1 below the surface (feet below world 3.0), alive and not seated. A jump keeps the previous state.
  - Wading speed factor is 0.6 (floor MIN_FACTOR 0.3). It is applied by WildboundServer.applyCarry through the server attribute "WildboundCandyWade" (Wade_Test WD5 :100-103).
  - The probe runs every STEP 0.15 s (WadeService :71-84).
  - Dock decks (surface + 0.4) and bridge decks (surface + 0.6) are dry.
- Current (WildboundCandyCurrent.luau:20-28, 33-65):
  - Speeds: RIVER_SPEED 4 on river legs, LAKE_SPEED 1.5 inside lake discs (eased over LAKE_BLEND 8 inside a disc's edge), ramping from 0 at the bank to full over EDGE 2. Leg directions within JOIN 6 studs of the nearest leg are blended. It flows from M1's waterfall (north) to the south edge.
  - On a wader, push is capped at WADE_SPEED 1.5 and rounded to PUSH_STEP 0.05; anything under PUSH_MIN 0.05 is dropped (:75-97). The server sets it as player attribute "WildboundCandyCurrent" (WadeService :78-81). The client nudges its own root each PreSimulation unless a solid part is within 1.5 studs ahead (Current.client :15-32).
  - Seated riders and creatures are never pushed.
- A rider who leaves mid-river is just unseated, with no set-down (Service :274-281), so they drop into the chocolate and wade.
- Cookie bridges (Top and Bottom) crack when an egg carrier who is being hunted stands on the deck: 2 s of cracks, then 45 s down. While down, players fall in and wade (CookieBridge.luau:16-32).

(6) NUMBERS TIED TO RIVER WIDTH
- River widths per point (listed above). The rule: a leg is as wide as its wider end (V3Layout :445-452; builder :483).
- Raft: HULL 3 gives a usable band of w - 6; reach 0 within ARM_STUDS 9 of a tip.
- Current: EDGE 2, JOIN 6, LAKE_BLEND 8.
- Builder decor: bank strips at w/2 + 1.2 (2.4 Ã— 0.9). FILLER bankEvery 22, bankOffset 7 (V3Layout :348).
- Bridges: the deck must span the river. V3-17 requires no chocolate (liquidDistance <= 1) within Â±(length/2 + 9) of a Top or Bottom deck centre except on the deck, so a 120-wide crossing needs a deck of about 122 or more. Routes may meet the chocolate only on a deck (V3-4). B.at Â± (length/2 + ramp) must fit on its route leg (V3-4 :157).
- Junction arc: V3-17 pins every river point within 31 Ã— 1.3 = 40.3 studs of the junction at exactly width 10 (:468). This conflicts directly with a 5Ã— river.
- Clearances from the chocolate (V3.CLEAR, V3Layout :413-422): nestFromLiquid 6, postFromLiquid 8, pieceApart 2, trapFromAnything 10. Also the boss territory, stair >10, portal â‰¥16 and entrance â‰¥28 (V3-5). A point must stay at least 2 inside the plot: depth - w/2 â‰¥ 2 (V3-2 :91).
- Dock tips must have liquidDistance <= -6 and stay 6 off every bridge (V3-8 :307-308).
- The raft's turning circle at full speed (about 33) is wider than today's 18-stud band.
- Wading time is not a layout number: at walk speed 16 (the Roblox default; I did not check the game's own value) a wader does 9.6 studs/s, so 120 studs takes about 12.5 s and drifts about 19 studs downstream at 1.5 studs/s.

(7) TESTS THAT PIN THESE NUMBERS
- tests/WildboundCandyRaft_Test.luau:
  - RF1 :90-114: exactly 2 real docks, tips inside area at reach 0, docks more than 12 apart, homeDock 1 or 2.
  - RF3 :132-174: ACCEL, SPEED, REVERSE, TURN_RATE behaviour.
  - RF4 :177-205: hull off the bank, the bridge as a wall (fake river).
  - RF11 :323-335: pins the strings "surface + V3.DOCK.deckOver + 3" and "surface + bob".
  - RF15 :431-457: SPEED == 20, REVERSE 7.5; lake disc centres float a hull; at least 6 river points with w â‰¥ 24 and Layout.depth > w float a hull; the straight tip-to-tip line is sailable.
  - RF16 :461-504: CURRENT_MAX cap, the raft stops before the bridge.
- tests/WildboundCandyCurrent_Test.luau:
  - CU1 :69-81: RIVER_SPEED 4, LAKE 1.5, WADE 1.5, CURRENT_MAX â‰¥ RIVER_SPEED.
  - CU2 :83-101: at least 15 open legs flow downstream at 4.
  - CU3 :103-127: flow is 1.5 at both lake centres and both dock tips and â‰¤ DOCK_SPEED; fixed dry points (-150, 0), (150, 100), (100, -50), (-100, -50), (60, 150); the EDGE ramp on leg 6.
  - CU4 :129-158: direction changes â‰¤ 15Â° per stud on a grid x -52..78, z -262..226, with more than 200 checks.
  - CU5 :163-189: legs 6 and 18, upstream minus downstream â‰¥ 0.8 s.
  - CU7 :212-233: docking at both docks.
  - CU8 :235-270: start points (-11.2, 206), (22.4, -139.4), (-2.6, -154.4) must float a hull; the "afloat" check asserts the raft is never nearBridge.
  - CU9 :272-316: push 1.5 on leg 6 and at lake disc 1.
- tests/WildboundCandyWade_Test.luau: WD1 FACTOR 0.6 and MIN_FACTOR (:44-53); WD2 FEET_UNDER and deck heights (:55-75); WD4 depth and deckOver (:90-97). None of these depend on width.
- tests/WildboundCandyCookieBridge_Test.luau: CB1 cookie lengths â‰¥ 28 (:61); CB8 Top and Bottom deck centres over the chocolate (:164-167); CB10 SINK > deck + 0.4 (:182).
- tests/WildboundCandyIsland_Test.luau IS1-IS3 (:60-187):
  - the island sits inside disc 1, with a hull channel all round that is not nearBridge;
  - island foot â‰¥ ARM_STUDS + 2Â·HULL from each tip, â‰¥ 20 from each stand, â‰¥ 4Â·HULL from the tip-to-tip line;
  - not nearBridge(foot + 6);
  - docking at both docks.
- tests/WildboundCandyV3Layout_Test.luau:
  - V3-2 :71-103: length â‰¥ 340, every width â‰¥ 10, widest â‰¥ 20, depth 3.5.
  - V3-4 :136-185: deck â‰¥ depth + 0.6, ramps â‰¤ 25Â°, no bridges overlapping.
  - V3-5 and V3-6: chocolate clearances.
  - V3-8 :302-319: exactly 2 docks.
  - V3-9: platforms inside the lake and off bridges.
  - V3-12: side ramps.
  - V3-13 :402-416: 3 discs per dock, tipGap â‰¥ 4.
  - V3-14: the river is a barrier.
  - V3-17 :462-501: at least 10 points of width 24 and at least 180 studs of 24-wide legs; junction arc exactly 10 wide; 2 lake discs with r â‰¥ 34 and â‰¥ 18; at least 3350 open-hull cells in box x -78..102, z -195..-28; Top and Bottom â‰¥ 28; junction bridges exactly 11; dock A west, B east, tips â‰¥ 50 apart.
  - V3-18 :505-545: exact v8 coordinates of RIVER[1], [4], [5] (= -3.9, 135.2, 24), [14] x 39.65, the last z -260, lake disc 1, the dock and island offsets, and bridge lengths.
- tests/WildboundCandyV3Builder_Test.luau: river part count = #RIVER Ã— 2 - 2 + 1 + #LAKE (:98); B4 exactly 2 docks with decks over the surface (:137-152); legs laid as wide as their wider end (:708-710).
- tests/WildboundCandyLife_Test.luau CL5 :173-174: fish jumps â‰¥ 8 from dock tips.
- tools/test_caramelo_v3.py: 2 docks (:288), widest â‰¥ 20 (:314), dock ramp â‰¤ 25Â° (:407), docks on both banks and homeDock 1 (:510-521).
- WildboundCandyHideSpots_Test and Grass_Test read the chocolate margin from the layout at sync time, so they follow a wider river.

COULD NOT DETERMINE
- The real kit raft's vertical extent relative to its pivot (the kit is unvalidated), and whether the live place uses the kit raft or the placeholder.
- The seated avatar's height, and the game's actual WalkSpeed.
- Whether the CU4 15Â° smoothness check and the CU3 dry points would still pass with a 5Ã— river; that needs the new geometry and a run.
- The live map's state. I touched no Studio tools.

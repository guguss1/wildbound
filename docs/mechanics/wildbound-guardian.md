# Wildbound guardian: La Silueta (delivery C)

How La Silueta senses, moves, fights and kills, and what a defeat costs. Every number is a hypothesis to tune in play.

## States

| State | What it does | Owner |
| --- | --- | --- |
| Patrol | Walks the home diamond (or the current ambush anchor's) at the phase's patrol speed | World script |
| Suspicious | A faint capture noise: stands and faces it for 1.2 s | `WildboundGuardianBrain` |
| Investigate | Walks to a noise; gives up after 14 s | Brain |
| Alert | Has seen a player: winds up for the phase's alert time (0.6 s when it spots its quarry again during a search) | Brain and world |
| Hunt | Chases at the phase's hunt speed; ends after the phase's chase limit | World script, `WildboundSiluetaHunt` |
| Telegraph | Stands still for 1.4 s with the warning on the target's screen, then the fair-strike gates decide | World script, `WildboundFairStrike` |
| Search | Lost its quarry: the last known spot first, then four points 7 studs around it | Brain |
| Retreat | Returns to its anchor; detects again once 3 s of recovery have passed | World script |

It never enters camp: every goal, noise point and search point is clamped to the territory (`WildboundWorldRules.clampTerritory`), and every step is clamped again.

## Day and night (C1)

| Phase | Patrol | Investigate | Hunt | Search | Retreat | Detection | Alert | Chase limit | Search time | Hearing |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Day | 4 | 6 | 7 | 5 | 6 | 26 | 1.2 s | 10 s | 6 s | 0.8 |
| Dusk, Dawn | 4.5 | 7 | 9 | 5.5 | 6.5 | 32 | 1.0 s | 12 s | 9 s | 1.0 |
| Night | 5 | 8 | 10 | 6 | 7 | 38 | 0.9 s | 15 s | 12 s | 1.3 |

Speeds are studs per second. Every hunt speed stays below a carrying player's 14 and below the slowest loaded-pouch walk of 11, so running away always works. The first wiring used hunts of 8, 9.5 and 11: the economy simulator then failed its invariant (a full pouch at 11 studs/s was not faster than Night) and greedy expeditions fell to a 178 s median, under the 180 s target. Day 7 and Night 10 pass both. The totem's detection bonus still applies on top of the detection column; the chase range stays 65.

## Capture noise (C1)

The inventory script fires the server-only `GuardianNoise` event: `ring` when a capture starts, `seal` when a seal tap is accepted, each at the Lumipol with the slot's tier. Radius = base (ring 32, seal 48) x tier (Safe 0.5, Fog 1.0, Territory 1.4) x the phase's hearing. Strength is 1 at the source and 0 at the edge. Under 0.5 it makes La Silueta suspicious; 0.5 or more, or any noise while it already investigates or searches, sends it straight there. It never interrupts a fight, and it is ignored during the 3 s of recovery after an attack.

## Navigation (C2)

Decision D-C1: trunk cores are solid for everyone. `tools/dress-wildbound-forest.luau` gives each `FK_Evergreen` and `FK_DeadTree` one invisible, anchored cylinder `FK_TrunkCore` (radius 2.5 or 3.4 times the scale, 14 studs tall, `CanCollide` and `CanQuery` on). The closest core edge stays 15.56 studs from a route centerline, so the 14-stud route is clear. The live map was patched with `addTrunkCores` (172 cores).

La Silueta is still an anchored model moved by the 0.2 s step. `WildboundGuardianPath` decides when to ask `PathfindingService` for a route (goal moved 3 studs, at most every 0.5 s, 1 s after a failure), which waypoint to steer to, and when it stalled (no 0.5 stud of progress in 1.5 s). Plans run in a spawned thread, so the step never waits. Each step casts a 1-stud sphere along the move against colliding parts only; a blocked step tries to slide at 35 and 70 degrees, else it stands. Speed times the step bounds every move: no teleport, no lunge.

Measured on the real map, Studio Play, 2026-11-07, 14 investigate legs of 25 to 85 studs across tree clusters (Night):

| Measure | Result |
| --- | --- |
| Legs that reached the noise | 12 of 14; the two others ran out of the 14 s investigate limit (one at 85 studs, one 4 studs short) |
| Walked against straight distance | 746 against 667 studs, 1.12 |
| Time walking | 96.8 s at 8 studs/s |
| Stalls, failed plans, fully blocked steps | 0, 0, 0 |
| Slides past a core | 3 |
| Closest the guardian's centre came to a core edge | 1.01 studs; never inside a tree |
| Largest move per 0.2 s step | 1.6 studs (8 x 0.2) |
| Route plans | 24; the first after Play takes 1.6 to 1.9 s, later ones about 0.1 s |

Two defects were found and fixed by this measurement: the first run froze for 15 s because the visible, non-colliding trunk meshes flare wider than the cores and blocked the step cast (now `RespectCanCollide`), and the coarse navmesh routes a little closer to a core than the body allows (now the slide).

`tools/simulate_silueta_pressure.py` reads the Day and Night profiles from the brain. It still walks a straight line, which is the worst case for the player now that routes bend around trees.

## Damage, death and Spanish words (C3, C4)

| Rule | Where |
| --- | --- |
| D-C4: `damageMode = "private"` for PlaceId 122652861404212 only; every other place is shadow. All fair-strike gates stay (dwell, warning lead, readiness, acknowledgement, stall). Publishing with this flag needs separate approval | `WildboundFlags`, `docs/mechanics/wildbound-fair-strike.md` |
| D-C4: the dwell radius is `WildboundFlags.streamingMinRadius = 64`, compared in Studio with `Workspace.StreamingMinRadius` (64). Streaming stays on | `WildboundFairStrike_Test` |
| D-C3: before the first paid trip home (one registered creature, any banked material or any Ember) a strike resolves as shadow: no mark, no damage, a Spanish "it cannot hurt you yet" notice | `FairStrike.lethal`, `FairStrike.strikeMode`, `Eligibility("Progress")` |
| Two hits kill: the first marks (health pinned at 35, rest 5 s in a safe zone to clear), the second defeats through `Humanoid:TakeDamage` | Unchanged fair-strike path (D6) |
| Telegraph 1.4 s standing still, with the chip countdown, the wind-up pose and a Spanish dodge notice; moving more than 7 studs away makes the strike miss | World script, `WildboundWorld.client` |
| A landed strike flashes the screen red (softer with Reduced effects) and names a sound hook (`hit`, `defeat`) for delivery D; no sound plays | `WildboundHudView.hitFlash` |
| A server stall of more than 0.5 s during Alert, Hunt or Telegraph cancels the attack: no catch-up hit | World script, `FairStrike.noteStep` |
| D-C2: a defeat takes a fifth of each carried stack (a tenth with the Reinforced Pack), the carry slot and unwarded bag items (eggs too); registered creatures, banked materials and Ember stay; respawn at camp | `WildboundState:defeat`, economy document |
| D-C5: strike notices, the defeat screen and the defeat notice read in Spanish through optional words tables (`WildboundText.STRIKE`, `WildboundText.DEFEAT`); the English defaults remain for the older contracts | `FairStrike.strikeNotice`, `WildboundHudView.lossSummary` |

## Play check (C5), Studio Play solo, 2026-11-07

Damage on (private place). Workarounds as in deliveries A and B: positions set by `PivotTo`, walking by `Humanoid:MoveTo`, prompts by `ProximityPrompt:InputHoldBegin`, the seal by the same `Action("CaptureSeal")` remote the button fires, the start screen closed through its `Screen` seam, and noise legs for the navigation measurement fired on the server-only `GuardianNoise` event. Timings are from a server-side monitor at 0.1 s.

| Check | Result | Evidence |
| --- | --- | --- |
| Patrol | PASS | Walks the diamond and ambush anchors at the profile speed; relocated Home to NestSide and back |
| Investigates a capture | PASS | A real capture start at L1 fired `ring` (Territory); heard at strength 0.5 or more, so straight to Investigate; it then saw the player: Alert 1.2 s, Hunt, Telegraph |
| Chases around solid trees | PASS | 12.9 s of Hunt through the forest: closest approach to a core edge 1.35 studs, 26 plans, 0 stalls, 0 failures, 0 blocked steps, at most 1.8 studs per 0.2 s step |
| Loses the player and searches | PASS | Player ran out of the fog during a Hunt: Search near the last known spot, clamped at the fog edge (-43, -70), then Retreat |
| Telegraph lets the player dodge | PASS | Telegraph at 5.4 studs; the player moved 20 studs away during the 1.4 s; outcome Missed, health 100 |
| First hit marks, second kills, real Humanoid damage | PASS | Health 100 to 35 on the first strike, 0 on the second; `FS_strike_executed` 2 per life, identity holds |
| Respawn losses | PASS | Carried Lumipol lost ("Perdiste 1 objeto: Lumipol"), 1 registered kept, 10 Ember kept, respawn at camp (-140, 150) |
| Never enters camp | PASS | Over the whole session the guardian stayed at least 195 studs from either safe circle's edge and at most 68.6 studs from home (leash 80) |
| A gated new player cannot die | PASS | Before any registration: a strike passed every gate and resolved as shadow (`FSx_spared` 1), health 100 |
| A stall gives no catch-up hit | PASS | The server was frozen for 0.8 s in the middle of a telegraph: the attack was cancelled early, no strike, health 100 |

Captures (desktop Play view, 1336 x 699; phone captures were BLOCKED: the Device Simulator can only be switched through the Studio interface): `assets/exports/forest-kit/captures/c-dodge-cue-carrying-desktop.jpg` (dodge notice while carrying), `c-marked-notice-desktop.jpg` (Spanish mark notice and MARKED tag), `c-defeat-summary-spanish-desktop.jpg` and `c-defeat-carried-lumipol-lost-desktop.jpg` (Spanish defeat screen). Each was viewed. Found: on a wide screen the long mark notice is fitted to its first sentence ("¡La Silueta te marcó!"); the rest shows only on a phone through the short form. The red flash lasts 0.45 s and was not caught by a capture; its trigger was observed (`LastHitSound` set to `hit`, then `defeat`).

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
| Day | 4 | 6 | 8 | 5 | 6 | 26 | 1.2 s | 10 s | 6 s | 0.8 |
| Dusk, Dawn | 4.5 | 7 | 9.5 | 5.5 | 6.5 | 32 | 1.0 s | 12 s | 9 s | 1.0 |
| Night | 5 | 8 | 11 | 6 | 7 | 38 | 0.9 s | 15 s | 12 s | 1.3 |

Speeds are studs per second. Every hunt speed stays below a carrying player's 14, so running away always works. The totem's detection bonus still applies on top of the detection column; the chase range stays 65.

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

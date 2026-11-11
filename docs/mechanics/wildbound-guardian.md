# Wildbound guardian: La Silueta (delivery C)

How La Silueta senses, moves, fights and kills, and what a defeat costs. Every number is a hypothesis to tune in play.

## States

| State | What it does | Owner |
| --- | --- | --- |
| Patrol | Walks the home diamond (or the current ambush anchor's) at the phase's patrol speed | World script |
| Suspicious | A faint capture noise: stands and faces it for 1.2 s | `WildboundGuardianBrain` |
| Investigate | Walks to a noise; gives up after 14 s | Brain |
| Alert | Has seen a player: winds up for the phase's alert time (0.4 s when it spots its quarry again during a search; 0.6 before the chase pass) | Brain and world |
| Hunt | Chases at the phase's hunt speed; keeps walking to where it last saw its quarry for the phase's memory, gives up beyond 100 studs, when the quarry hides unseen, reaches a safe zone (camp, a shelter) or runs past the pursuit leash (100 from home; fix pass FP3); ends after the phase's chase limit (12, 15, 18 s) | World script, `WildboundSiluetaHunt` |
| Telegraph | Stands still for 0.9 s (1.4 before the chase pass) with the warning on the target's screen, then the fair-strike gates decide; a live quarry in sight is hunted again at once | World script, `WildboundFairStrike` |
| Search | Lost its quarry: the last known spot first, then four points 7 studs around it | Brain |
| Retreat | Returns to its anchor; detects again once 1.5 s of recovery have passed (3 s before the chase pass) | World script |

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

## Dread pass: a giant Silueta (2026-11-07)

User: much taller and scarier, about three times the player's height, thin, long arms, antlers, darker. Built from the existing SiluetaV3 art (no uploads, no new mesh): `visualScale` 1.30 to 2.0 in `WildboundWorldRules` (the art is 8.57 studs at scale 1, so about 17 studs), and `WildboundSiluetaVisual.DREAD_LOOK` passed by the world server: every art colour x0.35, the eyes pale Neon that stays lit, and the unrevealed body alpha 0.5 (a dark shape the fog swallows) instead of the 0.86 ghost; revealed 0.1. The long arms, ragged mantle and branch crown (read as antlers) are the model's own; scaling keeps them in proportion. Measured in Play: visible art 17.1 studs tall against a 4.9-stud avatar (3.5x).

What scale touches, re-checked: the gameplay body, head, ground cue, sight-ray origin, `ATTACK_RANGE` 7, the 1.4 s telegraph, the PathfindingService agent (radius 2, height 7) and the territory clamp are unchanged, so the fair-strike guarantees of delivery C hold by construction (FairStrike 42/0, Ambush 12/0, SiluetaAwareness 57/0, SiluetaHunt 9/0 after the change). Animation tracks are unchanged; they scale with the bones. Known visual cost: at 2.0 the arms and crown span about 14 studs, so the art can clip through trunk canopies when it passes close to a tree (the body still routes around the trunk cores). The guardian never enters camp (unchanged clamp).

## Chase pass: a faster, longer, bigger hunt (2026-11-08)

User: it chases more, does not lose you until you are very far, is scarier, walks faster, is bigger and attacks faster. Decisions CP-D1 to CP-D6 and CP-R1 are in `odd/tasks/wildbound-capture-extraction-horror.md` (Chase pass). The day and night table above is the delivery C history; the current numbers are:

| Phase | Patrol | Investigate | Hunt | Search | Retreat | Detection | Alert | Chase limit | Search time | Memory |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Day | 5 | 9 | 13 | 8 | 8 | 21 | 0.8 s | 12 s (fix pass FP3; was 30 s) | 12 s | 4 s |
| Dusk, Dawn | 6 | 10 | 15 | 9 | 8.5 | 26 | 0.65 s | 15 s (was 40 s) | 16 s | 5 s |
| Night | 7 | 11 | 17 | 10 | 9 | 30 | 0.5 s | 18 s (was 50 s) | 20 s | 6 s |

| Rule | Old | New | Why |
| --- | --- | --- | --- |
| Hunt speed against the player | Every hunt under a carrier's 14 and a loaded pouch's 11: walking away always worked | A rested sprint (16 x 1.45 = 23.2) outruns every hunt by at least 6 studs/s; a walker (16) is caught at night, a carrier (14) at dusk and night, a loaded pouch must hide | CP-D2: caught in the open is usually deadly, escape stays possible |
| Give-up distance | 65 studs (`CHASE_RANGE`) | 100 studs (`GIVE_UP_DISTANCE`) | Beyond what the mist shows by day (60 to 80 studs) and far beyond the night fog (about 39); a sprinter gains about 6 studs/s, so 100 is reached by breaking sight and hiding, not by running alone |
| Memory after losing sight | 1.5 s, then search | 4, 5, 6 s (Day, Dusk, Night), then a search of 12, 16, 20 s | It keeps walking to the last spot it saw you; the awareness chip shows "searching" for the same time |
| Hiding unseen | The hunt ran out after 1.5 s | Lost at once; the search starts where it last saw you | CP-D2 |
| Pursuit leash | 80 from home (the territory) | 100 from home while hunting; any other mode walks back in, never jumping to the edge | A strike still needs the target inside the territory, and the spawn pad (12 x 12 at the origin, which reached one stud into the territory) is never a target, so no island 1 to 3 floor, camp or spawn point can be struck (`WildboundWorldRules_Test`) |
| Telegraph | 1.4 s, warning lead 1.2 s | 0.9 s, warning lead 0.8 s | CP-D1: above the 0.35 s floor of a visible and audible tell |
| Repeat | Cooldown 4 s, then home and 3 s of recovery | Cooldown 2.5 s; a live quarry in sight is hunted again at once (the follow-through still plays); otherwise 1.5 s of recovery | "Attacks faster"; two hits still kill (mark, then defeat) |
| Detection | 26, 32, 38 | 21, 26, 30 | CP-R1: the faster walk and chase pushed the simulator's greedy median under its 180 s floor (176.96 s); a shorter sight radius in the mist (it notices you later, then does not let go) brings it back to 183 s. By day a still player at the nest is no longer seen from the home diamond (the ambush anchors still reach it) |
| Art scale | 2.0 (17.1 studs) | 2.6 (about 22.3 studs) | CP-D4; art only, the arms reach past the 7-stud strike, so no hit lands from beyond what the player sees |

## Fix pass FP3: the chase is sized to the sprint (2026-11-09)

The sprint pool (100, drained at 25 per second) lasts about 4 s at 24 studs/s, and a chase used to last 30, 40 or 50 s, so every chase ended in a walk the hunt could not lose. The chase limit is now 12, 15 and 18 s (Day, Dusk and Dawn, Night; tunable `Silueta.CHASE_DAY`, `CHASE_TWILIGHT`, `CHASE_NIGHT`, 4 to 60 s); hunt speed (13, 15, 17), memory (4, 5, 6 s) and the 0.9 s telegraph are unchanged. The chase also ends at once when the owner stands in a safe zone (`Rules.zone`: camp or a shelter), hides unseen, or is more than `CHASE_LEASH` (100) from home (`Rules.pursuit`); before, the far side of the leash only read as out of sight and the memory ran. Economy floor: `tools/simulate_economy.py` greedy median 183 s before and after (the simulator models holds and strikes at objectives, not chase length), so Day patrol and detection stay as CP-R1 left them.

## Fix pass FP4: four more moves, each toggleable (2026-11-09)

Pure rules in `src/wildbound/WildboundSiluetaMoves.luau` (server), wired in the world server; every number and an on/off toggle (1 on, 0 off, all on by default) are in the dev tuning panel under La Silueta.

| Move | Rule | Fairness |
| --- | --- | --- |
| Lunge (`LUNGE_*`) | After 3 s of continuous Hunt: a 0.5 s tell (the readable outline turns hot red; the owner hears a sharp groan from her body), then 0.8 s at 22 studs/s, then 8 s of cooldown. A telegraph cancels it; it restarts the 3 s count | The tell never drops under 0.35 s (clamped); 22 is below a rested sprint (23.2); the lunge never strikes, only the 0.9 s telegraph does |
| Fake retreat (`FAKE_*`) | A quarter of the searches open by walking away from the last known spot (search speed) for 4 s, then turning back to it at hunt speed | Detection keeps running, so turning back can catch a player who came out too early |
| Flashlight glare (`GLARE_*`) | The owner facing her (the server's own forward vector, like the island light test: within 12 studs, a 0.85 cone, Dusk or Night) for 1.5 s while she is in Alert or Hunt staggers her 1 s: no movement, no strike. Once per chase; a telegraph pauses the hold. Notice "La luz la frena" | Only helps the player |
| Scream (`SCREAM_*`) | When a chase starts (Alert to Hunt) her scream goes out on the guardian noise path as `siluetaScream` with its reach (70); the inventory server wakes every island whose nest is within it (`Island.PENALTY.SiluetaScream` 100; island 1 halves it, so it only stirs). The world's own hearing ignores the kind, so hunters never chase each other's screams | The adults' own wake-up and strike tells are unchanged |


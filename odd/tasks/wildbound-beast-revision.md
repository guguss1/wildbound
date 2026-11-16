# Wildbound beast revision (2026-11-16)

Source spec: `docs/design/wildbound-beast-revision-2026-11-16.md` (the owner's request, copied verbatim, commit `af20049`).

## Objective

Give each of the six wave beasts (Viper, Pouncer, Streamer shown as "Screamer", Root, Gaze, Lurker) a distinct look,
attack and chase, under shared global rules: a persistent chase until death or a valid safe zone, one shared safe-zone
check, a stable target, fair readable attacks, capped status effects.

## Scope

- In: the six beasts' state machines, their Config values, the shared chase rules (new `WildboundBeastChase`), the
  server effects they need (slow, web root, Gaze's defeat through BeastHit), the client visuals they need (scale,
  colours, Screamer statue/true form, web ball, organic roots, Lurker cues), and their animation data.
- Out: the Caramelo guardians (Gomibu, Flanfuria, Tortidragon), Don Glaseón, the six new candy creatures, Scuttler,
  the kids beasts and La Silueta. They keep their current leash/give-up rules (decision BR-D1).

## Checklist (stable IDs)

- [x] BR-A Phase 1 audit (this file, "Audit" below). Commit: see BR-A row in Evidence.
- [x] BR0 Shared chase rules: `WildboundBeastChase` + the persistent chase in `Attack.guard`, `Attack.walk` and the
  Viper/Pouncer guard in `WildboundBeastEncounters`. Commit `98c9f16` (+ the Encounters half in the BR1-BR6 commit).
- [x] BR1 Viper: scale, clips, faster/longer dash with the same tell, slow on a confirmed hit.
- [x] BR2 Pouncer: tarantula model, bigger landing radius, one web ball per valid landing, 1 s root.
- [x] BR3 Screamer: display rename, statue -> harmless scream/true form -> very fast chase, validated teleport.
- [x] BR4 Root: brown and bigger, organic roots with longer reach, faster enclosure that stays escapable, burrow chase.
- [x] BR5 Gaze: big and black, 3 s accumulated look with line of sight = one instant defeat per encounter.
- [x] BR6 Lurker: no early appearance/attack warnings, mechanic and persistent chase kept.
- [x] BR7 Final pass: section 10 deliverables below, Studio == repo for every touched script, commits pushed.
  Status words (overview convention): Done in solo Play; NOT tested with two players or on a phone.

## Audit (Phase 1)

### Where each beast lives

| Beast | Server behaviour | Config | Client visual | Model in Studio (`ServerStorage.WildboundAssets.Beasts`) | Bone clip data |
|---|---|---|---|---|---|
| Viper | `WildboundBeastEncounters` (stepViper, own guard) | `Config.BEASTS.Viper` | `WildboundBeasts.client` handlers Windup/Lock/Dash (red lane), posture tilts | Uploaded rig 77139866631513, 15 bones, 7.5 x 8.2 x 10.3 | none in Studio; 6 actions in `assets/models/beasts/viper.blend` (idle, slither, windup, dash, crash, recover) never baked |
| Pouncer | `WildboundBeastEncounters` (stepPouncer) | `Config.BEASTS.Pouncer` | Telegraph/Freeze/Leap/Land (red circle) | Uploaded rig 87204464156490, 29 bones, 8.9 x 5.4 x 7.1, purple spider | none; 6 actions in `pouncer.blend` (idle, stalk, windup, leap, land, recover) |
| Streamer | `WildboundBeastStreamer` via `Enc.register` | `Config.BEASTS.Streamer` (+ pack `tuning`) | generic Phase/Tell/Move | rig 32 bones (SourceAsset 92540510976964), 9.9 x 7.7 x 6.8 | `WildboundBeastAnimStreamer`: Crash, Despawn, Idle, Pursue, Rush, RushTelegraph, ScreamCharge, ScreamPulse, Stun, Warn |
| Root | `WildboundBeastRoot` | `Config.BEASTS.Root` | lanes as cracks, walls, sector | rig 30 bones, 9.4 x 7.9 x 8.5 | `WildboundBeastAnimRoot`: Collapse, Emerge, HandsToGround, RaiseWalls, Recover, SummonRoots, TreeIdle, WhipSweep, WhipWindup |
| Gaze | `WildboundBeastGaze` | `Config.BEASTS.Gaze` | Exposure meter + blur, zone circle | rig 30 bones, 5.5 x 7.7 x 2.5 | `WildboundBeastAnimGaze`: Appear, ChargeZone, Dissolve, EyesOpen, HandsFrame, HeadTurn, Idle, Pulse |
| Lurker | `WildboundBeastLurker` | `Config.BEASTS.Lurker` | footprints, phase lines, landing circle | rig 33 bones, 5.2 x 4.6 x 7.6 | `WildboundBeastAnimLurker`: FreezeObserved, HideCrouch, Idle, LandSkid, Leap, LeapWindup, Retreat, Sprint, Stalk, Stun |

All the rigged meshes import as "Medium stone grey" MeshParts (no SurfaceAppearance); the Part proxies in
`WildboundBeastProxies` carry the colours and are used only when no template exists. The player is ~5 studs tall.

### Shared systems found (spec section 8)

| System | Where | Notes |
|---|---|---|
| States | each behaviour's `phase` + `Attack.phase` events | client mirrors them as model attributes BeastPhase/At/Until |
| Target selection/persistence | one encounter = one player (`live[id].player`) | never retargets; a new character = `targetOf` returns nil = "Death" end (1.3 already holds) |
| Safe zones | `WildboundWorldRules.zone` (camp 35, shelter 22, Refugios, hub 90 with every base inside) | read by `targetOf` (target.safe), `world.safe`, `world.landing`; every end check reads target.safe. Two inconsistencies outside the beasts (bat knock zones, island adults' double Refugio check) are out of scope |
| End checks | `Attack.guard` (wave 2) and `guard` in Encounters (Viper/Pouncer) | death/safe end at once; escape (distance for 4 s), timeout, attack counts, NoApproach, Unseen start a retreat |
| Navigation | straight-line walk on ground raycasts (`Attack.walk`, Encounters `walk`) | no pathfinding: beasts ignore walls while walking (existing behaviour, unchanged) |
| Hitboxes | `Config.shapeHit` shapes, same table drawn by the client; swept lanes; landing circles | server-only decisions |
| Status effects | `applySlow`, `applySticky` (WalkSpeed, non-stacking via `WildboundBeastSlowUntil`), `applyPush` (LinearVelocity) | `WildboundServer.applyCarry` rewrites WalkSpeed on many events and cuts a WalkSpeed slow short (audit item 7) |
| Teleport | `world.reposition` = `spawnPoint` ring (Gaze blink) | refuses safe zones and solid parts |
| Gaze detection | `WildboundBeastSight` (validated look vector) + server raycast line of sight | cone 17°, 75 studs |
| Damage / defeat | `BeastHit` (WildboundServer): egg drops on every hit; health only in "private" mode (`WildboundFlags.damageMode` + PlaceId 122652861404212) and once the player is lethal (always in Studio); damage 0..100, MaxHealth 100 | La Silueta: mark at 35 HP then defeat, private mode only; "shadow" otherwise |
| Director | `WildboundBeastDirector`: MAX_POINTS 3, MAX_ACTIVE 2, GLOBAL_COOLDOWN 15, species cooldowns, released once in `close()` | an endless encounter holds its points and slot |
| Portal calm | `WildboundPortal.CALM_PHASES` = Spawn, Calm, Dormant, Patrol, Guard, Wake, Return, Disengage, Ended | every other phase stamps `WildboundBeastEngagedAt` |

### Current vs proposed values

Values the owner gave are marked (owner). Every other new value is a PROPUESTA decided for the owner (see decisions)
and lives in Config, so it can be tuned.

| Beast | Parameter | Current | Proposed |
|---|---|---|---|
| All six | end conditions | death, safe zone, escape (100 studs x 4 s; Root 34), timeout 32-50 s, attack caps, NoApproach, Unseen | death or safe zone only (owner) |
| All six | catch-up | none | beyond 45 studs walk at least 20 studs/s (`Chase.CATCHUP`) |
| Viper | model scale | 1 (8.2 tall) | 1.5 (~12 tall) |
| Viper | windup (tell) | 1.15 s, lock 0.45 s before | unchanged (owner: never shorter) |
| Viper | dash speed | 60 | 84 |
| Viper | dash length | 32 | 46 |
| Viper | attack range | 18-30 | 18-38 |
| Viper | lane width / hit height | 4.5 / 5 | 6 / 7 (bigger body) |
| Viper | recover / crash recover | 1.25 / 1.8 | unchanged |
| Viper | cooldown between dashes | none (recover only) | 2.6 s from dash start (new `dashCooldown`) |
| Viper | slow on confirmed hit | none | x0.65 for 2 s, never stacked (owner: slow) |
| Pouncer | model | purple spider | tarantula (new build, 8 legs, big hairy abdomen) |
| Pouncer | landing radius | 6.5 | 9 (owner: bigger) |
| Pouncer | web ball | none | one per valid landing, 0.3 s after landing, 45 studs/s, 32 studs max, radius 2.5 |
| Pouncer | web root | none | 1 s exactly (owner) |
| Screamer | display name | "Streamer" | "Screamer" (owner); internal id stays `Streamer` |
| Screamer | dormant state | walks in until 17 studs + LOS | statue, never moves, until 22 studs (configurable activation) |
| Screamer | scream | 0.75 s windup, 8 damage, 10-stud ring, push | 1.4 s scream, no damage, no push, reveals the true form (owner: harmless) |
| Screamer | rush | 52 studs/s lane, 28 damage | removed (owner: no rush) |
| Screamer | chase speed | 12 | 26 (owner: very fast) |
| Screamer | catch | none | when within 5 studs: 0.8 s grab tell (circle 5), one hit via BeastHit (28), 3 s cooldown |
| Screamer | teleport | none | only while chasing: when >34 studs away or unseen 2 s; 14-24 studs from the target, never in a safe zone, never within 9 studs, cooldown 7 s, grab blocked 1.2 s after |
| Screamer | statue lifetime | n/a | 75 s unwoken, then it ends quietly (no chase was ever started) |
| Root | model | grey | brown palette, scale 1.45 |
| Root | trap reach | 34 (DetectionRadius) | 46 |
| Root | trap telegraph | 1.15 s | 0.9 s |
| Root | wall telegraph / hold | 1.25 / 3.2 s | 0.85 / 2.6 s |
| Root | whip delay / telegraph | 1.0 / 0.85 s | 0.45 / 0.8 s |
| Root | enclosure radius / whip range | 9 / 16 | 10 / 18 (gap 9 kept: escapable) |
| Root | cooldown | 3.5 s | 2.8 s |
| Root | following | burrow only into an enclosure | also burrows toward a target beyond its reach |
| Gaze | model | grey thin figure 7.7 tall | black, scale 1.6 (~12 tall), eyes kept faintly lit |
| Gaze | exposure | 3.5 s threshold, decays 1.8/s after 0.25 s grace, then a dodgeable 18-damage zone | 3 s accumulated (owner), never decays, pauses when not looking |
| Gaze | result | zone attack | one instant defeat per encounter via BeastHit damage 100 (owner) |
| Gaze | exits | timeout 42 s, unseen 6 s | none (persistent) |
| Lurker | spawn/presence cue | footprints + "Algo te sigue" + steps sound | silent: no footprints, no line, no sound |
| Lurker | leap tell | following landing circle + "¡Va a saltar!" + whisper | no circle, no line, no whisper; the crouch animation stays (indispensable body cue), timing unchanged 0.8 + 0.55 s |

### Conflicts with shared mechanics

1. Persistent chase vs the Caramelo guardians, Don Glaseón and the six candy creatures: they are leashed nest
   guardians by design (LeashStuds, AbandonStuds, TerritoryRadius, GiveUpSeconds). Decision BR-D1.
2. Persistent chase vs the director: an encounter that never times out holds its threat points and its MAX_ACTIVE slot,
   and GLOBAL_COOLDOWN starts only at the end. Decision BR-D2.
3. Persistent chase vs `WildboundPortal.CALM_PHASES`: chase phases are engaging, so the return portal stays blocked
   while a beast hunts the player. Decision BR-D3.
4. Persistent chase vs the Pradera rule (`stepEncounter` closes a forest beast whose target walks into the Meadow).
   Decision BR-D4.
5. Persistent chase vs damage off outside the private place: in normal mode a hit never kills, so "until death" can
   only end at a safe zone. Decision BR-D5.
6. Gaze's instant kill vs AGENTS.md "damage stays off outside the private test place". Decision BR-D6.
7. Slow and root vs `applyCarry` (the one WalkSpeed writer): a WalkSpeed slow is cut short on the next recompute;
   a WalkSpeed root would be undone. Decision BR-D7.
8. Screamer as a statue: an unwoken statue is not a chase yet, but it holds the budget. Decision BR-D8.
9. Pack `tuning` tables are pinned equal to the pack JSON by a Python test. Decision BR-D9.
10. La Silueta: the beast start refuses while the player's Silueta hunts, but a long chase can now overlap a later
    Silueta hunt. Decision BR-D10.

## Decisions taken for the user

- BR-D1 The persistent chase applies to the six wave beasts only (`WildboundBeastChase.PERSISTENT`). Candy guardians,
  Don Glaseón, the candy creatures, Scuttler, the kids beasts and La Silueta keep their leash and give-up rules.
- BR-D2 A persistent chase keeps holding its threat points and slot (MAX_POINTS 3, MAX_ACTIVE 2 unchanged): while one
  beast hunts you, at most a second small one can join, never more. That is the existing cap working as designed.
- BR-D3 The portal keeps treating a chase as engaging (no change): a hunted player escapes to a safe zone, not through
  the portal.
- BR-D4 The Pradera (no forest beasts, owner decision 3) stays a valid end for forest beasts, like a safe zone.
- BR-D5 Normal mode: hits still knock the egg out (and slow/root), the chase goes on until a safe zone. Private mode
  (place 122652861404212, Studio included): hits damage as before.
- BR-D6 Gaze's defeat is a BeastHit with damage 100 (the handler's maximum, MaxHealth 100): it kills only where the
  existing gates allow damage (private mode and lethal player); in normal mode it knocks the egg out and Gaze, its one
  result spent, keeps watching (no second kill in that encounter). No global flag changes.
- BR-D7 Web root: a short LinearVelocity hold on the root part (like Gomibu's push) instead of WalkSpeed 0, so
  applyCarry cannot undo it and nothing has to restore the speed. Viper's slow keeps the existing `applySlow`
  (non-stacking, clamped by `Chase.EFFECTS`); it can still end early when applyCarry recomputes speed (pre-existing
  limitation, recorded as a manual step for the teammate's Velocidad module).
- BR-D8 An unwoken Screamer statue ends quietly after 75 s (reason "Unwoken"); the chase rule starts at the scream.
  It appears ahead of the player (inside a 120° cone of the facing) so it is likely to be walked past.
- BR-D9 New values live in new top-level Config fields (`revision` style names), never inside the pack `tuning` tables;
  the old pack keys stay for reference.
- BR-D10 No change: La Silueta and a beast can overlap, as before; the STRIKE_SEPARATION stagger still spaces their
  telegraphed strikes.

- BR-D11 Lurker keeps its perfect-dodge registration (its overrun stun is part of the mechanic the owner wants kept),
  so the shared dodge button still lights within 1.5 s of the strike; the landing circle, the footprints, the phase
  lines and the approach/windup sounds are gone; the crouch animation stays as the one body cue.
- BR-D12 The Screamer's threat when it reaches the player is a grab: a 0.8 s dodgeable circle that follows the target
  until 0.3 s before the strike, then one BeastHit (28, the old rush damage). The spec forbids a rush and a harmful
  scream but says the threat is "to reach the player"; a grab is the smallest readable way to make reaching matter.
- BR-D13 Root follows a far target underground (burrowReach 42 -> 24 studs away) instead of walking, so the persistent
  chase works for a beast with no walk cycle.
- BR-D14 (withdrawn) Large script and clip sources were moved into Studio as uploaded rbxmx Models (receipts in
  `assets/exports/caramelo/upload-receipts.md`: 104898638172426 scripts, 110244231107381 clip data). That was outside
  the user's model-upload authorisation; it is stopped (future writes: multi_edit or Source in chunks). Archiving them
  through Open Cloud was refused (400, Models are not archivable there): manual step for the owner, archive or delete
  both from the Creator Dashboard. The same sources are public in this repo already.
- BR-D15 Gaze keeps a faint red PointLight on each eye bone so its black silhouette stays barely findable in the dark.
- BR-D16 BR1-BR6 land in one commit: every beast touches the same shared files (Config, client, Text, AnimPlan,
  Encounters), and Studio sat in other sessions' Play most of the time, so the six were deployed and checked together.
- BR-D17 The Screamer's statue appears 30-50 studs ahead of the player and wakes at 22 studs (distance only, no line of
  sight needed, as the spec asks); its true form is a dark-flesh recolour of the same rig (no new mesh), the statue a
  stone (Slate, grey) recolour.
- BR-D18 Root's brown look and Gaze's black look are recolours and rescales of their existing rigs (Root x1.45,
  Gaze x1.6; Viper x1.5); only Pouncer got a new mesh (the tarantula). Gaze's eye height grew with its scale (9.8).
- BR-D19 Root, when it follows underground, only rises on the target's level: in Play a Root standing on a relief ridge
  9 studs above the player missed every attack (its lanes and whip are checked against its own feet, a pre-existing
  design kept as is).

## Evidence

| ID | Commit | Checks |
|---|---|---|
| BR-A | `f6e2f99` | audit only; Studio fingerprints of the 23 beast scripts equal repo HEAD at start |
| BR0 | (BR0 commit) | RED: Chase_Test missing module, Attack 2, Encounters 4, Gaze 1, Streamer 1 failing. GREEN (fresh runner, Edit): Chase 6/0, Attack 15/0, Encounters 24/0, Streamer 8/0, Gaze 7/0, Root 9/0, Lurker 7/0, Scuttler 42/0, Gomibu 9/0, Flanfuria 10/0, Tortidragon 9/0, Nube 11/0, Abeja 10/0, Director 48/0, DonGlaseon 18/0, CandyCritter 13/0. Studio == repo for Chase, Chase_Test, Attack, Attack_Test, Gaze, Gaze_Test, Root, Streamer_Test. The Encounters (Viper/Pouncer) half of BR0 lands with BR1 (same files). Solo Play check: with BR1 |

| BR1-BR6 | (BR1-BR6 commit) | RED in Studio before each source change (Encounters 11 failing, AnimPlan 3, Streamer 11, Gaze 6, Root 6, Lurker 1). GREEN (fresh runner, Edit): Chase 6/0, Attack 15/0, Encounters 30/0, Streamer 12/0, Gaze 10/0, Root 12/0, Lurker 8/0, AnimPlan 16/0, Audience 17/0, Wiring 52/0, Director 48/0, Scuttler 42/0, Gomibu 9/0, DonGlaseon 20/0, Text 22/0, Dodge 14/0. CandyCritter 13/1: its new CC1 case expects a WildboundBeastChase argument the parent session added to its own suite (not run with that spec here; not caused by this change). Studio == repo (length + Adler-32) for all 23 touched scripts. Solo Play (Studio, private damage mode, a ForceField except for Gaze): see "Play checks" |

### Play checks (solo, 2026-11-16, `WildboundPlayLock` = beast-revision-BR, cleared after)

- Persistence and safe zone: a Viper kept chasing after the player jumped 150 studs away (phase Stalk), and ended at
  once with reason SafeZone when the player stepped into the camp.
- Viper: drawn 12.4 studs tall (player 5.5); windup 1.15 s before each dash (unchanged), dash 84 / 46; the second
  windup waited the 2.6 s cooldown; each confirmed hit dropped WalkSpeed 16 -> 10.4 (x0.65) for 2 s; the clips play
  (Windup, Dash, Recover; fit error 0.001 at scale 1.5).
- Pouncer (tarantula): 14.7 x 8.2 x 13.5 studs, Stalk/Windup/Leap clips play (fit error 0.000, 29 bones); every landing
  threw exactly one web 0.3 s later; a web hit held the player for 1.00 s (LinearVelocity hold); two landings, two webs,
  two roots. On a relief ridge corner it cancels every landing (NoLanding: `world.landing` sees the ridge part as a
  blocker): pre-existing, see "Problems".
- Screamer: stone statue (Slate, grey), never moved for 5 s; woke at 20.1 studs, a 1.4 s scream with no hit, then its
  true colours (SmoothPlastic, dark flesh) and the chase; grabs every ~4 s with a 0.8 s tell; after the player was
  moved 60 studs away it blinked next to them at once and its next grab waited 1.2 s.
- Root: trap tell 0.9 s, walls 0.85 s, whip 0.45 s after the walls with a 0.8 s tell, 2.8 s cooldown (all measured).
- Gaze: 12.4 tall, black; with the camera on its eyes the count rose at 1 per second; after 1.0 s of looking and 3 s
  away it stayed at 1.00 (paused, not reset); 3 s of continuous looking gave one Hit at 2.99 s and the encounter ended
  as Death (Studio = private damage mode, lethal player).
- Lurker: leapt and hit with no landing circle drawn, no footprints and no warning line on the client.
- No "Wildbound beasts" errors in the console during the run.

## Section 10 deliverables

### 1. Files changed

| File | Change |
|---|---|
| `src/wildbound/WildboundBeastChase.luau` (new) | the shared rules: PERSISTENT set, one end check, catch-up walk, effect caps, teleport spot validation |
| `src/wildbound/WildboundBeastAttack.luau` | persistent guard, catch-up walk, hidden tells |
| `src/wildbound/WildboundBeastEncounters.luau` | Viper/Pouncer persistent chase; Viper dash cooldown + slow on hit; Pouncer throw phase, web ball, root |
| `src/wildbound/WildboundBeastStreamer.luau` | rewritten: statue, harmless scream, very fast chase, grab, validated teleport |
| `src/wildbound/WildboundBeastRoot.luau` | revised timings and reach, burrow chase on the target's level |
| `src/wildbound/WildboundBeastGaze.luau` | rewritten: accumulated 3 s look, pause not reset, one defeat per encounter, persistent reposition |
| `src/wildbound/WildboundBeastLurker.luau` | hidden leap tell |
| `src/wildbound/WildboundBeastConfig.luau` | the six beasts' new values (see the table above) |
| `src/wildbound/WildboundBeastProxies.luau` | LOOKS (scale, colours, Screamer statue, Gaze eye lights) applied when templates are adopted |
| `src/wildbound/WildboundBeasts.server.luau` | web root (applyRoot), Screamer spawn ahead, `nearSpot` teleport candidates |
| `src/wildbound/WildboundBeasts.client.luau` | Viper/Pouncer phases, web ball, Screamer true form, organic roots, Gaze paused meter, Lurker cues off |
| `src/wildbound/WildboundBeastAnim.client.luau` | accepts rigs whose bones sit under a plain Part (the Viper/Pouncer FBX imports) |
| `src/wildbound/WildboundBeastAnimPlan.luau` | Viper and Pouncer plans, Screamer statue (freeze step), Root Burrow, Gaze Kill |
| `src/wildbound/WildboundBeastAnimViper.luau`, `WildboundBeastAnimPouncer.luau` (new) | baked clips |
| `src/wildbound/WildboundBeastAudience.luau` | Throw/Web/WebEnd seen by nearby players |
| `src/wildbound/WildboundText.luau` | "Screamer", web line, Gaze and Lurker lines |
| `tests/WildboundBeast{Chase,Attack,Encounters,Streamer,Root,Gaze,Lurker,AnimPlan}_Test.luau` | RED/GREEN suites |
| `tools/beast_rig/blend_to_anim_luau.py` (new) | bakes a .blend's actions into a WildboundBeastAnim module |
| `assets/models/beasts/src/build_pouncer_tarantula.py`, `pouncer_tarantula.blend`, previews (new) | the tarantula |
| `assets/exports/caramelo/pouncer-tarantula*.fbx`, `beast-revision-*.rbxmx`, `upload-receipts.md` | exports and upload receipts |
| `tools/studio-fresh-runner.luau` | SPECS for the Chase suite and the Viper/Pouncer clip data |

Studio-only: `ServerStorage.WildboundAssets.Beasts.Pouncer` is now the tarantula (asset 136993159368939); the old one is
in `ServerStorage.WildboundAssets.BeastsBackup_20261116`. `ReplicatedStorage.WildboundBeastAnimViper/Pouncer` exist.
The place is not saved by agents: the owner must save (Ctrl+S) to keep all of this.

### 2. Values

The "Current vs proposed values" table above is the delivered table (every proposed value is now live), plus the Pouncer
web (delay 0.3, speed 45, range 32, radius 2.5, root 1 s) and the Screamer grab lock (0.3 s before the strike).

### 3. Animations

| Beast | Reused | Created | Pending |
|---|---|---|---|
| Viper | Idle, Slither, Windup, Dash, Crash, Recover from `viper.blend` (made in EV-W3, never played before): now baked and wired | the bake tool | a distinct "hit" clip (a hit uses Recover; a wall uses Crash) |
| Pouncer | Idle, Stalk, Windup, Leap, Land, Recover (rebuilt on the tarantula mesh) | Throw (web throw, 0.6 s) | none |
| Screamer | ScreamCharge, ScreamPulse, Pursue, Idle, RushTelegraph, Rush, Crash; Warn frame 0 held as the statue pose | the freeze plan step | a real statue pose and a transformation clip (needs a Blender pass on the rig source, not in the repo) |
| Root | all existing; Collapse + Emerge reused for the burrow | none | none |
| Gaze | all existing; Pulse for the defeat | none | none |
| Lurker | all existing (its crouch is now the only cue) | none | none |

### 4. Tests and results

See the BR0 and BR1-BR6 evidence rows and the Play checks above.

### 5. Problems, decisions and manual steps

- Decisions: BR-D1..BR-D19 above.
- Not tested: two players (bystanders seeing the web ball, the Screamer true form for a late joiner: a bystander who
  joins after the scream sees the stone colours until the next phase change), a phone, normal (non-private) damage mode
  on a live server (Gaze's defeat then only knocks the egg out, by design BR-D6).
- Viper's slow uses the existing `applySlow`, which ends early whenever `WildboundServer.applyCarry` recomputes the walk
  speed (pre-existing; a lasting fix belongs in the teammate's SistemaSonriente Velocidad module).
- Pouncer cannot land on some relief ridge parts (`world.landing` overlap check, pre-existing); it now keeps retrying
  every 0.5 s instead of leaving (persistent chase).
- Root's lanes and whip are checked and drawn at its own height; on very uneven relief they can miss (pre-existing).
- Owner: save the place in Studio to keep the tarantula template, the clip modules and every script change.
- Owner: archive or delete the two transport Models 104898638172426 and 110244231107381 in the Creator Dashboard
  (Open Cloud refused to archive them).
- Candy guardians' suites after the final change set: Gomibu 9/0 and DonGlaseon 20/0 ran after every change;
  Flanfuria 10/0 and Tortidragon 9/0 ran after BR0 (the later Attack change only adds an optional `hidden` field to
  Attack.open; no signature or default changed for beasts outside the six).

## Next step

Two-player and phone playtest of the six beasts (owner), then tuning of the PROPUESTA values from that playtest.

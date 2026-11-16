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
- [ ] BR0 Shared chase rules: `WildboundBeastChase` + the persistent chase in `Attack.guard`, `Attack.walk` and the
  Viper/Pouncer guard in `WildboundBeastEncounters`.
- [ ] BR1 Viper: scale, clips, faster/longer dash with the same tell, slow on a confirmed hit.
- [ ] BR2 Pouncer: tarantula model, bigger landing radius, one web ball per valid landing, 1 s root.
- [ ] BR3 Screamer: display rename, statue -> harmless scream/true form -> very fast chase, validated teleport.
- [ ] BR4 Root: brown and bigger, organic roots with longer reach, faster enclosure that stays escapable, burrow chase.
- [ ] BR5 Gaze: big and black, 3 s accumulated look with line of sight = one instant defeat per encounter.
- [ ] BR6 Lurker: no early appearance/attack warnings, mechanic and persistent chase kept.
- [ ] BR7 Final pass: section 10 deliverables, Studio == repo for every touched script, all commits pushed.

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

## Evidence

| ID | Commit | Checks |
|---|---|---|
| BR-A | (this commit) | audit only; Studio fingerprints of the 23 beast scripts equal repo HEAD at start |

## Next step

BR0 shared chase rules, then BR1-BR6 beast by beast.

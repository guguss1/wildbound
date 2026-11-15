# Wildbound Scuttler (and shared beast visibility)

Feature document for `docs/design/wildbound-scuttler-plan.md`. Status words follow the overview (section 13).

## Objective

Add the Scuttler, a global threat-3 beast that reads the player (route intercept, feint charge, panic pulse, overrun
and fall), on top of the existing beast system. First, SC0: let every nearby player see every beast (La Silueta
excepted) while strikes, pulses, slows, knocks and egg drops keep affecting only the beast's target.

## Problem and why

Encounters were target-only: `WildboundBeasts.server` fired `BeastEvent` to the target's client alone, so a second
player standing next to the target saw nothing. The owner decided (Q4, 2026-11-14) that every player sees every beast
within a proximity radius (about 150 studs), that only the target is ever affected, and that La Silueta stays
personal. SC0 is that beast-system change, done before SC1.

## Scope

- SC0: `WildboundBeastAudience` (new, pure, ServerScriptService), `WildboundBeastConfig` (`Config.AUDIENCE`),
  `WildboundBeasts.server` (fan-out, enter/leave refresh, 5 Hz bystander snapshots, cleanup on every end),
  `WildboundBeasts.client` (quiet bystander rendering), suites `WildboundBeastAudience_Test` (new) and
  `WildboundBeastWiring_Test` (4 new SC0 cases), `tools/deploy_manifest.py` and its pin.
- SC1 to SC12: as in the plan, section 13.
- Out of scope: El Sonriente (SistemaSonriente, the teammate's), La Silueta (world script, lock zone), any new
  client-to-server traffic, monetization, uploads.

## Constraints

- Lock zone untouched: WildboundServer, WildboundState, WildboundEggCarry, WildboundBatKnock, WildboundWorldClient,
  WildboundEggCarry_Test, WildboundBat_Test, WildboundMechanicsWiring_Test, every SistemaSonriente folder.
- Parallel writers' files untouched: T05b (`tools/*economy*`, `docs/balance/`, `odd/tasks/wildbound-2-0.md`),
  `tools/studio-fresh-runner.luau` and `tools/test_studio_fresh_runner.py`.
- Shared Team Create place: before overwriting a Studio Source, it must equal the repo file (length + Adler-32 after
  CRLF->LF and trimming trailing newlines); otherwise stop and report. Never edit Workspace, never save or publish.
- Server authority unchanged: bystanders only receive; the director, the budget, the dodge states and the hit path are
  not touched.

## TDD and runner

- Mode: Strict TDD (source: the workflow task for this feature). RED against the current Studio modules, then
  implement, deploy, GREEN.
- Studio runner: MCP `execute_luau` (Edit) on fresh clones in a temporary `ServerStorage.SC0_Tmp` folder, destroyed
  afterwards. Module clones have their absolute `DataModel:GetService(...)` requires redirected to the suite folder,
  because the Edit session's require cache holds a stale `WildboundBeastConfig` (no `homeBiome`, no `SUMMONED`).
- Python: `python -I -B -m unittest discover -s tools -p "test_*.py"`.

## Design choices (SC0)

- Recipients are decided by a pure module, `WildboundBeastAudience`. A bystander is another player with a living body
  within `RADIUS` (150) flat studs of the beast; they keep it until `RADIUS + LEAVE_MARGIN` (165) so the edge does
  not flicker; at most `MAX_PER_CLIENT` (4) other players' beasts each, the nearest first, with a current member
  ranked `LEAVE_MARGIN` nearer (cap hysteresis: no End plus Spawn churn when two beasts trade places). All in
  `Config.AUDIENCE`, PROPUESTA.
- A viewer in a safe zone sees no beast (an encounter ends at once when its own target is safe), and a viewer in the
  Pradera sees only the summoned kids beasts (no forest beast is ever drawn in the meadow).
- Visual events (Spawn, Snap, Phase, Tell, TellEnd, Strike, Move, Windup, Lock, Dash, Recover, Telegraph, Freeze, Leap,
  Land, Cancel, Disengage, End, and the original beasts' phase markers Stalk and Hunt) go to bystanders as copies without effect fields (`damage`, `knock`, `slow`, `sticky`,
  `mark`, `eggDropped`, `dodged`, `line`, `hit`) and marked `bystander = true`. Everything else (Hit, Exposure,
  SightBreak, Notice, a future Afflict) stays with the target: a new event type is private until it is listed.
- Membership is re-evaluated every `REFRESH_SECONDS` (0.5 s) from server positions. An entering player gets a spawn
  snapshot in the beast's current phase plus a replay of its live visual state (`Audience.remember` / `replay`: the
  last Phase, Viper's lane, Pouncer's circle, open tells including Root's walls, a running Move, a Disengage);
  membership is committed only after that spawn was sent, so a failed send retries next refresh. A leaving one gets an
  `End` with reason `OutOfRange`. An encounter's end, and a
  target leaving the server, send `End` to its bystanders; a leaving viewer is forgotten.
- Bandwidth: bystanders get snapshots every `SNAP_SECONDS` (0.2 s, 5 Hz); the target keeps 10 Hz. A bystander view
  renders `SNAP_SECONDS + 0.05` s behind the server clock (the target view 0.1 s), so it interpolates instead of
  holding and jumping.
- La Silueta: `Audience.PERSONAL.Silueta`. She lives in the world script (lock zone) and never passes through the beast
  script, so she stays personal both by construction and by the rule.
- Client: a bystander view uses the same model, animation attributes and timeline. While a bystander event is handled
  (`muting`), `play`, `showWarning`, `showLine` and `shake` return early; Hit, Exposure and SightBreak are ignored;
  no BeastObserve is sent for a bystander's Gaze or Lurker; Root's raised walls never collide for a bystander. Tells
  are drawn, not skipped: same geometry, a neutral cream colour (226, 224, 210) at 40 % of the target's opacity
  (`soften`, once per drawn part: a `Softened` attribute keeps a second call from dimming it again), so a bystander
  understands the attack without being alarmed.

## Checklist

- [ ] SC0 Shared beast visibility (all beasts except La Silueta) -- code complete, GREEN and deployed (server
  included, with the teammate's Patio code ported); only the two-player check is pending (see evidence)
  - [x] SC0.1 Tests first: `WildboundBeastAudience_Test` (12 cases) and 3 SC0 cases in `WildboundBeastWiring_Test`;
    RED observed against Studio
  - [x] SC0.2 `Config.AUDIENCE` and the pure `WildboundBeastAudience` module; deployed and read back
  - [x] SC0.3 Client quiet bystander rendering; deployed and read back
  - [x] SC0.4 Server fan-out deployed to Studio -- the teammate's Studio-only Patio code (`PatioDentro` roll guard,
    `PatioBestia` BindableFunction) ported byte for byte into the repo file by a 3-way merge (base f9c7ef4), suites
    GREEN on the merged source, deployed and read back 41462:2561573253, solo Play checked (see "Patio port and server
    deploy"). Not committed
  - [x] SC0.5 Deploy manifest and pin
  - [ ] SC0.6 Two-player Studio check -- NOT VERIFIED (solo Play only; second recipient simulated)
  - [x] SC0.7 Review correction (findings 1-6): Pradera and safe-zone viewers, cap hysteresis, bystander render delay,
    late-joiner replay plus Stalk/Hunt as visual, idempotent soften, membership committed after the spawn send; 5 new
    Audience behaviour cases and 1 Wiring case; RED then GREEN; module, client and both suites deployed and read back
    (server: repo only, see SC0.4). Not committed
- [x] SC1 Config entry and director pins; verify a live press moves `WildboundDash` -- RED then GREEN, config and
  Dodge deployed and read back, live press checked in solo Play (see "Evidence (SC1)"). Not committed
- [x] SC2 `Attack.afflict` -- RED 9/4 then GREEN 13/0, module and suite deployed and read back, `Attack.hit` consumers
  65/0 (see "Evidence (SC2)"). Not committed
- [x] SC3 Brain skeleton (Spawn, Stalk, committed charge, Recovery, Castigo y caida, Disengage) -- RED (module
  missing) then GREEN 12/0, module and suite deployed and read back, manifest rows and runner SPECS added; not wired
  into the beast script yet (SC7) (see "Evidence (SC3)"). Not committed
- [x] SC4 Finta de caza -- RED 13/7 then GREEN 20/0, module and suite deployed and read back; the brain reads
  `world.random`, `world.lastDash` and `target.carryingEgg`, which the beast script supplies only from SC7 (see
  "Evidence (SC4)"). Not committed
- [x] SC5 Ruta predictiva -- RED 21/8 then GREEN 29/0, module and suite deployed and read back; the brain reads
  `target.vx/vz`, `world.safe`, `world.landing`, `world.lineOfSight` and `world.lastDash` (see "Evidence (SC5)"). Not
  committed
- [x] SC6 Pulso de panico -- RED 30/8 (Scuttler) and 45/1 (Director pin) then GREEN 38/0 and 46/0, module, config and
  both suites deployed and read back; `PulseCooldownSeconds` 9 -> 5 (see "Evidence (SC6)"). Not committed
- [x] SC7 Beast script wiring -- RED Scuttler 38/3, Wiring 42/3 then GREEN 41/0 and 45/0, beast script and brain
  deployed and read back; solo Play: three forced Scuttler encounters ran and each released the budget once, two
  landed pulses slowed 16 -> 12 for about 1.5 s (see "Evidence (SC7)"). Not committed
- [x] SC8 Client and proxy -- RED AnimPlan 9/3, Wiring 44/5, Text 18/1 then GREEN 12/0, 49/0, 19/0; proxy, plans,
  texts, client tells and the anim client's variant deployed and read back; solo Play: forced encounters showed the
  proxy (13.65 studs), the real lane, the feint outline, the hatched zone, the Snap sector, the pulse rings, a landed
  pulse's desaturation and the fall stars, 0 client errors (see "Evidence (SC8)"). Bystander style not checked (needs two
  players). Not committed
- [ ] SC9 Blender rig and baked clips (no upload) -- repo part done: Blender source, FBX (43 bones, 8 meshes, all
  bones skinned, re-import checked), front/side/back previews, the 17 clips as data and their suite (see "Evidence
  (SC9)"). Pending, Studio only: register the two files, run the suite, import the FBX and build the prefab, build and
  publish the clips. Suite not run (no Luau runtime outside Studio)
- [ ] SC10 Mesh upload (only after explicit user approval)
- [ ] SC11 Playtest: solo, then two players
- [ ] SC12 Docs: mechanics doc and overview status

## Acceptance criteria (SC0, from the plan)

A non-target client within the radius sees spawn, tells and phases; a non-target is never hit, slowed or knocked;
beyond the radius nothing is sent; Silueta events stay target-only; the per-player budget is unchanged.

## Evidence (SC0, 2026-11-14)

- Studio target: the single instance listed for placeId 122652861404212 (Edit).
- Pre-deploy fingerprints (Studio == repo): `WildboundBeastsClient` 38902:334963459, `WildboundBeastConfig`
  22976:3033649015, `WildboundBeastWiring_Test` 32568:1189062736.
- Mismatch: Studio `ServerScriptService.WildboundBeasts` is 37564:2137873840, the repo file 35774:1300170918. Studio
  carries a teammate's training-yard addition that is not in the repo (`PatioDentro` roll guard in the poll loop and a
  `PatioBestia` BindableFunction block at the end). Per the shared-place rule the live script was not overwritten.
- RED: `WildboundBeastAudience_Test` errored (module missing); `WildboundBeastWiring_Test` 37 passed, 3 failed (the 3
  new SC0 cases).
- GREEN (fresh clones; the Wiring suite read the Studio server source with the 15 SC0 edits merged in memory, every
  edit anchor unique; `loadstring` compiled the merged server, the client, the module and the config): Audience 12/0,
  Wiring 40/0, AnimPlan 9/0, Encounters 24/0, Director 39/0, Attack 9/0, Gaze 7/0, Lurker 7/0, Root 9/0, Streamer 8/0,
  Nube 11/0, Abeja 10/0, Sight 7/0. Total 192 passed, 0 failed.
- Read-back after deploy (Studio == repo): `WildboundBeastsClient` 41448:3985475766, `WildboundBeastConfig`
  23694:362591623, `WildboundBeastAudience` 6744:1244912934, `WildboundBeastWiring_Test` 36596:3327586766,
  `WildboundBeastAudience_Test` 10783:3336114345. `WildboundBeasts` unchanged at 37564:2137873840.
- Solo Play (lock `SC0-shared-visibility`, cleared after): a forced Root and Viper on the player drew as before for the
  target (Root WhipWindup, HUD line shown); hits landed and both ended. A simulated bystander stream fired from the
  server to the same client (Spawn in phase Warn, Phase ScreamCharge, a circle Tell, then End OutOfRange, all
  `bystander = true`): the Streamer view took the ScreamCharge phase, its tell was cream (0.886, 0.878, 0.824) at
  transparency 0.84, no Sound was created, the warning line stayed hidden, and the End cleared the local folder. No
  beast-script errors in the console.
- Two-player check: NOT VERIFIED (start_stop_play runs solo only); the second recipient is covered by the pure suite's
  simulated two-player case.

### Correction (review findings 1-6, 2026-11-14)

- Pre-deploy fingerprints (Studio == repo before the correction): `WildboundBeastAudience` 6744:1244912934,
  `WildboundBeastsClient` 41448:3985475766, `WildboundBeastAudience_Test` 10783:3336114345, `WildboundBeastWiring_Test`
  36596:3327586766; `WildboundBeastConfig` 23694:362591623 (unchanged, not redeployed).
- Runner: fresh clones in `ServerStorage.SC0_Tmp` (destroyed after); the server source under test was the Studio
  script's clone with the original SC0 edits and then the correction edits applied (compiles with `loadstring`).
- RED (new suites, old module and client): Audience 12 passed, 5 failed (Stalk not visual; meadow/safe viewers;
  cap churn; `Audience.remember` missing; enters committed without a delivery). The dead-target case passed already:
  it pins existing behaviour. Wiring 40 passed, 1 failed (the new correction case).
- GREEN: Audience 17/0, Wiring 41/0, on the clones and again on the deployed instances.
- Read-back after deploy (Studio == repo): `WildboundBeastAudience` 11067:2813954137, `WildboundBeastsClient`
  41884:3225949834, `WildboundBeastAudience_Test` 18387:4258935996, `WildboundBeastWiring_Test` 37929:1908846378.
  `WildboundBeasts` unchanged at 37564:2137873840 (repo file now 39672:2892377211). No save, no publish, no Workspace
  edit, Play lock untouched (nil), temp folder gone.
- Finding 5 note: `drawShape` clears the model's children, so the Heartbeat wall raise already soften()s fresh parts;
  the idempotent flag makes that guaranteed rather than incidental.
- Not run this round: solo Play of the corrected client (the change is a render delay, the soften flag and no new
  event type), and the two-player check (SC0.6).

### Patio port and server deploy (SC0.4, 2026-11-14)

- Studio target: the single instance for placeId 122652861404212 (Edit). Studio `WildboundBeasts` re-fingerprinted
  37564:2137873840 (unchanged since the last check).
- Studio-only hunks versus `f9c7ef4` (35774:1300170918), exactly two: (1) the poll-loop roll line replaced by a
  two-line comment plus `if #due > 0 and player:GetAttribute("PatioDentro") ~= true then ... Director.roll(...)`;
  (2) a 35-line `do ... end` block appended after the Studio tool block that creates `PatioBestia` (BindableFunction
  in `WildboundTelemetry`: "poner" reserves through `Director.reserve(..., { force = true })` for a player marked
  `PatioDentro`, "quitar" closes that player's encounters with reason "Patio"). base + these hunks reproduced
  37564:2137873840 exactly.
- Merge: `git merge-file` (ours HEAD 39672:2892377211, base f9c7ef4, theirs Studio) applied both hunks with no
  conflict; repo file now 41462:2561573253. "quitar" goes through `close`, which already calls `Audience.close`, so the
  yard's removals also end the bystanders' views.
- Not ported (Studio-only, teammate-owned, not needed for the beast script to run): `ServerScriptService.
  PatioEntrenamiento` (Servidor, Bichos, LEEME, Pruebas/ReglasVida_Test, Pruebas/BestiasCableado_Test),
  `ReplicatedStorage.PatioEntrenamiento` (ReglasVida, Config), `StarterPlayerScripts.PatioEntrenamiento.Cliente`,
  `Workspace.PatioEntrenamiento` (Model, 25 children).
- GREEN (fresh-runner logic, filter `^WildboundBeast[ADEW][a-z]+_Test$`, `src:WildboundBeasts` served from the merged
  source, fingerprint asserted): Attack 9/0, Audience 17/0, Director 39/0, Encounters 24/0, Wiring 41/0; 130 passed,
  0 failed, no leaks, no test expectation changed. The teammate's `BestiasCableado_Test` on the deployed source: 3/0.
- Deploy: fingerprint re-checked in the same call immediately before writing (37564:2137873840), written with
  `ScriptEditorService:UpdateSourceAsync`, read back 41462:2561573253 (== repo). No save, no publish, no Workspace
  edit, lock-zone scripts untouched.
- Solo Play (lock `patio-merge`, set from nil and cleared after): `WildboundTelemetry` had `ForceSpawnBeast`,
  `PatioBestia` and `BeastProbe`; `PatioBestia` refused a player outside the yard (`NotInYard`); at spawn a forced
  Viper was refused `SafeZone`; after moving the Play character outside the safe zone a forced Viper started
  (`beast:1`, Windup) and ended through the probe (ended 1, errors 0); with `PatioDentro` set in Play, "poner" Pouncer
  started (`beast:2`, Hunt) and "quitar" ended 1. No beast-script errors or warnings in the console.
- Python: `python -I -B -m unittest discover -s tools -p "test_*.py"`: 1298 run, 5 failed, 28 skipped. Failures: 3
  economy-config export, lumipol_v2 v1 files, and `test_studio_fresh_runner` (`WildboundRoulette_Test` has no SPECS
  or SKIP entry; another writer's suite). The audio catalog d9 failure seen earlier now passes.

### Evidence (SC1, 2026-11-14)

Route: direct inline (two source files with mechanical config rows, two suites). TDD: strict (workflow task).

- Changes: `WildboundBeastConfig` gains `BEASTS.Scuttler` (plan section 6: Global, biome nil, points 3, chance10 1/60
  through `Config.perRoll`, cooldown 75, spawn 40-75 / 1.0 s, escape 110 / 4 / 1.2, laneWidth 8, lockLead 0.3,
  hitHeight 8, damage 30, and a frozen `tuning` table with every other section 6 key), and Scuttler is appended to
  `ORDER` (ninth: its calendar slot is 8 s after Viper's), `PLAYABLE` and `WAVE2`. `WildboundDodge.SOURCES.Scuttler`.
  No `Config.SPAWN_BIAS` is added (plan section 8: a later toggle, off by absence; a case pins it is not true). The
  director needed no code change.
- Tests: `WildboundBeastDirector_Test` 7 new SC1 cases (entry and numbers, tells >= 0.8 s and slow inside applySlow's
  clamps, no biome preference, never starts with any point in use, nothing starts while it hunts plus release once and
  the 75 s cooldown, never in Pradera / safe zone / dead / Silueta, calendar slot and chance); `WildboundDodge_Test`
  D14 (source, a 0.9 s tell registers, 0.79 s is refused, a perfect press dodges it). Existing pins adapted to the
  ninth calendar beast (no rule changed): `#Config.ORDER` 8 -> 9 (two cases), `#Director.due` 8 -> 9, the BW2 calendar
  case gains `dueAt(128) == "Scuttler"`, and the "dead or safe player" case consumes up to t = 28 (Scuttler's slot)
  instead of 27.
- Studio target: the single instance for placeId 122652861404212 (Edit). Pre-deploy (Studio == repo HEAD):
  `WildboundBeastConfig` 23694:362591623, `WildboundDodge` 9010:1762949462, `WildboundBeastDirector_Test`
  35347:496867519, `WildboundDodge_Test` 8769:979668193, `WildboundBeastDirector` 13956:3503643689 (unchanged).
- RED (fresh-clone runner logic, filtered to the two suites; tests deployed first, old modules): Director 37 passed,
  9 failed (the 7 new cases and the two `#ORDER` pins); Dodge 13 passed, 1 failed (D14).
- GREEN after deploying config and Dodge: Director 44/2 on the first pass (the two calendar pins above, which assumed
  8 beasts), fixed, then Director 46/0, Dodge 14/0. Same deploy, every other beast suite on the fresh runner: Abeja
  10/0, AnimPlan 9/0, Attack 9/0, Audience 17/0, Encounters 24/0, Gaze 7/0, Lurker 7/0, Nube 11/0, Root 9/0, Sight 7/0,
  Streamer 8/0, Wiring 41/0. Total 219 passed, 0 failed, no leaks.
- Read-back (Studio == repo working tree): `WildboundBeastConfig` 26047:2520817000, `WildboundDodge` 9137:2062853421,
  `WildboundBeastDirector_Test` 43890:3431936679, `WildboundDodge_Test` 9435:3858719119. `WildboundBeasts`
  41462:2561573253 unchanged. Every write was compiled with `loadstring` and fingerprint-checked before
  `UpdateSourceAsync`. No save, no publish, no Workspace edit, runner lock and temp folders cleared.
- Live press (solo Play, lock `SC1-dodge-press` set from nil and cleared after): Z on the client (the
  `WildboundWorldClient` "WildboundDodge" action fires the stance remote; Studio's `WildboundServer` `Heist.dodge` calls
  `DodgeService.press`). Server attribute `WildboundDash` went nil -> 1794690287.38 with `WildboundDodgeReady` = +1.2 s
  (a Whiff: MISS_COOLDOWN), and the root moved 14.5 studs; a second press 1.5 s later moved it to 1794690297.72 and the
  root another 14.5 studs. In Play the live modules had `BEASTS.Scuttler`, `ORDER[9] == "Scuttler"` and
  `Dodge.SOURCES.Scuttler`. No beast-script errors in the console.
- Python: `python -I -B -m unittest discover -s tools -p "test_*.py"`: 1298 run, 4 failed, 28 skipped. Failures, all
  other tracks: 3 economy-config export (`test_export_economy_config_luau`), 1 lumipol_v2 v1 blend hash.
- Open: until SC3/SC7 register a Scuttler behaviour, a won Scuttler roll in Play reaches `start` and closes at once
  with `NoBehaviour` (the existing guard): the 3 points are released, but the release starts the 15 s global cooldown
  and Scuttler's 75 s species cooldown. Rare (1/60 per 10 s, only with 0 points in use), not observed in this Play.
- Open: summoned kids beasts (points 0) are outside the budget by design (KB-1), so a Pradera summon is not blocked by
  an active Scuttler through the budget; Scuttler itself never starts in Pradera. SC7 should decide whether entering
  Pradera ends a Scuttler encounter.

## Evidence (SC2, 2026-11-14)

- Route: direct inline (one module plus its suite). TDD strict, fresh-clone runner logic (`tools/studio-fresh-runner.luau`,
  SPECS reduced to the filtered suites), Edit datamodel.
- `src/wildbound/WildboundBeastAttack.luau`: new `Attack.afflict(events, e, world, attack, now, fields)`. Settling is
  shared with `Attack.hit` through a local `land` (close once, ask the dodge only when dodgeable, emit the Strike);
  `Attack.hit` behaviour is unchanged. A landed affliction emits `Strike` (hit = true) and `Afflict`
  (`attack` id plus the fields, no `damage`), never `Hit`; a perfect dodge emits only the dodged Strike. Returns
  "Afflicted", "Dodged" or nil when already settled.
- `tests/WildboundBeastAttack_Test.luau`: 4 new SC2 cases (landed: Strike + Afflict with fields, never Hit, dodge asked
  once; dodged: no Afflict, no Hit; one outcome only: afflict/hit/miss after any outcome are no-ops; undodgeable never
  asks the dodge and nothing afflicts after closeAll).
- Studio pre-check: module and suite equalled repo HEAD (module 9536 / 3457584777, suite 9479 / 2358479208).
- RED (new suite against the current module): 9 passed, 4 failed (the 4 SC2 cases: `Attack.afflict` is nil).
- GREEN after deploy: `WildboundBeastAttack_Test` 13 passed, 0 failed. Regression over every `Attack.hit` consumer
  (Abeja 10, Attack 13, Gaze 7, Lurker 7, Nube 11, Root 9, Streamer 8): 65 passed, 0 failed.
- Read-back: `ServerScriptService.WildboundBeastAttack` 10743 / 3970247103, `ServerStorage.WildboundBeastAttack_Test`
  13805 / 3200446642, both equal to the working files (length / Adler-32, LF, trailing newlines trimmed). No Play needed
  (pure module; no wiring yet).
- Manifest and runner already list the module and suite; no new rows.
- Python: 1298 run, 4 failed, 28 skipped; the same other-track failures as SC1 (3 economy-config export, 1 lumipol_v2
  v1 blend hash). Not committed.

## Evidence (SC3, 2026-11-14)

- Route: direct inline (one new module plus its new suite; mechanical manifest and runner rows). TDD strict.
- `src/wildbound/WildboundBeastScuttler.luau` (new, ServerScriptService): pure `init`/`step` brain. Spawn (1.0 s) ->
  Stalk (keeps 20..34 studs at 14 studs/s, faces the target) -> ChargeTell (1.1 s, the lane follows the target until
  `lockLead` 0.3 s before the commit, then is locked and cut at a wall by `world.castLane`; registered with the dodge
  through `Attack.open`) -> Charge (straight swept lane at 46 studs/s, 40 studs, `Attack.hit` with `ChargeDamage`, no
  homing) -> Recovery (1.2 s; landed or missed) or Fallen (the charge was `"Dodged"`: an 8-stud overrun along the
  locked line, then Stumble 2.2 s in open ground, or Crash 3.0 s when a wall is inside the overrun (stops 0.5 stud
  short) or already cut the lane) -> Stalk; after `FallsToGiveUp` (2) falls the second fall's end starts Disengage
  `Outplayed`. Escape and Timeout through `Attack.guard` (busy only during ChargeTell and Charge). The first move is a
  committed charge (`chargeReadyAt = -inf`); later charges wait `ChargeCooldownSeconds` (4.5 s) from the commit. A
  staggered `Attack.open` (claimStrike refused) leaves it in Stalk and retries next step. Fallen carries
  `{ fall, crashed, overrun, falls }`; an overrun emits a `Move` dash. Nothing is open while Fallen. Not registered with
  `Enc` by the beast script yet (SC7).
- `tests/WildboundBeastScuttler_Test.luau` (new, 12 cases): first move is a registered committed charge (tell >= 0.8 s,
  never refused, lockAt = commit - 0.3); stalk band; lane follows until the lock then never moves, one hit with
  ChargeDamage, Move dash, Recovery, no fall on a landed charge; step-out is a miss with cancel and 1.2 s recovery;
  dodged in open ground -> Stumble, full overrun straight on, no tell or open attack while fallen; wall inside the
  overrun -> Crash short of the wall; wall cutting the lane -> Crash; two falls -> Disengage Outplayed at the second
  fall's end, End after 1.2 s, no third charge; stagger waits; safe zone mid-tell ends at once and `Attack.closeAll`
  cancels the registration; death; Escape at 4 s and Timeout at 45 s; purity.
- `tools/deploy_manifest.py` and `tools/test_deploy_manifest.py`: two SC3 rows each. `tools/studio-fresh-runner.luau`:
  `SPECS["WildboundBeastScuttler_Test"]` (Encounters, Scuttler, Config, Attack modules, Scuttler source).
- Studio target: the single instance for placeId 122652861404212 (Edit). Pre-check: neither new instance existed;
  dependencies equalled the working tree (`WildboundBeastEncounters` 15458:1404725380, `WildboundBeastAttack`
  10743:3970247103, `WildboundBeastConfig` 26047:2520817000).
- RED (suite deployed first, fresh-clone runner logic filtered to `^WildboundBeast[SE][a-z]+_Test$`):
  `WildboundBeastScuttler_Test` ERROR "module not found: WildboundBeastScuttler"; Encounters 24/0, Streamer 8/0.
- GREEN after deploying the module, same runner: Scuttler 12/0, Encounters 24/0, Streamer 8/0 (44 passed, 0 failed),
  no leaks, runner lock cleared.
- Read-back (Studio == working tree): `ServerScriptService.WildboundBeastScuttler` 8564:2270039255,
  `ServerStorage.WildboundBeastScuttler_Test` 13751:1470235773. Each source was fingerprint-checked and compiled with
  `loadstring` before it was parented. No save, no publish, no Workspace edit, no Play (pure module, not wired).
- Python: 1298 run, 4 failed, 28 skipped; the same other-track failures as SC2 (3 economy-config export, 1 lumipol_v2
  v1 blend hash). The runner guard (15) and the manifest suite (25) pass with the new rows.

## Evidence (SC4, 2026-11-14)

- Route: direct inline (one module and its suite). TDD on (strict, project config); runner: the fresh-clone loader of
  `tools/studio-fresh-runner.luau` with SPECS cut to the filtered suites (`^WildboundBeast[SE][a-z]+_Test$`).
- `src/wildbound/WildboundBeastScuttler.luau`: Stalk's move choice rolls once per move (`e.plan`, kept while
  staggered). A feint (`FeintTell`, `FeintSeconds` 0.9) is chosen only when the encounter already opened a real charge,
  the last move was not a feint, `world.random()` < `FeintChance` (no `world.random`: never), and, while
  `target.carryingEgg`, fewer than `MaxFeintsWhileEgg` egg feints were made. The feint emits a `Tell` with
  `feint = true`, `dodgeable = false` (redrawn at `TELL_RATE`, following the target), never calls `Attack.open`
  (no `world.telegraph`, no strike claim, nothing in `e.open`), never moves the body, and ends with `TellEnd`
  reason `Feint`. Bait check: `world.lastDash()` inside [feint start, now] opens `PunishTell` at once, re-aimed,
  `PunishTelegraphSeconds` 0.9; no press opens `ChargeTell` (1.1 s) at the feint's end. Both are the registered real
  charge (lock 0.3 s before the commit; dodged -> Fallen). A refused strike slot after a feint goes back to Stalk and
  the next move is real. `FeintTell` and `PunishTell` count as busy for `Attack.guard`.
- `tests/WildboundBeastScuttler_Test.luau`: 8 new SC4 cases (first charge never a feint with every roll at 0; a feint
  never registers, strikes or hits, the body holds still, a real charge follows; a whole encounter never has two
  feints in a row and only real charges hit; press in the window -> re-aimed PunishTell, registration accepted with a
  tell >= 0.9 s, a dodge of it is a fall; press before the feint -> committed ChargeTell at the feint's end with the
  full 1.1 s; egg cap = 1 feint per encounter; roll >= FeintChance or no `world.random` -> never a feint; safe zone
  mid-feint ends at once with nothing to cancel).
- Studio target: the single instance for placeId 122652861404212 (Edit). Pre-check (Studio == working tree before
  the edits, both files are new and untracked): `WildboundBeastScuttler` 8564:2270039255, `WildboundBeastScuttler_Test`
  13751:1470235773; dependencies unchanged (`WildboundBeastConfig` 26047:2520817000, `WildboundBeastAttack`
  10743:3970247103, `WildboundBeastEncounters` 15458:1404725380).
- RED (suite deployed first, module unchanged): Scuttler 13 passed, 7 failed (the SC3 12 plus the first-charge case,
  which holds already); Encounters 24/0, Streamer 8/0.
- GREEN after deploying the module: Scuttler 20/0, Encounters 24/0, Streamer 8/0 (52 passed, 0 failed), no leaks,
  runner lock cleared, temporary runner holder removed.
- Read-back (Studio == working tree): `ServerScriptService.WildboundBeastScuttler` 12607:4261626075 (compiles),
  `ServerStorage.WildboundBeastScuttler_Test` 22029:2134861214. No save, no publish, no Workspace edit, no Play (pure
  module, not wired).
- Python: 1298 run, 4 failed, 28 skipped; the same other-track failures as SC2 and SC3 (3 economy-config export, 1
  lumipol_v2 v1 blend hash). No manifest or runner change (no new suite).
- Wiring owed to SC7: `worldFor(player)` must add `w.lastDash()` (the `WildboundDash` attribute, same
  `GetServerTimeNow` clock as the encounter) and `w.random()` (a server `Random`), and `targetOf` must set
  `carryingEgg` (the `WildboundEggCarried` child) for Scuttler; without them the brain never feints. Client (SC8):
  draw `Tell` events with `feint = true` as an outline without fill and without the antenna flash.

## Evidence (SC5, 2026-11-14)

- Route (inline, one writer: `src/wildbound/WildboundBeastScuttler.luau` and `tests/WildboundBeastScuttler_Test.luau`).
  TDD on (project setting), runner `tools/studio-fresh-runner.luau` filtered to `^WildboundBeast[SEA]` (Scuttler,
  Encounters, Streamer, Attack specs; same engine, pasted as a temporary holder and removed after).
- Behaviour: after the first charge, a target faster than `InterceptMinSpeed` is read first (`Read`, 0.8 s, never two
  reads in a row). At the read's end P = target + v x `PredictSeconds` (at most `InterceptMaxStuds`); P must pass
  `world.safe`, `world.landing` and `world.lineOfSight`, and Scuttler commits only when
  `ETA(Scuttler) + InterceptMarginSeconds < ETA(target)`; otherwise `Stalk` with `fallback = "Pursue"`. `Intercept`
  runs straight to P at `InterceptSpeed` 21 (< rested sprint 23.2) and draws the zone (Tell `zone = true`, circle of
  `SnapRadius` at P, not dodgeable, never an attack) from its start. `Block` (2.5 s) at P: a target inside the zone
  opens a `Snap` (registered sector, `SnapTelegraphSeconds` 0.9, `SnapArc` 100, locked when drawn), never before the
  zone was drawn `MIN_TELL`; hit only inside the sector at the strike. A press in `Read` uses the one re-plan; a press
  in `Intercept` re-plans once at >= plan + `ReplanCooldownSeconds` with the new velocity (zone TellEnd `Replan`, a new
  zone or the pursuit). The zone ends with TellEnd `Done` (block end or Snap) or `End` (guard). New events for SC8:
  Phase `Read`/`Intercept` (`to`, `eta`, `targetEta`, `replan`)/`Block`/`Snap`, Move `kind = "run"`.
- Cases (9 new): arrives-first commit with the ETA check; a target running straight away at 23.2 never gets an
  intercept and is pursued without a teleport; run speed <= `InterceptSpeed` < 23.2 and it stands at P; entering the
  zone opens a registered Snap >= MIN_TELL after the zone; no entry, no Snap, the zone ends at the block's end; one
  re-plan on an early dash, after the cooldown, with the new velocity; a press during Read uses the re-plan; never a
  safe zone, a void or an unseen P, and a re-plan into a safe zone falls back; the first move stays a charge.
- Studio target: the single instance for placeId 122652861404212 (Edit). Pre-check (Studio == working tree, both files
  untracked): `WildboundBeastScuttler` 12607:4261626075, `WildboundBeastScuttler_Test` 22029:2134861214; dependencies
  unchanged (`WildboundBeastConfig` 26047:2520817000, `WildboundBeastAttack` 10743:3970247103,
  `WildboundBeastEncounters` 15458:1404725380).
- RED (suite deployed first): Scuttler 21 passed, 8 failed (the first-move case holds already); Attack 13/0,
  Encounters 24/0, Streamer 8/0.
- GREEN: Scuttler 29/0, Attack 13/0, Encounters 24/0, Streamer 8/0 (74 passed, 0 failed), no leaks, runner lock
  cleared, temporary holder removed. Two test-only fixes between the first and the last GREEN run (find the Snap
  registration by id; read its locked Tell, not the first one).
- Read-back (Studio == working tree): `ServerScriptService.WildboundBeastScuttler` 21181:2903062228 (compiles),
  `ServerStorage.WildboundBeastScuttler_Test` 34539:2853157269. No save, no publish, no Workspace edit, no Play.
- Python: 1298 run, 4 failed, 28 skipped; the same other-track failures (3 economy-config export, 1 lumipol_v2 v1 blend
  hash). No manifest or runner change (no new suite).
- Deviation (recorded, plan section 4 is PROPUESTA): the move choice reads any target faster than `InterceptMinSpeed`,
  not only one moving away. Moving away (radial speed >= 0) gives |P - Scuttler| >= |target - Scuttler| >= `StalkMin`
  20, while committing needs |P - Scuttler| < 21 x (1.2 - 0.4) = 16.8, so the literal rule could never commit. The
  arrive-first check still filters every route Scuttler cannot win.
- Wiring owed to SC7: `targetOf` already passes `vx/vz`; `worldFor` must expose `safe`, `landing`, `lineOfSight`
  (exist in the beast script) and `lastDash`. Client (SC8): draw the zone Tell (`zone = true`) as a red hatched circle,
  the Snap sector, and the `run` Move.

## Evidence (SC6, 2026-11-14)

- Route (inline, one writer: `src/wildbound/WildboundBeastScuttler.luau`, `tests/WildboundBeastScuttler_Test.luau`, plus
  the one-number change in `src/wildbound/WildboundBeastConfig.luau` and its pin in
  `tests/WildboundBeastDirector_Test.luau`). TDD on (project setting), runner `tools/studio-fresh-runner.luau` engine with
  the Scuttler, Encounters, Streamer, Attack and Director specs, filter `^WildboundBeast[SEAD]`, kept as a temporary
  ServerStorage StringValue holder and removed after.
- Behaviour: move choice after the first charge, inside the shared move gate (`chargeReadyAt`, line of sight, range):
  pulse first when `now >= pulseReadyAt` and the target is closer than `PulseRadiusStuds + 4` (20, strict, so a target
  the stalk holds at `StalkMin` 20 is never pulsed), then the read, then a charge (feint or real). `PulseCharge`
  (1.3 s): the ring, a circle of `PulseRadiusStuds` 16 centred on Scuttler, opened through `Attack.open` (registered,
  dodgeable, damage 0) and locked at the charge start; the body holds still. At the release, one check against the
  drawn ring: outside -> `Strike` hit false and the registration cancelled; inside -> `Attack.afflict` with
  `{ pulse, slow = 0.75, slowSeconds = 1.5, shake = true }`; a perfect press -> `Strike` dodged, no slow, no pressure,
  never a fall. A landed pulse sets `lastPulseAt`; a second landed pulse within `PressureMemorySeconds` while
  `target.carryingEgg` and `e.pulseCanDropEgg` (copied per encounter from `PulseCanDropEgg`) is `Attack.hit` with
  damage 0 and `escalated = true` (the one egg drop path), then `Disengage` `EggDropped` at the release. Otherwise phase
  `Pulse` (0.5 s release, local constant) -> `Stalk`. `PulseCharge` counts as busy for `Attack.guard`.
- EggDropped after any Scuttler egg drop (plan section 7 rule 5): a landed charge on an egg carrier disengages at the
  lane end (no Recovery), a landed Snap at its strike.
- Deviations (recorded): (1) `PulseCooldownSeconds` 9 -> 5, measured from the release. With 9 the second pulse could
  never land inside the 8 s memory (9 + 1.3 > 8), so the owner's Q2 decision was unreachable; 5 + 1.3 = 6.3 s. Plan
  section 6 updated. PROPUESTA, tune in Studio. (2) The escalation needs `target.carryingEgg`: without an egg the second
  pulse stays an Afflict, because a damage-0 `Hit` would reach `BeastHit` and show "¡El Scuttler te atrapó!" with
  nothing to drop. (3) The SC4 egg-cap case now has the target step out of every locked lane (a landed charge would end
  the hunt with EggDropped); the SC5 read re-plan case reads `replans` during the intercept, since a later pulse lets a
  new read start.
- Cases (9 new): ring at the real radius from the charge start, registered and fixed; outside gets nothing; inside is an
  Afflict with the slow and shake and no damage, also on the first pulse with an egg; a perfect press cancels it (no
  slow, no fall, no pressure); a second landed pulse inside the memory with an egg is a damage-0 Hit, then EggDropped and
  End; no escalation without an egg, with the switch off, or past the memory; the first move is never a pulse and the
  band edge is never pulsed; a landed charge on an egg carrier ends with EggDropped; a safe zone mid-pulse ends at once
  and closeAll cancels the ring.
- Studio target: the single instance for placeId 122652861404212 (Edit). Pre-check (Studio == working tree):
  `WildboundBeastScuttler` 21181:2903062228, `WildboundBeastScuttler_Test` 34539:2853157269, `WildboundBeastConfig`
  26047:2520817000, `WildboundBeastDirector_Test` 43890:3431936679, `WildboundBeastAttack` 10743:3970247103,
  `WildboundBeastEncounters` 15458:1404725380.
- RED (suites deployed first): Scuttler 30 passed, 8 failed (the first-move case holds already); Director 45/1 (the new
  pin); Attack 13/0, Encounters 24/0, Streamer 8/0.
- GREEN: Scuttler 38/0, Director 46/0, Attack 13/0, Encounters 24/0, Streamer 8/0 (129 passed, 0 failed), no leaks,
  runner lock cleared, holder removed. One test-only fix between runs (the SC5 re-plan case, deviation 3).
- Read-back (Studio == working tree, all compile): `ServerScriptService.WildboundBeastScuttler` 25866:2885303217,
  `ServerStorage.WildboundBeastScuttler_Test` 46108:1605442438, `ReplicatedStorage.WildboundBeastConfig`
  26265:1751049468, `ServerStorage.WildboundBeastDirector_Test` 43890:1644638883. No save, no publish, no Workspace
  edit, no Play.
- Python: 1298 run, 4 failed, 28 skipped; the same other-track failures (3 economy-config export, 1 lumipol_v2 v1 blend
  hash). No manifest or runner change (no new suite).
- Wiring owed to SC7: handle `Afflict` (`applySlow(slow, slowSeconds)`, client shake, never `BeastHit`), pass
  `target.carryingEgg`; the escalated pulse arrives as a normal `Hit` (damage 0). Client (SC8): the `PulseCharge` ring
  (circle Tell, `r`), the `Pulse` release, the shake skipped by "Efectos suaves".

## Evidence (SC7, 2026-11-14)

- Route: inline, one writer (`src/wildbound/WildboundBeasts.server.luau`, `src/wildbound/WildboundBeastScuttler.luau`,
  `tests/WildboundBeastWiring_Test.luau`, `tests/WildboundBeastScuttler_Test.luau`, and one SPECS key in
  `tools/studio-fresh-runner.luau`). TDD strict. Runner: the `tools/studio-fresh-runner.luau` engine, SPECS cut to the
  beast suites, kept as a temporary `ServerStorage.SC7_RunnerHolder` StringValue and removed after.
- Beast script: `Scuttler` appended to the registered behaviours; its own `spawnSpec` entry (a plain ring 40..75, a
  hidden point preferred, no biome, no `SPAWN_BIAS`); `worldFor` adds `w.lastDash()` (the `WildboundDash` attribute,
  finite or nil) and `w.random()` (the server `rng`); `targetOf` sets `carryingEgg` (the `WildboundEggCarried` child)
  and `siluetaActive` for Scuttler; a new `afflict(entry, event)` calls only `applySlow(slow, slowSeconds)` and counts
  `Beast_afflicted`, never BeastHit. The Afflict event goes to the target alone (not in `Audience.VISUAL`); the client's
  shake is SC8. Patio hooks, SC0 fan-out and the Studio tools are unchanged.
- Silueta yield (plan section 7 rule 6) lives in the brain: with `target.siluetaActive` and no open attack (`busy`),
  the zone ends with TellEnd `Silueta` and Scuttler disengages `Silueta`; an open charge, Snap or pulse resolves first.
- Egg-drop disengage needed no new script code: the brain's EggDropped paths read `target.carryingEgg`, now supplied;
  the drop itself is the ordinary Hit path (damage-0 Hit for the escalated pulse).
- Pradera (SC1 open item): decided by the existing rule; a non-summoned encounter whose target enters the Pradera ends
  at once with reason `Pradera` (pinned by the SC7 Wiring case).
- Cases: Wiring 4 new (registration and spawnSpec; adapter and target extras; Afflict target-only with
  `sources.audience`; ends through the shared close, Patio and SC0 kept) and the BW2 pin updated to the five-name list;
  Scuttler 3 new (Silueta mid-tell yields after the charge resolves; Silueta already hunting: no attack, disengage at
  once; Silueta during an intercept ends the zone).
- Studio target: the single instance for placeId 122652861404212 (Edit). Pre-check (Studio == repo): `WildboundBeasts`
  41462:2561573253 (== HEAD), `WildboundBeastScuttler` 25866:2885303217, `WildboundBeastAudience` 11067:2813954137,
  `WildboundBeastScuttler_Test` 46108:1605442438, `WildboundBeastWiring_Test` 37929:1908846378 (== HEAD).
- RED (suites deployed first): Scuttler 38/3, Wiring 42/3 (the fourth SC7 Wiring case pins existing behaviour).
- GREEN after deploying both scripts (both compile with `loadstring`): first pass every beast suite 234/1 (the BW2 pin),
  pin updated; then Scuttler 41/0, Wiring 45/0, Sight 7/0, Streamer 8/0; the same deploy's other beast suites Attack
  13/0, Audience 17/0, Director 46/0, Encounters 24/0, Gaze 7/0, Lurker 7/0, Nube 11/0, Root 9/0. No leaks.
  Not run: Abeja and AnimPlan (not in the reduced SPECS; neither reads the changed files).
- Read-back (Studio == working tree): `WildboundBeasts` 43288:2374956119, `WildboundBeastScuttler` 26338:1753340479,
  `WildboundBeastWiring_Test` 41900:2169754626, `WildboundBeastScuttler_Test` 48323:3586383435.
- Solo Play (lock `SC7-scuttler-wiring`, set from nil and cleared after; Play stopped by this step): character moved
  out of the safe zone, `ForceSpawnBeast("Scuttler")` three times.
  - beast:1: Spawn, ChargeTell, Charge, Recovery, Stalk, FeintTell then ChargeTell (bait refused), Charge... 4 hits;
    ended `Death` (this place deals damage: 4 x 30). Director log: Started, Ended:Death once; points 0 after.
  - beast:2: ended `SafeZone` (the test's teleport crossed a safe zone); points 0.
  - beast:3 (at 298, 197, the test teleporting the character 12 studs from it during Stalk): two PulseCharge -> Pulse
    releases landed as Afflict (`Beast_afflicted` 2, later 3); WalkSpeed 16 -> 12.00 for about 1.5 s then back to 16;
    no Hit from a pulse. Ended `Death` after charge hits; released once, points 0.
  - Totals: started 3, ended 3, errors 0. No beast-script error or warning in the console.
- Not observed in Play: an intercept, a Silueta yield, an EggDropped disengage (no egg carried) and a dodge (no press);
  these are covered by the pure suites only.
- Python: 1298 run, 4 failed, 28 skipped; the same other-track failures (3 economy-config export, 1 lumipol_v2 v1
  blend hash). Runner guard passes with the new `audience` key. No manifest change (no new file).

## Evidence (SC8, 2026-11-14)

- Route: inline, one writer (`src/wildbound/WildboundBeastProxies.luau`, `src/wildbound/WildboundBeastAnimPlan.luau`,
  `src/wildbound/WildboundText.luau`, `src/wildbound/WildboundBeasts.client.luau`, `src/wildbound/WildboundBeastAnim.client.luau`,
  `tests/WildboundBeastAnimPlan_Test.luau`, `tests/WildboundBeastWiring_Test.luau`, `tests/WildboundText_Test.luau`). TDD
  strict. Runner: the `tools/studio-fresh-runner.luau` engine with the AnimPlan, Wiring and Text specs, kept as a
  temporary `ServerStorage.SC8_RunnerHolder` StringValue and removed after. No new suite or file: no manifest or SPECS
  change.
- Proxy: `Proxies.scuttler` (in `BUILDERS`, so `Proxies.ensure` builds `ScuttlerProxy`), `Proxies.SCUTTLER_PALETTE`
  (carapace maroon 6E2A35/4A1C26, cream chevrons EADBB8, moss 7E8F3A, amber Neon eyes and antenna tips FFB020, claws
  E3D3B4). 46 inert parts, pivot on the ground, head -Z, top 13.65 studs (Q1 12-14), claw arms with Pincer A/B, 8 legs.
- AnimPlan: `PLANS.Scuttler` names exactly the 17 clips of plan section 9; every brain phase (Spawn, Stalk, FeintTell,
  ChargeTell, PunishTell, Charge, Recovery, Fallen, Read, Intercept, Block, Snap, PulseCharge, Pulse, Disengage) has a
  plan; `Fallen>Stalk` plays GetUp. New optional `variant` argument of `Plan.steps`: a "Phase:Variant" entry wins
  (`Fallen:Crash` plays Crash, otherwise Stumble). The beast client publishes `BeastPhaseVariant` (Fallen's `fall`) and
  the anim client passes it.
- Text: `Text.BEAST.Scuttler` with the section 9 lines. Deviation: `PunishTell` (the bait was taken) is a real charge
  and has no line in the plan, so it reuses the ChargeTell line (otherwise the feint's line would stay up).
- Client: tell colour red (255, 60, 40). Feint `Tell` (`feint = true`): the lane's Fill and Chevrons are removed and two
  end bars added (outline only). Real lock: the antenna tips flash white 0.3 s (never for a feint). Zone `Tell`
  (`zone = true`): the circle plus diagonal hatch bars clipped to its radius. Pulse ring (Scuttler circle that is not a
  zone, until its strike): two rings ripple from the centre to the drawn `shape.r`, faster toward the release. `Fallen`
  shows the stars at 15 studs and a dust burst. `Move` `run` follows the server's timeline (endAt = `untilAt`). New
  `Afflict` handler: target only, skipped by "Efectos suaves"; a 0.25 s camera shake and a 0.45 s
  `ColorCorrectionEffect` on the client camera; never touches WalkSpeed (the server applied the slow). Proxy posture:
  ChargeTell, PunishTell and FeintTell crouch alike; PulseCharge rears up; Fallen tilts. Sounds (catalogue slots of plan
  section 9 only): Stalk/Intercept/ChargeTell `steps`, Read and PulseCharge `unease`, PunishTell `stinger`, Charge
  `dirt`, Snap `snap`, Pulse `roar`, Fallen `softStinger`, Fallen Crash `crack`, spawn `dirt`; FeintTell has no sound
  on purpose (cue only on real attacks).
- Studio target: the single instance for placeId 122652861404212 (Edit). Pre-check (Studio == HEAD): `WildboundBeastAnimPlan`
  8823:2528121456, `WildboundBeastAnimPlan_Test` 9025:1963586904, `WildboundBeastProxies` 23116:3065146105,
  `WildboundText` 32539:1870242275, `WildboundText_Test` 20104:313314756, `WildboundBeastsClient` 41884:3225949834,
  `WildboundBeastAnim` 6628:1692643219; `WildboundBeastWiring_Test` 41900:2169754626 (== working tree after SC7).
- RED (suites deployed first): AnimPlan 9/3, Wiring 44/5, Text 18/1 (71 passed, 9 failed).
- GREEN: first pass AnimPlan 12/0, Text 19/0, Wiring 46/3 (two existing pins: the EV-W3 model count 10 -> 11 now that
  9 proxies exist, and NB6's "no 4.5 in the client", hit by a first star height of 14.5, set to 15; plus the BW2 needle
  for the exact `drawShape` line, kept). Final: AnimPlan 12/0, Wiring 49/0, Text 19/0 (80 passed, 0 failed), no leaks,
  runner lock cleared, holder removed.
- Read-back (Studio == working tree, all compile): `ReplicatedStorage.WildboundBeastAnimPlan` 10278:4044280000,
  `StarterPlayer.StarterPlayerScripts.WildboundBeastAnim` 6757:2605243356, `ReplicatedStorage.WildboundText`
  33213:2854910699, `ServerScriptService.WildboundBeastProxies` 26841:3305354192,
  `StarterPlayer.StarterPlayerScripts.WildboundBeastsClient` 50115:1639409740, `ServerStorage.WildboundBeastAnimPlan_Test`
  12316:1001067766, `ServerStorage.WildboundText_Test` 21224:692927815, `ServerStorage.WildboundBeastWiring_Test`
  47934:2994433138. No save, no publish, no Workspace edit.
- Solo Play (lock `SC8-scuttler-client`, set from nil and cleared after; Play stopped by this step). Test-only runtime
  changes inside Play: the character's health raised to 100000 (this place deals damage), the character moved by
  `Humanoid:MoveTo`, `WildboundDash` set by the server during a feint (bait), and the real dodge sent through the
  `Stance` remote ("dodge") 0.1 s before a charge's strike. Six forced Scuttler encounters (beast:1 to beast:6): five
  ended `Timeout`, beast:6 was ended by `BeastProbe`; started 6, ended 6; counters `dodged` 2, `afflicted` 1, `errors`
  0. Observed on the client: every phase listed above except a `Charge` landing on a carrier; `Fallen` with variant
  `Crash` and with `Stumble` published on the model; a landed pulse slowed WalkSpeed 16 -> 12 and the client's
  `WildboundPulseDesaturate` appeared and was removed. No "Wildbound beasts client" warning in the console.
- Screenshots (`assets/exports/forest-kit/captures/`, untracked): `sc8-scuttler-proxy-day-desktop.jpg` (live proxy next
  to the character), and frozen client copies of the drawn tells taken the moment they appeared (night lighting):
  `sc8-scuttler-real-lane-desktop.jpg`, `sc8-scuttler-feint-outline-desktop.jpg`, `sc8-scuttler-intercept-zone-desktop.jpg`,
  `sc8-scuttler-pulse-rings-desktop.jpg`, `sc8-scuttler-fallen-stars-desktop.jpg`.
- Not checked: the bystander style (needs a second player, SC11 or the SC0.6 two-player check); "Efectos suaves" on
  (only the source contract is pinned); the escalated egg drop (no egg carried).
- Python: 1298 run, 4 failed, 28 skipped; the same other-track failures (3 economy-config export, 1 lumipol_v2 v1 blend
  hash).

## Correction (SC1-SC8 review, 2026-11-14)

The review found no blocker, high or medium finding; four low or informational items. One scoped correction, Strict
TDD (cases first, RED against the Studio modules, then GREEN).

- Finding 2 (low, fixed): the escalated second pulse carried `slow` as a number, which `landHit` ignores (it applies
  only a table), so the egg-dropping pulse did not slow. `releasePulse` now sends the Hit form `slow = { multiplier,
  seconds }` and no `slowSeconds` on the Hit. The shake already ran: `handlers.Hit` shakes (0.5) for every non-kids
  beast. Pinned in the SC6 escalation case.
- Finding 3 (low, fixed in the brain): `choosePoint` now also refuses a straight run that crosses a safe zone
  (`world.safe`, sampled every 2 studs, P included), the Pradera (`world.meadow`, optional) or a wall (`world.castLane`
  shorter than the run); it falls back to the pursuit. New SC5 case with three setups.
- Finding 4 (low, fixed): `WildboundBeastDirector` check: when a beast that fills the budget (Scuttler, 3 points) is
  active, a 0-point summoned kids beast is refused `Budget` (also forced), and Scuttler is refused `Budget` (no roll
  spent) while a kids beast is active. Two kids beasts still share the Pradera. New Director case.
- Finding 1 (info, left open): `PulseCooldownSeconds` 9 -> 5 is still the owner's decision (accept 5, or grow
  `PressureMemorySeconds` instead). No change.
- Not done, blocked by the fingerprint guard: `ServerScriptService.WildboundBeasts` (Studio 43594:3817298632, working
  tree 43288:2374956119), `StarterPlayer.StarterPlayerScripts.WildboundBeastsClient` (50158:3899946924 vs
  50115:1639409740) and `ServerStorage.WildboundBeastWiring_Test` (48022:1409714347 vs 47934:2994433138) differ from
  the repo: Studio has newer Studio-only edits by another track (a third kids beast, Gomibu, in `KIDS`, the client and
  the Wiring suite). Not overwritten, and the repo copies were left untouched. Still open there: wiring
  `world.meadow` in the beast script (so the Pradera check in the run applies live; safe zones and walls already do)
  and a desaturation for the escalated pulse on the client `Hit` handler.
- RED (Studio modules before the fix, fresh-clone runner): Scuttler 40/2 (the SC5 run case, setup 1, "no intercept
  through it: expected 0, got 1"; the SC6 escalation "the Hit form of the slow: expected table, got number"),
  Director 46/1 ("NubeGrunona while Scuttler hunts: expected Budget, got table"). Setups 2 and 3 of the SC5 case were
  not reached in RED (the case stops at its first failing setup).
- GREEN (after deploy): Scuttler 42/0, Director 47/0; also Attack 13/0, Encounters 24/0, Audience 17/0, Wiring 49/0
  (the Studio Wiring suite, against the Studio sources). No leaks; runner lock cleared.
- Runner: `tools/studio-fresh-runner.luau` lines 330-722 unchanged, wrapped as a function of FILTER, SPECS trimmed to
  the six Beast suites above (copied unchanged), one suite per FILTER.
- Deploy: pre-image of each Studio Source equal to the working file before the edit (Scuttler 26338:1753340479,
  Director 13956:3503643689, Scuttler_Test 48323:3586383435, Director_Test 43890:1644638883); applied as exact
  replacements. Read-back (Studio == working tree): `ServerScriptService.WildboundBeastScuttler` 27589:1620408176,
  `ServerScriptService.WildboundBeastDirector` 14282:2793392716, `ServerStorage.WildboundBeastScuttler_Test`
  50275:3922806828, `ServerStorage.WildboundBeastDirector_Test` 45560:2491437752. No Play, no save, no publish, no
  Workspace edit; `WildboundPlayLock` was nil and was not touched.
- Python: 1298 run, 4 failed, 28 skipped; the same other-track failures (3 economy-config export, 1 lumipol_v2 v1 blend
  hash).

## Evidence (SC9, 2026-11-15)

Route: delegated writer, no Studio (another batch was the only Studio writer). No upload, no publish, no place save.
Pattern: Caramelo CA2/CA3 (`odd/tasks/wildbound-caramelo.md`).

- Pack read as data: `Scuttler_Pack_Wildbound.zip` extracted into a new scratch folder; only the concept text, the 3D
  modelling prompt and `01_Scuttler_Concepto.png` were read; nothing in it was executed.
- Blender source `assets/blender/scuttler/build_scuttler.py`, run in the user's live Blender 5.1.2 through the MCP
  (`get_addon_status` first reported a lost connection; the next call reached Blender). It builds its own scene
  `Scuttler` from nothing; the open file's `Scene` was not touched and the file was not saved.
  - Model: low-poly, faceted insect in the Viper/Gargoyle style: maroon segmented carapace (4 back plates), raised
    thorax shield, wedge head with a dark brow, an ivory toothy grin, four amber emissive eyes, two antennas with
    glowing cream bulbs, two claw arms (dark upper arm, big carapace forearm with cream chevrons, two ivory pincer
    blades), eight jointed legs with ivory pointed feet, moss drips. 8 one-colour meshes (`Carapace`, `CarapaceDark`,
    `Chevron`, `Moss`, `Ivory`, `Mouth`, `Eye`, `Glow`), 914 vertices, 1432 triangles.
  - Size: 13.73 studs tall (antenna bulbs; Q1 12-14), 16.1 wide (feet), 18.68 long (pincer tips to tail spike); lowest
    point -0.007 (the foot tips touch the ground).
  - Axes: 1 Blender unit = 1 stud; faces -Y in Blender, so -Z in Roblox; left is +X in Blender (-X in Roblox). Root
    bone head at (0, 0, 0), on the ground between the feet.
  - Rigid skinning: every vertex has exactly one group at weight 1; the script asserts every bone owns a vertex (Root
    owns a small gem hidden in the abdomen) and that no mesh is named like a bone.
- FBX `assets/exports/scuttler/scuttler-v1.fbx` (same export settings as Tortidragon: FBX_SCALE_ALL, no leaf bones,
  armature node NULL, no baked animation). Round-trip check: re-imported into a temporary scene (removed after):
  1 armature, 43 bones, 8 meshes, 0 unskinned bones, 0 meshes named like a bone, every vertex in exactly one group,
  Root head (0, 0, 0), height 13.72.
- Previews (EEVEE, orthographic, dark background): `assets/exports/scuttler/scuttler-front.png`,
  `scuttler-side.png`, `scuttler-back.png`. Also checked with the MCP `look` tool (front, right, three-quarter, back).
- Bones (43), parents first:
  - `Root` -> `Hips` -> `Thorax` -> `Head` -> `Jaw`
  - `Head` -> `Antenna_L_01` -> `Antenna_L_02`; `Antenna_R_01` -> `Antenna_R_02`
  - `Thorax` -> `Claw_<S>_Shoulder` -> `Claw_<S>_Upper` -> `Claw_<S>_Fore` -> `Claw_<S>_PincerA`, `Claw_<S>_PincerB`
    (S = L, R)
  - `Hips` -> `Leg_<S><i>_Upper` -> `Leg_<S><i>_Lower` -> `Leg_<S><i>_Foot` (S = L, R; i = 1..4, front to back)
- Clips as data `tools/WildboundScuttlerClips.luau` (Tortidragon pattern: `Clips.BONES`, `Clips.ORDER`, `Clips.CLIPS`,
  `Clips.build(prefab, name)` -> KeyframeSequence, `Clips.IDS = {}`, `Clips.animationId`). The 17 clips, exactly
  `WildboundBeastAnimPlan.clips("Scuttler")`:

  | Clip | Length s | Loop | Notes |
  | --- | --- | --- | --- |
  | Idle | 2.4 | yes | breathing, antennas drift, jaw twitch |
  | Skitter | 0.6 | yes | alternating tripods (L1 R2 L3 R4 vs the rest), bob twice per cycle |
  | Read | 1.6 | yes | head tilts both ways, antennas sweep |
  | Intercept | 0.4 | yes | low fast skitter, claws tucked |
  | Block | 1.2 | yes | claws up and open, sway |
  | Feint | 0.9 | no | crouch and a short thorax lunge, back to rest; no marker (never registered) |
  | ChargeWindup | 1.1 | no | only ever deeper; markers TelegraphStart 0, AttackCommit 0.8 (lockLead 0.3); ends in the charge pose |
  | Charge | 0.45 | yes | head down, fast tripods; starts on the windup's last pose |
  | Snap | 1.2 | no | claws up and out, inward sweep; markers TelegraphStart 0, HitFrame 0.9 |
  | PulseCharge | 1.3 | no | rears up on the thorax, only ever higher; marker TelegraphStart 0; ends reared |
  | Pulse | 0.8 | no | scream from the reared pose (jaw -45), back to rest; marker HitFrame 0 |
  | Recover | 1.0 | no | from the charge pose, head shake, rest |
  | Stumble | 0.8 | no | from the charge pose, trips and rolls to the fallen pose |
  | Crash | 0.7 | no | from the charge pose, head slam, bounce, fallen pose |
  | Fallen | 1.6 | yes | body on the ground (Hips -4.2), legs splayed up, dazed head |
  | GetUp | 1.0 | no | fallen pose to rest |
  | Retreat | 1.0 | no | crouches and backs off, holds low while it fades |

- Suite `tests/WildboundScuttlerClips_Test.luau`, signature `(Clips, Plan)`, 11 cases: rig (43 bones, parents first,
  legs on Hips); the 17 clips (lengths, loops, ordered keys, known bones); equal to `Plan.clips("Scuttler")`; published
  ids (stays RED until the clips are published, like Tortidragon); loop seams and rest ends; the chains (windup ->
  charge -> recover/stumble/crash -> fallen -> get up; pulse charge -> pulse); markers (attack clips only, none on the
  feint); in place (Root never moves, Hips never slides, standing clips never turn Hips and the legs take its bob
  back); tripod gait in Skitter/Intercept/Charge; readable moves; `Clips.build` on a stand-in rig made from
  `Clips.BONES` (44 poses per key, pose tree, Hips offset, unknown clip refused).
- NOT RUN: the suite (no Luau runtime outside Studio, and Studio was off limits). Expected in Studio: 10/11, the
  published-ids case RED until the clips are published.
- Python: `test_studio_fresh_runner` fails only `test_every_suite_has_a_spec_or_a_skip` (the new suite has no SPECS
  yet, by instruction). On a scratch copy of `tools/`, `tests/` and `src/wildbound/` with the rows below added,
  `test_studio_fresh_runner` 15/15 OK and `test_deploy_manifest` 25/25 OK.

Rows to add (not added here: another agent is editing these files):

- `tools/deploy_manifest.py`, after the Tortidragon clips rows:
  `("tools/WildboundScuttlerClips.luau", "ServerStorage.WildboundScuttlerClips"),`
  `("tests/WildboundScuttlerClips_Test.luau", "ServerStorage.WildboundScuttlerClips_Test"),`
- `tools/test_deploy_manifest.py`, in the pinned mapping after the Tortidragon clips pins:
  `"tools/WildboundScuttlerClips.luau": "ServerStorage.WildboundScuttlerClips",`
  `"tests/WildboundScuttlerClips_Test.luau": "ServerStorage.WildboundScuttlerClips_Test",`
- `tools/studio-fresh-runner.luau`:
  `SPECS["WildboundScuttlerClips_Test"] = { "mod:WildboundScuttlerClips", "mod:WildboundBeastAnimPlan" }`

Decisions taken for the user (SC9):

- Followed the Caramelo pattern (KeyframeSequences from data, published Animation ids) as asked. The plan's section 10
  route (baked `WildboundBeastAnimScuttler` written to `Bone.Transform` by `WildboundBeastAnim.client`, no upload) is
  not built; the same `Clips.CLIPS` data can feed it later if the group publish stays blocked, as it is for CA2/CA3.
- Eight legs (`Leg_<S>1..4`), as the plan's bone list and the SC8 proxy, not the "6 legs" line of the proxy text.
- The legs hang from `Hips`, not `Thorax`, so the pulse's rear-up (Thorax pitch) and leaning never lift a planted foot;
  only the fall clips turn or drop Hips.
- The source script is the rig's source of truth; no `.blend` was saved (the plan's
  `assets/bestias_rig/scuttler/scuttler_rig.blend` is not made). Rerunning the script rebuilds the scene.
- The suite takes no prefab argument yet (the runner's `inst:` token needs an existing instance); the build case uses
  a stand-in rig. SC10 adds the imported prefab as a third argument and its `inst:` token.
- `Proxies.adopt` wants a `Root` BasePart, while the Tortidragon-style import yields a `RootPart` carrying the `Root`
  bone. Left for SC10: rename on assembly or teach the adopt path the RootPart; the clip pose tree uses the
  PrimaryPart's name either way.

Pending Studio steps (each needs its own go-ahead; uploads and publishing need the user's explicit approval):

1. Register the two files (rows above), deploy them, run `WildboundScuttlerClips_Test` fresh: expect 10/11 (ids RED).
2. Import `assets/exports/scuttler/scuttler-v1.fbx` (Model upload, SC10, approval) and build the prefab
   `ServerStorage.WildboundAssets.Scuttler` (pivot on Root at the ground, faces -Z, anchored root, all 43 bones kept).
3. Build the 17 KeyframeSequences with `Clips.build(prefab, name)` and publish them to the group that owns the universe
   (465694015); the Caramelo clips are blocked on the same group permission. Fill `Clips.IDS`, rerun: 11/11.
4. Adopt the model (`Proxies.adopt`, the Root naming above) and a solo Play check that every phase plays its clip.

## Next step

1. Two-player Studio check (Test > Clients and Servers, 2 players), SC0.6.
2. SC9 Studio steps (see "Evidence (SC9)": register the rows, run the suite, import, build and publish the clips).
3. Commit the SC0 server merge, SC1 to SC7 (not committed yet).

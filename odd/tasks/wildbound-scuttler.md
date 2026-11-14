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

- [ ] SC0 Shared beast visibility (all beasts except La Silueta) -- code complete and GREEN; server deploy and the
  two-player check pending (see evidence)
  - [x] SC0.1 Tests first: `WildboundBeastAudience_Test` (12 cases) and 3 SC0 cases in `WildboundBeastWiring_Test`;
    RED observed against Studio
  - [x] SC0.2 `Config.AUDIENCE` and the pure `WildboundBeastAudience` module; deployed and read back
  - [x] SC0.3 Client quiet bystander rendering; deployed and read back
  - [ ] SC0.4 Server fan-out deployed to Studio -- BLOCKED on porting the teammate's Studio Patio code
    (`PatioDentro` roll guard, `PatioBestia` BindableFunction) into the repo file; Studio `WildboundBeasts` is still
    37564:2137873840 and was not overwritten. The repo has the change (with the correction); GREEN ran on a merge of
    the repo edits onto a temporary clone of the Studio script
  - [x] SC0.5 Deploy manifest and pin
  - [ ] SC0.6 Two-player Studio check -- NOT VERIFIED (solo Play only; second recipient simulated)
  - [x] SC0.7 Review correction (findings 1-6): Pradera and safe-zone viewers, cap hysteresis, bystander render delay,
    late-joiner replay plus Stalk/Hunt as visual, idempotent soften, membership committed after the spawn send; 5 new
    Audience behaviour cases and 1 Wiring case; RED then GREEN; module, client and both suites deployed and read back
    (server: repo only, see SC0.4). Not committed
- [ ] SC1 Config entry and director pins; verify a live press moves `WildboundDash`
- [ ] SC2 `Attack.afflict`
- [ ] SC3 Brain skeleton (Spawn, Stalk, committed charge, Recovery, Castigo y caida, Disengage)
- [ ] SC4 Finta de caza
- [ ] SC5 Ruta predictiva
- [ ] SC6 Pulso de panico
- [ ] SC7 Beast script wiring
- [ ] SC8 Client and proxy
- [ ] SC9 Blender rig and baked clips (no upload)
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

## Next step

1. The owner (or the teammate who owns the training yard) reconciles `WildboundBeasts.server.luau`: port the Studio
   `PatioDentro` / `PatioBestia` additions into the repo, then deploy the repo file (the 15 SC0 edits apply cleanly to
   the Studio version, verified in memory) and read it back.
2. `tools/studio-fresh-runner.luau` (another writer's file) already lists
   `SPECS["WildboundBeastAudience_Test"]`; `test_studio_fresh_runner.py` passes (7/7).
3. Two-player Studio check (Test > Clients and Servers, 2 players) after the server deploy; then SC1.

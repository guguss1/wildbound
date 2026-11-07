# P0 world rules and Silueta

Status: locally authored source and contract tests; **not deployed, compiled or playtested**. The user deferred blocked Studio execution. This does not change global strict TDD or authorize an MCP permission bypass. Native review is disabled/unmanaged.

## Authority and installation boundary

- `src/wildbound/WildboundWorldRules.luau`: pure clock, zones, territory, ability authorization and attack predicates.
- `src/wildbound/WildboundWorld.server.luau`: server-owned guardian, cooldowns, shared clock, LOS, damage and lifecycle.
- Deploy both beside the inventory `WildboundServer` in ServerScriptService only when authorized testing resumes. A separate world client owns input, companion visuals and local atmosphere.
- Requires Workspace `WildboundP0` and ReplicatedStorage `WildboundNetwork`. Inventory owns the network folder and its server-only `Eligibility` BindableFunction. The callback validates actual registered collection membership and equipped UID for `LumipolPulse`; a Player attribute is never proof.
- World startup refuses existing `WildboundWorldRuntime`, `WorldAction` or `WorldState`. Cleanup removes only this script's own objects; it never deletes the map, inventory or collection.

## Shared time and regions

One `GetServerTimeNow()` origin controls a repeating 1,200-second cycle: Day 600, Dusk 120, Night 360, Dawn 120 seconds. Device wall clocks and client messages cannot advance it. The sky-clock interpolation remains continuous through midnight. Negative/non-finite elapsed values normalize to the start of Day.

Fog rectangle: x [-45, 165], z [-165, 35], inclusive. Camp is a 35-stud radius around (-140, 140); shelter is a 22-stud radius around (105, 125). These are horizontal gameplay regions, not a claim about visual geometry. Camp/shelter remain safe in every phase. Shelter does not extract or bank loot.

Only fog has increased Night detection (28 to 38 studs) and pursuit speed (6 to 8 studs/second). No global hostile multiplier, reward multiplier, rare variant, resource or RNG table is implemented. `nightRewardsEnabled` is explicitly false. The existing egg outcome remains deterministic Lumipol.

## Guardian behavior

`WildboundP0.WildboundWorldRuntime.Silueta` is one original primitive model with a weak outline, ground cue and readable amber alert/attack cue. It does **not** use camera/gaze signals and is not the Vigia. No external art or sound IDs are required.

`Patrol -> Alert (1.2s) -> Hunt -> Telegraph (1.4s) -> Retreat (at least 3s) -> Patrol`.

- Home: (0, -85). Patrol is a small fixed diamond. Territory is the intersection of the fog rectangle and an 80-stud home leash. Targets must stay in that territory, alive and visible; chase range is 65 studs, maximum chase time 10 seconds. Leaving the region, losing LOS, dying or disconnecting causes retreat.
- Startup begins in non-attacking Retreat for at least 3 seconds, including a first deployment with players already connected. Alert and attack telegraph still run afterwards; no startup damage or teleport hit is allowed. Actual initial replication/spawn clearance remains a runtime test, not a proven result.
- Telegraph is stationary. At impact, current-character, alive, height, LOS, territory, range (7 studs) and attack cooldown (4s) are revalidated server-side. Damage is 20. No lunge, teleport hit or touch damage exists. A Heartbeat stall over 0.5 seconds cancels an active wind-up/chase instead of delivering catch-up damage.
- Movement uses bounded 0.2-second anchored flat-floor steering, not Humanoid navigation or a validated navmesh. Current decorative props are non-colliding. Added walls, slopes and new collision require a navigation design and real traversal tests; do not claim they work.
- Pursuit speed is below a standard 16-stud/second character's walk speed; escape depends on actual runtime movement and must be tested. No character walk-speed setting is changed here.
- If Workspace streaming is enabled, guardian damage is **disabled**, recorded as runtime `DamageEnabled` and payload `damageEnabled`. A trusted loaded-guardian receipt/visibility protocol is pending; do not turn off streaming or damage invisible clients as a workaround.

## Free counterplay and Lumipol

All alive players can use the free flashlight. Its server cooldown is 12 seconds. Registered/equipped Lumipol grants a radial pulse with a 30-second cooldown. Both reveal the shared outline for 4 seconds, up to 55 studs, with server LOS. Flashlight also requires the server character's forward vector to face within the configured dot-product threshold (0.2); the client never supplies camera direction, target or position. Pulse is radial and does not require facing.

An authorized miss consumes cooldown and reports a miss; dead/unregistered uses do not. Cooldowns are per player and ability and survive character reset within the server. Rejoin starts a new session, consistent with the current session-only prototype. Overlapping reveals take `max(existingExpiry, now + 4)`, never add durations. Reveal does not kill, stun or freeze the guardian; escaping remains necessary. A revealed silhouette is shared, without altering another player's inventory or cooldown.

## Network contract

World owns two RemoteEvents under the existing `WildboundNetwork`:

```text
WorldAction:FireServer(action)
action = "RequestSnapshot" | "Flashlight" | "LumipolPulse"
```

Exactly one string argument; extra arguments, unknown actions and client target IDs are ignored. Known-key rate limits drop requests faster than 0.3 seconds overall or one second per action. Invalid traffic is not reflected into reply spam.

`WorldState.OnClientEvent(payload)` receives the complete latest state, not a delta:

```text
serverTime, cycleElapsed, phase, phaseRemaining, nextPhaseAt, clockTime
isFog, isSafe, alive, hasLumipol
flashlightReadyAt, pulseReadyAt
guardian = {state, distance, threat, revealedUntil, telegraphEndsAt}
nightRewardsEnabled=false, damageEnabled
action, ok, notice
```

Absolute times use `Workspace:GetServerTimeNow()` seconds; `cycleElapsed`/`phaseRemaining` are durations. `distance=-1` means no live character. Phases are `Day`, `Dusk`, `Night`, `Dawn`. Periodic full updates use `action="WorldTick"`, once/second/player; accepted bounded requests get immediate full replies. Clients subscribe before requesting a snapshot and tolerate model replication arriving after the network events. Guardian attributes are `RevealedUntil`, `State`, `TelegraphEndsAt`.

## Verification still required

`tests/WildboundWorldRules_Test.luau` is a function receiving a fresh Rules module result and returning `{passed, failed, messages}`. Cases cover clock boundaries/NaN, safe/fog/territory, day/night limits, ability ownership/LOS/range/cooldown and attack predicates. These cases are **authored, not executed**.

Before acceptance: compile all modules; run fresh-clone rules tests; verify one and two clients at phase boundaries, shared reveal expiry, spam/malformed payloads, real LOS/facing, current-character replacement, death/disconnect cleanup, safe-region escapes, attack telegraph at low FPS, initial spawn clearance, off-volume cues, low-graphics/mobile controls and a streaming-enabled non-damaging run. Confirm no damage from an unseen guardian. Measure performance on an actual device before claiming a frame budget. No persistence or reward-rarity claims are made by this unit.

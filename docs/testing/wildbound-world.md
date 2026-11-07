# Wildbound P0 world integration and verification guide

**Status: deployed and run in Studio on 11-05; world contracts passed and solo Play was observed (`odd/tasks/wildbound-first-playable.md:111-112`, `:119`, `:131-133`). Damage stays off under streaming, the damaging strike remains BLOCKED, and full co-op and mobile checks remain PENDING.** Source inspection is not compilation or gameplay evidence. Do not use alternate execution surfaces, APIs or permission workarounds, and do not bypass the Studio MCP permission gate.

## Source-to-Explorer mapping (future, manual only)

| Local source | Intended Explorer destination | Notes |
| --- | --- | --- |
| `src/wildbound/WildboundWorldRules.luau` | `ServerScriptService.WildboundWorldRules` (`ModuleScript`) | Pure server rules; WorldServer requires this exact sibling name. |
| `src/wildbound/WildboundWorld.server.luau` | `ServerScriptService.WildboundWorld` (`Script`) | Server-owned clock, Silueta, ability validation, and world remotes. |
| `src/wildbound/WildboundWorld.client.luau` | `StarterPlayer.StarterPlayerScripts.WildboundWorldClient` (`LocalScript`) | Client controls, notices, local atmosphere, and local-only companion visual. |

This is a manual source mapping, not Rojo configuration. Keep existing `WildboundServer`/`WildboundClient` (inventory) and Rescue scripts. Deploy `WildboundWorldRules` beside `WildboundWorld`, and `WildboundWorldClient` only after the server contract is present. WorldServer waits for `Workspace.WildboundP0`, the existing `ReplicatedStorage.WildboundNetwork` folder, and its `Eligibility` `BindableFunction`; if any is missing, it warns and exits. The inventory server owns that callback and must verify a registered, currently equipped Lumipol from private server state. Never replace it with client attributes, UI state, or a client-supplied UID.

## Current world network contract

- WorldServer creates `WorldAction` and `WorldState` `RemoteEvent`s inside the existing `WildboundNetwork`; duplicate startup refuses to overwrite either remote or `WildboundWorldRuntime`.
- Client sends exactly one string action: `RequestSnapshot`, `Flashlight`, or `LumipolPulse`. Extra arguments, unknown players/actions, and malformed calls are ignored. The client does not submit targets, distance, eligibility, time, or outcomes.
- Server sends a complete state replacement to that player: `{ serverTime, cycleElapsed, phase, phaseRemaining, nextPhaseAt, clockTime, isFog, isSafe, alive, hasLumipol, flashlightReadyAt, pulseReadyAt, guardian = { state, distance, threat, revealedUntil, telegraphEndsAt }, nightRewardsEnabled = false, damageEnabled, action, ok, notice }`. Times are based on `Workspace:GetServerTimeNow()`. Snapshots are sent about once per second and after accepted actions; per-action/rate limits bound requests.
- Flashlight is free. The server applies a 12-second cooldown; registered/equipped Lumipol pulse has a 30-second cooldown. Both are range/visibility checked; flashlight also requires facing. A valid use can miss, so the client cannot force a reveal. A reveal lasts 4 seconds; repeated valid reveals use `max(existingExpiry, now + 4)`, not additive time.
- The session clock is server-shared: 720 seconds total (Day 360, Dusk 72, Night 216, Dawn 72) since M5.7, starting at a random non-Night point. Night affects guardian speed/detection only in the fog zone. `nightRewardsEnabled` is `true` since M5.3: it only lets Nightbloom nodes spawn (docs/mechanics/wildbound-economy-p0.md).
- Silueta has bounded territory/chase, a visible warning/telegraph, server-side target and strike checks, and no gaze mechanic. Its safe-zone exclusion is rule-based. Zone coordinates are code geometry, **not verified placed map parts**; reconcile them with the actual generated map before deployment. Do not infer or move any existing spawn/landmark from this guide.
- `damageEnabled` is false when `Workspace.StreamingEnabled` is true because no trustworthy client-loaded receipt handshake exists. Do not enable damage or claim unseen-target safety without a separately authorized, tested solution. This limitation does not block reporting the local source as authored, but it blocks claiming safe runtime damage behavior.
- Client presentation is not authority: local lighting is restored on UI teardown; reduced effects are available; danger/telegraph notices are visual/textual as well as state-driven. Companion visual is client-only and appears only while fresh server state reports alive + Lumipol. This is not a server-spawned pet or verified visual effect.

## Future checks (only after authorization and permission gate)

Run through the authorized Studio workflow, after verifying the exact instance/place and receiving confirmation for any Studio edit. Do not perform this checklist now. Use fresh clones for pure-module tests where needed; preserve the existing legacy harness and all unrelated objects.

1. **Pure rules:** test exact phase boundaries/wrap, invalid/NaN/infinite inputs, fog/safe/territory edges, target range, chase/strike cooldown, telegraph timing, and free/eligible ability rules. Confirm failed/unauthorized actions do not consume cooldown; valid misses do; concurrent reveal expiry never extends.
2. **Integration startup:** missing map/network/Eligibility fails closed; duplicate scripts do not replace existing instances/remotes; cleanup removes only this script's remotes/runtime. Verify inventory Eligibility rejects unregistered, unequipped, stale, or foreign player state and accepts only registered + equipped Lumipol.
3. **Remote abuse:** unknown/malformed/extra-argument actions, spam, distant/dead player, respawn, occlusion, wrong facing, and non-finite geometry cannot mutate eligibility, time, or guardian outcomes. Confirm server-derived snapshots and bounded response frequency.
4. **Co-op and lifecycle:** with two clients, compare phase/time; verify a successful reveal is shared with the world guardian for both clients; race ability actions; ensure cooldown survives death/respawn and departing targets are cleared. Verify Lumipol eligibility and cooldown remain per-player even though the reveal itself is shared. Recheck safe zones and transitions at the zone edges.
5. **Counterplay/readability:** flashlight works without a pet and remains the free path; Lumipol pulse requires actual registered/equipped state. Observe warning before any strike, movement/escape space, camp safety, and no gaze-dependent behavior. Repeat with audio muted and reduced effects enabled.
6. **Streaming and damage:** with streaming on, observe `damageEnabled=false` and verify no damage. With streaming off only, verify visible, alive, in-range, out-of-safe-zone strike after telegraph and cooldown; also test moving behind cover/leaving range during wind-up. Do not infer a pass from source inspection.
7. **Devices/visuals:** inspect narrow portrait, wide portrait/landscape, keyboard, and touch input with the inventory open/closed. Verify local Lighting/Atmosphere restoration on teardown, fresh-state timeout disables actions, and no UI overlap with Roblox touch controls. Device usability/performance needs actual emulator/device evidence.

Record PASS/FAIL/BLOCKED, steps, observed results, and evidence; leave every unrun item pending. Current compilation, Studio integration, runtime, device, multiplayer, and persistence status is **UNVERIFIED**. This world unit adds no DataStore persistence or night reward odds; publishing and monetization are not authorized here.

## Reference boundary

Implementation facts above come from current local world source and the separate inventory integration contract. `resources/skill-packs/wildbound-codex-complete-v0.4.2/knowledge/wildbound/{MONSTERS.md,NIGHT_CYCLE.md,P0_TASKS.md,PROTOTIPO_BOSQUE_NIEBLA_P0.md}` are exploratory design references; their example timings, odds, and other proposed features do not establish implementation or permission. `C:/Users/Jesus/Documents/Roblox/roblox-codex-starter/knowledge/INDEX.md` and its linked video note are design hypotheses, not technical requirements.

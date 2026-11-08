# Fair strike decision record

Unit M4.1, wave W2b. Records decisions D2 and D6.

**Status: built in wave W6 (M4.2 to M4.7) on 2026-11-07, shipped with `damageMode = "off"` and an empty place list. Agent-tested in Studio only; no person or phone has played it.** All numbers are hypotheses. **Damage stays off outside a private test.** Turning it on anywhere else needs separate explicit approval (`odd/tasks/wildbound-waves.md:20`). Streaming stays on; option F is not used.

### W6 build notes

Code: `WildboundFlags`, `WildboundFairStrike`, `WildboundAmbush` (pure, with contracts), wired in `WildboundWorld.server.luau`, `WildboundServer.server.luau`, both clients and `WildboundState`. Counters are `FS_*` attributes on `ServerStorage.WildboundTelemetry`.

| Where this document proved wrong or incomplete | What was built |
| --- | --- |
| `DWELL_RADIUS` from `workspace.StreamingMinRadius`: a game script cannot read it ("lacking capability PluginOrOpenCloud"). Fail-closed then cancelled every honest strike | Delivery C (D-C4): the radius is configured as `WildboundFlags.streamingMinRadius = 64`, and a Studio contract compares it with `Workspace.StreamingMinRadius`. The old 64 fallback is gone; a missing value fails the gate closed |
| Counter identity listed every `cancel.*` | `cancel.duplicate` counts a second resolution of an already counted attack, so it is outside the identity |
| Gate 2 (`cancel.stall`) | Unreachable in practice: the existing 0.5 s Heartbeat rule cancels first, as `attack.cancelledEarly`. Kept as defense in depth |
| Gates 1, 4 and 7 | Contract-proven only. Normal flow resolves once, closes the attack on character change, and always warns at issue |
| A target who dies mid-telegraph | Closes as a prior life, so its late id counts `ack.priorLife` |
| Disconnect keeps mark and K in the D10 hold | No hold exists yet; mark and K go with the player, and drops are removed |
| Ambush never picks the current anchor | It can re-pick the anchor it already patrols around when standing at a patrol corner; harmless, counted as `ambush.moved` |

Play results (desktop Studio, damage off unless noted; private mode was a Play-only override, verified gone by hash):

| Check | Result |
| --- | --- |
| Shadow strike, all gates pass | PASS, `shadow.wouldStrike` |
| Dwell, geometry, guardian (mode flipped by a Play probe), not ready, ack missing, ack late, no liveness | PASS, each its own counter |
| K: two withheld acks cancel, third lands as unacked | PASS |
| Forged, extra argument, duplicate, 4 per second limit, wrong owner (second client), prior life | PASS |
| Warning reaches only the target | PASS, second client received nothing |
| Attack chip held until resolution | PASS, 1.49 s for a 1.4 s telegraph |
| Private mode: mark to 35 with drop, owner pickup, pin at 35 with regeneration on, rest clears at 5 s, drop lost at 30 s, second strike defeats, loss summary, tap to close | PASS |
| Ambush relocation | PASS, 56.8 studs, players 174 studs away; 30-minute run (FS-67) not run |
| MT-2 | `PersistentLoaded` fires on the server and was seen on one of two clients |
| MT-3, MT-4 | Server can read `GameplayPaused` and `GetNetworkPing()` (0.7 ms locally) |
| MT-10 | Preload of the guardian and four clips 0.3 to 0.9 s, no failures; whether clips are truly cached is unverified |
| MT-1, MT-6, MT-7, MT-11 to MT-14, FS-62 to FS-69, Network Simulator | Not run: need far or late joins, phones, a muted client, latency or people. Warning lead on a local client was 1.37 s |

## Choices worth your review

| # | Choice taken | Tradeoff |
| --- | --- | --- |
| 1 | After K free cancels, a strike can land with no on-time acknowledgement, but only if the client is otherwise alive on the network | **This narrows the roadmap's "zero strikes without a delivered warning".** Without it, ignoring acknowledgements means immunity. Such strikes are counted, and the exit test requires zero of them in honest-network scenes |
| 2 | Damage is off by default **even if streaming is turned off**. Today the opposite holds | Closes a silent path to damage |
| 3 | The mark is a server counter, not Humanoid health | Health is only the visible bar. Avoids depending on the default regeneration script, which is unverified here |
| 4 | The mark clears only by resting at camp or the shelter | Stricter than D6's "no regeneration in fog": also none on the way home. Simpler to explain |
| 5 | The dropped item lands near the player, owner-only, recoverable for 30 s | A false positive stays cheap, as D2 intends. It may be too cheap; falsifier below |
| 6 | Ambush is an instant reposition with no fade, at least 40 studs from every player | Simplest. May be seen as a pop from far away; capture check MT-14 |

## Context

Verified from source.

| Fact | Source |
| --- | --- |
| `damageEnabled = not workspace.StreamingEnabled`, so turning streaming off turns damage on | `src/wildbound/WildboundWorld.server.luau:32` |
| Comment states no trustworthy client-loaded receipt exists | `WildboundWorld.server.luau:31` |
| Telegraph is global state; the snapshot has no target identity and goes out at 1 Hz | `WildboundWorld.server.luau:188-197`, `:369` |
| Impact revalidates current character, range 7, LOS, height, territory, cooldown | `WildboundWorld.server.luau:263-276`; `src/wildbound/WildboundWorldRules.luau:107-113` |
| Retarget happens only in Hunt, never during Telegraph | `WildboundWorld.server.luau:230-262`, `:263` |
| Damage per strike 20; after every resolution Silueta retreats for at least 3 s | `WildboundWorldRules.luau:14`; `WildboundWorld.server.luau:152-155`, `:219-220` |
| A chase over 10 s or lost target cancels even during Telegraph | `WildboundWorld.server.luau:222-224` |
| A Heartbeat stall over 0.5 s cancels Alert, Hunt or Telegraph | `WildboundWorld.server.luau:357` |
| `WorldAction` accepts exactly one argument, limits 0.3 s overall and 1 s per action | `WildboundWorld.server.luau:294-302` |
| Defeat goes through `Died` or character replacement, deduped by `life:<generation>` | `src/wildbound/WildboundServer.server.luau:218-235`; `src/wildbound/WildboundState.luau:164-185` |
| Silueta art template sits in `ServerStorage`, which clients cannot read | `WildboundWorld.server.luau:72-76` |
| Studio checks 5, 6 and 13 remain BLOCKED | `docs/testing/silueta-encounter-phase-report.md:21-22`, `:29` |
| Cold Telegraph sample differed by about 0.41 s, server 0.9167 against client 0.5042 | `docs/testing/silueta-animation-runtime.md:15` |

**Roblox facts, as read on 2026-11-07 and recorded in `docs/wildbound-roadmap.md:192-201`, not re-read for this document:** Persistent models arrive after join and never stream out. Minimum radius default 64 has top priority. A remote can arrive before the instance it refers to. `PersistentLoaded` takes a player parameter. `RequestStreamAroundAsync` failure behavior is undocumented.

**The problem has three layers (roadmap section 2).** The instance reached the client. The assets loaded. The player noticed. The server cannot prove the last two.

## Decision

| Layer | ID | What it does | Trust |
| --- | --- | --- | --- |
| Persistent model | A | Guardian model set to Persistent, so it should exist on every client | Documented; runtime case unmeasured |
| Dwell gate | B | Target must have been inside a safe radius of Silueta for N seconds before the warning | Server-measured |
| Warning and acknowledgement | C | Target-only warning with an attack ID; client acknowledges; missing acknowledgement cancels, at most K times per life | Client-reported, bounded |
| Staged strike | D | First strike marks and drops one bag item; second defeats | Limits the cost of a false positive |
| Camp preload | E | Client preloads meshes and clips and reports ready, before the expedition | Client-reported, bounded |

All behind `damageMode`, default `off`.

| Candidate | Status | Reason |
| --- | --- | --- |
| F, streaming off | **Not used** | D2. Would remain a user decision if measurements demand it |
| G, `RequestStreamAroundAsync` | Not a gate. Optional aid only if MT-6 shows need | Yields; failure undocumented |
| H, integrity pause rule | Not a gate | Server readability unknown (MT-3). Promote only with evidence |
| X, client reports hits | **Rejected** | Exploitable |

## `damageMode`

**Delivery C, 2026-11-07 (decisions H5 and D-C4):** the user approved real damage for the unpublished test place `122652861404212` only. `WildboundFlags` now ships `damageMode = "private"` with that one place listed; every other place stays shadow. All fair-strike gates stay. Before the first paid trip home (one registered creature, any banked material or any Ember) a strike resolves as shadow for that player (D-C3, `FairStrike.lethal`). **Publishing with this flag on needs its own, separate approval.**

New server-only module `WildboundFlags` in the server folder. Clients cannot read or write it. No attribute is ever read back for a decision.

```luau
return { damageMode = "off", privateTestPlaceIds = {} }  -- "off" | "private"
```

| `damageMode` | `game.PlaceId` in list | Effect |
| --- | --- | --- |
| `off` (default) | Any | **Shadow mode.** All gates run and counters count. No mark, drop, health change or defeat |
| `private` | No | Treated as `off`, plus counter `flagMisconfigured` |
| `private` | Yes | Real strikes |

The list ships empty. The test place from `docs/testing/silueta-encounter-phase-report.md:7` is added only when the user confirms the target and approves the private test. `runtime:SetAttribute("DamageEnabled", ...)` and payload `damageEnabled` report the result for display only. **Changes existing behavior:** replaces `WildboundWorld.server.luau:32`.

Shadow mode lets M4.8 measure false cancels and warning delivery with damage off. A shadow pass is evidence about gates only, never about feel.

## Attack record

```luau
type Attack = { attackId: string, userId: number, life: Instance, guardianGeneration: number,
    issuedAt: number, endsAt: number, ackDeadline: number, warnSentAt: number?,
    ackedAt: number?, dwellOkAtWarn: boolean, stalled: boolean, resolved: boolean }

type LifeRecord = { life: Instance, marks: number, kUsed: number, nearSince: number?,
    lastPulseAt: number, clientReady: boolean, restSince: number?, markedAt: number? }
```

`attackId` is an opaque server string of at most 64 bytes, never reused. `life` is the character Instance, held on the server only, matching the existing `targetLife` (`WildboundWorld.server.luau:86`). `guardianGeneration` increments when a guardian model is created or replaced. Only one attack exists at a time, because Silueta is one state machine.

## Sequence

| Time | Server | Target client |
| --- | --- | --- |
| Enter Telegraph | Create attack. Compute `dwellOkAtWarn`. Fire `AttackWarning` in the same step. Set existing `TelegraphEndsAt` | |
| About half a round trip later | | Show warning text. On next rendered frame, fire `AttackAck(attackId)` |
| Ack arrives | Accept if all binding checks pass and `now <= ackDeadline` | |
| `endsAt`, next 0.2 s step | Run gates. Apply effect or cancel. Retreat either way. Set `lastAttackAt` | Receives `AttackResolved` |

## Gate order

Run once at impact, in this exact order. First failure stops. **Every failure means no strike, one counter increment, Silueta retreats normally.** Server-measured gates come first so a client-budgeted cancel is spent only on a strike that would otherwise land.

| # | Gate | Passes when | Counter on failure | Source of truth |
| --- | --- | --- | --- | --- |
| 1 | Already resolved | `attack.resolved == false`, then set true | `cancel.duplicate` | Server |
| 2 | Server health | `attack.stalled == false` (no step gap over 0.5 s since issue) | `cancel.stall` | Server |
| 3 | Guardian | `guardianGeneration` matches, model parented, `ModelStreamingMode` is Persistent | `cancel.guardian` | Server |
| 4 | Target binding | Player present, `character == attack.life`, alive | `cancel.binding` | Server |
| 5 | Geometry | Existing `targetContext(target, ATTACK_RANGE)` and `Rules.canStrike` | `cancel.geometry` | Server |
| 6 | Dwell | `attack.dwellOkAtWarn == true` | `cancel.dwell` | Server |
| 7 | Warning sent | `attack.warnSentAt ~= nil` and at least 1.2 s before now | `cancel.warning` | Server |
| 8 | Client ready | `clientReady == true`, or budget table below | `cancel.notReady` | Client, budgeted |
| 9 | Acknowledged | `ackedAt <= ackDeadline`, or budget table below | `cancel.ackMissing`, `cancel.ackLate` | Client, budgeted |
| 10 | Mode | `damageMode` effective is `private`. Otherwise record `shadow.wouldStrike` and stop | | Server |

Passing all ten increments `strike.executed`.

### Counters

Stored server-only, as attributes on a `ServerStorage.WildboundTelemetry` folder (server storage does not replicate; well-known, recheck). Also: `attack.issued`, `attack.cancelledEarly` (chase limit or lost target during Telegraph), `ack.forged`, `ack.wrongOwner`, `ack.duplicate`, `ack.priorLife`, `ack.late`, `strike.unacked`, `cancel.noLiveness`, `flagMisconfigured`, `effect.failed`, `ambush.moved`, `ambush.skipped`. Identity check for the harness: `attack.issued == strike.executed + shadow.wouldStrike + all cancel.* + attack.cancelledEarly`.

### Dwell

| Name | Value | Note |
| --- | --- | --- |
| `DWELL_RADIUS` | `min(workspace.StreamingMinRadius, 64)`, read at start. Unreadable means gate always fails | Place value unread (MT-5). Full 3D distance |
| `DWELL_SECONDS` | 3.0 | Checked at Telegraph entry |

Each 0.2 s step, for each player: inside radius and `nearSince == nil` sets it; outside clears it. Character change clears it. Ambush relocation clears it for everyone.

**Calculated:** a player sprinting at Silueta from 64 studs needs at least 2.25 s to reach detection range 28, then Alert 1.2 s, so natural Telegraph entry comes at 3.45 s or later. So 3.0 s should not cancel ordinary encounters. It catches join-in-range, relocation and teleport cases. The minimum radius is a loading priority, not an arrival time (`docs/wildbound-roadmap.md:208`), so this is a guard and not proof.

### Acknowledgement rule with K

| Name | Value |
| --- | --- |
| `K` | 2, per life |
| `ACK_DEADLINE` | `issuedAt + 1.0 s` |
| `LIVENESS_WINDOW` | 3 s |

**Why 1.0 s (calculated):** an acknowledgement arriving by 1.0 s implies one-way delay of about 0.5 s, so the warning stood about 0.9 s before impact. Reaction plus a 0.2 s step out needs less than that for an attentive player. Falsifier in MT-12.

Evaluated only after gates 1 to 7 pass. Gates 8 and 9 share one budget, and a single attack spends at most one K.

| Ready and on-time ack? | `kUsed < K` | Client alive (`now - lastPulseAt <= 3`) | Result |
| --- | --- | --- | --- |
| Both yes | Any | Any | Continue to gate 10 |
| Either no | Yes | Any | **Cancel.** `kUsed += 1` |
| Either no | No | Yes | Continue to gate 10. `strike.unacked += 1`, logged with attack ID |
| Either no | No | No | **Cancel.** `cancel.noLiveness += 1`. K not spent |

**Liveness** is a new `FieldPulse` remote, fired by the client once per second while alive in fog. Its only purpose is telling "client is dead on the network" from "client withheld this acknowledgement". It proves nothing else.

**What an acknowledgement proves:** the client's script ran with the attack ID. **Never that the player saw anything.** Sight is settled only by people, in M4 exit and F1.

**Residual exploit, accepted for P0:** a cheat that blocks all of Wildbound's remotes reaches `cancel.noLiveness` and is not struck. There is no PvP or leaderboard, so it only spoils that player's own game, and it loses every remote-driven action including abilities and crafting. Watch the counter.

### Binding cases

`AttackAck(attackId)` is a dedicated RemoteEvent, because `WorldAction` rejects arguments and its limiter could drop an acknowledgement sent just after a flashlight use (`WildboundWorld.server.luau:295`, `:301`). Limit: 4 per second per player, excess dropped silently, no reply.

| Case | Server sees | Result | Counter |
| --- | --- | --- | --- |
| On time | Current ID, right sender, current life | `ackedAt = now` | None |
| Forged | Unknown or non-string ID, or over 64 bytes | Ignored | `ack.forged` |
| Other player's | Current ID, wrong sender | Ignored, no effect on target | `ack.wrongOwner` |
| Late | Right ID after 1.0 s, before or after impact | Stays missing; first arrival logged | `ack.late` |
| Duplicate | Right ID, already acked | First stands | `ack.duplicate` |
| Prior life | ID from an attack on an old character | Attack was closed at character change. Keep the last 8 closed IDs only to classify this; no effect | `ack.priorLife` |
| Prior guardian | ID from an earlier generation | Same | `ack.forged` |
| Ack before warning could arrive | Under 5 ms after issue | Accepted. Timing adds nothing provable, and a cheat can already ack at once | None |
| Extra arguments | Any | Ignored, same pattern as `WildboundWorld.server.luau:295` | `ack.forged` |

A pre-emptive cheat that always acks at once gains nothing, since acknowledging only permits the strike.

## Remotes

All under `ReplicatedStorage.WildboundNetwork`, created by the world script before the runtime is published. Add to the duplicate-start guard at `WildboundWorld.server.luau:20`.

| Direction | Name | Payload | Rules |
| --- | --- | --- | --- |
| Server to target | `AttackWarning` | `{attackId, issuedAt, endsAt}` | Target only. M2.2 also creates this; build it once with the ID from the start |
| Server to target | `AttackResolved` | `{attackId, outcome = "Marked"|"Defeated"|"Missed", notice, dropped?}` | `Missed` covers every cancel, without naming the gate |
| Client to server | `AttackAck` | `attackId` | Above |
| Client to server | `ClientReady` | `persistentLoaded: boolean, assetsLoaded: boolean` | Types checked. Limit once per 2 s. May only move from false to true within a life |
| Client to server | `FieldPulse` | None | At most 2 per second accepted |

**Client handling order for a warning:** subscribe before any snapshot request. Do not look up the guardian model first; a remote can arrive before an instance. Text goes up immediately and needs no instance. Warning stays visible with inventory open and muted (depends on M2.3).

## Staged strike

Implements D6.

| Marks | Effect | Notice |
| --- | --- | --- |
| 0 to 1 | Set mark. Drop one bag item. `Health = MARKED_HEALTH` (35). Cancel any capture session | "Silueta marked you! Next hit defeats you. Dropped: Lumipol egg. Grab it within 30 s. Rest at camp or shelter to clear the mark." |
| 1 to defeat | `Humanoid:TakeDamage(Health)`. Verify health at 0, else `effect.failed` | Loss summary below |

**Which item drops:** the newest pending item that is not protected. Protected items never drop. No eligible item: mark only. Materials never drop (`wildbound-economy-p0.md`).

**Dropped item.** `State:dropForStrike(key, attackId)` moves the entry from `pending` to `dropped`, idempotent per `attackId`. A world model appears 4 studs from the player toward Silueta, clamped to the map.

| Rule | Value |
| --- | --- |
| Who can pick it up | Only the owner (D4). Others see it and get "This belongs to another player." |
| Pickup | Prompt, 0.25 s hold, 10 studs, same as `prompt()` at `WildboundServer.server.luau:88-95` |
| Lifetime | 30 s, then lost, reported in a notice |
| Bag full at pickup | `BackpackFull`; stays on the ground until expiry |
| Owner defeated or character replaced | Lost, listed in the loss summary |
| Owner disconnects | Follows the D10 hold (`wildbound-economy-p0.md`). Removed from the world, restored at their position if they return in time |

**Cross-script effect.** The world script calls a new server-only `StrikeEffect` BindableFunction in `WildboundNetwork`, the pattern of `Eligibility` at `WildboundServer.server.luau:35-47`. It is wrapped in `pcall`; failure leaves the mark, skips the drop, increments `effect.failed`.

**Calculated lethality**, still target at distance `h` from the patrol center, LOS clear:

| Moment | Day | Night |
| --- | --- | --- |
| First strike, detected at the range edge | 6.1 s | 6.5 s |
| First strike, detected at 20 studs | 4.8 s | 4.2 s |
| Second strike after the first, `h = 20` | 7.8 s | 7.2 s |
| Second strike after the first, `h = 27` | 9.3 s | 8.4 s |
| Defeat from detection at 20 studs, `h = 20` | 12.6 s | 11.4 s |

Compare about 40 s under today's numbers (`docs/wildbound-roadmap.md:153`). Moving still escapes: the guardian steps at most 1.6 studs per 0.2 s step and stops as soon as it is within 7, so a walker clears range in well under 0.5 s. The danger is in standing still by choice.

## Regeneration rule

| Rule | Detail |
| --- | --- |
| While marked, anywhere outside a safe zone | No recovery. Each 0.2 s step sets `Health = min(Health, 35)` if the player is marked, which also defeats default regeneration if it exists here (MT-8) |
| Clearing | `Rules.zone` safe true for 5 s continuously: mark cleared, `Health = MaxHealth`, notice "You rested. The mark is gone." Leaving resets the timer |
| Not marked | Health stays full. No other damage source exists in `src/wildbound` |
| New life | Mark and K reset |
| Reset to clear a mark | Costs a defeat (`WildboundServer.server.luau:218-220`), so it gains nothing |

## Defeat flow

| Step | Owner | Detail |
| --- | --- | --- |
| 1 | World | Second strike, `TakeDamage`. Mark record closed |
| 2 | Inventory | Existing `Died` handler, `life:<generation>` operation, no change to dedupe (`WildboundServer.server.luau:228-235`) |
| 3 | State | `defeat` runs in order: protected survivor by seal or totem, remove other pending, remove dropped, apply material loss, close expedition. Currency, registered pets and banked eggs untouched |
| 4 | Inventory | `State` remote with action `Defeat` and a `lossSummary` |
| 5 | Client | Full-screen summary before respawn, large text, tap to close, no timer pressure. Reads as text muted |
| 6 | Engine | Default respawn, then existing pivot to camp (`WildboundServer.server.luau:245`) |

```luau
lossSummary = { operationId: string, lostItems: { {uid: string, kind: string, species: string} },
    savedItem: {uid: string, kind: string, species: string}?, materialsLost: { [string]: number },
    kept = { registered: number, bankedEggs: number, ember: number, bankedMaterials: number } }
```

**Disconnect** is not a defeat (D10). Open attack closes with `attack.cancelledEarly`. The mark and K are retained in the hold record, so leaving does not clear them.

## Chase pass timing (2026-11-08)

User: "attacks faster". Decision CP-D1 keeps every gate above and shortens the numbers: `Rules.TELEGRAPH_SECONDS` 1.4 to 0.9, `WARNING_LEAD` 1.2 to 0.8, `ATTACK_COOLDOWN` 4 to 2.5, and a live quarry still in sight is hunted again at once instead of the guardian going home (recovery 3 to 1.5 s when the hunt ends). The 0.9 s wind-up stays above the 0.35 s floor of a visible and audible tell; the acknowledgement must now arrive within the 0.9 s telegraph. The earlier "floor 1.2 s" below (MT-11) is superseded; MT-11 (warning to first readable frame per client) is still not measured. Two strikes still kill (mark, then defeat). A strike needs the target inside the territory even while a hunt follows its quarry out to the 100-stud pursuit leash (CP-D3).

## Ambush relocation

M4.7. Silueta quietly moves its patrol to a place near an objective, on a server timer. **It never reads camera, gaze, look direction or who can see it.** It is not El Vigia.

New pure module `WildboundAmbush`, inputs by value:

```luau
type AmbushInput = { now: number, nextAt: number, mode: string, roll: number,
    players: { {x: number, z: number} },
    anchors: { {id: string, x: number, z: number, weight: number, active: boolean} },
    guardianX: number, guardianZ: number, lastHuntAt: number, anyPlayerInFog: boolean }
Ambush.pick(input) -> { move: boolean, anchorId: string?, reason: string }
```

| Rule | Value |
| --- | --- |
| Timer | Next attempt after a uniform 90 to 150 s, or 60 to 90 s at Night. Retry after 15 s if skipped |
| Allowed when | `mode == "Patrol"`, some player in fog, no hunt in the last 20 s |
| Player distance | Every live player at least 40 studs from both the guardian's current position and the anchor. 40 exceeds night detection 38 |
| After moving | `guardian:PivotTo`. Patrol diamond recenters on the anchor. Retreat returns there, not to home. `acquireBlockedUntil = now + 3`. Every dwell timer cleared |
| Territory | Leash stays relative to `Rules.HOME_X`, `HOME_Z`; anchors are inside it; patrol stays clamped by `Rules.clampTerritory` |
| Weights | Filter to active anchors, then `p = w / sum(w)`. Totem holders within 60 studs double that anchor's weight before normalizing |

| Anchor | XZ | Beside | Home dist | Base weight |
| --- | --- | --- | --- | --- |
| `Home` | (0, -85) | Ruin | 0 | 30 |
| `NestSide` | (40, -125) | `E1`, `L2` | 56.6 | 20 |
| `RuinEast` | (55, -38) | `L3` | 72.4 | 15 |
| `RuinWest` | (-30, -45) | `L1` | 50.0 | 15 |
| `WestHollow` | (-40, -110) | `E2` | 47.2 | 10 |
| `SouthGrove` | (40, -140) | `E3` | 67.9 | 10 |

Anchor coordinates are checked for territory by calculation only. Guardian movement is anchored and ignores collision (`WildboundWorld.server.luau:173`), so props do not block it. Client movement smoothing from M2.6 must snap, not glide, on a jump this large. **Compatible with the rule "no teleport hit"** (`docs/mechanics/wildbound-world.md:29`): relocation is at least 40 studs away, followed by a 3 s block, a fresh dwell and a full telegraph.

**Contract proving no gaze input:** `AmbushInput` contains no orientation. Test passes identical inputs plus extra fields `lookVector`, `camera`, `gaze`, with varied values, and asserts equal output. A source check asserts `WildboundAmbush.luau` contains no `Camera`, `LookVector`, `CFrame` or `workspace`. Flashlight facing at `WildboundWorld.server.luau:313` stays outside this module.

## Changes to existing behavior

| Where | Now | Proposed |
| --- | --- | --- |
| `WildboundWorld.server.luau:32` | Streaming off enables damage | `damageMode`, default off in every configuration |
| `:37`, guardian model | Default streaming | Persistent, set before parenting; fallback location from MT-1 |
| `:256-258`, enter Telegraph | Global only | Also creates attack and fires target warning |
| `:270-272`, impact | `TakeDamage(20)` | Gate order and staged strike. `Rules.DAMAGE` becomes unused; `Rules.canStrike` unchanged and its contracts stay |
| `:219`, Retreat | Returns to fixed home | Returns to current anchor |
| `WildboundWorld.client.luau:142-143` | Warning from shared snapshot | Warning from `AttackWarning` (with M2.3) |
| `WildboundState:defeat` | Pending only | Also dropped items, materials, summary |
| `camp` | No preload step | Client preloads and reports |

**Preload detail.** The template lives in `ServerStorage`, so a client must preload from the replicated guardian model and from Animation instances built with the four IDs in `docs/testing/silueta-animation-runtime.md:5`. Timeout 20 s, then report `assetsLoaded=false`. Whether `ContentProvider:PreloadAsync` preloads animation clips is unverified (MT-10). Target of M4.5: re-measure the 0.41 s cold mismatch.

## Measurement tasks

Documentation does not settle these. None are assumed in the design beyond the fail-closed defaults stated.

| ID | Question | Method | If the answer is bad |
| --- | --- | --- | --- |
| MT-1 | Does Persistent work for a runtime-created model nested under the `WildboundP0` Model? | Cold join, far join, read instance on client each frame | Parent guardian elsewhere, or build it in the map |
| MT-2 | Does `Workspace.PersistentLoaded` fire on the server? On the client? | Log both | Client-report only, already assumed |
| MT-3 | Can the server read `Player.GameplayPaused`? | Force a pause, log | H stays out |
| MT-4 | Is `Player:GetNetworkPing()` usable from the server? | Log against simulator settings | Keep `FieldPulse` |
| MT-5 | What are this place's streaming radii and integrity mode? | Read properties | `DWELL_RADIUS` follows |
| MT-6 | Delay until a Part inside the minimum radius exists on a client after moving in | Instrumented walk, three network levels, phone | Raise `DWELL_SECONDS`. Add G only as an aid |
| MT-7 | Phone behavior under memory pressure: does the Persistent model stay? | Real low-end phone | User decision on F |
| MT-8 | Does default Health regeneration exist in this place? Default WalkSpeed 16? | Read in Play | Pin already handles it |
| MT-9 | `TakeDamage` under a ForceField; respawn delay | Read in Play | Use `Health = 0` |
| MT-10 | Does preloading cover animation clips? | Cold join timing | Treat as mesh only |
| MT-11 | Time from `AttackWarning` issue to first readable frame, per client | Client logs, three levels, muted | Lengthen telegraph, floor 1.2 s from `tests/WildboundWorldRules_Test.luau:190` |
| MT-12 | Acknowledgement arrival distribution | Shadow mode logs | Adjust `ACK_DEADLINE`, K |
| MT-13 | How often does a warning arrive before the guardian instance? | Client logs | Text is independent, so expected harmless |
| MT-14 | Is the relocation visible from 40 studs at day, in fog? | Capture | Add a fade |

## Hypotheses and what would falsify them

| Hypothesis | Falsified by |
| --- | --- |
| The gates catch unfair strikes without catching fair ones | `cancel.*` above about 10% of `attack.issued` on a healthy network, or any tester says "I died without warning" |
| K=2 is enough for honest players | `strike.unacked` above 0 at the 500 ms level in honest scenes. Then raise K or extend the deadline |
| 1.0 s ack deadline leaves a usable warning | Testers report late warnings at 500 ms, or MT-11 shows under 0.7 s readable |
| Two strikes feel fair and threatening | No near-miss in 20 minutes, or defeats testers call random |
| A cheap drop matters | Over 90% of drops are recovered with no recorded tension: move farther, or shorten life |
| Marks push players home | Marked players stay out at the same rate as unmarked ones |
| Ambush adds surprise, not unfairness | Testers call it cheating, or `strike.executed` within 10 s of a relocation is common |
| Default-off shadow mode reflects real behavior | Numbers change much once damage is on in private |

## M4 test matrix

**Pure contracts, RED first.**

| ID | Case | Expected |
| --- | --- | --- |
| FS-01 | Each of gates 1 to 9 failing alone | No strike; exactly that counter |
| FS-02 | Two gates failing together | Earlier gate's counter only |
| FS-03 | `damageMode="off"`, all gates pass | `shadow.wouldStrike`, no effect |
| FS-04 | `private` with empty list | Treated as off, `flagMisconfigured` |
| FS-05 | `StreamingEnabled` false with `damageMode="off"` | No effect |
| FS-06 | Counter identity after a random run | Holds |
| FS-10 | On-time ack | Accepted |
| FS-11 | Forged: unknown, wrong type, 65 bytes, nil, table | Ignored, `ack.forged`, no error |
| FS-12 | Another player's ack | No effect, `ack.wrongOwner` |
| FS-13 | Late at 1.01 s, then at 2.0 s | Missing at impact |
| FS-14 | Duplicate | One accept |
| FS-15 | Prior life; prior guardian generation | Ignored; new attack unaffected |
| FS-16 | Ack after attack resolved | Ignored |
| FS-20 | Missing ack, K=2: first and second attacks | Cancel, `kUsed` 1, then 2 |
| FS-21 | Third attack, live | Strike allowed, `strike.unacked` |
| FS-22 | Third attack, no pulse | Cancel, `cancel.noLiveness`, K unchanged |
| FS-23 | Not ready and missing ack on one attack | Spends one K |
| FS-24 | New life | `kUsed` and marks 0 |
| FS-25 | Server gate fails with missing ack | K not spent |
| FS-30 | Dwell: 2.9 s, 3.0 s, left and returned, character change, relocation | False, true, reset, reset, reset |
| FS-31 | Unreadable radius | Gate fails |
| FS-40 | First strike with 0, 1, 3 items, with all protected | Mark only, newest drops, newest drops, mark only |
| FS-41 | Same attack ID twice to `dropForStrike` | One drop |
| FS-42 | Second strike | Defeat; one operation |
| FS-43 | Dropped: owner reclaims; other tries; expiry; owner defeated | Back in bag; refused; lost; lost |
| FS-44 | Health pin while marked; rest 4.9 s then 5.0 s; leave at 3 s | Pinned; clears at 5.0; resets |
| FS-45 | Defeat keeps currency, registered, banked | Unchanged |
| FS-50 | Ambush with `mode` other than Patrol, no one in fog, recent hunt, player at 39.9 | No move |
| FS-51 | Ambush with orientation fields added and varied | Identical output |
| FS-52 | Source check on `WildboundAmbush.luau` | No `Camera`, `LookVector`, `CFrame`, `workspace` |
| FS-53 | Weights: normalized; inactive removed; all inactive | Sums to 1; excluded; no move |
| FS-54 | Same seed and inputs | Same result |

**Studio, Network Simulator, phones.** Run in shadow mode first; damage only in the confirmed private place, after approval.

Network levels (settings are test choices, to record as actually configured): **L0** none, **L1** 150 ms with 1% loss, **L2** 500 ms with 5% loss.

| ID | Maps to | Case | Levels | Pass |
| --- | --- | --- | --- | --- |
| FS-60 | N1, check 5 | Ordinary telegraph on a still target; B watches; inventory open; muted; Reduced on | L0 to L2 | Only target gets warning; readable before impact; real strike applies in private |
| FS-61 | Check 6 | Real walking escape during telegraph | L0 to L2 | No strike; causal, since damage is on in private |
| FS-62 | Check 13 | Genuinely muted client through supported controls | L0 | Warning, mark, drop, loss summary all readable |
| FS-63 | N2 | Cold join, late join, stream out and back | L0 to L2 | No strike without gates; record instance, asset and warning times separately |
| FS-64 | N3 | Reset and disconnect during telegraph, second player present | L0 to L2 | Old attack does not touch new life or other player |
| FS-65 | N4 | Delayed, absent, duplicated, forged, out-of-order, prior-life acks, through a private test probe, approved separately | L0, L2 | Per binding table. `strike.unacked` is 0 in honest scenes |
| FS-66 | M4.2 | MT-1 to MT-10 | Varies | Recorded answer |
| FS-67 | M4.7 | Ambush over 30 minutes, cameras moving and still | L0 | No difference traceable to camera; distances held |
| FS-68 | B18 | Delete and restore guardian generation, only if authorized | L0 | No stale attack effect |
| FS-69 | Exit | Two people, real phones, real connection, 20 minutes | Real | At least one defeat or near miss; zero "I died without warning" |

**Exit test, from `docs/wildbound-roadmap.md:303`, with one clarification flagged in choice 1:** checks 5, 6 and 13 move from BLOCKED to PASS with a genuinely muted client. Across N4 scenes on an honest network, zero strikes without a delivered warning, read as `strike.unacked == 0`. Scenes that deliberately withhold acknowledgements exercise K instead. Agents never mark human gates passed. Damage stays private until this passes, and beyond the private place needs separate approval.

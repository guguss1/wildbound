# Lumipol capture design

Unit M3.1, wave W4a. Implements decision D3, and D4 and D14 where they touch capture.

**Status: built and run in Studio Play (wave W5, 2026-11-07): the rule (M3.2), the server wiring (M3.3), the touch screen (M3.4) and the slots, wild behavior and egg carry cost (M3.5). Every number is still a hypothesis. No person has played it, no real phone or real network was used, and tapping on a phone profile is BLOCKED (see [M3.3 to M3.5 build notes](#m33-to-m35-build-notes)).** Written 2026-11-07 from source and the layout plan. Where a build note disagrees with an earlier section, the build note wins.

## Choices worth your review

| # | Choice taken | Why | Alternative rejected |
| --- | --- | --- | --- |
| 1 | The ring is **in the world, on the ground**, not on screen. You stand in it and step once when it drifts off you | One thumb is the movement thumb. The server reads your position, so the client sends no skill data and nothing about skill can be forged. No sub-frame timing | On-screen ring tracked by the thumb: the skill signal would be client-reported, and the thumb covers what it tracks. D3 reads either way, so this is an interpretation |
| 2 | Tap once to start, no held button | A held button plus the movement stick is two thumbs, which breaks D3 | Hold to fill |
| 3 | The safe clearing slot pays **once per player**, for the first capture | Keeps the quick first catch and removes the free farm (B4) | Permanently open safe slot |
| 4 | A Silueta strike resolving on you ends the capture **even while damage is off** | M3 exposure can then be tested before M4 exits | Interrupt only when damage is on |
| 5 | One capture slot (L4) sits in fog but outside Silueta's leash | A no-Silueta route must exist for players who fail repeatedly. The economy pays less for it (`wildbound-economy-p0.md`) | All fog slots inside territory |

## Verified facts

| Fact | Source |
| --- | --- |
| Creature capture today is the same 0.25 s prompt hold as any pickup | `src/wildbound/WildboundServer.server.luau:91`, `:173` |
| Pickup requires alive and at most 10 studs, and claims without yielding | `src/wildbound/WildboundState.luau:90`, `:99-100` |
| Encounter record is `{kind, claimed}`; IDs retire and are never reused | `WildboundState.luau:74`, `:78-84` |
| Bag capacity is 3 | `WildboundState.luau:4` |
| Existing creature slot respawns in 20 s | `WildboundServer.server.luau:184` |
| Lumipol marker is (-95, 75), 79.1 studs from camp, outside the fog rectangle | `tools/build-wildbound-p0-map.luau:99`; `src/wildbound/WildboundWorldRules.luau:51` |
| Egg marker is now (35, -99) | `tools/build-wildbound-p0-map.luau:19`, `:101` |
| Silueta can only target inside fog, outside safe zones, within 80 studs of (0, -85) | `WildboundWorldRules.luau:55-58`, `:100-105` |
| Silueta speed 6, or 8 at fog night; detection 28, or 38 | `WildboundWorldRules.luau:77-78` |
| Alert 1.2 s, telegraph 1.4 s, attack range 7, gameplay step 0.2 s | `src/wildbound/WildboundWorld.server.luau:212`; `WildboundWorldRules.luau:7`, `:9`; `WildboundWorld.server.luau:354` |
| Action remote takes one action and one string, whitelisted, 80 ms and 300 ms limits | `WildboundServer.server.luau:64-71`, `:192-200` |
| Characters are bound by generation; replacement is a defeat boundary | `WildboundServer.server.luau:218-223` |
| Prompts have never been run on touch | `docs/testing/wildbound-next-verification.md:32-36` |

Reference pack advice used as a hypothesis only: timing wide, opaque session token, animations only reflect the server (`resources/skill-packs/wildbound-codex-complete-v0.4.2/knowledge/wildbound/CAPTURE_HATCH_BOND.md:11-14`). Shared knowledge note: an early reward and a short route to first action are a hypothesis (`roblox-codex-starter/knowledge/youtube/DLWYPHMGfMs/notes.md:15`).

## What the player does

1. Walk up to a Lumipol. It stops and watches. Tap **Calm**.
2. A bright ring appears on the ground, centered on you. A meter fills while you stand inside it.
3. The ring drifts slowly around the Lumipol. After about 3 s its edge reaches you. Step back in once.
4. The meter fills in about 5 s total. The Lumipol goes in your bag, not safe until extracted.

Standing still fails. Running around fails. Waiting too long fails. The ring is the danger: for those 5 s you are a still target inside Silueta's territory.

## Numbers

All hypotheses. Pure constants in `WildboundCapture.luau`.

| Name | Value | Meaning |
| --- | --- | --- |
| `START_RANGE` | 10 studs | Same as existing pickup |
| `CALM_REQUIRED` | 4.5 s | Meter target |
| `RING_RADIUS_VISIBLE` | 4.5 studs | Drawn radius |
| `RING_RADIUS_SERVER` | 5.0 studs | Tested radius. The 0.5 margin absorbs replication lag |
| `RING_SPEED` | 1.5 studs/s | Linear drift along the orbit |
| `ORBIT_MIN`, `ORBIT_MAX` | 4, 9 studs | Clamp on player-to-Lumipol distance at start |
| `STILL_LIMIT` | 1.0 stud per 0.2 s sample (5 studs/s) | Faster than this pauses the meter |
| `OUTSIDE_DRAIN` | 0.5 per s | Meter loss outside the ring |
| `OUTSIDE_LIMIT` | 2.5 s | Continuous time outside before failure |
| `TIME_LIMIT` | 12 s | Whole session |
| `TOO_FAR` | 18 studs horizontal, or 8 vertical from start | Hard cancel |
| `JUMP_LIMIT` | 8 studs per sample (40 studs/s) | Implausible movement: hard cancel |
| `SAMPLE` | 0.2 s | Matches the guardian step. Elapsed per sample is capped at 0.2 |
| `RETRY_COOLDOWN` | 6 s | Same player, same encounter, after any session end |
| `SPOOK_SECONDS` | 2 s | Nobody can start while it flees |
| `MAX_FAILS` | 3 | One player's failures on one encounter before that player gets `LONG_COOLDOWN`. The Lumipol does not leave (see the W5 audit row below) |
| `LONG_COOLDOWN` | 45 s | Wait after a player's third failure on one encounter. Same player, same encounter, no one else |

**Calculated check of D3's 4 to 6 s.** With orbit radius `r`, angular speed `w = 1.5 / r`, the ring center is `2 r sin(w t / 2)` from a player who never moves. It reaches the visible radius at about 3.0 s (r=9) to 3.2 s (r=4), and the server radius at about 3.4 s to 3.6 s. So standing still fills at most about 3.6 of 4.5 and then fails with `LeftRing` near 6 s. One 3-stud step at 16 studs/s costs one paused sample. Best case is about 4.7 s, and a late step about 5.5 s.

## Ring position

Pure function, shared by server and client, so no position stream is needed.

```text
lumipol = encounter XZ at start (frozen for the session)
orbit   = clamp(distance(player, lumipol), ORBIT_MIN, ORBIT_MAX)
a0      = bearing from lumipol to player
w       = dir * RING_SPEED / orbit      -- dir is +1 or -1, chosen by server RNG at start
center(t) = lumipol + orbit * (cos(a0 + w t), sin(a0 + w t))
```

If the player starts closer than `ORBIT_MIN`, the ring starts up to 4 studs off them, still inside 5.0 at `t=0` because the clamp offset is below 4. The server treats `t=0` as inside.

## States

**Session:** `Active -> Completed | Failed | Cancelled`. No resume. A token is dead once its session ends.

**Lumipol:** `Wander -> Curious -> Reserved -> Captured`, or `Reserved -> Spooked -> Wander`.

| Lumipol state | Enter when | Behavior | Prompt |
| --- | --- | --- | --- |
| `Wander` | Spawn, or spook ends | Walks at 2 studs/s to random points within 6 studs of the slot center, pauses 2 to 5 s. Server `PivotTo`, 0.2 s step | On |
| `Curious` | Any live player within 12 studs | Stops and turns toward the nearest player | On |
| `Reserved` | Session starts | Frozen, faces the player, small "listening" pose when art exists | Off |
| `Spooked` | Session fails or is cancelled | Flees 8 to 12 studs at 10 studs/s, staying within 10 studs of slot center | Off for `SPOOK_SECONDS` |
| `Captured` | Session completes | Model removed, encounter retired | Gone |

Lumipol has no reaction to Silueta in P0. It does not flee from approach, because keyboard players cannot walk slowly and a stealth approach would punish them. Movement is anchored and non-colliding, so kit collision does not affect it (`WildboundServer.server.luau:141`). Choppy movement risk B16 applies; smoothing belongs to M2.6.

## Start validation

Run in this order inside the prompt's `Triggered` handler, with no yield between the checks and the reservation. The client sends no encounter ID: the prompt's owner closure holds it, the same pattern as today (`WildboundServer.server.luau:175-178`).

| Order | Check | Refusal code |
| --- | --- | --- |
| 1 | Prompt enabled, on this body, model in runtime | Silent |
| 2 | Rate limit `allowed(player, "CaptureStart")` | Silent |
| 3 | Player has no active session | `AlreadyCapturing` |
| 4 | Alive, current character, distance at most 10, from `context()` | `InvalidContext` |
| 5 | Encounter exists and is not claimed | `InvalidEncounter`, `AlreadyClaimed` |
| 6 | Encounter not reserved, not spooked | `Reserved` |
| 7 | Player's retry time has passed for this encounter | `RetryWait` |
| 8 | Slot eligibility (first-capture rule below) | `FirstCaptureOnly`, `FirstCapturePending` |
| 9 | Bag has room | `BackpackFull` |
| 10 | Collection below limit | `CollectionFull` |
| 11 | Reserve encounter, create session, push `CaptureState` | |

## Sample step

Every 0.2 s, for each active session, in this order. First match ends it.

1. Character generation changed: `Defeated`. Player leaving is handled in `PlayerRemoving`, not here.
2. `context()` not alive: `Defeated`.
3. Encounter no longer reserved by this token: `Lost`. Should never happen; increments `captureAnomaly`.
4. Horizontal distance to Lumipol over 18, vertical over 8, or sample displacement over 8: `TooFar`.
5. Impact notice received from the guardian for this player since last sample: `Struck`.
6. `now >= deadline`: `TimedOut`.
7. Compute `elapsed = min(now - lastSample, 0.2)`, `inside`, and `moving` from displacement.
8. Inside and not moving: `calm += elapsed`, `outsideFor = 0`.
9. Inside and moving: meter holds, `outsideFor = 0`.
10. Outside: `calm = max(0, calm - 0.5 * elapsed)`, `outsideFor += elapsed`. If `outsideFor >= 2.5`: `LeftRing`.
11. If `calm >= 4.5`: complete. Recheck alive, bag room and collection limit, then `State:completeCapture`. On refusal, fail with that reason and do not grant.

A server stall over 0.5 s pushes `deadline` forward by the stall length, once per stall, so the server's hitch cannot time out a player. It adds no calm because `elapsed` is capped.

## How a session ends

The notice is the failure reason a player should be able to repeat back. Text is authoritative, with no color or sound dependency.

| Code | Trigger | Text shown | Lumipol after | Spooks? |
| --- | --- | --- | --- | --- |
| `Completed` | Meter full | "Caught! Lumipol is in your bag. Extract at camp to keep it." | Captured | No |
| `LeftRing` | Outside 2.5 s | "You left the ring. Step back in when it drifts." | Flees | Yes |
| `TimedOut` | 12 s passed | "Too restless. Stand still inside the ring." | Flees | Yes |
| `TooFar` | Distance or jump | "You moved too far from the Lumipol." | Flees | Yes |
| `Struck` | Silueta strike resolved on you | "Silueta struck you. The Lumipol fled." | Flees | Yes |
| `Defeated` | Died or character replaced | "You were defeated. The Lumipol fled." | Flees | Yes |
| `Cancelled` | Player tapped Stop | "You stopped. The Lumipol backed away." | Flees | Yes |
| `Disconnected` | Player left the server | None | Released, no spook | No |

Other start refusals use `reply()` notices: `Reserved` "Another player is calming this Lumipol.", `RetryWait` "It is still wary. Try again in a few seconds.", `BackpackFull` existing text (`WildboundServer.server.luau:52`), `FirstCaptureOnly` "This one is too shy now. Look for Lumipols in the fog.", `FirstCapturePending` "Extract the Lumipol you are carrying first."

## Data shapes

```luau
type CaptureConfig = { calmRequired: number, ringRadiusServer: number, ringSpeed: number,
    orbitMin: number, orbitMax: number, stillLimitPerSample: number, outsideDrain: number,
    outsideLimit: number, timeLimit: number, tooFarH: number, tooFarV: number, jumpLimitPerSample: number,
    retryCooldown: number, maxFails: number }

type CaptureSession = { token: string, playerKey: string | number, encounterId: string,
    life: number, startedAt: number, deadline: number, lastSample: number,
    lumipolX: number, lumipolZ: number, startY: number, orbit: number, a0: number, w: number,
    calm: number, outsideFor: number, lastX: number, lastZ: number, struck: boolean,
    outcome: string? }

type Observation = { alive: boolean, life: number, x: number, y: number, z: number, now: number }

-- WildboundCapture, pure and synchronous, no services, no RNG, no clock. Server supplies token, dir, now.
Capture.new(config) -> capture
capture:begin(playerKey, encounterId, life, token, dir, lumipolX, lumipolZ, obs) -> (ok, session | reason)
capture:sample(token, obs) -> { outcome: string?, calm: number, inside: boolean, moving: boolean }
capture:notifyStruck(playerKey) -> boolean
capture:cancel(token, playerKey) -> (ok, reason)   -- wrong owner or stale token returns false
capture:drop(playerKey) -> token?                  -- PlayerRemoving
Capture.ringCenter(session, t) -> (x, z)
```

`WildboundState` additions. Existing `pickup` stays for eggs and **refuses `Creature` with `CaptureRequired`**, so an adapter bug cannot grant a free catch.

```luau
State:reserveEncounter(key, id, token, alive, distance) -> (ok, reason)
State:releaseEncounter(id, token) -> ok            -- only the matching token can release
State:completeCapture(key, id, token, alive, tier) -> (ok, uid | reason)  -- claims, grants, clears reservation, no yield
-- encounters[id] gains reservedBy, reservedToken
-- pending entry gains riskTier = "Safe" | "Fog" | "Territory"
```

## Network

| Direction | Name | Payload | Rules |
| --- | --- | --- | --- |
| Client to server | Prompt `Triggered` on Lumipol | None | Engine-provided player. Recheck all of Start validation |
| Client to server | `Action:FireServer("CaptureCancel", token)` | Token, at most 128 bytes | Add to whitelist at `WildboundServer.server.luau:194`. Wrong owner or stale token is ignored silently |
| Server to client | New RemoteEvent `CaptureState` under `WildboundNetwork` | Below | Only to the session owner |

```luau
{ token = string, phase = "Active"|"Completed"|"Failed"|"Cancelled", reason = string?, notice = string,
  serverNow = number, deadline = number, calm = number, calmRequired = number,
  inside = boolean, moving = boolean, outsideFor = number, outsideLimit = number,
  ring = { lumipolX = number, lumipolZ = number, y = number, orbit = number, a0 = number,
           w = number, startedAt = number, radius = number }?,
  retryAt = number? }
```

Pushed at session start, at every sample while active (5 Hz, one player, at most about 60 messages per session), and once at the end with a full `State` snapshot. No client field influences any outcome: the client reports nothing about the session, so there is nothing to forge. Character position is client-simulated (well-known Roblox behavior, not re-verified here), so a cheat could auto-walk the ring. That gives no reward beyond what a skilled player earns, and the session still takes 4.5 s of real exposure.

## Race and reservation

| Case | Result |
| --- | --- |
| Two players tap the same Lumipol | Handlers run one at a time. The first reserves, the second gets `Reserved`. Only tested by C1-style real two-client run |
| Winner fails | Lumipol spooks 2 s, then anyone may start. Winner waits 6 s |
| One player keeps restarting to hold it | At most 12 s reserved in every 18 s, and that player's third failure on it earns that player a 45 s wait. The Lumipol stays for everyone else. Other slots scale by player count |
| Winner completes as loser's tap arrives | Loser gets `AlreadyClaimed` or `InvalidEncounter` |
| Strike and completion in the same frame | Whichever runs first wins. If completion ran first, the new item is in the bag and the strike rule applies normally |
| Stuck reservation | Watchdog: any reservation older than `TIME_LIMIT + 1` is force-released and increments `captureWatchdog`. Exit test expects 0 |

**Reservation is always released by:** completion, any failure, PlayerRemoving, character change, encounter retire. Each path has a contract.

## Leaving and reconnecting

Follows D10. **Capture never resumes.**

| Event | Result |
| --- | --- |
| Player leaves mid-session | No grant. Reservation released in `PlayerRemoving`, before `state:removePlayer` at `WildboundServer.server.luau:263`. Lumipol returns to `Wander` with no flee |
| Same player rejoins | New token if they try again. Old token matches nothing |
| Client lag spike under 2.5 s | Position stops updating on the server, so the player reads as still. Meter continues only if they are inside. Accepted: this helps a lagging honest player |
| `CaptureState` not received for 1 s | Client shows "Waiting for server..." and keeps the last ring. It claims nothing |

Today's server discards the profile on leaving, so pending loot cannot survive to expire (`WildboundServer.server.luau:263`). The D10 hold is specified in `wildbound-economy-p0.md` and depends on it.

## Touch UI flow

Pure presentation. New `WildboundCapture.client.luau` or a section of the world client, built with the same `make` helper. Not hidden by inventory, because opening inventory is blocked during a session.

| Step | Screen | Input |
| --- | --- | --- |
| Near Lumipol | Default `ProximityPrompt` "Calm · Lumipol". Touch use is unverified (M3.4 tests it) | One tap |
| Active | Bottom-center panel above the ability buttons, at least 300 x 90 px: fill bar, one short line of text, Stop button at least 64 x 64 px | Movement stick only |
| Inside, still | Bar fills. "Stay still..." | None |
| Ring edge within 1 stud | Line reads "Step this way" with an arrow rotated from camera toward ring center | One short move |
| Moving too fast | "Slow down" and a pause icon on the bar | Release the stick |
| Outside | "Back into the ring" and a 2.5 s countdown drawn on the bar | Move |
| Result | Large text for 3 s, plus a bag icon on success | None |

**No sub-frame timing:** the smallest meaningful interval is the 0.2 s sample, the ring takes about 3 s to reach you, and you have 2.5 s to return.

**Client ring:** a local non-colliding, non-queryable ring on the ground at `center(t)` using `GetServerTimeNow()`, redrawn every frame. It needs no replicated instance, so streaming cannot hide it. Exact drawing primitive is left to M3.4; readability at fog night is unverified.

**Muted and reduced effects:** no cue depends on sound or color.

| Signal | Non-color, non-sound form |
| --- | --- |
| In ring or out | Text line, plus ring stroke solid when inside and dashed when outside |
| Meter | Bar length |
| Direction to step | Arrow shape |
| Reduced effects on | Ring does not pulse. Text is unchanged |
| Warning during capture | The attack warning from M2.3 stays visible above the capture panel. Capture must not cover it |

Inventory: `Action` requests for `Equip`, `Hatch` and `Protect` are unchanged, but the client disables the inventory button during a session.

## Spawn slots

Coordinates are checked against `assets/maps/forest-layout/forest-layout-v1.json` by script, using its solid footprints. **That plan is not verified in play**, and trunk collision is undecided (M1.4). Recheck in M3.5. "Patrol" is the share of the home patrol loop within detection range, ignoring line of sight, so it is a worst case.

| Slot | XZ | Zone | Home dist | Open radius | Patrol day / night | Risk tier |
| --- | --- | --- | --- | --- | --- | --- |
| `S0a` | (-95, 75) | Outside fog, existing marker | 186 | 9.9 | 0 / 0 | Safe, first capture only |
| `S0b` | (-112, 92) | Outside fog | 210 | 20.8 | 0 / 0 | Safe, first capture only |
| `L1` | (-10, -60) | Territory | 26.9 | 12.7 | 46% / 83% | Territory |
| `L2` | (30, -105) | Territory, by the nest | 36.1 | 9.8 | 25% / 50% | Territory |
| `L3` | (65, -60) | Territory edge | 69.6 | 10.1 | 0 / 0 until ambush moves the patrol | Territory |
| `L4` | (110, 5) | Fog, outside leash | 142.1 | 18.6 | 0 / 0 | Fog |

Eggs use the same reservation-free pickup as today, at new slots:

| Slot | XZ | Zone | Home dist | Patrol day / night |
| --- | --- | --- | --- | --- |
| `E1` | (35, -99) | Nest, territory. Verified marker | 37.7 | 18% / 46% (`odd/tasks/fog-forest-visual-kit.md:15`) |
| `E2` | (-38, -85) | Territory | 38.0 | 17% / 42% |
| `E3` | (60, -125) | Territory | 72.1 | 0 / 0 |

**Per D4, slots scale by connected player count:**

| Players | `S0` active | `L` active | Egg active | Respawn |
| --- | --- | --- | --- | --- |
| 1 | `S0a` | 2 | `E1` | `S0` 8 s, `L` 45 s, eggs 60 s |
| 2 | `S0a` | 3 | `E1`, `E2` | Same |
| 3 to 4 | `S0a`, `S0b` | 4 | All 3 | Same |
| 5 or more | `S0a`, `S0b` | 4 | All 3 | `L` 30 s, eggs 40 s |

Place max players has not been read. Active `L` slots are picked by the server's spawn pipeline (M5.4), with at least one Territory slot always active. Encounter IDs keep advancing and are never reused, as today.

**First-capture rule.** `S0` slots accept a start only if the player has no registered creature (`FirstCaptureOnly`) and no creature in the bag (`FirstCapturePending`). Defeat clears the bag, so a player who lost their first catch can try again. This changes existing behavior: the clearing Lumipol is no longer farmable.

## Egg carry cost

Roadmap M3.5. Server sets `Humanoid.WalkSpeed` when the bag changes and on each new character. World rules currently leave walk speed alone (`docs/mechanics/wildbound-world.md:31`), so this changes existing behavior. Default 16 is documented but not read in this place (M1.1).

| Eggs in bag | Walk speed | Nest to camp, straight 296 studs (calculated) |
| --- | --- | --- |
| 0 | 16 | 18.5 s |
| 1 | 11 | 26.9 s |
| 2 | 10 | 29.6 s |
| 3 or 4 | 9 | 32.9 s |

Contract: `carrySpeed(eggs) > 8` for every bag size, including the Reinforced Pack and every skill, because 8 is Silueta's fastest speed (`WildboundWorldRules.luau:78`). Captured creatures add no cost. A cheating client could ignore the speed; log displacement over `WalkSpeed * 1.5` to a counter, do not punish.

**Honest limit:** a carrier walking straight still outruns Silueta. The cost is more time in territory, not a catch. See the falsifier below.

## Exposure inside territory

Calculated, not measured. Straight lines from the clearing, 16 studs/s in, capture 5.5 s, loaded speed out, no detours.

| Objective | Territory in | At spot | Territory out | Total |
| --- | --- | --- | --- | --- |
| `L1` | 3.3 s | 5.5 s | 3.3 s | 12.1 s |
| `L3` | 5.3 s | 5.5 s | 5.3 s | 16.1 s |
| `L2` | 7.0 s | 5.5 s | 7.0 s | 19.5 s |
| `E2` egg | 1.3 s | 0.25 s | 1.9 s | 3.5 s |
| `E1` nest egg | 6.8 s | 0.25 s | 10.0 s | 17.1 s |
| `E3` egg | 9.1 s | 0.25 s | 13.2 s | 22.6 s |

**A still player against Silueta (calculated):** impact comes `1.2 + (d - 7) / speed + 1.4` seconds after it detects you at distance `d`, so 6.1 s at the day edge, 6.5 s at the night edge, and 2.6 s up close. A 5 s capture finishes before impact only if Silueta starts beyond about 21 studs by day or 26 by night. Below that, the warning appears with the meter partly full, and the player chooses to finish or run. That choice is the point of this design.

Server logs per expedition, for measurement: `territorySeconds`, `captureSessions[]` with start, outcome, `inTerritory`, guardian mode and distance at start. Measure in M3 exit.

## Changes to existing behavior

| Change | Existing | New |
| --- | --- | --- |
| Creature pickup | 0.25 s hold (`WildboundServer.server.luau:173`) | Ring session; `State:pickup` refuses `Creature` |
| Contracts | 7 uses of `"Creature"` in `tests/WildboundState_Test.luau` go through `pickup` | Update those cases first, observe RED |
| Respawn | 20 s at one marker (`:184`) | Slot table above |
| Clearing Lumipol | Anyone, repeatedly | First capture only |
| Walk speed | Never set | Set by eggs in bag |
| Network | `Action`, `State` | Adds `CaptureCancel`, `CaptureState` |
| Species hardcode | `WildboundState.luau:102` | Unchanged in P0, one species. Replaced in M5.4 |

## Test matrix

**Pure contracts, fresh clones, RED first (M3.2).**

| ID | Case | Expected |
| --- | --- | --- |
| CAP-01 | Start with valid context | Session, encounter reserved |
| CAP-02 | Start with not alive, distance 10.01, NaN, infinite | Refused, nothing reserved |
| CAP-03 | Second player starts while reserved | `Reserved`, first session unaffected |
| CAP-04 | Same player starts second session | `AlreadyCapturing` |
| CAP-05 | Stationary for all `orbit` in 4 to 9, both `dir` | Never completes; `LeftRing` at about 6 s |
| CAP-06 | One 3-stud step at 3.0 s | Completes between 4.5 and 6 s |
| CAP-07 | Continuous movement above limit | `TimedOut` at 12 s, meter never grows |
| CAP-08 | Walking under 5 studs/s inside the ring | Meter grows |
| CAP-09 | Outside 2.4 s then back | Survives, meter reduced by 1.2 |
| CAP-10 | Displacement 8.01 in one sample, vertical 8.01, horizontal 18.01 | `TooFar` |
| CAP-11 | Elapsed 5 s between samples | Calm grows at most 0.2 |
| CAP-12 | Wrong owner cancels, stale token cancels | False, session intact |
| CAP-13 | `notifyStruck` | Next sample ends `Struck`, no grant |
| CAP-14 | Life changes between samples | `Defeated`, no grant |
| CAP-15 | `drop(player)` | Released, no grant, token dead |
| CAP-16 | Bag full at completion, forced | Refused with reason, no grant, released |
| CAP-17 | Completion twice for one token | One grant |
| CAP-18 | `State:pickup` on a `Creature` | `CaptureRequired` |
| CAP-19 | `releaseEncounter` with wrong token | False, still reserved |
| CAP-20 | `carrySpeed(n)` for n from 0 to max, all skills | Above 8 |
| CAP-21 | `S0` eligibility: new, carrying, registered, lost-first-catch | Allow, refuse, refuse, allow |
| CAP-22 | `ringCenter` at same `t` server and client inputs | Identical |

**Studio and people.**

| ID | Case | Needs | Pass |
| --- | --- | --- | --- |
| CAP-30 | Two clients tap the same Lumipol, 20 tries, roles swapped | Server & Clients | One owner, no stuck reservation |
| CAP-31 | Spam prompt and `CaptureCancel`, malformed tokens | Server & Clients | No duplicate, no error, counters 0 |
| CAP-32 | Leave mid-session, rejoin, reset mid-session | Server & Clients | No grant, reservation free within one sample |
| CAP-33 | Latency 0, 150, 500 ms with loss | Network Simulator | Honest player still completes; record success rate |
| CAP-34 | Phone landscape and portrait, Device Simulator | Device Simulator | Ring, bar and Stop readable; no overlap with stick |
| CAP-35 | Night fog, Reduced on and off, muted | Studio | Ring readable in a capture |
| CAP-36 | Five new testers, no coaching (M3 exit) | People, phones | All capture; each can state a failure reason |
| CAP-37 | Median exposure in territory across sessions | Server log | Reported; compare with table above |

## Hypotheses and what would falsify them

| Hypothesis | Falsified by |
| --- | --- |
| A world ring reads as a skill, not as waiting | Testers say "I just stood there", or success above about 95% on first try |
| One step in 5 s is learnable with no coaching | Below 60% of new testers complete a capture within three tries |
| 0.5 stud margin covers lag | CAP-33 success drops more than 15 points at 500 ms |
| One thumb is enough on a phone | Testers use two hands or mis-tap Stop (CAP-36) |
| Capture exposure creates tension | No tester mentions fear while capturing; or telemetry shows captures almost never overlap Hunt |
| Players take Territory slots over `L4` | Over 80% of captures at `L4` after first capture: raise the reward gap or remove `L4` |
| Egg slowdown makes the trip home tense | Eggs do not raise hunted time on the way home, or testers do not notice it. Then use a stronger cost, never below 8.5 studs/s |
| First catch in under a minute helps (hypothesis from notes) | First-capture funnel shows no effect on third expedition |

## Unverified Roblox behavior

| Item | Settle in |
| --- | --- |
| `ProximityPrompt` tap reliability on real touch | M3.4 |
| Server-side position lag at given latency on characters | CAP-33 |
| Humanoid movement on a phone stick at partial tilt | CAP-34 |
| Setting `Humanoid.WalkSpeed` from the server replicates promptly | M3.5 |
| Event handlers do not interleave without yields, in this place's signal mode | CAP-30 |
| Token source: `HttpService:GenerateGUID` works without HTTP enabled | M3.3; a server counter plus `Random` is an acceptable fallback, since the token grants nothing beyond cancel |

## M3.2 build notes

Wave W5, 2026-11-07. `src/wildbound/WildboundCaptureSession.luau`, deployed as `ReplicatedStorage.WildboundCaptureSession` because the client draws the ring from it. Contracts: `tests/WildboundCaptureSession_Test.luau` (`ServerStorage.WildboundCaptureSession_Test`), invoked as `require(testClone)(require(moduleClone), moduleClone.Source)`. Observed in Studio on fresh clones: RED 4 passed / 88 failed against a stub, then GREEN 92 / 92. Each of 42 single-line mutants, applied to a clone only, failed at least one contract. Nothing is wired: the server, `WildboundState` and the clients are unchanged, so the 0.25 s prompt still captures.

### Where this document was wrong

| Section | Problem found | Built instead |
| --- | --- | --- |
| Ring position | With the Lumipol as orbit center and `ORBIT_MIN` 4, a player who starts within about 2.57 studs of the Lumipol stays inside for 4.5 s and **completes by standing still** (calculated, r=4, distance squared + 16 - 8 d cos(w t) at most 25 until t = 4.5). The Lumipol is non-colliding, so standing on it is possible. The orbit center itself is always 4 studs from the ring center, so one step onto the Lumipol stays inside forever | The ring always starts centered on the player. The orbit center is the Lumipol for start distances 5.5 to 9 and shifts along the player-Lumipol line otherwise. `ORBIT_MIN` is 5.5, above the 5.0 tested radius, so no fixed spot stays inside for the whole orbit |
| Sample step 7 | Capping elapsed at exactly 0.2 loses up to 8% of every sample, because the fixed step really runs 0.2 to about 0.217 s (`WildboundWorld.server.luau:404-406`). 4.5 s of calm would take about 4.9 s | `MAX_ELAPSED` 0.25. Still and jump limits are speeds (5 and 40 studs/s) over `max(dt, 0.2)`, so a stall does not turn a walk into a jump |
| Stall rule and watchdog | Pushing the deadline on every stall lets a chugging server hold a reservation forever. A watchdog at `TIME_LIMIT + 1` after start would also kill a session the stall rule had just extended | Extensions are capped at 4 s in total (hard limit 16 s). The watchdog fires at the current deadline plus 1 s |
| Token | `HttpService:GenerateGUID` was unverified without HTTP | The module issues `cap:N` from a per-server counter, never reused. Cancel checks the owner, so a guessed token does nothing |
| `State` additions | `State:pickup` checks 10 studs, but a correct completion can be 14 studs away (orbit 9 plus radius 5) | The reservation lives in the session module. M3.3 still needs a `State` grant without the 10-stud check (see wiring below) |
| Session end table | No outcome for a clock that runs backward, unreadable positions, or an adapter that stops sampling | Three more reasons, all free of spook, retry and fail count: `LostTrack` (five unusable samples in a row), `Watchdog`, `Lost` (encounter retired) |
| `MAX_FAILS` | "Three failures" did not say whether Stop counts | Only `Failed` phases with player cause count. `Cancelled` and `Disconnected` do not |
| Failure count and leave-and-rejoin (independent audit, wave W5) | Failures were counted per encounter across all players, so one player who walked out of range three times (about 13 s) made the Lumipol leave for everyone. `drop` also erased the leaver's retry waits, so leaving and rejoining skipped the 6 s wait | Failures are counted **per player per encounter** (`failures[playerKey][encounterId]`). A player's third failure there costs that player `LONG_COOLDOWN` (45 s) on that encounter and the count starts over. The Lumipol no longer leaves because of failures: `leaves` stays in the ending but is always `false`, and only `retire` removes a Lumipol. `drop` keeps waits and counts, and each wait records its own length so a backward clock cannot stretch a short wait toward the long one. `sweep` forgets spent waits; `retire` forgets every player's waits and counts for that encounter. 103 contracts (11 new or rewritten: RED 92 passed and 11 failed, then GREEN 103 of 103) |

### Contract surface

`CaptureSession.new()`, then `begin(input)`, `sample(token, obs)`, `notifyStruck(playerKey)`, `cancel(token, playerKey, now)`, `drop(playerKey, now)`, `retire(encounterId, now)`, `sweep(now)`, `view(token)`, `activeSessions()`, `encounterState(id, now)`; pure `CaptureSession.ringCenter(ring, t)` and `CaptureSession.toSnapshot(view)`. `CONSTANTS` and `NOTICES` are frozen. Every ending returns `{ phase, reason, notice, grant, spook, spookUntil?, retryAt?, leaves, encounterId, playerKey, calm, ... }`; `grant = true` appears once per encounter, only on `Completed`.

`begin` takes server-read values only: `alive`, `life`, `distance`, the root position and the Lumipol position, plus `encounterStatus` (`"Open"` or `"Claimed"`), an optional `slotRefusal` (`FirstCaptureOnly` or `FirstCapturePending`), and `bagRoom` and `collectionRoom`, each of which must be exactly `true`. `dir` (+1 or -1) and `now` are injected.

Snapshot for the owner only, never naming the player or the encounter. Active: `token, phase, calm, inside, moving, outsideFor, deadline`; the first push and a resync from `view()` add `ring = { pivotX, pivotZ, y, orbit, a0, w, startedAt, radius }`, which never changes during a session. Ended: adds `reason, notice, retryAt`.

### Wiring for M3.3 and M3.4

- **Server.** In `WildboundServer.server.luau`, require the module from `ReplicatedStorage`. Change only the `Creature` branch of `spawnEncounter` (`:173-187`); eggs keep `state:pickup`. Set the creature prompt's `HoldDuration` to 0 after `prompt()` (`:91` hardcodes 0.25). In `Triggered`, after `validPrompt` and `allowed(player, "CaptureStart")`, read the root position (`context()` returns only alive and distance, so add a helper) and call `begin` with `playerKey = player.UserId`, `life = record.generation`, `now = workspace:GetServerTimeNow()` (the client ring uses the same clock), `dir` from a server `Random`, and bag and collection room from `state:snapshot`. While a session holds an encounter, disable its prompt (`encounterState`).
- **Loop.** On the same 0.2 s accumulator pattern as `WildboundWorld.server.luau:402-411`: for each `activeSessions()` entry, `sample`, then `sweep(now)` once. On `grant`, call a new `State:completeCapture` that claims and grants without the 10-stud check and without yielding, then retire the encounter in both `State` and the session module. On `leaves`, remove the model and respawn the slot. Keep `captureAnomaly` and `captureWatchdog` from `counters`; the exit test expects 0.
- **Strike.** Silueta resolves a strike in `WildboundWorld.server.luau:280-287`, a different script. Fire a server-only `BindableEvent` there whether or not damage is on (`completedPresentation`), and call `notifyStruck(player.UserId)`.
- **Remotes.** Add `CaptureCancel` to the `Action` whitelist (`WildboundServer.server.luau:194`); the token arrives as `uid` and is already length-checked at `:200`. Call `cancel(token, player.UserId, now)` and ignore `false` silently. Add a `CaptureState` RemoteEvent under `WildboundNetwork` and `FireClient` only to the owner with `toSnapshot(view)` on start, each sample and the ending.
- **Leaving and resets.** In `PlayerRemoving`, call `drop(player.UserId, now)` before `state:removePlayer` (`:263`). A new character changes `record.generation`, so the next sample ends `Defeated`.
- **State.** Make `State:pickup` refuse `Creature` with `CaptureRequired` (CAP-18), updating the seven `Creature` cases in `tests/WildboundState_Test.luau` first.
- **Client.** Draw the ring at `ringCenter(snapshot.ring, workspace:GetServerTimeNow() - ring.startedAt)` with `ring.radius`, and show `notice` on endings. The client never reports anything about a session.

### Still unverified

All numbers remain hypotheses. Nothing has run in Play: replication lag against the 0.5 stud margin, whether `GetServerTimeNow` on the server can step backward (handled by `LostTrack`, not observed), touch prompts, and the two-client race (CAP-30 is covered only as a pure contract plus a 6000-step seeded fuzz). Exposure inside territory comes from `tools/simulate_silueta_pressure.py` for a still player: at a 4.5 s hold, `L1` is warned in 60% of patrol phases and struck in 15% by day (98% and 24% by night); `L2` is warned in 39% and never struck by day. This document's calculated capture length is 4.7 to 5.5 s, between the simulator's 4.5 s and 6 s columns.

## M3.3 to M3.5 build notes

Wave W5, 2026-11-07, Studio place 122652861404212, Play on one machine (Studio Play solo, then Server and Clients with two clients). Damage stayed off, streaming stayed on, nothing was uploaded, published or saved.

### What exists

| Piece | Source | Explorer | Contracts |
| --- | --- | --- | --- |
| Capture rule, with the audit fix above | `src/wildbound/WildboundCaptureSession.luau` | `ReplicatedStorage.WildboundCaptureSession` | 103 |
| Grant, refusal, room | `WildboundState.luau`: `completeCapture(key, id, alive, tier)`, `captureRoom`, `encounterStatus`; `pickup` refuses a creature with `CaptureRequired` | `ServerScriptService.WildboundState` | 25 |
| Slots, wander and flee, first-capture rule, carry speed | `WildboundLumipolWild.luau` | `ServerScriptService.WildboundLumipolWild` | 34 |
| Words, shapes, ring geometry, placement | `WildboundCaptureView.luau` | `ReplicatedStorage.WildboundCaptureView` | 40 |
| Server adapter | `WildboundServer.server.luau` | `ServerScriptService.WildboundServer` | Play only |
| Strike signal | `WildboundWorld.server.luau`: one `BindableEvent:Fire(player)` after a resolved strike. The damage logic is untouched | `ServerScriptService.WildboundWorld` | Play only |
| Touch screen | `WildboundCapture.client.luau` | `StarterPlayerScripts.WildboundCaptureClient` | Play only |

Network: `Action` accepts `CaptureCancel` with the token as its one string (whitelisted, 128 bytes at most, rate limited like every action). `CaptureState` is a `RemoteEvent` fired only to the session owner. `CaptureStrike` is a `BindableEvent` under `WildboundNetwork`, so a client firing its own copy reaches nothing. The prompt for a creature has no hold. Measurement is kept in `ServerStorage.WildboundTelemetry` attributes (not replicated): `CaptureAnomaly`, `CaptureWatchdog`, counters, and `CaptureLog` with the last 40 sessions (slot, tier, reason, seconds, calm, in territory, Silueta's mode and distance at the start).

### Where this document was wrong again

| Section | Problem found | Built instead |
| --- | --- | --- |
| Spawn slots, which `L` slots are active | "Picked by the pipeline" gave no order, and L4 would be the last to appear | Order `L1`, `L4`, `L2`, `L3`: one player gets a territory slot and the no-Silueta fog slot, two get `L2`, three or more get all four |
| `State:completeCapture(key, id, token, alive, tier)` | The reservation lives in the session rule, so State has nothing to check a token against | No token. State claims, grants and refuses only |
| Touch UI flow, "at least 300 x 90" panel and a 64 px Stop | A 280 pixel tall phone interface has no free band that high | Panel from 340 x 76 down to 190 x 40 and Stop 64 x 64, chosen by a pure search that keeps clear of the avatar keep-out, the thumbstick, the jump button and every HUD rectangle. On a 359 x 660 portrait interface no free band exists, so the panel takes the objective line's place (drawn above it) |
| Touch UI flow, Stop and Inventory | Said the inventory button is disabled | Opening the inventory is refused with a notice while a session runs, and an open inventory closes when one starts |
| A still player | "Standing still fails" | Moving back and forth a stud or two inside the ring never exceeds 5 studs per second over a sample, so it counts as still and completed a capture in Play (4.6 s). Fixed in W9: stillness is also judged over a 1 s window. Path length over the window, divided by its span, must stay at or under 3 studs per second (twice the ring's 1.5), with at least 0.55 s of history; shuffling at 3.5 to 4.5 studs per second now pauses the meter, following the ring or a 0.2 stud sway does not. After real movement stops, the meter waits for the window to pass (about 1 s). Observed: RED 104 passed 4 failed, GREEN 108 passed 0 failed (CAP-38 cases). Thresholds are hypotheses; no human has judged them |
| Wander smoothing | Left to M2.6 | Not done: the Lumipol steps 0.4 stud every 0.2 s on the server and the client does not smooth it. Not judged by eye |

### Played in Studio

Solo (Studio Play), unless marked.

| Case | Result | Evidence |
| --- | --- | --- |
| Capture succeeds, fog slot `L4`, safe slot `S0a` (new player) and territory slot `L1` | PASS | 4.77 to 5.00 s each, one or two steps, Lumipol in the bag with its risk tier, slot refilled |
| `LeftRing` | PASS | Stood still, about 6 s, calm 2.2 |
| `Cancelled` (Stop message) | PASS | Ended at once with the Stop text |
| `TooFar` | PASS | Moved the character 25 studs |
| `Defeated` | PASS | Humanoid health set to 0 |
| `TimedOut` | PASS | Moved in a circle for 12.2 s, calm 0.37 |
| `Struck` | PASS | A real Silueta strike at `L1` ended it at 5.42 s and again at 4.82 s (calm 4.38 of 4.5) with damage off and health at 100 |
| Third failure on one Lumipol, the audit fix | PASS | The third failure at `L1` (`LeftRing`, `TooFar`, `Struck`) returned `retryAt` 44.97 s ahead, and the Lumipol stayed |
| `FirstCapturePending`, `FirstCaptureOnly` | PASS | Carrying a creature, then owning one, both refused at `S0a` with their texts |
| Two clients, one Lumipol, 28 rounds | PASS | 20 rounds with 40 ms offset and roles swapped, 8 with none: exactly one owner every round. The server `Reserved` reply was never reached: the loser's prompt was already disabled by replication, so that branch is covered by the pure contracts only |
| Spam: 200 taps, then 12 junk tokens, 90 foreign tokens and 4 bad actions, three times | PASS | Two sessions started in total, both from real taps after the first ended. The other player's running session was not touched. No error or warning line in the server output, anomaly 0, watchdog 0 |
| Leave mid-session (server `Kick`) | PASS | Ended `Disconnected`, no grant, the prompt was free again 1.07 s after the kick, the Lumipol did not flee, and the other player started a capture at once |
| Leave then rejoin | BLOCKED | Studio cannot rejoin the same test user |
| Reset mid-session | PASS | Same path as `Defeated` |
| `Lost`, `LostTrack`, `Watchdog` | Not reached | Pure contracts only; counters stayed 0 |
| Egg carry cost | PASS | Walk speed 16, then 11 with one egg (measured 11.0 studs per second), 16 after extraction |
| Night, fog, Reduced on | PASS | Ring readable in a capture (below) |
| Reduced off, muted client | Not run | The ring pulse is off when Reduced is on; no sound exists |
| Tap Stop or the prompt on a phone profile | BLOCKED | MCP clicks do not activate phone buttons (see `docs/testing/wildbound-baseline-m1.md`). Stop was exercised by its message only |
| Latency and loss | Not run | CAP-33 needs the Network Simulator |

### Exposure inside territory (CAP-37)

Measured at `L1`, which is 27 studs from Silueta's home, at night, with a bot that steps twice (about 16 studs per second for 0.22 s). Five sessions from one run, not independent: Silueta was already in Alert for four of them because the same player had just stood there.

| Result | Seconds | Silueta at start |
| --- | --- | --- |
| Caught | 4.77, 4.85, 4.77, 4.85 | Alert at 20.1, 27.5 and 25.8; Retreat at 27.1 |
| Struck | 4.82 | Alert at 24.0 |

Mean 4.81 s in territory, so about 5 s plus the walk in and out. 4 of 5 completed before the strike. By day, two earlier sessions at `L1` with a still player ended `LeftRing` at 5.88 s (Patrol, 39.6 studs) and `Struck` at 5.42 s (Alert, 20.6 studs). This agrees with the simulator's order of magnitude and says nothing about how fun it is.

### Captures

`assets/exports/forest-kit/captures/capture-*.jpg`, taken with Studio's Device Simulator (`StudioDeviceSimulatorService:SetDeviceAsync`, `SetOrientationAsync`): iPhone 17 Pro landscape (750 x 323 interface) and portrait (401 x 720), Galaxy A06 portrait (359 x 660) and landscape (705 x 280), and the desktop window. They show the calm state with a solid ring, the outside state with a dashed ring and a countdown, the left-the-ring and caught results, and a night fog capture. The device simulator was switched back off afterwards.

### Still unverified

All numbers. The 0.5 stud margin against real latency (CAP-33). Touch prompts, the Stop button and the movement stick on a real phone (CAP-34, CAP-36). Whether the ring reads as a skill or as waiting (CAP-36). Trunk collision against the slots. Wander smoothness. Behavior with more than two clients.

## Delivery A build notes (capture redesign, 2026-11-07)

Decisions H1 to H4 in `odd/tasks/wildbound-capture-extraction-horror.md`. All numbers are hypotheses.

### A1. Lumipol brain

`WildboundLumipolWild.luau` stays pure: the server passes positions, the nearest player's horizontal speed, cover points and an injected random source. Modes are `Idle` (pausing), `Wander` (walking), `Curious` (a calm player within 12 studs; it stops and watches), `Alert` (frozen, facing the runner), `Flee`, `Hide`, `Reserved` (a capture runs) and `Captured` (sealed; never moves again). The old `Spooked` mode is gone: a failed capture now flees and hides like any scare.

| Number | Wild slots | Safe slots `S0a`, `S0b` (gentle) |
| --- | --- | --- |
| Calm speed: at or under it, an approach never alarms | 8 studs/s | 12 studs/s |
| Alert radius: a faster player inside it builds alarm | 14 studs | 10 studs |
| Close radius: alarm builds twice as fast | 7 studs | 5 studs |
| Alarm for `Alert` / for `Flee` (seconds of running seen) | 0.2 / 0.8 | 0.4 / 1.2 |

Shared: alarm drains 0.5 per second when nobody runs near; an `Alert` lasts at least 1 s after the last fast move; flee speed 10 studs/s; `Hide` lasts 4 s, then it peeks at the threat for 2 s, then it is `Idle` again. A runner near a hidden Lumipol restarts its hiding. Wandering stays within 6 studs of the slot; every position stays within the leash, 24 studs by default (was 10; widened so the dressed map's props are in reach) and configurable per brain.

Cover: the server reads props named `FK_Evergreen_Trunk`, `FK_DeadTree_Wood`, `FK_DeadTree_Splinter`, `FK_FallenLog_Bark`, `FK_LanternMarker_Stones` and `RuinPillar` once at startup. `Wild.coverPoints` keeps those whose centre is within the leash, nearest first, 4 studs apart, 8 at most, each counted at most 3 studs wide. A flee picks the nearest hide spot 1.5 studs behind a prop as seen from the threat, skipping props in the threat's direction (within about 60 degrees) and spots outside the leash. With none, it backs away 8 to 12 studs and hides in place. Measured on the dressed map: `L2` has two trunks at 13 to 14 studs, `L1` a trunk and a pillar at 17, `L3` and `L4` props at 19 to 25; `S0a` and `S0b` have only lantern stakes and a trunk at 26, so the tutorial Lumipol mostly hides in the open.

`Wild.wary(brain)` is true in `Alert`, `Flee`, and `Hide` before the peek. The server hides the capture prompt while it is true, so a player who ran in may lose the chance before calm can begin.

Server wiring (`WildboundServer.server.luau`): the nearest live player's speed is `HumanoidRootPart.AssemblyLinearVelocity` without its vertical part. Each Lumipol model carries `Mode` and `Peek` attributes for the client. A sealed capture calls `Wild.capture` before the model is removed.

Keyboard players walk at 16 studs/s, so on a keyboard only stopping short or the gentle slots avoid alarm; a partly tilted thumbstick walks slower. No crouch exists yet; delivery D adds stamina sprint and may add a sneak.

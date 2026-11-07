# Lumipol capture design

Unit M3.1, wave W4a. Implements decision D3, and D4 and D14 where they touch capture.

**Status: proposal. Nothing here is built or playtested.** Every number is a hypothesis to test. Written 2026-11-07 from source and the layout plan, with no Studio or Play session. Calculated values say so.

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
| `MAX_FAILS` | 3 | After this the Lumipol leaves and the slot respawns |

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
| One player keeps restarting to hold it | At most 12 s reserved in every 18 s, and three failures remove it. Other slots scale by player count |
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

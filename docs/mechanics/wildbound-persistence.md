# Wildbound saved progress

Units M6.1 (schema) and M6.2 (fake-store contract list), wave W10. Implements B17 and D10, and defines the durable case that `docs/mechanics/wildbound-economy-p0.md:167` left open.

**Status: proposal, written 2026-11-07. Nothing here is built or run.** No DataStore was called, no API access was enabled, no experience was created. All numbers are hypotheses. No code on the Roblox page was copied, and none may be used untested (`docs/wildbound-roadmap.md:341`). Real tests wait for D8, which the user has not taken (`odd/tasks/wildbound-waves.md:20`, `:40`).

**Labels.** Verified = read in this repository, with file and line. Roblox = read on a Roblox page, section 11. Proposal = decided here for your review. Unverified = neither read nor tested.

## Quick path

1. One record per player, under one key, committed whole. Items move atomically because there is only one thing to write.
2. Only a successful lock claim creates a write handle. A failed load has no handle, so it cannot overwrite anything.
3. Extraction, hatch and purchases write first and report after. A loss applies first and writes right after.
4. The trip at risk is saved in the record with a leave time. Any server can resume it or expire it, so D10 no longer needs the same server.
5. Build pure modules first, against a fake store (section 8). Real store only in the isolated experience (section 10).

## Choices worth your review

| # | Choice taken | Tradeoff | Alternative |
| --- | --- | --- | --- |
| 1 | **D10 lives in the record, not on the old server.** Leaving writes the trip with a leave time; any server resumes or expires it | Changes the economy text. Bag and pouch enter the save | Hold in old server memory, as `wildbound-economy-p0.md:165`. See contradiction 1 |
| 2 | **Failed load shows a choice: Try again, or Play without saving.** Never automatic defaults, never a kick | A player can pick unsaved play and later regret it. Banner stays on | Kick, as the installed `roblox-datastores` skill says. Roblox recommends letting them play with clear messages |
| 3 | **Extraction waits for the save.** "Saving your catch..." then "Extracted" | A visible pause at the best moment of the loop. Length unmeasured | Report first and save later, which breaks the roadmap rule (`:342`) |
| 4 | **Small own module behind a store port** | Own code carries the risk until M6.6 proves it. Fake-store tests fit it directly | ProfileStore: more field use, but not read here, so its ledger fit and license are unknown. Roblox says to check ownership, maintenance and data exit first |
| 5 | **Item IDs come from a counter in the record:** `u12` | Unique per player only, which is enough with no trading. No random source, easy to test | GUIDs: unique everywhere, longer, and the source needs checking (`wildbound-capture.md:407`) |
| 6 | **Bad records are quarantined.** That player plays unsaved until a person looks | One corrupt record blocks one player's saving. Beats a silent repair that loses items | Auto-repair |
| 7 | **A server crash has no expiry.** With no leave time written, the trip resumes whenever they return | Slightly kinder than a leave. Players cannot choose it, as far as known | Expire after 180 s, which would fail the "one award, not zero" test |
| 8 | **A dropped item's 30 s keep running while you are away** | Reads `wildbound-fair-strike.md:212` narrowly, so logging out never pauses it | Freeze the timer: logging out would gain time |
| 9 | Autosave 60 s, lock expiry 300 s | After a crash, a return can wait up to 5 minutes. Roblox's sample autosaves at 180 s and states no expiry | Shorter expiry raises the risk of taking a lock from a live server |
| 10 | Pouch materials are saved by autosave and bag changes, not on every gather | A crash can lose up to a minute of gathered units. They were never claimed safe | Save per gather: wasteful |

## Contradictions found

| # | Conflict | Evidence | Resolved here as |
| --- | --- | --- | --- |
| 1 | Economy resumes "same server", but a solo player leaving likely closes that server, so the hold has nowhere to live. Rejoining a chosen server is not guaranteed either | `wildbound-economy-p0.md:165`, `:170`. Closing when empty is well known but not read on a page: Unverified | Choice 1. The rule must hold even if servers linger |
| 2 | `life:<generation>` is a defeat ID that restarts at 0 in each server. If saved, a real later defeat would look like a repeat and be ignored: free survival. The same kind of bug as B17 | `WildboundServer.server.luau:219`, `:232`, `:251`; `WildboundState.luau:168-173` | Keep that check session-only, and map it to one durable op ID (section 5) |
| 3 | Installed skill says one write per key per about 6 s. The Roblox limits page as read gives 4 MB per minute per key and no such rule | Section 11 | Design needs neither. Queue is serial, throttle errors back off. Measure in M6.6 |
| 4 | Skill says kick on failed load; Roblox says keep playing with clear messages | Section 11 | Choice 2 |
| 5 | Candidate schema holds creatures and eggs; exit test also needs materials | `wildbound-next-verification.md:57`; `wildbound-roadmap.md:346` | Whole economy is in the record |
| 6 | "Logging out to dodge death gains nothing", while D10 keeps a disconnect from being a defeat. An open telegraph is cancelled by leaving | `wildbound-roadmap.md:346`; `wildbound-fair-strike.md:255` | Leaving beats no more than walking away, which already escapes a strike (`wildbound-roadmap.md:150`). It costs the capture and the time. Stated in section 9, A7 |
| 7 | Roadmap blocks M6 until F1; waves schedule W10 now | `wildbound-roadmap.md:321`; `odd/tasks/wildbound-waves.md:14`, `:67` | Later user decision wins. This is design only, labelled unvalidated |

## 1. What today's code does

| Fact | Source |
| --- | --- |
| No DataStore call anywhere in `src/wildbound` | Searched 2026-11-07 |
| IDs are `wb:N` from one counter that starts at 0 in each new state, so they collide across servers (B17) | `WildboundState.luau:41-44`, `:47`; `wildbound-roadmap.md:138` |
| Leaving discards the profile | `WildboundServer.server.luau:263`; `WildboundState.luau:62-67` |
| `earnedSeal` lives only in the profile, so a saved copy must keep it or the seal could be earned again | `WildboundState.luau:121-124` |
| Extraction moves all items in one synchronous step | `WildboundState.luau:113-120` |
| Hatch removes the egg and adds the pet in one synchronous step | `WildboundState.luau:134-136` |
| Every new character goes to camp, which must skip a resumed trip | `WildboundServer.server.luau:245` |
| Session-only wording to remove only when true (M6.5) | `WildboundState.luau:197`; `WildboundServer.server.luau:27`, `:115`, `:197`, `:246`; `WildboundClient.client.luau:59`, `:83`, `:145`, `:149`, `:154` |

## 2. Storage layout

Proposal, following Roblox's advice on one store and one key per player.

| Item | Value | Why |
| --- | --- | --- |
| Data store | `WildboundPlayers`, scope default | Small fixed set of stores (Roblox) |
| Key | `Player_<UserId>` | Stable identifier, not a display name, under 50 characters (Roblox). Fits right-to-be-forgotten templates that need static patterns |
| Value | One JSON table, section 3 | What must change atomically stays in one key (Roblox) |
| Metadata | `LockId` only | Where Roblox's guidance puts the lock. Metadata limit is 300 characters in total |
| Reads and writes | `UpdateAsync` only in gameplay | Writes depend on current value (Roblox) |
| Flag | Server-only `persistenceMode = "off"`, plus an empty `persistencePlaceIds` list | Same pattern as `damageMode` (`wildbound-fair-strike.md:63-73`). `off` behaves as session-only and never touches the service |

Size, calculated: 100 entries at about 45 bytes, bond for 100 at about 30, ledger about 4 KB, trip about 1.5 KB. Under 20 KB against a limit of 4,194,304 characters.

## 3. Record, schema version 1

```json
{
  "schema": 1,
  "revision": 42,
  "lastCommitId": "extract:31",
  "nextUid": 18,
  "nextTrip": 8,
  "nextOp": 32,
  "firstSealGranted": true,
  "collection": {
    "registered": [{ "uid": "u12", "species": "Lumipol" }],
    "bankedEggs": [{ "uid": "u9", "species": "Lumipol" }]
  },
  "equippedUid": "u12",
  "banked": { "fogbark": 0, "glowmoss": 0, "nightbloom": 0 },
  "ember": 0,
  "consumables": { "seal": 0, "capsule": 0, "totem": 0 },
  "upgrades": { "reinforcedPack": false },
  "skills": {},
  "bondXp": { "u12": 0 },
  "settings": {},
  "stats": { "tripsOpened": 0, "extractions": 0, "defeats": 0, "firstPlayedDay": 0 },
  "atRisk": null,
  "ledger": [{ "id": "extract:31", "kind": "extract", "digest": "..." }]
}
```

`atRisk`, when the player has anything out in the world:

```json
{
  "pending": [{ "uid": "u15", "kind": "Egg", "species": "Lumipol", "riskTier": "Territory", "wardSource": null }],
  "carried": { "fogbark": 5, "glowmoss": 2 },
  "dropped": [{ "entry": {}, "expiresAtUnix": 0 }],
  "sealArmed": false,
  "totemActive": false,
  "marks": 0,
  "kUsed": 0,
  "position": { "x": 0, "y": 0, "z": 0 },
  "expedition": { "id": "t7", "leftCamp": true, "maxDistanceFromCamp": 0, "territorySeconds": 0, "paidSlots": {}, "pendingBondXp": 0, "bondEvents": {} },
  "checkpointAtUnix": 0,
  "leftAtUnix": null
}
```

| Rule | Detail |
| --- | --- |
| Integers | All quantities are nonnegative integers, as the economy requires (`wildbound-economy-p0.md:116`) |
| No derived values | Bond level, bag size and loss rate are computed from tuning, so retuning needs no migration |
| No session values | Section 7 lists what never enters the record |
| Stats | Plain counters for F2 (`docs/testing/wildbound-f2-plan.md`). No names, devices or chat |
| Personal data | The UserId appears only in the key. Never in the value, IDs or logs |
| Erasure | Static key pattern, single key, no secondary index, so Roblox's right-to-be-forgotten processing can match it (Roblox). Set this up before any real players |

### Durable unique IDs (B17)

| Rule | Detail |
| --- | --- |
| Format | Item `u<n>`, trip `t<n>`, operation `<kind>:<n>` |
| Source | `nextUid`, `nextTrip`, `nextOp` in the record, advanced by the lock holder |
| Why no collision | Counter and lists sit in one atomic record, so a rollback rolls both together |
| Old form | `wb:N` is never saved. Reading one in a record is a validation failure |
| State change | `newUid` moves from the state object to the profile (`WildboundState.luau:41-44`) |
| Retry | An ID is chosen when the operation is created and travels with it. Retries never allocate |

### Validation on every load

Pure function. Any failure means quarantine (section 4): no write, no repair.

| Check | Fails on |
| --- | --- |
| Types | Wrong type, NaN, fractions, negatives |
| IDs | Malformed, or duplicated anywhere across `registered`, `bankedEggs`, `pending`, `dropped` |
| Counters | `nextUid` at or below any used number |
| References | `equippedUid` not registered; bond key not a registered companion |
| Limits | Over collection limit 100; ledger over its cap |
| Schema | Above current version: `TooNew`, not quarantine |

### Migration path

| Rule | Detail |
| --- | --- |
| Ladder | `MIGRATIONS[n]` is pure and turns version n into n + 1. Applied in order, inside the claim |
| First release | Version 1 is first, so the ladder is empty. Tests prove it with a synthetic version 0 fixture |
| Fixtures | One golden fixture per version, kept forever in tests |
| Future data | A record newer than this server gets `TooNew`: no handle, plays unsaved. Protects data while old and new servers overlap |
| Failure | A throwing or invalid migration means quarantine, record unchanged |
| Unknown fields | Kept on write within the same version |
| Tuning | `economy-tuning.schemaVersion` is separate and never appears in the record |
| Recovery | Roblox keeps an hourly version of each key for 30 days after overwrite. Restoring is a human action with no live session. It writes a new revision and must strip the old `LockId`. Runbook belongs in M10.3 |

## 4. Load, lock, failed-load guard

**The guard is structural.** `claim` returns a `Session` holding `commit`. Every other outcome returns no session, so no code path can write defaults.

| Claim outcome | When | Session? | Player sees |
| --- | --- | --- | --- |
| `New` | Call succeeded, value absent, no lock | Yes | Normal start |
| `Loaded` | Call succeeded, validated, migrated, lock taken | Yes | Normal start |
| `LockedElsewhere` | Fresh `LockId` that is not ours; transform returned nil | **No** | "Your last game is still saving." Try again, or Play without saving |
| `Unavailable` | Call threw, or attempts ran out | **No** | "We could not load your creatures. They are safe." Same two buttons |
| `Quarantined` | Validation or migration failed | **No** | "We could not read your save." Play without saving only. Server counter |
| `TooNew` | Schema above this server | **No** | "Please rejoin to update." Play without saving |

| Rule | Value | Status |
| --- | --- | --- |
| Automatic attempts before the dialog | 3 within about 20 s, at camp | Proposal |
| Absent is never assumed | Only a successful call with no value is `New`. A thrown call is never absent | Required by F1 |
| Lock taken | Same `UpdateAsync` that reads and migrates | Roblox |
| Lock expired | Last update at least `LOCK_EXPIRY` ago. Store update time avoids comparing server clocks | Roblox; unit of `UpdatedTime` Unverified |
| `LOCK_EXPIRY` | 300 s | Proposal; Roblox states no value |
| Refresh | Every autosave | Roblox |
| `AUTOSAVE` | 60 s, random offset before the first | Proposal. Roblox's sample is 180 s with a random first offset |
| Release | Final write removes `LockId` | Roblox warns this can fail, so expiry must self-heal |
| Lock lost mid-session | A commit finds a foreign `LockId`: transform returns nil, session revoked, no more writes, player removed with a friendly message | Proposal, contract F5 |

**Play without saving.** The profile is a plain session profile, with no session object and the existing session-only copy, plus a banner that never hides. It is **never merged** into a save later, so nothing earned there can reach a real record. Try again stays offered at camp only until they leave camp. After that, rejoin.

## 5. Commit model

Each player has one serial queue, as Roblox warns that plain retry loops lose per-key order. At most one commit runs at a time.

| Class | Operations | Memory changes | Player told |
| --- | --- | --- | --- |
| **Write first** | Extract, hatch, capsule, craft, upgrade, learn, equip | After confirmation | After confirmation |
| **Apply first** | Defeat, away-too-long, strike drop | At once, then a commit | Loss at once. It is not a success claim, and never says "saved" |
| **Checkpoint** | Autosave, bag change | No change. Writes current profile | Nothing |

A write-first operation:

```text
1. Server validates, as today. The client supplies no operation ID, ever.
2. op = { id = kind:nextOp, kind, payload, digest }. Payload fixed here. New item IDs fixed here.
3. Snapshot sent to the client: saveStatus = Saving. Bag changes refused with Saving.
4. next = reduce(copy(profile), op)      pure, no yield
5. store.update(key, transform):
     if LockId is not ours            -> return nil: LockLost
     if ledger has op.id:
        same digest                   -> return nil: AlreadyApplied
        other digest                  -> return nil: OperationConflict
     if value.revision ~= profile.revision -> return nil: Diverged
     return next with revision + 1, lastCommitId = op.id, ledger + op
6. Success or AlreadyApplied: profile = next, then report success.
7. Failed call: same op retried with backoff, jitter and a cap.
8. Attempts ran out: read back without cache.
     op in ledger -> step 6. Definitely not -> refuse, nothing changed.
     Read fails   -> Unknown, section 6.
```

| Rule | Status |
| --- | --- |
| Transform is pure and does not yield. It may run more than once, so the fake runs it twice | Yield ban is Roblox; re-running is a defensive assumption, Unverified |
| Retry with backoff, jitter, cap and in-order queue; unknown outcomes are expected | Roblox |
| Stale requests stay in queue, except at close | Roblox |
| Throttle: stay inside 60 + 40 x players writes per minute per server. At one autosave per player per minute plus a few operations, this is far below | Roblox limit; calculated. Whether `UpdateAsync` also spends read budget is Unverified |

### Operations

The payload is immutable. Each reducer checks state too, so a replayed client request becomes a new operation that finds nothing to do.

| Op | Class | Reducer effect, in one record | Double-award guard | Replies |
| --- | --- | --- | --- | --- |
| `extract` | Write first | Bag to collection, materials and Nightbloom to banked, Ember paid, bond XP banked, first seal once, expedition closed, `atRisk` cleared | Bag and pouch gone after commit, ledger | `Extracted`, `Empty`, `Saving` |
| `hatch` | Write first | Egg out, pet in with the fixed ID | Egg UID gone, ledger. F3 | `Hatched`, `NotOwnedEgg`, `Saving` |
| `capsule` | Write first | One item banked, Ember paid, capsule spent | Item and capsule gone | As `wildbound-economy-p0.md:363` |
| `craft`, `upgrade`, `learn` | Write first | Cost and grant together | Cost check. A second tap pays twice, accepted by the economy (`:369`) | As `:357-359` |
| `equip` | Write first | `equippedUid` | Same result if repeated | `Equipped`, `NotOwnedPet` |
| `arm` | Checkpoint | Seal armed or item warded. No spend | State | `AlreadyProtected`, `NoSeal` |
| `defeat` | Apply first | Order of `wildbound-economy-p0.md:155`. Seal spent only if it saves | Session check per life, then one durable `defeat:<n>` | Loss summary |
| `drop` | Apply first | Item moves from `pending` to `dropped` | Per `attackId`, session (`wildbound-fair-strike.md:203`) | Notice |
| `away` | Inside the claim | Same order as defeat, with no mark | Requires `leftAtUnix` set and expired; clears it | Summary at join |

**Protection, as the roadmap names it (`:342`).** Marking a ward spends nothing. The seal is spent only inside `defeat` or `away`, so its idempotency is theirs.

**Ledger.** Last 64 operations, by count, not by time. Older IDs are safe to forget because the queue is serial, so only the newest operation can be in doubt, and reducers check state. This takes the retention decision that `wildbound-next-verification.md:64` left open.

## 6. Never report success before a confirmed save

| `saveStatus` | Meaning | Copy, always text, never color alone |
| --- | --- | --- |
| `Saved` | Last commit confirmed | Quiet "Saved" for 2 s |
| `Saving` | Write-first op in flight | "Saving your catch..." |
| `Paused` | Autosave failing, nothing in doubt | "Not saving right now. Keep playing. Your banked creatures are safe." |
| `Unknown` | Op outcome unknown | "Still saving. Stay in camp if you can." Bag changes and other ops refused until resolved |
| `Off` | Playing without saving | Permanent banner |

| Moment | Wording allowed | Wording banned |
| --- | --- | --- |
| Extract in flight | "Saving your catch..." | "Extracted" |
| Extract confirmed | "Extracted 2 items. Saved." | |
| Attempts ran out, definitely not written | "Could not save. Your items are still in your bag. Try again." | "Lost" |
| Defeat while an op is in flight | Applied after the op resolves | Reporting both at once |
| `Unknown` | The copy above | Any success or failure claim |

## 7. Leaving, closing, and D10

| Case | What is written | Next load, on any server |
| --- | --- | --- |
| Leaves with nothing at risk | Final write, lock released | Normal |
| Leaves with something at risk, in the field or in camp | Final write with `leftAtUnix = os.time()`, lock released | Within 180 s: resume at last position with bag, pouch, mark, K, paid slots and totem state, plus 3 s grace. Later: `away` in the claim, then a summary |
| Returns in time | `leftAtUnix` cleared | The pivot at `WildboundServer.server.luau:245` is skipped once. Position clamped to the map |
| Server closes while players are present (`BindToClose`) | All players in parallel, one final write each with the queue folded, `leftAtUnix` stays null | Resume whenever they return |
| Server crash | Nothing new; last checkpoint stands | Lock expires, then resume at the last checkpoint. No expiry |
| Final write fails | Same as crash | Same |
| Rejoining while the old final write is running | Claim sees `LockedElsewhere`, retries | Usually succeeds in the automatic attempts |

**Folding at close.** Roblox clears queues at close to fit the time limit. Here that means dropping checkpoints only. An unresolved write-first op is folded into the same final transform, guarded by the ledger, so it lands exactly once. The time limit itself was not on the page content I could read: Unverified.

**Kill mid-extraction, the roadmap's exit test:**

| Kill happens | Record | Player on return | Award |
| --- | --- | --- | --- |
| Before the write lands | Bag still in `atRisk`, no leave time | Bag back, extracts | One |
| After the write, before the reply | Items in collection, ledger entry | Sees items | One |
| During a retry | Ledger stops the second write | Sees items | One |

**Honest limit.** Items gained after the last checkpoint are lost in a crash. A bag change triggers a checkpoint, so this means seconds of bag loot and up to a minute of pouch units. They were never claimed safe. The exit test should use a bag item that was checkpointed.

### Economy, capture and strike state

| State | Durable | At risk (in `atRisk`) | Session only |
| --- | --- | --- | --- |
| Registered, banked eggs, banked materials, Ember | Yes | | |
| Consumables, upgrades, skills, bond XP, first-seal flag, settings | Yes | | |
| Bag, pouch, dropped items, wards | | Yes | |
| Mark, K | | Yes, so leaving clears neither (`wildbound-fair-strike.md:255`) | |
| Armed seal, active totem | | Yes, reconnect does not refresh (`wildbound-economy-p0.md:292`) | |
| Expedition with paid slots and pending bond XP | | Yes | |
| Capture session, token, ring, retry times, spook | | | Yes. Capture never resumes (`wildbound-capture.md:224`) |
| Encounter IDs, claims, reservations, gather nodes, active slots, respawn timers | | | Yes, belong to one server's world |
| Open attack, attack IDs, dwell, liveness, client ready | | | Yes. Open attack closes on leaving |
| Rate limits, `records`, character generation, `life:<n>` check | | | Yes |
| Guardian, phase, cycle offset, telemetry counters | | | Yes |
| Companion model | | | Rebuilt from `equippedUid` |

Item fields kept when banked: `uid`, `species`. `riskTier` is read at extraction and dropped, as today's extract copies only named fields (`WildboundState.luau:115-117`).

## 8. Contracts for M6.2

Strict TDD: observe RED first. **These cases are design until Studio runs them**, since Luau tests run only through the Studio harness (`wildbound-roadmap.md:419`), unless D9 changes that. Green here proves logic, never Roblox behavior (`wildbound-next-verification.md:67`).

**Modules proposed.** `WildboundRecord` (schema, validate, migrate, reducers, pure), `WildboundPersistence` (session, queue, lock, takes a store port), test double `FakePlayerStore`, and `WildboundStoreRoblox` (M6.3, the only file that may name `DataStoreService`). A source check enforces this.

**Port:** `update(key, transform) -> ok, value, info | false, errorKind`, and `read(key) -> ok, value, info | false, errorKind`.

**Fake controls:** scripted faults per call (`throwBefore`, `commitThenThrow`, `timeout`, `throttle`), delayed responses, transform run twice, injected clock, full `writes[]` log, byte-exact `get`.

### F1: failed load cannot overwrite

| ID | Setup | Expected | Evidence kept |
| --- | --- | --- | --- |
| F1.1 | Seeded record, load throws every time | `Unavailable`, no session | Stored bytes identical, `writes` empty |
| F1.2 | As F1.1, player plays unsaved 10 minutes of autosave ticks, leaves, server closes | Zero writes | Same |
| F1.3 | Timeout on load | As F1.1 | Same |
| F1.4 | Confirmed absent | `New`, first write allowed | One write |
| F1.5 | Malformed values: wrong type, NaN, duplicate IDs | `Quarantined`, no write | Bytes identical |
| F1.6 | Schema above current | `TooNew`, no write | Bytes identical |
| F1.7 | Load fails, then Try again succeeds before leaving camp | Real record loaded, unsaved progress discarded, not merged | Final record equals seed plus lock |
| F1.8 | Migration throws | `Quarantined` | Bytes identical |
| F1.9 | Autosave fails while loaded | `Paused`, no success notice, later retry succeeds | Status log |
| F1.10 | Commit returning `LockLost` | No retry, session revoked | No further writes |

### F2: unique IDs

| ID | Setup | Expected | Evidence |
| --- | --- | --- | --- |
| F2.1 | Seed `u1` to `u5`, `nextUid` 6, fresh server, grant and hatch | New IDs from `u6`, no collision | All IDs listed |
| F2.2 | Two consecutive sessions with new state objects | Counter continues | Same |
| F2.3 | Duplicate across `registered` and `bankedEggs` | Quarantine | Bytes identical |
| F2.4 | Duplicate across `pending` and `registered` | Quarantine | Same |
| F2.5 | `wb:1` in a record, `nextUid` too low, malformed ID | Quarantine | Same |
| F2.6 | Commit lost, retry | Same new ID, not a second | IDs identical |
| F2.7 | Crash rollback then new grant | Uses rolled-back counter; no ID conflict inside the record | Record |
| F2.8 | Two defeats in two server sessions, both first life | Both apply. Guards contradiction 2 | Ledger, loss amounts |

### F3: atomic operations

| ID | Setup | Expected | Evidence |
| --- | --- | --- | --- |
| F3.1 | Hatch, fail before commit | Egg kept, no pet, no success | Before and after records |
| F3.2 | Hatch, commit then lost reply, retry | One egg out, one pet in, success once | Order log |
| F3.3 | Hatch, commit then lost reply, read-back also fails | `Unknown`; no claim; resolves later to one | Status log |
| F3.4 | Extract, each of the three kill points | One award each | Records |
| F3.5 | Extract fails for good | Items still in bag, "Could not save" | Notice log |
| F3.6 | Every reducer against a broken record | No partial write | Bytes |
| F3.7 | Defeat queued during an extract in flight | Extract first, then defeat finds empty bag | Order log |
| F3.8 | Extract, first seal, with crafted seals held | Adds 1, once ever, across sessions | Consumables |
| F3.9 | Success notice is sent only after the fake confirms | Automatic check: notice index above commit index | Event log |

### F4: replay

| ID | Setup | Expected | Evidence |
| --- | --- | --- | --- |
| F4.1 | Deliver same op twice | One effect | Ledger |
| F4.2 | Deliver response twice | One memory change | Revision |
| F4.3 | Caller restarts with the same op ID, record unchanged | One effect | Same |
| F4.4 | Same ID, other payload | `OperationConflict`, no second award, counter | Record |
| F4.5 | 65 further ops | Oldest leaves ledger, size bounded | Ledger length |
| F4.6 | Client forged IDs and payload fields | Ignored, server creates its own | Source check, record |
| F4.7 | `away` claim replayed | Applied once | Ledger, materials |

### F5: two servers

| ID | Setup | Expected | Evidence |
| --- | --- | --- | --- |
| F5.1 | A holds a fresh lock, B claims | B `LockedElsewhere`, no write | Writes |
| F5.2 | A stops refreshing past expiry, B claims, A commits | A `LockLost`; B's record stands; A revoked | Commit sequence |
| F5.3 | A's delayed reply arrives after B took over | Ignored | Final record |
| F5.4 | A and B both read revision 10, then interleave | Stale write rejected, no union of lists, no resurrected egg | Sequence, final record |
| F5.5 | A's final write in flight, B claims | B retries, gets A's result | Sequence |
| F5.6 | Same player on two servers, second plays unsaved and leaves | Record shows nothing from the second | Bytes |
| F5.7 | Release fails, then expiry | Self-heals at exactly the limit, not before | Clock |
| F5.8 | Lock at 299 s and 300 s | Refused, allowed | Same |

### D10 and lifecycle

| ID | Case | Expected |
| --- | --- | --- |
| D10.1 | Leave, claim at 179 s | Resume, all at-risk intact, mark and K same, pivot skipped once |
| D10.2 | Leave, claim at 181 s | `away` once, same result as a defeat with no mark |
| D10.3 | Crash, claim after an hour | Resume, no expiry |
| D10.4 | Leave then rejoin twice | No bank, no reset of paid slots, mark, K or totem |
| D10.5 | Dropped item at 25 s of its 30, away 10 s | Lost on return |
| D10.6 | Leave mid-capture | No grant, reservation free, no at-risk change |
| D10.7 | Close with queue full | One final write per player, in-flight op applied once |
| D10.8 | Equal result: `away` and `defeat` on the same fixture, without the mark | Identical records except ledger and stats |

## 9. What a duplicate or rollback would need

| # | Attack | What it needs | What stops it | Contract | Left over |
| --- | --- | --- | --- | --- | --- |
| A1 | Hop servers before the final save lands | Second load to read old data | Lock refuses, no handle | F5.1, F5.5 | None known |
| A2 | Old server writes late | Its write accepted after takeover | `LockId` checked in the transform, atomic | F5.2, F5.3 | None known |
| A3 | Stall a server past expiry | Control over server stalls, then a late write | Same | F5.2 | Needs a real test |
| A4 | Lost reply gives two awards | A retry with a new effect | Ledger and fixed payload | F3.2, F4.1 | None known |
| A5 | Replay the extract or hatch remote | A second effect on the same items | Rate limit, serial queue, items already gone | F3, CAP spam tests | None known |
| A6 | Forge an operation ID | A client field read by the server | No such field | F4.6 | None |
| A7 | Log out to dodge a strike | A gain over walking away | Mark, K, bag, slots all kept; capture lost; moving already escapes | D10.1, D10.4 | Accepted. Gains a telegraph escape, which a step also gives. Check with F1 logs |
| A8 | Die, then leave before the defeat is written | Leave to outrun the queue | Queue drains in leave. Defeat before final write | F3.7, D10.7 | Only a server crash in that window |
| A9 | Crash the server after a loss, to get the bag back | A way to crash on demand | Defeat commits at once, so the window is short | None possible with a fake | Needs M9.3 abuse work. A real crash exploit would also be its own bug |
| A10 | Fail a load on purpose, then earn free | Unsaved progress reaching a record | Never merged, no handle | F1.2, F1.7 | None known |
| A11 | Hatch, then roll back, to keep egg and pet | Separate writes | One record, one commit | F3.1, F3.2 | None |
| A12 | Stale list merge brings an egg back | A merge | No merge ever. Stale snapshot rejected by revision | F5.4 | None |
| A13 | Refresh paid slots by relogging | Slots forgotten | Stored in `atRisk` | D10.4 | Server hopping for fresh nodes costs load time, gains nothing repeated |
| A14 | Server hop to find Night | Random cycle offset per server (D5) | Not stopped | None | Accepted. No duplication. Check in beta |
| A15 | Pause a dropped item's timer | Timer frozen while away | Absolute time | D10.5 | None |
| A16 | Spam craft to burn the store budget | A write per tap | Existing rate limit, one in flight, button disabled | M9.3 | Watch counters |
| A17 | Studio writes real data | API access on the main place | Off by default, `persistenceMode` off, place list empty, D8 separate experience | Source check | Human setting |
| A18 | Rollback by version restore | Dashboard access | Owner only. Runbook in M10.3 | None | Trust in owner |

**No trading exists,** so one player's duplicate cannot reach another. This lowers impact, not the requirement. Revisit before any trade or leaderboard.

## 10. Real tests need D8

| Fact | Source |
| --- | --- |
| Studio uses the same data stores as the live client, and Roblox says to enable API access only for a separate test version | Roblox |
| D8 is not taken. Creating that experience needs separate explicit approval | `odd/tasks/wildbound-waves.md:20`, `:40`, `:22` |

M6.6 runs only after D8, in that experience, with the destination named by the user. It must settle:

| ID | Question |
| --- | --- |
| R1 | Transform arguments and returns; does omitted metadata clear? Can `LockId` be written as read? |
| R2 | Unit and clock of `UpdatedTime` |
| R3 | Does the transform re-run? Are lost replies observable? |
| R4 | Per-key write behavior: is there a 6 s floor? Budget cost of `UpdateAsync`? |
| R5 | `BindToClose` time limit, and order against `PlayerRemoving` at shutdown |
| R6 | Does a solo server close when empty, and how soon? |
| R7 | Extraction wait on a phone over a real connection (choice 3) |
| R8 | Forced load failure, kept byte-identical, read from the dashboard |
| R9 | Kill mid-extraction, three points, one award |
| R10 | Two real servers, one player, lock refusal; two devices on one account |

**Exit test** (`wildbound-roadmap.md:346`) maps to: rejoin restores (R8 setup), forced load failure (F1 plus R8), two servers (F5 plus R10), kill mid-extraction (F3.4 plus R9), logout gains nothing (D10 plus A7).

## 11. Roblox documentation

Read 2026-11-07 through a fetch tool that returns a summary of each page, not raw text. So the facts are as summarized, pages carry no date, and quotes are as returned. **Recheck at M6.3.**

| Page | What I relied on |
| --- | --- |
| [Player data and purchasing](https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing) | Do not use sample "as-is without extensive testing". Lock in key metadata as `LockId`, written inside the same `UpdateAsync`. Expired when last update is at least the expiry ago, no value given. Autosave refreshes it, sample 180 s, random first offset. Release can fail. Per-key serial queue. Fallback data is marked errored and never written. Recommends play with clear messaging over a kick. `SessionLocked` and `DataStoreError` go to the client. Queues cleared at `BindToClose` |
| [Best practices](https://create.roblox.com/docs/cloud-services/data-stores/best-practices) | Few stores, one key per player, stable IDs, atomic data in one key. Prefer `UpdateAsync`. Backoff with jitter and caps, in-order retries, unknown-outcome writes. Check modules before adopting. Right-to-be-forgotten processing. Save more often than lock expiry |
| [Limits](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits) | 4,194,304 characters. Key name 50. Metadata 300 total. Per key 4 MB per minute write, 25 read. Server write 60 + 40 x players per minute. Experience write 300 + 20 x users |
| [Data stores](https://create.roblox.com/docs/cloud-services/data-stores) | Server only. Nil from the transform cancels. Transform cannot yield. Studio shares stores with live; do not enable for live games, use a separate test version |
| [Versioning and caching](https://create.roblox.com/docs/cloud-services/data-stores/versioning-listing-and-caching) | First write per UTC hour makes a version, kept 30 days after overwrite. `GetAsync` cached 4 s unless `UseCache` is false |

### Could not read

| Item | Result |
| --- | --- |
| `UpdateAsync` reference, transform arguments and returns | [`GlobalDataStore`](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore) returned only the signature |
| `DataStoreKeyInfo` units | [Page](https://create.roblox.com/docs/reference/engine/classes/DataStoreKeyInfo) gave types only |
| `BindToClose` time limit | [`DataModel`](https://create.roblox.com/docs/reference/engine/classes/DataModel) gave none in the content returned, which was truncated. The usual 30 s is memory, not read |
| `manage-data-stores` | 404 |
| `DataStoreSetOptions`, ProfileStore | Not read |

## Implementation status (W10, 2026-11-07)

Built as pure modules with contracts run in Studio Edit on fresh clones. **No data store was called**, no service was enabled, nothing is wired into the running server. Green proves logic against a fake, never Roblox behavior.

| Module | Studio path | Contracts | RED | GREEN |
| --- | --- | --- | --- | --- |
| `src/wildbound/WildboundRecord.luau` | `ServerScriptService.WildboundRecord` | `tests/WildboundRecord_Test.luau`, RT-1 to RT-18 | 1 passed, 17 failed (empty stub; RT-18 source check passes on a stub) | 17 passed, 1 failed (test defect, below), then 18 passed, 0 failed |
| `tests/WildboundFakePlayerStore.luau` (test double) | `ServerStorage.WildboundFakePlayerStore` | `tests/WildboundFakePlayerStore_Test.luau`, FK-1 to FK-13 | 1 passed, 12 failed (empty stub; FK-13 source check) | 13 passed, 0 failed |

The fake implements section 8's controls: scripted `throwBefore`, `commitThenThrow`, `timeout`, `throttle` per update call, a separate read queue (`scriptReads`) so a read never consumes an update's fault, `failAll`, scripted latency on the shared injected clock, a `before` hook that lets a second server land first, the transform run twice on detached JSON copies, a per-minute write budget, a 4,194,304-character limit, a full `writes` log and byte-exact `raw`. It lives under `tests/` and `ServerStorage`, never in the running game.

Test defect fixed: RT-4 banned the text "defeats", which `stats.defeats` (a designed counter) contains. It now checks the session tables by key.

### Decisions taken (for review)

| # | Decision | Why |
| --- | --- | --- |
| W10-1 | `lastWriteId` added to schema 1 | A checkpoint whose reply is lost must recognise its own landed write on retry instead of reading it as `Diverged` |
| W10-2 | The record stores State's real expedition fields (`newUnits`, `newItems`, `bondXp`, `bondEvents`, `pendingBond`, `paidSlots`, `maxDistanceFromCamp`) plus `elapsedSeconds`, not section 3's `leftCamp` and `territorySeconds` | Those two do not exist in `WildboundState`; the economy reads the others. `startedAt` is a server clock, so only elapsed time is saved and rebuilt on load |
| W10-3 | Trip time is frozen at the checkpoint; time away never counts toward base Ember | No credit for being offline |
| W10-4 | A dropped item with no known expiry is saved as expiring at the checkpoint | A missing timer can never extend a drop (A15) |
| W10-5 | Version 0 is defined as the unversioned shape and `MIGRATIONS[0]` ships, instead of an empty ladder | Proves the ladder on a real step. No store ever held version 0, so it only fills missing fields and never invents items |
| W10-6 | Skills are checked by shape only, not against tuning | Removing a skill from tuning must not quarantine every player who learned it |
| W10-7 | The serializer refuses any `wb:N` ID (`SessionId`) | Today's State still makes session IDs (B17); they can never reach a save. Moving `newUid` to the record is M6.4 wiring |

## Next step

Your review of the choices above, and D8 when you are ready. M6.2 code follows W7, because the reducers need the economy state.

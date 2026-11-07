# Wildbound next verification checklist

**Preparation only — no cases below were executed for this guide.** Use this after the exclusive animation operator hands Studio back to the parent. It adds no harness, gameplay, persistence, damage, reward or product change. Current authorization and the [canonical task document](../../odd/tasks/wildbound-first-playable.md) govern execution; this guide grants no permissions.

## Start gates and evidence

- [ ] Record the current Studio instance/place/universe, target confirmation, operator, date, source revision/hashes and editable backup. Reverify a changed target before any Studio edit. Keep one Studio/script writer.
- [ ] Obtain the four real clip IDs/statuses from the operator's handoff manifest (repository path: `docs/assets/silueta-animation-upload-manifest.json`; present, written by the four-animation upload, `silueta-animation-assets.md:16`). Confirm actual Animator loading, durations, upright deformation, fixed root and state transitions before animation acceptance. Missing IDs/manifest block this gate. Synthetic tracks and server playback positions are not client-visible evidence.
- [ ] Record fresh adapter and map/state/world results using the [adapter](silueta-visual-adapter.md), [core](wildbound-p0.md) and [world](wildbound-world.md) runners. Historical **23 + 41 passing contracts are baseline evidence, not a fresh run or co-op proof**. Older guide banners describe their original stage; consult the canonical chronology for current authorization/status.
- [ ] Verify and retain `StreamingEnabled=true`, `damageEnabled=false`, `nightRewardsEnabled=false` and accurate session-only messaging before and after every session. Do not disable streaming, weaken a guard or invoke damage to manufacture a pass. Native review remains OFF.

Use one evidence record per case and repeat: `case ID / PENDING|PASS|FAIL|BLOCKED / operator+time / source / setup+steps / expected / observed / server log / client A capture / client B capture / limitation / cleanup`. All cases start **PENDING**, except the explicitly blocked damage claims below. A missing capability is **BLOCKED**, not PASS. New fixes require observed RED → GREEN with fresh modules and affected regression checks; this documentation unit implements none.

Common session fields: `server session identity; player A UserId+name+client window; player B UserId+name+client window; character-life A/B; EncounterId; pending UID; banked egg UID; registered pet UID; equipped UID; protection flag+seal charges; server timestamp`. Copy observed values only. Distinguish a Studio session/window label from a production JobId; record any unavailable field and its consequence.

## 1. Genuine two-client loop

The current MCP Play/client schemas have no client-count or distinct-client selector. After exclusive handoff, use supported native **Server & Clients** with two actual clients. First observe both distinct player identities in the same server and map each window to its player. Two calls labeled “client,” two synthetic profiles, or server-only state calls do not satisfy this gate. If two identities or independent client control cannot be demonstrated, mark the co-op cases **BLOCKED** and stop that lane; do not bypass permissions.

| ID | Action and expected invariant | Required case evidence beyond the common record |
| --- | --- | --- |
| C1 | A and B use normal pickup input on the same live encounter as closely together as possible. Exactly one receives it; it disappears for both; loser receives no item. Repeat with roles reversed and a fresh encounter. | Same EncounterId in both captures; input/arrival ordering where observable; both inventories before/after; winner UID; no false claim of exact simultaneity. |
| C2 | Loser retries the retired/claimed encounter; winner resets, then loser retries again. No transfer or duplicate award. A replacement world spawn must have a different EncounterId. | Old/new EncounterIds, loser snapshot after each retry, winner character-life transition. Normal inputs that cannot exercise an old ID do not prove rejection; mark that subcase pending for a separately authorized probe. |
| C3 | Each client collects separate creature/egg loot and extracts at camp. Only that owner's pending entries move into registered creatures/banked eggs; repeated empty extraction grants nothing again. | Per-owner UID movement and counts; seal charges before/after; both independent client snapshots. |
| C4 | A hatches one owned banked egg for free, then equips the resulting registered pet. Repeat the consumed-egg request only through an authorized test surface; B cannot hatch/equip A's UID. | Consumed egg UID, new pet UID, equipped UID and ownership; unchanged B state; second request result. UI absence alone is not server rejection evidence. |
| C5 | Reset A through supported controls with unprotected temporary loot. A's new character loses only unprotected pending loot; banked/registered entries survive within this session; B is unchanged. | Before/after snapshots, old/new character identity, actual input versus controlled setup, no guardian-damage claim. |
| C6 | Earn a seal, choose a pending UID through inventory Protect, then reset. Only the selected item survives, its protection clears and one charge is spent only when it saves that item. Repeat with no charge; verify registered/banked items and B remain intact. | Selected UID/flag, all pending UIDs, charges and character lives before/after. Duplicate death-callback rejection needs a separately authorized probe, not two different resets. |
| C7 | Both clients observe the same phase and reveal expiry. Use each eligible player's flashlight/pulse; overlapping reveals do not add durations. Compare actual Idle/Locomotion/Telegraph/Attack poses, visibility and warning presentation on both clients. | Server deadlines plus time-aligned A/B captures; actual movement versus idle; real asset IDs; per-client late/missing visual observations. State/track existence alone is insufficient. |

## 2. Touch, layout and accessible warnings

Run the matrix below on each available phone emulator profile in **portrait and landscape**, each with inventory **closed and open**, and with **normal/reduced effects** plus **audible/muted audio**. Record viewport pixels, device profile, input mode, mute control used and whether a real device or emulator. Emulator success is not physical-phone evidence. If a setting/control is unavailable, mark only that slice BLOCKED; do not call privileged volume APIs or change permissions.

- [ ] **M1 — Layout/input:** capture each orientation and inventory state. Read HUD, inventory sections, session-only notice, hatch/equip/protect feedback and cooldowns; scroll to the last item; activate touch buttons without overlap with movement/camera or system safe areas. Reopen inventory and rotate without losing selection or blocking dismissal. Record clipping, occlusion and mis-taps, not an assumed accessibility pass.
- [ ] **M2 — Warning:** trigger an ordinary non-damaging telegraph while moving and while inventory is open. With audio genuinely muted and reduced effects enabled, capture when the warning first becomes readable, its wording and how long it remains before resolution. Repeat normal effects without relying on flash/color/audio alone. Missing/hidden/late warning is FAIL for that slice, even if no health is lost.
- [ ] **M3 — Counterplay/readability:** use free flashlight and an eligible pet pulse with touch, inspect cooldown/error feedback, and follow the camp-return route at night. Record interaction delays and device/frame-time observations where measurable; no invented performance threshold or first-action time target.

The [historical encounter report](silueta-encounter-phase-report.md) observed reduced-effects text but left literal muted-client verification BLOCKED. Inventory suppression of the shared world HUD is an identified warning risk, not a completed accessibility solution.

## 3. Non-damaging threat, streaming and lifecycle

**Damage stays OFF throughout. Actual damaging strike and causal “escape prevented damage” claims remain BLOCKED.** Unchanged health can establish the guard, not attack fairness. Existing snapshots are roughly 1 Hz against a 1.4-second telegraph; measure delivery/presentation, do not assume a full warning window.

| ID | Future authorized setup/check | Evidence and fail-closed requirement |
| --- | --- | --- |
| N1 | Observe an ordinary telegraph on A while B watches; repeat with inventory open, muted audio and reduced effects. | Target identity/life, guardian generation, warning/deadline, first readable frame on A/B and actual pose at resolution. Missing instrumentation stays pending; no new probe is authorized here. |
| N2 | Use supported network simulation, recording actual configured latency/jitter/loss and measured arrival delays where available. Repeat cold join, late observer and stream-out/re-entry. | Distinguish instance arrival, asset readiness, rendered pose and warning. Missing model, late cue or stale state never enables damage. No arbitrary acceptable latency/window is approved by this guide. |
| N3 | Reset/disconnect the targeted character during telegraph; observe its replacement and a second player. Repeat a replaced/removed guardian only if separately authorized. | Old attack must not bind to a new character life, another player or guardian generation. Record cancellation, residual animation/cue and fresh target selection; damage stays disabled. Reset-related health changes are not guardian damage. |
| N4 | If a future dedicated cue/acknowledgement design is authorized, test delayed, absent, duplicated, forged, out-of-order and prior-life acknowledgements without damage. | Bind evidence to server-issued attack, target, character life and guardian generation. An acknowledgement, proximity, stream request or replication receipt is not proof of displayed pixels. Do not ship a client-controlled damage/immunity decision. |

A dedicated target cue, minimum actionable warning window and missing-readiness policy remain design decisions requiring acceptance and separate implementation/TDD. This checklist neither chooses them nor authorizes a harness. Keep the guard until a reviewed, separately authorized solution has appropriate evidence.

## 4. Fake-store persistence contracts — design only

Do not call real DataStore, enable API access, use production identities/data or create an experience/store. Future isolated local test doubles need explicit implementation scope first; their results cannot prove Roblox cross-server behavior. Preserve session-only UI until durable saving is actually authorized and verified.

Candidate contracts for that future unit: one revisioned player record containing registered creatures and banked eggs, unique IDs across both lists, atomic egg removal plus pet insertion, and immutable retry inputs. These are test prerequisites to confirm in design, not implemented or accepted schema.

| ID | Fake-store failure/interleaving to model | Expected invariant / evidence to retain |
| --- | --- | --- |
| F1 | Timeout/throw on load; distinguish confirmed absent record from unavailable/malformed record; attempt autosave, leave-save and retry. | Failed/uncertain load cannot turn defaults into a write over valid data. Retain seeded record, load state, every attempted write and unchanged stored value; normal gameplay must not falsely report a durable save. |
| F2 | Seed a loaded UID such as `wb:1`, create a fresh state/server identity, then grant and hatch new items; inject duplicate/malformed IDs across both lists. | No loaded/new UID collision or silent overwrite; reject/quarantine invalid records per accepted policy. Current session counter reset is a known future persistence risk, not a present save feature. Record every generated/loaded UID and collision handling. |
| F3 | Fail before commit, commit then lose response, and retry the same hatch/extraction. | For a successful hatch, exactly one egg is removed and one pet inserted in the same committed record. Never both, neither after reported success, or a resurrected egg from a stale union merge. Record before/after records and commit/response order. |
| F4 | Replay the same operation ID; deliver its response twice; restart the retrying caller. | Exactly one effect; retries preserve the original IDs/payload. Conflicting payload reuse must not create a second award. Record operation identity/result and accepted dedup retention policy; no retention duration is selected here. |
| F5 | Two fake server sessions load the same revision, then interleave save/hatch/extraction commits and delayed old responses. | A stale full snapshot cannot overwrite a newer revision or resurrect consumed eggs. Conflict/retry policy preserves both valid changes or rejects safely; it cannot silently union stale lists. Record revisions, immutable inputs, commit sequence and final record. |

Before any real isolated-store test, obtain explicit destination, operation and credential/session authorization. Real lease/revision/rejoin behavior remains unverified by fake-store results.

## 5. Product decisions before rewards/material changes

Resolve through the parent, one focused question at a time, after the baseline loop. Do not infer requirements from pack examples or select numbers here.

| Unresolved decision | Required acceptance record |
| --- | --- |
| Night/fog reward | Eligible event/player/zone/phase; reward type and amount; deterministic versus random behavior; grant boundary and replay identity. Any probabilities/caps need explicit approval. |
| Materials and loss | Exact material categories and ownership; what is temporary versus extracted; defeat/disconnect behavior; loss rule and protection interaction. Do not extend loss to registered creatures or sealed loot. |
| Reward lifecycle | Whether eligibility resets per night, expedition or another accepted boundary; handling phase changes, repeat extraction and retries. Never infer a duplicate-grant window. |
| Saved scope | Which accepted items/fields are durable and how rewards/materials affect the stable schema. Keep free deterministic Lumipol hatching and session-only messaging until replacement is verified. |

## Next actions, in order

1. Finish the animation operator's real-asset/runtime handoff; parent records fresh regressions and releases sole Studio ownership.
2. Establish two observed client identities, then run C1–C7 and the mobile matrix. Preserve per-client evidence and every blocked slice.
3. Use non-damaging observations to resolve cue/lifecycle gaps; separately scope any needed probe or fix. Keep damage OFF.
4. Settle reward/material decisions, then scope fake-store implementation/tests. Real isolated persistence requires separate explicit authorization.

At session end restore only owned temporary settings/probes, stop Play, verify guards and session-only messaging, and record remaining failures/blockers in the canonical task document. Do not mark full P0 acceptance complete from this checklist.

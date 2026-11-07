# Wildbound capture, extraction and horror

## Objective

Turn the Wildbound prototype into a tense capture-and-extraction horror loop: find a live Lumipol, capture it with some skill, carry it home under threat from La Silueta, register it for good, and go back out for rarer creatures and eggs.

## Problem and why

User, 2026-11-07: walking and picking things up has no risk, collection has no clear logic, and La Silueta never harms anyone. The user wants Steal an Egg's clarity of progress, a sense of expedition, real danger, horror music, and death. Their full brief is the source of requirements; its deliveries A to F are done in order.

## Scope

- Delivery A, capture: a live Lumipol that idles, wanders, notices, flees and hides, and an interactive server-validated capture where failure scares it away.
- Delivery B, extraction: one visible carried creature, registration at a physical camp station, permanent collection, equipped companion.
- Delivery C, guardian and death: La Silueta navigates, chases, attacks and can kill; unregistered captures are lost, registered ones never.
- Delivery D, horror: layered dynamic audio from real events, hiding spots, stamina sprint, a controlled death jumpscare, and a reduced-horror option.
- Delivery E, special egg: one Lumipol egg in a guarded nest, carried, incubated with a timer, hatched and registered.
- Delivery F, progression and polish: camp upgrades, objectives, Spanish UI throughout, phone controls, stability, two-player check.

## Constraints

- Restore point: tag `backup/pre-identity-20261107` (commit `f03a268`), bundle and place copies outside the repo.
- Keep what works; extend existing modules instead of adding parallel rules.
- Server authority for spawning, capture, carrying, registration, damage, death, extraction, hatching and rewards.
- User asked on 2026-11-07 for La Silueta to be able to kill. Read as approval to turn damage on in this unpublished place during delivery C. No publishing.
- User asked for Spanish UI text. Read as overriding the English default for player-facing strings only; code, docs and commits stay English.
- No publishing, purchases, Robux, monetization, DataStore, or new uploads without separate consent. Audio comes from existing Roblox store assets that are verified to load, never invented IDs; own uploads need consent.
- No PvP, no stealing other players' creatures.
- Strict TDD with observed RED then GREEN, fresh-clone Studio runs, conventional commits by exact path, no `.rbxl`, no AI attribution, no push.
- One Studio writer at a time. Another session owns `assets/blender/lumipol-roblox-blockout-v1.blend` and the Lumipol sprite; do not touch it.

## Decisions taken by the parent, for user review

| ID | Decision |
| --- | --- |
| H1 | Capture keeps the existing calm ring and adds a final timed seal tap. Approach speed matters: walking slowly keeps Lumipol curious, running at it makes it flee. The tutorial Lumipol uses wide windows. |
| H2 | Capture skills `capturer_1` and `capturer_2` become live and act per player, so the capture improves with progress, not only with luck. |
| H3 | Player-facing strings move into one Spanish text module, starting with strings touched in each delivery; delivery F finishes the move. |
| H4 | Lumipol stays a provisional primitive model until the user approves uploading a real model. |
| H5 | Damage turns on in delivery C through the existing fair-strike path with this place listed as private, not by removing the safeguards. |

## Mode

- TDD strict, global configuration. Runners: Studio fresh-clone harness, `python -I -B -m unittest discover -s tools -p "test_*.py"`.
- Native review: off, read from global mode.
- Delivery strategy: `ask-on-risk`; local work-unit commits on `codex/wildbound-first-playable`.

## Tasks

- [x] P0 Restore point and audit. Route: inline backup, delegated read-only audit (4+ files). Evidence: tag above; audit gap map in this session.
- [x] A1 Lumipol brain: Idle, Wander, Curious, Alert, Flee, Hide, Captured; reacts to approach speed; hides near cover. Route: delegated, one Studio writer, Opus high. Commit `946afea`.
- [x] A2 Interactive capture: calm ring plus timed seal tap, flee on fail, per-player capture skills, Spanish strings for the capture path. Same writer. Commits `68b7bf3` (seal, wary refusal, Spanish text module), `8e86de9` (capturer skills live).
- [x] A3 Client smoothing and readable reactions on the provisional model. Same writer. Commit `a846fc2`.
- [x] A4 Play check: approach, scare, chase, capture, fail, two-player claim probe, phone captures. Studio Play solo; two real clients and real phones not run.
- [x] B Extraction and registration. Route: delegated, one Studio writer (Opus), instance `81631061-...`, place 122652861404212.
  - [x] B1 Carry slot and rules, with state tests: one carried wild creature apart from the bag, refuge registration idempotent per token, loss on defeat unless warded, registered never lost, slight configurable carry speed. Route: inline in the Studio writer (State, Wild, Text, Record plus their tests). RED State 34/33 (new `register`, `carrying`; 27 older cases whose premise moved: creature no longer a bag item), GREEN 67/0; Record 17/1 (RT-2 needs `carrying`, `discovered`), then 18/0; LumipolWild 46/2, then 48/0; Text 9/1, then 10/0. Commit `0368779`. Play evidence is in B5.
  - [x] B2 Visible carried capsule (server-built, replicated) and fear cues from the existing threat signal; HUD name and state; sound hook only. Route: inline, new pure `WildboundCarry`. Carry 0/9 against a stub, 8/1 until the server wiring, then 9/0; Text 10/0. Commit `d1323d3`. Play: capsule, calm, uneasy and afraid seen.
  - [x] B3 Refuge station "Registrar criatura": deposit animation, presentation card, collection entry. Route: inline, new pure `WildboundRefuge`. Refuge 0/8 against a stub, 7/1 until the server wiring, then 8/0; Analytics 35/2 and Wiring 10/1 (`first_register`), then 37/0 and 11/0; PromptKeys 5/1, then 6/0; Economy 18/1 (the deposit loop used `task.wait`, banned by AFK-1; now a tweened clock), then 19/0. Commit `d41c602` (with the B4 wiring). Play: register, card, idempotent repeat.
  - [x] B4 Display spot, storage chest, upgrade board and incubator placeholder in the camp; map builder and its tests. P0Map 6/6, then 12/0; ForestDress 25/0. Commits `31bdcbf` (builder, live map patched with `buildCamp`), `d41c602` (wiring). Play: chest, board, display.
  - [x] B5 Server-owned replicated companion that follows, pulses and survives death; Play check and phone captures. Refuge 9/1 (wiring), then 10/0. Commit `26d3435`. Play check all PASS, see `docs/mechanics/wildbound-extraction.md`.
- [ ] C Guardian navigation, damage and death.
- [ ] D Horror audio, hiding and stamina.
- [ ] E Special egg and incubator.
- [ ] F Progression, Spanish UI, phone polish, two-player check.

## Acceptance

The brief's acceptance list, checked one delivery at a time. Nothing is marked done without an observed test or Play result.

## Progress

- 2026-11-07: restore point made. Audit: Lumipol brain has Wander, Curious, Reserved and Spooked only; capture ring, flee on fail and server claim exist; carried creatures are invisible; no audio anywhere; Silueta uses anchored steering, not pathfinding, and damage is gated off; UI strings are English and scattered.
- 2026-11-07, delivery A (one Studio writer, instance `81631061-...`, place 122652861404212, verified read-only before the first edit). Fresh-clone Studio suites: baseline 760 passed (the brief said 757; the 760 includes SiluetaHunt 9 and SiluetaVisual 26), final 815 passed, 0 failed over 33 suites. Python `unittest discover -s tools`: 876 run, 1 known failure `test_lumipol_v2.test_v1_files_are_unchanged` (another session's uncommitted `lumipol-roblox-blockout-v1.blend`, not touched), 28 skipped. All 72 deployed sources match the repo by Adler-32 and length. `damageMode` off, `privateTestPlaceIds` empty, `analyticsMode` off, streaming on; Studio left in Edit mode, Device Simulator at default, temporary runner modules removed.
- RED then GREEN, per unit: brain 24 passed 22 failed, then 46 and 0. Text module 0/9 against an empty stub, 8/1 until the consumers moved, then 9/0. Capture rule 99/21, then 120/0 (seal, wary, words removed); then 120/4 for the skills, then 124/0. Capture view 29/18, then 47/0; 47/1, then 48/0. State 60/1, then 61/0; Economy 18/1, then 19/0; CampView 20/1 (pinned capturer_1 as pending), then 21/0. Analytics wiring 10/1 (`SealMissed` not in the vocabulary), then 11/0. Look module 0/10 against a stub, then 10/0. Deploy manifest test 23/1, then 24/0 (twice, one per new pair).
- Play (Studio solo, damage off), details in `docs/mechanics/wildbound-capture.md` (A4): slow approach stays Curious PASS; running in gives Alert, Flee, Hide PASS on wild slots (the gentle `S0a` only reached Alert when sprinted into and then calmed); four calm-plus-seal captures PASS; seal miss with flee and the 6 s retry PASS; server two-session claim probe PASS (30 of 30 `Reserved`, 30 of 30 `InvalidToken` during a real capture). Phone captures `assets/exports/forest-kit/captures/a-*.jpg` (iPhone 17 Pro and Galaxy A06, landscape), each viewed; the seal and result frames were fed by a server display push because the live seal lasts about 2 s.

## Decisions taken in delivery A, for user review

| ID | Decision |
| --- | --- |
| A-1 | Brain thresholds (hypotheses): calm speed 8 studs/s, alert radius 14, close radius 7, alarm 0.2 s for Alert and 0.8 s for Flee; Safe slots 12, 10, 5, 0.4 and 1.2. Alert holds 1 s after the last fast move; Hide 4 s plus a 2 s peek. |
| A-2 | Leash widened from 10 to 24 studs (configurable per brain) so the dressed map's props, 12 to 25 studs from the slots, count as cover. With no cover in reach the Lumipol backs away 8 to 12 studs and hides in the open. |
| A-3 | A start is refused (`Wary`) while it is Alert, fleeing, or hiding before its peek, and the prompt hides then. A peeking Lumipol can be calmed. |
| A-4 | Seal: 0.4 s wait, 1.6 s sweep, band 0.20 of the bar (0.36 on Safe slots) placed by a server roll in 0.30 to 0.95; a press counts up to 0.15 s after the marker leaves the band (latency allowance); a press before the marker moves is ignored; no press ends `SealMissed`, which flees, starts the retry wait and counts as a failure. |
| A-5 | The capture rule keeps no words: its purity contract bans `require`, so `CaptureSession.NOTICES` was removed and the server fills `notice` from `ReplicatedStorage.WildboundText`. Other HUD strings stay English until delivery F. |
| A-6 | Capture skills are clamped in the rule: meter target 4.0 to 4.5 s, retry wait 3 to 6 s. No seal-band skill was added. |
| A-7 | No crouch was added: keyboard players walk 16 studs/s, so on a keyboard a slow approach means stopping short; a thumbstick can walk slower. Delivery D's stamina sprint may add a sneak. |
| A-8 | A Studio-only, server-only `ServerStorage.WildboundTelemetry.CaptureProbe` drives `probe:` keys for the claim check. It is never created outside Studio and no client can reach it. |
| A-9 | The "!" is two neon parts because a `BillboardGui` never showed in MCP captures; the tutorial card now waits while a capture result shows (it covered the result line on phones). |

- 2026-11-07, delivery B (one Studio writer, same instance and place, verified read-only before the first edit). Baseline 815 passed over 33 suites, matching delivery A. Final 851 passed, 0 failed over 35 suites (new Carry 9 and Refuge 10; State +6, LumipolWild +2, Text +1, Analytics +1, PromptKeys +1, P0Map +6). Python `unittest discover -s tools`: 876 run, the same 1 known failure `test_lumipol_v2.test_v1_files_are_unchanged` (another session's `.blend`, not touched), 28 skipped. 78 of 78 deployed Wildbound sources match the repo by Adler-32 and length (the Rescue prototype is not in this place). `damageMode` off, `privateTestPlaceIds` empty, `analyticsMode` off, streaming on; Studio left in Edit, Device Simulator at default, temporary runner removed.
- Play (Studio solo, damage off; iPhone 17 Pro then Galaxy A06 landscape): every step PASS, details and captures in `docs/mechanics/wildbound-extraction.md`. Camp layout: refuge (-152, 128), display pedestals X -160 at Z 136 to 148, chest (-147.5, 140) with its prompt on `ExtractionMarker` (-146, 140), board (-150, 154), incubator (-136, 158).

## Decisions taken in delivery B, for user review

| ID | Decision |
| --- | --- |
| B-1 | The carried creature has one slot apart from the bag. The capture rule's `bagRoom` now means "carry slot free", so its `BackpackFull` ending reads "Ya llevas una criatura..."; State refuses a second grant `AlreadyCarrying`. A full bag no longer blocks a capture. |
| B-2 | A trip ends at the first camp station that takes something, chest or refuge: base Ember, companion bond and the first seal are paid there once; the other station pays no second base. |
| B-3 | The old single "Extract" prompt became the storage chest ("Guardar en el cofre", same marker and key E). It stores the bag and pouch permanently and never takes a creature. |
| B-4 | Registration token: the carried creature's uid, picked by the server (no client token). A repeat succeeds with `repeated = true` and pays nothing. |
| B-5 | Carry cost `CREATURE_CARRY_SPEED` 14 studs/s (from 16), configurable in `WildboundLumipolWild.CONSTANTS`; Light Load applies; always above Silueta's 8. |
| B-6 | Fear from the existing threat reading: afraid when Silueta hunts within 40 studs in the fog, uneasy within 80 (or anything within 40). Sound hook only on a rising mood, at most once per 8 s, no Sound instance; carrying adds nothing to Silueta's senses. |
| B-7 | Seals and totems ward the carried creature like a bag item (SealNewest picks it first); a capsule at the shelter registers it; a strike drop (D6) still takes bag items only, left to delivery C. |
| B-8 | Co-op display: one pedestal per player, first come first served (4), showing the equipped or first registered Lumipol with "de <name>"; everyone sees every spot and none has a prompt, so no one can take another's. |
| B-9 | Companion: server-built, AlignPosition to an attachment in the owner's root with no reaction force, owner holds network ownership; the client-only companion is gone. A pulse sets `WildboundPulseAt` on the player (world server) for every client's flash. |
| B-10 | Incubator is a placeholder with signs and no prompt; the old free hatch prompt stays until delivery E. |
| B-11 | Camp keys: refuge V / R1, board B / L2 (F, Q, X, G, C, I and M are taken). Signs carry a `SignKey` and are filled from `WildboundText.CAMP` by the server. |
| B-12 | Analytics: new `first_register`; the refuge ends an open trip as `extracted`. |
| B-13 | Studio-only, server-only `CarryProbe` (writes `probe:` keys only) for the ownership check, like A-8. |
| B-14 | The schema-1 saved record does not hold the carry slot (at risk, like the bag); `discovered` is rebuilt from registered species. |

Next: delivery C, guardian navigation, damage and death. Not verified: real touch, real phones, two real clients (display and companion replication to a second client), companion on slopes and stairs, latency, portrait, whether the camp feels cozy to players. English left on the delivery B path: the tutorial card ("press Extract"), the loss summary and the Camp screen (delivery F).

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
- [ ] B Extraction and registration.
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

Next: delivery B, extraction and registration. Not verified: real touch, real phones, two real clients, network latency against the seal allowance, portrait seal panel.

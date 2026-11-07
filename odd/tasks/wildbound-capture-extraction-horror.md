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
- [ ] A1 Lumipol brain: Idle, Wander, Curious, Alert, Flee, Hide, Captured; reacts to approach speed; hides near cover. Route: delegated, one Studio writer, Opus high.
- [ ] A2 Interactive capture: calm ring plus timed seal tap, flee on fail, per-player capture skills, Spanish strings for the capture path. Same writer.
- [ ] A3 Client smoothing and readable reactions on the provisional model. Same writer.
- [ ] A4 Play check: approach, scare, chase, capture, fail, two-player claim probe, phone captures.
- [ ] B Extraction and registration.
- [ ] C Guardian navigation, damage and death.
- [ ] D Horror audio, hiding and stamina.
- [ ] E Special egg and incubator.
- [ ] F Progression, Spanish UI, phone polish, two-player check.

## Acceptance

The brief's acceptance list, checked one delivery at a time. Nothing is marked done without an observed test or Play result.

## Progress

- 2026-11-07: restore point made. Audit: Lumipol brain has Wander, Curious, Reserved and Spooked only; capture ring, flee on fail and server claim exist; carried creatures are invisible; no audio anywhere; Silueta uses anchored steering, not pathfinding, and damage is gated off; UI strings are English and scattered.

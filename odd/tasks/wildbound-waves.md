# Wildbound delivery waves

## Objective

Keep agents advancing the whole game in waves, from the current baseline through F1, F2 and expansion content, as far as work can run without people or new consent.

## Problem and why

`docs/wildbound-roadmap.md` stops expansion behind gates F1 and F2. On 2026-11-07 the user asked to go further: finish what can be reached toward F1, add F2, and add more biomes, creatures, Blender work and design.

## User decisions, 2026-11-07

- Tiers: Opus 5.5 high for design-heavy waves, never extra. Sonnet 5.5 high for work that does not need Opus. Haiku 5.5 extra for reading.
- Expansion work may proceed before F1 and F2 are proven. Advised risk, accepted by the user: content built before the loop is proven fun may need rework. Anything built this way is labelled unvalidated.

## Constraints

- Gates F1 and F2 need human testers. Agents never mark them passed.
- At most three agents at once. One writer per script set, Studio scene or Blender scene.
- Needs separate explicit approval: each asset upload, publishing, monetization, turning damage on outside a private test, and creating the isolated persistence experience (D8).
- Overnight rule, user on 2026-11-07: "take decisions, I will review later; prioritize finishing and advancing, do not ask". Agents decide and record; they do not stop to ask, except on the approvals above, which they skip and report.
- That rule was not read as consent for permanent or public actions. No uploads, publishing, monetization or isolated experience tonight. Work needing them stops at local output.

## Decisions taken by the parent for later user review, 2026-11-07

All follow the roadmap section 5 recommendation. All values are hypotheses and can be changed.

| ID | Decision taken |
| --- | --- |
| D2 | Fair strike combines persistent model, dwell gate, target warning with acknowledgement, staged strike and camp preload, behind `damageMode`, default off. Streaming stays on; option F is not used. |
| D3 | Capture: hold still inside a slowly moving ring with a wide timing window, about 4 to 6 s, one thumb. |
| D4 | One-owner claims, with spawn slots scaling by player count. |
| D5 | 12-minute cycle, random non-Night start, 3 to 8 minute expeditions, one night-only resource. |
| D6 | First strike marks and drops one bag item, second defeats, no regeneration in fog. |
| D10 | Disconnect is not a defeat; pending loot expires after about three minutes. |
| D11 | Reduced effects off by default, offered on the first start screen. |
| D14 | One active companion for the first release. |
| D16 | Keep binaries in git for now. |

Not taken: D8 isolated experience, D9 tool installs, D12 testers, D13 languages, D15 final thresholds. These need the user.
- Original IP only. No recreation of existing games, characters or art. Designs are proposals until the user approves them.
- Strict TDD with observed RED and GREEN. Studio target is reconfirmed in each new session.
- Commits per work unit by exact path, no `.rbxl`, no AI attribution, no push.

## Tasks

| ID | Wave | Work | Route | Status |
| --- | --- | --- | --- | --- |
| W0 | 0 | Dress the map, LOS rule | Sonnet, Studio writer | Running |
| W1a | 1 | Stale banners, M0.2 | Haiku | Running |
| W1b | 1 | Deployment manifest, M0.3 | Sonnet | Done, `823389f`, 24 tests |
| W1c | 1 | Lighting, Play route, captures, T7 | Sonnet, Studio writer | After W0 |
| W2a | 2 | Hash comparison, 80 contracts, natural cycle, C1 to C7, M1.1, M1.5, M1.6 | Sonnet, Studio writer | After W1c |
| W2b | 2 | Fair-strike proposal, M4.1 | Opus high | Pending |
| W2c | 2 | Silueta pressure simulator | Sonnet | Pending |
| W3a | 3 | Awareness rule with contracts, M2.1 | Opus high | After W2a |
| W3b | 3 | Server and HUD wiring, M2.2, M2.3, M2.6 | Sonnet, Studio writer | After W3a |
| W4a | 4 | Capture and economy proposals, M3.1, M5.1 | Opus high | Pending |
| W4b | 4 | Lumipol v2 and search pose clip, local only | Sonnet, Blender | Pending |
| W5 | 5 | Skill capture code, M3.2 to M3.5, no uploads | Opus high, Sonnet | After W3 |
| W6 | 6 | Fair damage code, M4.2 to M4.8, `damageMode` default off | Opus high, Sonnet | After W5 |
| W7 | 7 | Reason to return code, M5.2 to M5.8 | Opus high, Sonnet | After W6 |
| W8 | 8 | Camp, nest and shelter art, local | Sonnet, Blender | Pending |
| W9 | 9 | Start screen, tutorial, quick bar, settings, M8.5, M8.6 | Sonnet, Studio writer | After W7 preferred |
| W10 | 10 | Persistence schema, fake-store contracts, M6.1, M6.2 | Opus high | Pending |
| F1 | Gate | Ten testers. Agents prepare the kit and analyze results | Humans | Needs people |
| W11 | 11 | Expansion bible: biomes, species, guardians, Blender specs | Opus high | Running |
| W12 | 12 | New species models and rigs, local, E1 | Sonnet, Blender | After W11 |
| W13 | 13 | El Vigia and Yeti models and rigs, local, E3, E5 | Sonnet, Blender | After W11 |
| W14 | 14 | Living Forest and Frozen Mountains kits and layout plans, local, E4, E5 | Sonnet, Blender | After W11 |
| W15 | 15 | Rock and Caves, Volcanic Lands, Cryptic Ruins, Demon Abyss kits, local, E6 | Sonnet, Blender | After W14 |
| W16 | 16 | F2 kit: analytics funnel, retention targets proposal, M9.5 | Opus high, Sonnet | Pending |
| W17 | 17 | Import and integrate expansion in Studio | Sonnet, Studio writer | Needs upload consent and place decision |
| F2 | Gate | Beta data from real players | Humans | Needs people and approved beta |

## Acceptance

- Each wave reports observed checks, and failures honestly.
- Local art has an editable source, an export, spec tests and a render a person can open.
- Nothing is uploaded or published without explicit approval.

## Progress

- 2026-11-07: plan created from the user's request. W1b committed.

## Next step

W0 finishes, then W1c. W11 output feeds W12 to W15.

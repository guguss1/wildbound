# Game workspace instructions

This workspace is for one Roblox game, **Wildbound**. Keep game code, tasks, and decisions here.

## Start here

Read in this order before planning or editing:

1. `docs/wildbound-game-overview.md`: the master overview and source of truth for status. Section 13 is the status matrix, section 14 lists open decisions, owner actions and risks, section 16 lists outdated docs and doc/code contradictions.
2. `docs/wildbound-roadmap.md`: milestones and gates F1 and F2. Older than the overview; where they disagree, the overview wins.
3. The ODD task file for the feature in `odd/tasks/`. The main log is `odd/tasks/wildbound-capture-extraction-horror.md`; its latest sections may be newer than the overview snapshot.
4. The relevant design or mechanics doc under `docs/`.

Conventions:

- Status lives in the overview (section 13) and in the ODD task files. Use the overview's status words: Done (wired, Studio suites passed, solo Play checked), Prepared (in the repo, not wired, suites not run), Design only, Not started. Never call something verified with two players or on a phone unless a doc records it.
- ODD task convention: each feature has one file, `odd/tasks/<feature>.md`, with objective, scope, a checklist with stable task IDs, evidence, and the next step. Tick a box only after an observed result, and record the commit and checks beside it.
- Design docs under `docs/design/` are proposals unless the overview marks the feature as Done. Section 16 of the overview names the outdated ones.
- The full documentation map, with one line per doc, is in `README.md`.

## Shared knowledge

Before designing, consult `C:/Users/Jesus/Documents/Roblox/roblox-codex-starter/knowledge/INDEX.md` and relevant notes it references. The shared library is read-only unless the user explicitly permits changes. Video advice is a hypothesis to test, not an official requirement or a guarantee.

## Safety and verification

- Before any Studio edit, verify the Studio instance and place, then obtain the user's confirmation of that target.
- Never publish or change monetization without explicit approval.
- Validate sensitive client requests on the server. Design persistence so failed loads cannot overwrite real player data; handle purchases atomically if ever approved.
- Design for touch and readable, adaptable UI; test on mobile devices where available. Measure performance and test gameplay before drawing conclusions.

## Design references and current scope

The project is now Wildbound, a Nest Heist horror game: steal an egg from a guarded nest in a foggy forest, carry it home past La Silueta, beasts and other players, and hatch it into a companion. The early horror map blockout and session rescue prototype are legacy (`docs/legacy/horror-map-and-rescue-prototype.md`). The current direction and its user decisions are in `docs/design/wildbound-combined-plan.md` section 6; what is actually built is in the overview.

Earlier Studio targets were confirmed per session only; reverify the instance and place and obtain confirmation in every new session before Studio edits. Design docs, the beast pack, reference images and screenshots guide exploration; they are not verified behavior or authorization to implement mechanics. Do not implement a design that the user has not requested.

- A quick first action and reward remains a hypothesis to test.
- Robux offers are design only. Nothing is purchasable (`monetization = "none"`); no design doc authorizes monetization.
- Damage stays off outside the private test place; turning it on elsewhere needs explicit approval.
- Each asset upload, publishing, and any isolated persistence experience needs separate explicit approval.

## Local Roblox skill routing

Read `docs/skill-packs.md` for the four guarded project skills: `game-roblox-mechanics`, `game-roblox-ui-ux`, `game-roblox-playtester`, and `game-roblox-map-builder`. Original packs are local reference material; Wildbound designs are proposals, not approved game requirements. Current user instructions, English artifact defaults, and the safety rules above take precedence.

## Agent routing

Read `docs/agent-routing.md` before delegating. Current preference: GPT-6.1 Sol / `medium` for the parent; Luna / `high` for research, Terra / `medium` for bounded implementation, and Sol / `high` for critical analysis. Keep at most three concurrent subagents, parent integration, and one writer per overlapping script set or live scene. No nested delegation without parent approval.

Load `.agents/skills/wildbound-fast-mode/SKILL.md` for explicit `rápido` / `rapido` or fast-mode requests, not incidental gameplay-performance wording. That explicit route intentionally overrides the economical defaults with Sol / `xhigh`. Configuration and skills do not hot-switch the running parent; preserve every safety, TDD, functional-check, and native review requirement. This configuration does not authorize Studio edits, publishing, monetization changes, or changes to approvals, security, MCP, or native review mode.

# Roblox project start skill

- Objective: create a reusable, explicitly invoked Roblox project onboarding skill and install it for the user after review.
- Problem: game projects need a safe, evidence-aware entry point into a separate, evolving Roblox knowledge library.
- Authorized scope: workspace skill source and validation, skill registry refresh; parent handles bounded user-level installation. No new games, Studio writes, Play, plugin installation, ambient credentials, or unrelated projects.
- Library: `C:\Users\Jesus\Documents\Roblox\roblox-codex-starter`; resolve as library separately from the current game. Read existing game instructions before proposing changes. Treat library as read-only absent explicit authorization.
- Invocation: explicit only (`policy.allow_implicit_invocation: false`). Read-only onboarding by default; an explicitly requested setup may prepare game AGENTS instructions only after a focused direction question and user response. Preserve existing instructions and conflicts; never copy the library AGENTS wholesale.
- Evidence: dynamically inventory actual mechanics on each invocation, including an empty folder; identify provenance, timestamps and verification states. The existing video is conceptual design, not verified Luau mechanics. First-minute timing targets are hypotheses.
- Route: delegated direct; multiple non-trivial files and preparatory reading required. Parent reviews this document before source writes. Parent owns final installation and decision log.
- TDD: unknown/not applicable to instruction-only skill; no project configuration or explicit user test mode supplied. Apply ordinary structural and behavioral validation; bundled `quick_validate.py` is the exact structural runner.
- Delivery: `ask-on-risk`; forecast under 400 authored changed lines; Git check failed (not a repository); no commits or Git initialization.
- Engram mirror: pending; attempted full document save returned unknown_project (project not backed by known context); do not invent a session or select an unrelated project.
- Acceptance: explicit-only metadata, honest library/game distinction and evidence reporting; one question then stop; no unrequested actions; isolated scenarios and structural validation; installation does not overwrite an existing skill.
- [x] T1 — Parent inspected task document before writes; created workspace skill instructions and explicit-only policy. Source and user target did not exist. Structural validator passed. Git/commit unavailable; Engram mirror pending.
- [x] T2 — Structural validation passed; registry and `.gitignore` updated. Parent installed the two files to `C:\Users\Jesus\.codex\skills\roblox-project-start`, verified matching SHA-256 hashes and explicit-only policy, and appended the durable decision to `knowledge/DECISIONS.md`. Four independent read-only simulated scenarios passed: real library with hypothetical game, inaccessible library, restrictive game instructions, and explicit setup with unknown game and direction (path and direction resolved in separate turns). These are simulations, not native fresh-chat integration. Parent final installed-target validator rerun passed after the distinct-game guard; final SHA-256 hashes match for both files.
- Evidence: bundled `quick_validate.py` passed on workspace source and initial installed target. Registry has 112 skills, one duplicate `skill-creator` and zero frontmatter errors; it points to the workspace source. `.atl/` was added to `.gitignore`. Engram task and registry mirrors remain pending after `unknown_project`. Git is unavailable; no commits were created.
- Next: invoke `$roblox-project-start` from the desired game project. Native skill picker discovery in a fresh chat or after reload remains unverified.






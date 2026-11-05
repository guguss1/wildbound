# Wildbound agent routing

## Objective and authorized scope
Apply the user's latest preference: multiple GPT-6.1 Sol agents with Very High reasoning (`xhigh`), plus an explicit `rápido` / `rapido` routing skill. Defer the earlier economical Luna/Terra architecture until a fresh user request. Preserve memories, skills, unrelated settings, and gameplay work. Broader master-prompt onboarding is handled separately by the parent; this unit does not implement gameplay. No Studio/Blender edits, installs, publication, purchases, or prototype development.

## Approach
One delegated configuration work unit (FAST-1), forecast under 350 authored lines; delivery strategy ask-on-risk, no PR requested. Parent owns validation, memory mirror, commit, and integration. Preparation/mapping and multi-file writer triggers apply. Configure Sol/xhigh for the root and specialized agents, with a three-subagent concurrency cap. Do not activate Luna/Terra or extract/install a claimed 32-skill pack.

## Tasks
- [x] FAST-1: Back up global configuration; set Sol/xhigh and three-subagent cap; add research/builder/critical role definitions, fast-mode skill, routing guide, AGENTS registration, and registry entry. Verified and committed as `c470693`.
  - Route: delegated; preparation/mapping and multiple non-trivial files require a bounded writer.
  - State: configuration checks passed with the pre-existing strict-startup exception below. Commit `c470693`: 154 lines; initial native assessment medium/under_budget. User subsequently disabled native RDD globally; effective outcome now disabled/unmanaged, not approval.
- [ ] ROUTE-1 (deferred, not authorized now): Resume the economical architecture only after a fresh user request. Historical intent: Sol Medium parent; Luna High research; Terra Medium bounded visual/UI/simple changes; Sol High critical work. Audit available skills before any role activation.

## Acceptance and checks
- Preserve unrelated files and existing skills/configuration; backup global configuration before a minimal edit.
- Configure `model = "gpt-6.1-sol"`, `model_reasoning_effort = "xhigh"`; set supported default-subagent preferences and `agents.max_concurrent_threads_per_session=3`. Preserve all other global settings and verify the exact backup and bounded delta.
- Trigger the skill only for a user request for fast mode (`rápido` / `rapido`), not incidental gameplay-performance wording. Very High reasoning may take longer and cost more; the keyword is not a speed guarantee.
- A skill/config edit cannot hot-switch the running parent. If no verified runtime control exists, use an explicitly selected Sol/xhigh worker for bounded non-trivial work; avoid unnecessary workers for trivial direct tasks. Disclose the limitation once; never claim an unobserved runtime change.
- Keep at most three concurrent subagents using native config plus parent scheduling; no nested spawning without parent approval. Single writer per live scene or overlapping script set; parent reviews before integration.
- No priority/speed-tier, approval, security, MCP, credential, or monetization changes. Preserve all existing correctness, TDD, RDD, and Studio safety rules.
- Installed CLI 0.166.0-alpha.6: strict startup config validation and bundled model catalog checks, no paid model calls needed for validation.
- TDD: enabled by `strict_tdd=true` in `C:/Users/Jesus/.gentle-ai/state.json`; config-only PowerShell RED and Python 3 standard-library structural GREEN. RED: fast-mode skill absent and configured effort medium (not requested xhigh), observed before source writes. GREEN: skill metadata/sections/references, bounded config delta and backup, bundled model catalog, role files, isolated strict CLI startup. Gameplay test runner: N/A, no gameplay changes.
- Functional checks: skill discovery metadata/registry references, TOML parsing, supported model/effort, strict Codex config startup, git diff --check. Runtime: N/A (configuration only); current-parent hot-switch and newly created skill discovery are not verified by file writes and must be reported pending next-turn/session discovery.
- Native RDD: user explicitly disabled it globally during closure; verified OFF. Do not start or request reviews. Ordinary correctness and security checks remain required.

## Evidence and next step
- Initial global model gpt-6.1-sol / medium; agents.max_threads=4 (legacy alias), max_depth=2. Replace the legacy concurrency alias with the supported explicit three-subagent key; preserve depth.
- Official documentation supports standalone named agent TOML and agents.max_concurrent_threads_per_session (excludes primary); local strict-config accepts canonical concurrency and default subagent fields.
- Latest user instruction supersedes both the economical plan and intermediate Ultra request: multiple Sol agents with Very High (`xhigh`) now. ROUTE-1 remains deferred.
- Exact global backup: `C:/Users/Jesus/.codex/config.toml.fast-mode-20261104-221032808.bak`; SHA256 `7FB398BE75F599CA40C48E5A24001E84B2EF2CD9A335DD962FD20A8F334D5A89`. Byte/semantic comparison confirms only effort, canonical concurrency, and default-subagent preferences changed; root Sol and max_depth=2 preserved.
- GREEN (Python structural assertions): global TOML and bounded byte delta; local catalog supports Sol/xhigh; all three named role TOMLs and required fields; skill frontmatter, description length, section order/local reference; AGENTS registration; 21 unique registry entries with existing paths; strict_tdd=true preserved. Registry scan retained its three sources and all prior rows; no claim of 32 installed runtime skills.
- GREEN: exact desktop CLI `0.166.0-alpha.6` ordinary `app-server --print-startup-config`; isolated requested settings pass `--strict-config` with exit0/startup JSON. No paid model calls. Temporary config removed after validation.
- FAILED full strict startup: unchanged original `computer_use.windows.always_allowed_app_ids` at global config line213 is unknown to this CLI. The field exists in the original backup; no unrelated/security settings changed. First isolated harness JSON parsing also failed on a warning prefix; corrected harness checks exit0/startup JSON and passes.
- GREEN: `git diff --check`; existing CRLF normalization warnings only. Gameplay/runtime tests N/A (no gameplay changes). Current-parent hot-switch, new skill/role discovery, and actual role dispatch remain unobserved; check next turn/session rather than claiming activation.
- Existing dirty gameplay files remain outside this task. Parent inspected and committed the isolated work unit; startup and selected settings independently verified. Final mirrors are synchronized at closure; ROUTE-1 remains deferred. Runtime discovery/dispatch and the pre-existing strict-startup exception remain explicitly pending, not hidden by task completion.

## Rollback
Remove only FAST-1 skill/guide/registration entries and restore the exact global configuration backup if its preconditions still match; preserve all prior gameplay changes, skills, and unrelated settings. Never overwrite later user configuration changes blindly.

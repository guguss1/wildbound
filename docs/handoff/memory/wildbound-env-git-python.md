---
name: wildbound-env-git-python
description: On this PC git is only inside GitHub Desktop and Python is not installed; Wildbound repo layout with worktrees
metadata:
  node_type: memory
  type: reference
  modified: 2026-11-16T12:00:00.000Z
---

- `git` is not on PATH. Use `%LOCALAPPDATA%\GitHubDesktop\app-<version>\resources\app\git\cmd\git.exe` (was app-3.6.5 on 2026-11-16; glob for it if the version changed).
- Python is not installed (only the Microsoft Store alias), so the repo's `python -I -B` tools/tests cannot run here; fingerprints (bytes + Adler-32) can be computed in PowerShell.
- The shell is Windows PowerShell 5.1: no `&&`, use `;` or `if ($?) { ... }`.
- Repo `guguss1/wildbound`: main checkout `E:\juego roblox\wildbound`, worktrees `E:\juego roblox\wb-*`.
  - `E:\juego roblox\wb-first-playable` = branch `codex/wildbound-first-playable` (main line of work, pushed).
  - `E:\juego roblox\wb-big4` = branch `agus/big4-map` (four-equal-biome map, pushed; merge into the main line once the owner approves big4).
- Project working rules (Studio fingerprint rule, Play lock, commit style) are in the repo: `docs/handoff/claude-context.md`. See also [[lumipol-rig-pipeline]].

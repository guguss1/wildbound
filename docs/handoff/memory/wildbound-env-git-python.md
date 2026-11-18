---
name: wildbound-env-git-python
description: On this PC git is only inside GitHub Desktop and Python is not installed; Wildbound repo layout with worktrees
metadata:
  node_type: memory
  type: reference
  originSessionId: b48f9822-0027-4b6a-b224-83ece34b8d29
  modified: 2026-11-16T22:00:00.293Z
---

- `git` is not on PATH. Use `C:\Users\Agustina\AppData\Local\GitHubDesktop\app-<version>\resources\app\git\cmd\git.exe` (was app-3.6.5 on 2026-11-15; glob for it if the version changed).
- No standalone Python, BUT Blender's bundled Python 3.11 works for the repo tools/tests: `& "C:\Program Files\Blender Foundation\Blender 5.0\5.0\python\bin\python.exe" -I -B -m unittest discover -s tools -p "test_*.py"` (used successfully 2026-11-12; ~1272 tests, known failure test_lumipol_v2.V1IsKept). The handoff docs wrongly say Python can't run here.
- Owner prefers no questions mid-work: decide, record under "Decisions taken for the user" in the task doc; agents on Opus medium, max 3 non-Studio + 1 Studio writer (rules in `docs/handoff/claude-context.md`).
- Repo `guguss1/wildbound`: main checkout `E:\juego roblox\wildbound`, user's own branches `agus/*` each in a `E:\juego roblox\wb-*` worktree (local only, not pushed as of 2026-11-15). The teammate's branch `codex/wildbound-first-playable` lives in worktree `E:\juego roblox\wb-first-playable`.
- Project working rules (Studio fingerprint rule, Play lock, commit style) are in the repo: `docs/handoff/claude-context.md`. See also [[lumipol-rig-pipeline]].

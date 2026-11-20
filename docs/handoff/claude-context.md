# Claude working context (sanitized for a public repo)

This file carries the working rules and preferences that Claude Code kept in its local memory for this project. It lets another machine or session continue the same way. Personal data, verbatim user messages, session ids and people's names were removed on purpose, because the repository is public.

## User preferences

- **Language:** reply in the user's language. The user writes in Rioplatense Spanish; plans and task breakdowns shown to the user go in Spanish too. Code, identifiers, comments, repo docs and commit messages stay in English. Player-facing UI copy is neutral Spanish and lives in `WildboundText`.
- **Agents:** run delegated agents and workflow agents on Opus at medium effort.
  - Use as many as the work needs: at most three concurrent agents that don't touch Studio, and only one Studio writer.
  - While the user is using the PC, agents run in the background only (no computer-use).
- **Plain Spanish:** summaries and any question to the user explain every term in simple words, without internal task codes.
- **Don't block on decisions:** the owner wants no questions (2026-11-16); in long batches, take product decisions yourself, record each one in the feature doc under "Decisions taken for the user", and list them at the end. Safety gates still apply (see below).
- **Commits:** Conventional Commits with no AI attribution and no Co-Authored-By line. This is a user rule that overrides tool defaults.
- **Commit scope:** commit only your own paths (`git commit -m "..." -- <paths>`). Several agents share one index, and staging the whole tree once swept another agent's files into the wrong commit.

## Team setup

- A teammate works in the same Roblox Team Create place from another PC, building the "Sonriente" system in the `SistemaSonriente` folders. Never touch those folders.
- During the teammate's stage 1, these scripts were their lock zone: `WildboundServer`, `WildboundState`, `WildboundEggCarry`, `WildboundBatKnock`, `WildboundWorldClient`, and the suites `WildboundEggCarry_Test`, `WildboundBat_Test`, `WildboundMechanicsWiring_Test`.
  - On 2026-11-14 the user allowed small, additive edits there for the playtest fixes.
  - Always pull Studio's live version into the repo before editing.
- Another session (owner unknown) built part of the Caramelo biome directly in Studio. Its task file `odd/tasks/caramelo-bioma.md` and its Blender sources were never in this repo.

## Studio rules that prevent data loss

- Target: Roblox Studio place `122652861404212` (universe `10774749224`, owned by group `465694015`). The Studio MCP instance id changes on every reconnect, so use `list_roblox_studios` and pick the one with this place id. The owner confirmed this place as the target for agent work (2026-11-16 handoff prompt); re-check the place id each session.
- **Fingerprint rule:** before writing any Studio `Source`, compare it with the repo HEAD file.
  - Normalise both first: CRLF→LF, strip trailing newlines, then compare byte length + Adler-32.
  - If Studio differs, Studio is the live truth: pull it into the repo first, read-only, then build on that.
  - After writing, read back and verify Studio == repo.
  - Prefer exact text replacements (`multi_edit`) over full writes.
- **Play lock:** start Play only if Studio is in Edit and `ServerStorage` attribute `WildboundPlayLock` is nil. Set it to your task id while playing, then clear it and stop Play. Never stop someone else's Play; poll `get_studio_state` and wait instead.
- **Edit-mode require cache:** Studio caches module requires in Edit, so a plain `require` gives stale code. Run suites with a fresh loader (`loadstring` + `setfenv`, a custom `require` that loads `Wildbound*` modules from their `Source`). See `tools/studio-fresh-runner.luau` and its `SPECS` table for each suite's arguments.
- The place is not saved by agents. Some state lives only in the open Studio session until the owner presses Ctrl+S (see the handoff).
- **WildboundServer local limit:** it is at Luau's 200-local limit (test NH-W13). New code goes inside `Heist.*` tables or `do ... end` blocks.

## Safety gates (need the user's explicit OK)

- Publishing, monetization changes and place saves.
- Asset uploads, unless the user authorised that specific upload.
- Remote operations other than pushing this repo's branch.
- Turning on damage outside the private test place.

## Asset ownership (important)

- The game is owned by a Roblox group, and Roblox only plays animations owned by the experience owner.
- Uploads made through the Studio MCP / Open Cloud route are created as the user, not the group. That route returns 403 for group uploads and has no `asset-permissions:write` scope.
- So user-owned animations never play in the game, and user-owned images (hotbar icons) fail with "Requester does not have permission".
  - **Fix for animations:** the owner publishes them to the group from Studio with "Save to Roblox", Creator = group.
  - **Workaround for icons:** to be tested, the `rbxthumb://type=Asset&id=<id>&w=150&h=150` form loaded in a preload test.
- Models (FBX meshes) uploaded as the user did insert and work.
- **Working upload route from this machine:**
  1. Write the file into `assets/exports/...` or `assets/models/beasts/...`.
  2. Upload with Studio MCP `open_cloud_invoke` `POST /assets/v1/assets` (FBX for a Model; one `model/x-rbxm` per KeyframeSequence for an Animation).
  3. Poll the operation.
  4. `insert_asset`.
  - Images go through `upload_image` with a short-lived local `python -m http.server` on 127.0.0.1.
  - Record every id in `assets/exports/caramelo/upload-receipts.md` and in the feature doc.

## Engram (local memory) topics

The local Engram store mirrors the ODD feature docs under these topic keys (the docs in `odd/tasks/` are the source of truth):

- `odd/wildbound-2-0/tasks`
- `odd/wildbound-scuttler/tasks`
- `odd/wildbound-caramelo/tasks`, plus `tasks-part2` and `tasks-part3` (split at the 50k limit)
- `odd/wildbound-playtest-fixes/tasks`
- `odd/wildbound-balance-pass/tasks`

On a new machine, rebuild them from the docs if needed.

## Tools on the owner's Windows machine (updated 2026-11-16)

- The shell is Windows PowerShell 5.1 (no `&&`). `git` is not on PATH: use `%LOCALAPPDATA%\GitHubDesktop\app-<version>\resources\app\git\cmd\git.exe` (app-3.6.5 on 2026-11-16).
- No standalone Python, but Blender's bundled Python 3.11 runs the tools, tests and economy simulator: `& "C:\Program Files\Blender Foundation\Blender 5.0\5.0\python\bin\python.exe" -I -B ...` (confirmed 2026-11-16).
- Claude memory on that PC is one shared folder, `E:\juego roblox\memoria-claude`, linked (Windows junction) from each account's `.claude\projects\E--juego-roblox\memory`; `E:\juego roblox\conectar-memoria-claude.ps1` creates the link for a new account or Windows user (see `HANDOFF-2026-11-16b.md`).
- On a machine with Python 3.11: run tools with `python -I -B`; tests with `python -I -B -m unittest discover -s tools -p "test_*.py"`. The known failure is `test_lumipol_v2.V1IsKept`. If prints fail on cp1252, use `sys.stdout.reconfigure(encoding='utf-8')`.
- Blender 5.0: `C:\Program Files\Blender Foundation\Blender 5.0\blender.exe`.
- Worktrees: `E:\juego roblox\wb-first-playable` (branch `codex/wildbound-first-playable`), `E:\juego roblox\wb-big4` (branch `agus/big4-map`).

## Current handoff

- Latest handoff: `docs/handoff/HANDOFF-2026-11-20.md` (everything of 2026-11-20 in Studio unsaved until the owner saves: Pueblo Gatito long, Toolbox look, Caramelo sky, store UI kit, roulette wheel, UI restyle and T1 thief rank; next T2, then the paused UI polish, P0.2/P0.3, T3..T13, the Bosque and Montañas arms). Before it: `docs/handoff/HANDOFF-2026-11-19.md` (quick move to another PC: OQ1-OQ3 in Studio unsaved until the owner saves, Pueblo Gatito 600 x 1200 coded in `d1a86c1` but not yet in Studio). Before it: `docs/handoff/HANDOFF-2026-11-18.md` (Pueblo Gatito moved to the big4 south arm; the half-done Caramelo v9, a longer plot with a river 5 times wider that the raft sails end to end, with its research, three designs and judges in `docs/handoff/caramelo-v9/`; then the other three arms to 600 x 1200, the park's look and the micro-phases). Before it: `docs/handoff/HANDOFF-2026-11-17.md` (Caramelo harder: what is in Studio, the half-done cake-move and relentless-chase deploy with its mandatory order, later tasks), after `docs/handoff/HANDOFF-2026-11-16b.md` and `docs/handoff/HANDOFF-2026-11-16.md`.
- One task at a time (owner, 2026-11-16), and tell the owner before deploying code so she does not press Play mid-deploy. Account switch guide and first prompt: `docs/handoff/SWITCH-ACCOUNT.md`. Sanitized memory copies: `docs/handoff/memory/`.
- Studio locks: besides `WildboundPlayLock`, never start Play while `ServerStorage` attribute `WildboundImportLock` is set; suites honour `WildboundFreshRunnerLock`.
- Map mode: leave the place in `big4` mode (`WildboundMapModeSwitch`); classic pieces are archived in `ServerStorage.WildboundMapArchive`.
- Never upload code as assets (the two transport Models 104898638172426 and 110244231107381 are for the owner to archive). Never spend Robux.

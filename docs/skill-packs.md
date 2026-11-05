# Local Roblox skill-pack guide

Four guarded project skills route recurring Roblox work. Their original sources are local, ignored reference material—not approved game design or independent authority.

## Quick use

- `$game-roblox-mechanics` for rescue interactions and inventory logic.
- `$game-roblox-ui-ux` for HUD, inventory screens, and touch controls.
- `$game-roblox-playtester` for test planning and evidence.
- `$game-roblox-map-builder` for map layout and greyboxing.

Codex may also match these descriptions automatically when the project skills are discovered. New skills become available on a later turn; restart if they are not visible. Read this guide and the full corresponding original when using a wrapper. A missing local source is a reported limitation, not permission to download or execute a substitute.

## Source inventory

Originals retain their archive layout under `resources/skill-packs/`. To consult another skill, deliberately read its `SKILL.md` and supporting references there; it is not installed as an active project skill. Wildbound content is exploratory, not an accepted design or permission to build a mechanic.

| Pack | Skills (path: `.agents/skills/<name>/SKILL.md`) |
| --- | --- |
| `roblox-codex-skills` | `roblox-playtester`, `roblox-npc-ai`, `roblox-map-builder`, `roblox-data-economy`, `roblox-studio-builder`, `roblox-animation`, `roblox-performance`, `roblox-multiplayer`, `roblox-asset-pipeline`, `blender-3d-artist`, `roblox-mechanics`, `roblox-ui-ux`, `roblox-game-architect` |
| `wildbound-codex-addon` | `wildbound-atmosphere`, `wildbound-creature-blender`, `wildbound-creatures`, `wildbound-encounters`, `wildbound-extraction`, `wildbound-mobile-coop`, `wildbound-monsters`, `wildbound-procedural-map`, `wildbound-progression`, `wildbound-random-reward-policy` |

Source ZIPs were found locally in `C:/Users/Jesus/Downloads/`:

| Archive | SHA-256 | Bytes |
| --- | --- | ---: |
| `roblox-codex-skills.zip` | `421EF7BD46D090B964B4758C3D5AE97C331461EDEA39B78E7D6338601A16C716` | 19016 |
| `wildbound-codex-addon.zip` | `38C5DF7117371326FDFFE0B3C12C3FF043D525A67C40D3D70E8218E507953A5B` | 26180 |

## Boundaries and conflicts

- Provenance, versions, and licenses are unverified. Originals are ignored and local-only; do not redistribute them. The four wrappers are new project instructions and do not embed original text.
- Current user instructions and `AGENTS.md` take precedence: artifacts default to English; Studio edits require target verification and confirmation; publishing and monetization require explicit approval. Read-only requests remain read-only.
- The base pack shared rules request Spanish artifacts, conflicting with project policy. Wildbound addendum assumes unapproved mechanics. Neither addendum has been merged into project rules.
- Base skills reference sibling `_roblox-shared/PROJECT_RULES.md`; the original archive layout preserves this path. They also mention `knowledge/GAME_BRIEF.md` and `knowledge/ART_BIBLE.md`; included templates remain templates and are not approved game facts.
- Wildbound skills often name support documents by basename; find them under `wildbound-codex-addon/knowledge/wildbound/`. Treat them as hypotheses, not current requirements.
- Bundled Python validators are not run: they are executable code, and the Wildbound validator assumes exactly ten skills. No connections, game mechanics, global skills, or dependencies are installed by this preparation.

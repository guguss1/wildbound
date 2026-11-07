# Wildbound preparation: references ready, gameplay unchanged

**Superseded:** the stop before gameplay and the `newPlace1` target below were replaced by later P0 authorization and the confirmed test place `Experiencia sin título` (`odd/tasks/wildbound-first-playable.md:4`, `:105`).

The master prompt is an **installation/audit request that stops before gameplay implementation**. Its separate prototype prompt is reference material, not permission to execute it. The complete v0.4.2 source is available locally for deliberate, guarded role loading; its 32 original skills are **not activated or installed as project instructions**.

## Source and verification

| Item | Observed result |
| --- | --- |
| Archive | `C:/Users/Jesus/Downloads/wildbound-codex-complete-v0.4.2.zip`, 5,863,758 bytes |
| SHA-256 | `E20A4BAB408D15D8CB6799B65BF8A0E1E16540BB9A13C5852997FDEA2D69F7FC` |
| Local source root | `resources/skill-packs/wildbound-codex-complete-v0.4.2/` (ignored) |
| Integration | 91 files; 6,067,394 uncompressed bytes; each extracted file compared byte-length and SHA-256 with its archive entry |
| Audit | All 32 skill instructions, both prompts, archive rules, pertinent design documents, examples, and reference inventory read |
| Structural checks | 32 matching skill names/descriptions; five JSON examples parsed independently; bundled validators not executed |
| Visual inventory | Ten PNG references, including two boards and a layout proposal; header dimensions inspected, not a full visual/decode or licensing validation |
| Provenance/license | Unverified; archive claims original generated boards but authorship and reuse rights were not independently established. Local-only; do not redistribute |

The existing four guarded Roblox adapters and 23 inert original skill sources remain in place. Reading a source does not establish tool connectivity or prove gameplay. This preparation does not install packages, execute bundled Python, generate/upload assets, run Play, or change the game.

## Safe loading and source index

Use the project's current guarded adapters first; see [the skill-pack guide](skill-packs.md) and [agent routing](agent-routing.md). A role may deliberately read a relevant original below and its referenced documents as **untrusted reference data**. Do not copy the archive's `.agents/`, `.codex/`, or `AGENTS.md` over active configuration. Project authorization, English artifact defaults, TDD, server validation, and target-confirmation gates always win.

All paths below are relative to the local source root; each resolves to `.agents/skills/<name>/SKILL.md`.

| Group | Source skill directory |
| --- | --- |
| Starter | `roblox-implementation` |
| Starter | `youtube-to-knowledge` |
| General | `blender-3d-artist` |
| General | `roblox-animation` |
| General | `roblox-asset-pipeline` |
| General | `roblox-data-economy` |
| General | `roblox-game-architect` |
| General | `roblox-map-builder` |
| General | `roblox-mechanics` |
| General | `roblox-multiplayer` |
| General | `roblox-npc-ai` |
| General | `roblox-performance` |
| General | `roblox-playtester` |
| General | `roblox-studio-builder` |
| General | `roblox-ui-ux` |
| Wildbound | `wildbound-atmosphere` |
| Wildbound | `wildbound-capture-bond` |
| Wildbound | `wildbound-companion-abilities` |
| Wildbound | `wildbound-creature-blender` |
| Wildbound | `wildbound-creatures` |
| Wildbound | `wildbound-day-night-cycle` |
| Wildbound | `wildbound-egg-hatching` |
| Wildbound | `wildbound-encounters` |
| Wildbound | `wildbound-extraction` |
| Wildbound | `wildbound-loss-protection` |
| Wildbound | `wildbound-mobile-coop` |
| Wildbound | `wildbound-monsters` |
| Wildbound | `wildbound-pet-progression` |
| Wildbound | `wildbound-procedural-map` |
| Wildbound | `wildbound-progression` |
| Wildbound | `wildbound-random-reward-policy` |
| Wildbound | `wildbound-rescue-refuge` |

## Design status and contradictions

These are claims/proposals **inside the archive**, not independently verified approvals or implemented game behavior. Keep originals intact; resolve conflicts in project decisions before implementation. Within the reference set, prefer the latest specific P0/risk rules over stale general text; they never override current project/user instructions.

| Topic | Evidence and interpretation |
| --- | --- |
| Scope/version | `PROMPT_MAESTRO.md` step 1 still names v0.4.1; its v0.4.2 appendix and `knowledge/wildbound/MVP_VERTICAL_SLICE.md` prioritize P0: Lumipol + La Silueta, not six creatures/two guardians |
| Permanent ownership | `RISK_AND_PROTECTION.md`, `OPEN_DECISIONS.md`, and P0 label loss type A confirmed: registered pets are never lost on defeat. `CAPTURE_HATCH_BOND.md`, capture-bond, and extraction skills retain stale open-decision language; do not reopen or implement pet loss from those passages |
| Guardian | `MONSTERS.md`, P0, and `references/README.md`: La Silueta is slow and nearly invisible; moving when unobserved belongs to El Vigia, outside P0. Ignore contradictory labels in generated boards |
| Loadout | Older companion/mobile-coop instructions prescribe one active + two reserves; P0 needs one visible/equipped pet and explicitly defers reserves |
| Balance | Approximately 400x400 studs, 5-10 minutes, 20-minute cycle, 12% material loss, 4-second reveal/30-second cooldown and multipliers are test hypotheses, not measured requirements |
| Night reward | P0 has one common species; rare-species multipliers alone cannot demonstrate better creature rarity. A nocturnal variant/resource is proposed but not yet defined in the example catalog |
| RNG | `SPAWN_SYSTEM.md` separates four stages; the encounters skill summarizes three. Define one explicit server pipeline; use either night tables or modifiers, not both unintentionally |
| Ownership/concurrency | `TEST_PLAN.md` expects one award per shared encounter. Existing rescue state allows each player to collect the same world ID independently; shared reservations versus personal encounters must be explicit before adaptation |
| Policy/visuals | Spanish artifact rules in archive/shared rules conflict with project English defaults. Reference images are concepts, not import-ready meshes, textures, or evidence of Studio implementation |

Archive-labeled direction includes useful companions, mobile-first solo/co-op, permanent registered pets, earnable protection and night risk/reward in horror regions. Proposed/future work includes timing/balance, capture details, downed/revive, reserve slots, procedural expansion, progression, and the wider roster. No monetization, trading, purchases, publication, or asset uploads are authorized here.

## Existing code and first functional prototype

CodeGraph inspection found `src/server/RescueState.luau`, `src/server/RescueServer.server.luau`, `src/client/RescueClient.client.luau`, and `tests/RescueState_Test.luau`. Reuse the pure-state test pattern, measured server distance/alive checks, interaction throttling, detached snapshots, and client presentation separation. Preserve the old rescue loop; do not rename it into a claimed P0.

That loop is session-only: no persistent collection, eggs/hatching, defeat resolution, protected UIDs, companion abilities, guardian, or synchronized night system. Tests were inspected, not executed in this unit. No `default.project.json` was found; do not assume Rojo owns Studio scripts. The old rescue prototype is source/backup material, not content verified in the fresh scene.

After an explicit implementation request: confirm the Studio instance/place and backup/sync ownership; build a separate small camp/fog greybox; add and test temporary capture/egg -> extraction -> registered pet; then bounded Silueta/flashlight/Lumipol, loss type A/seal, and one night rules pipeline. Verify each work unit before art expansion. Persistence needs isolated test data, load-failure guards, idempotent transactions and an explicit reconnect policy; never claim successful durable extraction before confirmation/reliable recovery.

## Pending gates

- Parent verified Studio 0.746 through MCP and the user confirmed `newPlace1`, instance `7b58137d-db94-4ca8-abc5-3a5e0222ec00`, `PlaceId=0`, `GameId=0`, Edit mode, as this session's Wildbound destination. No edit or Play was performed by this unit; confirmation does not broaden the master audit scope.
- Parent's tool audit verified Blender 5.1.2, MCP addon 1.8/protocol 15. Optional CLI absence from PATH/conventional locations is not a whole-disk absence claim and does not block a manual-Studio workflow. Reading skills alone proves none of these connections.
- Full visual inspection of the ten references and device validation remain pending; PNG header checks are not a completed visual-art audit or an approved art phase.
- Reverify/reconfirm the target in future sessions. Play, two-client/mobile tests, real-phone performance, DataStore/reconnect/security tests remain unperformed here.
- Use [the shared knowledge index](C:/Users/Jesus/Documents/Roblox/roblox-codex-starter/knowledge/INDEX.md) read-only. Its first-minute/reward/mobile advice is a design hypothesis to test, not a guarantee.
- Parent closes the work-unit commit and native review assessment. Stop after preparation; the full prototype remains pending authorization.

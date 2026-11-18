---
name: wildbound-current-state
description: Where Wildbound work stands on 2026-11-18 (Pueblo Gatito moved to the big4 south arm, step 2 deployed) and the queued steps
metadata:
  node_type: memory
  type: project
  originSessionId: 6e13884a-c13d-46c1-86d0-627c2213786c
  modified: 2026-11-18T16:46:18.915Z
---

**Status on 2026-11-18.** Studio a9e29749, place 122652861404212, big4 mode. Deployed and checked in solo Play:
- Caramelo v8.
- Pueblo Gatito, the kitten park: K-D1..K-D21 (fbcfb6f).
- **Step 1, its own biome:** PG-D1..PG-D9 (51debba, 5602037).
- **Step 2, the big4 south arm:** PGM-D1..PGM-D9 (6831632, docs 8dd7d10). Pushed on `codex/wildbound-first-playable`.

**Where the park is now:**
- The park frame is `ReplicatedStorage.WildboundGatitoArea`: origin (282, 600), yaw -90, world(lx, lz) = (282 - lz, 600 + lx).
- The root is `Workspace.PuebloGatito_v1` (Park, Nests, Ground).
- The big4 volcanic decor is archived in `WildboundMapArchive.GatitoSouthVolcanic`. The backup is `GatitoMoveBackup`.
- Caramelo's cloud wall is closed.

**Not saved yet.** Step 2's Studio edits are unsaved until the owner saves the place.

- Plans: `docs/design/wildbound-pueblo-gatito-biome-plan.md`, `docs/design/wildbound-pueblo-gatito-move-plan.md`.
- Log: `odd/tasks/wildbound-pueblo-gatito.md`.

**Account handoff, 2026-11-18:** `docs/handoff/HANDOFF-2026-11-18.md` holds the full state. The v9 research, the three designs, the judges and the checkers are in `docs/handoff/caramelo-v9/`. The best checker is `tools/v9-checker-geo9` (0 fails). The deploy tools `mkedits2.ps1` and `fp.ps1` are copied in `docs/handoff/caramelo-v9/tools/`.

**Next, in order:**
1. A longer Caramelo with a river 5 times wider so the raft can navigate. This is a v9 migration on the v8 pattern. Decisions PD1-PD6: all four arms become 600x1200; Caramelo grows east to x 1612; the river runs end to end along x at 50-120 wide. Design C ("build") won 2 of 3 judges.
   - The long axis is x, and the layout is a single-HALF square.
   - Today's river course fails at 5x: 9 nests, dock B, every bridge and point 23 fall into it.
   - Bridges are walls for the raft (`Raft.area`), so it needs raised bridges and more docks.
2. The park's look:
   - denser, a border, hills;
   - the grey 16-stud baseplate gap between the road's end (z 324.5) and the floor (z 340).
3. The micro-phases.

**Owner decision pending:** kitten eggs (park nests still give Caramelo species). Their icons are an upload, which needs approval.

**Still open for the owner:**
- Audition the kitten music (108517170970006). In automated Play every music layer reads volume 0, Caramelo's too, so I cannot hear-check it.
- Judge the park's look. 3D captures render white.

**Big4, Studio-only copies patched by hand:**
- Biomes, BiomeLight and BiomeLight_Test: the CandyEast arm row replaces Volcanic in AREAS_BIG4.
- BeastSight_Test (big4 copy) and Big4Map_Test: they expect CandyEast in the south arm.
- The big4 branch needs these when it merges.

**Testing in Studio:**
- Run the suites in a fresh Play server VM: `require` the originals and use the SPECS arguments from `tools/studio-fresh-runner.luau`.
- A kitten hit can "defeat" the player, which mutes the audio layers until respawn.
- The Studio camera does not follow a teleported character in an unfocused Play.

**Mixed Studio copies:** patch only hunks into WildboundText, WildboundText_Test (334 extra bytes), WildboundServer, WildboundWorld, WildboundWorldClient and the big4 copies above.

**Why:** the owner asks for one task at a time, no questions, and decisions recorded in the task doc.

**How to apply:**
- **Deploy:** commit, then run `mkedits2.ps1 -Base <prev> -Only ...` and apply the hunks with multi_edit.
- **Fingerprints:** check with `fp.ps1` against the Studio Adler-32.
- **One-shot tools:** run them by loadstring with DRY_RUN swapped, then poll the summary attribute in a separate call.
- **Agents:** at most 3 at a time, on disjoint files, then a reviewer.
- **Before code and Play:** warn the owner. See [[wildbound-env-git-python]].

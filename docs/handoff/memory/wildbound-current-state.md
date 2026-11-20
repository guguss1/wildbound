---
name: wildbound-current-state
description: "Where Wildbound work stands on 2026-11-18 (Caramelo v9 deployed: arm 1200 long, river end to end) and the queued steps"
metadata:
  node_type: memory
  type: project
  originSessionId: 6e13884a-c13d-46c1-86d0-627c2213786c
  modified: 2026-11-20T20:10:19.691Z
---

**Status on 2026-11-18.**
- Studio id 800955c0-34be-4656-8b15-accfefe46a2a (it changed after a restart), place 122652861404212, big4 mode.
- Branch `codex/wildbound-first-playable`, pushed up to `d3f5c78`.

**Deployed and checked in solo Play:**
- Caramelo v8.
- Pueblo Gatito: the park (`fbcfb6f`), step 1, its own biome (`51debba`), and step 2, the big4 south arm (`6831632`). The owner saved these.
- **Caramelo v9, CL-D1..CL-D18** (`11d035c`, `791744d`, docs `d3f5c78`):
  - the big4 arm is x 412..1612; the plot is x 412..1532 (`Layout.EAST = 860`, CENTRE (672, -3), HALF 260);
  - the river runs west to east, 50..120 wide;
  - 3 raised bridges at world x 1142 (deck 12.5) and 4 docks;
  - the Torta at (1420.2, -3) and 45 nests;
  - side and end walls at x 1612, z ±300.
  - Backup: `WildboundMapArchive.CaramelV9Backup`. The tool `ServerStorage.WildboundCaramelV9Migrate` (disabled) has a RESTORE mode.

**Saved:** the owner saved the place with v9 on 2026-11-19. The raft sailed by hand has not been reported.

**Docs:**
- Plan: `docs/design/wildbound-caramelo-v9-plan.md`.
- Log: `odd/tasks/wildbound-caramelo-v9.md`.
- Handoff: `docs/handoff/HANDOFF-2026-11-18.md`. It predates the v9 deploy, so its section 2 is now done.

**Paused 2026-11-19 at the owner's request ("pausa ahora y seguimos mañana").** The Pueblo Gatito 600x1200 research workflow was stopped before any results. Resume it with Workflow scriptPath `C:\Users\Agustina\.claude\projects\E--juego-roblox\6e13884a-c13d-46c1-86d0-627c2213786c\workflows\scripts\gatito-long-research-wf_fc7bda19-8a0.js` and resumeFromRunId `wf_fc7bda19-8a0`, or run it fresh. Nothing was written to the repo or to Studio for it.

**2026-11-19 progress (Studio id now a606dc2c-8e57-4d67-9541-5cd5b42127e8):**
- OQ5: proposals delivered (`docs/design/wildbound-progression-proposals.md`). The owner's choice is pending.
- OQ2: the queen's endless chase (`d69dfac`) is in Studio and passed its suites.
- OQ3: fall damage (`f0f2873`, new WildboundFallDamage, WildboundFallDamageService and _Test) is in Studio. Its suites passed, and a solo Play fall warned first, then took 40.
- OQ1: the clouds (`d91afab`) are in Studio:
  - Terrain Clouds per biome (Caramelo pink 0.72, Gatuno white 0.58);
  - the Veil is SmoothPlastic with transparency 1, plus a 72-puff client wall.
  - The owner judges the look. Fallbacks: cover up, or the pink skybox back.
- **Not saved yet.** The OQ2, OQ3 and OQ1 Studio edits are unsaved until the owner saves.
- **Next:** OQ4, the longer arms, starting with Pueblo Gatito. Run the research workflow script `gatito-long-research-wf_fc7bda19-8a0.js` fresh.

**2026-11-20.**
- Studio id now c21f0746-4241-42c7-a0a4-96f679bd77d4. OQ1 to OQ3 were saved by the owner.
- **Pueblo Gatito 600 x 1200 is deployed** (`d1a86c1`, docs `436455d`): mark PuebloGatito=3, 2826 parts, backup GatitoGrowBackup, 16 nests, far portal parque2. **Not saved yet.**
- Playtime plan: `docs/design/wildbound-playtime-and-gameplay-plan.md` (`ff27df1`). Today about 3-5 h; top proposals are ranks with a shop, a creature album with more species, and daily goals.
- **Toolbox look pass** (`bbf427f`, docs `ddd6fb8`), deployed but not saved:
  - Obby Sky on Lighting.Sky;
  - the WildboundGatitoGrass MaterialVariant on the park floor;
  - a scrolling chocolate texture client;
  - gatitoMusic is APM Cute Cat 1839661368.
  - The pink sky toolbox asset 97128825470015 was malware and was destroyed.
- **Build plan:** `docs/design/wildbound-fun-build-plan.md` (`1766a06`). Steps P0.1 store UI kit, P0.2 offers catalog with DESBLOQUEAR_TODO, P0.3 world signs, then T1..T13.
  - The owner wants Robux signs everywhere, but everything unlocked in dev, with no real purchases.
- **Next:** P0.1, then the Bosque and Montañas arms.
- **Gotchas:**
  - multi_edit `replace_all` reported success but did not stick: verify, or rewrite the Source directly.
  - Never poll a one-shot tool in the same execute_luau call that scheduled it: that call's undo recording stays open and the tool refuses.

**Later on 2026-11-20 (handoff `docs/handoff/HANDOFF-2026-11-20.md`; pushed up to `c2797f2`):**
- Deployed, all **unsaved**:
  - Caramelo-only sky `48d4a3e`;
  - P0.1 UI kit `4f556ce`;
  - roulette wheel `5ec13a1`;
  - full UI restyle `dea98cf`.
- **T1, thief rank plus dodge fix** (`8b0052b`, `f8a7c23`), deployed and Play-checked:
  - the count is `training.eggsHome`, added in State's bankItem; no schema step;
  - WildboundGoldService.sync mirrors it on the attribute `WildboundThiefSteals`;
  - the new scripts are WildboundRank, WildboundRankClient and WildboundRank_Test;
  - only a perfect dodge sets dashInvulnUntil.
- **UI polish pass:** paused with nothing written, after the owner switched to "jugar más tiempo".
- **Next, in order:**
  1. T2, the first egg in under 90 s;
  2. the UI polish;
  3. P0.2 and P0.3;
  4. T3 to T13;
  5. the Bosque and Montañas arms.
- **Pre-existing failures:**
  - State_Test: 14 cases, because Studio's economy values differ from the suite's (verified the same without T1);
  - EggCarry Q3b and EggLoop EL12.
  - Python sims and caramelo tests are stale against v9 (`Layout.ENTRANCE` not found).
- **Test egg banking in Play:** `ServerStorage.WildboundTelemetry.IslandProbe:Invoke("egg", nil, userId)`.

**Owner queue for 2026-11-20:** `odd/tasks/wildbound-owner-queue.md` (OQ1..OQ5), decided order:
1. OQ5, game progression proposals (dash or speed bought or earned; Robux is design only);
2. OQ2, the Caramelo queen chases forever after an egg theft;
3. OQ3, fall damage from tall towers;
4. OQ1, realistic clouds, not a stretched image;
5. OQ4, much longer arms with more creatures (Pueblo Gatito next).

**Next, in order:**
1. The owner plays v9: sails the raft from A to D, judges the look, and saves.
2. The other three arms grow to 600 x 1200 (PD1), one task each: Pueblo Gatito (south, +z), Bosque (west), Montañas (north). Big4Map_Test expects 600 for them until then.
3. The park's look, including the grey gap at z 324..340.
4. The micro-phases.

**Owner decisions pending:**
- kitten eggs (their icons need an upload approval);
- an audition of the kitten music.

**Big4 Studio-only copies, patched by hand:**
- Biomes and BiomeLight: the CandyEast south arm row, and the Meadow row 412..1612.
- BiomeLight_Test, BeastSight_Test and Big4Map_Test.
- The `agus/big4-map` branch needs these when it merges.

**Testing in Studio:**
- In a fresh Play server VM, `require` the originals with the SPECS args from `tools/studio-fresh-runner.luau`.
- The Assistant HTTP allowlist blocks localhost, so Studio cannot fetch files. Load hunks with multi_edit, or with sequential subagents, one writer at a time, verifying fingerprints.
- `CandyBeastSites` CC4 fails, as it did before v9.

**Why:** the owner asks for one task at a time, no questions, and decisions recorded in the task doc.

**How to apply:**
- **Deploy:** commit, then run `docs/handoff/caramelo-v9/tools/mkedits2.ps1 -OutDir <dir> -Base <prev> -Only <files>`. Fingerprint with `fp.ps1`.
- **One-shot tools:** run them by loadstring with DRY_RUN swapped, then poll the summary attribute.
- **Agents:** at most 3 at a time.
- **Before code and Play:** warn the owner. See [[wildbound-env-git-python]].

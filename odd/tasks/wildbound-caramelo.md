# Wildbound Caramelo completion

## Objective

Finish the Caramelo biome's creatures and its world rules from the user's Caramelo production pack:
finish Flanfuria, build Tortidragón and Don Glaseón (model, rig, clips, one attack, AI, wiring), and
implement pack item 08 (egg waves every 300 s, fixed per-biome lighting, no global day/night cycle).

## Why

User request 2026-11-15: "05 Tortidragón ... 06 Don Glaseón ... ve haciendolo"; item 08 "haz el rig,
animación"; "04 Flanfuria ... terminalo también". Item 08 **replaces** the 2026-11-14 decision
"Mantener 300/60/300/60" (odd/tasks/wildbound-suite-repair.md): no global day/night cycle; Caramelo is
always bright, the forest always dark; eggs refresh every 300 s.

## Scope and authorization

- Authorized: Studio script edits on place 122652861404212 (instance confirmed by the user this
  session), Blender sources under `assets/blender/caramelo/<creature>/`, and the asset uploads the rigs
  and clips need: meshes/models and animations for Flanfuria, Tortidragón and Don Glaseón only. Every
  uploaded id is logged below with what it is. No other uploads.
- Not authorized: publishing, saving the place, monetization, SistemaSonriente, hand edits of
  Workspace geometry (only through the existing builder scripts), damage outside the private test place.
- Pack rules (06_PROMPTS_CLAUDE/00): one attack per actor; wild versions only; farm pets never attack;
  tells >= 0.8 s (FairStrike); wild beasts never attack in safe zones; server-authoritative hits.

## Method

- TDD: strict (session configuration). RED then GREEN in Studio with a fresh loader
  (`tools/studio-fresh-runner.luau`, loadstring + setfenv, suite args from SPECS). Python:
  `python -I -B -m unittest discover -s tools -p "test_*.py"` (known pre-existing failure:
  `test_lumipol_v2` V1IsKept).
- Studio write rule: compare each Source fingerprint (CRLF to LF, trailing newlines stripped, byte
  length + Adler-32) with repo HEAD before writing; if Studio differs, pull Studio first.
- Pattern for every creature (Gomibu): prefab module (`tools/WildboundCandy<X>.luau`) + clips module
  (`...<X>Clips.luau`, data to KeyframeSequence, published ids) + pure attack module (`...<X>Attack.luau`)
  + beast brain (`src/wildbound/WildboundBeast<X>.luau`, stepped by WildboundBeastEncounters via
  Enc.register) + model service (`WildboundCandy<X>Service.server.luau`) + client anim
  (`WildboundCandy<X>Anim.client.luau`) + Config/Text/Beasts/PraderaSites wiring + suites + manifest rows
  + runner SPECS.

## CA0 discovery (2026-11-15, read-only)

### 1. How Gomibu and Flanfuria were produced and uploaded

- The prefab modules say the mesh, skin and armature come from Blender
  (`caramelo/gomibu/build_gomibu.py`, `caramelo/flanfuria/build_flanfuria.py` "in the local repo") and
  were uploaded as one Model asset each; Gomibu's ten clips "uploaded from caramelo/gomibu/clips/*.rbxmx".
  None of these sources, nor `candy_kit_spec.json` nor `odd/tasks/caramelo-bioma.md`, is in this repo,
  the `main` worktree, `Documents/wildbound-upload`, `Documents/Roblox/*` or Engram. A wider disk search
  of Documents/Desktop was still running when this doc was written (see Evidence). Treat them as lost:
  Tortidragón and Don Glaseón get new Blender sources in this repo.
- Live assets: Gomibu model 97819093908843 + 10 clips (ids in `tools/WildboundCandyGomibuClips.luau`);
  Flanfuria model 109182574821732 (v3; v1 82183195819347 and v2 76491528957195 unused) + 10 clips
  (Studio only, `ServerStorage.WildboundCandyFlanfuriaClips`: Idle 120202747796302 ... HatchReact
  83529503438825); candy kit 139302047387424.
- Known import gotchas recorded in the Flanfuria prefab: the importer drops bones no skinned vertex
  uses (Flanfuria needed a hidden `Keeper` mesh of tiny skinned tetrahedra), and a mesh named like a
  bone captures that bone. Name meshes unlike bones and skin every bone.
- Upload path that works from this machine (Engram #2574, #2581, #2721): FBX/rbxmx written into an
  approved upload directory (`assets/exports`, `assets/models/beasts`, approved in Studio MCP
  Permissions), then Studio MCP `open_cloud_invoke` POST `/assets/v1/assets` (Model: FBX; Animation:
  `model/x-rbxm` per KeyframeSequence, one asset per request, creator user 11937129310), poll
  `/assets/v1/operations/{id}`, then `insert_asset` into ServerStorage. Save the POST response before
  polling and never re-POST (no duplicate assets).
- Blender MCP: connected, Blender 5.1.2, addon protocol 15 vs expected 16 (warning only;
  `execute_code` works). No generators or libraries enabled (none needed).

### 2. Live Studio state (Edit, PlayLock nil)

- **Flanfuria is much further along in Studio than in the repo and than the user's summary.** Studio
  has, not in the repo: `ServerStorage.WildboundCandyFlanfuriaAttack` (+ `_Test`),
  `WildboundCandyFlanfuriaClips` (+ `_Test`, 10 published clip ids), `ServerScriptService.WildboundBeastFlanfuria`
  (+ `ServerStorage.WildboundBeastFlanfuria_Test`), `ServerScriptService.WildboundCandyFlanfuriaService`,
  `StarterPlayerScripts.WildboundCandyFlanfuriaAnim`; and Studio-ahead versions of
  `WildboundBeastConfig` (Flanfuria entry, WAVE2, SUMMONED), `WildboundBeasts` (KIDS row),
  `WildboundPraderaSites` (Flanfuria home `candyNestR1`, 11 studs from nest R1 at 534,-33),
  `WildboundBeastWiring_Test`, `WildboundCandyBeastSites_Test`. Prefab
  `ServerStorage.WildboundAssets.Flanfuria` exists (Height 8.76, AssetId 109182574821732, Keeper,
  Collision). Two snapshots minutes apart were identical; nothing looked mid-edit, but another session
  wrote these within the last day.
- Fingerprints (bytes, Adler-32; Studio vs repo HEAD 6cc5398):

| Script | Studio | Repo | State |
|---|---|---|---|
| WildboundBeastConfig | 28335 f87f71ea | 27384 29b14377 | Studio ahead |
| WildboundBeasts (server) | 44985 654a3fba | 44925 48ff2b7a | Studio ahead |
| WildboundPraderaSites | 4441 170bcdce | 4229 db028aa5 | Studio ahead |
| WildboundBeastWiring_Test | 48116 e7d9a74e | 48022 540688ab | Studio ahead |
| WildboundCandyBeastSites_Test | 9695 3fe75159 | 6676 cb968497 | Studio ahead |
| WildboundCandyFlanfuriaAttack | 8329 5a85dbc7 | missing | Studio only |
| WildboundCandyFlanfuriaAttack_Test | 8761 9e998694 | missing | Studio only |
| WildboundCandyFlanfuriaClips | 9823 eba3bba7 | missing | Studio only |
| WildboundCandyFlanfuriaClips_Test | 10583 45e80ec0 | missing | Studio only |
| WildboundBeastFlanfuria | 7476 5e3d97ce | missing | Studio only |
| WildboundBeastFlanfuria_Test | 13633 28cfefd8 | missing | Studio only |
| WildboundCandyFlanfuriaService | 1626 9a0135fc | missing | Studio only |
| WildboundCandyFlanfuriaAnim | 5911 2aa69239 | missing | Studio only |

  Equal in both: WildboundText (35833 fd4fbc11), WildboundAtmosphere, WildboundWaveClock (+ `_Test`),
  WildboundSpawnClock, WildboundWorldRules, WildboundWorld (server), WildboundServer (208864 cea678ec),
  WildboundState, WildboundEggCarry, WildboundBeastAttack, WildboundBeastEncounters, WildboundBiomes,
  WildboundBeasts.client, WildboundFlashlight.client, WildboundDusk, every Gomibu file, CandyLayout,
  CandyBuilder, CandyKit, CandyFlanfuria (+ `_Test`).
- `Workspace.Candy_Bioma_v1` (built by `ServerStorage.WildboundCandyBuilder`, LayoutVersion 2, seed
  20261114, 736 parts, `Replaces = PraderaArcoiris`, `SpawnsEnabled = false`), centre (620, 25, -7),
  430 x 463 studs, inside the `Meadow` square of WildboundBiomes (x 412..812, z -203..197). Markers:
  Entrance (412,-3), Fork (502,-3), TortaPlaza (568,-3), **BossHome (578,-3)**, Junction (742,-3),
  **Portal marker (772,-3)**, FirstNest (452,-21), routes left/right. `Boss.BossTerritory` (612,-3):
  Boss = DonGlaseon, Radius 62, PlazaRadius 44, Enabled false, ringed by 12 LimitPost/LimitCap
  decor parts. `GranTorta` model at (612,-3) with four collision tiers. `Portal` model (772,-3),
  Leads hub, Enabled false. 12 nests `Nest_*` (C1..C5 Comun, R1..R4 Rara, E1..E2 Epica, L1
  Legendaria event-only), all `Enabled = false`, `Candidate = true`.

### 3. Day/night cycle, waves, spawns, lighting today

- Cycle: `WildboundWorldRules.luau` PHASES (lines 4-12) Day 300 / Dusk 60 / Night 300 / Dawn 60
  (720 s); `Rules.cycle(elapsed)` (line 116) gives phase + clockTime; `Rules.startOffset` (line 137)
  never opens in Night. Origin: `WildboundWorld.server.luau` lines 133-161 sets runtime attribute
  `CycleStartedAt`; Studio-only `StudioClockShift`.
- Phase consumers (each must be migrated, not left reading a cycle that no longer exists):
  `WildboundServer.server.luau` 986-998, 2508 (islands, `islandPhase`), 3740-3780
  (`Heist.resetEggsAfterNight` / `stepNightEggReset`: nests and spawn reroll after Night),
  `Heist.stepDusk` (Dusk warnings); `WildboundBeasts.server.luau` 243-275, 469, 704 (night beast odds,
  Nube night wake); `WildboundGather.server.luau` 138 + `WildboundGatherField` 114 (Nightbloom);
  `WildboundWorldRules` 232-246 (Silueta night profile in the fog); `WildboundGuardianBrain`,
  `WildboundHide`, `WildboundIsland` 136 (deep sleep 11:00-13:00, dusk/night), `WildboundAmbush`,
  `WildboundAudioMix`, `WildboundHudView` 187, `WildboundCampView` 360, `WildboundEconomy` 211,
  `WildboundBalance`, `WildboundDusk`.
- Lighting: `WildboundAtmosphere.luau` (pure: ROWS per zone open/fog/camp x Day/Dusk/Night, LIGHT per
  time, `Atmos.at(clockTime, zone, reduced)`, variant tint). Applied only on the client:
  `WildboundWorld.client.luau` lines 648-667 (cache/restore, local Atmosphere, `WildboundVariantTint`)
  and 1088-1131 (per-frame lerp of Ambient, Fog, Brightness, Exposure, Atmosphere, flashlight, then
  `Lighting.ClockTime` toward the server's `state.clockTime`). Zones today are only camp/fog/open.
- Waves: `WildboundWaveClock.luau` (WAVE_SECONDS 300, `WaveClock.step` emits `waveStarted`, variants
  Niebla/Escarcha/Ceniza/Floracion, WorldEvent remote, `message`/`read`). Wired in
  `WildboundServer.server.luau` 1322-1330 and 1460-1525: `startWave` sets the variant, rerolls random
  spawns (`SpawnClock.reroll`, held spawns stay), places Refugios, broadcasts `wave` with `endsAt`;
  late joiners get it at 1553. `WildboundSpawnClock.luau`: LIFETIME 300, per-tier respawn and caps;
  `spawnHeld` (1302) keeps captured or prompt-held spawns.
- Biome tags: `WildboundBiomes.luau` (server only, ServerScriptService) squares Forest, Meadow (=
  Caramelo now), Swamp, Cemetery, Abyss, Mountains, Volcanic, Caves.

**Smallest design for CA4 (pack 05_SISTEMAS/01 and 02):**

1. One clock: keep WaveClock as the only timer. Add a pure `WaveClock.window(state, now)` returning
   `Collect` (0 to 289.999), `Warning` (290 to 299.999) and the wave id (`state.wave`, which already
   changes once per wave). Server: refuse a *new* egg hold during Warning (one gate where EggCarry
   holds start); holds already open resolve as today (`spawnHeld` keeps them). At `waveStarted`,
   also reset unclaimed island nests (move the body of `Heist.resetEggsAfterNight` into the wave
   start, keyed by wave id so it runs once) and drop the Night trigger; carried, dropped and secured
   eggs, chases and players are untouched. Clients get notices at 10/5/3/2/1 s from `endsAt`.
2. No global cycle: `Rules.cycle` becomes a fixed per-place answer instead of a timer: a pure
   `WildboundBiomeLight` (ReplicatedStorage) maps a biome tag to a preset (`Caramelo`/Meadow: Day,
   clockTime ~14, Saturation +0.08, Contrast +0.04, Brightness +0.03, low fog, long view; `Forest`:
   Night look; Swamp dusk green; Cemetery violet twilight; others their own). The world client picks
   the preset from the local character's position (needs a replicated copy of the Biomes squares) and
   lerps to it in about 1 s (0.8-1.5 s), replacing `state.clockTime`; only that client's Lighting
   changes. Server phase consumers read a per-place phase (`Forest` = Night, elsewhere Day) through
   one helper instead of the timer; the Dusk warnings and the day/night HUD label go.
3. Tests: WaveClock window boundaries 289.9/290/299.9/300, one wave id per wave, hold refused in
   Warning but an older hold kept; BiomeLight preset by point and by tag; a contract that no server
   script reads `CycleStartedAt` any more.

### 4. Build plan

- **CA1 Flanfuria finish.** Pull the 13 Studio-ahead/Studio-only scripts into the repo (byte-exact),
  add manifest rows, pins and runner SPECS for the four new suites; run every Flanfuria suite and the
  wiring suites fresh; fix what fails (TDD). Check the pack contract: tell 1.0 s, ring r2 to r11 in
  0.8 s, slow x0.65/1.5 s once per cast, puddle r4 3 s x0.8 non-stacking, cooldown 8 s, no egg drop,
  farm pet passive, no attack in safe zones. Solo Play check: summon at `candyNestR1`, screenshot the
  tell ring on the pink floor and the puddle. No new upload expected (model v3 and 10 clips exist).
- **CA2 Tortidragón.** Blender source `assets/blender/caramelo/tortidragon/build_tortidragon.py`
  (low-poly quadruped, about 11 studs, honey/orange body, pink cream crest, strawberry horns, cream
  tail; no side emblem), 22-26 bones per pack, every bone skinned, no mesh named like a bone. Upload
  Model (1) + 11 clips (`Idle, Walk_Quadruped, Run_Quadruped, Turn, Alert, Attack_Telegraph,
  Attack_Release, Attack_Recover, HitReact, FarmIdle, HatchReact`). Modules on the Gomibu pattern;
  attack Abanico de Confites: 55 deg sector, 12 studs, tell 1.0 s, lock at 0.6 s, three circles r2.3
  (shape `multi`, drawn by WildboundBeasts.client), at most one hit per player, light push, no egg
  drop, cooldown 7 s, no cast when the target is behind. Patrol 10, chase 16, sight 22, leash 35.
  Home: a Rara nest site (R2 534,31 or R3 672,-113).
- **CA3 Don Glaseón.** Blender source `assets/blender/caramelo/don-glaseon/build_don_glaseon.py`
  (22-25 studs, pink faceted torso, huge toothed mouth, gumdrop crown, long arms with claws, purple
  grape legs; no chef hat, no crown/robe), 26-30 bones incl. Jaw and Licorice_01..03. Upload Model (1)
  + 11 clips. Attack Látigo de Regaliz: shape `lane` 22 x 5, tell 1.10 s, lock at 0.60 s, 0.35 s
  lash, recover 1.0 s, cooldown 7 s; a carrier drops the egg through the existing BeastHit path
  (not keepsEgg); others push 12 + slow x0.85 0.7 s; damage 0; bat immune. One boss per server at
  `BossHome`, territory `BossTerritory` radius 62 (pack 110 studs pursuit leash vs the 62-stud marker:
  use the marker unless the user says otherwise), sight 36, noise 45, patrol 9, chase 17, chase cap
  15 s, last-seen search 3 s, never in safe zones, hub or portal; suppress other beasts on its target
  while it chases.
- **CA4 Waves + lighting.** As designed above. Owner of shared scripts: small additive edits to
  WildboundServer and WildboundWorld.client only; WildboundState untouched unless the hold gate needs it.
- **CA5 Close.** Python suite, solo Play pass of all four actors and a 3-wave lighting check, overview
  section 13 rows, commit.

### Risks

- Another session built Flanfuria in Studio within the last day and may resume: re-fingerprint before
  every write; one writer per script set.
- Lost Blender sources for Gomibu/Flanfuria: any Flanfuria mesh fix would need a new source and a new
  upload. Plan avoids touching the Flanfuria mesh.
- Animation upload needs a per-clip rbxm file in an approved directory; the Studio-native route (save
  each KeyframeSequence) is proven only for Silueta. Clip uploads are 22 new assets (11 + 11) plus 2
  models; keep a POST receipt per asset and never retry blindly.
- Importer bone loss (see Flanfuria Keeper) and the 50-bone / mesh-size limits; check the bone count
  right after `insert_asset`.
- The boss is one shared actor; WildboundBeastEncounters runs one encounter per target. A shared boss
  needs a per-server cap and target switching, a pattern no current beast has.
- Removing the cycle changes balance (Silueta night speed 17 in the fog, beast night odds, Nightbloom,
  island deep sleep, Dusk rule): pick the per-place mapping deliberately and update the suites that
  pin the cycle (WorldRules, Dusk, Balance, EconomyConfig contracts).
- `BossTerritory`, `Portal` and the nests are `Enabled = false` and the biome has `SpawnsEnabled =
  false`: Caramelo eggs and the boss trigger need those flags flipped through the builder, not by hand.

## Checklist

- [x] CA0 Discovery and plan (this document). Route: inline, read-only (Studio reads, repo reads).
- [x] CA1 Flanfuria finished: Studio work pulled, suites green, pack contract checked, solo Play. Route: inline
  (13 scripts pulled byte-exact; no new behaviour written, so no RED: every suite was already GREEN). Commit below.
- [ ] CA2 Tortidragón: Blender source, model + 11 clips uploaded, modules, brain, wiring, suites, Play.
- [ ] CA3 Don Glaseón: Blender source, model + 11 clips uploaded, modules, boss brain, wiring, suites, Play.
- [ ] CA4 Egg waves every 300 s with Warning window; fixed per-biome client lighting; cycle consumers migrated.
- [ ] CA5 Close: Python suite, Play pass, overview rows, commit.

## Uploaded assets

| Id | What | Task | Receipt |
|---|---|---|---|
| (none yet) | | | |

## Acceptance criteria

- Each actor: one attack with the pack's numbers, tell >= 0.8 s, never in safe zones, farm pet passive,
  suites green in a fresh loader, solo Play screenshot of the telegraph on the pink floor.
- Waves: wave id changes once per 300 s; no new hold in the last 10 s; unclaimed eggs refresh;
  carried/dropped/secured eggs kept; late join gets the current wave.
- Lighting: 15 min in Caramelo never gets dark; crossing into the forest darkens in 0.8-1.5 s; only the
  local client changes.

## Evidence

- CA0: Studio instance ba5a21af (place 122652861404212, Edit, PlayLock nil), fingerprint table above
  taken twice, identical. Engram #2574, #2581, #2721 for the upload route. No writes to Studio.
- CA1 (2026-11-15): Studio re-fingerprinted before pulling (unchanged from CA0). Pulled into the repo, each now equal
  to Studio (bytes, Adler-32): BeastConfig 28335 f87f71ea, Beasts.server 44985 654a3fba, PraderaSites 4441 170bcdce,
  BeastWiring_Test 48116 e7d9a74e, CandyBeastSites_Test 9695 3fe75159, and the new files
  `tools/WildboundCandyFlanfuriaAttack.luau` 8329 5a85dbc7 (+ `_Test` 8761 9e998694),
  `tools/WildboundCandyFlanfuriaClips.luau` 9823 eba3bba7 (+ `_Test` 10583 45e80ec0),
  `src/wildbound/WildboundBeastFlanfuria.luau` 7476 5e3d97ce (+ `tests/..._Test` 13633 28cfefd8),
  `WildboundCandyFlanfuriaService.server.luau` 1626 9a0135fc, `WildboundCandyFlanfuriaAnim.client.luau` 5911 2aa69239.
  No Studio Source was written. Manifest rows + pins (8) and runner SPECS (3) added.
  - Fresh loader (loadstring + setfenv, SPECS args), filter Beast*/Candy*: 16 suites, 254 passed, 0 failed
    (BeastFlanfuria 10, CandyFlanfuriaAttack 11, CandyFlanfuriaClips 8, CandyFlanfuria 7, BeastWiring 49,
    BeastGomibu 9, Director 47, Encounters 24, Attack 13, Audience 17, Nube 11, Abeja 10, CandyLayout 13, Gomibu x3 25).
    CandyBeastSites_Test (runner SKIP, reads Workspace) run with a loadstring loader: 8 passed, 0 failed.
  - Pack contract (03_PERSONAJES/02_FLANFURIA.md) matches the code: tell 1.00 s, ring r2 to r11 in 0.80 s, one hit
    per cast, slow x0.65 1.5 s, puddle r4 3 s x0.8 as 0.6 s pulses with a 0.15 s gap (no stacking), recover 0.85 s,
    cooldown 8 s, damage 0, egg kept (Afflict, never BeastHit), pet refused, safe zone ends it, 10 clips published.
  - Solo Play (PlayLock CA1, cleared after; Play stopped): teleported 10 studs from the post `candyNestR1`. Server
    phases Chase -> Telegraph -> Release -> Recover -> Chase; client ring radius 4.8 -> 7.8 -> 10.8 then puddle r4;
    WalkSpeed 16 -> 10.40 (x0.65) for 1.5 s, back to 16, then puddle pulses 12.80 (x0.8) every ~0.75 s until the
    puddle dried, then 16 (no permanent change, no stacking). Screenshots: `assets/exports/forest-kit/captures/`
    `ca1-flanfuria-tell-pink-floor-desktop.jpg` (red circle r11 + "¡Onda de Caramelo! Aléjate o salta" on the pink
    floor), `ca1-flanfuria-ring-front-desktop.jpg` (dotted front), `ca1-flanfuria-puddle-desktop.jpg`.
  - Observations, not fixed: the tell circle is red, the pack says amber; the r4 puddle is mostly hidden under the
    flan's own base until it hops away. The place was still on the day/night cycle (dim), CA4 removes it.
  - Python: 1195 tests, 1 failure = the known `test_lumipol_v2` V1IsKept; `test_studio_fresh_runner` and
    `test_deploy_manifest` OK. Not tested: two players, phone, farm Flanfuria in Play (no farm Flanfuria exists).

## Next step

CA2 Tortidragón: Blender source, model + 11 clip uploads, modules on the Gomibu/Flanfuria pattern.

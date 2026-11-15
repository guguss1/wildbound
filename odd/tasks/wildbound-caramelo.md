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
  (13 scripts pulled byte-exact; no new behaviour written, so no RED: every suite was already GREEN). Commit 1de89f3.
- [ ] CA2 Tortidragón: Blender source, model + 11 clips uploaded, modules, brain, wiring, suites, Play. Route: inline
  (writer trigger fired; kept inline because every Studio write needs the parent's fingerprint gate). PARTIAL: model, rig,
  attack, brain, wiring, suites and solo Play done; the 11 clips are data + built in Studio but NOT published (blocked, see
  Evidence CA2). Commit fed4228.
- [ ] CA3 Don Glaseón: Blender source, model + 11 clips uploaded, modules, boss brain, wiring, suites, Play. Route: inline
  (writer trigger fired; kept inline because every Studio write needs the fingerprint gate). PARTIAL: model, rig, attack, boss
  brain, one-per-server rule, wiring, suites and solo Play done; the 11 clips are data + build in Studio but NOT published (same
  group-ownership blocker as CA2, no clip uploaded). Commit e49fa59.
- [x] CA4 Egg waves every 300 s with Warning window; fixed per-biome client lighting; cycle consumers migrated. Route:
  inline (writer trigger fired: 2+ non-trivial files; kept inline because every Studio write needs the parent's fingerprint
  gate and Studio == repo before each write). Commit 91e29d7.
- [ ] CA5 Close: Python suite, Play pass, overview rows, commit.

## Uploaded assets

| Id | What | Task | Receipt |
|---|---|---|---|
| 103052975067537 | Tortidragon Model v1 (FBX `assets/exports/caramelo/tortidragon-v1.fbx`, 24 bones, 10 skinned meshes), user 11937129310 | CA2 | op 0a15dba5-c97e-4c2b-b33b-7e6d1b233aa5, Approved |
| 115362506833585 | Tortidragon Animation Idle (hand-written rbxmx), user-owned: UNUSED, cannot load in the group universe | CA2 | op 0f826065-7e87-46ca-bd97-62af9d63a157 |
| 81874477774437 | Tortidragon Animation Idle v2 (Studio-serialized rbxm), user-owned: UNUSED, cannot load in the group universe | CA2 | op c58601e8-80e5-4cff-ab07-e61bb18032e3 |
| 91765062667935 | Don Glaseon Model v1 (FBX `assets/exports/caramelo/don-glaseon-v1.fbx`, 29 bones, 14 skinned meshes), user 11937129310 | CA3 | op 971df032-1e7e-44d8-9b1e-2c2e510efa2a, Approved |

Receipts: `assets/exports/caramelo/upload-receipts.md`.

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

- CA2 (2026-11-15): Tortidragón.
  - Blender source `assets/blender/caramelo/tortidragon/build_tortidragon.py` (own scene "Tortidragon"; 24 bones, 10
    one-colour meshes, every vertex rigidly skinned to one bone, no mesh named like a bone, no side emblem). Uploaded as Model
    103052975067537; InsertService import kept all 24 bones; `Tortidragon.assemble` built `ServerStorage.WildboundAssets.Tortidragon`
    (height 10.62 studs, faces -Z, one box hitbox 3.4x5.4x6.4, root anchored). Raw import kept at `ServerStorage.TortidragonImport_v1`.
  - New: `tools/WildboundCandyTortidragon(.luau, Attack, Clips)`, `src/wildbound/WildboundBeastTortidragon.luau`,
    `WildboundCandyTortidragonService.server.luau`, `WildboundCandyTortidragonAnim.client.luau`, 4 suites. Wiring: BeastConfig
    (Tortidragon entry, WAVE2, SUMMONED), Beasts.server KIDS, PraderaSites post `candyNestC3` (510, -143), Text lines,
    BeastsClient draws a `multi` of circles + Tortidragon tell colour FFD23F; Wiring and CandyBeastSites suites extended.
    Manifest rows + pins (10), runner SPECS (4).
  - Attack Abanico de Confites: fan 55 deg / 12 studs, tell 1.00 s, lock 0.60 s, 3 circles r2.3 (side shots 20 deg), flight
    0.65 s, impact at 1.65 s (one hit per player), push 4 studs/0.3 s + slow x0.85 0.8 s, damage 0, keepsEgg, recover 0.85 s,
    cooldown 7 s, no cast at a target behind or beside it (turns at 240 deg/s first). Patrol 10, chase 16, sight 22, leash 35.
  - TDD (fresh loadstring+setfenv loader): RED Attack (module missing) -> GREEN 7/7; Prefab RED 0/6 -> GREEN 6/6; Clips 8/9
    (the published-ids case stays RED: no clip ids); Brain RED (module + config missing) -> GREEN 9/9; CandyBeastSites 9/9;
    BeastWiring 49/49; regression Attack 13, Director 47, Encounters 24, Gomibu 9, Flanfuria 10, CandyFlanfuria 7, CandyGomibu 7: 117/0.
  - Studio == repo after the writes (bytes, Adler-32): BeastConfig 29446 2640d5b2, Beasts.server 45050 60b3562e, PraderaSites
    4748 10e63213, Text 36126 4aaa21a1, BeastsClient 50938 d27b6bc3, BeastWiring_Test 48219 f5a9c8dd, CandyBeastSites_Test
    10093 3023c442, CandyTortidragon 4295 b3808eb0 (+_Test 6795 9d178129), Attack 6259 74f8fab1 (+_Test 5875 57230cbc), Clips
    11124 401e2982 (+_Test 10341 eb89c78c), BeastTortidragon 7825 8c2f0bc4 (+_Test 9339 95b99dc5), Service 1629 73453c80,
    Anim 5124 1207a30b. Studio was checked equal to HEAD before writing (no other session's changes).
  - Solo Play (PlayLock CA2, cleared; Play stopped): at the post the dragon went Release -> Recover -> Chase with the three
    candies flying; a hit took WalkSpeed 16 -> 13.60 (x0.85) and back; a sidestep of 8 studs after the lock: no slow (dodge
    works); a player past its reach left it waiting at the 35-stud leash. Screenshots `assets/exports/forest-kit/captures/`
    `ca2-tortidragon-fan-circles-pink-floor-desktop.jpg` (yellow fan + circles on the pink floor), `ca2-tortidragon-model-side-desktop.jpg`.
  - BLOCKED, clips: the universe 10774749224 is owned by group 465694015. Animations uploaded as user 11937129310 fail with
    "Requester does not have permission for Asset" in Edit and in Play (Flanfuria's clips are group-owned). The Assistant token
    refuses group uploads (403 "User not authenticated") and lacks `asset-permissions:write` to grant the universe Use. So the
    11 clips are not published; Clips.IDS is empty and the model plays no animation (it moves and attacks in its rest pose).
    The 11 KeyframeSequences build in Studio (1350 poses); `clips_to_rbxmx.py` mirrors them (checksum 98747.9572 vs Studio
    98747.9572). Studio-serialized Idle rbxm at `assets/exports/caramelo/tortidragon-clips-rbxm/`.
  - Python: 1195 tests, 1 failure = known `test_lumipol_v2` V1IsKept. Not run: WildboundText_Test, two players, phone.

- CA3 (2026-11-15): Don Glaseón.
  - Blender source `assets/blender/caramelo/don-glaseon/build_don_glaseon.py` (own scene "DonGlaseon"; 29 bones per the sheet incl.
    Jaw, CandyCrown, Licorice_01..03 on the right forearm; 14 one-colour meshes, rigid skin, no mesh named like a bone; pink
    faceted torso, huge toothed mouth, candy pile, long arms with cream claws, purple grape legs; no hat, crown or robe; 24.74
    studs). Uploaded as Model 91765062667935 (the only upload of CA3); InsertService import kept all 29 bones (Blender suffixed
    Body/Claw/Eye ".001", `DonGlaseon.assemble` strips it). Prefab `ServerStorage.WildboundAssets.DonGlaseon`; raw import kept at
    `ServerStorage.DonGlaseonImport_v1`.
  - New: `tools/WildboundCandyDonGlaseon(.luau, Attack, Clips)`, `src/wildbound/WildboundBeastDonGlaseon.luau`,
    `WildboundCandyDonGlaseonService.server.luau` (client model + a dormant copy on BossHome while no encounter lives),
    `WildboundCandyDonGlaseonAnim.client.luau` (clip per phase + licorice ribbon VFX), 4 suites. Wiring: BeastConfig (DonGlaseon:
    serverUnique, switchSeconds 4, batImmune, keepsEgg false, damage 0; WAVE2, SUMMONED), BeastDirector (BossBusy while one lives,
    BossResting for switchSeconds), PraderaSites (bossHome 578,-3 and bossTerritory 612,-3 = builder markers, wants = inside the
    62-stud territory, `bossPick`: rare-egg carrier first then nearest to home), Beasts.server (KIDS row with boss = true, excluded
    from summonPass; `bossPass` once per poll; targetOf carryingEgg + eggRarity; `Beast_bossAwake` telemetry), Server (one line:
    `EggRarity` attribute on the carried-egg backpack), Dodge.SOURCES (perfect dodge works on the lash), Text lines, BeastsClient
    lane colour 5B1A8C. Manifest rows + pins (10), runner SPECS (4).
  - Attack Látigo de Regaliz: lane 22 x 5 from the boss, tell 1.10 s, lock 0.60 s, lash 0.35 s, hit at 1.45 s (once), push 12
    studs along the lash; a carrier drops the egg via BeastHit (no slow), others also slow x0.85 0.7 s; damage 0; recover 1.0 s;
    cooldown 7 s; dodgeable (perfect dodge registered). States Dormant, Patrol, Suspicious, Roar (once), Chase (17, max 15 s,
    lash only with time left), Search (last seen, 3 s), Telegraph, Attack, Recover, LoseTarget, Return (walks home at 9, End
    "Return" at home: never teleports). Sight 36 (x1.25 for Rara/Epica/Legendaria carriers), heard running within 45, line of
    sight through world.lineOfSight, leash = territory 62 (marker), never steps into a safe zone; a safe/dead/left target makes
    it drop an open lash (TellEnd) and walk home. Bat immunity is by construction (WildboundBat is PvP only).
  - TDD (fresh loadstring+setfenv loader): Attack RED (module missing) -> GREEN 5/5; Prefab RED 0/6 -> GREEN 6/6; Clips RED (module
    missing) -> 6/7 (the published-ids case stays RED: no clip ids); Brain RED (module missing) -> 8/13 (a test-helper bug, fixed in
    the test) -> GREEN 13/13; BeastWiring RED 48/50 -> GREEN 50/50; CandyBeastSites 10/10 (its new CA3 case ran after Sites/Config
    were already pushed, so it had no RED of its own). Regression: Director 47, Encounters 24, Dodge 14, Text 20, Audience 17,
    Attack 13, Gomibu 9, Flanfuria 10, Tortidragon 9, CandyTortidragon 6, EggCarry 39, LumipolArt 12: all passed.
  - Studio == repo after the writes (bytes, Adler-32): BeastConfig 31089 450ced04, BeastDirector 14874 5dc5908f, PraderaSites 6227
    144c1889, Beasts.server 46986 4004dc9e, BeastsClient 51090 63559cea, Text 36545 43acaffc, Dodge 9182 6ea9b382, Server 208966
    f8c39bc2, BeastWiring_Test 49273 a7612a74, CandyBeastSites_Test 11645 1e8cd355, BeastDonGlaseon 12717 ea7c5005 (+_Test 13872
    13a93685), Service 3417 2fefa7e0, Anim 5258 185fca6b, CandyDonGlaseon 4332 0cd3826d (+_Test 6433 e570efec), Attack 4568
    4aebe341 (+_Test 4216 996a1dc4), Clips 11370 4b5f62c4 (+_Test 5307 feac9ec2). Studio was checked equal to HEAD before writing.
  - Solo Play (PlayLock CA3, cleared; Play stopped): the dormant model stood on BossHome (578, 0.58, -3). Standing at (556,-3):
    awake at once, the lash hit at ~4.1 s: WalkSpeed 16 -> 13.6 (x0.85) and a 13-stud push (556 -> 543), back to 16 at ~0.7 s;
    pushed out of the territory it went LoseTarget -> Return and the dormant model came back (awake false at ~6.8 s). Second run at
    (562,-3): client phases Spawn, Suspicious, Roar, Telegraph, Attack, Recover, Chase; the lane drawn 22 long in 5B1A8C; a 6-stud
    sidestep after the lock: WalkSpeed never dropped (dodged); the licorice ribbon appeared. No boss errors in the output.
    Screenshots: NOT taken (Studio screen_capture timed out three times in Play; desktop capture access was denied).
  - Not tested: the egg drop in Play (Caramelo nests are still disabled, so no egg to carry there), two players / target
    switching, phone, Search with real walls, the clips (unpublished). Python: 1195 tests, 1 failure = known `test_lumipol_v2` V1IsKept.

- CA4 (2026-11-15): one 300 s egg clock and fixed light per biome; the global day/night cycle is removed. This reverses the
  2026-11-14 decision "Mantener 300/60/300/60" (user request 2026-11-15, pack item 08).
  - Decisions, per system that read the day/night phase (what it keys on now):

| System | Before | Now |
|---|---|---|
| `WildboundWorldRules` cycle | `Rules.cycle(elapsed)` over PHASES 300/60/300/60, `startOffset`, `CYCLE_SECONDS` | Removed. `Rules.cycle()` returns the fixed `WORLD_PHASE` "Day" (clock `WORLD_CLOCK` 14, remaining 0); `FOREST_CONTENT_PHASE` "Night" |
| Lighting (world client) | `Atmos.at(state.clockTime, zone)` from the server cycle | `WildboundBiomeLight`: the preset of the biome the local character stands in, ~1 s blend (`alpha(dt) = 1 - e^(-3 dt)`), only this client's Lighting (+ ColorCorrection saturation/contrast/brightness). Caramelo Day + `candy` fog row (fogEnd 900), no wave variant; Bosque Night (variants kept); Pantano/Cementerio/Volcán Dusk; Abismo/Cuevas Night; Montañas/Hub Day |
| La Silueta (profile, Brain hunt/sight/memory, ambush timer) | Night profile in the fog (speed 8, detection 38), Brain Day/Twilight/Night rows | Fixed Day: base profile (6/28), Brain Day row (live tuning HUNT_DAY 17, SIGHT_DAY 60), day ambush delay. Key: none (no hidden night multiplier, pack 02 step 2) |
| Beasts (`WildboundBeasts.server` phaseAt) | night odds x2, Dusk buff, Nube night range | Fixed Day in every biome: no night odds, no Dusk buff, no Nube night range |
| Dusk (`WildboundDusk`, `Heist.stepDusk`) | two warnings + buff in Dusk | Inert (never Dusk); code kept so the tuning schema and MechanicsWiring pins stay |
| Island nests (`Heist.stepNightEggReset`) | empty egg nests restocked after the Night, plus a second spawn reroll | `Heist.resetNestsForWave(now, wave)` at each wave start (wave >= 2), idempotent by wave id, only empty nests (`wait_wave`/`wait`), waits while its island chases; no second reroll |
| Island adults (phase, deep sleep) | Dusk/Night wake radius, 11:00-13:00 deep sleep | Fixed Day, clock 14 (never the deep-sleep window) |
| Gather (`WildboundGather`, `worldClock`) | Nightbloom only at Night, wilts at Dawn | Key: forest content. Always the night table (the forest is always dark): Nightbloom always, never wilts |
| Hide, GuardianBrain PHASE_KEYS | by phase | Fixed Day row |
| Presentation (HUD hint, `Phase` attribute: fear stalk, Night Nose, audio) | server phase | Local biome mood: Bosque Night (stalks, Night Nose, night audio), Caramelo Day |
| WaveClock | 300 s, reroll at start | The only clock: `window()` Collect 0-289.999 / Warning 290-299.999, `holdAllowed()` (a hold begun in a Warning is refused, also right after the refresh; one begun before resolves), `ALERTS` 10/5/3/2/1 |
| SpawnClock | each spawn its own 300 s LIFETIME | `bindWave(state, endsAt)`: a random spawn born under a wave lives to that wave's end + `WAVE_GRACE` 1 s, so the wave's reroll always moves it first; special spawns keep their own life |
| Server egg prompts | no gate | steal hold and Arrullo refused in Warning (`Text.WAVE.locked`); countdown notices on the inventory client (`Text.WAVE.warning`) |
| World server | `CycleStartedAt`, `StudioClockShift` | gone; snapshot still sends the fixed phase/clock (unused by the client) |

  - Not changed on purpose: island eggs still sitting in a nest are not re-rolled at the refresh (identity kept; only the random
    spawns re-roll, as the pack allows "refrescar apariencia con identidad estable"); Caramelo nests are still `Enabled = false`
    (builder flag), so Caramelo has no eggs yet; `Balance.LIVE.dayCycle` (prepared, not wired) still lists 300/60/300/60.
  - TDD (fresh loadstring+setfenv loader, SPECS args). RED: WorldRules 38/3, Economy 19/3 (2 new + known ECO-20), HideWiring 13/1,
    BeastWiring 49/1, Dusk 8/1, SpawnClock 13/3, WaveClock 20/5 (4 new + known RW5), BiomeLight ERROR (module missing). GREEN:
    WorldRules 41/0, Dusk 9/0, HideWiring 14/0, BeastWiring 50/0, SpawnClock 16/0, BiomeLight 7/0, Settings 10/0 (re-pinned D12),
    Economy 21/1 and WaveClock 24/1 (only the known ECO-20 and RW5). One test bug fixed after GREEN: the CA4 window case expected
    only waveStarted at 300, but the first biome event also starts at 300 (`EVENT_FIRST`).
  - Regression, the 50 suites whose SPECS read a touched source or module (LumipolArt skipped: `inst:` token): all pass except the
    known pre-existing AN-3 (AnalyticsWiring), BZ7 (BaseZone), ECO-20, EL12 (EggLoop), HB-T3 (Hub), W1 (MechanicsWiring, the
    `canSteal(..., maxCarry)` text), RW5 (WaveClock). AN-3 and W1 were checked against HEAD's server source (same result);
    ECO-20 and RW5 also failed in the RED run before any source change; BZ7, EL12 and HB-T3 are listed as teammate failures in
    `odd/tasks/wildbound-suite-repair.md`.
  - Studio == repo after the writes (bytes, Adler-32): WorldRules 16518 15b6722d, WaveClock 13175 19e1e819, SpawnClock 15047
    53cc9082, Atmosphere 7145 8390ba8f, BiomeLight 5606 51e7ffb7 (new), World.server 82337 72413b84, World.client 65340 d33d780a,
    Server 209254 05a7ec58, Beasts.server 46644 2cc56627, Gather 7684 b5df3234, Text 36797 ee13000e, Client 46667 63ee83bd; tests
    WorldRules 27324 6fbf1410, Economy 20233 89c39f9c, HideWiring 9408 96495e78, BeastWiring 49386 cb8a4f24, Dusk 5666 9d5b1239,
    SpawnClock 13181 c06393f0, WaveClock 23182 c156cf0e, BiomeLight 6869 4b1e90b9 (new), Settings 4930 22a95ef1. Every touched
    Studio script matched HEAD before the first write. All compile (loadstring).
  - Solo Play (PlayLock CA4, cleared; Play stopped): server runtime has no `CycleStartedAt`, `Rules.cycle` Day/14. Client: spawn
    at the hub (298,-3) Phase Day, ClockTime 13; teleported into Caramelo (620,60): after 0.5 s Clock 13.8, FogEnd 771, grading
    0.064/0.032/0.024; after 1.1 s 13.97 / 881 / 0.078; 2.1 s 14.00 / 899 / 0.080 0.040 0.030 (Brightness 3, Exposure 0). Into
    the forest (20,-40): 0.5 s Clock 22.1, Bright 1.55; 1.1 s 23.7 / 1.25 / FogEnd 77; 2.1 s 23.98 / 1.20 / -0.50 / 47, Phase
    Night. Back to Caramelo: 1.1 s 14.35, 2.1 s 14.02 bright again. Waves with the dev tuning `World.WAVE_SECONDS` 30 (restored
    to 300): a HeistProbe steal 21 s into the wave (Warning) was refused, the refresh came at 30.11 s, a steal 1 s later was
    accepted (same egg), the wave id changed once (3 to 4) and stayed; WildSpawns stayed 11. The client showed "Los huevos se
    renuevan en 10 s", 5, 3, 2, 1 at the expected times. No script error in the output.
  - Not tested: two clients in different biomes at once, phone, 15 minutes / three full 300 s waves in Caramelo, a late join's
    countdown, the nest restock in Play (no island nest was emptied during the check), reconnect. Screenshots: none (Studio
    screen_capture timed out in Play again).
  - Python: `tools/wildbound_economy_sim_v2.py` read the PHASES lengths (stored, never used): it now reads `WORLD_PHASE`
    (35 errors on the first full run, fixed). Final full run: 1195 tests, 1 failure = the known `test_lumipol_v2` V1IsKept.
  - Commit 91e29d7.

## Follow-up CF (2026-11-15): the forest plays by night rules

User intent (2026-11-15): no global day/night cycle; Caramelo always bright; "Bosque siempre de noche": the forest is
always dark AND plays by night rules. After CA4, `Rules.cycle()` was hard-wired to Day, so in the forest La Silueta used
her Day profile, beast odds were no longer doubled, island parents lost their night pattern; only gather, stalk, Night
Nose and audio keyed on `FOREST_CONTENT_PHASE`. The user asked not to be stopped by decisions: each one taken for them
is listed below.

- [x] CF1 Per-place gameplay phase: one pure `BiomeLight.phaseAt(x, z)` routed through every server phase reader,
  keyed by the position of the player or entity concerned; Nightbloom gets its own wilt timer. Route: inline (writer
  trigger fired: 2+ non-trivial files; kept inline because every Studio write needs the parent's fingerprint gate).
  TDD strict. Commit 58220a1.
- [ ] CF2 (assigned by the follow-up workflow; not part of this task).
- [ ] CF3 (assigned by the follow-up workflow; not part of this task).
- [ ] CF4 (assigned by the follow-up workflow; not part of this task).

### Decisions taken for the user

1. **Where the phase function lives:** `BiomeLight.phaseAt(x, z) -> phase, clockTime` in the shared, pure
   `ReplicatedStorage.WildboundBiomeLight`, next to the light presets and the biome squares (already kept equal to
   `WildboundBiomes` by a suite), so the look and the rules of a place come from one table (`BiomeLight.RULES`). Not
   in `WildboundWorldRules`, which stays free of requires and would have needed a third copy of the squares.
2. **Per-place rules:** Bosque (forest square, incl. the I3 swamp island inside it), Abismo, Cuevas = **Night**;
   Caramelo, hub (and anything between biomes or a bad point), Montañas = **Day**.
3. **Dusk-look biomes (Pantano, Cementerio, Volcán) play by Day rules.** Their dusk is a look only; a permanent Dusk
   phase would fire "night is coming" warnings forever and a permanent x1.25 beast buff.
4. **Dusk stays disabled.** No place resolves to Dusk or Dawn; `Heist.stepDusk` keeps reading the fixed world phase
   (`islandCycle()` with no island = `Rules.cycle()`, Day), so its warnings and buff are inert. Code kept for the
   tuning schema and MechanicsWiring pins.
5. **Rules clock:** Night = 0, Day = 14 (`BiomeLight.RULES_CLOCK`), both outside the islands' 11:00-13:00 deep sleep:
   forest parents never get the noon deep sleep (it was a daytime rule).
6. **What each system keys on:** La Silueta's profile, brain row (hunt, sight, memory) and hearing = her own body's
   position; hide discovery = the hiding spot; first ambush timer = her spawn body (later timers use her step's phase);
   beast odds, Dusk buff and Nube night range = the player's position; island content, wake radius, sleep = the
   island's nest position. The world snapshot's `phase` (unused by clients since CA4) reads the hub's Day.
7. **Gather / Nightbloom:** keep the forest's night gather table (Nightbloom always rollable), but a Nightbloom node
   now wilts on its own timer, `GatherField.NIGHT_ONLY_SECONDS` = 300 s after it appeared (the old Night length), and
   its place refills after the normal respawn. Before CA4 Nightbloom existed ~42% of the time (300 s of 720 s); now it
   can roll at any time, so Nightbloom income rises (not rebalanced: flagged as a balance risk to measure). Prompt
   text changed from "se marchita al amanecer" to "se marchita pronto".
8. **Not changed:** `Rules.WORLD_PHASE`/`FOREST_CONTENT_PHASE` stay (other readers and pins use them); client
   presentation keeps the local biome mood from CA4.

### Evidence CF1

- Studio instance ba5a21af (place 122652861404212, Edit, PlayLock nil). Before any write every touched Source matched
  HEAD a81d3f0 (bytes, Adler-32): BiomeLight 5606 51e7ffb7, World 82337 72413b84, Server 209254 05a7ec58,
  Beasts.server 46644 2cc56627, GatherField 5231 1100d6d5, Gather 7684 b5df3234, Text 36797 ee13000e, BeastWiring_Test
  49386 cb8a4f24, HideWiring_Test 9408 96495e78, GatherField_Test 10518 ceff143b. No pull was needed.
- New suite `tests/WildboundPlacePhase_Test.luau` (manifest row + pin, runner SPECS). Behavioural cases: the phase of
  12 points (forest, swamp island, Abismo, Cuevas = Night; Caramelo, hub, Montañas, Pantano, Cementerio, Volcán, bad
  point, nil = Day); no preset has Dusk/Dawn rules and no rules clock is in the deep sleep; La Silueta's
  `resolveCreatureProfile` 8/38 in the forest fog vs 6/28 in Caramelo and the forest brain row equal to Night's;
  `Director.multiplier` 2 in the forest vs 1 in Caramelo and a real beast's `Director.chance` exactly doubled; every
  island Night with its `wakeNight` radius; `Ambush.nextDelay` NIGHT_MIN at home vs DAY_MIN in Caramelo. Plus wiring
  pins on World, Server and Beasts. `WildboundGatherField_Test` gained the CF1 own-timer case and a wiring case.
- RED (fresh loader: the runner engine from `tools/studio-fresh-runner.luau` with the touched suites' SPECS, loaded from
  a temporary ServerStorage StringValue, destroyed after): PlacePhase 0/8 (`BiomeLight.phaseAt missing`), GatherField
  11/2, BeastWiring 49/1 and HideWiring 13/1 (their CA4 pins re-pointed to the CF1 text).
- GREEN: PlacePhase 8/0, GatherField 13/0, BeastWiring 50/0, HideWiring 14/0, BiomeLight 7/0, GuardianBrain 26/0,
  Ambush 12/0, Dusk 9/0, WorldRules 41/0. Regression, the 43 suites whose SPECS read a touched source or module
  (LumipolArt left out: `inst:` token): 635 passed, 7 failed, all known pre-existing (AN-3, BZ7, ECO-20, EL12, HB-T3,
  W1, RW5; same list as CA4).
- Studio == repo after the writes (bytes, Adler-32), all compile: BiomeLight 6799 a7d9899b, World 82980 bc01140d,
  Server 209852 05c1b896, Beasts.server 46895 a789b8c5, GatherField 5785 03cb8b43, Gather 7757 86bc4999, Text 36792
  d3cafe78, BeastWiring_Test 49403 30ff545b, HideWiring_Test 9453 38d76c83, GatherField_Test 12203 b30334a5,
  PlacePhase_Test 8580 5fdadfb9 (new).
- Solo Play (PlayLock CF1, cleared; Play stopped): `IslandProbe read` phase Night; La Silueta (Patrol at -3,-99)
  resolves Night at her body; `BeastProbe context` at the forest (60,-60): night = true, multiplier 3.60 (= 2 night x
  1.2 far x 1.5 danger); in Caramelo (620,-7): night = false, multiplier 1.20; hub: safe, 1.00. Two Nightbloom
  prompts showed "Nightbloom x1 · se marchita pronto". No script error from the touched scripts (only the usual
  asset/TexturePack and DataStore messages). A player placed 64 studs from La Silueta saw her close to 36 studs in 4 s
  while she stayed in Patrol (stalk hold): her night hunt speed and sight were not measured in Play.
- Python: 1195 tests, 1 failure = the known `test_lumipol_v2` V1IsKept.
- Commit 58220a1.
- Not tested: a Nightbloom node really wilting after 300 s in Play, La Silueta's night hunt speed/sight in a chase,
  Nube night range in Caramelo (now never night, by design), two players, phone, the economy effect of always-on
  Nightbloom.

## Next step

- CA5 close: a two-client lighting check (one in the Bosque,
  one in Caramelo at once) and a 15-minute / three-wave stay in Caramelo; enable the Caramelo nests through the builder when the
  user wants Caramelo eggs.
- Owner action for CA2 and CA3 clips (unchanged): publish them to group 465694015 (or grant the Assistant group upload or the
  `asset-permissions:write` scope), then fill Tortidragon and Don Glaseon `Clips.IDS` and rerun both Clips suites and a Play check.

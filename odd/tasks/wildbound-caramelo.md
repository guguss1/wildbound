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
- [x] CF2 Wave gate and egg refresh: a steal hold that would end inside the Warning window is refused when it
  starts (`WaveClock.holdFits`); the window, `holdAllowed`, `endsAt` and the refresh read the wave's bound end; a
  held spawn kept through the reroll gets the new wave's expiry; the nest refresh runs through a pure
  `Island.waveRefill` core. Route: inline (writer trigger fired: 4 non-trivial files; kept inline because every
  Studio write needs the parent's fingerprint gate). TDD strict. Commit bfdcfbb.
- [x] CF3 Boss robustness: Don Glaseon's `batImmune` is enforced by both bat hit resolvers (`Bat.immune` in
  `Bat.pickTarget`, `BatImmune` refusal in `Knock.knock`, the server passes the flag); `Beast_bossAwake` is written
  when an encounter starts (before its Spawn message) and ends, so the sleeping copy goes in the summon's own step;
  the sleeping copy stays on BossHome but is pass-through (`DonGlaseon.asleep`); `Balance.LIVE.dayCycle` describes
  the wave clock and per-biome light; the missing receipt line for 81874477774437. Route: inline (writer trigger
  fired: 7 non-trivial files; kept inline because every Studio write needs the parent's fingerprint gate). TDD
  strict. Commit 542023e.
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
9. **CF2, when a hold is judged:** at its start, against the hold the server measures (`Gear.stealHold` with the
   player's glove, the same `need` the trigger uses). Refused when it starts inside a Warning window (this wave's or
   the one just before the refresh) or would end inside this wave's Warning window. A hold spanning the whole
   warning (only possible with a hold longer than 10 s) still resolves after the refresh, as in CA4. The Arrullo
   keeps its start-only check (it is a mini-game, not a timed hold).
10. **CF2, how the refusal reaches the player:** `Text.WAVE.locked` at once; when the refused player is the prompt's
   only holder the prompt is disabled for 0.25 s, which cuts the client's hold bar, then re-enabled (an island egg's
   prompt is re-synced to its nest every island step anyway). With other holders the prompt is left alone so their
   holds go on. The refused hold is remembered (`refused = true`) so a completed bar never steals.
11. **CF2, the bound wave end is the one truth:** the refresh (`due`), the window, `holdAllowed`, `holdFits` and
   `WaveClock.endsAt` read `state.waveEndsAt`, set when the wave starts (= the `waveStarted` event's `endsAt`, the
   value `SpawnClock.bindWave` gets). A tuned `WAVE_SECONDS` now applies from the next wave, not to the running one
   (before, a live change shortened the running wave). Dev checks that tune the wave must wait for the current wave
   to end once.
12. **CF2, held spawn through the reroll:** it gets the new wave's expiry (`waveEndsAt + WAVE_GRACE`, `waveBound`),
   as recommended; a special (event) spawn keeps its own life. Before, the step right after the hold ended expired it
   on the old wave's timer.
13. **CF2, the refresh core:** `Island.waveRefill(nestState, nestGen, chasing)` in the pure `WildboundIsland` (the
   server already requires it): empty nests (`wait_wave`, `wait`) get a new generation and open; a chasing island's
   nest waits for the server's 1 s retry; eggs in a nest, returning crias and the egg registry are never touched.
   New suite `WildboundNestRefill_Test` rather than widening `WildboundIsland_Test`'s signature.
14. **CF3, where bat immunity is enforced:** in both pure hit resolvers. `Bat.immune(candidate)` is true for a
   candidate flagged itself (`batImmune`) or by its beast config (`config.batImmune`); `Bat.pickTarget` skips it (the
   next valid target behind it is hit) and `Knock.knock` refuses it with reason `BatImmune` before its record is
   created (no ragdoll, no anti-chain immunity). The bat stays player against player: the server still offers no
   beast as a candidate (adding beasts as bat targets would be a new mechanic nobody asked for); it passes
   `batImmune = Bat.immune(target)` to the knock so the rule holds if one ever is.
15. **CF3, the sleeping copy at summon:** one answer, `Config.bossAwake(live)` (the pure beast config module the
   server already requires), written by a `publishBoss()` right after an encounter enters `live` in `start` (before
   the Spawn message) and right after one leaves it in `close`, and still on every snapshot. The service's existing
   attribute listener hides or shows the copy in that same server step.
16. **CF3, the sleeping copy in the lane: made pass-through, not moved.** It stays on BossHome (578, -3), where every
   summon starts, so the wake never jumps and the BossHome marker, the builder layout and their pinned suites stay
   as they are (moving it would need a Caramelo rebuild in the Workspace). `DonGlaseon.asleep` turns off CanCollide,
   CanTouch and CanQuery on every part of the copy and marks it `BeastSolid = false`; the prefab and the live boss
   keep their hitbox. Trade-off: a player can walk through the sleeping model.
17. **CF3, `Balance.LIVE.dayCycle`:** `{ fixed = true, waveSeconds = 300, warningSeconds = 10, rules = <phase per
   place>, light = <mood per preset> }`, read by `Balance.liveFrom` from `WildboundWaveClock.CONSTANTS` and
   `WildboundBiomeLight.RULES`/`PRESETS` (B23 now loads both). `conflicts()` reports one line, "no day/night cycle",
   instead of comparing phase lengths that no longer exist; a passed cycling world is still compared as before.
   `Balance.CONSTANTS.dayCycle` (the proposed 240/60/300/120) is not changed. The overview's 2.0 balance note is
   updated to match.
18. **CF3, receipts:** the Idle v2 done line (81874477774437) is written from the id and state already recorded in
   this document; the operation was not polled again (no Open Cloud call). Both Idle uploads are marked UNUSED.

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

### Evidence CF2

- Studio instance ba5a21af (place 122652861404212, Edit, PlayLock nil). Before any write every touched Source matched
  HEAD f9b0835 (bytes, Adler-32): Server 209852 05c1b896, Island 24114 f010257c, SpawnClock 15047 53cc9082,
  WaveClock 13175 19e1e819, SpawnClock_Test 13181 c06393f0, WaveClock_Test 23182 c156cf0e, EggCarry_Test 41622
  34ea7029. No pull was needed.
- New cases: WaveClock_Test 3 (holdFits boundaries 286.9/287/289/292/285+20 s, bad input, the refresh; the bound
  end under a mid-wave tune to 30 s: window Collect at 25, no refresh at 30, wave 2 at 300 ends at 330, its warning
  at 321; the server wiring), SpawnClock_Test 1 (a held spawn keeps its identity through the reroll, expiresAt
  301 -> 601, survives the step at 305, leaves at 601; a special keeps 460), new suite `WildboundNestRefill_Test` 5
  (behavioural: carried, dropped, secured and in-nest eggs, a cria wait, a returning cria and a chasing island; the
  egg registry deep-equal before/after; a simulated ensureNests spawns only into I2/I3/I4; second call and bad input;
  the server runs the core). `WildboundEggCarry_Test` HB-T7 pin re-pointed to `{ at = now }`.
- RED (fresh loader: the runner engine from `tools/studio-fresh-runner.luau` in a temporary ServerStorage StringValue
  with the touched suites' SPECS, destroyed after): NestRefill 0/5 (`Island.waveRefill missing`), SpawnClock 16/1
  (expected 601, got 301), WaveClock 24/4 (3 new + known RW5).
- GREEN: NestRefill 5/0, SpawnClock 17/0, WaveClock 27/1 (known RW5), EggCarry 39/0. Regression, the 34 suites whose
  SPECS read a touched source or module plus Tuning: 527+12 cases, failures only the known AN-3, BZ7, ECO-20, EL12,
  HB-T3, W1, RW5 and DT1 (Tuning_Test: schema `Eggs.STEAL_HOLD` 0.8 vs `EggCarry` 0.5; neither file touched here,
  pre-existing). HB-T7 failed once (the pin) and passes after the re-point.
- Studio == repo after the writes (bytes, Adler-32), all compile: Server 211002 5ae83f52, Island 25780 8f265def,
  SpawnClock 15411 1d480bdf, WaveClock 14894 7ae24a28, SpawnClock_Test 14960 9e3fd92a, WaveClock_Test 27254 99df06c4,
  NestRefill_Test 6917 fcf08c88 (new), EggCarry_Test 41801 8aa7ac11.
- Solo Play (PlayLock CF2, removed after; Play stopped; dev tuning `World.WAVE_SECONDS` 30 set 3 s after start,
  restored to 300): wave 1 did not refresh at 30 s (bound end), wave 2 came at 300 s, then waves every 30 s (wave 3
  at +30.08 s). Island I2: a HeistProbe steal (Egg:61 Carried), the woken parent knocked it loose (Dropped at +1.8 s,
  gone at +11.3 s with its drop time), and at the next refresh the empty nest got a new egg (Egg:112) while Egg:5
  and Egg:6 kept their identity. No script error (only the usual DataStore/asset messages).
- Python: 1195 tests, 1 failure = the known `test_lumipol_v2` V1IsKept.
- Commit bfdcfbb.
- Not tested: the hold-start refusal through a real prompt in Play (from the Studio client `InputHoldBegin` never
  fired `PromptButtonHoldBegan`: no prompt was shown to the command-bar client), so the 0.25 s bar cut is untested;
  a carried egg held across a refresh in Play (the I2 parent always knocked it loose); a held wild spawn across a
  reroll in Play; two players, phone.

### Evidence CF3

- Studio instance ba5a21af (place 122652861404212, Edit, PlayLock nil). Before any write every touched Source matched
  HEAD 4329717 (bytes, Adler-32): Server 211002 5ae83f52, Bat 7547 c9d1c189, BeastConfig 31089 450ced04,
  Beasts.server 46895 a789b8c5, BatKnock 7579 ce96d3b6, Balance 26840 e8ce415d, Balance_Test 19120 2a24cbc2,
  CandyDonGlaseon 4332 0cd3826d, CandyDonGlaseonService 3417 2fefa7e0, BeastWiring_Test 49403 30ff545b. No pull
  was needed.
- New suite `tests/WildboundBossRobustness_Test.luau` (manifest row + pin, runner SPECS), 8 cases. Behavioural:
  `Bat.immune` on the real Don Glaseon config, a flagged candidate, a player and Viper's config; `Bat.pickTarget`
  with the boss 2 studs in front and a player at 5 (the player is hit), the boss alone (nil, NoTarget), Viper as a
  control (picked); `Knock.knock` with the flag and with the config (BatImmune, no ragdoll, no immunity; the same key
  then lands without the flag); `Config.bossAwake` over a live table as entries enter and leave, malformed and bad
  input; `DonGlaseon.asleep` on a spawned copy of the real prefab (every part pass-through, the prefab's hitbox still
  collides). Wiring: `publishBoss()` after the `live` insert and before the Spawn message in `start`, after the
  removal in `close`; the server's knock passes `Bat.immune(target)`; the service requires the module and puts the
  copy to sleep. `WildboundBalance_Test`: B20 pins the new LIVE.dayCycle, B21/B22 the new conflict line, B23 loads
  WaveClock and BiomeLight, new B24 (behavioural liveFrom: a fixed world, broken sources, a cycling world).
  `WildboundBeastWiring_Test` CA3 pin re-pointed to `Config.bossAwake(live)`.
- RED (fresh loader: the runner engine in a temporary ServerStorage StringValue, destroyed after): BossRobustness
  0/8 (`Bat.immune missing`, `Config.bossAwake missing`, `DonGlaseon.asleep missing`, ...), Balance 22/3 (B20, B21,
  B24), BeastWiring 49/1 (the re-pointed pin).
- GREEN: BossRobustness 8/0, Balance 25/0, BeastWiring 50/0. Regression, the 54 suites whose SPECS read a touched
  source or module plus Tuning (LumipolArt included): 808 passed, 8 failed, all known pre-existing (AN-3, BZ7,
  ECO-20, EL12, HB-T3, W1, DT1, RW5).
- Studio == repo after the writes (bytes, Adler-32), all compile: Server 211034 0f244a65, Bat 8123 5cee8a80,
  BeastConfig 31673 2d04b63c, Beasts.server 47165 58801d54, BatKnock 7854 c2f13083, Balance 29142 3af324b1,
  CandyDonGlaseon 4934 56864d51, CandyDonGlaseonService 3779 540626e8, Balance_Test 21861 a328203a, BeastWiring_Test
  49464 6b6168d6, BossRobustness_Test 7497 ada88718 (new).
- Solo Play (PlayLock CF3, removed after; Play stopped; back in Edit with no runner value or lock left): the sleeping
  copy stood on BossHome (578, 0.58, -3) with 16 parts, none colliding, touching or queryable; a ray down at BossHome
  hit `Candy_Bioma_v1.Ground.Plaza`. Teleported into the territory at (606, 10): the boss woke 0.18 s later;
  `Beast_bossAwake` turned true and the copy left the Workspace in the same Heartbeat frame (523); the client saw only
  `WildboundBeastsLocal.DonGlaseon`. Leaving to (430, -3): the encounter ended and the attribute and the copy came
  back in one frame (1483). Walking east along z = -3 from x 560, the player passed through the sleeping copy at 578
  and stopped at 585.5 against the Gran Torta (radius 26 around 612). No script error (only the usual
  asset/TexturePack and DataStore messages).
- Python: 1195 tests, 1 failure = the known `test_lumipol_v2` V1IsKept.
- Commit 542023e.
- Not tested: a real bat swing at Don Glaseon (the server offers no beast as a target, and a swing needs a second
  player); that the write at summon comes from `start` rather than the snapshot is shown by the wiring order only
  (Play showed the same-frame hide, which either write gives); two players, phone.

## Follow-up CE (2026-11-15): Caramelo eggs, pets and portals

User intent (2026-11-15): explain what publishing the Tortidragón / Don Glaseón clips to the group is for and how it is
done; make Caramelo nests steal-able; give Gomibú, Flanfuria and Tortidragón an egg, a farm version and a hotbar icon;
start T08b (return portals, `odd/tasks/wildbound-2-0.md`). Authorized for this batch: one 256x256 hotbar icon upload each
for Gomibú, Flanfuria and Tortidragón. No other upload, no publishing, no place save, no monetization. The user asked not
to be stopped by decisions: each one taken for them is listed below. TDD strict (fresh loader in Studio).

- [x] CE0 Clips ready for the owner to publish: every Tortidragón and Don Glaseón clip built as a KeyframeSequence into
  `ServerStorage.WildboundPublishClips.<Creature>.<Clip>` with a Spanish README; pure helper
  `WildboundCandyClipPublish` (pending, parseId, idsSource, build); no upload. Route: inline (one new module + suite,
  manifest/runner rows; no trigger fired). TDD strict. Commit 7c5c044.
- [x] CE1 Caramelo nests with eggs to steal: the Candy builder's nests are island nests of the one island system
  (`WildboundCandyNests` merged after the trail nest; one egg each, no sleeping parent, the 300 s wave refill, the same
  steal hold / Arrullo, backpack and bank), species by rarity, each guardian post bound to its nest, live through
  `Layout.NESTS_ENABLED` + `Builder.syncNests`. Route: inline (one new module + suite; small additive edits to
  WildboundServer, Island, Species, Text, CandyLayout, CandyBuilder; the 4-file mapping read stayed in the parent because
  this worker may not delegate). TDD strict. Commit f2e0c77.
- [x] CE2 Caramelo pets: a banked Caramelo egg incubates by its rarity (Común 15 s, Rara 45 s, Épica 60 s) and hatches
  into Gomibú, Flanfuria or Tortidragón, registered and saved like any creature (no schema step: the record only needs a
  species string), never the companion (`Species.FARM_ONLY`, `State.farmOnly`: no auto-equip, `equip` refuses
  `FarmOnly`); a hotbar tool with its own icon (`Toolbar.ICONS`, three uploads); in the farm a scaled-down copy of the real
  rig (`WildboundCandyPets.build`, injected as the Toolbar's `farmModel`), passive (no brain, no collision, no light),
  wandering like the Lumipol and playing its published FarmIdle / walk clip from the server (`FarmWalking`). Route: inline
  (one new module + suite; small additive edits to Toolbar, Species, State, Text, Server; the writer trigger fired but
  every Studio write needs the parent's fingerprint gate, and this worker may not delegate). TDD strict. Commit
  551f56e.
- [x] CE3 Return portals (T08a + T08b of `odd/tasks/wildbound-2-0.md`): pure rules `WildboundPortal` (calm 5 s, channel
  2 s, rest 30 s, refusals, cuts, threat signals, the two stations), the server service `WildboundPortalService` (started
  by WildboundServer; the prompt's server-side Triggered is the only input; teleport to the own base pad, the hub spawn pad
  without a base), the forest arch built by the service at start, the Caramelo arch switched on through
  `Layout.PORTAL.enabled` + `Builder.syncPortal`, the client bar and prompt wait (`WildboundPortalClient`), Spanish words
  in `Text.PORTAL`, a beast-engagement stamp in WildboundBeasts. Route: inline (two new modules + one client + two
  suites; small additive edits to Server, Beasts, Text, CandyLayout, CandyBuilder; the writer trigger fired but every
  Studio write needs the parent's fingerprint gate and this worker may not delegate). TDD strict. Commit e10e8f1.

### CE0: qué es publicar las animaciones y cómo se hace

**Para qué sirve (sí se ve en el juego).** La experiencia pertenece al grupo 465694015. Roblox solo deja reproducir una
animación si su dueño es el mismo que el de la experiencia. Las que el asistente sube quedan a nombre del usuario, así
que en el juego no cargan: Tortidragón y Don Glaseón ya atacan, persiguen y hacen daño, pero se mueven rígidos, en pose
de reposo (sin caminar, sin telegrafiar el ataque con el cuerpo, sin rugido). Publicadas a nombre del grupo, se animan.
No es un trámite de Studio: es lo que hace que se vean vivos.

**Pasos (unos 10 minutos, 22 animaciones):**

1. Studio en modo Edit (no Play), en la place 122652861404212.
2. Explorer > ServerStorage > `WildboundPublishClips` > `Tortidragon` (luego `DonGlaseon`). Ahí está cada animación
   con el nombre de su clip (`Idle`, `Walk_Quadruped`, ...) y un `README` con estos mismos pasos.
3. Clic derecho en una animación > **Save to Roblox** (Guardar en Roblox).
4. En la ventana: **Creator = el grupo** (no tu usuario). Nombre sugerido `Tortidragon_<clip>` / `DonGlaseon_<clip>`.
   Submit.
5. Copia el id del final (el número o el enlace: los dos sirven).
6. Repite con las 11 de cada criatura.
7. Pásale los 22 ids al asistente (en cualquier formato: "Idle 1234...", enlaces, rbxassetid://...). Él los pone en
   `Clips.IDS` de `WildboundCandyTortidragonClips` y `WildboundCandyDonGlaseonClips`, corre las suites y prueba en Play.
   Los servicios ya leen `Clips.IDS`: no hace falta tocar nada más.

Si la carpeta no está (Studio se cerró sin guardar), el asistente la vuelve a crear con `Publish.build` en un paso.

### Decisions taken for the user (continued)

19. **CE0, where the clips wait:** `ServerStorage.WildboundPublishClips` (server-only, never replicated, read by no
   service), one folder per creature, each KeyframeSequence named exactly as its clip key, built by the same
   `Clips.build` the clip suites check, so what the owner publishes is what the data says.
20. **CE0, the services are not touched:** both services already set `Clip_<name>` from `Clips.IDS` for every id
   present, and both clients already play `Clip_<name>`; a suite case pins that line in both sources and checks that a
   pasted id becomes `rbxassetid://<id>` and leaves the pending list.
21. **CE0, the helper:** `WildboundCandyClipPublish` in ServerStorage (a tool, like the Clips modules): `pending`
   (clips still without an id), `parseId` (a number, `rbxassetid://`, or a roblox.com / create.roblox.com link),
   `idsSource` (the exact `Clips.IDS = { ... }` line, in ORDER, refusing unknown clips and non-ids), `build`
   (idempotent; keeps any other child the owner adds).
22. **CE0, not saved by the assistant:** the folder lives in the open session (no place save in this batch). If it is
   lost, `Publish.build` recreates it in one call. README text without accents (plain ASCII in a StringValue).

23. **CE1, which species each nest holds (pack 06_PROMPTS_CLAUDE/07):** Común -> Gomibú, Rara -> Tortidragón, Épica ->
   Flanfuria; Legendaria -> Flanfuria (the best of the three) at Legendaria rarity. The workflow suggested Rara ->
   Flanfuria / Épica -> Tortidragón; the pack, the user's design source, says Tortidragón Rara and Flanfuria Épica, so
   the pack wins. Reward tiers as the random world's (Fog, FogFar, Territory, Heart). One table (`CandyNests.POOL`).
24. **CE1, the legendary nest L1 stays off:** it is `eventOnly` in the layout and there is no Caramelo event; the flag
   (`Builder.nestEnabled`) keeps every event-only nest off. 11 live nests (C1-C5, R1-R4, E1-E2).
25. **CE1, guardian binding:** each Caramelo guardian post (`PraderaSites.HOME`/`FIXED`) is bound to the nearest nest
   within 20 studs: Gomibú -> C1, Flanfuria -> R1, Tortidragón -> C3 (`entry.guard`). A nest keeps its rarity's species
   (C3 holds a Gomibú egg guarded by Tortidragón; R1 a Tortidragón egg guarded by Flanfuria): the ring colour and the
   egg's rarity stay one rule. Guarding is the beasts' existing behaviour: each bound nest lies inside its guardian's
   wake radius (40) and leash (16-35), so a thief at that nest is the guardian's target (pinned by a test). The other 8
   nests have no guardian; Don Glaseón keeps priority on Rara/Épica carriers in his territory (the carried egg's
   `EggRarity` is the nest's rarity; `Sites.bossPick` unchanged, pinned by a test).
26. **CE1, one egg per Caramelo nest, no parent:** the pack's nest has a hollow for a single egg, so a candy nest holds
   `eggs = 1` (`Island.nestCount` honours it; forest nests keep `EGGS_PER_NEST` 3). No sleeping parent, so a steal wakes
   nobody: `wakeIsland` returns at once for an island with no adults (no scream for La Silueta, no "parents woke"
   message, no chase), and the nest has no Zzz readout. The egg rests in the bowl (`nestTop`, read from the marker).
27. **CE1, the species keep their own look:** `Species.ONLY = "Lumipol"` rewrote every nest; `Species.KEEPS_OWN` /
   `keepsOwn` now exempts LumipolVioleta (as before) and the three Caramelo species. Stand-in looks until CE2: candy egg
   tints (Gomibú pink FF7FA8, Tortidragón orange F2A24A, Flanfuria caramel F5CD5A), primitive companion colours; names
   and blurbs in `Text.CARD`. Steal hold as the forest: Común/Rara the NH1 hold, Épica/Legendaria the Arrullo.
28. **CE1, how the nests are switched on:** `WildboundCandyLayout.NESTS_ENABLED = true` and `Builder.syncNests(root)`,
   run once on the live `Candy_Bioma_v1` (attributes only, no part moved). The server reads the markers' `Enabled` at
   start. As with CE0, nothing is saved by the assistant: in Team Create the attributes live in the session; if they are
   lost, one `Builder.syncNests` call restores them.

29. **CE2, the icons:** cropped from the pack's 3/4-front turnaround views (the Blender sources of Gomibú and Flanfuria are
   lost, Tortidragón's turnaround matches the other two), 256x256 on the sheet's own dark background like the Lumipol
   icon; files `assets/icons/<species>-hotbar-icon-256.png`.
30. **CE2, farm only, never the companion (pack 05/03: "Nunca autoequipar. No seguir por el mapa"):** `Species.FARM_ONLY`
   (Gomibú, Tortidragón, Flanfuria) set on State by the server (`state.farmOnly`); a hatch never makes them the companion
   and `equip` refuses with `FarmOnly` ("Esta criatura vive en tu barra y tu granja; no te sigue."). Lumipols keep NS3.
   The held hotbar tool keeps the species' primitive stand-in (only the farm uses the rig).
31. **CE2, the farm model:** a clone of the wild beast's prefab (`ServerStorage.WildboundAssets.<species>`) scaled so its
   visible height is Gomibú 3, Flanfuria 3.2, Tortidragón 3.6 studs (a Lumipol is about 1.5, a player 5.5); scripts,
   lights and package links removed; only the root anchored; nothing collides, touches or is queried; no light of its own.
   It stands on its pivot (its feet), so the Toolbar skips the bounding-box lift for it (the hidden root reaches 1 stud
   below the feet).
32. **CE2, animation:** played on the server's Animator (replicates to every client): `FarmIdle` at rest and the walk clip
   (Gomibú `Bounce_Move`, Flanfuria `Hop_Move`, Tortidragón `Walk_Quadruped`) while the Toolbar's wander walks
   (`FarmWalking`, set only when it changes). Tortidragón has no published clip yet, so it rests in its bind pose until the
   owner publishes the CE0 clips; once `Clips.IDS` holds them it animates with no code change.
33. **CE2, data:** no schema change. Esencia is the egg's nest tier (Fog 10, FogFar 16, Territory 24), rarity comes from
   `Species.LOOKS`, hatch time from `Incubator.RARITY_MULTIPLIER`, the collection entry from `discovered`: all existing.

34. **CE3, the egg rides along:** a player may use a portal while carrying an egg; it stays in the arms and the own base
   banks it on arrival as usual (pack 04_ENTORNO/03: a legitimate teleport never resets or consumes the egg). The heist
   tension stays in the calm rule: a portal only works after 5 s with no threat nearby, so it is an escape after breaking
   a pursuit, never an instant exit (`Portal.CARRY = "keep"`).
35. **CE3, what counts as a threat** (all server-written, never the client's): La Silueta's `WildboundThreatLevel` at Near
   or Chase (Distant does not count); a live beast encounter on the player (new `WildboundBeastEngagedAt` stamp written by
   WildboundBeasts, any phase but Disengage/Ended, at most twice a second); a bat hit (`WildboundBatHit`) or ragdoll
   (`WildboundRagdollUntil`); a health drop of 3 or more between two 0.1 s samples (`hurtMin`; Play showed the
   regeneration dipping 1 point a second, which must not count); an awake nest parent within 40 studs. Other players
   nearby are not a threat (a friend standing at the arch must not block it). A stamp counts for 1 s.
36. **CE3, the rules' numbers:** 5 s calm, 2 s channel, 30 s rest per player across both stations (Balance.portal and the
   Caramelo layout, pinned by PT-1); the server measures its own root within 10 + 2 studs of the station (the prompt
   reaches 8); the channel is cut by a threat noted after it started, moving more than 3 studs, leaving the range or
   dying; a cut costs no rest. Refusal order: Disabled, Dead (also ragdolled), TooFar, Busy, Cooldown, Threat, NoBase.
37. **CE3, where the player lands:** 3 studs over the centre of their own base's Pad, facing the hub centre (Play landed
   0.1 studs from the target). Without a base (a ninth player) the hub spawn pad of `Heist.hub:spawnFrame`; with neither
   the portal refuses NoBase.
38. **CE3, the stations:** two. Caramelo: the Candy builder's existing `Portal` arch at (772, -3) (layout marker (160, 0)),
   switched on by `Layout.PORTAL.enabled = true` and `Builder.syncPortal` (run once on the live biome; session-only
   attribute, no save; the service also checks the model is still at its spot). Forest: a small stone arch with a faint
   violet ring and light, built by the service at server start at (-28, -132), the south-west of the deep fog, on the
   only clear 12x12 patch a floor scan found there, 55 studs from La Silueta's home and 336 from the hub: the deepest
   escape, which her hunting makes hard to use. Neither is in a safe zone (PT-8).
39. **CE3, the UI:** the server's prompt "Volver a la base" with the station name; the client changes its words locally to
   "Listo en N s" while the player's rest lasts (from `WildboundPortalReadyAt`), draws a 2 s bar "Volviendo a tu base..."
   from the `PortalEvent` remote, and every refusal and cut arrives as an ordinary HUD notice with the wait in it. The
   client sends nothing. For the Play check a Studio-only server `ServerStorage.PortalProbe` BindableFunction stands in
   for the prompt and calls the same trigger.

### Evidence CE0

- Studio target: place 122652861404212 (universe 10774749224); was in Play at start, polled until Edit (about 2 min),
  PlayLock nil, runner lock nil.
- Fingerprints before (Studio == HEAD): TortidragonClips 11124 401e2982, DonGlaseonClips 11370 4b5f62c4,
  TortidragonService 1629 73453c80, DonGlaseonService 3779 540626e8; new scripts absent.
- RED (fresh loader: trimmed `tools/studio-fresh-runner.luau` with these three SPECS, in a temporary ServerStorage
  ModuleScript holder, destroyed after; module deployed as an empty stub): ClipPublish 0/6 (every case "attempt to call
  a nil value").
- GREEN: ClipPublish 6/0. TortidragonClips 8/1 and DonGlaseonClips 6/1: the one failure each is the known "every clip
  is published" case (empty `Clips.IDS`, the owner action below), unchanged.
- Studio == repo after the writes: WildboundCandyClipPublish 5175 1841ab03, WildboundCandyClipPublish_Test 6048
  d53d935a.
- Built in Studio: `ServerStorage.WildboundPublishClips` = README (1089 chars) + Tortidragon (Idle, Walk_Quadruped,
  Run_Quadruped, Turn, Alert, Attack_Telegraph, Attack_Release, Attack_Recover, HitReact, FarmIdle, HatchReact) +
  DonGlaseon (Idle_Breath, Patrol_Walk, Chase_Run, Notice, Search, Attack_Telegraph_Licorice, Attack_Release_Licorice,
  Attack_Recover_Licorice, HitReact_ImmuneBat, LoseTarget, Roar_Visual), keyframe counts equal to each clip's keys.
- Python: 1195 tests, 1 failure = the known `test_lumipol_v2` V1IsKept.
- No upload. Play not run: the folder is server-only data read by no script, nothing in Play changes until ids exist.
- Not tested: the "Save to Roblox" dialog itself (owner action) and the clips playing in the game (needs the ids).

### Evidence CE1

- Studio target: place 122652861404212 (universe 10774749224), Edit, PlayLock nil, runner lock nil.
- Studio == HEAD before (bytes, Adler-32): Server 211034 0f244a65, Island 25780 8f265def, Species 3909 079bd746, Text
  36792 d3cafe78, CandyLayout 5295 4e626a0a, CandyBuilder 17351 4e900109, CandyBuilder_Test 14179 4996c70f,
  CandyLayout_Test 8578 6fb48347, Species_Test 3917 22b8eb62, Island_Test 32142 6af14620, PraderaSites 6227 144c1889;
  CandyNests absent.
- Runner: a mini fresh loader (loadstring + setfenv, every Wildbound require a fresh load of the original's Source,
  SPECS copied from `tools/studio-fresh-runner.luau` for every suite reading a touched script, plus CandyBuilder_Test),
  held in a temporary ServerStorage StringValue, destroyed after.
- RED (tests deployed, `WildboundCandyNests` an empty stub, old Layout/Builder): CandyNests 1/8 (every new case "attempt to
  call a nil value"; the wave-refill pin passes on the existing Island.waveRefill), CandyLayout 13/1 (`NESTS_ENABLED`
  nil). CandyBuilder_Test 13/0 (its nest case reads the layout flag, so it only turns with the layout; the builder's RED
  is the CandyNests sync case).
- GREEN: CandyNests 9/0, CandyLayout 14/0, CandyBuilder 13/0. Regression, 45 suites: 690 passed, 7 failed, all known
  pre-existing (AN-3, BZ7, ECO-20, EL12, HB-T3, W1, RW5).
- Studio == repo after the writes: Server 212254 ff46e7ff, Island 25987 c0a2a53c, Species 5336 17f59604, Text 37074
  c8cd5ca1, CandyLayout 5552 740bc39c, CandyBuilder 18623 6712aaaf, CandyBuilder_Test 14360 a34702b2, CandyLayout_Test
  8918 785fef85, CandyNests 6445 7c8c4b60 (new), CandyNests_Test 10931 3ba8a274 (new).
- Builder: `Builder.syncNests(workspace.Candy_Bioma_v1)` changed 11 nests (L1 stays false), root `NestsEnabled` true;
  `CandyNests.read` gives C1 at (452, -21), bowl top 2.70.
- Solo Play (PlayLock CE1, removed after; Play stopped): IslandCount 17 (6 forest + 11 Caramelo); 11 eggs, C1-C5
  Gomibu Comun, R1-R4 Tortidragon Rara, E1-E2 Flanfuria Epica, each centred at y 3.90 (in the bowl). HeistProbe steal
  at CandyR1 (the real trigger, the hold stood in): Egg:26 Carried, `WildboundEggCarried` with `EggRarity=Rara`, the
  nest emptied, its meter Alert with no chase. Moved to the own base (Base1): banked and incubating,
  `WildboundEggReward = 1|Tortidragon|Rara|16|0|1|...`, an orange egg on the cradle. No Wildbound script error (only
  the usual TexturePack, asset and DataStore messages). Screenshots
  `assets/exports/forest-kit/captures/ce1-caramelo-egg-stolen-desktop.jpg`, `ce1-caramelo-egg-banked-desktop.jpg`.
- Python: 1195 tests, 1 failure = the known `test_lumipol_v2` V1IsKept.
- Commit f2e0c77.
- Not tested: the steal through a real held prompt (the Studio client cannot fire it, as in CF2); the 300 s wave refill
  of a Caramelo nest in Play (pure core pinned by a case); an Arrullo on an Épica Caramelo egg in Play; a guardian
  actually chasing a thief at its bound nest in Play; the hatch result (a primitive stand-in until CE2); two players,
  phone.

### Evidence CE2

- Studio target: place 122652861404212 (universe 10774749224), instance ba5a21af, Edit, PlayLock nil, runner lock nil.
- Studio == HEAD before (bytes, Adler-32): Toolbar 18156 3445d012, Toolbar_Test 21536 434f288d, Species 5336 17f59604,
  Species_Test 3917 22b8eb62, State 53376 ec12c43e, State_Test 84403 7c682fde, Server 212254 ff46e7ff, Text 37074
  c8cd5ca1; CandyPets and its suite absent.
- Uploads (user-approved, one each): Gomibú 130041727906990, Flanfuria 106158128076232, Tortidragón 85016154045779
  (receipts in `assets/exports/caramelo/upload-receipts.md`).
- Runner: a trimmed copy of `tools/studio-fresh-runner.luau` (engine unchanged, the SPECS of every suite reading a
  touched script, a name set instead of FILTER) in a temporary ServerStorage ModuleScript, destroyed after.
- RED (tests deployed, `WildboundCandyPets` an empty stub, sources unchanged): CandyPets 0/8, CreatureToolbar 17/3
  (CT-18 icon, CT-19 rig, CT-20 FarmWalking).
- GREEN: CandyPets 8/0, CreatureToolbar 20/0. Regression, 44 suites: 629 passed, 21 failed, all known pre-existing:
  AN-3, BZ7, ECO-20, EL12, HB-T3, W1, RW5 and the 14 State_Test EconomyConfig drift cases (PF4).
- Studio == repo after the writes: Toolbar 19587 fe8da42d, Toolbar_Test 25972 a7cbaac8, Species 5860 44144708, State
  53911 c4087c0b, Server 213398 873a6713, Text 37237 896f92f9, CandyPets 6013 7e0ceeac (new), CandyPets_Test 11950
  9e1015f6 (new).
- Solo Play (PlayLock CE2, removed after; Play stopped): HeistProbe steal at CandyC1, carried to Base1: banked,
  `WildboundEggReward = 1|Gomibu|Comun|10|0|1|...`; 15 s later a hotbar tool "Gomibú" (TextureId
  rbxassetid://130041727906990, uid wb:2), not equipped. The client equipped and activated it on the own pad: a
  `WildboundFarmCreature` in Base1, species Gomibu, passive, pivot on the pad top (0.00), 3.45 studs tall (bounding box),
  no light, pickup prompt; it wandered 12 studs in 4 s; the server's Animator played FarmIdle 135673668651279 (3.00 s
  clip), seen playing on the client too. No Wildbound script error. Screenshot
  `assets/exports/forest-kit/captures/ce2-gomibu-farm-pet-desktop.jpg`.
- Icons do not load yet: the client log says "Requester does not have permission for Asset" for the three new icons and
  for the Lumipol icon (PF7): user-owned images cannot be used by the group experience. Owner action below.
- Python: 1195 tests, 1 failure = the known `test_lumipol_v2` V1IsKept. `test_studio_fresh_runner` 15/15,
  `test_deploy_manifest` 25/25.
- Commits 551f56e (code, tests, icons, screenshot) and 4aa1eab (this record).
- Not tested: Flanfuria and Tortidragón farm models in Play (only in the suite), the walk clip switching in Play, the hotbar
  showing the image (blocked by asset permission), the `FarmOnly` refusal through the Bag's equip remote in Play, two
  players, phone.

### Evidence CE3

- Studio target: place 122652861404212 (universe 10774749224), instance ba5a21af, Edit, PlayLock nil, runner lock nil.
- Studio == HEAD before (bytes, Adler-32): Server 213398 873a6713, Beasts 47165 58801d54, Text 37237 896f92f9,
  CandyLayout 5552 740bc39c, CandyBuilder 18623 6712aaaf, CandyLayout_Test 8918 785fef85, CandyBuilder_Test 14360
  a34702b2, Text_Test 22740 e4550fde; Portal, PortalService, PortalClient absent.
- Runner: a mini loader (fresh clones in a temporary ServerStorage folder, destroyed after) for the five touched suites,
  and the engine of `tools/studio-fresh-runner.luau` pasted with the 44 suites that read a touched script.
- RED (tests deployed, `WildboundPortal` / `WildboundPortalService` as `return {}` stubs, old Text/Layout/Builder):
  Portal 1/9 (only the purity pin passed), PortalService 0/13, CandyLayout 13/1, CandyBuilder 12/2, Text 20/1.
- GREEN: Portal 10/0, PortalService 13/0 (after fixing two test-side mistakes: a nil override that `pairs` skipped, and a
  beast stamp that still counts for 1 s), CandyLayout 14/0, CandyBuilder 14/0, Text 21/0. Two later RED/GREEN rounds from
  the Play check: the Studio PortalProbe (SV-13 RED 12/1, GREEN 13/0) and the regeneration dips (SV-5b and PT-1 RED, then
  Portal 10/0, PortalService 14/0).
- Regression, 44 suites: 681 passed, 7 failed, all known pre-existing (AN-3, BZ7, ECO-20, EL12, HB-T3, W1, RW5).
- Studio == repo after the writes: Server 214269 828f8dcc, Beasts 47753 cd99de9f, Text 38180 bccdbfd7, CandyLayout 5659
  27e0e9d6, CandyBuilder 19220 0b2b7640, CandyLayout_Test 8961 21b2fd46, CandyBuilder_Test 15040 05b5e4c1, Text_Test 23755
  4d6e4a54, Portal 6851 e4faff01 (new), PortalService 15773 bb427b8f (new), PortalClient 4384 decfbd25 (new), Portal_Test
  10677 8bc43ebd (new), PortalService_Test 13512 32d01db7 (new).
- Builder: `Builder.syncPortal(workspace.Candy_Bioma_v1)` changed 1 (Portal `Enabled` true); session-only, no save.
- Solo Play (PlayLock CE3, cleared after; Play stopped both times): the forest arch built at (-28, 1.2, -132), the Caramelo
  prompt "Portal del Caramelo", `PortalEvent` and `PortalProbe` present. HeistProbe steal at CandyR2 (Rara, carried),
  moved to the Caramelo arch, probe trigger accepted (Safe); 2 s later the root stood 0.10 studs from the own Base1 pad
  target, the egg banked (`WildboundEggReward = 1|Tortidragon|Rara|16|...`), 24.5 s of rest left. At the forest arch
  during the rest: bosque Cooldown, caramelo TooFar. A Scuttler and La Silueta came; a trigger while defeated was refused
  Dead; later at the forest arch with La Silueta Near: Threat. Back at the Caramelo arch every trigger was refused Threat:
  the health regeneration dipped 36 -> 35 each second (fixed with `hurtMin`, decision 35). Second Play: steal at CandyR3,
  trigger at the Caramelo arch, stepped 7 studs at 0.6 s: cut, still there 2.2 s later, no rest, egg still carried;
  trigger again: bar "Volviendo a tu base..." on screen, landed 0.10 studs from the Base1 target, egg banked, both prompts
  read "Listo en 18 s" on the client, bar hidden. No Wildbound script error (only the usual TexturePack, asset fork and
  DataStore messages). Screenshots `assets/exports/forest-kit/captures/ce3-forest-portal-arch-desktop.jpg`,
  `ce3-caramelo-portal-channel-desktop.jpg`, `ce3-portal-arrived-own-base-desktop.jpg`.
- Python: 1195 tests, 1 failure = the known `test_lumipol_v2` V1IsKept. `test_studio_fresh_runner` 15/15,
  `test_deploy_manifest` 25/25.
- Commit e10e8f1 (code, tests, screenshots).
- Not tested: a real held prompt (the probe stands in, same trigger); a full channel at the forest arch (La Silueta was
  always Near there; only its refusals were seen); a cut by a beast hit or an awake parent in Play (suite only); two
  players, phone (the bar is capped at 360 px and 70 % width but was not seen on a phone); why the health sat at 35 after
  a Silueta defeat (pre-existing, not a portal matter).

## Next step

- Owner action for the icons (CE2): in the Creator Hub open each image (130041727906990, 106158128076232, 85016154045779
  and the Lumipol 121561289565386) and share it with the experience / group 465694015, or upload the four PNGs from
  `assets/icons/` to the group and give the ids to the assistant, who swaps them in `Toolbar.ICONS` and reruns CT-17/CT-18.


- CA5 close: a two-client lighting check (one in the Bosque,
  one in Caramelo at once) and a 15-minute / three-wave stay in Caramelo; enable the Caramelo nests through the builder when the
  user wants Caramelo eggs.
- Owner action for CA2 and CA3 clips (unchanged): publish them to group 465694015 (or grant the Assistant group upload or the
  `asset-permissions:write` scope), then fill Tortidragon and Don Glaseon `Clips.IDS` and rerun both Clips suites and a Play check.

# Wildbound integration plan (W17 preparation)

**Status: plan only. Nothing here was uploaded, imported, placed or played.** Written 2026-11-07 overnight without Studio, Blender or uploads. Every upload still needs the user's explicit approval (`odd/tasks/wildbound-waves.md:20-22`); this document only prepares that decision.

## Quick path

| You are | Read | Then |
| --- | --- | --- |
| The user | Section 6, then the batch summary in section 1 | Answer U1. One yes unlocks batch 1 only |
| Studio writer, after U1 | Sections 2 and 3 in order | Probe first. Stop on the first failed check |
| Planner of later biomes | Sections 4 and 5 | Measure Fog Forest on a phone before any biome import |

**Labels.** "Verified" rows cite file and line. Everything marked **Proposal** is a design choice made tonight and can be changed. Source line numbers were read at commit `6629b3a`; `src/` and `tests/` are being edited by another writer, so re-find code by symbol name before editing.

## 0. What tonight's real imports taught (verified)

| Lesson | Evidence |
| --- | --- |
| Kit FBX (`FBX_SCALE_ALL`) arrived at 1 Blender unit = 1 stud; bounds matched the report within 0.0002 studs after `PivotTo(CFrame.identity)` | `odd/tasks/fog-forest-visual-kit.md:63` |
| Frame is Blender `(x, y, z)` to Studio `(-x, z, y)`, a proper rotation, for the kit and for Silueta | `fog-forest-visual-kit.md:63`; `docs/assets/silueta-studio-import.md:39` |
| Every imported MeshPart arrives default gray and unanchored. Colors, SmoothPlastic, anchoring, `CanCollide`/`CanTouch`/`CanQuery` false and Box fidelity were repaired on templates | `fog-forest-visual-kit.md:64`; `silueta-studio-import.md:26-27` |
| Neon `F08C2E` rendered saturated yellow; the lantern template uses RGB 205, 92, 18 | `fog-forest-visual-kit.md:65`; `docs/ui/wildbound-world.md:21` |
| Repairing a package copy raises a Studio modal; "Aceptar" keeps local repairs and disables auto-update until publish or revert. A reinsert or package update restores the unrepaired asset | `fog-forest-visual-kit.md:66`; `silueta-studio-import.md:54` |
| A minimized Studio or an open modal gives blank white captures | `fog-forest-visual-kit.md:67` |
| `PackageLink.AutoUpdate` cannot be read from MCP (`lacking capability RobloxScript`) | `silueta-studio-import.md:56` |
| Only `FK_Evergreen_Trunk` and `FK_DeadTree_Wood` have `CanQuery` on, with `PreciseConvexDecomposition` set on the template; a reinserted template loses it | `docs/maps/wildbound-p0.md:29-30` |
| The dress step removes `PackageLink` from clones and places with `PivotTo` | `docs/maps/wildbound-p0.md:25`, `:32` |
| A two-material mesh lost one material on import | `silueta-studio-import.md:29` |
| Model upload creates no animation; clips were separate Animation assets | `silueta-studio-import.md:60`; `docs/testing/silueta-animation-assets.md:3` |
| Clip route that worked: Clip Editor Import From File Custom onto a disposable rig clone, a shared neutral-basis rotation fix, Save to File as `.rbxmx`, one Animation upload per clip | `docs/testing/silueta-native-idle.md:14`; `silueta-animation-assets.md:3`, `:16`, `:41` |
| Upload folders must be approved in Studio MCP permissions | `fog-forest-visual-kit.md:58`; `silueta-studio-import.md:14` |

**Correction to tonight's brief, with evidence.** The brief says Silueta arrived at the wrong scale "through a different FBX unit setting". The record says Silueta also used `FBX_SCALE_UNITS` (`docs/assets/silueta-rig.md:63`), the same setting as the species, guardian and Lumipol v2 rigs (`assets/blender/species/species-report.json:9`, `guardians/guardian-report.json:9`, `lumipol-roblox-v2/lumipol-roblox-v2-report.json:9`). Silueta was authored 2.4 m tall (`silueta-rig.md:57`) and arrived 2.4 studs (`silueta-studio-import.md:23`): the unit mapping was 1 to 1 and the authored height was wrong. The new rigs are authored at stud size, so they should arrive right. **That is an inference.** All rig reports still say `roblox_scale_verified: false` (`species-report.json:16`), which is why section 2 tests one rig first.

## 1. Upload manifest

### Open Cloud limits that apply (as stated by the `open_cloud_invoke` tool, read 2026-11-07)

| Limit | Value |
| --- | --- |
| Uploadable formats | bmp, fbx, flac, glb, gltf, jpeg, jpg, mov, mp3, mp4, ogg, png, rbxm, rbxmx, tga, wav |
| Files per request | Up to 5 files of 20 MB each |
| Location | Files must be in a directory the creator approved in Assistant Settings, MCP Permissions |
| Result | An operation; poll `GET /assets/v1/operations/{operationId}` until `done` |

From the docs as recorded earlier, not from the tool: Animation assets take RBXM/RBXMX, one asset per create (`silueta-animation-assets.md:41`). So **every clip FBX below is a source file, not an upload file**: it must first become a native `.rbxmx` KeyframeSequence in Studio. The largest file in this manifest is 451,772 bytes, well under 20 MB.

### Batch summary

Counts are permanent assets: one Model per model upload and one Animation per clip. A model upload may also create mesh content; the forest-kit manifest records one asset ID per upload (`assets/exports/forest-kit/forest-kit-upload-manifest.json:7-43`), so mesh content is not counted here.

| Batch | Contents | Models | Animations | Permanent assets | Needs before upload |
| --- | --- | ---: | ---: | ---: | --- |
| 1 | Lumipol v2, Silueta Search_v1, camp kit | 7 | 3 | **10** | U1 |
| 2 | Eleven new species | 11 | 22 | **33** | U1 later; X3 order |
| 3 | Yeti, El Vigia | 2 | 11 | **13** | Guardian code and X4 IP check |
| 4a | Living Forest kit | 7 | 0 | **7** | Fog Forest phone result (section 4) |
| 4b | Frozen Mountains, Rock and Caves, Volcanic Lands, Cryptic Ruins, Demon Abyss kits | 34 | 0 | **34** | M6 persistence and X2 rule |
| **All** | | **61** | **36** | **97** | |

**Priority.** P1 is batch 1. P2 is batch 4a plus the first four species in X3 order (Soplillo, Cortezon, Cestillo, Zancanieve), because 4a gates the place decision. P3 is everything else.

### Batch 1: what the playable Fog Forest needs next (P1, wave W17a)

| File | Bytes | Asset type | Purpose |
| --- | ---: | --- | --- |
| `assets/exports/species/SP_Lumipol_v2.fbx` | 109,244 | Model | Replaces the primitive wild Lumipol (section 3.2). Also the rig probe |
| `assets/exports/species/SP_Lumipol_v2_Idle.fbx` | 224,332 | Animation clip source, 3.0 s loop | Wild Lumipol idle. Upload file is a future `.rbxmx` |
| `assets/exports/species/SP_Lumipol_v2_Move.fbx` | 207,532 | Animation clip source, 2.0 s loop | Wild Lumipol wander. Upload file is a future `.rbxmx` |
| `assets/exports/silueta-horror-rig-v3-search-v1.fbx` | 441,420 | Animation clip source, 2.4 s loop | Silueta search pose, roadmap M2.4. Upload file is a future `.rbxmx`; no native export exists yet |
| `assets/exports/camp-kit/CP_Campfire.fbx` | 31,244 | Model | Camp fire. Also the kit probe (three parts, one Neon) |
| `assets/exports/camp-kit/CP_CampShelter.fbx` | 31,436 | Model | Camp dressing; no stand-in today |
| `assets/exports/camp-kit/CP_HatchAltar.fbx` | 29,340 | Model | At `HatchMarker` |
| `assets/exports/camp-kit/CP_ExtractionMarker.fbx` | 33,308 | Model | At `ExtractionMarker` |
| `assets/exports/camp-kit/CP_EggNest.fbx` | 41,308 | Model | Replaces the eight `NestStone` visuals |
| `assets/exports/camp-kit/CP_MarshShelter.fbx` | 47,612 | Model | Replaces `ShelterRoof` and four `ShelterPost` visuals |

Clip sources: `SP_Lumipol_Idle` 91 frames and `SP_Lumipol_Move` 61 frames at 30 fps (`lumipol-roblox-v2-report.json:133-153`); `SiluetaV3_Search_v1` 73 frames, 2.4 s, loop (`assets/blender/silueta-horror-rig-v3-search-v1-report.json:10-19`).

### Batch 2: species (P2 for the first four, P3 for the rest, wave W17c, roadmap M11)

Each species has one Model and two Animation clip sources, Idle 3.0 s and Move 2.0 s (`species-report.json`). Bytes are model / Idle / Move.

| Species | Model file | Bytes model / Idle / Move | Tris | MeshParts | Bones |
| --- | --- | --- | ---: | ---: | ---: |
| Soplillo | `assets/exports/species/SP_Soplillo.fbx` (+ `_Idle`, `_Move`) | 47,852 / 102,620 / 93,276 | 344 | 3 | 4 |
| Cortezon | `SP_Cortezon.fbx` | 75,868 / 160,012 / 148,444 | 556 | 4 | 7 |
| Cestillo | `SP_Cestillo.fbx` | 81,292 / 153,116 / 145,196 | 554 | 5 | 6 |
| Zancanieve | `SP_Zancanieve.fbx` | 91,980 / 205,660 / 190,940 | 626 | 4 | 10 |
| Polvilla | `SP_Polvilla.fbx` | 51,196 / 104,732 / 96,284 | 416 | 3 | 4 |
| Espejuelo | `SP_Espejuelo.fbx` | 46,892 / 99,516 / 92,092 | 316 | 3 | 4 |
| Aldabon | `SP_Aldabon.fbx` | 63,564 / 126,684 / 117,772 | 512 | 4 | 5 |
| Tinajuelo | `SP_Tinajuelo.fbx` | 65,772 / 129,180 / 118,700 | 470 | 4 | 5 |
| Tizoncillo | `SP_Tizoncillo.fbx` | 60,364 / 133,948 / 122,876 | 508 | 3 | 6 |
| Humarel | `SP_Humarel.fbx` | 77,788 / 172,652 / 156,220 | 504 | 4 | 8 |
| Vetilla | `SP_Vetilla.fbx` | 66,092 / 183,468 / 163,468 | 564 | 2 | 10 |

`SP_Tinajuelo_Neon_NightEye` is `default_hidden: true` in the report; the importer sets it transparent.

### Batch 3: guardians (P3, wave W17d)

| File | Bytes | Asset type | Purpose |
| --- | ---: | --- | --- |
| `assets/exports/guardians/GD_Yeti.fbx` | 176,044 | Model | Yeti, 1,330 tris, 5 MeshParts, 18 bones |
| `GD_Yeti_Idle.fbx` / `_Stalk` / `_Sniff` / `_Telegraph` / `_Charge` / `_Recover` | 375,452 / 345,340 / 366,892 / 333,884 / 321,900 / 342,972 | 6 clip sources: 3.0, 2.0, 3.0, 1.8, 1.0, 2.0 s | Yeti states |
| `assets/exports/guardians/GD_ElVigia.fbx` | 173,996 | Model | El Vigia, 1,256 tris, 6 MeshParts, 17 bones |
| `GD_ElVigia_Hold.fbx` / `_Stride` / `_Flinch` / `_Telegraph` / `_Strike` | 352,348 / 331,996 / 313,164 / 322,028 / 313,164 | 5 clip sources: 3.0, 2.0, 1.0, 1.8, 1.0 s | Vigia states |

Uploading guardians before their behavior code exists buys nothing: night scope, home and abilities are single-guardian today (`docs/design/wildbound-expansion-bible.md:37-39`).

### Batch 4: biome kits (4a P2, 4b P3)

All Models, `FBX_SCALE_ALL` like the forest kit (e.g. `assets/blender/camp-kit/camp-kit-report.json:9`). Directory `assets/exports/<biome>-kit/`.

| Kit | Files and bytes | Count |
| --- | --- | ---: |
| 4a Living Forest | LF_Broadleaf 31,676; LF_ResinStump 23,980; LF_FlowerClump 21,740; LF_StreamStone 20,988; LF_HollowArch 33,164; LF_TrailPost 25,692; LF_LogBridge 27,100 | 7 |
| 4b Frozen Mountains | FM_SnowPine 30,204; FM_IceSpire 23,580; FM_RockOverhang 28,124; FM_ScourShelf 18,604; FM_Cairn 21,372; FM_SnowMound 17,356; FM_IcePass 32,732 | 7 |
| 4b Rock and Caves | RC_CaveMouth 37,292; RC_TunnelStraight 28,972; RC_TunnelBend 29,692; RC_Stalagmite 18,204; RC_CrystalCluster 23,036; RC_OreVein 23,580; RC_Burrow 21,164 | 7 |
| 4b Volcanic Lands | VL_BasaltColumn 19,180; VL_Vent 23,244; VL_CoolStone 17,244; VL_CharredTree 24,652; VL_AshShrine 32,252; VL_CrustPlate 21,340; VL_ObsidianShard 21,484 | 7 |
| 4b Cryptic Ruins | CR_Colonnade 31,292; CR_BrokenWall 26,188; CR_Plinth 21,244; CR_Archway 31,628; CR_Reliquary 23,372; CR_GlyphStone 21,580; CR_StairRun 19,228 | 7 |
| 4b Demon Abyss | DA_FissureLip 24,380; DA_FloatRock 22,764; DA_ThornSpire 21,516; DA_RiftGate 30,876; DA_RiftShard 21,564; DA_CalmStone 22,172 | 6 |

### Not to upload

| File | Why |
| --- | --- |
| `assets/exports/silueta-horror-rig-v3-model.fbx` and the four Silueta clip FBX | Already uploaded: model `123768633946912`, clips `90427760879990`, `109004575414309`, `106571946482274`, `139759980248576` (`silueta-studio-import.md:9`; `silueta-animation-assets.md:9-12`) |
| `assets/exports/silueta-horror-rig-v3-native-{idle,locomotion,telegraph,attack}-v1.rbxmx` | Already uploaded as those four Animations |
| `assets/exports/silueta-horror-rig-v3-native-animation-staging-v1.rbxmx` (5,401,547 bytes) | Local staging backup |
| `assets/exports/silueta-horror-rig-v3.glb` | Optional duplicate of the uploaded rig |
| `assets/exports/forest-kit/*.fbx` | Already uploaded (`forest-kit-upload-manifest.json`) |
| `*.rbxl` under `assets/exports/` and the repo root | Place backups. Never staged, never uploaded |

## 2. Risk-first import procedure (proposal, built on section 0)

### 2.1 Preconditions

| # | Step |
| --- | --- |
| 1 | Verify the Studio instance and place (PlaceId `122652861404212`, GameId `10774749224`, Edit, creator `11937129310`) and get the user's confirmation of that target (`AGENTS.md`, safety) |
| 2 | Backup with File, Download a Copy into `assets/exports/`, record size and SHA-256, as in `fog-forest-visual-kit.md:60` |
| 3 | Confirm the folders `assets/exports/species`, `camp-kit` and `silueta` root are approved for MCP upload. If a file is rejected, ask; never move files to work around it |
| 4 | Create one manifest per batch in the forest-kit shape (`forest-kit-upload-manifest.json`): `sha256`, `operationId`, `assetId`, `moderationState` |
| 5 | One POST per asset. Write the POST response to the manifest before polling. No retry on an unknown outcome; reuse any ID that exists (`silueta-animation-assets.md:16`) |

### 2.2 Probe pair first: one kit prop and one rig

Upload only `CP_Campfire.fbx` and `SP_Lumipol_v2.fbx`. Insert each into `ServerStorage.WildboundAssets` (`CampKit` and `Species` folders). Run every check below. **If any check fails, stop all further uploads**, fix at the Blender source, re-export, and use the one corrected re-upload that U1 allows.

| ID | Check | Pass rule | Applies to |
| --- | --- | --- | --- |
| I1 | Part inventory | MeshPart names and count equal the report: Campfire 3, Lumipol 5 | Both |
| I2 | Scale | After `PivotTo(CFrame.identity)`, bounding box equals report `size` mapped `(x, y, z)` to `(x, z, y)` within 0.02 studs: Campfire 6.0 x 3.6 x 6.0, Lumipol 2.6 x 2.7 x 2.4. Exclude invisible helper parts (`silueta-studio-import.md:25`) | Both |
| I3 | Ground | Lowest visible point Y = 0 within 0.05 | Both |
| I4 | Axes and facing | Report `bbox_min`/`bbox_max` land on `(-x, z, y)`. For the rig, the `Neon_Eye` centroid has more negative Z than the body centroid (faces -Z) | Both |
| I5 | Color | Each part's Color equals the report `color_hex`. Read back numerically, then compare in one capture with the Blender render | Both |
| I6 | Neon | Neon parts read as intended in a capture at night and day. Expect the `F08C2E` shift; start from RGB 205, 92, 18 for that hex. For other Neon hexes record the value that reads right | Both |
| I7 | Skeleton | Bone count equals report `bones` (10). AnimationController present. No Humanoid, no scripts (the adapter rejects them, `src/wildbound/WildboundSiluetaVisual.luau:15-24`) | Rig |
| I8 | Skinning | Clone-only probe at Y = 1000: offset two Bone `Transform`s, see the mesh bend in a capture, destroy the clone, template stays neutral (`silueta-studio-import.md:43-50`) | Rig |
| I9 | Safety | Anchored true; `CanCollide`, `CanTouch`, `CanQuery` false; Box fidelity | Both |
| I10 | Package | Accept the local-modification modal for these copies only; no open modal during captures | Both |
| I11 | Clip | First clip only (Lumipol Idle): import, length 3.0 s within 1/30 s, no folded rig at frame 0 (the Silueta clips folded about 90 degrees until the neutral-basis fix, `silueta-native-idle.md:14`), foot `lowest_z` near 0 | Rig |

If I2 fails on the rig by a constant factor, record the factor and stop. Do **not** batch-apply `ScaleTo`: the adapter already scales Silueta by profile (`WildboundSiluetaVisual.luau:84-86`) and a second hidden factor would compound.

### 2.3 Repair script outline (proposal)

A future `tools/repair-imported-template.luau`, written test-first by the W17 writer. Input is a table generated from the report JSON by a small Python exporter in the style of `tools/export_forest_layout_luau.py`, so colors are never hand-typed.

```luau
-- spec[assetName] = { size = {x, y, z}, parts = { [partName] = { hex, neon, hidden, query } } }
repair(template, spec, overrides)
  assert template is a Model with no scripts or Humanoid
  template:PivotTo(CFrame.identity)
  check visible bounds vs spec.size mapped (x, z, y); abort on mismatch (no auto-rescale)
  for each MeshPart:
    entry = spec.parts[part.Name] or abort("unknown part")
    part.Color = overrides.neon[entry.hex] or Color3.fromHex(entry.hex)
    part.Material = entry.neon and Neon or SmoothPlastic
    part.Anchored, part.CanCollide, part.CanTouch = true, false, false
    part.CanQuery = entry.query == true             -- trunks only
    part.CollisionFidelity = entry.query and PreciseConvexDecomposition or Box
    if entry.hidden then part.Transparency = 1 end   -- e.g. Tinajuelo NightEye
  task.wait()   -- fidelity applies only after a yield (docs/maps/wildbound-p0.md:30)
  return readback table: name, color, material, flags, fidelity
```

`query = true` only for trunk parts: `FK_Evergreen_Trunk`, `FK_DeadTree_Wood` (live), and for later kits `LF_Broadleaf_Trunk`, `FM_SnowPine_Trunk`, `VL_CharredTree_Wood`, following bible section 1 row "Kit meshes are CanCollide..." (`wildbound-expansion-bible.md:34`). Occluder and collision boxes from the reports become plain invisible Parts built by the biome dress step, not by this script (`wildbound-expansion-bible.md:382`, `:387`).

### 2.4 Animation route for the three batch 1 clips

| Step | Action |
| --- | --- |
| 1 | Clone the repaired rig template to Y = 1000 |
| 2 | Clip Editor, Import, From File, Custom, pick the clip FBX (`silueta-native-idle.md:14`). This is a UI step; it needs a Studio writer with UI control or the user |
| 3 | Check frame zero. If the root is rotated, apply the neutral-basis fix: per Pose, keep translation, rotation becomes `Idle0.Rotation:Inverse() * Raw.Rotation`, with that rig's own Idle frame zero as the shared neutral |
| 4 | For Search_v1, compare against Blender deltas mapped by `(-x, z, y)` and 25/7 studs per meter, as for the other Silueta clips (`silueta-native-idle.md:20`) |
| 5 | Save the KeyframeSequence to file as `assets/exports/<group>/native/<clip>-v1.rbxmx`, record bytes and SHA-256 |
| 6 | Upload with `assetType` Animation, one POST per clip, then metadata GET (`silueta-animation-assets.md:14`) |
| 7 | Load through a server Animator in Play and check `Length` within one frame |

## 3. Placement in the Fog Forest

### 3.1 Camp kit over the primitive stand-ins (proposal)

**Test constraints (verified):** markers must stay within 25 studs of their zones and be non-colliding (`tests/WildboundP0Map_Test.luau:54-65`); every BasePart under `WildboundP0` anchored and inside plus or minus 200 studs (`:40-50`); at least eight `NestStone` within 12 studs of `EggMarker` (`:73-80`); decorations non-colliding (`:93-97`). The forest dress test wants exactly 4 `RuinPillar` with `CanQuery` and exactly 8 `NestStone` (`tests/WildboundForestDress_Test.luau:125-126`, `:139-140`). `NestStone` and the shelter parts keep the default `CanQuery` true from `part()` (`tools/build-wildbound-p0-map.luau:31-44`), so they take part in the nest sight lines.

**Rule:** do not edit `tools/build-wildbound-p0-map.luau` and do not delete stand-ins. A new `tools/dress-wildbound-camp.luau`, modelled on the forest dress module, makes each replaced stand-in invisible (`Transparency = 1`), keeps its name, CFrame, `CanQuery` and lights, and adds `Decorations.CampKit` with one clone per prop (`PackageLink` removed, placed with `PivotTo`). Markers, sight lines and both suites stay as they are. It needs its own test, `tests/WildboundCampDress_Test.luau`, with RED first; the forest dress suite builds only from the builder plus forest dress, so its `Decorations` child count (`:134`) is unaffected.

| Prop | Pivot (X, Y, Z), yaw | Stand-ins hidden (builder line) | Notes |
| --- | --- | --- | --- |
| CP_Campfire | (-140, 0.5, 140), 0 | `CampfireBase`, `CampfireGlow` (`:104-111`) | Glow part stays as an invisible light holder: PointLight 1.2 / 22 is kept |
| CP_ExtractionMarker | (-146, 0.5, 140), 0 | none | Marker `:96` |
| CP_HatchAltar | (-135, 0.5, 146), 0 | none | Marker `:97` |
| CP_CampShelter | (-152, 0.5, 152), 225 | none | Placement is new. Writer checks 7 studs from route centerlines and pivot rule (`docs/maps/wildbound-p0.md:31`) |
| CP_EggNest | (35, 0.5, -99), 0 | 8 `NestStone` (`:117-122`) | 17 x 17 footprint covers the 9-stud stone ring. See decision U4 on the decorative eggs |
| CP_MarshShelter | (105, 0.5, 125), 0 | `ShelterRoof`, 4 `ShelterPost` (`:125-128`) | Its 18 x 12 footprint matches the 18 x 12 roof, X along X |

Kept as they are: `ClearingBeacon` (`:112`), 4 `RuinPillar` (`:114-116`, they carry the nest sight plan), `MarshPool` (`:123`). Ground top is Y = 0.5 (`docs/maps/wildbound-p0.md:5`).

### 3.2 Lumipol v2 in place of the primitive Lumipol (proposal)

Today (verified): `visual(kind, position)` builds a `Body` ball plus `Eye` and `Ear` parts and a PointLight, with `Body` as PrimaryPart (`src/wildbound/WildboundServer.server.luau:182-199`). The prompt is parented to `Body` (`:377`), range checks read `entry.body.Position` (`:285`, `:293`), and wandering moves the whole model with `entry.model:PivotTo` (`:426`). `groundY` is the marker Y, 1.5 (`:209`), so `Body` sits at Y 3.5.

| Keep | Change |
| --- | --- |
| `Body` as PrimaryPart, prompt host and the only position the server reads | When a valid `ServerStorage.WildboundAssets.Species.SP_Lumipol` template exists, clone it into the model as `LumipolArt` with its feet at Y 0.5: pivot = `Body.CFrame * CFrame.new(0, -3, 0)`. Facing -Z matches `CFrame.lookAt` |
| Server-only creation; client sends nothing | Set `Body`, `Eye`, `Ear` `Transparency = 1` only after the art clone succeeds; otherwise the primitive stays (fallback, like the Silueta adapter) |
| PointLight on `Body` | Art parts: anchored, no collide, touch or query, so the prompt and sight checks are unaffected |
| Egg kind | Unchanged: no egg model in batch 1 |
| Movement code | Unchanged: `PivotTo` on the model carries the nested art |

Animation: with both IDs valid, create an Animator on the art clone, loop Idle and Move, and play Move when `brain.moved` is true. Treat missing or wrong-length tracks as static art. Contracts first, in the style of `docs/testing/silueta-visual-adapter.md:50`.

The equipped companion is a separate client-made ball (`src/wildbound/WildboundWorld.client.luau:190-198`) with a camera fade on `Body` only (`:263-268`). A client cannot see `ServerStorage`, so a v2 companion needs a template in `ReplicatedStorage` and a fade over every part. **Proposal: keep the companion primitive in W17a** (decision U3); the bloom finding is still open (`odd/tasks/wildbound-waves.md:62`).

### 3.3 Silueta Search_v1 in the visual adapter (proposal)

Verified today: the adapter requires exactly four actions and lengths (`WildboundSiluetaVisual.luau:5-7`), refuses all tracks if any of the four IDs is missing (`:100-102`), and chooses Idle or Locomotion in `step()` (`:205-208`). Seen and searching are both mode `Hunt` (`docs/wildbound-roadmap.md:170`); the server already tracks `lastVisibleAt` (`src/wildbound/WildboundWorld.server.luau:330`); search lasts 1.5 s (`src/wildbound/WildboundSiluetaAwareness.luau:8`).

| Point | Proposal |
| --- | --- |
| Template | Attribute `SearchAnimationId` on `SiluetaV3`, length 2.4 s, looped, Movement priority |
| Optional | Search is outside the required four. Missing or bad Search keeps the four tracks working; only Search is dropped |
| Input | New `Visual:setSearching(bool)`, called by World where it already reads the hunt state for `lastVisibleAt` |
| Choice in `step()` | Telegraph and Attack win as today. Else moving gives Locomotion. Else searching gives Search. Else Idle |
| Never | Search never reads camera or gaze (`wildbound-expansion-bible.md:42`) and never touches damage or timing |
| Risk | During a 1.5 s search Silueta mostly walks to the last seen spot (`docs/maps/wildbound-p0.md:44`), so Search may rarely show. Measure the stationary-search time in Play before changing any gameplay timing |

## 4. Place topology under the hybrid decision (X2)

X2 was taken as hybrid, to be re-decided after a phone measurement (`odd/tasks/wildbound-waves.md:42`; `wildbound-expansion-bible.md:549-562`). Verified inputs: streaming is on with Roblox default radii, min 64 and target 1024 (`docs/testing/wildbound-baseline-m1.md:41`); no real phone has run the game (`:135`); emulator profiles exist but say nothing about frame rate (`:105`, `:120`).

**Blocker found:** a real-phone measurement needs the place reachable from a phone, which means saving it to Roblox. Publishing needs explicit approval (`AGENTS.md`, safety). This is decision U2.

| Step | Measure on two real phones (one low-end Android, one iPhone) | Asset need |
| --- | --- | --- |
| P1 | Fog Forest as it is, after batch 1: frame rate (median and worst second) over the full loop walk at day and at night, and client memory from the Developer Console, three runs each | Batch 1 only |
| P2 | Same place with the Living Forest sector added as a separate root `Workspace.WildboundLivingForest` (never under `WildboundP0`, whose map test bounds it to plus or minus 200 studs) | Batch 4a |
| P3 | P2 again with `StreamingTargetRadius` lowered once, for example to 512 | None |

**Decision rule (proposal; the thresholds are hypotheses, since D15 final thresholds were not taken):**

| Result | Decision |
| --- | --- |
| P1 below 30 fps median on the low-end phone | Stop expansion. Optimize Fog Forest first: evergreens are 48,100 of its 74,996 triangles (`assets/maps/forest-layout/forest-layout-v1.json`, totals) |
| P1 passes, P2 passes with memory growth up to 25% over P1 | Hybrid as planned: Living Forest joins the start place |
| P1 passes, P2 fails, P3 passes | Hybrid with the lower radius |
| P1 passes, P2 and P3 fail | Living Forest becomes its own place, like the other biomes; wait for M6 |
| Any later biome | Separate place after M6 (teleports discard local data, `wildbound-expansion-bible.md:540`, `:557`), unless a repeat of P2 with that sector passes |

Code needed before P2, not in this plan's scope: a sector table instead of the single zone, home and fog rectangle (`wildbound-expansion-bible.md:38`, `:556`).

## 5. Budget

Triangles and MeshParts are calculated from measured Blender reports and layout plans. **No row has been measured on any device.** Fog Forest is built and dressed in Studio, so it is the baseline, but its cost on a phone is unknown.

| Area | Instances | Triangles | MeshParts | Extra boxes | Cap (bible section 2) | Source |
| --- | ---: | ---: | ---: | --- | --- | --- |
| Fog Forest, live (baseline, unmeasured on devices) | 207 | 74,996 | 512 | 16 PointLights | none | `wildbound-expansion-bible.md:25-26`; `docs/maps/wildbound-p0.md:28` |
| Camp kit, batch 1 | 6 | 2,456 | 22 | none | none | `camp-kit-report.json` |
| Living Forest | 162 | 32,696 | 340 | collision boxes in report | 180 / 40,000 | `assets/maps/living-forest-layout/living-forest-layout-v1.json` |
| Frozen Mountains | 148 | 30,016 | 312 | occluders, collision | 170 / 40,000 | `frozen-mountains-layout-v1.json` |
| Rock and Caves | 111 | 21,222 | 185 | 210 collision, 234 occluder | 130 / 28,000 | `rock-caves-layout-v1.json` |
| Volcanic Lands | 190 | 22,144 | 280 | occluders, collision | 210 / 30,000 | `volcanic-lands-layout-v1.json` |
| Cryptic Ruins | 102 | 21,544 | 196 | 94 occluder | 120 / 30,000 | `cryptic-ruins-layout-v1.json` |
| Demon Abyss | 106 | 16,912 | 182 | occluders, collision | 120 / 25,000 | `demon-abyss-layout-v1.json` |
| **Hybrid start place** (Fog + camp + Living) | **375** | **110,148** | **874** | | | Sum, calculated |
| All seven in one place, with camp | 1,032 | 221,986 | 2,029 | | | Sum, calculated |

Per-creature cost, one instance each: Lumipol v2 706 triangles and 5 MeshParts; Silueta 1,288 and 9; Yeti 1,330 and 5; El Vigia 1,256 and 6; species 316 to 626 and 2 to 5 (reports above). The hybrid start place is 1.47 times the triangles and 1.71 times the MeshParts of the unmeasured baseline.

## 6. Decisions for the user

| ID | Decision | Recommendation |
| --- | --- | --- |
| U1 | Approve batch 1 uploads: 7 Models and 3 Animations, 10 permanent assets, probe pair first, plus at most one corrected re-upload per probe asset that fails section 2.2 | **Yes.** Nothing else in this document is approved by it |
| U2 | Allow saving a private, unlisted version of the place to Roblox so it can be measured on real phones | Yes, private only, after batch 1, for step P1. It is publishing in the sense of `AGENTS.md` and needs its own yes |
| U3 | Use Lumipol v2 for the equipped companion now, or keep the primitive | Keep primitive in W17a; revisit after the bloom item closes |
| U4 | Keep the decorative eggs in `CP_EggNest`, or hide that part | Hide `CP_EggNest_Egg` until a playtest shows players do not mistake them for the real egg pickup |
| U5 | Move batch 4a (Living Forest kit) ahead of species | Yes, but only after P1; it gates X2 |
| U6 | Neon color rule | Accept per-color tuning recorded in the batch manifest, starting from the lantern precedent |

## 7. Limits of this document

- Not opened: any FBX, `.blend`, render or capture. Sizes come from the file system, all other numbers from the report JSON files.
- The Search_v1 `.rbxmx` size and the Lumipol `.rbxmx` sizes are unknown until exported.
- Roblox documentation was not re-read tonight; limits come from the `open_cloud_invoke` tool text and from records written on 2026-11-07.
- Whether a model upload also adds mesh assets to the inventory was not observed.
- The camp shelter position, every threshold in section 4 and all of sections 3.2 and 3.3 are proposals.

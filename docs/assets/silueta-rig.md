# Silueta horror rig v3 — source and exports ready

**Blender rig, four original animations and local export roundtrips pass. Roblox model import is done (`silueta-studio-import.md:9`); the first attempt was BLOCKED by the upload-directory permission allowlist until that folder was enabled.** The user approved permanent creation under User `11937129310` and `assets/exports`; that consent does not itself configure the tool permission. The first model-FBX upload was rejected before transfer because the folder was not yet approved in Assistant Settings → MCP Permissions, and it created no ID. A retry after approval succeeded. Reuse the recorded asset ID instead of uploading again.

## Deliverables

| File | Role |
| --- | --- |
| `assets/blender/silueta-horror-rig-v3.blend` | Editable isolated source: one owned scene, nine meshes, one armature, four actions, preview camera/lights |
| `assets/blender/silueta-horror-rig-v3-report.json` | Source geometry, weights, 226 evaluated frames, bounds, checksums and preservation evidence |
| `assets/blender/silueta-horror-rig-v3-roundtrip-full.json` | Separate-process GLB, model-FBX and all four FBX animation roundtrips |
| `assets/blender/silueta-horror-rig-v3-front.png` / `-back.png` | Neutral horror art previews |
| `assets/blender/silueta-horror-rig-v3-telegraph-qa.png` / `-attack-qa.png` / `-locomotion-qa.png` | Correctly evaluated final pose previews |
| `assets/exports/silueta-horror-rig-v3-model.fbx` | Preferred model/custom-skeleton import candidate, no baked action |
| `assets/exports/silueta-horror-rig-v3.glb` | Portable skinned model with all four named actions |
| `assets/exports/silueta-horror-rig-v3-{idle,locomotion,telegraph,attack}.fbx` | One baked in-place clip per file, with matching skeleton/mesh |

Earlier non-`-qa` Telegraph/Attack diagnostic renders are not the final pose evidence. V1/v2 assets remain unchanged; v2 SHA-256 still equals `3586DA8B9F3E1135ECB2BDEDDE31E2AF45C3E2ED351300AE03B4DB3CFC08E835`.

## Art and rig contract

The original v2 guardian was revised with a forward-hunched, gaunter trunk, longer hanging forearms, recessed empty facial spaces, smaller violet eyes, an uneven branch crown and irregular ragged foliage. Thin reliefs read as bark, not gore. No flashing, jumpscare effect, downloaded geometry or paid generator was used. The original authorized reference tone is retained; gaze-controlled Vigia behavior is not introduced.

| Property | Measured result |
| --- | --- |
| Blender / addon | 5.1.2 / 1.8 |
| Scene / rig | `Wildbound_Silueta_HorrorRig_v3` / `SiluetaV3_Rig` |
| Geometry | 1,288 triangles, 792 source vertices, nine semantic meshes |
| Largest source mesh | Branch crown, 248 triangles; all meshes well below the 20,000-triangle importer threshold |
| World-vertex dimensions | 1.687236 × 0.539326 × 2.400000 m |
| Source axes / origin | Z-up, face -Y; feet origin `(0, 0, 0)` |
| Materials | Four opaque Principled materials, shader-input colors; no texture atlas |
| Skeleton | 18 custom bones: Root, Pelvis, Spine, Chest, Neck, Head; UpperArm/Forearm/Hand and Thigh/Shin/Foot on each side |
| Weights | Every mesh vertex covered and normalized; maximum two influences; no non-finite/unknown/non-positive weights |
| Health | Zero non-manifold/boundary edges, loose vertices or degenerate faces; positive mesh volumes |
| Topology | Intentionally overlapping closed shells; torso/limbs blend at joints, rigid ornament shells follow appropriate bones |

The rig genuinely deforms the head, spine, arms and legs. Head/crown/eyes share Head; the neck fills the chest/head join; shoulder and ankle shells overlap. Representative neutral, gait, telegraph and strike poses were visually inspected for visible gaps. This is an initial low-poly custom rig, not certified production deformation topology or a mobile-performance result.

## Animation timing

| Original action | Source frames at 30 fps | Duration | Presentation contract |
| --- | --- | --- | --- |
| `SiluetaV3_Idle` | 1–91 | 3.0 s | Slow breathing/uneven head motion, matching loop endpoints |
| `SiluetaV3_Locomotion` | 1–61 | 2.0 s | In-place legs/arm counter-swing, matching loop endpoints |
| `SiluetaV3_Telegraph` | 1–43 | **1.4 s** | Draws arms wide, settles by halfway and holds a readable warning |
| `SiluetaV3_Attack` | 1–31 | 1.0 s | Starts at the exact warning endpoint, forward arm strike and recovery to neutral |

Root and armature stay fixed: there is no physical root lunge. Animation never authorizes damage. Runtime must map warning/strike timing to the existing server FSM without changing streaming safety, line-of-sight, range or current-character validation.

## Verification actually performed

- Pure motion contracts: observed six stub errors (RED), implemented profiles, then **6/6 GREEN**; reran after pose refinement. Runner: `D:/blender/5.1/python/bin/python.exe tools/test_silueta_motion_v3.py`. Ambient `python` was missing and `py` pointed to an inaccessible Store executable; the existing Blender-bundled interpreter worked without an install or permission change.
- Blender sampled **every frame** of all four actions: 226 evaluated frames, finite bone/vertex transforms, stationary Root, complete weights and actual deformed vertex motion. Idle and Locomotion endpoint mesh error was zero. Telegraph/Attack continuity is also checked by the pure profile contracts.
- Source library readback contains only the owned scene, 14 owned objects, one armature and all four actions. It excludes original Cube/Camera/Light and v2 objects. The `.blend` was written with an explicit owned scene/action set, not Save As of the user's current file.
- GLB binary/JSON inspection confirms nine meshes, one 18-joint skin, four named actions, four materials and no preview camera. GLB is 237,188 bytes; model FBX is 258,524 bytes; clips are 402,364–451,772 bytes. Every file is below 20 MB.
- Real imports in a **separate background factory-startup Blender** recovered the GLB, model FBX and all four clip FBXs: nine skinned meshes, 18 bones, 1,288 triangles, no unweighted vertices and a 2.4 m height. All imported clips had finite moving poses, fixed Root and correct durations. GLB names survive; FBX takes are identified by their filenames because Blender names the imported take after rig/scene. FBX reimport offsets the take by one frame but preserves duration.
- A first live-scene import check failed because the Blender glTF importer used the wrong context for an unlink and changed the window scene despite a scene override. Only test-created data was cleaned; original Scene/Cube selection was explicitly restored. All final roundtrips ran in the separate process. Final original file `""`, scene `Scene`, Object mode and active/selected `Cube` match the initial context. Existing objects' matrices, mesh vertices and data references were verified unchanged; no source file was overwritten.
- Python AST, unit tests, JSON readability, whitespace, file existence, sizes and hashes were checked. No Roblox import, AnimationID, gameplay playback or device/performance result is claimed.

## Export settings and remaining gate

FBX uses only the owned armature/meshes, `AddLeafBones=false`, explicit unit scaling (`FBX_SCALE_UNITS`), scale 1, export -Z forward/Y up. Model has no baked action; each clip bakes only its active action with simplification zero and no NLA/all-action mixing. GLB exports the selected owned model, skins and four named actions with Y-up conversion. Local roundtrip preserved dimensions; **actual Studio orientation/scale must still be checked**, not inferred from exporter labels.

The parent must ask the user to allow this exact directory in MCP Permissions:

`C:/Users/Jesus/Documents/ChatGPT/roblox-terror/assets/exports`

Then perform one supported upload/import and record the actual operation/asset IDs. A model upload does not automatically publish four Roblox AnimationIDs. Animation Editor or another supported explicit animation-import step may be required later. Preserve the server-owned Body proxy, disable collision/query for visual geometry and apply reveal to every visual descendant. Do not publish the game, change monetization, weaken permissions or bypass streaming protection.

## Reproduction and rollback

Reviewed owned scripts: `tools/build-silueta-rig-v3.py`, `tools/silueta_motion_v3.py`, `tools/test_silueta_motion_v3.py`, `tools/verify-export-silueta-rig-v3.py` and `tools/roundtrip-silueta-rig-v3.py`. The builder selectively reuses only the Mesh helper from the reviewed v2 builder and its original mesh data, not bundled third-party executables. Output guards reject existing versioned assets. For rollback, remove only the new v3 owned scene/data and files after checking for later work; retain v1/v2 and unrelated original objects. No commit was made because the parent delivery-chain choice remains pending.

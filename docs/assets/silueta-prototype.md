# Original Silueta static art prototype

**The editable Blender prototype is complete; Roblox export, upload and import are pending.**
This is a static visual sample, not a rigged or animated game-ready character.

## Files

| File | Purpose |
| --- | --- |
| `assets/blender/silueta-prototype-v2.blend` | Current isolated editable scene and collection |
| `assets/blender/silueta-prototype-v2-preview.png` | Current three-quarter front render |
| `assets/blender/silueta-prototype-v2-back.png` | Current three-quarter back render |
| `assets/blender/silueta-prototype-v2-report.json` | Measured geometry, topology and context-preservation evidence |
| `tools/build-silueta-asset.py` | Reviewed, original procedural construction source; refuses existing scene/output collisions |

The unversioned first `.blend`, preview, back render and report are retained as historical v1 outputs. Front/back inspection found a small ankle-to-foot gap; v2 overlaps the owned ankle rings with the closed foot shells. No existing user object or existing source file was overwritten.

## Art and provenance

The actual `resources/skill-packs/wildbound-codex-complete-v0.4.2/references/guardians/la_silueta_reference.png` was inspected alongside its reference README, `knowledge/wildbound/ART_DIRECTION.md` and `MONSTERS.md` in the same pack. The pack identifies the reference as a concept crop from its original generated boards, not a production mesh or UV texture.

The new mesh uses original authored geometry: an asymmetric branching crown, broad shoulders, a layered ragged foliage mantle, long forearms, root-like fingers and restrained violet eyes. Opaque desaturated bark/moss materials present the revealed form. Runtime must own the near-invisible state and reveal effect; embedded concept-board gaze behavior is explicitly **not** a Silueta requirement.

No external mesh, third-party executable, download, paid generator or asset library was used.

## Measured source specification

| Property | Observed result |
| --- | --- |
| Blender / addon | 5.1.2 / 1.8, native MCP protocol 15 |
| Scene / collection | `Wildbound_Silueta_Prototype` |
| Root | `Silueta_FeetOrigin`, `(0, 0, 0)`, ground between feet |
| Source axes | Z up; face/eyes forward **-Y** |
| Dimensions from actual world vertices | X 1.810705 m, Y 0.486729 m, Z 2.400000 m |
| World-vertex minimum | `(-0.905425, -0.275183, 0)` m |
| World-vertex maximum | `(0.905280, 0.211546, 2.400000)` m |
| Illustrative target height | 8.571428 studs using an explicit 0.28 m/stud assumption; import scale not verified |
| Source trunk center marker | `(0, 0.018804, 1.250470)` m; not the runtime gameplay root |
| Triangles / vertices | 984 / 616 across seven semantic mesh objects |
| Materials | Four opaque Principled BSDF materials; colors written to shader inputs |
| Closed shells | 62 disconnected shells; intentional overlap, not a welded deformation mesh |
| Health | 0 non-manifold edges, boundaries, loose vertices, degenerate faces or inward/zero-volume shells |
| UV | Editable per-face planar placeholders; no texture atlas, baked maps or production unwrap |
| Rig / animation / collision | None; retain the authoritative gameplay proxy separately |

Semantic mesh objects are `Silueta_Body`, `Silueta_Head`, `Silueta_Eyes`, `Silueta_ArmLeft`, `Silueta_ArmRight`, `Silueta_BranchCrown` and `Silueta_RaggedMantle`. All vertices are authored in one feet-origin coordinate system, with identity object transforms. The root parents them without changing their placement.

Normals were recalculated and each connected closed shell has positive signed volume. This does not certify absence of shell intersections: overlap is intentional. The provisional triangle target is an art constraint, **not** a measured mobile-performance guarantee.

## Verification and preservation

- Blender MCP `get_addon_status` and `get_scene_info` ran before modeling. The existing unsaved `Scene` held only `Cube`, `Camera` and `Light`, with `Cube` active and selected in Object mode.
- Creation used data-only APIs in a new scene/collection. Render camera, lights and world belong only to the asset scene. Source saving used `bpy.data.libraries.write({asset_scene})`, not Save As of the user's current file.
- Source-library readback confirmed only the asset scene, 12 owned objects and four owned materials; the original cube/camera/light are not in the delivered source.
- Original file identity, active scene, mode, selection, original object data/material references and transforms were checked unchanged. Front and back were visually inspected through MCP `look`; the corrected v2 front and back were inspected again.
- Local Python AST parsing and file existence/size/hash checks passed. These are source/visual checks, not Studio import, rig, gameplay, device or performance tests. No artificial TDD RED/GREEN result is claimed.

## Import gate and adapter requirements

No FBX/GLB was exported and no asset was uploaded. Before any export/upload, the parent must obtain the exact approved asset-upload folder and explicit consent for permanent asset creation under the verified creator identity. No Studio change, publishing or monetization is included.

After authorization, export **only** the seven mesh objects and their root, excluding preview camera/lights. Verify actual import size, source forward-axis conversion to the runtime's -Z facing, pivot and material appearance in Studio rather than assuming exporter conventions. Preserve the gameplay `Body` authority and colliders; attach art as non-colliding/non-query visual descendants. Reveal/transparency must affect every visual descendant, not only `Body` and `Head`. Align the feet origin to measured ground relative to the runtime proxy; do not substitute the source trunk-center marker for the authoritative root.

Still pending: approved export directory, authorized export/upload, real Studio import/scale/material check, runtime art attachment and reveal regression, mobile readability/performance, rigging and animation if subsequently requested.

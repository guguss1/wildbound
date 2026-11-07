# Silueta v3 — staged native rig

**One model upload succeeded. The native rig deforms in Studio; four animation assets and runtime integration remain pending.**

## Asset and target

- Approved creator: User `11937129310`; Studio user and place creator both verified.
- Studio `dfda4f65-05a7-459a-b38f-a054490feece`, place `122652861404212`, universe `10774749224`, Edit, private, streaming enabled.
- Model asset: **`123768633946912`**, revision 1, `Approved` / `Active`.
- Operation: `9a063a15-aa41-41a7-902f-ace1ddbbb9b5`.
- Staged package: **`game.ServerStorage.WildboundAssets.SiluetaV3`**.
- Complete request/response, file hash, insertion tag, repairs and final readback: [upload manifest](silueta-studio-upload-manifest.json).

The earlier upload-directory rejection occurred before transfer and produced no ID. After the user confirmed the exact folder was enabled, one retry of the original model FBX succeeded. The response was recorded before polling. No duplicate model, optional GLB, image or animation upload was attempted. Asset publication is the explicitly approved permanent asset creation, **not publication of the game**.

## Observed import and repairs

| Check | Observed result |
| --- | --- |
| Geometry | Nine MeshParts with all nine source semantic names; all nine mesh fetches `Success`; silhouette visibly matches source. Source has 1,288 triangles; exact native triangle count was not measured. |
| Skeleton | 18 actual Bone instances under `RootPart`, nine Motor6Ds, one AnimationController. No Animator or Animation instances. |
| Import helpers | Invisible RootPart and 84 `InitialPoses` CFrameValues. These values are **not playable animation clips**. |
| Scale | Imported visual height 2.399999976 studs; corrected using measured height and source 2.4 m / 0.28 = 8.571428571 studs. Final visual height 8.571427345 studs. |
| Template frame | Identity orientation; pivot approximately `(0, 0.0000002384, 0)`; visible feet at Y=0. Face points -Z. |
| Visual bounds | Min `(-2.822591305, 0, -1.332867503)`, max `(3.203250408, 8.571427345, 0.593285263)`. These exclude the invisible RootPart helper. |
| Safety | All ten BaseParts anchored; `CanCollide`, `CanTouch`, `CanQuery` false. All template Bone transforms neutral after probe. |
| Colors | All imported parts initially default gray; no TextureID or SurfaceAppearance maps. Restored used source plain colors through linear-to-sRGB conversion. No texture/image IDs were generated. |

The source has four material datablocks, but the actual GLB contains only **three used materials**: BarkShadow, DryBark and RecessedViolet. DeadFoliage is unused. The Head contains both BarkShadow and DryBark faces, but the FBX pipeline returned one Head MeshPart without a texture. The Head's BarkShadow base is restored; its DryBark socket accents are **not separately recovered**. BarkRidges uses DryBark and Eyes uses RecessedViolet; the other meshes use BarkShadow. Source eye emission strength 1.7 was not recreated by substituting an invented Neon material.

Expected quantized Roblox sRGB colors:

| Material | Source linear RGB | Restored RGB (0–255) |
| --- | --- | --- |
| BarkShadow | 0.013, 0.019, 0.022 | 30, 37, 40 |
| DryBark | 0.047, 0.057, 0.055 | 61, 67, 66 |
| RecessedViolet | 0.26, 0.032, 0.48 | 139, 50, 184 |

Orientation was checked against eyes projecting in front of the head and the unequal branch crown, not only the pivot. The upright front-facing mapping is source `(x,y,z)` → Studio `(-x,z,y)`: it is a proper rotation, not mirroring. The larger source-negative-X crown appears on Studio +X. Eyes-minus-head is approximately `(0.0012534, 0.0955858, -0.2276012)` studs.

## Actual visual/deformation probe

A temporary clone, light and backdrop were staged at Y=1000, away from gameplay. Captures:

- `SiluetaV3_Imported_Front_Loaded`: all nine meshes visible, dark bark/ridges/violet eyes, crown asymmetry and front orientation inspected.
- `SiluetaV3_NativeBone_Deformation`: clone-only Head and Forearm.L Transform offsets visibly rotated the crown/head/eyes and bent the left forearm/hand. Numeric transformed bone frames also changed.

The first capture raced mesh loading and showed only the backdrop; it is not visual evidence. After all nine fetches reported Success, the baseline and deformed captures were inspected. This proves an actual native skin deformation path, **not animation-track loading, four-clip playback or production deformation quality**.

The entire temporary probe was destroyed. The stored template remained neutral. No original map objects, lighting settings, gameplay scripts, Body authority, streaming protection or FSM were changed. Studio write ownership was explicitly released to the parent after final readback.

## Package and remaining gates

The package link remains intact. Scale, color and safety repairs affect this local copy only; a reinsert or package update can restore the uncorrected asset. No repaired asset version was published, and no unlink or package-update operation was performed.

Reading PackageLink.AutoUpdate failed exactly: `The current thread cannot read 'AutoUpdate' (lacking capability RobloxScript)`. This capability is not user-grantable through MCP; its state remains unknown and unchanged. No alternate context was used to bypass it.

Pending:

1. Import/publish four separate original animation clips through a supported authorized route and record actual AnimationIDs. Model upload did not create them.
2. Recover Head material accents/eye emission if required; this needs an explicit bounded art repair, not a claim of full material fidelity.
3. Parent-owned strict-TDD runtime adapter and server-created Animator/track playback, preserving Body authority, reveal-all-art behavior and streaming damage protection.
4. Actual gameplay, mobile, co-op and performance verification. No Play session or regression suite was run in this art-import unit.

No commits were made because the parent delivery-chain choice remains pending. Native review remains disabled/unmanaged. No game publication, monetization, permission changes, paid generation or shared-library edits.

## Current primary references

- [Modeling specifications](https://create.roblox.com/docs/art/modeling/specifications): current per-mesh 20,000-triangle limit checked before upload.
- [Assets API usage](https://create.roblox.com/docs/cloud/guides/usage-assets): model formats, operation polling, package behavior, and distinct Animation upload restrictions checked.
- [Bone API](https://create.roblox.com/docs/reference/engine/classes/Bone): Transform and TransformedWorldCFrame checked before the clone-only visual probe.

Follow the real `rbx-import-asset`, `rbx-open-cloud-usage` and `rbx-permissions` skills for future retries; reuse the existing asset ID instead of uploading blindly.

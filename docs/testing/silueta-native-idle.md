# Silueta v3 native animation verification

**PASS — four corrected clips imported, previewed, and staged locally.** No Roblox AnimationIDs were created, and gameplay playback was not tested. Verified in Roblox Studio Edit, place `122652861404212`, with streaming left enabled.

| Clip | Keys at 30 fps | Duration | Native editor result |
| --- | ---: | ---: | --- |
| Idle | 91 | 3.0 s | Upright, fixed root; opposite breathing poses at 0.73/2.23 s; neutral loop |
| Locomotion | 61 | 2.0 s | Upright, in-place gait; opposite leg poses at 0.5/1.5 s; neutral loop |
| Telegraph | 43 | 1.4 s | Neutral start, opens into a held windup at 0.7–1.4 s |
| Attack | 31 | 1.0 s | Starts in the windup, strikes at approximately 0.23 s, and recovers to neutral |

## What changed

Avatar → Clip Editor → Import → From File → Custom loaded the existing FBXs onto disposable rig clones. The uncorrected clips folded the rig toward the ground; native Idle's stored frame-zero Root rotation was approximately 90°. The corrected clips use a **single shared neutral pose**, the original native Idle at time zero. For each full `Pose` path, preserve the raw translation and replace the rotation with `Idle0.Rotation:Inverse() * Raw.Rotation`. The original Idle baseline reproduced every component of the staged Idle across its 91 keys exactly. Using Attack's own first frame as a baseline would erase the authored windup.

Each key has 18 skeletal paths plus the `RootPart` and `SiluetaV3_Rig` wrappers. The new clips were staged without changing the raw `Action` priority or `Loop=false` flag; looping in the editor/runtime is not inferred from matching endpoint poses.

## Measured fidelity

Blender 5.1.2 source poses were evaluated separately. Compared Studio `Bone.TransformedWorldCFrame` rotation deltas `R(t) R(0)^T` and position deltas with Blender deltas mapped by `A(x,y,z)=(-x,z,y)` and `25/7` studs per meter. The largest tested neutral joint mapping error was `0.000085` stud. Rotations were compared as matrices or signed axis-angle vectors, not local Euler angles.

- Idle live editor scrubs at 0.73/2.23 s versus Blender keys at 22/30 and 67/30 s: maximum angular error `0.008749°`, maximum joint displacement error `0.000197` stud (Root, Spine, Chest, Head). An independent exact-key application on the disposable rig at 22/30 and 67/30 s gave maxima `0.000006°` and `0.000132` stud. Root did not move.
- Exact staged keys also matched the source's signed motion for the sampled torso and limb bones: Locomotion at 0.5/1.5 s; Telegraph at 0.7/1.4 s; Attack at windup, strike key 7/30 s, and 0.4 s recovery. These samples are not a comparison of every source bone at every frame.

| Boundary | Maximum world angular / position difference across all 18 bones |
| --- | --- |
| Idle and Locomotion loop ends | `0° / 0` stud |
| Telegraph 0.7 s → 1.4 s | `0° / 0` stud |
| Telegraph end → Attack start | `0.00001429° / 0.000001494` stud |
| Attack end → Idle neutral | `0.00001778° / 0.000000962` stud |

## Recover the local staging

The four sequences remain in `ServerStorage.WildboundAnimationStaging`. An independent [local Roblox model backup](../../assets/exports/silueta-horror-rig-v3-native-animation-staging-v1.rbxmx) was saved through Explorer → Save / Export → Save to File. XML readback confirmed the folder contains exactly those four sequences, with 226 total keys and 20 poses per key. SHA-256: `76D26F1CDFE9181FC9247164B572130065DFEF96E43B36E75CCC9DBB6906DAD2`.

If the staging folder is missing, insert the model file under `ServerStorage`; do not import a second folder over existing staging. The preserved original native baseline is `ServerStorage.RBX_ANIMSAVES.WildboundSiluetaClipPreview.silueta-horror-rig-v3-idle_Wildbound_Silueta_HorrorRig_v3`. The temporary preview rigs and their owned animation saves were removed. No rig template, gameplay, package settings, or cloud place was changed.

**Next gate:** obtain explicit authorization for the four permanent animation assets, then verify their IDs, actual playback and timing in Play before wiring the visual adapter into a multiplayer test. No new runtime regression or mobile checks ran for this staging-only change.

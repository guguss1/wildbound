# Wildbound beast models

Stylized faceted low-poly models for the four Wildbound beasts: **Viper**, **Pouncer**, **Gargoyle**
and **Mire**. Each has a rig, a full set of gameplay animation clips timed to the game at 30 fps,
FBX exports for the Roblox 3D importer, rigless fallbacks, a collision proxy, preview renders and
6-frame contact sheets per clip. The build scripts in `src/` regenerate every file. The `.blend`
sources are not committed.

Nothing here has been imported into Roblox Studio yet. The import steps below are the intended
path and still need a Studio check.

## What changed in this pass

- **Animations:** every beast now has its complete gameplay clip set (25 clips in all), each its own
  action and its own FBX, timed to `docs/mechanics/wildbound-beasts.md` (Viper, Pouncer) or to the
  beast-pack specs (Gargoyle, Mire). Poses are written as key poses on a spline plus procedural
  overlays (breathing, wing beats, gait) and baked to one key per frame, so the motion is no longer
  linear blocking.
- **Ground contact:** a cheap per-frame correction keeps the contact parts on the ground: Viper's coil
  belly, Pouncer's eight feet (each leg's femur is solved so its claw tip touches Z = 0 while the
  body moves), Gargoyle's hands and feet, Mire's hands. Flight and underwater clips are exempt.
- **Painted detail:** the palette texture is now a 1024 × 256 atlas: the flat swatches on top, plus
  painted tiles below. Faces that use a detail entry get planar UVs inside a tile, so thin lines are
  painted *on* the face. Viper: magenta veins on about half of the upper body plates and on the
  skull, dark cracks on some risers (the old solid-magenta faces are gone). Pouncer: magenta veins on
  the abdomen and stripes down the legs. Gargoyle: dark cracks on the big torso, head, shoulder,
  arm, thigh and wing-cap stones.
- **Shape fixes:** Pouncer's fangs are larger and hooked (three curved segments instead of two
  straight ones). Gargoyle's wing panels are thicker (0.28 instead of 0.16), bow backwards between the
  spars and have scalloped trailing edges; the spars are thicker and the top edge is a chain of four
  stones that arches over the elbow. Mire's fingers end in blunt blocks with a squared knuckle
  instead of spikes, and the comb of moss spikes on the brow is replaced by a thick cap and three
  broad drapes, with two strands at the outer corners, clear of the eyes.
- **Checks:** `src/check_fbx.py` re-imports every FBX in a clean scene (see Checks).

## Files

| File | What it is |
| --- | --- |
| `<beast>.blend` | Blender 5.1 source: skinned mesh, armature, every action (fake user), collision proxy, hidden static copies |
| `<beast>.fbx` | Rigged FBX (armature + skinned mesh), rest pose, no animation |
| `<beast>_anim_<clip>.fbx` | Same rig and mesh with exactly one baked clip, for the Animation Editor's FBX animation import |
| `<beast>_static.fbx` | Rigless fallback in the rest pose |
| `gargoyle_statue_static.fbx`, `mire_submerged_static.fbx` | Rigless fallbacks frozen in the statue pose and the submerged pose |
| `<beast>_collision.fbx` | Simple collision proxy mesh |
| `textures/viper_palette.png`, `textures/pouncer_palette.png`, `gargoyle_palette.png`, `mire_palette.png` | Palette texture (also embedded in every FBX). Viper, Pouncer and Gargoyle: 1024 × 256 atlas with painted tiles. Mire: 48 × 8 flat strip. |
| `previews/*.png` | Preview renders, reference comparisons and contact sheets (see Previews) |
| `src/beastlib.py`, `src/build_viper.py`, `src/build_pouncer.py` | Viper and Pouncer builders |
| `src/beastkit.py`, `src/gargoyle_build.py`, `src/mire_build.py` | Gargoyle and Mire builders |
| `src/beastanim.py` | Shared animation helpers: pose maths, spline keys, baking, ground contact, foot planting, contact sheets |
| `src/beastatlas.py` | Shared palette atlas: painted crack/vein tiles and the planar UV pass |
| `src/compare_sheet.py` | Builds the four `*-vs-reference.png` sheets |
| `src/check_fbx.py` | Re-imports and checks every FBX |

Rebuild headless (each build takes 15–60 s; `-- --no-render` skips all renders, `-- --strips-only`
renders only the contact sheets):

```
blender -b --factory-startup -P assets/models/beasts/src/build_viper.py
blender -b --factory-startup -P assets/models/beasts/src/build_pouncer.py
blender -b --factory-startup --python assets/models/beasts/src/gargoyle_build.py
blender -b --factory-startup --python assets/models/beasts/src/mire_build.py
blender -b --factory-startup --python assets/models/beasts/src/compare_sheet.py
blender -b --factory-startup --python assets/models/beasts/src/check_fbx.py
```

Saving over an existing `.blend` makes a `.blend1` backup next to it; delete it after a rebuild.

## Animation clips

All clips are 30 fps and start at frame 1. Duration = (last − first) / 30. Looping clips have the
same pose on their first and last frame; set `Animation.Looped` (or `AnimationTrack.Looped`) in
Roblox. Every bone is keyed on every frame. On re-import the FBX take starts one frame later
(frame 2); the length is unchanged.

Clips are **in place**: the game moves the model (dash, leap arc, flight path, swim path). The only
root motion is small: the body leaning, the Viper's head staying on its lane while the body swings
behind it, Gargoyle's recoil push-back.

### Viper (`Viper_*`, file suffix in brackets)

| Clip | Frames | Duration | Loop | In-game timing | Content |
| --- | --- | --- | --- | --- | --- |
| `Viper_Idle` (`idle`) | 1–61 | 2.00 s | yes | idle | coil breathing: slow neck rise, jaw flex, faint ripple along the coil |
| `Viper_Slither` (`slither`) | 1–37 | 1.20 s | yes | approach / stalk | travelling wave around the coil, neck sways, head stays aimed |
| `Viper_Windup` (`windup`) | 1–36 | 1.17 s | no | windup 1.15 s | neck compresses into an S spring by frame 22 (the 0.7 s aim phase), then holds and rattles during the 0.45 s lock |
| `Viper_Dash` (`dash`) | 1–17 | 0.53 s | no | dash 0.53 s | explodes out in 3 frames, body unwinds into a trailing S, neck straight, jaw wide, fast ripple |
| `Viper_Crash` (`crash`) | 1–17 | 0.53 s | no | wall hit (first part of the 1.8 s recovery) | head snaps back, neck accordions, rebounds and slumps into a dazed pose |
| `Viper_Recover` (`recover`) | 1–39 | 1.27 s | no | recovery 1.25 s | dazed head shakes, the body re-coils into the rest pose |

After a wall: `Crash` + `Recover` = 1.80 s, matching the 1.8 s recovery. After a clean dash, play
`Recover` straight away with a short fade (about 0.15 s): it starts in the slumped pose that `Crash`
ends in, not in the dash pose.

### Pouncer (`Pouncer_*`)

| Clip | Frames | Duration | Loop | In-game timing | Content |
| --- | --- | --- | --- | --- | --- |
| `Pouncer_Idle` (`idle`) | 1–41 | 1.33 s | yes | idle | body bob with all feet planted, two fang twitches, one front-leg tap |
| `Pouncer_Stalk` (`stalk`) | 1–25 | 0.80 s | yes | approach / sidestep | in-place walk: two alternating groups of four legs, stance feet planted, body low and bobbing |
| `Pouncer_Windup` (`windup`) | 1–40 | 1.30 s | no | telegraph 1.3 s | body sinks while the feet stay planted (the knees rise), fangs spread, quiver, a final dip from frame 33 |
| `Pouncer_Leap` (`leap`) | 1–24 | 0.77 s | no | flight 0.75 s | push-off (feet leave the ground over frames 4–6), legs tucked frames 9–17, legs open and meet the ground on the last frame |
| `Pouncer_Land` (`land`) | 1–7 | 0.20 s | no | landing / hit | slams down into a wide splay, fangs snap shut |
| `Pouncer_Recover` (`recover`) | 1–31 | 1.00 s | no | rest after landing | shudder, two fang clicks, legs gather back to the rest pose |

`Land` + `Recover` = 1.20 s, matching the 1.2 s pause after landing. The flight is 0.767 s
(23 frames) against the game's 0.75 s: at 30 fps the choice is 22 or 23 frames.

### Gargoyle

| Clip | Frames | Duration | Loop | Spec state | Content |
| --- | --- | --- | --- | --- | --- |
| `Statue` (`statue`) | 1–30 | held | yes | inert statue | upright crouch, head lowered, wings folded back |
| `Awaken` (`awaken`) | 1–49 | 1.60 s | no | AWAKENING 1.6 s | three crack tremors (frames 4, 9, 13), head lifts, wings unfold and rise, roar at frame 36, settles awake |
| `Takeoff` (`takeoff`) | 1–40 | 1.30 s | no | TAKEOFF ~1.3 s | crouch with wings raised, push off on a big downstroke at frame 13, climbs on fast beats into the hover pose |
| `Hover` (`hover`) | 1–25 | 0.80 s | yes | TRACK/HOVER, RECOVER/HOVER | wingbeat with lagging wing segments, body bobs against the beat, legs trailing, tail sway |
| `CastTornado` (`cast`) | 1–61 | 2.00 s | no | TORNADO_CHARGE 1.65 s + release | frames 1–50: wings sweep forward and up, left arm raised, growing tremble; frames 50–54: thrust release (spawn the tornado around frame 52) |
| `Recoil` (`recoil`) | 1–16 | 0.50 s | no | hit / knock-back | knocked back 0.8 studs, wings flung back, back into the hover beat |
| `LandPetrify` (`land`) | 1–46 | 1.50 s | no | RETURN_TO_STONE | descends, touches down at frame 14, absorbs, folds the wings into the statue pose, settles |

`Takeoff` ends, `Hover` starts and ends, `Recoil` ends and `LandPetrify` starts on the same hover
pose. `Awaken` ends on the pose `Takeoff` starts from. The flight clips lift the rig 1.5 studs
(`HOVER_Z`) so the dangling feet stay clear of the pivot; the game still places the model at its
8–16-stud flight height. The crack *glow* of the awakening is VFX, not part of the mesh.

### Mire

| Clip | Frames | Duration | Loop | Spec state | Content |
| --- | --- | --- | --- | --- | --- |
| `Glide` (`glide`) | 1–49 | 1.60 s | yes | STALK_UNDERWATER | sunk 1.7 studs, slow surge bob, shell sway, eyes bobbing at the surface, limbs paddling below |
| `Emerge` (`emerge`) | 1–13 | 0.40 s | no | EMERGE (first part) | bursts up out of the water, head first, then the front limbs |
| `Swipe` (`swipe`) | 1–15 | 0.47 s | no | EMERGE (attack) | right front limb cocks back (frames 1–5), sweeps across (5–12, the 0.23 s active window), follows through |
| `Recover` (`recover`) | 1–40 | 1.30 s | no | SURFACE_RECOVER 1.1–1.6 s | slumps on the bank, two heavy breaths, shakes off the mud, stands up |
| `Sink` (`sink`) | 1–37 | 1.20 s | no | DIVE/REPOSITION 1.2 s | rocks back, folds the limbs, slides under into the glide pose |

`Emerge` + `Swipe` = 0.87 s, inside the spec's 0.65–0.9 s EMERGE window. Each clip ends on the pose
the next one starts from (Glide → Emerge → Swipe → Recover → Sink → Glide).

## Scale, pivot and orientation

- 1 Blender unit = 1 metre = **1 stud**. Scene unit scale is 1.0.
- Pivot: the world origin on the ground plane (Z = 0), where the `Root` bone sits.
- The creatures face **-Y** in Blender (Blender's "front" view).
- Viper and Pouncer FBX: `Apply Scalings: FBX All`, primary bone axis Y, secondary X. Gargoyle and
  Mire FBX: `FBX_SCALE_NONE`, forward -Z, up Y. All four re-import into Blender at scale 1.0 with
  the same sizes in metres (see Checks).

| | Bounding box X × Y × Z (studs) | Notes |
| --- | --- | --- |
| Viper (rest) | 7.5 × 10.3 × 7.4 | about 10 studs long; spine path about 22.7 studs |
| Pouncer (rest) | 8.9 × 7.1 × 4.4 | leg span 8.9 studs (about 4.5-stud leg radius) |
| Gargoyle (rest, wings open) | 13.8 × 7.7 × 8.2 | wingspan 13.8 (target 11–15) |
| Gargoyle (statue pose) | 5.2 × 8.3 × 7.7 | wings folded back along the body |
| Mire (rest) | 13.4 × 11.1 × 4.3 | the long forelimbs reach 13 studs across |
| Mire (submerged) | about 2.5 above Z = 0 | only the mossy back, the brow and the eyes show |

Pouncer's leg span matches the `02_POUNCER.md` wording (4–6-stud leg *radius*) but is wider than the
"4–6 studs wide leg span" line in `POUNCER_PROMPT_IA_MODELO_3D.txt`.

**Roblox import scale (not verified in Studio):** check the size in the 3D Importer preview. If the
importer reads a file as centimetres (100× too small), fix the unit setting or rescale the Model
once. If a creature faces backwards, rotate it 180° around Y.

## Triangle counts

| Mesh | Viper | Pouncer | Gargoyle | Mire |
| --- | --- | --- | --- | --- |
| Body (skinned) | 1,206 | 1,630 | 4,678 (eyes included) | 4,540 (eyes included) |
| Eyes (separate skinned mesh, emissive) | 12 | 120 | — | — |
| **Total render** | **1,218** | **1,750** | **4,678** | **4,540** |
| Before this pass | 1,218 | 1,694 | 3,782 | 3,016 |
| Collision proxy | 68 | 56 | 24 | 24 |
| Budget (ceiling) | 2k–8k | 2k–8k | 4k–10k | 2k–8k |

Viper's veins are texture only, so its count did not change. Pouncer +56 (curved fangs), Gargoyle
+896 (arched panels and the stone cap chain), Mire +1,524 (two knuckle and tip blocks per finger,
the new brow). All faces are flat shaded and triangulated, and normals were recalculated outward.

## Materials and textures

- **Body:** one palette material per creature, closest-pixel sampling. Every flat face has its UVs
  on one swatch; detail faces have planar UVs inside a painted tile (about 1.4–1.6 studs per tile,
  shrunk to fit large faces, with a random offset and rotation per facet). The body imports as one
  MeshPart with one small texture. Viper and Pouncer also keep a face-corner colour attribute
  (`Col`) with the flat colours.
- **Atlas layout** (Viper, Pouncer, Gargoyle): 1024 × 256; top 64 px = one flat swatch per palette
  entry; bottom 192 px = painted 192 × 192 tiles. Tiles: Viper — plate + magenta veins, mid plate +
  magenta veins, charcoal riser + dark cracks; Pouncer — dark plum + veins, violet + veins;
  Gargoyle — stone + dark cracks, dark stone + darker cracks. Mire keeps the 48 × 8 flat strip.
- **Eyes:** Viper and Pouncer: a separate emissive eye mesh. In Roblox set it to `Neon` with amber
  `#FF7A0A` (Viper) or magenta `#FF3FC0` (Pouncer). Gargoyle and Mire: the eye faces are part of the
  body mesh with a second emissive material (`*_EyeGlow`); a real glow in Roblox needs a
  `SurfaceAppearance` emissive mask or two small `Neon` parts. Which one is still open.
- Palettes (sRGB hex as authored): Viper charcoal purple `#3A2B46`, plate purple `#6A4A80` /
  `#584070`, violet crest `#80509F`, magenta `#B8408E`, beige `#CBB39C`, ivory `#EFE4CC`, mouth
  `#A02A62`, vein line `#C43C96`. Pouncer charcoal plum `#352A3F`, plum `#5E4568` / `#4A3854`, violet
  `#7B5288`, magenta `#A8407F`, lavender `#8F7F9E`, ivory `#E6D7C0`. Gargoyle stone `#9E94AD`, dark
  stone `#786E8C`, membrane `#80739C`, claw `#5E5773`, moss `#809924`, eye cyan `#4DFFEB`. Mire stone
  `#4A6663`, dark stone `#304547`, moss `#8C9E38`, dark moss `#597326`, fungus `#DED4A3`, eye amber
  `#FFC74D`.
- **Known colour quirk (unchanged from the first pass):** the Viper and Pouncer textures store the
  *linearised* palette values as pixels, so their PNG swatches are darker than the hex values above
  (for example `#3A2B46` is stored as about `#0B0610`). The renders and the look in Blender use these
  darker values. Gargoyle and Mire store the sRGB values. Decide whether to brighten Viper and
  Pouncer before the Studio import.

## Rigs

Bone names are unchanged from the first pass. All bones deform; `Root` sits at the origin.

- **Viper_Rig (15 bones):** `Root`; `Spine01`…`Spine12` from the tail tip (the chain root) to the
  top of the neck — `Spine01`–`Spine10` lie in the ground coil, `Spine11`–`Spine12` are the neck;
  `Head` (skull, crest, upper fangs, eyes) → `Jaw` (lower jaw, lower teeth, tongue). Body vertices
  blend linearly between neighbouring spine bones.
- **Pouncer_Rig (29 bones):** `Root` → `Body` (cephalothorax, face, rigid) → `Abdomen`,
  `Fang.L`/`Fang.R`, and `LegL1..4_{Femur,Tibia,Tarsus}` / `LegR1..4_*` (leg 1 is the front leg).
- **Gargoyle_Rig (20 bones):** `Root` → `Hips` → `Spine` → `Head` → `Jaw`; `Hips` → `Tail`,
  `Leg_{L,R}_Upper` → `_Lower`; `Spine` → `Arm_{L,R}_Upper` → `_Lower`, `Wing_{L,R}_1` → `_2` → `_3`.
  Every part is rigidly skinned to one bone.
- **Mire_Rig (15 bones):** `Root` → `Shell` → `Head`; `Shell` → `ArmF_{L,R}_1..3` and
  `ArmM_{L,R}_1..3`. The hind stubs and the tail are skinned to `Shell`. Rigid skinning.

The rigs are FK only. Ground contact is baked into the keys (see What changed), not driven by IK.

## Import into Roblox Studio (intended steps, not yet run)

1. Avatar tab → **Import 3D** → choose `<beast>.fbx`. Keep **Rig General** (custom rig, not R15),
   check the size in the preview, and import as a Model. The importer turns the armature into Bones
   under the MeshPart.
2. Keep the embedded palette texture, or set `TextureID` to the uploaded palette PNG. Set up the eye
   glow as described under Materials.
3. Import `<beast>_collision.fbx` as a separate MeshPart, set `Transparency = 1` and
   `CanCollide = true`, and turn off `CanCollide` and `CanQuery` on the visual parts.
4. For each clip, open the Animation Editor on the imported rig and use **Import → From FBX
   Animation** with `<beast>_anim_<clip>.fbx` (one clip per file; the take is named `Scene`). Mark the
   looping clips as looped.
5. Fallback: if the skinned import misbehaves, use `<beast>_static.fbx` (and the statue or submerged
   static) with CFrame or TweenService.

By design the meshes contain no gameplay VFX: Viper's red lane, Pouncer's red circle, the tornado,
ripples, bubbles, dust and crack glow are separate.

## Previews

- Stills (EEVEE, neutral set): `viper-{front,side,34,windup,attack-avatar-scale}.png`,
  `pouncer-{front,side,34,top,windup,attack-avatar-scale}.png`,
  `gargoyle-{front,side,three-quarter,attack,statue,scale-avatar}.png`,
  `mire-{front,side,three-quarter,attack,submerged,scale-avatar}.png`. The "attack" and "windup"
  stills now show frames of the new clips (Viper dash frame 10, windup frame 36; Pouncer windup
  frame 40, leap frame 12; Gargoyle cast frame 54; Mire swipe frame 5).
- `*-vs-reference.png` (all four): the reference render next to the model renders.
- Contact sheets `anim-<beast>-<clip>.png`: 6 evenly spaced frames of each clip in one strip
  (6 × 420 × 340 px). The orange bar under each frame shows where it sits in the clip. Mire's glide,
  emerge and sink sheets include an opaque water plane at Z = 0. 24 sheets: Viper 6, Pouncer 6,
  Gargoyle 6 (no sheet for the held statue), Mire 5.

These are Blender renders, not in-game or biome captures.

## Checks

`src/check_fbx.py` re-imports each of the 38 FBX files into a clean factory scene and checks:
one armature with the expected bone count and the same bone names as the creature's rigged FBX;
every skinned vertex fully weighted to bones of that rig; exactly one action in each
`*_anim_*.fbx` with the expected length; no armature, vertex groups or actions in static and
collision files; object scale 1.0 and the mesh size in studs. Last run: **38 / 38 OK**.

Each build also prints a per-clip ground report (lowest vertex overall and the contact range).
Contact parts stay at Z = 0 (within 0.03 studs, the jitter of the claw tips) on every grounded
frame. Known small dips of non-contact parts below Z = 0: Pouncer leap push-off 0.11; Gargoyle wing
tips during the takeoff and landing downstrokes 0.33 and 0.58; Mire's head and tusks at the swipe
hit 0.43 and the slumped belly in Recover 0.18; Viper's jaw 0.02.

## Final vs placeholder

| Item | Status |
| --- | --- |
| Silhouettes, proportions and palettes | Production pass; matches the reference sheets in shape language and colour zones. Not final art. |
| Surface detail | Painted thin veins/cracks on Viper, Pouncer and Gargoyle; Mire flat colour zones. |
| Gameplay clips | Complete set per beast, timed to the game; procedural, not hand-polished. |
| Rigs | Usable and simple, FK only; bone names unchanged. |
| Collision proxies | Final-ready simple shapes (the Gargoyle proxy ignores the wings on purpose) |
| Eye glow in Roblox (Gargoyle, Mire) | Open: emissive mask or Neon parts |
| Viper/Pouncer texture brightness | Open: linearised swatches (see Materials) |
| Roblox import, scale, orientation and clip playback | **Unverified.** Needs a Studio import check. |
| Biome capture and in-game performance | Not done |

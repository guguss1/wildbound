# Wildbound beast models

Stylized faceted low-poly models for the Wildbound beast pack. The first part covers **Viper** and
**Pouncer**; Gargoyle and Mire (`gargoyle*`, `mire*`, `src/gargoyle_build.py`, `src/mire_build.py`,
`src/beastkit.py`) are described in the "Gargoyle and Mire" section at the end. The `.blend` sources
are not committed; every build script regenerates them.

Nothing here has been imported into Roblox Studio yet. The import steps below are the intended
path and still need a Studio check.

## Files

| File | What it is |
| --- | --- |
| `viper.blend`, `pouncer.blend` | Blender 5.1 source: skinned body, eye mesh, armature, three pose actions, collision proxy, hidden static copy |
| `viper.fbx`, `pouncer.fbx` | Rigged FBX (armature + skinned body + skinned eyes), rest pose, no animation |
| `viper_anim_{idle,windup,attack}.fbx`, `pouncer_anim_{idle,windup,attack}.fbx` | Same rig with one baked action each, for the Animation Editor's FBX animation import |
| `viper_static.fbx`, `pouncer_static.fbx` | Rigless fallback: body + eyes merged into one mesh, rest pose |
| `viper_collision.fbx`, `pouncer_collision.fbx` | Simple collision proxy mesh |
| `textures/viper_palette.png`, `textures/pouncer_palette.png` | Flat colour palette strip (also embedded in the FBX files) |
| `previews/viper-*.png`, `previews/pouncer-*.png` | Preview renders (see below) |
| `src/beastlib.py`, `src/build_viper.py`, `src/build_pouncer.py`, `src/compare_sheet.py` | Procedural build scripts; they regenerate every file above |

Rebuild one creature headless:

```
blender -b --factory-startup -P assets/models/beasts/src/build_viper.py
blender -b --factory-startup -P assets/models/beasts/src/build_pouncer.py
blender -b --factory-startup -P assets/models/beasts/src/compare_sheet.py
```

## Scale, pivot and orientation

- 1 Blender unit = 1 metre = **1 stud**. Scene unit scale is 1.0.
- The FBX files use `Apply Scalings: FBX All`, so a re-import into Blender gives the same sizes in metres.
- Pivot: the world origin, on the ground plane (Z = 0), centred under the creature's footprint.
- The creatures face **-Y** in Blender (Blender's "front" view).

| | Bounding box (X × Y × Z, studs) | Notes |
| --- | --- | --- |
| Viper (rest) | 7.5 × 10.3 × 7.4 | about 10 studs long; head about 4 × 3 × 2.5 including the open jaw; spine path about 22.7 studs |
| Pouncer (rest) | 8.9 × 7.1 × 4.4 | body plus abdomen about 6 studs long; leg span 8.9 studs (about 4.5-stud leg radius) |

Pouncer's leg span matches the `02_POUNCER.md` wording (4–6-stud leg *radius*) but is wider than the
"4–6 studs wide leg span" line in `POUNCER_PROMPT_IA_MODELO_3D.txt`. Scale the model or the legs if you
want the narrower reading.

**Roblox import scale (not yet verified in Studio):** in the 3D Importer, check the reported size of the
model in the preview. Viper should come in at about 10 studs long and Pouncer at about 9 studs wide. If
the importer reads the file as centimetres (100× too small) or metres with a stud conversion, fix the
unit setting in the importer or rescale the Model once after import. If the creature faces backwards in
Roblox, rotate it 180° around Y.

## Triangle counts

| Mesh | Viper | Pouncer |
| --- | --- | --- |
| Body (skinned) | 1,206 | 1,574 |
| Eyes (skinned, emissive) | 12 | 120 |
| **Total render** | **1,218** | **1,694** |
| Collision proxy | 68 | 56 |

Both are below the 2k–8k art target, which is a budget ceiling, not a minimum. All faces are flat
shaded. Meshes are triangulated and their normals were recalculated outward.

## Materials

- **Body:** one material per creature (`Viper_Palette`, `Pouncer_Palette`). It uses the palette PNG with
  closest-pixel sampling. Each face's UVs point at a single swatch, so the body imports as one MeshPart
  with one small texture. The same colours are also stored as a face-corner colour attribute (`Col`).
- **Eyes:** a separate mesh with an emissive material. In Roblox, set the eye MeshPart's `Material` to
  `Neon` and its colour to amber `#FF7A0A` (Viper) or magenta `#FF3FC0` (Pouncer) to get the glow.
- Viper palette: charcoal purple `#3A2B46`, plate purple `#6A4A80` / `#584070`, violet crest `#80509F`,
  magenta accent `#B8408E`, beige jaw and belly `#CBB39C`, ivory fangs `#EFE4CC`, mouth `#A02A62`.
- Pouncer palette: charcoal plum `#352A3F`, plum `#5E4568` / `#4A3854`, violet `#7B5288`, magenta
  `#A8407F`, lavender `#8F7F9E`, ivory `#E6D7C0`.

## Rigs

All bones deform. Bone-axis export settings are primary Y and secondary X, with no leaf bones.

**Viper_Rig (15 bones)**

- `Root`: on the ground at the origin.
- `Spine01` … `Spine12`: one chain from the tail tip to the top of the neck. Body vertices blend linearly between neighbouring spine bones.
- `Head`: the parent of `Jaw`. It drives the skull, crest, upper fangs and eyes.
- `Jaw`: the hinge at the back of the mouth. It drives the lower jaw, lower teeth and tongue.

**Pouncer_Rig (29 bones)**

- `Root`: on the ground at the origin.
- `Body`: the cephalothorax and face, rigid.
- `Abdomen`: the child of `Body`.
- `Fang.L` / `Fang.R`: each one drives a chelicera with its big and small fang.
- `LegL1..4_Femur`, `_Tibia`, `_Tarsus` and `LegR1..4_*`: eight legs with three bones each, rigid per segment. Leg 1 is the front leg.

**Pose actions (both creatures), stored in the .blend and exported one per FBX:**

| Action | Frames | Viper | Pouncer |
| --- | --- | --- | --- |
| `*_Idle` | 1–60 / 1–40 | neck sway with a slight jaw flex, loops | body bob with a fang twitch, loops |
| `*_Windup` | 1–35 / 1–25 | neck coils back, head rears up, mouth opens | knees rise, body lowers, fangs open |
| `*_Attack` | 1–20 | lunge from the windup pose: neck extends, jaw opens wide | airborne tuck: legs fold under, fangs spread |

These are blocking poses with linear in-betweens, not polished animation. Viper's slither, dash,
crash and recovery are not done yet. Pouncer's landing splay, stalk and recovery are also not done.
The rigs are FK only, so Pouncer's feet are not locked to the ground: the windup pose keeps the feet
close to the ground by eye, not with IK.

## Import into Roblox Studio (intended steps, not yet run)

1. Avatar tab → **Import 3D** → choose `viper.fbx` or `pouncer.fbx`.
2. In the importer, keep **Rig General** (custom rig, not R15), check the size in the preview, and import as a Model. The importer turns the armature into Bones under the MeshPart.
3. Set the eye MeshPart to `Neon`. Keep the body MeshPart's texture (the embedded palette), or set `TextureID` to the uploaded `textures/*_palette.png`.
4. Import `*_collision.fbx` as a separate MeshPart, set `Transparency = 1` and `CanCollide = true`, and turn off `CanCollide` and `CanQuery` on the visual parts. As a cheaper alternative, use Box collision fidelity on the body.
5. For animation, open the Animation Editor on the imported rig and use **Import → From FBX Animation** with `*_anim_*.fbx`.
6. Fallback: if the skinned import misbehaves, import `*_static.fbx` (no rig) and animate it with CFrame or TweenService, or drive the gameplay with the static mesh plus VFX.

Gameplay telegraphs (Viper's red dash lane and Pouncer's red landing circle) are not part of the meshes,
by design.

## Previews

- `previews/viper-front.png`, `viper-side.png`, `viper-34.png`, `viper-windup.png`, `viper-attack-avatar-scale.png` (lunge pose next to a 2 × 1 × 5-stud avatar-height block)
- `previews/pouncer-front.png`, `pouncer-side.png`, `pouncer-34.png`, `pouncer-top.png`, `pouncer-windup.png`, `pouncer-attack-avatar-scale.png` (airborne tuck, lifted 2 studs for the shot, next to the 5-stud block)
- `previews/viper-vs-reference.png`, `pouncer-vs-reference.png`: each reference render side by side with the model's 3/4 and front renders

The previews are Blender EEVEE renders with a neutral grey set. They are not in-game captures, and the biome capture has not been made.

## Final vs placeholder

| Item | Status |
| --- | --- |
| Silhouettes, proportions and palettes | First production pass; matches the reference sheets in shape language and colour zones. Not final art. |
| Surface detail | Flat colour zones only. The magenta crack lines from the references are flat magenta faces here. |
| Rigs | Usable and simple. Bone counts are within the brief. |
| Pose actions | Placeholder blocking poses |
| Collision proxies | Final-ready simple shapes |
| Roblox import, scale and orientation | **Unverified.** Needs a Studio import check. |
| Biome capture and in-game performance | Not done |

---

# Gargoyle and Mire

This section covers **Gargoyle** and **Mire**. They were built headless (Blender 5.1.2, `blender -b`)
from procedural scripts. Like the models above, they have not been imported into Roblox Studio yet.

## Files

| File | What it is |
| --- | --- |
| `gargoyle.blend`, `mire.blend` | Blender source: skinned body mesh, armature, three pose actions (fake user), collision proxy, hidden static copies, and a `Preview_Only` collection (lights, ground, 5-stud block) that is not exported |
| `gargoyle.fbx`, `mire.fbx` | Rigged FBX (armature + skinned mesh), rest pose, no animation |
| `gargoyle_anim_{statue,awaken,attack}.fbx` | Same rig, one baked action each |
| `mire_anim_{submerged,emerge,swipe}.fbx` | Same rig, one baked action each |
| `gargoyle_static.fbx`, `mire_static.fbx` | Rigless fallback in the rest pose |
| `gargoyle_statue_static.fbx` | Rigless fallback frozen in the folded statue pose (for the inert cemetery statue) |
| `mire_submerged_static.fbx` | Rigless fallback frozen in the submerged pose. Everything below Z = 0 sits under the water line. |
| `gargoyle_collision.fbx`, `mire_collision.fbx` | Collision proxy: two boxes each, 24 triangles |
| `gargoyle_palette.png`, `mire_palette.png` | 48 × 8 flat palette strip (also embedded in every FBX) |
| `previews/gargoyle-*.png`, `previews/mire-*.png` | Preview renders (see below) |
| `src/beastkit.py`, `src/gargoyle_build.py`, `src/mire_build.py` | Build scripts. Each creature's script regenerates all of its files above. |

Rebuild one creature headless (append `-- --no-render` to skip the previews):

```
blender -b --factory-startup --python assets/models/beasts/src/gargoyle_build.py
blender -b --factory-startup --python assets/models/beasts/src/mire_build.py
```

## Scale, pivot and orientation

- 1 Blender unit = 1 metre = **1 stud**. Scene unit scale is 1.0.
- The FBX files use `apply_unit_scale` with `FBX_SCALE_NONE`. A re-import into Blender gave scale 1.0 and the same sizes in metres.
- Pivot: the world origin on the ground plane (Z = 0), where the `Root` bone sits.
- The creatures face **-Y** in Blender. The FBX axes are forward -Z and up Y.

| | Bounding box X × Y × Z (studs) | Notes |
| --- | --- | --- |
| Gargoyle (rest, wings open) | 13.8 × 7.7 × 8.0 | wingspan 13.8 (target 11–15); 8.0 tall at the wing spikes, about 6.8 at the horn tip |
| Gargoyle (statue pose) | 5.2 × 8.5 × 7.5 | wings folded back along the body |
| Mire (rest) | 13.0 × 10.9 × 4.2 | central body (shell + head) about 6.5 long × 5.5 wide; the long forelimbs reach 13 studs across |
| Mire (submerged) | about 2.5 above Z = 0 | only the mossy back, the brow and the eyes (0.1–0.4 above the water line) show |

**Roblox import scale (not verified in Studio):** check the size in the 3D Importer preview. Gargoyle
should be about 14 studs wide and 8 tall, and Mire about 13 wide and 4 tall. If the importer reads
the file as centimetres (100× too small), fix the unit setting in the importer or scale the Model once.
If the creature faces backwards, rotate it 180° around Y.

## Triangle counts

| Mesh | Gargoyle | Mire |
| --- | --- | --- |
| Body: one skinned mesh, eyes included | **3,782** | **3,016** |
| Collision proxy | 24 | 24 |

Mire is inside its 2k–8k target. Gargoyle is just under its 4k–10k wing budget, which is a ceiling,
not a minimum. All faces are flat shaded and triangulated. Every part is a closed shell, with normals
recalculated outward.

## Materials and colours

The body uses one palette material (`*_Palette`, closest-pixel sampling). Each face's UVs sit on one
swatch. The eye faces are part of the same mesh but use a second, emissive material (`*_EyeGlow`).

- Gargoyle (sRGB): stone `#9E94AD`, dark stone `#786E8C`, membrane `#80739C`, claw `#5E5773`, moss `#809924`, eye cyan `#4DFFEB`.
- Mire (sRGB): stone `#4A6663`, dark stone `#304547`, moss `#8C9E38`, dark moss `#597326`, fungus cream `#DED4A3`, eye amber `#FFC74D`.
- In Roblox, the eye faces carry the eye swatch from the palette. A real glow needs either a `SurfaceAppearance` emissive mask or two small `Neon` parts over the eyes. Which one to use is still open.

## Rigs

Each part is rigidly skinned to one bone (weight 1.0, one influence), which matches the stacked-rock
construction. Leaf bones are off. `Root` has no weights.

**Gargoyle_Rig (20 bones)**

- `Root` → `Hips` → `Spine` → `Head` → `Jaw`
- `Hips` → `Tail`, `Leg_L_Upper` → `Leg_L_Lower`, and the matching right leg
- `Spine` → `Arm_L_Upper` → `Arm_L_Lower` (forearm and hand), and the matching right arm
- `Spine` → `Wing_L_1` → `Wing_L_2` → `Wing_L_3` (shoulder spar, wrist, long finger), and the matching right wing

**Mire_Rig (15 bones)**

- `Root` → `Shell` → `Head`
- `Shell` → `ArmF_L_1` → `ArmF_L_2` → `ArmF_L_3` (front forelimb: upper, forearm, root-claw hand), and the matching right limb
- `Shell` → `ArmM_L_1..3` (second forelimb pair), and the matching right limb
- The short hind stubs and the dragging tail are skinned to `Shell`.

**Pose actions (blocking poses with linear in-betweens, not polished animation):**

| Action | Frames | Status |
| --- | --- | --- |
| `Statue` (Gargoyle) | 1–30, held | exists: upright crouch, head lowered, wings folded back |
| `Awaken` (Gargoyle) | 1–50 | exists: statue → rest → wings raised with jaw open → rest |
| `Attack` (Gargoyle) | 1–40 | exists: wings rise, then thrust forward with the left arm raised (tornado cast) |
| Takeoff, hover, wingbeat, land/petrify (Gargoyle) | | missing |
| `Submerged` (Mire) | 1–30, held | exists: body sunk 1.7 studs, limbs folded below the water line, head tilted up |
| `Emerge` (Mire) | 1–30 | exists: submerged → reared up with the front limbs lifted → rest |
| `Swipe` (Mire) | 1–34 | exists: right front limb winds up, swipes across, then recovers |
| Underwater glide, recover, sink (Mire) | | missing |

The rigs are FK only, and the feet are not locked to the ground. In the statue pose, the hands and feet
were placed on the ground by measurement.

## Import into Roblox Studio (intended steps, not yet run)

1. Avatar tab → **Import 3D** → choose `gargoyle.fbx` or `mire.fbx`. Keep Rig General (a custom rig, not R15), check the size in the preview, and import as a Model.
2. Keep the embedded palette texture, or set `TextureID` to the uploaded `*_palette.png`. Add the eye glow as described under Materials and colours.
3. Import `*_collision.fbx` as a separate MeshPart and set `Transparency = 1` and `CanCollide = true`. Turn off `CanCollide` and `CanQuery` on the visual mesh.
4. For animation, open the Animation Editor on the imported rig and use **Import → From FBX Animation** with `*_anim_*.fbx`. The baked take is named `Scene`.
5. Fallback: use the static FBX files with CFrame or TweenService. `gargoyle_statue_static.fbx` can serve as the inert statue, swapped for the rigged model on awaken. `mire_submerged_static.fbx` can serve as the lurking state.

By design, the meshes contain no gameplay VFX: the tornado, ripples, bubbles, dust, warning ring and
crack glow are all separate.

## Previews

- Gargoyle: `gargoyle-front.png`, `gargoyle-side.png`, `gargoyle-three-quarter.png`, `gargoyle-attack.png` (`Attack` frame 24), `gargoyle-statue.png`, `gargoyle-scale-avatar.png` (next to a 2 × 1 × 5-stud avatar block)
- Mire: `mire-front.png`, `mire-side.png`, `mire-three-quarter.png`, `mire-attack.png` (`Swipe` wind-up, frame 10), `mire-submerged.png` (opaque murky water plane at Z = 0), `mire-scale-avatar.png`
- `gargoyle-vs-reference.png` and `mire-vs-reference.png`: the reference render next to the 3/4, the front, and the statue or submerged render

These are Blender EEVEE renders on a neutral grey set, not in-game or biome captures.

## Final vs placeholder

| Item | Status |
| --- | --- |
| Silhouette, proportions and palette | First production pass. Each reads as its reference creature, but this is not final art. |
| Gargoyle gaps | The wings are flat, straight-edged plates; the reference wings are thicker, curved and arched. There are no painted cracks. The head is blockier and less sculpted than the reference. |
| Mire gaps | The moss brow reads a little like a comb of teeth. The fingers are pointed spikes, where the reference has blunt block fingers. The shell is flatter on top, and the moss drapes less heavily than in the reference. |
| Rigs | Usable and simple; they match the bones listed in the brief |
| Pose actions | Placeholder blocking poses, 3 per creature. Several gameplay clips are still missing (see Rigs). |
| Collision proxies | Final-ready simple boxes. The Gargoyle proxy ignores the wings on purpose. |
| Eye glow in Roblox | Open: emissive mask or Neon parts |
| Roblox import, scale and orientation | **Unverified.** Needs a Studio import check. |

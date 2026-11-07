"""Add the Search_v1 clip to the Silueta v3 rig without touching the rig or its four clips (roadmap M2.4).

Run: "D:/blender/blender.exe" --background --factory-startup --python tools/build-silueta-search-v1.py
Then: SILUETA_SEARCH_MODE=verify-fbx "D:/blender/blender.exe" --background --factory-startup --python tools/build-silueta-search-v1.py

The existing rig source (assets/blender/silueta-horror-rig-v3.blend) is only opened, never saved
over. Its new action is keyed from tools/silueta_motion_v3.py exactly the way the original builder
keys the four clips, then the scene is saved under a new name and one FBX with only the new clip is
exported. The seven original files are hashed before and after, and the build stops if any hash
differs from the one recorded when they shipped. Silueta's model, rig and gameplay proxy are not
edited. Nothing is uploaded or imported into Roblox, so the in-game look stays unverified.
"""

import hashlib
import importlib.util
import json
import math
import os
import subprocess
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[1]
BLENDER_DIR, EXPORT_DIR = ROOT / "assets/blender", ROOT / "assets/exports"
ORIGINAL_BLEND = BLENDER_DIR / "silueta-horror-rig-v3.blend"
ORIGINAL_REPORT = BLENDER_DIR / "silueta-horror-rig-v3-report.json"
NEW_BLEND = BLENDER_DIR / "silueta-horror-rig-v3-search-v1.blend"
NEW_REPORT = BLENDER_DIR / "silueta-horror-rig-v3-search-v1-report.json"
NEW_QA = BLENDER_DIR / "silueta-horror-rig-v3-search-v1-qa.png"
NEW_FBX = EXPORT_DIR / "silueta-horror-rig-v3-search-v1.fbx"
CLIP = "Search_v1"
ACTION_NAME = "SiluetaV3_Search_v1"
ORIGINAL_FILES = ("silueta-horror-rig-v3.blend", "silueta-horror-rig-v3.glb", "silueta-horror-rig-v3-model.fbx",
                  "silueta-horror-rig-v3-idle.fbx", "silueta-horror-rig-v3-locomotion.fbx",
                  "silueta-horror-rig-v3-telegraph.fbx", "silueta-horror-rig-v3-attack.fbx")

spec = importlib.util.spec_from_file_location("silueta_motion_v3", ROOT / "tools/silueta_motion_v3.py")
motion = importlib.util.module_from_spec(spec)
spec.loader.exec_module(motion)


def original_path(name):
    return (EXPORT_DIR if name.endswith((".fbx", ".glb")) else BLENDER_DIR) / name


def hash_originals():
    return {name: hashlib.sha256(original_path(name).read_bytes()).hexdigest() for name in ORIGINAL_FILES}


def linear(action):
    try:
        curves = [c for layer in action.layers for strip in layer.strips for bag in strip.channelbags
                  for c in bag.fcurves]
    except AttributeError:
        curves = list(action.fcurves)
    for curve in curves:
        for key in curve.keyframe_points:
            key.interpolation = "LINEAR"
    return curves


def action_curves(action):
    try:
        return [c for layer in action.layers for strip in layer.strips for bag in strip.channelbags
                for c in bag.fcurves]
    except AttributeError:
        return list(action.fcurves)


def build():
    original_report = json.loads(ORIGINAL_REPORT.read_text(encoding="utf-8"))
    before = hash_originals()
    for name, digest in before.items():
        if digest != original_report["exports"][name]["sha256"]:
            raise RuntimeError(f"{name} no longer matches the hash recorded when it shipped; refusing to build")
    for path in (NEW_BLEND, NEW_REPORT, NEW_QA, NEW_FBX):
        path.parent.mkdir(parents=True, exist_ok=True)

    bpy.ops.wm.open_mainfile(filepath=str(ORIGINAL_BLEND))
    scene = bpy.context.scene
    vl = scene.view_layers[0]
    rig = bpy.data.objects["SiluetaV3_Rig"]
    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    assert len(meshes) == 9 and len(rig.data.bones) == 18 and list(rig.data.bones.keys()) == list(motion.BONES)
    assert sorted(a.name for a in bpy.data.actions) == sorted("SiluetaV3_" + n for n in motion.DURATIONS)
    triangles = 0
    for obj in meshes:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)

    # Key the new action the way tools/build-silueta-rig-v3.py keys the original four.
    duration = motion.EXTRA_CLIPS[CLIP]
    frames = round(duration * motion.FPS) + 1
    action = bpy.data.actions.new(ACTION_NAME)
    action.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = action
    for frame in range(1, frames + 1):
        profile = motion.pose(CLIP, (frame - 1) / (frames - 1))
        for bone in rig.pose.bones:
            bone.rotation_mode = "XYZ"
            bone.rotation_euler = profile[bone.name]
            bone.location = (0, 0, 0)
            bone.scale = (1, 1, 1)
            bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone.name)
    linear(action)
    action["duration_seconds"] = duration
    action["in_place"] = True
    action["loop"] = True
    action["damage_authority"] = "None"
    action["version"] = CLIP

    # Sample every frame of the new clip.
    scene.frame_start, scene.frame_end = 1, frames
    positions, root_reference, root_error, finite = [], None, 0.0, True
    movement = {obj.name: 0.0 for obj in meshes}
    baseline = None
    with bpy.context.temp_override(scene=scene, view_layer=vl):
        for frame in range(1, frames + 1):
            scene.frame_set(frame)
            vl.update()
            depsgraph = bpy.context.evaluated_depsgraph_get()
            evaluated_rig = rig.evaluated_get(depsgraph)
            root = evaluated_rig.pose.bones["Root"].matrix.copy()
            root_reference = root if root_reference is None else root_reference
            root_error = max(root_error, max(abs(root[i][j] - root_reference[i][j])
                                             for i in range(4) for j in range(4)))
            finite = finite and all(math.isfinite(v) for bone in evaluated_rig.pose.bones
                                    for row in bone.matrix for v in row)
            sample = {}
            for obj in meshes:
                evaluated = obj.evaluated_get(depsgraph)
                data = evaluated.to_mesh()
                points = [evaluated.matrix_world @ vertex.co for vertex in data.vertices]
                finite = finite and all(math.isfinite(v) for point in points for v in point)
                sample[obj.name] = points
                evaluated.to_mesh_clear()
            baseline = sample if baseline is None else baseline
            for name, points in sample.items():
                movement[name] = max(movement[name], max((p - r).length for p, r in zip(points, baseline[name])))
            if frame in (1, frames):
                positions.append(sample)
    endpoint_error = max((a - b).length for name in positions[0] for a, b in zip(positions[0][name], positions[1][name]))

    # Export only the new clip, with the same settings the original four used.
    for obj in scene.objects:
        obj.select_set(obj == rig or obj in meshes, view_layer=vl)
    vl.objects.active = rig
    settings = dict(use_selection=True, object_types={"ARMATURE", "MESH"}, apply_unit_scale=True,
                    apply_scale_options="FBX_SCALE_UNITS", global_scale=1, axis_forward="-Z", axis_up="Y",
                    add_leaf_bones=False, use_armature_deform_only=False, bake_anim_use_nla_strips=False,
                    bake_anim_use_all_actions=False, bake_anim_force_startend_keying=True,
                    bake_anim_simplify_factor=0)
    with bpy.context.temp_override(scene=scene, view_layer=vl, object=rig, active_object=rig,
                                   selected_objects=[rig, *meshes], selected_editable_objects=[rig, *meshes]):
        scene.frame_set(1)
        bpy.ops.export_scene.fbx(filepath=str(NEW_FBX), bake_anim=True, **settings)

    render_qa(scene, vl, rig)

    # Leave the scene as the original was, then save it under the new name.
    rig.animation_data.action = bpy.data.actions["SiluetaV3_Idle"]
    scene.frame_start, scene.frame_end = 1, 91
    scene.frame_set(1)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(NEW_BLEND), check_existing=False, compress=True)

    after = hash_originals()
    unchanged = before == after
    NEW_REPORT.write_text(json.dumps({
        "generator": "tools/build-silueta-search-v1.py",
        "blender_version": bpy.app.version_string,
        "status": "unvalidated",
        "uploaded": False,
        "design_changed": False,
        "new_rig_triangles": triangles,
        "not_verified": ("in-game look, Studio import and AnimationId, mobile readability, and whether players read it "
                         "as a search; upload stays pending and needs the user's consent"),
        "clip": CLIP,
        "action": {"name": action.name, "frame_start": 1, "frame_end": frames, "duration_seconds": duration,
                   "sampled_frames": frames, "finite": finite, "root_max_error": root_error,
                   "endpoint_mesh_error_m": endpoint_error, "loop": True,
                   "max_world_vertex_displacement_m": movement},
        "files": {"blend": NEW_BLEND.relative_to(ROOT).as_posix(), "fbx": NEW_FBX.relative_to(ROOT).as_posix(),
                  "qa_render": NEW_QA.relative_to(ROOT).as_posix(),
                  "fbx_sha256": hashlib.sha256(NEW_FBX.read_bytes()).hexdigest(),
                  "fbx_bytes": NEW_FBX.stat().st_size},
        "fbx_settings": {k: sorted(v) if isinstance(v, set) else v for k, v in settings.items()},
        "original_files": {"before": before, "after": after, "unchanged": unchanged},
        "qa_layout": ("columns left to right: Idle rest, Search_v1 at 25%, 50%, 75% of the loop, Telegraph hold; "
                      "top row from the preview camera, bottom row from the front"),
    }, indent=2), encoding="utf-8")
    if not unchanged:
        raise RuntimeError("an original Silueta file changed during the build")
    print("SEARCH_V1_BUILD_OK", frames, endpoint_error, movement)


def render_qa(scene, vl, rig):
    """Idle, three Search_v1 moments and the Telegraph hold, from the preview camera and from the front."""
    import numpy as np
    preview = scene.camera
    front_data = preview.data.copy()
    front = bpy.data.objects.new("SiluetaV3_QAFrontCamera", front_data)
    scene.collection.objects.link(front)
    front.location = (0.0, -7.5, 1.25)
    front.rotation_euler = (math.radians(90), 0.0, 0.0)
    tile_w, tile_h, gap = 400, 440, 6
    moments = (("SiluetaV3_Idle", 1), (ACTION_NAME, 19), (ACTION_NAME, 37), (ACTION_NAME, 55),
               ("SiluetaV3_Telegraph", 43))
    scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = tile_w, tile_h, 100
    scene.render.image_settings.file_format = "PNG"
    paths = []
    for row, camera in enumerate((preview, front)):
        scene.camera = camera
        for column, (name, frame) in enumerate(moments):
            rig.animation_data.action = bpy.data.actions[name]
            scene.frame_set(frame)
            path = Path(bpy.app.tempdir) / f"qa_{row}_{column}.png"
            scene.render.filepath = str(path)
            with bpy.context.temp_override(scene=scene, view_layer=vl):
                bpy.ops.render.render(write_still=True)
            paths.append((row, column, path))
    scene.camera = preview
    bpy.data.objects.remove(front, do_unlink=True)
    bpy.data.cameras.remove(front_data)
    width = len(moments) * tile_w + (len(moments) + 1) * gap
    height = 2 * tile_h + 3 * gap
    canvas = np.full((height, width, 4), 0.86, dtype=np.float32)
    canvas[:, :, 3] = 1.0
    for row, column, path in paths:
        image = bpy.data.images.load(str(path))
        pixels = np.empty(tile_w * tile_h * 4, dtype=np.float32)
        image.pixels.foreach_get(pixels)
        left = gap + column * (tile_w + gap)
        bottom = height - (gap + row * (tile_h + gap)) - tile_h
        canvas[bottom:bottom + tile_h, left:left + tile_w] = pixels.reshape(tile_h, tile_w, 4)
        bpy.data.images.remove(image)
    sheet = bpy.data.images.new("Search_v1_QA", width, height, alpha=False)
    sheet.pixels.foreach_set(canvas.ravel())
    sheet.filepath_raw = str(NEW_QA)
    sheet.file_format = "PNG"
    sheet.save()
    bpy.data.images.remove(sheet)
    scene.render.resolution_x, scene.render.resolution_y = 1000, 1100


def verify_fbx():
    """Re-import the new FBX in a fresh empty scene and add what came back to the report."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    before_objects = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(NEW_FBX))
    bpy.context.view_layer.update()
    objects = list(set(bpy.data.objects) - before_objects)
    armatures = [obj for obj in objects if obj.type == "ARMATURE"]
    meshes = [obj for obj in objects if obj.type == "MESH" and any(m.type == "ARMATURE" for m in obj.modifiers)]
    vertices = [obj.matrix_world @ vertex.co for obj in meshes for vertex in obj.data.vertices]
    triangles = 0
    for obj in meshes:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
    action = max(bpy.data.actions, key=lambda a: len(action_curves(a)))
    curves = action_curves(action)
    keyed = {round(k.co[0]) for c in curves for k in c.keyframe_points}
    start, end = action.frame_range
    trip = {"armatures": len(armatures), "bones": len(armatures[0].data.bones), "meshes": len(meshes),
            "triangles": triangles,
            "vertices_without_weights": sum(not v.groups for obj in meshes for v in obj.data.vertices),
            "dimensions_m": [max(v[i] for v in vertices) - min(v[i] for v in vertices) for i in range(3)],
            "actions": len(bpy.data.actions), "animated_channels": len(curves), "keyed_frames": len(keyed),
            "frame_range": [start, end], "scene_fps": bpy.context.scene.render.fps,
            "duration_seconds": (end - start) / motion.FPS,
            "note": "Blender shifts an imported take by one frame (docs/assets/silueta-rig.md:57)."}
    report = json.loads(NEW_REPORT.read_text(encoding="utf-8"))
    report["roundtrip"] = trip
    NEW_REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("SEARCH_V1_ROUNDTRIP", json.dumps(trip))


if os.environ.get("SILUETA_SEARCH_MODE") == "verify-fbx":
    verify_fbx()
else:
    build()

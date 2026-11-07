"""Read owned exports in an isolated --background --factory-startup Blender."""

import json
import math
from pathlib import Path

import bpy

ROOT = Path("C:/Users/Jesus/Documents/ChatGPT/roblox-terror")
EXPORT = ROOT / "assets/exports"
REPORT = ROOT / "assets/blender/silueta-horror-rig-v3-roundtrip-full.json"
assert bpy.app.background, "Never run this isolation check in the user's live Blender."
assert not REPORT.exists(), "Preserve prior roundtrip evidence."
report = {}
for kind, filename in (("glb", "silueta-horror-rig-v3.glb"),
                       ("fbx_model", "silueta-horror-rig-v3-model.fbx"),
                       *(("fbx_" + name, "silueta-horror-rig-v3-" + name + ".fbx")
                         for name in ("idle", "locomotion", "telegraph", "attack"))):
    before_objects, before_actions = set(bpy.data.objects), set(bpy.data.actions)
    if kind == "glb":
        bpy.ops.import_scene.gltf(filepath=str(EXPORT / filename))
    else:
        bpy.ops.import_scene.fbx(filepath=str(EXPORT / filename))
    objects = list(set(bpy.data.objects) - before_objects)
    armatures = [obj for obj in objects if obj.type == "ARMATURE"]
    meshes = [obj for obj in objects if obj.type == "MESH" and
              any(modifier.type == "ARMATURE" for modifier in obj.modifiers)]
    actions = list(set(bpy.data.actions) - before_actions)
    vertices = [obj.matrix_world @ vertex.co for obj in meshes for vertex in obj.data.vertices]
    details = {"armatures": len(armatures), "bones": [len(obj.data.bones) for obj in armatures],
               "meshes": len(meshes), "actions": [action.name for action in actions],
               "vertices_without_weights": sum(not vertex.groups for obj in meshes for vertex in obj.data.vertices),
               "dimensions_m": [max(v[i] for v in vertices) - min(v[i] for v in vertices) for i in range(3)],
               "triangles": 0,
               "unskinned_importer_helpers": [obj.name for obj in objects if obj.type == "MESH" and obj not in meshes]}
    for obj in meshes:
        obj.data.calc_loop_triangles()
        details["triangles"] += len(obj.data.loop_triangles)
    print("ROUNDTRIP_OBSERVED", kind, json.dumps(details))
    assert len(armatures) == 1 and len(armatures[0].data.bones) == 18
    assert len(meshes) == 9 and details["vertices_without_weights"] == 0
    assert abs(details["dimensions_m"][2] - 2.4) < 1e-4
    assert len(actions) == (4 if kind == "glb" else 0 if kind == "fbx_model" else 1)
    details["evaluated_actions"] = []
    imported_rig = armatures[0]
    for action in actions:
        imported_rig.animation_data.action = action
        first, last = action.frame_range
        frames = (first, (first + last) / 2, last)
        matrices = []
        for frame in frames:
            bpy.context.scene.frame_set(round(frame))
            bpy.context.view_layer.update()
            evaluated = imported_rig.evaluated_get(bpy.context.evaluated_depsgraph_get())
            matrices.append({bone.name: bone.matrix.copy() for bone in evaluated.pose.bones})
            assert all(math.isfinite(v) for bone in evaluated.pose.bones for row in bone.matrix for v in row)
        root_error = max(abs(sample["Root"][i][j] - matrices[0]["Root"][i][j])
                         for sample in matrices for i in range(4) for j in range(4))
        motion = max(abs(sample[bone][i][j] - matrices[0][bone][i][j])
                     for sample in matrices for bone in sample for i in range(4) for j in range(4))
        # Idle is sinusoidal and its midpoint may also be neutral: sample quarter-cycle.
        if motion < 1e-5:
            bpy.context.scene.frame_set(round(first + (last - first) / 4))
            evaluated = imported_rig.evaluated_get(bpy.context.evaluated_depsgraph_get())
            motion = max(abs(bone.matrix[i][j] - matrices[0][bone.name][i][j])
                         for bone in evaluated.pose.bones for i in range(4) for j in range(4))
        assert root_error < 1e-4 and motion > .001
        details["evaluated_actions"].append({"name": action.name, "frames": [first, last],
                                             "fps": bpy.context.scene.render.fps,
                                             "duration_seconds": (last - first) / bpy.context.scene.render.fps,
                                             "root_matrix_error": root_error, "pose_matrix_motion": motion})
    report[kind] = details
    for obj in objects:
        bpy.data.objects.remove(obj, do_unlink=True)
    for action in actions:
        bpy.data.actions.remove(action, do_unlink=True)
report["isolation"] = "Separate background factory-startup process; live Blender untouched."
REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")
print("SILUETA_ROUNDTRIP_PASS", json.dumps(report))

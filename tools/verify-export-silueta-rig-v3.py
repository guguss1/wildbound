"""Evaluate owned rig, save isolated source, export authorized files and roundtrip.

No upload or Studio operation. Run only in the existing authorized Blender session.
"""

import hashlib
import json
import math
import struct
import subprocess
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path("C:/Users/Jesus/Documents/ChatGPT/roblox-terror")
OUT, EXPORT = ROOT / "assets/blender", ROOT / "assets/exports"
scene = bpy.data.scenes["Wildbound_Silueta_HorrorRig_v3"]
rig = bpy.data.objects["SiluetaV3_Rig"]
meshes = [obj for obj in scene.objects if obj.type == "MESH"]
actions = {name: bpy.data.actions["SiluetaV3_" + name]
           for name in ("Idle", "Locomotion", "Telegraph", "Attack")}
BLEND = OUT / "silueta-horror-rig-v3.blend"
REPORT = OUT / "silueta-horror-rig-v3-report.json"
GLB = EXPORT / "silueta-horror-rig-v3.glb"
MODEL_FBX = EXPORT / "silueta-horror-rig-v3-model.fbx"
assert not any(path.exists() for path in (BLEND, REPORT, GLB, MODEL_FBX))
initial_context = json.loads(scene["initial_context_json"])


def context_snapshot():
    return {"file": bpy.data.filepath, "scene": bpy.context.scene.name, "mode": bpy.context.mode,
            "active": bpy.context.view_layer.objects.active.name if bpy.context.view_layer.objects.active else None,
            "selection": sorted(obj.name for obj in bpy.context.selected_objects)}


def stable_object_snapshot():
    return {obj.name: (obj.as_pointer(), tuple(tuple(row) for row in obj.matrix_world),
                       obj.data.as_pointer() if obj.data else None,
                       tuple(tuple(v.co) for v in obj.data.vertices) if obj.type == "MESH" else None)
            for obj in bpy.data.objects}


def enum_value(operator, name, wanted):
    return next(item.identifier for item in operator.get_rna_type().properties[name].enum_items
                if item.identifier == wanted)


assert context_snapshot() == initial_context
before = stable_object_snapshot()
report = {"asset": scene.name, "source_axes": "Z up, face -Y", "source_origin": [0, 0, 0],
          "fps": scene.render.fps, "custom_bones": list(rig.data.bones.keys()), "mesh_health": [],
          "actions": {}, "preview_files": {}, "exports": {}, "initial_context": initial_context,
          "runtime_damage_authority": "None; runtime server FSM must retain control.",
          "limitations": ["Not yet imported or played in Roblox; exported clips are not Roblox AnimationIDs.",
                          "Intentional overlapping closed shells, not welded production deformation topology.",
                          "Per-face planar UV placeholders and four opaque materials; no textures/LOD.",
                          "Mobile performance and real gameplay animation synchronization remain pending."]}
for obj in meshes:
    data = obj.data
    data.calc_loop_triangles()
    bm = bmesh.new()
    bm.from_mesh(data)
    bad_weights = []
    for vertex in data.vertices:
        influences = [(obj.vertex_groups[group.group].name, group.weight) for group in vertex.groups]
        if (not influences or len(influences) > 4 or
                any(name not in rig.data.bones or not math.isfinite(weight) or weight <= 0 for name, weight in influences) or
                abs(sum(weight for name, weight in influences) - 1) > 1e-5):
            bad_weights.append(vertex.index)
    health = {"name": obj.name, "vertices": len(data.vertices), "triangles": len(data.loop_triangles),
              "nonmanifold_edges": sum(not edge.is_manifold for edge in bm.edges),
              "boundary_edges": sum(edge.is_boundary for edge in bm.edges),
              "loose_vertices": sum(not vertex.link_edges for vertex in bm.verts),
              "degenerate_faces": sum(face.calc_area() < 1e-10 for face in bm.faces),
              "bad_weight_vertices": bad_weights,
              "max_influences": max(len(v.groups) for v in data.vertices),
              "signed_volume": bm.calc_volume(signed=True)}
    bm.free()
    assert all(health[key] == 0 for key in ("nonmanifold_edges", "boundary_edges", "loose_vertices", "degenerate_faces"))
    assert not bad_weights and health["signed_volume"] > 0 and health["triangles"] < 20000
    report["mesh_health"].append(health)

report["triangles"] = sum(item["triangles"] for item in report["mesh_health"])
report["vertices"] = sum(item["vertices"] for item in report["mesh_health"])
assert report["triangles"] < 2500 and len(rig.data.bones) == 18
vl = scene.view_layers[0]
with bpy.context.temp_override(scene=scene, view_layer=vl):
    for label, action in actions.items():
        rig.animation_data.action = action
        first, last = map(round, action.frame_range)
        positions, bone_matrices = [], []
        root_reference, movements = None, {obj.name: 0.0 for obj in meshes}
        baseline = None
        for frame in range(first, last + 1):
            scene.frame_set(frame)
            vl.update()
            depsgraph = bpy.context.evaluated_depsgraph_get()
            evaluated_rig = rig.evaluated_get(depsgraph)
            root = evaluated_rig.pose.bones["Root"].matrix.copy()
            root_reference = root if root_reference is None else root_reference
            assert max(abs(root[i][j] - root_reference[i][j]) for i in range(4) for j in range(4)) < 1e-6
            assert all(math.isfinite(value) for bone in evaluated_rig.pose.bones for row in bone.matrix for value in row)
            sample = {}
            for obj in meshes:
                evaluated = obj.evaluated_get(depsgraph)
                data = evaluated.to_mesh()
                points = [evaluated.matrix_world @ vertex.co for vertex in data.vertices]
                assert all(math.isfinite(value) for point in points for value in point)
                sample[obj.name] = points
                evaluated.to_mesh_clear()
            if baseline is None:
                baseline = sample
            for name, points in sample.items():
                movements[name] = max(movements[name], max((point - rest).length for point, rest in zip(points, baseline[name])))
            if frame in (first, last):
                positions.append(sample)
                bone_matrices.append({bone.name: bone.matrix.copy() for bone in evaluated_rig.pose.bones})
        endpoint_error = max((a - b).length for name in positions[0]
                             for a, b in zip(positions[0][name], positions[1][name]))
        if label in ("Idle", "Locomotion"):
            assert endpoint_error < 1e-5
        report["actions"][label] = {"action": action.name, "frames": [first, last],
                                    "duration_seconds": (last - first) / scene.render.fps,
                                    "sampled_frames": last - first + 1, "root_max_error": 0.0,
                                    "max_world_vertex_displacement_m": movements,
                                    "endpoint_mesh_error_m": endpoint_error}
    assert abs(report["actions"]["Telegraph"]["duration_seconds"] - 1.4) < 1e-8
    for name in ("SiluetaV3_Head", "SiluetaV3_Body", "SiluetaV3_ArmLeft", "SiluetaV3_ArmRight"):
        assert max(action["max_world_vertex_displacement_m"][name] for action in report["actions"].values()) > .02
    assert report["actions"]["Locomotion"]["max_world_vertex_displacement_m"]["SiluetaV3_Body"] > .08
    rig.animation_data.action = actions["Idle"]
    scene.frame_set(1)
    vl.update()

vertices = [obj.matrix_world @ vertex.co for obj in meshes for vertex in obj.data.vertices]
report["world_vertex_min_m"] = [min(v[i] for v in vertices) for i in range(3)]
report["world_vertex_max_m"] = [max(v[i] for v in vertices) for i in range(3)]
report["world_vertex_dimensions_m"] = [report["world_vertex_max_m"][i] - report["world_vertex_min_m"][i] for i in range(3)]
for label in ("front", "back", "telegraph-qa", "attack-qa", "locomotion-qa"):
    path = OUT / ("silueta-horror-rig-v3-" + label + ".png")
    assert path.is_file()
    report["preview_files"][label] = str(path)
scene.render.filepath = report["preview_files"]["front"]
bpy.data.libraries.write(str(BLEND), {scene, *actions.values()}, fake_user=True, compress=True)
with bpy.data.libraries.load(str(BLEND), link=False) as (available, requested):
    report["source_readback"] = {"scenes": list(available.scenes), "objects": list(available.objects),
                                  "armatures": list(available.armatures), "actions": list(available.actions)}
assert report["source_readback"]["scenes"] == [scene.name]
assert len(report["source_readback"]["actions"]) == 4
assert not any(name in report["source_readback"]["objects"] for name in ("Cube", "Camera", "Light", "Silueta_Body"))

EXPORT.mkdir(parents=True, exist_ok=True)
for obj in scene.objects:
    obj.select_set(obj == rig or obj in meshes, view_layer=vl)
vl.objects.active = rig
fbx = bpy.ops.export_scene.fbx
fbx_settings = dict(use_selection=True, object_types={enum_value(fbx, "object_types", value) for value in ("ARMATURE", "MESH")},
                    apply_unit_scale=True, apply_scale_options=enum_value(fbx, "apply_scale_options", "FBX_SCALE_UNITS"),
                    global_scale=1, axis_forward=enum_value(fbx, "axis_forward", "-Z"), axis_up=enum_value(fbx, "axis_up", "Y"),
                    add_leaf_bones=False, use_armature_deform_only=False,
                    bake_anim_use_nla_strips=False, bake_anim_use_all_actions=False,
                    bake_anim_force_startend_keying=True, bake_anim_simplify_factor=0)
with bpy.context.temp_override(scene=scene, view_layer=vl, object=rig, active_object=rig,
                               selected_objects=[rig, *meshes], selected_editable_objects=[rig, *meshes]):
    fbx(filepath=str(MODEL_FBX), bake_anim=False, **fbx_settings)
    for label, action in actions.items():
        path = EXPORT / ("silueta-horror-rig-v3-" + label.lower() + ".fbx")
        assert not path.exists()
        rig.animation_data.action = action
        scene.frame_start, scene.frame_end = map(round, action.frame_range)
        scene.frame_set(scene.frame_start)
        fbx(filepath=str(path), bake_anim=True, **fbx_settings)
    rig.animation_data.action = actions["Idle"]
    scene.frame_start, scene.frame_end = 1, 91
    scene.frame_set(1)
    from io_scene_gltf2 import ExportGLTF2
    format_property = next(cls.__annotations__["export_format"] for cls in ExportGLTF2.__mro__
                           if "export_format" in getattr(cls, "__annotations__", {}))
    glb_format = next(item[0] for item in format_property.keywords["items"](None, bpy.context) if item[0] == "GLB")
    gltf = bpy.ops.export_scene.gltf
    gltf(filepath=str(GLB), export_format=glb_format, use_selection=True, use_active_scene=True,
         export_skins=True, export_animations=True,
         export_animation_mode=enum_value(gltf, "export_animation_mode", "ACTIONS"),
         export_force_sampling=True, export_frame_range=False, export_apply=False,
         export_yup=True, export_materials=enum_value(gltf, "export_materials", "EXPORT"))

raw = GLB.read_bytes()
magic, version, length = struct.unpack_from("<4sII", raw, 0)
assert magic == b"glTF" and version == 2 and length == len(raw)
chunk_length, chunk_kind = struct.unpack_from("<II", raw, 12)
assert chunk_kind == 0x4E4F534A
gltf_data = json.loads(raw[20:20 + chunk_length])
report["glb_structure"] = {"skins": len(gltf_data.get("skins", [])),
                            "joints_per_skin": [len(skin["joints"]) for skin in gltf_data.get("skins", [])],
                            "animations": [action["name"] for action in gltf_data.get("animations", [])],
                            "meshes": len(gltf_data.get("meshes", [])),
                            "materials": len(gltf_data.get("materials", [])),
                            "cameras": len(gltf_data.get("cameras", []))}
assert report["glb_structure"]["skins"] >= 1
assert all(count == 18 for count in report["glb_structure"]["joints_per_skin"])
assert len(report["glb_structure"]["animations"]) == 4
assert report["glb_structure"]["meshes"] == len(meshes)
assert report["glb_structure"]["cameras"] == 0

# The native importer can change window.scene despite a scene override. Isolate
# all roundtrip reads in a new background factory-startup process, not the live UI.
roundtrip_path = OUT / "silueta-horror-rig-v3-roundtrip-full.json"
completed = subprocess.run([bpy.app.binary_path, "--background", "--factory-startup", "--python",
                            str(ROOT / "tools/roundtrip-silueta-rig-v3.py")],
                           capture_output=True, text=True,
                           creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
assert completed.returncode == 0 and "SILUETA_ROUNDTRIP_PASS" in completed.stdout
report["local_roundtrip"] = json.loads(roundtrip_path.read_text(encoding="utf-8"))

for path in [BLEND, GLB, MODEL_FBX, *(EXPORT / ("silueta-horror-rig-v3-" + label.lower() + ".fbx") for label in actions)]:
    assert path.is_file() and 0 < path.stat().st_size < 20_000_000
    report["exports"][path.name] = {"path": str(path), "bytes": path.stat().st_size,
                                    "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
assert context_snapshot() == initial_context
after = stable_object_snapshot()
assert all(after[name] == value for name, value in before.items())
report["original_context_preserved"] = True
report["existing_object_geometry_preserved"] = True
report["fbx_settings"] = {key: sorted(value) if isinstance(value, set) else value for key, value in fbx_settings.items()}
report["verification"] = {"motion_contracts": "Actual RED six stub errors, then GREEN 6/6; current profiles rerun GREEN.",
                           "runner": "D:/blender/5.1/python/bin/python.exe tools/test_silueta_motion_v3.py",
                           "visual_qa": "Front/back, corrected wide-held telegraph, forward strike and locomotion inspected.",
                           "render_gotcha": "Render inactive animation scene inside temp_override(scene/view_layer) to use intended frame."}
REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report, indent=2))

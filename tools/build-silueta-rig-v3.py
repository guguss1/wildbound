"""Original horror revision and custom rig. Reviewed local code only; no upload.

Uses the original v2 mesh data and its owned procedural Mesh helper, never edits
the original scene, v2 data or current file. Run through authorized Blender MCP.
"""

import ast
import hashlib
import importlib.util
import json
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path("C:/Users/Jesus/Documents/ChatGPT/roblox-terror")
OUT = ROOT / "assets/blender"
NAME = "Wildbound_Silueta_HorrorRig_v3"
BLEND = OUT / "silueta-horror-rig-v3.blend"
REPORT = OUT / "silueta-horror-rig-v3-report.json"
assert NAME not in bpy.data.scenes and NAME not in bpy.data.collections
assert not BLEND.exists() and not REPORT.exists(), "Versioned outputs must not be overwritten."


def context_snapshot():
    return {"file": bpy.data.filepath, "scene": bpy.context.scene.name, "mode": bpy.context.mode,
            "active": bpy.context.view_layer.objects.active.name if bpy.context.view_layer.objects.active else None,
            "selection": sorted(o.name for o in bpy.context.selected_objects)}


def existing_snapshot():
    result = {}
    for obj in bpy.data.objects:
        value = [obj.as_pointer(), tuple(tuple(row) for row in obj.matrix_world),
                 obj.data.as_pointer() if obj.data else None]
        if obj.type == "MESH":
            value.extend([tuple(tuple(v.co) for v in obj.data.vertices),
                          tuple(m.as_pointer() for m in obj.data.materials)])
        result[obj.name] = value
    return result


initial_context, initial_objects = context_snapshot(), existing_snapshot()


def enum_value(owner, property_name, wanted):
    rna = owner.bl_rna if hasattr(owner, "bl_rna") else owner
    return next(item.identifier for item in rna.properties[property_name].enum_items
                if item.identifier == wanted)


spec = importlib.util.spec_from_file_location("silueta_motion_v3", ROOT / "tools/silueta_motion_v3.py")
motion = importlib.util.module_from_spec(spec)
spec.loader.exec_module(motion)
scene = bpy.data.scenes.new(NAME)
collection = bpy.data.collections.new(NAME)
scene.collection.children.link(collection)
scene.render.fps = motion.FPS
scene.unit_settings.scale_length = 1
scene["source_forward"] = "-Y"
scene["runtime_damage"] = "None: original visual rig only; server owns gameplay."


def make_material(name, color, emission=0):
    mat = bpy.data.materials.new("SiluetaV3_" + name)
    mat.use_nodes = True
    shader = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = .93
    if emission:
        shader.inputs["Emission Color"].default_value = (*color, 1)
        shader.inputs["Emission Strength"].default_value = emission
    mat.diffuse_color = (*color, 1)
    return mat


materials = [make_material("BarkShadow", (.013, .019, .022)),
             make_material("DryBark", (.047, .057, .055)),
             make_material("DeadFoliage", (.025, .038, .033)),
             make_material("RecessedViolet", (.26, .032, .48), 1.7)]
source = ast.parse((ROOT / "tools/build-silueta-asset.py").read_text(encoding="utf-8"))
mesh_class = next(node for node in source.body if isinstance(node, ast.ClassDef) and node.name == "Mesh")
exec(compile(ast.Module(body=[mesh_class], type_ignores=[]), "owned-v2-Mesh-helper", "exec"), globals())
reference_scale = json.loads((OUT / "silueta-prototype-v2-report.json").read_text())["body_center_m"][2] / 1.33


def warp(point, part=""):
    x, y, z = point
    original_z = z
    x += .018 * math.sin(z * 3)
    y -= .22 * max(z - .85, 0) ** 1.25
    if part == "Body" and z > .76:
        x *= .83
    if part.startswith("Arm"):
        z -= .07 * max(1.5 - z, 0)
        x *= 1.035 if part.endswith("Left") else .96
    if part == "BranchCrown" and abs(x) > .24:
        x *= 1.02 if x < 0 else .88
        z += (.045 if x < 0 else -.11) * min(abs(x), .7) / .7
        y += .055 * math.sin(abs(x) * 16 + original_z)
    return Vector((x, y, z))


meshes = {}
for part in ("Body", "ArmLeft", "ArmRight", "BranchCrown", "RaggedMantle"):
    original = bpy.data.objects["Silueta_" + part]
    obj = bpy.data.objects.new("SiluetaV3_" + part, original.data.copy())
    collection.objects.link(obj)
    obj.data.name = obj.name + "Mesh"
    obj.data.materials.clear()
    for mat in materials:
        obj.data.materials.append(mat)
    for vertex in obj.data.vertices:
        v = vertex.co.copy()
        if part == "RaggedMantle":
            leaf, corner = divmod(vertex.index, 5)
            v.x += .027 * math.sin(leaf * 2.71)
            v.z += .04 * math.sin(leaf * 1.73)
            if corner == 2:
                v.z -= .04 + .095 * (.5 + .5 * math.sin(leaf * 3.17))
                v.x += .035 * math.cos(leaf)
        vertex.co = warp(v, part)
    meshes[part] = obj


def new_part(mesh, part):
    obj = mesh.object("V3_" + part)
    obj.name = "SiluetaV3_" + part
    obj.data.name = obj.name + "Mesh"
    for vertex in obj.data.vertices:
        vertex.co = warp(vertex.co * reference_scale, part)
    meshes[part] = obj
    return obj


head = Mesh()
head.loft([(0, .045, 1.72, .045, .035), (0, .035, 1.86, .135, .078),
           (0, .025, 2.015, .137, .08), (0, .04, 2.10, .07, .055)], 8)
for side in (-1, 1):
    # Thin irregular socket rims stand off from the recessed cranium, not angry cartoon brows.
    head.branch([(side * .018, -.112, 1.97), (side * .092, -.12, 1.99),
                 (side * .153, -.075, 1.96)], [.017, .023, .012], 5, 1)
    head.branch([(side * .145, -.082, 1.935), (side * .112, -.132, 1.845),
                 (side * .035, -.12, 1.76)], [.026, .022, .006], 5, 1)
head.branch([(0, -.13, 1.97), (0, -.165, 1.88), (0, -.15, 1.82)], [.021, .018, .005], 5)
new_part(head, "Head")
eyes = Mesh()
for side in (-1, 1):
    eyes.shell([(side * .051, -.087, 1.947), (side * .108, -.084, 1.95),
                (side * .091, -.094, 1.928), (side * .059, -.094, 1.93),
                (side * .078, -.075, 1.939)],
               [(0, 1, 2, 3), (0, 4, 1), (1, 4, 2), (2, 4, 3), (3, 4, 0)], 3)
new_part(eyes, "Eyes")
neck = Mesh()
neck.loft([(0, .02, 1.65, .095, .09), (0, -.005, 1.78, .075, .065),
           (0, -.015, 1.88, .06, .05)], 7)
new_part(neck, "Neck")
ridges = Mesh()
for side in (-1, 1):
    for row in range(4):
        z = 1.31 + row * .092
        ridges.branch([(side * .045, -.18, z), (side * (.18 + row * .035), -.15, z + .05),
                       (side * (.23 + row * .04), -.05, z + .065)], [.018, .014, .005], 4, 1)
new_part(ridges, "BarkRidges")
height = max(v.co.z for obj in meshes.values() for v in obj.data.vertices)
size_factor = 2.4 / height
for obj in meshes.values():
    for v in obj.data.vertices:
        v.co *= size_factor
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def rest(point, part=""):
    return warp(Vector(point) * reference_scale, part) * size_factor


armature = bpy.data.armatures.new("SiluetaV3_CustomSkeleton")
rig = bpy.data.objects.new("SiluetaV3_Rig", armature)
collection.objects.link(rig)
vl = scene.view_layers[0]
vl.objects.active = rig
rig.select_set(True, view_layer=vl)
bone_specs = {
    "Root": ((0, 0, 0), (0, 0, .20), None, ""),
    "Pelvis": ((0, .03, .89), (0, .02, 1.10), "Root", "Body"),
    "Spine": ((0, .02, 1.10), (0, .02, 1.42), "Pelvis", "Body"),
    "Chest": ((0, .02, 1.42), (0, .02, 1.72), "Spine", "Body"),
    "Neck": ((0, .02, 1.72), (0, -.015, 1.87), "Chest", ""),
    "Head": ((0, -.015, 1.87), (0, .02, 2.09), "Neck", ""),
}
for side, suffix, part in ((-1, ".L", "ArmLeft"), (1, ".R", "ArmRight")):
    shoulder, elbow, wrist, fingers = ((side * .39, .01, 1.63), (side * .61, -.015, 1.29),
                                      (side * .71, -.16, .68), (side * .71, -.22, .48))
    bone_specs.update({"UpperArm" + suffix: (shoulder, elbow, "Chest", part),
                       "Forearm" + suffix: (elbow, wrist, "UpperArm" + suffix, part),
                       "Hand" + suffix: (wrist, fingers, "Forearm" + suffix, part),
                       "Thigh" + suffix: ((side * .15, .03, .99), (side * .22, .055, .60), "Pelvis", "Body"),
                       "Shin" + suffix: ((side * .22, .055, .60), (side * .20, .02, .11), "Thigh" + suffix, "Body"),
                       "Foot" + suffix: ((side * .20, .02, .11), (side * .20, -.23, .045), "Shin" + suffix, "Body")})
with bpy.context.temp_override(scene=scene, view_layer=vl, object=rig, active_object=rig,
                               selected_objects=[rig], selected_editable_objects=[rig]):
    bpy.ops.object.mode_set(mode=enum_value(bpy.ops.object.mode_set.get_rna_type(), "mode", "EDIT"))
    try:
        for name in motion.BONES:
            head_co, tail_co, parent, part = bone_specs[name]
            bone = armature.edit_bones.new(name)
            bone.head, bone.tail = rest(head_co, part), rest(tail_co, part)
            if parent:
                bone.parent = armature.edit_bones[parent]
            bone.use_connect = False
    finally:
        bpy.ops.object.mode_set(mode=enum_value(bpy.ops.object.mode_set.get_rna_type(), "mode", "OBJECT"))


def weights(obj, indices, values):
    for bone, weight in values.items():
        group = obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
        group.add(list(indices), weight, "REPLACE")


for part, obj in meshes.items():
    obj.parent = rig
    modifier = obj.modifiers.new("CustomSkeleton", enum_value(bpy.types.Modifier, "type", "ARMATURE"))
    modifier.object = rig
    if part == "Body":
        for row, values in enumerate([{"Pelvis": 1}, {"Pelvis": .35, "Spine": .65},
                                      {"Spine": .35, "Chest": .65}, {"Chest": 1}, {"Chest": 1}]):
            weights(obj, range(row * 8, row * 8 + 8), values)
        for start, suffix in ((40, ".L"), (86, ".R")):
            for row, values in enumerate([{"Thigh" + suffix: 1},
                                          {"Thigh" + suffix: .45, "Shin" + suffix: .55},
                                          {"Shin" + suffix: .85, "Foot" + suffix: .15}]):
                weights(obj, range(start + row * 6, start + row * 6 + 6), values)
            weights(obj, range(start + 18, start + 46), {"Foot" + suffix: 1})
    elif part.startswith("Arm"):
        suffix = ".L" if part == "ArmLeft" else ".R"
        for row, values in enumerate([{"UpperArm" + suffix: 1},
                                      {"UpperArm" + suffix: .45, "Forearm" + suffix: .55},
                                      {"Forearm" + suffix: 1}, {"Hand" + suffix: 1}]):
            weights(obj, range(row * 6, row * 6 + 6), values)
        weights(obj, range(24, len(obj.data.vertices)), {"Hand" + suffix: 1})
    else:
        bone = "Head" if part in ("Head", "Eyes", "BranchCrown") else "Neck" if part == "Neck" else "Chest"
        weights(obj, range(len(obj.data.vertices)), {bone: 1})
    obj["original_art"] = True
    obj["runtime_role"] = "Visual only; preserve server-owned gameplay proxy."

rig.animation_data_create()
actions = {}
for name, duration in motion.DURATIONS.items():
    action = bpy.data.actions.new("SiluetaV3_" + name)
    action.use_fake_user = True
    rig.animation_data.action = action
    end = round(duration * motion.FPS) + 1
    for frame in range(1, end + 1):
        profile = motion.pose(name, (frame - 1) / (end - 1))
        for bone in rig.pose.bones:
            bone.rotation_mode = enum_value(bone, "rotation_mode", "XYZ")
            bone.rotation_euler = profile[bone.name]
            bone.location = (0, 0, 0)
            bone.scale = (1, 1, 1)
            bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone.name)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:
                        key.interpolation = enum_value(key, "interpolation", "LINEAR")
    action["duration_seconds"] = duration
    action["in_place"] = True
    action["loop"] = name in ("Idle", "Locomotion")
    action["damage_authority"] = "None"
    actions[name] = action

world = bpy.data.worlds.new("SiluetaV3_PreviewWorld")
world.use_nodes = True
background = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
background.inputs["Color"].default_value = (.021, .026, .032, 1)
background.inputs["Strength"].default_value = .28
scene.world = world
camera_data = bpy.data.cameras.new("SiluetaV3_PreviewCamera")
camera = bpy.data.objects.new(camera_data.name, camera_data)
collection.objects.link(camera)
camera_data.type = enum_value(camera_data, "type", "ORTHO")
camera_data.ortho_scale = 2.85
scene.camera = camera


def point_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


for name, position, power, color, size in [
    ("Key", (-2.5, -4, 4.5), 570, (.67, .80, .83), 3),
    ("Fill", (3, -1.5, 2), 135, (.45, .54, .58), 3),
    ("Rim", (.7, 2.2, 4), 690, (.48, .34, .68), 2),
]:
    light = bpy.data.lights.new("SiluetaV3_" + name, enum_value(bpy.types.Light, "type", "AREA"))
    light.energy, light.color, light.size = power, color, size
    obj = bpy.data.objects.new(light.name, light)
    collection.objects.link(obj)
    obj.location = position
    point_at(obj, (0, -.1, 1.25))
scene.render.resolution_x, scene.render.resolution_y = 1000, 1100
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = enum_value(scene.render.image_settings, "file_format", "PNG")
scene.render.film_transparent = False
scene.frame_start, scene.frame_end = 1, 91
rig.animation_data.action = actions["Idle"]
scene.frame_set(1)
camera.location = (3.1, -6.5, 2.7)
point_at(camera, (0, -.1, 1.20))
scene.render.filepath = str(OUT / "silueta-horror-rig-v3-front.png")

# Defer persistence/export until the separate evaluator has checked the live rig.
assert context_snapshot() == initial_context
final_objects = existing_snapshot()
assert all(final_objects[name] == value for name, value in initial_objects.items())
scene["initial_context_json"] = json.dumps(initial_context)
scene["original_objects_preserved"] = True
print(json.dumps({"scene": scene.name, "rig": rig.name, "bones": list(armature.bones.keys()),
                  "meshes": list(meshes), "actions": [a.name for a in actions.values()],
                  "initial_context": initial_context, "original_objects_preserved": True}, indent=2))

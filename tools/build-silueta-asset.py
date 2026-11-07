"""Build an original static Silueta art prototype in an isolated Blender scene.

Run only after reviewing this script, through the authorized Blender MCP session.
No external code, asset downloads, export, upload, or existing-scene edits.
"""

import json
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path("C:/Users/Jesus/Documents/ChatGPT/roblox-terror")
BLEND = ROOT / "assets/blender/silueta-prototype-v2.blend"
PREVIEW = ROOT / "assets/blender/silueta-prototype-v2-preview.png"
REPORT = ROOT / "assets/blender/silueta-prototype-v2-report.json"
NAME = "Wildbound_Silueta_Prototype"


def context_state():
    return {
        "file": bpy.data.filepath,
        "scene": bpy.context.scene.name,
        "mode": bpy.context.mode,
        "active": bpy.context.view_layer.objects.active.name
        if bpy.context.view_layer.objects.active else None,
        "selection": sorted(obj.name for obj in bpy.context.selected_objects),
    }


assert NAME not in bpy.data.collections, "Owned collection already exists; inspect before rerunning."
assert NAME not in bpy.data.scenes, "Owned scene already exists; inspect before rerunning."
assert not any(p.exists() for p in (BLEND, PREVIEW, REPORT)), "Do not overwrite existing outputs."
initial_context = context_state()
original_objects = {
    obj.name: (obj.as_pointer(), tuple(tuple(row) for row in obj.matrix_world),
               obj.data.as_pointer() if obj.data else None,
               tuple(mat.as_pointer() for mat in obj.data.materials) if obj.type == "MESH" else ())
    for obj in bpy.data.objects
}
scene = bpy.data.scenes.new(NAME)
collection = bpy.data.collections.new(NAME)
scene.collection.children.link(collection)
scene.unit_settings.system = next(
    item.identifier for item in scene.unit_settings.bl_rna.properties["system"].enum_items
    if item.identifier == "METRIC"
)
scene.unit_settings.scale_length = 1.0
scene["asset_status"] = "Original static visual prototype; not rigged or imported."
scene["forward_axis"] = "-Y"
scene["target_height_m"] = 2.4
scene["studs_per_meter_preview_assumption"] = 1 / 0.28


def material(name, color, emission=0):
    mat = bpy.data.materials.new("Silueta_" + name)
    mat.use_nodes = True
    shader = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = 0.88
    if emission:
        shader.inputs["Emission Color"].default_value = (*color, 1)
        shader.inputs["Emission Strength"].default_value = emission
    mat.diffuse_color = (*color, 1)
    return mat


materials = [
    material("DeepBark", (0.035, 0.044, 0.048)),
    material("BarkRidge", (0.088, 0.102, 0.099)),
    material("MossMantle", (0.048, 0.073, 0.067)),
    material("VioletEyes", (0.48, 0.12, 0.88), 3.0),
]


class Mesh:
    def __init__(self):
        self.vertices, self.faces, self.indices = [], [], []

    def shell(self, vertices, faces, mat=0):
        start = len(self.vertices)
        self.vertices.extend(vertices)
        self.faces.extend(tuple(start + i for i in face) for face in faces)
        self.indices.extend([mat] * len(faces))

    def loft(self, rings, sides=8, mat=0):
        # Horizontal closed rings, used for the faceted trunk/head.
        vertices = [
            (x + rx * math.cos(2 * math.pi * i / sides),
             y + ry * math.sin(2 * math.pi * i / sides), z)
            for x, y, z, rx, ry in rings for i in range(sides)
        ]
        faces = [tuple(reversed(range(sides)))]
        for row in range(len(rings) - 1):
            for i in range(sides):
                a, b = row * sides + i, row * sides + (i + 1) % sides
                faces.append((a, b, b + sides, a + sides))
        faces.append(tuple((len(rings) - 1) * sides + i for i in range(sides)))
        self.shell(vertices, faces, mat)

    def branch(self, points, radii, sides=5, mat=0):
        vertices = []
        for row, point in enumerate(points):
            tangent = Vector(points[min(row + 1, len(points) - 1)]) - Vector(points[max(row - 1, 0)])
            tangent.normalize()
            basis = tangent.cross(Vector((0, 1, 0))).normalized()
            if basis.length < 0.1:
                basis = tangent.cross(Vector((1, 0, 0))).normalized()
            other = tangent.cross(basis).normalized()
            for i in range(sides):
                angle = 2 * math.pi * i / sides
                v = Vector(point) + radii[row] * (basis * math.cos(angle) + other * math.sin(angle))
                vertices.append(tuple(v))
        faces = [tuple(reversed(range(sides)))]
        for row in range(len(points) - 1):
            for i in range(sides):
                a, b = row * sides + i, row * sides + (i + 1) % sides
                faces.append((a, b, b + sides, a + sides))
        faces.append(tuple((len(points) - 1) * sides + i for i in range(sides)))
        self.shell(vertices, faces, mat)

    def leaf(self, center, width, length, lean, mat=2):
        x, y, z = center
        self.shell([
            (x - width, y, z), (x + width, y, z), (x + lean, y - .045, z - length),
            (x, y - .065, z - .08), (x, y + .045, z - .08),
        ], [(0, 3, 1), (1, 3, 2), (2, 3, 0), (1, 4, 0), (2, 4, 1), (0, 4, 2)], mat)

    def object(self, name):
        data = bpy.data.meshes.new("Silueta_" + name + "Mesh")
        data.from_pydata(self.vertices, [], self.faces)
        data.update()
        bm = bmesh.new()
        bm.from_mesh(data)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(data)
        bm.free()
        for mat in materials:
            data.materials.append(mat)
        for polygon, index in zip(data.polygons, self.indices):
            polygon.material_index = index
        # Per-face planar UVs are editable placeholders, not a textured/atlased unwrap.
        uv = data.uv_layers.new(name="PrototypePlanarUV")
        for polygon in data.polygons:
            axis = max(range(3), key=lambda i: abs(polygon.normal[i]))
            axes = [i for i in range(3) if i != axis]
            for loop_index in polygon.loop_indices:
                v = data.vertices[data.loops[loop_index].vertex_index].co
                uv.data[loop_index].uv = (v[axes[0]], v[axes[1]])
        obj = bpy.data.objects.new("Silueta_" + name, data)
        collection.objects.link(obj)
        return obj


body = Mesh()
body.loft([(0, .03, .87, .20, .15), (0, .02, 1.13, .23, .17),
           (0, .02, 1.48, .39, .19), (0, .025, 1.68, .46, .20),
           (0, .02, 1.79, .22, .13)], mat=0)
for s in (-1, 1):
    body.branch([(s * .15, .03, .99), (s * .22, .055, .60), (s * .20, .02, .15)],
                [.13, .095, .065], 6)
    body.loft([(s * .20, -.06, 0, .105, .18), (s * .20, -.06, .12, .085, .14)], 6)
    for offset in (-.07, .035):
        body.branch([(s * .20 + offset, -.13, .07), (s * .20 + offset, -.29, .02)],
                    [.035, .009], 4, 1)
body.object("Body")

head = Mesh()
head.loft([(0, -.045, 1.73, .10, .085), (0, -.065, 1.85, .175, .16),
           (0, -.035, 2.02, .19, .155), (0, .01, 2.11, .105, .10)], 8)
for s in (-1, 1):
    head.branch([(s * .025, -.205, 1.98), (s * .16, -.17, 2.005)], [.025, .045], 4, 1)
head.object("Head")

eyes = Mesh()
for s in (-1, 1):
    eyes.shell([(s * .032, -.221, 1.955), (s * .132, -.195, 1.976),
                (s * .111, -.215, 1.927), (s * .051, -.23, 1.929),
                (s * .083, -.199, 1.95)],
               [(0, 1, 2, 3), (0, 4, 1), (1, 4, 2), (2, 4, 3), (3, 4, 0)], 3)
eyes.object("Eyes")

for s, side in ((-1, "Left"), (1, "Right")):
    arm = Mesh()
    arm.branch([(s * .39, .01, 1.63), (s * .61, -.015, 1.29),
                (s * .67, -.105, .86), (s * .71, -.16, .68)], [.14, .115, .085, .075], 6)
    for finger in range(3):
        x = s * (.655 + finger * .055)
        arm.branch([(x, -.17, .74), (x + s * .025, -.19, .56),
                    (x + s * .01, -.22, .48 + .025 * abs(1 - finger))], [.027, .021, .008], 4)
    arm.branch([(s * .65, -.16, .80), (s * .60, -.24, .70)], [.03, .012], 4)
    arm.object("Arm" + side)

antlers = Mesh()
for s in (-1, 1):
    extra = .07 if s == -1 else 0
    antlers.branch([(s * .13, .035, 2.04), (s * .32, .035, 2.18),
                    (s * .53, .055, 2.21), (s * .75, .085, 2.36),
                    (s * (.79 + extra), .07, 2.48 + extra)], [.075, .065, .043, .027, .006], 5)
    antlers.branch([(s * .32, .035, 2.17), (s * .36, .065, 2.39),
                    (s * .29, .09, 2.49)], [.044, .027, .005], 5)
    antlers.branch([(s * .52, .055, 2.22), (s * .59, .04, 2.43),
                    (s * .54, .06, 2.55 - extra)], [.034, .022, .004], 5)
    antlers.branch([(s * .70, .07, 2.33), (s * .89, .06, 2.35),
                    (s * .96, .09, 2.43)], [.026, .017, .004], 5)
antlers.object("BranchCrown")

mantle = Mesh()
for s in (-1, 1):
    for i in range(6):
        x = s * (.13 + i * .071)
        mantle.leaf((x, -.16 + i * .015, 1.77 - .032 * i),
                    .10, .29 + .07 * (i % 3), s * .11, 2 if i % 3 else 1)
        mantle.leaf((x, .17 - i * .008, 1.73 - .04 * i), .105, .38 + .08 * (i % 2), s * .10)
    for i in range(3):
        mantle.leaf((s * (.23 + .06 * i), -.16, 1.43 - .09 * i), .075, .28, s * .06)
mantle.object("RaggedMantle")

meshes = [obj for obj in collection.objects if obj.type == "MESH"]
highest = max(v.co.z for obj in meshes for v in obj.data.vertices)
scale = 2.4 / highest
for obj in meshes:
    for vertex in obj.data.vertices:
        vertex.co *= scale
    if obj.name == "Silueta_Body":
        # Front/back render QA: overlap ankle rings with the closed foot shells.
        for index in (*range(52, 58), *range(98, 104)):
            obj.data.vertices[index].co.z -= .04 * scale
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(obj.data)
        bm.free()
    obj["role"] = obj.name.removeprefix("Silueta_")
    obj["forward_axis"] = "-Y"
    obj["static_visual_only"] = True
    obj.data.update()

root = bpy.data.objects.new("Silueta_FeetOrigin", None)
collection.objects.link(root)
root["pivot"] = "Ground between feet; Z-up, forward -Y."
for obj in meshes:
    obj.parent = root

world = bpy.data.worlds.new("Silueta_PreviewWorld")
world.use_nodes = True
background = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
background.inputs["Color"].default_value = (.026, .033, .043, 1)
background.inputs["Strength"].default_value = .4
scene.world = world


def point_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


camera_data = bpy.data.cameras.new("Silueta_PreviewCamera")
camera = bpy.data.objects.new("Silueta_PreviewCamera", camera_data)
collection.objects.link(camera)
camera.location = (3.2, -6.5, 2.9)
point_at(camera, (0, 0, 1.22))
camera_data.type = next(i.identifier for i in camera_data.bl_rna.properties["type"].enum_items
                        if i.identifier == "ORTHO")
camera_data.ortho_scale = 2.95
scene.camera = camera
for name, position, energy, color, size in [
    ("Key", (-3, -4, 5), 700, (.82, .90, 1), 4),
    ("Fill", (3, -2, 2.5), 340, (.56, .66, .80), 3),
    ("Rim", (1, 2, 4), 850, (.60, .36, 1), 2),
]:
    area_type = next(i.identifier for i in bpy.types.Light.bl_rna.properties["type"].enum_items
                     if i.identifier == "AREA")
    light = bpy.data.lights.new("Silueta_Preview" + name, area_type)
    disk_shape = next(i.identifier for i in light.bl_rna.properties["shape"].enum_items
                      if i.identifier == "DISK")
    light.energy, light.color, light.shape, light.size = energy, color, disk_shape, size
    obj = bpy.data.objects.new(light.name, light)
    collection.objects.link(obj)
    obj.location = position
    point_at(obj, (0, 0, 1.3))

scene.render.resolution_x, scene.render.resolution_y = 1000, 1100
scene.render.resolution_percentage = 100
scene.render.film_transparent = False
scene.render.image_settings.file_format = next(
    i.identifier for i in scene.render.image_settings.bl_rna.properties["file_format"].enum_items
    if i.identifier == "PNG"
)
BLEND.parent.mkdir(parents=True, exist_ok=True)
scene.render.filepath = str(PREVIEW)

objects_report = []
for obj in meshes:
    data = obj.data
    data.calc_loop_triangles()
    bm = bmesh.new()
    bm.from_mesh(data)
    objects_report.append({
        "name": obj.name, "vertices": len(data.vertices), "polygons": len(data.polygons),
        "triangles": len(data.loop_triangles),
        "nonmanifold_edges": sum(not edge.is_manifold for edge in bm.edges),
        "boundary_edges": sum(edge.is_boundary for edge in bm.edges),
        "loose_vertices": sum(not v.link_edges for v in bm.verts),
        "degenerate_faces": sum(face.calc_area() < 1e-10 for face in bm.faces),
        "signed_volume_m3": bm.calc_volume(signed=True),
        "uv_layer": data.uv_layers.active.name,
    })
    bm.free()
world_vertices = [obj.matrix_world @ v.co for obj in meshes for v in obj.data.vertices]
minimum = [min(v[i] for v in world_vertices) for i in range(3)]
maximum = [max(v[i] for v in world_vertices) for i in range(3)]
report = {
    "asset": NAME, "static_only": True, "rigged": False, "animated": False,
    "forward": "-Y", "up": "+Z", "origin": [0, 0, 0],
    "world_vertex_min_m": minimum, "world_vertex_max_m": maximum,
    "world_vertex_dimensions_m": [maximum[i] - minimum[i] for i in range(3)],
    "height_studs_at_0_28_m_per_stud": (maximum[2] - minimum[2]) / .28,
    "body_center_m": [0, .02 * scale, 1.33 * scale],
    "triangles": sum(item["triangles"] for item in objects_report),
    "materials": [mat.name for mat in materials], "objects": objects_report,
    "blender_version": bpy.app.version_string, "scene": scene.name,
    "initial_context": initial_context, "export_status": "Not exported or uploaded; approved directory and consent pending.",
    "notes": ["Original hand-authored procedural geometry inspired by authorized concept tone, not copied mesh.",
              "Disconnected overlapping closed shells; no welded deformation topology or collision hull.",
              "Per-face planar UV placeholders only; opaque color materials; runtime owns reveal transparency.",
              "Triangle target is a provisional art budget, not measured mobile performance."],
}
assert report["triangles"] < 2500
assert all(item["nonmanifold_edges"] == item["degenerate_faces"] == item["loose_vertices"] == 0
           for item in objects_report)
assert all(item["signed_volume_m3"] > 0 for item in objects_report), "Outward closed-shell normals required."
assert abs(report["world_vertex_dimensions_m"][2] - 2.4) < 1e-5
for name, state in original_objects.items():
    obj = bpy.data.objects[name]
    assert state == (obj.as_pointer(), tuple(tuple(row) for row in obj.matrix_world),
                     obj.data.as_pointer() if obj.data else None,
                     tuple(mat.as_pointer() for mat in obj.data.materials) if obj.type == "MESH" else ())
assert context_state() == initial_context
bpy.ops.render.render(scene=scene.name, write_still=True)
assert context_state() == initial_context, "Original context changed during render."
bpy.data.libraries.write(str(BLEND), {scene}, fake_user=True, compress=True)
assert BLEND.is_file() and PREVIEW.is_file()
report["original_context_preserved"] = context_state() == initial_context
report["blend_bytes"], report["preview_bytes"] = BLEND.stat().st_size, PREVIEW.stat().st_size
REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report, indent=2))

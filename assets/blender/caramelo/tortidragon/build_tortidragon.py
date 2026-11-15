"""Tortidragon, the cake-and-strawberry dragon of the Caramelo biome (odd/tasks/wildbound-caramelo.md, CA2).

Pack: 03_PERSONAJES/03_TORTIDRAGON.md and 01_REFERENCIAS/CRIATURAS/03_Tortidragon_Turnaround.png.
Low-poly, faceted quadruped about 11 studs tall: honey body, red chest and jaw, pink cream crest and back,
strawberry horns, a cream tail curling up. The side emblem of the reference is left out on purpose.

Units: 1 Blender unit = 1 stud. The creature faces -Y; its left side is +X. Roblox reads the FBX as
X = -x, Y = z, Z = y, so its front is -Z there.

Every mesh is skinned, and every vertex belongs to exactly one bone (rigid skinning): the importer keeps
only the bones a skinned vertex uses, so each of the 24 bones owns at least one piece (Root owns a small
gem hidden inside the torso). No mesh is named like a bone: the importer would hang that bone under it.

Run inside Blender:  exec(open(r"<repo>/assets/blender/caramelo/tortidragon/build_tortidragon.py").read())
It rebuilds the scene from nothing and, with EXPORT set, writes the FBX for upload.
"""
import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

EXPORT = globals().get("TORTI_EXPORT_PATH")

BONES = [
    # name, head, tail, parent
    ("Root", (0, 0, 0), (0, 0, 1), None),
    ("Pelvis", (0, 1.9, 3.5), (0, 0.6, 3.6), "Root"),
    ("Spine", (0, 0.6, 3.6), (0, -1.4, 3.9), "Pelvis"),
    ("Neck_01", (0, -1.5, 4.1), (0, -2.0, 5.4), "Spine"),
    ("Neck_02", (0, -2.0, 5.4), (0, -2.4, 6.6), "Neck_01"),
    ("Head", (0, -2.5, 7.0), (0, -4.0, 7.4), "Neck_02"),
    ("Jaw", (0, -2.7, 7.0), (0, -4.0, 6.9), "Head"),
    ("CreamCrest", (0, -2.6, 8.6), (0, -2.4, 10.4), "Head"),
    ("Strawberry_L", (0.85, -2.45, 9.0), (1.25, -2.35, 10.4), "Head"),
    ("Strawberry_R", (-0.85, -2.45, 9.0), (-1.25, -2.35, 10.4), "Head"),
    ("Cheek_L", (1.0, -3.6, 7.15), (1.4, -3.5, 7.2), "Head"),
    ("Cheek_R", (-1.0, -3.6, 7.15), (-1.4, -3.5, 7.2), "Head"),
    ("Strawberry_Back", (0, 0.1, 5.0), (0, 0.15, 6.0), "Spine"),
    ("FrontLeg_L_Upper", (1.1, -1.3, 3.0), (1.1, -1.3, 1.6), "Spine"),
    ("FrontLeg_L_Lower", (1.1, -1.3, 1.6), (1.1, -1.4, 0.2), "FrontLeg_L_Upper"),
    ("FrontLeg_R_Upper", (-1.1, -1.3, 3.0), (-1.1, -1.3, 1.6), "Spine"),
    ("FrontLeg_R_Lower", (-1.1, -1.3, 1.6), (-1.1, -1.4, 0.2), "FrontLeg_R_Upper"),
    ("BackLeg_L_Upper", (1.15, 2.1, 3.0), (1.15, 2.2, 1.6), "Pelvis"),
    ("BackLeg_L_Lower", (1.15, 2.2, 1.6), (1.15, 2.1, 0.2), "BackLeg_L_Upper"),
    ("BackLeg_R_Upper", (-1.15, 2.1, 3.0), (-1.15, 2.2, 1.6), "Pelvis"),
    ("BackLeg_R_Lower", (-1.15, 2.2, 1.6), (-1.15, 2.1, 0.2), "BackLeg_R_Upper"),
    ("Tail_01", (0, 2.9, 3.9), (0, 3.9, 4.7), "Pelvis"),
    ("Tail_02", (0, 3.9, 4.7), (0, 4.5, 5.8), "Tail_01"),
    ("Tail_03", (0, 4.5, 5.8), (0, 4.1, 6.9), "Tail_02"),
]

COLOURS = {
    "Body": "#F2A93B", "Belly": "#D9343A", "Cream": "#F4B8CF", "Berry": "#E0263C", "Leaf": "#4CAF50",
    "Eye": "#9B3FC8", "Shine": "#FFFFFF", "Claw": "#5A3220", "SprinkleA": "#3EC9D6", "SprinkleB": "#F6C343",
}


def hex_rgba(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c) + (1.0,)


class Piece:
    """One mesh of one colour, built from primitives; every primitive is pinned to one bone."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.deform = self.bm.verts.layers.deform.verify()
        self.groups = []

    def _pin(self, verts, bone):
        if bone not in self.groups:
            self.groups.append(bone)
        index = self.groups.index(bone)
        for v in verts:
            v[self.deform][index] = 1.0

    def box(self, bone, centre, size, rot=(0, 0, 0)):
        m = Matrix.Translation(centre) @ euler(rot) @ Matrix.Diagonal((size[0], size[1], size[2], 1))
        res = bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)
        self._pin(res["verts"], bone)

    def gem(self, bone, centre, scale, subdiv=1):
        m = Matrix.Translation(centre) @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1))
        res = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=1.0, matrix=m)
        self._pin(res["verts"], bone)

    def prism(self, bone, a, b, r1, r2, segments=6):
        a, b = Vector(a), Vector(b)
        axis = b - a
        rot = axis.to_track_quat("Z", "Y").to_matrix().to_4x4()
        m = Matrix.Translation((a + b) / 2) @ rot
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segments,
                                    radius1=r1, radius2=r2, depth=axis.length, matrix=m)
        self._pin(res["verts"], bone)


def euler(rot):
    from mathutils import Euler
    return Euler(tuple(math.radians(a) for a in rot), "XYZ").to_matrix().to_4x4()


def mirror(x, side):
    return x if side == "L" else -x


def build_pieces():
    p = {name: Piece(name) for name in COLOURS}
    body, belly, cream, berry, leaf = p["Body"], p["Belly"], p["Cream"], p["Berry"], p["Leaf"]
    # torso: chest on the spine, hips on the pelvis; Root owns a gem hidden inside
    body.box("Spine", (0, -0.6, 3.7), (2.9, 2.7, 2.2))
    body.box("Pelvis", (0, 1.6, 3.55), (3.0, 2.4, 2.1))
    body.gem("Root", (0, 0.4, 3.4), (0.2, 0.2, 0.2), 0)
    # neck and head
    body.prism("Neck_01", (0, -1.4, 3.9), (0, -2.0, 5.5), 1.1, 0.95)
    body.prism("Neck_02", (0, -2.0, 5.4), (0, -2.5, 6.9), 0.95, 0.9)
    body.box("Head", (0, -2.9, 7.6), (2.3, 2.2, 1.6))
    body.box("Head", (0, -4.1, 7.45), (1.8, 1.5, 0.8))
    belly.box("Jaw", (0, -3.7, 6.85), (1.7, 2.0, 0.5))
    belly.box("Neck_01", (0, -2.55, 4.4), (0.85, 0.3, 1.5), (21.8, 0, 0))
    belly.box("Neck_02", (0, -3.05, 5.8), (0.8, 0.3, 1.4), (18.4, 0, 0))
    belly.box("Spine", (0, -0.2, 2.62), (1.6, 3.0, 0.2))
    for side in "LR":
        belly.box("Head", (mirror(1.17, side), -3.4, 7.2), (0.1, 1.6, 0.35))
        # the cheeks puff out sideways in the attack's tell
        body.gem("Cheek_%s" % side, (mirror(1.0, side), -3.6, 7.15), (0.32, 0.5, 0.38), 0)
        p["Eye"].gem("Head", (mirror(1.12, side), -3.1, 7.9), (0.18, 0.52, 0.52))
        p["Shine"].gem("Head", (mirror(1.26, side), -3.3, 8.05), (0.08, 0.13, 0.13), 0)
    # legs: shoulders and haunches on the upper bones, the lower leg and foot on the lower bone
    for side in "LR":
        x = mirror(1.1, side)
        body.gem("FrontLeg_%s_Upper" % side, (x, -1.3, 3.1), (0.7, 0.9, 0.9))
        body.box("FrontLeg_%s_Upper" % side, (x, -1.3, 2.3), (0.95, 1.0, 1.5))
        body.box("FrontLeg_%s_Lower" % side, (x, -1.35, 0.9), (0.85, 0.9, 1.4))
        body.box("FrontLeg_%s_Lower" % side, (x, -1.55, 0.25), (1.05, 1.3, 0.5))
        bx = mirror(1.15, side)
        body.gem("BackLeg_%s_Upper" % side, (bx, 2.1, 3.0), (0.8, 1.1, 1.1))
        body.box("BackLeg_%s_Upper" % side, (bx, 2.15, 2.3), (1.0, 1.1, 1.5))
        body.box("BackLeg_%s_Lower" % side, (bx, 2.15, 0.9), (0.9, 0.95, 1.4))
        body.box("BackLeg_%s_Lower" % side, (bx, 1.95, 0.25), (1.1, 1.35, 0.5))
        for bone, fx, fy in (("FrontLeg_%s_Lower" % side, x, -2.2), ("BackLeg_%s_Lower" % side, bx, 1.3)):
            for dx in (-0.28, 0, 0.28):
                p["Claw"].box(bone, (fx + dx, fy, 0.12), (0.2, 0.22, 0.24))
    # cream: head cap and crest, back frosting, drips and the curling tail
    cream.gem("Head", (0, -2.8, 8.5), (1.5, 1.7, 0.85))
    cream.prism("CreamCrest", (0, -2.6, 8.9), (0, -2.3, 10.6), 0.9, 0.1)
    cream.gem("CreamCrest", (0, -2.5, 9.5), (0.8, 0.8, 0.5))
    for x, y in ((1.2, -3.0), (-1.2, -3.0), (0.7, -4.0), (-0.7, -4.0), (0, -1.6)):
        cream.prism("Head", (x, y, 8.3), (x * 1.05, y - 0.1, 7.65), 0.25, 0.05, 5)
    cream.gem("Spine", (0, -0.4, 4.75), (1.7, 1.7, 0.55))
    cream.gem("Pelvis", (0, 1.5, 4.65), (1.7, 1.5, 0.55))
    for side in (1, -1):
        for bone, y in (("Spine", -1.0), ("Spine", 0.0), ("Pelvis", 1.2), ("Pelvis", 2.2)):
            cream.prism(bone, (1.5 * side, y, 4.6), (1.58 * side, y, 3.8), 0.28, 0.06, 5)
    cream.prism("Tail_01", (0, 2.8, 3.9), (0, 3.9, 4.7), 0.8, 0.7)
    cream.prism("Tail_02", (0, 3.9, 4.7), (0, 4.5, 5.8), 0.7, 0.6)
    cream.prism("Tail_03", (0, 4.5, 5.8), (0, 4.0, 6.95), 0.6, 0.1)
    cream.gem("Tail_03", (0, 4.35, 6.2), (0.65, 0.65, 0.6))
    # strawberries: two horns on the cream cap and one on the back
    for side, bone in (("L", "Strawberry_L"), ("R", "Strawberry_R")):
        x = mirror(0.85, side)
        berry.prism(bone, (x, -2.45, 9.0), (x + mirror(0.4, side), -2.35, 10.6), 0.5, 0.08)
        leaf.gem(bone, (x, -2.45, 9.0), (0.5, 0.5, 0.12), 0)
    berry.prism("Strawberry_Back", (0, 0.1, 5.0), (0, 0.15, 6.0), 0.55, 0.1)
    leaf.gem("Strawberry_Back", (0, 0.1, 5.0), (0.55, 0.55, 0.12), 0)
    # sprinkles on the cream (two colours)
    rng = random.Random(7)
    for i in range(22):
        mesh = p["SprinkleA"] if i % 2 == 0 else p["SprinkleB"]
        if i < 14:
            bone, c = ("Spine", (rng.uniform(-1.2, 1.2), rng.uniform(-1.4, 0.6), 5.25)) if i < 8 else \
                ("Pelvis", (rng.uniform(-1.2, 1.2), rng.uniform(1.0, 2.4), 5.15))
        else:
            bone, c = "Head", (rng.uniform(-1.1, 1.1), rng.uniform(-3.8, -2.0), 9.15)
        mesh.box(bone, c, (0.32, 0.09, 0.09), (0, 0, rng.uniform(0, 180)))
    return p


def own_scene():
    """A scene of its own, rebuilt from nothing each run; other scenes of the open file are not touched."""
    scene = bpy.data.scenes.get("Tortidragon") or bpy.data.scenes.new("Tortidragon")
    for o in list(scene.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.window.scene = scene
    return scene


def build():
    scene = own_scene()
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    arm_data = bpy.data.armatures.new("TortidragonRig")
    arm = bpy.data.objects.new("Tortidragon", arm_data)
    scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for name, head, tail, parent in BONES:
        eb = arm_data.edit_bones.new(name)
        eb.head, eb.tail = head, tail
        if parent:
            eb.parent = arm_data.edit_bones[parent]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    meshes = []
    for name, piece in build_pieces().items():
        me = bpy.data.meshes.new(name + "Mesh")
        piece.bm.to_mesh(me)
        piece.bm.free()
        obj = bpy.data.objects.new(name, me)
        scene.collection.objects.link(obj)
        for g in piece.groups:
            obj.vertex_groups.new(name=g)
        mat = bpy.data.materials.new(name + "Mat")
        mat.use_nodes = True
        bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs[0].default_value = hex_rgba(COLOURS[name])
        mat.diffuse_color = hex_rgba(COLOURS[name])
        me.materials.append(mat)
        for poly in me.polygons:
            poly.use_smooth = False
        obj.parent = arm
        mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
        meshes.append(obj)
    used = set()
    for obj in meshes:
        used.update(g.name for g in obj.vertex_groups)
    missing = [b[0] for b in BONES if b[0] not in used]
    assert not missing, "bones with no skinned vertex: %s" % missing
    return arm, meshes


def export(path, arm, meshes):
    bpy.ops.object.select_all(action="DESELECT")
    for o in [arm] + meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={"ARMATURE", "MESH"}, apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL", mesh_smooth_type="FACE", use_mesh_modifiers=False,
        add_leaf_bones=False, primary_bone_axis="Y", secondary_bone_axis="X", armature_nodetype="NULL",
        bake_anim=False, path_mode="AUTO")


ARM, MESHES = build()
STATS = {"bones": len(BONES), "meshes": len(MESHES),
         "verts": sum(len(m.data.vertices) for m in MESHES), "tris": sum(len(m.data.loop_triangles) or len(m.data.polygons) for m in MESHES)}
if EXPORT:
    export(EXPORT, ARM, MESHES)
    STATS["exported"] = EXPORT
print(STATS)

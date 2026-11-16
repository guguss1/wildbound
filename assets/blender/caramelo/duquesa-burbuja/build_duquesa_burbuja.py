"""Duquesa Burbuja, the bubblegum noble of the Caramelo biome (about 18 studs tall).

Original design: a round cream head, hair of glossy gum bubbles piled into a tall bun with one bubble floating
beside it, a tiara of three wrapped-candy drops, a bell dress of three scalloped gumdrop tiers (pink, darker pink,
magenta hem), a teal bow at the waist and long cream gloves. No legs: the hem hides them and she glides.

Units: 1 Blender unit = 1 stud. The creature faces -Y; its left side is +X; the hem rests on Z = 0. Roblox reads
the FBX as X = -x, Y = z, Z = y, so its front is -Z there.

Rigid skinning: every vertex belongs to exactly one bone, every bone owns at least one vertex (Root owns a small
gem hidden inside the dress), and no mesh is named like a bone.

Clips are authored as data (CLIPS below) and written to duquesa-burbuja-clips.json. Each pose value is
[dx, dy, dz, rx, ry, rz]: a translation in studs and XYZ Euler degrees (CFrame.Angles order, Rx * Ry * Rz) in
ROBLOX model axes (X = the creature's right, Y = up, -Z = its front), applied at the bone's head relative to its
rest pose, exactly like the Tortidragon family: Transform = rest:Inverse() * (T * R) * rest.

Run:  blender --background --python build_duquesa_burbuja.py
Set the environment variable DUQUESA_RENDER=0 to skip the preview renders.
"""
import json
import math
import os

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

SLUG = "duquesa-burbuja"
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
EXPORT = os.path.join(REPO, "assets", "exports", "caramelo", SLUG + "-v1.fbx")
RENDER = os.environ.get("DUQUESA_RENDER", "1") != "0"

BONES = [
    # name, head, tail, parent
    ("Root", (0, 0, 0), (0, 0, 1), None),
    ("Hips", (0, 0, 6.6), (0, 0, 9.1), "Root"),
    ("Torso", (0, 0, 9.1), (0, 0, 11.6), "Hips"),
    ("Head", (0, 0, 12.1), (0, 0, 14.2), "Torso"),
    ("HairBun", (0, 0.3, 15.3), (0, 0.3, 17.6), "Head"),
    ("FloatBubble", (2.9, 0.3, 16.5), (2.9, 0.3, 17.3), "Head"),
    ("Arm_L_Upper", (1.6, 0, 11.0), (2.2, -0.1, 9.0), "Torso"),
    ("Arm_L_Lower", (2.2, -0.1, 9.0), (2.3, -0.3, 6.9), "Arm_L_Upper"),
    ("Arm_R_Upper", (-1.6, 0, 11.0), (-2.2, -0.1, 9.0), "Torso"),
    ("Arm_R_Lower", (-2.2, -0.1, 9.0), (-2.3, -0.3, 6.9), "Arm_R_Upper"),
    ("Skirt_Front", (0, -1.5, 6.7), (0, -3.3, 0.4), "Hips"),
    ("Skirt_Back", (0, 1.5, 6.7), (0, 3.3, 0.4), "Hips"),
    ("Skirt_L", (1.5, 0, 6.7), (3.3, 0, 0.4), "Hips"),
    ("Skirt_R", (-1.5, 0, 6.7), (-3.3, 0, 0.4), "Hips"),
    ("Bow", (0, -1.4, 9.15), (0, -1.9, 9.15), "Torso"),
    # the lowest dress core: it rides the hips everywhere and only lifts in SitIdle so no column hangs under the seat
    ("Skirt_Core", (0, 0, 3.9), (0, 0, 0.4), "Hips"),
    # the teacup rests hidden inside the bodice (same parent, so it can never show) and is carried to the right
    # hand by a translation in SitIdle only
    ("Teacup", (0, 0, 10.05), (0, 0, 10.75), "Torso"),
]
CUP_BASE = (0, 0, 10.05)         # centre of the saucer underside in the rest pose
HAND_R = (-2.31, -0.31, 6.85)    # centre of the right hand in the rest pose
TIARA_SHIFT = (0, -0.15, 0.15)   # forward and up, so the side candies clear the hair cap

COLOURS = {
    "Skin": "#FFE6D6", "Hair": "#FF86BE", "HairDark": "#EE4C99", "DressA": "#FFB0D4", "DressB": "#F2569F",
    "DressC": "#CF2A86", "Glove": "#FFF4E2", "Gold": "#F6C343", "Teal": "#2EC4C6", "Eye": "#3A2033",
    "Shine": "#FFFFFF", "Blush": "#FF8BA6", "CupCream": "#FFF4E2", "CupRim": "#F2569F",
}


def hex_rgba(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c) + (1.0,)


def euler(rot):
    return Euler(tuple(math.radians(a) for a in rot), "XYZ").to_matrix().to_4x4()


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

    def gem(self, bone, centre, scale, subdiv=1, rot=(0, 0, 0)):
        m = Matrix.Translation(centre) @ euler(rot) @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1))
        res = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=1.0, matrix=m)
        self._pin(res["verts"], bone)

    def drop(self, bone, centre, scale, rot=(0, 0, 0), u=6, v=4):
        """A faceted gumdrop: a coarse UV sphere with its poles on Z."""
        m = Matrix.Translation(centre) @ euler(rot) @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1))
        res = bmesh.ops.create_uvsphere(self.bm, u_segments=u, v_segments=v, radius=1.0, matrix=m)
        self._pin(res["verts"], bone)

    def prism(self, bone, a, b, r1, r2, segments=6):
        a, b = Vector(a), Vector(b)
        axis = b - a
        rot = axis.to_track_quat("Z", "Y").to_matrix().to_4x4()
        m = Matrix.Translation((a + b) / 2) @ rot
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segments,
                                    radius1=r1, radius2=r2, depth=axis.length, matrix=m)
        self._pin(res["verts"], bone)


def ring(radius, angle, z):
    """A point around the body; angle 0 is the front (-Y), positive angles go to the creature's left (+X)."""
    a = math.radians(angle)
    return (radius * math.sin(a), -radius * math.cos(a), z)


def quadrant(angle):
    a = angle % 360
    if a < 45 or a >= 315:
        return "Skirt_Front"
    if a < 135:
        return "Skirt_L"
    if a < 225:
        return "Skirt_Back"
    return "Skirt_R"


def build_pieces():
    p = {name: Piece(name) for name in COLOURS}
    skin, hair, hair2 = p["Skin"], p["Hair"], p["HairDark"]
    da, db, dc, glove, gold, teal = p["DressA"], p["DressB"], p["DressC"], p["Glove"], p["Gold"], p["Teal"]
    eye, shine, blush = p["Eye"], p["Shine"], p["Blush"]

    # ---- dress: three gumdrop tiers; the cores ride the hips, the scallops of the two lower tiers sway
    dc.prism("Skirt_Core", (0, 0, 0.35), (0, 0, 3.9), 3.45, 2.6, 10)
    db.prism("Hips", (0, 0, 3.5), (0, 0, 6.9), 2.75, 1.95, 10)
    da.prism("Hips", (0, 0, 6.5), (0, 0, 9.3), 2.0, 1.2, 10)
    da.gem("Root", (0, 0, 7.6), (0.2, 0.2, 0.2), 0)
    for k in range(8):
        a = 22.5 + 45 * k
        dc.drop(quadrant(a), ring(3.0, a, 1.85), (1.7, 1.35, 1.85), (0, 0, a), u=7)
        db.drop(quadrant(a), ring(2.3, a, 5.05), (1.32, 1.1, 1.65), (0, 0, a))
        da.drop("Hips", ring(1.55, 45 * k, 7.6), (0.95, 0.85, 1.3), (0, 0, 45 * k))

    # ---- bodice, collar, sash and bow
    da.prism("Torso", (0, 0, 9.1), (0, 0, 11.3), 1.2, 1.45, 8)
    db.prism("Torso", (0, 0, 11.15), (0, 0, 11.55), 1.65, 1.0, 8)
    teal.prism("Torso", (0, 0, 8.95), (0, 0, 9.4), 1.38, 1.3, 8)
    skin.prism("Torso", (0, 0, 11.3), (0, 0, 12.3), 0.5, 0.5, 6)
    for s in (1, -1):
        teal.prism("Bow", (0, -1.5, 9.18), (1.05 * s, -1.7, 9.4), 0.12, 0.55, 5)
        teal.prism("Bow", (0.05 * s, -1.5, 9.1), (0.42 * s, -1.85, 8.0), 0.12, 0.26, 5)
    teal.gem("Bow", (0, -1.6, 9.18), (0.3, 0.26, 0.3), 0)

    # ---- arms: puff sleeve, a short bare upper arm, long cream gloves
    for s, side in ((1, "L"), (-1, "R")):
        up, lo = "Arm_%s_Upper" % side, "Arm_%s_Lower" % side
        db.gem(up, (1.7 * s, 0, 10.85), (0.9, 0.85, 0.8))
        skin.prism(up, (1.65 * s, 0, 10.9), (2.0 * s, -0.05, 9.7), 0.36, 0.36)
        glove.prism(up, (1.95 * s, -0.05, 9.9), (2.2 * s, -0.1, 9.0), 0.47, 0.42)
        glove.gem(lo, (2.2 * s, -0.1, 9.0), (0.44, 0.44, 0.44), 0)
        glove.prism(lo, (2.2 * s, -0.1, 9.0), (2.3 * s, -0.28, 7.2), 0.42, 0.33)
        glove.gem(lo, (2.31 * s, -0.31, 6.85), (0.48, 0.48, 0.55), 1)

    # ---- head and face (the features are small pieces that read from far away)
    skin.gem("Head", (0, 0, 13.7), (1.9, 1.8, 1.8), 2)
    for s in (1, -1):
        eye.gem("Head", (0.72 * s, -1.6, 13.85), (0.3, 0.16, 0.46))
        shine.gem("Head", (0.72 * s + 0.1, -1.76, 14.05), (0.11, 0.06, 0.13), 0)
        blush.gem("Head", (1.25 * s, -1.27, 13.2), (0.32, 0.13, 0.2), 0)
        eye.box("Head", (0.23 * s, -1.72, 13.17), (0.22, 0.1, 0.09), (0, -32 * s, 0))
    eye.box("Head", (0, -1.74, 13.11), (0.3, 0.1, 0.09))

    # ---- hair: a cap, two side bubbles, the bubble bun and the floating bubble
    hair.gem("Head", (0, 0.5, 14.05), (2.08, 1.98, 1.9), 2)
    for s in (1, -1):
        hair2.gem("Head", (1.85 * s, 0.25, 13.0), (0.75, 0.8, 0.85))
    hair.gem("HairBun", (0, 0.3, 16.3), (1.5, 1.45, 1.4), 2)
    hair2.gem("HairBun", (-1.05, 0.55, 15.6), (0.95, 0.95, 0.9))
    hair2.gem("HairBun", (1.1, 0.25, 15.75), (0.85, 0.85, 0.8))
    hair.gem("HairBun", (0.3, 0.25, 17.65), (0.85, 0.85, 0.8))
    hair2.gem("HairBun", (-0.35, 0.3, 18.15), (0.45, 0.45, 0.42), 0)
    hair.gem("FloatBubble", (2.9, 0.3, 16.5), (0.58, 0.58, 0.58))
    # gloss specks
    shine.gem("HairBun", (-0.55, -0.95, 16.85), (0.2, 0.1, 0.26), 0)
    shine.gem("HairBun", (0.05, -0.5, 17.95), (0.12, 0.07, 0.15), 0)
    shine.gem("FloatBubble", (2.72, -0.15, 16.75), (0.11, 0.07, 0.13), 0)

    # ---- tiara: a gold band and three wrapped-candy drops (teal centre, gold twist ends)
    for a in (-56, -28, 0, 28, 56):
        gold.box("Head", Vector(ring(1.72, a, 14.95 - abs(a) * 0.004)) + Vector(TIARA_SHIFT), (0.88, 0.2, 0.3), (0, 0, a))
    for a, z, k in ((0, 15.62, 1.0), (-38, 15.38, 0.78), (38, 15.38, 0.78)):
        c = Vector(ring(1.78, a, z)) + Vector(TIARA_SHIFT)
        t = Vector((math.cos(math.radians(a)), math.sin(math.radians(a)), 0))
        teal.gem("Head", c, (0.4 * k, 0.3 * k, 0.4 * k), 0, (0, 0, a))
        for s in (1, -1):
            gold.prism("Head", c + t * (0.3 * k * s), c + t * (0.78 * k * s), 0.06 * k, 0.32 * k, 5)

    # ---- teacup: a cream saucer and cup with a pink rim, its own two meshes on the Teacup bone
    cup, rim = p["CupCream"], p["CupRim"]
    cup.prism("Teacup", (0, 0, 10.05), (0, 0, 10.2), 0.62, 1.0, 8)
    cup.prism("Teacup", (0, 0, 10.18), (0, 0, 10.84), 0.38, 0.62, 8)
    cup.box("Teacup", (-0.75, 0, 10.52), (0.38, 0.15, 0.38))
    rim.prism("Teacup", (0, 0, 10.82), (0, 0, 10.94), 0.72, 0.72, 8)
    rim.prism("Teacup", (0, 0, 10.16), (0, 0, 10.23), 1.05, 1.05, 8)
    cup.prism("Teacup", (0, 0, 10.92), (0, 0, 10.98), 0.5, 0.5, 8)
    return p


def build(scene):
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    arm_data = bpy.data.armatures.new("DuquesaBurbujaRig")
    arm = bpy.data.objects.new("DuquesaBurbuja", arm_data)
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
    bone_names = {b[0] for b in BONES}
    meshes = []
    for name, piece in build_pieces().items():
        assert name not in bone_names, "mesh named like a bone: %s" % name
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
    # rigid skinning: every vertex on exactly one bone, every bone used
    used = set()
    for obj in meshes:
        names = [g.name for g in obj.vertex_groups]
        for v in obj.data.vertices:
            assert len(v.groups) == 1 and abs(v.groups[0].weight - 1.0) < 1e-6, \
                "%s vertex %d is not on exactly one bone" % (obj.name, v.index)
            used.add(names[v.groups[0].group])
    missing = [b[0] for b in BONES if b[0] not in used]
    assert not missing, "bones with no skinned vertex: %s" % missing
    assert not (used - bone_names), "vertex groups without a bone: %s" % (used - bone_names)
    return arm, meshes


def export(path, arm, meshes):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in [arm] + meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={"ARMATURE", "MESH"}, apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL", mesh_smooth_type="FACE", use_mesh_modifiers=False,
        add_leaf_bones=False, primary_bone_axis="Y", secondary_bone_axis="X", armature_nodetype="NULL",
        bake_anim=False, path_mode="AUTO")


# ---------------------------------------------------------------------------------------------- clips
def merge(*poses):
    out = {}
    for pose in poses:
        for bone, v in pose.items():
            s = out.setdefault(bone, [0.0] * 6)
            for i in range(6):
                s[i] += v[i] if i < len(v) else 0
    return out


def hips(dy=0, pitch=0, yaw=0, roll=0, dz=0):
    return {"Hips": [0, dy, dz, pitch, yaw, roll]}


def torso(pitch=0, yaw=0, roll=0):
    return {"Torso": [0, 0, 0, pitch, yaw, roll]}


def head(pitch=0, yaw=0, roll=0):
    return {"Head": [0, 0, 0, pitch, yaw, roll]}


def bun(pitch=0, roll=0, bob=0):
    return {"HairBun": [0, bob, 0, pitch, 0, roll]}


def bubble(dx=0, dy=0, dz=0):
    return {"FloatBubble": [dx, dy, dz, 0, 0, 0]}


def bow(roll=0, pitch=0):
    return {"Bow": [0, 0, 0, pitch, 0, roll]}


def skirt(front=0, back=0, left=0, right=0):
    """Degrees each quarter of the skirt swings OUTWARD (negative tucks it in)."""
    return {"Skirt_Front": [0, 0, 0, front, 0, 0], "Skirt_Back": [0, 0, 0, -back, 0, 0],
            "Skirt_L": [0, 0, 0, 0, 0, -left], "Skirt_R": [0, 0, 0, 0, 0, right]}


def arm(side, fwd=0, out=0, bend=0, inward=0):
    """fwd swings the whole arm forward/up, out lifts it sideways; bend folds the elbow, inward crosses the forearm."""
    s = 1 if side == "L" else -1
    return {"Arm_%s_Upper" % side: [0, 0, 0, fwd, 0, -out * s], "Arm_%s_Lower" % side: [0, 0, 0, bend, 0, inward * s]}


def arms(fwd=0, out=0, bend=0, inward=0):
    return merge(arm("L", fwd, out, bend, inward), arm("R", fwd, out, bend, inward))


CLASP = arms(fwd=8, out=0, bend=62, inward=45)  # hands folded in front of the waist: her neutral pose
NEUTRAL = CLASP
CHARGED = merge(arm("R", fwd=150, out=12, bend=25), arm("L", fwd=20, out=5, bend=75, inward=35),
                hips(0.35, 5), torso(6, -10), head(10, 6), bubble(5.2, -0.9, -1.8), skirt(4, 8, 5, 5), bun(-5))
LASH = merge(arm("R", fwd=96, out=-4, bend=4), arm("L", fwd=-25, out=25, bend=30),
             hips(0.1, -9, dz=-0.5), torso(-12, 14), head(8, -10), bubble(4.4, -5.0, -6.3),
             skirt(-6, 16, 8, 8), bun(10), bow(0, 10))
# Seated on a cake whose top is the model's Z = 0 plane: the hips drop, the lobes splay over the seat, the lowest
# core lifts into the dress, the left hand rests on the lap and the right forearm holds the teacup at the chest.
# The Teacup pose is computed per key by resolve_teacup() so the cup stays upright on the right hand.
SIT = merge(hips(-3.3), skirt(56, 36, 40, 40), torso(2), {"Skirt_Core": [0, 2.6, 0, 0, 0, 0]},
            # the lobes also slide in and up so they pool on the seat around her instead of floating off its edge
            {"Skirt_L": [1.4, 1.0, 0], "Skirt_R": [-1.4, 1.0, 0], "Skirt_Back": [0, 1.0, -1.4],
             "Skirt_Front": [0, 0.3, 1.6]},
            arm("L", fwd=14, out=4, bend=50, inward=36), arm("R", fwd=26, out=0, bend=96, inward=56))
CUP_TILT = {2.0: 16}  # SitIdle key time -> degrees the cup tips toward her mouth (the sip)
ARMS_UP = arms(fwd=158, out=18, bend=14, inward=-6)

CLIPS = {
    "Idle": {"length": 3.0, "loop": True, "priority": "Idle", "keys": [
        {"t": 0.0, "pose": NEUTRAL},
        {"t": 0.75, "pose": merge(NEUTRAL, hips(0.22), skirt(2, 2, 2, 2), bubble(0.25, 0.3, -0.3), head(0, 5, 2), bun(0, 2))},
        {"t": 1.5, "pose": merge(NEUTRAL, hips(0.4, 1), skirt(4, 4, 4, 4), bubble(0.0, 0.55, -0.6), bun(1, 0, 0.06), bow(3))},
        {"t": 2.25, "pose": merge(NEUTRAL, hips(0.2), skirt(1, 1, 1, 1), bubble(-0.3, 0.25, -0.25), head(0, -5, -2), bun(0, -2))},
        {"t": 3.0, "pose": NEUTRAL}]},
    "Walk": {"length": 1.2, "loop": True, "priority": "Movement", "keys": [
        {"t": 0.0, "pose": merge(NEUTRAL, hips(0.2, -3, 0, 2.5), skirt(-3, 10, 9, 2), torso(0, 3), bun(3, -3), bubble(0.2, 0.1, 0.3), bow(4))},
        {"t": 0.3, "pose": merge(NEUTRAL, hips(0.38, -4), skirt(-5, 13, 5, 5), bun(4), bubble(0, 0.3, 0.5))},
        {"t": 0.6, "pose": merge(NEUTRAL, hips(0.2, -3, 0, -2.5), skirt(-3, 10, 2, 9), torso(0, -3), bun(3, 3), bubble(-0.2, 0.1, 0.3), bow(-4))},
        {"t": 0.9, "pose": merge(NEUTRAL, hips(0.38, -4), skirt(-5, 13, 5, 5), bun(4), bubble(0, 0.3, 0.5))},
        {"t": 1.2, "pose": merge(NEUTRAL, hips(0.2, -3, 0, 2.5), skirt(-3, 10, 9, 2), torso(0, 3), bun(3, -3), bubble(0.2, 0.1, 0.3), bow(4))}]},
    "Glide": {"length": 0.8, "loop": True, "priority": "Movement", "keys": [
        {"t": 0.0, "pose": merge(hips(0.7, -15, 0, 3), torso(-5), head(14), arms(fwd=-38, out=16, bend=12), skirt(-10, 16, 10, 4), bun(12, -4), bubble(0, 0.2, 1.4), bow(6, 8))},
        {"t": 0.2, "pose": merge(hips(0.95, -17), torso(-5), head(15), arms(fwd=-44, out=20, bend=8), skirt(-12, 18, 8, 8), bun(15), bubble(0.2, 0.5, 1.8), bow(0, 12))},
        {"t": 0.4, "pose": merge(hips(0.7, -15, 0, -3), torso(-5), head(14), arms(fwd=-38, out=16, bend=12), skirt(-10, 16, 4, 10), bun(12, 4), bubble(0, 0.2, 1.4), bow(-6, 8))},
        {"t": 0.6, "pose": merge(hips(0.95, -17), torso(-5), head(15), arms(fwd=-44, out=20, bend=8), skirt(-12, 18, 8, 8), bun(15), bubble(-0.2, 0.5, 1.8), bow(0, 12))},
        {"t": 0.8, "pose": merge(hips(0.7, -15, 0, 3), torso(-5), head(14), arms(fwd=-38, out=16, bend=12), skirt(-10, 16, 10, 4), bun(12, -4), bubble(0, 0.2, 1.4), bow(6, 8))}]},
    "Charge": {"length": 0.8, "loop": False, "priority": "Action", "keys": [
        {"t": 0.0, "pose": NEUTRAL},
        {"t": 0.25, "pose": merge(arm("R", fwd=70, out=20, bend=60), arm("L", fwd=12, out=2, bend=68, inward=40), hips(0.1, 2), torso(3, -5), head(4, 3), bubble(2.4, -0.2, -0.8))},
        {"t": 0.55, "pose": merge(CHARGED, bun(0, 4), bubble(0.15, 0.1, 0))},
        {"t": 0.68, "pose": merge(CHARGED, bun(0, -4), bubble(-0.15, -0.1, 0), hips(0.05))},
        {"t": 0.8, "pose": CHARGED}]},
    "Whip": {"length": 0.9, "loop": False, "priority": "Action", "keys": [
        {"t": 0.0, "pose": CHARGED},
        {"t": 0.14, "pose": merge(CHARGED, arm("R", fwd=22, bend=30), torso(6, -10), hips(0, 4))},
        {"t": 0.3, "pose": LASH},
        {"t": 0.48, "pose": merge(LASH, arm("R", fwd=-10, bend=6), torso(-3), skirt(4, -6, 0, 0), bun(-8))},
        {"t": 0.9, "pose": merge(LASH, arm("R", fwd=-6), torso(2, -3), bun(-6), skirt(3, -8, -2, -2))}]},
    "Wall": {"length": 1.2, "loop": False, "priority": "Action", "keys": [
        {"t": 0.0, "pose": NEUTRAL},
        {"t": 0.3, "pose": merge(hips(-0.45, -8), torso(-8), head(6), arms(fwd=30, out=22, bend=30), skirt(10, 10, 12, 12), bun(8), bubble(0, -0.4, 0))},
        {"t": 0.65, "pose": merge(ARMS_UP, hips(0.75, 6), torso(8), head(8), skirt(-4, 6, -3, -3), bun(-10, 0, 0.1), bubble(0, 1.0, 0), bow(0, -8))},
        {"t": 0.9, "pose": merge(ARMS_UP, arms(fwd=-8), hips(0.55, 4), torso(5), head(6), skirt(3, 3, 3, 3), bun(4), bubble(0.2, 0.6, 0))},
        {"t": 1.2, "pose": merge(ARMS_UP, arms(fwd=-4), hips(0.6, 4), torso(6), head(6), bun(-2), bubble(0, 0.7, 0))}]},
    "Recover": {"length": 1.0, "loop": False, "priority": "Action", "keys": [
        {"t": 0.0, "pose": merge(LASH, arm("R", fwd=-6), torso(2, -3), bun(-6), skirt(3, -8, -2, -2))},
        {"t": 0.3, "pose": merge(arms(fwd=18, out=14, bend=40, inward=20), hips(0.3, 4), torso(4, 4), head(-4, 0, 6), bun(-10, 6), skirt(8, 2, 6, 6), bubble(0.5, 0.6, 0.4))},
        {"t": 0.6, "pose": merge(NEUTRAL, hips(0.12, -1), head(0, 0, -4), bun(5, -4), skirt(-2, 3, 2, 2), bubble(-0.2, 0.2, 0))},
        {"t": 0.8, "pose": merge(NEUTRAL, hips(0.04), head(0, 0, 2), bun(-2, 2))},
        {"t": 1.0, "pose": NEUTRAL}]},
    "Surprised": {"length": 0.6, "loop": False, "priority": "Action", "keys": [
        {"t": 0.0, "pose": NEUTRAL},
        {"t": 0.12, "pose": merge(arms(fwd=35, out=58, bend=55, inward=-10), hips(0.8, 7), torso(8), head(10), bun(-12, 0, 0.45), bubble(0.6, 1.5, 0), skirt(14, 14, 16, 16), bow(0, -12))},
        {"t": 0.3, "pose": merge(arms(fwd=30, out=50, bend=60, inward=-6), hips(0.6, 5), torso(6), head(8, 0, 4), bun(6, 0, 0.2), bubble(0.4, 1.1, 0), skirt(6, 6, 8, 8))},
        {"t": 0.45, "pose": merge(arms(fwd=16, out=18, bend=62, inward=25), hips(0.2, 1), head(2, 0, -3), bun(-3), bubble(0.1, 0.4, 0), skirt(-2, -2, -2, -2))},
        {"t": 0.6, "pose": NEUTRAL}]},
    "SitIdle": {"length": 4.0, "loop": True, "priority": "Idle", "keys": [
        {"t": 0.0, "pose": SIT},
        {"t": 1.0, "pose": merge(SIT, head(0, 4, 7), bun(0, 3), bubble(0.3, 0.3, -0.3), hips(0.05))},
        {"t": 2.0, "pose": merge(SIT, arm("R", fwd=8, bend=12), head(-6, 0, 3), bubble(0, 0.6, -0.5), bow(3))},
        {"t": 3.0, "pose": merge(SIT, head(0, -4, -7), bun(0, -3), bubble(-0.3, 0.3, -0.2), hips(0.05))},
        {"t": 4.0, "pose": SIT}]},
}
ORDER = ["Idle", "Walk", "Glide", "Charge", "Whip", "Wall", "Recover", "Surprised", "SitIdle"]
PREVIEW_T = {"Idle": 1.5, "Walk": 0.0, "Glide": 0.2, "Charge": 0.8, "Whip": 0.3, "Wall": 0.65, "Recover": 0.3,
             "Surprised": 0.12, "SitIdle": 1.0}

# Roblox model axes -> Blender axes: (x, y, z) -> (-x, z, y)
AXES = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def reset_pose(arm_obj):
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.matrix_basis = Matrix.Identity(4)


def apply_pose(arm_obj, pose):
    """Same maths as the Luau clip builder: the delta acts in model axes at the bone's head, on top of the parent."""
    reset_pose(arm_obj)
    for name, v in pose.items():
        v = list(v) + [0] * (6 - len(v))
        pb = arm_obj.pose.bones[name]
        rest = pb.bone.matrix_local
        rx, ry, rz = (math.radians(a) for a in v[3:6])
        rot = Matrix.Rotation(rx, 4, "X") @ Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rz, 4, "Z")
        delta = AXES @ (Matrix.Translation(v[0:3]) @ rot) @ AXES.inverted()
        pivot = Matrix.Translation(rest.to_translation())
        pb.matrix_basis = rest.inverted() @ pivot @ delta @ pivot.inverted() @ rest
    bpy.context.view_layer.update()


def deform(arm_obj, name):
    """How a bone moves the vertices it owns, in model space, for the pose that is applied now."""
    pb = arm_obj.pose.bones[name]
    return pb.matrix @ pb.bone.matrix_local.inverted()


def resolve_teacup(arm_obj):
    """Adds the Teacup entry to every SitIdle key: upright on the right hand, as [dx, dy, dz, rx, ry, rz]."""
    pivot = Matrix.Translation(CUP_BASE)
    for key in CLIPS["SitIdle"]["keys"]:
        pose = {b: v for b, v in key["pose"].items() if b != "Teacup"}
        apply_pose(arm_obj, pose)
        hand = deform(arm_obj, "Arm_R_Lower") @ Vector(HAND_R)
        tilt = Matrix.Rotation(math.radians(CUP_TILT.get(key["t"], 0)), 4, "X")
        world = Matrix.Translation(hand + Vector((0.05, -0.1, 0.42))) @ tilt @ pivot.inverted()
        local = pivot.inverted() @ deform(arm_obj, "Torso").inverted() @ world @ pivot
        delta = AXES.inverted() @ local @ AXES
        best = None
        for order in ("ZYX", "XYZ"):
            e = delta.to_euler(order)
            rot = Matrix.Rotation(e.x, 4, "X") @ Matrix.Rotation(e.y, 4, "Y") @ Matrix.Rotation(e.z, 4, "Z")
            err = max(abs(rot[i][j] - delta[i][j]) for i in range(3) for j in range(3))
            if best is None or err < best[0]:
                best = (err, e)
        assert best[0] < 1e-4, "teacup rotation did not decompose"
        t = delta.to_translation()
        value = [round(x, 4) for x in (t.x, t.y, t.z)] + [round(math.degrees(a), 3) for a in best[1]]
        key["pose"] = dict(pose, Teacup=value)
    reset_pose(arm_obj)


def posed_lowest(arm_obj, meshes, pose, bones):
    """Lowest Z reached by the vertices of the given bones in a pose."""
    apply_pose(arm_obj, pose)
    low = 1e9
    for obj in meshes:
        names = [g.name for g in obj.vertex_groups]
        for v in obj.data.vertices:
            b = names[v.groups[0].group]
            if b in bones:
                low = min(low, (deform(arm_obj, b) @ v.co).z)
    reset_pose(arm_obj)
    return low


def bake_actions(arm_obj, fps=30):
    """One Action per clip, kept in the .blend for preview only (the FBX is exported without animation)."""
    made = []
    arm_obj.animation_data_create()
    for name in ORDER:
        clip = CLIPS[name]
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        arm_obj.animation_data.action = act
        for key in clip["keys"]:
            apply_pose(arm_obj, key["pose"])
            frame = 1 + round(key["t"] * fps)
            for pb in arm_obj.pose.bones:
                pb.keyframe_insert("location", frame=frame)
                pb.keyframe_insert("rotation_quaternion", frame=frame)
        made.append(name)
    arm_obj.animation_data.action = None
    reset_pose(arm_obj)
    return made


# ---------------------------------------------------------------------------------------------- renders
def setup_render(scene):
    scene.render.engine = "BLENDER_WORKBENCH"
    sh = scene.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_shadows = True
    sh.shadow_intensity = 0.35
    sh.show_cavity = True
    sh.cavity_type = "BOTH"
    sh.show_object_outline = True
    sh.object_outline_color = (0.12, 0.05, 0.1)
    scene.display.render_aa = "8"
    scene.display.light_direction = (0.35, 0.45, 0.82)
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.exposure = 1.15
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("Backdrop")
    world.color = hex_rgba("#3B3A46")[:3]
    scene.world = world
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    return cam


def aim(cam, direction, target, ortho):
    d = Vector(direction).normalized()
    cam.location = Vector(target) - d * 60
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    cam.data.ortho_scale = ortho
    cam.data.clip_end = 200


def label(scene, cam, text, target, up_offset, size=1.3):
    curve = bpy.data.curves.new("Label", "FONT")
    curve.body = text
    curve.size = size
    curve.align_x = "CENTER"
    obj = bpy.data.objects.new("Label", curve)
    mat = bpy.data.materials.get("LabelMat") or bpy.data.materials.new("LabelMat")
    mat.diffuse_color = (1, 1, 1, 1)
    curve.materials.append(mat)
    scene.collection.objects.link(obj)
    bpy.context.view_layer.update()
    rot = cam.rotation_euler.to_matrix()
    obj.rotation_euler = cam.rotation_euler
    obj.location = Vector(target) + rot @ Vector((0, up_offset, 30))
    return obj


def shot(scene, path, w, h):
    scene.render.resolution_x, scene.render.resolution_y = w, h
    scene.render.resolution_percentage = 100
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def montage(paths, columns, out_path):
    import numpy as np
    tiles = []
    for path in paths:
        img = bpy.data.images.load(path)
        w, h = img.size
        px = np.empty(w * h * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        tiles.append(px.reshape(h, w, 4))
        bpy.data.images.remove(img)
    rows = [np.concatenate(tiles[i:i + columns], axis=1) for i in range(0, len(tiles), columns)]
    sheet = np.concatenate(rows[::-1], axis=0)  # image rows run bottom to top
    h, w = sheet.shape[:2]
    out = bpy.data.images.new("Montage", w, h, alpha=True)
    out.pixels.foreach_set(sheet.ravel())
    out.filepath_raw = out_path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)
    for path in paths:
        os.remove(path)


def render_all(scene, arm_obj):
    cam = setup_render(scene)
    extras = [cam]
    target = (0, 0, 9.4)
    # turnaround in the rest pose with her hands folded (the neutral pose), four views
    apply_pose(arm_obj, NEUTRAL)
    views = [("FRONT", (0, 1, 0)), ("SIDE", (-1, 0, 0)), ("BACK", (0, -1, 0)), ("THREE-QUARTER", (0.62, 1, -0.22))]
    paths = []
    for i, (text, direction) in enumerate(views):
        aim(cam, direction, target, 22.5)
        bpy.context.view_layer.update()
        lab = label(scene, cam, text, target, -10.8, 0.9)
        path = os.path.join(HERE, "_turn_%d.png" % i)
        shot(scene, path, 350, 640)
        paths.append(path)
        bpy.data.objects.remove(lab, do_unlink=True)
    montage(paths, 4, os.path.join(HERE, SLUG + "-turnaround.png"))
    # contact sheet: one key pose per clip, on a floor disc so the float and the seat read
    floor_me = bpy.data.meshes.new("PreviewFloor")
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=6.5, radius2=6.5, depth=0.2,
                          matrix=Matrix.Translation((0, 0, -0.1)))  # top face at Z = 0
    bm.to_mesh(floor_me)
    bm.free()
    floor = bpy.data.objects.new("PreviewFloor", floor_me)
    fmat = bpy.data.materials.new("PreviewFloorMat")
    fmat.diffuse_color = hex_rgba("#6B5A7A")
    floor_me.materials.append(fmat)
    scene.collection.objects.link(floor)
    extras.append(floor)
    paths = []
    target = (0, 0, 9.0)
    # one tile per clip, then SitIdle from the front and the right side and Glide from the side
    tiles = [(name, None, (1, 0.7, -0.22)) for name in ORDER]
    tiles += [("SitIdle", "SitIdle  front", (0, 1, -0.12)), ("SitIdle", "SitIdle  right side", (1, 0, -0.06)),
              ("Glide", "Glide  side", (1, 0, -0.06))]
    for i, (name, text, direction) in enumerate(tiles):
        clip = CLIPS[name]
        key = min(clip["keys"], key=lambda k: abs(k["t"] - PREVIEW_T[name]))
        apply_pose(arm_obj, key["pose"])
        sit = name == "SitIdle"
        floor.scale = (1, 1, 40 if sit else 1)  # a tall seat whose top stays on Z = 0
        target = (0, 0, 7.0) if sit else (0, 0, 9.0)
        ortho = 22.0 if sit else 25.5
        aim(cam, direction, target, ortho)
        bpy.context.view_layer.update()
        lab = label(scene, cam, text or "%s  %.2gs" % (name, key["t"]), target, 10.6 * ortho / 25.5,
                    1.25 * ortho / 25.5)
        path = os.path.join(HERE, "_pose_%d.png" % i)
        shot(scene, path, 468, 520)
        paths.append(path)
        bpy.data.objects.remove(lab, do_unlink=True)
    montage(paths, 3, os.path.join(HERE, SLUG + "-poses.png"))
    for o in extras:
        bpy.data.objects.remove(o, do_unlink=True)
    scene.world = None
    reset_pose(arm_obj)
    bpy.context.view_layer.update()


# ---------------------------------------------------------------------------------------------- main
def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.name = "DuquesaBurbuja"
    arm_obj, meshes = build(scene)
    for b in BONES:
        assert b[0] in arm_obj.data.bones
    for clip in CLIPS.values():
        for key in clip["keys"]:
            for bone in key["pose"]:
                assert bone in arm_obj.data.bones, "clip uses an unknown bone: %s" % bone
    tris = 0
    for m in meshes:
        m.data.calc_loop_triangles()
        tris += len(m.data.loop_triangles)
    height = max((m.matrix_world @ v.co).z for m in meshes for v in m.data.vertices)
    lowest = min((m.matrix_world @ v.co).z for m in meshes for v in m.data.vertices)
    assert len(BONES) <= 24
    resolve_teacup(arm_obj)
    sit_low = min(posed_lowest(arm_obj, meshes, k["pose"], {"Hips", "Skirt_Core"}) for k in CLIPS["SitIdle"]["keys"])
    assert sit_low >= -1.0, "the dress cores hang %.2f studs under the seat" % -sit_low
    export(EXPORT, arm_obj, meshes)
    with open(os.path.join(HERE, SLUG + "-clips.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({name: CLIPS[name] for name in ORDER}, f, indent=1)
    if RENDER:
        render_all(scene, arm_obj)
    actions = bake_actions(arm_obj)
    report = {
        "slug": SLUG, "bones": [b[0] for b in BONES], "boneCount": len(BONES),
        "meshes": [m.name for m in meshes], "verts": sum(len(m.data.vertices) for m in meshes), "tris": tris,
        "heightStuds": round(height, 3), "lowestZ": round(lowest, 3),
        "sitSeatPlaneZ": 0.0, "sitCoreLowestZ": round(sit_low, 3),
        "clips": {name: {"length": CLIPS[name]["length"], "loop": CLIPS[name]["loop"],
                         "priority": CLIPS[name]["priority"], "keys": len(CLIPS[name]["keys"])} for name in ORDER},
        "previewActions": actions, "fbx": os.path.relpath(EXPORT, REPO).replace("\\", "/"),
        "poseAxes": "Roblox model axes: X = creature's right, Y = up, -Z = front; degrees, Rx*Ry*Rz; "
                    "Transform = rest:Inverse() * (T * R) * rest",
    }
    with open(os.path.join(HERE, SLUG + "-report.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(report, f, indent=1)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, SLUG + "-v1.blend"), check_existing=False)
    print("DUQUESA_OK", json.dumps({k: report[k] for k in ("boneCount", "verts", "tris", "heightStuds", "lowestZ")}))


main()

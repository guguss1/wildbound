"""Duquesa Burbuja v2, the bubblegum noble of the Caramelo biome (about 18 studs tall).

v2 silhouette: tall and slender. A round cream head with big oval eyes and blush, a short bright-pink fringe, a
small bun of three gum bubbles with one bubble floating beside it, a tiara of three wrapped-candy drops, long
glossy pink hair that falls straight down her BACK to near the floor in six faceted strands (never in front of the
shoulders), big puffed sleeves, long slim light pink gloves, and a straight column dress in bright pink that widens
only slightly at a darker hem, with a light-pink scalloped neckline and a teal sash and bow. No legs: the hem hides
them and she glides.

v2 keeps every v1 bone name and clip (so the game can load either) and adds six hair bones (Hair_Back, Hair_L,
Hair_R and their _Low segments) so the long hair sways and folds back when she sits.

Units: 1 Blender unit = 1 stud. The creature faces -Y; its left side is +X; the hem rests on Z = 0. Roblox reads
the FBX as X = -x, Y = z, Z = y, so its front is -Z there.

Rigid skinning: every vertex belongs to exactly one bone, every bone owns at least one vertex (Root owns a small
gem hidden inside the dress), and no mesh is named like a bone.

Clips are authored as data (CLIPS below) and written to duquesa-burbuja-v2-clips.json. Each pose value is
[dx, dy, dz, rx, ry, rz]: a translation in studs and XYZ Euler degrees (CFrame.Angles order, Rx * Ry * Rz) in
ROBLOX model axes (X = the creature's right, Y = up, -Z = its front), applied at the bone's head relative to its
rest pose, exactly like the Tortidragon family: Transform = rest:Inverse() * (T * R) * rest.

Run:  blender --background --python build_duquesa_burbuja_v2.py
Set the environment variable DUQUESA_RENDER=0 to skip the preview renders.
"""
import json
import math
import os

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

SLUG = "duquesa-burbuja"
OUT = SLUG + "-v2"
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
EXPORT = os.path.join(REPO, "assets", "exports", "caramelo", OUT + ".fbx")
RENDER = os.environ.get("DUQUESA_RENDER", "1") != "0"


def ring(radius, angle, z):
    """A point around the body; angle 0 is the front (-Y), positive angles go to the creature's left (+X)."""
    a = math.radians(angle)
    return (radius * math.sin(a), -radius * math.cos(a), z)


# ---- hair strands: (top angle, bottom angle, upper bone, tip height, radial lift)
HAIR_TOP_Z, HAIR_SPLIT_Z, HAIR_R_TOP, HAIR_R_BOT, HAIR_REF_BOT = 12.7, 6.5, 2.2, 3.0, 1.0
STRANDS = [
    (126, 112, "Hair_L", 1.5, 0.0), (144, 131, "Hair_L", 1.05, 0.09),
    (166, 160, "Hair_Back", 0.75, 0.0), (194, 200, "Hair_Back", 0.9, 0.09),
    (216, 229, "Hair_R", 1.15, 0.0), (234, 248, "Hair_R", 1.55, 0.09),
]
HAIR_BONE_ANGLE = {"Hair_L": (133, 124, 118), "Hair_Back": (180, 180, 180), "Hair_R": (227, 236, 242)}


def hair_r(z):
    return HAIR_R_TOP + (HAIR_TOP_Z - z) / (HAIR_TOP_Z - HAIR_REF_BOT) * (HAIR_R_BOT - HAIR_R_TOP)


def hair_bones():
    out = []
    for name, (a0, a1, a2) in HAIR_BONE_ANGLE.items():
        top, mid, bot = ring(hair_r(HAIR_TOP_Z), a0, HAIR_TOP_Z), ring(hair_r(HAIR_SPLIT_Z), a1, HAIR_SPLIT_Z), \
            ring(hair_r(1.2), a2, 1.2)
        out.append((name, top, mid, "Torso"))
        out.append((name + "_Low", mid, bot, name))
    return out


BONES = [
    # name, head, tail, parent
    ("Root", (0, 0, 0), (0, 0, 1), None),
    ("Hips", (0, 0, 6.6), (0, 0, 9.1), "Root"),
    ("Torso", (0, 0, 9.1), (0, 0, 11.6), "Hips"),
    ("Head", (0, 0, 12.3), (0, 0, 14.4), "Torso"),
    ("HairBun", (0, 0.35, 16.0), (0, 0.35, 17.6), "Head"),
    ("FloatBubble", (2.55, 0.4, 16.9), (2.55, 0.4, 17.6), "Head"),
    ("Arm_L_Upper", (1.45, 0, 11.2), (1.8, -0.05, 9.3), "Torso"),
    ("Arm_L_Lower", (1.8, -0.05, 9.3), (1.88, -0.2, 7.55), "Arm_L_Upper"),
    ("Arm_R_Upper", (-1.45, 0, 11.2), (-1.8, -0.05, 9.3), "Torso"),
    ("Arm_R_Lower", (-1.8, -0.05, 9.3), (-1.88, -0.2, 7.55), "Arm_R_Upper"),
    ("Skirt_Front", (0, -1.65, 7.1), (0, -2.4, 0.4), "Hips"),
    ("Skirt_Back", (0, 1.65, 7.1), (0, 2.4, 0.4), "Hips"),
    ("Skirt_L", (1.65, 0, 7.1), (2.4, 0, 0.4), "Hips"),
    ("Skirt_R", (-1.65, 0, 7.1), (-2.4, 0, 0.4), "Hips"),
    ("Bow", (0, -1.2, 9.1), (0, -1.7, 9.1), "Torso"),
    # the lowest dress core: it rides the hips everywhere and only lifts in SitIdle so no column hangs under the seat
    ("Skirt_Core", (0, 0, 4.6), (0, 0, 0.4), "Hips"),
    # the teacup rests hidden inside the bodice (same parent, so it can never show) and is carried to the right
    # hand by a translation in SitIdle only
    ("Teacup", (0, 0, 10.05), (0, 0, 10.75), "Torso"),
] + hair_bones()
CUP_BASE = (0, 0, 10.05)         # centre of the saucer underside in the rest pose
HAND_R = (-1.9, -0.24, 7.25)     # centre of the right hand in the rest pose
HEAD_C = (0, 0, 13.9)            # centre of the head sphere
TIARA_SHIFT = (0, -0.1, 0.0)

COLOURS = {
    "Skin": "#FFE6D6", "Hair": "#FF62B0", "HairLight": "#FFA6D2", "DressA": "#FFBBDB", "DressB": "#F0479A",
    "DressC": "#C42679", "Glove": "#FFD3E4", "Gold": "#F6C343", "Teal": "#2EC4C6", "Sky": "#5CC9F2",
    "Eye": "#3A2033", "Shine": "#FFFFFF", "Blush": "#FF8BA6", "CupCream": "#FFF4E2", "CupRim": "#F2569F",
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

    def hull(self, bone, points):
        """A faceted solid: the convex hull of the points (interior points are dropped)."""
        verts = [self.bm.verts.new(p) for p in points]
        res = bmesh.ops.convex_hull(self.bm, input=verts)
        drop = [g for g in res["geom_interior"] + res["geom_unused"] if isinstance(g, bmesh.types.BMVert)]
        if drop:
            bmesh.ops.delete(self.bm, geom=drop, context="VERTS")
        self._pin([v for v in verts if v.is_valid], bone)


def quadrant(angle):
    a = angle % 360
    if a < 45 or a >= 315:
        return "Skirt_Front"
    if a < 135:
        return "Skirt_L"
    if a < 225:
        return "Skirt_Back"
    return "Skirt_R"


def wedge_level(a, w, r, z, ridge, depth):
    """One cross-section of a pleat or strand: two outer edges, an outer ridge and two inner edges."""
    return [ring(r, a - w, z), ring(r, a + w, z), ring(r + ridge, a, z),
            ring(r - depth, a - w * 0.85, z), ring(r - depth, a + w * 0.85, z)]


def lerp(a, b, t):
    return a + (b - a) * t


def build_pieces():
    p = {name: Piece(name) for name in COLOURS}
    skin, hair, hlight = p["Skin"], p["Hair"], p["HairLight"]
    da, db, dc, glove, gold, teal, sky = p["DressA"], p["DressB"], p["DressC"], p["Glove"], p["Gold"], p["Teal"], \
        p["Sky"]
    eye, shine, blush = p["Eye"], p["Shine"], p["Blush"]

    # ---- dress: a straight column. The hip yoke rides the hips, eight long pleats hang from the four skirt bones
    # and the lowest core (inside the pleats) rides Skirt_Core.
    db.prism("Hips", (0, 0, 5.2), (0, 0, 9.05), 1.95, 1.17, 10)
    dc.prism("Skirt_Core", (0, 0, 0.35), (0, 0, 4.9), 2.18, 1.72, 10)
    db.gem("Root", (0, 0, 7.6), (0.2, 0.2, 0.2), 0)
    zt, zb, rt, rb = 7.35, 0.35, 1.7, 2.38
    for k in range(8):
        a = 22.5 + 45 * k
        bone = quadrant(a)
        lift = 0.06 if k % 2 else 0.0
        db.hull(bone, wedge_level(a, 25, rt + lift, zt, 0.14, 0.42) +
                wedge_level(a, 25, rb + lift, zb + 0.75, 0.16, 0.42))
        # darker hem band, a hair outside the pleat
        hz = zb + 0.95
        hr = rt + (zt - hz) / (zt - zb) * (rb - rt)
        dc.hull(bone, wedge_level(a, 25.6, hr + lift + 0.05, hz, 0.15, 0.4) +
                wedge_level(a, 25.6, rb + lift + 0.08, zb, 0.17, 0.4))

    # ---- bodice, scalloped neckline, sash and bow
    db.prism("Torso", (0, 0, 9.0), (0, 0, 11.4), 1.14, 1.36, 8)
    da.prism("Torso", (0, 0, 11.32), (0, 0, 11.62), 1.42, 1.0, 8)
    for a in range(-80, 81, 20):
        da.gem("Torso", ring(1.3, a, 11.3), (0.29, 0.13, 0.2), 1, (0, 0, a))
    teal.prism("Torso", (0, 0, 8.85), (0, 0, 9.35), 1.24, 1.2, 8)
    skin.prism("Torso", (0, 0, 11.4), (0, 0, 12.5), 0.45, 0.45, 6)
    for s in (1, -1):
        teal.prism("Bow", (0, -1.28, 9.15), (0.95 * s, -1.45, 9.4), 0.1, 0.5, 5)
        teal.prism("Bow", (0.05 * s, -1.28, 9.05), (0.38 * s, -1.6, 7.95), 0.1, 0.24, 5)
    gold.gem("Bow", (0, -1.36, 9.15), (0.27, 0.24, 0.27), 0)

    # ---- arms: big puffed sleeves, then long slim light-pink gloves
    for s, side in ((1, "L"), (-1, "R")):
        up, lo = "Arm_%s_Upper" % side, "Arm_%s_Lower" % side
        db.gem(up, (1.55 * s, 0.02, 11.2), (1.0, 0.95, 0.88), 2)
        da.prism(up, (1.6 * s, 0, 10.45), (1.62 * s, 0, 10.2), 0.42, 0.42, 6)
        glove.prism(up, (1.6 * s, 0, 10.6), (1.8 * s, -0.05, 9.3), 0.32, 0.29, 6)
        glove.gem(lo, (1.8 * s, -0.05, 9.3), (0.3, 0.3, 0.3), 1)
        glove.prism(lo, (1.8 * s, -0.05, 9.3), (1.88 * s, -0.2, 7.6), 0.29, 0.24, 6)
        glove.gem(lo, (1.9 * s, -0.24, 7.25), (0.3, 0.36, 0.44), 1)
        glove.prism(lo, (1.9 * s, -0.3, 7.0), (1.9 * s, -0.32, 6.75), 0.2, 0.1, 5)  # fingertips

    # ---- head and face (the features are small pieces that read from far away)
    skin.gem("Head", HEAD_C, (1.9, 1.8, 1.8), 2)
    for s in (1, -1):
        eye.gem("Head", (0.72 * s, -1.6, 14.05), (0.3, 0.16, 0.46))
        shine.gem("Head", (0.72 * s + 0.1, -1.76, 14.25), (0.11, 0.06, 0.13), 0)
        blush.gem("Head", (1.25 * s, -1.27, 13.4), (0.32, 0.13, 0.2), 0)
        eye.box("Head", (0.23 * s, -1.72, 13.37), (0.22, 0.1, 0.09), (0, -32 * s, 0))
    eye.box("Head", (0, -1.74, 13.31), (0.3, 0.1, 0.09))

    # ---- hair on the head: a cap, a bell-shaped shell over the back of the head and a short fringe
    hair.gem("Head", (0, 0.42, 14.3), (2.0, 1.92, 1.82), 2)
    shell = [(0, 0.5, 15.7), (0, 0.6, 12.5)]
    shell += [ring(2.04, a, 14.5) for a in range(80, 281, 20)]
    shell += [ring(2.18, a, 13.4) for a in range(96, 265, 21)]
    shell += [ring(2.3, a, 12.35) for a in range(110, 251, 20)]
    hair.hull("Head", shell)
    for a in (-52, -26, 0, 26, 52):
        hair.gem("Head", ring(1.5, a, 15.0), (0.5, 0.32, 0.38), 1, (0, 0, a))
    # the bubble bun: three gum bubbles and the floating bubble
    hair.gem("HairBun", (0, 0.35, 16.45), (0.98, 0.95, 0.9), 2)
    hair.gem("HairBun", (-0.78, 0.5, 16.15), (0.62, 0.62, 0.6), 1)
    hair.gem("HairBun", (0.42, 0.3, 17.2), (0.58, 0.58, 0.55), 1)
    hair.gem("FloatBubble", (2.55, 0.4, 16.9), (0.5, 0.5, 0.5), 1)
    shine.gem("HairBun", (-0.35, -0.5, 16.95), (0.18, 0.09, 0.22), 0)
    shine.gem("HairBun", (0.28, -0.2, 17.5), (0.1, 0.06, 0.13), 0)
    shine.gem("FloatBubble", (2.4, 0.0, 17.12), (0.1, 0.06, 0.12), 0)
    shine.gem("Head", (-0.9, -0.95, 15.75), (0.22, 0.1, 0.12), 0, (0, 0, -30))

    # ---- long hair: six faceted strands falling straight down her back, each on an upper and a lower bone
    for a_top, a_bot, bone, tip, lift in STRANDS:
        def at(z):
            t = (HAIR_TOP_Z - z) / (HAIR_TOP_Z - HAIR_REF_BOT)
            return lerp(a_top, a_bot, t), lerp(11.5, 14.5, t), hair_r(z) + lift
        lv = []
        for z in (HAIR_TOP_Z, HAIR_SPLIT_Z - 0.25):
            a, w, r = at(z)
            lv += wedge_level(a, w, r, z, 0.2, 0.36)
        hair.hull(bone, lv)
        lv = []
        for z, shrink in ((HAIR_SPLIT_Z + 0.25, 0.04), (tip + 0.75, 0.0)):
            a, w, r = at(z)
            lv += wedge_level(a, w, r - shrink, z, 0.2, 0.36)
        a, w, r = at(tip)
        lv += [ring(r + 0.05, a, tip), ring(r - 0.05, a - w * 0.4, tip + 0.15), ring(r - 0.05, a + w * 0.4, tip + 0.15)]
        hair.hull(bone + "_Low", lv)
        # a glossy streak down the ridge of the upper strand
        lv = []
        for z in (11.9, 8.0):
            a, w, r = at(z)
            lv += [ring(r + 0.17, a - 2.6, z), ring(r + 0.17, a + 2.6, z), ring(r + 0.235, a, z),
                   ring(r + 0.1, a, z)]
        hlight.hull(bone, lv)

    # ---- tiara: a gold band and three wrapped-candy drops (sky-blue centre, gold twist ends)
    for a in (-56, -28, 0, 28, 56):
        gold.box("Head", Vector(ring(1.66, a, 15.42 - abs(a) * 0.004)) + Vector(TIARA_SHIFT), (0.86, 0.2, 0.3),
                 (0, 0, a))
    for a, z, k in ((0, 16.06, 1.0), (-38, 15.84, 0.78), (38, 15.84, 0.78)):
        c = Vector(ring(1.66, a, z)) + Vector(TIARA_SHIFT)
        t = Vector((math.cos(math.radians(a)), math.sin(math.radians(a)), 0))
        sky.gem("Head", c, (0.4 * k, 0.3 * k, 0.4 * k), 0, (0, 0, a))
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


def hair(back=0, low=0, spread=0, sway=0):
    """back/low swing the upper/lower hair strands backward (out), spread fans the side strands outward,
    sway swings the whole curtain sideways."""
    out = {}
    for b, s in (("Hair_Back", 0), ("Hair_L", 1), ("Hair_R", -1)):
        out[b] = [0, 0, 0, -back, 0, -spread * s + sway]
        out[b + "_Low"] = [0, 0, 0, -low, 0, -spread * 0.5 * s + sway * 0.5]
    return out


def arm(side, fwd=0, out=0, bend=0, inward=0):
    """fwd swings the whole arm forward/up, out lifts it sideways; bend folds the elbow, inward crosses the forearm."""
    s = 1 if side == "L" else -1
    return {"Arm_%s_Upper" % side: [0, 0, 0, fwd, 0, -out * s], "Arm_%s_Lower" % side: [0, 0, 0, bend, 0, inward * s]}


def arms(fwd=0, out=0, bend=0, inward=0):
    return merge(arm("L", fwd, out, bend, inward), arm("R", fwd, out, bend, inward))


CLASP = arms(fwd=6, out=0, bend=58, inward=52)  # hands folded in front of the waist: her neutral pose
NEUTRAL = CLASP
CHARGED = merge(arm("R", fwd=150, out=12, bend=25), arm("L", fwd=20, out=5, bend=75, inward=35),
                hips(0.35, 5), torso(6, -10), head(10, 6), bubble(5.2, -0.9, -1.8), skirt(4, 8, 5, 5), bun(-5),
                hair(4, 3, 3, 2))
LASH = merge(arm("R", fwd=96, out=-4, bend=4), arm("L", fwd=-20, out=28, bend=30),
             hips(0.1, -9, dz=-0.5), torso(-12, 14), head(8, -10), bubble(4.4, -5.0, -6.3),
             skirt(-6, 16, 8, 8), bun(10), bow(0, 10), hair(10, 6, 4, -4))
# Seated on a cake whose top is the model's Z = 0 plane: the hips drop, the pleats splay over the seat, the lowest
# core lifts into the dress, the long hair folds back over the seat, the left hand rests on the lap and the right
# forearm holds the teacup at the chest. The Teacup pose is computed per key by resolve_teacup().
SIT = merge(hips(-3.3), skirt(48, 16, 18, 18), torso(2), {"Skirt_Core": [0, 2.6, 0, 0, 0, 0]},
            {"Skirt_L": [-0.3, 1.6, 0], "Skirt_R": [0.3, 1.6, 0], "Skirt_Back": [0, 1.6, -0.3],
             "Skirt_Front": [0, 1.4, 0.4]},
            hair(8, 30, 4),
            arm("L", fwd=18, out=4, bend=50, inward=40), arm("R", fwd=30, out=0, bend=100, inward=56))
CUP_TILT = {2.0: 16}  # SitIdle key time -> degrees the cup tips toward her mouth (the sip)
ARMS_UP = arms(fwd=158, out=18, bend=14, inward=-6)
# Surprised: the left arm flies out, the right hand goes to her mouth (solved per key by solve_hand_to_mouth)
SURPRISE_L = arm("L", fwd=30, out=48, bend=55, inward=-10)

CLIPS = {
    "Idle": {"length": 3.0, "loop": True, "priority": "Idle", "keys": [
        {"t": 0.0, "pose": NEUTRAL},
        {"t": 0.75, "pose": merge(NEUTRAL, hips(0.22), skirt(2, 2, 2, 2), bubble(0.25, 0.3, -0.3), head(0, 5, 2), bun(0, 2), hair(1, 1, 1, 1))},
        {"t": 1.5, "pose": merge(NEUTRAL, hips(0.4, 1), skirt(4, 4, 4, 4), bubble(0.0, 0.55, -0.6), bun(1, 0, 0.06), bow(3), hair(2.5, 2, 2))},
        {"t": 2.25, "pose": merge(NEUTRAL, hips(0.2), skirt(1, 1, 1, 1), bubble(-0.3, 0.25, -0.25), head(0, -5, -2), bun(0, -2), hair(1, 1, 1, -1))},
        {"t": 3.0, "pose": NEUTRAL}]},
    "Walk": {"length": 1.2, "loop": True, "priority": "Movement", "keys": [
        {"t": 0.0, "pose": merge(NEUTRAL, hips(0.2, -3, 0, 2.5), skirt(-3, 10, 9, 2), torso(0, 3), bun(3, -3), bubble(0.2, 0.1, 0.3), bow(4), hair(6, 6, 5, 3))},
        {"t": 0.3, "pose": merge(NEUTRAL, hips(0.38, -4), skirt(-5, 13, 5, 5), bun(4), bubble(0, 0.3, 0.5), hair(8, 8, 5))},
        {"t": 0.6, "pose": merge(NEUTRAL, hips(0.2, -3, 0, -2.5), skirt(-3, 10, 2, 9), torso(0, -3), bun(3, 3), bubble(-0.2, 0.1, 0.3), bow(-4), hair(6, 6, 5, -3))},
        {"t": 0.9, "pose": merge(NEUTRAL, hips(0.38, -4), skirt(-5, 13, 5, 5), bun(4), bubble(0, 0.3, 0.5), hair(8, 8, 5))},
        {"t": 1.2, "pose": merge(NEUTRAL, hips(0.2, -3, 0, 2.5), skirt(-3, 10, 9, 2), torso(0, 3), bun(3, -3), bubble(0.2, 0.1, 0.3), bow(4), hair(6, 6, 5, 3))}]},
    "Glide": {"length": 0.8, "loop": True, "priority": "Movement", "keys": [
        {"t": 0.0, "pose": merge(hips(0.7, -15, 0, 3), torso(-5), head(14), arms(fwd=-22, out=22, bend=14), skirt(-10, 16, 10, 4), bun(12, -4), bubble(0, 0.2, 1.4), bow(6, 8), hair(9, 6, 5, 3))},
        {"t": 0.2, "pose": merge(hips(0.95, -17), torso(-5), head(15), arms(fwd=-26, out=26, bend=10), skirt(-12, 18, 8, 8), bun(15), bubble(0.2, 0.5, 1.8), bow(0, 12), hair(10, 7, 6))},
        {"t": 0.4, "pose": merge(hips(0.7, -15, 0, -3), torso(-5), head(14), arms(fwd=-22, out=22, bend=14), skirt(-10, 16, 4, 10), bun(12, 4), bubble(0, 0.2, 1.4), bow(-6, 8), hair(9, 6, 5, -3))},
        {"t": 0.6, "pose": merge(hips(0.95, -17), torso(-5), head(15), arms(fwd=-26, out=26, bend=10), skirt(-12, 18, 8, 8), bun(15), bubble(-0.2, 0.5, 1.8), bow(0, 12), hair(10, 7, 6))},
        {"t": 0.8, "pose": merge(hips(0.7, -15, 0, 3), torso(-5), head(14), arms(fwd=-22, out=22, bend=14), skirt(-10, 16, 10, 4), bun(12, -4), bubble(0, 0.2, 1.4), bow(6, 8), hair(9, 6, 5, 3))}]},
    "Charge": {"length": 0.8, "loop": False, "priority": "Action", "keys": [
        {"t": 0.0, "pose": NEUTRAL},
        {"t": 0.25, "pose": merge(arm("R", fwd=70, out=20, bend=60), arm("L", fwd=12, out=2, bend=68, inward=40), hips(0.1, 2), torso(3, -5), head(4, 3), bubble(2.4, -0.2, -0.8), hair(2, 1, 2))},
        {"t": 0.55, "pose": merge(CHARGED, bun(0, 4), bubble(0.15, 0.1, 0), hair(0, 0, 0, 2))},
        {"t": 0.68, "pose": merge(CHARGED, bun(0, -4), bubble(-0.15, -0.1, 0), hips(0.05), hair(0, 0, 0, -2))},
        {"t": 0.8, "pose": CHARGED}]},
    "Whip": {"length": 0.9, "loop": False, "priority": "Action", "keys": [
        {"t": 0.0, "pose": CHARGED},
        {"t": 0.14, "pose": merge(CHARGED, arm("R", fwd=22, bend=30), torso(6, -10), hips(0, 4), hair(-2, 0, 0, 3))},
        {"t": 0.3, "pose": LASH},
        {"t": 0.48, "pose": merge(LASH, arm("R", fwd=-10, bend=6), torso(-3), skirt(4, -6, 0, 0), bun(-8), hair(-4, 4, 0, 5))},
        {"t": 0.9, "pose": merge(LASH, arm("R", fwd=-6), torso(2, -3), bun(-6), skirt(3, -8, -2, -2), hair(-8, -4, -2, 4))}]},
    "Wall": {"length": 1.2, "loop": False, "priority": "Action", "keys": [
        {"t": 0.0, "pose": NEUTRAL},
        {"t": 0.3, "pose": merge(hips(-0.45, -8), torso(-8), head(6), arms(fwd=30, out=22, bend=30), skirt(10, 10, 12, 12), bun(8), bubble(0, -0.4, 0), hair(10, 8, 8))},
        {"t": 0.65, "pose": merge(ARMS_UP, hips(0.75, 6), torso(8), head(8), skirt(-4, 6, -3, -3), bun(-10, 0, 0.1), bubble(0, 1.0, 0), bow(0, -8), hair(2, 4, 4))},
        {"t": 0.9, "pose": merge(ARMS_UP, arms(fwd=-8), hips(0.55, 4), torso(5), head(6), skirt(3, 3, 3, 3), bun(4), bubble(0.2, 0.6, 0), hair(4, 3, 3))},
        {"t": 1.2, "pose": merge(ARMS_UP, arms(fwd=-4), hips(0.6, 4), torso(6), head(6), bun(-2), bubble(0, 0.7, 0), hair(2, 2, 2))}]},
    "Recover": {"length": 1.0, "loop": False, "priority": "Action", "keys": [
        {"t": 0.0, "pose": merge(LASH, arm("R", fwd=-6), torso(2, -3), bun(-6), skirt(3, -8, -2, -2), hair(-8, -4, -2, 4))},
        {"t": 0.3, "pose": merge(arms(fwd=18, out=14, bend=40, inward=20), hips(0.3, 4), torso(4, 4), head(-4, 0, 6), bun(-10, 6), skirt(8, 2, 6, 6), bubble(0.5, 0.6, 0.4), hair(4, 4, 4, -3))},
        {"t": 0.6, "pose": merge(NEUTRAL, hips(0.12, -1), head(0, 0, -4), bun(5, -4), skirt(-2, 3, 2, 2), bubble(-0.2, 0.2, 0), hair(3, 2, 2, 2))},
        {"t": 0.8, "pose": merge(NEUTRAL, hips(0.04), head(0, 0, 2), bun(-2, 2), hair(1, 1, 1, -1))},
        {"t": 1.0, "pose": NEUTRAL}]},
    "Surprised": {"length": 0.6, "loop": False, "priority": "Action", "keys": [
        {"t": 0.0, "pose": NEUTRAL},
        {"t": 0.12, "pose": merge(SURPRISE_L, hips(0.8, 7), torso(8), head(10), bun(-12, 0, 0.45), bubble(0.6, 1.5, 0), skirt(14, 14, 16, 16), bow(0, -12), hair(12, 10, 10))},
        {"t": 0.3, "pose": merge(arm("L", fwd=26, out=40, bend=60, inward=-6), hips(0.6, 5), torso(6), head(8, 0, 4), bun(6, 0, 0.2), bubble(0.4, 1.1, 0), skirt(6, 6, 8, 8), hair(6, 6, 6))},
        {"t": 0.45, "pose": merge(arm("L", fwd=16, out=18, bend=62, inward=25), hips(0.2, 1), head(2, 0, -3), bun(-3), bubble(0.1, 0.4, 0), skirt(-2, -2, -2, -2), hair(1, 2, 1))},
        {"t": 0.6, "pose": NEUTRAL}]},
    "SitIdle": {"length": 4.0, "loop": True, "priority": "Idle", "keys": [
        {"t": 0.0, "pose": SIT},
        {"t": 1.0, "pose": merge(SIT, head(0, 4, 7), bun(0, 3), bubble(0.3, 0.3, -0.3), hips(0.05), hair(0, 0, 0, 2))},
        {"t": 2.0, "pose": merge(SIT, arm("R", fwd=8, bend=12), head(-6, 0, 3), bubble(0, 0.6, -0.5), bow(3))},
        {"t": 3.0, "pose": merge(SIT, head(0, -4, -7), bun(0, -3), bubble(-0.3, 0.3, -0.2), hips(0.05), hair(0, 0, 0, -2))},
        {"t": 4.0, "pose": SIT}]},
}
# Surprised key time -> how close the right hand gets to the mouth (1 = at the mouth, 0 = neutral clasp)
SURPRISE_HAND = {0.12: 1.0, 0.3: 1.0, 0.45: 0.45}
ORDER = ["Idle", "Walk", "Glide", "Charge", "Whip", "Wall", "Recover", "Surprised", "SitIdle"]
PREVIEW_T = {"Idle": 1.5, "Walk": 0.0, "Glide": 0.2, "Charge": 0.8, "Whip": 0.3, "Wall": 0.65, "Recover": 0.3,
             "Surprised": 0.3, "SitIdle": 1.0}

# Roblox model axes -> Blender axes: (x, y, z) -> (-x, z, y)
AXES = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
BONE_HEAD = {b[0]: Vector(b[1]) for b in BONES}
BONE_PARENT = {b[0]: b[3] for b in BONES}


def delta_matrix(v):
    v = list(v) + [0] * (6 - len(v))
    rx, ry, rz = (math.radians(a) for a in v[3:6])
    rot = Matrix.Rotation(rx, 4, "X") @ Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rz, 4, "Z")
    return AXES @ (Matrix.Translation(v[0:3]) @ rot) @ AXES.inverted()


def fk(pose, name, memo):
    """Model-space deform of a bone for a pose, computed directly (same maths as apply_pose + deform)."""
    if name in memo:
        return memo[name]
    parent = BONE_PARENT[name]
    base = fk(pose, parent, memo) if parent else Matrix.Identity(4)
    if name in pose:
        p = Matrix.Translation(BONE_HEAD[name])
        m = base @ p @ delta_matrix(pose[name]) @ p.inverted()
    else:
        m = base
    memo[name] = m
    return m


def solve_hand_to_mouth(base_pose):
    """Right-arm pose that puts the right hand just in front of her mouth, for the given body pose."""
    memo = {}
    torso_m = fk(base_pose, "Torso", memo)
    head_m = fk(base_pose, "Head", memo)
    target = head_m @ Vector((-0.35, -2.25, 13.2))
    head_c = head_m @ Vector(HEAD_C)
    torso_inv = torso_m.inverted()
    p_up = Matrix.Translation(BONE_HEAD["Arm_R_Upper"])
    p_lo = Matrix.Translation(BONE_HEAD["Arm_R_Lower"])
    elbow, hand = BONE_HEAD["Arm_R_Lower"], Vector(HAND_R)

    def cost(fwd, out, bend, inward):
        pose = arm("R", fwd, out, bend, inward)
        up = torso_m @ p_up @ delta_matrix(pose["Arm_R_Upper"]) @ p_up.inverted()
        lo = up @ p_lo @ delta_matrix(pose["Arm_R_Lower"]) @ p_lo.inverted()
        h = lo @ hand
        e = torso_inv @ (up @ elbow)
        c = (h - target).length + 0.002 * (abs(out) + abs(inward))
        if math.hypot(e.x, e.y) < 1.55:
            c += 3.0
        if (h - head_c).length < 2.15:
            c += 3.0
        return c

    best = None
    for fwd in range(0, 171, 10):
        for out in range(-30, 51, 10):
            for bend in range(0, 161, 10):
                for inward in range(-30, 91, 10):
                    c = cost(fwd, out, bend, inward)
                    if best is None or c < best[0]:
                        best = (c, fwd, out, bend, inward)
    for step in (4, 2, 1):
        improved = True
        while improved:
            improved = False
            for i in range(1, 5):
                for d in (-step, step):
                    cand = list(best[1:])
                    cand[i - 1] += d
                    c = cost(*cand)
                    if c < best[0] - 1e-6:
                        best = (c,) + tuple(cand)
                        improved = True
    return best


def resolve_surprise():
    clasp = (6, 0, 58, 52)
    for key in CLIPS["Surprised"]["keys"]:
        k = SURPRISE_HAND.get(key["t"])
        if k is None:
            continue
        base = {b: v for b, v in key["pose"].items() if not b.startswith("Arm_R")}
        best = solve_hand_to_mouth(base)
        vals = [lerp(c, b, k) for c, b in zip(clasp, best[1:])]
        key["pose"] = merge(base, arm("R", *vals))
        print("SURPRISE", key["t"], "miss %.2f" % best[0], best[1:])


def reset_pose(arm_obj):
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.matrix_basis = Matrix.Identity(4)


def apply_pose(arm_obj, pose):
    """Same maths as the Luau clip builder: the delta acts in model axes at the bone's head, on top of the parent."""
    reset_pose(arm_obj)
    for name, v in pose.items():
        pb = arm_obj.pose.bones[name]
        rest = pb.bone.matrix_local
        delta = delta_matrix(v)
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
    # turnaround with her hands folded (the neutral pose), five views like the reference sheet
    apply_pose(arm_obj, NEUTRAL)
    views = [("FRONT", (0, 1, 0)), ("LEFT", (-1, 0, 0)), ("BACK", (0, -1, 0)), ("RIGHT", (1, 0, 0)),
             ("THREE-QUARTER", (0.62, 1, -0.22))]
    paths = []
    for i, (text, direction) in enumerate(views):
        aim(cam, direction, target, 22.5)
        bpy.context.view_layer.update()
        lab = label(scene, cam, text, target, -10.8, 0.9)
        path = os.path.join(HERE, "_turn_%d.png" % i)
        shot(scene, path, 350, 640)
        paths.append(path)
        bpy.data.objects.remove(lab, do_unlink=True)
    montage(paths, 5, os.path.join(HERE, OUT + "-turnaround.png"))
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
    # one tile per clip, then SitIdle from the front and the right side and Glide from the side
    tiles = [(name, None, (1, 0.7, -0.22)) for name in ORDER]
    tiles += [("SitIdle", "SitIdle  front", (0, 1, -0.12)), ("SitIdle", "SitIdle  right side", (1, 0, -0.06)),
              ("Glide", "Glide  side", (1, 0, -0.06)), ("Surprised", "Surprised  front", (0, 1, -0.05)),
              ("Walk", "Walk  back", (-0.5, -1, -0.15)), ("Whip", "Whip  side", (1, 0, -0.06))]
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
    montage(paths, 3, os.path.join(HERE, OUT + "-poses.png"))
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
    assert "Root" in arm_obj.data.bones and arm_obj.data.bones["Root"].parent is None
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
    resolve_surprise()
    resolve_teacup(arm_obj)
    sit_low = min(posed_lowest(arm_obj, meshes, k["pose"], {"Hips", "Skirt_Core"}) for k in CLIPS["SitIdle"]["keys"])
    assert sit_low >= -1.0, "the dress cores hang %.2f studs under the seat" % -sit_low
    export(EXPORT, arm_obj, meshes)
    for clip in CLIPS.values():
        for key in clip["keys"]:
            key["pose"] = {b: [round(x, 4) for x in v] for b, v in key["pose"].items()}
    with open(os.path.join(HERE, OUT + "-clips.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({name: CLIPS[name] for name in ORDER}, f, indent=1)
    if RENDER:
        render_all(scene, arm_obj)
    actions = bake_actions(arm_obj)
    report = {
        "slug": SLUG, "version": "v2", "bones": [b[0] for b in BONES], "boneCount": len(BONES),
        "meshes": [m.name for m in meshes], "verts": sum(len(m.data.vertices) for m in meshes), "tris": tris,
        "heightStuds": round(height, 3), "lowestZ": round(lowest, 3),
        "sitSeatPlaneZ": 0.0, "sitCoreLowestZ": round(sit_low, 3),
        "clips": {name: {"length": CLIPS[name]["length"], "loop": CLIPS[name]["loop"],
                         "priority": CLIPS[name]["priority"], "keys": len(CLIPS[name]["keys"])} for name in ORDER},
        "previewActions": actions, "fbx": os.path.relpath(EXPORT, REPO).replace("\\", "/"),
        "poseAxes": "Roblox model axes: X = creature's right, Y = up, -Z = front; degrees, Rx*Ry*Rz; "
                    "Transform = rest:Inverse() * (T * R) * rest",
    }
    with open(os.path.join(HERE, OUT + "-report.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(report, f, indent=1)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, OUT + ".blend"), check_existing=False)
    print("DUQUESA_OK", json.dumps({k: report[k] for k in ("boneCount", "verts", "tris", "heightStuds", "lowestZ")}))


main()

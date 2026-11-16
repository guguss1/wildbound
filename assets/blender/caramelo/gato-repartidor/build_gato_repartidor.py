"""Gato Repartidor, the candy-delivery kitten of the Caramelo biome.

Low-poly, faceted biped about 3.5 studs tall: orange tabby with a cream chest and muzzle, big dark eyes, a headset,
a striped tail. It wears the game's own invented candy-delivery brand: a mint-green cap with a small pink
wrapped-candy emblem, a pink-and-white striped paper cone of fries in the right paw and a mint-green delivery bag
with the same emblem in the left paw. No lettering and no real-world brand anywhere.

Units: 1 Blender unit = 1 stud. The creature faces -Y; its left side is +X; the feet rest on Z = 0. Roblox reads the
FBX as X = -x, Y = z, Z = y, so its front is -Z there.

Every mesh is skinned, and every vertex belongs to exactly one bone (rigid skinning): the importer keeps only the
bones a skinned vertex uses, so each of the 19 bones owns at least one piece (Root owns a small gem hidden inside
the hips). No mesh is named like a bone: the importer would hang that bone under it.

Clips are data (CLIPS below): { name: { length, loop, priority, keys: [ { t, pose: { bone: [dx, dy, dz, rx, ry, rz] } } ] } }.
The six numbers are a translation in studs and XYZ Euler degrees (CFrame.Angles order, Rx * Ry * Rz) in ROBLOX model
axes (X = creature's right, Y = up, Z = back), relative to the bone's rest pose and carried along by its animated
parent: Bone.Transform = rest:Inverse() * (T(v) * R(v)) * rest, exactly as tortidragon/clips_to_rbxmx.py composes it.

Run:  blender --background --python build_gato_repartidor.py
It rebuilds everything from nothing, exports the FBX, writes the clips and report JSON, renders the turnaround and the
pose sheet, and saves the .blend. Set GATO_NO_RENDER=1 in the environment to skip the renders.
"""
import json
import math
import os

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

SLUG = "gato-repartidor"
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
EXPORT = os.path.join(REPO, "assets", "exports", "caramelo", SLUG + "-v1.fbx")
BLEND = os.path.join(HERE, SLUG + "-v1.blend")
CLIPS_JSON = os.path.join(HERE, SLUG + "-clips.json")
REPORT_JSON = os.path.join(HERE, SLUG + "-report.json")
TURNAROUND = os.path.join(HERE, SLUG + "-turnaround.png")
POSES = os.path.join(HERE, SLUG + "-poses.png")
RENDER = not os.environ.get("GATO_NO_RENDER")

# the tail runs back, out to the left and curls up
TAIL = [(0, 0.42, 1.02), (0.12, 0.74, 0.9), (0.34, 1.0, 0.9), (0.56, 1.14, 1.14), (0.66, 1.12, 1.5)]

BONES = [
    # name, head, tail, parent
    ("Root", (0, 0, 0), (0, 0, 0.5), None),
    ("Hips", (0, 0.05, 1.0), (0, 0.05, 1.35), "Root"),
    ("Torso", (0, 0.05, 1.35), (0, 0, 1.95), "Hips"),
    ("Head", (0, 0, 1.95), (0, 0, 2.9), "Torso"),
    ("Ear_L", (0.52, 0.08, 3.0), (0.7, 0.08, 3.5), "Head"),
    ("Ear_R", (-0.52, 0.08, 3.0), (-0.7, 0.08, 3.5), "Head"),
    ("Cap", (0, 0, 3.0), (0, 0, 3.4), "Head"),
    ("Arm_L_Upper", (0.58, 0, 1.85), (0.8, -0.05, 1.45), "Torso"),
    ("Arm_L_Lower", (0.8, -0.05, 1.45), (0.88, -0.18, 1.06), "Arm_L_Upper"),
    ("Bag", (0.88, -0.2, 1.0), (0.88, -0.2, 0.4), "Arm_L_Lower"),
    ("Arm_R_Upper", (-0.58, 0, 1.85), (-0.78, -0.08, 1.5), "Torso"),
    ("Arm_R_Lower", (-0.78, -0.08, 1.5), (-0.62, -0.5, 1.42), "Arm_R_Upper"),
    ("Fries", (-0.6, -0.6, 1.45), (-0.6, -0.6, 1.9), "Arm_R_Lower"),
    ("Leg_L_Upper", (0.36, 0.05, 1.0), (0.36, 0.05, 0.55), "Hips"),
    ("Leg_L_Lower", (0.36, 0.05, 0.55), (0.36, 0.02, 0.1), "Leg_L_Upper"),
    ("Leg_R_Upper", (-0.36, 0.05, 1.0), (-0.36, 0.05, 0.55), "Hips"),
    ("Leg_R_Lower", (-0.36, 0.05, 0.55), (-0.36, 0.02, 0.1), "Leg_R_Upper"),
    ("Tail_01", TAIL[0], TAIL[2], "Hips"),
    ("Tail_02", TAIL[2], TAIL[4], "Tail_01"),
]
PARENT = {b[0]: b[3] for b in BONES}

COLOURS = {
    "Fur": "#FFC993", "Tabby": "#F5A768", "Cream": "#FFF3E0", "Eye": "#1D1422", "White": "#FFFFFF",
    "Blush": "#F48FA6", "Mint": "#86E3C3", "MintDark": "#45B894", "Candy": "#FF5FA2", "Headset": "#3B3442",
    "FryGold": "#F7C544",
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

    def prism(self, bone, a, b, r1, r2, segments=6):
        a, b = Vector(a), Vector(b)
        axis = b - a
        rot = axis.to_track_quat("Z", "Y").to_matrix().to_4x4()
        m = Matrix.Translation((a + b) / 2) @ rot
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segments,
                                    radius1=r1, radius2=r2, depth=axis.length, matrix=m)
        self._pin(res["verts"], bone)


def ring(piece, bone, centre, scale, dz, width=0.09, grow=1.02, subdiv=1):
    """A tabby stripe: a band cut out of a copy of the body mass itself (same facets, 2% larger), so it lies flush
    on the surface instead of standing out like a plate. dz is the height of the band's middle above the centre."""
    m = Matrix.Translation(centre) @ Matrix.Diagonal((scale[0] * grow, scale[1] * grow, scale[2] * grow, 1))
    res = bmesh.ops.create_icosphere(piece.bm, subdivisions=subdiv, radius=1.0, matrix=m)
    geom = set(res["verts"])
    for v in res["verts"]:
        geom.update(v.link_edges)
        geom.update(v.link_faces)
    for z, normal in ((centre[2] + dz - width / 2, (0, 0, -1)), (centre[2] + dz + width / 2, (0, 0, 1))):
        out = bmesh.ops.bisect_plane(piece.bm, geom=list(geom), dist=1e-5, plane_co=(0, 0, z), plane_no=normal,
                                     clear_outer=True, clear_inner=False)
        geom = {g for g in out["geom"] + out["geom_cut"] if g.is_valid}
    piece._pin([g for g in geom if isinstance(g, bmesh.types.BMVert)], bone)


def candy_emblem(p, bone, c, normal, s=1.0):
    """The invented brand mark: a pink faceted candy with two tiny twist ends. normal is 'y' (faces -Y) or 'x'."""
    if normal == "y":
        p["Candy"].gem(bone, c, (0.13 * s, 0.06 * s, 0.1 * s), 1)
        for d in (-1, 1):
            p["Candy"].prism(bone, (c[0] + 0.1 * s * d, c[1], c[2]), (c[0] + 0.23 * s * d, c[1], c[2]), 0.02 * s, 0.085 * s, 4)
    else:
        p["Candy"].gem(bone, c, (0.06 * s, 0.13 * s, 0.1 * s), 1)
        for d in (-1, 1):
            p["Candy"].prism(bone, (c[0], c[1] + 0.1 * s * d, c[2]), (c[0], c[1] + 0.23 * s * d, c[2]), 0.02 * s, 0.085 * s, 4)


def build_pieces():
    p = {name: Piece(name) for name in COLOURS}
    fur, tabby, cream, mint, dark = p["Fur"], p["Tabby"], p["Cream"], p["Mint"], p["MintDark"]

    # ---- body: hips and torso masses, cream belly and a fluffy cream chest; Root owns a hidden gem
    hips_c, hips_s = (0, 0.05, 1.12), (0.62, 0.54, 0.44)
    torso_c, torso_s = (0, 0.03, 1.64), (0.6, 0.5, 0.5)
    fur.gem("Hips", hips_c, (0.66, 0.56, 0.44), 1)
    fur.gem("Torso", torso_c, torso_s, 1)
    fur.gem("Root", (0, 0.05, 1.15), (0.08, 0.08, 0.08), 0)
    ring(tabby, "Hips", hips_c, (0.66, 0.56, 0.44), 0.08)
    ring(tabby, "Torso", torso_c, torso_s, 0.02)
    ring(tabby, "Torso", torso_c, torso_s, 0.24)
    cream.gem("Hips", (0, -0.3, 1.14), (0.4, 0.3, 0.36), 1)
    cream.gem("Torso", (0, -0.31, 1.68), (0.42, 0.27, 0.36), 1)
    for x in (-0.24, 0, 0.24):  # the fluff hangs in short points
        cream.prism("Torso", (x, -0.4, 1.62), (x * 1.15, -0.5, 1.4 if x else 1.32), 0.2, 0.04, 4)
    for d in (-1, 1):
        cream.prism("Torso", (0.26 * d, -0.36, 1.86), (0.5 * d, -0.42, 1.7), 0.16, 0.03, 4)

    # ---- head: a big faceted ball, cream muzzle, big dark eyes with a white glint, pink nose
    head_c, head_s = (0, 0, 2.55), (0.9, 0.78, 0.68)
    fur.gem("Head", head_c, head_s, 2)
    cream.gem("Head", (0, -0.6, 2.3), (0.4, 0.26, 0.24), 1)
    p["Blush"].gem("Head", (0, -0.86, 2.37), (0.085, 0.05, 0.06), 0)
    p["Eye"].box("Head", (0, -0.86, 2.27), (0.035, 0.03, 0.1))
    for d in (-1, 1):
        p["Eye"].gem("Head", (0.38 * d, -0.63, 2.6), (0.23, 0.13, 0.26), 2)  # round and glossy
        p["White"].gem("Head", (0.38 * d - 0.07, -0.745, 2.7), (0.075, 0.03, 0.075), 1)  # the big shine
        p["White"].gem("Head", (0.38 * d + 0.07, -0.75, 2.52), (0.035, 0.02, 0.035), 0)  # and a small one
        p["Eye"].box("Head", (0.09 * d, -0.83, 2.2), (0.12, 0.03, 0.03), (0, 25 * d, 0))  # the little mouth
        # cheek tufts and side stripes
        fur.prism("Head", (0.74 * d, -0.1, 2.36), (1.06 * d, -0.12, 2.2), 0.17, 0.02, 4)
        fur.prism("Head", (0.76 * d, -0.05, 2.52), (1.08 * d, -0.05, 2.46), 0.15, 0.02, 4)
        # ears with pink insides
        fur.prism("Ear_%s" % ("L" if d > 0 else "R"), (0.54 * d, 0.1, 2.96), (0.8 * d, 0.1, 3.56), 0.32, 0.03, 4)
        p["Blush"].prism("Ear_%s" % ("L" if d > 0 else "R"), (0.58 * d, -0.04, 3.04), (0.78 * d, 0.02, 3.46), 0.2, 0.02, 4)
    for z, w, y in ((2.74, 0.5, 0.7), (2.56, 0.6, 0.73), (2.38, 0.5, 0.7)):  # stripes on the back of the head
        tabby.box("Head", (0, y, z), (w, 0.1, 0.07))

    # ---- headset: a cup on each ear side, a boom and a mic on the right
    hs = p["Headset"]
    for d in (-1, 1):
        hs.prism("Head", (0.84 * d, 0.02, 2.62), (0.98 * d, 0.02, 2.62), 0.17, 0.13, 6)
    hs.prism("Head", (-0.95, -0.02, 2.56), (-0.56, -0.74, 2.3), 0.035, 0.035, 4)
    hs.gem("Head", (-0.54, -0.78, 2.29), (0.08, 0.08, 0.07), 0)

    # ---- the mint cap: dome, darker brim and button, the candy emblem on the front
    mint.gem("Cap", (0, 0.03, 2.99), (0.72, 0.71, 0.4), 2)
    dark.box("Cap", (0, -0.84, 3.0), (1.22, 0.5, 0.07), (-10, 0, 0))  # wide enough to shade both eyes
    dark.gem("Cap", (0, 0.03, 3.39), (0.1, 0.1, 0.05), 0)
    candy_emblem(p, "Cap", (0, -0.63, 3.19), "y")

    # ---- arms: the left one hangs with the bag, the right one is bent forward holding the fries
    fur.prism("Arm_L_Upper", (0.56, 0, 1.87), (0.8, -0.05, 1.45), 0.18, 0.16)
    fur.prism("Arm_L_Lower", (0.8, -0.05, 1.47), (0.88, -0.18, 1.08), 0.16, 0.15)
    tabby.prism("Arm_L_Upper", (0.7, -0.03, 1.63), (0.74, -0.04, 1.56), 0.172, 0.17)
    tabby.prism("Arm_L_Lower", (0.83, -0.1, 1.33), (0.85, -0.13, 1.26), 0.16, 0.158)
    cream.gem("Arm_L_Lower", (0.88, -0.2, 1.02), (0.17, 0.17, 0.15), 1)
    fur.prism("Arm_R_Upper", (-0.56, 0, 1.87), (-0.78, -0.08, 1.5), 0.18, 0.16)
    fur.prism("Arm_R_Lower", (-0.78, -0.08, 1.5), (-0.64, -0.46, 1.43), 0.16, 0.15)
    tabby.prism("Arm_R_Upper", (-0.66, -0.04, 1.7), (-0.7, -0.05, 1.63), 0.176, 0.174)
    tabby.prism("Arm_R_Lower", (-0.73, -0.22, 1.475), (-0.7, -0.3, 1.46), 0.16, 0.158)
    cream.gem("Arm_R_Lower", (-0.62, -0.54, 1.42), (0.17, 0.17, 0.15), 1)

    # ---- the fries: a pink-and-white striped paper cone and plain golden sticks
    fx, fy = -0.6, -0.62
    bands = [(1.26, 0.03), (1.42, 0.1), (1.56, 0.155), (1.7, 0.21), (1.82, 0.25)]
    for i in range(len(bands) - 1):
        (z0, r0), (z1, r1) = bands[i], bands[i + 1]
        (p["Candy"] if i % 2 == 0 else p["White"]).prism("Fries", (fx, fy, z0), (fx, fy, z1), r0, r1, 6)
    sticks = [(-0.11, -0.06, 2.0, 12, -14), (0.0, -0.09, 2.08, 8, 0), (0.11, -0.05, 2.02, 10, 14), (-0.06, 0.07, 2.12, -8, -8),
              (0.07, 0.08, 2.06, -10, 10), (0.0, 0.0, 2.16, 0, 3), (-0.14, 0.03, 1.98, -3, -20), (0.15, 0.03, 1.97, -3, 20)]
    for dx, dy, top, rx, ry in sticks:
        length = top - 1.62
        p["FryGold"].box("Fries", (fx + dx, fy + dy, 1.62 + length / 2), (0.07, 0.07, length), (rx, ry, 0))

    # ---- the delivery bag: mint box, darker fold and gussets, cream handle, the emblem on the front and outside
    bx, by = 0.9, -0.22
    mint.box("Bag", (bx, by, 0.5), (0.56, 0.34, 0.56))
    dark.box("Bag", (bx, by, 0.8), (0.58, 0.36, 0.07))
    dark.box("Bag", (bx, by + 0.005, 0.47), (0.575, 0.12, 0.5))
    for d in (-1, 1):
        cream.prism("Bag", (bx + 0.16 * d, by, 0.8), (bx - 0.02 + 0.03 * d, by, 1.0), 0.03, 0.03, 4)
    candy_emblem(p, "Bag", (bx, by - 0.175, 0.5), "y", 0.95)
    candy_emblem(p, "Bag", (bx + 0.285, by, 0.5), "x", 0.7)

    # ---- legs and cream feet
    for s, d in (("L", 1), ("R", -1)):
        x = 0.36 * d
        fur.prism("Leg_%s_Upper" % s, (x, 0.05, 1.02), (x, 0.05, 0.55), 0.25, 0.22)
        cream.prism("Leg_%s_Lower" % s, (x, 0.05, 0.57), (x, 0.03, 0.14), 0.22, 0.21)  # cream socks
        tabby.prism("Leg_%s_Upper" % s, (x, 0.05, 0.74), (x, 0.05, 0.66), 0.24, 0.236)
        cream.gem("Leg_%s_Lower" % s, (x, -0.1, 0.12), (0.25, 0.36, 0.12), 1)

    # ---- the striped tail with a cream tip
    radii = [0.17, 0.19, 0.2, 0.19, 0.16]
    for i in range(4):
        bone = "Tail_01" if i < 2 else "Tail_02"
        a, b = Vector(TAIL[i]), Vector(TAIL[i + 1])
        mid, rm = (a + b) / 2, (radii[i] + radii[i + 1]) / 2
        fur.prism(bone, a - (b - a) * 0.08, mid, radii[i], rm)
        tabby.prism(bone, mid, b + (b - a) * 0.08, rm * 1.04, radii[i + 1] * 1.04)
    cream.gem("Tail_02", (0.67, 1.1, 1.6), (0.17, 0.17, 0.2), 1)
    return p


def own_scene():
    """A scene of its own, rebuilt from nothing each run."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.data.scenes[0]
    scene.name = "GatoRepartidor"
    return scene


def build():
    scene = own_scene()
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    arm_data = bpy.data.armatures.new("GatoRepartidorRig")
    arm = bpy.data.objects.new("GatoRepartidor", arm_data)
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
        gloss = 0.12 if name == "Eye" else 0.95  # only the eyes shine
        bsdf.inputs["Roughness"].default_value = gloss
        mat.roughness = gloss
        mat.metallic = 0.0
        me.materials.append(mat)
        for poly in me.polygons:
            poly.use_smooth = False
        obj.parent = arm
        mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
        meshes.append(obj)
    names = {b[0] for b in BONES}
    used = set()
    for obj in meshes:
        groups = [g.name for g in obj.vertex_groups]
        for v in obj.data.vertices:
            assert len(v.groups) == 1 and abs(v.groups[0].weight - 1.0) < 1e-6, \
                "%s vertex %d is not pinned to exactly one bone" % (obj.name, v.index)
            used.add(groups[v.groups[0].group])
    missing = [b[0] for b in BONES if b[0] not in used]
    assert not missing, "bones with no skinned vertex: %s" % missing
    assert used <= names, "vertex groups that are not bones: %s" % (used - names)
    clash = [o.name for o in meshes if o.name in names]
    assert not clash, "meshes named like bones: %s" % clash
    return scene, arm, meshes


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


# ======================================================================================================================
# Clips. Roblox model axes: X = the creature's right, Y = up, Z = back (the front is -Z).
#   rx > 0: a hanging limb swings forward; the head or torso pitches up (rx < 0 bows); an ear leans back.
#   ry > 0: turns to the creature's left.      rz > 0: rolls / tilts to the creature's left;
#   the right arm lifts sideways with rz > 0, the left arm with rz < 0.
# ======================================================================================================================
def merge(*poses):
    out = {}
    for pose in poses:
        for bone, v in pose.items():
            s = out.setdefault(bone, [0.0] * 6)
            for i in range(len(v)):
                s[i] += v[i]
    return out


def body(dy, pitch=0, yaw=0, roll=0):
    """Hips bob with the feet planted: the legs slide the other way inside the hip mass."""
    return {"Hips": [0, dy, 0, pitch, yaw, roll], "Leg_L_Upper": [0, -dy, 0], "Leg_R_Upper": [0, -dy, 0]}


def hop(dy, pitch=0):
    return {"Hips": [0, dy, 0, pitch, 0, 0]}


def legs(l, r, bend_l=0, bend_r=0):
    return {"Leg_L_Upper": [0, 0, 0, l, 0, 0], "Leg_R_Upper": [0, 0, 0, r, 0, 0],
            "Leg_L_Lower": [0, 0, 0, -bend_l, 0, 0], "Leg_R_Lower": [0, 0, 0, -bend_r, 0, 0]}


def torso(pitch=0, yaw=0, roll=0, dy=0):
    return {"Torso": [0, dy, 0, pitch, yaw, roll]}


def head(pitch=0, yaw=0, roll=0, dy=0):
    return {"Head": [0, dy, 0, pitch, yaw, roll]}


def ears(back=0, spread=0):
    return {"Ear_L": [0, 0, 0, back, 0, -spread], "Ear_R": [0, 0, 0, back, 0, spread]}


def cap(pitch=0, dy=0, dz=0, roll=0):
    return {"Cap": [0, dy, dz, pitch, 0, roll]}


def arm_l(swing=0, out=0, elbow=0, bag=0, bag_roll=0):
    return {"Arm_L_Upper": [0, 0, 0, swing, 0, -out], "Arm_L_Lower": [0, 0, 0, elbow, 0, 0],
            "Bag": [0, 0, 0, bag, 0, bag_roll]}


def arm_r(swing=0, out=0, elbow=0, fries=0, fries_roll=0):
    return {"Arm_R_Upper": [0, 0, 0, swing, 0, out], "Arm_R_Lower": [0, 0, 0, elbow, 0, 0],
            "Fries": [0, 0, 0, fries, 0, fries_roll]}


def tail(yaw=0, lift=0, curl=0):
    """yaw swishes sideways; lift raises the whole tail; curl bends the tip further up."""
    return {"Tail_01": [0, 0, 0, -lift, yaw * 0.45, 0], "Tail_02": [0, 0, 0, -curl, yaw * 0.55, 0]}


REST = {}
STAND = merge(body(0), legs(0, 0), torso(), head(), ears(), cap(), arm_l(), arm_r(), tail())  # every bone keyed


def keys(*pairs):
    return [{"t": t, "pose": merge(STAND, pose)} for t, pose in pairs]


def walk_key(phase):
    """phase 0: left leg forward (contact). 1: right leg passing. 2: right leg forward. 3: left leg passing."""
    s = 1 if phase in (0, 1) else -1
    if phase % 2 == 0:
        lg = legs(24 * s, -24 * s, 10 if s > 0 else 0, 0 if s > 0 else 10)
        return merge(lg, body(0.03, 0, 5 * s, 0), torso(-3, -9 * s, 0), head(2, 4 * s, 0),
                     arm_l(-20 * s, 4, 6, 9 * s), arm_r(7 * s, 0, 0, -3 * s), tail(-14 * s, 4), ears(4, 0))
    lg = legs(-4, 22, 0, 50) if s > 0 else legs(22, -4, 50, 0)
    lift = {("Leg_R_Upper" if s > 0 else "Leg_L_Upper"): [0, 0.15, 0]}  # the passing foot clears the ground
    return merge(lg, lift, body(0.09, 0, 0, 2.5 * s), torso(-3, 0, -2 * s), head(3, 0, -1.5 * s),
                 arm_l(0, 5, 6, -15 * s), arm_r(0, 0, 0, 3 * s, 0), tail(0, 8, 4), ears(-3, 0))


def run_key(phase):
    s = 1 if phase in (0, 1) else -1
    lean = merge(torso(-16, 0, 0), head(13, 0, 0), ears(24, 6), cap(0, 0, 0), tail(0, 26, 10))
    if phase % 2 == 0:
        lg = legs(46 * s, -40 * s, 20 if s > 0 else 62, 62 if s > 0 else 20)
        return merge(lean, lg, body(-0.06, -6, 7 * s, 0), torso(0, -12 * s, 0), head(0, 6 * s, 0),
                     arm_l(-34 * s - 8, 10, 20, -22 + 12 * s), arm_r(16 * s, 4, 0, -6 * s), tail(-10 * s))
    lg = legs(4, 14, 10, 70) if s > 0 else legs(14, 4, 70, 10)
    return merge(lean, lg, hop(0.16, -6), {"Hips": [0, 0, 0, 0, 0, 3 * s]}, torso(2, 0, -2 * s),
                 arm_l(-8, 12, 24, -38), arm_r(0, 6, 0, 4), tail(0, 8), ears(6, 0), cap(3, 0.03, 0))


# Deliver: the left paw brings the bag forward and holds it out; the bag keeps hanging; a small bow.
OFFER = merge(arm_l(98, 22, -14, -84), {"Arm_L_Upper": [-0.06, 0.02, -0.16]}, body(-0.05, -4, 0, 0), torso(-13, 6, 0), head(9, -4, 4), ears(-6, 6),
              arm_r(-34, 22, 0, 30), tail(0, 22, 12))
# Throw: twist back with the fries arm cocked, then whip it forward and up.
WINDUP = merge({"Arm_R_Upper": [0, 0, 0, -25, 0, 100], "Arm_R_Lower": [0, 0, 0, 0, -95, 0], "Fries": [0, 0, 0, -80, 0, 0]}, body(-0.08, 6, -14, 0), torso(8, -22, 0), head(-6, 20, 0), arm_l(22, 10, 10, -18),
               tail(16, 10), ears(10, 0), legs(6, -6))
RELEASE = merge(arm_r(128, 34, -84, -62), {"Arm_R_Upper": [0.06, 0.05, -0.16]}, body(-0.02, -8, 10, 0), torso(-14, 20, 0), head(10, -16, 0), arm_l(-26, 12, 10, 26),
                tail(-18, 24, 10), ears(-8, 6), legs(-8, 10, 0, 10), cap(-4, 0.02, 0))
# Call: the fries paw goes up to the headset cup, the head tilts onto it.
PHONE = merge({"Arm_R_Upper": [0, 0, 0, 0, 0, 85], "Arm_R_Lower": [0, 0, 0, 0, -95, 0], "Fries": [0, 0, 0, -105, 0, 0]},
              head(4, 8, -15), torso(0, 0, -4), body(0, 0, 0, -2), ears(0, 8),
              arm_l(-6, 6, 4, 4), tail(-10, 14, 8))
# Rest: sitting on the ground with the legs out, the bag set down, the cap tipped over the eyes.
SIT = merge(hop(-0.7, 0), legs(86, 86), {"Leg_L_Upper": [0, 0, 0, 0, 12, 0], "Leg_R_Upper": [0, 0, 0, 0, -12, 0]},
            torso(-10, 0, 0), head(-16, 0, 5), cap(-30, 0.05, -0.16), ears(14, 14),
            arm_l(10, 26, 0, -8, 24), {"Bag": [0, 0.42, 0]}, arm_r(-18, 10, 0, 16), tail(40, 12, -20))

CLIPS = {
    "Idle": {"length": 2.5, "loop": True, "priority": "Idle", "keys": keys(
        (0.0, merge(tail(-18, 0), arm_l(0, 0, 0, 0, -3))),
        (0.625, merge(body(-0.025), torso(0, 0, 0, 0.02), head(2, 5, 2), tail(0, 6, 6), ears(-4, 3), arm_r(3))),
        (1.25, merge(tail(18, 0), arm_l(0, 0, 0, 0, 3), head(0, 0, 0))),
        (1.875, merge(body(-0.025), torso(0, 0, 0, 0.02), head(2, -5, -2), tail(0, 6, 6), ears(5, 0), arm_r(3))),
        (2.5, merge(tail(-18, 0), arm_l(0, 0, 0, 0, -3))))},
    "Walk": {"length": 1.0, "loop": True, "priority": "Movement", "keys": keys(
        (0.0, walk_key(0)), (0.25, walk_key(1)), (0.5, walk_key(2)), (0.75, walk_key(3)), (1.0, walk_key(0)))},
    "Run": {"length": 0.6, "loop": True, "priority": "Movement", "keys": keys(
        (0.0, run_key(0)), (0.15, run_key(1)), (0.3, run_key(2)), (0.45, run_key(3)), (0.6, run_key(0)))},
    "Deliver": {"length": 2.5, "loop": False, "priority": "Action", "keys": keys(
        (0.0, REST),
        (0.3, merge(arm_l(-16, 6, 4, 10), body(-0.03, 3), torso(4), head(-2), tail(0, 8))),
        (0.8, merge(OFFER, torso(-4), arm_l(6, 0, 0, -10))),
        (1.0, OFFER),
        (1.4, merge(OFFER, torso(2), head(2, 0, -8), arm_l(0, 0, 0, 0, 5), tail(16), ears(4, 0))),
        (1.8, merge(OFFER, head(0, 0, 0), arm_l(0, 0, 0, 0, -5), tail(-16))),
        (2.15, merge(arm_l(26, 4, 8, -34), body(-0.02, -2), torso(-4), head(3), tail(0, 8))),
        (2.5, REST))},
    "Throw": {"length": 0.8, "loop": False, "priority": "Action", "keys": keys(
        (0.0, REST), (0.25, WINDUP), (0.38, RELEASE),
        (0.55, merge(RELEASE, arm_r(-40, -4, 40, 40), torso(4, -8), head(-4, 6), body(0.02, 3, -4), cap(4, -0.02, 0))),
        (0.8, REST))},
    "Call": {"length": 1.2, "loop": False, "priority": "Action", "keys": keys(
        (0.0, REST), (0.25, PHONE),
        (0.5, merge(PHONE, head(-5, 0, -3), ears(6, 0), tail(20), body(-0.02))),
        (0.75, merge(PHONE, head(3, 0, 2), ears(-4, 0), tail(-20))),
        (0.95, merge(PHONE, head(-3, 0, -2), tail(8))),
        (1.2, REST))},
    "Rest": {"length": 3.0, "loop": True, "priority": "Idle", "keys": keys(
        (0.0, SIT),
        (0.75, merge(SIT, torso(1.5, 0, 0, 0.015), head(-1.5), tail(-22), ears(2, 0))),
        (1.5, merge(SIT, torso(3, 0, 0, 0.03), head(-3, 0, 0), cap(-2, 0, 0), tail(-40), ears(4, 0), arm_r(2))),
        (2.25, merge(SIT, torso(1.5, 0, 0, 0.015), head(-1.5), tail(-22), ears(2, 0))),
        (3.0, SIT))},
    "Surprised": {"length": 0.5, "loop": False, "priority": "Action", "keys": keys(
        (0.0, REST),
        (0.07, merge(body(-0.09, -3), torso(-5), head(-6), ears(14, 0), cap(0, -0.01, 0))),
        (0.2, merge(hop(0.3, 5), legs(-12, 14, 0, 24), torso(7), head(13), ears(-16, 16), cap(12, 0.2, 0.04),
                    arm_l(-12, 46, 0, 8, -40), arm_r(-24, 42, -12, 14, 30), tail(0, 62, 34))),
        (0.34, merge(body(-0.07, 2), torso(3), head(4), ears(-6, 8), cap(-3, -0.02, 0),
                     arm_l(-6, 22, 0, 4, -18), arm_r(-10, 18, -4, 6, 12), tail(0, 30, 16))),
        (0.5, REST))},
}
ORDER = ["Idle", "Walk", "Run", "Deliver", "Throw", "Call", "Rest", "Surprised"]
# the pose sheet: label, clip, key time, camera azimuth (0 = front, positive walks round to the creature's left)
SHEET = [("IDLE", "Idle", 1.25, 25), ("WALK", "Walk", 0.0, 50), ("RUN", "Run", 0.0, 60), ("RUN (air)", "Run", 0.15, 60),
         ("DELIVER", "Deliver", 1.0, 35), ("THROW (wind-up)", "Throw", 0.25, -40), ("THROW (release)", "Throw", 0.38, -65),
         ("CALL", "Call", 0.25, -20), ("REST", "Rest", 0.0, 30), ("SURPRISED", "Surprised", 0.2, 25)]


def clips_as_data():
    out = {}
    for name in ORDER:
        c = CLIPS[name]
        ks = []
        for k in c["keys"]:
            unknown = set(k["pose"]) - set(PARENT)
            assert not unknown, "clip %s keys unknown bones %s" % (name, unknown)
            ks.append({"t": round(k["t"], 4), "pose": {b: [round(x, 4) for x in v] for b, v in sorted(k["pose"].items())}})
        assert abs(ks[-1]["t"] - c["length"]) < 1e-6 and ks[0]["t"] == 0, "clip %s keys do not span its length" % name
        if c["loop"]:
            assert ks[0]["pose"] == ks[-1]["pose"], "looping clip %s does not close" % name
        out[name] = {"length": c["length"], "loop": c["loop"], "priority": c["priority"], "keys": ks}
    return out


# ---- preview in Blender: the same maths as Roblox, with Blender's axes ----
RBX_TO_BL = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def basis_for(arm, bone, v):
    """Bone.Transform = rest^-1 * (T * Rx * Ry * Rz) * rest, with the delta moved from Roblox axes to Blender's."""
    v = list(v) + [0] * (6 - len(v))
    rx, ry, rz = (math.radians(a) for a in v[3:6])
    d = (Matrix.Translation(v[0:3]) @ Matrix.Rotation(rx, 4, "X") @ Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rz, 4, "Z"))
    d = RBX_TO_BL @ d @ RBX_TO_BL.inverted()
    rest = arm.data.bones[bone].matrix_local.to_3x3().to_4x4()
    return rest.inverted() @ d @ rest


def apply_pose(arm, pose):
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.matrix_basis = basis_for(arm, pb.name, pose.get(pb.name, [0] * 6))
    bpy.context.view_layer.update()


def pose_at(clip, t):
    return next(k["pose"] for k in CLIPS[clip]["keys"] if abs(k["t"] - t) < 1e-6)


def lowest_z(meshes):
    dg = bpy.context.evaluated_depsgraph_get()
    low = 1e9
    for o in meshes:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        low = min(low, min((ev.matrix_world @ v.co).z for v in me.vertices))
        ev.to_mesh_clear()
    return low


def make_actions(arm):
    """One Blender action per clip, for scrubbing in the .blend (30 fps). The FBX carries no animation."""
    made = []
    arm.animation_data_create()
    for name in ORDER:
        act = bpy.data.actions.new("Gato_" + name)
        act.use_fake_user = True
        arm.animation_data.action = act
        for k in CLIPS[name]["keys"]:
            apply_pose(arm, k["pose"])
            frame = 1 + k["t"] * 30
            for pb in arm.pose.bones:
                pb.keyframe_insert("location", frame=frame)
                pb.keyframe_insert("rotation_quaternion", frame=frame)
        made.append(act.name)
    arm.animation_data.action = None
    apply_pose(arm, {})
    return made


# ---- renders ----
BG = (0.045, 0.04, 0.06)


def setup_render(scene):
    scene.render.engine = "BLENDER_WORKBENCH"
    sh = scene.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_shadows = True
    sh.shadow_intensity = 0.35
    sh.show_cavity = True
    sh.cavity_type = "BOTH"
    sh.show_object_outline = False
    sh.show_specular_highlight = True  # the materials are matte except the eyes
    scene.display.light_direction = (0.35, 0.45, 0.82)
    scene.display.render_aa = "8"
    world = bpy.data.worlds.new("GatoWorld")
    world.color = BG
    scene.world = world
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.exposure = 0.55
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    cam_data = bpy.data.cameras.new("GatoCam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("GatoCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    font = bpy.data.curves.new("GatoLabel", "FONT")
    font.align_x = "CENTER"
    font.size = 0.3
    label = bpy.data.objects.new("GatoLabel", font)
    scene.collection.objects.link(label)
    mat = bpy.data.materials.new("LabelMat")
    mat.diffuse_color = (1, 0.75, 0.86, 1)
    font.materials.append(mat)
    label.parent = cam
    return cam, label


def shot(scene, cam, label, path, text, azimuth, size, span=4.3, centre_z=1.8, elevation=10):
    """azimuth 0 looks at the front; positive walks round to the creature's left."""
    a, e = math.radians(azimuth), math.radians(elevation)
    target = Vector((0, 0, centre_z))
    pos = target + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * 12
    cam.location = pos
    cam.rotation_euler = (target - pos).to_track_quat("-Z", "Y").to_euler()
    cam.data.ortho_scale = span
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    label.data.body = text
    height = span if size[1] >= size[0] else span * size[1] / size[0]
    label.location = (0, -height / 2 + 0.16, -3)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def montage(paths, cols, out):
    import numpy as np
    tiles = []
    for path in paths:
        img = bpy.data.images.load(path)
        w, h = img.size
        px = np.empty(w * h * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        tiles.append(px.reshape(h, w, 4))
        bpy.data.images.remove(img)
    rows = [np.concatenate(tiles[i:i + cols], axis=1) for i in range(0, len(tiles), cols)]
    sheet = np.concatenate(rows[::-1], axis=0)  # image rows run bottom-up
    h, w, _ = sheet.shape
    img = bpy.data.images.new("GatoSheet", w, h, alpha=False)
    img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = out
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    for path in paths:
        os.remove(path)


def render_all(scene, arm):
    cam, label = setup_render(scene)
    tmp = []
    apply_pose(arm, {})
    for i, (text, az) in enumerate((("FRONT", 0), ("SIDE (LEFT)", 90), ("BACK", 180), ("SIDE (RIGHT)", -90),
                                    ("3/4 FRONT", -35), ("3/4 BACK", 145))):
        path = os.path.join(HERE, "_tmp_turn_%d.png" % i)
        shot(scene, cam, label, path, text, az, (467, 620), span=4.5, centre_z=1.72)
        tmp.append(path)
    montage(tmp, 3, TURNAROUND)
    tmp = []
    for i, (text, name, t, az) in enumerate(SHEET):
        apply_pose(arm, pose_at(name, t))
        path = os.path.join(HERE, "_tmp_pose_%d.png" % i)
        shot(scene, cam, label, path, text, az, (280, 380), span=5.4, centre_z=1.6)
        tmp.append(path)
    montage(tmp, 5, POSES)
    apply_pose(arm, {})
    for o in (cam, label):
        bpy.data.objects.remove(o, do_unlink=True)


# ======================================================================================================================
SCENE, ARM, MESHES = build()
export(EXPORT, ARM, MESHES)  # before any posing: the FBX carries the rest pose only

def settle(arm, meshes):
    """Lift the hips of every key whose lowest vertex dips under the ground, so the feet stay at or above Z = 0."""
    for clip in ORDER:
        for k in CLIPS[clip]["keys"]:
            apply_pose(arm, k["pose"])
            low = lowest_z(meshes)
            if low < 0:
                k["pose"]["Hips"][1] += 0.002 - low
    apply_pose(arm, {})


settle(ARM, MESHES)
DATA = clips_as_data()
with open(CLIPS_JSON, "w", encoding="utf-8", newline="\n") as f:
    json.dump(DATA, f, indent=1)

GROUND = {}
for clip in ORDER:
    GROUND[clip] = round(min(lowest_z(MESHES) for k in CLIPS[clip]["keys"] if apply_pose(ARM, k["pose"]) is None), 3)
apply_pose(ARM, {})

for m in MESHES:
    m.data.calc_loop_triangles()
ZS = [(m.matrix_world @ v.co).z for m in MESHES for v in m.data.vertices]
REPORT = {
    "slug": SLUG,
    "bones": [b[0] for b in BONES],
    "boneCount": len(BONES),
    "meshes": {m.name: {"verts": len(m.data.vertices), "tris": len(m.data.loop_triangles),
                        "colour": COLOURS[m.name], "bones": [g.name for g in m.vertex_groups]} for m in MESHES},
    "verts": sum(len(m.data.vertices) for m in MESHES),
    "tris": sum(len(m.data.loop_triangles) for m in MESHES),
    "heightStuds": round(max(ZS) - min(ZS), 3),
    "lowestZ": round(min(ZS), 4),
    "clips": {n: {"length": CLIPS[n]["length"], "loop": CLIPS[n]["loop"], "priority": CLIPS[n]["priority"],
                  "keys": len(CLIPS[n]["keys"]), "lowestZ": GROUND[n]} for n in ORDER},
    "fbx": os.path.relpath(EXPORT, REPO).replace("\\", "/"),
}
assert REPORT["tris"] < 2500, "too many triangles: %d" % REPORT["tris"]
assert REPORT["boneCount"] <= 24
assert abs(REPORT["lowestZ"]) < 0.01, "the feet do not rest on Z = 0"
assert min(GROUND.values()) >= 0, "a clip dips under the ground: %s" % GROUND

if RENDER:
    render_all(SCENE, ARM)
REPORT["actions"] = make_actions(ARM)
with open(REPORT_JSON, "w", encoding="utf-8", newline="\n") as f:
    json.dump(REPORT, f, indent=1)
bpy.ops.wm.save_as_mainfile(filepath=BLEND, check_existing=False)
print("GATO_REPORT " + json.dumps({k: REPORT[k] for k in ("boneCount", "verts", "tris", "heightStuds", "lowestZ", "clips")}))

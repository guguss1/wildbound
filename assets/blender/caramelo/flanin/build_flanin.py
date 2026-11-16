"""Flanin, the hopping flan of the Caramelo biome.

Low-poly, faceted custard creature about 8 studs tall: an eight-sided truncated-cone flan built as three stacked
rings (Base, Mid, Top) so it can wobble like jelly without bone scaling, a caramel cap with drips, a whipped-cream
rosette and a cherry. Original face: two tall oval eyes with a shine, blush, a small open mouth; two caramel-drop
horns, two custard stub arms and a caramel droplet tail. No whiskers, no stripes, no lettering.

Units: 1 Blender unit = 1 stud. The creature faces -Y; its left side is +X; the base rests on Z = 0. Roblox reads
the FBX as X = -x, Y = z, Z = y, so its front is -Z there.

Every mesh is skinned and every vertex belongs to exactly one bone (rigid skinning); every bone owns at least one
vertex (Root owns a small gem hidden inside the base). No mesh is named like a bone.

Clips are data (CLIPS below): { name: { length, loop, priority, keys: [ { t, pose: { bone: [dx, dy, dz, rx, ry, rz] } } ] } }.
The six numbers are a translation in studs and Euler degrees (applied as Rx * Ry * Rz, like CFrame.Angles) in ROBLOX
model axes (X = creature's right, Y = up, Z = back), relative to the bone's rest pose and carried by its parent, the
same convention as tortidragon/clips_to_rbxmx.py (Transform = rest:Inverse() * (T * R) * rest). A bone missing from a
key is at rest in that key.

Run:  blender --background --python-exit-code 1 --python build_flanin.py
It rebuilds everything from nothing, exports the FBX, writes the clips and report JSON, renders the turnaround and
the pose sheet, and saves the .blend. Set the environment variable FLANIN_NO_RENDER=1 to skip the renders.
"""
import json
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

SLUG = "flanin"
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(HERE))))
EXPORT_DIR = os.path.join(REPO, "assets", "exports", "caramelo")
FBX_PATH = os.path.join(EXPORT_DIR, SLUG + "-v1.fbx")
BLEND_PATH = os.path.join(HERE, SLUG + "-v1.blend")
CLIPS_PATH = os.path.join(HERE, SLUG + "-clips.json")
REPORT_PATH = os.path.join(HERE, SLUG + "-report.json")
TURNAROUND_PATH = os.path.join(HERE, SLUG + "-turnaround.png")
POSES_PATH = os.path.join(HERE, SLUG + "-poses.png")
RENDER = not os.environ.get("FLANIN_NO_RENDER")

BONES = [
    # name, head, tail, parent
    ("Root", (0, 0, 0), (0, 0, 1), None),
    ("Base", (0, 0, 0), (0, 0, 1.5), "Root"),
    ("Mid", (0, 0, 1.5), (0, 0, 3.9), "Base"),
    ("Top", (0, 0, 3.9), (0, 0, 4.9), "Mid"),
    ("Cream", (0, 0, 5.2), (0, 0, 6.4), "Top"),
    ("Cherry", (0, 0, 6.5), (0, 0, 7.6), "Cream"),
    ("Horn_L", (1.25, -1.5, 4.85), (1.55, -1.7, 6.0), "Top"),
    ("Horn_R", (-1.25, -1.5, 4.85), (-1.55, -1.7, 6.0), "Top"),
    ("Arm_L", (2.6, -0.3, 1.9), (3.5, -0.3, 1.8), "Mid"),
    ("Arm_R", (-2.6, -0.3, 1.9), (-3.5, -0.3, 1.8), "Mid"),
    ("Tail", (0, 2.9, 0.8), (0, 4.4, 2.0), "Base"),
    ("Lids", (0, -2.5, 3.0), (0, -2.5, 3.6), "Mid"),
]

COLOURS = {
    "Body": "#F6BC62", "Caramel": "#8A4A1E", "Amber": "#D9842A", "Whip": "#FFEBDA", "Fruit": "#EC2F5C",
    "Eye": "#3B2013", "Shine": "#FFFFFF", "Blush": "#F7909C",
}

# The flan's silhouette: (z, corner radius) of the eight-sided body.
PROFILE = [(0.0, 2.95), (0.35, 3.2), (1.5, 3.02), (3.9, 2.5), (4.9, 2.2)]
FLAT = math.cos(math.pi / 8)  # a flat face sits at corner radius * FLAT


def hex_rgba(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c) + (1.0,)


def euler(rot):
    from mathutils import Euler
    return Euler(tuple(math.radians(a) for a in rot), "XYZ").to_matrix().to_4x4()


def radius(z):
    for (z0, r0), (z1, r1) in zip(PROFILE, PROFILE[1:]):
        if z <= z1:
            return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
    return PROFILE[-1][1]


def surface(angle, z, off=0.0):
    """A point on the body's skin. angle in degrees: 0 = front (-Y), 90 = the creature's left (+X)."""
    delta = math.radians(((angle + 22.5) % 45.0) - 22.5)
    d = radius(z) * FLAT / math.cos(delta) + off
    a = math.radians(angle)
    return Vector((d * math.sin(a), -d * math.cos(a), z))


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

    def lathe(self, bone, profile, segments=8, phase=22.5, centre=(0, 0)):
        """Stacked rings around Z through `centre`: profile is [(z, corner radius), ...] from bottom to top, capped."""
        loops = []
        for z, r in profile:
            loop = []
            for i in range(segments):
                a = math.radians(phase + 360.0 * i / segments)
                loop.append(self.bm.verts.new((centre[0] + r * math.cos(a), centre[1] + r * math.sin(a), z)))
            loops.append(loop)
        for lower, upper in zip(loops, loops[1:]):
            for i in range(segments):
                j = (i + 1) % segments
                self.bm.faces.new((lower[i], lower[j], upper[j], upper[i]))
        self.bm.faces.new(list(reversed(loops[0])))
        self.bm.faces.new(loops[-1])
        self._pin([v for loop in loops for v in loop], bone)


def mirror(x, side):
    return x if side == "L" else -x


# Caramel drips: (angle, length) all round; short over the face so the eyes stay clear.
DRIPS = [(0, 0.7), (22.5, 0.4), (45, 1.0), (67.5, 0.55), (90, 1.25), (112.5, 0.5), (135, 0.95), (157.5, 0.6),
         (180, 1.2), (202.5, 0.55), (225, 1.0), (247.5, 0.5), (270, 1.2), (292.5, 0.6), (315, 0.95), (337.5, 0.4)]
FACE_TILT = -math.degrees(math.atan((3.02 - 2.5) * FLAT / 2.4))  # the front facet of the Mid ring leans back


def build_pieces():
    p = {name: Piece(name) for name in COLOURS}
    body, caramel, amber, cream, cherry = p["Body"], p["Caramel"], p["Amber"], p["Whip"], p["Fruit"]
    tilt = (FACE_TILT, 0, 0)

    # the flan: three stacked rings. Mid and Top carry a skirt tucked inside the ring below, so a ring that
    # lifts or tilts never opens a gap. Root owns a thin caramel puddle hidden under the base: it stays on the
    # floor when the flan hops, like a sticky footprint
    body.lathe("Base", [(0.0, 2.95), (0.35, 3.2), (1.5, 3.02)])
    body.lathe("Mid", [(1.0, 2.6), (1.5, 3.02), (3.9, 2.5)])
    body.lathe("Top", [(3.4, 2.1), (3.9, 2.5), (4.9, 2.2)])
    amber.lathe("Root", [(0.01, 2.7), (0.06, 2.5)])

    # caramel cap over the top rim, with drips running down the sides
    caramel.lathe("Top", [(4.3, radius(4.3) + 0.1), (4.92, 2.32), (5.2, 1.95)])
    for angle, length in DRIPS:
        zb = 4.4 - length
        caramel.prism("Top", surface(angle, 4.5, 0.02), surface(angle, zb, 0.06), 0.4, 0.22, 6)
        caramel.gem("Top", surface(angle, zb, 0.08), (0.27, 0.27, 0.3), 0)

    # whipped-cream rosette: a ring of dollops, a smaller ring, a twisted peak
    cream.lathe("Cream", [(5.15, 1.3), (5.5, 1.35), (5.85, 0.95)], 8, 0)
    for i in range(8):
        a = math.radians(45 * i)
        cream.gem("Cream", (1.2 * math.cos(a), 1.2 * math.sin(a), 5.52), (0.5, 0.5, 0.42), 0, (0, 0, 45 * i))
    cream.lathe("Cream", [(5.8, 0.8), (6.25, 0.62)], 6, 30)
    for i in range(6):
        a = math.radians(60 * i + 30)
        cream.gem("Cream", (0.68 * math.cos(a), 0.68 * math.sin(a), 6.05), (0.42, 0.42, 0.36), 0, (0, 0, 60 * i))
    cream.prism("Cream", (0, 0, 6.2), (0, 0, 6.85), 0.58, 0.16, 6)

    # cherry with a stem and a shine
    cherry.gem("Cherry", (0, 0, 7.05), (0.62, 0.62, 0.6), 1)
    caramel.prism("Cherry", (0, 0, 7.5), (0.1, 0, 7.82), 0.07, 0.06, 4)
    caramel.prism("Cherry", (0.1, 0, 7.8), (0.38, 0, 7.97), 0.06, 0.05, 4)
    p["Shine"].gem("Cherry", (0.24, -0.43, 7.3), (0.13, 0.08, 0.15), 0)

    # face on the Mid ring: tall oval eyes with a shine, blush, a small open mouth
    eye_y = surface(0, 3.0).y
    for side in "LR":
        x = mirror(0.7, side)
        p["Eye"].gem("Mid", (x, eye_y - 0.02, 3.0), (0.27, 0.07, 0.4), 1, tilt)
        p["Shine"].gem("Mid", (x + 0.09, surface(0, 3.17).y - 0.1, 3.17), (0.09, 0.04, 0.12), 0, tilt)
        p["Shine"].gem("Mid", (x - 0.1, surface(0, 2.82).y - 0.09, 2.82), (0.05, 0.03, 0.06), 0, tilt)
        p["Blush"].gem("Mid", (mirror(0.8, side), surface(0, 2.42).y - 0.01, 2.42), (0.22, 0.045, 0.13), 0, tilt)
        # eyelids: a custard pad with a dark closed-eye line, hidden inside the body at rest and pushed out
        # through the skin to blink or sleep (Roblox bones cannot scale an eye shut)
        body.gem("Lids", (x, eye_y + 0.5, 3.0), (0.37, 0.14, 0.5), 1, tilt)
        p["Eye"].box("Lids", (x, eye_y + 0.5 - 0.135, 2.86), (0.46, 0.05, 0.09), tilt)
    p["Eye"].gem("Mid", (0, surface(0, 2.5).y - 0.02, 2.5), (0.15, 0.05, 0.17), 0, tilt)

    # caramel-drop horns on the top rim, stub arms at the sides, a caramel droplet for a tail
    for side in "LR":
        hx = mirror(1.25, side)
        amber.gem("Horn_%s" % side, (hx, -1.5, 5.02), (0.47, 0.43, 0.4), 0)
        amber.prism("Horn_%s" % side, (hx, -1.5, 5.15), (hx + mirror(0.22, side), -1.62, 5.85), 0.38, 0.05, 5)
        ax = mirror(surface(90, 1.9).x, side)
        body.gem("Arm_%s" % side, (ax + mirror(0.28, side), -0.3, 1.88), (0.55, 0.45, 0.38), 1, (0, mirror(12, side), 0))
    amber.gem("Tail", (0, 3.4, 0.78), (0.78, 0.86, 0.75), 1)
    amber.prism("Tail", (0, 3.6, 1.2), (0, 4.05, 2.05), 0.52, 0.05, 6)
    return p


def own_scene():
    """Background run: start from an empty file. Inside an open Blender: a scene of its own, others untouched."""
    if bpy.app.background:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        scene = bpy.context.scene
        scene.name = "Flanin"
        return scene
    scene = bpy.data.scenes.get("Flanin") or bpy.data.scenes.new("Flanin")
    for o in list(scene.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.window.scene = scene
    return scene


def build():
    scene = own_scene()
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    arm_data = bpy.data.armatures.new("FlaninRig")
    arm = bpy.data.objects.new("Flanin", arm_data)
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
        piece.bm.normal_update()
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
        bsdf.inputs["Roughness"].default_value = 0.6
        mat.diffuse_color = hex_rgba(COLOURS[name])
        me.materials.append(mat)
        for poly in me.polygons:
            poly.use_smooth = False
        obj.parent = arm
        mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
        meshes.append(obj)
    # rigid skinning: one bone per vertex, every bone used, no mesh named like a bone
    bone_names = {b[0] for b in BONES}
    used = set()
    for obj in meshes:
        assert obj.name not in bone_names, "mesh named like a bone: %s" % obj.name
        names = {g.index: g.name for g in obj.vertex_groups}
        for v in obj.data.vertices:
            assert len(v.groups) == 1 and abs(v.groups[0].weight - 1.0) < 1e-6, \
                "%s vertex %d is not pinned to exactly one bone" % (obj.name, v.index)
            used.add(names[v.groups[0].group])
    missing = [b[0] for b in BONES if b[0] not in used]
    assert not missing, "bones with no skinned vertex: %s" % missing
    assert used <= bone_names, "vertex groups that are not bones: %s" % (used - bone_names)
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


# ---------------------------------------------------------------------------------------------------------------
# Clips. Values are in Roblox model axes: X = the creature's right, Y = up, Z = back (front is -Z).
# "side" amounts are positive toward the creature's left; "fwd" amounts are positive toward its front.
# ---------------------------------------------------------------------------------------------------------------
def merge(*poses):
    out = {}
    for pose in poses:
        for bone, v in pose.items():
            s = out.setdefault(bone, [0.0] * 6)
            for i in range(6):
                s[i] += v[i] if i < len(v) else 0
    return out


def sway(base=0, mid=0, top=0, cream=0, cherry=0):
    """Sideways jelly shear: each layer slides and tilts on the one below. Offset the five amounts to make it lag."""
    return {"Base": [-0.05 * base, 0, 0, 0, 0, 1.2 * base], "Mid": [-0.3 * mid, 0, 0, 0, 0, 6 * mid],
            "Top": [-0.28 * top, 0, 0, 0, 0, 7 * top], "Cream": [-0.06 * cream, 0, 0, 0, 0, 8 * cream],
            "Cherry": [-0.06 * cherry, 0, 0, 0, 0, 14 * cherry]}


def nod(base=0, mid=0, top=0, cream=0, cherry=0):
    """The same shear front to back (positive = toward the front)."""
    return {"Base": [0, 0, -0.05 * base, -1.2 * base, 0, 0], "Mid": [0, 0, -0.3 * mid, -6 * mid, 0, 0],
            "Top": [0, 0, -0.28 * top, -7 * top, 0, 0], "Cream": [0, 0, -0.06 * cream, -8 * cream, 0, 0],
            "Cherry": [0, 0, -0.06 * cherry, -14 * cherry, 0, 0]}


def squash(mid=0, top=0, cream=0, cherry=0):
    """Fake squash: the upper layers sink into the ones below (negative = stretch; the skirts cover the seams)."""
    return {"Mid": [0, -mid, 0], "Top": [0, -top, 0], "Cream": [0, -cream, 0], "Cherry": [0, -cherry, 0]}


def lift(h):
    return {"Base": [0, h, 0]}


def arms(out=0, up=0):
    return {"Arm_L": [-out, 0, 0, 0, 0, -up], "Arm_R": [out, 0, 0, 0, 0, up]}


def horns(splay=0, fwd=0):
    return {"Horn_L": [0, 0, 0, -fwd, 0, splay], "Horn_R": [0, 0, 0, -fwd, 0, -splay]}


def tail(wag=0, up=0, out=0):
    return {"Tail": [0, 0, out, -up, wag, 0]}


def lids(closed):
    return {"Lids": [0, 0, -0.53 * closed]}


def tremble(a):
    return {"Base": [-0.06 * a, 0, 0], "Mid": [0.13 * a, 0, 0], "Top": [-0.13 * a, 0, 0], "Cream": [0, 0, 0, 0, 0, 2.5 * a],
            "Cherry": [0, 0, 0, 0, 0, -6 * a], "Arm_L": [0, 0.05 * a, 0], "Arm_R": [0, -0.05 * a, 0]}


def idle_pose(t):
    """Jelly wobble: every layer follows the one below about 40 degrees of phase later, sideways and (less) front to back."""
    ph = 2 * math.pi * t / 2.0

    def s(lag, k=1.0):
        return math.sin(k * ph - math.radians(lag))

    def c(lag):
        return 0.35 * math.cos(ph - math.radians(lag))
    blink = 1.0 if 1.05 < t < 1.15 else 0.0
    return merge(sway(s(0), s(40), s(80), s(120), s(160)), nod(c(0), c(40), c(80), c(120), c(160)),
                 squash(0.07 * s(0, 2), 0.07 * s(60, 2), 0.03 * s(120, 2), 0.03 * s(180, 2)),
                 arms(0, 8 * s(60, 2)), horns(5 * s(110), 3 * s(110, 2)), tail(12 * s(30), 4 * s(0, 2)), lids(blink))


REST_POSE = {}
HOP_CROUCH = merge(squash(0.28, 0.22, 0.08, 0.05), arms(0.1, -10), tail(0, -5))
SLIDE = merge({"Base": [0, -0.1, 0, -3, 0, 0], "Mid": [0, -0.1, 0.22, 3, 0, 0], "Top": [0, -0.08, 0.25, 4, 0, 0],
               "Cream": [0, 0, 0.05, 6, 0, 0], "Cherry": [0, 0, 0.05, 12, 0, 0]}, arms(0.35, 15), tail(0, 30), horns(-5, -12))
STIFF = merge(squash(-0.16, -0.14, -0.05, -0.05), arms(0, 30), horns(-8, -10), tail(0, 25))
FLATTEN = merge(lift(-0.8), squash(0.85, 0.5, 0.4, 0.25), arms(0.7, -5), horns(20, 10), tail(0, -15, 0.3))
SLEEP = merge(squash(0.22, 0.16, 0.08, 0.04), lids(1), horns(14, 6), arms(0, -18), sway(0, 0.2, 0.3, 0.5, 0.9),
              tail(15, -8))


def breath(b, late):
    return merge(SLEEP, squash(-0.12 * b, -0.1 * late, -0.03 * late, 0), sway(0, 0, 0, 0, -0.15 * late),
                 arms(0, 6 * b), horns(-3 * late, 0))


CLIP_ORDER = ["Idle", "Walk", "Jump", "Land", "Slide", "Charge", "Wave", "Rest"]
IDLE_TIMES = [0, 0.25, 0.5, 0.75, 1.0, 1.06, 1.14, 1.25, 1.5, 1.75, 2.0]
CLIP_SOURCE = {
    # jelly wobble with a blink
    "Idle": (2.0, True, "Idle", [(t, idle_pose(t)) for t in IDLE_TIMES]),
    # small hops: crouch, push off, apex, squashy contact with the layers thrown sideways, rebound
    "Walk": (0.8, True, "Movement", [
        (0, HOP_CROUCH),
        (0.14, merge(lift(0.35), squash(-0.12, -0.1, 0, -0.05), nod(0.3, 0.5, 0.4, 0, -0.5), arms(0, 10))),
        (0.34, merge(lift(0.9), squash(-0.05, -0.05, -0.03, -0.12), nod(0.2, 0.2, 0, -0.3, -0.6), arms(0.05, 25),
                     tail(0, 20), horns(0, -8))),
        (0.54, merge(squash(0.36, 0.3, 0.14, 0.12), sway(0, 0.25, 0.4, 0.5, 0.8), arms(0.2, -15), tail(0, -10),
                     horns(8, 6))),
        (0.68, merge(squash(-0.1, -0.1, -0.04, -0.1), sway(0, -0.2, -0.3, -0.5, -0.8), arms(0, 12))),
        (0.8, HOP_CROUCH)]),
    # one bigger hop; the arc lives on the Base bone (visual only, the model's root does not move)
    "Jump": (1.0, False, "Action", [
        (0, REST_POSE),
        (0.2, merge(squash(0.45, 0.38, 0.15, 0.1), arms(0.15, -20), horns(10, 8), tail(0, -8))),
        (0.34, merge(lift(1.1), squash(-0.2, -0.18, -0.05, 0.1), arms(0, 35), nod(0.5, 0.4, 0.2, 0, -0.6))),
        (0.56, merge(lift(2.6), squash(-0.08, -0.06, -0.05, -0.15), arms(0.1, 45), tail(0, 25), horns(-6, -10),
                     sway(0, 0.15, 0.2, 0.3, 0.5))),
        (0.82, merge(lift(1.3), squash(-0.22, -0.2, -0.08, -0.2), arms(0.1, 55), tail(0, 35), nod(-0.3, -0.2, 0, 0.3, 0.5))),
        (1.0, merge(squash(0.2, 0.15, 0.05, 0), arms(0.15, 10)))]),
    # squash-like settle, then an overshoot wobble that dies out
    "Land": (0.6, False, "Action", [
        (0, merge(squash(0.55, 0.45, 0.2, 0.12), arms(0.3, -25), horns(12, 8), tail(0, -12))),
        (0.12, merge(squash(-0.2, -0.18, -0.06, -0.2), sway(0, 0.2, 0.3, 0.4, 0.6), arms(0, 20))),
        (0.26, merge(squash(0.22, 0.18, 0.08, 0.08), sway(0, -0.5, -0.7, -0.8, -1.0), arms(0.1, -8))),
        (0.4, merge(squash(-0.06, -0.06, 0, -0.05), sway(0, 0.35, 0.5, 0.6, 0.8))),
        (0.5, merge(squash(0.04, 0.03), sway(0, -0.15, -0.2, -0.3, -0.4))),
        (0.6, REST_POSE)]),
    # leans into the glide with the upper layers dragging behind, swaying gently
    "Slide": (0.8, True, "Movement", [
        (0, merge(SLIDE, sway(0.3, 0.2, 0, -0.2, -0.4), tail(10))),
        (0.2, merge(SLIDE, sway(0, 0.3, 0.3, 0.2, 0), squash(0.05, 0.04))),
        (0.4, merge(SLIDE, sway(-0.3, -0.2, 0, 0.2, 0.4), tail(-10))),
        (0.6, merge(SLIDE, sway(0, -0.3, -0.3, -0.2, 0), squash(0.05, 0.04))),
        (0.8, merge(SLIDE, sway(0.3, 0.2, 0, -0.2, -0.4), tail(10)))]),
    # stiffens (stretches tall, arms and horns up) and trembles harder and harder
    "Charge": (0.6, False, "Action", [
        (0, REST_POSE), (0.12, STIFF), (0.18, merge(STIFF, tremble(0.5))), (0.24, merge(STIFF, tremble(-0.6))),
        (0.3, merge(STIFF, tremble(0.7))), (0.36, merge(STIFF, tremble(-0.8))), (0.42, merge(STIFF, tremble(0.9))),
        (0.48, merge(STIFF, tremble(-1.0))), (0.54, merge(STIFF, tremble(1.0))), (0.6, merge(STIFF, tremble(-1.0)))]),
    # stretches up, drops flat (Top and Mid sink toward the Base, the Base into the floor) and pushes outward
    # with the arms, then springs back and settles; the wave leaves at 0.30 s
    "Wave": (1.2, False, "Action", [
        (0, REST_POSE),
        (0.15, merge(squash(-0.22, -0.2, -0.08, -0.1), arms(0, 40), horns(-5, -8))),
        (0.3, FLATTEN),
        (0.45, merge(FLATTEN, lift(-0.08), squash(0.05, 0.03), arms(0.25, 5), tremble(0.6))),
        (0.75, merge(FLATTEN, arms(0.15, 0), sway(0, 0.2, 0.3, 0.3, 0.5), tremble(-0.4))),
        (0.95, merge(lift(0.25), squash(-0.25, -0.22, -0.1, -0.3), arms(0, 35), sway(0, -0.2, -0.3, -0.4, -0.6))),
        (1.08, merge(squash(0.12, 0.1, 0.04, 0.05), sway(0, 0.2, 0.3, 0.4, 0.6))),
        (1.2, REST_POSE)]),
    # asleep: settled and slumped to one side, eyes shut, slow breathing with the top layers a beat late
    "Rest": (3.0, True, "Idle", [
        (0, breath(0, 0.2)), (0.75, breath(0.7, 0.3)), (1.5, breath(1.0, 0.9)), (2.25, breath(0.3, 0.8)),
        (3.0, breath(0, 0.2))]),
}


def clips_data():
    out = {}
    for name in CLIP_ORDER:
        length, loop, priority, keys = CLIP_SOURCE[name]
        assert abs(keys[-1][0] - length) < 1e-9 and keys[0][0] == 0, name
        out[name] = {"length": length, "loop": loop, "priority": priority, "keys": [
            {"t": round(t, 4), "pose": {b: [round(x + 0.0, 4) for x in pose[b]] for b, _, _, _ in BONES if b in pose
                                        and any(abs(x) > 1e-9 for x in pose[b])}} for t, pose in keys]}
        if loop:
            assert out[name]["keys"][0]["pose"] == out[name]["keys"][-1]["pose"], "%s does not loop" % name
    return out


# ---- Blender preview of the clip data (the same maths Roblox applies, converted to Blender axes) ----
TO_BLENDER = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))  # Roblox (X, Y, Z) -> Blender (-X, Z, Y)


def ease(u):  # Roblox cubic in-out
    return 4 * u * u * u if u < 0.5 else 1 - (-2 * u + 2) ** 3 / 2


def sample(clip, t):
    keys = clip["keys"]
    if t <= keys[0]["t"]:
        return keys[0]["pose"]
    for a, b in zip(keys, keys[1:]):
        if t <= b["t"]:
            u = ease((t - a["t"]) / (b["t"] - a["t"]))
            out = {}
            for bone in set(a["pose"]) | set(b["pose"]):
                va, vb = a["pose"].get(bone, [0] * 6), b["pose"].get(bone, [0] * 6)
                out[bone] = [x + (y - x) * u for x, y in zip(va, vb)]
            return out
    return keys[-1]["pose"]


def apply_pose(arm, pose):
    for pb in arm.pose.bones:
        v = pose.get(pb.name)
        if not v:
            pb.matrix_basis = Matrix.Identity(4)
            continue
        delta = Matrix.Translation(v[0:3]) @ Matrix.Rotation(math.radians(v[3]), 4, "X") \
            @ Matrix.Rotation(math.radians(v[4]), 4, "Y") @ Matrix.Rotation(math.radians(v[5]), 4, "Z")
        delta = TO_BLENDER @ delta @ TO_BLENDER.inverted()
        rest = pb.bone.matrix_local.to_3x3().to_4x4()
        pb.matrix_basis = rest.inverted() @ delta @ rest
    bpy.context.view_layer.update()


# ---- renders ----
BACKGROUND = (0.105, 0.1, 0.125)


def setup_render(scene):
    scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in \
        {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items} else "BLENDER_EEVEE_NEXT"
    scene.view_settings.view_transform = "Standard"
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("FlaninWorld")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = BACKGROUND + (1.0,)
    bg.inputs[1].default_value = 1.0
    scene.world = world
    lights = []
    for name, energy, rot, colour in (("Key", 3.2, (52, 0, -38), (1.0, 0.97, 0.92)), ("Fill", 1.3, (65, 0, 60), (0.85, 0.9, 1.0)),
                                      ("Rim", 2.4, (-62, 0, 150), (1.0, 0.9, 0.95)), ("Under", 0.5, (150, 0, 0), (1.0, 0.95, 0.9))):
        data = bpy.data.lights.new(name, "SUN")
        data.energy, data.color, data.angle = energy, colour, math.radians(8)
        obj = bpy.data.objects.new(name, data)
        obj.rotation_euler = tuple(math.radians(a) for a in rot)
        scene.collection.objects.link(obj)
        lights.append(obj)
    cam_data = bpy.data.cameras.new("FlaninCam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("FlaninCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    text_data = bpy.data.curves.new("FlaninLabel", "FONT")
    text_data.align_x, text_data.align_y = "CENTER", "CENTER"
    label = bpy.data.objects.new("FlaninLabel", text_data)
    mat = bpy.data.materials.new("FlaninLabelMat")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    em, outp = nodes.new("ShaderNodeEmission"), nodes.new("ShaderNodeOutputMaterial")
    em.inputs[0].default_value = (1, 1, 1, 1)
    mat.node_tree.links.new(em.outputs[0], outp.inputs[0])
    text_data.materials.append(mat)
    scene.collection.objects.link(label)
    return cam, label, lights


def shoot(scene, cam, label, path, azimuth, elevation, target_z, scale, size, text):
    """azimuth 0 = the camera in front of the creature (at -Y), 90 = at its left (+X)."""
    a, e = math.radians(azimuth), math.radians(elevation)
    direction = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    target = Vector((0, 0, target_z))
    cam.location = target + direction * 60
    cam.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
    cam.data.ortho_scale = scale
    cam.data.clip_end = 200
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    bpy.context.view_layer.update()
    label.data.body = text
    label.data.size = scale * 0.05
    label.hide_render = not text
    height = scale if size[1] >= size[0] else scale * size[1] / size[0]
    label.matrix_world = cam.matrix_world @ Matrix.Translation((0, -height * 0.455, -8))
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
    h, w = tiles[0].shape[:2]
    rows = (len(tiles) + columns - 1) // columns
    sheet = np.zeros((rows * h, columns * w, 4), dtype=np.float32)
    sheet[:, :, :3] = tiles[0][0, 0, :3]
    sheet[:, :, 3] = 1.0
    for i, tile in enumerate(tiles):
        r, c = divmod(i, columns)
        y0 = (rows - 1 - r) * h  # image rows run bottom to top
        sheet[y0:y0 + h, c * w:(c + 1) * w] = tile
    out = bpy.data.images.new("FlaninSheet", columns * w, rows * h, alpha=True)
    out.pixels.foreach_set(sheet.ravel())
    out.filepath_raw = out_path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)
    for path in paths:
        os.remove(path)


def stage(scene):
    """A floor for the pose sheet only: it shows the hops and hides what sinks below Z = 0."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=48, radius1=5.2, radius2=5.2, depth=1.0,
                          matrix=Matrix.Translation((0, 0, -0.5)))
    me = bpy.data.meshes.new("FlaninStage")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("FlaninStage", me)
    mat = bpy.data.materials.new("FlaninStageMat")
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs[0].default_value = (0.2, 0.17, 0.2, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.9
    me.materials.append(mat)
    scene.collection.objects.link(obj)
    return obj


TURNAROUND = [("FRONT", 0, 6), ("LEFT SIDE", 90, 6), ("BACK", 180, 6), ("THREE-QUARTER", 35, 14)]
# label, clip, time, azimuth
POSE_SHEET = [
    ("IDLE 0.50 s", "Idle", 0.5, 0), ("IDLE 1.50 s", "Idle", 1.5, 0), ("WALK crouch", "Walk", 0.0, 30),
    ("WALK apex", "Walk", 0.34, 30), ("JUMP apex", "Jump", 0.56, 30), ("LAND squash", "Land", 0.0, 30),
    ("LAND wobble", "Land", 0.26, 0), ("SLIDE", "Slide", 0.0, 62), ("CHARGE", "Charge", 0.48, 20),
    ("WAVE flat", "Wave", 0.45, 30), ("WAVE spring", "Wave", 0.95, 30), ("REST asleep", "Rest", 1.5, 25),
]


def render_all(scene, arm, clips):
    cam, label, lights = setup_render(scene)
    apply_pose(arm, {})
    paths = []
    for i, (text, azimuth, elevation) in enumerate(TURNAROUND):
        paths.append(os.path.join(HERE, "_turn%d.png" % i))
        shoot(scene, cam, label, paths[-1], azimuth, elevation, 4.1, 11.2, (350, 470), text)
    montage(paths, 4, TURNAROUND_PATH); floor = stage(scene)
    paths = []
    for i, (text, clip, t, azimuth) in enumerate(POSE_SHEET):
        apply_pose(arm, sample(clips[clip], t))
        paths.append(os.path.join(HERE, "_pose%d.png" % i))
        shoot(scene, cam, label, paths[-1], azimuth, 8, 4.6, 13.4, (350, 400), text)
    montage(paths, 4, POSES_PATH)
    apply_pose(arm, {})
    bpy.data.objects.remove(label, do_unlink=True); bpy.data.objects.remove(floor, do_unlink=True)


# ---------------------------------------------------------------------------------------------------------------
SCENE, ARM, MESHES = build()
CLIPS = clips_data()
for _clip in CLIPS.values():
    for _key in _clip["keys"]:
        assert set(_key["pose"]) <= {b[0] for b in BONES}
export(FBX_PATH, ARM, MESHES)
with open(CLIPS_PATH, "w", encoding="utf-8", newline="\n") as f:
    json.dump(CLIPS, f, indent=1)
    f.write("\n")
for _m in MESHES:
    _m.data.calc_loop_triangles()
TOP_Z = max((m.matrix_world @ v.co).z for m in MESHES for v in m.data.vertices)
LOW_Z = min((m.matrix_world @ v.co).z for m in MESHES for v in m.data.vertices)
STATS = {
    "slug": SLUG, "bones": len(BONES), "boneNames": [b[0] for b in BONES], "meshes": len(MESHES),
    "meshNames": [m.name for m in MESHES], "verts": sum(len(m.data.vertices) for m in MESHES),
    "tris": sum(len(m.data.loop_triangles) for m in MESHES), "heightStuds": round(TOP_Z - LOW_Z, 3),
    "lowestZ": round(LOW_Z, 3), "clips": {n: {"length": c["length"], "loop": c["loop"], "priority": c["priority"],
                                              "keys": len(c["keys"])} for n, c in CLIPS.items()},
    "fbx": os.path.relpath(FBX_PATH, REPO).replace("\\", "/"),
}
assert STATS["tris"] < 2500 and STATS["bones"] <= 24, STATS
if RENDER:
    render_all(SCENE, ARM, CLIPS)
if bpy.app.background:
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
with open(REPORT_PATH, "w", encoding="utf-8", newline="\n") as f:
    json.dump(STATS, f, indent=1)
    f.write("\n")
print("FLANIN", json.dumps(STATS))

"""Mielita, the bee-kitten of the Caramelo biome: a small hovering bee creature with kitten charm.

About 4.5 studs tall, floating with its paws about 1.5 studs above the ground. A round cream head with two
pointed ears, two curly antennae ending in honey drops, large round eyes, a tiny heart nose and a small smile;
a honey ruff, an egg-shaped abdomen with two brown bands and a short honey-drop stinger; two pairs of pale
wings and four small dangling paws. The design is original on purpose (see the task brief): no whiskers, no
forehead stripes, no striped tail, no closed-arc eyes.

Units: 1 Blender unit = 1 stud. The creature faces -Y; its left side is +X. Roblox reads the FBX as
X = -x, Y = z, Z = y, so its front is -Z there.

Every mesh is skinned, and every vertex belongs to exactly one bone (rigid skinning); each of the 16 bones owns
at least one piece (Root owns a small gem hidden inside the thorax). No mesh is named like a bone.

Clips are data (CLIPS below): per key, per bone, [dx, dy, dz, rx, ry, rz] = studs and XYZ Euler degrees in
Roblox model axes (X = creature's right, Y = up, Z = back), relative to the bone's rest pose, composed as
rest^-1 * (T * Rx*Ry*Rz) * rest like the Tortidragon family (tortidragon/clips_to_rbxmx.py).
Signs: rx > 0 pitches the nose up, ry > 0 turns left, rz > 0 lifts the right side (banks left).

Run:  blender --background --python build_mielita.py
It rebuilds everything from nothing, saves mielita-v1.blend, exports assets/exports/caramelo/mielita-v1.fbx,
writes mielita-clips.json and mielita-report.json, and renders mielita-turnaround.png and mielita-poses.png.
"""
import json
import math
import os

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

SLUG = "mielita"
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
EXPORT = os.path.join(REPO, "assets", "exports", "caramelo", SLUG + "-v1.fbx")
RENDER = globals().get("MIELITA_RENDER", True)


def side_bones(s, x):
    return [
        ("Antenna_%s" % s, (0.30 * x, -1.10, 4.70), (0.44 * x, -1.20, 5.50), "Head"),
        ("Ear_%s" % s, (0.74 * x, -0.80, 4.45), (1.02 * x, -0.76, 5.20), "Head"),
        ("Wing_%s_Front" % s, (0.45 * x, 0.25, 3.95), (1.70 * x, 0.90, 5.45), "Body"),
        ("Wing_%s_Back" % s, (0.45 * x, 0.70, 3.80), (1.75 * x, 1.45, 4.35), "Body"),
        ("Paw_F%s" % s, (0.50 * x, -0.55, 2.35), (0.50 * x, -0.60, 1.60), "Body"),
        ("Paw_B%s" % s, (0.62 * x, 0.45, 2.30), (0.62 * x, 0.42, 1.55), "Body"),
    ]


BONES = [
    # name, head, tail, parent
    ("Root", (0, 0, 0), (0, 0, 1), None),
    ("Body", (0, 0, 3.0), (0, 0, 3.8), "Root"),
    ("Head", (0, -0.5, 3.45), (0, -0.5, 4.45), "Body"),
    ("Abdomen", (0, 0.5, 3.0), (0, 2.0, 2.85), "Body"),
] + side_bones("L", 1) + side_bones("R", -1)
BONE_HEAD = {b[0]: Vector(b[1]) for b in BONES}
BONE_PARENT = {b[0]: b[3] for b in BONES}

COLOURS = {
    "Fur": "#FFE9BE", "Honey": "#F8B526", "Band": "#5B3417", "WingPlate": "#FBF4DF", "WingGlass": "#A6DDF2",
    "Eye": "#2E1A10", "Shine": "#FFFFFF", "Pink": "#F78DB0", "Drop": "#F28C13",
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

    def plate(self, bone, a, b, half_width, half_thick, facing, shift=0.0, subdiv=1):
        """A thin faceted leaf from a to b; its flat faces look along `facing` (made square to the axis)."""
        a, b = Vector(a), Vector(b)
        d = (b - a).normalized()
        n = Vector(facing)
        n = (n - n.dot(d) * d).normalized()
        w = d.cross(n)
        half_len = (b - a).length / 2
        centre = (a + b) / 2 + n * shift
        m = Matrix((
            (w.x * half_width, n.x * half_thick, d.x * half_len, centre.x),
            (w.y * half_width, n.y * half_thick, d.y * half_len, centre.y),
            (w.z * half_width, n.z * half_thick, d.z * half_len, centre.z),
            (0, 0, 0, 1)))
        res = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=1.0, matrix=m)
        self._pin(res["verts"], bone)


def lerp(a, b, t):
    return Vector(a) + (Vector(b) - Vector(a)) * t


def build_pieces():
    p = {name: Piece(name) for name in COLOURS}
    fur, honey, band, pink, drop = p["Fur"], p["Honey"], p["Band"], p["Pink"], p["Drop"]

    # thorax: a honey ruff, with a cream chest tuft under the chin; Root owns a gem hidden inside
    honey.gem("Body", (0, 0.05, 3.0), (1.22, 1.05, 1.15), 1)
    honey.gem("Root", (0, 0.1, 3.0), (0.2, 0.2, 0.2), 0)
    fur.gem("Body", (0, -0.62, 2.62), (0.62, 0.5, 0.5), 1)
    for i in range(7):  # fluffy collar tufts behind the head
        ang = math.radians(-90 + i * 30)
        x, z = math.cos(ang + math.pi / 2) * 1.02, math.sin(ang + math.pi / 2) * 0.98
        honey.prism("Body", (x * 0.8, 0.1, 3.05 + z * 0.8), (x * 1.22, 0.32, 3.05 + z * 1.22), 0.3, 0.04, 5)

    # head: a round cream ball with a small fluff on top
    fur.gem("Head", (0, -0.9, 3.75), (1.27, 1.1, 1.1), 2)
    for x, lean in ((0, 0), (0.17, 0.12), (-0.17, -0.12)):
        fur.prism("Head", (x, -1.25, 4.72), (x + lean, -1.42, 5.02 - abs(x) * 0.5), 0.15, 0.02, 4)
    # cheeks puff a little: kitten charm without whiskers
    for s in (1, -1):
        fur.gem("Head", (0.6 * s, -1.5, 3.42), (0.48, 0.42, 0.38), 1)

    # face: large round eyes with a shine, a tiny heart nose, a small smile, round blush
    for s in (1, -1):
        n = Vector((0.3 * s, -0.94, 0.1)).normalized()
        c = Vector((0.47 * s, -1.93, 3.9))
        p["Eye"].prism("Head", c - n * 0.07, c + n * 0.05, 0.36, 0.31, 12)
        hi = c + n * 0.06 + Vector((-0.11, 0, 0.13))  # both shines sit on the same side: the light comes from one place
        p["Shine"].prism("Head", hi - n * 0.02, hi + n * 0.02, 0.115, 0.1, 8)
        lo = c + n * 0.06 + Vector((0.12, 0, -0.14))
        p["Shine"].prism("Head", lo - n * 0.02, lo + n * 0.02, 0.055, 0.045, 6)
        pink.gem("Head", (0.95 * s, -1.66, 3.5), (0.2, 0.09, 0.14), 0, (0, 0, 42 * s))
        pink.gem("Head", (0.055 * s, -2.0, 3.6), (0.075, 0.06, 0.075), 0)
        band.box("Head", (0.115 * s, -1.99, 3.375), (0.15, 0.06, 0.05), (0, -32 * s, 0))
    pink.prism("Head", (0, -2.0, 3.6), (0, -2.0, 3.46), 0.125, 0.0, 4)
    band.box("Head", (0, -2.0, 3.34), (0.13, 0.06, 0.05))

    # ears: small pointed pyramids, pink inside
    for s, side in ((1, "L"), (-1, "R")):
        fur.prism("Ear_" + side, (0.72 * s, -0.82, 4.42), (1.02 * s, -0.76, 5.24), 0.42, 0.03, 4)
        pink.prism("Ear_" + side, (0.75 * s, -0.98, 4.55), (0.99 * s, -0.86, 5.08), 0.24, 0.02, 4)

    # antennae: a brown stalk that curls forward and ends in a honey drop
    for s, side in ((1, "L"), (-1, "R")):
        bone = "Antenna_" + side
        pts = [(0.30 * s, -1.10, 4.70), (0.44 * s, -1.18, 5.42), (0.52 * s, -1.42, 5.82), (0.54 * s, -1.74, 5.86),
               (0.54 * s, -1.9, 5.7)]
        for a, b in zip(pts, pts[1:]):
            band.prism(bone, a, b, 0.075, 0.075, 5)
        drop.gem(bone, (0.54 * s, -1.92, 5.5), (0.21, 0.21, 0.2), 1)
        drop.prism(bone, (0.54 * s, -1.92, 5.62), (0.54 * s, -1.9, 5.84), 0.15, 0.03, 5)

    # abdomen: an egg of stacked rings, honey with two brown bands, and a short honey-drop stinger
    a0, a1 = (0, 0.3, 3.04), (0, 2.6, 2.8)
    profile = [(0.0, 0.9), (0.17, 1.2), (0.35, 1.33), (0.52, 1.31), (0.68, 1.13), (0.82, 0.84), (0.93, 0.46)]
    ring_colour = [honey, band, honey, band, honey, honey]
    for (t0, r0), (t1, r1), mesh in zip(profile, profile[1:], ring_colour):
        mesh.prism("Abdomen", lerp(a0, a1, t0), lerp(a0, a1, t1), r0, r1, 10)
    drop.gem("Abdomen", lerp(a0, a1, 0.97), (0.36, 0.34, 0.36), 1)
    drop.prism("Abdomen", lerp(a0, a1, 1.02), lerp(a0, a1, 1.2), 0.26, 0.03, 6)

    # wings: thin cream leaves with a pale-blue glassy panel, large front pair and small back pair
    for s, side in ((1, "L"), (-1, "R")):
        for name, a, b, hw in (("Wing_%s_Front" % side, (0.45 * s, 0.25, 3.95), (1.78 * s, 0.95, 5.5), 0.62),
                               ("Wing_%s_Back" % side, (0.45 * s, 0.70, 3.80), (1.80 * s, 1.5, 4.36), 0.44)):
            facing = (-0.45 * s, -1.0, 0.25)
            p["WingPlate"].plate(name, a, b, hw, 0.05, facing)
            p["WingGlass"].plate(name, lerp(a, b, 0.2), lerp(a, b, 0.9), hw * 0.52, 0.075, facing, 0.0, 1)

    # paws: four small dangling stubs with a round foot
    for s, side in ((1, "L"), (-1, "R")):
        for bone, x, y in (("Paw_F" + side, 0.5 * s, -0.55), ("Paw_B" + side, 0.62 * s, 0.45)):
            fur.prism(bone, (x, y, 2.4), (x, y - 0.04, 1.8), 0.2, 0.22, 6)
            fur.gem(bone, (x, y - 0.08, 1.73), (0.27, 0.31, 0.23), 1)
            pink.gem(bone, (x, y - 0.3, 1.66), (0.11, 0.07, 0.09), 0)
    return p


# ---------------------------------------------------------------- clips (data)
def merge(*poses):
    out = {}
    for pose in poses:
        for bone, v in pose.items():
            s = out.setdefault(bone, [0.0] * 6)
            for i in range(6):
                s[i] += v[i] if i < len(v) else 0
    return out


def body(dx=0, dy=0, dz=0, rx=0, ry=0, rz=0):
    return {"Body": [dx, dy, dz, rx, ry, rz]}


def head(rx=0, ry=0, rz=0):
    return {"Head": [0, 0, 0, rx, ry, rz]}


def abdomen(rx=0, ry=0):
    """rx < 0 lifts the stinger, ry swings it sideways."""
    return {"Abdomen": [0, 0, 0, rx, ry, 0]}


def wings(front, back=None, sweep=0, sweep_back=None):
    """front/back: flap angle in degrees (up is positive); sweep: tilt backwards."""
    back = front * 0.75 if back is None else back
    sweep_back = sweep if sweep_back is None else sweep_back
    return {"Wing_L_Front": [0, 0, 0, sweep, 0, -front], "Wing_R_Front": [0, 0, 0, sweep, 0, front],
            "Wing_L_Back": [0, 0, 0, sweep_back, 0, -back], "Wing_R_Back": [0, 0, 0, sweep_back, 0, back]}


def paws(front=0, back=0, splay=0):
    """rx > 0 swings a paw forward; splay spreads them sideways."""
    return {"Paw_FL": [0, 0, 0, front, 0, -splay], "Paw_FR": [0, 0, 0, front, 0, splay],
            "Paw_BL": [0, 0, 0, back, 0, -splay], "Paw_BR": [0, 0, 0, back, 0, splay]}


def antennae(rx=0, rz=0):
    """rx > 0 blows them back, rz sways both to one side."""
    return {"Antenna_L": [0, 0, 0, rx, 0, rz], "Antenna_R": [0, 0, 0, rx, 0, rz]}


def ears(rx=0, spread=0):
    return {"Ear_L": [0, 0, 0, rx, 0, -spread], "Ear_R": [0, 0, 0, rx, 0, spread]}


def sin(x):
    return math.sin(x)


def cos(x):
    return math.cos(x)


TAU = 2 * math.pi


def clip_fly():
    keys = []
    for i in range(9):  # two wing beats and one body bob in 0.5 s
        ph = TAU * i / 8
        beat = cos(TAU * i / 4)
        keys.append((0.0625 * i, merge(
            body(dy=0.13 * sin(ph), rx=3 * cos(ph)), head(rx=-4 * sin(ph - 0.6)),
            wings(-22 + 40 * beat, -16 + 30 * cos(TAU * i / 4 - 0.9)),
            abdomen(rx=-7 * sin(ph - 1.0)), paws(10 * sin(ph - 1.5), -12 * sin(ph - 1.5)),
            antennae(rx=9 * sin(ph - 2.0)), ears(rx=4 * sin(ph - 1.2)))))
    return keys


def clip_patrol():
    keys = []
    for i in range(17):  # lazy figure of eight: one sway left-right, two bobs
        ph = TAU * i / 16
        beat = 1 if i % 2 == 0 else -1
        keys.append((0.1 * i, merge(
            body(dx=0.55 * sin(ph), dy=0.24 * sin(2 * ph), rx=-4, ry=-9 * cos(ph), rz=-11 * cos(ph)),
            head(ry=7 * sin(ph), rz=6 * cos(ph)), wings(-20 + 34 * beat, -14 - 24 * beat),
            abdomen(rx=-5 * sin(2 * ph - 1.0), ry=12 * cos(ph - 0.8)),
            paws(9 * sin(2 * ph - 1.2), -9 * sin(2 * ph - 1.2), 5 * cos(ph)),
            antennae(rx=6 * sin(2 * ph - 2.0), rz=11 * cos(ph - 1.0)))))
    return keys


def clip_dash():
    keys = []
    for i in range(9):  # leans forward, wings swept back and buzzing
        beat = 1 if i % 2 == 0 else -1
        keys.append((0.05 * i, merge(
            body(dy=0.05 * beat, dz=-0.2, rx=-34), head(rx=26), wings(-14 + 13 * beat, -10 - 11 * beat, 58, 50),
            abdomen(rx=-9 + 4 * beat), paws(-58, -66), antennae(rx=38 - 5 * beat), ears(rx=24, spread=-6))))
    return keys


def clip_pollen():
    rear = merge(body(dy=0.15, dz=0.3, rx=26), head(rx=14), wings(22, 18), abdomen(rx=30),
                 paws(-30, -20, 14), antennae(rx=28), ears(rx=12))
    puff = merge(body(dy=-0.05, dz=-0.38, rx=-20), head(rx=-10), wings(26, 22, -18), abdomen(rx=-24),
                 paws(52, 30, 22), antennae(rx=-34), ears(rx=-10, spread=10))
    return [
        (0.0, {}),
        (0.12, merge(body(dy=0.06, dz=0.12, rx=10), wings(-58), abdomen(rx=10), antennae(rx=10))),
        (0.3, rear),
        (0.45, puff),
        (0.55, merge(puff, body(rz=7), wings(-70), abdomen(ry=10))),
        (0.65, merge(puff, body(rz=-7), wings(-10), abdomen(ry=-10))),
        (0.78, merge(body(dz=-0.1, rx=-6), wings(-55), antennae(rx=-10))),
        (0.9, {}),
    ]


def clip_orbit():
    keys = []
    for i in range(9):  # banked turn to its left, circling a target on its left side
        ph = TAU * i / 8
        beat = 1 if i % 2 == 0 else -1
        keys.append((0.1 * i, merge(
            body(dy=0.09 * sin(ph), rx=-8, ry=12, rz=27), head(ry=20, rz=-15, rx=4),
            wings(-18 + 34 * beat, -12 - 24 * beat, 12), abdomen(rx=-6, ry=-15 + 5 * sin(ph - 1.0)),
            {"Paw_FL": [0, 0, 0, -18, 0, -14], "Paw_FR": [0, 0, 0, -18, 0, -14],
             "Paw_BL": [0, 0, 0, -24, 0, -14], "Paw_BR": [0, 0, 0, -24, 0, -14]},
            antennae(rx=14, rz=-14 + 4 * sin(ph - 2.0)), ears(rx=8))))
    return keys


LAND = merge(body(dy=-1.62, rx=3), head(rx=-5), wings(-52, -40, 34, 26), abdomen(rx=2), paws(62, -55, 10),
             antennae(rx=-8), ears(spread=6))


def clip_rest():
    groom = merge(LAND, head(rx=-6, ry=48, rz=12), {"Wing_L_Front": [0, 0, 0, -8, -42, 24]}, ears(spread=4))
    up = merge(groom, {"Paw_FL": [0, 0.12, 0, 58, 0, -34]}, head(rx=-8), {"Wing_L_Front": [0, 0, 0, 0, 0, -8]})
    down = merge(groom, {"Paw_FL": [0, 0.05, 0, 22, 0, -30]}, head(rx=2), {"Wing_L_Front": [0, 0, 0, 0, 0, 6]})
    return [
        (0.0, LAND),
        (0.5, merge(groom, body(dy=0.04))),
        (0.9, up), (1.25, down), (1.6, up), (1.95, down),
        (2.35, merge(LAND, body(dy=0.05), head(ry=14, rx=4), wings(26, 20), antennae(rx=10))),
        (2.6, merge(LAND, wings(-6, -4), abdomen(ry=8))),
        (3.0, LAND),
    ]


def clip_dizzy():
    env = [0, 0.8, 1, 1, 1, 1, 1, 0.7, 0]
    keys = []
    for i in range(9):  # the head rolls in a circle, the body wobbles and sags
        ph, e = TAU * i / 8, env[i]
        beat = 1 if i % 2 == 0 else -1
        keys.append((0.1 * i, merge(
            body(dx=0.26 * e * sin(ph), dy=-0.3 * e, rx=6 * e * cos(ph), rz=-13 * e * sin(ph)),
            head(rx=15 * e * sin(ph), rz=20 * e * cos(ph), ry=10 * e * sin(ph)),
            wings(e * (-44 + 12 * beat), e * (-34 - 10 * beat)), abdomen(rx=12 * e, ry=18 * e * sin(ph - 1.0)),
            paws(16 * e * sin(ph - 1.5), -16 * e * sin(ph - 1.5), 12 * e),
            {"Antenna_L": [0, 0, 0, -18 * e * sin(ph), 0, 26 * e * cos(ph)],
             "Antenna_R": [0, 0, 0, 18 * e * sin(ph), 0, 26 * e * cos(ph)]}, ears(rx=-10 * e, spread=12 * e))))
    return keys


CLIP_DEFS = [
    # name, length, loop, priority, key function, preview time, preview view
    ("Fly", 0.5, True, "Movement", clip_fly, 0.125, "three"),
    ("Patrol", 1.6, True, "Movement", clip_patrol, 0.4, "three"),
    ("Dash", 0.4, True, "Movement", clip_dash, 0.05, "side"),
    ("Pollen", 0.9, False, "Action", clip_pollen, 0.3, "side"),
    ("Orbit", 0.8, True, "Movement", clip_orbit, 0.2, "three"),
    ("Rest", 3.0, True, "Idle", clip_rest, 0.9, "three"),
    ("Dizzy", 0.8, False, "Action", clip_dizzy, 0.2, "three"),
]


def tidy(pose):
    out = {}
    for bone, v in pose.items():
        v = [round(x, 3) + 0.0 for x in v]
        if any(abs(x) > 1e-9 for x in v):
            out[bone] = v
    return out


def build_clips():
    clips = {}
    for name, length, loop, priority, fn, _t, _view in CLIP_DEFS:
        keys = [{"t": round(t, 4), "pose": tidy(pose)} for t, pose in fn()]
        assert abs(keys[0]["t"]) < 1e-9 and abs(keys[-1]["t"] - length) < 1e-6, name
        for key in keys:
            for bone in key["pose"]:
                assert bone in BONE_HEAD, "%s: unknown bone %s" % (name, bone)
        if loop:
            assert keys[0]["pose"] == keys[-1]["pose"], "%s does not loop cleanly" % name
        clips[name] = {"length": length, "loop": loop, "priority": priority, "keys": keys}
    return clips


# ---------------------------------------------------------------- scene, rig, skin
def own_scene():
    if bpy.app.background:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        scene = bpy.context.scene
        scene.name = "Mielita"
        return scene
    scene = bpy.data.scenes.get("Mielita") or bpy.data.scenes.new("Mielita")
    for o in list(scene.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.window.scene = scene
    return scene


def build():
    scene = own_scene()
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    arm_data = bpy.data.armatures.new("MielitaRig")
    arm = bpy.data.objects.new("Mielita", arm_data)
    scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for name, head_, tail, parent in BONES:
        eb = arm_data.edit_bones.new(name)
        eb.head, eb.tail = head_, tail
        if parent:
            eb.parent = arm_data.edit_bones[parent]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    bone_names = {b[0] for b in BONES}
    meshes = []
    owned = {}
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
        # rigid skinning: every vertex in exactly one group, weight 1
        for v in me.vertices:
            assert len(v.groups) == 1 and abs(v.groups[0].weight - 1.0) < 1e-6, \
                "%s: vertex %d is not pinned to exactly one bone" % (name, v.index)
            g = obj.vertex_groups[v.groups[0].group].name
            owned[g] = owned.get(g, 0) + 1
        meshes.append(obj)
    missing = [b[0] for b in BONES if not owned.get(b[0])]
    assert not missing, "bones with no skinned vertex: %s" % missing
    assert set(owned) <= bone_names, "vertex groups without a bone: %s" % (set(owned) - bone_names)
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


# ---------------------------------------------------------------- posing (the Roblox maths, in Blender axes)
ROBLOX_TO_BLENDER = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def delta(v):
    v = list(v) + [0] * (6 - len(v))
    rx, ry, rz = (math.radians(a) for a in v[3:6])
    rot = Matrix.Rotation(rx, 4, "X") @ Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rz, 4, "Z")
    m = Matrix.Translation(v[0:3]) @ rot
    return ROBLOX_TO_BLENDER @ m @ ROBLOX_TO_BLENDER.inverted()


def apply_pose(arm, pose):
    """Sets every pose bone so that it shows `pose` exactly as the Roblox importer family composes it."""
    frames, posed = {}, {}
    for name, _h, _t, parent in BONES:  # parents come first in BONES
        d = delta(pose.get(name, [0] * 6))
        if parent:
            frames[name] = frames[parent] @ Matrix.Translation(BONE_HEAD[name] - BONE_HEAD[parent]) @ d
        else:
            frames[name] = Matrix.Translation(BONE_HEAD[name]) @ d
        rest = arm.data.bones[name].matrix_local
        posed[name] = frames[name] @ Matrix.Translation(-BONE_HEAD[name]) @ rest
        pb = arm.pose.bones[name]
        pb.rotation_mode = "QUATERNION"
        if parent:
            rest_parent = arm.data.bones[parent].matrix_local
            basis = (rest_parent.inverted() @ rest).inverted() @ (posed[parent].inverted() @ posed[name])
        else:
            basis = rest.inverted() @ posed[name]
        pb.matrix_basis = basis


def sample(clip, t):
    keys = clip["keys"]
    for a, b in zip(keys, keys[1:]):
        if a["t"] - 1e-9 <= t <= b["t"] + 1e-9:
            f = 0 if b["t"] == a["t"] else (t - a["t"]) / (b["t"] - a["t"])
            out = {}
            for bone in set(a["pose"]) | set(b["pose"]):
                va, vb = a["pose"].get(bone, [0] * 6), b["pose"].get(bone, [0] * 6)
                out[bone] = [va[i] + (vb[i] - va[i]) * f for i in range(6)]
            return out
    return keys[-1]["pose"]


def bake_actions(scene, arm, clips, fps=30):
    """One Blender action per clip, for previewing in the .blend (they are not exported)."""
    made = []
    arm.animation_data_create()
    for name, clip in clips.items():
        action = bpy.data.actions.new("Mielita_" + name)
        action.use_fake_user = True
        arm.animation_data.action = action
        for key in clip["keys"]:
            apply_pose(arm, key["pose"])
            frame = 1 + key["t"] * fps
            for pb in arm.pose.bones:
                pb.keyframe_insert("location", frame=frame)
                pb.keyframe_insert("rotation_quaternion", frame=frame)
        made.append(action.name)
    arm.animation_data.action = None
    apply_pose(arm, {})
    return made


# ---------------------------------------------------------------- renders
VIEWS = {"front": (0, -1, 0.12), "side": (1, -0.12, 0.1), "back": (0, 1, 0.12), "three": (0.72, -1, 0.3),
         "three_back": (-0.8, 1, 0.35)}


def setup_render(scene, tile):
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x, scene.render.resolution_y = tile
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("MielitaWorld")
    world.color = (0.045, 0.04, 0.06)
    scene.world = world
    sh = scene.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_cavity = True
    sh.cavity_type = "BOTH"
    sh.show_shadows = False
    sh.show_object_outline = True
    sh.object_outline_color = (0.08, 0.05, 0.04)
    sh.show_specular_highlight = False
    scene.display.render_aa = "8"
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    # a ground disc so the hover reads
    me = bpy.data.meshes.new("PreviewGroundMesh")
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, segments=24, radius=1.9)
    bm.to_mesh(me)
    bm.free()
    ground = bpy.data.objects.new("PreviewGround", me)
    mat = bpy.data.materials.new("PreviewGroundMat")
    mat.diffuse_color = (0.02, 0.018, 0.03, 1)
    me.materials.append(mat)
    scene.collection.objects.link(ground)
    # label
    font = bpy.data.curves.new("PreviewLabel", "FONT")
    font.align_x = "CENTER"
    font.size = 0.55
    label = bpy.data.objects.new("PreviewLabel", font)
    lmat = bpy.data.materials.new("PreviewLabelMat")
    lmat.diffuse_color = (1, 0.85, 0.9, 1)
    font.materials.append(lmat)
    scene.collection.objects.link(label)
    label.parent = cam
    return cam, label


def shoot(scene, cam, label, view, text, path, scale=7.4, centre=(0, 0.25, 3.15)):
    direction = Vector(VIEWS[view]).normalized()
    target = Vector(centre)
    cam.location = target + direction * 30
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.ortho_scale = scale
    rx, ry = scene.render.resolution_x, scene.render.resolution_y
    half_height = scale * ry / max(rx, ry) * 0.5  # ortho_scale spans the larger side
    label.data.body = text
    label.data.size = scale * 0.06
    label.location = (0, half_height - scale * 0.085, -5)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def montage(paths, cols, out_path):
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
    rows = (len(tiles) + cols - 1) // cols
    sheet = np.zeros((rows * h, cols * w, 4), dtype=np.float32)
    sheet[..., 3] = 1
    sheet[..., 0:3] = tiles[0][0, 0, 0:3]
    for i, tile in enumerate(tiles):
        r, c = divmod(i, cols)
        y0 = (rows - 1 - r) * h  # image rows run bottom-up
        sheet[y0:y0 + h, c * w:(c + 1) * w] = tile
    out = bpy.data.images.new("Montage", cols * w, rows * h, alpha=False)
    out.pixels.foreach_set(sheet.ravel())
    out.filepath_raw = out_path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)


def render_all(scene, arm, clips):
    tmp = os.path.join(HERE, "renders")
    os.makedirs(tmp, exist_ok=True)
    cam, label = setup_render(scene, (700, 700))
    apply_pose(arm, {})
    turn = []
    for view, text in (("front", "FRONT"), ("side", "SIDE (LEFT)"), ("back", "BACK"), ("three", "THREE-QUARTER")):
        path = os.path.join(tmp, "%s-turn-%s.png" % (SLUG, view))
        shoot(scene, cam, label, view, text, path, 7.2, (0, 0.3, 3.2))
        turn.append(path)
    montage(turn, 2, os.path.join(HERE, SLUG + "-turnaround.png"))
    scene.render.resolution_x, scene.render.resolution_y = 360, 400
    poses = []
    path = os.path.join(tmp, "%s-pose-Hover.png" % SLUG)
    shoot(scene, cam, label, "three", "Rest pose (hover)", path, 8.0, (0, 0.3, 3.1))
    poses.append(path)
    for name, _length, _loop, _priority, _fn, t, view in CLIP_DEFS:
        apply_pose(arm, sample(clips[name], t))
        path = os.path.join(tmp, "%s-pose-%s.png" % (SLUG, name))
        shoot(scene, cam, label, view, "%s  t=%.2fs" % (name, t), path, 8.0, (0, 0.3, 3.1))
        poses.append(path)
    apply_pose(arm, {})
    montage(poses, 4, os.path.join(HERE, SLUG + "-poses.png"))
    label.data.body = ""
    return turn + poses


# ---------------------------------------------------------------- run
SCENE, ARM, MESHES = build()
CLIPS = build_clips()
bpy.context.view_layer.update()
deps = bpy.context.evaluated_depsgraph_get()
zs = []
for m in MESHES:
    zs.extend((m.matrix_world @ v.co).z for v in m.data.vertices)
paw_low = min((m.matrix_world @ v.co).z for m in MESHES for v in m.data.vertices
              if m.vertex_groups[v.groups[0].group].name.startswith("Paw_"))
for m in MESHES:
    m.data.calc_loop_triangles()
STATS = {
    "slug": SLUG,
    "bones": len(BONES),
    "boneNames": [b[0] for b in BONES],
    "meshes": len(MESHES),
    "meshNames": [m.name for m in MESHES],
    "verts": sum(len(m.data.vertices) for m in MESHES),
    "tris": sum(len(m.data.loop_triangles) for m in MESHES),
    "heightStuds": round(max(zs) - min(zs), 3),
    "lowestZ": round(min(zs), 3), "highestZ": round(max(zs), 3), "lowestPawZ": round(paw_low, 3),
    "clips": {name: {"length": c["length"], "loop": c["loop"], "priority": c["priority"], "keys": len(c["keys"])}
              for name, c in CLIPS.items()},
}
assert STATS["tris"] < 2500 and STATS["bones"] <= 24, STATS

with open(os.path.join(HERE, SLUG + "-clips.json"), "w", encoding="utf-8", newline="\n") as f:
    json.dump(CLIPS, f, indent=1)

export(EXPORT, ARM, MESHES)
STATS["exported"] = os.path.relpath(EXPORT, REPO).replace("\\", "/")

try:
    STATS["actions"] = bake_actions(SCENE, ARM, CLIPS)
except Exception as err:  # the preview actions are a convenience; the clip data is the JSON
    STATS["actions"] = "not baked: %r" % (err,)
    apply_pose(ARM, {})

if RENDER:
    render_all(SCENE, ARM, CLIPS)
    STATS["renders"] = [SLUG + "-turnaround.png", SLUG + "-poses.png"]

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, SLUG + "-v1.blend"), check_existing=False)
with open(os.path.join(HERE, SLUG + "-report.json"), "w", encoding="utf-8", newline="\n") as f:
    json.dump(STATS, f, indent=1)
print("MIELITA_STATS " + json.dumps(STATS))

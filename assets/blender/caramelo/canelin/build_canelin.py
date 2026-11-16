"""Canelin, the cinnamon-roll critter of the Caramelo biome.

Low-poly, faceted creature about 5.5 studs tall: a round dough body on four stubby legs, a white-pink icing cap
with drips, a cinnamon spiral on top, two small round ears sunk into the icing, a dark cinnamon-stick tail
and a small face on the front of the body (big round eyes with a shine, an oval nose, a small curved smile).
The closed-eye lines used for sleeping are separate pieces (Lid bones) hidden inside the dough at rest.

Units: 1 Blender unit = 1 stud. The creature faces -Y; its left side is +X; the feet rest on Z = 0. Roblox reads
the FBX as X = -x, Y = z, Z = y, so its front is -Z there.

Every mesh is skinned and every vertex belongs to exactly one bone (rigid skinning); every bone owns at least one
piece (Root owns a small gem hidden inside the body). No mesh is named like a bone.

Clips are data (CLIPS below): { name: { length, loop, priority, keys: [ { t, pose: { bone: [dx, dy, dz, rx, ry, rz] } } ] } }.
The six numbers are a translation in studs and XYZ Euler degrees (CFrame.Angles order, Rx * Ry * Rz) in ROBLOX model
axes (X = creature's right, Y = up, Z = back), relative to the bone's rest pose, composed exactly like
tortidragon/clips_to_rbxmx.py: Transform = rest^-1 * (T * R) * rest.

Run:  blender --background --python build_canelin.py
It rebuilds everything from nothing: canelin-v1.blend, assets/exports/caramelo/canelin-v1.fbx, canelin-clips.json,
canelin-report.json, canelin-turnaround.png and canelin-poses.png.
"""
import json
import math
import os
import random

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

SLUG = "canelin"
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
EXPORT = os.path.join(REPO, "assets", "exports", "caramelo", SLUG + "-v1.fbx")
RENDER = globals().get("CANELIN_RENDER", True)

# ---- shape parameters -------------------------------------------------------------------------------------------
BODY_C, BODY_R, SHAPE_E = Vector((0, 0, 2.55)), (2.9, 2.75, 1.9), 0.8
CAP_C, CAP_R = Vector((0, 0, 3.2)), (3.1, 2.95, 2.25)
LEG_X, LEG_Y, LEG_TOP = 1.55, 1.35, 1.35
EYE_X, EYE_Z, EYE_R = 1.15, 2.55, 0.5
LID_SINK = 0.55
EAR_AZ, EAR_PHI, EAR_R = 48.0, 55.0, 0.7
TAIL_A, TAIL_DIR, TAIL_LEN, TAIL_R = Vector((0, 2.3, 1.9)), Vector((0, 0.93, 0.36)).normalized(), 2.1, 0.7


def superpoint(centre, radii, az, phi, e=SHAPE_E, scale=1.0):
    """A point of a squarish ellipsoid. az 0 = front (-Y), positive towards +X; phi 0 = top, 180 = bottom."""
    a, p = math.radians(az), math.radians(phi)
    s = abs(math.sin(p)) ** e
    c = math.copysign(abs(math.cos(p)) ** e, math.cos(p))
    return Vector((centre[0] + radii[0] * s * math.sin(a) * scale, centre[1] - radii[1] * s * math.cos(a) * scale,
                   centre[2] + radii[2] * c * scale))


def body_front(x, z):
    """The point of the body surface at (x, z) on the front side, and its outward normal."""
    cz = (z - BODY_C[2]) / BODY_R[2]
    cosp = abs(cz) ** (1 / SHAPE_E)
    s = math.sqrt(max(0.0, 1 - cosp * cosp)) ** SHAPE_E
    y = -BODY_R[1] * math.sqrt(max(0.0, s * s - (x / BODY_R[0]) ** 2))
    n = Vector((x / BODY_R[0] ** 2, y / BODY_R[1] ** 2, (z - BODY_C[2]) / BODY_R[2] ** 2)).normalized()
    return Vector((x, y, z)), n


def cap_top(x, y):
    """Height of the icing cap above (x, y)."""
    s = min(0.999, math.sqrt((x / CAP_R[0]) ** 2 + (y / CAP_R[1]) ** 2))
    sinp = s ** (1 / SHAPE_E)
    return CAP_C[2] + CAP_R[2] * math.sqrt(1 - sinp * sinp) ** SHAPE_E


EAR_BASE = {s: superpoint(CAP_C, CAP_R, EAR_AZ * (1 if s == "L" else -1), EAR_PHI, scale=0.98) for s in "LR"}
EAR_TIP = {s: EAR_BASE[s] + Vector((0.2 * (1 if s == "L" else -1), 0.0, 0.9)) for s in "LR"}
EYE_POS = {s: body_front(EYE_X * (1 if s == "L" else -1), EYE_Z) for s in "LR"}

BONES = [
    # name, head, tail, parent
    ("Root", (0, 0, 0), (0, 0, 1), None),
    ("Body", (0, 0, 1.0), (0, 0, 2.55), "Root"),
    ("Roll", (0, 0, 3.2), (0, 0, 5.4), "Body"),
    ("Ear_L", tuple(EAR_BASE["L"]), tuple(EAR_TIP["L"]), "Roll"),
    ("Ear_R", tuple(EAR_BASE["R"]), tuple(EAR_TIP["R"]), "Roll"),
    ("Head", (0, 0, 2.55), (0, -2.75, 2.55), "Body"),
    ("Eye_L", tuple(EYE_POS["L"][0]), tuple(EYE_POS["L"][0] + EYE_POS["L"][1] * 0.5), "Head"),
    ("Eye_R", tuple(EYE_POS["R"][0]), tuple(EYE_POS["R"][0] + EYE_POS["R"][1] * 0.5), "Head"),
    ("Lid_L", tuple(EYE_POS["L"][0] - EYE_POS["L"][1] * LID_SINK), tuple(EYE_POS["L"][0]), "Head"),
    ("Lid_R", tuple(EYE_POS["R"][0] - EYE_POS["R"][1] * LID_SINK), tuple(EYE_POS["R"][0]), "Head"),
    ("Leg_FL", (LEG_X, -LEG_Y, 1.2), (LEG_X, -LEG_Y, 0.1), "Body"),
    ("Leg_FR", (-LEG_X, -LEG_Y, 1.2), (-LEG_X, -LEG_Y, 0.1), "Body"),
    ("Leg_BL", (LEG_X, LEG_Y, 1.2), (LEG_X, LEG_Y, 0.1), "Body"),
    ("Leg_BR", (-LEG_X, LEG_Y, 1.2), (-LEG_X, LEG_Y, 0.1), "Body"),
    ("Tail", tuple(TAIL_A), tuple(TAIL_A + TAIL_DIR * TAIL_LEN), "Body"),
]

COLOURS = {
    "Dough": "#F4BD86", "Icing": "#FFE9EC", "Cinnamon": "#E0934E", "Face": "#4A2A18", "EarPink": "#F3A59B",
    "Bark": "#8A4F2B", "Shine": "#FFFFFF",
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

    def box_m(self, bone, matrix, size):
        res = bmesh.ops.create_cube(self.bm, size=1.0, matrix=matrix @ Matrix.Diagonal((size[0], size[1], size[2], 1)))
        self._pin(res["verts"], bone)

    def gem(self, bone, centre, scale, subdiv=1, matrix=None):
        m = (matrix or Matrix.Translation(centre)) @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1))
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

    def wedge(self, bone, frame, width, height, depth):
        """A triangular slab standing on the frame's XY plane, its point along local Z: an ear."""
        bm = self.bm
        co = [(-width / 2, -depth / 2, 0), (width / 2, -depth / 2, 0), (0, -depth / 4, height),
              (-width / 2, depth / 2, 0), (width / 2, depth / 2, 0), (0, depth / 4, height)]
        vs = [bm.verts.new(frame @ Vector(c)) for c in co]
        faces = [bm.faces.new([vs[i] for i in f]) for f in ((0, 1, 2), (3, 5, 4), (0, 2, 5, 3), (1, 4, 5, 2), (0, 3, 4, 1))]
        bmesh.ops.recalc_face_normals(bm, faces=faces)
        self._pin(vs, bone)
    def stroke(self, bone, frame, p0, p1, thick, depth):
        """A flat bar from p0 to p1 (x, z in the frame's plane), for the face features."""
        dx, dz = p1[0] - p0[0], p1[1] - p0[1]
        m = frame @ Matrix.Translation(((p0[0] + p1[0]) / 2, 0, (p0[1] + p1[1]) / 2)) @ \
            Matrix.Rotation(-math.atan2(dz, dx), 4, "Y")
        self.box_m(bone, m, (math.hypot(dx, dz) + thick * 0.55, depth, thick))

    def lathe(self, bone, centre, radii, phis, segs, rim=None, jitter=0.0, seed=1, ref=None):
        """A faceted squarish ellipsoid (or a dome when `rim` is given): rings of `segs` vertices at the polar
        angles `phis`, each ring twisted half a step so the bands are triangles. `rim(az)` gives the polar angle
        of the last ring per azimuth (the dripping edge) and adds a ring turned inwards to close the edge."""
        bm, rng = self.bm, random.Random(seed)
        ref = ref or centre
        step = 360.0 / segs
        new_verts, new_faces = [], []

        def vert(az, phi, scale=1.0):
            k = scale * (1 + rng.uniform(-jitter, jitter))
            v = bm.verts.new(superpoint(centre, radii, az, phi, scale=k))
            new_verts.append(v)
            return v

        def face(*vs):
            f = bm.faces.new(vs)
            f.normal_update()
            if f.normal.dot(f.calc_center_median() - ref) < 0:
                f.normal_flip()
            new_faces.append(f)

        top = vert(0, 0)
        rings = []
        last = len(phis) - 1
        for i, phi in enumerate(phis):
            if phi >= 180:
                rings.append(None)
                continue
            off = 0.5 * (i % 2)
            if rim and i == last:
                rings.append([vert((j + off) * step, rim((j + off) * step)) for j in range(segs)])
            else:
                rings.append([vert((j + off) * step, phi) for j in range(segs)])
        for j in range(segs):
            face(top, rings[0][j], rings[0][(j + 1) % segs])
        for i in range(len(rings) - 1):
            a, b = rings[i], rings[i + 1]
            if b is None:
                bottom = vert(0, 180)
                for j in range(segs):
                    face(bottom, a[j], a[(j + 1) % segs])
                break
            for j in range(segs):
                j1 = (j + 1) % segs
                if i % 2 == 0:  # b sits half a step ahead of a
                    face(a[j], a[j1], b[j])
                    face(a[j1], b[j1], b[j])
                else:
                    face(a[j], a[j1], b[j1])
                    face(a[j], b[j1], b[j])
        if rim:
            edge = rings[-1]
            inner = []
            for v in edge:
                w = bm.verts.new(Vector((centre[0] + (v.co.x - centre[0]) * 0.86, centre[1] + (v.co.y - centre[1]) * 0.86,
                                         v.co.z + 0.05)))
                new_verts.append(w)
                inner.append(w)
            for j in range(segs):
                j1 = (j + 1) % segs
                for tri in ((edge[j], edge[j1], inner[j1]), (edge[j], inner[j1], inner[j])):
                    f = bm.faces.new(tri)
                    f.normal_update()
                    if f.normal.z > 0:
                        f.normal_flip()
        self._pin(new_verts, bone)

    def ribbon(self, bone, points, width, top, depth):
        """A closed band following `points` (x, y) on the icing cap: the cinnamon spiral."""
        bm = self.bm
        rows, new_verts, new_faces = [], [], []
        for k, (x, y) in enumerate(points):
            a = Vector(points[min(k + 1, len(points) - 1)]) - Vector(points[max(k - 1, 0)])
            side = Vector((-a.y, a.x)).normalized() * (width / 2)
            row = []
            for sx, dz in ((-1, -depth), (-1, top), (1, top), (1, -depth)):
                px, py = x + side.x * sx, y + side.y * sx
                row.append(bm.verts.new((px, py, cap_top(px, py) + dz)))
            rows.append(row)
            new_verts += row
        for k in range(len(rows) - 1):
            r0, r1 = rows[k], rows[k + 1]
            for i in range(4):
                new_faces.append(bm.faces.new((r0[i], r0[(i + 1) % 4], r1[(i + 1) % 4], r1[i])))
        new_faces.append(bm.faces.new(rows[0]))
        new_faces.append(bm.faces.new(rows[-1]))
        bmesh.ops.recalc_face_normals(bm, faces=new_faces)
        self._pin(new_verts, bone)


def mirror(x, side):
    return x if side == "L" else -x


def surface_frame(pos, normal, sink=0.0):
    """A frame on the body surface: local -Y points out of the body, local Z is up along the surface."""
    return Matrix.Translation(pos - normal * sink) @ normal.to_track_quat("-Y", "Z").to_matrix().to_4x4()


# Icing edge: the polar angle of the rim around the creature (0 = front). The front stays high so the face is clear.
DRIPS = [2, 5, 1, 6, 3, 16, 25, 9, 1, 15, 26, 11, 2, 17, 24, 8, 1, 16, 26, 10, 2, 14, 25, 14, 3, 6, 1, 5]


def icing_rim(az):
    i = (az % 360) / 360.0 * len(DRIPS)
    a, b = DRIPS[int(i) % len(DRIPS)], DRIPS[(int(i) + 1) % len(DRIPS)]
    f = i - int(i)
    return 86 + a * (1 - f) + b * f


def build_pieces():
    p = {name: Piece(name) for name in COLOURS}
    dough, icing, cinnamon, face, pink = p["Dough"], p["Icing"], p["Cinnamon"], p["Face"], p["EarPink"]
    bark, shine = p["Bark"], p["Shine"]

    # body: one round faceted dough ball; Root owns a gem hidden inside it
    dough.lathe("Body", BODY_C, BODY_R, [26, 52, 77, 102, 127, 153, 180], 16, jitter=0.018, seed=3)
    dough.gem("Root", (0, 0, 2.4), (0.2, 0.2, 0.2), 0)

    # four stubby legs, wider where they meet the body
    for name, sx, sy in (("Leg_FL", 1, -1), ("Leg_FR", -1, -1), ("Leg_BL", 1, 1), ("Leg_BR", -1, 1)):
        x, y = LEG_X * sx, LEG_Y * sy
        dough.prism(name, (x, y, LEG_TOP), (x, y, 0.22), 0.9, 0.66, 7)
        dough.prism(name, (x, y, 0.22), (x, y, 0.0), 0.66, 0.56, 7)

    # icing cap with a dripping edge, and the cinnamon spiral lying on top of it
    icing.lathe("Roll", CAP_C, CAP_R, [21, 43, 65, 86], 28, rim=icing_rim, jitter=0.012, seed=5,
                ref=CAP_C + Vector((0, 0, 0.8)))
    pts = []
    turns, n = 2.15, 46
    for k in range(n + 1):
        f = k / n
        a = math.radians(200) + f * turns * 2 * math.pi
        r = 0.15 + 1.95 * f
        pts.append((r * math.sin(a), -r * math.cos(a)))
    cinnamon.ribbon("Roll", pts, 0.44, 0.1, 0.3)

    # two small round ears, their lower third sunk into the icing
    for side in "LR":
        sx = 1 if side == "L" else -1
        base, tip = EAR_BASE[side], EAR_TIP[side]
        axis = (tip - base).normalized()
        front = Vector((0.4 * sx, -1, 0)).normalized()
        y = (-front - axis * (-front).dot(axis)).normalized()
        x = y.cross(axis)
        frame = Matrix.Translation(base + axis * 0.32) @ Matrix((x, y, axis)).transposed().to_4x4()
        dough.gem("Ear_%s" % side, None, (EAR_R, 0.3, EAR_R), 2, matrix=frame)
        pink.gem("Ear_%s" % side, None, (EAR_R * 0.58, 0.12, EAR_R * 0.58), 2,
                 matrix=frame @ Matrix.Translation((0, -0.23, 0.06)))

    # face: big round open eyes with a shine on their own bones, an oval nose and a small curved smile
    for side in "LR":
        sx = 1 if side == "L" else -1
        pos, nrm = EYE_POS[side]
        frame = surface_frame(pos, nrm, 0.0)
        face.gem("Eye_%s" % side, None, (EYE_R, 0.2, EYE_R), 2, matrix=frame)
        shine.gem("Eye_%s" % side, None, (0.17, 0.09, 0.17), 1,
                  matrix=frame @ Matrix.Translation((0.17 * sx, -0.17, 0.19)))
        # the sleeping eye: one closed line, hidden inside the dough until the Rest clip slides it out
        lid = surface_frame(pos, nrm, LID_SINK)
        face.stroke("Lid_%s" % side, lid, (-0.42, 0.0), (0.42, 0.0), 0.15, 0.3)
    pos, nrm = body_front(0, 2.27)
    face.gem("Head", None, (0.17, 0.16, 0.11), 1, matrix=surface_frame(pos, nrm, 0.02))
    pos, nrm = body_front(0, 1.9)
    frame = surface_frame(pos, nrm, 0.04)
    smile = [(-0.3, 0.1), (-0.12, -0.03), (0.12, -0.03), (0.3, 0.1)]
    for a, b in zip(smile, smile[1:]):
        face.stroke("Head", frame, a, b, 0.11, 0.32)

    # tail: a plain cinnamon stick, a roll of dark bark with a darker spiral showing on its end
    end = TAIL_A + TAIL_DIR * TAIL_LEN
    bark.prism("Tail", TAIL_A, end, TAIL_R, TAIL_R, 8)
    face.prism("Tail", end - TAIL_DIR * 0.05, end + TAIL_DIR * 0.04, TAIL_R * 0.74, TAIL_R * 0.74, 8)
    bark.prism("Tail", end, end + TAIL_DIR * 0.08, TAIL_R * 0.46, TAIL_R * 0.46, 8)
    face.prism("Tail", end, end + TAIL_DIR * 0.12, TAIL_R * 0.2, TAIL_R * 0.2, 6)
    # the lip of the rolled bark: a darker seam along the top of the stick
    up = Vector((0, -TAIL_DIR.z, TAIL_DIR.y))
    seam = Matrix.Translation(TAIL_A + TAIL_DIR * (TAIL_LEN / 2 + 0.2) + up * TAIL_R * 0.93) @ \
        TAIL_DIR.to_track_quat("Y", "Z").to_matrix().to_4x4()
    face.box_m("Tail", seam, (0.12, TAIL_LEN - 0.5, 0.1))
    return p


# ---- clips (ROBLOX model axes: X = right, Y = up, Z = back; degrees) -----------------------------------------------
LEGS = ["Leg_FL", "Leg_FR", "Leg_BL", "Leg_BR"]


def merge(*poses):
    out = {}
    for pose in poses:
        for bone, v in pose.items():
            s = out.setdefault(bone, [0.0] * 6)
            for i in range(6):
                s[i] += v[i] if i < len(v) else 0
    return out


def body(dy=0, pitch=0, yaw=0, roll=0, planted=True):
    """Moves the body; with planted, the legs slide the other way so the feet stay on the ground."""
    pose = {"Body": [0, dy, 0, pitch, yaw, roll]}
    if planted:
        for name in LEGS:
            pose[name] = [0, -dy, 0, 0, 0, 0]
    return pose


def legs(fl=0, fr=0, bl=0, br=0, lift=0):
    """Swing in degrees (positive = foot forward) and a common lift in studs."""
    return {n: [0, lift, 0, s, 0, 0] for n, s in zip(LEGS, (fl, fr, bl, br))}


def tuck_legs(lift=1.4, inward=0.75):
    """Pulls the four legs up and towards the centre so they disappear inside the dough ball."""
    return {"Leg_FL": [inward, lift, inward, 0, 0, 0], "Leg_FR": [-inward, lift, inward, 0, 0, 0],
            "Leg_BL": [inward, lift, -inward, 0, 0, 0], "Leg_BR": [-inward, lift, -inward, 0, 0, 0]}


def cap(dy=0, pitch=0, roll=0, yaw=0):
    """The icing cap rides up and down on the body: the fake squash and stretch."""
    return {"Roll": [0, dy, 0, pitch, yaw, roll]}


def ears(fold=0, splay=0, dy=0, left=0, right=0):
    return {"Ear_L": [0, dy, 0, fold + left, 0, splay], "Ear_R": [0, dy, 0, fold + right, 0, -splay]}


def face(yaw=0, pitch=0, tuck=0):
    """The face slides over the body around its centre; tuck sinks it into the dough."""
    return {"Head": [0, 0, tuck, pitch, yaw, 0]}


def eyes(tilt=0, closed=0.0):
    """tilt turns the eyes (the shine moves); closed 1 sinks the round eyes into the dough and slides the
    closed-eye lines out in their place."""
    return {"Eye_L": [0, 0, 0.6 * closed, 0, 0, tilt], "Eye_R": [0, 0, 0.6 * closed, 0, 0, -tilt],
            "Lid_L": [0, 0, -(LID_SINK - 0.05) * closed, 0, 0, 0], "Lid_R": [0, 0, -(LID_SINK - 0.05) * closed, 0, 0, 0]}


def tail(yaw=0, lift=0, tuck=0):
    return {"Tail": [0, 0, -tuck, -lift, yaw, 0]}


def key(t, *poses):
    return {"t": t, "pose": merge(*poses)}


REST_POSE = {}
# the ears sink inwards into the roll, the face and the tail into the dough, the legs up into the body
BALL = merge(face(tuck=0.6), tail(tuck=3.1), tuck_legs(),
             {"Ear_L": [0.6, -0.75, 0.55, 0, 0, 0], "Ear_R": [-0.6, -0.75, 0.55, 0, 0, 0]})
SPIN_BASE = merge(BALL, {"Body": [0, -0.62, 0, 0, 0, 0]})  # a clean ball sitting on the ground, legs inside
CHARGE_BASE = merge(BALL, {"Body": [0, -0.5, 0, -22, 0, 0]})
SLEEP = merge(body(-0.5, roll=3), face(pitch=5), eyes(closed=1), tail(yaw=60, lift=-4, tuck=0.3),
              ears(fold=-6, splay=5, dy=-0.05))


def spin_keys(times, base, bob=0.0):
    out = []
    for i, t in enumerate(times):
        out.append(key(t, base, {"Body": [0, bob if i % 2 else 0, 0, 0, 90.0 * i, 0]}))
    return out


def make_clips():
    walk_a = (legs(22, -22, -22, 22), body(0, roll=4), cap(roll=-3), tail(yaw=14), face(yaw=4))
    walk_b = (legs(-22, 22, 22, -22), body(0, roll=-4), cap(roll=3), tail(yaw=-14), face(yaw=-4))
    return {
        "Idle": {"length": 2.5, "loop": True, "priority": "Idle", "keys": [
            key(0, REST_POSE),
            key(0.625, body(0.07), cap(0.05), tail(yaw=12, lift=6), face(yaw=6), ears(left=-8)),
            key(1.25, body(-0.05), cap(-0.05), ears(splay=6)),
            key(1.875, body(0.07), cap(0.05), tail(yaw=-12, lift=6), face(yaw=-6), ears(right=-10)),
            key(2.5, REST_POSE)]},
        "Walk": {"length": 1.0, "loop": True, "priority": "Movement", "keys": [
            key(0, *walk_a),
            key(0.25, body(0.12), cap(0.06), legs(lift=0.0)),
            key(0.5, *walk_b),
            key(0.75, body(0.12), cap(0.06)),
            key(1.0, *walk_a)]},
        "Bounce": {"length": 0.7, "loop": False, "priority": "Action", "keys": [
            key(0, REST_POSE),
            key(0.12, body(-0.36), cap(-0.15), ears(splay=14), tail(lift=-12)),
            key(0.34, body(1.4, pitch=5, planted=False), legs(16, 16, -16, -16, lift=-0.12), cap(0.17),
                ears(fold=16), tail(lift=32)),
            key(0.52, body(-0.4), cap(-0.19), ears(splay=16), tail(lift=-8)),
            key(0.62, body(0.1), cap(0.09)),
            key(0.7, REST_POSE)]},
        # two turns per loop, the second one faster; keys every 90 degrees so the shortest path is unambiguous
        "Spin": {"length": 0.8, "loop": True, "priority": "Action", "easing": "Linear",
                 "keys": spin_keys([0, 0.14, 0.27, 0.39, 0.5, 0.58, 0.66, 0.73, 0.8], SPIN_BASE)},
        "Charge": {"length": 0.5, "loop": True, "priority": "Action", "easing": "Linear",
                   "keys": spin_keys([0, 0.125, 0.25, 0.375, 0.5], CHARGE_BASE, bob=0.1)},
        "Rest": {"length": 3.0, "loop": True, "priority": "Idle", "keys": [
            key(0, SLEEP),
            key(1.5, SLEEP, body(0.06), cap(0.07)),
            key(2.2, SLEEP, body(0.03), cap(0.03), ears(left=-8)),
            key(3.0, SLEEP)]},
        "Alert": {"length": 0.5, "loop": False, "priority": "Action", "keys": [
            key(0, REST_POSE),
            key(0.1, body(-0.16), cap(-0.09), ears(splay=10)),
            key(0.28, body(0.22, pitch=5), cap(0.15), ears(fold=-14, splay=-4), eyes(tilt=12), tail(lift=48),
                face(pitch=4)),
            key(0.5, body(0.1, pitch=3), cap(0.05), ears(fold=-9), eyes(tilt=12), tail(lift=36), face(pitch=2))]},
    }


CLIPS = make_clips()
# the key shown for each clip in the contact sheet: (clip, key index, label)
PREVIEW = [("Idle", 1, "Idle"), ("Walk", 0, "Walk"), ("Bounce", 2, "Bounce"), ("Spin", 1, "Spin"),
           ("Charge", 1, "Charge"), ("Rest", 1, "Rest"), ("Alert", 3, "Alert"), ("Bounce", 3, "Bounce (land)"),
           ("Walk", 2, "Walk (other step)")]

TO_RBX = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))  # Blender (x, y, z) -> Roblox (-x, z, y)


def pose_basis(arm, bone, v):
    """matrix_basis for one bone: rest^-1 * (T * Rx * Ry * Rz, in Roblox model axes) * rest, as Clips.build does."""
    v = list(v) + [0] * (6 - len(v))
    d = Matrix.Translation(v[0:3]) @ Matrix.Rotation(math.radians(v[3]), 4, "X") @ \
        Matrix.Rotation(math.radians(v[4]), 4, "Y") @ Matrix.Rotation(math.radians(v[5]), 4, "Z")
    d = TO_RBX.inverted() @ d @ TO_RBX
    rest = arm.data.bones[bone].matrix_local.to_3x3().to_4x4()
    return rest.inverted() @ d @ rest


def apply_pose(arm, pose):
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.matrix_basis = pose_basis(arm, pb.name, pose[pb.name]) if pb.name in pose else Matrix.Identity(4)
    bpy.context.view_layer.update()


# ---- scene ---------------------------------------------------------------------------------------------------------
def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.name = "Canelin"
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    arm_data = bpy.data.armatures.new("CanelinRig")
    arm = bpy.data.objects.new("Canelin", arm_data)
    scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for name, head, tail_, parent in BONES:
        eb = arm_data.edit_bones.new(name)
        eb.head, eb.tail = head, tail_
        if parent:
            eb.parent = arm_data.edit_bones[parent]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    meshes = []
    bone_names = {b[0] for b in BONES}
    for name, piece in build_pieces().items():
        assert name not in bone_names, "mesh named like a bone: %s" % name
        bmesh.ops.triangulate(piece.bm, faces=piece.bm.faces[:])
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
    # rigid skinning: every vertex on exactly one bone, every bone owns at least one vertex
    used = set()
    for obj in meshes:
        names = [g.name for g in obj.vertex_groups]
        for v in obj.data.vertices:
            assert len(v.groups) == 1 and abs(v.groups[0].weight - 1.0) < 1e-6, \
                "%s vertex %d is not on exactly one bone" % (obj.name, v.index)
            used.add(names[v.groups[0].group])
    missing = [b[0] for b in BONES if b[0] not in used]
    assert not missing, "bones with no skinned vertex: %s" % missing
    assert not (used - bone_names), "vertex groups that are not bones: %s" % (used - bone_names)
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


# ---- renders -------------------------------------------------------------------------------------------------------
def setup_render(scene):
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.exposure = 0.7
    sh = scene.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_shadows = True
    sh.shadow_intensity = 0.25
    sh.show_cavity = True
    sh.cavity_type = "BOTH"
    sh.show_object_outline = False
    sh.show_specular_highlight = False
    scene.display.light_direction = (0.35, 0.45, 0.82)
    scene.display.render_aa = "8"
    world = bpy.data.worlds.new("Backdrop")
    world.color = (0.05, 0.035, 0.075)
    scene.world = world
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    txt_data = bpy.data.curves.new("Label", "FONT")
    txt_data.align_x = "CENTER"
    txt = bpy.data.objects.new("Label", txt_data)
    scene.collection.objects.link(txt)
    txt.parent = cam
    mat = bpy.data.materials.new("LabelMat")
    mat.diffuse_color = (1.0, 0.55, 0.8, 1.0)
    txt_data.materials.append(mat)
    floor_me = bpy.data.meshes.new("FloorMesh")
    floor_me.from_pydata([(-9, -9, 0), (9, -9, 0), (9, 9, 0), (-9, 9, 0)], [], [(0, 1, 2, 3)])
    floor = bpy.data.objects.new("Floor", floor_me)
    fmat = bpy.data.materials.new("FloorMat")
    fmat.diffuse_color = (0.09, 0.06, 0.13, 1.0)
    floor_me.materials.append(fmat)
    scene.collection.objects.link(floor)
    return cam, txt, floor


def shot(scene, cam, txt, path, direction, label, size, scale, target_z):
    target = Vector((0, 0, target_z))
    d = Vector(direction).normalized()
    cam.location = target + d * 40
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    cam.data.ortho_scale = scale
    cam.data.clip_end = 200
    txt.data.body = label
    txt.data.size = scale * 0.06
    txt.location = (0, -scale * 0.46, -6)
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def montage(paths, cols, out_path):
    cells = []
    for path in paths:
        img = bpy.data.images.load(path)
        w, h = img.size
        arr = np.empty(w * h * 4, dtype=np.float32)
        img.pixels.foreach_get(arr)
        cells.append(arr.reshape(h, w, 4))
        bpy.data.images.remove(img)
    ch, cw = cells[0].shape[0], cells[0].shape[1]
    rows = (len(cells) + cols - 1) // cols
    canvas = np.zeros((rows * ch, cols * cw, 4), dtype=np.float32)
    canvas[..., 3] = 1.0
    for i, cell in enumerate(cells):
        r, c = divmod(i, cols)
        canvas[(rows - 1 - r) * ch:(rows - r) * ch, c * cw:(c + 1) * cw] = cell
    out = bpy.data.images.new("Montage", cols * cw, rows * ch, alpha=False)
    out.pixels.foreach_set(canvas.ravel())
    out.filepath_raw = out_path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)


def render_all(scene, arm):
    cam, txt, floor = setup_render(scene)
    tmp = os.path.join(HERE, "renders")
    os.makedirs(tmp, exist_ok=True)
    apply_pose(arm, {})
    views = [("front", (0, -1, 0.18), "FRONT"), ("side", (1, 0, 0.18), "LEFT SIDE"), ("back", (0, 1, 0.18), "BACK"),
             ("three-quarter", (0.8, -1, 0.42), "3/4 FRONT")]
    paths = []
    for name, d, label in views:
        path = os.path.join(tmp, "%s-view-%s.png" % (SLUG, name))
        shot(scene, cam, txt, path, d, label, (700, 700), 8.8, 2.7)
        paths.append(path)
    montage(paths, 2, os.path.join(HERE, SLUG + "-turnaround.png"))
    paths = []
    for i, (clip, index, label) in enumerate(PREVIEW):
        k = CLIPS[clip]["keys"][index]
        apply_pose(arm, k["pose"])
        path = os.path.join(tmp, "%s-pose-%d.png" % (SLUG, i))
        d = (-0.55, -1, 0.32) if clip == "Rest" else (0.15, -1, 0.22) if clip == "Alert" else (0.6, -1, 0.34)
        shot(scene, cam, txt, path, d, "%s  t=%.2fs" % (label, k["t"]), (468, 468), 10.0, 3.3)
        paths.append(path)
    montage(paths, 3, os.path.join(HERE, SLUG + "-poses.png"))
    apply_pose(arm, {})
    for o in (cam, txt, floor):
        o.hide_render = True


def store_actions(scene, arm):
    """One Blender action per clip, for previewing in the .blend (the FBX carries no animation)."""
    scene.render.fps = 30
    stored = []
    try:
        arm.animation_data_create()
        for name, clip in CLIPS.items():
            action = bpy.data.actions.new(SLUG + "_" + name)
            action.use_fake_user = True
            arm.animation_data.action = action
            for k in clip["keys"]:
                apply_pose(arm, k["pose"])
                frame = 1 + round(k["t"] * 30)
                for pb in arm.pose.bones:
                    pb.keyframe_insert("location", frame=frame)
                    pb.keyframe_insert("rotation_quaternion", frame=frame)
            stored.append(action.name)
        arm.animation_data.action = None
    except Exception as err:  # previews only; never block the export
        print("actions not stored:", err)
    apply_pose(arm, {})
    return stored


def main():
    scene, arm, meshes = build()
    export(EXPORT, arm, meshes)  # before any posing: the FBX is the rest pose
    with open(os.path.join(HERE, SLUG + "-clips.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(CLIPS, f, indent=1)
    # Predicted Studio rest rotations (pivot:ToObjectSpace(bone.WorldCFrame).Rotation, row-major) for the adapter
    # canelin_clips_to_rbxmx.py: TO_RBX * matrix_local * RotY(180). The formula reproduces the Studio readout of
    # Tortidragon (Root, straight legs, tail); replace the file with a real readout once the FBX is imported.
    flip = Matrix.Diagonal((-1, 1, -1))
    rest = {}
    for b in arm.data.bones:
        m = TO_RBX.to_3x3() @ b.matrix_local.to_3x3() @ flip
        rest[b.name] = [round(m[i][j], 7) for i in range(3) for j in range(3)]
    with open(os.path.join(HERE, SLUG + "-rest.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"source": "predicted from Blender, not read from Studio", "tree": [[b[0], b[3] or "RootPart"] for b in BONES],
                   "rest": rest}, f, indent=1)
    deps = bpy.context.evaluated_depsgraph_get()
    zs = [(o.matrix_world @ v.co).z for o in meshes for v in o.data.vertices]
    for o in meshes:
        o.data.calc_loop_triangles()
    bone_names = [b[0] for b in BONES]
    for name, clip in CLIPS.items():
        assert abs(clip["keys"][-1]["t"] - clip["length"]) < 1e-9, name
        for k in clip["keys"]:
            unknown = set(k["pose"]) - set(bone_names)
            assert not unknown, "%s poses unknown bones %s" % (name, unknown)
    report = {
        "slug": SLUG, "bones": len(BONES), "boneNames": bone_names, "meshes": len(meshes),
        "meshNames": [o.name for o in meshes],
        "verts": sum(len(o.data.vertices) for o in meshes),
        "tris": sum(len(o.data.loop_triangles) for o in meshes),
        "heightStuds": round(max(zs) - min(zs), 3), "minZ": round(min(zs), 3),
        "clips": {name: {"length": c["length"], "loop": c["loop"], "priority": c["priority"], "keys": len(c["keys"])}
                  for name, c in CLIPS.items()},
        "fbx": os.path.relpath(EXPORT, REPO).replace("\\", "/"),
    }
    if RENDER:
        render_all(scene, arm)
    report["blenderActions"] = store_actions(scene, arm)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, SLUG + "-v1.blend"), check_existing=False)
    with open(os.path.join(HERE, SLUG + "-report.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(report, f, indent=1)
    print("CANELIN_REPORT", json.dumps(report))


main()

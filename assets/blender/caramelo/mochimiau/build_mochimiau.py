"""Mochimiau, the round mochi cat of the Caramelo biome (about 5 studs tall).

A squashed-dome pink mochi body on four stubby legs, two folded triangular ears, large oval eyes with a shine,
a tiny triangular nose, a small open smile with one fang, blush cheeks, a strawberry-syrup glaze cap with drips,
a whipped-cream rosette with a cherry on top and a whipped-cream swirl for a tail. It trots, bounces and rolls.

Units: 1 Blender unit = 1 stud. The creature faces -Y; its left side is +X; feet rest on Z = 0. Roblox reads the
FBX as X = -x, Y = z, Z = y, so its front is -Z there.

Rigid skinning: every vertex belongs to exactly one bone, every bone owns at least one vertex (Root owns a small
gem hidden inside the body) and no mesh is named like a bone. All three are asserted.

Clips are data (CLIPS below): { name: {length, loop, priority, keys: [{t, pose: {bone: [dx, dy, dz, rx, ry, rz]}}]} }.
The six numbers are a translation in studs and XYZ Euler degrees (CFrame.Angles order) in ROBLOX model axes, applied
at the bone's pivot and carried by its parent, exactly like tortidragon/clips_to_rbxmx.py composes them:
Transform = rest:Inverse() * (T * R) * rest. In those axes: +Y up, -Z forward, -X the creature's left;
+rx nose up, +ry turn to its left, +rz lean to its left.

Run:  blender --background --python build_mochimiau.py
It rebuilds everything from nothing, saves mochimiau-v1.blend, exports assets/exports/caramelo/mochimiau-v1.fbx and
writes mochimiau-clips.json, mochimiau-report.json, mochimiau-turnaround.png and mochimiau-poses.png.
"""
import json
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

SLUG = "mochimiau"
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
EXPORT = os.path.join(REPO, "assets", "exports", "caramelo", SLUG + "-v1.fbx")
RENDER = not globals().get("MOCHI_NO_RENDER")

# the body is an ellipsoid dome: centre height CZ, half-width RX, half-length RY, UP above the centre, DOWN below
CZ, RX, RY, UP, DOWN, FULL = 2.0, 2.35, 2.55, 1.8, 1.65, 0.6  # FULL < 1 fills out the underside
LEG_X, LEG_YF, LEG_YB, LEG_PIVOT = 1.25, -1.25, 1.35, 1.0
EAR_X, EAR_Y = 1.3, -1.0
TOP_Y = -0.75
EAR_FLAT = (0.55, 1.0)

BONES = [
    # name, head, tail, parent
    ("Root", (0, 0, 0), (0, 0, 1), None),
    ("Body", (0, 0, CZ), (0, -1.2, CZ), "Root"),
    ("Eyes", (0, -2.2, 2.35), (0, -2.7, 2.35), "Body"),
    ("Lids", (0, -1.8, 2.3), (0, -2.3, 2.3), "Body"),
    ("Ear_L", (EAR_X, EAR_Y, 3.3), (EAR_X + 0.2, EAR_Y, 4.2), "Body"),
    ("Ear_R", (-EAR_X, EAR_Y, 3.3), (-EAR_X - 0.2, EAR_Y, 4.2), "Body"),
    ("Cherry", (0, TOP_Y, 4.15), (0, TOP_Y, 5.0), "Body"),
    ("Leg_FL", (LEG_X, LEG_YF, LEG_PIVOT), (LEG_X, LEG_YF, 0.1), "Body"),
    ("Leg_FR", (-LEG_X, LEG_YF, LEG_PIVOT), (-LEG_X, LEG_YF, 0.1), "Body"),
    ("Leg_BL", (LEG_X, LEG_YB, LEG_PIVOT), (LEG_X, LEG_YB, 0.1), "Body"),
    ("Leg_BR", (-LEG_X, LEG_YB, LEG_PIVOT), (-LEG_X, LEG_YB, 0.1), "Body"),
    ("Tail_01", (0, 2.3, 1.9), (0, 3.1, 2.2), "Body"),
    ("Tail_02", (0, 3.15, 2.3), (0, 3.5, 3.3), "Tail_01"),
]

COLOURS = {
    "Skin": "#F8B4CC", "Glaze": "#EE4E93", "Whip": "#FFF2E4", "Berry": "#D81E3A", "Stem": "#5A3220",
    "Eye": "#472619", "Shine": "#FFFFFF", "Rose": "#F27BA6", "Mouth": "#8C1D3E",
}


def hex_rgba(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c) + (1.0,)


def euler(rot):
    from mathutils import Euler
    return Euler(tuple(math.radians(a) for a in rot), "XYZ").to_matrix().to_4x4()


def mirror(x, side):
    return x if side == "L" else -x


IDENTITY = Matrix.Identity(4)


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

    def box(self, bone, centre, size, rot=(0, 0, 0), frame=IDENTITY):
        m = frame @ Matrix.Translation(centre) @ euler(rot) @ Matrix.Diagonal((size[0], size[1], size[2], 1))
        res = bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)
        self._pin(res["verts"], bone)

    def gem(self, bone, centre, scale, subdiv=1, rot=(0, 0, 0), frame=IDENTITY):
        m = frame @ Matrix.Translation(centre) @ euler(rot) @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1))
        res = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=1.0, matrix=m)
        self._pin(res["verts"], bone)

    def prism(self, bone, a, b, r1, r2, segments=6, flat=(1.0, 1.0)):
        a, b = Vector(a), Vector(b)
        axis = b - a
        rot = axis.to_track_quat("Z", "Y").to_matrix().to_4x4()
        m = Matrix.Translation((a + b) / 2) @ rot @ Matrix.Diagonal((flat[0], flat[1], 1, 1))
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segments,
                                    radius1=r1, radius2=r2, depth=axis.length, matrix=m)
        self._pin(res["verts"], bone)

    def dome(self, bone, scale=1.0, subdiv=3, keep=None):
        """The body ellipsoid (flatter below its centre). keep(u) filters faces by their unit-sphere centre."""
        res = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=1.0)
        verts = res["verts"]
        if keep:
            faces = {f for v in verts for f in v.link_faces}
            drop = [f for f in faces if not keep(f.calc_center_median().normalized())]
            bmesh.ops.delete(self.bm, geom=drop, context="FACES")
            verts = [v for v in verts if v.is_valid]
        for v in verts:
            v.co = dome_point(v.co.copy(), scale)
        self._pin(verts, bone)

    def blob(self, bone, a, b, width, thick, normal):
        """A flattened gem stretched from a to b, lying on a surface whose normal is given (a syrup run)."""
        a, b = Vector(a), Vector(b)
        z = (b - a).normalized()
        x = normal.cross(z).normalized()
        y = z.cross(x)
        m = Matrix((x, y, z)).transposed().to_4x4()
        m = Matrix.Translation((a + b) / 2) @ m @ Matrix.Diagonal((width, thick, (b - a).length / 2 + width * 0.6, 1))
        res = bmesh.ops.create_icosphere(self.bm, subdivisions=1, radius=1.0, matrix=m)
        self._pin(res["verts"], bone)


def dome_point(u, scale=1.0):
    """Unit-sphere point to the body: an ellipsoid above its centre, a fuller, flatter belly below it."""
    z = UP * u.z if u.z >= 0 else -DOWN * (-u.z) ** FULL
    return Vector((RX * u.x * scale, RY * u.y * scale, CZ + z * scale))


def surf_y(x, z):
    s = (z - CZ) / UP if z >= CZ else ((CZ - z) / DOWN) ** (1 / FULL)
    return -RY * math.sqrt(max(0.0, 1 - (x / RX) ** 2 - s * s))


def surf(x, z, out=0.0):
    """A point on the front of the body at (x, z), pushed out along the normal, and that normal."""
    e = 0.01
    p = Vector((x, surf_y(x, z), z))
    dx = Vector((2 * e, surf_y(x + e, z) - surf_y(x - e, z), 0))
    dz = Vector((0, surf_y(x, z + e) - surf_y(x, z - e), 2 * e))
    n = dz.cross(dx).normalized()
    if n.y > 0:
        n = -n
    return p + n * out, n


def face_frame(x, z, out=0.0):
    """Local frame on the face: -Y points out of the body, X runs across the face, Z up."""
    p, n = surf(x, z, out)
    return Matrix.Translation(p) @ n.to_track_quat("-Y", "Z").to_matrix().to_4x4()


def polar(phi, uz, scale=1.0):
    """A point on the body ellipsoid by azimuth (degrees; 0 = back, 90 = the creature's left) and unit height."""
    r = math.sqrt(max(0.0, 1 - uz * uz))
    a = math.radians(phi)
    return dome_point(Vector((r * math.sin(a), r * math.cos(a), uz)), scale)


def glaze_keep(u):
    """The syrup cap: lower at the back than over the forehead."""
    frontness = (1 - u.y / max(1e-6, math.sqrt(u.x * u.x + u.y * u.y))) / 2 if (u.x or u.y) else 0.5
    return u.z > 0.46 + 0.34 * frontness


def build_pieces():
    p = {name: Piece(name) for name in COLOURS}
    skin, glaze, whip, berry, rose, eye, shine, mouth = (p[k] for k in (
        "Skin", "Glaze", "Whip", "Berry", "Rose", "Eye", "Shine", "Mouth"))
    # body: a squashed mochi dome; Root owns a gem hidden inside
    skin.dome("Body")
    skin.gem("Root", (0, 0, CZ), (0.2, 0.2, 0.2), 0)
    # stubby legs
    for bone, x, y in (("Leg_FL", LEG_X, LEG_YF), ("Leg_FR", -LEG_X, LEG_YF),
                       ("Leg_BL", LEG_X, LEG_YB), ("Leg_BR", -LEG_X, LEG_YB)):
        skin.prism(bone, (x, y, 0), (x, y, 0.28), 0.56, 0.68)
        skin.prism(bone, (x, y, 0.28), (x, y, 1.35), 0.68, 0.6)
    # ears: a chunky pyramid whose tip folds forward, with a darker inner piece
    for side in "LR":
        bone = "Ear_%s" % side
        x = mirror(EAR_X, side)
        # a broad triangle, thin front to back, its tip folding forward
        fold = (x + mirror(0.2, side), EAR_Y - 0.08, 3.95)
        skin.prism(bone, (x - mirror(0.05, side), EAR_Y + 0.05, 3.0), fold, 0.98, 0.34, 4, EAR_FLAT)
        skin.prism(bone, fold, (x + mirror(0.26, side), EAR_Y - 0.62, 3.66), 0.34, 0.05, 4, EAR_FLAT)
        rose.prism(bone, (x + mirror(0.02, side), EAR_Y - 0.34, 3.2), (x + mirror(0.14, side), EAR_Y - 0.36, 3.72),
                   0.44, 0.12, 4, EAR_FLAT)
    # face: big oval eyes with a shine, a tiny nose, an open smile with one fang, blush cheeks
    for side in "LR":
        f = face_frame(mirror(0.98, side), 2.38)
        eye.gem("Eyes", (0, 0, 0), (0.33, 0.13, 0.47), 2, frame=f)
        shine.gem("Eyes", (mirror(0.1, side), -0.1, 0.17), (0.12, 0.07, 0.14), 1, frame=f)
        shine.gem("Eyes", (mirror(-0.1, side), -0.11, -0.2), (0.06, 0.04, 0.06), 0, frame=f)
        # closed-eye arcs, hidden inside the body until a blink or the sleep pose slides them out
        lf = face_frame(mirror(0.98, side), 2.3, -0.5)
        eye.box("Lids", (0, 0, -0.06), (0.3, 0.1, 0.1), frame=lf)
        eye.box("Lids", (0.24, 0, 0.01), (0.26, 0.1, 0.1), (0, -38, 0), frame=lf)
        eye.box("Lids", (-0.24, 0, 0.01), (0.26, 0.1, 0.1), (0, 38, 0), frame=lf)
        rose.gem("Body", (0, 0, 0), (0.36, 0.09, 0.23), 1, frame=face_frame(mirror(1.62, side), 1.88))
    nose = face_frame(0, 2.16)
    rose.prism("Body", nose @ Vector((0, -0.05, 0.08)), nose @ Vector((0, -0.05, -0.12)), 0.2, 0.02, 3)
    mf = face_frame(0, 1.8)
    mouth.gem("Body", (0, 0, 0), (0.34, 0.1, 0.24), 1, frame=mf)
    shine.prism("Body", mf @ Vector((0.13, -0.09, 0.2)), mf @ Vector((0.13, -0.09, -0.04)), 0.1, 0.01, 4)
    # syrup: a glaze cap that follows the dome, with drips running down the sides and the back
    glaze.dome("Body", 1.045, 3, glaze_keep)
    for phi, top, bottom, r in ((102, 0.66, 0.02, 0.34), (-82, 0.62, 0.2, 0.32), (32, 0.5, 0.12, 0.3),
                                (-36, 0.5, -0.08, 0.32), (158, 0.74, 0.5, 0.28)):
        a, b = polar(phi, top, 1.03), polar(phi, bottom, 1.03)
        mid = (a + b) / 2
        normal = Vector((mid.x / RX ** 2, mid.y / RY ** 2, (mid.z - CZ) / UP ** 2)).normalized()
        glaze.blob("Body", a, b, r * 1.2, 0.3, normal)
        end = polar(phi, bottom)
        normal = Vector((end.x / RX ** 2, end.y / RY ** 2, (end.z - CZ) / UP ** 2)).normalized()
        glaze.blob("Body", end + Vector((0, 0, 0.12)), end - Vector((0, 0, 0.12)), r * 1.55, 0.26, normal)
    # topping: a whipped-cream rosette between the ears, and the cherry with its stem on its own bone
    whip.gem("Body", (0, TOP_Y, 3.78), (0.85, 0.85, 0.32), 1)
    for i in range(6):
        a = math.radians(60 * i + 30)
        whip.gem("Body", (0.56 * math.cos(a), TOP_Y + 0.56 * math.sin(a), 3.92), (0.32, 0.32, 0.26), 1)
    whip.gem("Body", (0, TOP_Y, 4.1), (0.52, 0.52, 0.3), 1)
    berry.gem("Cherry", (0, TOP_Y, 4.58), (0.44, 0.44, 0.42), 1)
    p["Stem"].prism("Cherry", (0, TOP_Y, 4.92), (0.06, TOP_Y + 0.02, 5.16), 0.05, 0.045, 5)
    p["Stem"].prism("Cherry", (0.06, TOP_Y + 0.02, 5.16), (0.2, TOP_Y + 0.06, 5.28), 0.045, 0.04, 5)
    # tail: a swirl of whipped cream, three shrinking gems curling up
    whip.gem("Tail_01", (0, 2.8, 1.95), (0.8, 0.78, 0.72), 1)
    whip.gem("Tail_02", (0, 3.42, 2.5), (0.62, 0.6, 0.56), 1, (20, 0, 0))
    whip.gem("Tail_02", (0, 3.55, 3.1), (0.44, 0.44, 0.4), 1)
    whip.prism("Tail_02", (0, 3.52, 3.3), (0, 3.22, 3.78), 0.28, 0.03, 5)
    return p


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.name = "Mochimiau"
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene.render.fps = 30
    arm_data = bpy.data.armatures.new("MochimiauRig")
    arm = bpy.data.objects.new("Mochimiau", arm_data)
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
        names = [g.name for g in obj.vertex_groups]
        for v in obj.data.vertices:
            assert len(v.groups) == 1 and abs(v.groups[0].weight - 1.0) < 1e-6, \
                "%s vertex %d is not pinned to exactly one bone" % (obj.name, v.index)
            assert names[v.groups[0].group] in {b[0] for b in BONES}
    missing = [b[0] for b in BONES if b[0] not in used]
    assert not missing, "bones with no skinned vertex: %s" % missing
    clash = [m.name for m in meshes if m.name in {b[0] for b in BONES}]
    assert not clash, "meshes named like bones: %s" % clash
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


# ---------------------------------------------------------------- clips (Roblox model axes, see the docstring)
LEGS = ["Leg_FL", "Leg_FR", "Leg_BL", "Leg_BR"]
# each leg pivot relative to the Body pivot, in Roblox axes (X = -x, Y = z, Z = y)
LEG_OFFSET = {"Leg_FL": (-LEG_X, LEG_PIVOT - CZ, LEG_YF), "Leg_FR": (LEG_X, LEG_PIVOT - CZ, LEG_YF),
              "Leg_BL": (-LEG_X, LEG_PIVOT - CZ, LEG_YB), "Leg_BR": (LEG_X, LEG_PIVOT - CZ, LEG_YB)}


def angles(rx, ry, rz):
    """CFrame.Angles: Rx * Ry * Rz, degrees."""
    return (Matrix.Rotation(math.radians(rx), 3, "X") @ Matrix.Rotation(math.radians(ry), 3, "Y")
            @ Matrix.Rotation(math.radians(rz), 3, "Z"))


def merge(*poses):
    out = {}
    for pose in poses:
        for bone, v in pose.items():
            s = out.setdefault(bone, [0.0] * 6)
            for i in range(6):
                s[i] += v[i] if i < len(v) else 0
    return out


def body(dy=0.0, pitch=0.0, yaw=0.0, roll=0.0, dz=0.0, lift=(0, 0, 0, 0), swing=(0, 0, 0, 0)):
    """Moves the Body and keeps the four feet planted (plus a lift per leg), the legs staying upright.

    This is the fake squash and stretch: the dome sinks onto its legs or rises off them. swing is the leg's
    forward (+) or backward (-) rotation; lift and swing are ordered FL, FR, BL, BR.
    """
    r = angles(pitch, yaw, roll)
    rt = r.transposed()
    pose = {"Body": [0, dy, dz, pitch, yaw, roll]}
    for name, l, s in zip(LEGS, lift, swing):
        o = Vector(LEG_OFFSET[name])
        d = rt @ (o + Vector((0, l, 0)) - Vector((0, dy, dz))) - o
        pose[name] = [d.x, d.y, d.z, s - pitch, -yaw, -roll]
    return pose


def ears(back=0.0, splay=0.0, left=1.0, right=1.0):
    return {"Ear_L": [0, 0, 0, back * left, 0, splay * left], "Ear_R": [0, 0, 0, back * right, 0, -splay * right]}


def cherry(pitch=0.0, roll=0.0, dy=0.0):
    return {"Cherry": [0, dy, 0, pitch, 0, roll]}


def tail(yaw=0.0, lift=0.0):
    return {"Tail_01": [0, 0, 0, -lift * 0.5, yaw * 0.5, 0], "Tail_02": [0, 0, 0, -lift * 0.5, yaw * 0.5, 0]}


def blink(a=1.0):
    """Slides the open eyes into the body and the closed-eye arcs out of it."""
    return {"Eyes": [0, 0, 0.42 * a], "Lids": [0, 0, -0.52 * a]}


def tuck(a=1.0):
    """Legs pulled up into the dome for the roll."""
    pose = {}
    for name in LEGS:
        inward = 0.25 if name.endswith("L") else -0.25
        pose[name] = [inward * a, 0.95 * a, 0]
    return pose


def keys(*pairs):
    return [{"t": t, "pose": pose} for t, pose in pairs]


def idle_keys():
    out = []
    for t in (0, 0.5, 0.625, 0.75, 1.25, 1.75, 1.85, 1.95, 2.5):
        s = math.sin(2 * math.pi * t / 2.5)
        pose = merge(body(dy=0.07 * s), cherry(roll=4 * s), tail(yaw=12 * s, lift=4 * s), ears(back=-3 * s))
        if t == 0.625:
            pose = merge(pose, ears(back=10, splay=18, left=0))
        if t == 1.85:
            pose = merge(pose, blink())
        out.append({"t": t, "pose": pose})
    return out


def step(sign, big, roll, lift_mid=0.0):
    """One contact pose of the diagonal gait: sign +1 puts FL and BR forward."""
    return merge(body(dy=-0.03, roll=roll * sign, yaw=3 * sign, swing=(big * sign, -big * sign, -big * sign, big * sign)),
                 tail(yaw=-14 * sign), cherry(roll=-5 * sign))


def passing(sign, dy, lift, air=0.0, pitch=0.0):
    """The passing pose between two contacts: the pair that swings forward next is lifted."""
    l = (air, air + lift, air + lift, air) if sign > 0 else (air + lift, air, air, air + lift)
    return merge(body(dy=dy, pitch=pitch, lift=l), cherry(dy=0.04), ears(back=6 + 40 * air))


SLEEP = merge({"Body": [0, -0.36, 0, -3, 0, 6]},
              {"Leg_FL": [-0.1, 0.12, -0.1, 78, 0, -14], "Leg_FR": [0.1, 0.12, -0.1, 78, 0, 14],
               "Leg_BL": [-0.15, 0.12, 0.1, -78, 0, -18], "Leg_BR": [0.15, 0.12, 0.1, -78, 0, 18]},
              ears(back=6, splay=24), blink(), tail(yaw=50, lift=-14), cherry(roll=10, pitch=4))
BREATH = {"Body": [0, 0.07, 0], "Leg_FL": [0, -0.07, 0], "Leg_FR": [0, -0.07, 0], "Leg_BL": [0, -0.07, 0],
          "Leg_BR": [0, -0.07, 0]}
CROUCH = merge(body(dy=-0.32, pitch=-11), ears(back=30, splay=6), tail(lift=30), cherry(pitch=-8))
ROLLING = merge(tuck(), ears(back=38, splay=10), cherry(dy=-0.5), tail(lift=30))


def rolled(turn, dy, wobble=0.0):
    return merge({"Body": [0, dy, 0, -90 * turn, 0, 0]}, ROLLING, cherry(roll=wobble))


CLIPS = {
    "Idle": {"length": 2.5, "loop": True, "priority": "Idle", "keys": idle_keys()},
    "Walk": {"length": 0.9, "loop": True, "priority": "Movement", "keys": keys(
        (0, step(1, 22, 4)), (0.225, passing(1, 0.1, 0.16)), (0.45, step(-1, 22, 4)),
        (0.675, passing(-1, 0.1, 0.16)), (0.9, step(1, 22, 4)))},
    "Trot": {"length": 0.6, "loop": True, "priority": "Movement", "keys": keys(
        (0, merge(step(1, 32, 5), ears(back=8))), (0.15, passing(1, 0.3, 0.2, 0.14, -3)),
        (0.3, merge(step(-1, 32, 5), ears(back=8))), (0.45, passing(-1, 0.3, 0.2, 0.14, -3)),
        (0.6, merge(step(1, 32, 5), ears(back=8))))},
    "Bounce": {"length": 0.7, "loop": False, "priority": "Action", "keys": keys(
        (0, {}),
        (0.12, merge(body(dy=-0.28), ears(splay=12), cherry(dy=-0.06), tail(lift=-8))),
        (0.32, merge(body(dy=1.35, pitch=5, lift=(1.15, 1.15, 1.2, 1.2), swing=(24, 24, -24, -24)),
                     ears(back=16), cherry(dy=0.12, pitch=-6), tail(lift=-22))),
        (0.5, merge(body(dy=-0.28), ears(back=-6, splay=16), cherry(dy=-0.1), tail(lift=18))),
        (0.6, merge(body(dy=0.07), ears(splay=-4), cherry(dy=0.05), tail(lift=6))),
        (0.7, {}))},
    "Roll": {"length": 0.6, "loop": True, "priority": "Action", "easing": "Linear", "keys": keys(
        (0, rolled(0, -0.3)), (0.15, rolled(1, 0.5, 6)), (0.3, rolled(2, 0.5)), (0.45, rolled(3, 0.5, -6)),
        (0.6, rolled(4, -0.3)))},
    "Charge": {"length": 0.6, "loop": False, "priority": "Action", "keys": keys(
        (0, {}),
        (0.12, merge(body(dy=-0.26, pitch=-6), ears(back=20), tail(lift=14))),
        (0.2, merge(body(dy=-0.28, pitch=-7, roll=5, yaw=4), ears(back=24), tail(lift=18, yaw=10), cherry(roll=-9))),
        (0.28, merge(body(dy=-0.29, pitch=-8, roll=-5, yaw=-4), ears(back=26), tail(lift=22, yaw=-10), cherry(roll=9))),
        (0.36, merge(body(dy=-0.3, pitch=-9, roll=5, yaw=4), ears(back=28), tail(lift=26, yaw=10), cherry(roll=-9))),
        (0.44, merge(body(dy=-0.31, pitch=-10, roll=-5, yaw=-4), ears(back=30), tail(lift=28, yaw=-10), cherry(roll=9))),
        (0.52, merge(body(dy=-0.32, pitch=-11, roll=3), ears(back=30, splay=6), tail(lift=30), cherry(roll=-5))),
        (0.6, CROUCH))},
    "Rest": {"length": 3.0, "loop": True, "priority": "Idle", "keys": keys(
        (0, SLEEP), (1.5, merge(SLEEP, BREATH, cherry(roll=2), tail(lift=3))),
        (2.0, merge(SLEEP, {k: [x * 0.6 for x in v] for k, v in BREATH.items()})),
        (2.12, merge(SLEEP, {k: [x * 0.5 for x in v] for k, v in BREATH.items()}, ears(back=10, splay=-14, left=0))),
        (2.24, merge(SLEEP, {k: [x * 0.4 for x in v] for k, v in BREATH.items()})),
        (3.0, SLEEP))},
}
ORDER = ["Idle", "Walk", "Trot", "Bounce", "Roll", "Charge", "Rest"]


def clean(clips):
    out = {}
    for name in ORDER:
        c = dict(clips[name])
        c["keys"] = [{"t": k["t"], "pose": {b: [round(float(x), 4) + 0.0 for x in v] for b, v in k["pose"].items()}}
                     for k in c["keys"]]
        assert abs(c["keys"][0]["t"]) < 1e-9 and abs(c["keys"][-1]["t"] - c["length"]) < 1e-9, name
        for k in c["keys"]:
            assert all(b in {x[0] for x in BONES} for b in k["pose"]), name
        out[name] = c
    return out


# ---------------------------------------------------------------- preview in Blender
TO_ROBLOX = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))  # its own inverse


def basis_for(arm, bone, v):
    """matrix_basis that reproduces rest:Inverse() * (T * R) * rest of the Roblox pose."""
    v = list(v) + [0] * (6 - len(v))
    delta = Matrix.Translation(v[:3]) @ angles(v[3], v[4], v[5]).to_4x4()
    delta = TO_ROBLOX @ delta @ TO_ROBLOX
    b = arm.data.bones[bone]
    head = Matrix.Translation(b.head_local)
    return b.matrix_local.inverted() @ head @ delta @ head.inverted() @ b.matrix_local


def apply_pose(arm, pose):
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.matrix_basis = basis_for(arm, pb.name, pose[pb.name]) if pb.name in pose else Matrix.Identity(4)
    bpy.context.view_layer.update()


def bake_actions(arm, clips):
    """One Action per clip so the .blend can be scrubbed; the FBX is exported without animation."""
    fps = bpy.context.scene.render.fps
    arm.animation_data_create()
    for name, clip in clips.items():
        action = bpy.data.actions.new("Mochimiau_" + name)
        action.use_fake_user = True
        arm.animation_data.action = action
        last = {}
        for key in clip["keys"]:
            frame = 1 + key["t"] * fps
            for pb in arm.pose.bones:
                pb.rotation_mode = "QUATERNION"
                loc, quat, _ = (basis_for(arm, pb.name, key["pose"][pb.name]) if pb.name in key["pose"]
                                else Matrix.Identity(4)).decompose()
                if pb.name in last and last[pb.name].dot(quat) < 0:
                    quat.negate()
                last[pb.name] = quat.copy()
                pb.location, pb.rotation_quaternion = loc, quat
                pb.keyframe_insert("location", frame=frame)
                pb.keyframe_insert("rotation_quaternion", frame=frame)
    arm.animation_data.action = None
    apply_pose(arm, {})


# ---------------------------------------------------------------- renders
def setup_render(scene):
    scene.render.engine = "BLENDER_WORKBENCH"
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            pass
    sh = scene.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_shadows = True
    sh.shadow_intensity = 0.35
    sh.show_cavity = True
    sh.cavity_type = "BOTH"
    sh.show_object_outline = True
    sh.object_outline_color = (0.12, 0.04, 0.08)
    sh.show_specular_highlight = False
    scene.display.light_direction = (0.35, 0.45, 0.82)
    scene.display.render_aa = "8"
    world = bpy.data.worlds.new("Backdrop")
    world.color = (0.035, 0.03, 0.045)
    scene.world = world
    scene.view_settings.view_transform = "Standard"
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    font = bpy.data.curves.new("Label", "FONT")
    font.align_x = "CENTER"
    font.size = 0.6
    label = bpy.data.objects.new("Label", font)
    # suns that follow the camera, so every view is lit the same way
    for name, strength, rot in (("Key", 3.2, (-38, -32, 0)), ("Fill", 1.3, (-10, 55, 0)), ("Under", 0.7, (60, 10, 0)),
                                ("Top", 1.0, (-80, 0, 0))):
        sun = bpy.data.lights.new(name, "SUN")
        sun.energy = strength
        sun.angle = math.radians(12)
        ob = bpy.data.objects.new(name, sun)
        ob.parent = cam
        ob.rotation_euler = tuple(math.radians(a) for a in rot)
        scene.collection.objects.link(ob)
    mat = bpy.data.materials.new("LabelMat")
    mat.diffuse_color = (1, 1, 1, 1)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0, 0, 0, 1)
    bsdf.inputs["Emission Color"].default_value = (1, 1, 1, 1)
    bsdf.inputs["Emission Strength"].default_value = 1.0
    font.materials.append(mat)
    scene.collection.objects.link(label)
    return cam, label


def shot(scene, cam, label, path, direction, target, scale, size, text):
    direction = Vector(direction).normalized()
    target = Vector(target)
    cam.location = target + direction * 30
    quat = (-direction).to_track_quat("-Z", "Y")
    cam.rotation_euler = quat.to_euler()
    cam.data.ortho_scale = scale
    label.data.body = text
    label.data.size = scale * 0.062
    label.rotation_euler = quat.to_euler()
    label.location = cam.location + quat @ Vector((0, -scale * 0.47, -8))
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def montage(paths, columns, out):
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
    img = bpy.data.images.new("Sheet", w, h, alpha=True)
    img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = out
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    for path in paths:
        os.remove(path)


VIEWS = [("FRONT", (0, -1, 0.12)), ("SIDE (LEFT)", (1, 0, 0.12)), ("BACK", (0, 1, 0.12)),
         ("THREE-QUARTER", (0.8, -1, 0.42))]
POSES = [("Idle", 0.625, "IDLE  ear flick"), ("Walk", 0.0, "WALK  waddle"), ("Trot", 0.15, "TROT  airborne"),
         ("Bounce", 0.32, "BOUNCE  apex"), ("Charge", 0.6, "CHARGE  crouch"), ("Roll", 0.15, "ROLL  1/4 turn"),
         ("Roll", 0.3, "ROLL  1/2 turn"), ("Rest", 1.5, "REST  asleep")]


def render_all(scene, arm, clips):
    cam, label = setup_render(scene)
    apply_pose(arm, {})
    tiles = []
    for i, (text, direction) in enumerate(VIEWS):
        path = os.path.join(HERE, "_view%d.png" % i)
        shot(scene, cam, label, path, direction, (0, 0.3, 2.6), 8.4, (700, 700), text)
        tiles.append(path)
    montage(tiles, 2, os.path.join(HERE, SLUG + "-turnaround.png"))
    tiles = []
    for i, (name, t, text) in enumerate(POSES):
        pose = next(k["pose"] for k in clips[name]["keys"] if abs(k["t"] - t) < 1e-6)
        apply_pose(arm, pose)
        path = os.path.join(HERE, "_pose%d.png" % i)
        direction = (1, -0.55, 0.3) if name in ("Roll", "Bounce", "Trot", "Walk") else (0.8, -1, 0.42)
        shot(scene, cam, label, path, direction, (0, 0.3, 2.9), 9.4, (350, 350), text)
        tiles.append(path)
    montage(tiles, 4, os.path.join(HERE, SLUG + "-poses.png"))
    apply_pose(arm, {})
    label.hide_render = True


ARM, MESHES = build()
for m in MESHES:
    m.data.calc_loop_triangles()
STATS = {"slug": SLUG, "bones": len(BONES), "boneNames": [b[0] for b in BONES], "meshes": len(MESHES),
         "meshNames": [m.name for m in MESHES],
         "verts": sum(len(m.data.vertices) for m in MESHES),
         "tris": sum(len(m.data.loop_triangles) for m in MESHES),
         "heightStuds": round(max(v.co.z for m in MESHES for v in m.data.vertices), 3),
         "widthStuds": round(2 * max(abs(v.co.x) for m in MESHES for v in m.data.vertices), 3),
         "lengthStuds": round(max(v.co.y for m in MESHES for v in m.data.vertices)
                              - min(v.co.y for m in MESHES for v in m.data.vertices), 3)}
assert STATS["tris"] < 2500 and STATS["bones"] <= 24, STATS
assert abs(min(v.co.z for m in MESHES for v in m.data.vertices)) < 1e-6, "the feet must rest on Z = 0"
export(EXPORT, ARM, MESHES)
STATS["exported"] = os.path.relpath(EXPORT, REPO).replace("\\", "/")
CLIP_DATA = clean(CLIPS)
STATS["clips"] = {name: {"length": c["length"], "loop": c["loop"], "priority": c["priority"], "keys": len(c["keys"])}
                  for name, c in CLIP_DATA.items()}
with open(os.path.join(HERE, SLUG + "-clips.json"), "w", encoding="utf-8", newline="\n") as f:
    json.dump(CLIP_DATA, f, indent=1)
with open(os.path.join(HERE, SLUG + "-report.json"), "w", encoding="utf-8", newline="\n") as f:
    json.dump(STATS, f, indent=1)
try:
    bake_actions(ARM, CLIP_DATA)
except Exception as error:  # the preview actions are a convenience; the clip data is the JSON
    print("preview actions skipped:", error)
    ARM.animation_data_clear()
    apply_pose(ARM, {})
if RENDER:
    render_all(bpy.context.scene, ARM, CLIP_DATA)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, SLUG + "-v1.blend"), check_existing=False)
print("MOCHIMIAU", json.dumps(STATS))

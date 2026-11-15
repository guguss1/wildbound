"""Scuttler, the global tactical hunter (odd/tasks/wildbound-scuttler.md, SC9; docs/design/wildbound-scuttler-plan.md).

Pack: Scuttler_Pack_Wildbound 01_Concepto and 03_Imagenes/01_Scuttler_Concepto.png (design input only).
Low-poly, faceted insect about 13.5 studs tall (user decision Q1: 12-14) and 16 wide: maroon segmented carapace,
two big claw arms with cream chevrons, eight jointed legs, an ivory toothy grin, amber glowing eyes, two antennas
with glowing cream tips, moss drips on the plates. Same angular style as the Viper and Gargoyle models.

Units: 1 Blender unit = 1 stud. The creature faces -Y; its left side is +X. Roblox reads the FBX as
X = -x, Y = z, Z = y, so its front is -Z there. Root sits on the ground between the feet.

Every mesh is skinned, and every vertex belongs to exactly one bone (rigid skinning): the importer keeps
only the bones a skinned vertex uses, so each of the 43 bones owns at least one piece (Root owns a small
gem hidden inside the abdomen). No mesh is named like a bone: the importer would hang that bone under it.
The legs hang from Hips (not Thorax), so the Thorax can rear up for the pulse while the feet stay planted.

Run inside Blender:  exec(open(r"<repo>/assets/blender/scuttler/build_scuttler.py").read())
It rebuilds its own scene "Scuttler" from nothing (other scenes are not touched). With SCUTTLER_EXPORT_PATH set
it writes the FBX; with SCUTTLER_PREVIEW_DIR set it renders scuttler-front/side/back.png there.
"""
import math
import os
import random

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

EXPORT = globals().get("SCUTTLER_EXPORT_PATH")
PREVIEW_DIR = globals().get("SCUTTLER_PREVIEW_DIR")
SCENE_NAME = "Scuttler"

LEG_Y = (-0.8, 1.4, 3.6, 5.8)  # hip positions along the body, front (1) to back (4)


def _side(x, side):
    return x if side == "L" else -x


def _bones():
    bones = [
        # name, head, tail, parent
        ("Root", (0, 0, 0), (0, 0, 1.5), None),
        ("Hips", (0, 2.0, 7.0), (0, 6.0, 6.6), "Root"),
        ("Thorax", (0, 0.4, 7.6), (0, -2.6, 9.4), "Hips"),
        ("Head", (0, -3.4, 9.8), (0, -6.0, 10.4), "Thorax"),
        ("Jaw", (0, -4.4, 9.0), (0, -6.2, 8.8), "Head"),
    ]
    for s in "LR":
        bones += [
            ("Antenna_%s_01" % s, (_side(0.8, s), -5.0, 11.4), (_side(1.5, s), -6.2, 12.4), "Head"),
            ("Antenna_%s_02" % s, (_side(1.5, s), -6.2, 12.4), (_side(2.2, s), -7.2, 13.3), "Antenna_%s_01" % s),
        ]
    for s in "LR":
        bones += [
            ("Claw_%s_Shoulder" % s, (_side(1.8, s), -2.2, 8.6), (_side(2.6, s), -2.9, 8.9), "Thorax"),
            ("Claw_%s_Upper" % s, (_side(2.6, s), -2.9, 8.9), (_side(4.6, s), -5.2, 10.2), "Claw_%s_Shoulder" % s),
            ("Claw_%s_Fore" % s, (_side(4.6, s), -5.2, 10.2), (_side(4.6, s), -7.2, 5.4), "Claw_%s_Upper" % s),
            ("Claw_%s_PincerA" % s, (_side(4.6, s), -7.2, 5.4), (_side(3.6, s), -9.6, 4.6), "Claw_%s_Fore" % s),
            ("Claw_%s_PincerB" % s, (_side(4.6, s), -7.2, 5.4), (_side(4.9, s), -8.8, 2.6), "Claw_%s_Fore" % s),
        ]
    for s in "LR":
        for i, y in enumerate(LEG_Y, start=1):
            hip, knee = (_side(2.8, s), y, 6.6), (_side(6.0, s), y * 1.15 - 0.3, 9.0)
            ankle, tip = (_side(7.6, s), y * 1.3 - 0.5, 3.0), (_side(8.0, s), y * 1.3 - 0.6, 0.0)
            bones += [
                ("Leg_%s%d_Upper" % (s, i), hip, knee, "Hips"),
                ("Leg_%s%d_Lower" % (s, i), knee, ankle, "Leg_%s%d_Upper" % (s, i)),
                ("Leg_%s%d_Foot" % (s, i), ankle, tip, "Leg_%s%d_Lower" % (s, i)),
            ]
    return bones


BONES = _bones()

COLOURS = {
    "Carapace": "#6E2A35", "CarapaceDark": "#4A1C26", "Chevron": "#EADBB8", "Moss": "#7E8F3A",
    "Ivory": "#E3D3B4", "Mouth": "#1E0B10", "Eye": "#FFB020", "Glow": "#FFE6A0",
}
EMISSIVE = {"Eye": 4.0, "Glow": 3.0}


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
        self._pin(bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)["verts"], bone)

    def gem(self, bone, centre, scale, subdiv=1, rot=(0, 0, 0)):
        m = Matrix.Translation(centre) @ euler(rot) @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1))
        self._pin(bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=1.0, matrix=m)["verts"], bone)

    def prism(self, bone, a, b, r1, r2, segments=5):
        a, b = Vector(a), Vector(b)
        axis = b - a
        rot = axis.to_track_quat("Z", "Y").to_matrix().to_4x4()
        m = Matrix.Translation((a + b) / 2) @ rot
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segments,
                                    radius1=r1, radius2=r2, depth=axis.length, matrix=m)
        self._pin(res["verts"], bone)


def _bone(name):
    return next(b for b in BONES if b[0] == name)


def build_pieces():
    p = {name: Piece(name) for name in COLOURS}
    car, dark, chev, moss, ivory = p["Carapace"], p["CarapaceDark"], p["Chevron"], p["Moss"], p["Ivory"]
    rng = random.Random(11)
    # abdomen: a faceted core and four overlapping plates that shrink toward the back
    dark.gem("Hips", (0, 4.2, 6.8), (3.2, 4.0, 2.2), 1)
    for i, (y, w) in enumerate(((1.4, 6.6), (3.2, 6.4), (5.0, 5.6), (6.8, 4.2))):
        car.box("Hips", (0, y, 8.5 - i * 0.35), (w, 2.4, 1.1), (-10 - i * 6, 0, 0))
        moss.gem("Hips", (rng.uniform(-1.6, 1.6), y - 0.3, 9.1 - i * 0.35), (0.9, 0.7, 0.2), 0)
        for side in (1, -1):
            moss.prism("Hips", (side * w * 0.42, y, 8.0 - i * 0.35), (side * w * 0.44, y + 0.1, 7.1 - i * 0.35), 0.18, 0.04, 4)
    dark.box("Hips", (0, 8.0, 6.0), (2.2, 1.6, 1.6), (25, 0, 0))  # tail spike
    p["Mouth"].gem("Root", (0, 3.0, 6.8), (0.3, 0.3, 0.3), 0)  # Root's hidden piece
    # thorax: a raised shield
    dark.gem("Thorax", (0, -0.9, 8.3), (2.6, 2.3, 1.9), 1)
    car.box("Thorax", (0, -1.1, 9.8), (5.0, 3.6, 1.0), (14, 0, 0))
    moss.gem("Thorax", (0.7, -0.9, 10.35), (1.0, 0.8, 0.22), 0)
    # head: a wedge skull, a dark brow plate, the grin and four amber eyes
    car.box("Head", (0, -4.7, 10.2), (3.6, 3.0, 2.6), (8, 0, 0))
    dark.box("Head", (0, -4.9, 11.7), (3.9, 2.8, 0.7), (16, 0, 0))
    p["Mouth"].box("Head", (0, -6.15, 9.3), (2.8, 0.3, 0.9))
    for k in range(6):
        x = -1.15 + k * 0.46
        ivory.prism("Head", (x, -6.2, 9.75), (x, -6.25, 9.0), 0.18, 0.02, 3)
    dark.box("Jaw", (0, -5.3, 8.65), (2.9, 2.0, 0.6))
    for k in range(5):
        x = -0.92 + k * 0.46
        ivory.prism("Jaw", (x, -6.15, 8.9), (x, -6.2, 9.5), 0.17, 0.02, 3)
    for s in "LR":
        p["Eye"].gem("Head", (_side(0.95, s), -6.05, 10.55), (0.55, 0.3, 0.42), 1)
        p["Eye"].gem("Head", (_side(0.45, s), -5.95, 11.25), (0.28, 0.2, 0.24), 0)
    # antennas: dark stalks with glowing cream bulbs
    for s in "LR":
        for seg in ("01", "02"):
            name = "Antenna_%s_%s" % (s, seg)
            _, a, b, _ = _bone(name)
            dark.prism(name, a, b, 0.24 if seg == "01" else 0.18, 0.18 if seg == "01" else 0.12, 4)
        _, _, tip, _ = _bone("Antenna_%s_02" % s)
        p["Glow"].gem("Antenna_%s_02" % s, tip, (0.42, 0.42, 0.42), 1)
    # claw arms: a shoulder knob, a dark upper arm, a big chevroned forearm plate and two ivory pincer blades
    for s in "LR":
        _, sh_a, sh_b, _ = _bone("Claw_%s_Shoulder" % s)
        dark.gem("Claw_%s_Shoulder" % s, sh_b, (0.9, 0.9, 0.9), 0)
        _, up_a, up_b, _ = _bone("Claw_%s_Upper" % s)
        dark.prism("Claw_%s_Upper" % s, up_a, up_b, 0.75, 0.6, 5)
        _, fo_a, fo_b, _ = _bone("Claw_%s_Fore" % s)
        car.prism("Claw_%s_Fore" % s, fo_a, fo_b, 1.2, 1.5, 5)
        mid = (Vector(fo_a) + Vector(fo_b)) / 2
        for k, dz in enumerate((0.9, -0.3)):
            for arm in (1, -1):
                chev.box("Claw_%s_Fore" % s, (mid.x + _side(1.35, s), mid.y + arm * 0.45, mid.z + dz + 0.4),
                         (0.15, 1.2, 0.32), (arm * 40, 0, 0))
        moss.gem("Claw_%s_Fore" % s, (fo_a[0], fo_a[1] - 0.4, fo_a[2] + 0.3), (0.8, 0.8, 0.25), 0)
        for blade, r in (("PincerA", 0.55), ("PincerB", 0.5)):
            _, a, b, _ = _bone("Claw_%s_%s" % (s, blade))
            ivory.prism("Claw_%s_%s" % (s, blade), a, b, r, 0.05, 4)
    # legs: dark upper and lower segments, a carapace knee plate, an ivory pointed foot
    for s in "LR":
        for i in range(1, len(LEG_Y) + 1):
            _, hip, knee, _ = _bone("Leg_%s%d_Upper" % (s, i))
            _, _, ankle, _ = _bone("Leg_%s%d_Lower" % (s, i))
            _, _, tip, _ = _bone("Leg_%s%d_Foot" % (s, i))
            dark.prism("Leg_%s%d_Upper" % (s, i), hip, knee, 0.55, 0.45, 5)
            car.gem("Leg_%s%d_Upper" % (s, i), knee, (0.75, 0.75, 0.7), 0)
            (car if i % 2 else dark).prism("Leg_%s%d_Lower" % (s, i), knee, ankle, 0.5, 0.32, 5)
            ivory.prism("Leg_%s%d_Foot" % (s, i), ankle, tip, 0.32, 0.05, 4)
    return p


def own_scene():
    """A scene of its own, rebuilt from nothing each run; other scenes of the open file are not touched."""
    scene = bpy.data.scenes.get(SCENE_NAME) or bpy.data.scenes.new(SCENE_NAME)
    for o in list(scene.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.window.scene = scene
    return scene


def material(name):
    mat = bpy.data.materials.get(name + "Mat") or bpy.data.materials.new(name + "Mat")
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = hex_rgba(COLOURS[name])
    bsdf.inputs["Roughness"].default_value = 0.8
    if name in EMISSIVE:
        bsdf.inputs["Emission Color"].default_value = hex_rgba(COLOURS[name])
        bsdf.inputs["Emission Strength"].default_value = EMISSIVE[name]
    mat.diffuse_color = hex_rgba(COLOURS[name])
    return mat


def build():
    scene = own_scene()
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    arm_data = bpy.data.armatures.new("ScuttlerRig")
    arm = bpy.data.objects.new("Scuttler", arm_data)
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
        me.materials.append(material(name))
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


def render_previews(scene, folder):
    """Front, side and back stills through an orthographic camera (helper objects removed afterwards)."""
    os.makedirs(folder, exist_ok=True)
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "BLENDER_WORKBENCH"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.render.resolution_x = scene.render.resolution_y = 768
    scene.render.film_transparent = False
    world = bpy.data.worlds.get("ScuttlerWorld") or bpy.data.worlds.new("ScuttlerWorld")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.05, 0.06, 0.07, 1)
    bg.inputs["Strength"].default_value = 1.0
    scene.world = world
    helpers = []
    cam = bpy.data.objects.new("PreviewCamera", bpy.data.cameras.new("PreviewCamera"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 19.0
    scene.collection.objects.link(cam)
    helpers.append(cam)
    for name, rot, energy in (("Key", (50, 0, -30), 4.0), ("Fill", (60, 0, 150), 1.5)):
        sun = bpy.data.objects.new("Preview" + name, bpy.data.lights.new("Preview" + name, "SUN"))
        sun.data.energy = energy
        sun.rotation_euler = Euler(tuple(math.radians(a) for a in rot))
        scene.collection.objects.link(sun)
        helpers.append(sun)
    scene.camera = cam
    target = Vector((0, 0, 6.8))
    views = {"front": Vector((0, -40, 6.8)), "side": Vector((-40, 0, 6.8)), "back": Vector((0, 40, 6.8))}
    written = []
    for view, eye in views.items():
        cam.location = eye
        cam.rotation_euler = (target - eye).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "scuttler-%s.png" % view)
        bpy.ops.render.render(write_still=True, scene=scene.name)
        written.append(scene.render.filepath)
    for o in helpers:
        data = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        if isinstance(data, bpy.types.Camera):
            bpy.data.cameras.remove(data)
        else:
            bpy.data.lights.remove(data)
    return written


SCENE, ARM, MESHES = build()
bpy.context.view_layer.update()
_corners = [m.matrix_world @ Vector(c) for m in MESHES for c in m.bound_box]
STATS = {
    "bones": len(BONES), "meshes": len(MESHES),
    "verts": sum(len(m.data.vertices) for m in MESHES),
    "tris": sum(sum(len(p.vertices) - 2 for p in m.data.polygons) for m in MESHES),
    "height": round(max(c.z for c in _corners) - min(c.z for c in _corners), 2),
    "width": round(max(c.x for c in _corners) - min(c.x for c in _corners), 2),
    "length": round(max(c.y for c in _corners) - min(c.y for c in _corners), 2),
    "min_z": round(min(c.z for c in _corners), 3),
}
if EXPORT:
    export(EXPORT, ARM, MESHES)
    STATS["exported"] = EXPORT
if PREVIEW_DIR:
    STATS["previews"] = render_previews(SCENE, PREVIEW_DIR)
print(STATS)

"""Don Glaseon, the territorial boss of the Caramelo biome (odd/tasks/wildbound-caramelo.md, CA3).

Pack: 03_PERSONAJES/04_DON_GLASEON_BOSS.md, 06_PROMPTS_CLAUDE/06 and 01_REFERENCIAS/BOSS/04_Don_Glaseon_Turnaround.png.
Low-poly, faceted biped about 23.5 studs tall: a torso of angular pink frosting masses, a huge toothed mouth, a pile
of big candies on top of the head, long arms with cream claws, short purple grape legs. No chef hat, no crown, no
robe. The right forearm carries a coiled licorice whip (Licorice_01..03); its long lash is a client VFX, the bones
only swing the coil.

Units: 1 Blender unit = 1 stud. The creature faces -Y; its left side is +X. Roblox reads the FBX as
X = -x, Y = z, Z = y, so its front is -Z there.

Every mesh is skinned, and every vertex belongs to exactly one bone (rigid skinning): the importer keeps only the
bones a skinned vertex uses, so each of the 29 bones owns at least one piece (Root and Neck own small gems hidden in
the body). No mesh is named like a bone: the importer would hang that bone under it.

Run inside Blender:  exec(open(r"<repo>/assets/blender/caramelo/don-glaseon/build_don_glaseon.py").read())
It rebuilds its own scene from nothing and, with DON_EXPORT_PATH set, writes the FBX for upload.
"""
import math
import random

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

EXPORT = globals().get("DON_EXPORT_PATH")


def side_bones(s, x):
    """The arm and leg chain of one side; x is +1 for the left (+X), -1 for the right."""
    return [
        ("Shoulder_%s" % s, (2.6 * x, 0, 15.2), (4.4 * x, 0, 15.4), "Spine_Upper"),
        ("UpperArm_%s" % s, (4.8 * x, 0, 15.0), (6.0 * x, -0.5, 10.5), "Shoulder_%s" % s),
        ("Forearm_%s" % s, (6.0 * x, -0.5, 10.5), (6.2 * x, -1.5, 6.2), "UpperArm_%s" % s),
        ("Hand_%s" % s, (6.2 * x, -1.5, 6.2), (6.2 * x, -2.2, 4.6), "Forearm_%s" % s),
        ("Finger_%s1" % s, (6.8 * x, -2.4, 4.6), (7.0 * x, -3.6, 2.8), "Hand_%s" % s),
        ("Finger_%s2" % s, (5.6 * x, -2.4, 4.6), (5.4 * x, -3.6, 2.8), "Hand_%s" % s),
        ("Thigh_%s" % s, (2.2 * x, 0, 7.0), (2.3 * x, 0, 3.6), "Pelvis"),
        ("Shin_%s" % s, (2.3 * x, 0, 3.6), (2.3 * x, 0.2, 0.9), "Thigh_%s" % s),
        ("Foot_%s" % s, (2.3 * x, 0.2, 0.9), (2.3 * x, -1.8, 0.4), "Shin_%s" % s),
    ]


BONES = [
    # name, head, tail, parent
    ("Root", (0, 0, 0), (0, 0, 1), None),
    ("Pelvis", (0, 0, 7.0), (0, 0, 8.5), "Root"),
    ("Spine_Lower", (0, 0, 8.5), (0, 0, 12.0), "Pelvis"),
    ("Spine_Upper", (0, 0, 12.0), (0, 0, 15.8), "Spine_Lower"),
    ("Neck", (0, 0, 15.8), (0, -0.4, 16.8), "Spine_Upper"),
    ("Head", (0, -0.4, 16.8), (0, -0.4, 21.0), "Neck"),
    ("Jaw", (0, 0.8, 17.2), (0, -3.6, 16.8), "Head"),
    ("CandyCrown", (0, 0, 21.0), (0, 0, 24.0), "Head"),
] + side_bones("L", 1) + side_bones("R", -1) + [
    # the licorice whip coiled along the outside of the right forearm, wrist to elbow
    ("Licorice_01", (-7.2, -0.7, 10.0), (-7.4, -1.0, 8.6), "Forearm_R"),
    ("Licorice_02", (-7.4, -1.0, 8.6), (-7.5, -1.4, 7.2), "Licorice_01"),
    ("Licorice_03", (-7.5, -1.4, 7.2), (-7.5, -1.8, 5.8), "Licorice_02"),
]

COLOURS = {
    "Body": "#EE8CC4", "Shade": "#D9529A", "Mouth": "#5A1030", "Teeth": "#F3E6D3", "Claw": "#EAD2C4",
    "Leg": "#7B3F8C", "Eye": "#FFE3F1", "CandyA": "#2EC4D6", "CandyB": "#F2C230", "CandyC": "#F07A2A",
    "CandyD": "#8E44AD", "CandyE": "#E8344E", "Licorice": "#E23C8A", "Stripe": "#FFF4F8",
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


def build_pieces():
    p = {name: Piece(name) for name in COLOURS}
    body, shade, claw, leg = p["Body"], p["Shade"], p["Claw"], p["Leg"]
    rng = random.Random(20261115)
    # hidden owners: Root in the hips, Neck inside the throat
    body.gem("Root", (0, 0.4, 7.6), (0.3, 0.3, 0.3), 0)
    body.gem("Neck", (0, 0, 16.3), (2.6, 2.4, 1.2))
    # torso: a core per spine bone and a crust of angular frosting masses (the reference's faceted cluster)
    body.gem("Pelvis", (0, 0.2, 8.0), (3.6, 2.9, 1.9))
    body.gem("Spine_Lower", (0, 0, 10.6), (4.1, 3.2, 2.6))
    body.gem("Spine_Upper", (0, 0, 14.0), (4.3, 3.3, 2.6))
    for i in range(46):
        a = rng.uniform(0, 2 * math.pi)
        z = rng.uniform(7.2, 15.8)
        bulge = 1.0 - ((z - 11.5) / 6.0) ** 2 * 0.35
        x, y = math.cos(a) * 3.9 * bulge, math.sin(a) * 3.0 * bulge
        bone = "Pelvis" if z < 8.6 else ("Spine_Lower" if z < 12.0 else "Spine_Upper")
        s = rng.uniform(1.0, 1.55)
        mesh = shade if i % 5 == 0 else body
        mesh.gem(bone, (x, y, z), (s, s * 0.8, s * 0.85), 0, (rng.uniform(0, 60), rng.uniform(0, 60), rng.uniform(0, 90)))
    # a pointed frosting drip under the belly, as in the side views
    shade.prism("Pelvis", (0, -1.2, 7.4), (0, -1.6, 5.6), 1.1, 0.1, 5)
    # head: a wide skull over a huge mouth; the jaw hangs open a little
    head = "Head"
    body.box(head, (0, -0.6, 20.0), (7.6, 6.2, 2.4), (-6, 0, 0))
    body.gem(head, (0, 0.6, 18.4), (3.6, 2.8, 2.2))
    for x in (-3.4, 3.4):
        body.gem(head, (x, -1.0, 19.0), (1.3, 2.6, 1.6))
        shade.gem(head, (x * 0.85, -3.0, 20.6), (1.2, 0.8, 0.7), 0)  # the brows over the eyes
    p["Mouth"].box(head, (0, -1.6, 17.6), (6.4, 3.4, 3.0))
    for x in (-1.9, 1.9):
        p["Eye"].gem(head, (x, -3.25, 20.15), (0.45, 0.2, 0.28), 1)
    # upper teeth along the lip and the sides, pointing down
    for i in range(7):
        x = -2.7 + i * 0.9
        p["Teeth"].prism(head, (x, -3.25, 18.9), (x * 0.95, -3.35, 17.4 - (0.4 if i % 2 else 0)), 0.45, 0.04, 4)
    for x in (-3.3, 3.3):
        for y in (-2.2, -1.1):
            p["Teeth"].prism(head, (x, y, 18.9), (x * 0.97, y, 17.6), 0.36, 0.04, 4)
    # the jaw: a slab with its own row of teeth pointing up
    body.box("Jaw", (0, -1.2, 15.9), (6.8, 5.0, 1.3))
    shade.box("Jaw", (0, -3.5, 15.8), (5.8, 0.8, 1.0))
    for i in range(6):
        x = -2.25 + i * 0.9
        p["Teeth"].prism("Jaw", (x, -3.35, 16.4), (x * 0.95, -3.3, 17.5), 0.4, 0.04, 4)
    # the candy pile: a pink rim on the skull and big faceted candies in five colours
    body.box("CandyCrown", (0, -0.2, 21.3), (6.0, 4.6, 0.6))
    candies = ["CandyA", "CandyB", "CandyC", "CandyD", "CandyE"]
    spots = [(-2.3, -1.3, 22.2), (0, -1.8, 22.3), (2.3, -1.3, 22.2), (-2.4, 1.0, 22.2), (0.1, 0.5, 22.4),
             (2.4, 1.0, 22.2), (-1.2, -0.5, 23.6), (1.3, -0.4, 23.6), (0, 1.5, 23.4)]
    for i, c in enumerate(spots):
        r = 1.35 if c[2] < 23 else 1.2
        p[candies[i % 5]].gem("CandyCrown", c, (r, r, r * 0.95), 1)
    # arms: a big shoulder mass, a thick faceted upper arm and forearm, a block hand with three cream claws
    for s, x in (("L", 1), ("R", -1)):
        body.gem("Shoulder_%s" % s, (4.3 * x, 0, 15.2), (2.0, 1.9, 1.9))
        body.prism("UpperArm_%s" % s, (4.8 * x, 0, 15.0), (6.0 * x, -0.5, 10.5), 1.35, 1.2)
        shade.gem("UpperArm_%s" % s, (5.5 * x, -0.2, 12.8), (1.5, 1.4, 1.6), 0)
        body.prism("Forearm_%s" % s, (6.0 * x, -0.5, 10.5), (6.2 * x, -1.5, 6.2), 1.4, 1.2)
        body.gem("Forearm_%s" % s, (6.1 * x, -0.9, 8.6), (1.7, 1.6, 1.8), 0)
        body.box("Hand_%s" % s, (6.2 * x, -1.9, 5.3), (2.4, 2.2, 1.9), (-15, 0, 0))
        claw.prism("Finger_%s1" % s, (6.8 * x, -2.4, 4.6), (7.0 * x, -3.6, 2.8), 0.5, 0.08, 4)
        claw.prism("Finger_%s2" % s, (5.6 * x, -2.4, 4.6), (5.4 * x, -3.6, 2.8), 0.5, 0.08, 4)
        claw.prism("Hand_%s" % s, (6.2 * x, -2.7, 4.5), (6.2 * x, -3.9, 2.9), 0.5, 0.08, 4)
        # legs: short purple grape masses on hoof-like feet with cream toe claws
        leg.prism("Thigh_%s" % s, (2.2 * x, 0, 7.2), (2.3 * x, 0, 3.6), 1.7, 1.35)
        leg.gem("Thigh_%s" % s, (2.25 * x, 0, 5.6), (1.9, 1.8, 1.7), 0)
        leg.prism("Shin_%s" % s, (2.3 * x, 0, 3.7), (2.3 * x, 0.2, 0.9), 1.3, 1.6)
        leg.box("Foot_%s" % s, (2.3 * x, -0.6, 0.45), (3.0, 3.6, 0.9))
        for dx in (-0.8, 0, 0.8):
            claw.prism("Foot_%s" % s, (2.3 * x + dx, -2.2, 0.35), (2.3 * x + dx, -3.1, 0.15), 0.35, 0.05, 4)
    # the licorice coil on the right forearm: pink links with white bands
    for bone, a, b in (("Licorice_01", (-7.2, -0.7, 10.0), (-7.4, -1.0, 8.6)),
                       ("Licorice_02", (-7.4, -1.0, 8.6), (-7.5, -1.4, 7.2)),
                       ("Licorice_03", (-7.5, -1.4, 7.2), (-7.5, -1.8, 5.8))):
        p["Licorice"].prism(bone, a, b, 0.5, 0.45, 6)
        mid = (Vector(a) + Vector(b)) / 2
        p["Stripe"].prism(bone, mid + Vector((0, 0.06, 0.18)), mid - Vector((0, 0.06, 0.18)), 0.56, 0.56, 6)
    return p


def own_scene():
    """A scene of its own, rebuilt from nothing each run; other scenes of the open file are not touched."""
    scene = bpy.data.scenes.get("DonGlaseon") or bpy.data.scenes.new("DonGlaseon")
    for o in list(scene.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.window.scene = scene
    return scene


def build():
    scene = own_scene()
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    arm_data = bpy.data.armatures.new("DonGlaseonRig")
    arm = bpy.data.objects.new("DonGlaseon", arm_data)
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
    clash = [o.name for o in meshes if o.name in {b[0] for b in BONES}]
    assert not clash, "meshes named like bones: %s" % clash
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
         "verts": sum(len(m.data.vertices) for m in MESHES),
         "height": max((m.matrix_world @ v.co).z for m in MESHES for v in m.data.vertices)}
if EXPORT:
    export(EXPORT, ARM, MESHES)
    STATS["exported"] = EXPORT
print(STATS)

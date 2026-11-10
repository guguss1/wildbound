"""Build the Wildbound Gargoyle in headless Blender.

Run:  blender -b --factory-startup --python gargoyle_build.py -- [--no-render]
Outputs into assets/models/beasts/ (blend, FBX, palette, previews).
"""

import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import beastkit as bk  # noqa: E402

OUT = os.path.normpath(os.path.join(HERE, ".."))
PREV = os.path.join(OUT, "previews")
ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []

PALETTE = [
    ("stone", (0.62, 0.58, 0.68), False),
    ("stone_dark", (0.47, 0.43, 0.55), False),
    ("membrane", (0.50, 0.45, 0.61), False),
    ("claw", (0.37, 0.34, 0.45), False),
    ("moss", (0.50, 0.60, 0.14), False),
    ("eye", (0.30, 1.00, 0.92), True),
]

BONES = [
    ("Root", (0, 0, 0), (0, -1.0, 0), None, False),
    ("Hips", (0, 1.1, 2.3), (0, 0.0, 2.9), "Root", False),
    ("Spine", (0, 0.0, 2.9), (0, -1.3, 3.8), "Hips", True),
    ("Head", (0, -1.4, 4.0), (0, -2.3, 4.9), "Spine", False),
    ("Jaw", (0, -1.9, 4.05), (0, -2.9, 3.9), "Head", False),
    ("Tail", (0, 1.7, 2.1), (0, 3.6, 0.8), "Hips", False),
    ("Arm_L_Upper", (1.55, -0.9, 3.6), (1.75, -1.7, 2.0), "Spine", False),
    ("Arm_L_Lower", (1.75, -1.7, 2.0), (1.8, -2.15, 0.45), "Arm_L_Upper", True),
    ("Arm_R_Upper", (-1.55, -0.9, 3.6), (-1.75, -1.7, 2.0), "Spine", False),
    ("Arm_R_Lower", (-1.75, -1.7, 2.0), (-1.8, -2.15, 0.45), "Arm_R_Upper", True),
    ("Leg_L_Upper", (1.15, 1.1, 2.2), (1.7, 0.1, 1.35), "Hips", False),
    ("Leg_L_Lower", (1.7, 0.1, 1.35), (1.7, 1.15, 0.45), "Leg_L_Upper", True),
    ("Leg_R_Upper", (-1.15, 1.1, 2.2), (-1.7, 0.1, 1.35), "Hips", False),
    ("Leg_R_Lower", (-1.7, 0.1, 1.35), (-1.7, 1.15, 0.45), "Leg_R_Upper", True),
    ("Wing_L_1", (0.9, 0.5, 4.0), (2.6, 0.8, 6.0), "Spine", False),
    ("Wing_L_2", (2.6, 0.8, 6.0), (4.5, 1.0, 7.2), "Wing_L_1", True),
    ("Wing_L_3", (4.5, 1.0, 7.2), (6.9, 1.4, 1.3), "Wing_L_2", True),
    ("Wing_R_1", (-0.9, 0.5, 4.0), (-2.6, 0.8, 6.0), "Spine", False),
    ("Wing_R_2", (-2.6, 0.8, 6.0), (-4.5, 1.0, 7.2), "Wing_R_1", True),
    ("Wing_R_3", (-4.5, 1.0, 7.2), (-6.9, 1.4, 1.3), "Wing_R_2", True),
]


def build_mesh(col):
    b = bk.Builder(PALETTE, seed=31)
    R, P, PL, M = b.rock, b.prism, b.plate, b.mirror

    # ---- torso -------------------------------------------------------------
    R(center=(0, -0.75, 3.35), size=(2.5, 2.1, 2.2), color="stone", bone="Spine", rot=(-18, 0, 0))
    R(center=(0, -1.55, 2.95), size=(1.7, 0.7, 1.5), color="stone_dark", bone="Spine", rot=(-10, 0, 0))
    R(center=(0, -0.2, 4.35), size=(1.9, 1.7, 0.7), color="stone_dark", bone="Spine", rot=(-12, 0, 0))
    R(center=(0, 0.65, 2.55), size=(2.0, 1.8, 1.6), color="stone", bone="Hips", rot=(-8, 0, 0))
    R(center=(0, 1.45, 2.3), size=(1.8, 1.2, 1.2), color="stone_dark", bone="Hips")
    M(R, center=(0.7, -1.45, 3.45), size=(1.0, 0.7, 1.0), color="stone", bone="Spine", rot=(-15, 0, -15))
    R(center=(0, -1.2, 2.3), size=(1.2, 0.8, 0.8), color="stone_dark", bone="Spine", rot=(20, 0, 0))
    # spine ridge plates
    for i, (y, z) in enumerate(((-0.9, 4.65), (-0.1, 4.75), (0.7, 3.65), (1.4, 3.0))):
        P(p0=(0, y, z - 0.35), p1=(0, y + 0.25, z + 0.35), r0=0.28, r1=0.0, color="stone_dark",
          bone="Spine" if i < 2 else "Hips", sides=4)

    # ---- neck + head -------------------------------------------------------
    R(center=(0, -1.45, 4.0), size=(1.35, 1.2, 1.05), color="stone_dark", bone="Head", rot=(-20, 0, 0))
    R(center=(0, -2.1, 4.5), size=(1.75, 1.5, 1.3), color="stone", bone="Head", rot=(8, 0, 0))
    R(center=(0, -1.95, 5.15), size=(1.3, 1.1, 0.45), color="stone_dark", bone="Head", rot=(12, 0, 0))
    # snout wedge pointing down/forward, nose plate
    R(center=(0, -2.95, 4.1), size=(1.15, 1.0, 0.8), color="stone", bone="Head", rot=(-12, 0, 0), taper=(0.8, 0.75))
    R(center=(0, -3.42, 4.12), size=(0.6, 0.35, 0.45), color="stone_dark", bone="Head", rot=(-20, 0, 0))
    # heavy angry brow + cheeks
    M(R, center=(0.48, -2.8, 4.88), size=(0.8, 0.6, 0.34), color="stone_dark", bone="Head", rot=(-18, 0, -24))
    M(R, center=(0.88, -2.3, 4.25), size=(0.5, 0.95, 0.75), color="stone", bone="Head", rot=(0, 8, -12))
    M(R, center=(0.43, -2.92, 4.6), size=(0.36, 0.14, 0.2), color="eye", bone="Head", rot=(0, 0, -14), bevel=0.2, jitter=0.0)
    # jaw + fangs
    R(center=(0, -2.65, 3.72), size=(1.1, 1.1, 0.42), color="stone_dark", bone="Jaw", rot=(-6, 0, 0))
    M(P, p0=(0.32, -3.15, 3.95), p1=(0.35, -3.2, 3.55), r0=0.11, r1=0.0, color="claw", bone="Head", sides=4)
    # horns curving back (left horn broken off)
    M(P, p0=(0.5, -1.85, 5.15), p1=(0.95, -1.35, 5.95), r0=0.34, r1=0.24, color="stone_dark", bone="Head", sides=5)
    P(p0=(-0.95, -1.35, 5.95), p1=(-1.1, -0.65, 6.5), r0=0.24, r1=0.15, color="stone_dark", bone="Head", sides=5)
    P(p0=(-1.1, -0.65, 6.5), p1=(-1.05, 0.05, 6.75), r0=0.15, r1=0.0, color="stone_dark", bone="Head", sides=5)
    P(p0=(0.95, -1.35, 5.95), p1=(1.05, -1.05, 6.25), r0=0.24, r1=0.19, color="stone_dark", bone="Head", sides=5)
    # ears / cheek spikes and crown
    M(P, p0=(0.85, -1.8, 4.75), p1=(1.65, -1.4, 5.15), r0=0.2, r1=0.0, color="stone", bone="Head", sides=4)
    P(p0=(0, -2.0, 5.3), p1=(0, -1.6, 5.7), r0=0.2, r1=0.0, color="stone_dark", bone="Head", sides=4)
    R(center=(0.35, -1.75, 5.38), size=(0.5, 0.45, 0.1), color="moss", bone="Head", rot=(12, 0, 0), jitter=0.03)

    # ---- front arms + hands ----------------------------------------------------
    # massive hunched shoulder boulders
    M(R, center=(1.55, -0.85, 3.85), size=(1.5, 1.55, 1.35), color="stone", bone="Arm_L_Upper", rot=(-10, 12, -10))
    M(R, center=(1.95, -0.55, 4.35), size=(0.85, 0.9, 0.7), color="stone_dark", bone="Arm_L_Upper", rot=(0, 25, 10))
    M(R, center=(1.5, -0.95, 4.55), size=(1.05, 1.0, 0.2), color="moss", bone="Arm_L_Upper", rot=(-10, 12, -10), jitter=0.05)
    # upper arm: two stacked rocks
    M(R, center=(1.65, -1.25, 2.95), size=(1.1, 1.05, 1.05), color="stone", bone="Arm_L_Upper", rot=(25, 5, -6))
    M(R, center=(1.75, -1.6, 2.2), size=(0.95, 0.95, 0.75), color="stone_dark", bone="Arm_L_Upper", rot=(30, 0, 8))
    # forearm: two rocks + elbow chip
    M(R, center=(1.8, -1.85, 1.55), size=(1.0, 0.95, 0.95), color="stone", bone="Arm_L_Lower", rot=(12, -4, 5))
    M(R, center=(1.82, -2.05, 0.85), size=(0.9, 0.9, 0.75), color="stone", bone="Arm_L_Lower", rot=(5, 6, -6))
    M(R, center=(2.25, -1.55, 1.9), size=(0.4, 0.55, 0.5), color="stone_dark", bone="Arm_L_Lower", rot=(0, 20, 0))
    # hand: palm + four chunky fingers with claws + thumb
    M(R, center=(1.82, -2.4, 0.35), size=(1.2, 1.05, 0.62), color="stone", bone="Arm_L_Lower", rot=(0, 0, 4))
    for dx in (-0.42, -0.14, 0.14, 0.42):
        M(R, center=(1.82 + dx * 1.15, -2.98, 0.28), size=(0.3, 0.55, 0.42), color="stone", bone="Arm_L_Lower", rot=(-12, 0, -dx * 25), bevel=0.12)
        M(P, p0=(1.82 + dx * 1.2, -3.2, 0.28), p1=(1.82 + dx * 1.3, -3.55, 0.03), r0=0.15, r1=0.0, color="claw", bone="Arm_L_Lower", sides=4)
    M(P, p0=(1.3, -2.35, 0.35), p1=(0.95, -2.8, 0.08), r0=0.17, r1=0.0, color="claw", bone="Arm_L_Lower", sides=4)
    R(center=(1.95, -2.55, 0.7), size=(0.7, 0.6, 0.13), color="moss", bone="Arm_L_Lower", jitter=0.03)

    # ---- hind legs + feet --------------------------------------------------------
    M(R, center=(1.5, 0.7, 1.95), size=(1.25, 1.7, 1.55), color="stone", bone="Leg_L_Upper", rot=(35, 0, -10))
    M(R, center=(1.75, 0.15, 1.3), size=(0.75, 0.7, 0.7), color="stone_dark", bone="Leg_L_Lower", rot=(10, 0, 0))
    M(R, center=(1.72, 0.75, 0.8), size=(0.7, 0.75, 0.9), color="stone", bone="Leg_L_Lower", rot=(-35, 0, 0))
    M(R, center=(1.72, 0.8, 0.28), size=(1.0, 1.25, 0.52), color="stone", bone="Leg_L_Lower")
    for dx in (-0.3, 0.0, 0.3):
        M(P, p0=(1.72 + dx, 0.3, 0.25), p1=(1.72 + dx * 1.2, -0.1, 0.03), r0=0.16, r1=0.0, color="claw", bone="Leg_L_Lower", sides=4)

    # ---- tail ------------------------------------------------------------------
    P(p0=(0, 1.7, 2.1), p1=(0, 2.7, 1.3), r0=0.5, r1=0.35, color="stone", bone="Tail")
    P(p0=(0, 2.7, 1.3), p1=(0, 3.5, 0.6), r0=0.35, r1=0.2, color="stone_dark", bone="Tail")
    P(p0=(0, 3.5, 0.6), p1=(0, 4.1, 0.35), r0=0.25, r1=0.0, color="stone_dark", bone="Tail", sides=4)

    # ---- wings -------------------------------------------------------------------
    root, elbow, wrist, tip = (0.9, 0.5, 4.0), (2.6, 0.8, 6.0), (4.5, 1.0, 7.2), (6.9, 1.4, 1.3)
    low_root, rib2, rib1 = (1.05, 0.65, 3.3), (2.9, 1.0, 3.0), (4.7, 1.15, 2.4)
    # spars
    M(P, p0=root, p1=elbow, r0=0.42, r1=0.32, color="stone", bone="Wing_L_1")
    M(R, center=elbow, size=(0.65, 0.6, 0.6), color="stone_dark", bone="Wing_L_2", rot=(0, -30, 0))
    M(P, p0=elbow, p1=wrist, r0=0.34, r1=0.3, color="stone", bone="Wing_L_2")
    M(R, center=wrist, size=(0.6, 0.55, 0.6), color="stone_dark", bone="Wing_L_3", rot=(0, -25, 0))
    M(P, p0=(4.5, 1.0, 7.2), p1=(4.2, 0.6, 8.0), r0=0.25, r1=0.0, color="stone_dark", bone="Wing_L_2", sides=4)
    M(P, p0=wrist, p1=(5.9, 1.2, 4.0), r0=0.42, r1=0.3, color="stone", bone="Wing_L_3")
    M(P, p0=(5.9, 1.2, 4.0), p1=tip, r0=0.3, r1=0.0, color="stone_dark", bone="Wing_L_3", sides=5)
    M(P, p0=wrist, p1=rib1, r0=0.16, r1=0.08, color="stone_dark", bone="Wing_L_3", sides=4)
    M(P, p0=elbow, p1=rib2, r0=0.16, r1=0.08, color="stone_dark", bone="Wing_L_2", sides=4)
    # membrane plates (thick rocky slabs), set slightly behind the spars
    mem = lambda p: (p[0], p[1] + 0.12, p[2])  # noqa: E731
    M(PL, points=[mem(low_root), mem(root), mem(elbow), mem(rib2)], thickness=0.16, color="membrane", bone="Wing_L_1")
    M(PL, points=[mem(elbow), mem(wrist), mem((3.9, 1.1, 2.75))], thickness=0.16, color="stone_dark", bone="Wing_L_2")
    M(PL, points=[mem(elbow), mem((3.9, 1.1, 2.75)), mem(rib2)], thickness=0.16, color="membrane", bone="Wing_L_2")
    M(PL, points=[mem(wrist), mem(rib1), mem((3.9, 1.1, 2.75))], thickness=0.16, color="membrane", bone="Wing_L_3")
    M(PL, points=[mem(wrist), mem((5.9, 1.2, 4.0)), mem(tip), mem(rib1)], thickness=0.16, color="stone_dark", bone="Wing_L_3")
    # broad stone cap plates on the wing's top edge (the chunky "arm" look)
    M(R, center=(3.55, 0.8, 6.75), size=(2.2, 0.7, 0.65), color="stone", bone="Wing_L_2", rot=(0, -32, 0))
    M(R, center=(1.75, 0.65, 5.05), size=(1.9, 0.65, 0.6), color="stone", bone="Wing_L_1", rot=(0, -50, 0))
    R(center=(3.45, 0.75, 7.15), size=(1.4, 0.6, 0.14), color="moss", bone="Wing_L_2", rot=(0, -32, 0), jitter=0.03)
    P(p0=(3.0, 0.5, 6.6), p1=(3.05, 0.45, 5.5), r0=0.12, r1=0.0, color="moss", bone="Wing_L_2", sides=4)
    P(p0=(3.6, 0.5, 7.0), p1=(3.65, 0.45, 6.2), r0=0.1, r1=0.0, color="moss", bone="Wing_L_2", sides=4)
    R(center=(-1.6, 0.6, 5.4), size=(0.9, 0.5, 0.12), color="moss", bone="Wing_R_1", rot=(0, 50, 0), jitter=0.03)
    # moss drips
    P(p0=(-1.6, -1.35, 4.0), p1=(-1.7, -1.5, 3.1), r0=0.12, r1=0.0, color="moss", bone="Arm_R_Upper", sides=4)
    P(p0=(1.3, -1.5, 3.9), p1=(1.25, -1.65, 3.2), r0=0.1, r1=0.0, color="moss", bone="Arm_L_Upper", sides=4)
    P(p0=(5.2, 1.4, 5.6), p1=(5.3, 1.4, 4.4), r0=0.1, r1=0.0, color="moss", bone="Wing_L_3", sides=4)

    # extra chipped stone detail (back armour, chest plates, knuckle spikes)
    M(R, center=(0.8, 0.3, 3.9), size=(0.9, 1.2, 0.6), color="stone_dark", bone="Spine", rot=(-10, 15, 0))
    M(R, center=(1.0, 1.2, 2.9), size=(0.9, 1.0, 0.7), color="stone", bone="Hips", rot=(10, 20, 0))
    M(R, center=(0.55, -1.9, 2.55), size=(0.7, 0.5, 0.8), color="stone_dark", bone="Spine", rot=(10, 0, -8))
    M(P, p0=elbow, p1=(2.3, 0.55, 6.8), r0=0.2, r1=0.0, color="stone_dark", bone="Wing_L_2", sides=4)
    M(P, p0=(2.0, -1.45, 2.4), p1=(2.6, -1.1, 2.75), r0=0.18, r1=0.0, color="stone_dark", bone="Arm_L_Upper", sides=4)

    return b.to_object("Gargoyle_Mesh", col)


def poses():
    X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
    rest = {}
    statue = {
        "Hips": {"rot": [(X, -15)], "loc": (0, 0.2, 0.12)},
        "Spine": {"rot": [(X, -6)]},
        "Head": {"rot": [(X, 18)]},
        "Arm_L_Upper": {"rot": [(X, 40)]},
        "Arm_R_Upper": {"rot": [(X, 40)]},
        "Leg_L_Upper": {"rot": [(X, 18)]},
        "Leg_R_Upper": {"rot": [(X, 18)]},
        "Leg_L_Lower": {"rot": [(X, -10)]},
        "Leg_R_Lower": {"rot": [(X, -10)]},
        "Wing_L_1": {"rot": [(Z, 55), (Y, -12)]},
        "Wing_R_1": {"rot": [(Z, -55), (Y, 12)]},
        "Wing_L_2": {"rot": [(Z, 60)]},
        "Wing_R_2": {"rot": [(Z, -60)]},
        "Wing_L_3": {"rot": [(Z, 35), (Y, 15)]},
        "Wing_R_3": {"rot": [(Z, -35), (Y, -15)]},
        "Tail": {"rot": [(X, 25)]},
    }
    wings_up = {
        "Wing_L_1": {"rot": [(Y, -12)]},
        "Wing_R_1": {"rot": [(Y, 12)]},
        "Wing_L_2": {"rot": [(Y, -10)]},
        "Wing_R_2": {"rot": [(Y, 10)]},
        "Wing_L_3": {"rot": [(Y, -25)]},
        "Wing_R_3": {"rot": [(Y, 25)]},
        "Head": {"rot": [(X, -10)]},
        "Jaw": {"rot": [(X, 15)]},
    }
    attack = {
        "Hips": {"rot": [(X, 8)], "loc": (0, 0, 0.25)},
        "Spine": {"rot": [(X, 14)]},
        "Head": {"rot": [(X, -14)]},
        "Jaw": {"rot": [(X, 28)]},
        "Arm_L_Upper": {"rot": [(X, -70), (Y, -10)]},
        "Arm_L_Lower": {"rot": [(X, -30)]},
        "Wing_L_1": {"rot": [(Z, -30), (Y, -8)]},
        "Wing_R_1": {"rot": [(Z, 30), (Y, 8)]},
        "Wing_L_2": {"rot": [(Z, -25)]},
        "Wing_R_2": {"rot": [(Z, 25)]},
        "Wing_L_3": {"rot": [(Z, -20), (Y, -15)]},
        "Wing_R_3": {"rot": [(Z, 20), (Y, 15)]},
    }
    return rest, statue, wings_up, attack


def main():
    scene = bk.reset_scene()
    scene.render.fps = 30
    model_col = bk.get_collection("Gargoyle")
    prev_col = bk.get_collection("Preview_Only")

    mesh = build_mesh(model_col)
    mat, glow = bk.make_palette_materials("Gargoyle", PALETTE, os.path.join(OUT, "gargoyle_palette.png"))
    mesh.data.materials.append(mat)
    mesh.data.materials.append(glow)
    arm = bk.build_armature("Gargoyle_Rig", BONES, model_col)
    bk.skin(mesh, arm)

    coll = bk.collision_proxy(
        "Gargoyle_Collision",
        [((0, -0.4, 2.3), (3.6, 4.6, 4.6)), ((0, -2.2, 4.5), (1.8, 2.2, 1.8))],
        model_col,
    )

    rest, statue, wings_up, attack = poses()
    acts = {
        "Statue": bk.make_action(arm, "Statue", [(1, statue), (30, statue)]),
        "Awaken": bk.make_action(arm, "Awaken", [(1, statue), (20, rest), (36, wings_up), (50, rest)]),
        "Attack": bk.make_action(arm, "Attack", [(1, rest), (12, wings_up), (24, attack), (40, rest)]),
    }

    stats = {"tris": bk.tri_count(mesh), "parts": None, "bones": len(arm.data.bones)}
    mn, mx = bk.world_bbox(mesh)
    stats["rest_bbox"] = [tuple(round(c, 2) for c in mn), tuple(round(c, 2) for c in mx)]
    stats["collision_tris"] = bk.tri_count(coll)

    # ---- exports (rest pose) -------------------------------------------------
    bk.set_action(arm, None, 1)
    bk.export_fbx(os.path.join(OUT, "gargoyle.fbx"), [arm, mesh], animated=True, bake=False)
    bk.export_anim_fbx(os.path.join(OUT, "gargoyle_anim_statue.fbx"), arm, mesh, acts["Statue"])
    bk.export_anim_fbx(os.path.join(OUT, "gargoyle_anim_awaken.fbx"), arm, mesh, acts["Awaken"])
    bk.export_anim_fbx(os.path.join(OUT, "gargoyle_anim_attack.fbx"), arm, mesh, acts["Attack"])
    static = bk.static_copy(mesh, "Gargoyle_Static", model_col)
    static.vertex_groups.clear()
    bk.export_fbx(os.path.join(OUT, "gargoyle_static.fbx"), [static], animated=False)
    bk.set_action(arm, acts["Statue"], 1)
    statue_static = bk.static_copy(mesh, "Gargoyle_Static_StatuePose", model_col)
    statue_static.vertex_groups.clear()
    mn2, mx2 = bk.world_bbox(statue_static)
    stats["statue_bbox"] = [tuple(round(c, 2) for c in mn2), tuple(round(c, 2) for c in mx2)]
    bk.export_fbx(os.path.join(OUT, "gargoyle_statue_static.fbx"), [statue_static], animated=False)
    bk.export_fbx(os.path.join(OUT, "gargoyle_collision.fbx"), [coll], animated=False)
    static.hide_set(True)
    static.hide_render = True
    statue_static.hide_set(True)
    statue_static.hide_render = True
    bk.set_action(arm, None, 1)

    # ---- previews --------------------------------------------------------------
    if "--no-render" not in ARGS:
        cam = bk.setup_preview(scene, prev_col)
        arm.hide_render = True
        tgt = (0, 0, 3.6)
        g = lambda n: os.path.join(PREV, f"gargoyle-{n}.png")  # noqa: E731
        bk.shoot(scene, cam, tgt, (0, -1, 0.12), 21, g("front"), lens=50)
        bk.shoot(scene, cam, tgt, (1, 0, 0.1), 21, g("side"), lens=50)
        bk.shoot(scene, cam, tgt, (0.75, -1, 0.3), 21, g("three-quarter"), lens=50)
        block = bk.avatar_block(prev_col, (-8.5, -1.0))
        bk.shoot(scene, cam, (-1.5, 0, 3.4), (0.35, -1, 0.18), 27, g("scale-avatar"), lens=50)
        block.hide_render = True
        bk.set_action(arm, acts["Attack"], 24)
        bk.shoot(scene, cam, tgt, (0.75, -1, 0.3), 21, g("attack"), lens=50)
        bk.set_action(arm, acts["Statue"], 1)
        bk.shoot(scene, cam, (0, 0, 3.2), (0.75, -1, 0.3), 21, g("statue"), lens=50)
        bk.set_action(arm, None, 1)
    arm.hide_render = False

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "gargoyle.blend"), compress=True)
    print("GARGOYLE_STATS", stats)


main()

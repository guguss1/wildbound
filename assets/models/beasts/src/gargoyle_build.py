"""Build the Wildbound Gargoyle in headless Blender.

Run:  blender -b --factory-startup --python gargoyle_build.py -- [--no-render]
Outputs into assets/models/beasts/ (blend, FBX, palette, previews).
"""

import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import beastanim as ba  # noqa: E402
import beastatlas as at  # noqa: E402
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
    ("stone_crack", (0.62, 0.58, 0.68), False),       # stone with painted cracks (atlas tile 0)
    ("stone_dark_crack", (0.47, 0.43, 0.55), False),  # dark stone with painted cracks (atlas tile 1)
]
TILE_OF = {6: 0, 7: 1}

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
    R(center=(0, -0.75, 3.35), size=(2.5, 2.1, 2.2), color="stone_crack", bone="Spine", rot=(-18, 0, 0))
    R(center=(0, -1.55, 2.95), size=(1.7, 0.7, 1.5), color="stone_dark", bone="Spine", rot=(-10, 0, 0))
    R(center=(0, -0.2, 4.35), size=(1.9, 1.7, 0.7), color="stone_dark_crack", bone="Spine", rot=(-12, 0, 0))
    R(center=(0, 0.65, 2.55), size=(2.0, 1.8, 1.6), color="stone_crack", bone="Hips", rot=(-8, 0, 0))
    R(center=(0, 1.45, 2.3), size=(1.8, 1.2, 1.2), color="stone_dark", bone="Hips")
    M(R, center=(0.7, -1.45, 3.45), size=(1.0, 0.7, 1.0), color="stone", bone="Spine", rot=(-15, 0, -15))
    R(center=(0, -1.2, 2.3), size=(1.2, 0.8, 0.8), color="stone_dark", bone="Spine", rot=(20, 0, 0))
    # spine ridge plates
    for i, (y, z) in enumerate(((-0.9, 4.65), (-0.1, 4.75), (0.7, 3.65), (1.4, 3.0))):
        P(p0=(0, y, z - 0.35), p1=(0, y + 0.25, z + 0.35), r0=0.28, r1=0.0, color="stone_dark",
          bone="Spine" if i < 2 else "Hips", sides=4)

    # ---- neck + head -------------------------------------------------------
    R(center=(0, -1.45, 4.0), size=(1.35, 1.2, 1.05), color="stone_dark", bone="Head", rot=(-20, 0, 0))
    R(center=(0, -2.1, 4.5), size=(1.75, 1.5, 1.3), color="stone_crack", bone="Head", rot=(8, 0, 0))
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
    M(R, center=(1.55, -0.85, 3.85), size=(1.5, 1.55, 1.35), color="stone_crack", bone="Arm_L_Upper", rot=(-10, 12, -10))
    M(R, center=(1.95, -0.55, 4.35), size=(0.85, 0.9, 0.7), color="stone_dark", bone="Arm_L_Upper", rot=(0, 25, 10))
    M(R, center=(1.5, -0.95, 4.55), size=(1.05, 1.0, 0.2), color="moss", bone="Arm_L_Upper", rot=(-10, 12, -10), jitter=0.05)
    # upper arm: two stacked rocks
    M(R, center=(1.65, -1.25, 2.95), size=(1.1, 1.05, 1.05), color="stone", bone="Arm_L_Upper", rot=(25, 5, -6))
    M(R, center=(1.75, -1.6, 2.2), size=(0.95, 0.95, 0.75), color="stone_dark", bone="Arm_L_Upper", rot=(30, 0, 8))
    # forearm: two rocks + elbow chip
    M(R, center=(1.8, -1.85, 1.55), size=(1.0, 0.95, 0.95), color="stone_crack", bone="Arm_L_Lower", rot=(12, -4, 5))
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
    M(R, center=(1.5, 0.7, 1.95), size=(1.25, 1.7, 1.55), color="stone_crack", bone="Leg_L_Upper", rot=(35, 0, -10))
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
    M(P, p0=root, p1=elbow, r0=0.52, r1=0.42, color="stone", bone="Wing_L_1")
    M(R, center=elbow, size=(0.8, 0.75, 0.75), color="stone_dark", bone="Wing_L_2", rot=(0, -30, 0))
    M(P, p0=elbow, p1=wrist, r0=0.44, r1=0.38, color="stone", bone="Wing_L_2")
    M(R, center=wrist, size=(0.72, 0.66, 0.72), color="stone_dark", bone="Wing_L_3", rot=(0, -25, 0))
    M(P, p0=(4.5, 1.0, 7.2), p1=(4.15, 0.6, 8.15), r0=0.3, r1=0.0, color="stone_dark", bone="Wing_L_2", sides=4)
    M(P, p0=wrist, p1=(5.9, 1.2, 4.0), r0=0.5, r1=0.36, color="stone", bone="Wing_L_3")
    M(P, p0=(5.9, 1.2, 4.0), p1=tip, r0=0.36, r1=0.0, color="stone_dark", bone="Wing_L_3", sides=5)
    M(P, p0=wrist, p1=rib1, r0=0.16, r1=0.08, color="stone_dark", bone="Wing_L_3", sides=4)
    M(P, p0=elbow, p1=rib2, r0=0.16, r1=0.08, color="stone_dark", bone="Wing_L_2", sides=4)
    # membrane plates (thick rocky slabs), set slightly behind the spars
    mem = lambda p: (p[0], p[1] + 0.12, p[2])  # noqa: E731
    AP = b.arched_plate
    back = (0.0, 1.0, 0.15)   # panels bow backwards, like a cupped wing
    mid = (3.9, 1.1, 2.75)
    M(AP, points=[mem(low_root), mem(root), mem(elbow), mem(rib2)], thickness=0.28, bow=0.32, normal=back,
      scallop=(3,), depth=0.1, color="membrane", bone="Wing_L_1")
    M(AP, points=[mem(elbow), mem(wrist), mem(mid)], thickness=0.28, bow=0.26, normal=back,
      color="stone_dark", bone="Wing_L_2")
    M(AP, points=[mem(elbow), mem(mid), mem(rib2)], thickness=0.28, bow=0.26, normal=back,
      scallop=(1,), depth=0.12, color="membrane", bone="Wing_L_2")
    M(AP, points=[mem(wrist), mem(rib1), mem(mid)], thickness=0.28, bow=0.26, normal=back,
      scallop=(1,), depth=0.12, color="membrane", bone="Wing_L_3")
    M(AP, points=[mem(wrist), mem((5.9, 1.2, 4.0)), mem(tip), mem(rib1)], thickness=0.28, bow=0.3, normal=back,
      scallop=(2,), depth=0.1, color="stone_dark", bone="Wing_L_3")
    # thick arched stone cap along the wing's top edge, peaking over the elbow
    M(R, center=(1.6, 0.62, 4.9), size=(1.7, 0.85, 0.75), color="stone_crack", bone="Wing_L_1", rot=(0, -52, 0))
    M(R, center=(2.55, 0.7, 6.3), size=(1.15, 0.9, 0.85), color="stone", bone="Wing_L_2", rot=(0, -38, 0))
    M(R, center=(3.6, 0.8, 6.85), size=(1.7, 0.85, 0.75), color="stone_crack", bone="Wing_L_2", rot=(0, -24, 0))
    M(R, center=(4.45, 0.9, 7.35), size=(0.9, 0.8, 0.7), color="stone_dark", bone="Wing_L_2", rot=(0, -10, 0))
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


HOVER_Z = 1.5  # extra lift of the in-place flight clips; the game places the model at flight height

# action name, file suffix, first frame, last frame, loops
ACTIONS = [
    ("Statue", "statue", 1, 30, True),            # held statue pose
    ("Awaken", "awaken", 1, 49, False),           # 1.60 s cracks + wings unfold (spec AWAKENING 1.6 s)
    ("Takeoff", "takeoff", 1, 40, False),         # 1.30 s crouch, jump, climbing beats (spec TAKEOFF ~1.3 s)
    ("Hover", "hover", 1, 25, True),              # 0.80 s wingbeat loop
    ("CastTornado", "cast", 1, 61, False),        # 2.00 s: 1.65 s charge (frames 1-50) + release
    ("Recoil", "recoil", 1, 16, False),           # 0.50 s knocked back in the air
    ("LandPetrify", "land", 1, 46, False),        # 1.50 s touch down, fold wings, turn to stone
]


def wings(y1=0.0, z1=0.0, y2=0.0, z2=0.0, y3=0.0, z3=0.0):
    """Symmetric wing pose. +y flaps down, -y up; +z folds back, -z sweeps forward (left side)."""
    return {
        "Wing_L_1": ba.ch(0, y1, z1), "Wing_R_1": ba.ch(0, -y1, -z1),
        "Wing_L_2": ba.ch(0, y2, z2), "Wing_R_2": ba.ch(0, -y2, -z2),
        "Wing_L_3": ba.ch(0, y3, z3), "Wing_R_3": ba.ch(0, -y3, -z3),
    }


def sym(bone_l, rx=0.0, ry=0.0, rz=0.0):
    bone_r = bone_l.replace("_L_", "_R_")
    return {bone_l: ba.ch(rx, ry, rz), bone_r: ba.ch(rx, -ry, -rz)}


def poses():
    statue = ba.padd(
        {"Hips": ba.ch(-15, 0, 0, (0, 0.2, 0.12)), "Spine": ba.ch(-6), "Head": ba.ch(18), "Tail": ba.ch(25)},
        sym("Arm_L_Upper", 40), sym("Leg_L_Upper", 18), sym("Leg_L_Lower", -10),
        wings(-12, 55, 0, 60, 15, 35))
    awake = ba.padd({"Head": ba.ch(-6), "Spine": ba.ch(4), "Jaw": ba.ch(4)}, wings(-6, 4, -4, 0, -6, 0))
    wings_up = ba.padd({"Head": ba.ch(-10), "Jaw": ba.ch(15)}, wings(-12, 0, -10, 0, -25, 0))
    crouch = ba.padd({"Hips": ba.ch(12), "Spine": ba.ch(8), "Head": ba.ch(-14), "Tail": ba.ch(-10)},
                     sym("Leg_L_Upper", -22), sym("Leg_L_Lower", 30), sym("Arm_L_Upper", 18), sym("Arm_L_Lower", -26),
                     wings(-38, -6, -12, 0, -28, 0))
    # flying body: leaning forward, legs trailing, arms hanging with claws forward
    fly = ba.padd({"Hips": ba.ch(14), "Spine": ba.ch(-4), "Head": ba.ch(-12), "Tail": ba.ch(-14)},
                  sym("Leg_L_Upper", 26), sym("Leg_L_Lower", 28), sym("Arm_L_Upper", 16), sym("Arm_L_Lower", -30))
    charge = ba.padd({"Spine": ba.ch(-10), "Head": ba.ch(-16), "Jaw": ba.ch(18),
                      "Arm_L_Upper": ba.ch(-110, -10, 0), "Arm_L_Lower": ba.ch(-30)},
                     wings(-30, -24, -8, -18, -20, -14))
    release = ba.padd({"Hips": ba.ch(8), "Spine": ba.ch(16), "Head": ba.ch(-14), "Jaw": ba.ch(28),
                       "Arm_L_Upper": ba.ch(-66, -10, 0), "Arm_L_Lower": ba.ch(-24)},
                      wings(12, -30, 4, -22, 8, -18))
    return statue, awake, wings_up, crouch, fly, charge, release


def hover_pose(fly, phase, amp=1.0):
    """Wingbeat at `phase` cycles: 0 = top of the upstroke, 0.5 = bottom of the downstroke."""
    def beat(lag):
        return -math.cos(2 * math.pi * (phase - lag))
    w = wings(34 * amp * beat(0.0) + 2, -10 * amp * beat(0.0), 12 * amp * beat(0.08), 0, 16 * amp * beat(0.16), 0)
    lift = math.sin(2 * math.pi * (phase - 0.12))
    body = {"Root": ba.ch(0, 0, 0, (0, 0, 0.18 * amp * lift)),
            "Hips": ba.ch(-2 * amp * lift), "Head": ba.ch(2 * amp * lift),
            "Tail": ba.ch(4 * amp * lift, 0, 6 * math.sin(2 * math.pi * phase)),
            "Leg_L_Lower": ba.ch(5 * amp * math.sin(2 * math.pi * (phase - 0.3))),
            "Leg_R_Lower": ba.ch(5 * amp * math.sin(2 * math.pi * (phase - 0.3)))}
    return ba.padd(fly, w, body)


def build_actions(arm, mesh):
    rig = ba.Rig(arm)
    contact = ba.Ground(mesh, ["Leg_L_Lower", "Leg_R_Lower", "Arm_L_Lower", "Arm_R_Lower"])
    statue, awake, wings_up, crouch, fly, charge, release = poses()

    def mix(w_ground, z_air=0.0):
        """Post step: Root height = ground contact (weight w_ground) blended with an airborne height."""
        def post(f, p):
            w = w_ground(f) if callable(w_ground) else w_ground
            za = z_air(f) if callable(z_air) else z_air
            root = p.setdefault("Root", [0.0] * 6)
            extra = root[5]
            root[5] = 0.0
            rig.apply(p)
            dz = 0.0 - contact.min_z()
            # never let the feet or hands sink below the ground, even while airborne
            root[5] = max(w * dz + (1 - w) * (za + extra), dz)
            rig.apply(p)
        return post

    acts = {}
    acts["Statue"] = rig.bake("Statue", 1, 30, lambda f: statue, mix(1.0), loop=True)

    # ---- Awaken: three crack tremors in the stone, head lifts, wings unfold and rise, settle awake
    def awaken(f):
        p = ba.spline([(1, statue, "hold"), (16, statue, "hold"), (30, ba.plerp(statue, wings_up, 0.7)),
                       (38, wings_up), (49, awake, "hold")], f)
        jolt = sum(math.exp(-((f - c) / 1.3) ** 2) * a for c, a in ((4, 0.6), (9, 0.85), (13, 1.0)))
        shake = ba.wave(f, 0, 2.5)
        p = ba.padd(p, {"Hips": ba.ch(0, 1.8 * jolt * shake, 1.2 * jolt * shake),
                        "Spine": ba.ch(1.5 * jolt * ba.wave(f, 0, 3)), "Head": ba.ch(-3 * jolt)})
        p = ba.padd(p, {"Jaw": ba.ch(18 * math.exp(-((f - 36) / 4.0) ** 2))})
        return p
    acts["Awaken"] = rig.bake("Awaken", 1, 49, awaken, mix(1.0))

    # ---- Takeoff: crouch with wings raised, push off on a big downstroke, climb on fast beats
    def takeoff(f):
        if f <= 13:
            return ba.spline([(1, awake), (8, crouch, "hold"), (13, ba.padd(crouch, wings(52, 0, 18, 0, 22, 0)))], f)
        w = ba.smooth((f - 13) / 9.0)
        beat = hover_pose(fly, 0.5 + (f - 13) / 13.5, amp=1.2)
        if f >= 36:
            beat = ba.plerp(beat, hover_pose(fly, 0.0), ba.smooth((f - 36) / 4.0))
        return ba.plerp(ba.padd(crouch, wings(52, 0, 18, 0, 22, 0)), beat, w)
    acts["Takeoff"] = rig.bake("Takeoff", 1, 40, takeoff, mix(
        lambda f: 1.0 if f <= 13 else max(0.0, 1 - (f - 13) / 4.0),
        lambda f: 0.0 if f <= 13 else HOVER_Z * ba.ease_out((f - 13) / 27.0)))

    # ---- Hover: in-place wingbeat loop
    acts["Hover"] = rig.bake("Hover", 1, 25, lambda f: hover_pose(fly, (f - 1) / 24.0), mix(0.0, HOVER_Z), loop=True)

    # ---- CastTornado: 1.65 s charge (wings sweep forward, arm raised), release thrust at frame 50
    def cast(f):
        amp = 1.0 - 0.7 * ba.smooth((f - 1) / 12.0)
        base = hover_pose(fly, (f - 1) / 24.0, amp=amp)
        p = ba.spline([(1, {}), (14, charge), (44, charge), (50, ba.padd(charge, wings(-8, -6, 0, 0, -6, 0))),
                       (54, release, "hold"), (61, release, "hold")], f)
        trem = 0.0
        if 14 <= f <= 50:
            trem = (f - 14) / 36.0
        p = ba.padd(base, p, wings(2.5 * trem * ba.wave(f, 0, 3), 0, 0, 0, 3 * trem * ba.wave(f, 0, 2.5), 0))
        return p
    acts["CastTornado"] = rig.bake("CastTornado", 1, 61, cast, mix(0.0, HOVER_Z))

    # ---- Recoil: knocked back, wings flung back, then back into the hover beat
    def recoil(f):
        cast_end = cast(61)
        hit = ba.padd(fly, {"Root": ba.ch(0, 0, 0, (0, 0.8, 0.25)), "Hips": ba.ch(-22), "Spine": ba.ch(-8),
                            "Head": ba.ch(16), "Jaw": ba.ch(12)}, sym("Arm_L_Upper", -30), wings(-20, 28, -8, 10, -12, 8))
        return ba.spline([(1, cast_end), (5, hit), (16, hover_pose(fly, 0.0), "hold")], f)
    acts["Recoil"] = rig.bake("Recoil", 1, 16, recoil, mix(0.0, HOVER_Z))

    # ---- LandPetrify: descend, touch down, absorb, fold the wings and settle into stone
    touch = ba.padd(crouch, wings(10, 0, 4, 0, 6, 0))
    def land(f):
        if f <= 14:
            p = ba.plerp(hover_pose(fly, (f - 1) / 13.0 * 0.5), ba.padd(fly, wings(30, -6, 10, 0, 12, 0),
                                                                          sym("Leg_L_Upper", -36), sym("Leg_L_Lower", -26)),
                         ba.smooth((f - 1) / 13.0))
            return p
        p = ba.spline([(14, touch), (20, ba.padd(touch, sym("Leg_L_Upper", -8))), (38, statue), (46, statue, "hold")], f)
        settle = max(0.0, 1 - abs(f - 41) / 5.0)
        return ba.padd(p, {"Hips": ba.ch(0, 0.8 * settle * ba.wave(f, 0, 2.5), 0)})
    acts["LandPetrify"] = rig.bake("LandPetrify", 1, 46, land, mix(
        lambda f: 0.0 if f < 8 else min(1.0, (f - 8) / 6.0), lambda f: HOVER_Z * (1 - ba.smooth((f - 1) / 13.0))))
    rig.apply({})
    return acts, contact


def main():
    scene = bk.reset_scene()
    scene.render.fps = ba.FPS
    model_col = bk.get_collection("Gargoyle")
    prev_col = bk.get_collection("Preview_Only")

    mesh = build_mesh(model_col)
    mat, glow = bk.make_palette_materials("Gargoyle", PALETTE, os.path.join(OUT, "gargoyle_palette.png"))
    # pixel values are the sRGB palette values, as in beastkit.make_palette_materials
    srgb = [c for (_n, c, _e) in PALETTE]
    stone, dark = srgb[0], srgb[1]
    tiles = [
        at.paint_tile(stone, (0.36, 0.33, 0.42), rim=(0.52, 0.48, 0.58), seed=7, cracks=3, width=1.8, branch=0.9),
        at.paint_tile(dark, (0.29, 0.26, 0.35), seed=19, cracks=2, width=1.7, branch=0.9),
    ]
    atlas = at.build_atlas("Gargoyle_Atlas", srgb, tiles, os.path.join(OUT, "gargoyle_palette.png"))
    at.set_material_image(mat, atlas)
    mesh.data.materials.append(mat)
    mesh.data.materials.append(glow)
    at.apply_uvs(mesh, len(PALETTE), TILE_OF, world_per_tile=1.6, seed=3)
    arm = bk.build_armature("Gargoyle_Rig", BONES, model_col)
    bk.skin(mesh, arm)

    coll = bk.collision_proxy(
        "Gargoyle_Collision",
        [((0, -0.4, 2.3), (3.6, 4.6, 4.6)), ((0, -2.2, 4.5), (1.8, 2.2, 1.8))],
        model_col,
    )

    acts, contact = build_actions(arm, mesh)

    stats = {"tris": bk.tri_count(mesh), "bones": len(arm.data.bones)}
    mn, mx = bk.world_bbox(mesh)
    stats["rest_bbox"] = [tuple(round(c, 2) for c in mn), tuple(round(c, 2) for c in mx)]
    stats["collision_tris"] = bk.tri_count(coll)
    stats["actions"] = {a: (f0, f1, round((f1 - f0) / ba.FPS, 3), lp) for a, _s, f0, f1, lp in ACTIONS}
    stats["ground"] = {a: ba.ground_report(arm, acts[a], contact) for a, _s, _f0, _f1, _lp in ACTIONS}

    # ---- exports (rest pose) -------------------------------------------------
    ba.assign(arm, None, 1)
    bk.apply_pose(arm, {})
    bk.export_fbx(os.path.join(OUT, "gargoyle.fbx"), [arm, mesh], animated=True, bake=False)
    for name, short, _f0, _f1, _lp in ACTIONS:
        bk.export_anim_fbx(os.path.join(OUT, f"gargoyle_anim_{short}.fbx"), arm, mesh, acts[name])
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
        if "--strips-only" not in ARGS:
            bk.shoot(scene, cam, tgt, (0, -1, 0.12), 21, g("front"), lens=50)
            bk.shoot(scene, cam, tgt, (1, 0, 0.1), 21, g("side"), lens=50)
            bk.shoot(scene, cam, tgt, (0.75, -1, 0.3), 21, g("three-quarter"), lens=50)
            block = bk.avatar_block(prev_col, (-8.5, -1.0))
            bk.shoot(scene, cam, (-1.5, 0, 3.4), (0.35, -1, 0.18), 27, g("scale-avatar"), lens=50)
            block.hide_render = True
            bk.set_action(arm, acts["CastTornado"], 54)
            bk.shoot(scene, cam, (0, 0, 4.4), (0.75, -1, 0.3), 23, g("attack"), lens=50)
            bk.set_action(arm, acts["Statue"], 1)
            bk.shoot(scene, cam, (0, 0, 3.2), (0.75, -1, 0.3), 21, g("statue"), lens=50)
            bk.set_action(arm, None, 1)
        d = Vector((0.75, -1, 0.3)).normalized()
        cam.location = Vector((0, 0, 4.2)) + d * 27
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        cam.data.type = "PERSP"
        cam.data.lens = 50
        for name, short, _f0, _f1, _lp in ACTIONS:
            if short == "statue":
                continue
            ba.contact_strip(scene, arm, acts[name], os.path.join(PREV, f"anim-gargoyle-{short}.png"))
        bk.set_action(arm, None, 1)
    arm.hide_render = False

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "gargoyle.blend"), compress=True)
    print("GARGOYLE_STATS", stats)


main()

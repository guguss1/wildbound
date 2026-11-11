"""Build the Wildbound Mire in headless Blender.

Run:  blender -b --factory-startup --python mire_build.py -- [--no-render]
Outputs into assets/models/beasts/ (blend, FBX, palette, previews).
"""

import math
import os
import random
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import beastanim as ba  # noqa: E402
import beastkit as bk  # noqa: E402

OUT = os.path.normpath(os.path.join(HERE, ".."))
PREV = os.path.join(OUT, "previews")
ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []

PALETTE = [
    ("stone", (0.29, 0.40, 0.39), False),
    ("stone_dark", (0.19, 0.27, 0.28), False),
    ("moss", (0.55, 0.62, 0.22), False),
    ("moss_dark", (0.35, 0.45, 0.15), False),
    ("fungus", (0.87, 0.83, 0.64), False),
    ("eye", (1.00, 0.78, 0.30), True),
]

# Front pair (F) and middle pair (M) of long root-like forelimbs, 3 bones each.
FL = [(1.7, -1.7, 1.6), (3.5, -2.6, 3.5), (4.2, -4.0, 0.55), (4.4, -5.0, 0.12)]
ML = [(2.1, 0.3, 1.4), (4.1, 0.5, 2.9), (5.1, 0.9, 0.45), (5.8, 1.4, 0.1)]


def _mx(p):
    return (-p[0], p[1], p[2])


BONES = [
    ("Root", (0, 0, 0), (0, -1.0, 0), None, False),
    ("Shell", (0, 1.4, 1.5), (0, -1.3, 1.7), "Root", False),
    ("Head", (0, -1.6, 1.4), (0, -3.4, 1.2), "Shell", False),
]
for tag, pts in (("ArmF", FL), ("ArmM", ML)):
    for side, f in (("L", lambda p: p), ("R", _mx)):
        for i in range(3):
            parent = "Shell" if i == 0 else f"{tag}_{side}_{i}"
            BONES.append((f"{tag}_{side}_{i + 1}", f(pts[i]), f(pts[i + 1]), parent, i > 0))


def limb(b, tag, pts, scale=1.0):
    """One long root-like limb: segments, knuckles, splayed root fingers, moss."""
    R, P = b.rock, b.prism
    M = b.mirror
    s0, el, wr, tip = pts
    M(R, center=s0, size=(1.0 * scale, 1.0 * scale, 0.9 * scale), color="stone_dark", bone=f"{tag}_L_1")
    M(P, p0=s0, p1=el, r0=0.62 * scale, r1=0.5 * scale, color="stone", bone=f"{tag}_L_1", sides=5)
    M(R, center=el, size=(1.05 * scale, 1.0 * scale, 1.0 * scale), color="stone_dark", bone=f"{tag}_L_2", rot=(0, 20, 0))
    M(P, p0=el, p1=wr, r0=0.5 * scale, r1=0.4 * scale, color="stone", bone=f"{tag}_L_2", sides=5)
    # moss saddle on the elbow + hanging strand
    M(R, center=(el[0] - 0.1, el[1], el[2] + 0.38 * scale), size=(0.9 * scale, 0.75 * scale, 0.16), color="moss", bone=f"{tag}_L_2", rot=(0, 20, 0), jitter=0.04)
    M(P, p0=(el[0] + 0.2, el[1] - 0.2, el[2] + 0.2), p1=(el[0] + 0.3, el[1] - 0.25, el[2] - 0.9), r0=0.12, r1=0.0, color="moss_dark", bone=f"{tag}_L_2", sides=4)
    # hand: knuckle + 4 splayed root fingers (2 segments each)
    M(R, center=(wr[0], wr[1] - 0.1, wr[2] - 0.1), size=(1.0 * scale, 1.0 * scale, 0.6 * scale), color="stone", bone=f"{tag}_L_3")
    M(R, center=(wr[0], wr[1] - 0.1, wr[2] + 0.2), size=(0.6 * scale, 0.55 * scale, 0.12), color="moss", bone=f"{tag}_L_3", jitter=0.03)
    hx, hy = wr[0], wr[1]
    d = (tip[0] - wr[0], tip[1] - wr[1])
    n = (d[0] ** 2 + d[1] ** 2) ** 0.5
    fwd = (d[0] / n, d[1] / n)
    side = (-fwd[1], fwd[0])
    for k, spread in enumerate((-0.75, -0.25, 0.25, 0.75)):
        dirx = fwd[0] + side[0] * spread
        diry = fwd[1] + side[1] * spread
        ln = (dirx ** 2 + diry ** 2) ** 0.5
        dirx, diry = dirx / ln, diry / ln
        L1 = (0.75 + 0.15 * (k % 2)) * scale
        k1 = (hx + dirx * L1, hy + diry * L1, 0.34 * scale)
        k2 = (hx + dirx * (L1 + 0.62 * scale), hy + diry * (L1 + 0.62 * scale), 0.2 * scale)
        yaw = math.degrees(math.atan2(diry, dirx)) - 90.0
        # blunt block fingers: a thick first segment, a squared knuckle and a chunky blunt tip block
        M(P, p0=(hx, hy, wr[2] - 0.05), p1=k1, r0=0.27 * scale, r1=0.24 * scale, color="stone", bone=f"{tag}_L_3", sides=4)
        M(R, center=k1, size=(0.44 * scale, 0.42 * scale, 0.4 * scale), color="stone_dark", bone=f"{tag}_L_3",
          rot=(0, 0, yaw), bevel=0.08, jitter=0.03)
        M(P, p0=k1, p1=k2, r0=0.22 * scale, r1=0.2 * scale, color="stone", bone=f"{tag}_L_3", sides=4)
        M(R, center=(k2[0] + dirx * 0.1 * scale, k2[1] + diry * 0.1 * scale, 0.17 * scale),
          size=(0.42 * scale, 0.5 * scale, 0.34 * scale), color="stone_dark", bone=f"{tag}_L_3",
          rot=(-8, 0, yaw), bevel=0.07, jitter=0.02, taper=(0.85, 0.8))


def build_mesh(col):
    b = bk.Builder(PALETTE, seed=53)
    R, P, M = b.rock, b.prism, b.mirror
    rng = random.Random(11)

    # ---- shell: a low dome of angular green rocks ------------------------------
    R(center=(0, 0.3, 1.6), size=(4.2, 4.6, 2.0), color="stone_dark", bone="Shell")
    R(center=(0, 0.1, 2.9), size=(3.0, 3.0, 1.2), color="stone", bone="Shell", rot=(4, 0, 8))
    M(R, center=(1.3, -0.9, 2.45), size=(1.8, 1.7, 1.1), color="stone", bone="Shell", rot=(8, -14, -10))
    M(R, center=(1.5, 1.2, 2.35), size=(1.7, 1.8, 1.1), color="stone", bone="Shell", rot=(-6, -16, 12))
    M(R, center=(2.2, 0.2, 1.65), size=(1.2, 2.6, 1.4), color="stone_dark", bone="Shell", rot=(0, -20, 4))
    R(center=(0, 2.0, 2.15), size=(2.2, 1.4, 1.1), color="stone", bone="Shell", rot=(-14, 0, 0))
    R(center=(0, 2.7, 1.3), size=(1.8, 1.3, 1.0), color="stone_dark", bone="Shell", rot=(-20, 0, 0))
    # moss blankets on top of the shell
    R(center=(0.5, -0.5, 3.45), size=(1.6, 1.5, 0.3), color="moss", bone="Shell", rot=(10, 8, 20), jitter=0.07)
    R(center=(-0.5, 0.3, 3.5), size=(1.5, 1.6, 0.3), color="moss", bone="Shell", rot=(-6, -10, -15), jitter=0.07)
    R(center=(0.3, 0.9, 3.3), size=(1.3, 1.1, 0.28), color="moss_dark", bone="Shell", rot=(-14, 8, 30), jitter=0.06)
    R(center=(-1.35, -0.95, 3.02), size=(1.4, 1.3, 0.2), color="moss_dark", bone="Shell", rot=(8, 14, 10), jitter=0.06)
    R(center=(1.5, 1.2, 2.92), size=(1.3, 1.4, 0.2), color="moss", bone="Shell", rot=(-6, -16, 12), jitter=0.06)
    R(center=(-0.3, 1.95, 2.72), size=(1.5, 1.0, 0.2), color="moss_dark", bone="Shell", rot=(-14, 0, 0), jitter=0.05)

    # ---- hanging algae clumps around the shell rim --------------------------------
    for i in range(26):
        a = math.radians(-90 + i * (360 / 26) + rng.uniform(-5, 5))
        rx, ry = 2.75, 2.95
        x, y = math.cos(a) * rx, math.sin(a) * ry + 0.3
        front = max(0.0, -math.sin(a))  # longer clumps toward the front
        top_z = 2.55 + rng.uniform(-0.2, 0.25)
        length = 1.2 + 0.7 * front + rng.uniform(-0.2, 0.3)
        col_name = "moss" if i % 3 else "moss_dark"
        P(p0=(x * 0.92, y * 0.92, top_z), p1=(x * 1.08, y * 1.08, top_z - length), r0=0.36, r1=0.05,
          color=col_name, bone="Shell", sides=4, jitter=0.08)

    # ---- head: wedge mud mass emerging from the front ----------------------------
    R(center=(0, -2.15, 1.25), size=(2.6, 1.9, 1.4), color="stone_dark", bone="Head", rot=(-8, 0, 0), taper=(0.9, 0.8))
    R(center=(0, -3.0, 0.85), size=(1.9, 1.1, 0.85), color="stone", bone="Head", rot=(10, 0, 0), taper=(0.85, 0.9))
    R(center=(0, -3.35, 0.55), size=(1.4, 0.6, 0.4), color="stone_dark", bone="Head")
    M(R, center=(0.52, -3.12, 1.3), size=(0.46, 0.16, 0.3), color="eye", bone="Head", rot=(0, 0, -10), bevel=0.2, jitter=0.0)
    # heavy moss brow over the eyes: one thick cap and three broad drapes with an uneven lower edge
    R(center=(0, -2.6, 2.0), size=(2.9, 1.9, 0.46), color="moss", bone="Head", rot=(-14, 0, 0), jitter=0.05)
    R(center=(0, -3.05, 1.86), size=(2.5, 0.5, 0.34), color="moss_dark", bone="Head", rot=(-30, 0, 0), jitter=0.04)
    for (x0, x1, b0, b1, col_name) in ((-1.55, -0.55, 1.42, 1.56, "moss_dark"), (-0.62, 0.62, 1.58, 1.5, "moss"),
                                       (0.55, 1.55, 1.55, 1.4, "moss_dark")):
        b.plate(points=[(x0, -3.22, 1.98), (x1, -3.22, 1.98), (x1 * 1.04, -3.42, b1), ((x0 + x1) * 0.5, -3.46, min(b0, b1) - 0.05),
                        (x0 * 1.04, -3.42, b0)], thickness=0.16, color=col_name, bone="Head", normal=(0, -1, 0.35), jitter=0.02)
    # two moss strands at the outer corners, clear of the eyes
    M(P, p0=(1.5, -3.15, 1.75), p1=(1.62, -3.3, 0.95), r0=0.2, r1=0.06, color="moss", bone="Head", sides=4, jitter=0.04)
    # side moss sheets draping off the shell
    M(b.plate, points=[(1.9, -1.4, 3.0), (2.9, -1.0, 1.5), (3.0, 0.6, 1.3), (2.3, 0.4, 2.9)], thickness=0.18, color="moss_dark", bone="Shell", jitter=0.06)
    M(b.plate, points=[(1.5, 1.6, 2.9), (2.6, 1.6, 1.5), (2.2, 2.9, 1.2), (1.2, 2.6, 2.6)], thickness=0.18, color="moss", bone="Shell", jitter=0.06)
    # two short tusks / mandible shards
    M(P, p0=(0.55, -3.45, 0.6), p1=(0.7, -3.85, 0.2), r0=0.12, r1=0.0, color="fungus", bone="Head", sides=4)

    # ---- fungus caps and a dead root twig on the back --------------------------
    for x, y, z, r in ((0.4, -0.3, 3.6, 0.3), (-1.1, 0.4, 3.15, 0.24), (1.4, 0.9, 3.05, 0.2), (-0.6, 1.5, 2.85, 0.18), (1.9, -0.8, 2.85, 0.16)):
        P(p0=(x, y, z - 0.1), p1=(x, y, z + 0.35), r0=r * 0.35, r1=r * 0.3, color="fungus", bone="Shell", sides=5)
        P(p0=(x, y, z + 0.32), p1=(x, y, z + 0.5), r0=r, r1=r * 0.35, color="fungus", bone="Shell", sides=6)
    P(p0=(-0.3, 0.8, 3.1), p1=(-0.7, 0.9, 3.9), r0=0.12, r1=0.06, color="stone_dark", bone="Shell", sides=4)
    P(p0=(-0.6, 0.88, 3.7), p1=(-1.1, 0.7, 4.0), r0=0.07, r1=0.0, color="stone_dark", bone="Shell", sides=4)
    P(p0=(-0.65, 0.9, 3.8), p1=(-0.4, 1.2, 4.15), r0=0.06, r1=0.0, color="stone_dark", bone="Shell", sides=4)

    # ---- limbs ------------------------------------------------------------------
    limb(b, "ArmF", FL, 1.15)
    limb(b, "ArmM", ML, 0.9)
    # small hind stubs + a dragging tail (on the shell bone)
    M(P, p0=(1.4, 2.3, 1.0), p1=(2.4, 3.2, 0.1), r0=0.32, r1=0.12, color="stone_dark", bone="Shell", sides=5)
    P(p0=(0, 2.9, 1.1), p1=(0, 4.0, 0.5), r0=0.5, r1=0.3, color="stone", bone="Shell", sides=5)
    P(p0=(0, 4.0, 0.5), p1=(0, 5.0, 0.15), r0=0.3, r1=0.0, color="stone_dark", bone="Shell", sides=5)

    return b.to_object("Mire_Mesh", col)


SUNK_Z = -1.7  # Root offset that puts everything but the mossy back, brow and eyes under the water line

# action name, file suffix, first frame, last frame, loops
ACTIONS = [
    ("Glide", "glide", 1, 49, True),         # 1.60 s submerged glide loop (STALK_UNDERWATER)
    ("Emerge", "emerge", 1, 13, False),      # 0.40 s burst out of the water
    ("Swipe", "swipe", 1, 15, False),        # 0.47 s short claw swipe, active frames 5-12 (emerge + swipe = 0.87 s)
    ("Recover", "recover", 1, 40, False),    # 1.30 s exposed and sluggish on the bank (SURFACE_RECOVER 1.1-1.6 s)
    ("Sink", "sink", 1, 37, False),          # 1.20 s dive back under (DIVE/REPOSITION 1.2 s)
]


def sym(bone_l, rx=0.0, ry=0.0, rz=0.0):
    return {bone_l: ba.ch(rx, ry, rz), bone_l.replace("_L_", "_R_"): ba.ch(rx, -ry, -rz)}


def poses():
    submerged = ba.padd({"Root": ba.ch(0, 0, 0, (0, 0, SUNK_Z)), "Shell": ba.ch(-4), "Head": ba.ch(-14)},
                        sym("ArmF_L_1", 0, 75, 20), sym("ArmM_L_1", 0, 75, 20))
    reared = ba.padd({"Root": ba.ch(0, 0, 0, (0, 0, 0.35)), "Shell": ba.ch(-14), "Head": ba.ch(-12)},
                     sym("ArmF_L_1", 0, -25, 0), sym("ArmF_L_2", 20, 0, 0))
    swipe_up = ba.padd(reared, {"Shell": ba.ch(6, 0, 8), "Head": ba.ch(2),
                                "ArmF_R_1": ba.ch(0, 75, 30), "ArmF_R_2": ba.ch(-40, -15, 0), "ArmF_R_3": ba.ch(25)})
    swipe_hit = {"Root": ba.ch(0, 0, 0, (0, -0.4, 0)), "Shell": ba.ch(0, 0, -10), "Head": ba.ch(-2),
                 "ArmF_R_1": ba.ch(0, 5, 35), "ArmF_R_2": ba.ch(0, -10, 0)}
    follow = ba.padd(swipe_hit, {"Shell": ba.ch(2, 0, -6), "ArmF_R_1": ba.ch(0, 4, 18), "ArmF_R_3": ba.ch(-10)})
    slump = ba.padd({"Shell": ba.ch(8, 0, 3), "Head": ba.ch(16, 0, -6)},
                    sym("ArmF_L_1", 0, -12, 4), sym("ArmM_L_1", 0, -9, 0), sym("ArmF_L_2", 8))
    return submerged, reared, swipe_up, swipe_hit, follow, slump


def build_actions(arm, mesh):
    rig = ba.Rig(arm)
    hands = ba.Ground(mesh, ["ArmF_L_3", "ArmF_R_3", "ArmM_L_3", "ArmM_R_3"])
    submerged, reared, swipe_up, swipe_hit, follow, slump = poses()

    def grounded(weight):
        def post(f, p):
            w = weight(f) if callable(weight) else weight
            if w <= 0:
                return
            root = p.setdefault("Root", [0.0] * 6)
            z0 = root[5]
            root[5] = 0.0
            rig.apply(p)
            dz = -hands.min_z()
            root[5] = w * dz + (1 - w) * z0
            rig.apply(p)
        return post

    acts = {}

    # ---- Glide: sunk, slow surge bob, shell sway, eyes bobbing at the surface, limbs paddling below
    def glide(f):
        p = ba.padd(submerged, {"Root": ba.ch(0, 0, 0, (0, 0, 0.1 * ba.wave(f, 1, 24))),
                                "Shell": ba.ch(2 * ba.wave(f, 1, 24, 0.15), 0, 3 * ba.wave(f, 1, 48)),
                                "Head": ba.ch(3 * ba.wave(f, 1, 24, 0.35), 0, -2.5 * ba.wave(f, 1, 48))})
        for tag, ph in (("ArmF", 0.0), ("ArmM", 0.5)):
            p = ba.padd(p, sym(f"{tag}_L_1", 0, 4 * ba.wave(f, 1, 48, ph + 0.25), 14 * ba.wave(f, 1, 48, ph)),
                        sym(f"{tag}_L_2", 10 * ba.wave(f, 1, 48, ph + 0.15)))
        return p
    acts["Glide"] = rig.bake("Glide", 1, 49, glide, loop=True)

    # ---- Emerge: explode upward out of the water, head first, then the front limbs
    burst = ba.padd(ba.plerp(submerged, reared, 0.55), {"Head": ba.ch(-14)}, sym("ArmF_L_1", 0, -20, 0))
    acts["Emerge"] = rig.bake("Emerge", 1, 13, lambda f: ba.spline(
        [(1, glide(1), "hold"), (6, burst), (13, reared)], f), grounded(lambda f: ba.smooth((f - 9) / 4.0)))

    # ---- Swipe: right front limb cocks back (frames 1-5), sweeps across (5-12), follows through
    acts["Swipe"] = rig.bake("Swipe", 1, 15, lambda f: ba.spline(
        [(1, reared), (5, swipe_up, "hold"), (9, swipe_hit), (15, follow, "hold")], f),
        grounded(1.0))

    # ---- Recover: slumps on the bank, heaves two heavy breaths, shakes the mud off and stands up
    def recover(f):
        p = ba.spline([(1, follow, "hold"), (10, slump), (30, slump), (40, {}, "hold")], f)
        breath = math.sin(math.pi * min(1.0, max(0.0, (f - 8) / 22.0)) * 2) * (1 if 8 <= f <= 30 else 0)
        shake = math.exp(-((f - 33) / 2.5) ** 2)
        return ba.padd(p, {"Shell": ba.ch(-3 * breath, 4 * shake * ba.wave(f, 0, 3), 0),
                           "Head": ba.ch(-4 * breath, 0, 10 * shake * ba.wave(f, 0, 3, 0.25))})
    acts["Recover"] = rig.bake("Recover", 1, 40, recover, grounded(1.0))

    # ---- Sink: rocks back, folds the limbs and slides under, ending in the glide pose
    def sink(f):
        lean = ba.padd({"Root": ba.ch(0, 0, 0, (0, 0.3, -0.25)), "Shell": ba.ch(-8), "Head": ba.ch(-8)},
                       sym("ArmF_L_1", 0, 30, 8), sym("ArmM_L_1", 0, 30, 8))
        return ba.spline([(1, {}, "hold"), (12, lean), (37, glide(1), "hold")], f)
    acts["Sink"] = rig.bake("Sink", 1, 37, sink, grounded(lambda f: max(0.0, 1 - (f - 1) / 8.0)))
    rig.apply({})
    return acts, hands


def main():
    scene = bk.reset_scene()
    scene.render.fps = ba.FPS
    model_col = bk.get_collection("Mire")
    prev_col = bk.get_collection("Preview_Only")

    mesh = build_mesh(model_col)
    mat, glow = bk.make_palette_materials("Mire", PALETTE, os.path.join(OUT, "mire_palette.png"))
    mesh.data.materials.append(mat)
    mesh.data.materials.append(glow)
    arm = bk.build_armature("Mire_Rig", BONES, model_col)
    bk.skin(mesh, arm)

    coll = bk.collision_proxy(
        "Mire_Collision",
        [((0, 0.0, 1.5), (5.0, 6.4, 3.0)), ((0, -3.0, 1.0), (2.4, 1.6, 1.8))],
        model_col,
    )

    acts, hands = build_actions(arm, mesh)

    stats = {"tris": bk.tri_count(mesh), "bones": len(arm.data.bones), "collision_tris": bk.tri_count(coll)}
    mn, mx = bk.world_bbox(mesh)
    stats["rest_bbox"] = [tuple(round(c, 2) for c in mn), tuple(round(c, 2) for c in mx)]
    stats["actions"] = {a: (f0, f1, round((f1 - f0) / ba.FPS, 3), lp) for a, _s, f0, f1, lp in ACTIONS}
    stats["ground"] = {a: ba.ground_report(arm, acts[a], hands) for a, _s, _f0, _f1, _lp in ACTIONS}

    bk.set_action(arm, None, 1)
    bk.export_fbx(os.path.join(OUT, "mire.fbx"), [arm, mesh], animated=True, bake=False)
    for name, short, _f0, _f1, _lp in ACTIONS:
        bk.export_anim_fbx(os.path.join(OUT, f"mire_anim_{short}.fbx"), arm, mesh, acts[name])
    static = bk.static_copy(mesh, "Mire_Static", model_col)
    static.vertex_groups.clear()
    bk.export_fbx(os.path.join(OUT, "mire_static.fbx"), [static], animated=False)
    bk.set_action(arm, acts["Glide"], 1)
    sub_static = bk.static_copy(mesh, "Mire_Static_SubmergedPose", model_col)
    sub_static.vertex_groups.clear()
    mn2, mx2 = bk.world_bbox(sub_static)
    stats["submerged_bbox"] = [tuple(round(c, 2) for c in mn2), tuple(round(c, 2) for c in mx2)]
    bk.export_fbx(os.path.join(OUT, "mire_submerged_static.fbx"), [sub_static], animated=False)
    bk.export_fbx(os.path.join(OUT, "mire_collision.fbx"), [coll], animated=False)
    for o in (static, sub_static):
        o.hide_set(True)
        o.hide_render = True
    bk.set_action(arm, None, 1)

    if "--no-render" not in ARGS:
        cam = bk.setup_preview(scene, prev_col, ground_rgb=(0.17, 0.17, 0.19))
        arm.hide_render = True
        tgt = (0, -0.8, 1.5)
        g = lambda n: os.path.join(PREV, f"mire-{n}.png")  # noqa: E731
        if "--strips-only" not in ARGS:
            bk.shoot(scene, cam, tgt, (0, -1, 0.25), 20, g("front"))
            bk.shoot(scene, cam, tgt, (1, 0, 0.2), 20, g("side"))
            bk.shoot(scene, cam, tgt, (0.8, -1, 0.45), 20, g("three-quarter"))
            block = bk.avatar_block(prev_col, (-8.0, -1.5))
            bk.shoot(scene, cam, (-2.5, -0.8, 1.8), (0.3, -1, 0.3), 25, g("scale-avatar"))
            block.hide_render = True
            bk.set_action(arm, acts["Swipe"], 5)
            bk.shoot(scene, cam, tgt, (0.8, -1, 0.35), 20, g("attack"))
        bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0.0))
        water = bpy.context.active_object
        water.name = "Preview_Water"
        for c in water.users_collection:
            c.objects.unlink(water)
        prev_col.objects.link(water)
        water.data.materials.append(bk.flat_material("Preview_WaterMat", (0.09, 0.21, 0.22)))
        water.hide_render = True
        if "--strips-only" not in ARGS:
            water.hide_render = False
            bk.set_action(arm, acts["Glide"], 1)
            bk.shoot(scene, cam, (0, -0.8, 0.6), (0.6, -1, 0.35), 18, g("submerged"))
            water.hide_render = True
        d = Vector((0.8, -1, 0.42)).normalized()
        cam.location = Vector((0, -0.8, 1.4)) + d * 23
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        cam.data.type = "PERSP"
        cam.data.lens = 50
        for name, short, _f0, _f1, _lp in ACTIONS:
            # the water plane shows where the surface is for the in/out-of-water clips
            water.hide_render = short not in ("glide", "emerge", "sink")
            ba.contact_strip(scene, arm, acts[name], os.path.join(PREV, f"anim-mire-{short}.png"))
        water.hide_render = True
        bk.set_action(arm, None, 1)
    arm.hide_render = False

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "mire.blend"), compress=True)
    print("MIRE_STATS", stats)


main()

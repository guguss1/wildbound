"""Build the Wildbound Mire in headless Blender.

Run:  blender -b --factory-startup --python mire_build.py -- [--no-render]
Outputs into assets/models/beasts/ (blend, FBX, palette, previews).
"""

import os
import random
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
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
        k1 = (hx + dirx * L1, hy + diry * L1, 0.32 * scale)
        k2 = (hx + dirx * (L1 + 0.75 * scale), hy + diry * (L1 + 0.75 * scale), 0.02)
        M(P, p0=(hx, hy, wr[2] - 0.05), p1=k1, r0=0.24 * scale, r1=0.2 * scale, color="stone", bone=f"{tag}_L_3", sides=4)
        M(P, p0=k1, p1=k2, r0=0.2 * scale, r1=0.0, color="stone_dark", bone=f"{tag}_L_3", sides=4)


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
    import math

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
    # ragged moss brow over the eyes
    R(center=(0, -2.55, 1.98), size=(2.8, 1.8, 0.4), color="moss", bone="Head", rot=(-14, 0, 0), jitter=0.07)
    for x, ln, w in ((-1.35, 1.25, 0.32), (-1.0, 0.9, 0.26), (-0.05, 0.95, 0.3), (0.25, 0.7, 0.22), (1.0, 0.85, 0.26), (1.35, 1.3, 0.34), (-0.6, 0.45, 0.22), (0.62, 0.42, 0.2)):
        P(p0=(x, -3.05 - 0.1 * abs(x), 2.05), p1=(x * 1.08, -3.4 - 0.05 * abs(x), 2.05 - ln), r0=w, r1=0.04,
          color="moss" if (x * 10) % 2 < 1 else "moss_dark", bone="Head", sides=4, jitter=0.1, twist=x * 30)
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


def poses():
    X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
    rest = {}
    submerged = {
        "Root": {"loc": (0, 0, -1.7)},
        "Shell": {"rot": [(X, -4)]},
        "Head": {"rot": [(X, -14)]},
    }
    for side, sgn in (("L", 1), ("R", -1)):
        submerged[f"ArmF_{side}_1"] = {"rot": [(Y, 75 * sgn), (Z, 20 * sgn)]}
        submerged[f"ArmM_{side}_1"] = {"rot": [(Y, 75 * sgn), (Z, 20 * sgn)]}
    reared = {
        "Root": {"loc": (0, 0, 0.35)},
        "Shell": {"rot": [(X, -14)]},
        "Head": {"rot": [(X, -12)]},
        "ArmF_L_1": {"rot": [(Y, -25)]},
        "ArmF_R_1": {"rot": [(Y, 25)]},
        "ArmF_L_2": {"rot": [(X, 20)]},
        "ArmF_R_2": {"rot": [(X, 20)]},
    }
    swipe_up = {
        "Shell": {"rot": [(X, -8), (Z, 8)]},
        "Head": {"rot": [(X, -10)]},
        "ArmF_R_1": {"rot": [(Y, 50), (Z, 30)]},
        "ArmF_R_2": {"rot": [(Y, -15), (X, -20)]},
        "ArmF_R_3": {"rot": [(X, 25)]},
    }
    swipe_hit = {
        "Root": {"loc": (0, -0.4, 0)},
        "Shell": {"rot": [(X, 6), (Z, -10)]},
        "Head": {"rot": [(X, 8)]},
        "ArmF_R_1": {"rot": [(Y, 5), (Z, 35)]},
        "ArmF_R_2": {"rot": [(Y, -10)]},
    }
    return rest, submerged, reared, swipe_up, swipe_hit


def main():
    scene = bk.reset_scene()
    scene.render.fps = 30
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

    rest, submerged, reared, swipe_up, swipe_hit = poses()
    acts = {
        "Submerged": bk.make_action(arm, "Submerged", [(1, submerged), (30, submerged)]),
        "Emerge": bk.make_action(arm, "Emerge", [(1, submerged), (14, reared), (30, rest)]),
        "Swipe": bk.make_action(arm, "Swipe", [(1, rest), (10, swipe_up), (16, swipe_hit), (34, rest)]),
    }

    stats = {"tris": bk.tri_count(mesh), "bones": len(arm.data.bones), "collision_tris": bk.tri_count(coll)}
    mn, mx = bk.world_bbox(mesh)
    stats["rest_bbox"] = [tuple(round(c, 2) for c in mn), tuple(round(c, 2) for c in mx)]

    bk.set_action(arm, None, 1)
    bk.export_fbx(os.path.join(OUT, "mire.fbx"), [arm, mesh], animated=True, bake=False)
    bk.export_anim_fbx(os.path.join(OUT, "mire_anim_submerged.fbx"), arm, mesh, acts["Submerged"])
    bk.export_anim_fbx(os.path.join(OUT, "mire_anim_emerge.fbx"), arm, mesh, acts["Emerge"])
    bk.export_anim_fbx(os.path.join(OUT, "mire_anim_swipe.fbx"), arm, mesh, acts["Swipe"])
    static = bk.static_copy(mesh, "Mire_Static", model_col)
    static.vertex_groups.clear()
    bk.export_fbx(os.path.join(OUT, "mire_static.fbx"), [static], animated=False)
    bk.set_action(arm, acts["Submerged"], 1)
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
        bk.shoot(scene, cam, tgt, (0, -1, 0.25), 20, g("front"))
        bk.shoot(scene, cam, tgt, (1, 0, 0.2), 20, g("side"))
        bk.shoot(scene, cam, tgt, (0.8, -1, 0.45), 20, g("three-quarter"))
        block = bk.avatar_block(prev_col, (-8.0, -1.5))
        bk.shoot(scene, cam, (-2.5, -0.8, 1.8), (0.3, -1, 0.3), 25, g("scale-avatar"))
        block.hide_render = True
        bk.set_action(arm, acts["Swipe"], 10)
        bk.shoot(scene, cam, tgt, (0.8, -1, 0.35), 20, g("attack"))
        bk.set_action(arm, acts["Submerged"], 1)
        bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0.0))
        water = bpy.context.active_object
        water.name = "Preview_Water"
        for c in water.users_collection:
            c.objects.unlink(water)
        prev_col.objects.link(water)
        water.data.materials.append(bk.flat_material("Preview_WaterMat", (0.09, 0.21, 0.22)))
        bk.shoot(scene, cam, (0, -0.8, 0.6), (0.6, -1, 0.35), 18, g("submerged"))
        water.hide_render = True
        bk.set_action(arm, None, 1)
    arm.hide_render = False

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "mire.blend"), compress=True)
    print("MIRE_STATS", stats)


main()

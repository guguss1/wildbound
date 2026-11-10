"""Build the Wildbound Viper: mesh, rig, pose actions, exports and previews.

Run: blender -b --factory-startup -P build_viper.py
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import beastlib as bl  # noqa: E402

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
PREV = os.path.join(OUT, 'previews')
TEX = os.path.join(OUT, 'textures')

# palette index -> colour (sRGB hex)
PAL_HEX = [
    '#3a2b46',  # 0 charcoal purple (plate risers, deep shadow zones)
    '#6a4a80',  # 1 purple plate
    '#80509f',  # 2 violet crest
    '#b8408e',  # 3 magenta accent
    '#cbb39c',  # 4 beige jaw / belly
    '#efe4cc',  # 5 ivory fangs
    '#a02a62',  # 6 mouth / tongue
    '#584070',  # 7 mid plate (alternating)
]
PAL = [bl.hex_rgb(h) for h in PAL_HEX]
CHAR, PLATE, CREST, MAG, BEIGE, IVORY, MOUTH, MID = range(8)

N_SPINE = 12


# --------------------------------------------------------------------------
# Spine curve
# --------------------------------------------------------------------------

def catmull(pts, samples_per=24):
    out = []
    P = [pts[0]] + pts + [pts[-1]]
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for s in range(samples_per):
            t = s / samples_per
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-1])
    return out


def spine_points():
    pts = []
    # coil: ~1.1 turns counter-clockwise ending at the front (-Y)
    turns = 1.0
    end_ang = math.radians(-90)
    start_ang = end_ang - turns * 2 * math.pi
    n = 14
    for i in range(n):
        t = i / (n - 1)
        ang = start_ang + (end_ang - start_ang) * t
        R = 3.1 - 0.7 * t
        z = 0.0
        pts.append(Vector((R * math.cos(ang), R * math.sin(ang) + 0.6, z)))
    # neck rises from the front of the coil in an S
    pts += [
        Vector((0.55, -1.55, 1.25)),
        Vector((0.3, -1.05, 2.45)),
        Vector((0.0, -0.75, 3.5)),
        Vector((0.0, -1.05, 4.3)),
        Vector((0.0, -1.6, 4.65)),
    ]
    return pts


def resample(curve, count):
    d = [0.0]
    for i in range(1, len(curve)):
        d.append(d[-1] + (curve[i] - curve[i - 1]).length)
    L = d[-1]
    out = []
    j = 0
    for k in range(count):
        s = L * k / (count - 1)
        while j < len(d) - 2 and d[j + 1] < s:
            j += 1
        t = (s - d[j]) / max(1e-6, d[j + 1] - d[j])
        out.append(curve[j].lerp(curve[j + 1], t))
    return out, L


def frames(points):
    """Parallel-transport frames; returns list of (T, N_up, B_right)."""
    res = []
    ref = Vector((0, 0.45, 1)).normalized()
    for i, p in enumerate(points):
        a = points[max(0, i - 1)]
        b = points[min(len(points) - 1, i + 1)]
        T = (b - a).normalized()
        up = (ref - T * ref.dot(T)).normalized()
        right = T.cross(up).normalized()
        res.append((T, up.copy(), right))
    return res


def radius_at(s):
    # s in [0,1] tail -> neck top
    if s < 0.30:
        return 0.2 + (0.95 - 0.2) * (s / 0.30) ** 0.7
    if s < 0.78:
        return 0.95 + 0.05 * math.sin((s - 0.30) / 0.48 * math.pi)
    return 0.95 - 0.15 * (s - 0.78) / 0.22


def spine_weights(s):
    b = s * N_SPINE - 0.5
    i0 = int(math.floor(b))
    w1 = b - i0
    i0 = max(0, min(N_SPINE - 1, i0))
    i1 = max(0, min(N_SPINE - 1, i0 + 1))
    if i0 == i1:
        return {f'Spine{i0 + 1:02d}': 1.0}
    if b < 0:
        return {f'Spine{1:02d}': 1.0}
    return {f'Spine{i0 + 1:02d}': 1.0 - w1, f'Spine{i1 + 1:02d}': w1}


# --------------------------------------------------------------------------
# Geometry
# --------------------------------------------------------------------------

def build_body(mb, pts, frs):
    n_seg = 24
    sides = 8
    M = len(pts) - 1
    rings, ring_s = [], []
    rng = mb.rng

    def ring_at(s, scale):
        k = s * M
        i = min(M - 1, int(k))
        t = k - i
        p = pts[i].lerp(pts[i + 1], t)
        T, U, Rt = frs[i]
        r = radius_at(s) * scale
        out = []
        for j in range(sides):
            ang = 2 * math.pi * j / sides + math.pi / sides  # flat top/bottom
            c, sn = math.cos(ang), math.sin(ang)
            v = sn * 0.86
            if sn < -0.5:
                v = -0.62  # flattened belly
            out.append(p + Rt * (c * r * 1.08) + U * (v * r))
        return out

    seg_kind = []
    for k in range(n_seg):
        s0 = k / n_seg
        s1 = (k + 0.82) / n_seg
        rings.append(ring_at(s0, 1.13))
        ring_s.append(s0)
        seg_kind.append('plate')
        rings.append(ring_at(s1, 0.92))
        ring_s.append(s1)
        seg_kind.append('riser')
    rings.append(ring_at(1.0, 1.08))
    ring_s.append(1.0)
    seg_kind.append('end')
    # tail tip apex
    tip = pts[0] - frs[0][0] * 0.55
    rings.insert(0, tip)
    ring_s.insert(0, 0.0)
    seg_kind.insert(0, 'tip')

    accents = {k: rng.random() for k in range(len(rings))}

    def col(i, side, n):
        if i < 0 or i >= len(rings) - 1:
            return CHAR
        kind = seg_kind[i + 1] if seg_kind[i] == 'tip' else seg_kind[i]
        ang = 2 * math.pi * (side + 0.5) / n + math.pi / n
        sn = math.sin(ang)
        if sn < -0.55 or (ring_s[i] > 0.6 and sn < 0.1):
            return BEIGE
        if kind == 'riser':
            return CHAR
        if sn > 0.3 and accents[i] < 0.28 and side % 3 == 1:
            return MAG
        return PLATE if (i // 2) % 2 == 0 else MID

    mb.loft(rings, col, lambda i: spine_weights(ring_s[i]), cap_start=False, cap_end=True)

    # dorsal blades along the neck and upper back, growing toward the head
    for k in range(8, n_seg, 1):
        s = (k + 0.4) / n_seg
        if s < 0.66:
            continue
        i = min(M - 1, int(s * M))
        p, (T, U, Rt) = pts[i], frs[i]
        r = radius_at(s)
        h = 0.35 + 0.75 * max(0.0, (s - 0.6) / 0.4) ** 1.2
        base_c = p + U * (r * 0.85)
        L = 0.75
        for side in (0,):
            bc = base_c + Rt * (side * r * 0.35)
            base = [bc + T * (-L * 0.4) + Rt * 0.3, bc + T * (L * 0.5),
                    bc + T * (-L * 0.4) - Rt * 0.3]
            apex = bc + U * h * 0.8 - T * (L * 0.8) + Rt * (side * h * 0.35)
            mb.loft([base, apex], CREST if (k + side) % 2 else PLATE, spine_weights(s), cap_start=True)


def build_head(mb, H0, F, U):
    X = F.cross(U).normalized()
    S = 1.3

    def tw(p):
        return H0 + (X * p[0] + F * p[1] + U * p[2]) * S
    W = 'Head'
    J = 'Jaw'

    def sec(f, w, top, bot, brow=0.0):
        # hexagon-ish section in (x, z) at forward distance f
        return [tw((w, f, bot + 0.15)), tw((w * 0.85, f, top * 0.55 + brow)),
                tw((w * 0.35, f, top)), tw((-w * 0.35, f, top)),
                tw((-w * 0.85, f, top * 0.55 + brow)), tw((-w, f, bot + 0.15)),
                tw((-w * 0.6, f, bot)), tw((w * 0.6, f, bot))]

    # upper skull: wedge from the back of the head to the snout
    skull = [sec(-0.55, 1.0, 1.05, 0.0), sec(0.35, 1.18, 1.3, -0.05, 0.12),
             sec(1.3, 1.02, 1.12, -0.05, 0.2), sec(2.15, 0.78, 0.72, 0.0),
             sec(2.75, 0.5, 0.5, 0.05), tw((0.0, 3.1, 0.25))]

    def skull_col(i, side, n):
        if i < 0:
            return CHAR
        if side in (6,):
            return MOUTH  # palate
        if side in (0, 5):
            return MID
        return PLATE if (i + side) % 3 else MID
    mb.loft(skull, skull_col, W)

    # brow ridges above the eye slots
    for sgn in (1, -1):
        b = [tw((sgn * 0.75, 0.6, 0.78)), tw((sgn * 1.18, 1.0, 0.7)), tw((sgn * 0.75, 1.75, 0.75)),
             tw((sgn * 0.55, 1.2, 0.98))]
        mb.loft([b, tw((sgn * 1.05, 0.55, 1.15))], PLATE, W)
        # cheek plate flaring back and out
        c = [tw((sgn * 0.95, 0.9, 0.15)), tw((sgn * 1.05, 0.2, 0.55)), tw((sgn * 0.85, -0.1, 0.0))]
        mb.loft([c, tw((sgn * 1.6, -0.6, 0.2))], MID, W)

    # crest: jagged violet blades fanning back from the skull
    blades = [
        (0.0, 0.3, 1.05, 0.0, -1.6, 1.75),
        (0.45, 0.0, 0.95, 1.1, -1.7, 1.45),
        (-0.45, 0.0, 0.95, -1.1, -1.7, 1.45),
        (0.8, -0.3, 0.65, 1.9, -1.6, 0.75),
        (-0.8, -0.3, 0.65, -1.9, -1.6, 0.75),
        (0.0, -0.45, 0.8, 0.0, -2.5, 1.0),
        (0.55, -0.6, 0.4, 1.6, -2.2, -0.2),
        (-0.55, -0.6, 0.4, -1.6, -2.2, -0.2),
        (0.35, 1.0, 1.05, 0.75, -0.6, 1.75),
        (-0.35, 1.0, 1.05, -0.75, -0.6, 1.75),
        (0.95, 0.2, 0.3, 2.0, -0.9, -0.4),
        (-0.95, 0.2, 0.3, -2.0, -0.9, -0.4),
        (0.3, -0.75, 0.0, 0.9, -2.4, -0.9),
        (-0.3, -0.75, 0.0, -0.9, -2.4, -0.9),
        (0.7, 0.4, 1.0, 1.5, -0.6, 1.9),
        (-0.7, 0.4, 1.0, -1.5, -0.6, 1.9),
    ]
    for bx, bf, bz, ax, af, az in blades:
        base = [tw((bx - 0.42, bf + 0.45, bz)), tw((bx + 0.42, bf + 0.45, bz)),
                tw((bx + 0.32, bf - 0.45, bz - 0.25)), tw((bx - 0.32, bf - 0.45, bz - 0.25))]
        mb.loft([base, tw((ax, af, az))], CREST, W)

    # upper fangs (big) + small teeth
    for sgn in (1, -1):
        a = tw((sgn * 0.55, 2.2, 0.02))
        mb.prism(a, tw((sgn * 0.52, 2.35, -0.7)), 0.21, 0.13, 5, IVORY, W, up=F)
        mb.loft([[tw((sgn * 0.52 + dx, 2.35 + dy, -0.7)) for dx, dy in ((0.13, 0), (0, 0.13), (-0.13, 0), (0, -0.13))],
                 tw((sgn * 0.44, 2.15, -1.35))], IVORY, W)
        for f, ln in ((0.9, 0.26), (1.4, 0.3), (1.8, 0.26), (2.6, 0.22)):
            base = [tw((sgn * 0.72 * (1 - f / 4.2) + 0.08, f, 0.02)), tw((sgn * 0.72 * (1 - f / 4.2) - 0.08, f, 0.02)),
                    tw((sgn * 0.72 * (1 - f / 4.2), f + 0.12, 0.02))]
            mb.loft([base, tw((sgn * 0.7 * (1 - f / 4.2), f + 0.05, -ln))], IVORY, W)

    # lower jaw: hinged at the back, opened ~38 degrees
    hinge = Vector((0.0, -0.25, -0.05))
    ang = math.radians(-30)
    ca, sa = math.cos(ang), math.sin(ang)

    def jw(p):
        f, z = p[1] - hinge[1], p[2] - hinge[2]
        return tw((p[0], hinge[1] + f * ca - z * sa, hinge[2] + f * sa + z * ca))

    def jsec(f, w, top, bot):
        return [jw((w, f, top)), jw((w * 0.4, f, top - 0.05)), jw((-w * 0.4, f, top - 0.05)), jw((-w, f, top)),
                jw((-w * 0.8, f, bot + 0.1)), jw((-w * 0.3, f, bot)), jw((w * 0.3, f, bot)), jw((w * 0.8, f, bot + 0.1))]
    jaw = [jsec(-0.5, 0.9, 0.05, -0.6), jsec(0.6, 0.9, 0.0, -0.65), jsec(1.6, 0.7, 0.0, -0.45),
           jsec(2.4, 0.42, 0.0, -0.28), jw((0.0, 2.75, -0.08))]

    def jaw_col(i, side, n):
        if side in (1, 2):
            return MOUTH
        return BEIGE
    mb.loft(jaw, jaw_col, J)
    for sgn in (1, -1):
        for f in (1.1, 1.8, 2.4):
            w = 0.82 * (1 - f / 3.6)
            base = [jw((sgn * w + 0.07, f, 0.0)), jw((sgn * w - 0.07, f, 0.0)), jw((sgn * w, f + 0.12, 0.0))]
            mb.loft([base, jw((sgn * w, f + 0.04, 0.3))], IVORY, J)
    # forked tongue
    t0, t1, t2 = jw((0.0, 0.6, 0.02)), jw((0.0, 2.0, 0.15)), jw((0.0, 2.9, -0.2))
    mb.prism(t0, t1, 0.16, 0.12, 4, MOUTH, J, up=U)
    mb.prism(t1, t2, 0.12, 0.08, 4, MOUTH, J, up=U)
    for sgn in (1, -1):
        mb.prism(t2, t2 + F * 0.45 + X * (sgn * 0.22) - U * 0.35, 0.08, 0.02, 4, MOUTH, J, up=U, apex=True)

    return tw


def build_eyes(mb, tw):
    for sgn in (1, -1):
        pts = [tw((sgn * 0.98, 0.75, 0.52)), tw((sgn * 1.0, 1.25, 0.66)), tw((sgn * 0.93, 1.75, 0.56)),
               tw((sgn * 0.95, 1.15, 0.38))]
        mb.loft([pts, tw((sgn * 1.12, 1.2, 0.52))], 0, 'Head')


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

def main():
    scene = bl.reset_scene()
    col = bpy.data.collections.new('Viper')
    scene.collection.children.link(col)

    curve = catmull(spine_points(), 20)
    pts, L = resample(curve, 121)
    for i, p in enumerate(pts):
        p.z = max(p.z, 0.72 * radius_at(i / (len(pts) - 1)))
    frs = frames(pts)

    neck_end = pts[-1]
    T_end = frs[-1][0]
    F = Vector((0.0, -1.0, -0.12)).normalized()
    U = Vector((0.0, -0.12, 1.0)).normalized()
    H0 = neck_end + Vector((0.0, -0.15, 0.05))

    mb = bl.MeshBuilder(seed=7, jitter=0.035)
    build_body(mb, pts, frs)
    tw = build_head(mb, H0, F, U)
    body = bl.build_object(mb, 'Viper_Body', PAL,
                           bl.palette_material('Viper_Palette',
                                               bl.palette_image('viper_palette', PAL, os.path.join(TEX, 'viper_palette.png'))),
                           col)

    emb = bl.MeshBuilder(seed=3, jitter=0.0)
    build_eyes(emb, tw)
    amber = bl.hex_rgb('#ff7a0a')
    eyes = bl.build_object(emb, 'Viper_Eyes', [amber], bl.emissive_material('Viper_EyeGlow', amber, 1.8), col)
    eyes.data.materials.clear()
    eyes.data.materials.append(bpy.data.materials['Viper_EyeGlow'])

    # collision proxy: coil drum + neck column + head box
    cmb = bl.MeshBuilder(seed=1)
    ring = [Vector((3.6 * math.cos(a), 3.6 * math.sin(a) + 0.6, 0)) for a in
            [2 * math.pi * k / 8 for k in range(8)]]
    cmb.loft([ring, [p + Vector((0, 0, 1.7)) for p in ring]], 0, 'Root')
    cmb.prism(Vector((0.2, -0.9, 1.0)), Vector((0.0, -0.9, 4.9)), 0.85, 0.75, 6, 0, 'Root')
    hc = H0 + F * 1.3 + U * 0.2
    cmb.prism(hc - F * 2.0, hc + F * 2.0, 1.15, 0.6, 6, 0, 'Root', up=U)
    proxy = bl.build_object(cmb, 'Viper_CollisionProxy', [bl.hex_rgb('#40ff40')],
                            bl.flat_material('CollisionProxyMat', bl.hex_rgb('#40ff40')), col)
    proxy.display_type = 'WIRE'
    proxy.hide_render = True
    for g in list(proxy.vertex_groups):
        proxy.vertex_groups.remove(g)

    # ---------------- rig
    bones = [('Root', (0, 0, 0), (0, -1.0, 0), None, (0, 0, 1))]
    M = len(pts) - 1
    for i in range(N_SPINE):
        a = int(round(M * i / N_SPINE))
        b = int(round(M * (i + 1) / N_SPINE))
        parent = 'Root' if i == 0 else f'Spine{i:02d}'
        bones.append((f'Spine{i + 1:02d}', tuple(pts[a]), tuple(pts[b]), parent, tuple(frs[a][1])))
    bones.append(('Head', tuple(H0), tuple(H0 + F * 1.6), f'Spine{N_SPINE:02d}', tuple(U)))
    hinge_w = tw((0.0, -0.25, -0.05))
    bones.append(('Jaw', tuple(hinge_w), tuple(tw((0.0, 1.6, -1.0))), 'Head', tuple(U)))
    rig = bl.make_armature('Viper', bones, col)
    bl.bind(body, rig)
    bl.bind(eyes, rig)
    for o in (body, eyes):
        o.vertex_groups.get('Head') or o.vertex_groups.new(name='Head')

    sp = lambda i: f'Spine{i:02d}'  # noqa: E731
    POSES = {
        'rest': {},
        'idle_a': {sp(10): (-3, 0, 0), sp(11): (-3, 0, 0), sp(12): (-2, 0, 0), 'Head': (4, 0, 0), 'Jaw': (6, 0, 0)},
        'windup': {sp(9): (14, 0, 0), sp(10): (16, 0, 0), sp(11): (12, 0, 0), sp(12): (8, 0, 0),
                   'Head': (-26, 0, 0), 'Jaw': (-6, 0, 0)},
        'attack': {sp(9): (-5, 0, 0), sp(10): (-8, 0, 0), sp(11): (-6, 0, 0),
                   sp(12): (-3, 0, 0), 'Head': (-4, 0, 0), 'Jaw': (-18, 0, 0)},
    }
    bl.make_action(rig, 'Viper_Idle', [(1, POSES['rest']), (30, POSES['idle_a']), (60, POSES['rest'])])
    bl.make_action(rig, 'Viper_Windup', [(1, POSES['rest']), (35, POSES['windup'])])
    bl.make_action(rig, 'Viper_Attack', [(1, POSES['windup']), (8, POSES['attack']), (20, POSES['attack'])])
    rig.animation_data.action = None
    bl.set_pose(rig, {})

    info = {
        'tris_body': bl.tri_count(body), 'tris_eyes': bl.tri_count(eyes), 'tris_proxy': bl.tri_count(proxy),
        'spine_length': round(L, 2), 'bones': [b[0] for b in bones],
    }

    # ---------------- exports
    bl.export_fbx(os.path.join(OUT, 'viper.fbx'), [rig, body, eyes])
    for act_name, short in (('Viper_Idle', 'idle'), ('Viper_Windup', 'windup'), ('Viper_Attack', 'attack')):
        act = bpy.data.actions[act_name]
        rig.animation_data.action = act
        bpy.context.scene.frame_start = int(act.frame_range[0])
        bpy.context.scene.frame_end = int(act.frame_range[1])
        bl.export_fbx(os.path.join(OUT, f'viper_anim_{short}.fbx'), [rig, body, eyes], anim=True)
    rig.animation_data.action = None
    bl.set_pose(rig, {})
    bpy.context.view_layer.update()
    static = bl.static_copy([body, eyes], 'Viper_Static', col)
    bl.export_fbx(os.path.join(OUT, 'viper_static.fbx'), [static])
    static.hide_render = True
    static.hide_set(True)
    bl.export_fbx(os.path.join(OUT, 'viper_collision.fbx'), [proxy])

    min_c = Vector((1e9, 1e9, 1e9))
    max_c = Vector((-1e9, -1e9, -1e9))
    for v in static.data.vertices:
        for k in range(3):
            min_c[k] = min(min_c[k], v.co[k])
            max_c[k] = max(max_c[k], v.co[k])
    info['bbox_min'] = tuple(round(c, 2) for c in min_c)
    info['bbox_max'] = tuple(round(c, 2) for c in max_c)
    info['tris_static'] = bl.tri_count(static)

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, 'viper.blend'), compress=True)

    # ---------------- previews (separate scene state, not saved)
    if '--no-render' not in sys.argv:
        pcol, cam = bl.setup_render(scene)
        c = Vector((0, -0.4, 2.6))
        shots = [
            ('front', (0, -22, 4.2), c),
            ('side', (22, -0.5, 3.6), c),
            ('34', (10.5, -13.5, 5.8), c + Vector((0, 0, 0.6))),
        ]
        for name, loc, tgt in shots:
            bl.aim_camera(cam, loc, tgt)
            bl.render_to(scene, os.path.join(PREV, f'viper-{name}.png'))
        # attack pose with avatar block
        rig.animation_data.action = bpy.data.actions['Viper_Attack']
        scene.frame_set(12)
        blk = bl.avatar_block(pcol, (0.0, -8.5, 0))
        bl.aim_camera(cam, (22, -12, 6.5), Vector((0.0, -2.5, 2.8)))
        bl.render_to(scene, os.path.join(PREV, 'viper-attack-avatar-scale.png'))
        rig.animation_data.action = bpy.data.actions['Viper_Windup']
        scene.frame_set(35)
        bpy.data.objects.remove(blk)
        bl.aim_camera(cam, (20, -8, 5), c)
        bl.render_to(scene, os.path.join(PREV, 'viper-windup.png'))

    print('VIPER_INFO', info)


main()

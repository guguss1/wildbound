"""Build the Wildbound Pouncer: mesh, rig, gameplay actions, exports, previews and contact sheets.

Run: blender -b --factory-startup -P build_pouncer.py
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import beastanim as ba  # noqa: E402
import beastatlas as at  # noqa: E402
import beastlib as bl  # noqa: E402

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
PREV = os.path.join(OUT, 'previews')
TEX = os.path.join(OUT, 'textures')

PAL_HEX = [
    '#352a3f',  # 0 charcoal plum (joints, undersides)
    '#5e4568',  # 1 dark plum carapace
    '#7b5288',  # 2 violet plates
    '#a8407f',  # 3 magenta accent
    '#8f7f9e',  # 4 dusty lavender
    '#e6d7c0',  # 5 ivory claws / fangs
    '#4a3854',  # 6 mid plum
    '#5e4568',  # 7 dark plum with painted magenta veins (atlas tile 0)
    '#7b5288',  # 8 violet with painted magenta veins (atlas tile 1)
]
PAL = [bl.hex_rgb(h) for h in PAL_HEX]
CHAR, PLUM, VIOLET, MAG, LAV, IVORY, MID, VEIN_PL, VEIN_V = range(9)
TILE_OF = {VEIN_PL: 0, VEIN_V: 1}

BODY_C = Vector((0.0, -0.2, 1.75))

# leg layout per side: (forward angle deg, knee height, reach scale)
LEGS = [
    (40, 4.0, 1.0),
    (12, 3.0, 1.1),
    (-20, 2.9, 1.1),
    (-50, 3.4, 1.05),
]


def leg_points(side, idx):
    phi, knee_h, sc = LEGS[idx]
    a = math.radians(phi)
    d = Vector((side * math.cos(a), -math.sin(a), 0.0))
    root = BODY_C + d * 0.75 + Vector((0, 0.15 * (idx - 1.5), -0.05))
    knee = Vector((root.x, root.y, 0)) + d * (1.75 * sc)
    knee.z = knee_h
    ankle = Vector((root.x, root.y, 0)) + d * (2.95 * sc)
    ankle.z = 1.3
    foot = Vector((root.x, root.y, 0)) + d * (3.35 * sc)
    foot.z = 0.0
    return root, knee, ankle, foot, d


def leg_name(side, idx, part):
    return f"Leg{'L' if side > 0 else 'R'}{idx + 1}_{part}"


def build_body(mb):
    rng = mb.rng

    # abdomen: big faceted rock-like bulb behind the body
    ab_c = BODY_C + Vector((0.0, 2.0, 0.75))

    def ab_col(fc):
        if fc.z < -0.35:
            return CHAR
        r = rng.random()
        if fc.z > -0.1 and r < 0.4:
            return VEIN_PL if r < 0.28 else VEIN_V
        return PLUM if rng.random() < 0.6 else VIOLET
    mb.blob(ab_c, (1.8, 2.0, 1.5), PLUM, 'Abdomen', subdiv=2, col_fn=ab_col)
    # spinneret tip
    mb.prism(ab_c + Vector((0, 1.6, -0.2)), ab_c + Vector((0, 2.15, -0.45)), 0.35, 0.05, 5, MID, 'Abdomen', apex=True)
    # dorsal ridge plates on the abdomen
    for k in range(4):
        y = ab_c.y - 0.9 + k * 0.6
        z = ab_c.z + 1.42 - 0.12 * k * k * 0.5
        base = [Vector((-0.28, y - 0.25, z - 0.1)), Vector((0.28, y - 0.25, z - 0.1)),
                Vector((0.2, y + 0.3, z - 0.15)), Vector((-0.2, y + 0.3, z - 0.15))]
        mb.loft([base, Vector((0, y + 0.35, z + 0.35 - 0.05 * k))], VIOLET, 'Abdomen')

    # cephalothorax: armoured faceted block
    def sec(y, w, top, bot):
        c = BODY_C
        return [Vector((w, y, c.z + bot + 0.15)), Vector((w * 0.95, y, c.z + top * 0.5)),
                Vector((w * 0.45, y, c.z + top)), Vector((-w * 0.45, y, c.z + top)),
                Vector((-w * 0.95, y, c.z + top * 0.5)), Vector((-w, y, c.z + bot + 0.15)),
                Vector((-w * 0.5, y, c.z + bot)), Vector((w * 0.5, y, c.z + bot))]
    thorax = [sec(0.75, 0.95, 0.65, -0.5), sec(0.1, 1.25, 0.9, -0.6), sec(-0.75, 1.15, 0.82, -0.55),
              sec(-1.5, 0.95, 0.66, -0.45), sec(-1.85, 0.7, 0.4, -0.32)]

    def th_col(i, side, n):
        if side in (6, 7, 5) or i < 0:
            return CHAR
        return VIOLET if (i + side) % 3 == 0 else PLUM
    mb.loft(thorax, th_col, 'Body')

    # face mask: triangular armoured plate over the front
    fz = BODY_C.z
    mask = [Vector((1.05, -1.6, fz + 0.5)), Vector((0.0, -1.85, fz + 0.92)), Vector((-1.05, -1.6, fz + 0.5)),
            Vector((-0.6, -1.85, fz - 0.32)), Vector((0.6, -1.85, fz - 0.32))]
    mb.loft([mask, Vector((0, -2.12, fz - 0.05))], PLUM, 'Body')
    # brow ridges
    for sgn in (1, -1):
        b = [Vector((sgn * 0.12, -1.8, fz + 0.7)), Vector((sgn * 0.95, -1.62, fz + 0.55)),
             Vector((sgn * 0.6, -1.35, fz + 0.95))]
        mb.loft([b, Vector((sgn * 0.8, -2.0, fz + 0.85))], VIOLET, 'Body')
    # crown spikes on top of the head
    for x, y, h in ((0.0, -0.95, 0.75), (0.45, -0.7, 0.6), (-0.45, -0.7, 0.6), (0.75, -0.2, 0.5),
                    (-0.75, -0.2, 0.5), (0.25, -0.2, 0.55), (-0.25, -0.2, 0.55)):
        base_z = fz + 0.72
        base = [Vector((x - 0.17, y - 0.15, base_z)), Vector((x + 0.17, y - 0.15, base_z)),
                Vector((x + 0.15, y + 0.2, base_z)), Vector((x - 0.15, y + 0.2, base_z))]
        mb.loft([base, Vector((x * 1.1, y + 0.15, base_z + h))], VIOLET, 'Body')

    # chelicerae blocks and four ivory fangs
    for sgn in (1, -1):
        bone = 'Fang.L' if sgn > 0 else 'Fang.R'
        cb = Vector((sgn * 0.4, -1.85, fz - 0.4))
        mb.prism(cb + Vector((0, 0.35, 0.25)), cb, 0.26, 0.22, 5, PLUM, bone, mid=(0.5, 1.15))
        # big outer fang: longer, hooked curve (out and forward, then down and back in to the tip)
        p0 = cb + Vector((sgn * 0.08, -0.05, -0.05))
        p1 = p0 + Vector((sgn * 0.2, -0.42, -0.48))
        p2 = p0 + Vector((sgn * 0.13, -0.64, -0.98))
        p3 = p0 + Vector((-sgn * 0.1, -0.52, -1.24))
        mb.prism(p0, p1, 0.31, 0.27, 5, IVORY, bone)
        mb.prism(p1, p2, 0.27, 0.19, 5, IVORY, bone)
        mb.prism(p2, p3, 0.19, 0.02, 5, IVORY, bone, apex=True)
        # small inner fang, also curved
        q0 = Vector((sgn * 0.14, -1.95, fz - 0.4))
        q1 = q0 + Vector((sgn * 0.02, -0.16, -0.36))
        mb.prism(q0, q1, 0.11, 0.08, 4, IVORY, bone)
        mb.prism(q1, q1 + Vector((-sgn * 0.06, 0.02, -0.38)), 0.08, 0.01, 4, IVORY, bone, apex=True)


def build_legs(mb):
    for side in (1, -1):
        for idx in range(4):
            root, knee, ankle, foot, d = leg_points(side, idx)
            fem, tib, tar = (leg_name(side, idx, p) for p in ('Femur', 'Tibia', 'Tarsus'))
            up = Vector((0, 0, 1))
            # coxa knob at the body
            mb.blob(root, (0.45, 0.45, 0.45), CHAR, fem, subdiv=1)
            stripe = VEIN_V if (idx + (side > 0)) % 2 == 0 else VIOLET
            mb.prism(root, knee, 0.46, 0.38, 5, lambda i, k, n, s=stripe: s if k == 0 else (VEIN_PL if k == 3 and idx < 2 else PLUM), fem,
                     up=up, mid=(0.55, 1.3))
            mb.blob(knee, (0.42, 0.42, 0.4), MID, tib, subdiv=1)
            mb.prism(knee, ankle, 0.4, 0.3, 5, lambda i, k, n, s=stripe: (VIOLET if s == VEIN_V else VEIN_V) if k == 0 else PLUM, tib,
                     up=up, mid=(0.4, 1.3))
            mb.blob(ankle, (0.3, 0.3, 0.3), CHAR, tar, subdiv=1)
            claw0 = ankle.lerp(foot, 0.35)
            mb.prism(ankle, claw0, 0.29, 0.26, 5, PLUM, tar, up=up)
            # ivory claw with a small back spur
            mb.prism(claw0, foot, 0.26, 0.02, 5, IVORY, tar, up=up, apex=True, mid=(0.3, 1.12))
            spur = claw0.lerp(foot, 0.25)
            mb.prism(spur, spur + d * 0.35 + Vector((0, 0, 0.18)), 0.07, 0.01, 4, IVORY, tar, apex=True)


def build_eyes(mb):
    fz = BODY_C.z
    for sgn in (1, -1):
        mb.blob(Vector((sgn * 0.42, -1.97, fz + 0.36)), (0.28, 0.16, 0.25), 0, 'Body', subdiv=1)
        mb.blob(Vector((sgn * 0.18, -2.08, fz + 0.04)), (0.11, 0.07, 0.11), 0, 'Body', subdiv=1)
        mb.blob(Vector((sgn * 0.78, -1.72, fz + 0.14)), (0.1, 0.07, 0.1), 0, 'Body', subdiv=1)



# action name, file suffix, first frame, last frame, loops
ACTIONS = [
    ('Pouncer_Idle', 'idle', 1, 41, True),         # 1.33 s twitchy idle
    ('Pouncer_Stalk', 'stalk', 1, 25, True),       # 0.80 s low walk cycle (alternating tetrapod gait)
    ('Pouncer_Windup', 'windup', 1, 40, False),    # 1.30 s legs compress (in-game telegraph 1.3 s)
    ('Pouncer_Leap', 'leap', 1, 24, False),        # 0.77 s launch + tuck (in-game flight 0.75 s)
    ('Pouncer_Land', 'land', 1, 7, False),         # 0.20 s impact splay
    ('Pouncer_Recover', 'recover', 1, 31, False),  # 1.00 s gather legs (land + recover = 1.2 s pause)
]

GROUP_A = [(1, 0), (-1, 1), (1, 2), (-1, 3)]   # L1, R2, L3, R4 step together
GROUP_B = [(-1, 0), (1, 1), (-1, 2), (1, 3)]


def leg_frames():
    frames = {}
    for side in (1, -1):
        for idx in range(4):
            _r, _k, _a, _f, d = leg_points(side, idx)
            d = d.normalized()
            a = d.cross(Vector((0, 0, 1))).normalized()   # +rx about a lifts the leg
            for part in ('Femur', 'Tibia', 'Tarsus'):
                frames[leg_name(side, idx, part)] = (a, d, Vector((0, 0, 1)))
    return frames


def legs(fem=0.0, tib=0.0, tar=0.0, yaw=0.0, only=None):
    """Same leg pose on every leg (or on `only`); yaw > 0 swings the foot forward on both sides."""
    p = {}
    for side in (1, -1):
        for idx in range(4):
            if only is not None and (side, idx) not in only:
                continue
            p[leg_name(side, idx, 'Femur')] = ba.ch(fem, 0, -side * yaw)
            p[leg_name(side, idx, 'Tibia')] = ba.ch(tib)
            p[leg_name(side, idx, 'Tarsus')] = ba.ch(tar)
    return p


def fangs(open_deg=0.0, fwd=0.0):
    return {'Fang.L': ba.ch(-fwd, -open_deg, 0), 'Fang.R': ba.ch(-fwd, open_deg, 0)}


def build_actions(rig_obj):
    rig = ba.Rig(rig_obj, leg_frames())
    all_legs = [(s, i) for s in (1, -1) for i in range(4)]
    chains = {(s, i): (leg_name(s, i, 'Femur'), leg_name(s, i, 'Tarsus')) for s, i in all_legs}

    def plant(p, which=None, w=1.0):
        keys = which or all_legs
        before = {chains[k][0]: p.get(chains[k][0], [0.0] * 6)[0] for k in keys}
        ba.plant_tips(rig, p, [chains[k] for k in keys])
        if w < 1.0:
            for b, x in before.items():
                p[b][0] = x + (p[b][0] - x) * w
            rig.apply(p)

    def body(z=0.0, pitch=0.0, roll=0.0, ab=0.0, ab_yaw=0.0, y=0.0):
        return {'Body': ba.ch(pitch, roll, 0, (0, y, z)), 'Abdomen': ba.ch(ab, 0, ab_yaw)}

    rest = {}
    crouch = ba.padd(body(z=-0.55, pitch=-3, ab=14), legs(tib=-14, tar=8), fangs(18, 34))
    deep = ba.padd(body(z=-0.75, pitch=-4, ab=18), legs(tib=-20, tar=12), fangs(22, 42))
    launch = ba.padd(body(z=0.35, pitch=-6, ab=-8), legs(fem=-4, tib=8, tar=4), fangs(24, 30))
    tuck = ba.padd(body(z=0.2, pitch=-4, ab=6), legs(fem=22, tib=-62, tar=-34), fangs(30, 30))
    reach = ba.padd(body(z=0.0, pitch=-8, ab=-2), legs(fem=6, tib=-24, tar=-4, yaw=0), fangs(26, 30))
    splay = ba.padd(body(z=-0.72, pitch=-2, ab=10), legs(tib=16, tar=-6), fangs(6, 38))
    acts = {}

    # ---- Idle: body bob with feet planted, sharp fang twitches, one front-leg tap
    def idle(f):
        bob = ba.wave(f, 1, 40)
        p = ba.padd(body(z=-0.06 + 0.05 * bob, pitch=1.2 * ba.wave(f, 1, 40, 0.25), ab=3 * ba.wave(f, 1, 40, 0.15),
                         ab_yaw=2.5 * ba.wave(f, 1, 40, 0.4)))
        tw = math.exp(-((f - 9) / 2.0) ** 2) + math.exp(-((f - 27) / 2.0) ** 2)
        p = ba.padd(p, fangs(12 * tw, 12 + 8 * tw))
        return p

    def idle_post(f, p):
        tap = (1, 0)
        plant(p, [k for k in all_legs if k != tap])
        lift = 14 * max(0.0, math.sin(math.pi * (f - 16) / 10)) if 16 <= f <= 26 else 0.0
        plant(p, [tap])
        p[leg_name(1, 0, 'Femur')][0] += lift
        p.setdefault(leg_name(1, 0, 'Tibia'), [0.0] * 6)[0] = -0.6 * lift
        rig.apply(p)
    acts['Pouncer_Idle'] = rig.bake('Pouncer_Idle', 1, 41, idle, idle_post, loop=True)

    # ---- Stalk: in-place walk cycle, two alternating groups of four legs, body low and bobbing
    def gait(u):
        """u in [0,1): swing (lifted, foot travels back -> front) for u < 0.5, stance otherwise."""
        if u < 0.5:
            s = u / 0.5
            return -1 + 2 * ba.smooth(s), 18 * math.sin(math.pi * s)
        s = (u - 0.5) / 0.5
        return 1 - 2 * s, 0.0

    def stalk(f):
        u = (f - 1) / 24.0
        p = body(z=-0.28 + 0.04 * ba.wave(f, 1, 12), roll=2.0 * ba.wave(f, 1, 24), ab=4 + 2 * ba.wave(f, 1, 12, 0.3),
                 ab_yaw=4 * ba.wave(f, 1, 24, 0.2))
        for grp, off in ((GROUP_A, 0.0), (GROUP_B, 0.5)):
            for side, idx in grp:
                yaw, _lift = gait((u + off) % 1.0)
                p[leg_name(side, idx, 'Femur')] = ba.ch(0, 0, -side * 11 * yaw)
                p[leg_name(side, idx, 'Tibia')] = ba.ch(-6)
        return ba.padd(p, fangs(4 + 3 * ba.wave(f, 1, 12), 24))

    def stalk_post(f, p):
        plant(p)
        u = (f - 1) / 24.0
        for grp, off in ((GROUP_A, 0.0), (GROUP_B, 0.5)):
            for side, idx in grp:
                _yaw, lift = gait((u + off) % 1.0)
                p[leg_name(side, idx, 'Femur')][0] += lift
                p.setdefault(leg_name(side, idx, 'Tibia'), [0.0] * 6)[0] -= 0.7 * lift
        rig.apply(p)
    acts['Pouncer_Stalk'] = rig.bake('Pouncer_Stalk', 1, 25, stalk, stalk_post, loop=True)

    # ---- Windup: legs compress (knees rise as the body sinks), fangs spread, quiver, final dip
    def windup(f):
        p = ba.spline([(1, rest), (14, crouch, 'hold'), (33, crouch, 'hold'), (40, deep, 'hold')], f)
        if 14 < f < 36:
            q = 0.025 * ba.wave(f, 0, 3)
            p = ba.padd(p, {'Body': ba.ch(0.6 * ba.wave(f, 0, 4), 0, 0, (0, 0, q))})
        return p
    acts['Pouncer_Windup'] = rig.bake('Pouncer_Windup', 1, 40, windup, lambda f, p: plant(p))

    # ---- Leap: push off, tuck the legs for the flight, open them again to reach for the ground
    def leap(f):
        return ba.spline([(1, deep), (4, launch), (9, tuck, 'hold'), (17, tuck, 'hold'), (24, reach, 'hold')], f)

    def leap_post(f, p):
        if f <= 6:     # pushing off: feet leave the ground over frames 4-6
            plant(p, w=1.0 if f <= 3 else (6 - f) / 3.0)
        elif f >= 19:  # reaching for the ground: feet meet it on the last frame
            plant(p, w=(f - 19) / 5.0)
    acts['Pouncer_Leap'] = rig.bake('Pouncer_Leap', 1, 24, leap, leap_post)

    # ---- Land: slam down into a wide splay, fangs snap shut
    acts['Pouncer_Land'] = rig.bake('Pouncer_Land', 1, 7, lambda f: ba.spline(
        [(1, reach), (3, ba.padd(splay, body(z=-0.12))), (7, splay, 'hold')], f),
        lambda f, p: plant(p))

    # ---- Recover: shudder, fang clicks, gather the legs back under the body
    def recover(f):
        p = ba.spline([(1, splay, 'hold'), (9, ba.plerp(splay, rest, 0.25)), (31, rest, 'hold')], f)
        sh = max(0.0, 1 - f / 14.0)
        clicks = math.exp(-((f - 11) / 1.6) ** 2) + math.exp(-((f - 19) / 1.6) ** 2)
        p = ba.padd(p, {'Body': ba.ch(0, 2.5 * sh * ba.wave(f, 0, 4), 0, (0, 0, 0.03 * sh * ba.wave(f, 0, 3)))},
                    fangs(14 * clicks, 6 * clicks))
        return p
    acts['Pouncer_Recover'] = rig.bake('Pouncer_Recover', 1, 31, recover, lambda f, p: plant(p))
    rig.apply({})
    return acts


def main():
    scene = bl.reset_scene()
    scene.render.fps = ba.FPS
    col = bpy.data.collections.new('Pouncer')
    scene.collection.children.link(col)

    mb = bl.MeshBuilder(seed=11, jitter=0.03)
    build_body(mb)
    build_legs(mb)
    vein, rim, core = bl.hex_rgb('#b8408e'), bl.hex_rgb('#241b2c'), bl.hex_rgb('#ff7fd0')
    tiles = [
        at.paint_tile(PAL[PLUM], vein, rim=rim, core=core, seed=13, cracks=3, width=2.4),
        at.paint_tile(PAL[VIOLET], vein, rim=rim, core=core, seed=29, cracks=3, width=2.4),
    ]
    img = at.build_atlas('pouncer_palette', PAL, tiles, os.path.join(TEX, 'pouncer_palette.png'))
    body = bl.build_object(mb, 'Pouncer_Body', PAL, bl.palette_material('Pouncer_Palette', img), col)
    at.apply_uvs(body, len(PAL), TILE_OF, world_per_tile=1.5, seed=4)

    emb = bl.MeshBuilder(seed=2)
    build_eyes(emb)
    mag = bl.hex_rgb('#ff3fc0')
    eyemat = bl.emissive_material('Pouncer_EyeGlow', mag, 3.0)
    eyes = bl.build_object(emb, 'Pouncer_Eyes', [mag], eyemat, col)

    # collision proxy: a low hexagonal slab for the body plus a flat leg footprint
    cmb = bl.MeshBuilder(seed=1)
    ring = [Vector((1.35 * math.cos(a), 2.3 * math.sin(a) + 0.65, 0.7)) for a in
            [2 * math.pi * k / 8 for k in range(8)]]
    cmb.loft([ring, [p + Vector((0, 0, 2.2)) for p in ring]], 0, 'Root')
    foot = [Vector((3.6 * math.cos(a), 3.2 * math.sin(a) - 0.1, 0.0)) for a in [2 * math.pi * k / 8 for k in range(8)]]
    cmb.loft([foot, [p * 0.9 + Vector((0, 0, 0.7)) for p in foot]], 0, 'Root')
    proxy = bl.build_object(cmb, 'Pouncer_CollisionProxy', [bl.hex_rgb('#40ff40')],
                            bl.flat_material('CollisionProxyMat', bl.hex_rgb('#40ff40')), col)
    proxy.display_type = 'WIRE'
    proxy.hide_render = True
    for g in list(proxy.vertex_groups):
        proxy.vertex_groups.remove(g)

    # ---------------- rig
    Z = (0, 0, 1)
    bones = [
        ('Root', (0, 0, 0), (0, -1.0, 0), None, Z),
        ('Body', tuple(BODY_C), tuple(BODY_C + Vector((0, -1.2, 0))), 'Root', Z),
        ('Abdomen', tuple(BODY_C + Vector((0, 0.7, 0.1))), tuple(BODY_C + Vector((0, 2.6, 0.45))), 'Body', Z),
        ('Fang.L', (0.4, -1.8, BODY_C.z - 0.25), (0.4, -2.0, BODY_C.z - 1.3), 'Body', (0, -1, 0)),
        ('Fang.R', (-0.4, -1.8, BODY_C.z - 0.25), (-0.4, -2.0, BODY_C.z - 1.3), 'Body', (0, -1, 0)),
    ]
    for side in (1, -1):
        for idx in range(4):
            root, knee, ankle, foot, d = leg_points(side, idx)
            fem, tib, tar = (leg_name(side, idx, p) for p in ('Femur', 'Tibia', 'Tarsus'))
            bones += [(fem, tuple(root), tuple(knee), 'Body', Z),
                      (tib, tuple(knee), tuple(ankle), fem, Z),
                      (tar, tuple(ankle), tuple(foot), tib, Z)]
    rig = bl.make_armature('Pouncer', bones, col)
    bl.bind(body, rig)
    bl.bind(eyes, rig)

    acts = build_actions(rig)

    info = {'tris_body': bl.tri_count(body), 'tris_eyes': bl.tri_count(eyes), 'tris_proxy': bl.tri_count(proxy),
            'bones': [b[0] for b in bones]}

    ba.assign(rig, None, 1)
    ba.Rig(rig).apply({})
    bl.export_fbx(os.path.join(OUT, 'pouncer.fbx'), [rig, body, eyes])
    for act_name, short, f0, f1, _loop in ACTIONS:
        ba.assign(rig, acts[act_name], f0)
        scene.frame_start, scene.frame_end = f0, f1
        bl.export_fbx(os.path.join(OUT, f'pouncer_anim_{short}.fbx'), [rig, body, eyes], anim=True)
    ba.assign(rig, None, 1)
    ba.Rig(rig).apply({})
    static = bl.static_copy([body, eyes], 'Pouncer_Static', col)
    bl.export_fbx(os.path.join(OUT, 'pouncer_static.fbx'), [static])
    static.hide_render = True
    static.hide_set(True)
    bl.export_fbx(os.path.join(OUT, 'pouncer_collision.fbx'), [proxy])

    lo = [min(v.co[k] for v in static.data.vertices) for k in range(3)]
    hi = [max(v.co[k] for v in static.data.vertices) for k in range(3)]
    info['bbox_min'] = tuple(round(c, 2) for c in lo)
    info['bbox_max'] = tuple(round(c, 2) for c in hi)
    info['tris_static'] = bl.tri_count(static)
    info['actions'] = {a: (f0, f1, round((f1 - f0) / ba.FPS, 3), lp) for a, _s, f0, f1, lp in ACTIONS}
    feet = ba.Ground(body, [leg_name(s, i, 'Tarsus') for s in (1, -1) for i in range(4)])
    info['ground'] = {a: ba.ground_report(rig, acts[a], feet) for a, _s, _f0, _f1, _lp in ACTIONS}
    ba.Rig(rig).apply({})

    scene.frame_start, scene.frame_end = 1, 41
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, 'pouncer.blend'), compress=True)

    if '--no-render' not in sys.argv:
        pcol, cam = bl.setup_render(scene)
        c = Vector((0, 0.2, 1.8))
        if '--strips-only' not in sys.argv:
            for name, loc in (('front', (0, -17, 4.0)), ('side', (19, 0.2, 3.5)), ('34', (9.5, -12, 5.5)),
                              ('top', (0.01, 0.2, 22))):
                bl.aim_camera(cam, loc, c)
                bl.render_to(scene, os.path.join(PREV, f'pouncer-{name}.png'))
            ba.assign(rig, acts['Pouncer_Windup'], 40)
            bl.aim_camera(cam, (11, -14, 6.0), c)
            bl.render_to(scene, os.path.join(PREV, 'pouncer-windup.png'))
            ba.assign(rig, acts['Pouncer_Leap'], 12)
            rig.location.z = 2.0  # lift the airborne pose for the preview only
            blk = bl.avatar_block(pcol, (-6.5, 1.0, 0))
            bl.aim_camera(cam, (9, -19, 6.0), Vector((-1.8, 0, 2.8)))
            bl.render_to(scene, os.path.join(PREV, 'pouncer-attack-avatar-scale.png'))
            rig.location.z = 0.0
            bpy.data.objects.remove(blk)
        bl.aim_camera(cam, (11, -15, 7.0), Vector((0, 0.0, 1.4)))
        for act_name, short, f0, f1, _loop in ACTIONS:
            ba.contact_strip(scene, rig, acts[act_name], os.path.join(PREV, f'anim-pouncer-{short}.png'))

    print('POUNCER_INFO', info)


main()

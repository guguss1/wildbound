"""Build the tarantula revision of the Wildbound Pouncer.

Same 29-bone rig as build_pouncer.py (identical names, hierarchy and rest pose, uniformly scaled by S),
same six gameplay actions plus a new web-throw action. The mesh is split into a few flat-colour
objects (one Roblox MeshPart each, coloured in Studio from PALETTE below), every vertex rigidly
skinned to one bone.

Run: blender -b --factory-startup -P build_pouncer_tarantula.py [-- --no-render]

Outputs:
  assets/models/beasts/pouncer_tarantula.blend
  assets/exports/caramelo/pouncer-tarantula.fbx              (rigged model, no animation)
  assets/exports/caramelo/pouncer-tarantula-anim-<short>.fbx (one action per file, like pouncer_anim_*)
  assets/models/beasts/previews/pouncer-tarantula-{34,side,avatar-scale}.png
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import beastanim as ba  # noqa: E402
import beastlib as bl  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, '..'))
REPO = os.path.normpath(os.path.join(OUT, '..', '..', '..'))
PREV = os.path.join(OUT, 'previews')
EXPORT_DIR = os.path.join(REPO, 'assets', 'exports', 'caramelo')
EXPORT = os.path.join(EXPORT_DIR, 'pouncer-tarantula.fbx')

# uniform rig/mesh scale over the original Pouncer (design units below are the original's)
S = 1.6

# ---------------------------------------------------------------- colour table (Roblox MeshPart.Color)
# mesh object name -> sRGB 0-255. The FBX MeshParts import grey; set Color from this table.
PALETTE = {
    'Pouncer_Body': (58, 42, 33),       # dark brown cephalothorax, chelicerae, pedipalps
    'Pouncer_Abdomen': (43, 31, 26),    # near-black brown abdomen
    'Pouncer_Legs': (30, 22, 19),       # brown-black legs
    'Pouncer_Bands': (214, 110, 44),    # orange / rust joint bands
    'Pouncer_Hair': (140, 86, 54),      # rusty hair tufts and spikes
    'Pouncer_Eyes': (255, 63, 192),     # glowing eyes (use Neon material in Roblox)
    'Pouncer_Fangs': (217, 200, 168),   # bone-ivory fangs
}
PARTS = list(PALETTE)
BODY, ABD, LEGS, BANDS, HAIR, EYES, FANGS = range(len(PARTS))


def lin_rgb(c):
    return bl.hex_rgb('#%02x%02x%02x' % c)


BODY_C = Vector((0.0, -0.2, 1.75))

# leg layout per side: (forward angle deg, knee height, reach scale) -- identical to build_pouncer.py
LEGS_LAYOUT = [
    (40, 4.0, 1.0),
    (12, 3.0, 1.1),
    (-20, 2.9, 1.1),
    (-50, 3.4, 1.05),
]


def leg_points(side, idx):
    phi, knee_h, sc = LEGS_LAYOUT[idx]
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


# ---------------------------------------------------------------- geometry helpers

def hairs(mb, a, b, r, n, w, length, t0=0.08, t1=0.92, lean=1.1, spread=(-0.35, math.pi + 0.35), thick=0.13):
    """Spiky hair tufts along segment a->b (radius r): mostly on the top and sides, leaning to b."""
    rng = mb.rng
    a, b = Vector(a), Vector(b)
    d = (b - a).normalized()
    x = d.cross(Vector((0, 0, 1)))
    if x.length < 1e-4:
        x = d.cross(Vector((1, 0, 0)))
    x.normalize()
    y = x.cross(d).normalized()
    if y.z < 0:
        y = -y
    for i in range(n):
        t = t0 + (t1 - t0) * (i + rng.uniform(0.2, 0.8)) / n
        ang = rng.uniform(*spread)
        nd = x * math.cos(ang) + y * math.sin(ang)
        base = a.lerp(b, t) + nd * r * 0.8
        L = length * rng.uniform(0.7, 1.25)
        tip = base + (nd + d * lean).normalized() * L
        mb.prism(base, tip, L * thick, 0.0, 3, HAIR, w, apex=True, twist=rng.uniform(0, 2))


def band(mb, a, b, t0, t1, r, w, sides=6):
    a, b = Vector(a), Vector(b)
    mb.prism(a.lerp(b, t0), a.lerp(b, t1), r, r, sides, BANDS, w)


def split(mb, n):
    """Split one builder (face colour = part index) into n builders, scaled by S."""
    outs = [bl.MeshBuilder() for _ in range(n)]
    maps = [dict() for _ in range(n)]
    for face, c in zip(mb.faces, mb.fcol):
        o, m = outs[c], maps[c]
        idx = []
        for vi in face:
            if vi not in m:
                m[vi] = len(o.verts)
                o.verts.append(mb.verts[vi] * S)
                o.weights.append(dict(mb.weights[vi]))
            idx.append(m[vi])
        o.faces.append(idx)
        o.fcol.append(0)
    return outs


# ---------------------------------------------------------------- body

def build_body(mb):
    rng = mb.rng
    fz = BODY_C.z

    # ---- abdomen: big round hairy bulb, clearly larger than the cephalothorax
    ab_c = BODY_C + Vector((0.0, 2.75, 0.7))
    ab_r = (1.9, 2.1, 1.75)

    def ab_col(fc):
        if fc.z > -0.2 and rng.random() < 0.22:
            return HAIR
        if fc.z > 0.55 and fc.y > -0.1 and rng.random() < 0.5:   # rusty dorsal patch
            return HAIR
        return ABD
    mb.blob(ab_c, ab_r, ABD, 'Abdomen', subdiv=3, col_fn=ab_col)
    # pedicel (waist) joining abdomen and cephalothorax
    mb.prism(BODY_C + Vector((0, 0.45, 0.05)), BODY_C + Vector((0, 1.05, 0.3)), 0.42, 0.5, 6, ABD, 'Abdomen')
    # spinnerets
    for sgn in (1, -1):
        p0 = ab_c + Vector((sgn * 0.25, 1.85, -0.55))
        mb.prism(p0, p0 + Vector((sgn * 0.12, 0.6, -0.25)), 0.16, 0.03, 5, ABD, 'Abdomen', apex=True)
    # long hair spikes over the top and sides (fibonacci points on the ellipsoid)
    count = 230
    golden = math.pi * (3 - math.sqrt(5))
    for k in range(count):
        zz = 1 - 2 * (k + 0.5) / count
        if zz < -0.3:
            continue
        rr = math.sqrt(max(0.0, 1 - zz * zz))
        th = golden * k
        p = Vector((rr * math.cos(th), rr * math.sin(th), zz))
        pos = ab_c + Vector((p.x * ab_r[0], p.y * ab_r[1], p.z * ab_r[2]))
        nrm = Vector((p.x / ab_r[0], p.y / ab_r[1], p.z / ab_r[2])).normalized()
        base = pos - nrm * 0.08
        L = rng.uniform(0.3, 0.55)
        tip = base + (nrm + Vector((0, 0.8, 0.15))).normalized() * L
        mb.prism(base, tip, 0.065, 0.0, 3, HAIR, 'Abdomen', apex=True, twist=rng.uniform(0, 2))

    # ---- cephalothorax: flattish carapace, raised head region at the front
    def sec(y, w, top, bot):
        c = BODY_C
        return [Vector((w, y, c.z + bot + 0.15)), Vector((w * 0.95, y, c.z + top * 0.45)),
                Vector((w * 0.55, y, c.z + top * 0.9)), Vector((0.0, y, c.z + top)),
                Vector((-w * 0.55, y, c.z + top * 0.9)), Vector((-w * 0.95, y, c.z + top * 0.45)),
                Vector((-w, y, c.z + bot + 0.15)), Vector((-w * 0.5, y, c.z + bot)), Vector((w * 0.5, y, c.z + bot))]
    thorax = [sec(0.8, 0.7, 0.4, -0.4), sec(0.35, 1.15, 0.6, -0.55), sec(-0.35, 1.3, 0.72, -0.58),
              sec(-1.05, 1.15, 0.86, -0.55), sec(-1.6, 0.9, 0.82, -0.48), sec(-1.95, 0.6, 0.55, -0.36)]
    mb.loft(thorax, BODY, 'Body')
    # radial hair streaks on the carapace (thin rusty ridges from the fovea outward)
    fov = Vector((0, -0.25, fz + 0.74))
    for k in range(8):
        ang = 2 * math.pi * (k + 0.5) / 8
        dd = Vector((math.cos(ang) * 1.0, math.sin(ang) * 0.95, 0))
        a0 = fov + dd * 0.25
        a1 = fov + dd * 1.0 + Vector((0, 0, -0.35))
        mb.prism(a0, a1, 0.07, 0.05, 3, HAIR, 'Body')
    # rim hair along the carapace edge
    for sgn in (1, -1):
        hairs(mb, Vector((sgn * 1.1, 0.5, fz + 0.15)), Vector((sgn * 1.0, -1.6, fz + 0.15)), 0.12, 5, 'Body',
              0.3, spread=(-0.2, 0.6) if sgn > 0 else (math.pi - 0.6, math.pi + 0.2), lean=0.2)
    # ocular tubercle
    mb.blob(Vector((0, -1.4, fz + 0.83)), (0.36, 0.34, 0.22), BODY, 'Body', subdiv=2)

    # ---- pedipalps (short leg-like feelers held in front), on the Body bone
    for sgn in (1, -1):
        r0 = Vector((sgn * 0.55, -1.75, fz - 0.4))
        p1 = r0 + Vector((sgn * 0.4, -0.55, 0.25))
        p2 = p1 + Vector((sgn * 0.15, -0.5, -0.5))
        p3 = p2 + Vector((0.0, -0.38, -0.25))
        mb.prism(r0, p1, 0.24, 0.21, 6, LEGS, 'Body', mid=(0.5, 1.1))
        mb.blob(p1, (0.24, 0.24, 0.24), BANDS, 'Body', subdiv=1)
        mb.prism(p1, p2, 0.21, 0.18, 6, LEGS, 'Body')
        mb.blob(p2, (0.2, 0.2, 0.2), BANDS, 'Body', subdiv=1)
        mb.prism(p2, p3, 0.18, 0.2, 6, LEGS, 'Body')
        mb.blob(p3 + Vector((0, -0.05, 0)), (0.2, 0.22, 0.18), LEGS, 'Body', subdiv=1)
        hairs(mb, r0, p1, 0.2, 3, 'Body', 0.22)
        hairs(mb, p1, p2, 0.17, 3, 'Body', 0.22)
        hairs(mb, p2, p3, 0.16, 3, 'Body', 0.2)

    # ---- chelicerae (big hairy lobes) and fangs, on the Fang bones
    for sgn in (1, -1):
        bone = 'Fang.L' if sgn > 0 else 'Fang.R'
        cc = Vector((sgn * 0.3, -2.05, fz - 0.12))
        mb.blob(cc, (0.3, 0.48, 0.42), BODY, bone, subdiv=2)
        hairs(mb, cc + Vector((0, 0.35, 0.25)), cc + Vector((0, -0.35, 0.1)), 0.25, 4, bone, 0.25, lean=-0.3)
        p0 = cc + Vector((sgn * 0.02, -0.25, -0.33))
        p1 = p0 + Vector((sgn * 0.1, -0.2, -0.45))
        p2 = p1 + Vector((sgn * 0.02, 0.0, -0.35))
        p3 = p2 + Vector((-sgn * 0.08, 0.3, -0.28))
        mb.prism(p0, p1, 0.17, 0.15, 5, FANGS, bone)
        mb.prism(p1, p2, 0.15, 0.11, 5, FANGS, bone)
        mb.prism(p2, p3, 0.11, 0.01, 5, FANGS, bone, apex=True)


def build_legs(mb):
    for side in (1, -1):
        for idx in range(4):
            root, knee, ankle, foot, d = leg_points(side, idx)
            fem, tib, tar = (leg_name(side, idx, p) for p in ('Femur', 'Tibia', 'Tarsus'))
            up = Vector((0, 0, 1))
            # coxa knob at the body
            mb.blob(root, (0.46, 0.46, 0.44), LEGS, fem, subdiv=1)
            # femur: thick, bulging
            mb.prism(root, knee, 0.43, 0.37, 6, LEGS, fem, up=up, mid=(0.5, 1.18))
            band(mb, root, knee, 0.86, 0.97, 0.42, fem)
            hairs(mb, root, knee, 0.42, 11, fem, 0.36)
            # patella knob (orange knee)
            mb.blob(knee, (0.45, 0.45, 0.42), BANDS, tib, subdiv=1)
            # tibia
            mb.prism(knee, ankle, 0.37, 0.29, 6, LEGS, tib, up=up, mid=(0.45, 1.12))
            band(mb, knee, ankle, 0.04, 0.14, 0.4, tib)
            band(mb, knee, ankle, 0.84, 0.94, 0.32, tib)
            hairs(mb, knee, ankle, 0.36, 10, tib, 0.34)
            # ankle (orange) + metatarsus + thin band + tarsus with a padded foot
            mb.blob(ankle, (0.31, 0.31, 0.3), BANDS, tar, subdiv=1)
            mid = ankle.lerp(foot, 0.58)
            mb.prism(ankle, mid, 0.28, 0.23, 6, LEGS, tar, up=up)
            band(mb, ankle, foot, 0.52, 0.62, 0.255, tar)
            mb.prism(mid, foot + Vector((0, 0, 0.16)), 0.23, 0.2, 6, LEGS, tar, up=up)
            mb.blob(foot + Vector((0, 0, 0.17)) + d * 0.05, (0.23, 0.26, 0.17), LEGS, tar, subdiv=1)
            hairs(mb, ankle, foot, 0.25, 6, tar, 0.26, t1=0.75)


def build_eyes(mb):
    fz = BODY_C.z
    # two big forward eyes on the tubercle, six small ones around them (eight in total, like a real spider)
    for sgn in (1, -1):
        mb.blob(Vector((sgn * 0.15, -1.68, fz + 0.9)), (0.15, 0.1, 0.15), EYES, 'Body', subdiv=1)
        mb.blob(Vector((sgn * 0.33, -1.6, fz + 0.8)), (0.09, 0.07, 0.08), EYES, 'Body', subdiv=1)
        mb.blob(Vector((sgn * 0.3, -1.3, fz + 0.97)), (0.08, 0.07, 0.07), EYES, 'Body', subdiv=1)
        mb.blob(Vector((sgn * 0.38, -1.42, fz + 0.88)), (0.07, 0.06, 0.06), EYES, 'Body', subdiv=1)


# ---------------------------------------------------------------- animation

# action name, file suffix, first frame, last frame, loops
ACTIONS = [
    ('Pouncer_Idle', 'idle', 1, 41, True),         # 1.33 s twitchy idle
    ('Pouncer_Stalk', 'stalk', 1, 25, True),       # 0.80 s low walk cycle (alternating tetrapod gait)
    ('Pouncer_Windup', 'windup', 1, 40, False),    # 1.30 s legs compress (in-game telegraph 1.3 s)
    ('Pouncer_Leap', 'leap', 1, 24, False),        # 0.77 s launch + tuck (in-game flight 0.75 s)
    ('Pouncer_Land', 'land', 1, 7, False),         # 0.20 s impact splay
    ('Pouncer_Recover', 'recover', 1, 31, False),  # 1.00 s gather legs (land + recover = 1.2 s pause)
    ('Pouncer_Throw', 'throw', 1, 19, False),      # 0.60 s rear up, abdomen flick, web-ball throw, settle
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


def curve(keys, f):
    """Scalar smooth-step interpolation through (frame, value) keys."""
    if f <= keys[0][0]:
        return keys[0][1]
    for (fa, va), (fb, vb) in zip(keys, keys[1:]):
        if f <= fb:
            return va + (vb - va) * ba.smooth((f - fa) / (fb - fa))
    return keys[-1][1]


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
        # offsets are authored in the original Pouncer's units and scaled with the rig
        return {'Body': ba.ch(pitch, roll, 0, (0, y * S, z * S)), 'Abdomen': ba.ch(ab, 0, ab_yaw)}

    rest = {}
    crouch = ba.padd(body(z=-0.55, pitch=-3, ab=14), legs(tib=-14, tar=8), fangs(18, 34))
    deep = ba.padd(body(z=-0.75, pitch=-4, ab=18), legs(tib=-20, tar=12), fangs(22, 42))
    launch = ba.padd(body(z=0.35, pitch=-6, ab=-8), legs(fem=-4, tib=8, tar=4), fangs(24, 30))
    tuck = ba.padd(body(z=0.2, pitch=-4, ab=6), legs(fem=22, tib=-62, tar=-34), fangs(30, 30))
    reach = ba.padd(body(z=0.0, pitch=-8, ab=-2), legs(fem=6, tib=-24, tar=-4, yaw=0), fangs(26, 30))
    splay = ba.padd(body(z=-0.72, pitch=-2, ab=10), legs(tib=16, tar=-6), fangs(6, 38))
    acts = {}

    # ---- Idle
    def idle(f):
        bob = ba.wave(f, 1, 40)
        p = ba.padd(body(z=-0.06 + 0.05 * bob, pitch=1.2 * ba.wave(f, 1, 40, 0.25), ab=3 * ba.wave(f, 1, 40, 0.15),
                         ab_yaw=2.5 * ba.wave(f, 1, 40, 0.4)))
        tw = math.exp(-((f - 9) / 2.0) ** 2) + math.exp(-((f - 27) / 2.0) ** 2)
        return ba.padd(p, fangs(12 * tw, 12 + 8 * tw))

    def idle_post(f, p):
        tap = (1, 0)
        plant(p, [k for k in all_legs if k != tap])
        lift = 14 * max(0.0, math.sin(math.pi * (f - 16) / 10)) if 16 <= f <= 26 else 0.0
        plant(p, [tap])
        p[leg_name(1, 0, 'Femur')][0] += lift
        p.setdefault(leg_name(1, 0, 'Tibia'), [0.0] * 6)[0] = -0.6 * lift
        rig.apply(p)
    acts['Pouncer_Idle'] = rig.bake('Pouncer_Idle', 1, 41, idle, idle_post, loop=True)

    # ---- Stalk
    def gait(u):
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

    # ---- Windup
    def windup(f):
        p = ba.spline([(1, rest), (14, crouch, 'hold'), (33, crouch, 'hold'), (40, deep, 'hold')], f)
        if 14 < f < 36:
            q = 0.025 * S * ba.wave(f, 0, 3)
            p = ba.padd(p, {'Body': ba.ch(0.6 * ba.wave(f, 0, 4), 0, 0, (0, 0, q))})
        return p
    acts['Pouncer_Windup'] = rig.bake('Pouncer_Windup', 1, 40, windup, lambda f, p: plant(p))

    # ---- Leap
    def leap(f):
        return ba.spline([(1, deep), (4, launch), (9, tuck, 'hold'), (17, tuck, 'hold'), (24, reach, 'hold')], f)

    def leap_post(f, p):
        if f <= 6:
            plant(p, w=1.0 if f <= 3 else (6 - f) / 3.0)
        elif f >= 19:
            plant(p, w=(f - 19) / 5.0)
    acts['Pouncer_Leap'] = rig.bake('Pouncer_Leap', 1, 24, leap, leap_post)

    # ---- Land
    acts['Pouncer_Land'] = rig.bake('Pouncer_Land', 1, 7, lambda f: ba.spline(
        [(1, reach), (3, ba.padd(splay, body(z=-0.12))), (7, splay, 'hold')], f),
        lambda f, p: plant(p))

    # ---- Recover
    def recover(f):
        p = ba.spline([(1, splay, 'hold'), (9, ba.plerp(splay, rest, 0.25)), (31, rest, 'hold')], f)
        sh = max(0.0, 1 - f / 14.0)
        clicks = math.exp(-((f - 11) / 1.6) ** 2) + math.exp(-((f - 19) / 1.6) ** 2)
        p = ba.padd(p, {'Body': ba.ch(0, 2.5 * sh * ba.wave(f, 0, 4), 0, (0, 0, 0.03 * S * sh * ba.wave(f, 0, 3)))},
                    fangs(14 * clicks, 6 * clicks))
        return p
    acts['Pouncer_Recover'] = rig.bake('Pouncer_Recover', 1, 31, recover, lambda f, p: plant(p))

    # ---- Throw (new, 0.6 s): rear the front up with the front legs raised and the abdomen cocked up,
    # then snap: body pitches forward, abdomen flicks up and over as if flinging a web ball, front legs
    # slam down; settle back to rest. Positive pitch dips the head, positive ab lifts the abdomen tip.
    rear = ba.padd(body(z=0.42, pitch=-22, ab=30, y=0.3), legs(tib=-6), fangs(26, 18))
    cock = ba.padd(body(z=0.5, pitch=-26, ab=36, y=0.38), legs(tib=-8), fangs(30, 12))
    snap = ba.padd(body(z=-0.12, pitch=6, ab=58, y=-0.3), legs(tib=-10, tar=6), fangs(12, 40))
    follow = ba.padd(body(z=-0.08, pitch=3, ab=22, y=-0.12), legs(tib=-6, tar=3), fangs(6, 28))

    def throw(f):
        return ba.spline([(1, rest), (6, rear), (9, cock, 'hold'), (12, snap), (15, follow), (19, rest, 'hold')], f)

    front = [(1, 0), (-1, 0)]
    second = [(1, 1), (-1, 1)]

    def throw_post(f, p):
        plant(p)
        lift = curve([(1, 0), (6, 48), (9, 56), (11, 20), (12, 0), (19, 0)], f)
        for side, idx in front:
            p[leg_name(side, idx, 'Femur')][0] += lift
            p[leg_name(side, idx, 'Femur')][2] += -side * 0.35 * lift   # reach the raised feet forward
            p.setdefault(leg_name(side, idx, 'Tibia'), [0.0] * 6)[0] -= 0.55 * lift
        for side, idx in second:
            p[leg_name(side, idx, 'Femur')][0] += 0.3 * lift
            p.setdefault(leg_name(side, idx, 'Tibia'), [0.0] * 6)[0] -= 0.2 * lift
        rig.apply(p)
    acts['Pouncer_Throw'] = rig.bake('Pouncer_Throw', 1, 19, throw, throw_post)

    rig.apply({})
    return acts


# ---------------------------------------------------------------- export / checks

def export_fbx(path, objs, anim=False):
    """Same settings as pouncer.fbx and the Caramelo build scripts."""
    bl.select_only(objs)
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={'ARMATURE', 'MESH'}, apply_unit_scale=True,
        apply_scale_options='FBX_SCALE_ALL', mesh_smooth_type='FACE', use_mesh_modifiers=False,
        add_leaf_bones=False, primary_bone_axis='Y', secondary_bone_axis='X', armature_nodetype='NULL',
        bake_anim=anim, bake_anim_use_all_actions=False, bake_anim_use_nla_strips=False,
        bake_anim_force_startend_keying=True, path_mode='AUTO')


def build_flat_object(mb, name, material, collection):
    """One flat-colour mesh object, triangulated, flat shaded, rigidly skinned.

    (beastlib.build_object's UV/colour-attribute + remove_doubles path corrupted the heap in
    Blender 5.0.1 on these meshes; the parts need no UVs, and the vertex order is kept so the
    weights map 1:1.)
    """
    import bmesh
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in mb.verts], [], mb.faces)
    me.update()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    me.materials.append(material)
    me.update()
    obj = bpy.data.objects.new(name, me)
    collection.objects.link(obj)
    by_bone = {}
    for vi, wd in enumerate(mb.weights):
        (bone, _w), = wd.items()
        by_bone.setdefault(bone, []).append(vi)
    for bone, idx in by_bone.items():
        obj.vertex_groups.new(name=bone).add(idx, 1.0, 'REPLACE')
    return obj


def world_coords(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in objs:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        pts += [o.matrix_world @ v.co for v in me.vertices]
        ev.to_mesh_clear()
    return pts


def bbox(objs):
    pts = world_coords(objs)
    lo = [min(p[k] for p in pts) for k in range(3)]
    hi = [max(p[k] for p in pts) for k in range(3)]
    return lo, hi


def action_min_z(rig, act, meshes):
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    best = (1e9, '')
    for f in range(f0, f1 + 1):
        ba.assign(rig, act, f)
        for m in meshes:
            z = min(p.z for p in world_coords([m]))
            if z < best[0]:
                best = (z, m.name)
    ba.assign(rig, None, 1)
    ba.Rig(rig).apply({})
    return (round(best[0], 3), best[1])


def main():
    scene = bl.reset_scene()
    scene.render.fps = ba.FPS
    col = bpy.data.collections.new('Pouncer')
    scene.collection.children.link(col)

    mb = bl.MeshBuilder(seed=11, jitter=0.025)
    build_body(mb)
    build_legs(mb)
    build_eyes(mb)
    parts = split(mb, len(PARTS))
    meshes = []
    for i, name in enumerate(PARTS):
        rgb = lin_rgb(PALETTE[name])
        if i == EYES:
            mat = bl.emissive_material('Tarantula_Eyes', rgb, 3.0)
        else:
            mat = bl.flat_material('Tarantula_' + name.split('_')[1], rgb)
        meshes.append(build_flat_object(parts[i], name, mat, col))

    # ---------------- rig: identical to build_pouncer.py, every coordinate scaled by S
    Z = (0, 0, 1)

    def sv(v):
        return tuple(Vector(v) * S)
    bones = [
        ('Root', (0, 0, 0), sv((0, -1.0, 0)), None, Z),
        ('Body', sv(BODY_C), sv(BODY_C + Vector((0, -1.2, 0))), 'Root', Z),
        ('Abdomen', sv(BODY_C + Vector((0, 0.7, 0.1))), sv(BODY_C + Vector((0, 2.6, 0.45))), 'Body', Z),
        ('Fang.L', sv((0.4, -1.8, BODY_C.z - 0.25)), sv((0.4, -2.0, BODY_C.z - 1.3)), 'Body', (0, -1, 0)),
        ('Fang.R', sv((-0.4, -1.8, BODY_C.z - 0.25)), sv((-0.4, -2.0, BODY_C.z - 1.3)), 'Body', (0, -1, 0)),
    ]
    for side in (1, -1):
        for idx in range(4):
            root, knee, ankle, foot, d = leg_points(side, idx)
            fem, tib, tar = (leg_name(side, idx, p) for p in ('Femur', 'Tibia', 'Tarsus'))
            bones += [(fem, sv(root), sv(knee), 'Body', Z),
                      (tib, sv(knee), sv(ankle), fem, Z),
                      (tar, sv(ankle), sv(foot), tib, Z)]
    rig = bl.make_armature('Pouncer', bones, col)
    for m in meshes:
        bl.bind(m, rig)
    # rigid skinning check: every vertex on exactly one bone
    bone_names = {b[0] for b in bones}
    for m in meshes:
        names = [g.name for g in m.vertex_groups]
        assert set(names) <= bone_names, (m.name, set(names) - bone_names)
        for v in m.data.vertices:
            assert len(v.groups) == 1 and abs(v.groups[0].weight - 1.0) < 1e-6, (m.name, v.index)

    acts = build_actions(rig)

    ba.assign(rig, None, 1)
    ba.Rig(rig).apply({})
    os.makedirs(EXPORT_DIR, exist_ok=True)
    export_fbx(EXPORT, [rig] + meshes)
    for act_name, short, f0, f1, _loop in ACTIONS:
        ba.assign(rig, acts[act_name], f0)
        scene.frame_start, scene.frame_end = f0, f1
        export_fbx(os.path.join(EXPORT_DIR, f'pouncer-tarantula-anim-{short}.fbx'), [rig] + meshes, anim=True)
    ba.assign(rig, None, 1)
    ba.Rig(rig).apply({})

    lo, hi = bbox(meshes)
    info = {
        'tris': {m.name: bl.tri_count(m) for m in meshes},
        'tris_total': sum(bl.tri_count(m) for m in meshes),
        'bones': [b[0] for b in bones],
        'bbox_min': [round(c, 2) for c in lo], 'bbox_max': [round(c, 2) for c in hi],
        'size': [round(h - l, 2) for l, h in zip(lo, hi)],
        'actions': {a: (f0, f1, round((f1 - f0) / ba.FPS, 3), lp) for a, _s, f0, f1, lp in ACTIONS},
        'min_z_per_action': {a: action_min_z(rig, acts[a], meshes) for a, _s, _f0, _f1, _lp in ACTIONS},
    }
    ba.Rig(rig).apply({})

    scene.frame_start, scene.frame_end = 1, 41
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, 'pouncer_tarantula.blend'), compress=True)

    if '--no-render' not in sys.argv:
        pcol, cam = bl.setup_render(scene)
        c = Vector((0, 0.4, 2.9))
        for name, loc in (('side', (30, 0.4, 5.6)), ('34', (15.5, -19.5, 8.8))):
            bl.aim_camera(cam, loc, c)
            bl.render_to(scene, os.path.join(PREV, f'pouncer-tarantula-{name}.png'))
        blk = bl.avatar_block(pcol, (-10.0, -1.5, 0))
        bl.aim_camera(cam, (13, -27, 8.0), Vector((-2.5, 0, 3.0)))
        bl.render_to(scene, os.path.join(PREV, 'pouncer-tarantula-avatar-scale.png'))
        bpy.data.objects.remove(blk)
        strip_dir = os.environ.get('TARANTULA_STRIPS')
        if strip_dir:
            bl.aim_camera(cam, (17, -24, 11.0), Vector((0, 0.0, 2.6)))
            for act_name, short, f0, f1, _loop in ACTIONS:
                ba.contact_strip(scene, rig, acts[act_name], os.path.join(strip_dir, f'anim-tarantula-{short}.png'))

    print('POUNCER_TARANTULA_INFO', json.dumps(info))
    print('PALETTE_JSON', json.dumps({k: list(v) for k, v in PALETTE.items()}))


main()

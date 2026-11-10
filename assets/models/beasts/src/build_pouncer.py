"""Build the Wildbound Pouncer: mesh, rig, pose actions, exports and previews.

Run: blender -b --factory-startup -P build_pouncer.py
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

PAL_HEX = [
    '#352a3f',  # 0 charcoal plum (joints, undersides)
    '#5e4568',  # 1 dark plum carapace
    '#7b5288',  # 2 violet plates
    '#a8407f',  # 3 magenta accent
    '#8f7f9e',  # 4 dusty lavender
    '#e6d7c0',  # 5 ivory claws / fangs
    '#4a3854',  # 6 mid plum
]
PAL = [bl.hex_rgb(h) for h in PAL_HEX]
CHAR, PLUM, VIOLET, MAG, LAV, IVORY, MID = range(7)

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
        if fc.z > 0.3 and rng.random() < 0.3:
            return MAG
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
        # big outer fang: curves down and inward
        p0 = cb + Vector((sgn * 0.08, -0.05, -0.05))
        p1 = p0 + Vector((sgn * 0.12, -0.4, -0.7))
        p2 = p0 + Vector((-sgn * 0.1, -0.3, -1.35))
        mb.prism(p0, p1, 0.26, 0.21, 5, IVORY, bone)
        mb.prism(p1, p2, 0.21, 0.02, 5, IVORY, bone, apex=True)
        # small inner fang
        q0 = Vector((sgn * 0.14, -1.95, fz - 0.4))
        mb.prism(q0, q0 + Vector((-sgn * 0.04, -0.15, -0.55)), 0.09, 0.02, 4, IVORY, bone, apex=True)


def build_legs(mb):
    for side in (1, -1):
        for idx in range(4):
            root, knee, ankle, foot, d = leg_points(side, idx)
            fem, tib, tar = (leg_name(side, idx, p) for p in ('Femur', 'Tibia', 'Tarsus'))
            up = Vector((0, 0, 1))
            # coxa knob at the body
            mb.blob(root, (0.45, 0.45, 0.45), CHAR, fem, subdiv=1)
            mb.prism(root, knee, 0.46, 0.38, 5, lambda i, k, n: VIOLET if k == 0 else PLUM, fem,
                     up=up, mid=(0.55, 1.3))
            mb.blob(knee, (0.42, 0.42, 0.4), MID, tib, subdiv=1)
            mb.prism(knee, ankle, 0.4, 0.3, 5, lambda i, k, n: VIOLET if k == 0 else PLUM, tib,
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


def main():
    scene = bl.reset_scene()
    col = bpy.data.collections.new('Pouncer')
    scene.collection.children.link(col)

    mb = bl.MeshBuilder(seed=11, jitter=0.03)
    build_body(mb)
    build_legs(mb)
    img = bl.palette_image('pouncer_palette', PAL, os.path.join(TEX, 'pouncer_palette.png'))
    body = bl.build_object(mb, 'Pouncer_Body', PAL, bl.palette_material('Pouncer_Palette', img), col)

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

    def legs_pose(fem_rx, tib_rx, tar_rx, body_loc=(0, 0, 0), fang=0, ab=0, spread=0):
        pose = {'Body': {'rot': (0, 0, 0), 'loc': body_loc}, 'Abdomen': (ab, 0, 0),
                'Fang.L': (fang, 0, 0), 'Fang.R': (fang, 0, 0)}
        for side in (1, -1):
            for idx in range(4):
                pose[leg_name(side, idx, 'Femur')] = (fem_rx, 0, side * spread)
                pose[leg_name(side, idx, 'Tibia')] = (tib_rx, 0, 0)
                pose[leg_name(side, idx, 'Tarsus')] = (tar_rx, 0, 0)
        return pose

    rest = {}
    idle = legs_pose(3, -2, 0, body_loc=(0, 0.0, -0.06), fang=6, ab=-3)
    # bone local Y points along the bone; Body loc Y is bone-local, so lower via local Z-ish
    windup = legs_pose(24, -28, 8, body_loc=(0, 0, -0.2), fang=8, ab=-8)
    airborne = legs_pose(30, -62, -30, body_loc=(0, 0, 0), fang=-25, ab=6)
    bl.make_action(rig, 'Pouncer_Idle', [(1, rest), (20, idle), (40, rest)])
    bl.make_action(rig, 'Pouncer_Windup', [(1, rest), (25, windup)])
    bl.make_action(rig, 'Pouncer_Attack', [(1, windup), (8, airborne), (20, airborne)])
    rig.animation_data.action = None
    bl.set_pose(rig, {})

    info = {'tris_body': bl.tri_count(body), 'tris_eyes': bl.tri_count(eyes), 'tris_proxy': bl.tri_count(proxy),
            'bones': [b[0] for b in bones]}

    bl.export_fbx(os.path.join(OUT, 'pouncer.fbx'), [rig, body, eyes])
    for act_name, short in (('Pouncer_Idle', 'idle'), ('Pouncer_Windup', 'windup'), ('Pouncer_Attack', 'attack')):
        act = bpy.data.actions[act_name]
        rig.animation_data.action = act
        scene.frame_start = int(act.frame_range[0])
        scene.frame_end = int(act.frame_range[1])
        bl.export_fbx(os.path.join(OUT, f'pouncer_anim_{short}.fbx'), [rig, body, eyes], anim=True)
    rig.animation_data.action = None
    bl.set_pose(rig, {})
    bpy.context.view_layer.update()
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

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, 'pouncer.blend'), compress=True)

    if '--no-render' not in sys.argv:
        pcol, cam = bl.setup_render(scene)
        c = Vector((0, 0.2, 1.8))
        for name, loc in (('front', (0, -17, 4.0)), ('side', (19, 0.2, 3.5)), ('34', (9.5, -12, 5.5)),
                          ('top', (0.01, 0.2, 22))):
            bl.aim_camera(cam, loc, c)
            bl.render_to(scene, os.path.join(PREV, f'pouncer-{name}.png'))
        rig.animation_data.action = bpy.data.actions['Pouncer_Windup']
        scene.frame_set(25)
        bl.aim_camera(cam, (11, -14, 6.0), c)
        bl.render_to(scene, os.path.join(PREV, 'pouncer-windup.png'))
        rig.animation_data.action = bpy.data.actions['Pouncer_Attack']
        scene.frame_set(12)
        rig.location.z = 2.0  # lift the airborne pose for the preview only
        bl.avatar_block(pcol, (-6.5, 1.0, 0))
        bl.aim_camera(cam, (9, -19, 6.0), Vector((-1.8, 0, 2.8)))
        bl.render_to(scene, os.path.join(PREV, 'pouncer-attack-avatar-scale.png'))

    print('POUNCER_INFO', info)


main()

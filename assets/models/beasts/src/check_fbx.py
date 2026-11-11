"""Re-import every beast FBX into a clean headless scene and check it.

Run: blender -b --factory-startup --python check_fbx.py

Checks per file: armature and bone names (same set as the creature's rigged FBX, expected bone
count), skin weights (every skinned vertex fully weighted to existing bones), exactly one action
in each *_anim_*.fbx with the expected frame range, no action in the other files, object scale
1.0 and the mesh size in studs (1:1 with the build). Prints one line per file and a summary.
"""
import glob
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, '..'))

BONES = {'viper': 15, 'pouncer': 29, 'gargoyle': 20, 'mire': 15}
# expected (first, last) frame of each exported action
FRAMES = {
    'viper': {'idle': (1, 61), 'slither': (1, 37), 'windup': (1, 36), 'dash': (1, 17), 'crash': (1, 17),
              'recover': (1, 39)},
    'pouncer': {'idle': (1, 41), 'stalk': (1, 25), 'windup': (1, 40), 'leap': (1, 24), 'land': (1, 7),
                'recover': (1, 31)},
    'gargoyle': {'statue': (1, 30), 'awaken': (1, 49), 'takeoff': (1, 40), 'hover': (1, 25), 'cast': (1, 61),
                 'recoil': (1, 16), 'land': (1, 46)},
    'mire': {'glide': (1, 49), 'emerge': (1, 13), 'swipe': (1, 15), 'recover': (1, 40), 'sink': (1, 37)},
}


def clean():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def bbox(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        for v in me.vertices:
            p = o.matrix_world @ v.co
            for k in range(3):
                lo[k] = min(lo[k], p[k])
                hi[k] = max(hi[k], p[k])
        ev.to_mesh_clear()
    return hi - lo


def check(path, ref_bones):
    name = os.path.basename(path)
    beast = name.split('_')[0].split('.')[0]
    clean()
    bpy.ops.import_scene.fbx(filepath=path)
    arms = [o for o in bpy.data.objects if o.type == 'ARMATURE']
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    acts = list(bpy.data.actions)
    problems = []
    is_anim = '_anim_' in name
    rigged = is_anim or name == f'{beast}.fbx'
    scales = {tuple(round(s, 4) for s in o.scale) for o in arms + meshes}
    if any(abs(c - 1.0) > 1e-3 for s in scales for c in s):
        problems.append(f'object scale {sorted(scales)}')
    bones = []
    if rigged:
        if len(arms) != 1:
            problems.append(f'{len(arms)} armatures')
        else:
            bones = [b.name for b in arms[0].data.bones]
            if len(bones) != BONES[beast]:
                problems.append(f'{len(bones)} bones (want {BONES[beast]})')
            if ref_bones.get(beast) is not None and set(bones) != ref_bones[beast]:
                problems.append('bone names differ from the rigged FBX')
        bone_set = set(bones)
        for m in meshes:
            names = {g.index: g.name for g in m.vertex_groups}
            if not set(names.values()) <= bone_set:
                problems.append(f'{m.name}: groups not in rig {sorted(set(names.values()) - bone_set)}')
            bad = 0
            for v in m.data.vertices:
                w = sum(g.weight for g in v.groups if g.group in names)
                if abs(w - 1.0) > 0.02:
                    bad += 1
            if bad:
                problems.append(f'{m.name}: {bad} vertices not fully weighted')
            if not any(md.type == 'ARMATURE' for md in m.modifiers) and m.parent is None:
                problems.append(f'{m.name}: not bound to the armature')
    else:
        if arms:
            problems.append('unexpected armature')
        for m in meshes:
            if len(m.vertex_groups):
                problems.append(f'{m.name}: has vertex groups')
    act_info = ''
    if is_anim:
        short = name[:-4].split('_anim_')[1]
        if len(acts) != 1:
            problems.append(f'{len(acts)} actions (want 1)')
        if acts:
            fr = tuple(int(round(x)) for x in acts[0].frame_range)
            want = FRAMES[beast][short]
            span = fr[1] - fr[0]
            act_info = f'action {acts[0].name} frames {fr[0]}-{fr[1]} ({span / 30:.3f} s at 30 fps)'
            # the importer may shift the take's start frame; the length is what must match
            if span != want[1] - want[0]:
                problems.append(f'length {span} frames (want {want[1] - want[0]})')
    elif acts:
        problems.append(f'{len(acts)} unexpected actions')
    size = bbox(meshes) if meshes else Vector()
    tris = sum(sum(len(p.vertices) - 2 for p in m.data.polygons) for m in meshes)
    status = 'OK ' if not problems else 'FAIL'
    print(f'CHECK {status} {name:34s} bones={len(bones):2d} meshes={len(meshes)} tris={tris:5d} '
          f'size={size.x:.2f}x{size.y:.2f}x{size.z:.2f} {act_info} {"; ".join(problems)}')
    return beast, set(bones) if rigged else None, not problems


def main():
    files = sorted(glob.glob(os.path.join(OUT, '*.fbx')))
    ref = {}
    ok_all = True
    for b in BONES:
        p = os.path.join(OUT, f'{b}.fbx')
        if os.path.exists(p):
            _beast, bones, ok = check(p, {})
            ref[b] = bones
            ok_all &= ok
    count = 0
    for p in files:
        if os.path.basename(p) in {f'{b}.fbx' for b in BONES}:
            continue
        _b, _bones, ok = check(p, ref)
        ok_all &= ok
        count += 1
    missing = [f'{b}_anim_{s}.fbx' for b, d in FRAMES.items() for s in d
               if not os.path.exists(os.path.join(OUT, f'{b}_anim_{s}.fbx'))]
    print(f'CHECK_SUMMARY files={count + len(ref)} all_ok={ok_all and not missing} missing={missing}')


main()

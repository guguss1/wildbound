"""Shared animation helpers for the Wildbound beasts (headless Blender 5.x, 30 fps).

A pose is a dict {bone: [rx, ry, rz, lx, ly, lz]}: three rotations in degrees about the
bone's authoring axes (world X, Y, Z by default, applied X then Y then Z, expressed in the
bone's rest frame like beastkit.apply_pose) and a world-space offset in studs. Poses add,
scale and interpolate as plain numbers, so actions are written as key poses on a
Catmull-Rom spline plus procedural overlays (breathing, wing beats, gait cycles), then
baked to one key per frame.
"""
import math
import os
import tempfile

import bpy
import numpy as np
from mathutils import Quaternion, Vector

FPS = 30
WX, WY, WZ = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))


# --------------------------------------------------------------------------- pose maths

def ch(rx=0.0, ry=0.0, rz=0.0, loc=(0.0, 0.0, 0.0)):
    return [float(rx), float(ry), float(rz), float(loc[0]), float(loc[1]), float(loc[2])]


def norm(p):
    """Accept {bone: (rx, ry, rz) | (rx, ry, rz, lx, ly, lz) | list6} and return list6 values."""
    out = {}
    for b, v in p.items():
        v = list(v)
        if len(v) == 3:
            v += [0.0, 0.0, 0.0]
        out[b] = [float(x) for x in v]
    return out


def padd(*poses, weights=None):
    out = {}
    weights = weights or [1.0] * len(poses)
    for p, w in zip(poses, weights):
        for b, v in p.items():
            acc = out.setdefault(b, [0.0] * 6)
            for i in range(6):
                acc[i] += v[i] * w
    return out


def pscale(p, s):
    return {b: [x * s for x in v] for b, v in p.items()}


def plerp(a, b, t):
    return padd(a, b, weights=[1.0 - t, t])


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def ease_out(t):
    t = max(0.0, min(1.0, t))
    return 1 - (1 - t) ** 3


def ease_in(t):
    t = max(0.0, min(1.0, t))
    return t ** 3


def spline(keys, f, loop=False, tension=1.0):
    """keys: list of (frame, pose) or (frame, pose, 'hold'). Hermite spline per channel.

    Interior keys get Catmull-Rom tangents; end keys and 'hold' keys get zero tangents (a
    stop). With loop=True the first and last keys must be equal and their tangents wrap.
    """
    keys = [(k[0], norm(k[1]), len(k) > 2 and k[2] == 'hold') for k in keys]
    if f <= keys[0][0]:
        return {b: list(v) for b, v in keys[0][1].items()}
    if f >= keys[-1][0]:
        return {b: list(v) for b, v in keys[-1][1].items()}
    bones = set()
    for _f, p, _h in keys:
        bones.update(p)
    zero = [0.0] * 6
    n = len(keys)
    period = keys[-1][0] - keys[0][0]

    def val(i, b):
        return keys[i][1].get(b, zero)

    def tangent(i, b):
        if keys[i][2]:
            return zero
        if 0 < i < n - 1:
            pa, pb = val(i - 1, b), val(i + 1, b)
            dt = keys[i + 1][0] - keys[i - 1][0]
        elif loop and n > 2:
            pa, pb = val(n - 2, b), val(1, b)
            dt = (keys[n - 1][0] - keys[n - 2][0]) + (keys[1][0] - keys[0][0])
        else:
            return zero
        return [(pb[c] - pa[c]) / dt * tension for c in range(6)]

    i = 0
    while keys[i + 1][0] < f:
        i += 1
    t0, t1 = keys[i][0], keys[i + 1][0]
    h = t1 - t0
    s = (f - t0) / h
    h00 = 2 * s ** 3 - 3 * s ** 2 + 1
    h10 = s ** 3 - 2 * s ** 2 + s
    h01 = -2 * s ** 3 + 3 * s ** 2
    h11 = s ** 3 - s ** 2
    out = {}
    for b in bones:
        p0, p1 = val(i, b), val(i + 1, b)
        m0, m1 = tangent(i, b), tangent(i + 1, b)
        out[b] = [h00 * p0[c] + h10 * h * m0[c] + h01 * p1[c] + h11 * h * m1[c] for c in range(6)]
    _ = period
    return out


def wave(f, f0, period, phase=0.0):
    """sin wave in frames; phase in cycles."""
    return math.sin(2 * math.pi * ((f - f0) / period + phase))


# --------------------------------------------------------------------------- rig driver

class Rig:
    def __init__(self, arm, frames=None):
        self.arm = arm
        self.frames = frames or {}
        self.rest_inv = {b.name: b.matrix_local.to_3x3().inverted() for b in arm.data.bones}
        for pb in arm.pose.bones:
            pb.rotation_mode = 'QUATERNION'
        self._prev = {}

    def axes(self, b):
        return self.frames.get(b, (WX, WY, WZ))

    def apply(self, pose, update=True):
        for pb in self.arm.pose.bones:
            v = pose.get(pb.name)
            if v is None:
                pb.rotation_quaternion = Quaternion()
                pb.location = (0, 0, 0)
                continue
            inv = self.rest_inv[pb.name]
            q = Quaternion()
            for axis, deg in zip(self.axes(pb.name), v[:3]):
                if abs(deg) > 1e-7:
                    q = Quaternion((inv @ Vector(axis)).normalized(), math.radians(deg)) @ q
            pb.rotation_quaternion = q
            pb.location = inv @ Vector(v[3:6])
        if update:
            bpy.context.view_layer.update()

    def tail(self, bone):
        return self.arm.matrix_world @ self.arm.pose.bones[bone].tail

    def head(self, bone):
        return self.arm.matrix_world @ self.arm.pose.bones[bone].head

    def key_all(self, frame):
        for pb in self.arm.pose.bones:
            q = pb.rotation_quaternion.copy()
            prev = self._prev.get(pb.name)
            if prev is not None and prev.dot(q) < 0:
                q.negate()
                pb.rotation_quaternion = q
            self._prev[pb.name] = q
            pb.keyframe_insert('rotation_quaternion', frame=frame)
            pb.keyframe_insert('location', frame=frame)

    def bake(self, name, f0, f1, pose_fn, post=None, loop=False):
        """Bake pose_fn(frame) -> pose for every frame in [f0, f1]. post(frame, pose) may
        adjust the pose (ground contact) and must leave it applied."""
        ad = self.arm.animation_data or self.arm.animation_data_create()
        ad.action = None
        self._prev = {}
        for f in range(f0, f1 + 1):
            p = pose_fn(f)
            self.apply(p)
            if post is not None:
                post(f, p)
            self.key_all(f)
        act = ad.action
        act.name = name
        act.use_fake_user = True
        act.use_frame_range = True
        act.frame_start, act.frame_end = f0, f1
        act.use_cyclic = loop
        _linear(act)
        ad.action = None
        self.apply({})
        return act


def _linear(act):
    curves = []
    try:
        curves = list(act.fcurves)
    except AttributeError:
        pass
    if not curves:
        try:
            for layer in act.layers:
                for strip in layer.strips:
                    for bag in strip.channelbags:
                        curves += list(bag.fcurves)
        except AttributeError:
            pass
    for fc in curves:
        for kp in fc.keyframe_points:
            kp.interpolation = 'LINEAR'


def assign(arm, act, frame=None):
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = act
    if act is not None:
        try:
            if ad.action_slot is None and len(act.slots):
                ad.action_slot = act.slots[0]
        except AttributeError:
            pass
        if frame is None:
            frame = int(act.frame_range[0])
    bpy.context.scene.frame_set(frame or 1)
    bpy.context.view_layer.update()


# --------------------------------------------------------------------------- ground contact

class Ground:
    """Lowest point of a vertex subset of a skinned mesh (the parts that touch the ground)."""

    def __init__(self, mesh_obj, bones, min_weight=0.5):
        self.mesh = mesh_obj
        names = set(bones)
        gi = {g.index for g in mesh_obj.vertex_groups if g.name in names}
        self.idx = np.array([v.index for v in mesh_obj.data.vertices
                             if any(g.group in gi and g.weight >= min_weight for g in v.groups)], dtype=np.int64)

    def coords(self):
        dg = bpy.context.evaluated_depsgraph_get()
        ev = self.mesh.evaluated_get(dg)
        me = ev.to_mesh()
        co = np.empty(len(me.vertices) * 3, dtype=np.float64)
        me.vertices.foreach_get('co', co)
        ev.to_mesh_clear()
        co = co.reshape(-1, 3)
        mw = np.array(self.mesh.matrix_world)
        return co @ mw[:3, :3].T + mw[:3, 3]

    def min_z(self):
        return float(self.coords()[self.idx, 2].min())


def ground_root(rig, ground, pose, target=0.0, weight=1.0, root='Root'):
    """Shift the Root bone vertically so the contact subset's lowest point sits on target."""
    dz = (target - ground.min_z()) * weight
    if abs(dz) > 1e-5:
        v = pose.setdefault(root, [0.0] * 6)
        v[5] += dz
        rig.apply(pose)
    return dz


def plant_tips(rig, pose, chains, target=0.0, iters=6):
    """Plant chain tips on the ground by adjusting each chain's first bone's rx channel.

    chains: list of (driver_bone, tip_bone). Uses a secant solve on all chains at once.
    """
    for drv, _tip in chains:
        pose.setdefault(drv, [0.0] * 6)
    x0 = [pose[d][0] for d, _t in chains]
    rig.apply(pose)
    z0 = [rig.tail(t).z - target for _d, t in chains]
    x1 = [x + 2.0 for x in x0]
    for (d, _t), x in zip(chains, x1):
        pose[d][0] = x
    rig.apply(pose)
    z1 = [rig.tail(t).z - target for _d, t in chains]
    for _ in range(iters):
        nx = []
        for a, b, za, zb in zip(x0, x1, z0, z1):
            if abs(zb - za) < 1e-7:
                nx.append(b)
            else:
                nx.append(b - zb * (b - a) / (zb - za))
        x0, z0 = x1, z1
        x1 = [max(-80.0, min(80.0, x)) for x in nx]
        for (d, _t), x in zip(chains, x1):
            pose[d][0] = x
        rig.apply(pose)
        z1 = [rig.tail(t).z - target for _d, t in chains]
        if max(abs(z) for z in z1) < 1e-3:
            break
    return z1


# --------------------------------------------------------------------------- contact sheets

def contact_strip(scene, arm, act, path, count=6, tile=(420, 340), frames=None, before=None):
    """Render `count` evenly spaced frames of act and join them into one PNG strip."""
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    frames = frames or [round(f0 + (f1 - f0) * i / (count - 1)) for i in range(count)]
    r = scene.render
    old = (r.resolution_x, r.resolution_y, r.filepath)
    r.resolution_x, r.resolution_y = tile
    tiles = []
    tmpdir = tempfile.mkdtemp(prefix='beaststrip_')
    for i, f in enumerate(frames):
        assign(arm, act, f)
        if before:
            before(f)
        p = os.path.join(tmpdir, f'f{i}.png')
        r.filepath = p
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(p)
        w, h = img.size
        a = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
        # timeline bar: where this frame sits in the clip
        bar = a[0:6]
        bar[...] = (0.12, 0.12, 0.14, 1)
        x = int((w - 1) * (f - f0) / max(1, f1 - f0))
        bar[:, :x + 1] = (0.85, 0.55, 0.2, 1)
        tiles.append(a)
        bpy.data.images.remove(img)
        os.remove(p)
    os.rmdir(tmpdir)
    gap = np.zeros((tile[1], 4, 4), dtype=np.float32)
    gap[..., 3] = 1
    row = []
    for t in tiles:
        row += [t, gap]
    out = np.concatenate(row[:-1], axis=1)
    img = bpy.data.images.new(os.path.basename(path), out.shape[1], out.shape[0])
    img.pixels.foreach_set(out.ravel())
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    bpy.data.images.remove(img)
    r.resolution_x, r.resolution_y, r.filepath = old
    assign(arm, None, 1)
    for pb in arm.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = (0, 0, 0)
    bpy.context.view_layer.update()
    return frames


def anchor(rig, pose, bone, target, facing=None, root='Root', use_tail=False):
    """Move (and optionally yaw) the Root so `bone`'s head lands on target (x, y).

    facing: desired horizontal direction (x, y) of the bone, or None to keep the yaw.
    """
    v = pose.setdefault(root, [0.0] * 6)
    v[3], v[4] = 0.0, 0.0
    rig.apply(pose)
    h = rig.tail(bone) if use_tail else rig.head(bone)
    if facing is not None:
        d = rig.tail(bone) - rig.head(bone)
        cur = math.atan2(d.y, d.x)
        want = math.atan2(facing[1], facing[0])
        dpsi = want - cur
        while dpsi > math.pi:
            dpsi -= 2 * math.pi
        while dpsi < -math.pi:
            dpsi += 2 * math.pi
        v[2] += math.degrees(dpsi)
        c, s = math.cos(dpsi), math.sin(dpsi)
        h = Vector((c * h.x - s * h.y, s * h.x + c * h.y, h.z))
    v[3], v[4] = target[0] - h.x, target[1] - h.y
    rig.apply(pose)
    return pose


def ground_report(arm, act, ground, frames=None):
    """Per-action ground check: lowest vertex overall and the contact subset's range."""
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    lo_all, lo_c, hi_c = 1e9, 1e9, -1e9
    for f in (frames or range(f0, f1 + 1)):
        assign(arm, act, f)
        co = ground.coords()
        lo_all = min(lo_all, float(co[:, 2].min()))
        c = float(co[ground.idx, 2].min())
        lo_c, hi_c = min(lo_c, c), max(hi_c, c)
    assign(arm, None, 1)
    return {'min_z_all': round(lo_all, 3), 'contact_min_z': (round(lo_c, 3), round(hi_c, 3))}

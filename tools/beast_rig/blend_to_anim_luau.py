"""Bake a beast .blend's armature actions into a WildboundBeastAnim<Beast> Luau data module.

Run inside Blender 5.x (there is no system Python here):

    blender --background assets/models/beasts/viper.blend --python tools/beast_rig/blend_to_anim_luau.py -- \
        --out src/wildbound/WildboundBeastAnimViper.luau [--beast Viper] [--source assets/models/beasts/viper.blend]

The module has the same format as the wave-2 modules (WildboundBeastAnimGaze/Root/Streamer/Lurker) and unpacks itself
into the shape WildboundLumipolRig reads (data.restPos, data.parents, data.actions[clip] = { length, keys = { t, p } }):

  BONES   armature bones in Blender order (parents first), named as in Blender (the FBX import keeps the names).
  PARENT  1-based parent index per bone, 0 for a root bone.
  REST    each bone's rest frame in its parent's rest frame (tx, ty, tz, qw, qx, qy, qz), 4 decimals.
  PACKED  per clip: length (s), key times (s), the animated bones (index, then 1 if it also translates) and per key a
          string with 2 base-64 characters per value: the bone's local pose (matrix_basis) quaternion x, y, z (w >= 0 is
          rebuilt by the unpacker, range +-1) and, for translating bones, its location x, y, z (range +-12 studs).

Every frame of an action is sampled (the beasts bake one key per frame) and keys a straight line between their kept
neighbours already reproduces are dropped (KEY_TOL_ROT / KEY_TOL_LOC). Bones that never leave their rest pose in a
clip are left out of that clip (the unpacker poses them at rest). Prints byte length and Adler-32 of the module
(LF line endings, trailing newlines stripped).
"""
import math
import os
import sys
import zlib

import bpy
from mathutils import Matrix

# Action name -> clip name (PascalCase, the names WildboundBeastAnimPlan uses), per beast.
CLIP_NAMES = {
    "Viper": {
        "Viper_Idle": "Idle",
        "Viper_Slither": "Slither",
        "Viper_Windup": "Windup",
        "Viper_Dash": "Dash",
        "Viper_Crash": "Crash",
        "Viper_Recover": "Recover",
    },
    "Pouncer": {
        "Pouncer_Idle": "Idle",
        "Pouncer_Stalk": "Stalk",
        "Pouncer_Windup": "Windup",
        "Pouncer_Leap": "Leap",
        "Pouncer_Land": "Land",
        "Pouncer_Recover": "Recover",
        "Pouncer_Throw": "Throw",  # BR2: the tarantula's web throw (pouncer_tarantula.blend only)
    },
}

ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
MAXQ = 4095
T_RANGE = 12.0
KEY_TOL_ROT = 0.0015  # quaternion component error allowed when dropping a key (~0.17 degrees)
KEY_TOL_LOC = 0.006  # studs (about one quantisation step of the location range)
REST_EPS_ROT = 0.0005  # below this every frame, a bone does not rotate in the clip
REST_EPS_LOC = 0.003  # below this every frame, a bone does not translate in the clip

TOOL = "tools/beast_rig/blend_to_anim_luau.py"
REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

# The unpacker shared by every WildboundBeastAnim<Beast> module (verbatim).
TRAILER = """local ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local VALUE = {}
for i = 1, #ALPHA do VALUE[string.byte(ALPHA, i)] = i - 1 end
local MAXQ = 4095
local T_RANGE = 12
local function dec(s, at, range)
\treturn (VALUE[string.byte(s, at)] * 64 + VALUE[string.byte(s, at + 1)]) / MAXQ * 2 * range - range
end
local function quat(x, y, z)
\treturn math.sqrt(math.max(0, 1 - x * x - y * y - z * z))
end
-- Armature-space rest frames.
local restLocal, restWorld = {}, {}
for i, v in ipairs(REST) do
\trestLocal[i] = CFrame.new(v[1], v[2], v[3], v[5], v[6], v[7], v[4])
\trestWorld[i] = (PARENT[i] > 0 and restWorld[PARENT[i]] or CFrame.identity) * restLocal[i]
\tlocal p = restWorld[i].Position
\tdata.restPos[BONES[i]] = { p.X, p.Y, p.Z }
\tdata.parents[BONES[i]] = PARENT[i] > 0 and BONES[PARENT[i]] or false
end
local function pack(cf)
\tlocal axis, angle = cf:ToAxisAngle()
\tlocal s = math.sin(angle / 2)
\tlocal p = cf.Position
\treturn { p.X, p.Y, p.Z, math.cos(angle / 2), axis.X * s, axis.Y * s, axis.Z * s }
end
for name, packed in pairs(PACKED) do
\tlocal keys = {}
\tfor k, s in ipairs(packed.keys) do
\t\tlocal localPose, at = {}, 1
\t\tfor b = 1, #packed.bones, 2 do
\t\t\tlocal bone, moves = packed.bones[b], packed.bones[b + 1] == 1
\t\t\tlocal qx, qy, qz = dec(s, at, 1), dec(s, at + 2, 1), dec(s, at + 4, 1)
\t\t\tat += 6
\t\t\tlocal tx, ty, tz = 0, 0, 0
\t\t\tif moves then
\t\t\t\ttx, ty, tz = dec(s, at, T_RANGE), dec(s, at + 2, T_RANGE), dec(s, at + 4, T_RANGE)
\t\t\t\tat += 6
\t\t\tend
\t\t\tlocalPose[bone] = CFrame.new(tx, ty, tz, qx, qy, qz, quat(qx, qy, qz))
\t\tend
\t\tlocal world, p = {}, {}
\t\tfor i = 1, #BONES do
\t\t\tworld[i] = (PARENT[i] > 0 and world[PARENT[i]] or CFrame.identity) * restLocal[i] * (localPose[i] or CFrame.identity)
\t\t\tp[BONES[i]] = pack(world[i] * restWorld[i]:Inverse())
\t\tend
\t\tkeys[k] = { t = packed.times[k], p = p }
\tend
\tdata.actions[name] = { length = packed.length, keys = keys }
end
return data
"""


def fmt(x):
    s = "%.4f" % x
    if "." in s:
        s = s.rstrip("0").rstrip(".")
    if s in ("-0", ""):
        s = "0"
    return s


def enc(v, rng):
    q = int(math.floor((v + rng) / (2 * rng) * MAXQ + 0.5))
    q = max(0, min(MAXQ, q))
    return ALPHA[q // 64] + ALPHA[q % 64]


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = {"out": None, "beast": None, "source": None}
    i = 0
    while i < len(argv):
        key = argv[i].lstrip("-")
        if key in args and i + 1 < len(argv):
            args[key] = argv[i + 1]
            i += 2
        else:
            raise SystemExit("unknown argument: %s" % argv[i])
    if not args["out"]:
        raise SystemExit("--out <module.luau> is required")
    return args


def find_armature():
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    if not arms:
        raise SystemExit("no armature in " + bpy.data.filepath)
    arms.sort(key=lambda o: -len(o.data.bones))
    return arms[0]


def bone_order(arm):
    bones = list(arm.data.bones)
    names = [b.name for b in bones]
    if all(b.parent is None or names.index(b.parent.name) < i for i, b in enumerate(bones)):
        return bones
    out = []
    def walk(b):
        out.append(b)
        for c in b.children:
            walk(c)
    for b in bones:
        if b.parent is None:
            walk(b)
    return out


def source_height(arm):
    lo, hi = math.inf, -math.inf
    for o in bpy.data.objects:
        if o.type != "MESH" or o.parent != arm:
            continue
        mw = o.matrix_world
        for v in o.data.vertices:
            z = (mw @ v.co).z
            lo, hi = min(lo, z), max(hi, z)
    if lo == math.inf:
        return 0.0
    return hi - lo


def assign(arm, act):
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = act
    try:
        if ad.action_slot is None and len(act.slots):
            ad.action_slot = act.slots[0]
    except AttributeError:
        pass


def sample_action(arm, act, order):
    """Per frame: {bone: (qx, qy, qz, qw, lx, ly, lz)} of matrix_basis, quaternion with w >= 0."""
    assign(arm, act)
    f0, f1 = int(round(act.frame_range[0])), int(round(act.frame_range[1]))
    scene = bpy.context.scene
    frames = []
    for f in range(f0, f1 + 1):
        scene.frame_set(f)
        pose = {}
        for b in order:
            pb = arm.pose.bones[b.name]
            loc, rot, _scale = pb.matrix_basis.decompose()
            rot.normalize()
            if rot.w < 0:
                rot.negate()
            pose[b.name] = (rot.x, rot.y, rot.z, rot.w, loc.x, loc.y, loc.z)
        frames.append(pose)
    arm.animation_data.action = None
    return f0, f1, frames


def reduce_keys(frames, bones):
    """Indices of the frames to keep: first, last and every frame a straight line cannot reproduce."""
    n = len(frames)
    if n <= 2:
        return list(range(n))

    def fits(a, b):
        for k in range(a + 1, b):
            t = (k - a) / (b - a)
            for name in bones:
                va, vb, vk = frames[a][name], frames[b][name], frames[k][name]
                sign = 1.0 if sum(va[i] * vb[i] for i in range(4)) >= 0 else -1.0
                for i in range(7):
                    lerp = va[i] + ((vb[i] * sign if i < 4 else vb[i]) - va[i]) * t
                    if abs(lerp - vk[i]) > (KEY_TOL_ROT if i < 4 else KEY_TOL_LOC):
                        return False
        return True

    keep = [0]
    a = 0
    while a < n - 1:
        b = a + 1
        while b + 1 < n and fits(a, b + 1):
            b += 1
        keep.append(b)
        a = b
    return keep


def build(arm, beast, source_rel):
    order = bone_order(arm)
    names = [b.name for b in order]
    index = {n: i + 1 for i, n in enumerate(names)}
    parent = [index[b.parent.name] if b.parent else 0 for b in order]
    rest = []
    for b in order:
        m = b.matrix_local if b.parent is None else b.parent.matrix_local.inverted() @ b.matrix_local
        t = m.to_translation()
        q = m.to_quaternion()
        rest.append((t.x, t.y, t.z, q.w, q.x, q.y, q.z))

    mapping = CLIP_NAMES.get(beast, {})
    clips = []
    for act in bpy.data.actions:
        clip = mapping.get(act.name)
        if clip is None:
            print("skip action %s (no clip name for %s)" % (act.name, beast))
            continue
        f0, f1, frames = sample_action(arm, act, order)
        fps = bpy.context.scene.render.fps / bpy.context.scene.render.fps_base
        animated = []
        for n in names:
            rot = any(abs(fr[n][i]) > REST_EPS_ROT for fr in frames for i in range(3))
            mov = any(abs(fr[n][i]) > REST_EPS_LOC for fr in frames for i in range(4, 7))
            if mov:
                peak = max(abs(fr[n][i]) for fr in frames for i in range(4, 7))
                if peak > T_RANGE:
                    raise SystemExit("%s %s translates %.3f studs, past the +-%d range" % (act.name, n, peak, T_RANGE))
            if rot or mov:
                animated.append((n, mov))
        keep = reduce_keys(frames, [n for n, _ in animated])
        times = [(k) / fps for k in keep]
        keys = []
        for k in keep:
            s = []
            for n, mov in animated:
                v = frames[k][n]
                s += [enc(v[0], 1), enc(v[1], 1), enc(v[2], 1)]
                if mov:
                    s += [enc(v[4], T_RANGE), enc(v[5], T_RANGE), enc(v[6], T_RANGE)]
            keys.append("".join(s))
        clips.append({"name": clip, "action": act.name, "length": (f1 - f0) / fps, "times": times,
                      "bones": [(index[n], 1 if mov else 0) for n, mov in animated], "keys": keys,
                      "frames": len(frames)})
    missing = sorted(set(mapping.values()) - {c["name"] for c in clips})
    if missing:
        raise SystemExit("actions missing for clips: " + ", ".join(missing))
    clips.sort(key=lambda c: c["name"])

    ver = "%d.%d" % (bpy.app.version[0], bpy.app.version[1])
    L = []
    L.append("-- GENERATED by %s from %s (Blender %s): do not edit." % (TOOL, source_rel, ver))
    L.append("-- %s rig animation data, same shape as WildboundLumipolAnimData once unpacked (WildboundLumipolRig reads it)." % beast)
    L.append("-- Blender armature space: Z up, front -Y, 1 unit = 1 stud. Per action: key times, the animated bones (index into")
    L.append("-- BONES, then 1 if it also translates) and per key 2 base-64 characters per value (local quaternion xyz, then")
    L.append("-- translation xyz for translating bones); the unpacker chains the local poses into armature-space deltas.")
    L.append("local BONES = {" + ", ".join('"%s"' % n for n in names) + "}")
    L.append("local PARENT = {" + ", ".join(str(p) for p in parent) + "}")
    L.append("-- Rest frame per bone in its parent's space: tx, ty, tz, qw, qx, qy, qz.")
    L.append("local REST = {")
    for r in rest:
        L.append("\t{" + ", ".join(fmt(x) for x in r) + "},")
    L.append("}")
    L.append("local PACKED = {")
    for c in clips:
        L.append("\t%s = { length = %s, times = {%s}," % (c["name"], fmt(c["length"]), ", ".join(fmt(t) for t in c["times"])))
        L.append("\t\tbones = {%s}," % ", ".join("%d, %d" % b for b in c["bones"]))
        L.append("\t\tkeys = {")
        for k in c["keys"]:
            L.append('\t\t\t"%s",' % k)
        L.append("\t\t} },")
    L.append("}")
    L.append('local data = { beast = "%s", fps = %s, sourceHeight = %s, restPos = {}, parents = {}, actions = {} }'
             % (beast, fmt(bpy.context.scene.render.fps / bpy.context.scene.render.fps_base), fmt(source_height(arm))))
    text = "\n".join(L) + "\n" + TRAILER
    return text, names, clips


def main():
    args = parse_args()
    arm = find_armature()
    beast = args["beast"] or arm.name.split("_")[0].capitalize()
    blend = os.path.abspath(bpy.data.filepath)
    source = args["source"]
    if not source:
        try:
            source = os.path.relpath(blend, REPO)
        except ValueError:
            source = blend
        if source.startswith(".."):
            source = blend
    source = source.replace("\\", "/")
    text, names, clips = build(arm, beast, source)
    out = os.path.abspath(args["out"])
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)
    body = text.replace("\r\n", "\n").rstrip("\n").encode("utf-8")
    print("BEAST %s armature %s: %d bones: %s" % (beast, arm.name, len(names), ", ".join(names)))
    for c in clips:
        print("CLIP %s <- %s: length %s s, %d frames -> %d keys, %d animated bones (%d translate)"
              % (c["name"], c["action"], fmt(c["length"]), c["frames"], len(c["times"]), len(c["bones"]),
                 sum(m for _, m in c["bones"])))
    print("WROTE %s bytes %d adler32 %08x" % (out, len(body), zlib.adler32(body) & 0xFFFFFFFF))


if __name__ == "__main__":
    main()

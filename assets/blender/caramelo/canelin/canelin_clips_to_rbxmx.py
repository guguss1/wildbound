"""Writes Canelin's clips (canelin-clips.json) as one KeyframeSequence .rbxmx each.

Adapter for the JSON layout { clip: { length, loop, priority, easing?, keys: [ { t, pose } ] } }, using the pose maths
of tortidragon/clips_to_rbxmx.py (pose = rest^-1 * (T * Rx * Ry * Rz) * rest, data in Roblox model axes). Differences:
- the clip data is read from the JSON, not ported into this file;
- the optional clip field "easing" is honoured: "Linear" writes PoseEasingStyle.Linear (Spin and Charge need it, the
  default Cubic/InOut stops at every 90 degree key); anything else writes Cubic/InOut like the template;
- bone rest rotations and the bone tree come from canelin-rest.json. build_canelin.py writes a PREDICTION of them;
  after the FBX is imported, replace "rest" with pivot:ToObjectSpace(bone.WorldCFrame).Rotation read from Studio
  (9 numbers, row-major) and "tree" with the GetChildren order, then run this again.

No system Python on this PC, so run it inside Blender (it does not use bpy):
    blender --background --python canelin_clips_to_rbxmx.py -- <out_dir>
Default out_dir: ./rbxmx next to this file. It prints the checksum defined in the template's docstring.
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SLUG = "canelin"
STYLE = {"Linear": (0, 0), "Cubic": (3, 2)}  # (PoseEasingStyle, PoseEasingDirection); Cubic goes with InOut
PRIORITY = {"Idle": 0, "Movement": 1, "Action": 2}
IDENTITY = [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]

with open(os.path.join(HERE, SLUG + "-clips.json"), encoding="utf-8") as f:
    CLIPS = json.load(f)
with open(os.path.join(HERE, SLUG + "-rest.json"), encoding="utf-8") as f:
    _rest = json.load(f)
REST, TREE = _rest["rest"], [tuple(t) for t in _rest["tree"]]
ORDER = list(CLIPS)


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def transpose(a):
    return [[a[j][i] for j in range(3)] for i in range(3)]


def angles(rx, ry, rz):  # CFrame.Angles = Rx * Ry * Rz
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    return mul(mul([[1, 0, 0], [0, cx, -sx], [0, sx, cx]], [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]),
               [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])


def pose_cframe(bone, v):
    if v is None:
        return list(IDENTITY)
    v = list(v) + [0] * (6 - len(v))
    r = REST[bone]
    rest = [r[0:3], r[3:6], r[6:9]]
    rt = transpose(rest)
    p = [sum(rt[i][k] * v[k] for k in range(3)) for i in range(3)]
    m = mul(mul(rt, angles(math.radians(v[3]), math.radians(v[4]), math.radians(v[5]))), rest)
    return p + m[0] + m[1] + m[2]


def fmt(x):
    s = repr(float(x))
    return "0" if s in ("-0.0", "0.0") else s


_ref = [0]


def ref():
    _ref[0] += 1
    return "RBX%032X" % _ref[0]


def pose_xml(name, cf, weight, style, inner, ind):
    t = "\t" * ind
    comps = "".join("<%s>%s</%s>" % (k, fmt(c), k) for k, c in zip(
        ["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"], cf))
    return (t + '<Item class="Pose" referent="%s">\n' % ref() + t + "\t<Properties>\n"
            + t + '\t\t<CoordinateFrame name="CFrame">%s</CoordinateFrame>\n' % comps
            + t + '\t\t<token name="EasingDirection">%d</token>\n' % style[1]
            + t + '\t\t<token name="EasingStyle">%d</token>\n' % style[0]
            + t + '\t\t<float name="Weight">%s</float>\n' % fmt(weight)
            + t + '\t\t<string name="Name">%s</string>\n' % name + t + "\t</Properties>\n" + inner + t + "</Item>\n")


def build(name):
    clip = CLIPS[name]
    style = STYLE.get(clip.get("easing", "Cubic"), STYLE["Cubic"])
    ci = ORDER.index(name) + 1
    total = [0.0]

    def account(cf):
        for i, c in enumerate(cf, start=1):
            total[0] += c * ((i % 5) + 1) * ci

    def tree(parent, pose, ind):
        out = ""
        for bone in [b for b, p in TREE if p == parent]:
            cf = pose_cframe(bone, pose.get(bone))
            account(cf)
            out += pose_xml(bone, cf, 1, style, tree(bone, pose, ind + 1), ind)
        return out

    frames = ""
    for k in clip["keys"]:
        account(IDENTITY)
        inner = pose_xml("RootPart", IDENTITY, 0, (0, 0), tree("RootPart", k["pose"], 4), 3)
        frames += ('\t\t<Item class="Keyframe" referent="%s">\n\t\t\t<Properties>\n\t\t\t\t<float name="Time">%s</float>\n'
                   '\t\t\t\t<string name="Name">Keyframe</string>\n\t\t\t</Properties>\n%s\t\t</Item>\n') % (ref(), fmt(k["t"]), inner)
    xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
           '\t<Item class="KeyframeSequence" referent="%s">\n\t\t<Properties>\n\t\t\t<bool name="Loop">%s</bool>\n'
           '\t\t\t<token name="Priority">%d</token>\n\t\t\t<string name="Name">%s</string>\n\t\t</Properties>\n%s\t</Item>\n</roblox>\n'
           ) % (ref(), "true" if clip["loop"] else "false", PRIORITY[clip["priority"]], name, frames)
    return xml, total[0]


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_dir = args[0] if args else os.path.join(HERE, "rbxmx")
    os.makedirs(out_dir, exist_ok=True)
    checksum, poses = 0.0, 0
    for name in ORDER:
        xml, part = build(name)
        checksum += part
        poses += xml.count('class="Pose"')
        with open(os.path.join(out_dir, "%s-%s.rbxmx" % (SLUG, name)), "w", encoding="utf-8", newline="\n") as f:
            f.write(xml)
    print("rest source: %s" % _rest.get("source"))
    print("checksum %.6f poses %d clips %d" % (checksum, poses, len(ORDER)))

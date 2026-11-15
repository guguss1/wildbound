"""Writes Tortidragon's eleven clips as one KeyframeSequence .rbxmx each, for the Animation asset upload (CA2).

The game's source of truth is tools/WildboundCandyTortidragonClips.luau (Clips.build in Studio). Studio cannot write
files, so this script mirrors that module: the same clip data (ported line by line) and the same pose maths, with the
prefab's bone rest rotations (pivot:ToObjectSpace(bone.WorldCFrame).Rotation, read from Studio) in REST. It prints a
checksum computed exactly like the Studio check below; the export is valid only when the two match (to float32 noise).

Studio check (Edit, read-only):
    total = sum over clips ci (ORDER index) and every Pose p of Clips.build(prefab, name):
            sum_{i=1..12} p.CFrame component i * ((i % 5) + 1) * ci

Run:  python -I -B clips_to_rbxmx.py <out_dir>
"""
import math
import os
import sys

REST = {
    "Root": [1, 0, 0, 0, 1, -0.0000002, 0, 0.0000002, 1],
    "Pelvis": [1, 0, 0, 0, 0.0766965, 0.9970545, 0, -0.9970545, 0.0766965],
    "Spine": [1, 0, 0, 0, 0.1483407, 0.9889364, 0, -0.9889364, 0.1483407],
    "Neck_01": [1, 0, 0, 0, 0.9333457, 0.3589790, 0, -0.3589790, 0.9333457],
    "Neck_02": [1, 0, 0, 0, 0.9486834, 0.3162278, 0, -0.3162278, 0.9486834],
    "Head": [1, 0, 0, 0, 0.2576629, 0.9662350, 0, -0.9662350, 0.2576629],
    "Jaw": [1, 0, 0, 0, -0.0766963, 0.9970548, 0, -0.9970548, -0.0766963],
    "Strawberry_L": [0.9296995, -0.2740755, -0.2460517, 0.2460515, 0.9592645, -0.1388197, 0.2740756, 0.0685192, 0.9592643],
    "Strawberry_R": [0.9296995, 0.2740755, 0.2460517, -0.2460515, 0.9592645, -0.1388197, -0.2740756, 0.0685192, 0.9592643],
    "Cheek_L": [0.2524520, -0.9630870, -0.0934433, 0.0934426, 0.1203855, -0.9883200, 0.9630872, 0.2407717, 0.1203849],
    "Cheek_R": [0.2524520, 0.9630870, 0.0934433, -0.0934426, 0.1203855, -0.9883200, -0.9630872, 0.2407717, 0.1203849],
    "CreamCrest": [1, 0, 0, 0, 0.9938838, -0.1104316, 0, 0.1104316, 0.9938838],
    "Strawberry_Back": [1, 0, 0, 0, 0.9987525, -0.0499378, 0, 0.0499378, 0.9987525],
    "FrontLeg_L_Upper": [1, 0, 0, 0, -1.0000002, 0.0000001, 0, -0.0000001, -1.0000002],
    "FrontLeg_L_Lower": [1, 0, 0, 0, -0.9974590, 0.0712472, 0, -0.0712472, -0.9974590],
    "FrontLeg_R_Upper": [1, 0, 0, 0, -1.0000002, 0.0000001, 0, -0.0000001, -1.0000002],
    "FrontLeg_R_Lower": [1, 0, 0, 0, -0.9974590, 0.0712472, 0, -0.0712472, -0.9974590],
    "BackLeg_L_Upper": [1, 0, 0, 0, -0.9974588, -0.0712470, 0, 0.0712470, -0.9974588],
    "BackLeg_L_Lower": [1, 0, 0, 0, -0.9974588, 0.0712473, 0, -0.0712473, -0.9974588],
    "BackLeg_R_Upper": [1, 0, 0, 0, -0.9974588, -0.0712470, 0, 0.0712470, -0.9974588],
    "BackLeg_R_Lower": [1, 0, 0, 0, -0.9974588, 0.0712473, 0, -0.0712473, -0.9974588],
    "Tail_01": [1, 0, 0, 0, 0.6246948, -0.7808691, 0, 0.7808691, 0.6246948],
    "Tail_02": [1, 0, 0, 0, 0.8778957, -0.4788522, 0, 0.4788522, 0.8778957],
    "Tail_03": [1, 0, 0, 0, 0.9397936, 0.3417430, 0, -0.3417430, 0.9397936],
}
# The bone tree in GetChildren order as Studio reports it (RootPart > Root > ...).
TREE = [("Root", "RootPart"), ("Pelvis", "Root"), ("Spine", "Pelvis"), ("Neck_01", "Spine"), ("Neck_02", "Neck_01"),
        ("Head", "Neck_02"), ("Jaw", "Head"), ("Strawberry_L", "Head"), ("Strawberry_R", "Head"), ("Cheek_L", "Head"),
        ("Cheek_R", "Head"), ("CreamCrest", "Head"), ("Strawberry_Back", "Spine"), ("FrontLeg_L_Upper", "Spine"),
        ("FrontLeg_L_Lower", "FrontLeg_L_Upper"), ("FrontLeg_R_Upper", "Spine"), ("FrontLeg_R_Lower", "FrontLeg_R_Upper"),
        ("BackLeg_L_Upper", "Pelvis"), ("BackLeg_L_Lower", "BackLeg_L_Upper"), ("BackLeg_R_Upper", "Pelvis"),
        ("BackLeg_R_Lower", "BackLeg_R_Upper"), ("Tail_01", "Pelvis"), ("Tail_02", "Tail_01"), ("Tail_03", "Tail_02")]
EASING_STYLE_CUBIC, EASING_DIRECTION_INOUT = 3, 2  # Enum values read from Studio
PRIORITY = {"Idle": 0, "Movement": 1, "Action": 2}


# ---- the clip data, ported from tools/WildboundCandyTortidragonClips.luau ----
def merge(*poses):
    out = {}
    for pose in poses:
        for bone, v in pose.items():
            s = out.setdefault(bone, [0.0] * 6)
            for i in range(6):
                s[i] += v[i] if i < len(v) else 0
    return out


UPPER = ["FrontLeg_L_Upper", "FrontLeg_R_Upper", "BackLeg_L_Upper", "BackLeg_R_Upper"]


def body(dy, pitch=0, roll=0):
    pose = {"Pelvis": [0, dy, 0, pitch, 0, roll]}
    for name in UPPER:
        pose[name] = [0, -dy, 0]
    return pose


def legs(fl, fr, bl, br, bend=0):
    def lower(swing):
        return -bend if swing > 0 else 0
    return {"FrontLeg_L_Upper": [0, 0, 0, fl], "FrontLeg_R_Upper": [0, 0, 0, fr], "BackLeg_L_Upper": [0, 0, 0, bl],
            "BackLeg_R_Upper": [0, 0, 0, br], "FrontLeg_L_Lower": [0, 0, 0, lower(fl)], "FrontLeg_R_Lower": [0, 0, 0, lower(fr)],
            "BackLeg_L_Lower": [0, 0, 0, lower(bl)], "BackLeg_R_Lower": [0, 0, 0, lower(br)]}


def neck(pitch, yaw):
    return {"Neck_01": [0, 0, 0, pitch * 0.5, yaw * 0.4, 0], "Neck_02": [0, 0, 0, pitch * 0.5, yaw * 0.6, 0]}


def head(pitch=0, yaw=0, roll=0):
    return {"Head": [0, 0, 0, pitch, yaw, roll]}


def jaw(degrees):
    return {"Jaw": [0, 0, 0, -degrees, 0, 0]}


def cheeks(a):
    return {"Cheek_L": [-0.35 * a, 0, 0], "Cheek_R": [0.35 * a, 0, 0]}


def tail(yaw, lift=0):
    return {"Tail_01": [0, 0, 0, lift * 0.4, yaw * 0.4, 0], "Tail_02": [0, 0, 0, lift * 0.3, yaw * 0.35, 0],
            "Tail_03": [0, 0, 0, lift * 0.3, yaw * 0.25, 0]}


def wobble(roll, bob=0):
    return {"CreamCrest": [0, bob, 0, 0, 0, roll], "Strawberry_L": [0, bob * 0.5, 0, 0, 0, roll * 0.7],
            "Strawberry_R": [0, bob * 0.5, 0, 0, 0, roll * 0.7], "Strawberry_Back": [0, 0, 0, 0, 0, roll * 0.5]}


REST_POSE = {}
LIE = merge({"Pelvis": [0, -1.5, 0]}, {"FrontLeg_L_Upper": [0, 0.3, 0, 75], "FrontLeg_R_Upper": [0, 0.3, 0, 75],
            "FrontLeg_L_Lower": [0, 0, 0, -10], "FrontLeg_R_Lower": [0, 0, 0, -10], "BackLeg_L_Upper": [0, 0.2, 0, 60],
            "BackLeg_R_Upper": [0, 0.2, 0, 60], "BackLeg_L_Lower": [0, 0, 0, -110], "BackLeg_R_Lower": [0, 0, 0, -110]},
            neck(-10, 0), tail(30, -10))
AIM = merge(cheeks(1), neck(12, 0), head(8), body(-0.25, 3), legs(8, 8, -6, -6), tail(0, 18))
SPAT = merge(cheeks(0.1), neck(-12, 0), head(-14), jaw(28), body(-0.1, -3), legs(4, 4, -4, -4), tail(0, 25))

ORDER = ["Idle", "Walk_Quadruped", "Run_Quadruped", "Turn", "Alert", "Attack_Telegraph", "Attack_Release", "Attack_Recover",
         "HitReact", "FarmIdle", "HatchReact"]
CLIPS = {
    "Idle": (True, "Idle", {}, [(0, REST_POSE), (0.75, merge(body(0.08, 0), tail(12, 4), head(0, 10))),
             (1.5, merge(body(-0.04, 0), wobble(2))), (2.25, merge(body(0.08, 0), tail(-12, 4), head(0, -10))), (3.0, REST_POSE)]),
    "Walk_Quadruped": (True, "Movement", {}, [
        (0, merge(legs(18, -18, -18, 18, 20), body(0, 0))), (0.225, merge(legs(0, 0, 0, 0), body(0.12, 0), tail(6))),
        (0.45, merge(legs(-18, 18, 18, -18, 20), body(0, 0))), (0.675, merge(legs(0, 0, 0, 0), body(0.12, 0), tail(-6))),
        (0.9, merge(legs(18, -18, -18, 18, 20), body(0, 0)))]),
    "Run_Quadruped": (True, "Movement", {}, [
        (0, merge(legs(28, 24, -26, -22, 30), body(0, -5), neck(-6, 0), tail(0, 15))),
        (0.15, merge(legs(0, 4, 10, 14), body(0.35, 0), tail(0, 20), wobble(3, 0.05))),
        (0.3, merge(legs(-26, -22, 28, 24, 30), body(0, 5), neck(6, 0), tail(0, 12))),
        (0.45, merge(legs(4, 0, -10, -6), body(0.2, 0), tail(0, 18), wobble(-3))),
        (0.6, merge(legs(28, 24, -26, -22, 30), body(0, -5), neck(-6, 0), tail(0, 15)))]),
    "Turn": (False, "Movement", {}, [(0, REST_POSE), (0.2, merge(neck(0, 20), head(0, 15), body(0, 0, 6), tail(-20))),
             (0.35, merge(neck(0, 10), body(0, 0, 3), tail(-10))), (0.5, REST_POSE)]),
    "Alert": (False, "Action", {}, [(0, REST_POSE), (0.2, merge(neck(18, 0), head(10), wobble(8, 0.1), tail(0, 10))),
              (0.45, merge(neck(16, 0), head(6, 12), wobble(-5))), (0.75, merge(neck(14, 0), head(4)))]),
    "Attack_Telegraph": (False, "Action", {0: "TelegraphStart", 0.6: "AttackCommit"}, [
        (0, REST_POSE), (0.3, merge(cheeks(0.4), neck(5, 0), head(3), body(-0.1, 1), tail(0, 8))),
        (0.6, merge(cheeks(0.8), neck(10, 0), head(6), body(-0.2, 2), legs(6, 6, -4, -4), tail(0, 14))), (1.0, AIM)]),
    "Attack_Release": (False, "Action", {0: "HitFrame"}, [(0, AIM), (0.12, merge(SPAT, wobble(6))),
                       (0.35, merge(SPAT, wobble(-4), jaw(6))), (0.65, SPAT)]),
    "Attack_Recover": (False, "Action", {0: "RecoverStart", 0.85: "AttackEnd"}, [
        (0, SPAT), (0.2, merge(head(0, 0, 14), wobble(10), tail(0, 15))), (0.4, merge(head(0, 0, -12), wobble(-8), tail(0, 8))),
        (0.6, merge(head(0, 0, 6), wobble(4), tail(0, 3))), (0.85, REST_POSE)]),
    "HitReact": (False, "Action", {}, [(0, REST_POSE), (0.1, merge(body(-0.15, -4), head(-6, 18), wobble(10))),
                 (0.25, merge(head(0, -16), wobble(-8))), (0.4, merge(head(0, 8), wobble(4))), (0.5, REST_POSE)]),
    "FarmIdle": (True, "Idle", {}, [(0, LIE), (1.0, merge(LIE, tail(-25), {"Pelvis": [0, 0.05, 0]})),
                 (2.0, merge(LIE, head(-15, -20), jaw(10))), (2.5, merge(LIE, head(-12, -20), jaw(4))),
                 (3.0, merge(LIE, tail(-20))), (4.0, LIE)]),
    "HatchReact": (False, "Action", {}, [
        (0, merge(body(-0.8, 0), neck(-15, 0), cheeks(0.2))), (0.35, merge(body(0.3, 4), neck(15, 0), wobble(10, 0.15))),
        (0.7, merge(neck(18, 0), head(18), cheeks(0.6))), (0.9, merge(neck(-10, 0), head(-22), jaw(25), wobble(-8))),
        (1.3, merge(head(0, -25), tail(15))), (1.7, merge(head(0, 25), tail(-15))), (2.0, REST_POSE)]),
}


# ---- the pose maths of Clips.build ----
def mat(r):
    return [[r[0], r[1], r[2]], [r[3], r[4], r[5]], [r[6], r[7], r[8]]]


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def transpose(a):
    return [[a[j][i] for j in range(3)] for i in range(3)]


def angles(rx, ry, rz):  # CFrame.Angles = Rx * Ry * Rz
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    X = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    Y = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    Z = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]
    return mul(mul(X, Y), Z)


def pose_cframe(bone, v):
    """rest:Inverse() * (T(v) * R(v)) * rest, with rest a pure rotation: position rest^T p, rotation rest^T R rest."""
    if v is None:
        return [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]
    v = list(v) + [0] * (6 - len(v))
    rest = mat(REST[bone])
    rt = transpose(rest)
    p = [sum(rt[i][k] * v[k] for k in range(3)) for i in range(3)]
    r = mul(mul(rt, angles(math.radians(v[3]), math.radians(v[4]), math.radians(v[5]))), rest)
    return p + [r[0][0], r[0][1], r[0][2], r[1][0], r[1][1], r[1][2], r[2][0], r[2][1], r[2][2]]


def children(parent):
    return [b for b, p in TREE if p == parent]


def fmt(x):
    s = repr(float(x))
    return "0" if s in ("-0.0", "0.0") else s


def pose_xml(name, cf, weight, inner, ind):
    t = "\t" * ind
    comps = "".join("<%s>%s</%s>" % (k, fmt(c), k) for k, c in zip(
        ["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"], cf))
    return (t + '<Item class="Pose" referent="%s">\n' % ref() + t + "\t<Properties>\n"
            + t + '\t\t<CoordinateFrame name="CFrame">%s</CoordinateFrame>\n' % comps
            + t + '\t\t<token name="EasingDirection">%d</token>\n' % (EASING_DIRECTION_INOUT if name != "RootPart" else 0)
            + t + '\t\t<token name="EasingStyle">%d</token>\n' % (EASING_STYLE_CUBIC if name != "RootPart" else 0)
            + t + '\t\t<float name="Weight">%s</float>\n' % fmt(weight)
            + t + '\t\t<string name="Name">%s</string>\n' % name + t + "\t</Properties>\n" + inner + t + "</Item>\n")


_ref = [0]


def ref():
    _ref[0] += 1
    return "RBX%032X" % _ref[0]


def build(name):
    loop, priority, markers, keys = CLIPS[name]
    total = [0.0]
    ci = ORDER.index(name) + 1

    def account(cf):
        for i, c in enumerate(cf, start=1):
            total[0] += c * ((i % 5) + 1) * ci

    def tree(parent, pose, ind):
        out = ""
        for bone in children(parent):
            cf = pose_cframe(bone, pose.get(bone))
            account(cf)
            out += pose_xml(bone, cf, 1, tree(bone, pose, ind + 1), ind)
        return out

    frames = ""
    for time, pose in keys:
        base = [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]
        account(base)
        inner = pose_xml("RootPart", base, 0, tree("RootPart", pose, 4), 3)
        for mt, mname in markers.items():
            if abs(mt - time) < 1e-9:
                inner += ('\t\t\t<Item class="KeyframeMarker" referent="%s">\n\t\t\t\t<Properties>\n'
                          '\t\t\t\t\t<string name="Name">%s</string>\n\t\t\t\t\t<string name="Value"></string>\n'
                          '\t\t\t\t</Properties>\n\t\t\t</Item>\n') % (ref(), mname)
        frames += ('\t\t<Item class="Keyframe" referent="%s">\n\t\t\t<Properties>\n\t\t\t\t<float name="Time">%s</float>\n'
                   '\t\t\t\t<string name="Name">Keyframe</string>\n\t\t\t</Properties>\n%s\t\t</Item>\n') % (ref(), fmt(time), inner)
    xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
           '\t<Item class="KeyframeSequence" referent="%s">\n\t\t<Properties>\n\t\t\t<bool name="Loop">%s</bool>\n'
           '\t\t\t<token name="Priority">%d</token>\n\t\t\t<string name="Name">%s</string>\n\t\t</Properties>\n%s\t</Item>\n</roblox>\n'
           ) % (ref(), "true" if loop else "false", PRIORITY[priority], name, frames)
    return xml, total[0]


if __name__ == "__main__":
    out_dir = sys.argv[1]
    os.makedirs(out_dir, exist_ok=True)
    checksum, poses = 0.0, 0
    for name in ORDER:
        xml, part = build(name)
        checksum += part
        poses += xml.count('class="Pose"')
        with open(os.path.join(out_dir, "tortidragon-%s.rbxmx" % name), "w", encoding="utf-8", newline="\n") as f:
            f.write(xml)
    print("checksum %.6f poses %d" % (checksum, poses))

"""Pure, bounded, in-place pose profiles for the Wildbound guardian rigs.

No Blender here, so the profiles are unit-testable. tools/build-guardian-rigs.py converts
these values into bone-local keys through kit_common.key_clip, exactly as the species rigs do.
Root is never animated: no root motion, and the server body proxy owns gameplay.

Rotations are radians about the armature's X, Y and Z axes, applied in the bone's rest
frame. Offsets are studs along the same axes. Guardians face -Y with Z up, so a positive rx
pitches the nose down, and a positive rx on a limb that hangs below its joint swings the
lower end toward +Y (backward).

Two kinds of clip:
  loop   a static base pose plus terms (channel, amplitude, cycles, phase, mode), with
         mode "sin", "lift" (max(0, sin), only one way so feet never sink) or "rise"
         (0 to amplitude and back). pose(1) equals pose(0) exactly.
  keyed  key poses at fractions of the clip, joined by smoothstep. The last key is held
         exactly, so a clip can hand over to the next one with identical bone values.
Nothing here is validated in play.
"""

import math

FPS = 30
CHANNELS = ("rx", "ry", "rz", "lx", "ly", "lz")
MAX_ANGLE = 3.2  # a folded measuring rod turns through half a circle
MAX_OFFSET = 1.0
MODES = ("sin", "lift", "rise")

DURATIONS = {
    "Idle": 3.0, "Stalk": 2.0, "Sniff": 3.0, "Telegraph": 1.8, "Charge": 1.0, "Recover": 2.0,
}

YETI_BONES = ("Root", "Pelvis", "Spine", "Chest", "Neck", "Head",
              "UpperArm.L", "Forearm.L", "Hand.L", "UpperArm.R", "Forearm.R", "Hand.R",
              "Thigh.L", "Shin.L", "Foot.L", "Thigh.R", "Shin.R", "Foot.R")

BONES = {"GD_Yeti": YETI_BONES}
CLIPS = {"GD_Yeti": ("Idle", "Stalk", "Sniff", "Telegraph", "Charge", "Recover")}
LOOPS = {"GD_Yeti": ("Idle", "Stalk", "Sniff", "Charge")}


def frame_count(clip):
    """Frames 1 to N inclusive, so a loop's last frame repeats the first pose."""
    return round(DURATIONS[clip] * FPS) + 1


def euler_from_axis_angle(axis, angle):
    """Blender XYZ Euler (R = Rz @ Ry @ Rx) of a turn by `angle` about `axis`, for tilted hinges."""
    length = math.sqrt(sum(a * a for a in axis))
    x, y, z = (a / length for a in axis)
    c, s = math.cos(angle), math.sin(angle)
    t = 1.0 - c
    r20 = t * x * z - s * y
    r21 = t * y * z + s * x
    r22 = t * z * z + c
    r10 = t * x * y + s * z
    r00 = t * x * x + c
    ry = math.asin(max(-1.0, min(1.0, -r20)))
    if math.cos(ry) > 1e-6:
        return (math.atan2(r21, r22), ry, math.atan2(r10, r00))
    r12 = t * y * z - s * x
    r11 = t * y * y + c
    return (math.atan2(-r12, r11), ry, 0.0)


def term(channel, amplitude, cycles=1, phase=0.0, mode="sin"):
    assert channel in CHANNELS and mode in MODES and cycles == int(cycles)
    return (channel, amplitude, int(cycles), phase, mode)


def _term_value(kind, amplitude, cycles, phase, progress):
    angle = math.tau * (cycles * progress + phase)
    if kind == "sin":
        return amplitude * math.sin(angle)
    if kind == "lift":
        return amplitude * max(0.0, math.sin(angle))
    return amplitude * (1.0 - math.cos(angle)) / 2.0


def _full(spec, bones):
    """{bone: {channel: value}} -> {bone: 6-tuple}, zero where unspecified."""
    out = {bone: [0.0] * 6 for bone in bones}
    for bone, channels in spec.items():
        for channel, value in channels.items():
            out[bone][CHANNELS.index(channel)] = float(value)
    return {bone: tuple(values) for bone, values in out.items()}


# ---------------------------------------------------------------------------
# GD_Yeti. Heavy knuckle walker: arms carry the weight, head slung low.
# ---------------------------------------------------------------------------

# The warning stance, held at the end of Telegraph and the start of Charge: chest up and out,
# arms flung wide and forward, head tucked low like a bull, hind legs coiled. Pitch terms here
# only ever raise the shoulders (negative rx), so planted knuckles never sink into the ground.
YETI_BRACE = {
    "Spine": {"rx": -0.05}, "Chest": {"rx": -0.12}, "Neck": {"rx": 0.20}, "Head": {"rx": 0.25},
    "UpperArm.L": {"rx": -0.25, "ry": -0.30}, "UpperArm.R": {"rx": -0.25, "ry": 0.30},
    "Forearm.L": {"rx": -0.15}, "Forearm.R": {"rx": -0.15},
    "Hand.L": {"rx": -0.10}, "Hand.R": {"rx": -0.10},
    "Thigh.L": {"rx": -0.30}, "Thigh.R": {"rx": -0.30},
    "Shin.L": {"rx": 0.40}, "Shin.R": {"rx": 0.40},
}

YETI_LOOPS = {
    # Slow heavy breathing; the head turns a little as if listening.
    "Idle": {
        "base": {},
        "terms": {
            "Pelvis": (term("lz", 0.06, 1, 0, "rise"),),
            # Pitch terms only ever raise the shoulders (negative rise), so planted knuckles never sink.
            "Spine": (term("rx", -0.02, 1, 0, "rise"),),
            "Chest": (term("rx", -0.035, 1, 0, "rise"), term("rz", 0.02, 1, 0.0)),
            "Neck": (term("rx", 0.04, 1, 0.0),),
            "Head": (term("rx", 0.05, 1, 0.0), term("rz", 0.10, 1, 0.0)),
            "UpperArm.L": (term("rx", -0.03, 1, 0, "rise"),),
            "UpperArm.R": (term("rx", -0.03, 1, 0.25, "rise"),),
            "Forearm.L": (term("rx", -0.02, 1, 0, "rise"),),
            "Forearm.R": (term("rx", -0.02, 1, 0.25, "rise"),),
        },
    },
    # Knuckle-walk: each arm swings forward in turn and plants again, the hind legs lag, the
    # hump rolls. Swings only move forward of the rest pose, so hands and feet stay above ground.
    "Stalk": {
        "base": {"Head": {"rx": 0.10}, "Neck": {"rx": 0.06}},
        "terms": {
            "Pelvis": (term("lz", 0.22, 2, 0, "rise"), term("rz", 0.05, 1, 0.0)),
            "Spine": (term("rz", -0.07, 1, 0.0), term("rx", -0.03, 2, 0, "rise")),
            "Chest": (term("rz", 0.08, 1, 0.0),),
            "Neck": (term("rz", -0.05, 1, 0.0),),
            "Head": (term("rx", 0.04, 2, 0.25), term("rz", 0.06, 1, 0.25)),
            "UpperArm.L": (term("rx", -0.55, 1, 0.0, "lift"),),
            "UpperArm.R": (term("rx", -0.55, 1, 0.5, "lift"),),
            "Forearm.L": (term("rx", -0.35, 1, 0.0, "lift"),),
            "Forearm.R": (term("rx", -0.35, 1, 0.5, "lift"),),
            "Hand.L": (term("rx", -0.15, 1, 0.0, "lift"),),
            "Hand.R": (term("rx", -0.15, 1, 0.5, "lift"),),
            "Thigh.L": (term("rx", -0.30, 1, 0.5, "lift"),),
            "Thigh.R": (term("rx", -0.30, 1, 0.0, "lift"),),
            "Shin.L": (term("rx", 0.45, 1, 0.5, "lift"),),
            "Shin.R": (term("rx", 0.45, 1, 0.0, "lift"),),
        },
    },
    # Stopped, nose near the snow: the head sweeps and pulses while the arms stay planted.
    "Sniff": {
        "base": {"Neck": {"rx": 0.45}, "Head": {"rx": 0.50}, "Chest": {"rx": -0.05}},
        "terms": {
            "Chest": (term("rx", -0.04, 3, 0, "rise"),),
            "Neck": (term("rz", 0.25, 2, 0.0),),
            "Head": (term("rz", 0.30, 2, 0.0), term("rx", 0.10, 3, 0.0)),
            "Pelvis": (term("lz", 0.05, 3, 0, "rise"),),
        },
    },
    # A bounding gallop out of the warning stance: both arms reach forward together, then
    # both hind legs push. Every swing starts from the brace and returns to it.
    "Charge": {
        "base": YETI_BRACE,
        "terms": {
            "Pelvis": (term("lz", 0.40, 1, 0.0, "lift"),),
            "Spine": (term("rx", -0.08, 1, 0, "rise"),),
            "Chest": (term("rx", -0.06, 1, 0, "rise"),),
            "Head": (term("rx", 0.05, 2, 0.0),),
            "UpperArm.L": (term("rx", -0.35, 1, 0.0, "lift"), term("rx", 0.25, 1, 0.5, "lift")),
            "UpperArm.R": (term("rx", -0.35, 1, 0.0, "lift"), term("rx", 0.25, 1, 0.5, "lift")),
            "Forearm.L": (term("rx", -0.30, 1, 0.0, "lift"),),
            "Forearm.R": (term("rx", -0.30, 1, 0.0, "lift"),),
            "Thigh.L": (term("rx", -0.35, 1, 0.5, "lift"),),
            "Thigh.R": (term("rx", -0.35, 1, 0.5, "lift"),),
            "Shin.L": (term("rx", 0.30, 1, 0.5, "lift"),),
            "Shin.R": (term("rx", 0.30, 1, 0.5, "lift"),),
        },
    },
}

# Rise tall and breathe in, then flare into the held brace. The last pose is held exactly so
# it can hand over to Charge.
YETI_TELEGRAPH = (
    (0.00, {}),
    (0.30, {"Spine": {"rx": -0.10}, "Chest": {"rx": -0.20}, "Neck": {"rx": -0.10}, "Head": {"rx": -0.15},
            "UpperArm.L": {"rx": -0.12, "ry": -0.15}, "UpperArm.R": {"rx": -0.12, "ry": 0.15}}),
    (0.60, YETI_BRACE),
    (1.00, YETI_BRACE),
)

# A skid out of the brace, then a slow settle into idle breathing.
YETI_RECOVER = (
    (0.00, YETI_BRACE),
    (0.20, {"Spine": {"rx": -0.05}, "Chest": {"rx": -0.10}, "Neck": {"rx": 0.05}, "Head": {"rx": 0.05},
            "UpperArm.L": {"rx": -0.60, "ry": -0.15}, "UpperArm.R": {"rx": -0.60, "ry": 0.15},
            "Forearm.L": {"rx": -0.10}, "Forearm.R": {"rx": -0.10},
            "Thigh.L": {"rx": -0.55}, "Thigh.R": {"rx": -0.55}, "Shin.L": {"rx": 0.20}, "Shin.R": {"rx": 0.20}}),
    (0.55, {"Spine": {"rx": -0.04}, "Chest": {"rx": -0.08}, "Neck": {"rx": 0.10}, "Head": {"rx": 0.15},
            "UpperArm.L": {"rx": -0.12}, "UpperArm.R": {"rx": -0.12}}),
    (1.00, "idle-start"),
)

MOTION = {
    "GD_Yeti": {"loops": YETI_LOOPS,
                "keyed": {"Telegraph": YETI_TELEGRAPH, "Recover": YETI_RECOVER}},
}


def _smooth(t):
    return t * t * (3.0 - 2.0 * t)


def _loop_pose(guardian, clip, progress):
    definition = MOTION[guardian]["loops"][clip]
    result = {bone: list(values) for bone, values in _full(definition["base"], BONES[guardian]).items()}
    for bone, terms in definition["terms"].items():
        for channel, amplitude, cycles, phase, kind in terms:
            result[bone][CHANNELS.index(channel)] += _term_value(kind, amplitude, cycles, phase, progress)
    # Rounding removes sin(pi)-sized noise, so a loop that starts on a held pose equals it exactly.
    return {bone: tuple(round(v, 12) for v in values) for bone, values in result.items()}


def _keyed_pose(guardian, clip, progress):
    bones = BONES[guardian]
    keys = []
    for at, spec in MOTION[guardian]["keyed"][clip]:
        if spec == "idle-start":
            keys.append((at, _loop_pose(guardian, "Idle", 0.0)))
        else:
            keys.append((at, _full(spec, bones)))
    if progress >= keys[-1][0]:
        return keys[-1][1]
    for (t0, a), (t1, b) in zip(keys, keys[1:]):
        if t0 <= progress < t1:
            s = _smooth((progress - t0) / (t1 - t0))
            return {bone: tuple(x + (y - x) * s for x, y in zip(a[bone], b[bone])) for bone in bones}
    return keys[0][1]


def pose(guardian, clip, progress):
    """Return {bone: (rx, ry, rz, lx, ly, lz)} for every bone of the guardian."""
    if guardian not in MOTION or clip not in CLIPS[guardian]:
        raise ValueError("Unknown guardian or clip.")
    if isinstance(progress, bool) or not isinstance(progress, (float, int)):
        raise ValueError("Progress must be a number.")
    if not math.isfinite(progress) or not 0 <= progress <= 1:
        raise ValueError("Progress must be finite and between zero and one.")
    if clip in LOOPS[guardian]:
        return _loop_pose(guardian, clip, 0.0 if progress >= 1 else float(progress))
    return _keyed_pose(guardian, clip, float(progress))

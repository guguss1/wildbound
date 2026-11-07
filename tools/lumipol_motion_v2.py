"""Pure, bounded, in-place pose profiles for the Lumipol v2 rig.

No Blender here, so the profiles are unit-testable. The builder converts these values into
bone-local keys through kit_common.key_clip, which expects this module's interface: FPS,
DURATIONS, frame_count(clip) and pose(species, clip, progress). Every clip loops:
pose(progress=1) equals pose(progress=0) exactly, Root is never animated, and nothing moves a
bone by scaling it. The rules are the species rules of bible 5.9 (Idle 3.0 s, Move 2.0 s).

Rotations are radians about the armature's X, Y and Z axes, applied in the bone's rest frame.
Offsets are studs along the same axes. Lumipol faces -Y with Z up, so a positive rx pitches
the nose down and a positive rx on a foot that hangs below its hip swings it toward +Y.

A term is (channel, amplitude, cycles, phase, mode), with channel one of rx ry rz lx ly lz:
  sin   amplitude * sin(tau * (cycles * p + phase))
  rise  amplitude * (1 - cos(...)) / 2    0 at the start, up to amplitude and back
Nothing here is validated in play. This is a local prototype, never imported into Roblox.
"""

import math

FPS = 30
DURATIONS = {"Idle": 3.0, "Move": 2.0}
CHANNELS = ("rx", "ry", "rz", "lx", "ly", "lz")
MAX_ANGLE = 1.0
MAX_OFFSET = 0.6
MODES = ("sin", "rise")

BONES = {
    "SP_Lumipol": ("Root", "Body", "Tuft", "LeafL", "LeafR", "Tail", "FootFL", "FootFR", "FootBL", "FootBR"),
}


def frame_count(clip):
    """Frames 1 to N inclusive, so a loop's last frame repeats the first pose."""
    return round(DURATIONS[clip] * FPS) + 1


def term(channel, amplitude, cycles=1, phase=0.0, mode="sin"):
    assert channel in CHANNELS and mode in MODES and cycles == int(cycles)
    return (channel, amplitude, int(cycles), phase, mode)


MOTION = {
    # A small plant companion: breathes and lets its forelock and ears sway while it waits,
    # then trots in place on four feet in a diagonal gait with the ears and tail trailing.
    "SP_Lumipol": {
        "Idle": {
            "Body": (term("lz", 0.04, 1, 0, "rise"), term("rx", 0.015, 1, 0.0)),
            "Tuft": (term("rx", 0.05, 1, 0.10), term("rz", 0.03, 1, 0.0)),
            "LeafL": (term("ry", 0.07, 1, 0.20), term("rx", 0.03, 1, 0.0)),
            "LeafR": (term("ry", -0.06, 1, 0.35), term("rx", 0.04, 1, 0.15)),
            "Tail": (term("rz", 0.10, 1, 0.30), term("rx", 0.03, 1, 0.0)),
        },
        "Move": {
            "Body": (term("lz", 0.16, 2, 0, "rise"), term("rx", 0.06, 2, 0.25), term("rz", 0.05, 1, 0.0)),
            "Tuft": (term("rx", 0.14, 2, 0.30), term("rz", 0.06, 1, 0.0)),
            "LeafL": (term("rx", 0.32, 2, 0.20), term("ry", 0.20, 1, 0.0)),
            "LeafR": (term("rx", 0.32, 2, 0.45), term("ry", -0.20, 1, 0.0)),
            "Tail": (term("rz", 0.45, 2, 0.15), term("rx", 0.15, 2, 0.0)),
            "FootFL": (term("rx", 0.50, 1, 0.0),),
            "FootBR": (term("rx", 0.50, 1, 0.0),),
            "FootFR": (term("rx", 0.50, 1, 0.5),),
            "FootBL": (term("rx", 0.50, 1, 0.5),),
        },
    },
}


def _value(kind, amplitude, cycles, phase, progress):
    angle = math.tau * (cycles * progress + phase)
    if kind == "sin":
        return amplitude * math.sin(angle)
    return amplitude * (1.0 - math.cos(angle)) / 2.0


def pose(species, clip, progress):
    """Return {bone: (rx, ry, rz, lx, ly, lz)} for every bone of the species."""
    if species not in MOTION or clip not in DURATIONS:
        raise ValueError("Unknown species or clip.")
    if isinstance(progress, bool) or not isinstance(progress, (float, int)):
        raise ValueError("Progress must be a number.")
    if not math.isfinite(progress) or not 0 <= progress <= 1:
        raise ValueError("Progress must be finite and between zero and one.")
    progress = 0.0 if progress >= 1 else float(progress)
    result = {bone: [0.0] * 6 for bone in BONES[species]}
    for bone, terms in MOTION[species][clip].items():
        for channel, amplitude, cycles, phase, kind in terms:
            result[bone][CHANNELS.index(channel)] += _value(kind, amplitude, cycles, phase, progress)
    return {bone: tuple(values) for bone, values in result.items()}

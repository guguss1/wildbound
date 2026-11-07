"""Pure, bounded, in-place pose profiles for the Wildbound species rigs.

No Blender here, so the profiles are unit-testable. The builder converts these values
into bone-local keys. Every clip loops: pose(progress=1) equals pose(progress=0) exactly.

Rotations are radians about the armature's X, Y and Z axes, applied in the bone's rest
frame. Offsets are studs along the same axes. Creatures face -Y with Z up, so a positive
rx pitches the nose down and a positive rx on a leg that hangs below its hip swings the
foot toward +Y (backward).

A term is (channel, amplitude, cycles, phase, mode), with channel one of rx ry rz lx ly lz:
  sin   amplitude * sin(tau * (cycles * p + phase))
  lift  amplitude * max(0, sin(...))      only moves one way, so feet never sink
  rise  amplitude * (1 - cos(...)) / 2    0 at the start, up to amplitude and back
Nothing here is validated in play. Root is never animated: no root motion.
"""

import math

FPS = 30
DURATIONS = {"Idle": 3.0, "Move": 2.0}
CHANNELS = ("rx", "ry", "rz", "lx", "ly", "lz")
MAX_ANGLE = 1.0
MAX_OFFSET = 0.6
MODES = ("sin", "lift", "rise")

BONES = {
    "SP_Soplillo": ("Root", "Body", "TailA", "TailB"),
    "SP_Cortezon": ("Root", "Body", "Head", "LegFL", "LegFR", "LegBL", "LegBR"),
    "SP_Cestillo": ("Root", "Basket", "Neck", "Head", "LegL", "LegR"),
    "SP_Zancanieve": ("Root", "Body", "Neck", "Head", "ThighL", "ShinL", "ThighR", "ShinR", "TailA", "TailB"),
    "SP_Polvilla": ("Root", "Body", "WingL", "WingR"),
    "SP_Espejuelo": ("Root", "Slab", "LegL", "LegR"),
    "SP_Aldabon": ("Root", "Body", "Ring", "LegL", "LegR"),
    "SP_Tinajuelo": ("Root", "Jar", "Lid", "ArmL", "ArmR"),
    "SP_Tizoncillo": ("Root", "Body", "LegFL", "LegFR", "LegBL", "LegBR"),
    "SP_Humarel": ("Root", "Body", "Head", "ShinL", "FootL", "ShinR", "FootR", "Tail"),
    "SP_Vetilla": ("Root", "Body", "Head", "TailA", "TailB", "TailC", "LegFL", "LegFR", "LegBL", "LegBR"),
}


def frame_count(clip):
    """Frames 1 to N inclusive, so a loop's last frame repeats the first pose."""
    return round(DURATIONS[clip] * FPS) + 1


def term(channel, amplitude, cycles=1, phase=0.0, mode="sin"):
    assert channel in CHANNELS and mode in MODES and cycles == int(cycles)
    return (channel, amplitude, int(cycles), phase, mode)


MOTION = {
    # A snow puff that breathes, then hops along with a whip tail trailing behind.
    "SP_Soplillo": {
        "Idle": {
            "Body": (term("lz", 0.05, 1, 0, "rise"), term("rx", 0.03, 1, 0.0), term("rz", 0.02, 1, 0.25)),
            "TailA": (term("rx", 0.14, 1, 0.10),),
            "TailB": (term("rx", 0.22, 1, 0.25), term("rz", 0.12, 1, 0.0)),
        },
        "Move": {
            "Body": (term("lz", 0.30, 2, 0, "rise"), term("rx", 0.08, 2, 0.25), term("rz", 0.06, 1, 0.0)),
            "TailA": (term("rx", 0.20, 2, 0.15), term("rz", 0.10, 1, 0.0)),
            "TailB": (term("rx", 0.35, 2, 0.30), term("rz", 0.25, 1, 0.25)),
        },
    },
    # A bark dome that breathes and plods on four stubs in a diagonal gait.
    "SP_Cortezon": {
        "Idle": {
            "Body": (term("lz", 0.04, 1, 0, "rise"), term("rz", 0.015, 1, 0.25)),
            "Head": (term("rx", 0.07, 1, 0.25), term("rz", 0.05, 1, 0.0)),
        },
        "Move": {
            "Body": (term("lz", 0.07, 2, 0, "rise"), term("rz", 0.05, 1, 0.0), term("ry", 0.025, 1, 0.25)),
            "Head": (term("rx", 0.06, 2, 0.25),),
            "LegFL": (term("rx", 0.42, 1, 0.0),),
            "LegBR": (term("rx", 0.42, 1, 0.0),),
            "LegFR": (term("rx", 0.42, 1, 0.5),),
            "LegBL": (term("rx", 0.42, 1, 0.5),),
        },
    },
    # A walking basket: nods in place, waddles on two reed legs.
    "SP_Cestillo": {
        "Idle": {
            "Basket": (term("lz", 0.05, 1, 0, "rise"),),
            "Neck": (term("rx", 0.05, 1, 0.10),),
            "Head": (term("rx", 0.14, 1, 0.35), term("rz", 0.10, 1, 0.0)),
        },
        "Move": {
            "Basket": (term("lz", 0.08, 2, 0, "rise"), term("rz", 0.07, 1, 0.0), term("ry", 0.04, 1, 0.25)),
            "Neck": (term("rx", 0.08, 2, 0.20),),
            "Head": (term("rx", 0.10, 2, 0.45),),
            "LegL": (term("rx", 0.40, 1, 0.0),),
            "LegR": (term("rx", 0.40, 1, 0.5),),
        },
    },
    # A stilt wader: slow high steps with the knee folding, neck pecking, ice fan fluttering.
    "SP_Zancanieve": {
        "Idle": {
            "Body": (term("lz", 0.03, 1, 0, "rise"),),
            "Neck": (term("rx", 0.06, 1, 0.0), term("rz", 0.05, 1, 0.25)),
            "Head": (term("rx", 0.10, 1, 0.30), term("rz", 0.14, 1, 0.0)),
            "TailA": (term("rx", 0.04, 1, 0.15),),
            "TailB": (term("rx", 0.08, 1, 0.35), term("rz", 0.05, 1, 0.0)),
        },
        "Move": {
            "Body": (term("lz", 0.05, 2, 0, "rise"), term("rx", 0.03, 2, 0.25), term("rz", 0.04, 1, 0.0)),
            "Neck": (term("rx", 0.10, 2, 0.25),),
            "Head": (term("rx", 0.08, 2, 0.45),),
            "ThighL": (term("rx", 0.28, 1, 0.0),),
            "ShinL": (term("rx", -0.40, 1, 0.0, "lift"),),
            "ThighR": (term("rx", 0.28, 1, 0.5),),
            "ShinR": (term("rx", -0.40, 1, 0.5, "lift"),),
            "TailA": (term("rx", 0.06, 2, 0.20),),
            "TailB": (term("rx", 0.12, 2, 0.40), term("rz", 0.06, 1, 0.0)),
        },
    },
    # A hovering moth-like creature: the body bobs, the folded wings breathe open and shut.
    "SP_Polvilla": {
        "Idle": {
            "Body": (term("lz", 0.08, 1, 0, "rise"), term("rx", 0.03, 1, 0.25)),
            "WingL": (term("ry", 0.12, 1, 0.10),),
            "WingR": (term("ry", -0.12, 1, 0.10),),
        },
        "Move": {
            "Body": (term("lz", 0.14, 2, 0, "rise"), term("rx", 0.08, 1, 0.0), term("ry", 0.04, 2, 0.25)),
            "WingL": (term("ry", 0.26, 3, 0.10),),
            "WingR": (term("ry", -0.26, 3, 0.10),),
        },
    },
    # A tilted mirror plate: sways in place, rocks from side to side on two thin legs.
    "SP_Espejuelo": {
        "Idle": {
            "Slab": (term("lz", 0.05, 1, 0, "rise"), term("ry", 0.04, 1, 0.0), term("rz", 0.03, 1, 0.25)),
        },
        "Move": {
            "Slab": (term("lz", 0.06, 2, 0, "rise"), term("ry", 0.07, 1, 0.0), term("rz", 0.04, 2, 0.25)),
            "LegL": (term("rx", 0.32, 1, 0.0),),
            "LegR": (term("rx", 0.32, 1, 0.5),),
        },
    },
    # A heavy standing stone: slow, with the iron ring swinging from its bracket.
    "SP_Aldabon": {
        "Idle": {
            "Body": (term("lz", 0.03, 1, 0, "rise"), term("rz", 0.01, 1, 0.25)),
            "Ring": (term("rx", 0.12, 1, 0.10),),
        },
        "Move": {
            "Body": (term("lz", 0.05, 2, 0, "rise"), term("rz", 0.04, 1, 0.0), term("ry", 0.02, 1, 0.25)),
            "Ring": (term("rx", 0.25, 2, 0.20),),
            "LegL": (term("rx", 0.30, 1, 0.0),),
            "LegR": (term("rx", 0.30, 1, 0.5),),
        },
    },
    # A faceless jar: waits with a rattling lid, then shuffles forward in quick small hops.
    "SP_Tinajuelo": {
        "Idle": {
            "Jar": (term("lz", 0.03, 1, 0, "rise"), term("rz", 0.02, 1, 0.25)),
            "Lid": (term("rx", 0.05, 1, 0.30),),
            "ArmL": (term("ry", 0.12, 1, 0.0),),
            "ArmR": (term("ry", -0.12, 1, 0.0),),
        },
        "Move": {
            "Jar": (term("lz", 0.10, 4, 0, "rise"), term("rz", 0.07, 2, 0.0), term("ry", 0.05, 4, 0.25)),
            "Lid": (term("rx", 0.10, 4, 0.30),),
            "ArmL": (term("ry", 0.30, 2, 0.0),),
            "ArmR": (term("ry", -0.30, 2, 0.0),),
        },
    },
    # A charred log on four stumps: slow, heavy, diagonal crawl.
    "SP_Tizoncillo": {
        "Idle": {
            "Body": (term("lz", 0.05, 1, 0, "rise"), term("rz", 0.04, 1, 0.25), term("rx", 0.02, 1, 0.0)),
        },
        "Move": {
            "Body": (term("lz", 0.05, 2, 0, "rise"), term("rz", 0.03, 1, 0.0), term("ry", 0.02, 1, 0.25)),
            "LegFL": (term("rx", 0.35, 1, 0.0),),
            "LegBR": (term("rx", 0.35, 1, 0.0),),
            "LegFR": (term("rx", 0.35, 1, 0.5),),
            "LegBL": (term("rx", 0.35, 1, 0.5),),
        },
    },
    # An upright hopper: crouches in place, then bounds along with the smoke-ring tail trailing.
    "SP_Humarel": {
        "Idle": {
            "Body": (term("lz", 0.04, 1, 0, "rise"), term("rx", 0.03, 1, 0.25)),
            "Head": (term("rx", 0.08, 1, 0.30), term("rz", 0.08, 1, 0.0)),
            "Tail": (term("rx", 0.10, 1, 0.15), term("rz", 0.08, 1, 0.0)),
        },
        "Move": {
            "Body": (term("lz", 0.40, 2, 0, "rise"), term("rx", 0.08, 2, 0.25)),
            "Head": (term("rx", 0.10, 2, 0.40),),
            "ShinL": (term("rx", -0.12, 2, 0.0, "lift"),),
            "ShinR": (term("rx", -0.12, 2, 0.0, "lift"),),
            "FootL": (term("rx", -0.15, 2, 0.25, "lift"),),
            "FootR": (term("rx", -0.15, 2, 0.25, "lift"),),
            "Tail": (term("rx", 0.20, 2, 0.30), term("rz", 0.10, 1, 0.0)),
        },
    },
    # A flat crawling lizard: the spine and tail ripple, legs sprawl in a diagonal gait.
    "SP_Vetilla": {
        "Idle": {
            "Body": (term("rx", 0.02, 1, 0.0), term("rz", 0.03, 1, 0.25)),
            "Head": (term("rz", 0.10, 1, 0.10), term("rx", 0.04, 1, 0.30)),
            "TailA": (term("rz", 0.10, 1, 0.15),),
            "TailB": (term("rz", 0.15, 1, 0.30),),
            "TailC": (term("rz", 0.20, 1, 0.45),),
        },
        "Move": {
            "Body": (term("rz", 0.06, 1, 0.0), term("lz", 0.02, 2, 0, "rise")),
            "Head": (term("rz", -0.12, 1, 0.10),),
            "TailA": (term("rz", 0.20, 1, 0.15),),
            "TailB": (term("rz", 0.30, 1, 0.30),),
            "TailC": (term("rz", 0.40, 1, 0.45),),
            "LegFL": (term("rz", 0.45, 1, 0.0),),
            "LegBR": (term("rz", -0.45, 1, 0.0),),
            "LegFR": (term("rz", -0.45, 1, 0.5),),
            "LegBL": (term("rz", 0.45, 1, 0.5),),
        },
    },
}


def _value(kind, amplitude, cycles, phase, progress):
    angle = math.tau * (cycles * progress + phase)
    if kind == "sin":
        return amplitude * math.sin(angle)
    if kind == "lift":
        return amplitude * max(0.0, math.sin(angle))
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

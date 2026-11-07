"""Pure, bounded in-place pose profiles for the original Silueta custom rig."""

import math

FPS = 30
DURATIONS = {"Idle": 3.0, "Locomotion": 2.0, "Telegraph": 1.4, "Attack": 1.0}
# Versioned clips added after the four above. They stay out of DURATIONS on purpose: the rig
# builder (tools/build-silueta-rig-v3.py) loops DURATIONS, and the four original clips and their
# exports must not be regenerated. Search_v1 is built by tools/build-silueta-search-v1.py.
EXTRA_CLIPS = {"Search_v1": 2.4}
BONES = ("Root", "Pelvis", "Spine", "Chest", "Neck", "Head",
         "UpperArm.L", "Forearm.L", "Hand.L", "UpperArm.R", "Forearm.R", "Hand.R",
         "Thigh.L", "Shin.L", "Foot.L", "Thigh.R", "Shin.R", "Foot.R")


def _search_v1(progress):
    """Low, tilted, slowly scanning search: the opposite of the open-armed Telegraph.

    Stooped forward with the head cocked to one side and sweeping across the room, one forearm
    held low and the other feeling forward. Arms stay close to the body, so a viewer can tell it
    from the warning pose at a glance. Every term has a whole number of cycles, so it loops.
    """
    sweep = math.sin(progress * math.tau)
    swing = math.cos(progress * math.tau)
    result = dict.fromkeys(BONES, (0, 0, 0))
    result.update(
        Spine=(.22 + .02 * sweep, .06 * sweep, 0),
        Chest=(.16, .10 * sweep, -.05),
        Neck=(.12, .13 * sweep, .06),
        Head=(.12 + .04 * swing, .44 * sweep, .25 + .04 * swing),
        **{"UpperArm.L": (-.38 + .06 * sweep, 0, .05), "Forearm.L": (-.60 + .10 * swing, 0, 0),
           "Hand.L": (.12 * sweep, 0, 0),
           "UpperArm.R": (-.05, 0, -.06), "Forearm.R": (-.20 + .05 * swing, 0, 0),
           "Hand.R": (.08 * swing, 0, 0),
           "Thigh.L": (.04 * sweep, 0, 0), "Thigh.R": (-.04 * sweep, 0, 0)})
    return result


def pose(action, progress):
    if (action not in DURATIONS and action not in EXTRA_CLIPS) or not isinstance(progress, (float, int)):
        raise ValueError("Unknown action or non-numeric progress.")
    if not math.isfinite(progress) or not 0 <= progress <= 1:
        raise ValueError("Progress must be finite and between zero and one.")
    if action in EXTRA_CLIPS:
        return _search_v1(progress)
    result = dict.fromkeys(BONES, (0, 0, 0))
    wave = math.sin(progress * math.tau)
    if action == "Idle":
        result.update(Spine=(.018 * wave, 0, 0), Chest=(.025 * wave, 0, 0),
                      Head=(.015 * wave, .025 * wave, .035 * wave))
    elif action == "Locomotion":
        result.update(Spine=(.025 * wave, 0, .03 * wave), Chest=(0, .035 * wave, 0),
                      Head=(.025 * wave, -.04 * wave, 0))
        for suffix, sign in ((".L", 1), (".R", -1)):
            swing = wave * sign
            result["Thigh" + suffix] = (.27 * swing, 0, 0)
            result["Shin" + suffix] = (-.24 * max(0, swing), 0, 0)
            result["Foot" + suffix] = (.08 * max(0, swing), 0, 0)
            result["UpperArm" + suffix] = (-.16 * swing, 0, 0)
            result["Forearm" + suffix] = (-.10 * max(0, -swing), 0, 0)
            result["Hand" + suffix] = (.035 * swing, 0, 0)
    else:
        windup = {
            "Spine": (-.14, 0, 0), "Chest": (-.14, 0, .025), "Neck": (.13, 0, 0),
            "Head": (.08, -.05, -.06),
            "UpperArm.L": (.45, -.10, .60), "UpperArm.R": (.40, .10, -.60),
            "Forearm.L": (-.70, 0, 0), "Forearm.R": (-.65, 0, 0),
            "Hand.L": (.18, 0, -.08), "Hand.R": (.16, 0, .08),
        }
        if action == "Telegraph":
            amount = min(progress * 2, 1)
            amount = amount * amount * (3 - 2 * amount)
            result.update({bone: tuple(v * amount for v in angles) for bone, angles in windup.items()})
        elif progress <= .23:
            amount = progress / .23
            strike = {"Spine": (.19, 0, 0), "Chest": (.22, 0, -.08), "Head": (.08, .03, .05),
                      "UpperArm.L": (-.65, 0, -.10), "UpperArm.R": (-.60, 0, .10),
                      "Forearm.L": (-.35, 0, 0), "Forearm.R": (-.30, 0, 0)}
            for bone in BONES:
                result[bone] = tuple(a + (b - a) * amount
                                     for a, b in zip(windup.get(bone, (0, 0, 0)), strike.get(bone, (0, 0, 0))))
        else:
            strike = pose("Attack", .23)
            amount = (progress - .23) / .77
            amount = amount * amount * (3 - 2 * amount)
            result = {bone: tuple(v * (1 - amount) for v in angles) for bone, angles in strike.items()}
    return result

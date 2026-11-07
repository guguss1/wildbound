"""Hiding-spot layout for Wildbound delivery D7 (docs/mechanics/wildbound-delivery-d.md section 3).

Ten spots: six primitive bushes placed by a deterministic search and four existing FK_FallenLog models
marked as hollow logs. Reads the forest layout (routes, trunks, logs, lanterns) and writes
assets/maps/forest-layout/hide-spots-v1.json only when asked. Pure Python, no randomness.

Rules (bushes): outside both safe circles, 8 to 14 studs off the nearest route centerline, at least 10 studs
from any trunk core edge, 12 from the guardian's patrol diamond, at least 6 studs from every other forest prop, at least 25 studs from every other spot.
Logs keep their own place; none of the 17 lies 8 to 14 off the route, so a log counts when it is 15 to 32 off the
route (reachable, out of the corridor) and 10 from any trunk core edge (decision D-D4, for user review).
Coverage: a spot 25 to 45 studs from the nest, the ruin and the marsh, and one within 45 of the Lumipol clearing.

    python -I -B tools/plan_hide_spots.py            # prints JSON, writes nothing
    python -I -B tools/plan_hide_spots.py --write    # writes the JSON file
"""

import argparse
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # -I leaves the script folder off the path
import plan_forest_layout as forest  # noqa: E402
import plan_relief as relief_plan  # noqa: E402

REPO = Path(__file__).resolve().parent.parent
LAYOUT = REPO / "assets/maps/forest-layout/forest-layout-v1.json"
OUTPUT = REPO / "assets/maps/forest-layout/hide-spots-v1.json"
RELIEF = REPO / "assets/maps/forest-layout/relief-v1.json"
RELIEF_FLAT = 5.0  # expedition relief (R4): a spot keeps flat ground this far around it

BUSHES, LOGS = 6, 4
SPACING = 25.0
ROUTE_BAND = (8.0, 14.0)
LOG_ROUTE_BAND = (15.0, 32.0)
CORE_CLEAR = 10.0
PROP_CLEAR = 6.0
SAFE_MARGIN = 3.0
PATROL_CLEAR = 12.0  # a spot on the guardian's patrol diamond would be found on every lap
OBJECTIVES = {"nest": (35.0, -99.0), "ruin": (0.0, -85.0), "marsh": (115.0, 15.0)}
OBJECTIVE_BAND = (25.0, 45.0)
CLEARING, CLEARING_REACH = (-95.0, 75.0), 45.0
CORE_RADIUS = {"FK_Evergreen": 2.5, "FK_DeadTree": 3.4}
LOG_IDS = ("FK_FallenLog_001", "FK_FallenLog_005", "FK_FallenLog_011", "FK_FallenLog_014")
STEP = 1.0


def load_layout(path=LAYOUT):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def cores(layout):
    return [(i["x"], i["z"], CORE_RADIUS[i["name"]] * i["scale"]) for i in layout["instances"] if i["name"] in CORE_RADIUS]


def core_gap(p, core_list):
    return min(math.hypot(p[0] - x, p[1] - z) - r for x, z, r in core_list)


def prop_gap(p, layout, skip=None):
    return min(math.hypot(p[0] - i["x"], p[1] - i["z"]) for i in layout["instances"] if i["id"] != skip)


def safe_clear(p):
    return all(math.hypot(p[0] - c[0], p[1] - c[1]) > r + SAFE_MARGIN for c, r in forest.SAFE_CIRCLES)


def patrol_gap(p):
    loop = forest.PATROL_LOOP
    return min(forest.point_seg_dist(p, loop[i], loop[(i + 1) % len(loop)]) for i in range(len(loop)))


def load_relief(path=RELIEF):
    path = Path(path)
    return json.loads(path.read_text(encoding="utf-8"))["segments"] if path.exists() else []


def relief_flat(p, segments, radius=RELIEF_FLAT, step=1.0):
    """True when the relief leaves the floor flat within `radius` of p (hiding anchors on flat ground)."""
    if all(relief_plan.footprint_distance(seg, *p) > radius for seg in segments):
        return True
    n = int(radius // step)
    for i in range(-n, n + 1):
        for j in range(-n, n + 1):
            if math.hypot(i * step, j * step) <= radius:
                if relief_plan.height_at(segments, p[0] + i * step, p[1] + j * step) != relief_plan.FLOOR_TOP:
                    return False
    return True


def spaced(p, spots):
    return all(math.hypot(p[0] - s["x"], p[1] - s["z"]) >= SPACING for s in spots)


def bush_ok(p, layout, core_list, spots, relief=()):
    lo, hi = ROUTE_BAND
    return (lo <= forest.route_distance(p) <= hi and abs(p[0]) <= forest.LIMIT - 4 and abs(p[1]) <= forest.LIMIT - 4
            and safe_clear(p) and spaced(p, spots) and patrol_gap(p) >= PATROL_CLEAR and core_gap(p, core_list) >= CORE_CLEAR
            and prop_gap(p, layout) >= PROP_CLEAR and relief_flat(p, relief))


def log_ok(log, core_list, relief=()):
    p = (log["x"], log["z"])
    lo, hi = LOG_ROUTE_BAND
    return (safe_clear(p) and lo <= forest.route_distance(p) <= hi and core_gap(p, core_list) >= CORE_CLEAR
            and relief_flat(p, relief))


def _grid():
    span = int(forest.LIMIT)
    for xi in range(-span, span + 1):
        for zi in range(-span, span + 1):
            yield (xi * STEP, zi * STEP)


def _best(candidates, score):
    best = None
    for p in candidates:
        value = score(p)
        if best is None or value > best[0] or (value == best[0] and p < best[1]):
            best = (value, p)
    return best[1] if best else None


def plan(layout=None, relief=None):
    layout = layout or load_layout()
    relief = load_relief() if relief is None else relief
    core_list = cores(layout)
    by_id = {i["id"]: i for i in layout["instances"]}
    spots = []
    for log_id in LOG_IDS:
        log = by_id[log_id]
        if not log_ok(log, core_list, relief) or not spaced((log["x"], log["z"]), spots):
            raise ValueError(f"{log_id} breaks the hollow-log rule")
        spots.append({"kind": "log", "x": log["x"], "z": log["z"], "yaw": log["rotation_y_deg"], "scale": log["scale"],
                      "log_id": log_id})
    grid = list(_grid())

    def covered(target, band):
        return any(band[0] <= math.hypot(s["x"] - target[0], s["z"] - target[1]) <= band[1] for s in spots)

    # Coverage first: each objective, then the clearing, gets the candidate nearest the middle of its band.
    needs = [(target, OBJECTIVE_BAND) for target in OBJECTIVES.values()] + [(CLEARING, (0.0, CLEARING_REACH))]
    for target, band in needs:
        if covered(target, band):
            continue
        middle = (band[0] + band[1]) / 2

        def in_band(p, target=target, band=band):
            return band[0] <= math.hypot(p[0] - target[0], p[1] - target[1]) <= band[1]
        pick = _best((p for p in grid if in_band(p) and bush_ok(p, layout, core_list, spots, relief)),
                     lambda p, target=target, middle=middle: -abs(math.hypot(p[0] - target[0], p[1] - target[1]) - middle))
        if pick is None:
            raise ValueError(f"no bush can cover {target}")
        spots.append({"kind": "bush", "x": pick[0], "z": pick[1], "yaw": 0.0, "scale": 1.0})
    # The rest: spread out, preferring the fog territory where the guardian lives.
    while sum(1 for s in spots if s["kind"] == "bush") < BUSHES:
        def score(p):
            spread = min(math.hypot(p[0] - s["x"], p[1] - s["z"]) for s in spots)
            return min(spread, 60.0) + (25.0 if forest.in_fog(*p) else 0.0)
        pick = _best((p for p in grid if bush_ok(p, layout, core_list, spots, relief)), score)
        if pick is None:
            raise ValueError("not enough room for the bushes")
        spots.append({"kind": "bush", "x": pick[0], "z": pick[1], "yaw": 0.0, "scale": 1.0})
    spots.sort(key=lambda s: (s["kind"] != "bush", s["z"], s["x"]))
    for index, spot in enumerate(spots, start=1):
        spot["id"] = f"H{index:02d}"
        spot["route_distance"] = round(forest.route_distance((spot["x"], spot["z"])), 3)
        spot["core_gap"] = round(core_gap((spot["x"], spot["z"]), core_list), 3)
    return {
        "name": "hide-spots-v1",
        "source": "tools/plan_hide_spots.py",
        "conventions": "studs, origin at the map centre, x east, z south (as forest-layout-v1)",
        "rules": {"spacing": SPACING, "route_band_bush": list(ROUTE_BAND), "route_band_log": list(LOG_ROUTE_BAND),
                  "core_clear": CORE_CLEAR, "patrol_clear": PATROL_CLEAR, "prop_clear_bush": PROP_CLEAR, "safe_margin": SAFE_MARGIN,
                  "objective_band": list(OBJECTIVE_BAND), "clearing_reach": CLEARING_REACH},
        "spots": [{key: spot[key] for key in ("id", "kind", "x", "z", "yaw", "scale", "route_distance", "core_gap")}
                  | ({"log_id": spot["log_id"]} if "log_id" in spot else {}) for spot in spots],
    }


def render(result):
    return json.dumps(result, indent=2, sort_keys=False) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--write", action="store_true", help="write " + str(OUTPUT.relative_to(REPO)))
    args = parser.parse_args(argv)
    text = render(plan())
    if args.write:
        OUTPUT.write_text(text, encoding="utf-8", newline="\n")
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

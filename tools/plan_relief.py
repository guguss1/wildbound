"""Low relief for the Wildbound expedition map (docs/mechanics/wildbound-expedition-islands.md section 1, task R1).

Relief is a list of straight ridge segments built from parts (decision EI-1), never Roblox Terrain. A segment is a
trapezoid prism with tapered ends: one crest Part, two flank WedgeParts, two end-cap WedgeParts and four
CornerWedgeParts, 9 parts. Its height above the floor top (Y 0.5) at a point is

    height * min(cross, along)
    cross = clamp((crestWidth / 2 + run - |d|) / run, 0, 1)
    along = clamp((length / 2 + run - |t|) / run, 0, 1)
    run   = height / tan(slopeDeg)

where t is the distance along the segment from its middle and d the distance across it. The map height is the
floor top plus the maximum over segments. `src/wildbound/WildboundRelief.luau` holds the same rule; the 64 golden
samples written here tie the two together.

The planner places the design's candidate features in order and, for each, searches height, offset, length and
slope until every rule holds against what is already placed; a candidate that cannot fit is reported as dropped.
Rules (all checked against the combined height):

- crest at most 10 studs above the floor, at most 6 where any of its footprint is in the guardian's territory;
- flanks at most 20 degrees; a layout tree may stand only where the ground is at most 12 degrees, a fallen log
  only where it is at most 6 degrees over its whole length (logs simply stay off the relief);
- the route stays flat: no footprint within the 14-stud path plus 2 studs, so grade and cross slope are 0;
- no footprint inside a safe circle plus 3, an island floor, 5 studs of a hide spot, Lumipol or egg slot, gather
  slot, map marker or ambush anchor, 10 studs of a route landmark, 4.5 of a ruin pillar or 2 of the marsh pool;
- the nest's open sight lanes to patrol E and N stay on flat ground;
- at most 250 parts.

    python -I -B tools/plan_relief.py            # prints JSON, writes nothing
    python -I -B tools/plan_relief.py --write    # writes assets/maps/forest-layout/relief-v1.json
"""

import argparse
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # -I leaves the script folder off the path
import plan_forest_layout as forest  # noqa: E402
import simulate_economy as eco  # noqa: E402  (the one reader of the economy tuning block)

REPO = Path(__file__).resolve().parent.parent
LAYOUT = REPO / "assets/maps/forest-layout/forest-layout-v1.json"
HIDE = REPO / "assets/maps/forest-layout/hide-spots-v1.json"
OUTPUT = REPO / "assets/maps/forest-layout/relief-v1.json"

FLOOR_TOP = 0.5
PARTS_PER_SEGMENT = 9
PART_BUDGET = 250
MAX_HEIGHT, MAX_HEIGHT_TERRITORY = 10.0, 6.0
SLOPES = (20.0, 16.0, 12.0)
TREE_SLOPE, LOG_SLOPE = 12.0, 6.0
ROUTE_CLEAR = forest.ROUTE_WIDTH / 2 + 2.0
SAFE_MARGIN = 3.0
POINT_CLEAR = 5.0
LANDMARK_CLEAR = 10.0
PILLAR_CLEAR = 4.5
POOL_CLEAR = 2.0
LANE_CLEAR = 2.0
TREE_REMOVAL_PER_SEGMENT, TREE_REMOVAL_BUDGET = 4, 30  # of the layout's 172 trees
TREE_KEEP_NEST = 27.0  # the nest cover band (13 to 26) stays
LOG_REACH = 8.5  # half a fallen log's length per unit scale, plus a little

ISLANDS = {"claro": ((-95.0, 75.0), 14.0), "hondonada": ((-27.0, 0.0), 16.0), "pantano": ((115.0, 15.0), 16.0),
           "ruinas": ((35.0, -99.0), 16.0), "corazon": ((60.0, -135.0), 16.0)}
# src/wildbound/WildboundLumipolWild.luau slots S0a, S0b, L1 to L4, E1 to E3.
LUMIPOL_SLOTS = ((-95, 75), (-112, 92), (-10, -60), (30, -105), (65, -60), (110, 5), (35, -99), (-38, -85),
                 (60, -125))
# tools/build-wildbound-p0-map.luau markers and src/wildbound/WildboundAmbush.luau anchors.
MARKERS = ((-140, 140), (-146, 140), (-135, 146), (-135, 134), (-95, 75), (0, -85), (35, -99),
           (-152, 128), (-150, 154), (-136, 158))
AMBUSH = ((0, -85), (40, -125), (55, -38), (-30, -45), (-40, -110), (40, -140))
POOL = (112.0, 144.0, 3.0, 27.0)  # MarshPool, xmin xmax zmin zmax
# The place's default SpawnLocation, a 12 by 12 pad at the origin where characters appear before the inventory server
# moves them to camp (found in the R6 Play check): its half-diagonal plus 3 studs stays flat.
SPAWN_PAD, SPAWN_PAD_CLEAR = (0.0, 0.0), 6.0 * math.sqrt(2) + 3.0
NEST, LANES = (35.0, -99.0), ((16.0, -85.0), (0.0, -101.0))

# Candidate features from the design table, in placement order. Rims are rings of chords around an island floor;
# "gaps" are chord indices left open (entrances); the route corridor opens more on its own.
RIM_CLARO = {"feature": "rim-claro", "island": "claro", "height": 3.0, "crest": 3.0, "chords": 6, "gaps": ()}
RIM_HONDONADA = {"feature": "rim-hondonada", "island": "hondonada", "height": 4.0, "crest": 3.0, "chords": 6, "gaps": ()}
# The ruin rim keeps the nest's cover band (13 to 26 studs, plan_forest_layout.COVER_BAND) flat: its inner toe sits at
# 27 studs instead of the 16-stud floor.
RIM_RUINAS = {"feature": "rim-ruinas", "island": "ruinas", "height": 5.0, "crest": 3.0, "chords": 8, "gaps": (),
              "inner": 27.0}
RIM_CORAZON = {"feature": "rim-corazon", "island": "corazon", "height": 6.0, "crest": 3.0, "chords": 6, "gaps": ()}
LOMA_LARGA = {"feature": "loma-larga", "centre": (-10.0, 70.0), "length": 60.0, "yaw": 90.0, "height": 10.0,
              "crest": 6.0}
VIGIA = {"feature": "cresta-vigia", "centre": (15.0, -42.0), "length": 30.0, "yaw": 90.0, "height": 6.0, "crest": 4.0}
RIDGES = (
    {"feature": "saddle-west", "centre": (-50.0, -18.0), "length": 22.0, "yaw": 150.0, "height": 4.0, "crest": 3.0},
    {"feature": "saddle-east", "centre": (-20.0, -32.0), "length": 22.0, "yaw": 150.0, "height": 4.0, "crest": 3.0},
    {"feature": "hummock-marsh", "centre": (140.0, -8.0), "length": 14.0, "yaw": 30.0, "height": 3.0, "crest": 3.0,
     "lowest": 2.0},
    {"feature": "hummock-marsh", "centre": (90.0, 35.0), "length": 14.0, "yaw": 120.0, "height": 2.5, "crest": 3.0,
     "lowest": 2.0},
    {"feature": "hummock-marsh", "centre": (138.0, 45.0), "length": 12.0, "yaw": 75.0, "height": 2.0, "crest": 3.0,
     "lowest": 2.0},
)
# Placement order is priority order: the reveal rim, the tall hill, the sighting crest, then the deeper rims.
ORDER = (("rim", RIM_CLARO), ("ridge", LOMA_LARGA), ("ridge", VIGIA), ("rim", RIM_HONDONADA), ("rim", RIM_RUINAS),
         ("rim", RIM_CORAZON)) + tuple(("ridge", spec) for spec in RIDGES)
OFFSETS = [(0.0, 0.0)] + [(r * math.cos(math.radians(a)), r * math.sin(math.radians(a)))
                          for r in (4.0, 8.0, 12.0, 16.0, 20.0, 24.0) for a in range(0, 360, 45)]


def r3(value):
    return round(value + 0.0, 3)


# --- the height rule (mirrored in src/wildbound/WildboundRelief.luau) ------------------------------------------

def run_of(seg):
    return seg["height"] / math.tan(math.radians(seg["slopeDeg"]))


def _frame(seg):
    (ax, az), (bx, bz) = seg["a"], seg["b"]
    length = math.hypot(bx - ax, bz - az)
    return (ax + bx) / 2, (az + bz) / 2, (bx - ax) / length, (bz - az) / length, length


def profile(seg, x, z):
    mx, mz, ux, uz, length = _frame(seg)
    t = (x - mx) * ux + (z - mz) * uz
    d = -(x - mx) * uz + (z - mz) * ux
    run = run_of(seg)
    cross = min(1.0, max(0.0, (seg["crestWidth"] / 2 + run - abs(d)) / run))
    along = min(1.0, max(0.0, (length / 2 + run - abs(t)) / run))
    return seg["height"] * min(cross, along)


def height_at(segments, x, z):
    return FLOOR_TOP + max((profile(s, x, z) for s in segments), default=0.0)


def slope_deg(segments, x, z, step=0.25):
    """Steepest one-sided rise over 16 directions: exact for the piecewise-planar relief, no crease overshoot."""
    here = height_at(segments, x, z)
    worst = 0.0
    for k in range(16):
        angle = math.pi * k / 8
        rise = abs(height_at(segments, x + step * math.cos(angle), z + step * math.sin(angle)) - here)
        worst = max(worst, rise / step)
    return math.degrees(math.atan(worst))


def footprint_distance(seg, x, z):
    """Distance from a point to the footprint rectangle (0 inside)."""
    mx, mz, ux, uz, length = _frame(seg)
    run = run_of(seg)
    t = abs((x - mx) * ux + (z - mz) * uz) - (length / 2 + run)
    d = abs(-(x - mx) * uz + (z - mz) * ux) - (seg["crestWidth"] / 2 + run)
    return math.hypot(max(t, 0.0), max(d, 0.0))


def footprint_points(seg, step=2.0):
    mx, mz, ux, uz, length = _frame(seg)
    run = run_of(seg)
    half_t, half_d = length / 2 + run, seg["crestWidth"] / 2 + run
    nt, nd = max(1, math.ceil(2 * half_t / step)), max(1, math.ceil(2 * half_d / step))
    for i in range(nt + 1):
        t = -half_t + 2 * half_t * i / nt
        for j in range(nd + 1):
            d = -half_d + 2 * half_d * j / nd
            yield mx + t * ux - d * uz, mz + t * uz + d * ux


def _segment_distance(seg, a, b, step=1.0):
    length = math.dist(a, b)
    n = max(1, math.ceil(length / step))
    return min(footprint_distance(seg, a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n)
               for k in range(n + 1))


# --- inputs ----------------------------------------------------------------------------------------------------

def load_inputs():
    layout = json.loads(LAYOUT.read_text(encoding="utf-8"))
    hide = json.loads(HIDE.read_text(encoding="utf-8"))
    points = [(s["x"], s["z"]) for s in hide["spots"] if s["kind"] == "bush"]
    points += list(LUMIPOL_SLOTS) + list(MARKERS) + list(AMBUSH)
    points += [(s["x"], s["z"]) for s in eco.load_tuning()["gather"]["slots"]]
    instances = layout["instances"]
    return {
        "points": points,
        "trees": [(i["id"], i["x"], i["z"], math.dist((i["x"], i["z"]), NEST) < TREE_KEEP_NEST)
                  for i in instances if i["name"] in forest.TREES],
        "logs": [(i["x"], i["z"], i["scale"]) for i in instances if i["name"] == "FK_FallenLog"],
        "landmarks": [(i["x"], i["z"]) for i in instances if i["name"] in forest.LANDMARKS],
    }


# --- rules -----------------------------------------------------------------------------------------------------

def _pool_points():
    xmin, xmax, zmin, zmax = POOL
    for i in range(17):
        for j in range(13):
            yield xmin + (xmax - xmin) * i / 16, zmin + (zmax - zmin) * j / 12


def fits(seg, placed, inputs, removed=frozenset()):
    """Every rule for one new segment against the segments already placed. Returns None or the broken rule. On
    success the layout trees this segment leaves on ground steeper than 12 degrees are listed in seg["_removes"]."""
    lim = forest.LIMIT
    for x, z in footprint_points(seg, 4.0):
        if abs(x) > lim or abs(z) > lim:
            return "map edge"
    for c, r in forest.SAFE_CIRCLES:
        if footprint_distance(seg, *c) < r + SAFE_MARGIN:
            return "safe circle"
    for c, r in ISLANDS.values():
        if footprint_distance(seg, *c) < r:
            return "island floor"
    for p in inputs["points"]:
        if footprint_distance(seg, *p) < POINT_CLEAR:
            return "flat point"
    for p in inputs["landmarks"]:
        if footprint_distance(seg, *p) < LANDMARK_CLEAR:
            return "landmark"
    for p in forest.PILLARS:
        if footprint_distance(seg, *p) < PILLAR_CLEAR:
            return "pillar"
    if footprint_distance(seg, *SPAWN_PAD) < SPAWN_PAD_CLEAR:
        return "spawn pad"
    for x, z, scale in inputs["logs"]:
        if footprint_distance(seg, x, z) < LOG_REACH * scale:
            return "log"
    for p in _pool_points():
        if footprint_distance(seg, *p) < POOL_CLEAR:
            return "pool"
    for lane in LANES:
        if _segment_distance(seg, NEST, lane) < LANE_CLEAR:
            return "nest lane"
    for a, b in forest.SEGMENTS:
        if _segment_distance(seg, a, b, 2.0) < ROUTE_CLEAR:
            return "route"
    combined = placed + [seg]
    for x, z in footprint_points(seg, 2.0):
        if forest.in_territory(x, z) and height_at(combined, x, z) - FLOOR_TOP > MAX_HEIGHT_TERRITORY + 1e-9:
            return "territory height"
    steep = []
    for tree_id, x, z, keep in inputs["trees"]:
        if tree_id in removed or footprint_distance(seg, x, z) > 0.5:
            continue
        if slope_deg(combined, x, z) > TREE_SLOPE + 1e-9:
            if keep:
                return "kept tree on a steep flank"
            steep.append(tree_id)
    if len(steep) > TREE_REMOVAL_PER_SEGMENT or len(removed) + len(steep) > TREE_REMOVAL_BUDGET:
        return "too many trees on steep flanks"
    seg["_removes"] = steep
    return None


def make_segment(feature, centre, yaw_deg, length, height, crest, slope):
    ux, uz = math.sin(math.radians(yaw_deg)), math.cos(math.radians(yaw_deg))
    half = length / 2
    return {"feature": feature,
            "a": [r3(centre[0] - ux * half), r3(centre[1] - uz * half)],
            "b": [r3(centre[0] + ux * half), r3(centre[1] + uz * half)],
            "height": r3(height), "crestWidth": r3(crest), "slopeDeg": r3(slope)}


def _heights(target, lowest=3.0):
    h, out = target, []
    while h >= lowest - 1e-9:
        out.append(r3(h))
        h -= 1.0
    return out


def place_ridge(spec, placed, inputs, removed):
    """Height first, then a move of up to 24 studs, a shorter ridge, a turn and a gentler flank."""
    for height in _heights(spec["height"], spec.get("lowest", 3.0)):
        for dx, dz in OFFSETS:
            for factor in (1.0, 0.75, 0.5, 0.35):
                for turn in (0.0, 45.0, 90.0, 135.0):
                    for slope in SLOPES:
                        centre = (spec["centre"][0] + dx, spec["centre"][1] + dz)
                        seg = make_segment(spec["feature"], centre, spec["yaw"] + turn, spec["length"] * factor,
                                           height, spec["crest"], slope)
                        if fits(seg, placed, inputs, removed) is None:
                            return seg
    return None


def place_rim(spec, placed, inputs, removed):
    """Each chord of the ring is searched alone: height first, then a turn about the island, a shorter chord, a push
    outward and a gentler flank. A chord that cannot fit leaves an opening, which is also an entrance."""
    (cx, cz), floor = ISLANDS[spec["island"]]
    floor = spec.get("inner", floor)
    n = spec["chords"]
    out, dropped = [], []
    for k in range(n):
        if k in spec["gaps"]:
            continue
        seg = _rim_chord(spec, k, floor, cx, cz, placed + out, inputs, removed)
        if seg:
            out.append(seg)
            removed.update(seg["_removes"])
        else:
            dropped.append(f"{spec['feature']}#{k}")
    return out, dropped


def _rim_chord(spec, k, floor, cx, cz, placed, inputs, removed):
    n = spec["chords"]
    for height in _heights(spec["height"]):
        for turn in (0.0, 10.0, -10.0, 20.0, -20.0):
            angle = 2 * math.pi * k / n + math.radians(turn)
            for factor in (1.0, 0.75, 0.5):
                for push in (1.0, 4.0, 7.0):
                    for slope in SLOPES:
                        run = height / math.tan(math.radians(slope))
                        apothem = floor + run + spec["crest"] / 2 + push
                        length = 2 * apothem * math.tan(math.pi / n) * 1.05 * factor
                        centre = (cx + apothem * math.cos(angle), cz + apothem * math.sin(angle))
                        # yaw is measured from +z toward +x: the chord runs perpendicular to the radius.
                        yaw = math.degrees(math.atan2(-math.sin(angle), math.cos(angle)))
                        candidate = make_segment(spec["feature"], centre, yaw, length, height, spec["crest"], slope)
                        if fits(candidate, placed, inputs, removed) is None:
                            return candidate
    return None


def golden_samples(segments):
    points = []
    for seg in segments:
        mx, mz, ux, uz, length = _frame(seg)
        run = run_of(seg)
        for t, d in ((0.0, 0.0), (0.0, seg["crestWidth"] / 2 + run / 2), (length / 2 + run / 3, seg["crestWidth"] / 2 + run / 3)):
            points.append((mx + t * ux - d * uz, mz + t * uz + d * ux))
    fixed = [(-140.0, 150.0), (0.0, -85.0), (35.0, -99.0), (-95.0, 75.0), (190.0, 190.0), (-190.0, -190.0)]
    points = points[:64 - len(fixed)] + fixed
    k = 0
    while len(points) < 64:
        k += 1
        points.append((-180.0 + 37.0 * k, 160.0 - 29.0 * k))
    return [{"x": r3(x), "z": r3(z), "y": r3(height_at(segments, x, z))} for x, z in points]


def plan():
    inputs = load_inputs()
    placed, dropped, removed = [], [], set()
    for kind, spec in ORDER:
        if kind == "rim":
            segs, lost = place_rim(spec, placed, inputs, removed)
            placed += segs
            dropped += lost
            continue
        seg = place_ridge(spec, placed, inputs, removed)
        if seg:
            placed.append(seg)
            removed.update(seg["_removes"])
        else:
            dropped.append(spec["feature"])
    if len(placed) * PARTS_PER_SEGMENT > PART_BUDGET:
        raise ValueError("relief over the part budget")
    for index, seg in enumerate(placed, start=1):
        seg["id"] = f"R{index:02d}"
    keys = ("id", "feature", "a", "b", "height", "crestWidth", "slopeDeg")
    segments = [{k: s[k] for k in keys} for s in placed]
    return {
        "name": "relief-v1",
        "source": "tools/plan_relief.py",
        "conventions": "studs, origin at the map centre, x east, z south (as forest-layout-v1); heights above the "
                       "floor top Y 0.5; a segment runs from a to b with tapered ends",
        "floorTop": FLOOR_TOP,
        "partsPerSegment": PARTS_PER_SEGMENT,
        "rules": {"maxHeight": MAX_HEIGHT, "maxHeightTerritory": MAX_HEIGHT_TERRITORY, "maxSlopeDeg": SLOPES[0],
                  "treeSlopeDeg": TREE_SLOPE, "logSlopeDeg": LOG_SLOPE, "routeClear": ROUTE_CLEAR,
                  "safeMargin": SAFE_MARGIN, "pointClear": POINT_CLEAR, "partBudget": PART_BUDGET,
                  "treeRemovalBudget": TREE_REMOVAL_BUDGET, "treeKeepNest": TREE_KEEP_NEST},
        "totals": {"segments": len(segments), "parts": len(segments) * PARTS_PER_SEGMENT, "dropped": dropped},
        "removedTrees": sorted(removed),
        "segments": segments,
        "samples": golden_samples(segments),
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

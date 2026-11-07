#!/usr/bin/env python3
"""Reproducible top-down placement DRAFT for one Frozen Mountains sector (unvalidated).

This is a plan only: it writes JSON, SVG and (when Pillow is importable) PNG files and never
touches the Luau map builder, Studio or Blender. Python standard library only; Pillow is
optional. The plan stays a draft for a later sector design: it is not an approved layout, was
never imported into Roblox, and no budget in it was measured on a device.

    python tools/plan_frozen_mountains_layout.py [--seed N] [--out-dir DIR]

Conventions (studs, origin at the sector centre): x grows east, z grows south,
rotation_y_deg is CFrame.Angles(0, math.rad(r), 0) (see tools/layout_geometry.py).
Spec: docs/design/wildbound-expansion-bible.md sections 2 (Frozen Mountains), 4 (Yeti tracks) and
5.4. Snow records Yeti tracks and rock does not, so every shelf and overhang lists the rectangle
under which no track is recorded; shelves laid across the trail cut the Yeti's track chain.
Prop sizes are the measured Blender kit values (assets/blender/frozen-mountains-kit).
"""

import argparse
import json
import math
import random
import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import layout_geometry as g  # noqa: E402
import layout_render as render  # noqa: E402

DEFAULT_SEED = 20261109
LAYOUT_NAME = "frozen-mountains-layout-v1"
DEFAULT_OUT_DIR = TOOLS.parent / "assets" / "maps" / "frozen-mountains-layout"

# ---- Spec inputs (bible section 2, 4 and 5.4) -------------------------------------------
MAP_SIZE = 500.0
LIMIT = MAP_SIZE / 2 - 5.0
MAX_INSTANCES, MAX_TRIANGLES = 170, 40000
MIX = (("FM_SnowPine", 60), ("FM_IceSpire", 18), ("FM_RockOverhang", 8), ("FM_ScourShelf", 24),
       ("FM_Cairn", 16), ("FM_SnowMound", 20), ("FM_IcePass", 2))
WALK_SPEED = 16.0
CORRIDOR_HALF = 7.0
TRACK_SPACING, MAX_TRACKS = 6.0, 24   # one Yeti track every 6 studs on snow, 24 per player (section 4)

# Draft route from the south-west gate up the slopes. Hand-placed: long straights for the two
# passes, and a bend between the passes so the way is not a single line.
ROUTE_NODES = (("gate_south", (-225.0, 190.0)), ("foothill", (-140.0, 130.0)), ("saddle", (-60.0, 140.0)),
               ("snowfield", (20.0, 70.0)), ("cornice", (90.0, 10.0)), ("high_slope", (160.0, -60.0)),
               ("ridge", (200.0, -130.0)), ("gate_north", (225.0, -195.0)))
ROUTE = [p for _, p in ROUTE_NODES]
YETI_HOME = (110.0, -150.0)   # draft spawn point; no shelter may sit within 40 studs of it
SHELTER_YETI_CLEAR = 40.0

PROPS = {
    "FM_SnowPine": {"kind": "pine", "tris": 298, "budget": 360, "parts": 3, "r": 1.6, "canopy_r": 9.1,
                    "scale": (0.9, 1.15)},
    "FM_IceSpire": {"kind": "spire", "tris": 162, "budget": 180, "parts": 2, "r": 3.6, "scale": (0.9, 1.2),
                    "gather_local_z": -3.0},
    "FM_RockOverhang": {"kind": "overhang", "tris": 328, "budget": 340, "parts": 2, "half": (10.0, 6.1),
                        "no_track": ((0.0, -2.0), (12.0, 8.0))},
    "FM_ScourShelf": {"kind": "shelf", "tris": 120, "budget": 120, "parts": 1, "r": 8.05,
                      "no_track": ((0.0, 0.0), (9.224, 9.224))},
    "FM_Cairn": {"kind": "cairn", "tris": 100, "budget": 120, "parts": 2, "r": 2.05},
    "FM_SnowMound": {"kind": "mound", "tris": 58, "budget": 60, "parts": 1, "r": 3.2, "scale": (0.85, 1.1)},
    "FM_IcePass": {"kind": "pass", "tris": 478, "budget": 520, "parts": 2, "half": (15.1, 7.15),
                   "passage": (-8.7688, 8.6995), "clear_h": 11.3},
}
SHORT = {"FM_SnowPine": "pine", "FM_IceSpire": "spire", "FM_RockOverhang": "overhang", "FM_ScourShelf": "shelf",
         "FM_Cairn": "cairn", "FM_SnowMound": "mound", "FM_IcePass": "pass"}

# Design thresholds chosen by this draft.
BASE_GAP = 1.0
PINE_ROUTE_CENTRE = 14.0
PINE_SPACING = 12.0
CAIRN_OFFSET = 9.5
CAIRN_SPACING = 26.0
BREAK_SHELVES = 10        # shelves laid across the trail, evenly along it
PASS_ARCS = (55.0, 435.0)
GROVES, GROVE_SIZES = 6, (8, 8, 8, 8, 8, 8)


def r3(value):
    return round(float(value), 3) + 0.0


def make_instance(name, x, z, yaw, scale, **extra):
    yaw = r3(yaw % 360.0)
    return {"name": name, "x": r3(x), "z": r3(z), "rotation_y_deg": 0.0 if yaw >= 360.0 else yaw,
            "scale": r3(scale), **extra}


def footprint(inst):
    spec, s = PROPS[inst["name"]], inst["scale"]
    if "r" in spec:
        return g.Circle(inst["x"], inst["z"], spec["r"] * (s if spec["kind"] in ("pine", "spire", "mound") else 1.0))
    return g.rect_poly(inst["x"], inst["z"], spec["half"][0], spec["half"][1], inst["rotation_y_deg"])


def local_to_world(inst, local_x, local_z):
    r = math.radians(inst["rotation_y_deg"])
    return (inst["x"] + local_x * math.cos(r) + local_z * math.sin(r),
            inst["z"] - local_x * math.sin(r) + local_z * math.cos(r))


def no_track_poly(inst):
    (cx, cz), (sx, sz) = PROPS[inst["name"]]["no_track"]
    centre = local_to_world(inst, cx, cz)
    return g.rect_poly(centre[0], centre[1], sx / 2, sz / 2, inst["rotation_y_deg"]), centre


def gather_point(inst):
    return local_to_world(inst, 0.0, PROPS["FM_IceSpire"]["gather_local_z"] * inst["scale"])


ROUTE_LENGTH = g.polyline_length(ROUTE)


def route_distance(p):
    return g.project_to_polyline(ROUTE, p)[0]


class Placer:
    def __init__(self):
        self.items = []  # (inst, shape, kind)

    def add(self, inst):
        self.items.append((inst, footprint(inst), PROPS[inst["name"]]["kind"]))

    def valid(self, inst):
        kind = PROPS[inst["name"]]["kind"]
        shape = footprint(inst)
        x0, z0, x1, z1 = g.shape_bbox(shape)
        if min(x0, z0) < -LIMIT or max(x1, z1) > LIMIT:
            return False
        anchor = (inst["x"], inst["z"])
        route_gap = g.shape_polyline_dist(shape, ROUTE)
        if kind in ("pine", "spire", "overhang"):
            if route_gap < CORRIDOR_HALF + BASE_GAP:
                return False
        elif kind == "cairn":
            if route_gap < CORRIDOR_HALF + 0.2:
                return False
        elif kind == "mound" and route_gap < 4.0:
            return False
        if kind == "pine" and route_distance(anchor) < PINE_ROUTE_CENTRE:
            return False
        if kind == "overhang":
            poly, centre = no_track_poly(inst)
            if not 14.0 <= route_distance(centre) <= 50.0 or route_distance(centre) >= route_distance(anchor):
                return False
            if g.shape_point_dist(poly, YETI_HOME) < SHELTER_YETI_CLEAR:
                return False
        if kind == "spire":
            point = gather_point(inst)
            distance = route_distance(point)
            if not 8.0 <= distance <= 55.0 or distance >= route_distance(anchor):
                return False
        for other, other_shape, other_kind in self.items:
            if "mound" in (kind, other_kind):
                needed = 0.3
            else:
                needed = BASE_GAP
            if kind == "pine" == other_kind and math.dist(anchor, (other["x"], other["z"])) < PINE_SPACING:
                return False
            if g.shape_gap(shape, other_shape) < needed:
                return False
            if kind == "spire" and other_kind != "mound" and g.shape_point_dist(other_shape, gather_point(inst)) < BASE_GAP:
                return False
            if other_kind == "spire" and kind != "mound" and g.shape_point_dist(shape, gather_point(other)) < BASE_GAP:
                return False
        return True


class IdSource:
    def __init__(self):
        self.counts = {}

    def next(self, name):
        key = SHORT[name]
        self.counts[key] = self.counts.get(key, 0) + 1
        return f"{key}-{self.counts[key]:02d}"

    def release(self, name):
        self.counts[SHORT[name]] -= 1


def straight_here(arc, margin):
    """True when the route stays on one segment for margin studs either side of arc."""
    walked = 0.0
    for a, b in zip(ROUTE, ROUTE[1:]):
        length = math.dist(a, b)
        if walked < arc < walked + length:
            return arc - walked >= margin and walked + length - arc >= margin
        walked += length
    return False


def facing_route(x, z):
    """Yaw whose local -Z (the open or gather side) points at the nearest route point."""
    foot = g.project_to_polyline(ROUTE, (x, z))
    nearest = g.polyline_point(ROUTE, foot[1])[0]
    return g.heading_deg(-(nearest[0] - x), -(nearest[1] - z))


def side_point(rng, lateral_low, lateral_high):
    point, direction, _ = g.polyline_point(ROUTE, rng.uniform(0.0, ROUTE_LENGTH))
    lateral = rng.choice((-1, 1)) * rng.uniform(lateral_low, lateral_high)
    return point[0] - direction[1] * lateral, point[1] + direction[0] * lateral


def random_point(rng):
    return rng.uniform(-LIMIT, LIMIT), rng.uniform(-LIMIT, LIMIT)


def place_passes(placer, ids):
    passes = []
    for arc in PASS_ARCS:
        point, direction, _ = g.polyline_point(ROUTE, arc)
        assert straight_here(arc, PROPS["FM_IcePass"]["half"][1] + 1.0)
        inst = make_instance("FM_IcePass", point[0], point[1], g.heading_deg(*direction), 1.0, id=ids.next("FM_IcePass"))
        assert placer.valid(inst), f"pass at arc {arc} does not fit"
        placer.add(inst)
        passes.append(inst)
    return passes


def place_break_shelves(placer, ids, rng):
    """Shelves centred on the trail: the Yeti records no track while a walker crosses one."""
    shelves = []
    spacing = (ROUTE_LENGTH - 70.0) / (BREAK_SHELVES - 1)
    for k in range(BREAK_SHELVES):
        base, placed = 35.0 + spacing * k, None
        for delta in (0.0, 6.0, -6.0, 12.0, -12.0, 18.0, -18.0, 24.0, -24.0, 30.0, -30.0):
            arc = base + delta
            if not 9.5 < arc < ROUTE_LENGTH - 9.5 or not straight_here(arc, 9.5):
                continue
            point, direction, _ = g.polyline_point(ROUTE, arc)
            lateral = rng.uniform(-1.5, 1.5)
            inst = make_instance("FM_ScourShelf", point[0] - direction[1] * lateral, point[1] + direction[0] * lateral,
                                 rng.uniform(0.0, 360.0), 1.0, id=ids.next("FM_ScourShelf"))
            if placer.valid(inst):
                placed = inst
                break
            ids.release("FM_ScourShelf")
        assert placed, f"no room for break shelf {k}"
        placer.add(placed)
        shelves.append(placed)
    return shelves


def place_cairns(placer, ids):
    count = dict(MIX)["FM_Cairn"]
    spacing = (ROUTE_LENGTH - 60.0) / (count - 1)
    cairns, arcs = [], []
    for k in range(count):
        base, placed = 30.0 + spacing * k, None
        for delta in (0.0, 4.0, -4.0, 8.0, -8.0, 12.0, -12.0, 16.0, -16.0, 20.0, -20.0):
            arc = min(max(base + delta, 6.0), ROUTE_LENGTH - 6.0)
            if arcs and arc - arcs[-1] < CAIRN_SPACING:
                continue
            point, direction, _ = g.polyline_point(ROUTE, arc)
            for side in ((1, -1) if k % 2 == 0 else (-1, 1)):
                inst = make_instance("FM_Cairn", point[0] - direction[1] * CAIRN_OFFSET * side,
                                     point[1] + direction[0] * CAIRN_OFFSET * side, 0.0, 1.0, id=ids.next("FM_Cairn"))
                if placer.valid(inst):
                    placed = (inst, arc)
                    break
                ids.release("FM_Cairn")
            if placed:
                break
        assert placed, f"no room for cairn {k}"
        placer.add(placed[0])
        cairns.append(placed[0])
        arcs.append(placed[1])
    return cairns


def place_overhangs(placer, ids, rng):
    overhangs, attempts = [], 0
    while len(overhangs) < dict(MIX)["FM_RockOverhang"]:
        attempts += 1
        assert attempts < 40000, "could not place every overhang"
        x, z = side_point(rng, 24.0, 46.0)
        inst = make_instance("FM_RockOverhang", x, z, facing_route(x, z), 1.0, id=ids.next("FM_RockOverhang"))
        if placer.valid(inst):
            placer.add(inst)
            overhangs.append(inst)
        else:
            ids.release("FM_RockOverhang")
    return overhangs


def place_pines(placer, ids, rng):
    target, spec = dict(MIX)["FM_SnowPine"], PROPS["FM_SnowPine"]
    pines, centres = [], []

    def try_pine(x, z):
        inst = make_instance("FM_SnowPine", x, z, rng.uniform(0.0, 360.0), rng.uniform(*spec["scale"]),
                             id=ids.next("FM_SnowPine"))
        if placer.valid(inst):
            placer.add(inst)
            pines.append(inst)
            return True
        ids.release("FM_SnowPine")
        return False

    for _ in range(6000):
        if len(centres) == GROVES:
            break
        c = random_point(rng)
        if 40.0 <= route_distance(c) <= 100.0 and all(math.dist(c, o) >= 90.0 for o in centres):
            centres.append(c)
    for centre, want in zip(centres, GROVE_SIZES):
        got = attempts = 0
        while got < want and attempts < 500:
            attempts += 1
            angle, radius = rng.uniform(0.0, math.tau), rng.uniform(13.0, 40.0)
            got += try_pine(centre[0] + radius * math.cos(angle), centre[1] + radius * math.sin(angle))
    attempts = 0
    while len(pines) < target:
        attempts += 1
        assert attempts < 60000, "could not place every pine"
        try_pine(*random_point(rng))
    return pines


def place_spires(placer, ids, rng):
    spires, attempts = [], 0
    spec = PROPS["FM_IceSpire"]
    while len(spires) < dict(MIX)["FM_IceSpire"]:
        attempts += 1
        assert attempts < 40000, "could not place every spire"
        x, z = side_point(rng, 14.0, 45.0)
        inst = make_instance("FM_IceSpire", x, z, facing_route(x, z), rng.uniform(*spec["scale"]),
                             id=ids.next("FM_IceSpire"))
        if placer.valid(inst):
            placer.add(inst)
            spires.append(inst)
        else:
            ids.release("FM_IceSpire")
    return spires


def place_flank_shelves(placer, ids, rng, count):
    shelves, attempts = [], 0
    while len(shelves) < count:
        attempts += 1
        assert attempts < 40000, "could not place every flank shelf"
        x, z = random_point(rng)
        inst = make_instance("FM_ScourShelf", x, z, rng.uniform(0.0, 360.0), 1.0, id=ids.next("FM_ScourShelf"))
        if route_distance((x, z)) >= 20.0 and placer.valid(inst):
            placer.add(inst)
            shelves.append(inst)
        else:
            ids.release("FM_ScourShelf")
    return shelves


def place_mounds(placer, ids, rng):
    mounds, attempts = [], 0
    spec = PROPS["FM_SnowMound"]
    while len(mounds) < dict(MIX)["FM_SnowMound"]:
        attempts += 1
        assert attempts < 40000, "could not place every mound"
        x, z = random_point(rng)
        inst = make_instance("FM_SnowMound", x, z, rng.uniform(0.0, 360.0), rng.uniform(*spec["scale"]),
                             id=ids.next("FM_SnowMound"))
        if placer.valid(inst):
            placer.add(inst)
            mounds.append(inst)
        else:
            ids.release("FM_SnowMound")
    return mounds


def track_report(sources):
    """Walk the route dropping a Yeti track every 6 studs; rock records none."""
    rects = [no_track_poly(i)[0] for i in sources]
    chains, run, skipped, points = [], 0, 0, 0
    for k in range(int(ROUTE_LENGTH / TRACK_SPACING) + 1):
        points += 1
        point = g.polyline_point(ROUTE, k * TRACK_SPACING)[0]
        if any(g.poly_contains(r.pts, point) for r in rects):
            skipped += 1
            if run:
                chains.append(run)
            run = 0
        else:
            run += 1
    chains.append(run)
    return {"spacing": TRACK_SPACING, "max_points_per_player": MAX_TRACKS, "points": points, "skipped": skipped,
            "chains": [c * TRACK_SPACING for c in chains], "longest_chain_studs": max(chains) * TRACK_SPACING}


def sight_blocker_fraction(instances):
    blockers = [(i["x"], i["z"], 15.0) for i in instances if i["name"] == "FM_SnowPine"]
    blockers += [(i["x"], i["z"], 16.0) for i in instances if i["name"] in ("FM_RockOverhang", "FM_IcePass")]
    near = total = 0
    for ix in range(-245, 246, 10):
        for iz in range(-245, 246, 10):
            total += 1
            near += any(math.hypot(ix - x, iz - z) <= r for x, z, r in blockers)
    return near / total


def generate(seed=DEFAULT_SEED):
    rng = random.Random(seed)
    placer, ids = Placer(), IdSource()
    passes = place_passes(placer, ids)
    break_shelves = place_break_shelves(placer, ids, rng)
    cairns = place_cairns(placer, ids)
    overhangs = place_overhangs(placer, ids, rng)
    pines = place_pines(placer, ids, rng)
    spires = place_spires(placer, ids, rng)
    flank = place_flank_shelves(placer, ids, rng, dict(MIX)["FM_ScourShelf"] - len(break_shelves))
    mounds = place_mounds(placer, ids, rng)
    instances = pines + spires + overhangs + break_shelves + flank + cairns + mounds + passes
    by_name = {}
    for name, count in MIX:
        assert len([i for i in instances if i["name"] == name]) == count, name
        by_name[name] = {"count": count, "triangles": count * PROPS[name]["tris"]}
    sources = [i for i in instances if i["name"] in ("FM_ScourShelf", "FM_RockOverhang")]
    rects = []
    for source in sources:
        poly, centre = no_track_poly(source)
        rects.append({"source": source["id"], "name": source["name"], "center": [r3(centre[0]), r3(centre[1])],
                      "size": list(PROPS[source["name"]]["no_track"][1]), "yaw": source["rotation_y_deg"],
                      "polygon": [[r3(x), r3(z)] for x, z in poly.pts]})
    return {
        "name": LAYOUT_NAME,
        "status": "draft, unvalidated: never imported into Roblox, played or measured on a device",
        "seed": seed,
        "map_size": MAP_SIZE,
        "caps": {"instances": MAX_INSTANCES, "triangles": MAX_TRIANGLES},
        "totals": {
            "instances": len(instances),
            "triangles_measured": sum(v["triangles"] for v in by_name.values()),
            "triangles_budget": sum(c * PROPS[n]["budget"] for n, c in MIX),
            "mesh_parts": sum(c * PROPS[n]["parts"] for n, c in MIX),
            "by_name": by_name,
        },
        "route": {"nodes": [list(p) for p in ROUTE], "names": [n for n, _ in ROUTE_NODES],
                  "length": r3(ROUTE_LENGTH), "walk_seconds": r3(ROUTE_LENGTH / WALK_SPEED),
                  "corridor_width": 2 * CORRIDOR_HALF},
        "yeti_home": list(YETI_HOME),
        "no_track_rects": rects,
        "tracks": track_report(sources),
        "density": {"near_sight_blocker_fraction": round(sight_blocker_fraction(instances), 4),
                    "props_per_1000_sq_studs": round(len(instances) / (MAP_SIZE * MAP_SIZE / 1000.0), 3)},
        "instances": instances,
    }


def to_json(layout):
    return json.dumps(layout, indent=1) + "\n"


# ---- Drawing ----------------------------------------------------------------
CANVAS = (1300, 1000)
MAP_X0, MAP_Y0, MAP_SCALE = 30.0, 70.0, 1.8


def build_scene(layout):
    scene = render.Scene(*CANVAS)
    world = render.World(MAP_SCALE, MAP_X0, MAP_Y0, MAP_SIZE / 2)
    s = MAP_SCALE
    scene.text(MAP_X0, 34, "Frozen Mountains placement plan v1 - DRAFT, unvalidated - top-down", size=22, bold=True)
    scene.text(MAP_X0, 54, "seed %d | 500 x 500 studs | north (-z) is up | symbols enlarged" % layout["seed"], size=13,
               fill="#444444")
    scene.rect(world.px(-250), world.py(-250), 500 * s, 500 * s, fill="#eef4f8", stroke="#222222", sw=2)
    for v in range(-250, 251, 50):
        scene.line([(world.px(v), world.py(-250)), (world.px(v), world.py(250))], stroke="#000000", sw=0.8, so=0.10)
        scene.line([(world.px(-250), world.py(v)), (world.px(250), world.py(v))], stroke="#000000", sw=0.8, so=0.10)
        scene.text(world.px(v), world.py(250) + 18, str(v), size=11, fill="#555555", anchor="middle")
        scene.text(world.px(-250) - 6, world.py(v) + 4, str(v), size=11, fill="#555555", anchor="end")
    by = {name: [i for i in layout["instances"] if i["name"] == name] for name, _ in MIX}
    scene.line([world.pt(p) for p in ROUTE], stroke="#d8c9a3", sw=2 * CORRIDOR_HALF * s, so=0.9)
    scene.line([world.pt(p) for p in ROUTE], stroke="#6b5320", sw=1.2, dash=(8, 6))
    for shelf in by["FM_ScourShelf"]:
        scene.circle(world.px(shelf["x"]), world.py(shelf["z"]), 8.05 * s, fill="#7d8791", fo=0.75, stroke="#333333", sw=1)
    for rect in layout["no_track_rects"]:
        scene.poly([world.pt(p) for p in rect["polygon"]], fill="#c0392b", fo=0.12, stroke="#c0392b", sw=1.2, dash=(4, 3))
    for inst in by["FM_RockOverhang"]:
        scene.poly([world.pt(p) for p in footprint(inst).pts], fill="#566069", fo=0.85, stroke="#111111", sw=1.4)
    for inst in by["FM_IcePass"]:
        scene.poly([world.pt(p) for p in footprint(inst).pts], fill="#9ccbe0", fo=0.5, stroke="#111111", sw=1.6)
    for pine in by["FM_SnowPine"]:
        scene.circle(world.px(pine["x"]), world.py(pine["z"]), 9.1 * pine["scale"] * s, fill="#2f5450", fo=0.10)
    for mound in by["FM_SnowMound"]:
        scene.circle(world.px(mound["x"]), world.py(mound["z"]), 3.0, fill="#ffffff", stroke="#8aa0ad", sw=1)
    for pine in by["FM_SnowPine"]:
        scene.circle(world.px(pine["x"]), world.py(pine["z"]), 4.2, fill="#2f5450", stroke="#ffffff", sw=0.8)
    for spire in by["FM_IceSpire"]:
        x, y = world.px(spire["x"]), world.py(spire["z"])
        scene.poly([(x, y - 7), (x + 5, y + 5), (x - 5, y + 5)], fill="#9ccbe0", stroke="#2b5d78", sw=1)
        gx, gz = gather_point(spire)
        scene.circle(world.px(gx), world.py(gz), 2.2, fill="#ffffff", stroke="#2b5d78", sw=0.8)
    for cairn in by["FM_Cairn"]:
        scene.rect(world.px(cairn["x"]) - 4, world.py(cairn["z"]) - 4, 8, 8, fill="#e0602a", stroke="#111111", sw=0.8)
    for name, (x, z) in ROUTE_NODES:
        scene.circle(world.px(x), world.py(z), 5, fill="#ffffff", stroke="#3a2f12", sw=2)
        scene.text(world.px(x) + 10, world.py(z) - 9, name, size=12, bold=True, fill="#3a2f12")
    yx, yz = world.px(YETI_HOME[0]), world.py(YETI_HOME[1])
    scene.circle(yx, yz, 7, fill="#222222", stroke="#ffffff", sw=1.4)
    scene.circle(yx, yz, SHELTER_YETI_CLEAR * s, stroke="#222222", sw=1.2, dash=(5, 5))
    scene.text(yx + 10, yz - 10, "Yeti home (draft)", size=12, bold=True)
    # Legend and totals.
    x0, y = 1000.0, 100.0
    t = layout["totals"]
    scene.text(x0, y, "Legend", size=17, bold=True)
    rows = [("Trail 14 wide (centreline dashed)", "#d8c9a3"), ("Scoured shelf (r 8): no tracks", "#7d8791"),
            ("No-track rectangle", "#c0392b"), ("Rock overhang, open to the trail", "#566069"),
            ("Ice pass over the trail", "#9ccbe0"), ("Snow pine, shade r 9.1", "#2f5450"),
            ("Ice spire, dot = gather side", "#9ccbe0"), ("Cairn", "#e0602a"), ("Snow mound", "#ffffff")]
    for label, colour in rows:
        y += 24
        scene.rect(x0, y - 12, 22, 14, fill=colour, stroke="#333333", sw=0.8)
        scene.text(x0 + 32, y, label, size=12)
    y += 40
    scene.text(x0, y, "Budget (draft)", size=17, bold=True)
    tr = layout["tracks"]
    for line in ["Instances %d / %d cap" % (t["instances"], MAX_INSTANCES),
                 "Triangles measured %s / %s cap" % (format(t["triangles_measured"], ","), format(MAX_TRIANGLES, ",")),
                 "Triangles at bible budgets %s" % format(t["triangles_budget"], ","),
                 "MeshParts %d" % t["mesh_parts"],
                 "Route %.0f studs, %.0f s at 16 studs/s" % (layout["route"]["length"], layout["route"]["walk_seconds"]),
                 "Longest track chain on the route %.0f studs" % tr["longest_chain_studs"],
                 "Near a sight blocker: %.0f%% of the sector" % (100 * layout["density"]["near_sight_blocker_fraction"])]:
        y += 22
        scene.text(x0, y, line, size=12)
    y += 40
    scene.text(x0, y, "Counts", size=17, bold=True)
    for name, entry in t["by_name"].items():
        y += 22
        scene.text(x0, y, "%s  %d x %d" % (name, entry["count"], PROPS[name]["tris"]), size=12)
    y += 40
    for line in ["Draft for a later sector design. Never imported into", "Roblox, played or measured on a phone."]:
        scene.text(x0, y, line, size=12, fill="#8e2a1f")
        y += 18
    return scene


def write_outputs(layout, out_dir):
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    written = []
    json_path = out_dir / (LAYOUT_NAME + ".json")
    json_path.write_bytes(to_json(layout).encode("utf-8"))
    written.append(json_path)
    scene = build_scene(layout)
    svg_path = out_dir / (LAYOUT_NAME + ".svg")
    svg_path.write_bytes(scene.to_svg().encode("utf-8"))
    written.append(svg_path)
    try:
        import PIL  # noqa: F401
    except ImportError:
        return written
    png_path = out_dir / (LAYOUT_NAME + ".png")
    scene.to_png(png_path)
    written.append(png_path)
    return written


def summary(layout):
    t = layout["totals"]
    lines = ["seed %d: %d instances (cap %d), %d triangles measured, %d at bible budgets (cap %d), %d MeshParts"
             % (layout["seed"], t["instances"], MAX_INSTANCES, t["triangles_measured"], t["triangles_budget"],
                MAX_TRIANGLES, t["mesh_parts"])]
    lines += ["  %-16s x%-3d %6d tris" % (k, v["count"], v["triangles"]) for k, v in t["by_name"].items()]
    lines.append("route %.0f studs (%.1f s), %d no-track rects, longest track chain %.0f studs, "
                 "near a sight blocker %.1f%%" % (layout["route"]["length"], layout["route"]["walk_seconds"],
                                                  len(layout["no_track_rects"]), layout["tracks"]["longest_chain_studs"],
                                                  100 * layout["density"]["near_sight_blocker_fraction"]))
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    args = parser.parse_args(argv)
    layout = generate(args.seed)
    for path in write_outputs(layout, args.out_dir):
        print("wrote", path)
    print(summary(layout))
    return 0


if __name__ == "__main__":
    sys.exit(main())

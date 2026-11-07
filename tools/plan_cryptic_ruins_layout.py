#!/usr/bin/env python3
"""Reproducible top-down placement DRAFT for one Cryptic Ruins sector (unvalidated).

This is a plan only: it writes JSON, SVG and (when Pillow is importable) PNG files and never
touches the Luau map builder, Studio or Blender. Python standard library only; Pillow is
optional. The plan stays a draft for a later sector design: it is not an approved layout, was
never imported into Roblox, and no budget in it was measured on a device.

    python tools/plan_cryptic_ruins_layout.py [--seed N] [--out-dir DIR]

Conventions (studs, origin at the sector centre): x grows east, z grows south,
rotation_y_deg is CFrame.Angles(0, math.rad(r), 0) (see tools/layout_geometry.py). Kit frame to
plan frame: local x = -Blender x, local z = Blender y.
Spec: docs/design/wildbound-expansion-bible.md sections 2 (Cryptic Ruins), 4 (El Vigia) and 5.7.
Sight is the game: walls block it, so every instance of a colonnade, wall or archway records the
invisible occluder boxes (from the measured kit report) that Studio would build as CanQuery parts.
The 14 plinths form El Vigia's visible chain; reliquaries sit in three-wall alcoves that hide them
from most plinths, and the plan reports how much of the trail the plinths can see.
Prop sizes are the measured Blender kit values (assets/blender/cryptic-ruins-kit).
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

DEFAULT_SEED = 20261112
LAYOUT_NAME = "cryptic-ruins-layout-v1"
DEFAULT_OUT_DIR = TOOLS.parent / "assets" / "maps" / "cryptic-ruins-layout"

# ---- Spec inputs (bible section 2, 4 and 5.7) -------------------------------------------
MAP_SIZE = 300.0
LIMIT = MAP_SIZE / 2 - 5.0
MAX_INSTANCES, MAX_TRIANGLES = 120, 30000
MIX = (("CR_Colonnade", 14), ("CR_BrokenWall", 40), ("CR_Plinth", 14), ("CR_Archway", 6), ("CR_Reliquary", 8),
       ("CR_GlyphStone", 12), ("CR_StairRun", 8))
WALK_SPEED = 16.0
CORRIDOR_HALF = 7.0
SIGHT_RANGE = 70.0

# Draft route: a walk through five courts, an archway at the middle of each of the first six legs.
ROUTE_NODES = (("gate_south", (-120.0, 140.0)), ("outer_court", (-120.0, 70.0)), ("colonnade_walk", (-30.0, 70.0)),
               ("glyph_court", (-30.0, -20.0)), ("reliquary_court", (70.0, -20.0)), ("overlook", (70.0, -90.0)),
               ("inner_sanctum", (-60.0, -90.0)), ("gate_north", (-60.0, -140.0)))
ROUTE = [p for _, p in ROUTE_NODES]
# El Vigia's chain of plinths, 24 to 40 studs apart (bible section 4), crossing the trail twice.
VIGIA = [(-80.0, 125.0), (-70.0, 95.0), (-60.0, 57.0), (-60.0, 25.0), (-60.0, -14.0), (-45.0, -45.0),
         (-20.0, -65.0), (10.0, -55.0), (40.0, -45.0), (40.0, -6.0), (70.0, 12.0), (95.0, -10.0),
         (100.0, -45.0), (97.0, -80.0)]

# Measured kit values: "tris" and "parts" from cryptic-ruins-kit-report.json, "budget" from the
# bible table. "half" are conservative half extents (local X, local Z) of the measured geometry.
PROPS = {
    "CR_Colonnade": {"kind": "colonnade", "tris": 384, "budget": 420, "parts": 2, "half": (12.7, 2.6)},
    "CR_BrokenWall": {"kind": "wall", "tris": 228, "budget": 260, "parts": 2, "half": (7.1, 1.7)},
    "CR_Plinth": {"kind": "plinth", "tris": 96, "budget": 100, "parts": 2, "half": (3.0, 3.0)},
    "CR_Archway": {"kind": "arch", "tris": 396, "budget": 560, "parts": 2, "half": (14.25, 4.2),
                   "passage": (-7.4145, 7.2338), "clear_h": 11.4},
    "CR_Reliquary": {"kind": "reliquary", "tris": 164, "budget": 200, "parts": 2, "half": (4.05, 2.05)},
    "CR_GlyphStone": {"kind": "glyph", "tris": 96, "budget": 120, "parts": 2, "half": (2.05, 1.6)},
    "CR_StairRun": {"kind": "stair", "tris": 108, "budget": 180, "parts": 1, "half": (8.0, 6.05)},
}
SHORT = {"CR_Colonnade": "colonnade", "CR_BrokenWall": "wall", "CR_Plinth": "plinth", "CR_Archway": "arch",
         "CR_Reliquary": "reliquary", "CR_GlyphStone": "glyph", "CR_StairRun": "stair"}
# Occluder boxes from the kit report, in Blender axes: name, centre (x, y, z), size (x, y, z).
OCCLUDERS = {
    "CR_Colonnade": [("column_0", (-10.3, 0.0, 5.5), (3.9, 4.6, 11.0)), ("column_1", (0.0, 0.0, 5.5), (3.9, 4.6, 11.0)),
                     ("column_2", (10.3, 0.0, 5.5), (3.9, 4.6, 11.0))],
    "CR_BrokenWall": [("wall", (0.0, 0.0, 3.5), (14.3, 3.0, 7.0))],
    "CR_Archway": [("pier_left", (-10.8, 0.0, 5.5), (6.4, 6.8, 11.0)), ("pier_right", (10.8, 0.0, 5.5), (6.4, 6.8, 11.0))],
}

# Design thresholds chosen by this draft.
BASE_GAP = 1.0
# Colonnade pairs: (leg, arcs into the leg). They stay 20.7 from either end of a leg (corner corridor) and
# 17.9 from the archway at mid leg.
FLANK_PAIRS = ((1, (24.0,)), (2, (66.0,)), (3, (26.0,)), (5, (100.0,)))
FLANK_LATERAL = 11.5
OVERLOOK_PLAN = ((0, 0.5, 1), (2, 0.5, 1), (5, 0.5, 1), (6, 0.5, -1))   # (leg, relative arc, side)
OVERLOOK_LATERAL = 23.5
STAIR_OFFSET = 6.55          # landing ends 1 stud apart
ALCOVE_D = 10.4              # centre to wall centre; corner gaps of 1.7 stay open
ALCOVE_DISTANCE = (20.0, 36.0)
ALCOVE_EXPOSED_MAX = 2
SCREEN_COUNT = 16
GLYPH_LATERAL = 11.0
GLYPH_ARCS = (20.0, 60.0, 130.0, 165.0, 250.0, 320.0, 355.0, 400.0, 432.0, 464.0, 500.0, 560.0)  # in the free windows
EXPOSURE_STEP = 8.0


def r3(value):
    return round(float(value), 3) + 0.0


def make_instance(name, x, z, yaw, **extra):
    yaw = r3(yaw % 360.0)
    return {"name": name, "x": r3(x), "z": r3(z), "rotation_y_deg": 0.0 if yaw >= 360.0 else yaw, "scale": 1.0,
            **extra}


def yaw_for_x_axis(v):
    """Yaw whose local +X axis points along the vector v."""
    return math.degrees(math.atan2(-v[1], v[0])) % 360.0


def local_to_world(inst, local_x, local_z):
    r = math.radians(inst["rotation_y_deg"])
    return (inst["x"] + local_x * math.cos(r) + local_z * math.sin(r),
            inst["z"] - local_x * math.sin(r) + local_z * math.cos(r))


def footprint(inst):
    half = PROPS[inst["name"]]["half"]
    return g.rect_poly(inst["x"], inst["z"], half[0], half[1], inst["rotation_y_deg"])


def occluder_records(inst):
    records = []
    for name, (cx, cy, cz), (sx, sy, sz) in OCCLUDERS.get(inst["name"], []):
        centre = local_to_world(inst, -cx, cy)
        records.append({"name": name, "center": [r3(centre[0]), r3(centre[1])], "size": [sx, sy], "height": sz,
                        "base": r3(cz - sz / 2), "rotation_y_deg": inst["rotation_y_deg"]})
    return records


def occluder_poly(record):
    return g.rect_poly(record["center"][0], record["center"][1], record["size"][0] / 2, record["size"][1] / 2,
                       record["rotation_y_deg"])


ROUTE_LENGTH = g.polyline_length(ROUTE)
LEG_STARTS = [0.0]
for _a, _b in zip(ROUTE, ROUTE[1:]):
    LEG_STARTS.append(LEG_STARTS[-1] + math.dist(_a, _b))


def route_distance(p):
    return g.project_to_polyline(ROUTE, p)[0]


def at_lateral(arc, lateral):
    point, direction, _ = g.polyline_point(ROUTE, arc)
    return (point[0] - direction[1] * lateral, point[1] + direction[0] * lateral), direction


def leg_arc(leg, rel):
    return LEG_STARTS[leg] + rel * (LEG_STARTS[leg + 1] - LEG_STARTS[leg])


class Placer:
    def __init__(self):
        self.items = []   # (inst, shape)
        self.lanes = []   # reliquary access lanes kept clear

    def add(self, inst):
        if inst["name"] in OCCLUDERS:
            inst["occluders"] = occluder_records(inst)
        self.items.append((inst, footprint(inst)))

    def valid(self, inst, extra=()):
        shape = footprint(inst)
        x0, z0, x1, z1 = g.shape_bbox(shape)
        if min(x0, z0) < -LIMIT or max(x1, z1) > LIMIT:
            return False
        if inst["name"] != "CR_Archway" and g.shape_polyline_dist(shape, ROUTE) < CORRIDOR_HALF + BASE_GAP:
            return False
        if any(g.shape_segment_dist(shape, a, b) < 1.0 for a, b in self.lanes):
            return False
        for _, other in self.items:
            if g.shape_gap(shape, other) < BASE_GAP:
                return False
        for other in extra:
            if g.shape_gap(shape, footprint(other)) < BASE_GAP:
                return False
        return True

    def occluders(self, extra=()):
        polys = [occluder_poly(r) for inst, _ in self.items for r in inst.get("occluders", [])]
        polys += [occluder_poly(r) for inst in extra for r in occluder_records(inst)]
        return polys


class IdSource:
    def __init__(self):
        self.counts = {}

    def next(self, name):
        key = SHORT[name]
        self.counts[key] = self.counts.get(key, 0) + 1
        return f"{key}-{self.counts[key]:02d}"


def clear_sight(polys, a, b):
    return all(g.shape_segment_dist(p, a, b) > 0.0 for p in polys)


def exposed_plinths(polys, point):
    return sum(1 for p in VIGIA if math.dist(p, point) <= SIGHT_RANGE and clear_sight(polys, p, point))


def place_plinths(placer, ids):
    plinths = []
    for k, (x, z) in enumerate(VIGIA):
        other = VIGIA[k + 1] if k + 1 < len(VIGIA) else VIGIA[k - 1]
        sign = 1.0 if k + 1 < len(VIGIA) else -1.0
        yaw = g.heading_deg(sign * (other[0] - x), sign * (other[1] - z))
        inst = make_instance("CR_Plinth", x, z, yaw, id=ids.next("CR_Plinth"))
        assert placer.valid(inst), f"plinth {k} does not fit"
        placer.add(inst)
        plinths.append(inst)
    return plinths


def place_arches(placer, ids):
    arches = []
    for leg in range(6):
        point, direction, index = g.polyline_point(ROUTE, leg_arc(leg, 0.5))
        inst = make_instance("CR_Archway", point[0], point[1], g.heading_deg(*direction), id=ids.next("CR_Archway"))
        assert placer.valid(inst), f"archway on leg {leg} does not fit"
        placer.add(inst)
        arches.append(inst)
    return arches


def place_flank_colonnades(placer, ids):
    placed = []
    for leg, offsets in FLANK_PAIRS:
        for offset in offsets:
            base = LEG_STARTS[leg] + offset
            for delta in (0.0, 1.0, -1.0, 2.0, -2.0, 3.0, -3.0):
                made = []
                for side in (-1, 1):
                    point, direction = at_lateral(base + delta, side * FLANK_LATERAL)
                    made.append(make_instance("CR_Colonnade", point[0], point[1], yaw_for_x_axis(direction),
                                              id=ids.next("CR_Colonnade")))
                if all(placer.valid(m) for m in made):
                    for m in made:
                        placer.add(m)
                    placed.extend(made)
                    break
                ids.counts["colonnade"] -= 2
            else:
                raise AssertionError(f"no room for the colonnade pair on leg {leg}")
    return placed


def place_overlooks(placer, ids):
    stairs, records = [], []
    for leg, rel, side in OVERLOOK_PLAN:
        point, direction = at_lateral(leg_arc(leg, rel), side * OVERLOOK_LATERAL)
        heading = g.heading_deg(*direction)
        a = make_instance("CR_StairRun", point[0] - direction[0] * STAIR_OFFSET, point[1] - direction[1] * STAIR_OFFSET,
                          heading, id=ids.next("CR_StairRun"))
        b = make_instance("CR_StairRun", point[0] + direction[0] * STAIR_OFFSET, point[1] + direction[1] * STAIR_OFFSET,
                          heading + 180.0, id=ids.next("CR_StairRun"))
        assert placer.valid(a) and placer.valid(b, extra=[a]), f"overlook on leg {leg} does not fit"
        placer.add(a)
        placer.add(b)
        stairs.extend([a, b])
        records.append({"stairs": [a["id"], b["id"]], "center": [r3(point[0]), r3(point[1])], "leg": leg})
    return stairs, records


def place_glyphs(placer, ids):
    stones, last_arc = [], -1000.0
    for k, base in enumerate(GLYPH_ARCS):
        side = 1 if k % 2 == 0 else -1
        options = [(delta, s) for delta in (0.0, 2.0, -2.0, 4.0, -4.0, 6.0, -6.0) for s in (side, -side)]
        for delta, s in options:
            if base + delta - last_arc < 32.0:
                continue
            point, _ = at_lateral(base + delta, s * GLYPH_LATERAL)
            foot = g.polyline_point(ROUTE, g.project_to_polyline(ROUTE, point)[1])[0]
            inst = make_instance("CR_GlyphStone", point[0], point[1], g.heading_deg(-(foot[0] - point[0]), -(foot[1] - point[1])),
                                 id=ids.next("CR_GlyphStone"))
            if placer.valid(inst):
                placer.add(inst)
                stones.append(inst)
                last_arc = g.project_to_polyline(ROUTE, point)[1]
                break
            ids.counts["glyph"] -= 1
        else:
            raise AssertionError(f"no room for glyph stone {k}")
    return stones


def place_alcoves(placer, ids, rng):
    count = dict(MIX)["CR_Reliquary"]
    alcoves, bins = [], [ROUTE_LENGTH * k / count for k in range(count + 1)]
    for k in range(count):
        for _ in range(1200):
            arc = rng.uniform(bins[k] + 8.0, bins[k + 1] - 8.0)
            side = rng.choice((-1, 1))
            centre, direction = at_lateral(arc, side * rng.uniform(*ALCOVE_DISTANCE))
            foot = g.polyline_point(ROUTE, g.project_to_polyline(ROUTE, centre)[1])[0]
            back = (centre[0] - foot[0], centre[1] - foot[1])
            norm = math.hypot(*back)
            back = (back[0] / norm, back[1] / norm)
            perp = (-back[1], back[0])
            walls = [make_instance("CR_BrokenWall", centre[0] + back[0] * ALCOVE_D, centre[1] + back[1] * ALCOVE_D,
                                   yaw_for_x_axis(perp)),
                     make_instance("CR_BrokenWall", centre[0] + perp[0] * ALCOVE_D, centre[1] + perp[1] * ALCOVE_D,
                                   yaw_for_x_axis(back)),
                     make_instance("CR_BrokenWall", centre[0] - perp[0] * ALCOVE_D, centre[1] - perp[1] * ALCOVE_D,
                                   yaw_for_x_axis(back))]
            reliquary = make_instance("CR_Reliquary", centre[0], centre[1], yaw_for_x_axis(perp))
            group = walls + [reliquary]
            trial = []
            fits = True
            for inst in group:
                if not placer.valid(inst, extra=trial) or any(g.shape_segment_dist(footprint(o), centre, foot) < 0.5
                                                              for o in trial if o["name"] != "CR_Reliquary"):
                    fits = False
                    break
                trial.append(inst)
            if not fits or any(g.shape_segment_dist(shape, centre, foot) < 1.0 for _, shape in placer.items):
                continue
            exposed = exposed_plinths(placer.occluders(extra=walls), centre)
            if exposed > ALCOVE_EXPOSED_MAX:
                continue
            for wall in walls:
                wall["id"] = ids.next("CR_BrokenWall")
                placer.add(wall)
            reliquary["id"] = ids.next("CR_Reliquary")
            placer.add(reliquary)
            placer.lanes.append((centre, foot))
            alcoves.append({"reliquary": reliquary["id"], "wall_ids": [w["id"] for w in walls],
                            "open_toward": [r3(-back[0]), r3(-back[1])], "exposed_plinths": exposed})
            break
        else:
            raise AssertionError(f"no alcove found in bin {k}")
    return alcoves


def place_screens(placer, ids, rng):
    """Single walls turned to face the nearest plinth, beside the trail, to break sight on purpose."""
    screens, attempts, bin_tries = [], 0, 0
    while len(screens) < SCREEN_COUNT:
        attempts += 1
        assert attempts < 30000, "could not place every screen wall"
        bin_tries += 1
        if bin_tries <= 300:
            lo = ROUTE_LENGTH * len(screens) / SCREEN_COUNT
            arc = rng.uniform(lo, lo + ROUTE_LENGTH / SCREEN_COUNT)
        else:
            arc = rng.uniform(0.0, ROUTE_LENGTH)
        point, direction, _ = g.polyline_point(ROUTE, arc)
        plinth = min(VIGIA, key=lambda p: math.dist(p, point))
        if math.dist(plinth, point) > SIGHT_RANGE:
            continue
        sign = 1 if ((plinth[0] - point[0]) * -direction[1] + (plinth[1] - point[1]) * direction[0]) > 0 else -1
        centre, _ = at_lateral(arc, sign * rng.uniform(13.0, 24.0))
        if min(VIGIA, key=lambda p: math.dist(p, centre)) != plinth:
            continue
        toward = (plinth[0] - centre[0], plinth[1] - centre[1])
        norm = math.hypot(*toward)
        across = (-toward[1] / norm, toward[0] / norm)
        inst = make_instance("CR_BrokenWall", centre[0], centre[1], yaw_for_x_axis(across), id=ids.next("CR_BrokenWall"))
        if placer.valid(inst):
            placer.add(inst)
            screens.append(inst)
            bin_tries = 0
        else:
            ids.counts["wall"] -= 1
    return screens


def place_free_colonnades(placer, ids, rng, count):
    placed, attempts = [], 0
    while len(placed) < count:
        attempts += 1
        assert attempts < 40000, "could not place every colonnade"
        arc = rng.uniform(0.0, ROUTE_LENGTH)
        point, direction = at_lateral(arc, rng.choice((-1, 1)) * rng.uniform(22.0, 55.0))
        along = direction if rng.random() < 0.5 else (-direction[1], direction[0])
        inst = make_instance("CR_Colonnade", point[0], point[1], yaw_for_x_axis(along), id=ids.next("CR_Colonnade"))
        if placer.valid(inst):
            placer.add(inst)
            placed.append(inst)
        else:
            ids.counts["colonnade"] -= 1
    return placed


def route_exposure(placer):
    polys = placer.occluders()
    pairs = clear = 0
    for k in range(int(ROUTE_LENGTH / EXPOSURE_STEP) + 1):
        sample = g.polyline_point(ROUTE, k * EXPOSURE_STEP)[0]
        for plinth in VIGIA:
            if math.dist(sample, plinth) <= SIGHT_RANGE:
                pairs += 1
                clear += clear_sight(polys, plinth, sample)
    return clear / pairs, pairs


DECISIONS = [
    "El Vigia's chain is 14 plinths authored here (24 to 40 studs apart, bible section 4); the chain crosses the "
    "trail twice, so the contest is fought on the trail.",
    "Occluder boxes come straight from the kit report (columns 3.9 x 4.6 x 11, wall 14.3 x 3 x 7, piers 6.4 x 6.8 x "
    "11) and are recorded per instance with the measured base height; the shortest is 7 studs, above a standing avatar.",
    "Eight reliquaries sit in three-wall alcoves (24 walls) that open toward the trail, with a clear access lane; "
    "each alcove must be visible from at most two plinths. The other 16 walls are screens that face the nearest "
    "plinth, so a player can break line of sight on purpose.",
    "Stair runs are paired back to back as four overlook ridges 23.5 studs beside the trail; the bible gives "
    "stairs no purpose, so this is a draft choice.",
    "Archways straddle the trail on six different legs with the measured gap (0.09 off centre) containing the "
    "corridor; the pivot sits on the centreline.",
    "Colonnades: eight in flanking pairs 11.5 studs from the centreline, six scattered in the courts.",
    "A server ray is assumed to start above the walls the way a stilt walker's would; whether 7 stud walls hide "
    "a player from its head is untested (the bible leaves the ray start open).",
]


def generate(seed=DEFAULT_SEED):
    rng = random.Random(seed)
    placer, ids = Placer(), IdSource()
    plinths = place_plinths(placer, ids)
    arches = place_arches(placer, ids)
    flank = place_flank_colonnades(placer, ids)
    stairs, overlooks = place_overlooks(placer, ids)
    glyphs = place_glyphs(placer, ids)
    alcoves = place_alcoves(placer, ids, rng)
    screens = place_screens(placer, ids, rng)
    free = place_free_colonnades(placer, ids, rng, dict(MIX)["CR_Colonnade"] - len(flank))
    instances = [inst for inst, _ in placer.items]
    polys = placer.occluders()
    reliquaries = {i["id"]: i for i in instances if i["name"] == "CR_Reliquary"}
    for alcove in alcoves:
        rel = reliquaries[alcove["reliquary"]]
        alcove["exposed_plinths"] = exposed_plinths(polys, (rel["x"], rel["z"]))
    by_name = {}
    for name, count in MIX:
        assert len([i for i in instances if i["name"] == name]) == count, name
        by_name[name] = {"count": count, "triangles": count * PROPS[name]["tris"]}
    exposure, pairs = route_exposure(placer)
    crossings = g.crossings(ROUTE, VIGIA)
    spacings = [math.dist(a, b) for a, b in zip(VIGIA, VIGIA[1:])]
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
            "occluder_boxes": sum(len(i.get("occluders", [])) for i in instances),
            "by_name": by_name,
        },
        "route": {"nodes": [list(p) for p in ROUTE], "names": [n for n, _ in ROUTE_NODES],
                  "length": r3(ROUTE_LENGTH), "walk_seconds": r3(ROUTE_LENGTH / WALK_SPEED),
                  "corridor_width": 2 * CORRIDOR_HALF},
        "vigia": {"chain": [list(p) for p in VIGIA], "plinth_ids": [p["id"] for p in plinths],
                  "spacing_range": [r3(min(spacings)), r3(max(spacings))], "sight_range": SIGHT_RANGE,
                  "route_crossings": [{"route_arc": r3(c["first_arc"]), "point": [r3(c["point"][0]), r3(c["point"][1])],
                                       "angle_deg": r3(c["angle_deg"])} for c in crossings]},
        "alcoves": alcoves,
        "overlooks": overlooks,
        "density": {"route_sight_exposure": round(exposure, 4), "exposure_pairs": pairs,
                    "props_per_1000_sq_studs": round(len(instances) / (MAP_SIZE * MAP_SIZE / 1000.0), 3)},
        "decisions": DECISIONS,
        "instances": instances,
    }


def to_json(layout):
    return json.dumps(layout, indent=1) + "\n"


# ---- Drawing ----------------------------------------------------------------
CANVAS = (1240, 780)
MAP_X0, MAP_Y0, MAP_SCALE = 30.0, 70.0, 2.3


def build_scene(layout):
    scene = render.Scene(*CANVAS)
    world = render.World(MAP_SCALE, MAP_X0, MAP_Y0, MAP_SIZE / 2)
    s = MAP_SCALE
    scene.text(MAP_X0, 34, "Cryptic Ruins placement plan v1 - DRAFT, unvalidated - top-down", size=22, bold=True)
    scene.text(MAP_X0, 54, "seed %d | 300 x 300 studs | north (-z) is up | gray boxes are sight occluders" % layout["seed"],
               size=13, fill="#444444")
    scene.rect(world.px(-150), world.py(-150), 300 * s, 300 * s, fill="#e9e6ee", stroke="#222222", sw=2)
    for v in range(-150, 151, 50):
        scene.line([(world.px(v), world.py(-150)), (world.px(v), world.py(150))], stroke="#000000", sw=0.8, so=0.10)
        scene.line([(world.px(-150), world.py(v)), (world.px(150), world.py(v))], stroke="#000000", sw=0.8, so=0.10)
        scene.text(world.px(v), world.py(150) + 18, str(v), size=11, fill="#555555", anchor="middle")
        scene.text(world.px(-150) - 6, world.py(v) + 4, str(v), size=11, fill="#555555", anchor="end")
    by = {name: [i for i in layout["instances"] if i["name"] == name] for name, _ in MIX}
    scene.line([world.pt(p) for p in ROUTE], stroke="#d9cfae", sw=2 * CORRIDOR_HALF * s, so=0.9)
    scene.line([world.pt(p) for p in ROUTE], stroke="#6b5320", sw=1.2, dash=(8, 6))
    scene.line([world.pt(p) for p in VIGIA], stroke="#3b2f50", sw=1.6, so=0.7, dash=(6, 4))
    for inst in by["CR_Reliquary"]:
        scene.poly([world.pt(p) for p in footprint(inst).pts], fill="#c9a24a", fo=0.9, stroke="#111111", sw=1)
    for inst in by["CR_StairRun"]:
        scene.poly([world.pt(p) for p in footprint(inst).pts], fill="#9a95a3", fo=0.8, stroke="#111111", sw=1)
    for inst in layout["instances"]:
        for record in inst.get("occluders", []):
            scene.poly([world.pt(p) for p in occluder_poly(record).pts], fill="#77717f", fo=0.95, stroke="#222222", sw=0.8)
    for inst in by["CR_Archway"]:
        scene.poly([world.pt(p) for p in footprint(inst).pts], fill="#3b2f50", fo=0.15, stroke="#3b2f50", sw=1.6)
    for inst in by["CR_GlyphStone"]:
        scene.poly([world.pt(p) for p in footprint(inst).pts], fill="#c9a24a", stroke="#111111", sw=0.8)
    for point, inst in zip(VIGIA, by["CR_Plinth"]):
        scene.poly([world.pt(p) for p in footprint(inst).pts], fill="#3b2f50", stroke="#c9a24a", sw=1.6)
    for name, (x, z) in ROUTE_NODES:
        scene.circle(world.px(x), world.py(z), 5, fill="#ffffff", stroke="#3a2f12", sw=2)
        anchor = "end" if x > 40 else "start"
        scene.text(world.px(x) + (-10 if x > 40 else 10), world.py(z) - 10, name, size=12, bold=True, fill="#3a2f12",
                   anchor=anchor)
    x0, y = 780.0, 100.0
    t = layout["totals"]
    scene.text(x0, y, "Legend", size=17, bold=True)
    rows = [("Trail 14 wide (centreline dashed)", "#d9cfae"), ("Sight occluder box (wall, column, pier)", "#77717f"),
            ("Archway over the trail", "#3b2f50"), ("Plinth of El Vigia's chain", "#3b2f50"),
            ("Reliquary in a three-wall alcove", "#c9a24a"), ("Glyph stone", "#c9a24a"),
            ("Stair run, back-to-back overlook", "#9a95a3")]
    for label, colour in rows:
        y += 24
        scene.rect(x0, y - 12, 22, 14, fill=colour, stroke="#333333", sw=0.8)
        scene.text(x0 + 32, y, label, size=13)
    y += 40
    scene.text(x0, y, "Budget (draft)", size=17, bold=True)
    for line in ["Instances %d / %d cap" % (t["instances"], MAX_INSTANCES),
                 "Triangles measured %s / %s cap" % (format(t["triangles_measured"], ","), format(MAX_TRIANGLES, ",")),
                 "Triangles at bible budgets %s" % format(t["triangles_budget"], ","),
                 "MeshParts %d, occluder boxes %d" % (t["mesh_parts"], t["occluder_boxes"]),
                 "Route %.0f studs, %.0f s at 16 studs/s" % (layout["route"]["length"], layout["route"]["walk_seconds"]),
                 "Trail in plain view of a plinth: %.0f%%" % (100 * layout["density"]["route_sight_exposure"])]:
        y += 22
        scene.text(x0, y, line, size=13)
    y += 40
    scene.text(x0, y, "Counts", size=17, bold=True)
    for name, entry in t["by_name"].items():
        y += 22
        scene.text(x0, y, "%s  %d x %d" % (name, entry["count"], PROPS[name]["tris"]), size=13)
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
    lines = ["seed %d: %d instances (cap %d), %d triangles measured, %d at bible budgets (cap %d), %d MeshParts, "
             "%d occluder boxes" % (layout["seed"], t["instances"], MAX_INSTANCES, t["triangles_measured"],
                                    t["triangles_budget"], MAX_TRIANGLES, t["mesh_parts"], t["occluder_boxes"])]
    lines += ["  %-16s x%-3d %6d tris" % (k, v["count"], v["triangles"]) for k, v in t["by_name"].items()]
    lines.append("route %.0f studs (%.1f s), trail in plain view of a plinth %.1f%%, alcove exposures %s"
                 % (layout["route"]["length"], layout["route"]["walk_seconds"],
                    100 * layout["density"]["route_sight_exposure"], [a["exposed_plinths"] for a in layout["alcoves"]]))
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

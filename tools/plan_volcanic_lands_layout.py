#!/usr/bin/env python3
"""Reproducible top-down placement DRAFT for one Volcanic Lands sector (unvalidated).

This is a plan only: it writes JSON, SVG and (when Pillow is importable) PNG files and never
touches the Luau map builder, Studio or Blender. Python standard library only; Pillow is
optional. The plan stays a draft for a later sector design: it is not an approved layout, was
never imported into Roblox, and no budget in it was measured on a device.

    python tools/plan_volcanic_lands_layout.py [--seed N] [--out-dir DIR]

Conventions (studs, origin at the sector centre): x grows east, z grows south,
rotation_y_deg is CFrame.Angles(0, math.rad(r), 0) (see tools/layout_geometry.py).
Spec: docs/design/wildbound-expansion-bible.md sections 2 (Volcanic Lands) and 5.6. The hazard
is visible and on a schedule: vents cycle 6 s calm, 2.5 s glow with a ground ring, 3 s eruption,
radius 10. Eight vents sit on the trail as timing gates, six stand off it, and every route vent
keeps a clear sight lane from 40 studs upstream so the glow can be read in advance.
Prop sizes are the measured Blender kit values (assets/blender/volcanic-lands-kit).
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

DEFAULT_SEED = 20261110
LAYOUT_NAME = "volcanic-lands-layout-v1"
DEFAULT_OUT_DIR = TOOLS.parent / "assets" / "maps" / "volcanic-lands-layout"

# ---- Spec inputs (bible section 2 and 5.6) ----------------------------------------------
MAP_SIZE = 400.0
LIMIT = MAP_SIZE / 2 - 5.0
MAX_INSTANCES, MAX_TRIANGLES = 210, 30000
MIX = (("VL_BasaltColumn", 60), ("VL_Vent", 14), ("VL_CoolStone", 40), ("VL_CharredTree", 36),
       ("VL_AshShrine", 2), ("VL_CrustPlate", 20), ("VL_ObsidianShard", 18))
WALK_SPEED = 16.0
CORRIDOR_HALF = 7.0
CALM, GLOW, ERUPT, RADIUS = 6.0, 2.5, 3.0, 10.0
CYCLE = CALM + GLOW + ERUPT

# Draft route from the south-west gate to the north-east gate. Hand-placed: long straights so
# each vent disc lies wholly on one straight stretch, with a bend between the stretches.
ROUTE_NODES = (("gate_west", (-190.0, 130.0)), ("ash_flats", (-90.0, 130.0)), ("first_vents", (-10.0, 50.0)),
               ("basalt_gap", (100.0, 50.0)), ("caldera_rise", (150.0, -60.0)), ("caldera_rim", (150.0, -150.0)),
               ("gate_east", (190.0, -190.0)))
ROUTE = [p for _, p in ROUTE_NODES]
ROUTE_VENT_ARCS = (75.0, 140.0, 178.0, 250.0, 292.0, 360.0, 405.0, 485.0)
SHRINE_ARCS = (20.0, 562.0)
FLANK_VENTS = 6

# Measured kit values: "tris" and "parts" from volcanic-lands-kit-report.json, "budget" from the
# bible table. Radii are conservative bounding circles of the measured geometry.
PROPS = {
    "VL_BasaltColumn": {"kind": "column", "tris": 116, "budget": 120, "parts": 1, "r": 5.2, "scale": (0.85, 1.15)},
    "VL_Vent": {"kind": "vent", "tris": 156, "budget": 160, "parts": 2, "r": 5.8, "scale": (1.0, 1.0)},
    "VL_CoolStone": {"kind": "stone", "tris": 58, "budget": 80, "parts": 1, "r": 3.3, "scale": (1.0, 1.0)},
    "VL_CharredTree": {"kind": "tree", "tris": 178, "budget": 220, "parts": 2, "r": 8.7, "scale": (0.9, 1.15)},
    "VL_AshShrine": {"kind": "shrine", "tris": 418, "budget": 480, "parts": 2, "half": (14.3, 7.7),
                     "passage": (-7.447, 7.4521), "clear_h": 11.3},
    "VL_CrustPlate": {"kind": "plate", "tris": 98, "budget": 120, "parts": 2, "r": 11.0, "scale": (1.0, 1.0)},
    "VL_ObsidianShard": {"kind": "shard", "tris": 82, "budget": 90, "parts": 2, "r": 3.1, "scale": (0.9, 1.2),
                         "gather_local_z": -2.5},
}
SHORT = {"VL_BasaltColumn": "column", "VL_Vent": "vent", "VL_CoolStone": "stone", "VL_CharredTree": "tree",
         "VL_AshShrine": "shrine", "VL_CrustPlate": "plate", "VL_ObsidianShard": "shard"}

# Design thresholds chosen by this draft.
BASE_GAP = 1.0
PLATE_GAP = 0.5
REFUGE_ARC, REFUGE_LATERAL = 15.0, 11.5
SIGHT_LEAD = 40.0
SIGHT_CLEAR = 1.5
ROUTE_VENT_LATERAL = 3.0
PHASE_STEP = 5.75        # neighbouring route vents sit half a cycle apart
EDGE_SHARD_DISTANCE = 14.6


def r3(value):
    return round(float(value), 3) + 0.0


def make_instance(name, x, z, yaw, scale, **extra):
    yaw = r3(yaw % 360.0)
    return {"name": name, "x": r3(x), "z": r3(z), "rotation_y_deg": 0.0 if yaw >= 360.0 else yaw,
            "scale": r3(scale), **extra}


def footprint(inst):
    spec, s = PROPS[inst["name"]], inst["scale"]
    if "r" in spec:
        return g.Circle(inst["x"], inst["z"], spec["r"] * s)
    return g.rect_poly(inst["x"], inst["z"], spec["half"][0], spec["half"][1], inst["rotation_y_deg"])


def gather_point(inst):
    r = math.radians(inst["rotation_y_deg"])
    offset = PROPS["VL_ObsidianShard"]["gather_local_z"] * inst["scale"]
    return (inst["x"] + offset * math.sin(r), inst["z"] + offset * math.cos(r))


ROUTE_LENGTH = g.polyline_length(ROUTE)


def route_distance(p):
    return g.project_to_polyline(ROUTE, p)[0]


def at_lateral(arc, lateral):
    point, direction, _ = g.polyline_point(ROUTE, arc)
    return (point[0] - direction[1] * lateral, point[1] + direction[0] * lateral), direction


class Placer:
    def __init__(self):
        self.items = []     # (inst, shape, kind)
        self.discs = []     # vent eruption discs
        self.lanes = []     # sight lanes (a, b) kept clear of columns and trees

    def add(self, inst):
        self.items.append((inst, footprint(inst), PROPS[inst["name"]]["kind"]))
        if PROPS[inst["name"]]["kind"] == "vent":
            self.discs.append(g.Circle(inst["x"], inst["z"], RADIUS))

    def valid(self, inst):
        kind = PROPS[inst["name"]]["kind"]
        shape = footprint(inst)
        x0, z0, x1, z1 = g.shape_bbox(shape)
        if min(x0, z0) < -LIMIT or max(x1, z1) > LIMIT:
            return False
        if kind not in ("shrine",) and g.shape_polyline_dist(shape, ROUTE) < CORRIDOR_HALF + BASE_GAP:
            return False
        for disc in self.discs:
            if g.shape_gap(shape, disc) < BASE_GAP:
                return False
        if kind in ("column", "tree") and any(g.shape_segment_dist(shape, a, b) < SIGHT_CLEAR for a, b in self.lanes):
            return False
        if kind == "plate" and route_distance((inst["x"], inst["z"])) < 30.0:
            return False
        point = gather_point(inst) if kind == "shard" else None
        if point is not None and any(g.shape_point_dist(d, point) < 0.5 for d in self.discs):
            return False
        for other, other_shape, other_kind in self.items:
            if other_kind == "vent":
                continue
            needed = PLATE_GAP if kind == other_kind == "plate" else BASE_GAP
            if g.shape_gap(shape, other_shape) < needed:
                return False
            if kind == "shard" and g.shape_point_dist(other_shape, point) < BASE_GAP:
                return False
            if other_kind == "shard" and g.shape_point_dist(shape, gather_point(other)) < BASE_GAP:
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


def facing(x, z, target):
    """Yaw whose local -Z (the gather side) points at target."""
    return g.heading_deg(-(target[0] - x), -(target[1] - z))


def side_point(rng, lateral_low, lateral_high):
    arc = rng.uniform(0.0, ROUTE_LENGTH)
    point, _ = at_lateral(arc, rng.choice((-1, 1)) * rng.uniform(lateral_low, lateral_high))
    return point


def random_point(rng):
    return rng.uniform(-LIMIT, LIMIT), rng.uniform(-LIMIT, LIMIT)


def place_shrines(placer, ids):
    shrines = []
    for arc in SHRINE_ARCS:
        point, direction, index = g.polyline_point(ROUTE, arc)
        for node in (ROUTE[index], ROUTE[index + 1]):
            assert math.dist(point, node) >= PROPS["VL_AshShrine"]["half"][1] + 1.0, f"shrine at {arc} too near a bend"
        inst = make_instance("VL_AshShrine", point[0], point[1], g.heading_deg(*direction), 1.0, id=ids.next("VL_AshShrine"))
        assert placer.valid(inst), f"shrine at arc {arc} does not fit"
        placer.add(inst)
        shrines.append(inst)
    return shrines


def place_route_vents(placer, ids, rng):
    vents, records = [], []
    for k, arc in enumerate(ROUTE_VENT_ARCS):
        lateral = round(rng.uniform(-ROUTE_VENT_LATERAL, ROUTE_VENT_LATERAL), 2)
        point, _ = at_lateral(arc, lateral)
        inst = make_instance("VL_Vent", point[0], point[1], rng.uniform(0.0, 360.0), 1.0, id=ids.next("VL_Vent"))
        placer.discs.append(g.Circle(inst["x"], inst["z"], RADIUS))
        placer.items.append((inst, footprint(inst), "vent"))
        vents.append(inst)
        records.append({"id": inst["id"], "role": "route", "x": inst["x"], "z": inst["z"],
                        "phase_s": (k % 2) * PHASE_STEP, "route_arc": r3(arc), "lateral": lateral})
    return vents, records


def place_refuges(placer, ids, anchors):
    """Cool-stone pairs on both sides, upstream and downstream, just outside each hazard or shrine."""
    stones = []
    for arc in anchors:
        for arc_sign in (-1, 1):
            for side in (-1, 1):
                point, _ = at_lateral(arc + arc_sign * REFUGE_ARC, side * REFUGE_LATERAL)
                inst = make_instance("VL_CoolStone", point[0], point[1], 0.0, 1.0, id=ids.next("VL_CoolStone"))
                assert placer.valid(inst), f"refuge stone near arc {arc} does not fit"
                placer.add(inst)
                stones.append(inst)
    return stones


def place_flank_vents(placer, ids, rng, existing):
    vents, records, attempts = [], [], 0
    while len(vents) < FLANK_VENTS:
        attempts += 1
        assert attempts < 40000, "could not place every flank vent"
        x, z = side_point(rng, 24.0, 70.0)
        if max(abs(x), abs(z)) + RADIUS > MAP_SIZE / 2 - 5.0 or route_distance((x, z)) < CORRIDOR_HALF + RADIUS + BASE_GAP + 3.0:
            continue
        if any(math.dist((x, z), (v["x"], v["z"])) < 2 * RADIUS + 6.0 for v in existing + vents):
            continue
        inst = make_instance("VL_Vent", x, z, rng.uniform(0.0, 360.0), 1.0, id=ids.next("VL_Vent"))
        disc = g.Circle(inst["x"], inst["z"], RADIUS)
        if any(g.shape_gap(shape, disc) < BASE_GAP for _, shape, kind in placer.items if kind != "vent"):
            ids.release("VL_Vent")
            continue
        placer.discs.append(disc)
        placer.items.append((inst, footprint(inst), "vent"))
        vents.append(inst)
        records.append({"id": inst["id"], "role": "flank", "x": inst["x"], "z": inst["z"],
                        "phase_s": round(rng.uniform(0.0, CYCLE) / 0.25) * 0.25 % CYCLE, "route_arc": None,
                        "lateral": None})
    return vents, records


def place_edge_shards(placer, ids, flank):
    """Six risk shards: the gather point sits just outside a flank vent's disc."""
    shards = []
    for vent in flank:
        for attempt in range(72):
            angle = math.radians(attempt * 5.0)
            x = vent["x"] + EDGE_SHARD_DISTANCE * math.sin(angle)
            z = vent["z"] + EDGE_SHARD_DISTANCE * math.cos(angle)
            inst = make_instance("VL_ObsidianShard", x, z, facing(x, z, (vent["x"], vent["z"])), 1.0,
                                 id=ids.next("VL_ObsidianShard"))
            if placer.valid(inst):
                placer.add(inst)
                shards.append(inst)
                break
            ids.release("VL_ObsidianShard")
        else:
            raise AssertionError("no room for an edge shard at " + vent["id"])
    return shards


def place_route_shards(placer, ids, rng, count, flank):
    shards, attempts = [], 0
    spec = PROPS["VL_ObsidianShard"]
    while len(shards) < count:
        attempts += 1
        assert attempts < 40000, "could not place every route shard"
        x, z = side_point(rng, 13.0, 30.0)
        foot = g.project_to_polyline(ROUTE, (x, z))
        nearest = g.polyline_point(ROUTE, foot[1])[0]
        inst = make_instance("VL_ObsidianShard", x, z, facing(x, z, nearest), rng.uniform(*spec["scale"]),
                             id=ids.next("VL_ObsidianShard"))
        point = gather_point(inst)
        if placer.valid(inst) and 8.0 <= route_distance(point) < foot[0] and \
                all(math.dist(point, (v["x"], v["z"])) > 14.0 for v in flank):
            placer.add(inst)
            shards.append(inst)
        else:
            ids.release("VL_ObsidianShard")
    return shards


def place_clustered(placer, ids, rng, name, total, clusters, per_cluster, spread, route_band):
    spec, placed, centres = PROPS[name], [], []

    def attempt(x, z):
        inst = make_instance(name, x, z, rng.uniform(0.0, 360.0), rng.uniform(*spec["scale"]), id=ids.next(name))
        if placer.valid(inst):
            placer.add(inst)
            placed.append(inst)
            return True
        ids.release(name)
        return False

    for _ in range(6000):
        if len(centres) == clusters:
            break
        c = random_point(rng)
        if route_band[0] <= route_distance(c) <= route_band[1] and all(math.dist(c, o) >= 80.0 for o in centres):
            centres.append(c)
    for centre in centres:
        got = tries = 0
        while got < per_cluster and tries < 600:
            tries += 1
            angle, radius = rng.uniform(0.0, math.tau), rng.uniform(spread[0], spread[1])
            got += attempt(centre[0] + radius * math.cos(angle), centre[1] + radius * math.sin(angle))
    tries = 0
    while len(placed) < total:
        tries += 1
        assert tries < 60000, f"could not place every {name}"
        attempt(*random_point(rng))
    return placed


def sight_report(placer, vents_records):
    """Sight lanes from 40 studs upstream to each route vent, and how many are clear."""
    lanes, clear = [], 0
    occluders = [shape for inst, shape, kind in placer.items if kind in ("column", "tree", "shrine")]
    for record in vents_records:
        start = g.polyline_point(ROUTE, max(0.0, record["route_arc"] - SIGHT_LEAD))[0]
        end = (record["x"], record["z"])
        free = all(g.shape_segment_dist(shape, start, end) >= 1.0 for shape in occluders)
        clear += free
        lanes.append({"vent": record["id"], "from": [r3(start[0]), r3(start[1])], "to": [r3(end[0]), r3(end[1])],
                      "clear": free})
    return lanes, clear


DECISIONS = [
    "Route vents stand on the trail as timing gates (tiny, non-colliding); flank vents are at least 18 studs "
    "from it so their discs never touch the corridor.",
    "Neighbouring route vents run half a cycle apart (phase 0 or 5.75 s) so they never erupt together, and the "
    "2.5 s glow is longer than the 1.25 s it takes to cross a whole disc at 16 studs/s.",
    "Cool stones are read as refuge markers: four per route vent and per shrine, outside the corridor and every "
    "disc. The bible only calls them walkable slabs; this meaning is a draft choice.",
    "Crust plates are dressing in four fields at least 30 studs from the trail; they carry no hazard meaning.",
    "Obsidian shards: 12 along the trail, 6 beside flank vents with the gather point just outside the disc "
    "(reward beside danger, never inside it).",
    "Columns and trees keep sight lanes clear: every route vent is visible from 40 studs upstream.",
    "Shrines straddle the trail near both gates with the measured gap (about 0 off centre) centred on the "
    "trail; the pivot sits on the centreline.",
    "Footprints are bounding circles of the measured geometry, including tree branches (8.7).",
]


def generate(seed=DEFAULT_SEED):
    rng = random.Random(seed)
    placer, ids = Placer(), IdSource()
    shrines = place_shrines(placer, ids)
    route_vents, route_records = place_route_vents(placer, ids, rng)
    stones = place_refuges(placer, ids, list(ROUTE_VENT_ARCS) + list(SHRINE_ARCS))
    flank_vents, flank_records = place_flank_vents(placer, ids, rng, route_vents)
    edge_shards = place_edge_shards(placer, ids, flank_vents)
    route_shards = place_route_shards(placer, ids, rng, dict(MIX)["VL_ObsidianShard"] - len(edge_shards), flank_vents)
    for record in route_records:
        start = g.polyline_point(ROUTE, max(0.0, record["route_arc"] - SIGHT_LEAD))[0]
        placer.lanes.append((start, (record["x"], record["z"])))
    trees = place_clustered(placer, ids, rng, "VL_CharredTree", dict(MIX)["VL_CharredTree"], 4, 6, (16.0, 38.0), (40.0, 110.0))
    columns = place_clustered(placer, ids, rng, "VL_BasaltColumn", dict(MIX)["VL_BasaltColumn"], 5, 10, (10.0, 36.0), (35.0, 100.0))
    plates = place_clustered(placer, ids, rng, "VL_CrustPlate", dict(MIX)["VL_CrustPlate"], 4, 5, (14.0, 34.0), (45.0, 120.0))
    instances = columns + route_vents + flank_vents + stones + trees + shrines + plates + route_shards + edge_shards
    by_name = {}
    for name, count in MIX:
        assert len([i for i in instances if i["name"] == name]) == count, name
        by_name[name] = {"count": count, "triangles": count * PROPS[name]["tris"]}
    lanes, clear = sight_report(placer, route_records)
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
        "hazards": {"vent_cycle": {"calm_s": CALM, "glow_s": GLOW, "erupt_s": ERUPT, "cycle_s": CYCLE,
                                   "radius": RADIUS, "full_disc_crossing_s": r3(2 * RADIUS / WALK_SPEED)},
                    "vents": route_records + flank_records, "sight_lanes": lanes},
        "density": {"props_per_1000_sq_studs": round(len(instances) / (MAP_SIZE * MAP_SIZE / 1000.0), 3),
                    "route_vents_in_clear_view": clear},
        "decisions": DECISIONS,
        "instances": instances,
    }


def to_json(layout):
    return json.dumps(layout, indent=1) + "\n"


# ---- Drawing ----------------------------------------------------------------
CANVAS = (1240, 900)
MAP_X0, MAP_Y0, MAP_SCALE = 30.0, 70.0, 2.0


def build_scene(layout):
    scene = render.Scene(*CANVAS)
    world = render.World(MAP_SCALE, MAP_X0, MAP_Y0, MAP_SIZE / 2)
    s = MAP_SCALE
    scene.text(MAP_X0, 34, "Volcanic Lands placement plan v1 - DRAFT, unvalidated - top-down", size=22, bold=True)
    scene.text(MAP_X0, 54, "seed %d | 400 x 400 studs | north (-z) is up | symbols enlarged" % layout["seed"], size=13,
               fill="#444444")
    scene.rect(world.px(-200), world.py(-200), 400 * s, 400 * s, fill="#e6dfd8", stroke="#222222", sw=2)
    for v in range(-200, 201, 50):
        scene.line([(world.px(v), world.py(-200)), (world.px(v), world.py(200))], stroke="#000000", sw=0.8, so=0.10)
        scene.line([(world.px(-200), world.py(v)), (world.px(200), world.py(v))], stroke="#000000", sw=0.8, so=0.10)
        scene.text(world.px(v), world.py(200) + 18, str(v), size=11, fill="#555555", anchor="middle")
        scene.text(world.px(-200) - 6, world.py(v) + 4, str(v), size=11, fill="#555555", anchor="end")
    by = {name: [i for i in layout["instances"] if i["name"] == name] for name, _ in MIX}
    roles = {v["id"]: v["role"] for v in layout["hazards"]["vents"]}
    for plate in by["VL_CrustPlate"]:
        scene.circle(world.px(plate["x"]), world.py(plate["z"]), 11.0 * s, fill="#4a3c36", fo=0.45, stroke="#c8481a", sw=1)
    for vent in by["VL_Vent"]:
        color = "#c8481a" if roles[vent["id"]] == "route" else "#e8a23a"
        scene.circle(world.px(vent["x"]), world.py(vent["z"]), RADIUS * s, fill=color, fo=0.20, stroke=color, sw=1.4, dash=(5, 4))
    scene.line([world.pt(p) for p in ROUTE], stroke="#cdb892", sw=2 * CORRIDOR_HALF * s, so=0.9)
    scene.line([world.pt(p) for p in ROUTE], stroke="#5a4020", sw=1.2, dash=(8, 6))
    for lane in layout["hazards"]["sight_lanes"]:
        scene.line([world.pt(lane["from"]), world.pt(lane["to"])], stroke="#c8481a", sw=1.0, so=0.55, dash=(3, 3))
    for tree in by["VL_CharredTree"]:
        scene.circle(world.px(tree["x"]), world.py(tree["z"]), 8.7 * tree["scale"] * s, fill="#241f1d", fo=0.14)
        scene.circle(world.px(tree["x"]), world.py(tree["z"]), 5.0, fill="#241f1d", stroke="#ffffff", sw=0.8)
    for col in by["VL_BasaltColumn"]:
        scene.circle(world.px(col["x"]), world.py(col["z"]), 5.2 * col["scale"] * s, fill="#2e2b2c", fo=0.85, stroke="#111111", sw=0.8)
    for stone in by["VL_CoolStone"]:
        scene.circle(world.px(stone["x"]), world.py(stone["z"]), 3.3 * s, fill="#6c7a85", stroke="#222222", sw=0.8)
    for vent in by["VL_Vent"]:
        scene.circle(world.px(vent["x"]), world.py(vent["z"]), 5.0, fill="#ff7a2a", stroke="#111111", sw=1)
    for shard in by["VL_ObsidianShard"]:
        x, y = world.px(shard["x"]), world.py(shard["z"])
        scene.poly([(x, y - 6), (x + 5, y + 5), (x - 5, y + 5)], fill="#1a1a24", stroke="#ffffff", sw=0.8)
        gx, gz = gather_point(shard)
        scene.circle(world.px(gx), world.py(gz), 2.2, fill="#ffffff", stroke="#1a1a24", sw=0.8)
    for shrine in by["VL_AshShrine"]:
        scene.poly([world.pt(p) for p in footprint(shrine).pts], fill="#6f6863", fo=0.8, stroke="#111111", sw=1.6)
    for name, (x, z) in ROUTE_NODES:
        scene.circle(world.px(x), world.py(z), 5, fill="#ffffff", stroke="#3a2f12", sw=2)
        anchor = "end" if x > 100 else "start"
        scene.text(world.px(x) + (-10 if x > 100 else 10), world.py(z) - 10, name, size=12, bold=True, fill="#3a2f12",
                   anchor=anchor)
    x0, y = 880.0, 100.0
    t = layout["totals"]
    scene.text(x0, y, "Legend", size=17, bold=True)
    rows = [("Trail 14 wide (centreline dashed)", "#cdb892"), ("Route vent disc r 10 (timing gate)", "#c8481a"),
            ("Flank vent disc r 10", "#e8a23a"), ("Sight lane, 40 studs upstream", "#c8481a"),
            ("Basalt column", "#2e2b2c"), ("Charred tree, shade r 8.7", "#241f1d"), ("Cool stone (refuge)", "#6c7a85"),
            ("Crust plate field", "#4a3c36"), ("Obsidian shard, dot = gather", "#1a1a24"), ("Ash shrine over trail", "#6f6863")]
    for label, colour in rows:
        y += 24
        scene.rect(x0, y - 12, 22, 14, fill=colour, stroke="#333333", sw=0.8)
        scene.text(x0 + 32, y, label, size=13)
    y += 40
    scene.text(x0, y, "Budget (draft)", size=17, bold=True)
    for line in ["Instances %d / %d cap" % (t["instances"], MAX_INSTANCES),
                 "Triangles measured %s / %s cap" % (format(t["triangles_measured"], ","), format(MAX_TRIANGLES, ",")),
                 "Triangles at bible budgets %s" % format(t["triangles_budget"], ","),
                 "MeshParts %d" % t["mesh_parts"],
                 "Route %.0f studs, %.0f s at 16 studs/s" % (layout["route"]["length"], layout["route"]["walk_seconds"]),
                 "Vent cycle 6 + 2.5 + 3 s, 8 route vents, 6 flank"]:
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
    lines = ["seed %d: %d instances (cap %d), %d triangles measured, %d at bible budgets (cap %d), %d MeshParts"
             % (layout["seed"], t["instances"], MAX_INSTANCES, t["triangles_measured"], t["triangles_budget"],
                MAX_TRIANGLES, t["mesh_parts"])]
    lines += ["  %-16s x%-3d %6d tris" % (k, v["count"], v["triangles"]) for k, v in t["by_name"].items()]
    lines.append("route %.0f studs (%.1f s), %d vents, %d route vents in clear view"
                 % (layout["route"]["length"], layout["route"]["walk_seconds"], len(layout["hazards"]["vents"]),
                    layout["density"]["route_vents_in_clear_view"]))
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

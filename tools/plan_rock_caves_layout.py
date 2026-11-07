#!/usr/bin/env python3
"""Reproducible top-down placement DRAFT for one Rock and Caves sector (unvalidated).

This is a plan only: it writes JSON, SVG and (when Pillow is importable) PNG files and never
touches the Luau map builder, Studio or Blender. Python standard library only; Pillow is
optional. The plan stays a draft for a later sector design: it is not an approved layout, was
never imported into Roblox, and no budget in it was measured on a device.

    python tools/plan_rock_caves_layout.py [--seed N] [--out-dir DIR]

Conventions (studs, origin at the sector centre): x grows east, z grows south,
rotation_y_deg is CFrame.Angles(0, math.rad(r), 0) (see tools/layout_geometry.py). Kit frame to
plan frame: local x = -Blender x, local z = Blender y.
Spec: docs/design/wildbound-expansion-bible.md sections 2 (Rock and Caves) and 5.5. The route is
two snapped tunnels joined by a daylight clearing. Every tunnel joint is built from the measured
end rings in the kit report (centre and outward facing of ends A and B, the shared C-shaped
profile) so neighbouring modules meet within the 0.02 snap tolerance; the chain is written from
two strings (S straight, R bend entered through end A, L bend entered through end B). Four
rockfall lanes (dust 3 s, then rocks land for 2 s in a 10 stud strip) sit on straight modules.
Prop sizes are the measured Blender kit values (assets/blender/rock-caves-kit).
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

DEFAULT_SEED = 20261113
LAYOUT_NAME = "rock-caves-layout-v1"
DEFAULT_OUT_DIR = TOOLS.parent / "assets" / "maps" / "rock-caves-layout"

# ---- Spec inputs (bible section 2 and 5.5) ----------------------------------------------
MAP_SIZE = 300.0
LIMIT = MAP_SIZE / 2 - 5.0
MAX_INSTANCES, MAX_TRIANGLES = 130, 28000
MIX = (("RC_CaveMouth", 3), ("RC_TunnelStraight", 18), ("RC_TunnelBend", 8), ("RC_Stalagmite", 40),
       ("RC_CrystalCluster", 16), ("RC_OreVein", 14), ("RC_Burrow", 12))
WALK_SPEED = 16.0
CORRIDOR_HALF = 7.0
DUST_S, IMPACT_S, STRIP = 3.0, 2.0, 10.0

# Tunnel chains (bible gives only the module mix): found by a bounded search for chains of nine
# straights and four bends that stay in the sector and 2 studs apart, then fixed here by hand.
TUNNELS = (("A", "SSSLSSSLSRRSS", (-92.0, 100.0), (1.0, 0.0)),
           ("B", "RSSSRSSLLSSSS", (96.0, -44.0), (1.0, 0.0)))
GATE_WEST = (-140.0, 100.0)
LANE_ORDINALS = {"A": (1, 5), "B": (2, 6)}   # which straights of each tunnel carry a rockfall lane

# Measured end rings, in Blender axes (rock-caves-kit-report.json "ends"): centre and outward facing.
ENDS_BLENDER = {"RC_TunnelStraight": {"A": ((0.0, -12.0), (0.0, -1.0)), "B": ((0.0, 12.0), (0.0, 1.0))},
                "RC_TunnelBend": {"A": ((-3.0, -15.0), (0.0, -1.0)), "B": ((15.0, 3.0), (1.0, 0.0))}}
BEND_CENTRE_LOCAL, BEND_RADIUS, BEND_SEGMENTS = (-15.0, -15.0), 18.0, 6
STRAIGHT_HALF = (12.83, 12.0)
BEND_WEDGE = (5.7, 31.0 / math.cos(math.radians(7.5)))
MOUTH_BACK, MOUTH_FRONT = 7.7733, 7.4867
MOUTH_HALF_X = 18.1
LANE_SIZE = (14.0, STRIP)
SNAP_TOLERANCE = 0.02

# Measured kit values: "tris" and "parts" from rock-caves-kit-report.json, "budget" from the bible
# table. "r" are conservative bounding circles; "collision"/"occluders" are report box counts.
PROPS = {
    "RC_CaveMouth": {"kind": "mouth", "tris": 526, "budget": 640, "parts": 3, "occluders": 2, "collision": 0},
    "RC_TunnelStraight": {"kind": "straight", "tris": 406, "budget": 420, "parts": 2, "occluders": 2, "collision": 1},
    "RC_TunnelBend": {"kind": "bend", "tris": 406, "budget": 480, "parts": 2, "occluders": 24, "collision": 24},
    "RC_Stalagmite": {"kind": "stalagmite", "tris": 90, "budget": 90, "parts": 1, "r": 3.3, "scale": (0.9, 1.15)},
    "RC_CrystalCluster": {"kind": "crystal", "tris": 134, "budget": 140, "parts": 2, "r": 3.6, "scale": (0.9, 1.2),
                          "gather_local_z": -3.0},
    "RC_OreVein": {"kind": "vein", "tris": 160, "budget": 180, "parts": 2, "r": 4.1, "scale": (0.9, 1.15),
                   "gather_local_z": -2.5},
    "RC_Burrow": {"kind": "burrow", "tris": 92, "budget": 120, "parts": 2, "r": 3.8, "scale": (0.9, 1.1)},
}
SHORT = {"RC_CaveMouth": "mouth", "RC_TunnelStraight": "straight", "RC_TunnelBend": "bend",
         "RC_Stalagmite": "stalagmite", "RC_CrystalCluster": "crystal", "RC_OreVein": "vein", "RC_Burrow": "burrow"}

# Design thresholds chosen by this draft.
BASE_GAP = 1.0
STRUCTURE_GAP = 2.0
GATHER_BAND = (8.0, 40.0)
CRYSTALS_IN_CLEARING = 11
VEINS_IN_CLEARING = 8


def r3(value):
    return round(float(value), 3) + 0.0


def make_instance(name, x, z, yaw, scale=1.0, **extra):
    yaw = r3(yaw % 360.0)
    return {"name": name, "x": r3(x), "z": r3(z), "rotation_y_deg": 0.0 if yaw >= 360.0 else yaw,
            "scale": r3(scale), **extra}


def local_point(v):
    return (-v[0], v[1])


def tf(yaw_deg, pivot, v):
    r = math.radians(yaw_deg)
    return (pivot[0] + v[0] * math.cos(r) + v[1] * math.sin(r), pivot[1] - v[0] * math.sin(r) + v[1] * math.cos(r))


def tf_vec(yaw_deg, v):
    r = math.radians(yaw_deg)
    return (v[0] * math.cos(r) + v[1] * math.sin(r), -v[0] * math.sin(r) + v[1] * math.cos(r))


def local_to_world(inst, local_x, local_z):
    return tf(inst["rotation_y_deg"], (inst["x"], inst["z"]), (local_x, local_z))


def end_world(inst, end):
    centre, facing = ENDS_BLENDER[inst["name"]][end]
    return local_to_world(inst, *local_point(centre)), tf_vec(inst["rotation_y_deg"], local_point(facing))


def place_module(kind, entry, joint, direction):
    """Pivot and yaw that seat the module's end `entry` on `joint`, facing back against `direction`."""
    ends = ENDS_BLENDER[kind]
    centre, facing = ends[entry]
    face_local = local_point(facing)
    yaw = (g.heading_deg(-direction[0], -direction[1]) - g.heading_deg(*face_local)) % 360.0
    anchor = tf(yaw, (0.0, 0.0), local_point(centre))
    return (joint[0] - anchor[0], joint[1] - anchor[1]), yaw


def build_chain(ids, key, string, start, direction):
    """Instances of one tunnel, written from its string and the measured end rings."""
    joint, heading, modules = start, direction, []
    for letter in string:
        kind = "RC_TunnelStraight" if letter == "S" else "RC_TunnelBend"
        entry = "B" if letter == "L" else "A"
        pivot, yaw = place_module(kind, entry, joint, heading)
        inst = make_instance(kind, pivot[0], pivot[1], yaw, id=ids.next(kind), tunnel=key, entry=entry)
        exit_end = "B" if entry == "A" else "A"
        exact_exit = tf(yaw, pivot, local_point(ENDS_BLENDER[kind][exit_end][0]))
        exact_dir = tf_vec(yaw, local_point(ENDS_BLENDER[kind][exit_end][1]))
        modules.append(inst)
        joint, heading = exact_exit, (round(exact_dir[0], 9), round(exact_dir[1], 9))
    return modules, joint, heading


def pieces(inst):
    """Convex ground pieces of a structure."""
    kind = PROPS[inst["name"]]["kind"]
    if kind == "straight":
        return [g.rect_poly(inst["x"], inst["z"], STRAIGHT_HALF[0], STRAIGHT_HALF[1], inst["rotation_y_deg"])]
    if kind == "mouth":
        return [g.Poly(tuple(local_to_world(inst, sx * MOUTH_HALF_X, sz) for sx, sz in
                             ((-1, -MOUTH_FRONT - 0.05), (1, -MOUTH_FRONT - 0.05), (1, MOUTH_BACK + 0.03),
                              (-1, MOUTH_BACK + 0.03))))]
    out, (ri, ro), (cx, cz) = [], BEND_WEDGE, BEND_CENTRE_LOCAL
    for k in range(BEND_SEGMENTS):
        a0, a1 = math.radians(90.0 * k / BEND_SEGMENTS), math.radians(90.0 * (k + 1) / BEND_SEGMENTS)
        pts = [(cx + ri * math.cos(a0), cz + ri * math.sin(a0)), (cx + ro * math.cos(a0), cz + ro * math.sin(a0)),
               (cx + ro * math.cos(a1), cz + ro * math.sin(a1)), (cx + ri * math.cos(a1), cz + ri * math.sin(a1))]
        out.append(g.Poly(tuple(local_to_world(inst, *p) for p in pts)))
    return out


def prop_shape(inst):
    return g.Circle(inst["x"], inst["z"], PROPS[inst["name"]]["r"] * inst["scale"])


def shapes(inst):
    return pieces(inst) if PROPS[inst["name"]]["kind"] in ("straight", "bend", "mouth") else [prop_shape(inst)]


def shapes_gap(a, b):
    return min(g.shape_gap(p, q) for p in a for q in b)


def gather_point(inst):
    r = math.radians(inst["rotation_y_deg"])
    offset = PROPS[inst["name"]]["gather_local_z"] * inst["scale"]
    return (inst["x"] + offset * math.sin(r), inst["z"] + offset * math.cos(r))


def module_path(inst):
    """Centreline points through a module, from its entry end to its exit end."""
    if PROPS[inst["name"]]["kind"] == "straight":
        points = [end_world(inst, "A")[0], end_world(inst, "B")[0]]
    else:
        cx, cz = BEND_CENTRE_LOCAL
        points = [local_to_world(inst, cx + BEND_RADIUS * math.cos(math.radians(90.0 * k / BEND_SEGMENTS)),
                                 cz + BEND_RADIUS * math.sin(math.radians(90.0 * k / BEND_SEGMENTS)))
                  for k in range(BEND_SEGMENTS + 1)]
    return points if inst["entry"] == "A" else points[::-1]


def dedupe(points):
    out = []
    for p in points:
        if not out or math.dist(out[-1], p) > 1e-6:
            out.append((r3(p[0]), r3(p[1])))
    return out


class IdSource:
    def __init__(self):
        self.counts = {}

    def next(self, name):
        key = SHORT[name]
        self.counts[key] = self.counts.get(key, 0) + 1
        return f"{key}-{self.counts[key]:02d}"

    def release(self, name):
        self.counts[SHORT[name]] -= 1


def inward_vector(mouth):
    r = math.radians(mouth["rotation_y_deg"])
    return (math.sin(r), math.cos(r))


def build_structures(ids):
    """Tunnels, mouths and the route through them. Returns everything the props are placed around."""
    chains, mouths, route, surface, roles = [], [], [], [], []
    ends = {}
    for key, string, start, direction in TUNNELS:
        modules, end_point, end_dir = build_chain(ids, key, string, start, direction)
        chains.append((key, string, modules))
        ends[key] = (start, direction, end_point, end_dir)

    def mouth_at(role, tunnel, joint_name, rear, inward):
        pivot = (rear[0] - MOUTH_BACK * inward[0], rear[1] - MOUTH_BACK * inward[1])
        inst = make_instance("RC_CaveMouth", pivot[0], pivot[1], g.heading_deg(*inward), id=ids.next("RC_CaveMouth"))
        mouths.append(inst)
        roles.append({"id": inst["id"], "role": role, "tunnel": tunnel, "joint": joint_name})
        return inst

    start_a, dir_a, end_a, edir_a = ends["A"]
    start_b, dir_b, end_b, edir_b = ends["B"]
    west = mouth_at("west", "A", "start", start_a, dir_a)
    leave = mouth_at("exit", "A", "end", end_a, (-edir_a[0], -edir_a[1]))
    east = mouth_at("east", "B", "start", start_b, dir_b)

    def front(mouth):
        v = inward_vector(mouth)
        return (mouth["x"] - MOUTH_FRONT * v[0], mouth["z"] - MOUTH_FRONT * v[1])

    approach = [GATE_WEST, front(west)]
    clearing = [front(leave), front(east)]
    surface = [dedupe(approach), dedupe(clearing)]
    route.extend(approach)
    route.append(start_a)
    for key, string, modules in chains[:1]:
        for inst in modules:
            route.extend(module_path(inst))
    route.extend(clearing)
    route.append(start_b)
    for inst in chains[1][2]:
        route.extend(module_path(inst))
    return chains, mouths, roles, dedupe(route), surface


def check_structures(chains, mouths, roles):
    """Joint errors and clearances, asserted at build time and reported in the JSON."""
    records = []
    for key, string, modules in chains:
        worst = 0.0
        for a, b in zip(modules, modules[1:]):
            exit_end = "B" if a["entry"] == "A" else "A"
            pa, fa = end_world(a, exit_end)
            pb, fb = end_world(b, b["entry"])
            worst = max(worst, math.dist(pa, pb))
            assert fa[0] * fb[0] + fa[1] * fb[1] < -0.9999, "facings must be opposite"
        assert worst <= SNAP_TOLERANCE, f"tunnel {key} joint error {worst}"
        records.append({"name": key, "string": string, "module_ids": [m["id"] for m in modules],
                        "straights": string.count("S"), "bends": len(string) - string.count("S"),
                        "max_joint_error": r3(worst)})
    everything = [(m, shapes(m)) for _, _, mods in chains for m in mods]
    for a_index, (a, sa) in enumerate(everything):
        for b, sb in everything[a_index + 1:]:
            if a["tunnel"] == b["tunnel"] and abs(int(a["id"].split("-")[1]) - int(b["id"].split("-")[1])) <= 1 \
                    and a["name"] == b["name"]:
                continue
            same_chain = a["tunnel"] == b["tunnel"]
            idx = {m["id"]: i for i, m in enumerate(next(c[2] for c in chains if c[0] == a["tunnel"]))}
            if same_chain and abs(idx[a["id"]] - idx[b["id"]]) <= 1:
                continue
            assert shapes_gap(sa, sb) >= STRUCTURE_GAP, f"{a['id']} {b['id']} too close"
    for mouth in mouths:
        for m, sm in everything:
            gap = shapes_gap(shapes(mouth), sm)
            assert gap < 0.2 or gap >= BASE_GAP, f"{mouth['id']} / {m['id']} overlap"
    return records


class Placer:
    def __init__(self, structures, route, surface):
        self.structures = [shapes(s) for s in structures]
        self.route, self.surface = route, surface
        self.items = []  # (inst, shape)

    def surface_distance(self, p):
        return min(g.project_to_polyline(poly, p)[0] for poly in self.surface)

    def add(self, inst):
        self.items.append((inst, prop_shape(inst)))

    def valid(self, inst):
        kind = PROPS[inst["name"]]["kind"]
        shape = prop_shape(inst)
        x0, z0, x1, z1 = g.shape_bbox(shape)
        if min(x0, z0) < -LIMIT or max(x1, z1) > LIMIT:
            return False
        if g.shape_polyline_dist(shape, self.route) < CORRIDOR_HALF + BASE_GAP:
            return False
        for pieces_ in self.structures:
            if any(g.shape_gap(shape, p) < BASE_GAP for p in pieces_):
                return False
        point = gather_point(inst) if kind in ("crystal", "vein") else None
        if point is not None:
            distance = self.surface_distance(point)
            if not GATHER_BAND[0] <= distance <= GATHER_BAND[1] or distance >= self.surface_distance((inst["x"], inst["z"])):
                return False
            if any(g.shape_point_dist(p, point) < BASE_GAP for pieces_ in self.structures for p in pieces_):
                return False
        for other, other_shape in self.items:
            if g.shape_gap(shape, other_shape) < BASE_GAP:
                return False
            if point is not None and g.shape_point_dist(other_shape, point) < BASE_GAP:
                return False
            if PROPS[other["name"]]["kind"] in ("crystal", "vein") and g.shape_point_dist(shape, gather_point(other)) < BASE_GAP:
                return False
        return True


def random_point(rng):
    return rng.uniform(-LIMIT, LIMIT), rng.uniform(-LIMIT, LIMIT)


def side_of(polyline, rng, low, high):
    length = g.polyline_length(polyline)
    point, direction, _ = g.polyline_point(polyline, rng.uniform(0.0, length))
    lateral = rng.choice((-1, 1)) * rng.uniform(low, high)
    return point[0] - direction[1] * lateral, point[1] + direction[0] * lateral


def place_gatherables(placer, ids, rng, name, total, in_clearing):
    spec, placed, attempts = PROPS[name], [], 0
    while len(placed) < total:
        attempts += 1
        assert attempts < 60000, f"could not place every {name}"
        poly = placer.surface[1] if len(placed) < in_clearing else placer.surface[0]
        x, z = side_of(poly, rng, 12.0, 38.0)
        foot = g.project_to_polyline(placer.surface[0], (x, z)) if poly is placer.surface[0] else \
            g.project_to_polyline(placer.surface[1], (x, z))
        nearest = g.polyline_point(poly, foot[1])[0]
        inst = make_instance(name, x, z, g.heading_deg(x - nearest[0], z - nearest[1]), rng.uniform(*spec["scale"]),
                             id=ids.next(name))
        if placer.valid(inst):
            placer.add(inst)
            placed.append(inst)
        else:
            ids.release(name)
    return placed


def place_scatter(placer, ids, rng, name, total, groves=0, per_grove=0):
    spec, placed, centres = PROPS[name], [], []

    def attempt(x, z):
        inst = make_instance(name, x, z, rng.uniform(0.0, 360.0), rng.uniform(*spec["scale"]), id=ids.next(name))
        if placer.valid(inst):
            placer.add(inst)
            placed.append(inst)
            return True
        ids.release(name)
        return False

    for _ in range(4000):
        if len(centres) == groves:
            break
        c = random_point(rng)
        if 20.0 <= min(placer.surface_distance(c), 80.0) and all(math.dist(c, o) >= 50.0 for o in centres):
            centres.append(c)
    for centre in centres:
        got = tries = 0
        while got < per_grove and tries < 400:
            tries += 1
            angle, radius = rng.uniform(0.0, math.tau), rng.uniform(8.0, 24.0)
            got += attempt(centre[0] + radius * math.cos(angle), centre[1] + radius * math.sin(angle))
    tries = 0
    while len(placed) < total:
        tries += 1
        assert tries < 60000, f"could not place every {name}"
        attempt(*random_point(rng))
    return placed


def rockfall_report(chains, route):
    lanes = []
    for key, string, modules in chains:
        straights = [m for m in modules if m["name"] == "RC_TunnelStraight"]
        for ordinal in LANE_ORDINALS[key]:
            module = straights[ordinal]
            lanes.append({"id": f"lane-{len(lanes) + 1}", "module": module["id"], "center": [module["x"], module["z"]],
                          "rotation_y_deg": module["rotation_y_deg"], "size": list(LANE_SIZE),
                          "exit_from_center_s": r3((STRIP / 2) / WALK_SPEED), "cycle_s": DUST_S + IMPACT_S,
                          "route_arc": r3(g.project_to_polyline(route, (module["x"], module["z"]))[1])})
    return {"dust_s": DUST_S, "impact_s": IMPACT_S, "strip_width": STRIP, "lanes": lanes}


def points_of_interest(route, surface, mouths, roles, rockfall):
    by_id = {m["id"]: m for m in mouths}
    pois = [("gate_west", route[0])]
    names = {"west": "mouth_west", "exit": "mouth_exit", "east": "mouth_east"}
    for role in roles:
        m = by_id[role["id"]]
        pois.append((names[role["role"]], (m["x"], m["z"])))
    for k, lane in enumerate(rockfall["lanes"]):
        pois.append((f"rockfall_{k + 1}", tuple(lane["center"])))
    clearing = surface[1]
    pois.append(("crystal_hollow", g.polyline_point(clearing, g.polyline_length(clearing) / 2)[0]))
    pois.append(("gate_east", route[-1]))
    return [{"name": n, "point": [r3(p[0]), r3(p[1])], "route_arc": r3(g.project_to_polyline(route, p)[1])}
            for n, p in pois]


DECISIONS = [
    "The route is two snapped tunnels joined by a short daylight clearing: tunnel A (nine straights, four bends) "
    "from the west mouth to the exit mouth, a 60 stud clearing, then tunnel B from the east mouth to the east edge. "
    "The bible gives only the module mix (18 straights, 8 bends, 3 mouths); the chains were found by a bounded search "
    "and fixed as strings (S straight, R bend through end A, L bend through end B).",
    "Joints are computed from the measured end rings (centre and outward facing of ends A and B) with the kit frame "
    "(local x = -Blender x); a right bend entered through end B is a left turn, so bends are never mirrored.",
    "Rockfall lanes are 10 studs along the tunnel across the whole 14 stud floor (leaving from the centre takes "
    "0.31 s at 16 studs/s), on the centre of four straight modules, two per tunnel, at least 50 studs apart. The "
    "bible does not say which axis the strip is wide on.",
    "Each cave mouth sits on the route with its rear plane on the tunnel joint; the measured gap (+-8.1) contains the "
    "14 stud corridor. The far mouth faces outward, so the exit mouth is turned around.",
    "Nothing stands inside a tunnel: the 14 stud clear width equals the route corridor. Crystal clusters, ore veins, "
    "stalagmites and burrows stand on the surface around the approach and the clearing; gather points are measured to "
    "those two surface stretches only (8 to 40 studs, facing them).",
    "The route is about 700 studs, far longer than the 19 s sector crossing in the bible, because 26 modules at "
    "24 to 28 studs cannot fit a shorter path. Hostile night rules do not apply here (bible section 2).",
    "Tunnel footprints are convex pieces from the measured geometry: a 25.7 x 24 box per straight and six wedges per "
    "bend (radii 5.7 to 31.3 about the arc centre); non-adjacent modules stay at least 2 studs apart.",
]


def generate(seed=DEFAULT_SEED):
    rng = random.Random(seed)
    ids = IdSource()
    chains, mouths, roles, route, surface = build_structures(ids)
    tunnel_records = check_structures(chains, mouths, roles)
    structures = [m for _, _, mods in chains for m in mods] + mouths
    placer = Placer(structures, route, surface)
    crystals = place_gatherables(placer, ids, rng, "RC_CrystalCluster", dict(MIX)["RC_CrystalCluster"], CRYSTALS_IN_CLEARING)
    veins = place_gatherables(placer, ids, rng, "RC_OreVein", dict(MIX)["RC_OreVein"], VEINS_IN_CLEARING)
    stalagmites = place_scatter(placer, ids, rng, "RC_Stalagmite", dict(MIX)["RC_Stalagmite"], groves=5, per_grove=6)
    burrows = place_scatter(placer, ids, rng, "RC_Burrow", dict(MIX)["RC_Burrow"])
    modules = [m for _, _, mods in chains for m in mods]
    instances = mouths + modules + stalagmites + crystals + veins + burrows
    tunnel_length = sum(g.polyline_length(dedupe(module_path(m))) for m in modules)
    for inst in modules:
        inst.pop("entry", None)
        inst.pop("tunnel", None)
    by_name = {}
    for name, count in MIX:
        assert len([i for i in instances if i["name"] == name]) == count, name
        by_name[name] = {"count": count, "triangles": count * PROPS[name]["tris"]}
    rockfall = rockfall_report(chains, route)
    length = g.polyline_length(route)
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
            "collision_boxes": sum(c * PROPS[n].get("collision", 0) for n, c in MIX),
            "occluder_boxes": sum(c * PROPS[n].get("occluders", 0) for n, c in MIX),
            "by_name": by_name,
        },
        "route": {"nodes": [list(p) for p in route], "length": r3(length), "walk_seconds": r3(length / WALK_SPEED),
                  "corridor_width": 2 * CORRIDOR_HALF},
        "surface_routes": [{"nodes": [list(p) for p in poly], "length": r3(g.polyline_length(poly))} for poly in surface],
        "points_of_interest": points_of_interest(route, surface, mouths, roles, rockfall),
        "tunnels": tunnel_records,
        "mouths": roles,
        "rockfall": rockfall,
        "density": {"props_per_1000_sq_studs": round(len(instances) / (MAP_SIZE * MAP_SIZE / 1000.0), 3),
                    "tunnel_length": r3(tunnel_length)},
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
    scene.text(MAP_X0, 34, "Rock and Caves placement plan v1 - DRAFT, unvalidated - top-down", size=22, bold=True)
    scene.text(MAP_X0, 54, "seed %d | 300 x 300 studs | north (-z) is up | symbols enlarged" % layout["seed"], size=13,
               fill="#444444")
    scene.rect(world.px(-150), world.py(-150), 300 * s, 300 * s, fill="#d9d4c8", stroke="#222222", sw=2)
    for v in range(-150, 151, 50):
        scene.line([(world.px(v), world.py(-150)), (world.px(v), world.py(150))], stroke="#000000", sw=0.8, so=0.10)
        scene.line([(world.px(-150), world.py(v)), (world.px(150), world.py(v))], stroke="#000000", sw=0.8, so=0.10)
        scene.text(world.px(v), world.py(150) + 18, str(v), size=11, fill="#555555", anchor="middle")
        scene.text(world.px(-150) - 6, world.py(v) + 4, str(v), size=11, fill="#555555", anchor="end")
    by = {name: [i for i in layout["instances"] if i["name"] == name] for name, _ in MIX}
    for inst in by["RC_TunnelStraight"] + by["RC_TunnelBend"]:
        for poly in pieces(inst):
            scene.poly([world.pt(p) for p in poly.pts], fill="#3f3d3b", fo=0.78, stroke="#3f3d3b", sw=0.6)
    for inst in by["RC_CaveMouth"]:
        for poly in pieces(inst):
            scene.poly([world.pt(p) for p in poly.pts], fill="#7d5a42", fo=0.9, stroke="#111111", sw=1.4)
    route = [tuple(p) for p in layout["route"]["nodes"]]
    scene.line([world.pt(p) for p in route], stroke="#e8d9a8", sw=2 * CORRIDOR_HALF * s, so=0.55)
    scene.line([world.pt(p) for p in route], stroke="#fff6d6", sw=1.2, dash=(8, 6))
    for lane in layout["rockfall"]["lanes"]:
        poly = g.rect_poly(lane["center"][0], lane["center"][1], lane["size"][0] / 2, lane["size"][1] / 2,
                           lane["rotation_y_deg"])
        scene.poly([world.pt(p) for p in poly.pts], fill="#c0392b", fo=0.45, stroke="#c0392b", sw=1.4)
    for inst in by["RC_Stalagmite"]:
        x, y = world.px(inst["x"]), world.py(inst["z"])
        scene.poly([(x, y - 6), (x + 5, y + 4), (x - 5, y + 4)], fill="#8f8879", stroke="#222222", sw=0.8)
    for inst in by["RC_Burrow"]:
        scene.circle(world.px(inst["x"]), world.py(inst["z"]), 3.2 * s * inst["scale"] * 0.6, fill="#121214",
                     stroke="#7d5a42", sw=1.2)
    for inst in by["RC_OreVein"]:
        scene.circle(world.px(inst["x"]), world.py(inst["z"]), 4.1 * s * inst["scale"] * 0.7, fill="#b0772e",
                     stroke="#111111", sw=0.9)
        gx, gz = gather_point(inst)
        scene.circle(world.px(gx), world.py(gz), 2.2, fill="#ffffff", stroke="#111111", sw=0.8)
    for inst in by["RC_CrystalCluster"]:
        x, y = world.px(inst["x"]), world.py(inst["z"])
        scene.poly([(x, y - 7), (x + 5, y), (x, y + 7), (x - 5, y)], fill="#3fbfa8", stroke="#111111", sw=0.9)
        gx, gz = gather_point(inst)
        scene.circle(world.px(gx), world.py(gz), 2.2, fill="#ffffff", stroke="#111111", sw=0.8)
    for poi in layout["points_of_interest"]:
        if poi["name"] in ("gate_west", "gate_east", "crystal_hollow"):
            scene.circle(world.px(poi["point"][0]), world.py(poi["point"][1]), 5, fill="#ffffff", stroke="#3a2f12", sw=2)
            anchor = "end" if poi["point"][0] > 40 else "start"
            scene.text(world.px(poi["point"][0]) + (-10 if poi["point"][0] > 40 else 10), world.py(poi["point"][1]) - 10,
                       poi["name"], size=12, bold=True, fill="#3a2f12", anchor=anchor)
    x0, y = 780.0, 100.0
    t = layout["totals"]
    scene.text(x0, y, "Legend", size=17, bold=True)
    rows = [("Trail 14 wide (centreline dashed)", "#e8d9a8"), ("Tunnel module (snapped end to end)", "#3f3d3b"),
            ("Cave mouth", "#7d5a42"), ("Rockfall strip 10 x 14", "#c0392b"), ("Stalagmite", "#8f8879"),
            ("Crystal cluster, dot = gather", "#3fbfa8"), ("Ore vein, dot = gather", "#b0772e"), ("Burrow", "#121214")]
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
                 "Tunnels: 18 straights + 8 bends in two chains",
                 "Rockfall: dust 3 s, rocks 2 s, 4 lanes"]:
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
    lines += ["  %-18s x%-3d %6d tris" % (k, v["count"], v["triangles"]) for k, v in t["by_name"].items()]
    lines.append("route %.0f studs (%.1f s), %d rockfall lanes, joint errors %s"
                 % (layout["route"]["length"], layout["route"]["walk_seconds"], len(layout["rockfall"]["lanes"]),
                    [t_["max_joint_error"] for t_ in layout["tunnels"]]))
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

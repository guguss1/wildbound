#!/usr/bin/env python3
"""Reproducible top-down placement DRAFT for one Living Forest sector (unvalidated).

This is a plan only: it writes JSON, SVG and (when Pillow is importable) PNG files and never
touches the Luau map builder, Studio or Blender. Python standard library only; Pillow is
optional. The plan stays a draft for a later sector design: it is not an approved layout, was
never imported into Roblox, and no budget in it was measured on a device.

    python tools/plan_living_forest_layout.py [--seed N] [--out-dir DIR]

Conventions (studs, origin at the sector centre): x grows east, z grows south,
rotation_y_deg is CFrame.Angles(0, math.rad(r), 0) (see tools/layout_geometry.py).
Spec: docs/design/wildbound-expansion-bible.md section 2 (Living Forest) and 5.3.
Prop sizes are the measured Blender kit values (assets/blender/living-forest-kit).
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

DEFAULT_SEED = 20261108
LAYOUT_NAME = "living-forest-layout-v1"
DEFAULT_OUT_DIR = TOOLS.parent / "assets" / "maps" / "living-forest-layout"

# ---- Spec inputs (bible section 2 and 5.3) --------------------------------------------
MAP_SIZE = 400.0
LIMIT = MAP_SIZE / 2 - 5.0
MAX_INSTANCES, MAX_TRIANGLES = 180, 40000
MIX = (("LF_Broadleaf", 46), ("LF_ResinStump", 10), ("LF_FlowerClump", 60), ("LF_StreamStone", 24),
       ("LF_HollowArch", 2), ("LF_TrailPost", 16), ("LF_LogBridge", 4))
WALK_SPEED = 16.0   # documented, not rechecked (bible section 1)
WATER_HALF = 6.0    # 12-stud stream, slows walking to 10 studs/s; stones and bridges keep full speed
CORRIDOR_HALF = 7.0  # 14-stud trail

# Draft route: west gate (toward the start place) to east gate. Hand-placed so that the two
# streams cross it four times at 75 to 87 degrees, each crossing well away from any bend.
ROUTE_NODES = (("gate_west", (-185.0, 70.0)), ("glade", (-125.0, 30.0)), ("ford_west", (-70.0, -25.0)),
               ("hollow", (-5.0, -75.0)), ("meadow", (55.0, -20.0)), ("ford_east", (115.0, 35.0)),
               ("ridge", (160.0, 110.0)), ("gate_east", (185.0, 165.0)))
ROUTE = [p for _, p in ROUTE_NODES]
STREAMS = {
    "S1": [(-195.0, -110.0), (-140.0, -45.0), (-80.0, 22.0), (-55.0, 50.0), (-28.0, 52.0), (-8.0, 28.0),
           (8.0, -12.0), (40.0, -70.0), (58.0, -110.0), (62.0, -195.0)],
    "S2": [(30.0, 100.0), (52.0, 62.0), (104.0, -8.0), (122.0, -38.0), (150.0, -52.0), (186.0, -30.0),
           (190.0, 22.0), (168.0, 50.0), (120.0, 98.0), (100.0, 128.0), (95.0, 150.0), (90.0, 195.0)],
}

# Measured kit values: "tris" and "parts" from living-forest-kit-report.json, "budget" from the
# bible table. Footprints are conservative symmetric bounds of the measured geometry.
PROPS = {
    "LF_Broadleaf": {"kind": "tree", "tris": 428, "budget": 480, "parts": 2, "roots_r": 4.7, "core_r": 2.5,
                     "canopy_r": 13.8, "scale": (0.9, 1.15)},
    "LF_ResinStump": {"kind": "stump", "tris": 172, "budget": 180, "parts": 2, "r": 3.2, "scale": (0.9, 1.2),
                      "gather_local_z": -3.0},
    "LF_FlowerClump": {"kind": "flower", "tris": 84, "budget": 90, "parts": 2, "r": 2.7, "scale": (0.8, 1.2)},
    "LF_StreamStone": {"kind": "stone", "tris": 76, "budget": 80, "parts": 2, "half": (2.85, 2.05)},
    "LF_HollowArch": {"kind": "arch", "tris": 460, "budget": 520, "parts": 2, "half": (15.1, 7.3),
                      "passage": (-8.152, 8.373), "clear_h": 11.3},
    "LF_TrailPost": {"kind": "post", "tris": 146, "budget": 160, "parts": 3, "r": 1.85},
    "LF_LogBridge": {"kind": "bridge", "tris": 292, "budget": 300, "parts": 2, "half": (2.75, 9.15)},
}
SHORT = {"LF_Broadleaf": "tree", "LF_ResinStump": "stump", "LF_FlowerClump": "flower", "LF_StreamStone": "stone",
         "LF_HollowArch": "arch", "LF_TrailPost": "post", "LF_LogBridge": "bridge"}

# Design thresholds chosen by this draft.
BASE_GAP = 1.0           # minimum gap between solid bases
TRAIL_CLEAR_CENTRE = 12.0  # tree and stump anchors stay this far from the centreline
TREE_SPACING = 16.0      # trunk to trunk: canopies may touch but not stack
POST_OFFSET = 9.5        # posts stand just outside the corridor, alternating sides
CHAIN_OFFSETS = (-6.2, 0.0, 6.2)  # stone centres along the crossing; stones are 5 long, so gaps are 1.2
CHAIN_COUNT_PER_STREAM = 4
ARCH_ARCS = (36.0, -30.0)  # route arc position; negative counts back from the east gate
FLOWER_PATCHES = 10


def r3(value):
    return round(float(value), 3) + 0.0


def make_instance(name, x, z, yaw, scale, **extra):
    yaw = r3(yaw % 360.0)
    return {"name": name, "x": r3(x), "z": r3(z), "rotation_y_deg": 0.0 if yaw >= 360.0 else yaw,
            "scale": r3(scale), **extra}


def footprint(inst):
    """Ground footprint: roots, base or rectangle, at the instance scale."""
    spec, s = PROPS[inst["name"]], inst["scale"]
    if spec["kind"] == "tree":
        return g.Circle(inst["x"], inst["z"], spec["roots_r"] * s)
    if "r" in spec:
        return g.Circle(inst["x"], inst["z"], spec["r"] * s)
    return g.rect_poly(inst["x"], inst["z"], spec["half"][0], spec["half"][1], inst["rotation_y_deg"])


def gather_point(inst):
    r = math.radians(inst["rotation_y_deg"])
    offset = PROPS["LF_ResinStump"]["gather_local_z"] * inst["scale"]
    return (inst["x"] + offset * math.sin(r), inst["z"] + offset * math.cos(r))


ROUTE_LENGTH = g.polyline_length(ROUTE)


def route_distance(p):
    return g.project_to_polyline(ROUTE, p)[0]


def stream_distance(p):
    return min(g.project_to_polyline(nodes, p)[0] for nodes in STREAMS.values())


class Placer:
    """Collects accepted instances and answers 'may this one go here?'."""

    def __init__(self):
        self.items = []  # (inst, shape, kind)

    def add(self, inst):
        self.items.append((inst, footprint(inst), PROPS[inst["name"]]["kind"]))

    def pair_gap(self, kind, other):
        if "flower" in (kind, other):
            return 0.3
        if {kind, other} == {"stone", "bridge"}:
            return 3.0
        return BASE_GAP

    def valid(self, inst, skip=()):
        kind = PROPS[inst["name"]]["kind"]
        shape = footprint(inst)
        x0, z0, x1, z1 = g.shape_bbox(shape)
        if min(x0, z0) < -LIMIT or max(x1, z1) > LIMIT:
            return False
        anchor = (inst["x"], inst["z"])
        route_gap = g.shape_polyline_dist(shape, ROUTE)
        if kind in ("tree", "stump"):
            if route_gap < CORRIDOR_HALF + BASE_GAP or route_distance(anchor) < TRAIL_CLEAR_CENTRE:
                return False
        elif kind == "post":
            if route_gap < CORRIDOR_HALF + 0.2:
                return False
        elif kind == "flower":
            if route_gap < 4.0:
                return False
        elif kind == "stone":
            if route_gap < CORRIDOR_HALF + BASE_GAP:
                return False
        if kind in ("tree", "stump", "post", "arch", "flower"):
            margin = WATER_HALF + (0.5 if kind == "flower" else BASE_GAP)
            if any(g.shape_polyline_dist(shape, nodes) < margin for nodes in STREAMS.values()):
                return False
        for other, other_shape, other_kind in self.items:
            if other["id"] in skip:
                continue
            if kind == "tree" == other_kind and math.dist(anchor, (other["x"], other["z"])) < TREE_SPACING:
                return False
            if g.shape_gap(shape, other_shape) < self.pair_gap(kind, other_kind):
                return False
        if kind == "stump":
            point = gather_point(inst)
            distance = route_distance(point)
            if not 8.0 <= distance < route_distance(anchor) or stream_distance(point) <= WATER_HALF + 0.5:
                return False
            for other, other_shape, other_kind in self.items:
                if other_kind != "flower" and g.shape_point_dist(other_shape, point) < BASE_GAP:
                    return False
        return True


class IdSource:
    def __init__(self):
        self.counts = {}

    def next(self, name):
        key = SHORT[name]
        self.counts[key] = self.counts.get(key, 0) + 1
        return f"{key}-{self.counts[key]:02d}"


def route_pose(arc):
    """Point, heading and segment index at a route arc position."""
    point, direction, index = g.polyline_point(ROUTE, arc)
    return point, g.heading_deg(*direction), index


def place_bridges(placer, ids):
    """One bridge per route/stream crossing, laid along the route heading."""
    bridges, crossings = [], []
    for name, nodes in STREAMS.items():
        for c in g.crossings(ROUTE, nodes):
            heading = g.heading_deg(*c["first_dir"])
            inst = make_instance("LF_LogBridge", c["point"][0], c["point"][1], heading, 1.0, id=ids.next("LF_LogBridge"))
            assert placer.valid(inst), f"bridge at {c['point']} does not fit"
            placer.add(inst)
            bridges.append(inst)
            crossings.append({"stream": name, "point": [r3(c["point"][0]), r3(c["point"][1])],
                              "angle_deg": r3(c["angle_deg"]), "route_arc": r3(c["first_arc"]),
                              "water_chord": r3(2 * WATER_HALF / math.sin(math.radians(c["angle_deg"]))),
                              "bridge_id": inst["id"]})
    return bridges, crossings


def place_arches(placer, ids):
    arches = []
    for arc in ARCH_ARCS:
        point, heading, _ = route_pose(arc if arc >= 0 else ROUTE_LENGTH + arc)
        inst = make_instance("LF_HollowArch", point[0], point[1], heading, 1.0, id=ids.next("LF_HollowArch"))
        assert placer.valid(inst), f"arch at {point} does not fit"
        placer.add(inst)
        arches.append(inst)
    return arches


def place_posts(placer, ids):
    count = dict(MIX)["LF_TrailPost"]
    spacing = (ROUTE_LENGTH - 36.0) / (count - 1)
    posts = []
    for k in range(count):
        base_arc, placed = 18.0 + spacing * k, None
        for delta in (0.0, 4.0, -4.0, 8.0, -8.0, 12.0, -12.0):
            arc = min(max(base_arc + delta, 6.0), ROUTE_LENGTH - 6.0)
            point, direction, _ = g.polyline_point(ROUTE, arc)
            for side in ((1, -1) if k % 2 == 0 else (-1, 1)):
                normal = (-direction[1] * side, direction[0] * side)
                inst = make_instance("LF_TrailPost", point[0] + normal[0] * POST_OFFSET,
                                     point[1] + normal[1] * POST_OFFSET, 0.0, 1.0, id=ids.next("LF_TrailPost"))
                if placer.valid(inst):
                    placed = inst
                    break
                ids.counts["post"] -= 1
            if placed:
                break
        assert placed, f"no room for trail post {k}"
        placer.add(placed)
        posts.append(placed)
    return posts


def place_chains(placer, ids, rng, bridges):
    """Three stones across each chosen stretch of stream, long axis across the water."""
    stones, chains = [], []
    for name, nodes in STREAMS.items():
        length = g.polyline_length(nodes)
        arcs = [45.0 + 5.0 * k for k in range(int((length - 90.0) / 5.0) + 1)]
        rng.shuffle(arcs)
        taken = []
        for arc in arcs:
            if len(taken) == CHAIN_COUNT_PER_STREAM:
                break
            centre, direction, _ = g.polyline_point(nodes, arc)
            if any(abs(arc - other) < 70.0 for other in taken):
                continue
            if min(math.dist(centre, v) for v in nodes) < 8.0 or route_distance(centre) < 18.0:
                continue
            if min(math.dist(centre, (b["x"], b["z"])) for b in bridges) < 30.0:
                continue
            normal = (-direction[1], direction[0])
            made = [make_instance("LF_StreamStone", centre[0] + normal[0] * o, centre[1] + normal[1] * o,
                                  g.heading_deg(*direction), 1.0, id=f"stone-{len(stones) + i + 1:02d}", chain=len(chains))
                    for i, o in enumerate(CHAIN_OFFSETS)]
            trial = Placer()
            trial.items = list(placer.items)
            if not all(placer.valid(m, skip={n["id"] for n in made}) for m in made):
                continue
            for m in made:
                placer.add(m)
            taken.append(arc)
            stones.extend(made)
            chains.append({"stream": name, "arc": r3(arc), "center": [r3(centre[0]), r3(centre[1])],
                           "stone_ids": [m["id"] for m in made]})
    assert len(chains) == CHAIN_COUNT_PER_STREAM * len(STREAMS), "not enough straight stream for the stone chains"
    return stones, chains


def random_point(rng):
    return (rng.uniform(-LIMIT, LIMIT), rng.uniform(-LIMIT, LIMIT))


def place_trees(placer, ids, rng):
    target = dict(MIX)["LF_Broadleaf"]
    spec = PROPS["LF_Broadleaf"]
    trees, centres = [], []

    def try_tree(x, z):
        inst = make_instance("LF_Broadleaf", x, z, rng.uniform(0.0, 360.0), rng.uniform(*spec["scale"]),
                             id=ids.next("LF_Broadleaf"))
        if placer.valid(inst):
            placer.add(inst)
            trees.append(inst)
            return True
        ids.counts["tree"] -= 1
        return False

    # Groves first: loose clusters 30 to 70 studs off the trail, then scatter fills the rest.
    for _ in range(4000):
        if len(centres) == 7:
            break
        c = random_point(rng)
        if 30.0 <= route_distance(c) <= 70.0 and stream_distance(c) > 20.0 and \
                all(math.dist(c, o) >= 70.0 for o in centres):
            centres.append(c)
    for index, centre in enumerate(centres):
        want, attempts = (6, 6, 6, 5, 5, 5, 4)[index], 0
        got = 0
        while got < want and attempts < 400:
            attempts += 1
            angle, radius = rng.uniform(0.0, math.tau), rng.uniform(14.0, 34.0)
            got += try_tree(centre[0] + radius * math.cos(angle), centre[1] + radius * math.sin(angle))
    attempts = 0
    while len(trees) < target:
        attempts += 1
        assert attempts < 40000, "could not place every broadleaf"
        try_tree(*random_point(rng))
    return trees


def place_stumps(placer, ids, rng):
    target = dict(MIX)["LF_ResinStump"]
    spec = PROPS["LF_ResinStump"]
    stumps, attempts = [], 0
    while len(stumps) < target:
        attempts += 1
        assert attempts < 40000, "could not place every stump"
        point, direction, _ = g.polyline_point(ROUTE, rng.uniform(0.0, ROUTE_LENGTH))
        side = rng.choice((-1, 1))
        lateral = rng.uniform(16.0, 40.0) * side
        x, z = point[0] - direction[1] * lateral, point[1] + direction[0] * lateral
        foot = g.project_to_polyline(ROUTE, (x, z))
        nearest, _, _ = g.polyline_point(ROUTE, foot[1])
        inst = make_instance("LF_ResinStump", x, z, g.heading_deg(-(nearest[0] - x), -(nearest[1] - z)),
                             rng.uniform(*spec["scale"]), id=ids.next("LF_ResinStump"))
        if placer.valid(inst):
            placer.add(inst)
            stumps.append(inst)
        else:
            ids.counts["stump"] -= 1
    return stumps


def place_flowers(placer, ids, rng):
    target = dict(MIX)["LF_FlowerClump"]
    spec = PROPS["LF_FlowerClump"]
    flowers, patches = [], []
    per_patch = target // FLOWER_PATCHES
    attempts = 0
    while len(flowers) < target:
        attempts += 1
        assert attempts < 80000, "could not place every flower"
        if attempts % 1 == 0 and (not patches or patches[-1]["left"] == 0):
            if len(patches) >= FLOWER_PATCHES:
                patches.append({"centre": random_point(rng), "left": target - len(flowers), "size": 0})
            else:
                along_route = len(patches) % 2 == 0
                if along_route:
                    point, direction, _ = g.polyline_point(ROUTE, rng.uniform(0.0, ROUTE_LENGTH))
                    lateral = rng.choice((-1, 1)) * rng.uniform(9.0, 24.0)
                    centre = (point[0] - direction[1] * lateral, point[1] + direction[0] * lateral)
                else:
                    nodes = rng.choice(list(STREAMS.values()))
                    point, direction, _ = g.polyline_point(nodes, rng.uniform(0.0, g.polyline_length(nodes)))
                    lateral = rng.choice((-1, 1)) * rng.uniform(11.0, 17.0)
                    centre = (point[0] - direction[1] * lateral, point[1] + direction[0] * lateral)
                patches.append({"centre": centre, "left": per_patch, "size": 0})
        patch = patches[-1]
        angle, radius = rng.uniform(0.0, math.tau), rng.uniform(0.0, 11.0)
        inst = make_instance("LF_FlowerClump", patch["centre"][0] + radius * math.cos(angle),
                             patch["centre"][1] + radius * math.sin(angle), rng.uniform(0.0, 360.0),
                             rng.uniform(*spec["scale"]), id=ids.next("LF_FlowerClump"))
        if placer.valid(inst):
            placer.add(inst)
            flowers.append(inst)
            patch["left"] -= 1
            patch["size"] += 1
        else:
            ids.counts["flower"] -= 1
            patch["misses"] = patch.get("misses", 0) + 1
            if patch["misses"] > 60:  # a patch that cannot fill gives up and the next one starts
                patch["left"] = 0
    return flowers, [p["size"] for p in patches if p["size"]]


def canopy_cover(trees):
    covered = total = 0
    for ix in range(-195, 196, 5):
        for iz in range(-195, 196, 5):
            total += 1
            covered += any(math.hypot(ix - t["x"], iz - t["z"]) <= PROPS["LF_Broadleaf"]["canopy_r"] * t["scale"]
                           for t in trees)
    return covered / total


def generate(seed=DEFAULT_SEED):
    rng = random.Random(seed)
    placer, ids = Placer(), IdSource()
    bridges, crossings = place_bridges(placer, ids)
    arches = place_arches(placer, ids)
    posts = place_posts(placer, ids)
    stones, chains = place_chains(placer, ids, rng, bridges)
    trees = place_trees(placer, ids, rng)
    stumps = place_stumps(placer, ids, rng)
    flowers, patches = place_flowers(placer, ids, rng)
    instances = trees + stumps + flowers + stones + arches + posts + bridges
    for inst in instances:
        inst.pop("chain", None)
    by_name = {}
    for name, count in MIX:
        found = [i for i in instances if i["name"] == name]
        assert len(found) == count, f"{name}: {len(found)} placed, {count} planned"
        by_name[name] = {"count": count, "triangles": count * PROPS[name]["tris"]}
    totals = {
        "instances": len(instances),
        "triangles_measured": sum(v["triangles"] for v in by_name.values()),
        "triangles_budget": sum(c * PROPS[n]["budget"] for n, c in MIX),
        "mesh_parts": sum(c * PROPS[n]["parts"] for n, c in MIX),
        "by_name": by_name,
    }
    cover = canopy_cover(trees)
    return {
        "name": LAYOUT_NAME,
        "status": "draft, unvalidated: never imported into Roblox, played or measured on a device",
        "seed": seed,
        "map_size": MAP_SIZE,
        "caps": {"instances": MAX_INSTANCES, "triangles": MAX_TRIANGLES},
        "totals": totals,
        "route": {"nodes": [list(p) for p in ROUTE], "names": [n for n, _ in ROUTE_NODES],
                  "length": r3(ROUTE_LENGTH), "walk_seconds": r3(ROUTE_LENGTH / WALK_SPEED),
                  "corridor_width": 2 * CORRIDOR_HALF},
        "streams": [{"name": n, "nodes": [list(p) for p in nodes], "water_width": 2 * WATER_HALF,
                     "length": r3(g.polyline_length(nodes))} for n, nodes in STREAMS.items()],
        "crossings": crossings,
        "chains": chains,
        "density": {"canopy_cover_fraction": round(cover, 4),
                    "props_per_1000_sq_studs": round(len(instances) / (MAP_SIZE * MAP_SIZE / 1000.0), 3),
                    "flower_patches": patches},
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
    scene.text(MAP_X0, 34, "Living Forest placement plan v1 - DRAFT, unvalidated - top-down", size=22, bold=True)
    scene.text(MAP_X0, 54, "seed %d | 400 x 400 studs | north (-z) is up | symbols enlarged" % layout["seed"], size=13,
               fill="#444444")
    scene.rect(world.px(-200), world.py(-200), 400 * s, 400 * s, fill="#dfe9c8", stroke="#222222", sw=2)
    for v in range(-200, 201, 50):
        scene.line([(world.px(v), world.py(-200)), (world.px(v), world.py(200))], stroke="#000000", sw=0.8, so=0.10)
        scene.line([(world.px(-200), world.py(v)), (world.px(200), world.py(v))], stroke="#000000", sw=0.8, so=0.10)
        scene.text(world.px(v), world.py(200) + 18, str(v), size=11, fill="#555555", anchor="middle")
        scene.text(world.px(-200) - 6, world.py(v) + 4, str(v), size=11, fill="#555555", anchor="end")
    by = {name: [i for i in layout["instances"] if i["name"] == name] for name, _ in MIX}
    for nodes in STREAMS.values():
        scene.line([world.pt(p) for p in nodes], stroke="#6fb6d6", sw=2 * WATER_HALF * s, so=0.85)
    for tree in by["LF_Broadleaf"]:
        scene.circle(world.px(tree["x"]), world.py(tree["z"]), PROPS["LF_Broadleaf"]["canopy_r"] * tree["scale"] * s,
                     fill="#3f7d2c", fo=0.13)
    scene.line([world.pt(p) for p in ROUTE], stroke="#c9a96a", sw=2 * CORRIDOR_HALF * s, so=0.9)
    scene.line([world.pt(p) for p in ROUTE], stroke="#6b5320", sw=1.2, dash=(8, 6))
    for flower in by["LF_FlowerClump"]:
        scene.circle(world.px(flower["x"]), world.py(flower["z"]), 3.2, fill="#f2c14e", stroke="#a77b10", sw=0.8)
    for tree in by["LF_Broadleaf"]:
        scene.circle(world.px(tree["x"]), world.py(tree["z"]), 5.5, fill="#245b1d", stroke="#ffffff", sw=0.9)
    for stump in by["LF_ResinStump"]:
        scene.circle(world.px(stump["x"]), world.py(stump["z"]), PROPS["LF_ResinStump"]["r"] * stump["scale"] * s,
                     fill="#6b4a2f", stroke="#111111", sw=1)
        gx, gz = gather_point(stump)
        scene.circle(world.px(gx), world.py(gz), 3.0, fill="#d98a1f", stroke="#111111", sw=0.8)
    for inst in by["LF_StreamStone"]:
        scene.poly([world.pt(p) for p in footprint(inst).pts], fill="#8c8a7e", stroke="#333333", sw=1)
    for inst in by["LF_LogBridge"]:
        scene.poly([world.pt(p) for p in footprint(inst).pts], fill="#6b4a2f", fo=0.85, stroke="#111111", sw=1.2)
    for inst in by["LF_HollowArch"]:
        scene.poly([world.pt(p) for p in footprint(inst).pts], fill="#2f6b2a", fo=0.25, stroke="#111111", sw=1.6)
    for inst in by["LF_TrailPost"]:
        scene.rect(world.px(inst["x"]) - 3.5, world.py(inst["z"]) - 3.5, 7, 7, fill="#d9482b", stroke="#111111", sw=0.8)
    for name, (x, z) in ROUTE_NODES:
        scene.circle(world.px(x), world.py(z), 5, fill="#ffffff", stroke="#3a2f12", sw=2)
        anchor = "end" if x > 100 else "start"
        scene.text(world.px(x) + (-10 if x > 100 else 10), world.py(z) - 10, name, size=12, bold=True,
                   fill="#3a2f12", anchor=anchor)
    # Legend and totals.
    x0, y = 880.0, 100.0
    t = layout["totals"]
    scene.text(x0, y, "Legend", size=17, bold=True)
    rows = [("Trail 14 wide (centreline dashed)", "#c9a96a"), ("Stream 12 wide, slows to 10 studs/s", "#6fb6d6"),
            ("Broadleaf canopy shade (r 13.8)", "#3f7d2c"), ("Resin stump, dot = gather side", "#6b4a2f"),
            ("Flower clump", "#f2c14e"), ("Stepping stones, 8 chains of 3", "#8c8a7e"),
            ("Log bridge on each crossing", "#6b4a2f"), ("Hollow arch over the trail", "#2f6b2a"),
            ("Trail post", "#d9482b")]
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
                 "Canopy shade %.0f%% of the sector" % (100 * layout["density"]["canopy_cover_fraction"])]:
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
    lines.append("route %.0f studs (%.1f s), %d crossings, %d stone chains, canopy cover %.1f%%, flower patches %s"
                 % (layout["route"]["length"], layout["route"]["walk_seconds"], len(layout["crossings"]),
                    len(layout["chains"]), 100 * layout["density"]["canopy_cover_fraction"],
                    layout["density"]["flower_patches"]))
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

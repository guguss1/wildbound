#!/usr/bin/env python3
"""Reproducible top-down placement DRAFT for one Demon Abyss sector (unvalidated).

This is a plan only: it writes JSON, SVG and (when Pillow is importable) PNG files and never
touches the Luau map builder, Studio or Blender. Python standard library only; Pillow is
optional. The plan stays a draft for a later sector design: it is not an approved layout, was
never imported into Roblox, and no budget in it was measured on a device.

    python tools/plan_demon_abyss_layout.py [--seed N] [--out-dir DIR]

Conventions (studs, origin at the sector centre): x grows east, z grows south,
rotation_y_deg is CFrame.Angles(0, math.rad(r), 0) (see tools/layout_geometry.py). Kit frame to
plan frame: local x = -Blender x, local z = Blender y (docs: Blender (x, y, z) to Studio (-x, z, y)).
Spec: docs/design/wildbound-expansion-bible.md sections 2 (Demon Abyss) and 5.8. Broken ground
over a dark drop: the trail crosses three chasms on chains of floating rocks (they sink 1 stud/s
while occupied, up to 6 s, 1.5 studs/s at night). Calm stones are the rest on each bank.
Prop sizes are the measured Blender kit values (assets/blender/demon-abyss-kit).
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

DEFAULT_SEED = 20261111
LAYOUT_NAME = "demon-abyss-layout-v1"
DEFAULT_OUT_DIR = TOOLS.parent / "assets" / "maps" / "demon-abyss-layout"

# ---- Spec inputs (bible section 2 and 5.8) ----------------------------------------------
MAP_SIZE = 300.0
LIMIT = MAP_SIZE / 2 - 5.0
MAX_INSTANCES, MAX_TRIANGLES = 120, 25000
MIX = (("DA_FissureLip", 24), ("DA_FloatRock", 30), ("DA_ThornSpire", 30), ("DA_RiftGate", 2),
       ("DA_RiftShard", 14), ("DA_CalmStone", 6))
WALK_SPEED = 16.0
CORRIDOR_HALF = 7.0
SINK_DAY, SINK_NIGHT, SINK_MAX_S = 1.0, 1.5, 6.0

ROUTE_NODES = (("gate_south", (-140.0, 125.0)), ("first_bank", (10.0, 125.0)), ("mid_ridge", (130.0, 10.0)),
               ("far_bank", (-10.0, -60.0)), ("gate_north", (-50.0, -142.0)))
ROUTE = [p for _, p in ROUTE_NODES]
CHASM_ARCS = (84.0, 215.0, 405.0)       # route arc of each chasm centre, on the middle of a straight leg
GATE_ARCS = (12.0, -11.0)               # negative counts back from the north gate
ROCKS_PER_CHASM = 6
ROCK_STEP = 13.0                        # rock hull is 12 long along the trail, so a 1 stud gap
CHASM_ALONG = 84.0
CHASM_REACH = ((85.0, 85.0), (44.0, 85.0), (22.0, 85.0))  # (negative, positive) across the trail, clipped to the sector;
# chasms 2 and 3 stay short on the side facing each other so the two legs do not fold into one drop

ROCK_HULL = ((-5.2, 2.86), (-5.1, -1.81), (-3.12, -5.1), (1.64, -5.15), (3.93, -3.38), (5.74, -1.51), (6.8, 0.11),
             (5.39, 4.58), (2.09, 6.85), (-3.18, 5.82))
ROCK_WALK_BOX = 6.96
LIP_BOX = ((-9.8, -5.35), (10.1, -5.35), (10.1, 4.85), (-9.8, 4.85))

# Measured kit values: "tris" and "parts" from demon-abyss-kit-report.json, "budget" from the
# bible table. Round footprints are conservative bounding circles of the measured geometry.
PROPS = {
    "DA_FissureLip": {"kind": "lip", "tris": 210, "budget": 240, "parts": 2},
    "DA_FloatRock": {"kind": "rock", "tris": 124, "budget": 180, "parts": 2},
    "DA_ThornSpire": {"kind": "spire", "tris": 182, "budget": 200, "parts": 1, "r": 5.4, "scale": (0.9, 1.15)},
    "DA_RiftGate": {"kind": "gate", "tris": 406, "budget": 560, "parts": 2, "half": (14.5, 4.05),
                    "passage": (-8.4074, 7.3572), "clear_h": 11.2},
    "DA_RiftShard": {"kind": "shard", "tris": 88, "budget": 100, "parts": 2, "r": 3.5, "scale": (0.9, 1.2),
                     "gather_local_z": -2.5},
    "DA_CalmStone": {"kind": "calm", "tris": 108, "budget": 140, "parts": 2, "r": 3.3, "scale": (1.0, 1.0)},
}
SHORT = {"DA_FissureLip": "lip", "DA_FloatRock": "rock", "DA_ThornSpire": "spire", "DA_RiftGate": "gate",
         "DA_RiftShard": "shard", "DA_CalmStone": "calm"}

# Design thresholds chosen by this draft.
BASE_GAP = 1.0
LIP_OVERRUN = 25.0         # the bank edge may run this far past the chasm ends
LIP_FIRST_LATERAL = 19.0  # lips are packed outward from here in 1 stud steps, first valid spots win
LIP_PIVOT_BEHIND_RIM = 5.05
CALM_OFFSET = CHASM_ALONG / 2 + 16.0
CALM_LATERAL = 11.5
DECOYS_PER_CHASM = 4
SPIRES_IN_CHASMS, SPIRES_ON_BANKS = 10, 20
NIGHT_ONLY_SHARDS = 6


def r3(value):
    return round(float(value), 3) + 0.0


def make_instance(name, x, z, yaw, scale, **extra):
    yaw = r3(yaw % 360.0)
    return {"name": name, "x": r3(x), "z": r3(z), "rotation_y_deg": 0.0 if yaw >= 360.0 else yaw,
            "scale": r3(scale), **extra}


def local_to_world(inst, local_x, local_z):
    r = math.radians(inst["rotation_y_deg"])
    return (inst["x"] + local_x * math.cos(r) + local_z * math.sin(r),
            inst["z"] - local_x * math.sin(r) + local_z * math.cos(r))


def footprint(inst):
    spec, s = PROPS[inst["name"]], inst["scale"]
    if spec["kind"] == "rock":
        return g.Poly(tuple(local_to_world(inst, a, b) for a, b in ROCK_HULL))
    if spec["kind"] == "lip":
        return g.Poly(tuple(local_to_world(inst, a, b) for a, b in LIP_BOX))
    if "r" in spec:
        return g.Circle(inst["x"], inst["z"], spec["r"] * s)
    return g.rect_poly(inst["x"], inst["z"], spec["half"][0], spec["half"][1], inst["rotation_y_deg"])


def gather_point(inst):
    return local_to_world(inst, 0.0, PROPS["DA_RiftShard"]["gather_local_z"] * inst["scale"])


ROUTE_LENGTH = g.polyline_length(ROUTE)


def route_distance(p):
    return g.project_to_polyline(ROUTE, p)[0]


def at_lateral(arc, lateral):
    point, direction, _ = g.polyline_point(ROUTE, arc)
    return (point[0] - direction[1] * lateral, point[1] + direction[0] * lateral), direction


def make_chasm(index, arc):
    reach_low, reach_high = CHASM_REACH[index]
    centre, direction, leg = g.polyline_point(ROUTE, arc)
    half = CHASM_ALONG / 2

    def corners_ok(lat_low, lat_high):
        for a in (-half, half):
            for lat in (lat_low, lat_high):
                p = (centre[0] + direction[0] * a - direction[1] * lat, centre[1] + direction[1] * a + direction[0] * lat)
                if max(abs(p[0]), abs(p[1])) > LIMIT:
                    return False
        return True

    low = high = 0.0
    while low > -reach_low and corners_ok(low - 0.5, high):
        low -= 0.5
    while high < reach_high and corners_ok(low, high + 0.5):
        high += 0.5
    pts = []
    for a, lat in ((-half, low), (half, low), (half, high), (-half, high)):
        pts.append((r3(centre[0] + direction[0] * a - direction[1] * lat),
                    r3(centre[1] + direction[1] * a + direction[0] * lat)))
    assert g.polyline_point(ROUTE, arc - half)[2] == leg == g.polyline_point(ROUTE, arc + half)[2]
    return {"id": f"chasm-{index + 1}", "route_arc": r3(arc), "along_length": CHASM_ALONG, "lateral_min": low,
            "lateral_max": high, "polygon": [list(p) for p in pts], "route_rock_ids": [], "lip_ids": [],
            "hop_gap": r3(ROCK_STEP - ROCK_WALK_BOX)}


def chasm_poly(chasm):
    return g.Poly(tuple(map(tuple, chasm["polygon"])))


class Placer:
    def __init__(self):
        self.items = []  # (inst, shape, kind)

    def add(self, inst):
        self.items.append((inst, footprint(inst), PROPS[inst["name"]]["kind"]))

    def valid(self, inst, exempt_route=False):
        kind = PROPS[inst["name"]]["kind"]
        shape = footprint(inst)
        x0, z0, x1, z1 = g.shape_bbox(shape)
        if min(x0, z0) < -LIMIT or max(x1, z1) > LIMIT:
            return False
        if not exempt_route and kind != "gate" and g.shape_polyline_dist(shape, ROUTE) < CORRIDOR_HALF + BASE_GAP:
            return False
        point = gather_point(inst) if kind == "shard" else None
        for other, other_shape, other_kind in self.items:
            if g.shape_gap(shape, other_shape) < BASE_GAP:
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


def facing_route(x, z):
    foot = g.project_to_polyline(ROUTE, (x, z))
    nearest = g.polyline_point(ROUTE, foot[1])[0]
    return g.heading_deg(-(nearest[0] - x), -(nearest[1] - z))


def random_point(rng):
    return rng.uniform(-LIMIT, LIMIT), rng.uniform(-LIMIT, LIMIT)


def in_any(polys, p):
    return any(g.point_in_polygon(poly.pts, p) for poly in polys)


def place_gates(placer, ids):
    gates = []
    for arc in GATE_ARCS:
        arc = arc if arc >= 0 else ROUTE_LENGTH + arc
        point, direction, index = g.polyline_point(ROUTE, arc)
        for node in (ROUTE[index], ROUTE[index + 1]):
            assert math.dist(point, node) >= PROPS["DA_RiftGate"]["half"][1] + 1.0, "gate too near a bend"
        inst = make_instance("DA_RiftGate", point[0], point[1], g.heading_deg(*direction), 1.0, id=ids.next("DA_RiftGate"))
        assert placer.valid(inst), f"gate at arc {arc} does not fit"
        placer.add(inst)
        gates.append(inst)
    return gates


def place_chains(placer, ids):
    chasms, rocks = [], []
    for index, arc in enumerate(CHASM_ARCS):
        chasm = make_chasm(index, arc)
        for k in range(ROCKS_PER_CHASM):
            rock_arc = arc + (k - (ROCKS_PER_CHASM - 1) / 2) * ROCK_STEP
            point, direction, _ = g.polyline_point(ROUTE, rock_arc)
            inst = make_instance("DA_FloatRock", point[0], point[1], g.heading_deg(*direction), 1.0, id=ids.next("DA_FloatRock"))
            assert placer.valid(inst, exempt_route=True), f"chain rock {k} of chasm {index} does not fit"
            placer.add(inst)
            rocks.append(inst)
            chasm["route_rock_ids"].append(inst["id"])
        chasms.append(chasm)
    return chasms, rocks


def place_lips(placer, ids, chasms):
    """Lips along both rims, packed outward from the corridor: four per rim where the ground allows,
    then spares go one at a time to any rim with room until the planned 24 stand."""
    total = dict(MIX)["DA_FissureLip"]
    lips = []
    rims = []
    for chasm in chasms:
        for rim_sign in (-1, 1):
            arc, half = chasm["route_arc"], chasm["along_length"] / 2
            point, direction, _ = g.polyline_point(ROUTE, arc + rim_sign * (half + LIP_PIVOT_BEHIND_RIM))
            yaw = g.heading_deg(*direction) + (0.0 if rim_sign < 0 else 180.0)
            laterals = sorted([s * (LIP_FIRST_LATERAL + k) for k in range(0, 80) for s in (-1, 1)],
                              key=lambda v: (abs(v), -v))
            laterals = [v for v in laterals if chasm["lateral_min"] - LIP_OVERRUN <= v <= chasm["lateral_max"] + LIP_OVERRUN]
            rims.append({"chasm": chasm, "point": point, "direction": direction, "yaw": yaw, "laterals": laterals,
                         "taken": 0})

    def try_next(rim):
        while rim["laterals"]:
            lateral = rim["laterals"].pop(0)
            point, direction = rim["point"], rim["direction"]
            inst = make_instance("DA_FissureLip", point[0] - direction[1] * lateral, point[1] + direction[0] * lateral,
                                 rim["yaw"], 1.0, id=ids.next("DA_FissureLip"))
            if placer.valid(inst) and all(g.shape_gap(footprint(inst), chasm_poly(c)) >= 0.05 for c in chasms):
                placer.add(inst)
                lips.append(inst)
                rim["chasm"]["lip_ids"].append(inst["id"])
                rim["taken"] += 1
                return True
            ids.release("DA_FissureLip")
        return False

    for rim in rims:
        while rim["taken"] < 4 and try_next(rim):
            pass
    progress = True
    while len(lips) < total and progress:
        progress = False
        for rim in rims:
            if len(lips) < total and try_next(rim):
                progress = True
    assert len(lips) == total, "not enough room for the planned lips"
    return lips


def place_calm(placer, ids, chasms):
    stones = []
    for index, chasm in enumerate(chasms):
        for sign in (-1, 1):
            for lateral_sign in ((1, -1) if (index + (sign > 0)) % 2 == 0 else (-1, 1)):
                point, _ = at_lateral(chasm["route_arc"] + sign * CALM_OFFSET, lateral_sign * CALM_LATERAL)
                inst = make_instance("DA_CalmStone", point[0], point[1], 0.0, 1.0, id=ids.next("DA_CalmStone"))
                if placer.valid(inst):
                    placer.add(inst)
                    stones.append(inst)
                    break
                ids.release("DA_CalmStone")
            else:
                raise AssertionError("no room for a calm stone at " + chasm["id"])
    return stones


def place_decoys(placer, ids, rng, chasms):
    decoys = []
    for chasm in chasms:
        arc, half = chasm["route_arc"], chasm["along_length"] / 2
        poly, got, attempts = chasm_poly(chasm), 0, 0
        while got < DECOYS_PER_CHASM:
            attempts += 1
            assert attempts < 20000, "could not place every decoy rock"
            lateral = rng.uniform(chasm["lateral_min"], chasm["lateral_max"])
            if abs(lateral) < CORRIDOR_HALF + 9.0:
                continue
            point, _ = at_lateral(arc + rng.uniform(-half, half), lateral)
            inst = make_instance("DA_FloatRock", point[0], point[1], rng.uniform(0.0, 360.0), 1.0, id=ids.next("DA_FloatRock"))
            if all(g.point_in_polygon(poly.pts, p) for p in footprint(inst).pts) and placer.valid(inst):
                placer.add(inst)
                decoys.append(inst)
                got += 1
            else:
                ids.release("DA_FloatRock")
    return decoys


def place_spires(placer, ids, rng, chasms):
    spec, polys = PROPS["DA_ThornSpire"], [chasm_poly(c) for c in chasms]
    spires, inside, attempts = [], 0, 0
    while len(spires) < SPIRES_IN_CHASMS + SPIRES_ON_BANKS:
        attempts += 1
        assert attempts < 80000, "could not place every spire"
        x, z = random_point(rng)
        want_inside = inside < SPIRES_IN_CHASMS
        if in_any(polys, (x, z)) != want_inside:
            continue
        inst = make_instance("DA_ThornSpire", x, z, rng.uniform(0.0, 360.0), rng.uniform(*spec["scale"]), id=ids.next("DA_ThornSpire"))
        if placer.valid(inst):
            placer.add(inst)
            spires.append(inst)
            inside += want_inside
        else:
            ids.release("DA_ThornSpire")
    return spires


def place_shards(placer, ids, rng, chasms):
    polys = [chasm_poly(c) for c in chasms]
    spec, shards, attempts = PROPS["DA_RiftShard"], [], 0
    total = dict(MIX)["DA_RiftShard"]
    while len(shards) < total:
        attempts += 1
        assert attempts < 80000, "could not place every shard"
        arc = rng.uniform(0.0, ROUTE_LENGTH)
        point, _ = at_lateral(arc, rng.choice((-1, 1)) * rng.uniform(13.0, 30.0))
        inst = make_instance("DA_RiftShard", point[0], point[1], facing_route(*point), rng.uniform(*spec["scale"]),
                             id=ids.next("DA_RiftShard"), night_only=len(shards) >= total - NIGHT_ONLY_SHARDS)
        gather = gather_point(inst)
        if in_any(polys, point) or in_any(polys, gather) or not 8.0 <= route_distance(gather) < route_distance(point) \
                or not placer.valid(inst):
            ids.release("DA_RiftShard")
            continue
        placer.add(inst)
        shards.append(inst)
    return shards


DECISIONS = [
    "The trail crosses three chasms on chains of six floating rocks, 13 studs apart; each rock hull is 12 long "
    "so the gap between rocks is 1 stud and the hop between walk boxes is 6.04 studs (unverified: no jump test).",
    "A 6 s occupancy limit is far above a walking dwell of 0.81 s per rock; at night a walker sinks 1.2 studs per "
    "rock, so the sinking only punishes players who stop.",
    "Chasms are 84 studs along the trail and as wide across as the sector allows (clipped to the boundary); "
    "the bible gives no chasm size.",
    "Fissure lips: 24 packed outward from the corridor along both rims, four per rim first and spares to any "
    "rim with room (8, 7 and 9 per chasm in the default seed); the bank edge may run 25 studs past a chasm end "
    "where the other leg of the trail or the sector boundary leaves room.",
    "Calm stones: one on each bank of each chasm (six), the only rest; the bible gives them no zone radius.",
    "Twelve of the 30 rocks are decoys inside the chasms, off the trail. Thorn spires: 10 rise out of the drop, "
    "20 stand on the banks.",
    "Six of 14 rift shards are flagged night_only (the bible says night-only Rift Shards appear, no count).",
    "Rift gates straddle the trail at both gates with the measured gap (-8.41 to 7.36) containing the corridor "
    "with the pivot on the centreline; the gap is 0.52 off centre.",
]


def generate(seed=DEFAULT_SEED):
    rng = random.Random(seed)
    placer, ids = Placer(), IdSource()
    gates = place_gates(placer, ids)
    chasms, route_rocks = place_chains(placer, ids)
    lips = place_lips(placer, ids, chasms)
    calm = place_calm(placer, ids, chasms)
    decoys = place_decoys(placer, ids, rng, chasms)
    spires = place_spires(placer, ids, rng, chasms)
    shards = place_shards(placer, ids, rng, chasms)
    instances = lips + route_rocks + decoys + spires + gates + shards + calm
    by_name = {}
    for name, count in MIX:
        assert len([i for i in instances if i["name"] == name]) == count, name
        by_name[name] = {"count": count, "triangles": count * PROPS[name]["tris"]}
    dwell = ROCK_STEP / WALK_SPEED
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
        "hazards": {"chasms": chasms,
                    "rock_sink": {"rate_day": SINK_DAY, "rate_night": SINK_NIGHT, "max_occupied_s": SINK_MAX_S,
                                  "dwell_s_walking": r3(dwell), "night_depth_per_rock": r3(dwell * SINK_NIGHT)}},
        "density": {"props_per_1000_sq_studs": round(len(instances) / (MAP_SIZE * MAP_SIZE / 1000.0), 3),
                    "chasm_area_fraction": round(sum(c["along_length"] * (c["lateral_max"] - c["lateral_min"])
                                                       for c in chasms) / (MAP_SIZE * MAP_SIZE), 4)},
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
    scene.text(MAP_X0, 34, "Demon Abyss placement plan v1 - DRAFT, unvalidated - top-down", size=22, bold=True)
    scene.text(MAP_X0, 54, "seed %d | 300 x 300 studs | north (-z) is up | symbols enlarged" % layout["seed"], size=13,
               fill="#444444")
    scene.rect(world.px(-150), world.py(-150), 300 * s, 300 * s, fill="#d9d2d6", stroke="#222222", sw=2)
    for v in range(-150, 151, 50):
        scene.line([(world.px(v), world.py(-150)), (world.px(v), world.py(150))], stroke="#000000", sw=0.8, so=0.10)
        scene.line([(world.px(-150), world.py(v)), (world.px(150), world.py(v))], stroke="#000000", sw=0.8, so=0.10)
        scene.text(world.px(v), world.py(150) + 18, str(v), size=11, fill="#555555", anchor="middle")
        scene.text(world.px(-150) - 6, world.py(v) + 4, str(v), size=11, fill="#555555", anchor="end")
    for chasm in layout["hazards"]["chasms"]:
        scene.poly([world.pt(p) for p in chasm["polygon"]], fill="#15111b", fo=0.85, stroke="#7a1f2c", sw=1.5)
    by = {name: [i for i in layout["instances"] if i["name"] == name] for name, _ in MIX}
    scene.line([world.pt(p) for p in ROUTE], stroke="#cbb9a0", sw=2 * CORRIDOR_HALF * s, so=0.55)
    scene.line([world.pt(p) for p in ROUTE], stroke="#f0e6d6", sw=1.2, dash=(8, 6))
    for inst in by["DA_FissureLip"]:
        scene.poly([world.pt(p) for p in footprint(inst).pts], fill="#4a4650", fo=0.9, stroke="#c23a4f", sw=1.0)
    for inst in by["DA_FloatRock"]:
        scene.poly([world.pt(p) for p in footprint(inst).pts], fill="#7a1f2c", fo=0.9, stroke="#ffffff", sw=0.8)
    for inst in by["DA_ThornSpire"]:
        x, y = world.px(inst["x"]), world.py(inst["z"])
        scene.poly([(x, y - 8), (x + 5, y + 5), (x - 5, y + 5)], fill="#15111b", stroke="#bfb6a6", sw=0.8)
    for inst in by["DA_CalmStone"]:
        scene.circle(world.px(inst["x"]), world.py(inst["z"]), 3.3 * s, fill="#6fb7c9", stroke="#222222", sw=1)
    for inst in by["DA_RiftShard"]:
        x, y = world.px(inst["x"]), world.py(inst["z"])
        color = "#ffffff" if inst.get("night_only") else "#c23a4f"
        scene.poly([(x, y - 6), (x + 5, y), (x, y + 6), (x - 5, y)], fill=color, stroke="#c23a4f", sw=1.2)
        gx, gz = gather_point(inst)
        scene.circle(world.px(gx), world.py(gz), 2.2, fill="#ffffff", stroke="#c23a4f", sw=0.8)
    for inst in by["DA_RiftGate"]:
        scene.poly([world.pt(p) for p in footprint(inst).pts], fill="#4a4650", fo=0.8, stroke="#c23a4f", sw=2)
    for name, (x, z) in ROUTE_NODES:
        scene.circle(world.px(x), world.py(z), 5, fill="#ffffff", stroke="#3a2f12", sw=2)
        scene.text(world.px(x) + 10, world.py(z) - 10, name, size=12, bold=True, fill="#3a2f12")
    x0, y = 780.0, 100.0
    t = layout["totals"]
    scene.text(x0, y, "Legend", size=17, bold=True)
    rows = [("Trail 14 wide", "#cbb9a0"), ("Chasm (dark drop)", "#15111b"), ("Floating rock chain / decoy", "#7a1f2c"),
            ("Fissure lip, breaking edge to the drop", "#4a4650"), ("Thorn spire", "#15111b"),
            ("Calm stone (rest)", "#6fb7c9"), ("Rift shard (white = night only)", "#c23a4f"),
            ("Rift gate over trail", "#4a4650")]
    for label, colour in rows:
        y += 24
        scene.rect(x0, y - 12, 22, 14, fill=colour, stroke="#333333", sw=0.8)
        scene.text(x0 + 32, y, label, size=13)
    y += 40
    scene.text(x0, y, "Budget (draft)", size=17, bold=True)
    sink = layout["hazards"]["rock_sink"]
    for line in ["Instances %d / %d cap" % (t["instances"], MAX_INSTANCES),
                 "Triangles measured %s / %s cap" % (format(t["triangles_measured"], ","), format(MAX_TRIANGLES, ",")),
                 "Triangles at bible budgets %s" % format(t["triangles_budget"], ","),
                 "MeshParts %d" % t["mesh_parts"],
                 "Route %.0f studs, %.0f s at 16 studs/s" % (layout["route"]["length"], layout["route"]["walk_seconds"]),
                 "Rocks sink %.1f studs/s (night %.1f), dwell %.2f s" % (sink["rate_day"], sink["rate_night"], sink["dwell_s_walking"])]:
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
    lines.append("route %.0f studs (%.1f s), %d chasms" % (layout["route"]["length"], layout["route"]["walk_seconds"],
                                                           len(layout["hazards"]["chasms"])))
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

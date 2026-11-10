#!/usr/bin/env python3
"""Reproducible top-down plan for the Wildbound open world: hub, forest, Pradera (DESIGN, unvalidated).

This is a plan only: it writes JSON, SVG and (when Pillow is importable) PNG files and never
touches the Luau map builder, Studio or Blender. Python standard library only; Pillow is
optional. Nothing here was imported into Roblox, played or measured on a device.

    python tools/plan_open_world_layout.py [--seed N] [--out-dir DIR]

World frame (studs): the origin is the hub centre, x grows east, z grows south. The existing
400 x 400 fog forest (assets/maps/forest-layout/forest-layout-v1.json, with its islands, relief
and hide spots) is translated as one block by FOREST_OFFSET; the forest's local frame stays the
one its own planners use, so forest_world = forest_local + FOREST_OFFSET. The Pradera Arcoiris
(east) is read from its own kit plan (assets/maps/pradera-layout/pradera-layout-v1.json, written
by tools/plan_pradera_layout.py) and translated by PRADERA_OFFSET: La Nube Grunona's home, strike
zone and leash, La Abeja Reina's event ground at La Colmena, the gate, the cream path, the nests,
the sun circles and the prop footprints are never drafted twice (user decision 2026-11-10).

Spec: docs/design/wildbound-open-world-hub.md.
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
import plan_forest_layout as forest  # noqa: E402
import plan_pradera_layout as pradera  # noqa: E402

DEFAULT_SEED = 20261109
LAYOUT_NAME = "layout-v1"
REPO = TOOLS.parent
DEFAULT_OUT_DIR = REPO / "assets" / "maps" / "open-world"
FOREST_DIR = REPO / "assets" / "maps" / "forest-layout"
FOREST_LAYOUT = FOREST_DIR / "forest-layout-v1.json"
FOREST_ISLANDS = FOREST_DIR / "islands-v1.json"
FOREST_RELIEF = FOREST_DIR / "relief-v1.json"
FOREST_HIDE_SPOTS = FOREST_DIR / "hide-spots-v1.json"
PRADERA_LAYOUT = REPO / "assets" / "maps" / "pradera-layout" / "pradera-layout-v1.json"

# ---- World ------------------------------------------------------------------------------
# x, z extents: "about 1000 x 450" plus the ring road margin. The east side is 80 studs wider than the west
# because the ring road's east leg swings round La Nube's 110-stud strike zone, which reaches x 560.
WORLD_BOUNDS = {"x": (-520.0, 600.0), "z": (-225.0, 225.0)}
WORLD_SIZE = (WORLD_BOUNDS["x"][1] - WORLD_BOUNDS["x"][0], WORLD_BOUNDS["z"][1] - WORLD_BOUNDS["z"][0])
WORLD_HALF = (WORLD_SIZE[0] / 2, WORLD_SIZE[1] / 2)
REGION_SIZE = 400.0
REGION_HALF = REGION_SIZE / 2
FOREST_OFFSET = (-300.0, 0.0)          # forest local (0, 0) lands here
PRADERA_OFFSET = (300.0, 0.0)
WALK_SPEED = 16.0                      # documented player walk speed, not rechecked
ROAD_WIDTH = 14.0                      # every road, connector and spoke, like the forest route
ROAD_HALF = ROAD_WIDTH / 2
ROAD_CLEAR = 10.0                      # a prop footprint this close to a new road centreline is removed

# ---- Hub ---------------------------------------------------------------------------------
HUB_RADIUS = 60.0                      # the permanent safe circle for Rules.zone
HUB_WALL_RADIUS = 58.0                 # hedge / low wall ring, 2 studs thick, four gates
HUB_GATE_WIDTH = 16.0
HUB_PLAZA_RING = (25.0, 35.0)          # inner and outer radius of the paved plaza ring
HUB_STATION_BAND = (36.0, 56.0)        # stations live between the plaza ring and the wall
HUB_SPOKE_CLEAR = 10.0                 # station footprints keep this from the four gate spokes
HUB_STATION_GAP = 8.0                  # footprint to footprint
SPAWN_PAD = (0.0, 0.0, 9.0)            # the place's default SpawnLocation (Rules.SPAWN_PAD_*), kept
HUB_GATES = {"W": (-HUB_RADIUS, 0.0), "E": (HUB_RADIUS, 0.0), "N": (0.0, -HUB_RADIUS), "S": (0.0, HUB_RADIUS)}
HUB_SPOKE_INNER = HUB_PLAZA_RING[1]    # spokes run from the plaza ring to the gates


def _polar(radius, angle_deg):
    a = math.radians(angle_deg)
    return (radius * math.cos(a), radius * math.sin(a))


# Stations: id, player-facing name (neutral Spanish), footprint and what it holds. Angles are
# measured from +x toward +z (south), so negative z is north on the plan.
HUB_STATIONS = (
    {"id": "incubadora", "name": "Incubadora", "centre": _polar(46.0, -135.0), "footprint": {"kind": "circle", "r": 6.0},
     "holds": "3 visible egg slots (WildboundIncubator), prompt 'Incubar huevo'", "slots": 3},
    {"id": "corral", "name": "Corral", "centre": _polar(46.5, -38.0), "footprint": {"kind": "rect", "half": (11.0, 6.5), "yaw": 128.0},
     "holds": "8 pens where registered creatures idle and hover; prompt 'Ver corral'", "slots": 8},
    {"id": "refugio", "name": "Refugio", "centre": _polar(48.0, -70.0), "footprint": {"kind": "circle", "r": 5.0},
     "holds": "registration hut: 'Registrar criatura', card, equip (the forest camp's refuge, duplicated)"},
    {"id": "cofre", "name": "Cofre", "centre": _polar(46.0, -110.0), "footprint": {"kind": "circle", "r": 3.0},
     "holds": "storage chest: 'Guardar en el cofre' (extraction and banking)"},
    {"id": "puesto", "name": "Puesto", "centre": _polar(46.0, -160.0), "footprint": {"kind": "circle", "r": 4.0},
     "holds": "reserved stall marker for the convenience-offer design; no purchase flow is built"},
    {"id": "tablero", "name": "Tablero de Esencia", "centre": _polar(46.0, 120.0), "footprint": {"kind": "rect", "half": (4.0, 1.5), "yaw": 30.0},
     "holds": "Esencia board: balance, what each corral creature earned, wave board top 3"},
    {"id": "habilidades", "name": "Árbol de habilidades", "centre": _polar(46.0, 150.0), "footprint": {"kind": "circle", "r": 4.5},
     "holds": "skill tree kiosk (Learn action) and upgrades (Upgrade action)"},
)
TROPHY_ANGLES = (15.0, 30.0, 45.0, 60.0, 75.0)   # five plinths on the south-east arc, 13 studs apart
TROPHY_RADIUS = 50.0
TROPHY_FOOT_R = 2.0
SPAWN_PADS = tuple(_polar(16.0, a) for a in (0.0, 90.0, 180.0, 270.0))  # all face east (+x)

# ---- Forest (west), translated as a block --------------------------------------------------
FOREST_LOCAL = {
    "home": (0.0, -85.0), "leash": 80.0, "chase_leash": 100.0,
    "fog": (-45.0, 165.0, -165.0, 35.0),                       # xmin, xmax, zmin, zmax
    "safe_circles": {"camp": ((-140.0, 140.0), 35.0), "shelter": ((105.0, 125.0), 22.0)},
    "route": [p for _, p in forest.ROUTE_NODES],
    "route_names": [n for n, _ in forest.ROUTE_NODES],
}

# ---- Pradera (east): everything comes from the Pradera kit plan, see PraderaRegion ---------
PRADERA_SAFE_IDS = {"sun-gate": "porton", "sun-plaza": "plaza_molino"}   # the two permanent sun circles

# ---- Transitions, ring road, connectors ----------------------------------------------------
TRANSITION_HALF_Z = 45.0
RING_Z = 212.0
RING_X_WEST = 510.0                    # 10 studs outside the forest square
RING_X_EAST = 590.0                    # 140 studs from La Nube's home: beyond her 110 strike zone and her 90 leash
RING_CHAMFER = 12.0
RING_ROAD = [(-RING_X_WEST + RING_CHAMFER, -RING_Z), (RING_X_EAST - RING_CHAMFER, -RING_Z),
             (RING_X_EAST, -RING_Z + RING_CHAMFER), (RING_X_EAST, RING_Z - RING_CHAMFER),
             (RING_X_EAST - RING_CHAMFER, RING_Z), (-RING_X_WEST + RING_CHAMFER, RING_Z),
             (-RING_X_WEST, RING_Z - RING_CHAMFER), (-RING_X_WEST, -RING_Z + RING_CHAMFER)]

# ---- Refugios, hooks, seeds -------------------------------------------------------------------
REFUGIO_RADIUS = 8.0
REFUGIO_SETS, REFUGIO_PER_SET = 3, 3
REFUGIO_MIN_SPACING = 60.0             # inside one set
REFUGIO_BEAST_MARGIN = 10.0            # beyond every beast's reach (the larger of strike radius and leash) by this
REFUGIO_SAFE_MARGIN = 20.0             # from permanent safe circles and the hub
REFUGIO_ROAD_CLEAR = REFUGIO_RADIUS + ROAD_HALF
REFUGIO_PROP_CLEAR = REFUGIO_RADIUS + 1.0
REFUGIO_EDGE_MARGIN = 20.0
HOOK_GATE_BAND = (60.0, 110.0)         # studs from the region gate, like island 1's 88 from the forest spawn
HOOK_IDEAL = 85.0
HOOK_FLOOR = 14.0                      # cleared floor radius, as the islands
HOOK_PROP_CLEAR = HOOK_FLOOR + 2.0
HOOK_ROAD_CLEAR = 20.0
TIER_BANDS = (("Legendaria", 0.0, 45.0), ("Épica", 45.0, 80.0), ("Rara", 80.0, 120.0), ("Común", 120.0, math.inf))
TRAIL_SEED_STEP, TRAIL_SEED_LATERAL = 40.0, 10.0
PRADERA_SEED_STEP, PRADERA_SEED_JITTER = 30.0, 8.0
SEED_SAFE_MARGIN = 3.0


def r3(value):
    return round(float(value), 3) + 0.0


def translate(point, offset):
    return (r3(point[0] + offset[0]), r3(point[1] + offset[1]))


def rect_translate(rect, offset):
    return (r3(rect[0] + offset[0]), r3(rect[1] + offset[0]), r3(rect[2] + offset[1]), r3(rect[3] + offset[1]))


def in_rect(rect, x, z):
    return rect[0] <= x <= rect[1] and rect[2] <= z <= rect[3]


def tier_for(distance):
    for name, lo, hi in TIER_BANDS:
        if lo <= distance < hi:
            return name
    raise AssertionError("unreachable")


# ---- Inputs ----------------------------------------------------------------------------------
def load_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def load_forest_inputs(layout_path=FOREST_LAYOUT, islands_path=FOREST_ISLANDS, relief_path=FOREST_RELIEF,
                       hide_path=FOREST_HIDE_SPOTS, pradera_path=PRADERA_LAYOUT):
    return {"layout": load_json(layout_path), "islands": load_json(islands_path),
            "relief": load_json(relief_path), "hide_spots": load_json(hide_path),
            "pradera": load_json(pradera_path)}


# ---- Regions ----------------------------------------------------------------------------------
class Region:
    """A 400 x 400 biome square translated by an offset, with its beast rules in world studs."""

    def __init__(self, key, offset, local, beast_name, beast_rect_key):
        self.key, self.offset, self.local = key, offset, local
        self.beast_name = beast_name
        self.centre = offset
        self.bounds = (offset[0] - REGION_HALF, offset[0] + REGION_HALF, offset[1] - REGION_HALF, offset[1] + REGION_HALF)
        self.home = translate(local["home"], offset)
        self.leash, self.chase_leash = local["leash"], local["chase_leash"]
        self.beast_rect = rect_translate(local[beast_rect_key], offset)
        self.safe_circles = {name: (translate(c, offset), r) for name, (c, r) in local["safe_circles"].items()}
        self.route = [translate(p, offset) for p in local["route"]]
        self.route_names = list(local["route_names"])
        self.route_closed = True

    def beasts(self):
        """Every beast of the region: strikes need `strike_radius`, `reach` is the farthest it hunts from home."""
        return [{"key": "silueta", "name": self.beast_name, "home": self.home, "strike_radius": self.leash,
                 "reach": max(self.leash, self.chase_leash), "active": "always"}]

    def in_bounds(self, x, z, margin=0.0):
        return (self.bounds[0] + margin <= x <= self.bounds[1] - margin
                and self.bounds[2] + margin <= z <= self.bounds[3] - margin)

    def in_beast_rect(self, x, z):
        return in_rect(self.beast_rect, x, z)

    def in_safe(self, x, z, margin=0.0):
        return any(math.dist((x, z), c) <= r + margin for c, r in self.safe_circles.values())

    def distance_home(self, x, z):
        return math.dist((x, z), self.home)

    def in_territory(self, x, z):
        return self.in_beast_rect(x, z) and not self.in_safe(x, z) and self.distance_home(x, z) <= self.leash

    def zone(self, x, z):
        if self.in_territory(x, z):
            return "territory"
        return "fog" if self.in_beast_rect(x, z) else "outside"

    def reach(self):
        """Signed x reach of the beast toward the hub: strikes need the territory, hunts the chase leash."""
        sign = 1.0 if self.offset[0] < 0 else -1.0
        return {"territory_x": r3(self.home[0] + sign * self.leash), "chase_x": r3(self.home[0] + sign * self.chase_leash),
                "rect_x": r3(self.beast_rect[1] if sign > 0 else self.beast_rect[0])}

    def report(self):
        return {
            "key": self.key, "offset": list(self.offset), "bounds": {"x": [self.bounds[0], self.bounds[1]], "z": [self.bounds[2], self.bounds[3]]},
            "beast": {"name": self.beast_name, "home": list(self.home), "leash": self.leash, "chase_leash": self.chase_leash,
                      "strike_radius": self.leash,
                      "rect": {"x": [self.beast_rect[0], self.beast_rect[1]], "z": [self.beast_rect[2], self.beast_rect[3]]},
                      "reach_toward_hub": self.reach()},
            "safe_circles": {name: {"centre": list(c), "r": r} for name, (c, r) in self.safe_circles.items()},
            "route": {"names": self.route_names, "nodes": [list(p) for p in self.route], "closed": True,
                      "loop_length": r3(g.polyline_length(self.route + self.route[:1])),
                      "walk_seconds": r3(g.polyline_length(self.route + self.route[:1]) / WALK_SPEED)},
        }


class PraderaRegion:
    """The Pradera Arcoiris read from its kit plan and translated by PRADERA_OFFSET.

    La Nube Grunona is the permanent beast: a strike zone (circle) around her pond and a leash. La Abeja Reina
    is the biome event's beast: awake only while the event egg is up, guarding La Colmena. Zones: "territory"
    (inside la Nube's strike zone and not safe), "colmena" (inside the Abeja's guard radius, event only),
    "outside" (everything else).
    """

    def __init__(self, layout, offset=PRADERA_OFFSET):
        self.key, self.offset, self.centre = "pradera", offset, offset
        self.source = layout
        self.bounds = (offset[0] - REGION_HALF, offset[0] + REGION_HALF, offset[1] - REGION_HALF, offset[1] + REGION_HALF)
        beast = layout["beast"]
        self.beast_name = layout["biome"]["beast"]
        self.home = translate(tuple(beast["home"]), offset)
        self.strike_radius, self.leash = beast["strike_zone_radius"], beast["leash"]
        self.seta_trueno = translate(tuple(beast["seta_trueno"]), offset)
        ev = layout["abeja_event"]
        self.event = ev
        self.hive = translate(tuple(ev["hive"]), offset)
        self.guard_radius, self.event_leash, self.wake_radius = ev["guard_radius"], ev["leash"], ev["wake_radius"]
        self.safe_circles = {PRADERA_SAFE_IDS[c["id"]]: (translate((c["x"], c["z"]), offset), c["radius"])
                             for c in layout["sun_circles"] if c["permanent"]}
        self.sun_candidates = [{"id": c["id"], "centre": translate((c["x"], c["z"]), offset), "r": c["radius"]}
                               for c in layout["sun_circles"] if not c["permanent"]]
        self.gate = translate(tuple(layout["zones"]["sol"]["gate"][:2]), offset)
        self.route = [translate(tuple(p), offset) for p in layout["route"]["nodes"]]
        self.route_names = list(layout["route"]["names"])
        self.route_closed = False
        self.nests = [dict(n, x=r3(n["x"] + offset[0]), z=r3(n["z"] + offset[1])) for n in layout["nests"]]
        self.solids = []
        for inst in layout["instances"]:
            if inst["name"] == "PA_PuffFlower":
                continue
            world = dict(inst, x=inst["x"] + offset[0], z=inst["z"] + offset[1])
            self.solids.append((inst["id"], pradera.footprint(world)))

    def beasts(self):
        return [{"key": "nube", "name": self.beast_name, "home": self.home, "strike_radius": self.strike_radius,
                 "reach": max(self.strike_radius, self.leash), "active": "always"},
                {"key": "abeja", "name": self.event["displayName"], "home": self.hive, "strike_radius": self.guard_radius,
                 "reach": max(self.guard_radius, self.event_leash), "active": "event"}]

    def in_bounds(self, x, z, margin=0.0):
        return (self.bounds[0] + margin <= x <= self.bounds[1] - margin
                and self.bounds[2] + margin <= z <= self.bounds[3] - margin)

    def in_safe(self, x, z, margin=0.0):
        return any(math.dist((x, z), c) <= r + margin for c, r in self.safe_circles.values())

    def distance_home(self, x, z):
        return math.dist((x, z), self.home)

    def in_territory(self, x, z):
        return self.distance_home(x, z) <= self.strike_radius and not self.in_safe(x, z)

    def zone(self, x, z):
        if self.in_territory(x, z):
            return "territory"
        return "colmena" if math.dist((x, z), self.hive) <= self.guard_radius else "outside"

    def reach(self):
        return {"strike_x": r3(self.home[0] - self.strike_radius), "leash_x": r3(self.home[0] - self.leash)}

    def report(self):
        length = g.polyline_length(self.route)
        return {
            "key": self.key, "offset": list(self.offset), "bounds": {"x": [self.bounds[0], self.bounds[1]], "z": [self.bounds[2], self.bounds[3]]},
            "source": "assets/maps/pradera-layout/pradera-layout-v1.json", "biome": self.source["biome"]["displayName"],
            "beast": {"name": self.beast_name, "home": list(self.home), "strike_radius": self.strike_radius, "leash": self.leash,
                      "seta_trueno": list(self.seta_trueno), "reach_toward_hub": self.reach()},
            "event_beast": {"name": self.event["displayName"], "hive": list(self.hive), "guard_radius": self.guard_radius,
                            "leash": self.event_leash, "wake_radius": self.wake_radius, "egg_nest": self.event["egg_nest"],
                            "clock": dict(self.event["clock"]), "active": "event"},
            "gate": list(self.gate),
            "safe_circles": {name: {"centre": list(c), "r": r} for name, (c, r) in self.safe_circles.items()},
            "sun_circle_candidates": [{"id": c["id"], "centre": list(c["centre"]), "r": c["r"]} for c in self.sun_candidates],
            "nests": [{"id": n["id"], "species": n["species"], "rarity": n["rarity"], "x": n["x"], "z": n["z"],
                       "eventOnly": n["eventOnly"]} for n in self.nests],
            "route": {"names": self.route_names, "nodes": [list(p) for p in self.route], "closed": False,
                      "length": r3(length), "walk_seconds": r3(length / WALK_SPEED)},
        }


def make_regions(pradera_layout=None):
    west = Region("forest", FOREST_OFFSET, FOREST_LOCAL, "La Silueta", "fog")
    east = PraderaRegion(pradera_layout or load_json(PRADERA_LAYOUT))
    return west, east


# ---- Hub ---------------------------------------------------------------------------------------
def station_shape(station):
    foot, (cx, cz) = station["footprint"], station["centre"]
    if foot["kind"] == "circle":
        return g.Circle(cx, cz, foot["r"])
    return g.rect_poly(cx, cz, foot["half"][0], foot["half"][1], foot["yaw"])


def hub_spokes():
    return {name: ((HUB_SPOKE_INNER * gate[0] / HUB_RADIUS, HUB_SPOKE_INNER * gate[1] / HUB_RADIUS), gate)
            for name, gate in HUB_GATES.items()}


def trophy_plinths():
    return [{"id": "trofeo-%d" % (k + 1), "centre": [r3(v) for v in _polar(TROPHY_RADIUS, a)], "r": TROPHY_FOOT_R}
            for k, a in enumerate(TROPHY_ANGLES)]


def shape_radial_range(shape):
    if isinstance(shape, g.Circle):
        d = math.hypot(shape.x, shape.z)
        return d - shape.r, d + shape.r
    radii = [math.hypot(*p) for p in shape.pts]
    # A convex footprint's nearest point to the origin may lie on an edge, not a vertex.
    inner = min(g.point_seg_dist((0.0, 0.0), a, b) for a, b in zip(shape.pts, shape.pts[1:] + shape.pts[:1]))
    return inner, max(radii)


def validate_hub():
    shapes = [(s["id"], station_shape(s)) for s in HUB_STATIONS]
    shapes += [(p["id"], g.Circle(p["centre"][0], p["centre"][1], p["r"])) for p in trophy_plinths()]
    spokes = hub_spokes()
    for ident, shape in shapes:
        inner, outer = shape_radial_range(shape)
        if inner < HUB_STATION_BAND[0] or outer > HUB_STATION_BAND[1]:
            raise RuntimeError("hub station %s leaves the station band: %.1f..%.1f" % (ident, inner, outer))
        for name, (a, b) in spokes.items():
            if g.shape_segment_dist(shape, a, b) < HUB_SPOKE_CLEAR:
                raise RuntimeError("hub station %s crowds spoke %s" % (ident, name))
    for i in range(len(shapes)):
        for j in range(i + 1, len(shapes)):
            if g.shape_gap(shapes[i][1], shapes[j][1]) < HUB_STATION_GAP:
                raise RuntimeError("hub stations %s and %s are too close" % (shapes[i][0], shapes[j][0]))
    for pad in SPAWN_PADS:
        if math.hypot(*pad) - 2.0 < SPAWN_PAD[2] or math.hypot(*pad) + 2.0 > HUB_PLAZA_RING[0]:
            raise RuntimeError("spawn pad %s leaves the plaza" % (pad,))


def hub_report():
    validate_hub()
    stations = []
    for s in HUB_STATIONS:
        entry = {"id": s["id"], "name": s["name"], "centre": [r3(v) for v in s["centre"]], "footprint": dict(s["footprint"]),
                 "holds": s["holds"]}
        if "half" in entry["footprint"]:
            entry["footprint"]["half"] = list(entry["footprint"]["half"])
        if "slots" in s:
            entry["slots"] = s["slots"]
        stations.append(entry)
    spokes = {name: {"from": [r3(a[0]), r3(a[1])], "to": [r3(b[0]), r3(b[1])]} for name, (a, b) in hub_spokes().items()}
    return {
        "centre": [0.0, 0.0], "safe_radius": HUB_RADIUS, "wall_radius": HUB_WALL_RADIUS, "gate_width": HUB_GATE_WIDTH,
        "gates": {name: list(p) for name, p in HUB_GATES.items()},
        "plaza_ring": {"inner": HUB_PLAZA_RING[0], "outer": HUB_PLAZA_RING[1]},
        "spokes": spokes, "road_width": ROAD_WIDTH,
        "spawn": {"default_spawn_location": {"centre": [SPAWN_PAD[0], SPAWN_PAD[1]], "radius": SPAWN_PAD[2]},
                  "pads": [{"centre": [r3(p[0]), r3(p[1])], "faces": "east"} for p in SPAWN_PADS]},
        "stations": stations,
        "trophies": trophy_plinths(),
        "rules": {"station_band": list(HUB_STATION_BAND), "spoke_clear": HUB_SPOKE_CLEAR, "station_gap": HUB_STATION_GAP},
    }


# ---- Roads --------------------------------------------------------------------------------------
def connectors(west, east):
    shelter = west.safe_circles["shelter"][0]
    camp = west.safe_circles["camp"][0]
    pradera_gate = east.route[0]   # where the Pradera's cream path starts, just west of the rainbow gate
    return {
        "umbral_oeste": {"from": "hub gate W", "to": "forest shelter", "nodes": [HUB_GATES["W"], (-100.0, 20.0), shelter],
                         "region": "forest", "removes_props": True},
        "umbral_este": {"from": "hub gate E", "to": "pradera gate", "nodes": [HUB_GATES["E"], pradera_gate],
                        "region": "pradera", "removes_props": False},
        "espolon_norte": {"from": "hub gate N", "to": "ring road", "nodes": [HUB_GATES["N"], (0.0, -RING_Z)],
                          "region": "hub", "removes_props": False},
        "espolon_sur": {"from": "hub gate S", "to": "ring road", "nodes": [HUB_GATES["S"], (0.0, RING_Z)],
                        "region": "hub", "removes_props": False},
        "espolon_campamento": {"from": "forest camp", "to": "ring road", "nodes": [camp, (camp[0], RING_Z)],
                               "region": "forest", "removes_props": True},
    }


def all_road_polylines(west, east, conns):
    """(name, nodes, closed) for every corridor whose 14 studs must stay clear."""
    roads = [("ring", RING_ROAD, True), ("forest_route", west.route, west.route_closed),
             ("pradera_route", east.route, east.route_closed)]
    for name, c in conns.items():
        roads.append((name, c["nodes"], False))
    return roads


def road_distance(roads, p):
    return min(g.point_seg_dist(p, a, b) for _, nodes, closed in roads
               for a, b in zip(nodes, nodes[1:] + (nodes[:1] if closed else [])))


# ---- Forest translation -------------------------------------------------------------------------
def translated_forest_instances(layout):
    out = []
    for inst in layout["instances"]:
        world = dict(inst)
        world["x"], world["z"] = translate((inst["x"], inst["z"]), FOREST_OFFSET)
        out.append(world)
    return out


def as_geometry(shape):
    """The forest planner has its own Circle/Poly tuples; layout_geometry dispatches on its own classes."""
    if isinstance(shape, forest.Circle):
        return g.Circle(shape.x, shape.z, shape.r)
    return g.Poly(tuple(shape.pts))


def forest_shapes(instances):
    """Ground footprints (roots, log and landmark envelopes, lantern bases) in world studs."""
    return [(inst["id"], as_geometry(shape)) for inst in instances for shape in forest.footprint(inst)]


def props_removed_by(roads, shapes):
    removed = {}
    for name, nodes, closed in roads:
        for ident, shape in shapes:
            if g.shape_polyline_dist(shape, nodes, closed=closed) < ROAD_CLEAR:
                removed.setdefault(ident, []).append(name)
    return dict(sorted(removed.items()))


def translated_islands(islands):
    out = []
    for island in islands["islands"]:
        cx, cz = translate(tuple(island["centre"]), FOREST_OFFSET)
        out.append({"id": island["id"], "key": island["key"], "centre": [cx, cz], "floorRadius": island["floorRadius"],
                    "zone": island["zone"], "tier": island["tier"], "rewardTier": island["rewardTier"],
                    "species": island["species"], "adults": island["adults"],
                    "adultPoints": [{"x": r3(p["x"] + FOREST_OFFSET[0]), "z": r3(p["z"] + FOREST_OFFSET[1]),
                                     "faceX": p["faceX"], "faceZ": p["faceZ"]} for p in island["adultPoints"]]})
    return out


def translated_relief(relief):
    return [{"id": s["id"], "feature": s["feature"], "a": list(translate(tuple(s["a"]), FOREST_OFFSET)),
             "b": list(translate(tuple(s["b"]), FOREST_OFFSET)), "height": s["height"]} for s in relief["segments"]]


def translated_hide_spots(hide):
    return [{"id": s["id"], "kind": s["kind"], "x": r3(s["x"] + FOREST_OFFSET[0]), "z": r3(s["z"] + FOREST_OFFSET[1]),
             "yaw": s["yaw"]} for s in hide["spots"]]


# ---- Refugios -----------------------------------------------------------------------------------
def all_beasts(west, east):
    return west.beasts() + east.beasts()


def refugio_candidates(region, roads, shapes, beasts):
    """Never inside any beast's reach (strike zone or leash) plus a margin, on either side of the world."""
    xs = range(int(region.bounds[0] + REFUGIO_EDGE_MARGIN), int(region.bounds[1] - REFUGIO_EDGE_MARGIN) + 1, 10)
    zs = range(int(region.bounds[2] + REFUGIO_EDGE_MARGIN), int(region.bounds[3] - REFUGIO_EDGE_MARGIN) + 1, 10)
    found = []
    for x in xs:
        for z in zs:
            p = (float(x), float(z))
            if any(math.dist(p, b["home"]) < b["reach"] + REFUGIO_BEAST_MARGIN for b in beasts):
                continue
            if region.in_safe(*p, margin=REFUGIO_SAFE_MARGIN):
                continue
            if math.hypot(*p) <= HUB_RADIUS + REFUGIO_SAFE_MARGIN or road_distance(roads, p) < REFUGIO_ROAD_CLEAR:
                continue
            if any(g.shape_point_dist(shape, p) < REFUGIO_PROP_CLEAR for _, shape in shapes):
                continue
            found.append(p)
    return found


def pick_refugios(region, candidates, rng):
    """Farthest-point sampling from a seeded start, then round-robin into sets sorted by bearing."""
    want = REFUGIO_SETS * REFUGIO_PER_SET
    if len(candidates) < want:
        raise RuntimeError("%s: only %d refugio candidates" % (region.key, len(candidates)))
    chosen = [candidates[rng.randrange(len(candidates))]]
    while len(chosen) < want:
        best = max(candidates, key=lambda p: min(math.dist(p, c) for c in chosen))
        chosen.append(best)
    chosen.sort(key=lambda p: math.atan2(p[1] - region.centre[1], p[0] - region.centre[0]))
    sets = []
    for k in range(REFUGIO_SETS):
        members = chosen[k::REFUGIO_SETS]
        for i in range(len(members)):
            for j in range(i + 1, len(members)):
                if math.dist(members[i], members[j]) < REFUGIO_MIN_SPACING:
                    raise RuntimeError("%s refugio set %d too tight" % (region.key, k))
        sets.append({"id": "%s-%s" % (region.key[0].upper(), "ABC"[k]),
                     "candidates": [{"id": "%s%s%d" % (region.key[0].upper(), "ABC"[k], i + 1), "x": r3(p[0]), "z": r3(p[1]),
                                     "zone": region.zone(*p), "distance_home": r3(region.distance_home(*p))}
                                    for i, p in enumerate(members)]})
    return sets


# ---- Hooks --------------------------------------------------------------------------------------
def west_hook(region, roads, shapes):
    gate = (-100.0, 20.0)
    best = None
    for x in range(int(region.bounds[1] - 150), int(region.bounds[1]) + 1, 5):
        for z in range(-150, 151, 5):
            p = (float(x), float(z))
            d = math.dist(p, gate)
            if not HOOK_GATE_BAND[0] <= d <= HOOK_GATE_BAND[1] or not region.in_bounds(*p, margin=HOOK_FLOOR):
                continue
            if region.in_beast_rect(*p) or region.in_safe(*p, margin=HOOK_FLOOR) or math.hypot(*p) <= HUB_RADIUS + HOOK_FLOOR:
                continue
            if road_distance(roads, p) < HOOK_ROAD_CLEAR:
                continue
            clear = min(g.shape_point_dist(shape, p) for _, shape in shapes)
            if clear < HOOK_PROP_CLEAR:
                continue
            score = (abs(d - HOOK_IDEAL), -clear)
            if best is None or score < best[0]:
                best = (score, p, d, clear)
    if best is None:
        raise RuntimeError("no west hook candidate")
    _, p, d, clear = best
    return {"id": "umbral", "name": "Claro del Umbral", "side": "west", "x": r3(p[0]), "z": r3(p[1]), "gate": list(gate),
            "distance_from_gate": r3(d), "walk_seconds_from_gate": r3(d / WALK_SPEED), "prop_clearance": r3(clear),
            "zone": region.zone(*p), "distance_home": r3(region.distance_home(*p)), "tier": "Safe",
            "species": "Lumipol", "note": "new Safe-tier nest near the forest threshold; island 1 keeps its data"}


def east_hook(region):
    """The Pradera kit's first nest (Chispin, N1), visible from the rainbow gate, is the east first-steal hook."""
    gate = region.gate
    nest = region.nests[0]
    p = (nest["x"], nest["z"])
    d = math.dist(p, gate)
    clear = min(g.shape_point_dist(shape, p) for _, shape in region.solids)
    return {"id": "chispin", "name": "Nido de Chispín", "side": "east", "x": p[0], "z": p[1], "gate": list(gate),
            "distance_from_gate": r3(d), "walk_seconds_from_gate": r3(d / WALK_SPEED), "prop_clearance": r3(clear),
            "zone": region.zone(*p), "distance_home": r3(region.distance_home(*p)), "tier": "Safe",
            "species": nest["species"], "nest": nest["id"],
            "note": "the Pradera kit's first nest (N1, Comun), visible from the rainbow gate; replaces the draft Prado de los Brotes"}


# ---- Spawn-graph seeds ----------------------------------------------------------------------------
def seed_ok(region, p):
    return region.in_bounds(*p) and not region.in_safe(*p, margin=SEED_SAFE_MARGIN) and math.hypot(*p) > HUB_RADIUS + SEED_SAFE_MARGIN


def make_seed(region, kind, p, height, source):
    d = region.distance_home(*p)
    return {"kind": kind, "x": r3(p[0]), "z": r3(p[1]), "height": r3(height), "zone": region.zone(*p),
            "distance_home": r3(d), "tier": tier_for(d), "source": source}


def forest_seeds(region, instances, islands_world, roads):
    seeds = []
    for inst in instances:
        name, p, s = inst["name"], (inst["x"], inst["z"]), inst["scale"]
        if name in forest.TREES:
            # Base: 4 studs from the pivot toward the nearest route point (a spot at the root flare).
            _, arc, _, _ = g.project_to_polyline(region.route + region.route[:1], p)
            foot, _, _ = g.polyline_point(region.route + region.route[:1], arc)
            dx, dz = foot[0] - p[0], foot[1] - p[1]
            length = math.hypot(dx, dz) or 1.0
            base = (p[0] + 4.0 * dx / length, p[1] + 4.0 * dz / length)
            if seed_ok(region, base):
                seeds.append(make_seed(region, "tree_base", base, 0.0, inst["id"]))
            if name == "FK_Evergreen":
                height = forest.PROPS[name]["height"] * s * 0.6
                if seed_ok(region, p):
                    seeds.append(make_seed(region, "canopy", p, height, inst["id"]))
        elif name == "FK_FallenLog" and seed_ok(region, p):
            seeds.append(make_seed(region, "log", p, forest.PROPS[name]["height"] * s * 0.5, inst["id"]))
    for island in islands_world:
        c = tuple(island["centre"])
        if seed_ok(region, c):
            seeds.append(make_seed(region, "nest", c, 0.5, island["id"]))
    loop = region.route + region.route[:1]
    length = g.polyline_length(loop)
    arc = TRAIL_SEED_STEP / 2
    while arc < length:
        point, direction, _ = g.polyline_point(loop, arc)
        for side in (-1, 1):
            p = (point[0] - direction[1] * TRAIL_SEED_LATERAL * side, point[1] + direction[0] * TRAIL_SEED_LATERAL * side)
            if seed_ok(region, p) and road_distance(roads, p) >= ROAD_HALF + 1.0:
                seeds.append(make_seed(region, "trail_edge", p, 0.0, "route@%d" % round(arc)))
        arc += TRAIL_SEED_STEP
    return seeds


def pradera_seed_ok(region, p):
    """No Legendaria seed: in the Pradera, Legendaria comes only from the event egg (Pradera plan section 4).

    So nothing spawns within the Legendaria band of la Nube's pond, nothing inside La Colmena's leash disc
    (the event egg's glade stays the event's), and nothing inside a kit prop's footprint."""
    if region.distance_home(*p) < TIER_BANDS[0][2]:
        return False
    if math.dist(p, region.hive) < region.event_leash + SEED_SAFE_MARGIN:
        return False
    return all(g.shape_point_dist(shape, p) >= 1.0 for _, shape in region.solids)


def pradera_seeds(region, roads, rng):
    """A jittered meadow grid filtered by the kit, plus the kit's four wild nests (the event nest is not a seed)."""
    seeds = []
    x = region.bounds[0] + PRADERA_SEED_STEP
    while x < region.bounds[1] - PRADERA_SEED_STEP / 2:
        z = region.bounds[2] + PRADERA_SEED_STEP
        while z < region.bounds[3] - PRADERA_SEED_STEP / 2:
            p = (x + rng.uniform(-PRADERA_SEED_JITTER, PRADERA_SEED_JITTER), z + rng.uniform(-PRADERA_SEED_JITTER, PRADERA_SEED_JITTER))
            if seed_ok(region, p) and road_distance(roads, p) >= ROAD_HALF + 3.0 and pradera_seed_ok(region, p):
                seeds.append(make_seed(region, "meadow", p, 0.0, "grid"))
            z += PRADERA_SEED_STEP
        x += PRADERA_SEED_STEP
    for nest in region.nests:
        if not nest["eventOnly"]:
            seeds.append(make_seed(region, "nest", (nest["x"], nest["z"]), 0.5, nest["id"]))
    return seeds


def seed_summary(seeds):
    by_tier, by_kind, by_zone = {}, {}, {}
    for s in seeds:
        by_tier[s["tier"]] = by_tier.get(s["tier"], 0) + 1
        by_kind[s["kind"]] = by_kind.get(s["kind"], 0) + 1
        by_zone[s["zone"]] = by_zone.get(s["zone"], 0) + 1
    return {"count": len(seeds), "by_tier": dict(sorted(by_tier.items())), "by_kind": dict(sorted(by_kind.items())),
            "by_zone": dict(sorted(by_zone.items()))}


# ---- Zone rules for the Luau writer ---------------------------------------------------------------
def zone_rules(west, east):
    return {
        "hub": {"centre": [0.0, 0.0], "safe_radius": HUB_RADIUS, "spawn_pad": {"x": SPAWN_PAD[0], "z": SPAWN_PAD[1], "radius": SPAWN_PAD[2]}},
        "forest": {"offset": list(FOREST_OFFSET), "home": list(west.home), "leash": west.leash, "chase_leash": west.chase_leash,
                   "fog": {"x": [west.beast_rect[0], west.beast_rect[1]], "z": [west.beast_rect[2], west.beast_rect[3]]},
                   "safe": {name: {"centre": list(c), "r": r} for name, (c, r) in west.safe_circles.items()}},
        "pradera": {"offset": list(PRADERA_OFFSET), "source": "assets/maps/pradera-layout/pradera-layout-v1.json",
                    "home": list(east.home), "strike_radius": east.strike_radius, "leash": east.leash,
                    "beast": east.beast_name,
                    "event_beast": {"name": east.event["displayName"], "hive": list(east.hive), "guard_radius": east.guard_radius,
                                    "leash": east.event_leash, "wake_radius": east.wake_radius, "active": "event"},
                    "safe": {name: {"centre": list(c), "r": r} for name, (c, r) in east.safe_circles.items()}},
        "strike_zones": [{"beast": b["name"], "key": b["key"], "home": list(b["home"]), "strike_radius": b["strike_radius"],
                          "reach": b["reach"], "active": b["active"]} for b in all_beasts(west, east)],
        "beast_free_band": {"x": [west.reach()["chase_x"], east.reach()["strike_x"]],
                            "note": "no always-on beast can hunt here: the hub, both transitions, the Pradera's west half and "
                                    "the whole ring road. Only while the Pradera event egg is up, La Abeja Reina guards La "
                                    "Colmena inside this band; her ground touches no road, gate or safe circle"},
        "one_beast_per_player": "the strike zones never overlap (no point is inside two), so one player is never the "
                                "target of two beasts at once",
        "region_of": "x < -100: forest; -100..-60 and 60..100: transitions; |x| <= 60 inside the hub circle: hub; "
                     "x > 100: pradera; |z| > 200 or x > 500: ring road",
    }


def plaza_walk(east, conns):
    """Walking distance from the hub's east gate to the Plaza del Molino: connector, then the cream path."""
    path = east.route
    plaza = east.safe_circles["plaza_molino"][0]
    index = min(range(len(path)), key=lambda k: math.dist(path[k], plaza))
    return g.polyline_length(conns["umbral_este"]["nodes"]) + g.polyline_length(path[:index + 1])


# ---- Generation -----------------------------------------------------------------------------------
def generate(seed=DEFAULT_SEED, inputs=None):
    inputs = inputs or load_forest_inputs()
    rng = random.Random(seed)
    west, east = make_regions(inputs.get("pradera"))
    conns = connectors(west, east)
    roads = all_road_polylines(west, east, conns)
    instances = translated_forest_instances(inputs["layout"])
    shapes = forest_shapes(instances)
    removed = props_removed_by([r for r in roads if r[0] in ("ring", "umbral_oeste", "espolon_campamento", "espolon_norte",
                                                             "espolon_sur")], shapes)
    kept_shapes = [(ident, shape) for ident, shape in shapes if ident not in removed]
    islands_world = translated_islands(inputs["islands"])
    beasts = all_beasts(west, east)
    west_sets = pick_refugios(west, refugio_candidates(west, roads, kept_shapes, beasts), rng)
    # East: keep clear of the kit's solid props and of its rerolled sun-circle candidates (no stacked safe discs).
    east_shapes = east.solids + [(c["id"], g.Circle(c["centre"][0], c["centre"][1], c["r"])) for c in east.sun_candidates]
    east_sets = pick_refugios(east, refugio_candidates(east, roads, east_shapes, beasts), rng)
    hooks = {"west": west_hook(west, roads, kept_shapes), "east": east_hook(east)}
    kept_instances = [i for i in instances if i["id"] not in removed]
    seeds = {"west": forest_seeds(west, kept_instances, islands_world, roads), "east": pradera_seeds(east, roads, rng)}
    transitions = {
        "west": {"x": [-100.0, -HUB_RADIUS], "z": [-TRANSITION_HALF_Z, TRANSITION_HALF_Z],
                 "dressing": "evergreens thin to grass over 40 studs; fog density ramps from 0 at the hub wall to the forest value at the fog edge (x -135)"},
        "east": {"x": [HUB_RADIUS, 100.0], "z": [-TRANSITION_HALF_Z, TRANSITION_HALF_Z],
                 "dressing": "hub paving breaks into flower clumps and pale grass over 40 studs; warm light ramps up"},
    }
    ring_length = g.polyline_length(RING_ROAD + RING_ROAD[:1])
    for name, nodes, closed in roads:
        if name == "ring":
            for ident, shape in shapes:
                if g.shape_polyline_dist(shape, nodes, closed=True) < ROAD_HALF:
                    raise RuntimeError("ring road crosses forest prop %s" % ident)
    layout = {
        "name": LAYOUT_NAME,
        "status": "design, unvalidated: never built in Studio, played or measured on a device",
        "seed": seed,
        "conventions": {
            "units": "studs, origin at the hub centre; x east, z south; rotation_y_deg as CFrame.Angles(0, rad, 0)",
            "forest_frame": "forest_world = forest_local + forest.offset; forest-layout-v1.json, islands-v1.json, relief-v1.json and "
                            "hide-spots-v1.json stay in the forest local frame",
            "sources": {"forest_layout": "assets/maps/forest-layout/forest-layout-v1.json", "islands": "assets/maps/forest-layout/islands-v1.json",
                        "relief": "assets/maps/forest-layout/relief-v1.json", "hide_spots": "assets/maps/forest-layout/hide-spots-v1.json",
                        "pradera_layout": "assets/maps/pradera-layout/pradera-layout-v1.json"},
        },
        "world": {"size": list(WORLD_SIZE), "bounds": {"x": list(WORLD_BOUNDS["x"]), "z": list(WORLD_BOUNDS["z"])},
                  "walk_speed": WALK_SPEED, "hub_to_forest_camp": r3(math.dist(HUB_GATES["W"], west.safe_circles["camp"][0])),
                  "hub_gate_to_plaza_molino_walk": r3(plaza_walk(east, conns))},
        "hub": hub_report(),
        "regions": {"forest": west.report(), "pradera": east.report()},
        "transitions": transitions,
        "ring_road": {"nodes": [list(p) for p in RING_ROAD], "closed": True, "width": ROAD_WIDTH, "length": r3(ring_length),
                      "walk_seconds": r3(ring_length / WALK_SPEED), "beast_free": True},
        "connectors": {name: {"from": c["from"], "to": c["to"], "nodes": [[r3(p[0]), r3(p[1])] for p in c["nodes"]],
                              "width": ROAD_WIDTH, "length": r3(g.polyline_length(c["nodes"])), "region": c["region"]}
                       for name, c in conns.items()},
        "zone_rules": zone_rules(west, east),
        "forest_block": {
            "instances_total": len(instances), "instances_kept": len(kept_instances),
            "removed_props": [{"id": ident, "by": by} for ident, by in removed.items()],
            "islands": islands_world, "relief_segments": translated_relief(inputs["relief"]),
            "hide_spots": translated_hide_spots(inputs["hide_spots"]),
            "triangles": inputs["layout"]["totals"]["triangles"],
        },
        "hooks": hooks,
        "refugio_rules": {"radius": REFUGIO_RADIUS, "sets_per_side": REFUGIO_SETS, "per_set": REFUGIO_PER_SET, "min_spacing": REFUGIO_MIN_SPACING,
                          "beast_margin": REFUGIO_BEAST_MARGIN, "safe_margin": REFUGIO_SAFE_MARGIN, "road_clear": REFUGIO_ROAD_CLEAR,
                          "prop_clear": REFUGIO_PROP_CLEAR,
                          "beast_rule": "centre at least reach + beast_margin from every beast's home (Silueta 100, Nube 110, "
                                        "Abeja 45), so the whole disc stays outside every strike zone"},
        "refugio_sets": {"west": west_sets, "east": east_sets},
        "tier_bands": [{"tier": t, "min": lo, "max": (None if hi == math.inf else hi)} for t, lo, hi in TIER_BANDS],
        "spawn_seed_summary": {"west": seed_summary(seeds["west"]), "east": seed_summary(seeds["east"])},
        "spawn_seeds": seeds,
        "streaming": {
            "streaming_enabled": True, "min_radius": 64, "target_radius_recommended": 420, "stream_out": "Opportunistic",
            "persistent_models": ["La Silueta", "La Nube Gruñona", "La Abeja Reina (while the event runs)", "hub stations"],
            "triangles": {"forest_plan": inputs["layout"]["totals"]["triangles"], "pradera_cap": 40000, "hub_cap": 12000,
                          "ring_and_connectors_cap": 6000},
            "note": "with a 420 target radius a player at the hub streams the hub, both transitions and about a third of each "
                    "region (La Silueta's home is inside it, la Nube's is not); measure on a phone before trusting any number",
        },
    }
    return layout


def to_json(layout):
    """Deterministic JSON: stable key order, compact rows for seeds and refugio candidates, LF newlines."""
    parts = []
    for key, value in layout.items():
        if key == "spawn_seeds":
            sides = []
            for side, rows in value.items():
                body = ",\n".join("      " + json.dumps(row, ensure_ascii=False) for row in rows)
                sides.append('    "%s": [\n%s\n    ]' % (side, body))
            parts.append('  "spawn_seeds": {\n%s\n  }' % ",\n".join(sides))
        else:
            parts.append("  %s: %s" % (json.dumps(key), json.dumps(value, indent=2, ensure_ascii=False).replace("\n", "\n  ")))
    return "{\n" + ",\n".join(parts) + "\n}\n"


# ---- Drawing ------------------------------------------------------------------------------------------
CANVAS = (1440, 820)
MAP_SCALE, MAP_X0, MAP_Y0 = 1.2, 46.0, 70.0
C_FOREST, C_FOG, C_TERR, C_CHASE = "#cfd8c4", "#4b5d73", "#c0392b", "#e67e22"
C_PRADERA, C_ROAM, C_ABEJA = "#f3e7b8", "#b4a8d2", "#f2a33a"
C_HUB, C_ROAD, C_RING = "#f0d9a8", "#c9a96a", "#a88a4a"
C_TREE, C_DEAD, C_LOG = "#1f6b3a", "#3d2610", "#8a5a2b"
C_SAFE, C_REFUGIO, C_HOOK, C_SEED = "#27ae60", "#0b8fa8", "#d4a017", "#8e44ad"


def build_scene(layout):
    scene = render.Scene(*CANVAS)
    half = -WORLD_BOUNDS["x"][0]
    # World adds the same half extent on both axes; shift the vertical origin so the north edge lands at MAP_Y0.
    world = render.World(MAP_SCALE, MAP_X0, MAP_Y0 - (half + WORLD_BOUNDS["z"][0]) * MAP_SCALE, half)
    s = MAP_SCALE
    scene.text(MAP_X0, 30, "Wildbound open world plan v1 - DESIGN, unvalidated - top-down", size=22, bold=True)
    scene.text(MAP_X0, 52, "seed %d | %d x %d studs | hub at the origin, forest west, Pradera east | north (-z) is up"
               % (layout["seed"], WORLD_SIZE[0], WORLD_SIZE[1]), size=13, fill="#444444")
    wb = layout["world"]["bounds"]
    scene.rect(world.px(wb["x"][0]), world.py(wb["z"][0]), WORLD_SIZE[0] * s, WORLD_SIZE[1] * s, fill="#e6e2d6", stroke="#222222", sw=1.5)
    for key, colour in (("forest", C_FOREST), ("pradera", C_PRADERA)):
        b = layout["regions"][key]["bounds"]
        scene.rect(world.px(b["x"][0]), world.py(b["z"][0]), (b["x"][1] - b["x"][0]) * s, (b["z"][1] - b["z"][0]) * s,
                   fill=colour, stroke="#555555", sw=1)
    rect = layout["regions"]["forest"]["beast"]["rect"]
    scene.rect(world.px(rect["x"][0]), world.py(rect["z"][0]), (rect["x"][1] - rect["x"][0]) * s,
               (rect["z"][1] - rect["z"][0]) * s, fill=C_FOG, fo=0.35, stroke=C_FOG, sw=1.2)
    beast = layout["regions"]["forest"]["beast"]
    hx, hz = beast["home"]
    scene.circle(world.px(hx), world.py(hz), beast["leash"] * s, stroke=C_TERR, sw=1.5, dash=(6, 4))
    scene.circle(world.px(hx), world.py(hz), beast["chase_leash"] * s, stroke=C_CHASE, sw=1.0, dash=(3, 5))
    scene.circle(world.px(hx), world.py(hz), 5, fill=C_TERR, stroke="#ffffff", sw=1)
    scene.text(world.px(hx) + 8, world.py(hz) - 8, beast["name"], size=12, bold=True, fill=C_TERR)
    east = layout["regions"]["pradera"]
    nube, abeja = east["beast"], east["event_beast"]
    hx, hz = nube["home"]
    scene.circle(world.px(hx), world.py(hz), nube["strike_radius"] * s, fill=C_ROAM, fo=0.35, stroke=C_TERR, sw=1.5, dash=(6, 4))
    scene.circle(world.px(hx), world.py(hz), nube["leash"] * s, stroke=C_CHASE, sw=1.0, dash=(3, 5))
    scene.circle(world.px(hx), world.py(hz), 5, fill=C_TERR, stroke="#ffffff", sw=1)
    scene.text(world.px(hx) - 60, world.py(hz) - 8, nube["name"], size=12, bold=True, fill=C_TERR)
    ax, az = abeja["hive"]
    scene.circle(world.px(ax), world.py(az), abeja["leash"] * s, fill=C_ABEJA, fo=0.15, stroke=C_ABEJA, sw=1.0, dash=(3, 4))
    scene.circle(world.px(ax), world.py(az), abeja["guard_radius"] * s, fill=C_ABEJA, fo=0.30, stroke="#b8793a", sw=1.4, dash=(6, 4))
    scene.text(world.px(ax) - 50, world.py(az) + abeja["leash"] * s + 12, "La Abeja Reina (event)", size=11, bold=True, fill="#7a4a12")
    for t in layout["transitions"].values():
        scene.rect(world.px(t["x"][0]), world.py(t["z"][0]), (t["x"][1] - t["x"][0]) * s, (t["z"][1] - t["z"][0]) * s,
                   fill="#ffffff", fo=0.45, stroke="#888888", sw=0.8, dash=(4, 3))
    ring = layout["ring_road"]["nodes"]
    scene.line([world.pt(p) for p in ring + ring[:1]], stroke=C_RING, sw=ROAD_WIDTH * s)
    for c in layout["connectors"].values():
        scene.line([world.pt(p) for p in c["nodes"]], stroke=C_ROAD, sw=ROAD_WIDTH * s)
    for key in ("forest", "pradera"):
        route = layout["regions"][key]["route"]["nodes"]
        drawn = route + route[:1] if layout["regions"][key]["route"]["closed"] else route
        scene.line([world.pt(p) for p in drawn], stroke=C_ROAD, sw=ROAD_WIDTH * s)
        scene.line([world.pt(p) for p in drawn], stroke="#6b5320", sw=1.0, dash=(8, 6))
        for name, p in zip(layout["regions"][key]["route"]["names"], route):
            scene.circle(world.px(p[0]), world.py(p[1]), 3.5, fill="#ffffff", stroke="#3a2f12", sw=1.2)
            scene.text(world.px(p[0]) + 6, world.py(p[1]) - 5, name, size=10, fill="#3a2f12")
        for name, circle in layout["regions"][key]["safe_circles"].items():
            cx, cz = circle["centre"]
            scene.circle(world.px(cx), world.py(cz), circle["r"] * s, fill=C_SAFE, fo=0.25, stroke=C_SAFE, sw=1.2)
    hub = layout["hub"]
    scene.circle(world.px(0), world.py(0), hub["safe_radius"] * s, fill=C_HUB, fo=0.9, stroke=C_SAFE, sw=2)
    scene.circle(world.px(0), world.py(0), hub["plaza_ring"]["outer"] * s, fill=C_ROAD, fo=0.8)
    scene.circle(world.px(0), world.py(0), hub["plaza_ring"]["inner"] * s, fill=C_HUB)
    for spoke in hub["spokes"].values():
        scene.line([world.pt(spoke["from"]), world.pt(spoke["to"])], stroke=C_ROAD, sw=ROAD_WIDTH * s)
    for st in hub["stations"]:
        shape = station_shape({"footprint": {k: (tuple(v) if isinstance(v, list) else v) for k, v in st["footprint"].items()},
                               "centre": tuple(st["centre"])})
        if isinstance(shape, g.Circle):
            scene.circle(world.px(shape.x), world.py(shape.z), shape.r * s, fill="#8e6b3a", stroke="#111111", sw=0.8)
        else:
            scene.poly([world.pt(p) for p in shape.pts], fill="#8e6b3a", stroke="#111111", sw=0.8)
    for plinth in hub["trophies"]:
        scene.circle(world.px(plinth["centre"][0]), world.py(plinth["centre"][1]), plinth["r"] * s, fill="#b08d57", stroke="#111111", sw=0.6)
    scene.circle(world.px(0), world.py(0), SPAWN_PAD[2] * s, fill="#ffffff", stroke="#333333", sw=1)
    for pad in hub["spawn"]["pads"]:
        scene.rect(world.px(pad["centre"][0]) - 2 * s, world.py(pad["centre"][1]) - 2 * s, 4 * s, 4 * s, fill="#ffffff", stroke="#333333", sw=0.6)
    # Forest props (kept) as small marks.
    removed = {r["id"] for r in layout["forest_block"]["removed_props"]}
    for seed in layout["spawn_seeds"]["west"]:
        if seed["kind"] == "canopy":
            scene.circle(world.px(seed["x"]), world.py(seed["z"]), 2.2, fill=C_TREE, fo=0.8)
        elif seed["kind"] == "log":
            scene.circle(world.px(seed["x"]), world.py(seed["z"]), 1.8, fill=C_LOG)
    for seed in layout["spawn_seeds"]["east"]:
        scene.circle(world.px(seed["x"]), world.py(seed["z"]), 1.3, fill=C_SEED, fo=0.5)
    for island in layout["forest_block"]["islands"]:
        cx, cz = island["centre"]
        scene.circle(world.px(cx), world.py(cz), island["floorRadius"] * s, fill="#ffffff", fo=0.5, stroke="#d35400", sw=1.2)
        scene.text(world.px(cx) + 4, world.py(cz) + 4, island["id"], size=10, bold=True, fill="#d35400")
    for side, sets in layout["refugio_sets"].items():
        for k, group in enumerate(sets):
            for cand in group["candidates"]:
                scene.circle(world.px(cand["x"]), world.py(cand["z"]), REFUGIO_RADIUS * s, fill=C_REFUGIO, fo=0.3 + 0.2 * k, stroke=C_REFUGIO, sw=1)
                scene.text(world.px(cand["x"]) - 8, world.py(cand["z"]) - 10, cand["id"], size=9, fill=C_REFUGIO)
    for hook in layout["hooks"].values():
        scene.circle(world.px(hook["x"]), world.py(hook["z"]), HOOK_FLOOR * s, fill=C_HOOK, fo=0.45, stroke="#7a5a00", sw=1.5)
        scene.text(world.px(hook["x"]) - 20, world.py(hook["z"]) - 20, hook["name"], size=11, bold=True, fill="#7a5a00")
    # Legend.
    x0, y = MAP_X0, MAP_Y0 + WORLD_SIZE[1] * s + 40
    scene.text(x0, y, "Legend", size=16, bold=True)
    rows = [("Forest block (400 x 400, translated -300, 0)", C_FOREST), ("Fog rectangle (moves with the block)", C_FOG),
            ("Pradera Arcoiris (400 x 400, from its kit plan)", C_PRADERA), ("La Nube's strike zone r 110", C_ROAM),
            ("La Abeja Reina at La Colmena, event only", C_ABEJA),
            ("Hub safe circle r 60, plaza ring 25-35", C_HUB), ("Ring road and spokes, 14 wide, beast-free", C_RING),
            ("Routes and connectors, 14 wide", C_ROAD), ("Permanent safe circle (camp, shelter, Pradera sun circles)", C_SAFE),
            ("Refugio candidate (3 sets per side)", C_REFUGIO), ("First-steal hook nest", C_HOOK),
            ("Pradera seed grid / forest canopy and log seeds", C_SEED)]
    col, rowy = 0, y
    for label, colour in rows:
        rowy += 22
        if rowy > CANVAS[1] - 10:
            col += 1
            rowy = y + 22
        xx = x0 + col * 440
        scene.rect(xx, rowy - 12, 22, 14, fill=colour, stroke="#333333", sw=0.8)
        scene.text(xx + 32, rowy, label, size=12)
    xx = x0 + 900
    scene.text(xx, y, "Numbers", size=16, bold=True)
    sumw, sume = layout["spawn_seed_summary"]["west"], layout["spawn_seed_summary"]["east"]
    for line in ["Ring road %.0f studs, %.0f s at 16 studs/s" % (layout["ring_road"]["length"], layout["ring_road"]["walk_seconds"]),
                 "Hub gate to forest camp %.0f studs" % layout["world"]["hub_to_forest_camp"],
                 "Forest props kept %d of %d (%d removed for roads)" % (layout["forest_block"]["instances_kept"],
                                                                        layout["forest_block"]["instances_total"],
                                                                        len(layout["forest_block"]["removed_props"])),
                 "Seeds west %d, east %d" % (sumw["count"], sume["count"]),
                 "Dashed red: Silueta territory 80, Nube strike zone 110", "Dotted orange: Silueta chase 100, Nube leash 90"]:
        y += 22
        scene.text(xx, y, line, size=12)
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
    fb, hooks = layout["forest_block"], layout["hooks"]
    lines = ["seed %d: world %s, hub r %.0f, forest offset %s, pradera offset %s"
             % (layout["seed"], layout["world"]["size"], layout["hub"]["safe_radius"], layout["regions"]["forest"]["offset"],
                layout["regions"]["pradera"]["offset"])]
    lines.append("forest block: %d of %d props kept; removed %s" % (fb["instances_kept"], fb["instances_total"],
                                                                     [r["id"] for r in fb["removed_props"]]))
    lines.append("ring road %.0f studs (%.0f s); hub gate W to forest camp %.0f studs" % (
        layout["ring_road"]["length"], layout["ring_road"]["walk_seconds"], layout["world"]["hub_to_forest_camp"]))
    for side in ("west", "east"):
        hook = hooks[side]
        lines.append("hook %s: %s at (%.0f, %.0f), %.0f studs from the gate (%.1f s), zone %s"
                     % (side, hook["name"], hook["x"], hook["z"], hook["distance_from_gate"], hook["walk_seconds_from_gate"], hook["zone"]))
        lines.append("refugios %s: %s" % (side, [[c["id"] for c in group["candidates"]] for group in layout["refugio_sets"][side]]))
        lines.append("seeds %s: %s" % (side, layout["spawn_seed_summary"][side]))
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

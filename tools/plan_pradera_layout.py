#!/usr/bin/env python3
"""Reproducible top-down placement DRAFT for the Pradera Arcoiris sector (unvalidated).

The east biome for kids (docs/design/wildbound-biome-pradera.md): a 400 x 400 stud sector that
joins the hub through a rainbow gate on its west edge and holds La Nube Grunona's pond on its
east side. This is a plan only: it writes JSON, SVG and (when Pillow is importable) PNG files and
never touches Studio. tools/build-pradera-kit.py turns the JSON into a parts-only Luau builder.
Python standard library only; Pillow is optional. Nothing here was imported into Roblox, played
or measured on a device.

    python tools/plan_pradera_layout.py [--seed N] [--out-dir DIR]

Conventions (studs, origin at the sector centre): x grows east, z grows south, rotation_y_deg is
CFrame.Angles(0, math.rad(r), 0) (tools/layout_geometry.py). The hub frame places this sector
centre at world (+300, 0), so local x = -200 is the hub's east rim at world +100.
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
LAYOUT_NAME = "pradera-layout-v1"
DEFAULT_OUT_DIR = TOOLS.parent / "assets" / "maps" / "pradera-layout"

# ---- Sector, hub join and the beast ------------------------------------------------------
MAP_SIZE = 400.0
LIMIT = MAP_SIZE / 2 - 5.0
WORLD_OFFSET = (300.0, 0.0)          # sector centre in the hub frame (hub centre is the origin)
MAX_INSTANCES, MAX_PARTS = 220, 1700  # instances like the forest plan (207); parts are Luau primitives
WALK_SPEED = 16.0
CORRIDOR_HALF = 7.0                   # 14-stud cream path

HOME = (150.0, 0.0)                   # La Nube's pond centre, the beast home
POND_RADIUS = 28.0
BEAST_LEASH = 90.0                    # she never follows farther than this from the pond
TORMENTA_RADIUS = 110.0               # her strike zone: inside this, under open sky
LEGENDARIA_BAND, EPICA_BAND, RARA_BAND = 45.0, 80.0, 120.0  # W2 distance bands from the home
BEAST_WAYPOINT_RADIUS, BEAST_WAYPOINTS = 20.0, 6

GATE = (-186.0, 0.0)                  # Porton del Arcoiris, on the sector's west edge
GATE_SUN_RADIUS = 25.0                # the permanent sun circle centred on the gate
PLAZA = (-40.0, 14.0)                 # Plaza del Molino, the permanent sun circle on the path
SUN_RADIUS = 12.0                     # every other sun circle (candidates rerolled by the wave clock)
SUN_CANDIDATES = 6
SUN_MIN_FROM_HOME = 60.0              # the Legendaria band plus a 15-stud margin
SUN_MAX_FROM_HOME = 175.0
SUN_SPACING = 35.0

ROUTE_NODES = (("gate", (-195.0, 0.0)), ("meadow", (-140.0, 6.0)), ("plaza", PLAZA),
               ("rise", (45.0, 4.0)), ("pond_rim", (118.0, -4.0)))
ROUTE = [p for _, p in ROUTE_NODES]
ROUTE_LENGTH = g.polyline_length(ROUTE)

# Hills: (x, z, sphere radius, cap height). A hill is a sphere sunk so only `cap` studs show; the
# slope at its rim is acos((R - cap) / R), kept under 25 degrees so walking never slows.
HILLS = (("H1", -120.0, -110.0, 90.0, 8.0), ("H2", -110.0, 120.0, 110.0, 10.0),
         ("H3", 10.0, -120.0, 90.0, 8.0), ("H4", 20.0, 110.0, 110.0, 10.0),
         ("H5", 120.0, -130.0, 90.0, 8.0), ("H6", 130.0, 120.0, 90.0, 8.0),
         ("H7", -60.0, -40.0, 66.0, 6.0))
MAX_SLOPE_DEG = 25.0

# Five creatures, their nests and sleeping parents (islands pattern). Bands are distances from HOME.
SPECIES = (
    {"id": "Chispin", "name": "Chispín", "rarity": "Comun", "nest": (-125.0, -30.0), "adults": 2,
     "body": "F9E27A", "accent": "F2B84B", "eye": "3A2E22", "glow": "FFF1A8"},
    {"id": "Musgon", "name": "Musgón", "rarity": "Comun", "nest": (-30.0, -70.0), "adults": 2,
     "body": "A8E6B0", "accent": "6FBF8A", "eye": "2B3A30", "glow": "C9F5D0"},
    {"id": "Esponjin", "name": "Esponjín", "rarity": "Rara", "nest": (60.0, 50.0), "adults": 3,
     "body": "FFFFFF", "accent": "D9C8F0", "eye": "4A3F6B", "glow": "F2ECFF"},
    {"id": "Hongolin", "name": "Hongolín", "rarity": "Epica", "nest": (100.0, -45.0), "adults": 3,
     "body": "F28B9B", "accent": "FFF4E0", "eye": "3A2E22", "glow": "FFD7DE"},
    {"id": "Relampino", "name": "Relampino", "rarity": "Legendaria", "nest": (-75.0, 75.0), "adults": 0,
     "body": "B4A8D2", "accent": "FFD23F", "eye": "2B2440", "glow": "FFF1A8", "event_only": True},
)
NEST_RADIUS, NEST_ADULT_RING, NEST_CLEAR = 8.0, 6.0, 10.0
BANDS = (("Legendaria", 0.0, LEGENDARIA_BAND), ("Epica", LEGENDARIA_BAND, EPICA_BAND),
         ("Rara", EPICA_BAND, RARA_BAND), ("Comun", RARA_BAND, math.inf))
SETA_TRUENO = (136.0, -6.0)          # the tallest mushroom, in the shallows; a landmark and roof, no longer the event pedestal
SETA_TRUENO_CAP_TOP = 26.0

# ---- Biome event: La Abeja Reina guards the event egg at La Colmena ------------------------
# User decision 2026-11-10: la Nube is the permanent beast; La Abeja Reina wakes only while the
# 20-minute event egg is up (visible 5 minutes) and guards it, then sleeps. Her ground never
# touches la Nube's strike zone, a sun circle, the gate or the path, so one player is never the
# target of two beasts at once. Every number is a hypothesis for the tuning panel.
HIVE = (-75.0, 75.0)                  # La Colmena: the event egg pedestal, in a flat clearing south of the path
HIVE_CLEAR = NEST_RADIUS + 2.0        # no solid footprint this close to the egg pedestal (the wild-nest rule)
ABEJA_PATROL_RADIUS = 18.0            # her guard loop around the egg
ABEJA_GUARD_RADIUS = 35.0             # her strike zone ("colmenar"): she telegraphs and stings only inside it
ABEJA_LEASH = 45.0                    # she never flies farther than this from the egg
ABEJA_WAKE_RADIUS = 70.0              # a player's own Abeja wakes only while its owner is this close during the event
ABEJA_BEAST_GAP = 15.0                # her leash disc stays this far outside la Nube's strike zone
ABEJA_SUN_GAP = 5.0                   # and this far from every sun circle's rim
ABEJA_ROUTE_GAP = 3.0                 # and this far from the path's edge
EVENT_FIRST_SECONDS, EVENT_PERIOD_SECONDS, EVENT_WINDOW_SECONDS = 300.0, 1200.0, 300.0
ABEJA_TUNING = {"ABEJA_WAKE_SECONDS": 3.0, "ABEJA_SLEEP_SECONDS": 4.0, "ABEJA_PATROL_SPEED": 7.0,
                "ABEJA_CHASE_SPEED": 10.0, "ABEJA_HEAR_WALK": 30.0, "ABEJA_HEAR_SPRINT": 55.0,
                "ABEJA_HEAR_STILL": 0.0, "ABEJA_NOTICE_SECONDS": 1.0, "ABEJA_MEMORY_SECONDS": 3.0,
                "ABEJA_TELEGRAPH_SECONDS": 1.2, "ABEJA_TELEGRAPH_FLOOR": 0.8, "ABEJA_LANE_WIDTH": 6.0,
                "ABEJA_DIVE_LENGTH": 12.0, "ABEJA_COOLDOWN_SECONDS": 2.5, "ABEJA_STICKY_SPEED": 9.0,
                "ABEJA_STICKY_SECONDS": 6.0, "ABEJA_PARK_SECONDS": 120.0, "ABEJA_NIGHT_HEARING_SCALE": 0.5}

# ---- Kit (PA_) footprints and Luau part counts --------------------------------------------
# "parts" is what tools/build-pradera-kit.py emits per instance (primitives), not MeshParts.
PROPS = {
    "PA_GiantMushroom": {"kind": "mushroom", "stem_r": 2.5, "cap_r": 9.0, "parts": 8, "scale": (0.8, 1.3)},
    "PA_PuffTree": {"kind": "tree", "trunk_r": 1.2, "crown_r": 5.0, "parts": 5, "scale": (0.9, 1.2)},
    "PA_MushroomRing": {"kind": "ring", "r": 3.5, "parts": 12, "scale": (0.9, 1.1)},
    "PA_PuffFlower": {"kind": "flower", "r": 2.0, "parts": 4, "scale": (0.8, 1.2)},
    "PA_SunflowerPost": {"kind": "post", "r": 1.5, "parts": 4, "scale": (1.0, 1.0)},
    "PA_HillBoulder": {"kind": "boulder", "r": 3.0, "parts": 1, "scale": (0.8, 1.4)},
    "PA_RainbowGate": {"kind": "gate", "half": (15.0, 3.0), "parts": 23, "scale": (1.0, 1.0)},
    "PA_Pinwheel": {"kind": "pinwheel", "r": 1.0, "parts": 6, "scale": (1.0, 1.0)},
    "PA_SetaTrueno": {"kind": "landmark", "stem_r": 3.5, "cap_r": 13.0, "parts": 17, "scale": (1.0, 1.0)},
}
MIX = (("PA_GiantMushroom", 48), ("PA_PuffTree", 30), ("PA_MushroomRing", 12), ("PA_PuffFlower", 40),
       ("PA_SunflowerPost", 4 * (2 + SUN_CANDIDATES)), ("PA_HillBoulder", 20), ("PA_RainbowGate", 1),
       ("PA_Pinwheel", 16), ("PA_SetaTrueno", 1))
SHORT = {"PA_GiantMushroom": "mushroom", "PA_PuffTree": "tree", "PA_MushroomRing": "ring",
         "PA_PuffFlower": "flower", "PA_SunflowerPost": "post", "PA_HillBoulder": "boulder",
         "PA_RainbowGate": "gate", "PA_Pinwheel": "pinwheel", "PA_SetaTrueno": "landmark"}
CAP_COLOURS = ("Coral", "Sky", "Butter")
NEST_PARTS, ADULT_PARTS, HILL_PARTS, BEAST_PARTS, SIGN_PARTS = 4, 5, 2, 14, 3

BASE_GAP = 1.0
ROOF_REACH = 25.0          # every Tormenta point has a roof edge within this
PATH_ROOFS = 4             # mushrooms whose cap edge comes within 5 studs of the path centreline
PINWHEEL_OFFSET = 9.5
FLOWER_PATCHES = 8
GRID_STEP = 5.0


def r3(value):
    return round(float(value), 3) + 0.0


def dist(a, b):
    return math.dist(a, b)


# ---- Terrain ----------------------------------------------------------------------------
def hill_footprint(radius, cap):
    return math.sqrt(2.0 * radius * cap - cap * cap)


def hill_slope_deg(radius, cap):
    return math.degrees(math.acos((radius - cap) / radius))


def ground_height(x, z):
    """Height above the flat floor: the highest hill sphere under (x, z), else 0."""
    best = 0.0
    for _, hx, hz, radius, cap in HILLS:
        d = math.hypot(x - hx, z - hz)
        if d < hill_footprint(radius, cap):
            best = max(best, (cap - radius) + math.sqrt(radius * radius - d * d))
    return best


def hill_clearance(p, margin):
    """True when p stays `margin` outside every hill footprint (flat ground)."""
    return all(math.hypot(p[0] - hx, p[1] - hz) >= hill_footprint(r, c) + margin for _, hx, hz, r, c in HILLS)


def zone(x, z):
    if dist((x, z), GATE) <= GATE_SUN_RADIUS or dist((x, z), PLAZA) <= SUN_RADIUS:
        return "sol"
    if dist((x, z), HOME) <= TORMENTA_RADIUS:
        return "tormenta"
    return "prado"


def band(x, z):
    d = dist((x, z), HOME)
    for name, lo, hi in BANDS:
        if lo <= d < hi:
            return name
    return "Comun"


def in_pond(p, margin=0.0):
    return dist(p, HOME) <= POND_RADIUS + margin


def route_distance(p):
    return g.project_to_polyline(ROUTE, p)[0]


# ---- Instances --------------------------------------------------------------------------
def make_instance(name, x, z, yaw, scale, **extra):
    yaw = r3(yaw % 360.0)
    inst = {"name": name, "x": r3(x), "z": r3(z), "y": r3(ground_height(x, z)),
            "rotation_y_deg": 0.0 if yaw >= 360.0 else yaw, "scale": r3(scale), "zone": zone(x, z)}
    inst.update(extra)
    return inst


def footprint(inst):
    """Ground footprint of what collides or reads as a base."""
    spec, s = PROPS[inst["name"]], inst["scale"]
    if spec["kind"] in ("mushroom", "landmark"):
        return g.Circle(inst["x"], inst["z"], spec["stem_r"] * s)
    if spec["kind"] == "tree":
        return g.Circle(inst["x"], inst["z"], spec["trunk_r"] * s)
    if "r" in spec:
        return g.Circle(inst["x"], inst["z"], spec["r"] * s)
    return g.rect_poly(inst["x"], inst["z"], spec["half"][0], spec["half"][1], inst["rotation_y_deg"])


def canopy(inst):
    spec, s = PROPS[inst["name"]], inst["scale"]
    if spec["kind"] in ("mushroom", "landmark"):
        return spec["cap_r"] * s
    if spec["kind"] == "tree":
        return spec["crown_r"] * s
    return 0.0


def roof_covers(inst, p):
    """A roof (mushroom cap, puff-tree crown, Seta Trueno) is within ROOF_REACH of p."""
    reach = canopy(inst)
    return reach > 0.0 and math.hypot(inst["x"] - p[0], inst["z"] - p[1]) <= reach + ROOF_REACH


class Placer:
    def __init__(self, sun_circles, nests):
        self.items = []        # (inst, shape, kind)
        self.sun = sun_circles  # [(x, z, radius)]
        self.nests = nests      # [(x, z)]

    def add(self, inst):
        self.items.append((inst, footprint(inst), PROPS[inst["name"]]["kind"]))

    def valid(self, inst, allow_pond=False, allow_sun=False, allow_route=False):
        kind = PROPS[inst["name"]]["kind"]
        shape = footprint(inst)
        x0, z0, x1, z1 = g.shape_bbox(shape)
        if min(x0, z0) < -LIMIT or max(x1, z1) > LIMIT:
            return False
        anchor = (inst["x"], inst["z"])
        if not allow_pond and in_pond(anchor, g.shape_bound(shape)[2] + 1.0):
            return False
        if not allow_route:
            needed = 4.0 if kind == "flower" else CORRIDOR_HALF + BASE_GAP
            if g.shape_polyline_dist(shape, ROUTE) < needed:
                return False
        if not allow_sun:
            for sx, sz, sr in self.sun:
                if g.shape_point_dist(shape, (sx, sz)) < sr + 2.0:
                    return False
        for nx, nz in self.nests:
            if g.shape_point_dist(shape, (nx, nz)) < NEST_RADIUS + 2.0:
                return False
        for other, other_shape, other_kind in self.items:
            gap_needed = 0.3 if "flower" in (kind, other_kind) else BASE_GAP
            if g.shape_gap(shape, other_shape) < gap_needed:
                return False
            if kind == "tree" == other_kind and dist(anchor, (other["x"], other["z"])) < 14.0:
                return False
            if kind in ("mushroom", "tree") and other_kind in ("mushroom", "tree", "landmark"):
                if dist(anchor, (other["x"], other["z"])) < 0.7 * (canopy(inst) + canopy(other)):
                    return False
        return True


class IdSource:
    def __init__(self):
        self.counts = {}

    def next(self, name):
        key = SHORT[name]
        self.counts[key] = self.counts.get(key, 0) + 1
        return f"{key}-{self.counts[key]:02d}"

    def undo(self, name):
        self.counts[SHORT[name]] -= 1


def random_point(rng, limit=LIMIT - 10.0):
    return (rng.uniform(-limit, limit), rng.uniform(-limit, limit))


# ---- Fixed features ---------------------------------------------------------------------
def plan_sun_circles(rng, nests):
    """Two permanent sun circles plus SUN_CANDIDATES rerolled by the wave clock (W4)."""
    circles = [{"id": "sun-gate", "x": GATE[0], "z": GATE[1], "radius": GATE_SUN_RADIUS, "permanent": True,
                "label": "Portón del Arcoíris"},
               {"id": "sun-plaza", "x": PLAZA[0], "z": PLAZA[1], "radius": SUN_RADIUS, "permanent": True,
                "label": "Plaza del Molino"}]
    placed, attempts = [], 0
    while len(placed) < SUN_CANDIDATES:
        attempts += 1
        assert attempts < 60000, "could not place every sun-circle candidate"
        if len(placed) < 2:   # the first two sit inside the Tormenta zone, so safety exists where she hunts
            angle, radius = rng.uniform(0.0, math.tau), rng.uniform(SUN_MIN_FROM_HOME, TORMENTA_RADIUS - 4.0)
            p = (HOME[0] + radius * math.cos(angle), HOME[1] + radius * math.sin(angle))
        else:
            p = random_point(rng, LIMIT - SUN_RADIUS - 4.0)
        d = dist(p, HOME)
        if not SUN_MIN_FROM_HOME <= d <= SUN_MAX_FROM_HOME or max(abs(p[0]), abs(p[1])) > LIMIT - SUN_RADIUS - 2:
            continue
        if g.shape_polyline_dist(g.Circle(p[0], p[1], SUN_RADIUS), ROUTE) < 2.0:
            continue
        if any(dist(p, (c["x"], c["z"])) < SUN_SPACING + c["radius"] - SUN_RADIUS for c in circles + placed):
            continue
        if any(dist(p, n) < SUN_RADIUS + NEST_RADIUS + 6.0 for n in nests):
            continue
        if dist(p, HIVE) < ABEJA_LEASH + SUN_RADIUS + ABEJA_SUN_GAP:
            continue
        if not hill_clearance(p, SUN_RADIUS + 2.0):
            continue
        placed.append({"id": f"sun-{len(placed) + 1:02d}", "x": r3(p[0]), "z": r3(p[1]), "radius": SUN_RADIUS,
                       "permanent": False, "label": None})
    for c in circles + placed:
        c["zone"] = zone(c["x"], c["z"])
        c["distance_to_home"] = r3(dist((c["x"], c["z"]), HOME))
    return circles + placed


def plan_nests():
    nests = []
    for spec in SPECIES:
        x, z = spec["nest"]
        points = []
        for k in range(spec["adults"]):
            a = math.radians(90.0 + 360.0 * k / spec["adults"])
            fx, fz = math.cos(a), math.sin(a)
            points.append({"x": r3(x + fx * NEST_ADULT_RING), "z": r3(z + fz * NEST_ADULT_RING),
                           "faceX": r3(fx), "faceZ": r3(fz)})
        event = bool(spec.get("event_only"))
        # The event egg is Legendaria by rule (it hatches from the event only), not by its distance from her pond.
        nests.append({"id": f"N{len(nests) + 1}", "species": spec["id"], "displayName": spec["name"],
                      "rarity": spec["rarity"], "x": r3(x), "z": r3(z), "y": r3(ground_height(x, z)),
                      "radius": NEST_RADIUS, "adults": spec["adults"], "adultPoints": points,
                      "band": "Legendaria" if event else band(x, z), "distance_to_home": r3(dist((x, z), HOME)),
                      "zone": zone(x, z),
                      "eventOnly": event, "colors": {k: spec[k] for k in ("body", "accent", "eye", "glow")}})
    return nests


def place_gate(placer, ids):
    heading = g.heading_deg(1.0, 0.0)  # the passage runs along +X, into the sector
    inst = make_instance("PA_RainbowGate", GATE[0], GATE[1], heading, 1.0, id=ids.next("PA_RainbowGate"))
    assert placer.valid(inst, allow_sun=True, allow_route=True), "gate does not fit"
    placer.add(inst)
    return [inst]


def place_seta_trueno(placer, ids):
    inst = make_instance("PA_SetaTrueno", SETA_TRUENO[0], SETA_TRUENO[1], 0.0, 1.0, id=ids.next("PA_SetaTrueno"))
    inst["y"] = 0.0
    assert placer.valid(inst, allow_pond=True), "Seta Trueno does not fit"
    placer.add(inst)
    return [inst]


def place_posts(placer, ids, circles):
    posts = []
    for circle in circles:
        # The gate circle hangs over the sector edge, so its four posts stand on the arc that faces the meadow.
        angles = (-75.0, -35.0, 35.0, 75.0) if circle["id"] == "sun-gate" else (45.0, 135.0, 225.0, 315.0)
        for a in angles:
            a = math.radians(a)
            r = circle["radius"] - 2.0
            x, z = circle["x"] + r * math.cos(a), circle["z"] + r * math.sin(a)
            yaw = g.heading_deg(circle["x"] - x, circle["z"] - z)  # the flower face turns to the circle
            inst = make_instance("PA_SunflowerPost", x, z, yaw, 1.0, id=ids.next("PA_SunflowerPost"),
                                 sun_circle=circle["id"])
            assert placer.valid(inst, allow_sun=True, allow_route=True), f"post for {circle['id']} does not fit"
            placer.add(inst)
            posts.append(inst)
    return posts


def place_pinwheels(placer, ids):
    count = dict(MIX)["PA_Pinwheel"]
    spacing = (ROUTE_LENGTH - 60.0) / (count - 1)
    pinwheels = []
    for k in range(count):
        placed = None
        for delta in (0.0, 4.0, -4.0, 8.0, -8.0, 12.0, -12.0):
            arc = min(max(30.0 + spacing * k + delta, 6.0), ROUTE_LENGTH - 6.0)
            point, direction, _ = g.polyline_point(ROUTE, arc)
            for side in ((1, -1) if k % 2 == 0 else (-1, 1)):
                normal = (-direction[1] * side, direction[0] * side)
                inst = make_instance("PA_Pinwheel", point[0] + normal[0] * PINWHEEL_OFFSET,
                                     point[1] + normal[1] * PINWHEEL_OFFSET, 0.0, 1.0, id=ids.next("PA_Pinwheel"))
                if placer.valid(inst, allow_sun=True, allow_route=True) and \
                        g.shape_polyline_dist(footprint(inst), ROUTE) >= CORRIDOR_HALF + 0.5:
                    placed = inst
                    break
                ids.undo("PA_Pinwheel")
            if placed:
                break
        assert placed, f"no room for pinwheel {k}"
        placer.add(placed)
        pinwheels.append(placed)
    return pinwheels


# ---- Scatter ----------------------------------------------------------------------------
def mushroom_scale(rng, p):
    """Caps grow toward the pond: 0.8 far from her, about 1.25 at the rim, with a little jitter."""
    closeness = max(0.0, min(1.0, 1.0 - dist(p, HOME) / 300.0))
    return max(0.8, min(1.3, 0.8 + 0.5 * closeness + rng.uniform(-0.04, 0.04)))


def tormenta_grid():
    points = []
    steps = int(LIMIT * 2 / GRID_STEP)
    for i in range(steps + 1):
        for j in range(steps + 1):
            x, z = -LIMIT + i * GRID_STEP, -LIMIT + j * GRID_STEP
            if zone(x, z) == "tormenta" and not in_pond((x, z)):
                points.append((x, z))
    return points


def place_mushrooms(placer, ids, rng):
    target = dict(MIX)["PA_GiantMushroom"]
    mushrooms = []

    def try_at(x, z):
        inst = make_instance("PA_GiantMushroom", x, z, rng.uniform(0.0, 360.0), mushroom_scale(rng, (x, z)),
                             id=ids.next("PA_GiantMushroom"))
        if placer.valid(inst):
            inst["cap"] = CAP_COLOURS[(len(mushrooms)) % 3]
            placer.add(inst)
            mushrooms.append(inst)
            return True
        ids.undo("PA_GiantMushroom")
        return False

    # Phase 1: roofs over the path (a child walking in learns that caps are cover).
    for k in range(PATH_ROOFS):
        arc = ROUTE_LENGTH * (0.55 + 0.42 * k / (PATH_ROOFS - 1))
        point, direction, _ = g.polyline_point(ROUTE, arc)
        done = False
        for delta in (0.0, 6.0, -6.0, 12.0, -12.0, 18.0, -18.0):
            p2, d2, _ = g.polyline_point(ROUTE, min(max(arc + delta, 10.0), ROUTE_LENGTH - 10.0))
            for side in (1, -1):
                normal = (-d2[1] * side, d2[0] * side)
                if try_at(p2[0] + normal[0] * 11.0, p2[1] + normal[1] * 11.0):
                    done = True
                    break
            if done:
                break
        assert done, f"no room for path roof {k}"
    # Phase 2: fill the Tormenta zone until every point has a roof within ROOF_REACH.
    grid = tormenta_grid()
    rng.shuffle(grid)
    for point in grid:
        if any(roof_covers(m, point) for m in mushrooms):
            continue
        placed = False
        for attempt in range(240):
            # Near first, then anywhere whose cap edge still reaches the point (a sun circle may forbid the near ring).
            angle, radius = rng.uniform(0.0, math.tau), rng.uniform(0.0, 10.0 if attempt < 40 else 27.0)
            if try_at(point[0] + radius * math.cos(angle), point[1] + radius * math.sin(angle)):
                placed = True
                break
        assert placed, f"could not roof the Tormenta point {point}"
        assert len(mushrooms) <= target, "the Tormenta roof fill spent the whole mushroom budget"
    # Phase 3: scatter the rest, denser toward the pond.
    attempts = 0
    while len(mushrooms) < target:
        attempts += 1
        assert attempts < 60000, "could not place every giant mushroom"
        p = random_point(rng)
        if rng.random() < 0.55 and dist(p, HOME) > 180.0:
            continue
        try_at(*p)
    return mushrooms


def place_trees(placer, ids, rng):
    target, spec = dict(MIX)["PA_PuffTree"], PROPS["PA_PuffTree"]
    trees, attempts = [], 0
    while len(trees) < target:
        attempts += 1
        assert attempts < 60000, "could not place every puff tree"
        p = random_point(rng)
        if dist(p, HOME) < 60.0:
            continue
        inst = make_instance("PA_PuffTree", p[0], p[1], rng.uniform(0.0, 360.0), rng.uniform(*spec["scale"]),
                             id=ids.next("PA_PuffTree"))
        if placer.valid(inst):
            inst["puff"] = CAP_COLOURS[len(trees) % 3]
            placer.add(inst)
            trees.append(inst)
        else:
            ids.undo("PA_PuffTree")
    return trees


def place_boulders(placer, ids, rng):
    target, spec = dict(MIX)["PA_HillBoulder"], PROPS["PA_HillBoulder"]
    boulders, attempts = [], 0
    while len(boulders) < target:
        attempts += 1
        assert attempts < 60000, "could not place every boulder"
        if len(boulders) < target // 2:   # half of them are hill perches
            _, hx, hz, r, c = HILLS[len(boulders) % len(HILLS)]
            angle, radius = rng.uniform(0.0, math.tau), rng.uniform(4.0, hill_footprint(r, c) - 6.0)
            p = (hx + radius * math.cos(angle), hz + radius * math.sin(angle))
        else:
            p = random_point(rng)
        inst = make_instance("PA_HillBoulder", p[0], p[1], rng.uniform(0.0, 360.0), rng.uniform(*spec["scale"]),
                             id=ids.next("PA_HillBoulder"))
        if placer.valid(inst):
            placer.add(inst)
            boulders.append(inst)
        else:
            ids.undo("PA_HillBoulder")
    return boulders


def place_rings(placer, ids, rng):
    target, spec = dict(MIX)["PA_MushroomRing"], PROPS["PA_MushroomRing"]
    rings, attempts = [], 0
    while len(rings) < target:
        attempts += 1
        assert attempts < 60000, "could not place every mushroom ring"
        p = random_point(rng)
        inst = make_instance("PA_MushroomRing", p[0], p[1], rng.uniform(0.0, 360.0), rng.uniform(*spec["scale"]),
                             id=ids.next("PA_MushroomRing"))
        if placer.valid(inst):
            placer.add(inst)
            rings.append(inst)
        else:
            ids.undo("PA_MushroomRing")
    return rings


def place_flowers(placer, ids, rng):
    """Puff flowers in patches: most beside the path, a quarter inside her ground so Pelusa has a risky side."""
    target, spec = dict(MIX)["PA_PuffFlower"], PROPS["PA_PuffFlower"]
    flowers, patches = [], []
    per_patch = target // FLOWER_PATCHES
    min_tormenta = 6

    def try_flower(centre):
        angle, radius = rng.uniform(0.0, math.tau), rng.uniform(0.0, 9.0)
        inst = make_instance("PA_PuffFlower", centre[0] + radius * math.cos(angle), centre[1] + radius * math.sin(angle),
                             rng.uniform(0.0, 360.0), rng.uniform(*spec["scale"]), id=ids.next("PA_PuffFlower"))
        if placer.valid(inst):
            placer.add(inst)
            flowers.append(inst)
            return True
        ids.undo("PA_PuffFlower")
        return False

    def fill_patch(centre, want, kind):
        size = misses = 0
        while size < want and misses < 200 and len(flowers) < target:
            if try_flower(centre):
                size += 1
            else:
                misses += 1
        if size:
            patches.append({"size": size, "kind": kind})
        return size

    def route_centre():
        point, direction, _ = g.polyline_point(ROUTE, rng.uniform(0.0, ROUTE_LENGTH))
        lateral = rng.choice((-1, 1)) * rng.uniform(9.0, 26.0)
        return (point[0] - direction[1] * lateral, point[1] + direction[0] * lateral)

    def tormenta_centre():
        for _ in range(20000):
            p = random_point(rng)
            if zone(*p) != "tormenta" or in_pond(p, 12.0):
                continue
            if any(dist(p, (sx, sz)) < sr + 6.0 for sx, sz, sr in placer.sun):
                continue
            if any(dist(p, n) < NEST_RADIUS + 6.0 for n in placer.nests):
                continue
            return p
        raise AssertionError("no room for a Tormenta flower patch")

    def tormenta_count():
        return sum(1 for f in flowers if f["zone"] == "tormenta")

    for index in range(FLOWER_PATCHES):
        if index % 4 == 2:
            fill_patch(tormenta_centre(), per_patch, "tormenta")
        else:
            fill_patch(route_centre(), per_patch, "route")
    guard = 0
    while tormenta_count() < min_tormenta and len(flowers) < target:
        guard += 1
        assert guard < 200, "could not seed the Tormenta flower patches"
        fill_patch(tormenta_centre(), min_tormenta - tormenta_count(), "tormenta")
    while len(flowers) < target:
        guard += 1
        assert guard < 400, "could not place every puff flower"
        fill_patch(random_point(rng), target - len(flowers), "scatter")
    return flowers, [p["size"] for p in patches]


# ---- Biome event -------------------------------------------------------------------------
def abeja_event(instances, circles, nests):
    """La Colmena, La Abeja Reina's guard discs and the event clock, with the clearances the tests re-derive."""
    solids = [i for i in instances if i["name"] != "PA_PuffFlower"]
    egg = next(n for n in nests if n["eventOnly"])
    assert (egg["x"], egg["z"]) == HIVE, "the event nest must sit at La Colmena"
    nube_gap = dist(HIVE, HOME) - TORMENTA_RADIUS - ABEJA_LEASH
    sun_gap = min(dist(HIVE, (c["x"], c["z"])) - c["radius"] - ABEJA_LEASH for c in circles)
    route_gap = route_distance(HIVE) - CORRIDOR_HALF - ABEJA_LEASH
    clear = min(g.shape_point_dist(footprint(i), HIVE) for i in solids)
    assert nube_gap >= ABEJA_BEAST_GAP, "La Colmena overlaps la Nube's strike zone"
    assert sun_gap >= ABEJA_SUN_GAP, "La Colmena overlaps a sun circle"
    assert route_gap >= ABEJA_ROUTE_GAP, "La Colmena overlaps the path"
    assert clear >= HIVE_CLEAR, "a prop crowds the event egg"
    assert max(abs(HIVE[0]), abs(HIVE[1])) + ABEJA_LEASH <= LIMIT, "her leash leaves the sector"
    return {
        "name": "AbejaReina", "displayName": "La Abeja Reina", "event": "Huevo Real",
        "hive": [HIVE[0], HIVE[1]], "hive_world": [r3(HIVE[0] + WORLD_OFFSET[0]), r3(HIVE[1] + WORLD_OFFSET[1])],
        "egg_nest": egg["id"], "egg_species": egg["species"],
        "patrol_radius": ABEJA_PATROL_RADIUS, "guard_radius": ABEJA_GUARD_RADIUS, "leash": ABEJA_LEASH,
        "wake_radius": ABEJA_WAKE_RADIUS, "hive_clear": HIVE_CLEAR,
        "clock": {"first_seconds": EVENT_FIRST_SECONDS, "period_seconds": EVENT_PERIOD_SECONDS,
                  "window_seconds": EVENT_WINDOW_SECONDS, "awake": "only while the event egg is up"},
        "clearances": {"beyond_nube_strike_zone": r3(nube_gap), "beyond_sun_circles": r3(sun_gap),
                       "beyond_path_edge": r3(route_gap), "prop_clearance": r3(clear),
                       "gate_distance": r3(dist(HIVE, GATE)), "nube_home_distance": r3(dist(HIVE, HOME))},
        "tuning": dict(ABEJA_TUNING),
    }


# ---- Assembly ---------------------------------------------------------------------------
def roof_coverage(instances):
    grid = tormenta_grid()
    roofs = [i for i in instances if canopy(i) > 0.0]
    uncovered = [p for p in grid if not any(roof_covers(r, p) for r in roofs)]
    return {"grid_step": GRID_STEP, "points": len(grid), "uncovered": len(uncovered), "reach": ROOF_REACH}


def generate(seed=DEFAULT_SEED):
    rng = random.Random(seed)
    nests = plan_nests()
    nest_points = [(n["x"], n["z"]) for n in nests if not n["eventOnly"]]
    circles = plan_sun_circles(rng, nest_points)
    # The event nest at La Colmena is cleared like a wild nest, so the egg pedestal stands in an open glade.
    placer = Placer([(c["x"], c["z"], c["radius"]) for c in circles], nest_points + [HIVE])
    ids = IdSource()
    gate = place_gate(placer, ids)
    seta = place_seta_trueno(placer, ids)
    posts = place_posts(placer, ids, circles)
    pinwheels = place_pinwheels(placer, ids)
    mushrooms = place_mushrooms(placer, ids, rng)
    trees = place_trees(placer, ids, rng)
    boulders = place_boulders(placer, ids, rng)
    rings = place_rings(placer, ids, rng)
    flowers, patches = place_flowers(placer, ids, rng)
    instances = mushrooms + trees + rings + flowers + posts + boulders + gate + pinwheels + seta
    by_name, parts = {}, 0
    for name, count in MIX:
        found = [i for i in instances if i["name"] == name]
        assert len(found) == count, f"{name}: {len(found)} placed, {count} planned"
        by_name[name] = {"count": count, "parts": count * PROPS[name]["parts"]}
        parts += count * PROPS[name]["parts"]
    parts += sum(NEST_PARTS + ADULT_PARTS * n["adults"] for n in nests)
    parts += HILL_PARTS * len(HILLS) + BEAST_PARTS + SIGN_PARTS * 3 + 4  # floor, pond, path legs
    waypoints = [[r3(HOME[0] + BEAST_WAYPOINT_RADIUS * math.cos(math.tau * k / BEAST_WAYPOINTS)),
                  r3(HOME[1] + BEAST_WAYPOINT_RADIUS * math.sin(math.tau * k / BEAST_WAYPOINTS))]
                 for k in range(BEAST_WAYPOINTS)]
    tormenta_scales = [i["scale"] for i in mushrooms if i["zone"] == "tormenta"]
    prado_scales = [i["scale"] for i in mushrooms if i["zone"] == "prado"]
    return {
        "name": LAYOUT_NAME,
        "biome": {"displayName": "Pradera Arcoíris", "prefix": "PA_", "side": "east",
                  "beast": "La Nube Gruñona"},
        "status": "draft, unvalidated: never imported into Roblox, played or measured on a device",
        "seed": seed,
        "map_size": MAP_SIZE,
        "conventions": {"units": "studs, origin at the sector centre", "axes": "x east, z south",
                        "rotation_y_deg": "CFrame.Angles(0, math.rad(r), 0)",
                        "y": "height of the ground under the pivot above the flat floor (hills), 0 on flat ground"},
        "world": {"offset": [WORLD_OFFSET[0], WORLD_OFFSET[1]], "hub_centre": [0.0, 0.0],
                  "sector_x": [WORLD_OFFSET[0] - MAP_SIZE / 2, WORLD_OFFSET[0] + MAP_SIZE / 2],
                  "gate_world": [r3(GATE[0] + WORLD_OFFSET[0]), r3(GATE[1] + WORLD_OFFSET[1])],
                  "beast_home_world": [r3(HOME[0] + WORLD_OFFSET[0]), r3(HOME[1] + WORLD_OFFSET[1])]},
        "caps": {"instances": MAX_INSTANCES, "parts": MAX_PARTS},
        "totals": {"instances": len(instances), "parts_estimate": parts, "by_name": by_name,
                   "nests": len(nests), "sun_circles": len(circles), "hills": len(HILLS)},
        "route": {"nodes": [list(p) for p in ROUTE], "names": [n for n, _ in ROUTE_NODES],
                  "length": r3(ROUTE_LENGTH), "walk_seconds": r3(ROUTE_LENGTH / WALK_SPEED),
                  "corridor_width": 2 * CORRIDOR_HALF},
        "terrain": {
            "floor": {"size": MAP_SIZE, "material": "PA_Grass"},
            "hills": [{"id": hid, "x": hx, "z": hz, "sphere_radius": r, "cap_height": c,
                       "footprint_radius": r3(hill_footprint(r, c)), "slope_deg": r3(hill_slope_deg(r, c))}
                      for hid, hx, hz, r, c in HILLS],
            "pond": {"x": HOME[0], "z": HOME[1], "radius": POND_RADIUS, "material": "PA_Pond"},
            "path": {"nodes": [list(p) for p in ROUTE], "width": 2 * CORRIDOR_HALF, "material": "PA_Path"},
        },
        "zones": {"sol": {"gate": [GATE[0], GATE[1], GATE_SUN_RADIUS], "plaza": [PLAZA[0], PLAZA[1], SUN_RADIUS]},
                  "tormenta": {"centre": [HOME[0], HOME[1]], "radius": TORMENTA_RADIUS},
                  "bands": {"Legendaria": [0.0, LEGENDARIA_BAND], "Epica": [LEGENDARIA_BAND, EPICA_BAND],
                            "Rara": [EPICA_BAND, RARA_BAND], "Comun": [RARA_BAND, None]}},
        "beast": {"name": "NubeGrunona", "displayName": "La Nube Gruñona", "home": [HOME[0], HOME[1]],
                  "hover_height": 10.0, "leash": BEAST_LEASH, "strike_zone_radius": TORMENTA_RADIUS,
                  "waypoints": waypoints, "seta_trueno": [SETA_TRUENO[0], SETA_TRUENO[1]],
                  "gate_distance": r3(dist(HOME, GATE))},
        "nests": nests,
        "sun_circles": circles,
        "abeja_event": abeja_event(instances, circles, nests),
        "roof_coverage": roof_coverage(instances),
        "density": {"mushroom_scale_mean": {"tormenta": r3(sum(tormenta_scales) / len(tormenta_scales)),
                                            "prado": r3(sum(prado_scales) / len(prado_scales))},
                    "flower_patches": patches,
                    "props_per_1000_sq_studs": round(len(instances) / (MAP_SIZE * MAP_SIZE / 1000.0), 3)},
        "instances": instances,
    }


def to_json(layout):
    return json.dumps(layout, indent=1, ensure_ascii=False) + "\n"


# ---- Drawing ----------------------------------------------------------------------------
CANVAS = (1240, 900)
MAP_X0, MAP_Y0, MAP_SCALE = 30.0, 70.0, 2.0
CAP_FILL = {"Coral": "#f28b9b", "Sky": "#8fd3f4", "Butter": "#f9e27a"}


def build_scene(layout):
    scene = render.Scene(*CANVAS)
    world = render.World(MAP_SCALE, MAP_X0, MAP_Y0, MAP_SIZE / 2)
    s = MAP_SCALE
    scene.text(MAP_X0, 34, "Pradera Arcoiris placement plan v1 - DRAFT, unvalidated - top-down", size=22, bold=True)
    scene.text(MAP_X0, 54, "seed %d | 400 x 400 studs | hub is west (left) | symbols enlarged" % layout["seed"],
               size=13, fill="#444444")
    scene.rect(world.px(-200), world.py(-200), 400 * s, 400 * s, fill="#a8e6b0", stroke="#222222", sw=2)
    for v in range(-200, 201, 50):
        scene.line([(world.px(v), world.py(-200)), (world.px(v), world.py(200))], stroke="#000000", sw=0.8, so=0.10)
        scene.line([(world.px(-200), world.py(v)), (world.px(200), world.py(v))], stroke="#000000", sw=0.8, so=0.10)
        scene.text(world.px(v), world.py(200) + 18, str(v), size=11, fill="#555555", anchor="middle")
        scene.text(world.px(-200) - 6, world.py(v) + 4, str(v), size=11, fill="#555555", anchor="end")
    for hill in layout["terrain"]["hills"]:
        scene.circle(world.px(hill["x"]), world.py(hill["z"]), hill["footprint_radius"] * s, fill="#d9c8f0", fo=0.8)
        scene.circle(world.px(hill["x"]), world.py(hill["z"]), hill["footprint_radius"] * s * 0.55, fill="#bfeec4")
    scene.circle(world.px(HOME[0]), world.py(HOME[1]), TORMENTA_RADIUS * s, fill="#8c7fb0", fo=0.12,
                 stroke="#6b5e94", sw=1.2, dash=(6, 5))
    ev = layout["abeja_event"]
    scene.circle(world.px(ev["hive"][0]), world.py(ev["hive"][1]), ev["leash"] * s, fill="#f2a33a", fo=0.10,
                 stroke="#b8793a", sw=1.0, dash=(3, 4))
    scene.circle(world.px(ev["hive"][0]), world.py(ev["hive"][1]), ev["guard_radius"] * s, fill="#f2a33a", fo=0.18,
                 stroke="#b8793a", sw=1.4, dash=(6, 5))
    scene.text(world.px(ev["hive"][0]), world.py(ev["hive"][1]) + ev["leash"] * s + 14, "La Colmena (event only)",
               size=12, bold=True, fill="#7a4a12", anchor="middle")
    pond = layout["terrain"]["pond"]
    scene.circle(world.px(pond["x"]), world.py(pond["z"]), pond["radius"] * s, fill="#b9b3cf", stroke="#6b5e94", sw=1)
    scene.line([world.pt(p) for p in ROUTE], stroke="#f5e6c8", sw=2 * CORRIDOR_HALF * s, so=0.95)
    scene.line([world.pt(p) for p in ROUTE], stroke="#b89a60", sw=1.2, dash=(8, 6))
    by = {name: [i for i in layout["instances"] if i["name"] == name] for name, _ in MIX}
    for m in by["PA_GiantMushroom"]:
        scene.circle(world.px(m["x"]), world.py(m["z"]), PROPS["PA_GiantMushroom"]["cap_r"] * m["scale"] * s,
                     fill=CAP_FILL[m["cap"]], fo=0.75, stroke="#333333", sw=0.6)
    for t in by["PA_PuffTree"]:
        scene.circle(world.px(t["x"]), world.py(t["z"]), PROPS["PA_PuffTree"]["crown_r"] * t["scale"] * s,
                     fill=CAP_FILL[t["puff"]], fo=0.6, stroke="#5a4634", sw=0.8)
    for f in by["PA_PuffFlower"]:
        scene.circle(world.px(f["x"]), world.py(f["z"]), 3.0, fill="#ffffff", stroke="#6fbf8a", sw=0.8)
    for b in by["PA_HillBoulder"]:
        scene.circle(world.px(b["x"]), world.py(b["z"]), PROPS["PA_HillBoulder"]["r"] * b["scale"] * s,
                     fill="#c2b3e0", stroke="#333333", sw=0.8)
    for r in by["PA_MushroomRing"]:
        scene.circle(world.px(r["x"]), world.py(r["z"]), PROPS["PA_MushroomRing"]["r"] * r["scale"] * s,
                     fill=None, stroke="#e0607a", sw=1.4)
    for pw in by["PA_Pinwheel"]:
        scene.rect(world.px(pw["x"]) - 3, world.py(pw["z"]) - 3, 6, 6, fill="#ff8c69", stroke="#333333", sw=0.6)
    for c in layout["sun_circles"]:
        scene.circle(world.px(c["x"]), world.py(c["z"]), c["radius"] * s, fill="#ffd23f", fo=0.35,
                     stroke="#c9a200", sw=1.6 if c["permanent"] else 1.0, dash=None if c["permanent"] else (4, 4))
    for p in by["PA_SunflowerPost"]:
        scene.circle(world.px(p["x"]), world.py(p["z"]), 2.2, fill="#f9e27a", stroke="#5a4634", sw=0.6)
    for n in layout["nests"]:
        scene.circle(world.px(n["x"]), world.py(n["z"]), n["radius"] * s, fill="#ffffff", fo=0.7,
                     stroke="#e0607a" if n["eventOnly"] else "#2b6cb0", sw=1.6)
        scene.text(world.px(n["x"]), world.py(n["z"]) - n["radius"] * s - 4, "%s (%s)" % (n["displayName"], n["rarity"]),
                   size=11, bold=True, fill="#1d2530", anchor="middle")
    seta = by["PA_SetaTrueno"][0]
    scene.circle(world.px(seta["x"]), world.py(seta["z"]), PROPS["PA_SetaTrueno"]["cap_r"] * s, fill="#f28b9b",
                 fo=0.85, stroke="#111111", sw=1.4)
    gate = by["PA_RainbowGate"][0]
    scene.poly([world.pt(p) for p in footprint(gate).pts], fill="#ff8c69", fo=0.8, stroke="#111111", sw=1.4)
    scene.circle(world.px(HOME[0]), world.py(HOME[1]), 6, fill="#8c7fb0", stroke="#111111", sw=1.4)
    for wp in layout["beast"]["waypoints"]:
        scene.circle(world.px(wp[0]), world.py(wp[1]), 2.5, fill="#ffffff", stroke="#6b5e94", sw=0.8)
    for name, (x, z) in ROUTE_NODES:
        scene.circle(world.px(x), world.py(z), 5, fill="#ffffff", stroke="#3a2f12", sw=2)
        scene.text(world.px(x) + 10, world.py(z) - 10, name, size=12, bold=True, fill="#3a2f12")
    x0, y = 880.0, 100.0
    t = layout["totals"]
    scene.text(x0, y, "Legend", size=17, bold=True)
    rows = [("Cream path 14 wide, hub gate at the left", "#f5e6c8"), ("Giant mushroom cap = roof (3 colours)", "#f28b9b"),
            ("Puff tree crown = roof", "#8fd3f4"), ("Sun circle (solid permanent, dashed candidate)", "#ffd23f"),
            ("La Nube's pond and strike zone (dashed)", "#b9b3cf"),
            ("La Abeja's guard and leash at La Colmena (event)", "#f2a33a"), ("Hill (lavender shoulder, grass top)", "#d9c8f0"),
            ("Nest with sleeping parents / event nest", "#2b6cb0"), ("Puff flower (Pelusa)", "#ffffff"),
            ("Pinwheel", "#ff8c69"), ("Boulder", "#c2b3e0"), ("Mushroom ring", "#e0607a")]
    for label, colour in rows:
        y += 24
        scene.rect(x0, y - 12, 22, 14, fill=colour, stroke="#333333", sw=0.8)
        scene.text(x0 + 32, y, label, size=13)
    y += 40
    scene.text(x0, y, "Budget (draft)", size=17, bold=True)
    cov = layout["roof_coverage"]
    for line in ["Instances %d / %d cap" % (t["instances"], MAX_INSTANCES),
                 "Luau parts about %d / %d cap" % (t["parts_estimate"], MAX_PARTS),
                 "Route %.0f studs, %.0f s at 16 studs/s" % (layout["route"]["length"], layout["route"]["walk_seconds"]),
                 "Tormenta roof check: %d of %d grid points uncovered" % (cov["uncovered"], cov["points"]),
                 "Gate to pond %.0f studs; her leash %.0f" % (layout["beast"]["gate_distance"], BEAST_LEASH)]:
        y += 22
        scene.text(x0, y, line, size=13)
    y += 40
    scene.text(x0, y, "Counts", size=17, bold=True)
    for name, entry in t["by_name"].items():
        y += 22
        scene.text(x0, y, "%s  x%d (%d parts)" % (name, entry["count"], entry["parts"]), size=13)
    y += 40
    for line in ["Draft for the east biome. Never imported into Roblox,", "played or measured on a phone."]:
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
    lines = ["seed %d: %d instances (cap %d), about %d Luau parts (cap %d), %d nests, %d sun circles, %d hills"
             % (layout["seed"], t["instances"], MAX_INSTANCES, t["parts_estimate"], MAX_PARTS, t["nests"],
                t["sun_circles"], t["hills"])]
    lines += ["  %-18s x%-3d %5d parts" % (k, v["count"], v["parts"]) for k, v in t["by_name"].items()]
    cov = layout["roof_coverage"]
    lines.append("route %.0f studs (%.1f s), Tormenta roof check %d/%d uncovered, mushroom scale tormenta %.2f vs prado %.2f"
                 % (layout["route"]["length"], layout["route"]["walk_seconds"], cov["uncovered"], cov["points"],
                    layout["density"]["mushroom_scale_mean"]["tormenta"], layout["density"]["mushroom_scale_mean"]["prado"]))
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

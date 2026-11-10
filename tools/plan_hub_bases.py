#!/usr/bin/env python3
"""Reproducible plan for Wildbound's central social hub with eight personal bases (DESIGN, unvalidated).

The master prompt (docs/design/wildbound-combined-plan.md sections 1 and 2) asks for a safe central lobby with
personal bases for up to 8 players around it. Each base is recognisable (a name sign and a colour) and holds an egg
delivery station, an incubator, a Lumipol collection display, a glove station and a training station. Physical exits
lead from the lobby to the forest (several, so nobody can block one), and there is no PvP and no beast inside.

This tool writes `assets/maps/hub-layout/hub-bases-v1.json` (or `hub-bases-v2.json` with `--variant v2`) only. It
never touches Studio. The parts-only Luau builder is rendered from the JSON by `tools/build-hub-map.py`. Python
standard library only.

    python -I -B tools/plan_hub_bases.py                   # writes the v1 JSON (what Studio builds today)
    python -I -B tools/plan_hub_bases.py --variant v2      # writes the hub expansion JSON
    python -I -B tools/plan_hub_bases.py --check           # exit 1 when the written JSON is stale

Frame: the open-world hub frame of `assets/maps/open-world/layout-v1.json` (studs, origin at the hub centre, x east,
z south). `rotation_y_deg` is CFrame.Angles(0, math.rad(r), 0): local +X maps to (cos r, -sin r) and local +Z to
(sin r, cos r) in (x, z) (tools/layout_geometry.py). A piece's Front face (local -Z) is the side it faces. A bearing
b places a point at centre + radius * (cos b, sin b): 0 is east, 90 south, 180 west, 270 north.

Why the hub grows from radius 60 to 90 (v1): layout-v1 drew a radius-60 hub with shared stations. Eight 26 x 22 bases
plus a lobby do not fit inside 60 (the ring of bases alone needs about 81 studs of radius). The band no beast reaches
runs from x -200 to x 340, and the region squares start at x -100 and x 100, so a 90-stud safe disc stays inside the
band and outside both regions. This is decision HB1 for the user (docs/maps/wildbound-hub.md).

v2 (docs/design/wildbound-hub-expansion.md): radius 100, the most layout-v1's region squares allow; bigger bases with
a chest zone and an incubator for two eggs; a showcase in front of each base; four shop circles on the lawn ring;
more and brighter warm lamps and a hub ambience block for the client. Every number is a variant parameter below
(`VARIANTS`), so the Studio writer applies one variant as a whole.
"""

import argparse
import json
import math
import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import layout_geometry as g  # noqa: E402
import plan_open_world_layout as ow  # noqa: E402

REPO = TOOLS.parent
LAYOUT_NAME = "hub-bases-v1"
DEFAULT_SEED = 20261110  # no randomness is used; the seed only labels the plan and the builder header
OPEN_WORLD = REPO / "assets" / "maps" / "open-world" / "layout-v1.json"
OUT_DIR = REPO / "assets" / "maps" / "hub-layout"
DEFAULT_OUT = OUT_DIR / "hub-bases-v1.json"

# ---- Hub (v1 values; v2 overrides them in VARIANTS) -----------------------------------------------------------
FLOOR_TOP = 0.5          # the floor part is 1 stud thick, centred at y 0
HUB_SAFE_RADIUS = 90.0   # the WildboundHubSafeZone disc and the radius Rules.zone should use
WALL_RADIUS = 88.0       # hedge centreline
WALL_THICK, WALL_HEIGHT = 2.0, 4.0
FLOOR_RADIUS = 92.0
PLAZA_RADIUS = 30.0
PROMENADE_RADIUS, PROMENADE_WIDTH, PROMENADE_SEGMENTS = 50.0, 8.0, 16
CAMPFIRE_RADIUS = 3.5
HEDGE_MAX_SPAN_DEG = 12.0
GATE_WIDTH, PATH_WIDTH, TRAIL_WIDTH = 16.0, 12.0, 14.0
MAX_PLAYERS = 8
WALK_SPEED = 16.0        # studs/s, the walk speed since HF-T4 (WildboundTraining.WALK_CAP)

# ---- Bases -----------------------------------------------------------------------------------------------------
BASE_RING = 68.0
BASE_WIDTH, BASE_DEPTH = 26.0, 22.0      # pad, local X (tangential) by local Z (radial)
RIM = 0.6                                # coloured rim around the pad
PAD_TOP = 0.9
ENTRANCE_WIDTH = 8.0                     # gap in the front fence, facing the lobby
FENCE_HEIGHT, FENCE_THICK = 2.5, 0.5
STATION_MARGIN = 1.0                     # every station footprint stays this far inside the pad
STATION_GAP = 2.0
BASE_PATH_CLEAR = 2.0                    # base rim to the edge of a gate path
BASE_BEARINGS = tuple(22.5 + 45.0 * k for k in range(MAX_PLAYERS))
# Spanish colour names are in-game strings. Saturated, kid-readable, pairwise far apart in RGB.
BASE_COLOURS = (
    ("Rojo", "E5484D"), ("Naranja", "F2913D"), ("Amarillo", "F5D547"), ("Verde", "5CC46A"),
    ("Turquesa", "3FC1C9"), ("Azul", "4F7FE0"), ("Morado", "9B6BDB"), ("Rosa", "EE7DB8"),
)
SIGN_TEXT = "Base de <jugador>"          # placeholder; the server writes the owner's name (docs/maps/wildbound-hub.md)

# kind, CollectionService tag, Spanish label, local (lx, lz), footprint
STATIONS = (
    ("delivery", "WildboundDeliveryStation", "Entrega de huevos", (0.0, -4.5), ("circle", 2.5)),
    ("training", "WildboundTrainingStation", "Entrenamiento", (8.0, -4.5), ("rect", 2.0, 3.75)),
    ("glove", "WildboundGloveStation", "Guantes", (-8.0, -5.0), ("rect", 2.5, 1.5)),
    ("incubator", "WildboundIncubatorStation", "Incubadora", (-7.0, 4.5), ("circle", 3.0)),
    ("display", "WildboundCollectionDisplay", "Colección de Lumipols", (6.5, 5.0), ("rect", 4.5, 3.5)),
)
DISPLAY_SLOTS = 3
TREADMILL_BELT = 6.4                     # belt length along local Z

# ---- Entrances: id, bearing, leads, Spanish sign, join point, layout-v1 connector it joins -----------------------
ENTRANCES = (
    ("E", 0.0, "pradera", "Pradera Arcoíris", (105.0, 0.0), "umbral_este"),
    ("S", 90.0, "ring", "Camino del anillo", (0.0, 100.0), "espolon_sur"),
    ("SW", 135.0, "forest", "Al bosque: sendero sur", (-112.0, 90.0), None),
    ("W", 180.0, "forest", "Bosque de la Silueta", (-100.0, 20.0), "umbral_oeste"),
    ("NW", 225.0, "forest", "Al bosque: sendero norte", (-112.0, -90.0), None),
    ("N", 270.0, "ring", "Camino del anillo", (0.0, -100.0), "espolon_norte"),
)

# ---- Lobby decoration ------------------------------------------------------------------------------------------
SPAWN_PAD_RADIUS, SPAWN_PAD_SIZE = 16.0, 6.0
SPAWN_BEARINGS = (0.0, 90.0, 180.0, 270.0)
BENCH_RADIUS, BENCH_BEARINGS, BENCH_LENGTH = 9.0, (45.0, 135.0, 225.0, 315.0), 5.0
PLAZA_LANTERN_RADIUS = 25.0
FLOWER_RADIUS = 40.0
PLANTER_RADIUS, PLANTER_BEARINGS = 70.0, (45.0, 315.0)
RULES_SIGN = {"key": "hubRules", "text": "Plaza segura\nSin peleas ni bestias", "centre": (24.0, -7.0), "yaw": 90.0,
              "width": 6.0}

# ---- Light budget ----------------------------------------------------------------------------------------------
CAMP_LIGHT = (255, 176, 96)              # the camp's warm, shadowless light (aesthetic reference 3.6)
LANTERN_LIGHT = (255, 165, 85)
LIGHTS = {"campfire": (1.6, 30.0), "plaza": (0.9, 16.0), "gate": (0.8, 14.0), "base": (0.8, 14.0)}
PARTS_CAP, LIGHTS_CAP = 400, 20          # open-world doc section 10: the hub is always loaded, keep it under 400 parts

# ---- Checks ----------------------------------------------------------------------------------------------------
BEAST_MARGIN = 10.0                      # as the Refugio rule: beyond every beast's reach by this
FOREST_CLEAR = 10.0                      # a forest prop this close to a new trail centreline is removed
HOOK_CLEAR = 20.0

# ---- v2 expansion (docs/design/wildbound-hub-expansion.md) --------------------------------------------------------
SHOWCASE_LIGHT = (255, 214, 150)         # a paler warm white so the creature's own colours read
STATIONS_V2 = (
    ("delivery", "WildboundDeliveryStation", "Entrega de huevos", (0.0, -5.0), ("circle", 2.5)),
    ("training", "WildboundTrainingStation", "Entrenamiento", (9.0, -5.0), ("rect", 2.0, 3.75)),
    ("glove", "WildboundGloveStation", "Guantes", (-9.0, -5.5), ("rect", 2.5, 1.5)),
    ("incubator", "WildboundIncubatorStation", "Incubadora", (-8.0, 5.0), ("circle", 3.0)),
    ("display", "WildboundCollectionDisplay", "Colección de Lumipols", (9.0, 5.5), ("rect", 4.5, 3.5)),
)
# id, Spanish label, bearing, ring colour, what it sells (ids in the economy-tuning block, Esencia only)
SHOPS_V2 = (
    ("taller", "Taller de guantes", 45.0, "F2C14E", {"gear": ["guantes"]}),
    ("mejoras", "Mejoras", 157.5, "6FCF97", {"upgrades": ["farolTapado", "reinforcedPack"]}),
    ("suministros", "Suministros", 202.5, "56CCF2", {"recipes": ["seal", "capsule", "totem"], "gear": ["totemSuerte"]}),
    ("arbol", "Árbol de habilidades", 315.0, "BB86FC",
     {"skills": ["explorer_1", "explorer_2", "capturer_1", "capturer_2", "survivor_1", "survivor_2", "occultist_1",
                 "occultist_2"]}),
)
SHOP_V2 = {"ring_radius": 41.0, "trigger": 4.0, "close": 5.5, "server_range": 6.0, "stall_radius": 47.0,
           "stall_half": (3.0, 1.0)}
CHEST_V2 = {"local": (0.0, 7.5), "trigger": 2.0, "close": 3.0, "server_range": 3.5, "prop_local": (0.0, 10.3),
            "prop_half": (1.2, 0.7), "label": "Cofre del explorador"}
SHOWCASE_V2 = {"lx": 9.0, "gap": 1.0, "r": 2.0, "slots": 1, "hover": 3.5, "text": "Vitrina de <jugador>"}
BANK_ZONE_V2 = {"exit_margin": 2.0, "height": 12.0}
LIGHTING_V2 = {
    "zone": "hub", "blend_studs": 20.0,
    "atmosphere": {
        "Day": {"density": 0.42, "offset": 0.08, "haze": 1.4, "fogStart": 60.0, "fogEnd": 380.0, "color": [214, 196, 168]},
        "Dusk": {"density": 0.5, "offset": 0.05, "haze": 2.0, "fogStart": 40.0, "fogEnd": 260.0, "color": [206, 170, 130]},
        "Night": {"density": 0.56, "offset": 0.02, "haze": 2.6, "fogStart": 30.0, "fogEnd": 180.0,
                  "color": [150, 118, 90]},
    },
    "ambient": {"Day": [120, 110, 96], "Dusk": [110, 96, 80], "Night": [96, 80, 64]},
    "tint": {"brightness": 0.05, "contrast": 0.05, "saturation": 0.1, "color": [255, 240, 220]},
    "night_lamp_scale": 1.25,
    "note": "client-only: WildboundAtmosphere gains a 'hub' zone row; inside inside_radius the world client blends to "
            "it over blend_studs, so the forest outside stays dark; PointLights stay shadowless",
}
REFUGIO_SEARCH = {"step": 5.0, "reach": 80.0}


def _variant(**over):
    base = {
        "name": LAYOUT_NAME, "safe_radius": HUB_SAFE_RADIUS, "wall_radius": WALL_RADIUS, "floor_radius": FLOOR_RADIUS,
        "plaza_radius": PLAZA_RADIUS, "promenade": (PROMENADE_RADIUS, PROMENADE_WIDTH, PROMENADE_SEGMENTS),
        "base_ring": BASE_RING, "base_size": (BASE_WIDTH, BASE_DEPTH), "stations": STATIONS, "incubator_slots": None,
        "sign_lx": -8.5, "lantern_local": (-11.3, 9.3), "entrances": ENTRANCES,
        "plaza_lanterns": (PLAZA_LANTERN_RADIUS, BENCH_BEARINGS), "flowers": True,
        "planters": (PLANTER_RADIUS, PLANTER_BEARINGS), "rules_sign": RULES_SIGN, "lights": LIGHTS,
        "budget": (PARTS_CAP, LIGHTS_CAP, None), "expansion": False,
    }
    base.update(over)
    return base


VARIANTS = {
    "v1": _variant(),
    "v2": _variant(
        name="hub-bases-v2", safe_radius=100.0, wall_radius=98.0, floor_radius=102.0, plaza_radius=34.0,
        promenade=(54.0, 8.0, 20), base_ring=77.0, base_size=(29.0, 24.0), stations=STATIONS_V2, incubator_slots=2,
        sign_lx=-9.0, lantern_local=(-12.5, 10.0),
        entrances=tuple((i, b, leads, sign, (0.0, 110.0) if i == "S" else (0.0, -110.0) if i == "N" else join, c)
                        for i, b, leads, sign, join, c in ENTRANCES),
        plaza_lanterns=(30.0, tuple(22.5 + 45.0 * k for k in range(8))), flowers=False, planters=(72.0, (45.0, 315.0)),
        rules_sign=dict(RULES_SIGN, centre=(26.0, -6.0)),
        lights={"campfire": (2.0, 30.0), "plaza": (1.1, 18.0), "gate": (1.0, 16.0), "base": (1.0, 16.0),
                "showcase": (0.9, 12.0), "shop": (1.0, 14.0)},
        budget=(480, 36, "the hub is always loaded (ModelStreamingMode Persistent); 480 parts and 36 shadowless "
                         "PointLights raise layout-v1's cap of 400 parts on purpose and are unmeasured: record frame "
                         "time on a phone with 8 players before accepting"),
        expansion=True),
}


def out_path(variant):
    return OUT_DIR / (VARIANTS[variant]["name"] + ".json")


def r3(value):
    return round(value, 3) + 0.0


def polar(radius, bearing):
    a = math.radians(bearing)
    return (r3(radius * math.cos(a)), r3(radius * math.sin(a)))


def outward_yaw(bearing):
    """Yaw whose local +Z points away from the hub centre, so the Front face (local -Z) faces the lobby."""
    a = math.radians(bearing)
    return r3(g.heading_deg(math.cos(a), math.sin(a)))


def to_world(centre, yaw, local):
    ex, ez = g.local_axes(yaw)
    return (r3(centre[0] + local[0] * ex[0] + local[1] * ez[0]), r3(centre[1] + local[0] * ex[1] + local[1] * ez[1]))


def footprint_json(fp, yaw):
    if fp[0] == "circle":
        return {"kind": "circle", "r": fp[1]}
    return {"kind": "rect", "half": [fp[1], fp[2]], "yaw": yaw}


def shape_of(centre, footprint):
    """layout_geometry shape for a saved footprint at a world centre."""
    if footprint["kind"] == "circle":
        return g.Circle(centre[0], centre[1], footprint["r"])
    hx, hz = footprint["half"]
    return g.rect_poly(centre[0], centre[1], hx, hz, footprint.get("yaw", 0.0))


def segment_json(a, b, width):
    """A straight paved piece from a to b: centre, yaw (local +Z along a->b) and length."""
    length = math.dist(a, b)
    return {"from": [r3(a[0]), r3(a[1])], "to": [r3(b[0]), r3(b[1])], "width": width, "length": r3(length),
            "centre": [r3((a[0] + b[0]) / 2), r3((a[1] + b[1]) / 2)],
            "yaw": r3(g.heading_deg(b[0] - a[0], b[1] - a[1]))}


def colour_rgb(hex_value):
    return tuple(int(hex_value[i:i + 2], 16) for i in (0, 2, 4))


# ---- Pieces ----------------------------------------------------------------------------------------------------
def make_base(slot, bearing, colour, v=None):
    v = v or VARIANTS["v1"]
    centre = polar(v["base_ring"], bearing)
    yaw = outward_yaw(bearing)
    hx, hz = v["base_size"][0] / 2, v["base_size"][1] / 2
    prom_radius, prom_width, _ = v["promenade"]
    stations = []
    for kind, tag, label, local, fp in v["stations"]:
        station = {"kind": kind, "tag": tag, "label": label, "local": list(local),
                   "world": list(to_world(centre, yaw, local)), "yaw": yaw, "footprint": footprint_json(fp, yaw)}
        if kind == "incubator" and v["incubator_slots"]:
            station["slots"] = v["incubator_slots"]
        stations.append(station)
    gap = ENTRANCE_WIDTH / 2
    stub = (hx - gap) / 2
    fences = [
        {"id": "back", "local": [0.0, hz - FENCE_THICK / 2], "half": [hx, FENCE_THICK / 2]},
        {"id": "left", "local": [-(hx - FENCE_THICK / 2), 0.0], "half": [FENCE_THICK / 2, hz]},
        {"id": "right", "local": [hx - FENCE_THICK / 2, 0.0], "half": [FENCE_THICK / 2, hz]},
        {"id": "frontLeft", "local": [-(gap + stub), -(hz - FENCE_THICK / 2)], "half": [stub, FENCE_THICK / 2]},
        {"id": "frontRight", "local": [gap + stub, -(hz - FENCE_THICK / 2)], "half": [stub, FENCE_THICK / 2]},
    ]
    for fence in fences:
        fence["world"] = list(to_world(centre, yaw, fence["local"]))
        fence["yaw"] = yaw
    walk_depth = v["base_ring"] - hz - (prom_radius + prom_width / 2) + 0.4
    walk_local = (0.0, -(hz + walk_depth / 2 - 0.2))
    sign_local = (v["sign_lx"], -(hz - FENCE_THICK / 2))
    lantern_local = v["lantern_local"]
    base = {
        "slot": slot, "id": "base-%d" % slot, "bearing": bearing, "centre": list(centre), "yaw": yaw,
        "faces": "lobby",
        "colour": {"name": colour[0], "hex": colour[1]},
        "pad": {"half": [hx, hz], "rim": RIM, "top": PAD_TOP},
        "bounds": {"kind": "rect", "half": [hx + RIM, hz + RIM], "yaw": yaw},
        "entrance": {"local": [0.0, -hz], "world": list(to_world(centre, yaw, (0.0, -hz))), "width": ENTRANCE_WIDTH},
        "walk": {"local": [0.0, r3(walk_local[1])], "world": list(to_world(centre, yaw, walk_local)),
                 "half": [3.0, r3(walk_depth / 2)], "yaw": yaw},
        "fences": fences,
        "fence": {"height": FENCE_HEIGHT, "thick": FENCE_THICK},
        "sign": {"key": "base%d" % slot, "text": SIGN_TEXT, "local": list(sign_local),
                 "world": list(to_world(centre, yaw, sign_local)), "yaw": yaw, "width": 6.0},
        "lantern": {"local": list(lantern_local), "world": list(to_world(centre, yaw, lantern_local)), "r": 0.5},
        "stations": stations,
        "display_slots": DISPLAY_SLOTS,
        "treadmill_belt": TREADMILL_BELT,
    }
    if v["expansion"]:
        add_expansion_to_base(base, centre, yaw, hx, hz)
    return base


def add_expansion_to_base(base, centre, yaw, hx, hz):
    c = CHEST_V2
    base["chest"] = {"kind": "chest", "tag": "WildboundChestStation", "label": c["label"], "local": list(c["local"]),
                     "world": list(to_world(centre, yaw, c["local"])), "yaw": yaw, "trigger_radius": c["trigger"],
                     "close_radius": c["close"], "server_range": c["server_range"],
                     "prop": {"local": list(c["prop_local"]), "world": list(to_world(centre, yaw, c["prop_local"])),
                              "half": list(c["prop_half"]), "yaw": yaw}}
    s = SHOWCASE_V2
    local = (s["lx"], -(hz + RIM + s["gap"] + s["r"]))
    base["showcase"] = {"tag": "WildboundShowcase", "local": [s["lx"], r3(local[1])],
                        "world": list(to_world(centre, yaw, local)), "yaw": yaw, "r": s["r"], "slots": s["slots"],
                        "hover": s["hover"], "sign": {"key": "showcase%d" % base["slot"], "text": s["text"]}}
    base["bank_zone"] = {"tag": "WildboundBaseZone", "kind": "rect", "centre": list(centre), "yaw": yaw,
                         "half": [hx + RIM, hz + RIM], "exit_margin": BANK_ZONE_V2["exit_margin"],
                         "height": BANK_ZONE_V2["height"]}


def make_entrances(v=None):
    v = v or VARIANTS["v1"]
    out = []
    for ident, bearing, leads, sign, join, connector in v["entrances"]:
        gate = polar(v["wall_radius"], bearing)
        path = segment_json(polar(v["plaza_radius"] - 1.0, bearing), polar(v["wall_radius"] + 1.0, bearing), PATH_WIDTH)
        trail = segment_json(polar(v["wall_radius"] + 1.0, bearing), join, TRAIL_WIDTH)
        out.append({"id": ident, "bearing": bearing, "gate": list(gate), "width": GATE_WIDTH, "leads": leads,
                    "sign": sign, "yaw": outward_yaw(bearing), "path": path, "trail": trail,
                    "joins": connector or "forest_floor"})
    return out


def gate_half_angle(wall_radius=WALL_RADIUS):
    """Angular half width of a gate gap; the hedge stops 0.6 studs past the gate edge so chords never narrow it."""
    return math.degrees(math.asin((GATE_WIDTH / 2 + 0.6) / wall_radius))


def make_hedge(entrances, wall_radius=WALL_RADIUS):
    """Straight hedge chords on the wall circle between consecutive gates."""
    bearings = sorted(e["bearing"] for e in entrances)
    half = gate_half_angle(wall_radius)
    segments = []
    for index, start in enumerate(bearings):
        end = bearings[(index + 1) % len(bearings)] + (360.0 if index == len(bearings) - 1 else 0.0)
        a0, a1 = start + half, end - half
        count = max(1, math.ceil((a1 - a0) / HEDGE_MAX_SPAN_DEG))
        step = (a1 - a0) / count
        for k in range(count):
            p = polar(wall_radius, a0 + step * k)
            q = polar(wall_radius, a0 + step * (k + 1))
            mid = (a0 + step * (k + 0.5)) % 360.0
            segments.append({"centre": [r3((p[0] + q[0]) / 2), r3((p[1] + q[1]) / 2)], "length": r3(math.dist(p, q) + 0.6),
                             "yaw": outward_yaw(mid), "bearing": r3(mid)})
    return segments


def make_promenade(v=None):
    radius, _, segments = (v or VARIANTS["v1"])["promenade"]
    half = 180.0 / segments
    pieces = []
    for k in range(segments):
        mid = 360.0 * k / segments
        centre = polar(radius * math.cos(math.radians(half)), mid)
        chord = 2 * radius * math.sin(math.radians(half))
        pieces.append({"centre": list(centre), "length": r3(chord + 1.0), "yaw": outward_yaw(mid)})
    return pieces


def make_lobby(v=None):
    v = v or VARIANTS["v1"]
    stones = [{"centre": list(polar(CAMPFIRE_RADIUS, 60.0 * k + 30.0))} for k in range(6)]
    spawn = [{"id": "spawn-%d" % (i + 1), "centre": list(polar(SPAWN_PAD_RADIUS, b)), "size": SPAWN_PAD_SIZE,
              "faces": "east", "yaw": 270.0} for i, b in enumerate(SPAWN_BEARINGS)]
    rules = v["rules_sign"]
    return {
        "plaza_radius": v["plaza_radius"],
        "campfire": {"centre": [0.0, 0.0], "r": CAMPFIRE_RADIUS, "stones": stones, "light": list(CAMP_LIGHT)},
        "promenade": {"radius": v["promenade"][0], "width": v["promenade"][1], "pieces": make_promenade(v)},
        "spawn_pads": spawn,
        "rules_sign": {"key": rules["key"], "text": rules["text"], "centre": list(rules["centre"]),
                       "yaw": rules["yaw"], "width": rules["width"]},
    }


def make_decorations(bases, v=None):
    v = v or VARIANTS["v1"]
    deco = []
    for k, b in enumerate(BENCH_BEARINGS):
        deco.append({"id": "bench-%d" % (k + 1), "kind": "bench", "centre": list(polar(BENCH_RADIUS, b)),
                     "yaw": outward_yaw(b), "footprint": {"kind": "rect", "half": [BENCH_LENGTH / 2, 0.6],
                                                          "yaw": outward_yaw(b)}})
    lantern_r, lantern_bearings = v["plaza_lanterns"]
    for k, b in enumerate(lantern_bearings):
        deco.append({"id": "plaza-lantern-%d" % (k + 1), "kind": "lantern", "centre": list(polar(lantern_r, b)),
                     "yaw": 0.0, "footprint": {"kind": "circle", "r": 0.5}})
    if v["flowers"]:
        for base in bases:
            deco.append({"id": "flowers-%d" % base["slot"], "kind": "flowers", "colour": base["colour"]["hex"],
                         "centre": list(polar(FLOWER_RADIUS, base["bearing"])), "yaw": 0.0,
                         "footprint": {"kind": "circle", "r": 1.5}})
    planter_r, planter_bearings = v["planters"]
    for k, b in enumerate(planter_bearings):
        deco.append({"id": "planter-%d" % (k + 1), "kind": "planter", "centre": list(polar(planter_r, b)),
                     "yaw": outward_yaw(b), "footprint": {"kind": "rect", "half": [2.0, 2.0], "yaw": outward_yaw(b)}})
    return deco


def forest_world_shapes(open_world):
    forest_layout = ow.load_json(ow.FOREST_LAYOUT)
    return ow.forest_shapes(ow.translated_forest_instances(forest_layout))


def removed_forest_props(entrances, open_world):
    """Forest edge props the new west trails would hit (beyond those layout-v1 already removes)."""
    shapes = forest_world_shapes(open_world)
    roads = [("trail_" + e["id"], [tuple(e["trail"]["from"]), tuple(e["trail"]["to"])], False)
             for e in entrances if e["leads"] == "forest"]
    already = {r["id"] for r in open_world["forest_block"]["removed_props"]}
    removed = []
    for ident, by in ow.props_removed_by(roads, shapes).items():
        if ident not in already:
            removed.append({"id": ident, "by": sorted(set(by))})
    return removed


def light_list(bases, v=None):
    v = v or VARIANTS["v1"]
    L = v["lights"]
    lights = [{"id": "campfire", "brightness": L["campfire"][0], "range": L["campfire"][1], "color": list(CAMP_LIGHT)}]
    lights += [{"id": "plaza-lantern-%d" % (k + 1), "brightness": L["plaza"][0], "range": L["plaza"][1],
                "color": list(CAMP_LIGHT)} for k in range(len(v["plaza_lanterns"][1]))]
    lights += [{"id": "gate-%s" % e[0], "brightness": L["gate"][0], "range": L["gate"][1],
                "color": list(LANTERN_LIGHT)} for e in v["entrances"]]
    lights += [{"id": "base-%d" % b["slot"], "brightness": L["base"][0], "range": L["base"][1],
                "color": list(CAMP_LIGHT)} for b in bases]
    if v["expansion"]:
        lights += [{"id": "showcase-%d" % b["slot"], "brightness": L["showcase"][0], "range": L["showcase"][1],
                    "color": list(SHOWCASE_LIGHT)} for b in bases]
        lights += [{"id": "shop-%s" % s[0], "brightness": L["shop"][0], "range": L["shop"][1],
                    "color": list(LANTERN_LIGHT)} for s in SHOPS_V2]
    return lights


# ---- v2 pieces -------------------------------------------------------------------------------------------------
def make_shops():
    s = SHOP_V2
    out = []
    for ident, label, bearing, colour, sells in SHOPS_V2:
        yaw = outward_yaw(bearing)
        out.append({"id": ident, "tag": "WildboundShopSpot", "label": label, "sign": label, "bearing": bearing,
                    "colour": colour, "centre": list(polar(s["ring_radius"], bearing)), "yaw": yaw,
                    "trigger_radius": s["trigger"], "close_radius": s["close"], "server_range": s["server_range"],
                    "stall": {"centre": list(polar(s["stall_radius"], bearing)), "half": list(s["stall_half"]),
                              "yaw": yaw},
                    "sells": sells})
    return out


def _road_lines(open_world, entrances):
    lines = [[tuple(n) for n in c["nodes"]] for c in open_world["connectors"].values()]
    return lines + [[tuple(e["trail"]["from"]), tuple(e["trail"]["to"])] for e in entrances]


def refugio_ok(p, cid, open_world, safe_radius, roads, props, sets):
    rules = open_world["refugio_rules"]
    zr = open_world["zone_rules"]
    if math.hypot(*p) - rules["radius"] - safe_radius < rules["safe_margin"]:
        return False
    if any(math.dist(p, z["home"]) < z["reach"] + rules["beast_margin"] for z in zr["strike_zones"]):
        return False
    for line in roads:
        if min(g.point_seg_dist(p, a, b) for a, b in zip(line, line[1:])) < rules["road_clear"]:
            return False
    if any(g.shape_point_dist(s, p) < rules["prop_clear"] for s in props):
        return False
    safes = list(zr["forest"]["safe"].values()) + list(zr["pradera"]["safe"].values())
    if any(math.dist(p, s["centre"]) <= s["r"] + rules["radius"] for s in safes):
        return False
    fog = zr["forest"]["fog"]
    if fog["x"][0] <= p[0] <= fog["x"][1] and fog["z"][0] <= p[1] <= fog["z"][1]:
        return False
    for s in sets:
        if any(c["id"] == cid for c in s["candidates"]):
            if any(c["id"] != cid and math.dist(p, (c["x"], c["z"])) < rules["min_spacing"] for c in s["candidates"]):
                return False
    return True


def open_world_changes(open_world, safe_radius, entrances, removed):
    """Refugio candidates the bigger disc crowds, each moved to the nearest grid point that keeps every rule."""
    rules = open_world["refugio_rules"]
    gone = {r["id"] for r in removed} | {r["id"] for r in open_world["forest_block"]["removed_props"]}
    props = [s for ident, s in forest_world_shapes(open_world) if ident not in gone]
    roads = _road_lines(open_world, entrances)
    sets = [s for side in open_world["refugio_sets"].values() for s in side]
    changes = []
    step, reach = REFUGIO_SEARCH["step"], REFUGIO_SEARCH["reach"]
    n = int(reach / step)
    for s in sets:
        for c in s["candidates"]:
            origin = (c["x"], c["z"])
            if math.hypot(*origin) - rules["radius"] - safe_radius >= rules["safe_margin"]:
                continue
            grid = [(c["x"] + i * step, c["z"] + j * step) for i in range(-n, n + 1) for j in range(-n, n + 1)]
            grid.sort(key=lambda p: (math.dist(p, origin), p[0], p[1]))
            best = next((p for p in grid if refugio_ok(p, c["id"], open_world, safe_radius, roads, props, sets)), None)
            if best is None:
                raise RuntimeError("no place for refugio candidate " + c["id"])
            changes.append({"kind": "refugio_candidate", "id": c["id"], "from": [c["x"], c["z"]],
                            "to": [r3(best[0]), r3(best[1])],
                            "why": "the radius-%g disc leaves it %.1f studs from the hub, under the %g-stud safe margin; "
                                   "the open-world planner must apply and re-check this move"
                                   % (safe_radius, math.hypot(*origin) - rules["radius"] - safe_radius,
                                      rules["safe_margin"])})
    return changes


def walk_times(v):
    delivery_lz = next(local for kind, _, _, local, _ in v["stations"] if kind == "delivery")[1]
    return {"speed": WALK_SPEED,
            "spawn_to_gate_s": r3((v["wall_radius"] - SPAWN_PAD_RADIUS) / WALK_SPEED),
            "spawn_to_base_s": r3((v["base_ring"] + delivery_lz - SPAWN_PAD_RADIUS) / WALK_SPEED),
            "around_promenade_half_s": r3(math.pi * v["promenade"][0] / WALK_SPEED),
            "note": "straight lines at the walk speed, no sprint; a lower bound"}


def generate(open_world=None, variant="v1"):
    v = VARIANTS[variant]
    open_world = open_world or ow.load_json(OPEN_WORLD)
    bases = [make_base(i + 1, b, BASE_COLOURS[i], v) for i, b in enumerate(BASE_BEARINGS)]
    entrances = make_entrances(v)
    hub_ow = open_world["hub"]
    safe_radius = v["safe_radius"]
    removed = removed_forest_props(entrances, open_world)
    supersedes = {
        "layout_v1_hub_radius": hub_ow["safe_radius"],
        "hub_safe_radius": safe_radius,
        "why": "eight 26 x 22 personal bases and a lobby do not fit inside radius 60; the 90 disc stays inside the "
               "beast-free band (x -200 to 340) and outside both region squares (x -100 and x 100). The layout-v1 "
               "shared station band (incubadora, corral) is replaced by per-base stations; Refugio, Cofre, Puesto, "
               "Tablero, Arbol and trophies are not placed here (decision HB2)",
        "transitions": "the 40-stud transitions shrink to x -100..-90 and 90..100",
    }
    if v["expansion"]:
        supersedes["why"] = ("the hub expansion (docs/design/wildbound-hub-expansion.md): a 100 disc is the most "
                             "layout-v1's region squares (x -100 and 100) allow; bases grow to 29 x 24 for a chest zone, "
                             "a showcase stands in front of each base, four shop circles sit on the lawn ring")
        supersedes["transitions"] = ("the transitions vanish: the hub disc meets both region squares; the fog and "
                                     "every beast stay beyond x -135 and x 340")
        supersedes["hub_bases_v1_radius"] = HUB_SAFE_RADIUS
    parts_cap, lights_cap, why = v["budget"]
    budget = {"parts_cap": parts_cap, "lights_cap": lights_cap}
    if why:
        budget["why"] = why
    layout = {
        "name": v["name"],
        "status": "design, unvalidated: never built in Studio, played or measured on a device",
        "seed": DEFAULT_SEED,
        "conventions": {
            "units": "studs; the open-world hub frame of layout-v1.json (origin at the hub centre, x east, z south)",
            "yaw": "rotation_y_deg as CFrame.Angles(0, rad, 0); local +X = (cos r, -sin r), local +Z = (sin r, cos r)",
            "front": "a piece faces along its local -Z (its Front face); bases and gate signs face the lobby",
            "bearing": "centre + radius * (cos b, sin b): 0 east, 90 south, 180 west, 270 north",
            "station_local": "station local (lx, lz) is in its base's frame: -lz toward the lobby, +lx to the right",
            "heights": "floor top y 0.5; base pad top y 0.9",
        },
        "sources": {"open_world": "assets/maps/open-world/layout-v1.json",
                    "combined_plan": "docs/design/wildbound-combined-plan.md"},
        "supersedes": supersedes,
        "hub": {
            "centre": list(hub_ow["centre"]), "safe_radius": safe_radius, "floor_radius": v["floor_radius"],
            "floor_top": FLOOR_TOP, "max_players": MAX_PLAYERS,
            "wall": {"radius": v["wall_radius"], "thick": WALL_THICK, "height": WALL_HEIGHT,
                     "gate_half_angle": r3(gate_half_angle(v["wall_radius"]))},
            "pvp": False, "beasts": False,
        },
        "lobby": make_lobby(v),
        "bases": bases,
        "entrances": entrances,
        "hedge": make_hedge(entrances, v["wall_radius"]),
        "safe_zones": [{"id": "hub", "kind": "cylinder", "centre": list(hub_ow["centre"]), "radius": safe_radius,
                        "height": 40.0, "tag": "WildboundHubSafeZone"}],
        "decorations": make_decorations(bases, v),
        "lights": light_list(bases, v),
        "removed_forest_props": removed,
        "budget": budget,
        "rules": {"station_margin": STATION_MARGIN, "station_gap": STATION_GAP, "base_path_clear": BASE_PATH_CLEAR,
                  "beast_margin": BEAST_MARGIN, "forest_clear": FOREST_CLEAR, "hook_clear": HOOK_CLEAR},
    }
    if v["expansion"]:
        layout["shops"] = make_shops()
        layout["lighting"] = dict(LIGHTING_V2, inside_radius=safe_radius)
        layout["walk_times"] = walk_times(v)
        layout["open_world_changes"] = open_world_changes(open_world, safe_radius, entrances, removed)
    return layout


def to_json(layout):
    return json.dumps(layout, indent=1, ensure_ascii=False) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--variant", choices=sorted(VARIANTS), default="v1")
    parser.add_argument("--out", type=Path, default=None)
    parser.add_argument("--check", action="store_true", help="exit 1 when the written JSON differs")
    args = parser.parse_args(argv)
    out = args.out or out_path(args.variant)
    text = to_json(generate(variant=args.variant))
    if args.check:
        current = out.read_text(encoding="utf-8") if out.exists() else ""
        print(("fresh: " if current == text else "stale: ") + str(out))
        return 0 if current == text else 1
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(text.encode("utf-8"))
    print("wrote", out)
    return 0


if __name__ == "__main__":
    sys.exit(main())

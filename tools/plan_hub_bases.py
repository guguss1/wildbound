#!/usr/bin/env python3
"""Reproducible plan for Wildbound's central social hub with eight personal bases (DESIGN, unvalidated).

The master prompt (docs/design/wildbound-combined-plan.md sections 1 and 2) asks for a safe central lobby with
personal bases for up to 8 players around it. Each base is recognisable (a name sign and a colour) and holds an egg
delivery station, an incubator, a Lumipol collection display, a glove station and a training station. Physical exits
lead from the lobby to the forest (several, so nobody can block one), and there is no PvP and no beast inside.

This tool writes `assets/maps/hub-layout/hub-bases-v1.json` only. It never touches Studio. The parts-only Luau
builder is rendered from the JSON by `tools/build-hub-map.py`. Python standard library only.

    python -I -B tools/plan_hub_bases.py               # writes the JSON
    python -I -B tools/plan_hub_bases.py --check       # exit 1 when the written JSON is stale

Frame: the open-world hub frame of `assets/maps/open-world/layout-v1.json` (studs, origin at the hub centre, x east,
z south). `rotation_y_deg` is CFrame.Angles(0, math.rad(r), 0): local +X maps to (cos r, -sin r) and local +Z to
(sin r, cos r) in (x, z) (tools/layout_geometry.py). A piece's Front face (local -Z) is the side it faces. A bearing
b places a point at centre + radius * (cos b, sin b): 0 is east, 90 south, 180 west, 270 north.

Why the hub grows from radius 60 to 90: layout-v1 drew a radius-60 hub with shared stations. Eight 26 x 22 bases plus
a lobby do not fit inside 60 (the ring of bases alone needs about 81 studs of radius). The band no beast reaches runs
from x -200 to x 340, and the region squares start at x -100 and x 100, so a 90-stud safe disc stays inside the band
and outside both regions. This is decision HB1 for the user (docs/maps/wildbound-hub.md).
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
DEFAULT_OUT = REPO / "assets" / "maps" / "hub-layout" / "hub-bases-v1.json"

# ---- Hub -------------------------------------------------------------------------------------------------------
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
def make_base(slot, bearing, colour):
    centre = polar(BASE_RING, bearing)
    yaw = outward_yaw(bearing)
    hx, hz = BASE_WIDTH / 2, BASE_DEPTH / 2
    stations = []
    for kind, tag, label, local, fp in STATIONS:
        stations.append({"kind": kind, "tag": tag, "label": label, "local": list(local),
                         "world": list(to_world(centre, yaw, local)), "yaw": yaw, "footprint": footprint_json(fp, yaw)})
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
    walk_depth = BASE_RING - hz - (PROMENADE_RADIUS + PROMENADE_WIDTH / 2) + 0.4
    walk_local = (0.0, -(hz + walk_depth / 2 - 0.2))
    return {
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
        "sign": {"key": "base%d" % slot, "text": SIGN_TEXT, "local": [-8.5, -(hz - FENCE_THICK / 2)],
                 "world": list(to_world(centre, yaw, (-8.5, -(hz - FENCE_THICK / 2)))), "yaw": yaw, "width": 6.0},
        "lantern": {"local": [-11.3, 9.3], "world": list(to_world(centre, yaw, (-11.3, 9.3))), "r": 0.5},
        "stations": stations,
        "display_slots": DISPLAY_SLOTS,
        "treadmill_belt": TREADMILL_BELT,
    }


def make_entrances():
    out = []
    for ident, bearing, leads, sign, join, connector in ENTRANCES:
        gate = polar(WALL_RADIUS, bearing)
        path = segment_json(polar(PLAZA_RADIUS - 1.0, bearing), polar(WALL_RADIUS + 1.0, bearing), PATH_WIDTH)
        trail = segment_json(polar(WALL_RADIUS + 1.0, bearing), join, TRAIL_WIDTH)
        out.append({"id": ident, "bearing": bearing, "gate": list(gate), "width": GATE_WIDTH, "leads": leads,
                    "sign": sign, "yaw": outward_yaw(bearing), "path": path, "trail": trail,
                    "joins": connector or "forest_floor"})
    return out


def gate_half_angle():
    """Angular half width of a gate gap; the hedge stops 0.6 studs past the gate edge so chords never narrow it."""
    return math.degrees(math.asin((GATE_WIDTH / 2 + 0.6) / WALL_RADIUS))


def make_hedge(entrances):
    """Straight hedge chords on the wall circle between consecutive gates."""
    bearings = sorted(e["bearing"] for e in entrances)
    half = gate_half_angle()
    segments = []
    for index, start in enumerate(bearings):
        end = bearings[(index + 1) % len(bearings)] + (360.0 if index == len(bearings) - 1 else 0.0)
        a0, a1 = start + half, end - half
        count = max(1, math.ceil((a1 - a0) / HEDGE_MAX_SPAN_DEG))
        step = (a1 - a0) / count
        for k in range(count):
            p = polar(WALL_RADIUS, a0 + step * k)
            q = polar(WALL_RADIUS, a0 + step * (k + 1))
            mid = (a0 + step * (k + 0.5)) % 360.0
            segments.append({"centre": [r3((p[0] + q[0]) / 2), r3((p[1] + q[1]) / 2)], "length": r3(math.dist(p, q) + 0.6),
                             "yaw": outward_yaw(mid), "bearing": r3(mid)})
    return segments


def make_promenade():
    half = 180.0 / PROMENADE_SEGMENTS
    pieces = []
    for k in range(PROMENADE_SEGMENTS):
        mid = 360.0 * k / PROMENADE_SEGMENTS
        centre = polar(PROMENADE_RADIUS * math.cos(math.radians(half)), mid)
        chord = 2 * PROMENADE_RADIUS * math.sin(math.radians(half))
        pieces.append({"centre": list(centre), "length": r3(chord + 1.0), "yaw": outward_yaw(mid)})
    return pieces


def make_lobby():
    stones = [{"centre": list(polar(CAMPFIRE_RADIUS, 60.0 * k + 30.0))} for k in range(6)]
    spawn = [{"id": "spawn-%d" % (i + 1), "centre": list(polar(SPAWN_PAD_RADIUS, b)), "size": SPAWN_PAD_SIZE,
              "faces": "east", "yaw": 270.0} for i, b in enumerate(SPAWN_BEARINGS)]
    return {
        "plaza_radius": PLAZA_RADIUS,
        "campfire": {"centre": [0.0, 0.0], "r": CAMPFIRE_RADIUS, "stones": stones, "light": list(CAMP_LIGHT)},
        "promenade": {"radius": PROMENADE_RADIUS, "width": PROMENADE_WIDTH, "pieces": make_promenade()},
        "spawn_pads": spawn,
        "rules_sign": {"key": RULES_SIGN["key"], "text": RULES_SIGN["text"], "centre": list(RULES_SIGN["centre"]),
                       "yaw": RULES_SIGN["yaw"], "width": RULES_SIGN["width"]},
    }


def make_decorations(bases):
    deco = []
    for k, b in enumerate(BENCH_BEARINGS):
        deco.append({"id": "bench-%d" % (k + 1), "kind": "bench", "centre": list(polar(BENCH_RADIUS, b)),
                     "yaw": outward_yaw(b), "footprint": {"kind": "rect", "half": [BENCH_LENGTH / 2, 0.6],
                                                          "yaw": outward_yaw(b)}})
    for k, b in enumerate(BENCH_BEARINGS):
        deco.append({"id": "plaza-lantern-%d" % (k + 1), "kind": "lantern", "centre": list(polar(PLAZA_LANTERN_RADIUS, b)),
                     "yaw": 0.0, "footprint": {"kind": "circle", "r": 0.5}})
    for base in bases:
        deco.append({"id": "flowers-%d" % base["slot"], "kind": "flowers", "colour": base["colour"]["hex"],
                     "centre": list(polar(FLOWER_RADIUS, base["bearing"])), "yaw": 0.0,
                     "footprint": {"kind": "circle", "r": 1.5}})
    for k, b in enumerate(PLANTER_BEARINGS):
        deco.append({"id": "planter-%d" % (k + 1), "kind": "planter", "centre": list(polar(PLANTER_RADIUS, b)),
                     "yaw": outward_yaw(b), "footprint": {"kind": "rect", "half": [2.0, 2.0], "yaw": outward_yaw(b)}})
    return deco


def removed_forest_props(entrances, open_world):
    """Forest edge props the new west trails would hit (beyond those layout-v1 already removes)."""
    forest_layout = ow.load_json(ow.FOREST_LAYOUT)
    shapes = ow.forest_shapes(ow.translated_forest_instances(forest_layout))
    roads = [("trail_" + e["id"], [tuple(e["trail"]["from"]), tuple(e["trail"]["to"])], False)
             for e in entrances if e["leads"] == "forest"]
    already = {r["id"] for r in open_world["forest_block"]["removed_props"]}
    removed = []
    for ident, by in ow.props_removed_by(roads, shapes).items():
        if ident not in already:
            removed.append({"id": ident, "by": sorted(set(by))})
    return removed


def light_list(bases):
    lights = [{"id": "campfire", "brightness": LIGHTS["campfire"][0], "range": LIGHTS["campfire"][1],
               "color": list(CAMP_LIGHT)}]
    lights += [{"id": "plaza-lantern-%d" % (k + 1), "brightness": LIGHTS["plaza"][0], "range": LIGHTS["plaza"][1],
                "color": list(CAMP_LIGHT)} for k in range(len(BENCH_BEARINGS))]
    lights += [{"id": "gate-%s" % e[0], "brightness": LIGHTS["gate"][0], "range": LIGHTS["gate"][1],
                "color": list(LANTERN_LIGHT)} for e in ENTRANCES]
    lights += [{"id": "base-%d" % b["slot"], "brightness": LIGHTS["base"][0], "range": LIGHTS["base"][1],
                "color": list(CAMP_LIGHT)} for b in bases]
    return lights


def generate(open_world=None):
    open_world = open_world or ow.load_json(OPEN_WORLD)
    bases = [make_base(i + 1, b, BASE_COLOURS[i]) for i, b in enumerate(BASE_BEARINGS)]
    entrances = make_entrances()
    hub_ow = open_world["hub"]
    return {
        "name": LAYOUT_NAME,
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
        "supersedes": {
            "layout_v1_hub_radius": hub_ow["safe_radius"],
            "hub_safe_radius": HUB_SAFE_RADIUS,
            "why": "eight 26 x 22 personal bases and a lobby do not fit inside radius 60; the 90 disc stays inside the "
                   "beast-free band (x -200 to 340) and outside both region squares (x -100 and x 100). The layout-v1 "
                   "shared station band (incubadora, corral) is replaced by per-base stations; Refugio, Cofre, Puesto, "
                   "Tablero, Arbol and trophies are not placed here (decision HB2)",
            "transitions": "the 40-stud transitions shrink to x -100..-90 and 90..100",
        },
        "hub": {
            "centre": list(hub_ow["centre"]), "safe_radius": HUB_SAFE_RADIUS, "floor_radius": FLOOR_RADIUS,
            "floor_top": FLOOR_TOP, "max_players": MAX_PLAYERS,
            "wall": {"radius": WALL_RADIUS, "thick": WALL_THICK, "height": WALL_HEIGHT,
                     "gate_half_angle": r3(gate_half_angle())},
            "pvp": False, "beasts": False,
        },
        "lobby": make_lobby(),
        "bases": bases,
        "entrances": entrances,
        "hedge": make_hedge(entrances),
        "safe_zones": [{"id": "hub", "kind": "cylinder", "centre": list(hub_ow["centre"]), "radius": HUB_SAFE_RADIUS,
                        "height": 40.0, "tag": "WildboundHubSafeZone"}],
        "decorations": make_decorations(bases),
        "lights": light_list(bases),
        "removed_forest_props": removed_forest_props(entrances, open_world),
        "budget": {"parts_cap": PARTS_CAP, "lights_cap": LIGHTS_CAP},
        "rules": {"station_margin": STATION_MARGIN, "station_gap": STATION_GAP, "base_path_clear": BASE_PATH_CLEAR,
                  "beast_margin": BEAST_MARGIN, "forest_clear": FOREST_CLEAR, "hook_clear": HOOK_CLEAR},
    }


def to_json(layout):
    return json.dumps(layout, indent=1, ensure_ascii=False) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--check", action="store_true", help="exit 1 when the written JSON differs")
    args = parser.parse_args(argv)
    text = to_json(generate())
    if args.check:
        current = args.out.read_text(encoding="utf-8") if args.out.exists() else ""
        print(("fresh: " if current == text else "stale: ") + str(args.out))
        return 0 if current == text else 1
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_bytes(text.encode("utf-8"))
    print("wrote", args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Emit the parts-only Luau builder for Wildbound's central hub with eight personal bases.

The plan JSON (`tools/plan_hub_bases.py` -> `assets/maps/hub-layout/hub-bases-v1.json`) is the single source of
truth. This tool turns it into a flat list of primitive parts (every size, position, yaw, colour, collision flag, tag
and attribute decided here, in Python, where the tests can read it) and renders
`tools/build-wildbound-hub-map.luau`: a self-contained ModuleScript whose `Builder.build(parent, origin?)` only
interprets that list. No MeshParts, no uploads, no toolbox ids, no scripts, no SpawnLocation. Nothing here touches
Studio; a later Studio writer deploys and runs the module (docs/maps/wildbound-hub.md).

    python -I -B tools/build-hub-map.py            # writes the module and the kit report
    python -I -B tools/build-hub-map.py --check    # exit 1 when the written module is stale
    python -I -B tools/build-hub-map.py --stdout   # prints the module instead of writing it
    python -I -B tools/build-hub-map.py --plan assets/maps/hub-layout/hub-bases-v2-r90.json
                                                   # writes build-wildbound-hub-map-v2-r90.luau and its report

Everything is anchored. Only floors (ground, paving, pads, the treadmill deck and belt) and walls (hedge, gate posts,
base fences) collide and answer queries; every other part has CanCollide, CanQuery and CanTouch off. Every value is a
hypothesis; the module was never run in Studio by this tool.
"""

import argparse
import json
import math
import sys
import zlib
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
REPO = TOOLS.parent
PLAN = REPO / "assets" / "maps" / "hub-layout" / "hub-bases-v1.json"
MODULE = TOOLS / "build-wildbound-hub-map.luau"
REPORT = REPO / "assets" / "maps" / "hub-layout" / "hub-kit-report.json"
ROOT_NAME = "WildboundHub"

# One colour per role (hex). Forest palette for wood and stone (docs/design/wildbound-forest-aesthetic-reference.md
# section 2), the camp's warm flame, and a neutral meadow green between the fog forest and the Pradera.
PALETTE = {
    "grass": "7FA65A", "plaza": "C9B79C", "path": "D9C7A3", "hedge": "3B5A44", "bush": "556B3A",
    "wood": "8B5E3C", "paleWood": "BE9C70", "charcoal": "55585D", "pad": "E8DCC0", "straw": "F5E6C8",
    "glass": "BFE6F2", "rubber": "2C2D30", "metal": "9AA3AD", "ink": "3A2E22", "flame": "F08C2E",
    "flameTip": "FFD27A", "lamp": "FFD9A0", "zone": "FFFFFF",
}
ROLES = ("floor", "wall", "deco", "zone")      # floor and wall collide and answer queries; deco and zone never do
TAGS = ("WildboundHub", "WildboundBaseSlot", "WildboundDeliveryStation", "WildboundIncubatorStation",
        "WildboundCollectionDisplay", "WildboundGloveStation", "WildboundTrainingStation", "WildboundHubSafeZone",
        "WildboundHubEntrance", "WildboundHubSpawnPad", "WildboundBaseSign", "WildboundHubCampfire")
STATION_RANGE = 8.0                            # suggested prompt reach for the game code, studs
# Hub expansion (plan variant v2, docs/design/wildbound-hub-expansion.md): extra tags, and a lighter, warmer ground
# palette given as "#hex" so the v1 palette and module stay byte-identical.
EXPANSION_TAGS = ("WildboundShopSpot", "WildboundChestStation", "WildboundShowcase", "WildboundBaseZone")
BRIGHT_GROUND = {"grass": "#8DBB63", "plaza": "#E6D7BA", "path": "#ECDDC2"}


def expanded(plan):
    return "shops" in plan


def tags_for(plan):
    return TAGS + EXPANSION_TAGS if expanded(plan) else TAGS


def ground(plan, key):
    return BRIGHT_GROUND.get(key, key) if expanded(plan) else key


def plan_suffix(plan_name):
    """The variant part of a plan name: "hub-bases-v2" -> "v2", "hub-bases-v2-r90" -> "v2-r90"."""
    prefix = "hub-bases-"
    if not plan_name.startswith(prefix) or len(plan_name) == len(prefix):
        raise ValueError("unexpected plan name " + plan_name)
    return plan_name[len(prefix):]


def module_path(plan_name):
    """v1 keeps the original module path; any other plan renders beside it under its own suffix."""
    if plan_name == "hub-bases-v1":
        return MODULE
    return TOOLS / ("build-wildbound-hub-map-%s.luau" % plan_suffix(plan_name))


def report_path(plan_name):
    if plan_name == "hub-bases-v1":
        return REPORT
    return REPORT.with_name("hub-kit-report-%s.json" % plan_suffix(plan_name))


def hex_to_rgb(value):
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def adler32(text):
    return zlib.adler32(text.encode("utf-8")) & 0xFFFFFFFF


def r3(value):
    return round(value, 3) + 0.0


def axes(yaw):
    a = math.radians(yaw)
    return (math.cos(a), -math.sin(a)), (math.sin(a), math.cos(a))


def offset(centre, yaw, lx, lz):
    ex, ez = axes(yaw)
    return (centre[0] + lx * ex[0] + lz * ez[0], centre[1] + lx * ex[1] + lz * ez[1])


class Kit:
    """Collects models (folders and tagged models) and parts in build order."""

    def __init__(self):
        self.models, self.parts = [], []

    def model(self, path, kind="Model", tags=(), attrs=None, colours=None, primary=None):
        self.models.append({"path": path, "kind": kind, "tags": list(tags), "a": attrs or {}, "ca": colours or {},
                            "primary": primary})
        return len(self.models)          # 1-based, as Luau indexes it

    def part(self, m, name, shape, size, xz, y, yaw, colour, role, material="SmoothPlastic", **extra):
        assert role in ROLES and shape in ("B", "C", "X", "S") and (colour in PALETTE or colour.startswith("#"))
        row = {"m": m, "n": name, "s": shape, "z": [r3(v) for v in size], "p": [r3(xz[0]), r3(y), r3(xz[1])],
               "r": r3(yaw % 360.0), "c": colour, "mt": material, "role": role}
        for key in ("t", "tags", "a", "l", "sign", "ns"):
            if key in extra and extra[key] is not None:
                row[key] = extra[key]
        self.parts.append(row)
        return row


def sign(kit, m, name, spec_key, text, centre, yaw, width, base_y, colour, tag=None, attrs=None):
    for side in (-1, 1):
        kit.part(m, name + "Post", "B", (0.35, 5.0, 0.35), offset(centre, yaw, side * (width / 2 - 0.6), 0.0),
                 base_y + 2.5, yaw, "wood", "deco", "Wood")
    attrs = dict(attrs or {}, SignKey=spec_key)
    kit.part(m, name, "B", (width, 1.8, 0.3), centre, base_y + 4.2, yaw, colour, "deco", "WoodPlanks",
             tags=[tag] if tag else None, a=attrs, sign={"key": spec_key, "text": text})


def lantern(kit, m, name, centre, base_y, light, light_id):
    kit.part(m, name + "Post", "B", (0.4, 6.0, 0.4), centre, base_y + 3.0, 0.0, "wood", "deco", "Wood")
    kit.part(m, name, "S", (1.0, 1.0, 1.0), centre, base_y + 6.4, 0.0, "lamp", "deco", "Neon",
             l=[light["brightness"], light["range"], light["color"]], a={"LightId": light_id}, ns=True)


def build_lobby(kit, plan, lights):
    hub, lobby = plan["hub"], plan["lobby"]
    top = hub["floor_top"]
    m = kit.model("Lobby", "Folder")
    kit.part(m, "Floor", "C", (2 * hub["floor_radius"], 1.0, 2 * hub["floor_radius"]), (0, 0), 0.0, 0.0,
             ground(plan, "grass"), "floor", "Grass")
    kit.part(m, "Plaza", "C", (2 * lobby["plaza_radius"], 0.2, 2 * lobby["plaza_radius"]), (0, 0), top + 0.02, 0.0,
             ground(plan, "plaza"), "floor", "Pavement")
    width = lobby["promenade"]["width"]
    for k, piece in enumerate(lobby["promenade"]["pieces"]):
        kit.part(m, "Promenade%d" % (k + 1), "B", (piece["length"], 0.2, width), piece["centre"], top, piece["yaw"],
                 ground(plan, "path"), "floor", "Pavement")
    pads = kit.model("Lobby/SpawnPads", "Folder")
    for k, pad in enumerate(lobby["spawn_pads"]):
        kit.part(pads, "SpawnPad%d" % (k + 1), "B", (pad["size"], 0.3, pad["size"]), pad["centre"], top + 0.2,
                 pad["yaw"], "straw", "floor", "Pavement", tags=["WildboundHubSpawnPad"],
                 a={"SpawnIndex": k + 1, "Faces": pad["faces"], "Yaw": pad["yaw"]})
    fire = kit.model("Lobby/Campfire", tags=["WildboundHubCampfire"], attrs={"Radius": lobby["campfire"]["r"]})
    for k, stone in enumerate(lobby["campfire"]["stones"]):
        kit.part(fire, "Stone%d" % (k + 1), "S", (1.4, 1.4, 1.4), stone["centre"], top + 0.4, 0.0, "charcoal", "deco",
                 "Slate")
    for k, yaw in enumerate((45.0, 135.0)):
        kit.part(fire, "Log%d" % (k + 1), "X", (5.0, 0.9, 0.9), (0, 0), top + 0.45, yaw, "wood", "deco", "Wood")
    light = lights["campfire"]
    kit.part(fire, "Flame", "S", (2.2, 2.2, 2.2), (0, 0), top + 1.4, 0.0, "flame", "deco", "Neon",
             l=[light["brightness"], light["range"], light["color"]], a={"LightId": "campfire"}, ns=True)
    kit.part(fire, "FlameTip", "S", (1.3, 1.3, 1.3), (0, 0), top + 2.8, 0.0, "flameTip", "deco", "Neon", ns=True)
    deco = kit.model("Lobby/Decor", "Folder")
    for d in plan["decorations"]:
        did = d["id"]
        if d["kind"] == "bench":
            kit.part(deco, "Bench_" + did, "X", (d["footprint"]["half"][0] * 2, 1.2, 1.2), d["centre"], top + 0.6,
                     d["yaw"], "wood", "deco", "Wood")
        elif d["kind"] == "lantern":
            lantern(kit, deco, "Lamp_" + did, d["centre"], top, lights[did], did)
        elif d["kind"] == "flowers":
            kit.part(deco, "Flowers_" + did, "S", (2.4, 2.4, 2.4), d["centre"], top + 0.6, 0.0, "#" + d["colour"],
                     "deco")
        elif d["kind"] == "planter":
            kit.part(deco, "Planter_" + did, "B", (4.0, 1.2, 4.0), d["centre"], top + 0.6, d["yaw"], "wood", "deco",
                     "WoodPlanks")
            kit.part(deco, "Bush_" + did, "S", (3.2, 3.2, 3.2), d["centre"], top + 2.2, 0.0, "bush", "deco", "Grass")
        else:
            raise ValueError("unknown decoration kind " + d["kind"])
    rules = lobby["rules_sign"]
    sign(kit, deco, "RulesSign", rules["key"], rules["text"], rules["centre"], rules["yaw"], rules["width"], top,
         "paleWood")


def build_wall_and_entrances(kit, plan, lights):
    hub = plan["hub"]
    top, wall = hub["floor_top"], hub["wall"]
    paths = kit.model("Paths", "Folder")
    for e in plan["entrances"]:
        p = e["path"]
        kit.part(paths, "GatePath_" + e["id"], "B", (p["width"], 0.2, p["length"]), p["centre"], top + 0.01, p["yaw"],
                 ground(plan, "path"), "floor", "Pavement")
    for e in plan["entrances"]:
        t = e["trail"]
        kit.part(paths, "Trail_" + e["id"], "B", (t["width"], 1.2, t["length"] + 1.0), t["centre"], top - 0.5 + 0.01,
                 t["yaw"], "path", "floor", "Sand")
    hedge = kit.model("Hedge", "Folder")
    for k, h in enumerate(plan["hedge"]):
        kit.part(hedge, "Hedge%d" % (k + 1), "B", (h["length"], wall["height"], wall["thick"]), h["centre"],
                 top + wall["height"] / 2, h["yaw"], "hedge", "wall", "Grass")
    for e in plan["entrances"]:
        gm = kit.model("Gates/Gate_" + e["id"], attrs={"EntranceId": e["id"], "Leads": e["leads"]})
        yaw, gate, w = e["yaw"], e["gate"], e["width"]
        for side, name in ((-1, "PostLeft"), (1, "PostRight")):
            kit.part(gm, name, "B", (1.5, 7.0, 1.5), offset(gate, yaw, side * (w / 2 + 0.75), 0.0), top + 3.5, yaw,
                     "wood", "wall", "Wood")
        kit.part(gm, "Beam", "B", (w + 3.0, 1.0, 1.2), gate, top + 7.5, yaw, "wood", "deco", "Wood")
        kit.part(gm, "GateSign", "B", (9.0, 1.8, 0.3), offset(gate, yaw, 0.0, -0.8), top + 6.0, yaw, "paleWood",
                 "deco", "WoodPlanks", a={"SignKey": "gate" + e["id"]}, sign={"key": "gate" + e["id"], "text": e["sign"]})
        light = lights["gate-" + e["id"]]
        kit.part(gm, "GateLamp", "S", (1.0, 1.0, 1.0), offset(gate, yaw, -(w / 2 + 0.75), -1.1), top + 6.6, 0.0, "lamp",
                 "deco", "Neon", l=[light["brightness"], light["range"], light["color"]], a={"LightId": light["id"]},
                 ns=True)
        kit.part(gm, "EntranceZone", "B", (w, 8.0, 4.0), gate, top + 4.0, yaw, "zone", "zone", t=1, ns=True,
                 tags=["WildboundHubEntrance"],
                 a={"EntranceId": e["id"], "Leads": e["leads"], "Joins": e["joins"], "Bearing": e["bearing"],
                    "Width": w})
    zones = kit.model("SafeZones", "Folder")
    for z in plan["safe_zones"]:
        kit.part(zones, "HubSafeZone", "C", (2 * z["radius"], z["height"], 2 * z["radius"]), z["centre"],
                 z["height"] / 2, 0.0, "zone", "zone", t=1, ns=True, tags=[z["tag"]],
                 a={"ZoneId": z["id"], "Radius": z["radius"], "NoPvP": True, "NoBeasts": True})


def station_attrs(base, s):
    return {"SlotIndex": base["slot"], "StationKind": s["kind"], "Label": s["label"], "Range": STATION_RANGE}


def build_base(kit, base, lights):
    slot, yaw, centre = base["slot"], base["yaw"], base["centre"]
    colour = "#" + base["colour"]["hex"]
    top = base["pad"]["top"]
    m = kit.model("Bases/Base%d" % slot, tags=["WildboundBaseSlot"], colours={"BaseColor": colour},
                  attrs={"SlotIndex": slot, "BaseId": base["id"], "ColourName": base["colour"]["name"],
                         "Bearing": base["bearing"], "Yaw": yaw, "OwnerUserId": 0, "OwnerName": ""},
                  primary="Pad")
    hx, hz = base["pad"]["half"]
    rim = base["pad"]["rim"]
    kit.part(m, "Rim", "B", (2 * (hx + rim), 0.3, 2 * (hz + rim)), centre, 0.65, yaw, colour, "floor")
    kit.part(m, "Pad", "B", (2 * hx, 0.4, 2 * hz), centre, top - 0.2, yaw, "pad", "floor", "WoodPlanks")
    walk = base["walk"]
    kit.part(m, "Walk", "B", (2 * walk["half"][0], 0.2, 2 * walk["half"][1]), walk["world"], 0.5, yaw, "path", "floor",
             "Pavement")
    fence = base["fence"]
    for f in base["fences"]:
        kit.part(m, "Fence_" + f["id"], "B", (2 * f["half"][0], fence["height"], 2 * f["half"][1]), f["world"],
                 top + fence["height"] / 2, yaw, colour, "wall", "WoodPlanks")
    sg = base["sign"]
    sign(kit, m, "NameSign", sg["key"], sg["text"], sg["world"], yaw, sg["width"], top, colour, tag="WildboundBaseSign",
         attrs={"SlotIndex": slot, "Placeholder": "<jugador>"})
    st = {s["kind"]: s for s in base["stations"]}

    s = st["delivery"]
    kit.part(m, "DeliveryPedestal", "C", (3.2, 2.2, 3.2), s["world"], top + 1.1, yaw, "paleWood", "deco", "Wood",
             tags=[s["tag"]], a=station_attrs(base, s))
    kit.part(m, "DeliveryRing", "C", (5.0, 0.15, 5.0), s["world"], top + 0.08, yaw, colour, "deco", "Neon", t=0.3,
             ns=True)

    s = st["incubator"]
    kit.part(m, "IncubatorBase", "C", (5.0, 1.2, 5.0), s["world"], top + 0.6, yaw, "paleWood", "deco", "Wood",
             tags=[s["tag"]], a=dict(station_attrs(base, s), Slots=s.get("slots", 1)))
    kit.part(m, "IncubatorCradle", "C", (2.6, 0.4, 2.6), s["world"], top + 1.4, yaw, "straw", "deco", "Fabric")
    kit.part(m, "IncubatorDome", "S", (4.6, 4.6, 4.6), s["world"], top + 1.2, yaw, "glass", "deco", "Glass", t=0.45,
             ns=True)

    s = st["display"]
    kit.part(m, "DisplayPlatform", "B", (2 * s["footprint"]["half"][0], 0.4, 2 * s["footprint"]["half"][1]),
             s["world"], top + 0.2, yaw, "paleWood", "deco", "WoodPlanks", tags=[s["tag"]],
             a=dict(station_attrs(base, s), DisplaySlots=base["display_slots"]))
    for k in range(base["display_slots"]):
        lx = (k - (base["display_slots"] - 1) / 2) * 3.0
        kit.part(m, "DisplaySlot%d" % (k + 1), "C", (1.6, 1.2, 1.6), offset(s["world"], yaw, lx, 0.0), top + 1.0, yaw,
                 "straw", "deco", "Wood", a={"SlotIndex": slot, "DisplayIndex": k + 1})

    s = st["glove"]
    kit.part(m, "GloveBench", "B", (5.0, 2.6, 3.0), s["world"], top + 1.3, yaw, "wood", "deco", "WoodPlanks",
             tags=[s["tag"]], a=station_attrs(base, s))
    kit.part(m, "GloveRack", "B", (5.0, 2.0, 0.3), offset(s["world"], yaw, 0.0, 1.35), top + 3.6, yaw, "paleWood",
             "deco", "WoodPlanks")
    kit.part(m, "Glove", "S", (1.2, 1.2, 1.2), s["world"], top + 3.1, yaw, colour, "deco", "Fabric")

    s = st["training"]
    belt = base["treadmill_belt"]
    kit.part(m, "TreadmillDeck", "B", (4.0, 0.5, 7.5), s["world"], top + 0.25, yaw, "charcoal", "floor", "Metal",
             tags=[s["tag"]], a=dict(station_attrs(base, s), Device="treadmill", BeltLength=belt))
    kit.part(m, "TreadmillBelt", "B", (3.0, 0.12, belt), s["world"], top + 0.56, yaw, "rubber", "floor", "Fabric")
    for side, name in ((-1, "RollerFront"), (1, "RollerBack")):
        kit.part(m, name, "X", (3.4, 0.8, 0.8), offset(s["world"], yaw, 0.0, side * 3.4), top + 0.5, yaw, "metal",
                 "deco", "Metal")
    kit.part(m, "TreadmillConsole", "B", (3.2, 3.4, 0.5), offset(s["world"], yaw, 0.0, -3.5), top + 2.2, yaw,
             "charcoal", "deco", "Metal")
    for side, name in ((-1, "RailLeft"), (1, "RailRight")):
        kit.part(m, name, "B", (0.25, 0.25, 3.2), offset(s["world"], yaw, side * 1.85, -2.0), top + 3.4, yaw, "metal",
                 "deco", "Metal")

    lantern(kit, m, "Lantern", base["lantern"]["world"], top, lights["base-%d" % slot], "base-%d" % slot)
    if "chest" in base:
        build_base_expansion(kit, m, base, lights, colour, top)


def build_base_expansion(kit, m, base, lights, colour, top):
    """v2: the chest zone and its chest, the showcase in front of the base, and the invisible bank zone."""
    slot, yaw = base["slot"], base["yaw"]
    c = base["chest"]
    r = c["trigger_radius"]
    kit.part(m, "ChestZone", "C", (2 * r, 0.12, 2 * r), c["world"], top + 0.07, yaw, colour, "deco", "Neon", t=0.35,
             ns=True, tags=[c["tag"]],
             a={"SlotIndex": slot, "StationKind": "chest", "Label": c["label"], "TriggerRadius": r,
                "CloseRadius": c["close_radius"], "Range": c["server_range"]})
    prop = c["prop"]
    kit.part(m, "ChestBox", "B", (2 * prop["half"][0], 1.4, 2 * prop["half"][1]), prop["world"], top + 0.7, yaw, "wood",
             "deco", "WoodPlanks")
    kit.part(m, "ChestLid", "B", (2 * prop["half"][0] + 0.2, 0.5, 2 * prop["half"][1] + 0.2), prop["world"], top + 1.65,
             yaw, colour, "deco", "WoodPlanks")
    sc = base["showcase"]
    floor = 0.5
    kit.part(m, "ShowcasePlinth", "C", (2 * sc["r"], 1.6, 2 * sc["r"]), sc["world"], floor + 0.8, yaw, "paleWood",
             "deco", "Wood", tags=[sc["tag"]],
             a={"SlotIndex": slot, "Slots": sc["slots"], "HoverHeight": sc["hover"]})
    light = lights["showcase-%d" % slot]
    kit.part(m, "ShowcaseRing", "C", (2 * sc["r"] + 0.6, 0.15, 2 * sc["r"] + 0.6), sc["world"], floor + 0.08, yaw,
             colour, "deco", "Neon", t=0.3, ns=True, l=[light["brightness"], light["range"], light["color"]],
             a={"LightId": light["id"]})
    kit.part(m, "ShowcasePlate", "B", (3.2, 0.9, 0.2), offset(sc["world"], yaw, 0.0, -(sc["r"] + 0.15)), floor + 0.9,
             yaw, "paleWood", "deco", "WoodPlanks", a={"SignKey": sc["sign"]["key"], "SlotIndex": slot},
             sign={"key": sc["sign"]["key"], "text": sc["sign"]["text"]})
    z = base["bank_zone"]
    kit.part(m, "BaseZone", "B", (2 * z["half"][0], z["height"], 2 * z["half"][1]), z["centre"], top + z["height"] / 2,
             yaw, "zone", "zone", t=1, ns=True, tags=[z["tag"]],
             a={"SlotIndex": slot, "ExitMargin": z["exit_margin"], "Height": z["height"]})


def build_shops(kit, plan, lights):
    """v2: a glowing circle on the lawn (stand on it to open the shop) and a small stall behind it."""
    top = plan["hub"]["floor_top"]
    for s in plan["shops"]:
        m = kit.model("Shops/Shop_" + s["id"], attrs={"ShopId": s["id"]})
        colour, yaw = "#" + s["colour"], s["yaw"]
        r = s["trigger_radius"]
        kit.part(m, "ShopCircle", "C", (2 * r, 0.12, 2 * r), s["centre"], top + 0.07, yaw, colour, "deco", "Neon",
                 t=0.3, ns=True, tags=[s["tag"]],
                 a={"ShopId": s["id"], "Label": s["label"], "TriggerRadius": r, "CloseRadius": s["close_radius"],
                    "Range": s["server_range"]})
        st = s["stall"]
        hx, hz = st["half"]
        kit.part(m, "Counter", "B", (2 * hx, 2.4, 2 * hz), st["centre"], top + 1.2, yaw, "wood", "deco", "WoodPlanks")
        for side, name in ((-1, "AwningPostLeft"), (1, "AwningPostRight")):
            kit.part(m, name, "B", (0.35, 6.0, 0.35), offset(st["centre"], yaw, side * (hx - 0.2), hz - 0.2),
                     top + 3.0, yaw, "wood", "deco", "Wood")
        light = lights["shop-" + s["id"]]
        kit.part(m, "Awning", "B", (2 * hx + 1.0, 0.4, 2 * hz + 1.6), offset(st["centre"], yaw, 0.0, -0.3), top + 6.2,
                 yaw, colour, "deco", "Fabric", l=[light["brightness"], light["range"], light["color"]],
                 a={"LightId": light["id"]})
        kit.part(m, "ShopSign", "B", (2 * hx, 1.4, 0.3), offset(st["centre"], yaw, 0.0, -(hz + 0.9)), top + 5.2, yaw,
                 "paleWood", "deco", "WoodPlanks", a={"SignKey": "shop_" + s["id"]},
                 sign={"key": "shop_" + s["id"], "text": s["sign"]})


def validate(plan):
    for key in ("name", "seed", "hub", "lobby", "bases", "entrances", "hedge", "safe_zones", "decorations", "lights"):
        if key not in plan:
            raise ValueError("plan lacks " + key)
    if len(plan["bases"]) != plan["hub"]["max_players"]:
        raise ValueError("one base per player")
    kinds = {"delivery", "incubator", "display", "glove", "training"}
    for base in plan["bases"]:
        if {s["kind"] for s in base["stations"]} != kinds:
            raise ValueError("%s lacks a station" % base["id"])
    ids = [l["id"] for l in plan["lights"]]
    if len(set(ids)) != len(ids):
        raise ValueError("duplicate light id")


def finalize(plan):
    """Build, then rewrite each part's model index to the sorted model order."""
    validate(plan)
    lights = {l["id"]: l for l in plan["lights"]}
    kit = Kit()
    build_lobby(kit, plan, lights)
    build_wall_and_entrances(kit, plan, lights)
    for base in plan["bases"]:
        build_base(kit, base, lights)
    if expanded(plan):
        build_shops(kit, plan, lights)
    paths = [mdl["path"] for mdl in kit.models]
    for path in list(paths):                       # implicit parent folders, e.g. "Bases", "Gates"
        parts = path.split("/")
        for depth in range(1, len(parts)):
            parent = "/".join(parts[:depth])
            if parent not in paths:
                paths.append(parent)
                kit.models.append({"path": parent, "kind": "Folder", "tags": [], "a": {}, "ca": {}, "primary": None})
    order = sorted(range(len(kit.models)), key=lambda i: (kit.models[i]["path"].count("/"), i))
    new_index = {old: new + 1 for new, old in enumerate(order)}
    models = [kit.models[i] for i in order]
    for row in kit.parts:
        row["m"] = new_index[row["m"] - 1]
    return {"models": models, "parts": kit.parts}


def part_count(plan):
    data = finalize(plan)
    by_group = {}
    for row in data["parts"]:
        top = data["models"][row["m"] - 1]["path"].split("/")[0]
        by_group[top] = by_group.get(top, 0) + 1
    by_role = {}
    for row in data["parts"]:
        by_role[row["role"]] = by_role.get(row["role"], 0) + 1
    lights = sum(1 for row in data["parts"] if "l" in row)
    per_base = sum(1 for row in data["parts"] if data["models"][row["m"] - 1]["path"] == "Bases/Base1")
    return {"total": len(data["parts"]), "by_group": dict(sorted(by_group.items())), "by_role": by_role,
            "per_base": per_base, "lights": lights}


def data_text(plan):
    return json.dumps(finalize(plan), separators=(",", ":"), ensure_ascii=False)


def palette_text():
    return "\n".join("    %s = Color3.fromRGB(%d, %d, %d)," % ((name,) + hex_to_rgb(value))
                     for name, value in PALETTE.items())


TEMPLATE = r"""-- GENERATED by tools/build-hub-map.py from @@PLAN@@ (seed @@SEED@@, data Adler-32 @@ADLER@@).
-- Do not edit by hand: change tools/plan_hub_bases.py or tools/build-hub-map.py, regenerate, and compare the Adler-32.
-- Wildbound central hub (docs/maps/wildbound-hub.md): a safe lobby with a warm campfire, six physical entrances
-- (three to the forest) and eight personal bases, each with a name sign, a colour, an egg delivery station, an
-- incubator, a Lumipol collection display, a glove station and a treadmill training station. Parts only: no MeshParts,
-- no uploads, no toolbox ids, no scripts, no SpawnLocation. Everything is anchored; only floors and walls collide and
-- answer queries; nothing can be touched. Stations are inert markers: game code binds them by CollectionService tag.
-- Player-facing words are neutral Spanish; code and comments are English. @@PARTS@@ parts, @@LIGHTS@@ PointLights.
-- Builds a detached WildboundHub model, attaches it once complete, and refuses a second build.
local Builder = {}

local HttpService = game:GetService('HttpService')
local CollectionService = game:GetService('CollectionService')

local ROOT_NAME = '@@ROOT@@'
local YIELD_EVERY = 150

local palette = {
@@PALETTE@@
}

local DATA = [==[@@DATA@@]==]

local data = HttpService:JSONDecode(DATA)
Builder.DATA = data
Builder.EXPECTED_PARTS = @@PARTS@@
Builder.EXPECTED_LIGHTS = @@LIGHTS@@
Builder.DATA_ADLER32 = @@ADLER@@
Builder.TAGS = { @@TAGS@@ }

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- a Cylinder's axis is X; this stands it up

local function colorOf(key)
    if string.sub(key, 1, 1) == '#' then
        return Color3.fromRGB(tonumber(string.sub(key, 2, 3), 16), tonumber(string.sub(key, 4, 5), 16),
            tonumber(string.sub(key, 6, 7), 16))
    end
    local color = palette[key]
    assert(color, 'unknown colour ' .. tostring(key))
    return color
end

local function setAttributes(item, attrs)
    if type(attrs) ~= 'table' then return end
    for name, value in pairs(attrs) do item:SetAttribute(name, value) end
end

local function addTags(item, tags)
    if type(tags) ~= 'table' then return end
    for _, tag in ipairs(tags) do CollectionService:AddTag(item, tag) end
end

local function addSign(board, spec)
    local gui = Instance.new('SurfaceGui')
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 50
    gui.LightInfluence = 0
    gui.Parent = board
    local label = Instance.new('TextLabel')
    label.Name = 'Label'
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextScaled = true
    label.TextWrapped = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = palette.ink
    label.Text = spec.text
    label.Parent = gui
end

local function buildPart(row, parent)
    local item = Instance.new('Part')
    item.Name = row.n
    local sx, sy, sz = row.z[1], row.z[2], row.z[3]
    local frame = CFrame.new(row.p[1], row.p[2], row.p[3]) * CFrame.Angles(0, math.rad(row.r), 0)
    if row.s == 'C' then
        item.Shape = Enum.PartType.Cylinder
        item.Size = Vector3.new(sy, sx, sz)
        frame = frame * UPRIGHT
    elseif row.s == 'X' then
        item.Shape = Enum.PartType.Cylinder
        item.Size = Vector3.new(sx, sy, sz)
    elseif row.s == 'S' then
        item.Shape = Enum.PartType.Ball
        item.Size = Vector3.new(sx, sy, sz)
    else
        item.Size = Vector3.new(sx, sy, sz)
    end
    item.CFrame = frame
    item.Color = colorOf(row.c)
    item.Material = Enum.Material[row.mt]
    item.Anchored = true
    local solid = row.role == 'floor' or row.role == 'wall'
    item.CanCollide = solid
    item.CanQuery = solid
    item.CanTouch = false
    item.CastShadow = row.ns ~= true
    item.TopSurface = Enum.SurfaceType.Smooth
    item.BottomSurface = Enum.SurfaceType.Smooth
    if row.t then item.Transparency = row.t end
    setAttributes(item, row.a)
    addTags(item, row.tags)
    if row.l then
        local light = Instance.new('PointLight')
        light.Brightness = row.l[1]
        light.Range = row.l[2]
        light.Color = Color3.fromRGB(row.l[3][1], row.l[3][2], row.l[3][3])
        light.Shadows = false
        light.Parent = item
    end
    if row.sign then addSign(item, row.sign) end
    item.Parent = parent
    return item
end

local function existingHub(parent)
    if parent:FindFirstChild(ROOT_NAME) then return true end
    for _, item in ipairs(CollectionService:GetTagged('WildboundHub')) do
        if item:IsDescendantOf(game) then return true end
    end
    return false
end

-- Builds the hub detached, pivots it so the hub centre lands at `origin` (default: the open-world hub frame origin,
-- layout-v1.json hub.centre), then parents it under `parent`. Returns the WildboundHub Model.
function Builder.build(parent, origin)
    assert(typeof(parent) == 'Instance', 'parent must be an Instance')
    assert(origin == nil or typeof(origin) == 'CFrame', 'origin must be a CFrame')
    assert(not existingHub(parent), ROOT_NAME .. ' already exists')
    origin = origin or CFrame.new(0, 0, 0)
    local root = Instance.new('Model')
    root.Name = ROOT_NAME
    -- Always loaded under StreamingEnabled (open-world doc section 10): a player who spawns never sees an empty plaza,
    -- and clients can read every station tag at once.
    root.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
    local created, lights = 0, 0
    local ok, failure = pcall(function()
        local containers = {}
        for _, spec in ipairs(data.models) do
            local item = Instance.new(spec.kind)
            local parentPath, name = string.match(spec.path, '^(.*)/([^/]+)$')
            item.Name = name or spec.path
            setAttributes(item, spec.a)
            for attr, key in pairs(spec.ca) do item:SetAttribute(attr, colorOf(key)) end
            addTags(item, spec.tags)
            local container = root
            if parentPath then
                container = containers[parentPath]
                assert(container, 'missing parent ' .. parentPath)
            end
            item.Parent = container
            containers[spec.path] = item
            spec.instance = item
        end
        for _, row in ipairs(data.parts) do
            buildPart(row, data.models[row.m].instance)
            created += 1
            if row.l then lights += 1 end
            if created % YIELD_EVERY == 0 then task.wait() end
        end
        for _, spec in ipairs(data.models) do
            if spec.primary then spec.instance.PrimaryPart = spec.instance:FindFirstChild(spec.primary) end
            spec.instance = nil
        end
        assert(created == Builder.EXPECTED_PARTS, 'part count drift: ' .. created)
        assert(lights == Builder.EXPECTED_LIGHTS, 'light count drift: ' .. lights)
    end)
    if not ok then
        root:Destroy()
        error(failure, 0)
    end
    root.WorldPivot = CFrame.new(0, 0, 0)
    root:PivotTo(origin)
    if existingHub(parent) then
        root:Destroy()
        error(ROOT_NAME .. ' appeared during construction', 0)
    end
    root:SetAttribute('Plan', '@@PLANNAME@@')
    root:SetAttribute('PartCount', created)
    root:SetAttribute('LightCount', lights)
    root:SetAttribute('DataAdler32', Builder.DATA_ADLER32)
    root:SetAttribute('SafeRadius', @@SAFE@@)
    CollectionService:AddTag(root, 'WildboundHub')
    root.Parent = parent
    return root
end

return Builder
"""


def render(plan):
    data = data_text(plan)
    if "]==]" in data:
        raise ValueError("plan text would close the Luau long string")
    counts = part_count(plan)
    out = TEMPLATE
    for token, value in (("@@PLANNAME@@", plan["name"]), ("@@PLAN@@", plan["name"] + ".json"), ("@@SEED@@", str(plan["seed"])),
                         ("@@ADLER@@", str(adler32(data))), ("@@PARTS@@", str(counts["total"])),
                         ("@@LIGHTS@@", str(counts["lights"])), ("@@ROOT@@", ROOT_NAME),
                         ("@@TAGS@@", ", ".join("'%s'" % t for t in tags_for(plan))), ("@@SAFE@@", str(plan["hub"]["safe_radius"])),
                         ("@@PALETTE@@", palette_text()), ("@@DATA@@", data)):
        out = out.replace(token, value)
    return out


def report(plan, module_text):
    data = finalize(plan)
    return {
        "name": "hub-kit-report",
        "source": "tools/build-hub-map.py",
        "plan": plan["name"],
        "seed": plan["seed"],
        "status": "unvalidated: the module was never run in Studio by this tool",
        "module": module_path(plan["name"]).name,
        "module_adler32": adler32(module_text),
        "data_adler32": adler32(data_text(plan)),
        "parts": part_count(plan),
        "budget": plan["budget"],
        "tags": {tag: sum(1 for row in data["parts"] if tag in row.get("tags", []))
                 + sum(1 for mdl in data["models"] if tag in mdl["tags"]) for tag in tags_for(plan)},
        "palette": PALETTE,
        "signs": [{"key": row["sign"]["key"], "text": row["sign"]["text"]} for row in data["parts"] if "sign" in row],
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--plan", type=Path, default=PLAN)
    parser.add_argument("--check", action="store_true", help="exit 1 when the written module differs from the plan")
    parser.add_argument("--stdout", action="store_true", help="print the module instead of writing it")
    args = parser.parse_args(argv)
    plan = json.loads(args.plan.read_text(encoding="utf-8"))
    module = render(plan)
    module_file, report_file = module_path(plan["name"]), report_path(plan["name"])
    if args.stdout:
        sys.stdout.buffer.write(module.encode("utf-8"))
        return 0
    if args.check:
        current = module_file.read_text(encoding="utf-8") if module_file.exists() else ""
        if current != module:
            print("stale:", module_file)
            return 1
        print("fresh:", module_file, "adler32", adler32(module))
        return 0
    module_file.write_bytes(module.encode("utf-8"))
    report_file.write_bytes((json.dumps(report(plan, module), indent=1, ensure_ascii=False) + "\n").encode("utf-8"))
    counts = part_count(plan)
    print("wrote", module_file, "adler32", adler32(module))
    print("wrote", report_file)
    print("parts: %d (%s), per base %d, lights %d" % (counts["total"], counts["by_group"], counts["per_base"],
                                                      counts["lights"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())

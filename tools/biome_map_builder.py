#!/usr/bin/env python3
"""Generate one Studio Edit-mode builder per offline biome layout, plus the open-world roads (DESIGN, unvalidated).

    python tools/biome_map_builder.py [--check]

For each layout in assets/maps/<biome>-layout/ that has no builder yet (cryptic ruins, demon abyss, frozen
mountains, living forest, rock caves, volcanic lands) this writes tools/build-wildbound-<biome>-map.luau, and it
writes tools/build-wildbound-open-world-roads.luau for the eight roads from the hub rim. World placement comes
from assets/maps/open-world/biome-placement-v1.json (tools/plan_open_world_layout.py), so a builder drops its
biome where the placement says, for the hub the placement was made for.

Asset route. The forest kit reached Studio as Blender FBX exports uploaded as Model packages (asset ids in
assets/exports/forest-kit/forest-kit-upload-manifest.json) and kept as templates under
ServerStorage.WildboundAssets.ForestKit; tools/dress-wildbound-forest.luau clones them. No other kit was ever
uploaded (their reports say "never imported into Roblox"). So every builder uses the same route: it clones
ServerStorage.WildboundAssets.<Kit> templates by prop name when such a folder exists, and otherwise builds a
primitive-part fallback from the kit report (sizes, colours, occluder and collision boxes). Today no such folder
exists for these six kits, so the fallback is what builds. No asset id is written, nothing is uploaded.

Kit frame to plan frame: local x = -Blender x, local z = Blender y, height = Blender z (the layout planners'
convention); a box yaw in the report is kept as the Roblox yaw (CFrame.Angles(0, math.rad(r), 0)), and a ramp's
pitch (rising toward +Blender y, i.e. +local z) becomes CFrame.Angles(math.rad(-pitch), 0, 0).

Python standard library only. Nothing here touches Studio, and nothing was played or measured on a device.
"""

import argparse
import json
import math
import sys
import zlib
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
REPO = TOOLS.parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import layout_geometry as g  # noqa: E402

PLACEMENT = REPO / "assets" / "maps" / "open-world" / "biome-placement-v1.json"
GENERATOR = "tools/biome_map_builder.py"
ROADS_MODULE = TOOLS / "build-wildbound-open-world-roads.luau"
ROADS_ROOT = "WildboundOpenWorldRoads"
FLOOR_TOP = 0.5
ZONE_HEIGHT = 40.0
DEMON_TILE = 6.0             # chasm holes are cut from the floor on this grid
DEMON_FLOOR_THICK = 10.0     # the bank is a 10-stud slab, so a chasm reads as a drop
GATE_SIGN_OFFSET = 10.0

# key, kit prefix, template folder under ServerStorage.WildboundAssets, kit report
KITS = {
    "cryptic-ruins": ("CR", "CrypticRuinsKit", "assets/blender/cryptic-ruins-kit/cryptic-ruins-kit-report.json"),
    "demon-abyss": ("DA", "DemonAbyssKit", "assets/blender/demon-abyss-kit/demon-abyss-kit-report.json"),
    "frozen-mountains": ("FM", "FrozenMountainsKit", "assets/blender/frozen-mountains-kit/frozen-mountains-kit-report.json"),
    "living-forest": ("LF", "LivingForestKit", "assets/blender/living-forest-kit/living-forest-kit-report.json"),
    "rock-caves": ("RC", "RockCavesKit", "assets/blender/rock-caves-kit/rock-caves-kit-report.json"),
    "volcanic-lands": ("VL", "VolcanicLandsKit", "assets/blender/volcanic-lands-kit/volcanic-lands-kit-report.json"),
}
BIOMES = tuple(KITS)

# Ground look per biome, from the bible palettes (docs/design/wildbound-expansion-bible.md section 2).
GROUND = {
    "cryptic-ruins": {"floor": ("6C7452", "Slate"), "path": ("77717F", "Cobblestone")},
    "demon-abyss": {"floor": ("4A4650", "Basalt"), "path": ("BFB6A6", "Slate"), "void": ("15111B", "Basalt")},
    "frozen-mountains": {"floor": ("E6EFF4", "Snow"), "path": ("566069", "Slate")},
    "living-forest": {"floor": ("6E9445", "Grass"), "path": ("C9A876", "Ground"), "water": ("4F8FB0", "Glass")},
    "rock-caves": {"floor": ("8F8879", "Rock"), "path": ("7D5A42", "Ground")},
    "volcanic-lands": {"floor": ("6F6863", "Basalt"), "path": ("6C7A85", "Slate")},
}
ROAD_LOOK = ("B8A98A", "Cobblestone")

# Fallback shape for every prop the kit report does not fully describe with boxes.
SHAPES = {
    "CR_Colonnade": "boxes+lintel", "CR_BrokenWall": "boxes", "CR_Plinth": "boxes+glow", "CR_Archway": "arch",
    "CR_Reliquary": "block", "CR_GlyphStone": "block+glow", "CR_StairRun": "boxes",
    "DA_FissureLip": "boxes+glow", "DA_FloatRock": "boxes", "DA_ThornSpire": "spire", "DA_RiftGate": "arch",
    "DA_RiftShard": "spire", "DA_CalmStone": "ball+glow",
    "FM_SnowPine": "pine", "FM_IceSpire": "spire", "FM_RockOverhang": "overhang", "FM_ScourShelf": "boxes",
    "FM_Cairn": "cairn", "FM_SnowMound": "mound", "FM_IcePass": "arch",
    "LF_Broadleaf": "tree", "LF_ResinStump": "stump", "LF_FlowerClump": "flowers", "LF_StreamStone": "boxes",
    "LF_HollowArch": "arch", "LF_TrailPost": "post", "LF_LogBridge": "boxes",
    "RC_CaveMouth": "arch", "RC_TunnelStraight": "tunnel", "RC_TunnelBend": "tunnel", "RC_Stalagmite": "spire",
    "RC_CrystalCluster": "spire", "RC_OreVein": "ball+glow", "RC_Burrow": "burrow",
    "VL_BasaltColumn": "boxes", "VL_Vent": "vent", "VL_CoolStone": "boxes", "VL_CharredTree": "charred",
    "VL_AshShrine": "arch", "VL_CrustPlate": "boxes+glow", "VL_ObsidianShard": "spire",
}
TUNNEL_TOP = 18.0            # the tunnel profile's outer top (rock-caves report "snap.profile_loop")
ROOF_THICK = 2.0


def r3(v):
    return round(float(v), 3) + 0.0


def load(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


# ---- Kit frame ------------------------------------------------------------------------------------------
def kit_point(center):
    """Blender (x, y, z) to local (x, y up, z): (-x, z, y)."""
    return (-center[0], center[2], center[1])


def kit_size(size):
    """Blender extents (x, y, z) to Roblox Size (x, y up, z)."""
    return (size[0], size[2], size[1])


def piece(shape, size, pos, color, material="SmoothPlastic", collide=False, query=False, yaw=0.0, pitch=0.0,
          transparency=0.0, role="visual"):
    return {"shape": shape, "size": [r3(max(s, 0.05)) for s in size], "pos": [r3(p) for p in pos], "yaw": r3(yaw),
            "pitch": r3(pitch), "color": color.upper(), "material": material, "collide": bool(collide),
            "query": bool(query), "transparency": r3(transparency), "role": role}


def _colors(entry):
    plain = [p["color_hex"] for p in entry["parts"] if p.get("emission_strength", 0) == 0]
    glow = [p["color_hex"] for p in entry["parts"] if p.get("emission_strength", 0) > 0]
    return plain, glow


def box_pieces(entry, key, collide, query, color, role):
    out = []
    for box in entry.get(key) or []:
        out.append(piece("Block", kit_size(box["size"]), kit_point(box["center"]), color, "Slate" if query else "SmoothPlastic",
                         collide=collide, query=query, yaw=box.get("yaw_deg", 0.0), pitch=-box.get("pitch_deg", 0.0),
                         role=role))
    return out


def prop_pieces(name, entry):
    """Primitive pieces for one kit prop, in its local frame (y up from the ground pivot)."""
    shape = SHAPES[name]
    plain, glow = _colors(entry)
    main = plain[0] if plain else glow[0]
    second = plain[1] if len(plain) > 1 else main
    sx, sy, sz = kit_size(entry["size"])           # width x, height, depth z
    bmin, bmax = entry["bbox_min"], entry["bbox_max"]
    cx, cz = -(bmin[0] + bmax[0]) / 2, (bmin[1] + bmax[1]) / 2
    out = box_pieces(entry, "occluders", True, True, main, "occluder")
    out += box_pieces(entry, "collision_boxes", True, False, second if shape == "tunnel" else main, "walk")
    neon = glow[0] if glow else None

    def glow_cap(height, width):
        if neon:
            out.append(piece("Block", (width, 0.3, width), (cx, height, cz), neon, "Neon", role="glow"))

    if shape in ("boxes", "boxes+glow", "boxes+lintel"):
        if not out:
            out.append(piece("Block", (sx, sy, sz), (cx, sy / 2, cz), main, "Slate", collide=True, query=sy > 6, role="body"))
        if shape == "boxes+glow":
            glow_cap(max(p["pos"][1] + p["size"][1] / 2 for p in out) + 0.15, min(sx, sz) * 0.5)
        if shape == "boxes+lintel":
            top = max(p["pos"][1] + p["size"][1] / 2 for p in out)
            out.append(piece("Block", (sx, sy - top, sz * 0.8), (cx, (top + sy) / 2, cz), second, "Slate", collide=True, role="lintel"))
    elif shape == "block" or shape == "block+glow":
        out.append(piece("Block", (sx, sy, sz), (cx, sy / 2, cz), main, "Slate", collide=True, role="body"))
        if shape == "block+glow":
            out.append(piece("Block", (sx * 0.6, sy * 0.4, 0.2), (cx, sy * 0.6, cz - sz / 2 - 0.1), neon or main, "Neon", role="glow"))
    elif shape == "arch":
        clear = entry["clearance"]
        h = clear["height"]
        if not entry.get("occluders"):
            for lo, hi in ((-sx / 2, clear["gap_low_x"]), (clear["gap_high_x"], sx / 2)):
                # Report gap edges are Blender x; local x is mirrored.
                a, b = sorted((-lo, -hi))
                out.append(piece("Block", (b - a, h, sz * 0.8), ((a + b) / 2, h / 2, cz), main, "Slate", collide=True,
                                 query=True, role="pier"))
        out.append(piece("Block", (sx, max(sy - h, 1.0), sz * 0.8), (cx, h + max(sy - h, 1.0) / 2, cz), second, "Slate",
                         collide=True, role="lintel"))
        if neon:
            out.append(piece("Block", (clear["width"] * 0.8, 0.4, 0.4), (cx, h + 0.3, cz - sz * 0.4 - 0.2), neon, "Neon", role="glow"))
    elif shape == "tunnel":
        walks = [p for p in out if p["role"] == "walk"]
        for w in walks:
            out.append(piece("Block", (24.0, ROOF_THICK, w["size"][2] + 0.2), (w["pos"][0], TUNNEL_TOP - ROOF_THICK / 2, w["pos"][2]),
                             main, "Slate", collide=True, query=True, yaw=w["yaw"], role="roof"))
        for w in walks:     # outer shells close the profile's shoulders above the walls
            out.append(piece("Block", (24.0, 6.0, w["size"][2] + 0.2), (w["pos"][0], 12.0 + 3.0 - ROOF_THICK / 2, w["pos"][2]),
                             main, "Slate", collide=True, query=True, yaw=w["yaw"], role="shell", transparency=0.0))
    elif shape in ("tree", "pine", "charred"):
        trunk_w = max(1.2, min(sx, sz) * (0.16 if shape != "charred" else 0.12))
        trunk_h = sy * (0.55 if shape == "tree" else 0.45 if shape == "pine" else 0.9)
        out.append(piece("Cylinder", (trunk_h, trunk_w, trunk_w), (cx, trunk_h / 2, cz), main, "Wood", collide=True, query=True,
                         pitch=0.0, role="trunk"))
        out[-1]["upright"] = True
        if shape == "tree":
            out.append(piece("Ball", (sx * 0.9, sy * 0.55, sz * 0.9), (cx, sy * 0.68, cz), second, "Grass", role="crown"))
        elif shape == "pine":
            for k, f in enumerate((1.0, 0.72, 0.44)):
                out.append(piece("Ball", (sx * f, sy * 0.3, sz * f), (cx, sy * (0.38 + 0.2 * k), cz), second, "Grass", role="crown"))
            snow = plain[2] if len(plain) > 2 else "E6EFF4"
            out.append(piece("Ball", (sx * 0.3, sy * 0.12, sz * 0.3), (cx, sy * 0.92, cz), snow, "Snow", role="snow"))
        else:
            for k, a in enumerate((0.0, 120.0, 240.0)):
                r = math.radians(a)
                out.append(piece("Block", (sx * 0.4, 0.8, 0.8), (cx + math.cos(r) * sx * 0.18, sy * (0.55 + 0.1 * k), cz + math.sin(r) * sz * 0.18),
                                 main, "Wood", yaw=-a, role="branch"))
            glow_cap(0.2, trunk_w * 1.6)
    elif shape == "spire":
        for k, f in enumerate((1.0, 0.62, 0.3)):
            out.append(piece("Block", (sx * f * 0.8, sy / 3, sz * f * 0.8), (cx, sy / 6 + k * sy / 3, cz), (neon if neon and k > 0 else main),
                             "Neon" if (neon and k > 0) else "Slate", collide=k == 0, yaw=45.0 * k, role="spire"))
    elif shape == "ball+glow":
        out.append(piece("Ball", (sx, sy, sz), (cx, sy / 2, cz), main, "Slate", collide=True, role="body"))
        if neon:
            out.append(piece("Ball", (sx * 0.35, sy * 0.35, sz * 0.35), (cx, sy * 0.85, cz), neon, "Neon", role="glow"))
        elif len(plain) > 1:
            out.append(piece("Ball", (sx * 0.4, sy * 0.4, sz * 0.4), (cx, sy * 0.6, cz - sz * 0.35), plain[1], "Slate", role="accent"))
    elif shape == "overhang":
        out.append(piece("Wedge", (sx, sy * 0.5, sz), (cx, sy * 0.75, cz), second, "Snow", collide=True, role="cap"))
    elif shape == "cairn":
        for k, f in enumerate((1.0, 0.75, 0.5)):
            out.append(piece("Ball", (sx * f, sy * 0.33, sz * f), (cx, sy * (0.17 + 0.3 * k), cz), main, "Slate", collide=k == 0, role="stone"))
        out.append(piece("Block", (0.2, sy * 0.3, sz * 0.6), (cx + sx * 0.3, sy * 0.6, cz), plain[1] if len(plain) > 1 else main, "Fabric", role="ribbon"))
    elif shape == "mound":
        out.append(piece("Ball", (sx, sy * 2, sz), (cx, 0.0, cz), main, "Snow", collide=True, role="mound"))
    elif shape == "stump":
        out.append(piece("Cylinder", (sy * 0.8, sx * 0.8, sx * 0.8), (cx, sy * 0.4, cz), main, "Wood", collide=True, role="stump"))
        out[-1]["upright"] = True
        out.append(piece("Ball", (sx * 0.3, sy * 0.25, sz * 0.3), (cx, sy * 0.85, cz), second, "Glass", role="resin"))
    elif shape == "flowers":
        for k in range(5):
            a = math.radians(72 * k)
            out.append(piece("Ball", (1.2, 1.2, 1.2), (cx + math.cos(a) * sx * 0.3, sy * 0.6, cz + math.sin(a) * sz * 0.3), second, "SmoothPlastic", role="petal"))
        out.append(piece("Block", (sx * 0.7, sy * 0.4, sz * 0.7), (cx, sy * 0.2, cz), main, "Grass", role="stems"))
    elif shape == "post":
        out.append(piece("Block", (sx * 0.25, sy, sz * 0.25), (cx, sy / 2, cz), main, "Wood", role="post"))
        out.append(piece("Block", (sx * 0.5, sy * 0.15, sz * 0.3), (cx, sy * 0.8, cz), second, "Fabric", role="ribbon"))
    elif shape == "burrow":
        out.append(piece("Cylinder", (sy, sx, sz), (cx, sy / 2, cz), main, "Ground", role="rim"))
        out[-1]["upright"] = True
        hole = plain[1] if len(plain) > 1 else "121214"
        out.append(piece("Cylinder", (0.2, sx * 0.6, sz * 0.6), (cx, sy + 0.05, cz), hole, "SmoothPlastic", role="hole"))
        out[-1]["upright"] = True
    elif shape == "vent":
        out.append(piece("Cylinder", (sy, sx * 0.8, sz * 0.8), (cx, sy / 2, cz), main, "Basalt", role="cone"))
        out[-1]["upright"] = True
        out.append(piece("Cylinder", (0.2, sx * 0.4, sz * 0.4), (cx, sy + 0.1, cz), neon or main, "Neon", role="glow"))
        out[-1]["upright"] = True
    else:
        raise ValueError("no fallback shape for " + name)
    for p in out:
        p.setdefault("upright", False)
        if p["material"] == "Neon":
            p["collide"] = False
            p["query"] = False
    return out


def kit_recipes(key):
    report = load(REPO / KITS[key][2])["props"]
    return {name: prop_pieces(name, entry) for name, entry in report.items()}


# ---- Ground, features, zones -----------------------------------------------------------------------------
def segment_box(a, b, width, y, thick, color, material, folder, name, transparency=0.0, collide=True, caps=True):
    dx, dz = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dz)
    yaw = math.degrees(math.atan2(dx, dz))          # local +Z along the segment
    return {"folder": folder, "name": name, "x": r3((a[0] + b[0]) / 2), "y": r3(y), "z": r3((a[1] + b[1]) / 2),
            "sx": r3(width), "sy": r3(thick), "sz": r3(length + (width if caps else 0.0)), "yaw": r3(yaw), "color": color,
            "material": material, "collide": collide, "transparency": r3(transparency)}


def oriented_rect(poly):
    p0, p1, p3 = poly[0], poly[1], poly[3]
    e1 = (p1[0] - p0[0], p1[1] - p0[1])
    e2 = (p3[0] - p0[0], p3[1] - p0[1])
    cx = sum(p[0] for p in poly) / len(poly)
    cz = sum(p[1] for p in poly) / len(poly)
    yaw = math.degrees(math.atan2(-e1[1], e1[0]))     # local +X -> (cos r, -sin r)
    return (cx, cz, math.hypot(*e1), math.hypot(*e2), yaw)


def chasm_polys(layout):
    return [[tuple(p) for p in c["polygon"]] for c in layout.get("hazards", {}).get("chasms", [])] if "chasms" in layout.get("hazards", {}) else []


def floor_rows(key, layout):
    size = layout["map_size"]
    half = size / 2
    color, material = GROUND[key]["floor"]
    if key != "demon-abyss":
        return [{"x": 0.0, "z": 0.0, "sx": size, "sz": size, "thick": 1.0, "color": color, "material": material}]
    polys = chasm_polys(layout)
    rows = []
    n = int(round(size / DEMON_TILE))
    for j in range(n):
        z = -half + (j + 0.5) * DEMON_TILE
        run = None
        for i in range(n + 1):
            x = -half + (i + 0.5) * DEMON_TILE
            solid = i < n and not any(g.point_in_polygon(poly, (x, z)) for poly in polys)
            if solid and run is None:
                run = i
            elif not solid and run is not None:
                x0, x1 = -half + run * DEMON_TILE, -half + i * DEMON_TILE
                rows.append({"x": r3((x0 + x1) / 2), "z": r3(z), "sx": r3(x1 - x0), "sz": DEMON_TILE,
                             "thick": DEMON_FLOOR_THICK, "color": color, "material": material})
                run = None
    void, vmat = GROUND[key]["void"]
    rows.append({"x": 0.0, "z": 0.0, "sx": size, "sz": size, "thick": 1.0, "color": void, "material": vmat,
                 "y_top": FLOOR_TOP - DEMON_FLOOR_THICK})
    return rows


def route_paths(key, layout):
    color, material = GROUND[key]["path"]
    width = layout["route"].get("corridor_width", 14.0)
    lines = [r["nodes"] for r in layout["surface_routes"]] if key == "rock-caves" else [layout["route"]["nodes"]]
    polys = chasm_polys(layout)
    out = []
    for li, nodes in enumerate(lines):
        for k, (a, b) in enumerate(zip(nodes, nodes[1:])):
            for m, (c, d) in enumerate(solid_spans(a, b, polys)):
                name = "Path%d_%d" % (li + 1, k + 1) + ("" if m == 0 else "_%d" % (m + 1))
                out.append(segment_box(c, d, width, FLOOR_TOP + 0.05, 0.1, color, material, "Paths", name, caps=not polys))
    return out


def solid_spans(a, b, polys, step=1.0):
    """Parts of segment a-b outside every chasm polygon (the path never bridges a chasm)."""
    if not polys:
        return [(a, b)]
    L = math.dist(a, b)
    n = max(1, int(math.ceil(L / step)))
    pts = [(a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n) for k in range(n + 1)]
    inside = [any(g.point_in_polygon(poly, q) for poly in polys) for q in pts]
    spans, start = [], None
    for k, hole in enumerate(inside):
        if not hole and start is None:
            start = k
        if (hole or k == n) and start is not None:
            end = k - 1 if hole else k
            if end > start:
                spans.append((pts[start], pts[end]))
            start = None
    return spans


def feature_boxes(key, layout):
    out = route_paths(key, layout)
    if key == "living-forest":
        color, material = GROUND[key]["water"]
        for s in layout["streams"]:
            for k, (a, b) in enumerate(zip(s["nodes"], s["nodes"][1:])):
                out.append(segment_box(a, b, s["water_width"], FLOOR_TOP + 0.03, 0.1, color, material, "Water",
                                       "%s_%d" % (s["name"], k + 1), transparency=0.3))
    return out


def zone_rows(key, layout):
    size = layout["map_size"]
    rows = [{"kind": "Region", "id": key, "x": 0.0, "z": 0.0, "sx": size, "sz": size, "yaw": 0.0, "shape": "Block", "attrs": ""}]
    hazards = layout.get("hazards", {})
    for c in hazards.get("chasms", []):
        cx, cz, a, b, yaw = oriented_rect(c["polygon"])
        rows.append({"kind": "Chasm", "id": c["id"], "x": r3(cx), "z": r3(cz), "sx": r3(a), "sz": r3(b), "yaw": r3(yaw),
                     "shape": "Block", "attrs": "HopGap=%s" % c["hop_gap"]})
    if "vents" in hazards:
        cyc = hazards["vent_cycle"]
        for v in hazards["vents"]:
            rows.append({"kind": "Vent", "id": v["id"], "x": v["x"], "z": v["z"], "sx": 2 * cyc["radius"], "sz": 2 * cyc["radius"],
                         "yaw": 0.0, "shape": "Cylinder",
                         "attrs": "PhaseS=%s;CalmS=%s;GlowS=%s;EruptS=%s" % (v["phase_s"], cyc["calm_s"], cyc["glow_s"], cyc["erupt_s"])})
    for lane in layout.get("rockfall", {}).get("lanes", []):
        rows.append({"kind": "Rockfall", "id": lane["id"], "x": lane["center"][0], "z": lane["center"][1],
                     "sx": lane["size"][0], "sz": lane["size"][1], "yaw": lane["rotation_y_deg"], "shape": "Block",
                     "attrs": "DustS=%s;ImpactS=%s;CycleS=%s" % (layout["rockfall"]["dust_s"], layout["rockfall"]["impact_s"], lane["cycle_s"])})
    for rect in layout.get("no_track_rects", []):
        rows.append({"kind": "NoTrack", "id": rect["source"], "x": rect["center"][0], "z": rect["center"][1],
                     "sx": rect["size"][0], "sz": rect["size"][1], "yaw": rect["yaw"], "shape": "Block", "attrs": ""})
    for s in layout.get("streams", []):
        for k, (a, b) in enumerate(zip(s["nodes"], s["nodes"][1:])):
            box = segment_box(a, b, s["water_width"], 0, 0, "", "", "", "")
            rows.append({"kind": "Stream", "id": "%s_%d" % (s["name"], k + 1), "x": box["x"], "z": box["z"], "sx": box["sx"],
                         "sz": box["sz"], "yaw": box["yaw"], "shape": "Block", "attrs": "WalkSpeed=10"})
    return rows


def marker_rows(key, layout):
    route = layout["route"]
    names = route.get("names") or []
    rows = [{"name": "GateMarker", "x": route["nodes"][0][0], "z": route["nodes"][0][1]},
            {"name": "ExitMarker", "x": route["nodes"][-1][0], "z": route["nodes"][-1][1]}]
    if names and len(names) == len(route["nodes"]):
        for name, node in zip(names[1:-1], route["nodes"][1:-1]):
            rows.append({"name": "Route_" + name, "x": node[0], "z": node[1]})
    for poi in layout.get("points_of_interest", []):
        rows.append({"name": "Poi_" + poi["name"], "x": poi["point"][0], "z": poi["point"][1]})
    if "yeti_home" in layout:
        rows.append({"name": "YetiHomeMarker", "x": layout["yeti_home"][0], "z": layout["yeti_home"][1]})
    for k, p in enumerate(layout.get("vigia", {}).get("chain", [])):
        rows.append({"name": "VigiaChain_%02d" % (k + 1), "x": p[0], "z": p[1]})
    return rows


def gate_sign(layout):
    nodes = layout["route"]["nodes"]
    a, b = nodes[0], nodes[1]
    dx, dz = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dz)
    ux, uz = dx / L, dz / L
    px, pz = -uz, ux                                     # to the side of the trail
    x, z = a[0] + px * GATE_SIGN_OFFSET, a[1] + pz * GATE_SIGN_OFFSET
    # The board's front (local -Z) faces back along the trail, toward an arriving player.
    yaw = math.degrees(math.atan2(ux, uz))
    return {"x": r3(x), "z": r3(z), "yaw": r3(yaw)}


def instance_rows(key, layout):
    polys = chasm_polys(layout)
    rows = []
    for inst in layout["instances"]:
        y = 0.0
        if any(g.point_in_polygon(poly, (inst["x"], inst["z"])) for poly in polys):
            if inst["name"] == "DA_FloatRock":
                y = -6.0 * inst["scale"]                 # walk box top (6) flush with the bank
            else:
                y = -DEMON_FLOOR_THICK                   # anything else in a chasm stands on the drop's floor
        rows.append({"id": inst["id"], "name": inst["name"], "x": r3(inst["x"]), "y": r3(y), "z": r3(inst["z"]),
                     "yaw": r3(inst["rotation_y_deg"]), "scale": r3(inst["scale"])})
    return rows


# ---- Luau rendering --------------------------------------------------------------------------------------
def fmt(v):
    if isinstance(v, bool):
        return "1" if v else "0"
    if isinstance(v, float):
        return repr(r3(v))
    return str(v)


def rows_text(rows, fields):
    return "\n".join("|".join(fmt(r[f]) for f in fields) for r in rows)


INSTANCE_FIELDS = ("id", "name", "x", "y", "z", "yaw", "scale")
PIECE_FIELDS = ("prop", "shape", "sx", "sy", "sz", "px", "py", "pz", "yaw", "pitch", "color", "material", "collide",
                "query", "transparency", "upright")
FLOOR_FIELDS = ("x", "z", "sx", "sz", "thick", "top", "color", "material")
BOX_FIELDS = ("folder", "name", "x", "y", "z", "sx", "sy", "sz", "yaw", "color", "material", "collide", "transparency")
ZONE_FIELDS = ("kind", "id", "x", "z", "sx", "sz", "yaw", "shape", "attrs")
MARKER_FIELDS = ("name", "x", "z")


def recipe_rows(recipes, used):
    rows = []
    for name in sorted(used):
        for p in recipes[name]:
            rows.append({"prop": name, "shape": p["shape"], "sx": p["size"][0], "sy": p["size"][1], "sz": p["size"][2],
                         "px": p["pos"][0], "py": p["pos"][1], "pz": p["pos"][2], "yaw": p["yaw"], "pitch": p["pitch"],
                         "color": p["color"], "material": p["material"], "collide": p["collide"], "query": p["query"],
                         "transparency": p["transparency"], "upright": p["upright"]})
    return rows


def adler32(text):
    return zlib.adler32(text.encode("utf-8")) & 0xFFFFFFFF


def biome_data(key, placement):
    biome = placement["biomes"][key]
    layout = load(REPO / biome["layout"])
    recipes = kit_recipes(key)
    instances = instance_rows(key, layout)
    used = {r["name"] for r in instances}
    floors = []
    for f in floor_rows(key, layout):
        f = dict(f)
        f["top"] = f.pop("y_top", FLOOR_TOP)
        floors.append(f)
    return {"biome": biome, "layout": layout, "recipes": recipes, "instances": instances,
            "pieces": recipe_rows(recipes, used), "floors": floors, "boxes": feature_boxes(key, layout),
            "zones": zone_rows(key, layout), "markers": marker_rows(key, layout), "sign": gate_sign(layout)}


def placement_block(biome, hub):
    return ("Builder.PLACEMENT = table.freeze({ worldX = %s, worldZ = %s, yawDeg = %s, mapSize = %s, hubX = %s, hubZ = %s, "
            "hubRadius = %s })" % (fmt(float(biome["world_centre"][0])), fmt(float(biome["world_centre"][1])),
                                   fmt(float(biome["yaw_deg"])), fmt(float(biome["map_size"])), fmt(float(hub["centre"][0])),
                                   fmt(float(hub["centre"][1])), fmt(float(hub["radius"]))))


def luau_string(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def render_biome(key, placement):
    d = biome_data(key, placement)
    biome, layout = d["biome"], d["layout"]
    prefix, folder, report = KITS[key]
    blocks = {
        "INSTANCES": rows_text(d["instances"], INSTANCE_FIELDS),
        "PIECES": rows_text(d["pieces"], PIECE_FIELDS),
        "FLOORS": rows_text(d["floors"], FLOOR_FIELDS),
        "BOXES": rows_text(d["boxes"], BOX_FIELDS),
        "ZONES": rows_text(d["zones"], ZONE_FIELDS),
        "MARKERS": rows_text(d["markers"], MARKER_FIELDS),
    }
    data = "".join(blocks[k] for k in sorted(blocks))
    for k, text in blocks.items():
        assert "]==]" not in text, k
    head = HEADER.format(layout=biome["layout"], seed=layout["seed"], adler=adler32(data), display=biome["display_name"],
                         count=len(d["instances"]), report=report, folder=folder)
    body = BIOME_TEMPLATE
    repl = {
        "@@KEY@@": luau_string(key), "@@ROOT@@": luau_string(biome["root_name"]),
        "@@DISPLAY@@": luau_string(biome["display_name"]), "@@KIT@@": luau_string(prefix),
        "@@FOLDER@@": luau_string(folder), "@@GENERATOR@@": luau_string(GENERATOR),
        "@@PLACEMENT_NAME@@": luau_string(placement["name"]), "@@SEED@@": str(layout["seed"]),
        "@@PLACEMENT@@": placement_block(biome, placement["hub"]),
        "@@SIGN@@": "{ text = %s, x = %s, z = %s, yaw = %s }" % (luau_string(biome["display_name"]), fmt(d["sign"]["x"]),
                                                                fmt(d["sign"]["z"]), fmt(d["sign"]["yaw"])),
    }
    for k, v in repl.items():
        body = body.replace(k, v)
    for k, text in blocks.items():
        body = body.replace("@@%s@@" % k, text)
    return head + COMMON + body


def roads_data(placement):
    rows = []
    color, material = ROAD_LOOK
    for key, road in placement["roads"].items():
        nodes = road["nodes_world"]
        for k, (a, b) in enumerate(zip(nodes, nodes[1:])):
            box = segment_box(a, b, road["width"], FLOOR_TOP + 0.06, 0.12, color, material, key, "Road_%s_%d" % (key, k + 1))
            rows.append(box)
    gates = [{"name": "Gate_" + key, "x": b["gate_world"][0], "z": b["gate_world"][1]} for key, b in placement["biomes"].items()]
    return rows, gates


def render_roads(placement):
    rows, gates = roads_data(placement)
    boxes, markers = rows_text(rows, BOX_FIELDS), rows_text(gates, MARKER_FIELDS)
    hub = placement["hub"]
    head = ROADS_HEADER.format(adler=adler32(boxes + markers), count=len(placement["roads"]))
    body = ROADS_TEMPLATE
    for k, v in {"@@ROOT@@": luau_string(ROADS_ROOT), "@@GENERATOR@@": luau_string(GENERATOR),
                 "@@PLACEMENT_NAME@@": luau_string(placement["name"]),
                 "@@HUB@@": "Builder.HUB = table.freeze({ hubX = %s, hubZ = %s, hubRadius = %s })" % (
                     fmt(float(hub["centre"][0])), fmt(float(hub["centre"][1])), fmt(float(hub["radius"]))),
                 "@@BOXES@@": boxes, "@@MARKERS@@": markers}.items():
        body = body.replace(k, v)
    return head + COMMON + body


def module_path(key):
    return TOOLS / ("build-wildbound-%s-map.luau" % key)


def outputs(placement=None):
    placement = placement or load(PLACEMENT)
    out = {module_path(key): render_biome(key, placement) for key in BIOMES}
    out[ROADS_MODULE] = render_roads(placement)
    return out


HEADER = """-- GENERATED by tools/biome_map_builder.py from {layout} (seed {seed}) and
-- assets/maps/open-world/biome-placement-v1.json (data Adler-32 {adler}). Do not edit by hand: change the planner,
-- the placement or the generator, then regenerate.
-- {display}: a Studio Edit-mode builder for one open-world biome, {count} kit props. Run it once from the command bar:
--     require(game.ServerStorage.WildboundBiomeBuilders.<this module>).run()
-- It reuses or replaces only its own root model (same name and GeneratedBy attribute), builds under Workspace at the
-- placement, and adds no scripts. Props clone ServerStorage.WildboundAssets.{folder} templates by name when that folder
-- exists (the forest kit's route); otherwise each prop is a primitive-part fallback from {report}.
-- No MeshParts are created, no asset ids, no uploads. Player-facing words are neutral Spanish; code is English.
"""

ROADS_HEADER = """-- GENERATED by tools/biome_map_builder.py from assets/maps/open-world/biome-placement-v1.json (data Adler-32 {adler}).
-- Do not edit by hand. The {count} open-world roads from the hub rim to each biome's entry gate, as anchored
-- collidable primitive slabs. Run once from the command bar in Edit mode:
--     require(game.ServerStorage.WildboundBiomeBuilders.<this module>).run()
-- It reuses or replaces only its own root model and adds no scripts.
"""

COMMON = r"""local Builder = {}

local CollectionService = game:GetService('CollectionService')
local RunService = game:GetService('RunService')
local ServerStorage = game:GetService('ServerStorage')
local ServerScriptService = game:GetService('ServerScriptService')

local FLOOR_TOP = 0.5
local ZONE_HEIGHT = 40
local YIELD_EVERY = 250

local created = 0

-- Only these fields are numbers; ids, names, colours ('4E5050' would read as 4e5050) and materials stay strings.
local NUMERIC = { x = true, y = true, z = true, sx = true, sy = true, sz = true, px = true, py = true, pz = true,
    yaw = true, pitch = true, scale = true, thick = true, top = true, collide = true, query = true,
    transparency = true, upright = true }

local function rows(text, fields)
    local out = {}
    for line in string.gmatch(text, '[^\n]+') do
        local values = string.split(line, '|')
        assert(#values == #fields, 'bad row: ' .. line)
        local row = {}
        for index, field in ipairs(fields) do
            local value = values[index]
            if NUMERIC[field] then
                row[field] = assert(tonumber(value), 'bad number in row: ' .. line)
            else
                row[field] = value
            end
        end
        table.insert(out, row)
    end
    return out
end

local function hex(text)
    return Color3.fromRGB(tonumber(text:sub(1, 2), 16), tonumber(text:sub(3, 4), 16), tonumber(text:sub(5, 6), 16))
end

local function folder(parent, name)
    local existing = parent:FindFirstChild(name)
    if existing then return existing end
    local item = Instance.new('Folder')
    item.Name = name
    item.Parent = parent
    return item
end

local SHAPES = { Ball = Enum.PartType.Ball, Cylinder = Enum.PartType.Cylinder, Block = Enum.PartType.Block }

local function part(parent, name, shape, size, frame, color, material, collide, query, transparency)
    local item
    if shape == 'Wedge' then
        item = Instance.new('WedgePart')
    else
        item = Instance.new('Part')
        item.Shape = SHAPES[shape] or Enum.PartType.Block
    end
    item.Name = name
    item.Size = size
    item.CFrame = frame
    item.Color = color
    item.Material = Enum.Material[material] or Enum.Material.SmoothPlastic
    item.Anchored = true
    item.CanCollide = collide == true
    item.CanQuery = query == true
    item.CanTouch = false
    item.Transparency = transparency or 0
    item.TopSurface = Enum.SurfaceType.Smooth
    item.BottomSurface = Enum.SurfaceType.Smooth
    if material == 'Neon' then item.CastShadow = false end
    item.Parent = parent
    created += 1
    if created % YIELD_EVERY == 0 then task.wait() end
    return item
end

local function boxRow(parent, row)
    return part(folder(parent, row.folder), row.name, 'Block', Vector3.new(row.sx, row.sy, row.sz),
        CFrame.new(row.x, row.y, row.z) * CFrame.Angles(0, math.rad(row.yaw), 0), hex(row.color), row.material,
        row.collide == 1, row.collide == 1, row.transparency)
end

local function sign(parent, spec)
    local base = CFrame.new(spec.x, FLOOR_TOP, spec.z) * CFrame.Angles(0, math.rad(spec.yaw), 0)
    part(parent, 'SignPost', 'Block', Vector3.new(0.5, 5, 0.5), base * CFrame.new(0, 2.5, 0), hex('6B4A2F'), 'Wood', true, false)
    local board = part(parent, 'SignBoard', 'Block', Vector3.new(8, 2, 0.3), base * CFrame.new(0, 5, 0), hex('6B4A2F'), 'WoodPlanks', true, false)
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
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.fromRGB(245, 236, 220)
    label.Text = spec.text
    label.Parent = gui
    return board
end

-- The hub this placement was generated for must be the one the game uses (Rules.HUB_X, HUB_Z, HUB_RADIUS).
local function checkHub(expected)
    local module = ServerScriptService:FindFirstChild('WildboundWorldRules')
    if not (module and module:IsA('ModuleScript')) then
        warn('[' .. Builder.ROOT_NAME .. '] ServerScriptService.WildboundWorldRules not found; hub not checked')
        return
    end
    local ok, rules = pcall(require, module)
    if not ok or type(rules) ~= 'table' then
        warn('[' .. Builder.ROOT_NAME .. '] WildboundWorldRules did not load; hub not checked')
        return
    end
    if rules.HUB_X ~= expected.hubX or rules.HUB_Z ~= expected.hubZ or rules.HUB_RADIUS ~= expected.hubRadius then
        error(string.format('%s: placement made for hub (%s, %s) r %s but Rules has (%s, %s) r %s; regenerate with '
            .. 'python tools/plan_open_world_layout.py --placement-only and python tools/biome_map_builder.py',
            Builder.ROOT_NAME, expected.hubX, expected.hubZ, expected.hubRadius, tostring(rules.HUB_X),
            tostring(rules.HUB_Z), tostring(rules.HUB_RADIUS)), 0)
    end
end

-- Reuse or replace: only a root with this name AND this generator's attributes is ever removed.
local function ownRoot(parent)
    local existing = parent:FindFirstChild(Builder.ROOT_NAME)
    if existing == nil then return nil end
    if existing:GetAttribute('GeneratedBy') ~= Builder.GENERATED_BY or existing:GetAttribute('BuilderKey') ~= Builder.KEY then
        error(Builder.ROOT_NAME .. ' exists but was not built by ' .. Builder.GENERATED_BY .. '; refusing to replace it', 0)
    end
    return existing
end

local function withHistory(label, fn)
    local ok, history = pcall(function() return game:GetService('ChangeHistoryService') end)
    local recording
    if ok and history then
        local began, id = pcall(function() return history:TryBeginRecording(label) end)
        if began then recording = id end
    end
    local success, result = pcall(fn)
    if recording then
        pcall(function()
            history:FinishRecording(recording, success and Enum.FinishRecordingOperation.Commit
                or Enum.FinishRecordingOperation.Cancel)
        end)
    end
    if not success then error(result, 0) end
    return result
end

"""

BIOME_TEMPLATE = r"""Builder.KEY = @@KEY@@
Builder.ROOT_NAME = @@ROOT@@
Builder.DISPLAY_NAME = @@DISPLAY@@
Builder.KIT = @@KIT@@
Builder.TEMPLATE_FOLDER = @@FOLDER@@
Builder.GENERATED_BY = @@GENERATOR@@
Builder.PLACEMENT_NAME = @@PLACEMENT_NAME@@
Builder.SEED = @@SEED@@
@@PLACEMENT@@

local SIGN = @@SIGN@@

local INSTANCES = [==[
@@INSTANCES@@
]==]

local PIECES = [==[
@@PIECES@@
]==]

local FLOORS = [==[
@@FLOORS@@
]==]

local BOXES = [==[
@@BOXES@@
]==]

local ZONES = [==[
@@ZONES@@
]==]

local MARKERS = [==[
@@MARKERS@@
]==]

local recipes = {}
for _, piece in ipairs(rows(PIECES, { 'prop', 'shape', 'sx', 'sy', 'sz', 'px', 'py', 'pz', 'yaw', 'pitch', 'color',
    'material', 'collide', 'query', 'transparency', 'upright' })) do
    recipes[piece.prop] = recipes[piece.prop] or {}
    table.insert(recipes[piece.prop], piece)
end

local function templates()
    local assets = ServerStorage:FindFirstChild('WildboundAssets')
    return assets and assets:FindFirstChild(Builder.TEMPLATE_FOLDER) or nil
end

-- One prop: a clone of the uploaded kit template when it exists, else the primitive fallback.
local function buildProp(parent, inst, kit)
    local pose = CFrame.new(inst.x, FLOOR_TOP + inst.y, inst.z) * CFrame.Angles(0, math.rad(inst.yaw), 0)
    local template = kit and kit:FindFirstChild(inst.name)
    if template and template:IsA('Model') then
        local model = template:Clone()
        for _, link in ipairs(model:GetDescendants()) do
            if link:IsA('PackageLink') then link:Destroy() end
        end
        model.Name = inst.id
        if inst.scale ~= 1 then model:ScaleTo(inst.scale) end
        model:PivotTo(pose)
        model:SetAttribute('AssetRoute', 'template')
        model.Parent = parent
        return model
    end
    local list = recipes[inst.name]
    assert(list, 'no fallback recipe for ' .. tostring(inst.name))
    local model = Instance.new('Model')
    model.Name = inst.id
    local s = inst.scale
    for index, p in ipairs(list) do
        local size = Vector3.new(p.sx * s, p.sy * s, p.sz * s)
        local frame = pose * CFrame.new(p.px * s, p.py * s, p.pz * s) * CFrame.Angles(0, math.rad(p.yaw), 0)
            * CFrame.Angles(math.rad(p.pitch), 0, 0)
        if p.upright == 1 then frame = frame * CFrame.Angles(0, 0, math.rad(90)) end -- a Cylinder's axis is X
        part(model, inst.name .. '_' .. index, p.shape, size, frame, hex(p.color), p.material, p.collide == 1,
            p.query == 1, p.transparency)
    end
    model:SetAttribute('AssetRoute', 'primitive')
    model.Parent = parent
    return model
end

local function buildGround(root)
    local ground = folder(root, 'Ground')
    for index, f in ipairs(rows(FLOORS, { 'x', 'z', 'sx', 'sz', 'thick', 'top', 'color', 'material' })) do
        part(ground, 'Floor' .. index, 'Block', Vector3.new(f.sx, f.thick, f.sz), CFrame.new(f.x, f.top - f.thick / 2, f.z),
            hex(f.color), f.material, true, true)
    end
    for _, row in ipairs(rows(BOXES, { 'folder', 'name', 'x', 'y', 'z', 'sx', 'sy', 'sz', 'yaw', 'color', 'material',
        'collide', 'transparency' })) do
        boxRow(root, row)
    end
end

local function buildZones(root)
    local zones = folder(root, 'Zones')
    for _, z in ipairs(rows(ZONES, { 'kind', 'id', 'x', 'z', 'sx', 'sz', 'yaw', 'shape', 'attrs' })) do
        local frame = CFrame.new(z.x, FLOOR_TOP + ZONE_HEIGHT / 2, z.z) * CFrame.Angles(0, math.rad(z.yaw), 0)
        local size = Vector3.new(z.sx, ZONE_HEIGHT, z.sz)
        if z.shape == 'Cylinder' then
            frame = frame * CFrame.Angles(0, 0, math.rad(90))
            size = Vector3.new(ZONE_HEIGHT, z.sx, z.sz)
        end
        local item = part(zones, z.kind .. '_' .. tostring(z.id), z.shape, size, frame, hex('FFFFFF'), 'SmoothPlastic',
            false, false, 1)
        item:SetAttribute('Biome', Builder.KEY)
        item:SetAttribute('Kind', z.kind)
        item:SetAttribute('ZoneId', tostring(z.id))
        if type(z.attrs) == 'string' and z.attrs ~= '' then
            for _, pair in ipairs(string.split(z.attrs, ';')) do
                local name, value = pair:match('^(%w+)=(.+)$')
                if name then item:SetAttribute(name, tonumber(value) or value) end
            end
        end
        CollectionService:AddTag(item, 'WildboundBiomeZone')
        if z.kind ~= 'Region' then CollectionService:AddTag(item, 'WildboundBiomeHazard') end
    end
end

local function buildMarkers(root)
    local markers = folder(root, 'Markers')
    for _, m in ipairs(rows(MARKERS, { 'name', 'x', 'z' })) do
        local item = part(markers, m.name, 'Block', Vector3.new(1, 1, 1), CFrame.new(m.x, FLOOR_TOP + 1, m.z), hex('66D2CA'),
            'SmoothPlastic', false, false, 1)
        item:SetAttribute('Biome', Builder.KEY)
        if m.name == 'GateMarker' then CollectionService:AddTag(item, 'WildboundBiomeGate') end
    end
    sign(folder(root, 'Signs'), SIGN)
end

local function buildProps(root)
    local kit = templates()
    local props = folder(root, 'Props')
    local counts = { template = 0, primitive = 0 }
    for _, inst in ipairs(rows(INSTANCES, { 'id', 'name', 'x', 'y', 'z', 'yaw', 'scale' })) do
        local model = buildProp(folder(props, inst.name), inst, kit)
        counts[model:GetAttribute('AssetRoute')] += 1
    end
    return counts
end

-- Builds the biome detached, in its layout frame, then pivots it to `origin` (default: the placement).
function Builder.build(parent, origin)
    assert(typeof(parent) == 'Instance', 'parent must be an Instance')
    assert(origin == nil or typeof(origin) == 'CFrame', 'origin must be a CFrame')
    local p = Builder.PLACEMENT
    origin = origin or CFrame.new(p.worldX, FLOOR_TOP, p.worldZ) * CFrame.Angles(0, math.rad(p.yawDeg), 0)
    created = 0
    local root = Instance.new('Model')
    root.Name = Builder.ROOT_NAME
    local ok, failure = pcall(function()
        local anchor = part(root, 'Anchor', 'Block', Vector3.new(1, 1, 1), CFrame.new(0, FLOOR_TOP, 0), hex('FFFFFF'),
            'SmoothPlastic', false, false, 1)
        root.PrimaryPart = anchor
        buildGround(root)
        local counts = buildProps(root)
        buildZones(root)
        buildMarkers(root)
        root:SetAttribute('TemplateProps', counts.template)
        root:SetAttribute('PrimitiveProps', counts.primitive)
    end)
    if not ok then
        root:Destroy()
        error(failure, 0)
    end
    root:PivotTo(origin)
    root:SetAttribute('Biome', Builder.KEY)
    root:SetAttribute('BuilderKey', Builder.KEY)
    root:SetAttribute('DisplayName', Builder.DISPLAY_NAME)
    root:SetAttribute('GeneratedBy', Builder.GENERATED_BY)
    root:SetAttribute('Placement', Builder.PLACEMENT_NAME)
    root:SetAttribute('Seed', Builder.SEED)
    root:SetAttribute('PartCount', created)
    CollectionService:AddTag(root, 'WildboundBiome')
    root.Parent = parent
    return root
end

-- Edit mode only: checks the hub, builds the new root detached, then replaces this builder's old root.
function Builder.run(parent)
    parent = parent or workspace
    assert(RunService:IsEdit(), Builder.ROOT_NAME .. ': run in Studio Edit mode')
    checkHub(Builder.PLACEMENT)
    local old = ownRoot(parent)
    return withHistory('Build ' .. Builder.ROOT_NAME, function()
        local holder = Instance.new('Folder')
        local root = Builder.build(holder)
        if old then old:Destroy() end
        root.Parent = parent
        holder:Destroy()
        print(string.format('[%s] built at (%s, %s) yaw %s: %d parts, %d primitive props, %d template props',
            Builder.ROOT_NAME, Builder.PLACEMENT.worldX, Builder.PLACEMENT.worldZ, Builder.PLACEMENT.yawDeg,
            root:GetAttribute('PartCount'), root:GetAttribute('PrimitiveProps'), root:GetAttribute('TemplateProps')))
        return root
    end)
end

return Builder
"""

ROADS_TEMPLATE = r"""Builder.KEY = 'open-world-roads'
Builder.ROOT_NAME = @@ROOT@@
Builder.GENERATED_BY = @@GENERATOR@@
Builder.PLACEMENT_NAME = @@PLACEMENT_NAME@@
@@HUB@@

local BOXES = [==[
@@BOXES@@
]==]

local MARKERS = [==[
@@MARKERS@@
]==]

-- Roads are already in world coordinates; the root is never moved.
function Builder.build(parent)
    assert(typeof(parent) == 'Instance', 'parent must be an Instance')
    created = 0
    local root = Instance.new('Model')
    root.Name = Builder.ROOT_NAME
    local ok, failure = pcall(function()
        for _, row in ipairs(rows(BOXES, { 'folder', 'name', 'x', 'y', 'z', 'sx', 'sy', 'sz', 'yaw', 'color', 'material',
            'collide', 'transparency' })) do
            local item = boxRow(root, row)
            item:SetAttribute('Biome', row.folder)
            CollectionService:AddTag(item, 'WildboundOpenWorldRoad')
        end
        local gates = folder(root, 'Gates')
        for _, m in ipairs(rows(MARKERS, { 'name', 'x', 'z' })) do
            local item = part(gates, m.name, 'Block', Vector3.new(1, 1, 1), CFrame.new(m.x, FLOOR_TOP + 1, m.z), hex('66D2CA'),
                'SmoothPlastic', false, false, 1)
            item:SetAttribute('Biome', string.sub(m.name, 6))
        end
    end)
    if not ok then
        root:Destroy()
        error(failure, 0)
    end
    root:SetAttribute('BuilderKey', Builder.KEY)
    root:SetAttribute('GeneratedBy', Builder.GENERATED_BY)
    root:SetAttribute('Placement', Builder.PLACEMENT_NAME)
    root:SetAttribute('PartCount', created)
    root.Parent = parent
    return root
end

function Builder.run(parent)
    parent = parent or workspace
    assert(RunService:IsEdit(), Builder.ROOT_NAME .. ': run in Studio Edit mode')
    checkHub(Builder.HUB)
    local old = ownRoot(parent)
    return withHistory('Build ' .. Builder.ROOT_NAME, function()
        local holder = Instance.new('Folder')
        local root = Builder.build(holder)
        if old then old:Destroy() end
        root.Parent = parent
        holder:Destroy()
        print(string.format('[%s] built: %d parts', Builder.ROOT_NAME, root:GetAttribute('PartCount')))
        return root
    end)
end

return Builder
"""


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--check", action="store_true", help="exit 1 if a written module is not fresh")
    args = parser.parse_args(argv)
    stale = []
    for path, text in outputs().items():
        if args.check:
            if not path.exists() or path.read_bytes().decode("utf-8") != text:
                stale.append(path)
        else:
            path.write_bytes(text.encode("utf-8"))
            print("wrote", path.relative_to(REPO), "adler32", adler32(text))
    if stale:
        print("stale:", *[str(p.relative_to(REPO)) for p in stale])
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

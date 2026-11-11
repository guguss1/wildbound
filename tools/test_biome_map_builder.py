"""Contracts for the open-world biome builders (tools/biome_map_builder.py and its generated Luau modules).

Run from the project root (isolated mode, no bytecode written):

    python -I -B -m unittest discover -s tools -p test_biome_map_builder.py

The generator writes one Studio Edit-mode builder per offline biome layout and one for the open-world roads.
These tests restate the asset route (forest kit: uploaded packages cloned from ServerStorage templates; every
other kit: never uploaded, so primitive parts) and re-derive the facts from the layouts, the kit reports, the
placement JSON and the written Luau: every planned prop appears once, each builder's placement constants equal
the placement JSON, no asset id or MeshPart is ever written, neon never collides, chasms are holes, the written
modules are fresh. Nothing here runs Luau or touches Studio.
"""

import json
import math
import re
import unittest
from pathlib import Path

import biome_map_builder as bmb
import layout_geometry as g

TOOLS = Path(__file__).resolve().parent
REPO = TOOLS.parent
PLACEMENT = REPO / "assets/maps/open-world/biome-placement-v1.json"
BIOMES = ("cryptic-ruins", "demon-abyss", "frozen-mountains", "living-forest", "rock-caves", "volcanic-lands")
ROOTS = {"cryptic-ruins": "WildboundCrypticRuins", "demon-abyss": "WildboundDemonAbyss",
         "frozen-mountains": "WildboundFrozenMountains", "living-forest": "WildboundLivingForest",
         "rock-caves": "WildboundRockCaves", "volcanic-lands": "WildboundVolcanicLands"}
FORBIDDEN = ("rbxassetid", "MeshPart", "InsertService", "HttpService", "LoadAsset", "Instance.new('Script')",
             "Instance.new('LocalScript')", "Instance.new(\"Script\")", "MarketplaceService", "DataStore")
PLACEMENT_RE = re.compile(r"Builder\.PLACEMENT = table\.freeze\(\{ worldX = ([-\d.]+), worldZ = ([-\d.]+), yawDeg = ([-\d.]+), "
                          r"mapSize = ([-\d.]+), hubX = ([-\d.]+), hubZ = ([-\d.]+), hubRadius = ([-\d.]+) \}\)")
HUB_RE = re.compile(r"Builder\.HUB = table\.freeze\(\{ hubX = ([-\d.]+), hubZ = ([-\d.]+), hubRadius = ([-\d.]+) \}\)")


def placement():
    return json.loads(PLACEMENT.read_text(encoding="utf-8"))


def written(key):
    return (TOOLS / ("build-wildbound-%s-map.luau" % key)).read_bytes().decode("utf-8")


def block(text, name):
    return text.split("local %s = [==[\n" % name, 1)[1].split("\n]==]", 1)[0].split("\n")


def luau_block_balance(text):
    text = re.sub(r"\[==\[.*?\]==\]", "", text, flags=re.S)
    text = re.sub(r"--.*", "", text)
    text = re.sub(r"'(?:\\.|[^'\\])*'", "''", text)
    opens = len(re.findall(r"\bfunction\b|\bdo\b|\bif\b|\brepeat\b", text))
    closes = len(re.findall(r"\bend\b|\buntil\b", text))
    return opens, closes


def slab_poly(x, z, sx, sz, yaw):
    r = math.radians(yaw)
    ux, uz = math.cos(r), -math.sin(r)          # local +X
    vx, vz = math.sin(r), math.cos(r)           # local +Z
    return [(x + ux * sx / 2 * i + vx * sz / 2 * j, z + uz * sx / 2 * i + vz * sz / 2 * j)
            for i, j in ((-1, -1), (1, -1), (1, 1), (-1, 1))]


def strip(a, b, width, cap):
    L = math.dist(a, b)
    dx, dz = (b[0] - a[0]) / L, (b[1] - a[1]) / L
    nx, nz = -dz * width / 2, dx * width / 2
    a2, b2 = (a[0] - dx * cap, a[1] - dz * cap), (b[0] + dx * cap, b[1] + dz * cap)
    return [(a2[0] + nx, a2[1] + nz), (b2[0] + nx, b2[1] + nz), (b2[0] - nx, b2[1] - nz), (a2[0] - nx, a2[1] - nz)]


def road_slabs(text):
    out = []
    for row in block(text, "BOXES"):
        f = row.split("|")
        out.append((f[0], slab_poly(float(f[2]), float(f[4]), float(f[5]), float(f[7]), float(f[8]))))
    return out


def _area(poly):
    return sum(p[0] * q[1] - q[0] * p[1] for p, q in zip(poly, poly[1:] + poly[:1])) / 2


def overlap_area(p, q):
    """Area of the intersection of two convex polygons (Sutherland-Hodgman)."""
    out = p if _area(p) > 0 else p[::-1]
    clip = q if _area(q) > 0 else q[::-1]
    for c, d in zip(clip, clip[1:] + clip[:1]):
        def keep(v):
            return (d[0] - c[0]) * (v[1] - c[1]) - (d[1] - c[1]) * (v[0] - c[0]) >= 0
        src, out = out, []
        for v, w in zip(src, src[1:] + src[:1]):
            if keep(w):
                if not keep(v):
                    out.append(_cut(v, w, c, d))
                out.append(w)
            elif keep(v):
                out.append(_cut(v, w, c, d))
        if not out:
            return 0.0
    return abs(_area(out))


def _cut(v, w, c, d):
    ex, ez = d[0] - c[0], d[1] - c[1]
    fv = ex * (v[1] - c[1]) - ez * (v[0] - c[0])
    fw = ex * (w[1] - c[1]) - ez * (w[0] - c[0])
    t = fv / (fv - fw)
    return (v[0] + (w[0] - v[0]) * t, v[1] + (w[1] - v[1]) * t)


def inside(p, poly):
    return overlap_area(poly, [(p[0] - 0.01, p[1] - 0.01), (p[0] + 0.01, p[1] - 0.01), (p[0] + 0.01, p[1] + 0.01),
                               (p[0] - 0.01, p[1] + 0.01)]) > 3.9e-4 - 1e-9


def on_segment(p, a, b):
    L = math.dist(a, b)
    cross = (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])
    t = ((p[0] - a[0]) * (b[0] - a[0]) + (p[1] - a[1]) * (b[1] - a[1])) / (L * L)
    return abs(cross) / L < 0.01 and -1e-6 <= t <= 1 + 1e-6


class AssetRoute(unittest.TestCase):
    def test_only_the_forest_kit_was_uploaded(self):
        manifest = json.loads((REPO / "assets/exports/forest-kit/forest-kit-upload-manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(set(manifest["uploads"]), {"FK_Evergreen", "FK_DeadTree", "FK_FallenLog", "FK_RootArch",
                                                    "FK_RuinDoorway", "FK_LanternMarker"})
        for key in BIOMES:
            kit = key + "-kit"
            self.assertEqual(list((REPO / "assets/exports" / kit).glob("*manifest*.json")), [], kit)
            report = json.loads((REPO / bmb.KITS[key][2]).read_text(encoding="utf-8"))
            self.assertIs(report["roblox_scale_verified"], False, key)

    def test_builders_clone_templates_or_fall_back_to_primitives(self):
        for key in BIOMES:
            text = written(key)
            self.assertIn("ServerStorage:FindFirstChild('WildboundAssets')", text, key)
            self.assertIn("Builder.TEMPLATE_FOLDER = '%s'" % bmb.KITS[key][1], text, key)
            self.assertIn("'PackageLink'", text, key)
            self.assertIn("SetAttribute('AssetRoute', 'primitive')", text, key)

    def test_no_asset_id_mesh_or_script_is_ever_written(self):
        texts = {key: written(key) for key in BIOMES}
        texts["roads"] = (TOOLS / "build-wildbound-open-world-roads.luau").read_bytes().decode("utf-8")
        for key, text in texts.items():
            text = re.sub(r"--.*", "", text)          # code only: the header may say what is not done
            for word in FORBIDDEN:
                self.assertNotIn(word, text, (key, word))
            self.assertIsNone(re.search(r"\b\d{9,}\b", text), key)   # nothing that looks like an asset id


class KitFrame(unittest.TestCase):
    def test_blender_point_and_size_to_the_plan_frame(self):
        self.assertEqual(bmb.kit_point((1.0, 2.0, 3.0)), (-1.0, 3.0, 2.0))
        self.assertEqual(bmb.kit_size((4.0, 5.0, 6.0)), (4.0, 6.0, 5.0))

    def test_every_kit_occluder_and_collision_box_becomes_a_solid_piece(self):
        for key in BIOMES:
            report = json.loads((REPO / bmb.KITS[key][2]).read_text(encoding="utf-8"))["props"]
            recipes = bmb.kit_recipes(key)
            for name, entry in report.items():
                pieces = recipes[name]
                occluders = [p for p in pieces if p["role"] == "occluder"]
                walks = [p for p in pieces if p["role"] == "walk"]
                self.assertEqual(len(occluders), len(entry.get("occluders") or []), name)
                self.assertEqual(len(walks), len(entry.get("collision_boxes") or []), name)
                for p, box in zip(occluders, entry.get("occluders") or []):
                    self.assertTrue(p["collide"] and p["query"], name)
                    self.assertEqual(p["pos"], [bmb.r3(v) for v in bmb.kit_point(box["center"])], name)
                for p, box in zip(walks, entry.get("collision_boxes") or []):
                    self.assertTrue(p["collide"], name)
                    self.assertAlmostEqual(p["pitch"], -box.get("pitch_deg", 0.0), places=3)

    def test_pieces_are_sane_and_neon_never_collides_or_blocks_sight(self):
        for key in BIOMES:
            for name, pieces in bmb.kit_recipes(key).items():
                self.assertTrue(pieces, name)
                for p in pieces:
                    self.assertIn(p["shape"], ("Block", "Ball", "Cylinder", "Wedge"), name)
                    self.assertTrue(all(s > 0 for s in p["size"]), name)
                    self.assertRegex(p["color"], r"^[0-9A-F]{6}$")
                    if p["material"] == "Neon":
                        self.assertFalse(p["collide"] or p["query"], name)

    def test_tunnels_get_a_roof_above_the_walk_clearance(self):
        recipes = bmb.kit_recipes("rock-caves")
        for name in ("RC_TunnelStraight", "RC_TunnelBend"):
            walks = [p for p in recipes[name] if p["role"] == "walk"]
            roofs = [p for p in recipes[name] if p["role"] == "roof"]
            self.assertEqual(len(roofs), len(walks), name)
            for p in recipes[name]:
                if p["role"] in ("roof", "shell"):
                    self.assertGreaterEqual(p["pos"][1] - p["size"][1] / 2, 10.5, name)   # clearance height is 10


class Ground(unittest.TestCase):
    def test_demon_abyss_chasms_are_holes_and_route_rocks_are_flush(self):
        layout = json.loads((REPO / "assets/maps/demon-abyss-layout/demon-abyss-layout-v1.json").read_text(encoding="utf-8"))
        polys = [[tuple(p) for p in c["polygon"]] for c in layout["hazards"]["chasms"]]
        floors = bmb.floor_rows("demon-abyss", layout)
        banks = [f for f in floors if "y_top" not in f]
        area = sum(f["sx"] * f["sz"] for f in banks)
        self.assertLess(area, 300.0 * 300.0)
        for f in banks:
            for k in range(int(round(f["sx"] / bmb.DEMON_TILE))):
                x = f["x"] - f["sx"] / 2 + (k + 0.5) * bmb.DEMON_TILE
                self.assertFalse(any(g.point_in_polygon(poly, (x, f["z"])) for poly in polys), (x, f["z"]))
        route_rocks = {i for c in layout["hazards"]["chasms"] for i in c["route_rock_ids"]}
        rows = {r["id"]: r for r in bmb.instance_rows("demon-abyss", layout)}
        for rid in route_rocks:
            self.assertAlmostEqual(rows[rid]["y"] + 6.0 * rows[rid]["scale"], 0.0, places=3, msg=rid)

    def test_demon_abyss_paths_never_bridge_a_chasm(self):
        layout = json.loads((REPO / "assets/maps/demon-abyss-layout/demon-abyss-layout-v1.json").read_text(encoding="utf-8"))
        polys = [[tuple(p) for p in c["polygon"]] for c in layout["hazards"]["chasms"]]
        paths = [b for b in bmb.feature_boxes("demon-abyss", layout) if b["folder"] == "Paths"]
        self.assertGreater(len(paths), len(layout["route"]["nodes"]) - 1)    # legs crossing a chasm are split
        for b in paths:
            r = math.radians(b["yaw"])
            ux, uz = math.sin(r), math.cos(r)
            for k in range(21):
                t = (k / 20 - 0.5) * b["sz"]
                q = (b["x"] + ux * t, b["z"] + uz * t)
                self.assertFalse(any(g.point_in_polygon(poly, q) for poly in polys), (b["name"], q))
        rows = bmb.instance_rows("demon-abyss", layout)
        for r in rows:
            if any(g.point_in_polygon(poly, (r["x"], r["z"])) for poly in polys):
                self.assertLess(r["y"], 0.0, r["id"])       # nothing floats over a drop at bank height

    def test_every_route_leg_has_a_path_slab(self):
        for key in BIOMES:
            if key == "demon-abyss":
                continue
            layout = json.loads((REPO / placement()["biomes"][key]["layout"]).read_text(encoding="utf-8"))
            lines = [r["nodes"] for r in layout["surface_routes"]] if key == "rock-caves" else [layout["route"]["nodes"]]
            paths = [b for b in bmb.feature_boxes(key, layout) if b["folder"] == "Paths"]
            self.assertEqual(len(paths), sum(len(n) - 1 for n in lines), key)

    def test_the_route_is_never_blocked_by_a_solid_piece_below_head_height(self):
        # Walk on every trail centreline at 2-stud steps: no colliding piece whose bottom is under 5 studs (walk
        # boxes such as stairs, stepping stones and floating rocks excepted) may stand on it.
        for key in BIOMES:
            d = bmb.biome_data(key, placement())
            blockers = []
            for inst in d["instances"]:
                s, r = inst["scale"], math.radians(inst["yaw"])
                for p in d["recipes"][inst["name"]]:
                    bottom = inst["y"] + (p["pos"][1] - p["size"][1] / 2) * s
                    if not p["collide"] or p["role"] == "walk" or bottom >= 5.0:
                        continue
                    px, pz = p["pos"][0] * s, p["pos"][2] * s
                    cx = inst["x"] + px * math.cos(r) + pz * math.sin(r)
                    cz = inst["z"] - px * math.sin(r) + pz * math.cos(r)
                    sx, sz = (p["size"][1], p["size"][2]) if p["upright"] else (p["size"][0], p["size"][2])
                    blockers.append((inst["id"], g.rect_poly(cx, cz, sx * s / 2, sz * s / 2, inst["yaw"] + p["yaw"]).pts))
            nodes = d["layout"]["route"]["nodes"]
            for a, b in zip(nodes, nodes[1:]):
                n = int(math.dist(a, b) / 2) + 1
                for k in range(n + 1):
                    q = (a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n)
                    for iid, pts in blockers:
                        self.assertFalse(g.point_in_polygon(pts, q), (key, iid, q))

    def test_zones_cover_the_square_and_every_hazard(self):
        for key in BIOMES:
            layout = json.loads((REPO / placement()["biomes"][key]["layout"]).read_text(encoding="utf-8"))
            zones = bmb.zone_rows(key, layout)
            region = [z for z in zones if z["kind"] == "Region"]
            self.assertEqual(len(region), 1)
            self.assertEqual((region[0]["sx"], region[0]["sz"]), (layout["map_size"], layout["map_size"]))
            kinds = {z["kind"] for z in zones}
            expected = {"demon-abyss": "Chasm", "volcanic-lands": "Vent", "rock-caves": "Rockfall",
                        "frozen-mountains": "NoTrack", "living-forest": "Stream"}.get(key)
            if expected:
                self.assertIn(expected, kinds, key)

    def test_chasm_zone_matches_its_polygon(self):
        layout = json.loads((REPO / "assets/maps/demon-abyss-layout/demon-abyss-layout-v1.json").read_text(encoding="utf-8"))
        for chasm in layout["hazards"]["chasms"]:
            cx, cz, a, b, yaw = bmb.oriented_rect(chasm["polygon"])
            r = math.radians(yaw)
            ex, ez = (math.cos(r), -math.sin(r)), (math.sin(r), math.cos(r))
            corners = [(cx + sx * a / 2 * ex[0] + sz * b / 2 * ez[0], cz + sx * a / 2 * ex[1] + sz * b / 2 * ez[1])
                       for sx in (-1, 1) for sz in (-1, 1)]
            for p in chasm["polygon"]:      # the planner's polygons are rectangles to about 0.01 stud
                self.assertLess(min(math.dist(p, c) for c in corners), 0.05, chasm["id"])


class Written(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.placement = placement()
        cls.fresh = bmb.outputs(cls.placement)

    def test_modules_are_fresh(self):
        for path, text in self.fresh.items():
            self.assertTrue(path.exists(), path.name)
            self.assertEqual(path.read_bytes().decode("utf-8"), text, path.name + " is stale: run python tools/biome_map_builder.py")

    def test_placement_constants_match_the_placement_json(self):
        hub = self.placement["hub"]
        for key in BIOMES:
            biome = self.placement["biomes"][key]
            m = PLACEMENT_RE.search(written(key))
            self.assertIsNotNone(m, key)
            got = tuple(float(v) for v in m.groups())
            want = (biome["world_centre"][0], biome["world_centre"][1], biome["yaw_deg"], biome["map_size"],
                    hub["centre"][0], hub["centre"][1], hub["radius"])
            self.assertEqual(got, tuple(float(v) for v in want), key)
            self.assertIn("Builder.ROOT_NAME = '%s'" % ROOTS[key], written(key))
            self.assertEqual(biome["root_name"], ROOTS[key])
            self.assertEqual(biome["builder"], "tools/build-wildbound-%s-map.luau" % key)

    def test_roads_match_the_placement_json(self):
        text = (TOOLS / "build-wildbound-open-world-roads.luau").read_bytes().decode("utf-8")
        hub = self.placement["hub"]
        self.assertEqual(tuple(float(v) for v in HUB_RE.search(text).groups()),
                         (float(hub["centre"][0]), float(hub["centre"][1]), float(hub["radius"])))
        slabs = road_slabs(text)
        width = {road["width"] for road in self.placement["roads"].values()}
        self.assertEqual(width, {14.0})
        # Every stretch of every road's centreline is paved by some slab ...
        for key, road in self.placement["roads"].items():
            nodes = road["nodes_world"]
            for a, b in zip(nodes, nodes[1:]):
                n = max(2, int(math.dist(a, b)))
                for k in range(n):         # leg interiors: a road's first slab starts flush with its trail end
                    t = (k + 0.5) / n
                    p = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
                    self.assertTrue(any(inside(p, poly) for _, poly in slabs), (key, p))
        # ... every slab runs along a leg of the road it is filed under, and no leg is paved twice.
        legs = {key: list(zip(road["nodes_world"], road["nodes_world"][1:])) for key, road in self.placement["roads"].items()}
        for (folder, poly), row in zip(slabs, block(text, "BOXES")):
            f = row.split("|")
            centre = (float(f[2]), float(f[4]))
            self.assertTrue(any(on_segment(centre, a, b) for a, b in legs[folder]), row)
        rows = [tuple(r.split("|")[2:9]) for r in block(text, "BOXES")]
        self.assertEqual(len(rows), len(set(rows)))
        self.assertLess(len(rows), sum(len(v) for v in legs.values()), "shared stretches are emitted once")
        gates = block(text, "MARKERS")
        self.assertEqual(len(gates), len(self.placement["biomes"]))

    def test_no_two_road_slabs_overlap_by_more_than_a_junction_square(self):
        text = (TOOLS / "build-wildbound-open-world-roads.luau").read_bytes().decode("utf-8")
        slabs = road_slabs(text)
        junction = 14.0 * 14.0
        for i, (fa, pa) in enumerate(slabs):
            for fb, pb in slabs[i + 1:]:
                self.assertLessEqual(overlap_area(pa, pb), junction + 1e-3, (fa, fb, pa, pb))

    def test_no_road_slab_overlaps_a_hub_trail(self):
        text = (TOOLS / "build-wildbound-open-world-roads.luau").read_bytes().decode("utf-8")
        hub = json.loads((REPO / "assets/maps/hub-layout/hub-bases-v2-r90.json").read_text(encoding="utf-8"))
        hx, hz = self.placement["hub"]["centre"]
        for e in hub["entrances"]:
            t = e["trail"]
            a = (hx + t["from"][0], hz + t["from"][1])
            b = (hx + t["to"][0], hz + t["to"][1])
            trail = strip(a, b, t["width"], 0.0)
            for folder, poly in road_slabs(text):
                self.assertLess(overlap_area(trail, poly), 1e-3, (e["id"], folder))

    def test_every_planned_prop_is_a_row_once_with_a_recipe(self):
        for key in BIOMES:
            layout = json.loads((REPO / self.placement["biomes"][key]["layout"]).read_text(encoding="utf-8"))
            text = written(key)
            rows = [r.split("|") for r in block(text, "INSTANCES")]
            self.assertEqual(sorted(r[0] for r in rows), sorted(i["id"] for i in layout["instances"]), key)
            self.assertEqual(len({r[0] for r in rows}), len(rows), key)
            recipe_names = {r.split("|")[0] for r in block(text, "PIECES")}
            self.assertEqual(recipe_names, {r[1] for r in rows}, key)
            for r in rows:
                self.assertEqual(len(r), len(bmb.INSTANCE_FIELDS), r)

    def test_rows_have_the_field_count_the_reader_expects(self):
        counts = {"PIECES": len(bmb.PIECE_FIELDS), "FLOORS": len(bmb.FLOOR_FIELDS), "BOXES": len(bmb.BOX_FIELDS),
                  "ZONES": len(bmb.ZONE_FIELDS), "MARKERS": len(bmb.MARKER_FIELDS)}
        for key in BIOMES:
            text = written(key)
            for name, n in counts.items():
                for row in block(text, name):
                    self.assertEqual(len(row.split("|")), n, (key, name, row))

    def test_player_text_is_the_spanish_display_name(self):
        for key in BIOMES:
            name = self.placement["biomes"][key]["display_name"]
            self.assertIn("Builder.DISPLAY_NAME = '%s'" % name, written(key))
            self.assertIn("text = '%s'" % name, written(key))

    def test_idempotent_edit_mode_builder_shape(self):
        texts = [written(key) for key in BIOMES] + [(TOOLS / "build-wildbound-open-world-roads.luau").read_bytes().decode("utf-8")]
        for text in texts:
            self.assertIn("RunService:IsEdit()", text)
            self.assertIn("GetAttribute('GeneratedBy') ~= Builder.GENERATED_BY", text)
            self.assertIn("if old then old:Destroy() end", text)
            self.assertIn("checkHub(", text)
            self.assertIn("return Builder", text)
            opens, closes = luau_block_balance(text)
            self.assertEqual(opens, closes)

    def test_zone_and_gate_tags(self):
        for key in BIOMES:
            text = written(key)
            for tag in ("'WildboundBiome'", "'WildboundBiomeZone'", "'WildboundBiomeHazard'", "'WildboundBiomeGate'"):
                self.assertIn(tag, text, (key, tag))


class Doc(unittest.TestCase):
    """docs/maps/wildbound-open-world-biomes.md must state what the placement JSON says."""

    @classmethod
    def setUpClass(cls):
        cls.text = (REPO / "docs/maps/wildbound-open-world-biomes.md").read_text(encoding="utf-8")
        cls.placement = placement()

    def test_placement_table_matches_the_json(self):
        for key, biome in self.placement["biomes"].items():
            row = next((line for line in self.text.splitlines() if line.startswith("| `%s` |" % key)), None)
            self.assertIsNotNone(row, key)
            cx, cz = biome["world_centre"]
            self.assertIn("(%g, %g)" % (cx, cz), row, key)
            self.assertIn("%g" % biome["yaw_deg"], row, key)
            self.assertIn("`%s`" % biome["root_name"], row, key)

    def test_run_lines_name_every_builder(self):
        for key in BIOMES:
            self.assertIn("tools/build-wildbound-%s-map.luau" % key, self.text)
        self.assertIn("tools/build-wildbound-open-world-roads.luau", self.text)
        cx, cz = self.placement["biomes"]["pradera"]["world_centre"]
        self.assertIn("CFrame.new(%g, 0, %g)" % (cx, cz), self.text)

    def test_states_the_hub_it_was_made_for(self):
        hub = self.placement["hub"]
        self.assertIn("(%g, %g), radius %g" % (hub["centre"][0], hub["centre"][1], hub["radius"]), self.text)


if __name__ == "__main__":
    unittest.main()

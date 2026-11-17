"""Spec tests for the Caramelo v3 decor kit (CV3_), built by tools/build-caramelo-v3-decor-kit.py.

Run from the project root with Blender's bundled Python (isolated mode, no bytecode written):
  "C:/Program Files/Blender Foundation/Blender 5.0/5.0/python/bin/python.exe" -I -B -m unittest discover -s tools -p "test_caramelo_v3_decor_kit.py"
Artifacts come from a headless build (it also re-imports every FBX for the round trip):
  "C:/Program Files/Blender Foundation/Blender 5.0/blender.exe" -b --factory-startup -P tools/build-caramelo-v3-decor-kit.py

Standard library only. The generic biome kit rules (names, sizes, triangle budgets, pivots at the base,
closed outward meshes, one matte material per part, renders, FBX round trip, walk and ramp boxes, the
arch clearance) come from BiomeKitMixin; the contract table is tools/caramelo_v3_decor_spec.py. The rules
below add what this kit promises: trunk colliders 2 to 3 studs wide, crowns that sway as separate meshes,
the mountain's chocolate waterfall pouring off a ledge into a pool through a notch kept clear of rock,
Collision_ parts that never block the water, and cake modules that snap. Everything stays unvalidated:
nothing was imported into Roblox.
"""

import math
import unittest

import caramelo_v3_decor_spec as cs
from biome_kit_spec import BiomeKitMixin, box_extent, inside_bbox, triangle_overlaps_box
from kit_spec_common import ROOT, asset_triangles, bounds, load_json, part_triangles

KIT_DIR = ROOT / "assets/blender/caramelo-v3-decor"
EXPORT_DIR = ROOT / "assets/exports/caramelo-v3/decor"


class CarameloV3DecorKit(BiomeKitMixin, unittest.TestCase):
    SPECS = cs.SPECS
    REPORT = KIT_DIR / "caramelo-v3-decor-report.json"
    GEOMETRY = KIT_DIR / "caramelo-v3-decor-geometry.json"
    ROUNDTRIP = KIT_DIR / "fbx-roundtrip.json"
    BLEND = KIT_DIR / "caramelo-v3-decor-v1.blend"
    RENDER_DIR = KIT_DIR
    EXPORT_DIR = EXPORT_DIR


def collider_extent(c):
    """Axis-aligned half extents of a Collision_ part (yaw about Z or pitch about X, never both)."""
    sx, sy, sz = (s / 2 for s in c["size"])
    if c.get("pitch_deg"):
        return box_extent(c)
    yaw = math.radians(c.get("yaw_deg", 0.0))
    return (abs(math.cos(yaw)) * sx + abs(math.sin(yaw)) * sy, abs(math.sin(yaw)) * sx + abs(math.cos(yaw)) * sy, sz)


def collider_contains(c, point):
    """Is the point inside this block or upright cylinder?"""
    rel = [point[i] - c["center"][i] for i in range(3)]
    if abs(rel[2]) > c["size"][2] / 2:
        return False
    if c["shape"] == "cylinder":
        return math.hypot(rel[0], rel[1]) <= c["size"][0] / 2
    yaw = math.radians(c.get("yaw_deg", 0.0))
    local_x = rel[0] * math.cos(yaw) + rel[1] * math.sin(yaw)
    local_y = -rel[0] * math.sin(yaw) + rel[1] * math.cos(yaw)
    return abs(local_x) <= c["size"][0] / 2 and abs(local_y) <= c["size"][1] / 2


class CarameloV3Rules(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = load_json(CarameloV3DecorKit.REPORT)["props"]
        cls.geometry = load_json(CarameloV3DecorKit.GEOMETRY)
        cls.import_spec = load_json(EXPORT_DIR / "caramelo-v3-decor-spec.json")

    def points(self, asset, label):
        return self.geometry[asset]["parts"][f"{asset}_{label}"]["vertices"]

    def tris(self, asset, label):
        return part_triangles(self.geometry[asset]["parts"][f"{asset}_{label}"])

    # -- budgets and files --------------------------------------------------
    def test_triangle_caps_from_the_brief(self):
        for name, entry in self.report.items():
            cap = cs.TREE_TRI_CAP if name in cs.TREES else cs.ASSET_TRI_CAP
            self.assertLessEqual(entry["triangles"], cap, name)
            self.assertLessEqual(cs.SPECS[name]["tris"], cap, name)

    def test_one_fbx_per_asset_and_the_readme_names_them(self):
        readme = (EXPORT_DIR / "README.md").read_text(encoding="utf-8")
        for name in cs.SPECS:
            path = EXPORT_DIR / f"{name}.fbx"
            self.assertTrue(path.read_bytes().startswith(b"Kaydara FBX Binary"), name)
            self.assertIn(f"{name}.fbx", readme)
        for name in cs.MOUNTAINS:
            for label in cs.MOUNTAIN_WATER.values():
                self.assertIn(f"{name}_{label}", readme)

    def test_import_spec_lists_every_asset_piece_and_collider(self):
        assets = self.import_spec["assets"]
        self.assertEqual(sorted(assets), sorted(cs.SPECS))
        for name, entry in assets.items():
            self.assertEqual(sorted(entry["pieces"]), sorted(cs.SPECS[name]["parts"]))
            self.assertEqual(entry["collision"], self.report[name]["collision"])
            for piece in entry["pieces"].values():
                self.assertFalse(piece["collide"], "meshes never collide; Collision_ parts do")

    # -- collision parts ----------------------------------------------------
    def test_every_asset_has_simple_collision_parts_inside_its_bounds(self):
        for name, entry in self.report.items():
            with self.subTest(asset=name):
                low, high = bounds(asset_triangles(self.geometry[name]))
                self.assertTrue(entry["collision"])
                names = [c["name"] for c in entry["collision"]]
                self.assertEqual(len(names), len(set(names)))
                for c in entry["collision"]:
                    self.assertTrue(c["name"].startswith(cs.COLLISION_PREFIX), c["name"])
                    self.assertIn(c["shape"], ("block", "cylinder"))
                    if c["shape"] == "cylinder":
                        self.assertAlmostEqual(c["size"][0], c["size"][1], delta=1e-3)
                    self.assertTrue(inside_bbox(low, high, c["center"], collider_extent(c), 0.6), c["name"])

    # -- trees ----------------------------------------------------------------
    def test_trees_are_tall_with_a_two_to_three_stud_trunk_collider(self):
        for name in cs.TREES:
            with self.subTest(tree=name):
                entry = self.report[name]
                self.assertGreaterEqual(entry["size"][2], 22.0)
                self.assertLessEqual(entry["size"][2], 30.0)
                trunk = [c for c in entry["collision"] if c["name"] == "Collision_Trunk"]
                self.assertEqual(len(trunk), 1)
                low_d, high_d = cs.TRUNK_DIAMETER
                self.assertGreaterEqual(trunk[0]["size"][0], low_d)
                self.assertLessEqual(trunk[0]["size"][0], high_d)
                self.assertAlmostEqual(trunk[0]["center"][2] - trunk[0]["size"][2] / 2, 0.0, delta=0.01)
                base = [v for v in self.points(name, "Trunk") if v[2] <= 0.5]
                self.assertLessEqual(max(math.hypot(v[0], v[1]) for v in base), high_d / 2 + 0.05)

    def test_tree_crowns_are_separate_sway_meshes_above_the_trunk(self):
        for name in cs.TREES:
            with self.subTest(tree=name):
                sway = self.report[name]["sway"]
                labels = cs.SPECS[name]["sway"]
                self.assertEqual(sway["objects"], [f"{name}_{label}" for label in labels])
                self.assertNotIn("Trunk", labels)
                crown_low = min(v[2] for label in labels for v in self.points(name, label))
                self.assertLessEqual(sway["pivot"][2], crown_low + 0.01, "pivot sits at the crown base")
                self.assertGreaterEqual(crown_low, 8.0, "an avatar walks under the crown")
                self.assertLessEqual(math.hypot(*sway["pivot"][:2]), 0.5)

    # -- ice-cream mountains and the chocolate waterfall ---------------------
    def test_mountain_heights_big_and_medium(self):
        self.assertAlmostEqual(self.report["CV3_IceCreamMountain_L"]["size"][2], 90.0, delta=3.0)
        self.assertAlmostEqual(self.report["CV3_IceCreamMountain_M"]["size"][2], 60.0, delta=3.0)

    def test_water_pieces_are_their_own_meshes_named_in_the_report(self):
        for name in cs.MOUNTAINS:
            with self.subTest(mountain=name):
                water = self.report[name]["water"]
                for role, label in cs.MOUNTAIN_WATER.items():
                    self.assertEqual(water[role], f"{name}_{label}")
                    self.assertIn(water[role], self.geometry[name]["parts"])

    def test_waterfall_pours_off_the_ledge_into_the_pool(self):
        for name in cs.MOUNTAINS:
            with self.subTest(mountain=name):
                water, height = self.report[name]["water"], self.report[name]["size"][2]
                fall = self.points(name, "Waterfall")
                top, bottom = max(v[2] for v in fall), min(v[2] for v in fall)
                self.assertGreaterEqual(top - bottom, 0.3 * height, "a tall drop, not a trickle")
                self.assertGreaterEqual(top, water["ledge_z"] - 1.0)
                self.assertLess(bottom, water["pool_surface_z"], "the sheet ends in the pool")
                pool_top = max(v[2] for v in self.points(name, "Pool"))
                self.assertAlmostEqual(pool_top, water["pool_surface_z"], delta=0.01)
                foot = [v for v in fall if v[2] <= bottom + 0.01]
                cx, cy = water["pool_center"][:2]
                for v in foot:
                    self.assertLess(math.hypot(v[0] - cx, v[1] - cy), water["pool_radius"], "lands inside the pool")
                self.assertLess(sum(v[1] for v in fall) / len(fall), -0.2 * height, "falls on the -Y front")
                width = max(v[0] for v in fall) - min(v[0] for v in fall)
                self.assertGreaterEqual(width, 0.1 * height, "a big chocolate river")
                river = self.points(name, "River")
                self.assertGreater(max(v[2] for v in river), water["ledge_z"] + 0.1 * height, "the river runs down to the ledge")

    def test_the_cliff_notch_leaves_open_air_in_front_of_the_falling_water(self):
        for name in cs.MOUNTAINS:
            with self.subTest(mountain=name):
                water = self.report[name]["water"]
                fall = self.points(name, "Waterfall")
                front_y = max(v[1] for v in fall if abs(v[0]) < 2.5)
                low = (-2.0, min(v[1] for v in fall) - 4.0, water["pool_surface_z"] + 0.5)
                high = (2.0, front_y, water["ledge_z"] - 1.0)
                for label in ("Base", "Rocks", "Fudge", "PoolLip"):
                    hits = [t for t in self.tris(name, label) if triangle_overlaps_box(t, low, high)]
                    self.assertEqual(hits, [], f"{label} blocks the waterfall")
                behind = [v for v in self.points(name, "Base") if abs(v[0]) < 2.0 and v[2] < water["ledge_z"] - 1.0]
                self.assertTrue(behind)
                self.assertGreater(min(v[1] for v in behind) - front_y, -0.01, "the sheet hangs in front of the cliff")

    def test_pool_lip_opens_an_outlet_for_the_river_on_the_minus_y_side(self):
        for name in cs.MOUNTAINS:
            with self.subTest(mountain=name):
                water = self.report[name]["water"]
                cx, cy = water["pool_center"][:2]
                lip = self.points(name, "PoolLip")
                gap = [v for v in lip if abs(v[0] - cx) < 0.3 * water["pool_radius"] and v[1] < cy]
                self.assertEqual(gap, [], "the -Y outlet must stay open")
                self.assertLess(water["outlet"][1], cy - water["pool_radius"] + 0.01)
                self.assertLessEqual(max(v[2] for v in lip), 3.0, "a low rim")

    def test_no_collider_blocks_the_pool_or_the_falling_water(self):
        for name in cs.MOUNTAINS:
            with self.subTest(mountain=name):
                water = self.report[name]["water"]
                fall = self.points(name, "Waterfall")
                middle = [sum(v[i] for v in fall) / len(fall) for i in range(3)]
                cx, cy, cz = water["pool_center"]
                probes = [middle, [cx, cy, cz - 0.5], [cx, cy + water["pool_radius"] * 0.5, cz - 0.5], water["outlet"]]
                for c in self.report[name]["collision"]:
                    for probe in probes:
                        self.assertFalse(collider_contains(c, probe), f"{c['name']} covers {probe}")

    # -- licorice arch --------------------------------------------------------
    def test_licorice_arch_span_and_feet_colliders_stay_off_the_path(self):
        entry = self.report["CV3_LicoriceArch"]
        self.assertGreaterEqual(entry["clearance"]["width"], 24.0)
        self.assertGreaterEqual(entry["size"][0], 40.0)
        for c in entry["collision"]:
            self.assertGreaterEqual(abs(c["center"][0]) - c["size"][0] / 2, cs.SPECS["CV3_LicoriceArch"]["clear"][0] / 2,
                                    c["name"])
        stripes = [label for label in cs.SPECS["CV3_LicoriceArch"]["parts"] if label != "Clouds"]
        self.assertEqual(len(stripes), 6, "six rainbow stripes")

    # -- cake modules ---------------------------------------------------------
    def test_cake_modules_snap(self):
        base, ramp, top = (self.report[n] for n in cs.CAKE)
        walk = cs.SPECS["CV3_CakeBase"]["walk"]
        self.assertAlmostEqual(base["snap"]["sockets"]["top_tier"][2], walk, delta=0.01)
        self.assertAlmostEqual(ramp["snap"]["sockets"]["high_end"][2], walk, delta=0.01)
        self.assertAlmostEqual(cs.SPECS["CV3_CakeRamp"]["walk"], walk)
        body = next(c for c in base["collision"] if c["name"] == "Collision_Body")
        for key in ("ramp_front", "ramp_right", "ramp_back", "ramp_left"):
            socket = base["snap"]["sockets"][key]
            self.assertAlmostEqual(math.hypot(socket[0] - body["center"][0], socket[1] - body["center"][1]),
                                   body["size"][0] / 2, delta=0.05)
            self.assertAlmostEqual(socket[2], 0.0, delta=0.01)
        top_body = next(c for c in top["collision"] if c["name"] == "Collision_Body")
        self.assertLess(top_body["size"][0], body["size"][0] - 8.0, "the top tier leaves a ledge to walk on")
        self.assertAlmostEqual(ramp["snap"]["sockets"]["high_end"][1], ramp["bbox_max"][1], delta=0.01)
        self.assertAlmostEqual(ramp["snap"]["sockets"]["low_end"][1], ramp["bbox_min"][1], delta=0.01)

    # -- cookies ----------------------------------------------------------------
    def test_cookies_come_in_three_sizes_with_stable_flat_colliders(self):
        diameters = []
        for name in cs.COOKIES:
            with self.subTest(cookie=name):
                entry, walk = self.report[name], cs.SPECS[name]["walk"]
                diameters.append(entry["size"][0])
                slab = [c for c in entry["collision"] if c["name"] == "Collision_Slab"]
                self.assertEqual(len(slab), 1)
                self.assertAlmostEqual(slab[0]["center"][2] + slab[0]["size"][2] / 2, walk, delta=0.01)
                self.assertAlmostEqual(slab[0]["center"][2] - slab[0]["size"][2] / 2, 0.0, delta=0.01)
                self.assertGreaterEqual(slab[0]["size"][0], entry["size"][0] * 0.85)
                top = [v for v in self.points(name, "Dough") if v[2] > walk - 0.01]
                self.assertTrue(top)
                self.assertTrue(all(abs(v[2] - walk) < 1e-3 for v in top), "flat top")
                chips_top = max(v[2] for v in self.points(name, "Chips"))
                self.assertLessEqual(chips_top - walk, 0.2, "chips barely rise: no tripping")
        self.assertEqual(diameters, sorted(diameters))
        self.assertLess(diameters[0], 9.0)
        self.assertGreater(diameters[-1], 20.0)


if __name__ == "__main__":
    unittest.main()

"""Spec tests for the Frozen Mountains kit (expansion bible 5.1, 5.2 and 5.4).

Run with: python -I -B -m unittest discover -s tools -p "test_frozen_mountains_kit.py"

Standard library only. Artifacts come from tools/build-frozen-mountains-kit.py, run headless:
  "D:/blender/blender.exe" --background --factory-startup --python tools/build-frozen-mountains-kit.py
  FROZEN_MOUNTAINS_KIT_MODE=verify-fbx "D:/blender/blender.exe" --background --factory-startup --python tools/build-frozen-mountains-kit.py

The table below is the contract, copied from the bible, not from the builder. Sizes, clearances,
shelter boxes and no-track rectangles are recomputed from the geometry dump. Every value is
unvalidated: nothing was imported into Roblox, so scale there and phone cost stay unmeasured.
"""

import math
import unittest

from biome_kit_spec import BiomeKitMixin
from kit_spec_common import ROOT, load_json

KIT_DIR = ROOT / "assets/blender/frozen-mountains-kit"
EXPORT_DIR = ROOT / "assets/exports/frozen-mountains-kit"

# size is (x, y, z) in studs, tris the budget, parts map label to (hex, part budget).
SPECS = {
    "FM_SnowPine": {
        "size": (18.0, 18.0, 26.0), "tris": 360,
        "parts": {"Trunk": ("4A3B33", 110), "Canopy": ("2F5450", 170), "Snow": ("E6EFF4", 80)},
        "match_tops": ("Snow", "Canopy", 0.5),
    },
    "FM_IceSpire": {
        "size": (7.0, 7.0, 14.0), "tris": 180,
        "parts": {"Ice": ("9CCBE0", 140), "Base": ("566069", 40)},
        "gather": (0.0, -3.0, 2.0),
    },
    "FM_RockOverhang": {
        "size": (20.0, 12.0, 9.0), "tris": 340,
        "parts": {"Rock": ("566069", 250), "Snow": ("E6EFF4", 90)},
        "clear_box": ((-6.0, -6.0, 0.0), (6.0, 2.0, 6.0)), "occluder": 6.0, "no_track": True,
    },
    "FM_ScourShelf": {
        "size": (16.0, 16.0, 1.0), "tris": 120,
        "parts": {"Rock": ("566069", 120)},
        "walk": 1.0, "no_track": True,
    },
    "FM_Cairn": {
        "size": (4.0, 4.0, 6.0), "tris": 120,
        "parts": {"Stones": ("566069", 90), "Ribbon": ("E0602A", 30)},
        "part_top_above": {"Ribbon": 5.0},
    },
    "FM_SnowMound": {
        "size": (6.0, 6.0, 3.0), "tris": 60,
        "parts": {"Mound": ("E6EFF4", 60)},
        "tiny": 3.3,
    },
    "FM_IcePass": {
        "size": (30.0, 14.0, 18.0), "tris": 520,
        "parts": {"Ice": ("9CCBE0", 320), "Rock": ("566069", 200)},
        "clear": (16.0, 11.0), "limit": (32.0, 16.0),
    },
}


class FrozenMountainsKit(BiomeKitMixin, unittest.TestCase):
    SPECS = SPECS
    REPORT = KIT_DIR / "frozen-mountains-kit-report.json"
    GEOMETRY = KIT_DIR / "frozen-mountains-kit-geometry.json"
    ROUNDTRIP = KIT_DIR / "fbx-roundtrip.json"
    BLEND = KIT_DIR / "frozen-mountains-kit-v1.blend"
    RENDER_DIR = KIT_DIR
    EXPORT_DIR = EXPORT_DIR


def components(part):
    """Number of vertex-connected shells in one dumped part."""
    parent = list(range(len(part["vertices"])))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for triple in part["triangles"]:
        for other in triple[1:]:
            parent[find(other)] = find(triple[0])
    return len({find(i) for t in part["triangles"] for i in t})


class FrozenMountainsForm(unittest.TestCase):
    """Form rules from the bible's "Form" column that the generic rules cannot express."""

    @classmethod
    def setUpClass(cls):
        cls.geometry = load_json(FrozenMountainsKit.GEOMETRY)
        cls.report = load_json(FrozenMountainsKit.REPORT)["props"]

    def part(self, asset, label):
        return self.geometry[asset]["parts"][f"{asset}_{label}"]

    def test_snow_pine_is_three_tiers_with_a_cap_on_each(self):
        self.assertEqual(components(self.part("FM_SnowPine", "Canopy")), 3)
        self.assertEqual(components(self.part("FM_SnowPine", "Snow")), 3)

    def test_snow_pine_trunk_is_narrow_and_straight(self):
        trunk = [v for v in self.part("FM_SnowPine", "Trunk")["vertices"] if v[2] > 3.0]
        self.assertLessEqual(max(math.hypot(v[0], v[1]) for v in trunk), 1.6)

    def test_ice_spire_leans(self):
        ice = self.part("FM_IceSpire", "Ice")["vertices"]
        tip = max(ice, key=lambda v: v[2])
        self.assertGreaterEqual(abs(tip[0]) + abs(tip[1]), 1.5, "the main shard must lean")

    def test_overhang_no_track_rect_is_the_shelter_floor(self):
        rects = self.report["FM_RockOverhang"]["no_track_rects"]
        self.assertEqual(len(rects), 1)
        self.assertAlmostEqual(rects[0]["center"][0], 0.0, delta=0.05)
        self.assertAlmostEqual(rects[0]["center"][1], -2.0, delta=0.05)
        self.assertAlmostEqual(rects[0]["size"][0], 12.0, delta=0.05)
        self.assertAlmostEqual(rects[0]["size"][1], 8.0, delta=0.05)

    def test_overhang_is_open_to_minus_y_and_closed_behind(self):
        rock = self.part("FM_RockOverhang", "Rock")["vertices"]
        self.assertGreaterEqual(max(v[1] for v in rock), 5.5, "a back wall closes +Y")
        back = [v for v in rock if v[1] > 3.0 and v[2] > 1.0]
        self.assertGreaterEqual(max(v[2] for v in back), 6.0)

    def test_scour_shelf_outline_is_uneven_and_no_track_rect_is_square_inside_it(self):
        top = [v for v in self.part("FM_ScourShelf", "Rock")["vertices"] if v[2] >= 0.95 and (v[0], v[1]) != (0.0, 0.0)]
        radii = [math.hypot(v[0], v[1]) for v in top]
        self.assertGreaterEqual(max(radii) - min(radii), 0.5, "outline must not be a circle")
        (rect,) = self.report["FM_ScourShelf"]["no_track_rects"]
        self.assertAlmostEqual(rect["size"][0], rect["size"][1], delta=0.01)
        self.assertGreaterEqual(rect["size"][0], 9.0)

    def test_cairn_is_five_stacked_stones(self):
        stones = self.part("FM_Cairn", "Stones")
        self.assertEqual(components(stones), 5)
        self.assertLessEqual(max(v[2] for v in stones["vertices"]), 5.2, "the ribbon rides above the stack")

    def test_snow_mound_is_one_hump(self):
        self.assertEqual(components(self.part("FM_SnowMound", "Mound")), 1)

    def test_ice_pass_has_two_rock_legs_and_an_ice_lintel_across(self):
        ice = self.part("FM_IcePass", "Ice")["vertices"]
        self.assertLessEqual(min(v[0] for v in ice), -14.0)
        self.assertGreaterEqual(max(v[0] for v in ice), 14.0)
        rock = self.part("FM_IcePass", "Rock")["vertices"]
        left = [v for v in rock if v[0] < 0]
        right = [v for v in rock if v[0] > 0]
        self.assertTrue(left and right, "rock on both sides of the path")
        self.assertGreaterEqual(min(abs(v[0]) for v in rock if v[2] < 11.0), 8.0, "legs stay outside the passage")


if __name__ == "__main__":
    unittest.main()

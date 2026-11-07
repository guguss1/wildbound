"""Spec tests for the Living Forest kit (expansion bible 5.1, 5.2 and 5.3).

Run with: python -I -B -m unittest discover -s tools -p "test_living_forest_kit.py"

Standard library only. Artifacts come from tools/build-living-forest-kit.py, run headless:
  "D:/blender/blender.exe" --background --factory-startup --python tools/build-living-forest-kit.py
  LIVING_FOREST_KIT_MODE=verify-fbx "D:/blender/blender.exe" --background --factory-startup --python tools/build-living-forest-kit.py

The table below is the contract, copied from the bible, not from the builder. Sizes, clearances
and tags are recomputed from the geometry dump. Every value is unvalidated: nothing was
imported into Roblox, so scale there and phone cost stay unmeasured.
"""

import math
import unittest

from biome_kit_spec import BiomeKitMixin
from kit_spec_common import ROOT, load_json

KIT_DIR = ROOT / "assets/blender/living-forest-kit"
EXPORT_DIR = ROOT / "assets/exports/living-forest-kit"

# size is (x, y, z) in studs, tris the budget, parts map label to (hex, part budget).
SPECS = {
    "LF_Broadleaf": {
        "size": (24.0, 24.0, 32.0), "tris": 480,
        "parts": {"Trunk": ("6B4A2F", 170), "Crown": ("5E9A3C", 310)},
        "part_min_z": {"Crown": 12.0},
    },
    "LF_ResinStump": {
        "size": (6.0, 6.0, 6.0), "tris": 180,
        "parts": {"Stump": ("6B4A2F", 130), "Resin": ("D98A1F", 50)},
        "gather": (0.0, -3.0, 2.5),
    },
    "LF_FlowerClump": {
        "size": (5.0, 5.0, 2.5), "tris": 90,
        "parts": {"Stems": ("5E9A3C", 40), "Petals": ("F2C14E", 50)},
        "tiny": 3.0,
    },
    "LF_StreamStone": {
        "size": (5.0, 4.0, 1.0), "tris": 80,
        "parts": {"Stone": ("8C8A7E", 60), "Moss": ("8DB04A", 20)},
        "walk": 1.0,
    },
    "LF_HollowArch": {
        "size": (30.0, 14.0, 18.0), "tris": 520,
        "parts": {"Wood": ("6B4A2F", 400), "Leaf": ("5E9A3C", 120)},
        "clear": (16.0, 11.0), "limit": (32.0, 16.0),
    },
    "LF_TrailPost": {
        "size": (3.0, 3.0, 7.0), "tris": 160,
        "parts": {"Post": ("C9A876", 90), "Ribbon": ("D9482B", 40), "Stones": ("8C8A7E", 30)},
        "part_top_above": {"Ribbon": 5.0},
    },
    "LF_LogBridge": {
        "size": (5.0, 18.0, 2.2), "tris": 300,
        "parts": {"Bark": ("6B4A2F", 230), "Moss": ("8DB04A", 70)},
        "walk": 2.2, "ramps": 2,
    },
}


class LivingForestKit(BiomeKitMixin, unittest.TestCase):
    SPECS = SPECS
    REPORT = KIT_DIR / "living-forest-kit-report.json"
    GEOMETRY = KIT_DIR / "living-forest-kit-geometry.json"
    ROUNDTRIP = KIT_DIR / "fbx-roundtrip.json"
    BLEND = KIT_DIR / "living-forest-kit-v1.blend"
    RENDER_DIR = KIT_DIR
    EXPORT_DIR = EXPORT_DIR


class LivingForestForm(unittest.TestCase):
    """Form rules from the bible's "Form" column that the generic rules cannot express."""

    @classmethod
    def setUpClass(cls):
        cls.geometry = load_json(LivingForestKit.GEOMETRY)

    def points(self, asset, label):
        part = self.geometry[asset]["parts"][f"{asset}_{label}"]
        return part["vertices"]

    def test_resin_runs_down_the_minus_y_side(self):
        resin = self.points("LF_ResinStump", "Resin")
        self.assertLess(sum(v[1] for v in resin) / len(resin), -1.5)

    def test_moss_sits_on_one_edge_of_the_stream_stone(self):
        moss = self.points("LF_StreamStone", "Moss")
        centre_x = sum(v[0] for v in moss) / len(moss)
        centre_y = sum(v[1] for v in moss) / len(moss)
        self.assertGreater(max(abs(centre_x), abs(centre_y)), 0.8, "moss must hug one edge, not the middle")

    def test_trunk_is_a_single_upright_column(self):
        trunk = self.points("LF_Broadleaf", "Trunk")
        crown_base = min(v[2] for v in self.points("LF_Broadleaf", "Crown"))
        stem = [v for v in trunk if 3.0 <= v[2] <= crown_base]
        self.assertTrue(stem)
        self.assertLessEqual(max(math.hypot(v[0], v[1]) for v in stem), 2.6, "trunk must stay thick and straight")

    def test_arch_has_no_exposed_roots_near_the_path(self):
        wood = self.points("LF_HollowArch", "Wood")
        feet = [v for v in wood if v[2] < 1.0]
        self.assertTrue(feet)
        self.assertGreaterEqual(min(abs(v[0]) for v in feet), 8.0, "no root may cross the 16-wide passage")


if __name__ == "__main__":
    unittest.main()

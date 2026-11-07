"""Spec tests for the Living Forest kit (expansion bible 5.1, 5.2 and 5.3).

Run with: python -I -B -m unittest discover -s tools -p "test_living_forest_kit.py"

Standard library only. Artifacts come from tools/build-living-forest-kit.py, run headless:
  "D:/blender/blender.exe" --background --factory-startup --python tools/build-living-forest-kit.py
  LIVING_FOREST_KIT_MODE=verify-fbx "D:/blender/blender.exe" --background --factory-startup --python tools/build-living-forest-kit.py

The table below is the contract, copied from the bible, not from the builder. Sizes, clearances
and tags are recomputed from the geometry dump. Every value is unvalidated: nothing was
imported into Roblox, so scale there and phone cost stay unmeasured.
"""

import unittest

from biome_kit_spec import BiomeKitMixin
from kit_spec_common import ROOT

KIT_DIR = ROOT / "assets/blender/living-forest-kit"
EXPORT_DIR = ROOT / "assets/exports/living-forest-kit"

# size is (x, y, z) in studs, tris the budget, parts map label to (hex, part budget).
SPECS = {
    "LF_FlowerClump": {
        "size": (5.0, 5.0, 2.5), "tris": 90,
        "parts": {"Stems": ("5E9A3C", 40), "Petals": ("F2C14E", 50)},
        "tiny": 3.0,
    },
    "LF_TrailPost": {
        "size": (3.0, 3.0, 7.0), "tris": 160,
        "parts": {"Post": ("C9A876", 90), "Ribbon": ("D9482B", 40), "Stones": ("8C8A7E", 30)},
        "part_top_above": {"Ribbon": 5.0},
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


if __name__ == "__main__":
    unittest.main()

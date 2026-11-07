"""Spec tests for the Volcanic Lands kit (expansion bible 5.1, 5.2 and 5.6).

Run with: python -I -B -m unittest discover -s tools -p "test_volcanic_lands_kit.py"

Standard library only. Artifacts come from tools/build-volcanic-lands-kit.py, run headless:
  "D:/blender/blender.exe" --background --factory-startup --python tools/build-volcanic-lands-kit.py
  VOLCANIC_LANDS_KIT_MODE=verify-fbx "D:/blender/blender.exe" --background --factory-startup --python tools/build-volcanic-lands-kit.py

The table below is the contract, copied from the bible, not from the builder. Sizes, clearances, walk
surfaces, gather points and occluders are recomputed from the geometry dump. Every value is unvalidated:
nothing was imported into Roblox, so scale there and phone cost stay unmeasured.

Naming note: the bible lists the glowing parts as `Glow`, `Ember` and `Crack` with palette VL_Neon_Magma. The
shared G8 and G9 tests recognise a glowing part by a `Neon_` label (material name equals object name), so those
parts are labelled `Neon_Magma`. Their colour and budget are the bible's.
"""

import math
import unittest

from biome_kit_spec import BiomeKitMixin
from kit_spec_common import ROOT, asset_triangles, bounds, load_json, part_triangles

KIT_DIR = ROOT / "assets/blender/volcanic-lands-kit"
EXPORT_DIR = ROOT / "assets/exports/volcanic-lands-kit"

# size is (x, y, z) in studs, tris the budget, parts map label to (hex, part budget).
SPECS = {
    "VL_BasaltColumn": {
        "size": (8.0, 8.0, 12.0), "tris": 120,
        "parts": {"Rock": ("2E2B2C", 120)},
        "occluder": 10.0,
    },
    "VL_Vent": {
        "size": (10.0, 10.0, 3.0), "tris": 160,
        "parts": {"Cone": ("6F6863", 110), "Neon_Magma": ("C8481A", 50)},
        "tiny": 3.3,
    },
    "VL_CoolStone": {
        "size": (6.0, 5.0, 1.0), "tris": 80,
        "parts": {"Stone": ("6C7A85", 80)},
        "walk": 1.0,
    },
    "VL_CharredTree": {
        "size": (12.0, 12.0, 16.0), "tris": 220,
        "parts": {"Wood": ("241F1D", 190), "Neon_Magma": ("C8481A", 30)},
    },
    "VL_AshShrine": {
        "size": (28.0, 14.0, 16.0), "tris": 480,
        "parts": {"Stone": ("6F6863", 380), "Trim": ("A8692C", 100)},
        "clear": (14.0, 11.0), "limit": (30.0, 16.0), "occluder": 11.0,
    },
    "VL_CrustPlate": {
        "size": (20.0, 20.0, 0.5), "tris": 120,
        "parts": {"Crust": ("2E2B2C", 90), "Neon_Magma": ("C8481A", 30)},
        "walk": 0.5,
    },
    "VL_ObsidianShard": {
        "size": (5.0, 5.0, 4.0), "tris": 90,
        "parts": {"Shard": ("1A1A24", 70), "Base": ("6F6863", 20)},
        "gather": (0.0, -2.5, 1.5),
    },
}


class VolcanicLandsKit(BiomeKitMixin, unittest.TestCase):
    SPECS = SPECS
    REPORT = KIT_DIR / "volcanic-lands-kit-report.json"
    GEOMETRY = KIT_DIR / "volcanic-lands-kit-geometry.json"
    ROUNDTRIP = KIT_DIR / "fbx-roundtrip.json"
    BLEND = KIT_DIR / "volcanic-lands-kit-v1.blend"
    RENDER_DIR = KIT_DIR
    EXPORT_DIR = EXPORT_DIR


def shells(part):
    """Vertex lists of each vertex-connected shell of one dumped part."""
    parent = list(range(len(part["vertices"])))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for triple in part["triangles"]:
        for other in triple[1:]:
            parent[find(other)] = find(triple[0])
    groups = {}
    for i in {i for t in part["triangles"] for i in t}:
        groups.setdefault(find(i), []).append(part["vertices"][i])
    return list(groups.values())


def inside_rotated_box(box, x, y, z):
    cx, cy, cz = box["center"]
    sx, sy, sz = (s / 2 for s in box["size"])
    return abs(x - cx) <= sx and abs(y - cy) <= sy and abs(z - cz) <= sz


class VolcanicLandsReads(unittest.TestCase):
    """Visual reads. Each fails on the bare primitive it replaces: a hex prism, a cone, a plank, a log, a gate."""

    @classmethod
    def setUpClass(cls):
        cls.geometry = load_json(VolcanicLandsKit.GEOMETRY)
        cls.report = load_json(VolcanicLandsKit.REPORT)["props"]

    def part(self, asset, label):
        return self.geometry[asset]["parts"][f"{asset}_{label}"]

    # -- VL_BasaltColumn -------------------------------------------------
    def test_basalt_is_four_shells_with_three_different_tall_tops(self):
        found = shells(self.part("VL_BasaltColumn", "Rock"))
        self.assertGreaterEqual(len(found), 4, "three columns and a fallen piece")
        tops = sorted((max(v[2] for v in shell) for shell in found), reverse=True)
        self.assertGreaterEqual(tops[0], 11.0)
        self.assertGreaterEqual(tops[0] - tops[2], 4.0, f"column tops {[round(t, 1) for t in tops]}")

    def test_basalt_tops_are_tilted_and_chipped_not_flat(self):
        for shell in shells(self.part("VL_BasaltColumn", "Rock")):
            high = max(v[2] for v in shell)
            if high < 5.0:
                continue
            crown = [v[2] for v in shell if v[2] > high - 1.2]
            self.assertGreaterEqual(max(crown) - min(crown), 0.4, f"a column top at {high:.1f} is a flat cap")

    # -- VL_Vent ---------------------------------------------------------
    def test_vent_rim_is_broken_and_uneven(self):
        cone = self.part("VL_Vent", "Cone")["vertices"]
        crest = [v for v in cone if v[2] > 2.0]
        self.assertGreaterEqual(max(v[2] for v in crest) - min(v[2] for v in crest), 0.5, "the rim needs a notch")
        radii = [math.hypot(v[0], v[1]) for v in crest]
        self.assertGreaterEqual(max(radii) - min(radii), 0.5)

    def test_vent_glow_lies_inside_the_crater_below_the_rim(self):
        cone = self.part("VL_Vent", "Cone")["vertices"]
        glow = self.part("VL_Vent", "Neon_Magma")["vertices"]
        self.assertLess(max(v[2] for v in glow), max(v[2] for v in cone) - 0.3)
        self.assertGreater(min(v[2] for v in glow), 0.8)
        self.assertLessEqual(max(math.hypot(v[0], v[1]) for v in glow), 2.6)

    # -- VL_CoolStone ----------------------------------------------------
    def test_cool_stone_outline_is_irregular_and_top_is_one_flat_level(self):
        stone = self.part("VL_CoolStone", "Stone")["vertices"]
        top = [v for v in stone if v[2] > 0.95]
        self.assertGreaterEqual(len(top), 8)
        self.assertLessEqual(max(v[2] for v in top) - min(v[2] for v in top), 0.01)
        base = [v for v in stone if v[2] < 0.05]
        radii = [math.hypot(v[0] / 3.0, v[1] / 2.5) for v in base]
        self.assertGreaterEqual(max(radii) / min(radii), 1.12)

    # -- VL_CharredTree --------------------------------------------------
    def test_tree_trunk_bends_narrows_and_breaks_off_jagged(self):
        wood = self.part("VL_CharredTree", "Wood")
        trunk = max(shells(wood), key=len)

        def centre(low, high):
            band = [v for v in trunk if low <= v[2] <= high]
            return (sum(v[0] for v in band) / len(band), sum(v[1] for v in band) / len(band))

        near, far = centre(2.0, 6.5), centre(9.0, 13.0)
        self.assertGreaterEqual(math.dist(near, far), 0.6, "the trunk must lean or bend")

        def width(low, high):
            band = [v for v in trunk if low <= v[2] <= high]
            return max(v[0] for v in band) - min(v[0] for v in band)

        self.assertGreaterEqual(width(0.0, 1.5) / width(9.0, 11.5), 1.4)
        crown = [v[2] for v in trunk if v[2] > max(w[2] for w in trunk) - 2.0]
        self.assertGreaterEqual(max(crown) - min(crown), 1.0, "a burned break is jagged")

    def test_tree_has_stubs_that_reach_out(self):
        shell_list = shells(self.part("VL_CharredTree", "Wood"))
        self.assertGreaterEqual(len(shell_list), 4)
        trunk = max(shell_list, key=len)
        axis = (sum(v[0] for v in trunk) / len(trunk), sum(v[1] for v in trunk) / len(trunk))
        reach = sorted((max(math.hypot(v[0] - axis[0], v[1] - axis[1]) for v in shell) for shell in shell_list
                        if shell is not trunk), reverse=True)
        self.assertGreaterEqual(reach[0], 3.5)
        self.assertGreaterEqual(reach[1], 3.0)

    def test_tree_ember_seams_cling_to_the_trunk(self):
        ember = self.part("VL_CharredTree", "Neon_Magma")
        self.assertGreaterEqual(len(shells(ember)), 2)
        z = [v[2] for v in ember["vertices"]]
        self.assertGreaterEqual(min(z), 0.5)
        self.assertLessEqual(max(z), 14.0)

    # -- VL_AshShrine ----------------------------------------------------
    def test_shrine_piers_step_in_as_they_rise(self):
        triangles = part_triangles(self.part("VL_AshShrine", "Stone"))
        for side in (-1, 1):
            reach = []
            for z in (2.0, 5.7, 9.3):  # mid-height of each tier, cut through the triangles
                cuts = []
                for tri in triangles:
                    for p, q in ((tri[0], tri[1]), (tri[1], tri[2]), (tri[2], tri[0])):
                        if (p[2] - z) * (q[2] - z) < 0:
                            x = p[0] + (z - p[2]) / (q[2] - p[2]) * (q[0] - p[0])
                            if x * side > 6.5:
                                cuts.append(abs(x))
                self.assertTrue(cuts, f"no pier stone at z {z}")
                reach.append(max(cuts))
            self.assertGreaterEqual(reach[0] - reach[1], 0.4, f"side {side}: {reach}")
            self.assertGreaterEqual(reach[1] - reach[2], 0.4, f"side {side}: {reach}")

    def test_shrine_lintel_is_stepped_and_the_piers_do_not_match(self):
        stone = self.part("VL_AshShrine", "Stone")["vertices"]
        wide = max(abs(v[0]) for v in stone if 11.1 <= v[2] <= 13.0)
        narrow = max(abs(v[0]) for v in stone if v[2] >= 14.8)
        self.assertGreaterEqual(wide - narrow, 2.5, "the lintel steps in toward the top")
        tops = [max(v[2] for v in stone if v[0] * side > 7.0 and v[2] <= 11.0) for side in (-1, 1)]
        self.assertGreaterEqual(abs(tops[0] - tops[1]), 0.3, "one pier is broken lower than the other")

    def test_shrine_ochre_band_crosses_both_piers_and_the_lintel(self):
        trim = self.part("VL_AshShrine", "Trim")["vertices"]
        self.assertLessEqual(min(v[0] for v in trim), -11.0)
        self.assertGreaterEqual(max(v[0] for v in trim), 11.0)
        self.assertGreaterEqual(max(v[2] for v in trim), 12.0)
        self.assertLessEqual(min(v[2] for v in trim), 8.0)

    # -- VL_CrustPlate ---------------------------------------------------
    def test_crust_plate_outline_is_irregular_and_the_seam_wanders_and_stands_proud(self):
        crust = self.part("VL_CrustPlate", "Crust")["vertices"]
        radii = [math.hypot(v[0], v[1]) for v in crust if v[2] > 0.4 and math.hypot(v[0], v[1]) > 1.0]  # not the fan centre
        self.assertGreaterEqual(max(radii) / min(radii), 1.12)
        seam = self.part("VL_CrustPlate", "Neon_Magma")["vertices"]
        xs, ys = [v[0] for v in seam], [v[1] for v in seam]
        spans = sorted((max(xs) - min(xs), max(ys) - min(ys)))
        self.assertGreaterEqual(spans[1], 12.0)
        self.assertGreaterEqual(spans[0], 3.0, "a straight seam reads as a painted line")
        self.assertGreaterEqual(max(v[2] for v in seam), max(v[2] for v in crust) + 0.025, "raised seams")

    # -- VL_ObsidianShard ------------------------------------------------
    def test_obsidian_is_three_flat_leaning_fins_of_different_heights(self):
        found = shells(self.part("VL_ObsidianShard", "Shard"))
        self.assertEqual(len(found), 3)
        heights, leans, flats = [], [], 0
        for shell in found:
            tip = max(shell, key=lambda v: v[2])
            base = [v for v in shell if v[2] < tip[2] - 0.6]
            cx = sum(v[0] for v in base) / len(base)
            cy = sum(v[1] for v in base) / len(base)
            heights.append(tip[2])
            leans.append(math.hypot(tip[0] - cx, tip[1] - cy))
            band = [v for v in shell if 0.8 < v[2] < tip[2] - 0.5]
            mx, my = sum(v[0] for v in band) / len(band), sum(v[1] for v in band) / len(band)
            sxx = sum((v[0] - mx) ** 2 for v in band)
            syy = sum((v[1] - my) ** 2 for v in band)
            sxy = sum((v[0] - mx) * (v[1] - my) for v in band)
            mean, diff = (sxx + syy) / 2, math.hypot((sxx - syy) / 2, sxy)
            if mean - diff > 1e-9 and math.sqrt((mean + diff) / (mean - diff)) >= 1.6:
                flats += 1
        self.assertGreaterEqual(max(heights) / min(heights), 1.3)
        self.assertGreaterEqual(sum(1 for lean in leans if lean >= 0.4), 2)
        self.assertGreaterEqual(flats, 2, "glassy fins are blades, not rods")


class VolcanicLandsBoxes(unittest.TestCase):
    """Occluder boxes for the two props that block sight, recomputed against the dump."""

    @classmethod
    def setUpClass(cls):
        cls.geometry = load_json(VolcanicLandsKit.GEOMETRY)
        cls.report = load_json(VolcanicLandsKit.REPORT)["props"]

    def test_shrine_occluders_cover_each_pier_and_leave_the_gateway_open(self):
        boxes = self.report["VL_AshShrine"]["occluders"]
        for side in (-1, 1):
            for y in (-3.0, 0.0, 3.0):
                for z in (1.0, 5.0, 9.5):
                    self.assertTrue(any(inside_rotated_box(b, side * 10.0, y, z) for b in boxes),
                                    f"pier at x={side * 10.0}, y={y}, z={z}")
        for x in (-6.5, -3.0, 0.0, 3.0, 6.5):
            for z in (1.0, 5.0, 10.0):
                self.assertFalse(any(inside_rotated_box(b, x, 0.0, z) for b in boxes), f"blocks ({x}, 0, {z})")

    def test_basalt_occluder_hides_a_standing_avatar_behind_the_cluster(self):
        boxes = self.report["VL_BasaltColumn"]["occluders"]
        low, high = bounds(asset_triangles(self.geometry["VL_BasaltColumn"]))
        top = max(box["center"][2] + box["size"][2] / 2 for box in boxes)
        self.assertGreaterEqual(top, 10.0)
        for box in boxes:
            self.assertGreaterEqual(box["center"][2] - box["size"][2] / 2, -0.01)
            self.assertLessEqual(box["size"][0], high[0] - low[0] + 0.5)


if __name__ == "__main__":
    unittest.main()

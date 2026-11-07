"""Spec tests for the Cryptic Ruins kit (expansion bible 5.1, 5.2 and 5.7).

Run with: python -I -B -m unittest discover -s tools -p "test_cryptic_ruins_kit.py"

Standard library only. Artifacts come from tools/build-cryptic-ruins-kit.py, run headless:
  "D:/blender/blender.exe" --background --factory-startup --python tools/build-cryptic-ruins-kit.py
  CRYPTIC_RUINS_KIT_MODE=verify-fbx "D:/blender/blender.exe" --background --factory-startup --python tools/build-cryptic-ruins-kit.py

The table below is the contract, copied from the bible, not from the builder. Sizes, clearances, gaps between
columns, walk surfaces, step heights and occluder boxes are recomputed from the geometry dump. Every value is
unvalidated: nothing was imported into Roblox, so scale there and phone cost stay unmeasured.

Two recorded conflicts, not worked around:
  * The glowing part is labelled Neon_Glyph (the shared G8 and G9 tests recognise glow by a Neon_ label). The
    bible calls it Glyph.
  * CR_Plinth carries both `walk` and `tiny`. The shared W1 test needs `collision_boxes` in the report and the
    shared N1 test forbids them on the same asset, so both cannot pass. The plinth keeps `walk` in SPECS and the
    N1 height limit (2.2) is checked in PlinthAndStones below, without the collision-box clause.
"""

import math
import unittest

from biome_kit_spec import BiomeKitMixin, clip_axis, top_height
from kit_spec_common import ROOT, asset_triangles, bounds, load_json, part_triangles

KIT_DIR = ROOT / "assets/blender/cryptic-ruins-kit"
EXPORT_DIR = ROOT / "assets/exports/cryptic-ruins-kit"

# size is (x, y, z) in studs, tris the budget, parts map label to (hex, part budget).
SPECS = {
    "CR_Colonnade": {
        "size": (24.0, 5.0, 14.0), "tris": 420,
        "parts": {"Stone": ("77717F", 360), "Trim": ("3B2F50", 60)},
        "occluder": 11.0,
    },
    "CR_BrokenWall": {
        "size": (14.0, 3.0, 9.0), "tris": 260,
        "parts": {"Stone": ("77717F", 220), "Moss": ("6C7452", 40)},
        "occluder": 7.0,
    },
    "CR_Plinth": {
        "size": (6.0, 6.0, 2.0), "tris": 100,
        "parts": {"Stone": ("77717F", 70), "Neon_Glyph": ("C9A24A", 30)},
        "walk": 2.0,
    },
    "CR_Archway": {
        "size": (28.0, 8.0, 18.0), "tris": 560,
        "parts": {"Stone": ("77717F", 460), "Trim": ("3B2F50", 100)},
        "clear": (14.0, 11.0), "limit": (30.0, 16.0), "occluder": 11.0,
    },
    "CR_Reliquary": {
        "size": (8.0, 4.0, 4.0), "tris": 200,
        "parts": {"Stone": ("77717F", 150), "Trim": ("3B2F50", 50)},
        "gather": (0.0, 0.0, 4.0),
    },
    "CR_GlyphStone": {
        "size": (4.0, 3.0, 5.0), "tris": 120,
        "parts": {"Stone": ("77717F", 90), "Neon_Glyph": ("C9A24A", 30)},
    },
    "CR_StairRun": {
        "size": (16.0, 12.0, 6.0), "tris": 180,
        "parts": {"Stone": ("77717F", 180)},
        "walk": 6.0, "ramps": 1,
    },
}


class CrypticRuinsKit(BiomeKitMixin, unittest.TestCase):
    SPECS = SPECS
    REPORT = KIT_DIR / "cryptic-ruins-kit-report.json"
    GEOMETRY = KIT_DIR / "cryptic-ruins-kit-geometry.json"
    ROUNDTRIP = KIT_DIR / "fbx-roundtrip.json"
    BLEND = KIT_DIR / "cryptic-ruins-kit-v1.blend"
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


def inside_box(box, x, y, z):
    cx, cy, cz = box["center"]
    sx, sy, sz = (s / 2 for s in box["size"])
    return abs(x - cx) <= sx and abs(y - cy) <= sy and abs(z - cz) <= sz


def free_gaps(triangles, below, left, right, step=0.05):
    """Widths of the empty X stretches between left and right, for geometry under `below`, seen along Y."""
    covered = []
    for tri in triangles:
        kept = clip_axis([(v[0], v[2]) for v in tri], 1, 0.0, below)
        if kept:
            xs = [p[0] for p in kept]
            covered.append((min(xs), max(xs)))
    gaps, run, x = [], None, left
    while x <= right:
        hit = any(a - 1e-9 <= x <= b + 1e-9 for a, b in covered)
        if not hit and run is None:
            run = x
        if hit and run is not None:
            gaps.append(x - run)
            run = None
        x += step
    if run is not None:
        gaps.append(right - run)
    return gaps


class CrypticRuinsReads(unittest.TestCase):
    """Visual reads. Each fails on the bare primitive it replaces: a row of boxes, a flat wall, a block, a gate."""

    @classmethod
    def setUpClass(cls):
        cls.geometry = load_json(CrypticRuinsKit.GEOMETRY)
        cls.report = load_json(CrypticRuinsKit.REPORT)["props"]

    def part(self, asset, label):
        return self.geometry[asset]["parts"][f"{asset}_{label}"]

    # -- CR_Colonnade ----------------------------------------------------
    def test_colonnade_gaps_between_columns_stay_six_wide(self):
        triangles = part_triangles(self.part("CR_Colonnade", "Stone"))
        gaps = [g for g in free_gaps(triangles, 10.0, -9.0, 9.0) if g > 1.0]
        self.assertEqual(len(gaps), 2, f"gaps {gaps}")
        for gap in gaps:
            self.assertGreaterEqual(gap, 6.0)

    def test_colonnade_columns_are_stacked_drums_that_do_not_line_up(self):
        stone = self.part("CR_Colonnade", "Stone")
        found = shells(stone)
        self.assertGreaterEqual(len(found), 14, "drums, capitals, beam pieces and rubble are separate shells")
        for column_x in (-10.3, 0.0, 10.3):
            low = [v[0] for v in stone["vertices"] if abs(v[0] - column_x) < 2.6 and 2.4 < v[2] < 3.4]
            high = [v[0] for v in stone["vertices"] if abs(v[0] - column_x) < 2.6 and 6.5 < v[2] < 8.7]
            self.assertTrue(low and high, f"column at {column_x}")
        offsets = []
        for column_x in (-10.3, 0.0, 10.3):
            low = [v[0] for v in stone["vertices"] if abs(v[0] - column_x) < 2.6 and 2.4 < v[2] < 3.4]
            high = [v[0] for v in stone["vertices"] if abs(v[0] - column_x) < 2.6 and 6.5 < v[2] < 8.7]
            offsets.append(abs((min(low) + max(low)) / 2 - (min(high) + max(high)) / 2))
        self.assertGreaterEqual(max(offsets), 0.1, f"drum centres never shift: {offsets}")

    def test_colonnade_beam_is_cracked_and_uneven(self):
        stone = self.part("CR_Colonnade", "Stone")["vertices"]
        left = max(v[2] for v in stone if -12.0 < v[0] < -1.5)
        right = max(v[2] for v in stone if 1.5 < v[0] < 12.0)
        self.assertGreaterEqual(abs(left - right), 0.5, "the two halves of the beam sit at different heights")
        beam = [v[0] for v in stone if v[2] > 10.9]
        crack = [x for x in (i / 10 for i in range(-30, 31)) if not any(abs(v - x) < 0.12 for v in beam)]
        self.assertTrue(crack, "no crack in the beam")

    def test_colonnade_rubble_lies_at_the_foot(self):
        small = [s for s in shells(self.part("CR_Colonnade", "Stone")) if max(v[2] for v in s) < 2.0]
        self.assertGreaterEqual(len(small), 5, "column bases count, and at least two fallen blocks besides")

    def test_colonnade_occluders_are_one_box_per_column_and_leave_the_gaps_open(self):
        boxes = self.report["CR_Colonnade"]["occluders"]
        self.assertEqual(len(boxes), 3)
        for column_x in (-10.3, 0.0, 10.3):
            for y in (-1.5, 0.0, 1.5):
                for z in (1.0, 5.0, 10.0):
                    self.assertTrue(any(inside_box(b, column_x, y, z) for b in boxes), f"column {column_x}, z {z}")
        for x in (-6.0, -5.0, 5.0, 6.0):
            for z in (1.0, 5.0, 10.0):
                self.assertFalse(any(inside_box(b, x, 0.0, z) for b in boxes), f"gap at x={x}")

    # -- CR_BrokenWall ---------------------------------------------------
    def test_wall_top_steps_down_and_never_below_six(self):
        triangles = part_triangles(self.part("CR_BrokenWall", "Stone"))
        tops = [top_height(triangles, x, 0.0) for x in (-6, -4, -2, 0, 2, 4, 6)]
        self.assertNotIn(None, tops)
        self.assertGreaterEqual(max(tops) - min(tops), 2.5, f"stepped top heights {[round(t, 1) for t in tops]}")
        self.assertGreaterEqual(min(tops), 5.9, "an avatar must stay hidden along the full width")

    def test_wall_is_laid_in_courses_of_separate_blocks_with_moss_on_top(self):
        self.assertGreaterEqual(len(shells(self.part("CR_BrokenWall", "Stone"))), 14)
        moss = shells(self.part("CR_BrokenWall", "Moss"))
        self.assertGreaterEqual(len(moss), 2)
        self.assertGreaterEqual(max(v[2] for s in moss for v in s), 6.0)

    def test_wall_occluder_covers_the_full_width_at_least_five_tall(self):
        (box,) = self.report["CR_BrokenWall"]["occluders"]
        self.assertGreaterEqual(box["size"][0], 14.0 - 0.01)
        self.assertGreaterEqual(box["size"][2], 5.0)
        low, high = bounds(asset_triangles(self.geometry["CR_BrokenWall"]))
        self.assertLessEqual(box["center"][0] - box["size"][0] / 2, low[0] + 0.05)
        self.assertGreaterEqual(box["center"][0] + box["size"][0] / 2, high[0] - 0.05)

    # -- CR_Plinth, CR_GlyphStone ----------------------------------------
    def test_plinth_is_tiny_stepped_and_the_glyph_is_inset(self):
        stone, glyph = self.part("CR_Plinth", "Stone")["vertices"], self.part("CR_Plinth", "Neon_Glyph")["vertices"]
        self.assertLessEqual(max(v[2] for v in stone + glyph), 2.2, "N1 height limit")
        self.assertTrue(self.report["CR_Plinth"]["tiny"])
        self.assertLess(max(v[2] for v in glyph), max(v[2] for v in stone) - 0.04, "the glyph sits below the rim")
        gx = [v[0] for v in glyph]
        gy = [v[1] for v in glyph]
        self.assertLessEqual(max(gx) - min(gx), 3.0)
        self.assertLessEqual(max(gy) - min(gy), 3.0)

        def width(z):
            band = [v[0] for v in stone if abs(v[2] - z) <= 0.3]
            return max(band) - min(band)

        self.assertGreaterEqual(width(0.1) - width(1.65), 0.3, "a step, not a plain block")

    def test_glyph_stone_leans_narrows_and_carries_a_raised_plate_on_minus_y(self):
        stone, glyph = self.part("CR_GlyphStone", "Stone")["vertices"], self.part("CR_GlyphStone", "Neon_Glyph")["vertices"]
        low = [v for v in stone if v[2] < 0.6]
        high = [v for v in stone if v[2] > 4.0]
        shift = math.hypot(sum(v[0] for v in high) / len(high) - sum(v[0] for v in low) / len(low),
                           sum(v[1] for v in high) / len(high) - sum(v[1] for v in low) / len(low))
        self.assertGreaterEqual(shift, 0.25, "a standing stone that does not lean is a post")
        self.assertLessEqual((max(v[0] for v in high) - min(v[0] for v in high))
                             / (max(v[0] for v in low) - min(v[0] for v in low)), 0.8)
        self.assertLessEqual(max(v[1] for v in glyph), -0.2)
        self.assertLessEqual(min(v[1] for v in glyph), -0.9)
        self.assertLessEqual(max(v[1] for v in glyph) - min(v[1] for v in glyph), 0.5, "the plate is thin")

    # -- CR_Archway ------------------------------------------------------
    def test_archway_frame_is_thick_and_the_lintel_is_flat_and_stepped(self):
        stone = self.part("CR_Archway", "Stone")["vertices"]
        inner = [abs(v[0]) for v in stone if 7.0 < abs(v[0]) < 10.9 and v[2] < 10.0]
        self.assertGreaterEqual(max(inner) - min(inner), 3.0, "the inner pier is a thick jamb")
        under = [v[2] for v in stone if abs(v[0]) < 6.0 and 11.0 <= v[2] <= 12.0]
        self.assertTrue(under)
        self.assertLessEqual(max(under) - min(under), 0.35, "a flat lintel underside, unlike a curved arch")
        wide = max(abs(v[0]) for v in stone if 11.1 <= v[2] <= 13.8)
        narrow = max(abs(v[0]) for v in stone if v[2] >= 16.4)
        self.assertGreaterEqual(wide - narrow, 6.0, "the lintel steps in as it rises")

    def test_archway_piers_do_not_mirror_each_other_and_trim_bands_cross_the_frame(self):
        stone = self.part("CR_Archway", "Stone")["vertices"]
        tops = [max(v[2] for v in stone if v[0] * side > 7.0 and v[2] <= 11.2) for side in (-1, 1)]
        self.assertGreaterEqual(abs(tops[0] - tops[1]), 0.25)
        trim = self.part("CR_Archway", "Trim")["vertices"]
        self.assertLessEqual(min(v[0] for v in trim), -10.0)
        self.assertGreaterEqual(max(v[0] for v in trim), 10.0)
        self.assertGreaterEqual(max(v[2] for v in trim), 12.0)

    def test_archway_occluders_cover_each_pier_and_leave_the_gateway_open(self):
        boxes = self.report["CR_Archway"]["occluders"]
        for side in (-1, 1):
            for y in (-2.5, 0.0, 2.5):
                for z in (1.0, 5.0, 10.0):
                    self.assertTrue(any(inside_box(b, side * 9.0, y, z) for b in boxes), f"pier {side * 9.0}, {z}")
        for x in (-6.5, -3.0, 0.0, 3.0, 6.5):
            for z in (1.0, 5.0, 10.5):
                self.assertFalse(any(inside_box(b, x, 0.0, z) for b in boxes), f"blocks ({x}, 0, {z})")

    # -- CR_Reliquary ----------------------------------------------------
    def test_reliquary_has_a_shallow_recess_and_is_a_chest_not_a_coffin(self):
        stone = self.part("CR_Reliquary", "Stone")
        triangles = part_triangles(stone)
        rim = max(v[2] for v in stone["vertices"])
        centre = top_height(triangles, 0.0, 0.0)
        self.assertIsNotNone(centre)
        self.assertGreaterEqual(rim - centre, 0.4, "the top needs a recess")
        self.assertLessEqual(rim - centre, 1.3, "and it is shallow")
        self.assertGreaterEqual(centre, 2.4)

        def width(z):  # the section through the triangles at height z
            cuts = []
            for tri in triangles:
                for p, q in ((tri[0], tri[1]), (tri[1], tri[2]), (tri[2], tri[0])):
                    if (p[2] - z) * (q[2] - z) < 0:
                        cuts.append(p[0] + (z - p[2]) / (q[2] - p[2]) * (q[0] - p[0]))
            return max(cuts) - min(cuts)

        self.assertGreaterEqual(width(2.4) / width(0.2), 0.8, "straight sides: no tapered coffin outline")
        self.assertGreaterEqual(width(0.2) - width(2.0), 0.25, "the plinth is wider than the body")
        self.assertGreaterEqual(len(shells(stone)), 4, "plinth, body, posts and a rim")

    # -- CR_StairRun -----------------------------------------------------
    def test_stairs_are_six_treads_one_stud_apart(self):
        triangles = part_triangles(self.part("CR_StairRun", "Stone"))
        heights = []
        for k in range(6):
            y = -5.0 + 2.0 * k
            found = top_height(triangles, 0.0, y)
            self.assertIsNotNone(found, f"no tread at y={y}")
            heights.append(found)
        for k, found in enumerate(heights):
            self.assertAlmostEqual(found, k + 1.0, delta=0.3, msg=f"tread {k + 1}: {heights}")
        steps = [b - a for a, b in zip(heights, heights[1:])]
        self.assertGreaterEqual(min(steps), 0.7)
        self.assertLessEqual(max(steps), 1.3)

    def test_stairs_are_uneven_and_flanked_by_walls(self):
        stone = self.part("CR_StairRun", "Stone")
        triangles = part_triangles(stone)
        uneven = 0
        for k in range(6):
            y = -5.0 + 2.0 * k
            left, right = top_height(triangles, -4.5, y), top_height(triangles, 4.5, y)
            if left is not None and right is not None and abs(left - right) >= 0.04:
                uneven += 1
        self.assertGreaterEqual(uneven, 3, "treads must not all be perfectly level across")
        cheeks = [s for s in shells(stone) if min(abs(v[0]) for v in s) > 6.9]
        self.assertGreaterEqual(len(cheeks), 2, "a broken wall on each side")


if __name__ == "__main__":
    unittest.main()

"""Checks for the measurement helpers in biome_kit_spec, on hand-made triangles.

Run with: python -I -B -m unittest discover -s tools -p "test_biome_kit_spec.py"
"""

import unittest

import biome_kit_spec as spec

LOW, HIGH = (-1.0, -1.0, 0.0), (1.0, 1.0, 2.0)


def wall(x_low, x_high, z_high):
    """Two triangles of a thin vertical wall facing Y, from the ground up to z_high."""
    a, b = (x_low, 0.0, 0.0), (x_high, 0.0, 0.0)
    c, d = (x_high, 0.0, z_high), (x_low, 0.0, z_high)
    return [[a, b, c], [a, c, d]]


class TriangleBox(unittest.TestCase):
    def test_triangle_inside_overlaps(self):
        self.assertTrue(spec.triangle_overlaps_box([(0, 0, 0.5), (0.5, 0, 0.5), (0, 0.5, 0.5)], LOW, HIGH))

    def test_triangle_far_away_does_not(self):
        self.assertFalse(spec.triangle_overlaps_box([(5, 5, 5), (6, 5, 5), (5, 6, 5)], LOW, HIGH))

    def test_triangle_crossing_the_box_without_a_vertex_inside_overlaps(self):
        crossing = [(-3, -3, 1.0), (3, -3, 1.0), (0, 3, 1.0)]
        self.assertTrue(spec.triangle_overlaps_box(crossing, LOW, HIGH))

    def test_triangle_resting_on_the_surface_does_not_overlap(self):
        self.assertFalse(spec.triangle_overlaps_box([(-3, -3, 2.0), (3, -3, 2.0), (0, 3, 2.0)], LOW, HIGH))

    def test_slanted_triangle_missing_a_corner_does_not_overlap(self):
        # The triangle's bounding box touches the box but the plane passes outside it.
        near_miss = [(1.5, 1.5, 0.0), (1.5, 1.5, 3.0), (3.0, 3.0, 3.0)]
        self.assertFalse(spec.triangle_overlaps_box(near_miss, LOW, HIGH))


class Clearance(unittest.TestCase):
    def test_gap_between_two_legs(self):
        triangles = wall(-12.0, -8.5, 6.0) + wall(8.5, 12.0, 6.0)
        low, high = spec.clear_width(triangles, 5.0)
        self.assertEqual((low, high), (-8.5, 8.5))

    def test_a_blocker_on_the_pivot_closes_the_gap(self):
        self.assertEqual(spec.clear_width(wall(-1.0, 1.0, 3.0), 5.0), (0.0, 0.0))

    def test_height_is_the_lowest_surface_over_the_band(self):
        lintel = [[(-9.0, 0.0, 12.0), (9.0, 0.0, 12.0), (9.0, 2.0, 14.0)]]
        self.assertAlmostEqual(spec.clear_height(lintel, 8.0), 12.0, places=6)

    def test_measure_clearance_reports_width_and_height(self):
        triangles = wall(-12.0, -8.5, 6.0) + wall(8.5, 12.0, 6.0) + [[(-9, 0, 12), (9, 0, 12), (9, 2, 14)]]
        found = spec.measure_clearance(triangles, 16.0, 11.0)
        self.assertAlmostEqual(found["width"], 17.0, places=6)
        self.assertAlmostEqual(found["height"], 12.0, places=6)


class TopSurface(unittest.TestCase):
    def test_upward_triangle_gives_its_height(self):
        up = [(0, 0, 1.0), (4, 0, 1.0), (0, 4, 1.0)]
        self.assertAlmostEqual(spec.top_height([up], 1.0, 1.0), 1.0)
        self.assertIsNone(spec.top_height([up], 3.9, 3.9))

    def test_downward_triangle_is_ignored(self):
        down = [(0, 0, 1.0), (0, 4, 1.0), (4, 0, 1.0)]
        self.assertIsNone(spec.top_height([down], 1.0, 1.0))


class BoxExtent(unittest.TestCase):
    def test_pitch_swaps_the_extent(self):
        flat = spec.box_extent({"size": [4.0, 6.0, 0.6]})
        self.assertEqual(flat, (2.0, 3.0, 0.3))
        tilted = spec.box_extent({"size": [4.0, 6.0, 0.6], "pitch_deg": 30.0})
        self.assertGreater(tilted[2], flat[2])
        self.assertLess(tilted[1], 3.0 + 0.3)


if __name__ == "__main__":
    unittest.main()

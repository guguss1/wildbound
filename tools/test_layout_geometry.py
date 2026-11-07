"""Checks for the 2D helpers the biome layout plans share (tools/layout_geometry.py).

Run with: python -I -B -m unittest discover -s tools -p "test_layout_geometry.py"
"""

import math
import unittest

import layout_geometry as g


class Shapes(unittest.TestCase):
    def test_rect_poly_follows_roblox_yaw(self):
        # CFrame.Angles(0, rad(90), 0): local +Z maps to world +X, so a long-Z rect lies along X.
        rect = g.rect_poly(0.0, 0.0, 1.0, 5.0, 90.0)
        xs = [p[0] for p in rect.pts]
        zs = [p[1] for p in rect.pts]
        self.assertAlmostEqual(max(xs) - min(xs), 10.0, places=6)
        self.assertAlmostEqual(max(zs) - min(zs), 2.0, places=6)

    def test_circle_gaps(self):
        self.assertAlmostEqual(g.shape_gap(g.Circle(0, 0, 2), g.Circle(10, 0, 3)), 5.0)
        self.assertEqual(g.shape_gap(g.Circle(0, 0, 2), g.Circle(3, 0, 2)), 0.0)

    def test_rect_to_rect_gap_and_overlap(self):
        a = g.rect_poly(0, 0, 2, 2, 0)
        self.assertAlmostEqual(g.shape_gap(a, g.rect_poly(7, 0, 2, 2, 0)), 3.0)
        self.assertEqual(g.shape_gap(a, g.rect_poly(1, 1, 2, 2, 0)), 0.0)

    def test_rect_to_circle_gap(self):
        self.assertAlmostEqual(g.shape_gap(g.rect_poly(0, 0, 2, 2, 0), g.Circle(6, 0, 1)), 3.0)

    def test_shape_polyline_distance(self):
        line = [(0.0, 0.0), (10.0, 0.0)]
        self.assertAlmostEqual(g.shape_polyline_dist(g.Circle(5, 6, 1), line), 5.0)
        self.assertEqual(g.shape_polyline_dist(g.rect_poly(5, 0, 1, 1, 0), line), 0.0)


class Polylines(unittest.TestCase):
    LINE = [(0.0, 0.0), (10.0, 0.0), (10.0, 10.0)]

    def test_length_and_point_at(self):
        self.assertAlmostEqual(g.polyline_length(self.LINE), 20.0)
        point, direction, index = g.polyline_point(self.LINE, 15.0)
        self.assertAlmostEqual(point[0], 10.0)
        self.assertAlmostEqual(point[1], 5.0)
        self.assertEqual(index, 1)
        self.assertAlmostEqual(direction[1], 1.0)

    def test_projection_reports_distance_and_arc_position(self):
        distance, arc, index, lateral = g.project_to_polyline(self.LINE, (4.0, 3.0))
        self.assertAlmostEqual(distance, 3.0)
        self.assertAlmostEqual(arc, 4.0)
        self.assertEqual(index, 0)
        self.assertNotEqual(lateral, 0.0)

    def test_crossings_between_polylines(self):
        other = [(5.0, -5.0), (5.0, 5.0), (12.0, 5.0)]
        found = g.crossings(self.LINE, other)
        self.assertEqual(len(found), 2)
        points = sorted((round(c["point"][0], 6), round(c["point"][1], 6)) for c in found)
        self.assertEqual(points, [(5.0, 0.0), (10.0, 5.0)])
        self.assertAlmostEqual(found[0]["angle_deg"], 90.0, places=4)

    def test_heading_matches_the_roblox_convention(self):
        self.assertAlmostEqual(g.heading_deg(0.0, 1.0), 0.0)
        self.assertAlmostEqual(g.heading_deg(1.0, 0.0), 90.0)
        self.assertAlmostEqual(g.heading_deg(-1.0, 0.0), 270.0)


class Geometry(unittest.TestCase):
    def test_largest_centred_square_in_a_convex_polygon(self):
        octagon = [(10 * math.cos(math.tau * k / 8 + math.pi / 8), 10 * math.sin(math.tau * k / 8 + math.pi / 8))
                   for k in range(8)]
        half = g.inscribed_square_half(octagon)
        self.assertGreater(half, 9.0 * math.cos(math.pi / 8) / math.sqrt(2) * 0.97)
        self.assertLess(half, 10.0)


if __name__ == "__main__":
    unittest.main()

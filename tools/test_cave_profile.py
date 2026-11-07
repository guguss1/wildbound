"""Tests for tools/cave_profile.py, the shared Rock and Caves tunnel profile (bible 5.5, S1).

Run with: python -I -B -m unittest discover -s tools -p "test_cave_profile.py"
Standard library only. Every value is unvalidated: nothing here was imported into Roblox.
"""

import math
import random
import unittest

import cave_profile as cp


def point_segment_distance(p, a, b):
    ax, az = a
    bx, bz = b
    dx, dz = bx - ax, bz - az
    span = dx * dx + dz * dz
    t = 0.0 if span == 0 else max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - az) * dz) / span))
    return math.hypot(p[0] - (ax + t * dx), p[1] - (az + t * dz))


def inside_polygon(polygon, p):
    inside = False
    for k in range(len(polygon)):
        (x1, z1), (x2, z2) = polygon[k], polygon[(k + 1) % len(polygon)]
        if (z1 > p[1]) != (z2 > p[1]) and p[0] < x1 + (p[1] - z1) / (z2 - z1) * (x2 - x1):
            inside = not inside
    return inside


class ProfileShape(unittest.TestCase):
    def test_corners_are_the_bible_values(self):
        self.assertEqual(cp.INNER, ((-7.0, 0.0), (-7.0, 10.0), (-5.0, 12.0), (5.0, 12.0), (7.0, 10.0), (7.0, 0.0)))
        self.assertEqual(cp.OUTER, ((-12.0, 0.0), (-12.0, 12.0), (-7.0, 18.0), (7.0, 18.0), (12.0, 12.0),
                                    (12.0, 0.0)))

    def test_unrefined_loop_has_twelve_corners_and_closes_inner_then_outer(self):
        profile = cp.tunnel_profile(None, None, margin=0.0)
        self.assertEqual(len(profile.points), 12)
        self.assertEqual(profile.kinds, ["inner"] * 6 + ["outer"] * 6)
        self.assertEqual(profile.points[:6], list(cp.INNER))
        self.assertEqual(profile.points[6:], list(reversed(cp.OUTER)))

    def test_refinement_adds_only_points_on_the_original_edges(self):
        profile = cp.tunnel_profile(6.0, 8.0, margin=0.0)
        self.assertGreater(len(profile.points), 12)
        corners = [p for p, c in zip(profile.points, profile.corner) if c]
        self.assertEqual(sorted(corners), sorted(set(cp.INNER) | set(cp.OUTER)))
        loop = list(cp.INNER) + list(reversed(cp.OUTER))
        edges = [(loop[k], loop[(k + 1) % 12]) for k in range(12)]
        for point in profile.points:
            self.assertLess(min(point_segment_distance(point, a, b) for a, b in edges), 1e-9)

    def test_refinement_respects_the_step_on_each_side(self):
        profile = cp.tunnel_profile(6.0, 8.0)
        inner = [p for p, k in zip(profile.points, profile.kinds) if k == "inner"]
        outer = [p for p, k in zip(profile.points, profile.kinds) if k == "outer"]
        for chain, step in ((inner, 6.0), (outer, 8.0)):
            for a, b in zip(chain, chain[1:]):
                self.assertLessEqual(math.dist(a, b), step + 1e-9)

    def test_normals_are_unit_and_point_out_of_the_solid(self):
        profile = cp.tunnel_profile(6.0, 8.0)
        for point, normal in zip(profile.points, profile.normals):
            self.assertAlmostEqual(math.hypot(*normal), 1.0, places=9)
            if point[1] > 0.0:  # floor vertices point straight down, which a hair step cannot show
                probe = (point[0] + normal[0] * 0.05, point[1] + normal[1] * 0.05)
                self.assertFalse(inside_polygon(profile.points, probe), f"normal at {point} points into the rock")

    def test_pinned_points_are_exactly_the_ones_on_the_floor(self):
        profile = cp.tunnel_profile(6.0, 8.0)
        for point, pinned in zip(profile.points, profile.pinned):
            self.assertEqual(pinned, point[1] == 0.0)


class Relief(unittest.TestCase):
    def setUp(self):
        self.profile = cp.tunnel_profile(6.0, 8.0)

    def test_limits_keep_the_corridor_and_the_envelope(self):
        for k, point in enumerate(self.profile.points):
            low, high = self.profile.limits[k]
            kind = self.profile.kinds[k]
            if self.profile.pinned[k]:
                self.assertEqual((low, high), (0.0, 0.0))
            elif kind == "outer":
                self.assertLess(low, 0.0)
                if point[1] >= 5.9:
                    self.assertEqual(high, cp.OUTER_BULGE, "upper outer rock may swell a little past the envelope")
                else:
                    self.assertEqual(high, 0.0, "rock near the floor stays inside the footprint")
            elif point[1] >= 11.99:
                self.assertGreater(high, 0.0, "the flat ceiling may hang down")
                self.assertLessEqual(high, cp.CEILING_DROP)
            else:
                self.assertEqual(high, 0.0, "inner walls may only recess")

    def test_stations_are_deterministic_and_inside_the_limits(self):
        first = cp.relief_stations(self.profile, random.Random(7), 9, 0.7)
        second = cp.relief_stations(self.profile, random.Random(7), 9, 0.7)
        self.assertEqual(first, second)
        self.assertEqual(len(first), 9)
        self.assertTrue(all(v == 0.0 for v in first[0]) and all(v == 0.0 for v in first[-1]),
                        "end rings must stay exactly on the shared profile")
        for station in first:
            for k, value in enumerate(station):
                low, high = self.profile.limits[k]
                self.assertGreaterEqual(value, low - 1e-9)
                self.assertLessEqual(value, high + 1e-9)

    def test_upper_outer_rock_really_swells_somewhere(self):
        swell = 0.0
        for seed in range(1, 6):
            for station in cp.relief_stations(self.profile, random.Random(seed), 8, 1.0):
                swell = max([swell] + [v for v, kind in zip(station, self.profile.kinds) if kind == "outer"])
        self.assertGreaterEqual(swell, 0.3)
        self.assertLessEqual(swell, cp.OUTER_BULGE + 1e-9)

    def test_the_flat_ceiling_hangs_down_for_every_seed(self):
        ceiling = [k for k, p in enumerate(self.profile.points) if self.profile.kinds[k] == "inner" and p[1] >= 11.99]
        for seed in range(1, 12):
            stations = cp.relief_stations(self.profile, random.Random(seed), 7, 1.5)
            drop = max(station[k] for station in stations for k in ceiling)
            self.assertGreaterEqual(drop, 0.4, f"seed {seed}: the ceiling never hangs")

    def test_stations_really_vary(self):
        stations = cp.relief_stations(self.profile, random.Random(3), 9, 0.7)
        spread = max(abs(v) for s in stations for v in s)
        self.assertGreaterEqual(spread, 0.3)

    def test_displaced_ring_moves_along_the_normal_and_not_at_all_when_zero(self):
        zero = cp.displaced(self.profile, [0.0] * len(self.profile.points))
        self.assertEqual(zero, self.profile.points)
        amounts = [0.0] * len(self.profile.points)
        k = next(i for i, p in enumerate(self.profile.points) if p == (7.0 + cp.CLEAR_MARGIN, 10.0))
        amounts[k] = -0.5  # recess
        moved = cp.displaced(self.profile, amounts)
        self.assertGreater(math.dist(moved[k], (7.0 + cp.CLEAR_MARGIN, 10.0)), 0.49)
        self.assertGreater(moved[k][0], 7.0 + cp.CLEAR_MARGIN, "recessing the inner wall moves it away from the corridor")


class Extrusion(unittest.TestCase):
    def setUp(self):
        self.profile = cp.tunnel_profile(6.0, 8.0)

    def test_straight_end_rings_are_the_exact_profile_at_both_ends(self):
        rings = cp.straight_rings(self.profile, random.Random(1), 8, 24.0, 0.6)
        self.assertEqual(len(rings), 9)
        for ring, y in ((rings[0], -12.0), (rings[-1], 12.0)):
            self.assertEqual([(x, z) for x, _, z in ring], self.profile.points)
            self.assertTrue(all(v[1] == y for v in ring))

    def test_straight_interior_rings_advance_along_y(self):
        rings = cp.straight_rings(self.profile, random.Random(1), 8, 24.0, 0.6)
        ys = [sum(v[1] for v in ring) / len(ring) for ring in rings]
        self.assertEqual(ys, sorted(ys))
        self.assertTrue(all(b - a > 1.0 for a, b in zip(ys, ys[1:])))

    def test_bend_ends_sit_at_the_bible_positions(self):
        rings = cp.bend_rings(self.profile, random.Random(2), 6, 0.6)
        self.assertEqual(len(rings), 7)
        first, last = rings[0], rings[-1]
        for v in first:
            self.assertAlmostEqual(v[1], -15.0, places=9)
        for v in last:
            self.assertAlmostEqual(v[0], 15.0, places=9)
        centre_a = cp.ring_centre(first, (cp.BEND_END_A[0], cp.BEND_END_A[1]), (1.0, 0.0))
        centre_b = cp.ring_centre(last, (cp.BEND_END_B[0], cp.BEND_END_B[1]), (0.0, 1.0))
        self.assertAlmostEqual(centre_a, 0.0, places=9)
        self.assertAlmostEqual(centre_b, 0.0, places=9)

    def test_bend_end_rings_match_the_profile_in_local_coordinates(self):
        rings = cp.bend_rings(self.profile, random.Random(2), 6, 0.6)
        local_a = [(abs(v[0] - cp.BEND_END_A[0]), v[2]) for v in rings[0]]
        local_b = [(abs(v[1] - cp.BEND_END_B[1]), v[2]) for v in rings[-1]]
        def rounded(points):
            return sorted((round(a, 9), round(b, 9)) for a, b in points)

        self.assertEqual(rounded(local_a), rounded((abs(x), z) for x, z in self.profile.points))
        self.assertEqual(rounded(local_b), rounded(local_a))

    def test_bend_rings_walk_around_the_arc_centre(self):
        rings = cp.bend_rings(self.profile, random.Random(2), 6, 0.6)
        angles = [math.degrees(math.atan2(sum(v[1] for v in ring) / len(ring) - cp.BEND_CENTRE[1],
                                          sum(v[0] for v in ring) / len(ring) - cp.BEND_CENTRE[0]))
                  for ring in rings]
        self.assertAlmostEqual(angles[0], 180.0, delta=0.5)
        self.assertAlmostEqual(angles[-1], 90.0, delta=0.5)
        self.assertEqual(angles, sorted(angles, reverse=True))


class Measurements(unittest.TestCase):
    def test_ring_matches_profile_passes_for_the_profile_and_fails_for_a_moved_corner(self):
        profile = cp.tunnel_profile(6.0, 8.0, margin=0.0)
        good = cp.ring_matches_profile(profile.points, 0.02)
        self.assertTrue(good["ok"])
        self.assertEqual(good["worst_corner"], 0.0)
        moved = list(profile.points)
        k = moved.index((5.0, 12.0))
        moved[k] = (5.0, 12.1)
        bad = cp.ring_matches_profile(moved, 0.02)
        self.assertFalse(bad["ok"])
        self.assertAlmostEqual(bad["worst_corner"], 0.1, places=9)

    def test_default_margin_is_inside_the_snap_tolerance_and_opens_the_corridor(self):
        profile = cp.tunnel_profile(6.0, 8.0)
        self.assertTrue(cp.ring_matches_profile(profile.points, 0.02)["ok"])
        walls = [p for p, k in zip(profile.points, profile.kinds) if k == "inner" and abs(p[0]) > 6.0]
        self.assertTrue(walls)
        self.assertTrue(all(abs(p[0]) == 7.0 + cp.CLEAR_MARGIN for p in walls), "walls sit 0.01 outside 7.0")
        self.assertLess(cp.CLEAR_MARGIN, 0.02)

    def test_ring_matches_profile_rejects_a_stray_vertex_off_the_outline(self):
        profile = cp.tunnel_profile(6.0, 8.0)
        stray = profile.points + [(0.0, 6.0)]
        self.assertFalse(cp.ring_matches_profile(stray, 0.02)["ok"])

    def test_radial_violations_counts_vertices_in_the_forbidden_band(self):
        vertices = [(15.0 + 18.0 * math.cos(a), -15.0 + 18.0 * math.sin(a), 3.0) for a in (3.2, 2.5, 2.0)]
        found = cp.radial_violations(vertices, cp.BEND_CENTRE, 10.0, 11.0, 25.0, 0.3)
        self.assertEqual(len(found), 3)
        high = [(v[0], v[1], 10.5) for v in vertices]  # above Z 10 the ceiling may use the band
        self.assertEqual(cp.radial_violations(high, cp.BEND_CENTRE, 10.0, 11.0, 25.0, 0.3), [])
        wall = [(15.0 - 11.0, -15.0, 2.0), (15.0 + 5.0, -15.0, 2.0)]  # on the walls, tolerance spares them
        self.assertEqual(cp.radial_violations(wall, cp.BEND_CENTRE, 10.0, 11.0, 25.0, 0.3), [])

    def test_min_radial_gap_reports_the_narrowest_free_band(self):
        # Two wall slivers along one radial line: rock fills radius 8 to 11, and radius 24.8 to 28.
        triangles = [[(15.0 - 11.0, -15.0, 0.0), (15.0 - 8.0, -15.0, 0.0), (15.0 - 11.0, -15.0, 5.0)],
                     [(15.0 + 24.8, -15.0, 0.0), (15.0 + 28.0, -15.0, 0.0), (15.0 + 24.8, -15.0, 5.0)]]
        low, high = cp.free_radial_band(triangles, cp.BEND_CENTRE, 10.0)
        self.assertAlmostEqual(low, 11.0, places=6)
        self.assertAlmostEqual(high, 24.8, places=6)


if __name__ == "__main__":
    unittest.main()

"""Tests for tools/organic_shapes.py, the irregular-shape helpers shared by the W15 kits.

Run with: python -I -B -m unittest discover -s tools -p "test_organic_shapes.py"
Standard library only (kit_common is pure Python without Blender). Unvalidated, like every asset.
"""

import math
import random
import unittest
from collections import Counter

import kit_common as kc
import organic_shapes as os_

U, V = (1.0, 0.0, 0.0), (0.0, 1.0, 0.0)


def no_weight(vertex):
    return {}


def open_edges(part):
    counts = Counter()
    for face in part.faces:
        for k in range(len(face)):
            counts[tuple(sorted((face[k], face[(k + 1) % len(face)])))] += 1
    return sum(1 for n in counts.values() if n != 2)


def signed_volume(part):
    total = 0.0
    for face in part.faces:
        for k in range(1, len(face) - 1):
            a, b, c = (part.vertices[face[0]], part.vertices[face[k]], part.vertices[face[k + 1]])
            total += (a[0] * (b[1] * c[2] - b[2] * c[1]) - a[1] * (b[0] * c[2] - b[2] * c[0])
                      + a[2] * (b[0] * c[1] - b[1] * c[0])) / 6.0
    return total


def radii(points, centre=(0.0, 0.0)):
    return [math.hypot(p[0] - centre[0], p[1] - centre[1]) for p in points]


class Rings(unittest.TestCase):
    def test_plain_ring_is_a_regular_polygon(self):
        ring = os_.irregular_ring((0, 0, 0), U, V, 3.0, 3.0, 7, random.Random(1), wobble=0.0, jitter=0.0)
        self.assertEqual(len(ring), 7)
        for r in radii(ring):
            self.assertAlmostEqual(r, 3.0, places=9)

    def test_wobble_makes_the_outline_irregular_and_stays_bounded(self):
        ring = os_.irregular_ring((0, 0, 0), U, V, 3.0, 3.0, 9, random.Random(4), wobble=0.2, jitter=0.05)
        spread = max(radii(ring)) / min(radii(ring))
        self.assertGreaterEqual(spread, 1.15, "a wobbled outline must visibly differ from a circle")
        self.assertLessEqual(max(radii(ring)), 3.0 * 1.45)

    def test_ring_is_deterministic_per_seed_and_differs_between_seeds(self):
        one = os_.irregular_ring((0, 0, 0), U, V, 3.0, 2.0, 8, random.Random(9), 0.2, 0.05)
        two = os_.irregular_ring((0, 0, 0), U, V, 3.0, 2.0, 8, random.Random(9), 0.2, 0.05)
        three = os_.irregular_ring((0, 0, 0), U, V, 3.0, 2.0, 8, random.Random(10), 0.2, 0.05)
        self.assertEqual(one, two)
        self.assertNotEqual(one, three)

    def test_outline_points_are_irregular_and_ordered_around_the_centre(self):
        points = os_.outline_points(random.Random(2), 10, 5.0, 3.0, 0.2, 0.05)
        angles = [math.atan2(y, x) % math.tau for x, y in points]
        self.assertEqual(angles, sorted(angles))
        self.assertGreaterEqual(max(radii(points)) / min(radii(points)), 1.3)


class Blob(unittest.TestCase):
    def build(self, **kw):
        part = kc.Part("Rock")
        os_.rock_blob(part, random.Random(5), (0.0, 0.0, 0.0), 3.0, 2.5, 4.0, **kw)
        return part

    def test_blob_is_closed_outward_and_sits_on_its_base(self):
        part = self.build()
        self.assertEqual(open_edges(part), 0)
        self.assertGreater(abs(signed_volume(part)), 1.0, "a blob has volume")
        self.assertAlmostEqual(min(v[2] for v in part.vertices), 0.0, places=9)
        self.assertAlmostEqual(max(v[2] for v in part.vertices), 4.0, places=6)

    def test_blob_triangle_count_follows_the_ring_layout(self):
        part = self.build(rings=3, sides=7)
        # two bands of seven quads, a seven-gon base and a fan of seven to the tip
        self.assertEqual(part.triangles, 2 * 7 * 2 + 5 + 7)

    def test_blob_narrows_toward_the_top_and_leans(self):
        part = kc.Part("Rock")
        os_.rock_blob(part, random.Random(5), (0.0, 0.0, 0.0), 3.0, 2.5, 4.0, rings=4, lean=(1.2, 0.0))
        low = [v for v in part.vertices if v[2] < 0.5]
        high = [v for v in part.vertices if 2.5 < v[2] < 3.9]
        self.assertGreater(max(radii(low)), max(radii(high)))
        tip = max(part.vertices, key=lambda v: v[2])
        self.assertGreater(tip[0], 0.8, "lean must move the tip sideways")

    def test_flat_top_is_a_cap_at_exactly_the_height(self):
        part = self.build(rings=3, sides=6, flat_top=True)
        self.assertEqual(open_edges(part), 0)
        top = [v for v in part.vertices if v[2] > 3.99]
        self.assertGreaterEqual(len(top), 6)
        self.assertTrue(all(abs(v[2] - 4.0) < 1e-9 for v in top))


class Tubes(unittest.TestCase):
    def test_rough_tube_is_closed_and_tapers_to_a_tip(self):
        part = kc.Part("T")
        os_.rough_tube(part, random.Random(3), [(0, 0, 0), (0.4, 0, 2), (1.0, 0.2, 5)], [1.0, 0.7, 0.0], 6)
        self.assertEqual(open_edges(part), 0)
        tip = max(part.vertices, key=lambda v: v[2])
        self.assertEqual(tip, (1.0, 0.2, 5))
        base = [v for v in part.vertices if v[2] < 0.1]
        self.assertGreaterEqual(max(radii(base)), 0.85)

    def test_rough_tube_floor_pushes_low_vertices_up_to_the_floor(self):
        part = kc.Part("T")
        os_.rough_tube(part, random.Random(3), [(0, 0, 0.2), (0.4, 0, 2), (1.0, 0.2, 5)], [1.2, 0.7, 0.2], 6,
                       floor=0.0)
        self.assertGreaterEqual(min(v[2] for v in part.vertices), 0.0)

    def test_flutes_make_ring_radii_uneven(self):
        smooth, fluted = kc.Part("S"), kc.Part("F")
        pts, rad = [(0, 0, 0), (0, 0, 4)], [1.0, 1.0]
        os_.rough_tube(smooth, random.Random(1), pts, rad, 8, rough=0.0, flutes=0.0, phase=0.0)
        os_.rough_tube(fluted, random.Random(1), pts, rad, 8, rough=0.0, flutes=0.25, phase=0.0)
        self.assertLess(max(radii(smooth.vertices)) - min(radii(smooth.vertices)), 1e-9)
        self.assertGreater(max(radii(fluted.vertices)) - min(radii(fluted.vertices)), 0.2)


class Shards(unittest.TestCase):
    def test_shard_is_closed_points_where_told_and_leans_its_tip(self):
        part = kc.Part("S")
        os_.shard(part, random.Random(7), (0.0, 0.0, 0.0), (0.3, 0.1, 1.0), 1.0, 5.0, sides=5, bend=0.6)
        self.assertEqual(open_edges(part), 0)
        top = max(part.vertices, key=lambda v: v[2])
        self.assertGreaterEqual(math.hypot(top[0], top[1]), 0.8)
        self.assertGreaterEqual(top[2], 4.5)

    def test_shard_widest_point_is_not_at_the_base_when_swollen(self):
        part = kc.Part("S")
        os_.shard(part, random.Random(7), (0.0, 0.0, 0.0), (0.0, 0.0, 1.0), 1.0, 6.0, sides=6, belly=1.35)
        widths = {round(v[2], 3): max(radii([v2 for v2 in part.vertices if abs(v2[2] - v[2]) < 1e-6]))
                  for v in part.vertices}
        widest = max(widths, key=widths.get)
        self.assertGreater(widest, 0.5)


class Blocks(unittest.TestCase):
    def test_block_is_closed_and_corners_move_within_the_jitter(self):
        part = kc.Part("B")
        os_.jittered_block(part, random.Random(2), (0.0, 0.0, 1.0), (4.0, 3.0, 2.0), jitter=0.15)
        self.assertEqual(open_edges(part), 0)
        self.assertEqual(part.triangles, 12)
        xs = [v[0] for v in part.vertices]
        self.assertLessEqual(max(xs), 2.0 + 0.15 + 1e-9)
        self.assertGreater(len({round(x, 6) for x in xs}), 2, "corners must not all share two X values")

    def test_block_taper_narrows_the_top(self):
        part = kc.Part("B")
        os_.jittered_block(part, random.Random(2), (0.0, 0.0, 1.0), (4.0, 4.0, 2.0), jitter=0.0, taper=0.7)
        top = [v for v in part.vertices if v[2] > 1.9]
        bottom = [v for v in part.vertices if v[2] < 0.1]
        self.assertAlmostEqual(max(radii(top)) / max(radii(bottom)), 0.7, places=6)


if __name__ == "__main__":
    unittest.main()

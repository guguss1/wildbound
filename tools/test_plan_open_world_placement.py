"""Contracts for the open-world biome placement (tools/plan_open_world_layout.py, DESIGN, unvalidated).

Run from the project root (isolated mode, no bytecode written):

    python -I -B -m unittest discover -s tools -p test_plan_open_world_placement.py

Every biome layout gets one world placement around the central hub: La Silueta's forest west, the
Pradera Arcoiris east, the six offline biomes around them. The placement follows the hub centre and
radius in src/wildbound/WildboundWorldRules.luau (Rules.HUB_X, HUB_Z, HUB_RADIUS). These tests restate
the slot rules and re-derive each one from the generated placement and the committed JSON. Nothing
here was built in Studio or played.
"""

import json
import math
import re
import unittest
from pathlib import Path

import plan_open_world_layout as plan

REPO = Path(__file__).resolve().parent.parent
RULES = REPO / "src/wildbound/WildboundWorldRules.luau"
COMMITTED = REPO / "assets/maps/open-world/biome-placement-v1.json"

# ---- Spec, restated independently of the module under test ------------------------------------
TRANSITION, GAP, ROAD_W = 40.0, 40.0, 14.0
SLOTS = {"forest": "W", "pradera": "E", "living-forest": "N", "cryptic-ruins": "S",
         "demon-abyss": "NW", "frozen-mountains": "NE", "volcanic-lands": "SW", "rock-caves": "SE"}
SIZES = {"forest": 400.0, "pradera": 400.0, "living-forest": 400.0, "cryptic-ruins": 300.0,
         "demon-abyss": 300.0, "frozen-mountains": 500.0, "volcanic-lands": 400.0, "rock-caves": 300.0}
SLOT_DIRECTION = {"W": (-1, 0), "E": (1, 0), "N": (0, -1), "S": (0, 1),
                  "NW": (-1, -1), "NE": (1, -1), "SW": (-1, 1), "SE": (1, 1)}
HUBS = ((0.0, 0.0, 60.0), (0.0, 600.0, 90.0), (250.0, -40.0, 150.0))
PLACE_HUB = (282.0, -3.0, 90.0)
# Measured in the Studio place: WildboundP0's Floor part centred at (-18, -3), 400 x 400.
MEASURED = (-18.0, -3.0, 400.0)
REAL_FOREST = (-218.0, 182.0, -203.0, 197.0)   # xmin, xmax, zmin, zmax
STRIP_MARGIN = 2.0                              # beyond a road's half width
HUB_FLOOR_MARGIN = 2.0                          # hub floor radius 92 = safe radius 90 + 2 (hub-bases v1, v2-r90)


def rules_hub():
    text = RULES.read_text(encoding="utf-8")
    m = re.search(r"Rules\.HUB_X,\s*Rules\.HUB_Z,\s*Rules\.HUB_RADIUS\s*=\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+)", text)
    return float(m.group(1)), float(m.group(2)), float(m.group(3))


def rect_of(biome):
    return biome["bounds_world"]["x"] + biome["bounds_world"]["z"]   # xmin, xmax, zmin, zmax


def point_rect_distance(p, r):
    dx = max(r[0] - p[0], 0.0, p[0] - r[1])
    dz = max(r[2] - p[1], 0.0, p[1] - r[3])
    return math.hypot(dx, dz)


def point_segment_distance(p, a, b):
    ax, az = b[0] - a[0], b[1] - a[1]
    L = ax * ax + az * az
    t = 0.0 if L == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * ax + (p[1] - a[1]) * az) / L))
    return math.hypot(p[0] - a[0] - t * ax, p[1] - a[1] - t * az)


def segment_rect_distance(a, b, r):
    # Sampled: exact enough at 0.25 stud steps for a clearance contract measured in whole studs.
    n = max(2, int(math.hypot(b[0] - a[0], b[1] - a[1]) / 0.25))
    return min(point_rect_distance((a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n), r) for k in range(n + 1))


def segment_segment_distance(a, b, c, d):
    return min(point_segment_distance(a, c, d), point_segment_distance(b, c, d),
               point_segment_distance(c, a, b), point_segment_distance(d, a, b))


def rotate(x, z, deg):
    r = math.radians(deg)
    return (x * math.cos(r) + z * math.sin(r), -x * math.sin(r) + z * math.cos(r))


class RulesHub(unittest.TestCase):
    def test_reads_the_hub_from_the_world_rules(self):
        self.assertEqual(plan.read_rules_hub(), rules_hub())

    def test_parses_a_given_source(self):
        self.assertEqual(plan.read_rules_hub("Rules.HUB_X, Rules.HUB_Z, Rules.HUB_RADIUS = -12.5, 300, 140\n"),
                         (-12.5, 300.0, 140.0))

    def test_refuses_a_source_without_the_hub_line(self):
        with self.assertRaises(ValueError):
            plan.read_rules_hub("local Rules = {}")


class Rotation(unittest.TestCase):
    def test_matches_cframe_angles(self):
        # CFrame.Angles(0, r, 0): local +X -> (cos r, -sin r), local +Z -> (sin r, cos r).
        for deg in (0.0, 90.0, 180.0, 270.0, 33.0):
            for p in ((1.0, 0.0), (0.0, 1.0), (-7.0, 3.0)):
                got = plan.rotate_yaw(p[0], p[1], deg)
                want = rotate(p[0], p[1], deg)
                self.assertAlmostEqual(got[0], want[0], places=9)
                self.assertAlmostEqual(got[1], want[1], places=9)


class Placement(unittest.TestCase):
    def setUp(self):
        self.by_hub = {hub: plan.generate_placement(hub) for hub in HUBS}

    def test_every_biome_has_its_slot_and_size(self):
        for placement in self.by_hub.values():
            self.assertEqual(set(placement["biomes"]), set(SLOTS))
            for key, biome in placement["biomes"].items():
                self.assertEqual(biome["slot"], SLOTS[key], key)
                self.assertEqual(biome["map_size"], SIZES[key], key)
                xmin, xmax, zmin, zmax = rect_of(biome)
                self.assertAlmostEqual(xmax - xmin, SIZES[key])
                self.assertAlmostEqual(zmax - zmin, SIZES[key])

    def test_reproduces_the_open_world_offsets_at_the_original_hub(self):
        biomes = self.by_hub[(0.0, 0.0, 60.0)]["biomes"]
        self.assertEqual(biomes["forest"]["local_centre"], [-300.0, 0.0])
        self.assertEqual(biomes["pradera"]["local_centre"], [300.0, 0.0])
        self.assertEqual(tuple(biomes["forest"]["local_centre"]), plan.FOREST_OFFSET)
        self.assertEqual(tuple(biomes["pradera"]["local_centre"]), plan.PRADERA_OFFSET)
        self.assertEqual(biomes["forest"]["yaw_deg"], 0.0)
        self.assertEqual(biomes["pradera"]["yaw_deg"], 0.0)

    def test_sits_in_its_compass_slot_around_the_hub(self):
        for (hx, hz, _), placement in self.by_hub.items():
            for key, biome in placement["biomes"].items():
                cx, cz = biome["world_centre"]
                sx, sz = SLOT_DIRECTION[SLOTS[key]]
                for sign, value in ((sx, cx - hx), (sz, cz - hz)):
                    if sign == 0:
                        self.assertAlmostEqual(value, 0.0, msg=key)
                    else:
                        self.assertGreater(sign * value, 0.0, key)

    def test_no_two_biomes_overlap_and_gaps_hold(self):
        for placement in self.by_hub.values():
            items = list(placement["biomes"].items())
            for i, (ka, a) in enumerate(items):
                for kb, b in items[i + 1:]:
                    ra, rb = rect_of(a), rect_of(b)
                    gap = max(rb[0] - ra[1], ra[0] - rb[1], rb[2] - ra[3], ra[2] - rb[3])
                    self.assertGreaterEqual(gap, GAP - 1e-6, (ka, kb))

    def test_every_biome_keeps_the_transition_from_the_hub_disc(self):
        for (hx, hz, radius), placement in self.by_hub.items():
            for key, biome in placement["biomes"].items():
                d = point_rect_distance((hx, hz), rect_of(biome))
                self.assertGreaterEqual(d, radius + TRANSITION - 1e-6, key)
                if SLOTS[key] in ("W", "E"):
                    self.assertAlmostEqual(d, radius + TRANSITION, places=6, msg=key)

    def test_follows_the_hub_centre_and_radius(self):
        base = plan.generate_placement((0.0, 0.0, 60.0))["biomes"]
        moved = plan.generate_placement((25.0, 600.0, 60.0))["biomes"]
        grown = plan.generate_placement((0.0, 0.0, 90.0))["biomes"]
        for key in SLOTS:
            self.assertEqual(moved[key]["local_centre"], base[key]["local_centre"], key)
            self.assertAlmostEqual(moved[key]["world_centre"][0], base[key]["world_centre"][0] + 25.0)
            self.assertAlmostEqual(moved[key]["world_centre"][1], base[key]["world_centre"][1] + 600.0)
        self.assertAlmostEqual(grown["forest"]["local_centre"][0], -330.0)
        self.assertAlmostEqual(grown["pradera"]["local_centre"][0], 330.0)

    def test_the_entry_gate_faces_the_hub(self):
        for (hx, hz, _), placement in self.by_hub.items():
            for key, biome in placement["biomes"].items():
                cx, cz = biome["world_centre"]
                lx, lz = biome["gate_local"]
                wx, wz = rotate(lx, lz, biome["yaw_deg"])
                self.assertAlmostEqual(biome["gate_world"][0], cx + wx, places=3, msg=key)
                self.assertAlmostEqual(biome["gate_world"][1], cz + wz, places=3, msg=key)
                nx, nz = biome["gate_normal"]
                self.assertGreater(nx * (hx - cx) + nz * (hz - cz), 0.0, key)
                half = biome["map_size"] / 2
                # The gate (the biome route's first node) stands within 30 studs of the edge it faces.
                depth = half - (wx * nx + wz * nz)
                self.assertGreaterEqual(depth, -1e-6, key)
                self.assertLessEqual(depth, 30.0, key)

    def test_yaw_is_a_quarter_turn(self):
        for placement in self.by_hub.values():
            for key, biome in placement["biomes"].items():
                self.assertIn(biome["yaw_deg"], (0.0, 90.0, 180.0, 270.0), key)


class Roads(unittest.TestCase):
    def setUp(self):
        self.by_hub = {hub: plan.generate_placement(hub) for hub in HUBS}

    def test_one_road_per_biome_from_the_rim_to_the_gate(self):
        for (hx, hz, radius), placement in self.by_hub.items():
            self.assertEqual(set(placement["roads"]), set(SLOTS))
            for key, road in placement["roads"].items():
                nodes = road["nodes_world"]
                self.assertAlmostEqual(math.hypot(nodes[0][0] - hx, nodes[0][1] - hz), radius, places=2, msg=key)
                self.assertEqual(nodes[-1], placement["biomes"][key]["gate_world"], key)
                self.assertEqual(road["width"], ROAD_W)
                length = sum(math.dist(a, b) for a, b in zip(nodes, nodes[1:]))
                self.assertAlmostEqual(road["length"], length, places=2, msg=key)

    def test_roads_stay_clear_of_every_other_biome_and_out_of_the_hub(self):
        for (hx, hz, radius), placement in self.by_hub.items():
            for key, road in placement["roads"].items():
                nodes = road["nodes_world"]
                for a, b in zip(nodes, nodes[1:]):
                    for other, biome in placement["biomes"].items():
                        if other == key:
                            continue
                        self.assertGreaterEqual(segment_rect_distance(a, b, rect_of(biome)), ROAD_W / 2 + 5.0, (key, other))
                    self.assertGreaterEqual(point_segment_distance((hx, hz), a, b), radius - 0.01, key)
                # Only the last leg enters the road's own biome.
                own = rect_of(placement["biomes"][key])
                for a, b in zip(nodes[:-2], nodes[1:-1]):
                    self.assertGreaterEqual(segment_rect_distance(a, b, own), ROAD_W / 2 - 1e-6, key)

    def test_roads_meet_only_at_shared_junctions(self):
        # Past each road's first 30 studs (every road leaves the same rim), two roads closer than a road width
        # must be next to a node they share: a junction, never two parallel or crossing roads.
        for placement in self.by_hub.values():
            items = list(placement["roads"].items())
            for i, (ka, ra) in enumerate(items):
                for kb, rb in items[i + 1:]:
                    sa, sb = trimmed(ra["nodes_world"], 30.0), trimmed(rb["nodes_world"], 30.0)
                    for a, b in zip(sa, sa[1:]):
                        for c, d in zip(sb, sb[1:]):
                            if segment_segment_distance(a, b, c, d) >= ROAD_W:
                                continue
                            junctions = [n for n in {tuple(n) for n in ra["nodes_world"]} & {tuple(n) for n in rb["nodes_world"]}
                                         if point_segment_distance(n, a, b) < ROAD_W and point_segment_distance(n, c, d) < ROAD_W]
                            self.assertTrue(junctions, (ka, kb, a, b, c, d))
            # A shared junction is never inside a biome.
            for key, road in placement["roads"].items():
                for node in road["nodes_world"][1:-1]:
                    for other, biome in placement["biomes"].items():
                        self.assertGreater(point_rect_distance(node, rect_of(biome)), 0.0, (key, other, node))


def trimmed(nodes, skip):
    a, b = nodes[0], nodes[1]
    L = math.dist(a, b)
    t = min(skip / L, 0.99)
    return [(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)] + [tuple(n) for n in nodes[1:]]


class MeasuredForest(unittest.TestCase):
    """The forest map WildboundP0 as measured in the Studio place: its Floor part is centred at (-18, -3), 400 x 400,
    so the real forest square is x -218..182, z -203..197, not the placement's west slot (centre (-48, -3))."""

    @classmethod
    def setUpClass(cls):
        cls.slot = plan.generate_placement(PLACE_HUB)
        cls.placement = plan.generate_placement(PLACE_HUB, forest=MEASURED)

    def test_the_planner_records_the_measured_forest(self):
        self.assertEqual(tuple(plan.MEASURED_FOREST[:3]), MEASURED)
        self.assertIn("Studio", plan.MEASURED_FOREST_SOURCE)
        forest = self.placement["biomes"]["forest"]
        self.assertEqual(forest["world_centre"], [-18.0, -3.0])
        self.assertEqual(forest["bounds_world"], {"x": [-218.0, 182.0], "z": [-203.0, 197.0]})
        self.assertEqual(forest["slot_world_centre"], [-48.0, -3.0])
        self.assertEqual(forest["gate_world"], [182.0, 17.0], "the threshold road's crossing of the real east edge")
        self.assertIn("Studio", forest["measured"]["source"])

    def test_every_other_biome_square_stays_and_clears_the_real_forest_by_the_gap(self):
        for key, biome in self.placement["biomes"].items():
            if key == "forest":
                continue
            self.assertEqual(biome, self.slot["biomes"][key], key)
            ra, rb = rect_of(biome), REAL_FOREST
            gap = max(rb[0] - ra[1], ra[0] - rb[1], rb[2] - ra[3], ra[2] - rb[3])
            self.assertGreaterEqual(gap, GAP - 1e-6, key)

    def test_refuses_a_measured_forest_that_crowds_a_biome_square(self):
        with self.assertRaises(ValueError):
            plan.generate_placement(PLACE_HUB, forest=(-18.0, 20.0, 400.0))

    def test_no_road_strip_touches_the_real_forest(self):
        for key, road in self.placement["roads"].items():
            nodes = road["nodes_world"]
            for a, b in zip(nodes, nodes[1:]):
                self.assertGreaterEqual(segment_rect_distance(a, b, REAL_FOREST), ROAD_W / 2 + STRIP_MARGIN - 1e-6,
                                        (key, a, b))

    def test_the_forest_join_is_the_hub_w_trail_so_no_open_world_road_runs_there(self):
        self.assertNotIn("forest", self.placement["roads"])
        self.assertIn("W gate trail", self.placement["biomes"]["forest"]["entry_road"])
        hx, hz = PLACE_HUB[:2]
        gate = self.placement["biomes"]["forest"]["gate_world"]
        for name in ("hub-bases-v1.json", "hub-bases-v2-r90.json"):
            hub = json.loads((REPO / "assets/maps/hub-layout" / name).read_text(encoding="utf-8"))
            trail = next(e["trail"] for e in hub["entrances"] if e["id"] == "W")
            self.assertEqual([hx + trail["to"][0], hz + trail["to"][1]], gate, name)
            self.assertLessEqual(math.hypot(*trail["from"]), PLACE_HUB[2], name)   # it leaves from the W gate itself

    def test_no_road_strip_overlaps_another_biome_square(self):
        for key, road in self.placement["roads"].items():
            nodes = road["nodes_world"]
            for a, b in zip(nodes, nodes[1:]):
                for other, biome in self.placement["biomes"].items():
                    if other != key:
                        self.assertGreaterEqual(segment_rect_distance(a, b, rect_of(biome)),
                                                ROAD_W / 2 + STRIP_MARGIN - 1e-6, (key, other, a, b))
            own = rect_of(self.placement["biomes"][key])
            for a, b in zip(nodes[:-2], nodes[1:-1]):
                self.assertGreaterEqual(segment_rect_distance(a, b, own), ROAD_W / 2 + STRIP_MARGIN - 1e-6, key)

    def test_roads_stay_off_the_hub_floor_past_their_rim_node(self):
        for (hx, hz, radius), placement in [(PLACE_HUB, self.placement)] + [(h, plan.generate_placement(h)) for h in HUBS]:
            floor = radius + HUB_FLOOR_MARGIN
            for key, road in placement["roads"].items():
                nodes = road["nodes_world"]
                self.assertAlmostEqual(math.hypot(nodes[0][0] - hx, nodes[0][1] - hz), radius, places=2, msg=key)
                # The first leg runs straight out: its nearest point to the hub is its rim node.
                self.assertAlmostEqual(point_segment_distance((hx, hz), nodes[0], nodes[1]), radius, places=2, msg=key)
                for a, b in zip(nodes[1:], nodes[2:]):
                    self.assertGreaterEqual(point_segment_distance((hx, hz), a, b), floor + ROAD_W / 2, (key, a, b))
                self.assertGreaterEqual(math.hypot(nodes[1][0] - hx, nodes[1][1] - hz), floor + ROAD_W / 2, key)

    def test_the_cli_defaults_to_the_measured_forest(self):
        import contextlib
        import io
        import tempfile
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
            plan.main(["--placement-only", "--hub", "282", "-3", "90", "--out-dir", tmp])
            written = json.loads((Path(tmp) / "biome-placement-v1.json").read_text(encoding="utf-8"))
        self.assertEqual(written, json.loads(plan.placement_json(self.placement)))


class Committed(unittest.TestCase):
    def test_committed_json_is_fresh_for_the_rules_hub(self):
        committed = json.loads(COMMITTED.read_text(encoding="utf-8"))
        self.assertEqual(committed, json.loads(plan.placement_json(plan.generate_placement(rules_hub(), forest=MEASURED))))

    def test_committed_json_records_the_hub_it_was_made_for(self):
        committed = json.loads(COMMITTED.read_text(encoding="utf-8"))
        hx, hz, radius = rules_hub()
        self.assertEqual(committed["hub"]["centre"], [hx, hz])
        self.assertEqual(committed["hub"]["radius"], radius)
        self.assertIn("WildboundWorldRules.luau", committed["hub"]["source"])


if __name__ == "__main__":
    unittest.main()

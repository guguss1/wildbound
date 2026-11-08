"""Contracts for the creature islands layout (docs/mechanics/wildbound-expedition-islands.md section 2, task I1).

    python -I -B -m unittest discover -s tools -p test_plan_islands.py

The rules are restated here and re-derived from the saved JSON, the forest layout, the hide spots and the relief,
not from the planner's report. The Luau layout module is generated from the same JSON (tools/plan_islands.py).
"""

import json
import math
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SAVED = REPO / "assets/maps/forest-layout/islands-v1.json"
LUAU = REPO / "src/wildbound/WildboundIslandLayout.luau"
LAYOUT = REPO / "assets/maps/forest-layout/forest-layout-v1.json"
HIDE = REPO / "assets/maps/forest-layout/hide-spots-v1.json"
RELIEF = REPO / "assets/maps/forest-layout/relief-v1.json"

SPAWN = (-140.0, 150.0)
CAMP, CLEARING = (-140.0, 140.0), (-95.0, 75.0)
HOME, LEASH = (0.0, -85.0), 80.0
FOG = (-45.0, 165.0, -165.0, 35.0)
CORE = {"FK_Evergreen": 2.5 * 1.6, "FK_DeadTree": 3.4 * 1.4}  # core radius per unit scale, grown (DP6)
TRIANGLE_BUDGET = 95000
EXPECTED_ZONES = {"I1": "outside", "I2": "fog", "I3": "fog", "I4": "territory", "I5": "territory"}
TIER_ORDER = ["Safe", "Fog", "FogFar", "Territory", "Heart"]


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def zone(x, z):
    x0, x1, z0, z1 = FOG
    if not (x0 <= x <= x1 and z0 <= z <= z1):
        return "outside"
    return "territory" if math.dist((x, z), HOME) <= LEASH else "fog"


def cores(layout, removed):
    found = []
    for item in layout["instances"]:
        if item["name"] in CORE and item["id"] not in removed:
            found.append((item["id"], item["x"], item["z"], CORE[item["name"]] * item["scale"]))
    return found


def segment_point_distance(ax, az, bx, bz, px, pz):
    dx, dz = bx - ax, bz - az
    length2 = dx * dx + dz * dz
    t = 0.0 if length2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / length2))
    return math.dist((ax + t * dx, az + t * dz), (px, pz))


class IslandLayoutTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = load(SAVED)
        cls.islands = cls.data["islands"]
        cls.layout = load(LAYOUT)
        # Trees the relief already took (RW-3) are gone from the live map too.
        cls.removed = set(cls.data["removedTrees"]) | set(load(RELIEF)["removedTrees"])

    def test_five_islands_in_tier_order(self):
        self.assertEqual([i["id"] for i in self.islands], ["I1", "I2", "I3", "I4", "I5"])
        self.assertEqual([i["rewardTier"] for i in self.islands], TIER_ORDER)
        self.assertEqual([i["species"] for i in self.islands],
                         ["Lumipol", "Cortezon", "Cestillo", "Polvilla", "Tizoncillo"])
        self.assertEqual([i["adults"] for i in self.islands], [2, 2, 3, 3, 4])
        radii = [i["wakeRadius"]["day"] for i in self.islands]
        self.assertEqual(radii, sorted(radii))
        for island in self.islands:
            self.assertEqual(len(island["adultPoints"]), island["adults"])
            self.assertAlmostEqual(island["wakeRadius"]["night"], island["wakeRadius"]["day"] * 1.25)

    def test_island_one_within_100_studs_of_spawn_along_the_route(self):
        first = self.islands[0]
        along = math.dist(SPAWN, CAMP) + math.dist(CAMP, CLEARING) + math.dist(CLEARING, tuple(first["centre"]))
        self.assertLessEqual(along, 100.0)

    def test_zones_match_world_rules(self):
        for island in self.islands:
            x, z = island["centre"]
            self.assertEqual(zone(x, z), EXPECTED_ZONES[island["id"]], island["id"])
            self.assertEqual(island["zone"], EXPECTED_ZONES[island["id"]])
        self.assertEqual([i["tier"] for i in self.islands], ["Safe", "Fog", "Fog", "Territory", "Territory"])

    def test_floors_clear_of_trunk_cores_and_flat(self):
        relief = load(RELIEF)["segments"]
        for island in self.islands:
            cx, cz = island["centre"]
            radius = island["floorRadius"]
            self.assertTrue(14 <= radius <= 18, island["id"])
            for tree_id, x, z, core in cores(self.layout, self.removed):
                self.assertGreaterEqual(math.dist((x, z), (cx, cz)) - core, radius, f"{island['id']} {tree_id}")
            for segment in relief:
                (ax, az), (bx, bz) = segment["a"], segment["b"]
                run = segment["height"] / math.tan(math.radians(segment["slopeDeg"]))
                reach = segment["crestWidth"] / 2 + run
                self.assertGreaterEqual(segment_point_distance(ax, az, bx, bz, cx, cz) - reach, radius,
                                        f"{island['id']} {segment['id']}")
            for point in island["adultPoints"] + [island["nest"]]:
                self.assertLessEqual(math.dist((point["x"], point["z"]), (cx, cz)), radius - 4)

    def test_hide_spot_within_25_to_45_of_each_island_past_the_first(self):
        spots = load(HIDE)["spots"]
        for island in self.islands[1:]:
            near = [s for s in spots if 25 <= math.dist((s["x"], s["z"]), tuple(island["centre"])) <= 45]
            self.assertTrue(near, island["id"])
            self.assertIn(island["hideSpot"], [s["id"] for s in near])

    def test_show_crest_in_territory_and_45_to_60_from_island_2(self):
        crest = self.data["showCrest"]
        self.assertEqual(zone(crest["x"], crest["z"]), "territory")
        distance = math.dist((crest["x"], crest["z"]), tuple(self.islands[1]["centre"]))
        self.assertTrue(45 <= distance <= 60, distance)
        segment = next(s for s in load(RELIEF)["segments"] if s["id"] == crest["segment"])
        self.assertEqual(segment["feature"], "cresta-vigia")

    def test_show_crest_sight_corridor_has_no_trunk(self):
        crest = self.data["showCrest"]
        cx, cz = self.islands[1]["centre"]
        for tree_id, x, z, core in cores(self.layout, self.removed):
            self.assertGreater(segment_point_distance(crest["x"], crest["z"], cx, cz, x, z), core, tree_id)

    def test_removed_trees_listed_and_layout_under_95000_triangles(self):
        ids = {item["id"] for item in self.layout["instances"]}
        self.assertTrue(set(self.data["removedTrees"]) <= ids)
        props = self.layout["inputs"]["props"]
        relief_removed = set(load(RELIEF)["removedTrees"])
        kept = [i for i in self.layout["instances"] if i["id"] not in self.removed and i["id"] not in relief_removed]
        self.assertLess(sum(props[i["name"]]["tris"] for i in kept), TRIANGLE_BUDGET)

    def test_luau_layout_matches_json(self):
        text = LUAU.read_text(encoding="utf-8")
        for island in self.islands:
            self.assertIn(f'id = "{island["id"]}"', text)
            self.assertIn(f'species = "{island["species"]}"', text)
        self.assertIn("generated by tools/plan_islands.py", text)


if __name__ == "__main__":
    unittest.main()

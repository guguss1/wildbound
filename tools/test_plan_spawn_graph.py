"""Contracts for the random-world spawn graph (plan Part 3, task RW1).

    python -I -B -m unittest discover -s tools -p test_plan_spawn_graph.py

The rules are restated here and re-derived from the saved JSON, the forest layout, the islands and the relief, not
from the planner's report. The Luau module is generated from the same JSON (tools/plan_spawn_graph.py --write).
"""

import json
import math
import re
import sys
import unittest
from pathlib import Path

_HERE = str(Path(__file__).resolve().parent)
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

REPO = Path(__file__).resolve().parent.parent
SAVED = REPO / "assets/maps/forest-layout/spawn-graph-v1.json"
LUAU = REPO / "src/wildbound/WildboundSpawnGraph.luau"
LAYOUT = REPO / "assets/maps/forest-layout/forest-layout-v1.json"
ISLANDS = REPO / "assets/maps/forest-layout/islands-v1.json"
RELIEF = REPO / "assets/maps/forest-layout/relief-v1.json"

HOME, LEASH = (0.0, -85.0), 80.0
FOG = (-45.0, 165.0, -165.0, 35.0)
SAFE = (((-140.0, 140.0), 35.0), ((105.0, 125.0), 22.0))
CORE = {"FK_Evergreen": 2.5 * 1.6, "FK_DeadTree": 3.4 * 1.4}
KINDS = {"treeBase", "canopy", "root", "log", "rock", "nest", "trail"}
TIERS = ("Comun", "Rara", "Epica", "Legendaria")
MINIMUM = {"Comun": 30, "Rara": 15, "Epica": 10, "Legendaria": 6}


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def zone(x, z):
    x0, x1, z0, z1 = FOG
    if not (x0 <= x <= x1 and z0 <= z <= z1):
        return "outside"
    return "territory" if math.dist((x, z), HOME) <= LEASH else "fog"


def tier(distance):
    if distance < 45:
        return "Legendaria"
    if distance < 80:
        return "Epica"
    if distance <= 120:
        return "Rara"
    return "Comun"


class SpawnGraphTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.graph = load(SAVED) if SAVED.is_file() else None

    def setUp(self):
        self.assertIsNotNone(self.graph, f"{SAVED} missing: run tools/plan_spawn_graph.py --write")

    def test_saved_json_is_what_the_planner_makes(self):
        import plan_spawn_graph as planner
        self.assertEqual(planner.plan(load(LAYOUT), load(ISLANDS), load(RELIEF)), self.graph)

    def test_every_point_carries_distance_zone_tier_and_height(self):
        for p in self.graph["points"]:
            d = math.dist((p["x"], p["z"]), HOME)
            self.assertAlmostEqual(p["distanceToHome"], round(d, 2), places=2, msg=p["id"])
            self.assertEqual(p["zone"], zone(p["x"], p["z"]), p["id"])
            self.assertEqual(p["tier"], tier(d), p["id"])
            self.assertIn(p["kind"], KINDS, p["id"])
            self.assertGreaterEqual(p["ground"], 0.5, p["id"])
            if p["kind"] == "canopy":
                self.assertGreater(p["height"], 0, p["id"])
            else:
                self.assertEqual(p["height"], 0, p["id"])

    def test_no_point_inside_camp_or_shelter(self):
        for p in self.graph["points"]:
            for centre, radius in SAFE:
                self.assertGreater(math.dist((p["x"], p["z"]), centre), radius, p["id"])

    def test_wild_points_stay_off_island_floors_and_out_of_trunks(self):
        layout, islands = load(LAYOUT), load(ISLANDS)
        removed = set(islands["removedTrees"]) | set(load(RELIEF)["removedTrees"])
        trees = [(i["x"], i["z"], CORE[i["name"]] * i["scale"]) for i in layout["instances"]
                 if i["name"] in CORE and i["id"] not in removed]
        for p in self.graph["points"]:
            if p["kind"] == "nest":
                continue
            for island in islands["islands"]:
                cx, cz = island["centre"]
                self.assertGreater(math.dist((p["x"], p["z"]), (cx, cz)), island["floorRadius"], p["id"])
            if p["kind"] != "canopy":
                for x, z, core in trees:
                    self.assertGreaterEqual(math.dist((p["x"], p["z"]), (x, z)) - core, 1.0, p["id"])

    def test_every_kind_and_every_tier_is_present(self):
        kinds = {p["kind"] for p in self.graph["points"]}
        self.assertEqual(kinds, KINDS)
        for name in TIERS:
            count = sum(1 for p in self.graph["points"] if p["tier"] == name and p["kind"] != "nest")
            self.assertGreaterEqual(count, MINIMUM[name], name)

    def test_island_nests_are_guaranteed_points(self):
        nests = [p for p in self.graph["points"] if p["kind"] == "nest"]
        islands = load(ISLANDS)["islands"]
        self.assertEqual(sorted(p["island"] for p in nests), sorted(i["id"] for i in islands))
        for p in nests:
            island = next(i for i in islands if i["id"] == p["island"])
            self.assertEqual((p["x"], p["z"]), tuple(island["centre"]))
            self.assertTrue(p["guaranteed"])
        self.assertFalse(any(p.get("guaranteed") for p in self.graph["points"] if p["kind"] != "nest"))

    def test_ids_are_unique(self):
        ids = [p["id"] for p in self.graph["points"]]
        self.assertEqual(len(ids), len(set(ids)))

    def test_refuge_candidates_are_outside_the_territory_and_spread(self):
        candidates = self.graph["refugeCandidates"]
        self.assertGreaterEqual(len(candidates), 6)
        for c in candidates:
            self.assertGreaterEqual(math.dist((c["x"], c["z"]), HOME), LEASH + 15, c["id"])
            for centre, radius in SAFE:
                self.assertGreater(math.dist((c["x"], c["z"]), centre), radius + 10, c["id"])
        for i, a in enumerate(candidates):
            for b in candidates[i + 1:]:
                self.assertGreaterEqual(math.dist((a["x"], a["z"]), (b["x"], b["z"])), 35, (a["id"], b["id"]))

    def test_luau_module_is_generated_from_the_json(self):
        import plan_spawn_graph as planner
        text = LUAU.read_text(encoding="utf-8")
        self.assertEqual(text, planner.luau(self.graph))
        self.assertIn("do not edit", text.splitlines()[0])
        self.assertEqual(len(re.findall(r'^\tp\("', text, re.M)), len(self.graph["points"]))
        self.assertEqual(len(re.findall(r'^\tr\("', text, re.M)), len(self.graph["refugeCandidates"]))


if __name__ == "__main__":
    unittest.main()

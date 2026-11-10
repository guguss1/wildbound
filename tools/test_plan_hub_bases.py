"""Contracts for the hub-with-personal-bases plan (tools/plan_hub_bases.py; DESIGN, unvalidated).

Run from the project root (isolated mode, no bytecode written):

    python -I -B -m unittest discover -s tools -p test_plan_hub_bases.py

The spec numbers are restated here on purpose: the tests re-derive each rule from the saved JSON (and from
layout-v1.json for the open world) instead of trusting the generator. Rules: eight bases that never overlap each
other, the lobby, the gate paths or the hedge; every station inside its base; every base and every entrance reachable
on foot from a spawn pad; at least three entrances to the forest; the safe zone covers every base; nothing inside any
beast's reach. Nothing here was built in Studio, played or measured on a device.
"""

import json
import math
import unittest
from collections import deque
from pathlib import Path

import layout_geometry as g
import plan_forest_layout as forest
import plan_hub_bases as plan
import plan_pradera_layout as pradera

REPO = Path(__file__).resolve().parent.parent
OPEN_WORLD = REPO / "assets/maps/open-world/layout-v1.json"
FOREST_JSON = REPO / "assets/maps/forest-layout/forest-layout-v1.json"
PRADERA_JSON = REPO / "assets/maps/pradera-layout/pradera-layout-v1.json"
COMMITTED = REPO / "assets/maps/hub-layout/hub-bases-v1.json"

# ---- Spec, restated -----------------------------------------------------------------------------------------------
SLOTS = 8
SAFE_R, WALL_R, WALL_THICK, FLOOR_R, PLAZA_R = 90.0, 88.0, 2.0, 92.0, 30.0
PROMENADE = (46.0, 54.0)
GATE_W, PATH_W = 16.0, 12.0
MIN_ENTRANCES, MIN_FOREST_ENTRANCES, MIN_GATE_SPACING = 3, 3, 40.0
STATION_KINDS = {"delivery": "WildboundDeliveryStation", "incubator": "WildboundIncubatorStation",
                 "display": "WildboundCollectionDisplay", "glove": "WildboundGloveStation",
                 "training": "WildboundTrainingStation"}
STATION_MARGIN, STATION_GAP, BASE_PATH_CLEAR, BASE_GAP = 1.0, 2.0, 2.0, 2.0
REGION_EDGE_X = 100.0          # forest square starts at x -100, Pradera square at x 100 (layout-v1)
BEAST_MARGIN = 10.0
FOREST_OFFSET = (-300.0, 0.0)
FOREST_CLEAR, HOOK_CLEAR = 10.0, 20.0
CLEARANCE, GRID, REACH = 0.8, 0.5, 3.0   # character half width, BFS cell, interaction reach for a station
LIGHTS_CAP = 20


def circle_at(centre, r):
    return g.Circle(centre[0], centre[1], r)


def shape(entry_centre, fp):
    if fp["kind"] == "circle":
        return g.Circle(entry_centre[0], entry_centre[1], fp["r"])
    return g.rect_poly(entry_centre[0], entry_centre[1], fp["half"][0], fp["half"][1], fp.get("yaw", 0.0))


def seg_poly(seg):
    return g.rect_poly(seg["centre"][0], seg["centre"][1], seg["width"] / 2, seg["length"] / 2, seg["yaw"])


def local_to_world(centre, yaw, local):
    a = math.radians(yaw)
    return (centre[0] + local[0] * math.cos(a) + local[1] * math.sin(a),
            centre[1] - local[0] * math.sin(a) + local[1] * math.cos(a))


def far_radius(s):
    if isinstance(s, g.Circle):
        return math.hypot(s.x, s.z) + s.r
    return max(math.hypot(p[0], p[1]) for p in s.pts)


def near_radius(s):
    if isinstance(s, g.Circle):
        return math.hypot(s.x, s.z) - s.r
    return g.shape_point_dist(s, (0.0, 0.0))


class Plan(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ow = json.loads(OPEN_WORLD.read_text(encoding="utf-8"))
        cls.layout = json.loads(plan.to_json(plan.generate(cls.ow)))
        cls.bases = cls.layout["bases"]

    # -- helpers --
    def base_shape(self, base):
        return shape(base["centre"], base["bounds"])

    def station_shapes(self, base):
        return [(s["kind"], shape(s["world"], s["footprint"])) for s in base["stations"]]

    def fence_shapes(self, base):
        return [g.rect_poly(f["world"][0], f["world"][1], f["half"][0], f["half"][1], f["yaw"]) for f in base["fences"]]

    def hedge_shapes(self):
        return [g.rect_poly(h["centre"][0], h["centre"][1], h["length"] / 2, WALL_THICK / 2, h["yaw"])
                for h in self.layout["hedge"]]

    # -- schema and frame --
    def test_schema_and_frame_match_the_open_world(self):
        lay = self.layout
        for key in ("name", "status", "seed", "conventions", "hub", "lobby", "bases", "entrances", "hedge",
                    "safe_zones", "decorations", "lights", "removed_forest_props", "budget"):
            self.assertIn(key, lay)
        self.assertEqual(lay["name"], "hub-bases-v1")
        self.assertIn("unvalidated", lay["status"])
        self.assertEqual(lay["hub"]["centre"], self.ow["hub"]["centre"])
        self.assertEqual(lay["hub"]["centre"], [0.0, 0.0])
        self.assertEqual(lay["hub"]["safe_radius"], SAFE_R)
        self.assertEqual(lay["supersedes"]["layout_v1_hub_radius"], self.ow["hub"]["safe_radius"])
        self.assertFalse(lay["hub"]["pvp"])
        self.assertFalse(lay["hub"]["beasts"])

    def test_eight_recognisable_bases(self):
        self.assertEqual([b["slot"] for b in self.bases], list(range(1, SLOTS + 1)))
        names = [b["colour"]["name"] for b in self.bases]
        hexes = [b["colour"]["hex"] for b in self.bases]
        self.assertEqual(len(set(names)), SLOTS)
        self.assertEqual(len(set(hexes)), SLOTS)
        rgb = [tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) for h in hexes]
        for i in range(SLOTS):
            for j in range(i + 1, SLOTS):
                self.assertGreaterEqual(math.dist(rgb[i], rgb[j]), 60.0, (names[i], names[j]))
        for b in self.bases:
            self.assertEqual(b["sign"]["text"], "Base de <jugador>")
            self.assertEqual(b["sign"]["key"], "base%d" % b["slot"])
            self.assertEqual(sorted(s["kind"] for s in b["stations"]), sorted(STATION_KINDS))
            for s in b["stations"]:
                self.assertEqual(s["tag"], STATION_KINDS[s["kind"]])
                self.assertTrue(s["label"])

    def test_every_base_faces_the_lobby(self):
        for b in self.bases:
            a = math.radians(b["yaw"])
            front = (-math.sin(a), -math.cos(a))           # local -Z in (x, z)
            to_centre = (-b["centre"][0], -b["centre"][1])
            n = math.hypot(*to_centre)
            self.assertAlmostEqual((front[0] * to_centre[0] + front[1] * to_centre[1]) / n, 1.0, places=6)

    # -- no overlaps --
    def test_bases_never_overlap_each_other_the_lobby_paths_or_the_hedge(self):
        shapes = [self.base_shape(b) for b in self.bases]
        for i in range(SLOTS):
            for j in range(i + 1, SLOTS):
                self.assertGreaterEqual(g.shape_gap(shapes[i], shapes[j]), BASE_GAP, (i, j))
        paths = [seg_poly(e["path"]) for e in self.layout["entrances"]]
        for b, s in zip(self.bases, shapes):
            self.assertGreater(near_radius(s), PROMENADE[1], b["id"])
            self.assertLess(far_radius(s), WALL_R - WALL_THICK / 2 - 1.0, b["id"])
            for p in paths:
                self.assertGreaterEqual(g.shape_gap(s, p), BASE_PATH_CLEAR, b["id"])
            for h in self.hedge_shapes():
                self.assertGreater(g.shape_gap(s, h), 0.0, b["id"])

    def test_stations_never_overlap(self):
        for b in self.bases:
            stations = self.station_shapes(b)
            for i in range(len(stations)):
                for j in range(i + 1, len(stations)):
                    self.assertGreaterEqual(g.shape_gap(stations[i][1], stations[j][1]), STATION_GAP,
                                            (b["id"], stations[i][0], stations[j][0]))
                for f in self.fence_shapes(b):
                    self.assertGreater(g.shape_gap(stations[i][1], f), 0.0, (b["id"], stations[i][0]))
            lantern = circle_at(b["lantern"]["world"], b["lantern"]["r"])
            for kind, s in stations:
                self.assertGreater(g.shape_gap(lantern, s), 0.5, (b["id"], kind))

    def test_decorations_stay_off_bases_paths_and_the_campfire(self):
        bases = [self.base_shape(b) for b in self.bases]
        paths = [seg_poly(e["path"]) for e in self.layout["entrances"]]
        fire = circle_at(self.layout["lobby"]["campfire"]["centre"], self.layout["lobby"]["campfire"]["r"])
        pads = [g.rect_poly(p["centre"][0], p["centre"][1], p["size"] / 2, p["size"] / 2, 0.0)
                for p in self.layout["lobby"]["spawn_pads"]]
        for d in self.layout["decorations"]:
            s = shape(d["centre"], d["footprint"])
            for other in bases + paths + pads + [fire]:
                self.assertGreater(g.shape_gap(s, other), 0.0, d["id"])
        for p in pads:
            self.assertGreater(g.shape_gap(p, fire), 3.0)
            self.assertLess(far_radius(p), PLAZA_R)

    # -- stations inside their base --
    def test_stations_lie_inside_their_base(self):
        for b in self.bases:
            hx, hz = b["pad"]["half"]
            for s in b["stations"]:
                lx, lz = s["local"]
                fp = s["footprint"]
                ex, ez = (fp["r"], fp["r"]) if fp["kind"] == "circle" else fp["half"]
                self.assertLessEqual(abs(lx) + ex, hx - STATION_MARGIN, (b["id"], s["kind"]))
                self.assertLessEqual(abs(lz) + ez, hz - STATION_MARGIN, (b["id"], s["kind"]))
                world = local_to_world(b["centre"], b["yaw"], s["local"])
                self.assertAlmostEqual(world[0], s["world"][0], places=2)
                self.assertAlmostEqual(world[1], s["world"][1], places=2)
                pad = g.rect_poly(b["centre"][0], b["centre"][1], hx, hz, b["yaw"])
                if fp["kind"] == "rect":
                    for p in shape(s["world"], fp).pts:
                        self.assertTrue(g.poly_contains(pad.pts, p), (b["id"], s["kind"]))
                else:
                    self.assertTrue(g.poly_contains(pad.pts, tuple(s["world"])))
            lx, lz = b["lantern"]["local"]
            self.assertLess(abs(lx) + b["lantern"]["r"], hx)
            self.assertLess(abs(lz) + b["lantern"]["r"], hz)

    # -- reachability --
    def walk_grid(self):
        """Free cells (inside the floor or on a trail, outside every inflated obstacle) and the BFS from spawn 1."""
        n = int(2 * 120 / GRID) + 1

        def cell(p):
            return (int(round((p[0] + 120) / GRID)), int(round((p[1] + 120) / GRID)))

        def point(c):
            return (c[0] * GRID - 120, c[1] * GRID - 120)

        trails = [seg_poly(e["trail"]) for e in self.layout["entrances"]]
        obstacles = list(self.hedge_shapes())
        for b in self.bases:
            obstacles += self.fence_shapes(b) + [s for _, s in self.station_shapes(b)]
            obstacles.append(circle_at(b["lantern"]["world"], b["lantern"]["r"]))
        lobby = self.layout["lobby"]
        obstacles.append(circle_at(lobby["campfire"]["centre"], lobby["campfire"]["r"] + 0.8))
        obstacles += [shape(d["centre"], d["footprint"]) for d in self.layout["decorations"]]
        blocked = set()
        for s in obstacles:
            x0, z0, x1, z1 = g.shape_bbox(s)
            c0, c1 = cell((x0 - CLEARANCE, z0 - CLEARANCE)), cell((x1 + CLEARANCE, z1 + CLEARANCE))
            for i in range(c0[0], c1[0] + 1):
                for j in range(c0[1], c1[1] + 1):
                    if g.shape_point_dist(s, point((i, j))) <= CLEARANCE:
                        blocked.add((i, j))

        def free(c):
            if c in blocked or not (0 <= c[0] < n and 0 <= c[1] < n):
                return False
            p = point(c)
            return math.hypot(*p) <= FLOOR_R - CLEARANCE or any(g.poly_contains(t.pts, p) for t in trails)

        start = cell(tuple(lobby["spawn_pads"][0]["centre"]))
        self.assertTrue(free(start))
        seen, queue = {start}, deque([start])
        while queue:
            c = queue.popleft()
            for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nxt = (c[0] + d[0], c[1] + d[1])
                if nxt not in seen and free(nxt):
                    seen.add(nxt)
                    queue.append(nxt)
        return seen, cell, point

    def test_every_base_station_and_entrance_is_reachable_on_foot(self):
        seen, cell, point = self.walk_grid()
        for b in self.bases:
            for kind, s in self.station_shapes(b):
                x0, z0, x1, z1 = g.shape_bbox(s)
                c0, c1 = cell((x0 - REACH, z0 - REACH)), cell((x1 + REACH, z1 + REACH))
                hit = any((i, j) in seen and g.shape_point_dist(s, point((i, j))) <= REACH
                          for i in range(c0[0], c1[0] + 1) for j in range(c0[1], c1[1] + 1))
                self.assertTrue(hit, (b["id"], kind))
        for e in self.layout["entrances"]:
            end = e["trail"]["to"]
            self.assertTrue(any(math.dist(point(c), end) <= 3.0 for c in seen), e["id"])
        for p in self.layout["lobby"]["spawn_pads"][1:]:
            self.assertIn(cell(tuple(p["centre"])), seen, p["id"])

    # -- entrances --
    def test_several_entrances_and_at_least_three_to_the_forest(self):
        ents = self.layout["entrances"]
        self.assertGreaterEqual(len(ents), MIN_ENTRANCES)
        self.assertGreaterEqual(sum(1 for e in ents if e["leads"] == "forest"), MIN_FOREST_ENTRANCES)
        self.assertEqual(len({e["id"] for e in ents}), len(ents))
        for i in range(len(ents)):
            for j in range(i + 1, len(ents)):
                self.assertGreaterEqual(math.dist(ents[i]["gate"], ents[j]["gate"]), MIN_GATE_SPACING)
        for e in ents:
            self.assertEqual(e["width"], GATE_W)
            self.assertAlmostEqual(math.hypot(*e["gate"]), WALL_R, places=2)
            for h in self.hedge_shapes():   # the gap is open across its whole width
                self.assertGreaterEqual(g.shape_point_dist(h, tuple(e["gate"])), GATE_W / 2 - 0.05, e["id"])
            self.assertTrue(e["sign"])

    def test_hedge_closes_the_wall_between_gates(self):
        gates = [e["bearing"] for e in self.layout["entrances"]]
        half = math.degrees(math.asin((GATE_W / 2) / WALL_R))
        hedges = self.hedge_shapes()
        for k in range(360):
            b = k + 0.5
            if any(abs((b - gb + 180) % 360 - 180) <= half + 1.0 for gb in gates):
                continue
            p = (WALL_R * math.cos(math.radians(b)), WALL_R * math.sin(math.radians(b)))
            self.assertTrue(any(g.shape_point_dist(h, p) <= 0.6 for h in hedges), b)

    def test_trails_join_the_open_world_roads(self):
        conns = self.ow["connectors"]
        for e in self.layout["entrances"]:
            end = tuple(e["trail"]["to"])
            if e["joins"] == "forest_floor":
                self.assertEqual(e["leads"], "forest")
                self.assertLess(end[0], -REGION_EDGE_X)          # inside the forest square, past its edge wall
                fog = self.ow["zone_rules"]["forest"]["fog"]
                self.assertFalse(fog["x"][0] <= end[0] <= fog["x"][1] and fog["z"][0] <= end[1] <= fog["z"][1])
                for side in self.ow["hooks"].values():
                    self.assertGreaterEqual(math.dist(end, (side["x"], side["z"])), HOOK_CLEAR, e["id"])
            else:
                nodes = [tuple(n) for n in conns[e["joins"]]["nodes"]]
                d = min(g.point_seg_dist(end, a, b) for a, b in zip(nodes, nodes[1:]))
                self.assertLess(d, 0.01, e["id"])
            self.assertAlmostEqual(math.hypot(*e["trail"]["from"]), WALL_R + 1.0, places=2)

    def test_removed_forest_props_are_exactly_those_under_the_new_trails(self):
        layout = json.loads(FOREST_JSON.read_text(encoding="utf-8"))
        already = {r["id"] for r in self.ow["forest_block"]["removed_props"]}
        trails = [(e["id"], tuple(e["trail"]["from"]), tuple(e["trail"]["to"]))
                  for e in self.layout["entrances"] if e["leads"] == "forest"]
        expected = {}
        for inst in layout["instances"]:
            world = dict(inst, x=inst["x"] + FOREST_OFFSET[0], z=inst["z"] + FOREST_OFFSET[1])
            for s in forest.footprint(world):
                geo = g.Circle(s.x, s.z, s.r) if isinstance(s, forest.Circle) else g.Poly(tuple(s.pts))
                for ident, a, b in trails:
                    if inst["id"] not in already and g.shape_segment_dist(geo, a, b) < FOREST_CLEAR:
                        expected.setdefault(inst["id"], set()).add("trail_" + ident)
        reported = {r["id"]: set(r["by"]) for r in self.layout["removed_forest_props"]}
        self.assertEqual(reported, expected)
        self.assertLessEqual(len(reported), 6)

    # -- safety --
    def test_safe_zone_covers_every_base_station_pad_and_the_lobby(self):
        zones = self.layout["safe_zones"]
        self.assertEqual(len(zones), 1)
        zone = zones[0]
        self.assertEqual(zone["tag"], "WildboundHubSafeZone")
        self.assertEqual(zone["centre"], [0.0, 0.0])
        r = zone["radius"]
        self.assertEqual(r, SAFE_R)
        self.assertGreaterEqual(r, WALL_R + WALL_THICK / 2)
        for b in self.bases:
            self.assertLessEqual(far_radius(self.base_shape(b)), r, b["id"])
            for kind, s in self.station_shapes(b):
                self.assertLessEqual(far_radius(s), r, (b["id"], kind))
        for p in self.layout["lobby"]["spawn_pads"]:
            self.assertLessEqual(math.hypot(*p["centre"]) + p["size"], r)
        self.assertLessEqual(r, REGION_EDGE_X, "the safe disc stays out of both region squares")

    def test_nothing_lies_inside_any_beast_reach(self):
        beasts = self.ow["zone_rules"]["strike_zones"]
        self.assertEqual({z["key"] for z in beasts}, {"silueta", "nube", "abeja"})
        safe = self.layout["safe_zones"][0]
        for z in beasts:
            home = tuple(z["home"])
            reach = max(z["reach"], z["strike_radius"])
            self.assertGreater(math.dist(home, safe["centre"]) - safe["radius"], reach + BEAST_MARGIN, z["key"])
            for e in self.layout["entrances"]:
                d = g.point_seg_dist(home, tuple(e["trail"]["from"]), tuple(e["trail"]["to"])) - e["trail"]["width"] / 2
                self.assertGreater(d, reach + BEAST_MARGIN, (z["key"], e["id"]))
            for b in self.bases:
                self.assertGreater(g.shape_point_dist(self.base_shape(b), home), reach + BEAST_MARGIN)

    def test_the_bigger_hub_keeps_the_open_world_rules(self):
        r = SAFE_R
        rules = self.ow["refugio_rules"]
        for side in self.ow["refugio_sets"].values():
            for s in side:
                for c in s["candidates"]:
                    gap = math.hypot(c["x"], c["z"]) - rules["radius"] - r
                    self.assertGreaterEqual(gap, rules["safe_margin"], c["id"])
        for hook in self.ow["hooks"].values():
            self.assertGreater(math.hypot(hook["x"], hook["z"]), r + HOOK_CLEAR, hook["id"])
        for side in self.ow["spawn_seeds"].values():
            for seed in side:
                self.assertGreater(math.hypot(seed["x"], seed["z"]), r)
        kit = json.loads(PRADERA_JSON.read_text(encoding="utf-8"))
        off = self.ow["regions"]["pradera"]["offset"]
        for inst in kit["instances"]:
            fp = pradera.footprint(dict(inst, x=inst["x"] + off[0], z=inst["z"] + off[1]))
            self.assertGreater(g.shape_point_dist(fp, (0.0, 0.0)), FLOOR_R, inst["id"])

    def test_light_budget(self):
        lights = self.layout["lights"]
        self.assertLessEqual(len(lights), LIGHTS_CAP)
        self.assertEqual(len({l["id"] for l in lights}), len(lights))
        for l in lights:
            self.assertLessEqual(l["range"], 30.0)
            self.assertLessEqual(l["brightness"], 2.0)
        self.assertEqual(sum(1 for l in lights if l["id"].startswith("base-")), SLOTS)

    # -- reproducibility --
    def test_generation_is_deterministic(self):
        self.assertEqual(plan.to_json(plan.generate(self.ow)), plan.to_json(plan.generate(self.ow)))

    def test_committed_json_matches_the_generator(self):
        if not COMMITTED.exists():
            self.skipTest("plan not written yet")
        self.assertEqual(COMMITTED.read_text(encoding="utf-8"), plan.to_json(plan.generate(self.ow)))
        self.assertEqual(COMMITTED.read_bytes().count(b"\r\n"), 0, "LF line endings")


if __name__ == "__main__":
    unittest.main()

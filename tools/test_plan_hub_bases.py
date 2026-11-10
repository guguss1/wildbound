"""Contracts for the hub-with-personal-bases plan (tools/plan_hub_bases.py; DESIGN, unvalidated).

Run from the project root (isolated mode, no bytecode written):

    python -I -B -m unittest discover -s tools -p test_plan_hub_bases.py

The spec numbers are restated here on purpose: the tests re-derive each rule from the saved JSON (and from
layout-v1.json for the open world) instead of trusting the generator. Rules: eight bases that never overlap each
other, the lobby, the gate paths or the hedge; every station inside its base; every base and every entrance reachable
on foot from a spawn pad; at least three entrances to the forest; the safe zone covers every base; nothing inside any
beast's reach. Nothing here was built in Studio, played or measured on a device.

Two variants share these contracts: v1 (radius 90, what Studio builds today) and v2, the hub expansion of
docs/design/wildbound-hub-expansion.md (radius 100, shop circles in the lawn ring, a chest zone in every base, a
showcase in front of every base, more and brighter warm lamps). The v2-only contracts are in `ExpansionV2`.
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
import simulate_economy as p0

REPO = Path(__file__).resolve().parent.parent
OPEN_WORLD = REPO / "assets/maps/open-world/layout-v1.json"
FOREST_JSON = REPO / "assets/maps/forest-layout/forest-layout-v1.json"
PRADERA_JSON = REPO / "assets/maps/pradera-layout/pradera-layout-v1.json"
COMMITTED_V1 = REPO / "assets/maps/hub-layout/hub-bases-v1.json"
COMMITTED_V2 = REPO / "assets/maps/hub-layout/hub-bases-v2.json"

# ---- Spec, restated -----------------------------------------------------------------------------------------------
SLOTS = 8
V1 = {"safe_r": 90.0, "wall_r": 88.0, "wall_thick": 2.0, "floor_r": 92.0, "plaza_r": 30.0, "promenade": (46.0, 54.0),
      "lights_cap": 20}
V2 = {"safe_r": 100.0, "wall_r": 98.0, "wall_thick": 2.0, "floor_r": 102.0, "plaza_r": 34.0, "promenade": (50.0, 58.0),
      "lights_cap": 36}
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

# v2 expansion (docs/design/wildbound-hub-expansion.md)
MIN_SHOPS = 4
SHOP_TRIGGER, SHOP_HYSTERESIS, SHOP_TOLERANCE = 4.0, (1.0, 2.5), (1.0, 3.0)
SHOP_SPACING = 14.0            # two shop circles never open together: centres farther apart than two close radii
CHEST_TRIGGER = 2.0
SHOWCASE_R = 2.0
WARM_LIGHT = "red >= green >= blue"
ATMOSPHERE_OPEN = {"Day": (0.68, 140.0), "Dusk": (0.76, 90.0), "Night": (0.82, 60.0)}  # WildboundAtmosphere open rows
ATMOSPHERE_FLOORS = {"fogStart": 15.0, "fogEnd": 45.0}
REFUGIO_CHECK = {"radius": 8.0, "safe_margin": 20.0, "beast_margin": 10.0, "min_spacing": 60.0, "road_clear": 15.0,
                 "prop_clear": 9.0}
EXTRA_TAGS = {"shop": "WildboundShopSpot", "chest": "WildboundChestStation", "showcase": "WildboundShowcase",
              "bank": "WildboundBaseZone"}
INCUBATOR_SLOTS = 2            # eggs that incubate at once in one base (v2)
FOREST_NIGHT_AMBIENT = (22, 28, 46)  # WildboundAtmosphere LIGHT.Night.ambient


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


def extra_obstacles(layout):
    """v2 props a walker must go around: showcase plinths, chest boxes and shop stalls (none in v1)."""
    out = []
    for b in layout["bases"]:
        if "showcase" in b:
            out.append(circle_at(b["showcase"]["world"], b["showcase"]["r"]))
        if "chest" in b:
            prop = b["chest"]["prop"]
            out.append(g.rect_poly(prop["world"][0], prop["world"][1], prop["half"][0], prop["half"][1], prop["yaw"]))
    for s in layout.get("shops", []):
        st = s["stall"]
        out.append(g.rect_poly(st["centre"][0], st["centre"][1], st["half"][0], st["half"][1], st["yaw"]))
    return out


class Plan(unittest.TestCase):
    VARIANT, NAME, COMMITTED = "v1", "hub-bases-v1", COMMITTED_V1
    S = V1

    @classmethod
    def setUpClass(cls):
        cls.ow = json.loads(OPEN_WORLD.read_text(encoding="utf-8"))
        cls.layout = json.loads(plan.to_json(plan.generate(cls.ow, variant=cls.VARIANT)))
        cls.bases = cls.layout["bases"]

    # -- helpers --
    def base_shape(self, base):
        return shape(base["centre"], base["bounds"])

    def station_shapes(self, base):
        return [(s["kind"], shape(s["world"], s["footprint"])) for s in base["stations"]]

    def fence_shapes(self, base):
        return [g.rect_poly(f["world"][0], f["world"][1], f["half"][0], f["half"][1], f["yaw"]) for f in base["fences"]]

    def hedge_shapes(self):
        return [g.rect_poly(h["centre"][0], h["centre"][1], h["length"] / 2, self.S["wall_thick"] / 2, h["yaw"])
                for h in self.layout["hedge"]]

    # -- schema and frame --
    def test_schema_and_frame_match_the_open_world(self):
        lay = self.layout
        for key in ("name", "status", "seed", "conventions", "hub", "lobby", "bases", "entrances", "hedge",
                    "safe_zones", "decorations", "lights", "removed_forest_props", "budget"):
            self.assertIn(key, lay)
        self.assertEqual(lay["name"], self.NAME)
        self.assertIn("unvalidated", lay["status"])
        self.assertEqual(lay["hub"]["centre"], self.ow["hub"]["centre"])
        self.assertEqual(lay["hub"]["centre"], [0.0, 0.0])
        self.assertEqual(lay["hub"]["safe_radius"], self.S["safe_r"])
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
            self.assertGreater(near_radius(s), self.S["promenade"][1], b["id"])
            self.assertLess(far_radius(s), self.S["wall_r"] - self.S["wall_thick"] / 2 - 1.0, b["id"])
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
        extras = extra_obstacles(self.layout)
        shops = [circle_at(s["centre"], s["trigger_radius"]) for s in self.layout.get("shops", [])]
        for d in self.layout["decorations"]:
            s = shape(d["centre"], d["footprint"])
            for other in bases + paths + pads + [fire] + extras + shops:
                self.assertGreater(g.shape_gap(s, other), 0.0, d["id"])
        for p in pads:
            self.assertGreater(g.shape_gap(p, fire), 3.0)
            self.assertLess(far_radius(p), self.S["plaza_r"])

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
        half = math.ceil(self.S["floor_r"] + 30.0)
        n = int(2 * half / GRID) + 1

        def cell(p):
            return (int(round((p[0] + half) / GRID)), int(round((p[1] + half) / GRID)))

        def point(c):
            return (c[0] * GRID - half, c[1] * GRID - half)

        trails = [seg_poly(e["trail"]) for e in self.layout["entrances"]]
        obstacles = list(self.hedge_shapes())
        for b in self.bases:
            obstacles += self.fence_shapes(b) + [s for _, s in self.station_shapes(b)]
            obstacles.append(circle_at(b["lantern"]["world"], b["lantern"]["r"]))
        lobby = self.layout["lobby"]
        obstacles.append(circle_at(lobby["campfire"]["centre"], lobby["campfire"]["r"] + 0.8))
        obstacles += [shape(d["centre"], d["footprint"]) for d in self.layout["decorations"]]
        obstacles += extra_obstacles(self.layout)
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
            return math.hypot(*p) <= self.S["floor_r"] - CLEARANCE or any(g.poly_contains(t.pts, p) for t in trails)

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
            self.assertAlmostEqual(math.hypot(*e["gate"]), self.S["wall_r"], places=2)
            for h in self.hedge_shapes():   # the gap is open across its whole width
                self.assertGreaterEqual(g.shape_point_dist(h, tuple(e["gate"])), GATE_W / 2 - 0.05, e["id"])
            self.assertTrue(e["sign"])

    def test_hedge_closes_the_wall_between_gates(self):
        gates = [e["bearing"] for e in self.layout["entrances"]]
        wall_r = self.S["wall_r"]
        half = math.degrees(math.asin((GATE_W / 2) / wall_r))
        hedges = self.hedge_shapes()
        for k in range(360):
            b = k + 0.5
            if any(abs((b - gb + 180) % 360 - 180) <= half + 1.0 for gb in gates):
                continue
            p = (wall_r * math.cos(math.radians(b)), wall_r * math.sin(math.radians(b)))
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
            self.assertAlmostEqual(math.hypot(*e["trail"]["from"]), self.S["wall_r"] + 1.0, places=2)
            self.assertGreater(e["trail"]["length"], 0.0, e["id"])

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
        self.assertEqual(r, self.S["safe_r"])
        self.assertGreaterEqual(r, self.S["wall_r"] + self.S["wall_thick"] / 2)
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

    def refugio_sets_after_changes(self):
        """layout-v1's Refugio sets with the plan's declared moves applied (v1 declares none)."""
        moves = {c["id"]: c for c in self.layout.get("open_world_changes", []) if c["kind"] == "refugio_candidate"}
        sets = json.loads(json.dumps(self.ow["refugio_sets"]))
        for side in sets.values():
            for s in side:
                for c in s["candidates"]:
                    if c["id"] in moves:
                        self.assertEqual([c["x"], c["z"]], moves[c["id"]]["from"], c["id"])
                        c["x"], c["z"] = moves[c["id"]]["to"]
        return sets, moves

    def test_the_bigger_hub_keeps_the_open_world_rules(self):
        r = self.S["safe_r"]
        rules = self.ow["refugio_rules"]
        sets, _ = self.refugio_sets_after_changes()
        for side in sets.values():
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
            self.assertGreater(g.shape_point_dist(fp, (0.0, 0.0)), self.S["floor_r"], inst["id"])

    def test_light_budget(self):
        lights = self.layout["lights"]
        self.assertLessEqual(len(lights), self.S["lights_cap"])
        self.assertEqual(len({l["id"] for l in lights}), len(lights))
        for l in lights:
            self.assertLessEqual(l["range"], 30.0)
            self.assertLessEqual(l["brightness"], 2.0)
        self.assertEqual(sum(1 for l in lights if l["id"].startswith("base-")), SLOTS)

    # -- reproducibility --
    def test_generation_is_deterministic(self):
        self.assertEqual(plan.to_json(plan.generate(self.ow, variant=self.VARIANT)),
                         plan.to_json(plan.generate(self.ow, variant=self.VARIANT)))

    def test_committed_json_matches_the_generator(self):
        self.assertEqual(plan.out_path(self.VARIANT), self.COMMITTED)
        if not self.COMMITTED.exists():
            self.skipTest("plan not written yet")
        self.assertEqual(self.COMMITTED.read_text(encoding="utf-8"),
                         plan.to_json(plan.generate(self.ow, variant=self.VARIANT)))
        self.assertEqual(self.COMMITTED.read_bytes().count(b"\r\n"), 0, "LF line endings")

    def test_default_generation_is_v1(self):
        self.assertEqual(plan.to_json(plan.generate(self.ow)), plan.to_json(plan.generate(self.ow, variant="v1")))


class PlanV2(Plan):
    """Every v1 contract, re-run on the expansion (radius 100) with its own numbers."""
    VARIANT, NAME, COMMITTED = "v2", "hub-bases-v2", COMMITTED_V2
    S = V2


class ExpansionV2(unittest.TestCase):
    """Contracts only the expansion has: larger and brighter, shop circles, chest zones, showcases, ambience."""

    @classmethod
    def setUpClass(cls):
        cls.ow = json.loads(OPEN_WORLD.read_text(encoding="utf-8"))
        cls.v1 = json.loads(plan.to_json(plan.generate(cls.ow, variant="v1")))
        cls.layout = json.loads(plan.to_json(plan.generate(cls.ow, variant="v2")))
        cls.bases = cls.layout["bases"]
        cls.paths = [seg_poly(e["path"]) for e in cls.layout["entrances"]]
        cls.tuning = p0.load_tuning()

    def base_shape(self, b):
        return shape(b["centre"], b["bounds"])

    def test_v1_stays_without_expansion_keys(self):
        for key in ("shops", "lighting", "open_world_changes", "walk_times"):
            self.assertNotIn(key, self.v1)
        for b in self.v1["bases"]:
            self.assertNotIn("chest", b)
            self.assertNotIn("showcase", b)

    def test_the_hub_is_larger_and_still_inside_the_band(self):
        self.assertGreater(self.layout["hub"]["safe_radius"], self.v1["hub"]["safe_radius"])
        self.assertGreater(self.layout["lobby"]["plaza_radius"], self.v1["lobby"]["plaza_radius"])
        self.assertLessEqual(self.layout["hub"]["safe_radius"], REGION_EDGE_X)
        v1_pad = self.v1["bases"][0]["pad"]["half"]
        v2_pad = self.bases[0]["pad"]["half"]
        self.assertGreater(v2_pad[0] * v2_pad[1], v1_pad[0] * v1_pad[1], "bases grow to fit the chest zone")
        walk = self.layout["walk_times"]
        self.assertEqual(walk["speed"], 16.0)
        self.assertLessEqual(walk["spawn_to_gate_s"], 6.0)
        self.assertLessEqual(walk["spawn_to_base_s"], 4.5)
        self.assertAlmostEqual(walk["spawn_to_gate_s"], (self.layout["hub"]["wall"]["radius"] - 16.0) / 16.0, places=2)

    def test_shop_spots_are_circles_on_the_lawn_ring(self):
        shops = self.layout["shops"]
        self.assertGreaterEqual(len(shops), MIN_SHOPS)
        self.assertEqual(len({s["id"] for s in shops}), len(shops))
        plaza_r = self.layout["lobby"]["plaza_radius"]
        prom_in = self.layout["lobby"]["promenade"]["radius"] - self.layout["lobby"]["promenade"]["width"] / 2
        for s in shops:
            self.assertEqual(s["tag"], EXTRA_TAGS["shop"])
            self.assertEqual(s["trigger_radius"], SHOP_TRIGGER)
            self.assertGreaterEqual(s["close_radius"] - s["trigger_radius"], SHOP_HYSTERESIS[0], s["id"])
            self.assertLessEqual(s["close_radius"] - s["trigger_radius"], SHOP_HYSTERESIS[1], s["id"])
            self.assertGreaterEqual(s["server_range"] - s["trigger_radius"], SHOP_TOLERANCE[0], s["id"])
            self.assertLessEqual(s["server_range"] - s["trigger_radius"], SHOP_TOLERANCE[1], s["id"])
            self.assertTrue(s["label"] and s["sign"], s["id"])
            ring = circle_at(s["centre"], s["trigger_radius"])
            self.assertGreaterEqual(near_radius(ring), plaza_r + 1.0, s["id"])
            self.assertLessEqual(far_radius(ring), prom_in - 1.0, s["id"])
            st = s["stall"]
            stall = g.rect_poly(st["centre"][0], st["centre"][1], st["half"][0], st["half"][1], st["yaw"])
            self.assertGreater(g.shape_gap(stall, ring), 0.0, s["id"])
            self.assertLessEqual(far_radius(stall), prom_in, s["id"])
            for p in self.paths:
                self.assertGreaterEqual(g.shape_gap(ring, p), 2.0, s["id"])
                self.assertGreaterEqual(g.shape_gap(stall, p), 2.0, s["id"])
        for i in range(len(shops)):
            for j in range(i + 1, len(shops)):
                d = math.dist(shops[i]["centre"], shops[j]["centre"])
                self.assertGreater(d, shops[i]["close_radius"] + shops[j]["close_radius"] + SHOP_SPACING / 2)

    def test_shops_sell_only_esencia_items_that_exist_in_the_economy_config(self):
        self.assertEqual(self.tuning["monetization"], "none")
        self.assertFalse(self.tuning["currency"]["purchasable"])
        for s in self.layout["shops"]:
            self.assertTrue(s["sells"], s["id"])
            for group, ids in s["sells"].items():
                self.assertIn(group, ("recipes", "upgrades", "skills", "gear"), s["id"])
                for ident in ids:
                    self.assertIn(ident, self.tuning[group], (s["id"], ident))
            self.assertNotIn("robux", json.dumps(s).lower())
        sold = [i for s in self.layout["shops"] for ids in s["sells"].values() for i in ids]
        self.assertEqual(len(sold), len(set(sold)), "each item has one shop")

    def test_every_base_has_a_chest_zone_inside_its_pad(self):
        for b in self.bases:
            c = b["chest"]
            self.assertEqual(c["tag"], EXTRA_TAGS["chest"])
            self.assertEqual(c["trigger_radius"], CHEST_TRIGGER)
            self.assertGreaterEqual(c["server_range"] - c["trigger_radius"], 1.0)
            self.assertGreater(c["close_radius"], c["trigger_radius"])
            hx, hz = b["pad"]["half"]
            lx, lz = c["local"]
            self.assertLessEqual(abs(lx) + c["trigger_radius"], hx - STATION_MARGIN, b["id"])
            self.assertLessEqual(abs(lz) + c["trigger_radius"], hz - STATION_MARGIN, b["id"])
            world = local_to_world(b["centre"], b["yaw"], c["local"])
            self.assertAlmostEqual(world[0], c["world"][0], places=2)
            self.assertAlmostEqual(world[1], c["world"][1], places=2)
            zone = circle_at(c["world"], c["trigger_radius"])
            for s in b["stations"]:
                self.assertGreaterEqual(g.shape_gap(zone, shape(s["world"], s["footprint"])), STATION_GAP,
                                        (b["id"], s["kind"]))
            prop = c["prop"]
            box = g.rect_poly(prop["world"][0], prop["world"][1], prop["half"][0], prop["half"][1], prop["yaw"])
            self.assertGreater(g.shape_gap(box, zone), 0.0, b["id"])
            pad = g.rect_poly(b["centre"][0], b["centre"][1], hx, hz, b["yaw"])
            for p in box.pts:
                self.assertTrue(g.poly_contains(pad.pts, p), b["id"])

    def test_every_base_has_a_showcase_in_front_of_it(self):
        prom_out = self.layout["lobby"]["promenade"]["radius"] + self.layout["lobby"]["promenade"]["width"] / 2
        bases = [self.base_shape(b) for b in self.bases]
        for i, b in enumerate(self.bases):
            sc = b["showcase"]
            self.assertEqual(sc["tag"], EXTRA_TAGS["showcase"])
            self.assertEqual(sc["r"], SHOWCASE_R)
            self.assertGreaterEqual(sc["slots"], 1)
            ring = circle_at(sc["world"], sc["r"])
            self.assertGreater(near_radius(ring), prom_out + 1.0, b["id"])
            for j, other in enumerate(bases):
                self.assertGreaterEqual(g.shape_gap(ring, other), 0.5 if i == j else BASE_GAP, (b["id"], j))
            w = b["walk"]
            walk = g.rect_poly(w["world"][0], w["world"][1], w["half"][0], w["half"][1], w["yaw"])
            self.assertGreaterEqual(g.shape_gap(ring, walk), 1.0, b["id"])
            for p in self.paths:
                self.assertGreaterEqual(g.shape_gap(ring, p), BASE_PATH_CLEAR, b["id"])
            self.assertLessEqual(far_radius(ring), self.layout["hub"]["safe_radius"])
            a = math.radians(sc["yaw"])
            front = (-math.sin(a), -math.cos(a))            # the plate faces the lobby
            n = math.hypot(*sc["world"])
            self.assertGreater((front[0] * -sc["world"][0] + front[1] * -sc["world"][1]) / n, 0.9, b["id"])

    def test_every_shop_and_chest_zone_can_be_stood_on(self):
        grid = PlanV2("test_every_base_station_and_entrance_is_reachable_on_foot")
        grid.layout, grid.ow, grid.bases = self.layout, self.ow, self.bases
        seen, cell, point = grid.walk_grid()
        spots = [(s["id"], s["centre"], s["trigger_radius"]) for s in self.layout["shops"]]
        spots += [(b["id"] + "-chest", b["chest"]["world"], b["chest"]["trigger_radius"]) for b in self.bases]
        spots += [(b["id"] + "-showcase", b["showcase"]["world"], b["showcase"]["r"] + REACH) for b in self.bases]
        for ident, centre, radius in spots:
            c0, c1 = cell((centre[0] - radius, centre[1] - radius)), cell((centre[0] + radius, centre[1] + radius))
            inside = [(i, j) for i in range(c0[0], c1[0] + 1) for j in range(c0[1], c1[1] + 1)
                      if (i, j) in seen and math.dist(point((i, j)), centre) <= radius - 0.5]
            self.assertTrue(inside, ident)

    def test_lights_are_more_brighter_and_warm(self):
        lights = {l["id"]: l for l in self.layout["lights"]}
        old = {l["id"]: l for l in self.v1["lights"]}
        self.assertGreater(len(lights), len(old))
        for ident, l in old.items():
            if ident in lights:
                self.assertGreaterEqual(lights[ident]["brightness"], l["brightness"], ident)
                self.assertGreaterEqual(lights[ident]["range"], l["range"], ident)
        for s in self.layout["shops"]:
            self.assertIn("shop-" + s["id"], lights)
        for b in self.bases:
            self.assertIn("showcase-%d" % b["slot"], lights)
        for l in lights.values():
            r, gr, bl = l["color"]
            self.assertTrue(r >= gr >= bl, (l["id"], WARM_LIGHT))

    def test_ambience_is_brighter_than_the_forest_and_keeps_the_fog_floors(self):
        amb = self.layout["lighting"]
        self.assertEqual(amb["inside_radius"], self.layout["hub"]["safe_radius"])
        self.assertGreater(amb["blend_studs"], 0.0)
        self.assertEqual(amb["zone"], "hub")
        for phase, (density, fog_end) in ATMOSPHERE_OPEN.items():
            row = amb["atmosphere"][phase]
            self.assertLess(row["density"], density, phase)
            self.assertGreater(row["fogEnd"], fog_end, phase)
            self.assertGreaterEqual(row["fogStart"], ATMOSPHERE_FLOORS["fogStart"], phase)
            self.assertGreaterEqual(row["fogEnd"], ATMOSPHERE_FLOORS["fogEnd"], phase)
            cr, cg, cb = row["color"]
            self.assertTrue(cr >= cg >= cb, phase)
        self.assertGreater(amb["tint"]["brightness"], 0.0)
        self.assertLessEqual(amb["tint"]["brightness"], 0.1)

    def test_open_world_changes_are_exactly_the_refugios_the_bigger_disc_crowds(self):
        r = self.layout["hub"]["safe_radius"]
        rules = self.ow["refugio_rules"]
        crowded = {c["id"] for side in self.ow["refugio_sets"].values() for s in side for c in s["candidates"]
                   if math.hypot(c["x"], c["z"]) - rules["radius"] - r < rules["safe_margin"]}
        changes = self.layout["open_world_changes"]
        self.assertEqual({c["id"] for c in changes if c["kind"] == "refugio_candidate"}, crowded)
        self.assertIn("FA2", crowded)
        for k, v in REFUGIO_CHECK.items():
            self.assertEqual(rules[k], v, k)
        beasts = self.ow["zone_rules"]["strike_zones"]
        roads = [[tuple(n) for n in c["nodes"]] for c in self.ow["connectors"].values()]
        roads += [[tuple(e["trail"]["from"]), tuple(e["trail"]["to"])] for e in self.layout["entrances"]]
        fog = self.ow["zone_rules"]["forest"]["fog"]
        safes = list(self.ow["zone_rules"]["forest"]["safe"].values()) + list(
            self.ow["zone_rules"]["pradera"]["safe"].values())
        removed = {p["id"] for p in self.layout["removed_forest_props"]} | {
            p["id"] for p in self.ow["forest_block"]["removed_props"]}
        layout = json.loads(FOREST_JSON.read_text(encoding="utf-8"))
        props = []
        for inst in layout["instances"]:
            if inst["id"] in removed:
                continue
            world = dict(inst, x=inst["x"] + FOREST_OFFSET[0], z=inst["z"] + FOREST_OFFSET[1])
            for s in forest.footprint(world):
                props.append(g.Circle(s.x, s.z, s.r) if isinstance(s, forest.Circle) else g.Poly(tuple(s.pts)))
        for change in changes:
            p = tuple(change["to"])
            self.assertTrue(change["why"])
            self.assertGreaterEqual(math.hypot(*p) - rules["radius"] - r, rules["safe_margin"], change["id"])
            for z in beasts:
                self.assertGreaterEqual(math.dist(p, z["home"]), z["reach"] + rules["beast_margin"], change["id"])
            for line in roads:
                d = min(g.point_seg_dist(p, a, b) for a, b in zip(line, line[1:]))
                self.assertGreaterEqual(d, rules["road_clear"], change["id"])
            for prop in props:
                self.assertGreaterEqual(g.shape_point_dist(prop, p), rules["prop_clear"], change["id"])
            for s in safes:
                self.assertGreater(math.dist(p, s["centre"]), s["r"] + rules["radius"], change["id"])
            self.assertFalse(fog["x"][0] <= p[0] <= fog["x"][1] and fog["z"][0] <= p[1] <= fog["z"][1], change["id"])
            set_of = next(s for side in self.ow["refugio_sets"].values() for s in side
                          if any(c["id"] == change["id"] for c in s["candidates"]))
            for c in set_of["candidates"]:
                if c["id"] != change["id"]:
                    self.assertGreaterEqual(math.dist(p, (c["x"], c["z"])), rules["min_spacing"], change["id"])

    def test_every_base_has_a_bank_zone_that_covers_it(self):
        for i, b in enumerate(self.bases):
            z = b["bank_zone"]
            self.assertEqual(z["tag"], EXTRA_TAGS["bank"])
            self.assertEqual(z["kind"], "rect")
            self.assertEqual(z["centre"], b["centre"])
            self.assertEqual(z["yaw"], b["yaw"])
            self.assertEqual(z["half"], b["bounds"]["half"])
            self.assertGreaterEqual(z["exit_margin"], 1.0)
            self.assertGreaterEqual(z["height"], 10.0)
            box = g.rect_poly(z["centre"][0], z["centre"][1], z["half"][0], z["half"][1], z["yaw"])
            for s in b["stations"]:
                self.assertTrue(g.poly_contains(box.pts, tuple(s["world"])), (b["id"], s["kind"]))
            self.assertTrue(g.poly_contains(box.pts, tuple(b["chest"]["world"])), b["id"])
            for j, other in enumerate(self.bases):
                if i != j:
                    grown = g.rect_poly(z["centre"][0], z["centre"][1], z["half"][0] + z["exit_margin"],
                                        z["half"][1] + z["exit_margin"], z["yaw"])
                    self.assertGreater(g.shape_gap(grown, self.base_shape(other)), 0.0, (b["id"], j))
        incubators = [s for b in self.bases for s in b["stations"] if s["kind"] == "incubator"]
        self.assertTrue(all(s["slots"] == INCUBATOR_SLOTS for s in incubators))
        self.assertEqual(self.v1["bases"][0]["stations"][3].get("slots"), None)

    def test_the_hub_stays_lit_at_night(self):
        amb = self.layout["lighting"]
        night = amb["atmosphere"]["Night"]
        self.assertGreaterEqual(night["fogEnd"], 2 * ATMOSPHERE_OPEN["Night"][1])
        ambient = amb["ambient"]["Night"]
        self.assertGreater(sum(ambient), sum(FOREST_NIGHT_AMBIENT) * 2)
        self.assertTrue(ambient[0] >= ambient[1] >= ambient[2], "warm night ambient")
        self.assertGreaterEqual(amb["night_lamp_scale"], 1.0)
        self.assertLessEqual(amb["night_lamp_scale"] * max(l["brightness"] for l in self.layout["lights"]), 2.5)

    def test_budget_is_raised_on_purpose_and_stated(self):
        budget = self.layout["budget"]
        self.assertGreater(budget["parts_cap"], self.v1["budget"]["parts_cap"])
        self.assertLessEqual(budget["parts_cap"], 480)
        self.assertEqual(budget["lights_cap"], V2["lights_cap"])
        self.assertIn("phone", budget["why"])


if __name__ == "__main__":
    unittest.main()

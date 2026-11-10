"""Contracts for the open-world plan: hub, translated forest block, Pradera draft, roads (DESIGN, unvalidated).

Run from the project root (isolated mode, no bytecode written):

    python -I -B -m unittest discover -s tools -p test_plan_open_world_layout.py

The spec numbers are restated here on purpose: the tests pin the design independently of the
generator and re-derive each rule from the saved JSON instead of trusting the generator's report.
Nothing here was built in Studio, played or measured on a device.
"""

import json
import math
import tempfile
import unittest
from pathlib import Path

import layout_geometry as g
import plan_forest_layout as forest
import plan_open_world_layout as plan

REPO = Path(__file__).resolve().parent.parent
FOREST_JSON = REPO / "assets/maps/forest-layout/forest-layout-v1.json"
ISLANDS_JSON = REPO / "assets/maps/forest-layout/islands-v1.json"
RELIEF_JSON = REPO / "assets/maps/forest-layout/relief-v1.json"
HIDE_JSON = REPO / "assets/maps/forest-layout/hide-spots-v1.json"
COMMITTED = REPO / "assets/maps/open-world/layout-v1.json"

# ---- Spec inputs, restated independently of the module under test ----------
WORLD = (1040.0, 450.0)
HUB_R, HUB_WALL, PLAZA = 60.0, 58.0, (25.0, 35.0)
STATION_BAND, SPOKE_CLEAR, STATION_GAP = (36.0, 56.0), 10.0, 8.0
FOREST_OFFSET, PRADERA_OFFSET = (-300.0, 0.0), (300.0, 0.0)
FOREST_HOME_LOCAL, FOG_LOCAL = (0.0, -85.0), (-45.0, 165.0, -165.0, 35.0)
FOREST_SAFE_LOCAL = {"camp": ((-140.0, 140.0), 35.0), "shelter": ((105.0, 125.0), 22.0)}
FOREST_ROUTE_LOCAL = [(-140, 140), (-95, 75), (0, -85), (35, -99), (115, 15), (105, 125)]
LEASH, CHASE = 80.0, 100.0
PRADERA_HOME, PRADERA_ROAM = (400.0, -60.0), (300.0, 495.0, -165.0, 60.0)
PRADERA_OUTPOST = ((330.0, 130.0), 22.0)
ROAD_W, ROAD_CLEAR = 14.0, 10.0
RING_Z, RING_X = 212.0, 510.0
REFUGIO_R, HOME_CLEAR, SAFE_MARGIN, MIN_SPACING = 8.0, 110.0, 20.0, 60.0
HOOK_BAND, HOOK_FLOOR = (60.0, 110.0), 14.0
TIERS = (("Legendaria", 0, 45), ("Épica", 45, 80), ("Rara", 80, 120), ("Común", 120, math.inf))
ALT_SEEDS = (7, 1234)


def xz(d):
    return (d["x"], d["z"])


def in_rect(rect, p):
    return rect[0] <= p[0] <= rect[1] and rect[2] <= p[1] <= rect[3]


def shift(p, offset):
    """Translate and round to the plan's 3 decimals, so saved values compare exactly."""
    return (round(p[0] + offset[0], 3) + 0.0, round(p[1] + offset[1], 3) + 0.0)


def seg_dist(p, a, b):
    return g.point_seg_dist(p, a, b)


def polyline_dist(p, nodes, closed):
    pairs = list(zip(nodes, nodes[1:])) + ([(nodes[-1], nodes[0])] if closed else [])
    return min(seg_dist(p, a, b) for a, b in pairs)


def to_shape(shape):
    if isinstance(shape, forest.Circle):
        return g.Circle(shape.x, shape.z, shape.r)
    return g.Poly(tuple(shape.pts))


class Fixtures:
    forest_layout = islands = relief = hide = None

    @classmethod
    def load(cls):
        cls.forest_layout = json.loads(FOREST_JSON.read_text(encoding="utf-8"))
        cls.islands = json.loads(ISLANDS_JSON.read_text(encoding="utf-8"))
        cls.relief = json.loads(RELIEF_JSON.read_text(encoding="utf-8"))
        cls.hide = json.loads(HIDE_JSON.read_text(encoding="utf-8"))

    @classmethod
    def world_props(cls):
        """(id, footprint shapes in world studs) for every forest instance, translated independently."""
        out = []
        for inst in cls.forest_layout["instances"]:
            world = dict(inst, x=inst["x"] + FOREST_OFFSET[0], z=inst["z"] + FOREST_OFFSET[1])
            out.append((inst["id"], [to_shape(s) for s in forest.footprint(world)]))
        return out


class RuleChecks(Fixtures):
    """check_* methods only need self.layout; test classes decide which seed."""

    layout = None

    # -- helpers on the saved layout --
    def roads(self):
        lay = self.layout
        roads = [("ring", [tuple(p) for p in lay["ring_road"]["nodes"]], True)]
        for key in ("forest", "pradera"):
            roads.append((key, [tuple(p) for p in lay["regions"][key]["route"]["nodes"]], True))
        for name, c in lay["connectors"].items():
            roads.append((name, [tuple(p) for p in c["nodes"]], False))
        return roads

    def road_dist(self, p):
        return min(polyline_dist(p, nodes, closed) for _, nodes, closed in self.roads())

    def forest_safe(self, p, margin=0.0):
        return any(math.dist(p, shift(c, FOREST_OFFSET)) <= r + margin for c, r in FOREST_SAFE_LOCAL.values())

    def forest_zone(self, p):
        fog = in_rect(tuple(v + o for v, o in zip(FOG_LOCAL, (FOREST_OFFSET[0], FOREST_OFFSET[0], FOREST_OFFSET[1], FOREST_OFFSET[1]))), p)
        home = shift(FOREST_HOME_LOCAL, FOREST_OFFSET)
        if fog and not self.forest_safe(p) and math.dist(p, home) <= LEASH:
            return "territory"
        return "fog" if fog else "outside"

    def pradera_zone(self, p):
        safe = math.dist(p, PRADERA_OUTPOST[0]) <= PRADERA_OUTPOST[1]
        if in_rect(PRADERA_ROAM, p) and not safe and math.dist(p, PRADERA_HOME) <= LEASH:
            return "territory"
        return "fog" if in_rect(PRADERA_ROAM, p) else "outside"

    # -- schema and frame --
    def check_schema(self):
        lay = self.layout
        for key in ("name", "status", "seed", "conventions", "world", "hub", "regions", "transitions", "ring_road",
                    "connectors", "zone_rules", "forest_block", "hooks", "refugio_sets", "tier_bands", "spawn_seeds",
                    "spawn_seed_summary", "streaming"):
            self.assertIn(key, lay)
        self.assertIn("unvalidated", lay["status"])
        self.assertEqual(lay["world"]["size"], list(WORLD))
        self.assertEqual(lay["world"]["bounds"], {"x": [-WORLD[0] / 2, WORLD[0] / 2], "z": [-WORLD[1] / 2, WORLD[1] / 2]})
        self.assertEqual(lay["regions"]["forest"]["offset"], list(FOREST_OFFSET))
        self.assertEqual(lay["regions"]["pradera"]["offset"], list(PRADERA_OFFSET))

    def check_regions_and_hub_do_not_overlap(self):
        f, p = self.layout["regions"]["forest"]["bounds"], self.layout["regions"]["pradera"]["bounds"]
        self.assertEqual(f, {"x": [-500.0, -100.0], "z": [-200.0, 200.0]})
        self.assertEqual(p, {"x": [100.0, 500.0], "z": [-200.0, 200.0]})
        self.assertGreaterEqual(p["x"][0] - f["x"][1], 2 * HUB_R + 2 * 40.0)  # hub plus two 40-stud transitions
        hub = self.layout["hub"]
        self.assertEqual(hub["safe_radius"], HUB_R)
        self.assertLess(HUB_R, 100.0)
        t = self.layout["transitions"]
        self.assertEqual(t["west"]["x"], [f["x"][1], -HUB_R])
        self.assertEqual(t["east"]["x"], [HUB_R, p["x"][0]])

    # -- forest block translation --
    def check_forest_rules_moved_with_the_block(self):
        rules = self.layout["zone_rules"]["forest"]
        self.assertEqual(rules["home"], list(shift(FOREST_HOME_LOCAL, FOREST_OFFSET)))
        self.assertEqual(rules["fog"], {"x": [FOG_LOCAL[0] + FOREST_OFFSET[0], FOG_LOCAL[1] + FOREST_OFFSET[0]],
                                        "z": [FOG_LOCAL[2] + FOREST_OFFSET[1], FOG_LOCAL[3] + FOREST_OFFSET[1]]})
        self.assertEqual(rules["leash"], LEASH)
        self.assertEqual(rules["chase_leash"], CHASE)
        for name, (c, r) in FOREST_SAFE_LOCAL.items():
            self.assertEqual(rules["safe"][name], {"centre": list(shift(c, FOREST_OFFSET)), "r": r})
        route = self.layout["regions"]["forest"]["route"]["nodes"]
        self.assertEqual([tuple(p) for p in route], [shift(p, FOREST_OFFSET) for p in FOREST_ROUTE_LOCAL])
        self.assertEqual(self.layout["zone_rules"]["hub"], {"centre": [0.0, 0.0], "safe_radius": HUB_R,
                                                             "spawn_pad": {"x": 0.0, "z": 0.0, "radius": 9.0}})

    def check_islands_relief_and_hide_spots_are_pure_translations(self):
        fb = self.layout["forest_block"]
        self.assertEqual(len(fb["islands"]), len(self.islands["islands"]))
        for local, world in zip(self.islands["islands"], fb["islands"]):
            self.assertEqual(world["id"], local["id"])
            self.assertEqual(tuple(world["centre"]), shift(tuple(local["centre"]), FOREST_OFFSET))
            self.assertEqual(world["rewardTier"], local["rewardTier"])
            for a, b in zip(local["adultPoints"], world["adultPoints"]):
                self.assertEqual((b["x"], b["z"]), shift((a["x"], a["z"]), FOREST_OFFSET))
                self.assertEqual((b["faceX"], b["faceZ"]), (a["faceX"], a["faceZ"]))
        self.assertEqual(len(fb["relief_segments"]), len(self.relief["segments"]))
        for local, world in zip(self.relief["segments"], fb["relief_segments"]):
            self.assertEqual(world["id"], local["id"])
            self.assertEqual(tuple(world["a"]), shift(tuple(local["a"]), FOREST_OFFSET))
            self.assertEqual(tuple(world["b"]), shift(tuple(local["b"]), FOREST_OFFSET))
            self.assertEqual(world["height"], local["height"])
        self.assertEqual(len(fb["hide_spots"]), len(self.hide["spots"]))
        for local, world in zip(self.hide["spots"], fb["hide_spots"]):
            self.assertEqual(world["id"], local["id"])
            self.assertEqual(xz(world), shift(xz(local), FOREST_OFFSET))
        # Pairwise distances between islands survive, so every island rule measured locally still holds.
        for i in range(len(fb["islands"])):
            for j in range(i + 1, len(fb["islands"])):
                self.assertAlmostEqual(math.dist(fb["islands"][i]["centre"], fb["islands"][j]["centre"]),
                                       math.dist(self.islands["islands"][i]["centre"], self.islands["islands"][j]["centre"]), places=6)
        self.assertEqual(fb["triangles"], self.forest_layout["totals"]["triangles"])
        self.assertEqual(fb["instances_total"], len(self.forest_layout["instances"]))

    def check_removed_props_are_exactly_those_under_new_roads(self):
        new_roads = [(name, nodes, closed) for name, nodes, closed in self.roads()
                     if name in ("ring", "umbral_oeste", "espolon_campamento", "espolon_norte", "espolon_sur")]
        expected = {}
        for ident, shapes in self.world_props():
            for name, nodes, closed in new_roads:
                if any(g.shape_polyline_dist(s, nodes, closed=closed) < ROAD_CLEAR for s in shapes):
                    expected.setdefault(ident, []).append(name)
        reported = {r["id"]: r["by"] for r in self.layout["forest_block"]["removed_props"]}
        self.assertEqual(reported, expected)
        self.assertLessEqual(len(reported), 10, "two short roads must not cost more than a handful of props")
        self.assertEqual(self.layout["forest_block"]["instances_kept"], len(self.forest_layout["instances"]) - len(reported))
        ring = next(nodes for name, nodes, _ in self.roads() if name == "ring")
        for ident, shapes in self.world_props():
            for s in shapes:
                self.assertGreaterEqual(g.shape_polyline_dist(s, ring, closed=True), ROAD_W / 2, ident)

    # -- roads --
    def check_ring_road(self):
        ring = self.layout["ring_road"]
        nodes = [tuple(p) for p in ring["nodes"]]
        self.assertTrue(ring["closed"])
        self.assertEqual(ring["width"], ROAD_W)
        self.assertTrue(ring["beast_free"])
        for x, z in nodes:
            self.assertLessEqual(abs(x) + ROAD_W / 2, WORLD[0] / 2)
            self.assertLessEqual(abs(z) + ROAD_W / 2, WORLD[1] / 2)
            self.assertTrue(abs(z) >= RING_Z or abs(x) >= RING_X - 1e-9)
        length = g.polyline_length(nodes + nodes[:1])
        self.assertAlmostEqual(ring["length"], length, delta=0.01)
        self.assertAlmostEqual(ring["walk_seconds"], length / 16.0, delta=0.01)
        fog_world = (FOG_LOCAL[0] + FOREST_OFFSET[0], FOG_LOCAL[1] + FOREST_OFFSET[0], FOG_LOCAL[2], FOG_LOCAL[3])
        for k in range(400):  # sample the whole loop: outside both beast rectangles and beyond both chase leashes
            p = g.polyline_point(nodes + nodes[:1], length * k / 400)[0]
            self.assertFalse(in_rect(fog_world, p), p)
            self.assertFalse(in_rect(PRADERA_ROAM, p), p)
            self.assertGreater(math.dist(p, shift(FOREST_HOME_LOCAL, FOREST_OFFSET)), CHASE)
            self.assertGreater(math.dist(p, PRADERA_HOME), CHASE)
            for b in (self.layout["regions"]["forest"]["bounds"], self.layout["regions"]["pradera"]["bounds"]):
                square = g.rect_poly((b["x"][0] + b["x"][1]) / 2, (b["z"][0] + b["z"][1]) / 2,
                                     (b["x"][1] - b["x"][0]) / 2, (b["z"][1] - b["z"][0]) / 2, 0.0)
                self.assertGreaterEqual(g.shape_point_dist(square, p), ROAD_W / 2, p)

    def check_connectors_join_what_they_say(self):
        c = self.layout["connectors"]
        gates = self.layout["hub"]["gates"]
        self.assertEqual(c["umbral_oeste"]["nodes"][0], gates["W"])
        self.assertEqual(c["umbral_oeste"]["nodes"][-1], list(shift(FOREST_SAFE_LOCAL["shelter"][0], FOREST_OFFSET)))
        self.assertEqual(c["umbral_este"]["nodes"][0], gates["E"])
        self.assertEqual(c["umbral_este"]["nodes"][-1], self.layout["regions"]["pradera"]["route"]["nodes"][0])
        self.assertEqual(c["espolon_norte"]["nodes"], [gates["N"], [0.0, -RING_Z]])
        self.assertEqual(c["espolon_sur"]["nodes"], [gates["S"], [0.0, RING_Z]])
        self.assertEqual(c["espolon_campamento"]["nodes"][0], list(shift(FOREST_SAFE_LOCAL["camp"][0], FOREST_OFFSET)))
        self.assertEqual(c["espolon_campamento"]["nodes"][-1][1], RING_Z)
        self.assertEqual(c["espolon_pradera"]["nodes"][0], list(PRADERA_OUTPOST[0]))
        fog_world = (FOG_LOCAL[0] + FOREST_OFFSET[0], FOG_LOCAL[1] + FOREST_OFFSET[0], FOG_LOCAL[2], FOG_LOCAL[3])
        nodes = [tuple(p) for p in c["umbral_oeste"]["nodes"]]
        length = g.polyline_length(nodes)
        for k in range(200):  # the forest threshold never enters the fog: a new player reaches a safe circle first
            self.assertFalse(in_rect(fog_world, g.polyline_point(nodes, length * k / 200)[0]))
        for entry in c.values():
            self.assertEqual(entry["width"], ROAD_W)
            self.assertAlmostEqual(entry["length"], g.polyline_length([tuple(p) for p in entry["nodes"]]), delta=0.01)

    # -- hub --
    def check_hub_stations(self):
        hub = self.layout["hub"]
        self.assertEqual(hub["wall_radius"], HUB_WALL)
        self.assertEqual(hub["plaza_ring"], {"inner": PLAZA[0], "outer": PLAZA[1]})
        self.assertEqual(set(hub["gates"]), {"W", "E", "N", "S"})
        for gate in hub["gates"].values():
            self.assertAlmostEqual(math.hypot(*gate), HUB_R)
        ids = [s["id"] for s in hub["stations"]]
        for needed in ("incubadora", "corral", "refugio", "cofre", "tablero", "habilidades", "puesto"):
            self.assertIn(needed, ids)
        self.assertEqual(next(s for s in hub["stations"] if s["id"] == "incubadora")["slots"], 3)
        self.assertEqual(next(s for s in hub["stations"] if s["id"] == "corral")["slots"], 8)
        self.assertGreaterEqual(len(hub["trophies"]), 5)
        shapes = []
        for s in hub["stations"]:
            foot, (cx, cz) = s["footprint"], s["centre"]
            if foot["kind"] == "circle":
                shapes.append((s["id"], g.Circle(cx, cz, foot["r"])))
            else:
                shapes.append((s["id"], g.rect_poly(cx, cz, foot["half"][0], foot["half"][1], foot["yaw"])))
        for t in hub["trophies"]:
            shapes.append((t["id"], g.Circle(t["centre"][0], t["centre"][1], t["r"])))
        spokes = [((PLAZA[1] * gx / HUB_R, PLAZA[1] * gz / HUB_R), (gx, gz)) for gx, gz in hub["gates"].values()]
        for ident, shape in shapes:
            if isinstance(shape, g.Circle):
                inner, outer = math.hypot(shape.x, shape.z) - shape.r, math.hypot(shape.x, shape.z) + shape.r
            else:
                pts = shape.pts
                inner = min(seg_dist((0.0, 0.0), a, b) for a, b in zip(pts, pts[1:] + pts[:1]))
                outer = max(math.hypot(*p) for p in pts)
            self.assertGreaterEqual(inner, STATION_BAND[0] - 1e-6, ident)
            self.assertLessEqual(outer, STATION_BAND[1] + 1e-6, ident)
            self.assertLessEqual(outer, HUB_WALL - 1.0, ident)
            for a, b in spokes:
                self.assertGreaterEqual(g.shape_segment_dist(shape, a, b), SPOKE_CLEAR - 1e-6, ident)
        for i in range(len(shapes)):
            for j in range(i + 1, len(shapes)):
                self.assertGreaterEqual(g.shape_gap(shapes[i][1], shapes[j][1]), STATION_GAP - 1e-6, (shapes[i][0], shapes[j][0]))
        for pad in hub["spawn"]["pads"]:
            self.assertEqual(pad["faces"], "east")
            d = math.hypot(*pad["centre"])
            self.assertGreaterEqual(d - 2.0, 9.0)
            self.assertLessEqual(d + 2.0, PLAZA[0])
        self.assertEqual(hub["spawn"]["default_spawn_location"], {"centre": [0.0, 0.0], "radius": 9.0})

    # -- beasts stay on their sides --
    def check_leash_bands(self):
        rules = self.layout["zone_rules"]
        west, east = rules["forest"], rules["pradera"]
        self.assertEqual(west["home"][0] + CHASE, -200.0)
        self.assertEqual(east["home"][0] - CHASE, 300.0)
        self.assertEqual(rules["beast_free_band"]["x"], [-200.0, 300.0])
        self.assertLess(west["fog"]["x"][1], -HUB_R - 40.0)   # fog ends before the west transition begins
        self.assertGreater(east["roam"]["x"][0], HUB_R + 40.0)
        self.assertLessEqual(west["home"][0] + LEASH, west["fog"]["x"][1])
        self.assertGreaterEqual(east["home"][0] - LEASH, east["roam"]["x"][0])
        # The Pradera outpost and tutorial nest sit outside the beast's rectangle and beyond its chase leash.
        self.assertFalse(in_rect(PRADERA_ROAM, PRADERA_OUTPOST[0]))
        self.assertGreater(math.dist(PRADERA_OUTPOST[0], PRADERA_HOME), CHASE)
        hook = self.layout["hooks"]["east"]
        self.assertGreater(math.dist(xz(hook), PRADERA_HOME), CHASE + 50.0)

    # -- refugios --
    def check_refugio_sets(self):
        props = self.world_props()
        for side, sets in self.layout["refugio_sets"].items():
            self.assertIn(len(sets), (2, 3), side)
            home = shift(FOREST_HOME_LOCAL, FOREST_OFFSET) if side == "west" else PRADERA_HOME
            bounds = self.layout["regions"]["forest" if side == "west" else "pradera"]["bounds"]
            seen = set()
            for group in sets:
                cands = group["candidates"]
                self.assertIn(len(cands), (2, 3), group["id"])
                for c in cands:
                    p = xz(c)
                    self.assertNotIn(p, seen)
                    seen.add(p)
                    self.assertGreaterEqual(math.dist(p, home), HOME_CLEAR, c["id"])
                    self.assertNotEqual(c["zone"], "territory", c["id"])
                    self.assertEqual(c["zone"], self.forest_zone(p) if side == "west" else self.pradera_zone(p), c["id"])
                    self.assertAlmostEqual(c["distance_home"], math.dist(p, home), delta=0.01)
                    self.assertGreater(math.hypot(*p), HUB_R + SAFE_MARGIN, c["id"])
                    if side == "west":
                        self.assertFalse(self.forest_safe(p, SAFE_MARGIN), c["id"])
                        for ident, shapes in props:
                            if ident in {r["id"] for r in self.layout["forest_block"]["removed_props"]}:
                                continue
                            for s in shapes:
                                self.assertGreaterEqual(g.shape_point_dist(s, p), REFUGIO_R + 1.0 - 1e-6, (c["id"], ident))
                    else:
                        self.assertGreater(math.dist(p, PRADERA_OUTPOST[0]), PRADERA_OUTPOST[1] + SAFE_MARGIN, c["id"])
                    self.assertGreaterEqual(self.road_dist(p), REFUGIO_R + ROAD_W / 2 - 1e-6, c["id"])
                    self.assertTrue(bounds["x"][0] + 20 <= p[0] <= bounds["x"][1] - 20, c["id"])
                    self.assertTrue(bounds["z"][0] + 20 <= p[1] <= bounds["z"][1] - 20, c["id"])
                for i in range(len(cands)):
                    for j in range(i + 1, len(cands)):
                        self.assertGreaterEqual(math.dist(xz(cands[i]), xz(cands[j])), MIN_SPACING, group["id"])

    # -- hooks --
    def check_hooks(self):
        west, east = self.layout["hooks"]["west"], self.layout["hooks"]["east"]
        for hook in (west, east):
            d = math.dist(xz(hook), tuple(hook["gate"]))
            self.assertAlmostEqual(hook["distance_from_gate"], d, delta=0.01)
            self.assertTrue(HOOK_BAND[0] <= d <= HOOK_BAND[1], hook["id"])
            self.assertEqual(hook["tier"], "Safe")
            self.assertEqual(hook["zone"], "outside")
            self.assertGreater(math.hypot(*xz(hook)), HUB_R + HOOK_FLOOR)
        self.assertEqual(self.forest_zone(xz(west)), "outside")
        self.assertFalse(self.forest_safe(xz(west), HOOK_FLOOR))
        self.assertGreaterEqual(self.road_dist(xz(west)), 20.0 - 1e-6)
        removed = {r["id"] for r in self.layout["forest_block"]["removed_props"]}
        clear = min(g.shape_point_dist(s, xz(west)) for ident, shapes in self.world_props() if ident not in removed for s in shapes)
        self.assertGreaterEqual(clear, HOOK_FLOOR + 2.0 - 1e-6)
        self.assertAlmostEqual(west["prop_clearance"], clear, delta=0.01)
        self.assertEqual(west["species"], "Lumipol")
        self.assertEqual(xz(east), tuple(self.layout["regions"]["pradera"]["route"]["nodes"][1]))
        self.assertEqual(tuple(east["gate"]), tuple(self.layout["regions"]["pradera"]["route"]["nodes"][0]))

    # -- spawn-graph seeds --
    def check_spawn_seeds(self):
        seeds = self.layout["spawn_seeds"]
        removed = {r["id"] for r in self.layout["forest_block"]["removed_props"]}
        kept = [i for i in self.forest_layout["instances"] if i["id"] not in removed]
        for side in ("west", "east"):
            home = shift(FOREST_HOME_LOCAL, FOREST_OFFSET) if side == "west" else PRADERA_HOME
            bounds = self.layout["regions"]["forest" if side == "west" else "pradera"]["bounds"]
            summary = self.layout["spawn_seed_summary"][side]
            self.assertEqual(summary["count"], len(seeds[side]))
            by_tier = {}
            for s in seeds[side]:
                p = xz(s)
                d = math.dist(p, home)
                self.assertAlmostEqual(s["distance_home"], d, delta=0.01)
                tier = next(t for t, lo, hi in TIERS if lo <= d < hi)
                self.assertEqual(s["tier"], tier, s)
                by_tier[tier] = by_tier.get(tier, 0) + 1
                self.assertEqual(s["zone"], self.forest_zone(p) if side == "west" else self.pradera_zone(p), s)
                self.assertTrue(bounds["x"][0] <= p[0] <= bounds["x"][1] and bounds["z"][0] <= p[1] <= bounds["z"][1], s)
                self.assertGreater(math.hypot(*p), HUB_R + 3.0, s)
                if side == "west":
                    self.assertFalse(self.forest_safe(p, 3.0), s)
                else:
                    self.assertGreater(math.dist(p, PRADERA_OUTPOST[0]), PRADERA_OUTPOST[1] + 3.0, s)
                self.assertGreaterEqual(s["height"], 0.0)
            self.assertEqual(summary["by_tier"], by_tier)
            for tier in ("Legendaria", "Épica", "Rara", "Común"):
                self.assertGreater(by_tier.get(tier, 0), 0, (side, tier))
        west = seeds["west"]
        kinds = {k: [s for s in west if s["kind"] == k] for k in ("tree_base", "canopy", "log", "nest", "trail_edge")}
        evergreens = [i for i in kept if i["name"] == "FK_Evergreen"]
        self.assertEqual(len(kinds["canopy"]), sum(1 for i in evergreens if not self.forest_safe(shift(xz(i), FOREST_OFFSET), 3.0)))
        self.assertEqual(len(kinds["nest"]), len(self.islands["islands"]))
        self.assertGreaterEqual(len(kinds["trail_edge"]), 20)
        for s in kinds["canopy"]:
            source = next(i for i in kept if i["id"] == s["source"])
            self.assertEqual(xz(s), shift(xz(source), FOREST_OFFSET))
            self.assertAlmostEqual(s["height"], 30.0 * source["scale"] * 0.6, delta=0.01)
        for s in kinds["tree_base"]:
            source = next(i for i in kept if i["id"] == s["source"])
            self.assertAlmostEqual(math.dist(xz(s), shift(xz(source), FOREST_OFFSET)), 4.0, delta=0.01)
        for s in kinds["trail_edge"]:
            route = [tuple(p) for p in self.layout["regions"]["forest"]["route"]["nodes"]]
            self.assertAlmostEqual(polyline_dist(xz(s), route, True), 10.0, delta=0.01)
        east = seeds["east"]
        self.assertGreaterEqual(len(east), 100)
        self.assertEqual(sum(1 for s in east if s["kind"] == "nest"), 1)
        for s in east:
            if s["kind"] == "meadow":
                self.assertGreaterEqual(self.road_dist(xz(s)), ROAD_W / 2 + 3.0 - 1e-6, s)

    def check_everything(self):
        for name in sorted(n for n in dir(RuleChecks) if n.startswith("check_") and n != "check_everything"):
            with self.subTest(check=name):
                getattr(self, name)()


class DefaultSeed(RuleChecks, unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.load()
        cls.layout = json.loads(plan.to_json(plan.generate(plan.DEFAULT_SEED)))

    def test_schema(self):
        self.check_schema()

    def test_regions_and_hub_do_not_overlap(self):
        self.check_regions_and_hub_do_not_overlap()

    def test_forest_rules_moved_with_the_block(self):
        self.check_forest_rules_moved_with_the_block()

    def test_islands_relief_and_hide_spots_are_pure_translations(self):
        self.check_islands_relief_and_hide_spots_are_pure_translations()

    def test_removed_props_are_exactly_those_under_new_roads(self):
        self.check_removed_props_are_exactly_those_under_new_roads()

    def test_ring_road(self):
        self.check_ring_road()

    def test_connectors_join_what_they_say(self):
        self.check_connectors_join_what_they_say()

    def test_hub_stations(self):
        self.check_hub_stations()

    def test_leash_bands(self):
        self.check_leash_bands()

    def test_refugio_sets(self):
        self.check_refugio_sets()

    def test_hooks(self):
        self.check_hooks()

    def test_spawn_seeds(self):
        self.check_spawn_seeds()

    def test_streaming_notes_match_the_flags(self):
        streaming = self.layout["streaming"]
        self.assertTrue(streaming["streaming_enabled"])
        self.assertEqual(streaming["min_radius"], 64)  # WildboundFlags.streamingMinRadius
        self.assertLess(streaming["target_radius_recommended"], 1024)
        self.assertGreaterEqual(streaming["target_radius_recommended"], 2 * HUB_R + 2 * 40.0 + 100.0)
        self.assertEqual(streaming["triangles"]["forest_plan"], self.forest_layout["totals"]["triangles"])
        flags = REPO / "src/wildbound/WildboundFlags.luau"
        if flags.exists():
            self.assertIn("streamingMinRadius = 64", flags.read_text(encoding="utf-8"))

    def test_generation_is_deterministic(self):
        first = plan.to_json(plan.generate(plan.DEFAULT_SEED)).encode("utf-8")
        second = plan.to_json(plan.generate(plan.DEFAULT_SEED)).encode("utf-8")
        self.assertEqual(first, second)
        self.assertNotIn(b"\r", first)

    def test_different_seed_changes_refugios_or_seeds(self):
        other = json.loads(plan.to_json(plan.generate(ALT_SEEDS[0])))
        self.assertNotEqual(other["refugio_sets"], self.layout["refugio_sets"])
        self.assertNotEqual(other["spawn_seeds"]["east"], self.layout["spawn_seeds"]["east"])
        self.assertEqual(other["hub"], self.layout["hub"])  # the hub and the block translation never depend on the seed
        self.assertEqual(other["forest_block"], self.layout["forest_block"])
        self.assertEqual(other["hooks"], self.layout["hooks"])

    def test_committed_json_matches_the_generator(self):
        self.assertTrue(COMMITTED.exists(), COMMITTED)
        fresh = plan.to_json(plan.generate(plan.DEFAULT_SEED)).encode("utf-8")
        self.assertEqual(COMMITTED.read_bytes(), fresh)

    def test_outputs_are_written(self):
        with tempfile.TemporaryDirectory() as tmp:
            written = plan.write_outputs(plan.generate(plan.DEFAULT_SEED), tmp)
            suffixes = {p.suffix for p in written}
            self.assertTrue({".json", ".svg"} <= suffixes)
            for path in written:
                self.assertGreater(path.stat().st_size, 0)
            svg = Path(tmp, plan.LAYOUT_NAME + ".svg").read_text(encoding="utf-8")
            self.assertIn("<svg", svg)
            for needle in ("Legend", "Fog rectangle", "Pradera", "Ring road", "Refugio candidate", "First-steal hook"):
                self.assertIn(needle, svg)


class AlternateSeeds(RuleChecks, unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.load()

    def test_every_rule_holds_for_other_seeds(self):
        for seed in ALT_SEEDS:
            with self.subTest(seed=seed):
                self.layout = json.loads(plan.to_json(plan.generate(seed)))
                self.check_everything()


if __name__ == "__main__":
    unittest.main()

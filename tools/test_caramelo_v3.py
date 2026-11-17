"""Guard for Caramelo v3 (owner request 2026-11-17: new trees, a big chocolate river from ice-cream mountains with a
waterfall, a bridge, a free raft, houses with interiors, a rainbow licorice, the modular cake, cookie platforms on the
lake, a little less light and more sparkles; docs/design/wildbound-caramelo-v3-plan.md).

Run from the project root (isolated mode, no bytecode written):

    python -I -B -m unittest discover -s tools -p test_caramelo_v3.py

Reads the repo only. The Luau suites (WildboundCandyV3Layout_Test, WildboundCandyV3Builder_Test, WildboundCandyRaft_Test,
WildboundCandyAmbience_Test) hold the same rules in Studio; this mirror parses the layout data out of the Luau sources so
the geometry can be checked on a machine without Studio, and guards the one-shot migration tool and the raft's "free,
no purchase" rule.
"""

import math
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
V3_PATH = ROOT / "tools" / "WildboundCandyV3Layout.luau"
LAYOUT_PATH = ROOT / "tools" / "WildboundCandyLayout.luau"
SITES_PATH = ROOT / "src" / "wildbound" / "WildboundPraderaSites.luau"
TRAP_PATH = ROOT / "tools" / "WildboundCandyTrapCake.luau"
TOOL_PATH = ROOT / "tools" / "wildbound-caramelo-v3-migrate.luau"
BUILDER_PATH = ROOT / "tools" / "WildboundCandyV3Builder.luau"
DECOR_JSON = ROOT / "assets" / "exports" / "caramelo-v3" / "decor" / "caramelo-v3-decor-spec.json"
KIT_SPEC = ROOT / "tools" / "WildboundCandyV3KitSpec.luau"
RAFT_PATHS = [
    ROOT / "src" / "wildbound" / "WildboundCandyRaft.luau",
    ROOT / "src" / "wildbound" / "WildboundCandyRaftService.server.luau",
    ROOT / "src" / "wildbound" / "WildboundCandyRaft.client.luau",
]
NUM = r"(-?\d+(?:\.\d+)?)"


def read(path):
    return path.read_text(encoding="utf-8")


def block(text, start):
    """The text of the balanced { ... } that opens at the first brace after `start`."""
    index = text.index(start)
    open_index = text.index("{", index)
    depth = 0
    for position in range(open_index, len(text)):
        if text[position] == "{":
            depth += 1
        elif text[position] == "}":
            depth -= 1
            if depth == 0:
                return text[open_index : position + 1]
    raise AssertionError("unbalanced block " + start)


def floats(match):
    return [float(g) for g in match]


class Geometry:
    def __init__(self):
        v3, layout, sites, trap = read(V3_PATH), read(LAYOUT_PATH), read(SITES_PATH), read(TRAP_PATH)
        self.river = [floats(m) for m in re.findall(r"\{ %s, %s, %s \}" % (NUM, NUM, NUM), block(v3, "V3.RIVER ="))]
        self.pool = floats(re.search(r"V3\.POOL = freeze\(\{ x = %s, z = %s, r = %s \}\)" % (NUM, NUM, NUM), v3).groups())
        self.lake = [floats(m) for m in re.findall(r"x = %s, z = %s, r = %s" % (NUM, NUM, NUM), block(v3, "V3.LAKE ="))]
        b = re.search(r"V3\.BRIDGE = freeze\(\{ x = %s, z = %s, length = %s, ramp = %s, width = %s, deck = %s"
                      % (NUM, NUM, NUM, NUM, NUM, NUM), v3)
        self.bridge = dict(zip(("x", "z", "length", "ramp", "width", "deck"), floats(b.groups())))
        piece = r'id = "(\w+)", asset = "(\w+)", x = %s, z = %s, r = %s' % (NUM, NUM, NUM)
        mountain = r'id = "(\w+)", asset = "(\w+)", x = %s, z = %s, scale = %s, r = %s, height = %s,\s*faceX = %s, faceZ = %s' % ((NUM,) * 7)
        self.mountains = [(m[0], m[1], float(m[2]), float(m[3]), float(m[5]), float(m[4]), float(m[7]), float(m[8]))
                          for m in re.findall(mountain, block(v3, "V3.MOUNTAINS ="))]
        self.houses = [(m[0], m[1], float(m[2]), float(m[3]), float(m[4])) for m in re.findall(piece, block(v3, "V3.HOUSES ="))]
        self.docks = [(m[0],) + tuple(float(v) for v in m[1:]) for m in re.findall(
            r'id = "(\w+)", standX = %s, standZ = %s, tipX = %s, tipZ = %s' % (NUM, NUM, NUM, NUM), block(v3, "V3.DOCKS ="))]
        self.lane = [floats(m) for m in re.findall(r"\{ %s, %s \}" % (NUM, NUM), block(v3, "V3.RAFT ="))]
        self.dock = {k: float(v) for k, v in re.findall(r"(\w+) = %s" % NUM, block(v3, "V3.DOCK ="))}
        gaps = re.search(r"gaps = \{ ([^}]*) \}, gapWidth = %s, sideRamp = %s" % (NUM, NUM), v3)
        self.bridge["gaps"] = [float(v) for v in gaps.group(1).split(",")]
        self.bridge["gapWidth"], self.bridge["sideRamp"] = float(gaps.group(2)), float(gaps.group(3))
        lic = re.search(r"V3\.LICORICE = freeze\(\{ x = %s, z = %s, scale = %s, height = %s, span = %s" % ((NUM,) * 5), v3)
        self.licorice = dict(zip(("x", "z", "scale", "height", "span"), floats(lic.groups())))
        self.licorice["feet"] = [floats(m) for m in re.findall(r"offset = %s, r = %s" % (NUM, NUM), block(v3, "V3.LICORICE ="))]
        cake = re.search(r"V3\.CAKE = freeze\(\{ x = %s, z = %s, scale = %s, r = %s, rampReach = %s, faceX = %s, faceZ = %s"
                         % ((NUM,) * 7), v3)
        self.cake = dict(zip(("x", "z", "scale", "r", "reach", "faceX", "faceZ"), floats(cake.groups())))
        self.platforms = [(m[0], float(m[1]), float(m[2]), float(m[3])) for m in re.findall(
            r'asset = "(\w+)", x = %s, z = %s, r = %s' % (NUM, NUM, NUM), block(v3, "V3.PLATFORMS ="))]
        self.clear = {k: float(v) for k, v in re.findall(r"(\w+) = %s" % NUM, block(v3, "V3.CLEAR ="))}
        wf = re.search(r"V3\.WATERFALL = freeze\(\{ x = %s, z = %s, width = %s, top = %s, faceX = %s, faceZ = %s"
                       % ((NUM,) * 6), v3)
        self.waterfall = dict(zip(("x", "z", "width", "top", "faceX", "faceZ"), floats(wf.groups())))
        # the base layout
        self.half = float(re.search(r"Layout\.HALF = (\d+)", layout).group(1))
        self.path_half = float(re.search(r"Layout\.PATH_WIDTH = (\d+)", layout).group(1)) / 2
        cx, cz = floats(re.search(r"Layout\.CENTRE = point\(%s, %s\)" % (NUM, NUM), layout).groups())
        self.centre = (cx, cz)
        self.routes = {}
        for name, body in re.findall(r"(\w+) = route\(\{(.*?)\}\)\,?\n", layout):
            self.routes[name] = [floats(m) for m in re.findall(r"\{ %s, %s \}" % (NUM, NUM), body)]
        self.nests = {m[0]: (float(m[2]), float(m[3])) for m in re.findall(r'nest\("(\w+)", "(\w+)", %s, %s\)' % (NUM, NUM), layout)}
        boss = re.search(r"Layout\.BOSS = table\.freeze\(\{ x = %s, z = %s, plazaRadius = %s, territoryRadius = %s"
                         % ((NUM,) * 4), layout)
        self.boss = floats(boss.groups())
        self.entrance = floats(re.search(r"Layout\.ENTRANCE = point\(%s, %s\)" % (NUM, NUM), layout).groups())
        self.portal = floats(re.search(r"Layout\.PORTAL = table\.freeze\(\{ x = %s, z = %s" % (NUM, NUM), layout).groups())
        self.keep = [floats(m) for m in re.findall(r"x = %s, z = %s, r = %s, why" % (NUM, NUM, NUM), block(layout, "Layout.KEEP_CLEAR ="))]
        fixed = block(sites, "Sites.FIXED =")
        self.posts = {m[0]: (float(m[1]) - cx, float(m[2]) - cz)
                      for m in re.findall(r"(\w+) = table\.freeze\(\{ x = %s, z = %s \}\)" % (NUM, NUM), fixed)}
        self.traps = [floats(m) for m in re.findall(r'key = "\w+", x = %s, z = %s' % (NUM, NUM), block(trap, "Trap.SPOTS ="))]

    # --- distances ---
    @staticmethod
    def seg(x, z, ax, az, bx, bz):
        dx, dz = bx - ax, bz - az
        length2 = dx * dx + dz * dz
        t = 0.0 if length2 == 0 else max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / length2))
        return math.hypot(x - ax - dx * t, z - az - dz * t)

    def river_distance(self, x, z):
        best = math.inf
        for a, b in zip(self.river, self.river[1:]):
            best = min(best, self.seg(x, z, a[0], a[1], b[0], b[1]) - max(a[2], b[2]) / 2)
        return best

    def liquid_distance(self, x, z):
        best = self.river_distance(x, z)
        best = min(best, math.hypot(x - self.pool[0], z - self.pool[1]) - self.pool[2])
        for d in self.lake:
            best = min(best, math.hypot(x - d[0], z - d[1]) - d[2])
        return best

    def route_distance(self, x, z):
        return min(self.seg(x, z, p[0], p[1], q[0], q[1]) for pts in self.routes.values() for p, q in zip(pts, pts[1:]))

    def depth(self, x, z):
        return self.half - max(abs(x), abs(z))

    def on_bridge(self, x, z, deck_only=False):
        b = self.bridge
        reach = b["length"] / 2 + (0 if deck_only else b["ramp"])
        return abs(z - b["z"]) <= b["width"] / 2 and abs(x - b["x"]) <= reach

    def route_samples(self):
        for name, pts in self.routes.items():
            for p, q in zip(pts, pts[1:]):
                n = max(1, math.ceil(math.hypot(q[0] - p[0], q[1] - p[1]) / 2))
                for s in range(n + 1):
                    yield name, p[0] + (q[0] - p[0]) * s / n, p[1] + (q[1] - p[1]) * s / n

    def solid_pieces(self):
        out = [("mountain " + m[0], m[2], m[3], m[4]) for m in self.mountains]
        out += [("house " + h[0], h[2], h[3], h[4]) for h in self.houses]
        for d in self.docks:
            _, sx, sz, tx, tz = d
            length = math.hypot(tx - sx, tz - sz)
            ux, uz = (tx - sx) / length, (tz - sz) / length
            deck_end = length - self.dock["tipGap"]
            out.append(("dock " + d[0], sx, sz, 3.0))
            out.append(("dock " + d[0] + " ramp", sx - ux * self.dock["rampBack"], sz - uz * self.dock["rampBack"],
                        self.dock["deckWidth"] / 2 + 0.5))
            out.append(("dock " + d[0] + " deck", sx + ux * deck_end / 2, sz + uz * deck_end / 2, self.dock["deckWidth"] / 2))
        lic = self.licorice
        out += [("licorice foot", lic["x"], lic["z"] + side * off * lic["scale"], fr * lic["scale"])
                for off, fr in lic["feet"] for side in (-1, 1)]
        k = self.cake
        yaw = math.atan2(-(k["faceX"] - k["x"]), -(k["faceZ"] - k["z"]))
        mid = (k["r"] + k["reach"]) / 2
        out.append(("cake", k["x"], k["z"], k["r"]))
        out.append(("cake ramp", k["x"] - math.sin(yaw) * mid, k["z"] - math.cos(yaw) * mid, (k["reach"] - k["r"]) / 2 + 2))
        return out

    def kit_point(self, x, z, yaw, scale, X, Z):
        X, Z = X * scale, Z * scale
        return x + X * math.cos(yaw) + Z * math.sin(yaw), z - X * math.sin(yaw) + Z * math.cos(yaw)


class CarameloV3Layout(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.g = Geometry()

    def test_parsed_everything(self):
        g = self.g
        self.assertGreaterEqual(len(g.river), 6)
        self.assertEqual(len(g.lake), 4)
        self.assertEqual(len(g.houses), 7)
        self.assertGreaterEqual(len(g.mountains), 4)
        self.assertEqual(len(g.docks), 2)
        self.assertEqual(len(g.platforms), 4)
        self.assertEqual(set(g.routes), {"main", "left", "right", "deep"})
        self.assertEqual(len(g.nests), 28)
        self.assertGreaterEqual(len(g.posts), 26)
        self.assertEqual(len(g.traps), 3)

    def test_river_runs_from_the_waterfall_pool_into_the_lake_and_is_big(self):
        g = self.g
        first, last = g.river[0], g.river[-1]
        self.assertLessEqual(math.hypot(first[0] - g.pool[0], first[1] - g.pool[1]), g.pool[2] + 1, "starts at the pool's outlet")
        self.assertTrue(any(math.hypot(last[0] - d[0], last[1] - d[1]) < d[2] for d in g.lake), "ends inside the lake")
        length = sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(g.river, g.river[1:]))
        self.assertGreaterEqual(length, 250, "a long river")
        self.assertTrue(all(p[2] >= 20 for p in g.river[1:]), "at least 20 studs wide below the outlet")
        for p in g.river:
            self.assertGreaterEqual(g.depth(p[0], p[1]) - p[2] / 2, 2, "the river leaves the plot at %s" % p[:2])

    def test_the_waterfall_falls_from_the_big_mountain_into_the_pool(self):
        g = self.g
        m1 = [m for m in g.mountains if m[0] == "M1"][0]
        wf = g.waterfall
        self.assertLess(math.hypot(wf["x"] - m1[2], wf["z"] - m1[3]), m1[4], "the sheet stands on the mountain")
        self.assertLess(math.hypot(wf["x"] - g.pool[0], wf["z"] - g.pool[1]), g.pool[2], "it falls into the pool")
        self.assertEqual((wf["faceX"], wf["faceZ"]), (g.pool[0], g.pool[1]))
        self.assertGreaterEqual(wf["top"], 15)

    def test_m1_feeds_the_river_from_the_kit_outlet(self):
        # the kit contract: pool centre, radius, outlet and ledge of CV3_IceCreamMountain_L, scaled and turned like M1
        import json
        g = self.g
        spec = json.loads(DECOR_JSON.read_text(encoding="utf-8"))["assets"]
        m1 = [m for m in g.mountains if m[0] == "M1"][0]
        _, asset, x, z, r, scale, fx, fz = m1
        water = spec[asset]["water"]
        yaw = math.atan2(-(fx - x), -(fz - z))
        ox, oz = g.kit_point(x, z, yaw, scale, -water["outlet"][0], water["outlet"][1])
        px, pz = g.kit_point(x, z, yaw, scale, -water["pool_center"][0], water["pool_center"][1])
        self.assertLess(math.hypot(ox - g.river[0][0], oz - g.river[0][1]), 0.5, "RIVER[1] is M1's outlet")
        self.assertLess(math.hypot(px - g.pool[0], pz - g.pool[1]), 0.5, "POOL is M1's pool")
        self.assertAlmostEqual(g.pool[2], water["pool_radius"] * scale, delta=0.1)
        self.assertLess(abs(g.waterfall["top"] - water["ledge_z"] * scale), 0.5, "the fall starts at the ledge (studs over the floor)")
        size = spec[asset]["size"]
        self.assertGreaterEqual(r, max(size[0], size[1]) / 2 * scale, "the footprint holds the kit")
        for m in g.mountains:
            self.assertIn(m[1], spec, m[0])
        for name in ("CV3_TreeCotton", "CV3_TreeIceCream", "CV3_TreeCaramelApple", "CV3_LicoriceArch", "CV3_CakeBase",
                     "CV3_CakeRamp", "CV3_CakeTop", "CV3_CookieS", "CV3_CookieM", "CV3_CookieL"):
            self.assertIn(name, spec)
        for asset, _, _, rr in g.platforms:
            self.assertAlmostEqual(rr, max(spec[asset]["size"][0], spec[asset]["size"][1]) / 2, delta=0.3, msg=asset)
        lic = spec["CV3_LicoriceArch"]
        self.assertAlmostEqual(g.licorice["span"], lic["size"][0] * g.licorice["scale"], delta=0.5)
        self.assertAlmostEqual(g.licorice["height"], lic["size"][2] * g.licorice["scale"], delta=0.5)

    def test_routes_meet_the_chocolate_only_on_the_bridge(self):
        g = self.g
        for name, x, z in g.route_samples():
            d = g.liquid_distance(x, z)
            if d <= 0:
                self.assertTrue(g.on_bridge(x, z, True), "%s wades at (%.1f, %.1f)" % (name, x, z))
            if d < g.path_half:
                self.assertTrue(g.on_bridge(x, z), "%s's edge wades at (%.1f, %.1f)" % (name, x, z))
        b = g.bridge
        left = g.routes["left"]
        self.assertTrue(any(abs(p[1] - b["z"]) < 1e-6 and abs(q[1] - b["z"]) < 1e-6 and min(p[0], q[0]) <= b["x"] - b["length"] / 2
                            and max(p[0], q[0]) >= b["x"] + b["length"] / 2 for p, q in zip(left, left[1:])),
                        "the deck lies on a straight leg of the left route")
        self.assertGreater(b["width"], g.path_half * 2)

    def test_bridge_opens_for_north_south_crossings(self):
        b = self.g.bridge
        self.assertGreaterEqual(len(b["gaps"]), 3)
        self.assertGreaterEqual(b["gapWidth"], 8)
        for gx in b["gaps"]:
            self.assertLessEqual(abs(gx) + b["gapWidth"] / 2, b["length"] / 2, "a gap past the deck")
        for i, a in enumerate(b["gaps"]):
            for c in b["gaps"][i + 1:]:
                self.assertGreaterEqual(abs(a - c), b["gapWidth"] + 4, "gaps too close")
        rise = b["deck"]
        self.assertLessEqual(math.degrees(math.atan2(rise, b["sideRamp"])), 25, "side ramps walkable")

    def test_nests_posts_traps_boss_portal_entrance_stay_off_the_chocolate(self):
        g, c = self.g, self.g.clear
        for nid, (x, z) in g.nests.items():
            self.assertGreaterEqual(g.liquid_distance(x, z), c["nestFromLiquid"], "nest " + nid)
        for pid, (x, z) in g.posts.items():
            self.assertGreaterEqual(g.liquid_distance(x, z), c["postFromLiquid"], "post " + pid)
        for x, z in g.traps:
            self.assertGreaterEqual(g.liquid_distance(x, z), c["trapFromAnything"], "trap cake")
        bx, bz, plaza, territory = g.boss
        self.assertGreaterEqual(g.liquid_distance(bx, bz), territory, "boss ground")
        self.assertGreaterEqual(g.liquid_distance(*g.portal), 16, "portal")
        self.assertGreaterEqual(g.liquid_distance(*g.entrance), 28, "entrance")
        for x, z, r in g.keep:
            self.assertGreaterEqual(g.liquid_distance(x, z), r, "KEEP_CLEAR")

    def test_solid_pieces_are_clear(self):
        g, c = self.g, self.g.clear
        pieces = g.solid_pieces()
        bx, bz, plaza, territory = g.boss
        for label, x, z, r in pieces:
            for nid, (nx, nz) in g.nests.items():
                self.assertGreaterEqual(math.hypot(x - nx, z - nz) - r, c["pieceFromNest"], "%s on nest %s" % (label, nid))
            for pid, (px, pz) in g.posts.items():
                self.assertGreaterEqual(math.hypot(x - px, z - pz) - r, c["pieceFromPost"], "%s on post %s" % (label, pid))
            for tx, tz in g.traps:
                self.assertGreaterEqual(math.hypot(x - tx, z - tz) - r, c["trapFromAnything"], "%s on a trap cake" % label)
            self.assertGreaterEqual(g.route_distance(x, z) - r - g.path_half, c["pieceFromRoute"], label + " on a route")
            self.assertGreaterEqual(math.hypot(x - bx, z - bz) - r, territory, label + " in the boss territory")
            self.assertGreaterEqual(math.hypot(x - g.portal[0], z - g.portal[1]) - r, 16, label + " at the portal")
            self.assertGreaterEqual(math.hypot(x - g.entrance[0], z - g.entrance[1]) - r, 28, label + " at the entrance")
            for kx, kz, kr in g.keep:
                self.assertGreaterEqual(math.hypot(x - kx, z - kz) - r - kr, c["pieceApart"], label + " in KEEP_CLEAR")
            if label.startswith("mountain"):
                self.assertGreaterEqual(g.depth(x, z), r - 0.5, label + " leaves the plot")
            else:
                self.assertGreaterEqual(g.depth(x, z) - r, c["edgeDepth"], label + " by the plot edge")
            if not (label == "mountain M1" or label.startswith("dock")):
                self.assertGreaterEqual(g.liquid_distance(x, z) - r, c["pieceApart"], label + " in the chocolate")
        for i, a in enumerate(pieces):
            for b in pieces[i + 1:]:
                if a[0].startswith("cake") and b[0].startswith("cake"):
                    continue  # the ramp is built against the base
                if a[0].startswith("dock") and a[0].split()[:2] == b[0].split()[:2]:
                    continue  # one dock's stand, ramp and deck
                self.assertGreaterEqual(math.hypot(a[1] - b[1], a[2] - b[2]) - a[3] - b[3], c["pieceApart"], a[0] + " / " + b[0])

    def test_houses_several_places_with_three_kinds(self):
        g = self.g
        self.assertTrue(5 <= len(g.houses) <= 7)
        self.assertEqual({h[1] for h in g.houses}, {"CV3_SweetHouse", "CV3_ChocoHouse", "CV3_CaramelTower"})
        quadrants = {(h[2] > 0, h[3] > 0) for h in g.houses}
        self.assertEqual(len(quadrants), 4, "houses in every quarter of the plot")

    def test_docks_stand_on_both_banks_and_the_lane_floats(self):
        g = self.g
        (a, ax, az, atx, atz), (b, bx, bz, btx, btz) = g.docks
        for label, x, z in (("stand A", ax, az), ("stand B", bx, bz)):
            self.assertGreater(g.liquid_distance(x, z), 0, label + " on land")
        for label, x, z in (("tip A", atx, atz), ("tip B", btx, btz)):
            self.assertLess(g.liquid_distance(x, z), -2, label + " over the river")
        # opposite banks: the stands lie on opposite sides of the river's first leg
        p, q = g.river[0], g.river[1]

        def side(x, z):
            return (q[0] - p[0]) * (z - p[1]) - (q[1] - p[1]) * (x - p[0])

        self.assertLess(side(ax, az) * side(bx, bz), 0, "both banks")
        self.assertEqual((g.lane[0][0], g.lane[0][1]), (atx, atz), "the lane starts at tip A")
        self.assertEqual((g.lane[-1][0], g.lane[-1][1]), (btx, btz), "the lane ends at tip B")
        for a2, b2 in zip(g.lane, g.lane[1:]):
            for s in range(11):
                x, z = a2[0] + (b2[0] - a2[0]) * s / 10, a2[1] + (b2[1] - a2[1]) * s / 10
                self.assertLess(g.liquid_distance(x, z), -1.5, "the lane floats at (%.1f, %.1f)" % (x, z))

    def test_licorice_spans_the_main_path_and_platforms_float(self):
        g = self.g
        lic = g.licorice
        self.assertLess(g.route_distance(lic["x"], lic["z"]), 0.01, "centred on a route")
        inner = min(off * lic["scale"] - fr * lic["scale"] for off, fr in lic["feet"])
        self.assertGreaterEqual(inner - g.path_half, 4, "feet clear the path")
        self.assertGreaterEqual(lic["height"], 18)
        for asset, x, z, r in g.platforms:
            self.assertTrue(any(math.hypot(x - d[0], z - d[1]) + r <= d[2] for d in g.lake), asset + " inside the lake")
            self.assertGreater(abs(z - g.bridge["z"]) - r, g.bridge["width"] / 2 + g.bridge["sideRamp"], asset + " on the bridge's side ramps")
        for i, a in enumerate(g.platforms):
            for b in g.platforms[i + 1:]:
                self.assertGreaterEqual(math.hypot(a[1] - b[1], a[2] - b[2]) - a[3] - b[3], 2)


class CarameloV3Sources(unittest.TestCase):
    def test_migration_tool_starts_dry_backs_up_archives_and_never_destroys(self):
        tool = read(TOOL_PATH)
        self.assertRegex(tool, r"(?m)^local DRY_RUN = true\b")
        for needle in ("CaramelV3Backup", "CaramelV3Archived", "TryBeginRecording", "FinishRecordingOperation.Cancel",
                       'FindFirstAncestor("SistemaSonriente")', "RunService:IsRunning()", "WildboundCaramelV3Summary",
                       "Layout.VERSION == 3", "V3.MARK"):
            self.assertIn(needle, tool)
        self.assertGreater(tool.index("TryBeginRecording"), tool.index("task.delay("))
        # review M2 and m1-m4: the kit-upgrade mode, the post check, the dry-run estimate, the backup warning, fresh modules
        self.assertRegex(tool, r'(?m)^local MODE = "first"')
        for needle in ("V3Builder.upgradePlaceholders", "creature posts: refusing", "summary.partsEstimate", "summary.warning",
                       "require(found:Clone())"):
            self.assertIn(needle, tool)
        self.assertNotIn("archiving CaramelV3 and running again", tool)
        self.assertNotRegex(tool, r":Destroy\(\)")

    def test_builder_uses_the_layout_and_falls_back_to_placeholders(self):
        builder = read(BUILDER_PATH)
        for name in ("function V3Builder.layAll", "function V3Builder.plan", "function V3Builder.swapTrees",
                     "function V3Builder.kitModel", "Placeholder", "function V3Builder.upgradePlaceholders",
                     "function V3Builder.existingProps", "V3.BEAST_PASS_TAG", "V3.BEAST_OVERHEAD_TAG", "SideRamp_"):
            self.assertIn(name, builder)
        self.assertNotIn("SistemaSonriente\"", builder.replace('"SistemaSonriente"', ""))

    def test_raft_is_free(self):
        for path in RAFT_PATHS:
            text = read(path)
            for banned in ("MarketplaceService", "PromptProductPurchase", "PromptPurchase", "ProcessReceipt", "Robux", "DevProduct"):
                self.assertNotIn(banned, text, "%s mentions %s" % (path.name, banned))


if __name__ == "__main__":
    unittest.main()

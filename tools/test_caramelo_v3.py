"""Guard for Caramelo v3 and v4 (owner requests 2026-11-17: new trees, a big chocolate river from ice-cream mountains
with a waterfall, bridges, a free raft, houses with interiors, a rainbow licorice, the modular cake, cookie platforms on
the lake; v4: the river as a north-south barrier before the cake, deeper chocolate, bigger trees and houses, no yellow
crystals, fuller sides; docs/design/wildbound-caramelo-v3-plan.md).

Run from the project root (isolated mode, no bytecode written):

    python -I -B -m unittest discover -s tools -p test_caramelo_v3.py

Reads the repo only. The Luau suites (WildboundCandyV3Layout_Test, WildboundCandyV3Builder_Test, WildboundCandyRaft_Test,
WildboundCandyAmbience_Test) hold the same rules in Studio; this mirror parses the layout data out of the Luau sources so
the geometry can be checked on a machine without Studio, and guards the one-shot migration tools and the raft's "free,
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
BIOMES_PATH = ROOT / "src" / "wildbound" / "WildboundBiomes.luau"
TRAP_PATH = ROOT / "tools" / "WildboundCandyTrapCake.luau"
TOOL_PATH = ROOT / "tools" / "wildbound-caramelo-v3-migrate.luau"
TOOL_V4_PATH = ROOT / "tools" / "wildbound-caramelo-v4-migrate.luau"
TOOL_V5_PATH = ROOT / "tools" / "wildbound-caramelo-v5-migrate.luau"
BUILDER_PATH = ROOT / "tools" / "WildboundCandyV3Builder.luau"
OLD_BUILDER_PATH = ROOT / "tools" / "WildboundCandyBuilder.luau"
DECOR_JSON = ROOT / "assets" / "exports" / "caramelo-v3" / "decor" / "caramelo-v3-decor-spec.json"
KIT_SPEC = ROOT / "tools" / "WildboundCandyV3KitSpec.luau"
RAFT_PATHS = [
    ROOT / "src" / "wildbound" / "WildboundCandyRaft.luau",
    ROOT / "src" / "wildbound" / "WildboundCandyRaftService.server.luau",
    ROOT / "src" / "wildbound" / "WildboundCandyRaft.client.luau",
]
NUM = r"(-?\d+(?:\.\d+)?)"
HOUSE_BASE_R = {"CV3_SweetHouse": 20, "CV3_ChocoHouse": 16, "CV3_CaramelTower": 15}


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


def rect_corners(b):
    a = b["length"] / 2 + b["ramp"]
    c = b["width"] / 2 + (b["sideRamp"] if b["gaps"] else 0)
    ux, uz = b["ux"], b["uz"]
    return [(b["x"] + sa * a * ux - sc * c * uz, b["z"] + sa * a * uz + sc * c * ux)
            for sa, sc in ((-1, -1), (1, -1), (1, 1), (-1, 1))]


def rects_overlap(p, q):
    """Separating-axis test of two convex quads."""
    for poly in (p, q):
        for i in range(4):
            ax, az = poly[i]
            bx, bz = poly[(i + 1) % 4]
            nx, nz = -(bz - az), bx - ax
            pa = [nx * x + nz * z for x, z in p]
            qa = [nx * x + nz * z for x, z in q]
            if max(pa) < min(qa) or max(qa) < min(pa):
                return False
    return True


class Geometry:
    def __init__(self):
        v3, layout, sites, trap = read(V3_PATH), read(LAYOUT_PATH), read(SITES_PATH), read(TRAP_PATH)
        self.river = [floats(m) for m in re.findall(r"\{ %s, %s, %s \}" % (NUM, NUM, NUM), block(v3, "V3.RIVER ="))]
        self.pool = floats(re.search(r"V3\.POOL = freeze\(\{ x = %s, z = %s, r = %s \}\)" % (NUM, NUM, NUM), v3).groups())
        self.lake = [floats(m) for m in re.findall(r"x = %s, z = %s, r = %s" % (NUM, NUM, NUM), block(v3, "V3.LAKE ="))]
        self.depth_liquid = float(re.search(r"V3\.LIQUID = freeze\(\{ depth = %s" % NUM, v3).group(1))
        build = {k: float(v) for k, v in re.findall(r"(\w+) = %s" % NUM, block(v3, "V3.BRIDGE_BUILD ="))}
        self.bridges = []
        for m in re.findall(r'id = "(\w+)", route = "(\w+)", from = \{ %s, %s \}, to = \{ %s, %s \}, at = %s, length = %s, gaps = \{([^}]*)\}'
                            % ((NUM,) * 6), block(v3, "local BRIDGE_ROWS =")):
            fx, fz, tx, tz, at, length = (float(v) for v in m[2:8])
            leg = math.hypot(tx - fx, tz - fz)
            ux, uz = (tx - fx) / leg, (tz - fz) / leg
            b = dict(build)
            b.update(id=m[0], route=m[1], frm=(fx, fz), to=(tx, tz), at=at, length=length, leg=leg, ux=ux, uz=uz,
                     x=fx + ux * at, z=fz + uz * at,
                     gaps=[float(v) for v in m[8].split(",") if v.strip()])
            self.bridges.append(b)
        piece = r'id = "(\w+)", asset = "(\w+)", x = %s, z = %s, r = %s' % (NUM, NUM, NUM)
        mountain = r'id = "(\w+)", asset = "(\w+)", x = %s, z = %s, scale = %s, r = %s, height = %s,\s*faceX = %s, faceZ = %s' % ((NUM,) * 7)
        self.mountains = [(m[0], m[1], float(m[2]), float(m[3]), float(m[5]), float(m[4]), float(m[7]), float(m[8]))
                          for m in re.findall(mountain, block(v3, "V3.MOUNTAINS ="))]
        self.houses = [(m[0], m[1], float(m[2]), float(m[3]), float(m[4]), float(m[5])) for m in re.findall(
            piece + r", scale = %s" % NUM, block(v3, "V3.HOUSES ="))]
        self.docks = [(m[0],) + tuple(float(v) for v in m[1:]) for m in re.findall(
            r'id = "(\w+)", standX = %s, standZ = %s, tipX = %s, tipZ = %s' % (NUM, NUM, NUM, NUM), block(v3, "V3.DOCKS ="))]
        self.raft = block(v3, "V3.RAFT =")
        self.turns = {m[0]: float(m[1]) for m in re.findall(r'id = "(\w+)",[^\n]*turn = %s' % NUM, block(v3, "V3.HOUSES ="))}
        self.dock = {k: float(v) for k, v in re.findall(r"(\w+) = %s" % NUM, block(v3, "V3.DOCK ="))}
        lic = re.search(r"V3\.LICORICE = freeze\(\{ x = %s, z = %s, scale = %s, height = %s, span = %s" % ((NUM,) * 5), v3)
        self.licorice = dict(zip(("x", "z", "scale", "height", "span"), floats(lic.groups())))
        self.licorice["feet"] = [floats(m) for m in re.findall(r"offset = %s, r = %s" % (NUM, NUM), block(v3, "V3.LICORICE ="))]
        cake = re.search(r"V3\.CAKE = freeze\(\{ x = %s, z = %s, scale = %s, r = %s, rampReach = %s, faceX = %s, faceZ = %s"
                         % ((NUM,) * 7), v3)
        self.cake = dict(zip(("x", "z", "scale", "r", "reach", "faceX", "faceZ"), floats(cake.groups())))
        self.platforms = [(m[0], float(m[1]), float(m[2]), float(m[3])) for m in re.findall(
            r'asset = "(\w+)", x = %s, z = %s, r = %s' % (NUM, NUM, NUM), block(v3, "V3.PLATFORMS ="))]
        self.platform = {k: float(v) for k, v in re.findall(r"(\w+) = %s" % NUM, block(v3, "V3.PLATFORM ="))}
        # V6-D4: the lake's islands (dry land inside the waterline r) and their build
        self.islands = [dict(id=m[0], x=float(m[1]), z=float(m[2]), r=float(m[3]), flat=float(m[4]), foot=float(m[5]))
                        for m in re.findall(r'id = "(\w+)", x = %s, z = %s, r = %s, flat = %s, foot = %s' % ((NUM,) * 5),
                                            block(v3, "V3.ISLANDS ="))]
        self.island = {k: float(v) for k, v in re.findall(r"(\w+) = %s" % NUM, block(v3, "V3.ISLAND ="))}
        self.clear = {k: float(v) for k, v in re.findall(r"(\w+) = %s" % NUM, block(v3, "V3.CLEAR ="))}
        wf = re.search(r"V3\.WATERFALL = freeze\(\{ x = %s, z = %s, width = %s, top = %s, faceX = %s, faceZ = %s"
                       % ((NUM,) * 6), v3)
        self.waterfall = dict(zip(("x", "z", "width", "top", "faceX", "faceZ"), floats(wf.groups())))
        self.trees = {k: float(v) for k, v in re.findall(r"(heightFactor|minFactor) = %s" % NUM, block(v3, "V3.TREES ="))}
        self.crystal_hills = [(m[0], float(m[1]), float(m[2]), float(m[3]), float(m[4])) for m in re.findall(
            r'id = "(\w+)", x = %s, z = %s, scale = %s, r = %s' % ((NUM,) * 4), block(v3, "V3.CRYSTAL_HILLS ="))]
        self.backdrop = [(m[0], float(m[1]), float(m[2]), float(m[3]), float(m[4])) for m in re.findall(
            r'asset = "(\w+)", x = %s, z = %s, scale = %s, r = %s' % ((NUM,) * 4), block(v3, "V3.BACKDROP ="))]
        self.edge = {k: float(v) for k, v in re.findall(r"(\w+) = %s" % NUM, block(v3, "V3.EDGE ="))}
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
        self.biomes = [(m[0], float(m[1]), float(m[2]), float(m[3]), float(m[4])) for m in re.findall(
            r'square\("(\w+)", "[\w-]+", %s, %s, %s, %s\)' % ((NUM,) * 4), read(BIOMES_PATH))]

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

    def water_distance(self, x, z):
        """The chocolate without the islands (river, pool, lake discs)."""
        best = self.river_distance(x, z)
        best = min(best, math.hypot(x - self.pool[0], z - self.pool[1]) - self.pool[2])
        for d in self.lake:
            best = min(best, math.hypot(x - d[0], z - d[1]) - d[2])
        return best

    def island_distance(self, x, z):
        return min((math.hypot(x - i["x"], z - i["z"]) - i["r"] for i in self.islands), default=math.inf)

    def liquid_distance(self, x, z):
        # V6-D4: an island is dry land inside its waterline
        return max(self.water_distance(x, z), -self.island_distance(x, z))

    def route_distance(self, x, z):
        return min(self.seg(x, z, p[0], p[1], q[0], q[1]) for pts in self.routes.values() for p, q in zip(pts, pts[1:]))

    def depth(self, x, z):
        return self.half - max(abs(x), abs(z))

    @staticmethod
    def frame(b, x, z):
        dx, dz = x - b["x"], z - b["z"]
        return dx * b["ux"] + dz * b["uz"], -dx * b["uz"] + dz * b["ux"]

    def on_bridge(self, x, z, deck_only=False):
        for b in self.bridges:
            along, across = self.frame(b, x, z)
            if abs(across) <= b["width"] / 2 and abs(along) <= b["length"] / 2 + (0 if deck_only else b["ramp"]):
                return True
        return False

    def near_bridge(self, x, z, reach=0):
        for b in self.bridges:
            along, across = self.frame(b, x, z)
            side = b["sideRamp"] if b["gaps"] else 0
            if abs(across) <= b["width"] / 2 + side + reach and abs(along) <= b["length"] / 2 + b["ramp"] + reach:
                return True
        return False

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

    def open_disc(self, label, x, z, r, test, pieces=True):
        """The clearances of a solid disc: nests, posts, trap cakes, routes, the boss territory, the portal, the
        entrance, KEEP_CLEAR, the chocolate and (optionally) every v3 piece."""
        g, c = self, self.clear
        for nid, (nx, nz) in g.nests.items():
            test.assertGreaterEqual(math.hypot(x - nx, z - nz) - r, c["pieceFromNest"], "%s on nest %s" % (label, nid))
        for pid, (px, pz) in g.posts.items():
            test.assertGreaterEqual(math.hypot(x - px, z - pz) - r, c["pieceFromPost"], "%s on post %s" % (label, pid))
        for tx, tz in g.traps:
            test.assertGreaterEqual(math.hypot(x - tx, z - tz) - r, c["trapFromAnything"], "%s on a trap cake" % label)
        test.assertGreaterEqual(g.route_distance(x, z) - r - g.path_half, c["pieceFromRoute"], label + " on a route")
        bx, bz, _, territory = g.boss
        test.assertGreaterEqual(math.hypot(x - bx, z - bz) - r, territory, label + " in the boss territory")
        test.assertGreaterEqual(math.hypot(x - g.portal[0], z - g.portal[1]) - r, 16, label + " at the portal")
        test.assertGreaterEqual(math.hypot(x - g.entrance[0], z - g.entrance[1]) - r, 28, label + " at the entrance")
        for kx, kz, kr in g.keep:
            test.assertGreaterEqual(math.hypot(x - kx, z - kz) - r - kr, c["pieceApart"], label + " in KEEP_CLEAR")
        test.assertGreaterEqual(g.liquid_distance(x, z) - r, c["pieceApart"], label + " in the chocolate")
        test.assertFalse(g.near_bridge(x, z, r), label + " on a bridge")
        if pieces:
            for plabel, px, pz, pr in g.solid_pieces():
                test.assertGreaterEqual(math.hypot(x - px, z - pz) - r - pr, c["pieceApart"], label + " on " + plabel)


class CarameloV3Layout(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.g = Geometry()

    def test_parsed_everything(self):
        g = self.g
        self.assertGreaterEqual(len(g.river), 6)
        # Deliberately changed (V4): the lake is reshaped round the new river (two discs)
        self.assertGreaterEqual(len(g.lake), 1)
        self.assertEqual(len(g.houses), 7)
        self.assertGreaterEqual(len(g.mountains), 4)
        self.assertEqual(len(g.docks), 2)
        self.assertEqual(len(g.platforms), 4)
        self.assertEqual(set(g.routes), {"main", "left", "right", "deep"})
        self.assertEqual(len(g.nests), 28)
        self.assertGreaterEqual(len(g.posts), 26)
        self.assertEqual(len(g.traps), 3)
        self.assertEqual(len(g.bridges), 5)
        self.assertEqual(len(g.crystal_hills), 6)
        self.assertGreaterEqual(len(g.backdrop), 6)

    # Deliberately changed (V4): the river is born at M1's pool by the north edge and leaves at the south edge (V4-D1);
    # it was a south-band river into the lake, at least 20 wide and inside the plot.
    def test_river_runs_from_the_waterfall_pool_through_the_lake_to_the_south_edge(self):
        g = self.g
        first, last = g.river[0], g.river[-1]
        self.assertLessEqual(math.hypot(first[0] - g.pool[0], first[1] - g.pool[1]), g.pool[2] + 1, "starts at the pool's outlet")
        self.assertTrue(any(g.seg(d[0], d[1], a[0], a[1], b[0], b[1]) < d[2] for d in g.lake for a, b in zip(g.river, g.river[1:])),
                        "runs through the lake")
        self.assertAlmostEqual(g.depth(last[0], last[1]), 0, delta=0.01, msg="ends on the plot edge")
        self.assertLess(last[1], 0, "the south edge")
        m1 = [m for m in g.mountains if m[0] == "M1"][0]
        self.assertGreater(m1[3], 0, "M1 by the north edge")
        self.assertGreaterEqual(m1[3] + m1[4], g.half - 0.5, "M1's footprint touches the north edge")
        length = sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(g.river, g.river[1:]))
        self.assertGreaterEqual(length, 340, "a long river")
        self.assertTrue(all(p[2] >= 10 for p in g.river[1:]), "at least 10 studs wide below the outlet (round the junction)")
        self.assertGreaterEqual(max(p[2] for p in g.river), 20, "wide where the raft sails")
        for p in g.river[:-1]:
            self.assertGreaterEqual(g.depth(p[0], p[1]) - p[2] / 2, 2, "the river leaves the plot at %s" % p[:2])

    def test_the_river_is_a_barrier_west_of_the_cake(self):
        # V4-D1: every west-to-east line across the plot meets the chocolate (or M1, the source, standing on the north
        # edge), so every walk from the west half to the cake wades or takes a bridge.
        g = self.g
        m1 = [m for m in g.mountains if m[0] == "M1"][0]
        bx, bz, _, territory = g.boss
        for zi in range(-200, 201, 2):
            z = float(zi)
            if abs(z - m1[3]) <= m1[4] and g.depth(m1[2], m1[3]) <= m1[4] + 0.5:
                continue
            wet = [x for x in range(-200, 201) if g.liquid_distance(x, z) < 0]
            self.assertTrue(wet, "a dry line at z %s" % z)
            self.assertLess(min(wet), bx - territory + 1, "the chocolate at z %s is not west of the cake" % z)

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
        self.assertEqual((fx, fz), (g.river[1][0], g.river[1][1]), "M1 faces RIVER[2]")
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
        # V4-D6/D7: the pink hills and the backdrop hold their kit
        for hid, _, _, sc, rr in g.crystal_hills:
            self.assertGreaterEqual(rr, max(spec["CV3_IceCreamMountain_M"]["size"][:2]) / 2 * sc - 0.1, hid)
        for asset, _, _, sc, rr in g.backdrop:
            self.assertGreaterEqual(rr, max(spec[asset]["size"][:2]) / 2 * sc - 0.1, asset)

    # Deliberately changed (V4): a list of bridges, one on every route leg the river crosses (was the single BRIDGE).
    def test_routes_meet_the_chocolate_only_on_a_bridge(self):
        g = self.g
        for name, x, z in g.route_samples():
            d = g.liquid_distance(x, z)
            if d <= 0:
                self.assertTrue(g.on_bridge(x, z, True), "%s wades at (%.1f, %.1f)" % (name, x, z))
            if d < g.path_half:
                self.assertTrue(g.on_bridge(x, z), "%s's edge wades at (%.1f, %.1f)" % (name, x, z))
        crossed = set()
        for b in g.bridges:
            pts = g.routes[b["route"]]
            legs = list(zip(pts, pts[1:]))
            self.assertIn((list(b["frm"]), list(b["to"])), [(list(p), list(q)) for p, q in legs], b["id"] + " on a route leg")
            self.assertGreaterEqual(b["at"] - b["length"] / 2 - b["ramp"], -1e-6, b["id"] + " past its leg's start")
            self.assertLessEqual(b["at"] + b["length"] / 2 + b["ramp"], b["leg"] + 1e-6, b["id"] + " past its leg's end")
            self.assertGreater(b["width"], g.path_half * 2)
            self.assertLess(g.liquid_distance(b["x"], b["z"]), 0, b["id"] + " stands over the chocolate")
            crossed.add(b["route"])
        self.assertEqual(crossed, {"main", "left", "right"}, "the main avenue's, the left route's and the right route's")

    def test_bridges_stand_over_the_deeper_chocolate_and_are_walkable(self):
        g = self.g
        self.assertEqual(g.depth_liquid, 3.5, "V4-D2: 3.5 studs deep")
        for b in g.bridges:
            self.assertGreaterEqual(b["deck"], g.depth_liquid + 0.6 - 1e-9, b["id"] + " deck 0.6 over the surface")
            self.assertLessEqual(math.degrees(math.atan2(b["deck"], b["ramp"])), 25, b["id"] + " end ramps")
            self.assertLessEqual(math.degrees(math.atan2(b["deck"], b["sideRamp"])), 25, b["id"] + " side ramps")
        for i, a in enumerate(g.bridges):
            for c in g.bridges[i + 1:]:
                self.assertFalse(rects_overlap(rect_corners(a), rect_corners(c)), "bridges %s and %s overlap" % (a["id"], c["id"]))
        d = g.dock
        self.assertLessEqual(math.degrees(math.atan2(g.depth_liquid + d["deckOver"], d["rampBack"] - 1.5)), 25, "dock ramps walkable")

    def test_bridge_gaps_open_for_crossings_off_the_posts(self):
        for b in self.g.bridges:
            self.assertGreaterEqual(b["gapWidth"], 8)
            for gx in b["gaps"]:
                self.assertLessEqual(abs(gx) + b["gapWidth"] / 2, b["length"] / 2, "a gap past the deck")
            for i, a in enumerate(b["gaps"]):
                for c in b["gaps"][i + 1:]:
                    self.assertGreaterEqual(abs(a - c), b["gapWidth"] + 4, "gaps too close")
            # V3-D25: no side ramp on a creature post
            for gx in b["gaps"]:
                for s in (-1, 1):
                    for pid, (px, pz) in self.g.posts.items():
                        along, across = self.g.frame(b, px, pz)
                        da = max(abs(along - gx) - b["gapWidth"] / 2, 0)
                        lo, hi = sorted((s * b["width"] / 2, s * (b["width"] / 2 + b["sideRamp"])))
                        dc = max(lo - across, 0, across - hi)
                        self.assertGreaterEqual(math.hypot(da, dc), 6, "%s side ramp at gap %s on post %s" % (b["id"], gx, pid))
        self.assertTrue(any(b["gaps"] for b in self.g.bridges), "some bridge opens for waders")

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
            if not label.startswith("dock"):
                self.assertFalse(g.near_bridge(x, z, r), label + " on a bridge")
        for i, a in enumerate(pieces):
            for b in pieces[i + 1:]:
                if a[0].startswith("cake") and b[0].startswith("cake"):
                    continue  # the ramp is built against the base
                if a[0].startswith("dock") and a[0].split()[:2] == b[0].split()[:2]:
                    continue  # one dock's stand, ramp and deck
                self.assertGreaterEqual(math.hypot(a[1] - b[1], a[2] - b[2]) - a[3] - b[3], c["pieceApart"], a[0] + " / " + b[0])

    def test_houses_several_places_with_three_kinds_three_bigger(self):
        g = self.g
        self.assertTrue(5 <= len(g.houses) <= 7)
        self.assertEqual({h[1] for h in g.houses}, {"CV3_SweetHouse", "CV3_ChocoHouse", "CV3_CaramelTower"})
        quadrants = {(h[2] > 0, h[3] > 0) for h in g.houses}
        self.assertEqual(len(quadrants), 4, "houses in every quarter of the plot")
        # V4-D5: H1, H3 and H5 (one of each kind) at 1.4, their footprints scaled with them
        big = {h[0]: h for h in g.houses if h[5] > 1}
        self.assertEqual(set(big), {"H1", "H3", "H5"})
        self.assertEqual({h[1] for h in big.values()}, {"CV3_SweetHouse", "CV3_ChocoHouse", "CV3_CaramelTower"})
        for h in g.houses:
            self.assertIn(h[5], (1.0, 1.4), h[0])
            self.assertAlmostEqual(h[4], HOUSE_BASE_R[h[1]] * h[5], delta=0.05, msg=h[0] + " footprint")

    def test_towers_turn_their_balcony_to_the_kingdom_and_every_door_has_an_approach(self):
        # V4-D15: the caramel towers (balcony at the kit's +Z) are turned 180 degrees, so the balcony looks at the
        # junction and the door (-Z) faces away; every door keeps a clear approach inside the plot.
        g = self.g
        for h in g.houses:
            hid, asset, x, z, r, scale = h
            turn = g.turns.get(hid, 0)
            self.assertEqual(turn, 180 if asset == "CV3_CaramelTower" else 0, hid + " turn")
            length = math.hypot(x, z)
            sign = -1 if turn == 180 else 1
            lx, lz = -x / length * sign, -z / length * sign  # where the door looks
            dx, dz = x + lx * (r + 4), z + lz * (r + 4)
            self.assertGreaterEqual(g.depth(dx, dz), 5, hid + "'s door faces the plot edge")
            self.assertGreaterEqual(g.liquid_distance(dx, dz), 4, hid + "'s door faces the chocolate")
            for label, px, pz, pr in g.solid_pieces():
                if label != "house " + hid:
                    self.assertGreaterEqual(math.hypot(dx - px, dz - pz) - pr, 4, hid + "'s door faces " + label)

    # Deliberately changed (V4): the raft is steered (V4-D3), so there is no lane; each dock tip has 6 studs of chocolate
    # round it, off every bridge, and the two docks stand on opposite banks of an open stretch.
    def test_docks_stand_on_both_banks_with_open_chocolate_at_the_tips(self):
        g = self.g
        (a, ax, az, atx, atz), (b, bx, bz, btx, btz) = g.docks
        for label, x, z in (("stand A", ax, az), ("stand B", bx, bz)):
            self.assertGreater(g.liquid_distance(x, z), 0, label + " on land")
        for label, x, z in (("tip A", atx, atz), ("tip B", btx, btz)):
            self.assertLessEqual(g.liquid_distance(x, z), -6, label + " in open chocolate")
            self.assertFalse(g.near_bridge(x, z, 6), label + " by a bridge")
        wet = [s for s in range(1, 100) if g.liquid_distance(ax + (bx - ax) * s / 100, az + (bz - az) * s / 100) < 0]
        self.assertTrue(wet, "the docks are on the same bank")
        self.assertNotIn("lane", g.raft)
        self.assertIn("homeDock = 1", g.raft)

    def test_licorice_spans_the_main_path_and_platforms_float(self):
        g = self.g
        lic = g.licorice
        self.assertLess(g.route_distance(lic["x"], lic["z"]), 0.01, "centred on a route")
        inner = min(off * lic["scale"] - fr * lic["scale"] for off, fr in lic["feet"])
        self.assertGreaterEqual(inner - g.path_half, 4, "feet clear the path")
        self.assertGreaterEqual(lic["height"], 18)
        for asset, x, z, r in g.platforms:
            self.assertTrue(any(math.hypot(x - d[0], z - d[1]) + r <= d[2] for d in g.lake), asset + " inside the lake")
            # Deliberately changed (V4): off every bridge
            self.assertFalse(g.near_bridge(x, z, r), asset + " on a bridge")
        for i, a in enumerate(g.platforms):
            for b in g.platforms[i + 1:]:
                self.assertGreaterEqual(math.hypot(a[1] - b[1], a[2] - b[2]) - a[3] - b[3], 2)
        self.assertGreater(g.platform["over"], 0, "V4-D2: the walk tops over the surface")

    def test_trees_are_taller(self):
        self.assertEqual(self.g.trees["heightFactor"], 1.35, "V4-D4")
        self.assertLess(self.g.trees["minFactor"], 1)

    def test_pink_hills_stand_at_the_crystal_spots(self):
        g = self.g
        for hid, x, z, scale, r in g.crystal_hills:
            self.assertEqual(x, 198, hid + " at the crystals' x")
            self.assertGreater(scale, 0.2, hid)
            g.open_disc(hid, x, z, r, self)
        for i, a in enumerate(g.crystal_hills):
            for b in g.crystal_hills[i + 1:]:
                self.assertGreaterEqual(math.hypot(a[1] - b[1], a[2] - b[2]) - a[4] - b[4], 2, a[0] + " / " + b[0])

    def test_backdrop_stands_outside_the_east_edge_and_off_other_biomes(self):
        g = self.g
        cx, cz = g.centre
        for asset, x, z, scale, r in g.backdrop:
            self.assertGreater(x, g.half, asset + " east of the plot")
            dx, dz = max(abs(x) - g.half, 0), max(abs(z) - g.half, 0)
            self.assertGreaterEqual(math.hypot(dx, dz), r, "%s at (%s, %s) reaches into the plot" % (asset, x, z))
            wx, wz = cx + x, cz + z
            for tag, minx, maxx, minz, maxz in g.biomes:
                if tag == "Meadow":
                    continue
                ex = max(minx - wx, 0, wx - maxx)
                ez = max(minz - wz, 0, wz - maxz)
                self.assertGreaterEqual(math.hypot(ex, ez), r, "%s reaches into the %s square" % (asset, tag))

    # V5-D3, V5-D10 to V5-D13: a wider river, a bigger lake, longer Top and Bottom bridges, the docks on the new banks.
    def test_v5_wider_river_bigger_lake_longer_bridges(self):
        g = self.g
        v3 = read(V3_PATH)
        self.assertRegex(v3, r"(?m)^V3\.VERSION = 3$")
        self.assertIn('V3.V5_MARK = "CaramelV5"', v3)
        widths = [p[2] for p in g.river]
        self.assertGreaterEqual(sum(1 for w in widths if w >= 24), 10, "24 wide on the open legs")
        legs = sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(g.river, g.river[1:]) if min(a[2], b[2]) >= 24)
        self.assertGreaterEqual(legs, 180, "at least 180 studs of the river are 24 wide")
        # the junction arc stays 10 wide (its three short bridges), and so does every river point near the junction
        for p in g.river:
            if math.hypot(p[0], p[1]) <= 31:
                self.assertEqual(p[2], 10, "the junction arc at %s" % p[:2])
        self.assertEqual(len(g.lake), 2)
        self.assertGreaterEqual(g.lake[0][2], 34, "the big disc grew (was 30)")
        self.assertGreaterEqual(g.lake[1][2], 18, "the second disc grew (was 12)")
        open_water = sum(1 for x in range(-60, 80) for z in range(-150, -20)
                         if g.liquid_distance(x + 0.5, z + 0.5) <= -3 and not g.near_bridge(x + 0.5, z + 0.5, 3))
        # Deliberately changed (V6-D4): the lake's island takes about 280 square studs of it (3692 -> 3416)
        self.assertGreaterEqual(open_water, 3350, "open water for the raft's hull (v4: about 2800)")
        bridges = {b["id"]: b for b in g.bridges}
        self.assertGreaterEqual(bridges["Top"]["length"], 28)
        self.assertGreaterEqual(bridges["Bottom"]["length"], 28)
        for bid in ("RightLast", "Main", "LeftLast"):
            self.assertEqual(bridges[bid]["length"], 11, bid + " stays short")
        # each long bridge's deck spans the chocolate on its leg with a stud to spare at each end
        for bid in ("Top", "Bottom"):
            b = bridges[bid]
            for s in range(-int(b["length"] / 2) - 9, int(b["length"] / 2) + 10):
                x, z = b["x"] + b["ux"] * s, b["z"] + b["uz"] * s
                if g.liquid_distance(x, z) <= 1:
                    self.assertLessEqual(abs(s), b["length"] / 2, "%s: chocolate past the deck at %s" % (bid, s))
        (_, ax, az, atx, atz), (_, bx, bz, btx, btz) = g.docks
        self.assertLess(ax, 0, "dock A on the west bank")
        self.assertGreater(bx, 0, "dock B on the east bank")
        self.assertGreaterEqual(math.hypot(btx - atx, btz - atz), 50, "the docks face each other across open water")

    # V6-D4, V6-D60 on: an island in the big lake (WildboundCandyIsland lays it at server start; the layout treats it as
    # dry land). Mirrors WildboundCandyIsland_Test IS1, IS2 and IS6.
    def test_v6_island_in_the_lake(self):
        g = self.g
        hull, arm = 3.0, 9.0  # WildboundCandyRaft.HULL, ARM_STUDS
        self.assertEqual(len(g.islands), 1)
        i = g.islands[0]
        x, z, r, foot = i["x"], i["z"], i["r"], i["foot"]
        self.assertEqual(i["id"], "I1")
        self.assertLess(i["flat"], r)
        self.assertLess(r, foot)
        self.assertTrue(r >= 6 and 9 <= foot <= 12, "about 9 across the floor")
        self.assertAlmostEqual(foot, r + g.depth_liquid / math.tan(math.radians(g.island["bankDegrees"])), delta=0.05)
        bx, bz, br = g.lake[0]
        self.assertLess(math.hypot(x - bx, z - bz) + r, br, "inside the big disc")
        for k in range(720):
            a = 2 * math.pi * k / 720
            px, pz = x + math.cos(a) * (r + hull + 0.25), z + math.sin(a) * (r + hull + 0.25)
            self.assertLessEqual(g.water_distance(px, pz), -hull, "a raft channel all round at %d" % k)
            self.assertLessEqual(g.liquid_distance(px, pz), -hull)
            self.assertFalse(g.near_bridge(px, pz, hull))
            fx, fz = x + math.cos(a) * foot, z + math.sin(a) * foot
            self.assertLess(g.water_distance(fx, fz), 0, "the underwater bank stays in the lake")
        self.assertAlmostEqual(g.liquid_distance(x, z), r, delta=1e-9)
        self.assertGreater(g.liquid_distance(x + r - 0.01, z), 0)
        self.assertLess(g.liquid_distance(x + r + 0.01, z), 0)
        (_, asx, asz, atx, atz), (_, bsx, bsz, btx, btz) = g.docks
        for tx, tz in ((atx, atz), (btx, btz)):
            self.assertGreaterEqual(math.hypot(x - tx, z - tz) - foot, arm + 2 * hull, "by a dock tip")
        self.assertGreaterEqual(g.seg(x, z, atx, atz, btx, btz) - foot, 4 * hull, "on the dock-to-dock line")
        for asset, px, pz, pr in g.platforms:
            self.assertGreaterEqual(math.hypot(x - px, z - pz) - pr - r, g.clear["pieceApart"], asset)
            self.assertGreaterEqual(math.hypot(x - px, z - pz) - pr * g.platform["pedestalShare"] - foot, 0, asset + " pedestal")
        self.assertFalse(g.near_bridge(x, z, foot + 2 * hull))
        self.assertGreaterEqual(g.route_distance(x, z) - foot - g.path_half, g.clear["pieceFromRoute"])
        for nid, (nx, nz) in g.nests.items():
            self.assertGreaterEqual(math.hypot(x - nx, z - nz) - foot, g.clear["pieceFromNest"], nid)
        for pid, (px, pz) in g.posts.items():
            self.assertGreaterEqual(math.hypot(x - px, z - pz) - foot, g.clear["pieceFromPost"], pid)
        self.assertNotIn(i["id"], g.nests, "the nest id clashes with a layout nest")
        # the docks' straight crossing still floats the hull
        for s in range(101):
            px, pz = atx + (btx - atx) * s / 100, atz + (btz - atz) * s / 100
            reach = 0 if min(math.hypot(px - atx, pz - atz), math.hypot(px - btx, pz - btz)) <= arm else hull
            self.assertLessEqual(g.liquid_distance(px, pz), -reach, "crossing at %d %%" % s)
        # no chocolate fish jumps out of the island (WildboundCandyLife's spots: 7-stud arcs, 3 inside the chocolate)
        life = read(ROOT / "src" / "wildbound" / "WildboundCandyLife.luau")
        rows = re.findall(r'id = "(\w+)", x = %s, z = %s, heading = %s' % (NUM, NUM, NUM), block(life, "local FISH_ROWS ="))
        self.assertEqual(len(rows), 10)
        for fid, fx, fz, h in rows:
            fx, fz, h = float(fx), float(fz), float(h)
            for s in range(21):
                px, pz = fx + math.cos(h) * 7 * s / 20, fz + math.sin(h) * 7 * s / 20
                self.assertLessEqual(g.liquid_distance(px, pz), -3, "%s leaves the chocolate" % fid)
        island = read(ROOT / "tools" / "WildboundCandyIsland.luau")
        for needle in ('Island.RARITY = "Epica"', 'nest:SetAttribute("LakeIsland", true)', "function Island.sync(",
                       "Island.ready(root, V3)", 'lookup("WildboundCandyKit")'):
            self.assertIn(needle, island)
        nests = read(ROOT / "src" / "wildbound" / "WildboundCandyNests.luau")
        self.assertIn("pcall(I.sync, root, Layout)", nests)
        self.assertGreater(nests.index("pcall(I.sync, root, Layout)"), nests.index("pcall(T.sync, root, Layout)"))
        self.assertIn("and m.island ~= true", nests)

    def test_edge_fill_is_a_dense_band(self):
        e = self.g.edge
        self.assertLess(e["bandMin"], e["bandMax"])
        self.assertGreaterEqual(e["bandMax"], 40)
        self.assertLessEqual(e["spacing"], 16, "dense")
        self.assertGreaterEqual(e["maxTrees"] + e["maxProps"], 80)


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

    def test_v4_migration_tool_starts_dry_backs_up_archives_and_never_destroys(self):
        tool = read(TOOL_V4_PATH)
        self.assertRegex(tool, r"(?m)^local DRY_RUN = true\b")
        for needle in ("CaramelV4Backup", "CaramelV4Archived", "TryBeginRecording", "FinishRecordingOperation.Cancel",
                       'FindFirstAncestor("SistemaSonriente")', "RunService:IsRunning()", "WildboundCaramelV4Summary",
                       "V3.MARK", "V3.V4_MARK", "V3Builder.planV4", "V3Builder.refitTrees", "relay = true",
                       "creature posts: refusing", "summary.partsEstimate", "summary.overCap", "kitMissing = missing",
                       "partsBefore = countParts(root)", "require(found:Clone())", "V3.V4_PART_TARGET"):
            self.assertIn(needle, tool)
        self.assertGreater(tool.index("TryBeginRecording"), tool.index("task.delay("))
        self.assertNotRegex(tool, r":Destroy\(\)")

    def test_v5_migration_tool_starts_dry_backs_up_archives_and_never_destroys(self):
        tool = read(TOOL_V5_PATH)
        self.assertRegex(tool, r"(?m)^local DRY_RUN = true\b")
        for needle in ("CaramelV5Backup", "CaramelV5Archived", "TryBeginRecording", "FinishRecordingOperation.Cancel",
                       'FindFirstAncestor("SistemaSonriente")', "RunService:IsRunning()", "WildboundCaramelV5Summary",
                       "V3.V4_MARK", "V3.V5_MARK", "V3.VERSION == 3", "V3Builder.planV5", "V3Builder.layWater",
                       "summary.partsEstimate", "summary.overCap", "require(found:Clone())", "WildboundCandyRaft",
                       "homeDock", "partsBefore = countParts(root)"):
            self.assertIn(needle, tool)
        self.assertGreater(tool.index("TryBeginRecording"), tool.index("task.delay("))
        self.assertNotRegex(tool, r":Destroy\(\)")
        builder = read(BUILDER_PATH)
        for name in ("function V3Builder.planV5", "function V3Builder.layWater", "V3Builder.WATER_FOLDERS"):
            self.assertIn(name, builder)

    def test_v5_raft_is_a_quarter_faster(self):
        raft = read(RAFT_PATHS[0])
        self.assertRegex(raft, r"(?m)^Raft\.SPEED = 20\b")
        self.assertRegex(raft, r"(?m)^Raft\.REVERSE = 7\.5\b")

    def test_builder_uses_the_layout_and_falls_back_to_placeholders(self):
        builder = read(BUILDER_PATH)
        for name in ("function V3Builder.layAll", "function V3Builder.plan", "function V3Builder.swapTrees",
                     "function V3Builder.kitModel", "Placeholder", "function V3Builder.upgradePlaceholders",
                     "function V3Builder.existingProps", "V3.BEAST_PASS_TAG", "V3.BEAST_OVERHEAD_TAG", "SideRamp_",
                     "function V3Builder.planV4", "function V3Builder.refitTrees", "V3.BRIDGES", "V3.CRYSTAL_HILLS",
                     "V3.BACKDROP", "V3.EDGE", "Pedestal"):
            self.assertIn(name, builder)
        self.assertNotIn("SistemaSonriente\"", builder.replace('"SistemaSonriente"', ""))

    def test_fresh_build_lays_no_yellow_crystal(self):
        # V4-D6: the old builder's SugarHills lays no RockSugar any more (the pink hills come from the v3 batch)
        old = read(OLD_BUILDER_PATH)
        hills = old[old.index('"SugarHills"'):old.index("-- Portal back to the hub")]
        self.assertNotIn('"RockSugar"', hills)

    def test_raft_is_free(self):
        for path in RAFT_PATHS:
            text = read(path)
            for banned in ("MarketplaceService", "PromptProductPurchase", "PromptPurchase", "ProcessReceipt", "Robux", "DevProduct"):
                self.assertNotIn(banned, text, "%s mentions %s" % (path.name, banned))


if __name__ == "__main__":
    unittest.main()

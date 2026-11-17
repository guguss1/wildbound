"""Guard for GT (owner, 2026-11-16: "the cake with the princess at the end, and much bigger") and GT2 ("more eggs and
more creatures").

Run from the project root (isolated mode, no bytecode written):

    python -I -B -m unittest discover -s tools -p test_caramelo_cake_move.py

Reads the repo only. The Luau rules are in the Studio suites (WildboundCandyLayout_Test GT1-GT6, WildboundCandyTower_Test
GT7, WildboundCandyBuilder_Test GT8-GT12, WildboundCandyDuquesa_Test GT13-GT14); this checks what can be read from the
sources: the numbers the cake move spreads over several files agree, the layout has no hidden scale, and the one-shot live
tool reads the builder, starts dry, records one undo step from its own thread and never destroys or touches
SistemaSonriente.
"""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LAYOUT = ROOT / "tools" / "WildboundCandyLayout.luau"
BUILDER = ROOT / "tools" / "WildboundCandyBuilder.luau"
TOOL = ROOT / "tools" / "wildbound-caramelo-cake-move.luau"
SITES = ROOT / "src" / "wildbound" / "WildboundPraderaSites.luau"
CONFIG = ROOT / "src" / "wildbound" / "WildboundBeastConfig.luau"
PORTAL = ROOT / "src" / "wildbound" / "WildboundPortal.luau"


def read(path):
    return path.read_text(encoding="utf-8")


def number(pattern, text, label):
    found = re.search(pattern, text)
    if not found:
        raise AssertionError("not found: " + label)
    return [float(g) for g in found.groups()]


class CarameloCakeMove(unittest.TestCase):
    def setUp(self):
        self.layout = read(LAYOUT)
        self.builder = read(BUILDER)
        self.tool = read(TOOL)
        self.sites = read(SITES)

    def test_layout_is_version_3_with_the_cake_at_the_east_end(self):
        self.assertRegex(self.layout, r"(?m)^Layout\.VERSION = 3\b")
        x, z, r = number(r"Layout\.TORTA = table\.freeze\(\{ x = (-?[\d.]+), z = (-?[\d.]+), radius = ([\d.]+) \}\)",
                         self.layout, "TORTA")
        self.assertTrue(40 <= r <= 44, r)
        self.assertGreaterEqual(x, 100)
        # no hidden scale: the tiers follow TORTA.radius
        self.assertNotIn("26 / 36", self.layout)
        self.assertIn("Layout.TORTA.radius / 36", self.layout)

    def test_the_moved_numbers_agree_across_files(self):
        cx, cz = number(r"Layout\.CENTRE = point\((-?\d+), (-?\d+)\)", self.layout, "CENTRE")
        bx, bz, plaza, territory = number(
            r"Layout\.BOSS = table\.freeze\(\{ x = (-?[\d.]+), z = (-?[\d.]+), plazaRadius = ([\d.]+), territoryRadius = ([\d.]+)",
            self.layout, "BOSS")
        hx, hz = number(r"home = point\((-?\d+), (-?\d+)\)", self.layout, "BOSS.home")
        px, pz = number(r"Layout\.PORTAL = table\.freeze\(\{ x = (-?[\d.]+), z = (-?[\d.]+)", self.layout, "PORTAL")
        self.assertEqual(number(r"bossTerritory = table\.freeze\(\{ x = (-?\d+), z = (-?\d+) \}\)", self.sites, "bossTerritory"),
                         [cx + bx, cz + bz])
        self.assertEqual(number(r"bossHome = table\.freeze\(\{ x = (-?\d+), z = (-?\d+) \}\)", self.sites, "bossHome"),
                         [cx + hx, cz + hz])
        self.assertEqual(number(r"TerritoryRadiusStuds = (\d+)", read(CONFIG), "TerritoryRadiusStuds"), [territory])
        self.assertEqual(number(r'id = "caramelo", source = "candy", x = (-?\d+), z = (-?\d+)', read(PORTAL), "station"),
                         [cx + px, cz + pz])
        clear = number(r"bossClearStuds = (\d+)", self.sites, "bossClearStuds")[0]
        self.assertGreaterEqual(clear, territory + 40)

    def test_gt2_counts(self):
        nests = re.findall(r'nest\("(\w+)", "(\w+)", (-?\d+), (-?\d+)\)', self.layout)
        self.assertEqual(len(nests), 28)
        self.assertEqual(len({n[0] for n in nests}), 28)
        rarities = {}
        for n in nests:
            rarities[n[1]] = rarities.get(n[1], 0) + 1
        self.assertEqual(rarities, {"Comun": 13, "Rara": 11, "Epica": 3, "Legendaria": 1})
        extra = re.findall(r'\{ name = "(\w+)", key = "(candyPost\w+)" \}', self.sites)
        self.assertEqual(len(extra), 24 - 8)
        per = {}
        for name, key in extra:
            per[name] = per.get(name, 0) + 1
            self.assertRegex(self.sites, key + r" = table\.freeze\(\{ x = -?\d+, z = -?\d+ \}\)")
        self.assertEqual(set(per.values()), {2})

    def test_tool_reads_the_builder_and_starts_dry(self):
        self.assertRegex(self.tool, r"(?m)^local DRY_RUN = true\b")
        for name in ("Builder.placeTorta", "Builder.layBoss", "Builder.layPaths", "Builder.layMarkers", "Builder.syncTower",
                     "Builder.syncNestPositions", "Builder.syncNests", "Builder.cakeMovePlan", "Builder.syncCentre",
                     "Builder.growTree", "Builder.treeKeepOut"):
            self.assertIn(name, self.tool)
            self.assertIn("function " + name, self.builder)
        self.assertIn("Layout.VERSION == 3", self.tool)
        self.assertIn('"CakeMoveV1"', self.tool)
        self.assertIn("CakeMoveBackup", self.tool)
        self.assertIn("CakeMoveArchived", self.tool)
        # no number of its own: positions come from the layout, sizes from the builder
        self.assertNotRegex(self.tool, r"ScaleTo\(")

    def test_tool_records_from_its_own_thread_and_never_destroys(self):
        self.assertIn("task.delay(", self.tool)
        delay = self.tool.index("task.delay(")
        self.assertGreater(self.tool.index("TryBeginRecording"), delay, "the recording opens inside the deferred thread")
        self.assertIn("FinishRecordingOperation.Cancel", self.tool)
        self.assertIn('FindFirstAncestor("SistemaSonriente")', self.tool)
        self.assertIn("RunService:IsRunning()", self.tool)
        self.assertNotRegex(self.tool, r":Destroy\(\)")
        self.assertIn("WildboundCakeMoveSummary", self.tool)


if __name__ == "__main__":
    unittest.main()

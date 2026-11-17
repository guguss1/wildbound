"""Guard for CH (owner, 2026-11-16: the Caramelo trees leafier and bigger).

Run from the project root (isolated mode, no bytecode written):

    python -I -B -m unittest discover -s tools -p test_caramelo_tree_resize.py

Reads the repo only. The Luau rules themselves are in tests/WildboundCandyBuilder_Test.luau (CH-T1 to CH-T5, Studio);
this checks what can be read from the sources: the factors stay in the owner's 1.5x to 1.8x range and the one-shot
live resize tool takes them from the builder, defaults to a dry run and never touches SistemaSonriente.
"""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILDER = ROOT / "tools" / "WildboundCandyBuilder.luau"
RESIZE = ROOT / "tools" / "wildbound-caramelo-tree-resize.luau"
TREES = ("TreeCotton_S", "TreeCotton_M", "TreeCotton_L", "TreeLollipop_Straight", "TreeLollipop_Tilted", "TreeCookie",
         "TreeCream")


class CarameloTreeResize(unittest.TestCase):
    def setUp(self):
        self.builder = BUILDER.read_text(encoding="utf-8")
        self.resize = RESIZE.read_text(encoding="utf-8")

    def test_every_tree_kind_grows_1_5_to_1_8(self):
        table = re.search(r"Builder\.TREE_SCALE = table\.freeze\(\{(.*?)\}\)", self.builder, re.S)
        self.assertIsNotNone(table, "Builder.TREE_SCALE")
        factors = dict((name, float(value)) for name, value in re.findall(r"(\w+) = ([\d.]+)", table.group(1)))
        self.assertEqual(sorted(factors), sorted(TREES))
        for name, value in factors.items():
            self.assertTrue(1.5 <= value <= 1.8, "%s %s" % (name, value))
        boost = float(re.search(r"Builder\.CANOPY_BOOST = ([\d.]+)", self.builder).group(1))
        self.assertTrue(1.0 < boost <= 1.25, boost)
        self.assertRegex(self.builder, r"minFactor = 1\.5\b")

    def test_extra_trees_are_about_half_again(self):
        table = re.search(r"Builder\.EXTRA_TREES = table\.freeze\(\{(.*?)\}\)", self.builder, re.S)
        self.assertIsNotNone(table, "Builder.EXTRA_TREES")
        extra = dict((name, float(value)) for name, value in re.findall(r"(\w+) = ([\d.]+)", table.group(1)))
        # the base scatter: 22 + 10 cotton trees, 5 cookie and 5 cream trees, avenue pairs every 30 studs
        self.assertTrue(0.4 <= (extra["cottonLeft"] + extra["cottonRight"]) / 32 <= 0.6)
        self.assertTrue(0.4 <= (extra["TreeCookie"] + extra["TreeCream"]) / 10 <= 0.6)
        self.assertEqual(extra["avenueEvery"], 60)  # one extra pair per two base pairs
        self.assertIn("plant(22, -190, -10, cotton, tree)", self.builder)
        self.assertIn("plant(10, 10, 190, cotton, tree)", self.builder)
        # GT (cake move): 1300 -> 1450 for the centre backfill and the GT2 nests (Builder.MAX_PARTS comment)
        self.assertLessEqual(int(re.search(r"Builder\.MAX_PARTS = (\d+)", self.builder).group(1)), 1450)

    def test_resize_tool_reads_the_builder_and_starts_dry(self):
        self.assertRegex(self.resize, r"(?m)^local DRY_RUN = true\b")
        for name in ("Builder.TREE_SCALE", "Builder.growTree", "Builder.fitTree", "Builder.measureTree",
                     "Builder.treeKeepOut", "Builder.TREE_ATTRIBUTE", "Builder.syncTrees"):
            self.assertIn(name, self.resize)
        # no factor of its own: every number that grows a tree comes from the builder
        self.assertNotRegex(self.resize, r"ScaleTo\(")
        self.assertIn('TREE_ATTRIBUTE = "CaramelTreeScaleV2"', self.builder)
        self.assertIn("Candy_Bioma_v1", (ROOT / "tools" / "WildboundCandyLayout.luau").read_text(encoding="utf-8"))

    def test_resize_tool_never_touches_sistema_sonriente_and_runs_in_edit_only(self):
        self.assertIn('FindFirstAncestor("SistemaSonriente")', self.resize)
        self.assertIn("RunService:IsRunning()", self.resize)
        # the only thing it destroys is its own detached measuring clone
        self.assertEqual(re.findall(r"(\w+):Destroy\(\)", self.resize), ["probe"])


if __name__ == "__main__":
    unittest.main()

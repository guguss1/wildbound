"""Guard for Wildbound 2.0 T01: WildboundBalance stays unwired until T02 wires it.

Run from the project root (isolated mode, no bytecode written):

    python -I -B -m unittest discover -s tools -p test_wildbound_balance_unwired.py

Reads the repo only. When a later task wires the module on purpose, it updates this guard in the same commit.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MODULE = ROOT / "src" / "wildbound" / "WildboundBalance.luau"


class WildboundBalanceUnwired(unittest.TestCase):
    def test_module_exists(self):
        self.assertTrue(MODULE.is_file(), MODULE)

    def test_no_other_source_mentions_the_module(self):
        offenders = []
        for path in sorted((ROOT / "src").rglob("*.luau")):
            if path.resolve() == MODULE.resolve():
                continue
            if "WildboundBalance" in path.read_text(encoding="utf-8", errors="replace"):
                offenders.append(str(path.relative_to(ROOT)))
        self.assertEqual(offenders, [], "WildboundBalance is referenced before T02 wires it")


if __name__ == "__main__":
    unittest.main()

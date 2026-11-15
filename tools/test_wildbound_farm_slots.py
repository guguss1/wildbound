"""PF4 guard: State's farm slot count equals the 2.0 balance's farm.startSlots, and the record's hard cap stays at
or above the balance's farm.maxSlots range.

Run from the project root (isolated mode, no bytecode written):

    python -I -B -m unittest discover -s tools -p test_wildbound_farm_slots.py

Reads the repo only. WildboundBalance stays unwired (tools/test_wildbound_balance_unwired.py), so State carries its own
copy of the number and this guard keeps the two equal.
"""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "wildbound"


def read(name):
    return (SRC / name).read_text(encoding="utf-8")


class WildboundFarmSlots(unittest.TestCase):
    def test_state_slots_equal_balance_start_slots(self):
        state = re.search(r"^State\.FARM_SLOTS = (\d+)", read("WildboundState.luau"), re.M)
        balance = re.search(r"\bstartSlots = (\d+), -- farm slots a new account owns", read("WildboundBalance.luau"))
        self.assertIsNotNone(state, "State.FARM_SLOTS")
        self.assertIsNotNone(balance, "Balance farm.startSlots")
        self.assertEqual(int(state.group(1)), int(balance.group(1)))

    def test_record_cap_covers_the_max_slots_range(self):
        cap = re.search(r"^FarmRecord\.CAP = (\d+)", read("WildboundFarmRecord.luau"), re.M)
        upper = re.search(r'\["farm\.maxSlots"\] = scalar\(\d+, (\d+)', read("WildboundBalance.luau"))
        self.assertIsNotNone(cap, "FarmRecord.CAP")
        self.assertIsNotNone(upper, "farm.maxSlots range")
        self.assertGreaterEqual(int(cap.group(1)), int(upper.group(1)))


if __name__ == "__main__":
    unittest.main()

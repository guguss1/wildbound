"""Tests for tools/wildbound_gold_sim.py (gold layer over the live economy model, owner item O7).

Run: python -I -B -m unittest discover -s tools -p "test_wildbound_gold_sim.py"
"""

import contextlib
import io
import re
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

_HERE = str(Path(__file__).resolve().parent)
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

import wildbound_economy_sim_v2 as v2  # noqa: E402
import wildbound_gold_sim as sim  # noqa: E402

REPO = Path(__file__).resolve().parent.parent


def crafted_gold(**overrides):
    gold = {
        "farm_per_minute": {"Comun": 7, "Rara": 10, "Epica": 18, "Legendaria": 30},
        "sell_prices": {"Comun": 25, "Rara": 60, "Epica": 150, "Legendaria": 400},
        "upgrade_prices": {"farmSlot5": 60, "farmSlot6": 150},
        "TAME_BONUS": 20, "LAP_BASE": 2, "LAP_LEVELS_PER_EXTRA": 4, "TREADMILL_CAP_PER_MINUTE": 10,
        "SELL_LEVEL_BONUS": 0.2, "SELL_MAX_LEVEL": 10, "CAP_WINDOW": 60, "TRAIN_BASE": 30, "TRAIN_GROWTH": 1.15,
        "default_rarity": "Comun",
        "species_rarity": {"Gomibu": "Comun", "Tortidragon": "Rara", "Flanfuria": "Epica", "Lumipol": "Comun"},
    }
    gold.update(overrides)
    return gold


class LoadingTests(unittest.TestCase):
    def test_reads_live_gold_module(self):
        gold = sim.load_gold()
        self.assertEqual(set(gold["farm_per_minute"]), set(v2.RARITIES))
        self.assertEqual(set(gold["sell_prices"]), set(v2.RARITIES))
        self.assertIn("farmSlot5", gold["upgrade_prices"])
        self.assertIn("farmSlot6", gold["upgrade_prices"])
        for key in ("TAME_BONUS", "LAP_BASE", "TREADMILL_CAP_PER_MINUTE", "TRAIN_BASE", "TRAIN_GROWTH"):
            self.assertGreater(gold[key], 0)
        self.assertEqual(gold["species_rarity"]["Flanfuria"], "Epica")
        self.assertEqual(gold["species_rarity"]["Lumipol"], "Comun")

    def test_reads_a_changed_value_from_a_crafted_repo(self):
        with tempfile.TemporaryDirectory() as tmp:
            for rel in (sim.GOLD, sim.SPECIES):
                target = Path(tmp) / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy(REPO / rel, target)
            path = Path(tmp) / sim.GOLD
            text = path.read_text(encoding="utf-8")
            patched = re.sub(r"Gold\.TAME_BONUS = \d+", "Gold.TAME_BONUS = 9", text)
            patched = re.sub(r"Comun = \d+, Rara = \d+, Epica = \d+, Legendaria = \d+",
                             "Comun = 1, Rara = 2, Epica = 3, Legendaria = 4", patched, count=1)
            path.write_text(patched, encoding="utf-8")
            gold = sim.load_gold(tmp)
            self.assertEqual(gold["TAME_BONUS"], 9)
            self.assertEqual(gold["farm_per_minute"], {"Comun": 1, "Rara": 2, "Epica": 3, "Legendaria": 4})

    def test_missing_table_raises(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / sim.GOLD
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text("local Gold = {}\nreturn Gold\n", encoding="utf-8")
            with self.assertRaises(v2.NumbersUnavailable):
                sim.load_gold(tmp)


class RuleTests(unittest.TestCase):
    def test_train_ladder_matches_the_luau_rounding(self):
        gold = crafted_gold()
        ladder = [sim.train_price(gold, level, 17) for level in range(17)]
        self.assertEqual(ladder[:5], [30, 35, 40, 46, 52])
        self.assertEqual(ladder[-1], 281)
        self.assertIsNone(sim.train_price(gold, 17, 17))
        self.assertEqual(sim.sink_ladder(gold, 17)["total"], 210 + sum(ladder))

    def test_sell_price_bond_bonus_and_cap(self):
        gold = crafted_gold()
        self.assertEqual(sim.sell_price(gold, "Comun", 1), 25)
        self.assertEqual(sim.sell_price(gold, "Rara", 2), 72)
        self.assertEqual(sim.sell_price(gold, "Legendaria", 10), 1120)
        self.assertEqual(sim.sell_price(gold, "Legendaria", 99), 1120)
        self.assertEqual(sim.sell_price(gold, "Unknown", 1), 25)

    def test_lap_gold_and_cap_window(self):
        gold = crafted_gold()
        self.assertEqual([sim.lap_gold(gold, lv) for lv in (0, 3, 4, 17)], [2, 2, 3, 6])
        window, paid = None, 0
        for lap in range(1, 8):  # seven 8 s laps fit in one 60 s window
            got, window = sim.cap_lap(gold, window, lap * 8.0, 2)
            paid += got
        self.assertEqual(paid, 10)
        got, window = sim.cap_lap(gold, window, 8.0 + 60.0, 2)
        self.assertEqual(got, 2)

    def test_afk_gold(self):
        gold = crafted_gold()
        self.assertEqual(sim.afk_gold_per_minute(gold, []), 10)
        self.assertEqual(sim.afk_gold_per_minute(gold, ["Epica"] * 6), 118)


class SessionTests(unittest.TestCase):
    def test_companion_then_farm_income_and_tame_bonus(self):
        gold = crafted_gold(TRAIN_BASE=10 ** 6, upgrade_prices={"farmSlot5": 10 ** 6, "farmSlot6": 10 ** 6})
        hatches = [(0.0, "Comun", "Gomibu")] * 5
        r = sim.gold_session(gold, hatches, [], 1, "keep", 4, 17)
        self.assertEqual(r["split"]["tame"], 100)
        self.assertAlmostEqual(r["split"]["farm"], 28.0)  # the companion is not in the farm: 4 x 7
        self.assertAlmostEqual(r["gold_total"], sum(r["split"].values()))
        self.assertAlmostEqual(r["gold_end"], r["gold_total"])

    def test_farm_place_bought_the_moment_it_is_affordable(self):
        gold = crafted_gold(TRAIN_BASE=10 ** 6)
        # Companion, then two in the farm (14 per minute); three tame bonuses (60) buy place 5 at once.
        hatches = [(0.0, "Comun", "Gomibu")] * 3
        r = sim.gold_session(gold, hatches, [], 11, "keep", 4, 17)
        self.assertEqual(r["farm_slot_5_s"], 0.0)
        self.assertAlmostEqual(r["farm_slot_6_s"], 150 / 14 * 60.0)
        self.assertAlmostEqual(r["gold_end"], 14 * 11 - 150)

    def test_treadmill_laps_respect_the_cap(self):
        gold = crafted_gold(TRAIN_BASE=10 ** 6, upgrade_prices={"farmSlot5": 10 ** 6, "farmSlot6": 10 ** 6})
        laps = [(8.0 * i, 0) for i in range(1, 16)]  # 15 laps in 120 s
        r = sim.gold_session(gold, [], laps, 2, "keep", 4, 17)
        self.assertEqual(r["split"]["treadmill"], 20)

    def test_sell_policies(self):
        gold = crafted_gold(TRAIN_BASE=10 ** 6, upgrade_prices={"farmSlot5": 10 ** 6, "farmSlot6": 10 ** 6})
        hatches = [(0.0, "Comun", "Gomibu")] * 7 + [(0.0, "Rara", "Tortidragon")]
        keep = sim.gold_session(gold, hatches, [], 1, "keep", 4, 17)
        dupes = sim.gold_session(gold, hatches, [], 1, "duplicates", 4, 17)
        sell_all = sim.gold_session(gold, hatches, [], 1, "all", 4, 17)
        self.assertEqual(keep["sold"], 0)
        # Farm: 3 Gomibu + Tortidragon (the rarer one swapped in); 3 Gomibu left over, all duplicates.
        self.assertEqual(dupes["sold"], 3)
        self.assertEqual(sell_all["sold"], 3)
        self.assertEqual(sell_all["split"]["sale"], 75)
        self.assertAlmostEqual(keep["farm_rate_end"], 3 * 7 + 10)
        with self.assertRaises(ValueError):
            sim.gold_session(gold, hatches, [], 1, "bogus", 4, 17)

    def test_run_gold_is_deterministic_and_renders(self):
        live, gold = v2.load_live_game(), sim.load_gold()
        profiles = {"beginner": v2.default_live_profiles()["beginner"]}
        a = sim.run_gold(live, gold, profiles, [10], seed=3, runs=3, routes=("caramelo",))
        b = sim.run_gold(live, gold, profiles, [10], seed=3, runs=3, routes=("caramelo",))
        self.assertEqual(a["cells"], b["cells"])
        text = sim.render_md(a, "cmd")
        self.assertIn("### Gold (Oro) model", text)
        self.assertIn("ASSUMED `gold_policy`", text)

    def test_cli_md(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(sim.main(["--profile", "beginner", "--minutes", "10", "--runs", "2", "--md"]), 0)


class LiveLogTests(unittest.TestCase):
    def test_live_session_logs_hatches_and_laps(self):
        live = v2.load_live_game()
        profile = v2.default_live_profiles()["advanced"]
        s = v2.simulate_live_session(live, profile, "caramelo", 30, 7)
        self.assertEqual(len(s["hatch_log"]), s["hatches"])
        self.assertTrue(all(r in v2.RARITIES for _, r, _ in s["hatch_log"]))
        self.assertGreaterEqual(len(s["lap_log"]), profile.laps_at_start)
        times = [t for t, _, _ in s["hatch_log"]]
        self.assertEqual(times, sorted(times))


if __name__ == "__main__":
    unittest.main()

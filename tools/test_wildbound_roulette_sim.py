"""Tests for tools/wildbound_roulette_sim.py (T09a, the Wildbound 2.0 roulette prize table).

Run: python -I -B -m unittest discover -s tools -p "test_wildbound_roulette_sim.py"

The Python mirror pins the same numbers as tests/WildboundRoulette_Test.luau, so the two implementations cannot drift
apart silently.
"""

import contextlib
import copy
import io
import re
import sys
import unittest
from pathlib import Path

_HERE = str(Path(__file__).resolve().parent)
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

import wildbound_roulette_sim as rs  # noqa: E402

REPO = Path(__file__).resolve().parent.parent
MODULE = REPO / "src" / "wildbound" / "WildboundRoulette.luau"
TEST = REPO / "tests" / "WildboundRoulette_Test.luau"
REPORT = REPO / "docs" / "balance" / "wildbound-2-0-roulette.md"


def config():
    return rs.load_config()


class LoadingTests(unittest.TestCase):
    def test_cli_help(self):
        with contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(SystemExit) as raised:
                rs.main(["--help"])
        self.assertEqual(raised.exception.code, 0)

    def test_parses_the_luau_config(self):
        c = config()
        self.assertEqual(c["currency"], "esencia")
        self.assertEqual(c["spinCost"], 45)
        self.assertIs(c["freeFirstSpin"], True)
        self.assertEqual(len(c["prizes"]), 21)
        self.assertEqual(c["pity"], {"enabled": True, "every": 10, "minRarity": "Rara"})
        self.assertEqual(c["locations"], ["hub", "base"])

    def test_category_weights_match_balance(self):
        c = config()
        balance = rs.load_balance_roulette()
        self.assertEqual(c["categoryWeights"], balance["weights"])
        self.assertEqual(c["spinCost"], balance["spinCost"])
        self.assertEqual(c["freeFirstSpin"], balance["freeFirstSpin"])
        sums = {}
        for prize in c["prizes"]:
            sums[prize["category"]] = sums.get(prize["category"], 0) + prize["weight"]
        self.assertEqual(sums, {k: v * 100 for k, v in balance["weights"].items()})

    def test_missing_file_raises(self):
        with self.assertRaises(rs.ConfigUnavailable):
            rs.load_config(REPO / "src" / "wildbound" / "NoSuchRoulette.luau")

    def test_module_source_is_pure(self):
        text = rs.strip_comments(MODULE.read_text(encoding="utf-8"))
        for needle in ("game:", "game.", "workspace", "Instance.", "require(", "os.time", "os.clock", "tick(",
                       "math.random", "Random.new", "script."):
            self.assertNotIn(needle, text, needle)

    def test_luau_test_pins_the_same_rows(self):
        # Every EXPECTED row in the Luau suite equals the parsed config row.
        rows = re.findall(r'\{ "(\w+)", "(\w+)", "(\w+)", (\d+), (\d+), (\d+), "(\w+)", (\d+) \}',
                          TEST.read_text(encoding="utf-8"))
        self.assertEqual(len(rows), 21)
        for row, prize in zip(rows, config()["prizes"]):
            self.assertEqual(
                (row[0], row[1], row[2], int(row[3]), int(row[4]), int(row[5]), row[6], int(row[7])),
                (prize["id"], prize["category"], prize["rarity"], prize["weight"], prize["value"], prize["resale"],
                 prize["whenFull"], prize.get("fullEsencia", 0)),
            )


class RuleTests(unittest.TestCase):
    def test_default_config_validates(self):
        self.assertEqual(rs.validate(config()), [])

    def test_validation_catches_broken_tables(self):
        cases = [
            (lambda c: c["prizes"][0].update(weight=1601), "esencia"),
            (lambda c: c["prizes"][1].update(id="esencia10"), "duplicate"),
            (lambda c: c["prizes"][0].update(rarity="Mitica"), "rarity"),
            (lambda c: c["prizes"][5].update(grant={"iron": 3}), "iron"),
            (lambda c: c["prizes"][9]["grant"].update(glove="Rara"), "glove"),
            (lambda c: c["prizes"][13]["grant"].update(incubationBooster=1.2), "booster"),
            (lambda c: c["prizes"][16].update(grant={"bomb": 1}), "bomb"),
            (lambda c: c.update(spinCost=0), "spincost"),
            (lambda c: c["pity"].update(every=1), "pity"),
            (lambda c: c.update(currency="robux"), "currency"),
            (lambda c: c["prizes"][9].pop("whenFull"), "whenfull"),
            (lambda c: c["prizes"][0].update(whenFull="pending"), "whenfull"),
            (lambda c: c["prizes"][16].pop("fullEsencia"), "fullesencia"),
            (lambda c: c["prizes"][16].update(fullEsencia=25), "fullesencia"),
            (lambda c: c.update(locations=[]), "location"),
            (lambda c: c.update(locations=["hub", "cave"]), "location"),
            (lambda c: c["prizes"][9].update(resale=120), "money loop"),
        ]
        for mutate, needle in cases:
            c = copy.deepcopy(config())
            mutate(c)
            errors = " | ".join(rs.validate(c)).lower()
            self.assertIn(needle, errors, f"{needle}: {errors}")

    def test_draw_is_deterministic_and_matches_the_luau_pins(self):
        c = config()
        state = rs.new_state()
        prize, state2, receipt = rs.draw(0.0, state, c)
        self.assertEqual((prize["id"], receipt["cost"], receipt["free"]), ("esencia10", 0, True))
        self.assertEqual(state, rs.new_state(), "input state not mutated")
        for rng, expected in [(0.1599, "esencia10"), (0.16, "esencia25"), (0.3455, "esencia200"), (0.5, "glowmoss6"),
                              (0.62, "gloveComun"), (0.7975, "gloveLegendaria"), (0.915, "booster75"),
                              (0.975, "portal1"), (0.9999, "eggLegendaria")]:
            p, _, r = rs.draw(rng, state2, c)
            self.assertEqual(p["id"], expected, rng)
            self.assertEqual(r["cost"], 45)

    def test_pity_on_and_off(self):
        c = config()
        state = rs.draw(0.0, rs.new_state(), c)[1]
        for _ in range(9):
            state = rs.draw(0.0, state, c)[1]
        self.assertEqual(state["pityCount"], 9)
        prize, after, receipt = rs.draw(0.0, state, c)
        self.assertEqual((prize["id"], receipt["pity"], after["pityCount"]), ("esencia45", True, 0))
        self.assertEqual(rs.draw(0.5, state, c)[0]["id"], "gloveRara")
        off = copy.deepcopy(c)
        off["pity"]["enabled"] = False
        prize, after, receipt = rs.draw(0.0, state, off)
        self.assertEqual((prize["id"], receipt["pity"], after["pityCount"]), ("esencia10", False, 10))

    def test_bad_rng_is_refused(self):
        for bad in (-0.1, 1.0, float("nan"), float("inf")):
            prize, state, error = rs.draw(bad, rs.new_state(), config())
            self.assertIsNone(prize)
            self.assertEqual(state, rs.new_state())
            self.assertIsInstance(error, str)

    def test_expected_values_match_the_luau_pins(self):
        c = config()
        off = rs.expected_value(c, pity=False)
        self.assertAlmostEqual(off["esencia"], 10.05, places=9)
        self.assertAlmostEqual(off["cash"], 19.215, places=9)
        self.assertAlmostEqual(off["value"], 36.96, places=9)
        on = rs.expected_value(c, pity=True)
        self.assertAlmostEqual(on["esencia"], 10.153008736565770, places=9)
        self.assertAlmostEqual(on["cash"], 19.492222330422116, places=9)
        self.assertAlmostEqual(on["value"], 37.413987066739885, places=9)
        epic = copy.deepcopy(c)
        epic["pity"]["minRarity"] = "Epica"
        e = rs.expected_value(epic, pity=True)
        self.assertAlmostEqual(e["cash"], 24.95894930901911, places=9)
        self.assertAlmostEqual(e["value"], 44.68592773030853, places=9)

    def test_effective_odds_sum_to_one(self):
        for pity in (False, True):
            odds = rs.effective_odds(config(), pity)
            self.assertAlmostEqual(sum(odds.values()), 1.0, places=12)


class SimulationTests(unittest.TestCase):
    def test_simulation_is_seeded_and_reproducible(self):
        a = rs.simulate(config(), spins=2000, seed=11, pity=True)
        b = rs.simulate(config(), spins=2000, seed=11, pity=True)
        self.assertEqual(a, b)

    def test_empirical_frequencies_fit_the_declared_odds(self):
        for pity in (False, True):
            run = rs.simulate(config(), spins=20000, seed=7, pity=pity)
            chi2 = rs.chi_square(run["counts"], rs.effective_odds(config(), pity), run["paid"])
            self.assertLess(chi2, rs.CHI2_CRITICAL_DF20_P001, f"pity={pity} chi2={chi2}")

    def test_pity_caps_the_drought(self):
        on = rs.simulate(config(), spins=20000, seed=7, pity=True)
        off = rs.simulate(config(), spins=20000, seed=7, pity=False)
        self.assertLessEqual(on["longestDrought"], 9)
        self.assertGreater(off["longestDrought"], 9)

    def test_no_money_loop(self):
        c = config()
        for pity in (False, True):
            run = rs.simulate(c, spins=20000, seed=3, pity=pity)
            self.assertLess(run["cashPerSpin"], c["spinCost"] * c["limits"]["maxCashShare"])
            self.assertLess(run["esenciaPerSpin"], c["limits"]["maxEsenciaPerSpin"])
            self.assertFalse(rs.money_loop(c, pity))

    def test_report_is_written_and_stable(self):
        text = rs.report(config(), spins=10000, seed=7)
        self.assertEqual(text, rs.report(config(), spins=10000, seed=7))
        self.assertIn("| esencia10 |", text)
        self.assertIn("Pity ON", text)
        self.assertIn("Pity OFF", text)
        self.assertTrue(text.startswith("# Wildbound 2.0 roulette"))


def live():
    return rs.load_live_config()


class LiveTableTests(unittest.TestCase):
    """PF5 (user decision 2026-11-14): the hub roulette's LIVE table, Esencia and banked materials only."""

    def test_parses_the_live_config(self):
        c = live()
        self.assertEqual(len(c["prizes"]), 11)
        self.assertEqual({p["category"] for p in c["prizes"]}, {"esencia", "materials"})
        self.assertEqual(c["categoryWeights"], {"esencia": 40, "materials": 60})
        self.assertEqual(c["locations"], ["hub"])
        self.assertEqual((c["spinCost"], c["freeFirstSpin"]), (45, True))
        self.assertEqual(c["pity"], {"enabled": True, "every": 10, "minRarity": "Rara"})
        for prize in c["prizes"]:
            if prize["category"] == "materials":
                self.assertTrue(set(prize["grant"]) <= set(rs.MATERIALS), prize["id"])

    def test_live_validates(self):
        self.assertEqual(rs.validate(live()), [])

    def test_luau_test_pins_the_same_live_rows(self):
        rows = re.findall(r'\{ id = "(\w+)", category = "(\w+)", rarity = "(\w+)", weight = (\d+), value = (\d+),'
                          r' resale = (\d+) \}', TEST.read_text(encoding="utf-8"))
        self.assertEqual(len(rows), 11)
        for row, prize in zip(rows, live()["prizes"]):
            self.assertEqual((row[0], row[1], row[2], int(row[3]), int(row[4]), int(row[5])),
                             (prize["id"], prize["category"], prize["rarity"], prize["weight"], prize["value"],
                              prize["resale"]))

    def test_live_expected_values_match_the_luau_pins(self):
        off = rs.expected_value(live(), pity=False)
        self.assertAlmostEqual(off["esencia"], 11.9, places=9)
        self.assertAlmostEqual(off["value"], 21.12, places=9)
        on = rs.expected_value(live(), pity=True)
        self.assertAlmostEqual(on["esencia"], 12.014076350265439, places=9)
        self.assertAlmostEqual(on["cash"], on["esencia"], places=12)
        self.assertAlmostEqual(on["value"], 21.30234431310803, places=9)
        self.assertAlmostEqual(on["pitySpinShare"], 0.010162703809838618, places=12)
        self.assertFalse(rs.money_loop(live(), True))

    def test_live_draw_matches_the_luau_pins(self):
        c = live()
        state = rs.draw(0.0, rs.new_state(), c)[1]
        for rng, expected in [(0.1999, "esencia10"), (0.2, "esencia25"), (0.3, "esencia45"), (0.36, "esencia90"),
                              (0.39, "esencia200"), (0.4, "fogbark10"), (0.62, "glowmoss6"), (0.78, "mixedPouch"),
                              (0.87, "nightbloom2"), (0.94, "nightbloom5"), (0.98, "forestChest")]:
            self.assertEqual(rs.draw(rng, state, c)[0]["id"], expected, rng)
        for _ in range(9):
            state = rs.draw(0.0, state, c)[1]
        self.assertEqual(rs.draw(0.0, state, c)[0]["id"], "esencia45")
        self.assertEqual(rs.draw(0.999, state, c)[0]["id"], "forestChest")

    def test_live_frequencies_fit_and_pity_caps_the_drought(self):
        run = rs.simulate(live(), spins=20000, seed=7, pity=True)
        chi2 = rs.chi_square(run["counts"], rs.effective_odds(live(), True), run["paid"])
        self.assertLess(chi2, rs.CHI2_CRITICAL_DF10_P001, chi2)
        self.assertLessEqual(run["longestDrought"], 9)

    def test_full_report_carries_the_live_table_and_matches_the_doc(self):
        text = rs.full_report()
        self.assertEqual(text, rs.full_report())
        self.assertIn("## Live hub table (PF5)", text)
        self.assertIn("| forestChest |", text)
        self.assertEqual(REPORT.read_text(encoding="utf-8"), text, "regenerate with --write")


if __name__ == "__main__":
    unittest.main()

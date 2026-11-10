"""Contracts for the Wildbound hub economy simulator.

Run from the project root (isolated mode, no bytecode written):

    python -I -B -m unittest discover -s tools -p "test_*.py"

The simulator reads the fenced `json economy-synthesis` block of
docs/design/wildbound-economy-and-offers.md at run time. These tests pin the
document's rules (the refutation fixes) and the simulator's pure helpers with
hand-derived numbers. They model math only; they say nothing about fun.
"""

import contextlib
import copy
import io
import json
import re
import unittest
from pathlib import Path

import simulate_economy as p0
import simulate_hub_economy as hub

REPO = Path(__file__).resolve().parent.parent
DOC = REPO / "docs/design/wildbound-economy-and-offers.md"
BEST = [("c0", "Comun"), ("c1", "Comun"), ("c2", "Comun"), ("c3", "Comun"),
        ("r0", "Rara"), ("r1", "Rara"), ("e0", "Epica"), ("l0", "Legendaria")]

_CACHE = {}


def syn():
    if "syn" not in _CACHE:
        _CACHE["syn"] = hub.load_synthesis(DOC)
    return copy.deepcopy(_CACHE["syn"])


def p0_tuning():
    if "p0" not in _CACHE:
        _CACHE["p0"] = p0.load_tuning(p0.DOC)
    return copy.deepcopy(_CACHE["p0"])


def analysis(persistence=True, sessions=12, runs=3):
    key = ("analysis", persistence, sessions, runs)
    if key not in _CACHE:
        _CACHE[key] = hub.analyse(syn(), p0_tuning(), runs, sessions, 2026, persistence=persistence)
    return _CACHE[key]


class ReadingTheDocument(unittest.TestCase):
    def test_document_block_is_schema_two_and_unmonetized(self):
        s = syn()
        self.assertEqual(s["schemaVersion"], 2)
        self.assertEqual(s["monetization"], "none")
        self.assertFalse(s["currency"]["purchasable"])

    def test_refuses_any_monetization_but_none(self):
        text = DOC.read_text(encoding="utf-8").replace('"monetization": "none"', '"monetization": "convenience"', 1)
        with self.assertRaises(hub.TuningError):
            hub.extract_synthesis(text)

    def test_refuses_a_second_block_or_an_old_schema(self):
        text = DOC.read_text(encoding="utf-8")
        with self.assertRaises(hub.TuningError):
            hub.extract_synthesis(text + "\n```json economy-synthesis\n{}\n```\n")
        with self.assertRaises(hub.TuningError):
            hub.extract_synthesis(text.replace('"schemaVersion": 2', '"schemaVersion": 1', 1))

    def test_doc_has_the_refutations_section(self):
        text = DOC.read_text(encoding="utf-8")
        self.assertIn("## 17. Refutations addressed", text)
        for tag in ["R1.1", "R1.12", "R2.1", "R2.12", "R3.P1", "R3.P7"]:
            self.assertIn(f"| {tag} |", text)


class ShapeChecks(unittest.TestCase):
    def test_document_passes_every_shape_and_corral_check(self):
        s = syn()
        self.assertEqual(hub.check_shape(s, p0_tuning()), [])
        self.assertEqual(hub.corral_contract_checks(s), [])

    def _problems(self, mutate):
        s = syn()
        mutate(s)
        return " | ".join(hub.check_shape(s, p0_tuning()))

    def test_fear_relief_on_a_sold_piece_is_refused(self):
        out = self._problems(lambda s: s["equipment"]["pieces"]["amuleto"]["I"].update({"fearMuted": True}))
        self.assertIn("fearMuted", out)

    def test_old_first_offer_minute_is_refused(self):
        def mutate(s):
            s["offerRules"]["firstOfferMinute"] = 10
            s["offerRules"]["minSessionIndex"] = 1
        out = self._problems(mutate)
        self.assertIn("firstOfferMinute", out)
        self.assertIn("first session", out)

    def test_daily_gift_at_the_shop_is_refused(self):
        self.assertIn("daily gift", self._problems(lambda s: s["dailyGift"].update({"surface": "puesto"})))

    def test_imperative_copy_is_refused(self):
        out = self._problems(lambda s: s["strings"].update({"offerButton": "¡Cómpralo ya!"}))
        self.assertIn("forbidden copy token", out)

    def test_luck_totem_costing_esencia_is_refused(self):
        self.assertIn("K14", self._problems(lambda s: s["totems"]["suerte"]["cost"].update({"ember": 20})))

    def test_pooled_cap_and_breeder_corral_bonus_are_refused(self):
        self.assertIn("C1", self._problems(lambda s: s["corral"].update({"pooledCapPerSlot": 0.75})))
        self.assertIn("E4", self._problems(lambda s: s["breeder"].update({"corralBonusPerLevel": 0.05})))

    def test_printed_ceiling_must_equal_the_computed_one(self):
        self.assertIn("non-cosmetic total", self._problems(lambda s: s["offerRules"].update({"nonCosmeticTotalRobux": [461, 461]})))

    def test_permissive_policy_failure_is_refused(self):
        self.assertIn("P7", self._problems(lambda s: s["policy"]["policyService"].update({"onFailure": "permissive"})))

    def test_chaleco_is_not_sold(self):
        s = syn()
        self.assertNotIn("chaleco", s["equipment"]["soldPieces"])
        row = next(r for r in s["offers"] if r["id"] == "equipoExplorador")
        self.assertNotIn("chaleco", row["pieces"])


class Ladders(unittest.TestCase):
    def test_tree_and_equipment_costs(self):
        s = syn()
        self.assertEqual(hub.tree_cost(s, 1), {"ember": 40, "common": 20, "uncommon": 10})
        self.assertEqual(hub.tree_cost(s, 3), {"ember": 250, "common": 50, "uncommon": 30, "rare": 5})
        self.assertEqual(hub.equipment_step_cost(s, 3, 1), {"ember": 200, "common": 20, "uncommon": 10})
        self.assertEqual(hub.ladder_costs(60, 1.5, 5, 4), [60, 90, 135, 200])

    def test_pens_and_p0_costs_as_roles(self):
        s = syn()
        self.assertEqual(hub.pen_cost(s, 4), {})
        self.assertEqual(hub.pen_cost(s, 6), {"ember": 150})
        self.assertEqual(hub.p0_cost_as_roles(s, {"ember": 120, "fogbark": 60, "glowmoss": 30}),
                         {"ember": 120, "common": 60, "uncommon": 30})
        with self.assertRaises(hub.TuningError):
            hub.p0_cost_as_roles(s, {"unknownMaterial": 1})


class Corral(unittest.TestCase):
    def test_duplicates_halve_then_quarter(self):
        s = syn()
        self.assertEqual(hub.nominal_rates(s, [("a", "Rara")] * 3), [0.75, 0.375, 0.1875])

    def test_best_mix_is_six_and_cap_scales_every_plaque(self):
        s = syn()
        self.assertAlmostEqual(sum(hub.nominal_rates(s, BEST)), 6.0)
        # cap with 5.0 active and 4 extra pens: 0.4 * 5 + 0.3 * 4 = 3.2
        self.assertAlmostEqual(hub.corral_cap(s, 8, 5.0), 3.2)
        credited = hub.credited_rates(s, BEST, 5.0, 1.0)
        self.assertAlmostEqual(sum(credited), 3.2)
        nominal = hub.nominal_rates(s, BEST)
        ratios = {round(c / n, 9) for c, n in zip(credited, nominal)}
        self.assertEqual(len(ratios), 1)          # proportional: rarity still pays more
        self.assertGreater(credited[-1], credited[0])

    def test_uncapped_corral_pays_nominal(self):
        s = syn()
        self.assertEqual(hub.credited_rates(s, [("a", "Comun")], 10.0, 1.0), [0.5])

    def test_working_rule_shares(self):
        s = syn()
        self.assertEqual(hub.rate_share(s, active_window=True), 1.0)
        self.assertEqual(hub.rate_share(s, active_window=False), 0.25)
        self.assertEqual(hub.rate_share(s, alive=False), 0.0)
        self.assertEqual(hub.rate_share(s, in_server=False, active_window=True), 0.0)

    def test_idle_hour_is_one_quarter_window_and_zero_unfed(self):
        s = syn()
        once = sum(hub.credited_rates(s, BEST, 100.0, 0.25)) * 20
        self.assertAlmostEqual(hub.idle_hour_credit(s, BEST, 100.0, fed=True, refeeds=2), once)
        self.assertEqual(hub.idle_hour_credit(s, BEST, 100.0, fed=False), 0.0)


class OfferRules(unittest.TestCase):
    def _player(self, s, **kw):
        player = hub.Player(s, p0_tuning(), True)
        for key, value in kw.items():
            setattr(player, key, value)
        return player

    def test_no_card_in_the_first_session(self):
        s = syn()
        player = self._player(s, session_index=1, minute_in_session=15, cumulative_minutes_before_session=0)
        self.assertFalse(hub.card_allowed(s, player, 15, "bolsaGrande", "pack"))

    def test_second_session_after_thirty_minutes_and_quiet_start(self):
        s = syn()
        player = self._player(s, session_index=2, minute_in_session=12, cumulative_minutes_before_session=20)
        self.assertTrue(hub.card_allowed(s, player, 32, "bolsaGrande", "pack"))
        player.minute_in_session = 3
        player.cumulative_minutes_before_session = 40
        self.assertFalse(hub.card_allowed(s, player, 43, "bolsaGrande", "pack"))

    def test_once_per_step_gap_and_refusal_distance(self):
        s = syn()
        player = self._player(s, session_index=3, minute_in_session=10, cumulative_minutes_before_session=40)
        player.shown_this_session = {("unCorralMas", "slot6")}
        self.assertFalse(hub.card_allowed(s, player, 50, "unCorralMas", "slot6"))
        player.shown_this_session = set()
        player.last_card_minute = 40
        self.assertFalse(hub.card_allowed(s, player, 50, "unCorralMas", "slot6"))
        player.last_card_minute = None
        player.last_refusal_or_notice_minute = 49.5
        self.assertFalse(hub.card_allowed(s, player, 50, "unCorralMas", "slot6"))
        player.last_refusal_or_notice_minute = 49
        self.assertTrue(hub.card_allowed(s, player, 50, "unCorralMas", "slot6"))

    def test_estimate_never_above_the_design_median(self):
        s = syn()
        self.assertEqual(hub.free_path_estimate(36, 80, 20, s), 36)   # struggling player: design median
        self.assertEqual(hub.free_path_estimate(36, 20, 20, s), 20)   # faster player: own figure
        self.assertEqual(hub.free_path_estimate(36, 20, 2, s), 36)    # too little data

    def test_own_minutes_include_materials_and_the_floor(self):
        s = syn()
        cost = {"ember": 200, "common": 20, "uncommon": 10}
        self.assertAlmostEqual(hub.own_minutes_for(cost, 1.0, {"common": 2.0, "uncommon": 1.0}, s), 50.0)  # floor 4/min
        self.assertAlmostEqual(hub.own_minutes_for(cost, 10.0, {"common": 0.5, "uncommon": 1.0}, s), 40.0)  # materials bind

    def test_copy_lint_uses_word_boundaries(self):
        s = syn()
        s["strings"]["offerButton"] = "Una playa · 49 Robux"
        self.assertEqual(hub.lint_copy(s), [])
        s["strings"]["offerButton"] = "Cómpralo ya"
        self.assertTrue(hub.lint_copy(s))


class Simulation(unittest.TestCase):
    def test_paying_cards_keep_the_cadence_and_the_session_rule(self):
        s = syn()
        rules = s["offerRules"]
        for seed in range(3):
            run = hub.simulate(s, p0_tuning(), paying=True, persistence=True, sessions=12, seed=seed)
            minutes = [p["minute"] for p in run["purchases"]]
            self.assertTrue(minutes, "the paying policy bought nothing")
            for purchase in run["purchases"]:
                self.assertGreaterEqual(purchase["sessionIndex"], rules["minSessionIndex"])
                self.assertGreaterEqual(purchase["minute"], rules["minCumulativeMinutes"])
            for a, b in zip(minutes, minutes[1:]):
                self.assertGreaterEqual(b - a, rules["minMinutesBetweenOffers"])
            self.assertLessEqual(run["player"].robux_spent, rules["nonCosmeticTotalRobux"][1])

    def test_sessions_are_twenty_minutes(self):
        run = hub.simulate(syn(), p0_tuning(), paying=False, persistence=True, sessions=3, seed=1)
        self.assertEqual(sorted(run["snapshots"]), [20, 40, 60])

    def test_paying_never_changes_free_prices(self):
        self.assertTrue(analysis()["K5_identical"])

    def test_persistence_off_never_reaches_tier_three(self):
        result = analysis(persistence=False, sessions=3)
        self.assertNotIn("anyTier3", {k for k, v in result["firsts_p50"].items() if v is not None})
        self.assertEqual(result["cards"]["rows_triggered"], [])   # no card can exist without the second session

    def test_document_targets_hold(self):
        s = syn()
        on = hub.analyse(s, p0_tuning(), 3, 24, 2026, persistence=True)
        off = hub.analyse(s, p0_tuning(), 3, 1, 2026, persistence=False)
        sitting_sessions = s["simulatorInputs"]["sessionOnly"]["oneSittingMinutes"] // hub.SESSION_MINUTES
        sitting = hub.analyse(s, p0_tuning(), 3, sitting_sessions, 2026, persistence=False,
                              reset_every=sitting_sessions * hub.SESSION_MINUTES)
        self.assertEqual(hub.check_targets(s, on, off, sitting), [])

    def test_doc_quotes_the_simulated_headline_numbers(self):
        result = analysis(sessions=12)
        text = DOC.read_text(encoding="utf-8")
        self.assertEqual(round(result["K3_minutes_saved_p50"]), 60)
        self.assertIn("**60 minutes later**", text)
        self.assertEqual(round(result["robux_p50"]), 127)
        self.assertIn("127 Robux", text)
        self.assertAlmostEqual(result["K4b_ratio_p50"], 1.62, delta=0.02)   # seed set differs from the 30-run report


class CommandLine(unittest.TestCase):
    def test_main_runs_clean_on_the_document(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = hub.main(["--runs", "2", "--sessions", "24"])
        self.assertEqual(code, 0, out.getvalue())
        self.assertIn("math only", out.getvalue())
        self.assertIn("Target checks: ok", out.getvalue())

    def test_main_reports_a_missing_document(self):
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            code = hub.main(["--doc", str(REPO / "no-such-doc.md")])
        self.assertEqual(code, 2)
        self.assertIn("ERROR", err.getvalue())


if __name__ == "__main__":
    unittest.main()

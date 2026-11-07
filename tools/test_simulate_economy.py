"""Contracts for the Wildbound P0 economy simulator.

Run from the project root (isolated mode, no bytecode written):

    python -I -B -m unittest discover -s tools -p "test_simulate_*.py"

The simulator reads the fenced `json economy-tuning` block of
docs/mechanics/wildbound-economy-p0.md at run time. These tests therefore
restate hand-derived numbers (the loss table, hand-measured tours) and pin
them against the document, instead of importing the numbers from the module.

They model math only. They say nothing about fun or balance.
"""

import contextlib
import copy
import io
import math
import re
import unittest
from pathlib import Path

import simulate_economy as eco

REPO = Path(__file__).resolve().parent.parent
DOC = REPO / "docs/mechanics/wildbound-economy-p0.md"

_CACHE = {}


def tuning():
    if "t" not in _CACHE:
        _CACHE["t"] = eco.load_tuning(DOC)
    return copy.deepcopy(_CACHE["t"])


def context():
    if "c" not in _CACHE:
        _CACHE["c"] = eco.load_context(REPO)
    return _CACHE["c"]


def targets():
    """One seeded analysis shared by the target tests. Invented archetypes: this pins structure, not fun."""
    if "s" not in _CACHE:
        _CACHE["s"] = eco.analyse_policies(tuning(), context(), runs=30, trips=90, seed=2026)
    return _CACHE["s"]


def idle_policy(**overrides):
    policy = {"zones": {"outside": 0, "fog": 0, "territory": 0}, "captureTier": None,
              "captureRate": 0.0, "eggRate": 0.0, "defeatChance": 0.0}
    policy.update(overrides)
    return policy


class TuningBlock(unittest.TestCase):
    def test_block_is_read_from_the_document(self):
        t = tuning()
        self.assertEqual(t["schema"], "wildbound.economy.tuning")
        self.assertEqual(t["schemaVersion"], 1)
        self.assertEqual(t["monetization"], "none")
        self.assertIn("```json economy-tuning", DOC.read_text(encoding="utf-8"))

    def test_numbers_are_consumed_not_copied(self):
        # Change the rate inside the document text; the simulator must follow it.
        text = DOC.read_text(encoding="utf-8").replace('"rateBasisPoints": 5000', '"rateBasisPoints": 1000')
        t = eco.extract_tuning(text)
        state = eco.new_state(t)
        state["carried"]["fogbark"] = 100
        eco.apply_defeat(t, state)
        self.assertEqual(state["carried"]["fogbark"], 90)

    def test_missing_duplicate_or_bad_block_fails_loudly(self):
        good = DOC.read_text(encoding="utf-8")
        with self.assertRaises(eco.TuningError):
            eco.extract_tuning("# nothing here")
        block = re.search(r"```json economy-tuning\n.*?```", good, re.S).group(0)
        with self.assertRaises(eco.TuningError):
            eco.extract_tuning(good + "\n" + block)
        with self.assertRaises(eco.TuningError):
            eco.extract_tuning(good.replace('"schemaVersion": 1', '"schemaVersion": 2'))
        with self.assertRaises(eco.TuningError):
            eco.extract_tuning(good.replace('"schema": "wildbound.economy.tuning"', '"schema": "other"'))
        with self.assertRaises(eco.TuningError):
            eco.extract_tuning(good.replace('"monetization": "none",', '"monetization": "none"  oops'))
        with self.assertRaises(eco.TuningError):
            eco.extract_tuning(good.replace('"monetization": "none"', '"monetization": "robux"'))


class LossRule(unittest.TestCase):
    # Hand computed: (q * bp + 5000) // 10000, i.e. nearest, halves up.
    #   100: 12.00 -> 12, 8.00 -> 8     25: 3.00 -> 3, 2.00 -> 2
    #   12: 1.44 -> 1, 0.96 -> 1        5: 0.60 -> 1, 0.40 -> 0
    #   4: 0.48 -> 0, 0.32 -> 0         1: 0.12 -> 0, 0.08 -> 0
    TABLE = {100: (12, 8), 25: (3, 2), 12: (1, 1), 5: (1, 0), 4: (0, 0), 1: (0, 0), 0: (0, 0)}
    # The rates the document now uses, hand computed the same way:
    #   100: 50, 25     25: 12.5 -> 13, 6.25 -> 6     12: 6, 3     5: 2.5 -> 3, 1.25 -> 1
    #   4: 2, 1         1: 0.5 -> 1, 0.25 -> 0
    NEW_TABLE = {100: (50, 25), 25: (13, 6), 12: (6, 3), 5: (3, 1), 4: (2, 1), 1: (1, 0), 0: (0, 0)}

    def test_rounding_table_for_both_rates(self):
        for quantity, (at12, at8) in self.TABLE.items():
            self.assertEqual(eco.lost(quantity, 1200), at12, quantity)
            self.assertEqual(eco.lost(quantity, 800), at8, quantity)
        for quantity, (at50, at25) in self.NEW_TABLE.items():
            self.assertEqual(eco.lost(quantity, 5000), at50, quantity)
            self.assertEqual(eco.lost(quantity, 2500), at25, quantity)

    def test_half_rounds_up_exactly(self):
        # 50 * 1000 bp = exactly 5.0 -> 5; 25 * 200 bp = 0.5 exactly -> 1; 24 * 200 bp = 0.48 -> 0.
        self.assertEqual(eco.lost(25, 200), 1)
        self.assertEqual(eco.lost(24, 200), 0)
        self.assertEqual(eco.lost(50, 1000), 5)

    def test_integer_arithmetic_has_no_float_error(self):
        big = 10 ** 18
        self.assertEqual(eco.lost(big, 1200), 12 * 10 ** 16)
        self.assertIsInstance(eco.lost(7, 1200), int)

    def test_document_table_agrees_with_the_rule(self):
        text = DOC.read_text(encoding="utf-8")
        rows = re.findall(r"^\| (\d+) \| (\d+) \| (\d+) \|$", text, re.M)
        self.assertGreaterEqual(len(rows), 6)
        for quantity, at_base, at_reinforced in rows:
            self.assertEqual(self.NEW_TABLE[int(quantity)], (int(at_base), int(at_reinforced)), quantity)

    def test_defeat_with_100_fogbark_and_three_items(self):
        t = tuning()
        s = eco.new_state(t)
        s["carried"]["fogbark"] = 100
        s["ember"] = 30
        s["bag"] = [{"kind": "creature", "tier": "Territory"}, {"kind": "egg", "tier": "Territory"},
                    {"kind": "creature", "tier": "Fog"}]
        summary = eco.apply_defeat(t, s)
        self.assertEqual(s["carried"]["fogbark"], 50)
        self.assertEqual(s["bag"], [])
        self.assertEqual(s["ember"], 30)
        self.assertEqual(summary["lost_items"], 3)
        self.assertEqual(summary["lost_units"]["fogbark"], 50)

    def test_loss_is_per_stack_not_on_the_total(self):
        # Two stacks of 5 lose 3 each (2.5 rounds up), so 6. Rounding the 10-unit total at 50% would give 5.
        t = tuning()
        s = eco.new_state(t)
        s["carried"].update({"fogbark": 5, "glowmoss": 5})
        eco.apply_defeat(t, s)
        self.assertEqual(s["carried"], {"fogbark": 2, "glowmoss": 2})

    def test_reinforced_pack_lowers_the_rate(self):
        t = tuning()
        s = eco.new_state(t)
        s["upgrades"]["reinforcedPack"] = True
        s["carried"]["fogbark"] = 100
        eco.apply_defeat(t, s)
        self.assertEqual(s["carried"]["fogbark"], 75)

    def test_everything_listed_as_never_lost_is_untouched(self):
        t = tuning()
        s = eco.new_state(t)
        s["ember"] = 77
        s["banked"].update({"fogbark": 50, "glowmoss": 20, "nightbloom": 3})
        s["registered"] = [{"kind": "creature", "tier": "Fog"}]
        s["bankedEggs"] = [{"kind": "egg", "tier": "Territory"}]
        s["consumables"].update({"seal": 2, "capsule": 1, "totem": 1})
        s["upgrades"]["reinforcedPack"] = True
        s["skills"].update({"explorer_1": True})
        s["bond"] = {"pet-1": {"xp": 40, "level": 2}}
        s["carried"]["fogbark"] = 30
        s["bag"] = [{"kind": "egg", "tier": "Territory"}]
        before = copy.deepcopy(s)
        for key in t["loss"]["neverLost"]:
            self.assertIn(key, s, "state does not model neverLost entry " + key)
        eco.apply_defeat(t, s)
        for key in t["loss"]["neverLost"]:
            self.assertEqual(s[key], before[key], key)

    def test_same_operation_twice_loses_once(self):
        t = tuning()
        s = eco.new_state(t)
        s["carried"]["fogbark"] = 100
        eco.apply_defeat(t, s, operation_id="op-1")
        self.assertEqual(s["carried"]["fogbark"], 50)
        again = eco.apply_defeat(t, s, operation_id="op-1")
        self.assertEqual(s["carried"]["fogbark"], 50)
        self.assertTrue(again["duplicate"])

    def test_seal_spent_only_when_it_saves_an_item(self):
        t = tuning()
        s = eco.new_state(t)
        s["consumables"]["seal"] = 1
        eco.apply_defeat(t, s, use_seal=True)          # nothing in the bag: nothing to save
        self.assertEqual(s["consumables"]["seal"], 1)
        s["bag"] = [{"kind": "creature", "tier": "Fog"}, {"kind": "egg", "tier": "Territory"}]
        summary = eco.apply_defeat(t, s, use_seal=True)
        self.assertEqual(s["consumables"]["seal"], 0)
        self.assertEqual(len(s["bag"]), 1)
        self.assertEqual(summary["lost_items"], 1)
        self.assertEqual(s["bag"][0]["kind"], "egg")  # the newest item is the warded one

    def test_night_does_not_change_the_rate(self):
        self.assertIs(tuning()["loss"]["nightChangesRate"], False)


class Weights(unittest.TestCase):
    def test_normalize(self):
        self.assertEqual(eco.normalize({"a": 3, "b": 1}), {"a": 0.75, "b": 0.25})
        self.assertEqual(eco.normalize({"a": 5}), {"a": 1.0})
        self.assertEqual(eco.normalize({"a": 0, "b": 2}), {"a": 0.0, "b": 1.0})

    def test_bad_weights_are_rejected(self):
        for bad in ({}, {"a": 0}, {"a": -1, "b": 3}, {"a": float("nan")}):
            with self.assertRaises(eco.TuningError):
                eco.normalize(bad)

    def test_every_table_normalizes_to_one(self):
        t = tuning()
        for zone, phases in t["spawnWeights"].items():
            for phase in t["cycle"]["phaseOrder"]:
                probabilities = eco.spawn_probabilities(t, zone, phase)
                self.assertAlmostEqual(sum(probabilities.values()), 1.0, places=12, msg=(zone, phase))

    def test_night_only_materials_appear_only_at_night(self):
        t = tuning()
        for zone in t["spawnWeights"]:
            for phase in t["cycle"]["phaseOrder"]:
                probabilities = eco.spawn_probabilities(t, zone, phase)
                for material, spec in t["materials"].items():
                    if spec["nightOnly"] and phase != "Night":
                        self.assertEqual(probabilities.get(material, 0.0), 0.0, (zone, phase))

    def test_document_percentages_agree_with_the_json(self):
        text = DOC.read_text(encoding="utf-8")
        rows = re.findall(
            r"^\| (Outside, any|Fog, not Night|Fog, Night|Territory, not Night|Territory, Night)"
            r" \| ([\d.]+)% \| ([\d.]+)% \| ([\d.]+%|0) \|$", text, re.M)
        self.assertEqual(len(rows), 5)
        t = tuning()
        for label, fogbark, glowmoss, nightbloom in rows:
            zone = label.split(",")[0].lower()
            phase = "Night" if label.endswith("Night") and "not" not in label else "Day"
            p = eco.spawn_probabilities(t, zone, phase)
            self.assertAlmostEqual(100 * p["fogbark"], float(fogbark), places=6, msg=label)
            self.assertAlmostEqual(100 * p["glowmoss"], float(glowmoss), places=6, msg=label)
            expected = 0.0 if nightbloom == "0" else float(nightbloom.rstrip("%"))
            self.assertAlmostEqual(100 * p.get("nightbloom", 0.0), expected, places=6, msg=label)

    def test_seeded_draws_follow_the_table_and_repeat(self):
        t = tuning()
        expected = eco.spawn_probabilities(t, "territory", "Night")   # 25 / 40 / 35
        import random
        counts = {m: 0 for m in expected}
        rng = random.Random(7)
        for _ in range(100000):
            counts[eco.draw_material(t, "territory", "Night", rng)] += 1
        for material, p in expected.items():
            self.assertAlmostEqual(counts[material] / 100000, p, delta=0.01, msg=material)
        a = [eco.draw_material(t, "fog", "Night", random.Random(3)) for _ in range(5)]
        b = [eco.draw_material(t, "fog", "Night", random.Random(3)) for _ in range(5)]
        self.assertEqual(a, b)

    def test_yields_are_inclusive_ranges(self):
        t = tuning()
        import random
        rng = random.Random(1)
        seen = {eco.draw_yield(t, "territory", "fogbark", rng) for _ in range(200)}
        self.assertEqual(seen, {2, 3})   # [2, 3] inclusive
        seen = {eco.draw_yield(t, "fog", "glowmoss", rng) for _ in range(50)}
        self.assertEqual(seen, {2})      # [2, 2]


class Sinks(unittest.TestCase):
    def funded(self, **banked):
        t = tuning()
        s = eco.new_state(t)
        s["banked"].update({k: v for k, v in banked.items() if k != "ember"})
        s["ember"] = banked.get("ember", 0)
        return t, s

    def test_craft_pays_exactly_the_cost(self):
        t, s = self.funded(fogbark=8, glowmoss=4)
        self.assertEqual(eco.craft(t, s, "seal"), (True, "ok"))
        self.assertEqual(s["banked"], {"fogbark": 0, "glowmoss": 0, "nightbloom": 0})
        self.assertEqual(s["consumables"]["seal"], 1)

    def test_one_short_is_refused_and_changes_nothing(self):
        t, s = self.funded(fogbark=8, glowmoss=3)
        before = copy.deepcopy(s)
        self.assertEqual(eco.craft(t, s, "seal"), (False, "CannotAfford"))
        self.assertEqual(s, before)

    def test_cap_and_unknown_recipe(self):
        t, s = self.funded(fogbark=100, glowmoss=100)
        for _ in range(3):
            self.assertTrue(eco.craft(t, s, "seal")[0])
        before = copy.deepcopy(s)
        self.assertEqual(eco.craft(t, s, "seal"), (False, "AtLimit"))
        self.assertEqual(eco.craft(t, s, "nonsense"), (False, "UnknownRecipe"))
        self.assertEqual(s, before)

    def test_ember_is_a_cost_and_never_goes_negative(self):
        t, s = self.funded(fogbark=8, glowmoss=5, nightbloom=1, ember=11)
        self.assertEqual(eco.craft(t, s, "capsule"), (False, "CannotAfford"))
        s["ember"] = 12
        self.assertEqual(eco.craft(t, s, "capsule"), (True, "ok"))
        self.assertEqual(s["ember"], 0)

    def test_reinforced_pack_once_and_it_changes_capacity(self):
        t, s = self.funded(fogbark=120, glowmoss=60, ember=240)
        self.assertEqual((eco.pouch_capacity(t, s), eco.bag_capacity(t, s)), (30, 3))
        self.assertEqual(eco.upgrade(t, s, "reinforcedPack"), (True, "ok"))
        self.assertEqual((eco.pouch_capacity(t, s), eco.bag_capacity(t, s)), (45, 4))
        self.assertEqual(eco.loss_basis_points(t, s), 2500)
        self.assertEqual(eco.upgrade(t, s, "reinforcedPack"), (False, "AlreadyOwned"))
        self.assertEqual((s["banked"]["fogbark"], s["banked"]["glowmoss"], s["ember"]), (60, 30, 120))

    def test_skill_prerequisites_and_repeat(self):
        t, s = self.funded(fogbark=100, glowmoss=60, nightbloom=6, ember=300)
        self.assertEqual(eco.learn(t, s, "explorer_2"), (False, "NeedsPrerequisite"))
        self.assertEqual(eco.learn(t, s, "explorer_1"), (True, "ok"))
        self.assertEqual(eco.learn(t, s, "explorer_1"), (False, "AlreadyOwned"))
        self.assertEqual(eco.learn(t, s, "explorer_2"), (True, "ok"))
        self.assertEqual(eco.learn(t, s, "no_such_skill"), (False, "UnknownSkill"))
        self.assertEqual((s["ember"], s["banked"]["fogbark"], s["banked"]["glowmoss"], s["banked"]["nightbloom"]),
                         (300 - 40 - 100, 100 - 20 - 30, 60 - 10 - 20, 6 - 3))

    def test_buy_affordable_takes_cheapest_first_and_repeats(self):
        # 40 Ember, 20 Fogbark and 10 Glowmoss buy exactly one tier 1 skill. All four cost the same,
        # so the tie breaks on id, and capturer_1 sorts first.
        t, s = self.funded(fogbark=20, glowmoss=10, ember=40)
        self.assertEqual(eco.buy_affordable(t, s), ["capturer_1"])
        # Rich enough for everything: all 8 skills plus the pack, tier 1 before tier 2.
        t, s = self.funded(fogbark=500, glowmoss=500, nightbloom=50, ember=1000)
        bought = eco.buy_affordable(t, s)
        self.assertEqual(len(bought), 9)
        self.assertEqual(set(bought), set(t["skills"]) | set(t["upgrades"]))
        for skill_id, spec in t["skills"].items():
            for required in spec["requires"]:
                self.assertLess(bought.index(required), bought.index(skill_id))


class ExtractionAndAfk(unittest.TestCase):
    def test_base_ember_conditions(self):
        t = tuning()
        paid = lambda secs, dist, units: eco.base_ember(t, secs, dist, units)
        self.assertEqual(paid(45.0, 60.0, 1), 4)
        self.assertEqual(paid(44.9, 60.0, 1), 0)
        self.assertEqual(paid(45.0, 59.9, 1), 0)
        self.assertEqual(paid(45.0, 60.0, 0), 0)

    def test_extraction_ember_exact_payout(self):
        t = tuning()
        both = [{"kind": "creature", "tier": "Territory"}, {"kind": "egg", "tier": "Territory"}]
        self.assertEqual(eco.extraction_ember(t, both, 60.0, 70.0, 5), 4 + 14 + 10)
        self.assertEqual(eco.extraction_ember(t, [{"kind": "creature", "tier": "Fog"}], 44.0, 70.0, 1), 8)
        self.assertEqual(eco.extraction_ember(t, [{"kind": "creature", "tier": "Safe"}], 90.0, 70.0, 1), 4 + 6)
        self.assertEqual(eco.extraction_ember(t, [], 90.0, 70.0, 3), 4)   # materials-only trip
        self.assertEqual(eco.extraction_ember(t, [], 90.0, 70.0, 0), 0)   # empty trip

    def test_idle_hour_changes_nothing(self):
        t = tuning()
        s = eco.new_state(t)
        s["banked"]["fogbark"], s["ember"], s["carried"]["glowmoss"] = 9, 5, 2
        before = copy.deepcopy(s)
        eco.advance_idle(t, s, 3600.0)
        self.assertEqual(s, before)

    def test_staying_home_earns_nothing(self):
        t, ctx = tuning(), context()
        run = eco.simulate_policy(t, ctx, "idle", idle_policy(), seed=1, trips=60)
        self.assertEqual(run.state, eco.new_state(t))
        self.assertTrue(all(trip["outcome"] == "empty" for trip in run.trips))
        self.assertEqual(sum(trip["ember_gained"] for trip in run.trips), 0)

    def test_antiafk_block_is_zero(self):
        a = tuning()["antiAfk"]
        self.assertEqual((a["timeBasedGrants"], a["idleHourExpectedDelta"]), (0, 0))


class Expeditions(unittest.TestCase):
    def mini(self, slots=("O1", "O2")):
        t = tuning()
        t["gather"]["slots"] = [s for s in t["gather"]["slots"] if s["id"] in slots]
        t["spawnWeights"]["outside"] = {p: {"fogbark": 100} for p in t["cycle"]["phaseOrder"]}
        t["yields"]["outside"] = {"fogbark": [3, 3]}
        return t

    def test_two_outside_nodes_hand_tour(self):
        # Camp (-140,140) -> O1 (-120,110): 36.056; O1 -> O2 (-70,40): 86.023; O2 -> camp: 122.066.
        # 244.145 studs at 16 studs/s = 15.259 s, plus two 3.0 s outside holds = 21.259 s (under 45 s: no base Ember).
        # Six units of 30 is under the first load step, so the pouch does not slow the walk.
        t, ctx = self.mini(), context()
        run = eco.simulate_policy(t, ctx, "mini", idle_policy(zones={"outside": 2, "fog": 0, "territory": 0}),
                                  seed=5, trips=1)
        trip = run.trips[0]
        walk = (math.dist((-140, 140), (-120, 110)) + math.dist((-120, 110), (-70, 40))
                + math.dist((-70, 40), (-140, 140)))
        self.assertAlmostEqual(trip["seconds"], walk / 16.0 + 6.0, places=6)
        self.assertEqual(run.state["banked"]["fogbark"], 6)    # 2 nodes x 3
        self.assertEqual(run.state["ember"], 0)
        self.assertEqual(trip["outcome"], "extracted")
        self.assertAlmostEqual(trip["max_distance"], math.dist((-140, 140), (-70, 40)), places=6)

    def test_safe_capture_hand_trip(self):
        # S0a (-95,75) is 79.06 studs from camp; out and back at 16 studs/s plus a 5.5 s capture
        # is 15.4 s: too short for the base 4, so only the Safe creature's 6 Ember pays.
        t, ctx = tuning(), context()
        policy = idle_policy(captureTier="Safe", captureRate=1.0)
        run = eco.simulate_policy(t, ctx, "safe", policy, seed=1, trips=1)
        d = math.dist((-140, 140), (-95, 75))
        self.assertAlmostEqual(run.trips[0]["seconds"], 2 * d / 16.0 + 5.5, places=6)
        self.assertEqual(run.state["ember"], 6)
        self.assertEqual(len(run.state["registered"]), 1)
        self.assertEqual(run.state["consumables"]["seal"], 1)   # first-extraction seal

    def test_first_extraction_seal_is_granted_once_and_capped(self):
        t, ctx = tuning(), context()
        policy = idle_policy(captureTier="Safe", captureRate=1.0)
        run = eco.simulate_policy(t, ctx, "safe", policy, seed=1, trips=3)
        self.assertEqual(run.state["consumables"]["seal"], 1)

    def test_runs_are_deterministic_and_seeds_differ(self):
        t, ctx = tuning(), context()
        policy = t["simulatorInputs"]["archetypes"]["balanced"]
        a = eco.simulate_policy(t, ctx, "balanced", policy, seed=11, trips=20)
        b = eco.simulate_policy(t, ctx, "balanced", policy, seed=11, trips=20)
        c = eco.simulate_policy(t, ctx, "balanced", policy, seed=12, trips=20)
        self.assertEqual(a.trips, b.trips)
        self.assertEqual(a.state, b.state)
        self.assertNotEqual(a.trips, c.trips)

    def test_capacity_is_never_exceeded_and_units_balance(self):
        t, ctx = tuning(), context()
        for name, policy in t["simulatorInputs"]["archetypes"].items():
            run = eco.simulate_policy(t, ctx, name, policy, seed=3, trips=40)
            for trip in run.trips:
                self.assertLessEqual(trip["units_carried"], trip["pouch_capacity"], name)
                self.assertLessEqual(trip["bag_items"], trip["bag_capacity"], name)
                self.assertEqual(trip["units_gathered"], trip["units_carried"] + trip["units_wasted"], name)

    def test_solo_supply_limits_nodes_without_waiting(self):
        # Only 2 outside nodes are active for one player, so a plan for 4 gathers 2 unless
        # a claimed node has respawned (75 s) by the time the player is ready for another.
        t = self.mini(slots=("O1", "O2", "O3", "O4"))
        t["gather"]["respawnSeconds"] = 10 ** 9
        t["gather"]["activeByPlayers"][0]["outside"] = 2   # the rule under test, not the document's count
        ctx = context()
        run = eco.simulate_policy(t, ctx, "greedy-outside", idle_policy(zones={"outside": 4, "fog": 0, "territory": 0}),
                                  seed=2, trips=1)
        self.assertEqual(run.trips[0]["nodes_gathered"], 2)
        self.assertEqual(run.trips[0]["nodes_wanted"], 4)

    def test_defeat_applies_the_loss_rule_to_the_trip(self):
        t, ctx = self.mini(), context()
        policy = idle_policy(zones={"outside": 2, "fog": 0, "territory": 0}, defeatChance=1.0)
        run = eco.simulate_policy(t, ctx, "doomed", policy, seed=4, trips=1)
        # 6 fogbark in one stack: lost(6) = (6*5000+5000)//10000 = 3, so 3 stay carried.
        self.assertEqual(run.trips[0]["outcome"], "defeated")
        self.assertEqual(run.state["carried"]["fogbark"], 3)
        self.assertEqual(run.state["banked"]["fogbark"], 0)
        self.assertEqual(run.state["ember"], 0)


class Invariants(unittest.TestCase):
    def check(self, mutate):
        t = tuning()
        mutate(t)
        return eco.check_invariants(t, context())

    def test_real_tuning_passes(self):
        self.assertEqual(eco.check_invariants(tuning(), context()), [])

    def test_phases_must_sum_to_the_cycle(self):
        problems = self.check(lambda t: t["cycle"]["phases"].__setitem__("Day", 361))
        self.assertTrue(any("phases" in p for p in problems), problems)

    def test_night_only_material_in_a_day_table_is_caught(self):
        problems = self.check(lambda t: t["spawnWeights"]["fog"]["Day"].__setitem__("nightbloom", 5))
        self.assertTrue(any("nightbloom" in p for p in problems), problems)

    def test_empty_weight_table_is_caught(self):
        problems = self.check(lambda t: t["spawnWeights"]["outside"].__setitem__("Day", {"fogbark": 0}))
        self.assertTrue(problems)

    def test_slot_in_the_wrong_zone_is_caught(self):
        problems = self.check(lambda t: t["gather"]["slots"][0].__setitem__("zone", "territory"))
        self.assertTrue(any("O1" in p and "zone" in p for p in problems), problems)

    def test_slot_in_a_safe_circle_or_off_the_map_is_caught(self):
        problems = self.check(lambda t: t["gather"]["slots"][0].update(x=-140, z=140))
        self.assertTrue(any("O1" in p for p in problems), problems)
        problems = self.check(lambda t: t["gather"]["slots"][0].update(x=250))
        self.assertTrue(any("O1" in p and "map" in p for p in problems), problems)

    def test_tier2_without_a_tier1_prerequisite_is_caught(self):
        problems = self.check(lambda t: t["skills"]["explorer_2"].__setitem__("requires", []))
        self.assertTrue(any("explorer_2" in p for p in problems), problems)

    def test_seal_must_be_affordable_from_outside_and_fog(self):
        problems = self.check(lambda t: t["recipes"]["seal"]["cost"].__setitem__("nightbloom", 1))
        self.assertTrue(any("seal" in p for p in problems), problems)

    def test_standing_still_must_stay_below_calm_required(self):
        # Stationary maximum is about 3.6 s: a calmRequired of 3.5 would let standing still win.
        problems = self.check(lambda t: t["skills"]["capturer_1"]["effects"].__setitem__("calmRequired", 3.5))
        self.assertTrue(any("calm" in p.lower() for p in problems), problems)

    def test_reinforced_loss_must_match_the_loss_block(self):
        problems = self.check(lambda t: t["upgrades"]["reinforcedPack"]["effects"].__setitem__("lossBasisPoints", 700))
        self.assertTrue(any("loss" in p.lower() for p in problems), problems)

    def test_stationary_calm_hand_values(self):
        # Ring centre is 2 r sin(w t / 2) from a still player, w = speed / r. It leaves the
        # server radius R when sin(w t / 2) = R / (2 r): t = (2 r / speed) * asin(R / (2 r)).
        ring = context().ring
        for r in (4.0, 9.0):
            expected = (2 * r / ring["speed"]) * math.asin(ring["radius_server"] / (2 * r))
            self.assertAlmostEqual(eco.stationary_calm_seconds(ring, r), expected, places=9)
        # r=4: (2*4/1.5) * asin(5/8) = 5.3333 * 0.67513 = 3.6007 s, the document's "about 3.6".
        self.assertAlmostEqual(eco.stationary_calm_seconds(ring, 4.0), 3.6007, delta=0.001)
        self.assertAlmostEqual(eco.stationary_calm_max(ring), 3.6007, delta=0.001)
        self.assertEqual(ring["radius_server"], 5.0)


class StayOrReturn(unittest.TestCase):
    def test_expected_yield_hand_value(self):
        # Territory by day: 40% fogbark [2,3] avg 2.5, 60% glowmoss [2,2] -> 1.0 + 1.2 = 2.2 units.
        self.assertAlmostEqual(eco.expected_units(tuning(), "territory", "Day"), 2.2, places=9)
        # Territory at night adds Nightbloom [1,2] avg 1.5 at 35%: .25*2.5 + .40*2 + .35*1.5 = 1.95.
        self.assertAlmostEqual(eco.expected_units(tuning(), "territory", "Night"), 1.95, places=9)

    def test_worst_loss_matches_a_brute_force_split(self):
        # The pouch holds two stacks now; Nightbloom is a bag item.
        t = tuning()
        for capacity, basis in ((30, 5000), (45, 2500)):
            best = max(eco.lost(a, basis) + eco.lost(capacity - a, basis) for a in range(capacity + 1))
            self.assertEqual(eco.max_material_loss(t, capacity, basis), best)
            self.assertGreaterEqual(best, eco.lost(capacity, basis))

    def test_breakeven_hazard_uses_those_two_numbers(self):
        t, ctx = tuning(), context()
        result = eco.stay_or_return(t, ctx)["territory"]
        loss = eco.max_material_loss(t, 30, t["loss"]["rateBasisPoints"])
        self.assertAlmostEqual(result["breakeven_hazard"], result["expected_units_day"] / loss, places=9)
        self.assertEqual(result["materials_never_justify_returning"],
                         result["breakeven_hazard"] > result["worst_hold_hazard"])

    def test_materials_alone_can_justify_returning(self):
        # Target: was 0.82 against 0.30, so materials never mattered.
        result = eco.stay_or_return(tuning(), context())["territory"]
        self.assertFalse(result["materials_never_justify_returning"], result)

    def test_the_same_node_flips_from_stay_to_leave_as_the_load_grows(self):
        # Target: a real decision means one slot, one hazard, and the answer depends on what you carry.
        decisions = eco.load_decisions(tuning(), context())
        light, loaded = decisions["states"]["light_marked"], decisions["states"]["loaded_marked"]
        self.assertGreater(light["loss"], 0)
        self.assertGreater(loaded["loss"], 2 * light["loss"])
        self.assertLess(loaded["breakeven"], light["breakeven"])
        flipping = [row for row in decisions["slots"]
                    if loaded["breakeven"] < row["hazard"] < light["breakeven"]]
        self.assertTrue(flipping, decisions)

    def test_an_unmarked_player_risks_far_less_than_a_marked_one(self):
        # D6: the first strike takes one item, the second takes the trip.
        states = eco.load_decisions(tuning(), context())["states"]
        self.assertLess(states["loaded_unmarked"]["loss"], states["loaded_marked"]["loss"] / 2)
        self.assertGreater(states["loaded_unmarked"]["breakeven"], states["loaded_marked"]["breakeven"])


class PackAndSinks(unittest.TestCase):
    def test_pack_loss_comparison_hand_values(self):
        # Target: the old 8% on 45 lost the same 3.60 as 12% on 30, so the rate did nothing when full.
        # Base pouch 30 at 50%: 15 expected units lost when full. Reinforced 45 at 25%: 11.25, a real gain.
        result = eco.pack_loss_comparison(tuning())
        self.assertAlmostEqual(result["base_expected"], 15.0, places=9)
        self.assertAlmostEqual(result["reinforced_expected"], 11.25, places=9)
        self.assertFalse(result["rate_cancelled_by_capacity"])
        self.assertLess(result["reinforced_worst"], result["base_worst"])
        self.assertEqual(result["base_worst"], eco.max_material_loss(tuning(), 30, 5000))
        self.assertEqual(result["reinforced_worst"], eco.max_material_loss(tuning(), 45, 2500))

    def test_pack_that_helps_nothing_is_flagged(self):
        t = tuning()
        t["loss"]["rateBasisPointsReinforced"] = 3400
        t["upgrades"]["reinforcedPack"]["effects"]["lossBasisPoints"] = 3400
        self.assertTrue(eco.pack_loss_comparison(t)["rate_cancelled_by_capacity"])   # 45 * 34% = 15.3

    def test_materials_a_policy_never_earns_block_the_recipes_that_need_them(self):
        # Deliberately reversed: this used to pin cautious to never earning Nightbloom, which was the defect.
        t, ctx = tuning(), context()
        no_fog = copy.deepcopy(t["simulatorInputs"]["archetypes"]["cautious"])
        no_fog["zones"]["fog"] = 0
        summary = eco.analyse_policies(t, ctx, runs=4, trips=30, seed=77, policies={"no_fog": no_fog})
        self.assertEqual(summary["no_fog"]["never_earned"], ["nightbloom"])
        self.assertEqual(summary["no_fog"]["blocked_recipes"], ["capsule", "totem"])

    def test_completion_is_when_everything_purchasable_is_owned(self):
        # Deliberately changed: cautious used to be pinned at a completion share of 0.
        summary = targets()
        done = summary["balanced"]["completion"]
        self.assertEqual(done["reached_share"], 1.0)
        # Completion cannot come before the slowest single upgrade's own median first purchase.
        slowest = max(row["median_trip"] for row in summary["balanced"]["upgrades"].values())
        self.assertGreaterEqual(done["median_trip"], slowest)
        self.assertGreater(done["median_minutes"], 0)


class EconomyTargets(unittest.TestCase):
    """What a simulated run must yield. Invented archetypes: this pins structure, not fun."""

    def test_expedition_length_reaches_the_target(self):
        # Target from D5. Was 52, 73 and 77 s.
        low, high = tuning()["cycle"]["targetExpeditionSeconds"]
        for name, row in targets().items():
            self.assertGreaterEqual(row["seconds_median"], low, name)
            self.assertLessEqual(row["seconds_median"], high, name)

    def test_length_does_not_come_from_walking_alone_or_from_waits(self):
        # The 798-stud route is 50 s. Walking must not be the whole story, and no second is an idle wait.
        for name, row in targets().items():
            self.assertLess(row["time_share"]["walk"], 0.75, name)
            self.assertGreater(row["time_share"]["hold"] + row["time_share"]["capture"], 0.2, name)
            self.assertAlmostEqual(sum(row["time_share"].values()), 1.0, places=9, msg=name)
            self.assertEqual(set(row["time_share"]), {"walk", "hold", "capture", "evade"}, name)

    def test_holds_grow_only_with_exposure(self):
        # A long hold is only defensible where standing still is the risk.
        holds = tuning()["gather"]["holdSeconds"]
        self.assertLess(holds["outside"], holds["fog"])
        self.assertLess(holds["fog"], holds["territory"])
        self.assertLess(holds["territory"], holds["heart"])
        self.assertLessEqual(holds["outside"], 3)
        self.assertLessEqual(holds["fog"], 4)

    def test_solo_supply_is_not_what_ends_trips(self):
        # Was 4.0 of 7.0 planned nodes.
        for name, row in targets().items():
            self.assertLess(row["ended_by"].get("supply", 0.0), 0.5, name)

    def test_staying_pays_when_risk_is_accepted(self):
        summary = targets()
        safe = summary["cautious"]["value_per_minute"]
        self.assertGreater(summary["balanced"]["value_per_minute"], 1.15 * safe)
        self.assertGreater(summary["greedy"]["value_per_minute"], 1.05 * safe)
        self.assertGreater(summary["greedy"]["strikes_per_trip"], summary["balanced"]["strikes_per_trip"])
        self.assertGreater(summary["greedy"]["defeat_rate"], summary["balanced"]["defeat_rate"])

    def test_leaving_pays_when_loaded(self):
        # Same player, same nerve at a hold; the only difference is whether they walk home once loaded or marked.
        t, ctx = tuning(), context()
        base = t["simulatorInputs"]["archetypes"]["greedy"]
        stays, leaves = copy.deepcopy(base), copy.deepcopy(base)
        stays["riskAversion"], leaves["riskAversion"] = 0.0, 1.0
        summary = eco.analyse_policies(t, ctx, runs=30, trips=40, seed=2026, policies={"stays": stays, "leaves": leaves})
        self.assertGreater(summary["leaves"]["value_per_minute"], summary["stays"]["value_per_minute"])
        self.assertLess(summary["leaves"]["defeat_rate"], summary["stays"]["defeat_rate"])
        self.assertGreater(summary["stays"]["defeat_rate"], 0.0)

    def test_risk_decisions_really_end_trips(self):
        for name in ("balanced", "greedy"):
            ended = targets()[name]["ended_by"]
            self.assertGreater(ended.get("risk", 0.0), 0.05, (name, ended))
            self.assertLess(max(ended.values()), 0.85, (name, ended))

    def test_bag_pressure(self):
        # Was 0% of trips for every policy, at most 2 of 3.
        summary = targets()
        self.assertGreaterEqual(summary["balanced"]["bag_full_share"], 0.25)
        self.assertGreaterEqual(summary["greedy"]["bag_full_share"], 0.25)
        self.assertGreaterEqual(summary["cautious"]["bag_full_share"], 0.10)
        for name, row in summary.items():
            self.assertGreaterEqual(row["bag_max"], 3, name)

    def test_pouch_pressure(self):
        # Was 0 to 5% of trips. Balanced and greedy must feel it across the whole run. A cautious route carries
        # too little to fill the Reinforced Pack's 45, so it must feel it on the base pouch, before that purchase.
        summary = targets()
        self.assertGreaterEqual(summary["balanced"]["pouch_full_share"], 0.20)
        self.assertGreaterEqual(summary["greedy"]["pouch_full_share"], 0.20)
        for name, row in summary.items():
            self.assertGreaterEqual(row["pouch_full_share_base_pack"], 0.20, name)

    def test_progress_spans_several_sessions(self):
        # Was 18 to 21 minutes to own everything. A session is F1's 20 minutes.
        summary = targets()
        for name, row in summary.items():
            self.assertGreaterEqual(row["completion"]["reached_share"], 0.9, name)
            self.assertGreaterEqual(row["completion"]["median_minutes"], 60, name)
            self.assertLessEqual(row["completion"]["median_minutes"], 240, name)
            self.assertEqual(row["trivial"], [], name)
            self.assertLessEqual(row["first_purchase_trip"], 4, name)
            self.assertLessEqual(row["purchases_by_session"][0], 4, name)
            self.assertGreaterEqual(min(row["purchases_by_session"][:3]), 1, name)

    def test_cautious_is_slower_but_reaches_everything(self):
        summary = targets()
        cautious, balanced = summary["cautious"], summary["balanced"]
        self.assertGreaterEqual(cautious["completion"]["median_minutes"], 1.2 * balanced["completion"]["median_minutes"])
        self.assertEqual(cautious["unreachable"], [])
        self.assertEqual(cautious["never_earned"], [])
        self.assertEqual(cautious["blocked_recipes"], [])

    def test_cautious_can_afford_every_night_cost_too(self):
        # Skills are bought in the run; capsule and totem are not, so check their Nightbloom is earned as well.
        t = tuning()
        need = sum(s["cost"].get("nightbloom", 0) for s in t["skills"].values())
        need += sum(r["cost"].get("nightbloom", 0) for r in t["recipes"].values())
        self.assertGreaterEqual(targets()["cautious"]["nightbloom_lifetime_median"], need)

    def test_the_night_path_for_cautious_is_safe_by_rule(self):
        # Silueta cannot target fog beyond the leash, so this does not depend on any invented chance.
        t, ctx = tuning(), context()
        self.assertGreater(eco.spawn_probabilities(t, "fog", "Night").get("nightbloom", 0.0), 0.0)
        fog_slots = [s for s in t["gather"]["slots"] if s["zone"] == "fog"]
        self.assertGreaterEqual(len(fog_slots), 3)
        for slot in fog_slots:
            self.assertEqual(eco.hold_exposure(t, ctx, slot, "Night"), (0.0, 0.0), slot["id"])
        cautious = targets()["cautious"]
        self.assertEqual(cautious["territory_nodes_per_trip"], 0.0)
        self.assertEqual(cautious["strikes_per_trip"], 0.0)

    def test_night_pays_the_bold_better_than_the_cautious(self):
        summary = targets()
        self.assertGreater(summary["greedy"]["nightbloom_per_minute"], 1.5 * summary["cautious"]["nightbloom_per_minute"])

    def test_the_claims_survive_changing_the_invented_behavior(self):
        # Guards against overfitting to the archetypes: these inputs are invented, so the structure must not hinge on them.
        changes = (("holdThroughWarning", 0.5), ("holdThroughWarning", 1.5), ("riskAversion", 0.5), ("riskAversion", 2.0))
        for key, factor in changes:
            t, ctx = tuning(), context()
            for policy in t["simulatorInputs"]["archetypes"].values():
                policy[key] = min(1.0, policy[key] * factor) if key == "holdThroughWarning" else policy[key] * factor
            summary = eco.analyse_policies(t, ctx, runs=10, trips=70, seed=31)
            label = (key, factor)
            self.assertGreater(summary["balanced"]["value_per_minute"], 1.15 * summary["cautious"]["value_per_minute"], label)
            self.assertGreaterEqual(summary["cautious"]["completion"]["reached_share"], 0.9, label)
            self.assertGreater(summary["greedy"]["defeat_rate"], summary["balanced"]["defeat_rate"], label)
            for name, row in summary.items():
                self.assertGreaterEqual(row["seconds_median"], 150, (label, name))   # close to, if not always at, 180
                self.assertLessEqual(row["seconds_median"], 480, (label, name))
                self.assertGreaterEqual(row["completion"]["median_minutes"], 60, (label, name))

    def test_currency_banked_and_companions_are_never_lost(self):
        import random
        t, ctx = tuning(), context()
        policy = copy.deepcopy(t["simulatorInputs"]["archetypes"]["greedy"])
        policy["defeatChance"] = 0.5
        state, rng = eco.new_state(t), random.Random(9)
        defeats = 0
        for number in range(60):
            before = copy.deepcopy(state)
            trip = eco.run_expedition(t, ctx, state, policy, rng, start_clock=number * 200.0)
            defeats += trip["outcome"] == "defeated"
            self.assertGreaterEqual(state["ember"], before["ember"])
            self.assertGreaterEqual(len(state["registered"]), len(before["registered"]))
            self.assertGreaterEqual(len(state["bankedEggs"]), len(before["bankedEggs"]))
            for material, quantity in before["banked"].items():
                self.assertGreaterEqual(state["banked"][material], quantity)
        self.assertGreater(defeats, 10)

    def test_no_monetization_and_no_time_grant(self):
        t = tuning()
        self.assertEqual(t["monetization"], "none")
        self.assertIs(t["currency"]["purchasable"], False)
        self.assertIs(t["currency"]["lostOnDefeat"], False)
        for key in ("ember", "registered", "bankedEggs", "banked"):
            self.assertIn(key, t["loss"]["neverLost"])
        self.assertEqual(t["antiAfk"]["timeBasedGrants"], 0)


class DocumentHonesty(unittest.TestCase):
    def test_pacing_table_matches_the_simulator(self):
        text = DOC.read_text(encoding="utf-8")
        rows = re.findall(r"^\| (Cautious|Balanced|Greedy) \| (\d+) s \|.*\| (\d+) min \|$", text, re.M)
        self.assertEqual(len(rows), 3)
        for name, seconds, minutes in rows:
            row = targets()[name.lower()]
            self.assertAlmostEqual(row["seconds_median"], int(seconds), delta=0.1 * int(seconds), msg=name)
            self.assertAlmostEqual(row["completion"]["median_minutes"], int(minutes), delta=0.2 * int(minutes), msg=name)

    def test_the_document_says_what_is_only_math(self):
        text = DOC.read_text(encoding="utf-8")
        for phrase in ("## Revision after the simulator", "### Still only math", "### What would falsify this in play",
                       "invented", "| Before |"):
            self.assertIn(phrase, text)
        self.assertNotIn("not built here", text)


class TimeAndCarrying(unittest.TestCase):
    def test_phase_follows_the_cycle(self):
        t = tuning()
        self.assertEqual(eco.phase_at(t, 0.0), "Day")
        self.assertEqual(eco.phase_at(t, 359.9), "Day")
        self.assertEqual(eco.phase_at(t, 360.0), "Dusk")
        self.assertEqual(eco.phase_at(t, 432.0), "Night")
        self.assertEqual(eco.phase_at(t, 647.9), "Night")
        self.assertEqual(eco.phase_at(t, 648.0), "Dawn")
        self.assertEqual(eco.phase_at(t, 720.0), "Day")

    def test_start_offset_is_never_night(self):
        import random
        t, rng = tuning(), random.Random(3)
        phases = {eco.phase_at(t, eco.draw_start_clock(t, rng)) for _ in range(2000)}
        self.assertEqual(phases, {"Day", "Dusk", "Dawn"})

    def test_load_slows_the_walk_but_never_to_silueta(self):
        # Hand set in the document: under 40% of a pouch 16, from 40% 13, from 80% 11, eggs by the capture table.
        t = tuning()
        s = eco.new_state(t)
        self.assertEqual(eco.carry_speed(t, s), 16.0)
        s["carried"]["fogbark"] = 11
        self.assertEqual(eco.carry_speed(t, s), 16.0)
        s["carried"]["fogbark"] = 12
        self.assertEqual(eco.carry_speed(t, s), 13.0)
        s["bag"] = [{"kind": "egg", "tier": "Territory"}]
        self.assertEqual(eco.carry_speed(t, s), 11.0)     # the egg is slower than this load
        s["bag"] = []
        s["carried"]["fogbark"] = 24
        self.assertEqual(eco.carry_speed(t, s), 11.0)
        s["bag"] = [{"kind": "egg", "tier": "Territory"}] * 4
        self.assertEqual(eco.carry_speed(t, s), 9.0)
        self.assertGreater(eco.carry_speed(t, s), 8.0)   # 8 is Silueta's fastest speed

    def test_a_load_step_at_or_below_silueta_speed_is_caught(self):
        t = tuning()
        t["carry"]["pouchLoadSteps"][-1]["speed"] = 8
        problems = eco.check_invariants(t, context())
        self.assertTrue(any("carry" in p.lower() for p in problems), problems)


class StandingStillAgainstSilueta(unittest.TestCase):
    def test_anchors_are_read_from_the_fair_strike_document(self):
        anchors = context().anchors
        self.assertEqual([a[0] for a in anchors],
                         ["Home", "NestSide", "RuinEast", "RuinWest", "WestHollow", "SouthGrove"])
        self.assertEqual(sum(a[3] for a in anchors), 100)
        self.assertEqual(anchors[0][1:3], (0.0, -85.0))

    def test_exposure_is_zero_where_silueta_cannot_target(self):
        t, ctx = tuning(), context()
        for slot in t["gather"]["slots"]:
            if slot["zone"] != "territory":
                self.assertEqual(eco.hold_exposure(t, ctx, slot, "Day"), (0.0, 0.0), slot["id"])

    def test_exposure_comes_from_the_pressure_geometry(self):
        # With every weight on Home, the result must equal the pressure tool's own sweep at that spot.
        import dataclasses
        t, ctx = tuning(), context()
        only_home = dataclasses.replace(ctx, anchors=[("Home", 0.0, -85.0, 100)], exposure_cache={})
        slot = {"id": "probe", "zone": "territory", "x": -10.0, "z": -60.0}
        hold = t["gather"]["holdSeconds"]["territory"]
        w = eco.world_rules
        s = w.sweep(ctx.world.model, ctx.world.patrol, (-10.0, -60.0), ctx.world.day.speed, ctx.world.day.detection_range,
                    eco.EXPOSURE_PHASES)
        self.assertEqual(eco.hold_exposure(t, only_home, slot, "Day"), w.exposure(s, hold))

    def test_struck_never_exceeds_warned_and_night_is_worse(self):
        t, ctx = tuning(), context()
        heart = [s for s in t["gather"]["slots"] if s.get("heart")]
        self.assertGreaterEqual(len(heart), 2)
        for slot in t["gather"]["slots"]:
            for phase in ("Day", "Night"):
                warned, struck = eco.hold_exposure(t, ctx, slot, phase)
                self.assertLessEqual(struck, warned, slot["id"])
        for slot in heart:
            self.assertGreater(eco.hold_exposure(t, ctx, slot, "Night")[1], eco.hold_exposure(t, ctx, slot, "Day")[1], slot["id"])

    def test_long_holds_near_the_patrol_are_the_dangerous_ones(self):
        t, ctx = tuning(), context()
        by_kind = {True: [], False: []}
        for slot in t["gather"]["slots"]:
            if slot["zone"] == "territory":
                by_kind[bool(slot.get("heart"))].append(eco.hold_exposure(t, ctx, slot, "Night")[1])
        self.assertGreater(min(by_kind[True]), max(by_kind[False]))

    def test_strike_marks_then_defeats(self):
        import random
        t = tuning()
        s = eco.new_state(t)
        s["carried"]["fogbark"] = 20
        s["bag"] = [{"kind": "creature", "tier": "Territory"}, {"kind": "egg", "tier": "Territory"}]
        no_recovery = {"dropRecovery": 0.0}
        first = eco.apply_strike(t, s, 0, no_recovery, random.Random(1))
        self.assertEqual(first, {"marks": 1, "defeated": False, "dropped": "egg", "recovered": False})
        self.assertEqual(len(s["bag"]), 1)
        self.assertEqual(s["carried"]["fogbark"], 20)    # materials never drop to a strike (D6)
        second = eco.apply_strike(t, s, 1, no_recovery, random.Random(1))
        self.assertTrue(second["defeated"])
        self.assertEqual(s["bag"], [])
        self.assertEqual(s["carried"]["fogbark"], 10)

    def test_dropped_item_can_be_recovered(self):
        import random
        t = tuning()
        s = eco.new_state(t)
        s["bag"] = [{"kind": "egg", "tier": "Territory"}]
        result = eco.apply_strike(t, s, 0, {"dropRecovery": 1.0}, random.Random(1))
        self.assertTrue(result["recovered"])
        self.assertEqual(len(s["bag"]), 1)


class NightbloomInTheBag(unittest.TestCase):
    def test_nightbloom_is_a_bag_item_not_a_pouch_stack(self):
        t = tuning()
        self.assertEqual(t["materials"]["nightbloom"]["carriedAs"], "bagItem")
        self.assertEqual(sorted(eco.new_state(t)["carried"]), ["fogbark", "glowmoss"])

    def test_extraction_banks_the_bundle_and_pays_no_ember_for_it(self):
        t = tuning()
        bag = [{"kind": "nightbloom", "tier": "Fog", "quantity": 2}]
        self.assertEqual(eco.extraction_ember(t, bag, 90.0, 70.0, 0), 4)

    def test_defeat_takes_the_whole_bundle_unless_warded(self):
        t = tuning()
        s = eco.new_state(t)
        s["bag"] = [{"kind": "nightbloom", "tier": "Fog", "quantity": 2}]
        summary = eco.apply_defeat(t, s)
        self.assertEqual((summary["lost_items"], s["bag"]), (1, []))
        s["bag"] = [{"kind": "nightbloom", "tier": "Fog", "quantity": 2}]
        s["consumables"]["seal"] = 1
        eco.apply_defeat(t, s, use_seal=True)
        self.assertEqual(len(s["bag"]), 1)

    def test_a_full_bag_cannot_take_a_bundle(self):
        import random
        t, ctx = tuning(), context()
        t["gather"]["slots"] = [s for s in t["gather"]["slots"] if s["zone"] == "fog"]
        t["spawnWeights"]["fog"] = {p: {"nightbloom": 100} for p in t["cycle"]["phaseOrder"]}
        t["yields"]["fog"] = {"nightbloom": [1, 1]}
        s = eco.new_state(t)
        s["bag"] = [{"kind": "creature", "tier": "Fog"}] * 3
        policy = idle_policy(zones={"outside": 0, "fog": 8, "territory": 0})
        trip = eco.run_expedition(t, ctx, s, policy, random.Random(1), start_clock=500.0)
        self.assertEqual(s["banked"]["nightbloom"], 0)
        self.assertEqual(trip["nodes_gathered"], 0)
        self.assertGreater(trip["blooms_refused"], 0)


class Analysis(unittest.TestCase):
    def test_policy_summary_and_flags(self):
        t, ctx = tuning(), context()
        summary = eco.analyse_policies(t, ctx, runs=12, trips=60, seed=2026)
        self.assertEqual(set(summary), set(t["simulatorInputs"]["archetypes"]))
        cautious = summary["cautious"]
        for key in ("ember_per_trip", "units_per_trip", "seconds_median", "defeat_rate",
                    "pouch_full_share", "bag_full_share", "upgrades"):
            self.assertIn(key, cautious)
        for upgrade, row in cautious["upgrades"].items():
            self.assertIn("reached_share", row)
            self.assertIn("median_trip", row)

    def test_summary_is_deterministic(self):
        t, ctx = tuning(), context()
        a = eco.analyse_policies(t, ctx, runs=6, trips=40, seed=5)
        b = eco.analyse_policies(t, ctx, runs=6, trips=40, seed=5)
        self.assertEqual(a, b)

    def test_trivial_and_unreachable_flags_follow_the_thresholds(self):
        row = {"reached_share": 1.0, "median_trip": 1}
        self.assertEqual(eco.classify_upgrade(row), "TRIVIAL")
        self.assertEqual(eco.classify_upgrade({"reached_share": 1.0, "median_trip": 2}), "ok")
        self.assertEqual(eco.classify_upgrade({"reached_share": 0.49, "median_trip": 50}), "UNREACHABLE")
        self.assertEqual(eco.classify_upgrade({"reached_share": 0.0, "median_trip": None}), "UNREACHABLE")
        self.assertEqual(eco.classify_upgrade({"reached_share": 0.5, "median_trip": 40}), "ok")


class Report(unittest.TestCase):
    def run_main(self, argv):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = eco.main(argv)
        return code, out.getvalue()

    def test_header_states_the_limits(self):
        code, text = self.run_main(["--runs", "6", "--trips", "30"])
        self.assertEqual(code, 0)
        head = text[:1500].lower()
        for phrase in ("math only", "fun or balance", "assumption"):
            self.assertIn(phrase, head)

    def test_report_covers_policies_upgrades_and_flags(self):
        _, text = self.run_main(["--runs", "6", "--trips", "30"])
        for name in ("cautious", "balanced", "greedy", "reinforcedPack", "explorer_1", "INVARIANTS", "stay-or-return"):
            self.assertIn(name, text)

    def test_report_is_deterministic(self):
        argv = ["--runs", "6", "--trips", "30", "--seed", "9"]
        self.assertEqual(self.run_main(argv), self.run_main(argv))

    def test_bad_arguments_are_rejected(self):
        with self.assertRaises(SystemExit):
            with contextlib.redirect_stderr(io.StringIO()):
                eco.main(["--runs", "0"])

    def test_broken_document_exits_nonzero(self):
        with contextlib.redirect_stderr(io.StringIO()):
            code = eco.main(["--doc", str(REPO / "README.md")])
        self.assertNotEqual(code, 0)


if __name__ == "__main__":
    unittest.main()

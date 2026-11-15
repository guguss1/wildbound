"""Wildbound 2.0 roulette simulator (T09a, PF5): parse the WildboundRoulette prize tables and check them.

The Luau module src/wildbound/WildboundRoulette.luau is the source of truth. This tool parses its `Roulette.CONFIG`
literal (the 2.0 proposal) and its `Roulette.LIVE` literal (the wired hub table, PF5) with the economy simulator's Luau
literal parser, mirrors its validate/draw/odds/EV rules, runs seeded spins and writes
docs/balance/wildbound-2-0-roulette.md. tests/WildboundRoulette_Test.luau and
tools/test_wildbound_roulette_sim.py pin the same numbers, so the two implementations cannot drift silently.

Pure stdlib, seeded `random.Random`, no wall clock. Usage (from the project root):

    python -I -B tools/wildbound_roulette_sim.py                       # print the report
    python -I -B tools/wildbound_roulette_sim.py --spins 10000 --seed 7 --write
"""

import argparse
import copy
import math
import random
import sys
from pathlib import Path

_HERE = str(Path(__file__).resolve().parent)
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

from wildbound_economy_sim_v2 import _assignment_literal, parse_balance_literal, strip_comments  # noqa: E402,F401

REPO = Path(__file__).resolve().parent.parent
MODULE = REPO / "src" / "wildbound" / "WildboundRoulette.luau"
BALANCE = REPO / "src" / "wildbound" / "WildboundBalance.luau"
REPORT = REPO / "docs" / "balance" / "wildbound-2-0-roulette.md"

RARITIES = ("Comun", "Rara", "Epica", "Legendaria")
RANK = {name: index + 1 for index, name in enumerate(RARITIES)}
CATEGORIES = ("esencia", "materials", "gloves", "incubationBoosters", "consumables", "specialEgg")
MATERIALS = ("fogbark", "glowmoss", "nightbloom")
CONSUMABLES = ("trap", "smoke", "portablePortal")
LOCATIONS = ("hub", "base")
POLICIES = ("none", "pending", "convert")
TOTAL = 10000
# Chi-square critical value, 20 degrees of freedom (21 prizes), p = 0.001.
CHI2_CRITICAL_DF20_P001 = 45.315
# Chi-square critical value, 10 degrees of freedom (the 11 live prizes), p = 0.001.
CHI2_CRITICAL_DF10_P001 = 29.588


class ConfigUnavailable(Exception):
    """The module file is missing or its CONFIG literal could not be parsed. There is no silent fallback."""


def load_config(path=MODULE):
    try:
        text = Path(path).read_text(encoding="utf-8")
        return parse_balance_literal(_assignment_literal(text, "Roulette.CONFIG = freeze("))
    except (OSError, ValueError) as error:
        raise ConfigUnavailable(f"{path}: {error}") from error


def load_live_config(path=MODULE):
    """PF5: the wired hub table, `Roulette.LIVE`."""
    try:
        text = Path(path).read_text(encoding="utf-8")
        return parse_balance_literal(_assignment_literal(text, "Roulette.LIVE = freeze("))
    except (OSError, ValueError) as error:
        raise ConfigUnavailable(f"{path}: {error}") from error


def load_balance_roulette(path=BALANCE):
    try:
        text = Path(path).read_text(encoding="utf-8")
        return parse_balance_literal(_assignment_literal(text, "Balance.CONSTANTS = freeze("))["roulette"]
    except (OSError, ValueError, KeyError) as error:
        raise ConfigUnavailable(f"{path}: {error}") from error


def _whole(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value) and value == int(value)


def _finite(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def qualifies(prize, min_rarity):
    return RANK.get(prize["rarity"], 0) >= RANK.get(min_rarity, math.inf)


def effective_odds(config, pity):
    """Long-run odds of a paid spin per prize id (sums to 1). Mirrors `effective` in the Luau module."""
    odds, _ = _effective(config, pity)
    return odds


def _effective(config, pity):
    prizes, min_rarity = config["prizes"], config["pity"]["minRarity"]
    total = sum(p["weight"] for p in prizes)
    qualifying = sum(p["weight"] for p in prizes if qualifies(p, min_rarity))
    share = 0.0
    if pity and qualifying > 0:
        q, every = qualifying / total, config["pity"]["every"]
        share = q * (1 - q) ** (every - 1) / (1 - (1 - q) ** every)
    odds = {}
    for p in prizes:
        boosted = p["weight"] / qualifying if qualifies(p, min_rarity) else 0.0
        odds[p["id"]] = (1 - share) * (p["weight"] / total) + share * boosted
    return odds, share


def expected_value(config, pity=None):
    if pity is None:
        pity = config["pity"]["enabled"] is True
    odds, share = _effective(config, pity)
    out = {"esencia": 0.0, "cash": 0.0, "value": 0.0, "cost": config["spinCost"], "pitySpinShare": share}
    for p in config["prizes"]:
        chance = odds[p["id"]]
        if p["category"] == "esencia":
            out["esencia"] += chance * p["grant"].get("esencia", 0)
        out["cash"] += chance * p["resale"]
        out["value"] += chance * p["value"]
    out["netCash"] = out["cash"] - out["cost"]
    out["netValue"] = out["value"] - out["cost"]
    return out


def money_loop(config, pity=True):
    ev = expected_value(config, pity)
    limits = config["limits"]
    return ev["cash"] >= config["spinCost"] * limits["maxCashShare"] or ev["esencia"] >= limits["maxEsenciaPerSpin"]


def _check_grant(prize, fail):
    grant, label, category = prize.get("grant"), f"prize {prize.get('id')}", prize.get("category")
    if not isinstance(grant, dict) or not grant:
        fail(f"{label}: grant missing")
        return
    for key, amount in grant.items():
        if category == "esencia":
            if key != "esencia" or not _whole(amount) or amount <= 0:
                fail(f"{label}: esencia grant must be {{ esencia = n > 0 }}")
        elif category == "materials":
            if key not in MATERIALS:
                fail(f"{label}: unknown material {key}")
            elif not _whole(amount) or amount <= 0:
                fail(f"{label}: material {key} must be a whole number above 0")
        elif category == "gloves":
            if key != "glove" or amount != prize.get("rarity"):
                fail(f"{label}: glove grant must be {{ glove = its own rarity }}")
        elif category == "incubationBoosters":
            if key != "incubationBooster" or not _finite(amount) or not 0 < amount < 1:
                fail(f"{label}: incubation booster factor must be inside (0, 1)")
        elif category == "consumables":
            if key not in CONSUMABLES:
                fail(f"{label}: unknown consumable {key}")
            elif not _whole(amount) or amount <= 0:
                fail(f"{label}: consumable {key} must be a whole number above 0")
        elif category == "specialEgg":
            if key != "specialEgg" or amount not in RANK:
                fail(f"{label}: special egg grant must be {{ specialEgg = rarity }}")


def validate(config):
    """Mirror of Roulette.validate: returns the error list (empty when valid)."""
    errors = []
    fail = errors.append
    if config.get("currency") != "esencia":
        fail("currency: the roulette is Esencia-only")
    if not _whole(config.get("spinCost")) or config["spinCost"] <= 0:
        fail("spinCost: must be a whole number above 0")
    if not isinstance(config.get("freeFirstSpin"), bool):
        fail("freeFirstSpin: not a boolean")
    pity = config.get("pity")
    if (not isinstance(pity, dict) or not isinstance(pity.get("enabled"), bool) or not _whole(pity.get("every"))
            or pity["every"] < 2 or pity.get("minRarity") not in RANK):
        fail("pity: needs enabled (boolean), every (whole, at least 2) and a known minRarity")
    locations = config.get("locations")
    if not isinstance(locations, list) or not locations:
        fail("locations: at least one location (hub or base)")
    else:
        for name in locations:
            if name not in LOCATIONS:
                fail(f"locations: unknown location {name}")
    limits = config.get("limits")
    if not isinstance(limits, dict) or not _finite(limits.get("maxCashShare")) or not _finite(limits.get("maxEsenciaPerSpin")):
        fail("limits: maxCashShare and maxEsenciaPerSpin required")
    weights = config.get("categoryWeights") if isinstance(config.get("categoryWeights"), dict) else {}
    for name in weights:
        if name not in CATEGORIES:
            fail(f"categoryWeights: unknown category {name}")
    prizes = config.get("prizes")
    if not isinstance(prizes, list) or not prizes:
        fail("prizes: none")
        return errors
    seen, sums, total = set(), {}, 0
    for index, prize in enumerate(prizes, 1):
        label = f"prize {prize.get('id', index)}"
        if not isinstance(prize.get("id"), str):
            fail(f"prize {index}: id missing")
        elif prize["id"] in seen:
            fail(f"{label}: duplicate id")
        if isinstance(prize.get("id"), str):
            seen.add(prize["id"])
        if prize.get("category") not in CATEGORIES:
            fail(f"{label}: unknown category {prize.get('category')}")
        if prize.get("rarity") not in RANK:
            fail(f"{label}: unknown rarity {prize.get('rarity')}")
        if not _whole(prize.get("weight")) or prize["weight"] <= 0:
            fail(f"{label}: weight must be a whole number above 0")
        else:
            sums[prize.get("category")] = sums.get(prize.get("category"), 0) + prize["weight"]
            total += prize["weight"]
        if not _finite(prize.get("value")) or prize["value"] < 0:
            fail(f"{label}: value must be at least 0")
        if not _finite(prize.get("resale")) or prize["resale"] < 0:
            fail(f"{label}: resale must be at least 0")
        if not isinstance(prize.get("label"), str) or not prize["label"]:
            fail(f"{label}: label missing")
        _check_grant(prize, fail)
        if prize.get("category") == "esencia" and isinstance(prize.get("grant"), dict) and prize.get("resale") != prize["grant"].get("esencia"):
            fail(f"{label}: an Esencia prize resells for exactly its amount")
        policy = prize.get("whenFull")
        if policy not in POLICIES:
            fail(f"{label}: whenFull must be none, pending or convert (no prize is lost)")
        elif prize.get("category") == "esencia" and policy != "none":
            fail(f"{label}: whenFull of Esencia is none (no cap)")
        elif prize.get("category") != "esencia" and policy == "none":
            fail(f"{label}: whenFull none is only for Esencia")
        if policy == "convert":
            full = prize.get("fullEsencia")
            if not _whole(full) or full <= 0:
                fail(f"{label}: convert needs fullEsencia above 0")
            elif _finite(prize.get("resale")) and full > prize["resale"]:
                fail(f"{label}: fullEsencia above its resale")
        elif "fullEsencia" in prize:
            fail(f"{label}: fullEsencia only goes with whenFull convert")
    for name in CATEGORIES:
        want = weights.get(name, 0) * 100
        if sums.get(name, 0) != want:
            fail(f"{name}: prize weights sum {sums.get(name, 0)}, category weight x 100 is {want}")
    if total != TOTAL:
        fail(f"prizes: weights sum {total}, not {TOTAL}")
    if not errors and not any(qualifies(p, pity["minRarity"]) for p in prizes):
        fail(f"pity: no prize at or above {pity['minRarity']}")
    if not errors:
        worst = expected_value(config, True)
        cap = config["spinCost"] * limits["maxCashShare"]
        if worst["cash"] >= cap:
            fail(f"money loop: a spin turns into {worst['cash']:.2f} Esencia, cap {cap:.2f}")
        if worst["esencia"] >= limits["maxEsenciaPerSpin"]:
            fail(f"money loop: Esencia prizes pay {worst['esencia']:.2f} per spin, cap {limits['maxEsenciaPerSpin']:.2f}")
    return errors


def new_state():
    return {"freeSpinUsed": False, "pityCount": 0, "paidSpins": 0}


def draw(rng01, state, config):
    """Mirror of Roulette.draw: (prize, new_state, receipt) or (None, state, error)."""
    if not _finite(rng01) or not 0 <= rng01 < 1:
        return None, state, "rng01 must be a number in [0, 1)"
    free = config["freeFirstSpin"] is True and not state["freeSpinUsed"]
    pity = config["pity"]
    pity_on = not free and pity["enabled"] is True and state["pityCount"] >= pity["every"] - 1
    pool = [p for p in config["prizes"] if not pity_on or qualifies(p, pity["minRarity"])]
    pick = math.floor(rng01 * sum(p["weight"] for p in pool))
    chosen = None
    for prize in pool:
        pick -= prize["weight"]
        if pick < 0:
            chosen = prize
            break
    after = dict(state)
    if free:
        after["freeSpinUsed"] = True
    else:
        after["paidSpins"] += 1
        after["pityCount"] = 0 if qualifies(chosen, pity["minRarity"]) else state["pityCount"] + 1
    return chosen, after, {"cost": 0 if free else config["spinCost"], "free": free, "pity": pity_on}


def simulate(config, spins, seed, pity):
    """One account: the free spin, then `spins` paid spins. Seeded; returns plain data."""
    c = copy.deepcopy(config)
    c["pity"]["enabled"] = pity
    rng = random.Random(seed)
    state = new_state()
    counts = {p["id"]: 0 for p in c["prizes"]}
    esencia = cash = value = 0
    drought = longest = pity_spins = 0
    first_epic = None
    free_prize, state, _ = draw(rng.random(), state, c)
    for spin in range(1, spins + 1):
        prize, state, receipt = draw(rng.random(), state, c)
        counts[prize["id"]] += 1
        esencia += prize["grant"].get("esencia", 0) if prize["category"] == "esencia" else 0
        cash += prize["resale"]
        value += prize["value"]
        pity_spins += 1 if receipt["pity"] else 0
        drought = 0 if qualifies(prize, c["pity"]["minRarity"]) else drought + 1
        longest = max(longest, drought)
        if first_epic is None and RANK[prize["rarity"]] >= RANK["Epica"]:
            first_epic = spin
    return {
        "paid": spins,
        "freePrize": free_prize["id"],
        "counts": counts,
        "esenciaPerSpin": esencia / spins,
        "cashPerSpin": cash / spins,
        "valuePerSpin": value / spins,
        "pitySpins": pity_spins,
        "longestDrought": longest,
        "firstEpicSpin": first_epic,
    }


def chi_square(counts, odds, n):
    return sum((counts[k] - n * p) ** 2 / (n * p) for k, p in odds.items() if p > 0)


def max_relative_error(counts, odds, n):
    return max(abs(counts[k] / n - p) / p for k, p in odds.items() if p > 0)


def _fmt(value, places=2):
    return f"{value:.{places}f}"


def report(config, spins=10000, seed=7):
    errors = validate(config)
    c_off = copy.deepcopy(config)
    c_off["pity"]["enabled"] = False
    epic = copy.deepcopy(config)
    epic["pity"]["minRarity"] = "Epica"
    ev = {"off": expected_value(config, False), "on": expected_value(config, True), "epic": expected_value(epic, True)}
    odds_on = effective_odds(config, True)
    runs = {"off": simulate(config, spins, seed, False), "on": simulate(config, spins, seed, True),
            "epic": simulate(epic, spins, seed, True)}
    lines = [
        "# Wildbound 2.0 roulette (T09a prize table)",
        "",
        "GENERATED by `python -I -B tools/wildbound_roulette_sim.py --write` from `src/wildbound/WildboundRoulette.luau`"
        " (CONFIG, the 2.0 proposal; the wired hub table LIVE is at the end). Every `value` and the caps are ASSUMED;"
        " this is a model, not measured play data.",
        "",
        f"Validation: {'pass' if not errors else 'FAIL: ' + '; '.join(errors)}.",
        "",
        f"Esencia only. {config['spinCost']} Esencia per paid spin; free first spin per account: "
        f"{config['freeFirstSpin']}. Locations allowed: {', '.join(config['locations'])} (the choice and the wiring are T09b)."
        f" Pity default: {'ON' if config['pity']['enabled'] else 'OFF'}, the {config['pity']['every']}th paid spin in a row"
        f" without {config['pity']['minRarity']} or better draws from the {config['pity']['minRarity']}+ prizes.",
        "",
        "Columns: shown % = weight / 100 (what the UI lists); pity % = long-run odds of a paid spin with pity ON;"
        " value = ASSUMED Esencia-equivalent; resale = the most Esencia the prize can turn into (Esencia itself, glove"
        " recycle 3/6/12/25, special egg hatched and sold at the Balance sell price, consumable converted when full);"
        " when full = pending (held as a claim) or convert (paid in Esencia at once). No prize is lost.",
        "",
        "| Prize | Category | Rarity | Grant | Shown % | Pity % | Value | Resale | When full | Label |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for p in config["prizes"]:
        grant = ", ".join(f"{k} {v}" for k, v in p["grant"].items())
        full = p["whenFull"] + (f" ({p['fullEsencia']} Esencia)" if p["whenFull"] == "convert" else "")
        lines.append(f"| {p['id']} | {p['category']} | {p['rarity']} | {grant} | {_fmt(p['weight'] / 100)} |"
                     f" {_fmt(odds_on[p['id']] * 100, 3)} | {p['value']} | {p['resale']} | {full} | {p['label']} |")
    by_rarity = {r: sum(p["weight"] for p in config["prizes"] if p["rarity"] == r) / 100 for r in RARITIES}
    lines += [
        "",
        "By rarity (shown): " + ", ".join(f"{r} {_fmt(v, 1)}%" for r, v in by_rarity.items()) + ".",
        "",
        "## Expected value per paid spin",
        "",
        "| Mode | Pity spin share | Esencia prizes | Cash (all resale) | Value (assumed) | Net cash | Net value |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]
    for key, name in (("off", "Pity OFF"), ("on", "Pity ON (Rara+, default)"), ("epic", "Pity ON, Epica+ (earlier chest design)")):
        e = ev[key]
        lines.append(f"| {name} | {_fmt(e['pitySpinShare'] * 100, 3)}% | {_fmt(e['esencia'], 3)} | {_fmt(e['cash'], 3)} |"
                     f" {_fmt(e['value'], 3)} | {_fmt(e['netCash'], 3)} | {_fmt(e['netValue'], 3)} |")
    limits = config["limits"]
    lines += [
        "",
        f"Money-loop check (ASSUMED caps): cash per spin under {limits['maxCashShare']} x {config['spinCost']} ="
        f" {_fmt(config['spinCost'] * limits['maxCashShare'])} and Esencia prizes under {limits['maxEsenciaPerSpin']} per"
        f" spin (the economy simulator's break-even Esencia prize is about 91). Loop with pity OFF: {money_loop(config, False)};"
        f" ON: {money_loop(config, True)}. Every spin loses at least {_fmt(-ev['on']['netCash'])} Esencia in cash on average,"
        " so spins cannot pay for themselves.",
        "",
        f"## Seeded simulation ({spins} paid spins after the free spin, seed {seed})",
        "",
        "| Mode | Chi-square (df 20, critical 45.3) | Max relative error | Esencia/spin | Cash/spin | Value/spin |"
        " Pity spins | Longest drought | First Epica+ spin |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for key, name, cfg, pity in (("off", "Pity OFF", c_off, False), ("on", "Pity ON (Rara+)", config, True),
                                 ("epic", "Pity ON, Epica+", epic, True)):
        r = runs[key]
        odds = effective_odds(cfg, pity)
        lines.append(f"| {name} | {_fmt(chi_square(r['counts'], odds, r['paid']))} |"
                     f" {_fmt(max_relative_error(r['counts'], odds, r['paid']) * 100, 1)}% | {_fmt(r['esenciaPerSpin'], 3)} |"
                     f" {_fmt(r['cashPerSpin'], 3)} | {_fmt(r['valuePerSpin'], 3)} | {r['pitySpins']} | {r['longestDrought']} |"
                     f" {r['firstEpicSpin']} |")
    lines += [
        "",
        "Longest drought counts paid spins in a row without the mode's pity rarity (Rara+, or Epica+ for the last row).",
        "",
        "## Notes for the user and T09b",
        "",
        f"- Pity Rara+ (default, {_fmt(by_rarity['Rara'] + by_rarity['Epica'] + by_rarity['Legendaria'], 0)}% per spin):"
        f" fires on {_fmt(ev['on']['pitySpinShare'] * 100, 2)}% of paid spins, adds"
        f" {_fmt(ev['on']['cash'] - ev['off']['cash'], 3)} Esencia of cash and {_fmt(ev['on']['value'] - ev['off']['value'], 3)}"
        " of assumed value per spin, and caps the drought at 9 (OFF: the seeded run reached"
        f" {runs['off']['longestDrought']}). Money-loop caps hold: {not money_loop(config, True)}.",
        f"- Pity Epica+ (the earlier chest design, {_fmt(by_rarity['Epica'] + by_rarity['Legendaria'], 1)}% per spin): fires on"
        f" {_fmt(ev['epic']['pitySpinShare'] * 100, 2)}% of paid spins, cash {_fmt(ev['epic']['cash'], 2)} and value"
        f" {_fmt(ev['epic']['value'], 2)} per spin. Money-loop caps hold: {not money_loop(epic, True)}"
        f" (cash cap {_fmt(config['spinCost'] * limits['maxCashShare'])}); validate() rejects it with today's caps, so"
        " choosing it means lowering the Epica/Legendaria resale (special eggs) or raising maxCashShare. Cash stays under the"
        " 45 price either way, so it is not a true loop.",
        "- Conflict: the earlier base-chest design (docs/design/wildbound-hub-expansion.md section 6) said a paid draw never pays"
        " Esencia; the 2.0 pack weights give Esencia 35%. This table follows the 2.0 weights; the user should confirm.",
        "- Saved state: draw() needs `pityCount` and `paidSpins` beside `freeSpinUsed` and `pending` in the planned roulette"
        " record (docs/design/wildbound-2-0-schema-plan.md).",
        "- Glove recycle values (3/6/12/25) come from the hub-expansion design (Q8); no live module has them yet.",
        "- A pending prize mints nothing until claimed (schema plan); a consumable at its cap converts to its fullEsencia.",
        "",
    ]
    return "\n".join(lines)


def live_section(live, spins=10000, seed=7):
    """PF5: the wired hub table (Esencia and banked materials only), appended to the 2.0 report."""
    errors = validate(live)
    ev = {"off": expected_value(live, False), "on": expected_value(live, True)}
    odds_on = effective_odds(live, True)
    run = simulate(live, spins, seed, True)
    lines = [
        "",
        "## Live hub table (PF5)",
        "",
        "`Roulette.LIVE` is the table the hub station rolls from (WildboundRouletteService, user decision 2026-11-14:"
        " the roulette lives in the hub, pity Rara+). It grants only what the economy supports today, Esencia and the"
        " banked materials, so the four other kinds are dropped and the table is re-weighted to"
        f" {', '.join(f'{k} {v}%' for k, v in live['categoryWeights'].items())}. Scaling the 2.0 Esencia share up instead"
        " (35 of 60, about 58%) would pay about 35 Esencia a spin and break the maxEsenciaPerSpin cap.",
        "",
        f"Validation: {'pass' if not errors else 'FAIL: ' + '; '.join(errors)}. {live['spinCost']} Esencia per paid spin,"
        f" free first spin per account: {live['freeFirstSpin']}, locations: {', '.join(live['locations'])}, pity"
        f" {'ON' if live['pity']['enabled'] else 'OFF'} ({live['pity']['minRarity']}+ on the {live['pity']['every']}th"
        " paid spin in a row without it). Materials have no bank cap, so no live prize is ever held as pending.",
        "",
        "| Prize | Category | Rarity | Grant | Shown % | Pity % | Value | Label |",
        "| --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for p in live["prizes"]:
        grant = ", ".join(f"{k} {v}" for k, v in p["grant"].items())
        lines.append(f"| {p['id']} | {p['category']} | {p['rarity']} | {grant} | {_fmt(p['weight'] / 100)} |"
                     f" {_fmt(odds_on[p['id']] * 100, 3)} | {p['value']} | {p['label']} |")
    by_rarity = {r: sum(p["weight"] for p in live["prizes"] if p["rarity"] == r) / 100 for r in RARITIES}
    chi2 = chi_square(run["counts"], odds_on, run["paid"])
    lines += [
        "",
        "By rarity (shown): " + ", ".join(f"{r} {_fmt(v, 1)}%" for r, v in by_rarity.items()) + ".",
        "",
        "| Mode | Pity spin share | Esencia prizes | Value (assumed) | Net cash |",
        "| --- | --- | --- | --- | --- |",
    ]
    for key, name in (("off", "Pity OFF"), ("on", "Pity ON (Rara+, live)")):
        e = ev[key]
        lines.append(f"| {name} | {_fmt(e['pitySpinShare'] * 100, 3)}% | {_fmt(e['esencia'], 3)} | {_fmt(e['value'], 3)} |"
                     f" {_fmt(e['netCash'], 3)} |")
    lines += [
        "",
        f"Seeded run ({spins} paid spins after the free spin, seed {seed}, pity ON): chi-square {_fmt(chi2)} (df 10,"
        f" critical 29.6), Esencia/spin {_fmt(run['esenciaPerSpin'], 3)}, longest drought {run['longestDrought']}, pity"
        f" spins {run['pitySpins']}. Money loop: {money_loop(live, True)}; every paid spin loses"
        f" {_fmt(-ev['on']['netCash'])} Esencia in cash on average, so the roulette is an Esencia sink with material"
        " prizes.",
        "",
    ]
    return "\n".join(lines)


def full_report(spins=10000, seed=7):
    """The whole doc: the 2.0 proposal report plus the live hub table."""
    return report(load_config(), spins=spins, seed=seed) + live_section(load_live_config(), spins=spins, seed=seed)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--spins", type=int, default=10000)
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--write", action="store_true", help="write docs/balance/wildbound-2-0-roulette.md (LF)")
    args = parser.parse_args(argv)
    text = full_report(spins=args.spins, seed=args.seed)
    if args.write:
        REPORT.write_bytes(text.encode("utf-8"))
        print(f"wrote {REPORT.relative_to(REPO)}")
    else:
        sys.stdout.buffer.write(text.encode("utf-8"))
    return 0


if __name__ == "__main__":
    sys.exit(main())

"""Wildbound gold (Oro) economy model (owner item O7, 2026-11-16). A model, not measured play data.

Gold is a layer over the live game model in wildbound_economy_sim_v2: each live session already records when every
egg hatches (rarity, species) and every treadmill lap (time, level). This tool replays those logs with the gold rules
read from src/wildbound/WildboundGold.luau (farm gold per minute by rarity, the tame/hatch bonus, lap gold under the
per-minute cap, the creature sale price) and buys the gold sinks (farm places 5 and 6, treadmill levels) as soon as
they are affordable. Every player choice below is ASSUMED.

Run:  python -I -B tools/wildbound_gold_sim.py --minutes 10,30,60 --seed 7 --runs 200 --md
Test: python -I -B -m unittest discover -s tools -p "test_wildbound_gold_sim.py"
"""

import argparse
import math
import re
import statistics
import sys
from pathlib import Path

_HERE = str(Path(__file__).resolve().parent)
if _HERE not in sys.path:  # `python -I` does not put the script folder on the path
    sys.path.insert(0, _HERE)

import wildbound_economy_sim_v2 as v2  # noqa: E402

REPO = v2.REPO
GOLD = "src/wildbound/WildboundGold.luau"
SPECIES = "src/wildbound/WildboundSpecies.luau"
RANK = {r: i for i, r in enumerate(v2.RARITIES)}

# ASSUMED player behaviour, one gold policy per live profile.
#   keep: never sells; duplicates: sells a creature that is not in the farm while another of its species stays;
#   all: sells every creature that is not in the farm and is not the companion.
GOLD_POLICY = {"beginner": "keep", "intermediate": "duplicates", "advanced": "all"}
ASSUMPTIONS = [
    ("gold_policy", GOLD_POLICY),
    ("companion", "the first hatched creature becomes the companion (State NS3) and never goes into the farm"),
    ("farm_fill", "every other hatch goes into a free farm place; a full farm swaps out its lowest rarity for a rarer one"),
    ("buy_order", "cheapest gold sink first, bought the moment it is affordable: farmSlot5, then farmSlot6, and the "
                  "next treadmill level"),
    ("gold_training", "a gold-bought treadmill level adds to the lap level; it does not speed up the modelled trips"),
    ("bond_level", "every sold creature is at bond level 1 (fresh hatches); the +20% per level is shown as a table"),
    ("sellers_and_the_limit", "a player who sells is never stopped by the collection limit (a sale frees the place), "
                              "so the duplicates and all policies run the live sessions with no collection limit"),
    ("sources", "hatches only: no refuge taming of wild creatures, no offline income, no Studio probe gold"),
    ("session", "the farm pays only during the session (owner in the game); nothing carries to the next session"),
]


class GoldUnavailable(v2.NumbersUnavailable):
    """WildboundGold.luau or the species table could not be read."""


def _table(text, name):
    found = re.search(re.escape(name) + r" = table\.freeze\(\{([^}]*)\}\)", text)
    if not found:
        raise GoldUnavailable(f"{GOLD}: {name} not found")
    return {k: float(v) if "." in v else int(v) for k, v in re.findall(r"(\w+) = ([0-9.]+)", found.group(1))}


def load_gold(repo=REPO):
    """Every gold rule the model uses, read from WildboundGold.luau; species rarities from WildboundSpecies.luau."""
    repo = Path(repo)
    text = v2.strip_comments(v2._read(repo, GOLD))
    gold = {
        "farm_per_minute": _table(text, "Gold.FARM_PER_MINUTE"),
        "sell_prices": _table(text, "Gold.SELL_PRICES"),
        "upgrade_prices": _table(text, "Gold.UPGRADE_PRICES"),
    }
    for key in ("TAME_BONUS", "LAP_BASE", "LAP_LEVELS_PER_EXTRA", "TREADMILL_CAP_PER_MINUTE", "SELL_LEVEL_BONUS",
                "SELL_MAX_LEVEL", "CAP_WINDOW", "TRAIN_BASE", "TRAIN_GROWTH"):
        gold[key] = v2._number(text, GOLD, r"Gold\." + key + r" = ([0-9.]+)")
    default = re.search(r'Gold\.DEFAULT_RARITY = "(\w+)"', text)
    if not default:
        raise GoldUnavailable(f"{GOLD}: DEFAULT_RARITY not found")
    gold["default_rarity"] = default.group(1)
    for table in ("farm_per_minute", "sell_prices"):
        if set(gold[table]) != set(v2.RARITIES):
            raise GoldUnavailable(f"{GOLD}: {table} must list {v2.RARITIES}")
    species_text = v2._read(repo, SPECIES)
    gold["species_rarity"] = dict(re.findall(r'\b(\w+) = \{ name = "\w+", rarity = "(\w+)"', species_text))
    if not gold["species_rarity"]:
        raise GoldUnavailable(f"{SPECIES}: LOOKS rarities not found")
    return gold


# ---- Pure rules (mirror WildboundGold.luau) ------------------------------------------------------------------------
def rarity_of(gold, species):
    rarity = gold["species_rarity"].get(species)
    return rarity if rarity in gold["farm_per_minute"] else gold["default_rarity"]


def farm_rate(gold, rarities):
    return sum(gold["farm_per_minute"].get(r, gold["farm_per_minute"][gold["default_rarity"]]) for r in rarities)


def lap_gold(gold, level):
    return int(gold["LAP_BASE"] + max(0, int(level)) // int(gold["LAP_LEVELS_PER_EXTRA"]))


def cap_lap(gold, window, now, amount):
    """Gold.capLap: returns (paid, window)."""
    if window is None or now - window[0] >= gold["CAP_WINDOW"] or now < window[0]:
        window = [now, 0]
    paid = max(0, min(int(amount), int(gold["TREADMILL_CAP_PER_MINUTE"]) - window[1]))
    window[1] += paid
    return paid, window


def train_price(gold, level, max_level):
    if level < 0 or level >= max_level:
        return None
    return math.floor(gold["TRAIN_BASE"] * gold["TRAIN_GROWTH"] ** int(level) + 0.5)


def sell_price(gold, rarity, level=1):
    base = gold["sell_prices"].get(rarity, gold["sell_prices"][gold["default_rarity"]])
    level = max(1, min(int(level), int(gold["SELL_MAX_LEVEL"])))
    return math.floor(base * (1 + gold["SELL_LEVEL_BONUS"] * (level - 1)) + 0.5)


def sink_ladder(gold, max_level):
    """Every gold purchase: the two farm places and each treadmill level from 0."""
    train = [train_price(gold, level, max_level) for level in range(int(max_level))]
    slots = [gold["upgrade_prices"][k] for k in sorted(gold["upgrade_prices"])]
    return {"farm_slots": slots, "train": train, "total": sum(slots) + sum(train)}


def afk_gold_per_minute(gold, farm_rarities, max_lap_level=0):
    """Gold per minute standing on the treadmill with the farm full: the lap cap plus the farm."""
    laps_per_min = 60.0 / 8.0
    treadmill = min(gold["TREADMILL_CAP_PER_MINUTE"], laps_per_min * lap_gold(gold, max_lap_level))
    return treadmill + farm_rate(gold, farm_rarities)


# ---- One session ---------------------------------------------------------------------------------------------------
def gold_session(gold, hatch_log, lap_log, minutes, policy, farm_slots, max_level):
    """Replays one live session's hatch and lap logs with the gold rules. Deterministic."""
    if policy not in ("keep", "duplicates", "all"):
        raise ValueError(f"unknown gold policy {policy!r}")
    end = minutes * 60.0
    events = sorted([(t, 0, ("hatch", species)) for t, _, species in hatch_log if t <= end]
                    + [(t, 1, ("lap", level)) for t, level in lap_log if t <= end])
    st = {"t": 0.0, "gold": 0.0, "farm": [], "cap": int(farm_slots), "companion": None, "collection": [],
          "lap_level": 0, "gold_levels": 0, "window": None}
    split = {"farm": 0.0, "tame": 0.0, "treadmill": 0.0, "sale": 0.0}
    spent = {"farmSlot5": None, "farmSlot6": None}
    train_times = []
    out = {"sold": 0, "hatches": 0}

    def level():
        return min(int(max_level), st["lap_level"] + st["gold_levels"])

    def owned(species):
        names = [s for _, s in st["farm"]] + [s for _, s in st["collection"]]
        if st["companion"]:
            names.append(st["companion"][1])
        return names.count(species)

    def apply_sales():
        for creature in list(st["collection"]):
            if policy == "all" or (policy == "duplicates" and owned(creature[1]) > 1):
                price = sell_price(gold, creature[0])
                st["gold"] += price
                split["sale"] += price
                out["sold"] += 1
                st["collection"].remove(creature)

    def fill_farm():
        st["collection"].sort(key=lambda c: -RANK[c[0]])
        while len(st["farm"]) < st["cap"] and st["collection"]:
            st["farm"].append(st["collection"].pop(0))

    def next_sink():
        options = []
        if spent["farmSlot5"] is None:
            options.append((gold["upgrade_prices"]["farmSlot5"], "farmSlot5"))
        elif spent["farmSlot6"] is None:
            options.append((gold["upgrade_prices"]["farmSlot6"], "farmSlot6"))
        price = train_price(gold, level(), max_level)
        if price is not None:
            options.append((price, "train"))
        return min(options) if options else None

    def buy_all(t):
        while True:
            sink = next_sink()
            if sink is None or st["gold"] + 1e-9 < sink[0]:
                return
            st["gold"] -= sink[0]
            if sink[1] == "train":
                st["gold_levels"] += 1
                train_times.append(t)
            else:
                spent[sink[1]] = t
                st["cap"] += 1
                fill_farm()

    def advance(to_t):
        # Farm gold accrues continuously; a sink is bought at the exact moment the balance reaches its price.
        while st["t"] < to_t:
            rate = farm_rate(gold, [r for r, _ in st["farm"]]) / 60.0
            sink = next_sink()
            if rate > 0 and sink is not None and st["gold"] < sink[0]:
                reach = st["t"] + (sink[0] - st["gold"]) / rate
                if reach < to_t:
                    gained = sink[0] - st["gold"]
                    st["gold"] = float(sink[0])
                    split["farm"] += gained
                    st["t"] = reach
                    buy_all(reach)
                    continue
            gained = rate * (to_t - st["t"])
            st["gold"] += gained
            split["farm"] += gained
            st["t"] = to_t
        buy_all(to_t)

    for t, _, (kind, value) in events:
        advance(t)
        if kind == "lap":
            st["lap_level"] = max(st["lap_level"], int(value))
            paid, st["window"] = cap_lap(gold, st["window"], t, lap_gold(gold, level()))
            st["gold"] += paid
            split["treadmill"] += paid
        else:
            out["hatches"] += 1
            creature = (rarity_of(gold, value), value)
            st["gold"] += gold["TAME_BONUS"]
            split["tame"] += gold["TAME_BONUS"]
            if st["companion"] is None:
                st["companion"] = creature
            elif len(st["farm"]) < st["cap"]:
                st["farm"].append(creature)
            else:
                low = min(range(len(st["farm"])), key=lambda i: RANK[st["farm"][i][0]])
                if RANK[creature[0]] > RANK[st["farm"][low][0]]:
                    st["collection"].append(st["farm"][low])
                    st["farm"][low] = creature
                else:
                    st["collection"].append(creature)
            apply_sales()
        buy_all(t)
    advance(end)
    all_sinks = None
    if level() >= max_level and spent["farmSlot6"] is not None:
        all_sinks = max([spent["farmSlot6"]] + train_times)
    return {
        "minutes": minutes, "gold_total": sum(split.values()), "split": split, "gold_end": st["gold"],
        "farm_slot_5_s": spent["farmSlot5"], "farm_slot_6_s": spent["farmSlot6"], "train_times": train_times,
        "gold_levels": st["gold_levels"], "farm_rate_end": farm_rate(gold, [r for r, _ in st["farm"]]),
        "farm_size_end": len(st["farm"]), "sold": out["sold"], "hatches": out["hatches"],
        "all_sinks_s": all_sinks,
    }


# ---- Runs and report -----------------------------------------------------------------------------------------------
def run_gold(live, gold, profiles, minutes_list, seed=7, runs=200, routes=v2.LIVE_ROUTES):
    max_level = int(live["training"]["MAX_LEVEL"])
    unlimited = dict(live, collection_limit=10 ** 9)
    cells = []
    for name, profile in profiles.items():
        policy = GOLD_POLICY.get(name, "keep")
        variant = live if policy == "keep" else unlimited
        for route in routes:
            for minutes in minutes_list:
                results = []
                for i in range(runs):
                    s = v2.simulate_live_session(variant, profile, route, minutes, seed + i)
                    results.append(gold_session(gold, s["hatch_log"], s["lap_log"], minutes, policy,
                                                live["farm_slots"], max_level))
                cells.append({
                    "profile": name, "route": route, "minutes": minutes, "runs": runs, "policy": policy,
                    "gold_per_min": v2._stats([r["gold_total"] / minutes for r in results]),
                    "gold_session": statistics.fmean(r["gold_total"] for r in results),
                    "split_per_min": {k: statistics.fmean(r["split"][k] / minutes for r in results)
                                      for k in results[0]["split"]},
                    "farm_slot_5_s": v2._reach([r["farm_slot_5_s"] for r in results]),
                    "farm_slot_6_s": v2._reach([r["farm_slot_6_s"] for r in results]),
                    "train_1_s": v2._reach([r["train_times"][0] if r["train_times"] else None for r in results]),
                    "gold_levels": statistics.fmean(r["gold_levels"] for r in results),
                    "all_sinks_s": v2._reach([r["all_sinks_s"] for r in results]),
                    "gold_end": statistics.fmean(r["gold_end"] for r in results),
                    "farm_rate_end": statistics.fmean(r["farm_rate_end"] for r in results),
                    "hatches": statistics.fmean(r["hatches"] for r in results),
                    "sold": statistics.fmean(r["sold"] for r in results),
                })
    return {"seed": seed, "runs": runs, "cells": cells, "gold": gold, "max_level": max_level,
            "farm_slots": live["farm_slots"], "sinks": sink_ladder(gold, max_level)}


def _m(reach):
    return v2._mins(reach)


def render_md(report, command):
    gold, sinks = report["gold"], report["sinks"]
    fpm = gold["farm_per_minute"]
    lines = [
        "### Gold (Oro) model",
        "",
        f"Regenerate: `{command}`",
        "",
        f"Seed {report['seed']}, {report['runs']} runs per cell. Each live session above is replayed with the gold "
        f"rules from `{GOLD}`. A model with ASSUMED player choices (listed under the tables), not measured play.",
        "",
        f"- Farm gold per minute: Comun {fpm['Comun']:g}, Rara {fpm['Rara']:g}, Epica {fpm['Epica']:g}, "
        f"Legendaria {fpm['Legendaria']:g}. Tame/hatch bonus {gold['TAME_BONUS']:g}. Lap {gold['LAP_BASE']:g} "
        f"(+1 per {gold['LAP_LEVELS_PER_EXTRA']:g} levels), cap {gold['TREADMILL_CAP_PER_MINUTE']:g} per "
        f"{gold['CAP_WINDOW']:g} s.",
        "- Sale: " + ", ".join(f"{r} {gold['sell_prices'][r]:g}" for r in v2.RARITIES)
        + f" at bond level 1, +{gold['SELL_LEVEL_BONUS'] * 100:g}% per level above 1 (cap level "
          f"{gold['SELL_MAX_LEVEL']:g}).",
        f"- Sinks: farm places {'/'.join(str(p) for p in sinks['farm_slots'])}, treadmill levels "
        f"{sinks['train'][0]} to {sinks['train'][-1]} ({len(sinks['train'])} levels, {sum(sinks['train'])} in all). "
        f"Every gold sink: {sinks['total']} gold.",
        "",
        "| Profile | Route | Min | Sells | Gold/min | Farm | Tame | Treadmill | Sale | Gold per session | Farm place 5 "
        "| Farm place 6 | Treadmill level 1 | Gold levels | Every sink bought | Unspent at end | Farm gold/min at end "
        "| Hatches | Sold |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- "
        "| --- |",
    ]
    for c in report["cells"]:
        g, s = c["gold_per_min"], c["split_per_min"]
        lines.append(
            f"| {c['profile']} | {c['route']} | {c['minutes']} | {c['policy']} | {g['mean']:.1f} ({g['p10']:.1f}-"
            f"{g['p90']:.1f}) | {s['farm']:.1f} | {s['tame']:.1f} | {s['treadmill']:.1f} | {s['sale']:.1f} | "
            f"{c['gold_session']:.0f} | {_m(c['farm_slot_5_s'])} | {_m(c['farm_slot_6_s'])} | {_m(c['train_1_s'])} | "
            f"{c['gold_levels']:.1f} | {_m(c['all_sinks_s'])} | {c['gold_end']:.0f} | {c['farm_rate_end']:.1f} | "
            f"{c['hatches']:.1f} | {c['sold']:.1f} |")
    lines += [
        "",
        "Times are session minutes (share of runs when under 100%; `-` never). Gold levels: treadmill levels bought "
        "with gold in the session.",
        "",
        "| Rarity | Farm gold/min | Sale bond 1 | Sale bond 5 | Sale bond 10 | Minutes of farm a bond 1 sale is worth |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for r in v2.RARITIES:
        lines.append(f"| {r} | {fpm[r]:g} | {sell_price(gold, r, 1)} | {sell_price(gold, r, 5)} | "
                     f"{sell_price(gold, r, 10)} | {sell_price(gold, r, 1) / fpm[r]:.1f} |")
    lines += ["", f"- AFK on the treadmill: {afk_gold_per_minute(gold, []):g} gold/min with an empty farm "
                  f"(the cap binds from level 0: {60 / 8:g} laps of {lap_gold(gold, 0)}), "
                  f"{afk_gold_per_minute(gold, ['Epica'] * (report['farm_slots'] + 2)):g} with six Epica in the farm, "
                  f"{afk_gold_per_minute(gold, ['Legendaria'] * (report['farm_slots'] + 2)):g} with six Legendaria.",
              ""]
    lines += [f"- ASSUMED `{k}`: {v}" for k, v in ASSUMPTIONS]
    lines.append("")
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Wildbound gold (Oro) model over the live sessions. Not measured data.")
    parser.add_argument("--profile", default="all")
    parser.add_argument("--minutes", default="10,30,60")
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--runs", type=int, default=200)
    parser.add_argument("--md", action="store_true", help="print the markdown section")
    args = parser.parse_args(argv)
    live, gold = v2.load_live_game(), load_gold()
    profiles = v2.default_live_profiles()
    if args.profile != "all":
        profiles = {k: v for k, v in profiles.items() if k in args.profile.split(",")}
        if not profiles:
            parser.error(f"unknown profile {args.profile!r}")
    report = run_gold(live, gold, profiles, [int(m) for m in args.minutes.split(",")], args.seed, args.runs)
    command = ("python -I -B tools/wildbound_gold_sim.py " + " ".join(argv if argv is not None else sys.argv[1:])).strip()
    text = render_md(report, command)
    buffer = getattr(sys.stdout, "buffer", None)
    if buffer is not None:
        sys.stdout.flush()
        buffer.write(text.encode("utf-8"))
        buffer.flush()
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())

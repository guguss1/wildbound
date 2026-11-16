"""Wildbound gold (Oro) economy model (owner item O7, 2026-11-16). A model, not measured play data.

Gold is a layer over the live game model in wildbound_economy_sim_v2: each live session already records when every
egg hatches (rarity, species) and every treadmill lap (time, level). This tool replays those logs with the gold rules
read from src/wildbound/WildboundGold.luau (farm gold per minute by rarity, the tame/hatch bonus, lap gold under the
per-minute cap, the creature sale price, the idle pause) and buys the gold sinks (farm places 5 to 8, treadmill levels)
as soon as they are affordable. Every player choice below is ASSUMED.

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
    ("buy_order", "cheapest gold sink first, bought the moment it is affordable: the next farm place (5, 6, 7, 8 in "
                  "order) or the next treadmill level"),
    ("idle", "an active player moves all the time; only a run of back-to-back treadmill laps holds them still, so the "
             "farm pauses after the idle time inside such a run (Gold.idle)"),
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
                "SELL_MAX_LEVEL", "CAP_WINDOW", "TRAIN_BASE", "TRAIN_GROWTH", "IDLE_SECONDS", "IDLE_MOVE_STUDS"):
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


def farm_slot_names(gold):
    """The farm places sold for gold, in buying order (farmSlot5, farmSlot6, ...; each needs the one before)."""
    return sorted((k for k in gold["upgrade_prices"] if re.fullmatch(r"farmSlot\d+", k)), key=lambda k: int(k[8:]))


def sink_ladder(gold, max_level):
    """Every gold purchase: the farm places and each treadmill level from 0."""
    train = [train_price(gold, level, max_level) for level in range(int(max_level))]
    slots = [gold["upgrade_prices"][k] for k in farm_slot_names(gold)]
    return {"farm_slots": slots, "train": train, "total": sum(slots) + sum(train)}


def afk_gold_per_minute(gold, farm_rarities, max_lap_level=0):
    """Gold per minute standing on the treadmill with the farm full, before the idle pause: the lap cap plus the farm."""
    laps_per_min = 60.0 / 8.0
    treadmill = min(gold["TREADMILL_CAP_PER_MINUTE"], laps_per_min * lap_gold(gold, max_lap_level))
    return treadmill + farm_rate(gold, farm_rarities)


def afk_gold_per_hour(gold, farm_rarities, max_lap_level=0):
    """Gold in 60 min standing still on the treadmill: the farm pays until the idle pause (Gold.idle), laps all hour."""
    laps_per_min = 60.0 / 8.0
    treadmill = min(gold["TREADMILL_CAP_PER_MINUTE"], laps_per_min * lap_gold(gold, max_lap_level))
    farm_minutes = min(60.0, gold.get("IDLE_SECONDS", 3600.0) / 60.0)
    return treadmill * 60.0 + farm_rate(gold, farm_rarities) * farm_minutes


def idle_spans(gold, lap_log, lap_seconds=8.0):
    """Stretches where the farm is paused: a run of back-to-back treadmill laps holds the player still on the belt, so
    after IDLE_SECONDS of it (Gold.idle) the farm stops until the run ends. Returns [(start, end)] in seconds."""
    idle = gold.get("IDLE_SECONDS")
    if not idle or not lap_log:
        return []
    spans, start, last = [], None, None
    for t, _ in sorted(lap_log):
        if last is None or t - last > lap_seconds + 1e-6:
            if last is not None and last - start > idle:
                spans.append((start + idle, last))
            start = t - lap_seconds
        last = t
    if last - start > idle:
        spans.append((start + idle, last))
    return spans


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
    slot_names = farm_slot_names(gold)
    spent = {name: None for name in slot_names}
    train_times = []
    out = {"sold": 0, "hatches": 0, "paused_s": 0.0}
    paused = [(a, min(b, end)) for a, b in idle_spans(gold, [(t, lv) for t, lv in lap_log if t <= end]) if a < end]

    def farm_paused(t):
        """(paused now, the next time that changes)."""
        for a, b in paused:
            if a <= t < b:
                return True, b
            if t < a:
                return False, a
        return False, float("inf")

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
        for name in slot_names:  # each farm place needs the one before it
            if spent[name] is None:
                options.append((gold["upgrade_prices"][name], name))
                break
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
        # Gold.idle: the farm pays nothing while the player has stood still for IDLE_SECONDS (long treadmill runs).
        while st["t"] < to_t:
            idle, change = farm_paused(st["t"])
            stop = min(to_t, change)
            if idle:
                out["paused_s"] += stop - st["t"]
                st["t"] = stop
                continue
            rate = farm_rate(gold, [r for r, _ in st["farm"]]) / 60.0
            sink = next_sink()
            if rate > 0 and sink is not None and st["gold"] < sink[0]:
                reach = st["t"] + (sink[0] - st["gold"]) / rate
                if reach < stop:
                    gained = sink[0] - st["gold"]
                    st["gold"] = float(sink[0])
                    split["farm"] += gained
                    st["t"] = reach
                    buy_all(reach)
                    continue
            gained = rate * (stop - st["t"])
            st["gold"] += gained
            split["farm"] += gained
            st["t"] = stop
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
    if level() >= max_level and all(spent[name] is not None for name in slot_names):
        all_sinks = max([spent[name] for name in slot_names] + train_times)
    return {
        "minutes": minutes, "gold_total": sum(split.values()), "split": split, "gold_end": st["gold"],
        "farm_slots_s": dict(spent), "farm_slot_5_s": spent.get("farmSlot5"), "farm_slot_6_s": spent.get("farmSlot6"),
        "train_times": train_times,
        "gold_levels": st["gold_levels"], "farm_rate_end": farm_rate(gold, [r for r, _ in st["farm"]]),
        "farm_size_end": len(st["farm"]), "sold": out["sold"], "hatches": out["hatches"],
        "all_sinks_s": all_sinks, "farm_paused_s": out["paused_s"],
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
                    "farm_slots_s": {name: v2._reach([r["farm_slots_s"][name] for r in results])
                                     for name in farm_slot_names(gold)},
                    "farm_paused_min": statistics.fmean(r["farm_paused_s"] / 60.0 for r in results),
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
        f"{sinks['train'][0]} to {sinks['train'][-1]} ({len(sinks['train'])} levels, {sum(sinks['train'])} in all, "
        f"x{gold['TRAIN_GROWTH']:g} per level). Every gold sink: {sinks['total']} gold.",
        f"- Idle pause: the farm pays nothing after {gold.get('IDLE_SECONDS', 0) / 60:g} min without moving "
        f"{gold.get('IDLE_MOVE_STUDS', 0):g} studs (a treadmill run holds the player still).",
        "",
    ]
    slot_names = farm_slot_names(gold)
    head = (["Profile", "Route", "Min", "Sells", "Gold/min", "Farm", "Tame", "Treadmill", "Sale", "Gold per session"]
            + [f"Farm place {name[8:]}" for name in slot_names]
            + ["Treadmill level 1", "Gold levels", "Every sink bought", "Unspent at end", "Farm gold/min at end",
               "Farm paused min", "Hatches", "Sold"])
    lines += ["| " + " | ".join(head) + " |", "|" + " --- |" * len(head)]
    for c in report["cells"]:
        g, s = c["gold_per_min"], c["split_per_min"]
        cells = ([c["profile"], c["route"], str(c["minutes"]), c["policy"],
                  f"{g['mean']:.1f} ({g['p10']:.1f}-{g['p90']:.1f})", f"{s['farm']:.1f}", f"{s['tame']:.1f}",
                  f"{s['treadmill']:.1f}", f"{s['sale']:.1f}", f"{c['gold_session']:.0f}"]
                 + [_m(c["farm_slots_s"][name]) for name in slot_names]
                 + [_m(c["train_1_s"]), f"{c['gold_levels']:.1f}", _m(c["all_sinks_s"]), f"{c['gold_end']:.0f}",
                    f"{c['farm_rate_end']:.1f}", f"{c['farm_paused_min']:.1f}", f"{c['hatches']:.1f}",
                    f"{c['sold']:.1f}"])
        lines.append("| " + " | ".join(cells) + " |")
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
    full = report["farm_slots"] + len(slot_names)
    lines += ["", f"- AFK on the treadmill: {afk_gold_per_minute(gold, []):g} gold/min with an empty farm "
                  f"(the cap binds from level 0: {60 / 8:g} laps of {lap_gold(gold, 0)}), "
                  f"{afk_gold_per_minute(gold, ['Epica'] * full):g} with {full} Epica in the farm, "
                  f"{afk_gold_per_minute(gold, ['Legendaria'] * full):g} with {full} Legendaria, until the idle pause. "
                  f"A whole idle hour pays {afk_gold_per_hour(gold, []):.0f} (empty farm), "
                  f"{afk_gold_per_hour(gold, ['Epica'] * full):.0f} ({full} Epica) or "
                  f"{afk_gold_per_hour(gold, ['Legendaria'] * full):.0f} ({full} Legendaria): "
                  f"{afk_gold_per_hour(gold, ['Epica'] * full) / 60:.1f} per minute with the Epica farm.",
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

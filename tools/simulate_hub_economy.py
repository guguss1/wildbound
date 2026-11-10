"""Wildbound hub economy simulator: sessions, corral, ladders and offers as modifiers.

Reads the fenced ```json economy-synthesis block of docs/design/wildbound-economy-and-offers.md
at run time (nothing in it is copied here), checks the document's shape rules, then simulates a
free and a paying player over 20-minute sessions with hub turnaround, corral income under the
working rule and the active-income cap, the skill tree, the equipment ladder, pens, incubator and
breeder ladders, and the Robux rows modelled only as purchase modifiers in the paying policy
(nothing is a product; `monetization` must be "none" or the tool refuses to run).

THIS MODELS MATH ONLY. It says nothing about fun or balance, and the policies are the document's
invented archetypes, not players. `tools/simulate_economy.py` (the P0 expedition simulator) stays
untouched; this tool imports it for the shared helpers and for the P0 tuning block, so the first
two tree tiers are cross-checked against the ids and costs that exist today.

SIMULATOR ASSUMPTIONS (not game data; every one is printed in the report):
  * a session is 20 minutes of play: a 2-minute first steal near the hub, then 6-minute cycles of
    5 minutes out and 1 minute at the hub, the last one shortened so the session ends at a hub
    minute; the pattern repeats every 20 minutes;
  * active income per cycle, materials per cycle and the rarity script come from
    `simulatorInputs`; one creature comes home per cycle; duplicates are drawn from small species
    pools so the duplicate rule bites;
  * the corral accrues per minute: full rate while the owner is out (every out minute of this
    model is inside an active window, since every cycle steals and gathers), a quarter at the
    hub, and the credited total never exceeds the corral cap (a share of the owner's own rolling
    extraction income over the last 20 minutes of play, plus a fixed amount per filled pen past the
    free ones); the plaque rate is the credited rate, so the cap scales every creature proportionally;
  * feeding happens at every hub visit with one common or uncommon material per creature whose
    window is over, and only after an expedition since the last feed; collection happens at
    every hub visit;
  * a creature that comes home to full pens replaces the lowest-rate pen creature if it earns
    more, otherwise its placement is refused and it stays in the collection;
  * the free player buys in the document's fixed priority order, saving for the next entry,
    then cheapest first; the paying player accepts every card the surfacing rules allow;
  * `--persistence off` discards the whole profile at every session boundary (what the game
    can do today); `on` keeps it (what the design needs);
  * the "Bolsa llena" notice is an invented chance per cycle before the Pack exists; the second
    incubator card needs two eggs in the incubator at once, which this one-creature-per-cycle
    model never produces, so that row is reported as "not triggered";
  * time of day, defeats, beasts, totems and cosmetics are not modelled here; the P0 simulator
    owns the expedition floor and the capture and sprint invariants.

Usage (from the project root):

    python -I -B tools/simulate_hub_economy.py [--runs N] [--sessions N] [--seed N] [--persistence on|off|both]
"""

import argparse
import copy
import json
import math
import random
import re
import statistics
import sys
from dataclasses import dataclass, field
from pathlib import Path

_HERE = str(Path(__file__).resolve().parent)
if _HERE not in sys.path:  # `python -I` does not put the script folder on the path
    sys.path.insert(0, _HERE)

import simulate_economy as p0  # noqa: E402  (shared helpers and the P0 tuning block)

REPO = Path(__file__).resolve().parent.parent
DOC = REPO / "docs/design/wildbound-economy-and-offers.md"
P0_DOC = p0.DOC
FENCE = re.compile(r"^```json economy-synthesis[ \t]*\n(.*?)^```[ \t]*$", re.M | re.S)
SCHEMA = "wildbound.economy.synthesis"
SCHEMA_VERSION = 2
SESSION_MINUTES = int(p0.SESSION_MINUTES)
TuningError = p0.TuningError
_median = p0._median

BRANCHES = ("explorer", "capturer", "survivor", "occultist")
PIECES = ("guantes", "botas", "chaleco", "amuleto")
LEVEL_NAMES = {1: "I", 2: "II", 3: "III"}
ROLES = ("common", "uncommon", "rare")
ACCESSIBILITY_KEYS = ("fearMuted", "heartbeatMuted", "vignetteMuted", "shakeMuted", "accessibility", "modoTranquilo")
POWER_GRANT_WORDS = ("skill", "tree", "node", "totem", "multiplier", "hatch", "levelII", "levelIII", "esencia", "ember")
OFFER_STRING_KEYS = ("offerButton", "freeLine", "freeLineExample", "ladderSentence", "decline", "puestoHeadline")


# ---- Reading the document ---------------------------------------------------
def extract_synthesis(text):
    blocks = FENCE.findall(text)
    if len(blocks) != 1:
        raise TuningError(f"expected exactly one ```json economy-synthesis block, found {len(blocks)}")
    try:
        syn = json.loads(blocks[0])
    except json.JSONDecodeError as error:
        raise TuningError(f"economy-synthesis block is not valid JSON: {error}") from error
    if syn.get("schema") != SCHEMA:
        raise TuningError(f"unexpected schema {syn.get('schema')!r}")
    if syn.get("schemaVersion") != SCHEMA_VERSION:
        raise TuningError(f"unsupported schemaVersion {syn.get('schemaVersion')!r} (this tool reads {SCHEMA_VERSION})")
    if syn.get("monetization") != "none":
        raise TuningError("monetization is not 'none'; this tool models offers only as purchase modifiers")
    return syn


def load_synthesis(path=DOC):
    try:
        text = Path(path).read_text(encoding="utf-8")
    except OSError as error:
        raise TuningError(f"cannot read {path}: {error}") from error
    return extract_synthesis(text)


def role_of(syn, material):
    for role, ids in syn["materialRoles"].items():
        if isinstance(ids, list) and material in ids:
            return role
    return None


def p0_cost_as_roles(syn, cost):
    """Translate a P0 cost (`ember` plus material ids) into the role shape of this design."""
    out = {}
    for key, amount in cost.items():
        if key == "ember":
            out["ember"] = out.get("ember", 0) + amount
            continue
        role = role_of(syn, key)
        if role is None:
            raise TuningError(f"P0 cost names {key!r}, which no material role lists")
        out[role] = out.get(role, 0) + amount
    return out


# ---- Ladders (pure) ---------------------------------------------------------
def round_to(value, step):
    return int(round(value / step)) * step


def ladder_costs(base, ratio, rounding, steps):
    return [round_to(base * ratio ** n, rounding) for n in range(steps)]


def tree_cost(syn, tier):
    tree = syn["tree"]
    cost = {"ember": tree["esenciaByTier"][tier - 1]}
    for role in ROLES:
        amount = tree["materialsByTier"][role][tier - 1]
        if amount:
            cost[role] = amount
    return cost


def equipment_step_cost(syn, levels_owned, level):
    eq = syn["equipment"]
    cost = {"ember": eq["costs"][levels_owned]}
    cost.update(eq["materialsByLevel"][LEVEL_NAMES[level]])
    return cost


def pen_cost(syn, pen_index):
    """Cost of pen number `pen_index` (1-based); the free pens cost nothing."""
    free = syn["corral"]["freeSlots"]
    if pen_index <= free:
        return {}
    return {"ember": syn["corral"]["slotLadder"][pen_index - free - 1]}


def breeder_cost(syn, level):
    return {"ember": syn["breeder"]["costs"][level - 1]}


def nido_cost(syn, level):
    return {"ember": syn["incubator"]["nidoCalido"]["costs"][level - 1]}


def can_pay(wallet, cost):
    return all(wallet.get(key, 0) >= amount for key, amount in cost.items())


def pay(wallet, cost):
    if not can_pay(wallet, cost):
        return False
    for key, amount in cost.items():
        wallet[key] -= amount
    return True


# ---- Corral (pure) ----------------------------------------------------------
def nominal_rates(syn, pens):
    """Per-creature nominal rate with the duplicate rule; `pens` is a list of (species, rarity)."""
    rates = syn["corral"]["ratePerMinute"]
    factors = syn["corral"]["duplicateFactors"]
    seen = {}
    out = []
    for species, rarity in pens:
        key = (species, rarity)
        index = seen.get(key, 0)
        seen[key] = index + 1
        out.append(rates[rarity] * factors[min(index, len(factors) - 1)])
    return out


def corral_cap(syn, filled_pens, rolling_active_per_minute):
    """The corral ceiling per minute: a share of the owner's own rolling extraction income, plus a fixed amount
    for every filled pen past the free ones, so every pen bought still raises what the corral can pay."""
    cap = syn["corral"]["activeIncomeCap"]
    extra = max(0, filled_pens - syn["corral"]["freeSlots"])
    return cap["share"] * max(0.0, rolling_active_per_minute) + cap.get("perExtraPen", 0.0) * extra


def credited_rates(syn, pens, rolling_active_per_minute, share):
    """What each plaque shows and what each creature credits this minute: the nominal rate scaled by the
    corral cap (applied before the working-rule share) and by the share."""
    nominal = nominal_rates(syn, pens)
    total = sum(nominal)
    cap = corral_cap(syn, len(pens), rolling_active_per_minute)
    scale = 1.0 if total <= cap or total == 0 else cap / total
    return [rate * scale * share for rate in nominal]


def rate_share(syn, *, alive=True, in_server=True, active_window=False):
    shares = syn["corral"]["rateShare"]
    if not alive or not in_server:
        return shares["deadOrAway"]
    return shares["activeWindow"] if active_window else shares["otherwiseAlive"]


def idle_hour_credit(syn, pens, rolling_active_per_minute, *, fed=True, refeeds=0):
    """K8: an idle hour anywhere alive credits at most the quarter rate for one feeding window (storage and
    the feed rule cap it); re-feeding needs an expedition in between, so `refeeds` beyond 0 are refused."""
    if not fed:
        return 0.0
    minutes = min(syn["corral"]["feed"]["windowMinutes"], syn["corral"]["storageMinutes"])
    share = rate_share(syn, active_window=False)
    windows = 1 if syn["corral"]["feed"]["requiresExpeditionSinceLastFeed"] else 1 + refeeds
    return sum(credited_rates(syn, pens, rolling_active_per_minute, share)) * minutes * windows


# ---- Offer surfacing (pure) -------------------------------------------------
def card_allowed(syn, player, minute, row_id, step_key):
    """The surfacing rules of section 8.1 as one predicate. `player` is a Player; `minute` the play minute."""
    rules = syn["offerRules"]
    if player.session_index < rules["minSessionIndex"]:
        return False
    if player.cumulative_minutes_before_session + player.minute_in_session < rules["minCumulativeMinutes"]:
        return False
    if player.minute_in_session < rules["quietMinutesEachSession"]:
        return False
    if player.last_card_minute is not None and minute - player.last_card_minute < rules["minMinutesBetweenOffers"]:
        return False
    if player.cards_this_session >= rules["maxCardsPer20Minutes"]:
        return False
    if (row_id, step_key) in player.shown_this_session:
        return False
    if player.last_refusal_or_notice_minute is not None:
        if (minute - player.last_refusal_or_notice_minute) * 60.0 < rules["noCardWithinSecondsOfRefusalOrNotice"]:
            return False
    return True


def free_path_estimate(design_median_minutes, own_minutes, data_minutes, syn):
    """Rule 2: the design median is printed; the player's own figure only when it is lower and based on
    enough data. Never above the design median."""
    rules = syn["offerRules"]["estimate"]
    if own_minutes is not None and data_minutes >= rules["ownMinDataMinutes"] and own_minutes < design_median_minutes:
        return own_minutes
    return design_median_minutes


def own_minutes_for(cost, esencia_per_minute, materials_per_minute, syn):
    """The player's own time to earn a step, with the income floor of rule 2 and materials included."""
    floor = syn["offerRules"]["estimate"]["ownFloorPerMinute"]
    rate = max(esencia_per_minute, floor)
    minutes = cost.get("ember", 0) / rate
    for role in ROLES:
        need = cost.get(role, 0)
        if need:
            per_minute = materials_per_minute.get(role, 0.0)
            minutes = max(minutes, need / per_minute if per_minute > 0 else math.inf)
    return minutes


def lint_copy(syn):
    """Rule 11: descriptive purchase copy. Returns the offending (key, token) pairs."""
    tokens = [t.lower() for t in syn["offerRules"]["forbiddenCopyTokens"]]
    problems = []
    for key in OFFER_STRING_KEYS:
        text = syn["strings"].get(key, "").lower()
        for token in tokens:
            if re.search(r"(?<!\w)" + re.escape(token) + r"(?!\w)", text) or (not token[-1:].isalnum() and token in text):
                problems.append((key, token))
    return problems


def free_price_of_grant(syn, row_id, player, slot=None):
    """Esencia-equivalent of what a card grants (the free price, Esencia only; materials are reported apart)."""
    if row_id == "equipoExplorador":
        return syn["equipment"]["costs"][player.levels_owned()]
    if row_id == "unCorralMas":
        return pen_cost(syn, slot)["ember"]
    if row_id == "bolsaGrande":
        return player.pack_cost["ember"]
    if row_id == "segundaIncubadora":
        return syn["incubator"]["secondSlot"]
    raise KeyError(row_id)


def robux_of(row, slot=None):
    if "robuxApproxBySlot" in row:
        return row["robuxApproxBySlot"][str(slot)]
    return row["robuxApprox"]


# ---- Players ----------------------------------------------------------------
@dataclass
class Creature:
    species: str
    rarity: str
    fed_until: float = -1.0
    stored: float = 0.0
    last_fed_cycle: int = -1


@dataclass
class Player:
    syn: dict
    p0_tuning: dict
    paying: bool
    wallet: dict = field(default_factory=lambda: {"ember": 0, "common": 0, "uncommon": 0, "rare": 0})
    skills: set = field(default_factory=set)
    equipment: dict = field(default_factory=lambda: {piece: 0 for piece in PIECES})
    pens_owned: int = 4
    pens: list = field(default_factory=list)
    collection: list = field(default_factory=list)
    farol: bool = False
    pack: bool = False
    incubator2: bool = False
    nido: int = 0
    breeder: int = 0
    earned_active: float = 0.0
    earned_corral: float = 0.0
    spent_permanent: float = 0.0          # Esencia-equivalent (free price) of every permanent owned
    granted_value: float = 0.0            # free price of everything granted by a card
    robux_spent: int = 0
    purchases: list = field(default_factory=list)
    price_sequence: list = field(default_factory=list)
    events: list = field(default_factory=list)
    active_log: list = field(default_factory=list)   # (minute, esencia)
    material_log: list = field(default_factory=list)  # (minute, role, units)
    session_index: int = 1
    minute_in_session: int = 0
    cumulative_minutes_before_session: int = 0
    cards_this_session: int = 0
    shown_this_session: set = field(default_factory=set)
    last_card_minute: object = None
    last_refusal_or_notice_minute: object = None
    refused_placement_pending: bool = False
    full_bag_notices_session: int = 0
    cycles_out: int = 0
    rarity_cursor: int = 0
    firsts: dict = field(default_factory=dict)
    corral_share_at: dict = field(default_factory=dict)
    progress_log: list = field(default_factory=list)  # (minute, spent_permanent + granted_value)

    def __post_init__(self):
        self.pens_owned = self.syn["corral"]["freeSlots"]
        self.pack_cost = p0_cost_as_roles(self.syn, self.p0_tuning["upgrades"]["reinforcedPack"]["cost"])
        self.farol_cost = p0_cost_as_roles(self.syn, self.p0_tuning["upgrades"]["farolTapado"]["cost"])

    # -- derived -------------------------------------------------------------
    def levels_owned(self):
        return sum(self.equipment.values())

    def branch_tier(self, branch):
        return max([int(s.split("_")[1]) for s in self.skills if s.startswith(branch + "_")] or [0])

    def rolling_active(self, minute, window=None):
        window = window or self.syn["corral"]["activeIncomeCap"]["windowMinutes"]
        total = sum(amount for at, amount in self.active_log if minute - window < at <= minute)
        return total / float(window)

    def rolling_materials(self, minute, window=20):
        out = {role: 0.0 for role in ROLES}
        for at, role, units in self.material_log:
            if minute - window < at <= minute:
                out[role] += units
        return {role: units / float(window) for role, units in out.items()}

    def note_first(self, key, minute):
        if key not in self.firsts:
            self.firsts[key] = minute

    def record_progress(self, minute):
        self.progress_log.append((minute, self.spent_permanent + self.granted_value))


# ---- One simulation ---------------------------------------------------------
def _cycle_income(syn, player):
    inputs = syn["simulatorInputs"]
    esencia = inputs["activeEsenciaPerCycle"]
    bonus = inputs["activeBonusPerCycle"]
    if "explorer_1" in player.skills:
        esencia += bonus.get("explorer_1", 0)
    if player.equipment["guantes"] >= 1:
        esencia += bonus.get("guantes1", 0)
    if player.equipment["botas"] >= 1:
        esencia += bonus.get("botas1", 0)
    if player.pack:
        esencia += bonus.get("reinforcedPack", 0)
    esencia *= 1.0 + syn["breeder"]["extractionBonusPerLevel"] * player.breeder
    return esencia


def _arrive_creature(syn, player, minute, rng):
    inputs = syn["simulatorInputs"]
    script = inputs["rarityScript"]
    rarity = script[player.rarity_cursor % len(script)]
    player.rarity_cursor += 1
    species = f"{rarity}{rng.randrange(inputs['speciesPerRarity'][rarity])}"
    creature = Creature(species, rarity)
    player.collection.append(creature)
    player.note_first(f"first_{rarity}", minute)
    rates_now = nominal_rates(syn, [(c.species, c.rarity) for c in player.pens])
    if len(player.pens) < player.pens_owned:
        player.pens.append(creature)
        return
    candidate = nominal_rates(syn, [(c.species, c.rarity) for c in player.pens] + [(species, rarity)])[-1]
    if rates_now and candidate > min(rates_now):
        index = rates_now.index(min(rates_now))
        removed = player.pens[index]
        player.wallet["ember"] += removed.stored          # stored output is collected first
        player.earned_corral += removed.stored
        removed.stored = 0.0
        player.pens[index] = creature
        return
    player.refused_placement_pending = True
    player.last_refusal_or_notice_minute = minute
    player.events.append((minute, "placement refused: pens full"))


def _corral_tick(syn, player, minute, share):
    pens = [(c.species, c.rarity) for c in player.pens]
    credited = credited_rates(syn, pens, player.rolling_active(minute), share)
    storage = syn["corral"]["storageMinutes"]
    nominal = nominal_rates(syn, pens)
    for creature, rate, nominal_rate in zip(player.pens, credited, nominal):
        if creature.fed_until <= minute:
            continue
        room = storage * nominal_rate - creature.stored
        creature.stored += max(0.0, min(rate, room))


def _hub_collect_and_feed(syn, player, minute):
    feed = syn["corral"]["feed"]
    for creature in player.pens:
        player.wallet["ember"] += creature.stored
        player.earned_corral += creature.stored
        creature.stored = 0.0
        if creature.fed_until > minute + 1:
            continue
        if feed["requiresExpeditionSinceLastFeed"] and creature.last_fed_cycle == player.cycles_out:
            continue
        for role in feed["roles"]:
            if player.wallet[role] >= feed["units"]:
                player.wallet[role] -= feed["units"]
                creature.fed_until = minute + feed["windowMinutes"]
                creature.last_fed_cycle = player.cycles_out
                break


def _spend(player, cost, label, minute):
    player.wallet = dict(player.wallet)
    pay(player.wallet, cost)
    player.spent_permanent += cost.get("ember", 0)
    player.events.append((minute, f"bought {label}"))
    player.note_first(label, minute)


def _next_equipment(syn, player, prefer=None):
    """The next equipment purchase the free priority means: level I of the next piece, then level II/III where
    the branch tier allows. Returns (piece, level) or None."""
    order = list(prefer or []) + [p for p in PIECES if p not in (prefer or [])]
    for level in (1, 2, 3):
        gate = syn["equipment"]["levelGates"].get(LEVEL_NAMES[level], {}).get("branchTier", 0)
        for piece in order:
            if player.equipment[piece] == level - 1 and player.branch_tier(syn["equipment"]["pieces"][piece]["branch"]) >= gate:
                return piece, level
    return None


def _try_buy(syn, player, entry, minute):
    """Returns 'owned', 'bought' or 'short' for one free-priority entry."""
    if entry == "farolTapado":
        if player.farol:
            return "owned"
        if pay(player.wallet, player.farol_cost):
            player.farol = True
            player.spent_permanent += player.farol_cost["ember"]
            player.note_first("farolTapado", minute)
            return "bought"
        return "short"
    if entry == "reinforcedPack":
        if player.pack:
            return "owned"
        if pay(player.wallet, player.pack_cost):
            player.pack = True
            player.spent_permanent += player.pack_cost["ember"]
            player.note_first("reinforcedPack", minute)
            return "bought"
        return "short"
    if entry == "secondIncubator":
        if player.incubator2:
            return "owned"
        cost = {"ember": syn["incubator"]["secondSlot"]}
        if pay(player.wallet, cost):
            player.incubator2 = True
            player.spent_permanent += cost["ember"]
            player.note_first("secondIncubator", minute)
            return "bought"
        return "short"
    if entry.startswith("slot"):
        pen = int(entry[4:])
        if player.pens_owned >= pen:
            return "owned"
        if player.pens_owned != pen - 1:
            return "short"
        cost = pen_cost(syn, pen)
        if pay(player.wallet, cost):
            player.pens_owned = pen
            player.spent_permanent += cost["ember"]
            player.price_sequence.append(("pen", pen, cost["ember"]))
            player.note_first(entry, minute)
            return "bought"
        return "short"
    if entry.startswith("nido"):
        level = int(entry[4:])
        if player.nido >= level:
            return "owned"
        if player.nido != level - 1:
            return "short"
        cost = nido_cost(syn, level)
        if pay(player.wallet, cost):
            player.nido = level
            player.spent_permanent += cost["ember"]
            player.note_first(entry, minute)
            return "bought"
        return "short"
    if entry.startswith("breeder"):
        level = int(entry[7:])
        if player.breeder >= level:
            return "owned"
        if player.breeder != level - 1:
            return "short"
        cost = breeder_cost(syn, level)
        if pay(player.wallet, cost):
            player.breeder = level
            player.spent_permanent += cost["ember"]
            player.note_first(entry, minute)
            return "bought"
        return "short"
    if entry.startswith("equipmentStep"):
        wanted = int(entry[len("equipmentStep"):] or 0)
        if wanted and player.levels_owned() >= wanted:
            return "owned"
        target = _next_equipment(syn, player)
        if target is None:
            return "owned"
        piece, level = target
        step = player.levels_owned()
        if step >= syn["equipment"]["ladder"]["steps"]:
            return "owned"
        cost = equipment_step_cost(syn, step, level)
        if pay(player.wallet, cost):
            player.equipment[piece] = level
            player.spent_permanent += cost["ember"]
            player.price_sequence.append(("equipment", step + 1, cost["ember"]))
            player.note_first(f"{piece}{level}", minute)
            player.note_first(f"equipmentStep{step + 1}", minute)
            if all(v >= 1 for v in player.equipment.values()):
                player.note_first("allLevelI", minute)
            return "bought"
        return "short"
    # a tree node
    branch, tier = entry.split("_")
    tier = int(tier)
    if entry in player.skills:
        return "owned"
    if player.branch_tier(branch) != tier - 1:
        return "short"
    cost = tree_cost(syn, tier)
    if pay(player.wallet, cost):
        player.skills.add(entry)
        player.spent_permanent += cost["ember"]
        player.note_first(entry, minute)
        player.note_first(f"anyTier{tier}", minute)
        if all(player.branch_tier(b) >= tier for b in BRANCHES):
            player.note_first(f"allTier{tier}", minute)
        return "bought"
    return "short"


def _everything_candidates(syn, player):
    out = []
    for branch in BRANCHES:
        tier = player.branch_tier(branch) + 1
        if tier <= syn["tree"]["tiers"]:
            out.append((tree_cost(syn, tier)["ember"], f"{branch}_{tier}"))
    if _next_equipment(syn, player) and player.levels_owned() < syn["equipment"]["ladder"]["steps"]:
        out.append((syn["equipment"]["costs"][player.levels_owned()], "equipmentStep"))
    if player.pens_owned < syn["corral"]["maxSlots"]:
        out.append((pen_cost(syn, player.pens_owned + 1)["ember"], f"slot{player.pens_owned + 1}"))
    if player.nido < len(syn["incubator"]["nidoCalido"]["costs"]):
        out.append((nido_cost(syn, player.nido + 1)["ember"], f"nido{player.nido + 1}"))
    if player.breeder < syn["breeder"]["steps"]:
        out.append((breeder_cost(syn, player.breeder + 1)["ember"], f"breeder{player.breeder + 1}"))
    if not player.incubator2:
        out.append((syn["incubator"]["secondSlot"], "secondIncubator"))
    if not player.pack:
        out.append((player.pack_cost["ember"], "reinforcedPack"))
    if not player.farol:
        out.append((player.farol_cost["ember"], "farolTapado"))
    return sorted(out)


def _free_purchases(syn, player, minute):
    equipment_seen = 0
    for entry in syn["simulatorInputs"]["freePriority"]:
        if entry == "equipmentStep":          # the n-th occurrence means "own n equipment levels"
            equipment_seen += 1
            entry = f"equipmentStep{equipment_seen}"
        result = _try_buy(syn, player, entry, minute)
        if result == "short":
            return
    if not syn["simulatorInputs"].get("thenCheapestFirst", True):
        return
    for _ in range(8):
        bought = False
        for _, entry in _everything_candidates(syn, player):
            if _try_buy(syn, player, entry, minute) == "bought":
                bought = True
                break
        if not bought:
            return


def _paying_cards(syn, player, minute, offers_seen):
    """Show at most one card per hub visit, in the document's row order; the paying policy accepts it."""
    rows = {row["id"]: row for row in syn["offers"]}
    pref = syn["simulatorInputs"]["payingPolicy"]["piecePreference"]
    candidates = []
    # Bolsa grande: calm hub visit after two "Bolsa llena" notices in this session, step not owned.
    row = rows["bolsaGrande"]
    if not player.pack and player.full_bag_notices_session >= 2:
        candidates.append(("bolsaGrande", "pack", None, robux_of(row)))
    # Un corral más: the next calm hub visit after a refused placement; next pen cost at the threshold.
    row = rows["unCorralMas"]
    if player.refused_placement_pending and player.pens_owned < syn["corral"]["maxSlots"]:
        slot = player.pens_owned + 1
        if pen_cost(syn, slot)["ember"] >= row["minFreeStepCost"] and str(slot) in row["robuxApproxBySlot"]:
            candidates.append(("unCorralMas", f"slot{slot}", slot, robux_of(row, slot)))
    # Equipo del explorador: at the Taller when the current step costs the threshold and a sellable piece is unowned.
    row = rows["equipoExplorador"]
    step = player.levels_owned()
    if step < syn["equipment"]["ladder"]["steps"] and syn["equipment"]["costs"][step] >= row["minFreeStepCost"]:
        piece = next((p for p in pref if p in row["pieces"] and player.equipment[p] == 0), None)
        if piece is not None:
            candidates.append(("equipoExplorador", f"step{step + 1}", piece, robux_of(row)))
    # Segunda incubadora: needs two eggs at once, which this model never produces (reported as not triggered).
    for row_id, step_key, extra, robux in candidates:
        if not card_allowed(syn, player, minute, row_id, step_key):
            continue
        player.shown_this_session.add((row_id, step_key))
        player.cards_this_session += 1
        player.last_card_minute = minute
        offers_seen.append((minute, row_id, step_key))
        if not syn["simulatorInputs"]["payingPolicy"]["acceptsEveryEligibleCard"]:
            return
        value = free_price_of_grant(syn, row_id, player, extra if row_id == "unCorralMas" else None)
        if row_id == "bolsaGrande":
            player.pack = True
        elif row_id == "unCorralMas":
            player.pens_owned = extra
            player.price_sequence.append(("pen", extra, pen_cost(syn, extra)["ember"]))
            player.refused_placement_pending = False
            player.note_first(f"slot{extra}", minute)
        elif row_id == "equipoExplorador":
            player.equipment[extra] = 1
            player.price_sequence.append(("equipment", step + 1, syn["equipment"]["costs"][step]))
            player.note_first(f"{extra}1", minute)
            player.note_first(f"equipmentStep{step + 1}", minute)
            if all(v >= 1 for v in player.equipment.values()):
                player.note_first("allLevelI", minute)
        player.granted_value += value
        player.robux_spent += robux
        player.purchases.append({"minute": minute, "row": row_id, "step": step_key, "robux": robux, "freePrice": value,
                                 "sessionIndex": player.session_index, "minuteInSession": player.minute_in_session})
        return


def simulate(syn, p0_tuning, *, paying, persistence, sessions, seed, reset_every=SESSION_MINUTES):
    """Simulate `sessions` sessions of SESSION_MINUTES play minutes. Returns a dict of results."""
    rng = random.Random(seed)
    inputs = syn["simulatorInputs"]
    cycle = inputs["cycleMinutes"]
    first = inputs["firstCycleMinutes"]
    out_minutes = inputs["minutesOutPerCycle"]
    player = Player(syn, p0_tuning, paying)
    offers_seen = []
    snapshots = {}
    session_end_states = []
    minute = 0
    total_minutes = sessions * SESSION_MINUTES
    for session in range(1, sessions + 1):
        if not persistence and session > 1 and (minute % reset_every == 0):
            fresh = Player(syn, p0_tuning, paying)
            fresh.active_log, fresh.material_log = [], []
            player = fresh
        player.session_index = session if persistence else 1
        player.cumulative_minutes_before_session = minute if persistence else 0
        player.minute_in_session = 0
        player.cards_this_session = 0
        player.shown_this_session = set()
        player.full_bag_notices_session = 0
        # Pattern inside a session: first steal (2 out), then cycles (5 out + 1 hub) until the 20 minutes are used.
        local = 0
        stretch = first
        while local < SESSION_MINUTES:
            stretch = max(1, min(stretch, SESSION_MINUTES - local - 1))
            for _ in range(stretch):            # out
                minute += 1
                local += 1
                player.minute_in_session = local
                _corral_tick(syn, player, minute, rate_share(syn, active_window=True))
            # arrival at the hub: income, creature, notices
            player.cycles_out += 1
            esencia = inputs["firstCycleEsencia"] if stretch == first and local == first else _cycle_income(syn, player)
            player.wallet["ember"] += esencia
            player.earned_active += esencia
            player.active_log.append((minute, esencia))
            player.note_first("firstEsencia", minute)
            for role, units in inputs["materialsPerCycle"].items():
                player.wallet[role] += units
                player.material_log.append((minute, role, units))
            if player.cycles_out % 3 == 0:
                player.wallet["rare"] += inputs["rarePerThirdCycle"]
                player.material_log.append((minute, "rare", inputs["rarePerThirdCycle"]))
            if not player.pack and rng.random() < inputs["fullBagNoticeChancePerCycleWithoutPack"]:
                player.full_bag_notices_session += 1
                player.last_refusal_or_notice_minute = minute
            _arrive_creature(syn, player, minute, rng)
            player.note_first("firstProducingCreature", minute)
            if len(player.pens) >= player.pens_owned:
                player.note_first(f"corral{player.pens_owned}Pens", minute)
            # the hub minute
            minute += 1
            local += 1
            player.minute_in_session = local
            _corral_tick(syn, player, minute, rate_share(syn, active_window=False))
            _hub_collect_and_feed(syn, player, minute)
            if paying:
                _paying_cards(syn, player, minute, offers_seen)
            _free_purchases(syn, player, minute)
            player.record_progress(minute)
            if minute % SESSION_MINUTES == 0:
                total = player.earned_active + player.earned_corral
                snapshots[minute] = {"earned_active": player.earned_active, "earned_corral": player.earned_corral,
                                     "corral_share": player.earned_corral / total if total else 0.0,
                                     "progress": player.spent_permanent + player.granted_value,
                                     "robux": player.robux_spent, "pens": player.pens_owned,
                                     "nominal_corral_rate": sum(nominal_rates(syn, [(c.species, c.rarity) for c in player.pens])),
                                     "rolling_active": player.rolling_active(minute)}
            stretch = out_minutes
        session_end_states.append(_owned(player))
    return {"player": player, "offers_seen": offers_seen, "snapshots": snapshots, "firsts": dict(player.firsts),
            "purchases": list(player.purchases), "price_sequence": list(player.price_sequence),
            "session_end_states": session_end_states, "minutes": total_minutes}


def _owned(player):
    owned = set(player.skills)
    for piece, level in player.equipment.items():
        for n in range(1, level + 1):
            owned.add(f"{piece}{n}")
    for n in range(1, player.levels_owned() + 1):
        owned.add(f"equipmentStep{n}")
    for pen in range(player.syn["corral"]["freeSlots"] + 1, player.pens_owned + 1):
        owned.add(f"slot{pen}")
    if player.farol:
        owned.add("farolTapado")
    if player.pack:
        owned.add("reinforcedPack")
    if player.incubator2:
        owned.add("secondIncubator")
    for n in range(1, player.nido + 1):
        owned.add(f"nido{n}")
    for n in range(1, player.breeder + 1):
        owned.add(f"breeder{n}")
    if len(player.pens) >= player.syn["corral"]["freeSlots"]:
        owned.add("corral4Pens")
    return owned


# ---- Static shape checks (K12, K13, K14, S1, D1, copy) ---------------------
def check_shape(syn, p0_tuning):
    problems = []
    tree, eq, br = syn["tree"], syn["equipment"], syn["breeder"]
    # K12 ladders
    expected = ladder_costs(tree["esenciaLadder"]["base"], tree["esenciaLadder"]["ratio"], tree["esenciaLadder"]["round"], tree["tiers"])
    if expected != tree["esenciaByTier"]:
        problems.append(f"K12: tree ladder {tree['esenciaByTier']} is not {expected}")
    for a, b in zip(tree["esenciaByTier"], tree["esenciaByTier"][1:]):
        if b <= a:
            problems.append("K12: tree tiers not strictly increasing")
    expected = ladder_costs(eq["ladder"]["base"], eq["ladder"]["ratio"], eq["ladder"]["round"], eq["ladder"]["steps"])
    if expected != eq["costs"]:
        problems.append(f"K12: equipment ladder {eq['costs']} is not {expected}")
    band = syn["simulatorInputs"]["targets"]["K12_equipmentRatioBand"]
    for a, b in zip(eq["costs"], eq["costs"][1:]):
        if not band[0] - 0.05 <= b / a <= band[1] + 0.05:
            problems.append(f"K12: equipment step ratio {b / a:.2f} outside {band}")
    if syn["corral"]["slotLadder"] != syn["simulatorInputs"]["targets"]["K12_penLadder"]:
        problems.append("K12: pen ladder changed; re-derive the pen cards")
    expected = ladder_costs(br["base"], br["ratio"], br["round"], br["steps"])
    if expected != br["costs"] or br["sold"]:
        problems.append("K12: breeder ladder is not the 1.6 ladder or is sold")
    # tiers 1 and 2 are the existing eight P0 nodes with their costs
    for branch in BRANCHES:
        for tier in (1, 2):
            p0_cost = p0_cost_as_roles(syn, p0_tuning["skills"][f"{branch}_{tier}"]["cost"])
            if p0_cost != tree_cost(syn, tier):
                problems.append(f"K12: {branch}_{tier} cost {tree_cost(syn, tier)} differs from P0 {p0_cost}")
    if p0_tuning["currency"]["purchasable"] or syn["currency"]["purchasable"]:
        problems.append("K13: currency.purchasable is true")
    # K13 offer rows
    rules = syn["offerRules"]
    ceiling_low, ceiling_high = 0, 0
    for row in syn["offers"]:
        if row.get("random"):
            problems.append(f"K13: {row['id']} is random")
        if not row.get("freePath"):
            problems.append(f"K6: {row['id']} has no free path")
        if row.get("product") != syn["policy"]["products"]:
            problems.append(f"K13: {row['id']} is not a {syn['policy']['products']}")
        if not row.get("needsPersistence"):
            problems.append(f"K13: {row['id']} is not flagged needsPersistence")
        grant = row["grants"]
        if any(word.lower() in grant.lower() for word in POWER_GRANT_WORDS):
            problems.append(f"K13: {row['id']} grants {grant}")
        if row["id"] == "cintasYSombreros":
            continue
        if "robuxApproxBySlot" in row:
            total = sum(row["robuxApproxBySlot"].values())
            ceiling_low += total
            ceiling_high += total
        else:
            ceiling_low += row["robuxApprox"]
            ceiling_high += row["robuxApprox"]
    # the equipment row can sell one piece, or two when a level II was bought before the fourth level I
    eq_row = next(r for r in syn["offers"] if r["id"] == "equipoExplorador")
    ceiling_high += eq_row["robuxApprox"] * (min(2, len(eq_row["pieces"])) - 1)
    if [ceiling_low, ceiling_high] != rules["nonCosmeticTotalRobux"]:
        problems.append(f"K13: non-cosmetic total is {[ceiling_low, ceiling_high]}, printed {rules['nonCosmeticTotalRobux']}")
    if ceiling_high > rules["nonCosmeticCeilingRobux"]:
        problems.append("K13: non-cosmetic total above the ceiling")
    for piece in eq_row["pieces"]:
        if piece not in eq["soldPieces"]:
            problems.append(f"K13: {piece} sold but not in equipment.soldPieces")
    if eq["soldLevels"] != ["I"]:
        problems.append("K13: a level above I is sold")
    # no sold item carries an accessibility key; fear relief is free
    for piece in eq["soldPieces"]:
        for key in eq["pieces"][piece]["I"]:
            if key in ACCESSIBILITY_KEYS or "calm" in key.lower():
                problems.append(f"K13/K10: sold piece {piece} I carries {key}")
    for piece in PIECES:
        for level in ("I", "II", "III"):
            for key in eq["pieces"][piece][level]:
                if key in ACCESSIBILITY_KEYS:
                    problems.append(f"K13: {piece} {level} carries accessibility key {key}; Modo tranquilo is free")
    acc = syn["accessibility"]["modoTranquilo"]
    if not acc.get("free") or acc.get("sold"):
        problems.append("K13: Modo tranquilo is not a free setting")
    if "firstOfferMinute" in rules:
        problems.append("K13: firstOfferMinute is the old rule; use minSessionIndex and minCumulativeMinutes")
    if rules["minSessionIndex"] < 2 or rules["minCumulativeMinutes"] < 30:
        problems.append("K13: a Robux card or row may appear in the first session")
    if rules["dailyGiftSurface"] in ("puesto", "shop") or syn["dailyGift"]["surface"] in ("puesto", "shop"):
        problems.append("K13: the daily gift is claimed at the offer surface")
    if not rules["puestoShowsRobuxRowOnlyWhenEligible"]:
        problems.append("K13: the Puesto shows Robux rows before eligibility")
    if rules["purchaseCopy"] != "descriptive":
        problems.append("K13: purchase copy is not descriptive")
    for key, token in lint_copy(syn):
        problems.append(f"K13: strings.{key} contains forbidden copy token {token!r}")
    if rules["estimate"]["source"] != "designMedianBalanced" or not rules["estimate"]["ownFigureOnlyIfLower"]:
        problems.append("K13: the free-path estimate is not the design median with own-figure-only-if-lower")
    if not rules["estimate"]["includesMaterials"]:
        problems.append("K13: the free line omits materials")
    # K14 totems
    for name, totem in syn["totems"].items():
        if totem.get("sold"):
            problems.append(f"K14: totem {name} is sold")
    suerte = syn["totems"]["suerte"]
    if suerte["cost"].get("ember", 0) != 0 or not suerte.get("materialsOnly"):
        problems.append("K14: Tótem de la suerte costs Esencia; a Robux-bought pen is an Esencia generator")
    discount = tree["nodes"]["occultist_3"]["effects"]
    if discount["totemRareFloor"] < 1:
        problems.append("K14: Tallador's rare floor is below 1")
    for name, totem in syn["totems"].items():
        rare = totem["cost"].get("rare", 0)
        if rare and max(discount["totemRareFloor"], rare - discount["totemRareDiscount"]) < 1:
            problems.append(f"K14: Tallador takes {name} rare cost below 1")
    # S1 cosmetics, D1 daily gift
    cos = syn["cosmetics"]
    if len(cos["esenciaByTier"]) != len(cos["robuxByTier"]) or cos["milestoneRibbonsSold"]:
        problems.append("S1: cosmetics without an Esencia price or ribbons sold")
    gift_total = sum(g.get("ember", 0) for g in syn["dailyGift"]["byClaim"])
    if gift_total != syn["dailyGift"]["esenciaPerCycle"] or syn["dailyGift"]["consecutiveDays"] or syn["dailyGift"]["repairSold"]:
        problems.append("D1: daily gift table does not match or uses streaks")
    # corral honesty and the breeder reframing
    corral = syn["corral"]
    if corral.get("pooledCapPerSlot") is not None or not corral["plaqueShowsCreditedRate"]:
        problems.append("C1: a pooled per-pen cap with nominal plaques prints a rate that is not paid")
    best = nominal_rates(syn, [("c0", "Comun"), ("c1", "Comun"), ("c2", "Comun"), ("c3", "Comun"), ("r0", "Rara"), ("r1", "Rara"), ("e0", "Epica"), ("l0", "Legendaria")])
    if sum(best) > syn["simulatorInputs"]["targets"]["C1_corralNominalMaxPerMinute"] + 1e-9:
        problems.append(f"C1: best realistic 8-pen mix pays {sum(best):.2f} nominal, over the target")
    if br["corralBonusPerLevel"] != 0 or br["playerText"] != "prestige":
        problems.append("E4: the breeder ladder still sells itself as a corral upgrade")
    if not corral["feed"]["requiresExpeditionSinceLastFeed"]:
        problems.append("K8: idle re-feeding is allowed")
    if syn["policy"]["policyService"]["onFailure"] != "restrictedForSession":
        problems.append("P7: a failed PolicyService read does not fail closed")
    return problems


# ---- Analysis ---------------------------------------------------------------
def _p(values, q):
    if not values:
        return None
    values = sorted(values)
    index = min(len(values) - 1, int(math.ceil(q * len(values))) - 1)
    return values[max(0, index)]


def _minutes_to_progress(progress_log, target):
    for minute, value in progress_log:
        if value >= target - 1e-9:
            return minute
    return None


def analyse(syn, p0_tuning, runs, sessions, seed, persistence=True, reset_every=SESSION_MINUTES):
    free_runs = [simulate(syn, p0_tuning, paying=False, persistence=persistence, sessions=sessions, seed=seed + i, reset_every=reset_every)
                 for i in range(runs)]
    pay_runs = [simulate(syn, p0_tuning, paying=True, persistence=persistence, sessions=sessions, seed=seed + i, reset_every=reset_every)
                for i in range(runs)]
    targets = syn["simulatorInputs"]["targets"]
    out = {"runs": runs, "sessions": sessions, "persistence": persistence, "firsts_p50": {}, "firsts_p90": {}}
    keys = set()
    for run in free_runs:
        keys |= set(run["firsts"])
    for key in sorted(keys):
        values = [run["firsts"][key] for run in free_runs if key in run["firsts"]]
        reached = len(values) / float(runs)
        out["firsts_p50"][key] = _p(values, 0.5) if reached >= 0.5 else None
        out["firsts_p90"][key] = _p(values, 0.9) if reached >= 0.9 else None
    # snapshots (medians)
    out["free_snapshots"], out["pay_snapshots"] = {}, {}
    for label, runs_ in (("free_snapshots", free_runs), ("pay_snapshots", pay_runs)):
        minutes = sorted(set().union(*[set(r["snapshots"]) for r in runs_]))
        for minute in minutes:
            rows = [r["snapshots"][minute] for r in runs_ if minute in r["snapshots"]]
            out[label][minute] = {k: _median([row[k] for row in rows]) for k in rows[0]}
    # K3: minutes the free player needs to reach the payer's 2-hour progress (same seed)
    saved = []
    for free, payer in zip(free_runs, pay_runs):
        if 120 not in payer["snapshots"]:
            continue
        target = payer["snapshots"][120]["progress"]
        reached = _minutes_to_progress(free["player"].progress_log, target)
        saved.append((reached - 120) if reached is not None else None)
    out["K3_minutes_saved_p50"] = _median([s for s in saved if s is not None]) if any(s is not None for s in saved) else None
    out["K3_unreached_share"] = sum(1 for s in saved if s is None) / float(len(saved)) if saved else None
    # K4, K4b
    ratios, ratios_b = [], []
    for free, payer in zip(free_runs, pay_runs):
        if 120 in free["snapshots"] and 120 in payer["snapshots"]:
            fe = free["snapshots"][120]["earned_active"] + free["snapshots"][120]["earned_corral"]
            pe = payer["snapshots"][120]["earned_active"] + payer["snapshots"][120]["earned_corral"]
            ratios.append(pe / fe if fe else None)
            ratios_b.append((pe + payer["player"].granted_value_at(120)) / fe if fe else None)
    out["K4_ratio_p50"] = _median([r for r in ratios if r is not None])
    out["K4b_ratio_p50"] = _median([r for r in ratios_b if r is not None])
    # K5: price sequences for the same step are identical across free and paying
    out["K5_identical"] = all(_prices_by_step(f["price_sequence"]) == _prices_by_step(p["price_sequence"], subset=_prices_by_step(f["price_sequence"]))
                              for f, p in zip(free_runs, pay_runs))
    # cards: cadence, session rule, repetition
    out["cards"] = _card_stats(syn, pay_runs)
    out["robux_p50"] = _median([r["player"].robux_spent for r in pay_runs])
    # P1: per-row design median estimate (minutes to earn the free step at the free player's income when the card appears)
    out["P1_rows"] = _price_anchor(syn, free_runs, pay_runs)
    if out["K3_minutes_saved_p50"]:
        out["P1_aggregate_robux_per_hour"] = out["robux_p50"] / (out["K3_minutes_saved_p50"] / 60.0)
    else:
        out["P1_aggregate_robux_per_hour"] = None
    out["session_end_owned_p50"] = _owned_by_majority(free_runs)
    return out


def _prices_by_step(sequence, subset=None):
    table = {}
    for kind, step, price in sequence:
        table[(kind, step)] = price
    if subset is not None:
        return {k: v for k, v in table.items() if k in subset}
    return table


def _card_stats(syn, pay_runs):
    rules = syn["offerRules"]
    stats = {"min_gap": None, "max_per_session": 0, "first_session_cards": 0, "repeats": 0, "earliest_minute": None,
             "before_cumulative": 0, "rows_triggered": set(), "per_row_first_minute_p50": {}}
    gaps = []
    firsts = {}
    for run in pay_runs:
        seen = run["offers_seen"]
        by_session = {}
        for minute, row_id, step_key in seen:
            firsts.setdefault(row_id, []).append(minute)
            stats["rows_triggered"].add(row_id)
            if minute < rules["minCumulativeMinutes"]:
                stats["before_cumulative"] += 1
            stats["earliest_minute"] = minute if stats["earliest_minute"] is None else min(stats["earliest_minute"], minute)
        for purchase in run["purchases"]:
            by_session.setdefault(purchase["sessionIndex"], []).append(purchase)
            if purchase["sessionIndex"] < rules["minSessionIndex"]:
                stats["first_session_cards"] += 1
        for session, purchases in by_session.items():
            stats["max_per_session"] = max(stats["max_per_session"], len(purchases))
            keys = [(p["row"], p["step"]) for p in purchases]
            stats["repeats"] += len(keys) - len(set(keys))
        minutes = sorted(p["minute"] for p in run["purchases"])
        gaps.extend(b - a for a, b in zip(minutes, minutes[1:]))
    stats["min_gap"] = min(gaps) if gaps else None
    stats["rows_triggered"] = sorted(stats["rows_triggered"])
    stats["rows_not_triggered"] = sorted(set(r["id"] for r in syn["offers"] if r.get("card", True)) - set(stats["rows_triggered"]))
    stats["per_row_first_minute_p50"] = {row: _median(values) for row, values in firsts.items()}
    return stats


def _price_anchor(syn, free_runs, pay_runs):
    """For each row: the design median minutes to earn the free step (Esencia and materials) at the free player's
    income when the card first appears, the Robux price and the implied Robux per hour of that time."""
    rows = {}
    for payer, free in zip(pay_runs, free_runs):
        for purchase in payer["purchases"]:
            minute = purchase["minute"]
            fp = free["player"]
            esencia_rate = fp.rolling_active(minute)
            materials = fp.rolling_materials(minute)
            cost = _free_cost_of(syn, purchase, free["player"])
            minutes = own_minutes_for(cost, esencia_rate, materials, syn)
            rows.setdefault((purchase["row"], purchase["step"]), []).append((minutes, purchase["robux"], cost))
    out = {}
    for (row_id, step), values in sorted(rows.items()):
        minutes = _median([v[0] for v in values if math.isfinite(v[0])])
        robux = values[0][1]
        out[f"{row_id}:{step}"] = {"minutes_p50": minutes, "robux": robux, "cost": values[0][2],
                                   "robux_per_hour": (robux / (minutes / 60.0)) if minutes else None}
    return out


def _free_cost_of(syn, purchase, free_player):
    if purchase["row"] == "bolsaGrande":
        return free_player.pack_cost
    if purchase["row"] == "unCorralMas":
        return pen_cost(syn, int(purchase["step"][4:]))
    if purchase["row"] == "equipoExplorador":
        step = int(purchase["step"][4:]) - 1
        return equipment_step_cost(syn, step, 1)
    return {"ember": syn["incubator"]["secondSlot"]}


def _owned_by_majority(runs):
    """Items owned at the end of a session by at least half the runs, per session index (session-only reachability)."""
    sessions = len(runs[0]["session_end_states"])
    out = []
    for index in range(sessions):
        counts = {}
        for run in runs:
            for item in run["session_end_states"][index]:
                counts[item] = counts.get(item, 0) + 1
        out.append(sorted(item for item, n in counts.items() if n * 2 >= len(runs)))
    return out


def Player_granted_value_at(self, minute):
    return sum(p["freePrice"] for p in self.purchases if p["minute"] <= minute)


Player.granted_value_at = Player_granted_value_at


# ---- Target checks ----------------------------------------------------------
def check_targets(syn, result, one_session=None, one_sitting=None):
    """Compare a persistence-on analysis (and optionally the session-only ones) against `simulatorInputs.targets`."""
    t = syn["simulatorInputs"]["targets"]
    problems = []
    p50 = result["firsts_p50"]

    def hours(key):
        return None if p50.get(key) is None else p50[key] / 60.0

    if p50.get("anyTier2") is None or math.ceil(p50["anyTier2"] / SESSION_MINUTES) > t["K1_tier2_sessions_p50"]:
        problems.append(f"K1: first tier-2 node p50 at minute {p50.get('anyTier2')}, over {t['K1_tier2_sessions_p50']} sessions")
    if hours("anyTier3") is None or hours("anyTier3") > t["K2_tier3_hours_p50"]:
        problems.append(f"K2: first tier-3 node p50 at {hours('anyTier3')} h, over {t['K2_tier3_hours_p50']}")
    if hours("allLevelI") is None or hours("allLevelI") > t["K2_allLevelI_hours"]:
        problems.append(f"K2: all level-I pieces p50 at {hours('allLevelI')} h, over {t['K2_allLevelI_hours']}")
    saved = result["K3_minutes_saved_p50"]
    if saved is None or not t["K3_minutesSaved"][0] <= saved <= t["K3_minutesSaved"][1]:
        problems.append(f"K3: paying saves {saved} minutes, outside {t['K3_minutesSaved']}")
    if result["K4_ratio_p50"] is None or result["K4_ratio_p50"] > t["K4_payingIncomeRatioAt2h"]:
        problems.append(f"K4: paying income ratio {result['K4_ratio_p50']}, over {t['K4_payingIncomeRatioAt2h']}")
    if result["K4b_ratio_p50"] is None or result["K4b_ratio_p50"] > t["K4b_payingAdvantageRatioAt2h"]:
        problems.append(f"K4b: paying advantage ratio {result['K4b_ratio_p50']}, over {t['K4b_payingAdvantageRatioAt2h']}")
    if not result["K5_identical"]:
        problems.append("K5: a paying run met a different price for the same step")
    core = ["allTier3", "allLevelI", f"slot{t['K6_corePens']}", "secondIncubator"]
    for key in core:
        if hours(key) is None or hours(key) > t["K6_coreOwnedHours"]:
            problems.append(f"K6: {key} p50 at {hours(key)} h, over {t['K6_coreOwnedHours']}")
    for minute, share_key in ((120, "C2_freeCorralShare"),):
        snap = result["free_snapshots"].get(minute)
        if snap is None or snap["corral_share"] > t[share_key]:
            problems.append(f"C2: free corral share at {minute} min is {snap and snap['corral_share']:.2f}, over {t[share_key]}")
    for h in t["C2_hours"]:
        snap = result["free_snapshots"].get(h * 60)
        if snap is not None and snap["corral_share"] > t["C2_freeCorralShare"]:
            problems.append(f"C2: free corral share at {h} h is {snap['corral_share']:.2f}, over {t['C2_freeCorralShare']}")
        snap = result["pay_snapshots"].get(h * 60)
        if snap is not None and snap["corral_share"] > t["C2_payingCorralShare"]:
            problems.append(f"C2: paying corral share at {h} h is {snap['corral_share']:.2f}, over {t['C2_payingCorralShare']}")
    cards = result["cards"]
    if cards["first_session_cards"] or cards["before_cumulative"]:
        problems.append("K13: a card was bought in the first session or before the cumulative minimum")
    if cards["min_gap"] is not None and cards["min_gap"] < t["K13_minMinutesBetweenPurchases"]:
        problems.append(f"K13: purchases {cards['min_gap']} minutes apart")
    if cards["max_per_session"] > t["K13_maxPurchasesPer20Minutes"]:
        problems.append(f"K13: {cards['max_per_session']} purchases in one session")
    if cards["repeats"]:
        problems.append("K13: the same row and step was offered twice in one session")
    if result["robux_p50"] is not None and result["robux_p50"] > t["K13_nonCosmeticCeilingRobux"]:
        problems.append("K13: the paying policy spent over the ceiling")
    for key, row in result["P1_rows"].items():
        rate = row["robux_per_hour"]
        if rate is None or not t["P1_anchorBand"][0] <= rate <= t["P1_anchorBand"][1]:
            problems.append(f"P1: {key} implies {rate and round(rate)} Robux per hour of Esencia time, outside {t['P1_anchorBand']}")
    agg = result["P1_aggregate_robux_per_hour"]
    if agg is None or not t["P1_aggregateBand"][0] <= agg <= t["P1_aggregateBand"][1]:
        problems.append(f"P1: the basket implies {agg and round(agg)} Robux per hour of progress saved, outside {t['P1_aggregateBand']}")
    if (p50.get("firstEsencia") is None or p50["firstEsencia"] > t["K15_firstEsenciaMinutes"]
            or p50.get("firstProducingCreature") is None or p50["firstProducingCreature"] > t["K15_firstCreatureMinutes"]):
        problems.append("K15: first Esencia or first producing creature later than the first-minute rule")
    # D1: seven gifts under one session's median income
    session_income = None
    snap = result["free_snapshots"].get(SESSION_MINUTES)
    if snap:
        session_income = snap["earned_active"] + snap["earned_corral"]
    if session_income is None or syn["dailyGift"]["esenciaPerCycle"] >= session_income:
        problems.append(f"D1: seven gifts ({syn['dailyGift']['esenciaPerCycle']}) not under one session's income ({session_income})")
    if one_session is not None and one_sitting is not None:
        problems.extend(check_reachability(syn, one_session, one_sitting))
    return problems


def check_reachability(syn, one_session, one_sitting):
    """R1: the declared session-only partition against persistence-off runs (one 20-minute session; one 60-minute sitting)."""
    decl = syn["simulatorInputs"]["sessionOnly"]
    problems = []
    reached_session = set(one_session["session_end_owned_p50"][0]) if one_session["session_end_owned_p50"] else set()
    reached_sitting = set(one_sitting["session_end_owned_p50"][-1]) if one_sitting["session_end_owned_p50"] else set()
    for item in decl["reachedInOneSession"]:
        if item not in reached_session:
            problems.append(f"R1: {item} is declared session-reachable but a p50 20-minute session does not reach it")
    for item in decl["reachedInOneSitting"]:
        if item not in reached_sitting:
            problems.append(f"R1: {item} is declared sitting-reachable but a p50 60-minute sitting does not reach it")
    for item in decl["needsPersistence"]:
        if item in reached_sitting:
            problems.append(f"R1: {item} is flagged needsPersistence but a 60-minute sitting reaches it")
    return problems


def corral_contract_checks(syn):
    """C1, C3, K8, K8b and the plaque rule as pure-function checks."""
    problems = []
    best = [("c0", "Comun"), ("c1", "Comun"), ("c2", "Comun"), ("c3", "Comun"), ("r0", "Rara"), ("r1", "Rara"), ("e0", "Epica"), ("l0", "Legendaria")]
    nominal = sum(nominal_rates(syn, best))
    active = 5.5
    credited = sum(credited_rates(syn, best, active, 1.0))
    if credited > corral_cap(syn, len(best), active) + 1e-9:
        problems.append("C1: credited corral exceeds the active-income cap")
    if nominal > syn["simulatorInputs"]["targets"]["C1_corralNominalMaxPerMinute"] + 1e-9:
        problems.append("C1: nominal best mix over the ceiling")
    full = sum(credited_rates(syn, best, 100.0, rate_share(syn, active_window=True)))
    hub = sum(credited_rates(syn, best, 100.0, rate_share(syn, active_window=False)))
    if abs(hub - full * syn["corral"]["rateShare"]["otherwiseAlive"]) > 1e-9:
        problems.append("C3: the hub rate is not the quarter of the active rate")
    if sum(credited_rates(syn, best, 100.0, rate_share(syn, alive=False))) != 0:
        problems.append("C3: a dead owner's corral accrues")
    bound = idle_hour_credit(syn, best, 100.0, fed=True, refeeds=2)
    once = sum(credited_rates(syn, best, 100.0, rate_share(syn, active_window=False))) * syn["corral"]["feed"]["windowMinutes"]
    if bound > once + 1e-9 or idle_hour_credit(syn, best, 100.0, fed=False) != 0:
        problems.append("K8: an idle hour credits more than a quarter rate for one window, or an unfed corral accrues")
    legendarias = [("l0", "Legendaria")] * 8          # eight of the same species and rarity
    if sum(nominal_rates(syn, legendarias)) > nominal + 1e-9:
        problems.append("C2: eight identical Legendaria pay more than eight varied creatures")
    return problems


# ---- Report -----------------------------------------------------------------
HEADER = """\
WILDBOUND HUB ECONOMY SIMULATOR - math only
This models math only. It says nothing about fun or balance, and the policies are the document's
invented archetypes, not players. Numbers come from the economy-synthesis block of
{doc} at run time; the assumptions below are the simulator's, not game data."""

ASSUMPTIONS = (
    "sessions of 20 play minutes: 2-minute first steal, then 6-minute cycles of 5 out and 1 at the hub (the last one shortened); "
    "active income, materials and the rarity script from simulatorInputs; one creature home per cycle; "
    "corral per minute at the full rate while out and a quarter at the hub, capped by a share of the owner's rolling active income "
    "plus a fixed amount per filled pen past the free ones; "
    "plaques show the credited rate; feeding at every hub visit with one material after an expedition; "
    "free player buys in the fixed priority then cheapest first; paying player accepts every card the rules allow; "
    "no defeats, beasts, totems, time of day or cosmetics; the Bolsa llena notice is an invented chance; "
    "the second-incubator card is never triggered by this model."
)


def _fmt(value, spec="6.1f"):
    return "     -" if value is None else format(value, spec)


def render(syn, shape_problems, result_on, result_off, sitting, target_problems, args):
    lines = [HEADER.format(doc=DOC.relative_to(REPO).as_posix()), "", "Assumptions: " + ASSUMPTIONS, "",
             f"Runs {args.runs}, sessions {args.sessions}, seed {args.seed}", ""]
    lines.append("Shape checks (K12, K13, K14, S1, D1, C1, copy lint): " + ("ok" if not shape_problems else ""))
    lines.extend("  PROBLEM " + p for p in shape_problems)
    lines.append("")
    p50, p90 = result_on["firsts_p50"], result_on["firsts_p90"]
    lines.append("Free balanced player, persistence on (minute of first ownership, p50 / p90):")
    for key in ("farolTapado", "explorer_1", "capturer_1", "anyTier2", "allLevelI", "anyTier3", "allTier3", "slot5", "slot6", "slot7", "slot8",
                "secondIncubator", "reinforcedPack", "anyTier4", "allTier4", "anyTier5", "allTier5", "equipmentStep12", "breeder10", "nido3"):
        lines.append(f"  {key:16s} {_fmt(p50.get(key), '7.0f')} / {_fmt(p90.get(key), '7.0f')}")
    lines.append("")
    lines.append("Snapshots (medians): minute, earned active, earned corral, corral share, progress, pens, nominal corral rate, rolling active")
    for label, snaps in (("free", result_on["free_snapshots"]), ("paying", result_on["pay_snapshots"])):
        for minute in sorted(snaps):
            if minute in (20, 60, 120, 240, 480, 960) or minute % 480 == 0:
                s = snaps[minute]
                lines.append(f"  {label:6s} {minute:5d} {s['earned_active']:8.0f} {s['earned_corral']:8.0f} {s['corral_share']:6.2f} "
                             f"{s['progress']:8.0f} {s['pens']:3.0f} {s['nominal_corral_rate']:5.2f} {s['rolling_active']:5.2f}")
    lines.append("")
    lines.append(f"K3 minutes saved by the paying basket (p50): {_fmt(result_on['K3_minutes_saved_p50'], '.0f')}  "
                 f"(unreached share {_fmt(result_on['K3_unreached_share'], '.2f')})")
    lines.append(f"K4 paying earned / free earned at 2 h (p50): {_fmt(result_on['K4_ratio_p50'], '.2f')};  "
                 f"K4b with free-price value of grants: {_fmt(result_on['K4b_ratio_p50'], '.2f')}")
    lines.append(f"K5 identical prices per step: {result_on['K5_identical']}")
    cards = result_on["cards"]
    lines.append(f"Cards: earliest minute {cards['earliest_minute']}, min gap {cards['min_gap']}, max per session {cards['max_per_session']}, "
                 f"repeats {cards['repeats']}, first-session cards {cards['first_session_cards']}; rows triggered {cards['rows_triggered']}; "
                 f"not triggered {cards['rows_not_triggered']}; Robux p50 {_fmt(result_on['robux_p50'], '.0f')}")
    lines.append("P1 per row (design median minutes to earn the step at the income when the card appears; implied Robux per hour):")
    for key, row in result_on["P1_rows"].items():
        lines.append(f"  {key:28s} {_fmt(row['minutes_p50'], '6.0f')} min  {row['robux']:4d} Robux  {_fmt(row['robux_per_hour'], '6.0f')} R/h  cost {row['cost']}")
    lines.append(f"P1 aggregate (basket Robux per hour of progress saved): {_fmt(result_on['P1_aggregate_robux_per_hour'], '.0f')}")
    lines.append("")
    lines.append("Persistence off (what the game can do today): items owned by at least half the runs")
    if result_off is not None:
        lines.append("  at the end of one 20-minute session: " + ", ".join(result_off["session_end_owned_p50"][0]))
    if sitting is not None:
        lines.append("  at the end of one 60-minute sitting:  " + ", ".join(sitting["session_end_owned_p50"][-1]))
    lines.append("")
    lines.append("Target checks: " + ("ok" if not target_problems else ""))
    lines.extend("  PROBLEM " + p for p in target_problems)
    return "\n".join(lines) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description="Wildbound hub economy simulator (math only).")
    parser.add_argument("--runs", type=int, default=30, help="seeded runs per policy (default 30)")
    parser.add_argument("--sessions", type=int, default=24, help="20-minute sessions per run (default 24 = 8 hours)")
    parser.add_argument("--seed", type=int, default=2026, help="base seed (default 2026)")
    parser.add_argument("--persistence", choices=("on", "off", "both"), default="both", help="profile kept across sessions")
    parser.add_argument("--doc", default=str(DOC), help="design document with the economy-synthesis block")
    parser.add_argument("--p0-doc", default=str(P0_DOC), help="P0 economy document with the economy-tuning block")
    parser.add_argument("--json", default=None, help="write the machine-readable result here")
    args = parser.parse_args(argv)
    if args.runs < 1 or args.sessions < 1:
        parser.error("--runs and --sessions must be at least 1")
    try:
        syn = load_synthesis(args.doc)
        p0_tuning = p0.load_tuning(args.p0_doc)
    except (OSError, TuningError) as error:
        print(f"ERROR: {type(error).__name__}: {error}", file=sys.stderr)
        return 2
    shape_problems = check_shape(syn, p0_tuning) + corral_contract_checks(syn)
    result_on = result_off = sitting = None
    target_problems = []
    if args.persistence in ("on", "both"):
        result_on = analyse(syn, p0_tuning, args.runs, args.sessions, args.seed, persistence=True)
    if args.persistence in ("off", "both"):
        result_off = analyse(syn, p0_tuning, args.runs, 1, args.seed, persistence=False)
        sitting_sessions = syn["simulatorInputs"]["sessionOnly"]["oneSittingMinutes"] // SESSION_MINUTES
        sitting = analyse(syn, p0_tuning, args.runs, sitting_sessions, args.seed, persistence=False,
                          reset_every=sitting_sessions * SESSION_MINUTES)
    if result_on is not None:
        target_problems = check_targets(syn, result_on, result_off, sitting)
    elif result_off is not None:
        target_problems = check_reachability(syn, result_off, sitting)
    problems = shape_problems + target_problems
    if result_on is None:
        result_on = {"firsts_p50": {}, "firsts_p90": {}, "free_snapshots": {}, "pay_snapshots": {}, "K3_minutes_saved_p50": None,
                     "K3_unreached_share": None, "K4_ratio_p50": None, "K4b_ratio_p50": None, "K5_identical": True,
                     "cards": {"earliest_minute": None, "min_gap": None, "max_per_session": 0, "repeats": 0, "first_session_cards": 0,
                               "rows_triggered": [], "rows_not_triggered": []}, "robux_p50": None, "P1_rows": {},
                     "P1_aggregate_robux_per_hour": None}
    sys.stdout.write(render(syn, shape_problems, result_on, result_off, sitting, target_problems, args))
    if args.json:
        payload = {"shape_problems": shape_problems, "target_problems": target_problems,
                   "on": _jsonable(result_on), "off": _jsonable(result_off), "sitting": _jsonable(sitting)}
        Path(args.json).write_text(json.dumps(payload, indent=2, default=str), encoding="utf-8")
    return 1 if problems else 0


def _jsonable(result):
    if result is None:
        return None
    out = {}
    for key, value in result.items():
        if isinstance(value, dict):
            out[key] = {str(k): v for k, v in value.items()}
        else:
            out[key] = value
    return out


if __name__ == "__main__":
    sys.exit(main())

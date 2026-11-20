"""RW-7 (owner request 2026-11-20): nothing in the game asks Roblox to charge anyone.

The spin packs and the other offers in src/wildbound/WildboundOffers.luau show placeholder prices only; while
WildboundFlags.DESBLOQUEAR_TODO is true their green button grants for free on the server, and when it is false the
server answers "Próximamente". Monetization stays "none" (WildboundEconomyConfig). This check reads every game script
under src/ and every Luau tool under tools/ and fails on any purchase call or receipt handler, comments included, so
a purchase path can only arrive together with a deliberate change to this test (and its own approval).
Run: python -I -B -m unittest discover -s tools -p "test_no_purchase_calls.py"
"""

import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
BANNED = (
    "MarketplaceService",
    "PromptProductPurchase",
    "PromptGamePassPurchase",
    "PromptPurchase",
    "PromptBundlePurchase",
    "PromptPremiumPurchase",
    "PromptSubscriptionPurchase",
    "ProcessReceipt",
    "UserOwnsGamePassAsync",
)


def purchase_hits(paths):
    hits = []
    for path in paths:
        text = path.read_text(encoding="utf-8", errors="replace")
        for number, line in enumerate(text.splitlines(), start=1):
            for word in BANNED:
                if word in line:
                    hits.append(f"{path.relative_to(REPO).as_posix()}:{number}: {word}")
    return hits


def game_scripts():
    found = sorted((REPO / "src").rglob("*.lua")) + sorted((REPO / "src").rglob("*.luau"))
    found += sorted((REPO / "tools").rglob("*.luau"))
    return found


class NoPurchaseCalls(unittest.TestCase):
    def test_scripts_exist(self):
        names = {path.name for path in game_scripts()}
        for name in ("WildboundOffers.luau", "WildboundRouletteService.luau", "WildboundRoulette.client.luau",
                     "WildboundRouletteWheel.luau", "WildboundFlags.luau"):
            self.assertIn(name, names)

    def test_no_game_script_names_a_purchase_call(self):
        self.assertEqual(purchase_hits(game_scripts()), [])

    def test_the_switch_is_on_and_monetization_is_none(self):
        flags = (REPO / "src" / "wildbound" / "WildboundFlags.luau").read_text(encoding="utf-8")
        self.assertIn("\tDESBLOQUEAR_TODO = true,", flags)
        config = (REPO / "src" / "wildbound" / "WildboundEconomyConfig.luau").read_text(encoding="utf-8")
        self.assertIn('monetization = "none"', config)

    def test_detector_catches_a_call(self):
        sample = REPO / "tools" / "__purchase_probe_never_written__.luau"
        # The detector works on text; check it on an in-memory line instead of writing a file.
        line = 'game:GetService("MarketplaceService"):PromptProductPurchase(player, 1)'
        self.assertTrue(any(word in line for word in BANNED))
        self.assertFalse(sample.exists())


if __name__ == "__main__":
    unittest.main()

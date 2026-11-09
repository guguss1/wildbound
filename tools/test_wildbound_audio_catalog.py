"""Delivery D9: every audio id the game can play comes from the research shortlist and none is rejected there.

    python -I -B -m unittest discover -s tools -p test_wildbound_audio_catalog.py
"""

import re
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CATALOG = REPO / "src/wildbound/WildboundAudioCatalog.luau"
SHORTLIST = REPO / "docs/audio/wildbound-horror-audio-shortlist.md"
# Dread pass: the giant footstep, crack, groan and creak ids come from the second research shortlist.
DREAD_SHORTLIST = REPO / "docs/audio/wildbound-dread-assets-shortlist.md"
DREAD_IDS = {"9125404769", "9125404774", "9125404796", "9126239755", "9114628321", "9120262025"}
WILDBOUND = REPO / "src/wildbound"


def catalog_ids():
    text = CATALOG.read_text(encoding="utf-8")
    body = text.split("Catalog.SOUNDS", 1)[1].split("Catalog.SHARED", 1)[0]
    return set(re.findall(r"\b(\d{7,})\b", body))


class AudioCatalog(unittest.TestCase):
    def test_d9_every_catalog_id_is_on_the_shortlist_and_not_rejected(self):
        ids = catalog_ids()
        self.assertGreaterEqual(len(ids), 20)
        lines = SHORTLIST.read_text(encoding="utf-8").splitlines() + DREAD_SHORTLIST.read_text(encoding="utf-8").splitlines()
        for asset in sorted(ids):
            found = [line for line in lines if asset in line]
            self.assertTrue(found, f"{asset} is not on the shortlist")
            for line in found:
                self.assertNotIn("rejected", line.lower(), f"{asset} is rejected on the shortlist")

    def test_dread_pass_footstep_ids_are_in_the_catalog(self):
        missing = DREAD_IDS - catalog_ids()
        self.assertFalse(missing, f"dread pass ids missing from the catalog: {sorted(missing)}")

    def test_nb2_chase_sting_ids_are_in_the_catalog(self):
        missing = {"1846887425", "1842083006"} - catalog_ids()
        self.assertFalse(missing, f"chase sting ids missing from the catalog: {sorted(missing)}")

    def test_d9_no_other_script_names_an_audio_id(self):
        for path in WILDBOUND.glob("*.luau"):
            if path == CATALOG:
                continue
            text = path.read_text(encoding="utf-8")
            for asset in catalog_ids():
                self.assertNotIn(asset, text, f"{path.name} names {asset} outside the catalog")


if __name__ == "__main__":
    unittest.main()

"""Delivery D9: every audio id the game can play comes from the research shortlist and none is rejected there.

    python -I -B -m unittest discover -s tools -p test_wildbound_audio_catalog.py
"""

import re
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CATALOG = REPO / "src/wildbound/WildboundAudioCatalog.luau"
SHORTLIST = REPO / "docs/audio/wildbound-horror-audio-shortlist.md"
WILDBOUND = REPO / "src/wildbound"


def catalog_ids():
    text = CATALOG.read_text(encoding="utf-8")
    body = text.split("Catalog.SOUNDS", 1)[1].split("Catalog.SHARED", 1)[0]
    return set(re.findall(r"\b(\d{7,})\b", body))


class AudioCatalog(unittest.TestCase):
    def test_d9_every_catalog_id_is_on_the_shortlist_and_not_rejected(self):
        ids = catalog_ids()
        self.assertGreaterEqual(len(ids), 20)
        lines = SHORTLIST.read_text(encoding="utf-8").splitlines()
        for asset in sorted(ids):
            found = [line for line in lines if asset in line]
            self.assertTrue(found, f"{asset} is not on the shortlist")
            for line in found:
                self.assertNotIn("rejected", line.lower(), f"{asset} is rejected on the shortlist")

    def test_d9_no_other_script_names_an_audio_id(self):
        for path in WILDBOUND.glob("*.luau"):
            if path == CATALOG:
                continue
            text = path.read_text(encoding="utf-8")
            for asset in catalog_ids():
                self.assertNotIn(asset, text, f"{path.name} names {asset} outside the catalog")


if __name__ == "__main__":
    unittest.main()

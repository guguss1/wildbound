"""Reader for the ```json economy-tuning block of docs/mechanics/wildbound-economy-p0.md.

This is the single reader of that block. The exporter (export_economy_config_luau.py), the hub
simulator, the planners and wildbound_economy_sim_v2.py's doc path import it. It replaced the
reader half of tools/simulate_economy.py, which was retired on 2026-11-14 in favour of
tools/wildbound_economy_sim_v2.py.

Standard library only.
"""

import json
import re
import statistics
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DOC = REPO / "docs/mechanics/wildbound-economy-p0.md"
FENCE = re.compile(r"^```json economy-tuning[ \t]*\n(.*?)^```[ \t]*$", re.M | re.S)
SESSION_MINUTES = 20.0


class TuningError(Exception):
    """The economy tuning block is missing, malformed, or violates its schema."""


def extract_tuning(text):
    blocks = FENCE.findall(text)
    if len(blocks) != 1:
        raise TuningError(f"expected exactly one ```json economy-tuning block, found {len(blocks)}")
    try:
        tuning = json.loads(blocks[0])
    except json.JSONDecodeError as error:
        raise TuningError(f"economy-tuning block is not valid JSON: {error}") from error
    if tuning.get("schema") != "wildbound.economy.tuning":
        raise TuningError(f"unexpected schema {tuning.get('schema')!r}")
    if tuning.get("schemaVersion") != 1:
        raise TuningError(f"unsupported schemaVersion {tuning.get('schemaVersion')!r} (this tool reads 1)")
    if tuning.get("monetization") != "none":
        raise TuningError("monetization is not 'none'; this tool does not model paid items")
    return tuning


def load_tuning(path=DOC):
    try:
        text = Path(path).read_text(encoding="utf-8")
    except OSError as error:
        raise TuningError(f"cannot read {path}: {error}") from error
    return extract_tuning(text)


def _median(values):
    return statistics.median(values) if values else None

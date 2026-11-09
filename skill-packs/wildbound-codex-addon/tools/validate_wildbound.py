"""Validate Wildbound design examples and skill metadata; standard library only."""
from pathlib import Path
import json
import re

root = Path(__file__).resolve().parents[1]
file = root / "examples/encounter_tables.json"
data = json.loads(file.read_text(encoding="utf-8"))
assert data["tables"]
for table in data["tables"]:
    weights = table["weights"]
    assert len(weights) >= 2 and all(
        isinstance(v, (int, float)) and v >= 0 for v in weights.values()
    ), table["id"]
    assert abs(sum(weights.values()) - 100) < 1e-8, (table["id"], sum(weights.values()))
    assert "empty" in weights, table["id"]
skills = list((root / ".agents/skills").glob("*/SKILL.md"))
assert len(skills) == 10, len(skills)
for path in skills:
    txt = path.read_text(encoding="utf-8")
    assert txt.startswith("---\n") and re.search(
        r"^name:\s*" + re.escape(path.parent.name) + r"\s*$", txt, re.M
    ), str(path)
    assert re.search(r"^description:\s*\S+", txt, re.M), str(path)
print(f"OK: {len(skills)} skills, {len(data['tables'])} tables with weights summing to 100.")

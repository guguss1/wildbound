"""Check design JSON, 17 Codex SKILL.md files and cross-references. Python stdlib."""
from pathlib import Path
import json
import re

root = Path(__file__).resolve().parents[1]
spec = json.loads((root / 'examples/creature_catalog.json').read_text(encoding='utf-8'))['species']
abilities = json.loads((root / 'examples/companion_abilities.json').read_text(encoding='utf-8'))['abilities']
spawns = json.loads((root / 'examples/encounter_tables.json').read_text(encoding='utf-8'))['tables']

assert len(spec) == 10 and sum(s['mvp'] for s in spec) == 6
ids = {s['id'] for s in spec}
assert len(ids) == len(spec)
assert len({s['name'] for s in spec}) == len(spec)
ability_ids = {a['id'] for a in abilities}
assert len(abilities) == len(ability_ids) == 10
assert {s['ability_id'] for s in spec} <= ability_ids
for a in abilities:
    assert a['species_id'] in ids
    assert a['cooldown_s'] > 0 and a['duration_s'] > 0
for table in spawns:
    weights = table['weights']
    assert len(weights) > 1 and 'empty' in weights
    assert all(isinstance(v, (int, float)) and v >= 0 for v in weights.values())
    assert abs(sum(weights.values()) - 100) < 1e-9, table['id']
    assert set(weights) - {'empty'} <= ids
    for name, value in weights.items():
        if name != 'empty' and value > 0:
            species = next(s for s in spec if s['id'] == name)
            assert table['biome'] in species['biomes'], (table['id'], name)

skills = sorted((root / '.agents/skills').glob('wildbound-*/SKILL.md'))
assert len(skills) == 17, len(skills)
for path in skills:
    content = path.read_text(encoding='utf-8')
    assert content.startswith('---\n'), path
    assert re.search(r'^name:\s*' + re.escape(path.parent.name) + r'\s*$', content, re.M), path
    assert re.search(r'^description:\s*\S+', content, re.M), path
print(f'OK: {len(skills)} skills, {len(spec)} species, {len(abilities)} abilities, {len(spawns)} encounter tables.')

# Confirmar invariantes del sistema de pérdida/protección
risk = json.loads((root / 'examples/risk_protection_rules.json').read_text(encoding='utf-8'))
assert risk['confirmed']['lose_unprotected_eggs_on_failure']
assert risk['confirmed']['lose_unprotected_new_specimens_on_failure']
assert risk['confirmed']['registered_pets_permanent_on_defeat'] is True
assert risk['banked_pet_loss_mode'] == 'never_on_defeat'
assert 0 < risk['resource_loss']['default_fraction'] < 0.2
assert risk['resource_loss']['base_currency_loss_fraction'] == 0
items = risk['protections']
assert len({x['id'] for x in items}) == len(items)
assert {'ward_seal', 'expedition_charm', 'last_breath_totem', 'reinforced_bag', 'extraction_capsule'} == {x['id'] for x in items}
assert all(x['max_items'] >= 0 for x in items)
assert all(x['obtain'] in ('gameplay_or_crafting', 'skill_tree') for x in items)
print(f'OK risk: {len(items)} protection designs; {risk["resource_loss"]["default_fraction"]:.0%} default material loss; registered pet loss disabled.')

# Night phases, horror-zone limits and reward/risk weight handling
night = json.loads((root / 'examples/night_cycle_rules.json').read_text(encoding='utf-8'))
assert sum(x['minutes'] for x in night['phases']) == night['duration_minutes']
assert [p['id'] for p in night['phases']] == ['day','dusk','night','dawn']
assert night['horror_biomes']['fog']['mvp'] is True
assert all(not value for k,value in [(k,v['mvp']) for k,v in night['horror_biomes'].items() if k != 'fog'])
mods = night['night_modifiers_only_in_horror_biomes']
assert mods['rare_or_higher_creature_weight_multiplier'] > 1
assert mods['rare_resource_weight_multiplier'] > 1
assert mods['guardian_encounter_rate_multiplier'] > 1
assert {'fog_night','crypt_night'} <= {t['id'] for t in spawns}
assert (root/'knowledge/wildbound/NIGHT_CYCLE.md').exists()
assert (root/'.agents/skills/wildbound-day-night-cycle/SKILL.md').exists()
print('OK night: phases, horror-region gating, multipliers, night encounters, and registered-pet retention.')

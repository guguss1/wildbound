from pathlib import Path
from PIL import Image

root=Path(__file__).resolve().parents[1]
required=[
'PROMPT_MAESTRO.md','PROMPT_PROTOTIPO_BOSQUE_NIEBLA.md',
'knowledge/wildbound/PROTOTIPO_BOSQUE_NIEBLA_P0.md',
'knowledge/wildbound/P0_TASKS.md','references/README.md',
'references/boards/wildbound_concept_board_01.png',
'references/boards/fog_forest_prototype_board_02.png',
'references/biomes/fog_forest_day.png',
'references/biomes/fog_forest_night.png',
'references/creatures/lumipol_reference.png',
'references/guardians/la_silueta_reference.png',
'references/maps/fog_forest_layout_proposal.png',
]
for name in required:
    path=root/name
    assert path.is_file(), f'Falta: {name}'
    if path.suffix.lower()=='.png':
        with Image.open(path) as im: im.verify()
print(f'OK: {len(required)} archivos principales y PNGs comprobados.')

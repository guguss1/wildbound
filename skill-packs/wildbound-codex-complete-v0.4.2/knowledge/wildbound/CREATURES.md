# Taxonomía y colección — v0.2
## Ejes independientes
- Rareza: común / poco común / rara / épica / legendaria / mítica / anomalía.
- Familia: bestial / vegetal / fúngica / elemental / mineral / acuática / espectral / mecánica / ancestral / infernal.
- Afinidad: luz / naturaleza / tierra / sonido / niebla / viento / hielo / fuego / sombra / cristal / otras futuras.
- Rol funcional: explorador / protector / revelador / distractor / capturador / recolector.
- Variante visual: base / albina / nocturna / corrupta / luminiscente / ancestral (propuestas para fases posteriores).

**Rareza no es poder universal**: cada especie/rol abre una estrategia; las especies comunes siguen siendo relevantes en mapas avanzados.
**Guardián ≠ pet** en MVP. No convertir automáticamente un enemigo en criatura obtenible.

## Roster inicial propuesto
| ID | Especie | Rol | Afinidad | Obtención | MVP |
|---|---|---|---|---|---|
| CR001 | Lumipol | revelador | luz | wild, egg | Sí |
| CR002 | Musguín | protector | naturaleza | wild, egg | Sí |
| CR003 | Rocuelo | protector | tierra | egg, wild | Sí |
| CR004 | Ecozorro | distractor | sonido | wild | Sí |
| CR005 | Brumín | explorador | niebla | egg, wild | Sí |
| CR006 | Ojobúho | recolector | viento | egg, wild | Sí |
| CR007 | Nevín | explorador | hielo | egg, wild | No |
| CR008 | Ascua | explorador | fuego | egg | No |
| CR009 | Umbrelín | distractor | sombra | wild | No |
| CR010 | Cristalín | capturador | cristal | egg, wild | No |

Catálogo estructurado para Codex: `examples/creature_catalog.json`. Cada especie debe tener una interacción propia de captura y una razón de ser en el mapa.

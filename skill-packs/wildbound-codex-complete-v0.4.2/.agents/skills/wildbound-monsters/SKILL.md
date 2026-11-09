---
name: wildbound-monsters
description: Diseñar e implementar guardianes de terror con reglas de mirada/invisibilidad y contramedidas de pets en Wildbound.
---

# Procedimiento

1. Leer `MONSTERS.md`, `GUARDIAN_PET_MATRIX.md` y `COMPANION_SYSTEM.md`.
2. Cada guardián: señal de advertencia, máquina de estados, persecución acotada, counterplay sin pet, pets útiles, inmunidades y cooldown.
3. Vigía: si algún jugador vivo realmente lo observa y no hay oclusión, se detiene. Cliente manda indicios limitados, servidor valida; no confiar solo en cámaras reportadas.
4. Silueta: contorno tenue visible sin pet. Lumipol la revela 4 s (datos hipotéticos); Ecozorro puede distraerla en condiciones específicas. Ninguno la elimina.
5. Evitar daño desde NPC no cargado por streaming. Prever audio apagado, fotogramas bajos y cooperativo 2/4 sin apilar efectos infinitamente.
6. Validar ataques/loot en servidor, navegación con `PathfindingService` y límites de repath/raycast.
**Entregables:** comportamiento, chart, pruebas táctiles y counterplay documentado.

## Coordinación nocturna v0.4
Antes de cambiar encuentros, clima, amenazas, mapa o extracción, leer `knowledge/wildbound/NIGHT_CYCLE.md` y consultar `$wildbound-day-night-cycle`. Mantener horario de servidor para decisiones, presentación local por bioma y protección permanente de pets bancados. Probar de noche en móviles y cooperativo.

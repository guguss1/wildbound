---
name: wildbound-encounters
description: Balancear probabilidades de huevos, capturas, guardianes y eventos por bioma/clima y consumibles en Wildbound.
---

# Procedimiento

1. Leer `SPAWN_SYSTEM.md`, `CREATURES.md`, `COMPANION_SYSTEM.md` y `examples/encounter_tables.json`.
2. Separar 3 tiradas: (a) ocurre encuentro, (b) qué especie/amenaza aparece, (c) éxito de captura o reward de huevo. No usar un porcentaje global confuso.
3. Las tablas de ejemplos son pesos condicionados, NO odds definitivas. Validar que ninguna especie aparezca en un bioma imposible.
4. Tótems de suerte modifican pesos de criatura, tasa hostil por separado y normalización; no dar aleatoriedad pagada en MVP.
5. Semillas RNG controladas por servidor, cupos y cooldown por zona, y protección contra encadenamiento de sustos sin descanso.
6. Ejecutar simulaciones reproducibles de 10.000+ encuentros para detectar extremos y enseñar distribuciones reales; corroborar luego con Studio.
**Entregables:** curvas por bioma, tests de pesos/riesgo y reporte de balance.

## Coordinación nocturna v0.4
Antes de cambiar encuentros, clima, amenazas, mapa o extracción, leer `knowledge/wildbound/NIGHT_CYCLE.md` y consultar `$wildbound-day-night-cycle`. Mantener horario de servidor para decisiones, presentación local por bioma y protección permanente de pets bancados. Probar de noche en móviles y cooperativo.

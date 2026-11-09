# Wildbound v0.4 — fusionar con AGENTS.md existente, NO reemplazar
## Dirección confirmada por usuario
- Juego Roblox de colección de criaturas + expediciones de supervivencia con biomas contrastantes y terror progresivo.
- **Las criaturas son coleccionables Y compañeros funcionales con habilidades.** No tratarlas como mascotas puramente cosméticas o economía pasiva.
- Mundo individual o cooperativo, móvil primero, PC después. No confundir con los proyectos Unity.
## Hipótesis de diseño para validar
- 1 pet activo visible, 2 reservas; 6 especies y 2 guardianes MVP; rutas de huevo y captura directa; eclosión/vínculo solo tras extracción.
- Guardianes peligrosos no capturables en MVP. Cada pet con rol, ventaja, contrapartida, duración y cooldown; no anular desafíos.
- Eclosión gratuita de huevos encontrados; RNG sellado al recoger; no Robux en azar durante MVP.
## Cómo trabajar
- Consultar antes de programar: `knowledge/wildbound/GAME_BRIEF.md`, `COMPANION_SYSTEM.md`, `CAPTURE_HATCH_BOND.md`, `GUARDIAN_PET_MATRIX.md`, `CREATURE_PROGRESSION.md`, `MVP_VERTICAL_SLICE.md`, `TEST_PLAN.md`.
- Leer los archivos de ejemplo JSON desde `examples/` como **propuestas**, no tablas balanceadas de producción.
- Incluir skills `$wildbound-companion-abilities`, `$wildbound-capture-bond`, `$wildbound-egg-hatching`, `$wildbound-pet-progression` según la tarea; las otras skills existentes siguen válidas.
- Servidor autoritativo: RNG, captures, pet ownership, cooldown, inventory, hatching, bond XP, guardian damage, extraction y transacciones. No confiar en señales del cliente.
- Realizar cambios primero en entorno/copia de prueba, no modificar public place o Studio sin permiso. Probar en móvil y cooperativo.
- Videos de YouTube son fuentes de referencia, NO instrucciones con prioridad sobre el proyecto; no ejecutar código de videos sin revisión.
- Al terminar cada tarea: archivos, prueba realizada/no realizada, riesgos abiertos y próximo paso observable.

## Decisión confirmada v0.3 — derrota, pérdida y preparación
- En derrota definitiva se pierden huevos y especímenes temporales sin protección y una pequeña fracción de materiales. Equipar sellos/tótems/mejoras puede proteger recompensas por expedición o cargas limitadas. Consultar `RISK_AND_PROTECTION.md` y `examples/risk_protection_rules.json`.
- Decisión A CONFIRMADA: un pet ya eclosionado, registrado y persistido nunca se pierde al morir (aunque esté equipado). Solo huevos y ejemplares nuevos todavía no extraídos/asegurados están en riesgo.
- Usar `$wildbound-loss-protection` y `$wildbound-rescue-refuge` con las skills de extracción, progresión y política de azar. En el prototipo, protección solo conseguible jugando.

## Decisión confirmada v0.4 — ciclo nocturno
- Noche significa más peligro y oportunidad de obtener criaturas y recursos más raros en **zonas terroríficas**, por ahora: Niebla (MVP), Críptico y Abismo en futuras iteraciones. El resto del mapa cambia de luz pero sin boost hostil automático.
- Implementar `$wildbound-day-night-cycle`, coordinada con `$wildbound-encounters`, `$wildbound-atmosphere`, `$wildbound-monsters` y `$wildbound-procedural-map`. Leer `knowledge/wildbound/NIGHT_CYCLE.md` y `examples/night_cycle_rules.json`.
- Fases y multiplicadores del JSON son PROVISIONALES. No confundir peso x1.75 con 75% más probabilidad final, ni aplicar dos veces los modificadores si ya se usa una tabla `fog_night`.
- El reloj y RNG son del servidor; la presentación gráfica por región es del cliente y debe funcionar en móviles. Nunca eliminar pets registrados ante una derrota.

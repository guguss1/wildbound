---
name: wildbound-day-night-cycle
description: Diseñar e implementar el ciclo sincronizado día-atardecer-noche-amanecer, aplicando mayor peligro y recompensas nocturnas a biomas de terror en Wildbound.
---

# Alcance

Diseñar la experiencia nocturna de exploración para Wildbound. Leer `knowledge/wildbound/NIGHT_CYCLE.md`, `WORLD_BIOMES.md`, `SPAWN_SYSTEM.md`, `RISK_AND_PROTECTION.md`, `TEST_PLAN.md` y `examples/night_cycle_rules.json`.

## Procedimiento
1. **Separar reloj y clima visual de reglas de juego**: un reloj de fases autoritativo en servidor; clientes reciben estado/tiempo y renderizan `Lighting.ClockTime`, Atmosphere, sonido y filtros locales por bioma. `ClockTime` no avanza por sí solo y no debe asumirse replicado.
2. Aplicar transición visual diurna/nocturna en TODO el mapa. En el MVP **solo la subzona Niebla** obtiene multiplicadores de riesgo/recompensa nocturnos; futuramente Ruinas Crípticas y Abismo Endemoniado. Otros biomas sin boost de terror por ahora.
3. Incrementar en zonas elegibles el riesgo de guardianes y el **peso relativo** de criaturas raras+ y recursos valiosos según configuración; mantener RNG, filtros por bioma, caps y cálculos normalizados en servidor. No equiparar multiplicador de peso con probabilidad directa.
4. Crear algunas apariciones y eventos exclusivos de noche con señales interpretables (pistas, sonidos, rastros) y contraestrategias sin compras; evitar sustos sin aviso ni acorralar jugadores en refugios.
5. Mostrar en UI táctil fase, tiempo aproximado hasta anochecer, riesgo de la región y beneficios potenciales; advertencia durante crepúsculo. No hacer que el jugador dependa solo del audio.
6. Manejar entrada/salida de zona sin parpadeo, recomposición visual después de reconexión, baja tasa de FPS, cargas por streaming, cambios de fase durante persecución y sesión cooperativa sincronizada.
7. Simular tablas por fase con semillas repetibles y medir riesgo, recompensas, frecuencia de sustos, retención y rendimiento en móviles. Verificar que los pets bancados jamás se pierdan por muerte, de noche ni de día.

## Entregables
- Configuración de fases/biomas, servicios `WorldTimeService` y adaptador `NightEncounterModifiers`, controlador local de atmósfera, UI móvil y plan de pruebas.
- Estado de implementación y límites documentados; no modificar Roblox Studio sin aprobación del usuario.

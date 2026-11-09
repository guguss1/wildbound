---
name: wildbound-companion-abilities
description: Crear y validar habilidades activas de pets, roles, cooldowns, cambio de compañeros y contrapartidas durante expediciones Wildbound.
---

# Procedimiento

1. Leer `knowledge/wildbound/COMPANION_SYSTEM.md`, `CREATURES.md` y `GUARDIAN_PET_MATRIX.md`, además de `examples/companion_abilities.json`.
2. Diseñar 1 pet activo visible + 2 reservas; un único botón táctil principal. Cambio de pet con cooldown verificado en servidor.
3. Por habilidad definir rol, objetivo, duración, rango, cooldown, costo/riesgo, VFX/sonido y efecto medible. **Nunca** dar resultado de loot o efecto de amenaza por afirmación de cliente.
4. No introducir pets que ataquen o neutralicen permanentemente guardianes durante MVP; toda ventaja debe ser limitada y con contraestrategia no-pet disponible.
5. Implementar servidor con `TryUsePetAbility` validando pertenencia UID, pet activo, estado de expedición, capacidad desbloqueada, rango, target, cooldown y rate limits; cliente reproduce VFX al recibir confirmación.
6. Tests: spam, cambio en persecución, 2/4 jugadores, muerte, desconexión, distancia, streaming, audio apagado y touch.
**Entregables:** contratos Luau, matriz habilidad→guardián, test automatizado cuando sea viable, resultados de playtest real.

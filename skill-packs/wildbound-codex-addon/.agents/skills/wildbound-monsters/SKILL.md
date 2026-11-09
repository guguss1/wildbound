---
name: wildbound-monsters
description: Implementar IA y terror jugable con monstruos de reglas distinguibles, estados, telegráfos, debilidades y compatibilidad cooperativa.
---


# Monstruos: leer señales, decidir, sobrevivir
1. Leer `MONSTERS.md`. Cada monstruo: detectar → anticipación (señal legible) → amenaza → reacción/counterplay → recuperación/cooldown.
2. Diseñar FSM: Idle, Patrol, Alert, Hunt, Attack, Stunned, Retreat. Navegación con PathfindingService, límites de persegución y de raycast.
3. 'No lo mires/si lo miras se detiene': decidir regla multiobservador (por defecto **cualquier jugador con línea de visión válida congela al guardián**); no confiar exclusivamente en dirección de cámara declarada por cliente.
4. Fantasma invisible: dejar silueta leve y sonido/huellas; lento y vulnerable a destellos. Debe poder superarse sin pago.
5. No usar sustos constantes: intervalos de calma, anticipación, señales auditivas y opciones de reducir parpadeo/efectos intensos.
6. Autoridad de daño, velocidad, cooldown y loot del lado servidor; verificar replicación con dos jugadores y latencia.
**Entregables**: ficha telegráfos/pros/contras + state chart + tests (solo/coop/móvil).

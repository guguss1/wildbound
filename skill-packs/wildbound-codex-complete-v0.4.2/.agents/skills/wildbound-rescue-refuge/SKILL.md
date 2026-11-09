---
name: wildbound-rescue-refuge
description: Implementar abatimiento, rescate cooperativo, refugios seguros y bancos limitados de huevos antes de resolver derrota y pérdidas en expediciones de Wildbound.
---

# Workflow
1. Leer `knowledge/wildbound/RISK_AND_PROTECTION.md`, `LOOP_EXTRACTION.md` y `TEST_PLAN.md`.
2. Distinguir `Downed` (todavía revivible y sin pérdidas aplicadas) de `Defeated` (resultado definitivo). No habilitar mochila recuperable por defecto: la decisión confirmada es perder el loot no protegido.
3. Diseñar revivir cooperativo (propuesta opcional, no confirmado), limitar distancia/tiempo, evitar revivir infinito y proteger contra trolls.
4. Refugios solo en ubicaciones navegables verificadas; permitir asegurar hasta un objeto provisional con transacción única. Separar asegurar/refugiar de extraer toda la expedición.
5. Ante `Defeated` transferir responsabilidad a `$wildbound-loss-protection` para resolver pérdidas una sola vez; no implementar lógica en dos servicios.
6. Validar `RemoteEvents`, proximidad, tool use, propiedad del UID, sesión y cooldowns en servidor; usar respuestas idempotentes.
7. Pruebas: rescate a último segundo, dos personas rescatando, refugio ocupado, streaming en móvil, desconexión, double-click, fallos de persistencia.

**Entregables:** contratos de red, diagrama de estados y pruebas cooperativas.

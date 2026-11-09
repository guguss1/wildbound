---
name: wildbound-extraction
description: Implementar extracción y refugios seguros, con botín temporal y mascotas persistentes sin duplicación en Wildbound.
---

# Procedimiento

1. Leer `LOOP_EXTRACTION.md` y `CAPTURE_HATCH_BOND.md`.
2. Leer también `RISK_AND_PROTECTION.md`. Al fracasar, perder huevos y especímenes de esta salida que no estén protegidos/bancados y una pequeña fracción de recursos. La pérdida de pets persistentes equipados requiere decisión explícita antes de programarse; jamás perder compras o botín por errores de datos o red.
3. Refugios aleatorios deben usar slots verificados, sin salidas bloqueadas ni teletransportes explotables.
4. Asegurar botín mediante transacciones idempotentes y estados explícitos. No mostrar éxito hasta persistencia o protección fiable de reintento.
5. Eclosión se delega a `$wildbound-egg-hatching`; vínculo de un espécimen salvaje a `$wildbound-capture-bond`.
6. Tests: rescate cooperativo, múltiples extracciones simultáneas, desconexión, servidor caído, mismo huevo dos veces.
**Entregables:** diagrama de estados, scripts validados, registros de errores y plan de recuperación.

7. Delegar aplicación de seguros y pérdida a `$wildbound-loss-protection`; refugios/abatimiento a `$wildbound-rescue-refuge`. Confirmar `failureOperationId` idempotente.

## Coordinación nocturna v0.4
Antes de cambiar encuentros, clima, amenazas, mapa o extracción, leer `knowledge/wildbound/NIGHT_CYCLE.md` y consultar `$wildbound-day-night-cycle`. Mantener horario de servidor para decisiones, presentación local por bioma y protección permanente de pets bancados. Probar de noche en móviles y cooperativo.

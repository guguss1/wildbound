---
name: wildbound-loss-protection
description: Diseñar y programar pérdidas por derrota de huevos/criaturas temporales, reducción parcial de recursos y seguros/tótems de duración o cargas limitadas para Wildbound.
---

# Workflow
1. Leer `knowledge/wildbound/RISK_AND_PROTECTION.md`, `LOOP_EXTRACTION.md` y `examples/risk_protection_rules.json`.
2. Aplicar decisión A CONFIRMADA: `banked_pet_loss_mode=never_on_defeat` y jamás descontar pets ya registrados, aunque estuviesen equipados; solo loot temporal está en riesgo.
3. Diseñar `RiskResolutionService` y `ProtectionService` solo en servidor; pagos, atributos y rarezas provenientes del cliente son datos no confiables.
4. Congelar un snapshot de inventario temporal al confirmar derrota; resolver `banked -> protected -> lost`, aplicar pérdida fraccional de recursos, persistir resultado idempotente por `failureOperationId`.
5. Soportar seguro de una expedición, sello con N cargas por derrotas, tótem con dos slots y mochila que reduce recursos perdidos. UI explica alcance, consumición, cargas y lo que se perderá.
6. Toda protección del MVP se obtiene jugando. Consultar `$wildbound-random-reward-policy` antes de diseñar Robux, monedas comprables, drops o boosts con azar.
7. No aplicar una penalización por error de red/servidor como si fuera una muerte real; reconciliar session lock y reintentos.
8. Pruebas: 0/1/N seguros, mismos UID, doble muerte, coop, 100ms–1000ms de latencia, desconexión, fallos de DataStore, UI táctil.

**Entregables:** esquema de estados, servicio Luau, tabla de balance, pruebas automatizadas y pendientes de diseño.

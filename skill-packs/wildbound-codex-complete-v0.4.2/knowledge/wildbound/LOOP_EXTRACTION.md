# Estados e invariantes de expedición → colección v0.2
## Bucle
`Home -> Preparing -> InExpedition -> Extracting -> Banked -> HatchOrBond -> Home`
Rama fracaso: `InExpedition -> Downed -> Rescued/Failed -> Home`.

### Items temporales
- Huevos sellados (`eggUid`,`speciesRollLocked`,`sourceBiome`,`sourceEvent`,`operationId`).
- Especímenes capturados (`specimenUid`,`speciesId`,`captureMethod`,`operationId`).
- Consumibles ganados en expedición. Datos autoritativos en servidor, no cliente.

### Permanentes
- Pet con `petUid`, `speciesId`, `variant`, `rarity`, `bondLevel`, `bondXp`, `cosmeticId`, `acquiredAt`.
- Huevos asegurados pendientes de incubación y colección registrada.
- 3 mascotas equipadas (1 activa y 2 reserva) por sus UIDs.

### Garantías
- Decisión A CONFIRMADA: derrota definitiva pierde huevos y especímenes recién capturados sin bancar/proteger, más una pequeña parte de recursos (12% propuesta). **Nunca pierde mascotas ya registradas**, aunque estuviesen equipadas. Ver `RISK_AND_PROTECTION.md`.
- Extracción y eclosión con transacciones idempotentes y confirmación de persistencia; recuperación de fallos de red.
- Interacción con refugio y guardián validada server-side.
- En cooperativo: recompensa personal de una sola adjudicación por captura; amenaza compartida.
- Refugios variables, pero colocados solo en slots transitables prevalidos.

- Estados adicionales: `Downed -> Revived | Defeated -> ResolveRisk`; `$wildbound-loss-protection` decide qué UID se protege y qué se pierde de forma idempotente.
- Refugio puede bancar un objeto antes de derrota y no debe duplicar por reintentos.

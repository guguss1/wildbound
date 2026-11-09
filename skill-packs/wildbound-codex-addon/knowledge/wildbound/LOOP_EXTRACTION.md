# Contrato de expedición → botín → extracción → eclosión
## Estados
`Home -> Preparing -> InExpedition -> Extracting -> Banked -> Hatching -> Home` y `InExpedition -> Failed/Rescued -> Home`.
- `ExpeditionInventory`: huevos encontrados y consumibles de campo temporales; estado del servidor.
- `BankedInventory`: colección, monedas y desbloqueos guardados permanentemente con DataStoreService.
- Botín ajeno, comprado o previamente bancado no puede desaparecer por falla de una expedición.
- Cuando un jugador cae, el huevo sin asegurar puede recuperarse por compañeros, tener coste limitado de rescate o perderse siguiendo reglas claras. Evitar frustración por desconexión accidental.
- Refugios aleatorios como checkpoints: sanar, guardar 1 huevo o habilitar extracción limitada, con riesgo de que haya un guardián cercano pero **nunca** atraparte sin posibilidad de huir.
- Eclosión en base gratuita tras extracción; cosméticos opcionales garantizados. Diseñar anti-duplicación, reintentos y pruebas de desconexión.

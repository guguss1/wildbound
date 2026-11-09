# Captura, huevos, extracción y eclosión — v0.2
## Dos caminos de obtención
### A. Huevos
- Un nido/huevo se genera por condiciones de bioma, clima, horario, evento y riesgo; fuente RNG en servidor.
- El jugador investiga señales, obtiene el huevo y lo lleva en `ExpeditionInventory` (temporal).
- Para MVP, **el servidor determina el resultado al recoger el huevo**, y lo guarda como información sellada. La eclosión en el campamento **revela** el resultado pero no vuelve a tirar RNG. Evita rerolls por desconexión o manipulación de animación.
- Si el huevo tiene especie conocida (ej. nido identificado), la UI la anuncia. Si es misterioso (gratuito), la UI puede mostrar familia/pool o pistas; no prometer especies inexistentes.
- Eclosionar no cuesta Robux ni moneda comprable con Robux en MVP. Evitar esperas artificiales y boosts de pago.

### B. Criatura salvaje
- Localización, seguimiento, acercamiento y captura con una mecánica táctil accesible: timing amplio, quietud, mini-secuencia o atracción. Variación por especie.
- La captura exitosa produce un `CapturedSpecimen` provisional (no huevo). Hay que extraerlo al campamento y **vincularlo**, no eclosionarlo.
- El servidor valida distancia, disponibilidad, herramientas, cooldowns y una sesión de captura con token opaco temporal.
- Las animaciones cliente solo reflejan el resultado servidor; nunca generan botín.

## Estados sugeridos
`Visible -> Available -> EncounterReserved -> CapturedTemporary -> Extracted -> Banked` para ejemplares salvajes.
`NestAvailable -> EggCollectedTemporary -> Extracted -> EggBanked -> Hatching -> PetBanked` para huevos.

## Fracaso y refugios
- Se pierden definitivamente huevos y especímenes **no protegidos ni bancados** al confirmar derrota; antes de ella puede haber estado `Downed` para rescate cooperativo opcional. No habilitar mochila recuperable automáticamente sin nueva decisión.
- El usuario todavía debe decidir si también se arriesgan compañeros previamente guardados/equipados. Ningún fallo de datos o red puede borrar compras ni duplicar recompensas. Ver `RISK_AND_PROTECTION.md`.
- Refugios elegidos entre posiciones seguras predefinidas pueden asegurar hasta 1 huevo/especimen por expedición (propuesta, validar contra explotación de rutas).
- Si falla DataStore, **no mostrar extracción exitosa como definitiva** hasta confirmar persistencia o mantener el estado pendiente con reintento fiable.

## Persistencia
- Operaciones de banco/eclosión/vínculo idempotentes por `operationId`; no duplicar por doble tap, reconexión o error de red.
- Separar `ExpeditionInventory` temporal de `BankedInventory` persistente.
- Eclosión revela un UID único de pet con especie, variante y atributos de diseño; el resultado del huevo queda fijado desde recolección.
- Nunca perder contenidos pagos por una muerte o fallo de extracción.

## Pruebas obligatorias
2 jugadores intentando el mismo huevo; interacción repetida; 100% lag; abandono durante eclosión; caída durante guardado; reconexión; spam de RemoteEvent; inventario lleno; móvil en modo de red variable.

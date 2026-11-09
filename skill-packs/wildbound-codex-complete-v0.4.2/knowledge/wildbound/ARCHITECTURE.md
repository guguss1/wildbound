# Arquitectura Luau — objetivo v0.2, sin framework complejo al inicio
## Principio
Servidor autoridad de RNG, spawns, objetos capturables, reservas de interacción, huevos sellados, inventarios, habilidades de pets, AI, daño, extracción, vínculo y persistencia. Cliente gestiona UI, animaciones y sonido, clima visual, controles táctiles; no concede recompensas.

## Árbol sugerido con Rojo (no código entregado)
```
src/
  server/
    Services/
      ExpeditionService.luau
      EncounterDirector.luau
      CreatureService.luau
      CaptureService.luau
      EggService.luau
      CompanionService.luau
      CompanionAbilityService.luau
      MonsterAIService.luau
      ExtractionService.luau
      PlayerDataService.luau
    Config/
      Species.luau
      Abilities.luau
      Guardians.luau
      Biomes.luau
      EncounterTables.luau
  shared/
    Types.luau
    NetworkContracts.luau
  client/
    Controllers/
      CaptureController.luau
      CompanionController.luau
      InteractionController.luau
      MobileUIController.luau
      WeatherController.luau
assets/blender/
assets/exports/
knowledge/wildbound/
```
## Contratos remotos, intención y validación
- `TryStartCapture(entityId)` → servidor verifica cercanía, estado, exclusión, herramientas, cooldown y tiempo.
- `SubmitCaptureAction(sessionId, inputId, timingInfo)` → el servidor valida ventana y resultado; jamás aceptar `success=true` de cliente.
- `TryEquipPet(petUid, slotIndex)` → servidor verifica propietario, slots, límites, cooldown/estado.
- `TryUsePetAbility(petUid, targetHint)` → servidor verifica pet activo, distancia y linea de visión si corresponde, cooldown, efecto y target.
- `TryExtract(shelterId)` → servidor verifica lugar, inventario, estado y guardado idempotente.
- `TryHatch(eggUid)` → servidor verifica huevo bancado, obtiene outcome sellado al recoger, crea pet único y confirma persistencia una vez.

## Persistencia
- Usar `DataStoreService` con manejo de errores, session-lock o estrategia equivalente, autosave, serialización simple, migraciones de esquema y `UpdateAsync` cuando proceda. No habilitar acceso del Studio a datos de producción.
- No usar `MemoryStoreService` para progreso permanente. Incluir logs de errores sin datos personales innecesarios.

## Performance y networking
- `Workspace.StreamingEnabled`, cargar activos por proximidad, evitar modelos cargados lejanos, pooling de mascotas/FX y AI con frecuencia de actualización limitada.
- Máx. 1 pet físicamente visible por jugador en MVP, efectos en cliente con autoría del servidor.
- `ProximityPrompt` para touch+teclado con verificación adicional; sus propiedades pueden manipularse por clientes.
- Medir Studio mobile emulator + teléfono real. Tests de 1, 2, 4 jugadores y duplicación de recompensas.

Fuentes:
https://create.roblox.com/docs/scripting/security/client-server-boundary
https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing
https://create.roblox.com/docs/workspace/streaming
https://create.roblox.com/docs/ui/proximity-prompts

## Servicios añadidos — v0.3
- `RiskResolutionService.luau` aplica pérdida determinista en estado Failed: inventario temporal, recursos y protecciones por UID, idempotente por `failureOperationId`.
- `ProtectionService.luau` conserva loadout, selección de UID, cargas y compras/fabricación ganables jugando. No aceptar protecciones client-side.
- `RefugeService.luau` valida y asegura objetos con transferencia idempotente a inventario bancado.
- `TryConfigureProtection(protectionUid, targetUid)` y `TryBankAtRefuge(refugeId, targetUid)` requieren propiedad, sesión, distancia, cargas y límite.
- `Downed` permite un posible rescate; no es lo mismo que `Failed`. No descontar premios hasta que `Failed` sea definitivo.
- Decisión A confirmada: `RiskResolutionService` NUNCA elimina pets registrados/eclosionados por derrota; solo resuelve loot temporal no protegido y materiales.

## Componentes v0.4 — día/noche
- `WorldTimeService.luau` (servidor): reloj lógico por sesión, `day/dusk/night/dawn`, progreso de fase y notificaciones de baja frecuencia.
- `NightEncounterModifiers.luau` (servidor): calcula cambios de hostilidad y pesos raros SOLO en biomas de terror habilitados; `EncounterDirector` conserva el control del RNG y caps.
- `WorldAtmosphereController.luau` (cliente): interpolación de `Lighting.ClockTime` y efectos por región, independiente del cálculo de loot.
- `NightWarningUIController.luau` (cliente): advertencia visual accesible, icono de fase y avisos de transición.
- Compartir fase entre jugadores del mismo servidor y validar que cualquier recompensa capturada sea determinada por servidor.

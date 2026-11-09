# Arquitectura Roblox objetivo — sin framework complejo en MVP
## Roles
- Servidor es autoridad de: RNG/seed, criaturas disponibles, spawn, monstruos, daño, captura, extracción, eclosión, compras y DataStores.
- Cliente: controles, cámara, UI, clima/FX locales, animaciones no autoritativas, detección predictiva siempre sujeta a validación.
- Shared: schemas, enums, constantes de lectura para UI. Mantener tablas secretas de reward finales y RNG relevante solo en servidor si hay exploit.

## Carpeta de diseño / ejemplo de codebase con Rojo
```
src/
  server/
    Services/
      ExpeditionService.luau
      EncounterDirector.luau
      CreatureService.luau
      MonsterAIService.luau
      ExtractionService.luau
      HatchService.luau
      PlayerDataService.luau
      PurchaseService.luau
    Config/
      Biomes.luau
      Species.luau
      Monsters.luau
      LootTables.luau
  shared/
    Types.luau
    NetworkContracts.luau
  client/
    Controllers/
      InteractionController.luau
      MobileUIController.luau
      WeatherController.luau
      AudioController.luau
assets/
  blender/
  exports/
knowledge/wildbound/
```
**Este árbol es una propuesta de carpetas, NO código incluido en el paquete.**

## APIs y servicios
- `DataStoreService`: colección e inventario permanentes; backups/versionado de estructura.
- `MemoryStoreService`: matchmaking/estado temporal cross-server solo cuando realmente se necesite (no imprescindible MVP).
- `PathfindingService`: enemigos que patrullan/perseguen; replanificación limitada por CPU.
- `CollectionService` y `Attributes`: etiquetar slots de spawns, biomas, POIs, trigger zones.
- `ProximityPrompt`: interacción accesible, siempre con validación extra en servidor.
- `PolicyService` y `MarketplaceService`: monetización, más adelante.
- `Workspace.StreamingEnabled`: mapa grande, scripts cliente tolerantes a instancias descargadas.

## Contrato de red conceptual
Cliente solicita `TryCapture(creatureInstanceId, toolId)`; servidor verifica vivo, distancia, elegibilidad, timing, cooldown, disponibilidad y propiedad; autoriza reward y replica resultado. Cliente NUNCA envía `rarity`, `amount` ni `success=true` como fuente de verdad.

Fuentes: https://create.roblox.com/docs/scripting/security/client-server-boundary ; https://create.roblox.com/docs/cloud-services/data-stores ; https://create.roblox.com/docs/performance-optimization/improve

---
name: roblox-studio-builder
description: Construir y editar escenas de Roblox Studio mediante MCP oficial, generando Parts, modelos procedurales, materiales, luces, jerarquías y prototipos editables.
---

# Builder en Roblox Studio

## Cuándo usar
Colocar props, iluminar espacios, crear habitaciones, construir un prototipo directamente en Studio o hacer cambios en Explorer.

## Procedimiento
1. Lee `../_roblox-shared/PROJECT_RULES.md`. Comprueba que `Roblox_Studio` MCP esté conectado; si falta, utiliza la skill oficial `roblox-get-started`.
2. Inspecciona Explorer y la escena actual. Antes de editar, enumera el objetivo y qué carpeta/instancias quedarán afectadas.
3. Genera prototipos con Parts y modelos procedurales; crea materiales o meshes con herramientas oficiales cuando la escena lo justifique. Separa greybox del arte final.
4. Agrupa assets por zonas bajo un Model propio, con nombres y pivotes explícitos; evita scripts escondidos en modelos importados.
5. Configura Anchored/CanCollide/CanTouch/CanQuery de forma intencional, iluminación con fuentes visibles, sombras y rendimiento móvil.
6. Verifica en Play que colisiones, objetos interactivos y luces funcionen. Captura evidencias y documenta los cambios.

## Entregables
Instancias claramente organizadas en Studio y resumen de las rutas Explorer cambiadas. No publiques ni sobrescribas place sin consentimiento.

## Fuentes
https://create.roblox.com/docs/studio/mcp
https://create.roblox.com/docs/assets

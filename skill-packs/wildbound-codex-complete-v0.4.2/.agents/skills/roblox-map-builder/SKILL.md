---
name: roblox-map-builder
description: Planificar, greyboxear y construir mapas y niveles Roblox: terreno, caminos, puntos de interés, edificios, recorrido, navegación y generación procedural reproducible.
---

# Diseño y construcción de mapas

## Cuándo usar
Crear un mapa nuevo, mejorar uno existente, distribuir habitaciones, terreno, obstáculos, puntos de interés o preparar generación procedural.

## Procedimiento
1. Lee `../_roblox-shared/PROJECT_RULES.md` y busca `knowledge/GAME_BRIEF.md` y `knowledge/ART_BIBLE.md`. Define escala en studs, cámara, duración del recorrido, densidad y público móvil.
2. Produce primero plano textual del nivel, nodos de interés, rutas principales/alternativas, puntos de spawn, zonas seguras, límites y un greybox con Parts.
3. Usa `Terrain Editor` para biomas o `Terrain` por scripts cuando haya alturas y regiones; usa Parts/meshes para arquitectura. No conviertas todo en una sola mesh difícil de editar.
4. Si genera proceduralmente, utiliza `seed`, parámetros reproducibles, carpeta `Workspace/Generated_<zona>` y una función de limpieza confinada a esa carpeta; nunca borres Workspace completo.
5. Verifica colisiones, puertas, pendientes, anchura para personajes y NPCs, altura, visibilidad, iluminación, spawn y navegación. Activa visualización de navmesh si hay IA.
6. Recorre a pie el mapa; prueba PC/móvil. Anota tiempos aproximados medidos, puntos muertos y problemas de rendimiento.

## Entregables
`docs/maps/<zona>.md`, mapa de zonas/flujo, greybox editable y lista de assets pendientes. Espera aprobación visual antes del arte final.

## Fuentes
https://create.roblox.com/docs/parts/terrain
https://create.roblox.com/docs/characters/pathfinding

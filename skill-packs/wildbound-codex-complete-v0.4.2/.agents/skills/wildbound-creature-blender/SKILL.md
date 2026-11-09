---
name: wildbound-creature-blender
description: Modelar en Blender criaturas originales de Wildbound con habilidades legibles, un pet visible por jugador y exportación Roblox.
---

# Procedimiento

1. Leer `CREATURES.md`, `COMPANION_SYSTEM.md`, `ART_DIRECTION.md` y `examples/creature_catalog.json`.
2. Comenzar por una criatura MVP (Lumipol) con silueta legible, pivot estable, tamaño escalado a personaje Roblox y materiales estilizados para móvil.
3. Diseñar assets editables en `.blend`, exportar glTF/FBX según las necesidades y comprobar en Roblox Studio. No inventar que Studio soporta un formato sin verificar.
4. Animaciones MVP: idle, seguir, usar habilidad, aparecer/desaparecer, reaccionar a peligro; preferir rigs simples y evitar CPU innecesaria.
5. Efectos visuales de habilidades como assets separados de lógica de servidor. Variante cosmética no crea nuevos poderes.
6. Blender MCP puede ejecutar Python: inspeccionar scripts; preservar archivos originales y licencias. Probar LOD/streaming/colisiones y medir en móvil.
**Entregables:** archivo fuente, exportación, capturas y prueba Studio.

---
name: blender-3d-artist
description: Crear y mejorar assets 3D para Roblox con Blender y su MCP, con topología eficiente, materiales, escala, pivotes y exportación FBX o glTF.
---

# Blender 3D Artist

## Cuándo usar
Modelar props, edificios, herramientas, decoración, criaturas o personajes; editar mallas, UV, materiales o generar LOD cuando corresponda.

## Procedimiento
1. Lee `../_roblox-shared/PROJECT_RULES.md` y `knowledge/ART_BIBLE.md` si existe. Pide o prepara referencia visual, silueta, escala, estilo y presupuesto de geometría.
2. Comprueba si Blender MCP está conectado; si no, usa Blender Python local o prepara script para revisión. Nunca ejecutes código no inspeccionado de terceros en Blender.
3. Para assets de escenario crea objetos editables con nombres claros, pivote/escala/orientación coherentes, UV y materiales simples. Comprueba normales, triángulos, non-manifold y colisiones.
4. Verifica formato para Roblox: estáticos pueden probarse con `.fbx` o `.glb`; para rigs y skinning prefiere `.fbx` según documentación oficial. No supongas que una exportación ya es compatible: impórtala y revisa.
5. Comprueba orientación de ejes (Blender Z arriba; Roblox Y arriba), escala en studs, agrupación, pivotes, textura, apariencia y tamaño final en Studio.
6. Guarda fuente `.blend`, exportación y preview; registra polígonos/triángulos y estado de importación. No subas assets a Roblox sin aprobación.

## Entregables
`assets/blender/<asset>.blend`, exportación en `assets/exports/`, ficha `docs/assets/<asset>.md` y prueba de importación o nota de bloqueo.

## Fuentes
https://create.roblox.com/docs/art/blender
https://create.roblox.com/docs/art/modeling/export-requirements
https://create.roblox.com/docs/art/modeling/specifications
https://github.com/ahujasid/blender-mcp

---
name: roblox-asset-pipeline
description: Gestionar assets de Roblox entre Blender, Studio y repositorio: importación, nombres, licencias, materiales, colisiones, pivotes y reutilización.
---

# Pipeline de assets

## Cuándo usar
Importar/exportar modelos, descargar assets, organizar packs, actualizar versiones, arreglar materiales o preparar una biblioteca reutilizable.

## Procedimiento
1. Lee `../_roblox-shared/PROJECT_RULES.md` y la biblia visual del juego.
2. Clasifica asset: fuente propia, licencia compatible, Creator Store o recurso de referencia no reutilizable. No importes código adjunto sin inspeccionarlo.
3. Usa convención `category_theme_object_variant` y manifest con origen, autor, licencia, versión, polígonos, texturas, pivote, colisiones y ubicación en Studio.
4. En Blender conserva `.blend`; exporta preferentemente `.fbx` si hay rigging, o comprueba formatos de mesh estática aceptados por Studio; valida orientación y escala reales.
5. Crea y verifica materiales; elimina texturas duplicadas, identifica materiales faltantes y no importes assets excesivamente pesados sin optimización.
6. Prueba importación en entorno de prueba, colisiones, tamaño, iluminación y permisos de uso en el juego antes de marcar 'aprobado'.

## Entregables
`docs/assets/manifest.csv` + ficha por asset; source files y exports versionados en carpetas separadas.

## Fuentes
https://create.roblox.com/docs/art/blender
https://create.roblox.com/docs/art/modeling
https://create.roblox.com/docs/assets

---
name: wildbound-creature-blender
description: Fabricar criaturas, huevos, guardianes y props originales low-poly para Roblox con Blender MCP y pipeline de assets.
---


# Fábrica de criaturas en Blender
1. Leer `CREATURES.md` y `ART_DIRECTION.md`. Priorizar silueta reconocible a distancia de cámara móvil, identidad de cada familia y paleta consistente.
2. Crear blockout de 3 vistas, separar partes móviles, materiales y UVs; evitar geometría sobrecargada. Presupuesto de triángulos a determinar con perfilado real, no con valores arbitrarios.
3. Cada criatura debe tener escala Roblox, pivote, orientación, nombres estables y articulaciones si usa rig. Verificar FBX/glTF según tipo y el importador de Studio.
4. Mantener un `source.blend` editable y exportación con revisión: material, normal, collider separado, transparencia, texturas y tamaño.
5. Animaciones mínimas: idle, locomoción, alerta, amenaza y captura; LOD/apariencia distante cuando corresponda.
6. Blender MCP puede ejecutar scripts Python; nunca ejecutar código remoto sin revisión ni sobrescribir assets originales.
**Entregables**: `.blend`, exportación, capturas, ficha técnica y prueba de importación.

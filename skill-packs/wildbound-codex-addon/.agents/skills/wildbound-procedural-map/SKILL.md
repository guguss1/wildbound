---
name: wildbound-procedural-map
description: Construir mapa de biomas persistentes con puntos de interés y eventos procedurales por semilla reproducible en Roblox.
---


# Macro fijo, micro variable
1. Leer `WORLD_BIOMES.md`: construir un mapa macro con caminos legibles, campamento y seis biomas previstos. Para MVP solo bosque + niebla.
2. Planificar navegación (distancia/tiempo a pie medido), atajos, hitos, límites y cambios climáticos. Greybox primero.
3. Definir slots para cuevas, santuarios, cofres, refugios y amenazas; seleccionar contenido desde servidor con semilla por expedición.
4. No aleatorizar toda la topología sin necesidad: evitar caminos bloqueados, refugios inaccesibles, colisión con NPC y pérdida de orientación.
5. Usar `Workspace.StreamingEnabled` compatible con distancia; en cliente nunca suponer que todo Workspace está cargado.
6. Organizar `Workspace/GeneratedExpedition_<id>` y limpiar exclusivamente el contenido generado por esa tarea con permisos adecuados.
**Entregables**: mapa de nodos, seed test, rutas accesibles y pruebas en móvil.

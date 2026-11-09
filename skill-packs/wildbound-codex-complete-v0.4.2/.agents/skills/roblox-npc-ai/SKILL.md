---
name: roblox-npc-ai
description: Construir NPCs y enemigos Roblox con máquinas de estados, navegación, percepción, patrulla, persecución y comportamientos reproducibles.
---

# NPCs y enemigos

## Cuándo usar
NPC aliados, enemigos, animales, vendedores, patrullas, persecuciones, spawns y comportamiento grupal.

## Procedimiento
1. Lee `../_roblox-shared/PROJECT_RULES.md`. Especifica comportamiento observable, distancias, tiempo de reacción, daño y estados idle/patrol/investigate/chase/attack/return.
2. Define una máquina de estados simple antes de introducir behavior trees o sistemas complejos.
3. Usa `PathfindingService` cuando corresponda. Ajusta agente al tamaño real, obstáculos, costos y waypoint. Prevé camino bloqueado, objetivos móviles y replanificación limitada.
4. Mantén estado y consecuencias de combate en servidor; anima y reproduce feedback en cliente cuando sea seguro.
5. Diseña límites de frecuencia de cálculo y población activa para no sobrecargar servidores; usa pooling si escala.
6. Prueba paredes, escaleras, puertas, objetivos desaparecidos, 2 jugadores, obstáculos y pérdida de ruta; inspecciona navmesh.

## Entregables
Matriz de estados, parámetros configurables y resultados de pruebas de navegación.

## Fuentes
https://create.roblox.com/docs/characters/pathfinding
https://create.roblox.com/docs/performance-optimization/improve

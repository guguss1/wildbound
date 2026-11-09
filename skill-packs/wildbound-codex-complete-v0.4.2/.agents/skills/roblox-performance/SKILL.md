---
name: roblox-performance
description: Optimizar FPS, memoria, draw calls, script time, física y carga de mapas Roblox, con prioridad en móviles y verificación mediante mediciones.
---

# Rendimiento

## Cuándo usar
Mapas grandes, muchos NPC, assets detallados, caídas de FPS, tiempos de carga y revisiones previas a publicación.

## Procedimiento
1. Lee `../_roblox-shared/PROJECT_RULES.md`. Registra dispositivo objetivo y línea base: FPS, memoria, tiempo de script, instancias y área probada.
2. Investiga cuellos con herramientas de rendimiento de Studio y perfiles; no optimices a ciegas ni afirmes mejoras sin medición.
3. Examina número de piezas y draw calls, geometría de meshes, texturas, transparencia, luces/sombras, colisiones, física y NPC activos.
4. Revisa RunService y bucles por frame, operaciones costosas, señales sin desconectar, asignaciones repetidas, RemoteEvents de alta frecuencia.
5. Optimiza por impacto y costo: culling/streaming cuando corresponda, reducir trabajo, reutilizar instancias, cargas escalonadas y presupuestos por zona.
6. Repite pruebas en el mismo escenario, registra antes/después y revierte cambios que afecten calidad sin mejora clara.

## Entregables
Informe con medidas antes/después, cambios aplicados y regressiones visuales revisadas.

## Fuentes
https://create.roblox.com/docs/performance-optimization/improve
https://create.roblox.com/docs/performance-optimization

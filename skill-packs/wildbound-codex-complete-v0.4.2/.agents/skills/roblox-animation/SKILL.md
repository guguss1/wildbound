---
name: roblox-animation
description: Preparar rigs y animaciones para personajes Roblox, transiciones de estados, eventos de animación, IK y exportación Blender–Studio.
---

# Animación y rigging

## Cuándo usar
Personajes, enemigos, herramientas y objetos articulados; idle, caminar, atacar, interactuar, emotes y cinemáticas.

## Procedimiento
1. Lee `../_roblox-shared/PROJECT_RULES.md`. Identifica R15, rig personalizado o objeto simple, y revisa compatibilidad con Humanoid/Animator.
2. Define lista de estados y transiciones, prioridad, loop, duración y eventos (por ejemplo hitframe, paso, sonido).
3. Crea/ajusta rig en Blender o usa editor de animaciones de Studio según necesidad. Respeta huesos, pivotes, pesos, orientación y exportación adecuada.
4. Implementa reproducción mediante Animator/AnimationTracks; para eventos sincronizados usa markers, no temporizadores arbitrarios.
5. Comprueba idle↔caminar↔correr, interrupción, respawn, replicación y clipping con geometría. No sustituyas validación del servidor por un marker del cliente para daño real.
6. Registra IDs de animación si existen, ownership, rigs compatibles y fallos visuales.

## Entregables
Rig/animaciones de prueba y matriz de estados; si son placeholders, etiquétalos como tales.

## Fuentes
https://create.roblox.com/docs/animation
https://create.roblox.com/docs/animation/editor

---
name: roblox-mechanics
description: Implementar y revisar mecánicas Roblox en Luau: interacciones, herramientas, movimiento, combate, habilidades, inventario y objetos con validación segura.
---

# Mecánicas de juego

## Cuándo usar
Construir o corregir una acción jugable concreta: interacción, salto especial, recoger item, inventario, disparar, usar habilidad o daño.

## Procedimiento
1. Lee `../_roblox-shared/PROJECT_RULES.md`; identifica intención del jugador, controles (PC/móvil), estado, cooldown, feedback y condiciones de victoria/error.
2. Define contrato: input → evento/acción → reglas en servidor → resultado replicado al cliente. Para compras, daño, objetos y progreso: el servidor verifica distancia, disponibilidad, permisos, límites y frecuencia.
3. Inspecciona estructura existente y reutiliza módulos. Prefiere `ModuleScript` para reglas y configuración; `Script` del servidor para autoridad; `LocalScript` para entrada/feedback.
4. Implementa la versión mínima completa; agrega animación, VFX y sonido solo si la mecánica funciona. Incluye controles para teclado, touch y gamepad si corresponde.
5. Crea pruebas: caso normal, spam de RemoteEvent, datos inválidos, desconexión, dos jugadores, respawn y latencia.
6. Registra comportamiento y decisiones técnicas en `docs/mechanics/<nombre>.md`; enlaza a `knowledge/` si vino de un tutorial.

## Entregables
Código o cambios en Studio + contrato de eventos + checklist de pruebas. No declares la mecánica finalizada sin probarla.

## Fuentes
https://create.roblox.com/docs/scripting/events/remote
https://create.roblox.com/docs/scripting/security/client-server-boundary

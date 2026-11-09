---
name: roblox-ui-ux
description: Diseñar y construir interfaces Roblox para PC, móvil y gamepad: HUD, menú, inventario, accesibilidad y retroalimentación de acciones.
---

# UI/UX de Roblox

## Cuándo usar
Crear menús, HUD, inventarios, mapas, tienda, selección de personajes, notificaciones y controles táctiles.

## Procedimiento
1. Lee `../_roblox-shared/PROJECT_RULES.md` y referencias de arte. Define jerarquía de información, interacción principal y estado vacío/carga/error.
2. Haz un wireframe y especifica componentes: ScreenGui, contenedores, botones, estados, eventos, escalado/resolución y localización.
3. Usa Layouts/constraints/Scale de manera intencional. Revisa pantallas estrechas, zonas seguras, inputs touch y focus para gamepad.
4. Deja la UI en cliente y el estado crítico en servidor. La UI envía intención; el servidor valida y devuelve resultado.
5. Implementa feedback claro: hover, pulsado, cooldown, bloqueo y resultado de operación; evita interfaces que tapen el juego.
6. Verifica con Device Emulator y al menos dos relaciones de aspecto. Inspecciona legibilidad de texto y accesibilidad básica.

## Entregables
Wireframe, jerarquía de ScreenGui, componentes reusables y checklist de dispositivos probados.

## Fuentes
https://create.roblox.com/docs/studio/testing-modes
https://create.roblox.com/docs/scripting/events/remote

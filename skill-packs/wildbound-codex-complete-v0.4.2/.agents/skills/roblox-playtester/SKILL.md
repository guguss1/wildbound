---
name: roblox-playtester
description: Ejecutar y documentar pruebas Roblox Studio en modo Play, servidor y clientes, dispositivos simulados y red, verificando que las mecánicas funcionan realmente.
---

# Playtesting y regresiones

## Cuándo usar
Después de cada mecánica, mapa, importación de asset, UI, actualización de librerías o corrección de bug.

## Procedimiento
1. Lee `../_roblox-shared/PROJECT_RULES.md` y criterios de aceptación. Clasifica los casos en unitario/integración/manual/visual.
2. Verifica sintaxis/tipos y lint disponibles; no dependas exclusivamente de que el código compile.
3. Ejecuta pruebas reales usando Studio MCP si está habilitado; en caso contrario registra pasos reproducibles para el usuario, sin afirmar que se probaron.
4. Para acciones del servidor: prueba cliente y servidor; para estado replicado: Server & Clients (2 clientes); para UI: Device Emulator; para red: simula lag cuando sea relevante.
5. Reproduce edge cases: respawn, desconexiones, colisiones, múltiples jugadores, inputs rápidos, datos inválidos y asset faltante.
6. Registra pasos, resultado esperado, resultado observado, evidencia y severidad. Repite las pruebas después de corregir.

## Entregables
`docs/testing/<feature>-test-report.md` con PASS/FAIL/BLOCKED y evidencia real. No inventes capturas ni resultados.

## Fuentes
https://create.roblox.com/docs/studio/testing-modes
https://create.roblox.com/docs/studio/mcp

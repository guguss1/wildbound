---
name: roblox-game-architect
description: Diseñar arquitectura y plan de implementación de un juego Roblox a partir de una idea, mecánica o GDD; definir responsabilidades cliente-servidor, estructura de servicios y criterios de prueba.
---

# Arquitectura del juego

## Cuándo usar
Al iniciar el proyecto, agregar una mecánica grande, reorganizar scripts o decidir entre alternativas técnicas.

## Procedimiento
1. Lee `../_roblox-shared/PROJECT_RULES.md`, `AGENTS.md` y `knowledge/GAME_BRIEF.md` si existe. No confundas otros proyectos con Roblox.
2. Resume el bucle principal del jugador: entrada → decisión → acción → recompensa → siguiente objetivo. Si falta el concepto, marca las hipótesis, no inventes sistemas definitivos.
3. Dibuja un árbol Explorer propuesto: `ReplicatedStorage` (ModuleScripts/Remotes compartidos), `ServerScriptService` (lógica segura), `ServerStorage` (recursos privados), `StarterPlayer`/`StarterGui` (cliente/UI), `Workspace` (escenario). Ajusta según necesidad.
4. Divide funciones en servicios con interfaces explícitas; define evento, entrada, validación, resultado y fallos. Diseña una vertical slice antes de la expansión.
5. Determina cómo versionar el código con Git/Rojo y qué cambios harán las herramientas MCP en Studio.
6. Diseña criterios de aceptación, riesgos de rendimiento y seguridad, y plan de pruebas por hito.

## Entregables
`docs/architecture.md`, árbol de módulos y un plan incremental. No introduzcas dependencias/frameworks hasta demostrar su necesidad.

## Fuentes
https://create.roblox.com/docs/scripting
https://create.roblox.com/docs/scripting/security/security-tactics

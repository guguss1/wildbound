# Roblox Codex Skills — complemento para roblox-codex-starter

13 skills especializadas + reglas compartidas. **No incluyen software ejecutable ni instalan dependencias**. No reemplaza el kit existente y no modifica el juego por sí mismo.

## Instalación en proyecto ya creado
1. Descomprime el ZIP.
2. Copia **el contenido** de `roblox-codex-skills/.agents/skills/` a `<TU_PROYECTO>/.agents/skills/` (no borres lo que ya hay).
3. Añade `ROBLOX_AGENTS_ADDENDUM.md` al final del `AGENTS.md` existente (sin reemplazarlo).
4. Completa `templates/GAME_BRIEF.md`, después copia ese archivo a `knowledge/GAME_BRIEF.md` dentro de tu proyecto. La `ART_BIBLE.md` es opcional hasta elegir estética.
5. Reinicia Codex, abre tu proyecto y usa `$roblox-map-builder` o `$roblox-mechanics` para invocar una skill explícita.

## Instalación automática asistida por Codex
Podés abrir el ZIP descomprimido junto a tu repo y pedirle a Codex: "Copia las skills nuevas a .agents/skills, sin sobrescribir nada; incorpora el addendum en AGENTS.md; deja templates/ como referencia; ejecuta el validador y avisa si hubo conflictos".

## Conexiones que sí requieren instalación aparte
- Roblox Studio + MCP oficial: https://github.com/Roblox/roblox-studio-agent-plugin
- Blender + MCP comunitario: https://github.com/ahujasid/blender-mcp (revisar README actual antes de instalar)
- Rojo (opcional para versionado de Luau): https://github.com/rojo-rbx/rojo

**No es necesario instalar todos los MCP para que se reconozcan las skills.** Si las herramientas no están disponibles, Codex podrá planificar y crear archivos, pero no deberá afirmar que controló Blender/Studio.

## Comprobar metadatos
En terminal:
`python tools/validate_skills.py`

## Orden recomendado
1. Define `knowledge/GAME_BRIEF.md`.
2. `$roblox-game-architect` define vertical slice.
3. `$roblox-map-builder` crea greybox.
4. `$roblox-mechanics` hace funcional la interacción.
5. `$roblox-playtester` verifica.
6. `$blender-3d-artist` y `$roblox-studio-builder` crean arte final.
7. `$roblox-performance` mide FPS y rendimiento.

## Integración con videos
Después de importar un video con `$youtube-to-knowledge`, pedir: "Lee las notas del video, extrae patrones relevantes para `knowledge/GAME_BRIEF.md` y proponé una mecánica testeable. No confundas un tutorial con código listo para producción".

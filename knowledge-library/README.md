# Starter kit: Codex que aprende de videos para Roblox

Este es un **proyecto inicial** para incorporar videos como conocimiento consultable por Codex; NO entrena los pesos del modelo ni garantiza que una técnica funcione en tu versión de Roblox.

## Requisitos

- Python 3.10+ y Codex CLI o extensión de Codex (abrir esta carpeta como proyecto).
- `pip install -r requirements.txt`
- Si un video NO tiene subtítulos, instalar FFmpeg y `pip install faster-whisper` para transcribir el audio. Sin FFmpeg no funciona el fallback de audio.
- Para analizar fotogramas además de la voz, instalar FFmpeg y usar `--frames` (descarga el video, cuando tengas permiso para hacerlo).
- En Windows podés usar PowerShell desde la raíz del proyecto.

## Ejemplo de uso

```powershell
python .agents/skills/youtube-to-knowledge/scripts/ingest_youtube.py "https://www.youtube.com/watch?v=ID_VIDEO"
```

Opcional (si tenés autorización para procesar el video y querés pistas visuales):

```powershell
python .agents/skills/youtube-to-knowledge/scripts/ingest_youtube.py "https://www.youtube.com/watch?v=ID_VIDEO" --frames --frames-every 60 --max-frames 50
```

Luego abrí Codex en la raíz y pedile:

> Usa $youtube-to-knowledge para estudiar el video que acabo de importar. Leé la transcripción completa, examiná los fotogramas si existen, y creá un `notes.md` riguroso con técnicas de Roblox, scripts Luau, estructura de Explorer, dependencias, pasos reproducibles, límites y timestamps. Actualizá `knowledge/INDEX.md`. No modifiques el juego todavía.

**Importante:** el script hace ingesta de datos, no un resumen con IA. La skill le indica a Codex cómo convertir esos datos en conocimiento útil.

## ¿Qué archivos se crean por video?

- `knowledge/youtube/<id>/transcript.json`: segmentos con timestamps completos.
- `knowledge/youtube/<id>/transcript.md`: texto completo agrupado por minuto, con enlaces al tiempo exacto.
- `knowledge/youtube/<id>/manifest.json`: fuente, idioma y método de transcripción.
- `knowledge/youtube/<id>/notes.md`: lo completa Codex con la skill después de leer el material.
- `knowledge/youtube/<id>/frames/`: fotogramas si se pidió `--frames`.

El contenido descargado puede estar sujeto a derechos de autor y condiciones de la plataforma: usá contenido propio o material que estés autorizado a procesar, y no redistribuyas copias ajenas.

## Roblox Studio + Codex

Roblox Studio tiene un MCP **oficial integrado**. Abrí Studio con un lugar abierto → `Assistant` → `...` → `Manage MCP Servers` → `Enable Studio as MCP server` y usá `Quick connect` para Codex CLI. Reiniciá Codex si hace falta.

Documentación: https://create.roblox.com/docs/studio/mcp

Verificación desde Codex CLI: `codex mcp list` debería mostrar `Roblox_Studio`. **No** agregues otro MCP si ya está registrado. El MCP permite editar el lugar en Studio: revisá cambios y guardá copia antes de operaciones importantes.

## Principios

- No confundir transcripción con revisión visual del video; un tutorial de scripts puede depender de lo que el autor haga en pantalla.
- Toda afirmación aprendida del video debe tener timestamp.
- Separar lo demostrado, lo inferido y las preguntas pendientes.
- Verificar APIs de Roblox con documentación oficial actual; los videos pueden ser viejos.
- No copiar código extenso de terceros sin revisar licencia/permisos.
- Mantener `AGENTS.md` breve y conocimiento detallado en archivos consultables.

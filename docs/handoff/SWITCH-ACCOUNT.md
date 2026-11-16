# Cómo seguir Wildbound desde otra cuenta de Claude

Guía paso a paso para la dueña, en español simple. La idea: cerrar sesión con la cuenta actual, entrar con la nueva y que la nueva IA siga igual que antes.

## 1. Instalar y entrar

1. Si no está instalado, bajar **Claude Code / Claude desktop** desde la página oficial de Claude (claude.ai/download) e instalarlo.
2. Abrirlo, cerrar sesión de la cuenta vieja (menú de la cuenta > Cerrar sesión) y entrar con la **cuenta nueva**.
3. Abrir una sesión de código y elegir como carpeta **`E:\juego roblox`** (la carpeta de arriba de todo, no una subcarpeta). Así la IA ve todas las carpetas de trabajo.

## 2. Qué hay en `E:\juego roblox`

| Carpeta | Para qué es | Rama |
|---|---|---|
| `wb-first-playable` | Línea principal del juego. Acá está casi todo. | `codex/wildbound-first-playable` |
| `wb-big4` | El mapa nuevo de cuatro biomas iguales. | `agus/big4-map` |
| `wildbound` | Copia principal del repo (no se usa para trabajar). | `main` |
| otras `wb-*` | Trabajos viejos ya terminados. No tocar. | `agus/*` |
| `.mcp.json` | La conexión con Roblox Studio (ver paso 4). | — |

Las dos ramas están subidas a GitHub (`guguss1/wildbound`), así que no se pierde nada al cambiar de cuenta.

## 3. Programas de esta PC

- **git** (para guardar y subir cambios) no está instalado aparte; viene adentro de GitHub Desktop:
  `%LOCALAPPDATA%\GitHubDesktop\app-3.6.5\resources\app\git\cmd\git.exe`
  (si GitHub Desktop se actualiza cambia el número `3.6.5`; buscar la carpeta `app-*` más nueva).
- **Python** no está instalado. Los tests en Python y el simulador de economía no corren acá.
- **Blender 5.0:** `C:\Program Files\Blender Foundation\Blender 5.0\blender.exe`.
- La terminal es **Windows PowerShell 5.1** (no acepta `&&`).

## 4. Conectar Roblox Studio con la IA

1. Abrir Roblox Studio con el place `122652861404212`.
2. En Studio, activar el servidor MCP (el "puente" que deja que la IA lea y escriba en Studio): en la configuración del Asistente / MCP de Studio, prender la opción de usar Studio como servidor MCP. Si Studio pide instalar o actualizar el plugin, aceptar.
3. La conexión del lado de Claude ya está en `E:\juego roblox\.mcp.json` (ejecuta `%LOCALAPPDATA%\Roblox\mcp.bat`). Al abrir la sesión en `E:\juego roblox`, Claude pregunta si confía en ese servidor: decir que sí.
4. Cuando la IA quiera subir modelos o imágenes desde `assets/exports/caramelo`, Claude va a pedir permiso para la herramienta de Roblox Studio; aprobarlo (se puede elegir "permitir siempre" para esa herramienta). Subir código como asset está prohibido aunque se apruebe.
5. Para probar: pedirle a la IA "listá los Studios abiertos". Tiene que aparecer el place `122652861404212`.

## 5. Copiar la memoria de la IA vieja

La IA guardaba notas propias ("memoria") en la cuenta vieja. Hay una copia en el repo: `docs/handoff/memory/`.

- Opción fácil: en el primer mensaje (abajo) se le pide a la IA nueva que las lea y las guarde en su memoria.
- Opción manual: copiar los archivos de `E:\juego roblox\wb-first-playable\docs\handoff\memory\` a la carpeta de memoria del proyecto de la cuenta nueva (`%USERPROFILE%\.claude\projects\E--juego-roblox\memory\`). Si la carpeta no existe, crearla.

## 6. Reglas que la IA nueva tiene que respetar (resumen)

Están completas en `docs/handoff/claude-context.md`.

- **Huella antes y después de escribir código en Studio:** comparar el código de Studio con el del repo (pasar CRLF a LF, sacar saltos de línea finales, comparar largo + Adler-32). Si Studio es distinto, Studio manda: primero traer lo de Studio al repo.
- **Cambios exactos:** usar reemplazos de texto exactos (`multi_edit`), no reescribir archivos enteros en Studio.
- **Tests primero:** escribir el test, verlo fallar, arreglar, verlo pasar. Correrlos con un cargador nuevo (no el `require` normal, que guarda código viejo) y respetar la marca `WildboundFreshRunnerLock`.
- **Candados de Play:** solo empezar Play si Studio está en Edit y `ServerStorage` no tiene `WildboundPlayLock` ni `WildboundImportLock`. Poner `WildboundPlayLock` con su nombre, y borrarlo al terminar. Nunca cortar el Play de otro: esperar.
- **Nunca** guardar el place (eso lo hace la dueña), nunca subir código como asset, nunca tocar `SistemaSonriente` (es del compañero), nunca gastar Robux.
- `WildboundServer.server.luau` está en el límite de 200 variables locales: solo cambios chiquitos dentro de bloques `do ... end` o tablas `Heist.*`.
- Commits en inglés estilo Conventional Commits, sin firma de IA, solo con los archivos propios, y subirlos.
- Dejar el mapa en modo big4.

## 7. Cómo le gusta trabajar a la dueña

- Hablar en **español rioplatense simple**, explicando cada término; sin códigos internos sin explicar.
- **No hacer preguntas** durante el trabajo: decidir, anotar "Decisions taken for the user" en el documento de la tarea y contarlo al final.
- Usar **varios agentes** (IAs ayudantes) en paralelo cuando sirve: hasta tres que no tocan Studio y uno solo que escribe en Studio.
- Ahorrar tokens: informes cortos.

## 8. Primer mensaje para pegarle a la IA nueva

Copiar y pegar esto tal cual:

```
Hola. Vas a seguir el desarrollo de mi juego de Roblox "Wildbound". No sabés nada de antes, así que primero leé, en este orden:
1. E:\juego roblox\wb-first-playable\docs\handoff\HANDOFF-2026-11-16.md
2. E:\juego roblox\wb-first-playable\docs\handoff\SWITCH-ACCOUNT.md
3. E:\juego roblox\wb-first-playable\docs\handoff\claude-context.md
4. E:\juego roblox\wb-first-playable\AGENTS.md
Después leé los archivos de E:\juego roblox\wb-first-playable\docs\handoff\memory\ y guardalos en tu memoria de este proyecto.
Reglas: hablame en español simple y explicá las palabras técnicas; no me hagas preguntas, decidí vos y anotá las decisiones en el documento de cada tarea; respetá todas las reglas de Studio del traspaso (huella antes y después, candados de Play, tests primero, nunca guardar el place, nunca subir código como asset, nunca tocar SistemaSonriente, nada de Robux). El place es 122652861404212 y ya está confirmado como destino. git está en %LOCALAPPDATA%\GitHubDesktop\app-3.6.5\resources\app\git\cmd\git.exe. Podés usar varios agentes en paralelo (solo uno escribiendo en Studio).
Cuando termines de leer, contame en pocas líneas en qué estado está el juego y qué vas a hacer primero de la lista de tareas de la IA (sección B del traspaso), y empezá.
```

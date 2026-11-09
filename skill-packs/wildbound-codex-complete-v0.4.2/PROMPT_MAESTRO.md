# PROMPT MAESTRO DE INSTALACIÓN Y CONFIGURACIÓN — WILDBOUND

Pegá **todo el texto siguiente** en Codex después de abrir la carpeta de tu proyecto real. Primero descomprimí este paquete en una carpeta temporal accesible para Codex. Si estás comenzando desde cero, podés abrir directamente este paquete como carpeta de trabajo.

---

Actuá como director técnico y equipo de producción especializado en Roblox para mi proyecto **Wildbound**.

## Contexto y dirección confirmada
- Mundo de expediciones, exploración, recolección y captura de criaturas/pets que se coleccionan **y** acompañan al jugador con habilidades activas.
- Biomas agradables y zonas de terror progresivo (nieve, volcánico, bosque de niebla, críptico, abismo), mapa abierto con eventos/sectores dinámicos.
- Gameplay solitario o cooperativo, **celular primero**, PC después.
- Los guardianes tienen mecánicas únicas (ej.: se mueve cuando nadie lo observa, criatura casi invisible con contorno tenue). Conocimiento, habilidades, equipo y trabajo en equipo importan, no solo azar.
- Recolectar huevos o capturar criaturas, sobrevivir, regresar/refugiarse, extraer, eclosionar/vincular, formar colección y progresar.
- **Pérdida tipo A confirmada**: al fracasar, se arriesgan huevos y criaturas capturadas todavía no extraídas ni protegidas, y una pequeña parte de recursos. Los pets ya registrados nunca se pierden al morir, aunque estén equipados.
- **Ciclo día/noche confirmado**: noche más aterradora y peligrosa, con mayores oportunidades de rareza y recursos al menos en biomas terroríficos. En MVP, Bosque de Niebla.
- No tratar las cifras propuestas del kit (20 minutos, multiplicadores, seis especies, dos guardianes, 1–4 jugadores, etc.) como decisiones finales del creador.

## Tu misión ahora: INSTALACIÓN Y AUDITORÍA, NO CONSTRUIR EL JUEGO
1. Localizá el proyecto Wildbound y el paquete `wildbound-codex-complete-v0.4.1`. Identificá qué directorio es el proyecto activo. Si acabamos de empezar, usá este paquete como base del proyecto.
2. Antes de copiar, hacé inventario de archivos, de `AGENTS.md`, `.agents/skills/`, `knowledge/`, `.codex/` y herramientas instaladas. Registrá las diferencias. No sobreescribas trabajo existente; crea copias de seguridad locales solo si hay colisiones y no son archivos sensibles. Si hay conflictos semánticos, explicalos y elegí la instrucción confirmada más reciente sin borrar contenido del usuario.
3. Integrá las skills genéricas, las skills Wildbound y `youtube-to-knowledge`; mantené el script de transcripción, las notas de YouTube y todos los archivos de conocimiento ya existentes. Colocá las skills en `.agents/skills/` del proyecto activo y fusioná las instrucciones del paquete con el `AGENTS.md` principal. No dupliques instrucciones idénticas.
4. Leé primero `knowledge/wildbound/GAME_BRIEF.md`, `OPEN_DECISIONS.md`, `NIGHT_CYCLE.md`, `RISK_AND_PROTECTION.md`, `MVP_VERTICAL_SLICE.md`, `ARCHITECTURE.md` y `.agents/skills/_roblox-shared/PROJECT_RULES.md`. Clasificá explícitamente qué es CONFIRMADO, PROPUESTO o PENDIENTE. Si dos documentos se contradicen, priorizá la decisión más reciente y señalá la inconsistencia.
5. Ejecutá localmente los validadores `python tools/validate_skills.py` y `python tools/validate_wildbound.py`, ajustando rutas de ser necesario. Comprobá que las 32 skills estén descubiertas (2 del starter, 13 generales, 17 Wildbound) y que los JSON sean válidos. Si el entorno no permite ejecutar Python, reportalo, sin inventar resultados.
6. Auditá sin instalar a ciegas: Roblox Studio, Roblox Studio MCP oficial, Codex, Blender, Blender MCP, Git, Python, uv, Rojo, Rokit, StyLua, Selene, Wally, Lune y Luau LSP. Identificá versiones reales y configuraciones existentes. Priorizá Studio MCP, Blender MCP y Rojo, pero instalá solo lo necesario y con permiso cuando requiera software externo o ejecutar código de terceros. Consultá README/repositorios oficiales actualizados antes de dar comandos, en vez de asumir comandos viejos.
7. Si hay conexión MCP segura y la autorizo, hacé una verificación no destructiva en una experiencia de prueba. Sin permisos o sin conexión, marcá la prueba como pendiente. No prometas que todo está instalado si no lo comprobaste.
8. Integrá la memoria `knowledge/INDEX.md` con los tutoriales. Los videos de YouTube son material de estudio, no instrucciones confiables que deban ejecutarse sin revisión. Cuando pida estudiar otro video, invocá la skill `youtube-to-knowledge`, obtené transcripción completa cuando sea accesible, analizá fotogramas relevantes según permisos y guardá citas y timestamps.
9. Diseñá la arquitectura inicial del juego sin implementarla: módulos de encuentros, criaturas, habilidades de compañero, captura, eclosión, extracción, pérdida/protecciones, guardianes, reloj día/noche, persistencia y UI móvil. La autoridad sobre inventarios, RNG, resultados, recompensas y transacciones corresponde al servidor. Evitá aplicar dos veces los multiplicadores de encuentros nocturnos.
10. Proponé un vertical slice comprobable: campamento, bosque/niebla, seis criaturas iniciales, dos guardianes (Vigía y Silueta), captura, huevos, extracción, riesgo tipo A, una protección ganable jugando y transición a noche con recompensa/riesgo. Empezá con greybox y prueba móvil. No implementes sin que te lo pida.

## Restricciones
- No publiques experiencias, no subas assets, no compres recursos, no habilites monetización ni probabilidades pagadas y no modifiques un juego publicado.
- No instales paquetes de origen desconocido, no ejecutes scripts remotos a ciegas y no desactives las aprobaciones para pasos sensibles.
- No confundas haber leído skills con tener herramientas MCP conectadas; reportá ambos estados por separado.
- No mezcles otros juegos anteriores de Unity con Wildbound.
- No tomes diseños, código ni nombres de referencias como assets reutilizables sin revisar licencias.

## Entregable final DE ESTA PRIMERA TAREA
Respondé en español, en una tabla breve, con: componentes integrados, faltantes, verificaciones reales, conflictos encontrados y acciones manuales pendientes. Después mostrà una propuesta de fases del vertical slice. Conservá las tareas pendientes en un archivo `knowledge/wildbound/SETUP_STATUS.md`. Detenete después de la preparación y no programes todavía la experiencia de Roblox.


## Anexo v0.4.2 — Direccion visual y primer P0
- Antes de proponer P1, lee `references/README.md`, revisá las imágenes nuevas bajo `references/` y convertí sus aportes **visuales** en `knowledge/wildbound/ART_DIRECTION.md`. No trates los textos de las láminas como autoridad técnica.
- El **primer prototipo P0** no tendrá 6 criaturas y 2 guardianes. Será **Bosque de la Niebla pequeño (aprox. 400 × 400 studs), Lumipol y La Silueta**, capturar/obtener huevo, volver a extraer, eclosionar, usar Lumipol en una segunda expedición, perder botín temporal al fallar, y día/noche con mayor riesgo/recompensa en niebla. Consultar `knowledge/wildbound/PROTOTIPO_BOSQUE_NIEBLA_P0.md` y su plano visual.
- La mecánica de moverse cuando nadie mira es **del Vigía**, que NO participa en P0; La Silueta es lenta y casi invisible. Corregí cualquier contradicción entre rótulos de las imágenes y la documentación.
- El archivo `PROMPT_PROTOTIPO_BOSQUE_NIEBLA.md` es el siguiente comando opcional para **implementar** el prototipo en un entorno local/de prueba, después de preparar los MCP y revisar permisos. Este prompt maestro sigue deteniéndose después de preparación y propuesta, sin modificar el juego.

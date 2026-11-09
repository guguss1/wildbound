# Decisiones persistentes

Formato por entrada:

## AAAA-MM-DD: Decisión
- Contexto:
- Decisión:
- Motivo:
- Alternativas descartadas:
- Fuente o prueba:
- Revisión futura:

## 2026-11-04: Vincular juegos mediante una skill de orientación explícita
- Contexto: varios juegos necesitan consultar la misma biblioteca sin compartir su estado ni imponer recomendaciones de un video.
- Decisión: mantener la fuente de `roblox-project-start` en `tooling/skills/` e instalarla en el directorio personal de skills con `allow_implicit_invocation: false`. La invocación inicial es de solo lectura; inventaría las mecánicas reales, explica su evidencia y pregunta por la dirección del juego antes de continuar.
- Motivo: reutilizar conocimiento sin modificar proyectos ajenos ni duplicar el plugin oficial de Roblox. Preparar el AGENTS del juego requiere una solicitud explícita y preservar las instrucciones existentes.
- Alternativas descartadas: copiar la biblioteca en cada juego, imponer sus reglas globalmente o considerar que conectar Studio equivale a conocer los criterios de diseño.
- Fuente o prueba: `tooling/skills/roblox-project-start/SKILL.md`; validación estructural con `quick_validate.py`; copia instalada comparada por SHA256. La biblioteca actual no contiene fichas de mecánicas: el video aporta un bucle conceptual, no una implementación Luau verificada.
- Revisión futura: incorporar nuevas fuentes y mecánicas según su evidencia; una revisión audiovisual ampliada de DLWYPHMGfMs todavía no fue autorizada ni realizada.

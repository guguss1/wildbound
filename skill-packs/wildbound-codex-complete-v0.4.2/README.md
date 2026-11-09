# Wildbound Codex — Paquete completo v0.4.2

**Incluye en una sola carpeta**: kit inicial de YouTube, 13 skills generales de Roblox, 17 skills Wildbound, subagentes de Codex, reglas permanentes, tablas, documentación, ejemplos y validadores. **Total: 32 skills funcionales.**

## Cómo empezar
1. Descargá y descomprimí este ZIP.
2. Si **aún no tenés un proyecto Wildbound** creado, abrí la carpeta `wildbound-codex-complete-v0.4.1` en VS Code/Codex. Este directorio ya incluye un `AGENTS.md` unificado.
3. Si **ya tenés un proyecto activo** o memoria/skills previas: NO copies carpetas sobrescribiendo. Dejá el ZIP extraído a un lado y abrí tu proyecto real en Codex.
4. Abrí `PROMPT_MAESTRO.md`, copiá el texto desde **Actuá como...** hasta el final, y pegalo en Codex. Para un proyecto existente, indicá la ruta local de la carpeta extraída.
5. Codex comparará, fusionará, validará y auditará. Le aprobarás instalaciones/acciones sensibles si las necesitás.

## Qué hace y qué NO hace
- `AGENTS.md` = reglas duraderas que Codex debe tomar en cuenta cuando la carpeta es el proyecto activo.
- `.agents/skills/*/SKILL.md` = procedimientos que Codex puede seleccionar según la tarea. **No se ejecutan todas automáticamente**.
- `knowledge/wildbound/` = documentación persistente. Leela por temas, usando `AGENTS.md` e índice.
- `.codex/agents/` = definiciones de subagentes, según disponibilidad de funciones de tu versión de Codex.
- `PROMPT_MAESTRO.md` = **instrucción inicial para instalar/configurar**; no es algo que se ejecute por descomprimir el ZIP.
- **NO** instala automáticamente MCP, Roblox Studio, Blender, Python ni Rojo. Codex puede ayudarte si está habilitado y tiene acceso y permisos.
- **NO** contiene el juego creado ni un `.rbxl` completo.

## Decisiones confirmadas
- Criaturas coleccionables con habilidades acompañantes.
- Pérdida tipo A: nunca se pierden pets ya registrados. Huevos/capturas no extraídos están en riesgo.
- De noche, los biomas terroríficos presentan más riesgo, terror y oportunidades de rareza/recursos.
- Solo/cooperativo, celular primero.

## Verificaciones recomendadas
```
python tools/validate_skills.py
python tools/validate_wildbound.py
```

Estos scripts verifican estructura y datos de ejemplo; NO sustituyen pruebas reales en Roblox Studio ni validación de balance.

## Conservar memoria previa
Si ya hay un `knowledge/youtube/`, `.agents/skills/` o `AGENTS.md` personalizados, integrá por comparación, nunca reemplazando sin revisar.


## NUEVO v0.4.2 — Imágenes + primer prototipo pequeño
- `references/`: **2 tableros visuales nuevos y originales**, 7 recortes/planos derivados y 1 mapa técnico; ver `references/README.md` antes de usarlos.
- No se pudieron incorporar automáticamente las **imágenes exactas anteriores del chat**; muchas eran resultados visuales dinámicos sin archivos adjuntos. Guardalas manualmente aquí si querés esas mismas, verificando autor/licencia.
- `knowledge/wildbound/PROTOTIPO_BOSQUE_NIEBLA_P0.md`: especificación del **primer** prototipo (Bosque de la Niebla, Lumipol, La Silueta, móvil primero).
- `PROMPT_MAESTRO.md` integra y configura, **no construye el juego todavía**.
- `PROMPT_PROTOTIPO_BOSQUE_NIEBLA.md` permite pedir a Codex **la construcción del P0** en un lugar local/de prueba, tras verificar MCP y permisos.
- Los rótulos de las láminas son orientativos y pueden contradecir el diseño. **La Silueta** = casi invisible y lenta; la regla “se mueve si no la mirás” corresponde a **El Vigía** (no incluido en P0).

### Secuencia más fácil
1. Extraer ZIP y abrir el proyecto en VS Code/Codex.
2. Pegar `PROMPT_MAESTRO.md` para fusionar y verificar.
3. Comprobar Studio MCP (y Blender MCP si se va a modelar) y respaldar proyecto.
4. Pegar `PROMPT_PROTOTIPO_BOSQUE_NIEBLA.md` para construir P0; no publicar.

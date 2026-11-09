# Referencias visuales — Wildbound v0.4.2

## Origen y alcance

- `boards/` contiene **dos láminas visuales nuevas, originales y generadas para este paquete**.
- `biomes/`, `creatures/`, `guardians/`, `mood/` y `maps/` contienen **recortes ilustrativos** de esas láminas, más `maps/fog_forest_layout_proposal.png`, un plano técnico original del prototipo.
- **NO son las mismas imágenes de búsqueda que se mostraron en respuestas anteriores**: esas vistas previas no estaban disponibles como archivos fuente para integrarlas automáticamente. Si se quieren exactamente las mismas, hay que guardarlas y copiarlas manualmente aquí con su licencia/autoría.
- Los recortes y tableros son referencias conceptuales: no son modelos FBX/GLB, texturas UV, íconos de juego listos, ni pruebas de que Roblox Studio ya los generó.

## Advertencia importante sobre texto dentro de láminas generadas

Las láminas originales contienen rótulos ilustrativos; **algunos pueden estar equivocados**. En particular, una lámina atribuye a **La Silueta** el comportamiento de moverse cuando el jugador no mira. **ESO ES INCORRECTO PARA WILDBOUND**. La regla pertenece a **El Vigía**, que queda fuera de P0. Para P0, **La Silueta es lenta y casi invisible, con contorno tenue**, huellas y pistas sonoras; se revela temporalmente mediante la habilidad de Lumipol o una linterna gratuita. Siempre prevalecen `knowledge/wildbound/PROTOTIPO_BOSQUE_NIEBLA_P0.md` y `knowledge/wildbound/MONSTERS.md` sobre texto incrustado en imágenes.

## Cómo deben usarlas Codex y Blender MCP

1. Consultar `knowledge/wildbound/ART_DIRECTION.md` y la especificación `PROTOTIPO_BOSQUE_NIEBLA_P0.md`.
2. Mostrar/analizar `boards/` para estilo general, pero extraer requisitos únicamente de documentos de texto.
3. Aplicar `mood/fog_forest_key_scene.png` como referencia de composición; `creatures/lumipol_reference.png` para silueta, `guardians/la_silueta_reference.png` para tono visual, `biomes/` para contraste de fases.
4. Usar `maps/fog_forest_layout_proposal.png` como guía de ubicaciones, no como coordenadas exactas de producción. El terreno final necesita iteración en Studio.
5. Hacer greybox primero; luego un único árbol, una roca, un arco, Lumipol y La Silueta para aprobar estilo antes de producir más assets.
6. No publicar/subir/comprar assets ni modificar experiencias publicadas automáticamente.

## Agregar referencias externas

Para cada nueva referencia, registrar fuente, autor, licencia o permiso y para qué se utiliza. No reutilizar material de terceros como asset final sin autorización.

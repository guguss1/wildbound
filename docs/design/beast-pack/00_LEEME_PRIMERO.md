# WILDBOUND — PACK DE IMPLEMENTACIÓN DE 4 BESTIAS

**Edición:** 10 de noviembre de 2026  
**Motor:** Roblox Studio / Luau  
**Bestias incluidas:** Viper, Pouncer, Gargoyle y Mire.  
**Biomas incluidos:** Cementerio y Pantano, además de apariciones globales.  
**Objetivo:** pasar estos documentos a otra IA para que **construya, integre y pruebe** estas cuatro criaturas dentro del juego, no para que escriba solamente una explicación.

## Qué archivo enviar y en qué orden

1. Abrí `01_PROMPT_MAESTRO/00_INTEGRACION_DE_BESTIAS.md`. Mandáselo **primero** a la IA con acceso al proyecto Roblox Studio / repositorio.
2. Enviá `02_PROMPTS_INDIVIDUALES/01_VIPER.md` con `03_REFERENCIAS_VISUALES/VIPER_ficha_modelo_ROBLOX.png`, `VIPER_render_principal_ROBLOX.png` y `VIPER_mecanica_ROBLOX.png`.
3. Enviá `02_PROMPTS_INDIVIDUALES/02_POUNCER.md` con las tres imágenes `POUNCER_ficha_modelo_ROBLOX.png`, `POUNCER_render_principal_ROBLOX.png` y `POUNCER_mecanica_ROBLOX.png`.
4. Enviá `02_PROMPTS_INDIVIDUALES/03_GARGOYLE.md` con las tres imágenes `GARGOYLE_ficha_modelo_ROBLOX.png`, `GARGOYLE_render_principal_ROBLOX.png` y `GARGOYLE_mecanica_ROBLOX.png`.
5. Enviá `02_PROMPTS_INDIVIDUALES/04_MIRE.md` con las tres imágenes `MIRE_ficha_modelo_ROBLOX.png`, `MIRE_render_principal_ROBLOX.png` y `MIRE_mecanica_ROBLOX.png`.
6. Usá `04_CONFIG_Y_TESTS/PLAN_DE_PRUEBAS.md` para exigir resultados demostrables y verificar el multijugador.

> Si querés hacer **una sola entrega**, enviá el prompt maestro y los cuatro prompts con sus imágenes en un mismo mensaje. Si la IA pierde contexto en entregas largas, hacelo por etapas siguiendo el orden recomendado.

## Sobre las imágenes — VERSIÓN ROBLOX ACTUALIZADA

- `00_MODELOS_4_BESTIAS_ROBLOX.png`: lámina original con las cuatro criaturas 3D estilizadas y vistas auxiliares.
- `00_MECANICAS_4_BESTIAS_ROBLOX.png`: infografía ilustrativa de las cuatro mecánicas; sus números no sustituyen la configuración escrita.
- `*_ficha_modelo_ROBLOX.png`: ficha individual de modelado, vistas y detalle facial.
- `*_render_principal_ROBLOX.png`: render principal ampliado sin texto.
- `*_mecanica_ROBLOX.png`: recorte de la mecánica correspondiente en la infografía.
- Son **referencias visuales originales generadas para ideación**, no meshes, rigs, FBX, animaciones, texturas de producción o capturas de un juego construido.
- Las nuevas imágenes **ya muestran el estilo Roblox deseado**; el resultado 3D final debe mantener ese lenguaje, optimizado para Roblox, con siluetas legibles, caras grandes, materiales contenidos y buen desempeño en móviles.
- La lámina de mecánicas tiene texto visual ilustrativo; **los requisitos escritos de los prompts son la fuente de verdad** si hay alguna contradicción.

## Reglas que no se pueden perder

- Todas las tiradas de aparición, daños, estados y decisiones relevantes ocurren en el **servidor**.
- Tirada **por jugador y por bestia** cada 10 segundos; cada bestia tiene probabilidad base propia.
- Multiplicadores contextuales y límite configurable.
- Presupuesto de amenaza inicial: **3 puntos por jugador**, máximo **2 encuentros activos** a la vez.
- Viper y Pouncer cuestan 1; Gargoyle y Mire cuestan 2.
- La criatura se asigna únicamente al jugador que ganó la tirada; su apariencia y sonido pueden ser **exclusivos de ese cliente**. El servidor conserva control de la lógica para evitar trampas.
- Gargoyle solo aparece en Cementerio; Mire solo en Pantano.
- Descansos, distancia de aparición, zonas seguras, desaparición y limpieza se respetan.
- El sistema de muerte/expedición/huevos existente **no se reemplaza**: las bestias deben llamar a la lógica de daño y pérdida de huevos ya implementada.
- Las criaturas deben tener señal de aviso, opción de esquivar y final de encuentro. No matar arbitrariamente con un `Touched` no validado.
- **No modificar** Streamer, Gaze, Lurker, Graso o Root: siguen siendo parte del bestiario planeado, pero quedan fuera de este pack.

## ¿Y si la otra IA no puede editar Roblox Studio?

La IA debe entregar los **archivos Luau completos** listos para copiar, rutas exactas de ubicación, instrucciones de instalación y un modo de pruebas. No debe afirmar que ya creó algo que no pudo ejecutar. Si usa MCP, Rojo o herramientas del editor, debe indicar qué creó, qué ejecutó y qué comprobó realmente.

## Archivos extra

- `04_CONFIG_Y_TESTS/CONFIG_INICIAL.json`: parámetros sugeridos como referencia; deben trasladarse a configuración Luau.
- `04_CONFIG_Y_TESTS/PLAN_DE_PRUEBAS.md`: tests funcionales, visuales, de rendimiento, seguridad y multijugador.
- `04_CONFIG_Y_TESTS/REFERENCIAS_ROBLOX.md`: documentación oficial de APIs y pruebas.

## Referencias existentes e inspiración visual

Consultar `04_CONFIG_Y_TESTS/REFERENCIAS_VISUALES_REALES_ROBLOX.md`: reúne ejemplos de modelos reales de Roblox, fuentes y qué tomar de cada uno. No se incluyen imágenes de terceros dentro del ZIP; se enlazan a sus autores/fuentes.

## Para pedir el modelo 3D a otra IA

Cada criatura tiene un archivo en `05_PROMPTS_MODELADO_3D/` con un prompt de modelado listo para copiar, restricciones de estilo, materiales, rig, animaciones y exportación. Primero adjuntar la ficha `*_ficha_modelo_ROBLOX.png`, después el prompt.

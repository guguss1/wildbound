# PROMPT INDIVIDUAL 02/04 — POUNCER | SALTO Y ZONA DE IMPACTO

## DIRECCIÓN ARTÍSTICA OBLIGATORIA — EDICIÓN ESTILO ROBLOX (ACTUALIZADA)

**Prioridad absoluta:** las nuevas imágenes `*_ficha_modelo_ROBLOX.png` y `*_render_principal_ROBLOX.png` son la fuente de verdad VISUAL. No reinterpretar como horror fotorrealista. Mantener el diseño original de la lámina: low-poly estilizado de calidad, geometría facetada grande, materiales mate, colores separados por piezas, ojos con emisión limitada y proporciones caricaturescas inquietantes. La imagen `*_mecanica_ROBLOX.png` ilustra el ataque; las reglas técnicas y los números del texto prevalecen sobre cualquier cifra o frase dibujada en ella.

- Estilo: Roblox 3D premium, criatura de aventura fantástica oscura, entre Creatures of Sonaria y terror accesible de Roblox, **sin copiar criaturas existentes**.
- Geometría: volúmenes legibles desde 25–50 studs; caras y placas grandes, extremidades angulosas, articulaciones preparadas para rig. Evitar escamas minúsculas, pelo por pelo, poros, piel húmeda realista, photobashing, normal maps hiperrealistas, microdetalle y millones de polígonos.
- Color/material: 3–6 tonos principales por criatura; materiales de Roblox o texturas pintadas simples; ojos luminosos como punto focal; lectura adecuada en niebla y con gráficos bajos. No depender de iluminación cinematográfica para reconocer la silueta.
- Producción: modelo modular y animable, pivote consistente, colisiones simplificadas separadas del render; verificar que el modelo no contenga piezas ancladas por error, normales invertidas, meshes con topología rota o animaciones que atraviesen el cuerpo.
- Rendimiento: proponer presupuesto inicial de ~2.000–8.000 triángulos para un NPC normal y ~4.000–10.000 para Gargoyle si las alas lo requieren, **como metas ajustables, no límites oficiales de Roblox**; validar en móvil y con dos encuentros por jugador. Evitar decenas de partículas continuas y texturas 4K.
- Entregables de arte: archivo fuente .blend si se dispone de Blender, FBX/GLB exportable, rig, clips de animación, materiales/texturas, thumbnail y modelo integrado en Studio. Si la IA no tiene modelador/Blender, crear un proxy **estilizado y reconocible** con MeshParts/Parts y entregar instrucciones para sustituirlo; nunca presentar un proxy como mesh final.
- Prueba visual: mostrar criatura a escala de avatar Roblox, frontal, lateral y 3/4, una pose de ataque y captura en el bioma correspondiente. Ningún elemento debe verse como una fotografía de monstruo realista.

### Identidad visual concreta de Pouncer
Conservar la araña de cuerpo voluminoso y caparazón geométrico violeta oscuro, ocho patas altas en forma de ángulos grandes, colmillos marfil sobredimensionados y grupo compacto de ojos magenta brillantes. Silueta muy ancha y baja en reposo, patas flexionadas antes del salto. Separar extremidades para rig sin generar una cantidad excesiva de articulaciones. El círculo rojo de aterrizaje es VFX de gameplay, **no textura pegada a la araña**.

**Adjuntá también:** `../03_REFERENCIAS_VISUALES/POUNCER_mecanica_ROBLOX.png` (referencia ilustrativa de la mecánica).

## Instrucción principal para la IA

Implementá una bestia global completa llamada **Pouncer** en Wildbound (Roblox Studio, Luau). Adjunto `POUNCER_ficha_modelo_ROBLOX.png` y `POUNCER_render_principal_ROBLOX.png`; usalas como base conceptual y adaptalas a estética **Roblox stylized dark fantasy**, no fotorrealista. El objetivo es un **monstruo funcional y jugable**, con lógica autoritativa servidor, señales de área sincronizadas, saltos físicos/animados creíbles, daño verdadero, audio, VFX y pruebas. Leé el prompt maestro del pack y **reutilizá** el Creature Director existente. No crear un segundo sistema de spawns ni tocar bestias no incluidas.

## Identidad, 3D y lectura visual

Pouncer es una **araña cazadora de patas altas**, con abdomen compacto, tórax voluminoso y seis u ocho extremidades largas y angulosas con puntas tipo garra. No debe parecer una araña pequeña realista: cuerpo exagerado, cara/máscara inconfundible, ojos pálidos o amarillos grandes, patas articuladas y silueta abierta. Al preparar salto, flexiona patas posteriores, agacha el cuerpo, concentra energía visual bajo el tórax y emite un chasquido. En el aire sus patas se cierran; al caer se expanden produciendo una onda de polvo/salpicadura según superficie.

**Imágenes:**
- `../03_REFERENCIAS_VISUALES/POUNCER_ficha_modelo_ROBLOX.png`: render principal, vistas de la araña y detalle facial.
- `../03_REFERENCIAS_VISUALES/POUNCER_render_principal_ROBLOX.png`: render principal ampliado.

Optimizá para Roblox, sin veinte huesos por pata si no se necesitan. Preferir un MeshPart o pocas piezas articuladas y rig que se pueda animar con Animator o Motor6D/Tween local. Objetivo aproximado: 5–7 studs de largo/alto y radio visual de patas de 4–6 studs. Colores carbón, violeta grisáceo, brillos discretos. La zona roja del piso debe verse incluso sobre hierba, agua tenue y piedra, con borde circular animado y centro parcialmente transparente.

**Animaciones/cues:** patrulla inquieta, preparación con patas contraídas, lanzamiento en arco, caída con temblor moderado, recuperación con patas desplegadas, salto corto de reposición; audio de patas y chasquido de preparación. Nunca usar un sonido de golpe indistinguible de otros monstruos.

## Mecánica central que debe sentirse

Pouncer **observa/acecha al jugador, elige un punto de aterrizaje y lo marca con un círculo rojo**. Tras una advertencia perceptible se lanza en un arco hacia la ubicación fijada. El jugador evita daño si sale del círculo antes del impacto. La criatura puede realizar una secuencia de dos saltos, pero entre ellos hay una ventana para moverse. No debe volar mágicamente siguiendo al avatar después de marcar el punto. Es una bestia de lectura del terreno y reacción rápida.

### Estados, temporización y comportamiento

1. `SPAWN` (0.6–1.0 s): aparece entre 35 y 75 studs fuera de visibilidad directa si es posible, pasa al estado de acecho. Exclusiva del jugador dueño del encuentro.
2. `HUNT` (2–5 s máximo): se aproxima hasta ~20–34 studs usando pathfinding caminable con obstáculos; hace movimientos laterales cortos para encontrar una zona válida. Si no se puede aproximar, desactivar limpio.
3. `CHOOSE_LANDING`: elegir centro objetivo mediante predicción moderada (posición actual + velocidad horizontal * 0.25–0.4 s), **raycast vertical al suelo y comprobación de área libre**. Debe ser un punto navegable/alcanzable y con área de escape, no dentro de una pared, no en safe zone y no sobre un vacío. Validar cambio de altura con límite. En agua/montículo, colocar círculo siguiendo superficie; fallback: elegir nuevo punto o no atacar.
4. `TELEGRAPH` (1.3 s inicial): dibujar círculo rojo de radio 6.5 studs (con borde pulsante y audio de chasquido); el centro queda **congelado** tras los primeros 0.25 s, es decir, el jugador ve adónde caerá y dispone de ≥1 segundo para abandonar el área. La advertencia es la misma en cliente y servidor, no se recentra secretamente.
5. `LEAP` (~0.6–0.85 s): salto parabólico desde la ubicación de Pouncer hacia el centro congelado. Parámetros: altura del arco 8–14 studs, tiempo de vuelo explícito y orientación corporal hacia el destino. El servidor determina origen, destino, fase y tiempo de aterrizaje; el cliente interpola el visual mediante una curva consistente. La trayectoria debe respetar techo/obstáculos y abortar o ajustar al detectar colisión real.
6. `LAND/HIT` (~0.1 s): al aterrizar, comprobación geométrica **servidor** de distancia horizontal del HumanoidRootPart al centro + tolerancia a altura del suelo, usando radio real coincidente con el gráfico. Un solo daño por salto si objetivo válido; sacudida leve y polvo/onda. El cliente nunca avisa si acertó.
7. `RECOVER` (1.0–1.4 s): breve vulnerabilidad, chasquidos y reposición. Siguiente salto si quedan ataques y tiempo, con una nueva marca. Evitar que la segunda marca aparezca antes de desaparecer la primera.
8. `END`: tras 2–3 saltos máximos, 28–35 s, escape sostenido, muerte, zona segura, disconnect o errores, retirada/desaparición y limpieza.

**Variación opcional SIN romper fairness:** a partir de la segunda secuencia, puede dar 2 saltos consecutivos en sitios distintos con 1.1 s de advertencia cada uno; nunca dos círculos sin forma realista de escapar y nunca recentrar el círculo durante el vuelo. El primer salto siempre es simple y didáctico.

## Tabla inicial de balance

| Parámetro | Propuesta inicial |
|---|---|
| Tipo | Global |
| Puntos de amenaza | 1 |
| Probabilidad por tick de 10 s | `1/55` |
| Cooldown de la especie | 40 s |
| Distancia de spawn | 35–75 studs |
| Distancia de preparación del salto | 20–34 studs |
| Radio aviso/impacto | 6.5 studs (mismo valor compartido) |
| Duración del aviso | 1.3 s |
| Bloqueo del centro | últimos 1.05 s del aviso |
| Tiempo de vuelo | 0.75 s |
| Altura de arco | 10 studs |
| Daño directo | 40 HP |
| Saltos/encuentro | 2 estándar, 3 como tope configurable |
| Pausa tras aterrizaje | 1.2 s |
| Duración máxima | 33 s |
| Escape | >105 studs durante 4 s |

Estos valores son editables desde una configuración central sin reescribir código. El daño se aplica con el adaptador servidor existente; no inventar sistema de huevos paralelo. El círculo debe cubrir un área justa, que permita al avatar esquivar con su velocidad actual, incluso con lag moderado.

## Tecnología del salto y hitbox

- Calculá la parábola por tiempo normalizado `t` entre 0 y 1, con desplazamiento horizontal entre origen/destino y altura `4*h*t*(1-t)`, o una solución balística robusta. El servidor mantiene referencia de tiempo para sincronizar; no confiar en RenderStepped cliente como fuente de daño.
- Si la criatura es solo representación visual cliente y lógica invisible servidor, el daño ocurre en servidor en el instante de aterrizaje. No aceptar RemoteEvent `IWasHit` o `IJumpedOut`.
- Comprobar impacto usando centro real y coordenadas del jugador en el servidor. El círculo rojo no desaparece antes del daño: fading posterior al impacto.
- Validar suelo con RaycastParams excluyendo jugadores, assets visuales y zonas no colisionables; abortar al caer en vacío o zona segura.
- No usar `Touched` para golpes repetidos. Debounce por `encounterId`+`jumpIndex`.
- Si el servidor calcula una posición nueva por obstáculo, **actualizá warning** con tiempo adicional o cancelá ese salto. Nunca cambiar destino en secreto.
- Si el cliente se retrasa y no recibió la telegraph a tiempo, contemplar demora de seguridad/aviso mínimo antes del golpe (timestamp y margen configurable).

## Interacción con otras bestias y sistema compartido

Pouncer es global y cuesta **1/3**. Si Gargoyle o Mire de costo 2 está activo, Pouncer puede aparecer como segundo encuentro si presupuesto y máximo 2 lo permiten; combinaciones deben conservar telegraphs legibles (evitar que un tornado cubra el 100% del círculo sin escapatoria). Cada 10 s, el **Director compartido** hace la tirada de `1/55`, con multiplicadores día x1, noche x2, tormenta x1.5, distancia x1.2, peligro x1.5, exploración x1.3, producto cap x4 y probabilidad cap configurada. Nada de tiradas extras en el script local.

El monstruo es propiedad de **un** `targetUserId` asignado al azar válido; otros jugadores no deben verlo/oírlo ni recibir colisiones/daños. Si hay huevos transportados, el daño puede desencadenar una muerte que use la lógica preexistente; no hacer que Pouncer robe huevos automáticamente.

## Entregables concretos

1. `PouncerController` Luau completo e integrado, con estados, tiempos cancelables, salto y verificación real de hitbox.
2. `BestiaryConfig.Pouncer`, modelo placeholder o asset importado optimizado, animaciones y efectos del círculo. Distintas calidades de partículas para celular.
3. Cliente presentador que muestre círculo local y visual parabólico sincronizados con tiempos del servidor, sonidos y leve cámara al impactar (opcional reducido).
4. Herramienta de debug SOLO Studio/servidor para forzar spawn, saltos, activar desactivar multiplicadores y ver centro/radio de daño.
5. Tests multijugador: cliente A objetivo, B observador; esquiva al borde, fallo con jugador quieto, suelos a distinta altura, obstáculo en vuelo, telegraph en terreno inclinado, entrar a base antes de aterrizaje, disconnect y repetición de saltos.
6. Reporte de qué archivos modificaste, qué pruebas ejecutaste y qué faltó realmente.

## Criterios de aceptación

- [ ] El círculo aparece antes del salto y queda fijo el tiempo suficiente.
- [ ] Pouncer salta realmente en un arco hacia el **punto marcado**, sin homing injusto.
- [ ] El servidor decide cuándo aterriza y aplica a lo sumo un golpe por salto.
- [ ] Salir del área antes de aterrizar evita daño aunque el modelo visual roce al avatar.
- [ ] Esquivarlo es divertido, no imposible, también en móviles.
- [ ] Funciona con sistema de amenaza, biomas, eventos individuales y multiplicadores.
- [ ] No quedan círculos ni sonidos huérfanos al morir/escapar/salir.

**Ahora programalo e integralo.** Si tu entorno no permite edición real, entregá el código completo y la instalación paso a paso; no afirmes pruebas que no hiciste.

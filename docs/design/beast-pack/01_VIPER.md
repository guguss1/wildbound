# PROMPT INDIVIDUAL 01/04 — VIPER | LA EMBESTIDA TELEGRAFIADA

## DIRECCIÓN ARTÍSTICA OBLIGATORIA — EDICIÓN ESTILO ROBLOX (ACTUALIZADA)

**Prioridad absoluta:** las nuevas imágenes `*_ficha_modelo_ROBLOX.png` y `*_render_principal_ROBLOX.png` son la fuente de verdad VISUAL. No reinterpretar como horror fotorrealista. Mantener el diseño original de la lámina: low-poly estilizado de calidad, geometría facetada grande, materiales mate, colores separados por piezas, ojos con emisión limitada y proporciones caricaturescas inquietantes. La imagen `*_mecanica_ROBLOX.png` ilustra el ataque; las reglas técnicas y los números del texto prevalecen sobre cualquier cifra o frase dibujada en ella.

- Estilo: Roblox 3D premium, criatura de aventura fantástica oscura, entre Creatures of Sonaria y terror accesible de Roblox, **sin copiar criaturas existentes**.
- Geometría: volúmenes legibles desde 25–50 studs; caras y placas grandes, extremidades angulosas, articulaciones preparadas para rig. Evitar escamas minúsculas, pelo por pelo, poros, piel húmeda realista, photobashing, normal maps hiperrealistas, microdetalle y millones de polígonos.
- Color/material: 3–6 tonos principales por criatura; materiales de Roblox o texturas pintadas simples; ojos luminosos como punto focal; lectura adecuada en niebla y con gráficos bajos. No depender de iluminación cinematográfica para reconocer la silueta.
- Producción: modelo modular y animable, pivote consistente, colisiones simplificadas separadas del render; verificar que el modelo no contenga piezas ancladas por error, normales invertidas, meshes con topología rota o animaciones que atraviesen el cuerpo.
- Rendimiento: proponer presupuesto inicial de ~2.000–8.000 triángulos para un NPC normal y ~4.000–10.000 para Gargoyle si las alas lo requieren, **como metas ajustables, no límites oficiales de Roblox**; validar en móvil y con dos encuentros por jugador. Evitar decenas de partículas continuas y texturas 4K.
- Entregables de arte: archivo fuente .blend si se dispone de Blender, FBX/GLB exportable, rig, clips de animación, materiales/texturas, thumbnail y modelo integrado en Studio. Si la IA no tiene modelador/Blender, crear un proxy **estilizado y reconocible** con MeshParts/Parts y entregar instrucciones para sustituirlo; nunca presentar un proxy como mesh final.
- Prueba visual: mostrar criatura a escala de avatar Roblox, frontal, lateral y 3/4, una pose de ataque y captura en el bioma correspondiente. Ningún elemento debe verse como una fotografía de monstruo realista.

### Identidad visual concreta de Viper
Conservar la cabeza desproporcionadamente grande de serpiente/dragón de roca, mandíbula de hueso beige, dos colmillos superiores gigantes, ojos ámbar en ranuras angulares, cresta de placas púrpuras y cuerpo segmentado grueso en espiral. La sección inferior del cuerpo es beige apagado y las placas dorsales tienen acentos magenta tenues. La cara debe ser amenazante pero legible, no hiperrealista. Para el dash, animar compresión del cuello y extensión de segmentos; el indicador rojo es un objeto de gameplay, **no parte del mesh**.

**Adjuntá también:** `../03_REFERENCIAS_VISUALES/VIPER_mecanica_ROBLOX.png` (referencia ilustrativa de la mecánica).

## Instrucción principal para la IA

Quiero que **implementes de forma completa, con código Luau ejecutable y assets de sustitución funcionales**, la bestia global **Viper** para mi juego Roblox **Wildbound**. Tenés adjuntas `VIPER_ficha_modelo_ROBLOX.png` y `VIPER_render_principal_ROBLOX.png`. Usá también el PROMPT MAESTRO del pack; si no lo recibiste, leé las reglas esenciales al final de este archivo. **No me entregues solo una descripción, un pseudocódigo o un modelo decorativo**. Reutilizá la arquitectura de monstruos existente; si no existe, armá solo los componentes mínimos reutilizables. No borres otras criaturas ni scripts anteriores.

## Diseño visual y dirección artística

Viper es una **víbora monstruosa territorial**, más expresiva que una serpiente normal, con cabeza triangular grande, mandíbula de hueso oscura y un cuerpo en forma de S que se comprime como un resorte antes de embestir. Su silueta debe leerse instantáneamente de noche y durante una persecución. No hace falta un cuerpo con cientos de segmentos: priorizá un mesh low-poly bien trabajado y una animación convincente por segmentos/bones o un fallback de piezas articuladas de bajo costo.

**Referencias adjuntas:**
- `../03_REFERENCIAS_VISUALES/VIPER_ficha_modelo_ROBLOX.png`: render principal, vistas alternativas y detalle facial.
- `../03_REFERENCIAS_VISUALES/VIPER_render_principal_ROBLOX.png`: render principal ampliado.

**Arte final requerido:** oscuro, estilizado como un monstruo de Roblox/aventura fantástica, con escamas en grandes placas, no texturas hiperrealistas. Paleta carbón, ciruela grisáceo y ojos ámbar. Mandíbula claramente reconocible desde 30–50 studs, cresta dorsal baja y cola grande. Que parezca criatura original del bosque/bioma, no una serpiente genérica de Toolbox. Longitud orientativa 9–13 studs, altura de cabeza 3–4 studs. Optimizar cuerpo y ojos/colmillos; evitar meshes imposibles de animar o decenas de UnionOperations.

**Animaciones:** idle tenso, serpentear de acecho, cargar al contraerse, embestida extendida, frenado/choque y recuperación aturdida. Sonidos: arrastre, siseo de carga, golpe de avance, impacto y respiración posterior. Si la IA no puede generar/exportar FBX, implementar proxy con rig básico, scripts de visualización y guías claras de sustitución posterior.

## Fantasía de juego: «veo la línea, tengo que salir de ella»

Viper se presenta a distancia media y **no mata por simple proximidad**. Hace un siseo distintivo, se fija en el jugador objetivo, se contrae, dibuja una **línea/rectángulo rojo transparente en el suelo** indicando la trayectoria de su próxima embestida y luego acelera violentamente hacia adelante. El objetivo tiene un intervalo breve pero real para salir del carril. Viper queda vulnerable/parada si falla. Puede repetirlo dos o tres veces antes de retirarse.

### Máquina de estados exacta sugerida

1. `SPAWNING` (0.5–1.0 s): elegir punto de spawn fuera de la base, validado y entre 35–70 studs, idealmente parcialmente oculto. Materializar VFX/sonido solo en cliente objetivo; invulnerable/no daño.
2. `STALKING` (hasta 4 s): moverse/serpentear suavemente hasta 18–30 studs; girar hacia el objetivo, pero no teletransportar. Puede realizar microcorrecciones para no quedar atascada. Si no hay ruta segura, terminar limpiamente.
3. `WINDUP` (1.15 s de valor inicial): emitir siseo fuerte, comprimir cuerpo, bloquear trayectoria hacia la posición estimada del avatar. Crear telegraph **carril rojo** de longitud 25–38 studs y ancho 4–5 studs; coincide con hitbox de la embestida. Durante los primeros 0.7 s puede actualizar dirección visual; en los últimos ~0.45 s **bloquear el ángulo** para que esquivar lateralmente sea viable. No hacer homing tras el bloqueo.
4. `DASH` (0.45–0.75 s): recorrer la trayectoria bloqueada a velocidad rápida (valor inicial 55–70 studs/s) con animación y estela. **Movimiento en el servidor**, con raycast/swept hitbox entre posición anterior y nueva para detectar obstáculos/jugador; nunca depender solo de `Touched` o de `CFrame` final. La colisión con piedra/pared corta el dash. Atacar una única vez por dash.
5. `RECOVER` (1.25–1.8 s): quedar visiblemente confundida, disminuir movimiento y permitir que el jugador recupere espacio. Si chocó con un obstáculo, recuperación ligeramente más larga. Ningún daño durante esta fase.
6. `REPOSITION`: si sigue válido y pasaron menos de ~30 segundos, intentar otra embestida (máximo 3). Variar distancia/carril; si ya atacó suficiente, pasar a despedida.
7. `DISENGAGE/END` (0.6–1.2 s): retroceder o ocultarse en suelo/sombras, eliminar visuales y liberar presupuesto. Terminación inmediata por muerte, salida segura, disconnect y escape sostenido.

**Experiencia justa:** el jugador ve la dirección del ataque y puede evitarlo moviéndose lateralmente. La primera embestida jamás sucede antes de un aviso completo. No bloquear por defecto todas las salidas al mismo tiempo ni elegir un carril que abarque toda una pasarela sin esquiva: usar alternativas de warning o reposicionar; si no hay salida válida, saltar ese ataque.

### Valores de balance (configurables, no constantes dispersas)

| Parámetro | Inicio sugerido |
|---|---|
| Tipo | Global |
| Costo de amenaza | 1 |
| Probabilidad base por tirada de 10 s | `1/45` |
| Cooldown específico tras terminar | 35 s |
| Max 1ª aparición tras respawn | respetar director, 10 s |
| Distancia de activación | 18–30 studs |
| Distancia de aparición | 35–70 studs |
| Telegraph inicial | 1.15 s |
| Largo/ancho de carril | 32 / 4.5 studs |
| Velocidad máxima de dash | 60 studs/s |
| Daño al alcanzar al objetivo | 35 HP |
| Golpes máximos por encuentro | 3 intentos, 1 hit por intento |
| Duración máxima de encuentro | 32 s |
| Distancia para escapar | 100 studs sostenidos 4 s |

Con 100 HP iniciales, Viper es peligrosa, pero un golpe normalmente no mata. Los números se ajustan tras pruebas reales con avatar estándar y velocidad del juego.

## Detección de golpe y sincronización visual

- El servidor mantiene `encounterId`, `targetUserId`, estado, origen del dash, dirección bloqueada, tiempo de inicio del dash y `alreadyHit`.
- El carril en cliente y el carril usado por el servidor deben compartir exactamente centro, ancho, longitud, timestamp/instante de activación y orientación; no enviar un aviso arbitrario que no coincida con la colisión real.
- Al comenzar `DASH`, barrer un volumen geométrico razonable (cápsula/caja, raycasts segmentados o spatial query) **a lo largo del trayecto**, validando HumanoidRootPart del objetivo con tolerancia razonable por latencia. Registrar un solo daño por dash y excluir terceros.
- No atacar a través de paredes; un obstáculo sólido corta recorrido, aunque el cliente visual tenga interpolación.
- Si Viper apunta hacia un lugar donde el objetivo ya no está, la Viper mantiene el carril y falla; **no corregir mágicamente** para acertar.
- VFX locales para el objetivo y daño/HP real en servidor. En debug mostrar trayectoria efectiva y trayectoria dibujada simultáneamente para comprobar alineación.

## IA y reacción al contexto

- Usar PathfindingService o navegación especializada para aproximación corta, con frecuencia moderada y corrección al bloquearse; el dash final es una trayectoria recta, NO pathfinding.
- Si está en una pasarela estrecha y es imposible esquivar, elegir otro ángulo/ubicación o cancelar ataque para evitar situaciones sin solución.
- Si jugador muere o entra a la base, terminar ya, sin golpe tardío. Cancelar `task.delay` pendientes por token/ID, sonidos activos y trails.
- Interrupciones: desincronización de snapshots, CharacterAdded durante el dash, streaming de assets, distancia extrema, NPC destruido. El server siempre debe cerrar el encuentro sin fuga de amenaza.

## Integración con el resto de Wildbound

- Viper es **global**: puede aparecer en todo bioma elegible salvo base/safe zone.
- Su aparición es **personal**: solo el dueño del encuentro la ve y la oye; el daño solo a ese jugador. No hacer el monstruo visible para todos mediante un NPC estándar replicado si la arquitectura permite cliente visual + servidor autoritativo.
- Reservar 1 punto del presupuesto **3** y respetar **2 encuentros máximos** por jugador. Si ya está Gargoyle (2), Viper puede acompañarla. Si ya hay dos encuentros, rechazar tirada aunque haya presupuesto.
- Probabilidades y multiplicadores los administra el director compartido (día x1, noche x2, tormenta x1.5, lejos de base x1.2, zona peligrosa x1.5, expedición prolongada x1.3, producto máximo x4). **Viper no tiene un bucle local de RNG adicional**.
- Tomar datos de base, muerte y carga de huevos de sistemas existentes. No sustituir ni duplicar inventario.

## Entregables técnicos exigidos

1. Código `ViperController` completo, integrable con `EncounterManager`, `SpawnLocator` y `DamageAdapter`, no seudocódigo.
2. Definición `BestiaryConfig.Viper`, rig/modelo placeholder si no existe 3D definitivo, animaciones o equivalente procedural, efectos cliente y sonidos funcionales o IDs pendientes claramente etiquetados con fallback audible/visual.
3. Código que envía `Spawn, Windup, Dash, Recover, Despawn` con ID y tiempos a cliente objetivo. No dependencias ocultas.
4. Configuración de test `ForceSpawnBeast('Viper', player)` **solo disponible en Studio/servidor con permisos**, no RemoteEvent libre para exploits.
5. Prueba 2 clientes: Viper asignada A; B no ve/oye la Viper y no recibe daños; A puede esquivar dos veces y ser golpeado la tercera. Probar muro en trayectoria, desconexión en mitad de dash, salida a base, muerte y limpieza.
6. Entrega final: lista de archivos modificados, cómo probar, video/capturas o logs si el entorno lo permite y confirmación HONESTA de pruebas realizadas.

## Checklist de éxito

- [ ] Se aprecia la serpiente, tiene silueta propia y movimiento/sonido.
- [ ] La línea roja avisa con tiempo y coincide con daño real.
- [ ] Es posible esquivar caminando lateralmente; Viper falla cuando corresponde.
- [ ] El impacto se confirma solo en servidor, máximo una vez por dash.
- [ ] La recuperación evita cadena injusta de daño.
- [ ] Se cumplen RNG por jugador, presupuesto, modificadores y cooldown.
- [ ] La limpieza resiste respawn, safe zone, disconnect y dos encuentros simultáneos.

**Ejecutá la implementación**. Si no podés usar Studio, entregá TODOS los scripts completos y el procedimiento de montaje, sin declarar éxito ficticio.

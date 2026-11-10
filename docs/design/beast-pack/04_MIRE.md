# PROMPT INDIVIDUAL 04/04 — MIRE | ACECHADOR SEMISUMERGIDO DEL PANTANO

## DIRECCIÓN ARTÍSTICA OBLIGATORIA — EDICIÓN ESTILO ROBLOX (ACTUALIZADA)

**Prioridad absoluta:** las nuevas imágenes `*_ficha_modelo_ROBLOX.png` y `*_render_principal_ROBLOX.png` son la fuente de verdad VISUAL. No reinterpretar como horror fotorrealista. Mantener el diseño original de la lámina: low-poly estilizado de calidad, geometría facetada grande, materiales mate, colores separados por piezas, ojos con emisión limitada y proporciones caricaturescas inquietantes. La imagen `*_mecanica_ROBLOX.png` ilustra el ataque; las reglas técnicas y los números del texto prevalecen sobre cualquier cifra o frase dibujada en ella.

- Estilo: Roblox 3D premium, criatura de aventura fantástica oscura, entre Creatures of Sonaria y terror accesible de Roblox, **sin copiar criaturas existentes**.
- Geometría: volúmenes legibles desde 25–50 studs; caras y placas grandes, extremidades angulosas, articulaciones preparadas para rig. Evitar escamas minúsculas, pelo por pelo, poros, piel húmeda realista, photobashing, normal maps hiperrealistas, microdetalle y millones de polígonos.
- Color/material: 3–6 tonos principales por criatura; materiales de Roblox o texturas pintadas simples; ojos luminosos como punto focal; lectura adecuada en niebla y con gráficos bajos. No depender de iluminación cinematográfica para reconocer la silueta.
- Producción: modelo modular y animable, pivote consistente, colisiones simplificadas separadas del render; verificar que el modelo no contenga piezas ancladas por error, normales invertidas, meshes con topología rota o animaciones que atraviesen el cuerpo.
- Rendimiento: proponer presupuesto inicial de ~2.000–8.000 triángulos para un NPC normal y ~4.000–10.000 para Gargoyle si las alas lo requieren, **como metas ajustables, no límites oficiales de Roblox**; validar en móvil y con dos encuentros por jugador. Evitar decenas de partículas continuas y texturas 4K.
- Entregables de arte: archivo fuente .blend si se dispone de Blender, FBX/GLB exportable, rig, clips de animación, materiales/texturas, thumbnail y modelo integrado en Studio. Si la IA no tiene modelador/Blender, crear un proxy **estilizado y reconocible** con MeshParts/Parts y entregar instrucciones para sustituirlo; nunca presentar un proxy como mesh final.
- Prueba visual: mostrar criatura a escala de avatar Roblox, frontal, lateral y 3/4, una pose de ataque y captura en el bioma correspondiente. Ningún elemento debe verse como una fotografía de monstruo realista.

### Identidad visual concreta de Mire
Conservar criatura muy baja y ancha, cuatro apoyos delanteros largos como raíces/garras, caparazón de rocas verdes angulosas, musgo en mechones grandes y ojos amarillo ámbar intensos bajo un flequillo de algas. No convertirla en cocodrilo realista ni en una araña idéntica a Pouncer. Su cabeza debe parecer una masa de pantano que emerge del agua; preparar versión parcial (ojos y lomo) y versión completa (brazos y cabeza) con el mismo rig. Ondas y burbujas se generan por VFX, no mediante mallas complejas.

**Adjuntá también:** `../03_REFERENCIAS_VISUALES/MIRE_mecanica_ROBLOX.png` (referencia ilustrativa de la mecánica).

## Tu tarea

Implementá totalmente **Mire** en el juego Roblox **Wildbound** usando Luau y herramientas disponibles del proyecto. Es una criatura especial del **Pantano** cuyo peligro nace de que el jugador solo puede ver **ondas en el agua, burbujas y una pequeña parte del cuerpo** antes del ataque. Adjuntas referencias `MIRE_ficha_modelo_ROBLOX.png` y `MIRE_render_principal_ROBLOX.png`, más el prompt maestro del pack. No quiero una criatura decorativa, un enemigo que corre por tierra como cualquier otro, ni un GDD. Quiero el sistema de persecución acuática, aviso, emergencia, daño, retirada y bucle final completamente implementado e integrado con el director de bestias y las mecánicas de Wildbound. No borres nada existente.

## Anatomía y apariencia para Roblox stylized

Mire es un depredador de agua turbia, compacto pero inquietante, con cuatro o seis apoyos alargados, hombros o caparazón cubiertos de barro y algas, dedos muy largos y **dos ojos pálidos justo al nivel del agua**. Su cabeza y espinas emergen ocasionalmente. No es un cocodrilo realista: mezcla insecto del pantano, anfibio y entidad vegetal en un lenguaje visual original. Cuerpo central de 5–7 studs, extremidades extensibles, postura baja.

**Usar imágenes:**
- `../03_REFERENCIAS_VISUALES/MIRE_ficha_modelo_ROBLOX.png`: render principal, vistas del cuerpo y detalle de cabeza.
- `../03_REFERENCIAS_VISUALES/MIRE_render_principal_ROBLOX.png`: render principal ampliado.

Visual final con modelos optimizados: barro verde-gris, musgo, algas, pequeños brillos oculares blanco verdosos; bordes grandes low-poly, sin texturas 4K ni cientos de partes. Bajo el agua debe verse **poco**: ojos, lomo y ondas, no todo el cuerpo totalmente visible. Al emerger, mostrar el torso deformado, brazos/garras, arrastre y chorros de agua. Debe conservarse legible en un pantano de bajo contraste y en gráficos bajos. Agua real Terrain o piezas transparentes según el juego; VFX compatibles y con fallback.

Animaciones: desplazamiento bajo superficie, sacudidas/ripples, impulso hacia adelante, levantar cabeza, ataque de garra o mordida, retroceso y sumergirse. Sonidos: burbujeo, gorgoteo de barro, crujido húmedo y chapoteo fuerte de ataque. El sonido es **una advertencia**, no un ruido ambiental confundible; audio espacial cerca del punto real.

## Mecánica única — leer el agua antes de que salga

En el Pantano, hay zonas poco profundas de agua. Mire aparece en un **volumen de agua válido**, inicialmente oculta. Sus desplazamientos forman una estela en superficie (ondas/burbujas) que sigue al jugador desde un costado o detrás, pero nunca teletransportándose delante suyo. Cuando se acerca lo suficiente, el agua se agita, aparece **un anillo/cono de advertencia** y Mire emerge bruscamente para realizar un ataque de alcance corto. Un jugador que observa el agua y se mueve hacia tierra firme o se aleja del punto marcado puede evitar el golpe. Después, Mire puede sumergirse y preparar una segunda embestida si el objetivo sigue cerca del agua.

### Regla principal de justicia y legibilidad

El jugador nunca recibe daño solo porque «hay agua». Debe existir: **1) señal de que algo se acerca (ripple), 2) señal clara del lugar/radio del ataque, 3) tiempo real para huir, 4) hitbox servidora exactamente sincronizada**. No atacar desde debajo de una colisión sólida ni emergiendo a distancia arbitraria. Las zonas de agua tienen límites; Mire no persigue al jugador por tierra como un humanoide normal.

## Estados precisos

1. `WAIT_FOR_WATER_VALIDATION`: al ganar tirada, solo continuar si objetivo está en Pantano y **cerca de agua peligrosa** (ej. a ≤22 studs del borde/superficie) y existe una zona de agua conectada/navegable suficientemente amplia. Si no, descartar oportunidad sin consumir amenaza. Jamás spawnear en charcos decorativos diminutos.
2. `SUBMERGED_SPAWN` (0.5–1 s): aparecer inicialmente oculto 35–70 studs en canal/poza válido, con profundidad adecuada. Si no existe un corredor acuático válido entre criatura y víctima, no atravieses tierra o roca; buscá otro punto o cancela sin castigo.
3. `STALK_UNDERWATER` (4–8 s): avanzar lentamente por el agua (velocidad 9–13 studs/s) hacia una posición cercana al jugador, restringiendo navegación al grafo/volúmenes de agua. Dejar una estela visible y burbujas cada pocos studs; cabeza/ojos aparecen intermitentemente. Un sonido suave hace entender que hay algo acercándose. El jugador puede alejarse o salir de la orilla.
4. `SURFACE_WARNING` (~1.5 s): si alcanza distancia de emergencia (~9–13 studs) y hay punto de ataque válido, intensificar burbujas y dibujar un **anillo/cono rojo-ocre sobre la superficie** o el borde cercano indicando dónde romperá el agua y hacia qué sector atacará. Marcar dirección y alcance con claridad durante ≥1.2 segundos. Bloquear punto/dirección de salida en tramo final; una retirada hacia tierra debe funcionar.
5. `EMERGE` (~0.65–0.9 s): Mire asoma cabeza/brazos, salpica y realiza una zarpada/mordida hacia adelante. No teletransportarse al jugador ni aplicar un radio global instantáneo. El server verifica si la hitbox barrida del ataque (ej. cono 7 studs de alcance, anchura 5 studs) intersecta el objetivo en ventana activa de ~0.2–0.3 s. Máximo un daño por emergencia.
6. `SURFACE_RECOVER` (1.1–1.6 s): queda torpe y expuesto en el borde del agua, sin golpe adicional, con partículas de barro limitadas. La parte expuesta es claramente visible.
7. `DIVE/REPOSITION` (1.2 s): vuelve al agua. Puede repetir hasta 2 ataques por encuentro **solo si** el jugador continúa junto a agua válida; si se fue a tierra, inicia retirada y deja de atacar.
8. `DISENGAGE`: si objetivo sale del Pantano, entra a base, muere, se desconecta, se aleja de toda agua por >6 s, supera distancia de escape o duración máxima de 38 s, hundirse y limpiar. Amenaza liberada exactamente una vez.

## Cómo identificar agua de forma ROBUSTA (clave para no fallar)

No supongas que en Roblox cualquier `Terrain.Water` es automáticamente navegable o que `FindPartsInRegion3` va a detectar todo. Primero inspeccioná el juego: ¿el agua del Pantano usa `Terrain` water, piezas transparentes, MeshParts, volúmenes trigger o combinación? Implementá una **capa `WaterResolver`**:

- **Opción preferida si ya hay agua**: aprovechar regiones/partes del juego con tag `MireWater` o `SwampWater` y atributos `Biome='Swamp'`, `Depth`, `CanSpawnMire`, límites geométricos. Estas zonas son invisibles y no afectan colisiones.
- Para `Terrain` water, usar sampling/raycast/material con una máscara y profundidad validadas, pero no afirmar que se detecta agua si solo se tocó una textura decorativa. Siempre existe modo manual de colocar volumen.
- Convertir volúmenes de agua y sus conexiones en puntos/nodos navegables o simular un movimiento de corto alcance dentro de la misma poza; **no** atravesar islotes/paredes para unir pozas desconectadas.
- Permitir zonas elevadas/inclinadas y bordes: colocar ripple sobre superficie de agua, no 2 studs bajo tierra; calcular altura de superficie a partir de volumen/agua real. En clientes de bajos gráficos, usar círculos simples y pocas partículas.
- Si la zona de agua es muy pequeña o no hay ruta, la bestia **no aparece** y el director registra motivo en logs. No crear instancia colgada consumiendo 2 puntos para siempre.

## Parámetros iniciales (ajustables centralmente)

| Parámetro | Valor |
|---|---|
| Clase | `Biome` |
| Bioma requerido | `Swamp` |
| Puntos de amenaza | 2 |
| Chance por chequeo de 10 segundos | `1/80` |
| Cooldown por especie | 50 s |
| Distancia del jugador a agua para permitir aparición | ≤22 studs |
| Distancia de spawn en mismo sistema de agua | 35–70 studs |
| Velocidad bajo agua | 11 studs/s |
| Distancia para preparar ataque | 9–13 studs |
| Aviso superficie | 1.5 s |
| Alcance de zarpada | 7 studs |
| Ancho de zarpada | 5 studs |
| Daño por ataque | 40 HP |
| Máximo de ataques | 2 |
| Período lejos del agua para escape | 6 s |
| Duración máxima | 38 s |
| Distancia general de escape | 110 studs, 4 s |

Mire es un encuentro especial y no debe activarse por estar en cualquier punto del Pantano: necesita agua idónea y cercanía. Los multiplicadores generales de mundo siguen aplicando igual que a las demás (noche x2, tormenta x1.5, etc.). Las probabilidades son por jugador y por tirada: 1/80 = 1.25% cada 10 s antes de modificadores, no «una aparición fija cada 80 ticks».

## Hitbox, efectos personales y sincronización

- **Autoridad servidor** para posición lógica de Mire, validez de agua, estados, punto de salida, tiempo de ataque, trayectoria de zarpada, daño e invulnerabilidad.
- Visual exclusivamente en el cliente objetivo con `RemoteEvent:FireClient` y snapshots interpolados; jamás permitir que un cliente dispare directamente `MireHit` o `PlayerWasEaten` para hacer daño a terceros.
- La estela debe corresponder a la posición servidora aproximada, aunque suavizada. Si hay lag, priorizar warning estable y margen de seguridad; no clavar daño antes de que aparezca el anillo.
- Para golpes, usar un barrido/cone query con evaluación de target (HRP y tamaño corporal razonable) en instantes definidos, filtrando geometría sólida y evitando múltiples daños en la misma emergencia.
- Solo puede atacar objetivo si está próximo a la zona de agua y si hay línea/superficie válida; no atravesar 20 studs de muro ni perseguir en piso firme sin agua.
- El charco/agua debe seguir siendo utilizable por jugadores no objetivo. Si B cruza una onda personal de A, B no recibe daño ni ve el modelo, respetando la consigna de apariciones personales.

## Casos interesantes para pulir (sin features extra obligatorias)

- Si el jugador escucha burbujas y huye del pantano, queda solo el sonido que se desvanece. La criatura puede llegar a asomar una mano y hundirse sin ataque: gran tensión con bajo costo.
- En zonas con juncos, una estela visible a través de la vegetación que obliga a mirar a los pies, no al cielo.
- Si Pouncer aparece a la vez (1 punto), el aviso de Pouncer debe seguir legible aunque haya ripples de Mire; regular transparencia y superposición de VFX.
- Si el jugador muere cargando huevo, usar flujo actual de muerte y pérdida de huevo; no inventar «Mire roba inventario».

## Entregables completos

1. `MireController` en Luau con los ocho estados y cancelación robusta; `WaterResolver` o adaptador agua reutilizable.
2. `BestiaryConfig.Mire`, volumen etiquetado de agua de prueba en el Pantano si no lo hay, generación/selección de puntos correctos y fallback que no deje monstruos colgados.
3. Modelo 3D low-poly o placeholder útil con estados sumergido/emergido, ojos, ondas, salpicadura y audio direccional; componentes replicados mínimos.
4. Advertencia de ataque y daño sincronizados en servidor; no instante de daño antes del tiempo mínimo de reacción.
5. Debug solo de Studio con representación de agua válida/nodos, radio de emergencia, trayectoria, hitbox efectiva, `encounterId` y puntos ocupados.
6. Testear con 2 clientes, zonas de agua pequeñas y grandes, orilla, isla, lag, falta de terreno, base, salida del Pantano, desconexión, muerte, varias criaturas y 2 puntos de amenaza simultáneos con Viper.
7. Entregar todos los archivos, rutas y pruebas realizadas realmente; reportar qué requiere un mesh/audio definitivo si aún es placeholder.

### Criterios de aceptación

- [ ] Desde el Pantano se reconocen ojos y ondas de Mire antes del golpe.
- [ ] No sale de una pared, piso seco o poza inválida.
- [ ] La marca superficial está alineada con golpe servidor y puede evitarse.
- [ ] La zarpada tiene una sola ventana de daño por emergencia.
- [ ] Alejarse del agua o escapar a zona segura termina el encuentro.
- [ ] No spawnea fuera del Pantano, respeta coste 2, tirada 10 s y multiplicadores.
- [ ] Es visible/audible y peligrosa solo para el jugador dueño del encuentro.
- [ ] No deja sonidos, ondas, recursos ni threat points reservados al cerrar.

**Construí la bestia completa ahora.** Si el entorno no permite construir directamente, proporcioná scripts finales, estructura de instalación, modelos placeholder y pruebas manuales exactas; no solo recomendaciones.

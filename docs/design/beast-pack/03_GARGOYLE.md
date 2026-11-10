# PROMPT INDIVIDUAL 03/04 — GARGOYLE | ESTATUA VIVA Y TORNADOS DEL CEMENTERIO

## DIRECCIÓN ARTÍSTICA OBLIGATORIA — EDICIÓN ESTILO ROBLOX (ACTUALIZADA)

**Prioridad absoluta:** las nuevas imágenes `*_ficha_modelo_ROBLOX.png` y `*_render_principal_ROBLOX.png` son la fuente de verdad VISUAL. No reinterpretar como horror fotorrealista. Mantener el diseño original de la lámina: low-poly estilizado de calidad, geometría facetada grande, materiales mate, colores separados por piezas, ojos con emisión limitada y proporciones caricaturescas inquietantes. La imagen `*_mecanica_ROBLOX.png` ilustra el ataque; las reglas técnicas y los números del texto prevalecen sobre cualquier cifra o frase dibujada en ella.

- Estilo: Roblox 3D premium, criatura de aventura fantástica oscura, entre Creatures of Sonaria y terror accesible de Roblox, **sin copiar criaturas existentes**.
- Geometría: volúmenes legibles desde 25–50 studs; caras y placas grandes, extremidades angulosas, articulaciones preparadas para rig. Evitar escamas minúsculas, pelo por pelo, poros, piel húmeda realista, photobashing, normal maps hiperrealistas, microdetalle y millones de polígonos.
- Color/material: 3–6 tonos principales por criatura; materiales de Roblox o texturas pintadas simples; ojos luminosos como punto focal; lectura adecuada en niebla y con gráficos bajos. No depender de iluminación cinematográfica para reconocer la silueta.
- Producción: modelo modular y animable, pivote consistente, colisiones simplificadas separadas del render; verificar que el modelo no contenga piezas ancladas por error, normales invertidas, meshes con topología rota o animaciones que atraviesen el cuerpo.
- Rendimiento: proponer presupuesto inicial de ~2.000–8.000 triángulos para un NPC normal y ~4.000–10.000 para Gargoyle si las alas lo requieren, **como metas ajustables, no límites oficiales de Roblox**; validar en móvil y con dos encuentros por jugador. Evitar decenas de partículas continuas y texturas 4K.
- Entregables de arte: archivo fuente .blend si se dispone de Blender, FBX/GLB exportable, rig, clips de animación, materiales/texturas, thumbnail y modelo integrado en Studio. Si la IA no tiene modelador/Blender, crear un proxy **estilizado y reconocible** con MeshParts/Parts y entregar instrucciones para sustituirlo; nunca presentar un proxy como mesh final.
- Prueba visual: mostrar criatura a escala de avatar Roblox, frontal, lateral y 3/4, una pose de ataque y captura en el bioma correspondiente. Ningún elemento debe verse como una fotografía de monstruo realista.

### Identidad visual concreta de Gargoyle
Conservar el cuerpo de piedra facetada gris lavanda, hocico de bestia pétrea, ojos cian/turquesa, alas de murciélago de placas rocosas, dos cuernos quebrados y manchas de musgo en pocos sectores. Debe poder parecer una estatua inerte sobre una columna y luego desplegar alas y despegar. No crear un dragón genérico de escamas suaves: se siente como **escultura de piedra que cobra vida**. El tornado es VFX separado, con base visible y silueta clara.

**Adjuntá también:** `../03_REFERENCIAS_VISUALES/GARGOYLE_mecanica_ROBLOX.png` (referencia ilustrativa de la mecánica).

## Orden de implementación

Implementá **Gargoyle** como bestia especial del bioma **Cementerio** en mi videojuego Roblox Studio **Wildbound**. Es la tercera criatura de este pack. Usá el sistema común existente de tiradas por jugador y Threat Budget; no crees un spawner paralelo. Quiero funcionamiento real, no solo apariencia. Adjunto las referencias `GARGOYLE_ficha_modelo_ROBLOX.png` y `GARGOYLE_render_principal_ROBLOX.png` y el prompt maestro con las reglas del proyecto. La Gargoyle debe distinguirse completamente de Viper/Pouncer: mezcla **camuflaje ambiental en piedra, vuelo y tornados con aviso**.

## Diseño de criatura — cómo debe verse

Una gárgola de piedra oscura con cabeza expresiva, alas anchas plegables, cuernos cortos asimétricos, manos con garras y patas macizas. Su superficie tiene grietas grandes que revelan un resplandor suave azul grisáceo o violeta muy desaturado al activarse. Cuando está quieta, debe ser plausible confundirla con una estatua ornamental del cementerio, pero su silueta de alas sigue identificable. No copiar exactamente ninguna gárgola de juegos existentes.

**Referencias visuales incluidas:**
- `../03_REFERENCIAS_VISUALES/GARGOYLE_ficha_modelo_ROBLOX.png`: render principal, vistas alternativas, piedra y alas.
- `../03_REFERENCIAS_VISUALES/GARGOYLE_render_principal_ROBLOX.png`: render principal ampliado.

Arte **estilizado Roblox dark fantasy**: rocas facetadas grandes, grietas pintadas, detalles escultóricos y alas de grosor suficiente para verse a distancia. Evitar shaders hiperrealistas o alas tan transparentes que desaparezcan. Escala orientativa: 6–8 studs de alto, envergadura 11–15 studs. Rig de alas mínimo funcional, pivote para vuelo, control de colisiones y pocos efectos de partículas activos a la vez.

Sonidos únicos: piedra resquebrajándose como señal previa, golpe de alas pesado, viento que aumenta, aullido de tornado y piedra asentándose al desactivar. Animaciones: estatua plegada, activación con partículas de polvo, desplegar alas, elevarse, vuelo en círculo/percha, lanzamiento con mano/alas, impacto de viento y petrificación/retirada. Si no hay mesh final, hacé un modelo provisional de piedra de calidad suficiente para testear y documentá reemplazo.

## Fantasía de juego

En el Cementerio, el jugador observa lápidas y estatuas. Una de ellas comienza a **resquebrajarse y crujir**. De pronto despliega alas y vuela hasta una posición elevada; se oye viento antes de que **aparezca una indicación clara en suelo** de la trayectoria del tornado. La Gargoyle genera un tornado que viaja por el cementerio, obligando a moverse, cambiar de carril o usar las lápidas como cobertura. Su amenaza es espacial: no se limita a seguir al jugador y quitarle vida con contacto físico.

### Estados requeridos

1. `DORMANT_STATUE`: al ganar una tirada, elegir **una percha válida del Cementerio**, a 35–90 studs del objetivo, en columna, muro o monumento, evitando ocupar el mismo objeto que otra instancia y evitando base. En presentación local, se ve como estatua inmóvil; sin daño durante activación.
2. `AWAKENING` (1.6 s): crujido y pequeñas grietas con polvo. Las alas empiezan a abrirse; la señal puede escucharse antes de ver a la criatura. Este estado DEBE dar al jugador oportunidad de reconocer que algo se despertó.
3. `TAKEOFF` (~1.3 s): sube a posición aérea razonable (8–16 studs sobre suelo) o se desplaza a un punto despejado del Cementerio; comprobar techos, arcos, árboles y paredes con raycast. No atravesar geometría masiva.
4. `TRACK/HOVER` (1–3 s): vuela alrededor, mira al objetivo y elige un corredor de viento posible. No perseguir en contacto permanente ni pegar cuerpo a cuerpo por defecto.
5. `TORNADO_CHARGE` (1.65 s): efecto de viento que se concentra en las alas/cabeza; un **trazado de advertencia** visible en suelo (una franja con flechas/torbellinos transparentes) indica posición inicial, dirección y ancho del tornado. La ruta puede seguir una línea o curva sencilla conocida; el objetivo necesita ver por dónde pasará. Bloquear la ruta durante los últimos ~0.8 s para permitir evasión.
6. `TORNADO_TRAVEL` (2.2–3.5 s): generar un tornado visible que se desplaza por una ruta del Cementerio a 12–20 studs/s, con 4–5 studs de radio de golpe y duración acotada. Interactúa con pilares/paredes: **termina o desvía de forma preanunciada**, nunca atraviesa un muro sólido para golpear al jugador desde otro lado. Calcular volúmenes de peligro en el servidor; visual en el cliente objetivo sincronizado por origen, dirección, timestamp y velocidad. Nunca más de un tornado activo por Gargoyle salvo que se diseñe expresamente otro ataque futuro.
7. `HIT/NEAR MISS`: si alcanza al objetivo, aplicar daño servidor 25 HP, efecto de desplazamiento moderado (pequeño empuje horizontal **limitado** que no produzca lanzamiento al vacío) y sonido/viento en cámara del objetivo. Si falla, dejar respuesta audiovisual de viento que pasó cerca. No aplicar daño múltiples veces por permanecer dentro del tornado; usar debounce por tornado y encounter.
8. `RECOVER/HOVER` (1.3–2 s): se reposiciona, da tiempo de respirar, puede planear por encima de un muro y prepara nuevo ataque. Máximo 2–3 tornados por encuentro.
9. `RETURN_TO_STONE/END`: regresa hacia una percha o se petrifica y se desintegra discretamente. Liberar amenaza/recursos. Terminar si sale del Cementerio (gracia de ~2 s si cruza borde), entra a base, muere, escapa mucho, se desconecta o supera duración máxima.

## Por qué funciona como bestia de bioma

- **No aparece fuera del Cementerio**, aunque haya una tirada ganada en otro mapa.
- Se apoya en **arquitectura del cementerio**: estatuas, lápidas, pilares, bóvedas y lugares elevados para ocultarse y crear cobertura.
- Si el Cementerio está vacío o aún no tiene perchas, el juego debe incluir puntos temporales claramente identificados con `CollectionService` tag por ejemplo `GargoylePerch` y atributo `Biome='Cemetery'` o generarlos donde sea válido. No inventar una estatua que interfiere con pathfinding del jugador.
- Los tornados **deben respetar las paredes** y la geometría. Animar del cliente no habilita ignorar colisiones en el servidor.
- Que el tornado tenga una silueta nítida en su base y una señal en suelo; no oscurecer por completo la pantalla.

## Parámetros iniciales modificables

| Campo | Valor propuesto |
|---|---|
| Clase | `Biome` |
| Bioma requerido | `Cemetery` |
| Costo | 2 puntos de amenaza |
| Probabilidad base por 10 s | `1/100` (de día, antes de multiplicadores) |
| Cooldown especie | 60 s |
| Percha de aparición | 35–90 studs |
| Tiempo de despertar | 1.6 s |
| Altura vuelo respecto a suelo | 8–16 studs |
| Telegraph tornado | 1.65 s |
| Velocidad tornado | 16 studs/s |
| Radio tornado | 4.5 studs |
| Vida máx. tornado | 3 s |
| Daño por tornado | 25 HP |
| Tornados por encuentro | 2 estándar, 3 máximo |
| Duración total encuentro | 42 s |
| Salida por alejamiento | >125 studs, 5 s continuos |
| Salida por abandonar bioma | 2 s de gracia |

**Interpretación de probabilidad:** `1/100` significa 1% de chance en **cada tirada de 10 segundos** si el jugador está en Cementerio, tiene presupuesto y cumple condiciones. De noche x2 convierte 1% en 2%. No aparece «cada 100 tiradas exactamente». Multiplicadores comunes x4 máximo. Limitar chance efectiva según director.

## Control de vuelo y tornados, aspectos técnicos que quiero bien hechos

- Vuelo y hover: modelo visual separado de hitbox; planear con una interpolación que no atraviese paredes, límites de aceleración y comprobación de espacio. No usar `Humanoid:MoveTo` para un NPC volador si eso genera saltos por el suelo.
- El server calcula trayectoria de tornado (puede ser una recta que respete colisiones) y comprueba volumen con barrido por pasos a un ritmo controlado; el cliente solo dibuja la espiral y efectos. Evitar hacer 200 instancias físicas/tormenta.
- El jugador debe saber dónde se dirige el tornado **antes** de que sea letal. La misma matriz de posición/rotación/timestamp informa el suelo y el volumen de daño. Si cambia la trayectoria por colisión, el VFX debe corresponder. No corregir rumbo en secreto a 90 grados para golpear.
- No forzar grandes `AssemblyLinearVelocity` al cliente. Si se aplica un knockback, que sea pequeño, temporal, calculado en servidor, respetando paredes/abismos y estado humanoide; si no puede garantizarse, omitir knockback y mantener daño + cámara.
- Gargoyle **solo impacta al targetUserId**; otros jugadores en el Cementerio no ven el tornado personal ni reciben daño (salvo que en el futuro se diseñe modo compartido, no implementarlo ahora).
- El servidor ignora ataques cuando target entra a zona segura, está muerto o el encuentro finalizó, incluso si un VFX de tornado todavía está terminando en cliente.
- Sumar cost 2 al Threat Budget 3: puede coexistir con Viper o Pouncer cost 1, no con Mire cost 2. Máximo 2 encuentros activos por jugador, aunque costo permita más.

## Requisitos de audio, cámara y UX

A la distancia: ruido de piedra, no un jumpscare instantáneo. Cerca: dos fuentes sonoras distintas, 1) despegue y 2) tornado con viento direccional. La base del tornado ha de contrastar con suelo oscuro (anillo fino claro + núcleo gris) para que móvil distinga amenaza sin depender de postprocesado. Efecto cámara ligero al pasar cerca, reducido por preferencia de accesibilidad. Duraciones de efectos acotadas y pooling/limpieza de emisores.

## Integración con mundo actual y criterio de implementador

- Leer/usar `BiomeResolver` y zonas existentes, no colocar detección de bioma en LocalScript. Si no existe detector, construir un helper reutilizable con Parts invisibles, CFrame y Bounds para áreas rotadas.
- Si hay clima real, conectar multiplicador de tormenta servidor a la Gárgola por director. La tormenta no garantiza siempre que aparezca y no se vuelve permanente.
- Si ya hay tumbas, estatuas o meshes importados, no borrarlos ni reemplazarlos masivamente por pruebas. Añadir perchas de forma no destructiva.
- Dañar mediante servicio común, permitiendo que muerte active lógica actual de perder huevo en expedición.
- Utilizar `RemoteEvent:FireClient` para la presentación exclusiva; protegé servidores frente a eventos del cliente falsos; no aceptar `tornadoHit` desde cliente.

## Entregables, pruebas y definición de terminado

1. `GargoyleController` funcional, configuración, control de perchas, vuelo, tornado server-authoritative y efectos/animaciones audibles y visibles.
2. Modelos low-poly o placeholders modificables, rig de alas y visual para estado estatua, despertar y vuelo. Documentar rutas reales de assets.
3. Sistema de spawn de Cementerio real: sin aparición fuera del bioma, con validación de perchas, salida y safe zones.
4. Comando debug `ForceSpawnBeast('Gargoyle', testPlayer)` con verificación de bioma y override Studio independiente para pruebas, **no para jugadores normales**.
5. Tests: día vs noche (proporción de probabilidad), Cementerio vs Pantano, dos clientes, tornado cubierto por pared, pasar cerca sin tocar, moverse lateralmente durante telegraph, morir/respawn durante tornado, salir del bioma, presupuesto 3 con Viper=1.
6. Listar scripts creados/modificados, pruebas efectivamente ejecutadas y evidencias; reportar honestamente los problemas no resueltos.

### Checklist

- [ ] Como estatua, se reconoce en el Cementerio; despertar visible/audible.
- [ ] Vuela sin atravesar geometría o caer como humanoide de suelo.
- [ ] Muestra el rumbo de tornado con suficiente anticipación.
- [ ] El tornado y su hitbox servidor viajan sincronizados.
- [ ] Una tumba/pared válida ofrece cobertura cuando el diseño del corredor lo permite.
- [ ] No hay golpes fantasma fuera de tornado ni daño repetido masivo.
- [ ] Solo se activa en Cementerio, únicamente al objetivo elegido.
- [ ] Se integra a Threat Budget 3, modificadores, salida, muerte y limpieza.

**Construí la funcionalidad real.** Si no tenés acceso a Roblox Studio, entregá los archivos completos, rutas exactas y prueba manual reproducible; no me des un plan sin implementación.

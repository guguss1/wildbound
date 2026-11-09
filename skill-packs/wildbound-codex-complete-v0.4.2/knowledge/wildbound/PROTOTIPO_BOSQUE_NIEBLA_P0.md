# Prototipo P0 — Bosque de la Niebla, una criatura + un guardián

**Estado: DISEÑO PROPUESTO; sin implementación ni validación en Roblox Studio.**

## Intención y límites
Construir una primera expedición rejugable, pequeña y completa, para demostrar que **explorar → obtener un huevo o capturar a Lumipol → afrontar a La Silueta → volver a extraer → registrar/eclosionar → volver con el compañero** funciona en móvil y en cooperativo. No generar un mapa gigante ni 10 pets antes de validar esto.

- Zona aproximada: **400 × 400 studs**, ajustable según experiencia y rendimiento.
- Sesión objetivo: **5–10 minutos** de exploración inicial (hipótesis).
- Modo: **1 jugador como requisito**, **2 jugadores en prueba**, objetivo posterior 4.
- Mundo visual: bosque estilizado de día; **niebla densa y amenazante por la noche** dentro de un área claramente identificable.
- Contenido incluido: **una especie: Lumipol**; **un guardián: La Silueta**; una variante de huevo de esa especie; uno o dos recursos; un punto de extracción; un refugio opcional (solo si no distrae del objetivo).
- No está incluido en P0: El Vigía, Yeti, seis biomas, decenas de especies, comercio, tienda de Robux, intercambio, mapas procedurales completos, tablas complejas de gachas.

## Ubicaciones y rutas
Usar `references/maps/fog_forest_layout_proposal.png` como orientación, no como mesh ni coordenadas definitivas:
1. **Campamento seguro / extracción**: al suroeste, aparece el jugador, se guardan resultados al regresar, sin spawns hostiles.
2. **Ruta de acceso**: camino claro y una bifurcación legible en móvil. Dos regresos: largo relativamente seguro o corto y peligroso.
3. **Claro de Lumipol**: centro-izquierda, pistas luminosas y una captura directa mediante interacción corta.
4. **Nido de prueba**: noreste, huevo temporal; el resultado de eclosión en P0 puede ser Lumipol seguro para evitar un catálogo falso de rarezas. Variantes cosméticas de Lumipol son opcionales.
5. **Territorio de La Silueta**: norte/este, mayor espesor de niebla, pistas auditivas y huellas. No entrar en el campamento ni bloquear obligatoriamente la única ruta segura.
6. **Refugio opcional**: sureste, área sin spawns. En P0 NO convierte todo el botín en permanente automáticamente; se mantiene el papel de la extracción.

## Mecánica de captura y compañeros
- Lumipol salvaje: permite una captura sencilla (acercamiento sigiloso + interacción/minijuego breve). Mientras no esté extraído, se transporta como **captura temporal**. **No se puede equipar ni usar en campo hasta extraerlo y registrarlo**.
- Huevo de Lumipol: se transporta temporalmente, se eclosiona **gratis** en base tras extraerlo. No Robux, no azar pagado en P0.
- Después de extraer, Lumipol registrado es **permanente y equipable**. En la segunda expedición puede usar **Pulso luminoso**: revela por ~4 s el contorno de La Silueta, enfriamiento provisional ~30 s. Servidor valida distancias, activación y cooldown.
- Para que la primera expedición no exija pet, entregar al jugador una **linterna de destello gratuita** que permita revelar momentáneamente a La Silueta. Lumipol es una mejora táctica, nunca un requisito obligatorio.
- Pet en P0: uno visible/equipado; sin necesidad de programar reservas todavía.

## Guardián: La Silueta (único en P0)
- **No se mueve por regla de mirar/no mirar**. Esa es la mecánica de **El Vigía**, guardián futuro.
- La Silueta es lenta, casi invisible; se insinúa por contorno tenue, sonidos, hierba agitada y huellas. Patrulla y comienza persecución cuando se acerca/detecta ruido.
- Contraestrategia gratuita: reconocer pistas y apartarse/usar cobertura; linterna con destello y cooldown. Lumipol revela su contorno y simplifica escapar.
- Límites: velocidad baja, distancia máxima de persecución, transición clara de alerta, espacio de escape, cooldown después de perseguir, ausencia en radio seguro. No castigos invisibles sin telegráfo.
- Estado de IA, daño y proximidad decididos por **servidor**. Efectos de contorno y audio pueden renderizarse en cliente, sin darle autoridad al cliente.

## Día y noche
- Propuesta inicial: ciclo servidor de 20 min (día 10 / atardecer 2 / noche 6 / amanecer 2), NO confirmado por usuario; permitir avance/aceleración solo en entorno de pruebas.
- Se ve cambio general de luz; **solo zona de niebla** incrementa peligro y oportunidades. Día = pista clara / encuentro moderado. Noche = niebla más espesa, presencia de La Silueta más probable, y posibilidad mayor de variante rara de Lumipol y recursos especiales.
- Para mostrar el efecto sin múltiples especies, proponer una **variante nocturna de Lumipol** y un recurso raro. Sus porcentajes deben definirse en una única tabla server-side y normalizarse; no prometer odds a partir de un multiplicador de pesos.
- Crepúsculo alerta al jugador. Campamento/refugio no se vuelven peligrosos. Probar noche con baja calidad gráfica y sin sonido.

## Riesgo, muerte, extracción y protección
- **CONFIRMADO:** pérdida tipo A. Huevos y capturas no asegurados se pierden en derrota; mascotas registradas se conservan siempre, incluso equipadas; pequeña fracción de recursos perdidos (12% de ejemplo, por ajustar).
- Primer consumible gratuito: **Sello de Resguardo**, protege **un** huevo o captura seleccionada en derrota; una carga. Fabricable o ganable jugando; no se vende por Robux en P0.
- Si un jugador sale de la zona o se desconecta, no otorgar automáticamente botín temporal. Definir comportamiento seguro con reconexión y prevención de duplicación antes de pruebas.
- La extracción completa en campamento es la que convierte botín temporal en permanente; UI debe distinguir **NO ASEGURADO** de **ASEGURADO**.

## Interface mobile-first
- Botones grandes: Interactuar/Capturar, Linterna/Pet, Mochila, Sprint/Agacharse según test. Evitar superposición con controles táctiles de Roblox.
- Mostrar contador de carga/cooldown, fase día/noche, señal de peligro nocturno, estado del huevo (temporal/protegido), indicador de ruta a base accesible.
- Sustos y oscuridad graduables: never rely solely on color, audio or sudden flashing; provide visual alternatives and reduce-motion settings.

## Plan concreto para Codex
1. **Auditar** MCP/Studio y crear experiencia **local de prueba** (sin publicar). Guardar un respaldo antes de editar.
2. **Greybox** 400×400 con campamento, ruta bifurcada, claro de Lumipol, nido y territorio de Silueta. Comprobar cámara y navegación móvil antes de modelar.
3. **Luau/server**: estado de expedición, captura temporal, huevo temporal, extracción atómica/antiduplicación, persistencia de pet registrado, pérdida tipo A, sello, tablas de aparición.
4. **Guardian**: patrulla lenta, contorno tenue, pistas, persecución acotada, fin del aggro, destello gratuito.
5. **Compañero**: Lumipol equipable tras extracción, pulso reveal con cooldown server-side.
6. **Reloj**: Lighting + atmósfera por fase, y riesgo/recompensa nocturnos solo en niebla, sin doble multiplicación.
7. **Arte**: usar referencias del paquete; primero una roca/árbol/arco + un modelo sencillo de Lumipol y Silueta. Roblox Studio MCP para greybox/terreno; Blender MCP para meshes/rigging, si conectado. Fall back to Parts para prototipo.
8. **Playtests**: solo, móvil, 2 jugadores, día/noche, fallo durante captura/extracción, mala red, derrota, reconexión. No afirmar resultados no ejecutados.
9. **Reporte**: archivos modificados, assets generados, pruebas con resultado, pendientes; pedir revisión visual antes de expandir.

## Condiciones de aceptación
- Jugador 1 puede capturar un Lumipol o cargar un huevo, extraerlo y conservarlo en un relanzamiento de sesión cuando persistencia de prueba esté habilitada.
- En derrota, los huevos/capturas temporales sin sello desaparecen, recursos disminuyen en porcentaje provisional; los pets registrados NO se pierden.
- Linterna gratuita revela a La Silueta sin exigir un pet previo; después Lumipol registrado también puede hacerlo con cooldown.
- Cambio noche/día se aprecia, se anuncia; hostilidad y rareza nocturna ajustan solo área niebla. Ningún spawn hostil en campamento.
- Tanto solo como 2 jugadores obtienen sus propias recompensas sin duplicación ni afectarse la colección indebidamente.
- UI usable con controles táctiles; no errores críticos conocidos en teléfono de prueba. Registrar mediciones reales, no inventar FPS.
- No hay compras ni probabilidades pagadas, ni publicación automática.

## Referencias
- `references/README.md` — imagen real del material disponible y errores en textos ilustrativos.
- `references/mood/fog_forest_key_scene.png` — tono de la zona.
- `references/creatures/lumipol_reference.png` y `references/guardians/la_silueta_reference.png` — siluetas.
- `references/maps/fog_forest_layout_proposal.png` — guía de ubicaciones.

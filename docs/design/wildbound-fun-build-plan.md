# Wildbound: plan para construir, de a una cosa por vez

Fecha: 2026-11-20. Es un plan; nada está construido todavía. Sale del plan que te gustó (`docs/design/wildbound-playtime-and-gameplay-plan.md`) y de la propuesta B, rangos de ladrón con tienda.

## 1. Cómo vamos a trabajar

- **Una tarea por vez.** La siguiente no empieza hasta que vos hayas probado la anterior.
- **"Terminada" quiere decir:**
  1. Las pruebas automáticas pasan. Son chequeos que corren solos y avisan si algo se rompió.
  2. El código se copia a tu juego en Roblox Studio.
  3. Se juega una partida de prueba (botón Play) con un solo jugador.
  4. Vos la jugás, decís si te divierte y **guardás** el juego en Studio.
- Tamaños: **S** = chica (una tarea), **M** = mediana (2 o 3), **L** = grande (5 o más).
- Nada se publica y nada se cobra de verdad.

## 2. Paso 0: "La tienda y los carteles"

Va primero, así todo lo que venga después ya sale con la estética nueva.

### 2a. Un kit de estilo igual a tu imagen

Un "kit" son piezas de interfaz que comparten todas las ventanas. Ampliamos el que ya existe, `WildboundUiStyle.luau` (el archivo de estilo del juego), para que se parezca a `docs/design/refs/store-ui-reference.png`.

**La letra ya viene dentro de Roblox:**
- **FredokaOne**: redonda, para títulos como "¡Tienda!". El juego ya la usa.
- **LuckiestGuy**: más gruesa y en mayúsculas, para "¡NUEVO!" y la X.
- Les sumamos un **borde oscuro grueso**, como en la imagen. Hoy ese borde es finito.

**Los efectos, también incluidos:** `UIGradient` = degradé de colores; `UIStroke` = borde grueso; `UICorner` = esquinas redondeadas.

**Las piezas:**
1. **Ventana:** marco azul brillante con esquinas redondeadas y un panel claro adentro.
2. **Título** grande con borde oscuro.
3. **Botones redondos de categoría** arriba, de colores, con un dibujito (emoji).
4. **X roja** grande para cerrar, fácil de tocar con el dedo.
5. **Tarjetas con degradé** cian, magenta y amarillo, con **rayos de sol** que giran despacio.
6. **Cartel "¡NUEVO!"** rojo e inclinado, solo en cosas gratis. En las ofertas de Robux no va, porque apura a los chicos.
7. **Botones de precio gruesos:** naranja para el oro y verde para Robux. El verde lleva el **símbolo de Robux**, que Roblox trae como letra especial (código U+E002). Hay que comprobar en Play que se vea; si no se ve, va "R$".
8. **Chip con reloj** (🕐 y cuenta regresiva), solo para eventos gratis.
9. **Candado:** oscurece la tarjeta y muestra un candado con el precio.

Con **Efectos suaves** prendido en Ajustes, los rayos no giran y el "¡NUEVO!" no late.

**La Toolbox (Caja de herramientas):**
- **Cómo se abre:** en Roblox Studio, pestaña **Inicio** (Home) o **Ver** (View), botón **Toolbox**. En la versión nueva de Studio también está en el menú **Window**. Ahí está la **Creator Store**: modelos, imágenes y sonidos de otras personas, con buscador.
- **Para la interfaz no hace falta,** y no hay que subir ninguna imagen. Sus kits traen scripts (código) de desconocidos e imágenes ajenas que pueden fallar con "no tenés permiso", como nos pasó con los íconos.
- **Sí sirve para adornos del mapa** (un barril, un cartel de madera), después de revisar que no traigan scripts.

### 2b. El catálogo de ofertas

Es **una sola lista** con cada lugar donde algún día se podría pagar con Robux. Va en un archivo nuevo, `WildboundOffers.luau`. Los precios son **de mentira**.

| Código | Nombre | Dónde se ve | Precio de prueba | Qué desbloquea | Si estuviera bloqueado | Hoy (gratis) | ¿Lo permite el documento de economía? |
|---|---|---|---|---|---|---|---|
| `raftBoard` | Pase de balsa | Cartel en el muelle y tarjeta en la tienda | 49 | Subir a la balsa banana | Candado en "Subir"; se puede seguir caminando | Cualquiera sube | **No** (todo lo pago debe tener camino gratis). **Tu decisión del 20/11** |
| `rouletteExtraSpins` | Más tiros de ruleta | Tarjeta verde junto a "Girar" y cartel al lado de la ruleta | 25 (3 tiros) | Tiros extra | Solo el tiro gratis y los tiros con Esencia | 1 tiro gratis, después 45 Esencia | **No** (azar pago; los premios incluyen Esencia). **Tu decisión del 20/11** |
| `explorerGear` | Equipo del explorador I | Tarjeta en "Taller de guantes" | 49 cada pieza | Guantes, Botas o Amuleto nivel I, cada uno por separado | Candado | Se fabrica con Esencia y materiales | **Sí**, con rareza fija, no al azar, y es la misma pieza que se gana jugando |
| `bigBag` | Bolsa grande | Tarjeta en "Suministros" | 49 | Más lugar para huevos | Candado | Con Esencia | **Sí** |
| `secondIncubator` | Segunda incubadora | Tarjeta en "Mejoras" | 39 | Dos huevos a la vez | Candado | Con Esencia | **Sí** |
| `farmPen6` | Corral 6 | Tarjeta en "Mejoras" | 29 | Un lugar más en la granja | Candado | Con Esencia | **Sí** (los corrales 7 y 8, no) |
| `portalTravel` | Viaje rápido | Cartel en el portal | 25 | Viajar sin esperar | Esperás como hoy | Gratis, con espera | Dudoso: solo con camino gratis |
| `cosmetics` | Estelas y carteles de nombre | Tarjeta en la tienda | 49 a 149 | Solo apariencia | Candado | No existe todavía | **Sí**, más adelante |

**Lo que no lleva cartel,** salvo que vos confirmes que querés cambiar la regla:
- Lo que prohíbe el documento de economía: Esencia, el árbol de habilidades, ayudas para sobrevivir o calmar el miedo (como el Chaleco), tótems, multiplicadores ("x2"), velocidad de nacimiento, Guantes nivel II y III, y los corrales 7 y 8.
- El oro: el código dice que nunca se vende por dinero real.
- La velocidad de la cinta: no está nombrada, pero funciona como un multiplicador.

**Los textos con "Robux" o su símbolo van solo en `WildboundOffers.luau`.** Hay pruebas automáticas que hoy prohíben esa palabra en el oro y dicen "la balsa es gratis". Esas pruebas se cambian a propósito, en la misma tarea, y siguen prohibiendo cualquier cobro real.

La balsa y los tiros de ruleta también estaban prohibidos. Están en la lista porque los pediste el 20/11, y queda anotado como **tu decisión**.

### 2c. El interruptor de desarrollo

- Un interruptor, `DESBLOQUEAR_TODO = true`, en el archivo de opciones del juego (`WildboundFlags.luau`). Mientras esté prendido (`true`), **todo está abierto**.
- Los carteles muestran el precio con una notita: "modo desarrollo: desbloqueado".
- **El botón verde hace lo que haría la compra, gratis:** en la balsa, subís; en la ruleta, "Más tiros" te da 3 tiros sin gastar Esencia.
- Si algún día se apaga el interruptor antes de que haya pagos reales, el botón muestra "Próximamente" y la cosa queda con candado.
- **Nunca** se llama a `MarketplaceService` (el sistema de pagos de Roblox). La regla "sin cobros", `monetization = "none"`, sigue igual.
- Apagarlo necesita tu **OK explícito**, los productos creados en Roblox con sus números y una tarea aparte.

### 2d. Carteles en el mundo

Cada lugar del catálogo tiene su cartel, con el mismo estilo de la tienda:
- `BillboardGui`: cartel que flota y siempre mira a la cámara.
- `SurfaceGui`: cartel pegado a una pared o un poste.

Los primeros van en el muelle de la balsa y junto a la ruleta. Los carteles oscuros de hoy pasan al estilo nuevo.

**Tareas del Paso 0** (cada una deja algo que ves jugando):
- **P0.1, el kit (M).** Se estrena en la ventana de la ruleta, que pasa al estilo nuevo.
- **P0.2, el catálogo, el interruptor y el cartel de la balsa (S/M).** Ves el cartel en el muelle con precio y "desbloqueado", y subís gratis.
- **P0.3, "Más tiros" en la ruleta, y el contador de oro y el botón de la balsa con el estilo nuevo (M).** Ves la tarjeta verde y girás de más gratis.

P0.2 y P0.3 agregan **tarjetas de Robux de mentira**.

## 3. Orden de construcción

Primero va lo que más divierte por menos trabajo. **[R$]** marca las tareas que agregan una tarjeta de Robux de mentira.

**T1. Esquiva arreglada y rango de ladrón (S/M)**
- **Qué ves y jugás:** un cartel "Aprendiz" con una barra que llenan tus huevos. A los 3 robos sale la tarjeta "¡Ladronzuelo!".
- **Por qué es divertido:** cada robo te acerca a algo que se ve.
- **Qué se construye:** el arreglo de un error (hoy una esquiva fallada igual te deja intocable un rato) y el rango, que nunca baja, con su guardado.
- **Qué reusa:** el panel de arriba y el guardado de la ruleta como molde.
- **Riesgos:** que suba muy rápido o muy lento. Se ajusta jugando.

**T2. Primer huevo en menos de 90 segundos (S)**
- **Qué ves y jugás:** un nido fácil asegurado cerca de la plaza.
- **Por qué es divertido:** el primer premio llega enseguida.
- **Qué se construye:** cambios en la ubicación de nidos y en el tutorial.
- **Qué reusa:** lo que ya ubica los nidos y el tutorial.
- **Riesgos:** aburrir al que ya sabe jugar. Solo vale para el primer robo.

**T3. Círculo "Mejoras": el Impulso I por oro (M) [R$]**
- **Qué ves y jugás:** te parás en el círculo y se abre la tienda. El Impulso I cuesta 150 de oro o sale gratis con 10 esquivas perfectas, y hace que la Esquiva te tire hacia adelante.
- **Por qué es divertido:** la primera compra se siente en el cuerpo.
- **Qué se construye:** la tienda de los círculos, el Impulso (que **nunca** se vende por Robux) y tarjetas de mentira para Segunda incubadora y Corral 6.
- **Qué reusa:** el oro, los círculos ya construidos (hay que revisar en Studio que estén) y el kit.
- **Riesgos:** un Impulso demasiado fuerte.

**T4. Los otros círculos de tienda (M) [R$]**
- **Qué ves y jugás:** "Taller de guantes", "Suministros" y "Árbol de habilidades" se abren con el mismo estilo.
- **Por qué es divertido:** el oro y la Esencia tienen dónde gastarse.
- **Qué se construye:** las tres ventanas, tarjetas de mentira para Equipo I y Bolsa grande, y el cartel del portal.
- **Qué reusa:** la tienda de T3.
- **Riesgos:** el Árbol **nunca** lleva tarjeta de Robux.

**T5. Pagos al derecho (S)**
- **Qué ves y jugás:** Pueblo Gatito paga menos y el fondo de Caramelo, más.
- **Por qué es divertido:** arriesgarse vale la pena.
- **Qué se construye:** el ajuste de los pagos.
- **Qué reusa:** el nivel de riesgo de cada nido.
- **Riesgos:** desbalancear los precios.

**T6. Bichos que se adaptan a tu rango (S)**
- **Qué ves y jugás:** en Caramelo, los bichos persiguen un poco más rápido a quien tiene más rango.
- **Por qué es divertido:** el desafío crece con vos.
- **Qué se construye:** la velocidad de persecución según el rango del chico perseguido.
- **Qué reusa:** el cerebro de los bichos y el rango de T1.
- **Riesgos:** frustrar. Por eso, después de 2 robos fallados el siguiente es más suave.

**T7. Evento que rota de zona (S/M)**
- **Qué ves y jugás:** cada 20 minutos, un cartel con reloj anuncia Hora del Caramelo, Noche de la Silueta o Fiesta Gatuna.
- **Por qué es divertido:** cada visita es distinta.
- **Qué se construye:** la rotación y su cartel.
- **Qué reusa:** el reloj de eventos, el nido Legendario hoy apagado y el chip del kit.
- **Riesgos:** bajos.

**T8. Metas del día con racha amable (M)**
- **Qué ves y jugás:** 3 tarjetas por día ("traé 2 Raras"), con barra y premio de oro.
- **Por qué es divertido:** una razón para volver mañana.
- **Qué se construye:** las metas, que cambian cada día, y su guardado.
- **Qué reusa:** los contadores del juego y la barra del kit.
- **Riesgos:** ansiedad. Si faltás, la racha baja un día en vez de perderse, y nunca se paga para recuperarla. **Necesita tu sí.**

**T9. Álbum de criaturas (S/M)**
- **Qué ves y jugás:** un libro con una página por zona. Lo que falta es una silueta, y cada página completa da oro o un tiro de ruleta gratis.
- **Por qué es divertido:** metas largas sin agregar mapa.
- **Qué se construye:** el álbum y la marca de "página cobrada".
- **Qué reusa:** la colección y las tarjetas del kit.
- **Riesgos:** una variante dorada siempre muestra su probabilidad y **nunca** se vende.

**T10. Criaturas nuevas que nacen (M)**
- **Qué ves y jugás:** gatitos en Gatito y las especies del Bosque ya dibujadas: de 5 a unas 12 especies.
- **Por qué es divertido:** más para descubrir.
- **Qué se construye:** las especies nuevas en nidos y granja.
- **Qué reusa:** modelos ya exportados.
- **Riesgos:** **cada subida de modelo necesita tu permiso.**

**T11. Pueblo Gatito largo, 16 nidos (L)**
- **Qué ves y jugás:** una zona fácil mucho más grande.
- **Por qué es divertido:** más lugar para aprender.
- **Qué se construye:** la versión larga en Studio.
- **Qué reusa:** el armador ya preparado.
- **Riesgos:** lentitud en el celular. Se mide.

**T12. Rangos hasta Leyenda y tienda completa (3 × M) [R$]**
- **Qué ves y jugás:** seis rangos; Botas, Mochila firme, Planeo y Bomba de humo.
- **Por qué es divertido:** cada rango trae una herramienta.
- **Qué se construye:** los rangos 2 a 5 y las herramientas, cada una con camino gratis jugando o por oro.
- **Qué reusa:** el rango de T1 y la tienda de T3.
- **Riesgos:** solo Botas I puede tener tarjeta de Robux de mentira.

**T13. Medallas y contrarreloj (M)**
- **Qué ves y jugás:** bronce, plata y oro por nido, y un tablero de récords en la plaza.
- **Por qué es divertido:** el hábil repite para mejorar.
- **Qué se construye:** los retos y el tablero.
- **Qué reusa:** los nidos y el tablero hoy escondido.
- **Riesgos:** compararse. Se destaca tu propio récord.

**Después (Fase 4):** Montañas Heladas, mascotas que crecen, el Huevo Gigante en equipo (después de probar con 2 jugadores y en celular), un huevo de temporada y la vitrina.

## 4. Seguridad y reglas de Roblox

- **Premios al azar pagos (como los tiros de ruleta):** Roblox obliga a mostrar las probabilidades antes de pagar, y la ruleta ya las muestra. Algunos países los prohíben: ahí el cartel se esconde, según `PolicyService` (el servicio de Roblox que dice qué se permite en cada país).
- **Precios chicos y claros:** "Balsa · 49 Robux", nunca "¡Comprá ya!". Siempre con un "No, gracias" visible.
- **Sin apuro:** las ofertas pagas no llevan relojes ni "¡NUEVO!", y no aparecen antes de la segunda partida ni de los 30 minutos de juego. Esto vale cuando sea real; en modo desarrollo los carteles se ven siempre, para que los pruebes.
- **Nadie paga para ganar:** a todo se llega jugando (por ejemplo, caminando en vez de en balsa).
- **Las compras las revisa siempre el servidor** (la computadora de Roblox que maneja la partida), nunca el celular del chico.
- **Nada es real hasta que vos lo apruebes**, en una tarea aparte.

## 5. Qué decidís vos

1. **¿Confirmás la balsa y los tiros de ruleta con Robux,** aunque el documento de economía los prohibía? La otra opción es dejar la balsa como atajo con camino gratis.
2. **¿Querés las metas del día (T8)?**
3. **¿Das permiso para subir modelos de criaturas nuevas (T10)?**
4. **¿Cambiamos el orden?** Por ejemplo, el álbum antes que las metas.

**Primera tarea recomendada:** P0.1, el kit de estilo. Es lo que más vas a notar, y todo lo que venga después ya sale con la cara de tu imagen. Justo después, T1: el rango "Aprendiz" y su tarjeta "¡Ladronzuelo!".

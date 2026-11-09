# Wildbound — Riesgo, pérdida y protecciones (decisión usuario 04-11-2026; v0.3)

## Decisiones CONFIRMADAS
- Si la expedición termina en derrota, el jugador pierde los huevos y las criaturas obtenidas/cargadas durante esa salida que no hayan sido asegurados por refugio o protección.
- Conserva la mayoría de recursos, perdiendo solo una pequeña parte.
- Debe existir una vía de adquirir objetos/mejoras/tótems que eviten perder un huevo o criatura, por expedición o por un número limitado de derrotas/usos.
- Ganar habilidades y preparar la expedición son componentes centrales de Wildbound.

## Decisión A CONFIRMADA
Los **pets ya eclosionados y registrados en la colección nunca se pierden** por derrota, incluso si se llevan equipados a la expedición. Solo se pierden huevos y ejemplares nuevos no extraídos ni protegidos. No ofrecer una opción de borrar mascotas persistentes como consecuencia de morir.

## Configuración de balance PROVISIONAL del MVP
- `resourceLossFraction=0.12` de materiales obtenidos en la salida, redondeo hacia abajo por pila. Probar 0.10-0.15; no restar moneda/monetización de base.
- `loseUnprotectedEggs=true`, `loseUnprotectedCapturedSpecimens=true` después de derrota definitiva.
- `bankedPetLossMode=never_on_defeat` CONFIRMADO; cualquier pet persistente de la colección está protegido contra derrota, equipado o no.
- Revivir por aliado antes del estado `Failed` evita resolver pérdidas; en `Failed` se evalúa una sola vez por `failureOperationId`.
- Refugio permite asegurar un objeto temporal antes de derrota, sujeto a los límites de diseño del refugio. Cuando queda bancado se sustrae del inventario de expedición de forma idempotente.

## Productos de protección — prototipo SOLO obtenibles jugando
1. **Sello de Resguardo**: el jugador designa 1 `eggUid` o `specimenUid` concreto como protegido. 1 carga para evitar una pérdida en derrota. Se consume si realmente salvó el objeto; no es una compra aleatoria.
2. **Amuleto de Expedición**: protección de 1 objeto durante 1 expedición; caduca cuando se extrae o termina la expedición, se consume al activarse antes de entrar. No apilar con copias iguales.
3. **Tótem del Último Aliento**: hasta 2 objetos designados protegidos; aumenta peso/intensidad de encuentros hostiles mientras se porta. Coeficiente x1.5 de peso como ejemplo, nunca publicidad engañosa de «50% más probabilidad» sin normalización.
4. **Mochila Reforzada**: mejora permanente, reduce pérdida propuesta de recursos de 12% a 8%, y agrega 1 slot para equipo protector. No protege por sí sola todos los huevos.
5. **Cápsula de Extracción**: permite asegurar 1 huevo en sitio especial/refugio; no funciona en cualquier lugar ni eclosiona remotamente.

## Reglas para evitar explotación y frustración
- Mostrar claramente antes de salir qué se pierde, qué queda protegido y qué ocurrirá en una derrota, tanto en móvil como en PC.
- Protección dirigida al UID de objeto, no a una «rareza» manipulable desde cliente. Si no hay selección, solicitar confirmación en UI o aplicar preferencia de riesgo conocida, nunca reasignación oculta.
- No consumir dos cargas en un mismo evento; ni duplicar objetos por spam, rejoin, muerte simultánea o servidor caído.
- Sin softlock: siempre poder conseguir de nuevo medios gratuitos de explorar, capturar y fabricar al menos una protección básica. No forzar Robux.
- Desconexión: no tratar una caída de app o servidor como derrota castigable automática. Definir política de sesión/TTL para impedir que salir del juego se use como extracción gratuita. Si hay incertidumbre de persistencia, optar por estado pendiente y reintentos, no borrar premios definitivamente por fallos técnicos.
- En cooperativo, un revivido no pierde el botín por el mero hecho de caer; cuando se confirma derrota individual, cada jugador resuelve SOLO sus objetos. No permitir que otro jugador destruya directamente los pets guardados.
- No perder por fallas conocidas de streaming, teletransporte o daño sin señales perceptibles.

## Economía y políticas
- Para el MVP, protección y eclosión mediante materiales/moneda obtenidos únicamente jugando. NO vender moneda que financie recompensas aleatorias ni protección de random drops con Robux sin revisión jurídica/política específica.
- Roblox trata huevos, cofres, boosts de suerte y modificadores de chances adquiridos directamente/indirectamente con Robux como posibles artículos aleatorios pagados. Si después se monetiza un seguro que permita conservar botín aleatorio, se requiere evaluar si implica acceso indirecto a recompensas aleatorias pagadas, odds reales, `PolicyService` y elegibilidad ANTES de implementarlo. Priorizar cosméticos de resultado garantizado.
- Fuente oficial: https://create.roblox.com/docs/production/monetization/paid-random-items

## Estados de implementación
`Home -> Preparing -> ExpeditionActive -> Downed -> Revived | Defeated -> ResolveRisk -> Home`
`ExpeditionActive -> ShelterBank -> ExpeditionActive | Home` y `ExpeditionActive -> Extraction -> Banked`.
`ResolveRisk` es determinista e idempotente: primero identificar ítems bancados, luego protegidos por UID, después eliminar temporales no protegidos y descontar materiales, finalmente persistir y emitir resultado.

## Pruebas obligatorias
- Sin protección: muerte pierde dos huevos y una criatura temporal, conserva el 88% de 100 unidades de un recurso; nunca pierde moneda de base.
- Sello 1 carga para UID elegido: conserva ese UID, pierde el resto; consume exactamente 1 carga una sola vez.
- Amuleto de expedición: cubre solo la salida actual; no se puede reutilizar al reloguear.
- Tótem de dos objetos: respeta selección, se mantiene el coste de riesgo, sin acumulación infinita ni error de tablas de encuentro.
- Refugio asegura el huevo antes de perder el resto; doble toque no duplica.
- Pruebas con 1, 2, 4 jugadores; rebajar latencia; desconexión/servidor caído; errores de guardado; doble muerte y `RemoteEvent` repetido.
- UI móvil muestra número de cargas, ítem seleccionado y riesgo sin texto diminuto.

## Interacción con noche v0.4
- La noche puede aumentar guardianes y recompensas en zonas de terror, pero NO cambia el porcentaje de materiales perdidos al morir por sí misma, ni los derechos de propiedad de pets registrados.
- Las probabilidades de derrota pueden cambiar por enemigos más peligrosos; la protección es elegible antes de salir y se aplica de forma idéntica de día y de noche.
- Asegurar el huevo en un refugio transfiere su estado a persistente con operación idempotente; la noche no invalida la protección.

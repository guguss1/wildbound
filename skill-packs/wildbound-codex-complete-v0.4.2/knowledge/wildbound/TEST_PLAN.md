# Lista de pruebas del prototipo
## Captura y economía
- 2 jugadores intentan capturar una criatura al mismo tiempo: un único resultado por recurso.
- Doble tap y spam de RemoteEvent no duplican huevos o pets.
- Si el servidor se cierra tras asegurar botín, el inventario está consistente al reiniciar.
- Egg outcome fijado al recoger no se rerollee al reiniciar eclosión.
- Ningún dato de rareza/éxito enviado por cliente otorga loot si servidor no lo validó.
## Compañeros
- Cambiar pet durante cooldown se rechaza; sin pet activo, habilidad no se ejecuta.
- Un compañero visible como máximo por jugador, sin instancias huérfanas tras respawn o desconexión.
- Pet revela Silueta durante ventana temporal; no la elimina. Guardian vuelve al estado apropiado luego.
- Pet ya eclosionado y registrado NO puede perderse por derrota, incluso equipado. Probar derrota de día, de noche y con reconexión; jamás borrar pet persistente.
- Los pets no producen ventajas acumuladas infinitas en 4 jugadores.
## Mundo / móvil
- 1, 2, 4 jugadores; touch en pantallas chicas; cambio de mascota y captura utilizables con una mano si es posible.
- Monstruos solo atacan cuando realmente están cargados y sus señales son observables; streaming no genera daño invisible sin counterplay.
- Medir frames, memoria, tiempo de carga y latencia en teléfono real antes de fijar presupuestos.

## Derrota y seguros — v0.3
- 2 huevos + 1 espécimen, sin seguro: pérdida de los tres; perder 12 de 100 materiales, conservar moneda de base.
- Sello de 1 carga seleccionado: conservar 1 UID exacto, descontar 1 carga una sola vez por `failureOperationId`.
- Dos clientes mueren a la vez: no mezclar inventarios, seleccionar ni consumir pólizas ajenas.
- Tótem de 2 plazas con coste de mayor exposición hostil: no alterar la propia tabla por accidente; no apilar gratis.
- Refugio asegura un huevo previamente; después un fallo no lo elimina.
- Reconexión/cierre durante `ResolveRisk`: no duplicar ni borrar pet almacenado; no tratar caída técnica como derrota.
- Prueba móvil: UI indica claramente antes de salir qué objetos se perderían y qué protección está equipada.

## Día y noche — v0.4
- Comprobar ciclo de 20 minutos con fases 10/2/6/2 y sincronía de clientes que ingresan tarde; en producción valores de duración ajustables.
- En día, noche y transiciones con `fog`: verificar tasa de guardianes, rareza y recursos mediante simulaciones reproducibles y normalización; especies de `crypt` no aparecen en `fog` salvo que el catálogo permita ambas.
- `forest`, `snow` y `volcano` cambian iluminación sin recibir boosts de terror por defecto. `fog`, `crypt`, `abyss` sí, según disponibilidad; MVP solo `fog`.
- No aplicar a la vez tabla nocturna específica y multiplicador de rareza sin verificar doble conteo.
- No permitir spawns hostiles en refugios, campamento, rutas sin salida o personajes recién cargados por streaming.
- Noche con 1/2/4 jugadores, teléfono de gama baja, audio desactivado, visibilidad limitada, rejoin, horario avanzado y cambios de fase en persecución.
- Noche no afecta la invariante de pérdida tipo A ni provoca eliminación de mascotas registradas.

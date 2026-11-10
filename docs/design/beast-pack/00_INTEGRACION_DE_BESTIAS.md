# PROMPT MAESTRO — INTEGRAR CUATRO BESTIAS EN WILDBOUND (ROBLOX)


## REQUISITO VISUAL PRIORITARIO — REFERENCIAS ROBLOX ACTUALIZADAS

Antes de implementar los NPC, abrir `03_REFERENCIAS_VISUALES/00_MODELOS_4_BESTIAS_ROBLOX.png` y las fichas individuales. Estas referencias **reemplazan por completo la estética realista de cualquier arte previo**. Los cuatro modelos deben compartir geometría angular/facetada, colores planos/pintados, formas exageradas y ojos de emisión controlada. No usar texturas fotográficas ni mallas hiperrealistas.

Las fichas ilustran modelos 3D, NO assets exportados. La IA implementadora debe construir meshes/rigs reales o placeholders claramente identificados y demostrar el resultado dentro de Roblox Studio. Para modelado externo, usar los archivos `05_PROMPTS_MODELADO_3D`. No copiar modelos de DOORS, Creatures of Sonaria ni UGC de terceros: solo estudiar su nivel de simplificación y lectura visual.

## Rol, contexto y resultado que exijo

Sos un equipo senior de desarrollo de videojuegos para Roblox Studio: programación Luau, arquitectura cliente-servidor, diseño de IA de enemigos, animación, VFX, optimización, diseño de combate telegráfico, testing y arte 3D stylized. **Tu tarea es construir y dejar jugables** cuatro bestias: **Viper, Pouncer, Gargoyle y Mire**, siguiendo los archivos de prompt individuales y las imágenes adjuntas. Este mensaje NO pide un GDD, ideas generales o ejemplos cortos: pide implementación real dentro del proyecto existente **Wildbound**, un juego Roblox de expediciones peligrosas donde los jugadores buscan huevos, pueden regresar a base y pueden sufrir pérdidas al morir. No rompas los sistemas anteriores.

## Primera fase obligatoria: auditar el proyecto antes de escribir

1. Analizá qué existe actualmente en `ServerScriptService`, `ServerStorage`, `ReplicatedStorage`, `StarterPlayerScripts`, `Workspace`, modelos NPC, biomas, sistemas de clima/día-noche, daño, huevos, bases y zonas seguras. Buscá código compartido del director de amenazas, spawner, enemigos, hitboxes y RemoteEvents.
2. Enumerá en pocas líneas los módulos existentes que vas a **reutilizar**. Si hay otros monstruos, **no los borres, renombres ni reemplaces**. Conservá el árbol real del proyecto.
3. Si ya existe un sistema de spawn, extendelo: **NO crees un segundo scheduler paralelo que duplique tiradas y spawns**. Si no hay sistema, implementá uno modular.
4. Si no hay biomas detectables, implementá volúmenes invisibles/taggeados para Cementerio (`Cemetery`) y Pantano (`Swamp`). Hacé detección del lado servidor incluso para partes rotadas; nunca confiar en un booleano de bioma que envía el cliente.
5. Si faltan modelos 3D definitivos, construí proxies jugables estilizados con Parts/MeshParts simples, colisiones correctas, VFX visibles y controladores completos. Separá arte de comportamiento para poder sustituirlos después sin reescribir IA. Si podés generar/importar modelos definitivos, optimizalos.
6. Si no tenés acceso al proyecto, **decilo** y entregá archivos Luau completos, jerarquía exacta, pasos de instalación y comandos/pruebas; no finjas ejecución.

## Contrato funcional común — un Creature Director por jugador

### Tiradas y elegibilidad

- En el servidor, cada **10 segundos**, para cada jugador vivo y fuera de zona segura, evaluá **cada bestia elegible** mediante una tirada independiente.
- `baseChance` se expresa como probabilidad de 0 a 1 por tirada (ejemplo `1/100` = 1% cada 10 s, NO 1% por segundo). `math.random()` u otro RNG de servidor válido; proveé una semilla de test inyectable sin alterar azar de producción.
- Aplicá: `pEfectiva = clamp(pBase * multiplicadorTotal, 0, MAX_CHANCE)`. Propuesta `MAX_CHANCE = 0.20` por bestia y tick (configurable). No redondear a enteros ni convertir multiplicadores en porcentajes accidentales.
- Ejemplos configurables: día x1; noche x2; tormenta x1.5; lejos de base x1.2; zona peligrosa x1.5; expedición prolongada x1.3. **Producto limitado a x4** para balance. Las condiciones deben venir de estados reales del servidor; si alguno de los sistemas aún no existe, usar x1 y dejar integración limpia, no inventar eventos.
- Para bestias de bioma, exigí estar físicamente dentro del bioma correspondiente (y condiciones especiales de spawn). Globales pueden aparecer en ambos y en otros biomas seguros para navegación, nunca dentro de la base.
- No hay garantía de spawn ni «contador mágico» salvo que se agregue explícitamente como opción deshabilitada. Evitá que se acumule una cola infinita de tiradas ganadas: si no hay presupuesto, la oportunidad se descarta o se posterga con un límite estricto.
- Si ganan dos tiradas en el mismo tick, evaluá presupuesto, máximo concurrente, elegibilidad y fairness; asigná en orden aleatorio estable y registrá motivos de rechazo para debug.

### Presupuesto de amenaza

- Por jugador: `maxThreatPoints = 3`; `maxActiveEncounters = 2`.
- Costos: Viper=1, Pouncer=1, Gargoyle=2, Mire=2.
- Antes de confirmar spawn, reservá el presupuesto **atómicamente en servidor** para evitar exceso por apariciones simultáneas, callbacks o race conditions.
- Liberá exactamente una vez el costo cuando el encuentro finaliza por muerte, escape, vencimiento, salida de bioma, regreso a base o desconexión.
- No permitir dos instancias de la misma bestia activas para el mismo jugador salvo configuración futura.
- Cooldown global tras encuentro: propuesta 15 s; cooldown específico por bestia: 30–60 s configurable. No permitir spawns dentro de 10 s tras respawn.

### Cada bestia tiene dueño de encuentro

- `targetUserId` y `encounterId` únicos asignados en servidor. Un resultado del RNG de Jugador A **no crea** un encuentro para Jugador B.
- Un ataque solo puede dañar al objetivo asignado, si ese objetivo sigue vivo, en alcance, en el encuentro y sin inmunidad aplicable. NUNCA dañar personajes cercanos por accidente.
- **Preferencia de diseño del proyecto**: únicamente el jugador objetivo ve y oye a su criatura. Para implementarlo de forma segura, el servidor mantiene la simulación autoritativa (posiciones, telegraphs, raycasts, estados, daño); `RemoteEvent:FireClient(targetPlayer,...)` envía eventos y snapshots cosméticos; el cliente crea un clon visual local de un modelo de `ReplicatedStorage` y lo interpola. Si el proyecto ya posee otro protocolo de instancias personales robusto, adaptalo, pero explicá cómo preservás exclusividad y autoridad. Evitá crear un NPC físico visible para todos cuando se pidió exclusividad.
- Si usás representación física invisible en servidor, evitá network ownership del cliente y colisiones físicas peligrosas. El server debe calcular hitboxes y daño independientemente del render del cliente.
- No enviar un mensaje por cada frame a cada cliente: preferir snapshots compactos con interpolación local a 5–12 Hz y eventos discretos para fases, con reconciliación si hay lag. La señal de ataque debe coincidir con la ventana real de daño en la simulación de servidor.
- Un cliente malicioso jamás puede solicitar `SpawnBeast`, confirmar `HitPlayer` o decidir que esquivó un golpe. Todos esos resultados se verifican en servidor.

### Máquina de estados y ciclo completo

Cada encuentro debe tener explícitamente `Spawn/Intro → Alert/Telegraph → Attack → Recovery → Reposition/Chase → End` según su especie. Evitá bucles infinitos y `wait()` en cascada sin cancelación. Usá tokens de cancelación y un `EncounterManager` que limpie tasks, conexiones, tween/sounds/particles, visuales cliente, referencias y amenaza incluso si hay errores.

Señales de finalización: muerte del jugador, desconexión, regreso a zona segura, cambio de bioma para especies exclusivas (con un período de gracia corto si corresponde), distancia de escape sostenida, encuentro terminado por duración máxima, destrucción del modelo o error controlado. El evento `EncounterEnded` es idempotente.

### Aparición y navegación creíbles

- Posición inicial usual: 35–85 studs del jugador, detrás de vegetación, piedra o terreno si es posible; nunca en el techo o dentro de geometría, nunca dentro de base ni encima del avatar. Validar suelo, colisiones, distancia, bioma y accesibilidad.
- Cada especie puede ajustar esta regla. Mire necesita agua marcada como válida; Gargoyle requiere percha o espacio aéreo sobre Cementerio.
- Los modelos deben verse al llegar a render; no aparecer mágicamente superpuestos al jugador. Sonido de advertencia y ventanas de reacción visibles.
- Para navegación terrestre con obstáculos, usar PathfindingService según corresponda; no recalcular rutas por frame y contemplar `Path.Blocked`. Para vuelo o agua, usar controladores especializados con raycasts y límites.

### Daño y huevos

- El servidor es fuente de verdad para HP, ataque, invulnerabilidad y derrota. Daños de referencia configurables, no instakill injusto como comportamiento por defecto.
- Integrar daño mediante la API/servicio de daño ya existente. Si hay `DamageService`, usarlo; si no, crear un pequeño adaptador compatible con `Humanoid:TakeDamage()` y validación adicional.
- No escribir un nuevo sistema de pérdida de huevos: una muerte causada por monstruo debe disparar la lógica de muerte/expedición que ya tiene Wildbound. Si hoy no existe, ofrecer un hook o evento (`OnPlayerKilledByBeast`) pero no inventar un inventario paralelo.
- Opcional: cuando un jugador carga un huevo, rastro sonoro/visual especial **solo si la mecánica de huevos existente ofrece ese dato del servidor**; no aumentar las probabilidades por llevar huevo sin aprobación.

### UX, terror y mobile

- Estilo: **Roblox stylized dark fantasy**, inspirado en siluetas expresivas y materiales pintados a mano; no buscar hiperrealismo ni copiar IP de otros juegos. Contraste alto en el telegraph; rojo señal de peligro, geometrías suficientemente gruesas para pantalla móvil.
- Un aviso no dependerá solamente del color: acompañar con sonido, forma y animación. Volúmenes y efectos ajustables.
- Efectos locales: audio 3D, partículas con límites, cámara leve, luces discretas. Sin flashing intenso, sacudidas prolongadas ni blur indiscriminado.
- Dejar una opción/atributo para reducir screen shake, partículas y efectos visuales, sin quitar señales esenciales.
- Los jugadores que no son objetivo no reciben sonidos ni VFX de esa bestia; otros jugadores sí deben observar cambios legítimos de HP/estado del objetivo si el juego ya los replica.

### Rendimiento, calidad y robustez

- Nada de `Heartbeat` pesado por cada criatura sin frecuencia controlada. Actualizaciones por intervalos adecuados y colisiones optimizadas con spatial queries/raycasts y filtros.
- Limitá partículas, sonidos simultáneos, raycasts de comprobación y piezas sin anclar. No depender de plugins de terceros ni asset IDs inexistentes. Modelos de placeholder claros si faltan meshes.
- Acceso seguro para streaming/instancias aún no replicadas, estados durante respawn, character sin HumanoidRootPart, lag, teleport, zona cambiada, reinicio del Studio y explosiones de concurrencia.
- `CollectionService` / Attributes pueden etiquetar zonas, perchas y agua. No modificar scripts globales de día/noche o inventario salvo punto de integración pequeño y documentado.
- Código Luau tipado cuando sea razonable, módulos pequeños, sin dependencias circulares, comentarios útiles y configuración central editable.

## Árbol orientativo, ajustable al proyecto existente

```
ReplicatedStorage/
  WildboundBeasts/
    Shared/BestiaryConfig.lua
    Shared/BeastTypes.lua
    Models/ViperVisual | PouncerVisual | GargoyleVisual | MireVisual
    Remotes/BeastVisualEvent
ServerScriptService/
  WildboundBeasts/
    CreatureDirector.server.lua
    Modules/EncounterManager.lua
    Modules/BiomeResolver.lua
    Modules/SpawnLocator.lua
    Modules/ThreatBudget.lua
    Modules/DamageAdapter.lua
    Controllers/Viper.lua
    Controllers/Pouncer.lua
    Controllers/Gargoyle.lua
    Controllers/Mire.lua
StarterPlayer/StarterPlayerScripts/
  WildboundBeasts/BeastPresentation.client.lua
Workspace/
  BeastZones/     (Parts invisibles con Attribute Biome)
  BeastPerches/   (puntos etiquetados para Gargoyle)
  BeastWater/     (volúmenes etiquetados para Mire)
```

**Importante:** si el proyecto ya tiene estructura equivalente, reutilizala en vez de crear exactamente ese árbol. Solo debe existir una autoridad de spawn.

## Orden de desarrollo ejecutable

1. Auditoría y adaptadores reales.
2. `BestiaryConfig`, presupuesto y registro de encuentros independientes por jugador.
3. Resolución de biomas, agua/perchas y spawn locator con fallback seguro.
4. Protocolo server→cliente para modelos cosméticos, telegraphs y terminación; snapshots interpolados.
5. Viper completa y testeada.
6. Pouncer completa y testeada.
7. Gargoyle completa y testeada en Cementerio.
8. Mire completa y testeada en Pantano.
9. QA multijugador, estrés, mobile, respawn, desconexión, exploits y limpieza.
10. Reporte final honesto: lista de archivos creados/modificados, diferencias con diseño, pruebas realmente ejecutadas, fallos, pasos pendientes y cómo reproducir.

## Criterios de aceptación de entrega global

- Cuatro bestias visibles, con nombres, animaciones/proxies, audio y efectos de aviso.
- Cada una tiene un loop de ataque **distinto y funcional**: Viper embestida, Pouncer salto con círculo, Gargoyle tornado y Mire acecho acuático/emergencia.
- Las tiradas de bestias y los multiplicadores se pueden forzar en un modo debug y también funcionan aleatoriamente en producción.
- Con 2 clientes: si solo A recibe la bestia, B no la ve ni oye ni recibe daño. Con 3 clientes: dos pueden tener amenazas diferentes sin mezclar estados.
- La suma de threat points nunca supera 3; nunca más de 2 encuentros por jugador; sin `encounterId` duplicados ni fugas al morir o salir.
- Las bestias de bioma nunca se activan fuera de su bioma; zonas seguras bloquean daño/spawn.
- Esquivar realmente evita el daño en servidor; nunca hay daño antes del warning reglamentario.
- Al eliminar el encuentro desaparecen modelo, audio, VFX, hitboxes y listeners y se libera presupuesto una única vez.
- Integración no destructiva con huevos, muerte y juego existente; código documentado, configurable y reproducible.

**Entregá el trabajo.** No te limites a explicarme cómo se haría. Si estás imposibilitado para entrar al entorno, entregá los archivos completos listos para copiar y un plan exacto de instalación sin afirmar que los ejecutaste.

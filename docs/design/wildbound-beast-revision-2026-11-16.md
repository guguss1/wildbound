# WILDBOUND — Revisión y especificación de bestias

## Objetivo general

Actualizar las bestias existentes para que cada una tenga una identidad visual, una forma de atacar y una persecución claramente diferenciadas. La dificultad debe venir de sus mecánicas y de la presión que generan, no de errores, teletransportes injustos o ataques imposibles de leer.

**Importante para la implementación:**
- Revisar primero los scripts, estados, animaciones, hitboxes y valores actuales de cada bestia.
- Modificar las bestias existentes; no crear duplicados ni cambiar sus nombres internos sin comprobar las dependencias.
- Mantener todos los valores importantes configurables (velocidad, alcance, radio, duración, cooldown, distancia de activación, etc.).
- No romper el sistema actual de aparición, dificultad, puntos de amenaza, zonas seguras, muerte o respawn.
- Si un detalle de esta especificación contradice una mecánica compartida ya implementada, señalar el conflicto y proponer el cambio mínimo antes de sobrescribirla.

---

## 1. Reglas globales para todas las bestias

### 1.1 Persecución persistente

Cuando una bestia se active contra un jugador, debe mantener la persecución hasta que ocurra una de estas condiciones:

1. El jugador muere.
2. El jugador entra en una zona segura válida.

No debe abandonar la persecución simplemente porque el jugador se aleje, doble una esquina, salga del campo de visión o pase un tiempo sin ser visto. La IA debe conservar el objetivo y actualizar su ruta para intentar alcanzarlo.

### 1.2 Zonas seguras

- La zona segura debe ser reconocida por un sistema común, no mediante comprobaciones diferentes e inconsistentes en cada bestia.
- Al detectar que el objetivo entró realmente en una zona segura, la bestia debe cancelar la persecución y ejecutar el comportamiento de salida/desactivación que ya use el juego.
- La bestia no debe atacar, aplicar efectos ni teletransportarse dentro de la zona segura.
- Evitar que la bestia pueda golpear al jugador desde fuera atravesando el límite de la zona segura.
- Al salir el jugador, aplicar las reglas actuales de reactivación/aparición. No crear una reactivación instantánea injusta si el sistema actual contempla un intervalo.

### 1.3 Objetivo y cambio de objetivo

- Cada bestia debe tener un objetivo claro y persistente.
- No cambiar de objetivo aleatoriamente durante una persecución.
- Si el jugador muere o entra en zona segura, limpiar correctamente el objetivo y detener los ataques pendientes.
- Evitar que una bestia siga persiguiendo un personaje muerto, un personaje que ya no existe o una referencia antigua tras un respawn.

### 1.4 Lectura y justicia de los ataques

- Los ataques deben tener animaciones y señales visuales/sonoras coherentes.
- La señal previa debe ser suficiente para entender qué está pasando, pero no tan larga que el ataque resulte trivial.
- No reducir el tiempo de reacción cuando el pedido sea aumentar la velocidad de ejecución del ataque. Son parámetros distintos.
- Los efectos de control (lentitud, inmovilización) deben tener duración configurable y no acumularse infinitamente.
- Los impactos deben validarse con hitboxes consistentes y no depender solo de efectos visuales.

---

## 2. VIPER

### Identidad buscada

Una criatura más grande que el jugador, intimidante y reconocible por su embestida. Debe sentirse como un depredador que prepara el ataque y luego se lanza a gran velocidad.

### Cambios solicitados

1. **Tamaño**
   - Hacer que Viper sea visiblemente más grande que el personaje del jugador.
   - Escalar el modelo completo de forma consistente: cuerpo, colisiones, hitboxes y efectos.
   - Comprobar que no atraviese el suelo ni se atasque por el nuevo tamaño.

2. **Animación**
   - Añadir o completar las animaciones que falten.
   - Como mínimo: reposo/desplazamiento, preparación de embestida, embestida, impacto/fallo y recuperación.
   - La animación de embestida debe sincronizarse con el desplazamiento real del NPC.

3. **Embestida más rápida y más larga**
   - Aumentar la velocidad durante la fase en la que Viper ya está embistiendo.
   - Aumentar la distancia máxima recorrida por la embestida.
   - **No acortar el tiempo de reacción del jugador:** conservar la duración actual de aviso/preparación, salvo que una prueba demuestre que necesita un ajuste separado.
   - Separar y exponer como parámetros: duración de preparación, velocidad de embestida, distancia máxima, duración de recuperación y cooldown.

4. **Efecto de impacto: lentitud**
   - Si la embestida golpea al jugador, aplicar un efecto de lentitud.
   - La duración y la intensidad deben ser configurables.
   - El efecto debe tener un límite claro y no acumularse sin control si Viper golpea varias veces.
   - El efecto debe terminar correctamente al cumplirse su duración, al morir el jugador o cuando corresponda según el sistema de estados del juego.

### Criterios de aceptación

- Viper se ve claramente más grande que el jugador.
- La animación acompaña la embestida y no queda desincronizada.
- La embestida recorre más distancia y se ejecuta más rápido, pero conserva una ventana de reacción legible.
- Un impacto confirmado aplica lentitud; un fallo no la aplica.

---

## 3. POUNCER

### Identidad buscada

Una araña grande, con silueta y proporciones que recuerden a una tarántula. Su salto debe generar presión en un área amplia y, al aterrizar, debe poder atrapar al jugador con una telaraña.

### Cambios solicitados

1. **Apariencia y tamaño**
   - Aumentar el tamaño para que sea claramente más grande que el jugador.
   - Rediseñar o ajustar el modelo para que se parezca más a una tarántula: cuerpo de araña robusto, abdomen reconocible y ocho patas articuladas.
   - Mantener una silueta legible desde la distancia.

2. **Área de impacto del salto**
   - Aumentar el radio del área en la que el salto puede golpear.
   - La hitbox debe corresponder al área visual/indicada del aterrizaje.
   - Evitar que el área sea tan grande que alcance al jugador fuera de la zona que razonablemente parece peligrosa.
   - Hacer que el radio sea configurable.

3. **Nuevo ataque: bola de telaraña al aterrizar**
   - Cada vez que Pouncer complete un salto y aterrice, debe lanzar una bola de telaraña hacia el objetivo.
   - La bola debe tener una trayectoria y un efecto visual claramente reconocibles.
   - Si impacta al jugador, lo deja inmovilizado durante **1 segundo**.
   - Si falla, no debe inmovilizar ni afectar al jugador.
   - La bola debe desaparecer al impactar, al alcanzar su distancia máxima o al expirar su tiempo de vida.
   - Evitar que un mismo aterrizaje genere más de una bola por error.

4. **Estados y animaciones**
   - Asegurar animaciones diferenciadas para preparación, salto, caída/aterrizaje y lanzamiento de telaraña.
   - El lanzamiento debe ocurrir después de confirmar el aterrizaje, no antes.
   - Evitar que el lanzamiento se dispare si Pouncer fue desactivado, eliminado o perdió válidamente su objetivo antes de aterrizar.

### Criterios de aceptación

- Pouncer se reconoce visualmente como una tarántula grande.
- El área de impacto es mayor y consistente con el aterrizaje.
- Cada aterrizaje válido produce una sola bola de telaraña dirigida al objetivo.
- Un impacto inmoviliza exactamente 1 segundo; un fallo no aplica el efecto.

---

## 4. SCREAMER (antes llamado “Streamer”)

### Cambio de nombre

El nombre correcto para mostrar al jugador es **Screamer**, no Streamer. Revisar referencias, configuración, interfaz, registros y documentación antes de cambiar identificadores internos. Si otros sistemas dependen del identificador antiguo, mantener compatibilidad o migrarlo de forma segura.

### Identidad buscada

Screamer debe parecer inicialmente una estatua inquietante. No debe embestir ni usar el grito como ataque de daño. El grito es el momento de transformación y activación de la persecución.

### Comportamiento por estados

**Estado A — Estatua inactiva**
- Permanece quieto y parece una estatua.
- Su apariencia inicial debe ocultar o disimular su verdadera naturaleza.
- No persigue ni ataca antes de que el jugador entre en su distancia de activación.

**Estado B — Activación**
- Cuando el jugador se acerca lo suficiente, Screamer comienza a gritar.
- El grito debe funcionar como señal de activación y transformación, no como un ataque que haga daño.
- Durante esta transición debe mostrar su verdadera forma.
- La distancia de activación debe ser configurable.

**Estado C — Persecución**
- Después de transformarse, persigue al jugador con mucha velocidad.
- No embiste para hacer daño: su amenaza principal es perseguir y alcanzar al jugador.
- El grito inicial no debe causar daño.
- Mantiene la persecución hasta que el jugador muera o entre en una zona segura.

### Teletransporte de reposicionamiento

Una vez activado contra un jugador, Screamer puede reposicionarse mediante teletransportes para evitar que el jugador lo pierda de vista y pueda pasar junto a él sin darse cuenta. Este sistema debe sentirse como una capacidad sobrenatural, no como un teletransporte injusto.

Reglas obligatorias:
- Teletransportarse únicamente durante una persecución activa.
- Elegir una posición válida, navegable y cercana al jugador, sin aparecer encima de él ni dentro de su hitbox.
- No teletransportarse dentro de una zona segura ni atravesar sus límites para atacar.
- No teletransportarse directamente a una posición que produzca un impacto instantáneo.
- Respetar un cooldown configurable y una distancia mínima/máxima de reposicionamiento.
- Evitar posiciones bloqueadas, dentro de paredes, bajo el mapa o fuera del área jugable.
- Si no existe una posición válida, cancelar ese intento y continuar la persecución normal.
- Dar una señal audiovisual breve y coherente cuando el reposicionamiento sea perceptible; no hace falta revelar siempre la posición exacta.
- No usar el teletransporte para reiniciar la persecución ni para cambiar de objetivo.

### Criterios de aceptación

- Antes de activarse, Screamer se comporta como una estatua.
- Al acercarse el jugador, grita, revela su forma verdadera y comienza a perseguirlo.
- Es muy rápido y no realiza embestidas ni gritos dañinos.
- El reposicionamiento ocurre solo durante una persecución y nunca permite aparecer dentro del jugador, en una zona segura o en una posición inválida.

---

## 5. ROOT

### Identidad buscada

Una criatura grande, de tonos marrones, asociada a raíces reales que emergen del terreno. Debe ser más amenazante porque puede controlar el espacio y cerrar rutas de escape.

### Cambios solicitados

1. **Color y tamaño**
   - Cambiar la paleta principal hacia tonos marrones: tierra, madera oscura y raíces.
   - Aumentar el tamaño del modelo.
   - Mantener contraste suficiente entre Root, sus raíces y el entorno para que sus ataques puedan leerse.

2. **Raíces de mayor alcance**
   - Aumentar la distancia a la que puede lanzar/emergir raíces.
   - Las raíces deben parecer raíces reales: formas orgánicas, irregulares, ramificadas y conectadas visualmente con el suelo.
   - Evitar que parezcan líneas rectas o piezas genéricas que aparecen sin conexión con el terreno.
   - Asegurar que el efecto visual y la hitbox coincidan.

3. **Encierro más difícil de esquivar**
   - Aumentar la velocidad de ejecución del ataque de encierro.
   - Reducir el tiempo entre el inicio del ataque y su resolución, sin eliminar toda señal legible.
   - Ajustar la velocidad de las raíces y el tiempo de cierre para que el jugador tenga que reaccionar con rapidez.
   - Comprobar el ataque en movimiento y en distintas distancias; no debe ser trivial escapar caminando, pero tampoco debe ser inevitable si el jugador reacciona correctamente.

4. **Parámetros configurables**
   - Alcance de raíces.
   - Velocidad de aparición/avance.
   - Tiempo de cierre del encierro.
   - Duración del encierro, si aplica.
   - Cooldown del ataque.

### Criterios de aceptación

- Root tiene una apariencia más grande y marrón.
- Las raíces tienen apariencia orgánica y alcanzan más lejos.
- El ataque de encierro es más rápido y exigente, pero conserva una oportunidad razonable de reacción.

---

## 6. GAZE

### Identidad buscada

Una criatura grande y negra que se camufla con el entorno. Su mecánica es de mirada: si el jugador la observa durante suficiente tiempo acumulado, muere instantáneamente.

### Cambios solicitados

1. **Apariencia y tamaño**
   - Aumentar su tamaño.
   - Usar una paleta muy oscura/negra para camuflarla con el entorno.
   - Mantener una silueta mínimamente reconocible para que el jugador pueda descubrir qué lo amenaza.

2. **Mecánica de mirada: eliminación instantánea**
   - Si el jugador mira a Gaze durante **3 segundos acumulados**, Gaze elimina al jugador instantáneamente.
   - No debe aplicar daño gradual: al completar el umbral, el resultado es muerte inmediata.
   - El contador debe acumular el tiempo de todas las miradas válidas durante el encuentro, incluso si el jugador aparta la vista entre ellas.
   - Apartar la mirada pausa la acumulación; no debe reiniciar el contador.
   - Al alcanzar los 3 segundos acumulados, ejecutar una sola vez el resultado de muerte y bloquear activaciones repetidas para ese encuentro.
   - El contador debe reiniciarse cuando el encuentro termina según las reglas del sistema de bestias (por ejemplo, al morir el jugador o entrar en una zona segura y cerrarse correctamente el encuentro).

3. **Detección de mirada**
   - Usar una comprobación consistente de que el jugador realmente está mirando a Gaze, no solo de que Gaze está cerca o dentro de la pantalla.
   - Tener en cuenta línea de visión: paredes y obstáculos opacos deben impedir que se acumule tiempo de mirada.
   - Evitar que una mirada a través de una pared o desde detrás de un obstáculo cuente.
   - El umbral de 3 segundos debe ser configurable, pero el valor inicial solicitado es 3.

4. **Feedback**
   - Dar una señal de peligro progresiva y clara mientras se acumula la mirada, sin convertirla en daño gradual.
   - La señal debe ayudar al jugador a comprender que mirar a Gaze es peligroso.
   - Al apartar la vista, la señal debe reflejar que el contador dejó de avanzar.

### Criterios de aceptación

- Gaze es grande, negro y se integra visualmente con el entorno.
- Mirarlo durante 3 segundos acumulados provoca una única eliminación instantánea.
- Apartar la vista pausa el contador, pero no lo reinicia.
- Las paredes y obstáculos opacos bloquean la detección de mirada.

---

## 7. LURKER

### Identidad buscada

Mantener la mecánica general actual, porque ya funciona bien, pero quitar los avisos que hacen que sea demasiado fácil anticipar su aparición o ataque.

### Cambios solicitados

- Eliminar los avisos actuales que revelan con demasiada anticipación cuándo aparece.
- Eliminar o reducir los avisos previos que permiten saber exactamente cuándo va a atacar.
- Mantener su comportamiento y mecánica principal actual salvo los cambios necesarios para quitar esas señales.
- No eliminar señales indispensables para que el juego funcione correctamente.
- Asegurar que, una vez que Lurker active una persecución contra un jugador, la mantenga hasta que el jugador muera o entre en una zona segura.

### Criterios de aceptación

- Lurker ya no anuncia de forma evidente su aparición o el momento exacto del ataque.
- Su mecánica central sigue funcionando como antes.
- Mantiene la persecución según las reglas globales.

---

## 8. Organización técnica recomendada

Antes de implementar, identificar si el proyecto ya tiene módulos compartidos para:
- Estados de las bestias.
- Selección y persistencia del objetivo.
- Detección de zonas seguras.
- Navegación y persecución.
- Hitboxes y validación de impactos.
- Efectos de estado del jugador (lentitud e inmovilización).
- Teletransporte/reposicionamiento.
- Detección de mirada.
- Configuración de estadísticas.

**Preferencia:** reutilizar los sistemas existentes y evitar crear seis implementaciones distintas de la misma lógica global.

### Parámetros que deben quedar configurables

No inventar valores definitivos para los parámetros que no fueron especificados. Primero inspeccionar los valores actuales y proponer una tabla de cambios para revisión. Los valores explícitos de esta solicitud son:

| Bestia | Parámetro | Valor/objetivo solicitado |
|---|---|---|
| Viper | Velocidad durante embestida | Aumentar |
| Viper | Distancia de embestida | Aumentar |
| Viper | Tiempo de preparación | No reducir por el mero hecho de acelerar la embestida |
| Viper | Efecto al impactar | Lentitud |
| Pouncer | Radio de impacto del salto | Aumentar |
| Pouncer | Inmovilización por telaraña | 1 segundo |
| Screamer | Daño del grito | Ninguno |
| Screamer | Velocidad de persecución | Muy alta |
| Screamer | Reposicionamiento | Permitido durante persecución, con validaciones y cooldown |
| Root | Alcance de raíces | Aumentar |
| Root | Velocidad de ataques | Aumentar |
| Gaze | Tiempo de mirada acumulado | 3 segundos |
| Gaze | Efecto al completar el umbral | Muerte instantánea |
| Lurker | Avisos de aparición/ataque | Quitar los avisos que anticipan demasiado |

---

## 9. Plan de implementación y pruebas

### Fase 1 — Auditoría
1. Localizar scripts, modelos, animaciones, hitboxes y configuración de cada bestia.
2. Identificar dependencias y sistemas compartidos.
3. Registrar los valores actuales antes de modificarlos.
4. Detectar qué animaciones faltan y qué ataques ya están implementados.

### Fase 2 — Implementación
1. Aplicar primero las reglas globales de persecución y zonas seguras.
2. Implementar los cambios visuales y de tamaño.
3. Implementar ataques y efectos individuales.
4. Conectar animaciones con los estados reales de cada bestia.
5. Centralizar los parámetros configurables.

### Fase 3 — Pruebas obligatorias
Probar cada bestia individualmente y luego varias en una misma sesión.

- **Persecución:** comprobar que no abandona al jugador por perderlo de vista o por alejarse.
- **Zona segura:** comprobar que cancela persecución y ataques al entrar; no puede atacar desde fuera hacia dentro.
- **Muerte/respawn:** comprobar que limpia objetivos, temporizadores, proyectiles y efectos pendientes.
- **Colisiones:** comprobar que las hitboxes coinciden con los ataques visuales.
- **Rendimiento:** comprobar que las nuevas comprobaciones de mirada, navegación y reposicionamiento no generan carga excesiva.
- **Multijugador:** comprobar que el estado de una bestia sobre un jugador no afecta por error a los demás jugadores.

### Pruebas específicas

| Bestia | Prueba |
|---|---|
| Viper | Recibe un impacto y aplica lentitud; esquiva la embestida y no recibe el efecto. |
| Pouncer | Salta, aterriza y lanza una sola bola; al impactar inmoviliza 1 segundo. |
| Screamer | Permanece como estatua hasta la distancia de activación; grita, se transforma y persigue sin hacer daño con el grito. |
| Screamer | Reposicionamiento válido: nunca aparece encima del jugador, dentro de una pared o en una zona segura. |
| Root | Las raíces alcanzan más lejos y el encierro se ejecuta más rápido; hitbox y efecto visual coinciden. |
| Gaze | Dos miradas separadas acumulan tiempo; al sumar 3 segundos elimina al jugador una sola vez. |
| Gaze | Una pared opaca bloquea el conteo de mirada. |
| Lurker | Ya no da los avisos anticipados, pero su mecánica central continúa funcionando. |

---

## 10. Entrega esperada de la IA de desarrollo

Al terminar, entregar:

1. Lista de archivos/scripts modificados y explicación breve de cada cambio.
2. Tabla con los valores anteriores y nuevos de cada parámetro.
3. Lista de animaciones reutilizadas, creadas o pendientes.
4. Confirmación de las pruebas realizadas y sus resultados.
5. Problemas encontrados, decisiones tomadas y tareas que todavía requieran assets o configuración manual.

**No marcar una mecánica como terminada si solo se cambió su apariencia o se añadió un efecto visual sin conectar su lógica real.** Todas las mecánicas deben funcionar en juego, en multijugador y respetar las reglas globales de persecución y zonas seguras.

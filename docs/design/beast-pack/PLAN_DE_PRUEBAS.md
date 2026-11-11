# PLAN DE QA — WILDBOUND | 4 BESTIAS

## Modo de prueba obligatorio

En Roblox Studio usar **Server & Clients** con al menos 2 clientes, y cuando sea posible con 3. El servidor lleva el estado y los clientes ven efectos individuales. No considerar una bestia «terminada» solo porque se mueve en Play Solo. Para pruebas forzadas exponer comando de Studio con autorización del servidor; no un RemoteEvent invocable por jugadores comunes. Registrar `userId` o alias de prueba, `encounterId`, tipo, estado, amenaza reservada, probabilidad antes/después de multiplicadores y razón de finalización.

## P0 — Tests que bloquean la entrega

| ID | Cómo probar | Resultado esperado |
|---|---|---|
| S01 | Jugadores A y B; forzar Viper solo para A | A la ve/oye; B no la ve/oye ni recibe daño |
| S02 | Forzar Gargoyle a A y después Viper a A | Se aceptan ambas: amenaza 2+1=3, 2 encuentros |
| S03 | Con Gargoyle y Viper activas, forzar Pouncer | Se rechaza por amenaza/concurrencia; logs explican motivo |
| S04 | Forzar Gargoyle y Mire simultáneas al mismo jugador | Segunda se rechaza porque 2+2>3 |
| S05 | 1000 tiradas simuladas día/noche (sin mundo real) | No hay garantías de 1/100 exacto; ratios cercanos a los valores configurados dentro de variabilidad estadística |
| S06 | Morir durante ataque de cada bestia | Cancelan hitboxes pendientes; se libera amenaza 1 vez; reaparece sin bestia durante gracia inicial |
| S07 | Entrar a la base durante un warning | No se recibe daño dentro de zona segura; se cancela ataque y termina encuentro |
| S08 | Desconectarse durante dos encuentros | Borrar visuales, conexiones, listeners y contadores; no persisten referencias al usuario |
| S09 | Disparar RemoteEvents falsificados desde LocalScript | Servidor ignora órdenes de daño/aparición y valida argumentos; cliente no puede adjudicarse hits |
| S10 | Probar bioma con partes rotadas y superpuestas | Gargoyle solo Cemetery; Mire solo Swamp y con agua válida |

## P1 — Tests específicos

### Viper

- V01: Telegraphed lane visible ≥1.15 s antes del dash; origen/dirección coincide con daño server.
- V02: El jugador se sale lateralmente del carril: no daño.
- V03: El jugador permanece dentro del carril y es alcanzado: 35 HP de daño una sola vez.
- V04: Obstáculo sólido a mitad de dash: Viper choca y no golpea a través de él.
- V05: Movimiento target después del lock: Viper no cambia ángulo mágicamente.
- V06: Desaparición durante dash: no quedan Trails ni daño tardío.

### Pouncer

- P01: Círculo de radio real 6.5 studs, visible 1.3 s; no se mueve tras lock.
- P02: El avatar sale del círculo 0.2 s antes de aterrizar: no daño, si el server confirma posición afuera.
- P03: Avatar quieto en área y nivel de altura válido: 40 HP de daño solo una vez.
- P04: Atacar junto a pared, techo o barranco: abortar/reubicar si trayectoria inválida.
- P05: Dos saltos seguidos no solapan de forma injusta sus telegraphs.
- P06: El audio y VFX de impacto coinciden con tiempo real servidor.

### Gargoyle

- G01: Un spawn de Cementerio comienza como estatua y presenta grietas/ruido 1.6 s.
- G02: No crea gargoyle fuera de Cemetery aunque un RNG de bioma resulte ganador.
- G03: Tornado marca ruta 1.65 s, viaja en sentido previsto y no atraviesa coberturas sólidas.
- G04: El jugador usa una lápida para cubrirse o sale del corredor: no daño.
- G05: Si el tornado alcanza, daño 25 HP una sola vez, knockback limitado o omitido.
- G06: Salir del bioma o entrar a base limpia vuelo y tornado sin dejar activos.

### Mire

- M01: Sin agua válida en Swamp: no spawn, presupuesto sin consumir.
- M02: Agua declarada válida: Mire aparece parcialmente sumergido; estela no atraviesa islotes ni paredes.
- M03: Atacar cerca de orilla muestra anillo/cone ~1.5 s; hay escape real a tierra firme.
- M04: Jugador se retira de agua más de 6 s: encuentro termina sin perseguir por tierra.
- M05: Zarpada válida: 40 HP como máximo una vez por emergencia, no ataques a través de roca.
- M06: Agua muy poco profunda, poza aislada o profundidad inválida: descarta/retira sin fuga.

## P2 — Rendimiento, móvil, efectos y limpieza

- Correr 15 minutos con varias apariciones forzadas y registrar instancias activas, memory footprint aproximado, emisores y conexiones después de 20 finales; debe volver al nivel base aceptable.
- Probar gráficos bajos/móvil (o emulación Studio) y comprobar que el círculo rojo y línea de Viper se entienden sin filtros costosos.
- Probar FPS bajo / 200 ms RTT simulado: si llega warning tarde, no aceptar daño imposible. Logs de tiempos.
- Abusar de respawn mientras hay dos ataques: no quedan referencias stale, ataque no se aplica al nuevo Humanoid.
- Con 3 clientes, crear tres combinaciones diferentes; cada uno ve solo las propias.
- Cambiar entre día/noche/tormenta durante partida sin reiniciar scheduler; observar p efectiva en debug.
- Probar un jugador con invulnerabilidad de respawn o escudo, si el juego tiene ese sistema; el DamageAdapter debe respetarlo.
- Confirmar que morir por bestia activa el sistema existente de huevo de expedición; sin dupe, sin perdidas dobles.

## Criterio de salida y reporte

Al finalizar, la otra IA debe responder con un registro tipo:

```
Archivos nuevos: ...
Archivos existentes modificados: ...
Bestias funcionales: Viper / Pouncer / Gargoyle / Mire
Probé en Studio: [Sí/No], versión / entorno / modo / nº de clientes
Resultados de P0: S01 ... S10 (aprobado, falló o sin ejecutar)
Resultados específicos: ...
Limitaciones: Meshes, sonidos, animaciones que aún sean placeholders
Cómo forzar y reproducir: instrucciones exactas
Qué falta para producción: ...
```

No considerar un test «aprobado» si no fue ejecutado realmente.

# Rebloxed Discover: señales y procedencia de datos

**Conclusión:** Rebloxed Discover sirve como fuente de ideas para investigar tendencias de Roblox, pero no como evidencia suficiente de demanda, causalidad o ingresos. La página no identifica públicamente la fuente ni la metodología de sus métricas.

## Evidencia observada

Consulta anónima de la página pública el **3 de noviembre de 2026**. La interfaz ofrece los filtros “Most players”, “Growing fastest” y “Most room”, y presenta grupos de tendencias con número de juegos, jugadores actuales agregados y variación semanal; al desplegar un grupo, muestra juegos individuales con jugadores actuales y variación porcentual. En la página se observaron, por ejemplo, “Egg” (42 juegos, 970K y −12,9 %) y títulos individuales con recuentos y cambios. Son valores de una captura puntual, no datos históricos ni valores persistentes.

La descripción de la página afirma que presenta recuentos en vivo, crecimiento de siete días y estimaciones de ingresos, y que se actualiza cada hora. En cambio, la página independiente de Charts dice que sus datos se sincronizan cada día y, en la captura indexada consultada, no mostraba datos disponibles. Estas son declaraciones de Rebloxed sobre superficies distintas; no verifican la exactitud, cobertura ni cadencia real de actualización.

- [Trend Finder / Discover](https://rebloxed.com/discover)
- [Charts](https://rebloxed.com/discover/charts)
- [Planes y descripción de funciones](https://rebloxed.com/pricing)

## Procedencia: confirmado, posible y desconocido

**Confirmado:** el contenido descrito arriba es visible en la interfaz pública. La página no ofrece, en la interfaz consultada, una atribución de proveedor, documentación de metodología ni un endpoint de origen verificable para las cifras de jugadores, variaciones semanales, agrupaciones, etiqueta “room” o estimaciones de ingresos.

**Posible, no confirmado:** la referencia oficial de Roblox para `games.roblox.com` documenta el endpoint experimental `GET /v1/games` como “Gets a list of games' detail” y lo marca “Cookie None”. Podría ser una fuente técnicamente plausible para ciertos metadatos públicos, pero no demuestra que Rebloxed lo use ni que explique sus series históricas o métricas derivadas. La política de contenido de la página permite conexiones a dominios Supabase, pero eso tampoco demuestra que el almacenamiento o la ingestión de estas tendencias se haga allí.

- [Referencia oficial de Roblox: `games.roblox.com`](https://create.roblox.com/docs/cloud/reference/domains/games)
- [Referencia de Roblox Open Cloud y consideraciones de estabilidad](https://create.roblox.com/docs/cloud)

Roblox recomienda preferir APIs con garantías de estabilidad; su documentación advierte que las APIs heredadas pueden cambiar sin aviso y tener garantías limitadas. La referencia del endpoint citado lo clasifica como experimental. Antes de basar una integración o decisión en esa API, hay que comprobar el contrato y el estado actuales en la documentación de Roblox.

## Uso recomendado y límites

Usar las categorías y los cambios mostrados para formular hipótesis —por ejemplo, qué tema o mecánica vale la pena investigar— y contrastarlas por separado con Roblox y fuentes de primera mano. No inferir que una categoría agrupada es una taxonomía oficial, que “room” tiene una definición pública reproducible, que el porcentaje semanal prueba causalidad o que una estimación de ingresos equivale a ingresos reales. No asumir una cadencia garantizada: el sitio publica afirmaciones distintas (horaria en la descripción de Discover y diaria en Charts), sin que esta revisión valide el comportamiento de actualización.

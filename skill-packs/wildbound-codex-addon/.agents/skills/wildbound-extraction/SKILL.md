---
name: wildbound-extraction
description: Implementar expediciones, botín en riesgo, zonas seguras, refugios, retorno y eclosión gratuita con persistencia robusta.
---


# Expedición y extracción
1. Leer `LOOP_EXTRACTION.md`: separar `ExpeditionInventory` (temporal) de `BankedCollection` (persistente).
2. El servidor crea expedición, adjudica ítems/encuentros, verifica extracción y guarda resultados con acciones idempotentes.
3. Evitar perder monedas o huevos comprados con Robux en muerte/desconexión. El botín de expedición gratuito puede tener un riesgo declarado; usar cofre recuperable/rescate cooperativo.
4. Refugios variables pueden curar, guardar botín parcialmente y servir de extracción limitada; evitar campismo sin riesgo.
5. Diseñar fallos de red: reconexión, reintento de guardado, cierre de servidor, dos jugadores interactuando, doble entrega.
6. Eclosión: tabla servidor, ID único, confirmación de persistencia. Una animación no es la fuente de verdad del premio.
**Pruebas**: salida forzada, muerte durante guardado, extracción simultánea, doble click, duplicación.

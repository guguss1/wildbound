---
name: wildbound-creatures
description: Diseñar bestiario coleccionable, huevos, familias, variantes y reglas de aparición/captura verificables para Wildbound.
---


# Ecología y colección
1. Leer `knowledge/wildbound/CREATURES.md` y `SPAWN_SYSTEM.md`.
2. Mantener por criatura ID estable, nombre original, familia, afinidad, rareza, biomas, condiciones clima/horario, pistas, conducta, método de captura y si es hostil o no.
3. Separar explícitamente familia, afinidad, rareza, variante y guardián. No asumir que todos los hostiles son mascotas.
4. Diseñar una interacción de captura con habilidad: sigilo, atraer, acertijo, tiempo, equipamiento o supervivencia; evitar que todo sea 'presionar E'.
5. Balancear accesibilidad en móvil (botón contextual grande, input de una mano cuando posible) y cooperativo (sin duplicación de loot).
6. Conectar los datos con tabla de spawns validada en servidor. Escribir pruebas de ausencia de biomas, duplicados, condiciones imposibles y recompensas inválidas.
**Entregables**: ficha de criatura + reglas de captura + tabla de condiciones + test.

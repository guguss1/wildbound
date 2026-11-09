---
name: wildbound-creatures
description: Crear el bestiario y ecología de Wildbound, definiendo especies coleccionables con roles de compañero, rareza, afinidad y método de obtención.
---

# Procedimiento

1. Leer `knowledge/wildbound/CREATURES.md`, `COMPANION_SYSTEM.md`, `GUARDIAN_PET_MATRIX.md` y `examples/creature_catalog.json`.
2. Definir IDs estables y ejes independientes: especie, familia, afinidad, rareza, variante, rol, bioma, hora, clima, pistas y método de captura.
3. Cada especie debe justificar su uso como **compañero útil**, incluso si es común. Guardianes peligrosos no son capturables en MVP.
4. Delegar habilidades a `$wildbound-companion-abilities`, captura a `$wildbound-capture-bond`, huevos a `$wildbound-egg-hatching` y progresión a `$wildbound-pet-progression`.
5. Diseñar por especie al menos una interacción ambiental y un contraejemplo donde no sea óptima; prohibir poder universal por rareza.
6. Validar la lista con pruebas automáticas de IDs, spawn bioma, habilidad, rol, método y referencias cruzadas.
**Entregables:** ficha de criatura, datos y tests; sin generar código del juego si el usuario solo pide diseño.

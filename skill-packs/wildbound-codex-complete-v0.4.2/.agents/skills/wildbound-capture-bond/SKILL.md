---
name: wildbound-capture-bond
description: Diseñar captura de criaturas salvajes no hostiles en Roblox Wildbound, minijuegos accesibles, validación server-authoritative y vínculo tras extracción.
---

# Procedimiento

1. Leer `knowledge/wildbound/CAPTURE_HATCH_BOND.md` y catálogo `examples/creature_catalog.json`.
2. Separar `WildEncounter`, `CaptureSession`, `CapturedSpecimen`, `BankedPet`; capturar en campo no implica ya poseer la mascota.
3. Diseñar minijuegos de lectura/timing/sigilo por especie con controles táctiles justos, sin exigencia de reflejos de precisión sub-frame en móvil.
4. Server decide elegibilidad/estado/resultado; `sessionId` opaco, TTL y reserva de criatura para impedir doble captura; validar distancia, cooldown y condiciones aunque cliente modifique prompt.
5. Perder una captura no debe castigar con pérdidas de pets ya obtenidos; dar pistas para que la habilidad del jugador mejore.
6. Tests: dos clientes simultáneos, tap repetido, cerrar app, mobile lag, reintentos, streaming del ejemplar.
**Entregables:** flujo, schema, UI móvil, pruebas y telemetría básica de fallos.

7. Los especímenes recién capturados son temporales y se pierden en derrota definitiva salvo protección/refugio. La pérdida de compañeros ya registrados queda como decisión abierta. Consultar `$wildbound-loss-protection`.

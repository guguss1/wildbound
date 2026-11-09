---
name: roblox-data-economy
description: Diseñar progreso y economía Roblox segura: inventario persistente, guardados, recompensas, monedas y criterios para monetización sin tocar datos reales.
---

# Datos, progreso y economía

## Cuándo usar
Guardar progreso, niveles, monedas, logros, inventarios persistentes, recompensas o diseñar monetización.

## Procedimiento
1. Lee `../_roblox-shared/PROJECT_RULES.md`. Separa estado temporal (memoria servidor), datos persistentes (DataStore) y coordinación temporal entre servidores (MemoryStore).
2. Define esquema versionado, valores válidos, límites, migraciones, carga inicial, fallos y comportamiento cuando el guardado no está disponible.
3. Mantén datos críticos y decisiones de compra/recompensa en servidor; valida toda solicitud del cliente. Considera idempotencia y evita recompensar dos veces un mismo evento.
4. Usa UpdateAsync y control de concurrencia cuando corresponda; implementa reintentos limitados/backoff, observabilidad y escenarios de salida inesperada.
5. Nunca pruebes cambios peligrosos con los mismos DataStores de producción: prepara experiencia/entorno de prueba aislado.
6. No agregues microtransacciones ni publiques productos sin decisión explícita del usuario.

## Entregables
Esquema de datos, casos de error, política de guardado y evidencia de pruebas aisladas.

## Fuentes
https://create.roblox.com/docs/cloud-services/data-stores/best-practices
https://create.roblox.com/docs/cloud-services/data-stores-vs-memory-stores

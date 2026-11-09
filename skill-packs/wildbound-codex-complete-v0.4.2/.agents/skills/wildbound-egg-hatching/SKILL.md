---
name: wildbound-egg-hatching
description: Diseñar huevos encontrados, eclosión gratuita y álbum de colección con resultado fijado en servidor y guardado idempotente en Wildbound.
---

# Procedimiento

1. Leer `knowledge/wildbound/CAPTURE_HATCH_BOND.md`, `ECONOMY_POLICY.md` y `ARCHITECTURE.md`.
2. En MVP, el servidor fija el resultado del huevo en la recolección y lo guarda sellado; revelar en base no vuelve a lanzar RNG.
3. `TryHatch(eggUid)` valida propietario, huevo bancado, estado de sesión y operación no procesada; crea `petUid` único una sola vez y confirma persistencia.
4. Si el contenido del huevo es conocido mostrarlo; si es aleatorio gratis, dar pistas honestas, evitar promesas de rareza falsa. Si futura monetización afecta el azar, detener implementación y revisar política/odds numéricas/PolicyService.
5. Mantener álbum (`speciesId` registrado), UIDs por cada pet, atributos de variante y vínculo. Nunca perder ítems bancados por desconexión.
6. Tests: doble click, relogin durante animación, guardado fallido, conflicto entre servidores, carga de perfil no disponible.
**Entregables:** estados, contratos, historial de operaciones, prueba de seguridad.

7. Solo eclosionar `eggUid` extraído/bancado o explícitamente protegido tras derrota confirmada. Nunca eclosionar un huevo temporal perdido. Consultar `$wildbound-loss-protection`.

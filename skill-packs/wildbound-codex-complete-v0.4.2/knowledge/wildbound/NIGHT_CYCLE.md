# Wildbound — Día y noche (decisión confirmada, 04-11-2026)

## Confirmado por el usuario
- Existe ciclo de día/noche: en un momento se hace de noche.
- De noche el mundo se vuelve más difícil y aterrador, **al menos en biomas terroríficos por ahora**.
- Se incrementa la oportunidad de obtener criaturas de mayor rareza, huevos interesantes y recursos valiosos **al aceptar mayor riesgo**.
- El ciclo no altera el principio de propiedad: pets ya eclosionados y registrados nunca se pierden por derrota. Se arriesga loot temporal no asegurado.

## Propuesta de balance v0.4 — NO confirmada ni implementada
- Ciclo compartido por servidor de 20 minutos: día 10, atardecer 2, noche 6, amanecer 2. Testear ritmos en sesiones móviles.
- El mapa completo refleja la hora del día. Las bonificaciones de terror/riesgo empiezan solamente en `fog` durante MVP. En expansión: `crypt`, `abyss`.
- Multiplicadores **de ejemplo** en biomas de terror de noche: tasa de encuentro hostil x1.5, peso de criaturas raras o superiores x1.75, peso de recursos raros x1.4. Diferentes denominadores y cálculos, nunca prometer odds directas.
- Crepúsculo avisa de llegada de noche con música, tonalidad del cielo, reloj/ícono UI y pistas de actividad de guardianes. No saltos sin aviso.
- Algunos nidos, rastros y apariciones pueden ser nocturnos exclusivos; incluir siempre alguna recompensa de progreso más predecible y vías gratuitas para sobrevivir.
- Refugios y campamento no se convierten en trampas durante la noche. No spawnear enemigos sobre personajes, rutas críticas ni extracciones.
- Si un jugador entra en una zona nocturna, mostrar aviso de peligro y beneficios de forma accesible. Peligro gradual: no multiplicar indefinidamente si también usa tótem.

## Técnica en Roblox (para Codex)
1. `WorldTimeService` (servidor): guarda fase, progreso del ciclo y inicio/fin, servidor decide `isNight`. Todos en el mismo servidor comparten reloj, independiente del reloj real del dispositivo.
2. `NightEncounterModifiers` (servidor): consulta bioma y fase, ajusta por separado frecuencia hostil y **pesos** de especies/recursos elegibles; restringe caps, cooldowns, condición de nido y exclusividades. Fuentes únicas de verdad para RNG y loot.
3. `WorldAtmosphereController` (cliente): interpola `Lighting.ClockTime`, iluminación global y efectos locales por bioma. Roblox `Lighting.ClockTime` no cambia solo y se debe sincronizar explícitamente; evitar alternar todo el mapa a paleta de niebla por un único jugador.
4. `NightWarningUI` (cliente): pequeño icono sol/luna, tiempo orientativo restante, alerta de peligro en crepúsculo, accesibilidad táctil, opción de reducir sacudidas/flashes.
5. `EncounterDirector` (servidor): llama a una API de modificadores sin duplicar lógica de RNG en UI. Las criaturas elegibles requieren bioma + fase correctos, y solo después reciben pesos normalizados.
6. Condiciones límite: cambio de fase mientras un NPC persigue a alguien, ingreso en expedición nocturna, sesión de 4 jugadores, refugio, reconexión y muerte simultánea.

### Ejemplo para verificar efecto de pesos
Si hay 5 unidades de peso de rareza alta y 95 de otras opciones, multiplicar peso raro por 1.75 produce 8.75/(95+8.75) = 8.43% del total, NO 8.75% ni 1.75 veces exactas las odds finales. Cada tabla efectiva debe normalizarse tras filtros.

### Archivos de ejemplo
- `examples/night_cycle_rules.json` — fases y multiplicadores de ejemplo.
- `examples/encounter_tables.json` — incluye `fog_night` y `crypt_night` de ejemplo; no usar ambas tablas y un multiplicador adicional sin revisar doble conteo.

## Fuentes técnicas
- https://create.roblox.com/docs/reference/engine/classes/Lighting
- https://create.roblox.com/docs/environment
- https://create.roblox.com/docs/scripting/security/client-server-boundary

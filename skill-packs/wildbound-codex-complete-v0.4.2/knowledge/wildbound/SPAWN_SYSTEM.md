# Sistema probabilístico (modelo, NO porcentajes oficiales)
Separar cuatro RNG distintos:
1. **Encuentro**: ¿ocurre algún evento en este sector/ventana de tiempo? con intensidad, cooldown y presupuesto.
2. **Categoría**: ¿criatura, guardián, cofre, evento climático o vacío? por tabla y bioma.
3. **Especie**: escoger entre candidatos disponibles según condiciones; pesos se renormalizan.
4. **Eclosión**: si huevo contiene recompensa variable, resultado autorizado por servidor, persistente e independiente del cliente.

## Modelo de selección ponderada
De un conjunto elegible E de especies, peso efectivo `w_i >= 0`; `p_i = w_i / sum(w_j)` cuando `sum > 0`. Filtrar por biome/clima/tiempo primero. Nunca aplicar multiplicadores al azar sin decidir si afectan peso o probabilidad absoluta.

### Totem de ejemplo
Si una clase rara tiene peso 5 y las demás suman 95, duplicar su **peso** resulta `10 / (95+10) = 9.5238%`, no exactamente 10%. En una tabla con más especies, recalcular todos los resultados finales. Un tótem puede elevar encuentros hostiles de p=0.08 a p=0.16 como **regla independiente y explícita**, sujeto a caps/cooldowns.

## Protección contra aleatoriedad frustrante
- Pistas, recompensas de habilidad, rutas alternativas y desbloqueos garantizados.
- No spawnear guardianes sobre refugios o puntos de carga.
- Cooldown individual de sustos, máximo simultáneo de NPC hostiles, tiempos de descanso, spawn fuera de cámara.
- Seeds servidor reproducibles para depuración; el seed no confiere autoridad al cliente.

## Ejemplo de estructura de configuración
Ver `examples/encounter_tables.json`. Son pesos de muestra que suman 100, no valores ya balanceados ni probabilidades exactas de un huevo pagado.

## Multiplicadores nocturnos v0.4
- Primero filtrar por bioma, fase, clima, evento y elegibilidad de especie. En el MVP los beneficios/riesgos nocturnos solo se activan en `fog`.
- Segundo resolver la **tasa** de aparición de guardianes (con caps y cooldowns) y por separado los **pesos** de criaturas de rareza rara+ y materiales raros; normalizar los pesos efectivos.
- El JSON `examples/night_cycle_rules.json` propone guardianes x1.5 (tasa), criaturas rara+ x1.75 (peso) y recursos raros x1.4 (peso). Valores para testear, no odds publicadas.
- `fog_night` y `crypt_night` en `examples/encounter_tables.json` son tablas alternativas ilustrativas a los multiplicadores, NO aplicar multiplicador de rareza sobre una tabla ya reforzada sin intención expresa (evitar doble beneficio).
- Los sobresaltos deben tener presupuestos y descansos. Un tótem hostil adicional debe respetar techo conjunto, nunca apilar multiplicadores sin límite.

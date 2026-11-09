---
name: wildbound-encounters
description: Configurar apariciones probabilísticas de criaturas, monstruos, cofres y eventos por sector, clima, peligro y equipo con simulación reproducible.
---


# Director de encuentros
1. Leer `SPAWN_SYSTEM.md`. Diferenciar probabilidad de evento/encuentro de selección ponderada de especie y de eclosión.
2. Implementar RNG y semilla del lado servidor, con pesos no negativos y normalización coherente. Documentar probabilidades observables reales.
3. Separar por bioma/sector/horario/clima/peligro y usar presupuestos/cooldowns: impedir repetición del mismo monstruo, emboscadas imposibles y saturación de NPC.
4. Un tótem de 'x2 peso de raros' NO produce necesariamente 'x2 probabilidad final': recalcular y exhibir la distribución efectiva donde la política lo requiera.
5. Registrar contadores de expediciones, contactos con enemigos, captura por especie y abandono sin datos identificatorios innecesarios.
6. Simular 10.000+ extracciones de muestra para comprobar invariantes, pero NO tratar esa simulación como prueba del funcionamiento real en Studio.
**Pruebas**: pesos cero, máximo/mínimo, totems simultáneos, límite de criaturas y servidor lleno.

# Hoja de ruta de prototipos

**P0 (nuevo, PRIORIDAD ACTUAL):** leer [`PROTOTIPO_BOSQUE_NIEBLA_P0.md`](PROTOTIPO_BOSQUE_NIEBLA_P0.md). Un único sector pequeño del Bosque de la Niebla, una especie (`Lumipol`) y un guardián (`La Silueta`), captura, huevo, extracción, pet registrado, pérdida tipo A y ciclo nocturno. **No generar todos los biomas ni seis criaturas todavía.**

**P1 / expansión posterior, NO requerida para P0:** el alcance v0.2 de abajo (seis criaturas y dos guardianes). Se realiza solamente después de validar P0 en celular.

---

# MVP vertical slice v0.2 — jugable antes de escalar
1. Campamento (selección de pet activo/reservas, equipamiento gratuito y coleccionario básico).
2. Bosque vivo y subzona niebla que aparece en slots seguros; refugio variable.
3. Seis especies: Lumipol, Musguín, Rocuelo, Ecozorro, Brumín, Ojobúho, con habilidades y métodos de obtención de ejemplo.
4. Dos guardianes: Vigía y Silueta, cada uno con counterplay **gratuito y sin pet** más ventajas acotadas de pets.
5. Un huevo sellado y una criatura salvaje capturable, ambos asegurables por extracción, resultados persistentes y sin Robux.
6. Eclosión de huevo gratuito y vínculo de criatura; enciclopedia y pequeño progreso de Bond 1→2.
7. Solo y 2 jugadores funcionales primero; test de 4 después. Botones móviles y cooldowns legibles.
8. Prueba de fallo de red, doble tap, dos jugadores sobre el mismo huevo, respawn, reconexión, estrés de pet activo.
9. Rendimiento medido con dispositivos móviles, sin afirmar FPS objetivo hasta fijar gama de teléfono.

## Criterio de aceptación central
Una persona puede salir con Lumipol, encontrar una criatura o huevo, revelar por 4 s a la Silueta, huir, volver, eclosionar/vincular, equipar nuevo pet y repetir con una estrategia distinta; TODO sin Robux, sin duplicación y sin errores de red conocidos.

## Requisito adicional de MVP v0.4
- Añadir ciclo día / atardecer / noche / amanecer (20 min propuestos), sincronizado en servidor. El bosque cambia visualmente; solo la zona Niebla aumenta hostilidad y oportunidad de raros y recursos nocturnos.
- UI móvil anticipa anochecer y explica que hay riesgo/recompensa nocturna; probar jugar de noche voluntariamente y retirarse al refugio.
- En fracaso nocturno, las pérdidas siguen política A: solo nuevo botín temporal no protegido, y pequeña parte de materiales; pets registrados conservados.

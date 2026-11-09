# Guardianes × compañeros — matriz estratégica v0.2
| Guardián | Riesgo | Pet útil | Qué permite | Qué NO resuelve |
|---|---|---|---|---|
| Vigía (se mueve cuando nadie lo ve) | Aparece al perder contacto visual | Ojobúho | Advierte de presencia o dirección aproximada | No congela al Vigía ni reemplaza observarlo |
| Silueta (casi invisible, lenta) | Acecha y es difícil de localizar | Lumipol | Revela contorno 4 s, cooldown 30 s | No la elimina; destello puede atraer a otra amenaza |
| Silueta | Persecución por ruido y cercanía | Ecozorro | Desvía hacia un sonido por 5 s (si responde a sonido) | No garantiza escape; puede atraer otro guardián |
| Yeti (posterior al MVP) | Rastrea vibraciones en nieve | Nevín | Marca huellas y cobertura posible | No vuelve invisible al jugador |
| Taladro de Lava (posterior) | Embiste desde suelo caliente | Ascua | Señala superficies calientes inestables | No inmuniza a erupción |
| Eco Errante (posterior) | Sigue fuentes de ruido | Umbrelín / Ecozorro | Reduce pasos o coloca señuelo | No engaña enemigos basados en vista |

**Regla cardinal**: todo guardián tiene al menos una contraestrategia gratuita sin pet. Cada pet es una *ventaja limitada* y tiene coste, duración, enfriamiento y telegráfo.

## Vigilante de mirada — condiciones multijugador
- Estado server-authoritative. Cliente puede notificar foco/mirada de cámara como indicio; servidor verifica posición, distancia, oclusión (raycast), movimiento y coherencia con la cámara/character. No confiar exclusivamente en señal cliente.
- Regla inicial: un jugador vivo realmente observándolo puede detenerlo; si nadie lo mira, avanza. Rate limits, margen para latencia y máximo de ataques por ventana.
- Si streaming oculta al monstruo, no castigues al cliente por no haber recibido su modelo; simular condiciones y agregar guardas de visibilidad.

## Presupuesto de miedo
Tiempo para reconocer señal → elegir respuesta → ejecutar → alivio → cooldown. Miedo y tensión sin castigo arbitrario. Tests con audio apagado y baja calidad gráfica.

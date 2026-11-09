# Guardianes con personalidad y contraestrategia
| Guardián (provisional) | Pros/amenaza | Contraestrategia gratuita | Señal/telegrafía | Límite |
|---|---|---|---|---|
| El Vigía | Se desplaza cuando nadie lo observa | Mirarlo y retroceder, cerrar línea visual inteligentemente | Crujido y ojos | Lentitud, rango limitado y cooldown; solo 1 persecución activa |
| La Silueta | Invisible salvo contorno sutil; se acerca al distraído | Ver huellas, escuchar roce, usar destello de linterna ganable | Halo débil/huellas | Movimiento lento y destello la revela por segundos |
| Yeti de la Tormenta | Rastrear vibraciones en nieve, embiste | Caminar suave; usar refugios rocosos | Rugido y nieve levantada | Torpeza en giros; busca sombra térmica lentamente |
| Taladro de Lava | Sale por zonas calientes | Observar suelo rojo y esperar erupción | Temblor/roca | No cruza piedra fría |
| Devoraluz | Apaga linternas y crea oscuridad | Alternar fuentes de luz y moverse en pareja | Chasquidos de vidrio | Se fatiga tras cada apagón |
| Cofre Mimético | Simula recompensa y embosca | Reconocer patrón sonoro y probar con herramienta | Latido desde cofre | Se queda quieto lejos de cofres |
| Eco Errante | Sigue ruido de pasos y señales | Caminar agachado y desviar con piedra | Imitación con eco | Vulnerable a distracción de sonido |
| Centinela de Cenizas | Ve en línea recta a distancia | Cobertura y humo frío | Barrido de luz roja | Campo visual estrecho y pausas |

## Diseño del Vigía para multijugador
Propuesta: si **algún** jugador superviviente cercano tiene al Vigía en campo visual y línea de visión clara, el enemigo se detiene. Evita que cuatro jugadores reciban reglas contradictorias. La cámara del cliente aporta una intención **no confiable**, que el servidor debe comprobar con posición/rumbo/LOS, tolerancias y rate-limit. No raycastear cada enemigo en cada frame de todos los clientes.

## Terror razonable
Alternar calma / suspense / amenaza / alivio. Para juego con usuarios jóvenes, priorizar miedo leve, sin violencia gráfica. Declarar correctamente miedo y violencia en cuestionario Roblox: https://create.roblox.com/docs/production/promotion/content-maturity

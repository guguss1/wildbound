# Roadmap de implementación: versión que ya se pueda jugar
## Fase 0: entorno y premisas
- Confirmar idea de mascotas vs monstruos, sistema de captura y riesgo de muerte.
- Conectar Roblox Studio MCP; Rojo solo para código Luau, Blender MCP solo si Blender instalado y autorizado.
- Documentar baseline FPS y presupuesto de memoria en móvil.
## Fase 1: núcleo del bucle, primero gris
- 1 campamento, 1 bioma bosque, 1 subzona de niebla dinámica. Pocos minutos a pie, no gigante.
- 6 criaturas originales con 2 métodos distintos de captura.
- 2 guardianes: Vigía (mirada) y Silueta (contorno). Estados simples + límites.
- 1 refugio generado entre slots válidos.
- 1 huevo, inventario temporal y extracción en base; guardado y eclosión gratuita.
- 1 tótem gratuito con contrapartida, 1 mejora de habilidad ganable.
- Solo y cooperativo 2 jugadores; extender a 4 tras validación.
## Fase 2: variabilidad y escalado
- Más condiciones de spawn, eventos climáticos y cuevas modulares. Pistas en UI y audio.
- Desbloqueo de nieve y Yeti. Profundizar variedad antes de añadir 200 criaturas.
## Fase 3: operación y monetización
- Telemetría: primeros 60s de abandono, tasa de extracción, sesiones, aciertos de captura, FPS por device, repetición/retención.
- Only after fun & policy review: cosmetics, passes guaranteed. Nunca primero lootboxes Robux.

## Criterios mínimos de aceptación MVP
- Entrar con celular, entender cómo explorar y capturar en menos de unos minutos de observación de prueba.
- Completar una expedición gratis solo; completar con 2 jugadores sin desincronización.
- Un enemigo con regla visible y contramedida básica gratuita.
- Cerrar/reconectar no duplica ni borra huevos bancados.
- Ningún encuentro spawnea en refugio o área de inicio.
- Medición real de FPS, memoria y latencia; no declarar optimizado si no se probó.

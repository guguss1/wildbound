# Dirección de arte para un juego mobile-first
- **Estilo:** low-poly estilizado con siluetas claras, formas grandes, expresividad y detalles focales; no realismo de alta densidad ni copiar IP externa.
- **Criaturas recolectables:** formas redondeadas/memorables, contraste de ojos/cuernos/alas y señales de afinidad. Deben leerse en miniaturas pequeñas.
- **Guardianes:** siluetas fuertes y comportamientos identificables; la amenaza debe telegráfiarse con audio/partículas/pose, no solo oscuridad total.
- **Paletas:** bosque cálido, nieve cian, lava ocre, niebla verdosa/gris, críptico violeta, abismo rojo/negro. Garantizar accesibilidad visual.
- **Escenario:** assets modulares de roca, árbol, cueva, tumba, santuario y refugio. Reusar atlas/materiales y prefab por bioma.
- **Pipeline:** ficha/turnaround → Blender blockout → rig/pivots/UV → export → importar Studio → colisiones/escala → comprobar móvil.
- **No asumir presupuesto fijo de triángulos:** fijarlo después de medir cantidad visible, dispositivos objetivo y profiler de Studio.


## Referencias incluidas en la v0.4.2
- Revisar [`references/README.md`](../../references/README.md): dos láminas generadas para este paquete, recortes de ambiente, Lumipol, La Silueta y mapa esquemático.
- La guía de arte NO es un permiso para copiar assets ajenos. Si se agregan capturas de webs, guardar fuente y licencia.
- PRIORIDAD P0: claro del Bosque de la Niebla, Lumipol y La Silueta. Producir una muestra de cada asset y probar en móvil antes de construir catálogo.
- **Las imágenes generadas tienen rótulos no confiables**: la regla de moverse si no la miran es de El Vigía, NO de La Silueta. Prevalece la especificación `PROTOTIPO_BOSQUE_NIEBLA_P0.md`.

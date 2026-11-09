# Sistema de compañeros — hipótesis v0.2
## Equipamiento
- Inventario persistente de mascotas ilimitado en concepto, con límites técnicos de colección definidos tras pruebas.
- Loadout: **1 compañero activo visible + 2 reservas**, cambio explícito con cooldown inicial propuesto de 8 s.
- 1 instancia visual física del pet por jugador; los reservas no generan NPC físico. Proteger rendimiento en teléfonos y cooperativo de 4 personas.
- Como el compañero se puede cambiar, las habilidades se activan por botón táctil único con icono y estado de enfriamiento; jamás 6 botones permanentes.

## Roles
1. Explorador: localiza rutas, huellas, peligros de entorno.
2. Protector: reduce un peligro específico; no invulnerabilidad.
3. Revelador: marca enemigos ocultos durante una ventana limitada.
4. Distractor: genera falsas señales o ruidos que se pueden volver en contra.
5. Capturador: mejora ventanas de timing / lectura, nunca concede capturas automáticas.
6. Recolector: señala direcciones aproximadas de nidos/POIs, no coordenadas mágicas.

## Balance
- Cada capacidad tiene cooldown, alcance, duración, condición, señal visual/audio y coste/riesgo.
- Las capacidades más fuertes deben tener contraefectos, señales o ventanas estrechas. Ninguna neutraliza totalmente el terror.
- El jugador siempre puede superar el encuentro mediante acciones gratuitas y aprendizaje, aunque sin el pet especializado sea más difícil.
- Las mascotas **no pelean automáticamente** en el MVP; podrían tener soporte ambiental y señales tácticas.
- La rareza afecta descubrimiento, estética y variedad; no concede estadísticas dominantes automáticamente.

## Cooperativo
- Habilidades útiles a compañeros cercanos solo si tienen intención explícita (por ejemplo, revelar contorno global breve a los 2 jugadores cercanos), con rango verificado por servidor.
- No permitir apilar cuatro veces la misma habilidad para trivializar un guardián: usar resistencia/cooldown de grupo u objetivos por encuentro.
- Botín personal, peligro compartido; el mismo huevo o mascota salvaje no debe duplicarse por dos capturas simultáneas.

Datos propuestos: `examples/companion_abilities.json`.

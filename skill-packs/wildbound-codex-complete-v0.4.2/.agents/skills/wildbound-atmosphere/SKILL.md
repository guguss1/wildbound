---
name: wildbound-atmosphere
description: Crear atmósfera sonora, niebla, lluvia, nieve, viento y transición progresiva de terror optimizada para celulares.
---


# Clima y tensión
1. Leer `WORLD_BIOMES.md` y `MONSTERS.md`. Cada bioma debe tener paleta, viento, cielo, VFX, sonidos, temperatura percibida y señales del enemigo.
2. Priorizar legibilidad: la niebla puede limitar visión pero nunca esconder totalmente el aviso necesario para esquivar una amenaza.
3. Diseñar transiciones locales de cámara, audio, partículas y posprocesado, sin cambiar globalmente iluminación para usuarios de otros biomas.
4. Crear presets Low/Medium/High y reducir partículas/postprocesado en móvil.
5. Evitar flashes estroboscópicos y permitir bajar intensidad de jumpscares, cámara y volumen ambiente; no perder señales críticas si audio está apagado.
6. Medir costo de rendimiento antes y después de cada preset.
**Entregables**: tabla atmosférica, transiciones y capturas/pruebas en teléfono.

## Coordinación nocturna v0.4
Antes de cambiar encuentros, clima, amenazas, mapa o extracción, leer `knowledge/wildbound/NIGHT_CYCLE.md` y consultar `$wildbound-day-night-cycle`. Mantener horario de servidor para decisiones, presentación local por bioma y protección permanente de pets bancados. Probar de noche en móviles y cooperativo.

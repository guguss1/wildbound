---
name: wildbound-mobile-coop
description: Desarrollar controles táctiles, interfaz de pets y expediciones solo/cooperativas sincronizadas para Wildbound.
---

# Procedimiento

1. Leer `COMPANION_SYSTEM.md`, `MVP_VERTICAL_SLICE.md` y `TEST_PLAN.md`.
2. Diseñar UI para touch: interactuar/capturar, habilidad del pet activo, cambio rápido entre 3 slots, notificaciones de cooldown y ruta de extracción.
3. Un pet físico visible por jugador; 3 equipados, 2 guardados. Evitar controles sobrepuestos y texto minúsculo.
4. Un NPC compartido no puede adjudicar la misma captura a dos jugadores; co-op ayuda a rescatar, no duplica inventarios.
5. Rutas de juego en solitario viables con counters básicos incluso sin pet específico. Telegráfos visuales + audio opcional y vibración donde exista.
6. Medir memoria/FPS/latencia en teléfono real, probar 1/2/4 personas y fallo de red. No afirmar calidad por emulador exclusivamente.
**Entregables:** HUD, test de interacción móvil, bitácora de rendimiento.

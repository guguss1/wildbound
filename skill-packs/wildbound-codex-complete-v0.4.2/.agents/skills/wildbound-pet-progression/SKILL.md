---
name: wildbound-pet-progression
description: Diseñar progresión de relación Bond 1–5, especializaciones laterales, equilibrio de rarezas y participación activa de pets en Wildbound.
---

# Procedimiento

1. Leer `knowledge/wildbound/CREATURE_PROGRESSION.md`, `COMPANION_SYSTEM.md` y `PROGRESSION.md`.
2. Diseñar `bondLevel`, `bondXp`, `chosenSpecialization` por `petUid`. El servidor adjudica XP por eventos validados con antiafk y topes.
3. Evitar la escalada exponencial y pets legendarios obligatorios. Mejorar claridad/efectividad limitada, o desbloquear una variante estratégica con contrapartida, no daño infinito.
4. Estudiar equilibrio por bioma/monstruo/role y explicar qué hacen especies comunes que una legendaria no sustituye.
5. En MVP solo nivel 1→2, y un feedback de crecimiento claro en la UI y animación.
6. Tests: abandono, farm AFK, duplicado de XP, nivel máximo y cambio de loadout durante expedición.
**Entregables:** tabla de niveles, economía de XP, criterios de balance, test.

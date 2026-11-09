---
name: wildbound-random-reward-policy
description: Diseñar recompensas y eclosión aleatorias conforme a política Roblox, divulgación de odds, PolicyService y ProcessReceipt.
---


# Economía y reglas de azar
**Obligatorio**: leer `ECONOMY_POLICY.md` y https://create.roblox.com/docs/production/monetization/paid-random-items antes de proponer microtransacciones.
1. Distinguir loot aleatorio **ganado jugando** de pago directo/indirecto con Robux, incluyendo monedas compradas, boost de suerte, pity y tótems.
2. Si una mecánica paga afecta resultados aleatorios: mostrar todos los resultados finales y probabilidades numéricas reales, dinámicas y correctas; no usar lenguaje engañoso.
3. Consultar `PolicyService:GetPolicyInfoForPlayerAsync` y `ArePaidRandomItemsRestricted` para cada jugador según reglas; restringir UI y transacciones cuando corresponda.
4. Para Developer Products, usar solo `MarketplaceService.ProcessReceipt` y comprobaciones idempotentes en servidor. Nunca entregar premios por confirmación cliente.
5. Propuesta inicial: eclosión gratuita del botín encontrado; monetizar cosméticos, emotes, diseños de incubadora, efectos visuales y otros bienes directos/garantizados. No construir trading de items pagos sin revisar `IsPaidItemTradingAllowed`.
6. No introducir moneda convertible, apuestas entre jugadores ni recompensas monetarias reales; aplicar cuestionario de madurez por contenido de miedo.
**Entregables**: matriz de mecánicas y políticas, auditoría de probabilidades, tests por restricciones de usuario.

7. Si surge monetización de seguros o tótems que conservan botín aleatorio, analizar riesgo de **acceso indirecto a random items**; no asumir que un producto «de protección» queda exento. La ruta inicial es ganable jugando.

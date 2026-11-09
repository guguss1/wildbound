# Monetización futura y política de azar Roblox (noviembre 2026)
## Primera versión recomendada
- Recolectar criaturas, abrir cofres hallados y eclosionar huevos ganados en expedición **gratis**.
- Monetizar directo/garantizado: skins de mochila/linterna/campamento/incubadora; gestos; efectos cosméticos sin poder; servidores privados si el diseño lo justifica.
- Guardar mejoras de poder clave como progresión por habilidad y tiempo, no tras muro Robux.

## Si más adelante se usan recompensas pagadas aleatorias
Roblox define como paid random items **huevos, cofres, sorteos, mutaciones y modificadores de suerte/pity** comprados con Robux o moneda que pueda comprarse con Robux. Exigir antes de compra:
- Lista de **todos los resultados finales** y probabilidades numéricas efectivas; actualización dinámica con buffs/pity/tótems; porcentajes que sumen 100 según reglas de redondeo.
- `PolicyService:GetPolicyInfoForPlayerAsync` y `ArePaidRandomItemsRestricted`, y cuando haya trading, `IsPaidItemTradingAllowed`.
- Cambiar a ruta gratuita/no aleatoria o bloquear el producto para cuentas donde está restringido.
- Verificar compras con `MarketplaceService.ProcessReceipt` en servidor e idempotencia; nunca otorgar loot vía cliente.
- Auditoría de región, edad y cuestionario de madurez; no usar fichas/apuestas convertibles en dinero real, ni gambling jugable.

Fuentes:
https://create.roblox.com/docs/production/monetization/paid-random-items
https://create.roblox.com/docs/production/monetization/developer-products
https://create.roblox.com/docs/production/promotion/content-maturity

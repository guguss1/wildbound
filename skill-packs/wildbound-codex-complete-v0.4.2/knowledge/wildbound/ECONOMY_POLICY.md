# Monetización y azar — revisión inicial Nov 2026
## MVP
- Huevos, cofres y capturas **obtenidos jugando**, sin vender moneda que permita financiar sorteos y sin Robux.
- Eclosión y vínculo gratis; no aceleradores pagados de incubadora, boosts de rareza o sorteos durante pruebas.
- Monetización futura propuesta: skins de mascotas, campamento, mochila, linterna, emotes, efectos visuales cosméticos con resultado garantizado.

## Reglamentación si algún día hay paid random items
Roblox incluye en el régimen de recompensas pagadas aleatorias huevos, cofres, modificadores de suerte, pity, boost de drops y otros que involucren directa o indirectamente Robux o moneda comprada. Exige odds finales numéricas para todos los resultados y evaluación de restricciones de cada usuario con `PolicyService:GetPolicyInfoForPlayerAsync` y `ArePaidRandomItemsRestricted`.
- Verificar la política real **cuando se implemente**; puede cambiar. No agregar funciones de trading antes de revisar `IsPaidItemTradingAllowed`.
- `MarketplaceService.ProcessReceipt` y adjudicaciones idempotentes si existen Developer Products.
- No añadir apuestas por Robux, tokens convertibles en dinero, ni promover gasto compulsivo. Ofrecer experiencia divertida y progresión íntegra sin pago.
- Declarar correctamente intensidad de miedo/violencia en Maturity & Compliance Questionnaire.
Fuentes: https://create.roblox.com/docs/production/monetization/paid-random-items ; https://create.roblox.com/docs/production/promotion/content-maturity

## Protección de botín — v0.3
- **Decisión del usuario:** consumibles/mejoras/tótems para impedir perder huevos o criaturas en expediciones (por salida o por número de derrotas).
- En el MVP, todos se fabrican o se compran con moneda de juego ganada exclusivamente jugando; nunca se requiere pagar para conservar botín.
- Antes de vender por Robux una protección que preserve recompensas aleatorias hay que evaluar expresamente si cuenta como paid random item indirecto y cómo divulgar resultados/probabilidades y aplicar `PolicyService`. No inferir automáticamente que está permitido por ser «seguro». Preferir compras cosméticas directas.

# Recursos oficiales útiles para la IA implementadora

Estas URLs son documentación oficial de Roblox Creator Hub consultadas como referencias de implementación. No son assets a incluir ni dependencias que haya que comprar.

- PathfindingService / rutas NPC / `CreatePath` y `ComputeAsync`: https://create.roblox.com/docs/reference/engine/classes/PathfindingService
- Comunicación entre servidor y cliente / RemoteEvents / `FireClient`: https://create.roblox.com/docs/scripting/events/remote
- Seguridad de la frontera cliente-servidor y validación de eventos: https://create.roblox.com/docs/scripting/security/client-server-boundary
- Pruebas Studio «Server & Clients» con múltiples jugadores: https://create.roblox.com/docs/studio/testing-modes

## Lectura aplicada

1. Usar PathfindingService para aproximación terrestre, pero no asumir que pathfinding resuelve vuelo y agua automáticamente.
2. Usar RemoteEvents server→cliente para dibujar monstruos/efectos personales. El daño y las decisiones de spawn quedan en servidor.
3. Validar parámetros de remotes y no dar herramientas de debug de spawn a cualquier cliente.
4. Probar con múltiples clientes para validar que las apariciones verdaderamente sean individuales.

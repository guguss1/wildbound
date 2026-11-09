---
name: roblox-multiplayer
description: Implementar Roblox multijugador seguro: replicación, RemoteEvents, ownership, partidas, sincronización, anti-exploits y pruebas con clientes.
---

# Multijugador y red

## Cuándo usar
Acciones que afectan a otros jugadores, partidas, equipos, comercio, combate, herramientas y sincronización de estado.

## Procedimiento
1. Lee `../_roblox-shared/PROJECT_RULES.md`; especifica qué estado es local, replicado y exclusivo del servidor.
2. Para cada remote documenta nombre, propósito, dirección, payload, validaciones, frecuencia y respuesta. Evita que el cliente envíe precios, daño efectivo, saldo o autoridad.
3. Valida tipo, rango, propiedad, permiso, distancia, cooldown y límites de spam. Trata cada llamada del cliente como potencialmente manipulada.
4. Usa RemoteEvents para notificaciones asíncronas; usa RemoteFunctions solo donde la espera sea aceptable y controlada. Selecciona UnreliableRemoteEvents solo para actualizaciones no críticas cuando sea apropiado.
5. Prueba dos clientes, latencia, entradas simultáneas, rejoin, desconexión, spam y repetición de eventos.
6. Separa anti-cheat de feedback visual y evita confiar en Touched o ProximityPrompt del cliente para acciones privilegiadas.

## Entregables
Tabla de contratos remotos, mitigaciones y evidencia de pruebas cliente-servidor.

## Fuentes
https://create.roblox.com/docs/scripting/security/client-server-boundary
https://create.roblox.com/docs/scripting/events/remote

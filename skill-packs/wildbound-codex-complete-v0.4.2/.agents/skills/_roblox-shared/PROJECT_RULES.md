# Reglas compartidas de desarrollo Roblox para Codex

1. Lee `AGENTS.md` y la ficha actual del juego si existen. Si falta el concepto del juego, solicita una descripción breve antes de implementar una mecánica específica; para tareas de infraestructura puedes avanzar sin inventar el diseño.
2. Antes de escribir, inspecciona lo que ya existe. Trabaja en pasos pequeños, idempotentes y reversibles. Evita modificar `Workspace` completo o borrar escenas.
3. Roblox usa Luau, con arquitectura cliente/servidor. **Servidor autoritativo**: validar permisos, distancia, cooldowns, costes, propiedad de items y límites de parámetros en el servidor; nunca confiar en remotes o datos del cliente.
4. Decide quién es dueño de cada script: archivos Rojo **o** edición dentro de Studio, no ambos al mismo tiempo sin una estrategia explícita. No sobrescribas scripts sin respaldos/versionado.
5. La carpeta `knowledge/` contiene investigación y conocimiento, NO código de producción validado. Contrasta los tutoriales de YouTube con documentación actual de Roblox.
6. No publiques, monetices, compres recursos, subas assets ni cambies datos productivos sin autorización expresa. Una prueba en Studio no justifica cambiar producción.
7. Revisa licencias, derechos y scripts de recursos externos antes de incorporarlos. Evita plugins desconocidos, código remoto no auditado y assets copiados de juegos ajenos.
8. Prueba en Studio con Play, cliente/servidor, 2 clientes cuando corresponda y simulación móvil si la UI o rendimiento lo exige. Informa qué pruebas fueron reales y cuáles están pendientes.
9. Escribe en español; conserva nombres técnicos Luau en inglés. Cierra cada tarea con archivos cambiados, pruebas, resultado, riesgos y pendientes.

Documentación oficial:
- https://create.roblox.com/docs/studio/mcp
- https://create.roblox.com/docs/scripting/security/client-server-boundary
- https://create.roblox.com/docs/studio/testing-modes
- https://create.roblox.com/docs/performance-optimization

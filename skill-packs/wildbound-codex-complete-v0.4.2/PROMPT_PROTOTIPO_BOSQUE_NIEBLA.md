# PROMPT PARA CODEX — CONSTRUIR EL PROTOTIPO P0 (CUANDO ESTÉ LISTO EL ENTORNO)

**Este prompt es distinto del PROMPT_MAESTRO:** el maestro prepara entorno/skills y se detiene antes de programar; **este prompt autoriza trabajar sobre una experiencia LOCAL o de prueba**, una vez que confirmes la conexión Studio MCP. Nunca usar en una experiencia pública sin respaldo.

---

Actuá como desarrollador líder de Roblox y construí **el primer vertical slice P0 de Wildbound: un sector pequeño del Bosque de la Niebla, una especie (Lumipol) y un guardián (La Silueta)**.

**Fuentes obligatorias:** `AGENTS.md`, `knowledge/wildbound/PROTOTIPO_BOSQUE_NIEBLA_P0.md`, `NIGHT_CYCLE.md`, `RISK_AND_PROTECTION.md`, `COMPANION_SYSTEM.md`, `MONSTERS.md`, `GUARDIAN_PET_MATRIX.md`, `TEST_PLAN.md`, `references/README.md`, `references/maps/fog_forest_layout_proposal.png` y las referencias visuales de `references/`.

**Alcance exacto:**
1. Confirmá proyecto de prueba y estado real de Studio MCP, Blender MCP y Rojo; crea copia/backup. Si no están conectados, dejá la integración pendiente, construí lo posible como archivos fuente y NO afirmes que probaste en Studio.
2. Greybox con Parts/Terrain: zona cercana a 400×400 studs, campamento seguro, ruta bifurcada, claro de Lumipol, nido/huevo, área neblinosa de La Silueta, retorno al campamento. Terreno legible en móvil.
3. Agregá una sola especie salvaje capturable, Lumipol, y un huevo gratuito que produce Lumipol. Ambos son botín temporal hasta extraerlos; NO equipar capturas sin registrar.
4. Implementá una sola guardiana, La Silueta: lenta, casi invisible, contorno débil, pistas audiovisuales, persecución acotada. **No usar la mecánica de El Vigía de moverse cuando nadie la mira** aunque aparezca equivocadamente en texto de imágenes.
5. Para combatirla, el jugador comienza con linterna de destello gratuita. Tras extraer y registrar a Lumipol, puede equiparlo y usar su pulso revelador con cooldown validado en servidor.
6. Implementá extracción en campamento, eclosión gratuita, colección persistida (cuando sea posible probar DataStore), pérdida tipo A en derrota, pérdida pequeña de materiales y un Sello de Resguardo ganable jugando.
7. Día/noche con reloj compartido por servidor (20 min propuestos); riesgo y recompensa extra solo en niebla durante noche, con tabla de pesos coherente y advertencia de atardecer. Sin doble aplicación de multiplicadores.
8. UI mobile-first para interactuar, capturar, usar linterna/pet, seguir extracción y reconocer estado del botín. Considerar modo sin sonido/reducción de destellos.
9. Probá primero en Studio con una persona, luego en 2 clientes y en emulación móvil. Incluí casos de reconexión, spam de RemoteEvents, doble captura y muerte durante extracción.
10. Mostrá avances en cambios pequeños, no generes el resto de biomas. No publiques, no compres recursos, no agregues monetización. Reportá lo realizado versus lo pendiente.

**Proceso**: plan técnico breve → greybox y pruebas de recorrido → gameplay mínimo → networking y persistencia → arte/atmósfera → pruebas reales → informe. Si un paso requiere aprobación o permisos de terceros, pedila. Si el entorno no permite acceso a Studio, producí un diseño + código revisable y documentá el bloqueo sin simular pruebas.

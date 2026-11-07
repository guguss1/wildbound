# Wildbound extraction and registration (delivery B)

Delivery B of `odd/tasks/wildbound-capture-extraction-horror.md`: a captured creature is carried home, visibly and at risk, and only the camp makes it the player's. Numbers are hypotheses to tune in play. Player-facing words are neutral Spanish in `ReplicatedStorage.WildboundText`; code and docs are English.

## B1. Carry slot

- A finished capture puts the creature in one carry slot (`State.carrying`), apart from the temporary bag. Only one wild creature is carried at a time; a second capture is refused before it starts (the capture rule's `bagRoom` is now the free carry slot, notice "Ya llevas una criatura...") and, if it ever reached the grant, `AlreadyCarrying` with nothing claimed.
- A carried creature is not owned: it cannot be equipped and the chest does not take it. The refuge registers it (B3).
- A defeat loses it unless a valid ward applies: an armed or manual seal, or an active totem, exactly as for bag items (`protect`, `armSeal`, `sealNewest` treats it as the newest item). Registered companions, the equipped selection, banked eggs, banked materials and Ember are never lost.
- Walk speed while carrying is `CREATURE_CARRY_SPEED` 14 (from 16) in `WildboundLumipolWild.CONSTANTS`; the slower of egg and creature speed applies, Light Load adds its bonus, and every value stays above Silueta's 8. Set it to 16 to turn the cost off.
- Carrying adds nothing to what Silueta senses. A strike drop (D6) still takes bag items only; delivery C decides whether a strike can shake the creature loose.
- The carry slot is not in the saved record (schema 1): it is at risk, like the bag.

## B2. The carried capsule and its fear

- The server builds `WildboundCarryCapsule` inside the carrier's character: a wooden strap, a glass ball with a wooden base ring and the primitive Lumipol inside, facing backwards, with a small point light. Every part is massless and has collision, touch and query off, so it never changes movement or blocks a ray. Because the server builds it, every player sees it.
- Mood comes from the existing threat reading, read by the server once per fixed step: Silueta's state and distance (`guardianReading`), the fog and the safe zone (`WildboundWorldRules.zone`). `WildboundCarry.mood`: `afraid` when Silueta is hunting (any state but Retreat) within 40 studs in the fog, `uneasy` when hunting within 80 or anything within 40, `calm` otherwise and always in the safe zone, out of the fog or when dead.
- The server publishes the mood as the capsule's `Mood` attribute and repaints the glass and light (calm teal, uneasy amber, afraid red; fear glows brighter). Each client moves only the creature's `Seat` joint with `WildboundCarry.pose`: a small bob (0.08 studs), plus a fast shake (up to 0.12 studs and 0.12 rad) when uneasy or afraid. That joint offset never replicates.
- Sound hook, no sound: when the mood rises the server sets `SoundCue` ("unease" or "fear") and `SoundCueAt` on the capsule, at most once per 8 s; staying scared is silent, so carrying never makes constant noise. Delivery D plays it.
- The HUD's second line names the carried creature and its state, for example "Llevas: Lumipol · inquieto · sin proteger", shortened to fit (`WildboundCarry.hudLine`), amber when afraid. The Bag tab shows the carried creature in its own row with a Protect button.

## B3. The creature refuge

- A physical station in camp (see `docs/maps/wildbound-p0.md`, camp stations) with the prompt "Registrar criatura" (key V, pad R1, 0.4 s hold, 10 studs) on `RefugeMarker`.
- The server picks the token: the carried creature's uid. `State:register` moves it to the permanent collection, pays its tier Ember plus, if the trip was still open, its base Ember, and unlocks its collection entry (`discovered`). A repeat (double press or resent request) finds the uid already registered: it says "Esa criatura ya está registrada." and pays nothing. With nothing carried it says to go capture one.
- Deposit animation: a primitive Lumipol leaves the capsule's position and arcs 3 studs high into the refuge's nest over 1.2 s, shrinking to 40 %, then the refuge glow flashes (`WildboundRefuge.depositPose`, driven by a tweened clock so the adapter keeps no waiting loop). The capsule disappears with the next reply.
- Presentation card: the reply carries the receipt; the client words it with `WildboundRefuge.card` and shows a pop-in card with "¡Nueva criatura!" (or "Criatura registrada" after the first), the name, a one-line blurb, "Entrada de colección desbloqueada" the first time, "+N Ember", and Equip and Close buttons 44 pixels high. It closes itself after 12 s.
- Analytics: a new once-per-session `first_register` event, and the refuge ends an open trip as `extracted`, like the chest.

## B4. Display, chest, board and incubator

- Display: four pedestals. Each player with a registered Lumipol gets one spot, first come first served (`Refuge.assignSpot`), showing the equipped Lumipol or else the first registered one, with "de <name>" on its plaque. Rule for co-op: every player sees every spot, each spot belongs to exactly one player, and no spot has a prompt, so nobody can take, move or swap another player's creature. A fifth player gets no spot until one frees; leaving frees it. Each client adds the idle bob and slow look-around locally (`Refuge.idlePose`) from the `Base` frame the server set.
- Storage chest: the old single "Extract" prompt is now the chest, "Guardar en el cofre" on `ExtractionMarker` (key E). It stores the temporary bag (eggs, Nightbloom bundles) and the pouch materials permanently and ends the trip. The carried creature is separate: the chest never takes it and says "Las criaturas se registran en el refugio, no en el cofre." The bag (temporary, lost on defeat unless warded) and the banked stock (permanent) are shown apart in the inventory.
- Upgrade board: "Ver mejoras" (key B, pad L2) on `BoardMarker` opens the existing Camp screen (crafting, the Reinforced Pack, skills), paid with banked materials and Ember. The board only opens the screen; every purchase is still checked by the server.
- Incubator: a placeholder (slate base, glass dome, a canvas egg) with "Incubadora" and "Próximamente" signs and no prompt. Delivery E builds it. The old free hatch prompt at `HatchMarker` is unchanged.
- Camp prompt keys are all distinct (`WildboundPromptKeys`): chest E, hatch R, protect T, refuge V, board B; F, Q, X, G, C, I and M are taken by other controls.

## Tests

`tests/WildboundState_Test.luau` (B1 cases), `tests/WildboundLumipolWild_Test.luau` (carry speed and the first-capture rule), `tests/WildboundCarry_Test.luau` (mood, look, pose, sound hook, HUD line, wiring), `tests/WildboundText_Test.luau`.

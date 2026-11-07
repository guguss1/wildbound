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

## B5. The equipped companion

- Equip (from the card's "Equipar" button or the Bag tab) is checked by the server as before; only a registered pet can be equipped.
- The server builds `WildboundCompanion` in `WildboundRuntime.WildboundCompanions`: the primitive Lumipol at half size, every part unanchored, massless, non-colliding, untouchable and unqueryable, welded to its body. An `AlignPosition` and an `AlignOrientation` pull it to `WildboundCompanionAnchor`, an attachment the server puts in the owner's root 3 studs to the side, 1.6 up and 1.5 back (`Refuge.companionOffset`). There is no reaction force, so it never pushes, blocks or slows the owner. The server makes the owner its network owner, so it moves smoothly for the owner and replicates to everyone.
- The owner's client moves that attachment for a small hover bob and a 1.2-stud hop for 0.6 s after a pulse; since the owner simulates the companion, every player sees the motion. Every client flashes a companion's light when its owner's `WildboundPulseAt` attribute is fresh; the world server sets it on an accepted Lumipol pulse (the existing ability, unchanged). The camera fade near the companion is kept.
- It is rebuilt for every new character and removed while dead or gone, so a registered companion is never lost: it comes back after a defeat. The client-only companion (`WildboundLocalLumipol`) is removed.
- A Studio-only, server-only `ServerStorage.WildboundTelemetry.CarryProbe` (like A-8's capture probe) writes only `probe:` keys and can read a real player's carry slot and collection, for the two-session ownership check.

## Play check (2026-11-07, Studio Play solo, damage off)

Studio instance `81631061-...`, place 122652861404212, iPhone 17 Pro (750 x 381) then Galaxy A06 (705 x 338) landscape in the Device Simulator. Workarounds as in delivery A: positions set by server `PivotTo`, the prompts by `ProximityPrompt:InputHoldBegin`, the ring followed with `Humanoid:MoveTo`, the seal and Equip by the same remote the buttons fire, the pulse by the world remote the Pulse button fires.

| Step | Result | Evidence |
| --- | --- | --- |
| Capture, then the capsule is visible | PASS | S0a and L4 captures `Completed`; capsule on the back, walk speed 14, HUD "Llevas: Lumipol · tranquilo" |
| Fear cue when Silueta is near | PASS | 14 to 20 studs from Silueta in Alert, Hunt and Telegraph: mood `afraid`, glass and light red, `SoundCue` "fear"; HUD "¡asustado!"; farther away `uneasy` and amber |
| A second capture is refused while carrying | PASS | L4 prompt: "Ya llevas una criatura. Regístrala en el refugio." |
| Return, register, card, display | PASS | "Lumipol registrado. Ahora es tuyo para siempre."; the deposit model was seen mid-arc; card with entry and "+6 Ember"; a second press: "Esa criatura ya está registrada.", no second card or Ember; a Lumipol with the owner's name on display spot 1 |
| Chest deposit, then the upgrade board | PASS | Chest: "Guardado: 1 objeto(s) y 0 material(es). +14 Ember." and, with only a creature carried, the refuge notice; board: "Mejoras y habilidades del campamento." and the Camp screen opens |
| Equip, follow, pulse | PASS | "Lumipol te acompaña."; companion 3.6 to 4.0 studs from the owner while walking 22.7 studs at 16; non-colliding, massless, unanchored; pulse accepted, hop 1.12 studs, light 3.0 |
| Die while carrying (server sets Health 0) | PASS | Carried `wb:3` lost; registered 1 and equipped `wb:2` kept; no companion while dead, back 3.6 studs from the new character; loss summary "Lost 1 item: Lumipol. Kept: 1 registered" |
| Two-session ownership probe | PASS | `probe:B` registering A's companion uid or a forged token: `NotCarried`; its own carried creature registers once, the repeat pays 0; A unchanged; writes to a real player's key: `ProbeKeysOnly` |

Captures (`assets/exports/forest-kit/captures/`, each looked at): `b-carry-calm-iphone17pro-landscape.jpg`, `b-carry-uneasy-iphone17pro-landscape.jpg`, `b-carry-afraid-iphone17pro-landscape.jpg`, `b-card-iphone17pro-landscape.jpg`, `b-companion-camp-iphone17pro-landscape.jpg`, `b-carry-companion-galaxya06-landscape.jpg`, `b-defeat-carried-lost-galaxya06-landscape.jpg`, `b-camp-display-companion-galaxya06-landscape.jpg`, `b-board-camp-screen-galaxya06-landscape.jpg`, `b-camp-dusk-galaxya06-landscape.jpg`.

Not verified: real touch and real phones, two real clients (the display and companion replication to a second client was not seen; only the server probe ran), latency on the companion follow, portrait, how the companion behaves on stairs or steep slopes, and whether the camp reads as cozy to players. The tutorial card still says "press Extract" and the loss summary and Camp screen are English (delivery F).

## Tests

`tests/WildboundState_Test.luau` (B1 cases), `tests/WildboundLumipolWild_Test.luau` (carry speed and the first-capture rule), `tests/WildboundCarry_Test.luau` (mood, look, pose, sound hook, HUD line, wiring), `tests/WildboundRefuge_Test.luau` (deposit, card, display spots, idle, companion offset, camp words and wiring), `tests/WildboundP0Map_Test.luau` (camp stations), `tests/WildboundPromptKeys_Test.luau`, `tests/WildboundAnalytics_Test.luau` and `tests/WildboundAnalyticsWiring_Test.luau` (`first_register`), `tests/WildboundText_Test.luau`.

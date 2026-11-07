# Wildbound session loot contract

## Status and boundaries

Local source is implemented and deployed; its 17 state contracts passed and a solo Studio session ran on 11-05 (`odd/tasks/wildbound-first-playable.md:112-113`). Multiplayer and mobile checks are **pending**. No RED/GREEN, persistent storage or completed playable verification is claimed. Existing Rescue code is untouched.

Deploy `WildboundState` and `WildboundServer` together under a new server-owned folder in ServerScriptService. The adapter expects Workspace.WildboundP0 with recursive BasePart markers named CampCenter, LumipolMarker, EggMarker, ExtractionMarker, HatchMarker and ProtectionMarker. It refuses duplicate WildboundRuntime/WildboundNetwork roots rather than overwriting existing content. Restart a fresh server for a clean session; do not hot-rerun over live roots.

## Safe character entry

Each newly bound live character is moved once to `CampCenter.Position + Vector3.new(0, 4, 10)`, inside camp's safe region. The existing SpawnLocation and global spawn settings are not modified. The server waits at most 10 seconds for HumanoidRootPart, then revalidates the profile record, life generation, current character, health and marker ancestry before moving that character. The death listener is already connected during this wait; a stale callback cannot move a later life. No inventory action or companion ability teleports a character. Registered pets/equipped selection remain in the same session state across ordinary respawn. Actual spawn placement, floor clearance and death/reset races remain unexecuted runtime checks.

## State rules

- `State.new()` is pure and synchronous, with no Instances, yielding calls, network or DataStore dependency. The adapter owns measured position, alive state, timing and server IDs.
- Register players with `addPlayer(key)`. Nonempty strings up to 128 bytes and finite integer numbers are accepted; type-prefixed keys avoid string/number collisions. Repeat add does not reset inventory. `removePlayer` frees the profile, not world ownership.
- `registerEncounter(id, kind)` accepts unique IDs and Creature/Egg kinds. `pickup(key, id, alive, distance)` requires a live player within 10 studs and returns `(true, uid)` or `(false, reason)`. Each world encounter has one shared winner. Invalid requests never reserve it.
- Temporary bag capacity is three. Total carried + pending + banked + registered collection is capped at 100 per connected player; full profiles receive CollectionFull without claiming loot. There is no deletion/trading UI in this prototype.
- Carry slot (delivery B, B1). `completeCapture` puts the creature in `carrying`, a single slot apart from the bag; a second capture is refused `AlreadyCarrying` and claims nothing. `captureRoom` returns the free carry slot first (the capture rule still names it `bagRoom`, so its `BackpackFull` ending now means "already carrying"). A carried creature is not owned: it cannot be equipped, and the chest never takes it. Seals and totems ward it like a bag item (`protect`, `armSeal`, `sealNewest`, which treats it as the newest item); a defeat loses it unless warded; a capsule at the shelter registers it. A strike drop (D6) still takes bag items only; delivery C decides whether a strike can shake the creature loose.
- `register(key, uid, alive, distance, now)` is the refuge (B3): camp distance at most 12, the carried creature joins `registered`, pays its tier Ember and unlocks `discovered[species]`. It is idempotent per token (the creature uid): repeating it returns `(true, uid, { repeated = true, ember = 0 })` and pays nothing. Registered pets, the equipped selection and banked eggs are never lost.
- `extract(key, alive, distance)` is the storage chest (B4): camp distance at most 12, bag eggs to banked eggs, Nightbloom bundles and pouch materials to banked materials, and returns `(true, transferredCount, receipt)`. Empty extraction rejects. A trip ends at the first station that takes something, chest or refuge: the base Ember, the companion bond and the first seal are paid there once, and the other station pays no second base. The first nonempty extraction or registration earns exactly one seal; later ones cannot farm charges.
- `hatch(key, eggUid, alive, distance)` requires an owned banked egg within 12 studs of hatch, consumes it once, and returns a newly generated registered pet UID. Hatching is free.
- `equip(key, petUid, alive)` only accepts owned registered pets. The adapter sets WildboundEquippedUid and WildboundHasLumipol player attributes. The server-owned following companion (delivery B5) lives in the adapter, see [extraction](wildbound-extraction.md).
- `protect(key, pendingUid, alive)` selects exactly one owned pending item. Marking does not spend the seal. Extraction clears protection without spending it. On defeat, one marked item survives as unprotected pending loot and consumes one charge; unprotected pending items are lost. Registered pets, equipped selection and banked eggs remain.
- `defeat(key, operationId)` returns `(true, lostCount)`. The last 256 unique operation IDs are deduplicated per profile; this is a bounded replay window, **not eternal arbitrary-ID idempotency**. The adapter additionally guards callbacks by current character generation and a once-per-life flag, so old character callbacks cannot affect later lives. Character replacement is also treated as a defeat boundary.
- Snapshot arrays and their entries are detached copies. Snapshot contains sessionOnly=true, capacity, collectionLimit, pending, bankedEggs, registered, optional equippedUid and sealCharges, plus optional `carrying` and the `discovered` species (B1). The saved record (schema 1) does not hold the carry slot: a carried creature is at risk, like the bag; `discovered` is rebuilt from the registered species. Leaving the server discards the profile; returning starts fresh. No cross-session persistence is implied.

## Network and prompts

ReplicatedStorage.WildboundNetwork contains RemoteEvents `Action` (client to server) and `State` (server to client).

```luau
Action:FireServer("RequestSnapshot")
Action:FireServer("Equip", petUid)
Action:FireServer("Hatch", bankedEggUid)
Action:FireServer("Protect", pendingUid)
-- State.OnClientEvent receives one table:
{ snapshot = detachedSnapshot, action = actionName, ok = boolean, notice = englishMessage }
```

Only these four action names are accepted. UID is a nonempty string of at most 128 bytes, extra arguments are rejected, and no client-supplied position, distance, player identity or alive state is used. All accepted actions, including RequestSnapshot and world prompts, share an 80 ms minimum interval plus a 300 ms per-action interval. Throttled/malformed requests are silently dropped to avoid response amplification.

Pickup and extraction prompts invoke server state directly. Hatch prompt targets the first banked egg; inventory Hatch targets the selected UID. Protection prompt gives selection guidance only: the inventory Protect button must explicitly select a pending UID within 12 studs of ProtectionMarker. Prompts have touch-compatible controls and a short hold, but activation is not trusted: the adapter rechecks enabled status, ancestry, current character, health and measured distance.

Two server-owned encounter slots respawn 20 seconds after successful pickup. IDs monotonically advance and are never reused. The old callback is disconnected and its visual destroyed before `retireEncounter` removes its record; late old IDs reject as unknown, not available loot. Only active slot records remain, avoiding growing claim history. No untrusted caller can register or retire encounters.

## Pending verification

- Run `tests/WildboundState_Test.luau` against a freshly cloned state ModuleScript; it returns `{passed, failed, messages}` for 17 contract cases. No framework is required.
- Verify actual prompts and UI actions, two-client contested pickup, spam, dead/out-of-range input, death/reset races, reconnect, long-session respawns, cap behavior and mobile layouts.
- Review deployment folder paths and visual marker placement in the confirmed place. Local Luau compiler/analyzer was unavailable during this implementation stage; no syntax-runtime result is claimed.
- Silueta, counterplay, shared day/night and decorative companion visuals are now authored in separate world modules; see [world rules](wildbound-world.md). Their deployment/runtime validation and real persistence remain pending.

Security reference: [Roblox client-server boundary guidance](https://create.roblox.com/docs/scripting/security/client-server-boundary).


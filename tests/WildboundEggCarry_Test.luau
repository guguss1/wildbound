-- Invoke with require(freshTestClone)(require(freshEggCarryClone), freshEggCarryClone.Source, { server =
-- WildboundServer.Source, worldClient = WildboundWorldClient.Source, text = require(freshTextClone),
-- state = require(freshStateClone), economy = require(freshEconomyClone), config = require(freshConfigClone),
-- keys = require(freshKeysClone), stamina = require(freshStaminaClone), island = require(freshIslandClone),
-- audio = WildboundAudioClient.Source, schema = require(freshSchemaClone) }).
-- Nest Heist, phase 1 (docs/design/wildbound-combined-plan.md, tasks NH1 to NH8 in the feature document): the pure
-- egg-carry rules and the source contracts for how the inventory server wires them.
return function(EggCarry, source, sources)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function has(text, needle, label)
		assert(type(text) == "string" and text:find(needle, 1, true), (label or "source") .. " lacks " .. needle)
	end
	local function hasNot(text, needle, label)
		assert(type(text) == "string" and not text:find(needle, 1, true), (label or "source") .. " still has " .. needle)
	end
	local function block(text, startNeedle, endNeedle)
		local i = text:find(startNeedle, 1, true)
		assert(i, "block start missing: " .. startNeedle)
		local j = text:find(endNeedle, i + #startNeedle, true)
		assert(j, "block end missing: " .. endNeedle)
		return text:sub(i, j)
	end
	sources = type(sources) == "table" and sources or {}
	local server = sources.server or ""

	-- NH1 fast steal.
	-- Deliberately changed (PF1 re-pin, live Studio pulled in PF0): the frantic grab is 0.5 s, a rare egg 0.75 s.
	case("NH1: a normal egg is stolen with a 0.5 s hold; a rare or special egg keeps its 0.75 s hold", function()
		equal(type(EggCarry.CONSTANTS), "table", "CONSTANTS")
		equal(EggCarry.CONSTANTS.STEAL_HOLD, 0.5, "steal hold")
		equal(EggCarry.CONSTANTS.RARE_HOLD, 0.75, "rare hold")
		equal(EggCarry.holdFor("Comun"), 0.5)
		equal(EggCarry.holdFor("Rara"), 0.5)
		equal(EggCarry.holdFor("Epica"), 0.75)
		equal(EggCarry.holdFor("Legendaria"), 0.75)
		equal(EggCarry.holdFor("Comun", true), 0.75, "the biome event's egg")
		equal(EggCarry.holdFor(nil), 0.5, "an unknown tier is a normal egg")
	end)

	case("NH1: the steal hold stays inside 0.35 to 1 s and a rare hold is never shorter", function()
		EggCarry.tune({ STEAL_HOLD = 0.1 })
		equal(EggCarry.holdFor("Comun"), 0.35, "floor")
		EggCarry.tune({ STEAL_HOLD = 3 })
		equal(EggCarry.holdFor("Comun"), 1, "ceiling")
		EggCarry.tune({ STEAL_HOLD = 0.9, RARE_HOLD = 0.5 })
		equal(EggCarry.holdFor("Epica"), 0.9, "rare never under the steal hold")
		EggCarry.tune({ STEAL_HOLD = "x" })
		equal(EggCarry.holdFor("Comun"), 0.5, "a non-number is ignored")
		EggCarry.tune(nil)
		equal(EggCarry.holdFor("Comun"), 0.5, "nil restores the defaults")
	end)

	case("NH1: the server gives each egg prompt its hold from the rule and eggs never start a capture ring", function()
		has(server, 'WaitForChild("WildboundEggCarry")', "the server requires the rule")
		local spawn = block(server, "spawnEncounter = function(slot)", "\nend\n")
		has(spawn, "EggCarry.holdFor(rarity, slot.special)", "the egg prompt hold")
		hasNot(spawn, "isEgg and 1 or 0", "the old fixed 1 s hold")
		local egg = block(spawn, "if isEgg then", "\t\telse\n")
		hasNot(egg, "startCapture", "an egg never opens the ring")
	end)

	-- NH2 the egg in the arms.
	case("NH2: an egg starts InNest under its own id and a steal makes it Carried by one player", function()
		equal(table.concat(EggCarry.STATES, ","), "InNest,Carried,Dropped,Secured,Despawning")
		local reg = EggCarry.new()
		local egg = EggCarry.add(reg, "Egg:1", { species = "Lumipol", rarity = "Comun" })
		equal(egg.state, "InNest")
		equal(EggCarry.add(reg, "Egg:1", {}), nil, "an id is unique")
		local ok, carried = EggCarry.steal(reg, "Egg:1", 7, "u1")
		assert(ok, "steal")
		equal(carried.state, "Carried"); equal(carried.carrier, 7); equal(carried.uid, "u1")
		equal(EggCarry.carriedBy(reg, 7), carried)
		equal(carried.meta.rarity, "Comun", "meta kept")
	end)

	-- Deliberately changed (PF1 re-pin, live Studio pulled in PF0): a player carries eggs up to the bag capacity
	-- (maxCarry, default EggCarry.MAX_CARRY); an egg still never has two carriers.
	case("NH2: eggs per player up to the bag capacity and never two carriers", function()
		local reg = EggCarry.new()
		EggCarry.add(reg, "Egg:1", {}); EggCarry.add(reg, "Egg:2", {})
		assert(EggCarry.steal(reg, "Egg:1", 7, "u1"))
		local ok, reason = EggCarry.steal(reg, "Egg:2", 7, "u2", 1)
		equal(ok, false); equal(reason, "AlreadyCarrying", "a full bag")
		ok, reason = EggCarry.steal(reg, "Egg:1", 8, "u3")
		equal(ok, false); equal(reason, "NotInNest", "a carried egg cannot be taken from the nest again")
		equal(EggCarry.get(reg, "Egg:1").carrier, 7, "the first thief keeps it")
		equal(select(2, EggCarry.steal(reg, "Egg:9", 8)), "NoEgg")
		equal(select(2, EggCarry.steal(reg, "Egg:2", nil)), "InvalidPlayer")
		equal(EggCarry.count(reg, "Carried"), 1); equal(EggCarry.count(reg, "InNest"), 1)
		assert(EggCarry.steal(reg, "Egg:2", 7, "u2", 2), "a second egg while the bag has room")
		equal(EggCarry.carriedCount(reg, 7), 2)
	end)

	case("NH2: an expiring spawn retires only an egg still in its nest", function()
		local reg = EggCarry.new()
		EggCarry.add(reg, "Egg:1", {}); EggCarry.add(reg, "Egg:2", {})
		EggCarry.steal(reg, "Egg:2", 7, "u")
		equal(EggCarry.retire(reg, "Egg:1"), true); equal(EggCarry.get(reg, "Egg:1"), nil)
		equal(EggCarry.retire(reg, "Egg:2"), false, "the carried egg stays")
		equal(EggCarry.get(reg, "Egg:2").state, "Carried")
	end)

	case("NH2: the state marks a stolen egg as held in the arms", function()
		local State, Economy, Config = sources.state, sources.economy, sources.config
		local s = State.new(Economy, Config)
		s:addPlayer(1)
		assert(s:registerEncounter("Egg:1", "Egg"))
		local ok = s:pickup(1, "Egg:1", true, 0, { species = "Lumipol", tier = "Fog", arms = true })
		assert(ok, "pickup")
		equal(s:snapshot(1).pending[1].inArms, true)
		assert(s:registerEncounter("Egg:2", "Egg"))
		s:addPlayer(2)
		assert(s:pickup(2, "Egg:2", true, 0, { species = "Lumipol", tier = "Fog" }))
		equal(s:snapshot(2).pending[1].inArms, nil, "without arms, as before")
	end)

	case("NH2: the server registers nest eggs, steals into the arms and welds a massless egg to the root", function()
		has(server, "local eggs = EggCarry.new()")
		local spawn = block(server, "spawnEncounter = function(slot)", "\nend\n")
		has(spawn, "EggCarry.add(eggs, id,", "an InNest record per egg")
		has(spawn, "EggCarry.canSteal(eggs, id, player.UserId, maxCarry)", "up to the bag capacity, checked before the state")
		has(spawn, "local maxCarry = Economy.bagCapacity(EconomyConfig, snap and snap.upgrades or nil)")
		has(spawn, "Text.EGG.already")
		has(spawn, "arms = true", "the state knows the egg is in the arms")
		has(spawn, "EggCarry.steal(eggs, id, player.UserId, reason, maxCarry)")
		has(spawn, "syncEggArms(player)")
		local arms = block(server, "function Heist.syncEggArms(player)", "\nend\n")
		has(arms, "capsulePart(", "unanchored, massless, no collision, touch or query (the capsule's part)")
		-- Deliberately changed (user, 2026-11-11, Studio sync df278fd): the egg rides in a backpack on the upper torso
		-- (was welded in front of the root, in the arms). The pack is welded to the back, the egg to the pack's top.
		has(arms, 'weld("BackpackHold", back, pack', "the pack on the back")
		has(arms, 'character:FindFirstChild("UpperTorso")', "the back is the upper torso")
		has(arms, 'weld("EggHold", pack, shell', "the egg peeks out of the pack")
		has(arms, "Art.CONFIG.PACK_EGG_HEIGHT", "the art egg sized for the pack")
		has(block(server, "local function removeEntry(entry, now)", "\nend\n"), "EggCarry.retire(eggs, entry.id)")
		local part = block(server, "local function capsulePart(", "\nend\n")
		has(part, "part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.Massless = false, false, false, false, true")
	end)

	-- PF1 (user, 2026-11-14): exactly one backpack, and only while carrying an egg; it marks "something not yet hatched".
	-- A carried creature wears no bag (WildboundCarry_Test pins the capsule itself).
	case("PF1: one backpack, only while carrying an egg; the carried creature wears no bag", function()
		local arms = block(server, "function Heist.syncEggArms(player)", "\nend\n")
		local _, packs = arms:gsub('capsulePart%(model, "Backpack"', "")
		equal(packs, 1, "pack parts")
		has(arms, 'local EGG_ARMS = "WildboundEggCarried"', "the name BaseGuide and the beasts read")
		has(arms, 'model:SetAttribute("EggId", egg.id)')
		has(arms, "local egg = EggCarry.carriedBy(eggs, player.UserId)", "one pack whatever the egg count")
		has(arms, "if not egg or not record", "no egg, no pack")
		for _, name in ipairs({ '"Flap"', '"Pocket"', '"Strap"', '"Egg"' }) do
			has(arms, "capsulePart(model, " .. name, "the pack part SistemaSonriente dresses")
		end
		has(arms, 'weld("EggHold", pack, shell, CFrame.new(0, 0.85, 0))', "the egg sits in the pack's open top")
		local capsule = block(server, "local function buildCapsule(character, carried)", "\nend\n")
		for _, bag in ipairs({ '"Backpack"', '"Strap"', '"Base"', "Enum.Material.Fabric", "Enum.Material.Glass" }) do
			hasNot(capsule, bag, "the creature capsule")
		end
	end)

	case("NH2: the Spanish egg notices fit 64 bytes", function()
		local E = sources.text and sources.text.EGG
		assert(type(E) == "table", "Text.EGG")
		for key, value in pairs(E) do
			assert(type(value) == "string" and #value > 0 and #value <= 64, "EGG." .. key .. " " .. tostring(value))
		end
		assert(E.stolen and E.already, "stolen and already")
	end)

	-- NH3 the parent's reaction.
	case("NH3: the parents chase the egg thief at once and the charge is told, logged and exposed", function()
		local readings = block(server, "local function islandReadings()", "\nend\n")
		has(readings, "EggCarry.carriedBy(eggs, player.UserId)", "an egg thief is this island's thief")
		local spawn = block(server, "spawnEncounter = function(slot)", "\nend\n")
		has(spawn, 'Island.event(island.meter, "EggTaken").woke then wakeIsland(', "the steal wakes the island")
		local steps = block(server, "local function stepIslands(now, dt)", "\nend\n")
		has(steps, 'event == "PounceWindUp"', "the tell's warning")
		has(steps, 'event == "Charge"'); has(steps, 'event == "ChargeMissed"'); has(steps, "Text.ISLAND.exposed")
		has(steps, 'event == "Hit" and live then adultHit(island, target)', "a dash that lands hurts like a swing")
		has(steps, 'c.mode == "Strike" or c.mode == "Pounce"', "the tell is the rearing pose")
		has(steps, "select(2, Rules.zone(root.Position.X, root.Position.Z)) == true", "the camp ends a chase")
		local wake = block(server, "local function wakeIsland(island, now)", "\nend\n")
		has(wake, "not select(2, Rules.zone(reading.x, reading.z))", "nobody in the camp is chased")
		local Island = sources.island
		assert(Island.CONSTANTS.POUNCE_TELL >= 0.8, "the charge's tell keeps the fair-strike 0.8 s")
	end)

	-- NH4 the Burst, retired by Esquiva perfecta (Q3b; deliberately changed: the Burst's numbers stay in
	-- WildboundStamina_Test, the dodge's in WildboundDodge_Test, its wiring in WildboundMechanicsWiring_Test).
	case("Q3b: the server owns the dodge: the word over the stance remote, the rule's verdict, the speed and the effects", function()
		local stance = block(server, "stanceRemote.OnServerEvent:Connect(function(player, intent, ...)", "\nend)")
		has(stance, 'if intent == "dodge" then', "a dodge is one known word")
		hasNot(stance, 'intent == "burst"', "the Burst's word is retired")
		assert(stance:find("STANCE_RATE", 1, true) < stance:find('intent == "dodge"', 1, true), "after the rate limit")
		local fn = block(server, "function Heist.dodge(player, record, now)", "\nend\n")
		-- Play finding: the handler first called a burst defined below it (a nil global at run time).
		assert(server:find("function Heist.dodge(player, record, now)", 1, true)
			< server:find("stanceRemote.OnServerEvent:Connect", 1, true), "dodge is defined before the handler that calls it")
		hasNot(server, "function Heist.burst(", "the Burst is retired")
		has(fn, "Heist.DodgeService.press(player, now, blocked)", "the rule's verdict")
		has(fn, "capturing or hidden", "blocked during a capture or hidden")
		has(fn, "applyCarry(player)"); has(fn, "emitter:Emit(")
		hasNot(fn, 'Instance.new("Sound")', "the inventory server makes no sounds")
		local audio = sources.audio or ""
		has(audio, 'other:GetAttribute("WildboundDodgeBoost")', "every client hears a perfect dodge")
		has(audio, 'playOnce("dirt", burstRoot', "a catalogued slot, never a new id")
		local carry = block(server, "local function applyCarry(player)", "\nend\n")
		has(carry, "Heist.DodgeService.speed(player, speed,"); hasNot(carry, "Stamina.bursting(")
		-- Deliberately changed (Q4): the bat's knock added one server-to-client remote (BatKnock).
		local _, remotes = server:gsub('Instance.new%("RemoteEvent"%)', "")
		equal(remotes, 6, "no new remote besides the knock's")
	end)

	-- Deliberately changed (Q3b): the Burst's inputs (Keys.BURST: Z, R3) and slot now ask for a dodge.
	case("Q3b: Z, R3 and the Esquivar button ask for a dodge; the button counts the cooldown down", function()
		local client = sources.worldClient or ""
		has(client, '"WildboundDodge"'); has(client, "Enum.KeyCode.Z, Enum.KeyCode.ButtonR3")
		has(client, 'stanceRemote:FireServer("dodge")'); has(client, "WildboundDodgeReady")
		hasNot(client, 'stanceRemote:FireServer("burst")', "the Impulso button is retired")
		has(client, "dodgeWords.button"); has(client, 'UnbindAction("WildboundDodge")')
		local Keys = sources.keys
		equal(Keys.BURST.key, "Z"); equal(Keys.BURST.pad, "ButtonR3")
		equal(#Keys.conflicts(), 0, table.concat(Keys.conflicts(), "; "))
		equal(sources.text.DODGE.button, "Esquivar")
		equal(sources.text.STAMINA.burst, nil, "the Impulso words are gone")
	end)

	-- NH5 drop and pickup.
	local function carried(id, key)
		local reg = EggCarry.new()
		EggCarry.add(reg, id or "Egg:1", { species = "Lumipol", island = "I2" })
		assert(EggCarry.steal(reg, id or "Egg:1", key or 7, "u1"))
		return reg
	end
	-- Deliberately changed (PF1 re-pin, live Studio pulled in PF0): pickup delay and hold are 0.25 s.
	case("NH5: a drop leaves the egg Dropped and nobody's; it opens to anyone after 0.25 s", function()
		local C = EggCarry.CONSTANTS
		equal(C.PICKUP_DELAY, 0.25); equal(C.PICKUP_HOLD, 0.25); equal(C.PICKUP_RANGE, 10); equal(C.DROP_SECONDS, 30)
		local reg = carried()
		local ok, egg = EggCarry.drop(reg, 7, "Hit", 100, { safe = false })
		assert(ok, "drop")
		equal(egg.state, "Dropped"); equal(egg.carrier, nil); equal(egg.lastCarrier, 7); equal(egg.reason, "Hit")
		equal(EggCarry.carriedBy(reg, 7), nil, "the arms are empty")
		local took, why = EggCarry.pickup(reg, "Egg:1", 8, 100.2, "u2")
		equal(took, false); equal(why, "TooSoon")
		local actions = EggCarry.step(reg, 100.41)
		equal(#actions, 1); equal(actions[1].op, "open")
		assert(EggCarry.pickup(reg, "Egg:1", 8, 100.41, "u2"), "anyone after 0.25 s")
		equal(EggCarry.carriedBy(reg, 8).id, "Egg:1")
	end)

	case("NH5: the first valid pickup wins, with no owner priority, and nobody goes over the bag capacity", function()
		local reg = carried()
		EggCarry.drop(reg, 7, "Strike", 0, {})
		assert(EggCarry.pickup(reg, "Egg:1", 8, 1, "u2"), "a stranger first")
		local ok, why = EggCarry.pickup(reg, "Egg:1", 7, 1, "u3")
		equal(ok, false); equal(why, "NotDropped", "the old carrier is too late")
		equal(EggCarry.get(reg, "Egg:1").carrier, 8)
		EggCarry.add(reg, "Egg:2", {}); assert(EggCarry.steal(reg, "Egg:2", 7, "u4"))
		EggCarry.drop(reg, 7, "Hit", 2, {})
		equal(select(2, EggCarry.pickup(reg, "Egg:2", 8, 3, "u5", 1)), "AlreadyCarrying", "a full bag")
		assert(EggCarry.pickup(reg, "Egg:2", 7, 3, "u6"), "the old carrier may take it back too")
	end)

	case("NH5: inside a safe zone only a death or leaving drops the egg; bad reasons and empty arms are refused", function()
		local reg = carried()
		equal(select(2, EggCarry.drop(reg, 7, "Hit", 0, { safe = true })), "SafeZone")
		equal(select(2, EggCarry.drop(reg, 7, "Bat", 0, { safe = true })), "SafeZone")
		equal(select(2, EggCarry.drop(reg, 7, "Sneeze", 0, {})), "BadReason")
		equal(select(2, EggCarry.drop(reg, 9, "Hit", 0, {})), "NotCarrying")
		equal(EggCarry.carriedBy(reg, 7).state, "Carried")
		assert(EggCarry.drop(reg, 7, "Death", 0, { safe = true }), "a death drops it anywhere")
	end)

	case("NH5: an abandoned egg fades after 30 s and is gone 1 s later; an adult can carry one home", function()
		local reg = carried()
		EggCarry.drop(reg, 7, "Hit", 0, {})
		EggCarry.step(reg, 1)
		equal(#EggCarry.step(reg, 29.9), 0)
		local actions = EggCarry.step(reg, 30)
		equal(actions[1].op, "despawn"); equal(EggCarry.get(reg, "Egg:1").state, "Despawning")
		equal(select(2, EggCarry.pickup(reg, "Egg:1", 8, 30.5, "u")), "NotDropped", "no pickup while fading")
		actions = EggCarry.step(reg, 31)
		equal(actions[1].op, "remove"); equal(EggCarry.get(reg, "Egg:1"), nil)
		reg = carried()
		EggCarry.drop(reg, 7, "Hit", 0, {})
		assert(EggCarry.recover(reg, "Egg:1"), "an adult took it home")
		equal(EggCarry.get(reg, "Egg:1"), nil)
		equal(EggCarry.recover(reg, "Egg:1"), false)
	end)

	case("NH5: a drop lands on the ground under the carrier, never in the air or through the floor", function()
		equal(EggCarry.landingY(10, 7.5, 2), 7.5, "the ground the ray found")
		equal(EggCarry.landingY(10, 12, 2), 2, "a hit above the drop is not ground: the relief")
		equal(EggCarry.landingY(10, -60, 2), 2, "deeper than the fall depth: the relief")
		equal(EggCarry.landingY(10, nil, 2), 2, "no hit: the relief")
		equal(EggCarry.landingY(10, nil, nil), 7, "nothing at all: under the feet")
	end)

	case("NH5: the state lets the egg go to nobody and gives it to whoever picks it up", function()
		local State, Economy, Config = sources.state, sources.economy, sources.config
		local s = State.new(Economy, Config)
		s:addPlayer(1); s:addPlayer(2)
		assert(s:registerEncounter("Egg:1", "Egg"))
		assert(s:pickup(1, "Egg:1", true, 0, { species = "Cestillo", tier = "FogFar", island = "I3", arms = true }))
		local ok, entry = s:dropEgg(1)
		assert(ok, "dropEgg")
		equal(#s:snapshot(1).pending, 0); equal(#s:snapshot(1).dropped, 0, "never the owner's dropped item")
		equal(select(2, s:dropEgg(1)), "NotCarrying")
		equal(select(2, s:takeEgg(2, entry, true, 12)), "InvalidContext", "out of reach")
		assert(s:takeEgg(2, entry, true, 3), "picked up")
		local held = s:snapshot(2).pending[1]
		equal(held.species, "Cestillo"); equal(held.riskTier, "FogFar"); equal(held.inArms, true)
		-- Deliberately changed (PF1 re-pin, live Studio pulled in PF0): a second egg rides in the same bag until it is full.
		local again = table.clone(entry)
		again.uid = "Egg:2"
		assert(s:takeEgg(2, again, true, 3), "a second egg while the bag has room")
		equal(#s:snapshot(2).pending, 2)
	end)

	case("NH5: La Silueta's first strike knocks the egg in the arms loose before any other item", function()
		local State, Economy, Config = sources.state, sources.economy, sources.config
		local s = State.new(Economy, Config)
		s:addPlayer(1)
		assert(s:registerEncounter("Egg:1", "Egg"))
		assert(s:pickup(1, "Egg:1", true, 0, { species = "Lumipol", tier = "Fog", arms = true }))
		local ok, entry = s:dropForStrike(1, "attack-1")
		assert(ok and entry and entry.inArms, "the egg")
		equal(#s:snapshot(1).dropped, 0, "loose for anyone, not the owner's drop")
		local again, none = s:dropForStrike(1, "attack-1")
		assert(again and none == nil, "idempotent per attack")
	end)

	case("NH5: the server drops, lands, opens, re-targets and despawns eggs through the rule", function()
		local drop = block(server, "function Heist.dropEgg(player, reason, loose, from)", "\nend\n")
		has(drop, "EggCarry.drop(eggs, player.UserId, reason, now, { safe = safe })", "a safe zone keeps it")
		has(drop, "local uid = egg.uid", "read before EggCarry.drop clears it"); has(drop, "state:dropEgg(player.UserId, uid)", "the dropped egg's own bag entry"); has(drop, "landingAt(x, at.Y, z)"); has(drop, "pick.Enabled = false")
		has(drop, "syncEggArms(player)", "the arms empty")
		local land = block(server, "function Heist.landingAt(x, y, z)", "\nend\n")
		has(land, "workspace:Raycast("); has(land, "EggCarry.landingY(")
		local pick = block(server, "function Heist.pickupEgg(player, egg)", "\nend\n")
		has(pick, 'allowed(player, "EggPickup")', "rate limited")
		has(pick, "EggCarry.canPickup(eggs, egg.id, player.UserId, now)")
		has(pick, "distance > EggCarry.live.PICKUP_RANGE", "distance checked on the server")
		has(pick, "state:takeEgg(player.UserId, egg.entry, alive, distance)")
		has(pick, "EggCarry.pickup(eggs, egg.id, player.UserId, now, reason)")
		has(pick, "Island.perceives(chase.state, root.Position.X, root.Position.Z)", "no omniscience")
		has(pick, "chase.target = player")
		local stepper = block(server, "function Heist.stepEggs(now)", "\nend\n")
		has(stepper, "EggCarry.step(eggs, now)"); has(stepper, '"open"'); has(stepper, '"despawn"'); has(stepper, '"remove"')
		has(server, "stepEggs(now)", "on the server's step")
		has(block(server, "local function adultHit(island, player)", "\nend\n"), 'dropEgg(player, "Hit")')
		local strike = block(server, "strikeEffect.OnInvoke = function(", "\nend\n")
		has(strike, 'if entry and entry.inArms then Heist.dropEgg(player, "Strike", entry)')
		has(server, 'Heist.dropAllEggs(player, "Leave")', "leaving leaves every carried egg in the world")
		local steps = block(server, "local function stepIslands(now, dt)", "\nend\n")
		has(steps, "EggCarry.recover(eggs, loose.id)", "the parents still carry a loose egg home")
		local E = sources.text.EGG
		assert(E.pickUp and E.knocked and E.picked and E.taken and E.gone, "the NH5 notices")
		local Island = sources.island
		assert(type(Island.perceives) == "function", "Island.perceives")
	end)

	-- Play finding: the server first failed to start, "Out of local registers" (Luau's 200-local limit), after NH5 added
	-- its helpers as top-level locals. They live in one table.
	case("NH5: the Nest Heist helpers live in one table, not as top-level locals of the near-full server script", function()
		has(server, "local Heist = {}")
		for _, name in ipairs({ "syncEggArms", "dropEgg", "clearDroppedEgg", "pickupEgg", "stepEggs", "landingAt", "dodge",
			"landParams", "EGG_ARMS" }) do
			hasNot(server, "\nlocal function " .. name .. "(", "a top-level local function")
			hasNot(server, "\nlocal " .. name .. " ", "a top-level local")
			hasNot(server, "\nlocal " .. name .. ",", "a top-level local")
		end
	end)

	-- NH6 delivery.
	case("NH6: only the carrier secures a carried egg, once; a dropped or unknown egg is refused", function()
		local reg = carried()
		equal(select(2, EggCarry.secure(reg, "Egg:1", 8)), "NotCarrier")
		local ok, egg = EggCarry.secure(reg, "Egg:1", 7)
		assert(ok, "secure")
		equal(egg.state, "Secured"); equal(EggCarry.carriedBy(reg, 7), nil, "the arms are empty")
		equal(EggCarry.get(reg, "Egg:1"), nil, "a secured egg leaves the registry: it is banked")
		equal(select(2, EggCarry.secure(reg, "Egg:1", 7)), "NoEgg", "never secured twice")
		reg = carried()
		EggCarry.drop(reg, 7, "Hit", 0, {})
		equal(select(2, EggCarry.secure(reg, "Egg:1", 7)), "NotCarried", "a dropped egg is not delivered")
	end)

	case("NH6: the chest banks the egg in the arms as before", function()
		local State, Economy, Config = sources.state, sources.economy, sources.config
		local s = State.new(Economy, Config)
		s:addPlayer(1)
		assert(s:registerEncounter("Egg:1", "Egg"))
		local _, uid = s:pickup(1, "Egg:1", true, 0, { species = "Polvilla", tier = "Territory", island = "I4", arms = true })
		local ok = s:extract(1, true, 3, 100)
		assert(ok, "extract")
		local snapshot = s:snapshot(1)
		equal(#snapshot.pending, 0); equal(snapshot.bankedEggs[1].uid, uid); equal(snapshot.bankedEggs[1].species, "Polvilla")
	end)

	case("NH6: the chest and the incubator deliver the egg in the arms through the rule", function()
		local chest = block(server, "extractPrompt.Triggered:Connect(function(player)", "\nend)")
		-- Deliberately changed (PF1 re-pin, live Studio pulled in PF0): the chest secures every carried egg at once.
		has(chest, "Heist.secureAll(player)", "the chest secures them after banking")
		assert(chest:find("state:extract(", 1, true) < chest:find("Heist.secureAll(player)", 1, true), "banked first")
		local incubator = block(server, "hatchPrompt.Triggered:Connect(function(player)", "\nend)")
		has(incubator, "EggCarry.carriedBy(eggs, player.UserId)", "an egg carried to the incubator")
		has(incubator, "Heist.secure(player)"); has(incubator, "hatch(player, uid)")
		local secure = block(server, "function Heist.secure(player)", "\nend\n")
		has(secure, "EggCarry.secure(eggs, egg.id, player.UserId)"); has(secure, "Heist.syncEggArms(player)")
	end)

	-- NH7 death while carrying.
	case("NH7: a death drops the egg in the arms for a while, before the defeat, and keeps everything banked", function()
		local bind = block(server, "local function bindCharacter(player, character)", "\nend\n")
		local died = block(bind, "local function defeated()", "\n\tend\n")
		has(died, 'Heist.dropAllEggs(player, "Death")', "the dying character drops every egg")
		assert(died:find('Heist.dropAllEggs(player, "Death")', 1, true) < died:find("state:defeat(", 1, true),
			"dropped before the defeat, so the defeat never counts it lost")
		local replaced = block(bind, "if record.character and not record.defeated then", "\n\tend\n")
		has(replaced, 'Heist.dropAllEggs(player, "Death", record.character)', "a replaced character drops them where it was")
		assert(replaced:find("Heist.dropAllEggs(", 1, true) < replaced:find("state:defeat(", 1, true), "before the defeat")
		local drop = block(server, "function Heist.dropEgg(player, reason, loose, from)", "\nend\n")
		has(drop, "local character = from or player.Character")
		-- The state: the egg leaves the bag before the defeat, so nothing banked or registered is touched.
		local State, Economy, Config = sources.state, sources.economy, sources.config
		local s = State.new(Economy, Config)
		s:addPlayer(1)
		assert(s:registerEncounter("Egg:1", "Egg")); assert(s:registerEncounter("Egg:2", "Egg"))
		assert(s:pickup(1, "Egg:1", true, 0, { species = "Lumipol", tier = "Fog", arms = true }))
		assert(s:extract(1, true, 3, 10), "one egg banked")
		assert(s:pickup(1, "Egg:2", true, 0, { species = "Lumipol", tier = "Fog", arms = true }))
		assert(s:dropEgg(1))
		local ok, lost = s:defeat(1, "life:1")
		assert(ok); equal(lost, 0, "the dropped egg is not a defeat loss")
		equal(#s:snapshot(1).bankedEggs, 1, "the banked egg stays")
		local reg = carried()
		assert(EggCarry.drop(reg, 7, "Death", 5, { safe = true }), "a death drops it even in a safe zone")
		equal(EggCarry.get(reg, "Egg:1").expireAt, 5 + EggCarry.CONSTANTS.DROP_SECONDS, "for a limited time")
	end)

	-- SistemaSonriente, etapa 1 (odd/tasks/el-sonriente.md, S3): con 2 o más huevos en la espalda, el huevo que cae es
	-- el mismo que sale de la mochila (emparejados por uid), y morir, reaparecer o salir suelta todos, no solo uno.
	case("SON-1: dropping an egg by uid takes that very entry out of the bag; an unknown uid falls back to the first", function()
		local State, Economy, Config = sources.state, sources.economy, sources.config
		local s = State.new(Economy, Config)
		s:addPlayer(1)
		assert(s:registerEncounter("Egg:1", "Egg")); assert(s:registerEncounter("Egg:2", "Egg"))
		local _, first = s:pickup(1, "Egg:1", true, 0, { species = "Lumipol", tier = "Fog", arms = true })
		local _, second = s:pickup(1, "Egg:2", true, 0, { species = "Cestillo", tier = "Fog", arms = true })
		assert(first and second and first ~= second, "two eggs in the arms")
		local ok, entry = s:dropEgg(1, second)
		assert(ok, "dropEgg by uid")
		equal(entry.uid, second, "the newest egg's entry left the bag"); equal(entry.species, "Cestillo")
		local pending = s:snapshot(1).pending
		equal(#pending, 1); equal(pending[1].uid, first, "the other egg stays")
		local ok2, entry2 = s:dropEgg(1, "unknown-uid")
		assert(ok2, "fallback"); equal(entry2.uid, first, "falls back to the first egg in the arms")
		equal(select(2, s:dropEgg(1, first)), "NotCarrying")
	end)
	case("SON-2: death, a replaced character and leaving drop every carried egg through one bounded loop", function()
		local all = block(server, "function Heist.dropAllEggs(player, reason, from)", "\nend\n")
		has(all, "Heist.dropEgg(player, reason, nil, from)", "the one drop path")
		has(all, "EggCarry.carriedBy(eggs, player.UserId)", "until the arms are empty")
		has(all, "break", "a refused drop never loops forever")
		hasNot(server, 'Heist.dropEgg(player, "Death")', "a death never drops just one egg")
		hasNot(server, 'Heist.dropEgg(player, "Leave")', "leaving never drops just one egg")
	end)

	-- SistemaSonriente, etapa 2 (S4, S8): an egg with a home nest (meta.home) lies on the ground its own time
	-- (meta.dropSeconds, 15 s for the Huevo Sonriente) and then goes back to its nest ("return") instead of fading.
	case("SON-3: a home egg lies its own time on the ground, then returns to its nest; other eggs still fade", function()
		local reg = EggCarry.new()
		EggCarry.add(reg, "Egg:S", { home = true, dropSeconds = 15 })
		EggCarry.add(reg, "Egg:N", {})
		assert(EggCarry.steal(reg, "Egg:S", 7, "uid-s"))
		assert(EggCarry.steal(reg, "Egg:N", 8, "uid-n"))
		local _, home = EggCarry.drop(reg, 7, "Guardian", 100, {})
		local _, plain = EggCarry.drop(reg, 8, "Hit", 100, {})
		equal(home.expireAt, 115, "its own 15 s"); equal(plain.expireAt, 100 + EggCarry.live.DROP_SECONDS, "the default")
		local function ops(now)
			local list = {}
			for _, action in ipairs(EggCarry.step(reg, now)) do list[action.egg.id] = action.op end
			return list
		end
		ops(101)
		equal(ops(114.9)["Egg:S"], nil, "still on the ground")
		equal(ops(115)["Egg:S"], "return", "back to its nest")
		equal(EggCarry.get(reg, "Egg:S"), nil, "it left the registry at once (no fade)")
		equal(ops(100 + EggCarry.live.DROP_SECONDS)["Egg:N"], "despawn", "a normal egg still fades")
	end)
	case("SON-4: El Sonriente's catch ('Guardian') and a fall into the void ('Void') are drop reasons; the void even in a safe zone", function()
		equal(EggCarry.DROP_REASONS.Guardian, true); equal(EggCarry.DROP_REASONS.Void, true)
		local reg = carried()
		equal(select(2, EggCarry.drop(reg, 7, "Guardian", 0, { safe = true })), "SafeZone", "the guardian never catches in a safe zone")
		assert(EggCarry.drop(carried(), 7, "Void", 0, { safe = true }), "the void drops it anywhere")
		equal(select(2, EggCarry.drop(carried(), 7, "Nope", 0, {})), "BadReason")
		local bad = EggCarry.new()
		EggCarry.add(bad, "Egg:B", { home = true, dropSeconds = 0 / 0 })
		assert(EggCarry.steal(bad, "Egg:B", 7, "u"))
		local _, egg = EggCarry.drop(bad, 7, "Hit", 10, {})
		equal(egg.expireAt, 10 + EggCarry.live.DROP_SECONDS, "a bad dropSeconds falls back to the default")
	end)

	case("SON-5: the inventory server bridges the Huevo Sonriente to SistemaSonriente/InterfazHuevos and returns it home", function()
		has(server, 'Heist.Sonriente = require(script.Parent:WaitForChild("SistemaSonriente"):WaitForChild("InterfazHuevos"))')
		local bridge = block(server, "Heist.Sonriente.conectar({", "\n})\n")
		has(bridge, "spawnEncounter(slot)", "the egg is a real nest egg (bag, delivery, hatching)")
		has(bridge, "egg.meta.home, egg.meta.dropSeconds = true,", "it has a home nest and its own time on the ground")
		has(bridge, "Heist.dropEgg(player, motivo)", "the one drop path")
		has(bridge, "EggCarry.recover(eggs, id)", "sent home through the rule")
		has(bridge, "RunService:IsStudio()", "the test-only operations exist only in Studio")
		local stepper = block(server, "function Heist.stepEggs(now)", "\nend\n")
		has(stepper, 'action.op == "return"', "a home egg's time is up"); has(stepper, "Heist.clearDroppedEgg(egg)")
	end)

	-- NH8 no relocation mid-interaction or mid-chase.
	case("NH8: a prompt hold counts for at most 3 s after it began, so a lost release never pins a spawn", function()
		equal(EggCarry.HOLD_GRACE, 3)
		equal(EggCarry.holding({}, 10), false)
		equal(EggCarry.holding({ a = 9 }, 10), true)
		equal(EggCarry.holding({ a = 6.9 }, 10), false, "stale")
		equal(EggCarry.holding({ a = 11 }, 10), false, "from the future")
		equal(EggCarry.holding({ a = 6, b = 9.5 }, 10), true)
		equal(EggCarry.holding(nil, 10), false)
	end)

	case("NH8: the spawn clock holds a spawn being captured or held, and a nest refills only after its chase", function()
		local held = block(server, "local function spawnHeld(now)", "\nend\n")
		has(held, 'capture:encounterState(id, now) ~= "Free"', "a capture holds it, as before")
		has(held, "EggCarry.holding(entry.holders, now)", "a prompt hold holds it")
		local spawn = block(server, "spawnEncounter = function(slot)", "\nend\n")
		has(spawn, "entry.prompt.PromptButtonHoldBegan:Connect("); has(spawn, "entry.prompt.PromptButtonHoldEnded:Connect(")
		local respawn = block(server, "local function scheduleRespawn(slot)", "\nend\n")
		has(respawn, "if island and island.chase then", "a nest never changes during its parents' chase")
		has(server, "SpawnClock.step(spawnClock, now, rng, spawnHeld(now))", "the lifetime move respects it")
		has(server, "SpawnClock.reroll(spawnClock, now, rng, spawnHeld(now))", "the wave reroll respects it")
	end)

	-- Nest Heist phase 2 (NP1, a Phase 1 verifier finding): State:takeEgg refuses beyond 10 studs, so the tunable reach
	-- may never promise more. The schema's ceiling is 10 and the rule clamps an override to it.
	case("NP1: the pickup reach never exceeds the state's 10-stud limit", function()
		equal(EggCarry.PICKUP_RANGE_MAX, 10, "the rule's ceiling")
		EggCarry.tune({ PICKUP_RANGE = 20 })
		equal(EggCarry.live.PICKUP_RANGE, 10, "an override is clamped")
		EggCarry.tune({ PICKUP_RANGE = 6 })
		equal(EggCarry.live.PICKUP_RANGE, 6, "a shorter reach applies")
		EggCarry.tune(nil)
		equal(EggCarry.live.PICKUP_RANGE, 10)
		local Schema = sources.schema
		assert(type(Schema) == "table", "the tuning schema")
		equal(Schema.find("Eggs", "PICKUP_RANGE").max, EggCarry.PICKUP_RANGE_MAX, "the panel never offers more")
		local State, Economy, Config = sources.state, sources.economy, sources.config
		local s = State.new(Economy, Config)
		s:addPlayer(1); s:addPlayer(2)
		assert(s:registerEncounter("Egg:1", "Egg"))
		assert(s:pickup(1, "Egg:1", true, 0, { species = "Lumipol", tier = "Fog", arms = true }))
		local _, entry = s:dropEgg(1)
		equal(select(2, s:takeEgg(2, entry, true, 10.5)), "InvalidContext", "beyond the ceiling")
		assert(s:takeEgg(2, entry, true, EggCarry.PICKUP_RANGE_MAX), "at the ceiling")
	end)

	case("NH5: a Studio-only probe drives the real steal, drop and pickup paths for the Play check", function()
		local spawn = block(server, "spawnEncounter = function(slot)", "\nend\n")
		has(spawn, "entry.connection = entry.prompt.Triggered:Connect(entry.trigger)", "the prompt and the probe share one path")
		local studio = block(server, "if RunService:IsStudio() then\n\tlocal probe", "\nend\n")
		has(studio, 'heistProbe.Name = "HeistProbe"'); has(studio, "heistProbe.Parent = telemetry", "ServerStorage only")
		has(studio, "best.trigger(player)"); has(studio, "pickupEgg(player, best)"); has(studio, "dropEgg(player,")
	end)


	-- Nest Heist hub (HB-T7, verifier finding): the steal hold is measured on the server. A client that skips the hold
	-- (a zero-length local hold, or a trigger fired with no hold) no longer steals.
	case("HB-T7: a steal counts only after a continuous hold of the effective time, less a small latency allowance", function()
		local need = 0.8
		local a = EggCarry.live.HOLD_ALLOWANCE
		equal(a > 0 and a <= EggCarry.HOLD_ALLOWANCE_MAX, true, "a small allowance")
		equal(EggCarry.holdComplete({ at = 10 }, 10.8, need), true, "a full hold")
		equal(EggCarry.holdComplete({ at = 10 }, 10 + need - a, need), true, "on the allowance")
		equal(EggCarry.holdComplete({ at = 10 }, 10 + need - a - 0.01, need), false, "short")
		equal(EggCarry.holdComplete(nil, 10.8, need), false, "no hold began on the server")
		equal(EggCarry.holdComplete({ at = 10, ended = 10.3 }, 10.8, need), false, "released early, then triggered")
		equal(EggCarry.holdComplete({ at = 10, ended = 10.79 }, 10.8, need), true, "the release that comes with the trigger")
		equal(EggCarry.holdComplete({ at = 10 }, 10 + need + EggCarry.HOLD_GRACE + 0.01, need), false, "a stale begin")
		equal(EggCarry.holdComplete({ at = 11 }, 10.8, need), false, "a begin in the future")
		for _, bad in ipairs({ 0 / 0, math.huge, "1" }) do
			equal(EggCarry.holdComplete({ at = 10 }, bad, need), false, "now " .. tostring(bad))
			equal(EggCarry.holdComplete({ at = bad }, 10.8, need), false, "at " .. tostring(bad))
		end
		equal(EggCarry.holdComplete(nil, 10, 0), true, "no hold needed (a cria's tap)")
	end)
	-- Hub follow-up (HF-T2): 0.2 s was too tight for real latency. The allowance is a tunable (0.35 s by default, 0.05
	-- to 0.5), still refusing clearly short triggers, and a refused steal tells the player to hold a little longer.
	case("HF-T2: the steal-hold allowance is a tuning value, 0.35 s, that still refuses clearly short triggers", function()
		equal(EggCarry.CONSTANTS.HOLD_ALLOWANCE, 0.35, "the default allowance")
		equal(EggCarry.live.HOLD_ALLOWANCE, 0.35)
		equal(EggCarry.HOLD_ALLOWANCE_MIN, 0.05); equal(EggCarry.HOLD_ALLOWANCE_MAX, 0.5)
		local need = 0.8
		equal(EggCarry.holdComplete({ at = 10 }, 10 + need - 0.35, need), true, "a hold 0.35 s short of a full one counts")
		equal(EggCarry.holdComplete({ at = 10 }, 10 + need - 0.36, need), false, "0.36 s short refuses")
		equal(EggCarry.holdComplete({ at = 10 }, 10, need), false, "a zero-length hold refuses")
		equal(EggCarry.holdComplete({ at = 10 }, 10.2, 0.6), false, "the glove floor 0.6 s still needs 0.25 s")
		EggCarry.tune({ HOLD_ALLOWANCE = 0.2 })
		equal(EggCarry.holdComplete({ at = 10 }, 10 + need - 0.3, need), false, "the tuned allowance is the one read")
		EggCarry.tune({ HOLD_ALLOWANCE = 5 })
		equal(EggCarry.live.HOLD_ALLOWANCE, 0.5, "never more than half a second")
		EggCarry.tune({ HOLD_ALLOWANCE = -1 })
		equal(EggCarry.live.HOLD_ALLOWANCE, 0.05, "never zero or less")
		EggCarry.tune(nil)
		equal(EggCarry.live.HOLD_ALLOWANCE, 0.35, "no override, no change")
		local Schema = sources.schema
		local entry = Schema.find("Eggs", "HOLD_ALLOWANCE")
		assert(entry, "a dev tuning entry")
		equal(entry.module, "EggCarry"); equal(entry.target, "HOLD_ALLOWANCE"); equal(entry.default, 0.35)
		equal(entry.min, 0.05); equal(entry.max, 0.5)
	end)
	case("HF-T2: a steal the server refuses as too short tells the player to hold a little longer", function()
		local Text = sources.text
		equal(Text.EGG.holdLonger, "Mantén presionado un poco más.")
		assert(#Text.EGG.holdLonger <= 64, "a notice of at most 64 bytes")
		local trigger = block(server, "entry.trigger = function(player)", "entry.connection = entry.prompt.Triggered")
		has(trigger, "if not EggCarry.holdComplete(entry.holdStarts[player], workspace:GetServerTimeNow(), need) then\n"
			.. "\t\t\t\tsend(player, \"Pickup\", false, Text.EGG.holdLonger)\n\t\t\t\treturn\n\t\t\tend",
			"the refusal answers with the notice")
		hasNot(trigger, "workspace:GetServerTimeNow(), need) then return end", "no silent refusal")
	end)
	case("HB-T7: the server records each player's hold and checks it, with the glove, before a steal", function()
		local spawnBlock = block(server, "entry.holders = {}", "entry.trigger = function(player)")
		has(spawnBlock, "entry.holdStarts = {}")
		-- CF2: the hold start reads the server clock once (it also judges the wave's Warning window there).
		has(spawnBlock, "local now = workspace:GetServerTimeNow()", "the hold begins on the server clock")
		has(spawnBlock, "entry.holdStarts[player] = { at = now }", "the hold begins on the server")
		has(spawnBlock, "hold.ended = workspace:GetServerTimeNow()", "and its release")
		local trigger = block(server, "entry.trigger = function(player)", "entry.connection = entry.prompt.Triggered")
		local measured = trigger:find("EggCarry.holdComplete(entry.holdStarts[player], workspace:GetServerTimeNow(),", 1, true)
		-- Deliberately changed (Q2b): the steal moved into entry.claimEgg, shared with a won Arrullo; a normal egg's
		-- trigger measures the hold and only then calls it.
		local steal = measured and trigger:find("entry.claimEgg(player)", measured, true)
		assert(measured and steal and measured < steal, "the hold is checked before the steal")
		has(block(server, "entry.claimEgg = function(player)", "entry.trigger = function(player)"),
			"EggCarry.canSteal(eggs, id, player.UserId, maxCarry)", "the steal still checks the bag capacity")
		has(trigger, 'Gear.stealHold(entry.prompt:GetAttribute("WildboundStealHold"),', "the player's own effective hold")
		has(trigger, 'player:GetAttribute("WildboundGloveSteal")', "the glove's bonus the server wrote")
		local studio = block(server, 'if op == "steal" then', "best.trigger(player)")
		has(studio, "best.holdStarts[player] = { at = ", "the Studio probe completes a hold first")
	end)

	return result
end

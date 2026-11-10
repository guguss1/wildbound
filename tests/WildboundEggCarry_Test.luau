-- Invoke with require(freshTestClone)(require(freshEggCarryClone), freshEggCarryClone.Source, { server =
-- WildboundServer.Source, worldClient = WildboundWorldClient.Source, text = require(freshTextClone),
-- state = require(freshStateClone), economy = require(freshEconomyClone), config = require(freshConfigClone),
-- keys = require(freshKeysClone), stamina = require(freshStaminaClone), island = require(freshIslandClone),
-- audio = WildboundAudioClient.Source }).
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
	case("NH1: a normal egg is stolen with a 0.8 s hold; a rare or special egg keeps its 1 s hold", function()
		equal(type(EggCarry.CONSTANTS), "table", "CONSTANTS")
		equal(EggCarry.CONSTANTS.STEAL_HOLD, 0.8, "steal hold")
		equal(EggCarry.CONSTANTS.RARE_HOLD, 1, "rare hold, as before")
		equal(EggCarry.holdFor("Comun"), 0.8)
		equal(EggCarry.holdFor("Rara"), 0.8)
		equal(EggCarry.holdFor("Epica"), 1)
		equal(EggCarry.holdFor("Legendaria"), 1)
		equal(EggCarry.holdFor("Comun", true), 1, "the biome event's egg")
		equal(EggCarry.holdFor(nil), 0.8, "an unknown tier is a normal egg")
	end)

	case("NH1: the steal hold stays inside 0.6 to 1 s and a rare hold is never shorter", function()
		EggCarry.tune({ STEAL_HOLD = 0.1 })
		equal(EggCarry.holdFor("Comun"), 0.6, "floor")
		EggCarry.tune({ STEAL_HOLD = 3 })
		equal(EggCarry.holdFor("Comun"), 1, "ceiling")
		EggCarry.tune({ STEAL_HOLD = 0.9, RARE_HOLD = 0.5 })
		equal(EggCarry.holdFor("Epica"), 0.9, "rare never under the steal hold")
		EggCarry.tune({ STEAL_HOLD = "x" })
		equal(EggCarry.holdFor("Comun"), 0.8, "a non-number is ignored")
		EggCarry.tune(nil)
		equal(EggCarry.holdFor("Comun"), 0.8, "nil restores the defaults")
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

	case("NH2: one egg per player and never two carriers", function()
		local reg = EggCarry.new()
		EggCarry.add(reg, "Egg:1", {}); EggCarry.add(reg, "Egg:2", {})
		assert(EggCarry.steal(reg, "Egg:1", 7, "u1"))
		local ok, reason = EggCarry.steal(reg, "Egg:2", 7, "u2")
		equal(ok, false); equal(reason, "AlreadyCarrying")
		ok, reason = EggCarry.steal(reg, "Egg:1", 8, "u3")
		equal(ok, false); equal(reason, "NotInNest", "a carried egg cannot be taken from the nest again")
		equal(EggCarry.get(reg, "Egg:1").carrier, 7, "the first thief keeps it")
		equal(select(2, EggCarry.steal(reg, "Egg:9", 8)), "NoEgg")
		equal(select(2, EggCarry.steal(reg, "Egg:2", nil)), "InvalidPlayer")
		equal(EggCarry.count(reg, "Carried"), 1); equal(EggCarry.count(reg, "InNest"), 1)
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
		has(spawn, "EggCarry.canSteal(eggs, id, player.UserId)", "one egg per player, checked before the state")
		has(spawn, "Text.EGG.already")
		has(spawn, "arms = true", "the state knows the egg is in the arms")
		has(spawn, "EggCarry.steal(eggs, id, player.UserId, reason)")
		has(spawn, "syncEggArms(player)")
		local arms = block(server, "local function syncEggArms(player)", "\nend\n")
		has(arms, "capsulePart(", "unanchored, massless, no collision, touch or query (the capsule's part)")
		has(arms, 'weld("EggHold", root, shell', "welded in front of the root")
		has(block(server, "local function removeEntry(entry, now)", "\nend\n"), "EggCarry.retire(eggs, entry.id)")
		local part = block(server, "local function capsulePart(", "\nend\n")
		has(part, "part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.Massless = false, false, false, false, true")
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

	-- NH4 the Burst (its numbers are in WildboundStamina_Test).
	case("NH4: the server owns the burst: the word over the stance remote, the rule's cooldown, the speed and the effects", function()
		local stance = block(server, "stanceRemote.OnServerEvent:Connect(function(player, intent, ...)", "\nend)")
		has(stance, 'if intent == "burst" then', "a burst is one known word")
		assert(stance:find("STANCE_RATE", 1, true) < stance:find('intent == "burst"', 1, true), "after the rate limit")
		local fn = block(server, "local function burst(player, record, now)", "\nend\n")
		-- Play finding: the handler first called a burst defined below it (a nil global at run time).
		assert(server:find("local function burst(player, record, now)", 1, true)
			< server:find("stanceRemote.OnServerEvent:Connect", 1, true), "burst is defined before the handler that calls it")
		has(fn, "Stamina.burst(record.stamina, now,", "the rule's cooldown")
		has(fn, "capturing or hidden", "blocked during a capture or hidden")
		has(fn, "applyCarry(player)"); has(fn, "WildboundBurstReady"); has(fn, "emitter:Emit(")
		hasNot(fn, 'Instance.new("Sound")', "the inventory server makes no sounds")
		local audio = sources.audio or ""
		has(audio, 'other:GetAttribute("WildboundBurstReady")', "every client hears a burst")
		has(audio, 'playOnce("dirt", burstRoot', "a catalogued slot, never a new id")
		has(block(server, "local function applyCarry(player)", "\nend\n"), "Stamina.bursting(record.stamina,")
		local _, remotes = server:gsub('Instance.new%("RemoteEvent"%)', "")
		equal(remotes, 5, "no new remote")
	end)

	case("NH4: Z, R3 and the Impulso button ask for a burst; the button counts the cooldown down", function()
		local client = sources.worldClient or ""
		has(client, '"WildboundBurst"'); has(client, "Enum.KeyCode.Z, Enum.KeyCode.ButtonR3")
		has(client, 'stanceRemote:FireServer("burst")'); has(client, "WildboundBurstReady")
		has(client, "staminaWords.burst"); has(client, 'UnbindAction("WildboundBurst")')
		local Keys = sources.keys
		equal(Keys.BURST.key, "Z"); equal(Keys.BURST.pad, "ButtonR3")
		equal(#Keys.conflicts(), 0, table.concat(Keys.conflicts(), "; "))
		equal(sources.text.STAMINA.burst, "Impulso")
	end)

	return result
end

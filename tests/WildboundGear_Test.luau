-- Invoke with require(freshTestClone)(require(freshGearClone), freshGearClone.Source, { server = WildboundServer.Source,
-- world = WildboundWorld.Source, client = WildboundClient.Source, fear = WildboundFearClient.Source,
-- text = require(freshTextClone), config = require(freshConfigClone), spawnClock = require(freshSpawnClockClone),
-- stamina = require(freshStaminaClone), capture = require(freshCaptureClone), fairStrike = require(freshFairStrikeClone),
-- campView = require(freshCampViewClone), economy = require(freshEconomyClone), state = require(freshStateClone),
-- record = require(freshRecordClone), training = require(freshTrainingClone) }).
-- Nest Heist Phase 3 (NS7): gloves with rolled stats, crafted at camp with Esencia and materials and saved, one worn at
-- a time, and the placeable Tótem de la suerte (items and totem, plan Part 4). Gameplay effects are applied by the
-- server; the steal hold is shortened on the owner's client. Numbers live in Gear.CONSTANTS and the dev tuning schema.
return function(Gear, source, sources)
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
	local function near(actual, expected, label, tolerance)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-6),
			(label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function has(text, needle, label)
		assert(type(text) == "string" and text:find(needle, 1, true), (label or "source") .. " lacks " .. needle)
	end
	sources = type(sources) == "table" and sources or {}
	-- Nest Heist Phase 3 (NS7, user decision 2026-11-10): gloves with rolled stats replaced the four IT1 pieces
	-- (deliberately changed: every IT1 case below became an NS7 case). A seeded sequence stands in for the server's Random.
	local function sequence(values)
		local index = 0
		return function()
			index = index % #values + 1
			return values[index]
		end
	end
	local function stocked(state, key)
		state:addPlayer(key)
		local profile = state.players["s:" .. key]
		profile.ember = 999
		profile.banked.fogbark, profile.banked.glowmoss, profile.banked.nightbloom = 999, 999, 99
		return profile
	end
	local function newState()
		return sources.state.new(sources.economy, sources.config)
	end

	case("NS7: five stats with documented caps, four rarities, no ability stat", function()
		equal(table.concat(Gear.STATS, ","), "move,steal,burst,drain,calm")
		equal(table.concat(Gear.RARITIES, ","), "Comun,Rara,Epica,Legendaria")
		local C = Gear.CONSTANTS
		equal(C.MOVE_CAP, 3); equal(C.STEAL_CAP, 15); equal(C.BURST_CAP, 20); equal(C.DRAIN_CAP, 30); equal(C.CALM_CAP, 30)
		for stat, hard in pairs(Gear.HARD_CAPS) do
			assert(Gear.cap(stat) <= hard, stat .. " under its hard cap")
			equal(sources.record.GLOVE_CAPS[stat], hard, "the record validates the same cap for " .. stat)
		end
		for _, banned in ipairs({ "stamina", "luck", "stealth", "immunity", "keepEgg", "reach", "stun", "fear" }) do
			equal(Gear.HARD_CAPS[banned], nil, "no " .. banned .. " stat")
		end
		equal(Gear.RARITY.Comun.stats, 1); equal(Gear.RARITY.Rara.stats, 2)
		equal(Gear.RARITY.Epica.stats, 3); equal(Gear.RARITY.Legendaria.stats, 4)
	end)

	case("NS7: a roll picks distinct stats inside the rarity's share of each cap", function()
		for _, rarity in ipairs(Gear.RARITIES) do
			for seed = 1, 20 do
				local random = sequence({ (seed * 0.137) % 1, (seed * 0.61) % 1, (seed * 0.29) % 1, 0.999, 0, 0.5 })
				local glove = Gear.roll(random, rarity)
				equal(glove.rarity, rarity)
				local count = 0
				for stat, value in pairs(glove.stats) do
					count += 1
					local spec, cap = Gear.RARITY[rarity], Gear.cap(stat)
					assert(value >= math.max(0.1, cap * spec.low - 0.05) and value <= cap * spec.high + 0.05,
						rarity .. " " .. stat .. " " .. value)
				end
				equal(count, Gear.RARITY[rarity].stats, rarity .. " stat count")
				equal(Gear.valid(glove), true, "a rolled glove is valid")
			end
		end
		equal(Gear.rollRarity(function() return 0 end), "Comun")
		equal(Gear.rollRarity(function() return 0.999 end), "Legendaria")
		equal(Gear.rollRarity(function() return 0.7 end), "Rara", "60 Común, then 28 Rara")
		equal(Gear.valid({ rarity = "Mitica", stats = { move = 1 } }), false)
		equal(Gear.valid({ rarity = "Rara", stats = { stealth = 5 } }), false, "no ability stats")
		equal(Gear.valid({ rarity = "Rara", stats = { move = 9 } }), false, "over its hard cap")
	end)

	case("NS7: effects come from the worn glove only and stay under every cap, even when tuned", function()
		local glove = { rarity = "Legendaria", stats = { move = 3, steal = 15, burst = 20, drain = 30, calm = 30 } }
		near(Gear.calmRate(glove), 1.3); near(Gear.drainScale(glove), 0.7); near(Gear.burstScale(glove), 0.8)
		near(Gear.stealScale(glove), 0.85); near(Gear.moveBonus(glove, 16), 0.48)
		equal(Gear.calmRate(nil), 1); equal(Gear.drainScale(nil), 1); equal(Gear.moveBonus(nil, 16), 0)
		Gear.tune({ MOVE_CAP = 50, CALM_CAP = 10 })
		near(Gear.moveBonus({ stats = { move = 3 } }, 16), 0.48, "the hard cap holds against a tuned cap")
		near(Gear.calmRate(glove), 1.1, "a lower tuned cap lowers the effect of an old glove")
		Gear.tune(nil)
		near(Gear.stealHold(0.8, glove, 0.6), 0.68); near(Gear.stealHold(0.7, glove, 0.65), 0.65, "never under the floor")
		local Training, Stamina = sources.training, sources.stamina
		local walk = Training.walkSpeed(16, 16, { walk = 4 }, Gear.moveBonus(glove, 16))
		assert(walk <= Training.CONSTANTS.WALK_CAP, "training and glove stay under the walk cap: " .. walk)
		assert(Stamina.speed(walk, "sprint") <= Stamina.CONSTANTS.SPEED_CAP, "the sprint stays capped")
		assert(Stamina.speed(walk, "walk", true) <= Stamina.CONSTANTS.BURST_CAP, "the Burst stays capped")
		local state = {}
		Stamina.burst(state, 100, { cooldownScale = Gear.burstScale(glove) })
		near(state.burstReadyAt, 100 + Stamina.CONSTANTS.BURST_COOLDOWN * 0.8, "Burst recovery shortens the cooldown")
		Stamina.burst(state, 200, { cooldownScale = 0.1 })
		near(state.burstReadyAt, 200 + Stamina.CONSTANTS.BURST_COOLDOWN * 0.5, "never below half")
	end)

	case("NS7: the recipe costs Esencia and materials, no Robux; the old pieces are gone", function()
		local config = sources.config
		local spec = config.gear.guantes
		equal(spec.kind, "gloves"); equal(spec.cap, Gear.CONSTANTS.GLOVE_LIMIT)
		assert((spec.cost.ember or 0) > 0 and (spec.cost.fogbark or 0) + (spec.cost.glowmoss or 0) > 0, "Esencia and materials")
		for _, gone in ipairs({ "botas", "chaleco", "amuleto" }) do equal(config.gear[gone], nil, gone .. " removed") end
		for _, word in ipairs({ "MarketplaceService", "Robux", "game:", "workspace", "os.", "task." }) do
			equal(source:find(word, 1, true), nil, "the rule mentions " .. word)
		end
	end)

	case("NS7: crafted at camp with the server's roll, the first worn at once, one worn at a time, capped", function()
		local state = newState()
		local profile = stocked(state, "Ana")
		local before = profile.ember
		local roll = { rarity = "Rara", stats = { move = 1.5, calm = 12 } }
		local farOk, farWhy = state:craftGear("Ana", "guantes", true, 999, roll)
		equal(farOk, false); equal(farWhy, "NotAtCamp")
		equal((state:craftGear("Ana", "guantes", true, 5, { rarity = "Rara" })), false, "a roll without stats is refused")
		local ok, glove = state:craftGear("Ana", "guantes", true, 5, roll)
		equal(ok, true); equal(glove.rarity, "Rara"); equal(glove.stats.calm, 12)
		equal(profile.ember, before - sources.config.gear.guantes.cost.ember, "paid once")
		local snapshot = state:snapshot("Ana")
		equal(#snapshot.gloves, 1); equal(snapshot.equippedGlove, glove.uid, "the first glove is worn")
		equal(snapshot.glove.stats.move, 1.5)
		local _, second = state:craftGear("Ana", "guantes", true, 5, { rarity = "Comun", stats = { drain = 9 } })
		equal(state:snapshot("Ana").equippedGlove, glove.uid, "a second glove is not put on by itself")
		equal((state:equipGlove("Ana", second.uid, true)), true)
		equal(state:snapshot("Ana").glove.stats.drain, 9, "one glove at a time")
		equal((state:equipGlove("Ana", "wb:999", true)), false, "only an owned glove")
		equal((state:equipGlove("Ana", second.uid, false)), false, "alive only")
		for _ = 3, Gear.CONSTANTS.GLOVE_LIMIT do state:craftGear("Ana", "guantes", true, 5, roll) end
		local full, why = state:craftGear("Ana", "guantes", true, 5, roll)
		equal(full, false); equal(why, "GlovesFull")
		equal(#state:snapshot("Ana").gloves, Gear.CONSTANTS.GLOVE_LIMIT)
		local poor = newState()
		poor:addPlayer("Bo")
		local cannot, reason = poor:craftGear("Bo", "guantes", true, 5, roll)
		equal(cannot, false); equal(reason, "CannotAfford")
	end)

	case("NS7: the camp lists the craft row and every glove in Spanish, with each stat as a percent", function()
		local View, config, economy, text = sources.campView, sources.config, sources.economy, sources.text
		local snapshot = { ember = 999, banked = { fogbark = 999, glowmoss = 999 }, equippedGlove = "u1",
			gloves = { { uid = "u1", rarity = "Rara", stats = { move = 1.5, calm = 12 } },
				{ uid = "u2", rarity = "Legendaria", stats = { move = 3, steal = 15, burst = 20, drain = 30 } } } }
		local rows = View.campRows(config, economy, snapshot, { atCamp = true })
		local byId = {}
		for _, row in ipairs(rows) do byId[row.id] = row end
		local craft = byId["gear:guantes"]
		equal(craft.action, "CraftGear"); equal(craft.argument, "guantes"); equal(craft.enabled, true)
		has(byId["glove:u1"].text, "Guantes raros: +1,5% Velocidad, +12,0% Calma (puestos)")
		equal(byId["glove:u1"].action, nil, "the worn glove has no button")
		local other = byId["glove:u2"]
		equal(other.action, "EquipGlove"); equal(other.argument, "u2"); equal(other.label, "Ponerte")
		has(other.text, "Guantes legendarios: +3,0% Velocidad, +15,0% Robo rápido")
		assert(#other.text <= 140, "a glove row fits the camp row budget: " .. #other.text)
		for _, entry in ipairs(View.GLOVE_STATS) do equal(text.GEAR.stats[entry.id], entry.word, entry.id) end
		for rarity, word in pairs(View.GLOVE_RARITY) do equal(text.GEAR.rarity[rarity], word, rarity) end
		equal(table.concat(Gear.describe({ stats = { move = 4.66, calm = 12 } }, text), " | "),
			"+4,7% Velocidad | +12,0% Calma")
		equal(text.HUD.sections.Gear, "Equipo", "a Spanish section title")
	end)

	case("NS7 wiring: the server rolls, saves and applies the worn glove; the Chaleco and the Amuleto are gone", function()
		local server, world, fear, client = sources.server, sources.world, sources.fear, sources.client
		has(server, 'require(ReplicatedStorage:WaitForChild("WildboundGear"))', "server")
		has(server, "Gear.roll(function() return rng:NextNumber() end)", "the server rolls, never the client")
		has(server, "state:craftGear(key, argument, alive, distance, roll)", "server")
		has(server, "state:equipGlove(key, argument, context(player))", "server")
		has(server, "EquipGlove = true", "server economy actions")
		has(server, "calmRate = Gear.calmRate(snapshot.glove), ringBonus = 0", "capture calm")
		has(server, "drainScale = Gear.drainScale(snapshot and snapshot.glove)", "sprint drain")
		has(server, "cooldownScale = Gear.burstScale(glove)", "Burst recovery")
		has(server, "Gear.moveBonus(snapshot.glove, EconomyConfig.carry.baseSpeed)", "walk speed through the training cap")
		has(server, 'entry.prompt:SetAttribute("WildboundStealHold", entry.prompt.HoldDuration)', "steal hold base")
		has(server, 'player:SetAttribute("WildboundGloveSteal", steal)', "steal bonus for the owner's client")
		has(client, "Gear.stealHold(base, glove, Gear.CONSTANTS.STEAL_FLOOR)", "the client shortens only its own hold")
		has(client, "EquipGlove = true", "the client waits for the server's reply")
		for _, gone in ipairs({ "useVest", '"GearUsed"', '"GearChanged"', "Gear.ITEMS", "snapshot.gear" }) do
			assert(not server:find(gone, 1, true), "server still names " .. gone)
		end
		assert(not world:find("WildboundGear", 1, true), "the world server no longer reads gear")
		assert(not world:find("FairStrike.absorb(", 1, true), "no kept hit")
		assert(not fear:find("Gear.", 1, true), "the fear client no longer softens by gear")
		has(fear, "Efectos suaves", "the free setting owns the fear relief")
		assert(not server:find("MarketplaceService", 1, true), "no purchase path")
	end)

	-- IT2: the Tótem de la suerte. Crafted at camp (one held at a time), placed away from camp for LUCK_SECONDS; the next
	-- random spawn inside LUCK_RADIUS rolls one tier up (the spawn clock prefers a free point there, and with LUCK_LURE
	-- the totem draws one spawn in at once). It makes ring-level noise, so La Silueta can hear it.
	case("IT2: the luck totem's defaults and recipe", function()
		local C = Gear.CONSTANTS
		equal(Gear.LUCK, "totemSuerte")
		equal(C.LUCK_SECONDS, 60); equal(C.LUCK_RADIUS, 40); equal(C.LUCK_NOISE_EVERY, 10); equal(C.LUCK_LURE, 1)
		equal(C.LUCK_CAMP, 30, "placed at least this far from the camp centre")
		local spec = sources.config.gear.totemSuerte
		assert(type(spec) == "table", "recipe totemSuerte")
		equal(spec.kind, "luckTotem"); equal(spec.cap, 1)
		assert((spec.cost.ember or 0) > 0, "costs Esencia")
		equal(sources.config.recipes.totem ~= nil, true, "the older ward totem stays")
	end)

	case("IT2: crafted at camp up to one held, placed once, session only", function()
		local state = newState()
		stocked(state, "Ana")
		equal(state:snapshot("Ana").luckTotems, 0)
		local ok, id = state:craftGear("Ana", "totemSuerte", true, 5)
		equal(ok, true); equal(id, "totemSuerte")
		equal(state:snapshot("Ana").luckTotems, 1)
		local again, reason = state:craftGear("Ana", "totemSuerte", true, 5)
		equal(again, false); equal(reason, "AtLimit")
		local dead, deadReason = state:placeLuckTotem("Ana", false)
		equal(dead, false); equal(deadReason, "InvalidContext")
		equal(state:placeLuckTotem("Ana", true), true)
		equal(state:snapshot("Ana").luckTotems, 0)
		local none, noneReason = state:placeLuckTotem("Ana", true)
		equal(none, false); equal(noneReason, "NoLuckTotem")
		equal(state:snapshot("Ana").consumables.totemSuerte, nil, "not a saved consumable")
	end)

	local function luckClock(points)
		local SpawnClock = sources.spawnClock
		SpawnClock.tune({ MAX_COMUN = 1, MAX_RARA = 0, MAX_EPICA = 0, MAX_LEGENDARIA = 1, RESPAWN_COMUN = 0,
			RESPAWN_LEGENDARIA = 0 })
		return SpawnClock, SpawnClock.new({ points = points }, nil)
	end
	local ZERO = { NextNumber = function() return 0 end }
	local function spawnsOf(actions)
		local list = {}
		for _, action in ipairs(actions) do
			if action.op == "spawn" then table.insert(list, action.spawn) end
		end
		return list
	end

	case("IT2: the next spawn inside the radius rolls one tier up, once, and keeps its pool's count", function()
		local SpawnClock, clock = luckClock({
			{ id = "FAR", x = 300, z = 0, tier = "Comun", kind = "trail" },
			{ id = "NEAR", x = 10, z = 0, tier = "Comun", kind = "trail" },
		})
		local ok, message = pcall(function()
			SpawnClock.addLuck(clock, { id = "L1", x = 0, z = 0, radius = 40, untilAt = 60 })
			local first = spawnsOf(SpawnClock.step(clock, 1, ZERO))
			equal(#first, 1, "one spawn: the raised one still counts as a Comun slot")
			equal(first[1].point.id, "NEAR", "the clock prefers a free point inside the radius")
			equal(first[1].tier, "Rara"); equal(first[1].pool, "Comun"); equal(first[1].luck, "L1")
			equal(first[1].rewardTier, SpawnClock.REWARD.Rara)
			SpawnClock.claim(clock, first[1].id, 2)
			local second = spawnsOf(SpawnClock.step(clock, 3, ZERO))
			equal(#second, 1)
			equal(second[1].tier, "Comun", "the totem works once")
			equal(second[1].luck, nil)
		end)
		SpawnClock.tune(nil)
		assert(ok, message)
	end)

	case("IT2: an expired totem raises nothing; a Legendaria point cannot go higher and keeps the totem", function()
		local SpawnClock, clock = luckClock({ { id = "HEART", x = 0, z = 0, tier = "Legendaria", kind = "rock" } })
		local ok, message = pcall(function()
			SpawnClock.addLuck(clock, { id = "L1", x = 0, z = 0, radius = 40, untilAt = 60 })
			local first = spawnsOf(SpawnClock.step(clock, 1, ZERO))
			equal(first[1].tier, "Legendaria"); equal(first[1].luck, nil)
			equal(SpawnClock.luckActive(clock, "L1", 1), true, "still waiting for a spawn it can raise")
			equal(SpawnClock.luckActive(clock, "L1", 61), false, "gone after its time")
			local _, late = luckClock({ { id = "NEAR", x = 5, z = 0, tier = "Comun", kind = "trail" } })
			SpawnClock.addLuck(late, { id = "L2", x = 0, z = 0, radius = 40, untilAt = 5 })
			local raised = spawnsOf(SpawnClock.step(late, 10, ZERO))
			equal(raised[1].tier, "Comun", "an expired totem raises nothing")
		end)
		SpawnClock.tune(nil)
		assert(ok, message)
	end)

	case("IT2: with the lure the totem draws one spawn into its radius at once, one tier up", function()
		local SpawnClock, clock = luckClock({
			{ id = "FAR", x = 300, z = 0, tier = "Comun", kind = "trail" },
			{ id = "NEAR", x = 10, z = 0, tier = "Comun", kind = "trail" },
		})
		local ok, message = pcall(function()
			local placed = spawnsOf(SpawnClock.step(clock, 0, ZERO))
			equal(placed[1].point.id, "FAR")
			SpawnClock.addLuck(clock, { id = "L1", x = 0, z = 0, radius = 40, untilAt = 60 })
			local actions = SpawnClock.lure(clock, 1, ZERO, "L1", {})
			equal(#actions, 2, "the far spawn leaves, a raised one appears inside")
			equal(actions[1].op, "expire"); equal(actions[1].reason, "Lure"); equal(actions[1].spawn.point.id, "FAR")
			equal(actions[2].op, "spawn"); equal(actions[2].spawn.point.id, "NEAR"); equal(actions[2].spawn.tier, "Rara")
			equal(SpawnClock.luckActive(clock, "L1", 1), false, "used")
			equal(#SpawnClock.lure(clock, 2, ZERO, "L1", {}), 0, "a used totem draws nothing")
			-- A spawn someone is capturing never moves.
			local _, heldClock = luckClock({
				{ id = "FAR", x = 300, z = 0, tier = "Comun", kind = "trail" },
				{ id = "NEAR", x = 10, z = 0, tier = "Comun", kind = "trail" },
			})
			local held = spawnsOf(SpawnClock.step(heldClock, 0, ZERO))[1]
			SpawnClock.addLuck(heldClock, { id = "L2", x = 0, z = 0, radius = 40, untilAt = 60 })
			equal(#SpawnClock.lure(heldClock, 1, ZERO, "L2", { [held.id] = true }), 0, "held spawns stay")
		end)
		SpawnClock.tune(nil)
		assert(ok, message)
	end)

	case("IT2: the camp lists the totem's craft and a place row usable only away from camp", function()
		local View, config, economy = sources.campView, sources.config, sources.economy
		local function byId(snapshot, ctx)
			local map = {}
			for _, row in ipairs(View.campRows(config, economy, snapshot, ctx)) do map[row.id] = row end
			return map
		end
		local rows = byId({ ember = 999, banked = { fogbark = 999, glowmoss = 999, nightbloom = 99 }, luckTotems = 0 },
			{ atCamp = true })
		local craft = rows["gear:totemSuerte"]
		assert(craft, "craft row"); equal(craft.action, "CraftGear"); equal(craft.argument, "totemSuerte")
		has(craft.text, sources.text.GEAR.totemSuerte)
		equal(rows["luck:place"], nil, "nothing to place")
		local held = byId({ ember = 0, banked = {}, luckTotems = 1 }, { atCamp = true })
		equal(held["gear:totemSuerte"].enabled, false, "one held at most")
		equal(held["luck:place"].action, "PlaceLuck"); equal(held["luck:place"].enabled, false, "not at camp")
		has(held["luck:place"].why, "Sal del campamento")
		local away = byId({ ember = 0, banked = {}, luckTotems = 1 }, { atCamp = false })
		equal(away["luck:place"].enabled, true); equal(away["luck:place"].label, "Poner")
	end)

	case("IT2 wiring: the server places the totem, raises a spawn, makes noise and tells the owner", function()
		local server, text = sources.server, sources.text
		has(server, "PlaceLuck = true", "server economy actions")
		has(server, "state:placeLuckTotem(", "server")
		has(server, "SpawnClock.addLuck(", "server")
		has(server, "SpawnClock.lure(", "server")
		has(server, 'noiseEvent:Fire("ring", "Fog", zone.x, zone.z)', "the totem is heard like a capture ring")
		has(server, "Gear.live.LUCK_SECONDS", "server")
		has(server, "spawn.luck", "the owner hears which spawn was raised")
		has(server, "now >= zone.untilAt", "the totem stands (and is heard) its full time, raised or not")
		has(sources.client, "PlaceLuck = true", "the client waits for the server's reply")
		for _, key in ipairs({ "totemSuerte", "luckPlaced", "luckRaised", "luckGone" }) do
			equal(type(text.GEAR[key]), "string", "Text.GEAR." .. key)
		end
		for _, key in ipairs({ "NoLuckTotem", "NearCamp", "LuckActive" }) do
			equal(type(text.NOTICES[key]), "string", "Text.NOTICES." .. key)
		end
	end)

	case("IT3: the Play-check probe is Studio only and grants only on probe ops", function()
		local server = sources.server
		local studio = server:find("if RunService:IsStudio() then", 1, true)
		local probe = server:find('gearProbe.Name = "GearProbe"', 1, true)
		assert(studio and probe and studio < probe, "the GearProbe is built inside the Studio-only block")
		has(server, "gearProbe.Parent = telemetry", "it lives in ServerStorage, out of every client's reach")
	end)

	return result
end

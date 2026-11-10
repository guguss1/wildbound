-- Invoke with require(freshTestClone)(require(freshGearClone), freshGearClone.Source, { server = WildboundServer.Source,
-- world = WildboundWorld.Source, client = WildboundClient.Source, fear = WildboundFearClient.Source,
-- text = require(freshTextClone), config = require(freshConfigClone), spawnClock = require(freshSpawnClockClone),
-- stamina = require(freshStaminaClone), capture = require(freshCaptureClone), fairStrike = require(freshFairStrikeClone),
-- campView = require(freshCampViewClone), economy = require(freshEconomyClone), state = require(freshStateClone) }).
-- Items and totem (plan Part 4): four pieces of equipment crafted at camp with Esencia and materials, one of each and
-- session only (Guantes de captura, Botas, Chaleco, Amuleto), and the placeable Tótem de la suerte. Gameplay effects
-- are applied by the server (calm meter, ring, sprint drain, the vest's saved hit, La Silueta's memory); the fear
-- softening is presentation on the owner's client. Numbers live in Gear.CONSTANTS and the dev tuning schema.
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
	local ALL = { guantes = true, botas = true, chaleco = true, amuleto = true }

	case("IT1: four items in a fixed order, each with its defaults", function()
		equal(type(Gear.ITEMS), "table", "Gear.ITEMS")
		equal(table.concat(Gear.ITEMS, ","), "guantes,botas,chaleco,amuleto")
		local C = Gear.CONSTANTS
		equal(C.GLOVES_CALM, 1.3, "gloves: calm meter +30%")
		equal(C.GLOVES_RING, 0.4, "gloves: ring tolerance in studs")
		equal(C.BOOTS_DRAIN, 0.7, "boots: sprint drain -30%")
		equal(C.AMULET_MEMORY, 1, "amulet: La Silueta's memory -1 s")
		equal(C.AMULET_FEAR, 0.6, "amulet: heartbeat and fear x0.6 (client)")
		equal(Gear.attribute("chaleco"), "WildboundGear_chaleco")
		equal(Gear.attribute("capa"), nil, "an unknown item has no attribute")
	end)

	case("IT1: each effect needs its own item, and nothing else changes", function()
		equal(Gear.calmRate({ guantes = true }), 1.3); equal(Gear.calmRate({}), 1); equal(Gear.calmRate(nil), 1)
		equal(Gear.ringBonus({ guantes = true }), 0.4); equal(Gear.ringBonus({ botas = true }), 0)
		equal(Gear.drainScale({ botas = true }), 0.7); equal(Gear.drainScale({ guantes = true }), 1)
		equal(Gear.memory(4, { amuleto = true }), 3); equal(Gear.memory(4, ALL), 3); equal(Gear.memory(4, {}), 4)
		equal(Gear.memory(1, { amuleto = true }), 0.5, "memory never goes under half a second")
		local f = { heart = 1, red = 0.8, shake = 0.5, dark = 0.5, flash = 0.4, fov = 6 }
		local soft = Gear.softenFear(f, { amuleto = true })
		near(soft.heart, 0.6); near(soft.red, 0.48); near(soft.shake, 0.3); near(soft.dark, 0.3)
		equal(soft.flash, 0.4, "a hit's flash stays (it is information)"); equal(soft.fov, 6)
		equal(f.heart, 1, "the input is not changed")
		equal(Gear.softenFear(f, {}).heart, 1)
	end)

	case("IT1: tuning overrides the live values; no override, no change", function()
		local defaults = Gear.tunable()
		equal(defaults.BOOTS_DRAIN, 0.7)
		Gear.tune({ BOOTS_DRAIN = 0.5, GLOVES_CALM = 2 })
		equal(Gear.drainScale({ botas = true }), 0.5); equal(Gear.calmRate({ guantes = true }), 2)
		Gear.tune(nil)
		equal(Gear.drainScale({ botas = true }), 0.7); equal(Gear.calmRate({ guantes = true }), 1.3)
	end)

	case("IT1: the recipes cost Esencia and materials, in the economy config", function()
		local config = sources.config
		assert(type(config) == "table" and type(config.gear) == "table", "config.gear")
		for _, id in ipairs(Gear.ITEMS) do
			local spec = config.gear[id]
			assert(type(spec) == "table" and type(spec.cost) == "table", "recipe " .. id)
			assert((spec.cost.ember or 0) > 0, id .. " costs Esencia")
			assert((spec.cost.fogbark or 0) + (spec.cost.glowmoss or 0) + (spec.cost.nightbloom or 0) > 0, id .. " costs materials")
			equal(spec.kind, "equipment", id .. " kind")
		end
	end)

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

	case("IT1: crafted at camp, one of each, paid once, session only", function()
		local state = newState()
		local profile = stocked(state, "Ana")
		local before = profile.ember
		local ok, id = state:craftGear("Ana", "guantes", true, 5)
		equal(ok, true, "craft"); equal(id, "guantes")
		equal(profile.ember, before - sources.config.gear.guantes.cost.ember, "paid once")
		local again, reason = state:craftGear("Ana", "guantes", true, 5)
		equal(again, false); equal(reason, "AlreadyOwned")
		equal(profile.ember, before - sources.config.gear.guantes.cost.ember, "a refusal pays nothing")
		local far, farReason = state:craftGear("Ana", "botas", true, 25)
		equal(far, false); equal(farReason, "NotAtCamp")
		local bad, badReason = state:craftGear("Ana", "capa", true, 5)
		equal(bad, false); equal(badReason, "UnknownGear")
		state:addPlayer("Bea")
		local poor, poorReason = state:craftGear("Bea", "botas", true, 5)
		equal(poor, false); equal(poorReason, "CannotAfford")
		local snapshot = state:snapshot("Ana")
		equal(snapshot.gear.guantes, true); equal(snapshot.gear.botas, nil)
		equal(snapshot.sessionOnly, true)
		equal(snapshot.consumables.guantes, nil, "gear is not a saved consumable")
	end)

	case("IT1: the vest saves one hit per expedition", function()
		local state = newState()
		stocked(state, "Ana")
		equal(state:snapshot("Ana").vestReady, false, "no vest, never ready")
		assert(state:craftGear("Ana", "chaleco", true, 5))
		equal(state:snapshot("Ana").vestReady, true)
		state:observeExpedition("Ana", 80, true, 10)
		equal(state:useVest("Ana"), true, "first saved hit")
		equal(state:snapshot("Ana").vestReady, false)
		local again, reason = state:useVest("Ana")
		equal(again, false); equal(reason, "VestUsed")
		state.players["s:Ana"].carried.fogbark = 1
		assert(state:extract("Ana", true, 0), "extract closes the expedition")
		equal(state:snapshot("Ana").vestReady, true, "back at camp the expedition is over")
		state:observeExpedition("Ana", 80, true, 50)
		equal(state:snapshot("Ana").vestReady, true, "a new expedition, a new save")
		state:addPlayer("Bea")
		local none, noneReason = state:useVest("Bea")
		equal(none, false); equal(noneReason, "NoVest")
	end)

	case("IT1: boots drain the sprint 30% slower (server stamina)", function()
		local Stamina = sources.stamina
		local function after(scale)
			local s = Stamina.new(0)
			local now = 0
			for _ = 1, 10 do
				now += 0.1
				Stamina.intent(s, "sprint", now)
				Stamina.step(s, 0.1, { speed = 16, drainScale = scale }, now)
			end
			return s.stamina
		end
		near(after(nil), 75, "no boots", 1e-3)
		near(after(0.7), 82.5, "boots", 1e-3)
		near(after(-3), 75, "a bad scale is ignored", 1e-3)
		near(after(5), 75, "a scale never makes the sprint cost more", 1e-3)
	end)

	case("IT1: gloves fill the calm meter faster, never under the floor, and widen the ring under the orbit", function()
		local CaptureSession = sources.capture
		local C = CaptureSession.CONSTANTS
		local function begin(extra)
			local capture = CaptureSession.new()
			local entry = { playerKey = 1, encounterId = "wb:1", dir = 1, lumipolX = 0, lumipolZ = 0, now = 0, alive = true,
				life = "L", distance = 7, x = 7, y = 3, z = 0, encounterStatus = "Open", bagRoom = true, collectionRoom = true }
			for key, value in pairs(extra or {}) do entry[key] = value end
			local ok, view = capture:begin(entry)
			assert(ok, "begin " .. tostring(view))
			return view, capture
		end
		equal(begin().required, C.CALM_REQUIRED, "no gloves")
		near(begin({ calmRate = 1.1 }).required, C.CALM_REQUIRED / 1.1, "faster meter")
		near(begin({ calmRate = 1.3 }).required, math.max(C.CALM_MIN, C.CALM_REQUIRED / 1.3), "gloves, floored")
		equal(begin({ calmRate = 9 }).required, C.CALM_MIN, "never under CALM_MIN (standing still must not fill it)")
		equal(begin({ calmRate = 0.2 }).required, C.CALM_REQUIRED, "never slower")
		equal(begin().ringRadius, C.RING_RADIUS_SERVER)
		near(begin({ ringBonus = 0.4 }).ringRadius, C.RING_RADIUS_SERVER + 0.4)
		assert(begin({ ringBonus = 9 }).ringRadius < C.ORBIT_MIN, "the ring stays smaller than its orbit")
		equal(begin({ ringBonus = -2 }).ringRadius, C.RING_RADIUS_SERVER, "never narrower")
		-- A spot 0.2 studs outside the plain ring counts as inside with the gloves.
		local function insideAt(extra)
			local view, capture = begin(extra)
			local cx, cz = CaptureSession.ringCenter(view.ring, 0.2)
			local out = capture:sample(view.token, { now = 0.2, alive = true, life = "L", x = cx + C.RING_RADIUS_SERVER + 0.2,
				y = 3, z = cz, bagRoom = true, collectionRoom = true })
			return out and out.inside
		end
		equal(insideAt(nil), false, "plain ring")
		equal(insideAt({ ringBonus = 0.4 }), true, "gloves")
	end)

	case("IT1: the vest turns a defeating second mark into a kept mark (fair strike)", function()
		local FairStrike = sources.fairStrike
		local ledger = FairStrike.new()
		local record = FairStrike.lifeRecord(ledger, 7, "life")
		record.marks = 1
		equal(FairStrike.absorb(ledger, 7, "life"), false, "a first mark is not a defeat")
		record.marks = 2
		equal(FairStrike.absorb(ledger, 7, "other life"), false, "another life")
		equal(FairStrike.absorb(ledger, 7, "life"), true)
		equal(record.marks, 1, "still marked: the next hit defeats")
		local words = sources.text.STRIKE
		local full, short = FairStrike.strikeNotice("Vest", nil, words)
		equal(full, words.vest); equal(short, words.vestShort)
		assert(type(words.vest) == "string" and words.vest:find("chaleco", 1, true), "Spanish vest notice")
	end)

	case("IT1: the camp lists the four items with Spanish names, price and owned state", function()
		local View, config, economy = sources.campView, sources.config, sources.economy
		local snapshot = { ember = 0, banked = {}, gear = { guantes = true } }
		local rows = View.campRows(config, economy, snapshot, { atCamp = true })
		local byId = {}
		for _, row in ipairs(rows) do byId[row.id] = row end
		local names = sources.text.GEAR
		for _, id in ipairs(Gear.ITEMS) do
			local row = byId["gear:" .. id]
			assert(row, "row " .. id)
			equal(row.section, "Gear", id .. " section")
			has(row.text, names[id], id .. " name")
		end
		equal(byId["gear:guantes"].action, nil, "owned: no button")
		has(byId["gear:guantes"].text, "equipad")
		local boots = byId["gear:botas"]
		equal(boots.action, "CraftGear"); equal(boots.argument, "botas"); equal(boots.label, "Fabricar")
		equal(boots.enabled, false, "cannot afford"); has(boots.why, "Faltan")
		local rich = View.campRows(config, economy, { ember = 999, banked = { fogbark = 999, glowmoss = 999, nightbloom = 99 } },
			{ atCamp = true })
		for _, row in ipairs(rich) do
			if row.id == "gear:chaleco" then equal(row.enabled, true, "affordable at camp") end
		end
		equal(sources.text.HUD.sections.Gear, "Equipo", "a Spanish section title")
	end)

	case("IT1 wiring: the server crafts gear, publishes ownership and applies the gameplay effects", function()
		local server = sources.server
		has(server, 'require(ReplicatedStorage:WaitForChild("WildboundGear"))', "server")
		has(server, "CraftGear = true", "server economy actions")
		has(server, "state:craftGear(", "server")
		has(server, "Gear.attribute(", "server publishes ownership to the owner's client")
		has(server, '"GearChanged"', "server tells the world script the owned gear and the vest's charge")
		has(server, "gearChanged:Fire(player,", "server")
		has(server, "drainScale = Gear.drainScale(", "server stamina")
		has(server, "calmRate = Gear.calmRate(", "server capture")
		has(server, "ringBonus = Gear.ringBonus(", "server capture")
		has(server, '"GearUsed"', "the world script reports a spent vest")
		has(server, "state:useVest(", "server")
		has(sources.client, "CraftGear = true", "the client waits for the server's reply")
	end)

	case("IT1 wiring: the world server reads the amulet and the vest; the owner's client softens fear", function()
		local world = sources.world
		has(world, 'require(ReplicatedStorage:WaitForChild("WildboundGear"))', "world")
		has(world, "Gear.memory(", "world memory")
		has(world, "FairStrike.absorb(", "world vest")
		has(world, 'network:FindFirstChild("GearChanged")', "world gear comes from the inventory script")
		assert(not world:find(":GetAttribute(", 1, true), "the world script never reads an attribute back")
		has(world, '"Vest"', "world vest outcome")
		has(sources.fear, "Gear.softenFear(", "fear client")
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
		has(sources.client, "PlaceLuck = true", "the client waits for the server's reply")
		for _, key in ipairs({ "totemSuerte", "luckPlaced", "luckRaised", "luckGone" }) do
			equal(type(text.GEAR[key]), "string", "Text.GEAR." .. key)
		end
		for _, key in ipairs({ "NoLuckTotem", "NearCamp", "LuckActive" }) do
			equal(type(text.NOTICES[key]), "string", "Text.NOTICES." .. key)
		end
	end)

	return result
end

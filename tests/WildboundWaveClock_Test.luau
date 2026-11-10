-- Invoke with require(freshTestClone)(require(freshWaveClockClone), freshWaveClockClone.Source,
-- { server = WildboundServer.Source, client = WildboundClient.Source, text = require(freshTextClone),
-- rules = require(freshRulesClone), stamina = require(freshStaminaClone), world = WildboundWorld.Source,
-- worldClient = WildboundWorldClient.Source, atmosphere = require(freshAtmosphereClone) }).
-- Random world (plan Parts 3 and 6, RW3 to RW6): the server's wave clock, the wave board, the WorldEvent messages, the
-- random Refugios, the biome event and the biome variant rotation. Pure rules plus source contracts for the wiring.
return function(WaveClock, source, sources)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got "
			.. tostring(actual))
	end
	local function has(text, needle, label)
		assert(type(text) == "string" and text:find(needle, 1, true), (label or "missing") .. ": " .. needle)
	end
	sources = type(sources) == "table" and sources or {}
	local function types(events)
		local list = {}
		for _, event in ipairs(events) do table.insert(list, event.type) end
		return table.concat(list, ",")
	end

	case("RW3: the defaults, the live copy and the tuning hook", function()
		assert(type(WaveClock) == "table" and type(WaveClock.CONSTANTS) == "table", "module missing")
		assert(table.isfrozen(WaveClock.CONSTANTS), "the defaults are frozen")
		equal(WaveClock.CONSTANTS.WAVE_SECONDS, 300)
		equal(WaveClock.REMOTE, "WorldEvent")
		equal(WaveClock.tunable().WAVE_SECONDS, 300)
		WaveClock.tune({ WAVE_SECONDS = 2 })
		equal(WaveClock.live.WAVE_SECONDS, 300, "a wave never drops under 10 s")
		WaveClock.tune({ WAVE_SECONDS = 30 })
		equal(WaveClock.live.WAVE_SECONDS, 30)
		WaveClock.tune(nil)
		equal(WaveClock.live.WAVE_SECONDS, 300)
	end)

	case("RW3: the first wave starts when the server opens, then one every WAVE_SECONDS", function()
		local clock = WaveClock.new(1000)
		local first = WaveClock.step(clock, 1000)
		equal(types(first), "waveStarted")
		equal(first[1].wave, 1); equal(first[1].endsAt, 1300)
		equal(types(WaveClock.step(clock, 1299.9)), "")
		local second = WaveClock.step(clock, 1300)
		equal(second[1].wave, 2)
		equal(WaveClock.endsAt(clock), 1600)
		-- RW5 deliberately changed this count: the biome event's own events share the step, so only waves count here.
		local late = {}
		for _, event in ipairs(WaveClock.step(clock, 2500)) do
			if event.type == "waveStarted" then table.insert(late, event) end
		end
		equal(#late, 1, "a long gap starts one wave, not a backlog")
		equal(late[1].wave, 3)
	end)

	case("RW3: the wave board counts banked Esencia, shows the top 3 and resets each wave", function()
		local clock = WaveClock.new(0)
		WaveClock.step(clock, 0)
		equal(WaveClock.bank(clock, 1, "Ana", 10), true)
		WaveClock.bank(clock, 2, "Beto", 25)
		WaveClock.bank(clock, 3, "Caro", 10)
		WaveClock.bank(clock, 4, "Dani", 5)
		WaveClock.bank(clock, 1, "Ana", 5)
		equal(WaveClock.bank(clock, 5, "Eva", -3), false, "spending never counts")
		equal(WaveClock.bank(clock, 5, "Eva", 0 / 0), false)
		local top = WaveClock.top(clock)
		equal(#top, 3)
		equal(top[1].name, "Beto"); equal(top[1].amount, 25)
		equal(top[2].name, "Ana"); equal(top[2].amount, 15)
		equal(top[3].name, "Caro", "a tie goes to whoever banked first")
		WaveClock.bank(clock, 6, string.rep("x", 40), 1)
		for _, row in ipairs(WaveClock.top(clock, 10)) do assert(#row.name <= 20, "names are cut") end
		WaveClock.step(clock, 300)
		equal(#WaveClock.top(clock), 0, "a new wave starts an empty board")
	end)

	case("RW3: WorldEvent messages are built and read through one rule; anything else is dropped", function()
		local wave = WaveClock.message("wave", { wave = 2, endsAt = 600, board = { { name = "Ana", amount = 12.4 } } })
		assert(wave, "a wave message")
		equal(wave.board[1].amount, 12)
		assert(WaveClock.read(wave), "the client reads what the server sends")
		assert(WaveClock.read(WaveClock.message("board", { board = {} })), "an empty board is fine")
		assert(WaveClock.read(WaveClock.message("event", { phase = "start", species = "Tizoncillo", endsAt = 900 })))
		equal(WaveClock.read({ kind = "nope" }), nil)
		equal(WaveClock.read("wave"), nil)
		equal(WaveClock.read({ kind = "wave", wave = 0 / 0, endsAt = 1, board = {} }), nil)
		equal(WaveClock.read({ kind = "board", board = { {}, {}, {}, {} } }), nil, "at most three rows")
		equal(WaveClock.read({ kind = "event", phase = "boom", species = "X" }), nil)
		equal(WaveClock.read({ kind = "wave", wave = 1, endsAt = 1, board = {}, variant = string.rep("v", 40) }), nil)
	end)

	case("RW3: the module is pure", function()
		assert(type(source) == "string" and #source > 0, "source")
		for _, banned in ipairs({ "game:", "workspace", "task.", "os.time", "os.clock", "math.random", "tick(" }) do
			assert(not source:find(banned, 1, true), "reads " .. banned)
		end
	end)

	case("RW3: the inventory server runs the waves, rerolls the spawns and broadcasts WorldEvent", function()
		local server = sources.server
		has(server, 'require(ReplicatedStorage:WaitForChild("WildboundWaveClock"))')
		has(server, "WaveClock.step(waveClock,")
		has(server, "SpawnClock.reroll(spawnClock,", "a new wave rerolls the spawns")
		has(server, "SpawnClock.force(spawnClock,", "the first wave puts a common egg near camp")
		has(server, "worldEvent:FireAllClients(", "broadcast only")
		has(server, "worldEvent.OnServerEvent:Connect(", "a client message is refused and counted")
		has(server, "WaveClock.bank(waveClock,", "banked Esencia reaches the board")
		has(server, "WaveClock.message(", "every message goes through the rule")
		local client = sources.client
		has(client, "WaveClock.read(", "the client reads only well-formed messages")
	end)

	local CANDIDATES = {
		{ id = "K007", x = -17.5, z = 70 }, { id = "P001", x = -120.08, z = 95.41 }, { id = "P002", x = -75.01, z = 58.96 },
		{ id = "P004", x = -50.5, z = 17.69 }, { id = "P012", x = 97.51, z = -25.59 }, { id = "P014", x = 103.86, z = 38.09 },
		{ id = "P016", x = 99.52, z = 85.89 },
	}

	case("RW4: two or three Refugios each wave from the candidates, a new set each wave", function()
		local C = WaveClock.CONSTANTS
		equal(C.REFUGE_MIN, 2); equal(C.REFUGE_MAX, 3); equal(C.REFUGE_REGEN, 2)
		assert(C.REFUGE_RADIUS >= 8 and C.REFUGE_RADIUS <= 15, "a circle a few players fit in")
		local previous = nil
		for seed = 1, 20 do
			local picked = WaveClock.pickRefuges(CANDIDATES, Random.new(seed), previous)
			assert(#picked >= C.REFUGE_MIN and #picked <= C.REFUGE_MAX, "count " .. #picked)
			local seen = {}
			for _, refuge in ipairs(picked) do
				assert(not seen[refuge.id], "distinct")
				seen[refuge.id] = true
				for _, old in ipairs(previous or {}) do assert(old.id ~= refuge.id, "a new set each wave") end
			end
			previous = picked
		end
		equal(#WaveClock.pickRefuges({}, Random.new(1)), 0, "no candidates, no Refugio")
	end)

	case("RW4: Rules.zone reports a Refugio as safe; a Refugio never reaches the territory", function()
		local Rules = sources.rules
		assert(type(Rules) == "table" and type(Rules.setRefuges) == "function", "Rules.setRefuges missing")
		Rules.setRefuges({ { id = "P004", x = -50.5, z = 17.69 }, { id = "BAD", x = 0, z = -40 } }, 12)
		local _, safe = Rules.zone(-50.5, 17.69)
		equal(safe, true, "inside")
		equal(Rules.refugeAt(-50.5 + 11, 17.69), "P004")
		equal(Rules.refugeAt(-50.5 + 13, 17.69), nil)
		equal(Rules.refugeAt(0, -40), nil, "a circle inside the territory is refused")
		equal(#Rules.refuges(), 1)
		equal(Rules.inTerritory(-50.5, 17.69), false, "no strike inside")
		Rules.setRefuges(nil)
		local _, after = Rules.zone(-50.5, 17.69)
		equal(after, false, "cleared")
		equal(select(2, Rules.zone(-140, 140)), true, "camp stays permanent")
	end)

	case("RW4: stamina comes back twice as fast in a Refugio", function()
		local Stamina = sources.stamina
		local a, b = Stamina.new(0), Stamina.new(0)
		a.stamina, b.stamina = 20, 20
		a.lastDrainAt, b.lastDrainAt = -10, -10
		Stamina.step(a, 1, { speed = 0 }, 0)
		Stamina.step(b, 1, { speed = 0, regenScale = 2 }, 0)
		equal(b.stamina - 20, 2 * (a.stamina - 20))
		local c = Stamina.new(0)
		c.stamina, c.lastDrainAt = 20, -10
		Stamina.step(c, 1, { speed = 0, regenScale = 0 / 0 }, 0)
		equal(c.stamina, a.stamina, "a bad scale is ignored")
	end)

	case("RW4: the server places the Refugios each wave; inside: no strike, no parent chase, regen x2", function()
		local server = sources.server
		has(server, "WaveClock.pickRefuges(spawnGraph.refugeCandidates,")
		has(server, "Rules.setRefuges(")
		has(server, "regenScale = Rules.refugeAt(x, z) and WaveClock.live.REFUGE_REGEN or 1", "stamina x2")
		has(server, "not Rules.refugeAt(", "a parent never chases into a Refugio")
		has(server, "Text.REFUGE.sign", "the sign reads Refugio")
		has(sources.world or "", "Rules.zone(position.X, position.Z)", "the chase ends on the same zone rule")
		equal(sources.text.REFUGE.sign, "Refugio")
	end)

	case("RW5: the biome event comes every 20 minutes, the first at minute 5, and lasts 5 minutes", function()
		local C = WaveClock.CONSTANTS
		equal(C.EVENT_FIRST, 300); equal(C.EVENT_EVERY, 1200); equal(C.EVENT_SECONDS, 300)
		local clock = WaveClock.new(0)
		equal(types(WaveClock.step(clock, 0)), "waveStarted")
		equal(types(WaveClock.step(clock, 299)), "")
		local at5 = WaveClock.step(clock, 300)
		equal(types(at5), "waveStarted,eventStarted", "wave 2 and the first event together")
		equal(at5[2].index, 1); equal(at5[2].endsAt, 600)
		equal(types(WaveClock.step(clock, 450)), "")
		local ended = WaveClock.step(clock, 600)
		equal(types(ended), "waveStarted,eventEnded")
		equal(ended[2].claimed, false)
		equal(types(WaveClock.step(clock, 1499)), "waveStarted", "one wave for the gap, no event yet")
		local second = WaveClock.step(clock, 1500)
		equal(second[#second].type, "eventStarted")
		equal(second[#second].index, 2, "the next at minute 25")
	end)

	case("RW5: a tuned first event time reaches a clock already running (the Play check shortens it)", function()
		local clock = WaveClock.new(0)
		WaveClock.step(clock, 0)
		WaveClock.tune({ EVENT_FIRST = 20, EVENT_EVERY = 60 })
		local events = WaveClock.step(clock, 20)
		WaveClock.tune(nil)
		equal(events[#events] and events[#events].type, "eventStarted")
	end)

	case("RW5: one event at a time, one claimant", function()
		local clock = WaveClock.new(0)
		WaveClock.step(clock, 0)
		equal(WaveClock.claimEvent(clock, 7), false, "nothing to claim before the event")
		WaveClock.step(clock, 300)
		equal(WaveClock.claimEvent(clock, 7), true)
		equal(WaveClock.claimEvent(clock, 8), false, "one claimant")
		local ended = WaveClock.step(clock, 600)
		equal(ended[#ended].claimed, true)
		equal(WaveClock.claimEvent(clock, 9), false, "gone after it ends")
		local named = WaveClock.message("event", { phase = "claimed", species = "Tizoncillo", by = "Ana" })
		equal(named.by, "Ana")
		equal(WaveClock.read({ kind = "event", phase = "claimed", species = "X", by = string.rep("n", 40) }).by:len(), 20)
	end)

	case("RW5: the server places the event egg near La Silueta's home and the HUD shows a Spanish banner", function()
		local server = sources.server
		has(server, 'event.type == "eventStarted"')
		has(server, 'tier = "Legendaria", kind = "Egg"', "a Legendaria point")
		has(server, "special = true")
		has(server, "WaveClock.claimEvent(waveClock,", "one claimant")
		has(server, 'broadcast("event",')
		local Text = sources.text
		equal(Text.EVENT.title, "Huevo especial del bioma")
		assert(#Text.EVENT.banner:format("Tizoncillo", "4:59") <= 48, "the banner fits a phone")
		local client = sources.client
		has(client, "EventBanner", "the banner")
		has(client, "Catalog.SOUNDS.call", "a distant call from an existing id")
		has(client, "UISizeConstraint", "sized for phones")
	end)

	local VARIANTS = { "Niebla", "Escarcha", "Ceniza", "Floracion" }

	case("RW6: the biome variant rotates on the wave clock, every VARIANT_EVERY_WAVES waves", function()
		equal(WaveClock.CONSTANTS.VARIANT_EVERY_WAVES, 1)
		for index, name in ipairs(VARIANTS) do equal(WaveClock.VARIANTS[index], name) end
		equal(WaveClock.variantFor(1), "Niebla"); equal(WaveClock.variantFor(2), "Escarcha")
		equal(WaveClock.variantFor(3), "Ceniza"); equal(WaveClock.variantFor(4), "Floracion")
		equal(WaveClock.variantFor(5), "Niebla")
		WaveClock.tune({ VARIANT_EVERY_WAVES = 2 })
		equal(WaveClock.variantFor(2), "Niebla"); equal(WaveClock.variantFor(3), "Escarcha")
		WaveClock.tune(nil)
		equal(WaveClock.variantFor(0 / 0), "Niebla"); equal(WaveClock.variantFor(-3), "Niebla")
	end)

	case("RW6: each variant weights the spawn kinds, never to nothing", function()
		local kinds = { treeBase = true, canopy = true, root = true, log = true, rock = true, trail = true }
		for _, name in ipairs(VARIANTS) do
			local weights = WaveClock.VARIANT_WEIGHTS[name]
			assert(type(weights) == "table", name)
			local any = false
			for kind, weight in pairs(weights) do
				assert(kinds[kind], name .. " kind " .. tostring(kind))
				assert(type(weight) == "number" and weight > 0 and weight <= 3, name .. " weight " .. tostring(weight))
				any = true
			end
			assert(any or name == "Niebla", name .. " weights something")
		end
	end)

	case("RW6: a variant tints fog and palette but keeps night's darkness and the playable floors", function()
		local Atmosphere = sources.atmosphere
		assert(type(Atmosphere.variant) == "function", "Atmosphere.variant missing")
		for _, name in ipairs(VARIANTS) do
			local look = Atmosphere.VARIANTS[name]
			assert(type(look) == "table", name)
			assert(({ wind = true, birds = true, insectsDusk = true, insectsNight = true })[look.ambient],
				name .. " ambient from an existing catalog slot")
			for _, clock in ipairs({ 12, 19, 23 }) do
				for _, zone in ipairs({ "open", "fog", "camp" }) do
					local base = Atmosphere.at(clock, zone, false)
					local out = Atmosphere.variant(base, name)
					for _, key in ipairs({ "brightness", "exposure", "ambientWeight" }) do
						equal(out[key], base[key], name .. " keeps " .. key)
					end
					equal(out.ambient.r, base.ambient.r, name .. " keeps the ambient")
					assert(out.fogStart >= Atmosphere.FLOORS.fogStart - 1e-9, "fog start floor")
					assert(out.fogEnd >= Atmosphere.FLOORS.fogEnd - 1e-9, "fog end floor")
					assert(out.density <= Atmosphere.FLOORS.density + 1e-9, "density ceiling")
					assert(out.haze <= Atmosphere.FLOORS.haze + 1e-9, "haze ceiling")
					assert(math.abs(out.fogEnd - base.fogEnd) <= base.fogEnd * 0.2 + 1e-9, name .. " a tint, not a new map")
					assert(type(out.tint) == "table", "a palette tint")
				end
			end
		end
		local same = Atmosphere.variant(Atmosphere.at(12, "open", false), "Nope")
		equal(same.tint.r, 255, "an unknown variant changes nothing")
	end)

	case("RW6: the server rotates the variant, the clients tint, play its ambience and say so in Spanish", function()
		local server = sources.server
		has(server, "WaveClock.variantFor(event.wave)")
		has(server, "SpawnClock.setWeights(spawnClock, WaveClock.VARIANT_WEIGHTS[")
		has(server, 'network:SetAttribute("BiomeVariant",')
		assert(not server:find("nightsSurvived", 1, true) and not server:find("NightsSurvived", 1, true),
			"no mechanic is gated by nights survived")
		local worldClient = sources.worldClient
		has(worldClient, "Atmos.variant(")
		has(worldClient, '"BiomeVariant"')
		has(worldClient, "ColorCorrectionEffect")
		has(sources.client, "Text.VARIANT.changed")
		local Text = sources.text
		equal(Text.VARIANT.Floracion, "Floración")
		equal(Text.VARIANT.Escarcha, "Escarcha")
		assert(#Text.VARIANT.changed:format("Floración") <= 72, "a notice")
	end)

	return result
end

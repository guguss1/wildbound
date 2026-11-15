-- Invoke with require(freshTestClone)(require(freshWaveClockClone), freshWaveClockClone.Source,
-- { server = WildboundServer.Source, client = WildboundClient.Source, text = require(freshTextClone),
-- rules = require(freshRulesClone), stamina = require(freshStaminaClone), world = WildboundWorld.Source,
-- worldClient = WildboundWorldClient.Source, atmosphere = require(freshAtmosphereClone),
-- view = require(freshHudViewClone) }).
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
		has(server, "SpawnClock.force(spawnClock,", "the first wave puts a guaranteed common egg")
		has(server, "x = Rules.FIRST_EGG_X, z = Rules.FIRST_EGG_Z,", "EV-W5: near the hub's forest gate, not the old camp")
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

	case("RW7: the wave board shows the wave, its countdown and the top 3 within the chip budgets", function()
		local View, Text = sources.view, sources.text
		assert(type(View) == "table" and type(View.waveBoard) == "function", "View.waveBoard missing")
		local C = View.CONSTANTS
		local board = { { name = "Ana", amount = 25 }, { name = "Beto", amount = 10 } }
		local out = View.waveBoard({ wave = 3, endsAt = 400, now = 160, board = board, words = Text.WAVE })
		equal(out.title, "Oleada 3 · 4:00")
		equal(#out.lines, 2)
		equal(out.lines[1], "1. Ana · 25"); equal(out.lines[2], "2. Beto · 10")
		local long = { { name = string.rep("Nombrelargo", 2), amount = 12345 } }
		for _, compact in ipairs({ false, true }) do
			local budget = compact and C.COMPACT_BOARD_CHARS or C.BOARD_CHARS
			local view = View.waveBoard({ wave = 12, endsAt = 9999, now = 0, board = long, words = Text.WAVE, compact = compact })
			assert(utf8.len(view.title) <= budget, "title fits: " .. view.title)
			for _, line in ipairs(view.lines) do assert(utf8.len(line) <= budget, "row fits: " .. line) end
		end
		local empty = View.waveBoard({ wave = 1, endsAt = 10, now = 20, board = {}, words = Text.WAVE })
		equal(empty.title, "Oleada 1 · 0:00", "a past end reads zero")
		equal(empty.lines[1], Text.WAVE.empty)
		equal(View.waveBoard(nil), nil)
		equal(View.waveBoard({ wave = 0 / 0, words = Text.WAVE }), nil)
	end)

	case("RW7: the event banner fits the chip's width on a desktop and on a phone", function()
		local View, Text = sources.view, sources.text
		assert(type(View.eventBanner) == "function", "View.eventBanner missing")
		local C = View.CONSTANTS
		local wide = View.eventBanner({ species = "Tizoncillo", endsAt = 299, now = 0, words = Text.EVENT })
		equal(wide, "Huevo especial: Tizoncillo · 4:59")
		assert(utf8.len(wide) <= C.BANNER_CHARS, "desktop budget")
		local narrow = View.eventBanner({ species = "Tizoncillo", endsAt = 299, now = 0, words = Text.EVENT, compact = true })
		assert(utf8.len(narrow) <= C.COMPACT_BANNER_CHARS, "phone budget: " .. narrow)
		assert(narrow:find("4:59", 1, true), "the countdown stays on a phone")
		equal(View.eventBanner(nil), nil)
	end)

	-- Deliberately changed (user decision 2026-11-14, "Que queden ocultos"): the client still builds the board and the
	-- banner, but keeps both hidden; the pure views above stay ready for when they come back.
	case("RW7: the inventory client keeps the wave board and the event banner hidden", function()
		local client = sources.client
		has(client, '"WaveBoard"')
		has(client, '"EventBanner"')
		has(client, "local function refreshBoard()\n\twaveBoard.Visible = false\nend", "the board stays hidden")
		has(client, "local function refreshBanner()\n\teventBanner.Visible = false\nend", "the banner stays hidden")
	end)

	-- CA4 (user, 2026-11-15; Caramelo pack 05_SISTEMAS/01_OLEADAS_300_SEGUNDOS.md): the one 300 s egg clock. Collect from
	-- 0 to 289.999, Warning from 290 to 299.999 (no new steal hold), the refresh at 300 (a new wave id, once).
	case("CA4: the Collect and Warning windows and their boundaries", function()
		WaveClock.tune(nil)
		equal(WaveClock.CONSTANTS.WARNING_SECONDS, 10)
		local alerts = WaveClock.ALERTS
		equal(table.concat(alerts, ","), "10,5,3,2,1")
		local state = WaveClock.new(0)
		equal(WaveClock.window(state, 0).name, "Idle", "before the first step")
		WaveClock.step(state, 0)
		for _, sample in ipairs({ { 0, "Collect" }, { 289.9, "Collect" }, { 290, "Warning" }, { 299.9, "Warning" } }) do
			local window = WaveClock.window(state, sample[1])
			equal(window.name, sample[2], "at " .. sample[1])
			equal(window.wave, 1)
			equal(window.endsAt, 300)
		end
		equal(WaveClock.window(state, 295).remaining, 5)
		equal(#WaveClock.step(state, 299.9), 0, "no refresh before 300")
		local events = WaveClock.step(state, 300)
		equal(events[1].type, "waveStarted", "the refresh comes first (the first biome event may share the step)")
		equal(select(2, types(events):gsub("waveStarted", "")), 1, "one refresh")
		equal(events[1].wave, 2)
		equal(#WaveClock.step(state, 300), 0, "the wave id changes once")
		equal(#WaveClock.step(state, 300.01), 0)
		equal(WaveClock.window(state, 300).name, "Collect")
		equal(WaveClock.window(state, 300).wave, 2)
		equal(WaveClock.window(nil, 5).name, "Idle")
		equal(WaveClock.window(state, 0 / 0).name, "Idle")
	end)

	case("CA4: a steal hold begun before the warning resolves; one begun in the warning is refused", function()
		WaveClock.tune(nil)
		local state = WaveClock.new(0)
		equal(WaveClock.holdAllowed(state, 5), true, "no wave yet: nothing to lock")
		WaveClock.step(state, 0)
		equal(WaveClock.holdAllowed(state, 289), true, "begun at 289: it resolves")
		equal(WaveClock.holdAllowed(state, 289.99), true)
		equal(WaveClock.holdAllowed(state, 290), false, "begun at 290: refused")
		equal(WaveClock.holdAllowed(state, 299.9), false)
		WaveClock.step(state, 300)
		equal(WaveClock.holdAllowed(state, 295), false, "a warning hold stays refused after the refresh")
		equal(WaveClock.holdAllowed(state, 289), true, "an older hold still resolves across the refresh")
		equal(WaveClock.holdAllowed(state, 300), true, "the new wave collects at once")
		equal(WaveClock.holdAllowed(state, 0 / 0), false)
		-- A wave tuned short keeps a warning of at most half the wave.
		WaveClock.tune({ WAVE_SECONDS = 12 })
		local short = WaveClock.new(0)
		WaveClock.step(short, 0)
		equal(WaveClock.window(short, 5).name, "Collect")
		equal(WaveClock.window(short, 6).name, "Warning")
		WaveClock.tune(nil)
	end)

	case("CA4: the server gates new holds, binds the spawn clock and refreshes the empty nests at the wave start", function()
		local server = sources.server or ""
		has(server, "WaveClock.holdAllowed(waveClock, entry.holdStarts[player].at)", "the steal hold")
		has(server, "WaveClock.holdAllowed(waveClock, workspace:GetServerTimeNow())", "the Arrullo start")
		has(server, "Text.WAVE.locked", "the refusal line")
		has(server, "SpawnClock.bindWave(spawnClock, event.endsAt)")
		has(server, "Heist.resetNestsForWave(now, event.wave)")
		has(server, "if Heist.nestWave == wave then return end", "idempotent by wave id")
		for _, gone in ipairs({ "stepNightEggReset", "resetEggsAfterNight", "lastNightPhase", "wait_night",
			"¡Pasó la noche!" }) do
			assert(not server:find(gone, 1, true), "the night egg reset is gone: " .. gone)
		end
	end)

	case("CA4: the client warns at 10, 5, 3, 2 and 1 s and the lines are Spanish", function()
		local Text = sources.text
		assert(type(Text.WAVE.warning) == "string" and Text.WAVE.warning:find("%d", 1, true), "Text.WAVE.warning")
		assert(type(Text.WAVE.locked) == "string" and #Text.WAVE.locked > 0, "Text.WAVE.locked")
		assert(Text.WAVE.started:find("renov", 1, true), "the wave start says the eggs were renewed")
		has(sources.client, "Text.WAVE.warning:format(", "the countdown notice")
		has(sources.client, "WaveClock.ALERTS", "the alert seconds come from the clock module")
	end)

	-- CF2 (odd/tasks/wildbound-caramelo.md): a steal hold is judged when it starts. A hold that would end inside the
	-- Warning window (or starts in it) is refused at once, so nobody holds for nothing; one that ends before the
	-- warning, or spans the whole warning and resolves after the refresh, is allowed.
	case("CF2: holdFits refuses a hold that would end inside the Warning window", function()
		WaveClock.tune(nil)
		local state = WaveClock.new(0)
		equal(WaveClock.holdFits(state, 5, 3), true, "no wave yet: nothing to lock")
		WaveClock.step(state, 0)
		equal(WaveClock.holdFits(state, 100, 3), true, "mid-wave")
		equal(WaveClock.holdFits(state, 286.9, 3), true, "ends at 289.9: before the warning")
		equal(WaveClock.holdFits(state, 287, 3), false, "ends at 290: inside the warning")
		equal(WaveClock.holdFits(state, 289, 3), false, "starts in Collect, ends in Warning")
		equal(WaveClock.holdFits(state, 292, 1), false, "starts in the warning")
		equal(WaveClock.holdFits(state, 285, 20), true, "spans the whole warning: resolves after the refresh")
		equal(WaveClock.holdFits(state, 100, 0), true, "an instant hold")
		equal(WaveClock.holdFits(state, 100, 0 / 0), false, "a bad hold length")
		equal(WaveClock.holdFits(state, 0 / 0, 3), false, "a bad start")
		WaveClock.step(state, 300)
		equal(WaveClock.holdFits(state, 295, 1), false, "a warning hold stays refused after the refresh")
		equal(WaveClock.holdFits(state, 300, 3), true, "the new wave collects at once")
	end)

	-- CF2: the wave's end is bound when it starts (the waveStarted event's endsAt, the same one SpawnClock.bindWave
	-- gets). The Warning window, holdAllowed, endsAt and the refresh read that bound end, never the live WAVE_SECONDS,
	-- so a tuned length applies from the next wave and the two clocks never disagree.
	case("CF2: the window, the hold gate and the refresh use the bound wave end", function()
		WaveClock.tune(nil)
		local state = WaveClock.new(0)
		local first = WaveClock.step(state, 0)
		equal(first[1].endsAt, 300)
		WaveClock.tune({ WAVE_SECONDS = 30 })
		equal(WaveClock.endsAt(state), 300, "endsAt is the bound end")
		equal(WaveClock.window(state, 25).name, "Collect", "no warning at 25 of a 300 s wave")
		equal(WaveClock.window(state, 25).endsAt, 300)
		equal(WaveClock.holdAllowed(state, 25), true, "a hold at 25 is not in the bound wave's warning")
		equal(WaveClock.holdAllowed(state, 295), false, "the bound wave's warning")
		equal(WaveClock.holdFits(state, 285, 3), true)
		local early = 0
		for _, event in ipairs(WaveClock.step(state, 30)) do
			if event.type == "waveStarted" then early += 1 end
		end
		equal(early, 0, "the refresh waits for the bound end")
		local second = WaveClock.step(state, 300)
		equal(second[1].type, "waveStarted")
		equal(second[1].endsAt, 330, "the tuned length applies from the next wave")
		equal(WaveClock.endsAt(state), 330)
		equal(WaveClock.window(state, 321).name, "Warning", "the tuned wave's warning (half of 30 s caps at 10 s)")
		WaveClock.tune(nil)
		equal(WaveClock.endsAt(state), 330, "restoring the default does not move the bound end")
	end)

	case("CF2: the server refuses a steal hold at its start and binds the hold gate to the wave", function()
		local server = sources.server or ""
		has(server, "WaveClock.holdFits(waveClock, now, need)", "the hold-start check")
		has(server, "entry.holdStarts[player] = { at = now, refused = true }", "a refused hold is remembered")
		has(server, "if entry.holdStarts[player] and entry.holdStarts[player].refused then", "the trigger never resolves it")
		local began = server:find("PromptButtonHoldBegan", 1, true)
		local fits = server:find("WaveClock.holdFits(waveClock, now, need)", 1, true)
		local locked = fits and server:find("Text.WAVE.locked", fits, true)
		assert(began and fits and fits > began and locked and locked - fits < 400, "the refusal is sent at the hold start")
		assert(type(source) == "string" and not source:find("state.waveStartedAt + WaveClock.live.WAVE_SECONDS", 1, true),
			"nothing recomputes a wave end from the live length")
	end)

	return result
end

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
		local late = WaveClock.step(clock, 2500)
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

	return result
end

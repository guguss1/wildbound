-- Invoke with require(freshTestClone)(require(freshIncubatorClone), freshIncubatorClone.Source, { server =
-- WildboundServer.Source, client = WildboundClient.Source, text = require(freshTextClone) }).
-- Next batch NB4 (delivery E, docs/mechanics/wildbound-incubator.md): the pure incubator timer and the wiring that keeps
-- it on the server's clock and in the server's hands.
return function(Incubator, source, sources)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "Expected " .. tostring(expected) .. ", got "
			.. tostring(actual))
	end
	local function near(actual, expected, label)
		assert(type(actual) == "number" and math.abs(actual - expected) < 1e-6,
			(label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	sources = type(sources) == "table" and sources or {}

	case("NB4: the defaults, the live copy and the tuning hook", function()
		assert(type(Incubator) == "table" and type(Incubator.CONSTANTS) == "table", "module missing")
		equal(Incubator.CONSTANTS.HATCH_SECONDS, 90)
		equal(Incubator.CONSTANTS.SLOTS, 1)
		equal(Incubator.CONSTANTS.RANGE, 12)
		assert(table.isfrozen(Incubator.CONSTANTS), "the defaults are frozen")
		equal(Incubator.tunable().HATCH_SECONDS, 90)
		Incubator.tune({ HATCH_SECONDS = 30 })
		equal(Incubator.live.HATCH_SECONDS, 30)
		Incubator.tune({ HATCH_SECONDS = 0 / 0, NOPE = 4 })
		equal(Incubator.live.HATCH_SECONDS, 90, "a bad value keeps the default")
		equal(Incubator.live.NOPE, nil)
		Incubator.tune(nil)
		equal(Incubator.live.HATCH_SECONDS, 90)
	end)

	case("NB4: progress follows the server clock and never leaves 0 to 1", function()
		local entry = { uid = "u1", species = "Lumipol", startedAt = 100, readyAt = 190 }
		local start = Incubator.progress(entry, 100)
		near(start.fraction, 0); equal(start.remaining, 90); equal(start.ready, false)
		local half = Incubator.progress(entry, 145)
		near(half.fraction, 0.5); equal(half.remaining, 45); equal(half.ready, false)
		local done = Incubator.progress(entry, 190)
		near(done.fraction, 1); equal(done.remaining, 0); equal(done.ready, true)
		near(Incubator.progress(entry, 400).fraction, 1)
		near(Incubator.progress(entry, 50).fraction, 0, "a clock before the start")
		equal(Incubator.progress(entry, 145.2).remaining, 45, "whole seconds, rounded up")
		for _, bad in ipairs({ nil, "x", {}, { startedAt = 10 }, { startedAt = 0 / 0, readyAt = 5 } }) do
			equal(Incubator.progress(bad, 100), nil)
		end
		equal(Incubator.progress(entry, 0 / 0), nil)
	end)

	case("NB4: the Bag row names the species and the seconds left, in Spanish", function()
		local Text = sources.text
		assert(type(Text) == "table" and type(Text.INCUBATOR) == "table", "Text.INCUBATOR")
		local entry = { uid = "u1", species = "Lumipol", startedAt = 100, readyAt = 190 }
		local row = Incubator.row(entry, 145, Text)
		assert(row:find("Lumipol", 1, true) and row:find("45", 1, true), row)
		assert(Incubator.row(entry, 190, Text):find(Text.INCUBATOR.hatching, 1, true), "ready says it is hatching")
		equal(Incubator.row(nil, 100, Text), nil)
		for _, key in ipairs({ "prompt", "object", "started", "full", "hatched", "row", "hatching", "sign" }) do
			assert(type(Text.INCUBATOR[key]) == "string" and #Text.INCUBATOR[key] > 0, "INCUBATOR." .. key)
			assert(#Text.INCUBATOR[key] <= 80, "INCUBATOR." .. key .. " fits a notice")
		end
	end)

	case("NB4: the module is pure", function()
		for _, word in ipairs({ "game", "GetService", "os.", "tick", "Random", "DataStore", "task.", "workspace",
			"Instance", "MarketplaceService", "Robux" }) do
			equal(source:find(word, 1, true), nil, "source mentions " .. word)
		end
	end)

	case("NB4: the server owns the incubator: its clock, its checks, its hatch step", function()
		local server = sources.server
		assert(type(server) == "string", "server source")
		assert(server:find("state:incubate(", 1, true), "the server incubates through State")
		assert(server:find("state:hatchReady(", 1, true), "and hatches through State")
		assert(server:find("Incubator.live.HATCH_SECONDS", 1, true), "with the live, tunable time")
		assert(server:find("FindFirstChild(\"IncubatorMarker\", true)", 1, true), "at the incubator in camp")
		assert(not server:find("state:hatch(", 1, true), "no instant hatch is left")
		local incubate = server:find("state:incubate(", 1, true)
		local line = server:sub(incubate, (server:find("\n", incubate, true) or #server))
		assert(line:find("workspace:GetServerTimeNow()", 1, true), "the start time is the server's: " .. line)
	end)

	case("NB4: the Bag tab shows what incubates and never sends a time", function()
		local client = sources.client
		assert(type(client) == "string", "client source")
		assert(client:find("Incubator.row(", 1, true), "the row comes from the pure module")
		assert(client:find("snapshot.incubating", 1, true), "it reads the server snapshot")
	end)

	return result
end

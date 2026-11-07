-- Invoke with require(freshTestClone)(require(freshFakeClone), freshFakeClone.Source). Contracts for the in-memory
-- store port that the persistence contracts run against (W10, M6.2). It is a test double: deterministic, scripted
-- faults, an injected clock, a full write log and byte-exact reads. It never touches a real data store.
return function(Fake, source)
	local result = { passed = 0, failed = 0, messages = {} }
	local HttpService = game:GetService("HttpService")
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "Expected " .. tostring(expected)
			.. ", got " .. tostring(actual))
	end
	local function world(options)
		local clock = { t = 1000 }
		options = options or {}
		options.clock = function() return clock.t end
		options.wait = function(seconds) clock.t += seconds end
		return Fake.new(options), clock
	end
	local function put(value, metadata)
		return function() return value, metadata end
	end

	case("FK-1: an update on an absent key sees nil, stores the result and records when", function()
		local store, clock = world()
		local seen = "unset"
		local ok, value, info = store:update("Player_1", function(current) seen = current; return { a = 1 }, { LockId = "A" } end)
		equal(ok, true); equal(seen, nil); equal(value.a, 1)
		equal(info.updatedAt, clock.t); equal(info.metadata.LockId, "A")
		local okRead, read, readInfo = store:read("Player_1")
		equal(okRead, true); equal(read.a, 1); equal(readInfo.metadata.LockId, "A")
		equal(#store.writes, 1); equal(store.writes[1].key, "Player_1")
	end)

	case("FK-2: a transform that returns nil cancels: no write, value unchanged", function()
		local store = world()
		store:seed("k", { a = 1 }, { LockId = "A" }, 900)
		local before = store:raw("k")
		local ok, value, info = store:update("k", function() return nil end)
		equal(ok, true); equal(value.a, 1); equal(info.cancelled, true)
		equal(store:raw("k"), before); equal(#store.writes, 0)
	end)

	case("FK-3: the transform runs twice per call on detached copies", function()
		local store = world()
		store:seed("k", { list = { 1, 2 } }, {}, 900)
		local runs = 0
		store:update("k", function(current)
			runs += 1
			table.insert(current.list, 99)
			return current, {}
		end)
		equal(runs, 2)
		local _, read = store:read("k")
		equal(#read.list, 3, "only the last run's result is written, from a fresh copy")
		equal(store.transformRuns, 2)
	end)

	case("FK-4: scripted faults: throwBefore, commitThenThrow, timeout and throttle", function()
		local store = world()
		store:seed("k", { n = 0 }, {}, 900)
		store:script({ "throwBefore", "commitThenThrow", "timeout", "throttle" })
		local ok, kind = store:update("k", put({ n = 1 }, {}))
		equal(ok, false); equal(kind, "Error")
		local _, read = store:read("k"); equal(read.n, 0, "throwBefore writes nothing")
		ok, kind = store:update("k", put({ n = 2 }, {}))
		equal(ok, false); equal(kind, "Error")
		_, read = store:read("k"); equal(read.n, 2, "commitThenThrow writes, then reports an error")
		ok, kind = store:update("k", put({ n = 3 }, {}))
		equal(ok, false); equal(kind, "Timeout")
		ok, kind = store:update("k", put({ n = 4 }, {}))
		equal(ok, false); equal(kind, "Throttled")
		_, read = store:read("k"); equal(read.n, 2)
		equal(#store.writes, 1)
		ok = store:update("k", put({ n = 5 }, {}))
		equal(ok, true, "the script is used up in order, then calls succeed")
	end)

	case("FK-5: failAll fails every call, reads included, until cleared", function()
		local store = world()
		store:seed("k", { n = 0 }, {}, 900)
		store:failAll("Error")
		for _ = 1, 3 do
			local ok, kind = store:update("k", put({ n = 9 }, {}))
			equal(ok, false); equal(kind, "Error")
		end
		local okRead, kind = store:read("k")
		equal(okRead, false); equal(kind, "Error")
		store:failAll(nil)
		equal((store:update("k", put({ n = 1 }, {}))), true)
		equal(store.calls, 5)
	end)

	case("FK-6: latency advances the shared clock before the transform reads", function()
		local store, clock = world()
		store:script({ { delay = 2.5 } })
		local seenAt
		store:update("k", function() seenAt = clock.t; return { a = 1 }, {} end)
		equal(seenAt, 1002.5)
		equal(store.writes[1].at, 1002.5)
	end)

	case("FK-7: a before hook runs ahead of the read, so a second server can land first", function()
		local store = world()
		store:seed("k", { owner = "none" }, {}, 900)
		store:script({ { before = function()
			store:update("k", put({ owner = "B" }, { LockId = "B" }))
		end } })
		local seen
		store:update("k", function(current, info) seen = current.owner .. "/" .. tostring(info.metadata.LockId); return nil end)
		equal(seen, "B/B")
	end)

	case("FK-8: reads are byte exact and every value is a detached JSON copy", function()
		local store = world()
		local value = { a = { 1, 2, 3 }, b = "x" }
		store:seed("k", value, {}, 900)
		equal(store:raw("k"), HttpService:JSONEncode(value))
		value.b = "changed"
		local _, read = store:read("k")
		equal(read.b, "x")
		read.b = "mutated"
		local _, again = store:read("k")
		equal(again.b, "x")
		store:seedRaw("r", "{\"schema\":\"bad\"}")
		equal(store:raw("r"), "{\"schema\":\"bad\"}")
		equal(store:raw("missing"), nil)
	end)

	case("FK-9: a write budget per minute throttles, and frees up after a minute", function()
		local store, clock = world({ writesPerMinute = 2 })
		equal((store:update("k", put({ n = 1 }, {}))), true)
		equal((store:update("k", put({ n = 2 }, {}))), true)
		local ok, kind = store:update("k", put({ n = 3 }, {}))
		equal(ok, false); equal(kind, "Throttled")
		clock.t += 60
		equal((store:update("k", put({ n = 4 }, {}))), true)
	end)

	case("FK-10: a value over the size limit is refused and nothing changes", function()
		local store = world({ maxChars = 50 })
		store:seed("k", { n = 0 }, {}, 900)
		local ok, kind = store:update("k", put({ text = string.rep("x", 60) }, {}))
		equal(ok, false); equal(kind, "TooLarge")
		equal(#store.writes, 0)
		equal(Fake.MAX_CHARS, 4194304)
	end)

	case("FK-11: returned metadata replaces the stored metadata, and nil clears it", function()
		local store = world()
		store:update("k", put({ n = 1 }, { LockId = "A" }))
		equal(store:metadata("k").LockId, "A")
		store:update("k", put({ n = 2 }, nil))
		equal(store:metadata("k").LockId, nil)
	end)

	case("FK-12: the same script gives the same log every time", function()
		local function run()
			local store = world()
			store:script({ "throwBefore", { delay = 1 }, "commitThenThrow" })
			for n = 1, 4 do store:update("k", put({ n = n }, { LockId = "A" })) end
			local log = {}
			for _, write in ipairs(store.writes) do table.insert(log, write.at .. "|" .. write.bytes) end
			return table.concat(log, ";")
		end
		local first = run()
		equal(run(), first)
		assert(#first > 0, "something was written")
	end)

	case("FK-13: source check: the fake never names the data store service", function()
		assert(type(source) == "string" and #source > 0, "source passed")
		assert(not string.find(source, "DataStoreService", 1, true), "no DataStoreService")
		assert(not string.find(source, "GetDataStore", 1, true), "no GetDataStore")
	end)

	return result
end

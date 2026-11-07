-- Invoke with require(freshTestClone)(require(freshAnalyticsClone), { analytics = freshAnalyticsClone.Source }).
-- The event seam of W16 (M9.5): closed vocabulary, privacy, limits, sink faults and the off switch, all against an
-- in-memory recorder and an injected clock. Green here proves logic only. AN numbers refer to
-- docs/testing/wildbound-f2-plan.md section 2; Roblox receipt (AN-8) needs an approved published dry run.
return function(Analytics, sources)
	local result = { passed = 0, failed = 0, messages = {} }
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
	local function names(events)
		local list = {}
		for _, item in ipairs(events) do table.insert(list, item.name) end
		return table.concat(list, ",")
	end
	local function setup(extra)
		local clock = { t = 5000 }
		local recorder = Analytics.recorder(1000)
		local options = { sink = recorder, clock = function() return clock.t end, tag = "aaaaaaaaaaaa" }
		for k, v in pairs(extra or {}) do options[k] = v end
		return Analytics.new(options), recorder, clock
	end
	local EXPECTED = { "capture_end", "death", "first_capture", "first_craft", "first_extract", "first_gain",
		"first_gather", "session_end", "session_join", "spent", "start_play", "strike", "trip_end", "trip_open",
		"tutorial_complete", "tutorial_skip" }

	-- vocabulary ----------------------------------------------------------------------------------------------
	case("the vocabulary is the closed, versioned set", function()
		equal(Analytics.SCHEMA, 1)
		assert(table.isfrozen(Analytics.EVENTS), "events frozen")
		local found = {}
		for name in pairs(Analytics.EVENTS) do table.insert(found, name) end
		table.sort(found)
		equal(table.concat(found, ","), table.concat(EXPECTED, ","))
	end)
	case("every field is a short enumerated list, at most three fields per event", function()
		for name, def in pairs(Analytics.EVENTS) do
			local count = 0
			assert(table.isfrozen(def) and table.isfrozen(def.fields), name .. " frozen")
			for field, list in pairs(def.fields) do
				count += 1
				assert(field:match("^[a-z]+$"), name .. "." .. field .. " name")
				assert(#list >= 2 and table.isfrozen(list), name .. "." .. field .. " list")
				for _, value in ipairs(list) do
					assert(type(value) == "string" and #value <= 16 and value:match("^[%w_]+$"), name .. "." .. field)
				end
			end
			assert(count <= Analytics.MAX_FIELDS, name .. " has " .. count .. " fields")
		end
	end)
	case("validate accepts exact fields and rejects everything else (AN-6)", function()
		assert(Analytics.validate("session_join"))
		assert(Analytics.validate("trip_open", { n = "2" }))
		local bad = {
			{ "nope", nil }, { "session_join", { extra = "x" } }, { "trip_open", {} }, { "trip_open", { n = "9" } },
			{ "trip_open", { n = 2 } }, { "trip_open", { n = "2", extra = "x" } }, { "trip_open", { n = { "2" } } },
			{ "trip_open", { n = string.rep("1", 5000) } }, { "trip_open", "2" }, { 5, nil }, { "trip_open", { "2" } },
			{ "spent", { what = "totem" } }, { "death", { cause = "Silueta" } },
		}
		for index, row in ipairs(bad) do
			local ok = Analytics.validate(row[1], row[2])
			assert(ok == false, "case " .. index .. " should be rejected")
		end
	end)

	-- sessions and privacy ------------------------------------------------------------------------------------
	case("join logs session_join with an opaque id that holds no part of the key", function()
		local analytics, recorder = setup()
		local key = 123456789
		assert(analytics:join(key))
		local e = recorder.events[1]
		equal(e.name, "session_join")
		equal(e.v, 1)
		equal(e.seq, 1)
		equal(e.t, 0)
		assert(e.sid:match("^%x%x%x%x%x%x%x%x%x%x%x%x%-%d+$") or e.sid:match("^a+%-%d+$"), "sid shape " .. e.sid)
		assert(not e.sid:find("123456789", 1, true), "sid leaks the key")
	end)
	case("an event has exactly v, name, sid, seq, t and f, and is frozen", function()
		local analytics, recorder = setup()
		analytics:join(1)
		analytics:observeCamp(1, true)
		for _, e in ipairs(recorder.events) do
			local keys = {}
			for k in pairs(e) do table.insert(keys, k) end
			table.sort(keys)
			equal(table.concat(keys, ","), "f,name,seq,sid,t,v")
			assert(table.isfrozen(e) and table.isfrozen(e.f), "frozen")
			for k, v in pairs(e.f) do assert(type(k) == "string" and type(v) == "string", "field types") end
		end
	end)
	case("joining twice logs once and a second player gets another id", function()
		local analytics, recorder = setup()
		assert(analytics:join("a"))
		assert(not analytics:join("a"))
		assert(analytics:join("b"))
		equal(#recorder.events, 2)
		assert(recorder.events[1].sid ~= recorder.events[2].sid, "ids differ")
		equal(analytics:join(nil), false)
	end)
	case("t counts whole seconds from the join and seq rises by one", function()
		local analytics, recorder, clock = setup()
		analytics:join(1)
		clock.t += 12.9
		analytics:observeCamp(1, true)
		equal(recorder.events[2].t, 12)
		equal(recorder.events[2].seq, 2)
		equal(recorder.events[2].sid, recorder.events[1].sid)
	end)
	case("a call for a player who never joined logs nothing and is counted", function()
		local analytics, recorder = setup()
		equal(analytics:observeCamp(7, true), false)
		equal(analytics:extracted(7), false)
		equal(analytics:death(7), false)
		equal(analytics:leave(7), false)
		equal(#recorder.events, 0)
		equal(analytics.counters.unknownSession, 4)
	end)

	-- funnel moments ------------------------------------------------------------------------------------------
	case("leaving camp opens one trip; staying in camp logs nothing", function()
		local analytics, recorder = setup()
		analytics:join(1)
		analytics:observeCamp(1, false)
		equal(#recorder.events, 1)
		analytics:observeCamp(1, true)
		analytics:observeCamp(1, true)
		equal(names(recorder.events), "session_join,trip_open")
		equal(recorder.events[2].f.n, "1")
	end)
	case("a first gather logs trip_open, first_gain and first_gather in that order, and only once (AN-1)", function()
		local analytics, recorder = setup()
		analytics:join(1)
		assert(analytics:gain(1, "gather", "fog"))
		equal(names(recorder.events), "session_join,trip_open,first_gain,first_gather")
		equal(recorder.events[3].f.source, "gather")
		equal(recorder.events[4].f.zone, "fog")
		assert(analytics:gain(1, "gather", "outside"))
		equal(#recorder.events, 4)
		equal(analytics.counters.duplicates, 2)
	end)
	case("a gain with a bad source or zone logs nothing", function()
		local analytics, recorder = setup()
		analytics:join(1)
		equal(analytics:gain(1, "gift", "fog"), false)
		equal(analytics:gain(1, "gather", "moon"), false)
		equal(analytics:gain(1, "gather", nil), false)
		equal(analytics:gain(1, "capture", {}), false)
		equal(#recorder.events, 1)
		assert(analytics:gain(1, "pickup"), "pickup needs no zone")
	end)
	case("trips are numbered 1, 2, 3 and 4plus", function()
		local analytics, recorder, clock = setup()
		analytics:join(1)
		for _ = 1, 5 do
			analytics:observeCamp(1, true)
			analytics:gain(1, "pickup")
			clock.t += 60
			analytics:extracted(1)
		end
		local labels = {}
		for _, e in ipairs(recorder.events) do if e.name == "trip_open" then table.insert(labels, e.f.n) end end
		equal(table.concat(labels, ","), "1,2,3,4plus,4plus")
	end)
	case("an extraction logs first_extract once and ends the trip with its band and gain", function()
		local analytics, recorder, clock = setup()
		analytics:join(1)
		analytics:gain(1, "pickup")
		clock.t += 300
		assert(analytics:extracted(1))
		local tail = {}
		for i = 4, #recorder.events do table.insert(tail, recorder.events[i]) end
		equal(names(tail), "first_extract,trip_end")
		equal(tail[2].f.outcome, "extracted")
		equal(tail[2].f.band, "3to8")
		equal(tail[2].f.gained, "yes")
		analytics:extracted(1)
		equal(#recorder.events, 5, "no second first_extract and no trip to end")
	end)
	case("trip length bands break at 3 and 8 minutes", function()
		local function band(seconds)
			local analytics, recorder, clock = setup()
			analytics:join(1)
			analytics:observeCamp(1, true)
			clock.t += seconds
			analytics:extracted(1)
			for _, e in ipairs(recorder.events) do if e.name == "trip_end" then return e.f.band, e.f.gained end end
		end
		equal(band(179), "under3")
		equal(band(180), "3to8")
		equal(band(480), "3to8")
		equal(band(481), "over8")
		local _, gained = band(10)
		equal(gained, "no")
	end)
	case("a defeat soon after a strike is Silueta's, otherwise other, and ends the trip", function()
		local analytics, recorder, clock = setup()
		analytics:join(1)
		analytics:observeCamp(1, true)
		analytics:noteStrike(1)
		clock.t += 10
		assert(analytics:death(1))
		local deaths = {}
		for _, e in ipairs(recorder.events) do if e.name == "death" then table.insert(deaths, e.f.cause) end end
		equal(deaths[1], "silueta")
		equal(recorder.events[#recorder.events].name, "trip_end")
		equal(recorder.events[#recorder.events].f.outcome, "defeated")
		analytics:observeCamp(1, true)
		analytics:noteStrike(1)
		clock.t += 10.5
		analytics:death(1)
		analytics:death(1)
		deaths = {}
		for _, e in ipairs(recorder.events) do if e.name == "death" then table.insert(deaths, e.f.cause) end end
		equal(table.concat(deaths, ","), "silueta,other,other")
	end)
	case("a finished capture logs capture_end, and a granted one also the first gain and capture", function()
		local analytics, recorder = setup()
		analytics:join(1)
		assert(analytics:capture(1, "Struck", "territory", 3.2, false))
		equal(names(recorder.events), "session_join,capture_end")
		equal(recorder.events[2].f.band, "under4")
		assert(analytics:capture(1, "Completed", "fog", 8, true))
		equal(names(recorder.events), "session_join,capture_end,capture_end,trip_open,first_gain,first_capture")
		equal(recorder.events[3].f.band, "4to8")
		equal(recorder.events[6].f.zone, "fog")
		analytics:capture(1, "Completed", "fog", 8.1, false)
		equal(recorder.events[#recorder.events].f.band, "over8")
	end)
	case("a capture with an unknown reason, zone or time is rejected", function()
		local analytics, recorder = setup()
		analytics:join(1)
		equal(analytics:capture(1, "Won", "fog", 5, false), false)
		equal(analytics:capture(1, "Completed", "Safe", 5, false), false)
		equal(analytics:capture(1, "Completed", "fog", 0 / 0, false), false)
		equal(analytics:capture(1, "Completed", "fog", math.huge, false), false)
		equal(analytics:capture(1, "Completed", "fog", "5", false), false)
		equal(#recorder.events, 1)
		equal(Analytics.ZONE_OF_TIER.Safe, "outside")
		equal(Analytics.ZONE_OF_TIER.Territory, "territory")
	end)
	case("crafting logs first_craft once and a spent event each time; unknown recipes are rejected", function()
		local analytics, recorder = setup()
		analytics:join(1)
		assert(analytics:crafted(1, "seal"))
		assert(analytics:crafted(1, "capsule"))
		equal(names(recorder.events), "session_join,first_craft,spent,spent")
		equal(recorder.events[2].f.recipe, "seal")
		equal(analytics:crafted(1, "sword"), false)
		equal(analytics:crafted(1, nil), false)
		equal(#recorder.events, 4)
	end)
	case("spent accepts only the sink list", function()
		local analytics, recorder = setup()
		analytics:join(1)
		assert(analytics:spent(1, "upgrade"))
		assert(analytics:spent(1, "skill"))
		assert(analytics:spent(1, "capsule"))
		equal(analytics:spent(1, "totem"), false)
		equal(analytics:spent(1, nil), false)
		equal(#recorder.events, 4)
	end)
	case("leaving ends an open trip as left, then logs session_end with its bands", function()
		local analytics, recorder, clock = setup()
		analytics:join(1)
		analytics:observeCamp(1, true)
		clock.t += 400
		assert(analytics:leave(1))
		equal(names(recorder.events), "session_join,trip_open,trip_end,session_end")
		equal(recorder.events[3].f.outcome, "left")
		local last = recorder.events[4]
		equal(last.f.band, "5to15")
		equal(last.f.trips, "1")
		equal(last.f.ended, "left")
		equal(analytics:leave(1), false)
		equal(analytics:observeCamp(1, true), false)
	end)
	case("session length bands break at 1, 5, 15 and 30 minutes", function()
		local function band(seconds)
			local analytics, recorder, clock = setup()
			analytics:join(1)
			clock.t += seconds
			analytics:leave(1)
			return recorder.events[#recorder.events].f.band, recorder.events[#recorder.events].f.trips
		end
		equal(band(59), "under1")
		equal(band(60), "1to5")
		equal(band(299), "1to5")
		equal(band(300), "5to15")
		equal(band(900), "15to30")
		equal(band(1800), "over30")
		local _, trips = band(0)
		equal(trips, "0")
	end)
	case("closing the server ends every session as closed", function()
		local analytics, recorder = setup()
		analytics:join(1)
		analytics:join(2)
		assert(analytics:closeAll())
		local closed = 0
		for _, e in ipairs(recorder.events) do if e.name == "session_end" and e.f.ended == "closed" then closed += 1 end end
		equal(closed, 2)
		equal(analytics:closeAll(), false)
	end)

	-- the client path ------------------------------------------------------------------------------------------
	case("a client can only ask for the three client events, once, with no fields (AN-3)", function()
		local analytics, recorder = setup()
		analytics:join(1)
		assert(analytics:fromClient(1, "start_play"))
		assert(analytics:fromClient(1, "tutorial_skip"))
		equal(analytics:fromClient(1, "start_play"), false)
		equal(#recorder.events, 3)
		local forged = { "first_extract", "session_end", "death", "spent", "trip_open", "", "start_play ", "nope",
			{}, 5, true, string.rep("a", 9000) }
		for _, name in ipairs(forged) do equal(analytics:fromClient(1, name), false) end
		equal(analytics:fromClient(1, nil), false)
		equal(#recorder.events, 3)
		equal(analytics.counters.rejectedClient, #forged + 1)
	end)

	-- limits ---------------------------------------------------------------------------------------------------
	case("repeatable events are rate limited per player and refill with time", function()
		local analytics, recorder, clock = setup()
		analytics:join(1)
		analytics:join(2)
		for _ = 1, 40 do analytics:spent(1, "upgrade") end
		equal(#recorder.events, 2 + Analytics.RATE_CAPACITY)
		equal(analytics.counters.droppedRate, 40 - Analytics.RATE_CAPACITY)
		assert(analytics:spent(2, "upgrade"), "another player has their own bucket")
		clock.t += Analytics.RATE_SECONDS
		assert(analytics:spent(1, "upgrade"), "one token came back")
		equal(analytics:spent(1, "upgrade"), false)
	end)
	case("one-time events and session_end are not rate limited", function()
		local analytics, recorder, clock = setup()
		analytics:join(1)
		for _ = 1, 40 do analytics:spent(1, "upgrade") end
		assert(analytics:extracted(1))
		assert(analytics:leave(1))
		local tail = recorder.events[#recorder.events]
		equal(tail.name, "session_end")
		equal(recorder.events[#recorder.events - 1].name, "first_extract")
		assert(clock.t > 0)
	end)
	case("a session is capped and still gets its session_end", function()
		local analytics, recorder, clock = setup()
		analytics:join(1)
		for _ = 1, 400 do
			clock.t += Analytics.RATE_SECONDS
			analytics:spent(1, "upgrade")
		end
		equal(#recorder.events, Analytics.MAX_EVENTS - 1)
		assert(analytics.counters.droppedCap > 0, "cap counted")
		assert(analytics:leave(1))
		equal(#recorder.events, Analytics.MAX_EVENTS)
		equal(recorder.events[#recorder.events].name, "session_end")
	end)
	case("the number of sessions is capped", function()
		local analytics = setup()
		for key = 1, Analytics.MAX_SESSIONS do assert(analytics:join(key)) end
		equal(analytics:join(Analytics.MAX_SESSIONS + 1), false)
		equal(analytics.counters.droppedSessions, 1)
		assert(analytics:leave(1))
		assert(analytics:join(Analytics.MAX_SESSIONS + 1), "a freed slot is reusable")
	end)
	case("a call that logs nothing keeps no new state", function()
		local analytics, recorder = setup()
		analytics:join(1)
		analytics:observeCamp(1, true)
		local before = #recorder.events
		for _ = 1, 1000 do
			analytics:observeCamp(1, true)
			analytics:observeCamp(1, false)
			analytics:gain(1, "nope", "fog")
		end
		equal(#recorder.events, before)
	end)

	-- sink faults (AN-5) ---------------------------------------------------------------------------------------
	case("a sink that throws never throws into the game, and errors are counted", function()
		local failing = { write = function() error("sink down") end }
		local analytics = Analytics.new({ sink = failing, clock = function() return 0 end, tag = "bb" })
		assert(analytics:join(1))
		assert(analytics:gain(1, "pickup"))
		assert(analytics:extracted(1))
		assert(analytics:leave(1))
		assert(analytics.counters.sinkErrors >= 5, "errors counted")
		equal(analytics.counters.sent, 0)
	end)
	case("after enough consecutive sink errors the sink is cut off; one success resets the count", function()
		local fail = true
		local sink = { written = 0, write = function(self) if fail then error("down") end self.written += 1 end }
		local analytics, _, clock = setup({ sink = sink })
		analytics:join(1)
		for _ = 1, Analytics.SINK_TRIP - 2 do
			clock.t += 3
			analytics:spent(1, "upgrade")
		end
		fail = false
		clock.t += 3
		analytics:spent(1, "upgrade")
		equal(analytics.tripped, false)
		fail = true
		for _ = 1, Analytics.SINK_TRIP + 3 do
			clock.t += 3
			analytics:spent(1, "upgrade")
		end
		equal(analytics.tripped, true)
		assert(analytics.counters.droppedSink >= 3, "later events dropped")
		fail = false
		clock.t += 3
		analytics:spent(1, "upgrade")
		equal(sink.written, 1, "a cut-off sink stays off")
	end)
	case("new needs a sink with write", function()
		assert(not pcall(Analytics.new, nil))
		assert(not pcall(Analytics.new, {}))
		assert(not pcall(Analytics.new, { sink = {} }))
	end)

	-- the off switch (AN-7) ------------------------------------------------------------------------------------
	case("the disabled object has every method, logs nothing and says it is off", function()
		local off = Analytics.disabled()
		equal(off.enabled, false)
		equal(off.mode, "off")
		assert(table.isfrozen(off), "frozen")
		for _, method in ipairs(Analytics.METHODS) do
			assert(type(off[method]) == "function", method)
			equal(off[method](off, 1, "x", "y", 1, true), false)
		end
		for _, name in ipairs(Analytics.COUNTERS) do equal(off.counters[name], 0) end
		-- every public method of a real object is in METHODS, so the two cannot drift apart
		for name, value in pairs(Analytics) do
			if type(value) == "function" and name:match("^[a-z]") and not table.find({ "new", "disabled", "fromMode",
				"recorder", "lines", "validate" }, name) then
				assert(table.find(Analytics.METHODS, name), name .. " missing from METHODS")
			end
		end
	end)
	case("only the record mode turns the seam on; anything else is off", function()
		for _, mode in ipairs({ "off", "", "on", "RECORD", "verbose", 5, true }) do
			local analytics, recorder = Analytics.fromMode(mode)
			equal(analytics.enabled, false)
			equal(recorder, nil)
		end
		local analytics, recorder = Analytics.fromMode(nil)
		equal(analytics.enabled, false)
		local live, store = Analytics.fromMode("record", { clock = function() return 0 end })
		equal(live.enabled, true)
		equal(live.mode, "record")
		assert(live:join(1))
		equal(#store.events, 1)
		assert(recorder == nil)
	end)
	case("the recorder keeps the earliest events and counts what did not fit", function()
		local recorder = Analytics.recorder(3)
		for index = 1, 5 do recorder:write({ index = index }) end
		equal(#recorder.events, 3)
		equal(recorder.events[3].index, 3)
		equal(recorder.overflow, 2)
	end)
	case("lines uses the caller's encoder", function()
		local analytics, recorder = setup()
		analytics:join(1)
		local out = Analytics.lines(recorder.events, function(e) return e.name .. "|" .. e.sid end)
		equal(out[1], "session_join|aaaaaaaaaaaa-1")
	end)
	case("the module names no external service and no player identity (AN-7)", function()
		local source = sources.analytics
		for _, word in ipairs({ "AnalyticsService", "HttpService", "DataStoreService", "MarketplaceService",
			"MessagingService", "DisplayName", "UserId", "GetService", "Players", "TeleportService" }) do
			assert(not source:find(word, 1, true), "source mentions " .. word)
		end
	end)

	return result
end

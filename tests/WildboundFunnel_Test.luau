-- Invoke with require(freshTestClone)(require(freshFunnelClone), require(freshAnalyticsClone)).
-- The funnel reducer of W16 (F2 analysis): step counts and conversion from a list of recorded events, per-trip counts,
-- a session summary and the Wilson interval from docs/testing/wildbound-f2-plan.md section 4. The same fixture and the
-- same expected numbers appear in tools/test_analytics_funnel.py, so the Luau and Python readers cannot drift apart.
return function(Funnel, Analytics)
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
	local function near(actual, expected, label)
		assert(type(actual) == "number" and math.abs(actual - expected) < 1e-9, (label and label .. ": " or "")
			.. "Expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end

	local function ev(sid, seq, name, f)
		return { v = 1, name = name, sid = sid, seq = seq, t = seq, f = f or {} }
	end
	-- A finishes three trips' worth of play; B captures and falls; C only joins; D logs a gain before leaving camp;
	-- F lost its join. Five sessions in all.
	local function fixture()
		return {
			ev("A", 1, "session_join"), ev("A", 2, "trip_open", { n = "1" }), ev("A", 3, "first_gain", { source = "gather" }),
			ev("A", 4, "first_gather", { zone = "fog" }), ev("A", 5, "first_extract"),
			ev("A", 6, "trip_end", { outcome = "extracted", band = "3to8", gained = "yes" }),
			ev("A", 7, "trip_open", { n = "2" }), ev("A", 8, "strike"), ev("A", 9, "death", { cause = "silueta" }),
			ev("A", 10, "trip_end", { outcome = "defeated", band = "under3", gained = "no" }),
			ev("A", 11, "trip_open", { n = "3" }),
			ev("A", 12, "trip_end", { outcome = "left", band = "under3", gained = "no" }),
			ev("A", 13, "session_end", { band = "5to15", trips = "3", ended = "left" }),
			ev("B", 1, "session_join"), ev("B", 2, "trip_open", { n = "1" }), ev("B", 3, "first_gain", { source = "capture" }),
			ev("B", 4, "first_capture", { zone = "territory" }),
			ev("B", 5, "capture_end", { zone = "territory", reason = "Completed", band = "4to8" }),
			ev("B", 6, "death", { cause = "other" }),
			ev("B", 7, "trip_end", { outcome = "defeated", band = "3to8", gained = "yes" }),
			ev("B", 8, "session_end", { band = "1to5", trips = "1", ended = "left" }),
			ev("C", 1, "session_join"), ev("C", 2, "session_end", { band = "under1", trips = "0", ended = "closed" }),
			ev("D", 1, "session_join"), ev("D", 2, "first_gain", { source = "pickup" }), ev("D", 3, "trip_open", { n = "1" }),
			ev("F", 1, "trip_open", { n = "1" }),
		}
	end
	local function junk()
		return { { v = 2, name = "session_join", sid = "X", seq = 1, f = {} }, { v = 1, name = "session_join", seq = 1, f = {} },
			{ v = 1, name = "session_join", sid = "X", seq = "1", f = {} }, "text", { v = 1, name = 5, sid = "X", seq = 1, f = {} },
			{ v = 1, name = "session_join", sid = "X", seq = 0, f = {} }, { v = 1, name = "session_join", sid = "X", seq = 1.5, f = {} } }
	end

	case("the step list matches the analytics vocabulary", function()
		assert(table.isfrozen(Funnel.FIRST_STEPS), "frozen")
		equal(#Funnel.FIRST_STEPS, 6)
		for _, step in ipairs(Funnel.FIRST_STEPS) do
			local def = Analytics.EVENTS[step.name]
			assert(def, step.name .. " is not an analytics event")
			for field, values in pairs(step.where or {}) do
				assert(def.fields[field], step.name .. " has no field " .. field)
				for _, value in ipairs(values) do
					assert(table.find(def.fields[field], value), step.name .. "." .. field .. " value " .. value)
				end
			end
		end
	end)
	case("step counts and conversion for the fixture", function()
		local r = Funnel.reduce(fixture())
		equal(r.sessions, 5)
		equal(r.invalid, 0)
		equal(r.duplicates, 0)
		local want = { 4, 3, 2, 1, 1, 1 }
		local names = { "Joined", "LeftCamp", "FirstGain", "FirstExtract", "SecondTrip", "ThirdTrip" }
		for index, reached in ipairs(want) do
			equal(r.steps[index].reached, reached, "reached " .. index)
			equal(r.steps[index].step, names[index])
			equal(r.steps[index].index, index)
			near(r.steps[index].ofStart, reached / 4, "ofStart " .. index)
		end
		near(r.steps[2].ofPrev, 0.75)
		near(r.steps[3].ofPrev, 2 / 3)
		near(r.steps[4].ofPrev, 0.5)
		near(r.steps[5].ofPrev, 1)
		equal(r.steps[1].ofPrev, nil)
		equal(r.steps[3].lost, 1)
		equal(r.steps[2].lost, 1)
	end)
	case("steps count only in order, so a gain before leaving camp does not count (AN-2)", function()
		local r = Funnel.reduce({ ev("D", 1, "session_join"), ev("D", 2, "first_gain", { source = "pickup" }),
			ev("D", 3, "trip_open", { n = "1" }) })
		equal(r.steps[2].reached, 1)
		equal(r.steps[3].reached, 0)
		local ordered = Funnel.reduce({ ev("D", 3, "trip_open", { n = "1" }), ev("D", 1, "session_join"),
			ev("D", 2, "first_gain", { source = "pickup" }) })
		equal(ordered.steps[3].reached, 0, "events are sorted by seq first")
	end)
	case("one event moves a session at most one step", function()
		local r = Funnel.reduce({ ev("A", 1, "session_join"), ev("A", 2, "trip_open", { n = "3" }) })
		equal(r.steps[2].reached, 1)
		equal(r.steps[5].reached, 0, "the same trip_open cannot also be the second trip")
	end)
	case("the second trip must come after the first extraction", function()
		local lines = { ev("A", 1, "session_join"), ev("A", 2, "trip_open", { n = "1" }), ev("A", 3, "first_gain", { source = "pickup" }),
			ev("A", 4, "trip_open", { n = "2" }), ev("A", 5, "first_extract") }
		local r = Funnel.reduce(lines)
		equal(r.steps[4].reached, 1)
		equal(r.steps[5].reached, 0, "trip 2 opened before the extraction")
	end)
	case("replayed lines and unusable lines are counted, not used", function()
		local doubled = fixture()
		for _, e in ipairs(fixture()) do table.insert(doubled, e) end
		for _, e in ipairs(junk()) do table.insert(doubled, e) end
		local r = Funnel.reduce(doubled)
		equal(r.sessions, 5)
		equal(r.invalid, 7)
		equal(r.duplicates, #fixture())
		equal(r.steps[1].reached, 4)
		equal(r.steps[6].reached, 1)
	end)
	case("an empty log reduces to zeros without dividing by zero", function()
		local r = Funnel.reduce({})
		equal(r.sessions, 0)
		equal(r.steps[1].reached, 0)
		equal(r.steps[1].ofStart, nil)
		equal(r.steps[2].ofPrev, nil)
		local s = Funnel.summary({})
		equal(s.trips.opened, 0)
	end)
	case("custom steps work and reject nothing silently", function()
		local steps = { { step = "A", name = "session_join" }, { step = "B", name = "death", where = { cause = { "silueta" } } } }
		local r = Funnel.reduce(fixture(), steps)
		equal(r.steps[1].reached, 4)
		equal(r.steps[2].reached, 1)
	end)
	case("trips count opens, ends, outcomes, gains and lengths", function()
		local t = Funnel.trips(fixture())
		equal(t.opened, 6)
		equal(t.ended, 4)
		equal(t.outcomes.extracted, 1)
		equal(t.outcomes.defeated, 2)
		equal(t.outcomes.left, 1)
		equal(t.gained, 2)
		equal(t.bands.under3, 2)
		equal(t.bands["3to8"], 2)
		equal(t.bands.over8 or 0, 0)
		near(t.extractedOfEnded, 0.25)
		near(t.gainedOfEnded, 0.5)
	end)
	case("the summary adds session ends, deaths and captures", function()
		local s = Funnel.summary(fixture())
		equal(s.sessions, 5)
		equal(s.firstSteps.steps[6].reached, 1)
		equal(s.sessionEnds.count, 3)
		equal(s.sessionEnds.bands["5to15"], 1)
		equal(s.sessionEnds.bands["1to5"], 1)
		equal(s.sessionEnds.bands.under1, 1)
		equal(s.sessionEnds.trips["3"], 1)
		equal(s.sessionEnds.trips["0"], 1)
		equal(s.sessionEnds.ended.left, 2)
		equal(s.sessionEnds.ended.closed, 1)
		equal(s.deaths.silueta, 1)
		equal(s.deaths.other, 1)
		equal(s.captures.ended, 1)
		equal(s.captures.reasons.Completed, 1)
	end)
	case("a stream recorded by the analytics module reduces as expected", function()
		local clock = { t = 0 }
		local analytics, recorder = Analytics.fromMode("record", { clock = function() return clock.t end, tag = "t" })
		for key = 1, 3 do analytics:join(key) end
		analytics:gain(1, "gather", "fog")
		clock.t += 200
		analytics:extracted(1)
		analytics:observeCamp(1, true)
		analytics:observeCamp(2, true)
		analytics:noteStrike(2)
		analytics:death(2)
		analytics:leave(3)
		local r = Funnel.reduce(recorder.events)
		equal(r.sessions, 3)
		equal(r.steps[1].reached, 3)
		equal(r.steps[2].reached, 2)
		equal(r.steps[3].reached, 1)
		equal(r.steps[4].reached, 1)
		equal(r.steps[5].reached, 1)
		local t = Funnel.trips(recorder.events)
		equal(t.opened, 3)
		equal(t.outcomes.extracted, 1)
		equal(t.outcomes.defeated, 1)
		equal(Funnel.summary(recorder.events).deaths.silueta, 1)
	end)
	case("the Wilson interval matches the plan's formula", function()
		equal(Funnel.wilson(0, 0), nil)
		equal(Funnel.wilson(-1, 5), nil)
		equal(Funnel.wilson(6, 5), nil)
		equal(Funnel.wilson(1.5, 5), nil)
		local w = Funnel.wilson(5, 10)
		near(w.center, 0.5)
		assert(math.abs(w.low - 0.2366) < 5e-4, "low " .. w.low)
		assert(math.abs(w.high - 0.7634) < 5e-4, "high " .. w.high)
		local zero = Funnel.wilson(0, 10)
		near(zero.low, 0)
		assert(math.abs(zero.high - 0.2775) < 5e-4, "high " .. zero.high)
		local all = Funnel.wilson(10, 10)
		near(all.high, 1)
		assert(all.low > 0.72 and all.low < 0.725, "low " .. all.low)
		equal(w.k, 5)
		equal(w.n, 10)
	end)

	return result
end

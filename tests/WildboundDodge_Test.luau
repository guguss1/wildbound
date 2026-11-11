-- Invoke with require(freshTestClone)(require(freshDodgeClone), freshDodgeClone.Source).
-- Esquiva perfecta (decision Q3b, docs/mechanics/wildbound-new-mechanics.md section 2): it replaces the Burst. A press
-- inside the perfect window at the end of an attack's telegraph (a parent's swing, Viper's dash, Pouncer's leap, La
-- Silueta's lunge) cancels that hit and grants a short speed boost. An early or late press does nothing and starts a
-- cooldown; a flood of presses locks the dodge out. Telegraphs stay at least 0.8 s long.
return function(Dodge, source)
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
	local function near(actual, expected, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= 1e-6,
			(label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local CALM = { blocked = false }

	case("D1: the defaults: a 0.35 s window at the end of a telegraph of at least 0.8 s, a 1 s boost, cooldowns", function()
		local C = Dodge.CONSTANTS
		assert(type(C) == "table", "CONSTANTS")
		equal(C.WINDOW, 0.35); equal(C.BOOST_SECONDS, 1); equal(C.BOOST_MULTIPLIER, 1.35); equal(C.BOOST_CAP, 26)
		equal(C.MISS_COOLDOWN, 1.2); equal(C.SUCCESS_COOLDOWN, 0.6)
		equal(C.SPAM_LIMIT, 4); equal(C.SPAM_SECONDS, 1); equal(C.SPAM_LOCKOUT, 2)
		equal(Dodge.MIN_TELEGRAPH, 0.8, "the fair-strike floor")
		for _, name in ipairs({ "Parent", "Viper", "Pouncer", "Silueta" }) do
			equal(Dodge.SOURCES[name], true, name .. " can be dodged")
		end
		equal(Dodge.live.WINDOW, 0.35, "live starts at the defaults")
	end)

	case("D2: a telegraph shorter than 0.8 s is refused; 0.8 s exactly is fine; ids are unique", function()
		local state = Dodge.new()
		equal(select(2, Dodge.telegraph(state, "a1", "Viper", 10, 10.79)), "ShortTelegraph")
		equal(Dodge.telegraph(state, "a1", "Parent", 10, 10.8), true, "0.8 s is the floor")
		equal(select(2, Dodge.telegraph(state, "a1", "Viper", 11, 12.2)), "Duplicate")
		equal(select(2, Dodge.telegraph(state, "a2", "Dragon", 11, 12.2)), "BadSource")
		equal(select(2, Dodge.telegraph(state, "a3", "Viper", 0 / 0, 12.2)), "BadClock")
		equal(select(2, Dodge.telegraph(state, nil, "Viper", 11, 12.2)), "BadId")
		equal(select(2, Dodge.telegraph(nil, "a4", "Viper", 11, 12.2)), "Invalid")
	end)

	case("D3: a press inside the window cancels the hit and grants the boost", function()
		local state = Dodge.new()
		Dodge.telegraph(state, "v1", "Viper", 100, 101.15)
		local outcome, info = Dodge.press(state, 101.0, CALM)
		equal(outcome, "Perfect")
		assert(type(info) == "table" and info.dodged[1] == "v1", "the dodged attack is named")
		near(info.boostUntil, 101.0 + Dodge.CONSTANTS.BOOST_SECONDS, "boost end")
		equal(Dodge.resolve(state, "v1", 101.15), "Dodged", "the server cancels the hit")
		equal(Dodge.resolve(state, "v1", 101.15), "Unknown", "an attack resolves once")
		equal(Dodge.boosting(state, 101.5), true)
		near(Dodge.speed(state, 16, 101.5), 16 * 1.35, "boosted walk")
		equal(Dodge.boosting(state, 102.01), false, "the boost ends")
		equal(Dodge.speed(state, 16, 102.01), 16)
	end)

	case("D4: an early press does nothing, starts the cooldown, and the real window then finds it cooling", function()
		local state = Dodge.new()
		Dodge.telegraph(state, "p1", "Pouncer", 50, 51.3)
		equal(Dodge.press(state, 50.2, CALM), "Early")
		equal(Dodge.boosting(state, 50.3), false, "no boost for a miss")
		equal(Dodge.press(state, 51.2, CALM), "Cooldown", "1.2 s cooldown from 50.2")
		equal(Dodge.resolve(state, "p1", 51.3), "Hit", "the leap lands")
	end)

	case("D5: a press after the strike is late; after the cooldown it works again", function()
		local state = Dodge.new()
		Dodge.telegraph(state, "s1", "Silueta", 20, 20.9)
		equal(Dodge.resolve(state, "s1", 20.9), "Hit")
		equal(Dodge.press(state, 21.0, CALM), "Late")
		equal(Dodge.press(state, 21.5, CALM), "Cooldown")
		Dodge.telegraph(state, "s2", "Silueta", 22.3, 23.2)
		equal(Dodge.press(state, 23.0, CALM), "Perfect", "the cooldown is over")
	end)

	case("D6: a press with no attack is a whiff and also cools down (no free spamming between attacks)", function()
		local state = Dodge.new()
		equal(Dodge.press(state, 5, CALM), "Whiff")
		equal(Dodge.press(state, 5.5, CALM), "Cooldown")
		equal(Dodge.press(state, 6.3, CALM), "Whiff", "after 1.2 s")
	end)

	case("D7: a flood of presses locks the dodge out even through a real window", function()
		local state = Dodge.new()
		Dodge.telegraph(state, "v2", "Viper", 10, 11.15)
		local last
		for i = 1, 6 do last = Dodge.press(state, 10 + i * 0.05, CALM) end
		equal(last, "Spam")
		equal(Dodge.press(state, 11.0, CALM), "Spam", "locked for SPAM_LOCKOUT")
		equal(Dodge.resolve(state, "v2", 11.15), "Hit")
	end)

	case("D8: overlapping attacks: the press dodges only the one in its window", function()
		local state = Dodge.new()
		Dodge.telegraph(state, "near", "Parent", 10, 10.8)
		Dodge.telegraph(state, "far", "Viper", 10.2, 11.6)
		local outcome, info = Dodge.press(state, 10.7, CALM)
		equal(outcome, "Perfect"); equal(#info.dodged, 1); equal(info.dodged[1], "near")
		equal(Dodge.resolve(state, "near", 10.8), "Dodged")
		equal(Dodge.resolve(state, "far", 11.6), "Hit", "a perfect dodge is not a shield")
	end)

	case("D9: a blocked player (hidden, capturing, ragdolled, dead) cannot dodge and keeps no cooldown", function()
		local state = Dodge.new()
		Dodge.telegraph(state, "v3", "Viper", 10, 11.15)
		equal(Dodge.press(state, 11.0, { blocked = true }), "Blocked")
		equal(Dodge.press(state, 11.05, CALM), "Perfect", "the refused press spent nothing")
		equal(Dodge.press(state, 11.1, nil), "Cooldown", "no context counts as not blocked")
	end)

	case("D10: the window always lies inside the telegraph and never covers more than half of the shortest one", function()
		Dodge.tune({ WINDOW = 5 })
		assert(Dodge.live.WINDOW <= Dodge.MIN_TELEGRAPH / 2 + 1e-9, "the window is clamped")
		local state = Dodge.new()
		Dodge.telegraph(state, "x", "Parent", 10, 10.8)
		equal(Dodge.press(state, 10.39, CALM), "Early", "before the clamped window")
		Dodge.tune(nil)
		local open, close = Dodge.window(10, 11.15)
		near(open, 11.15 - 0.35, "opens WINDOW before the strike"); near(close, 11.15, "closes at the strike")
	end)

	case("D11: the boost never slows and never passes its cap", function()
		local state = Dodge.new()
		Dodge.telegraph(state, "v4", "Viper", 0, 1.15)
		Dodge.press(state, 1.0, CALM)
		equal(Dodge.speed(state, 23.2, 1.2), 26, "a sprint is capped at BOOST_CAP")
		equal(Dodge.speed(state, 30, 1.2), 30, "never slower than the given speed")
		equal(Dodge.speed(state, 0 / 0, 1.2), 0, "a bad speed is 0")
	end)

	case("D12: tune() clamps the values; the telegraph floor can rise but never drop below 0.8 s", function()
		Dodge.tune({ BOOST_MULTIPLIER = 9, BOOST_SECONDS = 99, MISS_COOLDOWN = 0, MIN_TELEGRAPH = 0.2, bogus = 1 })
		assert(Dodge.live.BOOST_MULTIPLIER <= 1.6, "boost multiplier clamped")
		assert(Dodge.live.BOOST_SECONDS <= 2, "boost seconds clamped")
		assert(Dodge.live.MISS_COOLDOWN >= 0.5, "a miss always cools down")
		equal(Dodge.live.MIN_TELEGRAPH, 0.8, "never below the fair-strike floor")
		Dodge.tune({ MIN_TELEGRAPH = 1.0 })
		equal(Dodge.live.MIN_TELEGRAPH, 1.0, "it may rise")
		local state = Dodge.new()
		equal(select(2, Dodge.telegraph(state, "a", "Parent", 0, 0.9)), "ShortTelegraph")
		Dodge.tune(nil)
		equal(Dodge.live.MIN_TELEGRAPH, 0.8)
		assert(Dodge.tunable().WINDOW == 0.35, "flat rows for the dev tuning schema")
	end)

	case("D13: cancel, prune and the player strings; the module is pure", function()
		local state = Dodge.new()
		Dodge.telegraph(state, "c1", "Viper", 0, 1.15)
		equal(Dodge.cancel(state, "c1"), true, "a fair-strike cancel drops the attack")
		equal(Dodge.resolve(state, "c1", 1.15), "Unknown")
		Dodge.telegraph(state, "c2", "Viper", 0, 1.15)
		Dodge.prune(state, 10)
		equal(state.attacks.c2, nil, "an attack the server never resolved is pruned")
		for _, key in ipairs({ "cue", "perfect", "early", "late" }) do
			assert(type(Dodge.TEXT[key]) == "string" and #Dodge.TEXT[key] > 0, "text " .. key)
		end
		assert(type(source) == "string", "source")
		for _, needle in ipairs({ "GetService", "os.time", "os.clock", "math.random", "tick()", "workspace" }) do
			assert(not source:find(needle, 1, true), "source has " .. needle)
		end
	end)

	return result
end

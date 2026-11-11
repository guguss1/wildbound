-- Invoke with require(freshTestClone)(require(freshDuskClone), freshDuskClone.Source, require(freshWorldRulesClone)).
-- Dusk (decision Q11, docs/mechanics/wildbound-new-mechanics.md section 5): the pre-night stage. The day cycle already
-- has a 72 s Dusk phase (WildboundWorldRules.cycle); this rule turns it into a warning (once when Dusk starts, once more
-- shortly before Night) and a small, tunable beast buff that holds only during Dusk.
return function(Dusk, source, Rules)
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
	local function cycle(phase, remaining) return { phase = phase, remaining = remaining, progress = 0 } end

	case("U1: the defaults: a small buff and a second warning 20 s before Night", function()
		local C = Dusk.CONSTANTS
		assert(type(C) == "table", "CONSTANTS")
		equal(C.SPEED_MULTIPLIER, 1.08); equal(C.ROLL_MULTIPLIER, 1.25); equal(C.DETECTION_MULTIPLIER, 1.1)
		equal(C.NIGHT_SOON, 20)
		equal(Dusk.PHASE, "Dusk")
		equal(Dusk.live.ROLL_MULTIPLIER, 1.25, "live starts at the defaults")
	end)

	case("U2: entering Dusk warns once; the buff holds only during Dusk", function()
		local state = Dusk.new()
		local day = Dusk.step(state, cycle("Day", 5))
		equal(day.enteredDusk, false); equal(day.buff.roll, 1); equal(day.buff.speed, 1); equal(day.buff.detection, 1)
		local first = Dusk.step(state, cycle("Dusk", 72))
		equal(first.enteredDusk, true, "the warning")
		equal(first.buff.roll, 1.25); equal(first.buff.speed, 1.08); equal(first.buff.detection, 1.1)
		equal(Dusk.step(state, cycle("Dusk", 60)).enteredDusk, false, "once per dusk")
		local night = Dusk.step(state, cycle("Night", 216))
		equal(night.buff.roll, 1, "Night keeps its own multipliers; the dusk buff never stacks")
	end)

	case("U3: the second warning fires once when NIGHT_SOON seconds of Dusk remain", function()
		local state = Dusk.new()
		Dusk.step(state, cycle("Dusk", 72))
		equal(Dusk.step(state, cycle("Dusk", 21)).nightSoon, false)
		local soon = Dusk.step(state, cycle("Dusk", 19.9))
		equal(soon.nightSoon, true); equal(soon.seconds, 20, "rounded up for the line")
		equal(Dusk.step(state, cycle("Dusk", 10)).nightSoon, false, "once")
	end)

	case("U4: the next dusk warns again; a server that starts inside Dusk warns at once", function()
		local state = Dusk.new()
		Dusk.step(state, cycle("Dusk", 72)); Dusk.step(state, cycle("Dusk", 10))
		Dusk.step(state, cycle("Night", 200)); Dusk.step(state, cycle("Dawn", 70)); Dusk.step(state, cycle("Day", 360))
		local again = Dusk.step(state, cycle("Dusk", 72))
		equal(again.enteredDusk, true, "every dusk warns")
		equal(Dusk.step(state, cycle("Dusk", 15)).nightSoon, true, "and its second warning too")
		local late = Dusk.new()
		local out = Dusk.step(late, cycle("Dusk", 30))
		equal(out.enteredDusk, true, "joined mid-dusk")
		equal(Dusk.step(late, cycle("Dusk", 29)).nightSoon, false)
		local veryLate = Dusk.new()
		local both = Dusk.step(veryLate, cycle("Dusk", 5))
		equal(both.enteredDusk, true); equal(both.nightSoon, false, "too late for a second line: the first says it all")
	end)

	case("U5: bad input is no dusk, no warning", function()
		local state = Dusk.new()
		local out = Dusk.step(state, nil)
		equal(out.enteredDusk, false); equal(out.buff.roll, 1)
		equal(Dusk.step(state, { phase = "Dusk", remaining = 0 / 0 }).nightSoon, false)
		equal(Dusk.step(nil, cycle("Dusk", 50)).enteredDusk, false)
	end)

	case("U6: tune() keeps the buff small: never a slowdown and always under the night multiplier", function()
		Dusk.tune({ SPEED_MULTIPLIER = 3, ROLL_MULTIPLIER = 0.2, DETECTION_MULTIPLIER = 9, NIGHT_SOON = 500, bogus = 1 })
		assert(Dusk.live.SPEED_MULTIPLIER <= 1.15, "speed capped")
		assert(Dusk.live.ROLL_MULTIPLIER >= 1, "never weaker than day")
		assert(Dusk.live.DETECTION_MULTIPLIER <= 1.25, "detection capped")
		assert(Dusk.live.NIGHT_SOON <= 60, "the second warning stays inside the 72 s dusk")
		Dusk.tune(nil)
		equal(Dusk.live.SPEED_MULTIPLIER, 1.08)
		equal(Dusk.tunable().NIGHT_SOON, 20, "flat rows for the dev tuning schema")
	end)

	case("U7: the player lines", function()
		equal(Dusk.message("dusk"), Dusk.TEXT.dusk)
		equal(Dusk.message("soon", 20), "La noche llega en 20 s.")
		equal(Dusk.message("nope"), nil)
	end)

	case("U8: it matches the day cycle: WorldRules names Dusk and gives it longer than NIGHT_SOON", function()
		if type(Rules) ~= "table" or type(Rules.cycle) ~= "function" then error("WorldRules was not passed") end
		local at = Rules.cycle(360 + 1)
		equal(at.phase, Dusk.PHASE)
		assert(at.remaining > Dusk.CONSTANTS.NIGHT_SOON, "a full dusk holds both warnings")
	end)

	case("U9: the module is pure", function()
		assert(type(source) == "string", "source")
		for _, needle in ipairs({ "GetService", "os.time", "os.clock", "math.random", "tick()", "workspace" }) do
			assert(not source:find(needle, 1, true), "source has " .. needle)
		end
	end)

	return result
end

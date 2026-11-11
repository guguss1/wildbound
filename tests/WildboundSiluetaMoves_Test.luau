-- Invoke with require(freshTestClone)(require(freshMovesClone), freshMovesClone.Source).
-- Fix pass (FP4): La Silueta's extra moves as pure rules, each behind a tuning toggle (default on): the lunge, the fake
-- retreat, the flashlight glare and the chase-start scream's reach. The world wiring is in WildboundSiluetaMovesWiring_Test.
return function(Moves, source)
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
		assert(type(actual) == "number" and math.abs(actual - expected) < 1e-6,
			(label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local C = Moves.CONSTANTS or {}

	case("FP4: the plan's numbers, every move on by default", function()
		equal(C.LUNGE_ON, 1); equal(C.FAKE_ON, 1); equal(C.GLARE_ON, 1); equal(C.SCREAM_ON, 1)
		equal(C.LUNGE_AFTER, 3); equal(C.LUNGE_TELL, 0.5); equal(C.LUNGE_SECONDS, 0.8); equal(C.LUNGE_SPEED, 22)
		equal(C.LUNGE_COOLDOWN, 8)
		equal(C.FAKE_CHANCE, 0.25); equal(C.FAKE_SECONDS, 4)
		equal(C.GLARE_RANGE, 12); equal(C.GLARE_DOT, 0.85); equal(C.GLARE_HOLD, 1.5); equal(C.GLARE_STAGGER, 1)
		equal(C.SCREAM_REACH, 70)
		-- Fair: the tell is above the 0.35 s floor of a readable tell, and a rested sprint (16 x 1.45) still outruns it.
		assert(C.LUNGE_TELL >= 0.35, "a readable tell")
		assert(C.LUNGE_SPEED < 16 * 1.45, "a rested sprinter outruns the lunge")
	end)

	case("FP4a: after 3 s of continuous Hunt a 0.5 s tell, then 0.8 s at 22, then 8 s of cooldown", function()
		Moves.tune(nil)
		local lunge = Moves.newLunge()
		local out = Moves.lungeStep(lunge, 10, "Hunt")
		equal(out.phase, "idle"); equal(out.speed, nil)
		equal(Moves.lungeStep(lunge, 12.9, "Hunt").phase, "idle", "not before 3 s")
		out = Moves.lungeStep(lunge, 13, "Hunt")
		equal(out.phase, "tell"); equal(out.started, true, "the tell starts once"); equal(out.speed, nil, "no burst during the tell")
		near(out.tellEndsAt, 13.5)
		equal(Moves.lungeStep(lunge, 13.2, "Hunt").started, false)
		out = Moves.lungeStep(lunge, 13.5, "Hunt")
		equal(out.phase, "burst"); equal(out.speed, 22)
		equal(Moves.lungeStep(lunge, 14.2, "Hunt").speed, 22)
		out = Moves.lungeStep(lunge, 14.3, "Hunt")
		equal(out.phase, "idle", "0.8 s of burst"); equal(out.speed, nil)
		equal(Moves.lungeStep(lunge, 22.2, "Hunt").phase, "idle", "cooldown 8 s")
		equal(Moves.lungeStep(lunge, 22.3, "Hunt").phase, "tell", "ready again after the cooldown and 3 s of hunt")
	end)

	case("FP4a: never during Telegraph; leaving Hunt cancels the lunge and restarts the 3 s", function()
		Moves.tune(nil)
		local lunge = Moves.newLunge()
		Moves.lungeStep(lunge, 0, "Hunt")
		equal(Moves.lungeStep(lunge, 3, "Hunt").phase, "tell")
		local out = Moves.lungeStep(lunge, 3.2, "Telegraph")
		equal(out.phase, "idle", "a telegraph cancels the tell"); equal(out.speed, nil)
		equal(Moves.lungeStep(lunge, 3.6, "Hunt").phase, "idle", "the hunt counts again from here")
		equal(Moves.lungeStep(lunge, 6.5, "Hunt").phase, "idle")
		equal(Moves.lungeStep(lunge, 6.6, "Hunt").phase, "tell")
		equal(Moves.lungeStep(lunge, 7.1, "Hunt").phase, "burst")
		equal(Moves.lungeStep(lunge, 7.2, "Telegraph").speed, nil, "a telegraph ends the burst")
		for _, mode in ipairs({ "Alert", "Search", "Patrol", "Retreat" }) do
			local other = Moves.newLunge()
			Moves.lungeStep(other, 0, mode)
			equal(Moves.lungeStep(other, 10, mode).phase, "idle", mode)
		end
	end)

	case("FP4a: the toggle turns the lunge off", function()
		Moves.tune({ LUNGE_ON = 0 })
		local lunge = Moves.newLunge()
		Moves.lungeStep(lunge, 0, "Hunt")
		equal(Moves.lungeStep(lunge, 5, "Hunt").phase, "idle")
		Moves.tune(nil)
		equal(Moves.enabled("LUNGE_ON"), true)
	end)

	case("FP4b: a quarter of the searches start with a fake retreat", function()
		Moves.tune(nil)
		equal(Moves.fakeRetreat(0), true); equal(Moves.fakeRetreat(0.2499), true)
		equal(Moves.fakeRetreat(0.25), false); equal(Moves.fakeRetreat(0.9), false)
		equal(Moves.fakeRetreat(0 / 0), false); equal(Moves.fakeRetreat(nil), false)
		Moves.tune({ FAKE_ON = 0 })
		equal(Moves.fakeRetreat(0), false, "toggle off")
		Moves.tune(nil)
	end)

	case("FP4b: walks away from the last known spot for 4 s, then turns back to it at hunt speed", function()
		Moves.tune(nil)
		local fake = Moves.newFake(100, 0, 0) -- last known at the origin
		local out = Moves.fakeStep(fake, 100, 0, 10) -- she stands 10 studs north of it
		equal(out.leg, "away"); equal(out.speed, "search")
		assert(out.destination.z > 10 and math.abs(out.destination.x) < 1e-6, "away from the spot, along spot -> her")
		equal(Moves.fakeStep(fake, 103.9, 0, 25).leg, "away")
		out = Moves.fakeStep(fake, 104, 0, 30)
		equal(out.leg, "back"); equal(out.speed, "hunt")
		equal(out.destination.x, 0); equal(out.destination.z, 0)
		equal(Moves.fakeStep(fake, 106, 0, 2.9).done, true, "arrived")
		-- On the spot itself: any direction, never NaN.
		local still = Moves.fakeStep(Moves.newFake(0, 5, 5), 0, 5, 5)
		assert(still.destination.x == still.destination.x and still.destination.z == still.destination.z, "finite")
	end)

	case("FP4c: a flashlight held on her for 1.5 s at dusk or night staggers her 1 s, once per chase", function()
		Moves.tune(nil)
		local glare = Moves.newGlare()
		local function input(overrides)
			local value = { phase = "Night", distance = 8, dot = 0.95, mode = "Hunt" }
			for key, item in pairs(overrides or {}) do value[key] = item end
			return value
		end
		equal(Moves.glareStep(glare, 0.7, input()).stagger, false)
		equal(Moves.glareStep(glare, 0.7, input()).stagger, false, "1.4 s")
		local out = Moves.glareStep(glare, 0.2, input())
		equal(out.stagger, true, "1.6 s held"); equal(out.seconds, 1)
		equal(Moves.glareStep(glare, 2, input()).stagger, false, "once per chase")
		Moves.resetGlare(glare)
		equal(Moves.glareStep(glare, 1.6, input()).stagger, true, "a new chase may stagger again")
	end)

	case("FP4c: only a dark phase, within 12 studs, inside the 0.85 cone, while she hunts; a break restarts the hold", function()
		Moves.tune(nil)
		local function triggers(overrides)
			local glare = Moves.newGlare()
			local value = { phase = "Night", distance = 8, dot = 0.95, mode = "Hunt" }
			for key, item in pairs(overrides) do value[key] = item end
			return Moves.glareStep(glare, 2, value).stagger
		end
		equal(triggers({ phase = "Dusk" }), true)
		equal(triggers({ phase = "Day" }), false); equal(triggers({ phase = "Dawn" }), false)
		equal(triggers({ distance = 12 }), true); equal(triggers({ distance = 12.5 }), false)
		equal(triggers({ dot = 0.85 }), true); equal(triggers({ dot = 0.8 }), false)
		equal(triggers({ mode = "Alert" }), true, "a chase that just started counts")
		equal(triggers({ mode = "Telegraph" }), false, "never inside a telegraph")
		equal(triggers({ mode = "Patrol" }), false); equal(triggers({ distance = 0 / 0 }), false)
		local glare = Moves.newGlare()
		local value = { phase = "Night", distance = 8, dot = 0.95, mode = "Hunt" }
		Moves.glareStep(glare, 1.2, value)
		Moves.glareStep(glare, 0.2, { phase = "Night", distance = 8, dot = 0.1, mode = "Hunt" })
		equal(Moves.glareStep(glare, 1.2, value).stagger, false, "the hold restarts after a break")
		Moves.tune({ GLARE_ON = 0 })
		equal(triggers({}), false, "toggle off")
		Moves.tune(nil)
	end)

	case("FP4d: the chase-start scream reaches 70 studs and has its own toggle", function()
		Moves.tune(nil)
		equal(Moves.screamReach(), 70)
		Moves.tune({ SCREAM_ON = 0 })
		equal(Moves.screamReach(), 0, "off: no scream")
		Moves.tune({ SCREAM_REACH = 40 })
		equal(Moves.screamReach(), 40)
		Moves.tune(nil)
	end)

	case("FP4: tunable defaults, overrides and bad values", function()
		local defaults = Moves.tunable()
		equal(defaults.LUNGE_SPEED, 22); equal(defaults.GLARE_HOLD, 1.5)
		Moves.tune({ LUNGE_SPEED = 30, NOPE = 1, GLARE_HOLD = 0 / 0 })
		equal(Moves.live.LUNGE_SPEED, 30); equal(Moves.live.GLARE_HOLD, 1.5); equal(Moves.live.NOPE, nil)
		-- The tell never drops under the readable floor whatever a designer sets.
		Moves.tune({ LUNGE_TELL = 0.1 })
		equal(Moves.live.LUNGE_TELL, 0.35)
		Moves.tune(nil)
		equal(Moves.live.LUNGE_SPEED, 22)
	end)

	case("FP4: the module is pure", function()
		for _, banned in ipairs({ "game:", "workspace", "Instance.new", "os.clock", "tick(", "Random", "math.random",
			"RemoteEvent", "SetAttribute", "GetAttribute" }) do
			assert(not source:find(banned, 1, true), banned .. " found")
		end
	end)

	return result
end

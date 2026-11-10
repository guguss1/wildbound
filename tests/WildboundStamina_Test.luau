-- Invoke with require(freshTestClone)(require(freshStaminaClone)).
-- Dread pass, unit 1 (decision D-D5: sprint must cost something): the stamina pool, sprint and exhaustion from
-- docs/mechanics/wildbound-delivery-d.md section 2, plus the two costs the user chose. Sprinting is loud (a `sprint`
-- noise at most every 1.2 s outside camp) and, while a Lumipol is carried outside camp, it frightens the creature:
-- past a warning it slips free. Pure: the clock and the horizontal speed are passed in.
return function(Stamina)
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
	local function near(actual, expected, label, tolerance)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-6),
			(label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local C = Stamina.CONSTANTS
	-- Runs the rule for `seconds` in steps of `dt`, re-sending the intent each step (the client's heartbeat).
	local function run(state, seconds, input, startAt, dt, intent)
		dt = dt or 0.1
		local now, events = startAt or 0, { noise = 0, warn = 0, slip = 0 }
		for _ = 1, math.round(seconds / dt) do
			now += dt
			if intent then Stamina.intent(state, intent, now) end
			local out = Stamina.step(state, dt, input, now)
			for key in pairs(events) do if out[key] then events[key] += 1 end end
		end
		return now, events
	end
	local MOVING = { speed = 16, blocked = false, carrying = false, inCamp = false }
	local STILL = { speed = 0, blocked = false, carrying = false, inCamp = false }

	case("D2: the numbers of the design", function()
		-- Deliberately changed in the chase pass (CP-D2, user: make sprint felt): the multiplier is 1.45 (was 1.3).
		equal(C.POOL, 100); equal(C.SPRINT_MULTIPLIER, 1.45); equal(C.SPEED_CAP, 24); equal(C.DRAIN, 25)
		equal(C.START, 10); equal(C.RECOVER, 30); equal(C.REGEN_DELAY, 1.5); equal(C.REGEN_WALK, 10)
		equal(C.REGEN_STILL, 15); equal(C.MOVING_SPEED, 4); equal(C.NOISE_INTERVAL, 1.2); equal(C.INTENT_SECONDS, 1.2)
		local state = Stamina.new(0)
		equal(state.stamina, 100, "full at spawn"); equal(state.stance, "walk")
	end)

	case("D2: full pool drains in 4 s of sprint", function()
		local state = Stamina.new(0)
		run(state, 3.9, MOVING, 0, 0.1, "sprint")
		equal(state.stance, "sprint", "still sprinting at 3.9 s")
		near(state.stamina, 2.5, "drain 25 per second", 1e-6)
		run(state, 0.1, MOVING, 3.9, 0.1, "sprint")
		equal(state.stamina, 0); equal(state.stance, "exhausted"); equal(state.exhausted, true)
	end)

	case("D2: nothing drains standing still or walking", function()
		local state = Stamina.new(0)
		run(state, 3, STILL, 0, 0.1, "sprint")
		equal(state.stamina, 100, "holding sprint in place costs nothing"); equal(state.stance, "walk")
		run(state, 3, MOVING, 3, 0.1, "walk")
		equal(state.stamina, 100)
	end)

	case("D2: regen starts 1.5 s after the last drain, 10 walking and 15 standing", function()
		local state = Stamina.new(0)
		local now = run(state, 2, MOVING, 0, 0.1, "sprint")
		near(state.stamina, 50, "after 2 s")
		now = run(state, 1.4, MOVING, now, 0.1, "walk")
		near(state.stamina, 50, "no regen inside the delay")
		now = run(state, 1.0, MOVING, now, 0.1, "walk")
		assert(state.stamina > 50 and state.stamina <= 60 + 1e-6, "walking regen about 10 per second, got " .. state.stamina)
		local before = state.stamina
		run(state, 1.0, STILL, now, 0.1, "walk")
		near(state.stamina - before, 15, "standing regen 15 per second", 1e-6)
	end)

	case("D2: exhaustion at 0 locks sprint until 30; a fresh start needs 10", function()
		local state = Stamina.new(0)
		local now = run(state, 4, MOVING, 0, 0.1, "sprint")
		equal(state.exhausted, true)
		now = run(state, 3.0, STILL, now, 0.1, "sprint")
		assert(state.stamina < 30, "regen still under 30: " .. state.stamina)
		assert(state.stance ~= "sprint", "locked while exhausted")
		now = run(state, 2, STILL, now, 0.1, "walk")
		assert(state.stamina >= 30 and not state.exhausted, "unlocked at 30")
		local low = Stamina.new(0)
		low.stamina = 9
		run(low, 0.1, MOVING, 0, 0.1, "sprint")
		equal(low.stance, "walk", "under 10 a sprint does not start")
		low.stamina = 10
		run(low, 0.1, MOVING, 0.1, 0.1, "sprint")
		equal(low.stance, "sprint", "10 is enough to start")
	end)

	-- Deliberately changed in the chase pass: x1.45 (was x1.3: 20.8, 18.2, 14.3, 11.7).
	case("D2: sprint speed is base x 1.45 capped at 24, other stances keep the base", function()
		near(Stamina.speed(16, "sprint"), 23.2, "walk"); near(Stamina.speed(14, "sprint"), 20.3, "carrying")
		near(Stamina.speed(11, "sprint"), 15.95, "loaded pouch"); near(Stamina.speed(9, "sprint"), 13.05, "three eggs")
		equal(Stamina.speed(20, "sprint"), 24, "capped")
		equal(Stamina.speed(16, "walk"), 16); equal(Stamina.speed(16, "exhausted"), 16)
		equal(Stamina.speed(0 / 0, "sprint"), 0, "a bad base never becomes a speed")
	end)

	case("D2: the intent is two known words and expires after 1.2 s", function()
		local state = Stamina.new(0)
		equal(Stamina.intent(state, "fly", 0), false); equal(Stamina.intent(state, 5, 0), false)
		equal(Stamina.intent(state, "sprint", 0), true)
		Stamina.step(state, 0.1, MOVING, 0.1)
		equal(state.stance, "sprint")
		Stamina.step(state, 0.1, MOVING, 1.3)
		equal(state.stance, "walk", "a lost release cannot leave a player sprinting")
	end)

	case("D2: blocked input (capture, hidden, dead) forces walk", function()
		local state = Stamina.new(0)
		run(state, 1, MOVING, 0, 0.1, "sprint")
		equal(state.stance, "sprint")
		run(state, 0.1, { speed = 16, blocked = true, carrying = false, inCamp = false }, 1, 0.1, "sprint")
		equal(state.stance, "walk")
	end)

	case("D-D5: sprint is loud at most every 1.2 s, never in camp", function()
		local state = Stamina.new(0)
		local _, events = run(state, 3.6, MOVING, 0, 0.1, "sprint")
		equal(events.noise, 3, "0.1, 1.3 and 2.5 s")
		local camp = Stamina.new(0)
		local _, quiet = run(camp, 3, { speed = 16, blocked = false, carrying = false, inCamp = true }, 0, 0.1, "sprint")
		equal(quiet.noise, 0); equal(camp.stance, "sprint", "camp still lets you run")
		local walker = Stamina.new(0)
		local _, none = run(walker, 3, MOVING, 0, 0.1, "walk")
		equal(none.noise, 0, "walking is silent")
	end)

	case("D-D5: sprinting with a Lumipol frightens it; a warning comes first, then it slips free", function()
		equal(C.FEAR_RISE, 30); equal(C.FEAR_FALL, 12); equal(C.FEAR_WARN, 45); equal(C.FEAR_SLIP, 100)
		local carrying = { speed = 14, blocked = false, carrying = true, inCamp = false }
		local state = Stamina.new(0)
		local now, events = run(state, 1.4, carrying, 0, 0.1, "sprint")
		equal(events.warn, 0, "no warning before 1.5 s")
		now, events = run(state, 0.2, carrying, now, 0.1, "sprint")
		equal(events.warn, 1, "warned once at 1.5 s"); equal(events.slip, 0)
		now, events = run(state, 1.6, carrying, now, 0.1, "sprint")
		equal(events.warn, 0, "one warning per fright"); equal(events.slip, 0, "still holding at 3.2 s")
		now, events = run(state, 0.2, carrying, now, 0.1, "sprint")
		equal(events.slip, 1, "slips free at 3.4 s, before the pool runs out")
		equal(state.fear, 0, "a new creature starts calm")
	end)

	case("D-D5: stopping in time calms it; carrying nothing or running in camp builds no fear", function()
		local carrying = { speed = 14, blocked = false, carrying = true, inCamp = false }
		local state = Stamina.new(0)
		local now, events = run(state, 2, carrying, 0, 0.1, "sprint")
		equal(events.warn, 1)
		now, events = run(state, 6, carrying, now, 0.1, "walk")
		equal(state.fear, 0, "walking lets it settle at 12 per second"); equal(events.slip, 0)
		now, events = run(state, 1.6, carrying, now, 0.1, "sprint")
		equal(events.warn, 1, "the warning re-arms once it has calmed")
		local empty = Stamina.new(0)
		run(empty, 3.5, MOVING, 0, 0.1, "sprint")
		equal(empty.fear, 0)
		local camp = Stamina.new(0)
		local _, quiet = run(camp, 3.5, { speed = 14, blocked = false, carrying = true, inCamp = true }, 0, 0.1, "sprint")
		equal(camp.fear, 0); equal(quiet.slip, 0)
	end)

	case("D2: bad dt and NaN keep the state", function()
		local state = Stamina.new(0)
		Stamina.intent(state, "sprint", 0)
		for _, dt in ipairs({ 0 / 0, -1, math.huge }) do
			local out = Stamina.step(state, dt, MOVING, 0.1)
			equal(out.noise or out.warn or out.slip or false, false)
		end
		equal(state.stamina, 100)
		local out = Stamina.step(state, 0.1, { speed = 0 / 0 }, 0.1)
		equal(out.slip or false, false); equal(state.stance, "walk", "an unreadable speed is not moving")
		equal(Stamina.step(nil, 0.1, MOVING, 0.1).noise or false, false)
	end)

	-- Deliberately changed in the chase pass: 10 / 35 of the time at x1.45 is at most 12.9 percent (was 8.6 at x1.3).
	case("D2: holding sprint forever gains at most 12.9 percent over walking", function()
		local state = Stamina.new(0)
		local now, distance, walked, dt = 0, 0, 0, 0.1
		for _ = 1, 6000 do
			now += dt
			Stamina.intent(state, "sprint", now)
			Stamina.step(state, dt, MOVING, now)
			distance += Stamina.speed(16, state.stance) * dt
			walked += 16 * dt
		end
		assert(distance / walked <= 1.129, "mean gain " .. distance / walked)
		assert(distance / walked > 1.0, "sprint still helps")
	end)

	-- Nest Heist (NH4): the Burst.
	case("NH4: a burst lasts 0.8 s at x1.7 of the walk, capped at 28, and waits 6 s from its start", function()
		local C = Stamina.CONSTANTS
		equal(C.BURST_SECONDS, 0.8); equal(C.BURST_MULTIPLIER, 1.7); equal(C.BURST_COOLDOWN, 6); equal(C.BURST_CAP, 28)
		local state = Stamina.new(0)
		equal(Stamina.burst(state, 10, {}), true)
		equal(Stamina.bursting(state, 10.5), true)
		equal(Stamina.bursting(state, 10.81), false, "over after 0.8 s")
		local ok, reason = Stamina.burst(state, 13, {})
		equal(ok, false); equal(reason, "Cooldown")
		equal(Stamina.burst(state, 16.01, {}), true, "ready 6 s after the last start")
	end)

	case("NH4: the burst speed never stacks on the sprint and respects its cap", function()
		near(Stamina.speed(16, "walk", true), 27.2, "a walker")
		near(Stamina.speed(16, "sprint", true), 27.2, "a sprinter gets the same push, not x1.45 x1.7")
		near(Stamina.speed(11, "walk", true), 18.7, "an egg carrier")
		equal(Stamina.speed(20, "walk", true), 28, "the cap")
		near(Stamina.speed(16, "sprint", false), 23.2, "no burst, as before")
		equal(Stamina.speed(16, "walk"), 16)
	end)

	case("NH4: a capture, a hiding spot or death blocks a burst and ends one; the edges are reported", function()
		local state = Stamina.new(0)
		local ok, reason = Stamina.burst(state, 0, { blocked = true })
		equal(ok, false); equal(reason, "Blocked")
		assert(Stamina.burst(state, 1, {}))
		local out = Stamina.step(state, 0.1, { speed = 16 }, 1.1)
		equal(out.changed, false, "no edge while it runs")
		out = Stamina.step(state, 0.1, { speed = 16 }, 1.85)
		equal(out.changed, true, "the end re-applies the speed")
		state = Stamina.new(0)
		assert(Stamina.burst(state, 1, {}))
		out = Stamina.step(state, 0.1, { speed = 16, blocked = true }, 1.2)
		equal(out.changed, true); equal(Stamina.bursting(state, 1.3), false, "blocked ends it")
	end)

	return result
end

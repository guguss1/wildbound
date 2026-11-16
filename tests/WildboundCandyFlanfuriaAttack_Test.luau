-- Invoke with require(freshTestClone)(require(freshAttackClone)).
-- Caramelo biome (odd/tasks/caramelo-bioma.md, T4, S6): Onda de Caramelo, Flanfuria's single attack, as server rules
-- (pack 03_PERSONAJES/02_FLANFURIA.md). Pure: time and positions come in, effects come out.
return function(Attack)
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
	local function near(actual, expected, tolerance, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= tolerance,
			(label and label .. ": " or "") .. "Expected about " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	-- Deliberately changed (CF): a cast begins so its release is at 101 whatever the tell, so the ring and puddle cases
	-- keep their times.
	local function begin() return Attack.start(101 - Attack.TELEGRAPH_SECONDS, { x = 0, z = 0 }, {}) end
	local function player(id, x, z, extra)
		local p = { id = id, x = x, z = z, alive = true, safe = false, carrying = true }
		for k, v in pairs(extra or {}) do p[k] = v end
		return p
	end
	-- Steps the ring every 0.05 s from the release to its end and returns every effect, in order.
	local function release(a, players, move)
		local all = {}
		for i = 0, 16 do
			local t = 101 + i * 0.05
			if move then move(t) end
			for _, effect in ipairs(Attack.sweep(a, t, players)) do
				effect.at = t
				table.insert(all, effect)
			end
		end
		return all
	end

	-- Deliberately changed (CF, user 2026-11-15, odd/tasks/wildbound-caramelo-v2.md): a faster cast. The tell is at the
	-- 0.8 s fair-strike floor, the recovery is shorter and the cooldown is about 5 s. Was: tell 1.00, recover 0.85,
	-- cooldown 8.
	case("CF: the sheet's numbers: tell 0.80, release 0.80, ring 2 to 11, slow x0.65 for 1.5 s, puddle r4 for 3 s at x0.8, recover 0.60, cooldown 5", function()
		equal(Attack.TELEGRAPH_SECONDS, 0.8); equal(Attack.RELEASE_SECONDS, 0.8); equal(Attack.RECOVER_SECONDS, 0.6)
		equal(Attack.RING_FROM_STUDS, 2); equal(Attack.RING_TO_STUDS, 11)
		equal(Attack.RING_SLOW_FACTOR, 0.65); equal(Attack.RING_SLOW_SECONDS, 1.5)
		equal(Attack.PUDDLE_RADIUS_STUDS, 4); equal(Attack.PUDDLE_SECONDS, 3); equal(Attack.PUDDLE_SLOW_FACTOR, 0.8)
		equal(Attack.COOLDOWN_SECONDS, 5)
	end)

	case("S6: phases by the server's clock", function()
		local a = begin()
		near(a.startedAt, 100.2, 1e-9, "the cast began 0.8 s before its release")
		equal(Attack.phase(a, 100.2), "Telegraph"); equal(Attack.phase(a, 100.999), "Telegraph")
		equal(Attack.phase(a, 101), "Release"); equal(Attack.phase(a, 101.799), "Release")
		equal(Attack.phase(a, 101.8), "Recover"); equal(Attack.phase(a, 102.399), "Recover")
		equal(Attack.phase(a, 102.4), "Done")
		near(Attack.endsAt(a), 102.4, 1e-9, "end time")
	end)

	case("S6: the ring is a front that grows from 2 to 11 in 0.8 s, not a full circle at once", function()
		local a = begin()
		equal(Attack.ringRadius(a, 100.5), nil, "no ring during the tell")
		near(Attack.ringRadius(a, 101), 2, 1e-6); near(Attack.ringRadius(a, 101.4), 6.5, 1e-6); near(Attack.ringRadius(a, 101.8), 11, 1e-6)
		equal(Attack.ringRadius(a, 101.9), nil, "no ring after the release")
		equal(#Attack.sweep(a, 100.9, { player(1, 5, 0) }), 0, "nothing is hit during the tell")
		local effects = release(begin(), { player(1, 10, 0) })
		equal(#effects, 1)
		near(effects[1].at, 101.75, 0.051, "a player 10 studs away is reached late in the release")
		equal(#release(begin(), { player(1, 11.5, 0) }), 0, "a player past radius 11 is never reached")
	end)

	case("S6: one hit per player per cast, even when they walk with the front or back through it", function()
		local a = begin()
		local p = player(1, 3, 0)
		local effects = release(a, { p }, function(t) p.x = 3 + (t - 101) * 9 end) -- runs away, a little slower than the ring
		equal(#effects, 1)
		equal(#Attack.sweep(a, 101.8, { p }), 0, "a second sweep at the same time adds nothing")
		local both = release(begin(), { player(1, 5, 0), player(2, 0, -8) })
		equal(#both, 2, "two players are each hit once")
	end)

	case("S6: a player walking into the ring is hit once when the front passes them, however fast they close", function()
		for _, speed in ipairs({ 8, 12, 16, 24 }) do
			for _, from in ipairs({ 4, 5.3, 6.5, 9 }) do
				local p = player(1, from, 0)
				local effects = release(begin(), { p }, function(t) p.x = math.max(from - (t - 101) * speed, 0) end)
				equal(#effects, 1, "walking in from " .. from .. " studs at " .. speed .. " studs/s")
			end
		end
		-- in the air while the front and the player cross: missed, and not caught later from behind
		local q = player(1, 7, 0)
		local jumped = release(begin(), { q }, function(t)
			q.x = math.max(7 - (t - 101) * 16, 0)
			q.airborne = t >= 101.1 and t <= 101.35
		end)
		equal(#jumped, 0, "jumped the front while running in")
	end)

	case("S6: a hit slows x0.65 for 1.5 s, deals no damage and keeps the egg", function()
		local effect = release(begin(), { player(1, 6, 0) })[1]
		equal(effect.id, 1); equal(effect.slowFactor, 0.65); equal(effect.slowSeconds, 1.5)
		equal(effect.damage, 0); equal(effect.dropEgg, false)
	end)

	case("S6: nobody hides inside the starting radius; the dead, the safe and whoever jumps the front are missed", function()
		equal(#release(begin(), { player(1, 1, 0) }), 1, "a player hugging the flan")
		equal(#release(begin(), { player(1, 6, 0, { alive = false }) }), 0, "dead")
		equal(#release(begin(), { player(1, 6, 0, { safe = true }) }), 0, "safe zone")
		local p = player(1, 6, 0)
		local effects = release(begin(), { p }, function(t) p.airborne = t >= 101.3 and t <= 101.5 end) -- the front is at 6 at 101.356
		equal(#effects, 0, "in the air while the front passes")
		local late = player(1, 6, 0)
		equal(#release(begin(), { late }, function(t) late.airborne = t >= 101.6 end), 1, "jumping after the front passed does not help")
	end)

	case("S6: a puddle of radius 4 lies at the flan for 3 s after the release and slows x0.8 while stood on", function()
		local a = begin()
		equal(Attack.puddleActive(a, 101.79), false); equal(Attack.puddleActive(a, 101.8), true)
		equal(Attack.puddleActive(a, 104.79), true); equal(Attack.puddleActive(a, 104.8), false)
		local effects = Attack.puddle(a, 103, { player(1, 3.9, 0), player(2, 4.2, 0), player(3, 0, 2, { safe = true }) })
		equal(#effects, 1); equal(effects[1].id, 1); equal(effects[1].slowFactor, 0.8)
		equal(effects[1].damage, 0); equal(effects[1].dropEgg, false)
		equal(effects[1].slowSeconds, Attack.PUDDLE_PULSE_SECONDS, "a puddle slow is one short pulse")
		assert(Attack.PUDDLE_PULSE_SECONDS <= 0.75, "the puddle slow must end soon after stepping out")
		assert(Attack.SLOW_GAP_SECONDS >= 0.1, "two slows on one player need a gap for the speed to be restored between them")
		equal(Attack.PUDDLE_REPEAT_SECONDS, Attack.PUDDLE_PULSE_SECONDS + Attack.SLOW_GAP_SECONDS, "pulse period")
		equal(#Attack.puddle(a, 104.8, { player(1, 1, 0) }), 0, "the dry puddle slows nobody")
	end)

	case("S6: leaving combat removes the ring and the puddle at once", function()
		local a = begin()
		Attack.cancel(a)
		equal(Attack.ringRadius(a, 101.4), nil)
		equal(#Attack.sweep(a, 101.4, { player(1, 3, 0) }), 0)
		equal(Attack.puddleActive(a, 103), false)
		equal(#Attack.puddle(a, 103, { player(1, 1, 0) }), 0)
	end)

	case("CF: cooldown 5 s after the cast ends, so one puddle at most; the farm version never attacks", function()
		local a = begin()
		equal(Attack.canStart(nil, 0), true)
		equal(Attack.canStart(Attack.endsAt(a), Attack.endsAt(a) + 4.99), false)
		equal(Attack.canStart(Attack.endsAt(a), Attack.endsAt(a) + 5), true)
		assert(Attack.puddleEndsAt(a) < Attack.endsAt(a) + Attack.COOLDOWN_SECONDS, "the old puddle must be dry before the next cast")
		local state, reason = Attack.start(100, { x = 0, z = 0 }, { pet = true })
		equal(state, nil); equal(reason, "Pet")
	end)

	case("S6: slows are modifiers with an expiry: the strongest wins, they never multiply, and the speed comes back", function()
		local Slows = Attack.Slows
		local slows = Slows.new()
		equal(Slows.factor(slows, 1, 100), 1)
		Slows.apply(slows, 1, "ring", 0.65, 101.5)
		Slows.apply(slows, 1, "puddle", 0.8, 100.25)
		equal(Slows.factor(slows, 1, 100.1), 0.65, "ring and puddle together are x0.65, not x0.52")
		Slows.apply(slows, 1, "puddle", 0.8, 103)
		Slows.apply(slows, 1, "puddle", 0.8, 103) -- renewed every step: still one modifier
		equal(Slows.factor(slows, 1, 101.49), 0.65); equal(Slows.factor(slows, 1, 101.5), 0.8, "the ring slow ends at 1.5 s")
		equal(Slows.factor(slows, 1, 103), 1, "and the puddle slow ends too")
		equal(slows[1], nil, "an expired player leaves no record")
		equal(Slows.factor(slows, 2, 100.1), 1, "another player is untouched")
		Slows.apply(slows, 1, "ring", 0.65, 200)
		Slows.clear(slows, 1)
		equal(Slows.factor(slows, 1, 100), 1, "cleared on leaving")
	end)

	return result
end

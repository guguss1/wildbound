-- Invoke with require(freshTestClone)(require(freshIslandClone), require(freshIslandLayoutClone)).
-- Task I2 (docs/mechanics/wildbound-expedition-islands.md section 2, decisions EI-2 and EI-5): the pure island rule.
-- One sleep meter ("inquietud") per island, its stir and wake, the Alerta window, the nest content roll, respawn,
-- island 1's first-steal cap, and the woken adult's short, leashed, non-lethal chase (EI-2).
return function(Island, layout)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function near(actual, expected, tolerance, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= tolerance,
			(label or "") .. " expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function island(id)
		for _, entry in ipairs(layout.islands) do
			if entry.id == id then return entry end
		end
		error("no island " .. id)
	end
	local function run(meter, seconds, input)
		local events = {}
		local steps = math.floor(seconds / 0.2 + 0.5)
		for _ = 1, steps do
			local out = Island.step(meter, 0.2, input)
			for key, value in pairs(out) do if value then events[key] = (events[key] or 0) + 1 end end
		end
		return events
	end
	local C = Island.CONSTANTS

	case("I2: the layout's five islands load with their rule numbers", function()
		assert(#layout.islands == 5, "five islands")
		near(Island.wakeRadius(island("I1"), "Day"), 12, 1e-9, "day")
		near(Island.wakeRadius(island("I1"), "Night"), 15, 1e-9, "night")
		near(Island.wakeRadius(island("I5"), "Dusk"), 27.5, 1e-9, "dusk sleeps lighter too")
	end)

	case("I2: walking far from adults adds nothing", function()
		local meter = Island.newMeter(island("I2"))
		run(meter, 5, { inside = true, phase = "Day" })
		near(meter.value, 0, 1e-9)
		assert(meter.state == "Asleep", meter.state)
	end)

	case("I2: lingering by an adult adds 6 per second", function()
		local meter = Island.newMeter(island("I2"))
		run(meter, 2, { inside = true, linger = true, phase = "Day" })
		near(meter.value, 12, 1e-6)
		near(C.LINGER, 6, 1e-9, "constant")
	end)

	case("I2: sprinting inside the radius wakes within 2.5 s", function()
		local meter = Island.newMeter(island("I3"))
		local events = run(meter, 2.4, { inside = true, sprint = true, phase = "Day" })
		assert(events.woke == 1, "woke once")
		assert(meter.state == "Alert", meter.state)
	end)

	case("I2: light on a face counts only at Dusk and Night and is halved with the upgrade", function()
		local day = Island.newMeter(island("I4"))
		run(day, 1, { inside = true, light = true, phase = "Day" })
		near(day.value, 0, 1e-9, "day")
		local night = Island.newMeter(island("I4"))
		run(night, 1, { inside = true, light = true, phase = "Night" })
		near(night.value, 10, 1e-6, "night")
		local covered = Island.newMeter(island("I4"))
		run(covered, 1, { inside = true, light = true, farol = true, phase = "Dusk" })
		near(covered.value, 5, 1e-6, "farol tapado")
	end)

	case("I2: a clean lull stays asleep", function()
		local meter = Island.newMeter(island("I2"))
		run(meter, 3, { inside = true, linger = true, phase = "Day" })
		run(meter, 5, { inside = true, lulling = true, phase = "Day" })
		near(meter.value, 33, 1e-6, "6 x 3 + 3 x 5")
		assert(meter.state == "Asleep", meter.state)
	end)

	case("I2: two mistakes wake it", function()
		local meter = Island.newMeter(island("I2"))
		run(meter, 3, { inside = true, linger = true, phase = "Day" })
		run(meter, 5, { inside = true, lulling = true, phase = "Day" })
		local first = Island.event(meter, "LeftRing")
		assert(first.stirred and not first.woke, "one mistake stirs")
		run(meter, 5, { inside = true, lulling = true, phase = "Day" })
		near(meter.value, 73, 1e-6, "one mistake and a clean retry")
		local second = Island.event(meter, "SealMissed")
		assert(second.woke, "two mistakes wake")
		assert(meter.state == "Alert", meter.state)
		near(C.PENALTY.LeftRing, 25, 1e-9)
		near(C.PENALTY.SealMissed, 35, 1e-9)
		near(C.PENALTY.EggTaken, 30, 1e-9)
		near(C.PENALTY.Rustle, 10, 1e-9)
		near(C.PENALTY.SprintNoise, 25, 1e-9)
	end)

	case("I2: decay starts after 2 s", function()
		local meter = Island.newMeter(island("I2"))
		run(meter, 3, { inside = true, linger = true, phase = "Day" })
		run(meter, 2, { inside = true, phase = "Day" })
		near(meter.value, 18, 1e-6, "no decay in the first 2 s")
		run(meter, 1, { inside = true, phase = "Day" })
		near(meter.value, 10, 1e-6, "8 per second after that")
		run(meter, 1, { inside = false, phase = "Day" })
		near(meter.value, 0, 1e-6, "20 per second with nobody inside, floored at 0")
	end)

	case("I2: stir at 40 and wake at 100, once", function()
		local meter = Island.newMeter(island("I4"))
		local events = run(meter, 7, { inside = true, linger = true, phase = "Day" })
		assert(events.stirred == 1, "stirred once, got " .. tostring(events.stirred))
		assert(not events.woke, "not yet awake")
		events = run(meter, 12, { inside = true, linger = true, phase = "Day" })
		assert(events.woke == 1, "woke once, got " .. tostring(events.woke))
		assert(not events.stirred, "no second stir")
	end)

	case("I2: Alerta closes the nest for 30 s and resets to 30", function()
		local meter = Island.newMeter(island("I2"))
		Island.event(meter, "SealMissed")
		Island.event(meter, "SealMissed")
		Island.event(meter, "SealMissed")
		assert(meter.state == "Alert", meter.state)
		assert(not Island.nestOpen(meter), "closed")
		local events = run(meter, 29.8, { inside = true, sprint = true, phase = "Day" })
		assert(meter.state == "Alert" and not events.woke, "inputs ignored during Alerta")
		events = run(meter, 0.2, { inside = false, phase = "Day" })
		assert(events.settled == 1, "settled")
		assert(meter.state == "Asleep" and Island.nestOpen(meter), "open again")
		near(meter.value, 30, 1e-6, "reset to 30")
		local first = Island.newMeter(island("I1"))
		for _ = 1, 6 do Island.event(first, "SealMissed") end
		run(first, 8.2, { phase = "Day" })
		assert(first.state == "Asleep", "island 1 reopens after 8 s")
	end)

	case("I2: island 1 never passes 95 for a first steal without sprint", function()
		local meter = Island.newMeter(island("I1"))
		run(meter, 60, { inside = true, linger = true, lulling = true, light = true, phase = "Night", firstSteal = true })
		for _ = 1, 10 do Island.event(meter, "SealMissed", { firstSteal = true }) end
		assert(meter.state == "Asleep", meter.state)
		near(meter.value, 95, 1e-6)
		local halved = Island.newMeter(island("I1"))
		run(halved, 1, { inside = true, linger = true, phase = "Day" })
		near(halved.value, 3, 1e-6, "island 1 halves every input")
		run(meter, 1.2, { inside = true, sprint = true, phase = "Day", firstSteal = true })
		assert(meter.state == "Alert", "a sprint still wakes it")
	end)

	case("I2: nest roll is 70 cria and 30 egg over 10,000 seeded rolls within 1 %", function()
		local rng = Random.new(2026)
		local creatures = 0
		for _ = 1, 10000 do
			if Island.rollContent(island("I3"), "Day", function() return rng:NextNumber() end) == "Creature" then
				creatures += 1
			end
		end
		near(creatures / 10000, 0.7, 0.01, "creature share")
	end)

	case("I2: island 1 always holds a cria", function()
		for _, value in ipairs({ 0, 0.5, 0.99 }) do
			assert(Island.rollContent(island("I1"), "Night", function() return value end) == "Creature", "roll " .. value)
		end
	end)

	case("I2: island 5 cria only at Dusk and Night", function()
		local low = function() return 0 end
		assert(Island.rollContent(island("I5"), "Day", low) == "Egg", "egg by day")
		assert(Island.rollContent(island("I5"), "Dawn", low) == "Egg", "egg at dawn")
		assert(Island.rollContent(island("I5"), "Dusk", low) == "Creature", "cria at dusk")
		assert(Island.rollContent(island("I5"), "Night", low) == "Creature", "cria at night")
	end)

	case("I2: respawn and nest count scale with players", function()
		near(Island.respawnSeconds(island("I2"), "Creature", 1), 45, 1e-9)
		near(Island.respawnSeconds(island("I2"), "Creature", 5), 30, 1e-9)
		near(Island.respawnSeconds(island("I4"), "Egg", 1), 60, 1e-9)
		near(Island.respawnSeconds(island("I4"), "Egg", 6), 40, 1e-9)
		near(Island.respawnSeconds(island("I1"), "Creature", 1), 8, 1e-9)
		assert(Island.nestCount(island("I2"), 4) == 1, "island 2 keeps one nest")
		assert(Island.nestCount(island("I3"), 2) == 1, "two players, one nest")
		assert(Island.nestCount(island("I3"), 3) == 2, "three players, two nests")
	end)

	case("I2: the woken adult chases between carry and carry-sprint speed", function()
		assert(C.CHASE_SPEED > 14 and C.CHASE_SPEED < 18.2, "speed " .. tostring(C.CHASE_SPEED))
		assert(C.CHASE_SECONDS >= 6 and C.CHASE_SECONDS <= 8, "duration")
		near(C.CHASE_LEASH, 35, 1e-9, "leash")
		local entry = island("I2")
		local chase = Island.newChase(entry, entry.adultPoints[1])
		local event = Island.chaseStep(chase, 0.5, entry.x + 5, entry.z + 30)
		assert(event == nil, "still running")
		near(math.sqrt((chase.x - entry.adultPoints[1].x) ^ 2 + (chase.z - entry.adultPoints[1].z) ^ 2),
			C.CHASE_SPEED * 0.5, 1e-6, "moved at chase speed")
	end)

	case("I2: the chase is leashed to its island and gives up on time", function()
		local entry = island("I3")
		local chase = Island.newChase(entry, entry.adultPoints[1])
		local gaveUp = false
		for _ = 1, 50 do
			local event = Island.chaseStep(chase, 0.2, entry.x + 200, entry.z)
			assert(math.sqrt((chase.x - entry.x) ^ 2 + (chase.z - entry.z) ^ 2) <= C.CHASE_LEASH + 1e-6, "leash")
			if event == "GaveUp" then gaveUp = true break end
		end
		assert(gaveUp, "gave up")
		assert(chase.mode == "Return", chase.mode)
		for _ = 1, 100 do Island.chaseStep(chase, 0.2) end
		assert(chase.mode == "Home", "walked home")
		near(chase.x, entry.adultPoints[1].x, 1e-6)
	end)

	case("I2: touching the thief catches, once, and never hurts", function()
		local entry = island("I2")
		local start = entry.adultPoints[1]
		local chase = Island.newChase(entry, start)
		local event = Island.chaseStep(chase, 0.2, start.x + C.CATCH - 0.1, start.z)
		assert(event == "Caught", tostring(event))
		assert(chase.mode == "Return", "goes home after a catch")
		assert(Island.chaseStep(chase, 0.2, chase.x, chase.z) == nil, "a returning adult catches nobody")
		assert(C.DAMAGE == 0, "no damage")
	end)

	case("I2: the chase picks the thief first, then the nearest intruder", function()
		local entry = island("I2")
		local pick = Island.chaseTarget(entry, {
			{ key = 1, x = entry.x + 3, z = entry.z, carrying = nil },
			{ key = 2, x = entry.x + 30, z = entry.z, carrying = "I2" },
		})
		assert(pick == 2, "the thief")
		pick = Island.chaseTarget(entry, {
			{ key = 1, x = entry.x + 12, z = entry.z },
			{ key = 2, x = entry.x + 4, z = entry.z },
			{ key = 3, x = entry.x + 200, z = entry.z, carrying = "I2" },
		})
		assert(pick == 2, "nearest inside the leash; a thief beyond it is gone")
		assert(Island.chaseTarget(entry, {}) == nil, "nobody")
	end)

	case("I2: bad input changes nothing", function()
		local meter = Island.newMeter(island("I2"))
		Island.step(meter, 0 / 0, { inside = true, sprint = true })
		Island.step(meter, -1, { inside = true, sprint = true })
		Island.step(meter, 0.2, nil)
		Island.step(meter, 0.2, "sprint")
		Island.event(meter, "Unknown")
		Island.event(meter, nil)
		near(meter.value, 0, 1e-9)
		assert(Island.rollContent(nil, "Day", function() return 0 end) == nil, "no island")
		assert(Island.newChase(nil, nil) == nil, "no chase")
		local chase = Island.newChase(island("I2"), island("I2").adultPoints[1])
		local x = chase.x
		assert(Island.chaseStep(chase, 0 / 0, 0, 0) == nil and chase.x == x, "bad dt")
	end)

	return result
end

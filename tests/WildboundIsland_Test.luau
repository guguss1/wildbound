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
		-- Deliberately changed in the fear pass (FA2): an egg was its own 30; a grab (cria or egg) is now GRAB.
		near(C.GRAB, 45, 1e-9, "a grab")
		near(C.PENALTY.Rustle, 10, 1e-9)
		near(C.PENALTY.SprintNoise, 25, 1e-9)
	end)

	-- Fear pass (FA2, user: "stealing must be an adrenaline rush"): the grab itself is loud. Taking a cria (a granted
	-- capture) or an egg adds GRAB to the meter, so a careful thief on a calm island keeps it asleep, while a sloppy one
	-- (a mistake, lingering) wakes the parents the moment the cria is lifted. Island 1's first steal stays capped.
	case("FA2: a grab is loud enough to wake a stirred island, and island 1's first steal stays safe", function()
		local calm = Island.newMeter(island("I2"))
		run(calm, 3, { inside = true, linger = true, phase = "Day" })
		local quiet = Island.event(calm, "CriaTaken")
		assert(not quiet.woke and calm.state == "Asleep", "a careful grab on a calm island: " .. tostring(calm.value))
		local stirred = Island.newMeter(island("I2"))
		run(stirred, 3, { inside = true, linger = true, phase = "Day" })
		Island.event(stirred, "LeftRing")
		Island.event(stirred, "LeftRing")
		assert(Island.event(stirred, "CriaTaken").woke, "a grab after mistakes wakes the parents")
		local egg = Island.newMeter(island("I4"))
		Island.event(egg, "EggTaken")
		near(egg.value, C.GRAB, 1e-9, "an egg is the same grab")
		local first = Island.newMeter(island("I1"))
		first.value = 90
		local out = Island.event(first, "CriaTaken", { firstSteal = true })
		assert(not out.woke and first.value <= C.FIRST_CAP + 1e-9, "the first steal never wakes island 1")
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

	-- Deliberately changed in the chase pass (CP-D5, user: "the parents can kill you"). It was "between carry (14) and
	-- carry-sprint (18.2) speed, 6 to 8 s, no wind-up" (IW-4: a thief next to the adults was caught in about 0.3 s).
	-- Deliberately changed again in the fear pass (FA2, user: "faster; the parents chase you and hit you"): it was a
	-- 0.35 to 1 s wind-up, 16 to 17.3 studs/s and 8 to 12 s. Now it stands up quicker (0.35 to 0.5 s, never under the
	-- readable floor), runs well past a walker (16) yet still under a carrying sprinter (14 x 1.45 = 20.3) by at
	-- least 1 stud/s, so a sprint (which scares the cria) is the only way out, and it chases for 12 to 16 s.
	case("CP4: the woken adult winds up, then chases faster than a walker, slower than a carrying sprinter", function()
		assert(C.WAKE_WINDUP >= 0.35 and C.WAKE_WINDUP <= 0.5, "wind-up " .. tostring(C.WAKE_WINDUP))
		assert(C.CHASE_SPEED >= 18 and C.CHASE_SPEED <= 20.3 - 1, "speed " .. tostring(C.CHASE_SPEED))
		assert(C.CHASE_SECONDS >= 12 and C.CHASE_SECONDS <= 16, "duration")
		near(C.CHASE_LEASH, 35, 1e-9, "leash")
		local entry = island("I2")
		local start = entry.adultPoints[1]
		local chase = Island.newChase(entry, start)
		assert(Island.chaseStep(chase, C.WAKE_WINDUP - 0.05, start.x + 1, start.z) == nil, "no strike while it stands up")
		near(chase.x, start.x, 1e-9, "it does not move during the wind-up")
		Island.chaseStep(chase, 0.05, entry.x + 5, entry.z + 30)
		local event = Island.chaseStep(chase, 0.5, entry.x + 5, entry.z + 30)
		assert(event == nil, "still running")
		near(math.sqrt((chase.x - start.x) ^ 2 + (chase.z - start.z) ^ 2), C.CHASE_SPEED * 0.5, 1e-6, "moved at chase speed")
	end)

	case("I2: the chase is leashed to its island and gives up on time", function()
		local entry = island("I3")
		local chase = Island.newChase(entry, entry.adultPoints[1])
		local gaveUp = false
		for _ = 1, 80 do
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

	-- Deliberately changed in the chase pass (CP-D1, CP-D5). It was "touching the thief catches, once, and never
	-- hurts". Now a reach starts a readable strike (it stands still for the wind-up, never under the 0.35 s floor); it
	-- lands only if the thief is still within the hit range, and the chase goes on after a cooldown.
	case("CP4: a reach starts a readable strike that lands only if the thief stays close", function()
		assert(C.STRIKE_WINDUP >= 0.35, "a readable tell")
		assert(C.HIT_RANGE > C.STRIKE_REACH, "a little slack for the swing")
		local entry = island("I2")
		local start = entry.adultPoints[1]
		local chase = Island.newChase(entry, start)
		Island.chaseStep(chase, C.WAKE_WINDUP, entry.x + 200, entry.z)
		local tx, tz = chase.x + C.STRIKE_REACH - 0.5, chase.z
		assert(Island.chaseStep(chase, 0.05, tx, tz) == "WindUp", "a reach starts the swing")
		assert(chase.mode == "Strike", chase.mode)
		local x, z = chase.x, chase.z
		assert(Island.chaseStep(chase, C.STRIKE_WINDUP - 0.1, tx, tz) == nil, "the swing is still coming")
		near(chase.x, x, 1e-9); near(chase.z, z, 1e-9, "it stands still to swing")
		assert(Island.chaseStep(chase, 0.1, tx, tz) == "Hit", "it lands on a thief who stayed")
		assert(chase.mode == "Chase", "it keeps chasing after a hit")
		assert(Island.chaseStep(chase, 0.1, chase.x + 1, chase.z) == nil, "no new swing during the cooldown")
		assert(Island.chaseStep(chase, C.STRIKE_COOLDOWN, chase.x + 1, chase.z) == "WindUp", "then it swings again")
		Island.chaseStep(chase, C.STRIKE_WINDUP - 0.01, chase.x + 1, chase.z)
		assert(Island.chaseStep(chase, 0.01, chase.x + C.HIT_RANGE + 2, chase.z) == "Missed", "a dodge makes it miss")
	end)

	case("CP4: three hits kill a lethal player; first-timers and other places only drop the cria", function()
		assert(C.DAMAGE * 3 >= 100 and C.DAMAGE * 2 < 100, "three hits, not two " .. tostring(C.DAMAGE))
		local hit = Island.hitEffect({ carrying = true, lethal = true, damageMode = "private" })
		assert(hit.drop == true and hit.damage == C.DAMAGE, "a thief drops the cria and is hurt")
		hit = Island.hitEffect({ carrying = false, lethal = true, damageMode = "private" })
		assert(hit.drop == false and hit.damage == C.DAMAGE, "an empty-handed intruder is hurt")
		assert(Island.hitEffect({ carrying = true, lethal = false, damageMode = "private" }).damage == 0, "before a paid trip")
		assert(Island.hitEffect({ carrying = true, lethal = true, damageMode = "off" }).damage == 0, "damage off here")
		assert(Island.hitEffect({ carrying = true, lethal = true, damageMode = "on" }).damage == 0, "only private counts")
		assert(Island.hitEffect(nil).damage == 0, "bad input")
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

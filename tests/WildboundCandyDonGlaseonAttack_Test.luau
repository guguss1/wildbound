-- Invoke with require(freshTestClone)(require(freshCandyDonGlaseonAttackClone)).
-- Caramelo biome (odd/tasks/wildbound-caramelo.md, CA3; pack 03_PERSONAJES/04_DON_GLASEON_BOSS.md): Latigo de Regaliz,
-- Don Glaseon's single attack, as pure rules. Changes nothing.
return function(Latigo)
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
	local O = { x = 0, y = 0, z = 0 }

	-- Deliberately changed (DG1, user 2026-11-15, odd/tasks/wildbound-caramelo-v2.md): a faster combo of three lashes, left
	-- lane, right lane, then centre, each with its own drawn lane. Was one lash: tell 1.10, lock 0.60.
	case("DG1: the numbers: tell 0.80 s, lock 0.35 s, three lashes of 0.35 s, recover 1.0 s, cooldown 7 s, 22 x 5 lanes", function()
		near(Latigo.TELEGRAPH_SECONDS, 0.8, "tell"); near(Latigo.LOCK_SECONDS, 0.35, "lock"); near(Latigo.RELEASE_SECONDS, 0.35, "lash")
		equal(Latigo.LASHES, 3, "lashes in the combo")
		assert(Latigo.TELEGRAPH_SECONDS - Latigo.LOCK_SECONDS + Latigo.RELEASE_SECONDS >= 0.8 - 1e-9,
			"the first locked lane leaves at least 0.8 s to step out")
		near(Latigo.RECOVER_SECONDS, 1.0, "recover"); near(Latigo.COOLDOWN_SECONDS, 7, "cooldown")
		near(Latigo.LENGTH_STUDS, 22, "length"); near(Latigo.WIDTH_STUDS, 5, "width")
		near(Latigo.PUSH_STUDS, 12, "push"); near(Latigo.SLOW_FACTOR, 0.85, "slow"); near(Latigo.SLOW_SECONDS, 0.7, "slow time")
		assert(Latigo.TELEGRAPH_SECONDS >= 0.8, "under the FairStrike floor")
	end)

	case("DG1: the timeline: one lock, three lashes back to back, an impact at the end of each, the end after the recovery", function()
		local cast = Latigo.start(10, {})
		near(Latigo.lockAt(cast), 10.35, "lock"); near(Latigo.releaseAt(cast), 10.8, "release")
		near(Latigo.impactAt(cast, 1), 11.15, "first impact"); near(Latigo.impactAt(cast, 2), 11.5, "second impact")
		near(Latigo.impactAt(cast, 3), 11.85, "third impact"); near(Latigo.impactAt(cast), 11.85, "the combo's last impact")
		near(Latigo.endsAt(cast), 12.85, "end"); near(Latigo.comboSeconds(), 2.85, "the whole combo")
		equal(Latigo.phase(cast, 10.5), "Telegraph"); equal(Latigo.phase(cast, 10.9), "Attack"); equal(Latigo.phase(cast, 11.6), "Attack")
		equal(Latigo.phase(cast, 12), "Recover"); equal(Latigo.phase(cast, 12.9), "Done")
		-- every lash is drawn from the start, so each lands at least 0.8 s after its lane appears
		for i = 1, Latigo.LASHES do assert(Latigo.impactAt(cast, i) - 10 >= 0.8, "lash " .. i .. " under the floor") end
	end)

	case("DG1: three lanes side by side: left, right, then centre, no overlap, all along the facing", function()
		-- facing -Z: the boss's right is +X
		local lanes = Latigo.lanes(O, 0, -2)
		equal(#lanes, 3, "lanes")
		for i, lane in ipairs(lanes) do
			equal(lane.kind, "lane", "lane " .. i); near(lane.dz, -1, "facing " .. i); near(lane.length, 22); near(lane.width, 5)
		end
		near(lanes[1].ox, -5, "the left lane"); near(lanes[2].ox, 5, "the right lane"); near(lanes[3].ox, 0, "the centre lane")
		local function count(point)
			local n = 0
			for _, lane in ipairs(lanes) do if Latigo.inLane(lane, point) then n += 1 end end
			return n
		end
		equal(Latigo.inLane(lanes[3], { x = 0, z = -10 }), true, "centre"); equal(count({ x = 0, z = -10 }), 1, "one lane only")
		equal(Latigo.inLane(lanes[1], { x = -5, z = -10 }), true, "left"); equal(count({ x = -5, z = -10 }), 1)
		equal(Latigo.inLane(lanes[2], { x = 5, z = -10 }), true, "right"); equal(count({ x = 5, z = -10 }), 1)
		equal(count({ x = 7.6, z = -10 }), 0, "past the outer edge"); equal(count({ x = 0, z = 1 }), 0, "behind the boss")
	end)

	case("the lane is the shared lane shape: from the boss, along its facing, the exact rectangle that hits", function()
		local lane = Latigo.lane(O, 0, -2)
		equal(lane.kind, "lane"); near(lane.dx, 0); near(lane.dz, -1); near(lane.length, 22); near(lane.width, 5)
		equal(Latigo.inLane(lane, { x = 0, z = -21.9 }), true, "the far end")
		equal(Latigo.inLane(lane, { x = 2.4, z = -10 }), true, "inside the edge")
		equal(Latigo.inLane(lane, { x = 2.6, z = -10 }), false, "a sidestep out of the 5-stud width")
		equal(Latigo.inLane(lane, { x = 0, z = -22.5 }), false, "past the end")
		equal(Latigo.inLane(lane, { x = 0, z = 1 }), false, "behind the boss")
	end)

	case("one impact per lash: a carrier drops the egg and is pushed, anyone else is pushed and slowed", function()
		local cast = Latigo.start(0, {})
		local lane = Latigo.lane(O, 0, -1)
		local effects = Latigo.impact(cast, lane, { { id = 1, x = 0, z = -8, alive = true, carrying = true },
			{ id = 2, x = 1, z = -14, alive = true }, { id = 3, x = 6, z = -8, alive = true }, { id = 4, x = 0, z = -5, alive = true, safe = true },
			{ id = 5, x = 0, z = -6, alive = false } })
		equal(#effects, 2, "hits")
		local carrier, other = effects[1], effects[2]
		equal(carrier.id, 1); equal(carrier.dropEgg, true, "the carrier drops the egg"); equal(carrier.slowFactor, nil, "no slow on top")
		near(carrier.push.studs, 12, "push"); near(carrier.push.dz, -1, "pushed along the lash")
		equal(other.id, 2); equal(other.dropEgg, false); near(other.slowFactor, 0.85); near(other.slowSeconds, 0.7)
		equal(carrier.damage, 0, "no damage"); equal(other.damage, 0)
		equal(#Latigo.impact(cast, lane, { { id = 9, x = 0, z = -8, alive = true } }), 0, "a second impact hits nobody")
	end)

	case("DG1: each lash lands once, and a player is hit at most once per combo", function()
		local cast = Latigo.start(0, {})
		local lanes = Latigo.lanes(O, 0, -1)
		local players = { { id = 1, x = -5, z = -8, alive = true, carrying = true }, { id = 2, x = 0, z = -14, alive = true },
			{ id = 3, x = 5, z = -8, alive = true } }
		local first = Latigo.impact(cast, lanes[1], players, 1)
		equal(#first, 1, "the left lash"); equal(first[1].id, 1); equal(first[1].dropEgg, true, "the carrier drops the egg")
		equal(#Latigo.impact(cast, lanes[1], players, 1), 0, "the left lash lands once")
		local second = Latigo.impact(cast, lanes[2], players, 2)
		equal(#second, 1, "the right lash"); equal(second[1].id, 3)
		players[1].x = 0 -- the carrier walks into the centre lane after being hit
		local third = Latigo.impact(cast, lanes[3], players, 3)
		equal(#third, 1, "the centre lash"); equal(third[1].id, 2, "only the one not hit yet")
	end)

	case("the farm version never attacks, and a new cast waits for the cooldown", function()
		local cast, why = Latigo.start(0, { pet = true })
		equal(cast, nil); equal(why, "Pet")
		equal(Latigo.canStart(nil, 0), true); equal(Latigo.canStart(5, 11.9), false); equal(Latigo.canStart(5, 12), true)
	end)

	return result
end

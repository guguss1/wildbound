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

	case("the pack's numbers: tell 1.10 s, lock 0.60 s, lash 0.35 s, recover 1.0 s, cooldown 7 s, a 22 x 5 lane", function()
		near(Latigo.TELEGRAPH_SECONDS, 1.1, "tell"); near(Latigo.LOCK_SECONDS, 0.6, "lock"); near(Latigo.RELEASE_SECONDS, 0.35, "lash")
		near(Latigo.RECOVER_SECONDS, 1.0, "recover"); near(Latigo.COOLDOWN_SECONDS, 7, "cooldown")
		near(Latigo.LENGTH_STUDS, 22, "length"); near(Latigo.WIDTH_STUDS, 5, "width")
		near(Latigo.PUSH_STUDS, 12, "push"); near(Latigo.SLOW_FACTOR, 0.85, "slow"); near(Latigo.SLOW_SECONDS, 0.7, "slow time")
		assert(Latigo.TELEGRAPH_SECONDS >= 0.8, "under the FairStrike floor")
	end)

	case("the timeline from start: lock, release, impact at the end of the lash, end after the recovery", function()
		local cast = Latigo.start(10, {})
		near(Latigo.lockAt(cast), 10.6, "lock"); near(Latigo.releaseAt(cast), 11.1, "release")
		near(Latigo.impactAt(cast), 11.45, "impact"); near(Latigo.endsAt(cast), 12.45, "end")
		equal(Latigo.phase(cast, 10.5), "Telegraph"); equal(Latigo.phase(cast, 11.2), "Attack")
		equal(Latigo.phase(cast, 12), "Recover"); equal(Latigo.phase(cast, 12.5), "Done")
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

	case("one impact per cast: a carrier drops the egg and is pushed, anyone else is pushed and slowed", function()
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

	case("the farm version never attacks, and a new cast waits for the cooldown", function()
		local cast, why = Latigo.start(0, { pet = true })
		equal(cast, nil); equal(why, "Pet")
		equal(Latigo.canStart(nil, 0), true); equal(Latigo.canStart(5, 11.9), false); equal(Latigo.canStart(5, 12), true)
	end)

	return result
end

-- Invoke with require(freshTestClone)(require(freshCandyFrutillonClone), require(freshCandyLayoutClone),
--   { service = <WildboundCandyFrutillonService Source> }).
-- Caramelo v2 (odd/tasks/wildbound-caramelo-v2.md, CT4): Frutillon, the giant strawberry guarding the Gran Torta's
-- summit. It wakes when a player stands on the summit and rolls round the summit's rim toward them after a squash and
-- a line on the floor, bumping whoever it rolls over off the edge; it throws seeds that bounce down the stair at players
-- climbing it. Knockback only: never damage, never the egg. Pure rules plus source pins of the service. Changes nothing.
return function(Frut, Layout, sources)
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
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-3),
			(label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function has(source, needle, label)
		assert(type(source) == "string" and string.find(source, needle, 1, true), (label or "missing") .. ": " .. needle)
	end
	local function kinds(events)
		local out = {}
		for _, e in ipairs(events) do table.insert(out, e.kind) end
		return table.concat(out, ",")
	end
	local summit = Frut.summit(Layout)
	local function onRing(angle, id)
		return { id = id or 1, alive = true, x = summit.x + math.cos(angle) * Frut.RING_STUDS, y = summit.top + 3,
			z = summit.z + math.sin(angle) * Frut.RING_STUDS }
	end
	local function below(id) return { id = id or 2, alive = true, x = summit.x + 30, y = Layout.FLOOR_TOP + 3, z = summit.z } end

	case("CT4: the numbers: tell 0.8 s, roll on a ring between La Duquesa and the edge, push 12 studs, seeds push 6", function()
		near(Frut.TELL_SECONDS, 0.8); assert(Frut.TELL_SECONDS >= 0.8, "the fair-strike floor")
		near(Frut.RECOVER_SECONDS, 1.0); near(Frut.SLEEP_SECONDS, 6)
		-- A2 review (walked Play): he rolled a climber off 0.8 s after arriving, before La Duquesa's first bubbles could
		-- pop; he now takes WAKE_SECONDS to wake up before his first tell
		near(Frut.WAKE_SECONDS, 2)
		near(Frut.ROLL_STUDS_PER_SECOND, 18); near(Frut.OVERSHOOT_RADIANS, 0.6); near(Frut.HIT_STUDS, 3)
		near(Frut.PUSH_STUDS, 12); near(Frut.PUSH_SECONDS, 0.4)
		assert(Frut.RING_STUDS - Frut.RADIUS_STUDS >= 3, "it rolls clear of La Duquesa's seat")
		assert(Frut.RING_STUDS + Frut.RADIUS_STUDS <= summit.radius + 0.5, "it stays on the summit")
		near(Frut.SEED_EVERY_SECONDS, 2.5); near(Frut.SEED_STEPS_PER_SECOND, 8); near(Frut.SEED_HIT_STUDS, 2)
		near(Frut.SEED_PUSH_STUDS, 6); near(Frut.SEED_PUSH_SECONDS, 0.3); equal(Frut.MAX_SEEDS, 3)
		equal(Frut.DAMAGE, 0, "knockback only")
		near(summit.top, Layout.FLOOR_TOP + Layout.TOWER.tiers[#Layout.TOWER.tiers].top, "the summit's floor")
	end)

	local WOKE = 2 + (Frut.WAKE_SECONDS or 0) -- a player arrives at 2; his first tell when he has woken up
	local ROLL = WOKE + Frut.TELL_SECONDS

	case("CT4: asleep until a player stands on the summit; he wakes up, then a squash and a line, and a roll toward them", function()
		local s = Frut.new(0, summit)
		equal(s.phase, "Asleep")
		equal(#Frut.step(s, 1, { below() }), 0, "nobody up there: asleep")
		local target = onRing(s.angle + 1.2, 5)
		local wake = Frut.step(s, 2, { target })
		equal(kinds(wake), "Wake"); equal(s.phase, "Waking")
		equal(#Frut.step(s, WOKE - 0.05, { target }), 0, "still waking up")
		local woke = Frut.step(s, WOKE, { target })
		equal(kinds(woke), "Telegraph"); equal(s.phase, "Telegraph")
		local tell = woke[1]
		near(tell.rollAt, ROLL, "rolls 0.8 s later")
		near(tell.toAngle, tell.fromAngle + 1.2 + Frut.OVERSHOOT_RADIANS, "toward the target and a little past", 1e-6)
		equal(#Frut.step(s, ROLL - 0.3, { target }), 0, "the tell")
		equal(kinds(Frut.step(s, ROLL, { target })), "Roll"); equal(s.phase, "Roll")
		-- nobody left when he has woken up: he waits and goes back to sleep
		local s2 = Frut.new(0, summit)
		Frut.step(s2, 2, { target })
		equal(#Frut.step(s2, WOKE, {}), 0, "woke up alone: no tell")
		equal(kinds(Frut.step(s2, WOKE + Frut.SLEEP_SECONDS, {})), "Sleep"); equal(s2.phase, "Asleep")
	end)

	case("CT4: rolling over a player bumps them outward once; then a recovery and the next roll", function()
		local s = Frut.new(0, summit)
		local target = onRing(s.angle + 1.2, 5)
		Frut.step(s, 2, { target })
		Frut.step(s, WOKE, { target })
		Frut.step(s, ROLL, { target })
		local duration = (1.2 + Frut.OVERSHOOT_RADIANS) * Frut.RING_STUDS / Frut.ROLL_STUDS_PER_SECOND
		near(s.rollEndsAt, ROLL + duration, "roll time from the arc", 1e-6)
		local hits = {}
		local t = ROLL
		while t < s.rollEndsAt + 0.05 do
			t += 0.05
			for _, e in ipairs(Frut.step(s, t, { target })) do if e.kind == "Hit" then table.insert(hits, e) end end
		end
		equal(#hits, 1, "one bump per roll")
		local hit = hits[1]
		equal(hit.id, 5)
		local ox, oz = target.x - summit.x, target.z - summit.z
		local length = math.sqrt(ox * ox + oz * oz)
		assert(hit.dx * ox / length + hit.dz * oz / length >= 0.7, "pushed outward, off the edge")
		near(hit.studs, 12); near(hit.seconds, 0.4); equal(hit.damage, 0)
		equal(s.phase, "Recover")
		local again = Frut.step(s, s.recoverEndsAt, { onRing(s.angle - 1, 5) })
		equal(kinds(again), "Telegraph", "the next roll while they stay")
	end)

	case("CT4: alone for 6 s it goes back to its rest spot and sleeps", function()
		local s = Frut.new(0, summit)
		local target = onRing(s.angle + 1.2, 5)
		Frut.step(s, 2, { target })
		Frut.step(s, WOKE, { target })
		Frut.step(s, ROLL, { target })
		local t = ROLL
		while s.phase ~= "Recover" do t += 0.1; Frut.step(s, t, {}) end
		t = s.recoverEndsAt
		equal(#Frut.step(s, t, {}), 0, "nobody: it waits")
		local events = Frut.step(s, t + Frut.SLEEP_SECONDS, {})
		equal(kinds(events), "Sleep"); equal(s.phase, "Asleep"); near(s.angle, Frut.REST_ANGLE, "back home")
	end)

	case("CT4: seeds: thrown while someone climbs the stair, bouncing down it, one push per seed and player", function()
		local path = Frut.seedPath(Layout)
		equal(#path, #Layout.stairSteps(), "every step from the top down")
		assert(path[1].y > path[#path].y, "from the top to the floor")
		local s = Frut.new(0, summit)
		equal(#Frut.seedStep(s, 1, { below() }, path), 0, "nobody on the stair: no seed")
		local climber = { id = 7, alive = true, x = path[20].x, y = path[20].y + 3, z = path[20].z }
		local first = Frut.seedStep(s, 2, { climber }, path)
		equal(kinds(first), "Seed"); equal(#s.seeds, 1)
		equal(#Frut.seedStep(s, 3, { climber }, path), 0, "one every 2.5 s")
		local pushes = {}
		local t = 2
		while t < 2 + 21 / Frut.SEED_STEPS_PER_SECOND do
			t += 0.05
			for _, e in ipairs(Frut.seedStep(s, t, { climber }, path)) do if e.kind == "SeedHit" and e.seed == 1 then table.insert(pushes, e) end end
		end
		equal(#pushes, 1, "seed 1 bumps the climber once")
		near(pushes[1].studs, 6); near(pushes[1].seconds, 0.3); equal(pushes[1].damage, 0)
		local down = path[21]
		local dx, dz = down.x - path[19].x, down.z - path[19].z
		assert(pushes[1].dx * dx + pushes[1].dz * dz > 0, "pushed down the stair")
		t = 2 + #path / Frut.SEED_STEPS_PER_SECOND + 0.1
		Frut.seedStep(s, t, {}, path)
		for _, seed in ipairs(s.seeds) do assert(seed.id ~= 1, "a seed at the bottom is gone") end
		assert(#s.seeds <= Frut.MAX_SEEDS, "at most three at once")
	end)

	case("CT4 wiring: the service builds him from parts, squashes with a mesh, pushes in the beasts' slot, reads the stair", function()
		local service = sources.service
		has(service, 'require(ServerStorage:WaitForChild("WildboundCandyFrutillon"))')
		has(service, "Frut.step("); has(service, "Frut.seedStep("); has(service, "Frut.seedPath(Layout)")
		has(service, 'Instance.new("SpecialMesh")', "the squash"); has(service, '"WildboundBeastPush"', "one push at a time")
		assert(not string.find(service, "TakeDamage", 1, true) and not string.find(service, "Health -", 1, true), "never damage")
		assert(not string.find(service, "dropEgg", 1, true) and not string.find(service, "BeastHit", 1, true), "never the egg")
	end)

	return result
end

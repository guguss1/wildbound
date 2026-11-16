-- Invoke with require(freshTestClone)(require(freshCandyTortidragonAttackClone)).
-- Caramelo biome (odd/tasks/wildbound-caramelo.md, CA2; pack 03_PERSONAJES/03_TORTIDRAGON.md): Abanico de Confites,
-- Tortidragon's single attack, as pure rules: the pack's timeline, the fan, the three circles, one hit per player,
-- no cast at a target behind it, no damage, the egg kept, the pet refused.
return function(Abanico)
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
	local function player(id, x, z, extra)
		local p = { id = id, x = x, z = z, alive = true, safe = false }
		for k, v in pairs(extra or {}) do p[k] = v end
		return p
	end

	-- Deliberately changed (CF, user 2026-11-15, odd/tasks/wildbound-caramelo-v2.md): a faster cast. The aim is at the
	-- 0.8 s fair-strike floor, the lock moves so the sidestep still has 1 s, the recovery is shorter and the cooldown is
	-- about 4.5 s. Was: aim 1.00, lock 0.60, recover 0.85, cooldown 7.
	case("CF: the numbers: aim 0.80 s, lock at 0.45 s, flight 0.65 s, recover 0.60 s, cooldown 4.5 s, 55 deg, 12 studs, r 2.3", function()
		near(Abanico.TELEGRAPH_SECONDS, 0.8, "aim"); near(Abanico.LOCK_SECONDS, 0.45, "lock"); near(Abanico.RELEASE_SECONDS, 0.65, "flight")
		near(Abanico.RECOVER_SECONDS, 0.6, "recover"); near(Abanico.COOLDOWN_SECONDS, 4.5, "cooldown")
		assert(Abanico.TELEGRAPH_SECONDS >= 0.8 - 1e-9, "the aim is never under the 0.8 s floor")
		assert(Abanico.TELEGRAPH_SECONDS - Abanico.LOCK_SECONDS + Abanico.RELEASE_SECONDS >= 0.8 - 1e-9,
			"the locked circles leave at least 0.8 s to step out")
		near(Abanico.ARC_DEGREES, 55, "arc"); near(Abanico.RANGE_STUDS, 12, "range"); near(Abanico.SHOT_RADIUS_STUDS, 2.3, "radius")
		equal(Abanico.SHOTS, 3, "shots")
		assert(Abanico.TELEGRAPH_SECONDS + Abanico.RELEASE_SECONDS >= 0.8, "the impact comes less than 0.8 s after the tell")
		assert(Abanico.LOCK_SECONDS < Abanico.TELEGRAPH_SECONDS, "the lock is not before the release")
	end)

	case("the timeline from start: Telegraph, Release, Recover, Done at the pack's times", function()
		local s = Abanico.start(10, {})
		near(Abanico.lockAt(s), 10.45, "lock"); near(Abanico.releaseAt(s), 10.8, "release"); near(Abanico.impactAt(s), 11.45, "impact")
		near(Abanico.endsAt(s), 12.05, "end")
		equal(Abanico.phase(s, 10), "Telegraph"); equal(Abanico.phase(s, 10.79), "Telegraph"); equal(Abanico.phase(s, 10.8), "Release")
		equal(Abanico.phase(s, 11.44), "Release"); equal(Abanico.phase(s, 11.45), "Recover"); equal(Abanico.phase(s, 12.05), "Done")
	end)

	case("the fan: in front within 12 studs and 27.5 deg off the facing; never behind or to the side", function()
		equal(Abanico.inFan(O, 0, -1, { x = 0, z = -8 }), true, "straight ahead")
		equal(Abanico.inFan(O, 0, -1, { x = 0, z = -12.5 }), false, "past the range")
		local a = math.rad(25)
		equal(Abanico.inFan(O, 0, -1, { x = math.sin(a) * 8, z = -math.cos(a) * 8 }), true, "25 deg off")
		a = math.rad(30)
		equal(Abanico.inFan(O, 0, -1, { x = math.sin(a) * 8, z = -math.cos(a) * 8 }), false, "30 deg off")
		equal(Abanico.canCast(O, 0, -1, { x = 0, z = 6 }), false, "behind")
		equal(Abanico.canCast(O, 0, -1, { x = 6, z = 0 }), false, "to the side")
		local fan = Abanico.fan(O, 0, -2)
		equal(fan.kind, "sector"); near(fan.dz, -1, "normalised"); near(fan.r, 12, "range"); near(fan.arc, 55, "arc in degrees")
	end)

	case("three circles along the locked direction at the target's distance, all inside the fan", function()
		local shots = Abanico.shots(O, 0, -1, 8)
		equal(shots.kind, "multi"); equal(#shots.list, 3, "circles")
		near(shots.list[2].x, 0, "middle x"); near(shots.list[2].z, -8, "middle z")
		for i, c in ipairs(shots.list) do
			equal(c.kind, "circle"); near(c.r, 2.3, "radius " .. i)
			near(math.sqrt(c.x * c.x + c.z * c.z), 8, "distance " .. i)
			assert(Abanico.inFan(O, 0, -1, c), "circle " .. i .. " centre outside the fan")
		end
		assert(shots.list[1].x * shots.list[3].x < 0, "the side shots are on both sides")
		local far = Abanico.shots(O, 0, -1, 40)
		near(-far.list[2].z, 12 - 2.3, "clamped to the fan's edge")
		local close = Abanico.shots(O, 0, -1, 1)
		near(-close.list[2].z, 4, "never nearer than MIN_SHOT_STUDS")
	end)

	case("the impact hits each player once, even standing in two circles; nobody outside; never damage or the egg", function()
		local s = Abanico.start(0, {})
		local shots = Abanico.shots(O, 0, -1, 4) -- at 4 studs the circles overlap
		local between = { x = (shots.list[1].x + shots.list[2].x) / 2, z = (shots.list[1].z + shots.list[2].z) / 2 }
		local effects = Abanico.impact(s, shots, O, { player(1, between.x, between.z), player(2, 0, 6), player(3, 0, -4, { safe = true }),
			player(4, 0, -4, { alive = false }) })
		equal(#effects, 1, "effects")
		local e = effects[1]
		equal(e.id, 1); equal(e.damage, 0, "damage"); equal(e.dropEgg, false, "egg")
		near(e.slowFactor, 0.85, "stagger"); near(e.slowSeconds, 0.8, "stagger time")
		near(e.push.studs, 4, "light push"); assert(e.push.dz < 0, "the push goes away from the dragon")
		equal(#Abanico.impact(s, shots, O, { player(1, between.x, between.z) }), 0, "a second impact")
	end)

	case("dodge: stepping out of the fan sideways after the lock leaves the player outside every circle", function()
		local s = Abanico.start(0, {})
		local shots = Abanico.shots(O, 0, -1, 8)
		equal(#Abanico.impact(s, shots, O, { player(1, 6.5, -8) }), 0, "out to the side")
	end)

	case("the farm pet refuses; cooldown 4.5 s from the end", function()
		local s, why = Abanico.start(0, { pet = true })
		equal(s, nil, "pet state"); equal(why, "Pet")
		equal(Abanico.canStart(nil, 0), true, "first cast")
		equal(Abanico.canStart(10, 14.4), false, "4.4 s after"); equal(Abanico.canStart(10, 14.5), true, "4.5 s after")
	end)

	return result
end

-- Invoke with require(freshTestClone)(require(freshCandyDonGlaseonVacuumClone)).
-- Caramelo v2 (odd/tasks/wildbound-caramelo-v2.md, DG2): Boca aspiradora, Don Glaseon's vacuum mouth, as pure rules.
-- He opens his mouth (a cone drawn on the ground), then for 2 s every target in the cone with a clear line to him is
-- pulled toward him at a speed a walking player beats. No hit, no damage, no egg drop. Changes nothing.
return function(Vacuum)
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
	local function target(x, z, extra)
		local t = { x = x, z = z, alive = true, safe = false }
		for k, v in pairs(extra or {}) do t[k] = v end
		return t
	end

	case("DG2: the numbers: tell 0.9 s, pull 2 s, recover 0.6 s, cooldown 12 s, a 70-degree cone of 30 studs, 7 studs/s", function()
		near(Vacuum.TELEGRAPH_SECONDS, 0.9, "tell"); near(Vacuum.PULL_SECONDS, 2, "pull"); near(Vacuum.RECOVER_SECONDS, 0.6, "recover")
		near(Vacuum.COOLDOWN_SECONDS, 12, "cooldown"); near(Vacuum.RANGE_STUDS, 30, "range"); near(Vacuum.ARC_DEGREES, 70, "arc")
		near(Vacuum.PULL_SPEED, 7, "pull speed"); near(Vacuum.STOP_STUDS, 5, "no pull this close")
		near(Vacuum.CHASE_BEFORE_SECONDS, 2, "only after this long chasing a target out of the lash's reach")
		assert(Vacuum.TELEGRAPH_SECONDS >= 0.8, "under the fair-strike floor")
		assert(Vacuum.PULL_SPEED < 16 / 2, "a walking player (16) must beat the pull clearly")
		assert(Vacuum.PULL_HOLD_SECONDS > Vacuum.REFRESH_SECONDS, "a refreshed pull never has a gap")
		assert(Vacuum.PULL_HOLD_SECONDS <= 0.5, "a pull the server stops refreshing ends within half a second")
	end)

	case("DG2: the timeline: Inhale, Vacuum, Recover, Done", function()
		local s = Vacuum.start(10, {})
		near(Vacuum.pullAt(s), 10.9, "pull starts"); near(Vacuum.pullEndsAt(s), 12.9, "pull ends"); near(Vacuum.endsAt(s), 13.5, "end")
		near(Vacuum.totalSeconds(), 3.5, "the whole move")
		equal(Vacuum.phase(s, 10.5), "Inhale"); equal(Vacuum.phase(s, 11), "Vacuum"); equal(Vacuum.phase(s, 12.89), "Vacuum")
		equal(Vacuum.phase(s, 13), "Recover"); equal(Vacuum.phase(s, 13.5), "Done")
	end)

	case("DG2: the cone: in front, within 30 studs and 35 degrees off the facing; the shared sector shape", function()
		equal(Vacuum.inCone(O, 0, 1, { x = 0, z = 25 }), true, "straight ahead")
		equal(Vacuum.inCone(O, 0, 1, { x = 0, z = 30.5 }), false, "past the range")
		local a = math.rad(33)
		equal(Vacuum.inCone(O, 0, 1, { x = math.sin(a) * 20, z = math.cos(a) * 20 }), true, "33 degrees off")
		a = math.rad(37)
		equal(Vacuum.inCone(O, 0, 1, { x = math.sin(a) * 20, z = math.cos(a) * 20 }), false, "37 degrees off")
		equal(Vacuum.inCone(O, 0, 1, { x = 0, z = -10 }), false, "behind")
		local cone = Vacuum.cone(O, 0, 2)
		equal(cone.kind, "sector"); near(cone.dz, 1, "normalised"); near(cone.r, 30, "range"); near(cone.arc, 70, "arc in degrees")
	end)

	case("DG2: the pull: toward his mouth at 7 studs/s, only in the Vacuum phase, in the cone, with a clear line", function()
		local s = Vacuum.start(0, {})
		equal(Vacuum.pull(s, 0.5, O, 0, 1, target(0, 20), true), nil, "no pull during the tell")
		local p = Vacuum.pull(s, 1, O, 0, 1, target(3, 20), true)
		assert(p, "no pull in the cone")
		near(p.speed, 7, "speed"); assert(p.dz < -0.9, "the pull goes toward him")
		near(math.sqrt(p.dx ^ 2 + p.dz ^ 2), 1, "a unit direction")
		near(p.untilAt, 1 + Vacuum.PULL_HOLD_SECONDS, "valid a moment")
		near(Vacuum.pull(s, 2.8, O, 0, 1, target(0, 20), true).untilAt, 2.9, "never past the pull's end")
		equal(Vacuum.pull(s, 1, O, 0, 1, target(0, 20), false), nil, "behind cover: no pull")
		equal(Vacuum.pull(s, 1, O, 0, 1, target(0, -20), true), nil, "behind him")
		equal(Vacuum.pull(s, 1, O, 0, 1, target(0, 4), true), nil, "already at his mouth")
		equal(Vacuum.pull(s, 1, O, 0, 1, target(0, 20, { safe = true }), true), nil, "a safe zone")
		equal(Vacuum.pull(s, 1, O, 0, 1, target(0, 20, { alive = false }), true), nil, "dead")
		equal(Vacuum.pull(s, 3, O, 0, 1, target(0, 20), true), nil, "after the pull")
	end)

	case("DG2: never damage, never the egg; the farm pet never uses it; a new one waits for the cooldown", function()
		local s = Vacuum.start(0, {})
		local p = Vacuum.pull(s, 1, O, 0, 1, target(0, 20, { carrying = true }), true)
		equal(p.damage, nil, "no damage"); equal(p.dropEgg, nil, "no egg drop")
		local pet, why = Vacuum.start(0, { pet = true })
		equal(pet, nil); equal(why, "Pet")
		equal(Vacuum.canStart(nil, 0), true); equal(Vacuum.canStart(5, 16.9), false); equal(Vacuum.canStart(5, 17), true)
	end)

	return result
end

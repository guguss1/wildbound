-- Invoke with require(freshTestClone)(require(freshCandyDonGlaseonWallClone)).
-- Caramelo v2 (odd/tasks/wildbound-caramelo-v2.md, DG3): Muro de chocolate, Don Glaseon's chocolate wall, as pure rules.
-- A ring of wall rises around the spot a fleeing target is running to, after a crack line on the floor, and stands a
-- few seconds. It always leaves a wide exit on the side away from him; it never hits. Changes nothing.
return function(Wall)
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
	local BOSS = { x = 0, y = 0, z = 0 }
	local function runner(x, z, vx, vz) return { x = x, y = 3, z = z, vx = vx, vz = vz, alive = true, safe = false } end

	case("DG3: the numbers: crack line 1.0 s, wall up 3 s, cooldown 14 s, a ring of 9 studs with a 140-degree exit", function()
		near(Wall.TELEGRAPH_SECONDS, 1.0, "crack line"); near(Wall.HOLD_SECONDS, 3, "up"); near(Wall.COOLDOWN_SECONDS, 14, "cooldown")
		near(Wall.RADIUS_STUDS, 9, "radius"); near(Wall.GAP_DEGREES, 140, "exit opening")
		near(Wall.LEAD_SECONDS, 0.5, "lead"); near(Wall.MAX_LEAD_STUDS, 8, "lead cap"); near(Wall.MIN_SPEED, 10, "only on a runner")
		near(Wall.OUT_OF_REACH_SECONDS, 1, "out of the lash's reach this long"); near(Wall.RANGE_STUDS, 30, "range")
		assert(Wall.TELEGRAPH_SECONDS >= 0.8, "the crack line shows at least 0.8 s ahead")
	end)

	case("DG3: the timeline: the crack line, then the wall up, then down", function()
		local s = Wall.start(10, {})
		near(Wall.upAt(s), 11, "up"); near(Wall.downAt(s), 14, "down")
		equal(Wall.phase(s, 10.5), "Crack"); equal(Wall.phase(s, 11), "Up"); equal(Wall.phase(s, 13.9), "Up"); equal(Wall.phase(s, 14), "Done")
		local pet, why = Wall.start(0, { pet = true })
		equal(pet, nil); equal(why, "Pet")
		equal(Wall.canStart(nil, 0), true); equal(Wall.canStart(5, 18.9), false); equal(Wall.canStart(5, 19), true)
	end)

	case("DG3: placed across the runner's route: around the spot 0.5 s ahead, the shared walls shape", function()
		local shape = Wall.place(BOSS, runner(0, 20, 0, 14))
		assert(shape, "no wall for a runner")
		equal(shape.kind, "walls"); near(shape.r, 9, "radius")
		near(shape.x, 0, "x on the route"); near(shape.z, 27, "0.5 s ahead (14 x 0.5)")
		local fast = Wall.place(BOSS, runner(0, 20, 0, 40))
		near(fast.z, 28, "the lead never passes 8 studs")
		equal(#shape.list, 2, "two walls meeting opposite the exit")
	end)

	case("DG3: never sealed: the exit is wide, sideways, on the side away from him", function()
		local shape = Wall.place({ x = -6, y = 0, z = 0 }, runner(0, 20, 0, 14))
		near(Wall.exitWidth(shape), 2 * 9 * math.sin(math.rad(70)), "the exit's chord", 1e-6)
		assert(Wall.exitWidth(shape) >= 16, "an exit of at least 16 studs")
		near(math.sqrt(shape.gx ^ 2 + shape.gz ^ 2), 1, "a unit direction")
		assert(math.abs(shape.gz) < 1e-6, "the exit is sideways to the route")
		assert(shape.gx > 0, "on the side away from him (he stands at -x)")
		near(shape.gap, Wall.exitWidth(shape), "the shape's gap is the exit")
		-- the walls cover the route ahead and behind the target, never the exit
		local half = shape.list[1].from
		near(math.deg(half), 70, "half the opening", 1e-6)
		near(shape.list[2].to, 2 * math.pi - half, "the second wall ends at the other exit post", 1e-9)
	end)

	case("DG3: only on a target running away from him", function()
		equal(Wall.place(BOSS, runner(0, 20, 0, 0)), nil, "a still target")
		equal(Wall.place(BOSS, runner(0, 20, 0, 6)), nil, "a slow walk")
		equal(Wall.place(BOSS, runner(0, 20, 0, -14)), nil, "running toward him")
		equal(Wall.place(BOSS, runner(0, 20, 14, 0)), nil, "running across, not away")
		equal(Wall.place(BOSS, { x = 0, z = 20, vx = 0, vz = 14, alive = true, safe = true }), nil, "in a safe zone")
		assert(Wall.place(BOSS, runner(0, 20, 6, 14)) ~= nil, "running away at an angle")
	end)

	return result
end

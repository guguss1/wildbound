-- Invoke with require(freshTestClone)(require(freshHideClone)).
-- Delivery D5: hiding spots as a server rule. Who may enter, how the guardian finds a hidden player by
-- standing near the spot for a dwell time, the 45 s limit and the exit point. Pure: numbers in, answers out.
return function(Hide)
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
	local function entry(overrides)
		local ctx = { alive = true, capturing = false, occupied = false, seen = false, cooldownUntil = 0, now = 100 }
		for key, value in pairs(overrides or {}) do ctx[key] = value end
		return ctx
	end
	local function guardian(mode, distance, phase, targetIsMe)
		return { dt = 0.2, mode = mode, distance = distance, phase = phase or "Day", targetIsMe = targetIsMe == true }
	end
	local function dwellFor(state, input, seconds)
		local found = false
		for _ = 1, math.ceil(seconds / input.dt - 1e-9) do found = Hide.discover(state, input) or found end
		return found
	end

	case("D5: seen, occupied, cooldown, capturing and dead refuse with a reason", function()
		local function refused(reason, overrides)
			local ok, why = Hide.canEnter(entry(overrides))
			equal(ok, false, reason)
			equal(why, reason)
		end
		refused("Dead", { alive = false })
		refused("Capturing", { capturing = true })
		refused("Occupied", { occupied = true })
		refused("Seen", { seen = true })
		refused("Cooldown", { cooldownUntil = 105, now = 100 })
		-- Dead wins over everything else; a nil context is refused, never an error.
		refused("Dead", { alive = false, capturing = true, occupied = true, seen = true })
		equal(select(2, Hide.canEnter(nil)), "Dead")
		equal((Hide.canEnter(entry({ cooldownUntil = 100, now = 100 }))), true, "the cooldown ends on time")
	end)

	case("D5: searching is allowed", function()
		local ok, why = Hide.canEnter(entry())
		equal(ok, true)
		equal(why, nil)
	end)

	case("D5: discovery needs the radius and the dwell by phase", function()
		for phase, row in pairs({ Day = { 4, 2.0 }, Dusk = { 5, 1.6 }, Dawn = { 5, 1.6 }, Night = { 6, 1.2 } }) do
			equal(Hide.CONFIG.DISCOVER[phase].radius, row[1], phase .. " radius")
			equal(Hide.CONFIG.DISCOVER[phase].dwell, row[2], phase .. " dwell")
			local state = Hide.newDwell()
			local near = guardian("Search", row[1] - 0.1, phase)
			equal(dwellFor(state, near, row[2] - 0.2), false, phase .. " found too soon")
			equal(dwellFor(state, near, 0.2), true, phase .. " not found at the dwell")
			local far = Hide.newDwell()
			equal(dwellFor(far, guardian("Search", row[1] + 0.1, phase), 30), false, phase .. " found from outside")
		end
		for _, mode in ipairs({ "Patrol", "Suspicious", "Investigate", "Search", "Retreat" }) do
			equal(dwellFor(Hide.newDwell(), guardian(mode, 1, "Night"), 1.2), true, mode)
		end
	end)

	case("D5: the dwell decays twice as fast outside", function()
		local state = Hide.newDwell()
		dwellFor(state, guardian("Search", 1, "Day"), 1.0)
		equal(math.abs(state.dwell - 1.0) < 1e-6, true, "one second inside")
		dwellFor(state, guardian("Search", 10, "Day"), 0.4)
		equal(math.abs(state.dwell - 0.2) < 1e-6, true, "0.4 s outside takes 0.8 s off")
		dwellFor(state, guardian("Search", 10, "Day"), 5)
		equal(state.dwell, 0, "never below zero")
	end)

	case("D5: a hunt on another player still discovers", function()
		for _, mode in ipairs({ "Alert", "Hunt", "Telegraph" }) do
			equal(dwellFor(Hide.newDwell(), guardian(mode, 1, "Day", false), 2.0), true, mode .. " on another player")
			equal(dwellFor(Hide.newDwell(), guardian(mode, 1, "Day", true), 10), false, mode .. " on this player has lost sight")
		end
	end)

	case("D5: 45 s forces an exit and an 8 s cooldown", function()
		equal(Hide.CONFIG.MAX_STAY, 45)
		equal(Hide.CONFIG.COOLDOWN, 8)
		equal(Hide.tooLong(10, 54.9), false)
		equal(Hide.tooLong(10, 55), true)
		equal(Hide.cooldownUntil(55), 63)
		equal(Hide.tooLong(nil, 55), false)
		local point = Hide.exitPoint(10, 20, 0, 20)
		equal(math.abs((point.x - 10) ^ 2 + (point.z - 20) ^ 2 - Hide.CONFIG.EXIT_DISTANCE ^ 2) < 1e-6, true, "exit distance")
		equal(point.x > 10, true, "the exit faces away from the guardian")
		local fallback = Hide.exitPoint(10, 20, nil, nil)
		equal(math.abs(fallback.x - (10 + Hide.CONFIG.EXIT_DISTANCE)) < 1e-6, true, "no guardian: a fixed side")
	end)

	case("D5: bad numbers never discover", function()
		for _, bad in ipairs({ 0 / 0, math.huge, -1, "1" }) do
			local state = Hide.newDwell()
			equal(dwellFor(state, guardian("Search", bad, "Night"), 5), false, "distance " .. tostring(bad))
			local input = guardian("Search", 1, "Night")
			input.dt = bad
			equal(Hide.discover(Hide.newDwell(), input), false, "dt " .. tostring(bad))
		end
		equal(Hide.discover(nil, guardian("Search", 1)), false)
		equal(Hide.discover(Hide.newDwell(), nil), false)
		equal(dwellFor(Hide.newDwell(), guardian("Dead", 1, "Night"), 5), false, "unknown mode")
		equal(Hide.CONFIG.DISCOVER.Moon, nil)
		equal(dwellFor(Hide.newDwell(), guardian("Search", 3.9, "Moon"), 2.0), true, "unknown phase reads as Day")
	end)

	return result
end

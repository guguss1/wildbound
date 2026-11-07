-- Invoke with require(freshTestClone)(require(freshPathClone), freshPathClone.Source).
-- Delivery C2: when La Silueta plans a route, which waypoint it steers to, and how a stall is noticed. Pure: the
-- world script runs PathfindingService and passes the waypoints in; the clock is injected.
return function(Path, source)
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
	local C = Path.CONSTANTS
	local function planned(state, goalX, goalZ, now, points)
		local serial = Path.begin(state, goalX, goalZ, now)
		Path.finish(state, serial, true, points, now)
		return serial
	end
	local ROUTE = { { x = 0, z = 0 }, { x = 10, z = 0 }, { x = 10, z = 10 } }

	case("constants are frozen and keep the step readable", function()
		assert(table.isfrozen(C), "frozen")
		assert(C.MIN_INTERVAL >= 0.2, "never plans every step")
		assert(C.STALL_SECONDS > C.MIN_INTERVAL, "a stall is longer than a planning interval")
		assert(C.REACH > 0 and C.REPATH_DISTANCE > C.REACH)
	end)

	case("a fresh navigator wants a plan, and never two at once", function()
		local state = Path.new()
		equal(Path.needsPlan(state, 10, 10, 0), true)
		Path.begin(state, 10, 10, 0)
		equal(Path.needsPlan(state, 10, 10, 5), false, "pending")
		equal(state.counters.plans, 1)
	end)

	case("a finished plan is followed waypoint by waypoint, then arrives", function()
		local state = Path.new()
		planned(state, 10, 10, 0, ROUTE)
		local x, z = Path.steer(state, 0, 0, 0.1)
		equal(x, 10); equal(z, 0, "the start point is skipped once reached")
		x, z = Path.steer(state, 9, 0, 0.2)
		equal(x, 10); equal(z, 10)
		x, z = Path.steer(state, 10, 9, 0.3)
		equal(x, nil, "arrived"); equal(state.counters.arrivals, 1)
		equal(Path.steer(state, 10, 9, 0.4), nil)
	end)

	case("a moved goal asks for a new plan, but not faster than the minimum interval", function()
		local state = Path.new()
		planned(state, 10, 10, 0, ROUTE)
		equal(Path.needsPlan(state, 10 + C.REPATH_DISTANCE - 0.1, 10, 5), false, "small moves keep the plan")
		equal(Path.needsPlan(state, 10 + C.REPATH_DISTANCE + 0.1, 10, C.MIN_INTERVAL - 0.01), false, "too soon")
		equal(Path.needsPlan(state, 10 + C.REPATH_DISTANCE + 0.1, 10, C.MIN_INTERVAL), true)
	end)

	case("a stale result is ignored after the navigator was cleared or replanned", function()
		local state = Path.new()
		local first = Path.begin(state, 10, 10, 0)
		Path.clear(state)
		equal(Path.finish(state, first, true, ROUTE, 0.2), false, "cleared")
		equal(Path.steer(state, 0, 0, 0.3), nil)
		local second = Path.begin(state, 20, 0, 1)
		equal(Path.finish(state, first, true, ROUTE, 1.1), false, "old serial")
		equal(Path.finish(state, second, true, { { x = 0, z = 0 }, { x = 20, z = 0 } }, 1.2), true)
		equal(Path.steer(state, 0, 0, 1.3), 20)
	end)

	case("a failed plan waits before it retries, and counts", function()
		local state = Path.new()
		local serial = Path.begin(state, 10, 10, 0)
		Path.finish(state, serial, false, nil, 0.1)
		equal(state.counters.failures, 1)
		equal(Path.steer(state, 0, 0, 0.2), nil, "nothing to follow")
		equal(Path.needsPlan(state, 10, 10, 0.1 + C.RETRY_SECONDS - 0.01), false)
		equal(Path.needsPlan(state, 10, 10, 0.1 + C.RETRY_SECONDS), true)
		serial = Path.begin(state, 10, 10, 2)
		Path.finish(state, serial, true, {}, 2.1)
		equal(state.counters.failures, 2, "an empty route is a failure")
	end)

	case("no progress for the stall time drops the plan, counts a stall and allows a new plan at once", function()
		local state = Path.new()
		planned(state, 10, 10, 0, ROUTE)
		equal(Path.steer(state, 0, 0, 0), 10)
		equal(Path.steer(state, 1, 0, 0.5), 10, "progress")
		equal(Path.steer(state, 1.2, 0, 0.5 + C.STALL_SECONDS - 0.01), 10, "under half a stud is not progress, not yet a stall")
		equal(Path.steer(state, 1.2, 0, 0.5 + C.STALL_SECONDS), nil, "stalled")
		equal(state.counters.stalls, 1)
		equal(Path.needsPlan(state, 10, 10, 0.5 + C.STALL_SECONDS), true)
	end)

	case("bad numbers never steer and never plan", function()
		local state = Path.new()
		equal(Path.needsPlan(state, 0 / 0, 1, 0), false)
		equal(Path.needsPlan(state, 1, 1, math.huge), false)
		planned(state, 10, 10, 0, ROUTE)
		equal(Path.steer(state, 0 / 0, 0, 1), nil)
		local serial = Path.begin(state, 5, 5, 3)
		equal(Path.finish(state, serial, true, { { x = 0 / 0, z = 1 } }, 3.1), true)
		equal(state.counters.failures, 1, "a route with a bad point is a failure")
	end)

	case("same inputs, same steering", function()
		local function run()
			local state = Path.new()
			planned(state, 10, 10, 0, ROUTE)
			local trace, x, z = {}, 0, 0
			for step = 1, 40 do
				local tx, tz = Path.steer(state, x, z, step * 0.2)
				if not tx then break end
				local dx, dz = tx - x, tz - z
				local length = math.sqrt(dx * dx + dz * dz)
				if length > 0 then x, z = x + dx / length * math.min(length, 1.6), z + dz / length * math.min(length, 1.6) end
				table.insert(trace, ("%.3f,%.3f"):format(x, z))
			end
			return table.concat(trace, "|")
		end
		local a = run()
		equal(a, run()); assert(#a > 0)
	end)

	case("purity: no services, no clock, no randomness, no require", function()
		assert(type(source) == "string" and #source > 0, "source given")
		for _, banned in ipairs({ "game:", "workspace", "require(", "task.", "os.clock", "os.time", "tick(", "Random", "math.random" }) do
			assert(not source:find(banned, 1, true), "contains " .. banned)
		end
	end)

	return result
end

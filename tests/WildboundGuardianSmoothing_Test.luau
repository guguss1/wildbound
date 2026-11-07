-- Invoke with require(freshTestClone)(require(freshSmoothingClone), freshSmoothingClone.Source) in Studio.
-- Pure numbers only: poses are (x, y, z, yaw) and time is injected.
return function(Smoothing, source)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected)
		assert(actual == expected, "Expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function near(actual, expected, tolerance)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-6),
			"Expected " .. tostring(expected) .. " +- " .. tostring(tolerance or 1e-6) .. ", got " .. tostring(actual))
	end
	local NAN, INF = 0 / 0, math.huge
	local CONST = Smoothing.CONSTANTS

	-- A guardian walking along +x in server steps, as the baseline measured it: every 0.2 s.
	local function walk(state, steps, stepStuds, gap, startAt)
		local now = startAt or 0
		for index = 0, steps do
			Smoothing.observe(state, now + index * gap, index * stepStuds, 3.7, 0, 0)
		end
		return now + steps * gap
	end

	case("nothing is shown before the first server pose", function()
		equal(Smoothing.sample(Smoothing.new(), 0), nil)
		equal(Smoothing.sample(nil, 0), nil)
		equal(Smoothing.sample({}, 0), nil)
	end)

	case("the first pose is shown at once, with no slide from the origin", function()
		local state = Smoothing.new()
		equal(Smoothing.observe(state, 10, 40, 3.7, -85, 1), true)
		for _, now in ipairs({ 10, 10.05, 10.2, 50 }) do
			local x, y, z, yaw = Smoothing.sample(state, now)
			equal(x, 40); equal(y, 3.7); equal(z, -85); equal(yaw, 1)
		end
	end)

	case("a new pose is reached one step later, with no jump at the moment it arrives", function()
		local state = Smoothing.new()
		Smoothing.observe(state, 0, 0, 0, 0, 0)
		Smoothing.observe(state, 0.2, 0.6, 0, 0, 0)
		near(Smoothing.sample(state, 0.2), 0)
		near(Smoothing.sample(state, 0.3), 0.3)
		near(Smoothing.sample(state, 0.4), 0.6)
		near(Smoothing.sample(state, 9), 0.6)
	end)

	case("patrol steps of 0.6 studs move a little every frame at 60 FPS instead of 0.6 at once", function()
		local state = Smoothing.new()
		Smoothing.observe(state, 0, 0, 0, 0, 0)
		local latest, previous, biggest, smallest = 0, 0, 0, math.huge
		local frame = 1 / 60
		for index = 1, 600 do
			local now = index * frame
			if index % 12 == 0 then
				latest += 0.6
				Smoothing.observe(state, now, latest, 0, 0, 0)
			end
			local x = Smoothing.sample(state, now)
			if now > 0.45 then
				biggest = math.max(biggest, x - previous)
				smallest = math.min(smallest, x - previous)
			end
			previous = x
		end
		assert(biggest <= 0.6 / 12 + 1e-6, "per-frame step too large: " .. biggest)
		assert(smallest >= 0.6 / 12 - 1e-6, "a frame stood still: " .. smallest)
	end)

	case("at the baseline 15 FPS the per-frame step stays under a quarter of the raw 0.6 stud jump", function()
		local state = Smoothing.new()
		Smoothing.observe(state, 0, 0, 0, 0, 0)
		local latest, previous, biggest = 0, 0, 0
		for index = 1, 150 do
			local now = index / 15
			if index % 3 == 0 then
				latest += 0.6
				Smoothing.observe(state, now, latest, 0, 0, 0)
			end
			local x = Smoothing.sample(state, now)
			if now > 0.5 then biggest = math.max(biggest, x - previous) end
			previous = x
		end
		assert(biggest <= 0.6 / 3 + 1e-6, "per-frame step too large: " .. biggest)
	end)

	case("the shown speed equals the server speed, so a hunt step of 1.2 studs never looks faster", function()
		local state = Smoothing.new()
		local shown = {}
		for index = 0, 40 do
			local now = index * 0.2
			Smoothing.observe(state, now, index * 1.2, 3.7, 0, 0)
			shown[index] = Smoothing.sample(state, now + 0.1)
		end
		-- One second apart, the shown pose has moved by exactly what the server moved: 6 studs.
		near(shown[15] - shown[10], 6, 1e-6)
		near(shown[40] - shown[20], 24, 1e-6)
		near(Smoothing.sample(state, 40 * 0.2 + 5), 48)
	end)

	case("the shown pose never trails the latest server pose by more than one step of travel", function()
		local state = Smoothing.new()
		Smoothing.observe(state, 0, 0, 0, 0, 0)
		local worst = 0
		for step = 1, 60 do
			local arrival = step * 0.2
			Smoothing.observe(state, arrival, step * 1.2, 0, 0, 0)
			for offset = 0, 9 do
				local now = arrival + offset * 0.02
				worst = math.max(worst, step * 1.2 - Smoothing.sample(state, now))
			end
		end
		assert(worst <= 1.2 + 1e-6, "lag exceeded one step: " .. worst)
	end)

	case("straight motion never overshoots, reverses, or runs ahead of the server", function()
		local state = Smoothing.new()
		-- The measured patrol jitter: median 0.2 s, p95 0.267 s.
		local gaps = { 0.2, 0.267, 0.15, 0.2, 0.267, 0.2, 0.18, 0.25, 0.2, 0.267, 0.2, 0.16 }
		local now, latest, previous = 0, 0, 0
		Smoothing.observe(state, 0, 0, 0, 0, 0)
		for index, gap in ipairs(gaps) do
			now += gap
			latest += 0.6
			Smoothing.observe(state, now, latest, 0, 0, 0)
			-- Sample only until the next server step arrives, so the clock never runs backwards.
			local untilNext = gaps[index + 1] or 0.3
			for offset = 0, math.floor(untilNext / 0.01 - 0.5) do
				local x = Smoothing.sample(state, now + offset * 0.01)
				assert(x >= previous - 1e-9, "moved backwards")
				assert(x <= latest + 1e-9, "ran ahead of the server")
				previous = x
			end
		end
	end)

	case("a pause settles exactly on the last pose and stays there", function()
		local state = Smoothing.new()
		local endAt = walk(state, 5, 1.2, 0.2)
		for _, wait in ipairs({ 0.2, 1, 5, 600 }) do
			local x, y, z = Smoothing.sample(state, endAt + wait)
			equal(x, 6); equal(y, 3.7); equal(z, 0)
		end
	end)

	case("the first step after a long pause still takes one normal interval", function()
		local state = Smoothing.new()
		local endAt = walk(state, 5, 1.2, 0.2)
		local resume = endAt + 3.6
		Smoothing.observe(state, resume, 7.2, 3.7, 0, 0)
		near(Smoothing.sample(state, resume), 6)
		near(Smoothing.sample(state, resume + 0.1), 6.6, 1e-6)
		near(Smoothing.sample(state, resume + 0.2), 7.2, 1e-6)
	end)

	case("the interval follows a steady faster or slower server step and stays within its clamp", function()
		for _, gap in ipairs({ 0.1, 0.3 }) do
			local state = Smoothing.new()
			local endAt = walk(state, 12, 1, gap)
			Smoothing.observe(state, endAt + gap, 13, 3.7, 0, 0)
			near(Smoothing.sample(state, endAt + gap + gap), 13, 1e-3)
			assert(Smoothing.sample(state, endAt + gap + gap / 2) < 13, "arrived early")
		end
		local state = Smoothing.new()
		walk(state, 12, 1, 0.01)
		Smoothing.observe(state, 0.13, 13, 3.7, 0, 0)
		assert(Smoothing.sample(state, 0.13 + CONST.MIN_INTERVAL / 2) < 13, "interval dropped under its minimum")
	end)

	case("a repeated pose is ignored and does not restart the slide", function()
		local state = Smoothing.new()
		Smoothing.observe(state, 0, 0, 0, 0, 0)
		Smoothing.observe(state, 0.2, 0.6, 0, 0, 0)
		equal(Smoothing.observe(state, 0.3, 0.6, 0, 0, 0), false)
		near(Smoothing.sample(state, 0.3), 0.3)
		near(Smoothing.sample(state, 0.4), 0.6)
	end)

	case("a jump larger than any real step snaps instead of sliding", function()
		local state = Smoothing.new()
		Smoothing.observe(state, 0, 0, 0, 0, 0)
		Smoothing.observe(state, 0.2, CONST.SNAP_DISTANCE + 1, 0, 0, 0)
		near(Smoothing.sample(state, 0.2), CONST.SNAP_DISTANCE + 1)
		local almost = Smoothing.new()
		Smoothing.observe(almost, 0, 0, 0, 0, 0)
		Smoothing.observe(almost, 0.2, CONST.SNAP_DISTANCE - 0.5, 0, 0, 0)
		near(Smoothing.sample(almost, 0.2), 0)
	end)

	case("the snap distance sits above the largest real step and below a teleport", function()
		-- Night hunt at speed 8 is 1.6 studs per 0.2 s step; Retreat is 1.2. Home is 85 studs away.
		assert(CONST.SNAP_DISTANCE > 1.6 * 2, "a stalled frame of two steps must still slide")
		assert(CONST.SNAP_DISTANCE < 20, "a teleport must not be smeared across the map")
	end)

	case("turning takes the short way round, never the long way through zero", function()
		local state = Smoothing.new()
		Smoothing.observe(state, 0, 0, 0, 0, math.pi - 0.1)
		Smoothing.observe(state, 0.2, 0.6, 0, 0, -math.pi + 0.1)
		local _, _, _, yaw = Smoothing.sample(state, 0.3)
		assert(math.cos(yaw) < -0.99, "turned through the wrong side: " .. yaw)
		local _, _, _, finish = Smoothing.sample(state, 0.4)
		near(math.cos(finish), math.cos(-math.pi + 0.1), 1e-9)
	end)

	case("height is carried and smoothed with the rest of the pose", function()
		local state = Smoothing.new()
		Smoothing.observe(state, 0, 0, 3.7, 0, 0)
		Smoothing.observe(state, 0.2, 0.6, 4.1, 0, 0)
		local _, y = Smoothing.sample(state, 0.3)
		near(y, 3.9, 1e-9)
	end)

	case("bad numbers are rejected and leave the pose and the timing alone", function()
		local state = Smoothing.new()
		Smoothing.observe(state, 0, 0, 0, 0, 0)
		Smoothing.observe(state, 0.2, 0.6, 0, 0, 0)
		for _, bad in ipairs({ NAN, INF, -INF, "1", false }) do
			equal(Smoothing.observe(state, 0.25, bad, 0, 0, 0), false)
			equal(Smoothing.observe(state, 0.25, 1, bad, 0, 0), false)
			equal(Smoothing.observe(state, 0.25, 1, 0, bad, 0), false)
			equal(Smoothing.observe(state, 0.25, 1, 0, 0, bad), false)
			equal(Smoothing.observe(state, bad, 1, 0, 0, 0), false)
		end
		near(Smoothing.sample(state, 0.3), 0.3)
		equal(Smoothing.observe(nil, 0, 0, 0, 0, 0), false)
		equal(Smoothing.observe("x", 0, 0, 0, 0, 0), false)
	end)

	case("sampling with a bad clock returns the latest pose without an error", function()
		local state = Smoothing.new()
		Smoothing.observe(state, 0, 0, 0, 0, 0)
		Smoothing.observe(state, 0.2, 0.6, 0, 0, 0)
		for _, bad in ipairs({ NAN, INF, -INF, "1", false }) do
			near(Smoothing.sample(state, bad), 0.6)
		end
	end)

	case("a clock that steps back never produces a pose outside the two ends", function()
		local state = Smoothing.new()
		Smoothing.observe(state, 10, 0, 0, 0, 0)
		Smoothing.observe(state, 10.2, 0.6, 0, 0, 0)
		near(Smoothing.sample(state, 5), 0)
		Smoothing.observe(state, 4, 1.2, 0, 0, 0)
		local x = Smoothing.sample(state, 4.1)
		assert(x >= 0 and x <= 1.2, "outside the two ends: " .. x)
		near(Smoothing.sample(state, 4.2), 1.2, 1e-6)
	end)

	case("reset forgets the pose so a respawned guardian never slides from the old place", function()
		local state = Smoothing.new()
		walk(state, 3, 1.2, 0.2)
		Smoothing.reset(state)
		equal(Smoothing.sample(state, 5), nil)
		Smoothing.observe(state, 5, 80, 3.7, 20, 2)
		near(Smoothing.sample(state, 5), 80)
	end)

	case("two smoothing states do not share a pose or timing", function()
		local first, second = Smoothing.new(), Smoothing.new()
		walk(first, 3, 1.2, 0.2)
		equal(Smoothing.sample(second, 1), nil)
		Smoothing.observe(second, 0, 50, 0, 0, 0)
		near(Smoothing.sample(first, 100), 3.6)
		near(Smoothing.sample(second, 100), 50)
	end)

	case("constants are frozen and tie the interval to the 0.2 s server step", function()
		assert(table.isfrozen(CONST), "constants must be frozen")
		equal(CONST.DEFAULT_INTERVAL, 0.2)
		assert(CONST.MIN_INTERVAL <= CONST.DEFAULT_INTERVAL and CONST.DEFAULT_INTERVAL <= CONST.MAX_INTERVAL,
			"default must sit inside the clamp")
		assert(CONST.MAX_INTERVAL <= 0.4, "a slide longer than two steps would look like lag")
	end)

	case("the module source stays pure and never touches the world or the server", function()
		assert(type(source) == "string" and #source > 0, "module source is required")
		for _, token in ipairs({ "game", "workspace", "script", "Instance", "require", "task", "tick",
			"wait", "os", "time", "GetService", "RunService", "RemoteEvent", "FireClient", "CFrame",
			"Vector3", "DateTime", "math%.random", "Random", "Body", "TakeDamage" }) do
			assert(not string.find(source, "%f[%w_]" .. token .. "%f[^%w_]"), "impure token: " .. token)
		end
	end)

	return result
end

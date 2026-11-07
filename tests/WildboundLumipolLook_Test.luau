-- Invoke with require(freshTestClone)(require(freshLookClone), freshLookClone.Source).
-- Delivery A3: how the client draws a wild Lumipol between server steps and how it shows its mood on the
-- provisional primitive model (decision H4: no uploads). Pure: time and positions are passed in.
return function(Look, source)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "Expected " .. tostring(expected)
			.. ", got " .. tostring(actual))
	end
	local function near(actual, expected, tolerance, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-6),
			(label and label .. ": " or "") .. "Expected about " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local NAN, INF = 0 / 0, math.huge
	local K = Look.CONSTANTS or {}
	local function pose(x, z, fx, fz) return { x = x, z = z, fx = fx or 0, fz = fz or -1 } end

	case("A3: constants are frozen and the follow rate catches up within half a second", function()
		assert(table.isfrozen(Look.CONSTANTS), "frozen")
		assert(math.exp(-K.FOLLOW_RATE * 0.5) < 0.01, "over 99% of the gap closed in 0.5 s")
		assert(K.SNAP_DISTANCE > 10, "a flee step never snaps")
	end)

	case("A3: following moves part of the way, never past the target, and arrives", function()
		local current = pose(0, 0)
		local target = pose(2, 0, 1, 0)
		local step = Look.follow(current, target, 1 / 60)
		assert(step.x > 0 and step.x < 2, "part of the way: " .. step.x)
		near(step.x, 2 * (1 - math.exp(-K.FOLLOW_RATE / 60)), 1e-9)
		local at = current
		for _ = 1, 120 do at = Look.follow(at, target, 1 / 60) end
		near(at.x, 2, 1e-3); near(at.z, 0, 1e-9)
		assert(at ~= target and step ~= current, "fresh tables")
	end)

	case("A3: facing turns smoothly and stays a unit vector", function()
		local at = pose(0, 0, 0, -1)
		local target = pose(0, 0, 1, 0)
		local first = Look.follow(at, target, 1 / 60)
		near(math.sqrt(first.fx ^ 2 + first.fz ^ 2), 1, 1e-9)
		assert(first.fx > 0 and first.fx < 1, "turned part of the way")
		for _ = 1, 120 do at = Look.follow(at, target, 1 / 60) end
		near(at.fx, 1, 1e-3)
		local opposite = Look.follow(pose(0, 0, 1, 0), pose(0, 0, -1, 0), 1 / 60)
		near(math.sqrt(opposite.fx ^ 2 + opposite.fz ^ 2), 1, 1e-9, "a half turn still gives a unit vector")
	end)

	case("A3: a far jump (respawn, streaming back in) snaps, and junk input snaps to the target", function()
		local snapped = Look.follow(pose(0, 0), pose(K.SNAP_DISTANCE + 1, 0, 1, 0), 1 / 60)
		equal(snapped.x, K.SNAP_DISTANCE + 1); equal(snapped.fx, 1)
		for _, dt in ipairs({ NAN, INF, -1, 0 }) do
			local held = Look.follow(pose(0, 0), pose(1, 0), dt)
			equal(held.x, 0, "a bad step holds still: " .. tostring(dt))
		end
		equal(Look.follow(nil, pose(3, 4), 0.1).x, 3)
		equal(Look.follow(pose(NAN, 0), pose(3, 4), 0.1).x, 3)
		equal(Look.follow(pose(1, 1), nil, 0.1), nil)
		local huge = Look.follow(pose(0, 0), pose(2, 0), 9)
		near(huge.x, 2, 1e-6, "a long frame lands on the target")
	end)

	case("A3: Curious hops a little and twitches its ears; nothing else hops", function()
		local hopped, twitched = 0, 0
		for index = 0, 300 do
			local p = Look.pose("Curious", false, index / 60, false)
			assert(p.hop >= 0 and p.hop <= K.HOP_HEIGHT + 1e-9, "hop " .. p.hop)
			if p.hop > 0.05 then hopped += 1 end
			if math.abs(p.ear) > 0.1 then twitched += 1 end
			equal(p.mark, false)
		end
		assert(hopped > 10 and twitched > 5, ("hopped %d, twitched %d"):format(hopped, twitched))
		for _, mode in ipairs({ "Idle", "Wander", "Alert", "Flee", "Hide", "Reserved", "Captured" }) do
			for index = 0, 60 do equal(Look.pose(mode, false, index / 30, false).hop, 0, mode) end
		end
	end)

	case("A3: Alert shows the mark and a bright pulse; only Alert shows the mark", function()
		local low, high = math.huge, -math.huge
		for index = 0, 120 do
			local p = Look.pose("Alert", false, index / 60, false)
			equal(p.mark, true)
			low, high = math.min(low, p.glow), math.max(high, p.glow)
		end
		assert(low > K.GLOW, "brighter than calm at its dimmest: " .. low)
		assert(high - low > 0.2, "it pulses")
		for _, mode in ipairs({ "Idle", "Wander", "Curious", "Flee", "Hide", "Reserved", "Captured" }) do
			equal(Look.pose(mode, false, 0.3, false).mark, false, mode)
		end
	end)

	case("A3: hiding dims the glow; a peek is a little brighter but still dim", function()
		local hidden = Look.pose("Hide", false, 1, false)
		local peeking = Look.pose("Hide", true, 1, false)
		equal(hidden.dim, true); equal(peeking.dim, true)
		assert(hidden.glow < K.GLOW * 0.5, "dim: " .. hidden.glow)
		assert(peeking.glow > hidden.glow and peeking.glow < K.GLOW, "a peek: " .. peeking.glow)
		equal(Look.pose("Idle", false, 1, false).glow, K.GLOW)
		equal(Look.pose("Idle", false, 1, false).dim, false)
	end)

	case("A3: reduced effects keep every cue but stop the motion and the pulse", function()
		for index = 0, 60 do
			local curious = Look.pose("Curious", false, index / 30, true)
			equal(curious.hop, 0); equal(curious.ear, 0)
			local alert = Look.pose("Alert", false, index / 30, true)
			equal(alert.mark, true); equal(alert.glow, K.ALERT_GLOW)
		end
		equal(Look.pose("Hide", false, 0, true).dim, true)
	end)

	case("A3: unknown modes and junk times read as calm", function()
		for _, mode in ipairs({ nil, "Spooked", 5 }) do
			local p = Look.pose(mode, false, 1, false)
			equal(p.hop, 0); equal(p.mark, false); equal(p.glow, K.GLOW); equal(p.dim, false)
		end
		for _, t in ipairs({ NAN, INF, "1" }) do
			local p = Look.pose("Curious", false, t, false)
			equal(p.hop, 0); equal(p.ear, 0)
		end
	end)

	case("the module reads no service, clock or interface", function()
		assert(type(source) == "string" and #source > 300, "source missing")
		for _, banned in ipairs({ "GetService", "os.clock", "os.time", "tick%(", "Instance", "workspace", "game%.", "require" }) do
			assert(not source:find(banned), "source uses " .. banned)
		end
	end)

	return result
end

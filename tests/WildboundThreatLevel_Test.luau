-- Invoke with require(freshTestClone)(require(freshThreatLevelClone)).
-- Delivery D8: the per-player threat bucket (Safe, Distant, Near, Chase) the server publishes and the client plays
-- audio from. Pure: the guardian's mode and distance in, a level out, with held falls so the music never flickers.
return function(Threat)
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
	local function input(mode, distance, overrides)
		local value = { mode = mode, distance = distance, targetIsMe = false, hidden = false, safe = false, alive = true }
		for key, item in pairs(overrides or {}) do value[key] = item end
		return value
	end
	local raw = Threat.raw

	case("D8: each level from mode and distance", function()
		equal(raw(input("Patrol", 130)), "Safe")
		equal(raw(input("Patrol", 120)), "Distant")
		equal(raw(input("Patrol", 56)), "Distant")
		equal(raw(input("Patrol", 55)), "Near")
		for _, mode in ipairs({ "Suspicious", "Investigate", "Search" }) do
			equal(raw(input(mode, 80)), "Near", mode .. " at 80")
			equal(raw(input(mode, 81)), "Distant", mode .. " at 81")
		end
		equal(raw(input("Retreat", 56)), "Safe", "retreating and past 55")
		equal(raw(input("Retreat", 40)), "Near", "retreating but close")
		for _, mode in ipairs({ "Alert", "Hunt", "Telegraph" }) do
			equal(raw(input(mode, 300, { targetIsMe = true })), "Chase", mode .. " on me")
		end
		equal(#Threat.LEVELS, 4)
		equal(Threat.rank("Chase") > Threat.rank("Near") and Threat.rank("Near") > Threat.rank("Distant")
			and Threat.rank("Distant") > Threat.rank("Safe"), true, "ordering")
	end)

	case("D8: safe zone forces Safe", function()
		equal(raw(input("Hunt", 5, { targetIsMe = true, safe = true })), "Safe")
		local state = Threat.new()
		Threat.update(state, input("Hunt", 5, { targetIsMe = true }), 0)
		equal(state.level, "Chase")
		equal(Threat.update(state, input("Hunt", 5, { targetIsMe = true, safe = true }), 0.2), "Safe", "no hold into camp")
	end)

	case("D8: hidden demotes Chase to Near", function()
		equal(raw(input("Hunt", 30, { targetIsMe = true, hidden = true })), "Near")
		equal(raw(input("Patrol", 30, { hidden = true })), "Near", "hiding never lowers a plain Near")
	end)

	case("D8: rises are immediate, falls are held 3, 3 and 5 s", function()
		local state = Threat.new()
		equal(state.level, "Safe")
		equal(Threat.update(state, input("Patrol", 100), 0), "Distant", "rise to Distant")
		equal(Threat.update(state, input("Hunt", 100, { targetIsMe = true }), 1), "Chase", "rise to Chase at once")
		local far = input("Patrol", 500)
		equal(Threat.update(state, far, 2), "Chase", "held")
		equal(Threat.update(state, far, 4.9), "Chase", "still held before 3 s")
		equal(Threat.update(state, far, 5), "Near", "Chase -> Near after 3 s")
		equal(Threat.update(state, far, 7.9), "Near")
		equal(Threat.update(state, far, 8), "Distant", "Near -> Distant after 3 s")
		equal(Threat.update(state, far, 12.9), "Distant")
		equal(Threat.update(state, far, 13), "Safe", "Distant -> Safe after 5 s")
		-- A fall that bounces back up restarts the hold.
		Threat.update(state, input("Patrol", 50), 20)
		Threat.update(state, input("Patrol", 100), 21)
		Threat.update(state, input("Patrol", 50), 22)
		equal(Threat.update(state, input("Patrol", 100), 24), "Near", "the hold restarts at 24 s, not 21")
		equal(Threat.update(state, input("Patrol", 100), 26.9), "Near")
		equal(Threat.update(state, input("Patrol", 100), 27), "Distant")
	end)

	case("D8: another player's hunt is Distant", function()
		for _, mode in ipairs({ "Alert", "Hunt", "Telegraph" }) do
			equal(raw(input(mode, 400)), "Distant", mode .. " far away")
			equal(raw(input(mode, 40)), "Near", mode .. " close by")
		end
	end)

	case("D8: bad input is Safe", function()
		equal(raw(nil), "Safe")
		equal(raw({}), "Safe")
		for _, bad in ipairs({ 0 / 0, math.huge, -1, "20" }) do
			equal(raw(input("Patrol", bad)), "Safe", tostring(bad))
		end
		equal(raw(input("Patrol", 10, { alive = false })), "Safe", "dead")
		equal(raw(input("Hunt", 10, { targetIsMe = true, alive = false })), "Safe", "dead while hunted")
		local state = Threat.new()
		equal(Threat.update(state, input("Patrol", 10), 0 / 0), "Safe", "a bad clock changes nothing")
		equal(Threat.update(nil, input("Patrol", 10), 0), "Safe")
		equal(Threat.rank("Panic"), 0)
	end)

	return result
end

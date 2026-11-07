-- Invoke with require(freshTestClone)(require(freshBrainClone), require(freshRulesClone), freshBrainClone.Source).
-- Delivery C1: La Silueta's non-combat brain (suspicion, investigating noises, searching the last known position,
-- returning) and its day and night profiles. Pure: positions are numbers, the clock is injected.
return function(Brain, Rules, source)
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
	local function near(actual, expected, tolerance, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-6),
			(label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local clamp = Rules.clampTerritory
	local PHASES = { "Day", "Dusk", "Night", "Dawn" }
	local function fresh(mode, now)
		local state = Brain.new(now or 0)
		if mode then Brain.set(state, mode, now or 0) end
		return state
	end
	local function distance(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end

	case("every phase has a profile, and Day is calmer than Night", function()
		for _, phase in ipairs(PHASES) do
			local profile = Brain.profile(phase)
			assert(type(profile) == "table", phase)
			for _, key in ipairs({ "patrol", "investigate", "hunt", "search", "retreat", "hearing", "searchSeconds",
				"chaseSeconds", "alertSeconds", "detection" }) do
				assert(type(profile[key]) == "number" and profile[key] > 0, phase .. "." .. key)
			end
		end
		local day, night = Brain.profile("Day"), Brain.profile("Night")
		assert(day.hunt < night.hunt, "hunts faster at night")
		assert(day.hearing < night.hearing, "hears farther at night")
		assert(day.searchSeconds < night.searchSeconds, "searches longer at night")
		assert(day.chaseSeconds < night.chaseSeconds, "chases longer at night")
		assert(day.alertSeconds > night.alertSeconds, "reacts faster at night")
		assert(day.detection < night.detection, "sees farther at night")
		equal(Brain.profile("Nonsense").hunt, day.hunt, "an unknown phase reads as Day")
	end)

	case("chases stay escapable: every hunt speed is below a carrying player's 14 and above patrol", function()
		for _, phase in ipairs(PHASES) do
			local profile = Brain.profile(phase)
			assert(profile.hunt < 14, phase .. " hunt " .. profile.hunt)
			assert(profile.hunt < 11, phase .. " stays below the slowest loaded walk, 11: " .. profile.hunt)
			assert(profile.hunt > profile.patrol and profile.investigate > profile.patrol, phase)
			assert(profile.alertSeconds >= 0.6, phase .. " leaves time to react")
			assert(profile.detection <= Rules.CHASE_RANGE, phase .. " detects inside the chase range")
		end
	end)

	case("speed by mode: standing modes are 0, moving modes follow the phase", function()
		for _, phase in ipairs(PHASES) do
			local profile = Brain.profile(phase)
			equal(Brain.speed("Suspicious", phase), 0); equal(Brain.speed("Alert", phase), 0)
			equal(Brain.speed("Telegraph", phase), 0)
			equal(Brain.speed("Patrol", phase), profile.patrol); equal(Brain.speed("Hunt", phase), profile.hunt)
			equal(Brain.speed("Investigate", phase), profile.investigate); equal(Brain.speed("Search", phase), profile.search)
			equal(Brain.speed("Retreat", phase), profile.retreat)
		end
		equal(Brain.speed("Dance", "Day"), 0)
	end)

	case("noise radius grows with the capture step, the slot tier and the night", function()
		assert(Brain.noiseRadius("seal", "Fog", "Day") > Brain.noiseRadius("ring", "Fog", "Day"), "seal is louder")
		assert(Brain.noiseRadius("ring", "Territory", "Day") > Brain.noiseRadius("ring", "Fog", "Day"), "territory louder")
		assert(Brain.noiseRadius("ring", "Fog", "Day") > Brain.noiseRadius("ring", "Safe", "Day"), "safe quieter")
		assert(Brain.noiseRadius("seal", "Fog", "Night") > Brain.noiseRadius("seal", "Fog", "Day"), "night carries")
		near(Brain.noiseRadius("ring", "Fog", "Day"), Brain.NOISE.ring * Brain.TIER_NOISE.Fog * Brain.profile("Day").hearing)
		equal(Brain.noiseRadius("shout", "Fog", "Day"), 0, "unknown kinds are silent")
		equal(Brain.noiseRadius("ring", "Moon", "Day"), Brain.noiseRadius("ring", "Fog", "Day"), "unknown tier reads as Fog")
		equal(Brain.noiseRadius(nil, nil, nil), 0)
	end)

	case("a noise beyond its radius is not heard", function()
		local state = fresh("Patrol")
		local radius = Brain.noiseRadius("ring", "Fog", "Day")
		local heard = Brain.hear(state, { kind = "ring", tier = "Fog", x = radius + 1, z = -85 }, 0, -85, 1, "Day", clamp)
		equal(heard, false); equal(state.mode, "Patrol")
	end)

	case("a faint noise makes it suspicious: it stops, faces the sound, then investigates", function()
		local state = fresh("Patrol")
		local radius = Brain.noiseRadius("ring", "Fog", "Day")
		local x = 0 + radius * 0.8
		local heard, strength = Brain.hear(state, { kind = "ring", tier = "Fog", x = x, z = -85 }, 0, -85, 10, "Day", clamp)
		equal(heard, true); near(strength, 0.2, 1e-6); equal(state.mode, "Suspicious")
		local out = Brain.step(state, 10 + Brain.CONSTANTS.SUSPICIOUS_SECONDS - 0.01, 0, -85, "Day", clamp)
		equal(out.mode, "Suspicious"); equal(out.speed, 0); equal(out.destination, nil)
		near(out.face.x, x); near(out.face.z, -85)
		out = Brain.step(state, 10 + Brain.CONSTANTS.SUSPICIOUS_SECONDS, 0, -85, "Day", clamp)
		equal(out.mode, "Investigate"); near(out.destination.x, x); equal(out.speed, Brain.profile("Day").investigate)
	end)

	case("a loud noise sends it straight to investigate", function()
		local state = fresh("Patrol")
		local heard, strength = Brain.hear(state, { kind = "seal", tier = "Territory", x = 5, z = -85 }, 0, -85, 3, "Night", clamp)
		equal(heard, true); assert(strength >= Brain.CONSTANTS.LOUD, "strength " .. tostring(strength))
		equal(state.mode, "Investigate")
	end)

	case("while fighting it ignores noises", function()
		for _, mode in ipairs({ "Alert", "Hunt", "Telegraph" }) do
			local state = fresh(mode)
			equal(Brain.hear(state, { kind = "seal", tier = "Territory", x = 1, z = -85 }, 0, -85, 1, "Night", clamp), false, mode)
			equal(state.mode, mode)
		end
	end)

	case("it hears while returning, searching or investigating, and a new noise retargets", function()
		local state = fresh("Retreat")
		equal(Brain.hear(state, { kind = "seal", tier = "Fog", x = 4, z = -85 }, 0, -85, 1, "Day", clamp), true)
		equal(state.mode, "Investigate")
		Brain.lostSight(state, 10, -90, 2, "Day", clamp)
		equal(state.mode, "Search")
		local radius = Brain.noiseRadius("ring", "Fog", "Day")
		-- Even a faint noise during a search goes straight to investigating it: it is already alert.
		equal(Brain.hear(state, { kind = "ring", tier = "Fog", x = 10 + radius * 0.9, z = -90 }, 10, -90, 3, "Day", clamp), true)
		equal(state.mode, "Investigate"); near(state.point.x, 10 + radius * 0.9)
	end)

	case("investigating ends in a search on arrival, and the search ends in a return", function()
		local state = fresh("Patrol")
		Brain.hear(state, { kind = "seal", tier = "Fog", x = 20, z = -85 }, 10, -85, 0, "Day", clamp)
		local out = Brain.step(state, 1, 10, -85, "Day", clamp)
		equal(out.mode, "Investigate")
		out = Brain.step(state, 2, 20 - Brain.CONSTANTS.ARRIVE_RADIUS + 0.1, -85, "Day", clamp)
		equal(out.mode, "Search"); equal(out.speed, Brain.profile("Day").search)
		local seen = 0
		local now, x, z = 2, out.destination.x, out.destination.z
		for _ = 1, 8 do
			assert(distance(out.destination.x, out.destination.z, 20, -85) <= Brain.CONSTANTS.SEARCH_RADIUS + 1e-6,
				"looks around the noise")
			now += 0.5
			out = Brain.step(state, now, out.destination.x, out.destination.z, "Day", clamp)
			if out.destination and (out.destination.x ~= x or out.destination.z ~= z) then seen += 1 end
			if out.destination then x, z = out.destination.x, out.destination.z end
		end
		assert(seen >= 3, "visits several look-around points, saw " .. seen)
		out = Brain.step(state, 2 + Brain.profile("Day").searchSeconds, 20, -85, "Day", clamp)
		equal(out.mode, "Retreat")
	end)

	case("an unreachable noise is given up after the investigate limit", function()
		local state = fresh("Patrol")
		Brain.hear(state, { kind = "seal", tier = "Fog", x = 20, z = -85 }, 10, -85, 0, "Day", clamp)
		local out = Brain.step(state, Brain.CONSTANTS.INVESTIGATE_MAX_SECONDS - 0.01, 0, -85, "Day", clamp)
		equal(out.mode, "Investigate")
		out = Brain.step(state, Brain.CONSTANTS.INVESTIGATE_MAX_SECONDS, 0, -85, "Day", clamp)
		equal(out.mode, "Search")
	end)

	case("losing sight searches the last known position, longer at night", function()
		local day, night = fresh("Hunt"), fresh("Hunt")
		Brain.lostSight(day, 30, -60, 5, "Day", clamp)
		Brain.lostSight(night, 30, -60, 5, "Night", clamp)
		equal(day.mode, "Search"); near(day.point.x, 30); near(day.point.z, -60)
		local out = Brain.step(day, 5.2, 0, -85, "Day", clamp)
		near(out.destination.x, 30); near(out.destination.z, -60, 1e-6, "goes to the last known spot first")
		equal(Brain.step(day, 5 + Brain.profile("Day").searchSeconds, 30, -60, "Day", clamp).mode, "Retreat")
		equal(Brain.step(night, 5 + Brain.profile("Day").searchSeconds, 30, -60, "Night", clamp).mode, "Search")
	end)

	case("never into camp: a noise or a last known spot in camp is pulled back into territory", function()
		local state = fresh("Patrol")
		-- A capture just outside the fog on the camp side, heard from the corner of the fog.
		equal(Brain.hear(state, { kind = "seal", tier = "Safe", x = -60, z = 50 }, -40, 30, 0, "Night", clamp), true)
		local fog, safe = Rules.zone(state.point.x, state.point.z)
		equal(fog, true, "inside the fog"); equal(safe, false, "not in a safe zone")
		assert(Rules.distance(state.point.x, state.point.z, Rules.HOME_X, Rules.HOME_Z) <= Rules.HOME_LEASH + 1e-6, "on the leash")
		Brain.lostSight(state, -140, 140, 1, "Night", clamp)
		fog, safe = Rules.zone(state.point.x, state.point.z)
		equal(safe, false)
		for now = 1.2, 12, 0.4 do
			local out = Brain.step(state, now, state.point.x, state.point.z, "Night", clamp)
			if out.destination then
				local _, inSafe = Rules.zone(out.destination.x, out.destination.z)
				equal(inSafe, false, "search point " .. now)
				assert(Rules.distance(out.destination.x, out.destination.z, Rules.HOME_X, Rules.HOME_Z) <= Rules.HOME_LEASH + 1e-6)
			end
		end
	end)

	case("detection: on its rounds and while searching, never while it recovers", function()
		for _, mode in ipairs({ "Patrol", "Suspicious", "Investigate", "Search" }) do
			equal(Brain.canDetect(fresh(mode), 5, 10), true, mode)
		end
		equal(Brain.canDetect(fresh("Retreat"), 5, 10), false, "recovering")
		equal(Brain.canDetect(fresh("Retreat"), 10, 10), true, "recovered")
		for _, mode in ipairs({ "Alert", "Hunt", "Telegraph" }) do equal(Brain.canDetect(fresh(mode), 50, 0), false, mode) end
	end)

	case("engaging winds up for the phase's alert time, shorter when it spots its quarry again", function()
		local state = fresh("Patrol")
		near(Brain.engage(state, 0, "Day"), Brain.profile("Day").alertSeconds)
		equal(state.mode, "Alert")
		local searching = fresh("Hunt")
		Brain.lostSight(searching, 1, -80, 0, "Day", clamp)
		local again = Brain.engage(searching, 1, "Day")
		near(again, Brain.CONSTANTS.REACQUIRE_ALERT_SECONDS)
		assert(again < Brain.profile("Day").alertSeconds and again >= 0.6)
	end)

	case("a chase gives up after the phase's limit", function()
		equal(Brain.chaseExpired(0, Brain.profile("Day").chaseSeconds - 0.01, "Day"), false)
		equal(Brain.chaseExpired(0, Brain.profile("Day").chaseSeconds, "Day"), true)
		equal(Brain.chaseExpired(0, Brain.profile("Day").chaseSeconds, "Night"), false)
	end)

	case("bad numbers change nothing", function()
		local state = fresh("Patrol")
		equal(Brain.hear(state, { kind = "seal", tier = "Fog", x = 0 / 0, z = 1 }, 0, -85, 1, "Day", clamp), false)
		equal(Brain.hear(state, nil, 0, -85, 1, "Day", clamp), false)
		equal(Brain.hear(state, { kind = "seal", tier = "Fog", x = 1, z = -85 }, math.huge, -85, 1, "Day", clamp), false)
		equal(state.mode, "Patrol")
		local out = Brain.step(state, 0 / 0, 0, -85, "Day", clamp)
		equal(out.mode, "Patrol")
	end)

	case("same inputs, same decisions", function()
		local function run()
			local state = fresh("Patrol")
			Brain.hear(state, { kind = "ring", tier = "Fog", x = 12, z = -80 }, 0, -85, 0, "Dusk", clamp)
			local trace = {}
			for now = 0, 20, 0.2 do
				local out = Brain.step(state, now, 6, -82, "Dusk", clamp)
				table.insert(trace, out.mode .. (out.destination and ("%.3f,%.3f"):format(out.destination.x, out.destination.z) or ""))
			end
			return table.concat(trace, "|")
		end
		equal(run(), run())
	end)

	case("purity: no services, no clock, no randomness, no require", function()
		assert(type(source) == "string" and #source > 0, "source given")
		for _, banned in ipairs({ "game:", "workspace", "require(", "task.", "os.clock", "os.time", "tick(", "Random", "math.random" }) do
			assert(not source:find(banned, 1, true), "contains " .. banned)
		end
	end)

	-- Delivery D5: sprinting and hiding make noise on the same hearing scale as a capture.
	case("D5: sprint noise radius is 16 x tier x hearing", function()
		equal(Brain.NOISE.sprint, 16)
		near(Brain.noiseRadius("sprint", "Territory", "Night"), 16 * 1.4 * 1.3, 1e-6, "night in the territory")
		near(Brain.noiseRadius("sprint", "Fog", "Day"), 16 * 1.0 * Brain.profile("Day").hearing, 1e-6, "day in the fog")
	end)

	case("D5: rustle radius", function()
		equal(Brain.NOISE.rustle, 10)
		near(Brain.noiseRadius("rustle", "Territory", "Night"), 10 * 1.4 * 1.3, 1e-6)
		assert(Brain.noiseRadius("rustle", "Fog", "Day") < Brain.noiseRadius("sprint", "Fog", "Day"), "rustle is quieter")
	end)

	case("D5: sprint under strength 0.5 is Suspicious", function()
		local radius = Brain.noiseRadius("sprint", "Fog", "Day")
		local state = fresh(nil, 0)
		local heard, strength = Brain.hear(state, { kind = "sprint", tier = "Fog", x = radius * 0.6, z = 0 }, 0, 0, 1, "Day", clamp)
		assert(heard and strength < 0.5, "a faint sprint is heard")
		equal(state.mode, "Suspicious")
		local loud = fresh(nil, 0)
		Brain.hear(loud, { kind = "sprint", tier = "Fog", x = radius * 0.2, z = 0 }, 0, 0, 1, "Day", clamp)
		equal(loud.mode, "Investigate")
	end)

	return result
end

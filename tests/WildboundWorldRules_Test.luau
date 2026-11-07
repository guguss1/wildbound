-- Contract cases only: execution is deferred until authorized Studio testing resumes.
-- Invoke this function with a freshly cloned WildboundWorldRules ModuleScript result.
return function(Rules)
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
	local function context(overrides)
		local value = { alive = true, eligible = true, distance = 20, visible = true, facing = true }
		for key, item in pairs(overrides or {}) do value[key] = item end
		return value
	end

	case("phase boundaries use the single 720 second cycle (M5.7, D5)", function()
		for _, sample in ipairs({ { 0, "Day" }, { 359.99, "Day" }, { 360, "Dusk" }, { 431.99, "Dusk" },
			{ 432, "Night" }, { 647.99, "Night" }, { 648, "Dawn" }, { 719.99, "Dawn" }, { 720, "Day" } }) do
			equal(Rules.cycle(sample[1]).phase, sample[2])
		end
		equal(Rules.CYCLE_SECONDS, 720)
	end)
	case("phase duration and progression remain exact", function()
		equal(Rules.cycle(0).remaining, 360)
		equal(Rules.cycle(360).remaining, 72)
		equal(Rules.cycle(432).remaining, 216)
		equal(Rules.cycle(648).remaining, 72)
		equal(Rules.cycle(540).progress, 0.5)
		equal(Rules.cycle(730).elapsed, 10)
	end)
	case("invalid elapsed time normalizes without NaN propagation", function()
		for _, value in ipairs({ -1, math.huge, -math.huge, 0 / 0, "720" }) do
			equal(Rules.cycle(value).phase, "Day")
			equal(Rules.cycle(value).elapsed, 0)
		end
		equal(Rules.cycle(nil).elapsed, 0)
	end)
	case("clock starts and phase joins are continuous", function()
		equal(Rules.cycle(0).clockTime, 6)
		equal(Rules.cycle(360).clockTime, 18)
		equal(Rules.cycle(432).clockTime, 20)
		equal(Rules.cycle(648).clockTime, 5)
		for time = 0, 1440, 1 do
			local clock = Rules.cycle(time).clockTime
			assert(clock >= 0 and clock < 24)
		end
	end)
	case("the start offset is drawn over non-Night time only, so the first phase is never Night", function()
		for index = 0, 9999 do
			local offset = Rules.startOffset(index / 10000)
			assert(offset >= 0 and offset < Rules.CYCLE_SECONDS, "offset in the cycle: " .. tostring(offset))
			assert(Rules.cycle(offset).phase ~= "Night", "Night start at roll " .. index / 10000)
		end
		equal(Rules.startOffset(0), 0)
		equal(Rules.cycle(Rules.startOffset(0.999999)).phase, "Dawn")
		equal(Rules.startOffset(432 / 504), 648, "the join between Dusk and Dawn skips the whole Night")
		equal(Rules.startOffset(0.5), 252)
	end)
	case("the start offset is uniform over non-Night time and rejects bad rolls", function()
		local day, steps = 0, 5040
		for index = 0, steps - 1 do
			if Rules.cycle(Rules.startOffset(index / steps)).phase == "Day" then day += 1 end
		end
		equal(day, 3600, "Day is 360 of the 504 non-Night seconds")
		for _, bad in ipairs({ -1, 0 / 0, math.huge, -math.huge, "0.5", 1, 2 }) do
			local offset = Rules.startOffset(bad)
			assert(offset >= 0 and offset < Rules.CYCLE_SECONDS and Rules.cycle(offset).phase ~= "Night", tostring(bad))
		end
		equal(Rules.startOffset(nil), 0)
	end)
	case("the wait to the first Night matches the economy document", function()
		local waits = {}
		for index = 0, 9999 do
			local offset = Rules.startOffset(index / 10000)
			table.insert(waits, (432 - offset) % Rules.CYCLE_SECONDS)
		end
		table.sort(waits)
		assert(math.abs(waits[5000] - 253) <= 3, "median " .. waits[5000])
		assert(math.abs(waits[9000] - 453) <= 3, "90th percentile " .. waits[9000])
		assert(waits[10000] <= 504 and waits[10000] > 503, "maximum " .. waits[10000])
	end)
	case("camp and shelter safe regions do not overlap fog", function()
		local fog, safe = Rules.zone(-140, 140)
		equal(fog, false); equal(safe, true)
		fog, safe = Rules.zone(105, 125)
		equal(fog, false); equal(safe, true)
		equal(select(2, Rules.zone(-105, 140)), true)
		equal(select(2, Rules.zone(-104.99, 140)), false)
		equal(select(2, Rules.zone(127, 125)), true)
		equal(select(2, Rules.zone(127.01, 125)), false)
	end)
	case("fog rectangle boundaries are inclusive and reject invalid coordinates", function()
		equal(Rules.zone(-45, -165), true)
		equal(Rules.zone(165, 35), true)
		equal(Rules.zone(-45.01, -85), false)
		equal(Rules.zone(166, 0), false)
		equal(Rules.zone(0, 36), false)
		equal(Rules.zone(0 / 0, 0), false)
		equal(Rules.zone(nil, 0), false)
	end)
	case("territory requires fog and a bounded home leash", function()
		equal(Rules.inTerritory(0, -85), true)
		equal(Rules.inTerritory(80, -85), true)
		equal(Rules.inTerritory(80.01, -85), false)
		equal(Rules.inTerritory(-46, -85), false)
		equal(Rules.inTerritory(-140, 140), false)
	end)
	case("clamp cannot steer outside fog and home leash", function()
		for _, sample in ipairs({ { 1000, 1000 }, { -1000, -1000 }, { 0, -85 }, { 70, -140 } }) do
			local x, z = Rules.clampTerritory(sample[1], sample[2])
			assert(Rules.distance(x, z, 0, -85) <= Rules.HOME_LEASH + 0.00001)
			equal(Rules.zone(x, z), true)
		end
		local x, z = Rules.clampTerritory(0 / 0, math.huge)
		equal(x, 0); equal(z, -85)
	end)
	case("night boosts only fog and remains slower than standard player walking", function()
		local day = Rules.guardianParameters("Day", true)
		local night = Rules.guardianParameters("Night", true)
		local outside = Rules.guardianParameters("Night", false)
		equal(day.speed, 6); equal(night.speed, 8); equal(outside.speed, 6)
		equal(day.detectionRange, 28); equal(night.detectionRange, 38)
		assert(day.speed < 16 and night.speed < 16)
	end)
	case("creature profile resolves Silueta phase and explicit fog scope", function()
		for _, sample in ipairs({ { "Day", true, 6, 28 }, { "Dusk", true, 6, 28 },
			{ "Night", true, 8, 38 }, { "Night", false, 6, 28 },
			{ "Dawn", true, 6, 28 }, { "Unknown", true, 6, 28 }, { "Night", "true", 6, 28 } }) do
			local profile = Rules.resolveCreatureProfile("Silueta", sample[1], sample[2])
			equal(profile.name, "Silueta"); equal(profile.specialBehaviorId, "Silueta")
			equal(profile.speed, sample[3]); equal(profile.detectionRange, sample[4])
			equal(profile.visualScale, 1.30)
		end
	end)
	case("unknown creature profiles fail closed", function()
		equal(Rules.resolveCreatureProfile("Unknown", "Night", true), nil)
		equal(Rules.resolveCreatureProfile(nil, "Night", true), nil)
		equal(Rules.resolveCreatureProfile({}, "Night", true), nil)
	end)
	case("resolved profiles are detached across calls and phase variants", function()
		local first = Rules.resolveCreatureProfile("Silueta", "Night", true)
		first.name = "Changed"; first.specialBehaviorId = "Changed"
		first.speed = 999; first.detectionRange = 999; first.visualScale = 999
		local second = Rules.resolveCreatureProfile("Silueta", "Night", true)
		local base = Rules.resolveCreatureProfile("Silueta", "Day", true)
		equal(second.name, "Silueta"); equal(second.specialBehaviorId, "Silueta")
		equal(second.speed, 8); equal(second.detectionRange, 38); equal(second.visualScale, 1.30)
		equal(base.speed, 6); equal(base.detectionRange, 28); equal(base.visualScale, 1.30)
	end)
	case("guardian compatibility agrees with creature resolver", function()
		for _, sample in ipairs({ { "Day", true }, { "Night", true }, { "Night", false } }) do
			local legacy = Rules.guardianParameters(sample[1], sample[2])
			local profile = Rules.resolveCreatureProfile("Silueta", sample[1], sample[2])
			equal(legacy.speed, profile.speed); equal(legacy.detectionRange, profile.detectionRange)
		end
	end)
	case("target acquisition rejects safe dead remote and out of territory players", function()
		equal(Rules.validTarget(true, 10, -85, 0, -85, 28), true)
		equal(Rules.validTarget(false, 10, -85, 0, -85, 28), false)
		equal(Rules.validTarget(true, 29, -85, 0, -85, 28), false)
		equal(Rules.validTarget(true, -140, 140, -140, 140, 65), false)
		equal(Rules.validTarget(true, 90, -85, 70, -85, 65), false)
		equal(Rules.validTarget(true, 0 / 0, -85, 0, -85, 28), false)
	end)
	case("free flashlight reveals without any pet", function()
		local cooldowns = {}
		local ok, reason, hit = Rules.tryAbility(cooldowns, "Flashlight", 100, context({ eligible = false }))
		equal(ok, true); equal(reason, "Revealed"); equal(hit, true)
		equal(cooldowns.Flashlight, 112)
	end)
	case("pulse requires verified equipped registered pet", function()
		local cooldowns = {}
		local ok, reason = Rules.tryAbility(cooldowns, "LumipolPulse", 100, context({ eligible = false }))
		equal(ok, false); equal(reason, "NotEquipped"); equal(cooldowns.LumipolPulse, nil)
		equal(Rules.tryAbility(cooldowns, "LumipolPulse", 100, context({ eligible = "true" })), false)
		local accepted, _, hit = Rules.tryAbility(cooldowns, "LumipolPulse", 100, context({ facing = false }))
		equal(accepted, true); equal(hit, true); equal(cooldowns.LumipolPulse, 130)
	end)
	case("reveal range is finite and capped at 55 studs", function()
		for _, sample in ipairs({ { 55, true }, { 55.01, false }, { -1, false }, { math.huge, false }, { 0 / 0, false } }) do
			local ok, _, hit = Rules.tryAbility({}, "Flashlight", 100, context({ distance = sample[1] }))
			equal(ok, true); equal(hit, sample[2])
		end
	end)
	case("flashlight facing and both abilities LOS are required for reveal", function()
		local _, _, hit = Rules.tryAbility({}, "Flashlight", 100, context({ facing = false }))
		equal(hit, false)
		for _, action in ipairs({ "Flashlight", "LumipolPulse" }) do
			local _, _, visibleHit = Rules.tryAbility({}, action, 100, context({ visible = false }))
			equal(visibleHit, false)
		end
	end)
	case("miss consumes cooldown but invalid context never does", function()
		local cooldowns = {}
		local ok, reason = Rules.tryAbility(cooldowns, "Flashlight", 100, context({ distance = 100 }))
		equal(ok, true); equal(reason, "Miss"); equal(cooldowns.Flashlight, 112)
		local dead = {}
		equal(Rules.tryAbility(dead, "Flashlight", 100, context({ alive = false })), false)
		equal(dead.Flashlight, nil)
		equal(Rules.tryAbility(dead, "Flashlight", 0 / 0, context()), false)
		equal(Rules.tryAbility(dead, "Other", 100, context()), false)
		equal(dead.Other, nil)
	end)
	case("cooldown is atomic and allows the exact deadline", function()
		local cooldowns = {}
		equal(Rules.tryAbility(cooldowns, "Flashlight", 100, context()), true)
		local ok, reason = Rules.tryAbility(cooldowns, "Flashlight", 100, context())
		equal(ok, false); equal(reason, "Cooldown"); equal(cooldowns.Flashlight, 112)
		equal(Rules.tryAbility(cooldowns, "Flashlight", 111.99, context()), false)
		equal(Rules.tryAbility(cooldowns, "Flashlight", 112, context()), true)
	end)
	case("players and abilities do not share a cooldown", function()
		local alice, bob = {}, {}
		equal(Rules.tryAbility(alice, "Flashlight", 100, context()), true)
		equal(Rules.tryAbility(alice, "LumipolPulse", 100, context()), true)
		equal(Rules.tryAbility(bob, "Flashlight", 100, context()), true)
		equal(alice.LumipolPulse, 130); equal(bob.LumipolPulse, nil)
	end)
	case("strike waits for telegraph and cooldown", function()
		assert(Rules.TELEGRAPH_SECONDS >= 1.2)
		equal(Rules.canStrike(11, 11.4, 0, 4, true, false, true), false)
		equal(Rules.canStrike(11.4, 11.4, 0, 4, true, false, true), true)
		equal(Rules.canStrike(11.4, 11.4, 10, 4, true, false, true), false)
	end)
	case("strike rejects escaped safe dead occluded and invalid targets", function()
		equal(Rules.canStrike(15, 14, 0, 7, true, false, true), true)
		equal(Rules.canStrike(15, 14, 0, 7.01, true, false, true), false)
		equal(Rules.canStrike(15, 14, 0, 4, true, true, true), false)
		equal(Rules.canStrike(15, 14, 0, 4, false, false, true), false)
		equal(Rules.canStrike(15, 14, 0, 4, true, false, false), false)
		equal(Rules.canStrike(15, 14, 0, 0 / 0, true, false, true), false)
		equal(Rules.canStrike(math.huge, 14, 0, 4, true, false, true), false)
	end)
	-- M2.2: the proximity cue never reads a guardian that is withdrawing, and the disc has a non-hue cue.
	case("threat is every engaged mode in fog but never Retreat", function()
		for _, mode in ipairs({ "Patrol", "Alert", "Hunt", "Telegraph" }) do
			equal(Rules.isThreat(mode, true, true, false, 30), true)
		end
		equal(Rules.isThreat("Retreat", true, true, false, 3), false)
	end)
	case("threat needs a live player in fog, outside shelter, within chase range", function()
		equal(Rules.isThreat("Hunt", false, true, false, 30), false)
		equal(Rules.isThreat("Hunt", true, false, false, 30), false)
		equal(Rules.isThreat("Hunt", true, true, true, 30), false)
		equal(Rules.isThreat("Hunt", true, true, false, Rules.CHASE_RANGE), true)
		equal(Rules.isThreat("Hunt", true, true, false, Rules.CHASE_RANGE + 0.01), false)
	end)
	case("threat fails closed on bad input", function()
		for _, distance in ipairs({ 0 / 0, math.huge, -1, "5" }) do
			equal(Rules.isThreat("Hunt", true, true, false, distance), false)
		end
		for _, mode in ipairs({ 5, false }) do equal(Rules.isThreat(mode, true, true, false, 5), false) end
		equal(Rules.isThreat(nil, true, true, false, 5), false)
	end)
	case("the disc turns amber while someone is seen, and also grows and fills in", function()
		local idle, seen = Rules.groundCue(false), Rules.groundCue(true)
		assert(seen.r > 200 and seen.r > seen.g and seen.g > seen.b + 40, "seen must be amber")
		assert(idle.g > idle.r and idle.g > idle.b, "idle stays the calm sage")
		assert(seen.diameter > idle.diameter, "seen must be larger, so colour is not the only cue")
		assert(seen.transparency < idle.transparency, "seen must be more solid, so colour is not the only cue")
		for _, value in ipairs({ "yes", 1, {} }) do
			equal(Rules.groundCue(value).diameter, idle.diameter)
		end
		equal(Rules.groundCue(nil).diameter, idle.diameter)
	end)
	case("the disc table is fresh each call", function()
		local first = Rules.groundCue(true)
		first.r, first.diameter = 0, 0
		equal(Rules.groundCue(true).diameter > 0, true)
		equal(Rules.groundCue(true).r > 200, true)
	end)
	return result
end

-- Contract cases only: execution is deferred until authorized Studio testing resumes.
-- Invoke this function with a freshly cloned WildboundWorldRules ModuleScript result and, for the chase pass
-- no-strike cases, the island layout (require(freshIslandLayoutClone), ServerScriptService.WildboundIslandLayout).
return function(Rules, islandLayout)
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
	-- Nest Heist hub (HB-T6): the hub disc is a safe zone (no PvP, no beasts, no strikes, chases end), like the camp.
	-- Every consumer of Rules.zone covers it: the bat, the beast director, La Silueta's strikes and chases, the parents.
	case("HB-T6: the hub disc (Rules.HUB_X, HUB_Z, radius 90) is safe and never fog", function()
		equal(Rules.HUB_RADIUS, 90, "decision HB1")
		local fog, safe = Rules.zone(Rules.HUB_X, Rules.HUB_Z)
		equal(fog, false); equal(safe, true, "the campfire")
		for step = 0, 15 do
			local angle = step * math.pi / 8
			local x, z = Rules.HUB_X + math.cos(angle), Rules.HUB_Z + math.sin(angle)
			equal(select(2, Rules.zone(Rules.HUB_X + 89.99 * math.cos(angle), Rules.HUB_Z + 89.99 * math.sin(angle))), true,
				"on the edge at " .. step)
			equal(select(2, Rules.zone(Rules.HUB_X + 90.5 * math.cos(angle), Rules.HUB_Z + 90.5 * math.sin(angle))), false,
				"just outside at " .. step)
			equal(Rules.inTerritory(x, z), false, "never La Silueta's territory")
		end
	end)
	case("HB-T1: Rules.CAMP_X, CAMP_Z, CAMP_RADIUS repeat the zone's literal camp circle", function()
		equal(select(2, Rules.zone(Rules.CAMP_X, Rules.CAMP_Z)), true)
		equal(select(2, Rules.zone(Rules.CAMP_X + Rules.CAMP_RADIUS - 0.01, Rules.CAMP_Z)), true)
		equal(select(2, Rules.zone(Rules.CAMP_X + Rules.CAMP_RADIUS + 0.01, Rules.CAMP_Z)), false)
		equal(select(2, Rules.zone(Rules.CAMP_X, Rules.CAMP_Z - Rules.CAMP_RADIUS - 0.01)), false)
	end)
	case("HB-T6: every corner of every base pad of the hub plan is safe", function()
		-- assets/maps/hub-layout/hub-bases-v1.json: pads 26 x 22 centred at radius 68, bearings 22.5 + 45k, yaw 90 - bearing
		-- (each faces the lobby); local +X = (cos r, -sin r), local +Z = (sin r, cos r).
		for slot = 0, 7 do
			local bearing = math.rad(22.5 + 45 * slot)
			local yaw = math.rad((90 - math.deg(bearing)) % 360)
			local cx, cz = Rules.HUB_X + 68 * math.cos(bearing), Rules.HUB_Z + 68 * math.sin(bearing)
			for _, corner in ipairs({ { 13.6, 11.6 }, { -13.6, 11.6 }, { 13.6, -11.6 }, { -13.6, -11.6 } }) do
				local x = cx + corner[1] * math.cos(yaw) + corner[2] * math.sin(yaw)
				local z = cz - corner[1] * math.sin(yaw) + corner[2] * math.cos(yaw)
				equal(select(2, Rules.zone(x, z)), true, "base " .. (slot + 1) .. " corner")
			end
		end
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
			equal(profile.visualScale, 3.8) -- look pass: deliberately changed from 2.6
		end
	end)
	-- Dread pass (user: much taller, about three times the player): the SiluetaV3 art is 8.57 studs at scale 1
	-- (its WildboundExpectedHeightStuds), so 2.0 stands about 17 studs over a 5.3-stud avatar. Deliberately
	-- changed from 1.30 (11.1 studs).
	-- Deliberately changed again in the chase pass (CP-D4, user: "bigger"): 2.0 (17.1 studs) to 2.6, about 22.3
	-- studs, four avatars tall. Art only: the gameplay body, ATTACK_RANGE 7 and the pathing agent are unchanged, and
	-- the art's arms (half span about 9 studs at 2.6) reach past the 7-stud strike, so no hit lands from beyond what
	-- the player sees.
	-- Deliberately changed again in the look pass (user: "¿Qué pasó con que tenía que ser mucho más alto y
	-- tenebroso?"): 2.6 (22.3 studs) to 3.8, about 32.6 studs, six avatars tall, as tall as the dead trees and past
	-- the evergreens' lowest boughs. Still art only, and live-tunable (Silueta.VISUAL_SCALE, 2 to 4.5).
	case("Silueta stands about six times a player's height", function()
		local height = 8.571428571428571 * Rules.resolveCreatureProfile("Silueta", "Night", true).visualScale
		assert(height >= 30 and height <= 35, "Silueta height " .. height)
		assert(height / 5.3 >= 6, "at least six avatars tall")
	end)
	case("look pass: the art scale is tunable, resolved live and restored by a reset", function()
		equal(Rules.tunable().SILUETA_VISUAL_SCALE, 3.8)
		Rules.tune({ SILUETA_VISUAL_SCALE = 3 })
		equal(Rules.resolveCreatureProfile("Silueta", "Day", false).visualScale, 3)
		Rules.tune(nil)
		equal(Rules.resolveCreatureProfile("Silueta", "Day", false).visualScale, 3.8)
		local speed = Rules.resolveCreatureProfile("Silueta", "Night", true).speed
		Rules.tune({ SILUETA_VISUAL_SCALE = 4.5 })
		equal(Rules.resolveCreatureProfile("Silueta", "Night", true).speed, speed, "art only")
		equal(Rules.ATTACK_RANGE, 7, "the hit range never follows the art")
		Rules.tune(nil)
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
		equal(second.speed, 8); equal(second.detectionRange, 38); equal(second.visualScale, 3.8)
		equal(base.speed, 6); equal(base.detectionRange, 28); equal(base.visualScale, 3.8)
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
	-- Deliberately changed in the chase pass (CP-D1, user: "attacks faster"). It was "TELEGRAPH_SECONDS >= 1.2". The
	-- telegraph is 0.9 s (was 1.4), the repeat 2.5 s (was 4): never under the 0.35 s floor of a visible and audible
	-- tell, and longer than the 0.8 s warning lead the fair-strike gate needs.
	case("chase pass: a shorter telegraph above the tell floor, a quicker repeat", function()
		equal(Rules.TELEGRAPH_SECONDS, 0.9); equal(Rules.ATTACK_COOLDOWN, 2.5)
		assert(Rules.TELEGRAPH_SECONDS >= 0.35 + 0.5, "the floor plus a margin for the network")
		assert(Rules.ATTACK_COOLDOWN > Rules.TELEGRAPH_SECONDS, "no back-to-back telegraphs")
	end)
	case("strike waits for telegraph and cooldown", function()
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
	-- Chase pass (CP-D2, CP-D3): La Silueta gives up only far away, and its pursuit may leave the territory to the
	-- chase leash, but a strike still needs the target inside the territory (the default leash, 80), so no island 1
	-- to 3 floor, camp circle or the spawn pad can ever be struck from anywhere it can stand.
	case("chase pass: give-up distance 90 to 120 and a pursuit leash", function()
		equal(Rules.GIVE_UP_DISTANCE, 100); equal(Rules.CHASE_LEASH, 100)
		assert(Rules.GIVE_UP_DISTANCE >= 90 and Rules.GIVE_UP_DISTANCE <= 120)
		assert(Rules.GIVE_UP_DISTANCE > Rules.CHASE_RANGE, "it keeps a quarry well past the old 65")
		equal(Rules.HOME_LEASH, 80, "the territory itself is unchanged")
		equal(Rules.inTerritory(20, 5, Rules.CHASE_LEASH), true, "92 from home is inside the pursuit leash")
		equal(Rules.inTerritory(20, 5), false, "but outside the territory")
		equal(Rules.validTarget(true, 20, 5, 20, -5, 20, Rules.CHASE_LEASH), true, "chased beyond the territory")
		equal(Rules.validTarget(true, 20, 5, 20, -2, 7), false, "never a strike target there")
		local x, z = Rules.clampTerritory(0, 40, Rules.CHASE_LEASH)
		assert(math.abs(Rules.distance(x, z, Rules.HOME_X, Rules.HOME_Z) - Rules.CHASE_LEASH) < 1e-6, "clamped to the chase leash")
		x, z = Rules.clampTerritory(0, 40)
		assert(math.abs(Rules.distance(x, z, Rules.HOME_X, Rules.HOME_Z) - Rules.HOME_LEASH) < 1e-6, "default leash unchanged")
		local _, safe = Rules.zone(Rules.clampTerritory(-140, 140, Rules.CHASE_LEASH))
		equal(safe, false, "the pursuit leash never reaches camp")
	end)
	case("chase pass: no strike on island 1 to 3 floors, at camp or on the spawn pad", function()
		assert(type(islandLayout) == "table" and type(islandLayout.islands) == "table", "island layout passed")
		local floors = {}
		for _, island in ipairs(islandLayout.islands) do
			if island.id == "I1" or island.id == "I2" or island.id == "I3" then table.insert(floors, island) end
		end
		equal(#floors, 3)
		-- Spawn pad: the place's default SpawnLocation, 12 x 12 at the origin (half diagonal 8.49). Its north edge
		-- reached one stud into the territory before the chase pass (found by this case: 21 points).
		table.insert(floors, { id = "spawn", x = 0, z = 0, floorRadius = 8.49 })
		table.insert(floors, { id = "camp", x = -140, z = 140, floorRadius = 35 })
		table.insert(floors, { id = "shelter", x = 105, z = 125, floorRadius = 22 })
		local struck = 0
		for _, floor in ipairs(floors) do
			for ring = 0, 4 do
				local r = floor.floorRadius * ring / 4
				for step = 0, 23 do
					local angle = step * math.pi / 12
					local px, pz = floor.x + math.cos(angle) * r, floor.z + math.sin(angle) * r
					-- The guardian stands anywhere the pursuit leash allows, as close as it likes.
					local gx, gz = Rules.clampTerritory(px, pz, Rules.CHASE_LEASH)
					if Rules.validTarget(true, px, pz, gx, gz, Rules.ATTACK_RANGE) then struck += 1 end
				end
			end
		end
		equal(struck, 0, "strikeable floor points")
	end)
	case("memory fix: a quarry out of legal sight is kept for the memory; only gone, hid or far ends the chase", function()
		-- Found in Play (2026-11-09): a sprinter crossing the spawn pad, the fog edge or the pursuit leash ended the hunt at
		-- once (Search 0.1 s later) instead of after the night memory. Those places now only read as out of sight.
		assert(type(Rules.pursuit) == "function", "Rules.pursuit missing")
		local function obs(overrides)
			local value = { alive = true, hidden = false, visible = true, distance = 24 }
			for key, item in pairs(overrides or {}) do value[key] = item end
			return value
		end
		equal(Rules.pursuit(obs()), true)
		equal(Rules.pursuit(obs({ visible = false })), true)
		equal(Rules.pursuit(obs({ visible = false, distance = Rules.GIVE_UP_DISTANCE })), true)
		equal(Rules.pursuit(obs({ alive = false })), false)
		equal(Rules.pursuit(obs({ hidden = true, visible = false })), false)
		-- A hidden player still in sight (seen while entering) is not lost by hiding.
		equal(Rules.pursuit(obs({ hidden = true, visible = true })), true)
		equal(Rules.pursuit(obs({ distance = Rules.GIVE_UP_DISTANCE + 0.5 })), false)
		equal(Rules.pursuit(obs({ visible = false, distance = Rules.GIVE_UP_DISTANCE + 0.5 })), false)
		for _, bad in ipairs({ 0 / 0, math.huge, -1, "24" }) do equal(Rules.pursuit(obs({ distance = bad })), false) end
		equal(Rules.pursuit(nil), false)
	end)
	-- Fix pass (FP3, chase sized to the sprint): the chase also ends at once when the owner reaches a safe zone (camp or a
	-- shelter) or runs past the pursuit leash from home. Deliberately changes the memory fix's "the pursuit leash only reads
	-- as out of sight": a quarry beyond the leash is now lost, as the plan asks. No homeDistance reads as inside.
	case("FP3: a quarry in a safe zone or past the leash is lost at once", function()
		local function obs(overrides)
			local value = { alive = true, hidden = false, visible = true, distance = 24, safe = false, homeDistance = 60 }
			for key, item in pairs(overrides or {}) do value[key] = item end
			return value
		end
		equal(Rules.pursuit(obs()), true)
		equal(Rules.pursuit(obs({ safe = true })), false, "camp or a shelter ends the chase")
		equal(Rules.pursuit(obs({ safe = true, visible = false })), false)
		equal(Rules.pursuit(obs({ homeDistance = Rules.CHASE_LEASH })), true, "on the leash still counts")
		equal(Rules.pursuit(obs({ homeDistance = Rules.CHASE_LEASH + 0.5 })), false, "past the leash ends the chase")
		equal(Rules.pursuit(obs({ homeDistance = 0 / 0 })), true, "an unknown home distance reads as inside")
		local plain = obs(); plain.safe, plain.homeDistance = nil, nil
		equal(Rules.pursuit(plain), true, "the old observation shape still works")
	end)
	return result
end

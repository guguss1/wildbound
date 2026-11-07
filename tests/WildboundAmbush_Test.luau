-- Invoke with require(freshTestClone)(require(freshAmbushClone), require(freshRulesClone), freshAmbushClone.Source).
-- M4.7 ambush relocation. FS numbers refer to docs/mechanics/wildbound-fair-strike.md.
return function(Ambush, Rules, source)
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
	local K = Ambush.CONSTANTS
	-- Guardian at home, one player far away in fog, timer due, no recent hunt.
	local function input(overrides)
		local value = { now = 500, nextAt = 400, mode = "Patrol", roll = 0.5,
			players = { { x = 140, z = 0 } }, anchors = Ambush.anchors(),
			guardianX = 0, guardianZ = -85, lastHuntAt = 0, anyPlayerInFog = true }
		for key, item in pairs(overrides or {}) do value[key] = item end
		return value
	end

	case("the anchor table matches the decision record and stays inside the territory", function()
		local expected = { Home = { 0, -85, 30 }, NestSide = { 40, -125, 20 }, RuinEast = { 55, -38, 15 },
			RuinWest = { -30, -45, 15 }, WestHollow = { -40, -110, 10 }, SouthGrove = { 40, -140, 10 } }
		local count = 0
		for _, anchor in ipairs(Ambush.anchors()) do
			local want = expected[anchor.id]
			assert(want, "unexpected anchor " .. tostring(anchor.id))
			equal(anchor.x, want[1]); equal(anchor.z, want[2]); equal(anchor.weight, want[3]); equal(anchor.active, true)
			assert(Rules.inTerritory(anchor.x, anchor.z), anchor.id .. " must be in the territory")
			count += 1
		end
		equal(count, 6)
	end)
	case("a due timer in patrol with nobody near moves to an anchor", function()
		local out = Ambush.pick(input())
		equal(out.move, true); equal(out.reason, "moved")
		assert(type(out.anchorId) == "string" and out.x and out.z)
	end)
	case("FS-50 no move outside patrol, with nobody in fog, after a recent hunt or with a player at 39.9", function()
		equal(Ambush.pick(input({ now = 399 })).reason, "notYet")
		for _, mode in ipairs({ "Alert", "Hunt", "Telegraph", "Retreat", 5 }) do
			equal(Ambush.pick(input({ mode = mode })).move, false, tostring(mode))
		end
		equal(Ambush.pick(input({ anyPlayerInFog = false })).reason, "nobodyInFog")
		equal(Ambush.pick(input({ lastHuntAt = 480.01 })).reason, "recentHunt")
		equal(Ambush.pick(input({ lastHuntAt = 480 })).move, true, "exactly 20 s is allowed")
		equal(Ambush.pick(input({ players = { { x = 39.9, z = -85 } } })).reason, "playerNearGuardian")
		equal(Ambush.pick(input({ players = { { x = 40, z = -85 } } })).reason ~= "playerNearGuardian", true)
	end)
	case("an anchor within 40 studs of any player is never chosen", function()
		for roll = 0, 0.99, 0.03 do
			local out = Ambush.pick(input({ roll = roll, guardianX = -40, guardianZ = -110,
				players = { { x = 40, z = -100 }, { x = 140, z = 0 } } }))
			if out.move then
				for _, player in ipairs({ { x = 40, z = -100 }, { x = 140, z = 0 } }) do
					assert(math.sqrt((out.x - player.x) ^ 2 + (out.z - player.z) ^ 2) >= K.MIN_PLAYER_DISTANCE,
						"anchor " .. out.anchorId .. " too close to a player")
				end
			end
		end
	end)
	case("FS-51 orientation fields never change the result", function()
		for roll = 0, 0.99, 0.07 do
			local base = Ambush.pick(input({ roll = roll }))
			for _, extra in ipairs({ { lookVector = { 1, 0, 0 }, camera = "a", gaze = 0 },
				{ lookVector = { -1, 0, 0 }, camera = { x = 5 }, gaze = 180 }, { lookVector = 0 / 0, camera = true, gaze = -1 } }) do
				local value = input({ roll = roll })
				for key, item in pairs(extra) do value[key] = item end
				for _, player in ipairs(value.players) do player.lookVector, player.camera, player.gaze = extra.lookVector, extra.camera, extra.gaze end
				local out = Ambush.pick(value)
				equal(out.move, base.move); equal(out.anchorId, base.anchorId); equal(out.reason, base.reason)
			end
		end
	end)
	case("FS-52 the module reads no camera, gaze, frame or world", function()
		assert(type(source) == "string" and #source > 300, "source missing")
		for _, banned in ipairs({ "Camera", "LookVector", "CFrame", "workspace", "game", "Random", "math.random",
			"os.clock", "tick(" }) do
			assert(not source:find(banned, 1, true), "ambush source uses " .. banned)
		end
	end)
	case("FS-53 weights are normalized, inactive anchors removed, all inactive means no move", function()
		local weights = Ambush.weights(Ambush.anchors(), {})
		local sum = 0
		for _, item in ipairs(weights) do sum += item.p end
		assert(math.abs(sum - 1) < 1e-9, "weights must sum to 1, got " .. sum)
		local anchors = Ambush.anchors()
		anchors[1].active = false
		for _, item in ipairs(Ambush.weights(anchors, {})) do assert(item.id ~= anchors[1].id, "inactive kept") end
		for _, anchor in ipairs(anchors) do anchor.active = false end
		equal(#Ambush.weights(anchors, {}), 0)
		equal(Ambush.pick(input({ anchors = anchors })).reason, "noAnchor")
	end)
	case("a totem holder within 60 studs doubles that anchor's weight", function()
		local plain, boosted = {}, {}
		for _, item in ipairs(Ambush.weights(Ambush.anchors(), {})) do plain[item.id] = item.p end
		for _, item in ipairs(Ambush.weights(Ambush.anchors(), { { x = 40, z = -170, totem = true } })) do boosted[item.id] = item.p end
		assert(boosted.SouthGrove > plain.SouthGrove, "SouthGrove must gain weight")
		assert(boosted.Home < plain.Home, "others lose share")
		local untouched = {}
		for _, item in ipairs(Ambush.weights(Ambush.anchors(), { { x = 40, z = -170, totem = false } })) do untouched[item.id] = item.p end
		equal(untouched.SouthGrove, plain.SouthGrove)
	end)
	case("FS-54 the same inputs give the same result, and the roll spreads choices", function()
		local seen = {}
		for roll = 0, 0.999, 0.01 do
			local first, second = Ambush.pick(input({ roll = roll })), Ambush.pick(input({ roll = roll }))
			equal(first.anchorId, second.anchorId)
			if first.anchorId then seen[first.anchorId] = true end
		end
		local count = 0
		for _ in pairs(seen) do count += 1 end
		assert(count >= 4, "a roll sweep should reach most anchors, got " .. count)
	end)
	case("the current anchor is never chosen again", function()
		for roll = 0, 0.99, 0.05 do
			equal(Ambush.pick(input({ roll = roll })).anchorId ~= "Home", true)
		end
	end)
	case("bad input never moves", function()
		equal(Ambush.pick(nil).move, false)
		equal(Ambush.pick(input({ now = 0 / 0 })).move, false)
		equal(Ambush.pick(input({ roll = 1.5 })).move, false)
		equal(Ambush.pick(input({ guardianX = math.huge })).move, false)
		equal(Ambush.pick(input({ players = "x" })).move, false)
		equal(Ambush.pick(input({ players = { { x = 0 / 0, z = 0 } } })).move, false)
	end)
	case("the timer is 90 to 150 s by day and 60 to 90 s at night", function()
		equal(Ambush.nextDelay("Day", 0), 90); equal(Ambush.nextDelay("Day", 1), 150)
		equal(Ambush.nextDelay("Dusk", 0.5), 120)
		equal(Ambush.nextDelay("Night", 0), 60); equal(Ambush.nextDelay("Night", 1), 90)
		equal(Ambush.nextDelay("Night", 0 / 0), 60); equal(Ambush.nextDelay("Day", -3), 90)
		equal(K.RETRY_SECONDS, 15); equal(K.MIN_PLAYER_DISTANCE, 40); equal(K.HUNT_QUIET_SECONDS, 20)
		assert(K.MIN_PLAYER_DISTANCE > Rules.guardianParameters("Night", true).detectionRange, "40 must exceed night detection")
	end)

	return result
end

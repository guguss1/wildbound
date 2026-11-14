-- Invoke with require(freshTestClone)(WildboundWorld.Source).
-- Aggro and tree fix (user, 2026-11-12: "pierde muy rápido el agro y los árboles lo bloquean todavía"). Measured in
-- Play with a runner at 12 studs/s past ten trunks: with a trunk between them she walked to the spot she last saw
-- her quarry instead of after it (17 to 43 studs behind in 5 s, then a search), her search then pushed against trunks
-- (51 blocked steps: look points inside trunk cores), and three route plans failed. Source contracts for how the
-- world server now follows on memory, keeps the chase clock, and keeps every goal out of solid trunks; the feel is
-- checked in Studio Play.
return function(world)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function at(text, label)
		local index = type(world) == "string" and world:find(text, 1, true)
		assert(index, label or ("missing: " .. text))
		return index
	end

	case("within her memory she follows the quarry itself, not the spot she last saw it", function()
		local follow = at("if not candidate.visible then decision.destination = candidate.root.Position end")
		assert(follow < at("navigate(h, decision.destination, parameters.speed, dt, now)"), "set before the walk, at the hunt's own speed")
		at("Hunt.step(h.huntState, now, current, {}, profile.memorySeconds)", "the memory still decides when the hunt ends")
	end)

	case("losing the quarry searches where it was last known, from an Alert too", function()
		at("h.lastKnown = candidate.root.Position", "remembered every combat step")
		at("local last = h.lastKnown or (h.huntState and h.huntState.lastPosition)", "the search starts there")
		at("\th.lastKnown = nil", "cleared with the target")
		assert(at("local last = h.lastKnown or") < at("\tif last and alive then"), "read before the target is cleared")
	end)

	case("the chase clock only runs while the quarry is out of sight or beyond her detection radius", function()
		local restart = at("if candidate.visible and candidate.distance <= detectionFor(target, parameters.detectionRange)")
		-- Verification finding: between the territory (80) and the chase leash (100) she can follow but never strike, so
		-- a quarry standing there must not hold the chase open for ever: the clock only restarts where a strike can land.
		at("and Rules.inTerritory(candidate.root.Position.X, candidate.root.Position.Z, herReach()) then\n\t\t\t\th.chaseStartedAt, chaseStartedAt = now, now",
			"the clock restarts only for a quarry inside the territory")
		at("h.chaseStartedAt, chaseStartedAt = now, now")
		assert(restart < at("elseif Brain.chaseExpired(chaseStartedAt, now, phase) then"), "restarted before the limit is read")
	end)

	case("every goal she plans or walks to is moved off solid trunks first, on the leash of her mode", function()
		at("gx, gz = freeGoal(gx, gz, leash)")
		at("return standable(cx, cz, leash)")
		assert(at("local function standable(x, z, leash)") < at("local function navigate(h, goal, speed, dt, now)"),
			"the free test is defined before the walk that uses it")
	end)

	case("the points of a search are free too", function()
		at("Brain.step(brain, now, body.Position.X, body.Position.Z, phase, searchPoint)")
		at("local function searchPoint(x, z)")
	end)

	-- Found in Play (2026-11-12): she lost a quarry that walked out of the territory, the search opened with a fake
	-- retreat, and its way back aimed at the raw spot outside the territory. Every step is clamped, so she never
	-- arrived, the fake retreat never ended and she stood at the edge in Search for good (over 40 s measured), blind to
	-- a quarry 7 studs away just outside. The fake retreat now turns back to the search's own clamped, free point.
	case("a fake retreat turns back to the search point, which she can reach", function()
		at("h.fake = Moves.newFake(now, brain.point.x, brain.point.z)")
		assert(not world:find("Moves.newFake(now, last.X, last.Z)", 1, true), "it still aims at the raw last position")
		at("if out.done or not out.destination or now >= brain.untilAt then", "and a fake retreat never outlasts its search")
		assert(at("Brain.lostSight(brain, last.X, last.Z, now, phase, searchPoint)") < at("h.fake = Moves.newFake(now, brain.point.x, brain.point.z)"),
			"the search point is placed first, inside the territory and off any trunk")
	end)

	-- Measured in Play (2026-11-12): a hunt set to 13 studs/s moved at about 10, and set to 17 at about 12. A step
	-- stopped at each route waypoint and threw the rest of its length away (waypoints are 4 studs apart), and the fixed
	-- step dropped the time left over after each 0.2 s. Both made her slower than her tuning, so she never closed on a
	-- walking quarry.
	case("a step carries what it has left past a waypoint, and never moves more than speed x dt", function()
		local from, to = at("local function navigate(h, goal, speed, dt, now)"), at("local function face(h, point)")
		local body = world:sub(from, to)
		for _, text in ipairs({ "local left = speed * dt", "stepToward(h, bodyAt(x, z), speed, left / speed)",
			"left -= flatDistance(h.body.Position, from)", "stepToward(h, goal, speed, left / speed)", "if speed <= 0 then return end" }) do
			assert(body:find(text, 1, true), "navigate lacks: " .. text)
		end
	end)

	case("the fixed step keeps the time left over, so five steps a second are five steps", function()
		at("accumulator -= 0.2")
		assert(not world:find("accumulator = 0\n", 1, true), "the remainder is still dropped")
		at("accumulator += math.min(dt, 0.2)", "a long frame still adds one step at most")
	end)

	-- Recorded in the user's own Play (2026-11-12, "se siente que te vio pero no le importas"): she noticed the player
	-- at 49 studs (Alert, the grin shows), a ruin pillar crossed her sight line on the next 0.2 s step, and she turned
	-- and walked home, blind for the recovery time, with the player 40 studs away in the open. An Alert needed its
	-- quarry in sight on every step. Once she has noticed a quarry she now keeps it like a hunt does: out of sight only
	-- starts her memory, and when the wind-up ends she comes.
	case("an Alert keeps a quarry that slips out of sight, like a hunt", function()
		at("local candidate = quarryContext(h, target)")
		assert(not world:find("candidate = targetContext(h, target, Rules.GIVE_UP_DISTANCE, false, Rules.CHASE_LEASH)", 1, true),
			"an Alert still drops a quarry it cannot see for one step")
		local _, count = world:gsub("h%.lastKnown = candidate%.root%.Position", "")
		assert(count >= 2, "the quarry's place is known from the step she notices it: " .. count)
	end)

	case("the fair-strike and leash gates are untouched by the aggro fix", function()
		at("local latest = binding and targetContext(h, target, Rules.ATTACK_RANGE) or nil", "a strike still needs reach, in the territory")
		at("and Rules.inTerritory(candidate.root.Position.X, candidate.root.Position.Z, herReach()) then\n\t\t\t\t\th.telegraphEndsAt", "a telegraph still starts only in the territory")
		at("local x, z = Rules.clampTerritory(stepX, stepZ, leash)", "every step is still clamped")
		assert(at("h.lastKnown = candidate.root.Position") < at("elseif candidate.hidden and not candidate.visible then"),
			"a quarry that hid unseen still ends the chase at once")
	end)

	return result
end

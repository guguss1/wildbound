-- Invoke with require(freshTestClone)(WildboundWorld.Source).
-- Patrol fix (found in Play, 2026-11-12): source contracts for how the world server keeps La Silueta's patrol points
-- out of solid trunks and gives up a point she cannot reach. The arithmetic is in WildboundGuardianPath_Test (the
-- ring search and the give-up count); that she walks her rounds is checked in Studio Play.
return function(world)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function has(text, label)
		assert(type(world) == "string" and world:find(text, 1, true), label or ("missing: " .. text))
	end
	local function at(text)
		local index = world:find(text, 1, true)
		assert(index, "missing: " .. text)
		return index
	end

	case("every patrol point, an anchor's centre and its four corners, is moved to a free spot", function()
		has("GuardianPath.freePoint(x, z, standable)")
		has("h.center = patrolPoint(x, z)", "the centre")
		has("table.insert(h.patrol, patrolPoint(px, pz))", "the corners")
	end)

	case("free means nothing that collides within the pathing agent's radius, inside the territory", function()
		local from, to = at("local function standable(x, z, leash)"), at("local function patrolPoint(x, z)")
		local body = world:sub(from, to)
		for _, text in ipairs({ "Rules.clampTerritory(x, z, herReach(leash))", "RespectCanCollide = true", "reliefFolder", "{ runtime }",
			"player.Character", "GetPartBoundsInRadius(bodyAt(x, z), POINT_CLEARANCE, params)" }) do
			assert(body:find(text, 1, true), "the free test lacks: " .. text)
		end
		has("local POINT_CLEARANCE = 2")
		has("AgentRadius = 2", "the clearance is the pathing agent's radius")
	end)

	case("a relocation lands on the anchor's free centre, never on its raw coordinates", function()
		assert(not world:find("PivotTo(CFrame.new(bodyAt(out.x, out.z)))", 1, true), "she is still put on the raw anchor")
		assert(at("setCenter(h, out.x, out.z)") < at("h.guardian:PivotTo(CFrame.new(h.center))"), "the centre is set first")
	end)

	case("a patrol corner and the way home are given up when she gets no closer, and it is counted", function()
		has("flatDistance(body.Position, patrol[patrolIndex]) < 2 or gaveUp(h, patrol[patrolIndex], now)", "patrol")
		has("flatDistance(body.Position, h.center) < 2 or gaveUp(h, h.center, now)", "the way home")
		has("GuardianPath.gaveUp(h.progress, point.X, point.Z, position.X, position.Z, now)")
		has("progress = GuardianPath.newProgress()", "each hunter has its own count")
		has("h.navStats.gaveUp += 1", "telemetry (Nav_gaveUp)")
		has("gaveUp = 0 }", "the counter starts at zero")
	end)

	return result
end

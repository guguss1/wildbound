-- Invoke with require(freshTestClone)(WildboundWorld.Source, WildboundServer.Source).
-- Expedition relief, task R5 (docs/mechanics/wildbound-expedition-islands.md section 1): source contracts for how
-- the world server walks La Silueta on the relief and how the inventory server stands creatures, eggs and drops on
-- their own ground. The arithmetic is in WildboundRelief_Test and WildboundGuardianPath_Test; the feel is in Play.
return function(worldSource, serverSource)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function has(source, needle, label)
		assert(source:find(needle, 1, true), (label or "missing") .. ": " .. needle)
	end

	case("R5: both servers read the relief through WildboundRelief and the exported layout", function()
		for name, source in pairs({ world = worldSource, server = serverSource }) do
			has(source, 'WaitForChild("WildboundRelief")', name)
			has(source, 'FindFirstChild("WildboundReliefLayout")', name)
		end
	end)

	case("R5: guardian movement no longer uses home.Y", function()
		assert(not worldSource:find("home.Y", 1, true), "home.Y is still used for a position")
		has(worldSource, "GuardianPath.groundStep(", "each step takes its height from the ground")
		has(worldSource, "local function bodyAt(", "positions are lifted from the ground")
		assert(not worldSource:find("Vector3.new(body.Position.X, 3, body.Position.Z)", 1, true), "plans start at local ground")
	end)

	case("R5: the guardian's obstacle cast ignores the relief folder", function()
		has(worldSource, 'map:FindFirstChild("Relief")', "the relief folder is looked up")
		local stepStart = worldSource:find("local function stepToward(", 1, true)
		assert(stepStart, "stepToward missing")
		local stepBody = worldSource:sub(stepStart, (worldSource:find("\nend\n", stepStart, true)))
		has(stepBody, "table.insert(excluded, reliefFolder)", "a rising slope must not read as a wall")
	end)

	case("R5: creature visuals no longer share one groundY", function()
		assert(not serverSource:find("local groundY = creatureMarker.Position.Y", 1, true), "one shared groundY remains")
		assert(not serverSource:find("groundY, ", 1, true), "a visual still uses the shared groundY")
		has(serverSource, "local function groundAt(", "a ground function per position")
		has(serverSource, "entry.lift", "a wandering creature keeps its lift over the ground it walks on")
	end)

	return result
end

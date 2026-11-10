-- Invoke with require(freshTestClone)({ world = WildboundWorld.Source, worldClient = WildboundWorldClient.Source,
-- fear = WildboundFearClient.Source, audio = WildboundAudioClient.Source, server = WildboundServer.Source }).
-- Fix pass (FP2, one Silueta per player): source contracts for how the world server spawns one hunter per player,
-- binds it to its owner (targets, strikes, marks, warnings and notices for the owner alone), staggers the hunters and
-- removes them, and how each client picks its own hunter and draws the others faint. The roster's numbers are in
-- WildboundHunters_Test; the behaviour is checked in Studio Play.
return function(sources)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function has(source, needle, label)
		assert(type(source) == "string" and source:find(needle, 1, true), (label or "missing") .. ": " .. needle)
	end
	local function hasNot(source, needle, label)
		assert(type(source) == "string" and not source:find(needle, 1, true), (label or "unexpected") .. ": " .. needle)
	end
	local function body(source, header)
		local start = source:find(header, 1, true)
		assert(start, header .. " missing")
		local finish = source:find("\nend\n", start, true)
		return source:sub(start, finish or #source)
	end
	local world, worldClient = sources.world or "", sources.worldClient or ""
	local fear, audio, server = sources.fear or "", sources.audio or "", sources.server or ""

	case("FP2: the world spawns one hunter per player, bound to its owner, and removes it when the player leaves", function()
		has(world, 'require(script.Parent:WaitForChild("WildboundHunters"))')
		has(world, "Hunters.add(roster, player.UserId, Rules.MAX_HUNTERS)", "the cap is the tunable")
		has(world, 'guardian:SetAttribute("Owner", player.UserId)', "the model names its owner for the clients")
		has(body(world, "local function addPlayer("), "addHunter(player)", "a joining player gets a hunter")
		has(body(world, "table.insert(connections, Players.PlayerRemoving:Connect("), "destroyHunter(h)", "a leaving player's hunter goes")
		has(body(world, "local function destroyHunter("), "Hunters.remove(roster, h.player.UserId)")
		has(world, "Hunters.count(roster) < Rules.MAX_HUNTERS then addHunter(player)", "a freed slot goes to a waiting player")
	end)

	case("FP2: a hunter only ever considers its owner as quarry", function()
		has(body(world, "local function targetContext("), "not Hunters.owns(h.roster, player.UserId)", "anyone else reads as nobody")
		local stepBody = body(world, "local function step(h, now, dt)")
		has(stepBody, "targetContext(h, player, detectionFor(player, parameters.detectionRange))", "acquisition asks about the owner")
		hasNot(stepBody, "for player in pairs(records)", "no scan over every player")
		-- Items IT1: the memory now passes through the owner's Amuleto (Gear.memory). Deliberately changed from
		-- profile.memorySeconds; the empty challenger list is what this case pins.
		has(stepBody, "Hunt.step(h.huntState, now, current, {}, Gear.memory(profile.memorySeconds, gearOf(target)))",
			"no challenger ever switches the hunt")
	end)

	case("FP2: strikes, marks, warnings, acknowledgements and notices go through the owner's own hunter", function()
		has(world, "attackWarning:FireClient(target,", "the warning reaches the target only")
		has(body(world, "local function isMarked("), "local h = hunters[player]", "the mark lives in the owner's ledger")
		has(world, "FairStrike.acknowledge(h.ledger, player.UserId", "an acknowledgement reaches the owner's ledger")
		has(world, "FairStrike.ready(h.ledger, player.UserId", "readiness too")
		has(world, "FairStrike.pulse(h.ledger, player.UserId", "liveness too")
		has(body(world, "local function snapshot("), "local h = hunters[player]", "the snapshot describes the owner's hunter")
		has(body(world, "local function stepThreat("), "local h = hunters[player]", "the threat level too")
	end)

	case("FP2: hunters share home and the diamond, start staggered, and never plan routes in lockstep", function()
		has(world, "Hunters.stagger(bound.slot)")
		has(world, "local start = patrol[stagger.patrolIndex]", "each slot starts on its own corner")
		has(world, "GuardianPath.needsPlan(h.nav, gx, gz, now - h.planDelay)", "a per-slot gap between plans")
		has(world, "for _, h in ipairs(hunterList) do", "every hunter hears a noise")
	end)

	case("FP2: each client picks its own hunter by owner and draws the others faint, grin hidden", function()
		for name, source in pairs({ worldClient = worldClient, fear = fear, audio = audio }) do
			has(source, 'GetAttribute("Owner") == player.UserId', name .. " picks its own hunter")
		end
		has(worldClient, "View.hunterFade(", "the fade is the pure rule")
		has(worldClient, "LocalTransparencyModifier", "a client-only fade the server never overwrites")
		has(worldClient, '"HorrorGrin"', "another player's grin is hidden here")
		hasNot(worldClient, "FireServer(\"Hunter", "nothing about hunters is sent to the server")
	end)

	case("FP2: the inventory server reads the capture context from the player's own hunter", function()
		has(server, "local function guardianReading(player, position)")
		has(server, "guardianReading(player, position)")
		hasNot(server, "guardianReading(position)")
	end)

	return result
end

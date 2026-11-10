-- Invoke with require(freshTestClone)({ world = WildboundWorld.Source, server = WildboundServer.Source,
-- audio = WildboundAudioClient.Source, text = require(WildboundText) }, require(freshIslandClone)).
-- Fix pass (FP4): source contracts for how the world server uses La Silueta's moves (WildboundSiluetaMoves): the lunge
-- in the hunt, the fake retreat in the search, the flashlight glare and its notice, the chase-start scream through the
-- guardian noise path to the islands, and the client's audible tell. The numbers are in WildboundSiluetaMoves_Test.
return function(sources, Island)
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
	local function body(source, header)
		local start = source:find(header, 1, true)
		assert(start, header .. " missing")
		local finish = source:find("\nend\n", start, true)
		return source:sub(start, finish or #source)
	end
	local world, server, audio = sources.world or "", sources.server or "", sources.audio or ""
	local text = type(sources.text) == "table" and sources.text or {}

	case("FP4a: the hunt lunges through the pure rule, with a visible tell and the burst speed", function()
		has(world, 'require(script.Parent:WaitForChild("WildboundSiluetaMoves"))')
		local stepBody = body(world, "local function step(h, now, dt)")
		has(stepBody, "Moves.lungeStep(h.lunge, now, h.mode)", "every step asks the rule")
		has(stepBody, "if lunge.speed then parameters.speed = lunge.speed end", "the burst replaces the hunt speed")
		has(stepBody, 'h.guardian:SetAttribute("LungeAt", now)', "the tell is published for the clients")
		has(stepBody, "h.outline.OutlineColor = lunge.phase == \"tell\"", "the tell is visible on the outline")
		-- The steering call the pressure simulator parses is unchanged.
		has(stepBody, "navigate(h, decision.destination, parameters.speed, dt, now)")
	end)

	case("FP4a: the owner's client hears the tell", function()
		has(audio, 'GetAttribute("LungeAt")', "the audio client watches its own hunter's tell")
	end)

	case("FP4b: a lost quarry may start the search with a fake retreat", function()
		local lose = body(world, "local function loseTarget(")
		has(lose, "Moves.fakeRetreat(h.rng:NextNumber())")
		has(lose, "h.fake = Moves.newFake(now, last.X, last.Z)")
		local stepBody = body(world, "local function step(h, now, dt)")
		has(stepBody, "Moves.fakeStep(h.fake, now, body.Position.X, body.Position.Z)")
	end)

	case("FP4c: the owner's flashlight cone, the stagger and its Spanish notice", function()
		has(world, "Moves.glareStep(h.glare, dt, {", "the rule decides")
		has(world, "root.CFrame.LookVector", "the server's own forward vector, never a camera")
		has(world, "h.staggerUntil = now + out.seconds")
		has(world, "now < h.staggerUntil", "a staggered hunter neither moves nor strikes")
		has(world, "Moves.resetGlare(h.glare)", "once per chase")
		assert(type(text.ABILITY) == "table" and text.ABILITY.glare == "La luz la frena", "the notice says La luz la frena")
		has(world, "abilityWords.glare")
	end)

	case("FP4d: the chase-start scream reaches the islands through the guardian noise path", function()
		local stepBody = body(world, "local function step(h, now, dt)")
		has(stepBody, 'noiseEvent:Fire("siluetaScream"', "fired when the chase starts")
		has(stepBody, "Moves.screamReach()", "behind the toggle")
		has(server, 'kind == "siluetaScream"', "the inventory server hears it for the islands")
		has(server, 'Island.event(island.meter, "SiluetaScream")')
		assert(type(Island) == "table" and type(Island.CONSTANTS.PENALTY) == "table", "island module")
		assert(Island.CONSTANTS.PENALTY.SiluetaScream >= Island.CONSTANTS.WAKE, "the scream wakes a sleeping island")
		-- The world's own hearing ignores the new kind, so hunters never chase each other's screams.
		local hear = body(world, "table.insert(connections, noiseEvent.Event:Connect(")
		assert(not hear:find("siluetaScream", 1, true), "the world does not hear its own scream")
	end)

	return result
end

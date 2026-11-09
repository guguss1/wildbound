-- Invoke with require(freshTestClone)(WildboundServer.Source, WildboundWorld.Source, WildboundClient.Source).
-- Expedition islands, task I6 (docs/mechanics/wildbound-expedition-islands.md section 2, decisions EI-2 and EI-5):
-- source contracts for how the inventory server runs the island nests, the shared sleep meter, the scream, the
-- woken adult's chase and the cria's cry, and how the world server hears them. The rule's numbers are in
-- WildboundIsland_Test; behavior is checked in Play with the Studio-only IslandProbe.
return function(serverSource, worldSource, clientSource)
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
	local function hasNot(source, needle, label)
		assert(not source:find(needle, 1, true), (label or "unexpected") .. ": " .. needle)
	end
	local function block(source, startNeedle, endNeedle)
		local i = source:find(startNeedle, 1, true)
		assert(i, "block start missing: " .. startNeedle)
		local j = source:find(endNeedle, i + #startNeedle, true)
		assert(j, "block end missing: " .. endNeedle)
		return source:sub(i, j)
	end

	case("I6: the server builds the islands from the layout with one meter per island", function()
		has(serverSource, 'WaitForChild("WildboundIsland")')
		has(serverSource, 'FindFirstChild("WildboundIslandLayout")')
		has(serverSource, "Island.newMeter(spec)")
		has(serverSource, "Island.rollContent(")
		has(serverSource, "Island.respawnSeconds(")
		has(serverSource, "Island.nestCount(")
		hasNot(serverSource, "Wild.activeSlotIds(", "the wandering slots are retired")
	end)

	case("I6: the meter is never read from a client", function()
		local handler = block(serverSource, "actionRemote.OnServerEvent:Connect", "\nend)")
		hasNot(handler, "meter"); hasNot(handler, "Island")
		local stance = block(serverSource, "stanceRemote.OnServerEvent:Connect", "\nend)")
		hasNot(stance, "meter")
		local _, remotes = serverSource:gsub('Instance.new%("RemoteEvent"%)', "")
		assert(remotes == 4, "no new remote, got " .. remotes .. " RemoteEvent constructors")
	end)

	case("I6: one player's noise wakes the island for everyone", function()
		has(serverSource, 'Island.event(island.meter, "SprintNoise"')
		has(serverSource, 'Island.event(island.meter, "Rustle"')
		has(serverSource, 'noiseEvent:Fire("scream", spec.tier, spec.x, spec.z)')
	end)

	case("I6: the nest prompt hides while Alerta", function()
		has(serverSource, "Island.nestOpen(")
		local wildlife = block(serverSource, "local function stepWildlife(now)", "\nend\n")
		has(wildlife, "nestOpen", "the cria prompt checks the nest")
		has(serverSource, "Text.ISLAND.guarded")
	end)

	case("I6: the facing input uses the server forward vector only", function()
		has(serverSource, "root.CFrame.LookVector")
		hasNot(serverSource, "CurrentCamera")
		hasNot(serverSource, "Facing", "no client facing input")
	end)

	-- Deliberately changed in the chase pass (CP-D5). It was "never damages": La Silueta was the only thing that hurt.
	-- Now a landed adult strike drops the cria and, only in the private damage mode and for a player past the first
	-- paid trip (the same gates as La Silueta), deals damage through one TakeDamage behind that guard.
	case("CP4: the woken adult chases with the leashed rule and its strike can hurt, behind the damage gates", function()
		has(serverSource, "Island.chaseTarget(")
		has(serverSource, "Island.newChase(")
		has(serverSource, "Island.chaseStep(")
		has(serverSource, "state:releaseCarried(")
		has(serverSource, "FairStrike.effectiveMode(")
		has(serverSource, "FairStrike.lethal(")
		has(serverSource, "Island.hitEffect(")
		local count = 0
		for _ in serverSource:gmatch("TakeDamage") do count += 1 end
		assert(count == 1, "one TakeDamage, found " .. count)
		local strike = block(serverSource, "local function adultHit(", "\nend\n")
		has(strike, "TakeDamage", "the damage lives in adultHit")
		has(strike, "if effect.damage > 0 then", "behind the gate")
		has(serverSource, "Text.ISLAND.strike", "the wind-up warns the thief")
		has(serverSource, 'adult.model:SetAttribute("Swing", adult.rearing)', "the swing is visible to every client")
		-- The Studio-only IslandProbe can mark a player lethal for the Play check (no paid trip needed); it lives inside
		-- the RunService:IsStudio() block, so a live server never has it.
		local probe = block(serverSource, "if RunService:IsStudio() then", "\nend\n")
		has(probe, 'op == "lethal"', "the probe op lives in the Studio block")
		has(serverSource, "probeLethal[player.UserId] == true", "lethalPlayer honours it")
		hasNot(serverSource, "Health -", "no direct health write")
	end)

	case("I6: a carried cria cries into the guardian noise", function()
		has(serverSource, "Carry.cry(")
		has(serverSource, 'noiseEvent:Fire("cry"')
		has(serverSource, "Text.CARRY.cry")
		has(serverSource, 'ability == "Crying"')
	end)

	case("I4: the world hears screams and cries and shares rustles", function()
		has(worldSource, 'kind == "scream"')
		has(worldSource, 'kind == "cry"')
		has(worldSource, 'noiseEvent:Fire("rustle"')
		has(worldSource, "crying = isCrying(player)")
	end)

	-- Fear pass (FA2): a granted island capture is a loud grab, and the first-steal flag is read before the bag
	-- changes (afterwards the thief carries the cria and island 1's cap would no longer apply).
	case("FA2: a granted island capture is a grab that can wake the parents", function()
		local grant = block(serverSource, "if out.grant then", "elseif entry and entry.brain then")
		has(grant, 'Island.event(island.meter, "CriaTaken", { firstSteal = firstSteal })')
		has(grant, "wakeIsland(island, now)")
		local before = grant:find("local firstSteal", 1, true)
		local complete = grant:find("state:completeCapture(", 1, true)
		assert(before and complete and before < complete, "firstSteal is read before the capture completes")
	end)

	case("K2: the refuge card carries the bonus and the next island", function()
		has(serverSource, "Refuge.nextIsland(")
		has(serverSource, "firstBonus = receipt.firstBonus")
		has(clientSource, "view.bonus")
		has(clientSource, "view.next")
	end)

	case("I6: a Studio-only, server-only probe drives the islands for Play checks", function()
		local studio = serverSource:find("RunService:IsStudio()", 1, true)
		local probe = serverSource:find('"IslandProbe"', 1, true)
		assert(studio and probe and probe > studio, "IslandProbe lives inside the Studio-only block")
		has(serverSource, "islandProbe.Parent = telemetry")
	end)

	return result
end

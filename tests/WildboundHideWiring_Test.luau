-- Invoke with require(freshTestClone)(WildboundWorld.Source, WildboundServer.Source, WildboundWorldClient.Source).
-- Delivery D6 and D8: how the world server plugs hiding into the guardian's single sight check, owns the spots,
-- finds hidden players by dwell and publishes the per-player threat level; and how the world client exits.
-- Source contracts, like WildboundCarry_Test: the behaviour itself is checked in Studio Play (D13).
return function(worldSource, serverSource, clientSource)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function has(source, needle, label)
		assert(type(source) == "string" and source:find(needle, 1, true), (label or needle) .. " missing")
	end
	local function body(source, header)
		local start = source:find(header, 1, true)
		assert(start, header .. " missing")
		local finish = source:find("\nend\n", start, true)
		return source:sub(start, finish or #source)
	end
	worldSource = type(worldSource) == "string" and worldSource or ""

	case("D6: a hidden player is not acquired", function()
		local context = body(worldSource, "local function targetContext(")
		has(context, "local hidden = records[player] ~= nil and records[player].hide ~= nil", "hidden flag in targetContext")
		has(context, "local inSight = not hidden and visible(", "sight is never true for a hidden player")
		has(context, "if not inSight and not allowHidden then return nil end", "no acquisition out of sight")
	end)

	-- Deliberately changed in the fix pass (FP2, one Silueta per player): every sight check names the hunter asking
	-- (`h`), which only ever asks about its owner.
	case("D6: a hidden player is not struck even in dwell", function()
		-- The strike gate asks without allowHidden, so a hidden target has no context and the strike fails.
		has(worldSource, "targetContext(h, target, Rules.ATTACK_RANGE)", "strike re-check")
		assert(not worldSource:find("targetContext(h, target, Rules.ATTACK_RANGE, true)", 1, true), "strike allows hidden")
	end)

	case("D6: a hunt on a player who hides ends, and she resumes her patrol", function()
		-- Hunt keeps the context with visible = false, so the hunt memory runs out and loseTarget searches.
		-- Deliberately changed in the chase pass (CP-D2): the hunt keeps its quarry to the give-up distance and the
		-- pursuit leash (was Rules.CHASE_RANGE, 65); a quarry who hides unseen is lost at once.
		-- Deliberately changed again by the memory fix (2026-11-09): Hunt and Telegraph read the quarry through
		-- quarryContext, where anything but legal sight only reads as out of sight. Changed again on 2026-11-12 (the
		-- user's Play: an Alert dropped its quarry when a ruin pillar crossed the sight line for one step): Alert reads
		-- the quarry the same way; a player who hides unseen still breaks it, through Rules.pursuit.
		has(worldSource, "candidate = quarryContext(h, target)", "hunt and telegraph keep an unseen quarry")
		has(worldSource, "targetContext(h, player, Rules.GIVE_UP_DISTANCE, false, Rules.CHASE_LEASH)", "legal sight is the old check, inside quarryContext")
		has(worldSource, "candidate.hidden and not candidate.visible", "hiding unseen breaks the chase")
		-- Chase pass, found in the Play check: during the 2.5 s repeat the giant walked into its quarry and stood inside
		-- the player. It now holds at half its reach and faces the quarry.
		has(worldSource, "candidate.distance <= Rules.ATTACK_RANGE * 0.5", "it holds at arm's length")
		-- Deliberately changed (user decision 2026-11-14): the lost hunt resumes the patrol instead of searching.
		has(worldSource, "-- When she loses sight completely or the quarry hides, she immediately resumes patrolling.")
		assert(not worldSource:find("Brain.lostSight(", 1, true), "no search is placed on loss")
	end)

	case("memory fix: the spawn pad, the fog edge, the leash or a floor change never end a hunt early", function()
		local quarry = body(worldSource, "local function quarryContext(")
		has(quarry, "Rules.pursuit({", "the pure rule decides whether the chase goes on")
		has(quarry, "targetContext(h, player, Rules.GIVE_UP_DISTANCE, false, Rules.CHASE_LEASH)", "legal sight is the old check")
		has(quarry, "visible = seen ~= nil", "anything else is out of sight, so the memory runs")
		-- After a telegraph, a live quarry out of sight is hunted again on memory instead of dropped.
		has(worldSource, "local again = quarryContext(h, target)", "the repeat keeps an unseen quarry")
		assert(not worldSource:find("local again = targetContext(", 1, true), "the repeat still needs sight")
	end)

	-- Fix pass (FP3): the pursuit rule hears whether the owner stands in a safe zone and how far from home they are.
	case("FP3: the quarry check passes the safe zone and the distance from home", function()
		local quarry = body(worldSource, "local function quarryContext(")
		has(quarry, "safe = safe", "a safe zone ends the chase")
		has(quarry, "homeDistance = Rules.distance(position.X, position.Z, Rules.HOME_X, Rules.HOME_Z)", "the leash ends it")
	end)

	case("D6: entering during Alert, Hunt or Telegraph is refused", function()
		local enter = body(worldSource, "local function enterHide(")
		has(enter, "Hide.canEnter(", "the pure rule decides")
		has(enter, "seen = result ~= nil and result.state == \"seen\"", "awareness seen feeds the rule")
		has(enter, "capturing = isCapturing(player)", "an open capture is checked")
		has(serverSource, "if ability == \"Capturing\" then", "the inventory script answers Capturing")
	end)

	case("D6: two players cannot take one spot", function()
		local enter = body(worldSource, "local function enterHide(")
		has(enter, "occupied = hideOccupants[id] ~= nil and hideOccupants[id] ~= player")
		has(enter, "hideOccupants[id] = player")
		has(body(worldSource, "local function releaseHide("), "if hideOccupants[hide.id] == player then hideOccupants[hide.id] = nil end")
	end)

	case("D6: death and capture release the spot", function()
		has(worldSource, "releaseHide(player, \"dead\", ", "a dead or replaced character releases")
		has(worldSource, "player.CharacterRemoving", "character removal is watched")
		local removing = body(worldSource, "table.insert(connections, Players.PlayerRemoving:Connect(")
		has(removing, "releaseHide(player, \"left\", ", "leaving releases")
	end)

	case("D6: exit unanchors at the exit point and only the server moves the character", function()
		local release = body(worldSource, "local function releaseHide(")
		has(release, "Hide.exitPoint(", "exit point from the pure rule")
		has(release, "if reason == \"found\" then gx, gz = 2 * hide.x - gx, 2 * hide.z - gz end", "a found player lands in sight")
		has(release, "Anchored = false", "the root is released")
		has(worldSource, "action ~= \"HideExit\"", "HideExit is a known action")
		has(worldSource, "releaseHide(player, \"exit\", now)", "HideExit releases with no arguments")
		has(worldSource, "player:SetAttribute(\"WildboundHidden\", id)", "hidden attribute set on entry")
	end)

	case("D6: discovery, the time limit and the rustle", function()
		local stepper = body(worldSource, "local function stepHiding(")
		has(stepper, "Hide.discover(hide.dwell,", "dwell discovery each step")
		has(stepper, "Hide.tooLong(hide.enteredAt, now)", "45 s limit")
		has(stepper, "Brain.engage(brain, now, phase)", "a found player is engaged")
		has(body(worldSource, "local function enterHide("), "hearNoise(\"rustle\",", "entering rustles")
		has(worldSource, "stepHiding(now)", "stepped with the fixed step")
	end)

	-- Caramelo v5 (odd/tasks/wildbound-caramelo-v2.md V5-D2): the candy creatures run in other server scripts; one that
	-- stood near a hidden player's spot for the dwell time reports it on the server-only HideFound event, and the player is
	-- found as by La Silueta, pulled out on the finder's side. The candy kingdom's hollows read "cave".
	case("V5-D2: other server scripts report a find (HideFound) and the player is found on the finder's side", function()
		has(worldSource, 'local hideFound = network:FindFirstChild("HideFound")', "one event, reused by a restarted script")
		has(worldSource, 'Instance.new("BindableEvent")', "server to server only")
		has(worldSource, 'hideFound.Name = "HideFound"')
		has(worldSource, "if stopped or typeof(player) ~= \"Instance\" or not player:IsA(\"Player\") then return end", "validated")
		has(worldSource, 'releaseHide(player, "found", workspace:GetServerTimeNow(), x, z)', "found like by La Silueta")
		local release = body(worldSource, "local function releaseHide(")
		has(release, "if type(fromX) == \"number\" and type(fromZ) == \"number\" then gx, gz = fromX, fromZ end", "the finder's side")
		has(worldSource, 'spot:FindFirstChild("Cave") and "cave"', "the candy hollows have their own words")
	end)

	case("D6: the prompt is server-bound, H, with the Spanish words", function()
		has(worldSource, "CollectionService:GetTagged(\"WildboundHideSpot\")")
		has(worldSource, "Keys.HIDE", "the prompt key comes from WildboundPromptKeys")
		has(worldSource, "hideWords.prompt")
	end)

	case("D8: the threat level is computed and published per player", function()
		local stepper = body(worldSource, "local function stepThreat(")
		has(stepper, "Threat.update(record.threat,", "pure hysteresis")
		has(stepper, "hidden = record.hide ~= nil", "hidden demotes")
		has(stepper, "SetAttribute(\"WildboundThreatLevel\", level)")
		has(stepper, "SetAttribute(\"WildboundThreatAt\", now)")
		has(worldSource, "stepThreat(now)", "stepped with the fixed step")
	end)

	-- CA4: no global cycle, so the Studio-only clock shift (D13) has nothing to shift and is gone.
	case("D13 CA4 CF1: the world reads the phase of a place (BiomeLight), with no clock shift", function()
		has(worldSource, "local phase, clockTime = PlaceRules.phaseAt(x, z)")
		assert(not worldSource:find("StudioClockShift", 1, true), "no clock shift left")
		assert(not worldSource:find(":GetAttribute(", 1, true), "no attribute is read back")
		assert(not worldSource:find("originTime", 1, true), "no cycle origin")
	end)

	case("D6: the client exits by button, H or the thumbstick and never moves itself", function()
		has(clientSource, "request(\"HideExit\")", "the client asks the server to exit")
		has(clientSource, "WildboundHidden", "the client follows the hidden attribute")
		has(clientSource, "Enum.KeyCode.H", "H exits")
		has(clientSource, "MoveDirection.Magnitude > 0.5", "the thumbstick exits")
		has(clientSource, "hideWords.exit", "the Salir button")
	end)

	return result
end
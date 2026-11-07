-- Local-source P0 world adapter. Deploy beside WildboundWorldRules after authorized testing resumes.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Rules = require(script.Parent:WaitForChild("WildboundWorldRules"))
local Hunt = require(script.Parent:WaitForChild("WildboundSiluetaHunt"))
local Awareness = require(script.Parent:WaitForChild("WildboundSiluetaAwareness"))
local FairStrike = require(script.Parent:WaitForChild("WildboundFairStrike"))
local Ambush = require(script.Parent:WaitForChild("WildboundAmbush"))
local map = workspace:WaitForChild("WildboundP0", 15)
local network = ReplicatedStorage:WaitForChild("WildboundNetwork", 15)
if not map or not network or not network:IsA("Folder") then
	warn("Wildbound world: map and inventory network are required.")
	return
end
local eligibility = network:WaitForChild("Eligibility", 15)
if not eligibility or not eligibility:IsA("BindableFunction") then
	warn("Wildbound world: authoritative inventory Eligibility is required.")
	return
end
-- Server-to-server signal for the capture adapter (M3.3). Missing is fine: the world runs without it.
local strikeEvent = network:FindFirstChild("CaptureStrike")
if strikeEvent and not strikeEvent:IsA("BindableEvent") then strikeEvent = nil end
-- M5.5 totem downside (docs/mechanics/wildbound-economy-p0.md): a holder is sensed from farther and draws
-- ambush anchors. The inventory script reports holders on a server-only event; missing means no holders.
local Economy, EconomyConfig = nil, nil
do
	local economyModule = ReplicatedStorage:FindFirstChild("WildboundEconomy")
	local configModule = ReplicatedStorage:FindFirstChild("WildboundEconomyConfig")
	if economyModule and configModule and economyModule:IsA("ModuleScript") and configModule:IsA("ModuleScript") then
		local economyOk, economyValue = pcall(require, economyModule)
		local configOk, configValue = pcall(require, configModule)
		if economyOk and configOk then Economy, EconomyConfig = economyValue, configValue end
	end
end
local totemHolders = setmetatable({}, { __mode = "k" })
local totemEvent = network:FindFirstChild("TotemChanged")
if totemEvent and totemEvent:IsA("BindableEvent") then
	totemEvent.Event:Connect(function(player, active)
		if typeof(player) == "Instance" and player:IsA("Player") then totemHolders[player] = active == true or nil end
	end)
end
-- Detection only. Chase range is never widened.
local function detectionFor(player, base)
	if Economy and totemHolders[player] then return Economy.detectionRange(EconomyConfig, base, true) end
	return base
end
-- A second copy must never overwrite an existing world, remote or another script's objects.
if map:FindFirstChild("WildboundWorldRuntime") or network:FindFirstChild("WorldAction")
	or network:FindFirstChild("WorldState") or network:FindFirstChild("AttackWarning")
	or network:FindFirstChild("AttackResolved") or network:FindFirstChild("AttackAck")
	or network:FindFirstChild("ClientReady") or network:FindFirstChild("FieldPulse") then
	warn("Wildbound world: duplicate startup refused.")
	return
end
local runtime = Instance.new("Folder")
runtime.Name = "WildboundWorldRuntime"
local function remote(name)
	local value = Instance.new("RemoteEvent")
	value.Name, value.Parent = name, network
	return value
end
local actionRemote, stateRemote = remote("WorldAction"), remote("WorldState")
-- Fair strike (M4.2 to M4.7): a warning for the target only, its acknowledgement, the result, the
-- client's readiness report and its liveness pulse. docs/mechanics/wildbound-fair-strike.md.
local attackWarning, attackResolved = remote("AttackWarning"), remote("AttackResolved")
local attackAck, readyRemote, pulseRemote = remote("AttackAck"), remote("ClientReady"), remote("FieldPulse")
local startedAt = workspace:GetServerTimeNow()
-- D5 (M5.7): the 12-minute cycle opens at one random point that is never Night, drawn once per server.
-- Timers that mean "since the world started" count from startedAt, not from the shifted origin.
local originTime = startedAt - Rules.startOffset(Random.new():NextNumber())
-- Damage never follows streaming. A missing or unreadable flag module means off, which is shadow mode
-- (M4.2). The attribute and payload only report the result; nothing reads them back to decide.
local flagsModule = script.Parent:FindFirstChild("WildboundFlags")
local flagsOk, flags = false, nil
if flagsModule and flagsModule:IsA("ModuleScript") then flagsOk, flags = pcall(require, flagsModule) end
local damageMode, flagMisconfigured = FairStrike.effectiveMode(flagsOk and flags or nil, game.PlaceId)
runtime:SetAttribute("DamageEnabled", damageMode == "private")
runtime:SetAttribute("NightRewardsEnabled", true)
runtime:SetAttribute("CycleStartedAt", originTime)

-- Server-only counters. ServerStorage never replicates, so no client can read or change them.
local telemetry = ServerStorage:FindFirstChild("WildboundTelemetry")
if not telemetry then
	telemetry = Instance.new("Folder")
	telemetry.Name, telemetry.Parent = "WildboundTelemetry", ServerStorage
end
local ledger = FairStrike.new()
if flagMisconfigured then FairStrike.count(ledger, "flagMisconfigured") end
local extra = { readyAccepted = 0, pulses = 0, acksAccepted = 0, serverPersistentLoaded = 0 }
local function publish()
	for key, value in pairs(ledger.counters) do telemetry:SetAttribute("FS_" .. key:gsub("%.", "_"), value) end
	for key, value in pairs(extra) do telemetry:SetAttribute("FSx_" .. key, value) end
	telemetry:SetAttribute("FS_identityHolds", FairStrike.identityHolds(ledger.counters))
	telemetry:SetAttribute("FS_damageMode", damageMode)
end
local MARKED_HEALTH = FairStrike.CONSTANTS.MARKED_HEALTH
local salt = HttpService:GenerateGUID(false):sub(1, 8)
-- min(StreamingMinRadius, 64). MT-5, measured 2026-11-07: a game script cannot read StreamingMinRadius
-- ("lacking capability PluginOrOpenCloud"), so it falls back to 64, the value Studio reads for this place.
-- Lowering the place's radius therefore needs this fallback lowered too.
local radiusOk, minRadius = pcall(function() return workspace.StreamingMinRadius end)
local dwellRadius = FairStrike.dwellRadius(radiusOk and minRadius or FairStrike.CONSTANTS.DWELL_MAX_RADIUS)

local guardian = Instance.new("Model")
guardian.Name = "Silueta"
local guardianGeneration = 1
local function primitive(name, size, position, color, transparency)
	local part = Instance.new("Part")
	part.Name, part.Size, part.Position = name, size, position
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
	part.Material, part.Color, part.Transparency = Enum.Material.SmoothPlastic, color, transparency
	part.Parent = guardian
	return part
end
local home = Vector3.new(Rules.HOME_X, 3.7, Rules.HOME_Z)
local body = primitive("Body", Vector3.new(2.8, 6.4, 2.2), home, Color3.fromRGB(70, 88, 87), 0.86)
local head = primitive("Head", Vector3.new(2, 2, 2), home + Vector3.new(0, 3.5, 0), Color3.fromRGB(92, 111, 107), 0.82)
head.Shape = Enum.PartType.Ball
local groundCue = primitive("GroundCue", Vector3.new(5.5, 0.12, 5.5), Vector3.new(home.X, 0.65, home.Z),
	Color3.fromRGB(177, 201, 180), 0.35)
groundCue.Shape = Enum.PartType.Cylinder
groundCue.Size = Vector3.new(0.12, 5.5, 5.5)
groundCue.CFrame = CFrame.new(home.X, 0.65, home.Z) * CFrame.Angles(0, 0, math.pi / 2)
local outline = Instance.new("Highlight")
outline.Name, outline.Adornee = "ReadableOutline", guardian
outline.FillTransparency, outline.OutlineTransparency = 1, 0.55
outline.OutlineColor, outline.DepthMode = Color3.fromRGB(178, 202, 190), Enum.HighlightDepthMode.Occluded
outline.Parent = guardian
-- Layer A (M4.2): the guardian should exist on every client and never stream out. Set before parenting.
guardian.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
guardian.PrimaryPart, guardian.Parent = body, runtime
guardian:SetAttribute("RevealedUntil", 0)
guardian:SetAttribute("TelegraphEndsAt", 0)
guardian:SetAttribute("State", "Retreat")
-- Publish the complete scene only after the remotes/model have been constructed.
runtime.Parent = map

-- Optional local art only. Missing module/template/IDs must not prevent the world from starting.
local visual
local visualModule = script.Parent:FindFirstChild("WildboundSiluetaVisual")
if visualModule and visualModule:IsA("ModuleScript") then
	local assets = ServerStorage:FindFirstChild("WildboundAssets")
	local ok, adapter = pcall(function()
		local profile = Rules.resolveCreatureProfile("Silueta", "Day", false)
		return require(visualModule).new({ guardian = guardian, body = body, head = head,
			template = assets and assets:FindFirstChild("SiluetaV3"), visualScale = profile.visualScale })
	end)
	if ok then visual = adapter else warn("Wildbound world: optional Silueta art unavailable.") end
end
if visual then visual:setState("Retreat") end

local records, connections = {}, {}
local stopped = false
-- A late-started world has an initial non-attacking grace before proximity acquisition.
local mode, target = "Retreat", nil
local targetLife, huntState = nil, nil
local alertEndsAt, telegraphEndsAt, recoveryEndsAt = 0, 0, startedAt + 3
local chaseStartedAt, lastAttackAt, revealedUntil = 0, -Rules.ATTACK_COOLDOWN, 0
local patrolIndex = 1
-- Per-player awareness (M2). Presentation only: nothing below ever reads it to gate a strike.
local awareness, awarenessResults, anySeen = Awareness.new(), {}, false
-- Ambush relocation (M4.7). The patrol diamond and the retreat point follow the current anchor.
local rng = Random.new()
local anchors = Ambush.anchors()
local center = home
-- The home diamond (tools/simulate_silueta_pressure.py reads it). Relocation keeps these offsets.
local patrol = {
	home + Vector3.new(16, 0, 0), home + Vector3.new(0, 0, 16),
	home + Vector3.new(-16, 0, 0), home + Vector3.new(0, 0, -16),
}
local patrolOffsets = {}
for index, point in ipairs(patrol) do patrolOffsets[index] = point - home end
local lastHuntAt, acquireBlockedUntil = -math.huge, 0
local ambushNextAt = startedAt + Ambush.nextDelay(Rules.cycle(startedAt - originTime).phase, rng:NextNumber())
local function setCenter(x, z)
	center = Vector3.new(x, home.Y, z)
	patrol = {}
	for _, offset in ipairs(patrolOffsets) do
		-- Clamped like every step, so a corner outside the leash can still be reached.
		local px, pz = Rules.clampTerritory(center.X + offset.X, center.Z + offset.Z)
		table.insert(patrol, Vector3.new(px, home.Y, pz))
	end
	patrolIndex = 1
end

local function characterContext(player)
	local record, character = records[player], player.Character
	if not record or record.character ~= character or not character or not character:IsDescendantOf(workspace) then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then return nil, nil, nil end
	local position = root.Position
	if not Rules.finite(position.X) or not Rules.finite(position.Y) or not Rules.finite(position.Z) then return nil, nil, nil end
	return character, humanoid, root
end

local function hasLumipol(player)
	-- Inventory implements this bounded, non-yielding callback from private registered state.
	if eligibility.Parent ~= network then return false end
	local ok, value = pcall(function() return eligibility:Invoke(player, "LumipolPulse") end)
	return ok and value == true
end

-- ignoreBodies: another player standing in the way does not hide the target from Silueta (M2.2).
local function visible(character, from, destination, ignoreBodies)
	local direction = destination - from
	if direction.Magnitude < 0.01 then return true end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = { character, runtime }
	if ignoreBodies then
		for _, other in ipairs(Players:GetPlayers()) do
			if other.Character and other.Character ~= character then table.insert(excluded, other.Character) end
		end
	end
	params.FilterDescendantsInstances = excluded
	params.IgnoreWater = true
	return workspace:Raycast(from, direction, params) == nil
end

local function targetContext(player, range, allowHidden)
	if not player then return nil end
	local character, humanoid, root = characterContext(player)
	if not root then return nil end
	local position, guardianPosition = root.Position, body.Position
	if not Rules.validTarget(true, position.X, position.Z, guardianPosition.X, guardianPosition.Z, range) then return nil end
	-- Do not acquire through cover or on a different floor; recheck these at strike time.
	if math.abs(position.Y - guardianPosition.Y) > 8 then return nil end
	local inSight = visible(character, guardianPosition, position, true)
	if not inSight and not allowHidden then return nil end
	return { player = player, character = character, humanoid = humanoid, root = root,
		distance = (position - guardianPosition).Magnitude, visible = inSight }
end

local function setMode(nextMode)
	mode = nextMode
	guardian:SetAttribute("State", mode)
	-- Present after the fixed step has latched movement, not with the previous sample.
	if visual then visual:setState(mode, mode == "Telegraph" and telegraphEndsAt or nil, true) end
end

local function playerByUserId(userId)
	for player in pairs(records) do
		if player.UserId == userId then return player end
	end
	return nil
end

-- Every attack ends with exactly one message to its target. "Missed" covers every cancel and never
-- names the gate.
local function tellResolved(attack, outcome, notice, dropped)
	local player = playerByUserId(attack.userId)
	if player and player.Parent == Players then
		attackResolved:FireClient(player, { attackId = attack.attackId, outcome = outcome, notice = notice or "",
			dropped = dropped })
	end
end

-- Closes an open attack before its impact: chase limit, lost target, stall, character change or leaving.
local function cancelOpenAttack(reason)
	local closed = FairStrike.cancelEarly(ledger, reason)
	if closed then
		tellResolved(closed, "Missed", "")
		publish()
	end
end

local function clearTarget(now, completedPresentation, reason)
	if visual then
		visual:finishTelegraph(completedPresentation == true)
		-- PlayerRemoving can clear the target between fixed gameplay steps.
		visual:setMoving(false)
	end
	-- A target that died or was replaced ends that life, so a late id from it reads as a prior life.
	if not reason then
		local lifeEnded = target ~= nil and (target.Character ~= targetLife or characterContext(target) == nil)
		reason = lifeEnded and "lifeChanged" or "chase"
	end
	cancelOpenAttack(reason)
	target, targetLife, huntState, telegraphEndsAt = nil, nil, nil, 0
	guardian:SetAttribute("TelegraphEndsAt", 0)
	recoveryEndsAt = now + 3
	setMode("Retreat")
end

local function moveToward(destination, speed, dt, checkObstacle)
	local position = body.Position
	local difference = Vector3.new(destination.X - position.X, 0, destination.Z - position.Z)
	if difference.Magnitude < 0.05 then return end
	local nextPosition = position + difference.Unit * math.min(difference.Magnitude, speed * dt)
	local x, z = Rules.clampTerritory(nextPosition.X, nextPosition.Z)
	nextPosition = Vector3.new(x, home.Y, z)
	if checkObstacle then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { runtime }
		params.IgnoreWater = true
		if workspace:Raycast(position, nextPosition - position, params) then return end
	end
	-- This greybox has a flat floor and non-colliding decorations; this is steering, not pathfinding.
	guardian:PivotTo(CFrame.lookAt(nextPosition, nextPosition + difference.Unit))
end

local function isMarked(player)
	local life = ledger.lives[player.UserId]
	local record = records[player]
	return life ~= nil and record ~= nil and life.life == record.character and life.marks > 0
end

local function snapshot(player, action, ok, notice, noticeShort)
	if stopped or not records[player] or player.Parent ~= Players then return end
	local now = workspace:GetServerTimeNow()
	local cycle = Rules.cycle(now - originTime)
	local _, _, root = characterContext(player)
	local isFog, isSafe = false, false
	local distance = -1
	if root then
		isFog, isSafe = Rules.zone(root.Position.X, root.Position.Z)
		distance = (root.Position - body.Position).Magnitude
	end
	local record = records[player]
	stateRemote:FireClient(player, {
		serverTime = now, cycleElapsed = cycle.elapsed, phase = cycle.phase,
		phaseRemaining = cycle.remaining, nextPhaseAt = now + cycle.remaining, clockTime = cycle.clockTime,
		isFog = isFog, isSafe = isSafe, alive = root ~= nil, hasLumipol = hasLumipol(player),
		flashlightReadyAt = record.cooldowns.Flashlight or 0, pulseReadyAt = record.cooldowns.LumipolPulse or 0,
		-- The attack deadline travels only inside this player's awareness, never to everyone (M2.2).
		guardian = { state = mode, distance = distance, threat = Rules.isThreat(mode, root ~= nil, isFog, isSafe, distance),
			revealedUntil = revealedUntil, awareness = Awareness.toSnapshot(awarenessResults[player.UserId]) },
		nightRewardsEnabled = true, damageEnabled = damageMode == "private", marked = isMarked(player),
		action = action or "WorldTick", ok = ok ~= false, notice = notice or "",
		noticeShort = noticeShort or notice or "",
	})
end

-- The only path to harm. Shadow mode returns before touching any Humanoid (M4.2, FS-03). D6: the first
-- strike marks and drops one bag item through the inventory script; the second defeats.
local function applyRealStrike(context, effect, attack)
	if damageMode ~= "private" then return false end
	local humanoid = context.humanoid
	if effect == "Defeated" then
		humanoid:TakeDamage(humanoid.Health)
		-- A ForceField or another script can keep the player alive; that is counted, never retried.
		if humanoid.Health > 0 then FairStrike.count(ledger, "effect.failed") end
		return true, nil
	end
	humanoid.Health = math.min(humanoid.Health, MARKED_HEALTH)
	local effectFunction = network:FindFirstChild("StrikeEffect")
	local ok, dropped = false, nil
	if effectFunction and effectFunction:IsA("BindableFunction") then
		local toward = body.Position
		ok, dropped = pcall(function() return effectFunction:Invoke(context.player, attack.attackId, toward.X, toward.Z) end)
	end
	-- Failure keeps the mark and skips the drop.
	if not ok then FairStrike.count(ledger, "effect.failed") end
	return true, ok and type(dropped) == "table" and dropped or nil
end

local function strikeNotice(effect, dropped)
	if effect == "Defeated" then return "Silueta defeated you." end
	local lead = "Silueta marked you! Next hit defeats you. "
	if dropped then
		local name = dropped.kind == "Egg" and "Lumipol egg" or "Lumipol"
		lead ..= ("Dropped: %s. Grab it within 30 s. "):format(name)
	end
	return lead .. "Rest at camp or shelter to clear the mark."
end

-- Telegraph entry: one attack for the current target and life, warned in the same step.
local function issueAttack(now)
	local attack = FairStrike.issue(ledger, { userId = target.UserId, life = targetLife,
		guardianGeneration = guardianGeneration, now = now, endsAt = telegraphEndsAt, salt = salt,
		dwellOk = FairStrike.dwellOk(ledger, target.UserId, targetLife, now) })
	attackWarning:FireClient(target, { attackId = attack.attackId, issuedAt = now, endsAt = telegraphEndsAt })
	FairStrike.warned(ledger, attack.attackId, now)
	-- Diagnostic for MT-6 and the dwell gate: seconds near at issue, or -1 for not near or another life.
	local life = ledger.lives[target.UserId]
	telemetry:SetAttribute("FSx_lastDwellSeconds", life and life.life == targetLife and life.nearSince
		and now - life.nearSince or -1)
	publish()
end

local function guardianOk(attack)
	return attack.guardianGeneration == guardianGeneration and guardian.Parent == runtime and runtime.Parent == map
		and guardian.ModelStreamingMode == Enum.ModelStreamingMode.Persistent
end

-- Impact: the gates decide in the document's order, then the staged effect applies in private mode only.
local function resolveImpact(now)
	local attack = ledger.attack
	local character = characterContext(target)
	local binding = attack ~= nil and character ~= nil and character == attack.life and character == targetLife
	local latest = binding and targetContext(target, Rules.ATTACK_RANGE) or nil
	local geometry = latest ~= nil and Rules.canStrike(now, telegraphEndsAt, lastAttackAt, latest.distance, true, false, true)
	if attack then
		local out = FairStrike.resolve(ledger, attack,
			{ guardian = guardianOk(attack), binding = binding, geometry = geometry }, now, damageMode)
		local outcome, notice, dropped = "Missed", "", nil
		if out.outcome == "strike" and latest then
			local applied, item = applyRealStrike(latest, out.effect, attack)
			if applied then outcome, dropped = out.effect, item; notice = strikeNotice(out.effect, item) end
		end
		-- A strike that passed every gate ends that player's capture whether or not damage is on (M3.3).
		if (out.outcome == "strike" or out.outcome == "shadow") and latest and strikeEvent then strikeEvent:Fire(latest.player) end
		tellResolved(attack, outcome, notice, dropped)
		publish()
	end
	return geometry
end

-- M4.6 regeneration rule: a marked player is pinned at MARKED_HEALTH until five seconds of rest.
local function stepMarks(now)
	for player in pairs(records) do
		local character, humanoid, root = characterContext(player)
		if root then
			local _, safe = Rules.zone(root.Position.X, root.Position.Z)
			local rest = FairStrike.restStep(ledger, player.UserId, character, safe, now)
			if rest == "pin" and humanoid.Health > MARKED_HEALTH then
				humanoid.Health = MARKED_HEALTH
			elseif rest == "cleared" then
				humanoid.Health = humanoid.MaxHealth
				snapshot(player, "Rest", true, "You rested. The mark is gone.", "Mark cleared.")
			end
		end
	end
end

-- Dwell (layer B): server-measured time inside min(StreamingMinRadius, 64) of the guardian, per life.
local function stepDwell(now)
	for player in pairs(records) do
		local character, _, root = characterContext(player)
		local inside = root ~= nil and dwellRadius ~= nil and (root.Position - body.Position).Magnitude <= dwellRadius
		FairStrike.dwellStep(ledger, player.UserId, character, inside, now)
	end
end

-- Ambush (M4.7): positions and timers only. Nothing here reads a camera, a look direction or sight.
local function tryAmbush(now, phase)
	if now < ambushNextAt then return end
	local positions, anyFog = {}, false
	for player in pairs(records) do
		local _, _, root = characterContext(player)
		if root then
			table.insert(positions, { x = root.Position.X, z = root.Position.Z, totem = totemHolders[player] == true })
			if Rules.zone(root.Position.X, root.Position.Z) then anyFog = true end
		end
	end
	local out = Ambush.pick({ now = now, nextAt = ambushNextAt, mode = mode, roll = rng:NextNumber(),
		players = positions, anchors = anchors, guardianX = body.Position.X, guardianZ = body.Position.Z,
		lastHuntAt = lastHuntAt, anyPlayerInFog = anyFog })
	if out.move then
		guardian:PivotTo(CFrame.new(out.x, home.Y, out.z))
		setCenter(out.x, out.z)
		acquireBlockedUntil = now + 3
		FairStrike.clearDwell(ledger)
		FairStrike.count(ledger, "ambush.moved")
		guardian:SetAttribute("Anchor", out.anchorId)
		ambushNextAt = now + Ambush.nextDelay(phase, rng:NextNumber())
	else
		FairStrike.count(ledger, "ambush.skipped")
		telemetry:SetAttribute("FSx_lastAmbushSkip", out.reason)
		ambushNextAt = now + Ambush.CONSTANTS.RETRY_SECONDS
	end
	publish()
end

local function step(now, dt)
	local cycle = Rules.cycle(now - originTime)
	local parameters = Rules.guardianParameters(cycle.phase, true)
	if mode == "Patrol" then
		local nearest, nearestDistance, nearestLife
		if now >= acquireBlockedUntil then
			for player in pairs(records) do
				local candidate = targetContext(player, detectionFor(player, parameters.detectionRange))
				if candidate and (not nearestDistance or candidate.distance < nearestDistance) then
					nearest, nearestDistance, nearestLife = player, candidate.distance, candidate.character
				end
			end
		end
		if nearest then
			target, targetLife, alertEndsAt, chaseStartedAt = nearest, nearestLife, now + 1.2, now
			setMode("Alert")
		else
			if (body.Position - patrol[patrolIndex]).Magnitude < 1 then patrolIndex = patrolIndex % #patrol + 1 end
			moveToward(patrol[patrolIndex], 3, dt)
			tryAmbush(now, cycle.phase)
		end
	elseif mode == "Retreat" then
		moveToward(center, 6, dt)
		if now >= recoveryEndsAt and (body.Position - center).Magnitude < 1 then setMode("Patrol") end
	else
		local candidate = targetContext(target, Rules.CHASE_RANGE, mode == "Hunt")
		if not candidate or candidate.character ~= targetLife or now - chaseStartedAt >= Rules.MAX_CHASE_SECONDS then
			clearTarget(now)
		elseif mode == "Alert" then
			if now >= alertEndsAt then
				huntState = Hunt.new({ id = target.UserId, life = targetLife, position = candidate.root.Position }, now)
				setMode("Hunt")
			end
		elseif mode == "Hunt" then
			local current = { id = target.UserId, life = targetLife, valid = true, visible = candidate.visible }
			if candidate.visible then current.position, current.distance = candidate.root.Position, candidate.distance end
			local candidates, playersById = {}, {}
			if candidate.visible and Hunt.shouldScan(huntState, now) then
				for player in pairs(records) do
					if player ~= target then
						local other = targetContext(player, detectionFor(player, parameters.detectionRange))
						if other then
							table.insert(candidates, { id = player.UserId, life = other.character, valid = true,
								visible = true, distance = other.distance, position = other.root.Position })
							playersById[player.UserId] = player
						end
					end
				end
			end
			local decision = Hunt.step(huntState, now, current, candidates)
			if decision.expired then
				clearTarget(now)
			else
				if decision.switched then
					target, targetLife = playersById[decision.id], decision.life
					candidate = targetContext(target, Rules.CHASE_RANGE)
				end
				if decision.canAttack and candidate and candidate.character == targetLife
					and candidate.distance <= Rules.ATTACK_RANGE and now - lastAttackAt >= Rules.ATTACK_COOLDOWN then
					telegraphEndsAt = now + Rules.TELEGRAPH_SECONDS
					guardian:SetAttribute("TelegraphEndsAt", telegraphEndsAt)
					setMode("Telegraph")
					issueAttack(now)
				elseif decision.destination then
					moveToward(decision.destination, parameters.speed, dt, not decision.canAttack)
				end
			end
		elseif mode == "Telegraph" and now >= telegraphEndsAt then
			-- Never lunge/teleport into a hit. Stationary wind-up; the gates validate the current character again.
			local completedPresentation = resolveImpact(now)
			lastAttackAt = now
			clearTarget(now, completedPresentation)
		end
	end
	if mode == "Alert" or mode == "Hunt" or mode == "Telegraph" then lastHuntAt = now end
	local revealed = now < revealedUntil
	if visual then visual:setRevealed(revealed) else
		body.Transparency, head.Transparency = revealed and 0.3 or 0.86, revealed and 0.25 or 0.82
	end
	outline.OutlineTransparency = revealed and 0.05 or 0.55
end

-- Runs once per fixed step, right after the guardian step, with the same clock. Pushes a snapshot to
-- every player whose awareness changed, so a warning never waits for the 1 Hz tick.
local discSeen
local function stepAwareness(now)
	local context = target and targetContext(target, Rules.CHASE_RANGE, true)
	local entries = {}
	for player in pairs(records) do
		local character, _, root = characterContext(player)
		local safe, distance = false, nil
		if root then
			local _, isSafe = Rules.zone(root.Position.X, root.Position.Z)
			safe, distance = isSafe, (root.Position - body.Position).Magnitude
		end
		table.insert(entries, { id = player.UserId, life = character, alive = root ~= nil,
			distance = distance, safe = safe })
	end
	awarenessResults = Awareness.step(awareness, { now = now, mode = mode,
		targetId = target and target.UserId, targetLife = targetLife,
		targetVisible = context ~= nil and context.visible,
		lastVisibleAt = huntState and huntState.lastVisibleAt,
		telegraphEndsAt = telegraphEndsAt, players = entries })
	anySeen = false
	for player in pairs(records) do
		local result = awarenessResults[player.UserId]
		if result then
			if result.state == "seen" then anySeen = true end
			if result.changed then snapshot(player) end
		end
	end
	if anySeen ~= discSeen then
		discSeen = anySeen
		local cue = Rules.groundCue(anySeen)
		groundCue.Color = Color3.fromRGB(cue.r, cue.g, cue.b)
		groundCue.Transparency = cue.transparency
		groundCue.Size = Vector3.new(0.12, cue.diameter, cue.diameter)
	end
end

local notices = {
	InvalidContext = "Use abilities while alive in your current character.",
	NotEquipped = "Extract and equip a registered Lumipol first. The flashlight is always free.",
	Cooldown = "Ability is cooling down.", Miss = "No Silueta revealed. Move within 55 studs; face it for flashlight.",
	Revealed = "Silueta revealed for 4 seconds. Keep moving; it is not defeated.",
}
-- Short forms for small screens, so the line is collapsed instead of shrunk or clipped.
local noticesShort = {
	InvalidContext = "Not available right now.", NotEquipped = "Equip a Lumipol first.",
	Cooldown = "Cooling down.", Miss = "Missed. Move closer, face it.", Revealed = "Revealed 4 s. Keep moving.",
}
table.insert(connections, actionRemote.OnServerEvent:Connect(function(player, action, ...)
	if stopped or select("#", ...) ~= 0 or type(action) ~= "string" then return end
	if action ~= "RequestSnapshot" and action ~= "Flashlight" and action ~= "LumipolPulse" then return end
	local record = records[player]
	if not record then return end
	local now = workspace:GetServerTimeNow()
	-- Bounded known keys only. Spam is dropped, never reflected with an unbounded reply.
	if now - record.lastRequest < 0.3 or now - (record.rates[action] or -math.huge) < 1 then return end
	record.lastRequest, record.rates[action] = now, now
	if action == "RequestSnapshot" then
		snapshot(player, action, true, "Connected to the shared world clock.")
		return
	end
	local eligible = action == "LumipolPulse" and hasLumipol(player)
	-- Read current-character context after the trusted inventory callback, never before it.
	if stopped or records[player] ~= record then return end
	local character, _, root = characterContext(player)
	local difference = root and (body.Position - root.Position) or Vector3.zero
	local distance = root and difference.Magnitude or math.huge
	local facing = root ~= nil and (distance < 0.01 or root.CFrame.LookVector:Dot(difference.Unit) >= 0.2)
	local context = { alive = root ~= nil, eligible = eligible,
		distance = distance, facing = facing,
		visible = root ~= nil and distance <= Rules.REVEAL_RANGE and visible(character, root.Position, body.Position) }
	local ok, reason, hit = Rules.tryAbility(record.cooldowns, action, now, context)
	if hit then
		-- Concurrent reveals overlap; they never add seconds to an existing expiry.
		revealedUntil = math.max(revealedUntil, now + Rules.REVEAL_SECONDS)
		guardian:SetAttribute("RevealedUntil", revealedUntil)
	end
	snapshot(player, action, ok, notices[reason] or "Ability not available.", noticesShort[reason] or "Not available.")
end))

-- AttackAck(attackId): at most 4 per second per player; excess is dropped silently, with no reply.
table.insert(connections, attackAck.OnServerEvent:Connect(function(player, attackId, ...)
	local record = records[player]
	if stopped or not record then return end
	local now = workspace:GetServerTimeNow()
	if not FairStrike.allow(record.ackBucket, now, 4, 1) then return end
	local outcome = FairStrike.acknowledge(ledger, player.UserId, record.character, attackId, select("#", ...), now)
	if outcome == "accepted" then extra.acksAccepted += 1 end
	publish()
end))
-- ClientReady(persistentLoaded, assetsLoaded): typed, once per 2 s, only false to true within a life.
table.insert(connections, readyRemote.OnServerEvent:Connect(function(player, persistentLoaded, assetsLoaded, ...)
	local record = records[player]
	if stopped or not record or select("#", ...) ~= 0 then return end
	if type(persistentLoaded) ~= "boolean" or type(assetsLoaded) ~= "boolean" then return end
	if not FairStrike.allow(record.readyBucket, workspace:GetServerTimeNow(), 1, 2) then return end
	local character = characterContext(player)
	if not character then return end
	if FairStrike.ready(ledger, player.UserId, character, persistentLoaded, assetsLoaded) then
		extra.readyAccepted += 1
	end
	telemetry:SetAttribute("FSx_lastReadyReport", ("%s,%s"):format(tostring(persistentLoaded), tostring(assetsLoaded)))
	publish()
end))
-- FieldPulse(): liveness only, at most 2 per second. It proves nothing else.
table.insert(connections, pulseRemote.OnServerEvent:Connect(function(player, ...)
	local record = records[player]
	if stopped or not record or select("#", ...) ~= 0 then return end
	local now = workspace:GetServerTimeNow()
	if not FairStrike.allow(record.pulseBucket, now, 2, 1) then return end
	local character = characterContext(player)
	if character then
		FairStrike.pulse(ledger, player.UserId, character, now)
		extra.pulses += 1
	end
end))
-- MT-2: does Workspace.PersistentLoaded fire on the server? Counted only, never used to decide.
pcall(function()
	table.insert(connections, workspace.PersistentLoaded:Connect(function()
		extra.serverPersistentLoaded += 1
	end))
end)
-- A replaced or removed guardian closes its attack; its old ids then classify as forged (FS-15).
table.insert(connections, guardian.AncestryChanged:Connect(function()
	if guardian.Parent ~= runtime then
		guardianGeneration += 1
		cancelOpenAttack("guardian")
	end
end))

local function addPlayer(player)
	if stopped or records[player] then return end
	local record = { cooldowns = {}, rates = {}, lastRequest = -math.huge, character = player.Character,
		ackBucket = {}, readyBucket = {}, pulseBucket = {} }
	records[player] = record
	record.characterConnection = player.CharacterAdded:Connect(function(character)
		if records[player] == record then
			record.character = character
			-- An attack on the previous character closes now; its id then reads as a prior life.
			if ledger.attack and ledger.attack.userId == player.UserId then cancelOpenAttack("lifeChanged") end
		end
	end)
	-- Cooldowns survive respawn in this server; there is no death/reset cooldown bypass.
	record.removingConnection = player.CharacterRemoving:Connect(function(character)
		if records[player] == record and record.character == character then record.character = nil end
	end)
end
table.insert(connections, Players.PlayerAdded:Connect(addPlayer))
table.insert(connections, Players.PlayerRemoving:Connect(function(player)
	local record = records[player]
	if not record then return end
	record.characterConnection:Disconnect()
	record.removingConnection:Disconnect()
	records[player] = nil
	-- Disconnect is not a defeat (D10). No hold record exists yet, so the mark and K go with the player.
	if ledger.attack and ledger.attack.userId == player.UserId then cancelOpenAttack("disconnect") end
	FairStrike.forgetPlayer(ledger, player.UserId)
	if target == player then clearTarget(workspace:GetServerTimeNow(), nil, "disconnect") end
end))
for _, player in ipairs(Players:GetPlayers()) do addPlayer(player) end
publish()

local accumulator, snapshotAccumulator = 0, 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
	if stopped or not Rules.finite(dt) or dt < 0 then return end
	accumulator += math.min(dt, 0.2)
	snapshotAccumulator += math.min(dt, 1)
	if accumulator >= 0.2 then
		local now = workspace:GetServerTimeNow()
		-- A long stall cancels wind-ups instead of inflicting catch-up damage without readable cues.
		if dt > 0.5 and (mode == "Telegraph" or mode == "Hunt" or mode == "Alert") then clearTarget(now, nil, "stall") end
		FairStrike.noteStep(ledger, now)
		stepDwell(now)
		local before = visual and body.Position
		step(now, 0.2)
		if visual then
			local after = body.Position
			-- Measure horizontal displacement, not rotation or intent; retain until the next fixed step.
			visual:setMoving(after.X ~= before.X or after.Z ~= before.Z)
		end
		stepAwareness(now)
		if damageMode == "private" then stepMarks(now) end
		accumulator = 0
	end
	-- Higher-frequency art scheduling does not change the existing 0.2-second gameplay step.
	if visual then visual:step() end
	if snapshotAccumulator >= 1 then
		snapshotAccumulator = 0
		for player in pairs(records) do snapshot(player) end
		publish()
	end
end))

local function cleanup()
	if stopped then return end
	stopped = true
	for _, connection in ipairs(connections) do connection:Disconnect() end
	for player, record in pairs(records) do
		record.characterConnection:Disconnect()
		record.removingConnection:Disconnect()
		records[player] = nil
	end
	-- Destroy only the objects owned by this script, never the map/inventory root.
	if visual then visual:destroy() end
	for _, owned in ipairs({ actionRemote, stateRemote, attackWarning, attackResolved, attackAck, readyRemote, pulseRemote }) do
		if owned.Parent == network then owned:Destroy() end
	end
	if runtime.Parent == map then runtime:Destroy() end
end
table.insert(connections, script.Destroying:Connect(cleanup))
table.insert(connections, runtime.AncestryChanged:Connect(function()
	if runtime.Parent ~= map or not map:IsDescendantOf(workspace) then cleanup() end
end))
table.insert(connections, network.AncestryChanged:Connect(function()
	if network.Parent ~= ReplicatedStorage then cleanup() end
end))

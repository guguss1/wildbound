-- Local-source P0 world adapter. Deploy beside WildboundWorldRules after authorized testing resumes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Rules = require(script.Parent:WaitForChild("WildboundWorldRules"))
local Hunt = require(script.Parent:WaitForChild("WildboundSiluetaHunt"))
local Awareness = require(script.Parent:WaitForChild("WildboundSiluetaAwareness"))
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
-- A second copy must never overwrite an existing world, remote or another script's objects.
if map:FindFirstChild("WildboundWorldRuntime") or network:FindFirstChild("WorldAction")
	or network:FindFirstChild("WorldState") then
	warn("Wildbound world: duplicate startup refused.")
	return
end
local runtime = Instance.new("Folder")
runtime.Name = "WildboundWorldRuntime"
local actionRemote, stateRemote = Instance.new("RemoteEvent"), Instance.new("RemoteEvent")
actionRemote.Name, stateRemote.Name = "WorldAction", "WorldState"
actionRemote.Parent, stateRemote.Parent = network, network
local originTime = workspace:GetServerTimeNow()
-- No trustworthy client-loaded receipt exists yet. Do not damage unseen streaming targets.
local damageEnabled = not workspace.StreamingEnabled
runtime:SetAttribute("DamageEnabled", damageEnabled)
runtime:SetAttribute("NightRewardsEnabled", false)
runtime:SetAttribute("CycleStartedAt", originTime)

local guardian = Instance.new("Model")
guardian.Name = "Silueta"
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
local alertEndsAt, telegraphEndsAt, recoveryEndsAt = 0, 0, originTime + 3
local chaseStartedAt, lastAttackAt, revealedUntil = 0, -Rules.ATTACK_COOLDOWN, 0
local patrolIndex = 1
-- Per-player awareness (M2). Presentation only: nothing below ever reads it to gate a strike.
local awareness, awarenessResults, anySeen = Awareness.new(), {}, false
local patrol = {
	home + Vector3.new(16, 0, 0), home + Vector3.new(0, 0, 16),
	home + Vector3.new(-16, 0, 0), home + Vector3.new(0, 0, -16),
}

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

local function clearTarget(now, completedPresentation)
	if visual then
		visual:finishTelegraph(completedPresentation == true)
		-- PlayerRemoving can clear the target between fixed gameplay steps.
		visual:setMoving(false)
	end
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
		nightRewardsEnabled = false, damageEnabled = damageEnabled,
		action = action or "WorldTick", ok = ok ~= false, notice = notice or "",
		noticeShort = noticeShort or notice or "",
	})
end

local function step(now, dt)
	local cycle = Rules.cycle(now - originTime)
	local parameters = Rules.guardianParameters(cycle.phase, true)
	if mode == "Patrol" then
		local nearest, nearestDistance, nearestLife
		for player in pairs(records) do
			local candidate = targetContext(player, parameters.detectionRange)
			if candidate and (not nearestDistance or candidate.distance < nearestDistance) then
				nearest, nearestDistance, nearestLife = player, candidate.distance, candidate.character
			end
		end
		if nearest then
			target, targetLife, alertEndsAt, chaseStartedAt = nearest, nearestLife, now + 1.2, now
			setMode("Alert")
		else
			if (body.Position - patrol[patrolIndex]).Magnitude < 1 then patrolIndex = patrolIndex % #patrol + 1 end
			moveToward(patrol[patrolIndex], 3, dt)
		end
	elseif mode == "Retreat" then
		moveToward(home, 6, dt)
		if now >= recoveryEndsAt and (body.Position - home).Magnitude < 1 then setMode("Patrol") end
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
						local other = targetContext(player, parameters.detectionRange)
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
				elseif decision.destination then
					moveToward(decision.destination, parameters.speed, dt, not decision.canAttack)
				end
			end
		elseif mode == "Telegraph" and now >= telegraphEndsAt then
			-- Never lunge/teleport into a hit. Stationary wind-up; validate the current character again.
			local latest = targetContext(target, Rules.ATTACK_RANGE)
			if latest and latest.character ~= targetLife then latest = nil end
			-- Presentation may finish a validated warning even while streaming safety blocks damage.
			local completedPresentation = latest and Rules.canStrike(now, telegraphEndsAt, lastAttackAt,
				latest.distance, true, false, true)
			if latest and damageEnabled and Rules.canStrike(now, telegraphEndsAt, lastAttackAt,
				latest.distance, true, false, true) then
				latest.humanoid:TakeDamage(Rules.DAMAGE)
			end
			-- A resolved strike ends that player's capture whether or not damage is on (M3.3).
			if completedPresentation and strikeEvent then strikeEvent:Fire(latest.player) end
			lastAttackAt = now
			clearTarget(now, completedPresentation)
		end
	end
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

local function addPlayer(player)
	if stopped or records[player] then return end
	local record = { cooldowns = {}, rates = {}, lastRequest = -math.huge, character = player.Character }
	records[player] = record
	record.characterConnection = player.CharacterAdded:Connect(function(character)
		if records[player] == record then record.character = character end
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
	if target == player then clearTarget(workspace:GetServerTimeNow()) end
end))
for _, player in ipairs(Players:GetPlayers()) do addPlayer(player) end

local accumulator, snapshotAccumulator = 0, 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
	if stopped or not Rules.finite(dt) or dt < 0 then return end
	accumulator += math.min(dt, 0.2)
	snapshotAccumulator += math.min(dt, 1)
	if accumulator >= 0.2 then
		local now = workspace:GetServerTimeNow()
		-- A long stall cancels wind-ups instead of inflicting catch-up damage without readable cues.
		if dt > 0.5 and (mode == "Telegraph" or mode == "Hunt" or mode == "Alert") then clearTarget(now) end
		local before = visual and body.Position
		step(now, 0.2)
		if visual then
			local after = body.Position
			-- Measure horizontal displacement, not rotation or intent; retain until the next fixed step.
			visual:setMoving(after.X ~= before.X or after.Z ~= before.Z)
		end
		stepAwareness(now)
		accumulator = 0
	end
	-- Higher-frequency art scheduling does not change the existing 0.2-second gameplay step.
	if visual then visual:step() end
	if snapshotAccumulator >= 1 then
		snapshotAccumulator = 0
		for player in pairs(records) do snapshot(player) end
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
	if actionRemote.Parent == network then actionRemote:Destroy() end
	if stateRemote.Parent == network then stateRemote:Destroy() end
	if runtime.Parent == map then runtime:Destroy() end
end
table.insert(connections, script.Destroying:Connect(cleanup))
table.insert(connections, runtime.AncestryChanged:Connect(function()
	if runtime.Parent ~= map or not map:IsDescendantOf(workspace) then cleanup() end
end))
table.insert(connections, network.AncestryChanged:Connect(function()
	if network.Parent ~= ReplicatedStorage then cleanup() end
end))

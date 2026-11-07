-- Local-source P0 world adapter. Deploy beside WildboundWorldRules after authorized testing resumes.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Rules = require(script.Parent:WaitForChild("WildboundWorldRules"))
local Hunt = require(script.Parent:WaitForChild("WildboundSiluetaHunt"))
local Awareness = require(script.Parent:WaitForChild("WildboundSiluetaAwareness"))
local FairStrike = require(script.Parent:WaitForChild("WildboundFairStrike"))
local Ambush = require(script.Parent:WaitForChild("WildboundAmbush"))
-- Delivery C: the non-combat brain (suspicion, capture noise, search, day and night profiles) and route following
-- around the solid trunk cores. docs/mechanics/wildbound-guardian.md.
local Brain = require(script.Parent:WaitForChild("WildboundGuardianBrain"))
local GuardianPath = require(script.Parent:WaitForChild("WildboundGuardianPath"))
-- Delivery D6 and D8: hiding spots and the per-player threat level the client plays audio from.
local Hide = require(script.Parent:WaitForChild("WildboundHide"))
local Threat = require(script.Parent:WaitForChild("WildboundThreatLevel"))
local Keys = require(script.Parent:WaitForChild("WildboundPromptKeys"))
-- Cleanup cannot run inside this script once it is destroyed (its connections die with it), so what it owns is
-- tagged here and WildboundWorldGuard sweeps by tag. docs/ui/wildbound-start-and-settings.md, A3.
local Ownership = require(script.Parent:WaitForChild("WildboundOwnership"))
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
-- D-C5: Spanish strike, dodge and rest words. Missing means the English fallbacks in FairStrike.
local strikeWords
local hideWords = {}
do
	local textModule = ReplicatedStorage:FindFirstChild("WildboundText")
	if textModule and textModule:IsA("ModuleScript") then
		local ok, value = pcall(require, textModule)
		if ok and type(value) == "table" and type(value.STRIKE) == "table" then strikeWords = value.STRIKE end
		if ok and type(value) == "table" and type(value.HIDE) == "table" then hideWords = value.HIDE end
	end
end
-- M5.6 bond: a pulse that revealed Silueta to a player in the fog is reported on a server-only event.
local pulseHit = network:FindFirstChild("PulseHit")
if pulseHit and not pulseHit:IsA("BindableEvent") then pulseHit = nil end
-- Delivery C1: capture noise from the inventory script (ring and seal, with the slot tier). Missing means silence.
local noiseEvent = network:FindFirstChild("GuardianNoise")
if noiseEvent and not noiseEvent:IsA("BindableEvent") then noiseEvent = nil end
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
Ownership.claim(CollectionService, runtime)
local function remote(name)
	local value = Instance.new("RemoteEvent")
	value.Name, value.Parent = name, network
	Ownership.claim(CollectionService, value)
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
-- Delivery D13: a Studio-only, server-only clock shift for Play checks of dusk and night: a NumberValue a tester puts
-- in ServerStorage.WildboundTelemetry (no client can reach it). Outside Studio it is 0.
local function cycleAt(now)
	local holder = RunService:IsStudio() and telemetry:FindFirstChild("StudioClockShift")
	local shift = holder and holder:IsA("NumberValue") and holder.Value or 0
	if shift ~= shift or math.abs(shift) > 1e6 then shift = 0 end
	return Rules.cycle(now - originTime + shift)
end
local ledger = FairStrike.new()
if flagMisconfigured then FairStrike.count(ledger, "flagMisconfigured") end
local extra = { readyAccepted = 0, pulses = 0, acksAccepted = 0, serverPersistentLoaded = 0, noises = 0, noisesHeard = 0,
	spared = 0 }
-- Delivery C2: route planning around the trunk cores, measured on the real map (docs/mechanics/wildbound-guardian.md).
local nav = GuardianPath.new()
local navStats = { lastPlanMs = 0, maxPlanMs = 0, directSteps = 0, blockedSteps = 0, slideSteps = 0 }
local function publish()
	for key, value in pairs(ledger.counters) do telemetry:SetAttribute("FS_" .. key:gsub("%.", "_"), value) end
	for key, value in pairs(extra) do telemetry:SetAttribute("FSx_" .. key, value) end
	for key, value in pairs(nav.counters) do telemetry:SetAttribute("Nav_" .. key, value) end
	for key, value in pairs(navStats) do telemetry:SetAttribute("Nav_" .. key, value) end
	telemetry:SetAttribute("FS_identityHolds", FairStrike.identityHolds(ledger.counters))
	telemetry:SetAttribute("FS_damageMode", damageMode)
end
local MARKED_HEALTH = FairStrike.CONSTANTS.MARKED_HEALTH
local salt = HttpService:GenerateGUID(false):sub(1, 8)
-- min(StreamingMinRadius, 64). MT-5, measured 2026-11-07: a game script cannot read StreamingMinRadius
-- ("lacking capability PluginOrOpenCloud"). D-C4: the radius is configured in WildboundFlags and a Studio contract
-- compares it with the place's value. A missing or impossible value fails the dwell gate closed.
local dwellRadius = FairStrike.dwellRadius(flagsOk and type(flags) == "table" and flags.streamingMinRadius or nil)

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
local brain = Brain.new(startedAt)
local COMBAT = { Alert = true, Hunt = true, Telegraph = true }
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

-- D-C3: whether this player has made a paid trip home yet. The inventory script reports progress counts only;
-- FairStrike.lethal decides. Any failure reads as not yet lethal, so the gate fails toward sparing.
local function isLethal(player)
	if not player or eligibility.Parent ~= network then return false end
	local ok, progress = pcall(function() return eligibility:Invoke(player, "Progress") end)
	return ok and FairStrike.lethal(progress)
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
	-- Delivery D6: a hidden player is never in sight, so never acquired, and hunts and strikes read them as lost.
	local hidden = records[player] ~= nil and records[player].hide ~= nil
	local inSight = not hidden and visible(character, guardianPosition, position, true)
	if not inSight and not allowHidden then return nil end
	return { player = player, character = character, humanoid = humanoid, root = root,
		distance = (position - guardianPosition).Magnitude, visible = inSight }
end

local function setMode(nextMode)
	mode = nextMode
	if brain.mode ~= nextMode then Brain.set(brain, nextMode, workspace:GetServerTimeNow()) end
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
local function tellResolved(attack, outcome, notice, dropped, noticeShort)
	local player = playerByUserId(attack.userId)
	if player and player.Parent == Players then
		attackResolved:FireClient(player, { attackId = attack.attackId, outcome = outcome, notice = notice or "",
			noticeShort = noticeShort or notice or "", dropped = dropped })
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
	GuardianPath.clear(nav)
	target, targetLife, huntState, telegraphEndsAt = nil, nil, nil, 0
	guardian:SetAttribute("TelegraphEndsAt", 0)
	recoveryEndsAt = now + 3
	setMode("Retreat")
end

-- Every step refuses to walk into geometry: a sphere about the body's half-width is cast along the step, ignoring the
-- guardian, every character and anything that does not collide. Since D-C1 the trunk cores are solid, so this never
-- slides through a tree. Measured in delivery C2: PathfindingService's coarse navmesh can route a little closer to a
-- core than the body allows, so a blocked step tries to slide past at up to 70 degrees before it gives up.
local SLIDE_ANGLES = { 0, math.rad(35), -math.rad(35), math.rad(70), -math.rad(70) }
local function stepToward(destination, speed, dt)
	local position = body.Position
	local difference = Vector3.new(destination.X - position.X, 0, destination.Z - position.Z)
	if difference.Magnitude < 0.05 then return false end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = { runtime }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then table.insert(excluded, player.Character) end
	end
	params.FilterDescendantsInstances = excluded
	params.IgnoreWater = true
	-- Only what collides blocks a step, like the PathfindingService routes: the visible trunk meshes are sight-only
	-- and flare wider than the cores at body height.
	params.RespectCanCollide = true
	local length = math.min(difference.Magnitude, speed * dt)
	for index, angle in ipairs(SLIDE_ANGLES) do
		local direction = CFrame.Angles(0, angle, 0):VectorToWorldSpace(difference.Unit)
		local nextPosition = position + direction * length
		local x, z = Rules.clampTerritory(nextPosition.X, nextPosition.Z)
		nextPosition = Vector3.new(x, home.Y, z)
		local move = nextPosition - position
		if move.Magnitude > 0.01 and not workspace:Spherecast(position, 1, move, params) then
			if index > 1 then navStats.slideSteps += 1 end
			-- Speed times the fixed step bounds every move: there is no teleport and no lunge.
			guardian:PivotTo(CFrame.lookAt(nextPosition, nextPosition + direction))
			return true
		end
	end
	navStats.blockedSteps += 1
	return false
end

local function flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Asks PathfindingService for a route without blocking the gameplay step. Only the latest request is followed.
local function requestPlan(goal, now)
	local serial = GuardianPath.begin(nav, goal.X, goal.Z, now)
	local from = Vector3.new(body.Position.X, 3, body.Position.Z)
	local to = Vector3.new(goal.X, 3, goal.Z)
	task.spawn(function()
		local started = os.clock()
		local route = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 7, AgentCanJump = false,
			AgentCanClimb = false, WaypointSpacing = 4 })
		local ok = pcall(function() route:ComputeAsync(from, to) end)
		local points
		if ok and route.Status == Enum.PathStatus.Success then
			points = {}
			for _, waypoint in ipairs(route:GetWaypoints()) do
				table.insert(points, { x = waypoint.Position.X, z = waypoint.Position.Z })
			end
		end
		route:Destroy()
		local spent = math.floor((os.clock() - started) * 1000 + 0.5)
		navStats.lastPlanMs, navStats.maxPlanMs = spent, math.max(navStats.maxPlanMs, spent)
		if not stopped then GuardianPath.finish(nav, serial, points ~= nil, points, workspace:GetServerTimeNow()) end
	end)
end

-- Walks toward goal at speed: along the planned route when there is one, else a direct step that still refuses to
-- enter geometry. The goal is clamped to the territory first, so no route ever leads into camp.
local function navigate(goal, speed, dt, now)
	local gx, gz = Rules.clampTerritory(goal.X, goal.Z)
	goal = Vector3.new(gx, home.Y, gz)
	if GuardianPath.needsPlan(nav, gx, gz, now) then requestPlan(goal, now) end
	local x, z = GuardianPath.steer(nav, body.Position.X, body.Position.Z, now)
	if x then
		stepToward(Vector3.new(x, home.Y, z), speed, dt)
	else
		navStats.directSteps += 1
		stepToward(goal, speed, dt)
	end
end

local function face(point)
	local position = body.Position
	local toward = Vector3.new(point.x - position.X, 0, point.z - position.Z)
	if toward.Magnitude < 0.05 or body.CFrame.LookVector:Dot(toward.Unit) > 0.99 then return end
	guardian:PivotTo(CFrame.lookAt(position, position + toward.Unit))
end

local function isMarked(player)
	local life = ledger.lives[player.UserId]
	local record = records[player]
	return life ~= nil and record ~= nil and life.life == record.character and life.marks > 0
end

local function snapshot(player, action, ok, notice, noticeShort)
	if stopped or not records[player] or player.Parent ~= Players then return end
	local now = workspace:GetServerTimeNow()
	local cycle = cycleAt(now)
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

-- Telegraph entry: one attack for the current target and life, warned in the same step.
local function issueAttack(now)
	local attack = FairStrike.issue(ledger, { userId = target.UserId, life = targetLife,
		guardianGeneration = guardianGeneration, now = now, endsAt = telegraphEndsAt, salt = salt,
		dwellOk = FairStrike.dwellOk(ledger, target.UserId, targetLife, now) })
	attackWarning:FireClient(target, { attackId = attack.attackId, issuedAt = now, endsAt = telegraphEndsAt,
		notice = strikeWords and strikeWords.dodge or "Dodge! Move away from Silueta." })
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
		-- D-C3: before the first paid trip home a strike resolves as shadow: no mark, no damage.
		local strikeMode = FairStrike.strikeMode(damageMode, isLethal(target))
		local out = FairStrike.resolve(ledger, attack,
			{ guardian = guardianOk(attack), binding = binding, geometry = geometry }, now, strikeMode)
		local outcome, notice, dropped, noticeShort = "Missed", "", nil, nil
		if out.outcome == "strike" and latest then
			local applied, item = applyRealStrike(latest, out.effect, attack)
			if applied then
				outcome, dropped = out.effect, item
				notice, noticeShort = FairStrike.strikeNotice(out.effect, item, strikeWords)
			end
		elseif out.outcome == "shadow" and latest and damageMode == "private" and strikeMode == "off" then
			extra.spared += 1
			outcome = "Spared"
			notice = strikeWords and strikeWords.spared or "Silueta reached you, but it cannot hurt you yet."
		end
		-- A strike that passed every gate ends that player's capture whether or not damage is on (M3.3).
		if (out.outcome == "strike" or out.outcome == "shadow") and latest and strikeEvent then strikeEvent:Fire(latest.player) end
		tellResolved(attack, outcome, notice, dropped, noticeShort)
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
				snapshot(player, "Rest", true, strikeWords and strikeWords.rested or "You rested. The mark is gone.",
					strikeWords and strikeWords.restedShort or "Mark cleared.")
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

-- The quarry got away but is still alive: search where it was last seen (clamped to the territory). A dead or
-- departed quarry, or a finished attack, sends the guardian home instead.
local function loseTarget(now, phase)
	local last = huntState and huntState.lastPosition
	local alive = target ~= nil and target.Character == targetLife and characterContext(target) ~= nil
	clearTarget(now)
	if last and alive then
		Brain.lostSight(brain, last.X, last.Z, now, phase, Rules.clampTerritory)
		setMode("Search")
	end
end

local function step(now, dt)
	local cycle = cycleAt(now)
	local phase = cycle.phase
	-- Delivery C1: day and night profiles come from the brain. Day is the calmest phase, Night the most active.
	local profile = Brain.profile(phase)
	local parameters = { speed = profile.hunt, detectionRange = profile.detection }
	if not COMBAT[mode] then
		local nearest, nearestDistance, nearestLife
		if now >= acquireBlockedUntil and Brain.canDetect(brain, now, recoveryEndsAt) then
			for player in pairs(records) do
				local candidate = targetContext(player, detectionFor(player, parameters.detectionRange))
				if candidate and (not nearestDistance or candidate.distance < nearestDistance) then
					nearest, nearestDistance, nearestLife = player, candidate.distance, candidate.character
				end
			end
		end
		if nearest then
			target, targetLife, chaseStartedAt = nearest, nearestLife, now
			alertEndsAt = now + Brain.engage(brain, now, phase)
			GuardianPath.clear(nav)
			setMode("Alert")
		elseif mode == "Patrol" then
			if flatDistance(body.Position, patrol[patrolIndex]) < 2 then patrolIndex = patrolIndex % #patrol + 1 end
			navigate(patrol[patrolIndex], profile.patrol, dt, now)
			tryAmbush(now, phase)
		elseif mode == "Retreat" then
			navigate(center, profile.retreat, dt, now)
			if now >= recoveryEndsAt and flatDistance(body.Position, center) < 2 then setMode("Patrol") end
		else
			-- Suspicious, Investigate and Search.
			local out = Brain.step(brain, now, body.Position.X, body.Position.Z, phase, Rules.clampTerritory)
			if out.mode ~= mode then
				GuardianPath.clear(nav)
				setMode(out.mode)
			end
			if out.destination then
				navigate(Vector3.new(out.destination.x, home.Y, out.destination.z), out.speed, dt, now)
			elseif out.face then
				face(out.face)
			end
		end
	else
		local candidate = targetContext(target, Rules.CHASE_RANGE, mode == "Hunt")
		if not candidate or candidate.character ~= targetLife then
			loseTarget(now, phase)
		elseif Brain.chaseExpired(chaseStartedAt, now, phase) then
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
				loseTarget(now, phase)
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
					navigate(decision.destination, parameters.speed, dt, now)
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

-- Delivery D6: any known noise (capture, sprint, rustle) reaches the brain through one function.
local function hearNoise(kind, tier, x, z)
	if stopped or not Brain.NOISE[kind] or type(tier) ~= "string" or not Rules.finite(x) or not Rules.finite(z) then return end
	extra.noises += 1
	local now = workspace:GetServerTimeNow()
	if COMBAT[mode] or now < recoveryEndsAt then return publish() end
	local phase = cycleAt(now).phase
	local position = body.Position
	if Brain.hear(brain, { kind = kind, tier = tier, x = x, z = z }, position.X, position.Z, now, phase, Rules.clampTerritory) then
		extra.noisesHeard += 1
		GuardianPath.clear(nav)
		setMode(brain.mode)
		telemetry:SetAttribute("FSx_lastNoise", ("%s,%s,%.0f,%.0f,%s"):format(kind, tier, x, z, brain.mode))
	end
	publish()
end

-- Delivery D6: hiding spots. The prompt is the only way in; HideExit, death, discovery and the time limit are the
-- ways out. Positions come from the spot, never from a client. docs/mechanics/wildbound-delivery-d.md section 3.
local hideOccupants = {} -- spot id -> player
local HIDE_REFUSAL = { Seen = "seen", Occupied = "occupied", Capturing = "busy", Cooldown = "cooldown" }
local function isCapturing(player)
	local ok, value = pcall(function() return eligibility:Invoke(player, "Capturing") end)
	return ok and value == true
end
local function noiseTier(x, z)
	local _, safe = Rules.zone(x, z)
	if safe then return nil end
	return Rules.inTerritory(x, z) and "Territory" or "Fog"
end
local function hideNotice(player, ok, key)
	local words = key and hideWords[key]
	if type(words) == "string" then snapshot(player, "Hide", ok, words, key == "entered" and hideWords.short or words) end
end

local function releaseHide(player, reason, now)
	local record = records[player]
	local hide = record and record.hide
	if not hide then return end
	record.hide = nil
	if hideOccupants[hide.id] == player then hideOccupants[hide.id] = nil end
	if player.Parent == Players then player:SetAttribute("WildboundHidden", nil) end
	if reason == "found" or reason == "tooLong" then record.hideCooldown[hide.id] = Hide.cooldownUntil(now) end
	local root = hide.root
	if root and root.Parent then
		root.Anchored = false
		if reason ~= "dead" and reason ~= "left" then
			-- A player who leaves steps out away from the guardian; a found one is pulled out on its side, in sight.
			local gx, gz = body.Position.X, body.Position.Z
			if reason == "found" then gx, gz = 2 * hide.x - gx, 2 * hide.z - gz end
			local point = Hide.exitPoint(hide.x, hide.z, gx, gz)
			root.CFrame = CFrame.lookAt(Vector3.new(point.x, hide.y, point.z),
				Vector3.new(point.x + point.faceX, hide.y, point.z + point.faceZ))
		end
	end
	if reason == "found" or reason == "tooLong" then hideNotice(player, false, reason) end
end

local function enterHide(player, spot)
	local record = records[player]
	if stopped or not record or record.hide then return end
	local zone = spot:FindFirstChild("HideZone")
	-- The spot id is in the model name (HideSpot_H01), so no attribute is read back here.
	local id = spot.Name:match("^HideSpot_(H%d+)$")
	if not (zone and zone:IsA("BasePart") and type(id) == "string") then return end
	local now = workspace:GetServerTimeNow()
	local _, _, root = characterContext(player)
	local result = awarenessResults and awarenessResults[player.UserId]
	local ok, reason = Hide.canEnter({ alive = root ~= nil, capturing = isCapturing(player),
		occupied = hideOccupants[id] ~= nil and hideOccupants[id] ~= player,
		seen = result ~= nil and result.state == "seen", cooldownUntil = record.hideCooldown[id], now = now })
	if ok and (root.Position - zone.Position).Magnitude > Hide.CONFIG.PROMPT_DISTANCE + 4 then ok, reason = false, "Far" end
	if not ok then return hideNotice(player, false, HIDE_REFUSAL[reason]) end
	-- The Capturing question yields, so check the record, the character and the spot again before taking it.
	local _, _, again = characterContext(player)
	if stopped or records[player] ~= record or record.hide or hideOccupants[id] or again ~= root then return end
	local inside = zone.Position
	hideOccupants[id] = player
	record.hide = { id = id, root = root, enteredAt = now, dwell = Hide.newDwell(), x = inside.X, y = root.Position.Y,
		z = inside.Z }
	root.Anchored = true
	root.CFrame = CFrame.new(inside.X, inside.Y + 1.5, inside.Z) * root.CFrame.Rotation
	player:SetAttribute("WildboundHidden", id)
	local tier = noiseTier(inside.X, inside.Z)
	if tier then hearNoise("rustle", tier, inside.X, inside.Z) end
	hideNotice(player, true, "entered")
end

-- Each fixed step: a dead or replaced character leaves its spot, 45 s is the limit, and a guardian that stands
-- near the spot long enough finds the player and engages with the short re-acquire wind-up.
local function stepHiding(now)
	local phase = cycleAt(now).phase
	for player, record in pairs(records) do
		local hide = record.hide
		if hide then
			local _, _, root = characterContext(player)
			if not root or root ~= hide.root then
				releaseHide(player, "dead", now)
			elseif Hide.tooLong(hide.enteredAt, now) then
				releaseHide(player, "tooLong", now)
			else
				local dx, dz = body.Position.X - hide.x, body.Position.Z - hide.z
				if Hide.discover(hide.dwell, { dt = 0.2, mode = mode, phase = phase, targetIsMe = target == player,
					distance = math.sqrt(dx * dx + dz * dz) }) then
					releaseHide(player, "found", now)
					if not COMBAT[mode] then
						target, targetLife, chaseStartedAt = player, player.Character, now
						alertEndsAt = now + Brain.engage(brain, now, phase)
						GuardianPath.clear(nav)
						setMode("Alert")
					end
				end
			end
		end
	end
end

-- Delivery D8: the threat bucket per player, published as attributes. It reveals nothing a streamed client cannot
-- already see about the guardian, and the client plays all horror audio from it.
local function stepThreat(now)
	for player, record in pairs(records) do
		local _, _, root = characterContext(player)
		local safe, distance = false, nil
		if root then
			local _, isSafe = Rules.zone(root.Position.X, root.Position.Z)
			local dx, dz = root.Position.X - body.Position.X, root.Position.Z - body.Position.Z
			safe, distance = isSafe, math.sqrt(dx * dx + dz * dz)
		end
		record.threat = record.threat or Threat.new()
		local level = Threat.update(record.threat, { mode = mode, distance = distance, targetIsMe = target == player,
			hidden = record.hide ~= nil, safe = safe, alive = root ~= nil }, now)
		if record.publishedThreat ~= level then
			record.publishedThreat = level
			player:SetAttribute("WildboundThreatLevel", level)
			player:SetAttribute("WildboundThreatAt", now)
		end
	end
end

local function bindHideSpot(spot)
	if not spot:IsA("Model") then return end
	local zone = spot:FindFirstChild("HideZone")
	local prompt = zone and zone:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then return end
	prompt.ActionText = hideWords.prompt or "Esconderse"
	local kinds = hideWords.kind
	prompt.ObjectText = type(kinds) == "table" and kinds[spot:FindFirstChild("Hollow") and "log" or "bush"] or ""
	prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode[Keys.HIDE.key], Enum.KeyCode[Keys.HIDE.pad]
	prompt.HoldDuration, prompt.MaxActivationDistance = Hide.CONFIG.PROMPT_HOLD, Hide.CONFIG.PROMPT_DISTANCE
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OneGlobally
	prompt.RequiresLineOfSight = false
	table.insert(connections, prompt.Triggered:Connect(function(player) enterHide(player, spot) end))
end
for _, spot in ipairs(CollectionService:GetTagged("WildboundHideSpot")) do bindHideSpot(spot) end
table.insert(connections, CollectionService:GetInstanceAddedSignal("WildboundHideSpot"):Connect(bindHideSpot))

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
	if action ~= "RequestSnapshot" and action ~= "Flashlight" and action ~= "LumipolPulse" and action ~= "HideExit" then return end
	local record = records[player]
	if not record then return end
	local now = workspace:GetServerTimeNow()
	-- Bounded known keys only. Spam is dropped, never reflected with an unbounded reply.
	if now - record.lastRequest < 0.3 or now - (record.rates[action] or -math.huge) < 1 then return end
	record.lastRequest, record.rates[action] = now, now
	if action == "HideExit" then return releaseHide(player, "exit", now) end
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
	-- Delivery B5: an accepted pulse is marked on the player, so every client flashes that player's companion.
	if ok and action == "LumipolPulse" then player:SetAttribute("WildboundPulseAt", now) end
	if hit then
		-- Concurrent reveals overlap; they never add seconds to an existing expiry.
		revealedUntil = math.max(revealedUntil, now + Rules.REVEAL_SECONDS)
		guardian:SetAttribute("RevealedUntil", revealedUntil)
		if action == "LumipolPulse" and pulseHit and root and Rules.zone(root.Position.X, root.Position.Z) then
			pulseHit:Fire(player, true)
		end
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
-- Delivery C1: capture noise. Server-to-server only; every value is still checked. It never interrupts a fight, and a
-- guardian still recovering from an attack ignores it.
if noiseEvent then
	table.insert(connections, noiseEvent.Event:Connect(function(kind, tier, x, z)
		if kind == "ring" or kind == "seal" then hearNoise(kind, tier, x, z) end
	end))
end
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
		ackBucket = {}, readyBucket = {}, pulseBucket = {},
		hideCooldown = {}, threat = Threat.new() }
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
		if records[player] == record and record.hide then releaseHide(player, "dead", workspace:GetServerTimeNow()) end
		if records[player] == record and record.character == character then record.character = nil end
	end)
end
table.insert(connections, Players.PlayerAdded:Connect(addPlayer))
table.insert(connections, Players.PlayerRemoving:Connect(function(player)
	local record = records[player]
	if not record then return end
	record.characterConnection:Disconnect()
	record.removingConnection:Disconnect()
	releaseHide(player, "left", workspace:GetServerTimeNow())
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
		stepHiding(now)
		stepThreat(now)
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
		if record.hide and record.hide.root and record.hide.root.Parent then record.hide.root.Anchored = false end
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

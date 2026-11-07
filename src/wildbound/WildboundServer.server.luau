-- Authoritative adapter. Deploy beside WildboundState in ServerScriptService.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local State = require(script.Parent:WaitForChild("WildboundState"))
local Wild = require(script.Parent:WaitForChild("WildboundLumipolWild"))
local Rules = require(script.Parent:WaitForChild("WildboundWorldRules"))
local Capture = require(ReplicatedStorage:WaitForChild("WildboundCaptureSession"))
-- M5.2: the pure economy rules and the generated tuning copy (docs/mechanics/wildbound-economy-p0.md).
local Economy = require(ReplicatedStorage:WaitForChild("WildboundEconomy"))
local EconomyConfig = require(ReplicatedStorage:WaitForChild("WildboundEconomyConfig"))
local state = State.new(Economy, EconomyConfig)
local capture = Capture.new()
local map = workspace:WaitForChild("WildboundP0", 15)
if not map then warn("Wildbound: build the P0 map before starting gameplay."); return end

local function marker(name)
	local value = map:FindFirstChild(name, true)
	assert(value and value:IsA("BasePart"), "Wildbound missing marker: " .. name)
	return value
end
local creatureMarker, eggMarker = marker("LumipolMarker"), marker("EggMarker")
local extraction = marker("ExtractionMarker")
local campCenter = marker("CampCenter")
local hatchMarker, protectionMarker = marker("HatchMarker"), marker("ProtectionMarker")
-- Never overwrite an unowned or already-running root on duplicate startup.
if map:FindFirstChild("WildboundRuntime") or ReplicatedStorage:FindFirstChild("WildboundNetwork") then
	warn("Wildbound: runtime/network already exists; duplicate startup refused.")
	return
end
local runtime = Instance.new("Folder")
runtime.Name, runtime.Parent = "WildboundRuntime", map
local network = Instance.new("Folder")
network.Name = "WildboundNetwork"
network:SetAttribute("SessionOnly", true)
local actionRemote, stateRemote = Instance.new("RemoteEvent"), Instance.new("RemoteEvent")
actionRemote.Name, actionRemote.Parent = "Action", network
stateRemote.Name, stateRemote.Parent = "State", network
-- M3.3: the capture screen's feed. Only the session owner is ever sent a message on it.
local captureRemote = Instance.new("RemoteEvent")
captureRemote.Name, captureRemote.Parent = "CaptureState", network
-- Server-to-server only: a client can fire its own copy of a BindableEvent, which reaches nothing here.
local strikeEvent = Instance.new("BindableEvent")
strikeEvent.Name, strikeEvent.Parent = "CaptureStrike", network
network.Parent = ReplicatedStorage

-- Measurement for the capture exit tests. Lives in ServerStorage, so no client can read or change it.
local telemetry = ServerStorage:FindFirstChild("WildboundTelemetry")
if not telemetry then
	telemetry = Instance.new("Folder")
	telemetry.Name, telemetry.Parent = "WildboundTelemetry", ServerStorage
end

-- Server-to-server proof of registered ownership; clients cannot invoke bindables.
-- Never use a replicated Player attribute alone to authorize a companion ability.
local eligibility = Instance.new("BindableFunction")
eligibility.Name = "Eligibility"
eligibility.OnInvoke = function(player, ability)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players
		or ability ~= "LumipolPulse" then return false end
	local snapshot = state:snapshot(player.UserId)
	if not snapshot or not snapshot.equippedUid then return false end
	for _, pet in ipairs(snapshot.registered) do
		if pet.uid == snapshot.equippedUid and pet.species == "Lumipol" then return true end
	end
	return false
end
eligibility.Parent = network

local records, serial = {}, 0
local playersByUserId = {}
local notices = {
	InvalidContext = "Move closer while alive and try again.", Empty = "Your bag is empty.",
	BackpackFull = "Bag full. Return to camp to extract.", AlreadyClaimed = "Someone collected this encounter.",
	CollectionFull = "Session collection limit reached (100 items).",
	NotOwnedEgg = "Select one of your banked eggs.", NotOwnedPet = "Only your registered pets can be equipped.",
	NotOwnedPending = "Select an item in your temporary bag.", NoSeal = "Your first extraction earns one seal.",
	AlreadyProtected = "One item is already protected.", InvalidEncounter = "This encounter is no longer available.",
}
-- The capture rule owns the words for its own refusals and endings.
for reason, text in pairs(Capture.NOTICES) do
	if notices[reason] == nil and text ~= "" then notices[reason] = text end
end
-- Walk speed follows the eggs in the bag (M3.5). Set when a reply is sent and for each new character.
local function applyCarry(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local snapshot = state:snapshot(player.UserId)
	if not humanoid or not snapshot then return end
	local speed = Wild.carrySpeed(Wild.eggsCarried(snapshot))
	if humanoid.WalkSpeed ~= speed then humanoid.WalkSpeed = speed end
end
local function send(player, action, ok, notice, lossSummary)
	if not records[player] or player.Parent ~= Players then return end
	applyCarry(player)
	stateRemote:FireClient(player, {
		snapshot = state:snapshot(player.UserId), action = action, ok = ok, notice = notice or "",
		lossSummary = lossSummary,
	})
end
local function allowed(player, action)
	local record = records[player]
	if not record then return false end
	local now = os.clock()
	if now - record.lastAny < 0.08 or now - (record.rates[action] or -math.huge) < 0.3 then return false end
	record.lastAny, record.rates[action] = now, now
	return true
end
local function context(player, target)
	local record, character = records[player], player.Character
	if not record or not character or record.character ~= character or not character:IsDescendantOf(workspace) then
		return false, math.huge
	end
	local humanoid, root = character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart")
	if record.defeated or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return false, math.huge
	end
	if not target then return true, 0 end
	if not target:IsDescendantOf(map) then return false, math.huge end
	return true, (root.Position - target.Position).Magnitude
end
local function reply(player, action, ok, reason, success)
	send(player, action, ok, ok and success or (notices[reason] or "That action is not available."))
end
local function prompt(target, action, object, range, hold)
	local value = Instance.new("ProximityPrompt")
	value.ActionText, value.ObjectText = action, object
	value.MaxActivationDistance, value.HoldDuration = range, hold or 0.25
	value.RequiresLineOfSight, value.KeyboardKeyCode = false, Enum.KeyCode.E
	value.Parent = target
	return value
end
local function validPrompt(value, target)
	return value.Enabled and value.Parent == target and target:IsDescendantOf(map)
end
local function hatch(player, uid)
	local alive, distance = context(player, hatchMarker)
	local ok, reason = state:hatch(player.UserId, uid, alive, distance)
	reply(player, "Hatch", ok, reason, "Lumipol hatched and registered. Hatching is free.")
end
local function protect(player, uid)
	local alive, distance = context(player, protectionMarker)
	local ok, reason
	if not alive or distance ~= distance or distance < 0 or distance > 12 then
		ok, reason = false, "InvalidContext"
	else
		ok, reason = state:protect(player.UserId, uid, alive)
	end
	reply(player, "Protect", ok, reason, "Selected item protected for one defeat. Seal is spent only if it saves the item.")
end

local extractPrompt = prompt(extraction, "Extract bag", "Camp · session only", 12)
extractPrompt.Triggered:Connect(function(player)
	if not validPrompt(extractPrompt, extraction) or not allowed(player, "Extract") then return end
	local alive, distance = context(player, extraction)
	local ok, count = state:extract(player.UserId, alive, distance)
	reply(player, "Extract", ok, count, "Extracted " .. tostring(count) .. " item(s). First extraction earns one seal.")
end)
local hatchPrompt = prompt(hatchMarker, "Hatch first egg", "Free hatch", 12)
hatchPrompt.Triggered:Connect(function(player)
	if not validPrompt(hatchPrompt, hatchMarker) or not allowed(player, "Hatch") then return end
	local snapshot = state:snapshot(player.UserId)
	local egg = snapshot and snapshot.bankedEggs[1]
	hatch(player, egg and egg.uid)
end)
local protectionPrompt = prompt(protectionMarker, "Choose protected item", "Earned protection", 12)
protectionPrompt.Triggered:Connect(function(player)
	if not validPrompt(protectionPrompt, protectionMarker) or not allowed(player, "ProtectHint") then return end
	local alive, distance = context(player, protectionMarker)
	if alive and distance == distance and distance <= 12 then
		send(player, "ProtectHint", true, "In your inventory, choose a temporary item and press Protect. One item maximum.")
	end
end)

local function block(model, name, size, offset, color, shape)
	local part = Instance.new("Part")
	part.Name, part.Size, part.CFrame = name, size, offset
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
	part.Material, part.Color = Enum.Material.SmoothPlastic, color
	if shape then part.Shape = shape end
	part.Parent = model
	return part
end
local function visual(kind, position)
	local model = Instance.new("Model")
	model.Name = kind == "Egg" and "LumipolEgg" or "Lumipol"
	local body = block(model, "Body", kind == "Egg" and Vector3.new(2, 2.8, 2) or Vector3.new(3, 2, 2.4),
		CFrame.new(position + Vector3.new(0, 2, 0)), Color3.fromRGB(121, 202, 160), Enum.PartType.Ball)
	if kind == "Creature" then
		for _, x in ipairs({ -0.65, 0.65 }) do
			block(model, "Eye", Vector3.new(0.35, 0.4, 0.25),
				body.CFrame * CFrame.new(x, 0.3, -1.15), Color3.fromRGB(25, 43, 48))
			block(model, "Ear", Vector3.new(0.6, 1.3, 0.7),
				body.CFrame * CFrame.new(x, 1.1, 0) * CFrame.Angles(0, 0, x * 0.3), Color3.fromRGB(81, 151, 117))
		end
	end
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Parent = Color3.fromRGB(151, 236, 175), 0.7, 10, body
	model.PrimaryPart, model.Parent = body, runtime
	return model, body
end

-- Slots, sessions and wildlife -------------------------------------------------------------------
-- Every wild encounter lives in `entries`, keyed by its never-reused id. Slot ids decide where and when.
local rng = Random.new()
local function rand() return rng:NextNumber() end
local entries, slotState = {}, {}
local sessionMeta = {}
local captureLog = {}
local counters = { started = 0, completed = 0, failed = 0, cancelled = 0, grantRefused = 0, rejected = 0 }
local groundY = creatureMarker.Position.Y
local handleEnding

local function publishTelemetry()
	telemetry:SetAttribute("CaptureAnomaly", capture.counters.anomaly)
	telemetry:SetAttribute("CaptureWatchdog", capture.counters.watchdog)
	for key, value in pairs(counters) do telemetry:SetAttribute("Capture_" .. key, value) end
	telemetry:SetAttribute("CaptureLog", HttpService:JSONEncode(captureLog))
end

local function rootOf(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root:IsA("BasePart") and root or nil
end

-- Values the capture rule trusts: all read here, none from a client.
local function observe(player, now)
	local record = records[player]
	local alive = context(player)
	local root = rootOf(player)
	local bag, collection = state:captureRoom(player.UserId)
	local position = root and root.Position
	return { now = now, alive = alive == true and root ~= nil, life = record and record.generation,
		x = position and position.X, y = position and position.Y, z = position and position.Z,
		bagRoom = bag, collectionRoom = collection }
end

local function guardianReading(position)
	local world = map:FindFirstChild("WildboundWorldRuntime")
	local guardian = world and world:FindFirstChild("Silueta")
	local body = guardian and guardian:FindFirstChild("Body")
	if not body or not body:IsA("BasePart") then return nil, nil end
	return guardian:GetAttribute("State"), (body.Position - position).Magnitude
end

local function slotOf(id)
	local slot = Wild.slot(id)
	if not slot then return nil end
	-- The map's own markers stay the truth for the two slots that already had one.
	local at = id == "S0a" and creatureMarker or id == "E1" and eggMarker or nil
	if not at then return slot end
	local moved = table.clone(slot)
	moved.x, moved.z = at.Position.X, at.Position.Z
	return moved
end

local function removeEntry(entry, now)
	if entries[entry.id] ~= entry then return end
	entries[entry.id] = nil
	entry.prompt.Enabled = false
	if entry.connection then entry.connection:Disconnect() end
	entry.model:Destroy()
	state:retireEncounter(entry.id)
	local out = capture:retire(entry.id, now or workspace:GetServerTimeNow())
	if out then handleEnding(out) end
end

local spawnEncounter
local function ensureSlots()
	for _, id in ipairs(Wild.activeSlotIds(math.max(1, #Players:GetPlayers()))) do
		if slotState[id] == nil then spawnEncounter(slotOf(id)) end
	end
end
local function scheduleRespawn(slot)
	slotState[slot.id] = "wait"
	task.delay(Wild.respawnSeconds(slot, #Players:GetPlayers()), function()
		slotState[slot.id] = nil
		ensureSlots()
	end)
end

local function startCapture(player, entry)
	local record = records[player]
	if not record then return end
	local now = workspace:GetServerTimeNow()
	local alive, distance = context(player, entry.body)
	local root = rootOf(player)
	local snapshot = state:snapshot(player.UserId)
	if not alive or not root or not snapshot then
		reply(player, "Capture", false, "InvalidContext")
		return
	end
	local bag, collection = state:captureRoom(player.UserId)
	local position, lumipol = root.Position, entry.body.Position
	local ok, result = capture:begin({
		playerKey = player.UserId, encounterId = entry.id, dir = rng:NextInteger(0, 1) * 2 - 1,
		lumipolX = lumipol.X, lumipolZ = lumipol.Z, now = now, alive = alive, life = record.generation,
		distance = distance, x = position.X, y = position.Y, z = position.Z,
		encounterStatus = state:encounterStatus(entry.id) or "Gone",
		slotRefusal = Wild.slotRefusal(entry.slot.tier, snapshot), bagRoom = bag, collectionRoom = collection,
	})
	if not ok then
		counters.rejected += 1
		reply(player, "Capture", false, result)
		return
	end
	counters.started += 1
	entry.prompt.Enabled = false
	Wild.reserve(entry.brain, position.X, position.Z)
	local mode, guardianDistance = guardianReading(position)
	sessionMeta[result.token] = { startedAt = now, slot = entry.slot.id, tier = entry.slot.tier,
		inTerritory = Rules.inTerritory(position.X, position.Z), guardianMode = mode,
		guardianDistance = guardianDistance and math.floor(guardianDistance * 10 + 0.5) / 10 or nil }
	captureRemote:FireClient(player, Capture.toSnapshot(result))
end

-- Every ending passes through here: grant, spook or release, the final push, and the log.
handleEnding = function(out)
	local entry = entries[out.encounterId]
	local player = playersByUserId[out.playerKey]
	local now = workspace:GetServerTimeNow()
	local notice, granted = out.notice, false
	if out.grant then
		local alive = player ~= nil and context(player) == true
		local ok, reason = state:completeCapture(out.playerKey, out.encounterId, alive,
			entry and entry.slot.tier or "Fog")
		granted = ok
		if ok then
			counters.completed += 1
		else
			-- The rule said finished but the bag disagreed. Nothing is granted and the Lumipol still goes.
			counters.grantRefused += 1
			notice = notices[reason] or "That action is not available."
		end
		if entry then
			removeEntry(entry, now)
			scheduleRespawn(entry.slot)
		end
	elseif entry and entry.brain then
		if out.spook then
			local threat = player and rootOf(player)
			Wild.spook(entry.brain, threat and threat.Position.X, threat and threat.Position.Z, rand)
		else
			Wild.release(entry.brain)
		end
	end
	if out.phase == "Failed" then counters.failed += 1 elseif out.phase == "Cancelled" then counters.cancelled += 1 end
	local meta = sessionMeta[out.token]
	sessionMeta[out.token] = nil
	if meta then
		table.insert(captureLog, { slot = meta.slot, tier = meta.tier, reason = out.reason, granted = granted,
			seconds = math.floor((now - meta.startedAt) * 100 + 0.5) / 100, calm = math.floor(out.calm * 100 + 0.5) / 100,
			inTerritory = meta.inTerritory, guardianMode = meta.guardianMode, guardianDistance = meta.guardianDistance })
		while #captureLog > 40 do table.remove(captureLog, 1) end
	end
	if player and records[player] and player.Parent == Players then
		local snapshot = Capture.toSnapshot(out)
		if snapshot then
			snapshot.notice = notice
			captureRemote:FireClient(player, snapshot)
		end
		if notice ~= "" then send(player, "Capture", granted, notice) end
	end
	publishTelemetry()
end

spawnEncounter = function(slot)
	if not slot or runtime.Parent ~= map then return end
	serial += 1
	local id = slot.kind .. ":" .. serial
	if not state:registerEncounter(id, slot.kind) then return end
	local model, body = visual(slot.kind, Vector3.new(slot.x, groundY, slot.z))
	model:SetAttribute("EncounterId", id)
	model:SetAttribute("Slot", slot.id)
	local isEgg = slot.kind == "Egg"
	local entry = { id = id, slot = slot, model = model, body = body, bodyY = body.Position.Y }
	-- A creature is calmed with a tap, so its prompt has no hold. Eggs keep the short hold.
	entry.prompt = prompt(body, isEgg and "Collect" or "Calm", isEgg and "Lumipol egg" or "Lumipol", 10, isEgg and 0.25 or 0)
	if not isEgg then entry.brain = Wild.newBrain(slot, rand) end
	entries[id] = entry
	slotState[slot.id] = id
	entry.connection = entry.prompt.Triggered:Connect(function(player)
		if entries[id] ~= entry or model.Parent ~= runtime or not validPrompt(entry.prompt, body) then return end
		if isEgg then
			if not allowed(player, "Pickup") then return end
			local alive, distance = context(player, body)
			local ok, reason = state:pickup(player.UserId, id, alive, distance)
			if ok then
				removeEntry(entry)
				scheduleRespawn(slot)
			end
			reply(player, "Pickup", ok, reason, "Collected temporary loot. Extract it at camp before defeat.")
		else
			if not allowed(player, "CaptureStart") then return end
			startCapture(player, entry)
		end
	end)
end

-- Silueta's resolved strike ends the target's capture, whether or not damage is on (the world script fires it).
strikeEvent.Event:Connect(function(player)
	if typeof(player) == "Instance" and player:IsA("Player") and records[player] then
		capture:notifyStruck(player.UserId)
	end
end)

-- Dropped items (D6, M4.6). Each lies near its owner for 30 s; only the owner can pick it up.
local DROP_SECONDS = 30
local drops = {}
local function removeDrop(uid)
	local drop = drops[uid]
	if not drop then return nil end
	drops[uid] = nil
	drop.prompt.Enabled = false
	drop.connection:Disconnect()
	drop.model:Destroy()
	return drop
end
-- The owner was defeated, replaced or left: the world copies go. State already moved or lost the entries.
local function removeDropsOf(player)
	for uid, drop in pairs(drops) do
		if drop.owner == player then removeDrop(uid) end
	end
end
local function itemName(entry)
	return entry.kind == "Egg" and "Lumipol egg" or "Lumipol"
end
local function spawnDrop(player, entry, towardX, towardZ)
	local root = rootOf(player)
	if not root then return end
	local from = Vector3.new(root.Position.X, 0, root.Position.Z)
	local toward = Vector3.new(towardX, 0, towardZ) - from
	local offset = toward.Magnitude > 0.01 and toward.Unit * 4 or Vector3.new(0, 0, 4)
	-- Clamped to the fog forest, where every strike happens.
	local x = math.clamp(from.X + offset.X, -45, 165)
	local z = math.clamp(from.Z + offset.Z, -165, 35)
	local model, body = visual(entry.kind, Vector3.new(x, groundY, z))
	model.Name = "DroppedItem"
	model:SetAttribute("OwnerUserId", player.UserId)
	local drop = { owner = player, uid = entry.uid, model = model }
	drop.prompt = prompt(body, "Pick up", "Dropped " .. itemName(entry), 10, 0.25)
	drop.connection = drop.prompt.Triggered:Connect(function(who)
		if drops[entry.uid] ~= drop or not validPrompt(drop.prompt, body) then return end
		if who ~= drop.owner then
			if allowed(who, "DropRefused") then send(who, "Pickup", false, "This belongs to another player.") end
			return
		end
		if not allowed(who, "Reclaim") then return end
		local alive, distance = context(who, body)
		local ok, reason = state:reclaimDropped(who.UserId, entry.uid, alive, distance)
		if ok then removeDrop(entry.uid) end
		reply(who, "Reclaim", ok, reason, "Picked up your dropped " .. itemName(entry) .. ".")
	end)
	drops[entry.uid] = drop
	task.delay(DROP_SECONDS, function()
		if drops[entry.uid] ~= drop then return end
		removeDrop(entry.uid)
		local ok = state:loseDropped(player.UserId, entry.uid)
		if ok then send(player, "DropLost", false, "Your dropped " .. itemName(entry) .. " was lost.") end
	end)
end

-- Server-to-server only (the Eligibility pattern): the world script calls this for a real first strike.
-- It drops one bag item once per attack id and returns what dropped, or nil. The capture ends through
-- CaptureStrike, which the world fires for the same strike.
local strikeEffect = Instance.new("BindableFunction")
strikeEffect.Name = "StrikeEffect"
strikeEffect.OnInvoke = function(player, attackId, towardX, towardZ)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or not records[player] or type(attackId) ~= "string"
		or not Rules.finite(towardX) or not Rules.finite(towardZ) then return nil end
	local ok, entry = state:dropForStrike(player.UserId, attackId)
	if not ok then return nil end
	if entry then spawnDrop(player, entry, towardX, towardZ) end
	send(player, "Strike", true, "")
	return entry and { kind = entry.kind, species = entry.species } or nil
end
strikeEffect.Parent = network

local function stepWildlife(now)
	local watchers = {}
	for player in pairs(records) do
		local root = rootOf(player)
		if root and context(player) then table.insert(watchers, root.Position) end
	end
	for _, entry in pairs(entries) do
		local brain = entry.brain
		if brain then
			local prompting = capture:encounterState(entry.id, now) == "Free"
			if entry.prompt.Enabled ~= prompting then entry.prompt.Enabled = prompting end
			local near, best = nil, math.huge
			for _, position in ipairs(watchers) do
				local distance = math.sqrt((position.X - brain.x) ^ 2 + (position.Z - brain.z) ^ 2)
				if distance < best then best, near = distance, { x = position.X, z = position.Z } end
			end
			local fx, fz = brain.fx, brain.fz
			Wild.step(brain, Wild.CONSTANTS.STEP, near, rand)
			if brain.moved or math.abs(brain.fx - fx) > 1e-3 or math.abs(brain.fz - fz) > 1e-3 then
				local at = Vector3.new(brain.x, entry.bodyY, brain.z)
				entry.model:PivotTo(CFrame.lookAt(at, at + Vector3.new(brain.fx, 0, brain.fz)))
			end
		end
	end
end

local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	if dt ~= dt or dt < 0 then return end
	accumulator += math.min(dt, 0.2)
	if accumulator < Wild.CONSTANTS.STEP then return end
	accumulator = 0
	local now = workspace:GetServerTimeNow()
	for _, item in ipairs(capture:activeSessions()) do
		local player = playersByUserId[item.playerKey]
		if not player or not records[player] then
			local out = capture:drop(item.playerKey, now)
			if out then handleEnding(out) end
		else
			local out = capture:sample(item.token, observe(player, now))
			if out then
				if out.phase == "Active" then
					captureRemote:FireClient(player, Capture.toSnapshot(out))
				else
					handleEnding(out)
				end
			end
		end
	end
	for _, out in ipairs(capture:sweep(now)) do handleEnding(out) end
	stepWildlife(now)
end)

actionRemote.OnServerEvent:Connect(function(player, action, uid, ...)
	if type(action) ~= "string" or #action > 32 or select("#", ...) > 0 then return end
	if action ~= "RequestSnapshot" and action ~= "Equip" and action ~= "Protect" and action ~= "Hatch"
		and action ~= "CaptureCancel" then return end
	if action == "RequestSnapshot" then
		if uid ~= nil or not allowed(player, action) then return end
		send(player, action, true, "Session only: collection resets when you leave this server.")
		return
	end
	if type(uid) ~= "string" or #uid == 0 or #uid > 128 or not allowed(player, action) then return end
	if action == "CaptureCancel" then
		-- The token is untrusted. A wrong owner, a stale or a made-up one is ignored without a reply.
		local ok, out = capture:cancel(uid, player.UserId, workspace:GetServerTimeNow())
		if ok then handleEnding(out) end
		return
	end
	if action == "Hatch" then hatch(player, uid)
	elseif action == "Protect" then protect(player, uid)
	else
		local alive = context(player)
		local ok, reason = state:equip(player.UserId, uid, alive)
		if ok then
			player:SetAttribute("WildboundEquippedUid", uid)
			player:SetAttribute("WildboundHasLumipol", true)
		end
		reply(player, action, ok, reason, "Lumipol equipped.")
	end
end)

local function bindCharacter(player, character)
	local record = records[player]
	if not record or record.character == character then return end
	-- Character replacement/reset is also a defeat boundary, even if Died was missed.
	if record.character and not record.defeated then
		state:defeat(player.UserId, "life:" .. record.generation)
		removeDropsOf(player)
	end
	if record.deathConnection then record.deathConnection:Disconnect(); record.deathConnection = nil end
	record.generation += 1
	record.character, record.defeated = character, false
	local generation = record.generation
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or records[player] ~= record
		or record.generation ~= generation or player.Character ~= character then return end
	local function defeated()
		if records[player] ~= record or record.generation ~= generation or record.defeated
			or record.character ~= character or player.Character ~= character then return end
		record.defeated = true
		local _, _, lossSummary = state:defeat(player.UserId, "life:" .. generation)
		removeDropsOf(player)
		-- The client shows the summary full screen before respawn (M4.6).
		send(player, "Defeat", true, "Defeated: unprotected temporary loot was lost. Banked eggs and registered pets remain.",
			lossSummary)
	end
	record.deathConnection = humanoid.Died:Connect(defeated)
	if humanoid.Health <= 0 then defeated(); return end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	-- Revalidate after the bounded wait; an old life must never move a replacement character.
	if not root or not root:IsA("BasePart") or records[player] ~= record
		or record.generation ~= generation or record.character ~= character or player.Character ~= character
		or record.defeated or humanoid.Health <= 0 or not humanoid:IsDescendantOf(character)
		or not root:IsDescendantOf(character) or not character:IsDescendantOf(workspace)
		or not campCenter:IsDescendantOf(map) or not map:IsDescendantOf(workspace) then return end
	-- Once per new character, not an ability teleport; preserve the existing SpawnLocation.
	character:PivotTo(CFrame.new(campCenter.Position + Vector3.new(0, 4, 10)))
	applyCarry(player)
	send(player, "Respawn", true, "Return temporary loot to camp. Registered collection is session only.")
end
local function addPlayer(player)
	if records[player] then return end
	state:addPlayer(player.UserId)
	local record = { rates = {}, lastAny = -math.huge, generation = 0, defeated = false }
	records[player] = record
	playersByUserId[player.UserId] = player
	record.characterConnection = player.CharacterAdded:Connect(function(character) bindCharacter(player, character) end)
	if player.Character then task.spawn(bindCharacter, player, player.Character) end
	ensureSlots()
end
Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
	local record = records[player]
	if not record then return end
	if record.deathConnection then record.deathConnection:Disconnect() end
	if record.characterConnection then record.characterConnection:Disconnect() end
	-- Free any reservation first, with no grant and no penalty, before the profile goes (M3.3, CAP-32).
	local out = capture:drop(player.UserId, workspace:GetServerTimeNow())
	if out then handleEnding(out) end
	-- D10 hold is not built: a disconnected owner's drops go with the profile.
	removeDropsOf(player)
	records[player] = nil
	playersByUserId[player.UserId] = nil
	state:removePlayer(player.UserId)
end)
for _, player in ipairs(Players:GetPlayers()) do addPlayer(player) end
ensureSlots()
publishTelemetry()

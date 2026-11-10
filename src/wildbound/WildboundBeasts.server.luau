-- Nest Heist phase 4a (NB5): the beast script. The one authority that spawns beasts: every Config.DIRECTOR.TICK_SECONDS
-- it asks WildboundBeastDirector to roll for each living player outside a safe zone, and it steps every encounter
-- (WildboundBeastEncounters) on the server at 20 Hz. Each encounter belongs to one target: its events and 10 Hz
-- snapshots go to that player's client alone over BeastEvent (FireClient), which draws its own visual from
-- ReplicatedStorage.WildboundBeasts.Models. Nothing listens to BeastEvent from clients, so no client can spawn a beast,
-- claim a hit or claim a dodge. A landed hit goes to the inventory server's BeastHit (server to server): the egg in the
-- arms falls through the one drop path and health drops only in the private damage mode, so a defeat runs the ordinary
-- Died flow. Every end (death, escape, timeout, safe zone, leave, error) releases the threat budget exactly once.
-- La Silueta stays outside the budget; no beast starts while the player's own Silueta hunts or telegraphs.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Rules = require(script.Parent:WaitForChild("WildboundWorldRules"))
local Director = require(script.Parent:WaitForChild("WildboundBeastDirector"))
local Enc = require(script.Parent:WaitForChild("WildboundBeastEncounters"))
local Proxies = require(script.Parent:WaitForChild("WildboundBeastProxies"))
local Config = require(ReplicatedStorage:WaitForChild("WildboundBeastConfig"))

local map = workspace:WaitForChild("WildboundP0", 15)
local network = ReplicatedStorage:WaitForChild("WildboundNetwork", 15)
if not map or not network or not network:IsA("Folder") then
	warn("Wildbound beasts: map and inventory network are required.")
	return
end
if network:FindFirstChild("BeastEvent") then
	warn("Wildbound beasts: duplicate startup refused.")
	return
end
Proxies.ensure(ReplicatedStorage)
-- Server to the target client only. No server handler is connected: whatever a client fires on it reaches nothing.
local beastEvent = Instance.new("RemoteEvent")
beastEvent.Name = "BeastEvent"
beastEvent.Parent = network

local telemetry = ServerStorage:FindFirstChild("WildboundTelemetry")
if not telemetry then
	telemetry = Instance.new("Folder")
	telemetry.Name, telemetry.Parent = "WildboundTelemetry", ServerStorage
end

local D = Config.DIRECTOR
local STEP, SNAPSHOT = 1 / 20, 0.1
local rng = Random.new()
local director = Director.new({ random = function() return rng:NextNumber() end })
local players = {} -- [Player] = { respawnedAt, outsideSince, character }
local live = {} -- [encounter id] = { e = encounter, player = Player, character = Model }
local counts = { started = 0, ended = 0, hits = 0, refused = 0, noSpawn = 0, errors = 0 }
local eventLog = {} -- the last events with their server times, for the Studio probe

local function now() return workspace:GetServerTimeNow() end

local function count(key, by)
	counts[key] += by or 1
	telemetry:SetAttribute("Beast_" .. key, counts[key])
end

local function logEvent(id, kind, at, extra)
	table.insert(eventLog, { id = id, type = kind, at = at, extra = extra })
	if #eventLog > 200 then table.remove(eventLog, 1) end
end

-- World adapter -----------------------------------------------------------------------------------------------------

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true
-- Walls for the dash and the leap: the same, plus the relief, which is ground the beasts run and land on (R5).
local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Exclude
wallParams.RespectCanCollide = true
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.RespectCanCollide = true
local function refreshFilter()
	local exclude = {}
	for _, name in ipairs({ "WildboundWorldRuntime", "WildboundRuntime" }) do
		local folder = map:FindFirstChild(name)
		if folder then table.insert(exclude, folder) end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then table.insert(exclude, player.Character) end
	end
	params.FilterDescendantsInstances = exclude
	overlap.FilterDescendantsInstances = exclude
	local walls = table.clone(exclude)
	if map:FindFirstChild("Relief") then table.insert(walls, map.Relief) end
	wallParams.FilterDescendantsInstances = walls
end

local function groundAt(x, z, refY)
	local hit = workspace:Raycast(Vector3.new(x, refY + 20, z), Vector3.new(0, -80, 0), params)
	return hit and hit.Position.Y or nil
end

local function clearAt(x, y, z)
	return #workspace:GetPartBoundsInBox(CFrame.new(x, y + 2.5, z), Vector3.new(3, 3, 3), overlap) == 0
end

local world = {}
function world.ground(x, z, refY) return groundAt(x, z, refY) end
-- The first solid thing along the lane, 2.5 studs over the ground (low walls, trunks and rocks cut the dash; the relief
-- does not: the dash runs along it).
function world.castLane(ox, oy, oz, dx, dz, length)
	local hit = workspace:Raycast(Vector3.new(ox, oy + 2.5, oz), Vector3.new(dx * length, 0, dz * length), wallParams)
	return hit and hit.Distance or nil
end
-- A landing needs ground under it (no void), no safe zone and no solid part where the beast lands.
function world.landing(x, z, refY)
	local _, safe = Rules.zone(x, z)
	if safe then return nil end
	local y = groundAt(x, z, refY)
	if not y or not clearAt(x, y, z) then return nil end
	return y
end
-- The arc in four straight pieces, 2 studs over the curve: a trunk or a ceiling on the way calls the jump off.
function world.arcClear(ax, ay, az, bx, by, bz, height)
	local previous = Vector3.new(ax, ay + 2, az)
	for i = 1, 4 do
		local x, y, z = Config.arc(ax, ay, az, bx, by, bz, height, i / 4)
		local point = Vector3.new(x, y + 2, z)
		if workspace:Raycast(previous, point - previous, wallParams) then return false end
		previous = point
	end
	return true
end

-- Player context ----------------------------------------------------------------------------------------------------

local function bodyOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then return nil end
	return character, humanoid, root
end

local function isNight(at)
	local worldRuntime = map:FindFirstChild("WildboundWorldRuntime")
	local origin = worldRuntime and worldRuntime:GetAttribute("CycleStartedAt")
	if type(origin) ~= "number" then return false end
	local holder = RunService:IsStudio() and telemetry:FindFirstChild("StudioClockShift")
	local shift = holder and holder:IsA("NumberValue") and holder.Value or 0
	if shift ~= shift or math.abs(shift) > 1e6 then shift = 0 end
	return Rules.cycle(at - origin + shift).phase == "Night"
end

-- The player's own Silueta (the world script's hunter whose Owner is this player) is hunting or telegraphing.
local function siluetaActive(userId)
	local worldRuntime = map:FindFirstChild("WildboundWorldRuntime")
	if not worldRuntime then return false end
	for _, hunter in ipairs(worldRuntime:GetChildren()) do
		if hunter:GetAttribute("Owner") == userId then
			local state = hunter:GetAttribute("State")
			if state == "Hunt" or state == "Telegraph" then return true end
		end
	end
	return false
end

local function contextFor(player, at)
	local record = players[player]
	local character, humanoid, root = bodyOf(player)
	if not record or not character or humanoid.Health <= 0 then return { alive = false } end
	local p = root.Position
	local fog, safe = Rules.zone(p.X, p.Z)
	if safe then record.outsideSince = nil else record.outsideSince = record.outsideSince or at end
	return { alive = true, safe = safe, night = isNight(at),
		farFromBase = Rules.farFromBase(p.X, p.Z, D.FAR_FROM_BASE),
		dangerousZone = fog or Rules.inTerritory(p.X, p.Z),
		longExpedition = record.outsideSince ~= nil and at - record.outsideSince >= D.LONG_EXPEDITION,
		storm = false, -- no weather system yet
		siluetaActive = siluetaActive(player.UserId), respawnedAt = record.respawnedAt,
		biomes = {} } -- no Cementerio or Pantano zone exists yet
end

-- Encounters ----------------------------------------------------------------------------------------------------------

local function send(player, payload)
	if player.Parent == Players then beastEvent:FireClient(player, payload) end
end

local function close(id, reason, at, event)
	local entry = live[id]
	live[id] = nil
	if Director.release(director, id, reason, at) then count("ended") end
	if entry then
		local ending = event or Enc.finish(entry.e, reason, at)
		if ending then
			logEvent(id, "End", at, reason)
			send(entry.player, ending)
		end
	end
end

-- A spawn point 35 to 70 (Viper) or 75 (Pouncer) studs from the target, on the ground, out of every safe zone and
-- clear of solid parts; one hidden from the target's eyes (behind a trunk or a rock) is preferred.
local function spawnPoint(beast, root)
	local C = Config.BEASTS[beast]
	local from = root.Position
	local fallback
	for _ = 1, 16 do
		local angle = rng:NextNumber() * math.pi * 2
		local distance = C.spawnMin + rng:NextNumber() * (C.spawnMax - C.spawnMin)
		local x, z = from.X + math.cos(angle) * distance, from.Z + math.sin(angle) * distance
		local y = world.landing(x, z, from.Y)
		if y and math.abs(y - (from.Y - 3)) <= 15 then
			local eye = from + Vector3.new(0, 1.5, 0)
			local point = Vector3.new(x, y + 2, z)
			if workspace:Raycast(eye, point - eye, params) then return { x = x, y = y, z = z } end
			fallback = fallback or { x = x, y = y, z = z }
		end
	end
	return fallback
end

local function start(player, reservation, at)
	local character, _, root = bodyOf(player)
	if not Config.PLAYABLE[reservation.beast] then
		close(reservation.id, "NoBehaviour", at)
		return false, "NoBehaviour"
	end
	refreshFilter()
	local point = character and spawnPoint(reservation.beast, root)
	if not point then
		count("noSpawn")
		close(reservation.id, "NoSpawn", at)
		return false, "NoSpawn"
	end
	local e = Enc.new(reservation.beast, reservation.id, player.UserId, at, point)
	local dx, dz = Config.unit(root.Position.X - point.x, root.Position.Z - point.z)
	e.dx, e.dz = dx or 0, dz or 1
	live[reservation.id] = { e = e, player = player, character = character }
	count("started")
	logEvent(e.id, "Spawn", at, reservation.beast)
	send(player, { type = "Spawn", id = e.id, beast = e.beast, at = at, pos = { x = point.x, y = point.y, z = point.z },
		dx = e.dx, dz = e.dz })
	return true, e.id
end

-- Verifier finding (Nest Heist Phase 3): an error while an encounter starts (spawn point, filters, the first message)
-- must not leak its reservation. It ends as Error through close, which releases the threat budget exactly once.
local function safeStart(player, reservation, at)
	local ok, started, value = pcall(start, player, reservation, at)
	if ok then return started, value end
	count("errors")
	warn("Wildbound beasts: encounter start error, ended: " .. tostring(started))
	close(reservation.id, "Error", at)
	return false, "Error"
end

local function targetOf(entry)
	local character, humanoid, root = bodyOf(entry.player)
	-- A new character is a new life: the encounter ends as a death, never carried to the respawned body.
	if entry.player.Parent ~= Players or not character or character ~= entry.character or humanoid.Health <= 0 then return nil end
	local p, v = root.Position, root.AssemblyLinearVelocity
	local _, safe = Rules.zone(p.X, p.Z)
	return { x = p.X, y = p.Y, z = p.Z, vx = v.X, vz = v.Z, alive = true, safe = safe }
end

local beastHit = nil
local function landHit(entry, event)
	count("hits")
	beastHit = beastHit or network:FindFirstChild("BeastHit")
	local ok, effect = false, nil
	if beastHit and beastHit:IsA("BindableFunction") then
		ok, effect = pcall(function() return beastHit:Invoke(entry.player, entry.e.beast, event.damage) end)
	end
	if not ok then telemetry:SetAttribute("Beast_hitFailed", (telemetry:GetAttribute("Beast_hitFailed") or 0) + 1) end
	event.eggDropped = ok and type(effect) == "table" and effect.eggDropped == true or nil
end

local function stepEncounter(id, entry, at)
	local events = Enc.step(entry.e, at, targetOf(entry), world)
	for _, event in ipairs(events) do
		if event.type == "End" then
			close(id, event.reason, at, event)
		else
			if event.type == "Hit" then landHit(entry, event) end
			logEvent(id, event.type, event.at, event.reason or event.hit)
			send(entry.player, event)
		end
	end
end

local function snapshot(entry, at)
	local e = entry.e
	send(entry.player, { type = "Snap", id = e.id, at = at, phase = e.phase, x = e.pos.x, y = e.pos.y, z = e.pos.z,
		dx = e.dx, dz = e.dz, center = e.beast == "Pouncer" and e.phase == "Telegraph" and not e.frozen and e.center or nil })
end

local stepClock, snapClock, tickClock = 0, 0, 0
RunService.Heartbeat:Connect(function(dt)
	stepClock += dt
	snapClock += dt
	tickClock += dt
	if stepClock >= STEP then
		stepClock = 0
		local at = now()
		refreshFilter()
		for id, entry in pairs(live) do
			local ok, message = pcall(stepEncounter, id, entry, at)
			if not ok then
				count("errors")
				warn("Wildbound beasts: encounter error, ended: " .. tostring(message))
				close(id, "Error", at)
			end
		end
	end
	if snapClock >= SNAPSHOT then
		snapClock = 0
		local at = now()
		for _, entry in pairs(live) do snapshot(entry, at) end
	end
	if tickClock >= D.TICK_SECONDS then
		tickClock = 0
		local at = now()
		for _, player in ipairs(Players:GetPlayers()) do
			local started, refused = Director.tick(director, player.UserId, contextFor(player, at), at)
			for _, reservation in ipairs(started) do safeStart(player, reservation, at) end
			for _, refusal in ipairs(refused) do
				count("refused")
				telemetry:SetAttribute("Beast_lastRefusal", refusal.beast .. ":" .. refusal.reason)
			end
		end
	end
end)

local function track(player)
	players[player] = { respawnedAt = now(), outsideSince = nil }
	player.CharacterAdded:Connect(function()
		if players[player] then players[player].respawnedAt = now() end
	end)
end
for _, player in ipairs(Players:GetPlayers()) do track(player) end
Players.PlayerAdded:Connect(track)
Players.PlayerRemoving:Connect(function(player)
	local at = now()
	for id, entry in pairs(live) do
		if entry.player == player then
			live[id] = nil
			Enc.finish(entry.e, "Leave", at)
			logEvent(id, "End", at, "Leave")
		end
	end
	local released = Director.forget(director, player.UserId, at)
	count("ended", #released)
	players[player] = nil
end)

-- Studio only, server only (ServerStorage, never a remote): force a beast on a player through the director's own
-- reservation (timers skipped, budget and every other rule kept), and read or end encounters for the Play check.
if RunService:IsStudio() then
	local force = Instance.new("BindableFunction")
	force.Name = "ForceSpawnBeast"
	force.OnInvoke = function(name, player)
		if type(player) == "number" then player = Players:GetPlayerByUserId(player) end
		if typeof(player) ~= "Instance" or not player:IsA("Player") or type(name) ~= "string" then return false, "BadArguments" end
		local at = now()
		local ok, value = Director.reserve(director, player.UserId, name, contextFor(player, at), at, { force = true })
		if not ok then
			telemetry:SetAttribute("Beast_lastRefusal", name .. ":" .. tostring(value))
			return false, value
		end
		return safeStart(player, value, at)
	end
	force.Parent = telemetry
	local probe = Instance.new("BindableFunction")
	probe.Name = "BeastProbe"
	probe.OnInvoke = function(op, value)
		if op == "read" then
			local out = { encounters = {}, counts = table.clone(counts), log = {}, events = table.clone(eventLog), budget = {} }
			for id, entry in pairs(live) do
				local e = entry.e
				out.encounters[id] = { beast = e.beast, phase = e.phase, userId = e.userId, x = e.pos.x, y = e.pos.y, z = e.pos.z,
					attacks = e.attacks, jumps = e.jumps }
			end
			for _, player in ipairs(Players:GetPlayers()) do
				local points, active = Director.budget(director, player.UserId)
				out.budget[player.UserId] = { points = points, active = active }
			end
			for i = math.max(1, #director.log - 20), #director.log do table.insert(out.log, director.log[i]) end
			return out
		elseif op == "clear" then
			table.clear(eventLog)
			return true
		elseif op == "end" and type(value) == "string" and live[value] then
			close(value, "Probe", now())
			return true
		elseif op == "context" and typeof(value) == "Instance" and value:IsA("Player") then
			return contextFor(value, now())
		end
		return false
	end
	probe.Parent = telemetry
end

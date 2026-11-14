-- Nest Heist phase 4a (NB5): the beast script. The one authority that spawns beasts: on the director's calendar
-- it asks WildboundBeastDirector to roll for each living player outside a safe zone, and it steps every encounter
-- (WildboundBeastEncounters) on the server at 20 Hz. Each encounter belongs to one target: its events and 10 Hz
-- snapshots go to that player's client alone over BeastEvent (FireClient), which draws its own visual from
-- ReplicatedStorage.WildboundBeasts.Models. Nothing listens to BeastEvent from clients, so no client can spawn a beast,
-- claim a hit or claim a dodge. A landed hit goes to the inventory server's BeastHit (server to server): the egg in the
-- arms falls through the one drop path and health drops only in the private damage mode, so a defeat runs the ordinary
-- Died flow. Every end (death, escape, timeout, safe zone, leave, error) releases the threat budget exactly once.
-- La Silueta stays outside the budget; no beast starts while the player's own Silueta hunts or telegraphs.
-- Wave 2 (odd/tasks/wildbound-beasts-wave2.md): the director rolls on its 20 s calendar (polled every POLL_SECONDS),
-- ctx.biomes comes from WildboundBiomes, and Streamer, Root, Gaze and Lurker run as registered behaviours. Their
-- dodgeable attacks are registered with and resolved by WildboundDodgeService (the same per-player states the
-- inventory server's "dodge" press uses); the client's camera direction arrives on BeastObserve, is validated by
-- WildboundBeastSight and only steers Gaze and Lurker, never a hit or a dodge.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Rules = require(script.Parent:WaitForChild("WildboundWorldRules"))
local Director = require(script.Parent:WaitForChild("WildboundBeastDirector"))
local Enc = require(script.Parent:WaitForChild("WildboundBeastEncounters"))
local Proxies = require(script.Parent:WaitForChild("WildboundBeastProxies"))
local Config = require(ReplicatedStorage:WaitForChild("WildboundBeastConfig"))
local Biomes = require(script.Parent:WaitForChild("WildboundBiomes"))
local Attack = require(script.Parent:WaitForChild("WildboundBeastAttack"))
local Sight = require(ReplicatedStorage:WaitForChild("WildboundBeastSight"))
local DodgeService = require(script.Parent:WaitForChild("WildboundDodgeService"))
for _, name in ipairs({ "Streamer", "Root", "Gaze", "Lurker" }) do
	Enc.register(name, require(script.Parent:WaitForChild("WildboundBeast" .. name)))
end
-- Beast spawn P0: the dusk roll buff. A place without the module keeps every roll at x1 instead of stalling the beasts.
local duskModule = ReplicatedStorage:WaitForChild("WildboundDusk", 10)
local Dusk = duskModule and require(duskModule) or nil
if not Dusk then warn("Wildbound beasts: WildboundDusk missing, no dusk roll buff.") end

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
-- EV-W3: the uploaded Viper and Pouncer models (ServerStorage.WildboundAssets.Beasts) replace the proxies when present.
do
	local assets = ServerStorage:FindFirstChild("WildboundAssets")
	Proxies.ensure(ReplicatedStorage, assets and assets:FindFirstChild("Beasts"))
end
-- Server to the target client only. No server handler is connected: whatever a client fires on it reaches nothing.
local beastEvent = Instance.new("RemoteEvent")
beastEvent.Name = "BeastEvent"
beastEvent.Parent = network
-- Wave 2: client to server, the camera's look vector only (WildboundBeastSight validates rate and shape). It can only
-- steer Gaze's exposure and Lurker's pause; damage and dodges never read it.
local observeEvent = Instance.new("RemoteEvent")
observeEvent.Name = "BeastObserve"
observeEvent.Parent = network
local sights = {} -- [Player] = WildboundBeastSight state

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
local live = {} -- [encounter id] = { e = encounter, player = Player, character = Model, world = per-encounter adapter }
local claims = {} -- [Player] = { [attack id] = { enc = encounter id, at = strike time } } (anti-frustration stagger)
local counts = { started = 0, ended = 0, hits = 0, refused = 0, noSpawn = 0, errors = 0, dodged = 0, staggered = 0,
	observeDropped = 0 }
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
-- Wave 2. Sight lines count every queryable part, colliding or not (leaves and props are cover too), so a thin
-- decoration never lets a gaze or a beast "see through" it. Characters and runtime visuals never block.
local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude
sightParams.RespectCanCollide = false
sightParams.IgnoreWater = true -- swamp water is never a wall for the eyes
local function sightClear(from, to)
	sightParams.FilterDescendantsInstances = params.FilterDescendantsInstances
	return workspace:Raycast(from, to - from, sightParams) == nil
end
-- A clear line from a beast (2.5 studs over its feet) to the target's chest.
function world.lineOfSight(from, target)
	return sightClear(Vector3.new(from.x, from.y + 2.5, from.z), Vector3.new(target.x, target.y + 0.5, target.z))
end
function world.safe(x, z)
	local _, safe = Rules.zone(x, z)
	return safe
end
-- Root's enclosure gap: a free run from the centre out through the gap, 4 studs past the ring, at knee and head height.
function world.gapClear(center, gx, gz, radius)
	local reach = radius + 4
	for _, h in ipairs({ 1.5, 4 }) do
		local from = Vector3.new(center.x, center.y + h, center.z)
		if workspace:Raycast(from, Vector3.new(gx * reach, 0, gz * reach), params) then return false end
	end
	local _, safe = Rules.zone(center.x + gx * reach, center.z + gz * reach)
	return not safe
end

-- Player context ----------------------------------------------------------------------------------------------------

local function bodyOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then return nil end
	return character, humanoid, root
end

-- The day cycle's phase name ("Day", "Dusk", "Night", "Dawn"), or nil before the world script starts the cycle.
local function phaseAt(at)
	local worldRuntime = map:FindFirstChild("WildboundWorldRuntime")
	local origin = worldRuntime and worldRuntime:GetAttribute("CycleStartedAt")
	if type(origin) ~= "number" then return nil end
	local holder = RunService:IsStudio() and telemetry:FindFirstChild("StudioClockShift")
	local shift = holder and holder:IsA("NumberValue") and holder.Value or 0
	if shift ~= shift or math.abs(shift) > 1e6 then shift = 0 end
	return Rules.cycle(at - origin + shift).phase
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
	local phase = phaseAt(at)
	return { alive = true, safe = safe, night = phase == "Night",
		duskRoll = Dusk and Dusk.buff(phase).roll or 1, -- x1.25 during Dusk only (WildboundDusk), x1 otherwise
		-- The inventory server welds its "WildboundEggCarried" backpack to the character exactly while EggCarry says this
		-- player carries an egg (Heist.syncEggArms); a server-made child, so a client cannot add one.
		carryingEgg = character:FindFirstChild("WildboundEggCarried") ~= nil,
		farFromBase = Rules.farFromBase(p.X, p.Z, D.FAR_FROM_BASE),
		dangerousZone = fog or Rules.inTerritory(p.X, p.Z),
		longExpedition = record.outsideSince ~= nil and at - record.outsideSince >= D.LONG_EXPEDITION,
		storm = false, -- no weather system yet
		siluetaActive = siluetaActive(player.UserId), respawnedAt = record.respawnedAt,
		biomes = Biomes.at(p.X, p.Z) } -- wave 2 (P1): Swamp = Pantano, Meadow = Pradera, Cemetery = Cementerio
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
		-- Wave 2: an attack still open never lands after the end, and its dodge registration and stagger claim go too.
		Attack.closeAll(entry.e, entry.world)
		local mine = claims[entry.player]
		if mine then
			for attackId, claim in pairs(mine) do
				if claim.enc == id then mine[attackId] = nil end
			end
		end
		local ending = event or Enc.finish(entry.e, reason, at)
		if ending then
			logEvent(id, "End", at, reason)
			send(entry.player, ending)
		end
	end
end

-- Wave 2: where each beast may appear. Viper and Pouncer keep their ring and prefer a hidden point; Gaze prefers a
-- point the target can see (its eyes are the tell), Root needs the Pantano, Lurker starts behind the target at its
-- InitialSpawnDistance.
local function spawnSpec(beast)
	local C = Config.BEASTS[beast]
	if beast == "Lurker" then
		local d = C.tuning.InitialSpawnDistanceStuds
		return { min = d, max = d, visible = false, behind = true }
	end
	return { min = C.spawnMin, max = C.spawnMax, visible = beast == "Gaze", biome = C.biome }
end

-- A spawn point 35 to 70 (Viper) or 75 (Pouncer) studs from the target, on the ground, out of every safe zone and
-- clear of solid parts; one hidden from the target's eyes (behind a trunk or a rock) is preferred.
local function spawnPoint(beast, root)
	local spec = spawnSpec(beast)
	local from = root.Position
	local look = root.CFrame.LookVector
	local behind = math.atan2(-look.Z, -look.X)
	local fallback
	for _ = 1, 16 do
		local angle = spec.behind and behind + (rng:NextNumber() - 0.5) * math.rad(120) or rng:NextNumber() * math.pi * 2
		local distance = spec.min + rng:NextNumber() * (spec.max - spec.min)
		local x, z = from.X + math.cos(angle) * distance, from.Z + math.sin(angle) * distance
		local y = world.landing(x, z, from.Y)
		if y and math.abs(y - (from.Y - 3)) <= 15 and (not spec.biome or Biomes.has(x, z, spec.biome)) then
			local eye = from + Vector3.new(0, 1.5, 0)
			local point = Vector3.new(x, y + 2, z)
			local hidden = workspace:Raycast(eye, point - eye, params) ~= nil
			if hidden ~= spec.visible then return { x = x, y = y, z = z } end
			fallback = fallback or { x = x, y = y, z = z }
		end
	end
	return fallback
end

-- Wave 2: the anti-frustration stagger (pack 05_MATRIZ_COMBINACIONES). A wave 2 attack may not strike within
-- STRIKE_SEPARATION of another encounter's strike on the same player; Viper's dash and Pouncer's landing are recorded
-- (force) so the new beasts wait for them, and their own timing never changes.
local function claimStrike(player, encId, attackId, strikeAt, force)
	local mine = claims[player]
	if not mine then
		mine = {}
		claims[player] = mine
	end
	local at = now()
	for key, claim in pairs(mine) do
		if claim.at < at - 1 then
			mine[key] = nil
		elseif not force and claim.enc ~= encId and math.abs(claim.at - strikeAt) < D.STRIKE_SEPARATION then
			count("staggered")
			return false
		end
	end
	mine[attackId] = { enc = encId, at = strikeAt }
	return true
end

-- The adapter one encounter sees: the shared world plus what needs its player (the dodge states, the stagger claims,
-- Gaze's new spot).
local function worldFor(player)
	local w = setmetatable({}, { __index = world })
	function w.telegraph(id, beast, startAt, strikeAt)
		return (DodgeService.telegraph(player, id, beast, startAt, strikeAt))
	end
	function w.resolve(id, at)
		local verdict = DodgeService.resolve(player, id, at)
		if verdict == "Dodged" then count("dodged") end
		return verdict
	end
	function w.cancel(id) DodgeService.cancel(player, id) end
	function w.claimStrike(encId, attackId, strikeAt) return claimStrike(player, encId, attackId, strikeAt, false) end
	function w.reposition(e)
		local _, _, root = bodyOf(player)
		return root and spawnPoint(e.beast, root) or nil
	end
	return w
end

local function start(player, reservation, at)
	local character, _, root = bodyOf(player)
	if not Config.PLAYABLE[reservation.beast] or not Enc.registered(reservation.beast) then
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
	live[reservation.id] = { e = e, player = player, character = character, world = worldFor(player) }
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
	local target = { x = p.X, y = p.Y, z = p.Z, vx = v.X, vz = v.Z, alive = true, safe = safe }
	if Config.WAVE2[entry.e.beast] then
		target.biomes = Biomes.at(p.X, p.Z)
		if Config.OBSERVERS[entry.e.beast] then
			-- Whether the target observes a point: the cone starts at the server's head position, the line of sight is the
			-- server's raycast, and only the look direction comes from the client (validated, or the body's facing).
			target.observe = function(point, halfAngle, maxDist, favour)
				local head = p + Vector3.new(0, 1.5, 0)
				local look = root.CFrame.LookVector
				return (Sight.observes(sights[entry.player], now(), { origin = { x = head.X, y = head.Y, z = head.Z },
					bodyLook = { x = look.X, y = look.Y, z = look.Z }, point = point, halfAngle = halfAngle,
					maxDist = maxDist, los = sightClear(head, Vector3.new(point.x, point.y, point.z)), favour = favour }))
			end
		end
	end
	return target
end

-- Wave 2: Root's trap slow on the target's walk speed. It never stacks, and it is put back only if nothing changed the
-- speed meanwhile; the inventory server's own speed update (a stance change, an egg drop) ends it early, never late.
local function applySlow(player, multiplier, seconds)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not Config.finite(multiplier) or not Config.finite(seconds) then return end
	multiplier, seconds = math.clamp(multiplier, 0.5, 1), math.clamp(seconds, 0, 3)
	local untilAt = humanoid:GetAttribute("WildboundBeastSlowUntil")
	if type(untilAt) == "number" and untilAt > now() then return end
	local slowed = humanoid.WalkSpeed * multiplier
	humanoid.WalkSpeed = slowed
	humanoid:SetAttribute("WildboundBeastSlowUntil", now() + seconds)
	task.delay(seconds, function()
		if humanoid.Parent and math.abs(humanoid.WalkSpeed - slowed) < 1e-3 then humanoid.WalkSpeed = slowed / multiplier end
	end)
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
	-- Wave 2 extras: Root's slow is applied here; Streamer's light push (event.knock) rides on the Hit event to the
	-- target's client, which owns its character's physics and clamps it.
	if type(event.slow) == "table" then applySlow(entry.player, event.slow.multiplier, event.slow.seconds) end
end

-- Esquiva perfecta (decision Q3b, odd/tasks/wildbound-new-mechanics.md W2): Viper's dash and Pouncer's leap are
-- dodgeable. Each tell registers its attack with the shared WildboundDodgeService (Viper: Windup to dashAt; Pouncer:
-- Telegraph to landAt); a Hit asks resolve() first and a perfect press inside the window skips it. An attack that ends
-- without a strike is cancelled. Attack ids: the encounter id and the attack number. DodgeService is required at the
-- top. Wave 2 beasts never pass here: their attack layer registers and resolves through entry.world (one path each).
local function dodgeStep(entry, event)
	local e = entry.e
	if e.beast ~= "Viper" and e.beast ~= "Pouncer" then return false end
	local attack = e.beast == "Viper" and e.attacks or e.jumps or 0
	local key = tostring(e.id) .. ":"
	if event.type == "Windup" and e.beast == "Viper" then
		DodgeService.telegraph(entry.player, key .. (attack + 1), "Viper", event.at, event.dashAt)
	elseif event.type == "Telegraph" and e.beast == "Pouncer" then
		DodgeService.telegraph(entry.player, key .. (attack + 1), "Pouncer", event.at, event.landAt)
	elseif event.type == "Hit" then
		return DodgeService.resolve(entry.player, key .. tostring(event.attack), event.at) == "Dodged"
	elseif event.type == "Recover" then
		DodgeService.cancel(entry.player, key .. attack)
	elseif event.type == "Cancel" then
		DodgeService.cancel(entry.player, key .. (attack + 1))
	end
	return false
end

local function stepEncounter(id, entry, at)
	local events = Enc.step(entry.e, at, targetOf(entry), entry.world or world)
	for _, event in ipairs(events) do
		if event.type == "End" then
			close(id, event.reason, at, event)
		elseif dodgeStep(entry, event) then
			count("dodged")
			logEvent(id, "Dodged", event.at, nil)
		else
			-- The original beasts' strikes are recorded for the wave 2 stagger; their timing never changes.
			if event.type == "Windup" and Config.finite(event.dashAt) then
				claimStrike(entry.player, id, id .. ":dash:" .. tostring(event.at), event.dashAt, true)
			elseif event.type == "Telegraph" and Config.finite(event.landAt) then
				claimStrike(entry.player, id, id .. ":leap:" .. tostring(event.at), event.landAt, true)
			end
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

local stepClock, snapClock, pollClock = 0, 0, 0
RunService.Heartbeat:Connect(function(dt)
	stepClock += dt
	snapClock += dt
	pollClock += dt
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
	-- Wave 2: the director's calendar decides which beasts roll (20 s each, 1 s apart); this only asks it often enough.
	if pollClock >= D.POLL_SECONDS then
		pollClock = 0
		local at = now()
		for _, player in ipairs(Players:GetPlayers()) do
			-- The context is read only when a slot is due (Director.tick = Director.due + Director.roll).
			local due = Director.due(director, player.UserId, at)
			local started, refused = {}, {}
			if #due > 0 then started, refused = Director.roll(director, player.UserId, contextFor(player, at), at, due) end
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
			Attack.closeAll(entry.e, nil)
			logEvent(id, "End", at, "Leave")
		end
	end
	local released = Director.forget(director, player.UserId, at)
	count("ended", #released)
	players[player] = nil
	sights[player] = nil
	claims[player] = nil
end)

-- Wave 2: the target client's look vector (WildboundBeastSight.accept: at most 10 a second, a finite unit vector). Only
-- players the script tracks; anything else is dropped. It is stored and read by Gaze and Lurker, never acted on alone.
observeEvent.OnServerEvent:Connect(function(player, payload)
	if not players[player] then return end
	local state = sights[player]
	if not state then
		state = Sight.new()
		sights[player] = state
	end
	if not Sight.accept(state, now(), payload) then count("observeDropped") end
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
					attacks = e.attacks, jumps = e.jumps, exposure = e.exposure, open = Attack.openIds(e) }
			end
			for _, player in ipairs(Players:GetPlayers()) do
				local points, active = Director.budget(director, player.UserId)
				-- Wave 2: the next calendar slot of every beast, read without rolling, and the observation counters.
				local slots = {}
				for _, name in ipairs(Config.ORDER) do slots[name] = Director.nextSlot(director, player.UserId, name, now()) end
				local sight = sights[player]
				out.budget[player.UserId] = { points = points, active = active, slots = slots,
					sight = sight and { accepted = sight.accepted, dropped = sight.dropped, bad = sight.bad } or nil }
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

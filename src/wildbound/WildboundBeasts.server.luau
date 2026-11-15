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
-- SC0 shared visibility (odd/tasks/wildbound-scuttler.md, owner decision Q4): every other player within
-- Config.AUDIENCE.RADIUS of a beast also gets its visual events (spawn, phases, tells, moves, end) and 5 Hz snapshots,
-- as filtered copies marked `bystander` (WildboundBeastAudience). Hits, slows, sticky, marks, knocks, egg drops, the
-- Gaze meter and every HUD cue stay with the target. Membership is re-evaluated as players move: an entering player
-- gets a spawn snapshot, a leaving one an End. The director, the budget and the dodge states are untouched.
-- SC7 Scuttler (docs/design/wildbound-scuttler-plan.md): registered like the wave 2 behaviours. Its adapter adds the
-- server-written dash time (bait and re-plan) and a server Random (the feint roll); its target carries the egg and
-- whether the player's own Silueta hunts (Scuttler yields). A landed pulse is an Afflict: applySlow only, never
-- BeastHit, and never copied to a bystander (not in Audience.VISUAL). Its egg drops ride the ordinary Hit path.
local CollectionService = game:GetService("CollectionService")
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
local PlaceRules = require(ReplicatedStorage:WaitForChild("WildboundBiomeLight"))
local Attack = require(script.Parent:WaitForChild("WildboundBeastAttack"))
local Sight = require(ReplicatedStorage:WaitForChild("WildboundBeastSight"))
local DodgeService = require(script.Parent:WaitForChild("WildboundDodgeService"))
local Audience = require(script.Parent:WaitForChild("WildboundBeastAudience"))
for _, name in ipairs({ "Streamer", "Root", "Gaze", "Lurker", "Scuttler" }) do
	Enc.register(name, require(script.Parent:WaitForChild("WildboundBeast" .. name)))
end
-- Kids biome (odd/tasks/wildbound-kids-beasts.md): the Pradera's two summoned beasts, never rolled (Config.SUMMONED).
local Sites = require(script.Parent:WaitForChild("WildboundPraderaSites"))
local KIDS = { { name = "NubeGrunona", module = "WildboundBeastNube" }, { name = "AbejaReina", module = "WildboundBeastAbeja" },
	{ name = "Gomibu", module = "WildboundBeastGomibu" }, { name = "Flanfuria", module = "WildboundBeastFlanfuria" },
	{ name = "Tortidragon", module = "WildboundBeastTortidragon" }, -- Caramelo biome: the candy nest guardians
	{ name = "DonGlaseon", module = "WildboundBeastDonGlaseon", boss = true } } -- and its one boss per server (bossPass)
for _, kid in ipairs(KIDS) do Enc.register(kid.name, require(script.Parent:WaitForChild(kid.module))) end
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
-- Server to the target client, and (SC0) visual copies to bystanders in range. No server handler is connected:
-- whatever a client fires on it reaches nothing.
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
	observeDropped = 0, afflicted = 0 }
local eventLog = {} -- the last events with their server times, for the Studio probe
local AUDIENCE = Config.AUDIENCE
local audience = Audience.new() -- SC0: which other players see which encounter

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

-- Kids biome: the Pradera's sites from the sector origin (Workspace "WildboundPradera", read only, else the Meadow
-- centre), and the sky ray: one upward ray from the head against WildboundRoof parts only (a hit means covered).
local function praderaOrigin()
	local pradera = workspace:FindFirstChild("WildboundPradera")
	if pradera and (pradera:IsA("Model") or pradera:IsA("BasePart")) then
		local p = pradera:GetPivot().Position
		return { x = p.X, z = p.Z }
	end
	return nil
end
function world.site(key)
	return Sites.world(praderaOrigin(), key)
end
local roofParams = RaycastParams.new()
roofParams.FilterType = Enum.RaycastFilterType.Include
roofParams.RespectCanCollide = false
local function covered(head)
	roofParams.FilterDescendantsInstances = CollectionService:GetTagged("WildboundRoof")
	return workspace:Raycast(head, Vector3.new(0, 200, 0), roofParams) ~= nil
end
local function inMeadow(x, z) return Biomes.has(x, z, "Meadow") end
-- The Abeja window: the server's event clock writes BiomeEvent (read only here); Studio may override it (ForceAbejaEvent).
local biomeEvent = telemetry:GetAttribute("BiomeEvent")
telemetry:GetAttributeChangedSignal("BiomeEvent"):Connect(function()
	biomeEvent = telemetry:GetAttribute("BiomeEvent")
	telemetry:SetAttribute("Beast_abejaWindow", Sites.eventOpen(biomeEvent, nil))
end)
local abejaOverride = nil -- Studio only: true opens, false closes, nil follows BiomeEvent
local function eventOpen() return Sites.eventOpen(biomeEvent, abejaOverride) end

-- Player context ----------------------------------------------------------------------------------------------------

local function bodyOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then return nil end
	return character, humanoid, root
end

-- CA4 (odd/tasks/wildbound-caramelo.md): no global day/night cycle. CF1 (user, 2026-11-15, "Bosque siempre de
-- noche"): the phase of the player's place (PlaceRules.phaseAt): the forest (and Abismo, Cuevas) always Night, so the
-- night odds (x2) hold there; Caramelo and the rest Day (no night odds, no Nube night range). Never Dusk: no Dusk buff.
local function phaseAt(x, z)
	return (PlaceRules.phaseAt(x, z))
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
	local phase = phaseAt(p.X, p.Z)
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

-- SC0: a visual event's filtered copy to the encounter's bystanders; a non-visual event (a hit) is never copied.
local function sendBystanders(id, event)
	local copy = Audience.forBystander(event)
	if not copy then return end
	Audience.remember(audience, id, copy) -- the live visual state, replayed to a late joiner
	for _, userId in ipairs(Audience.recipients(audience, id)) do
		local viewer = Players:GetPlayerByUserId(userId)
		if viewer then send(viewer, copy) end
	end
end

-- CF3 (odd/tasks/wildbound-caramelo.md): Beast_bossAwake is written in the step an encounter starts or ends (and again
-- with every snapshot), so WildboundCandyDonGlaseonService hides the sleeping copy in the summon's own server step.
local function publishBoss()
	if telemetry then telemetry:SetAttribute("Beast_bossAwake", Config.bossAwake(live)) end
end

local function close(id, reason, at, event)
	local entry = live[id]
	live[id] = nil
	publishBoss()
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
			sendBystanders(id, ending)
		end
	end
	Audience.close(audience, id)
end

-- Wave 2: where each beast may appear. Viper and Pouncer keep their ring and prefer a hidden point; Gaze prefers a
-- point the target can see (its eyes are the tell), Lurker starts behind the target at its InitialSpawnDistance. A
-- beast with a home biome (Config.homeBiome: Root's Pantano, only while Config.BIOME_PREFERENCE is on) spawns only on it.
local function spawnSpec(beast)
	local C = Config.BEASTS[beast]
	if beast == "Lurker" then
		local d = C.tuning.InitialSpawnDistanceStuds
		return { min = d, max = d, visible = false, behind = true }
	end
	-- SC7: Scuttler is Global (no home biome, no route weighting): a plain ring like Viper's, a hidden point preferred.
	if beast == "Scuttler" then
		return { min = C.spawnMin, max = C.spawnMax, visible = false }
	end
	return { min = C.spawnMin, max = C.spawnMax, visible = beast == "Gaze", biome = Config.homeBiome(beast) }
end

-- A spawn point 35 to 70 (Viper) or 75 (Pouncer) studs from the target, on the ground, out of every safe zone and
-- clear of solid parts; one hidden from the target's eyes (behind a trunk or a rock) is preferred.
local function spawnPoint(beast, root)
	if Config.SUMMONED[beast] then
		-- Kids biome: the Nube at the pond, the Abeja at La Colmena, on the ground there (no ground: no spawn).
		local site = world.site(Sites.HOME[beast])
		local y = site and groundAt(site.x, site.z, root.Position.Y)
		return y and { x = site.x, y = y, z = site.z } or nil
	end
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
	-- SC7 Scuttler: the last dodge press (WildboundDodgeService writes WildboundDash on the server, the same
	-- GetServerTimeNow clock as the encounter) and a server-side roll for the feint.
	function w.lastDash()
		local at = player:GetAttribute("WildboundDash")
		return Config.finite(at) and at or nil
	end
	function w.random() return rng:NextNumber() end
	return w
end

local function start(player, reservation, at)
	local character, _, root = bodyOf(player)
	local beast = reservation.beast
	if not (Config.PLAYABLE[beast] or Config.SUMMONED[beast]) or not Enc.registered(beast) then
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
	publishBoss()
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
	local target = { x = p.X, y = p.Y, z = p.Z, vx = v.X, vz = v.Z, alive = true, safe = safe, meadow = inMeadow(p.X, p.Z) }
	if Config.SUMMONED[entry.e.beast] then
		-- Kids biome: what the Nube sees (open sky, Night range) and what the Abeja hears (the server's speed and floor).
		local night = phaseAt(p.X, p.Z) == "Night"
		target.night = night
		target.covered = covered(p + Vector3.new(0, 1.5, 0))
		target.noise = Sites.noiseRadius(Vector3.new(v.X, 0, v.Z).Magnitude, humanoid.FloorMaterial == Enum.Material.Air, night)
		target.eventOpen = eventOpen()
		target.markedUntil = humanoid:GetAttribute("WildboundKidsMarkUntil")
		target.stickyUntil = humanoid:GetAttribute("WildboundKidsStickyUntil")
	end
	if entry.e.beast == "Scuttler" then
		-- SC7: the egg in the arms (the inventory server's own child) caps the feints and lets a pressured pulse drop it;
		-- the player's own Silueta hunting makes Scuttler yield (plan section 7 rule 6).
		target.carryingEgg = character:FindFirstChild("WildboundEggCarried") ~= nil
		target.siluetaActive = siluetaActive(entry.player.UserId)
	end
	if entry.e.beast == "DonGlaseon" then
		-- CA3: an egg on the back drops through BeastHit; its tier (EggRarity) sharpens the boss's eyes.
		local egg = character:FindFirstChild("WildboundEggCarried")
		target.carryingEgg = egg ~= nil
		target.eggRarity = egg and egg:GetAttribute("EggRarity") or nil
	end
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

-- Kids biome: La Abeja's Pegajoso. The walk speed is set to `speed` for at most 6 s: never lower than 9, never raised
-- (a slower player keeps their speed). It never stacks with Root's slow (the same WildboundBeastSlowUntil) and is put
-- back only if nothing changed the speed meanwhile. WildboundKidsStickyUntil tells the Abeja a second sting knocks.
local STICKY_FLOOR, STICKY_CAP = 9, 6
local function applySticky(player, speed, seconds)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not Config.finite(speed) or not Config.finite(seconds) then return end
	speed, seconds = math.max(speed, STICKY_FLOOR), math.clamp(seconds, 0, STICKY_CAP)
	humanoid:SetAttribute("WildboundKidsStickyUntil", now() + seconds)
	local untilAt = humanoid:GetAttribute("WildboundBeastSlowUntil")
	if type(untilAt) == "number" and untilAt > now() then return end
	local before = humanoid.WalkSpeed
	if before <= speed then return end
	humanoid.WalkSpeed = speed
	humanoid:SetAttribute("WildboundBeastSlowUntil", now() + seconds)
	task.delay(seconds, function()
		if humanoid.Parent and math.abs(humanoid.WalkSpeed - speed) < 1e-3 then humanoid.WalkSpeed = before end
	end)
end

-- SC7: Scuttler's landed pulse (Attack.afflict). Only the slow, clamped and never stacked by applySlow; the shake rides
-- on the event to the target's client. Never BeastHit: no damage and no egg drop.
local function afflict(entry, event)
	count("afflicted")
	applySlow(entry.player, event.slow, event.slowSeconds)
end

-- Caramelo biome: Gomibu's push. The target is moved 'studs' away over 'seconds' by a short-lived LinearVelocity on the
-- character's root (flat: it never lifts), which the owning client simulates. One push at a time; clamped.
local function applyPush(player, dx, dz, studs, seconds)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not Config.finite(studs) or not Config.finite(seconds) then return end
	local ux, uz = Config.unit(dx, dz)
	if not ux or root:FindFirstChild("WildboundBeastPush") then return end
	studs, seconds = math.clamp(studs, 0, 12), math.clamp(seconds, 0.1, 1)
	local attachment = Instance.new("Attachment")
	attachment.Name = "WildboundBeastPush"
	attachment.Parent = root
	local push = Instance.new("LinearVelocity")
	push.Attachment0 = attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	push.PrimaryTangentAxis, push.SecondaryTangentAxis = Vector3.xAxis, Vector3.zAxis
	push.PlaneVelocity = Vector2.new(ux, uz) * (studs / seconds)
	push.MaxForce = 1e5
	push.Parent = attachment
	task.delay(seconds, function() attachment:Destroy() end)
end

local beastHit = nil
local function landHit(entry, event)
	count("hits")
	beastHit = beastHit or network:FindFirstChild("BeastHit")
	local ok, effect = false, nil
	-- Kids rule (defence in depth): a summoned beast, or any hit on a target in the Pradera, never deals damage.
	local _, _, body = bodyOf(entry.player)
	if Config.SUMMONED[entry.e.beast] or (body and inMeadow(body.Position.X, body.Position.Z)) then event.damage = 0 end
	-- Caramelo biome: a keepsEgg beast (Gomibu) never reaches BeastHit: no damage, and the carried egg stays.
	local kept = Config.BEASTS[entry.e.beast]
	if kept and kept.keepsEgg == true then
		ok = true
	elseif beastHit and beastHit:IsA("BindableFunction") then
		ok, effect = pcall(function() return beastHit:Invoke(entry.player, entry.e.beast, event.damage) end)
	end
	if not ok then telemetry:SetAttribute("Beast_hitFailed", (telemetry:GetAttribute("Beast_hitFailed") or 0) + 1) end
	event.eggDropped = ok and type(effect) == "table" and effect.eggDropped == true or nil
	-- Wave 2 extras: Root's slow is applied here; Streamer's light push (event.knock) rides on the Hit event to the
	-- target's client, which owns its character's physics and clamps it.
	if type(event.slow) == "table" then applySlow(entry.player, event.slow.multiplier, event.slow.seconds) end
	if type(event.push) == "table" then applyPush(entry.player, event.push.dx, event.push.dz, event.push.studs, event.push.seconds) end
	-- Kids biome: the Nube's mark and the Abeja's Pegajoso; their knocks ride on the Hit event like Streamer's push.
	if type(event.sticky) == "table" then applySticky(entry.player, event.sticky.walkSpeed, event.sticky.seconds) end
	local humanoid = entry.player.Character and entry.player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and Config.finite(event.mark) then
		humanoid:SetAttribute("WildboundKidsMarkUntil", now() + math.clamp(event.mark, 0, 30))
	end
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
	local target = targetOf(entry)
	-- Kids biome: the Pradera has no forest beasts. A non-summoned encounter whose target walks in ends at once.
	if target and target.meadow and not Config.SUMMONED[entry.e.beast] then
		close(id, "Pradera", at)
		return
	end
	local events = Enc.step(entry.e, at, target, entry.world or world)
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
			if event.type == "Afflict" then afflict(entry, event) end
			logEvent(id, event.type, event.at, event.reason or event.hit)
			send(entry.player, event)
			sendBystanders(id, event)
		end
	end
end

local function snapshot(entry, at)
	local e = entry.e
	local snap = { type = "Snap", id = e.id, at = at, phase = e.phase, x = e.pos.x, y = e.pos.y, z = e.pos.z,
		dx = e.dx, dz = e.dz, center = e.beast == "Pouncer" and e.phase == "Telegraph" and not e.frozen and e.center or nil }
	send(entry.player, snap)
	-- SC0: bystanders get the same snapshot at SNAP_SECONDS (5 Hz) instead of 10 Hz.
	local copy
	for _, userId in ipairs(Audience.recipients(audience, e.id)) do
		if Audience.snapDue(audience, e.id, userId, at, AUDIENCE.SNAP_SECONDS) then
			local viewer = Players:GetPlayerByUserId(userId)
			copy = copy or Audience.forBystander(snap)
			if viewer and copy then send(viewer, copy) end
		end
	end
end

-- SC0: re-evaluates who sees which encounter from the server's own positions. An entering player gets a spawn
-- snapshot (the beast where it is now, in its phase) and a replay of its live tells, lane, circle and move; a leaving
-- one an End, so its client drops the view. A viewer in a safe zone sees no beast, one in the Pradera only the summoned
-- kids beasts (the forest beasts never exist there). Membership is committed only once the spawn was sent.
local function refreshAudience(at)
	local encounters, viewers = {}, {}
	for id, entry in pairs(live) do
		local e = entry.e
		table.insert(encounters, { id = id, beast = e.beast, x = e.pos.x, z = e.pos.z, target = entry.player.UserId,
			summoned = Config.SUMMONED[e.beast] == true })
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local character, humanoid, root = bodyOf(player)
		if character and humanoid.Health > 0 then
			local p = root.Position
			local _, safe = Rules.zone(p.X, p.Z)
			table.insert(viewers, { userId = player.UserId, x = p.X, z = p.Z, safe = safe, meadow = inMeadow(p.X, p.Z) })
		end
	end
	local _, leaves = Audience.refresh(audience, encounters, viewers, AUDIENCE, function(item)
		local viewer, entry = Players:GetPlayerByUserId(item.userId), live[item.id]
		if not viewer or not entry then return false end
		send(viewer, Audience.spawnFor(entry.e, at))
		for _, event in ipairs(Audience.replay(audience, item.id, at)) do send(viewer, event) end
		return true
	end)
	for _, item in ipairs(leaves) do
		local viewer = Players:GetPlayerByUserId(item.userId)
		if viewer then send(viewer, Audience.leaveFor(item.id, at)) end
	end
end

-- Kids biome: presence instead of chance. Each poll, a player in the Pradera near the pond (or near La Colmena while
-- the event window is open) summons that beast through the director (Director.summon: points 0, its own rules).
local function summonPass(player, at)
	local character, humanoid, root = bodyOf(player)
	if not character or humanoid.Health <= 0 then return end
	local p = root.Position
	if not inMeadow(p.X, p.Z) then return end
	local _, safe = Rules.zone(p.X, p.Z)
	local want = { alive = true, safe = safe, meadow = true, night = phaseAt(p.X, p.Z) == "Night", eventOpen = eventOpen(),
		x = p.X, z = p.Z, origin = praderaOrigin() }
	local ctx
	for _, kid in ipairs(KIDS) do
		if not kid.boss and Sites.wants(kid.name, want) then
			ctx = ctx or contextFor(player, at)
			local ok, value = Director.summon(director, player.UserId, kid.name, ctx, at)
			if ok then safeStart(player, value, at) end
		end
	end
end

-- Caramelo biome (CA3): Don Glaseon is one per server. Each poll it may wake for one player in its territory
-- (Sites.bossPick: a rare-egg carrier first, then the nearest to its home); the director refuses while it lives or
-- rests (BossBusy, BossResting). Beast_bossAwake tells WildboundCandyDonGlaseonService to hide the sleeping model.
local function bossPass(at)
	local candidates = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character, humanoid, root = bodyOf(player)
		if character and humanoid.Health > 0 and inMeadow(root.Position.X, root.Position.Z) then
			local p = root.Position
			local _, safe = Rules.zone(p.X, p.Z)
			local egg = character:FindFirstChild("WildboundEggCarried")
			table.insert(candidates, { userId = player.UserId, player = player, ctx = { alive = true, safe = safe, meadow = true,
				x = p.X, z = p.Z, origin = praderaOrigin(), rarity = egg and egg:GetAttribute("EggRarity") or nil } })
		end
	end
	local pick = Sites.bossPick(candidates)
	for _, c in ipairs(candidates) do
		if c.userId == pick then
			local ok, value = Director.summon(director, pick, "DonGlaseon", contextFor(c.player, at), at)
			if ok then safeStart(c.player, value, at) end
		end
	end
end

local stepClock, snapClock, pollClock, audienceClock = 0, 0, 0, 0
RunService.Heartbeat:Connect(function(dt)
	stepClock += dt
	snapClock += dt
	pollClock += dt
	audienceClock += dt
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
		publishBoss()
	end
	if audienceClock >= AUDIENCE.REFRESH_SECONDS then
		audienceClock = 0
		local ok, message = pcall(refreshAudience, now())
		if not ok then warn("Wildbound beasts: audience refresh error: " .. tostring(message)) end
	end
	-- Wave 2: the director's calendar decides which beasts roll (20 s each, 1 s apart); this only asks it often enough.
	if pollClock >= D.POLL_SECONDS then
		pollClock = 0
		local at = now()
		for _, player in ipairs(Players:GetPlayers()) do
			-- The context is read only when a slot is due (Director.tick = Director.due + Director.roll).
			local due = Director.due(director, player.UserId, at)
			local started, refused = {}, {}
			-- A developer inside the training yard (PatioEntrenamiento sets PatioDentro) gets no random beast: the yard is far
			-- outside every safe zone, so the calendar would otherwise roll on them and use the budget they test with.
			if #due > 0 and player:GetAttribute("PatioDentro") ~= true then started, refused = Director.roll(director, player.UserId, contextFor(player, at), at, due) end
			for _, reservation in ipairs(started) do safeStart(player, reservation, at) end
			for _, refusal in ipairs(refused) do
				count("refused")
				telemetry:SetAttribute("Beast_lastRefusal", refusal.beast .. ":" .. refusal.reason)
			end
			summonPass(player, at)
		end
		local okBoss, bossError = pcall(bossPass, at)
		if not okBoss then warn("Wildbound beasts: boss pass error: " .. tostring(bossError)) end
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
			local ending = Enc.finish(entry.e, "Leave", at)
			Attack.closeAll(entry.e, nil)
			logEvent(id, "End", at, "Leave")
			-- SC0: the leaving target's beasts end for their bystanders too.
			if ending then sendBystanders(id, ending) end
			Audience.close(audience, id)
		end
	end
	Audience.forgetViewer(audience, player.UserId)
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
	-- Kids biome: open (true), close (false) or release (nil) a local Abeja window for the Play check.
	local abeja = Instance.new("BindableFunction")
	abeja.Name = "ForceAbejaEvent"
	abeja.OnInvoke = function(open)
		if open == true or open == false then abejaOverride = open else abejaOverride = nil end
		return eventOpen()
	end
	abeja.Parent = telemetry
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

-- Patio de entrenamiento (developer training yard, ServerScriptService/PatioEntrenamiento). Server only (ServerStorage,
-- never a remote) and only for a player the yard marked as inside (PatioDentro): "poner" asks for one beast through
-- the director's own reservation (timers skipped, budget and every other rule kept); "quitar" ends that player's
-- encounters. Unlike the Studio tool above it also exists on a live server; the yard itself only admits developers.
do
	local patio = Instance.new("BindableFunction")
	patio.Name = "PatioBestia"
	patio.OnInvoke = function(op, player, name)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then return false, "BadArguments" end
		if player:GetAttribute("PatioDentro") ~= true then return false, "NotInYard" end
		local at = now()
		if op == "poner" then
			if type(name) ~= "string" then return false, "BadArguments" end
			local ok, value = Director.reserve(director, player.UserId, name, contextFor(player, at), at, { force = true })
			if not ok then
				telemetry:SetAttribute("Beast_lastRefusal", name .. ":" .. tostring(value))
				return false, value
			end
			return safeStart(player, value, at)
		elseif op == "quitar" then
			local ended = 0
			local ids = {}
			for id, entry in pairs(live) do
				if entry.player == player then table.insert(ids, id) end
			end
			for _, id in ipairs(ids) do
				close(id, "Patio", at)
				ended += 1
			end
			return true, ended
		end
		return false, "BadOperation"
	end
	patio.Parent = telemetry
end

-- Caramelo (owner request 2026-11-16, "bichos voladores que te persiguen"): runs WildboundCandyFlyers, the Zumbidulces.
-- Standalone (not an encounter of the beasts' script, like Frutillon). It waits for the built biome root
-- (Workspace.Candy_Bioma_v1, present in big4 and in classic), takes the plot's centre and floor from its Ground.Floor
-- (Layout.CENTRE / FLOOR_TOP without it), places the hives with F.hives (never in a safe zone: Rules.zone), casts one
-- floor ray per hive at start (none afterwards) and builds every bug at runtime from 7 plain parts (a striped candy body,
-- head, stinger and two wings; no asset). The body is anchored and moved by CFrame on a throttled step (F.STEP_SECONDS);
-- the other parts are welded, massless and never collide, touch or get queried. Each bug model carries At / Vel / Phase
-- attributes for WildboundCandyFlyersClient (smoothing, wing flaps, the shake and the buzz).
-- A dive's tell registers with WildboundDodgeService (source F.DODGE_SOURCE), a perfect press is resolved before the
-- sting, a miss or a give-up cancels it. A sting goes through the beasts' BeastHit (ReplicatedStorage.WildboundNetwork,
-- server to server) with keepEgg true: health only drops where the place's damage switch allows it and the carried egg
-- always stays; then the beasts' one push slot (WildboundBeastPush). While a swarm is on a player the beasts'
-- WildboundBeastEngagedAt stamp is written, so the return portal sees the chase. Everything is removed when the script
-- stops or the server closes; nothing is kept per player past PlayerRemoving.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local F = require(ServerStorage:WaitForChild("WildboundCandyFlyers"))
local Layout = require(ServerStorage:WaitForChild("WildboundCandyLayout"))
-- CL-D15 (Caramelo v9): the chocolate (V3.liquidDistance) keeps the hives off the river, the lake and the basins
local V3 = require(ServerStorage:WaitForChild("WildboundCandyV3Layout"))
local Rules = require(ServerScriptService:WaitForChild("WildboundWorldRules"))
local DodgeService = require(ServerScriptService:WaitForChild("WildboundDodgeService"))
-- RC4 (relentless chases): the strike ledger shared with the candy beasts (one module instance in this server)
local Smarts = require(ServerScriptService:WaitForChild("WildboundCandySmarts"))
local network = ReplicatedStorage:WaitForChild("WildboundNetwork", 15)

-- An older WildboundDodge without the Zumbidulce row still gets a dodgeable dive (same window, another label).
local SOURCE = DodgeService.Dodge.SOURCES[F.DODGE_SOURCE] and F.DODGE_SOURCE or "Pouncer"
local NOTE_EVERY = 6 -- seconds between two notices to one player
local IDLE_EVERY = 3 -- an idle swarm's parts move every third step (the client smooths)
local COLORS = {
	body = Color3.fromRGB(255, 120, 185), stripe = Color3.fromRGB(255, 250, 245), head = Color3.fromRGB(110, 62, 40),
	stinger = Color3.fromRGB(255, 205, 70), wing = Color3.fromRGB(205, 240, 255), glow = Color3.fromRGB(255, 70, 150),
	hive = Color3.fromRGB(250, 196, 92), marker = Color3.fromRGB(255, 60, 140),
}

local function now() return workspace:GetServerTimeNow() end

local biome = workspace:WaitForChild(Layout.ROOT_NAME, 60)
if not biome then
	warn("WildboundCandyFlyersService: no Workspace." .. Layout.ROOT_NAME .. "; no Zumbidulces.")
	return
end
local ground = biome:FindFirstChild("Ground")
local floorPart = ground and ground:FindFirstChild("Floor")
local centre, floorTop = { x = Layout.CENTRE.x, z = Layout.CENTRE.z }, Layout.FLOOR_TOP
-- CL-D15 (Caramelo v9): the floor grew 600 studs east only, so the plot centre is HALF east of the floor's west edge
-- (972 - 560 + 260 = 672 on the grown floor; the v8 square floor gives 672 too), as WildboundCandyLife.plotFrame.
if floorPart and floorPart:IsA("BasePart") then
	centre = { x = floorPart.Position.X - floorPart.Size.X / 2 + Layout.HALF, z = floorPart.Position.Z }
	floorTop = floorPart.Position.Y + floorPart.Size.Y / 2
end
-- CL-D15: the biome's rectangle, local x -HALF..EAST and z -HALF..HALF: { x = 972, z = -3, half = 260, halfX = 560 }
local east = Layout.EAST or Layout.HALF
local bounds = { x = centre.x + (east - Layout.HALF) / 2, z = centre.z, half = Layout.HALF, halfX = (Layout.HALF + east) / 2 }

local function safeAt(x, z)
	local _, safe = Rules.zone(x, z)
	return safe == true
end

-- Studio run 2026-11-16: no hive on a candy creature's post. The posts (WildboundPraderaSites.FIXED, world coordinates,
-- every "candy..." key) are read from the deployed module when it is there, as the Builder's treeKeepOut does; without
-- it the hives are placed as before.
local function creaturePosts()
	local list = {}
	local module = ServerScriptService:FindFirstChild("WildboundPraderaSites")
	if not (module and module:IsA("ModuleScript") and ReplicatedStorage:FindFirstChild("WildboundBeastConfig")) then return list end
	local ok, Sites = pcall(require, module)
	if not ok or type(Sites) ~= "table" or type(Sites.FIXED) ~= "table" then return list end
	for key, p in pairs(Sites.FIXED) do
		if type(key) == "string" and string.sub(key, 1, 5) == "candy" and type(p) == "table" then
			table.insert(list, { x = p.x, z = p.z })
		end
	end
	return list
end
local hives = F.hives(Layout, centre, { floorTop = floorTop, safe = safeAt, posts = creaturePosts(),
	liquid = V3.liquidDistance })
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { ground or biome }
for _, h in ipairs(hives) do -- the floor under each hive, once
	local hit = workspace:Raycast(Vector3.new(h.x, floorTop + 200, h.z), Vector3.new(0, -400, 0), params)
	h.floor = hit and hit.Position.Y or floorTop
end
local world = F.new(hives, now(), bounds, F.noGoZones(Layout, centre))

local folder = Instance.new("Folder")
folder.Name = "WildboundCandyFlyers"
local function part(parent, name, shape, size, color)
	local p = Instance.new("Part")
	p.Name, p.Shape, p.Size, p.Color = name, shape, size, color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow, p.Massless = false, false, false, false, true
	p.Parent = parent
	return p
end

-- One bug: 7 parts. The body (an ellipsoid: a block with a sphere mesh) is the anchored root; forward is -Z.
local function buildBug(parent, index)
	local model = Instance.new("Model")
	model.Name = "Bug_" .. index
	local body = part(model, "Body", Enum.PartType.Block, Vector3.new(1.3, 1.2, 2), COLORS.body)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = body
	model.PrimaryPart = body
	local function piece(name, shape, size, color, offset)
		local p = part(model, name, shape, size, color)
		p.Anchored = false
		local weld = Instance.new("Weld")
		weld.Name = "Weld_" .. name
		weld.Part0, weld.Part1, weld.C0 = body, p, offset
		weld.Parent = body
		return p
	end
	piece("Stripe_1", Enum.PartType.Cylinder, Vector3.new(0.22, 1.28, 1.28), COLORS.stripe, CFrame.new(0, 0, 0.35) * CFrame.Angles(0, math.rad(90), 0))
	piece("Stripe_2", Enum.PartType.Cylinder, Vector3.new(0.22, 1.24, 1.24), COLORS.stripe, CFrame.new(0, 0, -0.3) * CFrame.Angles(0, math.rad(90), 0))
	piece("Head", Enum.PartType.Ball, Vector3.new(0.9, 0.9, 0.9), COLORS.head, CFrame.new(0, 0.1, -1.15))
	piece("Stinger", Enum.PartType.Cylinder, Vector3.new(0.6, 0.22, 0.22), COLORS.stinger, CFrame.new(0, -0.05, 1.2) * CFrame.Angles(0, math.rad(90), 0))
	local wingL = piece("WingL", Enum.PartType.Block, Vector3.new(1.4, 0.08, 0.9), COLORS.wing, CFrame.new(-0.85, 0.55, 0))
	local wingR = piece("WingR", Enum.PartType.Block, Vector3.new(1.4, 0.08, 0.9), COLORS.wing, CFrame.new(0.85, 0.55, 0))
	for _, wing in ipairs({ wingL, wingR }) do wing.Material, wing.Transparency = Enum.Material.Glass, 0.35 end
	model:SetAttribute("Phase", "Idle")
	model.Parent = parent
	return { model = model, body = body, look = Vector3.new(0, 0, -1), glow = false }
end

local visuals = {} -- [swarm] = { model, bugs = { [index] = visual }, markers = { [bugIndex] = Part } }
for _, swarm in ipairs(world.swarms) do
	local model = Instance.new("Model")
	model.Name = "Hive_" .. swarm.id
	model:SetAttribute("Phase", swarm.phase)
	local hive = part(model, "Panal", Enum.PartType.Block, Vector3.new(3, 3.6, 3), COLORS.hive)
	local hiveMesh = Instance.new("SpecialMesh")
	hiveMesh.MeshType = Enum.MeshType.Sphere
	hiveMesh.Parent = hive
	hive.CFrame = CFrame.new(swarm.hive.x, swarm.hive.floor + 1.8, swarm.hive.z)
	local v = { model = model, bugs = {}, markers = {} }
	for _, bug in ipairs(swarm.bugs) do v.bugs[bug.index] = buildBug(model, bug.index) end
	model.Parent = folder
	visuals[swarm] = v
end
folder.Parent = workspace

local telemetry = ServerStorage:FindFirstChild("WildboundTelemetry")
local function count(key, add)
	telemetry = telemetry or ServerStorage:FindFirstChild("WildboundTelemetry")
	if telemetry then telemetry:SetAttribute(key, (telemetry:GetAttribute(key) or 0) + (add or 1)) end
end
if telemetry then
	telemetry:SetAttribute("Flyers_hives", #world.swarms)
	telemetry:SetAttribute("Flyers_bugs", world.bugs)
end

local function place(swarm, bug, visual)
	local at = Vector3.new(bug.x, bug.y, bug.z)
	local vel = Vector3.new(bug.vx or 0, bug.vy or 0, bug.vz or 0)
	local flatVel = Vector3.new(vel.X, 0, vel.Z)
	if flatVel.Magnitude > 0.5 then visual.look = flatVel.Unit end
	visual.body.CFrame = CFrame.lookAt(at, at + visual.look)
	visual.model:SetAttribute("At", at)
	visual.model:SetAttribute("Vel", vel)
	if visual.model:GetAttribute("Phase") ~= bug.phase then visual.model:SetAttribute("Phase", bug.phase) end
	local glow = swarm.phase == "Alert" or bug.phase == "Aim"
	if glow ~= visual.glow then
		visual.glow = glow
		visual.body.Material = glow and Enum.Material.Neon or Enum.Material.SmoothPlastic
		visual.body.Color = glow and COLORS.glow or COLORS.body
	end
end

local function marker(v, bugIndex, x, y, z)
	local m = v.markers[bugIndex]
	if not m then
		m = part(v.model, "DiveMarker_" .. bugIndex, Enum.PartType.Cylinder, Vector3.new(0.12, F.HIT_STUDS * 2, F.HIT_STUDS * 2), COLORS.marker)
		m.Material, m.Transparency = Enum.Material.Neon, 0.35
		v.markers[bugIndex] = m
	end
	m.CFrame = CFrame.new(x, y + 0.08, z) * CFrame.Angles(0, 0, math.rad(90))
end
local function unmark(v, bugIndex)
	if v.markers[bugIndex] then v.markers[bugIndex]:Destroy() v.markers[bugIndex] = nil end
end

local noted = {} -- [Player] = the last notice time
local function note(player, text)
	if not player or (noted[player] and now() - noted[player] < NOTE_EVERY) then return end
	noted[player] = now()
	player:SetAttribute("WildboundCandyFlyersNote", text)
	player:SetAttribute("WildboundCandyFlyersNoteAt", noted[player])
end

-- The beasts' push: one at a time (WildboundBeastPush), flat, clamped like theirs.
local function push(player, dx, dz, studs, seconds)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or root:FindFirstChild("WildboundBeastPush") then return end
	studs, seconds = math.clamp(studs, 0, 12), math.clamp(seconds, 0.1, 1)
	local attachment = Instance.new("Attachment")
	attachment.Name = "WildboundBeastPush"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis, velocity.SecondaryTangentAxis = Vector3.xAxis, Vector3.zAxis
	velocity.PlaneVelocity = Vector2.new(dx, dz) * (studs / seconds)
	velocity.MaxForce = 1e5
	velocity.Parent = attachment
	task.delay(seconds, function() attachment:Destroy() end)
end

-- A sting: the damage gate is the beasts' BeastHit (private damage mode only; the egg kept), then the push.
local beastHit = nil
local function sting(player, e)
	beastHit = beastHit or (network and network:FindFirstChild("BeastHit"))
	local ok, effect = false, nil
	if beastHit and beastHit:IsA("BindableFunction") then
		ok, effect = pcall(function() return beastHit:Invoke(player, F.BEAST_NAME, e.damage, F.KEEPS_EGG) end)
	end
	if not ok then count("Flyers_hitFailed") end
	if type(effect) == "table" and effect.dodged == true then return end
	push(player, e.dx, e.dz, e.studs, e.seconds)
	count("Flyers_stings")
end

local hooks = {
	resolve = function(id, key, at)
		local player = Players:GetPlayerByUserId(id)
		if not player then return "Unknown" end
		return DodgeService.resolve(player, key, at)
	end,
	-- RC4: a dive books its strike with the candy beasts' strikes; at most Smarts.STRIKE_MAX land within
	-- Smarts.STRIKE_WINDOW on one player, a refused dive waits for a later step
	claim = function(id, swarmId, strikeAt, at)
		return Smarts.claimStrike(id, "flyers:" .. tostring(swarmId), strikeAt, at)
	end,
}

local function play(events)
	for _, e in ipairs(events) do
		local player = e.id and Players:GetPlayerByUserId(e.id)
		local swarm
		for _, s in ipairs(world.swarms) do if s.id == e.swarm then swarm = s break end end
		local v = swarm and visuals[swarm]
		if e.kind == "Wake" then
			note(player, F.TEXT.wake)
			count("Flyers_wakes")
		elseif e.kind == "DiveTell" then
			if player then DodgeService.telegraph(player, e.key, SOURCE, e.startAt, e.strikeAt) end
			if v then marker(v, e.bug, e.x, e.y, e.z) end
		elseif e.kind == "Dive" then
			if v then marker(v, e.bug, e.x, e.y - F.ROOT_HEIGHT_STUDS, e.z) end
		elseif e.kind == "Hit" then
			if v then unmark(v, e.bug) end
			if player then task.spawn(sting, player, e) end -- review F-4: a yielding BeastHit never stalls the step
		elseif e.kind == "Miss" or e.kind == "DiveCancel" then
			if v then unmark(v, e.bug) end
			if player then DodgeService.cancel(player, e.key) end
		elseif e.kind == "Dodged" then
			if v then unmark(v, e.bug) end
			count("Flyers_dodged")
		elseif e.kind == "GiveUp" then
			if e.vanish then count("Flyers_vanished") end -- RC3: far from the hive they vanish (the client fades them)
			if player and e.reason ~= "Death" and e.reason ~= "Gone" then
				noted[player] = nil
				note(player, F.TEXT.home)
			end
			count("Flyers_giveUp_" .. tostring(e.reason))
		end
	end
end

local grounded = {} -- [Player] = the root's last height while standing on something (review F-7)
-- V6-D1 (Caramelo v6): the tall licorice grass. The patches (WildboundCandyGrass's tagged models) are read every 5 s;
-- whether a player stands in one and is not sprinting is worked out here from the server's positions.
local Hiding = require(ServerScriptService:WaitForChild("WildboundCandyHiding"))
local grass = { patches = {}, at = -math.huge }
local function grassCover(player, x, z)
	local t = now()
	if t - grass.at >= 5 or t < grass.at then
		grass.at = t
		grass.patches = Hiding.grassPatches(game:GetService("CollectionService"):GetTagged(Hiding.GRASS.tag))
	end
	return Hiding.covered(Hiding.inGrass(grass.patches, x, z), player:GetAttribute("WildboundStance"))
end
local function sample()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and humanoid then
			local p, v = root.Position, root.AssemblyLinearVelocity
			local g = grounded[player]
			if not g or g.character ~= character or humanoid.FloorMaterial ~= Enum.Material.Air then
				g = { character = character, y = p.Y }
				grounded[player] = g
			end
			-- V4-D14: in a house (the footprint discs), wading in the chocolate (WildboundCandyWadeService's factor under 1),
			-- and whether an egg rides on the player's back (the inventory server's WildboundEggCarried model)
			local wade = tonumber(player:GetAttribute("WildboundCandyWade"))
			table.insert(list, { id = player.UserId, alive = humanoid.Health > 0, x = p.X, y = p.Y, z = p.Z, vx = v.X, vz = v.Z,
				groundY = g.y, safe = safeAt(p.X, p.Z), sheltered = Smarts.inHouse(p.X, p.Z, world.houses) ~= nil,
				wading = wade ~= nil and wade < 1, carryingEgg = character:FindFirstChild("WildboundEggCarried") ~= nil,
				-- V5-D2: hidden in a hide spot (WildboundWorld's attribute): like a house for the bees
				hidden = player:GetAttribute("WildboundHidden") ~= nil,
				-- V6-D1: in the licorice grass and not sprinting
				grassCover = grassCover(player, p.X, p.Z) })
		end
	end
	return list
end

-- Review F-1: a calm swarm's parts replicate only while someone is within WATCH_STUDS of its hive.
local WATCH_STUDS = 150
local function watched(swarm, players)
	for _, p in ipairs(players) do
		if (p.x - swarm.hive.x) ^ 2 + (p.z - swarm.hive.z) ^ 2 <= WATCH_STUDS * WATCH_STUDS then return true end
	end
	return false
end

local clock, ticks, failed = 0, 0, false
local connection
connection = RunService.Heartbeat:Connect(function(dt)
	clock += dt
	if clock < F.STEP_SECONDS then return end
	clock = math.min(clock - F.STEP_SECONDS, F.MAX_DT) -- review F-3: keep the remainder, a real 12 Hz
	ticks += 1
	local at = now()
	local ok, message = pcall(function()
		-- V4-D12 / V4-D14: the houses' footprint discs, read again every 5 s (the bugs never enter them)
		if not world.housesAt or at - world.housesAt >= 5 or at < world.housesAt then
			world.housesAt, world.houses = at, Smarts.houseDiscs(biome)
		end
		local players = sample()
		play(F.step(world, at, players, hooks))
		for _, swarm in ipairs(world.swarms) do
			local v = visuals[swarm]
			local was = v.model:GetAttribute("Phase")
			if was ~= swarm.phase then v.model:SetAttribute("Phase", swarm.phase) end
			local calm = swarm.phase == "Idle" or swarm.phase == "Cooldown"
			-- Studio Play 2026-11-17: back from a vanish (RC3) the bugs are placed at the hive at once, watched or not;
			-- they stood where they vanished (by the base) until a player came near the hive again
			if not calm or was == "Vanish" or (ticks % IDLE_EVERY == 0 and watched(swarm, players)) then
				for _, bug in ipairs(swarm.bugs) do place(swarm, bug, v.bugs[bug.index]) end
			end
			for _, bug in ipairs(swarm.bugs) do
				if bug.phase == "Aim" and bug.markX then marker(v, bug.index, bug.markX, bug.markY or floorTop, bug.markZ) end
			end
			-- the return portal's calm check: a swarm on a player counts as a beast on them (at most twice a second)
			if (swarm.phase == "Alert" or swarm.phase == "Chase") and swarm.target then
				local target = Players:GetPlayerByUserId(swarm.target)
				local last = target and target:GetAttribute("WildboundBeastEngagedAt")
				if target and (type(last) ~= "number" or at - last >= 0.5) then target:SetAttribute("WildboundBeastEngagedAt", at) end
			end
		end
	end)
	if not ok and not failed then
		failed = true -- warn once; the next steps keep trying
		warn("WildboundCandyFlyersService: " .. tostring(message))
	end
end)

Players.PlayerRemoving:Connect(function(player)
	noted[player] = nil
	grounded[player] = nil
end)

local stopped = false
local function stop()
	if stopped then return end
	stopped = true
	if connection then connection:Disconnect() end
	folder:Destroy()
end
script.Destroying:Connect(stop)
game:BindToClose(stop)

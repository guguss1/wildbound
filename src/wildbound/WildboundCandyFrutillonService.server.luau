-- Caramelo v2 (odd/tasks/wildbound-caramelo-v2.md, CT4): runs WildboundCandyFrutillon on the Gran Torta's summit.
-- Builds Frutillon at runtime from plain parts (a red body squashed by a SpecialMesh sphere, a green leaf cap, yellow
-- seeds; no asset upload), anchored and never colliding: every bump is a scripted push in the beasts' slot
-- (WildboundBeastPush, so never two at once). Each STEP it reads the players' server-side roots, steps the rules, moves
-- the strawberry round its ring (rolling), draws the tell line along the arc it will roll, squashes it during the tell,
-- and moves the seeds down the stair. Knockback only: no damage, nothing about the egg.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Frut = require(ServerStorage:WaitForChild("WildboundCandyFrutillon"))
local Layout = require(ServerStorage:WaitForChild("WildboundCandyLayout"))

local STEP = 0.05
local RED, GREEN, SEED, LINE = Color3.fromRGB(224, 38, 60), Color3.fromRGB(88, 170, 70), Color3.fromRGB(251, 225, 94),
	Color3.fromRGB(255, 90, 90)
local summit = Frut.summit(Layout)
local path = Frut.seedPath(Layout)
local state = Frut.new(workspace:GetServerTimeNow(), summit)

local folder = Instance.new("Folder")
folder.Name = "WildboundCandyFrutillon"
local function part(parent, name, shape, size, color)
	local p = Instance.new("Part")
	p.Name, p.Shape, p.Size, p.Color = name, shape, size, color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, true
	p.Parent = parent
	return p
end

-- Frutillon: the body's centre is its pivot; the cap and the seeds hang off it.
local model = Instance.new("Model")
model.Name = "Frutillon"
local d = Frut.RADIUS_STUDS * 2
local body = part(model, "Body", Enum.PartType.Block, Vector3.new(d, d, d), RED)
local mesh = Instance.new("SpecialMesh")
mesh.MeshType = Enum.MeshType.Sphere
mesh.Parent = body
model.PrimaryPart = body
local cap = part(model, "LeafCap", Enum.PartType.Cylinder, Vector3.new(0.4, d * 0.7, d * 0.7), GREEN)
cap.CFrame = body.CFrame * CFrame.new(0, d / 2 - 0.1, 0) * CFrame.Angles(0, 0, math.rad(90))
local stem = part(model, "Stem", Enum.PartType.Cylinder, Vector3.new(0.8, 0.35, 0.35), GREEN)
stem.CFrame = body.CFrame * CFrame.new(0, d / 2 + 0.4, 0) * CFrame.Angles(0, 0, math.rad(90))
for i = 1, 8 do
	local a, h = i * math.pi / 4, (i % 2 == 0) and 0.4 or -0.5
	local dot = part(model, "Seed_" .. i, Enum.PartType.Ball, Vector3.new(0.35, 0.35, 0.35), SEED)
	dot.CFrame = body.CFrame * CFrame.new(math.cos(a) * (d / 2 - 0.05), h, math.sin(a) * (d / 2 - 0.05))
end
model:SetAttribute("BeastPhase", "Asleep")
model.Parent = folder
folder.Parent = workspace

local spin = 0 -- how far it has rolled, for the body's turn
local function place()
	local x, z = Frut.position(state, summit)
	local squash = state.phase == "Telegraph"
	mesh.Scale = squash and Vector3.new(1.15, 0.75, 1.15) or Vector3.new(1, 1, 1)
	local y = summit.top + Frut.RADIUS_STUDS * (squash and 0.75 or 1)
	local tangent = Vector3.new(-math.sin(state.angle), 0, math.cos(state.angle))
	local frame = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x, y, z) + tangent)
	model:PivotTo(frame * CFrame.Angles(-spin, 0, 0))
end

local line = nil
local function drawLine(fromAngle, toAngle)
	if line then line:Destroy() end
	line = Instance.new("Folder")
	line.Name = "TellLine"
	local pieces = 10
	for i = 1, pieces do
		local a0 = fromAngle + (toAngle - fromAngle) * (i - 1) / pieces
		local a1 = fromAngle + (toAngle - fromAngle) * i / pieces
		local p0 = Vector3.new(summit.x + math.cos(a0) * Frut.RING_STUDS, summit.top + 0.06, summit.z + math.sin(a0) * Frut.RING_STUDS)
		local p1 = Vector3.new(summit.x + math.cos(a1) * Frut.RING_STUDS, summit.top + 0.06, summit.z + math.sin(a1) * Frut.RING_STUDS)
		local piece = part(line, "Line_" .. i, Enum.PartType.Block, Vector3.new(1.2, 0.08, (p1 - p0).Magnitude + 0.1), LINE)
		piece.Material = Enum.Material.Neon
		piece.CastShadow = false
		piece.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
	end
	line.Parent = folder
end
local function clearLine()
	if line then line:Destroy() line = nil end
end

local function push(player, dx, dz, studs, seconds)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or root:FindFirstChild("WildboundBeastPush") then return end
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

local seeds = {} -- [id] = Part
local function play(events)
	for _, e in ipairs(events) do
		if e.kind == "Telegraph" then
			drawLine(e.fromAngle, e.toAngle)
		elseif e.kind == "Recover" or e.kind == "Sleep" then
			clearLine()
		elseif e.kind == "Hit" or e.kind == "SeedHit" or e.kind == "PatrolHit" or e.kind == "Slip" then
			local player = Players:GetPlayerByUserId(e.id)
			if player then push(player, e.dx, e.dz, e.studs, e.seconds) end
		elseif e.kind == "Seed" then
			local seed = part(folder, "FlyingSeed_" .. e.seed, Enum.PartType.Ball, Vector3.new(0.8, 0.8, 0.8), SEED)
			seed.Position = Vector3.new(path[1].x, path[1].y + 0.4, path[1].z)
			seeds[e.seed] = seed
		elseif e.kind == "SeedGone" then
			if seeds[e.seed] then seeds[e.seed]:Destroy() seeds[e.seed] = nil end
		end
	end
end

-- OF3 (owner feedback 3): the stair's sugar patrols (white drops, pink while they glow before setting off) and its glaze
-- steps (glossy pale patches), all anchored, never colliding, never queried.
local patrolParts = {}
for _, def in ipairs(Frut.patrols(path)) do
	local drop = part(folder, "StairPatrol_" .. def.id, Enum.PartType.Ball, Vector3.new(2.2, 1.6, 2.2), Color3.fromRGB(250, 246, 240))
	drop.Material = Enum.Material.Glass
	patrolParts[def.id] = drop
end
for _, i in ipairs(Frut.glazeSteps(path)) do
	local s = path[i]
	local patch = part(folder, "StairGlaze_" .. i, Enum.PartType.Cylinder, Vector3.new(0.08, 2.8, 2.8), Color3.fromRGB(214, 240, 255))
	patch.Material, patch.Transparency, patch.CastShadow = Enum.Material.Glass, 0.15, false
	patch.CFrame = CFrame.new(s.x, s.y + 0.05, s.z) * CFrame.Angles(0, 0, math.rad(90))
end
local function placePatrols(now)
	for _, def in ipairs(state.patrolDefs or Frut.patrols(path)) do
		local at, drop = Frut.patrolAt(def, now, path), patrolParts[def.id]
		if drop then
			drop.Position = Vector3.new(at.x, at.y, at.z)
			drop.Color = at.tell and Color3.fromRGB(255, 120, 190) or Color3.fromRGB(250, 246, 240)
		end
	end
end

place()
local clock, lastAngle = 0, state.angle
RunService.Heartbeat:Connect(function(dt)
	clock += dt
	if clock < STEP then return end
	clock = 0
	local now = workspace:GetServerTimeNow()
	local players = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and humanoid and humanoid.Health > 0 then
			table.insert(players, { id = player.UserId, alive = true, x = root.Position.X, y = root.Position.Y, z = root.Position.Z })
		end
	end
	play(Frut.step(state, now, players))
	play(Frut.seedStep(state, now, players, path, summit))
	play(Frut.patrolStep(state, now, players, path, summit)) -- OF3
	play(Frut.glazeStep(state, now, players, path, summit)) -- OF3
	placePatrols(now)
	local turned = (state.angle - lastAngle + math.pi) % (2 * math.pi) - math.pi
	if state.phase ~= "Asleep" then spin += math.abs(turned) * Frut.RING_STUDS / Frut.RADIUS_STUDS end
	lastAngle = state.angle
	model:SetAttribute("BeastPhase", state.phase)
	place()
	for _, seed in ipairs(state.seeds) do
		local at = Frut.seedAt(seed, now, path)
		if at and seeds[seed.id] then seeds[seed.id].Position = Vector3.new(at.x, at.y, at.z) end
	end
end)

-- Caramelo v8, V8-D3 (owner request 2026-11-17: "an invisible wall with a cloud texture that you can see through";
-- docs/design/wildbound-caramelo-v8-plan.md). Client-only look of the cloud wall between the Caramelo plot and Caramelo
-- Este (WildboundCandyEast): slow big pink-white puffs on Workspace.Candy_Este_v1.CloudWall.Veil, the band the player
-- sees through. The Veil never collides nor answers rays; the wall that stops players is its invisible Collider, and
-- creatures are held back by the server (WildboundCandySmarts.outsideWall). Nothing here touches gameplay.
--   puffs    ParticleEmitters made here (nothing replicates) on the Veil, with the built-in smoke texture (no upload);
--   budget   "Efectos suaves" (the world gui's Reduced, as WildboundCandyLife.client reads it) lowers the rate; far from
--            the wall the emitters stop;
--   stream   at 2 Hz (Heartbeat) the Veil is looked up again, so a Veil that streams out and back gets its puffs again;
--   cleanup  the emitters go when the script goes (script.Destroying);
--   faces    PG-D6 (docs/design/wildbound-pueblo-gatito-biome-plan.md; owner request 2026-11-18, "hacelo bioma aparte"):
--            the cloud has two faces. Seen from Caramelo (the camera west of the Veil) the puffs are pink and white; seen
--            from Pueblo Gatito (east of it) they are white and sky blue (the park's Atmosphere air, 199, 226, 245). The
--            side is read at the same 2 Hz step and the palette is set only when it changes. The Veil part is unchanged.
-- OQ1 (owner request 2026-11-19, "quiero que las nubes sean mas realistas, no una foto estirada"): the wall is a soft
-- volume, not a flat texture. The Veil itself is no longer drawn (WildboundCandyEast plans it fully transparent); this
-- client lays a bank of soft cloud puffs along the band (ellipsoid parts, mostly see-through, three overlapping layers
-- of varied sizes, each swaying slowly back and forth on an engine tween) and keeps the particles over them, fewer:
--   budget   puffs: floor(536 / PUFF_SPACING) = 24 columns x 3 layers = 72 parts on the 536-stud band, 36 with
--            "Efectos suaves", none (and no tweens running) farther than NEAR_STUDS; particles alive at full rate about
--            10 x 11.5 + 6 x 9 = 169 (was about 380), about 51 with "Efectos suaves";
--   puffs    made here only (never replicated) in Workspace.WildboundCloudWallPuffs: anchored, never collide, never in
--            rays, never touched, no shadow; the same wall every time (a fixed seed); they wear the PG-D6 faces too;
--            each puff stays inside the band's length (its end and its sway never pass the Veil's ends), and the three
--            layers overlap from the floor to near the top, so the wall reads as one cloud mass, not stripes.
--   faces    Deliberately changed (OQ1 review): the face follows the biome the camera is in (WildboundBiomeLight), not
--            the camera's side of the Veil. Pueblo Gatito moved to the south arm (PGM-D3), so east of the wall is only
--            Caramelo's closed tail, and the camera (which the invisible Collider never stops) slips past the wall when
--            a Caramelo player backs into it; the side rule then flipped the whole wall to the park's colours while the
--            player stood in pink Caramelo. Both palettes stay for when the park borders a wall again.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BiomeLight = require(ReplicatedStorage:WaitForChild("WildboundBiomeLight"))

local ROOT_NAME, FOLDER_NAME, VEIL_NAME = "Candy_Este_v1", "CloudWall", "Veil"
local TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local CHECK_SECONDS = 0.5
local NEAR_STUDS = 700 -- farther than this from the wall (flat) the puffs stop
local REDUCED_SHARE = 0.3 -- Efectos suaves: this share of the rate
-- Two layers of puffs: big slow pink ones and smaller white ones (rate per second at full budget).
-- PG-D6: colors is the Caramelo face; parkColors the Pueblo Gatito face (white and sky blue).
-- OQ1: the rates are lower (were 22 and 14): the puff parts below carry the cloud's body now.
local LAYERS = {
	{ name = "CloudPuffs", rate = 10, lifetime = { 9, 14 }, size = { 18, 30 }, speed = { 0.4, 1.4 },
		colors = { Color3.fromRGB(255, 214, 234), Color3.fromRGB(255, 240, 248) },
		parkColors = { Color3.fromRGB(240, 248, 255), Color3.fromRGB(199, 226, 245) }, transparency = 0.45 },
	{ name = "CloudWisps", rate = 6, lifetime = { 7, 11 }, size = { 10, 18 }, speed = { 0.6, 1.8 },
		colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 226, 240) },
		parkColors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(214, 236, 250) }, transparency = 0.55 },
}
-- OQ1: the puff bank. A column every PUFF_SPACING studs along the band; per column one puff per layer (height: share of
-- the wall's height; size: studs; transparency: never below 0.65, so the player still sees through the wall).
local PUFF_FOLDER = "WildboundCloudWallPuffs"
local PUFF_SEED = 1540
local PUFF_SPACING = 22
-- OQ1 review: the layers overlap (a typical puff on the 80-stud Veil spans about -2..26, 24..48 and 47..68, plus the
-- sway up; were about 0..26, 25..47 and 54..71, which left a gap near 50 and the wall read as stripes); taller puffs
-- (PUFF_SHAPE y 0.8, was 0.7).
local PUFF_TIERS = {
	{ height = 0.15, size = { 30, 40 }, transparency = 0.7 },
	{ height = 0.45, size = { 26, 36 }, transparency = 0.74 },
	{ height = 0.72, size = { 24, 30 }, transparency = 0.8 },
}
local PUFF_SHAPE = Vector3.new(0.8, 0.8, 1.3) -- across the band, up, along it: times the puff's size (a flat cloud)
local PUFF_JITTER = Vector3.new(3, 3, 0.3) -- across and up in studs; along the band as a share of the column
local PUFF_DRIFT_SECONDS = { 8, 14 } -- one sway, there or back
local PUFF_DRIFT_STUDS = Vector3.new(1.5, 3, 4) -- how far a puff sways (across, up, along)
-- PG-D6: the puffs' two faces (Caramelo: pink and white; Pueblo Gatito: white and sky blue)
local PUFF_COLORS = { Color3.fromRGB(255, 232, 242), Color3.fromRGB(255, 246, 250) }
local PUFF_PARK_COLORS = { Color3.fromRGB(246, 250, 255), Color3.fromRGB(214, 234, 250) }

local player = Players.LocalPlayer
local veil = nil
local emitters = {}
local puffs = {}
local tones = {} -- OQ1: each puff's colour of its face (1 or 2)
local tweens = {}
local puffFolder = nil
local shownKey = nil -- OQ1: the near/far and Efectos suaves state the puffs show (nil: not shown yet)
local connections = {}
local side = nil -- PG-D6: the face the emitters wear (true = Pueblo Gatito, false = Caramelo, nil = not painted yet)

local function worldGui()
	local gui = player:FindFirstChildOfClass("PlayerGui")
	return gui and gui:FindFirstChild("WildboundWorldUI")
end

local function teardown()
	for _, emitter in ipairs(emitters) do emitter:Destroy() end
	table.clear(emitters)
	for _, tween in ipairs(tweens) do tween:Cancel() end
	table.clear(tweens)
	for _, puff in ipairs(puffs) do puff:Destroy() end
	table.clear(puffs)
	table.clear(tones)
	if puffFolder then puffFolder:Destroy() end
	puffFolder = nil
	shownKey = nil
	veil = nil
	side = nil
end

-- PG-D6: every emitter wears the palette of the biome the camera is in (park: Pueblo Gatito, else Caramelo).
local function paint(park)
	for i, emitter in ipairs(emitters) do
		local colors = park and LAYERS[i].parkColors or LAYERS[i].colors
		emitter.Color = ColorSequence.new(colors[1], colors[2])
	end
	-- OQ1: the puffs too
	local tint = park and PUFF_PARK_COLORS or PUFF_COLORS
	for i, puff in ipairs(puffs) do puff.Color = tint[tones[i]] end
	side = park
end

local function newEmitter(layer, parent)
	local e = Instance.new("ParticleEmitter")
	e.Name = layer.name
	e.Texture = TEXTURE
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(layer.lifetime[1], layer.lifetime[2])
	e.Speed = NumberRange.new(layer.speed[1], layer.speed[2])
	e.Drag = 0.2
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-8, 8)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, layer.size[1] * 0.6),
		NumberSequenceKeypoint.new(0.5, layer.size[2]),
		NumberSequenceKeypoint.new(1, layer.size[2] * 1.1),
	})
	-- fades in and out, never opaque: the player sees through the band
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, layer.transparency),
		NumberSequenceKeypoint.new(0.75, layer.transparency),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Color = ColorSequence.new(layer.colors[1], layer.colors[2])
	e.LightEmission = 0.15
	e.LightInfluence = 0.6
	e.Rate = 0
	e.Parent = parent
	return e
end

-- OQ1: the puff bank along the band, in the Veil's own frame (x across, y up, z along). Puffs stay unparented (not
-- drawn) until show() puts them in the folder; each gets its slow sway tween, not yet playing.
local function buildPuffs(at)
	local rng = Random.new(PUFF_SEED)
	puffFolder = Instance.new("Folder")
	puffFolder.Name = PUFF_FOLDER
	local size = at.Size
	local columns = math.max(1, math.floor(size.Z / PUFF_SPACING))
	local step = size.Z / columns
	for column = 1, columns do
		for _, tier in ipairs(PUFF_TIERS) do
			local d = rng:NextNumber(tier.size[1], tier.size[2])
			local ox = rng:NextNumber(-1, 1) * PUFF_JITTER.X
			local oy = -size.Y / 2 + tier.height * size.Y + rng:NextNumber(-1, 1) * PUFF_JITTER.Y
			local oz = -size.Z / 2 + (column - 0.5 + rng:NextNumber(-1, 1) * PUFF_JITTER.Z) * step
			-- OQ1 review: the puff's whole length and its sway stay inside the band (the end columns' puffs reached
			-- about 25 studs past the Veil's ends, past the caps and over the space outside the wall)
			local halfLen = PUFF_SHAPE.Z * d / 2 + PUFF_DRIFT_STUDS.Z
			oz = math.clamp(oz, math.min(0, -size.Z / 2 + halfLen), math.max(0, size.Z / 2 - halfLen))
			local offset = Vector3.new(ox, oy, oz)
			local base = at.CFrame * CFrame.new(offset) * CFrame.Angles(0, rng:NextNumber(-0.35, 0.35), 0)
			local puff = Instance.new("Part")
			puff.Name = "Puff"
			puff.Anchored = true
			puff.CanCollide = false
			puff.CanQuery = false
			puff.CanTouch = false
			puff.CastShadow = false
			puff.Material = Enum.Material.SmoothPlastic
			puff.TopSurface, puff.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			puff.Size = PUFF_SHAPE * d
			puff.CFrame = base
			puff.Transparency = tier.transparency
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = puff
			local drift = Vector3.new(rng:NextNumber(-1, 1) * PUFF_DRIFT_STUDS.X, rng:NextNumber(0.5, 1) * PUFF_DRIFT_STUDS.Y,
				rng:NextNumber(-1, 1) * PUFF_DRIFT_STUDS.Z)
			local info = TweenInfo.new(rng:NextNumber(PUFF_DRIFT_SECONDS[1], PUFF_DRIFT_SECONDS[2]),
				Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
			table.insert(puffs, puff)
			table.insert(tones, rng:NextInteger(1, 2))
			table.insert(tweens, TweenService:Create(puff, info, { CFrame = base + drift }))
		end
	end
	puffFolder.Parent = workspace
end

-- OQ1: near the wall every puff (Efectos suaves: every other one) is drawn and sways; far away none is drawn and every
-- sway is paused.
local function show(near, reduced)
	for i, puff in ipairs(puffs) do
		local shown = near and (not reduced or i % 2 == 1)
		puff.Parent = shown and puffFolder or nil
		if not shown then
			tweens[i]:Pause()
		elseif tweens[i].PlaybackState ~= Enum.PlaybackState.Playing then
			tweens[i]:Play()
		end
	end
end

-- The Veil of the live map, or nil (not built, not streamed in).
local function findVeil()
	local root = workspace:FindFirstChild(ROOT_NAME)
	local folder = root and root:FindFirstChild(FOLDER_NAME)
	local found = folder and folder:FindFirstChild(VEIL_NAME)
	if found and found:IsA("BasePart") then return found end
	return nil
end

-- The 2 Hz step: the Veil (again when it streamed out), then each emitter's rate for the budget and the distance.
local function refresh()
	local current = findVeil()
	if current ~= veil or (veil and #emitters > 0 and emitters[1].Parent ~= veil)
		or (veil and (puffFolder == nil or puffFolder.Parent ~= workspace)) then
		teardown()
		veil = current
		if veil then
			for _, layer in ipairs(LAYERS) do table.insert(emitters, newEmitter(layer, veil)) end
			buildPuffs(veil)
		end
	end
	if not veil then return end
	local gui = worldGui()
	local reduced = gui ~= nil and gui:GetAttribute("Reduced") == true
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	local near = eye ~= nil and math.abs(eye.X - veil.Position.X) <= NEAR_STUDS
	-- PG-D6: a camera in Pueblo Gatito sees the park's face; a new emitter (side nil) is painted at once.
	-- Deliberately changed (OQ1 review): by the camera's biome, not its side of the Veil (east of it is Caramelo's tail)
	local park = eye ~= nil and BiomeLight.presetAt(eye.X, eye.Z) == "Gatuno"
	if park ~= side then paint(park) end
	for i, emitter in ipairs(emitters) do
		local layer = LAYERS[i]
		emitter.Rate = near and layer.rate * (reduced and REDUCED_SHARE or 1) or 0
		emitter.Enabled = near
	end
	-- OQ1: the puffs follow the same distance and budget, changed only when the state changes
	local key = (near and "near" or "far") .. (reduced and "-reduced" or "")
	if key ~= shownKey then
		show(near, reduced)
		shownKey = key
	end
end

local clock = CHECK_SECONDS
local warned = false
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
	clock += dt
	if clock < CHECK_SECONDS then return end
	clock = 0
	local ok, message = pcall(refresh)
	if not ok then
		teardown()
		if not warned then
			warned = true
			warn("Wildbound cloud wall: " .. tostring(message))
		end
	end
end))

table.insert(connections, script.Destroying:Connect(function()
	for _, connection in ipairs(connections) do connection:Disconnect() end
	teardown()
end))

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
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ROOT_NAME, FOLDER_NAME, VEIL_NAME = "Candy_Este_v1", "CloudWall", "Veil"
local TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local CHECK_SECONDS = 0.5
local NEAR_STUDS = 700 -- farther than this from the wall (flat) the puffs stop
local REDUCED_SHARE = 0.3 -- Efectos suaves: this share of the rate
-- Two layers of puffs: big slow pink ones and smaller white ones (rate per second at full budget).
-- PG-D6: colors is the Caramelo face; parkColors the Pueblo Gatito face (white and sky blue).
local LAYERS = {
	{ name = "CloudPuffs", rate = 22, lifetime = { 9, 14 }, size = { 18, 30 }, speed = { 0.4, 1.4 },
		colors = { Color3.fromRGB(255, 214, 234), Color3.fromRGB(255, 240, 248) },
		parkColors = { Color3.fromRGB(240, 248, 255), Color3.fromRGB(199, 226, 245) }, transparency = 0.45 },
	{ name = "CloudWisps", rate = 14, lifetime = { 7, 11 }, size = { 10, 18 }, speed = { 0.6, 1.8 },
		colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 226, 240) },
		parkColors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(214, 236, 250) }, transparency = 0.55 },
}

local player = Players.LocalPlayer
local veil = nil
local emitters = {}
local connections = {}
local side = nil -- PG-D6: the face the emitters wear (true = Pueblo Gatito, false = Caramelo, nil = not painted yet)

local function worldGui()
	local gui = player:FindFirstChildOfClass("PlayerGui")
	return gui and gui:FindFirstChild("WildboundWorldUI")
end

local function teardown()
	for _, emitter in ipairs(emitters) do emitter:Destroy() end
	table.clear(emitters)
	veil = nil
	side = nil
end

-- PG-D6: every emitter wears the palette of the side the camera is on (park: Pueblo Gatito, else Caramelo).
local function paint(park)
	for i, emitter in ipairs(emitters) do
		local colors = park and LAYERS[i].parkColors or LAYERS[i].colors
		emitter.Color = ColorSequence.new(colors[1], colors[2])
	end
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
	if current ~= veil or (veil and #emitters > 0 and emitters[1].Parent ~= veil) then
		teardown()
		veil = current
		if veil then
			for _, layer in ipairs(LAYERS) do table.insert(emitters, newEmitter(layer, veil)) end
		end
	end
	if not veil then return end
	local gui = worldGui()
	local reduced = gui ~= nil and gui:GetAttribute("Reduced") == true
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	local near = eye ~= nil and math.abs(eye.X - veil.Position.X) <= NEAR_STUDS
	-- PG-D6: the camera east of the Veil sees Pueblo Gatito's face; a new emitter (side nil) is painted at once
	local park = eye ~= nil and eye.X > veil.Position.X
	if park ~= side then paint(park) end
	for i, emitter in ipairs(emitters) do
		local layer = LAYERS[i]
		emitter.Rate = near and layer.rate * (reduced and REDUCED_SHARE or 1) or 0
		emitter.Enabled = near
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

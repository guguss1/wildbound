-- Nest Heist phase 4a (NB6): the beast client. The server (WildboundBeasts) sends this player only their own beasts'
-- events and 10 Hz snapshots over BeastEvent; this script draws them locally: a clone of the beast's model from
-- ReplicatedStorage.WildboundBeasts.Models (the user's import when present, else the Part proxy), interpolated about
-- 0.1 s behind the server, and the gameplay tells, which are never part of a model: Viper's red lane and Pouncer's red
-- circle, built from the same WildboundBeastConfig geometry the server checks hits with and timed by the server's
-- timestamps. Every tell also has a sound and a short Spanish line, so it never depends on colour alone. Efectos suaves
-- removes the camera shake and the dust, never a tell. Nothing is ever sent back: hits and dodges are server decisions.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
-- Wave 2 (odd/tasks/wildbound-beasts-wave2.md): Streamer, Root, Gaze and Lurker send generic events: Phase (posture,
-- a Spanish line, a sound), Tell (a shape from WildboundBeastConfig, the exact hit volume, drawn until its Strike or
-- TellEnd), Move (dash, arc, burrow, blink, slide on the server's timeline) and Exposure (Gaze's meter). The only thing
-- this client sends is the camera's look vector on BeastObserve, while it draws a Gaze or a Lurker
-- (WildboundBeastSight.SEND_INTERVAL); the server validates it and never uses it for a hit or a dodge.
-- SC0 shared visibility (odd/tasks/wildbound-scuttler.md): the server also sends this client other players' beasts in
-- range, as visual copies marked `bystander`. They use the same model, animation and timeline, but are drawn quietly:
-- no warning or phase line, no sound, no camera shake, no hit feedback or knock, no Gaze meter, no BeastObserve, and
-- Root's raised walls never collide for a bystander. Their tells keep the exact server geometry in a neutral, faded
-- colour (soften), so a bystander reads the attack without being alarmed by it.
-- SC8 Scuttler (docs/design/wildbound-scuttler-plan.md section 9): its feint lane is an outline without fill, its real
-- lane is solid with an antenna flash at the lock, the intercept zone is hatched, the pulse ring has rings rippling out
-- to its true radius, a fall shows dizzy stars over the tall body, and a landed pulse (Afflict, target only) gives a
-- short shake and desaturation that Efectos suaves leaves out. Sounds are existing catalogue slots only.
local Config = require(ReplicatedStorage:WaitForChild("WildboundBeastConfig"))
local Catalog = require(ReplicatedStorage:WaitForChild("WildboundAudioCatalog"))
local Text = require(ReplicatedStorage:WaitForChild("WildboundText"))
local Sight = require(ReplicatedStorage:WaitForChild("WildboundBeastSight"))

local player = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild("WildboundNetwork")
local beastEvent = network:WaitForChild("BeastEvent")
local observeEvent = network:WaitForChild("BeastObserve", 10)

-- Client-made, so it exists on this client only.
local folder = Instance.new("Folder")
folder.Name = "WildboundBeastsLocal"
folder.Parent = workspace

local RED = Color3.fromRGB(255, 40, 30)
local BEHIND = 0.1 -- render this far behind the server clock, between two snapshots
-- SC0: a bystander's snapshots come every Config.AUDIENCE.SNAP_SECONDS, so its view renders at least that far behind.
local BYSTANDER_BEHIND = Config.AUDIENCE.SNAP_SECONDS + BEHIND / 2
local views = {}
-- SC0: true while a bystander's event is being handled, so its HUD lines, sounds and shake stay silent.
local muting = false
local NEUTRAL = Color3.fromRGB(226, 224, 210)
local BYSTANDER_OPACITY = 0.4 -- a bystander's tell keeps this share of the target's opacity
local function dim(transparency) return 1 - (1 - transparency) * BYSTANDER_OPACITY end

local function serverNow() return workspace:GetServerTimeNow() end

local function reduced()
	local gui = player:FindFirstChildOfClass("PlayerGui")
	local world = gui and gui:FindFirstChild("WildboundWorldUI")
	return world ~= nil and world:GetAttribute("Reduced") == true
end

-- The warning line: large, centred high, red stroke, shown for the length of a tell.
local gui = Instance.new("ScreenGui")
gui.Name = "WildboundBeastsUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
local warning = Instance.new("TextLabel")
warning.Name = "Warning"
warning.AnchorPoint = Vector2.new(0.5, 0)
warning.Position = UDim2.fromScale(0.5, 0.16)
warning.Size = UDim2.fromScale(0.8, 0.07)
warning.BackgroundTransparency = 1
warning.TextScaled = true
warning.Font = Enum.Font.FredokaOne -- UI colorida: the rounded display font, same red stroke
warning.TextColor3 = Color3.fromRGB(255, 235, 225)
warning.TextStrokeColor3 = Color3.fromRGB(150, 0, 0)
warning.TextStrokeTransparency = 0
warning.Visible = false
warning.Parent = gui
gui.Parent = player:WaitForChild("PlayerGui")
local warningUntil = 0
local function showWarning(beast, untilAt)
	if muting then return end
	local words = Text.BEAST[beast]
	if not words then return end
	warning.Text = words.warn
	warning.Visible = true
	warningUntil = math.max(warningUntil, untilAt)
end
-- Wave 2: a phase's own line (Text.BEAST[beast].phases[phase]), shown at least a second.
local function showLine(line, untilAt)
	if muting then return end
	if type(line) ~= "string" then return end
	warning.Text = line
	warning.Visible = true
	warningUntil = math.max(warningUntil, untilAt, workspace:GetServerTimeNow() + 1)
end

-- Sounds: existing catalogue ids only (WildboundAudioCatalog), on the beast so they come from its direction.
local function play(slot, parent, pitch, volume)
	if muting then return end
	local entry = Catalog.SOUNDS[slot]
	if not entry or not parent then return end
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. tostring(entry.ids[1])
	sound.PlaybackSpeed = (pitch or 1) * (entry.pitch or 1)
	sound.Volume = volume or 0.7
	sound.RollOffMaxDistance = 160
	sound.Parent = parent
	sound:Play()
	sound.Ended:Once(function() sound:Destroy() end)
	task.delay(6, function() if sound.Parent then sound:Destroy() end end)
end

local function visualFor(beast)
	local root = ReplicatedStorage:FindFirstChild("WildboundBeasts")
	local models = root and root:FindFirstChild("Models")
	if not models then return nil end
	local real = models:FindFirstChild(beast)
	if real and real:IsA("Model") then return real end
	local proxy = models:FindFirstChild(beast .. "Proxy")
	return proxy and proxy:IsA("Model") and proxy or nil
end

local function quiet(part)
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.CastShadow = false
end

-- A flat red marker part on the ground (gameplay effect, never part of a model).
local function marker(name, size, cframe, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = RED
	part.Material = Enum.Material.Neon
	part.Transparency = transparency
	quiet(part)
	part.Parent = folder
	return part
end

local function clearLane(view)
	if view.lane then view.lane:Destroy() end
	view.lane = nil
end
local function clearCircle(view)
	if view.circle then view.circle:Destroy() end
	view.circle = nil
end

-- SC0: a bystander's tell in the neutral colour at a lower opacity (same shape and timing); nothing for the target.
local function soften(view, model)
	if not view.bystander or not model then return end
	for _, part in ipairs(model:GetDescendants()) do
		-- Once per drawn part (a redraw makes new parts), so a second call never dims it again.
		if part:IsA("BasePart") and part:GetAttribute("Softened") ~= true then
			part.Color = NEUTRAL
			part.Transparency = dim(part.Transparency)
			part:SetAttribute("Softened", true)
		end
	end
end

-- Viper's lane: the exact rectangle of Config.lane, a few hundredths over the ground, with brighter edges.
local function drawLane(view)
	local L = view.laneSpec
	if not L then return end
	local spec = Config.lane(L.ox, L.oz, L.dx, L.dz, L.length, L.width)
	local cframe = CFrame.new(spec.cx, L.oy + 0.12, spec.cz) * CFrame.Angles(0, spec.yaw, 0)
	if not view.lane then
		local lane = Instance.new("Model")
		lane.Name = "ViperLane"
		marker("Fill", Vector3.new(L.width, 0.12, L.length), cframe, 0.55).Parent = lane
		marker("EdgeL", Vector3.new(0.25, 0.14, L.length), cframe, 0.15).Parent = lane
		marker("EdgeR", Vector3.new(0.25, 0.14, L.length), cframe, 0.15).Parent = lane
		lane.Parent = folder
		view.lane = lane
		soften(view, lane)
	end
	local fill, left, right = view.lane:FindFirstChild("Fill"), view.lane:FindFirstChild("EdgeL"), view.lane:FindFirstChild("EdgeR")
	fill.Size = Vector3.new(L.width, 0.12, math.max(L.length, 0.1))
	fill.CFrame = cframe
	left.Size = Vector3.new(0.25, 0.14, math.max(L.length, 0.1))
	right.Size = left.Size
	left.CFrame = cframe * CFrame.new(-L.width / 2, 0, 0)
	right.CFrame = cframe * CFrame.new(L.width / 2, 0, 0)
end

-- Pouncer's circle: a flat disc of the exact radius and a pulsing ring of segments around it.
local RING = 20
local function drawCircle(view)
	local c = view.circleSpec
	if not c then return end
	if not view.circle then
		local circle = Instance.new("Model")
		circle.Name = "PouncerCircle"
		marker("Disc", Vector3.new(0.12, c.radius * 2, c.radius * 2), CFrame.new(), 0.6).Parent = circle
		for i = 1, RING do marker("Ring" .. i, Vector3.new(0.18, 0.3, c.radius * 2 * math.pi / RING), CFrame.new(), 0.1).Parent = circle end
		circle.Parent = folder
		view.circle = circle
		soften(view, circle)
	end
	local base = CFrame.new(c.x, c.y + 0.12, c.z)
	view.circle.Disc.CFrame = base * CFrame.Angles(0, 0, math.pi / 2)
	for i = 1, RING do
		local a = (i - 0.5) / RING * math.pi * 2
		view.circle["Ring" .. i].CFrame = base * CFrame.Angles(0, -a, 0) * CFrame.new(c.radius, 0.02, 0)
	end
end

local function fadeModel(view, alpha)
	if not view.model then return end
	for _, d in ipairs(view.model:GetDescendants()) do
		if d:IsA("BasePart") then d.LocalTransparencyModifier = alpha end
	end
end

local function shake(strength)
	if reduced() then return end
	if muting then return end
	local camera = workspace.CurrentCamera
	local untilAt = os.clock() + 0.25
	local name = "WildboundBeastShake"
	RunService:UnbindFromRenderStep(name)
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
		local left = untilAt - os.clock()
		if left <= 0 then RunService:UnbindFromRenderStep(name) return end
		local s = strength * left / 0.25
		camera.CFrame *= CFrame.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
	end)
end

-- SC8: a brief desaturation on this client's camera (client-made, removed after `seconds`).
local desaturateToken = 0
local function desaturate(seconds)
	if muting then return end
	local camera = workspace.CurrentCamera
	if not camera then return end
	local effect = camera:FindFirstChild("WildboundPulseDesaturate")
	if not effect then
		effect = Instance.new("ColorCorrectionEffect")
		effect.Name = "WildboundPulseDesaturate"
		effect.Parent = camera
	end
	effect.Saturation, effect.Contrast, effect.Enabled = -0.65, 0.05, true
	desaturateToken += 1
	local token = desaturateToken
	task.delay(seconds, function()
		if token == desaturateToken and effect.Parent then effect:Destroy() end
	end)
end

local function dust(at)
	if reduced() then return end
	local part = Instance.new("Part")
	part.Name = "Dust"
	part.Size = Vector3.new(1, 1, 1)
	part.Transparency = 1
	part.CFrame = CFrame.new(at)
	quiet(part)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(120, 105, 95))
	emitter.Size = NumberSequence.new(1.2, 3)
	emitter.Transparency = NumberSequence.new(0.4, 1)
	emitter.Lifetime = NumberRange.new(0.5, 0.8)
	emitter.Speed = NumberRange.new(6, 10)
	emitter.SpreadAngle = Vector2.new(180, 20)
	emitter.Rate = 0
	emitter.Parent = part
	part.Parent = folder
	emitter:Emit(18)
	task.delay(1.2, function() part:Destroy() end)
end

-- Wave 2 tells ----------------------------------------------------------------------------------------------------------
-- Colours per beast; every tell also has its line, a sound and a pulse, so colour is never the only cue.
local TELL_COLOR = {
	Streamer = Color3.fromRGB(255, 45, 140), Root = Color3.fromRGB(130, 235, 90), Gaze = Color3.fromRGB(165, 80, 255),
	Lurker = Color3.fromRGB(255, 70, 200), Scuttler = Color3.fromRGB(255, 60, 40),
	-- Kids biome: the Nube's ring in sun yellow, the Abeja's lane in honey; never red.
	NubeGrunona = Color3.fromHex("FFD23F"), AbejaReina = Color3.fromHex("F2A33A"),
	-- Caramelo biome (CA2): Tortidragon's fan and circles in candy yellow, which reads on the pink floor.
	Tortidragon = Color3.fromHex("FFD23F"),
}
-- Kids biome: their own sounds (catalogue slots only; never chaseMusic, heartbeat, roar or stinger).
local KIDS_PHASE_SOUND = {
	NubeGrunona = { Notice = { "groan", 1.1 }, Telegraph = { "crack", 1.3 } },
	AbejaReina = { Telegraph = { "unease", 1.2 } },
}
local KIDS_HIT_SOUND = { NubeGrunona = "softStinger", AbejaReina = "softStinger" }
local KIDS_HUM = { AbejaReina = "insectsDusk" } -- looped while her encounter lives
-- SC8: a beast's own phase sounds (plan section 9 slots only); "Phase:Variant" wins when the event carries it. The feint
-- has no cue on purpose: only real attacks sound.
local OWN_PHASE_SOUND = {
	Scuttler = {
		Stalk = { "steps", 1.1 }, Read = { "unease", 1 }, Intercept = { "steps", 1.5 }, ChargeTell = { "steps", 1.6 },
		PunishTell = { "stinger", 1.2 }, Charge = { "dirt", 1.5 }, Snap = { "snap", 1 }, PulseCharge = { "unease", 0.7 },
		Pulse = { "roar", 1.1 }, Fallen = { "softStinger", 1 }, ["Fallen:Crash"] = { "crack", 0.9 },
	},
}
local SPAWN_SOUND = { Scuttler = "dirt" } -- the rise out of the ground
local STAR_HEIGHT = { Scuttler = 15 } -- dizzy stars over a tall body (others: 6 studs)
local GAP_COLOR = Color3.fromRGB(235, 255, 235)
local WALL_COLOR = Color3.fromRGB(92, 70, 52)
local WALL_HEIGHT = 7

local function piece(model, name, size, cframe, color, transparency)
	local part = marker(name, size, cframe, transparency)
	part.Color = color
	part.Parent = model
	return part
end

-- A flat bar from a to b (Vector3 on the ground), `width` wide.
local function bar(model, name, a, b, width, color, transparency, height)
	local length = (b - a).Magnitude
	if length < 0.05 then return nil end
	local h = height or 0.12
	local middle = (a + b) / 2 + Vector3.new(0, h / 2, 0)
	return piece(model, name, Vector3.new(width, h, length), CFrame.lookAt(middle, middle + (b - a)), color, transparency)
end

local function ring(model, cx, y, cz, radius, color, transparency, count)
	count = count or 24
	for i = 1, count do
		local a0, a1 = (i - 1) / count * math.pi * 2, i / count * math.pi * 2
		bar(model, "Ring" .. i, Vector3.new(cx + math.cos(a0) * radius, y, cz + math.sin(a0) * radius),
			Vector3.new(cx + math.cos(a1) * radius, y, cz + math.sin(a1) * radius), 0.3, color, transparency)
	end
end

-- SC8: Scuttler's feint, an outline without fill: the lane's two edges and its two ends, never the fill or the chevrons.
local function outline(model)
	local fill = model:FindFirstChild("Fill")
	local cframe, size, color = fill and fill.CFrame, fill and fill.Size, fill and fill.Color
	for _, part in ipairs(model:GetChildren()) do
		local name = part.Name
		if name == "Fill" or name:sub(1, 7) == "Chevron" then part:Destroy() end
	end
	if not cframe then return end
	for i, z in ipairs({ -size.Z / 2, size.Z / 2 }) do
		piece(model, "EdgeEnd" .. i, Vector3.new(size.X, 0.14, 0.25), cframe * CFrame.new(0, 0, z), color, 0.15)
	end
end

-- SC8: the intercept zone, hatched: diagonal bars clipped to the exact circle (on top of its disc and ring).
local function hatch(model, shape, color)
	local r = shape.r
	if type(r) ~= "number" or r <= 0 then return end
	local step = 2.5
	local dx, dz = math.cos(math.pi / 4), math.sin(math.pi / 4)
	local nx, nz = -dz, dx
	local i = 0
	for offset = -r + step / 2, r - step / 2, step do
		local half = math.sqrt(math.max(r * r - offset * offset, 0))
		if half > 0.3 then
			i += 1
			local cx, cz = shape.x + nx * offset, shape.z + nz * offset
			bar(model, "Hatch" .. i, Vector3.new(cx - dx * half, shape.y + 0.04, cz - dz * half),
				Vector3.new(cx + dx * half, shape.y + 0.04, cz + dz * half), 0.35, color, 0.25)
		end
	end
end

local function rotate(gx, gz, angle)
	local c, s = math.cos(angle), math.sin(angle)
	return gx * c - gz * s, gx * s + gz * c
end

-- Draws one shape into a fresh model (the exact Config geometry the server checks).
local function drawShape(model, shape, color, raised)
	model:ClearAllChildren()
	local kind = shape.kind
	if kind == "circle" then
		local disc = piece(model, "Disc", Vector3.new(0.12, shape.r * 2, shape.r * 2),
			CFrame.new(shape.x, shape.y + 0.1, shape.z) * CFrame.Angles(0, 0, math.pi / 2), color, 0.6)
		disc.Shape = Enum.PartType.Cylinder
		ring(model, shape.x, shape.y + 0.14, shape.z, shape.r, color, 0.1)
	elseif kind == "lane" then
		local spec = Config.lane(shape.ox, shape.oz, shape.dx, shape.dz, shape.length, shape.width)
		local cframe = CFrame.new(spec.cx, shape.oy + 0.12, spec.cz) * CFrame.Angles(0, spec.yaw, 0)
		piece(model, "Fill", Vector3.new(shape.width, 0.12, math.max(shape.length, 0.1)), cframe, color, 0.55)
		piece(model, "EdgeL", Vector3.new(0.25, 0.14, math.max(shape.length, 0.1)), cframe * CFrame.new(-shape.width / 2, 0, 0), color, 0.15)
		piece(model, "EdgeR", Vector3.new(0.25, 0.14, math.max(shape.length, 0.1)), cframe * CFrame.new(shape.width / 2, 0, 0), color, 0.15)
		-- Chevrons along the lane show the direction of travel.
		for i = 1, math.floor(shape.length / 6) do
			local at = Vector3.new(shape.ox + shape.dx * i * 6, shape.oy + 0.16, shape.oz + shape.dz * i * 6)
			piece(model, "Chevron" .. i, Vector3.new(shape.width * 0.6, 0.1, 0.4), CFrame.lookAt(at, at + Vector3.new(shape.dx, 0, shape.dz)),
				color, 0.05)
		end
	elseif kind == "sector" then
		local half = math.rad(shape.arc / 2)
		local steps = 12
		for i = 0, steps do
			local dx, dz = rotate(shape.dx, shape.dz, -half + i / steps * half * 2)
			local edge = i == 0 or i == steps
			bar(model, "Ray" .. i, Vector3.new(shape.x, shape.y, shape.z),
				Vector3.new(shape.x + dx * shape.r, shape.y, shape.z + dz * shape.r), edge and 0.35 or 0.9, color, edge and 0.1 or 0.65)
			if i > 0 then
				local px, pz = rotate(shape.dx, shape.dz, -half + (i - 1) / steps * half * 2)
				bar(model, "Arc" .. i, Vector3.new(shape.x + px * shape.r, shape.y, shape.z + pz * shape.r),
					Vector3.new(shape.x + dx * shape.r, shape.y, shape.z + dz * shape.r), 0.35, color, 0.1)
			end
		end
	elseif kind == "multi" then
		-- Root's lanes: each split into `segments` cracked pieces of the drawn width (raised as roots on the eruption).
		-- Caramelo biome (CA2): Tortidragon's three landing circles, each a disc and a ring like a single circle.
		local segments = shape.segments or 1
		for c, circle in ipairs(shape.list or {}) do
			if circle.kind == "circle" then
				local disc = piece(model, "Disc" .. c, Vector3.new(0.12, circle.r * 2, circle.r * 2),
					CFrame.new(circle.x, circle.y + 0.1, circle.z) * CFrame.Angles(0, 0, math.pi / 2), color, 0.5)
				disc.Shape = Enum.PartType.Cylinder
				ring(model, circle.x, circle.y + 0.14, circle.z, circle.r, color, 0.05)
			end
		end
		for l, lane in ipairs(shape.list or {}) do
			if lane.kind ~= "lane" then continue end
			local step = lane.length / segments
			for s = 1, segments do
				local a = Vector3.new(lane.ox + lane.dx * (s - 1) * step, lane.oy, lane.oz + lane.dz * (s - 1) * step)
				local b = Vector3.new(lane.ox + lane.dx * (s * step - 0.4), lane.oy, lane.oz + lane.dz * (s * step - 0.4))
				bar(model, ("Lane%dSeg%d"):format(l, s), a, b, lane.width, raised and WALL_COLOR or color, raised and 0 or 0.45,
					raised and 3 or nil)
			end
		end
	elseif kind == "walls" then
		local height = raised and WALL_HEIGHT or 0.12
		for w, span in ipairs(shape.list) do
			local count = math.max(2, math.ceil((span.to - span.from) * shape.r / 3))
			for i = 1, count do
				local a0 = span.from + (i - 1) / count * (span.to - span.from)
				local a1 = span.from + i / count * (span.to - span.from)
				local x0, z0 = rotate(shape.gx, shape.gz, a0)
				local x1, z1 = rotate(shape.gx, shape.gz, a1)
				local part = bar(model, ("Wall%dSeg%d"):format(w, i), Vector3.new(shape.x + x0 * shape.r, shape.y, shape.z + z0 * shape.r),
					Vector3.new(shape.x + x1 * shape.r, shape.y, shape.z + z1 * shape.r), 1.4, raised and WALL_COLOR or color,
					raised and 0 or 0.35, height)
				if part then part:SetAttribute("Wall", true) end
			end
		end
		-- The gap: two bright posts and a strip leading out (white-green, never the danger colour).
		local half = shape.list[1].from
		for _, a in ipairs({ half, -half }) do
			local px, pz = rotate(shape.gx, shape.gz, a)
			local base = Vector3.new(shape.x + px * shape.r, shape.y, shape.z + pz * shape.r)
			piece(model, "GapPost", Vector3.new(0.6, 9, 0.6), CFrame.new(base + Vector3.new(0, 9 / 2, 0)), GAP_COLOR, 0.1)
		end
		bar(model, "GapPath", Vector3.new(shape.x, shape.y, shape.z),
			Vector3.new(shape.x + shape.gx * (shape.r + 4), shape.y, shape.z + shape.gz * (shape.r + 4)), 2, GAP_COLOR, 0.3)
	end
end

-- Raised walls collide on this client only, so they hold back only this player's own character (the owner simulates
-- it); a wall piece that would rise inside the character stays open, so nobody is ever trapped in a wall.
local function raiseWalls(model)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") and part:GetAttribute("Wall") then
			local inside = root and (part.CFrame:PointToObjectSpace(root.Position)) or nil
			local overlapping = inside and math.abs(inside.X) < part.Size.X / 2 + 1.5 and math.abs(inside.Z) < part.Size.Z / 2 + 1.5
			part.CanCollide = not overlapping
		end
	end
end

local function clearTell(view, tell, delay)
	local item = view.tells and view.tells[tell]
	if not item then return end
	view.tells[tell] = nil
	if delay and delay > 0 then
		task.delay(delay, function() item.model:Destroy() end)
	else
		item.model:Destroy()
	end
end

local function clearTells(view)
	for tell in pairs(view.tells or {}) do clearTell(view, tell) end
end

local function finishView(id)
	local view = views[id]
	if not view then return end
	views[id] = nil
	clearLane(view)
	clearCircle(view)
	clearTells(view)
	if view.extras then view.extras:Destroy() end
	if view.model then view.model:Destroy() end
end

local function rootOf(view) return view.model and view.model.PrimaryPart end
-- Wave 2: the phase, published on the model for WildboundBeastAnim (a rigged model plays the matching baked clip).
local function publishPhase(view, phase, at, untilAt)
	if not view.model then return end
	view.model:SetAttribute("BeastPhase", phase)
	view.model:SetAttribute("BeastPhaseAt", at)
	view.model:SetAttribute("BeastPhaseUntil", untilAt or at)
	view.model:SetAttribute("BeastPhaseVariant", nil)
end
-- SC8: a phase's variant (Scuttler's Fallen: "Crash" or "Stumble"), published after the phase it belongs to.
local function publishVariant(view, variant)
	if not view.model then return end
	if type(variant) ~= "string" then variant = nil end
	view.model:SetAttribute("BeastPhaseVariant", variant)
end

-- SC8: Scuttler's antennas flash white for a moment when a real attack locks (never for a feint).
local function flash(view)
	if not view.model then return end
	for _, name in ipairs({ "AntennaTipL", "AntennaTipR" }) do
		local tip = view.model:FindFirstChild(name, true)
		if tip and tip:IsA("BasePart") then
			if tip:GetAttribute("BaseColor") == nil then tip:SetAttribute("BaseColor", tip.Color) end
			tip.Color = Color3.new(1, 1, 1)
			task.delay(0.3, function()
				if tip.Parent then tip.Color = tip:GetAttribute("BaseColor") end
			end)
		end
	end
end

local handlers = {}
function handlers.Spawn(ev)
	finishView(ev.id)
	local template = visualFor(ev.beast)
	local view = { beast = ev.beast, snaps = {}, mode = "snap", dx = ev.dx or 0, dz = ev.dz or 1 }
	view.bystander = ev.bystander == true
	view.behind = view.bystander and BYSTANDER_BEHIND or BEHIND
	if template then
		view.model = template:Clone()
		-- Wave 2: the visual in the world is named exactly after the beast (Streamer, Root, Gaze, Lurker), proxy or art.
		view.model.Name = ev.beast
		for _, d in ipairs(view.model:GetDescendants()) do if d:IsA("BasePart") then quiet(d) end end
		view.model.Parent = folder
	end
	table.insert(view.snaps, { at = ev.at, x = ev.pos.x, y = ev.pos.y, z = ev.pos.z, dx = view.dx, dz = view.dz })
	views[ev.id] = view
	if Config.WAVE2[ev.beast] then
		view.tells, view.wave2, view.exposure = {}, true, 0
		-- A rigged model (bones under its mesh) animates its own posture; the Part proxies keep posture().
		view.rigged = view.model ~= nil and view.model:FindFirstChildWhichIsA("Bone", true) ~= nil
		-- SC0: a bystander joining mid-encounter starts in the beast's current phase.
		local phase = view.bystander and type(ev.phase) == "string" and ev.phase or "Spawn"
		view.phase = phase ~= "Spawn" and phase or nil
		publishPhase(view, phase, ev.at, ev.at)
		view.extras = Instance.new("Folder")
		view.extras.Name = ev.beast .. "Extras"
		view.extras.Parent = folder
		if SPAWN_SOUND[ev.beast] then play(SPAWN_SOUND[ev.beast], rootOf(view), 0.7, 0.8) end
		local hum = not muting and KIDS_HUM[ev.beast] and Catalog.SOUNDS[KIDS_HUM[ev.beast]]
		if hum then
			-- Destroyed with the model (or the extras folder) when the encounter ends.
			local sound = Instance.new("Sound")
			sound.Name = "Hum"
			sound.SoundId = "rbxassetid://" .. tostring(hum.ids[1])
			sound.Looped, sound.Volume, sound.RollOffMaxDistance = true, 0.5, 120
			sound.Parent = rootOf(view) or view.extras
			sound:Play()
		end
		return
	end
	play(ev.beast == "Viper" and "dirt" or "steps", rootOf(view), ev.beast == "Viper" and 0.8 or 1.25, 0.6)
end
function handlers.Snap(ev, view)
	table.insert(view.snaps, { at = ev.at, x = ev.x, y = ev.y, z = ev.z, dx = ev.dx, dz = ev.dz })
	if #view.snaps > 12 then table.remove(view.snaps, 1) end
	-- Before the lock (Viper) or the freeze (Pouncer) the tell follows the server's aim.
	if view.laneSpec and not view.laneSpec.locked and ev.dx then view.laneSpec.dx, view.laneSpec.dz = ev.dx, ev.dz end
	if view.circleSpec and not view.circleSpec.frozen and ev.center then
		view.circleSpec.x, view.circleSpec.y, view.circleSpec.z = ev.center.x, ev.center.y, ev.center.z
	end
end
function handlers.Windup(ev, view)
	view.laneSpec = { ox = ev.origin.x, oy = ev.origin.y, oz = ev.origin.z, dx = ev.dx, dz = ev.dz, length = ev.length,
		width = ev.width, locked = false }
	view.mode = "windup"
	drawLane(view)
	showWarning("Viper", ev.dashAt)
	play("whisper", rootOf(view), 1.7, 0.9)
end
function handlers.Lock(ev, view)
	if not view.laneSpec then return end
	view.laneSpec.dx, view.laneSpec.dz, view.laneSpec.length, view.laneSpec.locked = ev.dx, ev.dz, ev.length, true
	drawLane(view)
	if view.lane then view.lane.Fill.Transparency = view.bystander and dim(0.35) or 0.35 end
end
function handlers.Dash(ev, view)
	view.mode = "dash"
	view.dash = { at = ev.at, endAt = ev.endAt, dx = ev.dx, dz = ev.dz, speed = ev.speed, length = ev.length }
	play("dirt", rootOf(view), 1.5, 1)
end
function handlers.Recover(_, view)
	-- The snapshots sent during the dash already follow it, so the body stays where the dash ended.
	view.mode = "snap"
	task.delay(0.15, function() clearLane(view) end)
end
function handlers.Telegraph(ev, view)
	view.circleSpec = { x = ev.center.x, y = ev.center.y, z = ev.center.z, radius = ev.radius, frozen = false,
		startAt = ev.at, landAt = ev.landAt }
	drawCircle(view)
	showWarning("Pouncer", ev.landAt)
	play("snap", rootOf(view), 1.2, 0.9)
end
function handlers.Freeze(ev, view)
	if not view.circleSpec then return end
	view.circleSpec.x, view.circleSpec.y, view.circleSpec.z, view.circleSpec.frozen = ev.center.x, ev.center.y, ev.center.z, true
	drawCircle(view)
	play("snap", rootOf(view), 0.9, 0.9)
end
function handlers.Leap(ev, view)
	view.mode = "leap"
	view.leap = { at = ev.at, landAt = ev.landAt, from = ev.from, to = ev.to, height = ev.height }
end
function handlers.Land(ev, view)
	view.mode = "snap"
	view.snaps = { { at = ev.at, x = ev.center.x, y = ev.center.y, z = ev.center.z, dx = view.dx, dz = view.dz } }
	play("crack", rootOf(view), 0.8, 1)
	dust(Vector3.new(ev.center.x, ev.center.y + 0.5, ev.center.z))
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and (root.Position - Vector3.new(ev.center.x, root.Position.Y, ev.center.z)).Magnitude < 14 then shake(0.35) end
	-- The circle stays until after the landing, then goes.
	task.delay(0.35, function() clearCircle(view) end)
end
function handlers.Hit(ev, view)
	-- SC0: never sent to a bystander; if it ever arrived, no feedback and no knock on this character.
	if view.bystander then return end
	local kid = KIDS_HIT_SOUND[view.beast]
	play(kid or "hit", rootOf(view), 1, 1)
	if not kid then shake(0.5) end
	-- Kids biome: the Ráfaga and Pegajoso lines ride on the Hit event (Text.BEAST[beast].phases[ev.line]).
	local said = Text.BEAST[view.beast]
	if type(ev.line) == "string" and said and said.phases and said.phases[ev.line] then showLine(said.phases[ev.line], ev.at + 1.5) end
	-- Wave 2: Streamer's scream pushes lightly. This client owns its character, so it applies the push, never faster
	-- than the configured speed and never a ragdoll.
	local knock = ev.knock
	local cap = Config.BEASTS.Streamer.tuning.ScreamKnockbackStudsPerSecond
	if type(knock) == "table" and Config.finite(knock.dx) and Config.finite(knock.dz) and Config.finite(knock.speed) then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local dx, dz = Config.unit(knock.dx, knock.dz)
		if root and dx then
			local speed = math.clamp(knock.speed, 0, cap)
			root.AssemblyLinearVelocity += Vector3.new(dx * speed, 0, dz * speed)
		end
	end
end

-- Wave 2 handlers ---------------------------------------------------------------------------------------------------
-- A sound per phase (catalogue slots only) and a posture the Heartbeat applies.
local PHASE_SOUND = {
	Warn = { "breathing", 0.9 }, ScreamCharge = { "groan", 1.4 }, RushTelegraph = { "snap", 1.1 }, RushCommit = { "dirt", 1.6 },
	Recovery = { "crack", 1 }, Stunned = { "crack", 0.7 },
	Rise = { "creak", 0.8 }, TelegraphTrap = { "crack", 0.6 }, Erupt = { "crack", 1.2 }, TelegraphWalls = { "creak", 1.2 },
	WhipWindup = { "whisper", 0.7 },
	Manifest = { "unease", 1 }, ExposureBuild = { "heartbeat", 1 }, ChargeZone = { "pulse", 1.2 },
	Presence = { "steps", 0.8 }, CoverApproach = { "steps", 1.1 }, LeapWindup = { "whisper", 1.4 }, OverrunStunned = { "crack", 0.9 },
}
function handlers.Phase(ev, view)
	if not view.wave2 then return end
	view.phase, view.phaseAt, view.phaseUntil = ev.phase, ev.at, ev.untilAt
	publishPhase(view, ev.phase, ev.at, ev.untilAt)
	publishVariant(view, ev.fall)
	-- A move ends at the first phase that starts after it.
	if view.move and ev.at >= (view.move.endAt or math.huge) - 1e-3 then view.move = nil end
	local words = Text.BEAST[view.beast]
	local line = words and words.phases and words.phases[ev.phase]
	if line then showLine(line, ev.untilAt or ev.at) end
	local own = KIDS_PHASE_SOUND[view.beast] or OWN_PHASE_SOUND[view.beast]
	local sound
	if own then
		sound = (type(ev.fall) == "string" and own[ev.phase .. ":" .. ev.fall]) or own[ev.phase]
	else
		sound = PHASE_SOUND[ev.phase]
	end
	if sound then play(sound[1], rootOf(view), sound[2], 0.85) end
	if ev.phase == "Stunned" or ev.phase == "OverrunStunned" or ev.phase == "Fallen" then view.stunUntil = ev.untilAt end
	if ev.phase == "Fallen" then
		local last = view.snaps[#view.snaps]
		if last then dust(Vector3.new(last.x, last.y + 0.5, last.z)) end
	end
end
function handlers.Tell(ev, view)
	if not view.wave2 or type(ev.shape) ~= "table" or type(ev.tell) ~= "string" then return end
	local item = view.tells[ev.tell]
	if not item then
		local model = Instance.new("Model")
		model.Name = view.beast .. "Tell"
		model.Parent = view.extras
		item = { model = model }
		view.tells[ev.tell] = item
	end
	item.shape, item.startAt, item.strikeAt, item.locked = ev.shape, ev.startAt, ev.strikeAt, ev.locked
	item.zone, item.feint = ev.zone == true, ev.feint == true
	drawShape(item.model, ev.shape, TELL_COLOR[view.beast] or RED, false)
	local color = TELL_COLOR[view.beast] or RED
	if ev.locked and item.model:FindFirstChild("Fill") then item.model.Fill.Transparency = 0.35 end
	-- SC8: Scuttler's feint is an outline only, its intercept zone is hatched, a real lock flashes its antennas once.
	if ev.feint then outline(item.model) end
	if ev.zone then hatch(item.model, ev.shape, color) end
	if view.beast == "Scuttler" and ev.locked and not item.flashed then
		item.flashed = true
		if not ev.feint then flash(view) end
	end
	soften(view, item.model)
end
function handlers.TellEnd(ev, view)
	if view.wave2 then clearTell(view, ev.tell) end
end
function handlers.Strike(ev, view)
	local item = view.wave2 and view.tells[ev.tell]
	if not item then return end
	if item.shape.kind == "multi" and item.shape.list and item.shape.list[1] and item.shape.list[1].kind == "lane" then
		-- Root's eruption: the roots rise on the drawn lanes, then sink.
		drawShape(item.model, item.shape, TELL_COLOR.Root, true)
		soften(view, item.model)
		play("crack", rootOf(view), 1.25, 1)
	else
		for _, part in ipairs(item.model:GetChildren()) do
			if part:IsA("BasePart") then part.Transparency = view.bystander and dim(0) or 0 end
		end
	end
	if ev.dodged then showLine(Text.DODGE and Text.DODGE.perfect, ev.at + 1) end
	clearTell(view, ev.tell, 0.35)
end
function handlers.Move(ev, view)
	if not view.wave2 then return end
	local move = { kind = ev.kind, at = ev.at, from = ev.from, to = ev.to, dx = ev.dx, dz = ev.dz, speed = ev.speed,
		length = ev.length, height = ev.height }
	if ev.kind == "dash" then move.endAt = ev.at + ev.length / math.max(ev.speed, 1e-3)
	elseif ev.kind == "arc" then move.endAt = ev.landAt
	elseif ev.kind == "burrow" or ev.kind == "slide" or ev.kind == "run" then move.endAt = ev.untilAt
	elseif ev.kind == "blink" then
		view.snaps = { { at = ev.at, x = ev.to.x, y = ev.to.y, z = ev.to.z, dx = view.dx, dz = view.dz } }
		play("unease", rootOf(view), 0.8, 0.6)
		return
	end
	view.move = move
	if ev.kind == "burrow" then play("dirt", rootOf(view), 0.7, 0.9) end
end
-- SC8: a landed pulse (Afflict) on this player. The server already applied the slow; the client only adds a short
-- shake and a brief desaturation, both left out by Efectos suaves. A bystander never receives Afflict.
function handlers.Afflict(ev, view)
	if view.bystander then return end
	if ev.shake ~= true or reduced() then return end
	shake(0.45)
	desaturate(0.45)
end
function handlers.Exposure(ev, view)
	if view.wave2 and not view.bystander and Config.finite(ev.value) then view.exposure = math.clamp(ev.value, 0, 1) end
end
function handlers.SightBreak(ev, view)
	if not view.wave2 or view.bystander then return end
	view.exposure = 0
	local words = Text.BEAST.Gaze
	if words and words.broken then showLine(words.broken, ev.at + 1) end
	play("softStinger", rootOf(view), 1.2, 0.5)
end
function handlers.Cancel(_, view)
	clearCircle(view)
	clearLane(view)
	if not view.bystander then warningUntil = 0 end
end
function handlers.Disengage(ev, view)
	if view.wave2 then publishPhase(view, "Disengage", ev.at, ev.untilAt) end
	view.fadeFrom = os.clock()
	clearCircle(view)
	clearLane(view)
	clearTells(view)
end
function handlers.End(ev)
	-- Kids biome: after Bostezo the Nube goes to sleep.
	local view = views[ev.id]
	local said = view and Text.BEAST[view.beast]
	if ev.reason == "Yawn" and said and said.phases and said.phases.Asleep then showLine(said.phases.Asleep, ev.at + 1.5) end
	finishView(ev.id)
end

beastEvent.OnClientEvent:Connect(function(ev)
	if type(ev) ~= "table" or type(ev.id) ~= "string" or type(ev.type) ~= "string" then return end
	local handler = handlers[ev.type]
	if not handler then return end
	local view = views[ev.id]
	if ev.type ~= "Spawn" and ev.type ~= "End" and not view then return end
	-- SC0: a bystander's events (or a bystander view's) are handled silently.
	muting = (view ~= nil and view.bystander) or ev.bystander == true
	local ok, message = pcall(handler, ev, view)
	muting = false
	if not ok then warn("Wildbound beasts client: " .. tostring(message)) end
end)

-- Wave 2: a move on the server's timeline (dash, arc, burrow, slide), held at its end until the next phase.
local function movePlace(view, at)
	local m = view.move
	local span = math.max((m.endAt or m.at) - m.at, 1e-3)
	local t = math.clamp((at - m.at) / span, 0, 1)
	if m.kind == "dash" then
		local travelled = math.clamp((at - m.at) * m.speed, 0, m.length)
		local last = view.snaps[#view.snaps]
		local y = last and last.at >= m.at and last.y or m.from.y
		return m.from.x + m.dx * travelled, y, m.from.z + m.dz * travelled, m.dx, m.dz
	elseif m.kind == "arc" then
		local x, y, z = Config.arc(m.from.x, m.from.y, m.from.z, m.to.x, m.to.y, m.to.z, m.height, t)
		local dx, dz = Config.unit(m.to.x - m.from.x, m.to.z - m.from.z)
		return x, y, z, dx or view.dx, dz or view.dz
	elseif m.kind == "burrow" then
		-- Sinks into the mud at the old spot, rises at the new one.
		if t < 0.5 then return m.from.x, m.from.y - 9 * t, m.from.z, view.dx, view.dz end
		return m.to.x, m.to.y - 9 * (1 - t), m.to.z, view.dx, view.dz
	elseif m.kind == "slide" then
		return m.from.x + (m.to.x - m.from.x) * t, m.from.y + (m.to.y - m.from.y) * t, m.from.z + (m.to.z - m.from.z) * t,
			view.dx, view.dz
	elseif m.kind == "run" then
		-- SC8: Scuttler's intercept, a straight run to P facing where it goes.
		local dx, dz = Config.unit(m.to.x - m.from.x, m.to.z - m.from.z)
		return m.from.x + (m.to.x - m.from.x) * t, m.from.y + (m.to.y - m.from.y) * t, m.from.z + (m.to.z - m.from.z) * t,
			dx or view.dx, dz or view.dz
	end
	return nil
end

-- Where the beast is now: the dash and the leap follow the server's own timeline; otherwise between two snapshots.
local function placeOf(view, at)
	if view.move then
		local x, y, z, dx, dz = movePlace(view, at)
		if x then return x, y, z, dx, dz end
	end
	if view.mode == "dash" and view.dash then
		local d = view.dash
		local L = view.laneSpec
		local travelled = math.clamp((at - d.at) * d.speed, 0, d.length)
		-- Height: the server runs the head along the ground; its latest snapshot of this dash carries that height.
		local last = view.snaps[#view.snaps]
		local y = last and last.at >= d.at and last.y or L.oy
		return L.ox + d.dx * travelled, y, L.oz + d.dz * travelled, d.dx, d.dz
	end
	if view.mode == "leap" and view.leap then
		local l = view.leap
		local t = (at - l.at) / math.max(l.landAt - l.at, 1e-3)
		local x, y, z = Config.arc(l.from.x, l.from.y, l.from.z, l.to.x, l.to.y, l.to.z, l.height, t)
		local dx, dz = Config.unit(l.to.x - l.from.x, l.to.z - l.from.z)
		return x, y, z, dx or view.dx, dz or view.dz
	end
	local snaps = view.snaps
	local renderAt = at - (view.behind or BEHIND)
	local a, b = snaps[1], snaps[1]
	for i = 1, #snaps do
		if snaps[i].at <= renderAt then a = snaps[i]; b = snaps[i + 1] or snaps[i] end
	end
	if not a then return nil end
	local span = b.at - a.at
	local t = span > 1e-3 and math.clamp((renderAt - a.at) / span, 0, 1) or 1
	return a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t, b.dx or a.dx, b.dz or a.dz
end

-- Wave 2: Gaze's exposure overlay. Four soft violet edges (a vignette that never covers the centre, never a blackout),
-- a small meter with its word, and a light blur capped at MaxScreenBlurSize that Efectos suaves leaves out.
local GAZE = Config.BEASTS.Gaze.tuning
local vignette = Instance.new("Frame")
vignette.Name = "GazeVignette"
vignette.BackgroundTransparency = 1
vignette.Size = UDim2.fromScale(1, 1)
vignette.Visible = false
vignette.Parent = gui
local edges = {}
for i, spec in ipairs({ { 0, 0, 1, 0.22, 90 }, { 0, 0.78, 1, 0.22, -90 }, { 0, 0, 0.18, 1, 0 }, { 0.82, 0, 0.18, 1, 180 } }) do
	local edge = Instance.new("Frame")
	edge.Name = "Edge" .. i
	edge.BorderSizePixel = 0
	edge.BackgroundColor3 = TELL_COLOR.Gaze
	edge.Position = UDim2.fromScale(spec[1], spec[2])
	edge.Size = UDim2.fromScale(spec[3], spec[4])
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = spec[5]
	gradient.Transparency = NumberSequence.new(0, 1)
	gradient.Parent = edge
	edge.Parent = vignette
	table.insert(edges, edge)
end
local meter = Instance.new("TextLabel")
meter.Name = "GazeMeter"
meter.AnchorPoint = Vector2.new(0.5, 0)
meter.Position = UDim2.fromScale(0.5, 0.24)
meter.Size = UDim2.fromScale(0.3, 0.04)
meter.BackgroundColor3 = Color3.fromRGB(30, 20, 45)
meter.BackgroundTransparency = 0.3
meter.TextScaled = true
meter.Font = Enum.Font.FredokaOne
meter.TextColor3 = Color3.fromRGB(240, 225, 255)
-- UI colorida: stroked words in a rounded, outlined meter.
meter.TextStrokeColor3, meter.TextStrokeTransparency = Color3.fromRGB(16, 18, 34), 0
Instance.new("UICorner", meter).CornerRadius = UDim.new(0, 8)
do
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color, edge.Thickness = Color3.fromRGB(16, 18, 34), 3
	edge.Parent = meter
end
meter.Visible = false
meter.Parent = gui
local meterFill = Instance.new("Frame")
meterFill.Name = "Fill"
meterFill.BorderSizePixel = 0
meterFill.BackgroundColor3 = TELL_COLOR.Gaze
meterFill.BackgroundTransparency = 0.2
meterFill.Size = UDim2.fromScale(0, 1)
meterFill.ZIndex = 0
meterFill.Parent = meter
local blur = Instance.new("BlurEffect")
blur.Name = "WildboundGazeBlur"
blur.Size = 0
blur.Enabled = false

-- Lurker's footprints and the stun stars: client-made, short-lived, kept in the view's extras folder.
local function footprint(view, x, y, z)
	local mark = Instance.new("Part")
	mark.Name = "Footprint"
	mark.Size = Vector3.new(0.7, 0.06, 1)
	mark.CFrame = CFrame.lookAt(Vector3.new(x, y + 0.05, z), Vector3.new(x + view.dx, y + 0.05, z + view.dz))
	mark.Color = TELL_COLOR.Lurker
	mark.Material = Enum.Material.Neon
	mark.Transparency = 0.35
	quiet(mark)
	mark.Parent = view.extras
	task.delay(6, function() mark:Destroy() end)
end

local function stars(view, x, y, z, at)
	view.stars = view.stars or {}
	for i = 1, 3 do
		local star = view.stars[i]
		if not star then
			star = Instance.new("Part")
			star.Name = "Star" .. i
			star.Shape = Enum.PartType.Ball
			star.Size = Vector3.new(0.6, 0.6, 0.6)
			star.Color = Color3.fromRGB(255, 240, 150)
			star.Material = Enum.Material.Neon
			quiet(star)
			star.Parent = view.extras
			view.stars[i] = star
		end
		local a = at * 4 + i * math.pi * 2 / 3
		local radius = STAR_HEIGHT[view.beast] and 2.6 or 1.8
		star.CFrame = CFrame.new(x + math.cos(a) * radius, y + (STAR_HEIGHT[view.beast] or 6), z + math.sin(a) * radius)
	end
end

-- SC8: Scuttler's pulse ring: PULSE_RINGS thin rings ripple out from its centre to the drawn radius (item.shape.r, the
-- server's own circle), faster toward the release. Kept inside the tell's model, so a redraw or its end removes them.
local PULSE_RINGS, PULSE_SEGMENTS = 2, 20
local function pulseRings(view, item, at)
	local shape = item.shape
	local r = item.shape.r
	if type(r) ~= "number" or r <= 0 then return end
	item.pulse = item.pulse or {}
	local span = math.max((item.strikeAt or at) - (item.startAt or at), 0.1)
	local progress = math.clamp((at - (item.startAt or at)) / span, 0, 1)
	local made = false
	for k = 1, PULSE_RINGS do
		local parts = item.pulse[k]
		if not parts or not parts[1] or parts[1].Parent ~= item.model then
			parts = {}
			for i = 1, PULSE_SEGMENTS do
				parts[i] = piece(item.model, ("Pulse%dSeg%d"):format(k, i), Vector3.new(0.3, 0.12, 1), CFrame.new(),
					TELL_COLOR.Scuttler, 0.2)
			end
			item.pulse[k] = parts
			made = true
		end
		-- About two ripples a second at the start, four at the release.
		local phase = (progress * (2 + 2 * progress) * span + (k - 1) / PULSE_RINGS) % 1
		local radius = math.max(r * phase, 0.3)
		local alpha = 0.85 - 0.6 * phase -- brightest as it reaches the true radius
		if view.bystander then alpha = dim(alpha) end
		for i, p in ipairs(parts) do
			local a0, a1 = (i - 1) / PULSE_SEGMENTS * math.pi * 2, i / PULSE_SEGMENTS * math.pi * 2
			local a = Vector3.new(shape.x + math.cos(a0) * radius, shape.y + 0.2, shape.z + math.sin(a0) * radius)
			local b = Vector3.new(shape.x + math.cos(a1) * radius, shape.y + 0.2, shape.z + math.sin(a1) * radius)
			p.Size = Vector3.new(0.3, 0.12, math.max((b - a).Magnitude, 0.05))
			p.CFrame = CFrame.lookAt((a + b) / 2, b)
			p.Transparency = alpha
		end
	end
	if made then soften(view, item.model) end
end

local function clearStars(view)
	for _, star in ipairs(view.stars or {}) do star:Destroy() end
	view.stars = nil
end

-- Posture per phase (the model keeps its place; the tells stay where the server put them).
local function posture(view, base, at)
	local phase = view.phase
	if phase == "Warn" then
		local s = reduced() and 0 or 0.12
		return base * CFrame.new((math.random() - 0.5) * s, -0.2, 0)
	elseif phase == "ScreamCharge" or phase == "PulseCharge" then
		-- Scuttler rears up for its pulse (SC8), like the Streamer before its scream.
		return base * CFrame.Angles(math.rad(14), 0, 0)
	elseif phase == "RushTelegraph" or phase == "LeapWindup" or phase == "ChargeTell" or phase == "PunishTell"
		or phase == "FeintTell" then
		-- Scuttler's feint crouches exactly like its real windup (SC8): only the drawn lane tells them apart.
		return base * CFrame.new(0, -0.5, 0.5) * CFrame.Angles(math.rad(-10), 0, 0)
	elseif phase == "Stunned" or phase == "OverrunStunned" or phase == "Fallen" then
		return base * CFrame.Angles(0, 0, math.rad(22))
	elseif phase == "Rise" and view.phaseUntil then
		local left = math.clamp((view.phaseUntil - at) / math.max(view.phaseUntil - view.phaseAt, 1e-3), 0, 1)
		return base * CFrame.new(0, -5 * left, 0)
	elseif view.beast == "Gaze" then
		return base * CFrame.new(0, 1.5 + math.sin(at * 1.2) * 0.4, 0)
	elseif Config.SUMMONED[view.beast] and not Config.BEASTS[view.beast].grounded then
		-- The Nube and the Abeja bob gently over their ground pivot.
		return base * CFrame.new(0, math.sin(at * 1.6) * 0.5, 0)
	end
	return base
end

local lastObserve = 0

-- Heartbeat, not RenderStepped: it also runs when the window does not render (Studio in the background), so the
-- beast keeps its place and the warning still clears; the parts are anchored and client-only either way.
RunService.Heartbeat:Connect(function()
	local at = serverNow()
	local exposure, observing = 0, false
	for _, view in pairs(views) do
		local x, y, z, dx, dz = placeOf(view, at)
		if x and view.model then
			if dx and (dx ~= 0 or dz ~= 0) then view.dx, view.dz = dx, dz end
			local look = Vector3.new(view.dx, 0, view.dz)
			local base = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x, y, z) + look)
			-- Windup: the body coils back and low; the tells stay where the server put them.
			if view.mode == "windup" then base *= CFrame.new(0, -0.3, 0.6) * CFrame.Angles(math.rad(-8), 0, 0) end
			if view.wave2 and not view.rigged then base = posture(view, base, at) end
			view.model:PivotTo(base)
		end
		if view.wave2 then
			if Config.OBSERVERS[view.beast] and not view.bystander then observing = true end
			if view.beast == "Gaze" then exposure = math.max(exposure, view.exposure or 0) end
			-- Root's walls rise at their scheduled time and hold this player back on this client only.
			for _, item in pairs(view.tells) do
				if item.shape and item.shape.kind == "walls" and not item.raised and item.strikeAt and at >= item.strikeAt then
					item.raised = true
					drawShape(item.model, item.shape, TELL_COLOR.Root, true)
					for _, part in ipairs(item.model:GetChildren()) do
						if part:GetAttribute("Wall") then part.Material = Enum.Material.Wood end
					end
					soften(view, item.model)
					-- SC0: Root's walls hold back only the target; a bystander's stay see-through and never collide.
					if not view.bystander then raiseWalls(item.model) end
					if not view.bystander then play("creak", rootOf(view), 1.4, 1) end
				end
			end
			if x and view.beast == "Lurker" and (view.phase == "Presence" or view.phase == "CoverApproach") then
				local lastPrint = view.lastPrint
				if not lastPrint or (Vector3.new(x, 0, z) - lastPrint).Magnitude >= 1.6 then
					view.lastPrint = Vector3.new(x, 0, z)
					footprint(view, x, y, z)
				end
			end
			if view.beast == "Scuttler" then
				for _, item in pairs(view.tells) do
					if item.shape and item.shape.kind == "circle" and not item.zone and item.strikeAt and at < item.strikeAt then
						pulseRings(view, item, at)
					end
				end
			end
			if x and view.stunUntil and at < view.stunUntil then stars(view, x, y, z, at)
			elseif view.stars then clearStars(view) end
		end
		if view.laneSpec and view.lane and not view.laneSpec.locked then drawLane(view) end
		if view.laneSpec and view.lane and not view.laneSpec.locked then drawLane(view) end
		if view.circleSpec and view.circle then
			if not view.circleSpec.frozen then drawCircle(view) end
			-- A pulse on the ring that quickens toward the landing.
			local left = math.max(view.circleSpec.landAt - at, 0)
			local pulse = 0.1 + 0.3 * (0.5 + 0.5 * math.sin(at * (8 + 12 / (left + 0.3))))
			if view.bystander then pulse = dim(pulse) end
			for i = 1, RING do view.circle["Ring" .. i].Transparency = pulse end
		end
		if view.fadeFrom then fadeModel(view, math.clamp((os.clock() - view.fadeFrom) / 0.9, 0, 1)) end
	end
	if warning.Visible and at >= warningUntil then warning.Visible = false end
	-- Gaze's overlay follows the server's exposure meter (never the local camera).
	vignette.Visible = exposure > 0.01
	meter.Visible = exposure > 0.01
	if exposure > 0.01 then
		for _, edge in ipairs(edges) do edge.BackgroundTransparency = 1 - 0.55 * exposure end
		meterFill.Size = UDim2.fromScale(exposure, 1)
		local words = Text.BEAST.Gaze
		meter.Text = words and words.meter or ""
	end
	local wantBlur = exposure > 0.01 and not reduced()
	blur.Parent = wantBlur and workspace.CurrentCamera or nil
	blur.Enabled = wantBlur
	blur.Size = wantBlur and math.min(GAZE.MaxScreenBlurSize, GAZE.MaxScreenBlurSize * exposure) or 0
	-- The only message this client sends: the camera's look vector, while it draws a Gaze or a Lurker.
	if observing and observeEvent and os.clock() - lastObserve >= Sight.SEND_INTERVAL then
		lastObserve = os.clock()
		local camera = workspace.CurrentCamera
		if camera then
			local v = camera.CFrame.LookVector
			observeEvent:FireServer({ x = v.X, y = v.Y, z = v.Z })
		end
	end
end)

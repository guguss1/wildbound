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
local Config = require(ReplicatedStorage:WaitForChild("WildboundBeastConfig"))
local Catalog = require(ReplicatedStorage:WaitForChild("WildboundAudioCatalog"))
local Text = require(ReplicatedStorage:WaitForChild("WildboundText"))

local player = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild("WildboundNetwork")
local beastEvent = network:WaitForChild("BeastEvent")

-- Client-made, so it exists on this client only.
local folder = Instance.new("Folder")
folder.Name = "WildboundBeastsLocal"
folder.Parent = workspace

local RED = Color3.fromRGB(255, 40, 30)
local BEHIND = 0.1 -- render this far behind the server clock, between two snapshots
local views = {}

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
warning.Font = Enum.Font.GothamBlack
warning.TextColor3 = Color3.fromRGB(255, 235, 225)
warning.TextStrokeColor3 = Color3.fromRGB(150, 0, 0)
warning.TextStrokeTransparency = 0
warning.Visible = false
warning.Parent = gui
gui.Parent = player:WaitForChild("PlayerGui")
local warningUntil = 0
local function showWarning(beast, untilAt)
	local words = Text.BEAST[beast]
	if not words then return end
	warning.Text = words.warn
	warning.Visible = true
	warningUntil = math.max(warningUntil, untilAt)
end

-- Sounds: existing catalogue ids only (WildboundAudioCatalog), on the beast so they come from its direction.
local function play(slot, parent, pitch, volume)
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

local function finishView(id)
	local view = views[id]
	if not view then return end
	views[id] = nil
	clearLane(view)
	clearCircle(view)
	if view.model then view.model:Destroy() end
end

local function rootOf(view) return view.model and view.model.PrimaryPart end

local handlers = {}
function handlers.Spawn(ev)
	finishView(ev.id)
	local template = visualFor(ev.beast)
	local view = { beast = ev.beast, snaps = {}, mode = "snap", dx = ev.dx or 0, dz = ev.dz or 1 }
	if template then
		view.model = template:Clone()
		for _, d in ipairs(view.model:GetDescendants()) do if d:IsA("BasePart") then quiet(d) end end
		view.model.Parent = folder
	end
	table.insert(view.snaps, { at = ev.at, x = ev.pos.x, y = ev.pos.y, z = ev.pos.z, dx = view.dx, dz = view.dz })
	views[ev.id] = view
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
	if view.lane then view.lane.Fill.Transparency = 0.35 end
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
function handlers.Hit(_, view)
	play("hit", rootOf(view), 1, 1)
	shake(0.5)
end
function handlers.Cancel(_, view)
	clearCircle(view)
	clearLane(view)
	warningUntil = 0
end
function handlers.Disengage(_, view)
	view.fadeFrom = os.clock()
	clearCircle(view)
	clearLane(view)
end
function handlers.End(ev)
	finishView(ev.id)
end

beastEvent.OnClientEvent:Connect(function(ev)
	if type(ev) ~= "table" or type(ev.id) ~= "string" or type(ev.type) ~= "string" then return end
	local handler = handlers[ev.type]
	if not handler then return end
	local view = views[ev.id]
	if ev.type ~= "Spawn" and ev.type ~= "End" and not view then return end
	handler(ev, view)
end)

-- Where the beast is now: the dash and the leap follow the server's own timeline; otherwise between two snapshots.
local function placeOf(view, at)
	if view.mode == "dash" and view.dash then
		local d = view.dash
		local L = view.laneSpec
		local travelled = math.clamp((at - d.at) * d.speed, 0, d.length)
		return L.ox + d.dx * travelled, L.oy, L.oz + d.dz * travelled, d.dx, d.dz
	end
	if view.mode == "leap" and view.leap then
		local l = view.leap
		local t = (at - l.at) / math.max(l.landAt - l.at, 1e-3)
		local x, y, z = Config.arc(l.from.x, l.from.y, l.from.z, l.to.x, l.to.y, l.to.z, l.height, t)
		local dx, dz = Config.unit(l.to.x - l.from.x, l.to.z - l.from.z)
		return x, y, z, dx or view.dx, dz or view.dz
	end
	local snaps = view.snaps
	local renderAt = at - BEHIND
	local a, b = snaps[1], snaps[1]
	for i = 1, #snaps do
		if snaps[i].at <= renderAt then a = snaps[i]; b = snaps[i + 1] or snaps[i] end
	end
	if not a then return nil end
	local span = b.at - a.at
	local t = span > 1e-3 and math.clamp((renderAt - a.at) / span, 0, 1) or 1
	return a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t, b.dx or a.dx, b.dz or a.dz
end

-- Heartbeat, not RenderStepped: it also runs when the window does not render (Studio in the background), so the
-- beast keeps its place and the warning still clears; the parts are anchored and client-only either way.
RunService.Heartbeat:Connect(function()
	local at = serverNow()
	for _, view in pairs(views) do
		local x, y, z, dx, dz = placeOf(view, at)
		if x and view.model then
			if dx and (dx ~= 0 or dz ~= 0) then view.dx, view.dz = dx, dz end
			local look = Vector3.new(view.dx, 0, view.dz)
			local base = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x, y, z) + look)
			-- Windup: the body coils back and low; the tells stay where the server put them.
			if view.mode == "windup" then base *= CFrame.new(0, -0.3, 0.6) * CFrame.Angles(math.rad(-8), 0, 0) end
			view.model:PivotTo(base)
		end
		if view.laneSpec and view.lane and not view.laneSpec.locked then drawLane(view) end
		if view.circleSpec and view.circle then
			if not view.circleSpec.frozen then drawCircle(view) end
			-- A pulse on the ring that quickens toward the landing.
			local left = math.max(view.circleSpec.landAt - at, 0)
			local pulse = 0.1 + 0.3 * (0.5 + 0.5 * math.sin(at * (8 + 12 / (left + 0.3))))
			for i = 1, RING do view.circle["Ring" .. i].Transparency = pulse end
		end
		if view.fadeFrom then fadeModel(view, math.clamp((os.clock() - view.fadeFrom) / 0.9, 0, 1)) end
	end
	if warning.Visible and at >= warningUntil then warning.Visible = false end
end)

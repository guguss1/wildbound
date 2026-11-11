-- Fear pass (FA3, user: "scarier, faster; capturing must be an adrenaline rush; the parents chase and hit you"). A
-- client-only feel layer, driven by what the server already sends (the State remote's island and capture actions)
-- and what replicates (the island adults' Awake attribute, La Silueta's State), never by a request of its own:
--   a grab (a granted capture or an egg) -> "¡CORRE!", a red edge, a camera shake and field-of-view punch;
--   a parent wakes or chases you -> "¡PADRE DESPIERTO!"; its swing -> "¡VA A GOLPEARTE!" and a tighter screen;
--   a landed hit -> a push away from the adult, a red flash, a hard shake, the hit sound and the damage number;
--   La Silueta starts hunting you close by -> "TE VIO" and a black edge;
--   the heartbeat follows the nearest awake threat and the burst.
-- The numbers are pure rules in WildboundHudView (View.fear, View.threat, View.knockback). "Efectos suaves" (the
-- world interface's Reduced attribute) removes the shake and halves the rest. The audio client reads FearHeart and
-- FearCue from the world interface; the world client adds FearFov to its field of view.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local viewModule = ReplicatedStorage:WaitForChild("WildboundHudView", 10)
local textModule = ReplicatedStorage:WaitForChild("WildboundText", 10)
local worldGui = playerGui:WaitForChild("WildboundWorldUI", 30)
if not (viewModule and textModule and worldGui) then
	warn("Wildbound fear: view, text or world interface missing; fear effects off.")
	return
end
if playerGui:FindFirstChild("WildboundFearUI") then
	warn("Wildbound fear already exists; duplicate controller refused.")
	return
end
local View, Text = require(viewModule), require(textModule)
local WORDS = Text.FEAR or {}
-- NS7 (user decision 2026-11-10): the Amuleto is gone. Its fear relief belongs to the free Efectos suaves setting, which
-- removes the shake and halves the heartbeat, the red edge and the darkness (more than the Amuleto's x0.6 did).

local connections = {}
local function listen(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end
local function make(className, properties, parent)
	local instance = Instance.new(className)
	for key, value in pairs(properties) do instance[key] = value end
	instance.Parent = parent
	return instance
end

local gui = make("ScreenGui", { Name = "WildboundFearUI", ResetOnSpawn = false, DisplayOrder = 12,
	IgnoreGuiInset = true }, playerGui)
-- One set of screen edges: red for the burst and the hits, black when La Silueta has seen you.
local edges = make("Frame", { Name = "FearEdges", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
	Active = false, Visible = false }, gui)
local EDGES = {
	{ UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0), 90 }, { UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0.7), -90 },
	{ UDim2.fromScale(0.25, 1), UDim2.fromScale(0, 0), 0 }, { UDim2.fromScale(0.25, 1), UDim2.fromScale(0.75, 0), 180 },
}
local edgeFrames, edgeGradients = {}, {}
for _, edge in ipairs(EDGES) do
	local frame = make("Frame", { Size = edge[1], Position = edge[2], BorderSizePixel = 0, BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(170, 0, 0), Active = false }, edges)
	table.insert(edgeFrames, frame)
	table.insert(edgeGradients, make("UIGradient", { Rotation = edge[3] }, frame))
end
local flash = make("Frame", { Name = "HitFlash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(200, 0, 0),
	BackgroundTransparency = 1, BorderSizePixel = 0, Active = false }, gui)
local shout = make("TextLabel", { Name = "FearShout", AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.new(0.9, 0, 0, 64), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack, TextScaled = true, Text = "", TextColor3 = Color3.fromRGB(255, 60, 50),
	TextStrokeColor3 = Color3.fromRGB(0, 0, 0), TextStrokeTransparency = 0.2, Visible = false }, gui)
make("UITextSizeConstraint", { MaxTextSize = 56, MinTextSize = 22 }, shout)
local shoutScale = make("UIScale", { Scale = 1 }, shout)
local damage = make("TextLabel", { Name = "FearDamage", AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(200, 48), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack, TextSize = 40, Text = "", TextColor3 = Color3.fromRGB(255, 235, 235),
	TextStrokeColor3 = Color3.fromRGB(120, 0, 0), TextStrokeTransparency = 0, Visible = false }, gui)

local cues = {}
local shoutSerial = 0
local function displayShout(text, seconds)
	shoutSerial += 1
	local serial = shoutSerial
	shout.Text, shout.Visible, shout.TextTransparency, shout.TextStrokeTransparency = text, true, 0, 0.2
	shoutScale.Scale = 1.5
	TweenService:Create(shoutScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(seconds or 1.4, function()
		if serial ~= shoutSerial then return end
		local fade = TweenService:Create(shout, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 })
		fade:Play()
		fade.Completed:Once(function() if serial == shoutSerial then shout.Visible = false end end)
	end)
end
-- Shouts that arrive together (a grab that wakes the parents) are read one after another, each for at least
-- SHOUT_MIN seconds: "¡PADRE DESPIERTO!", then "¡CORRE!".
local SHOUT_MIN = 0.7
local shoutFree = 0
local function showShout(text, seconds)
	if type(text) ~= "string" or text == "" then return end
	local now = os.clock()
	local delay = math.max(0, shoutFree - now)
	shoutFree = now + delay + SHOUT_MIN
	if delay <= 0 then displayShout(text, seconds) else task.delay(delay, displayShout, text, seconds) end
end
local function showDamage(amount)
	damage.Text = (WORDS.damage or "-%d"):format(math.floor(amount + 0.5))
	damage.Visible, damage.TextTransparency, damage.TextStrokeTransparency = true, 0, 0
	damage.Position = UDim2.fromScale(0.5, 0.42)
	local rise = TweenService:Create(damage, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.fromScale(0.5, 0.33), TextTransparency = 1, TextStrokeTransparency = 1 })
	rise:Play()
end

-- A cue starts the burst on this client and tells the audio client (server time, like the hit hook).
local function trigger(kind, words, seconds)
	cues[kind] = os.clock()
	worldGui:SetAttribute("FearCue", kind)
	worldGui:SetAttribute("FearCueAt", workspace:GetServerTimeNow())
	showShout(words, seconds)
end

local function rootPart()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end
-- The awake island adult nearest to the player (the one that is chasing or just hit), or nil.
local function nearestAwakeAdult(root)
	local best, bestDistance
	for _, adult in ipairs(CollectionService:GetTagged("WildboundIslandAdult")) do
		local part = adult:IsA("Model") and adult.PrimaryPart
		if part and adult:GetAttribute("Awake") == true then
			local distance = (part.Position - root.Position).Magnitude
			if not bestDistance or distance < bestDistance then best, bestDistance = part, distance end
		end
	end
	return best, bestDistance
end

-- A landed adult hit: a push straight away from the adult (the client owns its character, so the push is applied
-- here; the server already dropped the cria and applied any damage), a red flash, the hit sound.
local lastHitAt = -math.huge
local function adultHit()
	lastHitAt = os.clock()
	trigger("hit", WORDS.hit, 1)
	worldGui:SetAttribute("LastHitSound", "hit")
	worldGui:SetAttribute("LastHitAt", workspace:GetServerTimeNow())
	local root = rootPart()
	local adult = root and nearestAwakeAdult(root)
	if root and adult then
		local x, z = View.knockback(root.Position.X, root.Position.Z, adult.Position.X, adult.Position.Z)
		if x then
			-- Airborne first: a running humanoid would cancel a sideways push on its next step.
			local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
			root.AssemblyLinearVelocity = Vector3.new(x, 18, z)
			worldGui:SetAttribute("FearKnockAt", workspace:GetServerTimeNow())
		end
	end
end

task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild("WildboundNetwork", 10)
	local state = folder and folder:WaitForChild("State", 10)
	if not (state and state:IsA("RemoteEvent")) or not gui.Parent then return end
	listen(state.OnClientEvent, function(payload)
		if type(payload) ~= "table" then return end
		local action = payload.action
		if (action == "Capture" or action == "Pickup") and payload.ok == true then
			trigger("grab", WORDS.run, 1.6)
		elseif action == "IslandWoke" or action == "IslandChase" then
			trigger("woke", WORDS.awake, 1.6)
		elseif action == "IslandStrike" then
			trigger("strike", WORDS.strike, 0.8)
		elseif action == "IslandCaught" then
			adultHit()
		end
	end)
end)

-- The damage number for any hit that hurts (an adult's or La Silueta's), on each new character.
local function watchHealth(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not (humanoid and humanoid:IsA("Humanoid")) then return end
	local last = humanoid.Health
	listen(humanoid.HealthChanged, function(health)
		if health < last - 0.5 and health >= 0 then
			showDamage(last - health)
			if os.clock() - lastHitAt > 1 then cues.hit = os.clock() end
		end
		last = health
	end)
end
if player.Character then task.spawn(watchHealth, player.Character) end
listen(player.CharacterAdded, function(character)
	cues = {}
	task.spawn(watchHealth, character)
end)

-- Fix pass (FP2, one Silueta per player): this player's own hunter, the model whose Owner is this player; never
-- anyone else's, so another player's chase never shouts, shakes or darkens this screen.
local function guardian()
	local map = workspace:FindFirstChild("WildboundP0")
	local runtime = map and map:FindFirstChild("WildboundWorldRuntime")
	if not runtime then return nil end
	for _, model in ipairs(runtime:GetChildren()) do
		if model.Name == "Silueta" and model:IsA("Model") and model:GetAttribute("Owner") == player.UserId then
			local body = model:FindFirstChild("Body")
			if body and body:IsA("BasePart") then return model, body end
		end
	end
	return nil
end
local THREAT_STATES = { Alert = true, Hunt = true, Telegraph = true }
local SEEN_RANGE = 90
local lastGuardianState, lastHeart, lastFov = nil, -1, -1
local rng = Random.new()
local function feel()
	local camera = workspace.CurrentCamera
	local root = rootPart()
	local now = os.clock()
	local reduced = worldGui:GetAttribute("Reduced") == true
	-- The nearest threat: La Silueta while it is after someone, or an awake island adult.
	local nearest = math.huge
	local model, body = guardian()
	if model and root then
		local stateName = model:GetAttribute("State")
		local distance = (body.Position - root.Position).Magnitude
		if THREAT_STATES[stateName] then nearest = math.min(nearest, distance) end
		if stateName == "Hunt" and lastGuardianState ~= "Hunt" and lastGuardianState ~= "Telegraph"
			and distance <= SEEN_RANGE then
			trigger("seen", WORDS.seen, 1.2)
		end
		lastGuardianState = stateName
	end
	if root then
		local _, adultDistance = nearestAwakeAdult(root)
		if adultDistance then nearest = math.min(nearest, adultDistance) end
	end
	local f = View.fear(cues, now, View.threat(nearest), reduced)
	-- The red edge beats with the heart; black wins when La Silueta has just seen you.
	local strength = math.max(f.red * (0.8 + 0.2 * math.sin(now * math.pi * 2 * (1 + f.heart))), f.dark)
	edges.Visible = strength > 0.01
	if edges.Visible then
		local color = f.dark > f.red and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(170, 0, 0)
		for index, frame in ipairs(edgeFrames) do
			frame.BackgroundColor3 = color
			edgeGradients[index].Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - strength),
				NumberSequenceKeypoint.new(1, 1) })
		end
	end
	flash.BackgroundTransparency = 1 - f.flash
	if camera and f.shake > 0.001 then
		camera.CFrame *= CFrame.new(rng:NextNumber(-f.shake, f.shake), rng:NextNumber(-f.shake, f.shake), 0)
	end
	-- Attributes change only in visible steps, so the audio and world clients are not woken every frame.
	local heart = math.floor(f.heart * 20 + 0.5) / 20
	if heart ~= lastHeart then
		lastHeart = heart
		worldGui:SetAttribute("FearHeart", heart)
	end
	local fov = math.floor(f.fov * 4 + 0.5) / 4
	if fov ~= lastFov then
		lastFov = fov
		worldGui:SetAttribute("FearFov", fov)
	end
end
RunService:BindToRenderStep("WildboundFear", Enum.RenderPriority.Camera.Value + 2, function()
	local ok, message = pcall(feel)
	if not ok then gui:SetAttribute("LastError", tostring(message)) end
end)

-- Stalk sightings (user: "Sí, armalo"): at dusk, night and dawn La Silueta is sometimes glimpsed at the edge of sight,
-- standing still just behind a trunk, off to the side; it tilts its head and is gone when looked at, approached, or
-- after a few seconds. A client-only copy of its art: no collision, no queries, no touch, nothing sent to the server,
-- so it can never hit, be heard by the guardian or change the game. Never while the real one is after this player,
-- near or in view; never in camp, the hub, on the spawn pad or on an island floor (View.STALK_KEEP_OUT), and never
-- staged while the player stands in the hub (View.inHub). The rules and the
-- numbers are in WildboundHudView (stalk*); "Efectos suaves": at most one per evening, twice as rare, no whisper.
local STALK_FIRST_WAIT = 20
local stalk = { nextAt = os.clock() + STALK_FIRST_WAIT, count = 0, phase = nil, shown = nil }
local coreCache
local function trunkCores()
	if coreCache and #coreCache > 0 then return coreCache end
	local list = {}
	local map = workspace:FindFirstChild("WildboundP0")
	for _, part in ipairs(map and map:GetDescendants() or {}) do
		if part:IsA("BasePart") and part.Name == "FK_TrunkCore" then
			table.insert(list, { x = part.Position.X, z = part.Position.Z, r = math.min(part.Size.X, part.Size.Z) / 2 })
		end
	end
	coreCache = list
	return list
end
local function silhouette()
	local model = guardian()
	local art = model and model:FindFirstChild("SiluetaVisual")
	local copy
	if art then
		local ok, made = pcall(function() return art:Clone() end)
		copy = ok and made or nil
	end
	if not copy then
		-- No art streamed in: a plain tall, thin dark figure with two red eyes.
		copy = Instance.new("Model")
		local body = make("Part", { Name = "Body", Size = Vector3.new(2.4, 16, 1.4), Color = Color3.fromRGB(8, 8, 10),
			Material = Enum.Material.SmoothPlastic }, copy)
		make("Part", { Name = "Head", Size = Vector3.new(2, 2.6, 1.6), Color = Color3.fromRGB(8, 8, 10),
			CFrame = body.CFrame * CFrame.new(0, 9.3, 0) }, copy)
		for _, side in ipairs({ -0.45, 0.45 }) do
			make("Part", { Name = "Eye", Size = Vector3.new(0.3, 0.3, 0.2), Color = Color3.fromRGB(235, 40, 30),
				Material = Enum.Material.Neon, CFrame = body.CFrame * CFrame.new(side, 9.5, -0.85) }, copy)
		end
		copy.PrimaryPart = body
	end
	for _, item in ipairs(copy:GetDescendants()) do
		-- Look pass: a sighting never copies the real one's horror grin (fix pass: nor the jaw part it sits on).
		if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("Sound") or item:IsA("Animator")
			or item.Name == "HorrorGrin" or item.Name == "HorrorJaw" then
			item:Destroy()
		end
	end
	local parts = {}
	for _, part in ipairs(copy:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			parts[part] = part.Transparency
			part.Transparency = 1
		end
	end
	-- Play finding: in the night fog the art's thin pale eye slit did not read at 39 studs. Two red eyes on a billboard
	-- that ignores the light (but not the trunks: AlwaysOnTop stays off) are what the player catches first.
	local eye
	for part in pairs(parts) do
		if part.Name:lower():find("eye") then eye = part break end
	end
	local dots = {}
	if eye then
		local board = make("BillboardGui", { Name = "StalkEyes", Adornee = eye, Size = UDim2.new(3, 0, 1, 0),
			LightInfluence = 0, AlwaysOnTop = false, MaxDistance = 120, ResetOnSpawn = false }, eye)
		for _, x in ipairs({ 0.2, 0.8 }) do
			local dot = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.5),
				Size = UDim2.fromScale(0.26, 0.75), BackgroundColor3 = Color3.fromRGB(255, 45, 30), BorderSizePixel = 0,
				BackgroundTransparency = 1 }, board)
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
			table.insert(dots, dot)
		end
	end
	parts[dots] = "dots"
	copy.Name = "WildboundStalkSighting"
	return copy, parts
end
local function fade(parts, to, seconds, done)
	local value = Instance.new("NumberValue")
	value.Value = to == 1 and 0 or 1
	value.Changed:Connect(function(k)
		for part, base in pairs(parts) do
			if base == "dots" then
				for _, dot in ipairs(part) do dot.BackgroundTransparency = k end
			elseif part.Parent then
				part.Transparency = base + (1 - base) * k
			end
		end
	end)
	local tween = TweenService:Create(value, TweenInfo.new(seconds), { Value = to == 1 and 1 or 0 })
	tween.Completed:Once(function()
		value:Destroy()
		if done then done() end
	end)
	tween:Play()
end
-- The ground under a spot: only colliding geometry counts (a tree crown or a sight-only trunk mesh is not ground).
local function groundAt(x, z, fromY, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = false
	params.RespectCanCollide = true
	local hit = workspace:Raycast(Vector3.new(x, fromY + 40, z), Vector3.new(0, -120, 0), params)
	if hit and hit.Material ~= Enum.Material.Water then return hit.Position.Y end
	return nil
end
local function vanish(why)
	local shown = stalk.shown
	stalk.shown = nil
	if not shown then return end
	gui:SetAttribute("StalkVanish", why)
	gui:SetAttribute("StalkShownFor", math.floor((os.clock() - shown.at) * 10 + 0.5) / 10)
	fade(shown.parts, 1, why == "Looked" and 0.15 or 0.4, function() shown.model:Destroy() end)
end
local function show(x, z, root)
	local ignore = { gui }
	if player.Character then table.insert(ignore, player.Character) end
	local y = groundAt(x, z, root.Position.Y, ignore)
	if not y or math.abs(y - root.Position.Y) > 12 then return false end
	local model, parts = silhouette()
	local box, size = model:GetBoundingBox()
	local lift = model:GetPivot().Position.Y - (box.Position.Y - size.Y / 2)
	local at = Vector3.new(x, y + lift, z)
	local face = Vector3.new(root.Position.X, at.Y, root.Position.Z)
	local base = CFrame.lookAt(at, face)
	model:PivotTo(base)
	model.Parent = workspace.CurrentCamera -- local to this client and out of every server-side cast
	stalk.shown = { model = model, parts = parts, at = os.clock(), x = x, z = z, base = base }
	fade(parts, 0, 0.5)
	worldGui:SetAttribute("StalkSpot", at)
	worldGui:SetAttribute("FearCue", "stalk")
	worldGui:SetAttribute("FearCueAt", workspace:GetServerTimeNow())
	return true
end
local function stalkStep()
	local now = os.clock()
	local phase = worldGui:GetAttribute("Phase")
	if phase ~= stalk.phase then
		-- A new evening: dusk, or the dark straight after the day (the Studio clock shift can skip dusk).
		if phase == "Dusk" or (stalk.phase == "Day" and phase ~= "Day") then stalk.count = 0 end
		stalk.phase = phase
	end
	local root, camera = rootPart(), workspace.CurrentCamera
	if not (root and camera) then return end
	local model, body = guardian()
	local guardianState = model and model:GetAttribute("State")
	local guardianDistance = body and (body.Position - root.Position).Magnitude or math.huge
	local reduced = worldGui:GetAttribute("Reduced") == true
	local shown = stalk.shown
	if shown then
		local toward = Vector3.new(shown.x, camera.CFrame.Position.Y, shown.z) - camera.CFrame.Position
		local look = camera.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		local lookDot = toward.Magnitude > 0.1 and flatLook.Magnitude > 0.1
			and flatLook.Unit:Dot(Vector3.new(toward.X, 0, toward.Z).Unit) or 0
		local age = now - shown.at
		local why = View.stalkVanish({ age = age, lookDot = lookDot, guardianState = guardianState,
			distance = Vector3.new(shown.x - root.Position.X, 0, shown.z - root.Position.Z).Magnitude })
		if why then
			vanish(why)
		elseif shown.model.Parent then
			-- A slow head tilt while it watches.
			shown.model:PivotTo(shown.base * CFrame.Angles(0, 0, math.rad(7) * math.sin(math.min(age, 2) * 0.8)))
		end
		return
	end
	if now < stalk.nextAt then return end
	local ok, reason = View.stalkAllowed({ phase = phase, count = stalk.count, reduced = reduced,
		guardianState = guardianState, guardianDistance = guardianDistance })
	if ok and View.inHub(root.Position.X, root.Position.Z) then ok, reason = false, "Hub" end
	-- Never while the real one is in view, even far away.
	if ok and body and guardianDistance < 160 then
		local toward = body.Position - camera.CFrame.Position
		if toward.Magnitude > 0.1 and camera.CFrame.LookVector:Dot(toward.Unit) > 0.5 then ok, reason = false, "InView" end
	end
	if not ok then
		gui:SetAttribute("StalkSkip", reason)
		stalk.nextAt = now + 3
		return
	end
	local look = camera.CFrame.LookVector
	local x, z = View.stalkSpot(root.Position.X, root.Position.Z, look.X, look.Z, trunkCores(), View.STALK_KEEP_OUT)
	if not (x and show(x, z, root)) then
		gui:SetAttribute("StalkSkip", "NoSpot")
		stalk.nextAt = now + 2
		return
	end
	stalk.count += 1
	gui:SetAttribute("StalkCount", stalk.count)
	gui:SetAttribute("StalkDistance", math.floor(Vector3.new(x - root.Position.X, 0, z - root.Position.Z).Magnitude * 10 + 0.5) / 10)
	local character = player.Character
	local carrying = character ~= nil and character:FindFirstChild("WildboundCarryCapsule") ~= nil
	local far = View.farFromHome(root.Position.X, root.Position.Z)
	local delaySeconds = View.stalkInterval(carrying, far, reduced, rng:NextNumber())
	gui:SetAttribute("StalkNextIn", math.floor(delaySeconds * 10 + 0.5) / 10)
	stalk.nextAt = now + delaySeconds
end
local stalkClock = 0
listen(RunService.Heartbeat, function(dt)
	stalkClock += dt
	if stalkClock < 0.1 then return end
	stalkClock = 0
	local ok, message = pcall(stalkStep)
	if not ok then gui:SetAttribute("StalkError", tostring(message)) end
end)
listen(player.CharacterAdded, function() vanish("Respawn") end)

-- Look pass: the server shows La Silueta's HorrorGrin while she hunts, warns and strikes (and hides it after); this
-- client only animates its arrival from the pure rule: a short pop, or with "Efectos suaves" a gentle fade, no pop.
local grinWatched
local function popGrin(grin)
	local face = grin:FindFirstChild("Face")
	local pop = face and face:FindFirstChild("Pop")
	if not (face and face:IsA("CanvasGroup") and pop and pop:IsA("UIScale")) then return end
	local shape = View.grinPop(worldGui:GetAttribute("Reduced") == true)
	local info = TweenInfo.new(shape.seconds, Enum.EasingStyle[shape.style], Enum.EasingDirection.Out)
	face.GroupTransparency, pop.Scale = shape.fromAlpha, shape.fromScale
	TweenService:Create(face, info, { GroupTransparency = 0 }):Play()
	if shape.fromScale ~= 1 then TweenService:Create(pop, info, { Scale = 1 }):Play() end
end
local function watchGrin()
	local model = guardian()
	local grin = model and model:FindFirstChild("HorrorGrin", true)
	-- Fix pass (FP1): the grin is a SurfaceGui on the HorrorJaw part fitted to her face (was a BillboardGui).
	if not grin or grin == grinWatched or not grin:IsA("SurfaceGui") then return end
	grinWatched = grin
	listen(grin:GetPropertyChangedSignal("Enabled"), function()
		if grin.Enabled then popGrin(grin) end
	end)
end
local grinClock = 1
listen(RunService.Heartbeat, function(dt)
	grinClock += dt
	if grinClock < 1 then return end
	grinClock = 0
	local ok, message = pcall(watchGrin)
	if not ok then gui:SetAttribute("GrinError", tostring(message)) end
end)

local function cleanup()
	for _, connection in ipairs(connections) do connection:Disconnect() end
	pcall(function() RunService:UnbindFromRenderStep("WildboundFear") end)
	if stalk.shown then stalk.shown.model:Destroy() end
	if gui.Parent then gui:Destroy() end
end
listen(script.Destroying, cleanup)
listen(worldGui.Destroying, cleanup)

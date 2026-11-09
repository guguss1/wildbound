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

local function guardian()
	local map = workspace:FindFirstChild("WildboundP0")
	local runtime = map and map:FindFirstChild("WildboundWorldRuntime")
	local model = runtime and runtime:FindFirstChild("Silueta")
	local body = model and model:FindFirstChild("Body")
	if model and body and body:IsA("BasePart") then return model, body end
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

local function cleanup()
	for _, connection in ipairs(connections) do connection:Disconnect() end
	pcall(function() RunService:UnbindFromRenderStep("WildboundFear") end)
	if gui.Parent then gui:Destroy() end
end
listen(script.Destroying, cleanup)
listen(worldGui.Destroying, cleanup)

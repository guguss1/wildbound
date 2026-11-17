-- Caramelo flyers (ServerStorage.WildboundCandyFlyers, run by WildboundCandyFlyersService): the Zumbidulces' looks on
-- this client only. Visual only: it never sends anything to the server. Each frame (RenderStepped) it places every bug
-- between the server's throttled steps (the bug model's At + Vel, a short extrapolation), flaps its wings (the Weld C0
-- of WingL / WingR, written locally), shakes it during the swarm's tell (hive Phase "Alert") and its pull-up (bug Phase
-- "Aim"), wobbles it while stunned, and plays a buzz per hive that rises when the swarm is awake. The buzz reuses the
-- game's insects loop (WildboundAudioCatalog insectsNight), pitched up: no new asset. It also shows the service's short
-- notices (the player attributes WildboundCandyFlyersNote / WildboundCandyFlyersNoteAt).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local folder = workspace:WaitForChild("WildboundCandyFlyers", 120)
if not folder then return end

local okCatalog, Catalog = pcall(function()
	return require(game:GetService("ReplicatedStorage"):WaitForChild("WildboundAudioCatalog", 30))
end)
local insects = okCatalog and type(Catalog) == "table" and Catalog.SOUNDS and Catalog.SOUNDS.insectsNight
local BUZZ_ID = insects and insects.ids[1] and ("rbxassetid://" .. tostring(insects.ids[1])) or nil -- no catalog: silent
local EXTRAPOLATE = 0.35 -- seconds past the last server update at most (review F-2: idle bugs update every ~0.25 s)
local FAR_STUDS = 200 -- review F-9: no per-frame work for a bug this far from the camera
local DIVE_EXTRAPOLATE = 0.1 -- seconds ahead at most while a bug pulls up or dives (its velocity turns sharply there)
local VANISH_FADE = 0.8 -- RC3: seconds of the fade while a swarm vanishes (the rules climb it for 1 s first)
local mixGroup = nil -- review F-8: the audio client's SoundGroup for this sound (SoundService.WildboundMix.<group>)
local bugs = {} -- [Model] = record
local hives = {} -- [Model] = { sound }

local function track(model)
	if bugs[model] then return end
	local body = model:FindFirstChild("Body")
	if not (body and body:IsA("BasePart")) then return end
	local wingL, wingR = body:FindFirstChild("Weld_WingL"), body:FindFirstChild("Weld_WingR")
	local rec = { body = body, wingL = wingL, wingR = wingR, baseL = wingL and wingL.C0, baseR = wingR and wingR.C0,
		look = Vector3.new(0, 0, -1), seed = math.random() * 10, parts = {}, alpha = 0 }
	-- RC3: the parts this client fades out while the swarm vanishes (hive Phase "Vanish"), never touched on the server
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(rec.parts, d) end
	end
	local function refresh()
		rec.at = model:GetAttribute("At")
		local vel = model:GetAttribute("Vel")
		rec.vel = typeof(vel) == "Vector3" and vel or Vector3.zero
		rec.gotAt = os.clock()
	end
	rec.conn = model:GetAttributeChangedSignal("At"):Connect(refresh)
	refresh()
	bugs[model] = rec
end

local function hiveSound(hive)
	if hives[hive] then return hives[hive] end
	if not BUZZ_ID then return nil end
	local first = hive:FindFirstChild("Bug_1")
	local body = first and first:FindFirstChild("Body")
	if not body then return nil end
	local sound = Instance.new("Sound")
	sound.Name = "Buzz"
	sound.SoundId = BUZZ_ID
	sound.Looped, sound.Volume, sound.PlaybackSpeed = true, 0.25, 1.8
	sound.RollOffMinDistance, sound.RollOffMaxDistance = 6, 50
	if not mixGroup then
		local mix = game:GetService("SoundService"):FindFirstChild("WildboundMix")
		mixGroup = mix and mix:FindFirstChild(insects.group or "Ambient")
	end
	sound.SoundGroup = mixGroup
	sound.Parent = body
	sound:Play()
	hives[hive] = { sound = sound }
	return hives[hive]
end

local function scan()
	-- review F-5 (StreamingEnabled): a body or buzz that streamed out comes back as a new instance; track it again
	for model, rec in pairs(bugs) do if not rec.body.Parent then rec.conn:Disconnect() bugs[model] = nil end end
	for hive, h in pairs(hives) do if not h.sound.Parent then h.sound:Destroy() hives[hive] = nil end end
	for _, hive in ipairs(folder:GetChildren()) do
		if hive:IsA("Model") then
			hiveSound(hive)
			for _, child in ipairs(hive:GetChildren()) do
				if child:IsA("Model") then track(child) end
			end
		end
	end
	for model in pairs(bugs) do if not model:IsDescendantOf(folder) then bugs[model] = nil end end
	for hive in pairs(hives) do if not hive:IsDescendantOf(folder) then hives[hive] = nil end end
end
scan()
folder.ChildAdded:Connect(function() task.defer(scan) end)

local lastScan = os.clock()
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	if t - lastScan > 2 then lastScan = t scan() end
	for hive, h in pairs(hives) do
		local awake = hive:GetAttribute("Phase") == "Alert" or hive:GetAttribute("Phase") == "Chase"
		h.sound.PlaybackSpeed = awake and 2.4 or 1.8
		h.sound.Volume = awake and 0.55 or 0.25
	end
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	for model, rec in pairs(bugs) do
		if typeof(rec.at) == "Vector3" and rec.body.Parent and not (eye and (rec.at - eye).Magnitude > FAR_STUDS) then
			local phase = model:GetAttribute("Phase")
			local hivePhase = model.Parent and model.Parent:GetAttribute("Phase")
			-- Studio run 2026-11-16: a ~6.5-stud snap at a dive (0.35 s of the old velocity caught up at once); during the
			-- pull-up and the dive the guess ahead is short (DIVE_EXTRAPOLATE), so the bug never runs far past its new path
			local ahead = (phase == "Aim" or phase == "Dive") and DIVE_EXTRAPOLATE or EXTRAPOLATE
			local pos = rec.at + rec.vel * math.min(t - rec.gotAt, ahead)
			local flatVel = Vector3.new(rec.vel.X, 0, rec.vel.Z)
			if flatVel.Magnitude > 0.5 then rec.look = flatVel.Unit end
			local shake = CFrame.identity
			if hivePhase == "Alert" or phase == "Aim" then
				shake = CFrame.new(math.noise(t * 25, rec.seed) * 0.3, math.noise(rec.seed, t * 25) * 0.3, 0)
			elseif phase == "Stunned" then
				shake = CFrame.Angles(0, 0, math.sin(t * 9 + rec.seed) * 0.6)
			end
			rec.body.CFrame = CFrame.lookAt(pos, pos + rec.look) * shake
			local rate = (phase == "Stunned") and 6 or ((hivePhase == "Alert" or phase == "Aim") and 55 or 38)
			local flap = math.sin(t * rate + rec.seed) * 0.6
			if rec.wingL and rec.baseL then rec.wingL.C0 = rec.baseL * CFrame.Angles(0, 0, flap) end
			if rec.wingR and rec.baseR then rec.wingR.C0 = rec.baseR * CFrame.Angles(0, 0, -flap) end
			-- RC3: far from its hive at a give-up the swarm vanishes: fade it out over VANISH_FADE, back once it is home
			if hivePhase == "Vanish" then rec.vanishFrom = rec.vanishFrom or t else rec.vanishFrom = nil end
			local alpha = rec.vanishFrom and math.clamp((t - rec.vanishFrom) / VANISH_FADE, 0, 1) or 0
			if alpha ~= rec.alpha then
				rec.alpha = alpha
				for _, p in ipairs(rec.parts) do p.LocalTransparencyModifier = alpha end
			end
		end
	end
end)

-- The service's short notices: a small label at the top of the screen for a few seconds.
local gui = Instance.new("ScreenGui")
gui.Name = "WildboundCandyFlyersNotice"
gui.ResetOnSpawn = false
local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0.12, 0)
label.Size = UDim2.new(0.8, 0, 0, 36)
label.BackgroundColor3 = Color3.fromRGB(60, 20, 45)
label.BackgroundTransparency = 0.25
label.TextColor3 = Color3.fromRGB(255, 235, 245)
label.Font = Enum.Font.GothamBold
label.TextScaled = true
label.Visible = false
label.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = label
local limit = Instance.new("UITextSizeConstraint")
limit.MaxTextSize = 24
limit.Parent = label
gui.Parent = player:WaitForChild("PlayerGui")
local shown = 0
player:GetAttributeChangedSignal("WildboundCandyFlyersNoteAt"):Connect(function()
	local text = player:GetAttribute("WildboundCandyFlyersNote")
	if type(text) ~= "string" or text == "" then return end
	shown += 1
	local mine = shown
	label.Text, label.Visible = text, true
	task.delay(3, function() if shown == mine then label.Visible = false end end)
end)

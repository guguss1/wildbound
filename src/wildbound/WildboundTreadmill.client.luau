-- Client visuals, running animation, particles, audio, and progress UI for the interactive treadmill.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local STRIPE_COUNT = 8
local STRIPE_SPEED_ACTIVE = 1.8 -- canvas heights per second
local belts = {} -- [BasePart] = { stripes = { Frame }, statusLabel = TextLabel?, offset = number }
local runnerEffects = {} -- [Player] = { dust = ParticleEmitter, sweat = ParticleEmitter }
local runnerTracks = {} -- [Player] = { track = AnimationTrack?, character = Model }

local function getRunTrack(player, character)
	local entry = runnerTracks[player]
	if entry and entry.character == character and entry.track then
		return entry.track
	end
	if entry and entry.track then
		pcall(function() entry.track:Stop(0.1) end)
	end
	runnerTracks[player] = nil

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local animObj = nil
	local animateScript = character:FindFirstChild("Animate")
	local runFolder = animateScript and animateScript:FindFirstChild("run")
	if runFolder then
		animObj = runFolder:FindFirstChildWhichIsA("Animation")
	end
	local tempAnim = nil
	if not animObj then
		tempAnim = Instance.new("Animation")
		tempAnim.AnimationId = humanoid.RigType == Enum.RigType.R15 and "rbxassetid://913376220" or "rbxassetid://180426354"
		animObj = tempAnim
	end
	local ok, track = pcall(function()
		return animator:LoadAnimation(animObj)
	end)
	if tempAnim then tempAnim:Destroy() end
	if ok and track then
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		runnerTracks[player] = { track = track, character = character }
		return track
	end
	return nil
end

local function makeCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function dressConsole(belt)
	local parent = belt.Parent
	if not parent then return nil end
	local console = parent:FindFirstChild("TreadmillConsole") or parent:FindFirstChild("Console")
	if not console or not console:IsA("BasePart") then return nil end
	local existing = console:FindFirstChild("WildboundConsoleDisplay")
	if existing then
		return existing:FindFirstChild("Status", true)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "WildboundConsoleDisplay"
	gui.Face = Enum.NormalId.Back
	gui.LightInfluence = 0.15
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = console

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(16, 22, 32)
	bg.BorderSizePixel = 0
	bg.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -12, 0.42, 0)
	title.Position = UDim2.fromOffset(6, 6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "CAMINADORA"
	title.TextColor3 = Color3.fromRGB(190, 235, 255)
	title.TextScaled = true
	title.Parent = bg

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Size = UDim2.new(1, -12, 0.42, 0)
	status.Position = UDim2.new(0, 6, 0.5, 0)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.FredokaOne
	status.Text = "LISTA"
	status.TextColor3 = Color3.fromRGB(92, 240, 165)
	status.TextScaled = true
	status.Parent = bg

	return status
end

local function dressBelt(belt)
	if not belt:IsA("BasePart") or belts[belt] then return end
	local existing = belt:FindFirstChild("WildboundBeltSurface")
	if existing then existing:Destroy() end

	local surface = Instance.new("SurfaceGui")
	surface.Name = "WildboundBeltSurface"
	surface.Face = Enum.NormalId.Top
	surface.LightInfluence = 0.25
	surface.ClipsDescendants = true
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 32
	surface.Parent = belt

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(28, 30, 36)
	bg.BorderSizePixel = 0
	bg.ClipsDescendants = true
	bg.Parent = surface

	local stripes = {}
	for i = 1, STRIPE_COUNT do
		local bar = Instance.new("Frame")
		bar.Name = "Stripe" .. i
		bar.Size = UDim2.new(0.84, 0, 0.045, 0)
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.BackgroundColor3 = i % 2 == 0 and Color3.fromRGB(72, 200, 250) or Color3.fromRGB(58, 64, 74)
		bar.BackgroundTransparency = i % 2 == 0 and 0.35 or 0.15
		bar.BorderSizePixel = 0
		bar.Parent = bg
		makeCorner(bar, 4)
		table.insert(stripes, bar)
	end

	local statusLabel = dressConsole(belt)
	belts[belt] = { stripes = stripes, statusLabel = statusLabel, offset = 0 }

	belt.AncestryChanged:Connect(function()
		if not belt.Parent then belts[belt] = nil end
	end)
end

local function isTreadmillBelt(inst)
	if not inst:IsA("BasePart") then return false end
	if inst.Name == "TreadmillBelt" then return true end
	if inst.Name == "Belt" and inst.Parent and inst.Parent.Name == "WildboundTreadmill" then return true end
	return false
end

for _, inst in ipairs(workspace:GetDescendants()) do
	if isTreadmillBelt(inst) then dressBelt(inst) end
end
workspace.DescendantAdded:Connect(function(inst)
	if isTreadmillBelt(inst) then dressBelt(inst) end
end)

-- Running animation (procedural Motor6D.Transform on Stepped for R15 & R6).
local function setMotor(character, name, cf)
	local motor = character:FindFirstChild(name, true)
	if motor and motor:IsA("Motor6D") then
		motor.Transform = cf
	end
end

local function animateRunner(character, phase)
	local s = math.sin(phase)
	local c = math.cos(phase)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	if humanoid.RigType == Enum.RigType.R15 then
		local bob = math.abs(c) * 0.14
		setMotor(character, "Root", CFrame.new(0, bob, 0) * CFrame.Angles(math.rad(-8), 0, 0))
		setMotor(character, "UpperTorso", CFrame.Angles(math.rad(-6), s * 0.12, 0))
		setMotor(character, "LeftUpperLeg", CFrame.Angles(s * 0.85, 0, 0))
		setMotor(character, "RightUpperLeg", CFrame.Angles(-s * 0.85, 0, 0))
		setMotor(character, "LeftLowerLeg", CFrame.Angles(-math.max(0, -c) * 0.95 - 0.15, 0, 0))
		setMotor(character, "RightLowerLeg", CFrame.Angles(-math.max(0, c) * 0.95 - 0.15, 0, 0))
		setMotor(character, "LeftUpperArm", CFrame.Angles(-s * 0.8, 0, math.rad(-8)))
		setMotor(character, "RightUpperArm", CFrame.Angles(s * 0.8, 0, math.rad(8)))
		setMotor(character, "LeftLowerArm", CFrame.Angles(math.rad(45), 0, 0))
		setMotor(character, "RightLowerArm", CFrame.Angles(math.rad(45), 0, 0))
	else
		local bob = math.abs(c) * 0.14
		setMotor(character, "RootJoint", CFrame.new(0, bob, 0) * CFrame.Angles(math.rad(-8), 0, 0))
		setMotor(character, "Left Hip", CFrame.Angles(0, 0, -s * 0.85))
		setMotor(character, "Right Hip", CFrame.Angles(0, 0, -s * 0.85))
		setMotor(character, "Left Shoulder", CFrame.Angles(0, 0, s * 0.8))
		setMotor(character, "Right Shoulder", CFrame.Angles(0, 0, s * 0.8))
	end
end

local function ensureParticles(player, active)
	local existing = runnerEffects[player]
	if not active then
		if existing then
			if existing.dust then existing.dust:Destroy() end
			if existing.sweat then existing.sweat:Destroy() end
			runnerEffects[player] = nil
		end
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	if not root or not head then return end
	if existing and existing.dust and existing.dust.Parent == root then return end
	ensureParticles(player, false)

	local dust = Instance.new("ParticleEmitter")
	dust.Name = "WildboundTreadmillDust"
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(160, 235, 255), Color3.fromRGB(220, 240, 255))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.25, 0.45)
	dust.Rate = 18
	dust.Speed = NumberRange.new(3, 6)
	dust.EmissionDirection = Enum.NormalId.Back
	dust.SpreadAngle = Vector2.new(25, 25)
	dust.Parent = root

	local sweat = Instance.new("ParticleEmitter")
	sweat.Name = "WildboundTreadmillSweat"
	sweat.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sweat.Color = ColorSequence.new(Color3.fromRGB(140, 225, 255))
	sweat.Size = NumberSequence.new(0.22, 0)
	sweat.Lifetime = NumberRange.new(0.35, 0.55)
	sweat.Rate = 8
	sweat.Speed = NumberRange.new(2, 4)
	sweat.Acceleration = Vector3.new(0, -18, 0)
	sweat.SpreadAngle = Vector2.new(60, 60)
	sweat.Parent = head

	runnerEffects[player] = { dust = dust, sweat = sweat }
end

RunService.Stepped:Connect(function()
	local phase = os.clock() * 14
	for _, player in ipairs(Players:GetPlayers()) do
		local active = player:GetAttribute("WildboundOnTreadmill") == true
		ensureParticles(player, active)
		if active and player.Character then
			local track = getRunTrack(player, player.Character)
			if track then
				if not track.IsPlaying then
					track:Play(0.1, 1, 1.65)
				end
			else
				animateRunner(player.Character, phase)
			end
		else
			local entry = runnerTracks[player]
			if entry and entry.track and entry.track.IsPlaying then
				entry.track:Stop(0.15)
			end
		end
	end
end)

RunService.RenderStepped:Connect(function(dt)
	for belt, info in pairs(belts) do
		local active = belt:GetAttribute("WildboundRunner") ~= nil
		local speed = active and STRIPE_SPEED_ACTIVE or 0
		if speed > 0 then
			info.offset = (info.offset + dt * speed) % 1
		end
		for i, bar in ipairs(info.stripes) do
			local y = ((i - 1) / STRIPE_COUNT + info.offset) % 1
			bar.Position = UDim2.fromScale(0.5, y)
		end
		if info.statusLabel then
			info.statusLabel.Text = active and "CORRIENDO" or "LISTA"
			info.statusLabel.TextColor3 = active
				and Color3.fromRGB(72, 215, 255)
				or Color3.fromRGB(92, 240, 165)
		end
	end
end)

-- Treadmill audio & local HUD. Ids come only from WildboundAudioCatalog (delivery D9).
local catalogModule = ReplicatedStorage:WaitForChild("WildboundAudioCatalog", 10)
local Catalog = catalogModule and catalogModule:IsA("ModuleScript") and require(catalogModule)
local function catalogSound(slot)
	local entry = Catalog and Catalog.SOUNDS and Catalog.SOUNDS[slot]
	local sound = Instance.new("Sound")
	if entry then
		sound.SoundId = "rbxassetid://" .. entry.ids[1]
		sound.Looped = entry.loop
		sound.PlaybackSpeed = entry.pitch
	end
	return sound
end

local runSound = catalogSound("treadmillSteps")
runSound.Name = "WildboundTreadmillSteps"
runSound.Volume = 0.28
runSound.Parent = SoundService

local lapSound = catalogSound("treadmillLap")
lapSound.Name = "WildboundTreadmillLap"
lapSound.Volume = 0.5
lapSound.Parent = SoundService

local screen = Instance.new("ScreenGui")
screen.Name = "WildboundTreadmillGui"
screen.ResetOnSpawn = false
screen.DisplayOrder = 12
screen.Enabled = false
screen.Parent = playerGui

local card = Instance.new("Frame")
card.Name = "Card"
card.Size = UDim2.fromOffset(320, 118)
card.AnchorPoint = Vector2.new(0.5, 1)
card.Position = UDim2.new(0.5, 0, 1, -24)
card.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
card.BackgroundTransparency = 0.08
card.BorderSizePixel = 0
card.Parent = screen
makeCorner(card, 14)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(72, 200, 250)
stroke.Thickness = 2
stroke.Parent = card

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -24, 0, 24)
titleLabel.Position = UDim2.fromOffset(12, 8)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.FredokaOne
titleLabel.Text = "CAMINADORA · ENTRENAMIENTO"
titleLabel.TextColor3 = Color3.fromRGB(235, 248, 255)
titleLabel.TextSize = 17
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = card

local barBg = Instance.new("Frame")
barBg.Size = UDim2.new(1, -24, 0, 22)
barBg.Position = UDim2.fromOffset(12, 36)
barBg.BackgroundColor3 = Color3.fromRGB(32, 38, 56)
barBg.BorderSizePixel = 0
barBg.Parent = card
makeCorner(barBg, 8)

local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = Color3.fromRGB(72, 215, 255)
barFill.BorderSizePixel = 0
barFill.Parent = barBg
makeCorner(barFill, 8)

local pctLabel = Instance.new("TextLabel")
pctLabel.Size = UDim2.fromScale(1, 1)
pctLabel.BackgroundTransparency = 1
pctLabel.Font = Enum.Font.GothamBold
pctLabel.Text = "Corriendo... 0%"
pctLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
pctLabel.TextStrokeTransparency = 0.4
pctLabel.TextSize = 13
pctLabel.Parent = barBg

local dismountBtn = Instance.new("TextButton")
dismountBtn.Name = "Dismount"
dismountBtn.Size = UDim2.new(1, -24, 0, 38)
dismountBtn.Position = UDim2.fromOffset(12, 68)
dismountBtn.BackgroundColor3 = Color3.fromRGB(232, 84, 84)
dismountBtn.BorderSizePixel = 0
dismountBtn.Font = Enum.Font.FredokaOne
dismountBtn.Text = "Bajar (Espacio)"
dismountBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
dismountBtn.TextSize = 17
dismountBtn.Parent = card
makeCorner(dismountBtn, 10)

local treadmillRemote = nil
task.spawn(function()
	local network = ReplicatedStorage:WaitForChild("WildboundNetwork", 15)
	local remote = network and network:WaitForChild("Treadmill", 15)
	if remote and remote:IsA("RemoteEvent") then
		treadmillRemote = remote
		remote.OnClientEvent:Connect(function(kind)
			if kind == "lap" then
				lapSound:Play()
			end
		end)
	end
end)

local function requestDismount()
	if localPlayer:GetAttribute("WildboundOnTreadmill") == true and treadmillRemote then
		treadmillRemote:FireServer("dismount")
	end
end

dismountBtn.Activated:Connect(requestDismount)
UserInputService.JumpRequest:Connect(requestDismount)

local function syncMounted()
	local on = localPlayer:GetAttribute("WildboundOnTreadmill") == true
	screen.Enabled = on
	if on then
		if not runSound.IsPlaying then runSound:Play() end
	else
		if runSound.IsPlaying then runSound:Stop() end
	end
end

local function syncProgress()
	local p = localPlayer:GetAttribute("WildboundTreadmillProgress")
	local pct = type(p) == "number" and math.clamp(p, 0, 1) or 0
	barFill.Size = UDim2.fromScale(pct, 1)
	pctLabel.Text = string.format("Corriendo... %d%%", math.floor(pct * 100 + 0.5))
end

localPlayer:GetAttributeChangedSignal("WildboundOnTreadmill"):Connect(syncMounted)
localPlayer:GetAttributeChangedSignal("WildboundTreadmillProgress"):Connect(syncProgress)
syncMounted()
syncProgress()

Players.PlayerRemoving:Connect(function(player)
	ensureParticles(player, false)
end)
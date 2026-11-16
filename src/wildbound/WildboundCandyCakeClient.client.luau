-- PF6 (odd/tasks/wildbound-caramelo-playfix.md): what a bite of a Caramelo trap cake did, told to this player. The cake
-- service names it on the player (attribute WildboundCandyCakeSaid = "<what>:<serial>"): "rush" (a slice: a short
-- sugar rush the server already applies to the walk speed) or "eaten" (this player already ate from that cake this
-- round). This shows the WildboundText.CANDY_CAKE line on screen; a rush also plays a bright catalogue sound and a
-- burst of sparkles on the character. Nothing here changes the game; it only makes the bite readable.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Text = require(ReplicatedStorage:WaitForChild("WildboundText"))
local Catalog = require(ReplicatedStorage:WaitForChild("WildboundAudioCatalog"))
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "WildboundCandyCakeUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")
local line = Instance.new("TextLabel")
line.Name = "Line"
line.AnchorPoint = Vector2.new(0.5, 0)
line.Position = UDim2.new(0.5, 0, 0.26, 0)
line.Size = UDim2.new(0.8, 0, 0, 40)
line.BackgroundTransparency = 1
line.Font = Enum.Font.GothamBold
line.TextScaled = true
line.TextColor3 = Color3.fromRGB(255, 236, 160)
line.TextStrokeColor3 = Color3.fromRGB(150, 50, 110)
line.TextStrokeTransparency = 0.2
line.TextTransparency = 1
line.Parent = gui
local constraint = Instance.new("UITextSizeConstraint")
constraint.MaxTextSize = 34
constraint.Parent = line

local shown = 0
local fade -- the previous line's fade; a new line cancels it so it cannot hide the new words (PF6 review)
local function show(words)
	shown += 1
	local mine = shown
	if fade then fade:Cancel() end
	line.Text = words
	line.TextTransparency, line.TextStrokeTransparency = 0, 0.2
	task.delay(2.2, function()
		if shown ~= mine then return end
		fade = TweenService:Create(line, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 })
		fade:Play()
	end)
end

local function sparkle()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "WildboundSugarRush"
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Speed = NumberRange.new(4, 9)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
	emitter.LightEmission = 0.8
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 225, 120), Color3.fromRGB(255, 140, 200))
	emitter.Parent = root
	emitter:Emit(30)
	task.delay(1.5, function() emitter:Destroy() end)
end

local function chime()
	local slot = Catalog.SOUNDS.eggBanked
	if not slot then return end
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. tostring(slot.ids[1])
	sound.Volume = 0.6
	sound.PlaybackSpeed = 1.15
	sound.Parent = gui
	sound:Play()
	sound.Ended:Connect(function() sound:Destroy() end)
	task.delay(4, function() if sound.Parent then sound:Destroy() end end)
end

player:GetAttributeChangedSignal("WildboundCandyCakeSaid"):Connect(function()
	local value = player:GetAttribute("WildboundCandyCakeSaid")
	local what = type(value) == "string" and string.match(value, "^(%a+):") or nil
	local words = what and Text.CANDY_CAKE[what]
	if not words then return end
	show(words)
	if what == "rush" then
		chime()
		sparkle()
	end
end)

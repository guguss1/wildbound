-- Caramelo raft, the client side (docs/design/wildbound-caramelo-v3-plan.md V3-D13; Caramelo v4 V4-D3). Listens to
-- the server's ReplicatedStorage.WildboundNetwork.CandyRaftEvent ({ kind = "Boarded" | "Arrived" | "Left" |
-- "Called" | "Refused", reason }) and shows a short line; while the player rides, a short steering hint (W/S and A/D
-- on a keyboard, the thumbstick on touch: the default controls drive the raft's VehicleSeat, which the server reads)
-- and a large "Bajar" button (touch friendly; jumping works too) that asks the server to set them down
-- ({ action = "Leave" }). The server decides everything; this script only shows and asks. Free: no price is ever
-- shown. Words: WildboundText.CANDY_RAFT (steer and steerTouch fall back to the Spanish lines below until added).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Raft = require(ReplicatedStorage:WaitForChild("WildboundCandyRaft"))
local Text = require(ReplicatedStorage:WaitForChild("WildboundText"))
local network = ReplicatedStorage:WaitForChild("WildboundNetwork", 60)
local remote = network and network:WaitForChild(Raft.EVENT, 120)
if not remote then return end

local player = Players.LocalPlayer
local T = Text.CANDY_RAFT
local STEER = T.steer or "Usa W/S para avanzar y A/D para girar"
local STEER_TOUCH = T.steerTouch or "Mueve el joystick para guiar la balsa"
local REASON = { Busy = T.busy, Moving = T.moving, TooFar = T.tooFar, Dead = T.moving, Invalid = T.moving, Here = T.here }

local gui = Instance.new("ScreenGui")
gui.Name = "WildboundCandyRaftUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local line = Instance.new("TextLabel")
line.Name = "Line"
line.AnchorPoint = Vector2.new(0.5, 1)
line.Position = UDim2.new(0.5, 0, 1, -150)
line.Size = UDim2.new(0.8, 0, 0, 36)
line.BackgroundTransparency = 0.35
line.BackgroundColor3 = Color3.fromRGB(92, 52, 34)
line.TextColor3 = Color3.fromRGB(255, 247, 238)
line.Font = Enum.Font.FredokaOne
line.TextScaled = true
line.Visible = false
line.Parent = gui
local constraint = Instance.new("UITextSizeConstraint")
constraint.MaxTextSize = 26
constraint.Parent = line
local corner = Instance.new("UICorner")
corner.Parent = line

local leave = Instance.new("TextButton")
leave.Name = "Leave"
leave.AnchorPoint = Vector2.new(0.5, 1)
leave.Position = UDim2.new(0.5, 0, 1, -96)
leave.Size = UDim2.new(0, 160, 0, 48)
leave.BackgroundColor3 = Color3.fromRGB(242, 102, 139)
leave.TextColor3 = Color3.fromRGB(255, 255, 255)
leave.Font = Enum.Font.FredokaOne
leave.TextScaled = true
leave.Text = T.leave
leave.Visible = false
leave.Parent = gui
local leaveCorner = Instance.new("UICorner")
leaveCorner.Parent = leave

local shownAt = 0
local function show(message)
	if type(message) ~= "string" then return end
	line.Text = message
	line.Visible = true
	shownAt = os.clock()
	local mine = shownAt
	task.delay(2.5, function()
		if shownAt == mine then line.Visible = false end
	end)
end

-- V4-D3: the steering hint above the line while riding (a keyboard's keys, or the thumbstick on a touch screen)
local hint = line:Clone()
hint.Name = "SteerHint"
hint.Position = UDim2.new(0.5, 0, 1, -192)
hint.BackgroundTransparency = 0.5
hint.Parent = gui

local function steerHint(on)
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	hint.Text = touch and STEER_TOUCH or STEER
	hint.Visible = on
end

leave.Activated:Connect(function()
	remote:FireServer({ action = "Leave" })
end)

remote.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	if payload.kind == "Boarded" then
		leave.Visible = true
		steerHint(true)
		show(T.boarded)
	elseif payload.kind == "Arrived" then
		leave.Visible = false
		steerHint(false)
		show(T.arrived)
	elseif payload.kind == "Left" then
		leave.Visible = false
		steerHint(false)
		show(T.left)
	elseif payload.kind == "Called" then
		show(T.called)
	elseif payload.kind == "Refused" then
		show(REASON[payload.reason] or T.moving)
	end
end)

-- a respawned character never keeps the button
player.CharacterAdded:Connect(function()
	leave.Visible = false
	steerHint(false)
end)

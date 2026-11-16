-- Gold HUD (odd/tasks/wildbound-gold.md): the "Oro: N" counter, read from the player attribute WildboundGold that the
-- server's WildboundGoldService keeps, and the batched "+N oro" popup sent through the GoldPopup remote. View only:
-- the client never changes gold.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Text = require(ReplicatedStorage:WaitForChild("WildboundText"))
local T = Text.GOLD

local gui = Instance.new("ScreenGui")
gui.Name = "WildboundGoldUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local counter = Instance.new("TextLabel")
counter.Name = "GoldCounter"
counter.AnchorPoint = Vector2.new(1, 0)
counter.Position = UDim2.new(1, -12, 0, 8)
counter.Size = UDim2.fromOffset(130, 36)
counter.BackgroundColor3 = Color3.fromRGB(54, 40, 12)
counter.BackgroundTransparency = 0.15
counter.TextColor3 = Color3.fromRGB(255, 214, 90)
counter.Font = Enum.Font.FredokaOne
counter.TextSize = 22
counter.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = counter
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 200, 60)
stroke.Thickness = 2
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = counter

local function refresh()
	local gold = player:GetAttribute("WildboundGold")
	counter.Text = T.counter:format(type(gold) == "number" and gold or 0)
end
player:GetAttributeChangedSignal("WildboundGold"):Connect(refresh)
refresh()

local function popup(amount)
	local label = Instance.new("TextLabel")
	label.Name = "GoldPopup"
	label.AnchorPoint = Vector2.new(1, 0)
	label.Position = UDim2.new(1, -12, 0, 48)
	label.Size = UDim2.fromOffset(130, 30)
	label.BackgroundTransparency = 1
	label.Text = T.popup:format(amount)
	label.TextColor3 = Color3.fromRGB(255, 226, 120)
	label.TextStrokeTransparency = 0.2
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 24
	label.Parent = gui
	local tween = TweenService:Create(label, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.new(1, -12, 0, 80), TextTransparency = 1, TextStrokeTransparency = 1 })
	tween.Completed:Connect(function() label:Destroy() end)
	tween:Play()
end

local network = ReplicatedStorage:WaitForChild("WildboundNetwork", 30)
local remote = network and network:WaitForChild("GoldPopup", 30)
if remote then
	remote.OnClientEvent:Connect(function(amount)
		if type(amount) == "number" and amount > 0 then popup(math.floor(amount)) end
	end)
end

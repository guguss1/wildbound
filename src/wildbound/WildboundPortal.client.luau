-- CE3 / T08b: the return portals on screen. Presentation only: the server (WildboundPortalService) owns the prompt,
-- the calm check, the channel, the cooldown and the teleport, and its notices reach the HUD through the inventory
-- snapshot. This script draws the 2 s channel bar from the server's "PortalEvent" (Channel, Cut, Arrived, Refused) and,
-- on every portal prompt (tag WildboundPortalPrompt), shows the wait left from the server-written attribute
-- WildboundPortalReadyAt. It changes the prompt's words locally only and sends nothing to the server.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Text = require(ReplicatedStorage:WaitForChild("WildboundText"))
local player = Players.LocalPlayer
local P = Text.PORTAL

local gui = Instance.new("ScreenGui")
gui.Name = "WildboundPortal"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 21
gui.Parent = player:WaitForChild("PlayerGui")

-- The bar: bottom centre, above the hotbar, narrow enough for a phone (at most 70 % of the screen width).
local panel = Instance.new("Frame")
panel.Name = "Channel"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -150)
panel.Size = UDim2.new(0.7, 0, 0, 52)
panel.BackgroundColor3 = Color3.fromRGB(24, 16, 40)
panel.BackgroundTransparency = 0.15
panel.Visible = false
panel.Parent = gui
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(360, 52)
limit.Parent = panel
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel
local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(12, 4)
title.Size = UDim2.new(1, -24, 0, 22)
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(235, 225, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = P.channel
title.Parent = panel
local track = Instance.new("Frame")
track.Name = "Track"
track.Position = UDim2.new(0, 12, 0, 32)
track.Size = UDim2.new(1, -24, 0, 10)
track.BackgroundColor3 = Color3.fromRGB(60, 46, 90)
track.BorderSizePixel = 0
track.Parent = panel
local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.fromRGB(170, 120, 255)
fill.BorderSizePixel = 0
fill.Parent = track
for _, frame in ipairs({ track, fill }) do
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = frame
end

local channelStart, channelSeconds = nil, 0
local function hide()
	channelStart = nil
	panel.Visible = false
end

local network = ReplicatedStorage:WaitForChild("WildboundNetwork", 30)
local remote = network and network:WaitForChild("PortalEvent", 30)
if remote and remote:IsA("RemoteEvent") then
	remote.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then return end
		if payload.kind == "Channel" and type(payload.seconds) == "number" and payload.seconds > 0 then
			channelStart, channelSeconds = os.clock(), math.min(payload.seconds, 10)
			title.Text = P.channel
			fill.Size = UDim2.fromScale(0, 1)
			panel.Visible = true
		else
			hide()
		end
	end)
end
player.CharacterAdded:Connect(hide)

-- The wait on every portal prompt, from the server's attribute (server time).
local function promptText()
	local readyAt = player:GetAttribute("WildboundPortalReadyAt")
	local left = type(readyAt) == "number" and readyAt - workspace:GetServerTimeNow() or 0
	if left > 0 then return P.readyIn:format(math.ceil(left)) end
	return P.prompt
end

local promptClock = 0
RunService.RenderStepped:Connect(function(dt)
	if channelStart then
		local share = math.clamp((os.clock() - channelStart) / channelSeconds, 0, 1)
		fill.Size = UDim2.fromScale(share, 1)
		-- The server ends it (Arrived or Cut); a lost event never leaves the bar up.
		if os.clock() - channelStart > channelSeconds + 2 then hide() end
	end
	promptClock += dt
	if promptClock < 0.25 then return end
	promptClock = 0
	local words = promptText()
	for _, prompt in ipairs(CollectionService:GetTagged("WildboundPortalPrompt")) do
		if prompt:IsA("ProximityPrompt") and prompt.ActionText ~= words then prompt.ActionText = words end
	end
end)

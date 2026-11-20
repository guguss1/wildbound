-- Arrullo client (decision Q2b, docs/mechanics/wildbound-new-mechanics.md section 1). Deploy in
-- StarterPlayer.StarterPlayerScripts. Presentation and input only: the server (WildboundArrulloService) simulates the
-- session and sends this player its view on WildboundNetwork.Arrullo ("open", about 10 "view"s a second, "close").
-- This client sends only "hold" or "release", and only when the hold changes: the "Mantener" button (touch or mouse),
-- Space on a keyboard or A on a gamepad while the meter is open (bound high and sunk, so it never jumps meanwhile).
-- Original look: a lullaby meter (a vertical bar with a calm zone and a marker, and a calm meter beside it).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
if playerGui:FindFirstChild("WildboundArrulloUI") then
	warn("Wildbound Arrullo presentation already exists; duplicate controller refused.")
	return
end

local words, rarityWords = {}, {}
do
	local textModule = ReplicatedStorage:FindFirstChild("WildboundText")
	local ok, value = false, nil
	if textModule and textModule:IsA("ModuleScript") then ok, value = pcall(require, textModule) end
	if ok and type(value) == "table" and type(value.ARRULLO) == "table" then words = value.ARRULLO end
	if ok and type(value) == "table" and type(value.RARITY) == "table" then rarityWords = value.RARITY end
end
local ACTION = "WildboundArrulloHold"

local function make(className, properties, parent)
	local item = Instance.new(className)
	for key, value in pairs(properties) do item[key] = value end
	item.Parent = parent
	return item
end

local gui = make("ScreenGui", { Name = "WildboundArrulloUI", ResetOnSpawn = false, DisplayOrder = 12, Enabled = false },
	playerGui)
-- The meter sits on the right, at mid height, where a right thumb holds the button on a phone.
local panel = make("Frame", { Name = "Panel", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0),
	Size = UDim2.new(0, 132, 0.62, 0), BackgroundColor3 = Color3.fromRGB(22, 28, 40), BackgroundTransparency = 0.12 }, gui)
make("UICorner", { CornerRadius = UDim.new(0, 10) }, panel)
make("UISizeConstraint", { MinSize = Vector2.new(132, 250), MaxSize = Vector2.new(132, 440) }, panel)
make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(150, 170, 220), Transparency = 0.3 }, panel)
local title = make("TextLabel", { Name = "Title", BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 6),
	Size = UDim2.new(1, -16, 0, 24), Font = Enum.Font.GothamBold, TextSize = 17, TextScaled = false,
	TextColor3 = Color3.fromRGB(236, 240, 255), Text = words.title or "Arrullo" }, panel)
-- The bar (0 at the bottom, 1 at the top), its calm zone and the marker.
local bar = make("Frame", { Name = "Bar", Position = UDim2.fromOffset(16, 36), Size = UDim2.new(0, 46, 1, -132),
	BackgroundColor3 = Color3.fromRGB(40, 46, 70), ClipsDescendants = true }, panel)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, bar)
local zone = make("Frame", { Name = "Zone", BackgroundColor3 = Color3.fromRGB(150, 220, 190), BorderSizePixel = 0,
	BackgroundTransparency = 0.15, Size = UDim2.fromScale(1, 0.3), Position = UDim2.fromScale(0, 0.35) }, bar)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, zone)
local marker = make("Frame", { Name = "Marker", AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0,
	BackgroundColor3 = Color3.fromRGB(255, 240, 200), Size = UDim2.new(1, 8, 0, 8), Position = UDim2.fromScale(0.5, 1) }, bar)
make("UICorner", { CornerRadius = UDim.new(0, 4) }, marker)
-- The calm meter: fills from the bottom; win at the top, lose when it empties.
local meter = make("Frame", { Name = "Calm", Position = UDim2.fromOffset(78, 36), Size = UDim2.new(0, 22, 1, -132),
	BackgroundColor3 = Color3.fromRGB(40, 46, 70), ClipsDescendants = true }, panel)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, meter)
local fill = make("Frame", { Name = "Fill", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
	Size = UDim2.fromScale(1, 0.35), BackgroundColor3 = Color3.fromRGB(255, 196, 120), BorderSizePixel = 0 }, meter)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, fill)
local timeLabel = make("TextLabel", { Name = "Time", BackgroundTransparency = 1, Position = UDim2.new(0, 8, 1, -92),
	Size = UDim2.new(1, -16, 0, 22), Font = Enum.Font.GothamBold, TextSize = 16,
	TextColor3 = Color3.fromRGB(236, 240, 255), Text = "" }, panel)
local holdButton = make("TextButton", { Name = "HoldButton", Position = UDim2.new(0, 8, 1, -64), Size = UDim2.new(1, -16, 0, 56),
	BackgroundColor3 = Color3.fromRGB(96, 120, 190), TextColor3 = Color3.fromRGB(245, 247, 255), Font = Enum.Font.GothamBold,
	TextSize = 16, TextWrapped = true, AutoButtonColor = false, Text = words.hold or "Mantener" }, panel)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, holdButton)
-- The hint over the middle of the screen, wrapped, so it reads on a phone.
local hint = make("TextLabel", { Name = "Hint", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64),
	Size = UDim2.new(0.6, 0, 0, 48), BackgroundColor3 = Color3.fromRGB(22, 28, 40), BackgroundTransparency = 0.25,
	Font = Enum.Font.GothamBold, TextSize = 15, TextWrapped = true, TextColor3 = Color3.fromRGB(236, 240, 255),
	Text = words.hint or "" }, gui)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, hint)
make("UISizeConstraint", { MaxSize = Vector2.new(520, 60) }, hint)
-- UI colorida, then UR-A (owner request 2026-11-20, docs/design/refs/store-ui-reference.png): the kit's look. The panel
-- is the reference's bright blue window (a thick dark border, 16 px corners); the title and the time are white round
-- words with a thick dark outline that shrink to fit; the meters are dark wells with a thick border; Mantener is a
-- chunky glossy button with the 3D lip (orange, so it stands out on the blue window; green while held: setHolding
-- recolours it and the gloss stays); the hint
-- is a dark rounded panel. Without the shared style module (or with an older one, no Style.gloss) nothing changes.
do
	local styleModule = ReplicatedStorage:WaitForChild("WildboundUiStyle", 10)
	local Style = styleModule and require(styleModule)
	if Style and Style.gloss then
		Style.screen(gui)
		Style.dressPanel(panel, "blue", 0.04)
		Style.loudText(title)
		Style.fitText(title, 18, 10)
		Style.loudText(timeLabel, nil, nil, Style.COLORS.gold)
		Style.fitText(timeLabel, 18, 10)
		for _, item in ipairs({ bar, meter }) do
			item.BackgroundColor3 = Style.COLORS.panelDeep
			Style.outline(item, 3)
		end
		Style.shade(fill, 0.8)
		Style.outline(marker, 2)
		Style.gloss(holdButton, "orange")
		Style.fitText(holdButton, 20, 12)
		Style.dressPanel(hint, "dark", 0.1)
		Style.title(hint)
	end
end

local remote = nil
local open, holding = false, false
local target = { zoneLow = 0.35, zoneHigh = 0.65, marker = 0, progress = 0.35 }
local shown = { zoneLow = 0.35, zoneHigh = 0.65, marker = 0 }
local closeSerial = 0

local function setHolding(value)
	if value == holding then return end
	holding = value
	holdButton.BackgroundColor3 = holding and Color3.fromRGB(92, 214, 64) or Color3.fromRGB(255, 148, 32)
	if remote and open then remote:FireServer(holding and "hold" or "release") end
end

local function bindKeys()
	ContextActionService:BindActionAtPriority(ACTION, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			setHolding(true)
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			setHolding(false)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
end

local function unbindKeys()
	pcall(function() ContextActionService:UnbindAction(ACTION) end)
end

holdButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		setHolding(true)
	end
end)
holdButton.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		setHolding(false)
	end
end)
-- A finger or the mouse released anywhere (it may have slid off the button) also releases.
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		setHolding(false)
	end
end)
-- A lost focus never leaves the marker rising.
UserInputService.WindowFocusReleased:Connect(function() setHolding(false) end)

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function apply(payload)
	for _, key in ipairs({ "zoneLow", "zoneHigh", "marker", "progress" }) do
		if finite(payload[key]) then target[key] = math.clamp(payload[key], 0, 1) end
	end
	if finite(payload.remaining) then timeLabel.Text = (words.time or "%d s"):format(math.ceil(payload.remaining)) end
end

local function onPayload(payload)
	if type(payload) ~= "table" then return end
	if payload.kind == "open" then
		closeSerial += 1
		open, holding = true, false
		apply(payload)
		shown.zoneLow, shown.zoneHigh, shown.marker = target.zoneLow, target.zoneHigh, target.marker
		local tier = type(payload.rarity) == "string" and rarityWords[payload.rarity]
		title.Text = (words.title or "Arrullo") .. (tier and (" · " .. tier) or "")
		hint.Text, hint.Visible = words.hint or "", true
		holdButton.Text = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and (words.hold or "Mantener")
			or (words.holdKey or "Mantener (Espacio)")
		gui.Enabled = true
		bindKeys()
	elseif payload.kind == "view" and open then
		apply(payload)
	elseif payload.kind == "close" then
		apply(payload)
		setHolding(false)
		open = false
		unbindKeys()
		local line = payload.status == "won" and words.won or payload.reason == "Timeout" and words.timeout
			or payload.status == "lost" and words.lost or nil
		if line then hint.Text = line else gui.Enabled = false end
		closeSerial += 1
		local mine = closeSerial
		task.delay(1.6, function()
			if closeSerial == mine and not open then gui.Enabled = false end
		end)
	end
end

RunService.RenderStepped:Connect(function(dt)
	if not gui.Enabled then return end
	local alpha = math.clamp(dt * 14, 0, 1)
	for _, key in ipairs({ "zoneLow", "zoneHigh", "marker" }) do
		shown[key] += (target[key] - shown[key]) * alpha
	end
	local low, high = math.min(shown.zoneLow, shown.zoneHigh), math.max(shown.zoneLow, shown.zoneHigh)
	zone.Position, zone.Size = UDim2.fromScale(0, 1 - high), UDim2.fromScale(1, high - low)
	marker.Position = UDim2.fromScale(0.5, 1 - shown.marker)
	local inside = shown.marker >= low and shown.marker <= high
	marker.BackgroundColor3 = inside and Color3.fromRGB(190, 255, 220) or Color3.fromRGB(255, 200, 170)
	fill.Size = UDim2.fromScale(1, target.progress)
end)

task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild("WildboundNetwork", 15)
	local found = folder and folder:WaitForChild("Arrullo", 15)
	if not (found and found:IsA("RemoteEvent")) then return end
	remote = found
	remote.OnClientEvent:Connect(onPayload)
end)

gui.Destroying:Connect(unbindKeys)
-- Start screen, first-run tutorial card and Settings (W9, M8.5 and M8.6). Client presentation only: the state is
-- session-only, nothing is sent to the server and nothing is saved. Rectangles and words come from
-- WildboundStartView, the rules from WildboundSettings and WildboundTutorial (all contract-tested).
-- Test seams, local to this client: attribute Screen on WildboundStartUI ("start", "settings", "howto",
-- "closed") shows that screen; attribute TestSnapshot (a JSON string) replaces the state snapshot the tutorial
-- reads; attribute TestAction runs a button handler by name (play, openSettings, openHowto, back, toggleReduced,
-- toggleHints, replay, skip). None of them changes anything on the server. Read-only attributes: TutorialState, ReducedEffects, Hints.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("WildboundStartUI")
if old then old:Destroy() end

local function module(name)
	local found = ReplicatedStorage:WaitForChild(name, 10)
	return found and require(found) or nil
end
local Settings, Tutorial = module("WildboundSettings"), module("WildboundTutorial")
local View, Layout = module("WildboundStartView"), module("WildboundHudLayout")
if not (Settings and Tutorial and View and Layout) then
	warn("Wildbound start screen: a shared module is missing; the game starts without it.")
	return
end

local gui = Instance.new("ScreenGui")
gui.Name = "WildboundStartUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 30
gui.Parent = playerGui
local connections = {}
local function listen(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end
listen(gui.Destroying, function()
	for _, connection in ipairs(connections) do connection:Disconnect() end
end)

local ink = Color3.fromRGB(240, 244, 231)
local amber = Color3.fromRGB(255, 214, 120)
local dark = Color3.fromRGB(25, 34, 31)
local accent = Color3.fromRGB(77, 115, 88)
local accentOn = Color3.fromRGB(110, 150, 120)
local muted = Color3.fromRGB(190, 198, 190)

local function make(className, properties, parent)
	local instance = Instance.new(className)
	for key, value in pairs(properties) do instance[key] = value end
	instance.Parent = parent
	return instance
end
local function place(item, rect)
	item.Position, item.Size = UDim2.fromOffset(rect.x, rect.y), UDim2.fromOffset(rect.w, rect.h)
end
local function label(parent, rect, text, size, bold, color, center)
	local item = make("TextLabel", { BackgroundTransparency = 1, Text = text, TextColor3 = color or ink, TextSize = size,
		Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham, TextWrapped = true,
		TextXAlignment = center and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center }, parent)
	place(item, rect)
	return item
end
local function button(parent, rect, text, name, color, size)
	local item = make("TextButton", { Name = name, Text = text, BackgroundColor3 = color or accent, TextColor3 = ink,
		TextSize = size or 16, Font = Enum.Font.GothamBold, AutoButtonColor = true, TextWrapped = true }, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 7) }, item)
	place(item, rect)
	return item
end

local settings = Settings.new()
local tutorial = Tutorial.new()
local screen, playPressed = "start", false
local lastSnapshot, doneUntil = nil, 0
local worldGui = nil

local backdrop = make("Frame", { Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.4, Active = true, BorderSizePixel = 0 }, gui)
local panel = make("Frame", { Name = "Panel", BackgroundColor3 = dark, BorderSizePixel = 0 }, backdrop)
make("UICorner", { CornerRadius = UDim.new(0, 10) }, panel)
make("UIStroke", { Color = amber, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, panel)

local function currentLayout()
	local size = gui.AbsoluteSize
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	return Layout.compute(size.X, size.Y, { touch = touch })
end

local show
local function applyReduced(value)
	Settings.set(settings, "reducedEffects", value)
	if worldGui then worldGui:SetAttribute("Reduced", value) end
	gui:SetAttribute("ReducedEffects", value)
end
local function backTarget()
	return playPressed and "closed" or "start"
end

-- Every button handler is also reachable by name through the TestAction attribute: a local test seam for runs
-- where no tap or click can be sent. It calls the same functions and changes nothing on the server.
local actions = {}
actions.play = function() playPressed = true; show("closed") end
actions.openSettings = function() show("settings") end
actions.openHowto = function() show("howto") end
actions.back = function() show(backTarget()) end
local build
actions.toggleReduced = function() applyReduced(not Settings.get(settings, "reducedEffects")); build() end
actions.toggleHints = function()
	Settings.toggle(settings, "hints")
	gui:SetAttribute("Hints", Settings.get(settings, "hints"))
	build()
end
actions.replay = function()
	Tutorial.restart(tutorial)
	Settings.set(settings, "hints", true)
	gui:SetAttribute("Hints", true)
	show(backTarget())
end
actions.skip = function()
	Tutorial.skip(tutorial)
	gui:SetAttribute("TutorialState", Tutorial.state(tutorial))
end

build = function()
	for _, child in ipairs(panel:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	if screen == "closed" then return end
	local layout = currentLayout()
	if screen == "start" then
		local v = View.start(layout)
		place(panel, v.panel)
		label(panel, v.title, View.TEXT.title, 24, true, amber, true)
		label(panel, v.tagline, View.TEXT.tagline, View.TEXT_SIZE, false, ink, true)
		button(panel, v.play, "Jugar", "PlayButton", accentOn, 18).Activated:Connect(actions.play)
		button(panel, v.settings, "Ajustes", "SettingsButton").Activated:Connect(actions.openSettings)
		button(panel, v.howto, "Cómo jugar", "HowToButton").Activated:Connect(actions.openHowto)
		button(panel, v.reduced, Settings.buttonText("reducedEffects", Settings.get(settings, "reducedEffects")), "ReducedToggle").Activated:Connect(actions.toggleReduced)
		label(panel, v.note, View.TEXT.note, View.TEXT_SIZE, false, muted, true)
	elseif screen == "settings" then
		local descriptions = {}
		for _, key in ipairs(Settings.ORDER) do
			table.insert(descriptions, Settings.LABELS[key] .. ". " .. Settings.DESCRIPTIONS[key])
		end
		local v = View.settings(layout, descriptions)
		place(panel, v.panel)
		label(panel, v.title, View.TEXT.settingsTitle, 22, true, amber, true)
		for index, key in ipairs(Settings.ORDER) do
			local row = v.rows[index]
			label(panel, row.text, descriptions[index], View.TEXT_SIZE)
			local on = Settings.get(settings, key)
			button(panel, row.toggle, Settings.stateText(on), "Toggle_" .. key, on and accentOn or Color3.fromRGB(58, 68, 62)).Activated:Connect(
				key == "reducedEffects" and actions.toggleReduced or actions.toggleHints)
		end
		button(panel, v.replay, "Repetir tutorial", "ReplayButton").Activated:Connect(actions.replay)
		button(panel, v.back, "Volver", "BackButton").Activated:Connect(actions.back)
	elseif screen == "howto" then
		local v = View.howto(layout)
		place(panel, v.panel)
		label(panel, v.title, View.TEXT.howtoTitle, 22, true, amber, true)
		for index, text in ipairs(View.TEXT.howto) do label(panel, v.lines[index], text, View.TEXT_SIZE) end
		button(panel, v.back, "Volver", "BackButton").Activated:Connect(actions.back)
	end
end
show = function(name)
	screen = name
	backdrop.Visible = name ~= "closed"
	if gui:GetAttribute("Screen") ~= name then gui:SetAttribute("Screen", name) end
	build()
end

listen(gui:GetAttributeChangedSignal("Screen"), function()
	local wanted = gui:GetAttribute("Screen")
	if (wanted == "start" or wanted == "settings" or wanted == "howto" or wanted == "closed") and wanted ~= screen then
		if wanted == "closed" then playPressed = true end
		show(wanted)
	end
end)
listen(gui:GetAttributeChangedSignal("TestAction"), function()
	local name = gui:GetAttribute("TestAction")
	if type(name) == "string" and actions[name] then
		-- Cleared first, so the same action can be requested again (a same-value attribute set fires nothing).
		gui:SetAttribute("TestAction", nil)
		actions[name]()
	end
end)
listen(gui:GetPropertyChangedSignal("AbsoluteSize"), function() build() end)
listen(UserInputService:GetPropertyChangedSignal("KeyboardEnabled"), function() build() end)
listen(UserInputService.InputBegan, function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.M then
		if screen == "closed" then show("settings") elseif screen == "settings" then show(backTarget()) end
	end
end)

-- The world controller owns the Reduced effects value (attribute Reduced on WildboundWorldUI). This screen sets
-- it, and follows it when the HUD button changes it.
task.spawn(function()
	local found = playerGui:WaitForChild("WildboundWorldUI", 15)
	if not found or not gui.Parent then return end
	worldGui = found
	worldGui:SetAttribute("Reduced", Settings.get(settings, "reducedEffects"))
	listen(worldGui:GetAttributeChangedSignal("Reduced"), function()
		local value = worldGui:GetAttribute("Reduced")
		if type(value) == "boolean" and value ~= Settings.get(settings, "reducedEffects") then
			Settings.set(settings, "reducedEffects", value)
			gui:SetAttribute("ReducedEffects", value)
			build()
		end
	end)
end)

-- Tutorial card.
local card = make("Frame", { Name = "TutorialCard", BackgroundColor3 = dark, BackgroundTransparency = 0, Visible = false,
	BorderSizePixel = 0 }, gui)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, card)
make("UIStroke", { Color = amber, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
local cardText = make("TextLabel", { Name = "CardText", BackgroundTransparency = 1, TextColor3 = ink, Font = Enum.Font.Gotham,
	TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, Text = "" }, card)
local skip = button(card, { x = 0, y = 0, w = 64, h = 44 }, "Saltar", "SkipButton", Color3.fromRGB(58, 68, 62), 15)
local cardMode, cardKey = nil, nil
local function layoutCard()
	local geometry = View.card(currentLayout())
	cardMode = geometry.mode
	place(card, geometry.rect)
	place(cardText, geometry.text)
	place(skip, geometry.skip)
	cardText.TextSize = geometry.size
	cardKey = tostring(gui.AbsoluteSize)
end
local function compactNow() return currentLayout().mode == "compact" end

listen(skip.Activated, actions.skip)

local function snapshotNow()
	local seam = gui:GetAttribute("TestSnapshot")
	if type(seam) == "string" and seam ~= "" then
		local ok, decoded = pcall(function() return HttpService:JSONDecode(seam) end)
		if ok and type(decoded) == "table" then return decoded end
	end
	return lastSnapshot
end

-- The card is hidden while a full screen is up, while the inventory panel or a capture needs the space, and
-- when hints are off.
local function updateTutorial()
	local worldReady = playerGui:FindFirstChild("WildboundUI")
	local inventory = worldReady and worldReady:FindFirstChild("InventoryPanel")
	local tab = worldReady and worldReady:GetAttribute("PanelTab")
	if Tutorial.state(tutorial) == "running" then
		-- K1: the first step reads where the character stands (the clearing), the others the state snapshot.
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local at = root and root:IsA("BasePart") and { x = root.Position.X, z = root.Position.Z } or nil
		Tutorial.observe(tutorial, Tutorial.factsFrom(snapshotNow(), tab == "camp", at))
		if Tutorial.state(tutorial) == "done" then doneUntil = os.clock() + 5 end
	end
	local step = Tutorial.step(tutorial)
	gui:SetAttribute("TutorialState", step and step.id or Tutorial.state(tutorial))
	local hints = Settings.get(settings, "hints")
	local blocked = screen ~= "closed" or player:GetAttribute("WildboundCapturing") == true
		or (inventory and inventory.Visible == true)
	local finishing = Tutorial.state(tutorial) == "done" and os.clock() < doneUntil
	if (step or finishing) and hints and not blocked then
		if cardKey ~= tostring(gui.AbsoluteSize) or cardMode == nil then layoutCard() end
		cardText.Text = step and Tutorial.cardText(step, compactNow()) or Tutorial.DONE_TEXT
		skip.Visible = step ~= nil
		card.Visible = true
	else
		card.Visible = false
	end
end
listen(gui:GetPropertyChangedSignal("AbsoluteSize"), function() cardKey = nil end)

task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild("WildboundNetwork", 10)
	local state = folder and folder:WaitForChild("State", 10)
	if state and state:IsA("RemoteEvent") and gui.Parent then
		listen(state.OnClientEvent, function(payload)
			if type(payload) == "table" and type(payload.snapshot) == "table" then lastSnapshot = payload.snapshot end
		end)
	end
end)
task.spawn(function()
	while gui.Parent do
		updateTutorial()
		task.wait(0.25)
	end
end)

gui:SetAttribute("ReducedEffects", Settings.get(settings, "reducedEffects"))
gui:SetAttribute("Hints", Settings.get(settings, "hints"))
show("start")

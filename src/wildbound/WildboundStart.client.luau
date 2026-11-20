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

-- UI colorida: the shared look. Without the module every call is a no-op and the plain look stays. UR-H1: an older
-- module without the glossy kit (no Style.gloss, a partial Studio sync) counts as missing, so the screen never dies
-- half-built behind the full-screen backdrop.
local Style = module("WildboundUiStyle")
if not (type(Style) == "table" and type(Style.gloss) == "function") then
	Style = setmetatable({}, { __index = function() return function() end end })
end

local gui = Instance.new("ScreenGui")
gui.Name = "WildboundStartUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 30
Style.screen(gui)
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

-- UI colorida palette: white ink, gold, slate-navy panel, blue neutral buttons, lime green for "on" and Play.
local ink = Color3.fromRGB(255, 255, 255)
local amber = Color3.fromRGB(255, 214, 64)
local dark = Color3.fromRGB(40, 50, 70)
local accent = Color3.fromRGB(58, 148, 245)
local accentOn = Color3.fromRGB(92, 214, 64)
local muted = Color3.fromRGB(200, 210, 232)
local offTone = Color3.fromRGB(84, 92, 112)

local function make(className, properties, parent)
	local instance = Instance.new(className)
	for key, value in pairs(properties) do instance[key] = value end
	instance.Parent = parent
	return instance
end
local function place(item, rect)
	item.Position, item.Size = UDim2.fromOffset(rect.x, rect.y), UDim2.fromOffset(rect.w, rect.h)
end
-- Owner request 2026-11-20 (UR-H1, docs/design/refs/store-ui-reference.png): the reference's look. A title is big
-- white words with the kit's thick round outline; other words sit on the pale inner panel in dark round letters and
-- shrink to fit their rectangle (the rectangles were measured for Gotham). Without the kit (lip 0) nothing moves.
local lip = type(Style.HUD_SIZES) == "table" and Style.HUD_SIZES.lip or 0
local function label(parent, rect, text, size, bold, color, center)
	local item = make("TextLabel", { BackgroundTransparency = 1, Text = text, TextColor3 = color or ink, TextSize = size,
		Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham, TextWrapped = true,
		TextXAlignment = center and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center }, parent)
	place(item, rect)
	if bold then
		Style.loudText(item, Enum.Font.FredokaOne, 3, color or ink)
	else
		Style.panelText(item)
	end
	Style.fitText(item, size, 10)
	return item
end
-- UR-H1: a glossy chunky button (lit top, dark 3D bottom edge, thick outline, outlined round words) in the colour
-- passed in, or the neutral blue; its words sit on the lit face, above the edge.
local function button(parent, rect, text, name, color, size)
	local item = make("TextButton", { Name = name, Text = text, BackgroundColor3 = color or accent, TextColor3 = ink,
		TextSize = size or 16, Font = Enum.Font.GothamBold, AutoButtonColor = true, TextWrapped = true }, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 7) }, item)
	place(item, rect)
	Style.gloss(item, color or accent)
	Style.corner(item, 12)
	make("UIPadding", { Name = "WbLift", PaddingBottom = UDim.new(0, lip) }, item)
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
Style.panel(panel)
-- UR-H1: the reference's window: a bright blue frame with a thick dark border, the title on the blue, and everything
-- under the title on a pale inner panel (rebuilt with the screen, behind its words and buttons). The rectangles stay
-- WildboundStartView's; the inner panel starts at the title's bottom edge and keeps 4 px of blue on each side.
Style.dressPanel(panel, "blue")
local function header(rect)
	local top = rect.y + rect.h
	local inner = make("Frame", { Name = "WbInner", Active = false, BorderSizePixel = 0, ZIndex = 0,
		BackgroundTransparency = 1, Position = UDim2.fromOffset(4, top), Size = UDim2.new(1, -8, 1, -(top + 4)) }, panel)
	Style.dressPanel(inner, "light")
	Style.corner(inner, 12)
	Style.outline(inner, 3, type(Style.KIT_COLORS) == "table" and Style.KIT_COLORS.innerEdge or nil)
end

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
		header(v.title)
		label(panel, v.title, View.TEXT.title, 24, true, ink, true)
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
		header(v.title)
		label(panel, v.title, View.TEXT.settingsTitle, 22, true, ink, true)
		for index, key in ipairs(Settings.ORDER) do
			local row = v.rows[index]
			label(panel, row.text, descriptions[index], View.TEXT_SIZE)
			local on = Settings.get(settings, key)
			button(panel, row.toggle, Settings.stateText(on), "Toggle_" .. key, on and accentOn or offTone).Activated:Connect(
				key == "reducedEffects" and actions.toggleReduced or actions.toggleHints)
		end
		button(panel, v.replay, "Repetir tutorial", "ReplayButton").Activated:Connect(actions.replay)
		button(panel, v.back, "Volver", "BackButton").Activated:Connect(actions.back)
	elseif screen == "howto" then
		local v = View.howto(layout)
		place(panel, v.panel)
		header(v.title)
		label(panel, v.title, View.TEXT.howtoTitle, 22, true, ink, true)
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
-- UI colorida: the tutorial card is a slate panel with a gold outline (the next step stands out from the HUD).
Style.panel(card)
Style.outline(card, 3, amber)
-- UR-H1: the card is the reference's pale panel (thick dark border, rounded) with dark round words that shrink to fit,
-- and a glossy red Saltar.
Style.dressPanel(card, "light")
local cardText = make("TextLabel", { Name = "CardText", BackgroundTransparency = 1, TextColor3 = ink, Font = Enum.Font.Gotham,
	TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, Text = "" }, card)
Style.body(cardText, true)
Style.panelText(cardText)
local skip = button(card, { x = 0, y = 0, w = 64, h = 44 }, "Saltar", "SkipButton", Color3.fromRGB(236, 64, 72), 15)
local cardMode, cardKey = nil, nil
local function layoutCard()
	local geometry = View.card(currentLayout())
	cardMode = geometry.mode
	place(card, geometry.rect)
	place(cardText, geometry.text)
	place(skip, geometry.skip)
	cardText.TextSize = geometry.size
	Style.fitText(cardText, geometry.size, 10)
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
	-- Egg loop guide: nothing is observed or shown before the first state snapshot, so a returning player is
	-- recognised as a veteran (no card, no closing line) instead of flashing step 1.
	local snapshot = snapshotNow()
	if Tutorial.state(tutorial) == "running" and snapshot then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local at = root and root:IsA("BasePart") and { x = root.Position.X, z = root.Position.Z } or nil
		Tutorial.observe(tutorial, Tutorial.factsFrom(snapshot, tab == "camp", at))
		if Tutorial.state(tutorial) == "done" then doneUntil = os.clock() + 5 end
	end
	local step = Tutorial.step(tutorial)
	gui:SetAttribute("TutorialState", step and step.id or Tutorial.state(tutorial))
	-- User decision 2026-11-14 ("Que se muestre"): the card shows again under the conditions above.
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
playPressed = true
show("closed")

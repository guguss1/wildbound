-- Local presentation only; all actions and eligibility are decided by the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
if playerGui:FindFirstChild("WildboundWorldUI") then
	warn("Wildbound world presentation already exists; duplicate controller refused.")
	return
end
-- Pure rules live in ReplicatedStorage so they can be tested; this script only applies them.
local layoutModule = ReplicatedStorage:WaitForChild("WildboundHudLayout", 10)
local viewModule = ReplicatedStorage:WaitForChild("WildboundHudView", 10)
if not (layoutModule and viewModule) then
	warn("Wildbound world presentation: HUD modules are missing; controller refused.")
	return
end
local Layout, View = require(layoutModule), require(viewModule)
-- Delivery D12: the comfort switch's words, in Spanish from WildboundText (one switch: fog, audio and the defeat fade).
local settingsWords = {}
local worldWords = { phases = {} }
local function word(key) return worldWords[key] or "" end
do
	local textModule = ReplicatedStorage:FindFirstChild("WildboundText")
	local ok, value = false, nil
	if textModule and textModule:IsA("ModuleScript") then ok, value = pcall(require, textModule) end
	if ok and type(value) == "table" and type(value.SETTINGS) == "table" then settingsWords = value.SETTINGS end
	-- Next batch NB3: the panel and ability words (WildboundText.WORLD). A missing module leaves the buttons blank.
	if ok and type(value) == "table" and type(value.WORLD) == "table" then worldWords = value.WORLD end
end
local function reducedText(on)
	return on and (settingsWords.shortOn or "Suave: Sí") or (settingsWords.shortOff or "Suave: No")
end

local function make(className, properties, parent)
	local item = Instance.new(className)
	for key, value in pairs(properties) do item[key] = value end
	item.Parent = parent
	return item
end
local function rgb(value)
	return Color3.fromRGB(value.r, value.g, value.b)
end
-- Above the inventory interface, so the awareness chip stays readable when the inventory is open.
local gui = make("ScreenGui", {Name = "WildboundWorldUI", ResetOnSpawn = false, DisplayOrder = 10}, playerGui)
-- Delivery C: a full-screen red flash when a strike lands (WildboundHudView.hitFlash). It never takes input.
local hitFlash = make("Frame", {Name = "HitFlash", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
	BorderSizePixel = 0, Visible = false, Active = false, ZIndex = 50}, gui)
local panel = make("Frame", {Name = "WorldPanel", BackgroundColor3 = Color3.fromRGB(25, 34, 31),
	BackgroundTransparency = 0.15}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, panel)
local function label(parent, text, position, size)
	return make("TextLabel", {BackgroundTransparency = 1, Position = position, Size = size,
		Text = text, TextColor3 = Color3.fromRGB(240, 244, 231), TextSize = 14,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.Gotham}, parent)
end
local phaseLabel = label(panel, word("connecting"), UDim2.fromOffset(10, 4), UDim2.new(1, -140, 0, 24))
local warningLabel = label(panel, "", UDim2.fromOffset(10, 29), UDim2.new(1, -146, 0, 29))
local statusLabel = label(panel, "", UDim2.fromOffset(10, 60), UDim2.new(1, -20, 0, 26))
local function button(parent, text, position, size)
	local item = make("TextButton", {Text = text, Position = position, Size = size,
		BackgroundColor3 = Color3.fromRGB(77, 115, 88), TextColor3 = Color3.fromRGB(240, 244, 231),
		TextSize = 14, Font = Enum.Font.GothamBold, TextWrapped = true}, parent)
	make("UICorner", {CornerRadius = UDim.new(0, 7)}, item)
	return item
end
-- Positions come from the layout module (applyLayout below); only the sizes start here.
local effects = button(gui, reducedText(false), UDim2.new(), UDim2.fromOffset(126, 44))
local flashlight = button(gui, word("flashlightKey"), UDim2.new(), UDim2.fromOffset(110, 44))
local pulse = button(gui, word("pulseKey"), UDim2.new(), UDim2.fromOffset(110, 44))
effects.Name, flashlight.Name, pulse.Name = "ReducedButton", "FlashlightButton", "PulseButton"
-- The awareness chip lives outside the panel, so it stays visible while the inventory is open (M2.3).
-- It always carries words and a shape; colour is only a redundant cue, and nothing depends on audio.
local chip = make("Frame", {Name = "AwarenessChip", BackgroundColor3 = Color3.fromRGB(30, 38, 35)}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, chip)
local chipStroke = make("UIStroke", {Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, chip)
local chipShape = make("Frame", {Name = "Shape", AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0, 22, 0.5, 0), BorderSizePixel = 0}, chip)
local chipShapeCorner = make("UICorner", {}, chipShape)
local chipShapeStroke = make("UIStroke", {Thickness = 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, chipShape)
local chipGlyph = make("TextLabel", {Name = "Glyph", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0, 22, 0.5, 0), Size = UDim2.fromOffset(28, 28), Font = Enum.Font.GothamBold,
	TextSize = 16, Text = ""}, chip)
local chipText = make("TextLabel", {Name = "Text", BackgroundTransparency = 1, Position = UDim2.fromOffset(40, 0),
	Size = UDim2.new(1, -44, 1, 0), Font = Enum.Font.GothamBold, TextSize = 15, Text = "",
	TextXAlignment = Enum.TextXAlignment.Left}, chip)
local SHAPES = {
	diamond = {size = Vector2.new(20, 20), rotation = 45, radius = UDim.new(0, 3), filled = true},
	square = {size = Vector2.new(24, 24), rotation = 0, radius = UDim.new(0, 3), filled = true},
	ring = {size = Vector2.new(26, 26), rotation = 0, radius = UDim.new(0.5, 0), filled = false},
	dot = {size = Vector2.new(24, 24), rotation = 0, radius = UDim.new(0.5, 0), filled = true},
	dash = {size = Vector2.new(22, 6), rotation = 0, radius = UDim.new(0, 3), filled = true},
}
-- The view module hands back the same table until something visible changes, so a steady chip costs
-- one comparison per frame and no allocation.
local chipCache, chipView = View.newChipCache(), nil
local NO_GUARDIAN = table.freeze({})
local function applyChip(view)
	if view == chipView then return end
	chipView = view
	local tone = View.TONES[view.tone] or View.TONES.none
	local shape = SHAPES[view.shape] or SHAPES.dash
	chip.BackgroundColor3, chip.BackgroundTransparency = rgb(tone.bg), tone.transparency
	chipStroke.Color, chipStroke.Thickness = rgb(tone.border), view.kind == "attack" and 4 or 2
	chipText.Text, chipText.TextColor3 = view.text, rgb(tone.text)
	chipShape.Size, chipShape.Rotation = UDim2.fromOffset(shape.size.X, shape.size.Y), shape.rotation
	chipShapeCorner.CornerRadius = shape.radius
	chipShape.BackgroundColor3 = rgb(tone.text)
	chipShape.BackgroundTransparency = shape.filled and 0 or 1
	chipShapeStroke.Color, chipShapeStroke.Thickness = rgb(tone.text), shape.filled and 0 or 3
	chipGlyph.Text = view.shape == "dash" and "" or view.glyph
	chipGlyph.TextColor3 = shape.filled and rgb(tone.bg) or rgb(tone.text)
	chip:SetAttribute("Kind", view.kind)
end
-- D11: off by default (On mutes the horror). The start screen offers it and may set it through the attribute.
local reduced = false
-- The capture screen reads this to stop its ring pulsing (M3.4).
gui:SetAttribute("Reduced", reduced)
local state, actionRemote, lastUpdate = nil, nil, 0
-- Fair strike (M4.2 to M4.7): this client's own warning, its acknowledgement, readiness and liveness.
-- The local attributes WithholdAck and WithholdReady exist only to test the server's K rule; they can
-- only make this client's own strikes less likely to land.
local pendingAttack, ackRemote, readyRemote, pulseRemote = nil, nil, nil, nil
local connections = {}
local function listen(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end
local function inventoryOpen()
	local inventory = playerGui:FindFirstChild("WildboundUI")
	local inventoryPanel = inventory and inventory:FindFirstChild("InventoryPanel")
	return inventoryPanel and inventoryPanel:IsA("GuiObject") and inventoryPanel.Visible or false
end
local noticeState = View.newNotice()
local compact, noticeBudget = false, 40
local function touchPrimary()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end
local function placeRect(item, rect)
	item.Position, item.Size = UDim2.fromOffset(rect.x, rect.y), UDim2.fromOffset(rect.w, rect.h)
end
-- Apply the pure layout. Small screens collapse the long explanatory lines instead of shrinking them.
local function applyLayout()
	local size = gui.AbsoluteSize
	local layout = Layout.compute(size.X, size.Y, {touch = touchPrimary()})
	compact = layout.mode == "compact"
	local rects = layout.rects
	placeRect(chip, rects.chip)
	placeRect(panel, rects.panel)
	placeRect(effects, rects.effects)
	placeRect(flashlight, rects.flashlight)
	placeRect(pulse, rects.pulse)
	local textSize = compact and 13 or 14
	for _, item in ipairs({phaseLabel, warningLabel, statusLabel, effects, flashlight, pulse}) do item.TextSize = textSize end
	chipText.TextSize = compact and 14 or 15
	if compact then
		phaseLabel.Position, phaseLabel.Size = UDim2.fromOffset(8, 0), UDim2.new(1, -16, 0, 15)
		warningLabel.Position, warningLabel.Size = UDim2.fromOffset(8, 15), UDim2.new(1, -16, 0, 31)
		noticeBudget = Layout.charBudget(rects.panel.w - 16, textSize, 2)
	else
		phaseLabel.Position, phaseLabel.Size = UDim2.fromOffset(10, 4), UDim2.new(1, -140, 0, 24)
		warningLabel.Position, warningLabel.Size = UDim2.fromOffset(10, 29), UDim2.new(1, -146, 0, 29)
		noticeBudget = Layout.charBudget(rects.panel.w - 20, textSize, 1)
	end
	statusLabel.Visible = not compact
	gui:SetAttribute("LayoutMode", layout.mode)
end
applyLayout()
listen(gui:GetPropertyChangedSignal("AbsoluteSize"), applyLayout)
listen(UserInputService:GetPropertyChangedSignal("KeyboardEnabled"), applyLayout)
local lastAction = 0
local function request(action)
	-- Abilities keep working with the inventory open (M2.3); only stale world state blocks them.
	if not actionRemote or (action ~= "RequestSnapshot" and (not state or os.clock() - lastUpdate >= 5)) then return end
	if action ~= "RequestSnapshot" then
		local now = os.clock()
		if now - lastAction < 0.25 then return end
		lastAction = now
	end
	actionRemote:FireServer(action)
end
listen(flashlight.Activated, function() request("Flashlight") end)
listen(pulse.Activated, function() request("LumipolPulse") end)
-- Delivery D6: while hidden, "Salir" covers the pulse slot; H, or the stick pushed past half for 0.25 s, exits too.
-- The server moves the character in and out; this script only asks.
local hideWords = {}
do
	local textModule = ReplicatedStorage:FindFirstChild("WildboundText")
	local ok, value = false, nil
	if textModule and textModule:IsA("ModuleScript") then ok, value = pcall(require, textModule) end
	if ok and type(value) == "table" and type(value.HIDE) == "table" then hideWords = value.HIDE end
end
local hideExit = button(gui, hideWords.exit or "Salir", UDim2.new(), UDim2.fromOffset(110, 44))
hideExit.Name, hideExit.Visible, hideExit.ZIndex = "HideExitButton", false, 5
local pushedSince
local function isHidden()
	return type(player:GetAttribute("WildboundHidden")) == "string"
end
listen(player:GetAttributeChangedSignal("WildboundHidden"), function()
	hideExit.Visible, pushedSince = isHidden(), nil
end)
listen(hideExit.Activated, function() request("HideExit") end)
listen(UserInputService.InputBegan, function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.H and isHidden() then request("HideExit") end
end)
listen(RunService.Heartbeat, function()
	if not isHidden() then pushedSince = nil return end
	hideExit.Position, hideExit.Size = pulse.Position, pulse.Size
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.MoveDirection.Magnitude > 0.5 then
		pushedSince = pushedSince or os.clock()
		if os.clock() - pushedSince >= 0.25 then
			pushedSince = math.huge
			request("HideExit")
		end
	else
		pushedSince = nil
	end
end)
-- Dread pass (D4, decision D-D5): sprint. Keyboard LeftShift and gamepad L3 are held; touch uses the "Correr" toggle,
-- because a held button would take the right thumb off the camera. A sinking high-priority action keeps Shift from
-- toggling shift lock. The server owns stamina, stance and speed; this only asks, refreshed every 0.5 s while held.
local ContextActionService = game:GetService("ContextActionService")
local staminaWords = {}
do
	local textModule = ReplicatedStorage:FindFirstChild("WildboundText")
	local ok, value = false, nil
	if textModule and textModule:IsA("ModuleScript") then ok, value = pcall(require, textModule) end
	if ok and type(value) == "table" and type(value.STAMINA) == "table" then staminaWords = value.STAMINA end
end
local stanceRemote
task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild("WildboundNetwork", 15)
	local remote = folder and folder:WaitForChild("Stance", 15)
	if remote and remote:IsA("RemoteEvent") then stanceRemote = remote end
end)
local sprintHeld, sprintToggle, lastStanceSent = false, false, 0
local function sendStance(force)
	if not stanceRemote then return end
	if sprintHeld or sprintToggle then
		local now = os.clock()
		if force or now - lastStanceSent >= 0.5 then
			lastStanceSent = now
			stanceRemote:FireServer("sprint")
		end
	elseif force then
		stanceRemote:FireServer("walk")
	end
end
ContextActionService:BindActionAtPriority("WildboundSprint", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		sprintHeld = true
		sendStance(true)
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		sprintHeld = false
		sendStance(true)
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
local sprintButton = button(gui, staminaWords.sprint or "Correr", UDim2.new(), UDim2.fromOffset(110, 44))
sprintButton.Name = "SprintButton"
local staminaBar = make("Frame", {Name = "StaminaBar", BackgroundColor3 = Color3.fromRGB(25, 34, 31),
	BackgroundTransparency = 0.2, BorderSizePixel = 0, Visible = false}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 4)}, staminaBar)
local staminaFill = make("Frame", {Name = "Fill", BackgroundColor3 = Color3.fromRGB(214, 226, 196),
	BorderSizePixel = 0, Size = UDim2.fromScale(1, 1)}, staminaBar)
make("UICorner", {CornerRadius = UDim.new(0, 4)}, staminaFill)
local staminaLabel = make("TextLabel", {Name = "Words", BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, -18),
	Size = UDim2.new(1, 0, 0, 16), Font = Enum.Font.GothamBold, TextSize = 13, Text = staminaWords.label or "Aliento",
	TextColor3 = Color3.fromRGB(240, 244, 231), TextXAlignment = Enum.TextXAlignment.Left}, staminaBar)
local function paintSprintButton()
	sprintButton.BackgroundColor3 = sprintToggle and Color3.fromRGB(150, 96, 60) or Color3.fromRGB(77, 115, 88)
end
listen(sprintButton.Activated, function()
	sprintToggle = not sprintToggle
	paintSprintButton()
	sendStance(true)
end)
local function applyStamina()
	local value = player:GetAttribute("WildboundStamina")
	local stance = player:GetAttribute("WildboundStance")
	local amount = type(value) == "number" and math.clamp(value / 100, 0, 1) or 1
	staminaFill.Size = UDim2.fromScale(amount, 1)
	-- Exhausted shows words, not only colour (D4).
	local tired = stance == "exhausted"
	staminaLabel.Text = tired and (staminaWords.exhausted or "Sin aliento") or (staminaWords.label or "Aliento")
	staminaFill.BackgroundColor3 = tired and Color3.fromRGB(196, 92, 72) or Color3.fromRGB(214, 226, 196)
	staminaBar.Visible = amount < 0.999 or stance == "sprint"
end
listen(player:GetAttributeChangedSignal("WildboundStamina"), applyStamina)
listen(player:GetAttributeChangedSignal("WildboundStance"), applyStamina)
listen(RunService.Heartbeat, function()
	sendStance(false)
	-- Above the pulse slot; the button only on touch-first screens, where there is no Shift.
	sprintButton.Position, sprintButton.Size = pulse.Position - UDim2.fromOffset(0, 52), pulse.Size
	sprintButton.Visible = touchPrimary() and not isHidden()
	staminaBar.Position = pulse.Position - UDim2.fromOffset(0, touchPrimary() and 66 or 14)
	staminaBar.Size = UDim2.new(pulse.Size.X.Scale, pulse.Size.X.Offset, 0, 8)
end)
-- Nest Heist (NH4): the Burst. Z on a keyboard, R3 on a gamepad and the "Impulso" button (touch, and the ready
-- indicator everywhere: it counts down while the burst cools). The server owns the cooldown and the speed; this asks.
local burstButton = button(gui, staminaWords.burst or "Impulso", UDim2.new(), UDim2.fromOffset(110, 44))
burstButton.Name = "BurstButton"
local function askBurst()
	if stanceRemote then stanceRemote:FireServer("burst") end
end
ContextActionService:BindActionAtPriority("WildboundBurst", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then askBurst() end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Z, Enum.KeyCode.ButtonR3)
listen(burstButton.Activated, askBurst)
listen(RunService.Heartbeat, function()
	local readyAt = player:GetAttribute("WildboundBurstReady")
	local left = type(readyAt) == "number" and readyAt - workspace:GetServerTimeNow() or 0
	local word = staminaWords.burst or "Impulso"
	burstButton.Text = left > 0.05 and ("%s %d"):format(word, math.ceil(left))
		or (touchPrimary() and word or (staminaWords.burstKey or "Impulso (Z)"))
	burstButton.BackgroundColor3 = left > 0.05 and Color3.fromRGB(70, 74, 72) or Color3.fromRGB(77, 115, 88)
	burstButton.AutoButtonColor = left <= 0.05
	burstButton.Position = pulse.Position - UDim2.fromOffset(0, touchPrimary() and 120 or 70)
	burstButton.Size = pulse.Size
	burstButton.Visible = not isHidden()
end)
-- Nest Heist phase 2 (NP5): the bat. A left click (never one on the interface), DPadRight or the "Bate" button (touch,
-- and the ready indicator everywhere: it counts down while the bat cools) asks the server to swing; the server owns
-- the cooldown, the target and every effect. Every client turns every player's bat grip for the swing it sees.
do
	local batWords = {}
	local textModule = ReplicatedStorage:FindFirstChild("WildboundText")
	local ok, value = false, nil
	if textModule and textModule:IsA("ModuleScript") then ok, value = pcall(require, textModule) end
	if ok and type(value) == "table" and type(value.BAT) == "table" then batWords = value.BAT end
	local BAT_SWING_SECONDS = 0.3 -- WildboundBat.CONSTANTS.SWING_SECONDS (a server-only module)
	local batButton = button(gui, batWords.button or "Bate", UDim2.new(), UDim2.fromOffset(110, 44))
	batButton.Name = "BatButton"
	local lastAsk = 0
	local function askBat()
		local now = os.clock()
		if not stanceRemote or now - lastAsk < 0.25 then return end
		lastAsk = now
		stanceRemote:FireServer("bat")
	end
	listen(batButton.Activated, askBat)
	listen(UserInputService.InputBegan, function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.DPadRight then askBat() end
	end)
	local rest = setmetatable({}, { __mode = "k" })
	listen(RunService.Heartbeat, function()
		local now = workspace:GetServerTimeNow()
		local readyAt = player:GetAttribute("WildboundBatReady")
		local left = type(readyAt) == "number" and readyAt - now or 0
		local word = batWords.button or "Bate"
		batButton.Text = left > 0.05 and ("%s %d"):format(word, math.ceil(left))
			or (touchPrimary() and word or (batWords.buttonKey or "Bate (clic)"))
		batButton.BackgroundColor3 = left > 0.05 and Color3.fromRGB(70, 74, 72) or Color3.fromRGB(120, 86, 58)
		batButton.AutoButtonColor = left <= 0.05
		batButton.Position = pulse.Position - UDim2.fromOffset(0, touchPrimary() and 172 or 122)
		batButton.Size = pulse.Size
		batButton.Visible = not isHidden()
		for _, other in ipairs(Players:GetPlayers()) do
			local model = other.Character and other.Character:FindFirstChild("WildboundBat")
			local handle = model and model:FindFirstChild("Handle")
			local grip = handle and handle:FindFirstChild("BatGrip")
			if grip and grip:IsA("Weld") then
				rest[grip] = rest[grip] or grip.C0
				local at = other:GetAttribute("WildboundBatSwing")
				local t = type(at) == "number" and (now - at) / BAT_SWING_SECONDS or 2
				if t >= 0 and t < 1 then
					-- A flat sweep across the front, from the right to the left, easing out.
					local yaw = math.rad(80 - 160 * (1 - (1 - t) ^ 2))
					grip.C0 = CFrame.new(rest[grip].Position) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-90), 0, 0)
				elseif grip.C0 ~= rest[grip] then
					grip.C0 = rest[grip]
				end
			end
		end
	end)
end
listen(effects.Activated, function()
	reduced = not reduced
	gui:SetAttribute("Reduced", reduced)
	effects.Text = reducedText(reduced)
end)
-- The Settings screen sets the same attribute; follow it so the button always shows the real value.
listen(gui:GetAttributeChangedSignal("Reduced"), function()
	local value = gui:GetAttribute("Reduced")
	if type(value) == "boolean" and value ~= reduced then
		reduced = value
		effects.Text = reducedText(reduced)
	end
end)
listen(UserInputService.InputBegan, function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.F then request("Flashlight") end
	if input.KeyCode == Enum.KeyCode.Q then request("LumipolPulse") end
end)

-- Cache and restore only the Lighting properties this controller owns locally.
local original = {ClockTime = Lighting.ClockTime, Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient, FogColor = Lighting.FogColor,
	FogStart = Lighting.FogStart, FogEnd = Lighting.FogEnd, Brightness = Lighting.Brightness,
	ExposureCompensation = Lighting.ExposureCompensation}
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local ownsAtmosphere = not atmosphere
if not atmosphere then
	atmosphere = make("Atmosphere", {Name = "WildboundLocalAtmosphere", Density = 0.2,
		Color = original.FogColor, Haze = 0}, Lighting)
end
local originalAtmosphere = {Density = atmosphere.Density, Color = atmosphere.Color, Haze = atmosphere.Haze,
	Offset = atmosphere.Offset}
-- Delivery D1: whole-map fog by zone and time of day comes from a pure module; this script only applies it.
local atmosphereModule = ReplicatedStorage:WaitForChild("WildboundAtmosphere", 10)
local Atmos = atmosphereModule and require(atmosphereModule)
-- Random world (RW6): the biome variant the server publishes on the network folder ("BiomeVariant"). It tints the fog
-- and the palette (a local ColorCorrectionEffect, removed on cleanup) and plays a quiet bed from an existing catalog
-- slot; night keeps its own fog and darkness (Atmos.variant never touches brightness, exposure or ambient).
local variantTint = make("ColorCorrectionEffect", {Name = "WildboundVariantTint", TintColor = Color3.new(1, 1, 1)}, Lighting)
local audioCatalogModule = ReplicatedStorage:FindFirstChild("WildboundAudioCatalog")
local AudioCatalog = audioCatalogModule and audioCatalogModule:IsA("ModuleScript") and require(audioCatalogModule)
local variantBed, variantBedSlot = nil, nil
local function biomeVariant()
	local folder = ReplicatedStorage:FindFirstChild("WildboundNetwork")
	local value = folder and folder:GetAttribute("BiomeVariant")
	return type(value) == "string" and value or nil
end
local function playVariantBed(name)
	local look = Atmos and Atmos.VARIANTS and Atmos.VARIANTS[name]
	local slot = look and look.ambient
	if slot == variantBedSlot then return end
	variantBedSlot = slot
	if variantBed then variantBed:Destroy() variantBed = nil end
	local entry = slot and AudioCatalog and AudioCatalog.SOUNDS[slot]
	if not entry then return end
	variantBed = make("Sound", {Name = "WildboundVariantBed", SoundId = "rbxassetid://" .. entry.ids[1], Looped = true,
		Volume = 0.1, PlaybackSpeed = name == "Escarcha" and 0.8 or 1}, game:GetService("SoundService"))
	variantBed:Play()
end
-- Dread pass: the player's own flashlight, rebuilt on each new character's head.
local function ownFlashlight()
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then return nil end
	local light = head:FindFirstChild("WildboundFlashlight")
	if not light then
		light = make("SpotLight", {Name = "WildboundFlashlight", Face = Enum.NormalId.Front, Brightness = 0, Range = 55,
			Angle = 60, Shadows = true, Color = Color3.fromRGB(255, 238, 210), Enabled = false}, head)
	end
	return light
end
-- Delivery B (B2): every carried capsule bobs, and shakes when its creature is scared. The server builds the
-- capsule and publishes its mood; this client only moves the creature's seat joint, which never replicates.
local carryModule = ReplicatedStorage:WaitForChild("WildboundCarry", 10)
local Carry = carryModule and require(carryModule)
local function animateCapsules(now)
	if not Carry then return end
	for _, other in ipairs(Players:GetPlayers()) do
		local capsule = other.Character and other.Character:FindFirstChild("WildboundCarryCapsule")
		local creature = capsule and capsule:FindFirstChild("Creature")
		local seat = creature and creature:FindFirstChild("Seat")
		if seat and seat:IsA("Weld") then
			local pose = Carry.pose(capsule:GetAttribute("Mood"), now)
			seat.C0 = CFrame.new(pose.x, 0.1 + pose.y, 0) * CFrame.Angles(0, 0, pose.roll)
		end
	end
end
-- B4: every Lumipol on a camp display spot bobs and looks around a little, on this client only, from the Base
-- frame the server set. The server's model never moves.
local refugeModule = ReplicatedStorage:WaitForChild("WildboundRefuge", 10)
local Refuge = refugeModule and require(refugeModule)
local function animateDisplay(now)
	local map = Refuge and workspace:FindFirstChild("WildboundP0")
	local runtime = map and map:FindFirstChild("WildboundRuntime")
	if not runtime then return end
	for _, model in ipairs(runtime:GetChildren()) do
		local base = model.Name == "DisplayLumipol" and model:GetAttribute("Base")
		if typeof(base) == "CFrame" then
			local pose = Refuge.idlePose(now, model:GetAttribute("Spot"))
			model:PivotTo(base * CFrame.new(0, pose.y, 0) * CFrame.Angles(0, pose.yaw, 0))
		end
	end
end
-- B5: the companion is server-owned and follows an attachment in its owner's root. This client moves its own
-- companion's attachment for the hover bob and the pulse hop (it simulates that companion, so every player sees the
-- motion), fades it as the camera nears it so it never fills the view, and flashes any companion whose owner pulsed.
local function animateCompanions(now, root)
	local map = Refuge and workspace:FindFirstChild("WildboundP0")
	local runtime = map and map:FindFirstChild("WildboundRuntime")
	local folder = runtime and runtime:FindFirstChild("WildboundCompanions")
	if not folder then return end
	local camera = workspace.CurrentCamera
	local serverNow = workspace:GetServerTimeNow()
	for _, model in ipairs(folder:GetChildren()) do
		local body = model:FindFirstChild("Body")
		local owner = Players:GetPlayerByUserId(tonumber(model:GetAttribute("OwnerUserId")) or 0)
		if body and owner then
			local pulseAt = owner:GetAttribute("WildboundPulseAt")
			local age = type(pulseAt) == "number" and serverNow - pulseAt or nil
			local light = body:FindFirstChildOfClass("PointLight")
			if light then light.Brightness = age and age >= 0 and age < Refuge.CONFIG.PULSE_SECONDS and 3 or 0.7 end
			if owner == player then
				local anchor = root and root:FindFirstChild("WildboundCompanionAnchor")
				if anchor then
					local offset = Refuge.companionOffset(now, age)
					anchor.Position = Vector3.new(offset.x, offset.y, offset.z)
				end
				if camera then
					local fade = View.companionTransparency((camera.CFrame.Position - body.Position).Magnitude)
					if model:GetAttribute("LumipolArt") == true then
						-- MeshGen1 pass: the ball stays hidden; the user's model fades, on this client only.
						for _, part in ipairs(model:GetChildren()) do
							if part:IsA("BasePart") and part:GetAttribute("LumipolArt") == true then
								part.LocalTransparencyModifier = fade
							end
						end
					else
						body.Transparency = fade
					end
				end
			end
		end
	end
end
-- Smooth only what the player sees. The server moves Body in 0.2 s steps and stays authoritative;
-- Body is never written here. The art and the ground cue slide between the last two server poses.
-- Set the local attribute GuardianSmoothing to false to see the raw steps (used to measure them).
local smoothingModule = ReplicatedStorage:WaitForChild("WildboundGuardianSmoothing", 10)
local Smoothing = smoothingModule and require(smoothingModule)
if not Smoothing then warn("Wildbound world: guardian smoothing unavailable; steps stay visible.") end
-- Fix pass (FP2, one Silueta per player): the runtime holds one "Silueta" model per player, each marked with its
-- owner's user id. This client reads its own hunter for the chase feel, the preload and the awareness, and draws every
-- other player's hunter faint (View.hunterFade as a LocalTransparencyModifier, its grin and glow hidden) here only.
local function hunterModels()
	local map = workspace:FindFirstChild("WildboundP0")
	local runtime = map and map:FindFirstChild("WildboundWorldRuntime")
	local list = {}
	if runtime then
		for _, child in ipairs(runtime:GetChildren()) do
			if child.Name == "Silueta" and child:IsA("Model") then table.insert(list, child) end
		end
	end
	return list
end
local function ownHunter()
	for _, model in ipairs(hunterModels()) do
		if model:GetAttribute("Owner") == player.UserId then return model end
	end
	return nil
end
local function guardianParts()
	local model = ownHunter()
	local body = model and model:FindFirstChild("Body")
	if not (model and body and body:IsA("BasePart")) then return nil end
	return model, body, model:FindFirstChild("SiluetaVisual"), model:FindFirstChild("GroundCue")
end
local follows = {}
local function followOne(model, now)
	local body = model:FindFirstChild("Body")
	if not (body and body:IsA("BasePart")) then return end
	local follow = follows[model]
	if not follow then
		follow = { smoothing = Smoothing.new() }
		follows[model] = follow
	end
	local art, cue = model:FindFirstChild("SiluetaVisual"), model:FindFirstChild("GroundCue")
	local pose = body.CFrame
	if pose ~= follow.lastPose then
		follow.lastPose, follow.changedAt = pose, now
		local look = pose.LookVector
		Smoothing.observe(follow.smoothing, now, pose.X, pose.Y, pose.Z, math.atan2(-look.X, -look.Z))
	end
	if gui:GetAttribute("GuardianSmoothing") == false then return end
	if art ~= follow.art then follow.art, follow.artRel = art, nil end
	if cue ~= follow.cue then follow.cue, follow.cueRel = cue, nil end
	-- The offsets are measured once, while the server pose has held still, so no part is mid-update.
	if now - (follow.changedAt or now) > 0.3 then
		if art and not follow.artRel and art:IsA("Model") then follow.artRel = pose:ToObjectSpace(art:GetPivot()) end
		if cue and not follow.cueRel and cue:IsA("BasePart") then follow.cueRel = pose:ToObjectSpace(cue.CFrame) end
	end
	if not (follow.artRel or follow.cueRel) then return end
	local x, y, z, yaw = Smoothing.sample(follow.smoothing, now)
	if not x then return end
	local shown = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
	if follow.artRel then art:PivotTo(shown * follow.artRel) end
	if follow.cueRel then cue.CFrame = shown * follow.cueRel end
end
local function followGuardian()
	if not Smoothing then return end
	local now = os.clock()
	local seen = {}
	for _, model in ipairs(hunterModels()) do
		seen[model] = true
		followOne(model, now)
	end
	for model in pairs(follows) do
		if not seen[model] then follows[model] = nil end
	end
end
RunService:BindToRenderStep("WildboundGuardianSmoothing", Enum.RenderPriority.Last.Value, followGuardian)

-- Another player's hunter: every part faded by the pure rule, its grin, glow and outline off. Re-applied every half
-- second because a server reveal or a new chase rewrites the replicated properties; the modifier itself is local.
local fadedGrins = {}
local function fadeHunters()
	for _, model in ipairs(hunterModels()) do
		local fade = View.hunterFade(model:GetAttribute("Owner"), player.UserId)
		for _, item in ipairs(model:GetDescendants()) do
			if item:IsA("BasePart") then
				if item.LocalTransparencyModifier ~= fade then item.LocalTransparencyModifier = fade end
			elseif fade > 0 and item.Name == "HorrorGrin" and item:IsA("SurfaceGui") then
				if item.Enabled then item.Enabled = false end
				if not fadedGrins[item] then
					fadedGrins[item] = true
					listen(item:GetPropertyChangedSignal("Enabled"), function()
						if item.Enabled and View.hunterFade(model:GetAttribute("Owner"), player.UserId) > 0 then item.Enabled = false end
					end)
				end
			elseif fade > 0 and item:IsA("PointLight") and item.Name == "Glow" then
				if item.Enabled then item.Enabled = false end
			elseif fade > 0 and item:IsA("Highlight") then
				if item.Enabled then item.Enabled = false end
			end
		end
	end
end
local fadeClock = 0
listen(RunService.Heartbeat, function(dt)
	fadeClock += dt
	if fadeClock < 0.5 then return end
	fadeClock = 0
	local ok, message = pcall(fadeHunters)
	if not ok then gui:SetAttribute("HunterFadeError", tostring(message)) end
end)

-- Fix pass (FP5d): a sleeping island adult breathes on this client only (View.breath, slower in the deep noon sleep the
-- server marks with "Deep"). A server pose (waking, a chase, a carried egg) moves it, which resets the resting frame.
local breathing = {}
local function breathe()
	local now = os.clock()
	for _, adult in ipairs(game:GetService("CollectionService"):GetTagged("WildboundIslandAdult")) do
		if adult:IsA("Model") and adult.PrimaryPart and adult:GetAttribute("Awake") ~= true then
			local pivot = adult:GetPivot()
			local entry = breathing[adult]
			if not entry or (pivot.Position - entry.applied.Position).Magnitude > 0.02 then
				entry = { base = pivot, applied = pivot, offset = (adult:GetAttribute("Adult") or 0) * 0.7 }
				breathing[adult] = entry
			end
			local lift = View.breath(now + entry.offset, adult:GetAttribute("Deep") == true)
			entry.applied = CFrame.new(0, lift, 0) * entry.base
			adult:PivotTo(entry.applied)
		else
			breathing[adult] = nil
		end
	end
end
listen(RunService.RenderStepped, function()
	local ok, message = pcall(breathe)
	if not ok then gui:SetAttribute("BreathError", tostring(message)) end
end)

-- Chase pass (CP1, CP3): sprint is shown and felt, and a close hunting Silueta is felt too. An always-on hint
-- ("Shift: Correr", "L3: Correr"; touch has the button), a wider view while sprinting, and near a hunting Silueta a
-- small camera shake and darker screen edges. The numbers are pure rules in WildboundHudView; "Efectos suaves" softens
-- the kick and the vignette and removes the shake.
local sprintHint = make("TextLabel", {Name = "SprintHint", AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(150, 24), BackgroundColor3 = Color3.fromRGB(25, 34, 31),
	BackgroundTransparency = 0.35, Font = Enum.Font.GothamBold, TextSize = 15, Text = "",
	TextColor3 = Color3.fromRGB(240, 244, 231), Visible = false}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 6)}, sprintHint)
local vignette = make("Frame", {Name = "DreadVignette", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
	Active = false, ZIndex = 40, Visible = false}, gui)
local VIGNETTE_EDGES = {
	{ UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0), 90 }, { UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0.65), -90 },
	{ UDim2.fromScale(0.3, 1), UDim2.fromScale(0, 0), 0 }, { UDim2.fromScale(0.3, 1), UDim2.fromScale(0.7, 0), 180 },
}
local vignetteGradients = {}
for _, edge in ipairs(VIGNETTE_EDGES) do
	local frame = make("Frame", {Size = edge[1], Position = edge[2], BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0, BackgroundTransparency = 0, Active = false, ZIndex = 40}, vignette)
	table.insert(vignetteGradients, make("UIGradient", {Rotation = edge[3]}, frame))
end
local fov = { base = nil, applied = nil }
local shakeRng = Random.new()
local function chaseFeel(dt)
	local camera = workspace.CurrentCamera
	if not camera then return end
	if isHidden() then
		sprintHint.Visible = false
	else
		local input = touchPrimary() and "touch"
			or (UserInputService:GetLastInputType().Name:find("Gamepad", 1, true) and "gamepad" or "keyboard")
		local hint = View.sprintHint(input, staminaWords)
		sprintHint.Text, sprintHint.Visible = hint or "", hint ~= nil
	end
	-- Someone else changed the field of view (a cutscene, a setting): follow it as the new base.
	if fov.applied == nil or math.abs(camera.FieldOfView - fov.applied) > 0.01 then fov.base = camera.FieldOfView end
	-- Fear pass (FA3): the fear client's punch (a grab, a hit) is added on top; it is already halved for Reduced.
	local punch = tonumber(gui:GetAttribute("FearFov")) or 0
	local goal = View.sprintFov(fov.base, player:GetAttribute("WildboundStance"), reduced) + punch
	camera.FieldOfView += (goal - camera.FieldOfView) * math.min(1, dt * 8)
	fov.applied = camera.FieldOfView
	local model, body = guardianParts()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local dread = { shake = 0, vignette = 0 }
	if model and root then
		dread = View.dread((root.Position - body.Position).Magnitude, model:GetAttribute("State"), reduced)
	end
	vignette.Visible = dread.vignette > 0.001
	if vignette.Visible then
		local edge = 1 - dread.vignette
		for _, gradient in ipairs(vignetteGradients) do
			gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, edge),
				NumberSequenceKeypoint.new(1, 1) })
		end
	end
	if dread.shake > 0 then
		local amount = dread.shake
		camera.CFrame *= CFrame.new(shakeRng:NextNumber(-amount, amount), shakeRng:NextNumber(-amount, amount), 0)
	end
end
RunService:BindToRenderStep("WildboundChaseFeel", Enum.RenderPriority.Camera.Value + 1, chaseFeel)

-- Camp preload (M4.5): wait for the replicated guardian, preload it and the four Silueta clips, then
-- report. The template lives in ServerStorage, so clips are preloaded from Animation instances. 20 s cap.
local CLIP_IDS = { "rbxassetid://90427760879990", "rbxassetid://109004575414309",
	"rbxassetid://106571946482274", "rbxassetid://139759980248576" }
local function reportReady()
	if gui:GetAttribute("WithholdReady") == true then return end
	local started = os.clock()
	local model = guardianParts()
	while not model and gui.Parent and os.clock() - started < 20 do
		task.wait(0.25)
		model = guardianParts()
	end
	gui:SetAttribute("GuardianSeenAfter", model and os.clock() - started or -1)
	local list = {}
	for _, id in ipairs(CLIP_IDS) do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		table.insert(list, animation)
	end
	if model then table.insert(list, model) end
	local failures, done = 0, false
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(list, function(_, status)
				if status ~= Enum.AssetFetchStatus.Success then failures += 1 end
			end)
		end)
		done = true
	end)
	while not done and gui.Parent and os.clock() - started < 20 do task.wait(0.1) end
	local persistentLoaded, assetsLoaded = model ~= nil, done and failures == 0
	gui:SetAttribute("PreloadSeconds", os.clock() - started)
	gui:SetAttribute("PreloadFailures", failures)
	gui:SetAttribute("ReadyReport", ("%s,%s"):format(tostring(persistentLoaded), tostring(assetsLoaded)))
	if readyRemote and gui.Parent then readyRemote:FireServer(persistentLoaded, assetsLoaded) end
end
-- MT-2: does Workspace.PersistentLoaded fire on this client? Recorded only.
pcall(function()
	listen(workspace.PersistentLoaded, function() gui:SetAttribute("PersistentLoadedAt", os.clock()) end)
end)
local function cooldown(readyAt, now)
	if type(readyAt) ~= "number" then return "?" end
	local remaining = math.max(0, math.ceil(readyAt - now))
	return remaining > 0 and (remaining .. "s") or word("ready")
end
local elapsed, pulseElapsed = 0, 0
listen(RunService.Heartbeat, function(dt)
	if not gui.Parent then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local fresh = state and os.clock() - lastUpdate < 5
	animateCompanions(os.clock(), root)
	animateCapsules(os.clock())
	animateDisplay(os.clock())
	-- The chip is checked every frame and never hides with the inventory (M2.3); it is rebuilt only on change.
	-- This client's own attack warning holds it on attack until the server says the strike resolved.
	local guardianState = fresh and type(state.guardian) == "table" and state.guardian or NO_GUARDIAN
	local serverNow = workspace:GetServerTimeNow()
	if pendingAttack and serverNow > pendingAttack.endsAt + 3 then pendingAttack = nil end
	applyChip(View.chipCached(chipCache, pendingAttack and pendingAttack.awareness or guardianState.awareness,
		fresh == true or pendingAttack ~= nil, serverNow, compact))
	-- Liveness (FieldPulse): once per second while alive in fog. It proves only that this client is online.
	pulseElapsed += dt
	if pulseElapsed >= 1 then
		pulseElapsed = 0
		if pulseRemote and fresh and state.isFog == true and humanoid and humanoid.Health > 0 then pulseRemote:FireServer() end
	end
	elapsed += dt
	if elapsed < 0.1 then return end
	local step = elapsed
	elapsed = 0
	local hidden = inventoryOpen()
	panel.Visible, effects.Visible, flashlight.Visible, pulse.Visible = not hidden, not hidden, not hidden, not hidden
	flashlight.Active, pulse.Active = not not fresh, not not fresh
	flashlight.AutoButtonColor, pulse.AutoButtonColor = not not fresh, not not fresh
	if not fresh then
		flashlight.Text, pulse.Text = word("flashlightOff"), word("pulseOff")
		phaseLabel.Text = word("stateOff")
		warningLabel.Text = word("waiting")
		return
	end
	local now = workspace:GetServerTimeNow()
	phaseLabel.Text = tostring(worldWords.phases[state.phase] or state.phase or "?") .. " · "
		.. math.max(0, math.ceil((state.nextPhaseAt or now) - now)) .. "s" .. (state.marked == true and word("marked") or "")
	local guardian = guardianState
	-- Only the targeted player receives an attack deadline, inside their own awareness (M2.2).
	local aware = type(guardian.awareness) == "table" and guardian.awareness or {}
	-- Held until the server resolves or cancels the strike, not only until the deadline (W6 audit).
	local attack = View.attackPending(aware) or pendingAttack ~= nil
	local hint = View.hint({attack = attack, threat = guardian.threat == true,
		revealed = type(guardian.revealedUntil) == "number" and guardian.revealedUntil > now,
		phase = state.phase, isFog = state.isFog == true})
	-- A notice shows for a few seconds, then goes. On small screens it takes the hint line, never an attack warning.
	local notice = View.currentNotice(noticeState, os.clock())
	if compact then
		warningLabel.Text = (attack or not notice) and hint or View.fit(notice, noticeBudget)
	else
		warningLabel.Text = hint
		statusLabel.Text = notice and View.fit(notice, noticeBudget) or ""
	end
	local keys = UserInputService.KeyboardEnabled
	flashlight.Text = (keys and word("flashlightKey") or word("flashlight")) .. "\n" .. cooldown(state.flashlightReadyAt, now)
	pulse.Text = (keys and word("pulseKey") or word("pulse")) .. "\n"
		.. (state.hasLumipol and cooldown(state.pulseReadyAt, now) or word("equipLumipol"))
	local alpha = 1 - math.exp(-step * 0.5)
	if Atmos then
		local zone = state.isSafe == true and "camp" or (state.isFog == true and "fog" or "open")
		local variant = biomeVariant()
		local target = Atmos.variant(Atmos.at(state.clockTime, zone, reduced), variant)
		variantTint.TintColor = variantTint.TintColor:Lerp(rgb(target.tint), alpha)
		playVariantBed(variant)
		local ambient = original.Ambient:Lerp(rgb(target.ambient), target.ambientWeight)
		local outdoor = original.OutdoorAmbient:Lerp(rgb(target.outdoorAmbient), target.ambientWeight)
		Lighting.Ambient = Lighting.Ambient:Lerp(ambient, alpha)
		Lighting.OutdoorAmbient = Lighting.OutdoorAmbient:Lerp(outdoor, alpha)
		Lighting.FogColor = Lighting.FogColor:Lerp(rgb(target.fogColor), alpha)
		Lighting.FogStart += (target.fogStart - Lighting.FogStart) * alpha
		Lighting.FogEnd += (target.fogEnd - Lighting.FogEnd) * alpha
		Lighting.Brightness += (original.Brightness * target.brightness - Lighting.Brightness) * alpha
		Lighting.ExposureCompensation += (original.ExposureCompensation + target.exposure
			- Lighting.ExposureCompensation) * alpha
		if atmosphere.Parent == Lighting then
			atmosphere.Density += (target.density - atmosphere.Density) * alpha
			atmosphere.Offset += (target.offset - atmosphere.Offset) * alpha
			atmosphere.Color = atmosphere.Color:Lerp(rgb(target.atmosphereColor), alpha)
			atmosphere.Haze += (target.haze - atmosphere.Haze) * alpha
		end
		-- Dread pass: the flashlight is the main light at night. A local SpotLight on this player's own head, off
		-- by day; it never replicates and Reduced effects never dims it.
		local beam = ownFlashlight()
		if beam then
			beam.Brightness += (target.flashlight.brightness - beam.Brightness) * alpha
			beam.Range, beam.Angle = target.flashlight.range, target.flashlight.angle
			beam.Enabled = beam.Brightness > 0.05
		end
	end
	if type(state.clockTime) == "number" then
		local delta = (state.clockTime - Lighting.ClockTime + 12) % 24 - 12
		Lighting.ClockTime = (Lighting.ClockTime + delta * alpha) % 24
	end
end)
listen(gui.Destroying, function()
	for _, connection in ipairs(connections) do connection:Disconnect() end
	pcall(function() RunService:UnbindFromRenderStep("WildboundGuardianSmoothing") end)
	pcall(function() RunService:UnbindFromRenderStep("WildboundChaseFeel") end)
	if fov.base and workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView = fov.base end
	pcall(function() ContextActionService:UnbindAction("WildboundSprint") end)
	pcall(function() ContextActionService:UnbindAction("WildboundBurst") end)
	local beam = player.Character and player.Character:FindFirstChild("WildboundFlashlight", true)
	if beam then beam:Destroy() end
	for key, value in pairs(original) do Lighting[key] = value end
	variantTint:Destroy()
	if variantBed then variantBed:Destroy() end
	if ownsAtmosphere then
		atmosphere:Destroy()
	elseif atmosphere.Parent then
		for key, value in pairs(originalAtmosphere) do atmosphere[key] = value end
	end
end)
task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild("WildboundNetwork", 10)
	local action = folder and folder:WaitForChild("WorldAction", 10)
	local updates = folder and folder:WaitForChild("WorldState", 10)
	if not gui.Parent then return end
	if not (action and action:IsA("RemoteEvent") and updates and updates:IsA("RemoteEvent")) then
		phaseLabel.Text = word("serverDown")
		return
	end
	actionRemote = action
	-- Subscribe to this client's warning before any snapshot request. The text needs no instance: a
	-- remote can arrive before the guardian model does.
	local warning = folder:WaitForChild("AttackWarning", 10)
	local resolved = folder:WaitForChild("AttackResolved", 10)
	local ack, ready, pulse = folder:WaitForChild("AttackAck", 10), folder:WaitForChild("ClientReady", 10),
		folder:WaitForChild("FieldPulse", 10)
	if not gui.Parent then return end
	if ack and ack:IsA("RemoteEvent") then ackRemote = ack end
	if ready and ready:IsA("RemoteEvent") then readyRemote = ready end
	if pulse and pulse:IsA("RemoteEvent") then pulseRemote = pulse end
	if warning and warning:IsA("RemoteEvent") then
		listen(warning.OnClientEvent, function(payload)
			if type(payload) ~= "table" or type(payload.attackId) ~= "string" or type(payload.endsAt) ~= "number" then return end
			local receivedAt = workspace:GetServerTimeNow()
			pendingAttack = { attackId = payload.attackId, endsAt = payload.endsAt,
				awareness = { state = "seen", attackEndsAt = payload.endsAt } }
			applyChip(View.chipCached(chipCache, pendingAttack.awareness, true, receivedAt, compact))
			-- Delivery C: the dodge cue, in the server's words, beside the chip countdown and the wind-up pose.
			if type(payload.notice) == "string" and payload.notice ~= "" and #payload.notice <= 80 then
				View.setNotice(noticeState, View.pickNotice(payload, compact), os.clock())
			end
			-- MT-11: how much warning was left when it arrived here.
			gui:SetAttribute("LastWarningId", payload.attackId)
			gui:SetAttribute("LastWarningLead", payload.endsAt - receivedAt)
			if gui:GetAttribute("WithholdAck") == true then return end
			-- Acknowledge after a frame has rendered with the warning on screen. This proves only that this
			-- script ran with the id, never that the player saw it.
			local id = payload.attackId
			RunService.RenderStepped:Once(function()
				RunService.RenderStepped:Once(function()
					if ackRemote and gui.Parent then ackRemote:FireServer(id) end
					gui:SetAttribute("LastAckAfter", workspace:GetServerTimeNow() - receivedAt)
				end)
			end)
		end)
	end
	if resolved and resolved:IsA("RemoteEvent") then
		listen(resolved.OnClientEvent, function(payload)
			if type(payload) ~= "table" then return end
			if pendingAttack and payload.attackId == pendingAttack.attackId then pendingAttack = nil end
			gui:SetAttribute("LastResolvedOutcome", type(payload.outcome) == "string" and payload.outcome or "?")
			-- Delivery C: a marking strike flashes the screen red; D11: a defeat eases to dark instead and stays until
			-- respawn. The audio client plays the named sound hook.
			local flash = View.hitFlash(payload.outcome, reduced)
			if flash then
				hitFlash.BackgroundColor3 = Color3.fromRGB(flash.r, flash.g, flash.b)
				hitFlash.BackgroundTransparency = flash.from
				hitFlash.Visible = true
				gui:SetAttribute("LastHitSound", flash.sound)
				gui:SetAttribute("LastHitAt", workspace:GetServerTimeNow())
				local tween = TweenService:Create(hitFlash, TweenInfo.new(flash.seconds), { BackgroundTransparency = flash.to })
				if flash.kind ~= "fade" then tween.Completed:Once(function() hitFlash.Visible = false end) end
				tween:Play()
			end
			if type(payload.notice) == "string" and payload.notice ~= "" then
				View.setNotice(noticeState, View.pickNotice(payload, compact), os.clock())
			end
		end)
	end
	listen(player.CharacterAdded, function() task.spawn(reportReady) end)
	-- Delivery D11: the defeat overlay lifts slowly once the player is back at camp.
	listen(player.CharacterAdded, function()
		if hitFlash.Visible then
			local lift = TweenService:Create(hitFlash, TweenInfo.new(2), { BackgroundTransparency = 1 })
			lift.Completed:Once(function() hitFlash.Visible = false end)
			lift:Play()
		end
	end)
	if player.Character then task.spawn(reportReady) end
	listen(updates.OnClientEvent, function(payload)
		if type(payload) ~= "table" then return end
		state, lastUpdate = payload, os.clock()
		-- The inventory controller reads this for the explorer compass (Night Nose works at Night only).
		if type(payload.phase) == "string" then gui:SetAttribute("Phase", payload.phase) end
		View.setNotice(noticeState, View.pickNotice(payload, compact), os.clock())
	end)
	for _ = 1, 3 do
		if not gui.Parent or state then break end
		request("RequestSnapshot")
		task.wait(3)
	end
end)





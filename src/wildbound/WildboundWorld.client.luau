-- Local presentation only; all actions and eligibility are decided by the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
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
local panel = make("Frame", {Name = "WorldPanel", BackgroundColor3 = Color3.fromRGB(25, 34, 31),
	BackgroundTransparency = 0.15}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, panel)
local function label(parent, text, position, size)
	return make("TextLabel", {BackgroundTransparency = 1, Position = position, Size = size,
		Text = text, TextColor3 = Color3.fromRGB(240, 244, 231), TextSize = 14,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.Gotham}, parent)
end
local phaseLabel = label(panel, "Connecting to world...", UDim2.fromOffset(10, 4), UDim2.new(1, -140, 0, 24))
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
local effects = button(gui, "Reduced: On", UDim2.new(), UDim2.fromOffset(126, 44))
local flashlight = button(gui, "Flashlight (F)", UDim2.new(), UDim2.fromOffset(110, 44))
local pulse = button(gui, "Pulse (Q)", UDim2.new(), UDim2.fromOffset(110, 44))
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
local chipKey
local function applyChip(view)
	local key = view.kind .. "|" .. view.text
	if key == chipKey then return end
	chipKey = key
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
local reduced = true
local state, actionRemote, lastUpdate = nil, nil, 0
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
		phaseLabel.Position, phaseLabel.Size = UDim2.fromOffset(8, 3), UDim2.new(1, -16, 0, 16)
		warningLabel.Position, warningLabel.Size = UDim2.fromOffset(8, 19), UDim2.new(1, -16, 0, 30)
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
listen(effects.Activated, function()
	reduced = not reduced
	effects.Text = reduced and "Reduced: On" or "Reduced: Off"
end)
listen(UserInputService.InputBegan, function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.F then request("Flashlight") end
	if input.KeyCode == Enum.KeyCode.Q then request("LumipolPulse") end
end)

-- Cache and restore only the Lighting properties this controller owns locally.
local original = {ClockTime = Lighting.ClockTime, Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient, FogColor = Lighting.FogColor,
	FogStart = Lighting.FogStart, FogEnd = Lighting.FogEnd}
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local ownsAtmosphere = not atmosphere
if not atmosphere then
	atmosphere = make("Atmosphere", {Name = "WildboundLocalAtmosphere", Density = 0.2,
		Color = original.FogColor, Haze = 0}, Lighting)
end
local originalAtmosphere = {Density = atmosphere.Density, Color = atmosphere.Color, Haze = atmosphere.Haze}
local pet
local function destroyPet()
	if pet then pet:Destroy(); pet = nil end
end
local function newPet(position)
	local model = make("Model", {Name = "WildboundLocalLumipol"}, workspace)
	-- Not Neon: it bloomed into a white disc that filled the view when the camera was close.
	local body = make("Part", {Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4),
		Color = Color3.fromRGB(181, 220, 140), Material = Enum.Material.SmoothPlastic, Anchored = true,
		CanCollide = false, CanTouch = false, CanQuery = false, Position = position}, model)
	model.PrimaryPart = body
	return model
end
-- Smooth only what the player sees. The server moves Body in 0.2 s steps and stays authoritative;
-- Body is never written here. The art and the ground cue slide between the last two server poses.
-- Set the local attribute GuardianSmoothing to false to see the raw steps (used to measure them).
local smoothingModule = ReplicatedStorage:WaitForChild("WildboundGuardianSmoothing", 10)
local Smoothing = smoothingModule and require(smoothingModule)
if not Smoothing then warn("Wildbound world: guardian smoothing unavailable; steps stay visible.") end
local follow = { smoothing = Smoothing and Smoothing.new() }
local function guardianParts()
	local map = workspace:FindFirstChild("WildboundP0")
	local runtime = map and map:FindFirstChild("WildboundWorldRuntime")
	local model = runtime and runtime:FindFirstChild("Silueta")
	local body = model and model:FindFirstChild("Body")
	if not (model and body and body:IsA("BasePart")) then return nil end
	return model, body, model:FindFirstChild("SiluetaVisual"), model:FindFirstChild("GroundCue")
end
local function followGuardian()
	if not Smoothing then return end
	local model, body, art, cue = guardianParts()
	if model ~= follow.model then
		follow.model, follow.art, follow.cue, follow.artRel, follow.cueRel, follow.lastPose = model, nil, nil, nil, nil, nil
		Smoothing.reset(follow.smoothing)
	end
	if not model then return end
	local now = os.clock()
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
RunService:BindToRenderStep("WildboundGuardianSmoothing", Enum.RenderPriority.Last.Value, followGuardian)
local function cooldown(readyAt, now)
	if type(readyAt) ~= "number" then return "?" end
	local remaining = math.max(0, math.ceil(readyAt - now))
	return remaining > 0 and (remaining .. "s") or "Ready"
end
local elapsed = 0
listen(RunService.Heartbeat, function(dt)
	if not gui.Parent then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local fresh = state and os.clock() - lastUpdate < 5
	local petAllowed = fresh and state.hasLumipol == true and state.alive == true
		and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0
	if petAllowed then
		local target = root.Position + root.CFrame.RightVector * 3 + Vector3.new(0, 2 + math.sin(os.clock() * 2) * 0.25, 0)
		if not pet then pet = newPet(target) end
		pet:PivotTo(pet:GetPivot():Lerp(CFrame.new(target), 1 - math.exp(-5 * dt)))
		-- Fade the companion as the camera nears it, so it can never fill the view.
		local camera = workspace.CurrentCamera
		local petBody = pet:FindFirstChild("Body")
		if petBody and camera then
			petBody.Transparency = View.companionTransparency((camera.CFrame.Position - petBody.Position).Magnitude)
		end
	else
		destroyPet()
	end
	-- The chip updates every frame and never hides with the inventory (M2.3).
	local guardianState = fresh and type(state.guardian) == "table" and state.guardian or {}
	applyChip(View.chip(guardianState.awareness, fresh == true, workspace:GetServerTimeNow(), compact))
	elapsed += dt
	if elapsed < 0.1 then return end
	local step = elapsed
	elapsed = 0
	local hidden = inventoryOpen()
	panel.Visible, effects.Visible, flashlight.Visible, pulse.Visible = not hidden, not hidden, not hidden, not hidden
	flashlight.Active, pulse.Active = not not fresh, not not fresh
	flashlight.AutoButtonColor, pulse.AutoButtonColor = not not fresh, not not fresh
	if not fresh then
		flashlight.Text, pulse.Text = "Flashlight unavailable", "Pulse unavailable"
		phaseLabel.Text = "World state unavailable"
		warningLabel.Text = "Waiting for server updates."
		return
	end
	local now = workspace:GetServerTimeNow()
	phaseLabel.Text = tostring(state.phase or "Unknown") .. " · " .. math.max(0, math.ceil((state.nextPhaseAt or now) - now)) .. "s"
	local guardian = guardianState
	-- Only the targeted player receives an attack deadline, inside their own awareness (M2.2).
	local aware = type(guardian.awareness) == "table" and guardian.awareness or {}
	local attack = aware.state == "seen" and type(aware.attackEndsAt) == "number" and aware.attackEndsAt > now
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
	flashlight.Text = (keys and "Flashlight (F)\n" or "Flashlight\n") .. cooldown(state.flashlightReadyAt, now)
	pulse.Text = (keys and "Pulse (Q)\n" or "Pulse\n")
		.. (state.hasLumipol and cooldown(state.pulseReadyAt, now) or "Equip Lumipol")
	local fog = state.isFog == true
	local night = state.phase == "Night"
	local strength = reduced and 0.45 or 1
	local ambient = original.Ambient:Lerp(night and Color3.fromRGB(34, 46, 76) or Color3.fromRGB(102, 113, 100), strength)
	local outdoor = original.OutdoorAmbient:Lerp(night and Color3.fromRGB(40, 54, 86) or Color3.fromRGB(126, 136, 118), strength)
	local alpha = 1 - math.exp(-step * 0.5)
	Lighting.Ambient = Lighting.Ambient:Lerp(ambient, alpha)
	Lighting.OutdoorAmbient = Lighting.OutdoorAmbient:Lerp(outdoor, alpha)
	Lighting.FogColor = Lighting.FogColor:Lerp(fog and (night and Color3.fromRGB(40, 54, 72) or Color3.fromRGB(96, 110, 105)) or original.FogColor, alpha)
	Lighting.FogStart += ((fog and 45 or original.FogStart) - Lighting.FogStart) * alpha
	Lighting.FogEnd += ((fog and (reduced and 180 or 130) or original.FogEnd) - Lighting.FogEnd) * alpha
	if atmosphere.Parent == Lighting then
		local density = fog and (night and (reduced and 0.35 or 0.4) or 0.3) or 0.2
		atmosphere.Density += (density - atmosphere.Density) * alpha
		atmosphere.Color = atmosphere.Color:Lerp(fog and (night and Color3.fromRGB(78, 94, 116) or Color3.fromRGB(140, 153, 145)) or originalAtmosphere.Color, alpha)
		atmosphere.Haze += ((fog and (reduced and 0.5 or 1) or 0) - atmosphere.Haze) * alpha
	end
	if type(state.clockTime) == "number" then
		local delta = (state.clockTime - Lighting.ClockTime + 12) % 24 - 12
		Lighting.ClockTime = (Lighting.ClockTime + delta * alpha) % 24
	end
end)
listen(gui.Destroying, function()
	for _, connection in ipairs(connections) do connection:Disconnect() end
	pcall(function() RunService:UnbindFromRenderStep("WildboundGuardianSmoothing") end)
	destroyPet()
	for key, value in pairs(original) do Lighting[key] = value end
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
		phaseLabel.Text = "World server unavailable. Please rejoin."
		return
	end
	actionRemote = action
	listen(updates.OnClientEvent, function(payload)
		if type(payload) ~= "table" then return end
		state, lastUpdate = payload, os.clock()
		View.setNotice(noticeState, View.pickNotice(payload, compact), os.clock())
	end)
	for _ = 1, 3 do
		if not gui.Parent or state then break end
		request("RequestSnapshot")
		task.wait(3)
	end
end)





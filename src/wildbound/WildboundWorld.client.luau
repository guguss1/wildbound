-- Local presentation only; all actions and eligibility are decided by the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")
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
local effects = button(gui, "Reduced: Off", UDim2.new(), UDim2.fromOffset(126, 44))
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
listen(effects.Activated, function()
	reduced = not reduced
	gui:SetAttribute("Reduced", reduced)
	effects.Text = reduced and "Reduced: On" or "Reduced: Off"
end)
-- The Settings screen sets the same attribute; follow it so the button always shows the real value.
listen(gui:GetAttributeChangedSignal("Reduced"), function()
	local value = gui:GetAttribute("Reduced")
	if type(value) == "boolean" and value ~= reduced then
		reduced = value
		effects.Text = reduced and "Reduced: On" or "Reduced: Off"
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
	FogStart = Lighting.FogStart, FogEnd = Lighting.FogEnd}
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local ownsAtmosphere = not atmosphere
if not atmosphere then
	atmosphere = make("Atmosphere", {Name = "WildboundLocalAtmosphere", Density = 0.2,
		Color = original.FogColor, Haze = 0}, Lighting)
end
local originalAtmosphere = {Density = atmosphere.Density, Color = atmosphere.Color, Haze = atmosphere.Haze}
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
				if camera then body.Transparency = View.companionTransparency((camera.CFrame.Position - body.Position).Magnitude) end
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
	return remaining > 0 and (remaining .. "s") or "Ready"
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
		flashlight.Text, pulse.Text = "Flashlight unavailable", "Pulse unavailable"
		phaseLabel.Text = "World state unavailable"
		warningLabel.Text = "Waiting for server updates."
		return
	end
	local now = workspace:GetServerTimeNow()
	phaseLabel.Text = tostring(state.phase or "Unknown") .. " · " .. math.max(0, math.ceil((state.nextPhaseAt or now) - now)) .. "s"
		.. (state.marked == true and " · MARKED" or "")
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
			if type(payload.notice) == "string" and payload.notice ~= "" then
				View.setNotice(noticeState, View.pickNotice(payload, compact), os.clock())
			end
		end)
	end
	listen(player.CharacterAdded, function() task.spawn(reportReady) end)
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





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

local function make(className, properties, parent)
	local item = Instance.new(className)
	for key, value in pairs(properties) do item[key] = value end
	item.Parent = parent
	return item
end
local gui = make("ScreenGui", {Name = "WildboundWorldUI", ResetOnSpawn = false}, playerGui)
local panel = make("Frame", {Position = UDim2.fromOffset(12, 100), Size = UDim2.new(1, -24, 0, 92),
	BackgroundColor3 = Color3.fromRGB(25, 34, 31), BackgroundTransparency = 0.15}, gui)
make("UISizeConstraint", {MaxSize = Vector2.new(400, 92)}, panel)
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
local effects = button(panel, "Reduced: On", UDim2.new(1, -126, 0, 0), UDim2.fromOffset(126, 44))
local controls = make("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -90),
	Size = UDim2.fromOffset(228, 44), BackgroundTransparency = 1}, gui)
local flashlight = button(controls, "Flashlight (F)", UDim2.fromOffset(0, 0), UDim2.fromOffset(110, 44))
local pulse = button(controls, "Pulse (Q)", UDim2.fromOffset(118, 0), UDim2.fromOffset(110, 44))
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
local lastAction = 0
local function request(action)
	if not actionRemote or (action ~= "RequestSnapshot" and (inventoryOpen() or not state or os.clock() - lastUpdate >= 5)) then return end
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
	if processed or UserInputService:GetFocusedTextBox() or inventoryOpen() then return end
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
	local body = make("Part", {Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2),
		Color = Color3.fromRGB(181, 220, 140), Material = Enum.Material.Neon, Anchored = true,
		CanCollide = false, CanTouch = false, CanQuery = false, Position = position}, model)
	model.PrimaryPart = body
	return model
end
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
	else
		destroyPet()
	end
	elapsed += dt
	if elapsed < 0.1 then return end
	local step = elapsed
	elapsed = 0
	local hidden = inventoryOpen()
	controls.Visible = not hidden
	panel.Visible = not hidden
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
	local guardian = type(state.guardian) == "table" and state.guardian or {}
	if type(guardian.telegraphEndsAt) == "number" and guardian.telegraphEndsAt > now then
		warningLabel.Text = "Attack incoming: move away!"
	elseif guardian.threat then
		warningLabel.Text = "Threat nearby: move toward shelter."
	elseif type(guardian.revealedUntil) == "number" and guardian.revealedUntil > now then
		warningLabel.Text = "Silueta revealed. Keep moving."
	elseif state.phase == "Dusk" then
		warningLabel.Text = "Dusk: night is approaching."
	elseif state.isFog then
		warningLabel.Text = "Fog forest: stay alert."
	else
		warningLabel.Text = "Explore or return to camp."
	end
	flashlight.Text = "Flashlight (F)\n" .. cooldown(state.flashlightReadyAt, now)
	pulse.Text = "Pulse (Q)\n" .. (state.hasLumipol and cooldown(state.pulseReadyAt, now) or "Equip Lumipol")
	local fog = state.isFog == true
	local night = state.phase == "Night"
	local strength = reduced and 0.45 or 1
	local ambient = original.Ambient:Lerp(night and Color3.fromRGB(44, 56, 58) or Color3.fromRGB(102, 113, 100), strength)
	local outdoor = original.OutdoorAmbient:Lerp(night and Color3.fromRGB(49, 60, 65) or Color3.fromRGB(126, 136, 118), strength)
	local alpha = 1 - math.exp(-step * 0.5)
	Lighting.Ambient = Lighting.Ambient:Lerp(ambient, alpha)
	Lighting.OutdoorAmbient = Lighting.OutdoorAmbient:Lerp(outdoor, alpha)
	Lighting.FogColor = Lighting.FogColor:Lerp(fog and Color3.fromRGB(96, 110, 105) or original.FogColor, alpha)
	Lighting.FogStart += ((fog and 45 or original.FogStart) - Lighting.FogStart) * alpha
	Lighting.FogEnd += ((fog and (reduced and 180 or 130) or original.FogEnd) - Lighting.FogEnd) * alpha
	if atmosphere.Parent == Lighting then
		local density = fog and (night and (reduced and 0.35 or 0.4) or 0.3) or 0.2
		atmosphere.Density += (density - atmosphere.Density) * alpha
		atmosphere.Color = atmosphere.Color:Lerp(fog and Color3.fromRGB(140, 153, 145) or originalAtmosphere.Color, alpha)
		atmosphere.Haze += ((fog and (reduced and 0.5 or 1) or 0) - atmosphere.Haze) * alpha
	end
	if type(state.clockTime) == "number" then
		local delta = (state.clockTime - Lighting.ClockTime + 12) % 24 - 12
		Lighting.ClockTime = (Lighting.ClockTime + delta * alpha) % 24
	end
end)
listen(gui.Destroying, function()
	for _, connection in ipairs(connections) do connection:Disconnect() end
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
		if type(payload.notice) == "string" and payload.notice ~= "" then statusLabel.Text = payload.notice end
	end)
	for _ = 1, 3 do
		if not gui.Parent or state then break end
		request("RequestSnapshot")
		task.wait(3)
	end
end)





-- Client presentation only. The server owns all collection and interaction state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("WildboundUI")
if old then old:Destroy() end

-- Pure layout and view rules are shared with the world controller. Without them the fixed layout stays.
local layoutModule = ReplicatedStorage:WaitForChild("WildboundHudLayout", 10)
local viewModule = ReplicatedStorage:WaitForChild("WildboundHudView", 10)
local Layout = layoutModule and require(layoutModule)
local View = viewModule and require(viewModule)
-- M5.8: the camp screen, the loss line and the compass read these. Without them the Bag tab stays as it was.
local campModule = ReplicatedStorage:WaitForChild("WildboundCampView", 10)
local economyModule = ReplicatedStorage:WaitForChild("WildboundEconomy", 10)
local configModule = ReplicatedStorage:WaitForChild("WildboundEconomyConfig", 10)
local Camp = campModule and require(campModule)
local Economy = economyModule and require(economyModule)
local Config = configModule and require(configModule)
local campReady = Camp ~= nil and Economy ~= nil and Config ~= nil and Layout ~= nil

local gui = Instance.new("ScreenGui")
gui.Name = "WildboundUI"
gui.ResetOnSpawn = false
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

local function make(className, properties, parent)
	local instance = Instance.new(className)
	for key, value in pairs(properties) do instance[key] = value end
	instance.Parent = parent
	return instance
end
local ink = Color3.fromRGB(240, 244, 231)
local amber = Color3.fromRGB(255, 214, 120)
local dark = Color3.fromRGB(25, 34, 31)
local accent = Color3.fromRGB(77, 115, 88)
local accentOff = Color3.fromRGB(58, 68, 62)
local function label(parent, text, size)
	return make("TextLabel", {BackgroundTransparency = 1, Text = text, TextColor3 = ink,
		TextSize = size, Font = Enum.Font.Gotham, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left}, parent)
end
local function button(parent, text)
	local b = make("TextButton", {Text = text, BackgroundColor3 = accent, TextColor3 = ink,
		TextSize = 16, Font = Enum.Font.GothamBold, AutoButtonColor = true}, parent)
	make("UICorner", {CornerRadius = UDim.new(0, 7)}, b)
	local scale = make("UIScale", {Scale = 1}, b)
	b.MouseEnter:Connect(function() TweenService:Create(scale, TweenInfo.new(0.12), {Scale = 1.02}):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(scale, TweenInfo.new(0.12), {Scale = 1}):Play() end)
	return b
end
local function place(item, rect)
	item.Position, item.Size = UDim2.fromOffset(rect.x, rect.y), UDim2.fromOffset(rect.w, rect.h)
end

local hud = make("Frame", {BackgroundColor3 = dark, BackgroundTransparency = 0.15,
	Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -168, 0, 82)}, gui)
make("UISizeConstraint", {MaxSize = Vector2.new(430, 82)}, hud)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, hud)
local objective = label(hud, "Collect. Return to camp.\nSession only.", 15)
objective.Position = UDim2.fromOffset(10, 5)
objective.Size = UDim2.new(1, -20, 0, 42)
local status = label(hud, "Connecting to server...", 14)
status.Position = UDim2.fromOffset(10, 49)
status.Size = UDim2.new(1, -20, 0, 28)
local open = button(gui, "Inventory (I)")
open.AnchorPoint = Vector2.new(1, 0)
open.Position = UDim2.new(1, -12, 0, 12)
open.Size = UDim2.fromOffset(132, 44)

local panel = make("Frame", {Name = "InventoryPanel", Visible = false, BackgroundColor3 = dark,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromScale(0.88, 0.75)}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 10)}, panel)
-- Header: two tabs and Close, each at least 44 pixels (the rectangles come from the camp view module).
local bagTab = button(panel, "Bag")
bagTab.Name = "BagTab"
local campTab = button(panel, "Camp")
campTab.Name = "CampTab"
local close = button(panel, "Close")
close.Name = "CloseButton"
for _, tab in ipairs({ bagTab, campTab }) do
	tab.TextSize = 16
	make("UIStroke", {Thickness = 0, Color = amber, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, tab)
end
local warning = label(panel, "Session only: progress is lost when you leave or the server stops.", 14)
warning.Name = "TabNote"
local scroll = make("ScrollingFrame", {Position = UDim2.fromOffset(12, 96),
	Size = UDim2.new(1, -24, 1, -108), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y}, panel)
make("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)
campTab.Visible = campReady

-- Status line: a server notice shows for a few seconds and then goes; a local error stays until replaced.
local compact, statusBudget = false, 40
local stickyStatus = "Connecting to server..."
local noticeState = View and View.newNotice()
local hudWidth = 430
local lastSnapshot, compassText = nil, nil
local tab, busy, atCamp = "bag", false, nil
local rowWidth, rowText = 330, 15
local rebuild
local function refreshStatus()
	if not View then
		status.Text = stickyStatus
		return
	end
	local notice = View.currentNotice(noticeState, os.clock())
	local text = notice or stickyStatus
	if compact then
		-- One slot on small screens: a message replaces the objective line, which returns afterwards.
		local showing = text ~= ""
		status.Visible, objective.Visible = showing, not showing
	else
		status.Visible, objective.Visible = true, true
	end
	status.Text = View.fit(text, statusBudget)
end
local function showNotice(text)
	if not View then
		status.Text = text
		return
	end
	View.setNotice(noticeState, text, os.clock())
	refreshStatus()
	task.delay(View.CONSTANTS.NOTICE_SECONDS + 0.1, refreshStatus)
end
local function showSticky(text)
	stickyStatus = text
	refreshStatus()
end
-- The HUD line (M5.8): what a defeat right now would take, with a shape cue and words. When nothing is at
-- risk the explorer compass, then the old objective, take its place.
local function updateObjective()
	local budget = Layout and Layout.charBudget(hudWidth - (compact and 16 or 20), compact and 13 or 15, 1) or 40
	local loss = campReady and lastSnapshot and Camp.lossLine(lastSnapshot, budget) or nil
	local risky = loss ~= nil and loss.atRisk
	local second = risky and loss.text or compassText
	if compact then
		objective.Text = second and (View and View.fit(second, budget) or second) or "Collect. Return to camp."
	else
		objective.Text = "Collect. Return to camp.\n" .. (second and (View and View.fit(second, budget) or second) or "Session only.")
	end
	objective.TextColor3 = risky and amber or ink
end
-- Apply the pure layout: text in the top-left corner, the Inventory button with the other controls.
local function applyLayout()
	if not Layout then return end
	local size = gui.AbsoluteSize
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local layout = Layout.compute(size.X, size.Y, {touch = touch})
	compact = layout.mode == "compact"
	local rects = layout.rects
	hudWidth = rects.hud.w
	hud.Position, hud.Size = UDim2.fromOffset(rects.hud.x, rects.hud.y), UDim2.fromOffset(rects.hud.w, rects.hud.h)
	open.AnchorPoint = Vector2.new(0, 0)
	open.Position = UDim2.fromOffset(rects.inventory.x, rects.inventory.y)
	open.Size = UDim2.fromOffset(rects.inventory.w, rects.inventory.h)
	open.Text = UserInputService.KeyboardEnabled and "Inventory (I)" or "Inventory"
	open.TextSize = compact and 14 or 16
	rowText = compact and 13 or 15
	local noteHeight = compact and 20 or 24
	if campReady then
		-- The panel sits below the awareness chip and inside the screen; every header button is 44 or more.
		local rect = Camp.panel(size.X, size.Y, rects.chip)
		panel.AnchorPoint = Vector2.new(0, 0)
		place(panel, rect)
		local header = Camp.header(rect.w)
		place(bagTab, header.bag); place(campTab, header.camp); place(close, header.close)
		warning.Position, warning.Size = UDim2.fromOffset(12, header.bottom + 2), UDim2.new(1, -24, 0, noteHeight)
		local top = header.bottom + 2 + noteHeight + 2
		scroll.Position, scroll.Size = UDim2.fromOffset(12, top), UDim2.new(1, -24, 1, -(top + 6))
		rowWidth = rect.w - 24 - scroll.ScrollBarThickness
	else
		panel.Size = UDim2.fromScale(0.88, 0.75)
		bagTab.Position, bagTab.Size = UDim2.fromOffset(8, 4), UDim2.fromOffset(84, 44)
		close.Position, close.Size = UDim2.new(1, -86, 0, 4), UDim2.fromOffset(78, 44)
		warning.Position, warning.Size = UDim2.fromOffset(12, 52), UDim2.new(1, -24, 0, noteHeight)
		scroll.Position, scroll.Size = UDim2.fromOffset(12, 78), UDim2.new(1, -24, 1, -90)
		rowWidth = 330
	end
	warning.TextSize = rowText - (compact and 0 or 1)
	if compact then
		status.TextSize = 13
		status.Position, status.Size = UDim2.fromOffset(8, 2), UDim2.new(1, -16, 0, 32)
		objective.TextSize = 13
		objective.Position, objective.Size = UDim2.fromOffset(8, 3), UDim2.new(1, -16, 0, 18)
		statusBudget = Layout.charBudget(rects.hud.w - 16, 13, 2)
	else
		status.TextSize = 14
		status.Position, status.Size = UDim2.fromOffset(10, 49), UDim2.new(1, -20, 0, 28)
		objective.TextSize = 15
		objective.Position, objective.Size = UDim2.fromOffset(10, 5), UDim2.new(1, -20, 0, 42)
		statusBudget = Layout.charBudget(rects.hud.w - 20, 14, 1)
	end
	updateObjective()
	refreshStatus()
	if rebuild then rebuild() end
end

local actionRemote
local receivedSnapshot = false
local lastRequest = 0
local ECONOMY_ACTIONS = { Craft = true, Upgrade = true, Learn = true, ArmSeal = true, SealNewest = true,
	ArmTotem = true, DisarmTotem = true }
local function request(action, uid)
	if not actionRemote then
		showSticky("Server unavailable. Please rejoin.")
		return
	end
	local now = os.clock()
	if now - lastRequest < 0.5 then return end
	lastRequest = now
	-- A second tap on a camp button waits for the server's reply, so nothing is bought twice by accident.
	if ECONOMY_ACTIONS[action] then
		busy = true
		task.delay(2, function()
			if busy and os.clock() - lastRequest >= 1.9 then
				busy = false
				if rebuild then rebuild() end
			end
		end)
		if rebuild then rebuild() end
	end
	actionRemote:FireServer(action, uid)
end

-- One row of the panel. spec = { text, label?, action?, argument?, enabled?, header? }.
local order = 0
local function addRow(spec)
	order += 1
	if spec.header then
		local title = label(scroll, spec.text, rowText)
		title.Font = Enum.Font.GothamBold
		title.TextColor3 = amber
		title.Size = UDim2.new(1, -8, 0, 24)
		title.LayoutOrder = order
		return
	end
	local hasButton = spec.label ~= nil
	local height = campReady and Camp.rowHeight(spec, rowWidth, rowText) or 56
	local item = make("Frame", {BackgroundColor3 = Color3.fromRGB(42, 53, 47), LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, height)}, scroll)
	make("UICorner", {CornerRadius = UDim.new(0, 6)}, item)
	local description = label(item, spec.text, rowText)
	description.Position = UDim2.fromOffset(8, 2)
	description.Size = UDim2.new(1, hasButton and -(112 + 6) or -16, 1, -4)
	if hasButton then
		local b = button(item, spec.label)
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -5, 0.5, 0)
		b.Size = UDim2.fromOffset(98, 44)
		b.TextSize = 14
		b.Name = "Action_" .. tostring(spec.action)
		if spec.enabled == false then
			-- Off is shown by dim colour and by the reason written in the row, never by colour alone.
			b.Active, b.AutoButtonColor = false, false
			b.BackgroundColor3, b.TextColor3 = accentOff, Color3.fromRGB(190, 198, 190)
		else
			b.Activated:Connect(function() request(spec.action, spec.argument) end)
		end
	end
end

local function bagRows(snapshot)
	local pending = snapshot.pending or {}
	local eggs = snapshot.bankedEggs or {}
	local registered = snapshot.registered or {}
	local seals = snapshot.consumables and snapshot.consumables.seal or snapshot.sealCharges or 0
	addRow({ text = ("Pending bag: %d/%d | Seals: %d%s"):format(#pending, snapshot.capacity or 3, seals,
		snapshot.sealArmed and " | Seal armed" or "") })
	if campReady then
		for _, spec in ipairs(Camp.quickRows(snapshot, { busy = busy })) do addRow(spec) end
	end
	addRow({ text = "Pending items are lost on defeat unless warded. A seal works anywhere." })
	if #pending == 0 then addRow({ text = "No pending items." }) end
	for index, item in ipairs(pending) do
		local name = item.kind == "Nightbloom" and ("Nightbloom bundle (%d)"):format(item.quantity or 1) or item.species .. " " .. item.kind
		addRow({ text = ("#%d "):format(index) .. name .. (item.protected and " · Protected" or " · Unprotected"),
			label = not item.protected and "Protect" or nil, action = "Protect", argument = item.uid })
	end
	-- A first strike drops one item near you for 30 s (M4.6). Only you can pick it up.
	for _, item in ipairs(snapshot.dropped or {}) do
		addRow({ text = "Dropped nearby: " .. item.species .. " " .. item.kind .. " · pick it up within 30 s" })
	end
	addRow({ text = "Banked eggs · Hatch at camp" })
	if #eggs == 0 then addRow({ text = "No banked eggs." }) end
	for _, egg in ipairs(eggs) do addRow({ text = egg.species .. " egg", label = "Hatch", action = "Hatch", argument = egg.uid }) end
	addRow({ text = "Registered creatures" })
	if #registered == 0 then addRow({ text = "No registered creatures." }) end
	for _, creature in ipairs(registered) do
		local equipped = snapshot.equippedUid == creature.uid
		addRow({ text = creature.species .. (equipped and " · Equipped" or ""), label = not equipped and "Equip" or nil,
			action = "Equip", argument = creature.uid })
	end
end

local function campRows(snapshot)
	local previous
	for _, spec in ipairs(Camp.campRows(Config, Economy, snapshot, { atCamp = atCamp, busy = busy })) do
		if spec.section ~= previous then
			previous = spec.section
			addRow({ header = true, text = spec.section == "Stock" and "Your stock" or spec.section == "Craft" and "Craft and carry"
				or spec.section == "Upgrade" and "Upgrade" or spec.section == "Skills" and "Skills" or "Companion" })
		end
		addRow(spec)
	end
end

local function paintTabs()
	for name, item in pairs({ bag = bagTab, camp = campTab }) do
		local selected = tab == name
		item.BackgroundColor3 = selected and Color3.fromRGB(110, 150, 120) or accentOff
		item.Font = selected and Enum.Font.GothamBold or Enum.Font.Gotham
		-- The chosen tab also wears an outline, so it is not told apart by colour alone.
		local stroke = item:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Thickness = selected and 3 or 0 end
		item.Text = selected and (name == "bag" and "[ Bag ]" or "[ Camp ]") or (name == "bag" and "Bag" or "Camp")
	end
end
rebuild = function()
	paintTabs()
	if campReady then warning.Text = Camp.note(tab, atCamp, compact) end
	if not lastSnapshot then return end
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
	end
	order = 0
	if tab == "camp" and campReady then campRows(lastSnapshot) else bagRows(lastSnapshot) end
end
local function render(snapshot)
	lastSnapshot = snapshot
	busy = false
	rebuild()
	updateObjective()
end
applyLayout()
listen(gui:GetPropertyChangedSignal("AbsoluteSize"), applyLayout)
listen(UserInputService:GetPropertyChangedSignal("KeyboardEnabled"), applyLayout)

local function toggle(wanted)
	-- Opening the inventory is blocked during a capture session (M3.4). Closing it is always allowed.
	if not panel.Visible and Players.LocalPlayer:GetAttribute("WildboundCapturing") == true then
		showNotice("Finish calming the Lumipol first.")
		return
	end
	if wanted == "camp" and not campReady then wanted = "bag" end
	if wanted and panel.Visible and tab == wanted then
		panel.Visible = false
		return
	end
	if wanted then tab = wanted end
	panel.Visible = wanted ~= nil or not panel.Visible
	if panel.Visible then
		rebuild()
		if not receivedSnapshot then request("RequestSnapshot") end
	end
end
listen(Players.LocalPlayer:GetAttributeChangedSignal("WildboundCapturing"), function()
	if Players.LocalPlayer:GetAttribute("WildboundCapturing") == true then panel.Visible = false end
end)
-- Test seam, local to this client: setting the attribute OpenTab to "bag", "camp" or "closed" shows that screen,
-- for runs where no tap or key can be sent. It changes nothing on the server.
listen(gui:GetAttributeChangedSignal("OpenTab"), function()
	local wanted = gui:GetAttribute("OpenTab")
	if wanted == "closed" then
		panel.Visible = false
	elseif wanted == "bag" or wanted == "camp" then
		panel.Visible = false
		toggle(wanted)
	end
end)
listen(open.Activated, function() toggle(nil) end)
listen(close.Activated, function() panel.Visible = false end)
listen(bagTab.Activated, function() tab = "bag"; rebuild() end)
listen(campTab.Activated, function() tab = "camp"; rebuild() end)
listen(UserInputService.InputBegan, function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.I then toggle(nil) end
	if input.KeyCode == Enum.KeyCode.C then toggle("camp") end
end)

-- Camp distance and the explorer compass, twice a second. Display only: the server checks every purchase.
local function campMarker()
	local map = workspace:FindFirstChild("WildboundP0")
	local marker = map and map:FindFirstChild("CampCenter", true)
	return marker and marker:IsA("BasePart") and marker or nil
end
local function gatherNodes()
	local map = workspace:FindFirstChild("WildboundP0")
	local folder = map and map:FindFirstChild("WildboundGather")
	local list = {}
	for _, model in ipairs(folder and folder:GetChildren() or {}) do
		local body = model:FindFirstChild("Body")
		local material = model:GetAttribute("Material")
		if body and body:IsA("BasePart") and type(material) == "string" then
			table.insert(list, { x = body.Position.X, z = body.Position.Z, material = material })
		end
	end
	return list
end
task.spawn(function()
	while gui.Parent do
		if campReady then
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local marker = campMarker()
			local now = nil
			if root and marker then
				now = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(marker.Position.X, 0, marker.Position.Z)).Magnitude
					<= Config.sinks.campRange
			end
			local changed = now ~= atCamp
			atCamp = now
			local effects = lastSnapshot and Economy.skillEffects(Config, lastSnapshot.skills) or {}
			local line
			if root and next(effects) ~= nil then
				local world = playerGui:FindFirstChild("WildboundWorldUI")
				line = Camp.compass(effects, gatherNodes(), root.Position.X, root.Position.Z, world and world:GetAttribute("Phase"))
			end
			local text = line and line.text or nil
			if text ~= compassText then
				compassText = text
				updateObjective()
			end
			if changed and panel.Visible and tab == "camp" then rebuild() end
		end
		task.wait(0.5)
	end
end)

-- M4.6 defeat flow: a full-screen summary before respawn, large text, closed by a tap, with no timer.
local summaryGui
local function closeLossSummary()
	if summaryGui then summaryGui:Destroy(); summaryGui = nil end
end
local function showLossSummary(summary, fallback)
	closeLossSummary()
	summaryGui = make("ScreenGui", {Name = "WildboundLossSummary", ResetOnSpawn = false, DisplayOrder = 50,
		IgnoreGuiInset = true}, playerGui)
	local sheet = make("TextButton", {Name = "Summary", Size = UDim2.fromScale(1, 1), BackgroundColor3 = dark,
		BackgroundTransparency = 0.05, AutoButtonColor = false, Modal = true, TextColor3 = ink, Font = Enum.Font.GothamBold,
		TextScaled = true, TextWrapped = true,
		Text = View and View.lossSummary(summary) or (fallback .. "\nTap to close.")}, summaryGui)
	make("UITextSizeConstraint", {MinTextSize = 14, MaxTextSize = 30}, sheet)
	make("UIPadding", {PaddingLeft = UDim.new(0.08, 0), PaddingRight = UDim.new(0.08, 0),
		PaddingTop = UDim.new(0.12, 0), PaddingBottom = UDim.new(0.12, 0)}, sheet)
	sheet.Activated:Connect(closeLossSummary)
end
listen(gui.Destroying, closeLossSummary)

task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild("WildboundNetwork", 10)
	local action = folder and folder:WaitForChild("Action", 10)
	local state = folder and folder:WaitForChild("State", 10)
	if not gui.Parent then return end
	if not (action and action:IsA("RemoteEvent") and state and state:IsA("RemoteEvent")) then
		showSticky("Server unavailable. Please rejoin.")
		return
	end
	actionRemote = action
	listen(state.OnClientEvent, function(payload)
		if type(payload) ~= "table" then return end
		if type(payload.snapshot) == "table" then
			receivedSnapshot = true
			if stickyStatus == "Connecting to server..." then showSticky("") end
			render(payload.snapshot)
		end
		if type(payload.notice) == "string" and payload.notice ~= "" then showNotice(payload.notice) end
		if payload.action == "Defeat" and type(payload.lossSummary) == "table" then
			showLossSummary(payload.lossSummary, type(payload.notice) == "string" and payload.notice or "Defeated.")
		end
	end)
	request("RequestSnapshot")
	task.wait(3)
	if gui.Parent and not receivedSnapshot then request("RequestSnapshot") end
	task.wait(3)
	if gui.Parent and not receivedSnapshot then showSticky("No response. Open inventory to retry.") end
end)

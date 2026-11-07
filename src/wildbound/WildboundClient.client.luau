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
local dark = Color3.fromRGB(25, 34, 31)
local accent = Color3.fromRGB(77, 115, 88)
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
make("UISizeConstraint", {MaxSize = Vector2.new(500, 520)}, panel)
make("UICorner", {CornerRadius = UDim.new(0, 10)}, panel)
local heading = label(panel, "Inventory", 20)
heading.Font = Enum.Font.GothamBold
heading.Position = UDim2.fromOffset(12, 6)
heading.Size = UDim2.new(1, -100, 0, 32)
-- 78 x 44: a touch target of at least 44 pixels (it was 70 x 36).
local close = button(panel, "Close")
close.Position = UDim2.new(1, -86, 0, 4)
close.Size = UDim2.fromOffset(78, 44)
local warning = label(panel, "Session only: progress is lost when you leave or the server stops.", 14)
warning.Position = UDim2.fromOffset(12, 52)
warning.Size = UDim2.new(1, -24, 0, 38)
local scroll = make("ScrollingFrame", {Position = UDim2.fromOffset(12, 96),
	Size = UDim2.new(1, -24, 1, -108), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y}, panel)
make("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)

-- Status line: a server notice shows for a few seconds and then goes; a local error stays until replaced.
local compact, statusBudget = false, 40
local stickyStatus = "Connecting to server..."
local noticeState = View and View.newNotice()
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
-- Apply the pure layout: text in the top-left corner, the Inventory button with the other controls.
local function applyLayout()
	if not Layout then return end
	local size = gui.AbsoluteSize
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local layout = Layout.compute(size.X, size.Y, {touch = touch})
	compact = layout.mode == "compact"
	local rects = layout.rects
	hud.Position, hud.Size = UDim2.fromOffset(rects.hud.x, rects.hud.y), UDim2.fromOffset(rects.hud.w, rects.hud.h)
	open.AnchorPoint = Vector2.new(0, 0)
	open.Position = UDim2.fromOffset(rects.inventory.x, rects.inventory.y)
	open.Size = UDim2.fromOffset(rects.inventory.w, rects.inventory.h)
	open.Text = UserInputService.KeyboardEnabled and "Inventory (I)" or "Inventory"
	open.TextSize = compact and 14 or 16
	if compact then
		objective.Text, objective.TextSize = "Collect. Return to camp.", 13
		objective.Position, objective.Size = UDim2.fromOffset(8, 3), UDim2.new(1, -16, 0, 18)
		status.TextSize = 13
		status.Position, status.Size = UDim2.fromOffset(8, 2), UDim2.new(1, -16, 0, 32)
		statusBudget = Layout.charBudget(rects.hud.w - 16, 13, 2)
		warning.Text, warning.TextSize = "Session only: lost when you leave.", 13
		warning.Position, warning.Size = UDim2.fromOffset(12, 52), UDim2.new(1, -24, 0, 20)
		scroll.Position, scroll.Size = UDim2.fromOffset(12, 78), UDim2.new(1, -24, 1, -90)
	else
		objective.Text, objective.TextSize = "Collect. Return to camp.\nSession only.", 15
		objective.Position, objective.Size = UDim2.fromOffset(10, 5), UDim2.new(1, -20, 0, 42)
		status.TextSize = 14
		status.Position, status.Size = UDim2.fromOffset(10, 49), UDim2.new(1, -20, 0, 28)
		statusBudget = Layout.charBudget(rects.hud.w - 20, 14, 1)
		warning.Text, warning.TextSize = "Session only: progress is lost when you leave or the server stops.", 14
		warning.Position, warning.Size = UDim2.fromOffset(12, 52), UDim2.new(1, -24, 0, 38)
		scroll.Position, scroll.Size = UDim2.fromOffset(12, 96), UDim2.new(1, -24, 1, -108)
	end
	refreshStatus()
end
applyLayout()
listen(gui:GetPropertyChangedSignal("AbsoluteSize"), applyLayout)
listen(UserInputService:GetPropertyChangedSignal("KeyboardEnabled"), applyLayout)

local actionRemote
local receivedSnapshot = false
local lastRequest = 0
local function request(action, uid)
	if not actionRemote then
		showSticky("Server unavailable. Please rejoin.")
		return
	end
	local now = os.clock()
	if now - lastRequest < 0.5 then return end
	lastRequest = now
	actionRemote:FireServer(action, uid)
end
local function row(text, actionText, action, uid)
	local item = make("Frame", {BackgroundColor3 = Color3.fromRGB(42, 53, 47),
		Size = UDim2.new(1, -8, 0, 56)}, scroll)
	make("UICorner", {CornerRadius = UDim.new(0, 6)}, item)
	local description = label(item, text, 15)
	description.Position = UDim2.fromOffset(8, 2)
	description.Size = UDim2.new(1, actionText and -112 or -16, 1, -4)
	if actionText then
		local b = button(item, actionText)
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -5, 0.5, 0)
		b.Size = UDim2.fromOffset(98, 44)
		b.Activated:Connect(function() request(action, uid) end)
	end
end
local function render(snapshot)
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	local pending = snapshot.pending or {}
	local eggs = snapshot.bankedEggs or {}
	local registered = snapshot.registered or {}
	row(("Pending bag: %d/%d | Seals: %d"):format(#pending, snapshot.capacity or 3, snapshot.sealCharges or 0))
	row("Pending items are lost on defeat unless protected at camp.")
	if #pending == 0 then row("No pending items.") end
	for index, item in ipairs(pending) do
		row(("#%d "):format(index) .. item.species .. " " .. item.kind .. (item.protected and " · Protected" or " · Unprotected"),
			not item.protected and "Protect" or nil, "Protect", item.uid)
	end
	-- A first strike drops one item near you for 30 s (M4.6). Only you can pick it up.
	for _, item in ipairs(snapshot.dropped or {}) do
		row("Dropped nearby: " .. item.species .. " " .. item.kind .. " · pick it up within 30 s")
	end
	row("Banked eggs · Hatch at camp")
	if #eggs == 0 then row("No banked eggs.") end
	for _, egg in ipairs(eggs) do row(egg.species .. " egg", "Hatch", "Hatch", egg.uid) end
	row("Registered creatures")
	if #registered == 0 then row("No registered creatures.") end
	for _, creature in ipairs(registered) do
		local equipped = snapshot.equippedUid == creature.uid
		row(creature.species .. (equipped and " · Equipped" or ""), not equipped and "Equip" or nil, "Equip", creature.uid)
	end
end
local function toggle()
	-- Opening the inventory is blocked during a capture session (M3.4). Closing it is always allowed.
	if not panel.Visible and Players.LocalPlayer:GetAttribute("WildboundCapturing") == true then
		showNotice("Finish calming the Lumipol first.")
		return
	end
	panel.Visible = not panel.Visible
	if panel.Visible and not receivedSnapshot then request("RequestSnapshot") end
end
listen(Players.LocalPlayer:GetAttributeChangedSignal("WildboundCapturing"), function()
	if Players.LocalPlayer:GetAttribute("WildboundCapturing") == true then panel.Visible = false end
end)
listen(open.Activated, toggle)
listen(close.Activated, function() panel.Visible = false end)
listen(UserInputService.InputBegan, function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.I then toggle() end
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

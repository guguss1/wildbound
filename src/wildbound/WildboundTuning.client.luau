-- Dev tuning client (docs/testing/wildbound-tuning.md). Deploy as StarterPlayer.StarterPlayerScripts.WildboundTuningClient.
-- For every player it applies the client-only values (camera kick, dread shake and vignette) from the replicated
-- ReplicatedStorage.WildboundTuning folder. Only for a developer (the server sets Player.WildboundTuningDev: Studio, or
-- the private place's owner or allowlist) it builds the slider panel; every change goes through the server's remote,
-- which checks it again. Spanish words; touch-sized controls; F8 or the "Ajustes dev" button toggles it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Schema = require(ReplicatedStorage:WaitForChild("WildboundTuningSchema"))
local View = require(ReplicatedStorage:WaitForChild("WildboundHudView"))
local player = Players.LocalPlayer

local folder = ReplicatedStorage:WaitForChild(Schema.FOLDER, 30)
if not folder then return end -- no folder: every module keeps its defaults
local read = Schema.reader(folder)

local listeners = {}
local function changed()
	Schema.apply({ View = View }, read, "client")
	for _, listener in ipairs(listeners) do task.spawn(listener) end
end
local function watch(child)
	if child:IsA("Configuration") then child.AttributeChanged:Connect(changed) end
end
for _, child in ipairs(folder:GetChildren()) do watch(child) end
folder.ChildAdded:Connect(watch)
changed()

local build -- defined below; called only after the developer check
local built = false
local function maybeBuild()
	if built or not (player:GetAttribute(Schema.DEV_ATTRIBUTE) == true) then return end
	built = true
	build()
end

local TEXT = Color3.fromRGB(236, 238, 232)
local DIM = Color3.fromRGB(160, 168, 160)
local AMBER = Color3.fromRGB(255, 196, 96)
local PANEL = Color3.fromRGB(18, 22, 22)
local BUTTON = Color3.fromRGB(46, 56, 54)
local ACCENT = Color3.fromRGB(110, 190, 150)

local function make(class, props, parent)
	local item = Instance.new(class)
	for key, value in pairs(props) do item[key] = value end
	item.Parent = parent
	return item
end
local function corner(parent, radius)
	make("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, parent)
end
local function button(text, props, parent)
	local item = make("TextButton", { Text = text, Font = Enum.Font.GothamMedium, TextSize = 15, TextColor3 = TEXT,
		BackgroundColor3 = BUTTON, AutoButtonColor = true }, parent)
	for key, value in pairs(props) do item[key] = value end
	corner(item, 8)
	return item
end

-- Snaps a value to the entry's step from its minimum, inside its range.
local function snap(entry, value)
	local steps = math.floor((value - entry.min) / entry.step + 0.5)
	return math.clamp(tonumber(Schema.format(entry.min + steps * entry.step)) or entry.default, entry.min, entry.max)
end

build = function()
	local remote = ReplicatedStorage:WaitForChild(Schema.REMOTE, 30)
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "WildboundTuningPanel", false, 60
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local toggle = button("Ajustes dev", { Name = "Toggle", Size = UDim2.fromOffset(112, 44),
		Position = UDim2.new(0, 8, 0.4, 0), BackgroundTransparency = 0.15 }, gui)
	local panel = make("Frame", { Name = "Panel", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.new(0.92, 0, 1, -16), BackgroundColor3 = PANEL, BackgroundTransparency = 0.06, Visible = false }, gui)
	corner(panel, 10)
	make("UISizeConstraint", { MaxSize = Vector2.new(440, math.huge) }, panel)
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8) }, panel)
	make("TextLabel", { Name = "Title", Text = "Ajustes de desarrollo", Font = Enum.Font.GothamBold, TextSize = 18,
		TextColor3 = TEXT, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Left }, panel)
	make("TextLabel", { Name = "Note", Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = DIM, BackgroundTransparency = 1,
		Text = "Los cambios en Play se pierden al parar. Usa «Copiar valores» para guardarlos en el código. "
			.. "Ámbar: distinto del valor del repositorio.",
		TextWrapped = true, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 26),
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, panel)
	local resetAll = button("Restablecer", { Name = "Reset", Size = UDim2.new(0.33, -6, 0, 40), Position = UDim2.fromOffset(0, 64) }, panel)
	local export = button("Copiar valores", { Name = "Export", Size = UDim2.new(0.34, -6, 0, 40),
		Position = UDim2.new(0.33, 3, 0, 64), BackgroundColor3 = Color3.fromRGB(40, 86, 66) }, panel)
	local close = button("Cerrar", { Name = "Close", Size = UDim2.new(0.33, -6, 0, 40), Position = UDim2.new(0.67, 6, 0, 64) }, panel)
	local status = make("TextLabel", { Name = "Status", Text = "", Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = AMBER,
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 108),
		TextXAlignment = Enum.TextXAlignment.Left }, panel)
	local list = make("ScrollingFrame", { Name = "Systems", Position = UDim2.fromOffset(0, 130), Size = UDim2.new(1, 0, 1, -130),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y }, panel)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, list)

	local function say(text)
		status.Text = text
		task.delay(4, function() if status.Text == text then status.Text = "" end end)
	end
	local function request(action, systemId, key, value)
		task.spawn(function()
			local ok, result, reason = pcall(function() return remote:InvokeServer(action, systemId, key, value) end)
			if not ok then say("Error de red: " .. tostring(result)) elseif result ~= true then say("Rechazado: " .. tostring(reason)) end
		end)
	end

	-- Slider sends are throttled: the latest value per row goes out at most every 0.15 s, and on release.
	local pending, rows, headers = {}, {}, {}
	task.spawn(function()
		while true do -- the panel lives for the whole session (ResetOnSpawn is off)
			for id, item in pairs(pending) do
				pending[id] = nil
				request("set", item.system, item.key, item.value)
			end
			task.wait(0.15)
		end
	end)

	local dragging = nil
	local function setPreview(row, value)
		row.preview = value
		row.refresh()
	end
	local function valueAt(row, x)
		local track = row.track
		local fraction = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		return snap(row.entry, row.entry.min + fraction * (row.entry.max - row.entry.min))
	end

	for order, system in ipairs(Schema.SYSTEMS) do
		local header = button("", { Name = system.id, Size = UDim2.new(1, -10, 0, 44), LayoutOrder = order * 2 - 1,
			TextXAlignment = Enum.TextXAlignment.Left, TextSize = 16, Font = Enum.Font.GothamBold }, list)
		make("UIPadding", { PaddingLeft = UDim.new(0, 10) }, header)
		local body = make("Frame", { Name = system.id .. "Values", Size = UDim2.new(1, -10, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order * 2, Visible = false }, list)
		make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, body)
		local function refreshHeader()
			local count = 0
			for _, entry in ipairs(system.entries) do
				if math.abs(Schema.current(entry, system.id, read) - entry.default) > 1e-9 then count += 1 end
			end
			header.Text = (body.Visible and "− " or "+ ") .. system.label .. (count > 0 and ("  · %d cambiado(s)"):format(count) or "")
			header.TextColor3 = count > 0 and AMBER or TEXT
		end
		table.insert(headers, refreshHeader)
		header.Activated:Connect(function()
			body.Visible = not body.Visible
			refreshHeader()
		end)

		for index, entry in ipairs(system.entries) do
			local row = { entry = entry, system = system.id }
			local frame = make("Frame", { Name = entry.key, Size = UDim2.new(1, 0, 0, 66), BackgroundTransparency = 1,
				LayoutOrder = index }, body)
			local label = make("TextLabel", { Name = "Label", Font = Enum.Font.Gotham, TextSize = 14, BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, frame)
			local minus = button("−", { Name = "Minus", Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(0, 24), TextSize = 20 }, frame)
			local plus = button("+", { Name = "Plus", Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -112, 0, 24), TextSize = 20 }, frame)
			local box = make("TextBox", { Name = "Value", Size = UDim2.fromOffset(66, 40), Position = UDim2.new(1, -68, 0, 24),
				Font = Enum.Font.Code, TextSize = 15, TextColor3 = TEXT, BackgroundColor3 = BUTTON, ClearTextOnFocus = false }, frame)
			corner(box, 8)
			local track = make("TextButton", { Name = "Track", Text = "", AutoButtonColor = false, Size = UDim2.new(1, -168, 0, 8),
				Position = UDim2.fromOffset(48, 40), BackgroundColor3 = Color3.fromRGB(70, 78, 76) }, frame)
			corner(track, 4)
			local fill = make("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = ACCENT, BorderSizePixel = 0 }, track)
			corner(fill, 4)
			local knob = make("Frame", { Name = "Knob", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(22, 22),
				Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = TEXT }, track)
			corner(knob, 11)
			local mark = make("Frame", { Name = "Default", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(2, 16),
				BackgroundColor3 = DIM, BorderSizePixel = 0,
				Position = UDim2.fromScale((entry.default - entry.min) / (entry.max - entry.min), 0.5) }, track)
			mark.ZIndex = 0
			row.track = track
			function row.refresh()
				local value = row.preview or Schema.current(entry, system.id, read)
				local fraction = (value - entry.min) / (entry.max - entry.min)
				knob.Position = UDim2.fromScale(fraction, 0.5)
				fill.Size = UDim2.fromScale(fraction, 1)
				local differs = math.abs(value - entry.default) > 1e-9
				label.Text = (differs and "● " or "") .. entry.label .. (differs and ("  (repo " .. Schema.format(entry.default) .. ")") or "")
				label.TextColor3 = differs and AMBER or TEXT
				if not box:IsFocused() then box.Text = Schema.format(value) end
			end
			local function send(value)
				value = snap(entry, value)
				setPreview(row, value)
				pending[system.id .. "." .. entry.key] = { system = system.id, key = entry.key, value = value }
			end
			minus.Activated:Connect(function() send((row.preview or Schema.current(entry, system.id, read)) - entry.step) end)
			plus.Activated:Connect(function() send((row.preview or Schema.current(entry, system.id, read)) + entry.step) end)
			box.FocusLost:Connect(function()
				local typed = tonumber((box.Text:gsub(",", ".")))
				if typed then send(typed) else row.refresh() end
			end)
			track.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = row
					send(valueAt(row, input.Position.X))
				end
			end)
			rows[system.id .. "." .. entry.key] = row
			row.refresh()
		end
		refreshHeader()
	end

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local row = dragging
			local value = valueAt(row, input.Position.X)
			if value ~= row.preview then
				row.preview = value
				row.refresh()
				pending[row.system .. "." .. row.entry.key] = { system = row.system, key = row.entry.key, value = value }
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = nil
		end
	end)

	-- The server's attribute write is the truth: it clears the local preview once it arrives.
	table.insert(listeners, function()
		for _, row in pairs(rows) do
			if dragging ~= row and row.preview ~= nil
				and math.abs(Schema.current(row.entry, row.system, read) - row.preview) < 1e-9 then
				row.preview = nil
			end
			row.refresh()
		end
		for _, refreshHeader in ipairs(headers) do refreshHeader() end
	end)

	-- Export: Roblox cannot write the clipboard, so the snippet sits in a selectable box.
	local sheet = make("Frame", { Name = "ExportSheet", Size = UDim2.fromScale(1, 1), BackgroundColor3 = PANEL, Visible = false,
		ZIndex = 5 }, panel)
	make("TextLabel", { Text = "Selecciona todo (Ctrl+A) y copia (Ctrl+C). Pega los valores CHANGED en el archivo indicado.",
		Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = DIM, TextWrapped = true, BackgroundTransparency = 1, ZIndex = 5,
		Size = UDim2.new(1, 0, 0, 36), TextXAlignment = Enum.TextXAlignment.Left }, sheet)
	local scroller = make("ScrollingFrame", { Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -92), ZIndex = 5,
		BackgroundColor3 = Color3.fromRGB(10, 12, 12), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.XY,
		ScrollBarThickness = 8, BorderSizePixel = 0 }, sheet)
	local snippetBox = make("TextBox", { Name = "Snippet", ClearTextOnFocus = false, MultiLine = true, TextEditable = true,
		Font = Enum.Font.Code, TextSize = 12, TextColor3 = TEXT, BackgroundTransparency = 1, ZIndex = 5,
		AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0), TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top }, scroller)
	local closeSheet = button("Cerrar", { Size = UDim2.new(1, 0, 0, 44), Position = UDim2.new(0, 0, 1, -44), ZIndex = 5 }, sheet)
	closeSheet.Activated:Connect(function() sheet.Visible = false end)
	snippetBox.FocusLost:Connect(function() snippetBox.Text = Schema.snippet(read) end)

	export.Activated:Connect(function()
		snippetBox.Text = Schema.snippet(read)
		sheet.Visible = true
	end)
	resetAll.Activated:Connect(function()
		for _, row in pairs(rows) do row.preview = nil end
		request("reset")
		say("Valores del repositorio restablecidos.")
	end)
	local function setOpen(open)
		panel.Visible = open
		toggle.Text = open and "Ocultar dev" or "Ajustes dev"
	end
	close.Activated:Connect(function() setOpen(false) end)
	toggle.Activated:Connect(function() setOpen(not panel.Visible) end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed and UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == Enum.KeyCode.F8 then setOpen(not panel.Visible) end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

player:GetAttributeChangedSignal(Schema.DEV_ATTRIBUTE):Connect(maybeBuild)
maybeBuild()

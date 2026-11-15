-- Hub roulette panel (PF5, user decision 2026-11-14). Presentation only: the server (WildboundRouletteService) owns
-- the price, the roll, the prize and the Esencia. The station's prompt opens this panel with the odds of every prize,
-- the price (or "Tirada gratis") and the pity counter, before any spin. "Girar" asks the server to spin; the panel
-- plays a short spin over the odds rows and lands on the row of the prize the server rolled. This script only ever
-- sends one of two words: "open" or "spin".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Text = require(ReplicatedStorage:WaitForChild("WildboundText"))
local Style = require(ReplicatedStorage:WaitForChild("WildboundUiStyle"))
local network = ReplicatedStorage:WaitForChild("WildboundNetwork")
local remote = network:WaitForChild("Roulette")

local WORDS = Text.ROULETTE
local SPIN_SECONDS = 1.25
local RARITY_TONE = { Comun = "slate", Rara = "blue", Epica = "purple", Legendaria = "gold" }

local gui = Instance.new("ScreenGui")
gui.Name = "WildboundRouletteGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 35 -- above the HUD and the base guide's tutorial card (20), so the buttons are never covered
Style.screen(gui)

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(1, -32, 0.86, 0)
panel.Visible = false
Style.panel(panel)
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(400, 520)
limit.Parent = panel
local pad = Instance.new("UIPadding")
pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 12), UDim.new(0, 12)
pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
pad.Parent = panel
panel.Parent = gui

local function label(name, y, height, size, bold)
	local item = Instance.new("TextLabel")
	item.Name = name
	item.BackgroundTransparency = 1
	item.Position = UDim2.new(0, 0, 0, y)
	item.Size = UDim2.new(1, 0, 0, height)
	item.TextSize = size
	item.TextWrapped = true
	item.TextXAlignment = Enum.TextXAlignment.Center
	item.Text = ""
	if bold then Style.title(item) else
		item.TextColor3 = Style.COLORS.soft
		Style.body(item)
	end
	item.Parent = panel
	return item
end

local title = label("Title", 0, 30, 26, true)
title.Text = WORDS.title
local priceLine = label("Price", 34, 24, 20, true)
local pityLine = label("Pity", 60, 20, 15)
local balanceLine = label("Balance", 80, 20, 15)
local oddsHeader = label("OddsHeader", 104, 22, 17, true)
oddsHeader.Text = WORDS.oddsHeader

local list = Instance.new("ScrollingFrame")
list.Name = "Odds"
list.Position = UDim2.new(0, 0, 0, 130)
list.Size = UDim2.new(1, 0, 1, -262)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local note = label("Note", 0, 18, 13)
note.Position = UDim2.new(0, 0, 1, -128)
note.Text = WORDS.oddsNote
local resultLine = label("Result", 0, 44, 18, true)
resultLine.Position = UDim2.new(0, 0, 1, -108)

local function button(name, text, tone, x, width)
	local item = Instance.new("TextButton")
	item.Name = name
	item.AnchorPoint = Vector2.new(0, 1)
	item.Position = UDim2.new(x, x > 0 and 4 or 0, 1, 0)
	item.Size = UDim2.new(width, -4, 0, 52)
	item.Text = text
	item.TextSize = 24
	item.AutoButtonColor = false
	Style.button(item, tone)
	item.Parent = panel
	return item
end
local spinButton = button("Spin", WORDS.spin, "green", 0, 0.62)
local closeButton = button("Close", WORDS.close, "red", 0.62, 0.38)

gui.Parent = player:WaitForChild("PlayerGui")

local rows = {}
local view = nil
local spinning = false
local spinToken = 0

local function percentText(value)
	return (string.format("%.2f", value):gsub("%.", ","))
end

local function paintRow(row, lit)
	row.frame.BackgroundColor3 = lit and Style.color("green") or Style.color(RARITY_TONE[row.rarityKey] or "row")
end

local function buildRows(odds)
	for _, row in ipairs(rows) do row.frame:Destroy() end
	rows = {}
	for index, entry in ipairs(odds) do
		local frame = Instance.new("TextLabel")
		frame.Name = "Row" .. index
		frame.LayoutOrder = index
		frame.Size = UDim2.new(1, -8, 0, 30)
		frame.TextSize = 15
		frame.TextWrapped = true
		frame.Text = WORDS.oddsRow:format(entry.label, entry.rarity, percentText(entry.percent))
		frame.TextColor3 = Style.COLORS.ink
		Style.card(frame, RARITY_TONE[entry.rarityKey] or "row")
		Style.body(frame, true)
		frame.Parent = list
		local row = { frame = frame, rarityKey = entry.rarityKey }
		table.insert(rows, row)
		paintRow(row, false)
	end
end

local function show(next)
	if type(next) ~= "table" then return end
	view = next
	if #rows ~= #(view.odds or {}) then buildRows(view.odds or {}) end
	priceLine.Text = view.free and WORDS.free or WORDS.price:format(view.price or 0)
	if view.pityEnabled then
		pityLine.Text = view.pityLeft == 1 and WORDS.pityNext or WORDS.pity:format(view.pityLeft or 0)
	else
		pityLine.Text = ""
	end
	balanceLine.Text = WORDS.balance:format(view.ember or 0)
	if not spinning then
		spinButton.Text = WORDS.spin
		Style.tint(spinButton, view.canSpin and "green" or "off")
	end
end

local function stopSpin()
	spinning = false
	spinToken += 1
	for _, row in ipairs(rows) do paintRow(row, false) end
end

-- A short spin over the rows that slows down and lands on the server's prize row.
local function playSpin(index, done)
	local token = spinToken
	local count = #rows
	if count == 0 or type(index) ~= "number" then done(); return end
	local steps = count * 2 + index
	task.spawn(function()
		local lit = nil
		for step = 1, steps do
			if token ~= spinToken then return end
			if lit then paintRow(lit, false) end
			lit = rows[(step - 1) % count + 1]
			paintRow(lit, true)
			local progress = step / steps
			task.wait(SPIN_SECONDS / steps * (0.4 + 1.6 * progress * progress))
		end
		if token ~= spinToken then return end
		list.CanvasPosition = Vector2.new(0, math.max(0, lit.frame.AbsolutePosition.Y - list.AbsolutePosition.Y
			+ list.CanvasPosition.Y - 60))
		local pop = TweenService:Create(lit.frame, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out,
			0, true), { Size = UDim2.new(1, -2, 0, 34) })
		pop:Play()
		done()
	end)
end

spinButton.Activated:Connect(function()
	if spinning or not view then return end
	spinning = true
	resultLine.Text = ""
	spinButton.Text = WORDS.spinning
	Style.tint(spinButton, "off")
	remote:FireServer("spin")
end)

closeButton.Activated:Connect(function()
	stopSpin()
	panel.Visible = false
end)

remote.OnClientEvent:Connect(function(kind, payload)
	if type(payload) ~= "table" then return end
	if kind == "open" then
		stopSpin()
		resultLine.Text = ""
		show(payload)
		panel.Visible = true
	elseif kind == "result" then
		panel.Visible = true
		playSpin(payload.index, function()
			spinning = false
			resultLine.Text = payload.text or ""
			local rare = payload.rarityKey == "Epica" or payload.rarityKey == "Legendaria"
			resultLine.TextColor3 = rare and Style.COLORS.gold or Style.COLORS.ink
			show(payload.view)
		end)
	elseif kind == "refused" then
		stopSpin()
		resultLine.Text = payload.text or ""
		resultLine.TextColor3 = Style.color("red")
		if payload.view then show(payload.view) end
		if view then
			spinButton.Text = WORDS.spin
			Style.tint(spinButton, view.canSpin and "green" or "off")
		end
	end
end)

player.CharacterAdded:Connect(function()
	stopSpin()
	panel.Visible = false
end)

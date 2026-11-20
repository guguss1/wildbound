-- Hub roulette panel (PF5, user decision 2026-11-14). Presentation only: the server (WildboundRouletteService) owns
-- the price, the roll, the prize and the Esencia. The station's prompt opens this panel with the odds of every prize,
-- the price (or "Tirada gratis") and the pity counter, before any spin. "Girar" asks the server to spin; the panel
-- plays a short spin over the odds rows and lands on the row of the prize the server rolled. This script only ever
-- sends one of two words: "open" or "spin".
-- P0.1 (owner request 2026-11-20): the window wears the store kit from WildboundUiStyle (docs/design/refs/
-- store-ui-reference.png): a blue window with a light panel, the outlined title, a red X beside the old "Cerrar", and a
-- cyan sunburst card for the price, the pity and the balance. Same words, same two remote words, same spin. On a wide
-- window (a phone held sideways, a computer) the odds sit in a second column so nothing is squeezed; on a narrow one
-- they sit between the card and the buttons. The rays stand still with "Efectos suaves" and while the window is shut.
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

local HEADER = 60
local CARD_HEIGHT = 100
local FOOT_HEIGHT = 100

local panel, inner = Style.kitWindow(gui, "Panel", HEADER)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(1, -24, 0.92, 0)
panel.Visible = false
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(640, 560)
limit.Parent = panel

local title = Style.kitTitle(panel, WORDS.title, 30)
title.Position = UDim2.new(0, 16, 0, 8)
title.Size = UDim2.new(1, -84, 0, HEADER - 14)
title.TextXAlignment = Enum.TextXAlignment.Left
local closeX = Style.kitClose(panel)

-- Two transparent columns inside the light panel: "Main" (the card on top, the result and buttons at the bottom) and
-- "OddsBox" (the odds). arrange() places them side by side on a wide window, or the odds between on a narrow one.
local function column(name, z)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Active = false
	frame.ZIndex = z
	frame.Parent = inner
	return frame
end
local main = column("Main", 1)
local oddsBox = column("OddsBox", 2)

local function line(parent, name, y, height, size, font, stroke)
	local item = Style.kitLabel(parent, name, "", size, font, stroke)
	item.Position = UDim2.new(0, 8, 0, y)
	item.Size = UDim2.new(1, -16, 0, height)
	Style.fitText(item, size, math.min(size, 11))
	return item
end

local card = Style.kitCard(main, "cyan", true, "PriceCard")
card.Size = UDim2.new(1, 0, 0, CARD_HEIGHT)
local priceLine = line(card, "Price", 6, 30, 24, Style.FONT_TITLE, Style.KIT_SIZES.textStroke)
local pityLine = line(card, "Pity", 38, 30, 16, Style.FONT_BOLD, 1.5)
local balanceLine = line(card, "Balance", 70, 24, 16, Style.FONT_BOLD, 1.5)

local function plain(parent, name, text, size, font)
	local item = Instance.new("TextLabel")
	item.Name = name
	item.BackgroundTransparency = 1
	item.BorderSizePixel = 0
	item.Text = text
	item.TextSize = size
	item.TextWrapped = true
	item.Font = font
	item.TextColor3 = Style.KIT_COLORS.inkDark
	item.TextXAlignment = Enum.TextXAlignment.Center
	item.Parent = parent
	return item
end

local oddsHeader = plain(oddsBox, "OddsHeader", WORDS.oddsHeader, 20, Style.FONT_TITLE)
oddsHeader.Size = UDim2.new(1, 0, 0, 24)

local list = Instance.new("ScrollingFrame")
list.Name = "Odds"
list.Position = UDim2.new(0, 0, 0, 28)
list.Size = UDim2.new(1, 0, 1, -64)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.ScrollBarImageColor3 = Style.KIT_COLORS.frame
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = oddsBox
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list
local listPad = Instance.new("UIPadding")
listPad.PaddingTop, listPad.PaddingLeft = UDim.new(0, 4), UDim.new(0, 4)
listPad.Parent = list

local note = plain(oddsBox, "Note", WORDS.oddsNote, 13, Style.FONT_BODY)
note.AnchorPoint = Vector2.new(0, 1)
note.Position = UDim2.new(0, 0, 1, 0)
note.Size = UDim2.new(1, 0, 0, 32)

local resultLine = Style.kitLabel(main, "Result", "", 18, Style.FONT_TITLE, Style.KIT_SIZES.textStroke)
resultLine.AnchorPoint = Vector2.new(0, 1)
resultLine.Position = UDim2.new(0, 0, 1, -56)
resultLine.Size = UDim2.new(1, 0, 0, 40)
Style.fitText(resultLine, 18, 12)

local function button(name, text, tone, x, width)
	local item = Style.kitButton(main, text, tone, name)
	item.AnchorPoint = Vector2.new(0, 1)
	item.Position = UDim2.new(x, x > 0 and 4 or 0, 1, 0)
	item.Size = UDim2.new(width, -4, 0, Style.KIT_SIZES.buttonHeight)
	return item
end
local spinButton = button("Spin", WORDS.spin, "green", 0, 0.62)
local closeButton = button("Close", WORDS.close, "red", 0.62, 0.38)

-- On a wide window the result fills the room between the card and the buttons, so on a short phone held sideways a
-- two-line result never draws over the card; on a narrow one it sits just above the buttons, under the odds.
local function arrange()
	if Style.isWide(inner.AbsoluteSize.X) then
		main.Position, main.Size = UDim2.new(), UDim2.new(0.46, -6, 1, 0)
		oddsBox.Position, oddsBox.Size = UDim2.new(0.46, 6, 0, 0), UDim2.new(0.54, -6, 1, 0)
		resultLine.AnchorPoint = Vector2.new(0, 0)
		resultLine.Position = UDim2.new(0, 0, 0, CARD_HEIGHT + 4)
		resultLine.Size = UDim2.new(1, 0, 1, -(CARD_HEIGHT + 8 + Style.KIT_SIZES.buttonHeight))
	else
		main.Position, main.Size = UDim2.new(), UDim2.fromScale(1, 1)
		oddsBox.Position = UDim2.new(0, 0, 0, CARD_HEIGHT + 6)
		oddsBox.Size = UDim2.new(1, 0, 1, -(CARD_HEIGHT + 6 + FOOT_HEIGHT))
		resultLine.AnchorPoint = Vector2.new(0, 1)
		resultLine.Position = UDim2.new(0, 0, 1, -56)
		resultLine.Size = UDim2.new(1, 0, 0, 40)
	end
end
inner:GetPropertyChangedSignal("AbsoluteSize"):Connect(arrange)
arrange()

local playerGui = player:WaitForChild("PlayerGui")
gui.Parent = playerGui

-- "Efectos suaves" can change while the window is open (the HUD settings stay reachable): follow it, like the other
-- clients do, so the rays stop at once.
task.spawn(function()
	local world = playerGui:WaitForChild("WildboundWorldUI")
	world:GetAttributeChangedSignal("Reduced"):Connect(function()
		if panel.Visible then
			Style.setSpin(card, Style.motion(Style.reduced(playerGui)).spin)
		end
	end)
end)

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
		Style.setLabel(spinButton, WORDS.spin)
		Style.tint(spinButton, view.canSpin and "green" or "off")
	end
end

local function stopSpin()
	spinning = false
	spinToken += 1
	for _, row in ipairs(rows) do paintRow(row, false) end
end

-- Shows the window; the card's rays turn only while it is open and never with "Efectos suaves".
local function openPanel()
	if panel.Visible then return end
	panel.Visible = true
	Style.setSpin(card, Style.motion(Style.reduced(playerGui)).spin)
end

local function hidePanel()
	stopSpin()
	panel.Visible = false
	Style.setSpin(card, false)
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
	Style.setLabel(spinButton, WORDS.spinning)
	Style.tint(spinButton, "off")
	remote:FireServer("spin")
end)

closeButton.Activated:Connect(hidePanel)
closeX.Activated:Connect(hidePanel)

remote.OnClientEvent:Connect(function(kind, payload)
	if type(payload) ~= "table" then return end
	if kind == "open" then
		stopSpin()
		resultLine.Text = ""
		show(payload)
		openPanel()
	elseif kind == "result" then
		openPanel()
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
			Style.setLabel(spinButton, WORDS.spin)
			Style.tint(spinButton, view.canSpin and "green" or "off")
		end
	end
end)

player.CharacterAdded:Connect(hidePanel)

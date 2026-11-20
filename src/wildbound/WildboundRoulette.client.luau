-- Hub roulette window (PF5, user decision 2026-11-14). Presentation only: the server (WildboundRouletteService) owns
-- the price, the roll, the prize, the Esencia and the extra spins. The station's prompt opens this window; "Girar" asks
-- the server to spin and the wheel turns to the prize the server rolled. This script only ever sends "spin" or
-- "offer" with one catalog id.
-- RW-1..RW-6 (owner request 2026-11-20: "quiero que la ui de mi juego sea exactamente igual a la de la foto que te envie
-- y que lo de la ruleta sea asi", after docs/design/refs/roulette-wheel-reference.webp): no window frame, like the
-- reference. Over a dimmed screen: "Tiradas: N" in big outlined letters, the price and balance line, the wheel
-- (WildboundRouletteWheel: one bright wedge per prize with its icon and "+10" label, a white ring and a white pointer),
-- the result line, and a row with the round "i" (the odds window, which Roblox requires before any random prize is
-- bought; it keeps the old odds words), the green "Girar" and the red "Cerrar". Three spin packs (WildboundOffers)
-- stand on the right on a wide screen, or in a row under the buttons on a phone held upright (Wheel.layout); while the
-- server's development switch is on they grant for free and say "modo desarrollo: gratis", otherwise "Próximamente".
-- "Efectos suaves" makes the spin one short turn without the bounce.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Text = require(ReplicatedStorage:WaitForChild("WildboundText"))
local Style = require(ReplicatedStorage:WaitForChild("WildboundUiStyle"))
local Wheel = require(ReplicatedStorage:WaitForChild("WildboundRouletteWheel"))
local Offers = require(ReplicatedStorage:WaitForChild("WildboundOffers"))
local Roulette = require(ReplicatedStorage:WaitForChild("WildboundRoulette"))
local network = ReplicatedStorage:WaitForChild("WildboundNetwork")
local remote = network:WaitForChild("Roulette")

local WORDS = Text.ROULETTE
local WHEEL_WORDS = Wheel.WORDS
local RARITY_TONE = { Comun = "slate", Rara = "blue", Epica = "purple", Legendaria = "gold" }
local PRIZES = {}
for _, prize in ipairs(Roulette.LIVE.prizes) do PRIZES[prize.id] = prize end

local gui = Instance.new("ScreenGui")
gui.Name = "WildboundRouletteGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 35 -- above the HUD and the base guide's tutorial card (20), so the buttons are never covered
Style.screen(gui)

-- The stage: the whole screen, dimmed; it keeps taps off the world while the wheel is open.
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromScale(1, 1)
panel.BackgroundColor3 = Style.COLORS.outline
panel.BackgroundTransparency = 0.45
panel.BorderSizePixel = 0
panel.Active = true
panel.Visible = false
panel.Parent = gui

local title = Style.kitTitle(panel, WHEEL_WORDS.spinsLeft:format(0), 36)
local info = Style.kitLabel(panel, "Info", "", 18, Style.FONT_BOLD, 1.5)
Style.fitText(info, 18, 10)
local resultLine = Style.kitLabel(panel, "Result", "", 20, Style.FONT_TITLE, Style.KIT_SIZES.textStroke)
Style.fitText(resultLine, 20, 11)

local oddsButton, oddsMark = Style.kitButton(panel, WHEEL_WORDS.oddsButton, "sky", "OddsButton")
Style.corner(oddsButton, 25)
oddsMark.Font = Style.FONT_LOUD
local spinButton = Style.kitButton(panel, WORDS.spin, "green", "Spin")
local closeButton = Style.kitButton(panel, WORDS.close, "red", "Close")

-- The spin packs: a caption, the mini wheel, the name and the price with the kit's price sign (Style.priceText).
local packs = {}
for index, offer in ipairs(Offers.list()) do
	local box, button = Wheel.buildPack(panel, offer, Style.priceText("robux", offer.robux), Style)
	box.LayoutOrder = index
	packs[index] = { box = box, button = button, offer = offer }
end
local devNote = Style.kitLabel(panel, "DevNote", Offers.WORDS.devFree, 14, Style.FONT_BOLD, 1.5)
Style.fitText(devNote, 14, 9)

-- The odds window ("i"): the store-kit window with the old odds words, the pity line and one row per prize.
local oddsPanel, oddsInner = Style.kitWindow(gui, "OddsPanel", 56)
oddsPanel.AnchorPoint = Vector2.new(0.5, 0.5)
oddsPanel.Position = UDim2.fromScale(0.5, 0.5)
oddsPanel.Size = UDim2.new(1, -32, 0.86, 0)
oddsPanel.ZIndex = 5
oddsPanel.Visible = false
local oddsLimit = Instance.new("UISizeConstraint")
oddsLimit.MaxSize = Vector2.new(460, 540)
oddsLimit.Parent = oddsPanel
local oddsTitle = Style.kitTitle(oddsPanel, WORDS.oddsHeader, 28)
oddsTitle.Position = UDim2.new(0, 16, 0, 6)
oddsTitle.Size = UDim2.new(1, -84, 0, 44)
oddsTitle.TextXAlignment = Enum.TextXAlignment.Left
local oddsClose = Style.kitClose(oddsPanel)

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

local pityLine = plain(oddsInner, "Pity", "", 15, Style.FONT_BOLD)
pityLine.Size = UDim2.new(1, 0, 0, 36)

local list = Instance.new("ScrollingFrame")
list.Name = "Odds"
list.Position = UDim2.new(0, 0, 0, 40)
list.Size = UDim2.new(1, 0, 1, -80)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.ScrollBarImageColor3 = Style.KIT_COLORS.frame
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = oddsInner
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list
local listPad = Instance.new("UIPadding")
listPad.PaddingTop, listPad.PaddingLeft = UDim.new(0, 4), UDim.new(0, 4)
listPad.Parent = list

local note = plain(oddsInner, "Note", WORDS.oddsNote, 13, Style.FONT_BODY)
note.AnchorPoint = Vector2.new(0, 1)
note.Position = UDim2.new(0, 0, 1, 0)
note.Size = UDim2.new(1, 0, 0, 36)

local playerGui = player:WaitForChild("PlayerGui")
gui.Parent = playerGui

local rows = {}
local view = nil
local spinning = false
local spinToken = 0
local spinAskedAt = -math.huge
local spinTween = nil
local wheelRoot, disc, wheelCount = nil, nil, 0
local rng = Random.new()

local function place(item, box)
	item.Position = UDim2.fromOffset(box.x, box.y)
	item.Size = UDim2.fromOffset(box.w, box.h)
end

-- Every box comes from Wheel.layout for the window's size in pixels, so a phone held either way fits.
local function arrange()
	local size = panel.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then return end
	local boxes = Wheel.layout(size.X, size.Y)
	place(title, boxes.title)
	place(info, boxes.info)
	place(resultLine, boxes.result)
	place(oddsButton, boxes.odds)
	place(spinButton, boxes.spin)
	place(closeButton, boxes.close)
	if wheelRoot then place(wheelRoot, boxes.wheel) end
	for index, pack in ipairs(packs) do
		local box = boxes.packs[index]
		if box then
			place(pack.box, box)
			Wheel.fitPack(pack.box, box.w, box.h)
		end
	end
	place(devNote, boxes.note)
end
panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(arrange)

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

-- One wedge per prize, in the server's prize order (the index a result carries).
local function buildWheel(odds)
	if spinTween then spinTween:Cancel() end
	if wheelRoot then wheelRoot:Destroy() end
	local faces = {}
	for index, row in ipairs(odds) do faces[index] = Wheel.face(PRIZES[row.id]) end
	wheelRoot, disc = Wheel.buildWheel(panel, faces, Style)
	wheelCount = #faces
	arrange()
end

local function setSpinButton()
	Style.setLabel(spinButton, WORDS.spin)
	Style.tint(spinButton, view and view.canSpin and "green" or "off")
end

local function show(next)
	if type(next) ~= "table" then return end
	view = next
	local odds = view.odds or {}
	if #rows ~= #odds then buildRows(odds) end
	if wheelCount ~= #odds then buildWheel(odds) end
	title.Text = WHEEL_WORDS.spinsLeft:format(view.spinsLeft or 0)
	local first = WORDS.price:format(view.price or 0)
	if view.free then
		first = WORDS.free
	elseif (view.extraSpins or 0) > 0 then
		first = WHEEL_WORDS.extra
	end
	info.Text = first .. WHEEL_WORDS.joiner .. WORDS.balance:format(view.ember or 0)
	if view.pityEnabled then
		pityLine.Text = view.pityLeft == 1 and WORDS.pityNext or WORDS.pity:format(view.pityLeft or 0)
		-- The next spin is an extra one (WildboundRoulette.drawExtra rolls the whole table, outside the pity), so the
		-- odds window says so instead of promising the pity prize.
		if (view.extraSpins or 0) > 0 and not view.free then
			pityLine.Text = WHEEL_WORDS.extraNoPity
		end
	else
		pityLine.Text = ""
	end
	devNote.Text = view.unlocked and Offers.WORDS.devFree or Offers.WORDS.comingSoon
	if not spinning then setSpinButton() end
end

-- The server takes one spin per WildboundRouletteService.SPIN_SECONDS (sent in the view as spinSeconds), counted from
-- when the request reaches it; Girar waits that long after the tap (plus a little), so it never offers a spin the server
-- would refuse as busy, even when "Efectos suaves" stops the wheel after 1 s.
local function spinGate()
	local seconds = view and tonumber(view.spinSeconds) or nil
	return (seconds or 3.2) + 0.1
end

local function stopSpin()
	spinning = false
	spinToken += 1
	if spinTween then spinTween:Cancel() end
	spinTween = nil
	for _, row in ipairs(rows) do paintRow(row, false) end
end

local function openPanel()
	if panel.Visible then return end
	panel.Visible = true
	arrange()
end

local function hidePanel()
	stopSpin()
	panel.Visible = false
	oddsPanel.Visible = false
end

-- Turns the wheel several times (one short turn with "Efectos suaves") and stops with the server's prize under the
-- pointer (Wheel.targetRotation), then a small bounce unless "Efectos suaves".
local function playSpin(index, done)
	local token = spinToken
	if not disc or type(index) ~= "number" or index < 1 or index > wheelCount then done(); return end
	local motion = Wheel.motion(Style.reduced(playerGui))
	local from = Wheel.normalize(disc.Rotation)
	disc.Rotation = from
	local target = Wheel.targetRotation(index, wheelCount, motion.turns, rng:NextNumber(-1, 1), from)
	if spinTween then spinTween:Cancel() end
	local tween = TweenService:Create(disc, TweenInfo.new(motion.seconds, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Rotation = target })
	spinTween = tween
	tween.Completed:Connect(function(state)
		if token ~= spinToken or state ~= Enum.PlaybackState.Completed then return end
		spinTween = nil
		local pop = wheelRoot and wheelRoot:FindFirstChild("WbPop")
		if motion.bounce and pop then
			TweenService:Create(pop, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, true),
				{ Scale = 1.05 }):Play()
		end
		local row = rows[index]
		if row then paintRow(row, true) end
		done()
	end)
	tween:Play()
end

spinButton.Activated:Connect(function()
	if spinning or not view then return end
	if os.clock() - spinAskedAt < spinGate() then return end
	spinning = true
	spinAskedAt = os.clock()
	resultLine.Text = ""
	for _, row in ipairs(rows) do paintRow(row, false) end
	Style.setLabel(spinButton, WORDS.spinning)
	Style.tint(spinButton, "off")
	remote:FireServer("spin")
end)

for _, pack in ipairs(packs) do
	pack.button.Activated:Connect(function()
		if spinning or not view then return end
		remote:FireServer("offer", pack.offer.id)
	end)
end

oddsButton.Activated:Connect(function()
	oddsPanel.Visible = not oddsPanel.Visible
end)
oddsClose.Activated:Connect(function()
	oddsPanel.Visible = false
end)
closeButton.Activated:Connect(hidePanel)

remote.OnClientEvent:Connect(function(kind, payload)
	if type(payload) ~= "table" then return end
	if kind == "open" then
		-- The station's prompt again while the wheel turns (or Girar waits for the server): keep the spin; its view would
		-- also show the new Esencia before the wheel stops.
		if spinning then return end
		stopSpin()
		resultLine.Text = ""
		show(payload)
		openPanel()
	elseif kind == "result" then
		openPanel()
		playSpin(payload.index, function()
			resultLine.Text = payload.text or ""
			local rare = payload.rarityKey == "Epica" or payload.rarityKey == "Legendaria"
			resultLine.TextColor3 = rare and Style.COLORS.gold or Style.COLORS.ink
			show(payload.view)
			local token = spinToken
			task.delay(math.max(0, spinGate() - (os.clock() - spinAskedAt)), function()
				if token ~= spinToken then return end
				spinning = false
				setSpinButton()
			end)
		end)
	elseif kind == "granted" then
		resultLine.Text = payload.text or ""
		resultLine.TextColor3 = Style.COLORS.gold
		show(payload.view)
	elseif kind == "refused" then
		stopSpin()
		resultLine.Text = payload.text or ""
		resultLine.TextColor3 = Style.color("red")
		if payload.view then show(payload.view) end
		if view then setSpinButton() end
	end
end)

player.CharacterAdded:Connect(hidePanel)

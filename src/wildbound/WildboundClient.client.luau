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
-- Delivery B: the carried creature's HUD line (B2) and the Spanish words (H3).
local carryModule = ReplicatedStorage:WaitForChild("WildboundCarry", 10)
local textModule = ReplicatedStorage:WaitForChild("WildboundText", 10)
local Carry = carryModule and require(carryModule)
local Text = textModule and require(textModule)
-- B3: the presentation card after a registration.
local refugeModule = ReplicatedStorage:WaitForChild("WildboundRefuge", 10)
local Refuge = refugeModule and require(refugeModule)
-- Next batch NB4: the incubator's Bag row (delivery E).
local incubatorModule = ReplicatedStorage:WaitForChild("WildboundIncubator", 10)
local Incubator = incubatorModule and require(incubatorModule)
-- Egg loop (docs/design/wildbound-egg-loop.md): the objective line says the next action from the snapshot, and the
-- stored egg rows name the rarity (species looks from WildboundSpecies).
local eggLoopModule = ReplicatedStorage:WaitForChild("WildboundEggLoop", 10)
local EggLoop = eggLoopModule and require(eggLoopModule)
local speciesModule = ReplicatedStorage:WaitForChild("WildboundSpecies", 10)
local speciesLooks = speciesModule and require(speciesModule).LOOKS or nil
-- Next batch NB3: every word on this HUD and its panel comes from WildboundText.HUD.
local H = Text.HUD
-- UI colorida: the shared look (palette, outlines, shading, press squash). Without the module every call is a no-op
-- and the plain look stays.
local styleModule = ReplicatedStorage:WaitForChild("WildboundUiStyle", 10)
local Style = styleModule and require(styleModule) or setmetatable({}, { __index = function() return function() end end })

local gui = Instance.new("ScreenGui")
gui.Name = "WildboundUI"
gui.ResetOnSpawn = false
Style.screen(gui)
gui.Parent = playerGui
task.spawn(function()
	local StarterGui = game:GetService("StarterGui")
	for _ = 1, 10 do
		if pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true) end) then break end
		task.wait(0.2)
	end
end)
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
-- UI colorida palette: white ink, gold highlights, slate-navy panels, lime green actions, a dim slate for "off".
local ink = Color3.fromRGB(255, 255, 255)
local amber = Color3.fromRGB(255, 214, 64)
local dark = Color3.fromRGB(40, 50, 70)
local accent = Color3.fromRGB(92, 214, 64)
local accentOff = Color3.fromRGB(84, 92, 112)
local function label(parent, text, size)
	local item = make("TextLabel", {BackgroundTransparency = 1, Text = text, TextColor3 = ink,
		TextSize = size, Font = Enum.Font.Gotham, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left}, parent)
	Style.body(item)
	return item
end
local function button(parent, text, tone)
	local b = make("TextButton", {Text = text, BackgroundColor3 = accent, TextColor3 = ink,
		TextSize = 16, Font = Enum.Font.GothamBold, AutoButtonColor = true}, parent)
	make("UICorner", {CornerRadius = UDim.new(0, 7)}, b)
	local scale = make("UIScale", {Scale = 1}, b)
	b.MouseEnter:Connect(function() TweenService:Create(scale, TweenInfo.new(0.12), {Scale = 1.02}):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(scale, TweenInfo.new(0.12), {Scale = 1}):Play() end)
	Style.button(b, tone or "green")
	return b
end
local function place(item, rect)
	item.Position, item.Size = UDim2.fromOffset(rect.x, rect.y), UDim2.fromOffset(rect.w, rect.h)
end

local hud = make("Frame", {BackgroundColor3 = dark, BackgroundTransparency = 0.15,
	Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -168, 0, 82), Visible = false}, gui)
make("UISizeConstraint", {MaxSize = Vector2.new(430, 82)}, hud)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, hud)
Style.panel(hud, 0.12)
local objective = label(hud, H.objective .. "\n" .. H.sessionOnly, 15)
Style.body(objective, true)
objective.Position = UDim2.fromOffset(10, 5)
objective.Size = UDim2.new(1, -20, 0, 42)
local status = label(hud, H.connecting, 14)
status.Position = UDim2.fromOffset(10, 49)
status.Size = UDim2.new(1, -20, 0, 28)
local open = button(gui, H.inventoryKey, "orange")
open.AnchorPoint = Vector2.new(1, 0)
open.Position = UDim2.new(1, -12, 0, 12)
open.Size = UDim2.fromOffset(132, 44)
open.Visible = false

local panel = make("Frame", {Name = "InventoryPanel", Visible = false, BackgroundColor3 = dark,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromScale(0.88, 0.75)}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 10)}, panel)
-- UI colorida: an outlined slate panel under a magenta header strip (moved with the header in applyLayout).
Style.panel(panel)
Style.header(panel, 52, "magenta")
-- Header: two tabs and Close, each at least 44 pixels (the rectangles come from the camp view module).
local bagTab = button(panel, H.bag, "sky")
bagTab.Name = "BagTab"
local eggsTab = button(panel, H.eggsTab or "Huevos", "sky")
eggsTab.Name = "EggsTab"
local campTab = button(panel, H.camp, "sky")
campTab.Name = "CampTab"
local close = button(panel, H.close, "red")
close.Name = "CloseButton"
-- W9: opens the Settings screen (WildboundStartUI) from the inventory header.
local menuTab = button(panel, H.menu, "purple")
menuTab.Name = "MenuTab"
for _, tab in ipairs({ bagTab, eggsTab, campTab }) do
	tab.TextSize = 16
	-- The outline the style gave the tab (or a new one without the style module); paintTabs turns it gold when chosen.
	if not tab:FindFirstChildOfClass("UIStroke") then
		make("UIStroke", {Thickness = 0, Color = amber, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, tab)
	end
end
local warning = label(panel, H.sessionNote, 14)
warning.Name = "TabNote"
warning.TextColor3 = Color3.fromRGB(214, 224, 245)
local scroll = make("ScrollingFrame", {Position = UDim2.fromOffset(12, 96),
	Size = UDim2.new(1, -24, 1, -108), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y}, panel)
local listLayout = make("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)
-- Room for the rows' outlines inside the scrolling clip.
make("UIPadding", {PaddingLeft = UDim.new(0, 3), PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3)}, scroll)
campTab.Visible = campReady
menuTab.Visible = campReady

-- Status line: a server notice shows for a few seconds and then goes; a local error stays until replaced.
local compact, statusBudget = false, 40
local stickyStatus = H.connecting
local noticeState = View and View.newNotice()
local hudWidth = 430
local lastSnapshot, compassText = nil, nil
local tab, busy, atCamp = "bag", false, nil
local rowWidth, rowText = 330, 15
-- A phone held sideways: compact camp rows and no tab note, so the list shows three rows or more (W9).
local sideways = false
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
-- B2: while a wild creature is carried, its name and state take the line: it is the thing most at risk.
local carryMood = "calm"
local function ownCapsuleMood()
	local character = Players.LocalPlayer.Character
	local capsule = character and character:FindFirstChild("WildboundCarryCapsule")
	local mood = capsule and capsule:GetAttribute("Mood")
	return type(mood) == "string" and mood or "calm"
end
local function updateObjective()
	local budget = Layout and Layout.charBudget(hudWidth - (compact and 16 or 20), compact and 13 or 15, 1) or 40
	local carryLine = Carry and Text and lastSnapshot and Carry.hudLine(lastSnapshot.carrying, carryMood, Text, budget) or nil
	local loss = campReady and lastSnapshot and Camp.lossLine(lastSnapshot, budget) or nil
	local risky = (loss ~= nil and loss.atRisk) or (carryLine ~= nil and carryLine.tone == "risk")
	local second = carryLine and carryLine.text or risky and loss.text or compassText
	-- Egg loop: the first line always names the next action ("Roba un huevo...", "Llévalo a tu base...", "Ve a tu
	-- base: tu incubadora está libre.", "Busca otro huevo. El tuyo nace en 1:30.").
	local slots = (lastSnapshot and lastSnapshot.incubatorSlots) or (Incubator and Incubator.live and Incubator.live.SLOTS) or 1
	local loopLine, loopId = nil, nil
	if EggLoop and lastSnapshot then
		loopLine, loopId = EggLoop.objectiveText(EggLoop.facts(lastSnapshot, slots), workspace:GetServerTimeNow(), Text)
	end
	local first = loopLine or H.objective
	if compact then
		-- One line on phones: a carried creature or a risk warning first, then the next action (the explorer compass
		-- only while the next action is "steal one").
		local pick = (carryLine or risky) and second or (loopId == "steal" and compassText) or first
		objective.Text = View and View.fit(pick, budget) or pick
	else
		-- NS1: "Progreso guardado." while the server saves this player's progress, else "Solo esta sesión."
		local saveLine = lastSnapshot and lastSnapshot.sessionOnly == false and H.saved or H.sessionOnly
		objective.Text = first .. "\n" .. (second and (View and View.fit(second, budget) or second) or saveLine)
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
	open.Text = UserInputService.KeyboardEnabled and H.inventoryKey or H.inventory
	open.TextSize = compact and 14 or 16
	open.Visible = false
	hud.Visible = false
	rowText = compact and 13 or 15
	local noteHeight = compact and 20 or 24
	if campReady then
		-- The panel sits below the awareness chip and inside the screen; every header button is 44 or more.
		local rect = Camp.panel(size.X, size.Y, rects.chip)
		panel.AnchorPoint = Vector2.new(0, 0)
		place(panel, rect)
		local header = Camp.headerWithEggs and Camp.headerWithEggs(rect.w) or Camp.header(rect.w)
		place(bagTab, header.bag); place(campTab, header.camp); place(close, header.close); place(menuTab, header.menu)
		if header.eggs then eggsTab.Visible = true; place(eggsTab, header.eggs) else eggsTab.Visible = false end
		Style.header(panel, header.bottom + 4, "magenta")
		-- A narrow panel shrinks the header buttons, so their words shrink with them.
		for _, item in ipairs({ bagTab, eggsTab, campTab, menuTab, close }) do item.TextSize = header.tabWidth < 80 and 13 or 16 end
		sideways = Camp.sideways(size.X, size.Y)
		local area = Camp.listArea(rect, sideways)
		warning.Visible = area.showNote
		warning.Position, warning.Size = UDim2.fromOffset(12, header.bottom + 2), UDim2.new(1, -24, 0, noteHeight)
		local top = area.top
		listLayout.Padding = UDim.new(0, sideways and Camp.COMPACT_GAP or 6)
		scroll.Position, scroll.Size = UDim2.fromOffset(12, top), UDim2.new(1, -24, 1, -(top + (area.showNote and 6 or 4)))
		rowWidth = rect.w - 24 - scroll.ScrollBarThickness
	else
		panel.Size = UDim2.fromScale(0.88, 0.75)
		bagTab.Position, bagTab.Size = UDim2.fromOffset(8, 4), UDim2.fromOffset(84, 44)
		close.Position, close.Size = UDim2.new(1, -86, 0, 4), UDim2.fromOffset(78, 44)
		Style.header(panel, 52, "magenta")
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
	ArmTotem = true, DisarmTotem = true, CraftGear = true, PlaceLuck = true, EquipGlove = true }
local function request(action, uid)
	if not actionRemote then
		showSticky(H.serverDown)
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
		Style.title(title, amber)
		title.Size = UDim2.new(1, -8, 0, 24)
		title.LayoutOrder = order
		return
	end
	local hasButton = spec.label ~= nil
	local height = campReady and Camp.rowHeight(spec, rowWidth, rowText, sideways) or 56
	local item = make("Frame", {BackgroundColor3 = Color3.fromRGB(54, 66, 94), LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, height)}, scroll)
	make("UICorner", {CornerRadius = UDim.new(0, 6)}, item)
	-- UI colorida: each row is an outlined tile (2 px, so the list keeps its row height).
	Style.card(item, "row")
	Style.outline(item, 2)
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
			b.BackgroundColor3, b.TextColor3 = accentOff, Color3.fromRGB(200, 206, 220)
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
	addRow({ text = H.pendingBag:format(#pending, snapshot.capacity or 3, seals, snapshot.sealArmed and H.sealArmed or "") })
	if campReady then
		for _, spec in ipairs(Camp.quickRows(snapshot, { busy = busy })) do addRow(spec) end
	end
	-- B1: the carried creature has its own slot, apart from the bag, and its own ward button.
	local carried = snapshot.carrying
	if carried and Text then
		local words = Text.CARRY
		addRow({ text = ("%s: %s · %s. %s"):format(words.label, carried.species, carried.protected and words.warded
			or words.unwarded, words.registerHint), label = not carried.protected and H.protect or nil,
			action = "Protect", argument = carried.uid })
	end
	addRow({ text = H.pendingRule })
	if #pending == 0 then addRow({ text = H.noPending }) end
	for index, item in ipairs(pending) do
		local name = item.kind == "Nightbloom" and H.bundle:format(item.quantity or 1)
			or H.item:format(H.kinds[item.kind] or tostring(item.kind), tostring(item.species))
		addRow({ text = ("#%d "):format(index) .. name .. (item.protected and H.protected or H.unprotected),
			label = not item.protected and H.protect or nil, action = "Protect", argument = item.uid })
	end
	-- A first strike drops one item near you for 30 s (M4.6). Only you can pick it up.
	for _, item in ipairs(snapshot.dropped or {}) do
		addRow({ text = H.dropped:format(H.item:format(H.kinds[item.kind] or tostring(item.kind), tostring(item.species))) })
	end
	-- Egg loop: the header counts the stored eggs and says they go into the cradle on their own; each row names the
	-- rarity. "Incubar" stays as the manual way in (the server checks the cradle's range).
	addRow({ text = EggLoop and Text.LOOP and Text.LOOP.eggsHeader:format(#eggs) or H.eggsHeader })
	if #eggs == 0 then addRow({ text = H.noEggs }) end
	for _, egg in ipairs(eggs) do
		local line = EggLoop and EggLoop.eggRow(egg, speciesLooks, Text) or H.egg:format(egg.species)
		addRow({ text = line, label = H.hatch, action = "Hatch", argument = egg.uid })
	end
	-- NB4: what incubates, from the server snapshot and the server clock; the client never sends a time.
	for _, entry in ipairs(snapshot.incubating or {}) do
		local line = Incubator and Incubator.row(entry, workspace:GetServerTimeNow(), Text)
		if line then addRow({ text = line }) end
	end
	addRow({ text = H.registeredHeader })
	if #registered == 0 then addRow({ text = H.noRegistered }) end
	for _, creature in ipairs(registered) do
		local equipped = snapshot.equippedUid == creature.uid
		local creatureName = Text.CARD and Text.CARD.species and Text.CARD.species[creature.species] or creature.species
		-- NS4: the companion's row stores it; every other row equips (swaps) its creature.
		addRow({ text = creatureName .. (equipped and H.equipped or ""), label = equipped and H.store or H.equip,
			action = equipped and "Unequip" or "Equip", argument = creature.uid })
	end
end

local function eggsRows(snapshot)
	local eggs = snapshot.bankedEggs or {}
	local inc = snapshot.incubating or {}
	local slots = snapshot.incubatorSlots or (Incubator and Incubator.live and Incubator.live.SLOTS) or 1
	local speedScale = snapshot.hatchSpeedScale or 1
	addRow({ header = true, text = (H.eggsInventoryHeader or "Cofre de huevos (%d) · Incubadora: %d/%d"):format(#eggs, #inc, slots) })
	local pendingEggs = 0
	for _, entry in ipairs(snapshot.pending or {}) do
		if entry.kind == "Egg" then pendingEggs += 1 end
	end
	if pendingEggs > 0 then
		addRow({
			text = (H.depositAllRow or "Llevas %d huevo(s) en la bolsa. Guárdalos en el cofre."):format(pendingEggs),
			label = H.depositAll or "Depositar",
			action = "DepositEggs",
			argument = "all",
			enabled = not busy,
		})
	end
	local freeSlots = math.max(0, slots - #inc)
	if #eggs > 0 and freeSlots > 0 then
		addRow({
			text = (H.hatchAllRow or "Ranuras libres: %d. Llena las incubadoras."):format(freeSlots),
			label = H.hatchAll or "Incubar todo",
			action = "HatchAll",
			argument = "all",
			enabled = not busy,
		})
	end
	local seenSpecies, dupCount = {}, 0
	for _, egg in ipairs(eggs) do
		if seenSpecies[egg.species] then dupCount += 1 else seenSpecies[egg.species] = true end
	end
	if dupCount > 0 then
		addRow({
			text = (H.sellDuplicatesRow or "Huevos repetidos: %d. Canjéalos por Esencia."):format(dupCount),
			label = H.sellDuplicates or "Canjear rep.",
			action = "SellDuplicateEggs",
			argument = "all",
			enabled = not busy,
		})
	end
	if #inc > 0 then
		for _, entry in ipairs(inc) do
			local line = Incubator and Incubator.row(entry, workspace:GetServerTimeNow(), Text)
			if line then addRow({ text = line }) end
		end
	end
	if #eggs == 0 then
		addRow({ text = H.noEggs })
	else
		for _, egg in ipairs(eggs) do
			local rarity = EggLoop and EggLoop.rarityOf(egg, speciesLooks) or "Comun"
			local rarityLabel = Text.RARITY and Text.RARITY[rarity] or rarity
			local speciesName = Text.CARD and Text.CARD.species and Text.CARD.species[egg.species] or egg.species
			local hatchSec = Incubator and Incubator.hatchSeconds and Incubator.hatchSeconds(rarity, Incubator.live.HATCH_SECONDS, speedScale) or 15
			local line = H.eggRowTime and H.eggRowTime:format(speciesName, rarityLabel, hatchSec)
				or (EggLoop and EggLoop.eggRow(egg, speciesLooks, Text)) or H.egg:format(speciesName)
			local canHatch = #inc < slots
			addRow({ text = line, label = H.hatch, action = "Hatch", argument = egg.uid, enabled = canHatch })
		end
	end
end

local function campRows(snapshot)
	local previous
	for _, spec in ipairs(Camp.campRows(Config, Economy, snapshot, { atCamp = atCamp, busy = busy, compact = sideways })) do
		if spec.section ~= previous then
			previous = spec.section
			if Camp.showSectionHeaders(sideways) then
				addRow({ header = true, text = H.sections[spec.section] or H.sections.Bond })
			end
		end
		addRow(spec)
	end
end

local function paintTabs()
	for name, item in pairs({ bag = bagTab, eggs = eggsTab, camp = campTab }) do
		local selected = tab == name
		item.BackgroundColor3 = selected and Color3.fromRGB(72, 200, 250) or accentOff
		item.Font = Enum.Font.FredokaOne
		-- The chosen tab also wears a gold outline (the others a dark one), so it is not told apart by colour alone.
		local stroke = item:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = selected and amber or Color3.fromRGB(16, 18, 34)
			stroke.Thickness = selected and 3 or 2
		end
		local word = name == "bag" and H.bag or name == "eggs" and (H.eggsTab or "Huevos") or H.camp
		item.Text = selected and ("[" .. word .. "]") or word
	end
end
-- The tutorial reads which tab is open ("bag", "camp" or "closed").
local function publishTab()
	gui:SetAttribute("PanelTab", panel.Visible and tab or "closed")
end
rebuild = function()
	publishTab()
	paintTabs()
	if campReady then warning.Text = Camp.note(tab, atCamp, compact) end
	if not lastSnapshot then return end
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
	end
	order = 0
	if tab == "camp" and campReady then campRows(lastSnapshot)
	elseif tab == "eggs" then eggsRows(lastSnapshot)
	else bagRows(lastSnapshot) end
end
local function render(snapshot)
	lastSnapshot = snapshot
	busy = false
	rebuild()
	updateObjective()
	local hub = workspace:FindFirstChild("WildboundHub")
	local bases = hub and hub:FindFirstChild("Bases")
	if bases then
		for _, base in ipairs(bases:GetChildren()) do
			if base:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
				local lid = base:FindFirstChild("ChestLid")
				local bb = lid and lid:FindFirstChild("ChestBillboard")
				local lbl = bb and bb:FindFirstChild("Label")
				if lbl and lbl:IsA("TextLabel") then
					lbl.Text = ("Cofre de huevos · %d guardados"):format(#(snapshot.bankedEggs or {}))
				end
			end
		end
	end
end
applyLayout()
listen(gui:GetPropertyChangedSignal("AbsoluteSize"), applyLayout)
listen(UserInputService:GetPropertyChangedSignal("KeyboardEnabled"), applyLayout)

local function toggle(wanted)
	-- Opening the inventory is blocked during a capture session (M3.4). Closing it is always allowed.
	if not panel.Visible and Players.LocalPlayer:GetAttribute("WildboundCapturing") == true then
		showNotice(H.calmFirst)
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
	elseif wanted == "bag" or wanted == "camp" or wanted == "eggs" then
		panel.Visible = false
		toggle(wanted)
	end
end)
listen(open.Activated, function() toggle(nil) end)
listen(close.Activated, function() panel.Visible = false end)
listen(panel:GetPropertyChangedSignal("Visible"), publishTab)
listen(menuTab.Activated, function()
	panel.Visible = false
	local startGui = playerGui:FindFirstChild("WildboundStartUI")
	if startGui then startGui:SetAttribute("Screen", "settings") end
end)
listen(bagTab.Activated, function() tab = "bag"; rebuild() end)
listen(eggsTab.Activated, function() tab = "eggs"; rebuild() end)
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
			-- HB-T5: the own base's glove bench opens this screen too; the server allows only glove crafting there.
			if root and not now then
				for _, bench in ipairs(game:GetService("CollectionService"):GetTagged("WildboundGloveStation")) do
					local base = bench:FindFirstAncestorWhichIsA("Model")
					if base and base:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
						and (root.Position - bench.Position).Magnitude <= (bench:GetAttribute("Range") or 8) + 2 then
						now = true
					end
				end
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
			local mood = ownCapsuleMood()
			if text ~= compassText or mood ~= carryMood then
				compassText, carryMood = text, mood
				updateObjective()
			elseif lastSnapshot and #(lastSnapshot.incubating or {}) > 0 then
				-- Egg loop: the objective line's hatch countdown ("El tuyo nace en 1:30").
				updateObjective()
			end
			if changed and panel.Visible and tab == "camp" then rebuild() end
			-- NB4: the incubating egg's countdown refreshes while the Bag or Eggs tab is open.
			if panel.Visible and (tab == "bag" or tab == "eggs") and lastSnapshot and #(lastSnapshot.incubating or {}) > 0 then rebuild() end
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
		Text = View and View.lossSummary(summary, Text and Text.DEFEAT) or (fallback .. "\n"
			.. Text.DEFEAT.close)}, summaryGui)
	make("UITextSizeConstraint", {MinTextSize = 14, MaxTextSize = 30}, sheet)
	Style.title(sheet)
	Style.shade(sheet, 0.7)
	make("UIPadding", {PaddingLeft = UDim.new(0.08, 0), PaddingRight = UDim.new(0.08, 0),
		PaddingTop = UDim.new(0.12, 0), PaddingBottom = UDim.new(0.12, 0)}, sheet)
	sheet.Activated:Connect(closeLossSummary)
end
listen(gui.Destroying, closeLossSummary)

-- B3: the presentation card. A short pop-in panel with the creature, its collection entry and its Ember, an Equip
-- button and a Close button, both 44 pixels high. It closes by itself after a while.
local cardGui
local function closeCard()
	if cardGui then cardGui:Destroy(); cardGui = nil end
end
local function showCard(view)
	closeCard()
	-- A plain registration card stays suppressed (WildboundBaseGuideClient shows a non-blocking top hatch banner).
	-- User decision 2026-11-14 ("Que se muestre"): the refuge card that carries the first-steal bonus or the next
	-- island's tease (K2) shows again.
	if not view or not (view.bonus or view.next) then return end
	cardGui = make("ScreenGui", {Name = "WildboundCard", ResetOnSpawn = false, DisplayOrder = 40, IgnoreGuiInset = true}, playerGui)
	local size = gui.AbsoluteSize
	local width = math.min(380, math.max(260, size.X - 32))
	local sheet = make("Frame", {Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(width, 288), BackgroundColor3 = dark, BackgroundTransparency = 0.05}, cardGui)
	make("UICorner", {CornerRadius = UDim.new(0, 12)}, sheet)
	make("UIStroke", {Thickness = 2, Color = amber}, sheet)
	local scale = make("UIScale", {Scale = 0.6}, sheet)
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Scale = 1}):Play()
	local title = label(sheet, view.title, 22)
	title.Font, title.TextColor3 = Enum.Font.GothamBold, amber
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Position, title.Size = UDim2.fromOffset(12, 10), UDim2.new(1, -24, 0, 28)
	local name = label(sheet, view.name, 20)
	name.Font, name.TextXAlignment = Enum.Font.GothamBold, Enum.TextXAlignment.Center
	name.Position, name.Size = UDim2.fromOffset(12, 40), UDim2.new(1, -24, 0, 24)
	local lines = {}
	if view.blurb then table.insert(lines, view.blurb) end
	if view.entry then table.insert(lines, view.entry) end
	if view.ember then table.insert(lines, view.ember) end
	-- Expedition islands (K2): the one-off first-steal bonus and the next island's tease.
	if view.bonus then table.insert(lines, view.bonus) end
	if view.next then table.insert(lines, view.next) end
	local body = label(sheet, table.concat(lines, "\n"), 15)
	body.TextXAlignment = Enum.TextXAlignment.Center
	body.TextWrapped = true
	body.Position, body.Size = UDim2.fromOffset(16, 68), UDim2.new(1, -32, 0, 152)
	local equip = button(sheet, view.equip)
	equip.Name = "CardEquip"
	equip.Position, equip.Size = UDim2.new(0.5, -128, 1, -56), UDim2.fromOffset(120, 44)
	local closer = button(sheet, view.close)
	closer.Name = "CardClose"
	closer.BackgroundColor3 = accentOff
	closer.Position, closer.Size = UDim2.new(0.5, 8, 1, -56), UDim2.fromOffset(120, 44)
	local uid = view.uid
	equip.Activated:Connect(function() request("Equip", uid); closeCard() end)
	closer.Activated:Connect(closeCard)
	local shown = cardGui
	task.delay(12, function() if cardGui == shown then closeCard() end end)
end
listen(gui.Destroying, closeCard)

-- Random world (RW5): the biome event banner, top centre under the threat chip, sized for phones; a distant call
-- (the catalog's existing "call" id) when the event starts.
local catalogModule = ReplicatedStorage:FindFirstChild("WildboundAudioCatalog")
local Catalog = catalogModule and catalogModule:IsA("ModuleScript") and require(catalogModule)
local eventBanner = make("TextLabel", { Name = "EventBanner", AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 150), Size = UDim2.new(0.92, 0, 0, 40), BackgroundColor3 = dark,
	BackgroundTransparency = 0.15, TextColor3 = amber, Font = Enum.Font.GothamBold, TextScaled = true, Visible = false,
	Text = "" }, gui)
make("UISizeConstraint", { MaxSize = Vector2.new(520, 40) }, eventBanner)
make("UITextSizeConstraint", { MaxTextSize = 22 }, eventBanner)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, eventBanner)
-- UI colorida: the top-centre banner is a bold outlined purple pill with gold stroked words.
Style.pill(eventBanner, 0)
Style.shade(eventBanner, 0.75)
Style.title(eventBanner, amber)
eventBanner.BackgroundColor3 = Color3.fromRGB(150, 86, 232)
local eventState = nil
-- Under the threat chip (the world client's AwarenessChip), as wide as it, so the banner never covers the left panels
-- or the Mochila button on any screen; the fallback above is used until the chip exists.
local function anchorUnderChip(frame, gap, height)
	local worldUI = playerGui:FindFirstChild("WildboundWorldUI")
	local chip = worldUI and worldUI:FindFirstChild("AwarenessChip")
	if chip and chip:IsA("GuiObject") and chip.Visible then
		frame.Position = UDim2.fromOffset(chip.AbsolutePosition.X + chip.AbsoluteSize.X / 2,
			chip.AbsolutePosition.Y + chip.AbsoluteSize.Y + gap)
		frame.Size = UDim2.fromOffset(math.max(chip.AbsoluteSize.X, 240), height)
	end
end
local function speciesWord(name)
	return Text and Text.CARD and Text.CARD.species and Text.CARD.species[name] or name
end
local function playCall()
	local entry = Catalog and Catalog.SOUNDS and Catalog.SOUNDS.call
	if not entry then return end
	local sound = Instance.new("Sound")
	sound.Name, sound.SoundId = "BiomeEventCall", "rbxassetid://" .. entry.ids[1]
	sound.Volume, sound.PlaybackSpeed = 0.6, 0.6
	sound.Parent = game:GetService("SoundService")
	sound:Play()
	task.delay(12, function() sound:Destroy() end)
end
local function refreshBanner()
	eventBanner.Visible = false
end

-- Random world (RW7): the wave board, top 3 of this wave's banked Esencia and the wave's countdown, under the
-- Mochila button (above it when the button sits low on a phone). Lines come from View.waveBoard, which fits them to
-- the board budget (COMPACT_BOARD_CHARS on a phone).
local waveBoard = make("Frame", { Name = "WaveBoard", BackgroundColor3 = dark, BackgroundTransparency = 0.2,
	BorderSizePixel = 0, Size = UDim2.fromOffset(190, 92), Visible = false }, gui)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, waveBoard)
Style.pill(waveBoard, 0.1)
local boardLabels = {}
for index = 1, 4 do
	boardLabels[index] = make("TextLabel", { BackgroundTransparency = 1, Font = index == 1 and Enum.Font.GothamBold
		or Enum.Font.Gotham, TextColor3 = index == 1 and amber or ink, TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true, Position = UDim2.new(0, 8, 0, 4 + (index - 1) * 21), Size = UDim2.new(1, -16, 0, 19),
		Text = "" }, waveBoard)
	make("UITextSizeConstraint", { MaxTextSize = 16 }, boardLabels[index])
	if index == 1 then Style.title(boardLabels[index], amber) else Style.body(boardLabels[index], true) end
end
local boardState = nil
local function placeBoard()
	local width, height = compact and 150 or 190, 92
	local x, y = gui.AbsoluteSize.X - width - 12, 62
	if open and open.Parent then
		local at, size = open.AbsolutePosition, open.AbsoluteSize
		x = at.X + size.X - width
		y = at.Y > gui.AbsoluteSize.Y / 2 and at.Y - height - 6 or at.Y + size.Y + 6
	end
	waveBoard.Position, waveBoard.Size = UDim2.fromOffset(math.max(8, x), math.max(8, y)), UDim2.fromOffset(width, height)
end
local function refreshBoard()
	waveBoard.Visible = false
end
task.spawn(function()
	while gui.Parent do
		refreshBoard()
		task.wait(0.5)
	end
end)
task.spawn(function()
	while gui.Parent do
		refreshBanner()
		task.wait(0.5)
	end
end)

-- Random world (RW3): what the WorldEvent broadcast changes on this HUD. A new wave after the first says so.
local lastWaveSeen = nil
local function onWorldEvent(message)
	if message.kind == "wave" and Text and Text.WAVE then
		if lastWaveSeen ~= nil and message.wave > lastWaveSeen then
			-- RW6: a changed biome variant says so; otherwise the wave notice.
			if message.variantChanged and message.variant and Text.VARIANT then
				showNotice(Text.VARIANT.changed:format(Text.VARIANT[message.variant] or message.variant))
			else
				showNotice(Text.WAVE.started:format(message.wave))
			end
		end
		lastWaveSeen = message.wave
		boardState = { wave = message.wave, endsAt = message.endsAt, board = message.board }
		refreshBoard()
	elseif message.kind == "board" then
		if boardState then boardState.board = message.board end
		refreshBoard()
	elseif message.kind == "event" and Text and Text.EVENT then
		local now = workspace:GetServerTimeNow()
		if message.phase == "start" and message.endsAt then
			eventState = { species = message.species, endsAt = message.endsAt }
			showNotice(Text.EVENT.start:format(speciesWord(message.species)))
			playCall()
		elseif message.phase == "claimed" then
			eventState = { line = Text.EVENT.claimed:format(message.by or "?"), lineUntil = now + 6 }
		else
			eventState = { line = Text.EVENT.ended, lineUntil = now + 5 }
		end
		refreshBanner()
	end
end

task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild("WildboundNetwork", 10)
	local action = folder and folder:WaitForChild("Action", 10)
	local state = folder and folder:WaitForChild("State", 10)
	if not gui.Parent then return end
	if not (action and action:IsA("RemoteEvent") and state and state:IsA("RemoteEvent")) then
		showSticky(H.serverDown)
		return
	end
	actionRemote = action
	listen(state.OnClientEvent, function(payload)
		if type(payload) ~= "table" then return end
		if type(payload.snapshot) == "table" then
			receivedSnapshot = true
			if stickyStatus == H.connecting then showSticky("") end
			render(payload.snapshot)
		end
		if type(payload.notice) == "string" and payload.notice ~= "" then showNotice(payload.notice) end
		if payload.action == "Defeat" and type(payload.lossSummary) == "table" then
			showLossSummary(payload.lossSummary, type(payload.notice) == "string" and payload.notice or "Defeated.")
		end
		-- B3: a registration's card; B4: the upgrade board opens the camp screen.
		if type(payload.card) == "table" and Refuge and Text then showCard(Refuge.card(payload.card, Text)) end
		if payload.action == "OpenBoard" and payload.ok == true then
			panel.Visible = false
			toggle("camp")
		elseif payload.action == "OpenChest" and payload.ok == true then
			panel.Visible = false
			toggle("eggs")
			local hub = workspace:FindFirstChild("WildboundHub")
			local bases = hub and hub:FindFirstChild("Bases")
			if bases then
				for _, base in ipairs(bases:GetChildren()) do
					if base:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
						local lid = base:FindFirstChild("ChestLid")
						if lid and lid:IsA("BasePart") and not lid:GetAttribute("WildboundAnimating") then
							lid:SetAttribute("WildboundAnimating", true)
							local restCF = lid.CFrame
							local openTween = TweenService:Create(lid, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
								{ CFrame = restCF * CFrame.new(0, 0.35, 0.35) * CFrame.Angles(math.rad(-35), 0, 0) })
							openTween:Play()
							task.delay(0.45, function()
								if lid.Parent then
									local closeTween = TweenService:Create(lid, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
										{ CFrame = restCF })
									closeTween.Completed:Once(function() lid:SetAttribute("WildboundAnimating", nil) end)
									closeTween:Play()
								end
							end)
						end
					end
				end
			end
		end
	end)
	-- Random world (RW3): the WorldEvent broadcast (the wave, its board, the biome events), read only through
	-- WaveClock.read; this client never sends on it.
	task.spawn(function()
		local remote = folder:WaitForChild("WorldEvent", 10)
		local waveModule = ReplicatedStorage:FindFirstChild("WildboundWaveClock")
		local WaveClock = waveModule and waveModule:IsA("ModuleScript") and require(waveModule)
		if not (gui.Parent and remote and remote:IsA("RemoteEvent") and WaveClock) then return end
		listen(remote.OnClientEvent, function(payload)
			local message = WaveClock.read(payload)
			if message then onWorldEvent(message) end
		end)
		-- CA4 (pack 05_SISTEMAS/01): the countdown before each egg refresh, at WaveClock.ALERTS seconds (10, 5, 3, 2, 1),
		-- once each per wave, from the wave's endsAt (a late joiner gets it with the wave in progress).
		local warned = {}
		while gui.Parent do
			local wave = boardState
			if wave and type(wave.endsAt) == "number" and Text and Text.WAVE and Text.WAVE.warning then
				local remaining = wave.endsAt - workspace:GetServerTimeNow()
				for _, second in ipairs(WaveClock.ALERTS or {}) do
					local key = tostring(wave.wave) .. ":" .. second
					if remaining <= second and remaining > second - 1 and not warned[key] then
						warned[key] = true
						showNotice(Text.WAVE.warning:format(second))
					end
				end
			end
			task.wait(0.2)
		end
	end)
	request("RequestSnapshot")
	task.wait(3)
	if gui.Parent and not receivedSnapshot then request("RequestSnapshot") end
	task.wait(3)
	if gui.Parent and not receivedSnapshot then showSticky(H.noResponse) end
end)
-- NS7: the worn glove's "Robo rápido" shortens this player's own egg prompts' hold. The server sets the base hold
-- (WildboundStealHold) and the bonus (WildboundGloveSteal); Gear keeps the floor. Only this client's copy changes.
do
	local ProximityPromptService = game:GetService("ProximityPromptService")
	local gearModule = ReplicatedStorage:WaitForChild("WildboundGear", 10)
	local Gear = gearModule and require(gearModule) or nil
	if Gear then
		ProximityPromptService.PromptShown:Connect(function(shown)
			local base = shown:GetAttribute("WildboundStealHold")
			if type(base) ~= "number" then return end
			local pct = Players.LocalPlayer:GetAttribute("WildboundGloveSteal")
			local glove = { stats = { steal = type(pct) == "number" and pct or 0 } }
			shown.HoldDuration = Gear.stealHold(base, glove, Gear.CONSTANTS.STEAL_FLOOR)
		end)
	end
end
-- Nest Heist hub (HB-T3): each client shows only its own base's station prompts. The server marks them
-- (WildboundHubStation) and still checks the owner and the range on every trigger; this only hides the prompts of
-- another player's (or a free) base, so a neighbour's station never takes this player's key. Once a second.
do
	local CollectionService = game:GetService("CollectionService")
	local function ownerOf(prompt)
		local model = prompt:FindFirstAncestorWhichIsA("Model")
		while model and not CollectionService:HasTag(model, "WildboundBaseSlot") do
			model = model:FindFirstAncestorWhichIsA("Model")
		end
		return model and model:GetAttribute("OwnerUserId") or 0
	end
	task.spawn(function()
		while gui.Parent do
			local hub = workspace:FindFirstChild("WildboundHub")
			for _, item in ipairs(hub and hub:GetDescendants() or {}) do
				if item:IsA("ProximityPrompt") and item:GetAttribute("WildboundHubStation") ~= nil then
					local mine = ownerOf(item) == Players.LocalPlayer.UserId
					if item.Enabled ~= mine then item.Enabled = mine end
				end
			end
			task.wait(1)
		end
	end)
end
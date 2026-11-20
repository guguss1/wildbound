-- Hub expansion T8 (docs/design/wildbound-hub-expansion.md section 7) and the drop-off guide (user, 2026-11-11: the
-- player could not find where to leave the egg). While the local character carries an egg (the server's
-- "WildboundEggCarried" backpack on it), the own base (the WildboundBaseSlot whose OwnerUserId is this player) gets a
-- light column, a Highlight on its Pad and a "Deja el huevo aquí" billboard, and the HUD says how far it is with an
-- arrow toward it. Walking into the base banks the egg on the server, which then sets the "WildboundSafeBanner"
-- attribute; this script shows the big "¡Estás a salvo!" banner for 2.5 s. Everything here is local and visual: the
-- client sends nothing.
-- Egg loop (docs/design/wildbound-egg-loop.md, second half of this file): the reward toast with sparkles and bells
-- (attribute "WildboundEggReward"), the sign over the own base's cradle (timer, "Libre...", the row of stored eggs)
-- and the "¡Tu huevo eclosionó!" banner with the harp when an egg hatches. Words from WildboundEggLoop and Text.LOOP,
-- sounds from WildboundAudioCatalog.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Text = require(ReplicatedStorage:WaitForChild("WildboundText"))
local player = Players.LocalPlayer

local BANNER_SECONDS = 2.5 -- WildboundBaseZone.CONSTANTS.BANNER_SECONDS (the design's SAFE_BANNER_SECONDS)
local BEACON_COLOR = Color3.fromRGB(70, 150, 255) -- the blue of the eggs (Species.NEST_GLOW.egg)

local gui = Instance.new("ScreenGui")
gui.Name = "WildboundBaseGuide"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

-- The HUD hint: a pill under the top-centre chips (Play check: at y 64 it covered the hunt chip) with an arrow that
-- turns toward the base.
local hint = Instance.new("Frame")
hint.Name = "Hint"
hint.AnchorPoint = Vector2.new(0.5, 0)
hint.Position = UDim2.new(0.5, 0, 0, 48)
-- UR-G: at most 380 wide, and 12 px inside each edge on a narrow phone, so the pill and its border are never cut off.
hint.Size = UDim2.new(1, -24, 0, 40)
Instance.new("UISizeConstraint", hint).MaxSize = Vector2.new(380, 40)
hint.BackgroundColor3 = Color3.fromRGB(12, 24, 40)
hint.BackgroundTransparency = 0.2
hint.Visible = false
hint.Parent = gui
Instance.new("UICorner", hint).CornerRadius = UDim.new(0, 22)
local stroke = Instance.new("UIStroke", hint)
stroke.Color, stroke.Thickness = BEACON_COLOR, 2
local arrow = Instance.new("TextLabel")
arrow.Name = "Arrow"
arrow.BackgroundTransparency = 1
arrow.Size = UDim2.fromOffset(34, 34)
arrow.Position = UDim2.fromOffset(8, 1)
arrow.Font = Enum.Font.GothamBold
arrow.Text = "▲"
arrow.TextScaled = true
arrow.TextColor3 = BEACON_COLOR
arrow.Parent = hint
local label = Instance.new("TextLabel")
label.Name = "Label"
label.BackgroundTransparency = 1
label.Position = UDim2.fromOffset(48, 0)
label.Size = UDim2.new(1, -60, 1, 0)
label.Font = Enum.Font.GothamBold
label.TextScaled = true
label.TextColor3 = Color3.new(1, 1, 1)
label.TextXAlignment = Enum.TextXAlignment.Left
label.Parent = hint
Instance.new("UITextSizeConstraint", label).MaxTextSize = 22

-- The banner: big and centred, with what was saved under it.
local banner = Instance.new("Frame")
banner.Name = "SafeBanner"
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.fromScale(0.5, 0.4)
banner.Size = UDim2.new(0.8, 0, 0, 130)
banner.BackgroundTransparency = 1
banner.Visible = false
banner.Parent = gui
Instance.new("UISizeConstraint", banner).MaxSize = Vector2.new(640, 130)
local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, 0, 0, 80)
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(150, 255, 190)
title.TextStrokeTransparency = 0.3
title.Parent = banner
local saved = Instance.new("TextLabel")
saved.Name = "Saved"
saved.BackgroundTransparency = 1
saved.Position = UDim2.fromOffset(0, 84)
saved.Size = UDim2.new(1, 0, 0, 36)
saved.Font = Enum.Font.GothamBold
saved.TextScaled = true
saved.TextColor3 = Color3.new(1, 1, 1)
saved.TextStrokeTransparency = 0.4
saved.Parent = banner

-- UI colorida: the shared look. The guide's blue and the rarity colours stay the strokes' colours (they carry meaning);
-- the style adds the rounded display font with a dark outline, shading and thicker borders. Without the module every
-- call is a no-op. UR-G: an older module without the glossy kit (no Style.gloss) counts as missing, so a partial sync
-- never stops the guide.
local Style = (function()
	local found = ReplicatedStorage:WaitForChild("WildboundUiStyle", 10)
	local kit = found and found:IsA("ModuleScript") and require(found)
	if type(kit) == "table" and type(kit.gloss) == "function" then return kit end
	return setmetatable({}, { __index = function() return function() end end })
end)()
Style.screen(gui)
-- UR-G (owner request 2026-11-20, docs/design/refs/store-ui-reference.png): the hint is a glossy pill in the guide's
-- blue (a thick dark border, a lighter top half, the darker 3D lip) with white outlined words; the kit lifts the
-- "Label" above the lip. The arrow keeps turning toward the base.
Style.gloss(hint, BEACON_COLOR)
Style.loudText(arrow)
Style.loudText(label)
Style.title(title, Color3.fromRGB(150, 255, 190))
Style.title(saved)

local shownUntil = 0
local function showBanner()
	banner.Visible = false
end
player:GetAttributeChangedSignal("WildboundSafeBanner"):Connect(showBanner)

-- The own base: its Pad (the floor) and the model.
local function ownBase()
	for _, model in ipairs(CollectionService:GetTagged("WildboundBaseSlot")) do
		if model:IsDescendantOf(workspace) and model:GetAttribute("OwnerUserId") == player.UserId then
			local pad = model:FindFirstChild("Pad") or model:FindFirstChild("BaseZone")
			if pad and pad:IsA("BasePart") then return model, pad end
		end
	end
	return nil
end

-- The beacon: built once per base, shown only while carrying.
local beacon = { pad = nil, folder = nil }
local function buildBeacon(pad)
	if beacon.pad == pad and beacon.folder and beacon.folder.Parent then return end
	if beacon.folder then beacon.folder:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "WildboundBaseGuideBeacon"
	local column = Instance.new("Part")
	column.Name = "Column"
	column.Shape = Enum.PartType.Cylinder
	column.Size = Vector3.new(80, 3, 3)
	column.CFrame = CFrame.new(pad.Position + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.rad(90))
	column.Anchored, column.CanCollide, column.CanTouch, column.CanQuery = true, false, false, false
	column.CastShadow = false
	column.Material = Enum.Material.Neon
	column.Color = BEACON_COLOR
	column.Transparency = 0.55
	column.Parent = folder
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range = BEACON_COLOR, 3, 24
	light.Parent = column
	local highlight = Instance.new("Highlight")
	highlight.Name = "PadHighlight"
	highlight.Adornee = pad
	highlight.FillColor, highlight.FillTransparency = BEACON_COLOR, 0.55
	highlight.OutlineColor, highlight.OutlineTransparency = Color3.new(1, 1, 1), 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = folder
	local anchor = Instance.new("Attachment")
	anchor.Name = "SignAnchor"
	anchor.Position = Vector3.new(0, 7, 0)
	anchor.Parent = pad
	local sign = Instance.new("BillboardGui")
	sign.Name = "DropHere"
	sign.Adornee = anchor
	sign.AlwaysOnTop = true
	sign.LightInfluence = 0
	sign.MaxDistance = 2000
	sign.Size = UDim2.fromOffset(260, 56)
	sign.Parent = folder
	local text = Instance.new("TextLabel")
	text.BackgroundColor3 = Color3.fromRGB(12, 24, 40)
	text.BackgroundTransparency = 0.15
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Text = "⬇ " .. Text.HUB.dropHere
	text.Parent = sign
	Instance.new("UICorner", text).CornerRadius = UDim.new(0, 14)
	local edge = Instance.new("UIStroke", text)
	edge.Color, edge.Thickness, edge.ApplyStrokeMode = BEACON_COLOR, 3, Enum.ApplyStrokeMode.Border
	-- UR-G: a glossy chip in the guide's blue with the 3D lip; the gloss reuses the sign's border (now dark and thick).
	Style.gloss(text, BEACON_COLOR)
	beacon.pad, beacon.folder, beacon.anchor = pad, folder, anchor
	folder.Parent = nil
end
local function setBeacon(visible)
	if not beacon.folder then return end
	local parent = visible and workspace or nil
	if beacon.folder.Parent ~= parent then beacon.folder.Parent = parent end
end

local elapsed = 0
RunService.RenderStepped:Connect(function(dt)
	if banner.Visible and os.clock() >= shownUntil then banner.Visible = false end
	elapsed += dt
	if elapsed < 0.1 then return end
	elapsed = 0
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local carrying = root ~= nil and character:FindFirstChild("WildboundEggCarried") ~= nil
	local _, pad = ownBase()
	if not carrying or not pad then
		hint.Visible = false
		setBeacon(false)
		return
	end
	buildBeacon(pad)
	setBeacon(true)
	local offset = pad.Position - root.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	label.Text = Text.HUB.goBase:format(math.floor(flat.Magnitude + 0.5))
	local camera = workspace.CurrentCamera
	if camera and flat.Magnitude > 0.1 then
		local look = camera.CFrame.LookVector
		local forward = Vector3.new(look.X, 0, look.Z)
		if forward.Magnitude > 1e-3 then
			forward = forward.Unit
			local dir = flat.Unit
			local angle = math.atan2(forward.X * dir.Z - forward.Z * dir.X, forward.X * dir.X + forward.Z * dir.Z)
			arrow.Rotation = math.deg(angle)
		end
	end
	hint.Visible = true
end)

-- Egg loop. Everything below only draws: the server already banked, paid and filled the cradle.
local loop = {}
do
	local function shared(name)
		local found = ReplicatedStorage:WaitForChild(name, 10)
		return found and found:IsA("ModuleScript") and require(found) or nil
	end
	loop.EggLoop = shared("WildboundEggLoop")
	loop.Catalog = shared("WildboundAudioCatalog")
	local species = shared("WildboundSpecies")
	loop.looks = species and species.LOOKS or nil
end
local EggLoop = loop.EggLoop
if EggLoop and Text.LOOP then
	local TweenService = game:GetService("TweenService")
	local Debris = game:GetService("Debris")
	local SoundService = game:GetService("SoundService")
	local C = EggLoop.CONFIG
	local snapshot = nil

	local function rarityColor(rarity)
		local rgb = EggLoop.RARITY_COLOR[rarity] or EggLoop.RARITY_COLOR.Comun
		return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	end
	local function reduced()
		local world = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("WildboundWorldUI")
		return world ~= nil and world:GetAttribute("Reduced") == true
	end
	-- A 2D one-shot from the catalog (existing shortlist ids only).
	local function play(slot, volume)
		local entry = loop.Catalog and loop.Catalog.SOUNDS[slot]
		if not entry then return end
		local sound = Instance.new("Sound")
		sound.Name = "WildboundEggLoop_" .. slot
		sound.SoundId = "rbxassetid://" .. tostring(entry.ids[1])
		sound.Volume = volume
		sound.PlaybackSpeed = entry.pitch or 1
		sound.Parent = SoundService
		sound:Play()
		Debris:AddItem(sound, 8)
	end
	-- One burst of sparkles at a world position, in the rarity's colour; fewer with "Efectos suaves".
	local function burst(position, color)
		if typeof(position) ~= "Vector3" then return end
		local holder = Instance.new("Attachment")
		holder.Name = "WildboundEggSparkles"
		holder.Parent = workspace.Terrain
		holder.Position = position -- Terrain sits at the origin, so this is the world position
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
		sparkles.LightEmission = 0.8
		sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
		sparkles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		sparkles.Lifetime = NumberRange.new(0.8, 1.4)
		sparkles.Speed = NumberRange.new(6, 12)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Acceleration = Vector3.new(0, -6, 0)
		sparkles.Rate = 0
		sparkles.Parent = holder
		sparkles:Emit(reduced() and C.SPARKLES_REDUCED or C.SPARKLES)
		Debris:AddItem(holder, 3)
	end

	-- The toast: a clean non-blocking banner at the top-centre below the health bar.
	local toast = Instance.new("Frame")
	toast.Name = "EggToast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 48)
	toast.Size = UDim2.new(0.86, 0, 0, 68)
	toast.BackgroundColor3 = Color3.fromRGB(12, 24, 40)
	toast.BackgroundTransparency = 0.1
	toast.Active = false
	toast.Visible = false
	toast.Parent = gui
	Instance.new("UISizeConstraint", toast).MaxSize = Vector2.new(440, 68)
	Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 12)
	local toastEdge = Instance.new("UIStroke", toast)
	toastEdge.Thickness = 3
	local toastScale = Instance.new("UIScale", toast)
	-- UR-G: the kit's dark HUD panel (16 px corners, a thick border, soft shading). It stays dark, not the pale toast,
	-- because the rarity colour stays on the border and the title, and a pale Común border would vanish on a pale fill.
	Style.dressPanel(toast, "dark")
	toastEdge.Thickness = 4
	local function toastLabel(name, y, height, font, maxSize)
		local item = Instance.new("TextLabel")
		item.Name = name
		item.BackgroundTransparency = 1
		item.Position = UDim2.new(0, 12, 0, y)
		item.Size = UDim2.new(1, -24, 0, height)
		item.Font = font
		item.TextScaled = true
		item.TextColor3 = Color3.new(1, 1, 1)
		item.Parent = toast
		Instance.new("UITextSizeConstraint", item).MaxTextSize = maxSize
		return item
	end
	local toastTitle = toastLabel("Title", 6, 28, Enum.Font.GothamBlack, 22)
	local toastLine = toastLabel("Line", 34, 24, Enum.Font.GothamBold, 17)
	local toastSub = toastLabel("Sub", 56, 12, Enum.Font.Gotham, 13)
	-- UR-G: the title and the line are round words with a thick dark outline (the reference's titles).
	Style.loudText(toastTitle, nil, 3)
	Style.loudText(toastLine, nil, 2, Color3.fromRGB(255, 214, 64))
	Style.body(toastSub, true)
	local toastUntil = 0
	local function showToast(lines, color, seconds)
		toastTitle.Text, toastLine.Text, toastSub.Text = lines.title or "", lines.line or "", ""
		toastSub.Visible = false
		toastTitle.TextColor3, toastEdge.Color = color, color
		toast.Position = hint.Visible and UDim2.new(0.5, 0, 0, 94) or UDim2.new(0.5, 0, 0, 48)
		toast.Visible = true
		toastUntil = os.clock() + seconds
		-- UR-G: the pop is left out with "Efectos suaves".
		if reduced() then
			toastScale.Scale = 1
		else
			toastScale.Scale = 0.85
			TweenService:Create(toastScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }):Play()
		end
	end

	-- The bank reward (the server writes it once per egg banked).
	local function onReward()
		local reward = EggLoop.decodeReward(player:GetAttribute("WildboundEggReward"))
		local lines = reward and EggLoop.rewardLines(reward, Text)
		if not lines then return end
		local color = rarityColor(reward.rarity)
		showToast(lines, color, C.REWARD_TOAST_SECONDS)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then burst(root.Position + Vector3.new(0, 2, 0), color) end
		play("eggBanked", 0.3)
	end
	player:GetAttributeChangedSignal("WildboundEggReward"):Connect(onReward)

	-- The own base's cradle: the incubator station (tag WildboundIncubatorStation) inside the base this player owns.
	local function ownCradle()
		local model = ownBase()
		if not model then return nil end
		for _, station in ipairs(CollectionService:GetTagged("WildboundIncubatorStation")) do
			if station:IsA("BasePart") and station:IsDescendantOf(model) then return station end
		end
		return nil
	end
	local sign = { station = nil, gui = nil }
	local function buildSign(station)
		if sign.station == station and sign.gui and sign.gui.Parent then return end
		if sign.gui then sign.gui:Destroy() end
		if sign.glow then sign.glow:Destroy() end
		-- A BillboardGui renders from PlayerGui (not from inside a ScreenGui); the Highlight lives in the workspace.
		local board = Instance.new("BillboardGui")
		board.Name = "WildboundCradleSign"
		board.Adornee = station
		board.AlwaysOnTop = true
		board.LightInfluence = 0
		board.MaxDistance = 160
		board.StudsOffsetWorldSpace = Vector3.new(0, (station.Size.Y / 2) + 4, 0)
		board.Size = UDim2.fromOffset(240, 76)
		board.Parent = gui.Parent
		local back = Instance.new("Frame")
		back.Name = "Back"
		back.BackgroundColor3 = Color3.fromRGB(12, 24, 40)
		back.BackgroundTransparency = 0.15
		back.Size = UDim2.fromScale(1, 1)
		back.Parent = board
		Instance.new("UICorner", back).CornerRadius = UDim.new(0, 12)
		local edge = Instance.new("UIStroke", back)
		edge.Name = "Edge"
		edge.Thickness, edge.Color = 3, BEACON_COLOR
		-- UI colorida: a slate sign with shading and a stroked status line. UR-G: now the kit's dark HUD panel (16 px
		-- corners, a 4 px border on the same "Edge", which the loop below still colours blue or green).
		back.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
		Style.dressPanel(back, "dark", 0.1)
		local status = Instance.new("TextLabel")
		status.Name = "Status"
		status.BackgroundTransparency = 1
		status.Position = UDim2.fromOffset(8, 4)
		status.Size = UDim2.new(1, -16, 0, 34)
		status.Font = Enum.Font.GothamBlack
		status.TextScaled = true
		status.TextColor3 = Color3.new(1, 1, 1)
		status.Parent = back
		Style.loudText(status)
		local shelf = Instance.new("Frame")
		shelf.Name = "Shelf"
		shelf.BackgroundTransparency = 1
		shelf.Position = UDim2.fromOffset(8, 42)
		shelf.Size = UDim2.new(1, -16, 0, 28)
		shelf.Parent = back
		local row = Instance.new("UIListLayout", shelf)
		row.FillDirection = Enum.FillDirection.Horizontal
		row.HorizontalAlignment = Enum.HorizontalAlignment.Center
		row.VerticalAlignment = Enum.VerticalAlignment.Center
		row.Padding = UDim.new(0, 5)
		row.SortOrder = Enum.SortOrder.LayoutOrder
		local glow = Instance.new("Highlight")
		glow.Name = "CradleGlow"
		glow.Adornee = station
		glow.FillColor, glow.FillTransparency = BEACON_COLOR, 1
		glow.OutlineColor, glow.OutlineTransparency = Color3.new(1, 1, 1), 1
		glow.DepthMode = Enum.HighlightDepthMode.Occluded
		glow.Parent = workspace
		sign.station, sign.gui, sign.status, sign.shelf, sign.glow, sign.edge = station, board, status, shelf, glow, edge
		sign.shelfKey = nil
	end
	-- The row of stored eggs (oldest first, rarity colours, "+N" past SHELF_MAX), rebuilt only when it changes.
	local function paintShelf(bankedEggs)
		local shelf = EggLoop.shelf(bankedEggs, C.SHELF_MAX, loop.looks)
		local key = table.concat(shelf.rarities, ",") .. "+" .. shelf.extra
		if sign.shelfKey == key then return end
		sign.shelfKey = key
		for _, child in ipairs(sign.shelf:GetChildren()) do
			if child:IsA("GuiObject") then child:Destroy() end
		end
		for index, rarity in ipairs(shelf.rarities) do
			local egg = Instance.new("Frame")
			egg.Name = "Egg" .. index
			egg.LayoutOrder = index
			egg.Size = UDim2.fromOffset(18, 24)
			egg.BackgroundColor3 = rarityColor(rarity)
			egg.Parent = sign.shelf
			Instance.new("UICorner", egg).CornerRadius = UDim.new(0.5, 0)
			local rim = Instance.new("UIStroke", egg)
			rim.Color, rim.Thickness = Color3.new(1, 1, 1), 1
			-- UR-G: a chunky egg, like the reference's icons: a dark 2 px rim (the same stroke) and a lit top.
			Style.outline(egg, 2)
			Style.shade(egg, 0.72)
		end
		if shelf.extra > 0 then
			local more = Instance.new("TextLabel")
			more.Name = "More"
			more.LayoutOrder = #shelf.rarities + 1
			more.BackgroundTransparency = 1
			more.Size = UDim2.fromOffset(36, 24)
			more.Font = Enum.Font.GothamBold
			more.TextScaled = true
			more.TextColor3 = Color3.new(1, 1, 1)
			more.Text = "+" .. shelf.extra
			more.Parent = sign.shelf
			Style.loudText(more)
		end
		sign.shelf.Visible = #shelf.rarities > 0
	end

	-- The hatch: the banner, sparkles at the cradle (or the player) and the harp.
	local function onHatched(card, customNotice)
		-- Words from EggLoop.hatchLines and Text.LOOP (EL13). No auto-equip, so the line always says where it was stored.
		local hasSpecies = type(card) == "table" and type(card.species) == "string" and card.species ~= ""
		local lines = hasSpecies and EggLoop.hatchLines(card, nil, Text) or {
			title = Text.LOOP.hatchTitle,
			line = (type(customNotice) == "string" and customNotice ~= "") and customNotice or Text.LOOP.hatchStoredPlain,
		}
		local color = Color3.fromRGB(150, 255, 190)
		showToast(lines, color, C.HATCH_BANNER_SECONDS or 4)
		local station = ownCradle()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local at = station and station.Position + Vector3.new(0, station.Size.Y / 2 + 1.5, 0)
			or root and root.Position + Vector3.new(0, 2, 0) or nil
		burst(at, color)
		play("eggHatched", 0.3)
	end

	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("WildboundNetwork", 10)
		local state = folder and folder:WaitForChild("State", 10)
		if not (state and state:IsA("RemoteEvent")) then return end
		state.OnClientEvent:Connect(function(payload)
			if type(payload) ~= "table" then return end
			if type(payload.snapshot) == "table" then snapshot = payload.snapshot end
			local act = payload.action
			if payload.ok ~= false and (act == "Hatched" or act == "IncubateDone" or act == "NewCreature"
				or (act == "Hatch" and type(payload.card) == "table")
				or type(payload.card) == "table") then
				onHatched(payload.card, payload.notice)
			end
		end)
	end)

	local clock = 0
	RunService.RenderStepped:Connect(function(dt)
		if toast.Visible and os.clock() >= toastUntil then toast.Visible = false end
		clock += dt
		if clock < 0.25 then return end
		clock = 0
		local station = ownCradle()
		if not station or not snapshot then
			if sign.gui then sign.gui.Enabled = false end
			if sign.glow then sign.glow.Enabled = false end
			return
		end
		if sign.glow then sign.glow.Enabled = true end
		buildSign(station)
		sign.gui.Enabled = true
		local incubating = type(snapshot.incubating) == "table" and snapshot.incubating[1] or nil
		local stored = type(snapshot.bankedEggs) == "table" and #snapshot.bankedEggs or 0
		local text, mode = EggLoop.cradleLine(incubating, workspace:GetServerTimeNow(), stored, Text)
		sign.status.Text = text or ""
		paintShelf(snapshot.bankedEggs)
		-- A free cradle with eggs waiting, or a hatching egg, glows and pulses; otherwise the glow is off.
		local pulse = 0.5 + 0.5 * math.sin(os.clock() * 4)
		local lit = mode == "freeEggs" or mode == "ready"
		sign.glow.FillTransparency = lit and (0.45 + 0.35 * pulse) or 1
		sign.glow.OutlineTransparency = lit and 0 or 1
		sign.edge.Color = mode == "busy" and Color3.fromRGB(150, 255, 190) or BEACON_COLOR
	end)
end

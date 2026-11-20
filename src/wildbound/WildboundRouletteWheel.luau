-- Wildbound roulette wheel (RW-1..RW-3, owner request 2026-11-20: "quiero que la ui de mi juego sea exactamente igual a
-- la de la foto que te envie y que lo de la ruleta sea asi", after docs/design/refs/roulette-wheel-reference.webp): a big
-- round wheel with one bright wedge per prize, a reward icon and a "+10" style label on each, a white ring, a white
-- pointer at the top, and the spin-pack buttons beside it. Presentation only: the server (WildboundRouletteService)
-- decides the prize; the client only turns the wheel so that prize stops under the pointer.
-- The pure part (angles, the landing rotation, colours, the fan geometry, the faces and the screen layout) has no
-- Instance, service, clock or random source and is pinned by tests/WildboundRouletteWheel_Test.luau. The builders at the
-- end make GUI objects from built-in pieces only (Frame, CanvasGroup, TextLabel, UICorner, UIStroke, UIGradient,
-- UIScale, UIAspectRatioConstraint, emoji text): no uploaded image, no remote, no purchase call. They take the kit
-- (WildboundUiStyle) as an argument, so this module requires nothing.
--
-- How a wedge is drawn without an image (RW-1): the wedge is a fan of thin straight strips, each one a w x R rectangle
-- whose long edge lies exactly on a ray from the centre. A strip is the top-right (or top-left) quarter of a transparent
-- "holder" frame that is 2w wide and one diameter tall, centred on the wheel and rotated to the ray's angle; GUI objects
-- turn around their own centre, so the holder turns around the wheel's centre and its child strip turns with it. In the
-- first half of a wedge the strips lie clockwise of their ray, in the second half anticlockwise, so the two boundary
-- strips start exactly on the wedge's straight edges and no strip reaches a neighbour outside the hub (fan().clearRatio
-- is the radius beyond which that holds; the white hub cap covers the middle). The strips overlap a little at the rim
-- (barOverlap), so nothing shows through. All the wedges sit in one CanvasGroup with a round UICorner: it clips the rim
-- to a clean circle, and the spin only turns the group's finished picture instead of laying out every strip each frame.
local Wheel = {}

local function freeze(value)
	if type(value) == "table" and not table.isfrozen(value) then
		for _, child in pairs(value) do freeze(child) end
		table.freeze(value)
	end
	return value
end

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function whole(value)
	return finite(value) and value == math.floor(value)
end

-- The reference's wedge colours, in order around the wheel: red, magenta, blue, cyan, green, yellow, orange.
Wheel.PALETTE = freeze({
	Color3.fromRGB(236, 34, 40),
	Color3.fromRGB(214, 30, 222),
	Color3.fromRGB(52, 36, 220),
	Color3.fromRGB(30, 222, 240),
	Color3.fromRGB(44, 222, 36),
	Color3.fromRGB(255, 236, 24),
	Color3.fromRGB(255, 142, 18),
})

-- Sizes as fractions of the wheel. ring: the white ring's width over the wheel's diameter. hubRatio: the hub cap's
-- diameter over the disc's diameter (so its radius over the disc's radius). spoke, icon and label: fractions of the
-- disc's diameter; iconRadius and labelRadius: distances from the centre over the disc's radius. The label lies across
-- its wedge (labelLength is its width along the rim), so it turns with the wedge like the reference's "+100".
-- Many thin strips keep the hub small (the reference has none): fan().clearRatio stays under hubRatio for 6..14 wedges.
Wheel.SIZES = freeze({
	barsPerWedge = 24,
	barOverlap = 1.25,
	ring = 0.04,
	ringStroke = 4,
	hubRatio = 0.13,
	divider = 0.012,
	spoke = 0.26,
	iconRadius = 0.72,
	iconSize = 0.12,
	labelRadius = 0.5,
	labelLength = 0.11,
	labelHeight = 0.075,
	pointer = 0.12,
	pointerLift = 0.01,
	jitterShare = 0.35,
})

-- The spin: several turns that slow down (Quint, Out) and stop on the server's prize. "Efectos suaves" makes it one
-- short turn and drops the little bounce at the end. seconds stays under WildboundRouletteService.SPIN_SECONDS (3.2),
-- and the HUD notice of the win waits WildboundRouletteService.NOTIFY_DELAY (3) so it never tells the prize first.
Wheel.MOTION = freeze({
	full = { turns = 5, seconds = 3, bounce = true },
	soft = { turns = 1, seconds = 1, bounce = false },
})

-- Words that are new with the wheel (Spanish). The words the panel already had stay in WildboundText.ROULETTE.
Wheel.WORDS = freeze({
	spinsLeft = "Tiradas: %d",
	extra = "Tirada extra gratis",
	joiner = "  ·  ",
	oddsButton = "i",
	chest = "Cofre",
	extraNoPity = "Las tiradas extra no cuentan para el premio asegurado.",
})

-- One simple built-in icon per kind of prize (emoji from the oldest, widest-supported set).
Wheel.ICONS = freeze({
	esencia = "✨",
	fogbark = "🌲",
	glowmoss = "🌿",
	nightbloom = "🌸",
	chest = "🎁",
	pouch = "🎒",
})

-- The screen layout, in pixels. Every button is at least 44 px tall (the touch guideline).
Wheel.LAYOUT = freeze({
	pad = 8,
	gap = 6,
	title = 36,
	info = 20,
	result = 24,
	buttons = 50,
	round = 50,
	rowMin = 290,
	caption = 18,
	pack = 58,
	packGap = 8,
	note = 18,
	minDiameter = 120,
	floorDiameter = 80,
	packFloor = 44,
	maxDiameter = 440,
	packMin = 150,
	packMax = 240,
	packIconMin = 140,
	wide = 1.1,
})

-- wedgeAngle(count) -> degrees per wedge, or nil when count is not a whole number of at least 1.
function Wheel.wedgeAngle(count)
	if not whole(count) or count < 1 then return nil end
	return 360 / count
end

-- wedgeCenter(index, count) -> the wedge's middle, in degrees clockwise from the top of the unturned wheel.
function Wheel.wedgeCenter(index, count)
	local step = Wheel.wedgeAngle(count)
	if not step or not whole(index) or index < 1 or index > count then return nil end
	return (index - 0.5) * step
end

-- clampJitter(value) -> a number in [-1, 1]; anything that is not a finite number is 0.
function Wheel.clampJitter(value)
	if not finite(value) then return 0 end
	return math.clamp(value, -1, 1)
end

-- normalize(angle) -> the same direction in [0, 360); not a finite number is 0.
function Wheel.normalize(angle)
	if not finite(angle) then return 0 end
	return angle % 360
end

-- indexAt(rotation, count) -> the wedge under the top pointer when the wheel is turned by rotation degrees (GUI
-- Rotation turns clockwise, so the wheel's angle a shows at a + rotation and the pointer reads a = -rotation).
function Wheel.indexAt(rotation, count)
	local step = Wheel.wedgeAngle(count)
	if not step then return nil end
	local angle = Wheel.normalize(-(finite(rotation) and rotation or 0))
	return math.clamp(math.floor(angle / step) + 1, 1, count)
end

-- targetRotation(prizeIndex, count, turns, jitter, from?) -> the Rotation to ease the wheel to so that the prize's
-- wedge stops under the pointer. It moves forward from `from` (default 0) by at least `turns` whole turns and less than
-- one turn more; jitter in [-1, 1] moves the stop inside the wedge by up to jitterShare of a wedge from its middle, so it
-- never lands on a line. nil on a bad index or count.
function Wheel.targetRotation(prizeIndex, count, turns, jitter, from)
	local center = Wheel.wedgeCenter(prizeIndex, count)
	if not center then return nil end
	local step = 360 / count
	local spins = finite(turns) and math.max(0, math.floor(turns)) or 0
	local start = finite(from) and from or 0
	local offset = Wheel.clampJitter(jitter) * step * Wheel.SIZES.jitterShare
	local base = Wheel.normalize(-(center + offset))
	local here = Wheel.normalize(start)
	local target = start - here + spins * 360 + base
	if base < here then target += 360 end
	return target
end

-- colorIndex(index, count) -> which PALETTE colour a wedge wears: the palette in order, except that the last wedge
-- skips the first wedge's colour, so no two neighbours (the last and the first included) ever match.
function Wheel.colorIndex(index, count)
	local size = #Wheel.PALETTE
	local value = (index - 1) % size + 1
	if count > 1 and index == count and value == 1 then
		value = 2
	end
	return value
end

function Wheel.color(index, count)
	return Wheel.PALETTE[Wheel.colorIndex(index, count)]
end

-- fan(count, perWedge?) -> { bars, width, gap, perWedge, clearRatio }. bars: { wedge, angle, side } (side 1 = the strip
-- lies clockwise of its ray, -1 = anticlockwise); width: a strip's width over the disc's diameter; gap: degrees between
-- rays; clearRatio: the radius (over the disc's radius) beyond which no strip crosses into a neighbour wedge.
function Wheel.fan(count, perWedge)
	local step = Wheel.wedgeAngle(count)
	if not step then return nil end
	local wanted = whole(perWedge) and perWedge or Wheel.SIZES.barsPerWedge
	local bars = math.max(4, 2 * math.floor(wanted / 2))
	local gap = step / (bars - 1)
	local width = Wheel.SIZES.barOverlap * math.rad(gap) * 0.5
	local list = {}
	for wedge = 1, count do
		for k = 0, bars - 1 do
			table.insert(list, { wedge = wedge, angle = (wedge - 1) * step + k * gap, side = k < bars / 2 and 1 or -1 })
		end
	end
	local half = math.sin(math.rad(math.min(step, 180) / 2))
	return { bars = list, width = width, gap = gap, perWedge = bars, clearRatio = width / (0.5 * half) }
end

local function shortNumber(amount)
	local value = math.max(0, math.floor(amount))
	if value >= 1000 then
		local thousands = value / 1000
		if thousands == math.floor(thousands) then
			return tostring(math.floor(thousands)) .. "K"
		end
		return string.format("%.1fK", thousands)
	end
	return tostring(value)
end
Wheel.shortNumber = shortNumber

-- face(prize) -> { kind, icon, label } for a WildboundRoulette prize: one kind of reward shows its own icon and "+n";
-- several kinds show a chest ("Cofre") when Legendaria, otherwise a pouch and the total. Anything unknown is a "?" chest.
function Wheel.face(prize)
	local grant = type(prize) == "table" and prize.grant or nil
	if type(grant) ~= "table" or next(grant) == nil then
		return { kind = "chest", icon = Wheel.ICONS.chest, label = "?" }
	end
	local kinds, sum, only = 0, 0, nil
	for key, amount in pairs(grant) do
		kinds += 1
		only = key
		if finite(amount) then sum += amount end
	end
	if kinds == 1 and Wheel.ICONS[only] and only ~= "chest" and only ~= "pouch" then
		return { kind = only, icon = Wheel.ICONS[only], label = "+" .. shortNumber(sum) }
	end
	if prize.rarity == "Legendaria" then
		return { kind = "chest", icon = Wheel.ICONS.chest, label = Wheel.WORDS.chest }
	end
	return { kind = "pouch", icon = Wheel.ICONS.pouch, label = "+" .. shortNumber(sum) }
end

-- motion(reduced) -> { turns, seconds, bounce }: the short spin with "Efectos suaves".
function Wheel.motion(reduced)
	local pick = reduced == true and Wheel.MOTION.soft or Wheel.MOTION.full
	return { turns = pick.turns, seconds = pick.seconds, bounce = pick.bounce }
end

local function rect(x, y, w, h)
	return { x = math.floor(x), y = math.floor(y), w = math.floor(w), h = math.floor(h) }
end

-- layout(width, height) -> boxes { x, y, w, h } in pixels for a window that size. Wide (a phone held sideways, a
-- computer): the title, the wheel, the result line and the buttons in a column, the three packs stacked on the right.
-- Narrow (a phone held upright): the same column with the packs in one row under the buttons. The wheel takes the room
-- that is left, between minDiameter and maxDiameter; on a short screen held sideways (a small phone under the 58 px top
-- bar) the wheel may go down to floorDiameter and the pack buttons to packFloor, so nothing leaves the screen. Returns
-- { wide, diameter, title, info, wheel, result, odds, spin, close, packs = { three boxes }, note }.
function Wheel.layout(width, height)
	local P = Wheel.LAYOUT
	local W = finite(width) and math.max(0, width) or 0
	local H = finite(height) and math.max(0, height) or 0
	local wide = W >= H * P.wide
	local fixed = P.title + P.info + P.result + P.buttons + 4 * P.gap
	local packW, columnW, packsH
	local packH = P.pack
	if wide then
		packW = math.clamp(math.floor(W * 0.28), P.packMin, P.packMax)
		columnW = math.max(0, W - packW - 5 * P.pad)
		local fit = math.floor((H - 2 * P.pad - 2 * P.packGap - P.gap - P.note) / 3) - P.caption
		packH = math.clamp(fit, P.packFloor, P.pack)
		packsH = 3 * (P.caption + packH) + 2 * P.packGap + P.gap + P.note
	else
		packW = 0
		columnW = math.max(0, W - 2 * P.pad)
		packsH = P.caption + P.pack + P.gap + P.note
	end
	local room = H - 2 * P.pad - fixed - (wide and 0 or (packsH + P.gap))
	local least = math.min(P.minDiameter, math.max(P.floorDiameter, math.floor(room)))
	local D = math.clamp(math.floor(math.min(columnW, room)), least, P.maxDiameter)
	local contentW = wide and math.min(columnW, math.max(D, P.rowMin)) or columnW
	local groupW = wide and (contentW + 3 * P.pad + packW) or contentW
	local left = math.max(P.pad, math.floor((W - groupW) / 2))
	local cx = left + contentW / 2
	local stackH = fixed + D + (wide and 0 or (P.gap + packsH))
	local y = math.max(P.pad, math.floor((H - stackH) / 2))
	local out = { wide = wide, diameter = D, packs = {} }
	out.title = rect(left, y, contentW, P.title)
	y += P.title + P.gap
	out.info = rect(left, y, contentW, P.info)
	y += P.info + P.gap
	out.wheel = rect(cx - D / 2, y, D, D)
	y += D + P.gap
	out.result = rect(left, y, contentW, P.result)
	y += P.result + P.gap
	local rowW = math.min(contentW, math.max(D, P.rowMin))
	local rowX = cx - rowW / 2
	local rest = rowW - P.round - 2 * P.gap
	local spinW = math.floor(rest * 0.55)
	out.odds = rect(rowX, y, P.round, P.buttons)
	out.spin = rect(rowX + P.round + P.gap, y, spinW, P.buttons)
	out.close = rect(rowX + P.round + 2 * P.gap + spinW, y, rest - spinW, P.buttons)
	y += P.buttons
	if wide then
		local px = left + contentW + 3 * P.pad
		local py = math.max(P.pad, math.floor((H - packsH) / 2))
		for index = 1, 3 do
			out.packs[index] = rect(px, py, packW, P.caption + packH)
			py += P.caption + packH + P.packGap
		end
		py += P.gap - P.packGap
		out.note = rect(px, py, packW, P.note)
	else
		y += P.gap
		local each = (columnW - 2 * P.packGap) / 3
		for index = 1, 3 do
			out.packs[index] = rect(left + (index - 1) * (each + P.packGap), y, each, P.caption + P.pack)
		end
		y += P.caption + P.pack + P.gap
		out.note = rect(left, y, columnW, P.note)
	end
	return out
end

-- ===================================================================================================================
-- Builders. Each takes its parent and the kit (WildboundUiStyle) and returns what it made; the root goes into the
-- parent last.
-- ===================================================================================================================

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(236, 34, 40)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 142, 18)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 236, 24)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(44, 212, 36)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(30, 160, 240)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(214, 30, 222)),
})

local function plainFrame(name, color)
	local item = Instance.new("Frame")
	item.Name = name
	item.BorderSizePixel = 0
	item.Active = false
	if color then
		item.BackgroundColor3 = color
		item.BackgroundTransparency = 0
	else
		item.BackgroundTransparency = 1
	end
	return item
end

local function round(item)
	local corner = item:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = item
	return corner
end

local function border(item, thickness, color)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "WbOutline"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = thickness
	stroke.Color = color
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = item
	return stroke
end

-- A holder: transparent, one disc diameter tall, centred on the disc and turned to `angle`.
local function holder(parent, name, widthScale, angle)
	local item = plainFrame(name)
	item.AnchorPoint = Vector2.new(0.5, 0.5)
	item.Position = UDim2.fromScale(0.5, 0.5)
	item.Size = UDim2.fromScale(widthScale, 1)
	item.Rotation = angle
	item.Parent = parent
	return item
end

-- buildWheel(parent, faces, Style) -> root "Wheel", disc "Disc". faces: one { icon, label } per wedge, in prize order.
-- root: a square transparent frame (the caller sizes it) holding the white "Ring", the turning "Disc" (a round
-- CanvasGroup with "Wedges", "Dividers" and "Faces"), the white "Hub" cap and the "Pointer" at the top. Turn the disc
-- by setting disc.Rotation; root's "WbPop" UIScale is there for a small bounce.
function Wheel.buildWheel(parent, faces, Style)
	local S = Wheel.SIZES
	local count = math.max(1, #faces)
	local outline = Style.COLORS.outline
	local white = Color3.new(1, 1, 1)
	local root = plainFrame("Wheel")
	root.Size = UDim2.fromOffset(300, 300)
	root:SetAttribute("WbWedges", #faces)
	local pop = Instance.new("UIScale")
	pop.Name = "WbPop"
	pop.Parent = root

	local ring = plainFrame("Ring", white)
	ring.Size = UDim2.fromScale(1, 1)
	ring.ZIndex = 1
	round(ring)
	border(ring, S.ringStroke, outline)
	ring.Parent = root

	local inner = 1 - 2 * S.ring
	local disc = Instance.new("CanvasGroup")
	disc.Name = "Disc"
	disc.BorderSizePixel = 0
	disc.Active = false
	disc.BackgroundColor3 = white
	disc.BackgroundTransparency = 0
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.Size = UDim2.fromScale(inner, inner)
	disc.ZIndex = 2
	round(disc)

	local wedges = plainFrame("Wedges")
	wedges.Size = UDim2.fromScale(1, 1)
	wedges.Parent = disc
	local fan = Wheel.fan(count)
	for _, bar in ipairs(fan.bars) do
		local spoke = holder(wedges, "Bar", 2 * fan.width, bar.angle)
		local strip = plainFrame("Strip", Wheel.color(bar.wedge, count))
		strip.Position = UDim2.fromScale(bar.side > 0 and 0.5 or 0, 0)
		strip.Size = UDim2.fromScale(0.5, 0.5)
		strip.Parent = spoke
	end

	local dividers = plainFrame("Dividers")
	dividers.Size = UDim2.fromScale(1, 1)
	dividers.Parent = disc
	if count > 1 then
		for index = 1, count do
			local line = holder(dividers, "Divider", S.divider, (index - 1) * 360 / count)
			local strip = plainFrame("Strip", outline)
			strip.Size = UDim2.fromScale(1, 0.5)
			strip.Parent = line
		end
	end

	local faceLayer = plainFrame("Faces")
	faceLayer.Size = UDim2.fromScale(1, 1)
	faceLayer.Parent = disc
	for index, face in ipairs(faces) do
		local spoke = holder(faceLayer, "Face" .. index, S.spoke, Wheel.wedgeCenter(index, count))
		local icon = Instance.new("TextLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.BorderSizePixel = 0
		icon.Active = false
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5 - S.iconRadius * 0.5)
		icon.Size = UDim2.fromScale(S.iconSize / S.spoke, S.iconSize)
		icon.Text = face.icon or ""
		icon.TextScaled = true
		icon.Font = Style.FONT_TITLE
		icon.TextColor3 = white
		icon.Parent = spoke
		local label = Style.kitLabel(spoke, "Label", face.label or "", 24, Style.FONT_TITLE, Style.KIT_SIZES.textStroke)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5 - S.labelRadius * 0.5)
		label.Size = UDim2.fromScale(S.labelLength / S.spoke, S.labelHeight)
		label.Rotation = 0
		Style.fitText(label, 40, 8)
		label.TextWrapped = false
	end
	disc.Parent = root

	local hubSize = S.hubRatio * inner
	local hub = plainFrame("Hub", white)
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.Size = UDim2.fromScale(hubSize, hubSize)
	hub.ZIndex = 3
	round(hub)
	border(hub, 3, outline)
	hub.Parent = root

	-- The pointer: an unrotated clip frame showing the lower half of a white square turned 45 degrees (a triangle
	-- pointing down at the wheel), with a dark line along its flat top.
	local pointer = plainFrame("Pointer")
	pointer.ClipsDescendants = true
	pointer.AnchorPoint = Vector2.new(0.5, 0)
	pointer.Position = UDim2.fromScale(0.5, -S.pointerLift)
	pointer.Size = UDim2.fromScale(S.pointer, S.pointer * 0.5 + 0.02)
	pointer.ZIndex = 4
	local tip = plainFrame("Tip", white)
	tip.AnchorPoint = Vector2.new(0.5, 0.5)
	tip.Position = UDim2.fromScale(0.5, 0)
	tip.Size = UDim2.fromScale(0.7071, 0.7071)
	tip.Rotation = 45
	local square = Instance.new("UIAspectRatioConstraint")
	square.AspectRatio = 1
	square.DominantAxis = Enum.DominantAxis.Width
	square.Parent = tip
	border(tip, 3, outline)
	tip.Parent = pointer
	local cap = plainFrame("Cap", outline)
	cap.Size = UDim2.new(1, 0, 0, 3)
	cap.Parent = pointer
	pointer.Parent = root

	root.Parent = parent
	return root, disc
end

-- buildMiniWheel(parent, Style) -> "WheelIcon": the small round rainbow wheel on a pack button (a white rim, a rainbow
-- face and a white middle dot). Square by its aspect constraint; the caller sizes its height.
function Wheel.buildMiniWheel(parent, Style)
	local white = Color3.new(1, 1, 1)
	local icon = plainFrame("WheelIcon", white)
	round(icon)
	border(icon, 2, Style.COLORS.outline)
	local square = Instance.new("UIAspectRatioConstraint")
	square.AspectRatio = 1
	square.DominantAxis = Enum.DominantAxis.Height
	square.Parent = icon
	local face = plainFrame("Face", white)
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.Size = UDim2.fromScale(0.78, 0.78)
	round(face)
	local colors = Instance.new("UIGradient")
	colors.Name = "WbRainbow"
	colors.Color = RAINBOW
	colors.Rotation = 45
	colors.Parent = face
	face.Parent = icon
	local dot = plainFrame("Dot", white)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromScale(0.22, 0.22)
	round(dot)
	dot.Parent = icon
	icon.Parent = parent
	return icon
end

-- buildPack(parent, offer, priceWords, Style) -> holder "Pack_<id>", button "Buy". A small loud caption on top (the
-- offer's caption in capitals), then a chunky button in the offer's tone with the mini wheel on the left, the offer's
-- name and, under it, the small price words. It only shows the offer: the caller decides what a tap does.
function Wheel.buildPack(parent, offer, priceWords, Style)
	local P = Wheel.LAYOUT
	local box = plainFrame("Pack_" .. tostring(offer.id))
	box:SetAttribute("OfferId", offer.id)
	box.Size = UDim2.fromOffset(200, P.caption + P.pack)
	local caption = Style.kitLabel(box, "Caption", string.upper(offer.caption or ""), 16, Style.FONT_TITLE, Style.KIT_SIZES.textStroke)
	caption.Size = UDim2.new(1, 0, 0, P.caption)
	Style.fitText(caption, 16, 9)
	local button, label = Style.kitButton(box, offer.name or "", offer.tone or "green", "Buy")
	button.Position = UDim2.fromOffset(0, P.caption)
	button.Size = UDim2.new(1, 0, 1, -P.caption)
	Style.corner(button, 18)
	Style.fitText(label, 26, 11)
	local icon = Wheel.buildMiniWheel(button, Style)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 4, 0.5, 0)
	icon.Size = UDim2.new(1, 0, 1, -8)
	local price = Style.kitLabel(button, "Price", priceWords or "", 15, Style.FONT_TITLE, 1.5)
	Style.fitText(price, 15, 9)
	box.Parent = parent
	Wheel.fitPack(box, 200, P.caption + P.pack)
	return box, button
end

-- fitPack(box, width, height): places a pack's words for its size in pixels. The mini wheel shows only when the pack
-- is at least packIconMin wide; the name takes the top of the button and the price the bottom.
function Wheel.fitPack(box, width, height)
	local P = Wheel.LAYOUT
	local button = box:FindFirstChild("Buy")
	if not button then return end
	local icon = button:FindFirstChild("WheelIcon")
	local label = button:FindFirstChild("Label")
	local price = button:FindFirstChild("Price")
	local showIcon = (tonumber(width) or 0) >= P.packIconMin
	local buttonH = math.max(0, (tonumber(height) or 0) - P.caption)
	local left = showIcon and buttonH or 6
	if icon then icon.Visible = showIcon end
	if label then
		label.Position = UDim2.fromOffset(left, 2)
		label.Size = UDim2.new(1, -(left + 6), 0.6, -2)
	end
	if price then
		price.Position = UDim2.new(0, left, 0.58, 0)
		price.Size = UDim2.new(1, -(left + 6), 0.38, 0)
	end
end

return Wheel

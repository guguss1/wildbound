-- Pure rectangles and words for the start screen, the Settings panel, the how-to-play card and the tutorial
-- card (W9, M8.5 and M8.6). The HUD layout (WildboundHudLayout.compute) goes in; local rectangles come out.
-- Nothing here reads or writes an interface object, the clock or a service; the controller applies it. Every
-- button is 44 pixels or more, and on a phone every panel stays out of the zones where Roblox draws the move
-- control and the jump button. See docs/ui/wildbound-start-and-settings.md.
local View = {}

View.MIN_TARGET = 44
View.TEXT_SIZE = 13

View.TEXT = table.freeze({
	title = "Wildbound",
	-- K1: player-facing words in neutral Spanish (they were English).
	tagline = "Roba crías dormidas. Vuelve sin que te vean.",
	-- NS1: the collection is saved now; carried things are not.
	note = "Tu colección se guarda.",
	settingsTitle = "Ajustes",
	howtoTitle = "Cómo jugar",
	howto = table.freeze({
		"Sigue los faroles hasta las islas de criaturas dormidas.",
		"Acércate sin correr, calma a la cría y séllala.",
		"Llévala al refugio del campamento y regístrala.",
		"Si La Silueta te ve, escóndete. Correr hace ruido.",
	}),
})

local PAD, GAP = 8, 6

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function rect(x, y, w, h)
	return { x = x, y = y, w = w, h = h }
end

-- Lines a text takes in `width` pixels at `size`. Gotham averages about 0.6 of the size per character.
function View.textLines(text, width, size)
	if type(text) ~= "string" or not finite(width) or not finite(size) or size <= 0 then return 1 end
	local perLine = math.max(1, math.floor(width / (size * 0.6)))
	return math.max(1, math.ceil((#text + 2) / perLine))
end

function View.textHeight(text, width, size)
	return View.textLines(text, width, size) * (size + 3) + 2
end

-- The part of the screen a panel may use. Desktop: all of it. A phone held upright: above the lower 40 percent
-- where the move control and the jump button are drawn. A phone held sideways: the column between the move
-- control (left 40 percent) and the jump button (bottom right).
function View.region(layout)
	local w, h, zones = layout.width, layout.height, layout.zones
	if layout.mode == "desktop" then return rect(8, 8, w - 16, h - 16) end
	if layout.portrait then return rect(8, 8, w - 16, math.max(120, math.floor(zones.thumbstick.y) - 16)) end
	local left = math.floor(zones.thumbstick.x + zones.thumbstick.w) + 8
	local right = math.floor(zones.jump.x) - 8
	if right - left < 240 then left = math.max(8, right - 240) end
	return rect(left, 8, right - left, h - 16)
end

-- A panel of this width and height centred in the region.
local function placed(region, width, height)
	local w = math.min(width, region.w)
	return rect(region.x + math.floor((region.w - w) / 2), region.y + math.max(0, math.floor((region.h - height) / 2)), w, height)
end

local function half(inner)
	local first = math.floor((inner - GAP) / 2)
	return first, inner - first - GAP
end

-- Start screen: title, tagline, Play, Settings and How to play side by side, the Reduced effects toggle (D11),
-- and a one-line note. All rectangles are local to the panel.
function View.start(layout)
	local region = View.region(layout)
	local width = math.min(360, region.w)
	local inner = width - 2 * PAD
	local out, y = {}, PAD
	out.title = rect(PAD, y, inner, 30); y += 32
	local tagH = View.textHeight(View.TEXT.tagline, inner, View.TEXT_SIZE)
	out.tagline = rect(PAD, y, inner, tagH); y += tagH + GAP
	out.play = rect(PAD, y, inner, 48); y += 48 + GAP
	local left, right = half(inner)
	out.settings = rect(PAD, y, left, View.MIN_TARGET)
	out.howto = rect(PAD + left + GAP, y, right, View.MIN_TARGET); y += View.MIN_TARGET + GAP
	out.reduced = rect(PAD, y, inner, View.MIN_TARGET); y += View.MIN_TARGET + GAP
	local noteH = View.textHeight(View.TEXT.note, inner, View.TEXT_SIZE)
	out.note = rect(PAD, y, inner, noteH); y += noteH + PAD
	out.panel = placed(region, width, y)
	out.region = region
	return out
end

-- Settings panel. descriptions = one sentence per setting row, in order. Each row has its words on the left
-- and a 70 by 44 On/Off toggle on the right; then Replay tutorial and Back side by side.
function View.settings(layout, descriptions)
	local region = View.region(layout)
	local width = math.min(360, region.w)
	local inner = width - 2 * PAD
	local out, y = { rows = {} }, PAD
	out.title = rect(PAD, y, inner, 30); y += 32
	local toggleW = 70
	local textW = inner - toggleW - GAP
	for _, text in ipairs(descriptions) do
		local textH = View.textHeight(text, textW, View.TEXT_SIZE)
		local rowH = math.max(48, textH)
		table.insert(out.rows, {
			text = rect(PAD, y + math.floor((rowH - textH) / 2), textW, textH),
			toggle = rect(PAD + textW + GAP, y + math.floor((rowH - View.MIN_TARGET) / 2), toggleW, View.MIN_TARGET),
			row = rect(PAD, y, inner, rowH),
		})
		y += rowH + GAP
	end
	local left, right = half(inner)
	out.replay = rect(PAD, y, left, View.MIN_TARGET)
	out.back = rect(PAD + left + GAP, y, right, View.MIN_TARGET); y += View.MIN_TARGET + PAD
	out.panel = placed(region, width, y)
	out.region = region
	return out
end

-- How to play: the title, the lines, one Back button. Local rectangles.
function View.howto(layout)
	local region = View.region(layout)
	local width = math.min(360, region.w)
	local inner = width - 2 * PAD
	local out, y = { lines = {} }, PAD
	out.title = rect(PAD, y, inner, 30); y += 32
	for _, text in ipairs(View.TEXT.howto) do
		local textH = View.textHeight(text, inner, View.TEXT_SIZE)
		table.insert(out.lines, rect(PAD, y, inner, textH))
		y += textH + 4
	end
	y += 2
	out.back = rect(PAD, y, inner, View.MIN_TARGET); y += View.MIN_TARGET + PAD
	out.panel = placed(region, width, y)
	out.region = region
	return out
end

-- The tutorial card. Where the screen has room it sits in free space; where it has none (a phone held upright,
-- where the avatar keep-out leaves under 50 pixels) it takes the place of the HUD objective line, which the
-- tutorial replaces anyway. Returns { mode, rect, text, skip } with text and skip local to the card.
function View.card(layout)
	local w, h, rects, zones = layout.width, layout.height, layout.rects, layout.zones
	local mode, area
	if layout.mode == "desktop" then
		local button = rects.inventory
		local cardW = math.min(420, w - 16)
		mode, area = "side", rect(w - 12 - cardW, button.y + button.h + 8, cardW, 60)
	elseif layout.portrait then
		mode, area = "hud", rect(rects.hud.x, rects.hud.y, rects.hud.w, 44)
	else
		local left = math.floor(zones.thumbstick.x + zones.thumbstick.w) + 6
		local right = math.floor(zones.jump.x) - 6
		local y = math.floor(zones.keepout.y + zones.keepout.h) + 6
		mode, area = "bottom", rect(left, y, math.min(340, right - left), math.max(46, math.min(60, h - 8 - y)))
	end
	local skipW = 64
	local skipH = View.MIN_TARGET
	local size = layout.mode == "desktop" and 14 or View.TEXT_SIZE
	return {
		mode = mode, rect = area, size = size,
		skip = rect(area.w - skipW - 4, math.floor((area.h - skipH) / 2), skipW, skipH),
		text = rect(8, 2, area.w - skipW - 4 - 8 - 8, area.h - 4),
	}
end

return View

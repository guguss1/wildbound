-- Pure HUD geometry for Wildbound: the viewport size in, pixel rectangles out. Nothing here reads or
-- writes an interface object. Both client controllers apply their own subset of the rectangles.
-- The avatar, thumbstick and jump zones are hypotheses about default framing and Roblox's default
-- touch controls; the layout test and the live check use the same zones. See docs/ui/wildbound-world.md.
local Layout = {}

Layout.MIN_TARGET = 44
-- Room taken inside the chip by the shape and its padding, before the text starts.
Layout.CHIP_TEXT_INSET = 44
Layout.ELEMENTS = table.freeze({ "chip", "hud", "panel", "inventory", "effects", "flashlight", "pulse" })
Layout.TOUCH_TARGETS = table.freeze({ "inventory", "effects", "flashlight", "pulse" })

local MARGIN, GAP, BUTTON_H = 8, 6, 44
local COLUMN_W = 110
local EDGE = 4

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function rect(x, y, w, h)
	return { x = x, y = y, w = w, h = h }
end

local function validRect(value)
	return type(value) == "table" and finite(value.x) and finite(value.y) and finite(value.w) and finite(value.h)
		and value.w > 0 and value.h > 0
end

function Layout.overlapArea(a, b)
	if not validRect(a) or not validRect(b) then return 0 end
	local width = math.min(a.x + a.w, b.x + b.w) - math.max(a.x, b.x)
	local height = math.min(a.y + a.h, b.y + b.h) - math.max(a.y, b.y)
	if width <= 0 or height <= 0 then return 0 end
	return width * height
end

-- Where the world view and Roblox's own touch controls live. Landscape and portrait follow the
-- default dynamic thumbstick frame; the jump button is the default bottom-right button.
function Layout.zones(width, height)
	local portrait = height > width
	local minAxis = math.min(width, height)
	local halfWidth = math.max(64, 0.08 * width)
	local halfHeight = math.clamp(0.25 * height, 80, 110)
	local jumpSize = minAxis <= 500 and 70 or 120
	local jumpX = width - (1.5 * jumpSize - 10) - 8
	local jumpY = height - jumpSize - 20 - 8
	return {
		keepout = rect(width / 2 - halfWidth, height / 2 - halfHeight, 2 * halfWidth, 2 * halfHeight),
		thumbstick = portrait and rect(0, 0.6 * height, width, 0.4 * height)
			or rect(0, height / 3, 0.4 * width, height * 2 / 3),
		jump = rect(jumpX, jumpY, width - jumpX, height - jumpY),
	}
end

-- How many characters fit in a text area of this pixel width. Gotham averages about 0.6 of the size
-- per character; a wrapped second line wastes a few. A budget for tests and for fitting long text.
function Layout.charBudget(width, size, lines)
	if not (finite(width) and finite(size) and finite(lines)) or size <= 0 or lines < 1 then return 1 end
	local perLine = math.floor(width / (size * 0.6))
	return math.max(1, perLine * lines - (lines - 1) * 6)
end

local function place(rects, name, x, y, w, h)
	rects[name] = rect(x, y, w, h)
end

-- Desktop: the geometry the controllers had before, plus the chip between the panels and the
-- inventory button.
local function desktop(width, height, rects)
	place(rects, "hud", 12, 12, math.min(width - 168, 430), 82)
	place(rects, "panel", 12, 100, math.min(width - 24, 400), 92)
	place(rects, "inventory", width - 12 - 132, 12, 132, BUTTON_H)
	place(rects, "effects", rects.panel.x + rects.panel.w - 126, rects.panel.y, 126, BUTTON_H)
	place(rects, "flashlight", width / 2 - 114, height - 90 - BUTTON_H, 110, BUTTON_H)
	place(rects, "pulse", width / 2 + 4, height - 90 - BUTTON_H, 110, BUTTON_H)
	local left = rects.hud.x + rects.hud.w + 8
	local right = rects.inventory.x - 8
	local chipWidth = 280
	local x = math.max((width - chipWidth) / 2, left)
	if x + chipWidth > right then chipWidth = right - x end
	place(rects, "chip", x, 12, chipWidth, BUTTON_H)
end

-- Compact landscape: text in the top-left corner, controls in a column at the right edge above the
-- jump button, the chip between them. Everything keeps clear of the avatar and the thumbstick.
local function compactLandscape(width, height, rects, zones)
	local columnWidth = math.clamp(math.floor(0.34 * width), 150, 280)
	place(rects, "hud", MARGIN, MARGIN, columnWidth, 42)
	place(rects, "panel", MARGIN, MARGIN + 42 + 2, columnWidth, 50)
	local limit = zones.jump.y - MARGIN
	local x, y = width - MARGIN - COLUMN_W, MARGIN
	local leftmost = x
	for _, name in ipairs({ "inventory", "effects", "flashlight", "pulse" }) do
		if y + BUTTON_H > limit and y > MARGIN then
			x, y = x - COLUMN_W - GAP, MARGIN
			leftmost = x
		end
		place(rects, name, x, y, COLUMN_W, BUTTON_H)
		y += BUTTON_H + GAP
	end
	local leftLimit = MARGIN + columnWidth + GAP
	local rightLimit = leftmost - GAP
	local halfFree = math.min(width / 2 - leftLimit, rightLimit - width / 2)
	local chipWidth = math.clamp(math.floor(2 * halfFree), 150, 240)
	local chipX = math.clamp(math.floor((width - chipWidth) / 2), leftLimit, math.max(leftLimit, rightLimit - chipWidth))
	place(rects, "chip", chipX, MARGIN, chipWidth, 40)
end

-- Compact portrait: everything stacks in the top band, above the avatar and the thumbstick.
local function compactPortrait(width, height, rects)
	local full = width - 2 * MARGIN
	local chipWidth = math.min(full, 320)
	place(rects, "chip", math.floor((width - chipWidth) / 2), MARGIN, chipWidth, 40)
	place(rects, "hud", MARGIN, MARGIN + 40 + 4, full, 42)
	place(rects, "panel", MARGIN, MARGIN + 40 + 4 + 42 + 2, full, 50)
	local buttonWidth = math.floor((full - 3 * GAP) / 4)
	local y = MARGIN + 40 + 4 + 42 + 2 + 50 + 4
	for index, name in ipairs({ "inventory", "effects", "flashlight", "pulse" }) do
		place(rects, name, MARGIN + (index - 1) * (buttonWidth + GAP), y, buttonWidth, BUTTON_H)
	end
end

-- options.touch: the device is touch-first, so the phone placement applies at any size.
function Layout.compute(width, height, options)
	local w = (finite(width) and width > 0) and width or 1280
	local h = (finite(height) and height > 0) and height or 720
	local touch = type(options) == "table" and options.touch == true
	local compact = touch or math.min(w, h) <= 500 or w < 1000
	local zones = Layout.zones(w, h)
	local rects = {}
	if not compact then
		desktop(w, h, rects)
	elseif h > w then
		compactPortrait(w, h, rects)
	else
		compactLandscape(w, h, rects, zones)
	end
	return { mode = compact and "compact" or "desktop", portrait = h > w, width = w, height = h,
		rects = rects, zones = zones }
end

-- Every rule the layout must keep. Returns a list of plain sentences; empty means the layout is sound.
-- The same check runs on rectangles measured from the live interface.
function Layout.check(layout)
	if type(layout) ~= "table" or type(layout.rects) ~= "table" or type(layout.zones) ~= "table"
		or not finite(layout.width) or not finite(layout.height) then
		return { "the layout is missing its rectangles, zones or size" }
	end
	local zones = layout.zones
	if not (validRect(zones.keepout) and validRect(zones.thumbstick) and validRect(zones.jump)) then
		return { "the layout is missing a zone" }
	end
	local violations = {}
	local compact = layout.mode == "compact"
	local present = {}
	for _, name in ipairs(Layout.ELEMENTS) do
		local item = layout.rects[name]
		if not validRect(item) then
			table.insert(violations, name .. " has no usable rectangle")
		else
			table.insert(present, name)
			if item.x < EDGE or item.y < EDGE or item.x + item.w > layout.width - EDGE
				or item.y + item.h > layout.height - EDGE then
				table.insert(violations, name .. " runs off screen")
			end
			if Layout.overlapArea(item, zones.keepout) > 0 then
				table.insert(violations, name .. " enters the avatar keep-out")
			end
			if compact and Layout.overlapArea(item, zones.thumbstick) > 0 then
				table.insert(violations, name .. " enters the thumbstick zone")
			end
			if compact and Layout.overlapArea(item, zones.jump) > 0 then
				table.insert(violations, name .. " sits on the jump button")
			end
		end
	end
	for _, name in ipairs(Layout.TOUCH_TARGETS) do
		local item = layout.rects[name]
		if validRect(item) and (item.w < Layout.MIN_TARGET or item.h < Layout.MIN_TARGET) then
			table.insert(violations, ("%s is %dx%d, under 44"):format(name, item.w, item.h))
		end
	end
	for first = 1, #present do
		for second = first + 1, #present do
			local a, b = present[first], present[second]
			local contained = layout.mode == "desktop" and ((a == "panel" and b == "effects") or (a == "effects" and b == "panel"))
			if not contained and Layout.overlapArea(layout.rects[a], layout.rects[b]) > 0 then
				table.insert(violations, a .. " and " .. b .. " overlap")
			end
		end
	end
	return violations
end

return Layout

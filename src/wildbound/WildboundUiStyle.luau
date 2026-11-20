-- Wildbound UI style, the "colorida" pass (odd/tasks/wildbound-ui-colorida.md): one palette and a few helpers that
-- dress the GUI objects the client scripts already build, in the bright, chunky, outlined look of Roblox simulator
-- games. Presentation only: no remotes, no purchases, no prices, no uploaded assets (only UIStroke, UIGradient,
-- UICorner, UIScale and built-in fonts).
-- Contract: every helper takes an existing GuiObject and adds or reuses named children (WbOutline, WbShade, WbCorner,
-- WbHeader, WbStripes, WbPress). None changes Name, Position, Size, Visible, Text, ZIndex or any handler, so each
-- script's layout (WildboundHudLayout, WildboundCampView, WildboundStartView) and behaviour stay as they were.
-- The store kit at the end of this file (P0.1) is different: its builders make new objects (see its own note).
local TweenService = game:GetService("TweenService")

local Style = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Panels are dark slate-navy with a near-black navy outline; tones are flat and saturated, shaded by a gradient.
Style.COLORS = table.freeze({
	panel = rgb(40, 50, 70),
	panelDeep = rgb(30, 38, 56),
	row = rgb(54, 66, 94),
	outline = rgb(16, 18, 34),
	ink = rgb(255, 255, 255),
	soft = rgb(214, 224, 245),
	gold = rgb(255, 214, 64),
	green = rgb(92, 214, 64),
	greenDark = rgb(38, 128, 30),
	red = rgb(236, 64, 72),
	blue = rgb(58, 148, 245),
	sky = rgb(72, 200, 250),
	purple = rgb(150, 86, 232),
	magenta = rgb(226, 62, 176),
	orange = rgb(255, 146, 38),
	yellow = rgb(255, 196, 36),
	slate = rgb(96, 108, 136),
	off = rgb(84, 92, 112),
})
-- Titles and buttons use the round bold display font; longer lines keep a Gotham weight close to the width the
-- layout's character budgets were measured with.
Style.FONT = Enum.Font.FredokaOne
Style.FONT_BODY = Enum.Font.GothamMedium
Style.FONT_BOLD = Enum.Font.GothamBold
Style.OUTLINE = 3
Style.PANEL_OUTLINE = 4
Style.CORNER = 10
Style.PRESS_SCALE = 0.95

function Style.color(name)
	return Style.COLORS[name] or Style.COLORS.slate
end

local function child(parent, className, name)
	local found = parent:FindFirstChild(name)
	if found and found:IsA(className) then
		return found
	end
	local item = Instance.new(className)
	item.Name = name
	item.Parent = parent
	return item
end

-- Every new ScreenGui sorts children over their parent; the header strip below relies on it.
function Style.screen(gui)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
end

-- Reuses the object's own UICorner when it has one (two corners on one object would fight).
function Style.corner(item, radius)
	local corner = item:FindFirstChildOfClass("UICorner") or child(item, "UICorner", "WbCorner")
	corner.CornerRadius = UDim.new(0, radius or Style.CORNER)
	return corner
end

-- A thick dark border. Reuses a border stroke the script already owns, so the script's later colour changes (the
-- awareness chip, the capture panel) keep working on the same stroke.
function Style.outline(item, thickness, color)
	local stroke = nil
	-- On a frame a Contextual stroke is a border too; on a text object only a Border stroke is.
	local textual = item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox")
	for _, candidate in ipairs(item:GetChildren()) do
		if candidate:IsA("UIStroke") and (not textual or candidate.ApplyStrokeMode == Enum.ApplyStrokeMode.Border) then
			stroke = candidate
			break
		end
	end
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Name = "WbOutline"
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = item
	end
	stroke.Color = color or Style.COLORS.outline
	stroke.Thickness = thickness or Style.OUTLINE
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Transparency = 0
	return stroke
end

-- Top lighter, bottom darker. The gradient multiplies the background colour, so a script that recolours the object
-- later (a cooldown, a toggle) keeps the same shading.
function Style.shade(item, low)
	local gradient = child(item, "UIGradient", "WbShade")
	local value = low or 0.78
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(value, value, value))
	gradient.Rotation = 90
	return gradient
end

-- Big display text: white unless a colour is given, with a dark outline.
function Style.title(label, color)
	label.Font = Style.FONT
	label.TextColor3 = color or Style.COLORS.ink
	label.TextStrokeColor3 = Style.COLORS.outline
	label.TextStrokeTransparency = 0
	return label
end

-- Body lines keep the colour the script gives them (amber for risk, for example); a soft outline keeps them readable
-- over the world.
function Style.body(label, bold)
	label.Font = bold and Style.FONT_BOLD or Style.FONT_BODY
	label.TextStrokeColor3 = Style.COLORS.outline
	label.TextStrokeTransparency = 0.55
	return label
end

-- Press feedback: a short squash to 0.95 while held. Reuses the button's own UIScale when it has one.
local pressed = setmetatable({}, { __mode = "k" })
local PRESS_INFO = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end
function Style.press(button)
	if pressed[button] then
		return
	end
	pressed[button] = true
	local scale = button:FindFirstChildOfClass("UIScale") or child(button, "UIScale", "WbPress")
	button.InputBegan:Connect(function(input)
		if isPress(input) and button.Active then
			TweenService:Create(scale, PRESS_INFO, { Scale = Style.PRESS_SCALE }):Play()
		end
	end)
	button.InputEnded:Connect(function(input)
		if isPress(input) then
			TweenService:Create(scale, PRESS_INFO, { Scale = 1 }):Play()
		end
	end)
end

-- A chunky button: flat saturated tone, dark outline, shading, white display text with an outline, press squash.
function Style.button(button, tone)
	button.BackgroundColor3 = Style.color(tone or "green")
	button.BackgroundTransparency = 0
	button.BorderSizePixel = 0
	Style.title(button)
	Style.corner(button, Style.CORNER)
	Style.outline(button, Style.OUTLINE)
	Style.shade(button)
	Style.press(button)
	return button
end

-- Recolours a styled button (a toggle, a cooldown) without touching anything else.
function Style.tint(button, tone)
	button.BackgroundColor3 = Style.color(tone)
end

-- A dark slate panel with a thick outline. transparency defaults to opaque; HUD strips pass a little.
function Style.panel(frame, transparency)
	frame.BackgroundColor3 = Style.COLORS.panel
	frame.BackgroundTransparency = transparency or 0
	frame.BorderSizePixel = 0
	Style.corner(frame, 12)
	Style.outline(frame, Style.PANEL_OUTLINE)
	Style.shade(frame, 0.82)
	return frame
end

-- A dark rounded pill (a counter, a banner, a hint), outlined.
function Style.pill(frame, transparency)
	frame.BackgroundColor3 = Style.COLORS.panelDeep
	frame.BackgroundTransparency = transparency or 0.05
	frame.BorderSizePixel = 0
	Style.corner(frame, 12)
	Style.outline(frame, Style.OUTLINE)
	return frame
end

-- A tile inside a panel: a flat vivid tone with the shading and the outline.
function Style.card(frame, tone)
	frame.BackgroundColor3 = Style.color(tone or "row")
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	Style.corner(frame, Style.CORNER)
	Style.outline(frame, Style.OUTLINE)
	Style.shade(frame, 0.8)
	return frame
end

-- Soft diagonal bands over a header: a white overlay whose transparency alternates (19 keypoints, under the 20 limit).
local STRIPES = (function()
	local points = {}
	for index = 0, 18 do
		table.insert(points, NumberSequenceKeypoint.new(index / 18, index % 2 == 0 and 0.86 or 1))
	end
	return NumberSequence.new(points)
end)()

-- The saturated strip across the top of a panel, under its title and header buttons (ZIndex 0 with the Sibling
-- order set by Style.screen). height is in pixels; calling it again only moves and recolours the same strip.
function Style.header(frame, height, tone)
	local strip = child(frame, "Frame", "WbHeader")
	strip.BackgroundColor3 = Style.color(tone or "magenta")
	strip.BackgroundTransparency = 0
	strip.BorderSizePixel = 0
	strip.Position = UDim2.fromOffset(0, 0)
	strip.Size = UDim2.new(1, 0, 0, height)
	strip.ZIndex = 0
	strip.Active = false
	Style.corner(strip, 12)
	Style.shade(strip, 0.72)
	local stripes = child(strip, "Frame", "WbStripes")
	stripes.BackgroundColor3 = Color3.new(1, 1, 1)
	stripes.BackgroundTransparency = 0
	stripes.BorderSizePixel = 0
	stripes.Size = UDim2.fromScale(1, 1)
	stripes.ZIndex = 0
	stripes.Active = false
	Style.corner(stripes, 12)
	local bands = child(stripes, "UIGradient", "WbStripes")
	bands.Transparency = STRIPES
	bands.Rotation = 35
	return strip
end

-- A progress bar: a dark outlined track and a rainbow fill. The fill's own BackgroundColor3 multiplies the rainbow,
-- so white shows it as is and a warning colour tints it.
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, rgb(255, 72, 72)),
	ColorSequenceKeypoint.new(0.2, rgb(255, 160, 40)),
	ColorSequenceKeypoint.new(0.4, rgb(255, 230, 60)),
	ColorSequenceKeypoint.new(0.6, rgb(100, 220, 80)),
	ColorSequenceKeypoint.new(0.8, rgb(70, 170, 255)),
	ColorSequenceKeypoint.new(1, rgb(170, 100, 255)),
})
function Style.bar(track, fill)
	track.BackgroundColor3 = Style.COLORS.panelDeep
	track.BackgroundTransparency = 0
	track.BorderSizePixel = 0
	Style.outline(track, 2)
	if fill then
		local gradient = child(fill, "UIGradient", "WbRainbow")
		gradient.Color = RAINBOW
		gradient.Rotation = 0
	end
	return track
end

-- ===================================================================================================================
-- The store kit (P0.1 of docs/design/wildbound-fun-build-plan.md, owner request 2026-11-20: "Quiero que la estetica
-- sea asi de la ui, con esa tipografia"), after docs/design/refs/store-ui-reference.png: a bright blue window with a
-- light panel inside, a big title with a thick dark outline, round category buttons, a big red X, gradient cards with
-- sunburst rays, a tilted "¡NUEVO!", chunky price buttons, a timer chip and a lock.
-- Built-in pieces only: Frame, TextButton, UIStroke, UIGradient, UICorner, UIScale, built-in fonts and emoji text.
-- No uploaded image, no remote, no purchase call: a price button only shows a price, and the caller decides what a tap
-- does. The pure helpers (tables, texts, sizes, motion rules) are tested in tests/WildboundUiKit_Test.luau.
-- Every builder takes a parent and returns the instances it made; the root goes into the parent last. One UIStroke per
-- object: a button's thick border sits on the button, the outline of its words on a child "Label", so the two never
-- share an object.
-- ===================================================================================================================

Style.KIT_COLORS = table.freeze({
	frame = rgb(48, 140, 246),
	frameOutline = rgb(14, 30, 78),
	inner = rgb(236, 246, 255),
	innerEdge = rgb(140, 190, 240),
	inkDark = rgb(28, 36, 66),
	coin = rgb(255, 150, 30),
	coinFace = rgb(255, 214, 64),
	robux = rgb(64, 204, 72),
	close = rgb(232, 46, 56),
	badge = rgb(240, 40, 52),
	badgeOutline = rgb(255, 255, 255),
	chip = rgb(255, 255, 255),
	lockShade = rgb(10, 12, 26),
})

-- Sizes in pixels. Every tap target is at least minTap (44 px, the touch guideline).
Style.KIT_SIZES = table.freeze({
	minTap = 44,
	close = 48,
	category = 52,
	priceHeight = 48,
	buttonHeight = 52,
	titleStroke = 3,
	textStroke = 2,
	frameStroke = 4,
	buttonStroke = 3,
	frameCorner = 18,
	innerCorner = 14,
	cardCorner = 14,
	header = 60,
	innerPad = 10,
	rays = 12,
	rayWidth = 26,
	rayLength = 800,
	rayInset = 5,
	spinSeconds = 24,
	badgeTilt = -12,
	pulseScale = 1.08,
	pulseSeconds = 0.6,
	lockTransparency = 0.4,
	wideWidth = 500,
	timerMax = 359999,
	priceMax = 999999,
})

-- FredokaOne (round) for titles and buttons; LuckiestGuy (heavier, capitals) for "¡NUEVO!" and the X.
Style.FONT_TITLE = Enum.Font.FredokaOne
Style.FONT_LOUD = Enum.Font.LuckiestGuy

-- The Robux sign is a private-use letter in Roblox's own fonts (U+E002). If Play shows an empty box, pass glyph =
-- false and the price falls back to "R$".
Style.ROBUX_GLYPH = utf8.char(0xE002)
Style.ROBUX_FALLBACK = "R$"
Style.NEW_TEXT = "¡NUEVO!"
Style.CLOCK_ICON = "🕐"
Style.LOCK_ICON = "🔒"

-- Card gradients, left to right: cyan into a pale lime, magenta into a pink purple, yellow into orange.
local CARD_TONES = table.freeze({
	cyan = table.freeze({ rgb(56, 208, 250), rgb(214, 244, 168) }),
	magenta = table.freeze({ rgb(236, 40, 214), rgb(186, 72, 240) }),
	yellow = table.freeze({ rgb(255, 226, 40), rgb(255, 160, 24) }),
})
Style.CARD_TONES = CARD_TONES

-- cardColors(tone) -> from, to. An unknown tone is cyan.
function Style.cardColors(tone)
	local pair = CARD_TONES[tone] or CARD_TONES.cyan
	return pair[1], pair[2]
end

function Style.cardGradient(tone)
	local from, to = Style.cardColors(tone)
	return ColorSequence.new(from, to)
end

-- tapSize(pixels) -> never under 44.
function Style.tapSize(pixels)
	local value = tonumber(pixels)
	if value == nil or value ~= value then
		value = 0
	end
	return math.max(value, Style.KIT_SIZES.minTap)
end

-- motion(reduced) -> { spin, pulse }. With "Efectos suaves" (reduced = true) the rays stand still and "¡NUEVO!"
-- does not beat.
function Style.motion(reduced)
	local soft = reduced == true
	return { spin = not soft, pulse = not soft }
end

-- reduced(playerGui) -> the "Efectos suaves" setting, as the world gui's Reduced attribute carries it (set by
-- WildboundStart). Like WildboundCapture, anything but an explicit false counts as reduced.
function Style.reduced(playerGui)
	local world = playerGui and playerGui:FindFirstChild("WildboundWorldUI")
	local value = world and world:GetAttribute("Reduced")
	return value ~= false
end

-- urgencyAllowed(kind) -> whether "¡NUEVO!" or a timer may sit on this offer: only free things (gold, Esencia, an
-- event), never a paid one ("robux"), so nothing hurries a child into paying.
function Style.urgencyAllowed(kind)
	return kind ~= "robux"
end

-- isWide(width) -> whether a window this wide (in pixels) lays out in two columns.
function Style.isWide(width)
	return (tonumber(width) or 0) >= Style.KIT_SIZES.wideWidth
end

local function whole(value, top)
	local number = tonumber(value)
	if number == nil or number ~= number then
		number = 0
	end
	return math.floor(math.clamp(number, 0, top))
end

-- priceText(kind, amount, glyph) -> the words on a price button. "coin": the number (the coin is drawn beside it);
-- "robux": the Robux sign and the number, or "R$" when glyph is false.
function Style.priceText(kind, amount, glyph)
	local number = tostring(whole(amount, Style.KIT_SIZES.priceMax))
	if kind == "robux" then
		local mark = glyph == false and Style.ROBUX_FALLBACK or Style.ROBUX_GLYPH
		return mark .. " " .. number
	end
	return number
end

-- timerText(seconds) -> "24h30m43s", "2m05s" or "7s"; never negative, at most 99h59m59s.
function Style.timerText(seconds)
	local total = whole(seconds, Style.KIT_SIZES.timerMax)
	local hours = total // 3600
	local minutes = (total % 3600) // 60
	local rest = total % 60
	if hours > 0 then
		return string.format("%dh%02dm%02ds", hours, minutes, rest)
	end
	if minutes > 0 then
		return string.format("%dm%02ds", minutes, rest)
	end
	return string.format("%ds", rest)
end

-- rayAngles(count) -> the rotation of each ray bar. A bar crosses the centre, so count bars over 180 degrees draw
-- 2 x count rays.
function Style.rayAngles(count)
	local angles = {}
	local total = math.max(1, math.floor(tonumber(count) or Style.KIT_SIZES.rays))
	for index = 0, total - 1 do
		table.insert(angles, index * 180 / total)
	end
	return angles
end

local function kitTone(tone)
	return Style.KIT_COLORS[tone] or Style.color(tone)
end

local function setCorner(item, radius)
	local corner = item:FindFirstChildOfClass("UICorner") or child(item, "UICorner", "WbCorner")
	corner.CornerRadius = radius
	return corner
end

-- loudText(label, font, thickness, color): big white words with a thick dark outline (a Contextual UIStroke, which
-- outlines the letters; the old TextStroke is turned off).
function Style.loudText(label, font, thickness, color)
	label.Font = font or Style.FONT_TITLE
	label.TextColor3 = color or Style.COLORS.ink
	label.TextStrokeTransparency = 1
	local stroke = child(label, "UIStroke", "WbTextStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Thickness = thickness or Style.KIT_SIZES.textStroke
	stroke.Color = Style.COLORS.outline
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Transparency = 0
	return label
end

-- fitText(label, maxSize, minSize): shrink to fit the box (a phone), never over maxSize.
function Style.fitText(label, maxSize, minSize)
	label.TextScaled = true
	label.TextWrapped = true
	local fit = child(label, "UITextSizeConstraint", "WbFit")
	fit.MaxTextSize = maxSize
	fit.MinTextSize = minSize or 10
	return fit
end

-- kitLabel(parent, name, text, size, font, thickness) -> a transparent TextLabel with loud text.
function Style.kitLabel(parent, name, text, size, font, thickness)
	local label = Instance.new("TextLabel")
	label.Name = name or "Label"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Active = false
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text or ""
	label.TextSize = size or 20
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	Style.loudText(label, font, thickness)
	label.Parent = parent
	return label
end

-- kitTitle(parent, text, size) -> "Title": the big FredokaOne title with the thick outline, shrinking on a phone.
function Style.kitTitle(parent, text, size)
	local top = size or 30
	local title = Style.kitLabel(parent, "Title", text, top, Style.FONT_TITLE, Style.KIT_SIZES.titleStroke)
	Style.fitText(title, top, 16)
	return title
end

-- kitWindow(parent, name, header) -> window, inner. The bright blue frame (thick dark border, rounded) and the light
-- panel inside it, header pixels below the top: the title, category buttons and the X go in the window above it.
function Style.kitWindow(parent, name, header)
	local top = header or Style.KIT_SIZES.header
	local pad = Style.KIT_SIZES.innerPad
	local window = Instance.new("Frame")
	window.Name = name or "Window"
	window.BackgroundColor3 = Style.KIT_COLORS.frame
	window.BackgroundTransparency = 0
	window.BorderSizePixel = 0
	setCorner(window, UDim.new(0, Style.KIT_SIZES.frameCorner))
	Style.outline(window, Style.KIT_SIZES.frameStroke, Style.KIT_COLORS.frameOutline)
	Style.shade(window, 0.8)
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundColor3 = Style.KIT_COLORS.inner
	inner.BackgroundTransparency = 0
	inner.BorderSizePixel = 0
	inner.Position = UDim2.new(0, pad, 0, top)
	inner.Size = UDim2.new(1, -2 * pad, 1, -(top + pad))
	setCorner(inner, UDim.new(0, Style.KIT_SIZES.innerCorner))
	Style.outline(inner, Style.KIT_SIZES.buttonStroke, Style.KIT_COLORS.innerEdge)
	local padding = child(inner, "UIPadding", "WbPad")
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0, pad), UDim.new(0, pad)
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, pad), UDim.new(0, pad)
	inner.Parent = window
	window.Parent = parent
	return window, inner
end

-- kitButton(parent, text, tone, name) -> button, label. A chunky button: a flat tone (a KIT_COLORS or COLORS name),
-- a thick dark border, top-light shading, the press squash and never smaller than 44 x 44. Its words are the child
-- "Label" (set them with Style.setLabel), so they can carry their own thick outline.
function Style.kitButton(parent, text, tone, name)
	local button = Instance.new("TextButton")
	button.Name = name or "Button"
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundColor3 = kitTone(tone or "green")
	button.BackgroundTransparency = 0
	button.BorderSizePixel = 0
	button.Size = UDim2.fromOffset(160, Style.tapSize(Style.KIT_SIZES.buttonHeight))
	setCorner(button, UDim.new(0, 12))
	Style.outline(button, Style.KIT_SIZES.buttonStroke)
	Style.shade(button, 0.72)
	local tap = child(button, "UISizeConstraint", "WbTapMin")
	tap.MinSize = Vector2.new(Style.KIT_SIZES.minTap, Style.KIT_SIZES.minTap)
	local label = Style.kitLabel(button, "Label", text, 24, Style.FONT_TITLE, Style.KIT_SIZES.textStroke)
	Style.press(button)
	button.Parent = parent
	return button, label
end

-- setLabel(button, text): the words of a kit button (or of a plain button that has no "Label").
function Style.setLabel(button, text)
	local label = button:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.Text = text
	else
		button.Text = text
	end
end

-- kitCategoryButton(parent, icon, tone) -> "Category": a round 52 px button with an emoji.
function Style.kitCategoryButton(parent, icon, tone)
	local size = Style.tapSize(Style.KIT_SIZES.category)
	local button, label = Style.kitButton(parent, icon, tone or "sky", "Category")
	button.Size = UDim2.fromOffset(size, size)
	setCorner(button, UDim.new(0.5, 0))
	label.TextSize = 28
	return button
end

-- kitClose(parent) -> "CloseX": the big red X, 48 px, top right of its parent unless the caller moves it.
function Style.kitClose(parent)
	local size = Style.tapSize(Style.KIT_SIZES.close)
	local button, label = Style.kitButton(parent, "X", "close", "CloseX")
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, -8, 0, 6)
	button.Size = UDim2.fromOffset(size, size)
	label.Font = Style.FONT_LOUD
	label.TextSize = 30
	return button
end

-- The sunburst: a plain "Rays" frame with ClipsDescendants (an unrotated frame clips its rotated children; a
-- CanvasGroup would redraw its whole picture every frame the rays turn) holding a small centred "Burst" frame with
-- soft white bars that cross the centre. setSpin turns the Burst slowly. Rays sits rayInset pixels inside the card so
-- its square clip stays within the card's rounded corners.
-- Each bar is clear at the middle (about 32 px each side of the centre, where every bar crosses and the card's words
-- sit) and at most about 18% white further out, so the card keeps its colour, like the faint rays of the reference.
local RAY_FADE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.3, 0.82),
	NumberSequenceKeypoint.new(0.46, 1),
	NumberSequenceKeypoint.new(0.54, 1),
	NumberSequenceKeypoint.new(0.7, 0.82),
	NumberSequenceKeypoint.new(1, 1),
})
Style.RAY_FADE = RAY_FADE

local spins = setmetatable({}, { __mode = "k" })

-- setSpin(card, on) -> whether the card's rays now turn. Off cancels the tween (call it when the window closes).
function Style.setSpin(card, on)
	local rays = card:FindFirstChild("Rays")
	local burst = rays and rays:FindFirstChild("Burst")
	local running = spins[card]
	if running then
		running:Cancel()
		spins[card] = nil
	end
	local turning = on == true and burst ~= nil
	card:SetAttribute("WbSpin", turning)
	if not turning then
		return false
	end
	local start = burst.Rotation % 360
	burst.Rotation = start
	local info = TweenInfo.new(Style.KIT_SIZES.spinSeconds, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
	local tween = TweenService:Create(burst, info, { Rotation = start + 360 })
	spins[card] = tween
	tween:Play()
	return true
end

-- kitCard(parent, tone, reduced, name) -> "Card": a rounded gradient card (cyan, magenta or yellow) with sunburst
-- rays behind its content. The rays turn unless reduced ("Efectos suaves"). Content added later draws over the rays
-- (they sit at ZIndex 0).
function Style.kitCard(parent, tone, reduced, name)
	local card = Instance.new("Frame")
	card.Name = name or "Card"
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.BackgroundTransparency = 0
	card.BorderSizePixel = 0
	card.Size = UDim2.fromOffset(240, 120)
	setCorner(card, UDim.new(0, Style.KIT_SIZES.cardCorner))
	Style.outline(card, Style.KIT_SIZES.buttonStroke)
	local tint = child(card, "UIGradient", "WbCardTone")
	tint.Color = Style.cardGradient(tone)
	tint.Rotation = 20
	card:SetAttribute("WbTone", CARD_TONES[tone] and tone or "cyan")
	local inset = Style.KIT_SIZES.rayInset
	local rays = Instance.new("Frame")
	rays.Name = "Rays"
	rays.BackgroundTransparency = 1
	rays.BorderSizePixel = 0
	rays.Active = false
	rays.ClipsDescendants = true
	rays.Position = UDim2.fromOffset(inset, inset)
	rays.Size = UDim2.new(1, -2 * inset, 1, -2 * inset)
	rays.ZIndex = 0
	local burst = Instance.new("Frame")
	burst.Name = "Burst"
	burst.BackgroundTransparency = 1
	burst.BorderSizePixel = 0
	burst.Active = false
	burst.AnchorPoint = Vector2.new(0.5, 0.5)
	burst.Position = UDim2.fromScale(0.5, 0.5)
	burst.Size = UDim2.fromOffset(2, 2)
	for index, angle in ipairs(Style.rayAngles(Style.KIT_SIZES.rays)) do
		local ray = Instance.new("Frame")
		ray.Name = "Ray" .. index
		ray.BackgroundColor3 = Color3.new(1, 1, 1)
		ray.BackgroundTransparency = 0
		ray.BorderSizePixel = 0
		ray.Active = false
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromOffset(Style.KIT_SIZES.rayWidth, Style.KIT_SIZES.rayLength)
		ray.Rotation = angle
		local fade = Instance.new("UIGradient")
		fade.Name = "WbFade"
		fade.Transparency = RAY_FADE
		fade.Rotation = 90
		fade.Parent = ray
		ray.Parent = burst
	end
	burst.Parent = rays
	rays.Parent = card
	card.Destroying:Connect(function()
		Style.setSpin(card, false)
	end)
	Style.setSpin(card, Style.motion(reduced).spin)
	card.Parent = parent
	return card
end

local pulses = setmetatable({}, { __mode = "k" })

-- setPulse(badge, on) -> whether the "¡NUEVO!" badge now beats. Off cancels the tween and sets the size back to 1
-- (call it when "Efectos suaves" turns on); destroying the badge also cancels it.
function Style.setPulse(badge, on)
	local scale = badge:FindFirstChild("WbPulse")
	local running = pulses[badge]
	if running then
		running:Cancel()
		pulses[badge] = nil
	end
	local beating = on == true and scale ~= nil and scale:IsA("UIScale")
	badge:SetAttribute("WbPulse", beating)
	if scale and scale:IsA("UIScale") then
		scale.Scale = 1
	end
	if not beating then
		return false
	end
	local info = TweenInfo.new(Style.KIT_SIZES.pulseSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local tween = TweenService:Create(scale, info, { Scale = Style.KIT_SIZES.pulseScale })
	pulses[badge] = tween
	tween:Play()
	return true
end

-- kitNewBadge(parent, kind, reduced, text) -> "NewBadge", or nil for a paid ("robux") offer. Red tilted LuckiestGuy
-- words with a white outline; it beats gently unless reduced (setPulse changes that later).
function Style.kitNewBadge(parent, kind, reduced, text)
	if not Style.urgencyAllowed(kind) then
		return nil
	end
	local badge = Style.kitLabel(parent, "NewBadge", text or Style.NEW_TEXT, 24, Style.FONT_LOUD, Style.KIT_SIZES.textStroke)
	badge.TextColor3 = Style.KIT_COLORS.badge
	badge.TextWrapped = false
	badge.Size = UDim2.fromOffset(110, 34)
	badge.Rotation = Style.KIT_SIZES.badgeTilt
	local stroke = badge:FindFirstChild("WbTextStroke")
	if stroke then
		stroke.Color = Style.KIT_COLORS.badgeOutline
	end
	local scale = child(badge, "UIScale", "WbPulse")
	scale.Scale = 1
	badge.Destroying:Connect(function()
		Style.setPulse(badge, false)
	end)
	Style.setPulse(badge, Style.motion(reduced).pulse)
	return badge
end

-- kitPriceButton(parent, kind, amount, glyph) -> "Price": a chunky price button. "coin": orange with a drawn coin;
-- "robux": green with the Robux sign (or "R$" when glyph is false). It only shows the price: the caller decides what
-- a tap does, and nothing here ever asks Roblox to charge anyone.
function Style.kitPriceButton(parent, kind, amount, glyph)
	local paid = kind == "robux"
	local button, label = Style.kitButton(parent, Style.priceText(kind, amount, glyph), paid and "robux" or "coin", "Price")
	button.Size = UDim2.fromOffset(120, Style.tapSize(Style.KIT_SIZES.priceHeight))
	Style.fitText(label, 24, 12)
	button:SetAttribute("WbPriceKind", paid and "robux" or "coin")
	if not paid then
		local coin = Instance.new("Frame")
		coin.Name = "Coin"
		coin.BackgroundColor3 = Style.KIT_COLORS.coinFace
		coin.BackgroundTransparency = 0
		coin.BorderSizePixel = 0
		coin.Active = false
		coin.AnchorPoint = Vector2.new(0, 0.5)
		coin.Position = UDim2.new(0, 10, 0.5, 0)
		coin.Size = UDim2.fromOffset(24, 24)
		setCorner(coin, UDim.new(0.5, 0))
		Style.outline(coin, 2)
		coin.Parent = button
		label.Position = UDim2.fromOffset(30, 0)
		label.Size = UDim2.new(1, -36, 1, 0)
	end
	return button
end

-- kitTimerChip(parent, kind, seconds) -> "Timer", or nil for a paid offer: a white pill with a clock and the time
-- left. Update it with setTimer.
function Style.kitTimerChip(parent, kind, seconds)
	if not Style.urgencyAllowed(kind) then
		return nil
	end
	local chip = Instance.new("Frame")
	chip.Name = "Timer"
	chip.BackgroundColor3 = Style.KIT_COLORS.chip
	chip.BackgroundTransparency = 0
	chip.BorderSizePixel = 0
	chip.Active = false
	chip.Size = UDim2.fromOffset(150, 34)
	setCorner(chip, UDim.new(0.5, 0))
	Style.outline(chip, 2)
	local clock = Instance.new("TextLabel")
	clock.Name = "Clock"
	clock.BackgroundTransparency = 1
	clock.Active = false
	clock.Position = UDim2.fromOffset(6, 2)
	clock.Size = UDim2.fromOffset(30, 30)
	clock.Text = Style.CLOCK_ICON
	clock.TextSize = 22
	clock.Font = Style.FONT_TITLE
	clock.Parent = chip
	local left = Instance.new("TextLabel")
	left.Name = "Time"
	left.BackgroundTransparency = 1
	left.Active = false
	left.Position = UDim2.fromOffset(38, 0)
	left.Size = UDim2.new(1, -44, 1, 0)
	left.Text = Style.timerText(seconds)
	left.TextSize = 18
	left.Font = Style.FONT_TITLE
	left.TextColor3 = Style.KIT_COLORS.inkDark
	left.TextXAlignment = Enum.TextXAlignment.Left
	left.Parent = chip
	chip.Parent = parent
	return chip
end

-- setTimer(chip, seconds): the time left on a timer chip.
function Style.setTimer(chip, seconds)
	local left = chip and chip:FindFirstChild("Time")
	if left and left:IsA("TextLabel") then
		left.Text = Style.timerText(seconds)
	end
end

-- kitLock(parent, priceLine) -> "Lock": darkens the whole parent card and shows a padlock with the price words. It is
-- an empty TextButton on top (a topmost button always takes the tap; an Active Frame only keeps taps from the 3D
-- world), so a tap on a locked card does not reach the card's buttons. It does nothing itself.
function Style.kitLock(parent, priceLine)
	local lock = Instance.new("TextButton")
	lock.Name = "Lock"
	lock.Text = ""
	lock.AutoButtonColor = false
	lock.Selectable = false
	lock.BackgroundColor3 = Style.KIT_COLORS.lockShade
	lock.BackgroundTransparency = Style.KIT_SIZES.lockTransparency
	lock.BorderSizePixel = 0
	lock.Active = true
	lock.Size = UDim2.fromScale(1, 1)
	lock.ZIndex = 5
	setCorner(lock, UDim.new(0, Style.KIT_SIZES.cardCorner))
	local icon = Style.kitLabel(lock, "Icon", Style.LOCK_ICON, 34, Style.FONT_TITLE, Style.KIT_SIZES.textStroke)
	icon.Position = UDim2.new(0, 0, 0.5, -40)
	icon.Size = UDim2.new(1, 0, 0, 40)
	icon.ZIndex = 6
	local price = Style.kitLabel(lock, "Price", priceLine or "", 22, Style.FONT_TITLE, Style.KIT_SIZES.textStroke)
	price.Position = UDim2.new(0, 8, 0.5, 2)
	price.Size = UDim2.new(1, -16, 0, 30)
	price.ZIndex = 6
	lock.Parent = parent
	return lock
end

return Style

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

-- Recolours a styled button (a toggle, a cooldown) without touching anything else. A glossy button (Style.gloss,
-- below) takes its tone from the glossy palette, so "grey" and the other glossy names work on it too.
function Style.tint(button, tone)
	if button:GetAttribute("WbGloss") == true then
		button.BackgroundColor3 = Style.glossColor(tone)
	else
		button.BackgroundColor3 = Style.color(tone)
	end
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

-- motion(reduced) -> { spin, pulse, bump }. With "Efectos suaves" (reduced = true) the rays stand still, "¡NUEVO!"
-- does not beat and a counter does not pop when its number changes.
function Style.motion(reduced)
	local soft = reduced == true
	return { spin = not soft, pulse = not soft, bump = not soft }
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

-- ===================================================================================================================
-- The glossy HUD kit (UR-K, owner request 2026-11-20: "quiero que la ui de mi juego sea exactamente igual a la de la
-- foto que te envie"), after the price and category buttons of docs/design/refs/store-ui-reference.png: chunky glossy
-- buttons (a lighter top half, a darker 3D lip along the bottom, a thick dark border, white outlined words, the press
-- squash) in seven tones, a pill counter, a rounded progress bar, a light panel and toast, and a round icon button with
-- a caption for the action bar. Built-in pieces only (Frame, TextLabel, TextButton, UIStroke, UIGradient, UICorner,
-- UIScale, UIPadding, UITextSizeConstraint, emoji text); no remote, no purchase, no uploaded image.
-- The 3D lip is drawn inside the object's own box by its UIGradient (the bottom few pixels darker), not by a second
-- frame beside it: a sibling would be laid out by a UIListLayout, would need to follow every Position, Size and
-- Visible change the scripts make, and would sit outside the rects WildboundHudLayout measures. Because the gradient
-- multiplies the background colour, a script that recolours a glossy object later (a cooldown, low health) keeps the
-- gloss and the lip.
-- Two kinds of helper, like the rest of this file: dress helpers (gloss, glossBar, dressPanel, panelText) take an
-- existing object and never change its Name, Position, Size, Visible, Text, ZIndex or handlers; kit builders
-- (kitGlossButton, kitCounter, kitProgressBar, kitPanel, kitToast, kitIconButton) make new objects and put the root
-- into the parent last. Pure helpers (glossColor, glossSequence, progressFraction, countText, panelLook, motion) are
-- tested in tests/WildboundUiKit_Test.luau (UR-K1..).
-- ===================================================================================================================

-- Glossy tones, read off the reference: green and orange price buttons, the blue, red, yellow and purple category
-- buttons, a grey for a disabled or "off" button, and a dark navy for HUD counters over the world.
Style.GLOSS_TONES = table.freeze({
	green = rgb(64, 208, 72),
	red = rgb(234, 52, 60),
	blue = rgb(44, 150, 244),
	orange = rgb(255, 148, 32),
	purple = rgb(156, 82, 236),
	yellow = rgb(255, 202, 40),
	grey = rgb(138, 150, 172),
	dark = rgb(40, 50, 76),
})

-- Sizes in pixels. iconButton and the glossy button height are tap targets (at least 44); counterHeight and barHeight
-- are not tap targets but stay readable on a phone.
Style.HUD_SIZES = table.freeze({
	lip = 5,
	lipMax = 0.3,
	lipMin = 0.02,
	glossCorner = 12,
	glossStroke = 3,
	glossHeight = 52,
	counterWidth = 160,
	counterHeight = 48,
	counterIcon = 34,
	counterText = 26,
	barWidth = 200,
	barHeight = 26,
	barStroke = 3,
	barText = 16,
	panelStroke = 4,
	panelCorner = 16,
	panelPad = 10,
	toastWidth = 320,
	toastHeight = 56,
	toastText = 20,
	iconButton = 64,
	iconText = 30,
	captionHeight = 20,
	captionGap = 2,
	captionWiden = 28,
	captionText = 16,
	shineTransparency = 0.65,
	dimTransparency = 0.45,
	bumpScale = 1.12,
	bumpSeconds = 0.09,
	countMax = 999999999,
})

-- Suggested emoji for the HUD (built-in text, no upload). Check each in Play on a phone: a missing one shows a box.
Style.ICONS = table.freeze({
	gold = "💰",
	essence = "✨",
	heart = "❤️",
	bolt = "⚡",
	bat = "🏏",
	dodge = "💨",
	light = "🔦",
	pulse = "💥",
	run = "👟",
	egg = "🥚",
	bag = "🎒",
	star = "⭐",
})

local HUD = Style.HUD_SIZES

-- glossColor(tone) -> Color3. A glossy tone name, else a KIT_COLORS or COLORS name, else grey; a Color3 is kept.
function Style.glossColor(tone)
	if typeof(tone) == "Color3" then
		return tone
	end
	return Style.GLOSS_TONES[tone] or Style.KIT_COLORS[tone] or Style.COLORS[tone] or Style.GLOSS_TONES.grey
end

local function grey(value)
	return Color3.new(value, value, value)
end

-- glossSequence(height, lip) -> the ColorSequence of a glossy object's UIGradient (Rotation 90, so time 0 is the top):
-- the top half at full colour, the lower half a little darker, and the bottom lip pixels clearly darker (the 3D edge).
-- height is the object's height in pixels (a bad one counts as glossHeight); the lip stays between lipMin and lipMax of
-- the height.
function Style.glossSequence(height, lip)
	local tall = tonumber(height)
	if tall == nil or tall ~= tall or tall <= 0 or tall == math.huge then
		tall = HUD.glossHeight
	end
	local edge = tonumber(lip)
	if edge == nil or edge ~= edge then
		edge = HUD.lip
	end
	local share = math.clamp(edge / tall, HUD.lipMin, HUD.lipMax)
	local start = 1 - share
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, grey(1)),
		ColorSequenceKeypoint.new(0.46, grey(1)),
		ColorSequenceKeypoint.new(0.54, grey(0.86)),
		ColorSequenceKeypoint.new(start - 0.001, grey(0.82)),
		ColorSequenceKeypoint.new(start, grey(0.58)),
		ColorSequenceKeypoint.new(1, grey(0.58)),
	})
end

local function glossHeight(item)
	local shown = item.AbsoluteSize.Y
	if shown > 0 then
		return shown
	end
	if item.Size.Y.Offset > 0 and item.Size.Y.Scale == 0 then
		return item.Size.Y.Offset
	end
	return HUD.glossHeight
end

local function refreshGloss(item)
	local gradient = item:FindFirstChild("WbShade")
	if gradient and gradient:IsA("UIGradient") then
		gradient.Color = Style.glossSequence(glossHeight(item), HUD.lip)
		gradient.Rotation = 90
	end
end

-- Keeps a kit "Label" (or a glyph) above the lip, so the words sit in the middle of the lit face.
local function liftLabel(label)
	if label.Size.Y.Scale == 1 and label.Size.Y.Offset == 0 then
		label.Size = UDim2.new(label.Size.X.Scale, label.Size.X.Offset, 1, -HUD.lip)
	end
end

local glossed = setmetatable({}, { __mode = "k" })

-- gloss(item, tone) -> item. Dresses an existing GuiObject (a script's own button, chip or pill) as a glossy chunky
-- button: the tone (nil keeps its colour), a 12 px corner unless it already has one (a round button stays round), a
-- thick dark border, the gloss and lip gradient (it follows the object's size), the press squash on a button, and
-- white outlined words: a kit "Label" is lifted above the lip, a button's own Text gets the display font and outline.
-- Do not gloss an object that carries a UIGradient of its own: one object shows one gradient.
function Style.gloss(item, tone)
	if tone ~= nil then
		item.BackgroundColor3 = Style.glossColor(tone)
	end
	item.BackgroundTransparency = 0
	item.BorderSizePixel = 0
	if item:FindFirstChildOfClass("UICorner") == nil then
		setCorner(item, UDim.new(0, HUD.glossCorner))
	end
	Style.outline(item, HUD.glossStroke)
	child(item, "UIGradient", "WbShade")
	item:SetAttribute("WbGloss", true)
	refreshGloss(item)
	if not glossed[item] then
		glossed[item] = true
		item:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			refreshGloss(item)
		end)
	end
	local label = item:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		liftLabel(label)
	elseif item:IsA("TextButton") or item:IsA("TextLabel") then
		Style.title(item)
	end
	if item:IsA("GuiButton") then
		Style.press(item)
	end
	return item
end

-- kitGlossButton(parent, text, tone, name) -> button, label. kitButton in the glossy look: words on the child "Label"
-- (Style.setLabel), at least 44 x 44, recolour with Style.tint (glossy names work).
function Style.kitGlossButton(parent, text, tone, name)
	local button, label = Style.kitButton(nil, text, tone or "green", name or "Button")
	Style.gloss(button, tone or "green")
	button.Parent = parent
	return button, label
end

-- countText(value) -> a whole number with Spanish dots: 1250 -> "1.250"; never negative, at most 999.999.999.
function Style.countText(value)
	local digits = tostring(whole(value, HUD.countMax))
	local grouped = string.reverse((string.gsub(string.reverse(digits), "(%d%d%d)", "%1.")))
	if string.sub(grouped, 1, 1) == "." then
		grouped = string.sub(grouped, 2)
	end
	return grouped
end

-- kitCounter(parent, icon, text, tone, name) -> counter, value. A round glossy pill (dark navy unless a tone is given)
-- with an emoji "Icon" on the left and the outlined "Value" words, shrinking to fit. Not a button.
function Style.kitCounter(parent, icon, text, tone, name)
	local counter = Instance.new("Frame")
	counter.Name = name or "Counter"
	counter.Active = false
	counter.Size = UDim2.fromOffset(HUD.counterWidth, HUD.counterHeight)
	setCorner(counter, UDim.new(0.5, 0))
	Style.gloss(counter, tone or "dark")
	local glyph = Instance.new("TextLabel")
	glyph.Name = "Icon"
	glyph.BackgroundTransparency = 1
	glyph.BorderSizePixel = 0
	glyph.Active = false
	glyph.AnchorPoint = Vector2.new(0, 0.5)
	glyph.Position = UDim2.new(0, 8, 0.5, -math.floor(HUD.lip / 2))
	glyph.Size = UDim2.fromOffset(HUD.counterIcon, HUD.counterIcon)
	glyph.Text = icon or ""
	glyph.TextSize = 28
	glyph.Font = Style.FONT_TITLE
	glyph.TextColor3 = Style.COLORS.ink
	glyph.Parent = counter
	local value = Style.kitLabel(counter, "Value", text, HUD.counterText, Style.FONT_TITLE, Style.KIT_SIZES.textStroke)
	value.Position = UDim2.fromOffset(HUD.counterIcon + 10, 0)
	value.Size = UDim2.new(1, -(HUD.counterIcon + 22), 1, -HUD.lip)
	Style.fitText(value, HUD.counterText, 12)
	counter.Parent = parent
	return counter, value
end

-- setCounter(counter, text): the words of a counter (or of a kit button, through its Label).
function Style.setCounter(counter, text)
	local value = counter and (counter:FindFirstChild("Value") or counter:FindFirstChild("Label"))
	if value and value:IsA("TextLabel") then
		value.Text = text
	end
end

local bumps = setmetatable({}, { __mode = "k" })

-- bump(item, reduced) -> whether it popped: a quick grow and back (a counter that just changed), never with
-- "Efectos suaves". Reuses the object's own UIScale when it has one.
function Style.bump(item, reduced)
	if not Style.motion(reduced).bump then
		return false
	end
	local scale = item:FindFirstChildOfClass("UIScale") or child(item, "UIScale", "WbBump")
	local running = bumps[item]
	if running then
		running:Cancel()
	end
	scale.Scale = 1
	local info = TweenInfo.new(HUD.bumpSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
	local tween = TweenService:Create(scale, info, { Scale = HUD.bumpScale })
	bumps[item] = tween
	tween:Play()
	return true
end

-- progressFraction(value, max) -> value / max between 0 and 1; a bad number or a max of 0 gives 0. max defaults to 1.
function Style.progressFraction(value, max)
	local amount = tonumber(value)
	local top = max == nil and 1 or tonumber(max)
	if amount == nil or top == nil or amount ~= amount or top ~= top or top <= 0 or top == math.huge then
		return 0
	end
	local share = amount / top
	if share ~= share then
		return 0
	end
	return math.clamp(share, 0, 1)
end

-- A bar fill: lit top, darker bottom.
local FILL_SHINE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, grey(1)),
	ColorSequenceKeypoint.new(0.5, grey(1)),
	ColorSequenceKeypoint.new(0.56, grey(0.84)),
	ColorSequenceKeypoint.new(1, grey(0.72)),
})
Style.FILL_SHINE = FILL_SHINE

-- The fill of a bar: rounded, a tone (nil keeps the script's colour, so its warning recolour still shows) with a lit
-- top, or "rainbow" (the Aliento look), and a soft white "WbShine" streak across its upper part.
local function dressFill(fill, tone)
	local rainbow = tone == "rainbow"
	local drop = fill:FindFirstChild(rainbow and "WbShade" or "WbRainbow")
	if drop and drop:IsA("UIGradient") then
		drop:Destroy()
	end
	local gradient = child(fill, "UIGradient", rainbow and "WbRainbow" or "WbShade")
	if rainbow then
		fill.BackgroundColor3 = Color3.new(1, 1, 1)
		gradient.Color = RAINBOW
		gradient.Rotation = 0
	else
		if tone ~= nil then
			fill.BackgroundColor3 = Style.glossColor(tone)
		end
		gradient.Color = FILL_SHINE
		gradient.Rotation = 90
	end
	fill.BackgroundTransparency = 0
	fill.BorderSizePixel = 0
	setCorner(fill, UDim.new(0.5, 0))
	local shine = child(fill, "Frame", "WbShine")
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = HUD.shineTransparency
	shine.BorderSizePixel = 0
	shine.Active = false
	shine.Position = UDim2.new(0, 4, 0.14, 0)
	shine.Size = UDim2.new(1, -8, 0.3, 0)
	setCorner(shine, UDim.new(0.5, 0))
	return fill
end

-- glossBar(track, fill, tone) -> track. Dresses an existing bar: a dark round track with a thick border and, when
-- fill is given, the glossy rounded fill (tone as dressFill above; nil keeps the fill's colour).
function Style.glossBar(track, fill, tone)
	track.BackgroundColor3 = Style.COLORS.panelDeep
	track.BackgroundTransparency = 0
	track.BorderSizePixel = 0
	setCorner(track, UDim.new(0.5, 0))
	Style.outline(track, HUD.barStroke)
	if fill then
		dressFill(fill, tone)
	end
	return track
end

-- kitProgressBar(parent, text, tone, name) -> track, fill, label. A new rounded bar ("Fill" inside, full to start)
-- with the outlined "Text" words centred over it. tone: a glossy name or "rainbow"; default green.
function Style.kitProgressBar(parent, text, tone, name)
	local track = Instance.new("Frame")
	track.Name = name or "Bar"
	track.Active = false
	track.Size = UDim2.fromOffset(HUD.barWidth, HUD.barHeight)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Active = false
	fill.Size = UDim2.fromScale(1, 1)
	fill.ZIndex = 1
	fill.Parent = track
	Style.glossBar(track, fill, tone or "green")
	local label = Style.kitLabel(track, "Text", text, HUD.barText, Style.FONT_TITLE, Style.KIT_SIZES.textStroke)
	label.ZIndex = 2
	Style.fitText(label, HUD.barText, 10)
	track.Parent = parent
	return track, fill, label
end

-- setProgress(track, value, max, text) -> the fraction shown. Sizes the track's "Fill" (hidden at 0, where a rounded
-- sliver would look like a dot) and, when text is given, sets the "Text" words.
function Style.setProgress(track, value, max, text)
	local share = Style.progressFraction(value, max)
	local fill = track and track:FindFirstChild("Fill")
	if fill and fill:IsA("GuiObject") then
		fill.Size = UDim2.new(share, 0, 1, 0)
		fill.Visible = share > 0
	end
	if text ~= nil then
		local label = track and track:FindFirstChild("Text")
		if label and label:IsA("TextLabel") then
			label.Text = text
		end
	end
	return share
end

-- Panel looks: "light" (the reference's pale inner panel, dark words), "dark" (navy, for HUD panels over the world,
-- white words) and "blue" (the reference's window frame).
local PANEL_LOOKS = table.freeze({
	light = table.freeze({ fill = Style.KIT_COLORS.inner, edge = Style.KIT_COLORS.frameOutline, shade = 0.94 }),
	dark = table.freeze({ fill = Style.COLORS.panelDeep, edge = Style.COLORS.outline, shade = 0.82 }),
	blue = table.freeze({ fill = Style.KIT_COLORS.frame, edge = Style.KIT_COLORS.frameOutline, shade = 0.8 }),
})
Style.PANEL_LOOKS = PANEL_LOOKS

-- panelLook(variant) -> { fill, edge, shade }. An unknown variant is light.
function Style.panelLook(variant)
	return PANEL_LOOKS[variant] or PANEL_LOOKS.light
end

-- dressPanel(frame, variant, transparency) -> frame. A rounded panel with a thick dark border; adds no padding, so the
-- script's own layout stays where it was.
function Style.dressPanel(frame, variant, transparency)
	local look = Style.panelLook(variant)
	frame.BackgroundColor3 = look.fill
	frame.BackgroundTransparency = transparency or 0
	frame.BorderSizePixel = 0
	Style.corner(frame, HUD.panelCorner)
	Style.outline(frame, HUD.panelStroke, look.edge)
	Style.shade(frame, look.shade)
	frame:SetAttribute("WbPanel", PANEL_LOOKS[variant] and variant or "light")
	return frame
end

-- panelText(label) -> label: dark round words for a light panel (no outline, which would blur on a pale fill).
function Style.panelText(label)
	label.Font = Style.FONT_TITLE
	label.TextColor3 = Style.KIT_COLORS.inkDark
	label.TextStrokeTransparency = 1
	local stroke = label:FindFirstChild("WbTextStroke")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Transparency = 1
	end
	return label
end

-- kitPanel(parent, name, variant) -> panel. A new panel (dressPanel) with 10 px padding inside.
function Style.kitPanel(parent, name, variant)
	local panel = Instance.new("Frame")
	panel.Name = name or "Panel"
	panel.Active = false
	Style.dressPanel(panel, variant)
	local pad = child(panel, "UIPadding", "WbPad")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, HUD.panelPad), UDim.new(0, HUD.panelPad)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, HUD.panelPad), UDim.new(0, HUD.panelPad)
	panel.Parent = parent
	return panel
end

-- kitToast(parent, text, name) -> toast, label. A light panel (320 x 56 to start) with dark round words that shrink
-- to fit.
function Style.kitToast(parent, text, name)
	local toast = Style.kitPanel(nil, name or "Toast", "light")
	toast.Size = UDim2.fromOffset(HUD.toastWidth, HUD.toastHeight)
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Active = false
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text or ""
	label.TextSize = HUD.toastText
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	Style.panelText(label)
	Style.fitText(label, HUD.toastText, 12)
	label.Parent = toast
	toast.Parent = parent
	return toast, label
end

-- kitIconButton(parent, icon, caption, tone, name) -> button, glyph, caption. A round glossy button (64 px, never under
-- 44) with an emoji in its "Label" and an outlined "Caption" under it, outside the button (captionGap + captionHeight
-- pixels below; leave that room in the layout). Change the icon with Style.setLabel and the caption with
-- Style.setCaption; Style.setDimmed shades it while it cannot be used.
function Style.kitIconButton(parent, icon, caption, tone, name)
	local size = Style.tapSize(HUD.iconButton)
	local button, glyph = Style.kitGlossButton(nil, icon, tone or "blue", name or "IconButton")
	button.Size = UDim2.fromOffset(size, size)
	setCorner(button, UDim.new(0.5, 0))
	refreshGloss(button)
	glyph.TextSize = HUD.iconText
	local words = Style.kitLabel(button, "Caption", caption, HUD.captionText, Style.FONT_TITLE, Style.KIT_SIZES.textStroke)
	words.AnchorPoint = Vector2.new(0.5, 0)
	words.Position = UDim2.new(0.5, 0, 1, HUD.captionGap)
	words.Size = UDim2.new(1, HUD.captionWiden, 0, HUD.captionHeight)
	Style.fitText(words, HUD.captionText, 10)
	words.TextWrapped = false
	button.Parent = parent
	return button, glyph, words
end

-- setCaption(button, text): the words under an icon button.
function Style.setCaption(button, text)
	local words = button and button:FindFirstChild("Caption")
	if words and words:IsA("TextLabel") then
		words.Text = text
	end
end

-- setDimmed(button, on) -> on. A dark round "WbDim" cover over the button (and its icon) while it cannot be used; it
-- does not take taps or change Active, so the script still decides what a tap does.
function Style.setDimmed(button, on)
	local dim = child(button, "Frame", "WbDim")
	dim.BackgroundColor3 = Style.KIT_COLORS.lockShade
	dim.BackgroundTransparency = HUD.dimTransparency
	dim.BorderSizePixel = 0
	dim.Active = false
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = 2
	local corner = button:FindFirstChildOfClass("UICorner")
	setCorner(dim, corner and corner.CornerRadius or UDim.new(0, HUD.glossCorner))
	local shown = on == true
	dim.Visible = shown
	button:SetAttribute("WbDimmed", shown)
	return shown
end

return Style

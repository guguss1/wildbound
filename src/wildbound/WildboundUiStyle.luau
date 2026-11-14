-- Wildbound UI style, the "colorida" pass (odd/tasks/wildbound-ui-colorida.md): one palette and a few helpers that
-- dress the GUI objects the client scripts already build, in the bright, chunky, outlined look of Roblox simulator
-- games. Presentation only: no remotes, no purchases, no prices, no uploaded assets (only UIStroke, UIGradient,
-- UICorner, UIScale and built-in fonts).
-- Contract: every helper takes an existing GuiObject and adds or reuses named children (WbOutline, WbShade, WbCorner,
-- WbHeader, WbStripes, WbPress). None changes Name, Position, Size, Visible, Text, ZIndex or any handler, so each
-- script's layout (WildboundHudLayout, WildboundCampView, WildboundStartView) and behaviour stay as they were.
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

return Style

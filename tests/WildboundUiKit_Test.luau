-- Invoke with require(freshTestClone)(require(freshStyleClone), WildboundUiStyle.Source).
-- P0.1 (docs/design/wildbound-fun-build-plan.md, owner request 2026-11-20: "Quiero que la estetica sea asi de la ui,
-- con esa tipografia"): the store kit in WildboundUiStyle, after docs/design/refs/store-ui-reference.png. Pins the pure
-- parts (colours, sizes, fonts, price and timer words, the Robux sign and its "R$" fallback, the motion rule for
-- "Efectos suaves", the no-hurry rule for paid offers) and every builder (classes, names, fonts, strokes, tap sizes),
-- and that the module never names a purchase service, a remote or an uploaded image. Builders only parent into a
-- parentless ScreenGui made here, destroyed at the end of each case.
return function(Style, source)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function near(actual, expected, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= 1e-6,
			(label and label .. ": " or "") .. "expected about " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function scratch()
		local gui = Instance.new("ScreenGui")
		gui.Name = "WbUiKitScratch"
		return gui
	end
	local function strokeOf(item, mode)
		for _, candidate in ipairs(item:GetChildren()) do
			if candidate:IsA("UIStroke") and candidate.ApplyStrokeMode == mode then return candidate end
		end
		return nil
	end
	local function strokeCount(item)
		local count = 0
		for _, candidate in ipairs(item:GetChildren()) do
			if candidate:IsA("UIStroke") then count += 1 end
		end
		return count
	end
	local function tapMin(button)
		local limit = button:FindFirstChild("WbTapMin")
		assert(limit and limit:IsA("UISizeConstraint"), button.Name .. ": no tap size limit")
		return limit.MinSize
	end
	source = type(source) == "string" and source or ""
	local GLYPH = utf8.char(0xE002)

	case("K1: the kit tables are frozen; every tap target is at least 44 px; the title outline is thick", function()
		assert(type(Style.KIT_COLORS) == "table" and table.isfrozen(Style.KIT_COLORS), "KIT_COLORS frozen")
		assert(type(Style.KIT_SIZES) == "table" and table.isfrozen(Style.KIT_SIZES), "KIT_SIZES frozen")
		local sizes = Style.KIT_SIZES
		equal(sizes.minTap, 44, "minTap")
		for _, key in ipairs({ "close", "category", "priceHeight", "buttonHeight" }) do
			assert(sizes[key] >= 44, key .. " is under 44 px")
		end
		assert(sizes.titleStroke >= 3, "title outline thick")
		assert(sizes.textStroke >= 2, "text outline thick")
		assert(sizes.frameStroke >= 4, "window border thick")
		for _, key in ipairs({ "frame", "frameOutline", "inner", "inkDark", "coin", "coinFace", "robux", "close", "badge",
			"chip", "lockShade" }) do
			assert(typeof(Style.KIT_COLORS[key]) == "Color3", "colour " .. key)
		end
		local blue = Style.KIT_COLORS.frame
		assert(blue.B > blue.R and blue.B > blue.G, "the window is blue")
		local red = Style.KIT_COLORS.close
		assert(red.R > red.G and red.R > red.B, "the X is red")
		local green = Style.KIT_COLORS.robux
		assert(green.G > green.R and green.G > green.B, "the Robux price is green")
		local orange = Style.KIT_COLORS.coin
		assert(orange.R > orange.G and orange.G > orange.B, "the coin price is orange")
	end)

	case("K2: fonts: FredokaOne for titles, LuckiestGuy for the loud words; the older helpers are still there", function()
		equal(Style.FONT_TITLE, Enum.Font.FredokaOne, "FONT_TITLE")
		equal(Style.FONT_LOUD, Enum.Font.LuckiestGuy, "FONT_LOUD")
		equal(Style.FONT, Enum.Font.FredokaOne, "FONT unchanged")
		for _, name in ipairs({ "screen", "corner", "outline", "shade", "title", "body", "press", "button", "tint", "panel",
			"pill", "card", "header", "bar" }) do
			assert(type(Style[name]) == "function", "the older helper " .. name .. " is gone")
		end
	end)

	case("K3: tapSize never goes under 44", function()
		equal(Style.tapSize(20), 44, "20")
		equal(Style.tapSize(44), 44, "44")
		equal(Style.tapSize(60), 60, "60")
		equal(Style.tapSize(nil), 44, "nil")
		equal(Style.tapSize(0 / 0), 44, "nan")
	end)

	case("K4: card gradients: cyan, magenta and yellow, each its own pair; an unknown tone is cyan", function()
		local seen = {}
		for _, tone in ipairs({ "cyan", "magenta", "yellow" }) do
			local from, to = Style.cardColors(tone)
			assert(typeof(from) == "Color3" and typeof(to) == "Color3", tone)
			assert(from ~= to, tone .. " is a gradient")
			local key = tostring(from)
			assert(not seen[key], tone .. " repeats another tone")
			seen[key] = true
			local sequence = Style.cardGradient(tone)
			equal(typeof(sequence), "ColorSequence", tone .. " sequence")
			equal(#sequence.Keypoints, 2, tone .. " keypoints")
			equal(sequence.Keypoints[1].Value, from, tone .. " start")
			equal(sequence.Keypoints[2].Value, to, tone .. " end")
		end
		local cyanFrom = Style.cardColors("cyan")
		equal(Style.cardColors("nope"), cyanFrom, "unknown tone")
		local c = Style.cardColors("cyan")
		assert(c.B > c.R, "cyan is blue-green")
		local y = Style.cardColors("yellow")
		assert(y.R > y.B and y.G > y.B, "yellow is yellow")
	end)

	case("K5: price words: the coin number, the Robux sign U+E002, and R$ when the sign is turned off", function()
		equal(Style.ROBUX_GLYPH, GLYPH, "ROBUX_GLYPH")
		equal(utf8.codepoint(Style.ROBUX_GLYPH), 0xE002, "the private-use letter")
		equal(Style.ROBUX_FALLBACK, "R$", "fallback")
		equal(Style.priceText("coin", 799), "799", "coin")
		equal(Style.priceText("robux", 199), GLYPH .. " 199", "robux")
		equal(Style.priceText("robux", 199, true), GLYPH .. " 199", "robux with the sign")
		equal(Style.priceText("robux", 199, false), "R$ 199", "robux fallback")
		equal(Style.priceText("coin", -5), "0", "never negative")
		equal(Style.priceText("coin", 12.7), "12", "whole numbers")
		equal(Style.priceText("coin", 0 / 0), "0", "nan")
		equal(Style.priceText("coin", nil), "0", "nil")
		equal(Style.priceText("coin", math.huge), "999999", "capped")
	end)

	case("K6: timer words like the reference (24h30m43s), never negative, capped at 99h59m59s", function()
		equal(Style.timerText(24 * 3600 + 30 * 60 + 43), "24h30m43s", "hours")
		equal(Style.timerText(3600), "1h00m00s", "one hour")
		equal(Style.timerText(125), "2m05s", "minutes")
		equal(Style.timerText(7), "7s", "seconds")
		equal(Style.timerText(0), "0s", "zero")
		equal(Style.timerText(-5), "0s", "negative")
		equal(Style.timerText(nil), "0s", "nil")
		equal(Style.timerText(0 / 0), "0s", "nan")
		equal(Style.timerText(math.huge), "99h59m59s", "capped")
		equal(Style.timerText(59.9), "59s", "rounded down")
	end)

	case("K7: motion: Efectos suaves stops the rays and the beat; reduced() reads the world gui like the other clients", function()
		local soft = Style.motion(true)
		equal(soft.spin, false, "reduced spin")
		equal(soft.pulse, false, "reduced pulse")
		local full = Style.motion(false)
		equal(full.spin, true, "full spin")
		equal(full.pulse, true, "full pulse")
		equal(Style.motion(nil).spin, true, "nil is not reduced")
		local playerGui = Instance.new("Folder")
		equal(Style.reduced(playerGui), true, "no world gui yet: reduced")
		equal(Style.reduced(nil), true, "no PlayerGui: reduced")
		local world = Instance.new("ScreenGui")
		world.Name = "WildboundWorldUI"
		world.Parent = playerGui
		equal(Style.reduced(playerGui), true, "attribute missing: reduced")
		world:SetAttribute("Reduced", false)
		equal(Style.reduced(playerGui), false, "Reduced false")
		world:SetAttribute("Reduced", true)
		equal(Style.reduced(playerGui), true, "Reduced true")
		playerGui:Destroy()
	end)

	case("K8: no hurry on paid offers: NEW and the timer only on free things; isWide and the ray angles", function()
		equal(Style.urgencyAllowed("robux"), false, "robux")
		equal(Style.urgencyAllowed("coin"), true, "coin")
		equal(Style.urgencyAllowed("free"), true, "free")
		equal(Style.isWide(Style.KIT_SIZES.wideWidth - 1), false, "narrow")
		equal(Style.isWide(Style.KIT_SIZES.wideWidth), true, "wide")
		equal(Style.isWide(nil), false, "nil")
		local angles = Style.rayAngles(12)
		equal(#angles, 12, "12 bars")
		near(angles[1], 0, "first")
		near(angles[2], 15, "step")
		for _, angle in ipairs(angles) do assert(angle >= 0 and angle < 180, "angle " .. angle) end
		equal(#Style.rayAngles(0), 1, "at least one bar")
	end)

	case("K9: kitWindow: a blue rounded frame with a thick dark border and a light padded panel under the header", function()
		local gui = scratch()
		local window, inner = Style.kitWindow(gui, "Shop", 60)
		equal(window.ClassName, "Frame", "window class")
		equal(window.Name, "Shop", "name")
		equal(window.Parent, gui, "parent")
		equal(window.BackgroundColor3, Style.KIT_COLORS.frame, "blue")
		local border = strokeOf(window, Enum.ApplyStrokeMode.Border)
		assert(border, "window border")
		equal(border.Thickness, Style.KIT_SIZES.frameStroke, "border thickness")
		equal(border.Color, Style.KIT_COLORS.frameOutline, "border colour")
		local corner = window:FindFirstChildOfClass("UICorner")
		assert(corner, "window corner")
		equal(corner.CornerRadius.Offset, Style.KIT_SIZES.frameCorner, "window corner radius")
		equal(inner.Name, "Inner", "inner name")
		equal(inner.Parent, window, "inner parent")
		equal(inner.BackgroundColor3, Style.KIT_COLORS.inner, "light panel")
		equal(inner.Position.Y.Offset, 60, "under the header")
		assert(inner:FindFirstChildOfClass("UICorner"), "inner corner")
		assert(inner:FindFirstChildOfClass("UIPadding"), "inner padding")
		gui:Destroy()
	end)

	case("K10: kitTitle: FredokaOne, white, a Contextual UIStroke of at least 3 px, old TextStroke off, fits a phone", function()
		local gui = scratch()
		local title = Style.kitTitle(gui, "¡Tienda!", 30)
		equal(title.ClassName, "TextLabel", "class")
		equal(title.Name, "Title", "name")
		equal(title.Text, "¡Tienda!", "text")
		equal(title.Font, Enum.Font.FredokaOne, "font")
		equal(title.TextColor3, Style.COLORS.ink, "white")
		equal(title.TextStrokeTransparency, 1, "the thin TextStroke is replaced")
		local stroke = strokeOf(title, Enum.ApplyStrokeMode.Contextual)
		assert(stroke, "text outline")
		assert(stroke.Thickness >= 3, "thick outline")
		equal(stroke.Color, Style.COLORS.outline, "dark outline")
		equal(strokeCount(title), 1, "one stroke on the label")
		equal(title.TextScaled, true, "shrinks to fit")
		equal(title:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize, 30, "never over 30")
		gui:Destroy()
	end)

	case("K11: kitButton: chunky, Border stroke on the button, outlined words on a child Label, 44 px minimum", function()
		local gui = scratch()
		local button, label = Style.kitButton(gui, "Girar", "green", "Spin")
		equal(button.ClassName, "TextButton", "class")
		equal(button.Name, "Spin", "name")
		equal(button.Text, "", "the words live on the Label")
		equal(button.AutoButtonColor, false, "AutoButtonColor")
		equal(button.BackgroundColor3, Style.COLORS.green, "tone")
		local border = strokeOf(button, Enum.ApplyStrokeMode.Border)
		assert(border and border.Thickness >= 3, "thick border")
		equal(strokeCount(button), 1, "one stroke on the button")
		equal(label.Name, "Label", "label name")
		equal(label.Parent, button, "label parent")
		equal(label.Text, "Girar", "label text")
		equal(label.Active, false, "taps go to the button")
		equal(label.Font, Enum.Font.FredokaOne, "label font")
		assert(strokeOf(label, Enum.ApplyStrokeMode.Contextual), "label outline")
		equal(tapMin(button), Vector2.new(44, 44), "tap minimum")
		assert(button.Size.Y.Offset >= 44, "default height")
		Style.setLabel(button, "Girando...")
		equal(label.Text, "Girando...", "setLabel")
		local plain = Instance.new("TextButton")
		Style.setLabel(plain, "x")
		equal(plain.Text, "x", "setLabel on a plain button")
		plain:Destroy()
		Style.tint(button, "off")
		equal(button.BackgroundColor3, Style.COLORS.off, "tint still works")
		gui:Destroy()
	end)

	case("K12: kitClose is a big red X in LuckiestGuy; kitCategoryButton is round and 52 px", function()
		local gui = scratch()
		local close = Style.kitClose(gui)
		equal(close.Name, "CloseX", "name")
		equal(close.ClassName, "TextButton", "class")
		equal(close.BackgroundColor3, Style.KIT_COLORS.close, "red")
		assert(close.Size.X.Offset >= 48 and close.Size.Y.Offset >= 48, "48 px")
		local x = close:FindFirstChild("Label")
		equal(x.Text, "X", "the X")
		equal(x.Font, Enum.Font.LuckiestGuy, "X font")
		equal(close.AnchorPoint, Vector2.new(1, 0), "top right")
		local category = Style.kitCategoryButton(gui, "🥚", "sky")
		equal(category.Name, "Category", "category name")
		equal(category.Size.X.Offset, 52, "category width")
		equal(category.Size.Y.Offset, 52, "category height")
		equal(category:FindFirstChildOfClass("UICorner").CornerRadius.Scale, 0.5, "round")
		equal(category:FindFirstChild("Label").Text, "🥚", "icon")
		equal(tapMin(category), Vector2.new(44, 44), "category tap minimum")
		gui:Destroy()
	end)

	case("K13: kitCard: the tone gradient, faint clipped sunburst rays under the content, turning unless reduced", function()
		local gui = scratch()
		local card = Style.kitCard(gui, "magenta", false, "Offer")
		equal(card.ClassName, "Frame", "class")
		equal(card.Name, "Offer", "name")
		equal(card.Parent, gui, "parent")
		local tint = card:FindFirstChild("WbCardTone")
		assert(tint and tint:IsA("UIGradient"), "tone gradient")
		local from, to = Style.cardColors("magenta")
		equal(tint.Color.Keypoints[1].Value, from, "gradient start")
		equal(tint.Color.Keypoints[2].Value, to, "gradient end")
		equal(card:GetAttribute("WbTone"), "magenta", "tone attribute")
		local rays = card:FindFirstChild("Rays")
		assert(rays and rays.ClassName == "Frame" and rays.ClipsDescendants, "the rays are clipped to the card")
		equal(rays.ZIndex, 0, "rays under the content")
		local inset = Style.KIT_SIZES.rayInset
		assert(type(inset) == "number" and inset >= 5, "the clip stays inside the rounded corners")
		equal(rays.Position, UDim2.fromOffset(inset, inset), "rays inset")
		equal(rays.Size, UDim2.new(1, -2 * inset, 1, -2 * inset), "rays inset size")
		local middle, faintest = 0, 1
		for _, point in ipairs(Style.RAY_FADE.Keypoints) do
			if point.Time >= 0.45 and point.Time <= 0.55 then
				middle += 1
				equal(point.Value, 1, "the centre of every bar is clear")
			end
			faintest = math.min(faintest, point.Value)
		end
		assert(middle >= 2, "the clear middle is pinned at both sides")
		assert(faintest >= 0.8, "the rays stay faint")
		local burst = rays:FindFirstChild("Burst")
		assert(burst, "burst")
		local count = 0
		for _, ray in ipairs(burst:GetChildren()) do
			if ray:IsA("Frame") then
				count += 1
				local fade = ray:FindFirstChildOfClass("UIGradient")
				assert(fade, ray.Name .. " fades")
				equal(#fade.Transparency.Keypoints, #Style.RAY_FADE.Keypoints, ray.Name .. " fade")
			end
		end
		equal(count, Style.KIT_SIZES.rays, "ray bars")
		near(burst:FindFirstChild("Ray2").Rotation, 180 / Style.KIT_SIZES.rays, "second ray angle")
		equal(card:GetAttribute("WbSpin"), true, "turning")
		equal(Style.setSpin(card, false), false, "stopped")
		equal(card:GetAttribute("WbSpin"), false, "stopped attribute")
		equal(Style.setSpin(card, true), true, "turning again")
		local soft = Style.kitCard(gui, "yellow", true)
		equal(soft.Name, "Card", "default name")
		equal(soft:GetAttribute("WbSpin"), false, "Efectos suaves: still rays")
		local odd = Style.kitCard(gui, "plaid", true)
		equal(odd:GetAttribute("WbTone"), "cyan", "unknown tone is cyan")
		Style.setSpin(card, false)
		gui:Destroy()
	end)

	case("K14: NEW is red, tilted, LuckiestGuy, only on free things, and beats only without Efectos suaves", function()
		local gui = scratch()
		equal(Style.kitNewBadge(gui, "robux", false), nil, "never on a paid offer")
		equal(#gui:GetChildren(), 0, "nothing built for a paid offer")
		local badge = Style.kitNewBadge(gui, "coin", false)
		equal(badge.Name, "NewBadge", "name")
		equal(badge.ClassName, "TextLabel", "class")
		equal(badge.Text, Style.NEW_TEXT, "text")
		equal(Style.NEW_TEXT, "¡NUEVO!", "Spanish")
		equal(badge.Font, Enum.Font.LuckiestGuy, "font")
		equal(badge.TextColor3, Style.KIT_COLORS.badge, "red")
		assert(badge.Rotation < 0, "tilted")
		assert(strokeOf(badge, Enum.ApplyStrokeMode.Contextual), "outlined")
		equal(badge:GetAttribute("WbPulse"), true, "beats")
		local still = Style.kitNewBadge(gui, "free", true)
		equal(still:GetAttribute("WbPulse"), false, "Efectos suaves: no beat")
		equal(Style.setPulse(badge, false), false, "the beat stops")
		equal(badge:GetAttribute("WbPulse"), false, "stopped attribute")
		equal(badge:FindFirstChild("WbPulse").Scale, 1, "back to full size")
		equal(Style.setPulse(still, true), true, "beats again")
		Style.setPulse(still, false)
		gui:Destroy()
	end)

	case("K15: price buttons: orange with a drawn coin, green with the Robux sign or R$, 44 px minimum, no call", function()
		local gui = scratch()
		local coin = Style.kitPriceButton(gui, "coin", 799)
		equal(coin.Name, "Price", "name")
		equal(coin.ClassName, "TextButton", "class")
		equal(coin.BackgroundColor3, Style.KIT_COLORS.coin, "orange")
		equal(coin:FindFirstChild("Label").Text, "799", "coin words")
		local fit = coin:FindFirstChild("Label"):FindFirstChildOfClass("UITextSizeConstraint")
		assert(fit, "a long price shrinks to fit the button")
		equal(fit.MaxTextSize, 24, "never over 24")
		local face = coin:FindFirstChild("Coin")
		assert(face and face:IsA("Frame"), "a drawn coin")
		equal(face.BackgroundColor3, Style.KIT_COLORS.coinFace, "coin face")
		equal(coin:GetAttribute("WbPriceKind"), "coin", "kind")
		assert(coin.Size.Y.Offset >= 44, "height")
		equal(tapMin(coin), Vector2.new(44, 44), "tap minimum")
		local paid = Style.kitPriceButton(gui, "robux", 199)
		equal(paid.BackgroundColor3, Style.KIT_COLORS.robux, "green")
		equal(paid:FindFirstChild("Label").Text, GLYPH .. " 199", "the Robux sign")
		equal(paid:FindFirstChild("Coin"), nil, "no coin on the green one")
		equal(paid:GetAttribute("WbPriceKind"), "robux", "kind")
		local fallback = Style.kitPriceButton(gui, "robux", 25, false)
		equal(fallback:FindFirstChild("Label").Text, "R$ 25", "fallback")
		gui:Destroy()
	end)

	case("K16: the timer chip: clock and countdown, only for free events; setTimer updates it", function()
		local gui = scratch()
		equal(Style.kitTimerChip(gui, "robux", 60), nil, "never on a paid offer")
		local chip = Style.kitTimerChip(gui, "free", 88243)
		equal(chip.Name, "Timer", "name")
		equal(chip.ClassName, "Frame", "class")
		equal(chip:FindFirstChild("Clock").Text, Style.CLOCK_ICON, "clock")
		equal(chip:FindFirstChild("Time").Text, "24h30m43s", "time")
		Style.setTimer(chip, 65)
		equal(chip:FindFirstChild("Time").Text, "1m05s", "updated")
		Style.setTimer(nil, 5)
		gui:Destroy()
	end)

	case("K17: the lock darkens the whole card, blocks its taps and shows a padlock with the price", function()
		local gui = scratch()
		local card = Style.kitCard(gui, "cyan", true)
		local lock = Style.kitLock(card, "R$ 49")
		equal(lock.Name, "Lock", "name")
		equal(lock.Parent, card, "on the card")
		equal(lock.Size, UDim2.fromScale(1, 1), "covers the card")
		assert(lock.BackgroundTransparency < 1, "darkens")
		equal(lock.BackgroundColor3, Style.KIT_COLORS.lockShade, "dark")
		equal(lock:IsA("GuiButton"), true, "a button on top takes the tap")
		equal(lock.Text, "", "no words of its own")
		equal(lock.Selectable, false, "not a gamepad stop")
		equal(lock.Active, true, "blocks taps")
		assert(lock.ZIndex > 1, "over the content")
		equal(lock:FindFirstChild("Icon").Text, Style.LOCK_ICON, "padlock")
		equal(lock:FindFirstChild("Price").Text, "R$ 49", "price words")
		gui:Destroy()
	end)

	case("K18: the kit never names a purchase service, a remote, a server call or an uploaded image", function()
		assert(#source > 0, "source")
		for _, word in ipairs({ "MarketplaceService", "PromptProductPurchase", "PromptGamePassPurchase", "PromptPurchase",
			"ProcessReceipt", "UserOwnsGamePassAsync", "DeveloperProduct", "FireServer", "InvokeServer", "RemoteEvent",
			"rbxassetid", "http://", "https://", "DataStore" }) do
			assert(not source:find(word, 1, true), "the kit names " .. word)
		end
		assert(source:find("utf8.char(0xE002)", 1, true), "the sign is the built-in private-use letter")
	end)

	return result
end

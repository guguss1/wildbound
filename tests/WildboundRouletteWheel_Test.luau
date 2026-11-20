-- Invoke with require(freshTestClone)(require(freshWheelClone), require(freshStyleClone), require(freshRouletteClone),
-- WildboundRouletteWheel.Source).
-- RW-1..RW-3 (owner request 2026-11-20: "quiero que la ui de mi juego sea exactamente igual a la de la foto que te envie
-- y que lo de la ruleta sea asi", docs/design/refs/roulette-wheel-reference.webp): the roulette wheel. Pins the pure
-- math (wedge angles, the rotation that stops the server's prize under the pointer for any jitter and start, the
-- wedge under the pointer, the palette with no two equal neighbours, the strip fan that draws a wedge without an image,
-- the faces of the live prizes, the "Efectos suaves" spin, the layout that fits a phone held either way) and the
-- builders (built-in pieces only, every tap at least 44 px), and that the module names no purchase call, remote or
-- uploaded image. Builders only parent into a parentless ScreenGui made here, destroyed at the end of each case.
return function(Wheel, Style, Roulette, source)
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
	local function near(actual, expected, eps, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (eps or 1e-9),
			(label and label .. ": " or "") .. "expected about " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function scratch()
		local gui = Instance.new("ScreenGui")
		gui.Name = "WbWheelScratch"
		return gui
	end
	source = type(source) == "string" and source or ""
	local LIVE_COUNT = #Roulette.LIVE.prizes

	case("W1: the tables are frozen; the palette is the reference's seven bright colours, all different", function()
		for _, name in ipairs({ "PALETTE", "SIZES", "MOTION", "WORDS", "ICONS", "LAYOUT" }) do
			assert(type(Wheel[name]) == "table" and table.isfrozen(Wheel[name]), name .. " frozen")
		end
		equal(#Wheel.PALETTE, 7, "seven colours")
		local seen = {}
		for index, color in ipairs(Wheel.PALETTE) do
			equal(typeof(color), "Color3", "colour " .. index)
			local brightest = math.max(color.R, color.G, color.B)
			assert(brightest >= 0.85, "colour " .. index .. " is bright")
			local key = tostring(color)
			assert(not seen[key], "colour " .. index .. " repeats")
			seen[key] = true
		end
		local red = Wheel.PALETTE[1]
		assert(red.R > red.G and red.R > red.B, "red first, like the top wedge of the reference")
		equal(Wheel.WORDS.spinsLeft:format(1), "Tiradas: 1", "the reference's title, in Spanish")
	end)

	case("W2: wedge angles and middles; one wedge per live prize", function()
		equal(LIVE_COUNT, 11, "the live table has 11 prizes")
		near(Wheel.wedgeAngle(LIVE_COUNT), 360 / 11, 1e-12, "11 wedges")
		near(Wheel.wedgeAngle(8), 45, 1e-12, "8 wedges")
		near(Wheel.wedgeCenter(1, 8), 22.5, 1e-12, "first middle")
		near(Wheel.wedgeCenter(8, 8), 337.5, 1e-12, "last middle")
		for _, bad in ipairs({ 0, -3, 2.5, 0 / 0 }) do equal(Wheel.wedgeAngle(bad), nil, "count " .. tostring(bad)) end
		equal(Wheel.wedgeAngle(nil), nil, "nil count")
		equal(Wheel.wedgeCenter(0, 8), nil, "index 0"); equal(Wheel.wedgeCenter(9, 8), nil, "index past the end")
		equal(Wheel.wedgeCenter(1.5, 8), nil, "not whole")
	end)

	case("W3: targetRotation stops every prize under the pointer for any jitter and start, after the asked turns", function()
		for _, count in ipairs({ 2, 7, 8, LIVE_COUNT, 16 }) do
			local step = 360 / count
			for index = 1, count do
				for _, jitter in ipairs({ -1, -0.5, 0, 0.5, 1 }) do
					for _, from in ipairs({ 0, 123.4, 359.9, 7200.5, -50 }) do
						for _, turns in ipairs({ 0, 1, 5 }) do
							local label = string.format("count %d index %d jitter %g from %g turns %d", count, index, jitter, from, turns)
							local target = Wheel.targetRotation(index, count, turns, jitter, from)
							assert(type(target) == "number", label .. ": no target")
							equal(Wheel.indexAt(target, count), index, label)
							local travel = target - from
							assert(travel >= turns * 360 - 1e-9, label .. ": too few turns " .. travel)
							assert(travel < (turns + 1) * 360, label .. ": too many turns " .. travel)
							local shown = Wheel.normalize(Wheel.wedgeCenter(index, count) + target)
							local off = math.min(shown, 360 - shown)
							assert(off <= step * Wheel.SIZES.jitterShare + 1e-6, label .. ": stops too far from the middle " .. off)
						end
					end
				end
			end
		end
		near(Wheel.normalize(Wheel.targetRotation(1, 8, 0, 0, 0)), 360 - 22.5, 1e-9, "no jitter: the middle of wedge 1")
		near(Wheel.targetRotation(1, 8, 3, 0, 0), 3 * 360 + 337.5, 1e-9, "three turns from 0")
		assert(Wheel.SIZES.jitterShare < 0.5, "jitter never reaches a line")
		equal(Wheel.targetRotation(0, 8, 1, 0), nil, "bad index")
		equal(Wheel.targetRotation(1, 0, 1, 0), nil, "bad count")
		local plain = Wheel.targetRotation(3, 8, 2, 0 / 0, nil)
		equal(plain, Wheel.targetRotation(3, 8, 2, 0, 0), "a bad jitter is 0 and a missing start is 0")
		equal(Wheel.clampJitter(5), 1); equal(Wheel.clampJitter(-5), -1); equal(Wheel.clampJitter("x"), 0)
	end)

	case("W4: indexAt reads the wedge under the pointer, lines included", function()
		equal(Wheel.indexAt(0, 8), 1, "unturned: wedge 1 starts under the pointer")
		equal(Wheel.indexAt(-1, 8), 1, "turned back 1 degree")
		equal(Wheel.indexAt(1, 8), 8, "turned on 1 degree: the last wedge")
		equal(Wheel.indexAt(-45, 8), 2, "a whole wedge back")
		equal(Wheel.indexAt(-44.9, 8), 1)
		equal(Wheel.indexAt(720 - 90, 8), 3, "turns are ignored")
		equal(Wheel.indexAt(0 / 0, 8), 1, "a bad rotation reads as 0")
		equal(Wheel.indexAt(0, 0), nil, "bad count")
	end)

	case("W5: no two neighbouring wedges share a colour, the last and the first included", function()
		for count = 2, 22 do
			for index = 1, count do
				local nextIndex = index % count + 1
				assert(Wheel.colorIndex(index, count) ~= Wheel.colorIndex(nextIndex, count),
					string.format("count %d: wedges %d and %d match", count, index, nextIndex))
				equal(Wheel.color(index, count), Wheel.PALETTE[Wheel.colorIndex(index, count)], "color()")
			end
		end
		equal(Wheel.colorIndex(1, LIVE_COUNT), 1, "the first wedge is red")
	end)

	case("W6: the strip fan: straight wedge edges outside the hub, no gap at the rim, both edges drawn inward", function()
		for _, count in ipairs({ 6, 8, LIVE_COUNT, 14 }) do
			local fan = Wheel.fan(count)
			local step = 360 / count
			equal(fan.perWedge, Wheel.SIZES.barsPerWedge, "strips per wedge")
			equal(fan.perWedge % 2, 0, "an even number: half clockwise, half anticlockwise")
			equal(#fan.bars, count * fan.perWedge, "count " .. count)
			assert(fan.width >= 0.5 * math.rad(fan.gap), "count " .. count .. ": the strips meet at the rim")
			assert(fan.clearRatio < Wheel.SIZES.hubRatio, string.format("count %d: strips cross a line out to %.3f of the radius, the hub covers %.3f",
				count, fan.clearRatio, Wheel.SIZES.hubRatio))
			for wedge = 1, count do
				local first = fan.bars[(wedge - 1) * fan.perWedge + 1]
				local last = fan.bars[wedge * fan.perWedge]
				equal(first.wedge, wedge); equal(last.wedge, wedge)
				near(first.angle, (wedge - 1) * step, 1e-9, "the first strip lies on the start edge")
				equal(first.side, 1, "and reaches clockwise, into its wedge")
				near(last.angle, wedge * step, 1e-9, "the last strip lies on the end edge")
				equal(last.side, -1, "and reaches anticlockwise, into its wedge")
			end
		end
		equal(Wheel.fan(0), nil, "no wedges")
		equal(Wheel.fan(8, 5).perWedge, 4, "an odd request rounds down to even")
	end)

	case("W7: the faces of the live prizes: an icon per kind and a short +n label (a chest for the legendary bundle)", function()
		local want = {
			esencia10 = { "esencia", "+10" }, esencia25 = { "esencia", "+25" }, esencia45 = { "esencia", "+45" },
			esencia90 = { "esencia", "+90" }, esencia200 = { "esencia", "+200" }, fogbark10 = { "fogbark", "+10" },
			glowmoss6 = { "glowmoss", "+6" }, mixedPouch = { "pouch", "+15" }, nightbloom2 = { "nightbloom", "+2" },
			nightbloom5 = { "nightbloom", "+5" }, forestChest = { "chest", "Cofre" },
		}
		for _, prize in ipairs(Roulette.LIVE.prizes) do
			local face = Wheel.face(prize)
			local row = want[prize.id]
			assert(row, "a face pinned for " .. prize.id)
			equal(face.kind, row[1], prize.id .. " kind")
			equal(face.label, row[2], prize.id .. " label")
			equal(face.icon, Wheel.ICONS[row[1]], prize.id .. " icon")
			assert(#face.label <= 6, prize.id .. ": short enough for a narrow wedge")
		end
		equal(Wheel.face(nil).label, "?", "unknown prize")
		equal(Wheel.face({ grant = {} }).kind, "chest", "empty grant")
		equal(Wheel.shortNumber(1000), "1K"); equal(Wheel.shortNumber(1500), "1.5K"); equal(Wheel.shortNumber(250), "250")
		for kind, icon in pairs(Wheel.ICONS) do
			assert(type(icon) == "string" and #icon > 0 and not icon:find("rbxassetid", 1, true), kind .. ": a built-in emoji")
		end
	end)

	case("W8: Efectos suaves makes the spin one short turn without the bounce; the full spin stays under 3.2 s", function()
		local full, soft = Wheel.motion(false), Wheel.motion(true)
		assert(full.turns >= 3, "several turns"); equal(full.bounce, true)
		equal(soft.turns, 1, "one turn"); equal(soft.bounce, false, "no bounce")
		assert(soft.seconds < full.seconds, "shorter")
		assert(full.seconds < 3.2, "the wheel stops before WildboundRouletteService.SPIN_SECONDS lets the next spin in")
		equal(Wheel.motion(nil).turns, full.turns, "nil is not reduced")
	end)

	-- Phones upright and sideways (the gui area under the top bar), small and large screens, a computer. The 262 / 302 /
	-- 332 heights are small phones held sideways under Roblox's 58 px top bar (568x320, 480x320, 640x360, 844x390).
	local SCREENS = { { 320, 480 }, { 375, 667 }, { 390, 800 }, { 568, 284 }, { 667, 339 }, { 844, 354 }, { 1024, 718 },
		{ 768, 990 }, { 1366, 710 }, { 1920, 1022 }, { 568, 262 }, { 480, 262 }, { 640, 302 }, { 844, 332 } }
	local function inside(box, W, H, label)
		assert(box.x >= 0 and box.y >= 0 and box.x + box.w <= W and box.y + box.h <= H,
			string.format("%s: (%d,%d %dx%d) leaves %dx%d", label, box.x, box.y, box.w, box.h, W, H))
	end
	local function apart(a, b, label)
		local clear = a.x + a.w <= b.x or b.x + b.w <= a.x or a.y + a.h <= b.y or b.y + b.h <= a.y
		assert(clear, label .. " overlap")
	end

	case("W9: the layout fits a phone held either way: everything inside, nothing over the wheel, taps of 44 px", function()
		for _, screen in ipairs(SCREENS) do
			local W, H = screen[1], screen[2]
			local tag = W .. "x" .. H
			local boxes = Wheel.layout(W, H)
			equal(boxes.wide, W >= H * Wheel.LAYOUT.wide, tag .. " wide")
			assert(boxes.diameter >= Wheel.LAYOUT.floorDiameter and boxes.diameter <= Wheel.LAYOUT.maxDiameter, tag .. " diameter")
			equal(boxes.wheel.w, boxes.diameter, tag .. " square wheel"); equal(boxes.wheel.h, boxes.diameter, tag .. " square wheel")
			local all = { title = boxes.title, info = boxes.info, wheel = boxes.wheel, result = boxes.result, odds = boxes.odds,
				spin = boxes.spin, close = boxes.close, note = boxes.note, pack1 = boxes.packs[1], pack2 = boxes.packs[2],
				pack3 = boxes.packs[3] }
			for name, box in pairs(all) do inside(box, W, H, tag .. " " .. name) end
			for _, name in ipairs({ "odds", "spin", "close" }) do
				assert(all[name].w >= 44 and all[name].h >= 44, tag .. " " .. name .. " is a 44 px tap")
			end
			for index = 1, 3 do
				local pack = boxes.packs[index]
				assert(pack.h - Wheel.LAYOUT.caption >= 44 and pack.w >= 44, tag .. " pack " .. index .. " is a 44 px tap")
				apart(pack, boxes.wheel, tag .. " pack " .. index .. " and the wheel")
				apart(pack, boxes.spin, tag .. " pack " .. index .. " and Girar")
				apart(pack, boxes.close, tag .. " pack " .. index .. " and Cerrar")
				if index > 1 then apart(pack, boxes.packs[index - 1], tag .. " packs " .. index) end
			end
			apart(boxes.wheel, boxes.spin, tag .. " wheel and Girar"); apart(boxes.wheel, boxes.title, tag .. " wheel and title")
			apart(boxes.odds, boxes.spin, tag .. " i and Girar"); apart(boxes.spin, boxes.close, tag .. " Girar and Cerrar")
			apart(boxes.note, boxes.wheel, tag .. " note and wheel")
		end
		local phoneUp, phoneSide = Wheel.layout(390, 800), Wheel.layout(844, 354)
		equal(phoneUp.wide, false, "upright: packs in a row"); equal(phoneSide.wide, true, "sideways: packs on the right")
		assert(phoneUp.packs[1].y == phoneUp.packs[3].y, "upright: one row")
		assert(phoneSide.packs[1].x == phoneSide.packs[3].x and phoneSide.packs[1].y < phoneSide.packs[3].y, "sideways: stacked")
		assert(phoneSide.packs[1].x > phoneSide.wheel.x + phoneSide.wheel.w, "sideways: right of the wheel")
		assert(phoneUp.diameter >= 300, "upright: a big wheel")
		equal(Wheel.layout(1920, 1022).diameter, Wheel.LAYOUT.maxDiameter, "a computer: the largest wheel")
		assert(Wheel.layout(667, 339).diameter >= Wheel.LAYOUT.minDiameter, "a wheel smaller than minDiameter only when short")
		local short = Wheel.layout(568, 262)
		assert(short.diameter < Wheel.LAYOUT.minDiameter, "568x262: the wheel shrinks instead of pushing Girar off-screen")
		assert(short.packs[3].h < Wheel.LAYOUT.caption + Wheel.LAYOUT.pack, "568x262: the packs shrink too")
		equal(Wheel.layout(844, 354).packs[1].h, Wheel.LAYOUT.caption + Wheel.LAYOUT.pack, "full packs when there is room")
		local broken = Wheel.layout(0 / 0, nil)
		equal(broken.diameter, Wheel.LAYOUT.floorDiameter, "a bad size does not throw")
	end)

	case("W10: buildWheel: a white ring, a round CanvasGroup disc of strips, faces, a hub and a pointer; built-ins only", function()
		local gui = scratch()
		local faces = {}
		for index, prize in ipairs(Roulette.LIVE.prizes) do faces[index] = Wheel.face(prize) end
		local root, disc = Wheel.buildWheel(gui, faces, Style)
		equal(root.Name, "Wheel"); equal(root.Parent, gui)
		equal(root:GetAttribute("WbWedges"), LIVE_COUNT)
		assert(root:FindFirstChild("WbPop") and root.WbPop:IsA("UIScale"), "the bounce scale")
		local ring = root:FindFirstChild("Ring")
		assert(ring and ring.BackgroundColor3 == Color3.new(1, 1, 1), "a white ring")
		equal(ring:FindFirstChildOfClass("UICorner").CornerRadius, UDim.new(0.5, 0), "round ring")
		equal(disc.ClassName, "CanvasGroup", "the disc clips its strips to a circle")
		equal(disc.Name, "Disc"); equal(disc.Parent, root)
		equal(disc:FindFirstChildOfClass("UICorner").CornerRadius, UDim.new(0.5, 0), "round disc")
		equal(disc.Rotation, 0, "unturned")
		local fan = Wheel.fan(LIVE_COUNT)
		local bars = disc.Wedges:GetChildren()
		equal(#bars, #fan.bars, "one holder per strip")
		local first = disc.Wedges:FindFirstChild("Bar")
		local strip = first:FindFirstChild("Strip")
		equal(strip.BackgroundColor3, Wheel.color(1, LIVE_COUNT), "the first wedge's colour")
		equal(strip.Size, UDim2.fromScale(0.5, 0.5), "a quarter of its holder: from the centre to the rim")
		equal(first.Size, UDim2.fromScale(2 * fan.width, 1), "a holder one diameter tall")
		equal(#disc.Dividers:GetChildren(), LIVE_COUNT, "a dark line on every edge, like the reference")
		equal(disc.Dividers:FindFirstChild("Divider").Strip.BackgroundColor3, Style.COLORS.outline, "dark divider")
		for index, face in ipairs(faces) do
			local spoke = disc.Faces:FindFirstChild("Face" .. index)
			assert(spoke, "face " .. index)
			near(spoke.Rotation, Wheel.wedgeCenter(index, LIVE_COUNT), 1e-3, "face " .. index .. " in its wedge")
			equal(spoke.Icon.Text, face.icon, "icon " .. index)
			equal(spoke.Label.Text, face.label, "label " .. index)
			equal(spoke.Label.Rotation, 0, "the label lies across its wedge and turns with it, like the reference's +100")
			equal(spoke.Label.Font, Style.FONT_TITLE, "the kit's round font")
			assert(spoke.Label:FindFirstChildOfClass("UIStroke"), "outlined label")
		end
		local hub = root:FindFirstChild("Hub")
		assert(hub and hub.ZIndex > disc.ZIndex, "the hub cap over the disc")
		local pointer = root:FindFirstChild("Pointer")
		assert(pointer and pointer.ClipsDescendants and pointer.Rotation == 0, "an unrotated clip makes the triangle")
		equal(pointer.Tip.Rotation, 45, "a turned square")
		equal(pointer.Tip.BackgroundColor3, Color3.new(1, 1, 1), "white pointer")
		assert(pointer.ZIndex > hub.ZIndex, "the pointer on top")
		for _, item in ipairs(root:GetDescendants()) do
			assert(not item:IsA("ImageLabel") and not item:IsA("ImageButton"), "no image: " .. item:GetFullName())
		end
		gui:Destroy()
	end)

	case("W11: buildPack: caption, chunky button with the mini wheel, name and price; fitPack hides the wheel when narrow", function()
		local gui = scratch()
		local offer = { id = "rouletteSpins3", name = "+3 Tiradas", caption = "Popular", tone = "blue" }
		local box, button = Wheel.buildPack(gui, offer, Style.priceText("robux", 29), Style)
		equal(box.Name, "Pack_rouletteSpins3"); equal(box.Parent, gui); equal(box:GetAttribute("OfferId"), "rouletteSpins3")
		equal(box.Caption.Text, "POPULAR", "the caption in capitals, like the reference")
		equal(button.Name, "Buy"); equal(button.ClassName, "TextButton")
		equal(button.BackgroundColor3, Style.COLORS.blue, "the offer's tone")
		equal(button.Label.Text, "+3 Tiradas")
		equal(button.Price.Text, Style.priceText("robux", 29), "the price words with the sign")
		local limit = button:FindFirstChild("WbTapMin")
		equal(limit.MinSize, Vector2.new(44, 44), "a 44 px tap at least")
		local icon = button:FindFirstChild("WheelIcon")
		assert(icon and icon:FindFirstChild("Face"):FindFirstChildOfClass("UIGradient"), "a rainbow mini wheel")
		Wheel.fitPack(box, 220, 76)
		equal(icon.Visible, true, "wide: the mini wheel shows")
		equal(button.Label.Position.X.Offset, 76 - Wheel.LAYOUT.caption, "the words start after the wheel")
		Wheel.fitPack(box, 96, 76)
		equal(icon.Visible, false, "narrow: no mini wheel")
		equal(button.Label.Position.X.Offset, 6, "the words take the whole button")
		for _, item in ipairs(box:GetDescendants()) do
			assert(not item:IsA("ImageLabel") and not item:IsA("ImageButton"), "no image: " .. item.Name)
		end
		gui:Destroy()
	end)

	case("W12: the module names no purchase call, remote, server call, uploaded image or data store", function()
		assert(#source > 0, "source")
		for _, word in ipairs({ "MarketplaceService", "PromptProductPurchase", "PromptGamePassPurchase", "PromptPurchase",
			"ProcessReceipt", "Robux", "FireServer", "InvokeServer", "RemoteEvent", "rbxassetid", "http://", "https://",
			"DataStore", "require(", "game:", "task." }) do
			assert(not source:find(word, 1, true), "the wheel module names " .. word)
		end
	end)

	return result
end

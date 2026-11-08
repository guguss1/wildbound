-- Invoke with require(freshTestClone)(require(freshViewClone), require(freshLayoutClone),
-- require(freshSettingsClone), require(freshTutorialClone), freshViewClone.Source). Pure rectangles for the start
-- screen, Settings, How to play and the tutorial card (W9, M8.5 and M8.6), checked on nine viewports.
return function(View, Layout, Settings, Tutorial, source)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "Expected " .. tostring(expected)
			.. ", got " .. tostring(actual))
	end
	-- Interface sizes as the HUD layout tests use them, plus two small and two large ones.
	local VIEWPORTS = { { 750, 323 }, { 705, 280 }, { 401, 720 }, { 359, 660 }, { 1069, 501 }, { 1280, 720 },
		{ 640, 360 }, { 320, 568 }, { 1920, 1080 } }
	local function layoutFor(size)
		return Layout.compute(size[1], size[2], { touch = size[1] < 1000 })
	end
	local function label(size) return size[1] .. "x" .. size[2] end
	local function inside(inner, outer, message)
		assert(inner.x >= outer.x and inner.y >= outer.y and inner.x + inner.w <= outer.x + outer.w
			and inner.y + inner.h <= outer.y + outer.h, message)
	end
	local function absolute(panel, local_)
		return { x = panel.x + local_.x, y = panel.y + local_.y, w = local_.w, h = local_.h }
	end
	local function noOverlap(named, message)
		for first = 1, #named do
			for second = first + 1, #named do
				equal(Layout.overlapArea(named[first][2], named[second][2]), 0, message .. ": " .. named[first][1] .. " and " .. named[second][1])
			end
		end
	end
	local function buttonCheck(named, tag)
		for _, entry in ipairs(named) do
			assert(entry[2].w >= 44 and entry[2].h >= 44, tag .. " " .. entry[1] .. " is " .. entry[2].w .. "x" .. entry[2].h)
		end
	end
	local function textFits(entries, tag)
		for _, entry in ipairs(entries) do
			assert(View.textHeight(entry[2], entry[3].w, entry[4] or 13) <= entry[3].h, tag .. " text does not fit: " .. entry[2])
		end
	end

	case("SV-1: the region keeps clear of the move control and the jump button on phones", function()
		for _, size in ipairs(VIEWPORTS) do
			local layout = layoutFor(size)
			local region = View.region(layout)
			assert(region.x >= 0 and region.y >= 0 and region.x + region.w <= size[1] and region.y + region.h <= size[2], label(size))
			if layout.mode == "compact" then
				equal(Layout.overlapArea(region, layout.zones.thumbstick), 0, label(size) .. " thumbstick")
				equal(Layout.overlapArea(region, layout.zones.jump), 0, label(size) .. " jump")
			end
			assert(region.w >= 240, label(size) .. " region is " .. region.w .. " wide")
		end
	end)

	case("SV-2: the start screen fits its region, has 44 pixel targets and offers Reduced effects (D11)", function()
		for _, size in ipairs(VIEWPORTS) do
			local layout = layoutFor(size)
			local start = View.start(layout)
			local tag = label(size)
			inside(start.panel, start.region, tag .. " panel outside region (" .. start.panel.h .. " high, region " .. start.region.h .. ")")
			local local_ = { {"play", start.play}, {"settings", start.settings}, {"howto", start.howto}, {"reduced", start.reduced} }
			buttonCheck(local_, tag)
			local all = { {"title", start.title}, {"tagline", start.tagline}, {"note", start.note}, table.unpack(local_) }
			for _, entry in ipairs(all) do inside(entry[2], { x = 0, y = 0, w = start.panel.w, h = start.panel.h }, tag .. " " .. entry[1] .. " outside the panel") end
			noOverlap(all, tag)
			textFits({ { "tagline", View.TEXT.tagline, start.tagline }, { "note", View.TEXT.note, start.note } }, tag)
			if layout.mode == "compact" then
				equal(Layout.overlapArea(start.panel, layout.zones.thumbstick), 0, tag .. " thumbstick")
				equal(Layout.overlapArea(start.panel, layout.zones.jump), 0, tag .. " jump")
			end
		end
	end)

	case("SV-3: Settings fits, every toggle and button is 44 pixels or more, text fits", function()
		local descriptions = {}
		for _, key in ipairs(Settings.ORDER) do table.insert(descriptions, Settings.LABELS[key] .. ". " .. Settings.DESCRIPTIONS[key]) end
		for _, size in ipairs(VIEWPORTS) do
			local layout = layoutFor(size)
			local view = View.settings(layout, descriptions)
			local tag = label(size)
			inside(view.panel, view.region, tag .. " panel outside region (" .. view.panel.h .. " high, region " .. view.region.h .. ")")
			equal(#view.rows, #descriptions)
			local named = { {"title", view.title}, {"replay", view.replay}, {"back", view.back} }
			for index, row in ipairs(view.rows) do
				table.insert(named, { "text" .. index, row.text }); table.insert(named, { "toggle" .. index, row.toggle })
				buttonCheck({ { "toggle" .. index, row.toggle } }, tag)
				textFits({ { "row" .. index, descriptions[index], row.text } }, tag)
			end
			buttonCheck({ { "replay", view.replay }, { "back", view.back } }, tag)
			for _, entry in ipairs(named) do inside(entry[2], { x = 0, y = 0, w = view.panel.w, h = view.panel.h }, tag .. " " .. entry[1] .. " outside the panel") end
			noOverlap(named, tag)
			if layout.mode == "compact" then
				equal(Layout.overlapArea(view.panel, layout.zones.thumbstick), 0, tag .. " thumbstick")
				equal(Layout.overlapArea(view.panel, layout.zones.jump), 0, tag .. " jump")
			end
		end
	end)

	case("SV-4: How to play fits, says the four lines and has a 44 pixel Back button", function()
		equal(#View.TEXT.howto, 4)
		for _, size in ipairs(VIEWPORTS) do
			local layout = layoutFor(size)
			local view = View.howto(layout)
			local tag = label(size)
			inside(view.panel, view.region, tag .. " panel outside region (" .. view.panel.h .. " high, region " .. view.region.h .. ")")
			buttonCheck({ { "back", view.back } }, tag)
			local named = { {"title", view.title}, {"back", view.back} }
			for index, line in ipairs(view.lines) do
				table.insert(named, { "line" .. index, line })
				textFits({ { "line" .. index, View.TEXT.howto[index], line } }, tag)
			end
			for _, entry in ipairs(named) do inside(entry[2], { x = 0, y = 0, w = view.panel.w, h = view.panel.h }, tag .. " " .. entry[1] .. " outside the panel") end
			noOverlap(named, tag)
			if layout.mode == "compact" then
				equal(Layout.overlapArea(view.panel, layout.zones.thumbstick), 0, tag .. " thumbstick")
				equal(Layout.overlapArea(view.panel, layout.zones.jump), 0, tag .. " jump")
			end
		end
	end)

	case("SV-5: the tutorial card keeps clear of the controls, the avatar and the HUD, and its text fits", function()
		for _, size in ipairs(VIEWPORTS) do
			local layout = layoutFor(size)
			local card = View.card(layout)
			local tag = label(size) .. " " .. card.mode
			assert(card.rect.x >= 4 and card.rect.y >= 4 and card.rect.x + card.rect.w <= size[1] - 4
				and card.rect.y + card.rect.h <= size[2] - 4, tag .. " runs off screen")
			buttonCheck({ { "skip", card.skip } }, tag)
			inside(card.skip, { x = 0, y = 0, w = card.rect.w, h = card.rect.h }, tag .. " skip outside the card")
			inside(card.text, { x = 0, y = 0, w = card.rect.w, h = card.rect.h }, tag .. " text outside the card")
			equal(Layout.overlapArea(absolute(card.rect, card.skip), absolute(card.rect, card.text)), 0, tag .. " skip over the text")
			for _, name in ipairs(Layout.ELEMENTS) do
				local item = layout.rects[name]
				if not (card.mode == "hud" and name == "hud") then
					equal(Layout.overlapArea(card.rect, item), 0, tag .. " covers " .. name)
				end
			end
			if card.mode ~= "hud" then equal(Layout.overlapArea(card.rect, layout.zones.keepout), 0, tag .. " covers the avatar") end
			if layout.mode == "compact" then
				equal(Layout.overlapArea(card.rect, layout.zones.thumbstick), 0, tag .. " thumbstick")
				equal(Layout.overlapArea(card.rect, layout.zones.jump), 0, tag .. " jump")
			end
			for _, step in ipairs(Tutorial.STEPS) do
				local text = Tutorial.cardText(step, layout.mode == "compact")
				assert(View.textHeight(text, card.text.w, card.size) <= card.text.h, tag .. " card text does not fit: " .. text)
			end
		end
	end)

	case("SV-6: the card sits under the chip on desktop and replaces the objective line on an upright phone", function()
		equal(View.card(layoutFor({ 1280, 720 })).mode, "side")
		equal(View.card(layoutFor({ 401, 720 })).mode, "hud")
		equal(View.card(layoutFor({ 750, 323 })).mode, "bottom")
	end)

	-- Deliberately changed (K1): the start screen is Spanish now (it was plain English and ASCII only).
	case("SV-7: every string is Spanish, valid UTF-8, with no developer words", function()
		local all = { View.TEXT.title, View.TEXT.tagline, View.TEXT.note, View.TEXT.settingsTitle, View.TEXT.howtoTitle }
		for _, line in ipairs(View.TEXT.howto) do table.insert(all, line) end
		for _, text in ipairs(all) do
			for _, bad in ipairs({ "TODO", "P0", "debug", "nil", "TBD" }) do assert(not text:find(bad, 1, true), text) end
			assert(utf8.len(text) ~= nil, "valid UTF-8: " .. text)
		end
		assert(View.TEXT.note:find("no se guarda", 1, true), "session-only must be said")
		equal(View.TEXT.howtoTitle, "Cómo jugar")
	end)

	case("SV-8: the module is pure: no services, clock, randomness or persistence", function()
		for _, word in ipairs({ "game", "GetService", "os.", "tick(", "Random", "math.random", "DataStore", "task.",
			"workspace", "Instance", "MarketplaceService", "Robux" }) do
			equal(source:find(word, 1, true), nil, "source mentions " .. word)
		end
	end)

	return result
end

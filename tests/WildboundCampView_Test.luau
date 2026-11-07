-- Invoke with require(freshTestClone)(require(freshViewClone), require(freshConfigClone), require(freshEconomyClone),
-- require(freshLayoutClone), freshViewClone.Source). M5.8 camp screen, HUD loss line and M5.6 compass. Pure
-- view-models: a snapshot in, rows and rectangles out. ECO numbers refer to docs/mechanics/wildbound-economy-p0.md.
return function(View, Config, Economy, Layout, source)
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
	local function snapshot(overrides)
		local value = { ember = 0, banked = { fogbark = 0, glowmoss = 0, nightbloom = 0 },
			consumables = { seal = 0, capsule = 0, totem = 0 }, upgrades = { reinforcedPack = false }, skills = {}, bond = {},
			pending = {}, sealArmed = false, totemActive = false, pendingBondXp = 0,
			riskPreview = { loseItems = 0, keep = 0, loseMaterials = {} } }
		for key, item in pairs(overrides or {}) do value[key] = item end
		return value
	end
	local rich = { ember = 400, banked = { fogbark = 100, glowmoss = 80, nightbloom = 10 } }
	local function rowsOf(overrides, ctx)
		return View.campRows(Config, Economy, snapshot(overrides), ctx)
	end
	local function byId(rows, id)
		for _, item in ipairs(rows) do
			if item.id == id then return item end
		end
		error("no row " .. id)
	end

	case("costText lists the price in a fixed order and reads Free for nothing", function()
		equal(View.costText({ nightbloom = 1, fogbark = 8, ember = 12, glowmoss = 5 }), "12 Ember, 8 Fogbark, 5 Glowmoss, 1 Nightbloom")
		equal(View.costText(Config.recipes.seal.cost), "8 Fogbark, 4 Glowmoss")
		equal(View.costText({}), "Free"); equal(View.costText(nil), "Free")
		equal(View.costText({ fogbark = 0, glowmoss = -1 }), "Free")
	end)

	case("shortfall names exactly what is missing", function()
		local wallet = { ember = 5, banked = { fogbark = 5, glowmoss = 4 } }
		equal(View.shortfall(wallet, Config.recipes.seal.cost), "Need 3 more Fogbark")
		equal(View.shortfall({ ember = 0, banked = {} }, Config.recipes.totem.cost), "Need 20 more Ember and 12 more Glowmoss and 2 more Nightbloom")
		equal(View.shortfall(wallet, { fogbark = 5 }), nil, "affordable has no shortfall")
		equal(View.shortfall(nil, { fogbark = 1 }), "Need 1 more Fogbark")
	end)

	case("ECO-32 every recipe, the upgrade and all eight skills have a row that matches a server action", function()
		local rows = rowsOf(rich)
		for recipe in pairs(Config.recipes) do equal(byId(rows, "craft:" .. recipe).action, "Craft"); equal(byId(rows, "craft:" .. recipe).argument, recipe) end
		for upgrade in pairs(Config.upgrades) do equal(byId(rows, "upgrade:" .. upgrade).argument, upgrade) end
		local skills = 0
		for id in pairs(Config.skills) do
			local item = byId(rows, "skill:" .. id)
			equal(item.action, "Learn"); equal(item.argument, id)
			skills += 1
		end
		equal(skills, 8)
		local valid = { Craft = Config.recipes, Upgrade = Config.upgrades, Learn = Config.skills }
		for _, item in ipairs(rows) do
			if item.action and valid[item.action] then assert(valid[item.action][item.argument], item.id .. " names an unknown argument") end
			if item.label then assert(#item.label <= 12, "a button label that fits 98 pixels: " .. item.label) end
		end
	end)

	case("a craft is enabled only when the stock covers it, and a disabled row says why in words", function()
		local poor = rowsOf({ ember = 3, banked = { fogbark = 5, glowmoss = 4, nightbloom = 0 } })
		local seal = byId(poor, "craft:seal")
		equal(seal.enabled, false); equal(seal.why, "Need 3 more Fogbark")
		assert(seal.text:find("Cost: 8 Fogbark, 4 Glowmoss", 1, true), seal.text)
		assert(seal.text:find(seal.why, 1, true), "the reason is part of the visible text, not only a dimmed button")
		local flush = byId(rowsOf(rich), "craft:seal")
		equal(flush.enabled, true); equal(flush.why, "")
		local atLimit = byId(rowsOf({ ember = 400, banked = rich.banked, consumables = { seal = 3, capsule = 0, totem = 0 } }), "craft:seal")
		equal(atLimit.enabled, false); assert(atLimit.why:find("most", 1, true), atLimit.why)
		equal(byId(rowsOf(rich, { atCamp = false }), "craft:seal").why, "Go to camp")
		equal(byId(rowsOf(rich, { busy = true }), "craft:seal").why, "Wait a moment")
		equal(byId(rowsOf(rich, { busy = true, atCamp = false }), "craft:seal").enabled, false)
		for _, item in ipairs(rowsOf({ ember = 1 }, { atCamp = false })) do
			if item.label then assert(item.enabled == false and item.why ~= "", item.id .. " must be off with a reason") end
		end
		for _, item in ipairs(rowsOf(rich)) do
			assert(#item.text <= 140, item.id .. " is " .. #item.text .. " characters")
			if item.enabled then equal(item.why, "", item.id) end
		end
	end)

	case("ECO-13 skill rows show the tree: locked, pending, affordable and learned", function()
		local rows = rowsOf(rich)
		local tier2 = byId(rows, "skill:explorer_2")
		equal(tier2.enabled, false); equal(tier2.why, "Needs Explorer 1")
		local pending = byId(rows, "skill:occultist_1")
		equal(pending.enabled, false); equal(pending.why, "Effect not built yet")
		local live = byId(rows, "skill:explorer_1")
		equal(live.enabled, true)
		assert(live.text:find(View.costText(Config.skills.explorer_1.cost), 1, true), "the shown price is the tuned price")
		assert(live.text:find("60 studs", 1, true), live.text)
		local learned = byId(rowsOf({ ember = 400, banked = rich.banked, skills = { explorer_1 = true } }), "skill:explorer_1")
		equal(learned.label, nil, "a learned skill has no button"); assert(learned.text:find("learned", 1, true))
		local unlocked = byId(rowsOf({ ember = 400, banked = rich.banked, skills = { explorer_1 = true } }), "skill:explorer_2")
		equal(unlocked.enabled, true); assert(unlocked.text:find("100 studs", 1, true), unlocked.text)
		equal(byId(rowsOf(rich), "skill:survivor_1").enabled, true)
		for id, spec in pairs(Config.skills) do
			equal(byId(rows, "skill:" .. id).enabled, spec.effectLive == true and #spec.requires == 0, id)
		end
	end)

	case("arming, the totem, the upgrade and the bond line follow the snapshot", function()
		local plain = rowsOf(rich)
		for _, id in ipairs({ "arm:seal", "totem:on", "totem:off", "bond" }) do
			local found = false
			for _, item in ipairs(plain) do if item.id == id then found = true end end
			equal(found, false, id .. " is not shown with nothing to arm")
		end
		local armed = byId(rowsOf({ consumables = { seal = 1, capsule = 0, totem = 1 }, sealArmed = true }), "arm:seal")
		equal(armed.enabled, false); assert(armed.text:find("armed", 1, true))
		equal(byId(rowsOf({ consumables = { seal = 1, capsule = 0, totem = 0 } }), "arm:seal").enabled, true)
		equal(byId(rowsOf({ consumables = { seal = 0, capsule = 0, totem = 1 } }), "totem:on").action, "ArmTotem")
		local off = byId(rowsOf({ totemActive = true }), "totem:off")
		equal(off.action, "DisarmTotem"); equal(off.enabled, true)
		equal(byId(rowsOf({ totemActive = true, expedition = { startedAt = 1 } }), "totem:off").enabled, false)
		local owned = byId(rowsOf({ upgrades = { reinforcedPack = true } }), "upgrade:reinforcedPack")
		equal(owned.label, nil); assert(owned.text:find("owned", 1, true))
		local bond = byId(rowsOf({ equippedUid = "p1", bond = { p1 = { xp = 45, level = 2 } }, pendingBondXp = 10 }), "bond")
		assert(bond.text:find("level 2", 1, true) and bond.text:find("45 XP", 1, true) and bond.text:find("+10 pending", 1, true), bond.text)
	end)

	case("the Bag tab quick actions: seal the newest item, arm a seal", function()
		local none = View.quickRows(snapshot({ pending = { { uid = "a" } } }))
		equal(none[1].enabled, false); assert(none[1].text:find("No seal", 1, true), none[1].text)
		equal(none[1].action, "SealNewest"); equal(none[1].argument, "seal")
		local ready = View.quickRows(snapshot({ consumables = { seal = 1, capsule = 0, totem = 0 }, pending = { { uid = "a" } } }))
		equal(ready[1].enabled, true); equal(ready[2].enabled, true); equal(ready[2].action, "ArmSeal")
		local empty = View.quickRows(snapshot({ consumables = { seal = 1, capsule = 0, totem = 0 } }))
		equal(empty[1].enabled, false); assert(empty[1].why:find("Nothing", 1, true))
		local sealed = View.quickRows(snapshot({ consumables = { seal = 2, capsule = 0, totem = 0 },
			pending = { { uid = "a", protected = true, wardSource = "Seal" }, { uid = "b" } } }))
		equal(sealed[1].enabled, false); assert(sealed[1].why:find("already", 1, true))
		local armed = View.quickRows(snapshot({ consumables = { seal = 1, capsule = 0, totem = 0 }, sealArmed = true }))
		equal(armed[2].enabled, false)
		equal(View.quickRows(snapshot({ consumables = { seal = 1, capsule = 0, totem = 0 }, pending = { { uid = "a" } } }), { busy = true })[1].enabled, false)
	end)

	case("the loss line states exactly what a defeat would take and never exceeds its budget", function()
		local safe = View.lossLine(snapshot())
		equal(safe.text, "Nothing at risk."); equal(safe.atRisk, false); equal(safe.tone, "safe")
		local risky = snapshot({ riskPreview = { loseItems = 2, keep = 1, loseMaterials = { fogbark = 7, glowmoss = 3 } } })
		local full = View.lossLine(risky, 80)
		equal(full.atRisk, true); equal(full.tone, "risk"); equal(full.glyph, "!")
		assert(full.text:sub(1, 1) == "!", "a shape cue comes first, so hue is never alone")
		for _, needle in ipairs({ "2 items", "7 Fogbark", "3 Glowmoss", "1 kept" }) do assert(full.text:find(needle, 1, true), needle .. " in " .. full.text) end
		for budget = 12, 90 do
			local shown = View.lossLine(risky, budget)
			assert(#shown.text <= budget, ("budget %d got %d: %s"):format(budget, #shown.text, shown.text))
			assert(shown.text:find("%d"), "always a number")
			if budget >= 24 then
				assert(shown.text:find("2", 1, true) and shown.text:find("10", 1, true) or shown.text:find("7", 1, true), shown.text)
			end
		end
		equal(View.lossLine(snapshot({ riskPreview = { loseItems = 1, keep = 0, loseMaterials = {} } }), 60).text, "! If defeated you lose: 1 item.")
		equal(View.lossLine(snapshot({ riskPreview = { loseItems = 0, keep = 0, loseMaterials = { glowmoss = 1 } } }), 60).text, "! If defeated you lose: 1 Glowmoss.")
		local tiny = View.lossLine(risky, 14)
		assert(#tiny.text <= 14 and tiny.text:sub(1, 1) == "!", tiny.text)
		equal(View.lossLine(nil).atRisk, false); equal(View.lossLine({ riskPreview = "x" }).atRisk, false)
	end)

	case("the compass lists gather nodes only, within the owned range, and Nightbloom only at Night", function()
		local nodes = { { x = 30, z = 0, material = "fogbark" }, { x = 0, z = -61, material = "glowmoss" },
			{ x = 90, z = 0, material = "nightbloom" }, { x = 0, z = 50, material = "moonstone" } }
		equal(View.compass({}, nodes, 0, 0, "Day"), nil, "no skill, no compass")
		equal(View.compass(nil, nodes, 0, 0, "Day"), nil)
		local near = View.compass({ nodeHintRange = 60 }, nodes, 0, 0, "Day")
		equal(near.material, "fogbark"); equal(near.distance, 30); equal(near.direction, "E"); equal(near.count, 1)
		assert(near.text:find("Fogbark") and near.text:find("30 studs E"), near.text)
		equal(View.compass({ nodeHintRange = 60 }, { { x = 0, z = -61, material = "glowmoss" } }, 0, 0, "Day"), nil, "61 studs is out of range")
		equal(View.compass({ nodeHintRange = 60 }, { { x = 0, z = -60, material = "glowmoss" } }, 0, 0, "Day").direction, "N", "60 is in, and -Z is north")
		equal(View.compass({ nodeHintRange = 60, nightbloomHintRange = 100 }, { nodes[3] }, 0, 0, "Day"), nil, "Nightbloom hint is Night only")
		local night = View.compass({ nodeHintRange = 60, nightbloomHintRange = 100 }, { nodes[3] }, 0, 0, "Night")
		equal(night.material, "nightbloom"); equal(night.direction, "E")
		equal(View.compass({ nodeHintRange = 60 }, { nodes[3] }, 0, 0, "Night"), nil, "Night Nose is needed for Nightbloom")
		equal(View.compass({ nodeHintRange = 60 }, nodes, 0 / 0, 0, "Day"), nil)
		equal(View.compass({ nodeHintRange = 60 }, "nodes", 0, 0, "Day"), nil)
		equal(View.compass({ nodeHintRange = 60 }, { { x = 0 / 0, z = 0, material = "fogbark" }, "x" }, 0, 0, "Day"), nil)
		assert(#near.text <= 40, "fits a phone line")
		equal(View.compass({ nodeHintRange = 60 }, { { x = 10, z = 10, material = "fogbark" } }, 0, 0, "Day").direction, "SE")
	end)

	local VIEWPORTS = { { 750, 323 }, { 705, 280 }, { 401, 720 }, { 359, 660 }, { 1069, 501 }, { 1280, 720 }, { 640, 360 }, { 320, 568 }, { 1920, 1080 } }
	case("the panel sits below the chip and inside the screen, with 44 pixel header buttons, on nine viewports", function()
		for _, size in ipairs(VIEWPORTS) do
			local width, height = size[1], size[2]
			local layout = Layout.compute(width, height, { touch = width < 1000 })
			local chip = layout.rects.chip
			local panel = View.panel(width, height, chip)
			local label = width .. "x" .. height
			assert(panel.x >= 4 and panel.y >= 4 and panel.x + panel.w <= width - 4 and panel.y + panel.h <= height - 4, label .. " on screen")
			equal(Layout.overlapArea(panel, chip), 0, label .. " panel overlaps the chip")
			if width > height and math.min(width, height) <= 500 then
				-- A phone held sideways: the visible stick sits at the left and the jump button at the right.
				equal(Layout.overlapArea(panel, layout.zones.jump), 0, label .. " panel covers the jump button")
				assert(panel.x >= 0.2 * width, label .. " panel reaches over the thumbstick: x " .. panel.x)
			end
			if height > width then
				-- Held upright: Roblox draws its stick and jump button over the lower 40 percent, above this panel.
				equal(Layout.overlapArea(panel, layout.zones.thumbstick), 0, label .. " panel runs under the touch controls")
				equal(Layout.overlapArea(panel, layout.zones.jump), 0, label .. " panel runs under the jump button")
			end
			local header = View.header(panel.w)
			for _, name in ipairs({ "bag", "camp", "close" }) do
				local button = header[name]
				assert(button.w >= 44 and button.h >= 44, label .. " " .. name .. " under 44")
				assert(button.x >= 0 and button.x + button.w <= panel.w, label .. " " .. name .. " inside the panel")
			end
			equal(Layout.overlapArea(header.bag, header.camp), 0); equal(Layout.overlapArea(header.camp, header.close), 0)
			local list = panel.h - header.bottom - 4 - 24
			assert(list >= 120, label .. " leaves only " .. list .. " pixels for rows")
		end
	end)

	case("a row is tall enough for its wrapped text and keeps a 44 pixel button inside it", function()
		local rows = rowsOf(rich)
		for _, size in ipairs({ { 335, 13 }, { 312, 15 }, { 470, 15 } }) do
			for _, item in ipairs(rows) do
				local height = View.rowHeight(item, size[1], size[2])
				local lines = View.textLines(item.text, size[1] - 16 - (item.label and View.BUTTON_W + 14 or 0), size[2])
				assert(height >= View.ROW_MIN and height >= lines * size[2], item.id .. " at width " .. size[1])
				if item.label then assert(height >= 44 + 8, "the button fits with room") end
			end
		end
		local short = View.rowHeight({ text = "Hi", label = "Go" }, 335, 13)
		local long = View.rowHeight({ text = string.rep("word ", 40), label = "Go" }, 335, 13)
		assert(long > short and short == View.ROW_MIN, "tall text grows the row")
		equal(View.textLines(nil, 100, 13), 1); equal(View.textLines("x", 0 / 0, 13), 1)
	end)

	case("the tab notes are short enough for the phone line and say whether you are at camp", function()
		for _, tab in ipairs({ "bag", "camp" }) do
			for _, atCamp in ipairs({ true, false }) do
				assert(#View.note(tab, atCamp, true) <= 40, tab)
				assert(#View.note(tab, atCamp, false) <= 70, tab)
			end
		end
		assert(View.note("camp", false, true):find("camp", 1, true))
	end)

	-- Compact rows (W9). A phone held sideways showed about 1.5 camp rows (found in W7). Compact rows say
	-- "Title: cost." or "Title: reason.", the sideways list drops the tab note, and rows may be 48 high.
	local function compactRows(overrides, ctx)
		ctx = ctx or {}
		ctx.compact = true
		return View.campRows(Config, Economy, snapshot(overrides), ctx)
	end
	case("CV-C1: compact rows take at most three lines beside the button on a sideways phone", function()
		for _, wallet in ipairs({ rich, {} }) do
			for _, atCamp in ipairs({ true, false }) do
				for _, item in ipairs(compactRows(wallet, { atCamp = atCamp })) do
					local height = View.rowHeight(item, 379, 13, true)
					assert(height <= 64, item.id .. " is " .. height .. " high: " .. item.text)
				end
			end
		end
	end)
	case("CV-C2: most compact rows with money fit two lines and the 48 pixel minimum", function()
		local flat = 0
		local rows = compactRows(rich, { atCamp = true })
		for _, item in ipairs(rows) do
			if View.rowHeight(item, 379, 13, true) == 48 then flat += 1 end
		end
		assert(flat * 2 >= #rows, flat .. " of " .. #rows .. " rows are 48 high")
		equal(View.rowHeight({ text = "Hi", label = "Go" }, 379, 13, true), 48)
		equal(View.rowHeight({ text = "Hi", label = "Go" }, 379, 13), View.ROW_MIN)
	end)
	case("CV-C3: compact rows keep the name, and the reason when a button is off", function()
		local seal = byId(compactRows({}, { atCamp = true }), "craft:seal")
		assert(seal.text:find("Ward Seal") and seal.text:find("Short") and seal.text:find("Fogbark"), seal.text)
		local away = byId(compactRows(rich, { atCamp = false }), "craft:seal")
		assert(away.text:find("Go to camp"), away.text)
		local affordable = byId(compactRows(rich, { atCamp = true }), "craft:seal")
		assert(affordable.text:find("8 Fogbark, 4 Glowmoss"), affordable.text)
		equal(affordable.enabled, true)
	end)
	case("CV-C4: the full rows are unchanged when not compact", function()
		local seal = byId(rowsOf(rich, { atCamp = true }), "craft:seal")
		assert(seal.text:find("saves one bag item", 1, true), seal.text)
	end)
	case("CV-C5: the sideways phone list drops the note and shows three rows or more", function()
		for _, size in ipairs({ { 705, 280 }, { 750, 323 } }) do
			local layout = Layout.compute(size[1], size[2], { touch = true })
			local panel = View.panel(size[1], size[2], layout.rects.chip)
			local area = View.listArea(panel, true)
			equal(area.showNote, false, size[1] .. " note")
			assert(area.height >= 160, size[1] .. " list is only " .. area.height)
			assert(math.floor((area.height + 6) / (48 + 6)) >= 3, size[1] .. " shows fewer than three rows")
		end
	end)
	case("CV-C6: upright phones and desktop keep the note", function()
		for _, size in ipairs({ { 401, 720, true }, { 1069, 501, false } }) do
			local layout = Layout.compute(size[1], size[2], { touch = size[3] })
			local panel = View.panel(size[1], size[2], layout.rects.chip)
			local area = View.listArea(panel, false)
			equal(area.showNote, true); assert(area.height >= 120)
		end
	end)

	case("CV-C7: a sideways phone drops the section headers and keeps three rows in view", function()
		equal(View.showSectionHeaders(true), false); equal(View.showSectionHeaders(false), true)
		equal(View.COMPACT_GAP, 4)
		for _, size in ipairs({ { 705, 280 }, { 750, 323 } }) do
			local layout = Layout.compute(size[1], size[2], { touch = true })
			local panel = View.panel(size[1], size[2], layout.rects.chip)
			local area = View.listArea(panel, true)
			local rows = compactRows({}, { atCamp = true })
			local used = 2 * View.COMPACT_GAP
			for index = 1, 3 do used += View.rowHeight(rows[index], panel.w - 24 - 6, 13, true) end
			assert(used <= area.height, size[1] .. ": the first three rows need " .. used .. " of " .. area.height)
		end
	end)

	case("CV-H1: the header has a Menu button next to Bag and Camp, 44 pixels or more, on nine viewports", function()
		for _, size in ipairs(VIEWPORTS) do
			local layout = Layout.compute(size[1], size[2], { touch = size[1] < 1000 })
			local panel = View.panel(size[1], size[2], layout.rects.chip)
			local header = View.header(panel.w)
			local label = size[1] .. "x" .. size[2]
			local names = { "bag", "camp", "menu", "close" }
			for index, name in ipairs(names) do
				local button = header[name]
				assert(button, label .. " has no " .. name)
				assert(button.w >= 44 and button.h >= 44, label .. " " .. name .. " is " .. button.w .. "x" .. button.h)
				assert(button.x >= 0 and button.x + button.w <= panel.w, label .. " " .. name .. " is outside the panel")
				for other = index + 1, #names do
					equal(Layout.overlapArea(button, header[names[other]]), 0, label .. " " .. name .. " and " .. names[other])
				end
			end
		end
	end)

	case("the module is pure: no services, clock, randomness or persistence", function()
		for _, word in ipairs({ "game", "GetService", "os.", "tick", "Random", "math.random", "DataStore",
			"task.", "workspace", "Instance", "MarketplaceService", "Robux", "TextService" }) do
			equal(source:find(word, 1, true), nil, "source mentions " .. word)
		end
	end)

	return result
end

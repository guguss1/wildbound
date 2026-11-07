-- Invoke with require(freshTestClone)(require(freshLayoutClone), require(freshViewClone), freshLayoutClone.Source).
-- Pure geometry: viewport size in, rectangles out. No instance is read or written here.
return function(Layout, View, source)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected)
		assert(actual == expected, "Expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local NAN, INF = 0 / 0, math.huge

	-- Viewports as the baseline measured them (Device Simulator), plus desktop and tablet. The first two
	-- phone rows are the interface sizes a client really gets: the viewport minus the 58 pixel top inset.
	local DEVICES = {
		{ name = "iPhone 17 Pro landscape", w = 750, h = 381, touch = true, mode = "compact" },
		{ name = "iPhone 17 Pro portrait", w = 401, h = 778, touch = true, mode = "compact" },
		{ name = "Galaxy A06 landscape", w = 705, h = 338, touch = true, mode = "compact" },
		{ name = "Galaxy A06 portrait", w = 359, h = 718, touch = true, mode = "compact" },
		{ name = "iPhone 17 Pro landscape interface", w = 750, h = 323, touch = true, mode = "compact" },
		{ name = "Galaxy A06 landscape interface", w = 705, h = 280, touch = true, mode = "compact" },
		{ name = "Studio desktop", w = 1094, h = 558, touch = false, mode = "desktop" },
		{ name = "desktop 1366", w = 1366, h = 768, touch = false, mode = "desktop" },
		{ name = "desktop 1920", w = 1920, h = 1080, touch = false, mode = "desktop" },
		{ name = "tablet landscape", w = 1024, h = 768, touch = true, mode = "compact" },
		{ name = "small desktop window", w = 800, h = 600, touch = false, mode = "compact" },
		{ name = "iPhone 17 Pro portrait interface", w = 401, h = 720, touch = true, mode = "compact" },
		{ name = "Galaxy A06 portrait interface", w = 359, h = 660, touch = true, mode = "compact" },
	}
	local function layoutOf(device)
		return Layout.compute(device.w, device.h, { touch = device.touch })
	end
	local function area(a, b) return Layout.overlapArea(a, b) end

	case("every device gets a layout with no rule broken", function()
		for _, device in ipairs(DEVICES) do
			local violations = Layout.check(layoutOf(device))
			assert(#violations == 0, device.name .. ": " .. table.concat(violations, "; "))
		end
	end)

	case("the layout mode follows size and touch", function()
		for _, device in ipairs(DEVICES) do equal(layoutOf(device).mode, device.mode) end
		equal(layoutOf(DEVICES[1]).portrait, false)
		equal(layoutOf(DEVICES[2]).portrait, true)
	end)

	case("the zones are the documented hypotheses for the iPhone landscape viewport", function()
		local zones = layoutOf(DEVICES[1]).zones
		equal(zones.thumbstick.x, 0); equal(zones.thumbstick.w, 300)
		equal(zones.thumbstick.y, 381 / 3); equal(zones.thumbstick.h, 381 * 2 / 3)
		equal(zones.jump.x, 750 - 103); equal(zones.jump.y, 381 - 98)
		equal(zones.keepout.x + zones.keepout.w / 2, 375); equal(zones.keepout.y + zones.keepout.h / 2, 190.5)
	end)

	case("on a phone the HUD panels stay under 36 percent of the width where they were 57", function()
		for _, device in ipairs({ DEVICES[1], DEVICES[3], DEVICES[5], DEVICES[6] }) do
			local layout = layoutOf(device)
			for _, name in ipairs({ "hud", "panel" }) do
				local rect = layout.rects[name]
				assert((rect.x + rect.w) / device.w <= 0.36, device.name .. " " .. name .. " reaches "
					.. (rect.x + rect.w) / device.w)
			end
		end
	end)

	case("the avatar centre is never covered, on any device", function()
		for _, device in ipairs(DEVICES) do
			local layout = layoutOf(device)
			local cx, cy = device.w / 2, device.h / 2
			for name, rect in pairs(layout.rects) do
				assert(not (cx >= rect.x and cx <= rect.x + rect.w and cy >= rect.y and cy <= rect.y + rect.h),
					device.name .. ": " .. name .. " covers the avatar centre")
				assert(area(rect, layout.zones.keepout) == 0, device.name .. ": " .. name .. " enters the avatar keep-out")
			end
		end
	end)

	case("every control is at least 44 by 44, on every device", function()
		for _, device in ipairs(DEVICES) do
			local layout = layoutOf(device)
			for _, name in ipairs(Layout.TOUCH_TARGETS) do
				local rect = layout.rects[name]
				assert(rect.w >= 44 and rect.h >= 44, device.name .. ": " .. name .. " is " .. rect.w .. "x" .. rect.h)
			end
		end
		equal(Layout.MIN_TARGET, 44)
	end)

	case("on a phone nothing sits in the thumbstick zone or on the jump button, where the old controls did", function()
		for _, device in ipairs({ DEVICES[1], DEVICES[2], DEVICES[3], DEVICES[4], DEVICES[5], DEVICES[6], DEVICES[10] }) do
			local layout = layoutOf(device)
			for name, rect in pairs(layout.rects) do
				equal(area(rect, layout.zones.thumbstick), 0)
				equal(area(rect, layout.zones.jump), 0)
			end
		end
	end)

	case("everything stays inside the viewport with a margin", function()
		for _, device in ipairs(DEVICES) do
			local layout = layoutOf(device)
			for name, rect in pairs(layout.rects) do
				assert(rect.x >= 4 and rect.y >= 4, device.name .. ": " .. name .. " starts off screen")
				assert(rect.x + rect.w <= device.w - 4 and rect.y + rect.h <= device.h - 4,
					device.name .. ": " .. name .. " runs off screen")
			end
		end
	end)

	case("no two elements overlap, except the effects button inside the desktop panel", function()
		for _, device in ipairs(DEVICES) do
			local layout = layoutOf(device)
			for _, first in ipairs(Layout.ELEMENTS) do
				for _, second in ipairs(Layout.ELEMENTS) do
					if first < second and not (layout.mode == "desktop" and
						((first == "effects" and second == "panel") or (first == "panel" and second == "effects"))) then
						assert(area(layout.rects[first], layout.rects[second]) == 0,
							device.name .. ": " .. first .. " overlaps " .. second)
					end
				end
			end
		end
	end)

	case("desktop keeps today's geometry, so desktop stays good", function()
		local layout = Layout.compute(1094, 558, { touch = false })
		local rects = layout.rects
		equal(rects.hud.x, 12); equal(rects.hud.y, 12); equal(rects.hud.w, 430); equal(rects.hud.h, 82)
		equal(rects.panel.x, 12); equal(rects.panel.y, 100); equal(rects.panel.w, 400); equal(rects.panel.h, 92)
		equal(rects.inventory.w, 132); equal(rects.inventory.h, 44); equal(rects.inventory.x, 1094 - 12 - 132)
		equal(rects.inventory.y, 12)
		equal(rects.flashlight.w, 110); equal(rects.flashlight.h, 44)
		equal(rects.flashlight.x, 1094 / 2 - 114); equal(rects.pulse.x, 1094 / 2 + 4)
		equal(rects.flashlight.y, 558 - 90 - 44)
		equal(rects.effects.w, 126); equal(rects.effects.h, 44)
		equal(rects.effects.x, rects.panel.x + rects.panel.w - 126)
		equal(rects.effects.y, rects.panel.y)
	end)

	case("the desktop HUD never exceeds what it had on a narrow desktop window", function()
		local layout = Layout.compute(1000, 600, { touch = false })
		equal(layout.mode, "desktop")
		assert(layout.rects.hud.w <= 430 and layout.rects.panel.w <= 400, "panels must not grow")
	end)

	case("the chip fits between the panels and the inventory button on desktop widths", function()
		for width = 1000, 2560, 40 do
			local layout = Layout.compute(width, 700, { touch = false })
			local violations = Layout.check(layout)
			assert(#violations == 0, width .. ": " .. table.concat(violations, "; "))
			assert(layout.rects.chip.w >= 240, width .. ": chip too narrow " .. layout.rects.chip.w)
		end
	end)

	case("a sweep of phone landscape sizes keeps every rule", function()
		for width = 640, 932, 26 do
			for height = 280, 440, 20 do
				local violations = Layout.check(Layout.compute(width, height, { touch = true }))
				assert(#violations == 0, width .. "x" .. height .. ": " .. table.concat(violations, "; "))
			end
		end
	end)

	case("a sweep of phone portrait sizes keeps every rule", function()
		for width = 320, 440, 20 do
			for height = 640, 960, 40 do
				local violations = Layout.check(Layout.compute(width, height, { touch = true }))
				assert(#violations == 0, width .. "x" .. height .. ": " .. table.concat(violations, "; "))
			end
		end
	end)

	case("a very short landscape view moves the effects toggle to a second column, not onto the jump button", function()
		local layout = Layout.compute(705, 280, { touch = true })
		local violations = Layout.check(layout)
		assert(#violations == 0, table.concat(violations, "; "))
		assert(layout.rects.effects.x < layout.rects.inventory.x, "the overflow must use a second column")
		equal(layout.rects.flashlight.x, layout.rects.pulse.x)
	end)

	case("the check finds a panel on the avatar, a small target, an overlap and an off-screen rect", function()
		local layout = Layout.compute(750, 381, { touch = true })
		local function broken(name, rect)
			local copy = { mode = layout.mode, width = layout.width, height = layout.height, zones = layout.zones, rects = {} }
			for key, value in pairs(layout.rects) do copy.rects[key] = value end
			copy.rects[name] = rect
			return Layout.check(copy)
		end
		local onAvatar = broken("panel", { x = 300, y = 120, w = 150, h = 50 })
		assert(#onAvatar > 0 and table.concat(onAvatar, ";"):find("keep"), "must report the avatar keep-out")
		local small = broken("pulse", { x = layout.rects.pulse.x, y = layout.rects.pulse.y, w = 110, h = 36 })
		assert(table.concat(small, ";"):find("44"), "must report a target under 44")
		local overlap = broken("effects", layout.rects.flashlight)
		assert(table.concat(overlap, ";"):find("overlap"), "must report an overlap")
		local outside = broken("chip", { x = 700, y = 8, w = 120, h = 40 })
		assert(table.concat(outside, ";"):find("screen"), "must report an off-screen rect")
		local thumb = broken("flashlight", { x = 20, y = 200, w = 110, h = 44 })
		assert(table.concat(thumb, ";"):find("thumbstick"), "must report the thumbstick zone")
		local jump = broken("pulse", { x = 660, y = 300, w = 70, h = 44 })
		assert(table.concat(jump, ";"):find("jump"), "must report the jump zone")
	end)

	case("the check itself fails closed on a broken layout table", function()
		assert(#Layout.check(nil) > 0)
		assert(#Layout.check({}) > 0)
		assert(#Layout.check({ rects = {}, zones = {}, width = 1, height = 1 }) > 0)
	end)

	case("text budgets grow with width and lines, and never drop under one", function()
		assert(Layout.charBudget(200, 13, 1) < Layout.charBudget(300, 13, 1))
		assert(Layout.charBudget(200, 13, 1) < Layout.charBudget(200, 13, 2))
		assert(Layout.charBudget(200, 13, 1) > Layout.charBudget(200, 16, 1))
		equal(Layout.charBudget(1, 13, 1), 1)
		equal(Layout.charBudget(NAN, 13, 1), 1)
		equal(Layout.charBudget(200, 0, 1), 1)
		equal(Layout.charBudget(200, 13, 0), 1)
	end)

	case("every phone hint and chip text fits the room the layout gives it", function()
		local hints = { "Attack incoming: move away!", "Threat nearby: move toward shelter.", "Silueta revealed. Keep moving.",
			"Dusk: night is approaching.", "Fog forest: stay alert.", "Explore or return to camp." }
		for _, device in ipairs({ DEVICES[1], DEVICES[2], DEVICES[3], DEVICES[4], DEVICES[5], DEVICES[6] }) do
			local layout = layoutOf(device)
			local twoLines = Layout.charBudget(layout.rects.panel.w - 16, 13, 2)
			for _, text in ipairs(hints) do
				assert(#text <= twoLines, device.name .. ": '" .. text .. "' needs " .. #text .. ", room " .. twoLines)
			end
			local chipRoom = Layout.charBudget(layout.rects.chip.w - Layout.CHIP_TEXT_INSET, 14, 1)
			assert(chipRoom >= View.CONSTANTS.COMPACT_CHIP_CHARS, device.name .. ": chip room " .. chipRoom)
			for _, text in ipairs({ "Revealed 4 s. Keep moving.", "Missed. Move closer, face it.", "Not available right now." }) do
				assert(#text <= twoLines, device.name .. ": notice '" .. text .. "'")
			end
		end
	end)

	case("desktop chip text has room for the full wording", function()
		local layout = Layout.compute(1094, 558, { touch = false })
		local room = Layout.charBudget(layout.rects.chip.w - Layout.CHIP_TEXT_INSET, 15, 1)
		assert(room >= View.CONSTANTS.CHIP_CHARS, "chip room " .. room)
	end)

	case("bad sizes fall back to a safe desktop layout instead of erroring", function()
		for _, bad in ipairs({ NAN, INF, -5, 0, "700", false }) do
			local layout = Layout.compute(bad, 500, {})
			assert(#Layout.check(layout) == 0, "fallback must satisfy every rule")
			layout = Layout.compute(900, bad, nil)
			assert(#Layout.check(layout) == 0, "fallback must satisfy every rule")
		end
		assert(#Layout.check(Layout.compute(nil, nil, nil)) == 0)
	end)

	case("each call returns fresh tables", function()
		local first = Layout.compute(750, 381, { touch = true })
		first.rects.chip.x = -999
		equal(Layout.compute(750, 381, { touch = true }).rects.chip.x > 0, true)
	end)

	case("the module source stays pure", function()
		assert(type(source) == "string" and #source > 0, "module source is required")
		for _, token in ipairs({ "game", "workspace", "script", "Instance", "require", "task", "tick",
			"wait", "os", "time", "GetService", "Players", "UserInputService", "Vector2", "UDim2",
			"DateTime", "math%.random", "Random" }) do
			assert(not string.find(source, "%f[%w_]" .. token .. "%f[^%w_]"), "impure token: " .. token)
		end
	end)

	return result
end

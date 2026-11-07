-- Invoke with require(freshTestClone)(require(freshViewClone), freshViewClone.Source) in Studio.
-- Pure view-models for the Wildbound HUD: chip, hint, notice expiry, text fitting. Time is injected.
return function(View, source)
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
	local function near(actual, expected, tolerance)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-6),
			"Expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local NAN, INF = 0 / 0, math.huge
	local CONST = View.CONSTANTS

	local function chip(awareness, compact, now)
		return View.chip(awareness, true, now or 100, compact == true)
	end
	local SEEN = { state = "seen" }
	local ATTACK = { state = "seen", attackEndsAt = 101.4 }
	local SEARCH = { state = "searching", searchEndsAt = 101.5 }
	local ALLY = { state = "ally" }
	local NONE = { state = "none" }

	-- The chip says who is hunted with text and a shape. Hue alone is never the cue.
	case("each state reads as a distinct word and a distinct shape", function()
		local seen, attack, search, ally, none = chip(SEEN), chip(ATTACK), chip(SEARCH), chip(ALLY), chip(NONE)
		local shapes, texts = {}, {}
		for name, entry in pairs({ seen = seen, attack = attack, search = search, ally = ally, none = none }) do
			assert(type(entry.shape) == "string" and entry.shape ~= "", name .. " needs a shape")
			assert(type(entry.text) == "string" and #entry.text > 0, name .. " needs text")
			assert(type(entry.glyph) == "string" and #entry.glyph > 0, name .. " needs a glyph")
			assert(not shapes[entry.shape], name .. " repeats a shape: " .. entry.shape)
			assert(not texts[entry.text], name .. " repeats a text: " .. entry.text)
			shapes[entry.shape], texts[entry.text] = true, true
		end
		equal(seen.state, "seen"); equal(attack.state, "seen"); equal(search.state, "searching")
		equal(ally.state, "ally"); equal(none.state, "none")
	end)

	case("the words say what to do, not who is who in code terms", function()
		assert(chip(SEEN).text:find("sees you"), "seen must say it sees you")
		assert(chip(ALLY).text:lower():find("friend"), "ally must name a friend")
		assert(chip(SEARCH).text:lower():find("searching"), "searching must say searching")
		assert(chip(NONE).text:lower():find("no hunt"), "none must say there is no hunt")
		assert(chip(ATTACK).text:find("ATTACK"), "attack must say attack")
	end)

	case("an attack deadline in the future shows the attack warning, past or absent does not", function()
		equal(chip(ATTACK).attack, true)
		equal(chip({ state = "seen", attackEndsAt = 100 }).attack, false)
		equal(chip({ state = "seen", attackEndsAt = 99 }).attack, false)
		equal(chip(SEEN).attack, false)
		equal(chip({ state = "seen", attackEndsAt = NAN }).attack, false)
		equal(chip({ state = "seen", attackEndsAt = "101" }).attack, false)
		equal(chip({ state = "searching", attackEndsAt = 200, searchEndsAt = 101 }).attack, false)
	end)

	case("searching shows a countdown with one decimal that never goes negative", function()
		assert(chip(SEARCH).text:find("1%.5s"), chip(SEARCH).text)
		equal(chip(SEARCH).seconds, 1.5)
		assert(chip({ state = "searching", searchEndsAt = 100.04 }).text:find("0%.0s"), "0.04 rounds to 0.0")
		equal(chip({ state = "searching", searchEndsAt = 90 }).seconds, 0)
		assert(chip({ state = "searching", searchEndsAt = 90 }).text:find("0%.0s"), "expired countdown clamps at zero")
	end)

	case("searching without a usable deadline still says searching, with no number", function()
		for _, bad in ipairs({ NAN, INF, "1", false }) do
			local entry = chip({ state = "searching", searchEndsAt = bad })
			equal(entry.state, "searching"); equal(entry.seconds, nil)
			assert(not entry.text:find("%d"), "no digits without a deadline")
		end
		equal(chip({ state = "searching" }).seconds, nil)
	end)

	case("a stale or missing world state shows the waiting chip, never an old warning", function()
		local stale = View.chip(ATTACK, false, 100, false)
		equal(stale.state, "unknown"); equal(stale.attack, false)
		assert(stale.text:find("Waiting"), stale.text)
		equal(View.chip(nil, true, 100, false).state, "none")
		equal(View.chip(ATTACK, true, nil, false).state, "unknown")
		equal(View.chip(ATTACK, true, NAN, false).state, "unknown")
		equal(View.chip(ATTACK, true, "100", false).state, "unknown")
	end)

	case("bad awareness values fail closed to none", function()
		for _, bad in ipairs({ 5, "seen", true, {}, { state = 3 }, { state = "owned" }, { state = "SEEN" } }) do
			equal(View.chip(bad, true, 100, false).state, "none")
		end
	end)

	case("full text fits the chip and compact text fits the narrow phone chip", function()
		for _, awareness in ipairs({ SEEN, ATTACK, SEARCH, ALLY, NONE }) do
			assert(#chip(awareness, false).text <= CONST.CHIP_CHARS, chip(awareness, false).text)
			assert(#chip(awareness, true).text <= CONST.COMPACT_CHIP_CHARS, chip(awareness, true).text)
		end
		local stale = View.chip(SEEN, false, 100, true)
		assert(#stale.text <= CONST.COMPACT_CHIP_CHARS, stale.text)
		assert(#View.chip(SEEN, false, 100, false).text <= CONST.CHIP_CHARS)
		-- A longest countdown still fits.
		local long = View.chip({ state = "searching", searchEndsAt = 101.5 }, true, 100, true)
		assert(#long.text <= CONST.COMPACT_CHIP_CHARS, long.text)
	end)

	case("compact wording is shorter or equal, never a different meaning", function()
		equal(chip(ALLY, true).state, "ally"); equal(chip(SEARCH, true).state, "searching")
		assert(chip(ATTACK, true).text:find("ATTACK"), "compact attack keeps its word")
		assert(chip(SEARCH, true).text:find("1%.5s"), "compact search keeps its countdown")
		assert(chip(ALLY, true).text:lower():find("friend"), "compact ally keeps its word")
	end)

	-- Colour is a redundant cue only, but it must still be readable.
	local function channel(value)
		value = value / 255
		return value <= 0.03928 and value / 12.92 or ((value + 0.055) / 1.055) ^ 2.4
	end
	local function luminance(color)
		return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b)
	end
	local function contrast(a, b)
		local la, lb = luminance(a), luminance(b)
		return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
	end

	case("every chip tone has text with at least 4.5:1 contrast", function()
		local count = 0
		for name, tone in pairs(View.TONES) do
			count += 1
			assert(contrast(tone.text, tone.bg) >= 4.5, name .. " contrast " .. contrast(tone.text, tone.bg))
			assert(tone.transparency >= 0 and tone.transparency < 0.6, name .. " must stay solid enough")
		end
		assert(count >= 5, "expected a tone per state")
	end)

	case("every chip names a tone that exists, and seen is amber", function()
		for _, awareness in ipairs({ SEEN, ATTACK, SEARCH, ALLY, NONE }) do
			assert(View.TONES[chip(awareness).tone], "unknown tone " .. tostring(chip(awareness).tone))
		end
		assert(View.TONES[View.chip(SEEN, false, 100, false).tone], "stale tone must exist")
		local amber = View.TONES[chip(SEEN).tone].bg
		assert(amber.r > 200 and amber.r > amber.g and amber.g > amber.b + 40, "seen is amber")
		assert(chip(SEEN).tone ~= chip(ATTACK).tone, "attack is a different tone from seen")
	end)

	case("the chip table is fresh each call", function()
		local first = chip(SEEN)
		first.text, first.shape = "changed", "x"
		assert(chip(SEEN).text ~= "changed" and chip(SEEN).shape ~= "x", "chip results must not be shared")
	end)

	-- Hints for the panel line.
	local function hint(overrides, compact)
		local info = { attack = false, threat = false, revealed = false, phase = "Day", isFog = false }
		for key, value in pairs(overrides or {}) do info[key] = value end
		return View.hint(info)
	end

	case("the hint follows the old priority: attack, threat, revealed, dusk, fog, calm", function()
		equal(hint({ attack = true, threat = true, revealed = true }), "Attack incoming: move away!")
		equal(hint({ threat = true, revealed = true }), "Threat nearby: move toward shelter.")
		equal(hint({ revealed = true, phase = "Dusk", isFog = true }), "Silueta revealed. Keep moving.")
		equal(hint({ phase = "Dusk", isFog = true }), "Dusk: night is approaching.")
		equal(hint({ isFog = true }), "Fog forest: stay alert.")
		equal(hint({}), "Explore or return to camp.")
	end)

	case("every hint fits a two line phone budget of 50 characters", function()
		for _, overrides in ipairs({ { attack = true }, { threat = true }, { revealed = true },
			{ phase = "Dusk" }, { isFog = true }, {} }) do
			assert(#hint(overrides) <= 50, hint(overrides))
		end
	end)

	case("a garbage hint input never errors and gives the calm line", function()
		equal(View.hint(nil), "Explore or return to camp.")
		equal(View.hint("x"), "Explore or return to camp.")
		equal(View.hint({ attack = "yes", threat = 1, revealed = {} }), "Explore or return to camp.")
	end)

	-- Notice expiry: a line shows for a while, then goes.
	case("a notice shows, then expires exactly at the limit", function()
		local notice = View.newNotice()
		equal(View.currentNotice(notice, 0), nil)
		View.setNotice(notice, "Revealed 4 s.", 10)
		equal(View.currentNotice(notice, 10), "Revealed 4 s.")
		equal(View.currentNotice(notice, 10 + CONST.NOTICE_SECONDS - 0.01), "Revealed 4 s.")
		equal(View.currentNotice(notice, 10 + CONST.NOTICE_SECONDS), nil)
		equal(View.currentNotice(notice, 10), nil, "an expired notice never comes back")
	end)

	case("a new notice replaces the old one and restarts the limit", function()
		local notice = View.newNotice()
		View.setNotice(notice, "first", 0)
		View.setNotice(notice, "second", 4)
		equal(View.currentNotice(notice, 4 + CONST.NOTICE_SECONDS - 0.01), "second")
		equal(View.currentNotice(notice, 4 + CONST.NOTICE_SECONDS), nil)
	end)

	case("an empty or non-text notice does not clear or replace what is showing", function()
		local notice = View.newNotice()
		View.setNotice(notice, "kept", 0)
		for _, bad in ipairs({ "", 5, false, {}, NAN }) do View.setNotice(notice, bad, 1) end
		equal(View.currentNotice(notice, 2), "kept")
		View.setNotice(notice, "x", NAN)
		equal(View.currentNotice(notice, 2), "kept")
	end)

	case("a clock that steps back expires the notice instead of showing it for ever", function()
		local notice = View.newNotice()
		View.setNotice(notice, "stale", 100)
		equal(View.currentNotice(notice, 50), nil)
		equal(View.currentNotice(notice, 101), nil)
	end)

	case("a bad clock reads no notice", function()
		local notice = View.newNotice()
		View.setNotice(notice, "x", 0)
		for _, bad in ipairs({ NAN, INF, "1", false }) do equal(View.currentNotice(notice, bad), nil) end
		equal(View.currentNotice(nil, 0), nil)
	end)

	case("the notice limit is long enough to read and short enough to be fresh", function()
		assert(CONST.NOTICE_SECONDS >= 4 and CONST.NOTICE_SECONDS <= 10, "limit must stay between 4 and 10 s")
	end)

	case("small screens pick the short form when the server sent one", function()
		local payload = { notice = "Silueta revealed for 4 seconds. Keep moving; it is not defeated.",
			noticeShort = "Revealed 4 s. Keep moving." }
		equal(View.pickNotice(payload, true), "Revealed 4 s. Keep moving.")
		equal(View.pickNotice(payload, false), payload.notice)
		equal(View.pickNotice({ notice = "Only long." }, true), "Only long.")
		equal(View.pickNotice({ notice = "Long.", noticeShort = "" }, true), "Long.")
		equal(View.pickNotice({ noticeShort = "Short." }, false), "")
		equal(View.pickNotice(nil, true), "")
		equal(View.pickNotice({ notice = 5, noticeShort = false }, true), "")
	end)

	-- Fitting: collapse a long line instead of shrinking it or clipping it.
	case("a line that fits is returned unchanged", function()
		equal(View.fit("Bag full.", 30), "Bag full.")
		equal(View.fit("", 30), "")
		equal(View.fit("exactly ten", 11), "exactly ten")
	end)

	case("a long line keeps the longest whole sentence that fits", function()
		equal(View.fit("In your inventory, choose a temporary item and press Protect. One item maximum.", 62),
			"In your inventory, choose a temporary item and press Protect.")
		equal(View.fit("Selected item protected for one defeat. Seal is spent only if it saves the item.", 54),
			"Selected item protected for one defeat.")
	end)

	case("with no sentence that fits it cuts at a word and says so", function()
		local out = View.fit("Collect the glowing creatures while the fog is thin and return before night", 30)
		assert(#out <= 30, "too long: " .. #out)
		assert(out:sub(-3) == "...", out)
		assert(not out:find("%s%.%.%.$"), "no space before the dots")
		assert(out:find("^Collect the glowing"), out)
	end)

	case("fit never exceeds its budget and survives tiny budgets and bad input", function()
		for _, budget in ipairs({ 1, 2, 3, 4, 5, 8, 12, 40 }) do
			local out = View.fit("A very long unbroken sentence that keeps going without any end", budget)
			assert(#out <= budget, ("budget %d gave %d"):format(budget, #out))
		end
		equal(View.fit("x", 0), "")
		equal(View.fit(nil, 10), "")
		equal(View.fit(12, 10), "")
		equal(View.fit("abc", NAN), "")
		equal(#View.fit("Supercalifragilisticexpialidocious", 10) <= 10, true)
	end)

	-- The companion must never white out the view.
	case("the companion fades as the camera gets close and never disappears or whitens", function()
		local far, near2, mid = View.companionTransparency(20), View.companionTransparency(1), View.companionTransparency(5.5)
		assert(far >= 0 and far <= 0.2, "far stays solid")
		assert(near2 >= 0.8 and near2 < 1, "close fades but is not invisible")
		assert(mid > far and mid < near2, "the fade is gradual")
		near(View.companionTransparency(CONST.COMPANION_FADE_START), far, 1e-9)
		near(View.companionTransparency(CONST.COMPANION_FADE_END), near2, 1e-9)
		local previous = -1
		for distance = 12, 0, -0.5 do
			local value = View.companionTransparency(distance)
			assert(value >= previous - 1e-9, "fade must never reverse as the camera nears")
			previous = value
		end
	end)

	case("a bad camera distance leaves the companion at its base look", function()
		local base = View.companionTransparency(100)
		for _, bad in ipairs({ NAN, INF, -INF, "3", false }) do equal(View.companionTransparency(bad), base) end
		equal(View.companionTransparency(nil), base)
		equal(View.companionTransparency(-5), View.companionTransparency(0))
	end)

	case("the module source stays pure", function()
		assert(type(source) == "string" and #source > 0, "module source is required")
		for _, token in ipairs({ "game", "workspace", "script", "Instance", "require", "task", "tick",
			"wait", "os", "time", "GetService", "Players", "RemoteEvent", "FireClient", "CFrame",
			"Vector3", "Color3", "UDim2", "DateTime", "math%.random", "Random" }) do
			assert(not string.find(source, "%f[%w_]" .. token .. "%f[^%w_]"), "impure token: " .. token)
		end
	end)

	return result
end

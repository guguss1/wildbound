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

	-- W6 audit: the server resolves the strike up to one 0.2 s step after the deadline, so a chip that
	-- dropped at the deadline left the player reading "sees you" while the strike could still land.
	case("the attack warning holds past its deadline until the server resolves or cancels it", function()
		equal(chip(ATTACK).attack, true)
		equal(chip({ state = "seen", attackEndsAt = 100 }).attack, true)
		equal(chip({ state = "seen", attackEndsAt = 99.78 }).attack, true)
		equal(chip({ state = "seen", attackEndsAt = 99.78 }, false, 100.22).text, chip(ATTACK).text)
		equal(View.attackPending({ state = "seen", attackEndsAt = 99 }), true)
		equal(View.attackPending(SEEN), false)
		equal(View.attackPending({ state = "searching", attackEndsAt = 99 }), false)
		equal(View.attackPending({ state = "seen", attackEndsAt = 0 }), false)
		equal(View.attackPending(nil), false)
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

	-- W6 audit: the client asked for a new chip table and key string every Heartbeat.
	case("the cached chip is the same table while nothing visible changes", function()
		local cache = View.newChipCache()
		local first = View.chipCached(cache, SEEN, true, 100, false)
		assert(rawequal(first, View.chipCached(cache, SEEN, true, 100.5, false)), "seen must not reallocate")
		assert(rawequal(first, View.chipCached(cache, { state = "seen" }, true, 101, false)), "same words, same chip")
		local search = View.chipCached(cache, SEARCH, true, 100, false)
		assert(not rawequal(first, search), "a new state must give a new chip")
		assert(rawequal(search, View.chipCached(cache, SEARCH, true, 100.01, false)), "same tenth, same chip")
		local later = View.chipCached(cache, SEARCH, true, 100.2, false)
		assert(not rawequal(search, later), "a visible countdown change gives a new chip")
		equal(later.text, View.chip(SEARCH, true, 100.2, false).text)
	end)
	case("the cached chip changes with freshness, size and a new snapshot", function()
		local cache = View.newChipCache()
		local base = View.chipCached(cache, SEEN, true, 100, false)
		local stale = View.chipCached(cache, SEEN, false, 100, false)
		assert(not rawequal(base, stale), "stale must change the chip"); equal(stale.kind, "unknown")
		local compact = View.chipCached(cache, SEEN, true, 100, true)
		assert(not rawequal(stale, compact), "size must change the chip")
		local other = View.chipCached(cache, { state = "ally" }, true, 100, true)
		equal(other.kind, "ally")
		equal(View.chipCached(nil, SEEN, true, 100, false).kind, "seen")
		local full = View.chipCached(cache, ATTACK, true, 100, false)
		equal(View.chipCached(cache, ATTACK, true, 100, true).text, View.chip(ATTACK, true, 100, true).text)
		assert(full.text ~= View.chipCached(cache, ATTACK, true, 100, true).text, "size alone must change the chip")
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

	case("M5.3 Night outside the fog says why to go there, and danger lines still come first", function()
		equal(hint({ phase = "Night" }), "Night: Nightbloom blooms in the fog.")
		equal(hint({ phase = "Night", isFog = true }), "Fog forest: stay alert.")
		equal(hint({ phase = "Night", threat = true }), "Threat nearby: move toward shelter.")
		equal(hint({ phase = "Night", attack = true }), "Attack incoming: move away!")
		assert(#hint({ phase = "Night" }) <= 50, "fits the two line phone budget")
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

	-- M4.6 defeat flow: a full-screen summary before respawn, in plain words.
	case("the loss summary names what was lost, saved and kept", function()
		local text = View.lossSummary({ operationId = "life:2",
			lostItems = { { uid = "a", kind = "Egg", species = "Lumipol" }, { uid = "b", kind = "Creature", species = "Lumipol" } },
			savedItem = { uid = "c", kind = "Creature", species = "Lumipol" }, materialsLost = {},
			kept = { registered = 2, bankedEggs = 1, ember = 0, bankedMaterials = 0 } })
		assert(text:find("Defeated", 1, true), "says defeated")
		assert(text:find("Lost 2 items: Lumipol egg, Lumipol.", 1, true), "lists the losses: " .. text)
		assert(text:find("Saved by your seal: Lumipol.", 1, true), "names the saved item")
		assert(text:find("Kept: 2 registered, 1 banked egg.", 1, true), "names what is kept: " .. text)
		assert(text:find("Tap to close", 1, true), "says how to close")
	end)
	case("M5.8 the loss summary names lost materials, a Nightbloom bundle, every saved item and what is safe", function()
		local text = View.lossSummary({ operationId = "life:3",
			lostItems = { { uid = "n", kind = "Nightbloom", quantity = 2 }, { uid = "a", kind = "Egg", species = "Lumipol" } },
			savedItems = { { uid = "c", kind = "Creature", species = "Lumipol" }, { uid = "d", kind = "Egg", species = "Lumipol" } },
			materialsLost = { glowmoss = 3, fogbark = 13 },
			kept = { registered = 1, bankedEggs = 0, ember = 20, bankedMaterials = 5 } })
		assert(text:find("Lost 2 items: Nightbloom bundle (2), Lumipol egg.", 1, true), text)
		assert(text:find("Lost materials: 13 Fogbark, 3 Glowmoss.", 1, true), text)
		assert(text:find("Saved by seal or totem: Lumipol, Lumipol egg.", 1, true), text)
		assert(text:find("Kept: 1 registered, 0 banked eggs.", 1, true), text)
		assert(text:find("Safe: 20 Ember, 5 banked materials.", 1, true), text)
		assert(#text < 420, "still short: " .. #text)
		local plain = View.lossSummary({ lostItems = {}, materialsLost = {}, kept = { registered = 0, bankedEggs = 0, ember = 0, bankedMaterials = 0 } })
		assert(not plain:find("Lost materials", 1, true) and not plain:find("Safe:", 1, true) and not plain:find("Saved", 1, true), plain)
		assert(View.lossSummary({ materialsLost = { fogbark = 0, glowmoss = "x" }, lostItems = {} }):find("Lost materials", 1, true) == nil)
	end)
	case("an empty, bad or huge loss summary still reads clearly and stays short", function()
		local text = View.lossSummary({ lostItems = {}, kept = { registered = 0, bankedEggs = 3 } })
		assert(text:find("Nothing was lost.", 1, true), text)
		assert(text:find("3 banked eggs", 1, true), text)
		for _, bad in ipairs({ 5, "x", { lostItems = "x" }, { lostItems = { 5, { kind = 5 } } } }) do
			local value = View.lossSummary(bad)
			assert(type(value) == "string" and value:find("Defeated", 1, true), "bad input still reads")
		end
		equal(type(View.lossSummary(nil)), "string")
		local many = {}
		for index = 1, 50 do many[index] = { uid = tostring(index), kind = "Egg", species = "Lumipol" } end
		local long = View.lossSummary({ lostItems = many, kept = {} })
		assert(long:find("Lost 50 items", 1, true) and long:find("and 45 more", 1, true), long)
		assert(#long < 300, "summary must stay short")
	end)

	case("D-C5: an optional words table writes the defeat screen in Spanish; English stays the default", function()
		local words = { title = "Derrotado.", nothing = "Nada perdido.", lost = "Perdiste %s: %s%s.", more = " y %d más",
			item = "objeto", items = "objetos", materials = "Materiales perdidos: %s.",
			materialNames = { fogbark = "Fogbark", glowmoss = "Glowmoss", nightbloom = "Nightbloom" },
			savedMany = "Salvado: %s.", savedOne = "Salvado por tu sello: %s.", kept = "Conservas: %d registrados, %s.",
			egg = "huevo guardado", eggs = "huevos guardados", safe = "A salvo: %d Ember, %s.", material = "material guardado",
			materialsWord = "materiales guardados", close = "Toca para cerrar.", eggName = "huevo de %s",
			bundle = "ramo de Nightbloom", bundleCount = "ramo de Nightbloom (%d)" }
		local text = View.lossSummary({ lostItems = { { kind = "Egg", species = "Lumipol" }, { kind = "Nightbloom", quantity = 2 } },
			materialsLost = { fogbark = 4 }, kept = { registered = 2, bankedEggs = 1, ember = 9, bankedMaterials = 3 } }, words)
		assert(text:find("Derrotado.", 1, true), text)
		assert(text:find("Perdiste 2 objetos: huevo de Lumipol, ramo de Nightbloom (2).", 1, true), text)
		assert(text:find("Materiales perdidos: 4 Fogbark.", 1, true), text)
		assert(text:find("Conservas: 2 registrados, 1 huevo guardado.", 1, true), text)
		assert(text:find("A salvo: 9 Ember, 3 materiales guardados.", 1, true), text)
		assert(text:find("Toca para cerrar.", 1, true), text)
		assert(not text:find("Defeated", 1, true) and not text:find("Tap", 1, true), "no English left: " .. text)
		local empty = View.lossSummary({ lostItems = {}, kept = {} }, words)
		assert(empty:find("Nada perdido.", 1, true), empty)
		assert(View.lossSummary({ lostItems = {} }, "bad"):find("Defeated", 1, true), "a bad table keeps English")
	end)
	case("delivery C: a landed strike flashes the screen, softer with reduced effects; a miss never flashes", function()
		local marked = View.hitFlash("Marked", false)
		local defeated = View.hitFlash("Defeated", false)
		local reduced = View.hitFlash("Marked", true)
		assert(marked and defeated and reduced, "landed strikes flash")
		assert(marked.seconds > 0 and marked.seconds <= 0.6, "short")
		-- Deliberately changed in delivery D11: a defeat no longer flashes red; it fades to dark (see the D11 cases).
		equal(defeated.kind, "fade", "a defeat fades")
		assert(reduced.from > marked.from, "reduced effects flash softer")
		equal(marked.sound, "hit"); equal(defeated.sound, "defeat")
		for _, outcome in ipairs({ "Missed", "Spared", nil, 5 }) do equal(View.hitFlash(outcome, false), nil) end
	end)
	case("D11: defeat uses a fade of at least 0.5 s and no flash", function()
		local fade = View.hitFlash("Defeated", false)
		equal(fade.kind, "fade")
		assert(fade.seconds >= 0.5, "slow fade")
		equal(fade.from, 1, "starts clear, never a bright frame")
		assert(math.abs(fade.to - 0.15) < 1e-6, "ends at alpha 0.85")
		assert(fade.r <= 20 and fade.g <= 20 and fade.b <= 30, "dark, not red")
		equal(fade.sound, "defeat")
	end)
	case("D11: reduced uses 0.8 s at alpha 0.6", function()
		local fade = View.hitFlash("Defeated", true)
		equal(fade.kind, "fade")
		assert(math.abs(fade.seconds - 0.8) < 1e-6 and math.abs(fade.to - 0.4) < 1e-6, "0.8 s to alpha 0.6")
	end)
	case("D11: the marking hit still flashes", function()
		local flash = View.hitFlash("Marked", false)
		equal(flash.kind, "flash")
		equal(flash.to, 1, "the flash clears")
		assert(flash.r >= 150 and flash.g <= 40, "red")
		equal(flash.sound, "hit")
	end)
	case("the module source stays pure", function()
		assert(type(source) == "string" and #source > 0, "module source is required")
		for _, token in ipairs({ "game", "workspace", "script", "Instance", "require", "task", "tick",
			"wait", "os", "time", "GetService", "Players", "RemoteEvent", "FireClient", "CFrame",
			"Vector3", "Color3", "UDim2", "DateTime", "math%.random", "Random" }) do
			assert(not string.find(source, "%f[%w_]" .. token .. "%f[^%w_]"), "impure token: " .. token)
		end
	end)

	-- Chase pass (CP1, CP3): sprint is felt (a wider view, a Spanish hint per input) and a close hunting Silueta shakes
	-- the view and darkens the edges. "Efectos suaves" keeps a softer vignette and no shake.
	case("chase pass: sprint widens the view, softer with Efectos suaves", function()
		equal(View.sprintFov(70, "sprint", false), 80); equal(View.sprintFov(70, "sprint", true), 74)
		equal(View.sprintFov(70, "walk", false), 70); equal(View.sprintFov(70, "exhausted", false), 70)
		equal(View.sprintFov(NAN, "sprint", false), 80, "a bad base reads 70")
	end)
	case("chase pass: the sprint hint follows the input", function()
		local words = { hintKeyboard = "Shift: Correr", hintGamepad = "L3: Correr" }
		equal(View.sprintHint("keyboard", words), "Shift: Correr"); equal(View.sprintHint("gamepad", words), "L3: Correr")
		equal(View.sprintHint("touch", words), nil, "touch has the Correr button")
		equal(View.sprintHint("keyboard", nil), "Shift: Correr", "Spanish default without words")
	end)
	case("chase pass: dread grows as a hunting Silueta closes in", function()
		local near10, near25 = View.dread(10, "Hunt", false), View.dread(25, "Hunt", false)
		assert(near10.shake > near25.shake and near25.shake > 0, "shake grows when closer")
		assert(near10.vignette > near25.vignette and near25.vignette > 0, "vignette grows when closer")
		assert(View.dread(10, "Telegraph", false).shake > near10.shake, "the wind-up shakes harder")
		for _, quiet in ipairs({ View.dread(CONST.DREAD_RANGE + 0.1, "Hunt", false), View.dread(10, "Patrol", false),
			View.dread(10, "Retreat", false), View.dread(NAN, "Hunt", false), View.dread(-1, "Hunt", false) }) do
			equal(quiet.shake, 0); equal(quiet.vignette, 0)
		end
		local soft = View.dread(10, "Hunt", true)
		equal(soft.shake, 0, "Efectos suaves never shakes")
		assert(soft.vignette > 0 and soft.vignette < near10.vignette, "a softer vignette")
		assert(near10.shake <= 0.5 and near10.vignette <= 0.7, "bounded")
	end)
	return result
end

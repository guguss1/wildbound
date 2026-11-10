-- Invoke with require(freshTestClone)(require(freshViewClone), freshViewClone.Source,
-- require(freshIslandLayoutClone), require(freshRulesClone)) in Studio. Pure view-models for the Wildbound HUD: chip,
-- hint, notice expiry, text fitting. Time is injected. The island layout (stalk sightings) and the world rules (the
-- hub circle) are optional; without them those cases fail.
return function(View, source, islandLayout, Rules)
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

	-- Deliberately changed in NB3: the chip and the hint are neutral Spanish.
	case("the words say what to do, not who is who in code terms", function()
		assert(chip(SEEN).text:find("te ve"), "seen must say it sees you")
		assert(chip(ALLY).text:lower():find("amigo"), "ally must name a friend")
		assert(chip(SEARCH).text:lower():find("busca"), "searching must say searching")
		assert(chip(NONE).text:lower():find("sin caza"), "none must say there is no hunt")
		assert(chip(ATTACK).text:find("ATAQUE"), "attack must say attack")
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
		assert(stale.text:find("Esperando"), stale.text) -- Spanish since NB3
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
		assert(chip(ATTACK, true).text:find("ATAQUE"), "compact attack keeps its word")
		assert(chip(SEARCH, true).text:find("1%.5s"), "compact search keeps its countdown")
		assert(chip(ALLY, true).text:lower():find("amigo"), "compact ally keeps its word")
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
		equal(hint({ attack = true, threat = true, revealed = true }), "¡Ataque en camino! Apártate.")
		equal(hint({ threat = true, revealed = true }), "Peligro cerca: ve a un refugio.")
		equal(hint({ revealed = true, phase = "Dusk", isFog = true }), "La Silueta se ve. ¡Muévete!")
		equal(hint({ phase = "Dusk", isFog = true }), "Atardecer: llega la noche.")
		equal(hint({ isFog = true }), "Bosque de niebla: mantente alerta.")
		equal(hint({}), "Explora o vuelve al campamento.")
	end)

	case("every hint fits a two line phone budget of 50 characters", function()
		for _, overrides in ipairs({ { attack = true }, { threat = true }, { revealed = true },
			{ phase = "Dusk" }, { isFog = true }, {} }) do
			assert(#hint(overrides) <= 50, hint(overrides))
		end
	end)

	case("a garbage hint input never errors and gives the calm line", function()
		equal(View.hint(nil), "Explora o vuelve al campamento.")
		equal(View.hint("x"), "Explora o vuelve al campamento.")
		equal(View.hint({ attack = "yes", threat = 1, revealed = {} }), "Explora o vuelve al campamento.")
	end)

	case("M5.3 Night outside the fog says why to go there, and danger lines still come first", function()
		equal(hint({ phase = "Night" }), "Noche: florece el Nightbloom.")
		equal(hint({ phase = "Night", isFog = true }), "Bosque de niebla: mantente alerta.")
		equal(hint({ phase = "Night", threat = true }), "Peligro cerca: ve a un refugio.")
		equal(hint({ phase = "Night", attack = true }), "¡Ataque en camino! Apártate.")
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

	-- Fix pass (FP2, one Silueta per player): this client draws its own hunter in full and anyone else's faint.
	case("FP2: another player's Silueta is drawn faint, your own in full, tunable", function()
		equal(View.hunterFade(101, 101), 0, "your own hunter")
		equal(View.hunterFade(202, 101), CONST.OTHER_SILUETA_FADE, "someone else's")
		assert(CONST.OTHER_SILUETA_FADE >= 0.5 and CONST.OTHER_SILUETA_FADE < 1, "faint, not gone: " .. CONST.OTHER_SILUETA_FADE)
		for _, bad in ipairs({ nil, NAN, "101" }) do equal(View.hunterFade(bad, 101), CONST.OTHER_SILUETA_FADE, "no owner reads as foreign") end
		View.tune({ OTHER_SILUETA_FADE = 1 })
		equal(View.hunterFade(202, 101), 1, "1 hides them")
		equal(View.hunterFade(101, 101), 0, "never your own")
		View.tune({ OTHER_SILUETA_FADE = 7 })
		equal(View.hunterFade(202, 101), 1, "clamped")
		View.tune(nil)
		equal(View.hunterFade(202, 101), CONST.OTHER_SILUETA_FADE)
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
	-- Fear pass (FA3, user: "scarier; capturing must be an adrenaline rush; the parents chase and hit you"): pure
	-- rules for the burst after a grab, a woken parent, a swing, a landed hit and La Silueta seeing you. Each cue
	-- fades linearly over its own seconds; a hit flashes red; the heartbeat lingers 6 s and follows the nearest threat.
	-- "Efectos suaves" removes the shake and halves the rest; the heartbeat stays (the audio mix softens it).
	case("FA3: a grab is a short adrenaline burst that fades out", function()
		local cues = { grab = 10 }
		local f = View.fear(cues, 10, 0, false)
		near(f.shake, CONST.FEAR_SHAKE)
		near(f.fov, CONST.FEAR_FOV)
		assert(f.red > 0.3 and f.red <= 0.6, "a red edge " .. tostring(f.red))
		near(f.heart, 1)
		near(f.flash, 0)
		local half = View.fear(cues, 10 + CONST.FEAR_SECONDS / 2, 0, false)
		near(half.shake, CONST.FEAR_SHAKE / 2)
		local gone = View.fear(cues, 10 + CONST.FEAR_SECONDS + 0.01, 0, false)
		near(gone.shake, 0); near(gone.fov, 0); near(gone.red, 0)
		assert(gone.heart > 0, "the heart is still racing after the burst")
		near(View.fear(cues, 17, 0, false).heart, 0)
		near(View.fear(cues, 9, 0, false).shake, 0) -- a cue from the future is ignored
	end)

	case("FA3: a landed hit flashes red and shakes hardest; a swing and a sighting are felt too", function()
		local hit = View.fear({ hit = 5 }, 5, 0, false)
		near(hit.flash, CONST.HIT_FLASH)
		assert(hit.shake > View.fear({ grab = 5 }, 5, 0, false).shake, "a hit shakes harder than a grab")
		near(View.fear({ hit = 5 }, 5.4, 0, false).flash, 0)
		local strike = View.fear({ strike = 1 }, 1, 0, false)
		assert(strike.red > 0 and strike.shake > 0 and strike.flash == 0, "the swing tightens the screen")
		local seen = View.fear({ seen = 1 }, 1, 0, false)
		assert(seen.dark > 0 and seen.red == 0, "La Silueta seeing you darkens the screen")
		local woke = View.fear({ woke = 1 }, 1, 0, false)
		assert(woke.red > 0 and woke.heart == 1, "a woken parent")
	end)

	case("FA3: the heartbeat follows the nearest threat", function()
		near(View.threat(0), 1)
		near(View.threat(CONST.HEART_RANGE / 2), 0.5)
		near(View.threat(CONST.HEART_RANGE + 1), 0)
		near(View.threat(NAN), 0); near(View.threat(nil), 0)
		near(View.fear({}, 0, 0.7, false).heart, 0.7)
		near(View.fear({ grab = 0 }, 4.5, 0.9, false).heart, 0.9)
	end)

	case("FA3: Efectos suaves removes the shake and halves the rest", function()
		local full = View.fear({ hit = 0, grab = 0 }, 0, 0, false)
		local soft = View.fear({ hit = 0, grab = 0 }, 0, 0, true)
		near(soft.shake, 0)
		near(soft.fov, full.fov / 2); near(soft.red, full.red / 2)
		assert(soft.flash > 0 and soft.flash < full.flash, "a softer flash")
		near(soft.heart, full.heart)
	end)

	case("FA3: bad input is calm, and the knockback pushes away from the adult", function()
		local calm = View.fear(nil, NAN, NAN, false)
		near(calm.shake, 0); near(calm.red, 0); near(calm.heart, 0); near(calm.flash, 0)
		near(View.fear({ grab = "x" }, 1, 0, false).shake, 0)
		local x, z = View.knockback(10, 0, 7, 0)
		near(x, CONST.KNOCKBACK); near(z, 0)
		x, z = View.knockback(0, 0, 0, 0)
		near(x, 0); near(z, CONST.KNOCKBACK) -- on top of it: a fixed push, never NaN
		equal(View.knockback(NAN, 0, 0, 0), nil)
		assert(CONST.HIT_FLASH <= 0.7 and CONST.FEAR_SHAKE <= 0.6 and CONST.FEAR_FOV <= 15, "bounded")
	end)
	-- Stalk sightings (fear pass, user: "Sí, armalo"): La Silueta's silhouette appears for a few seconds at the edge of
	-- what the player can see, between trees, mostly at dusk and night, then vanishes. Client-only visuals: these
	-- rules decide when one may appear, where (behind a trunk core, in the peripheral view, inside the distance band,
	-- never in camp, on the spawn pad or on an island floor) and when it vanishes.
	local function stalkInput(over)
		local input = { phase = "Night", count = 0, reduced = false, guardianState = "Patrol", guardianDistance = 200 }
		for key, value in pairs(over or {}) do input[key] = value end
		return input
	end

	case("Stalk: allowed only at dusk, night and dawn, never while the real one is after you or near", function()
		equal(View.stalkAllowed(stalkInput()), true)
		equal(View.stalkAllowed(stalkInput({ phase = "Dusk" })), true)
		equal(View.stalkAllowed(stalkInput({ phase = "Dawn" })), true)
		equal(select(2, View.stalkAllowed(stalkInput({ phase = "Day" }))), "Day")
		for _, state in ipairs({ "Alert", "Hunt", "Telegraph", "Search" }) do
			equal(select(2, View.stalkAllowed(stalkInput({ guardianState = state }))), "Hunting")
		end
		equal(select(2, View.stalkAllowed(stalkInput({ guardianDistance = CONST.STALK_MAX + 10 }))), "Near")
		equal(select(2, View.stalkAllowed(stalkInput({ count = CONST.STALK_PER_NIGHT }))), "Cap")
		equal(select(2, View.stalkAllowed(stalkInput({ count = 1, reduced = true }))), "Cap")
		equal(View.stalkAllowed(nil), false)
	end)

	case("Stalk: rare, sooner while carrying a cria or far from camp, rarer with Efectos suaves", function()
		local base = View.stalkInterval(false, false, false, 0.5)
		near(base, CONST.STALK_EVERY)
		assert(View.stalkInterval(true, false, false, 0.5) < base, "carrying a cria")
		assert(View.stalkInterval(false, true, false, 0.5) < base, "far from camp")
		assert(View.stalkInterval(false, false, true, 0.5) > base, "Efectos suaves")
		for _, roll in ipairs({ 0, 1, NAN }) do
			assert(View.stalkInterval(true, true, false, roll) >= CONST.STALK_COOLDOWN, "never under the cooldown")
		end
		assert(CONST.STALK_COOLDOWN >= 20 and CONST.STALK_PER_NIGHT <= 4, "it stays rare")
		-- Play finding: at 55 studs a night sighting was lost in the fog (about 39 studs at night); its red eyes must
		-- still read, so the band sits inside the night fog and the flashlight.
		assert(CONST.STALK_MAX <= 40 and CONST.STALK_MIN >= 15 and CONST.STALK_NEAR < CONST.STALK_MIN, "the band is visible")
	end)

	case("Stalk: the spot is behind a trunk, in the band, off to the side, and away from the player", function()
		local cores = {
			{ x = 0, z = 40, r = 1.5 }, -- straight ahead: too central
			{ x = 18, z = 24, r = 1.5 }, -- about 37 degrees off, 30 studs: the one
			{ x = 5, z = 8, r = 1.5 }, -- too close
			{ x = 0, z = -40, r = 1.5 }, -- behind the player
			{ x = 200, z = 200, r = 1.5 }, -- too far
		}
		local x, z = View.stalkSpot(0, 0, 0, 1, cores, {})
		assert(x, "a spot")
		local d = math.sqrt(x * x + z * z)
		assert(d > 30, "behind the trunk, farther than its core")
		assert(d >= CONST.STALK_MIN and d <= CONST.STALK_MAX + 5, "in the band " .. tostring(d))
		equal(View.stalkSpot(0, 0, 0, 1, { cores[1], cores[3], cores[4], cores[5] }, {}), nil)
		equal(View.stalkSpot(NAN, 0, 0, 1, cores, {}), nil)
	end)

	case("Stalk: never in camp, on the spawn pad or on an island floor", function()
		assert(type(View.STALK_KEEP_OUT) == "table" and #View.STALK_KEEP_OUT >= 3, "keep-out circles")
		local function covered(x, z, radius)
			for _, zone in ipairs(View.STALK_KEEP_OUT) do
				if math.sqrt((x - zone.x) ^ 2 + (z - zone.z) ^ 2) + radius <= zone.r + 1e-6 then return true end
			end
			return false
		end
		assert(covered(-140, 140, 35), "camp")
		assert(covered(105, 125, 22), "shelter")
		assert(covered(0, 0, 9), "spawn pad")
		assert(islandLayout and islandLayout.islands, "the island layout is passed in")
		for _, island in ipairs(islandLayout.islands) do
			assert(covered(island.x, island.z, island.floorRadius), "island " .. island.id)
		end
		local zone = View.STALK_KEEP_OUT[1]
		local inCamp = { { x = zone.x + 12, z = zone.z, r = 1.5 } }
		assert(View.stalkSpot(zone.x, zone.z - 25, 0, 1, inCamp, {}), "a spot without the keep-out circles")
		equal(View.stalkSpot(zone.x, zone.z - 25, 0, 1, inCamp, View.STALK_KEEP_OUT), nil)
	end)

	case("HV-H1: no stalk sighting can land inside the hub disc, and the hub counts as home", function()
		assert(Rules and Rules.HUB_X, "the world rules are passed in")
		local hub = View.HUB_CIRCLE
		assert(type(hub) == "table", "View.HUB_CIRCLE")
		equal(hub.x, Rules.HUB_X); equal(hub.z, Rules.HUB_Z); equal(hub.r, Rules.HUB_RADIUS)
		local zone
		for _, candidate in ipairs(View.STALK_KEEP_OUT) do
			if candidate.x == hub.x and candidate.z == hub.z then zone = candidate end
		end
		assert(zone and zone.r >= hub.r + 10, "a keep-out circle covers the hub disc with a margin")
		-- A ring of trunk cores all around the hub, seen from many spots and looks: every spot found is outside the disc.
		local cores = {}
		for i = 0, 71 do
			local a = i / 72 * 2 * math.pi
			for _, d in ipairs({ 20, 45, 70, 85, 95, 110 }) do
				table.insert(cores, { x = hub.x + d * math.cos(a), z = hub.z + d * math.sin(a), r = 1.5 })
			end
		end
		local found = 0
		for i = 0, 23 do
			local a = i / 24 * 2 * math.pi
			for _, d in ipairs({ 0, 40, 80, 100, 120, 140 }) do
				local px, pz = hub.x + d * math.cos(a), hub.z + d * math.sin(a)
				for j = 0, 7 do
					local b = j / 8 * 2 * math.pi
					local x, z = View.stalkSpot(px, pz, math.cos(b), math.sin(b), cores, View.STALK_KEEP_OUT)
					if x then
						found += 1
						assert(math.sqrt((x - hub.x) ^ 2 + (z - hub.z) ^ 2) > hub.r, "a sighting inside the hub")
					end
				end
			end
		end
		assert(found > 0, "spots outside the hub are still found")
		equal(View.inHub(hub.x, hub.z), true); equal(View.inHub(hub.x + hub.r - 0.01, hub.z), true)
		equal(View.inHub(hub.x + hub.r + 0.01, hub.z), false); equal(View.inHub(NAN, 0), false)
		equal(View.farFromHome(hub.x, hub.z), false, "the hub is home")
		equal(View.farFromHome(hub.x + 120, hub.z), false)
		equal(View.farFromHome(Rules.CAMP_X, Rules.CAMP_Z), false, "the camp is home")
		equal(View.farFromHome(Rules.CAMP_X, Rules.CAMP_Z - View.FAR_FROM_HOME - 1), true)
		equal(View.farFromHome(NAN, 0), false)
	end)

	case("Stalk: it vanishes when looked at, approached, after its seconds, or when the real one hunts", function()
		equal(View.stalkVanish({ age = 1, distance = 40, lookDot = 0.7, guardianState = "Patrol" }), nil)
		equal(View.stalkVanish({ age = CONST.STALK_SECONDS, distance = 40, lookDot = 0.7 }), "Time")
		equal(View.stalkVanish({ age = 1, distance = CONST.STALK_NEAR - 1, lookDot = 0.7 }), "Approach")
		equal(View.stalkVanish({ age = 1, distance = 40, lookDot = 0.995 }), "Looked")
		equal(View.stalkVanish({ age = 0.2, distance = 40, lookDot = 0.995 }), nil) -- a glimpse first
		equal(View.stalkVanish({ age = 1, distance = 40, lookDot = 0.7, guardianState = "Hunt" }), "Real")
		equal(View.stalkVanish(nil), "Time")
	end)
	-- Look pass: La Silueta's horror grin pops in when she starts the chase; "Efectos suaves" fades it in, no pop.
	case("Look pass: the grin pops in briefly, and only fades with Efectos suaves", function()
		local full, soft = View.grinPop(false), View.grinPop(true)
		assert(full.fromScale > 0 and full.fromScale < 1, "a pop grows from smaller")
		assert(full.seconds > 0 and full.seconds <= 0.3, "short")
		equal(full.style, "Back", "a snap past full size")
		equal(soft.fromScale, 1, "no pop with Efectos suaves")
		assert(soft.seconds >= full.seconds and soft.seconds <= 0.8, "a gentler fade")
		equal(soft.style, "Sine")
		equal(full.fromAlpha, 1); equal(soft.fromAlpha, 1)
		equal(View.grinPop("yes").fromScale, full.fromScale, "anything but true is the full pop")
	end)
	-- Fix pass (FP5d): a sleeping adult's breathing: a slow rise and fall, slower and deeper at noon.
	case("FP5d: breathing pulse", function()
		local amp = CONST.BREATH_AMPLITUDE
		assert(amp > 0 and amp <= 0.5, "a small rise")
		equal(View.breath(0, false), 0, "starts at rest")
		local peak = View.breath(CONST.BREATH_SECONDS / 2, false)
		assert(math.abs(peak - amp) < 1e-6, "peak at half a breath: " .. tostring(peak))
		local deepPeak = View.breath(CONST.BREATH_DEEP_SECONDS / 2, true)
		assert(math.abs(deepPeak - amp) < 1e-6, "deep peak")
		assert(CONST.BREATH_DEEP_SECONDS > CONST.BREATH_SECONDS, "deep sleep breathes slower")
		equal(View.breath(0 / 0, false), 0)
		for t = 0, 6, 0.25 do
			local v = View.breath(t, t > 3)
			assert(v >= -1e-9 and v <= amp + 1e-9, "inside the range")
		end
	end)
	return result
end

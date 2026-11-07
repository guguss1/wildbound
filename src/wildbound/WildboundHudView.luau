-- Pure view-models for the Wildbound HUD: what the awareness chip says, the panel hint, how long a
-- notice lives, how a long line is collapsed, how the companion fades. The clock is injected and
-- nothing here touches an interface object. See docs/ui/wildbound-world.md.
local View = {}

-- Hypotheses. Character counts are budgets for the chip text at its two sizes (see the layout module).
View.CONSTANTS = table.freeze({
	NOTICE_SECONDS = 6,
	CHIP_CHARS = 26,
	COMPACT_CHIP_CHARS = 17,
	COMPANION_BASE_TRANSPARENCY = 0.1,
	COMPANION_FADED_TRANSPARENCY = 0.9,
	COMPANION_FADE_START = 8,
	COMPANION_FADE_END = 3,
})

local CONSTANTS = View.CONSTANTS

-- Colour is a redundant cue. Every pairing keeps at least 4.5:1 contrast (a contract checks it).
View.TONES = table.freeze({
	seen = table.freeze({ bg = table.freeze({ r = 255, g = 176, b = 32 }), text = table.freeze({ r = 30, g = 22, b = 6 }),
		border = table.freeze({ r = 255, g = 226, b = 150 }), transparency = 0.05 }),
	attack = table.freeze({ bg = table.freeze({ r = 200, g = 40, b = 40 }), text = table.freeze({ r = 255, g = 255, b = 255 }),
		border = table.freeze({ r = 255, g = 255, b = 255 }), transparency = 0 }),
	searching = table.freeze({ bg = table.freeze({ r = 36, g = 44, b = 40 }), text = table.freeze({ r = 255, g = 214, b = 120 }),
		border = table.freeze({ r = 255, g = 176, b = 32 }), transparency = 0.1 }),
	ally = table.freeze({ bg = table.freeze({ r = 40, g = 76, b = 120 }), text = table.freeze({ r = 255, g = 255, b = 255 }),
		border = table.freeze({ r = 150, g = 195, b = 240 }), transparency = 0.1 }),
	none = table.freeze({ bg = table.freeze({ r = 30, g = 38, b = 35 }), text = table.freeze({ r = 200, g = 210, b = 200 }),
		border = table.freeze({ r = 90, g = 105, b = 95 }), transparency = 0.35 }),
})

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function entry(kind, state, shape, glyph, text, extra)
	local value = { kind = kind, state = state, tone = kind == "unknown" and "none" or kind, shape = shape,
		glyph = glyph, text = text, attack = kind == "attack" }
	for key, item in pairs(extra or {}) do value[key] = item end
	return value
end

-- The server sends an attack deadline only while its strike is unresolved, and resolves it up to one
-- 0.2 s step after the deadline. So the warning holds while the deadline is present, not until it passes.
function View.attackPending(awareness)
	if type(awareness) ~= "table" or awareness.state ~= "seen" then return false end
	local deadline = awareness.attackEndsAt
	return finite(deadline) and deadline > 0
end

-- awareness is the snapshot value ({ state, searchEndsAt?, attackEndsAt? }); fresh is false when the
-- world state is stale; now is the server clock. Shapes: square attack, diamond seen, ring searching,
-- dot ally, dash none. The text always names the state, so the chip never depends on hue or audio.
function View.chip(awareness, fresh, now, compact)
	if fresh ~= true or not finite(now) then
		return entry("unknown", "unknown", "dash", "-", compact and "No signal" or "Waiting for server")
	end
	local state = type(awareness) == "table" and awareness.state or "none"
	if state == "seen" then
		if View.attackPending(awareness) then
			return entry("attack", "seen", "square", "!!", compact and "ATTACK! Move!" or "ATTACK! Move away!")
		end
		return entry("seen", "seen", "diamond", "!", "Silueta sees you")
	elseif state == "searching" then
		local label = compact and "Searching" or "Silueta is searching"
		local deadline = awareness.searchEndsAt
		if finite(deadline) then
			local seconds = math.max(0, deadline - now)
			return entry("searching", "searching", "ring", "?", ("%s %.1fs"):format(label, seconds), { seconds = seconds })
		end
		return entry("searching", "searching", "ring", "?", label)
	elseif state == "ally" then
		return entry("ally", "ally", "dot", "i", compact and "Friend hunted" or "Silueta hunts a friend")
	end
	return entry("none", "none", "dash", "-", "No hunt nearby")
end

function View.newChipCache()
	return {}
end

-- The chip for a per-frame caller. It is rebuilt only when what it shows changes: freshness, size,
-- state, the attack flag or the searching countdown's tenth. Otherwise the previous table comes back,
-- so a steady chip allocates nothing.
function View.chipCached(cache, awareness, fresh, now, compact)
	if type(cache) ~= "table" then return View.chip(awareness, fresh, now, compact) end
	local live = fresh == true and finite(now)
	local state = live and (type(awareness) == "table" and awareness.state or "none") or "unknown"
	local attack = live and View.attackPending(awareness)
	local tenth = -1
	if live and state == "searching" and finite(awareness.searchEndsAt) then
		tenth = math.floor(math.max(0, awareness.searchEndsAt - now) * 10 + 0.5)
	end
	compact = compact == true
	if cache.view and cache.state == state and cache.attack == attack and cache.tenth == tenth
		and cache.compact == compact then
		return cache.view
	end
	cache.state, cache.attack, cache.tenth, cache.compact = state, attack, tenth, compact
	cache.view = View.chip(awareness, fresh, now, compact)
	return cache.view
end

-- The panel line under the phase. Priority: attack, threat, revealed, dusk, fog, night, calm.
function View.hint(info)
	info = type(info) == "table" and info or {}
	if info.attack == true then return "Attack incoming: move away!" end
	if info.threat == true then return "Threat nearby: move toward shelter." end
	if info.revealed == true then return "Silueta revealed. Keep moving." end
	if info.phase == "Dusk" then return "Dusk: night is approaching." end
	if info.isFog == true then return "Fog forest: stay alert." end
	if info.phase == "Night" then return "Night: Nightbloom blooms in the fog." end
	return "Explore or return to camp."
end

function View.newNotice()
	return {}
end

-- Empty or non-text input never clears what is showing; a bad clock never starts a notice.
function View.setNotice(notice, text, now)
	if type(notice) ~= "table" or type(text) ~= "string" or text == "" or not finite(now) then return end
	notice.text, notice.shownAt = text, now
end

-- Returns the text while it is fresh, else nothing. An expired or impossible notice is dropped for good.
function View.currentNotice(notice, now)
	if type(notice) ~= "table" or not finite(now) then return nil end
	if notice.text == nil then return nil end
	local age = now - notice.shownAt
	if age < 0 or age >= CONSTANTS.NOTICE_SECONDS then
		notice.text, notice.shownAt = nil, nil
		return nil
	end
	return notice.text
end

-- Small screens use the short form when the server sent one.
function View.pickNotice(payload, compact)
	if type(payload) ~= "table" then return "" end
	local full = type(payload.notice) == "string" and payload.notice or ""
	local short = type(payload.noticeShort) == "string" and payload.noticeShort or ""
	if compact and short ~= "" then return short end
	return full
end

-- Collapse a long line instead of shrinking or clipping it: keep the longest whole sentence that fits,
-- else cut at a word and end with three dots. The result never exceeds the budget.
function View.fit(text, maxChars)
	if type(text) ~= "string" or not finite(maxChars) then return "" end
	maxChars = math.floor(maxChars)
	if maxChars <= 0 then return "" end
	if #text <= maxChars then return text end
	if maxChars <= 3 then return text:sub(1, maxChars) end
	for position = maxChars, 1, -1 do
		local mark = text:sub(position, position)
		if (mark == "." or mark == "!" or mark == "?") and (position == #text or text:sub(position + 1, position + 1):match("%s")) then
			return text:sub(1, position)
		end
	end
	local room = maxChars - 3
	local cut = text:sub(1, room)
	local space = cut:match("^(.*)%s+%S*$")
	if text:sub(room + 1, room + 1):match("%s") then
		space = cut
	end
	local kept = (space and #space > 0) and space or cut
	return kept:gsub("%s+$", "") .. "..."
end

-- The English words of the defeat summary. D-C5: a words table of the same shape (WildboundText.DEFEAT) replaces
-- them, so the screen reads in Spanish while the older English contracts still hold.
local ENGLISH = table.freeze({
	title = "Defeated. You will return to camp.", nothing = "Nothing was lost.", lost = "Lost %s: %s%s.",
	more = " and %d more", item = "item", items = "items", materials = "Lost materials: %s.",
	materialNames = table.freeze({ fogbark = "Fogbark", glowmoss = "Glowmoss", nightbloom = "Nightbloom" }),
	savedMany = "Saved by seal or totem: %s.", savedOne = "Saved by your seal: %s.", kept = "Kept: %d registered, %s.",
	egg = "banked egg", eggs = "banked eggs", safe = "Safe: %d Ember, %s.", material = "banked material",
	materialsWord = "banked materials", close = "Tap to close.", eggName = "%s egg", bundle = "Nightbloom bundle",
	bundleCount = "Nightbloom bundle (%d)",
})

local function itemName(item, words)
	if type(item) ~= "table" then return nil end
	if item.kind == "Nightbloom" then
		return finite(item.quantity) and words.bundleCount:format(math.max(1, math.floor(item.quantity))) or words.bundle
	end
	local species = type(item.species) == "string" and item.species or "Lumipol"
	return item.kind == "Egg" and words.eggName:format(species) or species
end

local function plural(count, word, words)
	return ("%d %s"):format(count, count == 1 and word or words)
end

-- M4.6: the full-screen defeat summary, from the server's loss summary. At most five names are listed.
function View.lossSummary(summary, words)
	summary = type(summary) == "table" and summary or {}
	words = type(words) == "table" and words or ENGLISH
	local lines = { words.title }
	local names = {}
	for _, item in ipairs(type(summary.lostItems) == "table" and summary.lostItems or {}) do
		local name = itemName(item, words)
		if name then table.insert(names, name) end
	end
	if #names == 0 then
		table.insert(lines, words.nothing)
	else
		local shown = {}
		for index = 1, math.min(5, #names) do shown[index] = names[index] end
		local more = #names > 5 and words.more:format(#names - 5) or ""
		table.insert(lines, words.lost:format(plural(#names, words.item, words.items), table.concat(shown, ", "), more))
	end
	-- M5.8: lost materials, in a fixed order, and only the ones that really went.
	local materials = {}
	local lostMaterials = type(summary.materialsLost) == "table" and summary.materialsLost or {}
	for _, key in ipairs({ "fogbark", "glowmoss", "nightbloom" }) do
		local value = lostMaterials[key]
		if finite(value) and value >= 1 then
			table.insert(materials, ("%d %s"):format(math.floor(value), words.materialNames[key] or key))
		end
	end
	if #materials > 0 then table.insert(lines, words.materials:format(table.concat(materials, ", "))) end
	local savedNames = {}
	for _, item in ipairs(type(summary.savedItems) == "table" and summary.savedItems or {}) do
		local name = itemName(item, words)
		if name then table.insert(savedNames, name) end
	end
	if #savedNames > 0 then
		table.insert(lines, words.savedMany:format(table.concat(savedNames, ", ")))
	else
		local saved = itemName(summary.savedItem, words)
		if saved then table.insert(lines, words.savedOne:format(saved)) end
	end
	local kept = type(summary.kept) == "table" and summary.kept or {}
	local registered = finite(kept.registered) and math.max(0, math.floor(kept.registered)) or 0
	local eggs = finite(kept.bankedEggs) and math.max(0, math.floor(kept.bankedEggs)) or 0
	table.insert(lines, words.kept:format(registered, plural(eggs, words.egg, words.eggs)))
	local ember = finite(kept.ember) and math.max(0, math.floor(kept.ember)) or 0
	local banked = finite(kept.bankedMaterials) and math.max(0, math.floor(kept.bankedMaterials)) or 0
	if ember > 0 or banked > 0 then
		table.insert(lines, words.safe:format(ember, plural(banked, words.material, words.materialsWord)))
	end
	table.insert(lines, words.close)
	return table.concat(lines, "\n")
end

-- Delivery C: the red flash when a strike lands, and the name of the sound hook for later (no sound plays yet).
-- Reduced effects keep the cue but soften it. A miss, a cancel or a spared strike never flashes.
local FLASHES = table.freeze({
	Marked = table.freeze({ from = 0.45, seconds = 0.45, sound = "hit" }),
	Defeated = table.freeze({ from = 0.2, seconds = 0.6, sound = "defeat" }),
})
function View.hitFlash(outcome, reduced)
	local flash = FLASHES[outcome]
	if not flash then return nil end
	return { from = reduced == true and math.min(0.8, flash.from + 0.3) or flash.from, seconds = flash.seconds,
		sound = flash.sound, r = 200, g = 20, b = 20 }
end

-- The decorative companion fades as the camera nears it, so it can never fill the view.
function View.companionTransparency(distance)
	local base, faded = CONSTANTS.COMPANION_BASE_TRANSPARENCY, CONSTANTS.COMPANION_FADED_TRANSPARENCY
	if not finite(distance) then return base end
	local start, finish = CONSTANTS.COMPANION_FADE_START, CONSTANTS.COMPANION_FADE_END
	local fraction = math.clamp((start - distance) / (start - finish), 0, 1)
	return base + (faded - base) * fraction
end

return View

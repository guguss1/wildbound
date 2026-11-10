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
	-- Chase pass (CP1, CP3): the sprint field-of-view kick, and how close a hunting Silueta must be to shake the view.
	SPRINT_FOV_KICK = 10,
	SPRINT_FOV_KICK_REDUCED = 4,
	DREAD_RANGE = 35,
	DREAD_SHAKE = 0.35, -- studs of camera offset at contact while it hunts; the wind-up shakes 1.4 times that
	DREAD_VIGNETTE = 0.6,
	DREAD_VIGNETTE_REDUCED = 0.3,
	-- Fear pass (FA3): the adrenaline burst after a grab (seconds, camera offset in studs, field-of-view punch in
	-- degrees), the red flash of a landed hit (opacity), the heartbeat's reach (studs) and a hit's push (studs/s).
	FEAR_SECONDS = 3,
	FEAR_SHAKE = 0.3,
	FEAR_FOV = 8,
	HIT_FLASH = 0.55,
	HEART_RANGE = 45,
	KNOCKBACK = 42,
	-- Stalk sightings (fear pass): La Silueta glimpsed at the edge of sight. The mean gap between two (seconds), the
	-- shortest gap, the most per evening, the distance band (studs, inside the night fog's end, about 39, so its eyes still
	-- read), how long one may stand there (seconds) and how close the player may come before it is gone (studs).
	STALK_EVERY = 50,
	STALK_COOLDOWN = 30,
	STALK_PER_NIGHT = 3,
	STALK_MIN = 18,
	STALK_MAX = 36,
	STALK_SECONDS = 4,
	STALK_NEAR = 12,
	-- Fix pass (FP2): another player's Silueta is drawn this faint on this client (1 = not drawn at all).
	OTHER_SILUETA_FADE = 0.75,
	-- Fix pass (FP5d): a sleeping island adult rises and falls this many studs, once per BREATH_SECONDS (slower in the
	-- deep noon sleep).
	BREATH_AMPLITUDE = 0.15,
	BREATH_SECONDS = 3,
	BREATH_DEEP_SECONDS = 4.5,
	-- RW7, the random world: the wave board's line budget (bytes, like the chip's) and the event banner's, as wide
	-- as the chip, on a desktop and on a phone. (Its own words avoid the purity scan's tokens.)
	BOARD_CHARS = 22,
	COMPACT_BOARD_CHARS = 18,
	BANNER_CHARS = 36,
	COMPACT_BANNER_CHARS = 24,
})

-- Dev tuning (docs/testing/wildbound-tuning.md): CONSTANTS stay the defaults the tests pin; the view reads `live`, a
-- copy the client's tuning bridge may override at runtime (client-only values such as the camera kick). No override,
-- no change.
local CONSTANTS = {}
View.live = CONSTANTS

function View.tunable()
	return table.clone(View.CONSTANTS)
end

function View.tune(overrides)
	for key, value in pairs(View.CONSTANTS) do CONSTANTS[key] = value end
	if type(overrides) ~= "table" then return end
	for key, value in pairs(overrides) do
		if type(View.CONSTANTS[key]) == "number" and type(value) == "number" and value == value
			and value > -math.huge and value < math.huge then
			CONSTANTS[key] = value
		end
	end
	-- A dread range under one stud would divide by nothing; neither may the burst or the heartbeat's reach.
	CONSTANTS.DREAD_RANGE = math.max(CONSTANTS.DREAD_RANGE, 1)
	CONSTANTS.FEAR_SECONDS = math.max(CONSTANTS.FEAR_SECONDS, 0.1)
	CONSTANTS.HEART_RANGE = math.max(CONSTANTS.HEART_RANGE, 1)
	-- A sighting keeps a real band, a real gap and a visible moment whatever the panel says.
	CONSTANTS.STALK_MAX = math.max(CONSTANTS.STALK_MAX, CONSTANTS.STALK_MIN + 5)
	CONSTANTS.STALK_COOLDOWN = math.max(CONSTANTS.STALK_COOLDOWN, 5)
	CONSTANTS.STALK_SECONDS = math.max(CONSTANTS.STALK_SECONDS, 0.5)
end
View.tune(nil)

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
-- dot ally, dash none. The text always names the state, so the chip never depends on hue or audio. Next batch NB3:
-- the words are neutral Spanish (full forms at most 26 bytes, compact at most 17).
function View.chip(awareness, fresh, now, compact)
	if fresh ~= true or not finite(now) then
		return entry("unknown", "unknown", "dash", "-", compact and "Sin señal" or "Esperando al servidor")
	end
	local state = type(awareness) == "table" and awareness.state or "none"
	if state == "seen" then
		if View.attackPending(awareness) then
			return entry("attack", "seen", "square", "!!", compact and "¡ATAQUE! Huye" or "¡ATAQUE! ¡Apártate!")
		end
		return entry("seen", "seen", "diamond", "!", "La Silueta te ve")
	elseif state == "searching" then
		local label = compact and "Te busca" or "La Silueta te busca"
		local deadline = awareness.searchEndsAt
		if finite(deadline) then
			local seconds = math.max(0, deadline - now)
			return entry("searching", "searching", "ring", "?", ("%s %.1fs"):format(label, seconds), { seconds = seconds })
		end
		return entry("searching", "searching", "ring", "?", label)
	elseif state == "ally" then
		return entry("ally", "ally", "dot", "i", compact and "Caza a un amigo" or "La Silueta caza a un amigo")
	end
	return entry("none", "none", "dash", "-", "Sin caza cerca")
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

-- The panel line under the phase. Priority: attack, threat, revealed, dusk, fog, night, calm. Spanish since NB3.
function View.hint(info)
	info = type(info) == "table" and info or {}
	if info.attack == true then return "¡Ataque en camino! Apártate." end
	if info.threat == true then return "Peligro cerca: ve a un refugio." end
	if info.revealed == true then return "La Silueta se ve. ¡Muévete!" end
	if info.phase == "Dusk" then return "Atardecer: llega la noche." end
	if info.isFog == true then return "Bosque de niebla: mantente alerta." end
	if info.phase == "Night" then return "Noche: florece el Nightbloom." end
	return "Explora o vuelve al campamento."
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

-- Delivery C: the red flash when a marking strike lands, and the name of the sound hook the audio client plays.
-- Reduced effects keep the cue but soften it. A miss, a cancel or a spared strike never flashes.
-- Delivery D11: a defeat never flashes. It eases to a dark overlay (transparency 1 to `to`), slower and lighter with
-- Reduced effects, and the defeat screen shows above it.
local FLASHES = table.freeze({
	Marked = table.freeze({ from = 0.45, seconds = 0.45, sound = "hit" }),
})
local DEFEAT_FADE = table.freeze({ seconds = 0.5, to = 0.15, reducedSeconds = 0.8, reducedTo = 0.4 })
function View.hitFlash(outcome, reduced)
	if outcome == "Defeated" then
		local soft = reduced == true
		return { kind = "fade", from = 1, to = soft and DEFEAT_FADE.reducedTo or DEFEAT_FADE.to,
			seconds = soft and DEFEAT_FADE.reducedSeconds or DEFEAT_FADE.seconds, sound = "defeat", r = 6, g = 6, b = 12 }
	end
	local flash = FLASHES[outcome]
	if not flash then return nil end
	return { kind = "flash", from = reduced == true and math.min(0.8, flash.from + 0.3) or flash.from, to = 1,
		seconds = flash.seconds, sound = flash.sound, r = 200, g = 20, b = 20 }
end

-- The decorative companion fades as the camera nears it, so it can never fill the view.
function View.companionTransparency(distance)
	local base, faded = CONSTANTS.COMPANION_BASE_TRANSPARENCY, CONSTANTS.COMPANION_FADED_TRANSPARENCY
	if not finite(distance) then return base end
	local start, finish = CONSTANTS.COMPANION_FADE_START, CONSTANTS.COMPANION_FADE_END
	local fraction = math.clamp((start - distance) / (start - finish), 0, 1)
	return base + (faded - base) * fraction
end

-- Chase pass (CP1): the camera's field of view while sprinting; out of breath or walking it returns to the base.
function View.sprintFov(base, stance, reduced)
	if not finite(base) or base <= 0 then base = 70 end
	if stance ~= "sprint" then return base end
	return base + (reduced == true and CONSTANTS.SPRINT_FOV_KICK_REDUCED or CONSTANTS.SPRINT_FOV_KICK)
end

-- Chase pass (CP1): the always-on sprint hint. Touch already has the "Correr" button, so it gets none.
function View.sprintHint(input, words)
	words = type(words) == "table" and words or {}
	if input == "keyboard" then return words.hintKeyboard or "Shift: Correr" end
	if input == "gamepad" then return words.hintGamepad or "L3: Correr" end
	return nil
end

-- Chase pass (CP3): a hunting Silueta close by shakes the view and darkens its edges, more during the wind-up.
-- Returns { shake = studs, vignette = 0 to 1 }. "Efectos suaves" never shakes and keeps half the vignette.
local DREAD_MODES = table.freeze({ Alert = 1, Hunt = 1, Telegraph = 1.4 })
function View.dread(distance, mode, reduced)
	local weight = DREAD_MODES[mode]
	if not weight or not finite(distance) or distance < 0 or distance > CONSTANTS.DREAD_RANGE then
		return { shake = 0, vignette = 0 }
	end
	local closeness = 1 - distance / CONSTANTS.DREAD_RANGE
	local soft = reduced == true
	return {
		shake = soft and 0 or CONSTANTS.DREAD_SHAKE * closeness * weight,
		vignette = (soft and CONSTANTS.DREAD_VIGNETTE_REDUCED or CONSTANTS.DREAD_VIGNETTE) * closeness,
	}
end

-- Fear pass (FA3): what each cue does at its start, and over how many seconds it fades out (linearly). red: the red
-- screen edge; dark: a black edge (La Silueta has seen you); shake and fov: multiples of FEAR_SHAKE and FEAR_FOV;
-- heart: the heartbeat, which lingers HEART_SECONDS whatever the cue. grab's length is FEAR_SECONDS (tunable).
local FEAR_CUES = table.freeze({
	grab = table.freeze({ seconds = nil, red = 0.45, dark = 0, shake = 1, fov = 1, heart = 1 }),
	woke = table.freeze({ seconds = 2.5, red = 0.4, dark = 0, shake = 0.8, fov = 0.6, heart = 1 }),
	strike = table.freeze({ seconds = 0.6, red = 0.35, dark = 0, shake = 0.5, fov = 0, heart = 0.8 }),
	hit = table.freeze({ seconds = 0.8, red = 0.7, dark = 0, shake = 2, fov = 0.6, heart = 1 }),
	seen = table.freeze({ seconds = 2, red = 0, dark = 0.5, shake = 0.4, fov = 0, heart = 0.9 }),
})
local HEART_SECONDS = 6
local FLASH_SECONDS = 0.35

-- How close the nearest threat is, 0 (out of reach) to 1 (on top of you).
function View.threat(distance)
	if not finite(distance) or distance < 0 then return 0 end
	return math.clamp(1 - distance / CONSTANTS.HEART_RANGE, 0, 1)
end

-- cues: { [kind] = the clock reading when it fired }. threat: View.threat of the nearest threat. Returns the screen and the
-- heartbeat for this frame: { red, dark, shake, fov, flash, heart }.
function View.fear(cues, now, threat, reduced)
	local out = { red = 0, dark = 0, shake = 0, fov = 0, flash = 0, heart = finite(threat) and math.clamp(threat, 0, 1) or 0 }
	if type(cues) ~= "table" or not finite(now) then return out end
	for kind, spec in pairs(FEAR_CUES) do
		local at = cues[kind]
		local age = finite(at) and now - at or -1
		if age >= 0 then
			local seconds = spec.seconds or CONSTANTS.FEAR_SECONDS
			local k = math.max(0, 1 - age / seconds)
			out.red = math.max(out.red, spec.red * k)
			out.dark = math.max(out.dark, spec.dark * k)
			out.shake = math.max(out.shake, spec.shake * k)
			out.fov = math.max(out.fov, spec.fov * k)
			out.heart = math.max(out.heart, spec.heart * math.max(0, 1 - age / HEART_SECONDS))
			if kind == "hit" then out.flash = math.max(0, 1 - age / FLASH_SECONDS) end
		end
	end
	local soft = reduced == true
	out.shake = soft and 0 or out.shake * CONSTANTS.FEAR_SHAKE
	out.fov = out.fov * CONSTANTS.FEAR_FOV * (soft and 0.5 or 1)
	out.red, out.dark = out.red * (soft and 0.5 or 1), out.dark * (soft and 0.5 or 1)
	out.flash = out.flash * CONSTANTS.HIT_FLASH * (soft and 0.4 or 1)
	return out
end

-- A landed adult hit pushes the player straight away from the adult (studs/s on the ground plane). On top of it the
-- push is a fixed +Z, never NaN. Returns nil for a bad position.
function View.knockback(px, pz, ax, az)
	if not (finite(px) and finite(pz) and finite(ax) and finite(az)) then return nil end
	local dx, dz = px - ax, pz - az
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-6 then return 0, CONSTANTS.KNOCKBACK end
	return dx / length * CONSTANTS.KNOCKBACK, dz / length * CONSTANTS.KNOCKBACK
end

-- The hub's safe disc (Rules.HUB_X, HUB_Z, HUB_RADIUS repeated here: the clients cannot load the server's world
-- rules; a test keeps them equal). Beside the forest since the forest shift (HF-T3, S1).
View.HUB_CIRCLE = table.freeze({ x = 282, z = -3, r = 90 })
-- Studs from the camp's or the hub's centre past which the player counts as far from home (sightings come sooner).
View.FAR_FROM_HOME = 150

-- Stalk sightings (fear pass). Never in camp, the shelter, the hub, on the spawn pad or on an island floor (each
-- island circle is its floor radius plus 8; a contract checks the layout; the hub's is its safe disc plus 10, like
-- the camp's): x, z, radius in studs.
View.STALK_KEEP_OUT = table.freeze({
	table.freeze({ x = -140, z = 140, r = 45 }), -- camp
	table.freeze({ x = View.HUB_CIRCLE.x, z = View.HUB_CIRCLE.z, r = View.HUB_CIRCLE.r + 10 }), -- hub
	table.freeze({ x = 105, z = 125, r = 30 }), -- shelter
	table.freeze({ x = 0, z = 0, r = 15 }), -- spawn pad
	table.freeze({ x = -95, z = 75, r = 22 }), -- island 1
	table.freeze({ x = -20, z = 15, r = 22 }), -- island 2
	table.freeze({ x = 115, z = 15, r = 24 }), -- island 3
	table.freeze({ x = 35, z = -99, r = 24 }), -- island 4
	table.freeze({ x = 60, z = -135, r = 22 }), -- island 5
})
local STALK_THREAT = { Alert = true, Hunt = true, Telegraph = true, Search = true }
local STALK_PHASES = { Dusk = true, Night = true, Dawn = true }
local STALK_ANGLE_MIN, STALK_ANGLE_MAX, STALK_ANGLE_BEST = math.rad(15), math.rad(60), math.rad(35)
local STALK_LOOK_DOT = 0.985 -- about 10 degrees: looked at directly
local STALK_GLIMPSE = 0.5 -- seconds it always stays, even when looked at
local STALK_BEHIND = 2.5 -- studs past the trunk core's edge

-- input = { phase, count (sightings this evening), reduced, guardianState, guardianDistance }. Returns ok, reason.
function View.stalkAllowed(input)
	if type(input) ~= "table" then return false, "Bad" end
	if not STALK_PHASES[input.phase] then return false, "Day" end
	if STALK_THREAT[input.guardianState] then return false, "Hunting" end
	if finite(input.guardianDistance) and input.guardianDistance < CONSTANTS.STALK_MAX + 25 then return false, "Near" end
	local cap = input.reduced == true and 1 or CONSTANTS.STALK_PER_NIGHT
	if not finite(input.count) or input.count >= cap then return false, "Cap" end
	return true, nil
end

-- True inside the hub's safe disc: no sighting is staged there.
function View.inHub(x, z)
	if not (finite(x) and finite(z)) then return false end
	local hub = View.HUB_CIRCLE
	return math.sqrt((x - hub.x) ^ 2 + (z - hub.z) ^ 2) <= hub.r
end

-- True when the player is farther than FAR_FROM_HOME from both the camp's and the hub's centre. False for a bad
-- position (bad input never makes a sighting come sooner).
function View.farFromHome(x, z)
	if not (finite(x) and finite(z)) then return false end
	local hub = View.HUB_CIRCLE
	return math.sqrt((x + 140) ^ 2 + (z - 140) ^ 2) > View.FAR_FROM_HOME
		and math.sqrt((x - hub.x) ^ 2 + (z - hub.z) ^ 2) > View.FAR_FROM_HOME
end

-- Seconds until the next sighting may come: STALK_EVERY scaled by a roll (0.6 to 1.4), sooner while carrying a cria
-- or far from camp, twice as long with "Efectos suaves", never under STALK_COOLDOWN.
function View.stalkInterval(carrying, far, reduced, roll)
	roll = finite(roll) and math.clamp(roll, 0, 1) or 0.5
	local seconds = CONSTANTS.STALK_EVERY * (0.6 + 0.8 * roll)
	if carrying == true then seconds *= 0.6 end
	if far == true then seconds *= 0.8 end
	if reduced == true then seconds *= 2 end
	return math.max(seconds, CONSTANTS.STALK_COOLDOWN)
end

-- Where to stand: just behind a trunk core (cores = { { x, z, r } }), inside the distance band, 15 to 60 degrees off
-- the player's look (seen from the corner of the eye), outside every keep-out circle. The one nearest 35 degrees.
function View.stalkSpot(px, pz, lookX, lookZ, cores, keepOut)
	if not (finite(px) and finite(pz) and finite(lookX) and finite(lookZ)) or type(cores) ~= "table" then return nil end
	local size = math.sqrt(lookX * lookX + lookZ * lookZ)
	if size < 1e-6 then return nil end
	lookX, lookZ = lookX / size, lookZ / size
	local bestX, bestZ, bestScore
	for _, core in ipairs(cores) do
		if type(core) == "table" and finite(core.x) and finite(core.z) then
			local dx, dz = core.x - px, core.z - pz
			local d = math.sqrt(dx * dx + dz * dz)
			if d >= CONSTANTS.STALK_MIN and d <= CONSTANTS.STALK_MAX then
				local angle = math.acos(math.clamp((dx * lookX + dz * lookZ) / d, -1, 1))
				if angle >= STALK_ANGLE_MIN and angle <= STALK_ANGLE_MAX then
					local push = (finite(core.r) and core.r or 1) + STALK_BEHIND
					local x, z = core.x + dx / d * push, core.z + dz / d * push
					local clear = true
					for _, zone in ipairs(type(keepOut) == "table" and keepOut or {}) do
						if math.sqrt((x - zone.x) ^ 2 + (z - zone.z) ^ 2) <= zone.r then
							clear = false
							break
						end
					end
					local score = math.abs(angle - STALK_ANGLE_BEST)
					if clear and (not bestScore or score < bestScore) then bestX, bestZ, bestScore = x, z, score end
				end
			end
		end
	end
	return bestX, bestZ
end

-- input = { age (seconds shown), distance (studs to the player), lookDot (player's look toward it), guardianState }.
-- Returns why it vanishes now ("Real", "Time", "Approach", "Looked"), or nil while it stays.
function View.stalkVanish(input)
	if type(input) ~= "table" or not finite(input.age) then return "Time" end
	if STALK_THREAT[input.guardianState] then return "Real" end
	if input.age >= CONSTANTS.STALK_SECONDS then return "Time" end
	if finite(input.distance) and input.distance <= CONSTANTS.STALK_NEAR then return "Approach" end
	if input.age >= STALK_GLIMPSE and finite(input.lookDot) and input.lookDot >= STALK_LOOK_DOT then return "Looked" end
	return nil
end

-- Fix pass (FP2, one Silueta per player): how faint a hunter is drawn on this client. The player's own hunter (the
-- model's owner id is this player's) is drawn in full; anyone else's, or one with no owner, at OTHER_SILUETA_FADE as a
-- LocalTransparencyModifier (0 full, 1 invisible). Presentation only: the server never reads it.
function View.hunterFade(ownerId, localId)
	if finite(ownerId) and finite(localId) and ownerId == localId then return 0 end
	return math.clamp(CONSTANTS.OTHER_SILUETA_FADE, 0, 1)
end

-- Fix pass (FP5d): a sleeping adult's breath at `seconds`: 0 at rest, BREATH_AMPLITUDE studs at the top, a smooth rise
-- and fall once per BREATH_SECONDS (BREATH_DEEP_SECONDS in the deep noon sleep). Presentation only.
function View.breath(seconds, deep)
	if not finite(seconds) then return 0 end
	local period = deep == true and CONSTANTS.BREATH_DEEP_SECONDS or CONSTANTS.BREATH_SECONDS
	if not finite(period) or period <= 0 then return 0 end
	return CONSTANTS.BREATH_AMPLITUDE * (1 - math.cos(2 * math.pi * seconds / period)) / 2
end

-- Look pass: how La Silueta's horror grin arrives when the server shows it (she starts a chase). A short snap from
-- small and transparent past full size; "Efectos suaves" (reduced = true) only fades it in, a little slower, no pop.
-- Returns { fromScale, fromAlpha, seconds, style } (style is an Enum.EasingStyle name).
local GRIN_POP = table.freeze({ fromScale = 0.35, fromAlpha = 1, seconds = 0.22, style = "Back" })
local GRIN_FADE = table.freeze({ fromScale = 1, fromAlpha = 1, seconds = 0.5, style = "Sine" })
function View.grinPop(reduced)
	return table.clone(reduced == true and GRIN_FADE or GRIN_POP)
end

-- RW7, the random world: a countdown as m:ss, never below zero.
local function countdown(seconds)
	seconds = finite(seconds) and math.max(0, math.ceil(seconds - 1e-9)) or 0
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

-- The wave board: input = { wave, endsAt, now, board = { { name, amount } }, words = WildboundText.WAVE, compact }.
-- Returns { title, lines } where every line fits the board budget; a long name is cut so the amount stays.
function View.waveBoard(input)
	if type(input) ~= "table" or not finite(input.wave) or type(input.words) ~= "table" then return nil end
	local words = input.words
	local budget = input.compact == true and View.CONSTANTS.COMPACT_BOARD_CHARS or View.CONSTANTS.BOARD_CHARS
	local left = finite(input.endsAt) and finite(input.now) and input.endsAt - input.now or 0
	local out = { title = View.fit(words.board:format(math.floor(input.wave), countdown(left)), budget), lines = {} }
	for index, row in ipairs(type(input.board) == "table" and input.board or {}) do
		if index > 3 then break end
		if type(row) == "table" and type(row.name) == "string" and finite(row.amount) then
			local amount = tostring(math.max(0, math.floor(row.amount + 0.5)))
			local room = budget - #words.row:format(index, "", amount)
			local name = #row.name > room and View.fit(row.name, math.max(1, room)) or row.name
			table.insert(out.lines, View.fit(words.row:format(index, name, amount), budget))
		end
	end
	if #out.lines == 0 then table.insert(out.lines, View.fit(words.empty, budget)) end
	return out
end

-- The biome event banner: input = { species (the shown word), endsAt, now, words = WildboundText.EVENT, compact }.
-- A phone gets the short form; the countdown always stays.
function View.eventBanner(input)
	if type(input) ~= "table" or type(input.words) ~= "table" or type(input.species) ~= "string" then return nil end
	local left = finite(input.endsAt) and finite(input.now) and input.endsAt - input.now or 0
	local compact = input.compact == true
	local text = (compact and input.words.bannerShort or input.words.banner):format(input.species, countdown(left))
	return View.fit(text, compact and View.CONSTANTS.COMPACT_BANNER_CHARS or View.CONSTANTS.BANNER_CHARS)
end

return View

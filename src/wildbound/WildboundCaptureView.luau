-- Pure view-model for the touch capture screen: what each state says, which glyph marks it, how the world
-- ring is drawn from the server clock, where the panel and the Stop button sit. Nothing here reads a service
-- or touches an interface object; the clock and every measurement are passed in. Shared with the client.
-- See docs/mechanics/wildbound-capture.md (Touch UI flow) and docs/ui/wildbound-world.md.
-- Delivery A: every word comes from the shared Spanish text module (H3), and the seal step has its own state (H1).
local View = {}
local Text = require(script.Parent:WaitForChild("WildboundText"))
local WORDS = Text.CAPTURE_VIEW

-- Hypotheses. CALM_REQUIRED, OUTSIDE_LIMIT and RING_VISIBLE copy the capture rule's numbers (a contract checks).
View.CONSTANTS = table.freeze({
	STALE_AFTER = 1,
	STEP_MARGIN = 1,
	RESULT_SECONDS = 3,
	RING_SEGMENTS = 32,
	MIN_SEGMENTS = 8,
	MAX_SEGMENTS = 64,
	RING_WIDTH = 0.35,
	RING_PULSE = 0.15,
	CALM_REQUIRED = 4.5,
	OUTSIDE_LIMIT = 2.5,
	RING_VISIBLE = 4.5,
	STOP_PREFERRED = 64,
	STOP_MIN = 56,
	PANEL_MIN_WIDTH = 190,
	PANEL_MIN_HEIGHT = 40,
	TEXT_INSET = 60,
	EDGE = 4,
	GAP = 4,
	GRID = 6,
})
local K = View.CONSTANTS

-- Colour is a redundant cue: every state also has its own words and glyph. Text keeps 4.5:1 on its panel
-- and the meter keeps 3:1 against both the panel and its track (contracts check all of it).
local function color(r, g, b) return table.freeze({ r = r, g = g, b = b }) end
local function tone(bg, text, fill, track, border)
	return table.freeze({ bg = bg, text = text, fill = fill, track = track, border = border })
end
View.TONES = table.freeze({
	calm = tone(color(22, 50, 38), color(232, 245, 236), color(112, 214, 150), color(8, 18, 12), color(112, 214, 150)),
	slow = tone(color(64, 48, 8), color(255, 236, 170), color(255, 196, 60), color(20, 16, 2), color(255, 196, 60)),
	step = tone(color(14, 48, 70), color(225, 243, 255), color(120, 200, 255), color(4, 14, 22), color(120, 200, 255)),
	outside = tone(color(110, 24, 24), color(255, 255, 255), color(255, 140, 110), color(30, 6, 6), color(255, 255, 255)),
	waiting = tone(color(40, 44, 48), color(222, 228, 232), color(176, 186, 196), color(14, 16, 18), color(176, 186, 196)),
	good = tone(color(18, 72, 40), color(255, 255, 255), color(150, 255, 176), color(6, 24, 12), color(150, 255, 176)),
	failed = tone(color(92, 30, 30), color(255, 255, 255), color(255, 150, 130), color(26, 8, 8), color(255, 255, 255)),
})
-- The world ring: bright and thick enough to read in fog at night. Amber when the player is outside it.
View.RING_COLORS = table.freeze({ inside = color(120, 255, 170), outside = color(255, 196, 60) })

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function validToken(value)
	return type(value) == "string" and #value > 0 and #value <= 128
end

local PHASES = table.freeze({ Active = true, Completed = true, Failed = true, Cancelled = true })

-- Headline per ending reason: { full, short }, from the text module. The short form is for phone panels.
local REASONS = Text.CAPTURE_HEADLINES

function View.reasonText(reason, compact)
	local row = type(reason) == "string" and REASONS[reason]
	if not row then return nil end
	return compact == true and row[2] or row[1]
end

local GLYPHS = table.freeze({
	Calm = "o", Slow = "||", Step = ">", Outside = "!", Waiting = "...", Caught = "OK", Failed = "X", Stopped = "=",
	Seal = "<>",
})

local function hidden()
	return { visible = false, state = "Idle", glyph = "", headline = "", detail = "", fraction = 0, tone = "waiting",
		ringStyle = "hidden", ringTone = "inside", arrow = false, pulse = false }
end

-- H2: the meter fills against the session's own target (a capture skill can lower it), else the rule's default.
local function fractionOf(calm, required)
	if type(calm) ~= "number" or calm ~= calm then return 0 end
	local target = finite(required) and required > 0 and required or K.CALM_REQUIRED
	return math.clamp(calm / target, 0, 1)
end

local function validSeal(seal)
	return type(seal) == "table" and finite(seal.startedAt) and finite(seal.sweep) and seal.sweep > 0
		and finite(seal.lo) and finite(seal.hi) and seal.lo >= 0 and seal.lo < seal.hi and seal.hi <= 1
end

-- H1: where the seal marker is on the bar at this server time, 0 to 1. It waits at 0 until the sweep starts.
function View.sealMarker(seal, serverNow)
	if not validSeal(seal) or not finite(serverNow) then return nil end
	return math.clamp((serverNow - seal.startedAt) / seal.sweep, 0, 1)
end

local function view(state, tonename, headline, detail, fraction, extra)
	local value = { visible = true, state = state, glyph = GLYPHS[state], headline = headline, detail = detail,
		fraction = fraction, tone = tonename, ringStyle = "hidden", ringTone = "inside", arrow = false, pulse = false }
	for key, item in pairs(extra or {}) do value[key] = item end
	return value
end

-- snap is the held CaptureState snapshot. info = { age, sinceEnd, ringDistance, reduced, compact, serverNow }:
-- age is seconds since the last push, sinceEnd seconds since the ending arrived, ringDistance the studs
-- from the player to the ring centre, serverNow the synced server clock for the seal marker.
-- Priority while active: waiting, seal, outside, slow, step, calm.
function View.status(snap, info)
	info = type(info) == "table" and info or {}
	if type(snap) ~= "table" or not PHASES[snap.phase] or not validToken(snap.token) then return hidden() end
	local compact = info.compact == true
	local fraction = fractionOf(snap.calm, snap.required)
	if snap.phase == "Active" then
		local stale = not finite(info.age) or info.age < 0 or info.age > K.STALE_AFTER
		if stale then
			return view("Waiting", "waiting", compact and WORDS.waitingShort or WORDS.waiting, WORDS.waitingDetail, fraction,
				{ ringStyle = "dashed" })
		end
		if snap.stage == "Seal" and validSeal(snap.seal) then
			return view("Seal", "step", compact and WORDS.sealShort or WORDS.seal, WORDS.sealDetail,
				View.sealMarker(snap.seal, info.serverNow) or 0, { band = { lo = snap.seal.lo, hi = snap.seal.hi } })
		end
		if snap.inside ~= true then
			local spent = finite(snap.outsideFor) and snap.outsideFor or 0
			local left = math.clamp(K.OUTSIDE_LIMIT - spent, 0, K.OUTSIDE_LIMIT)
			local line = (compact and WORDS.outsideShort or WORDS.outside) .. ("%.1fs"):format(left)
			return view("Outside", "outside", line, WORDS.outsideDetail, fraction,
				{ ringStyle = "dashed", ringTone = "outside", arrow = true })
		end
		if snap.moving == true then
			return view("Slow", "slow", WORDS.slow, WORDS.slowDetail, fraction, { ringStyle = "solid" })
		end
		if finite(info.ringDistance) and info.ringDistance >= K.RING_VISIBLE - K.STEP_MARGIN then
			return view("Step", "step", WORDS.step, WORDS.stepDetail, fraction,
				{ ringStyle = "solid", arrow = true, pulse = info.reduced ~= true })
		end
		return view("Calm", "calm", WORDS.calm, WORDS.calmDetail, fraction,
			{ ringStyle = "solid", pulse = info.reduced ~= true })
	end
	local showing = finite(info.sinceEnd) and info.sinceEnd >= 0 and info.sinceEnd < K.RESULT_SECONDS
	local notice = type(snap.notice) == "string" and snap.notice or ""
	if snap.reason == "Disconnected" then showing = false end
	local value
	if snap.phase == "Completed" then
		-- The headline already says the Caught word, so the line under it starts after it.
		local detail = notice
		if detail:sub(1, #WORDS.caught) == WORDS.caught then detail = (detail:sub(#WORDS.caught + 1):gsub("^%s+", "")) end
		value = view("Caught", "good", WORDS.caught, detail, 1)
	else
		local headline = View.reasonText(snap.reason, compact) or WORDS.ended
		value = view(snap.phase == "Cancelled" and "Stopped" or "Failed", "failed", headline, notice, fraction)
	end
	value.visible = showing
	return value
end

-- The token the Stop button sends back. Only a running session has one.
function View.stopToken(snap)
	if type(snap) ~= "table" or snap.phase ~= "Active" or not validToken(snap.token) then return nil end
	return snap.token
end

-- H1: the token the Seal button sends back. Only a running session with an open seal has one.
function View.sealToken(snap)
	if View.stopToken(snap) == nil or snap.stage ~= "Seal" or not validSeal(snap.seal) then return nil end
	return snap.token
end

local function validRing(ring)
	return type(ring) == "table" and finite(ring.pivotX) and finite(ring.pivotZ) and finite(ring.y)
		and finite(ring.orbit) and finite(ring.a0) and finite(ring.w) and finite(ring.startedAt)
		and finite(ring.radius) and ring.radius > 0
end

-- Fold a push into what is held. The ring comes once, with the first push, and is kept for that token.
-- A junk push changes nothing: the held value comes back as it was.
function View.merge(held, incoming)
	if type(incoming) ~= "table" or not PHASES[incoming.phase] or not validToken(incoming.token) then return held end
	local merged = table.clone(incoming)
	if validRing(incoming.ring) then
		merged.ring = table.clone(incoming.ring)
	elseif type(held) == "table" and held.token == incoming.token and validRing(held.ring) then
		merged.ring = held.ring
	else
		merged.ring = nil
	end
	merged.seal = validSeal(incoming.seal) and table.clone(incoming.seal) or nil
	return merged
end

-- Degrees clockwise from where the camera looks to the ring centre, seen from above, plus a plain word.
-- Returns nil when the player is on the centre or the camera look is unusable.
function View.arrow(px, pz, cx, cz, lookX, lookZ)
	if not (finite(px) and finite(pz) and finite(cx) and finite(cz) and finite(lookX) and finite(lookZ)) then return nil end
	local dx, dz = cx - px, cz - pz
	local distance = math.sqrt(dx * dx + dz * dz)
	local length = math.sqrt(lookX * lookX + lookZ * lookZ)
	if distance < 1e-6 or length < 1e-6 then return nil end
	local fx, fz = lookX / length, lookZ / length
	local rx, rz = -fz, fx
	local degrees = math.deg(math.atan2(dx * rx + dz * rz, dx * fx + dz * fz)) % 360
	return degrees, Text.ARROWS[math.floor((degrees + 22.5) / 45) % 8 + 1]
end

-- The detail line under the arrow: "Muévete <word>."
function View.moveLine(word)
	return WORDS.move:format(tostring(word))
end

-- The ring as short straight segments on the ground. rotY turns a part whose long side runs along X so it
-- follows the ring. Dashed hides every other segment, which is the "outside" form that needs no colour.
function View.ringSegments(cx, cz, radius, count, style)
	local list = {}
	if not (finite(cx) and finite(cz) and finite(radius)) or radius <= 0 then return list end
	local n = finite(count) and math.floor(count) or K.RING_SEGMENTS
	n = math.clamp(n, K.MIN_SEGMENTS, K.MAX_SEGMENTS)
	if n % 2 == 1 then n += 1 end
	local length = 2 * radius * math.sin(math.pi / n) * 1.05
	for index = 1, n do
		local angle = (index - 0.5) * 2 * math.pi / n
		local shown = style == "solid" or (style == "dashed" and index % 2 == 1)
		list[index] = { x = cx + radius * math.cos(angle), z = cz + radius * math.sin(angle),
			rotY = -(angle + math.pi / 2), length = length, visible = shown }
	end
	return list
end

-- Where the server's ring is at this server time, from the shared rule. Never reads a clock itself.
function View.ringCenterAt(ring, serverNow, session)
	if type(ring) ~= "table" or not finite(serverNow) or type(session) ~= "table" or type(session.ringCenter) ~= "function" then
		return nil, nil
	end
	local x, z = session.ringCenter(ring, serverNow - ring.startedAt)
	return x, z
end

function View.ringWidth(pulse, t)
	if pulse ~= true or not finite(t) then return K.RING_WIDTH end
	return K.RING_WIDTH + K.RING_PULSE * (0.5 + 0.5 * math.sin(2 * math.pi * t / 1.2))
end

-- Placement ------------------------------------------------------------------------------------------

local function rect(x, y, w, h)
	return { x = x, y = y, w = w, h = h }
end

local function validRect(value)
	return type(value) == "table" and finite(value.x) and finite(value.y) and finite(value.w) and finite(value.h)
		and value.w > 0 and value.h > 0
end

local function overlaps(a, b)
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

local function free(candidate, obstacles)
	for _, other in ipairs(obstacles) do
		if overlaps(candidate, other) then return false end
	end
	return true
end

-- Grid positions from low to high, always ending on the last position that still fits.
local function positions(low, high)
	local list = {}
	local at = low
	while at < high do
		table.insert(list, at)
		at += K.GRID
	end
	table.insert(list, math.max(low, high))
	return list
end

-- Largest first. Wide and short entries come before narrow ones, so a tall phone screen gets a full band.
local PANEL_SIZES = { { 340, 76 }, { 300, 72 }, { 340, 60 }, { 260, 64 }, { 300, 52 }, { 220, 56 }, { 190, 52 },
	{ 190, 44 }, { 190, 40 } }

local function findPanel(width, height, obstacles)
	for _, size in ipairs(PANEL_SIZES) do
		local w, h = size[1], size[2]
		if w <= width - 2 * K.EDGE and h <= height - 2 * K.EDGE then
			local best, bestCost
			for _, y in ipairs(positions(K.EDGE, height - K.EDGE - h)) do
				for _, x in ipairs(positions(K.EDGE, width - K.EDGE - w)) do
					local candidate = rect(x, y, w, h)
					if free(candidate, obstacles) then
						-- Low on the screen and centred, so the top stays for the HUD.
						local cost = math.abs(x + w / 2 - width / 2) + 2 * (height - K.EDGE - (y + h))
						if not best or cost < bestCost then best, bestCost = candidate, cost end
					end
				end
			end
			if best then return best end
		end
	end
	return nil
end

local function findStop(width, height, obstacles, panel)
	local around = rect(panel.x - K.GAP, panel.y - K.GAP, panel.w + 2 * K.GAP, panel.h + 2 * K.GAP)
	local blocked = table.clone(obstacles)
	table.insert(blocked, around)
	local px, py = panel.x + panel.w / 2, panel.y + panel.h / 2
	for _, side in ipairs({ K.STOP_PREFERRED, K.STOP_MIN }) do
		if side <= width - 2 * K.EDGE and side <= height - 2 * K.EDGE then
			local best, bestCost
			for _, y in ipairs(positions(K.EDGE, height - K.EDGE - side)) do
				for _, x in ipairs(positions(K.EDGE, width - K.EDGE - side)) do
					local candidate = rect(x, y, side, side)
					if free(candidate, blocked) then
						local cost = math.sqrt((x + side / 2 - px) ^ 2 + (y + side / 2 - py) ^ 2)
						if not best or cost < bestCost then best, bestCost = candidate, cost end
					end
				end
			end
			if best then return best end
		end
	end
	return nil
end

-- layout is the result of HudLayout.compute. The panel and the Stop button stay clear of every HUD rectangle,
-- the avatar keep-out and, on phones, the thumbstick and jump zones. When no free spot is big enough, the panel
-- takes the objective text's place (takesOver = "hud") and is drawn above it. Returns nil if nothing fits.
function View.layout(layout)
	if type(layout) ~= "table" or not finite(layout.width) or not finite(layout.height) or layout.width <= 0
		or layout.height <= 0 or type(layout.rects) ~= "table" or type(layout.zones) ~= "table"
		or not validRect(layout.zones.keepout) then
		return nil
	end
	local compact = layout.mode == "compact"
	local function obstaclesWithout(skip)
		local list = { layout.zones.keepout }
		if compact then
			if validRect(layout.zones.thumbstick) then table.insert(list, layout.zones.thumbstick) end
			if validRect(layout.zones.jump) then table.insert(list, layout.zones.jump) end
		end
		for name, item in pairs(layout.rects) do
			if name ~= skip and validRect(item) then table.insert(list, item) end
		end
		return list
	end
	local takesOver
	local obstacles = obstaclesWithout(nil)
	local panel = findPanel(layout.width, layout.height, obstacles)
	if not panel then
		local hud = layout.rects.hud
		if validRect(hud) and hud.w >= K.PANEL_MIN_WIDTH and hud.h >= K.PANEL_MIN_HEIGHT then
			panel, takesOver = rect(hud.x, hud.y, hud.w, hud.h), "hud"
			obstacles = obstaclesWithout("hud")
		end
	end
	if not panel then return nil end
	local stop = findStop(layout.width, layout.height, obstacles, panel)
	if not stop then return nil end
	local size = compact and 13 or 14
	return { panel = panel, stop = stop, takesOver = takesOver, compact = compact, textSize = size,
		chars = math.max(1, math.floor((panel.w - K.TEXT_INSET) / (size * 0.6))) }
end

return View

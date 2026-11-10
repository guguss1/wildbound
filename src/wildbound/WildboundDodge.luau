-- Esquiva perfecta (decision Q3b, docs/mechanics/wildbound-new-mechanics.md section 2): the timed dodge that replaces
-- the Burst. Every attack that can be dodged (a parent's close swing, Viper's dash, Pouncer's leap, La Silueta's lunge)
-- is registered by the server when its telegraph starts, with the server time of its strike. A press that arrives in
-- the perfect window (the last WINDOW seconds of the telegraph, up to the strike) cancels that hit and grants a short
-- speed boost. A press before the window (Early), after the strike (Late) or with nothing to dodge (Whiff) does nothing
-- and starts MISS_COOLDOWN; more than SPAM_LIMIT presses in SPAM_SECONDS lock the dodge out for SPAM_LOCKOUT. A
-- telegraph shorter than MIN_TELEGRAPH (0.8 s, the fair-strike warning lead) is refused, so every dodgeable attack
-- stays readable. Pure: the server passes its clock; the client only sends "dodge". No invulnerability: only the hits
-- whose window held the press are cancelled.
local Dodge = {}

Dodge.CONSTANTS = table.freeze({
	WINDOW = 0.35, -- seconds before the strike in which a press is perfect
	MIN_TELEGRAPH = 0.8, -- the shortest telegraph a dodgeable attack may have (tunable upward only)
	BOOST_SECONDS = 1, -- the speed boost after a perfect dodge
	BOOST_MULTIPLIER = 1.35, -- of the current speed (walk or sprint)
	BOOST_CAP = 26, -- studs per second at most (the Burst had 28)
	SUCCESS_COOLDOWN = 0.6, -- after a perfect dodge
	MISS_COOLDOWN = 1.2, -- after an early, late or empty press
	SPAM_LIMIT = 4, -- presses allowed in SPAM_SECONDS
	SPAM_SECONDS = 1,
	SPAM_LOCKOUT = 2, -- seconds locked out after a flood
	LATE_MEMORY = 0.6, -- seconds after a strike in which a press still reads as Late (not Whiff)
})
-- The fair-strike floor (docs/mechanics/wildbound-fair-strike.md, WARNING_LEAD 0.8): no tune goes below it.
Dodge.MIN_TELEGRAPH = 0.8
Dodge.SOURCES = table.freeze({ Parent = true, Viper = true, Pouncer = true, Silueta = true })
local EPSILON = 1e-6

-- Neutral Spanish player strings (the Studio writer may move them into WildboundText).
Dodge.TEXT = table.freeze({
	button = "Esquivar",
	cue = "¡Esquiva!",
	perfect = "¡Esquiva perfecta!",
	early = "Muy pronto",
	late = "Muy tarde",
})

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end
local function validId(value)
	return (type(value) == "number" and finite(value)) or (type(value) == "string" and #value > 0 and #value <= 64)
end

-- Dev tuning (docs/testing/wildbound-tuning.md): CONSTANTS stay the defaults the tests pin; the rules read `live`.
local C = {}
Dodge.live = C

function Dodge.tunable()
	return table.clone(Dodge.CONSTANTS)
end

function Dodge.tune(overrides)
	for key, value in pairs(Dodge.CONSTANTS) do C[key] = value end
	if type(overrides) == "table" then
		for key, value in pairs(overrides) do
			if Dodge.CONSTANTS[key] ~= nil and finite(value) then C[key] = value end
		end
	end
	C.MIN_TELEGRAPH = math.clamp(C.MIN_TELEGRAPH, Dodge.MIN_TELEGRAPH, 3)
	-- The window is a skill test: never more than half the shortest telegraph and never more than 0.5 s.
	C.WINDOW = math.clamp(C.WINDOW, 0.1, math.min(0.5, Dodge.MIN_TELEGRAPH / 2))
	C.BOOST_SECONDS = math.clamp(C.BOOST_SECONDS, 0.3, 2)
	C.BOOST_MULTIPLIER = math.clamp(C.BOOST_MULTIPLIER, 1, 1.6)
	C.BOOST_CAP = math.clamp(C.BOOST_CAP, 16, 28)
	C.SUCCESS_COOLDOWN = math.clamp(C.SUCCESS_COOLDOWN, 0.2, 5)
	C.MISS_COOLDOWN = math.clamp(C.MISS_COOLDOWN, 0.5, 5)
	C.SPAM_LIMIT = math.clamp(math.floor(C.SPAM_LIMIT + 0.5), 2, 10)
	C.SPAM_SECONDS = math.clamp(C.SPAM_SECONDS, 0.5, 3)
	C.SPAM_LOCKOUT = math.clamp(C.SPAM_LOCKOUT, 0.5, 5)
	C.LATE_MEMORY = math.clamp(C.LATE_MEMORY, 0.1, 2)
end
Dodge.tune(nil)

-- One state per player.
function Dodge.new()
	return {
		attacks = {}, cooldownUntil = -math.huge, lockedUntil = -math.huge, boostUntil = -math.huge,
		presses = {}, lastStrikeAt = -math.huge,
	}
end

-- The perfect window of a telegraph that starts at `startAt` and strikes at `strikeAt`.
function Dodge.window(startAt, strikeAt)
	return math.max(startAt, strikeAt - C.WINDOW), strikeAt
end

-- The server registers an attack aimed at this player when its telegraph starts. Returns true, or false and "Invalid",
-- "BadId", "BadSource", "BadClock", "ShortTelegraph" or "Duplicate".
function Dodge.telegraph(state, id, sourceName, startAt, strikeAt)
	if type(state) ~= "table" then return false, "Invalid" end
	if not validId(id) then return false, "BadId" end
	if not Dodge.SOURCES[sourceName] then return false, "BadSource" end
	if not finite(startAt) or not finite(strikeAt) then return false, "BadClock" end
	if strikeAt - startAt < C.MIN_TELEGRAPH - EPSILON then return false, "ShortTelegraph" end
	if state.attacks[id] then return false, "Duplicate" end
	local open, close = Dodge.window(startAt, strikeAt)
	state.attacks[id] = { source = sourceName, startAt = startAt, strikeAt = strikeAt, open = open, close = close,
		dodged = false }
	return true
end

-- Counts this press and reports whether the recent ones are a flood.
local function flood(state, now)
	local kept = {}
	for _, at in ipairs(state.presses) do
		if now - at < C.SPAM_SECONDS then table.insert(kept, at) end
	end
	table.insert(kept, now)
	state.presses = kept
	return #kept > C.SPAM_LIMIT
end

-- The client's "dodge". ctx = { blocked = hidden, capturing, ragdolled or dead }. Returns one of "Perfect" (with
-- { dodged = { ids }, boostUntil }), "Early", "Late", "Whiff", "Cooldown", "Blocked", "Spam" or "Invalid".
function Dodge.press(state, now, ctx)
	if type(state) ~= "table" or not finite(now) then return "Invalid" end
	if now < state.lockedUntil then return "Spam" end
	if flood(state, now) then
		state.lockedUntil = now + C.SPAM_LOCKOUT
		return "Spam"
	end
	if type(ctx) == "table" and ctx.blocked == true then return "Blocked" end
	if now < state.cooldownUntil - EPSILON then return "Cooldown" end

	local dodged, early, late = {}, false, now - state.lastStrikeAt <= C.LATE_MEMORY + EPSILON
	for id, attack in pairs(state.attacks) do
		if not attack.dodged then
			if now >= attack.open - EPSILON and now <= attack.close + EPSILON then
				table.insert(dodged, id)
			elseif now < attack.open then
				early = true
			else
				late = true
			end
		end
	end
	if #dodged > 0 then
		table.sort(dodged, function(a, b) return tostring(a) < tostring(b) end)
		for _, id in ipairs(dodged) do state.attacks[id].dodged = true end
		state.boostUntil = now + C.BOOST_SECONDS
		state.cooldownUntil = now + C.SUCCESS_COOLDOWN
		return "Perfect", { dodged = dodged, boostUntil = state.boostUntil }
	end
	state.cooldownUntil = now + C.MISS_COOLDOWN
	if early then return "Early" end
	if late then return "Late" end
	return "Whiff"
end

-- The server asks when the attack would land. Returns "Dodged" (cancel the hit), "Hit" or "Unknown". Once only.
function Dodge.resolve(state, id, now)
	if type(state) ~= "table" or not validId(id) then return "Unknown" end
	local attack = state.attacks[id]
	if not attack then return "Unknown" end
	state.attacks[id] = nil
	if finite(now) then state.lastStrikeAt = now end
	return attack.dodged and "Dodged" or "Hit"
end

-- An attack that ended without a strike (a fair-strike cancel, the beast gave up).
function Dodge.cancel(state, id)
	if type(state) ~= "table" or not validId(id) or not state.attacks[id] then return false end
	state.attacks[id] = nil
	return true
end

-- Drops attacks the server never resolved, LATE_MEMORY after their strike.
function Dodge.prune(state, now)
	if type(state) ~= "table" or not finite(now) then return end
	for id, attack in pairs(state.attacks) do
		if now > attack.strikeAt + C.LATE_MEMORY then state.attacks[id] = nil end
	end
end

function Dodge.boosting(state, now)
	return type(state) == "table" and finite(now) and now < state.boostUntil - EPSILON
end

-- The speed while boosted: the given speed times BOOST_MULTIPLIER, capped at BOOST_CAP and never slower.
function Dodge.speed(state, base, now)
	if not finite(base) or base < 0 then return 0 end
	if not Dodge.boosting(state, now) then return base end
	return math.max(base, math.min(base * C.BOOST_MULTIPLIER, C.BOOST_CAP))
end

return Dodge

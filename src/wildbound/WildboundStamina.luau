-- Pure stamina, sprint and exhaustion (delivery D2, docs/mechanics/wildbound-delivery-d.md section 2), with the two
-- costs of the dread pass (decision D-D5, the user chose "make sprint cost something"): sprinting is loud, and a
-- carried Lumipol is frightened by it until it slips free. The server owns this state and WalkSpeed; the client only
-- sends an intent. The clock and the horizontal speed are passed in. Every number is a hypothesis to tune in play.
local Stamina = {}

Stamina.CONSTANTS = table.freeze({
	POOL = 100, -- full at spawn and after respawn; never saved
	-- of the current walk speed, so carry, egg and pouch costs still count. Chase pass (CP-D2): 1.45 (was 1.3), so a
	-- rested sprint (23.2) outruns La Silueta's fastest hunt (17) by 6 studs/s and the difference is felt.
	SPRINT_MULTIPLIER = 1.45,
	SPEED_CAP = 24,
	DRAIN = 25, -- per second while sprinting and moving: a full pool lasts 4 s
	START = 10, -- a sprint needs this much to start
	RECOVER = 30, -- after reaching 0, no sprint until stamina is back here
	REGEN_DELAY = 1.5, -- seconds after the last drain
	REGEN_WALK = 10, -- per second while moving
	REGEN_STILL = 15, -- per second standing still or hiding
	MOVING_SPEED = 4, -- horizontal studs per second; holding sprint in place costs nothing
	NOISE_INTERVAL = 1.2, -- one `sprint` noise at most this often, never in camp
	INTENT_SECONDS = 1.2, -- an intent not refreshed this long counts as walk
	FEAR_RISE = 30, -- carried Lumipol fear per second of sprinting outside camp
	FEAR_FALL = 12, -- per second otherwise
	FEAR_WARN = 45, -- the warning cue (1.5 s into a sprint)
	FEAR_SLIP = 100, -- it slips free (3.4 s into a sprint, before a full pool runs out)
	-- Nest Heist (NH4): the Burst. For BURST_SECONDS the speed is the walk speed times BURST_MULTIPLIER (never slower
	-- than the current stance, never over BURST_CAP: it does not stack on the sprint), then BURST_COOLDOWN before the
	-- next. It steers with the player's own move direction (it is WalkSpeed) and gives no invulnerability.
	BURST_SECONDS = 0.8,
	BURST_MULTIPLIER = 1.7,
	BURST_COOLDOWN = 6,
	BURST_CAP = 28,
})
local EPSILON = 1e-6
local INTENTS = { sprint = true, walk = true }

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- Dev tuning (docs/testing/wildbound-tuning.md): CONSTANTS stay the defaults the tests pin; the rules read `live`, a
-- copy the server's tuning bridge may override at runtime. No override, no change. `version` counts the tunes, so the
-- server re-applies WalkSpeed after a sprint value changes.
local C = {}
Stamina.live = C
Stamina.version = 0

function Stamina.tunable()
	local defaults = {}
	for key, value in pairs(Stamina.CONSTANTS) do
		if type(value) == "number" then defaults[key] = value end
	end
	return defaults
end

-- overrides: { [constant] = number }. Unknown keys and non-finite values are ignored; nil restores the defaults.
function Stamina.tune(overrides)
	local defaults = Stamina.tunable()
	for key, value in pairs(defaults) do C[key] = value end
	if type(overrides) == "table" then
		for key, value in pairs(overrides) do
			if defaults[key] ~= nil and finite(value) then C[key] = value end
		end
	end
	Stamina.version += 1
end
Stamina.tune(nil)

function Stamina.new(now)
	return {
		stamina = C.POOL, stance = "walk", exhausted = false, fear = 0, warned = false,
		intent = "walk", intentAt = finite(now) and now or 0, lastDrainAt = -math.huge, lastNoiseAt = -math.huge,
		burstUntil = -math.huge, burstReadyAt = -math.huge, bursting = false,
	}
end

-- The client's request. Only two words are known; anything else is ignored.
function Stamina.intent(state, value, now)
	if type(state) ~= "table" or type(value) ~= "string" or not INTENTS[value] or not finite(now) then return false end
	state.intent, state.intentAt = value, now
	return true
end

-- Sprint is the walk speed times 1.45, capped at 24 and never slower than the walk. Other stances keep the walk.
-- NH4: bursting, the walk speed times BURST_MULTIPLIER, capped at BURST_CAP and never slower than the stance's speed.
function Stamina.speed(base, stance, bursting)
	if not finite(base) or base < 0 then return 0 end
	local speed = base
	if stance == "sprint" then speed = math.max(base, math.min(base * C.SPRINT_MULTIPLIER, C.SPEED_CAP)) end
	if bursting == true then speed = math.max(speed, math.min(base * C.BURST_MULTIPLIER, C.BURST_CAP)) end
	return speed
end

-- NH4: the client's burst request. input = { blocked = a capture, a hiding spot, no live character }. Returns true, or
-- false and "Blocked" or "Cooldown". The cooldown runs from the start of the burst.
function Stamina.burst(state, now, input)
	if type(state) ~= "table" or not finite(now) then return false, "Invalid" end
	if type(input) == "table" and input.blocked == true then return false, "Blocked" end
	if now < (state.burstReadyAt or -math.huge) - EPSILON then return false, "Cooldown" end
	-- NS7: a glove's Burst recovery shortens the cooldown, never below half of it.
	local scale = type(input) == "table" and finite(input.cooldownScale) and math.clamp(input.cooldownScale, 0.5, 1) or 1
	state.burstUntil, state.burstReadyAt, state.bursting = now + C.BURST_SECONDS, now + C.BURST_COOLDOWN * scale, true
	return true
end

function Stamina.bursting(state, now)
	return type(state) == "table" and finite(now) and now < (state.burstUntil or -math.huge) - EPSILON
end

-- One step. input = { speed = horizontal studs/s, blocked = capture, hidden or dead, carrying = a creature is
-- carried, inCamp = inside the safe circle, regenScale? (a Refugio), drainScale? (the Botas) }. Returns { noise,
-- warn, slip, changed } as booleans.
function Stamina.step(state, dt, input, now)
	local out = { noise = false, warn = false, slip = false, changed = false }
	if type(state) ~= "table" or type(input) ~= "table" or not finite(dt) or dt < 0 or not finite(now) then return out end
	dt = math.min(dt, 1)
	local before = state.stance
	local moving = finite(input.speed) and input.speed >= C.MOVING_SPEED
	local fresh = now - state.intentAt <= C.INTENT_SECONDS + EPSILON
	local wants = state.intent == "sprint" and fresh and input.blocked ~= true
	if state.exhausted and state.stamina >= C.RECOVER - EPSILON then state.exhausted = false end
	-- NH4: a burst ends at its time or the moment something blocks the player; the edge re-applies the speed.
	if input.blocked == true and (state.burstUntil or -math.huge) > now then state.burstUntil = now end
	local bursting = Stamina.bursting(state, now)
	local burstChanged = bursting ~= (state.bursting == true)
	state.bursting = bursting
	local threshold = before == "sprint" and EPSILON or C.START - EPSILON
	if wants and moving and not state.exhausted and state.stamina >= threshold then
		state.stance = "sprint"
		-- Items and totem (IT1): the Botas pass drainScale under 1; anything not in (0, 1] is 1, so it never costs more.
		local drain = finite(input.drainScale) and input.drainScale > 0 and input.drainScale <= 1 and input.drainScale or 1
		state.stamina -= C.DRAIN * drain * dt
		state.lastDrainAt = now
		if state.stamina <= EPSILON then
			state.stamina, state.exhausted, state.stance = 0, true, "exhausted"
		end
	else
		state.stance = state.exhausted and "exhausted" or "walk"
		if now - state.lastDrainAt >= C.REGEN_DELAY - EPSILON then
			local rate = moving and C.REGEN_WALK or C.REGEN_STILL
			-- Random world (RW4): a Refugio passes regenScale 2; anything that is not a positive number is 1.
			local scale = finite(input.regenScale) and input.regenScale > 0 and input.regenScale or 1
			state.stamina = math.min(C.POOL, state.stamina + rate * scale * dt)
		end
		if state.exhausted and state.stamina >= C.RECOVER - EPSILON then
			state.exhausted, state.stance = false, "walk"
		end
	end
	local sprinting = state.stance == "sprint"
	if sprinting and input.inCamp ~= true and now - state.lastNoiseAt >= C.NOISE_INTERVAL - EPSILON then
		state.lastNoiseAt = now
		out.noise = true
	end
	if input.carrying == true then
		if sprinting and input.inCamp ~= true then
			state.fear += C.FEAR_RISE * dt
		else
			state.fear = math.max(0, state.fear - C.FEAR_FALL * dt)
		end
		if state.fear < C.FEAR_WARN / 2 then state.warned = false end
		if state.fear >= C.FEAR_WARN - EPSILON and not state.warned then
			state.warned, out.warn = true, true
		end
		if state.fear >= C.FEAR_SLIP - EPSILON then
			state.fear, state.warned, out.slip = 0, false, true
		end
	else
		state.fear, state.warned = 0, false
	end
	out.changed = state.stance ~= before or burstChanged
	return out
end

return Stamina

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
})
local C = Stamina.CONSTANTS
local EPSILON = 1e-6
local INTENTS = { sprint = true, walk = true }

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function Stamina.new(now)
	return {
		stamina = C.POOL, stance = "walk", exhausted = false, fear = 0, warned = false,
		intent = "walk", intentAt = finite(now) and now or 0, lastDrainAt = -math.huge, lastNoiseAt = -math.huge,
	}
end

-- The client's request. Only two words are known; anything else is ignored.
function Stamina.intent(state, value, now)
	if type(state) ~= "table" or type(value) ~= "string" or not INTENTS[value] or not finite(now) then return false end
	state.intent, state.intentAt = value, now
	return true
end

-- Sprint is the walk speed times 1.45, capped at 24 and never slower than the walk. Other stances keep the walk.
function Stamina.speed(base, stance)
	if not finite(base) or base < 0 then return 0 end
	if stance ~= "sprint" then return base end
	return math.max(base, math.min(base * C.SPRINT_MULTIPLIER, C.SPEED_CAP))
end

-- One step. input = { speed = horizontal studs/s, blocked = capture, hidden or dead, carrying = a creature is
-- carried, inCamp = inside the safe circle }. Returns { noise, warn, slip, changed } as booleans.
function Stamina.step(state, dt, input, now)
	local out = { noise = false, warn = false, slip = false, changed = false }
	if type(state) ~= "table" or type(input) ~= "table" or not finite(dt) or dt < 0 or not finite(now) then return out end
	dt = math.min(dt, 1)
	local before = state.stance
	local moving = finite(input.speed) and input.speed >= C.MOVING_SPEED
	local fresh = now - state.intentAt <= C.INTENT_SECONDS + EPSILON
	local wants = state.intent == "sprint" and fresh and input.blocked ~= true
	if state.exhausted and state.stamina >= C.RECOVER - EPSILON then state.exhausted = false end
	local threshold = before == "sprint" and EPSILON or C.START - EPSILON
	if wants and moving and not state.exhausted and state.stamina >= threshold then
		state.stance = "sprint"
		state.stamina -= C.DRAIN * dt
		state.lastDrainAt = now
		if state.stamina <= EPSILON then
			state.stamina, state.exhausted, state.stance = 0, true, "exhausted"
		end
	else
		state.stance = state.exhausted and "exhausted" or "walk"
		if now - state.lastDrainAt >= C.REGEN_DELAY - EPSILON then
			local rate = moving and C.REGEN_WALK or C.REGEN_STILL
			state.stamina = math.min(C.POOL, state.stamina + rate * dt)
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
	out.changed = state.stance ~= before
	return out
end

return Stamina

-- Rabia creciente, Don Glaseon's rising anger (odd/tasks/wildbound-caramelo-v2.md, DG5; decision taken for the user
-- 2026-11-15: both time and dodges, for the current target). Pure server rules on one meter per encounter.
-- The meter (0 to 1) rises by 1/FILL_SECONDS a second while his target carries an egg inside his territory, and each
-- perfect dodge of his lash adds DODGE_CHUNK. Full, he rages for RAGE_SECONDS: his cooldowns are scaled by
-- COOLDOWN_SCALE (his tells never go under the 0.8 s floor). The meter resets to empty when the target no longer
-- carries an egg or leaves the territory (a rage ends with it), and after a rage. step and dodge return a report
-- { value, rage } when it is worth telling the clients (each REPORT_STEP, a rage, a reset), else nil; the clients
-- tint him toward red.
-- Every number is a starting proposal to tune in play. Rules: WildboundCandyDonGlaseonAnger_Test.
local Anger = {}
Anger.FILL_SECONDS = 10
Anger.DODGE_CHUNK = 0.25
Anger.RAGE_SECONDS = 10
Anger.COOLDOWN_SCALE = 0.5
Anger.REPORT_STEP = 0.1
local EPSILON = 1e-6

function Anger.new()
	return { value = 0, rageUntil = nil, lastAt = nil, reported = 0 }
end

function Anger.raging(state, now)
	return state.rageUntil ~= nil and now < state.rageUntil - EPSILON
end

function Anger.cooldownScale(state, now)
	return Anger.raging(state, now) and Anger.COOLDOWN_SCALE or 1
end

local function report(state)
	state.reported = state.value
	return { value = state.value, rage = state.rageUntil ~= nil }
end

local function check(state, now)
	if state.value >= 1 - EPSILON then
		state.value = 1
		state.rageUntil = now + Anger.RAGE_SECONDS
		return report(state)
	end
	if state.value - state.reported >= Anger.REPORT_STEP - EPSILON then return report(state) end
	return nil
end

local function empty(state)
	state.value, state.rageUntil = 0, nil
	return report(state)
end

-- One step at server time now. building: the target carries an egg inside his territory.
function Anger.step(state, now, building)
	local dt = state.lastAt and math.max(0, now - state.lastAt) or 0
	state.lastAt = now
	if state.rageUntil then
		if not building or now >= state.rageUntil - EPSILON then return empty(state) end
		return nil
	end
	if not building then
		if state.value > 0 or state.reported > 0 then return empty(state) end
		return nil
	end
	state.value = math.min(1, state.value + dt / Anger.FILL_SECONDS)
	return check(state, now)
end

-- A perfect dodge of his lash. Nothing during a rage.
function Anger.dodge(state, now)
	if state.rageUntil then return nil end
	state.value = math.min(1, state.value + Anger.DODGE_CHUNK)
	return check(state, now)
end

return Anger

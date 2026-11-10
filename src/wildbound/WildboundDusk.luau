-- Dusk (decision Q11, docs/mechanics/wildbound-new-mechanics.md section 5): the pre-night stage. The day cycle in
-- WildboundWorldRules already has a 72 s "Dusk" phase between Day and Night; this rule reads that cycle (passed in by
-- value, never the clock) and turns it into two warnings (once when Dusk starts, once NIGHT_SOON seconds before Night)
-- and a small beast buff that holds only during Dusk: a little faster, a little keener, a little more likely to roll.
-- Night keeps its own multipliers (the director's night x2); the dusk buff never stacks into Night. Pure and shared:
-- the server fires the warnings, the client may show the same lines. Every number is a hypothesis to tune in play.
local Dusk = {}

Dusk.PHASE = "Dusk" -- the phase name WildboundWorldRules.cycle returns
Dusk.CONSTANTS = table.freeze({
	SPEED_MULTIPLIER = 1.08, -- beast movement speed during Dusk
	ROLL_MULTIPLIER = 1.25, -- the beast director's per-roll odds during Dusk (Night is x2)
	DETECTION_MULTIPLIER = 1.1, -- guardian and beast detection ranges during Dusk
	NIGHT_SOON = 20, -- seconds of Dusk left when the second warning fires
})

-- Neutral Spanish player strings (the Studio writer may move them into WildboundText).
Dusk.TEXT = table.freeze({
	dusk = "Está anocheciendo. Las bestias se inquietan: vuelve a tu base antes de la noche.",
	soon = "La noche llega en %d s.",
})

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- Dev tuning (docs/testing/wildbound-tuning.md): CONSTANTS stay the defaults the tests pin; the rules read `live`.
local C = {}
Dusk.live = C

function Dusk.tunable()
	return table.clone(Dusk.CONSTANTS)
end

function Dusk.tune(overrides)
	for key, value in pairs(Dusk.CONSTANTS) do C[key] = value end
	if type(overrides) == "table" then
		for key, value in pairs(overrides) do
			if Dusk.CONSTANTS[key] ~= nil and finite(value) then C[key] = value end
		end
	end
	-- A small buff: never a slowdown, always well under the night multiplier.
	C.SPEED_MULTIPLIER = math.clamp(C.SPEED_MULTIPLIER, 1, 1.15)
	C.ROLL_MULTIPLIER = math.clamp(C.ROLL_MULTIPLIER, 1, 1.5)
	C.DETECTION_MULTIPLIER = math.clamp(C.DETECTION_MULTIPLIER, 1, 1.25)
	-- The second warning stays inside the 72 s dusk.
	C.NIGHT_SOON = math.clamp(C.NIGHT_SOON, 5, 60)
end
Dusk.tune(nil)

local NEUTRAL = table.freeze({ speed = 1, roll = 1, detection = 1 })

-- The beast multipliers for a phase name: the dusk buff during Dusk, 1 otherwise.
function Dusk.buff(phase)
	if phase ~= Dusk.PHASE then return NEUTRAL end
	return { speed = C.SPEED_MULTIPLIER, roll = C.ROLL_MULTIPLIER, detection = C.DETECTION_MULTIPLIER }
end

function Dusk.new()
	return { inDusk = false, soonSent = false }
end

-- One observation of the cycle ({ phase, remaining }, as WildboundWorldRules.cycle returns it). Returns { phase,
-- enteredDusk, nightSoon, seconds (for the second line), buff }. Each warning fires once per dusk; a server that starts
-- inside Dusk warns at once, and one that starts in its last NIGHT_SOON seconds sends only the first line.
function Dusk.step(state, cycle)
	local phase = type(cycle) == "table" and cycle.phase or nil
	local out = { phase = phase, enteredDusk = false, nightSoon = false, seconds = nil, buff = Dusk.buff(phase) }
	if type(state) ~= "table" then return out end
	if phase ~= Dusk.PHASE then
		state.inDusk, state.soonSent = false, false
		return out
	end
	local remaining = cycle.remaining
	local soon = finite(remaining) and remaining <= C.NIGHT_SOON
	if not state.inDusk then
		state.inDusk, state.soonSent = true, soon
		out.enteredDusk = true
	elseif soon and not state.soonSent then
		state.soonSent = true
		out.nightSoon, out.seconds = true, math.max(1, math.ceil(remaining))
	end
	return out
end

-- The player line for "dusk" or "soon" (with the seconds left); nil for anything else.
function Dusk.message(kind, seconds)
	if kind == "dusk" then return Dusk.TEXT.dusk end
	if kind == "soon" then return string.format(Dusk.TEXT.soon, finite(seconds) and math.ceil(seconds) or C.NIGHT_SOON) end
	return nil
end

return Dusk

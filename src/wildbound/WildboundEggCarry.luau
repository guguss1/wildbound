-- Nest Heist, phase 1 (docs/design/wildbound-combined-plan.md sections 1, 2 and 4): pure server rules for stealing an
-- egg and carrying it in the arms. Positions, time and randomness are passed in; nothing here reads the world.
-- NH1 fast steal: a normal egg (Común or Rara) is taken with a short hold, STEAL_HOLD; a rare egg (Épica,
-- Legendaria) or the biome event's special egg keeps the slower hold it always had, RARE_HOLD. No egg has a ring.
-- Every number is a hypothesis to tune in play.
local EggCarry = {}

EggCarry.CONSTANTS = table.freeze({
	STEAL_HOLD = 0.8, -- seconds, the master prompt's 0.6 to 1 s
	RARE_HOLD = 1, -- the hold every egg had before (I3)
})
EggCarry.STEAL_HOLD_MIN, EggCarry.STEAL_HOLD_MAX = 0.6, 1
local RARE = table.freeze({ Epica = true, Legendaria = true })

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- Dev tuning (docs/testing/wildbound-tuning.md): CONSTANTS stay the defaults the tests pin; the server's tuning bridge
-- overrides `live`. No override, no change.
local C = {}
EggCarry.live = C

function EggCarry.tunable()
	return table.clone(EggCarry.CONSTANTS)
end

function EggCarry.tune(overrides)
	for key, value in pairs(EggCarry.CONSTANTS) do C[key] = value end
	if type(overrides) == "table" then
		for key, value in pairs(overrides) do
			if EggCarry.CONSTANTS[key] ~= nil and finite(value) then C[key] = value end
		end
	end
	C.STEAL_HOLD = math.clamp(C.STEAL_HOLD, EggCarry.STEAL_HOLD_MIN, EggCarry.STEAL_HOLD_MAX)
	C.RARE_HOLD = math.max(C.RARE_HOLD, C.STEAL_HOLD)
end
EggCarry.tune(nil)

-- NH1: the prompt hold for an egg of this rarity tier ("Comun", "Rara", "Epica", "Legendaria"); special: the biome
-- event's egg. An unknown tier is a normal egg.
function EggCarry.holdFor(rarity, special)
	if special == true or RARE[rarity] then return C.RARE_HOLD end
	return C.STEAL_HOLD
end

return EggCarry

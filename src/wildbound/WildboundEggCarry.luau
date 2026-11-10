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

-- NH2: one record per egg, keyed by a unique id (the server uses the egg's encounter id). States:
--   InNest: lying in its nest or spawn point, waiting for a thief;
--   Carried: in one player's arms (carrier = the player's key); a player carries at most one egg;
--   Dropped, Secured, Despawning: see NH5 and NH6.
-- The registry is plain data; the server is single-threaded and never yields between a check and its change, so the
-- first valid request wins.
EggCarry.STATES = table.freeze({ "InNest", "Carried", "Dropped", "Secured", "Despawning" })

local function validId(value)
	return type(value) == "string" and #value > 0 and #value <= 64
end
local function validKey(value)
	return (type(value) == "number" and finite(value)) or (type(value) == "string" and #value > 0 and #value <= 64)
end

function EggCarry.new()
	return { eggs = {}, carriers = {} }
end

-- meta: what the server needs back later (species, rarity, island, reward tier); copied, never trusted from a client.
function EggCarry.add(registry, id, meta)
	if type(registry) ~= "table" or not validId(id) or registry.eggs[id] ~= nil then return nil end
	local egg = { id = id, state = "InNest", carrier = nil, uid = nil,
		meta = type(meta) == "table" and table.clone(meta) or {} }
	registry.eggs[id] = egg
	return egg
end

function EggCarry.get(registry, id)
	return type(registry) == "table" and validId(id) and registry.eggs[id] or nil
end

-- The egg this player carries, or nil.
function EggCarry.carriedBy(registry, key)
	if type(registry) ~= "table" or not validKey(key) then return nil end
	local id = registry.carriers[key]
	local egg = id and registry.eggs[id]
	if egg and egg.state == "Carried" and egg.carrier == key then return egg end
	return nil
end

-- Whether this player may take this egg out of its nest now. Returns true, or false and a reason.
function EggCarry.canSteal(registry, id, key)
	if not validKey(key) then return false, "InvalidPlayer" end
	local egg = EggCarry.get(registry, id)
	if not egg then return false, "NoEgg" end
	if egg.state ~= "InNest" then return false, "NotInNest" end
	if EggCarry.carriedBy(registry, key) then return false, "AlreadyCarrying" end
	return true
end

-- InNest to Carried. uid: the bag entry the server's state created for it (how the chest banks it later).
function EggCarry.steal(registry, id, key, uid)
	local ok, reason = EggCarry.canSteal(registry, id, key)
	if not ok then return false, reason end
	local egg = registry.eggs[id]
	egg.state, egg.carrier, egg.uid = "Carried", key, uid
	registry.carriers[key] = id
	return true, egg
end

-- An egg still in its nest leaves the registry with its encounter (a spawn that moved or expired). A carried, dropped or
-- secured egg is not the encounter's any more and stays.
function EggCarry.retire(registry, id)
	local egg = EggCarry.get(registry, id)
	if not egg or egg.state ~= "InNest" then return false end
	registry.eggs[id] = nil
	return true
end

function EggCarry.count(registry, state)
	local total = 0
	if type(registry) ~= "table" then return 0 end
	for _, egg in pairs(registry.eggs) do
		if state == nil or egg.state == state then total += 1 end
	end
	return total
end

return EggCarry

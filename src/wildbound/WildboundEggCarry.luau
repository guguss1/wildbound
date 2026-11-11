-- Nest Heist, phase 1 (docs/design/wildbound-combined-plan.md sections 1, 2 and 4): pure server rules for stealing an
-- egg and carrying it in the arms. Positions, time and randomness are passed in; nothing here reads the world.
-- NH1 fast steal: a normal egg (Común or Rara) is taken with a short hold, STEAL_HOLD; a rare egg (Épica,
-- Legendaria) or the biome event's special egg keeps the slower hold it always had, RARE_HOLD. No egg has a ring.
-- Every number is a hypothesis to tune in play.
local EggCarry = {}

EggCarry.CONSTANTS = table.freeze({
	STEAL_HOLD = 0.8, -- seconds, the master prompt's 0.6 to 1 s
	RARE_HOLD = 1, -- the hold every egg had before (I3)
	-- NH5 drop and pickup: a dropped egg can be picked up by anyone after PICKUP_DELAY, with a PICKUP_HOLD hold within
	-- PICKUP_RANGE studs; left alone for DROP_SECONDS it fades for DESPAWN_SECONDS and is gone. A drop lands on the
	-- first ground found within LAND_DEPTH studs under the player, else on the relief.
	PICKUP_DELAY = 0.4,
	PICKUP_HOLD = 0.4,
	PICKUP_RANGE = 10,
	DROP_SECONDS = 30,
	DESPAWN_SECONDS = 1,
	LAND_DEPTH = 40,
	-- Hub follow-up (HF-T2): how much shorter than the effective hold a steal may be, as the server measures it, to
	-- absorb latency (HB-T7 used 0.2 s, too tight). Clamped to HOLD_ALLOWANCE_MIN..MAX, so a clearly short trigger
	-- still refuses (at the 0.6 s glove floor a hold of at least 0.1 s is always needed).
	HOLD_ALLOWANCE = 0.35,
})
EggCarry.STEAL_HOLD_MIN, EggCarry.STEAL_HOLD_MAX = 0.6, 1
EggCarry.PICKUP_HOLD_MIN, EggCarry.PICKUP_HOLD_MAX = 0.3, 0.5
-- Nest Heist phase 2 (NP1): State:takeEgg refuses a pickup beyond 10 studs, so the tunable reach never exceeds it.
EggCarry.PICKUP_RANGE_MAX = 10
EggCarry.HOLD_ALLOWANCE_MIN, EggCarry.HOLD_ALLOWANCE_MAX = 0.05, 0.5
-- Why an egg leaves the arms. Inside a safe zone (camp, a Refugio) only a death or leaving the server drops it.
EggCarry.DROP_REASONS = table.freeze({ Death = true, Hit = true, Strike = true, Bat = true, Leave = true })
local SAFE_DROPS = table.freeze({ Death = true, Leave = true })
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
	C.PICKUP_HOLD = math.clamp(C.PICKUP_HOLD, EggCarry.PICKUP_HOLD_MIN, EggCarry.PICKUP_HOLD_MAX)
	C.PICKUP_DELAY = math.max(C.PICKUP_DELAY, 0)
	C.PICKUP_RANGE = math.clamp(C.PICKUP_RANGE, 1, EggCarry.PICKUP_RANGE_MAX)
	C.HOLD_ALLOWANCE = math.clamp(C.HOLD_ALLOWANCE, EggCarry.HOLD_ALLOWANCE_MIN, EggCarry.HOLD_ALLOWANCE_MAX)
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

-- NH5: the one way an egg leaves the arms undelivered. opts = { safe = the carrier stands in a safe zone }. Returns
-- true and the egg (now Dropped, nobody's), or false and a reason ("NotCarrying", "BadReason", "SafeZone").
function EggCarry.drop(registry, key, reason, now, opts)
	if not EggCarry.DROP_REASONS[reason] then return false, "BadReason" end
	if not finite(now) then return false, "BadClock" end
	local egg = EggCarry.carriedBy(registry, key)
	if not egg then return false, "NotCarrying" end
	if type(opts) == "table" and opts.safe == true and not SAFE_DROPS[reason] then return false, "SafeZone" end
	registry.carriers[key] = nil
	egg.state, egg.carrier, egg.uid, egg.lastCarrier, egg.reason = "Dropped", nil, nil, key, reason
	egg.droppedAt, egg.pickableAt, egg.expireAt = now, now + C.PICKUP_DELAY, now + C.DROP_SECONDS
	egg.open = false
	return true, egg
end

-- Whether this player may pick this dropped egg up now. Anyone may, the last carrier included, with no priority.
function EggCarry.canPickup(registry, id, key, now)
	if not validKey(key) then return false, "InvalidPlayer" end
	local egg = EggCarry.get(registry, id)
	if not egg then return false, "NoEgg" end
	if egg.state ~= "Dropped" then return false, "NotDropped" end
	if not finite(now) or now < egg.pickableAt then return false, "TooSoon" end
	if EggCarry.carriedBy(registry, key) then return false, "AlreadyCarrying" end
	return true
end

-- Dropped to Carried. The first valid request wins: the next one finds the egg Carried and gets "NotDropped".
function EggCarry.pickup(registry, id, key, now, uid)
	local ok, reason = EggCarry.canPickup(registry, id, key, now)
	if not ok then return false, reason end
	local egg = registry.eggs[id]
	egg.state, egg.carrier, egg.uid, egg.open = "Carried", key, uid, false
	registry.carriers[key] = id
	return true, egg
end

-- NH6: the carrier delivered the egg (the chest or the incubator banked it). Only its carrier, only while Carried, once:
-- Secured, and it leaves the registry (the state's bank keeps it from here). Returns true and the egg, or false and a
-- reason ("NoEgg", "NotCarried", "NotCarrier").
function EggCarry.secure(registry, id, key)
	local egg = EggCarry.get(registry, id)
	if not egg then return false, "NoEgg" end
	if egg.state ~= "Carried" then return false, "NotCarried" end
	if egg.carrier ~= key then return false, "NotCarrier" end
	registry.carriers[key] = nil
	egg.state, egg.carrier = "Secured", nil
	registry.eggs[id] = nil
	return true, egg
end

-- An adult carried a dropped egg home (FP5c): it leaves the registry.
function EggCarry.recover(registry, id)
	local egg = EggCarry.get(registry, id)
	if not egg or (egg.state ~= "Dropped" and egg.state ~= "Despawning") then return false end
	registry.eggs[id] = nil
	return true, egg
end

-- The clock of dropped eggs. Returns a list of { op, egg }: "open" (pickable from now), "despawn" (abandoned too
-- long: Despawning, fading) and "remove" (gone; it left the registry).
function EggCarry.step(registry, now)
	local actions = {}
	if type(registry) ~= "table" or not finite(now) then return actions end
	for id, egg in pairs(registry.eggs) do
		if egg.state == "Dropped" then
			if now >= egg.expireAt then
				egg.state, egg.despawnAt = "Despawning", now + C.DESPAWN_SECONDS
				table.insert(actions, { op = "despawn", egg = egg })
			elseif not egg.open and now >= egg.pickableAt then
				egg.open = true
				table.insert(actions, { op = "open", egg = egg })
			end
		elseif egg.state == "Despawning" and now >= egg.despawnAt then
			registry.eggs[id] = nil
			table.insert(actions, { op = "remove", egg = egg })
		end
	end
	return actions
end

-- Where a dropped egg rests: the ground a downward ray found (hitY), if it lies between just above the drop height and
-- LAND_DEPTH below it; otherwise the relief's height (fallbackY); never below the fall depth, never in the air.
function EggCarry.landingY(fromY, hitY, fallbackY)
	if finite(fromY) and finite(hitY) and hitY <= fromY + 1 and hitY >= fromY - C.LAND_DEPTH then return hitY end
	if finite(fallbackY) then return fallbackY end
	return finite(fromY) and fromY - 3 or 0
end

-- NH8: whether a spawn's prompt is being held. holders = { [player] = when the hold began }; a hold counts for at most
-- HOLD_GRACE seconds (every hold is 1 s or shorter), so a release that never arrived cannot pin a spawn.
EggCarry.HOLD_GRACE = 3
function EggCarry.holding(holders, now)
	if type(holders) ~= "table" or not finite(now) then return false end
	for _, at in pairs(holders) do
		if finite(at) and at <= now and now - at <= EggCarry.HOLD_GRACE then return true end
	end
	return false
end

-- HB-T7 (verifier finding): the steal hold is measured on the server. hold = { at = when this player's hold began on the
-- server (PromptButtonHoldBegan), ended = when it was released, if it was }; need = this player's effective hold. A
-- trigger counts only after a continuous hold of at least need - allowance seconds (default the tunable HOLD_ALLOWANCE),
-- begun at most need + HOLD_GRACE ago.
local EPSILON = 1e-6
function EggCarry.holdComplete(hold, now, need, allowance)
	if not finite(need) then return false end
	if need <= 0 then return true end
	if type(hold) ~= "table" or not finite(hold.at) or not finite(now) then return false end
	local least = need - (finite(allowance) and allowance or C.HOLD_ALLOWANCE)
	local held = now - hold.at
	if held + EPSILON < least or held > need + EggCarry.HOLD_GRACE then return false end
	if hold.ended ~= nil and not (finite(hold.ended) and hold.ended - hold.at + EPSILON >= least) then return false end
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

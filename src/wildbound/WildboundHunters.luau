-- Fix pass (FP2, user: a Silueta per player): pure bookkeeping for the world script's hunters. One hunter per player,
-- bound to its owner for life: it only ever considers its owner as quarry, so no hunter targets, strikes, marks or
-- notices anyone else. The roster hands out the lowest free slot under a cap (Rules.MAX_HUNTERS, tunable) and each slot
-- a stagger: the patrol corner it starts from and extra seconds between route plans, so eight hunters never ask
-- PathfindingService in the same step. Nothing here reads a service, a clock or an instance.
local Hunters = {}

Hunters.CONSTANTS = table.freeze({
	PLAN_STAGGER = 0.125, -- extra seconds between a slot's route plans, times its corner index (0 to 3)
	PATROL_CORNERS = 4, -- the home diamond has four corners; slots start spread over them
})
local C = Hunters.CONSTANTS

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function Hunters.new()
	return { byOwner = {}, slots = {}, count = 0 }
end

function Hunters.count(roster)
	return type(roster) == "table" and roster.count or 0
end

function Hunters.get(roster, ownerId)
	if type(roster) ~= "table" or not finite(ownerId) then return nil end
	return roster.byOwner[ownerId]
end

-- Binds a hunter to ownerId under the cap `limit`. Returns the record { owner, slot }, or nil and a reason.
function Hunters.add(roster, ownerId, limit)
	if type(roster) ~= "table" then return nil, "BadRoster" end
	if not finite(ownerId) then return nil, "BadOwner" end
	if not finite(limit) or limit < 1 then return nil, "BadLimit" end
	if roster.byOwner[ownerId] then return nil, "Duplicate" end
	if roster.count >= math.floor(limit) then return nil, "Full" end
	local slot = 1
	while roster.slots[slot] do slot += 1 end
	local record = { owner = ownerId, slot = slot }
	roster.slots[slot], roster.byOwner[ownerId] = record, record
	roster.count += 1
	return record
end

-- Unbinds ownerId's hunter and frees its slot. Returns the record, or nil when there was none.
function Hunters.remove(roster, ownerId)
	local record = Hunters.get(roster, ownerId)
	if not record then return nil end
	roster.byOwner[ownerId], roster.slots[record.slot] = nil, nil
	roster.count -= 1
	return record
end

function Hunters.owns(hunter, userId)
	return type(hunter) == "table" and finite(userId) and hunter.owner == userId
end

-- The only candidates a hunter may consider: its owner. candidates = list of { id = userId, ... }.
function Hunters.quarry(hunter, candidates)
	local list = {}
	if type(hunter) ~= "table" or type(candidates) ~= "table" then return list end
	for _, candidate in ipairs(candidates) do
		if type(candidate) == "table" and Hunters.owns(hunter, candidate.id) then table.insert(list, candidate) end
	end
	return list
end

-- What a slot gets so hunters never move in lockstep: a starting patrol corner and a longer gap between route plans.
function Hunters.stagger(slot)
	local index = finite(slot) and slot >= 1 and (math.floor(slot) - 1) % C.PATROL_CORNERS or 0
	return { patrolIndex = index + 1, planDelay = index * C.PLAN_STAGGER }
end

return Hunters

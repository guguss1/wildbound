-- Pure, synchronous session state. Only the server supplies context and IDs.
local State = {}
State.__index = State
local CAPACITY, COLLECTION_LIMIT, DEFEAT_HISTORY = 3, 100, 256

local function validId(value)
	return type(value) == "string" and #value > 0 and #value <= 128
end

local function playerKey(value)
	if validId(value) then return "s:" .. value end
	if type(value) == "number" and value == value and math.abs(value) < math.huge
		and value % 1 == 0 then return "n:" .. tostring(value) end
	return nil
end

local function profile(self, key)
	local normalized = playerKey(key)
	return normalized and self.players[normalized] or nil
end

local function context(alive, distance, limit)
	return alive == true and type(distance) == "number" and distance == distance
		and distance >= 0 and distance <= limit
end

local function find(entries, uid)
	if not validId(uid) then return nil end
	for index, entry in ipairs(entries) do
		if entry.uid == uid then return index, entry end
	end
	return nil
end

local function copy(entries)
	local detached = {}
	for index, entry in ipairs(entries) do detached[index] = table.clone(entry) end
	return detached
end

local function newUid(self)
	self.nextUid += 1
	return "wb:" .. self.nextUid
end

function State.new()
	return setmetatable({ players = {}, encounters = {}, nextUid = 0 }, State)
end

function State:addPlayer(key)
	local normalized = playerKey(key)
	if not normalized then return false, "InvalidPlayer" end
	if not self.players[normalized] then
		self.players[normalized] = {
			pending = {}, bankedEggs = {}, registered = {}, sealCharges = 0,
			earnedSeal = false, defeats = {}, defeatOrder = {},
		}
	end
	return true
end

function State:removePlayer(key)
	local normalized = playerKey(key)
	if not normalized then return false, "InvalidPlayer" end
	self.players[normalized] = nil
	return true
end

function State:registerEncounter(id, kind)
	if not validId(id) or (kind ~= "Creature" and kind ~= "Egg") then
		return false, "InvalidEncounter"
	end
	if self.encounters[id] then return false, "AlreadyRegistered" end
	self.encounters[id] = { kind = kind, claimed = false }
	return true
end

-- Adapter-only lifecycle: disconnect/remove an expired world slot first.
-- Retired IDs must NEVER be reused; they become unknown, not available loot.
function State:retireEncounter(id)
	if not validId(id) then return false, "InvalidEncounter" end
	self.encounters[id] = nil
	return true
end

function State:pickup(key, id, alive, distance)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	if not validId(id) then return false, "InvalidEncounter" end
	if not context(alive, distance, 10) then return false, "InvalidContext" end
	local encounter = self.encounters[id]
	if not encounter then return false, "InvalidEncounter" end
	if encounter.claimed then return false, "AlreadyClaimed" end
	-- A creature is granted only by a finished capture session (completeCapture), never by a prompt.
	if encounter.kind == "Creature" then return false, "CaptureRequired" end
	if #player.pending >= CAPACITY then return false, "BackpackFull" end
	if #player.pending + #player.bankedEggs + #player.registered >= COLLECTION_LIMIT then
		return false, "CollectionFull"
	end
	local uid = newUid(self)
	-- No yield occurs between availability check, global claim and ownership grant.
	encounter.claimed = true
	table.insert(player.pending, {
		uid = uid, kind = encounter.kind, species = "Lumipol", protected = false,
	})
	return true, uid
end

local TIERS = table.freeze({ Safe = true, Fog = true, Territory = true })

-- Whether a capture could be granted now: bag room, then collection room. Missing players have neither.
function State:captureRoom(key)
	local player = profile(self, key)
	if not player then return false, false end
	local total = #player.pending + #player.bankedEggs + #player.registered
	return #player.pending < CAPACITY, total < COLLECTION_LIMIT
end

-- "Open", "Claimed" or nil for an unknown or retired id. Lets the adapter name the encounter state.
function State:encounterStatus(id)
	if not validId(id) then return nil end
	local encounter = self.encounters[id]
	if not encounter then return nil end
	return encounter.claimed and "Claimed" or "Open"
end

-- The grant for a finished capture. The ring session already proved skill, owner and reservation, and a
-- correct finish can be farther than the 10 stud pickup range, so there is no distance here. It claims
-- and grants in one step with no yield, so the creature has exactly one owner.
function State:completeCapture(key, id, alive, tier)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	if not validId(id) then return false, "InvalidEncounter" end
	local encounter = self.encounters[id]
	if not encounter or encounter.kind ~= "Creature" then return false, "InvalidEncounter" end
	if alive ~= true then return false, "InvalidContext" end
	if encounter.claimed then return false, "AlreadyClaimed" end
	if type(tier) ~= "string" or not TIERS[tier] then return false, "InvalidTier" end
	if #player.pending >= CAPACITY then return false, "BackpackFull" end
	if #player.pending + #player.bankedEggs + #player.registered >= COLLECTION_LIMIT then
		return false, "CollectionFull"
	end
	local uid = newUid(self)
	encounter.claimed = true
	table.insert(player.pending, {
		uid = uid, kind = "Creature", species = "Lumipol", protected = false, riskTier = tier,
	})
	return true, uid
end

function State:extract(key, alive, distance)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	if not context(alive, distance, 12) then return false, "InvalidContext" end
	local count = #player.pending
	if count == 0 then return false, "Empty" end
	for _, entry in ipairs(player.pending) do
		if entry.kind == "Egg" then
			table.insert(player.bankedEggs, { uid = entry.uid, kind = "Egg", species = entry.species })
		else
			table.insert(player.registered, { uid = entry.uid, species = entry.species })
		end
	end
	player.pending = {}
	if not player.earnedSeal then
		player.earnedSeal = true
		player.sealCharges = 1
	end
	return true, count
end

function State:hatch(key, uid, alive, distance)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	if not context(alive, distance, 12) then return false, "InvalidContext" end
	local index, egg = find(player.bankedEggs, uid)
	if not index then return false, "NotOwnedEgg" end
	local petUid = newUid(self)
	table.remove(player.bankedEggs, index)
	table.insert(player.registered, { uid = petUid, species = egg.species })
	return true, petUid
end

function State:equip(key, uid, alive)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	if alive ~= true then return false, "InvalidContext" end
	if not find(player.registered, uid) then return false, "NotOwnedPet" end
	player.equippedUid = uid
	return true, uid
end

function State:protect(key, uid, alive)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	if alive ~= true then return false, "InvalidContext" end
	local _, entry = find(player.pending, uid)
	if not entry then return false, "NotOwnedPending" end
	if entry.protected then return true, uid end
	if player.sealCharges < 1 then return false, "NoSeal" end
	for _, pending in ipairs(player.pending) do
		if pending.protected then return false, "AlreadyProtected" end
	end
	entry.protected = true
	return true, uid
end

function State:defeat(key, operationId)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	if not validId(operationId) then return false, "InvalidOperation" end
	if player.defeats[operationId] then return true, 0 end
	player.defeats[operationId] = true
	table.insert(player.defeatOrder, operationId)
	if #player.defeatOrder > DEFEAT_HISTORY then
		player.defeats[table.remove(player.defeatOrder, 1)] = nil
	end
	local survivor, before = nil, #player.pending
	for _, entry in ipairs(player.pending) do
		if entry.protected and player.sealCharges > 0 then survivor = entry; break end
	end
	player.pending = {}
	if survivor then
		survivor.protected = false
		player.sealCharges -= 1
		table.insert(player.pending, survivor)
	end
	return true, before - #player.pending
end

function State:isClaimed(id)
	if not validId(id) then return false end
	local encounter = self.encounters[id]
	return encounter ~= nil and encounter.claimed == true
end

function State:snapshot(key)
	local player = profile(self, key)
	if not player then return nil end
	return {
		sessionOnly = true, capacity = CAPACITY, collectionLimit = COLLECTION_LIMIT,
		pending = copy(player.pending), bankedEggs = copy(player.bankedEggs),
		registered = copy(player.registered), equippedUid = player.equippedUid,
		sealCharges = player.sealCharges,
	}
end

return State

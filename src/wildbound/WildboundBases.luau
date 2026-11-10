-- Nest Heist hub (docs/maps/wildbound-hub.md): pure rules for the hub's personal bases, its spawn pads and the forest
-- props its trails replace. No services, no instances, no clock: numbers and tables in, answers out. The hub script and
-- the stations module apply them on the server.
local Bases = {}

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- HF-T3 (HB7): the hub plan's NW and SW forest trails run where these two forest edge trees stand
-- (hub-bases-v1.json, removed_forest_props); the hub script removes them from the forest map at start.
Bases.REMOVED_FOREST_PROPS = table.freeze({ "FK_Evergreen_095", "FK_Evergreen_101" })

-- HF-T3 (HB6): which of the hub's spawn pads (SpawnIndex 1..count) a player starts on: the base slot's, wrapping, so
-- two players of neighbouring slots never share a pad while there are pads enough; pad 1 without a slot. nil: no pad.
function Bases.spawnIndex(slot, count)
	if not finite(count) or count < 1 then return nil end
	count = math.floor(count)
	if not finite(slot) or slot < 1 then return 1 end
	return (math.floor(slot) - 1) % count + 1
end

-- HB-T2: base slots. Each player gets the lowest free slot when they join and keeps it while present (a respawn or a
-- repeated join keeps it); it is released when they leave. A player beyond SLOTS gets no base and uses the camp.
Bases.SLOTS = 8
local function validUser(userId)
	return finite(userId) and userId == math.floor(userId) and userId ~= 0
end
function Bases.new(count)
	local slots = finite(count) and math.max(1, math.floor(count)) or Bases.SLOTS
	return { count = slots, owners = {}, byUser = {} }
end
function Bases.assign(registry, userId)
	if type(registry) ~= "table" or not validUser(userId) then return nil end
	local held = registry.byUser[userId]
	if held then return held end
	for slot = 1, registry.count do
		if registry.owners[slot] == nil then
			registry.owners[slot], registry.byUser[userId] = userId, slot
			return slot
		end
	end
	return nil
end
function Bases.release(registry, userId)
	if type(registry) ~= "table" or not validUser(userId) then return nil end
	local slot = registry.byUser[userId]
	if not slot then return nil end
	registry.byUser[userId], registry.owners[slot] = nil, nil
	return slot
end
function Bases.slotOf(registry, userId)
	if type(registry) ~= "table" or not validUser(userId) then return nil end
	return registry.byUser[userId]
end
function Bases.ownerOf(registry, slot)
	if type(registry) ~= "table" then return nil end
	return registry.owners[slot]
end
-- The name sign: "Base libre" while nobody owns it (decision HB4), "Base de <name>" with the owner's display name.
function Bases.signText(Text, name)
	if type(name) ~= "string" or name == "" then return Text.HUB.freeSign end
	return Text.HUB.ownedSign:format(name)
end

-- HB-T3: a station answers only its base's owner, measured by the server within the station's Range plus a small
-- latency allowance. A free base (owner 0) is nobody's, so it refuses everyone.
Bases.ALLOWANCE = 2
function Bases.mayUse(ownerUserId, userId, distance, range)
	if not validUser(userId) or ownerUserId ~= userId then return false, "NotYourBase" end
	if not finite(distance) or distance < 0 or not finite(range) or distance > range + Bases.ALLOWANCE then
		return false, "FarAway"
	end
	return true
end

-- HB-T5: which registered Lumipols stand on the base's collection display: the companion first, then the others in
-- registration order, at most `count` (the builder's three slots). Entries without an id or a species are skipped.
function Bases.displayPicks(snapshot, count)
	local picks = {}
	if type(snapshot) ~= "table" or type(snapshot.registered) ~= "table" or not finite(count) then return picks end
	local limit, valid = math.max(0, math.floor(count)), {}
	for _, entry in ipairs(snapshot.registered) do
		if type(entry) == "table" and type(entry.uid) == "string" and entry.uid ~= "" and type(entry.species) == "string" then
			table.insert(valid, entry)
		end
	end
	for _, entry in ipairs(valid) do
		if entry.uid == snapshot.equippedUid then
			table.insert(picks, entry)
			break
		end
	end
	for _, entry in ipairs(valid) do
		if #picks >= limit then break end
		if entry.uid ~= snapshot.equippedUid then table.insert(picks, entry) end
	end
	while #picks > limit do table.remove(picks) end
	return picks
end

return Bases

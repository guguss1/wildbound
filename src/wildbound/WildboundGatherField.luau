-- Pure rules for the world gather field (M5.3, wave W7 part 2): how many nodes a zone keeps, when a freed
-- place refills, which night-only nodes wilt, how a node looks and whether a hold was kept still. No
-- services, clock or randomness of its own: the caller passes the tuning copy, the spawn rules, the time
-- and a roll function. docs/mechanics/wildbound-economy-p0.md owns every number.
local Field = {}
Field.__index = Field

Field.ZONES = table.freeze({ "outside", "fog", "territory" })
-- Studs a player may drift while a hold runs and still count as standing still (ECO-25). A hypothesis.
Field.MOVE_TOLERANCE = 2.5

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- Seconds of hold for a slot: by band, with the heart band longest.
function Field.holdFor(config, slot)
	if type(slot) ~= "table" then return nil end
	return config.gather.holdSeconds[slot.heart == true and "heart" or slot.zone]
end

-- True when the player moved too far from where the hold began, or when either position is unusable.
function Field.holdBroken(startX, startZ, x, z, tolerance)
	tolerance = finite(tolerance) and tolerance or Field.MOVE_TOLERANCE
	if not (finite(startX) and finite(startZ) and finite(x) and finite(z)) then return true end
	return (x - startX) ^ 2 + (z - startZ) ^ 2 > tolerance ^ 2
end

-- Each material has its own silhouette, so shape and size say what it is before colour does. All low
-- and small: a node is walked past or over, never around. Sizes are studs, colours are 0 to 255.
local LOOKS = table.freeze({
	fogbark = table.freeze({ name = "Fogbark", shape = "Block", size = table.freeze({ 2.6, 1, 1.1 }),
		color = table.freeze({ 139, 98, 62 }), glow = false }),
	glowmoss = table.freeze({ name = "Glowmoss", shape = "Ball", size = table.freeze({ 2.2, 2.2, 2.2 }),
		color = table.freeze({ 130, 214, 150 }), glow = true }),
	nightbloom = table.freeze({ name = "Nightbloom", shape = "Diamond", size = table.freeze({ 1.5, 2.6, 1.5 }),
		color = table.freeze({ 170, 130, 240 }), glow = true }),
})

function Field.look(material, heart)
	local base = type(material) == "string" and LOOKS[material] or nil
	if not base then return nil end
	return { name = base.name, shape = base.shape, size = table.clone(base.size), color = table.clone(base.color),
		glow = base.glow, ring = heart == true, ringDiameter = heart == true and 7 or 0 }
end

function Field.new(config, spawn)
	assert(type(config) == "table" and type(spawn) == "table", "Field.new needs the tuning and the spawn rules")
	return setmetatable({ config = config, spawn = spawn, nodes = {}, bySlot = {}, cooling = {} }, Field)
end

function Field:count(zone)
	local total = 0
	for _, node in pairs(self.nodes) do
		if node.zone == zone then total += 1 end
	end
	return total
end

local function coolingIn(self, zone)
	local total = 0
	for _, entry in ipairs(self.cooling) do
		if entry.zone == zone then total += 1 end
	end
	return total
end

-- The slots to fill now, as ids, for this many players. `rand` returns a roll in [0, 1). A zone keeps its
-- tuned number of nodes counting those cooling down, so a freed place refills only after the respawn time.
-- Nothing is reserved: the caller tracks each node it really creates.
function Field:plan(players, now, rand)
	local pending = {}
	for _, entry in ipairs(self.cooling) do
		if entry.readyAt > now then table.insert(pending, entry) end
	end
	self.cooling = pending
	local taken, picks = {}, {}
	for slotId in pairs(self.bySlot) do taken[slotId] = true end
	for _, zone in ipairs(Field.ZONES) do
		local missing = self.spawn.activeCount(self.config, zone, players) - self:count(zone) - coolingIn(self, zone)
		for _ = 1, missing do
			local slotId = self.spawn.pickSlot(self.config, zone, taken, rand())
			if not slotId then break end
			taken[slotId] = true
			table.insert(picks, slotId)
		end
	end
	return picks
end

-- node = { id, slotId, zone, material }. One node per id and per slot.
function Field:track(node)
	if type(node) ~= "table" or type(node.id) ~= "string" or type(node.slotId) ~= "string"
		or type(node.zone) ~= "string" then return false end
	if self.nodes[node.id] or self.bySlot[node.slotId] then return false end
	self.nodes[node.id] = { id = node.id, slotId = node.slotId, zone = node.zone, material = node.material }
	self.bySlot[node.slotId] = node.id
	return true
end

-- A claimed or wilted node leaves, once. Its zone refills after the respawn time. Nil for an unknown id.
function Field:release(id, now, reason)
	local node = type(id) == "string" and self.nodes[id] or nil
	if not node then return nil end
	self.nodes[id] = nil
	self.bySlot[node.slotId] = nil
	table.insert(self.cooling, { zone = node.zone, readyAt = now + self.config.gather.respawnSeconds, reason = reason })
	return node
end

-- Ids of the night-only nodes that must go now: all of them, as soon as the phase is not Night.
function Field:wilting(phase)
	local ids = {}
	if phase == "Night" then return ids end
	for id, node in pairs(self.nodes) do
		local spec = self.config.materials[node.material]
		if spec and spec.nightOnly then table.insert(ids, id) end
	end
	table.sort(ids)
	return ids
end

return Field

-- Delivery B (B3 to B5): pure rules for the camp. The refuge's deposit animation and presentation card, the display
-- spots and their idle motion, and the equipped companion's follow offset. Time is passed in; nothing here reads a
-- clock, a service or an instance, so the server and every client draw the same thing. Numbers are hypotheses.
local Refuge = {}

Refuge.CONFIG = table.freeze({
	-- The captured creature leaves the capsule and arcs into the refuge's nest, shrinking as it settles.
	DEPOSIT_SECONDS = 1.2,
	DEPOSIT_LIFT = 3,
	DEPOSIT_END_SCALE = 0.4,
	-- Pedestals in the camp display. One per player; a fifth player waits for a free one.
	DISPLAY_SPOTS = 4,
	IDLE_BOB = 0.25,
	IDLE_SPEED = 1.6,
	IDLE_TURN = 0.35,
	-- The companion hovers beside and a little behind the player, in the root's own space (studs).
	HOVER_SIDE = 3,
	HOVER_HEIGHT = 1.6,
	HOVER_BACK = 1.5,
	HOVER_BOB = 0.3,
	HOVER_SPEED = 2,
	-- A pulse makes it hop.
	PULSE_HOP = 1.2,
	PULSE_SECONDS = 0.6,
})
local K = Refuge.CONFIG

-- Nest Heist Phase 3 (NS4): the companion's PointLight. Live values for the dev tuning (schema system "Companion");
-- the server applies them to every companion on each refresh. No override, no change.
Refuge.LIGHT = table.freeze({ LIGHT_BRIGHTNESS = 1.2, LIGHT_RANGE = 12 })
Refuge.live = {}
function Refuge.tunable()
	return table.clone(Refuge.LIGHT)
end
function Refuge.tune(overrides)
	table.clear(Refuge.live)
	for key, value in pairs(Refuge.LIGHT) do Refuge.live[key] = value end
	if type(overrides) ~= "table" then return end
	for key in pairs(Refuge.LIGHT) do
		local value = overrides[key]
		if type(value) == "number" and value == value and value > -math.huge and value < math.huge then
			Refuge.live[key] = math.max(0, value)
		end
	end
end
Refuge.tune(nil)

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function validId(value)
	return type(value) == "string" and #value > 0 and #value <= 128
end

-- t seconds into the deposit: alpha (eased 0 to 1) along the path, lift above it, scale of the creature.
function Refuge.depositPose(t)
	if not finite(t) or t <= 0 then return { alpha = 0, lift = 0, scale = 1, done = false } end
	local share = math.min(t / K.DEPOSIT_SECONDS, 1)
	local alpha = share * share * (3 - 2 * share)
	return { alpha = alpha, lift = 4 * K.DEPOSIT_LIFT * share * (1 - share),
		scale = 1 - (1 - K.DEPOSIT_END_SCALE) * alpha, done = share >= 1 }
end

-- The presentation card for a registration receipt (State:register), or nil for a repeat or a bad receipt.
function Refuge.card(receipt, Text)
	if type(receipt) ~= "table" or receipt.repeated == true or not validId(receipt.uid)
		or type(receipt.species) ~= "string" or type(Text) ~= "table" or type(Text.CARD) ~= "table" then
		return nil
	end
	local words = Text.CARD
	local ember = finite(receipt.ember) and math.floor(receipt.ember) or 0
	-- K2: the first-steal bonus gets its own line; the Ember line keeps the creature's own pay.
	local bonus = finite(receipt.firstBonus) and math.floor(receipt.firstBonus) or 0
	if bonus > 0 and bonus <= ember then ember -= bonus else bonus = 0 end
	local title = words.titleAgain
	if receipt.isNew == true then
		title = receipt.firstEver == false and words.newSpecies or words.title
	end
	local islandNames = type(Text.ISLAND) == "table" and Text.ISLAND.names or {}
	local tease = nil
	if receipt.isNew == true and type(receipt.nextIsland) == "string" and type(receipt.nextSpecies) == "string"
		and islandNames[receipt.nextIsland] and words.next then
		tease = words.next:format(islandNames[receipt.nextIsland], words.species[receipt.nextSpecies] or receipt.nextSpecies)
	end
	return {
		uid = receipt.uid,
		title = title,
		name = words.species[receipt.species] or receipt.species,
		blurb = words.blurb[receipt.species],
		entry = receipt.isNew == true and words.entry or nil,
		ember = ember > 0 and words.ember:format(ember) or nil,
		bonus = bonus > 0 and words.firstBonus and words.firstBonus:format(bonus) or nil,
		next = tease,
		equip = words.equip,
		close = words.close,
	}
end

-- K2: the next island, in island order, whose species the player has not registered. islands = list of
-- { id, species }; discovered = { [species] = true }. nil when every species is found.
function Refuge.nextIsland(islands, discovered)
	if type(islands) ~= "table" then return nil end
	discovered = type(discovered) == "table" and discovered or {}
	for _, island in ipairs(islands) do
		if type(island) == "table" and type(island.species) == "string" and discovered[island.species] ~= true then
			return island
		end
	end
	return nil
end

-- One display spot per owner key, the lowest free one, kept until released. nil when every spot is taken.
function Refuge.assignSpot(assigned, key, count)
	if type(assigned) ~= "table" or key == nil or not finite(count) or count < 1 then return nil end
	if assigned[key] then return assigned[key] end
	local taken = {}
	for _, index in pairs(assigned) do taken[index] = true end
	for index = 1, math.floor(count) do
		if not taken[index] then
			assigned[key] = index
			return index
		end
	end
	return nil
end

function Refuge.releaseSpot(assigned, key)
	if type(assigned) == "table" and key ~= nil then assigned[key] = nil end
end

-- Which registered Lumipol a player's display spot shows: the equipped one, else the first registered one.
function Refuge.displayChoice(snapshot)
	if type(snapshot) ~= "table" or type(snapshot.registered) ~= "table" then return nil end
	local first
	for _, entry in ipairs(snapshot.registered) do
		-- K2: any registered species can stand on the display (it was Lumipol only).
		if type(entry) == "table" and validId(entry.uid) and type(entry.species) == "string" then
			if entry.uid == snapshot.equippedUid then return entry end
			first = first or entry
		end
	end
	return first
end

-- The display's idle motion: a small bob and a slow look around. seed offsets each spot so they never move as one.
function Refuge.idlePose(t, seed)
	if not finite(t) then return { y = 0, yaw = 0 } end
	local phase = finite(seed) and seed * 1.7 or 0
	return { y = math.sin(t * K.IDLE_SPEED + phase) * K.IDLE_BOB,
		yaw = math.sin(t * K.IDLE_SPEED * 0.37 + phase) * K.IDLE_TURN }
end

-- The companion's follow point in the player's root space (x right, y up, z back), with a hop for
-- PULSE_SECONDS after a pulse. pulseAge is the seconds since the last pulse, or nil.
function Refuge.companionOffset(t, pulseAge)
	local time = finite(t) and t or 0
	local y = K.HOVER_HEIGHT + math.sin(time * K.HOVER_SPEED) * K.HOVER_BOB
	if finite(pulseAge) and pulseAge >= 0 and pulseAge < K.PULSE_SECONDS then
		y += math.sin(pulseAge / K.PULSE_SECONDS * math.pi) * K.PULSE_HOP
	end
	return { x = K.HOVER_SIDE, y = y, z = K.HOVER_BACK }
end

return Refuge

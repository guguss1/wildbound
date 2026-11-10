-- Random world (plan Part 3, RW2): the spawn clock, pure and server only. Eggs and crias appear on the spawn graph
-- (WildboundSpawnGraph) outside the island nests: each lives LIFETIME seconds and then moves to another point of the
-- same tier. The tier is the distance band to La Silueta's home (Comun beyond 120, Rara 80 to 120, Epica 45 to 80,
-- Legendaria under 45); rarer tiers keep fewer spawns at once and wait longer after a claim. The species and the
-- reward tier follow the spawn tier. The clock and the rolls (a Random) are passed in; nothing here reads a service.
local SpawnClock = {}

local function freeze(value)
	if type(value) == "table" and not table.isfrozen(value) then
		for _, child in pairs(value) do freeze(child) end
		table.freeze(value)
	end
	return value
end

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

SpawnClock.TIERS = freeze({ "Comun", "Rara", "Epica", "Legendaria" })
-- The reward tier (the economy's Ember rows) and the capture tier (noise, capture windows) of each spawn tier. A wild
-- spawn is never "Safe" (first capture only); the island nests keep their own tiers.
SpawnClock.REWARD = freeze({ Comun = "Fog", Rara = "FogFar", Epica = "Territory", Legendaria = "Heart" })
SpawnClock.SLOT_TIER = freeze({ Comun = "Fog", Rara = "Fog", Epica = "Territory", Legendaria = "Territory" })

-- LIFETIME: seconds a spawn stays before it moves. RESPAWN_*: seconds a tier waits after a claim. MAX_*: spawns of a
-- tier at once. EGG_SHARE: the chance a ground spawn is an egg (a bough always holds an egg). SPACING: studs kept
-- between two spawns.
SpawnClock.CONSTANTS = freeze({
	LIFETIME = 300,
	RESPAWN_COMUN = 90, RESPAWN_RARA = 150, RESPAWN_EPICA = 240, RESPAWN_LEGENDARIA = 360,
	MAX_COMUN = 4, MAX_RARA = 3, MAX_EPICA = 2, MAX_LEGENDARIA = 1,
	EGG_SHARE = 0.4,
	SPACING = 12,
})

local TUNABLE = { "LIFETIME", "RESPAWN_COMUN", "RESPAWN_RARA", "RESPAWN_EPICA", "RESPAWN_LEGENDARIA", "MAX_COMUN",
	"MAX_RARA", "MAX_EPICA", "MAX_LEGENDARIA", "EGG_SHARE" }
SpawnClock.live = {}

function SpawnClock.tunable()
	local defaults = {}
	for _, key in ipairs(TUNABLE) do defaults[key] = SpawnClock.CONSTANTS[key] end
	return defaults
end

-- Dev tuning: CONSTANTS stays the default; the bridge overrides at runtime. No override, no change.
function SpawnClock.tune(overrides)
	table.clear(SpawnClock.live)
	for key, value in pairs(SpawnClock.CONSTANTS) do SpawnClock.live[key] = value end
	if type(overrides) ~= "table" then return end
	for _, key in ipairs(TUNABLE) do
		local value = overrides[key]
		if finite(value) and value >= 0 then SpawnClock.live[key] = value end
	end
end
SpawnClock.tune(nil)

local function upper(tier)
	return string.upper(tier)
end
local function maxOf(tier)
	return math.max(0, math.floor((SpawnClock.live["MAX_" .. upper(tier)] or 0) + 0.5))
end
local function respawnOf(tier)
	return SpawnClock.live["RESPAWN_" .. upper(tier)] or 0
end

function SpawnClock.tierOf(distance)
	if not finite(distance) or distance < 0 then return nil end
	if distance < 45 then return "Legendaria" end
	if distance < 80 then return "Epica" end
	if distance <= 120 then return "Rara" end
	return "Comun"
end

-- graph: WildboundSpawnGraph. species: WildboundSpecies (its byRarity); without it a spawn's species is nil and the
-- server falls back on its own default.
function SpawnClock.new(graph, species)
	local pools = {}
	for _, tier in ipairs(SpawnClock.TIERS) do pools[tier] = {} end
	if type(graph) == "table" and type(graph.points) == "table" then
		for _, point in ipairs(graph.points) do
			if type(point) == "table" and not point.guaranteed and pools[point.tier] then table.insert(pools[point.tier], point) end
		end
	end
	local nextAt = {}
	for _, tier in ipairs(SpawnClock.TIERS) do nextAt[tier] = -math.huge end
	return { pools = pools, active = {}, nextAt = nextAt, serial = 0, species = species, weights = {} }
end

-- weights: { [point kind] = multiplier } for the biome variant (RW6); nil restores even weights.
function SpawnClock.setWeights(state, weights)
	state.weights = type(weights) == "table" and weights or {}
end

local function roll(rand)
	if type(rand) == "table" or typeof(rand) == "Random" then
		local ok, value = pcall(function() return rand:NextNumber() end)
		if ok and finite(value) then return math.clamp(value, 0, 0.999999) end
	end
	return 0
end

local function busy(state, point, ignore)
	for _, spawn in pairs(state.active) do
		if spawn.point == point then return true end
		local dx, dz = spawn.point.x - point.x, spawn.point.z - point.z
		if math.sqrt(dx * dx + dz * dz) < SpawnClock.live.SPACING then return true end
	end
	return ignore ~= nil and ignore[point.id] == true
end

local function choose(state, list, rand, ignore, near)
	local total, candidates = 0, {}
	for _, point in ipairs(list) do
		local ok = not busy(state, point, ignore)
		if ok and near then
			local dx, dz = point.x - near.x, point.z - near.z
			ok = math.sqrt(dx * dx + dz * dz) <= near.radius
		end
		if ok then
			local weight = state.weights[point.kind]
			weight = finite(weight) and math.max(0, weight) or 1
			if weight > 0 then
				total += weight
				table.insert(candidates, { point = point, weight = weight })
			end
		end
	end
	if total <= 0 then return nil end
	local target = roll(rand) * total
	for _, item in ipairs(candidates) do
		target -= item.weight
		if target < 0 then return item.point end
	end
	return candidates[#candidates].point
end

local function speciesFor(state, tier, rand)
	local Species = state.species
	local names = type(Species) == "table" and type(Species.byRarity) == "function" and Species.byRarity(tier) or nil
	if type(names) ~= "table" or #names == 0 then return nil end
	return names[math.floor(roll(rand) * #names) + 1]
end

local function make(state, now, rand, tier, point, kind, lifetime, special)
	state.serial += 1
	if point.kind == "canopy" then kind = "Egg" end
	if kind ~= "Egg" and kind ~= "Creature" then
		kind = roll(rand) < SpawnClock.live.EGG_SHARE and "Egg" or "Creature"
	end
	local spawn = {
		id = "W" .. state.serial, point = point, tier = tier, kind = kind, species = speciesFor(state, tier, rand),
		rewardTier = SpawnClock.REWARD[tier], slotTier = SpawnClock.SLOT_TIER[tier], bornAt = now,
		expiresAt = now + (finite(lifetime) and lifetime or SpawnClock.live.LIFETIME), special = special == true,
	}
	state.active[spawn.id] = spawn
	return spawn
end

local function countOf(state, tier)
	local n = 0
	for _, spawn in pairs(state.active) do
		if spawn.tier == tier and not spawn.special then n += 1 end
	end
	return n
end

local function fill(state, now, rand, actions, ignore)
	for _, tier in ipairs(SpawnClock.TIERS) do
		if now >= state.nextAt[tier] then
			while countOf(state, tier) < maxOf(tier) do
				local point = choose(state, state.pools[tier], rand, ignore)
				if not point then break end
				table.insert(actions, { op = "spawn", spawn = make(state, now, rand, tier, point) })
			end
		end
	end
end

-- held: { [spawn id] = true } for spawns a player is capturing; they never expire while held.
-- Returns a list of { op = "expire", spawn, reason } and { op = "spawn", spawn } in the order to apply.
function SpawnClock.step(state, now, rand, held)
	local actions = {}
	if type(state) ~= "table" or not finite(now) then return actions end
	held = type(held) == "table" and held or {}
	local ignore = {}
	local ids = {}
	for id in pairs(state.active) do table.insert(ids, id) end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local spawn = state.active[id]
		-- A tuned shorter LIFETIME reaches the spawns already out; a special spawn keeps its own life.
		local ends = spawn.special and spawn.expiresAt or math.min(spawn.expiresAt, spawn.bornAt + SpawnClock.live.LIFETIME)
		if now >= ends and not held[id] then
			state.active[id] = nil
			ignore[spawn.point.id] = true
			table.insert(actions, { op = "expire", spawn = spawn, reason = "Lifetime" })
		end
	end
	fill(state, now, rand, actions, ignore)
	return actions
end

-- A player took the spawn: it leaves, and its tier waits RESPAWN before the next one. Returns false when unknown.
function SpawnClock.claim(state, id, now)
	local spawn = type(state) == "table" and state.active[id] or nil
	if not spawn then return false end
	state.active[id] = nil
	if not spawn.special and finite(now) then
		state.nextAt[spawn.tier] = math.max(state.nextAt[spawn.tier], now + respawnOf(spawn.tier))
	end
	return true
end

-- Wave start (RW3): every random spawn leaves (a held one stays) and the tiers refill at once on new points.
function SpawnClock.reroll(state, now, rand, held)
	local actions = {}
	if type(state) ~= "table" or not finite(now) then return actions end
	held = type(held) == "table" and held or {}
	local ignore, ids = {}, {}
	for id, spawn in pairs(state.active) do
		if not spawn.special and not held[id] then table.insert(ids, id) end
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local spawn = state.active[id]
		state.active[id] = nil
		ignore[spawn.point.id] = true
		table.insert(actions, { op = "expire", spawn = spawn, reason = "Reroll" })
	end
	for _, tier in ipairs(SpawnClock.TIERS) do state.nextAt[tier] = math.min(state.nextAt[tier], now) end
	fill(state, now, rand, actions, ignore)
	return actions
end

-- One spawn on demand: options = { tier, kind, x, z, radius, lifetime, special }. The first wave's guaranteed egg near
-- camp and the biome event use it. Returns the spawn or nil when no free point lies within the radius.
function SpawnClock.force(state, now, rand, options)
	if type(state) ~= "table" or not finite(now) or type(options) ~= "table" then return nil end
	local tier = options.tier
	if not state.pools[tier] then return nil end
	local near = finite(options.x) and finite(options.z) and finite(options.radius)
		and { x = options.x, z = options.z, radius = options.radius } or nil
	local point = choose(state, state.pools[tier], rand, nil, near)
	if not point then return nil end
	return make(state, now, rand, tier, point, options.kind, options.lifetime, options.special)
end

-- The spawn by id, or nil.
function SpawnClock.get(state, id)
	return type(state) == "table" and state.active[id] or nil
end

return SpawnClock

-- The one server spawn pipeline for gather nodes (M5.4, wave W7). Pure: the caller passes the tuning
-- copy and a seeded generator (a Roblox Random), so a fixed seed reproduces every node in a test.
-- Filter first by biome, zone, phase, weather and event, then normalize: p = weight / sum(weights).
-- One table only, never a multiplier stacked on top (docs/mechanics/wildbound-economy-p0.md, Spawn weights).
-- P0 has one biome, no weather and no events. Their only known values are the identity ones below; a
-- future weather or event table must replace the phase table, not multiply it. Unknown values are refused.
local Spawn = {}

Spawn.BIOMES = table.freeze({ forest = true })
Spawn.WEATHERS = table.freeze({ Clear = true })
Spawn.EVENTS = table.freeze({ None = true })

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- The weights that apply, as a list sorted by material. Night-only materials need night rewards on.
-- request = { zone, phase, biome = "forest", weather = "Clear", event = "None", nightRewards = false }
function Spawn.weights(config, request)
	if type(request) ~= "table" then return nil, "InvalidRequest" end
	if not Spawn.BIOMES[request.biome or "forest"] then return nil, "UnknownBiome" end
	if not Spawn.WEATHERS[request.weather or "Clear"] then return nil, "UnknownWeather" end
	if not Spawn.EVENTS[request.event or "None"] then return nil, "UnknownEvent" end
	local zone = type(request.zone) == "string" and config.spawnWeights[request.zone] or nil
	if not zone then return nil, "UnknownZone" end
	local table_ = type(request.phase) == "string" and zone[request.phase] or nil
	if not table_ then return nil, "UnknownPhase" end
	local list = {}
	for material, weight in pairs(table_) do
		local spec = config.materials[material]
		if spec and (not spec.nightOnly or request.nightRewards == true) then
			table.insert(list, { id = material, weight = weight })
		end
	end
	table.sort(list, function(a, b) return a.id < b.id end)
	return list
end

-- Shares that sum to one, dropping zero weights. Nil for a negative, non-finite or empty table.
function Spawn.normalize(list)
	if type(list) ~= "table" then return nil end
	local total = 0
	for _, item in ipairs(list) do
		if not finite(item.weight) or item.weight < 0 then return nil end
		total += item.weight
	end
	if total <= 0 then return nil end
	local out = {}
	for _, item in ipairs(list) do
		if item.weight > 0 then table.insert(out, { id = item.id, weight = item.weight, p = item.weight / total }) end
	end
	table.sort(out, function(a, b) return a.id < b.id end)
	return out
end

-- The outcome whose cumulative share first exceeds the roll. A roll outside [0, 1) is clamped.
function Spawn.pick(list, roll)
	if type(list) ~= "table" or #list == 0 then return nil end
	if not finite(roll) then roll = 0 end
	roll = math.clamp(roll, 0, 1)
	local cumulative = 0
	for _, item in ipairs(list) do
		cumulative += item.p
		if roll < cumulative then return item.id end
	end
	return list[#list].id
end

-- A uniform integer over the tuned inclusive range, plus the heart bonus once. Nil without a yield row.
function Spawn.yield(config, zone, material, heart, roll)
	local range = config.yields[zone] and config.yields[zone][material]
	if not range then return nil end
	if not finite(roll) then roll = 0 end
	local span = range[2] - range[1] + 1
	local offset = math.min(span - 1, math.floor(math.clamp(roll, 0, 1) * span))
	return range[1] + offset + (heart == true and config.gather.heartYieldBonus or 0)
end

-- One node for a slot: its material, then its quantity, each from one draw of the given generator.
function Spawn.rollNode(config, slot, phase, rng, options)
	if type(slot) ~= "table" or typeof(rng) ~= "Random" then return nil end
	options = type(options) == "table" and options or {}
	local list = Spawn.normalize(Spawn.weights(config, { zone = slot.zone, phase = phase,
		nightRewards = options.nightRewards, weather = options.weather, event = options.event }))
	if not list then return nil end
	local material = Spawn.pick(list, rng:NextNumber())
	local quantity = Spawn.yield(config, slot.zone, material, slot.heart, rng:NextNumber())
	if not quantity then return nil end
	return { material = material, quantity = quantity }
end

-- Active nodes per zone for a player count (D4).
function Spawn.activeCount(config, zone, players)
	local best
	for _, row in ipairs(config.gather.activeByPlayers) do
		if finite(players) and row.minPlayers <= players and (not best or row.minPlayers > best.minPlayers) then best = row end
	end
	best = best or config.gather.activeByPlayers[1]
	return best[zone] or 0
end

function Spawn.slot(config, id)
	for _, slot in ipairs(config.gather.slots) do
		if slot.id == id then return slot end
	end
	return nil
end

-- A free slot of the zone, chosen uniformly by the roll. Nil when every slot of the zone is taken.
function Spawn.pickSlot(config, zone, occupied, roll)
	local free = {}
	for _, slot in ipairs(config.gather.slots) do
		if slot.zone == zone and not (type(occupied) == "table" and occupied[slot.id]) then table.insert(free, slot.id) end
	end
	if #free == 0 then return nil end
	if not finite(roll) then roll = 0 end
	return free[math.min(#free, math.floor(math.clamp(roll, 0, 1) * #free) + 1)]
end

return Spawn

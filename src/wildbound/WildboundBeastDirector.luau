-- Nest Heist phase 4a (NB2): the one beast director (server only, pure). The beast script calls Director.tick for each
-- player every Config.DIRECTOR.TICK_SECONDS; nothing else rolls for beasts (no second scheduler, no per-beast RNG).
-- Each roll is independent: pEff = clamp(pBase * product(multipliers), 0, MAX_CHANCE), the product capped at
-- MAX_MULTIPLIER. A won roll becomes an encounter only through Director.reserve, which checks and books the threat
-- budget in one call with no yield, so two wins in one tick can never overspend; a refused win is logged and dropped
-- (no queue). Director.release gives the points back exactly once and starts the global and species cooldowns.
-- La Silueta stays outside the budget (she is per player and always present), but no beast starts while that player's
-- Silueta hunts or telegraphs (ctx.siluetaActive). The random source is injected: production passes the server's
-- Random, tests pass a seed or a fixed sequence.
local Config = require((script:FindFirstAncestorOfClass("DataModel") :: any):GetService("ReplicatedStorage")
	:WaitForChild("WildboundBeastConfig"))
local Director = {}

local D = Config.DIRECTOR
local LOG_SIZE = 64

local function finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- The product of the multipliers whose condition is really true, capped at MAX_MULTIPLIER.
function Director.multiplier(ctx)
	local product = 1
	if type(ctx) ~= "table" then return product end
	for key, value in pairs(D.MULTIPLIERS) do
		if ctx[key] == true then product *= value end
	end
	return math.min(product, D.MAX_MULTIPLIER)
end

-- The effective chance of one roll (per tick, 0 to 1). `override` is a tuned beast table (tests and tuning only).
function Director.chance(name, ctx, override)
	local beast = Config.BEASTS[name]
	if not beast then return 0 end
	local base = override and override.chance or beast.chance
	if not finite(base) then return 0 end
	return math.clamp(base * Director.multiplier(ctx), 0, D.MAX_CHANCE)
end

function Director.new(options)
	options = type(options) == "table" and options or {}
	-- No random source means no roll ever wins: a beast never starts by accident.
	local random = type(options.random) == "function" and options.random or function() return 1 end
	return { random = random, players = {}, encounters = {}, nextId = 0, log = {},
		counts = { rolled = 0, won = 0, started = 0, refused = 0, released = 0 } }
end

local function record(dir, userId)
	local value = dir.players[userId]
	if not value then
		value = { points = 0, active = {}, speciesReadyAt = {}, globalReadyAt = -math.huge }
		dir.players[userId] = value
	end
	return value
end

local function log(dir, entry)
	table.insert(dir.log, entry)
	if #dir.log > LOG_SIZE then table.remove(dir.log, 1) end
end

local function refuse(dir, userId, name, reason, now)
	dir.counts.refused += 1
	log(dir, { userId = userId, beast = name, reason = reason, at = now })
	return false, reason
end

function Director.budget(dir, userId)
	local value = dir.players[userId]
	if not value then return 0, 0 end
	local count = 0
	for _ in pairs(value.active) do count += 1 end
	return value.points, count
end

-- Checks every rule and books the encounter in the same call. opts.force (the Studio-only ForceSpawnBeast) skips the
-- roll's timers (respawn grace, global and species cooldowns) but never the budget, concurrency, a duplicate, the
-- biome, a safe zone, death or an active Silueta.
function Director.reserve(dir, userId, name, ctx, now, opts)
	local beast = Config.BEASTS[name]
	local force = type(opts) == "table" and opts.force == true
	if type(userId) ~= "number" then return refuse(dir, userId, name, "InvalidPlayer", now) end
	if not beast then return refuse(dir, userId, name, "UnknownBeast", now) end
	if not finite(now) then return refuse(dir, userId, name, "BadClock", now) end
	ctx = type(ctx) == "table" and ctx or {}
	if ctx.alive ~= true then return refuse(dir, userId, name, "Dead", now) end
	if ctx.safe == true then return refuse(dir, userId, name, "SafeZone", now) end
	if beast.biome and not (type(ctx.biomes) == "table" and ctx.biomes[beast.biome] == true) then
		return refuse(dir, userId, name, "Biome", now)
	end
	if ctx.siluetaActive == true then return refuse(dir, userId, name, "SiluetaActive", now) end
	local player = record(dir, userId)
	if not force then
		if finite(ctx.respawnedAt) and now - ctx.respawnedAt < D.RESPAWN_GRACE then
			return refuse(dir, userId, name, "RespawnGrace", now)
		end
		if now < player.globalReadyAt then return refuse(dir, userId, name, "GlobalCooldown", now) end
		if now < (player.speciesReadyAt[name] or -math.huge) then return refuse(dir, userId, name, "SpeciesCooldown", now) end
	end
	for _, id in pairs(player.active) do
		if dir.encounters[id] and dir.encounters[id].beast == name then return refuse(dir, userId, name, "AlreadyActive", now) end
	end
	local _, count = Director.budget(dir, userId)
	if count >= D.MAX_ACTIVE then return refuse(dir, userId, name, "MaxActive", now) end
	if player.points + beast.points > D.MAX_POINTS then return refuse(dir, userId, name, "Budget", now) end
	dir.nextId += 1
	local encounter = { id = "beast:" .. dir.nextId, beast = name, userId = userId, points = beast.points,
		startedAt = now, released = false }
	dir.encounters[encounter.id] = encounter
	player.points += beast.points
	player.active[encounter.id] = encounter.id
	dir.counts.started += 1
	log(dir, { userId = userId, beast = name, reason = "Started", id = encounter.id, at = now })
	return true, encounter
end

-- Returns true only for the first release of a known encounter; every later call (or an unknown id) is a no-op.
function Director.release(dir, id, reason, now)
	local encounter = type(id) == "string" and dir.encounters[id] or nil
	if not encounter or encounter.released then return false end
	encounter.released = true
	dir.encounters[id] = nil
	dir.counts.released += 1
	local player = dir.players[encounter.userId]
	if player then
		player.points = math.max(0, player.points - encounter.points)
		player.active[id] = nil
		if finite(now) then
			player.globalReadyAt = math.max(player.globalReadyAt, now + D.GLOBAL_COOLDOWN)
			player.speciesReadyAt[encounter.beast] = now + Config.BEASTS[encounter.beast].cooldown
		end
	end
	log(dir, { userId = encounter.userId, beast = encounter.beast, reason = "Ended:" .. tostring(reason), id = id, at = now })
	return true
end

-- One player's tick: every playable beast whose biome holds rolls once, in an order shuffled by the injected source;
-- each win tries to reserve. Returns the started encounters and the refused wins.
function Director.tick(dir, userId, ctx, now)
	local started, refused = {}, {}
	if type(ctx) ~= "table" or ctx.alive ~= true or ctx.safe == true then return started, refused end
	local names = {}
	for _, name in ipairs(Config.ORDER) do
		local biome = Config.BEASTS[name].biome
		-- A biome beast is rolled only inside its biome; the beast script ends one with no behaviour yet at once.
		if biome == nil or (type(ctx.biomes) == "table" and ctx.biomes[biome] == true) then table.insert(names, name) end
	end
	for i = #names, 2, -1 do
		local j = math.clamp(math.floor(dir.random() * i) + 1, 1, i)
		names[i], names[j] = names[j], names[i]
	end
	for _, name in ipairs(names) do
		dir.counts.rolled += 1
		if dir.random() < Director.chance(name, ctx) then
			dir.counts.won += 1
			local ok, value = Director.reserve(dir, userId, name, ctx, now)
			if ok then table.insert(started, value) else table.insert(refused, { beast = name, reason = value }) end
		end
	end
	return started, refused
end

-- A player leaves: every encounter is released once and nothing about the user is kept.
function Director.forget(dir, userId, now)
	local ids = {}
	local player = dir.players[userId]
	if player then
		for id in pairs(player.active) do table.insert(ids, id) end
		table.sort(ids)
		for _, id in ipairs(ids) do Director.release(dir, id, "Leave", now) end
	end
	dir.players[userId] = nil
	return ids
end

return Director

-- Nest Heist phase 4a (NB2): the one beast director (server only, pure). The beast script calls Director.tick for each
-- player every Config.DIRECTOR.POLL_SECONDS; nothing else rolls for beasts (no second scheduler, no per-beast RNG).
-- Wave 2 (pack, owner decision 2026-11-11): each beast rolls on a calendar, anchor + (i - 1) x BEAST_OFFSET +
-- k x TICK_SECONDS (20 s, 1 s apart), and a missed slot is never made up. A beast that cannot start (its own chase is
-- running, the budget or the concurrency cap is full, a cooldown, the respawn grace, La Silueta) does not roll at all:
-- the slot passes with no roll and nothing waits. Only Config.PLAYABLE beasts roll.
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

-- The dusk roll buff the beast script passes (WildboundDusk.buff(phase).roll): x1 outside Dusk. Clamped to the range
-- WildboundDusk.tune allows, so a bad value never turns into a slowdown or a big buff.
local DUSK_MIN, DUSK_MAX = 1, 1.5

-- The product of the multipliers whose condition is really true (each read from ctx[CONDITIONS[key] or key]), times the
-- dusk roll buff, capped at MAX_MULTIPLIER. Night and Dusk are different phases, so the dusk buff never stacks on night.
function Director.multiplier(ctx)
	local product = 1
	if type(ctx) ~= "table" then return product end
	for key, value in pairs(D.MULTIPLIERS) do
		if ctx[D.CONDITIONS[key] or key] == true then product *= value end
	end
	if finite(ctx.duskRoll) then product *= math.clamp(ctx.duskRoll, DUSK_MIN, DUSK_MAX) end
	return math.min(product, D.MAX_MULTIPLIER)
end

-- The effective chance of one roll (per tick, 0 to 1): base x riskModifier x conditions, capped at MAX_CHANCE.
-- `override` is a tuned beast table (tests and tuning only).
function Director.chance(name, ctx, override)
	local beast = Config.BEASTS[name]
	if not beast then return 0 end
	local base = override and override.chance or beast.chance
	if not finite(base) then return 0 end
	local risk = override and override.riskModifier or beast.riskModifier
	if not finite(risk) or risk < 0 then risk = 1 end
	return math.clamp(base * risk * Director.multiplier(ctx), 0, D.MAX_CHANCE)
end

-- Eligibility by place (beast spawn design, owner decision 3): a Biome beast needs its biome tag in ctx.biomes; a Global
-- beast is barred from every biome in Config.NO_GLOBAL_BIOMES (Pradera). Safe zones bar every beast before this. The
-- biome and category are the effective ones (Config.homeBiome / categoryOf): with Config.BIOME_PREFERENCE off every
-- playable beast is Global. Returns nil when eligible, else the refusal reason.
function Director.placeBlock(name, ctx)
	local beast = Config.BEASTS[name]
	if not beast then return "UnknownBeast" end
	local biomes = type(ctx) == "table" and type(ctx.biomes) == "table" and ctx.biomes or {}
	local home = Config.homeBiome(name)
	if home and biomes[home] ~= true then return "Biome" end
	if Config.categoryOf(name) == "Global" then
		for tag in pairs(Config.NO_GLOBAL_BIOMES) do
			if biomes[tag] == true then return "NoGlobalZone" end
		end
	end
	return nil
end

function Director.new(options)
	options = type(options) == "table" and options or {}
	-- No random source means no roll ever wins: a beast never starts by accident.
	local random = type(options.random) == "function" and options.random or function() return 1 end
	return { random = random, players = {}, encounters = {}, nextId = 0, log = {},
		counts = { rolled = 0, won = 0, started = 0, refused = 0, released = 0, skipped = 0 } }
end

local function record(dir, userId)
	local value = dir.players[userId]
	if not value then
		value = { points = 0, active = {}, speciesReadyAt = {}, globalReadyAt = -math.huge, anchor = nil, slots = {} }
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
-- biome, Pradera for a global beast, a safe zone, death or an active Silueta.
-- Every rule reserve applies, without booking or logging anything. Returns nil when the beast may start now, else the
-- refusal reason. Shared by reserve (which books in the same call) and by the roll (which then does not roll at all).
-- roar (DG6, Director.roar): Don Glaseon's guardians' roar may pass MAX_ACTIVE; every other rule stands.
-- PF1: whether a beast stands outside MAX_ACTIVE (a summoned beast worth 0 points: the Pradera and Caramelo creatures).
function Director.uncapped(name)
	local beast = Config.BEASTS[name]
	return Config.SUMMONED[name] == true and beast ~= nil and beast.points == 0
end
-- CH1 (owner request "more repeated creatures in the Caramelo kingdom"): post (a WildboundPraderaSites.EXTRA_POSTS key,
-- or nil for the beast's home post) makes a summoned beast one of a kind per post, with its own species rest.
local function check(dir, userId, name, ctx, now, force, roar, post)
	local beast = Config.BEASTS[name]
	if type(userId) ~= "number" then return "InvalidPlayer" end
	if not beast then return "UnknownBeast" end
	if not finite(now) then return "BadClock" end
	ctx = type(ctx) == "table" and ctx or {}
	if ctx.alive ~= true then return "Dead" end
	if ctx.safe == true then return "SafeZone" end
	local blocked = Director.placeBlock(name, ctx)
	if blocked then return blocked end
	if ctx.siluetaActive == true then return "SiluetaActive" end
	local player = record(dir, userId)
	if not force then
		if finite(ctx.respawnedAt) and now - ctx.respawnedAt < D.RESPAWN_GRACE then return "RespawnGrace" end
		-- Kids biome: a summoned beast neither obeys nor sets the global cooldown (Config.SUMMONED).
		if not Config.SUMMONED[name] and now < player.globalReadyAt then return "GlobalCooldown" end
		if now < (player.speciesReadyAt[post and name .. "@" .. post or name] or -math.huge) then return "SpeciesCooldown" end
	end
	for _, id in pairs(player.active) do
		-- CH1: one per post; a roar still never adds a second of a kind (DG6)
		local other = dir.encounters[id]
		if other and other.beast == name and (roar == true or other.post == post) then return "AlreadyActive" end
	end
	-- Caramelo biome (CA3): a serverUnique beast (Don Glaseon) is one per server: none while one lives, nor during its
	-- switch rest after the last one ended (then it may take another target).
	if beast.serverUnique == true then
		for _, other in pairs(dir.encounters) do
			if other.beast == name then return "BossBusy" end
		end
		if now < ((dir.uniqueReadyAt or {})[name] or -math.huge) then return "BossResting" end
	end
	local _, count = Director.budget(dir, userId)
	-- PF1 (odd/tasks/wildbound-caramelo-playfix.md): a summoned points-0 beast stands outside MAX_ACTIVE; the cap counts
	-- and refuses only the other (rolled) beasts.
	if not Director.uncapped(name) and roar ~= true then
		local capped = 0
		for _, id in pairs(player.active) do
			local other = dir.encounters[id]
			if other and not Director.uncapped(other.beast) then capped += 1 end
		end
		if capped >= D.MAX_ACTIVE then return "MaxActive" end
	end
	if player.points + beast.points > D.MAX_POINTS then return "Budget" end
	-- A beast that fills the whole budget (Scuttler, 3 points) hunts alone: a 0-point summoned kids beast never starts
	-- beside it, and it never starts beside one (docs/design/wildbound-scuttler-plan.md, "only alone").
	if count > 0 and (player.points >= D.MAX_POINTS or beast.points >= D.MAX_POINTS) then return "Budget" end
	return nil
end
Director.blocked = function(dir, userId, name, ctx, now, force)
	return check(dir, userId, name, ctx, now, force == true)
end

function Director.reserve(dir, userId, name, ctx, now, opts)
	local beast = Config.BEASTS[name]
	local force = type(opts) == "table" and opts.force == true
	local post = type(opts) == "table" and type(opts.post) == "string" and opts.post or nil
	local why = check(dir, userId, name, ctx, now, force, type(opts) == "table" and opts.roar == true, post)
	if why then return refuse(dir, userId, name, why, now) end
	local player = record(dir, userId)
	dir.nextId += 1
	local encounter = { id = "beast:" .. dir.nextId, beast = name, userId = userId, points = beast.points,
		startedAt = now, released = false, post = post }
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
			local beast = Config.BEASTS[encounter.beast]
			if not Config.SUMMONED[encounter.beast] then
				player.globalReadyAt = math.max(player.globalReadyAt, now + D.GLOBAL_COOLDOWN)
			end
			-- A reason-specific cooldown (the Nube's Bostezo nap) wins over the species cooldown.
			local ends = beast.endCooldowns
			local rest = encounter.post and encounter.beast .. "@" .. encounter.post or encounter.beast -- CH1: per post
			player.speciesReadyAt[rest] = now + (ends and ends[reason] or beast.cooldown)
			if beast.serverUnique == true then
				dir.uniqueReadyAt = dir.uniqueReadyAt or {}
				dir.uniqueReadyAt[encounter.beast] = now + (beast.switchSeconds or 0)
			end
		end
	end
	log(dir, { userId = encounter.userId, beast = encounter.beast, reason = "Ended:" .. tostring(reason), id = id, at = now })
	return true
end

-- Kids biome (odd/tasks/wildbound-kids-beasts.md): the presence spawn of the Pradera beasts. Only Config.SUMMONED beasts
-- (never rolled, never in ORDER); the same rules as reserve (placeBlock keeps them in their Meadow home, budget 0 points,
-- AlreadyActive, species cooldown, respawn grace, safe zone, death, Silueta), except the global cooldown and (PF1)
-- MAX_ACTIVE. A refusal is returned without a log entry: the beast script asks every poll while the player stays near
-- and writes the reason to telemetry (Beast_lastSummonRefusal).
function Director.summon(dir, userId, name, ctx, now, opts)
	if not Config.SUMMONED[name] then return false, "NotSummoned" end
	local force = type(opts) == "table" and opts.force == true
	local why = check(dir, userId, name, ctx, now, force, nil, type(opts) == "table" and type(opts.post) == "string" and opts.post or nil)
	if why then return false, why end
	return Director.reserve(dir, userId, name, ctx, now, opts)
end

-- CG2 (F5, odd/tasks/wildbound-caramelo.md decision 50): a stolen Caramelo nest egg wakes that nest's guardian on the
-- thief at once. Only a summoned beast; every rule of summon stands (its home biome, safe zones, death, an active Silueta,
-- one of a kind per player, budget) except the timers a forced reservation skips (species rest, respawn grace).
-- CH1: post (optional) wakes the guardian copy of that extra post (the nest's binding "<name>@<post>").
function Director.alarm(dir, userId, name, ctx, now, post)
	if not Config.SUMMONED[name] then return false, "NotSummoned" end
	return Director.reserve(dir, userId, name, ctx, now, { force = true, post = post })
end

-- Caramelo v2 (DG6, odd/tasks/wildbound-caramelo-v2.md): Don Glaseon's guardians' roar wakes a fresh candy guardian on
-- the thief. Like alarm (the timers skipped) and past the per-player MAX_ACTIVE, but never a second of a kind on one
-- player (the one already there stays the only one), never in a safe zone, only the three candy guardians.
Director.ROAR = table.freeze({ Gomibu = true, Flanfuria = true, Tortidragon = true })
function Director.roar(dir, userId, name, ctx, now)
	if not Director.ROAR[name] then return false, "NotRoarable" end
	return Director.reserve(dir, userId, name, ctx, now, { force = true, roar = true })
end

-- Wave 2: the calendar. The first call for a player sets their anchor; beast i of Config.ORDER has its slots at
-- anchor + (i - 1) x BEAST_OFFSET + k x TICK_SECONDS, k >= 1 (the first roll comes one interval after the anchor).
-- Returns the beasts whose newest slot has passed and was not consumed yet, and consumes it. Only the newest slot
-- counts: slots missed while the server stalled are dropped, so a beast never rolls twice to catch up.
function Director.due(dir, userId, now)
	local due = {}
	if type(userId) ~= "number" or not finite(now) then return due end
	local player = record(dir, userId)
	player.anchor = player.anchor or now
	for i, name in ipairs(Config.ORDER) do
		local phase = player.anchor + (i - 1) * D.BEAST_OFFSET
		local slot = math.floor((now - phase) / D.TICK_SECONDS + 1e-9)
		if slot >= 1 and slot > (player.slots[name] or 0) then
			player.slots[name] = slot
			table.insert(due, name)
		end
	end
	return due
end

-- The next slot time of one beast for one player (nil before the anchor exists). Read-only, for the Studio probe.
function Director.nextSlot(dir, userId, name, now)
	local player = dir.players[userId]
	if not player or not player.anchor or not finite(now) then return nil end
	for i, other in ipairs(Config.ORDER) do
		if other == name then
			local phase = player.anchor + (i - 1) * D.BEAST_OFFSET
			local slot = math.max(1, math.floor((now - phase) / D.TICK_SECONDS + 1e-9) + 1)
			return phase + slot * D.TICK_SECONDS
		end
	end
	return nil
end

-- Rolls the given beasts (default: every beast) once for one player: a playable beast whose place holds and that could
-- start right now rolls; any other is skipped with no roll spent (returned in `refused` with rolled = false). Two
-- beasts due together are taken in an order shuffled by the injected source; each win reserves atomically.
-- Returns the started encounters and the refusals.
function Director.roll(dir, userId, ctx, now, names)
	local started, refused = {}, {}
	if type(ctx) ~= "table" or ctx.alive ~= true or ctx.safe == true then return started, refused end
	local list = {}
	for _, name in ipairs(type(names) == "table" and names or Config.ORDER) do
		-- A biome beast is rolled only inside its biome, a global beast never in Pradera, a beast with no behaviour
		-- never (no roll is spent on any of them).
		if Config.PLAYABLE[name] and Director.placeBlock(name, ctx) == nil then table.insert(list, name) end
	end
	for i = #list, 2, -1 do
		local j = math.clamp(math.floor(dir.random() * i) + 1, 1, i)
		list[i], list[j] = list[j], list[i]
	end
	for _, name in ipairs(list) do
		local why = check(dir, userId, name, ctx, now, false)
		if why then
			-- Pack: already chasing, no capacity (and every other rule): no roll and nothing kept for later.
			dir.counts.skipped += 1
			table.insert(refused, { beast = name, reason = why, rolled = false })
		else
			dir.counts.rolled += 1
			if dir.random() < Director.chance(name, ctx) then
				dir.counts.won += 1
				local ok, value = Director.reserve(dir, userId, name, ctx, now)
				if ok then table.insert(started, value)
				else table.insert(refused, { beast = name, reason = value, rolled = true }) end
			end
		end
	end
	return started, refused
end

-- One player's poll: the beasts whose calendar slot is due roll (Director.roll). A dead player or one in a safe zone
-- still consumes the slots, so nothing accumulates while they wait.
function Director.tick(dir, userId, ctx, now)
	local due = Director.due(dir, userId, now)
	if #due == 0 then return {}, {} end
	return Director.roll(dir, userId, ctx, now, due)
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

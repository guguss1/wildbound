-- Wildbound 2.0 balance, PROPOSED and UNWIRED: no module requires it. Values come from the external 2.0 pack and are
-- not validated in play. Later tasks (T02-T10) wire it.
-- Pure data plus pure rules: no services, no clock, no rolls, no saved data. Every helper reads CONSTANTS unless a
-- config table is passed as its last argument (tests pass edited copies). Plan: docs/design/wildbound-2-0-schema-plan.md;
-- tasks: odd/tasks/wildbound-2-0.md. There is no tune() here: tuning is registered in TuningSchema at wiring time.
-- LIVE records what the running game uses today where it differs from the pack; conflicts() reports each gap.
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

local function deepCopy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for key, child in pairs(value) do out[key] = deepCopy(child) end
	return out
end

local EPS = 1e-9

local Balance = {}

Balance.status = "proposed"
Balance.wired = false
Balance.schemaVersion = 1

-- The existing rarity ids (WildboundSpecies). 2.0 English names: Comun = Common, Rara = Rare, Epica = Epic,
-- Legendaria = Legendary.
Balance.RARITIES = freeze({ "Comun", "Rara", "Epica", "Legendaria" })

-- Day cycle phases in play order.
Balance.PHASES = freeze({ "Day", "Dusk", "Night", "Dawn" })

-- The six roulette prize categories the 2.0 pack names.
Balance.ROULETTE_CATEGORIES = freeze({ "esencia", "materials", "gloves", "incubationBoosters", "consumables", "specialEgg" })

-- The three shop consumables the 2.0 pack names.
Balance.CONSUMABLES = freeze({ "trap", "smoke", "portablePortal" })

-- Round-2 decision Q9 (docs/design/wildbound-combined-plan.md section 6): the walk stays at 16 and La Silueta's night
-- hunt runs at 17. A decision record for conflicts(); the live hunt speed comes from LIVE.silueta.
Balance.Q9 = freeze({ walk = 16, siluetaNightHunt = 17 })

Balance.CONSTANTS = freeze({
	treadmill = {
		speeds = { 16, 17, 18, 19, 20, 21 }, -- studs/s walk speed at treadmill levels 0..5 (index = level + 1)
		costs = { 0, 30, 80, 200, 450, 900 }, -- Esencia to reach levels 0..5; level 0 is free
	},
	incubation = {
		firstEggSeconds = 10, -- seconds for the account's first hatch, no upgrade, booster or minimum
		secondEggSeconds = 20, -- seconds for the account's second hatch, no upgrade, booster or minimum
		baseSeconds = { Comun = 40, Rara = 75, Epica = 150, Legendaria = 300 }, -- seconds per rarity at upgrade level 0
		-- Floor per rarity (proposed minimums, not from the pack). Rule 6 keeps each at or below the fully upgraded time,
		-- so the floor only binds when an incubation booster (a roulette prize) cuts the time further.
		minSeconds = { Comun = 25, Rara = 45, Epica = 90, Legendaria = 180 },
		upgradeFactors = { 1, 0.9, 0.8, 0.7 }, -- multiplier on baseSeconds at incubator levels 0..III (cumulative off base)
		upgradeCosts = { 0, 100, 300, 750 }, -- Esencia to reach incubator levels 0..III
		secondCradleCost = 250, -- Esencia for the second incubator cradle
	},
	farm = {
		startSlots = 4, -- farm slots a new account owns
		maxSlots = 8, -- farm slots an account can own
		slotCosts = { [5] = 200, [6] = 500 }, -- Esencia per extra slot index; slots 7 and 8 are TBD and absent
		incomePerMinute = { Comun = 1, Rara = 3, Epica = 7, Legendaria = 15 }, -- Esencia per minute per placed creature
		uncollectedCapMinutes = 15, -- minutes of income that accrue before collection stops it
	},
	sell = {
		price = { Comun = 15, Rara = 60, Epica = 200, Legendaria = 650 }, -- Esencia per sold creature
	},
	bat = {
		cooldown = 5, -- seconds between swings
		ragdollSeconds = 1.2, -- seconds a hit player stays ragdolled
		push = 45, -- studs/s horizontal knockback (BatKnock IMPULSE)
		lift = 20, -- studs/s vertical knockback
		immunity = 3, -- seconds a hit player cannot be hit again; at least ragdollSeconds + 1
		parentStun = 0.6, -- seconds a nest parent is stunned by a hit
	},
	portal = {
		calmSeconds = 5, -- seconds without threat before a portal can be used
		channelSeconds = 2, -- seconds of channel before the teleport
		cooldown = 30, -- seconds between uses per player
	},
	consumables = {
		price = { trap = 60, smoke = 40, portablePortal = 125 }, -- Esencia per item
	},
	dayCycle = {
		cycleSeconds = 720, -- seconds per full day cycle
		phases = { Day = 240, Dusk = 60, Night = 300, Dawn = 120 }, -- seconds per phase; they sum to cycleSeconds
	},
	roulette = {
		weights = { esencia = 35, materials = 25, gloves = 20, incubationBoosters = 12, consumables = 6, specialEgg = 2 }, -- percent per category; sum 100
		freeFirstSpin = true, -- every account gets one free spin
		spinCost = 45, -- Esencia per paid spin
		-- prizeOdds: per-prize odds inside each category, left for T09a (absent).
		-- pity: undecided (absent).
	},
})

-- What the running game uses today (the live Studio sources, synced into the repo at commit 34eab83). Not owned here:
-- a record of the gap later tasks must close. Balance.liveFrom() rebuilds it from the live modules so the copy cannot
-- drift silently (test B23). Sources: WildboundWorldRules PHASES; WildboundTraining CONSTANTS and the TuningSchema
-- WALK_CAP entry; WildboundBatKnock CONSTANTS (immunityMax is the clamp in its tune(), not exported); WildboundIncubator
-- CONSTANTS; WildboundStamina CONSTANTS; the TuningSchema HUNT_NIGHT entry.
Balance.LIVE = freeze({
	dayCycle = { cycleSeconds = 720, phases = { Day = 300, Dusk = 60, Night = 300, Dawn = 60 } },
	training = { walkStep = 0.25, maxLevel = 4, walkCap = 16, walkCapMin = 16, walkCapMax = 16.5, baseCost = 30, costGrowth = 1.6 },
	bat = { cooldown = 5, ragdollSeconds = 1.2, immunity = 3, push = 45, lift = 20, immunityMax = 15 },
	incubator = { hatchSeconds = 15, slots = 1 },
	movement = { sprintMultiplier = 1.45, sprintCap = 24 },
	silueta = { nightHunt = 17 },
})

-- Allowed range per numeric field, by dotted path. kind: "scalar" is one number, "array" a list keyed 1..n, "map" a
-- keyed table; every entry of a list or map must be in the range. integer: every value must be a whole number.
local function scalar(min, max, integer) return { kind = "scalar", min = min, max = max, integer = integer == true } end
local function array(min, max, integer) return { kind = "array", min = min, max = max, integer = integer == true } end
local function map(min, max, integer) return { kind = "map", min = min, max = max, integer = integer == true } end
Balance.RANGES = freeze({
	["treadmill.speeds"] = array(16, 24),
	["treadmill.costs"] = array(0, 5000, true),
	["incubation.firstEggSeconds"] = scalar(5, 60),
	["incubation.secondEggSeconds"] = scalar(5, 120),
	["incubation.baseSeconds"] = map(10, 900),
	["incubation.minSeconds"] = map(5, 900),
	["incubation.upgradeFactors"] = array(0.5, 1),
	["incubation.upgradeCosts"] = array(0, 5000, true),
	["incubation.secondCradleCost"] = scalar(0, 5000, true),
	["farm.startSlots"] = scalar(1, 8, true),
	["farm.maxSlots"] = scalar(1, 12, true),
	["farm.slotCosts"] = map(0, 10000, true),
	["farm.incomePerMinute"] = map(0, 100, true),
	["farm.uncollectedCapMinutes"] = scalar(1, 120),
	["sell.price"] = map(0, 5000, true),
	-- The bat bounds match the safety clamps in WildboundBatKnock tune(); the immunity floor is ragdollSeconds + 1 (rule 9).
	["bat.cooldown"] = scalar(3, 30),
	["bat.ragdollSeconds"] = scalar(0.5, 2),
	["bat.push"] = scalar(10, 60),
	["bat.lift"] = scalar(0, 35),
	["bat.immunity"] = scalar(0, 15),
	["bat.parentStun"] = scalar(0, 3),
	["portal.calmSeconds"] = scalar(0, 30),
	["portal.channelSeconds"] = scalar(0, 10),
	["portal.cooldown"] = scalar(5, 300),
	["consumables.price"] = map(0, 2000, true),
	["dayCycle.cycleSeconds"] = scalar(120, 3600),
	["dayCycle.phases"] = map(10, 3600),
	["roulette.weights"] = map(0, 100),
	["roulette.spinCost"] = scalar(0, 1000, true),
})

local RANGE_PATHS = {}
for path in pairs(Balance.RANGES) do table.insert(RANGE_PATHS, path) end
table.sort(RANGE_PATHS)

local function get(config, path)
	local node = config
	for key in string.gmatch(path, "[^%.]+") do
		if type(node) ~= "table" then return nil end
		node = node[key]
	end
	return node
end

local function num(value)
	if finite(value) then return value end
	return nil
end

-- A plain array (keys exactly 1..n), or nil.
local function sequence(value)
	if type(value) ~= "table" then return nil end
	local count = 0
	for _ in pairs(value) do count += 1 end
	if count ~= #value then return nil end
	return value
end

local function sortedKeys(keyed)
	local keys = {}
	for key in pairs(keyed) do table.insert(keys, key) end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	return keys
end

local function checkNumber(label, value, range, fail)
	if not finite(value) then
		fail(label .. ": not a finite number (" .. tostring(value) .. ")")
	elseif value < range.min or value > range.max then
		fail(string.format("%s: %g is outside %g..%g", label, value, range.min, range.max))
	elseif range.integer and value % 1 ~= 0 then
		fail(string.format("%s: %g is not a whole number", label, value))
	end
end

-- Rule 1: every value has its kind (one number, a list or a map), is finite, inside RANGES and whole where required.
local function checkRanges(config, fail)
	for _, path in ipairs(RANGE_PATHS) do
		local range = Balance.RANGES[path]
		local value = get(config, path)
		if range.kind == "scalar" then
			if type(value) == "table" then
				fail(path .. ": expected a number, got a table")
			else
				checkNumber(path, value, range, fail)
			end
		elseif type(value) ~= "table" then
			fail(path .. ": expected a table, got " .. type(value))
		elseif range.kind == "array" and not sequence(value) then
			fail(path .. ": expected an array keyed 1..n")
		else
			for _, key in ipairs(sortedKeys(value)) do
				checkNumber(path .. "[" .. tostring(key) .. "]", value[key], range, fail)
			end
		end
	end
	if type(get(config, "roulette.freeFirstSpin")) ~= "boolean" then fail("roulette.freeFirstSpin: not a boolean") end
end

-- Rule 2: the phases sum to the cycle length, and only the four known phases exist.
local function checkCycle(config, fail)
	local phases = get(config, "dayCycle.phases")
	if type(phases) ~= "table" then
		fail("dayCycle.phases: not a table, so the day cycle cannot be checked")
		return
	end
	local known = {}
	local sum = 0
	for _, name in ipairs(Balance.PHASES) do
		known[name] = true
		local seconds = num(phases[name])
		if seconds == nil then
			fail("dayCycle.phases." .. name .. ": missing or not finite, so the day cycle cannot be summed")
			return
		end
		sum += seconds
	end
	for _, name in ipairs(sortedKeys(phases)) do
		if not known[name] then fail("dayCycle.phases." .. tostring(name) .. ": not a day cycle phase") end
	end
	local cycle = num(get(config, "dayCycle.cycleSeconds"))
	if cycle and math.abs(sum - cycle) > EPS then
		fail(string.format("dayCycle: the phases sum to %g, not the cycle length %g", sum, cycle))
	end
end

-- Rule 3: the roulette weights cover exactly the six known categories and sum to 100.
local function checkRoulette(config, fail)
	local weights = get(config, "roulette.weights")
	if type(weights) ~= "table" then
		fail("roulette.weights: not a table")
		return
	end
	local known = {}
	for _, name in ipairs(Balance.ROULETTE_CATEGORIES) do
		known[name] = true
		if weights[name] == nil then fail("roulette.weights: missing category " .. name) end
	end
	local sum = 0
	for _, name in ipairs(sortedKeys(weights)) do
		if not known[name] then fail("roulette.weights." .. tostring(name) .. ": not a roulette category") end
		sum += num(weights[name]) or 0
	end
	if math.abs(sum - 100) > EPS then fail(string.format("roulette.weights: sum %g, not 100", sum)) end
end

local function strictly(list, label, increasing, fail)
	for index = 2, #list do
		local before, after = num(list[index - 1]), num(list[index])
		if before and after then
			if increasing and after <= before then
				fail(string.format("%s: entry %d (%g) does not increase over entry %d (%g)", label, index, after, index - 1, before))
			elseif not increasing and after >= before then
				fail(string.format("%s: entry %d (%g) does not decrease below entry %d (%g)", label, index, after, index - 1, before))
			end
		end
	end
end

-- Rule 4: treadmill speeds and costs pair up level by level, both strictly increase, and level 0 is free.
local function checkTreadmill(config, fail)
	local speeds = sequence(get(config, "treadmill.speeds"))
	local costs = sequence(get(config, "treadmill.costs"))
	if not speeds or not costs then
		fail("treadmill: speeds and costs must both be arrays")
		return
	end
	if #speeds == 0 then fail("treadmill.speeds: empty") end
	if #speeds ~= #costs then fail(string.format("treadmill: %d speeds but %d costs", #speeds, #costs)) end
	strictly(speeds, "treadmill.speeds", true, fail)
	strictly(costs, "treadmill.costs", true, fail)
	if costs[1] ~= 0 then fail("treadmill.costs[1]: level 0 must cost 0, got " .. tostring(costs[1])) end
end

-- Rule 5: incubator factors start at 1 and strictly decrease (each inside RANGES, so level III is tunable there);
-- costs start free, strictly increase and pair up with the factors.
local function checkUpgrades(config, fail)
	local factors = sequence(get(config, "incubation.upgradeFactors"))
	local costs = sequence(get(config, "incubation.upgradeCosts"))
	if not factors or not costs then
		fail("incubation: upgradeFactors and upgradeCosts must both be arrays")
		return
	end
	if #factors == 0 then
		fail("incubation.upgradeFactors: empty")
		return
	end
	if factors[1] ~= 1 then fail("incubation.upgradeFactors[1]: level 0 must be 1, got " .. tostring(factors[1])) end
	strictly(factors, "incubation.upgradeFactors", false, fail)
	if #costs ~= #factors then
		fail(string.format("incubation: %d upgrade factors but %d upgrade costs", #factors, #costs))
	end
	strictly(costs, "incubation.upgradeCosts", true, fail)
	if costs[1] ~= 0 then fail("incubation.upgradeCosts[1]: level 0 must cost 0, got " .. tostring(costs[1])) end
end

-- Rule 6: each rarity's minimum is reachable: it never exceeds the base or the fully upgraded time.
local function checkMinimums(config, fail)
	local base = get(config, "incubation.baseSeconds")
	local minimum = get(config, "incubation.minSeconds")
	local factors = sequence(get(config, "incubation.upgradeFactors"))
	if type(base) ~= "table" or type(minimum) ~= "table" or not factors then return end
	local last = num(factors[#factors])
	for _, rarity in ipairs(Balance.RARITIES) do
		local b, m = num(base[rarity]), num(minimum[rarity])
		if b and m then
			if m > b + EPS then
				fail(string.format("incubation.minSeconds.%s: %g is above baseSeconds %g", rarity, m, b))
			end
			if last and m > b * last + EPS then
				fail(string.format("incubation.minSeconds.%s: %g is above the fully upgraded time %g", rarity, m, b * last))
			end
		end
	end
end

-- Rule 7: the starting slots fit under the maximum, and every priced slot is one a player can buy.
local function checkFarm(config, fail)
	local start, max = num(get(config, "farm.startSlots")), num(get(config, "farm.maxSlots"))
	if start and max and start > max then fail(string.format("farm: startSlots %g is above maxSlots %g", start, max)) end
	local slotCosts = get(config, "farm.slotCosts")
	if type(slotCosts) ~= "table" then
		fail("farm.slotCosts: not a table")
		return
	end
	for _, slot in ipairs(sortedKeys(slotCosts)) do
		if not finite(slot) or slot % 1 ~= 0 or (start and slot <= start) or (max and slot > max) then
			fail("farm.slotCosts[" .. tostring(slot) .. "]: the slot must be a whole index above startSlots and at most maxSlots")
		end
	end
end

-- Rule 8: the keyed maps hold exactly their ids, none missing and none extra.
local KEYED_MAPS = {
	{ "sell.price", Balance.RARITIES, "rarity" },
	{ "farm.incomePerMinute", Balance.RARITIES, "rarity" },
	{ "incubation.baseSeconds", Balance.RARITIES, "rarity" },
	{ "incubation.minSeconds", Balance.RARITIES, "rarity" },
	{ "consumables.price", Balance.CONSUMABLES, "consumable" },
}
local function checkKeys(config, fail)
	for _, entry in ipairs(KEYED_MAPS) do
		local path, ids, noun = entry[1], entry[2], entry[3]
		local keyed = get(config, path)
		if type(keyed) ~= "table" then
			fail(path .. ": not a table")
		else
			local known = {}
			for _, id in ipairs(ids) do
				known[id] = true
				if keyed[id] == nil then fail(path .. ": missing " .. noun .. " " .. id) end
			end
			for _, key in ipairs(sortedKeys(keyed)) do
				if not known[key] then fail(path .. ": unknown " .. noun .. " " .. tostring(key)) end
			end
		end
	end
end

-- Rule 9: hit immunity outlasts the ragdoll by at least a second.
local function checkBat(config, fail)
	local immunity, ragdoll = num(get(config, "bat.immunity")), num(get(config, "bat.ragdollSeconds"))
	if immunity and ragdoll and immunity < ragdoll + 1 - EPS then
		fail(string.format("bat.immunity: %g is below ragdollSeconds + 1 (%g)", immunity, ragdoll + 1))
	end
end

local RULES = {
	{ "ranges", checkRanges },
	{ "cycle", checkCycle },
	{ "roulette", checkRoulette },
	{ "treadmill", checkTreadmill },
	{ "upgrades", checkUpgrades },
	{ "minimums", checkMinimums },
	{ "farm", checkFarm },
	{ "keys", checkKeys },
	{ "bat", checkBat },
}

-- Pure. Returns (ok, errors); errors is an array of strings, empty when ok. Never throws.
function Balance.validate(config)
	if config == nil then config = Balance.CONSTANTS end
	local errors = {}
	local function fail(message) table.insert(errors, message) end
	if type(config) ~= "table" then
		fail("config: not a table")
		return false, errors
	end
	for _, rule in ipairs(RULES) do
		local ran, problem = pcall(rule[2], config, fail)
		if not ran then fail("rule " .. rule[1] .. " could not run: " .. tostring(problem)) end
	end
	return #errors == 0, errors
end

-- Builds a LIVE-shaped table from the live modules (or their CONSTANTS tables), which the caller loads and passes in:
-- { worldRules, training, stamina, batKnock, incubator, tuningSchema }. Any source that is absent or unreadable keeps
-- the LIVE value. Pure: it only reads the tables and calls worldRules.cycle(t).
function Balance.liveFrom(sources)
	local live = deepCopy(Balance.LIVE)
	if type(sources) ~= "table" then return live end
	local function constants(source)
		if type(source) ~= "table" then return nil end
		if type(source.CONSTANTS) == "table" then return source.CONSTANTS end
		return source
	end
	local function take(target, key, value)
		if finite(value) then target[key] = value end
	end
	pcall(function()
		local rules = sources.worldRules
		if type(rules) ~= "table" or type(rules.cycle) ~= "function" or not finite(rules.CYCLE_SECONDS) then return end
		local phases, at = {}, 0
		for _ = 1, 8 do
			if at >= rules.CYCLE_SECONDS - EPS then break end
			local now = rules.cycle(at)
			if type(now) ~= "table" or type(now.phase) ~= "string" or not finite(now.remaining) or now.remaining <= 0 then return end
			phases[now.phase] = now.remaining
			at += now.remaining
		end
		for _, name in ipairs(Balance.PHASES) do
			if not finite(phases[name]) then return end
		end
		live.dayCycle = { cycleSeconds = rules.CYCLE_SECONDS, phases = phases }
	end)
	pcall(function()
		local c = constants(sources.training)
		if not c then return end
		take(live.training, "walkStep", c.WALK_STEP)
		take(live.training, "maxLevel", c.MAX_LEVEL)
		take(live.training, "walkCap", c.WALK_CAP)
		take(live.training, "baseCost", c.BASE_COST)
		take(live.training, "costGrowth", c.COST_GROWTH)
	end)
	pcall(function()
		local c = constants(sources.stamina)
		if not c then return end
		take(live.movement, "sprintMultiplier", c.SPRINT_MULTIPLIER)
		take(live.movement, "sprintCap", c.SPEED_CAP)
	end)
	pcall(function()
		local c = constants(sources.batKnock)
		if not c then return end
		take(live.bat, "cooldown", c.COOLDOWN)
		take(live.bat, "ragdollSeconds", c.RAGDOLL_SECONDS)
		take(live.bat, "immunity", c.IMMUNITY)
		take(live.bat, "push", c.IMPULSE)
		take(live.bat, "lift", c.LIFT)
	end)
	pcall(function()
		local c = constants(sources.incubator)
		if not c then return end
		take(live.incubator, "hatchSeconds", c.HATCH_SECONDS)
		take(live.incubator, "slots", c.SLOTS)
	end)
	pcall(function()
		local schema = sources.tuningSchema
		if type(schema) ~= "table" or type(schema.SYSTEMS) ~= "table" then return end
		for _, system in ipairs(schema.SYSTEMS) do
			for _, entry in ipairs(type(system) == "table" and type(system.entries) == "table" and system.entries or {}) do
				if entry.key == "WALK_CAP" and system.id == "Training" then
					take(live.training, "walkCapMin", entry.min)
					take(live.training, "walkCapMax", entry.max)
				elseif entry.key == "HUNT_NIGHT" and system.id == "Silueta" then
					take(live.silueta, "nightHunt", entry.default)
				end
			end
		end
	end)
	return live
end

-- Flags, not errors: where these values disagree with the round-2 decisions or with the live game. live defaults to
-- Balance.LIVE; pass Balance.liveFrom(...) to compare against the modules as they are now. Returns an array of strings.
function Balance.conflicts(config, live)
	if config == nil then config = Balance.CONSTANTS end
	if type(live) ~= "table" then live = Balance.LIVE end
	local list = {}
	local function add(...) table.insert(list, string.format(...)) end
	local speeds = sequence(get(config, "treadmill.speeds"))
	local top = speeds and num(speeds[#speeds])
	pcall(function()
		if not top then return end
		if top > Balance.Q9.walk then
			add("Q9: the top treadmill walk %g is above the round-2 walk %g", top, Balance.Q9.walk)
		end
		local hunt = num(get(live, "silueta.nightHunt")) or Balance.Q9.siluetaNightHunt
		if top > hunt then
			add("Q9: the top treadmill walk %g is above La Silueta's night hunt speed %g, so a walking player outruns the Silueta", top, hunt)
		end
		local multiplier, cap = num(get(live, "movement.sprintMultiplier")), num(get(live, "movement.sprintCap"))
		if multiplier and cap and top * multiplier > cap then
			add("sprint %g x %g = %g is clamped to the Stamina cap %g", top, multiplier, top * multiplier, cap)
		end
	end)
	pcall(function()
		local cycle, liveCycle = num(get(config, "dayCycle.cycleSeconds")), num(get(live, "dayCycle.cycleSeconds"))
		if cycle and liveCycle and cycle ~= liveCycle then
			add("live: dayCycle.cycleSeconds is %g live, %g in Balance (WildboundWorldRules)", liveCycle, cycle)
		end
		for _, name in ipairs(Balance.PHASES) do
			local mine, theirs = num(get(config, "dayCycle.phases." .. name)), num(get(live, "dayCycle.phases." .. name))
			if mine and theirs and mine ~= theirs then
				add("live: dayCycle.phases.%s is %g live, %g in Balance (WildboundWorldRules)", name, theirs, mine)
			end
		end
	end)
	pcall(function()
		if not top then return end
		local capMin, capMax = num(get(live, "training.walkCapMin")), num(get(live, "training.walkCapMax"))
		if capMax and top > capMax then
			add("live: the top treadmill walk %g is above the WALK_CAP tuning range %g..%g (TuningSchema), so the live cap clamps it", top, capMin or capMax, capMax)
		end
		local maxLevel, step = num(get(live, "training.maxLevel")), num(get(live, "training.walkStep"))
		if maxLevel and maxLevel ~= #speeds - 1 then
			add("live: Training.MAX_LEVEL %g with WALK_STEP %s, but Balance has %d treadmill levels above 0", maxLevel, tostring(step), #speeds - 1)
		end
	end)
	pcall(function()
		for _, key in ipairs({ "cooldown", "ragdollSeconds", "immunity", "push", "lift" }) do
			local mine, theirs = num(get(config, "bat." .. key)), num(get(live, "bat." .. key))
			if mine and theirs and mine ~= theirs then
				add("live: bat.%s is %g live, %g in Balance (WildboundBatKnock)", key, theirs, mine)
			end
		end
		local stun = num(get(config, "bat.parentStun"))
		if stun and get(live, "bat.parentStun") == nil then
			add("live: bat.parentStun %g has no live constant yet (WildboundBatKnock has none)", stun)
		end
		local immunity, immunityMax = num(get(config, "bat.immunity")), num(get(live, "bat.immunityMax"))
		if immunity and immunityMax and immunity > immunityMax then
			add("live: bat.immunity %g is above the live BatKnock cap %g, so its tune() clamps it", immunity, immunityMax)
		end
	end)
	pcall(function()
		local hatch, slots = num(get(live, "incubator.hatchSeconds")), num(get(live, "incubator.slots"))
		if hatch then
			add("live: the incubator uses one base HATCH_SECONDS %g for every egg and %s slot(s); Balance uses first-egg times, per-rarity times and a second cradle", hatch, tostring(slots))
		end
	end)
	return list
end

local function level(value, count)
	local whole = finite(value) and math.floor(value) or 0
	return math.clamp(whole, 0, math.max(count - 1, 0))
end

-- Walk speed at a treadmill level; the level is floored and clamped to 0..#speeds-1.
function Balance.treadmillSpeed(treadmillLevel, config)
	local speeds = (config or Balance.CONSTANTS).treadmill.speeds
	return speeds[level(treadmillLevel, #speeds) + 1]
end

-- Esencia for the next treadmill level, or nil at the maximum.
function Balance.treadmillCost(treadmillLevel, config)
	local costs = (config or Balance.CONSTANTS).treadmill.costs
	return costs[level(treadmillLevel, #costs) + 2]
end

-- Incubation seconds. previousHatches is 0-based, the saved hatchCount (0 for a new account): 0 and 1 use the fixed
-- first-egg times; later hatches use baseSeconds times the incubator factor times the optional booster factor
-- (0 < booster <= 1, default 1), never under the rarity's minimum. Returns nil for an unknown rarity, a previousHatches
-- that is not a whole number of at least 0, or a booster outside 0 < booster <= 1.
function Balance.incubationSeconds(rarity, previousHatches, upgradeLevel, booster, config)
	local incubation = (config or Balance.CONSTANTS).incubation
	local base, minimum = num(incubation.baseSeconds[rarity]), num(incubation.minSeconds[rarity])
	if base == nil or minimum == nil then return nil end
	if not finite(previousHatches) or previousHatches < 0 or previousHatches % 1 ~= 0 then return nil end
	if booster == nil then booster = 1 end
	if not finite(booster) or booster <= 0 or booster > 1 then return nil end
	if previousHatches == 0 then return incubation.firstEggSeconds end
	if previousHatches == 1 then return incubation.secondEggSeconds end
	local factors = incubation.upgradeFactors
	return math.max(minimum, base * factors[level(upgradeLevel, #factors) + 1] * booster)
end

-- Balance.phaseAt(t) is left for T02.

return freeze(Balance)

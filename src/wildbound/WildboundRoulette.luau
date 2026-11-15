-- Wildbound 2.0 roulette prize table (T09a) and the live hub roulette (PF5, user decision 2026-11-14). CONFIG is the
-- 2.0 proposal (six kinds, mirroring the Balance weights). LIVE is the wired table: the hub station
-- (WildboundRouletteService) rolls only from it, because it grants only what the economy supports today (Esencia and
-- the banked materials). Pure data plus pure rules: no Instance, service, clock or random source. The caller (the
-- server) rolls rng01 in [0, 1) and saves the state this module returns (WildboundRecord schema 6).
-- Esencia only (no Robux, monetization stays "none"). Every percent comes from the 2.0 Balance module roulette.weights
-- (categoryWeights mirrors it; tests/WildboundRoulette_Test.luau and tools/test_wildbound_roulette_sim.py check the
-- mirror). Report: docs/balance/wildbound-2-0-roulette.md (tools/wildbound_roulette_sim.py).
--
-- Prize fields:
--   weight      basis points of 10000 (the shown percent is weight / 100); a category's weights sum to its Balance
--               weight x 100
--   rarity      Comun / Rara / Epica / Legendaria, the pity and the reveal tier
--   value       ASSUMED Esencia-equivalent, for reports only (gloves 1x/2x/4x/8x the 30 Esencia craft, boosters ASSUMED,
--               consumables at shop price, special eggs at the Balance sell price of their rarity)
--   resale      the most Esencia this prize can turn into: Esencia itself, a glove's recycle value (Q8; hub-expansion
--               design 3/6/12/25), a special egg hatched and sold (Balance sell.price), or a consumable's fullEsencia
--   whenFull    the full-inventory policy, so no prize is ever lost: "none" (Esencia has no cap), "pending" (held as a
--               pending claim until there is room) or "convert" (paid as fullEsencia Esencia at once)
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

local function whole(value)
	return finite(value) and value == math.floor(value)
end

local Roulette = {}

Roulette.status = "wired"
Roulette.wired = true

Roulette.RARITIES = freeze({ "Comun", "Rara", "Epica", "Legendaria" })
Roulette.CATEGORIES = freeze({ "esencia", "materials", "gloves", "incubationBoosters", "consumables", "specialEgg" })
Roulette.MATERIALS = freeze({ "fogbark", "glowmoss", "nightbloom" }) -- WildboundEconomyConfig.materials
Roulette.CONSUMABLES = freeze({ "trap", "smoke", "portablePortal" }) -- Balance.CONSUMABLES (2.0 balance module)
Roulette.LOCATIONS = freeze({ "hub", "base" })
Roulette.POLICIES = freeze({ "none", "pending", "convert" })
Roulette.TOTAL = 10000

Roulette.CONFIG = freeze({
	currency = "esencia",
	spinCost = 45, -- Esencia per paid spin (Balance roulette.spinCost)
	freeFirstSpin = true, -- one free spin per account (Balance roulette.freeFirstSpin)
	categoryWeights = { esencia = 35, materials = 25, gloves = 20, incubationBoosters = 12, consumables = 6, specialEgg = 2 },
	-- User: "hub/base". Both allowed until the user picks; T09b wires the station(s).
	locations = { "hub", "base" },
	-- Undecided by the user. Default ON: the 10th paid spin in a row without a Rara-or-better prize draws only from the
	-- Rara-or-better prizes. The free spin neither counts nor resets. See the report for the ON/OFF impact.
	pity = { enabled = true, every = 10, minRarity = "Rara" },
	-- No money loop: the Esencia a spin can turn into (with pity) stays under maxCashShare of the price, and the Esencia
	-- prizes alone under maxEsenciaPerSpin (well below the simulator's 91 break-even). Both ASSUMED caps.
	limits = { maxCashShare = 0.5, maxEsenciaPerSpin = 30 },
	prizes = {
		{ id = "esencia10", category = "esencia", rarity = "Comun", weight = 1600, grant = { esencia = 10 }, value = 10, resale = 10, whenFull = "none", label = "10 de Esencia" },
		{ id = "esencia25", category = "esencia", rarity = "Comun", weight = 1000, grant = { esencia = 25 }, value = 25, resale = 25, whenFull = "none", label = "25 de Esencia" },
		{ id = "esencia45", category = "esencia", rarity = "Rara", weight = 600, grant = { esencia = 45 }, value = 45, resale = 45, whenFull = "none", label = "45 de Esencia" },
		{ id = "esencia90", category = "esencia", rarity = "Epica", weight = 250, grant = { esencia = 90 }, value = 90, resale = 90, whenFull = "none", label = "90 de Esencia" },
		{ id = "esencia200", category = "esencia", rarity = "Legendaria", weight = 50, grant = { esencia = 200 }, value = 200, resale = 200, whenFull = "none", label = "200 de Esencia" },
		{ id = "fogbark10", category = "materials", rarity = "Comun", weight = 1200, grant = { fogbark = 10 }, value = 10, resale = 0, whenFull = "pending", label = "10 Fogbark" },
		{ id = "glowmoss6", category = "materials", rarity = "Comun", weight = 800, grant = { glowmoss = 6 }, value = 12, resale = 0, whenFull = "pending", label = "6 Glowmoss" },
		{ id = "mixedPouch", category = "materials", rarity = "Rara", weight = 350, grant = { fogbark = 10, glowmoss = 5 }, value = 20, resale = 0, whenFull = "pending", label = "10 Fogbark y 5 Glowmoss" },
		{ id = "nightbloom2", category = "materials", rarity = "Rara", weight = 150, grant = { nightbloom = 2 }, value = 10, resale = 0, whenFull = "pending", label = "2 Nightbloom" },
		{ id = "gloveComun", category = "gloves", rarity = "Comun", weight = 1100, grant = { glove = "Comun" }, value = 30, resale = 3, whenFull = "pending", label = "Guante común" },
		{ id = "gloveRara", category = "gloves", rarity = "Rara", weight = 600, grant = { glove = "Rara" }, value = 60, resale = 6, whenFull = "pending", label = "Guante raro" },
		{ id = "gloveEpica", category = "gloves", rarity = "Epica", weight = 250, grant = { glove = "Epica" }, value = 120, resale = 12, whenFull = "pending", label = "Guante épico" },
		{ id = "gloveLegendaria", category = "gloves", rarity = "Legendaria", weight = 50, grant = { glove = "Legendaria" }, value = 250, resale = 25, whenFull = "pending", label = "Guante legendario" },
		{ id = "booster25", category = "incubationBoosters", rarity = "Comun", weight = 700, grant = { incubationBooster = 0.75 }, value = 15, resale = 0, whenFull = "pending", label = "Acelerador de incubación (-25 %)" },
		{ id = "booster50", category = "incubationBoosters", rarity = "Rara", weight = 400, grant = { incubationBooster = 0.5 }, value = 30, resale = 0, whenFull = "pending", label = "Acelerador de incubación (-50 %)" },
		{ id = "booster75", category = "incubationBoosters", rarity = "Epica", weight = 100, grant = { incubationBooster = 0.25 }, value = 60, resale = 0, whenFull = "pending", label = "Acelerador de incubación (-75 %)" },
		{ id = "smoke1", category = "consumables", rarity = "Comun", weight = 300, grant = { smoke = 1 }, value = 40, resale = 20, whenFull = "convert", fullEsencia = 20, label = "Bomba de humo" },
		{ id = "trap1", category = "consumables", rarity = "Comun", weight = 200, grant = { trap = 1 }, value = 60, resale = 30, whenFull = "convert", fullEsencia = 30, label = "Trampa" },
		{ id = "portal1", category = "consumables", rarity = "Rara", weight = 100, grant = { portablePortal = 1 }, value = 125, resale = 60, whenFull = "convert", fullEsencia = 60, label = "Portal portátil" },
		{ id = "eggEpica", category = "specialEgg", rarity = "Epica", weight = 150, grant = { specialEgg = "Epica" }, value = 200, resale = 200, whenFull = "pending", label = "Huevo especial épico" },
		{ id = "eggLegendaria", category = "specialEgg", rarity = "Legendaria", weight = 50, grant = { specialEgg = "Legendaria" }, value = 650, resale = 650, whenFull = "pending", label = "Huevo especial legendario" },
	},
})

-- PF5: the live hub table. Same price, free first spin, Rara+ pity and money-loop caps as CONFIG; re-weighted to the
-- two kinds the economy supports today (Esencia 40, banked materials 60). The Esencia share is lower than CONFIG's
-- 35 of 100 scaled up, because scaling it to 58 would pay about 35 Esencia a spin and break the maxEsenciaPerSpin cap.
-- Banked materials have no cap, so "pending" never holds a live prize back. Report:
-- docs/balance/wildbound-2-0-roulette.md ("Live hub table").
Roulette.LIVE = freeze({
	currency = "esencia",
	spinCost = 45,
	freeFirstSpin = true,
	categoryWeights = { esencia = 40, materials = 60 },
	locations = { "hub" },
	pity = { enabled = true, every = 10, minRarity = "Rara" },
	limits = { maxCashShare = 0.5, maxEsenciaPerSpin = 30 },
	prizes = {
		{ id = "esencia10", category = "esencia", rarity = "Comun", weight = 2000, grant = { esencia = 10 }, value = 10, resale = 10, whenFull = "none", label = "10 de Esencia" },
		{ id = "esencia25", category = "esencia", rarity = "Comun", weight = 1000, grant = { esencia = 25 }, value = 25, resale = 25, whenFull = "none", label = "25 de Esencia" },
		{ id = "esencia45", category = "esencia", rarity = "Rara", weight = 600, grant = { esencia = 45 }, value = 45, resale = 45, whenFull = "none", label = "45 de Esencia" },
		{ id = "esencia90", category = "esencia", rarity = "Epica", weight = 300, grant = { esencia = 90 }, value = 90, resale = 90, whenFull = "none", label = "90 de Esencia" },
		{ id = "esencia200", category = "esencia", rarity = "Legendaria", weight = 100, grant = { esencia = 200 }, value = 200, resale = 200, whenFull = "none", label = "200 de Esencia" },
		{ id = "fogbark10", category = "materials", rarity = "Comun", weight = 2200, grant = { fogbark = 10 }, value = 10, resale = 0, whenFull = "pending", label = "10 Fogbark" },
		{ id = "glowmoss6", category = "materials", rarity = "Comun", weight = 1600, grant = { glowmoss = 6 }, value = 12, resale = 0, whenFull = "pending", label = "6 Glowmoss" },
		{ id = "mixedPouch", category = "materials", rarity = "Rara", weight = 900, grant = { fogbark = 10, glowmoss = 5 }, value = 20, resale = 0, whenFull = "pending", label = "10 Fogbark y 5 Glowmoss" },
		{ id = "nightbloom2", category = "materials", rarity = "Rara", weight = 700, grant = { nightbloom = 2 }, value = 10, resale = 0, whenFull = "pending", label = "2 Nightbloom" },
		{ id = "nightbloom5", category = "materials", rarity = "Epica", weight = 400, grant = { nightbloom = 5 }, value = 25, resale = 0, whenFull = "pending", label = "5 Nightbloom" },
		{ id = "forestChest", category = "materials", rarity = "Legendaria", weight = 200, grant = { fogbark = 40, glowmoss = 20, nightbloom = 5 }, value = 80, resale = 0, whenFull = "pending", label = "Cofre del bosque" },
	},
})

local RANK = {}
for index, name in ipairs(Roulette.RARITIES) do RANK[name] = index end
local function setOf(list)
	local out = {}
	for _, name in ipairs(list) do out[name] = true end
	return out
end
local KNOWN_CATEGORY = setOf(Roulette.CATEGORIES)
local KNOWN_MATERIAL = setOf(Roulette.MATERIALS)
local KNOWN_CONSUMABLE = setOf(Roulette.CONSUMABLES)
local KNOWN_LOCATION = setOf(Roulette.LOCATIONS)
local KNOWN_POLICY = setOf(Roulette.POLICIES)

local function qualifies(prize, minRarity)
	return (RANK[prize.rarity] or 0) >= (RANK[minRarity] or math.huge)
end

local function checkGrant(prize, fail)
	local grant, label = prize.grant, "prize " .. tostring(prize.id)
	if type(grant) ~= "table" or next(grant) == nil then return fail(label .. ": grant missing") end
	local category = prize.category
	for key, amount in pairs(grant) do
		if category == "esencia" then
			if key ~= "esencia" or not whole(amount) or amount <= 0 then fail(label .. ": esencia grant must be { esencia = n > 0 }") end
		elseif category == "materials" then
			if not KNOWN_MATERIAL[key] then fail(label .. ": unknown material " .. tostring(key))
			elseif not whole(amount) or amount <= 0 then fail(label .. ": material " .. key .. " must be a whole number above 0") end
		elseif category == "gloves" then
			if key ~= "glove" or amount ~= prize.rarity then fail(label .. ": glove grant must be { glove = its own rarity }") end
		elseif category == "incubationBoosters" then
			if key ~= "incubationBooster" or not finite(amount) or amount <= 0 or amount >= 1 then
				fail(label .. ": incubation booster factor must be inside (0, 1)")
			end
		elseif category == "consumables" then
			if not KNOWN_CONSUMABLE[key] then fail(label .. ": unknown consumable " .. tostring(key))
			elseif not whole(amount) or amount <= 0 then fail(label .. ": consumable " .. key .. " must be a whole number above 0") end
		elseif category == "specialEgg" then
			if key ~= "specialEgg" or not RANK[amount] then fail(label .. ": special egg grant must be { specialEgg = rarity }") end
		end
	end
end

-- Long-run odds per prize (fractions that sum to 1) and the share of paid spins that are pity spins. With pity the
-- drought counter is a chain over 0..every-1: pi_k = pi_0 (1-q)^k, pi_0 = q / (1 - (1-q)^every), so the pity share is
-- pi_0 (1-q)^(every-1). A pity spin draws from the qualifying prizes in proportion to their weights.
local function effective(config, pity)
	local total, qualifyingTotal = 0, 0
	for _, prize in ipairs(config.prizes) do
		total += prize.weight
		if qualifies(prize, config.pity.minRarity) then qualifyingTotal += prize.weight end
	end
	local share = 0
	if pity and qualifyingTotal > 0 then
		local q = qualifyingTotal / total
		local every = config.pity.every
		share = q * (1 - q) ^ (every - 1) / (1 - (1 - q) ^ every)
	end
	local odds = {}
	for index, prize in ipairs(config.prizes) do
		local p = prize.weight / total
		local boosted = qualifies(prize, config.pity.minRarity) and prize.weight / qualifyingTotal or 0
		odds[index] = (1 - share) * p + share * boosted
	end
	return odds, share
end

local function values(config, pity)
	local odds, share = effective(config, pity)
	local out = { esencia = 0, cash = 0, value = 0, cost = config.spinCost, pitySpinShare = share }
	for index, prize in ipairs(config.prizes) do
		local p = odds[index]
		if prize.category == "esencia" then out.esencia += p * (prize.grant.esencia or 0) end
		out.cash += p * prize.resale
		out.value += p * prize.value
	end
	out.netCash = out.cash - out.cost
	out.netValue = out.value - out.cost
	return out
end

-- validate(config?) -> ok, errors. Reads CONFIG when no config is given.
function Roulette.validate(config)
	config = config or Roulette.CONFIG
	local errors = {}
	local function fail(message) table.insert(errors, message) end
	if type(config) ~= "table" then return false, { "config: not a table" } end
	if config.currency ~= "esencia" then fail("currency: the roulette is Esencia-only") end
	if not whole(config.spinCost) or config.spinCost <= 0 then fail("spinCost: must be a whole number above 0") end
	if type(config.freeFirstSpin) ~= "boolean" then fail("freeFirstSpin: not a boolean") end
	local pity = config.pity
	if type(pity) ~= "table" or type(pity.enabled) ~= "boolean" or not whole(pity.every) or pity.every < 2
		or not RANK[pity.minRarity] then
		fail("pity: needs enabled (boolean), every (whole, at least 2) and a known minRarity")
	end
	local locations = config.locations
	if type(locations) ~= "table" or #locations == 0 then fail("locations: at least one location (hub or base)")
	else
		for _, name in ipairs(locations) do
			if not KNOWN_LOCATION[name] then fail("locations: unknown location " .. tostring(name)) end
		end
	end
	local limits = config.limits
	if type(limits) ~= "table" or not finite(limits.maxCashShare) or not finite(limits.maxEsenciaPerSpin) then
		fail("limits: maxCashShare and maxEsenciaPerSpin required")
	end
	local weights = config.categoryWeights
	if type(weights) ~= "table" then fail("categoryWeights: not a table"); weights = {} end
	for name in pairs(weights) do
		if not KNOWN_CATEGORY[name] then fail("categoryWeights: unknown category " .. tostring(name)) end
	end
	local prizes = config.prizes
	if type(prizes) ~= "table" or #prizes == 0 then
		fail("prizes: none")
		return false, errors
	end
	local seen, sums, total = {}, {}, 0
	for index, prize in ipairs(prizes) do
		local label = "prize " .. tostring(prize.id or index)
		if type(prize.id) ~= "string" then fail("prize " .. index .. ": id missing")
		elseif seen[prize.id] then fail(label .. ": duplicate id") end
		if type(prize.id) == "string" then seen[prize.id] = true end
		if not KNOWN_CATEGORY[prize.category] then fail(label .. ": unknown category " .. tostring(prize.category)) end
		if not RANK[prize.rarity] then fail(label .. ": unknown rarity " .. tostring(prize.rarity)) end
		if not whole(prize.weight) or prize.weight <= 0 then fail(label .. ": weight must be a whole number above 0")
		else
			sums[prize.category] = (sums[prize.category] or 0) + prize.weight
			total += prize.weight
		end
		if not finite(prize.value) or prize.value < 0 then fail(label .. ": value must be at least 0") end
		if not finite(prize.resale) or prize.resale < 0 then fail(label .. ": resale must be at least 0") end
		if type(prize.label) ~= "string" or prize.label == "" then fail(label .. ": label missing") end
		checkGrant(prize, fail)
		if prize.category == "esencia" and type(prize.grant) == "table" and prize.resale ~= prize.grant.esencia then
			fail(label .. ": an Esencia prize resells for exactly its amount")
		end
		local policy = prize.whenFull
		if not KNOWN_POLICY[policy] then fail(label .. ": whenFull must be none, pending or convert (no prize is lost)")
		elseif prize.category == "esencia" and policy ~= "none" then fail(label .. ": whenFull of Esencia is none (no cap)")
		elseif prize.category ~= "esencia" and policy == "none" then fail(label .. ": whenFull none is only for Esencia")
		end
		if policy == "convert" then
			if not whole(prize.fullEsencia) or prize.fullEsencia <= 0 then fail(label .. ": convert needs fullEsencia above 0")
			elseif finite(prize.resale) and prize.fullEsencia > prize.resale then fail(label .. ": fullEsencia above its resale") end
		elseif prize.fullEsencia ~= nil then
			fail(label .. ": fullEsencia only goes with whenFull convert")
		end
	end
	for _, name in ipairs(Roulette.CATEGORIES) do
		local want = (weights[name] or 0) * 100
		if (sums[name] or 0) ~= want then
			fail(string.format("%s: prize weights sum %d, category weight x 100 is %d", name, sums[name] or 0, want))
		end
	end
	if total ~= Roulette.TOTAL then fail(string.format("prizes: weights sum %d, not %d", total, Roulette.TOTAL)) end
	if #errors == 0 and type(pity) == "table" then
		local anyQualifying = false
		for _, prize in ipairs(prizes) do if qualifies(prize, pity.minRarity) then anyQualifying = true end end
		if not anyQualifying then fail("pity: no prize at or above " .. tostring(pity.minRarity)) end
	end
	if #errors == 0 then
		local worst = values(config, true)
		if worst.cash >= config.spinCost * limits.maxCashShare then
			fail(string.format("money loop: a spin turns into %.2f Esencia, cap %.2f", worst.cash, config.spinCost * limits.maxCashShare))
		end
		if worst.esencia >= limits.maxEsenciaPerSpin then
			fail(string.format("money loop: Esencia prizes pay %.2f per spin, cap %.2f", worst.esencia, limits.maxEsenciaPerSpin))
		end
	end
	return #errors == 0, errors
end

function Roulette.newState()
	return { freeSpinUsed = false, pityCount = 0, paidSpins = 0 }
end

local function validState(state)
	return type(state) == "table" and type(state.freeSpinUsed) == "boolean" and whole(state.pityCount)
		and state.pityCount >= 0 and whole(state.paidSpins) and state.paidSpins >= 0
end

-- draw(rng01, state, config?) -> prize, newState, receipt { cost, free, pity }. rng01 is in [0, 1); the prize is the
-- first one whose cumulative weight exceeds floor(rng01 * pool total). The input state is never changed. On bad input:
-- nil, the same state, an error text.
function Roulette.draw(rng01, state, config)
	config = config or Roulette.CONFIG
	if not finite(rng01) or rng01 < 0 or rng01 >= 1 then return nil, state, "rng01 must be a number in [0, 1)" end
	if not validState(state) then return nil, state, "state must be { freeSpinUsed, pityCount, paidSpins }" end
	local free = config.freeFirstSpin == true and not state.freeSpinUsed
	local pityOn = not free and config.pity.enabled == true and state.pityCount >= config.pity.every - 1
	local total = 0
	for _, prize in ipairs(config.prizes) do
		if not pityOn or qualifies(prize, config.pity.minRarity) then total += prize.weight end
	end
	local pick, chosen = math.floor(rng01 * total), nil
	for _, prize in ipairs(config.prizes) do
		if not pityOn or qualifies(prize, config.pity.minRarity) then
			pick -= prize.weight
			if pick < 0 then chosen = prize; break end
		end
	end
	local nextState = { freeSpinUsed = state.freeSpinUsed, pityCount = state.pityCount, paidSpins = state.paidSpins }
	if free then
		nextState.freeSpinUsed = true
	else
		nextState.paidSpins += 1
		nextState.pityCount = qualifies(chosen, config.pity.minRarity) and 0 or state.pityCount + 1
	end
	return chosen, nextState, { cost = free and 0 or config.spinCost, free = free, pity = pityOn }
end

-- oddsTable(config?, withPity?) -> { prizes = { {id, category, rarity, label, percent} }, byRarity, byCategory, pity,
-- pitySpinShare }. Without withPity the percents are the declared weights / 100 (what the UI shows); with it they are
-- the long-run odds of a paid spin under pity.
function Roulette.oddsTable(config, withPity)
	config = config or Roulette.CONFIG
	local odds, share = effective(config, withPity == true)
	local out = { prizes = {}, byRarity = {}, byCategory = {}, pitySpinShare = share,
		pity = { enabled = config.pity.enabled, every = config.pity.every, minRarity = config.pity.minRarity } }
	for _, name in ipairs(Roulette.RARITIES) do out.byRarity[name] = 0 end
	for _, name in ipairs(Roulette.CATEGORIES) do out.byCategory[name] = 0 end
	for index, prize in ipairs(config.prizes) do
		local percent = odds[index] * 100
		table.insert(out.prizes, { id = prize.id, category = prize.category, rarity = prize.rarity, label = prize.label, percent = percent })
		out.byRarity[prize.rarity] += percent
		out.byCategory[prize.category] += percent
	end
	return out
end

-- expectedValue(config?, pity?) -> { esencia, cash, value, cost, netCash, netValue, pitySpinShare } per paid spin.
-- pity defaults to config.pity.enabled. esencia counts the Esencia prizes only; cash adds every resale path.
function Roulette.expectedValue(config, pity)
	config = config or Roulette.CONFIG
	if pity == nil then pity = config.pity.enabled == true end
	return values(config, pity)
end

-- allowedAt(location, config?) -> true when the roulette may open at that location ("hub" or "base").
function Roulette.allowedAt(location, config)
	config = config or Roulette.CONFIG
	for _, name in ipairs(config.locations) do
		if name == location then return true end
	end
	return false
end

return Roulette

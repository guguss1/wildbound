-- Pure economy rules (M5.2, M5.5, wave W7). No services, clock, RNG, persistence or state of its own.
-- Every number comes from the generated tuning copy (WildboundEconomyConfig), passed in as `config`,
-- so docs/mechanics/wildbound-economy-p0.md stays the single source. Integers only for amounts.
local Economy = {}

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function count(value)
	return finite(value) and value >= 0 and value % 1 == 0
end
Economy.isCount = count

-- What a defeat takes from one carried stack: nearest unit, halves up, integer arithmetic only.
function Economy.lost(quantity, basisPoints)
	if not count(quantity) or not count(basisPoints) or basisPoints > 10000 then return 0 end
	return (quantity * basisPoints + 5000) // 10000
end

-- Materials that travel in the pouch, in a stable order. Bag materials (Nightbloom) are not listed.
function Economy.pouchMaterials(config)
	local list = {}
	for name, spec in pairs(config.materials) do
		if spec.carriedAs == "pouch" then table.insert(list, name) end
	end
	table.sort(list)
	return list
end

-- Every material, pouch or bag, in a stable order.
function Economy.materials(config)
	local list = {}
	for name in pairs(config.materials) do table.insert(list, name) end
	table.sort(list)
	return list
end

local function owned(config, upgrades, key)
	local values = {}
	for name, spec in pairs(config.upgrades) do
		if type(upgrades) == "table" and upgrades[name] == true and spec.effects[key] ~= nil then
			table.insert(values, spec.effects[key])
		end
	end
	return values
end

function Economy.bagCapacity(config, upgrades)
	local values = owned(config, upgrades, "bagItems")
	return #values > 0 and math.max(table.unpack(values)) or config.capacity.bagItems
end

function Economy.pouchCapacity(config, upgrades)
	local values = owned(config, upgrades, "pouchUnits")
	return #values > 0 and math.max(table.unpack(values)) or config.capacity.pouchUnits
end

function Economy.lossBasisPoints(config, upgrades)
	local values = owned(config, upgrades, "lossBasisPoints")
	return #values > 0 and math.min(table.unpack(values)) or config.loss.rateBasisPoints
end

-- Walk speed for a pouch load. Steps apply from their share upward.
function Economy.pouchSpeed(config, units, capacity)
	local speed = config.carry.baseSpeed
	if not count(units) or not finite(capacity) or capacity <= 0 then return speed end
	local share = units / capacity
	for _, step in ipairs(config.carry.pouchLoadSteps) do
		if share >= step.atShare then speed = step.speed end
	end
	return speed
end

-- Effect keys that are applied today (M5.6). A skill can be learned only when every effect it names is here,
-- so a player never pays for something that does nothing yet.
Economy.LIVE_EFFECTS = table.freeze({ nodeHintRange = true, nightbloomHintRange = true, carrySpeedBonus = true })

-- The effects of the skills a player owns: numbers take the highest owned value, flags are kept.
function Economy.skillEffects(config, skills)
	local effects = {}
	if type(skills) ~= "table" then return effects end
	for name, spec in pairs(config.skills) do
		if skills[name] == true then
			for key, value in pairs(spec.effects) do
				if type(value) == "number" then effects[key] = math.max(effects[key] or value, value) else effects[key] = value end
			end
		end
	end
	return effects
end

-- Bond level (1 to 5) for banked XP.
function Economy.bondLevel(config, xp)
	if not count(xp) then return 1 end
	local level = 1
	for index, threshold in ipairs(config.bond.levelThresholdsXp) do
		if xp >= threshold then level = index end
	end
	return level
end

-- The slower of the pouch step and the egg speed from the capture rules. Light Load adds to the egg speed
-- only, never past the base speed, so a loaded player still outruns Silueta.
function Economy.carrySpeed(config, units, capacity, eggSpeed, skills)
	local pouch = Economy.pouchSpeed(config, units, capacity)
	if not finite(eggSpeed) then return pouch end
	local bonus = Economy.skillEffects(config, skills).carrySpeedBonus
	if bonus and eggSpeed < config.carry.baseSpeed then eggSpeed = math.min(config.carry.baseSpeed, eggSpeed + bonus) end
	if eggSpeed < pouch then return eggSpeed end
	return pouch
end

-- Ember for one bag item, read from the tier stored on it at capture. Nightbloom pays none.
function Economy.itemEmber(config, item)
	if type(item) ~= "table" or type(item.riskTier) ~= "string" then return 0 end
	local table_ = item.kind == "Creature" and config.earn.creatureEmberByTier
		or item.kind == "Egg" and config.earn.eggEmberByTier or nil
	return table_ and table_[item.riskTier] or 0
end

-- The completed-trip Ember: long enough, far enough and something new.
function Economy.baseEmber(config, seconds, maxDistance, newCount)
	local need = config.earn.baseRequires
	if finite(seconds) and finite(maxDistance) and count(newCount)
		and seconds >= need.minExpeditionSeconds and maxDistance >= need.minDistanceFromCamp
		and newCount >= need.minNewUnitsOrItems then
		return config.earn.extractBaseEmber
	end
	return 0
end

-- `wallet` is { ember = n, banked = { material = n } }. Costs name Ember or banked materials only.
function Economy.canPay(wallet, cost)
	if type(wallet) ~= "table" or type(cost) ~= "table" then return false end
	for key, amount in pairs(cost) do
		local have = key == "ember" and wallet.ember or (wallet.banked or {})[key]
		if not count(amount) or not count(have) or have < amount then return false end
	end
	return true
end

-- Only after canPay. Never makes a balance negative.
function Economy.pay(wallet, cost)
	assert(Economy.canPay(wallet, cost), "Economy.pay without canPay")
	for key, amount in pairs(cost) do
		if key == "ember" then wallet.ember -= amount else wallet.banked[key] -= amount end
	end
end

-- Totem downside (M5.5): Silueta senses the holder from farther. Chase range is not changed.
function Economy.detectionRange(config, base, totemActive)
	if not finite(base) then return base end
	return totemActive == true and base + config.totem.detectionBonusStuds or base
end

-- Invariants the rules rely on. Returns a list of problems; empty means the config is usable.
function Economy.validate(config)
	local problems = {}
	local function problem(text) table.insert(problems, text) end
	if type(config) ~= "table" then return { "config is not a table" } end
	if config.monetization ~= "none" then problem("monetization is not none") end
	if config.currency.purchasable ~= false or config.currency.lostOnDefeat ~= false then
		problem("Ember must never be bought or lost")
	end
	if config.loss.rounding ~= "nearest_half_up_per_stack" then problem("unsupported loss rounding") end
	for _, bp in ipairs({ config.loss.rateBasisPoints, config.loss.rateBasisPointsReinforced }) do
		if not count(bp) or bp > 10000 then problem("loss rate out of range") end
	end
	local phaseTotal = 0
	for _, phase in ipairs(config.cycle.phaseOrder) do phaseTotal += config.cycle.phases[phase] or 0 end
	if phaseTotal ~= config.cycle.seconds then problem("phases do not sum to the cycle") end
	for zone, phases in pairs(config.spawnWeights) do
		for phase, weights in pairs(phases) do
			local total = 0
			for material, weight in pairs(weights) do
				if not finite(weight) or weight < 0 then problem(zone .. "/" .. phase .. " has a bad weight") end
				total += finite(weight) and weight or 0
				if config.materials[material] == nil then problem(zone .. "/" .. phase .. " names " .. material) end
				if config.materials[material] and config.materials[material].nightOnly and phase ~= "Night" then
					problem(material .. " outside Night in " .. zone)
				end
				local range = config.yields[zone] and config.yields[zone][material]
				if not range or range[1] > range[2] or range[1] < 0 then problem("no yield for " .. zone .. "/" .. material) end
			end
			if total <= 0 then problem(zone .. "/" .. phase .. " sums to zero") end
		end
	end
	local base = config.carry.baseSpeed
	for _, step in ipairs(config.carry.pouchLoadSteps) do
		if step.speed > base then problem("a load step is faster than the one before") end
		base = step.speed
	end
	for name, recipe in pairs(config.recipes) do
		if config.capacity.consumableCaps[name] == nil then problem("recipe " .. name .. " has no cap") end
		for key, amount in pairs(recipe.cost) do
			if not count(amount) or (key ~= "ember" and config.materials[key] == nil) then problem("bad cost in " .. name) end
		end
	end
	for name, skill in pairs(config.skills) do
		if type(skill.effectLive) ~= "boolean" then problem(name .. " does not say whether its effect is built") end
		if skill.effectLive == true then
			for key in pairs(skill.effects) do
				if not Economy.LIVE_EFFECTS[key] then problem(name .. " claims an effect that is not applied yet: " .. key) end
			end
		end
	end
	local holds = config.gather.holdSeconds
	if not (holds.outside < holds.fog and holds.fog < holds.territory and holds.territory < holds.heart) then
		problem("holds must grow outside, fog, territory, heart")
	end
	return problems
end

return Economy

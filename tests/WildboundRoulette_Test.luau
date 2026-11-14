-- Invoke with require(freshTestClone)(require(freshRouletteClone), require(freshBalanceClone)).
-- Wildbound 2.0 roulette prize table (T09a, odd/tasks/wildbound-2-0.md): the unwired, pure Esencia-only roulette.
-- Pins every prize, its odds against the WildboundBalance category weights, the free first spin, the 45 Esencia price,
-- the configurable pity, the full-inventory policy, the hub/base location config, the deterministic draw and the
-- expected values. tools/test_wildbound_roulette_sim.py pins the same numbers from the Python mirror.
return function(Roulette, Balance)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function near(actual, expected, eps, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (eps or 1e-9),
			(label and label .. ": " or "") .. "expected about " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function copy(value)
		if type(value) ~= "table" then return value end
		local out = {}
		for key, child in pairs(value) do out[key] = copy(child) end
		return out
	end
	local function fresh()
		return copy(Roulette.CONFIG)
	end
	local function prizeIn(config, id)
		for _, prize in ipairs(config.prizes) do if prize.id == id then return prize end end
		return nil
	end
	local function fails(config, label, needle)
		local ran, ok, errors = pcall(Roulette.validate, config)
		assert(ran, label .. ": validate threw: " .. tostring(ok))
		assert(ok == false, label .. ": expected validation to fail")
		assert(type(errors) == "table" and #errors > 0, label .. ": expected errors listed")
		local text = table.concat(errors, " | ")
		assert(text:lower():find(needle, 1, true), label .. ": no error mentions " .. needle .. ": " .. text)
	end
	local function passes(config, label)
		local ran, ok, errors = pcall(Roulette.validate, config)
		assert(ran, label .. ": validate threw: " .. tostring(ok))
		assert(ok == true, label .. ": expected validation to pass: " .. table.concat(errors or {}, " | "))
	end

	-- id, category, rarity, weight (basis points of 10000), value (assumed Esencia-equivalent), resale (Esencia it can
	-- turn into), whenFull, fullEsencia
	local EXPECTED = {
		{ "esencia10", "esencia", "Comun", 1600, 10, 10, "none", 0 },
		{ "esencia25", "esencia", "Comun", 1000, 25, 25, "none", 0 },
		{ "esencia45", "esencia", "Rara", 600, 45, 45, "none", 0 },
		{ "esencia90", "esencia", "Epica", 250, 90, 90, "none", 0 },
		{ "esencia200", "esencia", "Legendaria", 50, 200, 200, "none", 0 },
		{ "fogbark10", "materials", "Comun", 1200, 10, 0, "pending", 0 },
		{ "glowmoss6", "materials", "Comun", 800, 12, 0, "pending", 0 },
		{ "mixedPouch", "materials", "Rara", 350, 20, 0, "pending", 0 },
		{ "nightbloom2", "materials", "Rara", 150, 10, 0, "pending", 0 },
		{ "gloveComun", "gloves", "Comun", 1100, 30, 3, "pending", 0 },
		{ "gloveRara", "gloves", "Rara", 600, 60, 6, "pending", 0 },
		{ "gloveEpica", "gloves", "Epica", 250, 120, 12, "pending", 0 },
		{ "gloveLegendaria", "gloves", "Legendaria", 50, 250, 25, "pending", 0 },
		{ "booster25", "incubationBoosters", "Comun", 700, 15, 0, "pending", 0 },
		{ "booster50", "incubationBoosters", "Rara", 400, 30, 0, "pending", 0 },
		{ "booster75", "incubationBoosters", "Epica", 100, 60, 0, "pending", 0 },
		{ "smoke1", "consumables", "Comun", 300, 40, 20, "convert", 20 },
		{ "trap1", "consumables", "Comun", 200, 60, 30, "convert", 30 },
		{ "portal1", "consumables", "Rara", 100, 125, 60, "convert", 60 },
		{ "eggEpica", "specialEgg", "Epica", 150, 200, 200, "pending", 0 },
		{ "eggLegendaria", "specialEgg", "Legendaria", 50, 650, 650, "pending", 0 },
	}

	case("R1: the module is pure, unwired data and the default config validates", function()
		equal(Roulette.status, "proposed", "status")
		equal(Roulette.wired, false, "wired")
		assert(type(Roulette.CONFIG) == "table" and table.isfrozen(Roulette.CONFIG), "CONFIG frozen")
		for _, name in ipairs({ "validate", "draw", "oddsTable", "expectedValue", "newState", "allowedAt" }) do
			assert(type(Roulette[name]) == "function", "missing function " .. name)
		end
		passes(fresh(), "default config")
		local ok, errors = Roulette.validate()
		assert(ok == true, "validate() with no argument reads CONFIG: " .. table.concat(errors or {}, " | "))
	end)

	case("R2: every exact prize, in order, with rarity, weight, value, resale and full-inventory policy", function()
		local prizes = Roulette.CONFIG.prizes
		equal(#prizes, #EXPECTED, "prize count")
		for index, row in ipairs(EXPECTED) do
			local prize = prizes[index]
			local label = "prize " .. index
			equal(prize.id, row[1], label .. " id")
			equal(prize.category, row[2], label .. " category")
			equal(prize.rarity, row[3], label .. " rarity")
			equal(prize.weight, row[4], label .. " weight")
			equal(prize.value, row[5], label .. " value")
			equal(prize.resale, row[6], label .. " resale")
			equal(prize.whenFull, row[7], label .. " whenFull")
			equal(prize.fullEsencia or 0, row[8], label .. " fullEsencia")
			assert(type(prize.label) == "string" and #prize.label > 0, label .. ": Spanish label missing")
			assert(type(prize.grant) == "table", label .. ": grant missing")
		end
	end)

	case("R3: the grants (Esencia, the three materials, glove rarity, booster factor, consumables, special egg)", function()
		local c = Roulette.CONFIG
		equal(prizeIn(c, "esencia200").grant.esencia, 200, "esencia200")
		equal(prizeIn(c, "fogbark10").grant.fogbark, 10, "fogbark10")
		equal(prizeIn(c, "glowmoss6").grant.glowmoss, 6, "glowmoss6")
		equal(prizeIn(c, "mixedPouch").grant.fogbark, 10, "mixedPouch fogbark")
		equal(prizeIn(c, "mixedPouch").grant.glowmoss, 5, "mixedPouch glowmoss")
		equal(prizeIn(c, "nightbloom2").grant.nightbloom, 2, "nightbloom2")
		equal(prizeIn(c, "gloveEpica").grant.glove, "Epica", "gloveEpica")
		near(prizeIn(c, "booster25").grant.incubationBooster, 0.75, 1e-12, "booster25")
		near(prizeIn(c, "booster50").grant.incubationBooster, 0.5, 1e-12, "booster50")
		near(prizeIn(c, "booster75").grant.incubationBooster, 0.25, 1e-12, "booster75")
		equal(prizeIn(c, "smoke1").grant.smoke, 1, "smoke1")
		equal(prizeIn(c, "trap1").grant.trap, 1, "trap1")
		equal(prizeIn(c, "portal1").grant.portablePortal, 1, "portal1")
		equal(prizeIn(c, "eggLegendaria").grant.specialEgg, "Legendaria", "eggLegendaria")
	end)

	case("R4: category totals equal WildboundBalance roulette.weights x 100, and the price and free spin match", function()
		local weights = Balance.CONSTANTS.roulette.weights
		local sums = {}
		for _, prize in ipairs(Roulette.CONFIG.prizes) do sums[prize.category] = (sums[prize.category] or 0) + prize.weight end
		for _, name in ipairs(Balance.ROULETTE_CATEGORIES) do
			equal(sums[name], weights[name] * 100, "category " .. name)
			equal(Roulette.CONFIG.categoryWeights[name], weights[name], "mirror " .. name)
		end
		for name in pairs(sums) do assert(weights[name] ~= nil, "unknown category " .. name) end
		equal(Roulette.CONFIG.spinCost, 45, "spinCost")
		equal(Roulette.CONFIG.spinCost, Balance.CONSTANTS.roulette.spinCost, "spinCost vs Balance")
		equal(Roulette.CONFIG.freeFirstSpin, Balance.CONSTANTS.roulette.freeFirstSpin, "freeFirstSpin vs Balance")
		equal(Roulette.CONFIG.currency, "esencia", "Esencia-only")
	end)

	case("R5: oddsTable() lists every prize with its percent (sum 100) and the rarity totals", function()
		local odds = Roulette.oddsTable()
		equal(#odds.prizes, 21, "rows")
		local sum = 0
		for index, row in ipairs(odds.prizes) do
			equal(row.id, EXPECTED[index][1], "row " .. index)
			near(row.percent, EXPECTED[index][4] / 100, 1e-9, row.id .. " percent")
			assert(type(row.label) == "string", row.id .. " label")
			sum += row.percent
		end
		near(sum, 100, 1e-9, "percent sum")
		near(odds.byRarity.Comun, 69, 1e-9, "Comun")
		near(odds.byRarity.Rara, 22, 1e-9, "Rara")
		near(odds.byRarity.Epica, 7.5, 1e-9, "Epica")
		near(odds.byRarity.Legendaria, 1.5, 1e-9, "Legendaria")
		near(odds.byCategory.esencia, 35, 1e-9, "esencia")
		near(odds.byCategory.specialEgg, 2, 1e-9, "specialEgg")
		equal(odds.pity.every, 10, "pity every")
		equal(odds.pity.minRarity, "Rara", "pity minRarity")
		equal(odds.pity.enabled, true, "pity enabled")
	end)

	case("R6: oddsTable(config, true) gives the long-run odds with pity, still summing to 100", function()
		local odds = Roulette.oddsTable(nil, true)
		local sum = 0
		for _, row in ipairs(odds.prizes) do sum += row.percent end
		near(sum, 100, 1e-9, "sum")
		-- q = 0.31, pity share = q (1-q)^9 / (1 - (1-q)^10)
		local q = 0.31
		local share = q * (1 - q) ^ 9 / (1 - (1 - q) ^ 10)
		near(odds.pitySpinShare, share, 1e-12, "pity spin share")
		near(odds.prizes[1].percent, 16 * (1 - share), 1e-9, "esencia10 (not in the pity pool)")
		near(odds.prizes[3].percent, 6 * (1 - share) + 100 * share * 600 / 3100, 1e-9, "esencia45 (in the pity pool)")
	end)

	case("R7: draw() is deterministic: the free first spin, then paid spins by cumulative basis points", function()
		local state = Roulette.newState()
		equal(state.freeSpinUsed, false, "new freeSpinUsed")
		equal(state.pityCount, 0, "new pityCount")
		equal(state.paidSpins, 0, "new paidSpins")
		local prize, nextState, receipt = Roulette.draw(0.0, state)
		equal(prize.id, "esencia10", "rng 0")
		equal(receipt.cost, 0, "free cost")
		equal(receipt.free, true, "free flag")
		equal(nextState.freeSpinUsed, true, "free used")
		equal(nextState.pityCount, 0, "free spin leaves pity alone")
		equal(nextState.paidSpins, 0, "free spin is not paid")
		equal(state.freeSpinUsed, false, "the input state is not mutated")
		local expectations = { { 0.1599, "esencia10" }, { 0.16, "esencia25" }, { 0.3455, "esencia200" }, { 0.5, "glowmoss6" },
			{ 0.62, "gloveComun" }, { 0.7975, "gloveLegendaria" }, { 0.915, "booster75" }, { 0.975, "portal1" },
			{ 0.9999, "eggLegendaria" } }
		for _, pair in ipairs(expectations) do
			local p, s, r = Roulette.draw(pair[1], nextState)
			equal(p.id, pair[2], "rng " .. pair[1])
			equal(r.cost, 45, "paid cost")
			equal(r.free, false, "paid flag")
			equal(s.paidSpins, nextState.paidSpins + 1, "paidSpins")
		end
	end)

	case("R8: pity ON: the 10th paid spin in a row without Rara or better draws from the Rara+ pool", function()
		local state = select(2, Roulette.draw(0.0, Roulette.newState()))
		for spin = 1, 9 do
			local prize
			prize, state = Roulette.draw(0.0, state)
			equal(prize.id, "esencia10", "miss " .. spin)
		end
		equal(state.pityCount, 9, "count before the 10th")
		local prize, after, receipt = Roulette.draw(0.0, state)
		equal(prize.id, "esencia45", "pity pool at rng 0")
		equal(receipt.pity, true, "pity flag")
		equal(after.pityCount, 0, "reset")
		local pooled = Roulette.draw(0.5, state)
		equal(pooled.id, "gloveRara", "pity pool at rng 0.5 (1550 of 3100)")
		local afterFree = select(2, Roulette.draw(0.0, Roulette.newState()))
		local hit, reset = Roulette.draw(0.27, afterFree)
		equal(hit.id, "esencia45", "a natural Rara")
		equal(reset.pityCount, 0, "a natural Rara resets")
	end)

	case("R9: pity OFF: the 10th spin uses the full table and the drought counter keeps going", function()
		local config = fresh()
		config.pity.enabled = false
		local state = select(2, Roulette.draw(0.0, Roulette.newState(), config))
		for _ = 1, 9 do state = select(2, Roulette.draw(0.0, state, config)) end
		local prize, after, receipt = Roulette.draw(0.0, state, config)
		equal(prize.id, "esencia10", "no pity")
		equal(receipt.pity, false, "pity flag")
		equal(after.pityCount, 10, "drought")
		local tuned = fresh()
		tuned.pity.minRarity = "Epica"
		local s = select(2, Roulette.draw(0.0, Roulette.newState(), tuned))
		for _ = 1, 9 do s = select(2, Roulette.draw(0.27, s, tuned)) end -- esencia45 is Rara: not enough for Epica
		equal(s.pityCount, 9, "Rara does not reset an Epica pity")
		local epic = Roulette.draw(0.0, s, tuned)
		equal(epic.id, "esencia90", "Epica+ pool at rng 0")
	end)

	case("R10: draw() refuses a bad rng or state without changing anything", function()
		local state = Roulette.newState()
		for _, bad in ipairs({ -0.1, 1, 1.5, 0 / 0, math.huge }) do
			local prize, same, err = Roulette.draw(bad, state)
			equal(prize, nil, "rng " .. tostring(bad))
			equal(same, state, "state returned unchanged")
			assert(type(err) == "string", "error text")
		end
		local prize, _, err = Roulette.draw("x", state)
		equal(prize, nil, "string rng")
		assert(type(err) == "string", "string rng error")
		local p2, _, e2 = Roulette.draw(0.5, { freeSpinUsed = true, pityCount = -1, paidSpins = 0 })
		equal(p2, nil, "negative pityCount")
		assert(type(e2) == "string", "state error")
		local p3, _, e3 = Roulette.draw(0.5, nil)
		equal(p3, nil, "nil state")
		assert(type(e3) == "string", "nil state error")
	end)

	case("R11: expectedValue() pity OFF and ON (cash = Esencia it can turn into; value = assumed equivalent)", function()
		local off = Roulette.expectedValue(nil, false)
		near(off.esencia, 10.05, 1e-9, "off esencia")
		near(off.cash, 19.215, 1e-9, "off cash")
		near(off.value, 36.96, 1e-9, "off value")
		equal(off.cost, 45, "cost")
		near(off.netCash, 19.215 - 45, 1e-9, "off net cash")
		near(off.pitySpinShare, 0, 1e-12, "off share")
		local on = Roulette.expectedValue(nil, true)
		near(on.esencia, 10.153008736565770, 1e-9, "on esencia")
		near(on.cash, 19.492222330422116, 1e-9, "on cash")
		near(on.value, 37.413987066739885, 1e-9, "on value")
		local default = Roulette.expectedValue()
		near(default.cash, on.cash, 1e-12, "default follows CONFIG.pity.enabled (ON)")
		local epic = fresh()
		epic.pity.minRarity = "Epica"
		local e = Roulette.expectedValue(epic, true)
		near(e.cash, 24.95894930901911, 1e-9, "Epica pity cash")
		near(e.value, 44.68592773030853, 1e-9, "Epica pity value")
	end)

	case("R12: no money loop: cash EV with pity stays under the cap share of the price, Esencia EV well under 90", function()
		local limits = Roulette.CONFIG.limits
		near(limits.maxCashShare, 0.5, 1e-12, "maxCashShare")
		equal(limits.maxEsenciaPerSpin, 30, "maxEsenciaPerSpin")
		local on = Roulette.expectedValue(nil, true)
		assert(on.cash < Roulette.CONFIG.spinCost * limits.maxCashShare, "cash EV " .. on.cash)
		assert(on.esencia < limits.maxEsenciaPerSpin, "esencia EV " .. on.esencia)
		local loop = fresh()
		prizeIn(loop, "esencia10").grant.esencia = 100
		prizeIn(loop, "esencia10").value = 100
		prizeIn(loop, "esencia10").resale = 100
		fails(loop, "esencia10 at 100", "money loop")
		local resold = fresh()
		prizeIn(resold, "gloveComun").resale = 120
		fails(resold, "gloves resold at 120", "money loop")
	end)

	case("R13: validate() catches broken tables", function()
		local c = fresh(); c.prizes[1].weight = 1601
		fails(c, "esencia weight drift", "esencia")
		c = fresh(); c.categoryWeights.esencia = 36; c.categoryWeights.materials = 24
		fails(c, "category mirror changed without prizes", "esencia")
		c = fresh(); c.prizes[2].id = "esencia10"
		fails(c, "duplicate id", "duplicate")
		c = fresh(); c.prizes[1].rarity = "Mitica"
		fails(c, "unknown rarity", "rarity")
		c = fresh(); c.prizes[6].grant = { iron = 3 }
		fails(c, "unknown material", "iron")
		c = fresh(); c.prizes[10].grant.glove = "Rara"
		fails(c, "glove rarity mismatch", "glove")
		c = fresh(); c.prizes[14].grant.incubationBooster = 1.2
		fails(c, "booster above 1", "booster")
		c = fresh(); c.prizes[17].grant = { bomb = 1 }
		fails(c, "unknown consumable", "bomb")
		c = fresh(); c.prizes[1].weight = 0; c.prizes[2].weight = 2600
		fails(c, "zero weight", "weight")
		c = fresh(); c.spinCost = 0
		fails(c, "spinCost 0", "spincost")
		c = fresh(); c.pity.every = 1
		fails(c, "pity every 1", "pity")
		c = fresh(); c.pity.minRarity = "Mitica"
		fails(c, "pity rarity", "pity")
		c = fresh(); c.currency = "robux"
		fails(c, "not Esencia-only", "currency")
	end)

	case("R14: no prize is ever lost: each prize names a full-inventory policy and conversions are stated", function()
		local c = fresh(); c.prizes[10].whenFull = nil
		fails(c, "glove with no policy", "whenfull")
		c = fresh(); c.prizes[10].whenFull = "discard"
		fails(c, "discard policy", "whenfull")
		c = fresh(); c.prizes[1].whenFull = "pending"
		fails(c, "esencia must be none", "whenfull")
		c = fresh(); c.prizes[6].whenFull = "none"
		fails(c, "material none", "whenfull")
		c = fresh(); c.prizes[17].fullEsencia = nil
		fails(c, "convert without a rate", "fullesencia")
		c = fresh(); c.prizes[17].fullEsencia = 25
		fails(c, "convert rate above resale", "fullesencia")
		for _, prize in ipairs(Roulette.CONFIG.prizes) do
			assert(prize.whenFull == "none" or prize.whenFull == "pending" or prize.whenFull == "convert", prize.id)
		end
	end)

	case("R15: location is config: hub and base both allowed by default (wiring is T09b)", function()
		equal(Roulette.allowedAt("hub"), true, "hub")
		equal(Roulette.allowedAt("base"), true, "base")
		equal(Roulette.allowedAt("forest"), false, "forest")
		equal(Roulette.allowedAt(nil), false, "nil")
		local hubOnly = fresh(); hubOnly.locations = { "hub" }
		passes(hubOnly, "hub only")
		equal(Roulette.allowedAt("base", hubOnly), false, "base under hub only")
		local none = fresh(); none.locations = {}
		fails(none, "no location", "location")
		local bad = fresh(); bad.locations = { "hub", "cave" }
		fails(bad, "unknown location", "location")
	end)

	return result
end

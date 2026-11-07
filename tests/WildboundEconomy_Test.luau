-- Invoke with require(freshTestClone)(require(freshEconomyClone), require(freshConfigClone), freshEconomyClone.Source,
-- require(freshRulesClone), require(freshWildClone), require(freshAmbushClone)).
-- M5.2 and M5.5 pure rules. ECO numbers refer to docs/mechanics/wildbound-economy-p0.md.
return function(Economy, Config, source, Rules, Wild, Ambush)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "Expected " .. tostring(expected)
			.. ", got " .. tostring(actual))
	end

	case("the tuning copy is frozen at every level and passes its invariants", function()
		assert(table.isfrozen(Config), "root frozen")
		assert(table.isfrozen(Config.recipes.seal.cost), "nested frozen")
		assert(table.isfrozen(Config.gather.slots[1]), "list entries frozen")
		local problems = Economy.validate(Config)
		equal(#problems, 0, table.concat(problems, "; "))
		equal(Config.monetization, "none")
		equal(Config.currency.purchasable, false)
	end)

	case("the tuning copy carries the document's numbers for this part", function()
		equal(Config.loss.rateBasisPoints, 5000); equal(Config.loss.rateBasisPointsReinforced, 2500)
		equal(Config.capacity.bagItems, 3); equal(Config.capacity.pouchUnits, 30)
		equal(Config.capacity.consumableCaps.seal, 3); equal(Config.capacity.consumableCaps.totem, 1)
		equal(Config.recipes.seal.cost.fogbark, 8); equal(Config.recipes.seal.cost.glowmoss, 4)
		equal(Config.upgrades.reinforcedPack.effects.pouchUnits, 45)
		equal(Config.earn.extractBaseEmber, 4)
		equal(Config.simulatorInputs, nil, "simulator assumptions are not game data")
	end)

	case("ECO-01 the loss table, both rates, exact integers", function()
		local rows = { { 100, 50, 25 }, { 25, 13, 6 }, { 12, 6, 3 }, { 5, 3, 1 }, { 4, 2, 1 }, { 1, 1, 0 }, { 0, 0, 0 } }
		for _, row in ipairs(rows) do
			equal(Economy.lost(row[1], 5000), row[2], "50% of " .. row[1])
			equal(Economy.lost(row[1], 2500), row[3], "25% of " .. row[1])
		end
		equal(Economy.lost(3, 5000), 2, "1.5 rounds up")
		equal(Economy.lost(30, 10000), 30); equal(Economy.lost(30, 0), 0)
		for _, bad in ipairs({ -1, 1.5, 0 / 0, math.huge, "4" }) do equal(Economy.lost(bad, 5000), 0) end
		equal(Economy.lost(4, 10001), 0, "a rate above 100% is refused")
		equal(Economy.lost(4, 2500.5), 0)
	end)

	case("capacity and loss follow owned upgrades only", function()
		equal(Economy.bagCapacity(Config, {}), 3); equal(Economy.pouchCapacity(Config, {}), 30)
		equal(Economy.lossBasisPoints(Config, {}), 5000)
		local pack = { reinforcedPack = true }
		equal(Economy.bagCapacity(Config, pack), 4); equal(Economy.pouchCapacity(Config, pack), 45)
		equal(Economy.lossBasisPoints(Config, pack), 2500)
		equal(Economy.bagCapacity(Config, { reinforcedPack = "yes" }), 3, "only true owns")
		equal(Economy.bagCapacity(Config, nil), 3)
		local names = Economy.pouchMaterials(Config)
		equal(#names, 2); equal(names[1], "fogbark"); equal(names[2], "glowmoss")
		equal(#Economy.materials(Config), 3)
	end)

	case("ECO-24 carry speed is the slower of pouch and eggs, and always outruns Silueta", function()
		equal(Economy.pouchSpeed(Config, 0, 30), 16); equal(Economy.pouchSpeed(Config, 11, 30), 16)
		equal(Economy.pouchSpeed(Config, 12, 30), 13); equal(Economy.pouchSpeed(Config, 23, 30), 13)
		equal(Economy.pouchSpeed(Config, 24, 30), 11); equal(Economy.pouchSpeed(Config, 30, 30), 11)
		equal(Economy.pouchSpeed(Config, 17, 45), 16); equal(Economy.pouchSpeed(Config, 18, 45), 13)
		equal(Economy.pouchSpeed(Config, 5, 0), 16, "no capacity reads as empty")
		local fastest = 0
		for _, phase in ipairs({ "Day", "Night" }) do
			for _, fog in ipairs({ true, false }) do
				fastest = math.max(fastest, Rules.resolveCreatureProfile("Silueta", phase, fog).speed)
			end
		end
		equal(fastest, 8)
		for units = 0, 45 do
			for eggs = 0, 4 do
				for _, capacity in ipairs({ 30, 45 }) do
					local speed = Economy.carrySpeed(Config, math.min(units, capacity), capacity, Wild.carrySpeed(eggs))
					assert(speed > fastest, ("carrySpeed %s at %d units, %d eggs"):format(speed, units, eggs))
					assert(speed <= Economy.pouchSpeed(Config, math.min(units, capacity), capacity), "slower of the two")
					assert(speed <= Wild.carrySpeed(eggs), "slower of the two")
				end
			end
		end
	end)

	case("ECO-17 item Ember reads the stored tier, and a trip pays its base only when complete", function()
		equal(Economy.itemEmber(Config, { kind = "Creature", riskTier = "Safe" }), 6)
		equal(Economy.itemEmber(Config, { kind = "Creature", riskTier = "Fog" }), 8)
		equal(Economy.itemEmber(Config, { kind = "Creature", riskTier = "Territory" }), 14)
		equal(Economy.itemEmber(Config, { kind = "Egg", riskTier = "Territory" }), 10)
		equal(Economy.itemEmber(Config, { kind = "Egg", riskTier = "Fog" }), 0)
		equal(Economy.itemEmber(Config, { kind = "Nightbloom", quantity = 3 }), 0)
		equal(Economy.itemEmber(Config, { kind = "Creature" }), 0, "no tier pays nothing")
		equal(Economy.itemEmber(Config, nil), 0)
		equal(Economy.baseEmber(Config, 45, 60, 1), 4)
		equal(Economy.baseEmber(Config, 44.9, 60, 1), 0, "too short")
		equal(Economy.baseEmber(Config, 45, 59.9, 1), 0, "too close")
		equal(Economy.baseEmber(Config, 600, 300, 0), 0, "AFK-5 nothing new pays nothing")
		equal(Economy.baseEmber(Config, 0 / 0, 300, 3), 0)
	end)

	case("payment is atomic: exact cost, one short, unknown keys", function()
		local wallet = { ember = 12, banked = { fogbark = 8, glowmoss = 5, nightbloom = 1 } }
		assert(Economy.canPay(wallet, Config.recipes.capsule.cost), "exact cost")
		Economy.pay(wallet, Config.recipes.capsule.cost)
		equal(wallet.ember, 0); equal(wallet.banked.fogbark, 0); equal(wallet.banked.nightbloom, 0)
		local short = { ember = 0, banked = { fogbark = 7, glowmoss = 4 } }
		equal(Economy.canPay(short, Config.recipes.seal.cost), false)
		equal(short.banked.fogbark, 7, "refusal changes nothing")
		equal(Economy.canPay(short, { moonstone = 1 }), false)
		equal(Economy.canPay(short, { fogbark = -1 }), false)
		equal(Economy.canPay(nil, { fogbark = 1 }), false)
		local ok = pcall(Economy.pay, short, Config.recipes.seal.cost)
		equal(ok, false, "pay refuses what canPay refuses")
		equal(short.banked.fogbark, 7)
	end)

	case("B8 a Ward Seal is affordable from outside and fog materials alone", function()
		for key in pairs(Config.recipes.seal.cost) do
			assert(key == "fogbark" or key == "glowmoss", "seal needs only Day materials, got " .. key)
			for _, zone in ipairs({ "outside", "fog" }) do
				assert(Config.yields[zone][key] and Config.spawnWeights[zone].Day[key], key .. " reachable in " .. zone)
			end
		end
	end)

	case("totem downside: detection grows by the tuned bonus, ambush radius matches the tuning", function()
		equal(Economy.detectionRange(Config, 28, true), 34)
		equal(Economy.detectionRange(Config, 38, true), 44)
		equal(Economy.detectionRange(Config, 28, false), 28)
		equal(Economy.detectionRange(Config, 28, "true"), 28, "only true counts")
		equal(Ambush.CONSTANTS.TOTEM_RANGE, Config.totem.ambushAnchorRadius)
		equal(Config.totem.ambushAnchorWeightMultiplier, 2, "Ambush.weights doubles")
		local doubled = Ambush.weights(Ambush.anchors(), { { x = 0, z = -85, totem = true } })
		local plain = Ambush.weights(Ambush.anchors(), { { x = 0, z = -85 } })
		equal(doubled[1].weight, plain[1].weight * 2)
	end)

	case("validate catches broken tuning", function()
		local function broken(mutate)
			local copy = {}
			local function deep(value)
				if type(value) ~= "table" then return value end
				local out = {}
				for key, item in pairs(value) do out[key] = deep(item) end
				return out
			end
			copy = deep(Config)
			mutate(copy)
			assert(#Economy.validate(copy) > 0, "a broken config must be reported")
		end
		broken(function(c) c.monetization = "robux" end)
		broken(function(c) c.spawnWeights.fog.Day.nightbloom = 5 end)
		broken(function(c) c.cycle.phases.Day = 1 end)
		broken(function(c) c.loss.rateBasisPoints = 12000 end)
		broken(function(c) c.spawnWeights.outside.Day = { fogbark = 0, glowmoss = 0 } end)
		broken(function(c) c.gather.holdSeconds.heart = 2 end)
		broken(function(c) c.recipes.seal.cost.moonstone = 1 end)
		equal(#Economy.validate(nil), 1)
	end)

	case("the module is pure: no services, clock, randomness or persistence", function()
		for _, word in ipairs({ "game", "GetService", "os.", "tick", "Random", "math.random", "DataStore",
			"task.", "workspace", "MarketplaceService", "Robux" }) do
			equal(source:find(word, 1, true), nil, "source mentions " .. word)
		end
	end)

	return result
end

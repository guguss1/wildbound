-- Invoke with require(freshTestClone)(require(freshBalanceClone), freshBalanceClone.Source).
-- Wildbound 2.0 balance (T01, odd/tasks/wildbound-2-0.md): the proposed, unwired 2.0 numbers, their validation, the
-- round-2 and live conflict flags and the pure lookup helpers. Nothing requires the module yet; these cases pin its
-- values. Every failing config names the error text that only its rule produces.
return function(Balance, source)
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
		return copy(Balance.CONSTANTS)
	end
	local function errorsOf(config, label)
		local ran, ok, errors = pcall(Balance.validate, config)
		assert(ran, (label or "config") .. ": validate threw: " .. tostring(ok))
		return ok, errors
	end
	local function fails(config, label, needle)
		local ok, errors = errorsOf(config, label)
		assert(ok == false, (label or "config") .. ": expected validation to fail")
		assert(type(errors) == "table" and #errors > 0, (label or "config") .. ": expected errors listed")
		if needle then
			assert(table.concat(errors, " | "):lower():find(needle, 1, true), (label or "config") .. ": no error mentions " .. needle .. ": " .. table.concat(errors, " | "))
		end
	end
	local function passes(config, label)
		local ok, errors = errorsOf(config, label)
		assert(ok == true, label .. ": expected validation to pass: " .. table.concat(errors or {}, " | "))
	end
	local function pinArray(actual, expected, label)
		assert(type(actual) == "table", label .. ": not a table")
		equal(#actual, #expected, label .. " length")
		for index, value in ipairs(expected) do equal(actual[index], value, label .. "[" .. index .. "]") end
	end
	local function pinMap(actual, expected, label)
		assert(type(actual) == "table", label .. ": not a table")
		for key, value in pairs(expected) do
			if type(value) == "table" then pinMap(actual[key], value, label .. "." .. tostring(key))
			else equal(actual[key], value, label .. "." .. tostring(key)) end
		end
		for key in pairs(actual) do assert(expected[key] ~= nil, label .. ": unexpected key " .. tostring(key)) end
	end
	local function mentions(list, needle, label)
		local text = table.concat(list, " | ")
		assert(text:find(needle, 1, true), label .. ": no entry mentions " .. needle .. ": " .. text)
	end
	local function lacks(list, needle, label)
		local text = table.concat(list, " | ")
		assert(not text:find(needle, 1, true), label .. ": an entry mentions " .. needle .. ": " .. text)
	end

	case("B0: the module exists, is proposed and is not wired", function()
		equal(type(Balance), "table", "module")
		equal(Balance.status, "proposed")
		equal(Balance.wired, false)
	end)

	case("B1: the rarity ids are the existing ones, in order", function()
		pinArray(Balance.RARITIES, { "Comun", "Rara", "Epica", "Legendaria" }, "RARITIES")
	end)

	case("B2: the default constants validate", function()
		local ok, errors = Balance.validate()
		equal(ok, true, "validate: " .. table.concat(errors or {}, "; "))
		equal(#errors, 0, "no errors")
		local okExplicit = Balance.validate(Balance.CONSTANTS)
		equal(okExplicit, true, "the explicit constants")
	end)

	case("B3: the day cycle phases are 240/60/300/120 and sum to 720", function()
		pinMap(Balance.CONSTANTS.dayCycle.phases, { Day = 240, Dusk = 60, Night = 300, Dawn = 120 }, "phases")
		equal(Balance.CONSTANTS.dayCycle.cycleSeconds, 720)
		local sum = 0
		for _, seconds in pairs(Balance.CONSTANTS.dayCycle.phases) do sum += seconds end
		equal(sum, 720, "phase sum")
	end)

	case("B4: phases that do not sum to the cycle fail; an unknown phase fails", function()
		local config = fresh()
		config.dayCycle.phases.Night = 301
		fails(config, "Night 301", "not the cycle length")
		local noon = fresh()
		noon.dayCycle.phases.Noon = 30
		fails(noon, "a Noon phase", "not a day cycle phase")
	end)

	case("B5: the roulette weights are pinned; the sum, a missing and an unknown category fail", function()
		pinMap(Balance.CONSTANTS.roulette.weights,
			{ esencia = 35, materials = 25, gloves = 20, incubationBoosters = 12, consumables = 6, specialEgg = 2 }, "weights")
		local sum = 0
		for _, weight in pairs(Balance.CONSTANTS.roulette.weights) do sum += weight end
		equal(sum, 100, "weight sum")
		equal(Balance.CONSTANTS.roulette.freeFirstSpin, true)
		equal(Balance.CONSTANTS.roulette.spinCost, 45)
		local config = fresh()
		config.roulette.weights.specialEgg = 3
		fails(config, "specialEgg 3", "not 100")
		local dropped = fresh()
		dropped.roulette.weights.specialEgg = nil
		dropped.roulette.weights.esencia = 37
		fails(dropped, "specialEgg dropped, esencia 37", "missing category specialegg")
		local unknown = fresh()
		unknown.roulette.weights.esencia = 30
		unknown.roulette.weights.jackpot = 5
		fails(unknown, "a jackpot category", "not a roulette category")
	end)

	case("B6: the treadmill is pinned; repeats, drops, a length mismatch and a paid level 0 fail", function()
		local wide = fresh()
		wide.treadmill.speeds = { 16, 24, 32, 40, 46, 50 }
		equal((errorsOf(wide, "a PF2-sized ladder")), true, "PF2: a walk up to 50 is in range")
		pinArray(Balance.CONSTANTS.treadmill.speeds, { 16, 17, 18, 19, 20, 21 }, "speeds")
		pinArray(Balance.CONSTANTS.treadmill.costs, { 0, 30, 80, 200, 450, 900 }, "costs")
		local flat = fresh()
		flat.treadmill.speeds[3] = flat.treadmill.speeds[2]
		fails(flat, "a repeated speed", "treadmill.speeds: entry 3")
		local cheaper = fresh()
		cheaper.treadmill.costs[4] = 70
		fails(cheaper, "a decreasing cost", "treadmill.costs: entry 4")
		local short = fresh()
		short.treadmill.costs[6] = nil
		fails(short, "five costs for six speeds", "6 speeds but 5 costs")
		local paid = fresh()
		paid.treadmill.costs[1] = 5
		fails(paid, "level 0 costs 5", "level 0 must cost 0")
	end)

	case("B7: the incubator factors and costs are pinned; level III may be tuned inside the range", function()
		pinArray(Balance.CONSTANTS.incubation.upgradeFactors, { 1, 0.9, 0.8, 0.7 }, "factors")
		pinArray(Balance.CONSTANTS.incubation.upgradeCosts, { 0, 100, 300, 750 }, "upgrade costs")
		local tuned = fresh()
		tuned.incubation.upgradeFactors[4] = 0.75
		passes(tuned, "level III at 0.75")
		local bumpy = fresh()
		bumpy.incubation.upgradeFactors = { 1, 0.8, 0.85, 0.7 }
		fails(bumpy, "0.8 then 0.85", "does not decrease")
		local start = fresh()
		start.incubation.upgradeFactors[1] = 0.95
		fails(start, "level 0 at 0.95", "level 0 must be 1")
		local length = fresh()
		length.incubation.upgradeCosts[4] = nil
		fails(length, "three costs for four factors", "4 upgrade factors but 3 upgrade costs")
		local order = fresh()
		order.incubation.upgradeCosts = { 0, 300, 100, 750 }
		fails(order, "upgrade costs out of order", "incubation.upgradecosts: entry 3")
		local paid = fresh()
		paid.incubation.upgradeCosts[1] = 50
		fails(paid, "incubator level 0 costs 50", "incubation.upgradecosts[1]: level 0 must cost 0")
	end)

	case("B8: incubation seconds by previous hatches (0-based), rarity and incubator level", function()
		equal(Balance.incubationSeconds("Epica", 0, 3), 10, "first hatch ignores rarity and upgrade")
		equal(Balance.incubationSeconds("Legendaria", 1, 0), 20, "second hatch")
		equal(Balance.incubationSeconds("Comun", 2, 0), 40, "base")
		near(Balance.incubationSeconds("Rara", 4, 3), 52.5, 1e-9, "Rara level III")
		near(Balance.incubationSeconds("Legendaria", 8, 3), 210, 1e-9, "Legendaria level III")
		near(Balance.incubationSeconds("Comun", 2, 99), 28, 1e-9, "level clamps to III")
		equal(Balance.incubationSeconds("Nope", 2, 0), nil, "unknown rarity")
		for _, bad in ipairs({ -1, 1.5, 0 / 0, math.huge }) do
			equal(Balance.incubationSeconds("Comun", bad, 0), nil, "previousHatches " .. tostring(bad))
		end
		equal(Balance.incubationSeconds("Comun", nil, 0), nil, "previousHatches nil")
		equal(Balance.incubationSeconds("Comun", "2", 0), nil, "previousHatches as a string")
	end)

	case("B9: the rarity minimum binds under a booster; a minimum above the upgraded time fails", function()
		near(Balance.incubationSeconds("Legendaria", 2, 0, 0.9), 270, 1e-9, "booster 0.9")
		equal(Balance.incubationSeconds("Comun", 2, 3, 0.5), 25, "booster: the Comun floor 25 binds over 14")
		equal(Balance.incubationSeconds("Epica", 0, 0, 0.5), 10, "the first-egg time ignores the booster")
		for _, bad in ipairs({ 0, -0.5, 1.5, 0 / 0 }) do
			equal(Balance.incubationSeconds("Comun", 2, 0, bad), nil, "booster " .. tostring(bad))
		end
		local config = fresh()
		config.incubation.minSeconds.Comun = 30
		near(Balance.incubationSeconds("Comun", 2, 3, nil, config), 30, 1e-9, "minimum binds")
		fails(config, "Comun minimum 30 above 28", "above the fully upgraded time")
	end)

	case("B10: the farm slots are pinned; start above max, unbuyable slots and part slots fail", function()
		equal(Balance.CONSTANTS.farm.startSlots, 4)
		equal(Balance.CONSTANTS.farm.maxSlots, 8)
		equal(Balance.CONSTANTS.farm.uncollectedCapMinutes, 15)
		pinMap(Balance.CONSTANTS.farm.slotCosts, { [5] = 200, [6] = 500 }, "slot costs")
		local over = fresh()
		over.farm.startSlots = 7
		over.farm.maxSlots = 6
		over.farm.slotCosts = {}
		fails(over, "start 7 over max 6", "startslots 7 is above maxslots 6")
		local owned = fresh()
		owned.farm.startSlots = 5
		fails(owned, "start 5 with a price for slot 5", "slotcosts[5]: the slot must be")
		local beyond = fresh()
		beyond.farm.maxSlots = 5
		fails(beyond, "max 5 with a price for slot 6", "slotcosts[6]: the slot must be")
		local half = fresh()
		half.farm.startSlots = 4.5
		fails(half, "start 4.5", "farm.startslots: 4.5 is not a whole number")
	end)

	case("B11: sell prices and income are pinned and keyed exactly by rarity", function()
		pinMap(Balance.CONSTANTS.sell.price, { Comun = 15, Rara = 60, Epica = 200, Legendaria = 650 }, "sell")
		pinMap(Balance.CONSTANTS.farm.incomePerMinute, { Comun = 1, Rara = 3, Epica = 7, Legendaria = 15 }, "income")
		local extra = fresh()
		extra.sell.price.Common = 15
		fails(extra, "extra key Common", "sell.price: unknown rarity common")
		local missing = fresh()
		missing.sell.price.Legendaria = nil
		fails(missing, "missing Legendaria", "sell.price: missing rarity legendaria")
	end)

	case("B12: the bat is pinned; short immunity and an out-of-range push fail", function()
		pinMap(Balance.CONSTANTS.bat,
			{ cooldown = 5, ragdollSeconds = 1.2, push = 45, lift = 20, immunity = 3, parentStun = 0.6 }, "bat")
		local short = fresh()
		short.bat.immunity = 2
		fails(short, "immunity under ragdoll + 1", "below ragdollseconds + 1")
		local strong = fresh()
		strong.bat.push = 70
		fails(strong, "push 70", "bat.push: 70 is outside")
		local long = fresh()
		long.bat.immunity = 20
		fails(long, "immunity 20 over the live BatKnock cap 15", "bat.immunity: 20 is outside")
	end)

	case("B13: a NaN or a string in any number field fails without throwing", function()
		local leaves = {}
		local function walk(node, path)
			for key, value in pairs(node) do
				local here = table.clone(path)
				table.insert(here, key)
				if type(value) == "table" then walk(value, here)
				elseif type(value) == "number" then table.insert(leaves, here) end
			end
		end
		walk(Balance.CONSTANTS, {})
		assert(#leaves > 30, "expected every numeric field, found " .. #leaves)
		for _, path in ipairs(leaves) do
			for _, bad in ipairs({ 0 / 0, "12" }) do
				local config = fresh()
				local node = config
				for index = 1, #path - 1 do node = node[path[index]] end
				node[path[#path]] = bad
				local label = {}
				for _, key in ipairs(path) do table.insert(label, tostring(key)) end
				fails(config, table.concat(label, ".") .. " = " .. tostring(bad))
			end
		end
		fails("not a table", "a string config", "config: not a table")
	end)

	case("B14: treadmill helpers clamp the level and stop at the maximum", function()
		equal(Balance.treadmillSpeed(-1), 16)
		equal(Balance.treadmillSpeed(99), 21)
		equal(Balance.treadmillSpeed(2.7), 18, "floored")
		equal(Balance.treadmillCost(5), nil, "no level after the maximum")
		equal(Balance.treadmillCost(0), 30)
	end)

	case("B15: the default values flag the round-2 Q9 conflict with La Silueta", function()
		local list = Balance.conflicts()
		assert(type(list) == "table" and #list > 0, "expected conflicts at default")
		mentions(list, "Silueta", "Q9")
		mentions(list, "30.45", "the clamped sprint")
	end)

	case("B16: the module stays unwired and pure", function()
		assert(type(source) == "string" and #source > 0, "source")
		for _, needle in ipairs({ "require(", "DataStore", "game:", "GetService", "workspace", "os.time", "os.clock",
			"tick(", "math.random", "Random.new" }) do
			assert(not source:find(needle, 1, true), "source has " .. needle)
		end
	end)

	case("B17: consumable prices are keyed exactly by the three consumables", function()
		pinArray(Balance.CONSUMABLES, { "trap", "smoke", "portablePortal" }, "CONSUMABLES")
		pinMap(Balance.CONSTANTS.consumables.price, { trap = 60, smoke = 40, portablePortal = 125 }, "price")
		local typo = fresh()
		typo.consumables.price.portablePortal = nil
		typo.consumables.price.potablePortal = 125
		fails(typo, "potablePortal typo", "consumables.price: unknown consumable potableportal")
		fails(typo, "potablePortal typo", "consumables.price: missing consumable portableportal")
		local bare = fresh()
		bare.consumables.price = 60
		fails(bare, "a bare number price", "consumables.price: expected a table")
	end)

	case("B18: a table in a number field and a number in a list field fail", function()
		local empty = fresh()
		empty.bat.cooldown = {}
		fails(empty, "bat.cooldown = {}", "bat.cooldown: expected a number")
		local boxed = fresh()
		boxed.incubation.secondCradleCost = { 5 }
		fails(boxed, "secondCradleCost = {5}", "incubation.secondcradlecost: expected a number")
		local flat = fresh()
		flat.treadmill.speeds = 16
		fails(flat, "treadmill.speeds = 16", "treadmill.speeds: expected a table")
		local holes = fresh()
		holes.incubation.upgradeFactors = { [1] = 1, [3] = 0.8 }
		fails(holes, "a gap in upgradeFactors", "incubation.upgradefactors: expected an array")
	end)

	case("B19: Esencia amounts and slot counts must be whole numbers", function()
		local slot = fresh()
		slot.farm.slotCosts[5] = 200.5
		fails(slot, "slot 5 costs 200.5", "farm.slotcosts[5]: 200.5 is not a whole number")
		local spin = fresh()
		spin.roulette.spinCost = 45.5
		fails(spin, "spin 45.5", "roulette.spincost: 45.5 is not a whole number")
		local sell = fresh()
		sell.sell.price.Rara = 60.25
		fails(sell, "Rara sells for 60.25", "sell.price[rara]: 60.25 is not a whole number")
	end)

	case("B20: Balance.LIVE records the live values (sync 34eab83) that differ from the pack", function()
		local live = Balance.LIVE
		assert(type(live) == "table", "LIVE")
		-- CF3 (odd/tasks/wildbound-caramelo.md): no day/night cycle since CA4; a 300 s wave clock with a 10 s Warning window,
		-- and per place a fixed gameplay phase (BiomeLight.RULES, CF1) and a fixed light mood (BiomeLight.PRESETS).
		pinMap(live.dayCycle, { fixed = true, waveSeconds = 300, warningSeconds = 10,
			rules = { Forest = "Night", Abyss = "Night", Caves = "Night", Caramelo = "Day", Hub = "Day", Mountains = "Day",
				Swamp = "Day", Cemetery = "Day", Volcanic = "Day" },
			light = { Forest = "Night", Abyss = "Night", Caves = "Night", Caramelo = "Day", Hub = "Day", Mountains = "Day",
				Swamp = "Dusk", Cemetery = "Dusk", Volcanic = "Dusk" } }, "LIVE.dayCycle")
		-- PF2 (user decision 2026-11-14): the live treadmill went to +2 walk per level, 17 levels, a cap of 50.
		pinMap(live.training, { walkStep = 2, maxLevel = 17, walkCap = 50, walkCapMin = 16, walkCapMax = 60,
			baseCost = 30, costGrowth = 1.2 }, "LIVE.training")
		pinMap(live.bat, { cooldown = 5, ragdollSeconds = 1.2, immunity = 3, push = 45, lift = 20, immunityMax = 15 }, "LIVE.bat")
		pinMap(live.incubator, { hatchSeconds = 15, slots = 1 }, "LIVE.incubator")
		pinMap(live.movement, { sprintMultiplier = 1.45, sprintCap = 24 }, "LIVE.movement")
		pinMap(live.silueta, { nightHunt = 17 }, "LIVE.silueta")
		equal(Balance.CONSTANTS.movement, nil, "the movement mirror moved out of CONSTANTS")
	end)

	case("B21: conflicts() reports each live gap at default", function()
		local list = Balance.conflicts()
		mentions(list, "live: no day/night cycle: a 300 s wave clock and a fixed light per biome", "CF3: the fixed world")
		lacks(list, "live: dayCycle.phases", "CF3: no phase lengths are compared with a world that has none")
		lacks(list, "WALK_CAP tuning range", "PF2: the live walk cap range (16..60) holds the proposed top walk")
		mentions(list, "Training.MAX_LEVEL 17", "the level count")
		mentions(list, "live: bat.parentStun", "no live parent stun")
		lacks(list, "live: bat.cooldown", "the bat cooldown agrees")
		mentions(list, "HATCH_SECONDS 15", "the incubator")
	end)

	case("B22: conflicts() takes the live constants as an argument", function()
		local live = copy(Balance.LIVE)
		live.dayCycle = { cycleSeconds = 720, phases = { Day = 240, Dusk = 60, Night = 300, Dawn = 120 } }
		live.bat.cooldown = 12
		live.silueta.nightHunt = 22
		local list = Balance.conflicts(nil, live)
		lacks(list, "live: dayCycle", "the passed day cycle agrees")
		lacks(list, "live: no day/night cycle", "CF3: a passed cycling world is not the fixed one")
		mentions(list, "live: bat.cooldown is 12 live, 5 in Balance", "the passed bat")
		lacks(list, "outruns", "a 22 hunt is not outrun by 21")
		local config = fresh()
		config.bat.immunity = 14
		local capped = copy(Balance.LIVE)
		capped.bat.immunityMax = 10
		mentions(Balance.conflicts(config, capped), "above the live BatKnock cap 10", "the immunity cap")
		equal(type(Balance.conflicts(nil, "broken")), "table", "a broken live table never throws")
	end)

	case("B23: liveFrom() reads the deployed live modules, and Balance.LIVE has not drifted from them", function()
		local where = {
			worldRules = { "ServerScriptService", "WildboundWorldRules" },
			training = { "ReplicatedStorage", "WildboundTraining" },
			stamina = { "ServerScriptService", "WildboundStamina" },
			batKnock = { "ServerScriptService", "WildboundBatKnock" },
			incubator = { "ReplicatedStorage", "WildboundIncubator" },
			tuningSchema = { "ReplicatedStorage", "WildboundTuningSchema" },
			waveClock = { "ReplicatedStorage", "WildboundWaveClock" },
			biomeLight = { "ReplicatedStorage", "WildboundBiomeLight" },
		}
		local sources, missing = {}, {}
		for key, spot in pairs(where) do
			local module = game:GetService(spot[1]):FindFirstChild(spot[2])
			local loaded = nil
			if module and module:IsA("ModuleScript") then
				local ok, value = pcall(require, module:Clone())
				if ok then loaded = value end
			end
			if loaded == nil then table.insert(missing, spot[1] .. "." .. spot[2]) end
			sources[key] = loaded
		end
		assert(#missing == 0, "live modules not loaded: " .. table.concat(missing, ", "))
		local derived = Balance.liveFrom(sources)
		pinMap(derived, copy(Balance.LIVE), "liveFrom vs LIVE")
		pinMap(Balance.liveFrom({}), copy(Balance.LIVE), "liveFrom with nothing falls back to LIVE")
	end)

	case("B24: CF3, liveFrom() describes the fixed world from the wave clock and the biome light it is given", function()
		local fixedRules = { CYCLE_SECONDS = 0, cycle = function() return { phase = "Day", remaining = 0, fixed = true } end }
		local wave = { CONSTANTS = { WAVE_SECONDS = 240, WARNING_SECONDS = 12 } }
		local light = { RULES = { Forest = "Night", Caramelo = "Day" },
			PRESETS = { Forest = { mood = "Night" }, Caramelo = { mood = "Day" }, Swamp = { mood = "Dusk" } } }
		local derived = Balance.liveFrom({ worldRules = fixedRules, waveClock = wave, biomeLight = light })
		pinMap(derived.dayCycle, { fixed = true, waveSeconds = 240, warningSeconds = 12,
			rules = { Forest = "Night", Caramelo = "Day" }, light = { Forest = "Night", Caramelo = "Day", Swamp = "Dusk" } },
			"derived dayCycle")
		mentions(Balance.conflicts(nil, derived), "live: no day/night cycle: a 240 s wave clock", "the derived wave")
		-- a bad source keeps the LIVE value
		local broken = Balance.liveFrom({ waveClock = { CONSTANTS = { WAVE_SECONDS = "x" } }, biomeLight = { RULES = 3 } })
		pinMap(broken.dayCycle, copy(Balance.LIVE.dayCycle), "broken sources")
		-- a cycling world (the old 720 s day) still replaces the description with its phase lengths
		local cycling = { CYCLE_SECONDS = 720, cycle = function(t)
			local spans = { { "Day", 300 }, { "Dusk", 60 }, { "Night", 300 }, { "Dawn", 60 } }
			local at = 0
			for _, span in ipairs(spans) do
				if t < at + span[2] then return { phase = span[1], remaining = at + span[2] - t } end
				at += span[2]
			end
			return { phase = "Day", remaining = 300 }
		end }
		local old = Balance.liveFrom({ worldRules = cycling, waveClock = wave, biomeLight = light })
		pinMap(old.dayCycle, { cycleSeconds = 720, phases = { Day = 300, Dusk = 60, Night = 300, Dawn = 60 } }, "cycling")
		mentions(Balance.conflicts(nil, old), "live: dayCycle.phases.Day is 300 live, 240 in Balance", "the old gap")
	end)

	return result
end

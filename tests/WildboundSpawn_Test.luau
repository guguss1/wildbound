-- Invoke with require(freshTestClone)(require(freshSpawnClone), require(freshConfigClone), freshSpawnClone.Source,
-- require(freshRulesClone)). M5.4 spawn pipeline. ECO numbers refer to docs/mechanics/wildbound-economy-p0.md.
return function(Spawn, Config, source, Rules)
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
	local function near(actual, expected, tolerance, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= tolerance, (label and label .. ": " or "")
			.. ("expected %.4f within %.4f, got %s"):format(expected, tolerance, tostring(actual)))
	end
	local function probabilities(request)
		local list = assert(Spawn.normalize(assert(Spawn.weights(Config, request))))
		local map = {}
		for _, item in ipairs(list) do map[item.id] = item.p end
		return map, list
	end
	local PHASES = { "Day", "Dusk", "Night", "Dawn" }

	case("weights are filtered by zone and phase, then normalized to one", function()
		for zone in pairs(Config.spawnWeights) do
			for _, phase in ipairs(PHASES) do
				for _, night in ipairs({ true, false }) do
					local _, list = probabilities({ zone = zone, phase = phase, nightRewards = night })
					local total = 0
					for _, item in ipairs(list) do total += item.p; assert(item.p > 0, "zero weights are dropped") end
					near(total, 1, 1e-9, zone .. "/" .. phase)
				end
			end
		end
		local fogNight = probabilities({ zone = "fog", phase = "Night", nightRewards = true })
		near(fogNight.fogbark, 0.45, 1e-12); near(fogNight.glowmoss, 0.40, 1e-12); near(fogNight.nightbloom, 0.15, 1e-12)
		local outside = probabilities({ zone = "outside", phase = "Day" })
		near(outside.fogbark, 0.85, 1e-12); near(outside.glowmoss, 0.15, 1e-12)
		local territoryDay = probabilities({ zone = "territory", phase = "Dawn" })
		near(territoryDay.glowmoss, 0.60, 1e-12)
	end)

	case("ECO-15 Nightbloom appears only at Night, only in fog and territory, and only with night rewards on", function()
		for zone in pairs(Config.spawnWeights) do
			for _, phase in ipairs(PHASES) do
				local on = probabilities({ zone = zone, phase = phase, nightRewards = true })
				local off = probabilities({ zone = zone, phase = phase, nightRewards = false })
				equal(off.nightbloom, nil, "rewards off: " .. zone .. "/" .. phase)
				if phase == "Night" and zone ~= "outside" then
					assert(on.nightbloom and on.nightbloom > 0, "Night " .. zone .. " has Nightbloom")
				else
					equal(on.nightbloom, nil, zone .. "/" .. phase)
				end
			end
		end
		local territoryOff = probabilities({ zone = "territory", phase = "Night", nightRewards = false })
		near(territoryOff.fogbark, 25 / 65, 1e-12, "filtered, then renormalized; nothing multiplied")
		near(territoryOff.glowmoss, 40 / 65, 1e-12)
		equal(probabilities({ zone = "fog", phase = "Night" }).nightbloom, nil, "night rewards default to off")
	end)

	case("biome, weather and event are validated; the P0 identity values change nothing", function()
		local base = probabilities({ zone = "fog", phase = "Night", nightRewards = true })
		local same = probabilities({ zone = "fog", phase = "Night", nightRewards = true, biome = "forest",
			weather = "Clear", event = "None" })
		for id, p in pairs(base) do equal(same[id], p, id) end
		local function refused(reason, request)
			local list, why = Spawn.weights(Config, request)
			equal(list, nil); equal(why, reason)
		end
		refused("UnknownZone", { zone = "camp", phase = "Day" })
		refused("UnknownZone", { zone = nil, phase = "Day" })
		refused("UnknownPhase", { zone = "fog", phase = "Noon" })
		refused("UnknownBiome", { zone = "fog", phase = "Day", biome = "desert" })
		refused("UnknownWeather", { zone = "fog", phase = "Day", weather = "Storm" })
		refused("UnknownEvent", { zone = "fog", phase = "Day", event = "BloodMoon" })
		equal(Spawn.weights(Config, nil), nil)
	end)

	case("normalize refuses unusable tables and keeps a stable order", function()
		equal(Spawn.normalize({}), nil)
		equal(Spawn.normalize({ { id = "a", weight = 0 } }), nil)
		equal(Spawn.normalize({ { id = "a", weight = -1 }, { id = "b", weight = 2 } }), nil)
		equal(Spawn.normalize({ { id = "a", weight = 0 / 0 } }), nil)
		equal(Spawn.normalize({ { id = "a", weight = math.huge } }), nil)
		equal(Spawn.normalize(nil), nil)
		local list = Spawn.normalize({ { id = "b", weight = 1 }, { id = "a", weight = 3 } })
		equal(list[1].id, "a"); equal(list[1].p, 0.75); equal(list[2].p, 0.25)
		local dropped = Spawn.normalize({ { id = "a", weight = 0 }, { id = "b", weight = 2 } })
		equal(#dropped, 1, "a zero weight is never an outcome"); equal(dropped[1].id, "b"); equal(dropped[1].p, 1)
	end)

	case("pick maps a roll onto cumulative shares, deterministically and in range", function()
		local list = Spawn.normalize({ { id = "a", weight = 1 }, { id = "b", weight = 3 } })
		equal(Spawn.pick(list, 0), "a"); equal(Spawn.pick(list, 0.2499), "a"); equal(Spawn.pick(list, 0.25), "b")
		equal(Spawn.pick(list, 0.9999), "b"); equal(Spawn.pick(list, 1), "b", "a roll of 1 stays in range")
		equal(Spawn.pick(list, -5), "a"); equal(Spawn.pick(list, 0 / 0), "a")
		equal(Spawn.pick(nil, 0.5), nil)
	end)

	case("yields stay inside the tuned inclusive range, and a heart slot adds its bonus once", function()
		for zone, materials in pairs(Config.yields) do
			for material, range in pairs(materials) do
				for _, heart in ipairs({ false, true }) do
					local bonus = heart and Config.gather.heartYieldBonus or 0
					local seen = {}
					for step = 0, 100 do
						local amount = Spawn.yield(Config, zone, material, heart, step / 100)
						assert(amount >= range[1] + bonus and amount <= range[2] + bonus, ("%s/%s %d"):format(zone, material, amount))
						seen[amount] = true
					end
					for amount = range[1] + bonus, range[2] + bonus do assert(seen[amount], "every value is reachable") end
				end
			end
		end
		equal(Spawn.yield(Config, "territory", "nightbloom", true, 0), 2, "heart Nightbloom is 2 to 3")
		equal(Spawn.yield(Config, "territory", "nightbloom", true, 0.999), 3)
		equal(Spawn.yield(Config, "outside", "nightbloom", false, 0.5), nil, "no yield row, no node")
	end)

	case("ECO-16 a fixed seed reproduces the same nodes, and 100,000 draws match the table", function()
		local slot = { id = "T6", zone = "territory", heart = true }
		local function run(seed, count)
			local rng = Random.new(seed)
			local out = {}
			for index = 1, count do
				local node = assert(Spawn.rollNode(Config, slot, "Night", rng, { nightRewards = true }))
				out[index] = node.material .. node.quantity
			end
			return table.concat(out, ",")
		end
		equal(run(20261107, 50), run(20261107, 50), "same seed, same nodes")
		assert(run(20261107, 50) ~= run(7, 50), "a different seed differs")
		local rng = Random.new(12345)
		local counts, draws = {}, 100000
		for _ = 1, draws do
			local node = Spawn.rollNode(Config, slot, "Night", rng, { nightRewards = true })
			counts[node.material] = (counts[node.material] or 0) + 1
		end
		near(counts.fogbark / draws, 0.25, 0.01, "fogbark"); near(counts.glowmoss / draws, 0.40, 0.01, "glowmoss")
		near(counts.nightbloom / draws, 0.35, 0.01, "nightbloom")
	end)

	case("rollNode refuses unknown slots, phases and generators", function()
		local rng = Random.new(1)
		equal(Spawn.rollNode(Config, { zone = "camp" }, "Day", rng), nil)
		equal(Spawn.rollNode(Config, { zone = "fog" }, "Noon", rng), nil)
		equal(Spawn.rollNode(Config, nil, "Day", rng), nil)
		equal(Spawn.rollNode(Config, { zone = "fog" }, "Day", nil), nil)
		local node = Spawn.rollNode(Config, { zone = "outside" }, "Night", rng, { nightRewards = true })
		assert(node.material == "fogbark" or node.material == "glowmoss", "outside never grows Nightbloom")
	end)

	case("slots: active counts follow players, and a free slot of the zone is chosen", function()
		equal(Spawn.activeCount(Config, "fog", 1), 6); equal(Spawn.activeCount(Config, "fog", 2), 7)
		equal(Spawn.activeCount(Config, "territory", 9), 8); equal(Spawn.activeCount(Config, "outside", 0), 6)
		equal(Spawn.slot(Config, "T1").heart, true); equal(Spawn.slot(Config, "nope"), nil)
		local occupied = {}
		for index = 1, 8 do
			local id = Spawn.pickSlot(Config, "fog", occupied, (index - 1) / 8)
			assert(id and not occupied[id], "a free fog slot")
			equal(Spawn.slot(Config, id).zone, "fog")
			occupied[id] = true
		end
		equal(Spawn.pickSlot(Config, "fog", occupied, 0.5), nil, "every fog slot is taken")
	end)

	case("every slot's zone matches the world rules, and heart slots sit in the territory", function()
		for _, slot in ipairs(Config.gather.slots) do
			local fog, safe = Rules.zone(slot.x, slot.z)
			equal(safe, false, slot.id .. " is not in a safe circle")
			local zone = Rules.inTerritory(slot.x, slot.z) and "territory" or fog and "fog" or "outside"
			equal(zone, slot.zone, slot.id)
			if slot.heart then equal(slot.zone, "territory", slot.id) end
		end
	end)

	case("the pipeline is pure: the only randomness is the generator it is given", function()
		for _, word in ipairs({ "game", "GetService", "os.", "tick", "Random.new", "math.random", "DataStore",
			"task.", "workspace", "MarketplaceService" }) do
			equal(source:find(word, 1, true), nil, "source mentions " .. word)
		end
	end)

	return result
end

-- Invoke with require(freshTestClone)(require(freshIslandClone), require(freshEggCarryClone),
-- { server = WildboundServer.Source }).
-- CF2 (odd/tasks/wildbound-caramelo.md; CA4, Caramelo pack 05_SISTEMAS/01): at each 300 s wave start the island nests
-- emptied last wave restock, once per wave id. Island.waveRefill is the pure core of Heist.resetNestsForWave: only an
-- empty nest ("wait_wave" for an egg, "wait" for a cria) refills; an egg still in its nest, a nest whose cria is
-- running home ("returning"), and every carried, dropped or secured egg are never touched; a nest whose island is
-- chasing waits for the chase to end.
return function(Island, EggCarry, sources)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got "
			.. tostring(actual))
	end
	sources = type(sources) == "table" and sources or {}
	local function deepCopy(value)
		if type(value) ~= "table" then return value end
		local out = {}
		for k, v in pairs(value) do out[k] = deepCopy(v) end
		return out
	end
	local function deepEqual(a, b, path)
		if type(a) ~= "table" or type(b) ~= "table" then
			assert(a == b, path .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
			return
		end
		for k, v in pairs(a) do deepEqual(v, b[k], path .. "." .. tostring(k)) end
		for k in pairs(b) do assert(a[k] ~= nil, path .. "." .. tostring(k) .. " is gone") end
	end

	-- One world: E1 lies in I1's nest; E2 (from I2) is carried; E3 (from I3) lies dropped in the forest; E4 (from I4)
	-- was secured at the chest (it left the registry). I5:1 waits for a cria, I5:2's cria is running home, and I6 is
	-- chasing a thief with its nest empty.
	local function world()
		local eggs = EggCarry.new()
		for index, island in ipairs({ "I1", "I2", "I3", "I4" }) do
			EggCarry.add(eggs, "E" .. index, { species = "Lumipol", rarity = "Comun", island = island, tier = "Fog" })
		end
		assert(EggCarry.steal(eggs, "E2", 101, "u2"), "E2 carried")
		assert(EggCarry.steal(eggs, "E3", 102, "u3"), "E3 stolen")
		assert(EggCarry.drop(eggs, 102, "Hit", 50), "E3 dropped")
		assert(EggCarry.steal(eggs, "E4", 103, "u4"), "E4 stolen")
		assert(EggCarry.secure(eggs, "E4", 103), "E4 secured")
		local nestState = { ["I1:1"] = "E1", ["I2:1"] = "wait_wave", ["I3:1"] = "wait_wave", ["I4:1"] = "wait_wave",
			["I5:1"] = "wait", ["I5:2"] = "returning", ["I6:1"] = "wait_wave" }
		local nestGen = { ["I1:1"] = 1, ["I2:1"] = 2, ["I3:1"] = 2, ["I4:1"] = 2, ["I5:1"] = 3, ["I5:2"] = 4, ["I6:1"] = 2 }
		return eggs, nestState, nestGen
	end

	case("CF2: only empty nests refill; an egg still in its nest and a returning cria stay", function()
		assert(type(Island.waveRefill) == "function", "Island.waveRefill missing")
		local _, nestState, nestGen = world()
		local refilled, waiting = Island.waveRefill(nestState, nestGen, { I6 = true })
		equal(table.concat(refilled, ","), "I2:1,I3:1,I4:1,I5:1", "the empty nests, sorted")
		equal(table.concat(waiting, ","), "I6:1", "the chasing island waits")
		equal(nestState["I1:1"], "E1", "the egg in its nest is kept")
		equal(nestState["I5:2"], "returning", "a cria running home is kept")
		for _, slot in ipairs(refilled) do equal(nestState[slot], nil, slot .. " is open for a new egg") end
		equal(nestState["I6:1"], "wait_wave", "a chasing island's nest stays empty")
		equal(nestGen["I1:1"], 1); equal(nestGen["I5:2"], 4)
		equal(nestGen["I2:1"], 3, "a refilled nest's generation moves (a pending refill timer is cancelled)")
		equal(nestGen["I5:1"], 4)
		equal(nestGen["I6:1"], 3, "the waiting nest's generation moves too (its retry owns it)")
	end)

	case("CF2: carried, dropped and secured eggs are untouched by the refresh", function()
		local eggs, nestState, nestGen = world()
		local before = deepCopy(eggs)
		Island.waveRefill(nestState, nestGen, {})
		deepEqual(eggs, before, "eggs")
		equal(EggCarry.get(eggs, "E1").state, "InNest")
		equal(EggCarry.get(eggs, "E2").state, "Carried")
		equal(EggCarry.get(eggs, "E2").carrier, 101)
		equal(EggCarry.get(eggs, "E3").state, "Dropped")
		equal(EggCarry.get(eggs, "E4"), nil, "a secured egg stays banked, never back in the registry")
	end)

	-- The server's ensureNests spawns into every open slot. Run that against the refill's result: new eggs appear only
	-- in the emptied nests, and the old carried and dropped eggs keep their own identity next to the new ones.
	case("CF2: after the refill a new egg appears only in an emptied nest", function()
		local eggs, nestState, nestGen = world()
		local slots = { "I1:1", "I2:1", "I3:1", "I4:1", "I6:1" }
		Island.waveRefill(nestState, nestGen, { I6 = true })
		local serial = 10
		local spawned = {}
		for _, slot in ipairs(slots) do
			if nestState[slot] == nil then
				serial += 1
				local id = "E" .. serial
				EggCarry.add(eggs, id, { species = "Lumipol", rarity = "Comun", island = slot:match("^([^:]+):") })
				nestState[slot] = id
				table.insert(spawned, slot)
			end
		end
		equal(table.concat(spawned, ","), "I2:1,I3:1,I4:1")
		equal(nestState["I1:1"], "E1", "no second egg on a full nest")
		equal(EggCarry.get(eggs, "E2").state, "Carried", "the carried egg is still the thief's")
		equal(EggCarry.get(eggs, "E3").state, "Dropped", "the dropped egg still lies where it fell")
		equal(EggCarry.get(eggs, "E11").state, "InNest")
		equal(EggCarry.carriedCount(eggs, 101), 1)
	end)

	case("CF2: a second call has nothing left to refill; bad input is a no-op", function()
		local _, nestState, nestGen = world()
		Island.waveRefill(nestState, nestGen, {})
		local again, waiting = Island.waveRefill(nestState, nestGen, {})
		equal(#again, 0); equal(#waiting, 0)
		local none, idle = Island.waveRefill(nil, nestGen, {})
		equal(#none, 0); equal(#idle, 0)
		local plain = { ["I2:1"] = "wait_wave" }
		local fresh = {}
		local done = Island.waveRefill(plain, fresh)
		equal(done[1], "I2:1", "no chase table: nothing is chasing")
		equal(fresh["I2:1"], 1, "a missing generation starts at 1")
	end)

	case("CF2: the server's wave reset runs the pure core once per wave id", function()
		local server = sources.server or ""
		local at = server:find("function Heist.resetNestsForWave(_now, wave)", 1, true)
		assert(at, "Heist.resetNestsForWave")
		local core = server:find("Island.waveRefill(nestState, nestGen, chasing)", at, true)
		assert(core and core - at < 900, "resetNestsForWave runs Island.waveRefill")
		assert(server:find("if Heist.nestWave == wave then return end", at, true), "idempotent by wave id")
		assert(server:find("ensureNests()", core, true), "then ensureNests spawns into the open nests")
	end)

	return result
end

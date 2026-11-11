-- Invoke with require(freshTestClone)(require(freshSpawnClockClone), require(freshSpawnGraphClone),
-- require(freshSpeciesClone), freshSpawnClockClone.Source, { server = WildboundServer.Source, text = require(freshTextClone) }).
-- Random world (plan Part 3, RW2): the spawn clock. Every egg or cria spawn lives 300 s, then moves to another point
-- of the same tier; tiers come from the distance to La Silueta's home; rarer tiers respawn later and fewer at once;
-- the species and the reward tier follow the spawn tier. Pure: the clock and the rolls are passed in.
return function(SpawnClock, graph, Species, source, sources)
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
	local TIERS = { "Comun", "Rara", "Epica", "Legendaria" }
	local function count(actions, op)
		local by = {}
		for _, action in ipairs(actions) do
			if action.op == op then by[action.spawn.tier] = (by[action.spawn.tier] or 0) + 1 end
		end
		return by
	end

	case("RW2: the defaults, the live copy and the tuning hook", function()
		assert(type(SpawnClock) == "table" and type(SpawnClock.CONSTANTS) == "table", "module missing")
		local C = SpawnClock.CONSTANTS
		assert(table.isfrozen(C), "the defaults are frozen")
		equal(C.LIFETIME, 300)
		equal(C.RESPAWN_COMUN, 90); equal(C.RESPAWN_RARA, 150); equal(C.RESPAWN_EPICA, 240); equal(C.RESPAWN_LEGENDARIA, 360)
		assert(C.MAX_COMUN > C.MAX_RARA and C.MAX_RARA > C.MAX_EPICA and C.MAX_EPICA >= C.MAX_LEGENDARIA
			and C.MAX_LEGENDARIA >= 1, "fewer at once for higher tiers")
		equal(SpawnClock.tunable().LIFETIME, 300)
		SpawnClock.tune({ LIFETIME = 20, MAX_RARA = 0 / 0, NOPE = 1 })
		equal(SpawnClock.live.LIFETIME, 20)
		equal(SpawnClock.live.MAX_RARA, C.MAX_RARA, "a bad value keeps the default")
		equal(SpawnClock.live.NOPE, nil)
		SpawnClock.tune(nil)
		equal(SpawnClock.live.LIFETIME, 300)
	end)

	case("RW2: tiers by distance to La Silueta's home", function()
		equal(SpawnClock.tierOf(0), "Legendaria"); equal(SpawnClock.tierOf(44.9), "Legendaria")
		equal(SpawnClock.tierOf(45), "Epica"); equal(SpawnClock.tierOf(79.9), "Epica")
		equal(SpawnClock.tierOf(80), "Rara"); equal(SpawnClock.tierOf(120), "Rara")
		equal(SpawnClock.tierOf(120.1), "Comun"); equal(SpawnClock.tierOf(400), "Comun")
		equal(SpawnClock.tierOf(0 / 0), nil); equal(SpawnClock.tierOf("far"), nil)
	end)

	case("RW2: the reward and capture tiers follow the spawn tier; the labels are Spanish", function()
		equal(SpawnClock.REWARD.Comun, "Fog"); equal(SpawnClock.REWARD.Rara, "FogFar")
		equal(SpawnClock.REWARD.Epica, "Territory"); equal(SpawnClock.REWARD.Legendaria, "Heart")
		for _, tier in ipairs(TIERS) do assert(SpawnClock.SLOT_TIER[tier] ~= "Safe", "a wild spawn is never first-capture only") end
		local Text = sources.text
		assert(type(Text) == "table" and type(Text.RARITY) == "table", "Text.RARITY missing")
		equal(Text.RARITY.Comun, "Común"); equal(Text.RARITY.Rara, "Rara")
		equal(Text.RARITY.Epica, "Épica"); equal(Text.RARITY.Legendaria, "Legendaria")
	end)

	case("RW2: every species has a rarity, and every tier has a species", function()
		for name, look in pairs(Species.LOOKS) do
			assert(table.find(TIERS, look.rarity), name .. " rarity " .. tostring(look.rarity))
		end
		for _, tier in ipairs(TIERS) do assert(#Species.byRarity(tier) > 0, "no species for " .. tier) end
		equal(Species.LOOKS.Tizoncillo.rarity, "Legendaria")
		equal(Species.LOOKS.Lumipol.rarity, "Comun")
	end)

	case("RW2: the pools take every wild graph point by its own tier; island nests stay guaranteed points", function()
		local state = SpawnClock.new(graph, Species)
		local wild = 0
		for _, point in ipairs(graph.points) do if not point.guaranteed then wild += 1 end end
		local pooled = 0
		for _, tier in ipairs(TIERS) do
			for _, point in ipairs(state.pools[tier]) do
				pooled += 1
				equal(point.tier, tier, point.id)
				assert(not point.guaranteed, "a nest is never a random point: " .. point.id)
			end
		end
		equal(pooled, wild)
	end)

	case("RW2: the first step fills every tier up to its cap, each spawn living LIFETIME", function()
		local state = SpawnClock.new(graph, Species)
		local actions = SpawnClock.step(state, 100, Random.new(7))
		local made = count(actions, "spawn")
		local C = SpawnClock.CONSTANTS
		equal(made.Comun, C.MAX_COMUN); equal(made.Rara, C.MAX_RARA)
		equal(made.Epica, C.MAX_EPICA); equal(made.Legendaria, C.MAX_LEGENDARIA)
		local used = {}
		for _, action in ipairs(actions) do
			local spawn = action.spawn
			equal(spawn.expiresAt, 100 + C.LIFETIME, spawn.id)
			equal(spawn.point.tier, spawn.tier, spawn.id)
			assert(not used[spawn.point.id], "two spawns on one point")
			used[spawn.point.id] = true
			equal(Species.LOOKS[spawn.species].rarity, spawn.tier, "species follows the tier")
			equal(spawn.rewardTier, SpawnClock.REWARD[spawn.tier])
			if spawn.point.kind == "canopy" then equal(spawn.kind, "Egg", "a bough holds an egg only") end
			assert(spawn.kind == "Egg" or spawn.kind == "Creature", spawn.kind)
		end
		equal(#SpawnClock.step(state, 101, Random.new(8)), 0, "nothing more while every cap is full")
	end)

	case("RW2: at the end of its life a spawn moves to another point of the same tier", function()
		local state = SpawnClock.new(graph, Species)
		local first = SpawnClock.step(state, 0, Random.new(3))
		local old = {}
		for _, action in ipairs(first) do old[action.spawn.id] = action.spawn end
		local actions = SpawnClock.step(state, SpawnClock.CONSTANTS.LIFETIME, Random.new(4))
		local expired, spawned = count(actions, "expire"), count(actions, "spawn")
		for _, tier in ipairs(TIERS) do equal(spawned[tier], expired[tier], tier .. " relocates one for one") end
		for _, action in ipairs(actions) do
			if action.op == "expire" then
				equal(action.reason, "Lifetime")
				assert(old[action.spawn.id], "only old spawns expire")
			else
				for _, before in pairs(old) do
					if before.tier == action.spawn.tier and before.point.id == action.spawn.point.id
						and #state.pools[before.tier] > SpawnClock.live["MAX_" .. string.upper(before.tier)] then
						error("relocated onto its old point " .. before.point.id)
					end
				end
			end
		end
	end)

	case("RW2: a tuned shorter lifetime reaches the spawns already out (the Play check shortens it live)", function()
		local state = SpawnClock.new(graph, Species)
		local first = SpawnClock.step(state, 0, Random.new(11))
		SpawnClock.tune({ LIFETIME = 20 })
		local actions = SpawnClock.step(state, 20, Random.new(12))
		SpawnClock.tune(nil)
		local expired = 0
		for _, action in ipairs(actions) do if action.op == "expire" then expired += 1 end end
		equal(expired, #first, "every spawn out moves at 20 s")
	end)

	case("RW2: a spawn being captured is held past its lifetime", function()
		local state = SpawnClock.new(graph, Species)
		local first = SpawnClock.step(state, 0, Random.new(5))
		local held = { [first[1].spawn.id] = true }
		local actions = SpawnClock.step(state, 400, Random.new(6), held)
		for _, action in ipairs(actions) do
			assert(not (action.op == "expire" and held[action.spawn.id]), "a held spawn never expires")
		end
	end)

	case("RW2: a claimed spawn's tier waits its respawn time before refilling", function()
		local state = SpawnClock.new(graph, Species)
		local first = SpawnClock.step(state, 0, Random.new(9))
		local legend
		for _, action in ipairs(first) do if action.spawn.tier == "Legendaria" then legend = action.spawn end end
		assert(legend, "a Legendaria spawn")
		equal(SpawnClock.claim(state, legend.id, 10), true)
		equal(SpawnClock.claim(state, legend.id, 10), false, "claimed once")
		equal(count(SpawnClock.step(state, 10 + 359, Random.new(1)), "spawn").Legendaria, nil, "not before 360 s")
		equal(count(SpawnClock.step(state, 10 + 360, Random.new(1)), "spawn").Legendaria, 1, "back after 360 s")
	end)

	case("RW2: a reroll expires every random spawn and refills at once; forced spawns can be placed near a point", function()
		local state = SpawnClock.new(graph, Species)
		SpawnClock.step(state, 0, Random.new(2))
		local actions = SpawnClock.reroll(state, 50, Random.new(3))
		local expired, spawned = 0, 0
		for _, action in ipairs(actions) do
			if action.op == "expire" then expired += 1; equal(action.reason, "Reroll") else spawned += 1 end
		end
		assert(expired > 0 and spawned == expired, "everything rerolled")
		local near = SpawnClock.force(state, 60, Random.new(4), { tier = "Comun", kind = "Egg", x = -140, z = 140, radius = 70 })
		assert(near, "a common egg near camp")
		equal(near.kind, "Egg"); equal(near.tier, "Comun")
		assert(math.sqrt((near.point.x + 140) ^ 2 + (near.point.z - 140) ^ 2) <= 70, "within the radius")
		local special = SpawnClock.force(state, 60, Random.new(4), { tier = "Legendaria", kind = "Egg", lifetime = 300,
			special = true, x = 0, z = -85, radius = 45 })
		assert(special and special.special, "a special spawn")
		equal(special.expiresAt, 360)
	end)

	case("RW2: the module is pure", function()
		assert(type(source) == "string" and #source > 0, "source")
		for _, banned in ipairs({ "game:", "workspace", "task.", "os.time", "os.clock", "math.random", "tick(" }) do
			assert(not source:find(banned, 1, true), "reads " .. banned)
		end
	end)

	case("RW2: the inventory server runs the clock and places the spawns on the graph", function()
		local server = sources.server
		assert(type(server) == "string", "server source")
		for _, needle in ipairs({ 'require(script.Parent:WaitForChild("WildboundSpawnClock"))',
			'require(script.Parent:WaitForChild("WildboundSpawnGraph"))', "SpawnClock.step(spawnClock,",
			"SpawnClock.claim(spawnClock,", "Text.RARITY[", 'SetAttribute("Rarity"' }) do
			assert(server:find(needle, 1, true), "server: " .. needle)
		end
	end)

	return result
end

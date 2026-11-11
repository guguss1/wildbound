-- Invoke with require(freshTestClone)(require(freshBeastDirectorClone), freshBeastDirectorClone.Source,
-- require(freshBeastConfigClone)).
-- Nest Heist phase 4a (NB2, docs/design/beast-pack/00_INTEGRACION_DE_BESTIAS.md and CONFIG_INICIAL.json): the one beast
-- director. Every 10 s each living player outside a safe zone gets an independent roll per eligible beast; a won roll
-- becomes an encounter only if the per-player threat budget (3 points, 2 encounters) and every cooldown allow it, and
-- the reservation is released exactly once. Fake players and an injected random source; no world is touched.
return function(Director, source, Config)
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
	local function near(actual, expected, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= 1e-9,
			(label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	-- A random source that plays back a list, then repeats its last value.
	local function sequence(values)
		local i = 0
		return function()
			i = math.min(i + 1, #values)
			return values[i]
		end
	end
	local function always(value) return function() return value end end
	-- A calm, living player in the open forest at day, long past the respawn grace.
	local function ctx(extra)
		local value = { alive = true, safe = false, night = false, farFromBase = false, dangerousZone = false,
			longExpedition = false, storm = false, siluetaActive = false, respawnedAt = -1000, biomes = {} }
		for k, v in pairs(extra or {}) do value[k] = v end
		return value
	end
	local BOTH = { Cemetery = true, Swamp = true }

	case("NB2 config: the pack's numbers (director, Viper, Pouncer, Gargoyle and Mire)", function()
		local D = Config.DIRECTOR
		equal(D.TICK_SECONDS, 10); equal(D.MAX_POINTS, 3); equal(D.MAX_ACTIVE, 2)
		near(D.MAX_CHANCE, 0.20); equal(D.MAX_MULTIPLIER, 4); equal(D.GLOBAL_COOLDOWN, 15); equal(D.RESPAWN_GRACE, 10)
		local M = D.MULTIPLIERS
		equal(M.night, 2); near(M.farFromBase, 1.2); near(M.dangerousZone, 1.5); near(M.longExpedition, 1.3)
		equal(M.storm, 1, "no weather system yet: storm stays x1")
		local V, P, G, Mi = Config.BEASTS.Viper, Config.BEASTS.Pouncer, Config.BEASTS.Gargoyle, Config.BEASTS.Mire
		equal(V.points, 1); near(V.chance, 1 / 45); equal(V.cooldown, 35); equal(V.biome, nil)
		equal(P.points, 1); near(P.chance, 1 / 55); equal(P.cooldown, 40); equal(P.biome, nil)
		equal(G.points, 2); equal(G.biome, "Cemetery"); equal(Mi.points, 2); equal(Mi.biome, "Swamp")
		equal(Config.ORDER[1], "Viper"); equal(Config.ORDER[2], "Pouncer"); equal(#Config.ORDER, 4)
	end)

	case("NB2: multipliers multiply, only for real conditions, capped at x4", function()
		near(Director.multiplier(ctx()), 1, "day in the open")
		near(Director.multiplier(ctx({ night = true })), 2)
		near(Director.multiplier(ctx({ farFromBase = true, dangerousZone = true })), 1.2 * 1.5)
		near(Director.multiplier(ctx({ night = true, farFromBase = true, dangerousZone = true })), 3.6)
		near(Director.multiplier(ctx({ night = true, farFromBase = true, dangerousZone = true, longExpedition = true })), 4,
			"2 x 1.2 x 1.5 x 1.3 = 4.68, capped at 4")
		near(Director.multiplier(ctx({ storm = true })), 1, "storm x1")
		near(Director.multiplier(ctx({ night = "yes", farFromBase = 1 })), 1, "only true counts")
		near(Director.multiplier(nil), 1)
	end)

	case("NB2: pEff = clamp(pBase x product, 0, 0.20), per 10 s roll, never a percentage by mistake", function()
		near(Director.chance("Viper", ctx()), 1 / 45)
		near(Director.chance("Viper", ctx({ night = true })), 2 / 45)
		near(Director.chance("Pouncer", ctx({ night = true, farFromBase = true, dangerousZone = true, longExpedition = true })), 4 / 55)
		equal(Director.chance("Nobody", ctx()), 0)
		-- The 0.20 cap, through a hypothetical tuned base chance.
		near(Director.chance("Viper", ctx({ night = true, farFromBase = true, dangerousZone = true, longExpedition = true }),
			{ chance = 0.08 }), 0.20, "0.32 is clamped to 0.20")
		equal(Director.chance("Viper", ctx(), { chance = -1 }), 0, "never negative")
	end)

	case("NB2: a won roll reserves the beast atomically; budget and concurrency are server counters", function()
		local dir = Director.new({ random = always(0) })
		local started, rejects = Director.tick(dir, 7, ctx(), 100)
		equal(#started, 2, "both global beasts win at roll 0 and fit (1 + 1)")
		equal(#rejects, 0)
		local points, count = Director.budget(dir, 7)
		equal(points, 2); equal(count, 2)
		assert(started[1].id ~= started[2].id, "unique encounter ids")
		equal(started[1].userId, 7, "the target is the rolling player")
		local seen = {}
		for _, enc in ipairs(started) do seen[enc.beast] = true end
		assert(seen.Viper and seen.Pouncer, "one of each")
	end)

	case("NB2: a lost roll starts nothing", function()
		local dir = Director.new({ random = always(0.999) })
		local started = Director.tick(dir, 7, ctx(), 100)
		equal(#started, 0)
		equal(select(2, Director.budget(dir, 7)), 0)
	end)

	case("NB2: dead or safe players are not rolled at all", function()
		local calls = 0
		local dir = Director.new({ random = function() calls += 1; return 0 end })
		equal(#Director.tick(dir, 1, ctx({ alive = false }), 100), 0)
		equal(#Director.tick(dir, 1, ctx({ safe = true }), 100), 0)
		equal(calls, 0, "no roll is spent")
	end)

	case("NB2: no spawn within 10 s of a respawn, no beast while that player's Silueta hunts or telegraphs", function()
		local dir = Director.new({ random = always(0) })
		local started, rejects = Director.tick(dir, 1, ctx({ respawnedAt = 95 }), 100)
		equal(#started, 0); equal(rejects[1].reason, "RespawnGrace")
		started = Director.tick(dir, 1, ctx({ respawnedAt = 90 }), 100)
		equal(#started, 2, "exactly 10 s later is allowed")
		local other = Director.new({ random = always(0) })
		started, rejects = Director.tick(other, 2, ctx({ siluetaActive = true }), 100)
		equal(#started, 0); equal(rejects[1].reason, "SiluetaActive")
	end)

	case("NB2: release is exactly once, and only then starts the global and species cooldowns", function()
		local dir = Director.new({ random = always(0) })
		local ok, enc = Director.reserve(dir, 3, "Viper", ctx(), 100)
		assert(ok, "reserve")
		equal(Director.release(dir, enc.id, "Escape", 120), true, "first release")
		equal(Director.release(dir, enc.id, "Death", 121), false, "second release is a no-op")
		equal(Director.release(dir, enc.id, "Timeout", 122), false)
		equal(Director.release(dir, "beast:unknown", "Error", 122), false)
		local points, count = Director.budget(dir, 3)
		equal(points, 0, "the point came back once"); equal(count, 0)
		equal(dir.counts.released, 1)
		-- Global cooldown 15 s after the end (any beast), species cooldown 35 s for Viper.
		equal(select(2, Director.reserve(dir, 3, "Pouncer", ctx(), 134.9)), "GlobalCooldown")
		assert(Director.reserve(dir, 3, "Pouncer", ctx(), 135), "Pouncer after 15 s")
		equal(select(2, Director.reserve(dir, 3, "Viper", ctx(), 154.9)), "SpeciesCooldown")
		assert(Director.reserve(dir, 3, "Viper", ctx(), 155), "Viper after 35 s")
	end)

	case("NB2: every end reason releases once (death, escape, timeout, safe zone, leave, error)", function()
		for i, reason in ipairs({ "Death", "Escape", "Timeout", "SafeZone", "Leave", "Error", "Done", "NoSpawn" }) do
			local dir = Director.new({ random = always(0) })
			local _, enc = Director.reserve(dir, i, "Pouncer", ctx(), 0)
			equal(Director.release(dir, enc.id, reason, 1), true, reason)
			equal(Director.release(dir, enc.id, reason, 2), false, reason .. " twice")
			equal(Director.budget(dir, i), 0, reason .. " budget")
		end
	end)

	case("NB2: a player leaving releases every encounter once", function()
		local dir = Director.new({ random = always(0) })
		Director.tick(dir, 9, ctx(), 0)
		local ids = Director.forget(dir, 9, 5)
		equal(#ids, 2)
		equal(Director.budget(dir, 9), 0)
		equal(Director.release(dir, ids[1], "Leave", 6), false, "already released by the leave")
		equal(dir.players[9], nil, "no reference to the user is kept")
	end)

	case("NB2: no two of the same beast for one player, and one player's roll never creates another's encounter", function()
		local dir = Director.new({ random = always(0) })
		assert(Director.reserve(dir, 1, "Viper", ctx(), 0))
		equal(select(2, Director.reserve(dir, 1, "Viper", ctx(), 0, { force = true })), "AlreadyActive")
		local started = Director.tick(dir, 2, ctx(), 0)
		equal(#started, 2, "player 2 has their own budget")
		for _, enc in ipairs(started) do equal(enc.userId, 2) end
		equal(Director.budget(dir, 1), 1, "player 1 unchanged")
	end)

	case("S02: Gargoyle then Viper on one player: 2 + 1 = 3 points, 2 encounters", function()
		local dir = Director.new({ random = always(0) })
		assert(Director.reserve(dir, 1, "Gargoyle", ctx({ biomes = BOTH }), 0, { force = true }), "Gargoyle")
		assert(Director.reserve(dir, 1, "Viper", ctx({ biomes = BOTH }), 0, { force = true }), "Viper")
		local points, count = Director.budget(dir, 1)
		equal(points, 3); equal(count, 2)
	end)

	case("S03: with Gargoyle and Viper active a forced Pouncer is refused, with the reason logged", function()
		local dir = Director.new({ random = always(0) })
		Director.reserve(dir, 1, "Gargoyle", ctx({ biomes = BOTH }), 0, { force = true })
		Director.reserve(dir, 1, "Viper", ctx({ biomes = BOTH }), 0, { force = true })
		local ok, why = Director.reserve(dir, 1, "Pouncer", ctx({ biomes = BOTH }), 0, { force = true })
		equal(ok, false); equal(why, "MaxActive", "two encounters already, even before the budget")
		local last = dir.log[#dir.log]
		equal(last.reason, "MaxActive"); equal(last.beast, "Pouncer"); equal(last.userId, 1)
		equal(Director.budget(dir, 1), 3, "nothing was reserved")
	end)

	case("S04: Gargoyle and Mire together: the second is refused because 2 + 2 > 3", function()
		local dir = Director.new({ random = always(0) })
		assert(Director.reserve(dir, 1, "Gargoyle", ctx({ biomes = BOTH }), 0, { force = true }))
		local ok, why = Director.reserve(dir, 1, "Mire", ctx({ biomes = BOTH }), 0, { force = true })
		equal(ok, false); equal(why, "Budget")
		equal(Director.budget(dir, 1), 2)
	end)

	case("NB2: biome beasts never leave their biome (no Cementerio or Pantano exists yet)", function()
		local dir = Director.new({ random = always(0) })
		equal(select(2, Director.reserve(dir, 1, "Gargoyle", ctx(), 0, { force = true })), "Biome", "even forced")
		equal(select(2, Director.reserve(dir, 1, "Mire", ctx({ biomes = { Cemetery = true } }), 0, { force = true })), "Biome")
		local started = Director.tick(dir, 1, ctx(), 0)
		for _, enc in ipairs(started) do assert(enc.beast == "Viper" or enc.beast == "Pouncer", enc.beast) end
	end)

	case("NB2: no queue of won rolls: a win without budget is discarded and logged, never retried", function()
		local dir = Director.new({ random = always(0) })
		Director.reserve(dir, 1, "Gargoyle", ctx({ biomes = BOTH }), 0, { force = true })
		-- Two points used: one more global beast fits, the second won roll is discarded.
		local started, rejects = Director.tick(dir, 1, ctx({ biomes = BOTH }), 10)
		equal(#started, 1)
		local reasons = {}
		for _, r in ipairs(rejects) do reasons[r.beast] = r.reason end
		assert(reasons.Mire == "Budget" or reasons.Mire == "MaxActive", "Mire refused: " .. tostring(reasons.Mire))
		equal(#(dir.pending or {}), 0, "nothing waits for later")
		-- Next tick at a losing roll: nothing starts from the old win.
		dir.random = always(0.999)
		Director.release(dir, started[1].id, "Escape", 11)
		equal(#Director.tick(dir, 1, ctx({ biomes = BOTH }), 40), 0)
	end)

	case("NB2: two won rolls in one tick are assigned in a stable random order", function()
		-- First value shuffles, the rest roll. A seeded source gives the same order twice.
		local function run()
			local dir = Director.new({ random = sequence({ 0.9, 0.0, 0.0, 0.0, 0.0 }) })
			local started = Director.tick(dir, 1, ctx(), 0)
			local names = {}
			for _, enc in ipairs(started) do table.insert(names, enc.beast) end
			return table.concat(names, ",")
		end
		equal(run(), run(), "deterministic under the same seed")
		local dirA = Director.new({ random = sequence({ 0.0, 0.0, 0.0 }) })
		local dirB = Director.new({ random = sequence({ 0.99, 0.0, 0.0 }) })
		local a, b = Director.tick(dirA, 1, ctx(), 0), Director.tick(dirB, 1, ctx(), 0)
		assert(a[1].beast ~= b[1].beast, "the shuffle roll changes who is assigned first")
	end)

	case("S05: 1000 simulated rolls by day and by night land near the configured odds (no guarantee)", function()
		local function count(night, seed)
			local rng = Random.new(seed)
			local dir = Director.new({ random = function() return rng:NextNumber() end })
			local wins = 0
			for i = 1, 1000 do
				local started = Director.tick(dir, 1, ctx({ night = night }), i * 1000)
				for _, enc in ipairs(started) do
					if enc.beast == "Viper" then wins += 1 end
					Director.release(dir, enc.id, "Done", i * 1000)
				end
			end
			return wins
		end
		local day, night = count(false, 4242), count(true, 4242)
		-- Expected 22.2 by day (sd 4.7) and 44.4 by night (sd 6.5); 4 sd either side.
		assert(day >= 4 and day <= 41, "day wins " .. day)
		assert(night >= 18 and night <= 71, "night wins " .. night)
		assert(night > day, ("night %d should beat day %d"):format(night, day))
		result.messages.S05 = ("Viper wins in 1000 ticks: day %d, night %d"):format(day, night)
	end)

	case("NB2: the director is pure: no world, no clock, no global random", function()
		for _, banned in ipairs({ "game:", "workspace", "task.", "os.clock", "os.time", "math.random", "Random.new" }) do
			assert(not source:find(banned, 1, true), "director source uses " .. banned)
		end
		assert(not source:find("[^%.%w_]tick%("), "director source calls the global tick()")
	end)

	return result
end

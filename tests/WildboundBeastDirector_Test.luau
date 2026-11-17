-- Invoke with require(freshTestClone)(require(freshBeastDirectorClone), freshBeastDirectorClone.Source,
-- require(freshBeastConfigClone)).
-- Nest Heist phase 4a (NB2, docs/design/beast-pack/00_INTEGRACION_DE_BESTIAS.md and CONFIG_INICIAL.json): the one beast
-- director. Each living player outside a safe zone gets an independent roll per eligible beast; a won roll becomes an
-- encounter only if the per-player threat budget (3 points, 2 encounters) and every cooldown allow it, and the
-- reservation is released exactly once. Wave 2 (odd/tasks/wildbound-beasts-wave2.md): the rolls run on a 20 s calendar,
-- 1 s apart per beast (Director.tick = Director.due + Director.roll); the NB2 cases below call Director.roll directly,
-- with the two original beasts where the case is about them. Fake players and an injected random source; no world.
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
	-- The two original global beasts, for the NB2 cases written before wave 2.
	local OLD = { "Viper", "Pouncer" }
	-- p20 = 1 - (1 - p10)^2: a 10 s base chance carried to the 20 s roll.
	local function p20(p10) return 1 - (1 - p10) ^ 2 end
	-- Deliberately changed (PF7, odd/tasks/wildbound-caramelo-playfix.md, "more frequency of beasts"): the rolled beasts'
	-- base chances per 10 s went up moderately: Viper (and the wave 2 four, which use Viper's) 1/45 -> 1/32, Pouncer
	-- 1/55 -> 1/40, Scuttler 1/60 -> 1/45 (still the rarest); MAX_CHANCE, the multipliers and the strike rules stay.
	local V10, P10, S10 = 1 / 32, 1 / 40, 1 / 45

	case("NB2 config: the pack's numbers (director, Viper, Pouncer, Gargoyle and Mire)", function()
		local D = Config.DIRECTOR
		equal(D.TICK_SECONDS, 20, "wave 2: 20 s"); equal(D.BEAST_OFFSET, 1); equal(D.MAX_POINTS, 3); equal(D.MAX_ACTIVE, 2)
		equal(D.INITIAL_RISK, 1)
		near(D.MAX_CHANCE, p20(0.20), "0.20 per 10 s carried to 20 s"); equal(D.MAX_MULTIPLIER, 4)
		equal(D.GLOBAL_COOLDOWN, 10, "PF7: 15 -> 10"); equal(D.RESPAWN_GRACE, 10)
		local M = D.MULTIPLIERS
		equal(M.night, 2); near(M.farFromBase, 1.2); near(M.dangerousZone, 1.5); near(M.longExpedition, 1.3)
		equal(M.storm, 1, "no weather system yet: storm stays x1")
		near(M.egg, 1.2, "the egg step (a hypothesis to tune)")
		equal(D.CONDITIONS.egg, "carryingEgg")
		local V, P, G, Mi = Config.BEASTS.Viper, Config.BEASTS.Pouncer, Config.BEASTS.Gargoyle, Config.BEASTS.Mire
		equal(V.points, 1); near(V.chance10, V10); near(V.chance, p20(V10)); equal(V.cooldown, 35); equal(V.biome, nil)
		equal(P.points, 1); near(P.chance10, P10); near(P.chance, p20(P10)); equal(P.cooldown, 40); equal(P.biome, nil)
		equal(G.points, 2); equal(G.biome, "Cemetery"); equal(Mi.points, 2); equal(Mi.biome, "Swamp")
		near(G.chance, p20(1 / 100)); near(Mi.chance, p20(1 / 80))
		equal(Config.ORDER[1], "Viper"); equal(Config.ORDER[2], "Pouncer"); equal(#Config.ORDER, 9, "SC1: Scuttler is ninth")
	end)

	-- Wave 2 config (pack 04_CONFIG_BALANCE_PROPUESTA.json, owner decision 2026-11-11).
	case("BW2 config: the four new beasts, 2 points each, Root only in the Pantano, Viper's base chance", function()
		for _, name in ipairs({ "Streamer", "Root", "Gaze", "Lurker" }) do
			local B = Config.BEASTS[name]
			assert(B, name)
			equal(B.points, 2, name .. " points"); equal(B.riskModifier, 1, name)
			near(B.chance10, V10, name .. " uses Viper's base chance (PROPUESTA)")
			near(B.chance, p20(V10), name .. ": 1 - (1 - Viper's)^2")
			equal(B.cooldown, 35, name .. " uses Viper's cooldown (PROPUESTA)")
			equal(Config.PLAYABLE[name], true, name .. " is playable"); equal(Config.WAVE2[name], true)
			assert(type(B.tuning) == "table" and table.isfrozen(B.tuning), name .. " tuning frozen")
		end
		equal(Config.BEASTS.Root.category, "Biome"); equal(Config.BEASTS.Root.biome, "Swamp")
		for _, name in ipairs({ "Streamer", "Gaze", "Lurker" }) do
			equal(Config.BEASTS[name].category, "Global", name); equal(Config.BEASTS[name].biome, nil, name)
		end
		equal(Config.PLAYABLE.Gargoyle, nil, "no behaviour"); equal(Config.PLAYABLE.Mire, nil, "no behaviour")
		local S, R, Gz, L = Config.BEASTS.Streamer.tuning, Config.BEASTS.Root.tuning, Config.BEASTS.Gaze.tuning,
			Config.BEASTS.Lurker.tuning
		equal(S.RushTelegraphSeconds, 0.9); equal(S.RushSpeedStudsPerSecond, 52); equal(S.RushDamage, 28)
		equal(R.TrapTelegraphSeconds, 1.15); equal(R.SafeGapMinimumStuds, 9); equal(R.MaxActiveRootSegments, 12)
		equal(Gz.SightConeDegrees, 17); equal(Gz.ExposureToAttackSeconds, 3.5); equal(Gz.ZoneRadiusStuds, 7)
		equal(L.LeapTelegraphSeconds, 0.8); equal(L.LeapTravelSeconds, 0.55); equal(L.LeapOverrunDistanceStuds, 7)
		equal(Config.BEASTS.Root.trapLanes * Config.BEASTS.Root.trapSegments, R.MaxActiveRootSegments)
	end)

	case("BW2 config: every dodgeable tell is at least the 0.8 s fair-strike lead", function()
		local S, R, Gz, L = Config.BEASTS.Streamer.tuning, Config.BEASTS.Root.tuning, Config.BEASTS.Gaze.tuning,
			Config.BEASTS.Lurker.tuning
		for label, seconds in pairs({ rush = S.RushTelegraphSeconds, trap = R.TrapTelegraphSeconds,
			whip = R.WhipTelegraphSeconds, zone = Gz.ZoneTelegraphSeconds, leap = L.LeapTelegraphSeconds + L.LeapTravelSeconds,
			scream = S.WarningSeconds + S.ScreamWindupSeconds }) do
			assert(seconds >= Config.MIN_TELL - 1e-9, label .. " tell " .. seconds)
		end
	end)

	-- Wave 2 calendar (pack 01_SISTEMA_COMPARTIDO section 2).
	case("BW2 calendar: anchor, first slot one interval later, beasts 1 s apart, every 20 s", function()
		local dir = Director.new({ random = always(0.999) })
		local function dueAt(t)
			local list = Director.due(dir, 5, t)
			table.sort(list)
			return table.concat(list, ",")
		end
		equal(dueAt(100), "", "the first call only anchors")
		equal(dueAt(119.99), "", "nothing before anchor + 20")
		equal(dueAt(120), "Viper", "Viper at anchor + 20")
		equal(dueAt(120.5), "", "consumed")
		equal(dueAt(121), "Pouncer", "Pouncer 1 s later")
		equal(dueAt(122), "Gargoyle"); equal(dueAt(123), "Mire"); equal(dueAt(124), "Streamer")
		equal(dueAt(125), "Root"); equal(dueAt(126), "Gaze"); equal(dueAt(127), "Lurker")
		equal(dueAt(128), "Scuttler", "SC1: the ninth beast 8 s after Viper")
		equal(dueAt(139.9), ""); equal(dueAt(140), "Viper", "every 20 s")
		equal(Director.nextSlot(dir, 5, "Viper", 140.1), 160)
		equal(Director.nextSlot(dir, 5, "Lurker", 140.1), 147)
	end)

	case("BW2 calendar: a stall never accumulates rolls; only the newest slot counts", function()
		local calls = 0
		local dir = Director.new({ random = function() calls += 1; return 0.999 end })
		Director.tick(dir, 5, ctx(), 0)
		-- 100 s with no poll: five Viper slots passed; one roll at most.
		local due = Director.due(dir, 5, 100.5)
		local viper = 0
		for _, name in ipairs(due) do if name == "Viper" then viper += 1 end end
		equal(viper, 1, "one Viper roll, not five")
		equal(#Director.due(dir, 5, 100.6), 0, "and nothing pending afterwards")
		-- Just before 120 the other beasts' slots (101 to 107) are due, never Viper's next one.
		for _, name in ipairs(Director.due(dir, 5, 119.9)) do assert(name ~= "Viper", "Viper before its slot") end
		equal(Director.due(dir, 5, 120)[1], "Viper", "the calendar keeps its phase (anchor + k x 20)")
	end)

	case("BW2 calendar: a dead or safe player consumes the slot with no roll and nothing waits", function()
		local calls = 0
		local dir = Director.new({ random = function() calls += 1; return 0 end })
		Director.tick(dir, 5, ctx(), 0)
		equal(#Director.tick(dir, 5, ctx({ safe = true }), 20), 0)
		equal(#Director.tick(dir, 5, ctx({ alive = false }), 21), 0)
		for t = 22, 28 do Director.tick(dir, 5, ctx({ alive = false }), t) end -- SC1: Scuttler's slot is at 28
		equal(calls, 0, "no roll spent")
		equal(#Director.tick(dir, 5, ctx(), 28.5), 0, "the missed slots are not made up")
		local started = Director.tick(dir, 5, ctx(), 40)
		equal(#started, 1, "Viper's next slot rolls"); equal(started[1].beast, "Viper")
	end)

	case("BW2: no roll while that beast already chases the player, or without capacity; never kept for later", function()
		local calls = 0
		local dir = Director.new({ random = function() calls += 1; return 0 end })
		assert(Director.reserve(dir, 1, "Streamer", ctx(), 0), "Streamer chasing")
		local started, refused = Director.roll(dir, 1, ctx(), 0, { "Streamer" })
		equal(#started, 0); equal(refused[1].reason, "AlreadyActive"); equal(refused[1].rolled, false)
		equal(calls, 0, "no roll spent on the chasing beast")
		-- 2 points used: another 2-point beast does not fit (2 + 2 > 3) and does not roll.
		started, refused = Director.roll(dir, 1, ctx(), 0, { "Gaze" })
		equal(#started, 0); equal(refused[1].reason, "Budget"); equal(calls, 0)
		-- A 1-point beast fits (2 + 1 = 3): it rolls and starts.
		started = Director.roll(dir, 1, ctx(), 0, { "Viper" })
		equal(#started, 1); equal(Director.budget(dir, 1), 3)
		equal(dir.counts.skipped, 2)
	end)

	case("BW2: release refunds the 2 points at once, exactly once; the beast can roll again after its cooldown", function()
		local dir = Director.new({ random = always(0) })
		local ok, enc = Director.reserve(dir, 1, "Lurker", ctx(), 0)
		assert(ok)
		equal(Director.budget(dir, 1), 2)
		equal(Director.release(dir, enc.id, "Done", 10), true)
		equal(Director.budget(dir, 1), 0, "refunded at once")
		equal(Director.release(dir, enc.id, "Done", 10), false, "exactly once")
		equal(select(2, Director.reserve(dir, 1, "Lurker", ctx(), 44.9)), "SpeciesCooldown")
		assert(Director.reserve(dir, 1, "Lurker", ctx(), 45), "35 s later")
	end)

	case("BW2 matrix: allowed and blocked pairs under capacity 3", function()
		for _, pair in ipairs({ { "Streamer", "Viper", true }, { "Gaze", "Viper", true }, { "Lurker", "Pouncer", true },
			{ "Streamer", "Gaze", false }, { "Gaze", "Lurker", false } }) do
			local dir = Director.new({ random = always(0) })
			assert(Director.reserve(dir, 1, pair[1], ctx(), 0, { force = true }), pair[1])
			local ok, why = Director.reserve(dir, 1, pair[2], ctx(), 0, { force = true })
			equal(ok, pair[3], pair[1] .. " + " .. pair[2])
			if not pair[3] then equal(why, "Budget") end
		end
		local dir = Director.new({ random = always(0) })
		assert(Director.reserve(dir, 1, "Root", ctx({ biomes = { Swamp = true } }), 0, { force = true }))
		equal(select(2, Director.reserve(dir, 1, "Streamer", ctx({ biomes = { Swamp = true } }), 0, { force = true })), "Budget",
			"Streamer + Root = 4")
		assert(Director.reserve(dir, 1, "Pouncer", ctx({ biomes = { Swamp = true } }), 0, { force = true }), "Root + Pouncer = 3")
	end)

	case("BIOME-OFF: with BIOME_PREFERENCE off every playable beast rolls anywhere except Pradera", function()
		equal(Config.BIOME_PREFERENCE, false, "the switch is off for now (owner, 2026-11-14)")
		for name in pairs(Config.PLAYABLE) do
			equal(Config.homeBiome(name), nil, name .. " has no home biome while the switch is off")
			equal(Config.categoryOf(name), "Global", name .. " acts as a global beast")
			for _, biomes in ipairs({ {}, { Swamp = true }, { Cemetery = true }, { Swamp = true, Cemetery = true } }) do
				equal(Director.placeBlock(name, ctx({ biomes = biomes })), nil, name .. " outside Pradera")
			end
			equal(Director.placeBlock(name, ctx({ biomes = { Meadow = true } })), "NoGlobalZone", name .. " never in Pradera")
			equal(Director.placeBlock(name, ctx({ biomes = { Meadow = true, Swamp = true } })), "NoGlobalZone",
				name .. ": Pradera wins over any other tag")
		end
		local dir = Director.new({ random = always(0) })
		local started = Director.roll(dir, 1, ctx(), 0, { "Root" })
		equal(#started, 1, "Root rolls in the open forest"); equal(started[1].beast, "Root")
		equal(#Director.roll(dir, 2, ctx({ biomes = { Meadow = true } }), 0, { "Root" }), 0, "no Root in Pradera")
		local forced = Director.new({ random = always(0) })
		equal(select(2, Director.reserve(forced, 1, "Root", ctx({ biomes = { Meadow = true } }), 0, { force = true })),
			"NoGlobalZone", "not even forced")
	end)

	case("BIOME-OFF: the preference data stays and comes back with the switch on; config-only beasts keep their biome", function()
		equal(Config.BEASTS.Root.biome, "Swamp", "data kept"); equal(Config.BEASTS.Root.category, "Biome", "data kept")
		equal(Config.homeBiome("Root", true), "Swamp", "switch on: Root needs the Pantano again")
		equal(Config.categoryOf("Root", true), "Biome")
		for _, name in ipairs({ "Viper", "Pouncer", "Streamer", "Gaze", "Lurker" }) do
			equal(Config.homeBiome(name, true), nil, name); equal(Config.categoryOf(name, true), "Global", name)
		end
		-- Gargoyle and Mire have no behaviour: never rolled, and the switch does not touch their biome.
		equal(Config.homeBiome("Gargoyle"), "Cemetery"); equal(Config.homeBiome("Mire"), "Swamp")
		equal(Config.categoryOf("Gargoyle"), "Biome"); equal(Config.categoryOf("Mire"), "Biome")
		equal(Config.homeBiome("Nope"), nil); equal(Config.categoryOf("Nope"), nil)
		equal(Director.placeBlock("Mire", ctx()), "Biome")
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

	case("NB2: pEff = clamp(pBase x product, 0, MAX_CHANCE), per 20 s roll, never a percentage by mistake", function()
		near(Director.chance("Viper", ctx()), p20(V10))
		near(Director.chance("Viper", ctx({ night = true })), 2 * p20(V10))
		near(Director.chance("Pouncer", ctx({ night = true, farFromBase = true, dangerousZone = true, longExpedition = true })),
			4 * p20(P10))
		equal(Director.chance("Nobody", ctx()), 0)
		-- The cap (0.20 per 10 s carried to 0.36 per 20 s), through a hypothetical tuned base chance.
		near(Director.chance("Viper", ctx({ night = true, farFromBase = true, dangerousZone = true, longExpedition = true }),
			{ chance = 0.12 }), p20(0.20), "0.48 is clamped to 0.36")
		equal(Director.chance("Viper", ctx(), { chance = -1 }), 0, "never negative")
	end)

	case("NB2: a won roll reserves the beast atomically; budget and concurrency are server counters", function()
		local dir = Director.new({ random = always(0) })
		local started, rejects = Director.roll(dir, 7, ctx(), 100, OLD)
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
		local started = Director.roll(dir, 7, ctx(), 100, OLD)
		equal(#started, 0)
		equal(select(2, Director.budget(dir, 7)), 0)
	end)

	case("NB2: dead or safe players are not rolled at all", function()
		local calls = 0
		local dir = Director.new({ random = function() calls += 1; return 0 end })
		equal(#Director.roll(dir, 1, ctx({ alive = false }), 100), 0)
		equal(#Director.roll(dir, 1, ctx({ safe = true }), 100), 0)
		equal(calls, 0, "no roll is spent")
	end)

	case("NB2: no spawn within 10 s of a respawn, no beast while that player's Silueta hunts or telegraphs", function()
		local dir = Director.new({ random = always(0) })
		local started, rejects = Director.roll(dir, 1, ctx({ respawnedAt = 95 }), 100, OLD)
		equal(#started, 0); equal(rejects[1].reason, "RespawnGrace")
		started = Director.roll(dir, 1, ctx({ respawnedAt = 90 }), 100, OLD)
		equal(#started, 2, "exactly 10 s later is allowed")
		local other = Director.new({ random = always(0) })
		started, rejects = Director.roll(other, 2, ctx({ siluetaActive = true }), 100, OLD)
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
		-- Global cooldown (PF7: 10 s, was 15) after the end (any beast), species cooldown 35 s for Viper.
		equal(select(2, Director.reserve(dir, 3, "Pouncer", ctx(), 129.9)), "GlobalCooldown")
		assert(Director.reserve(dir, 3, "Pouncer", ctx(), 130), "Pouncer after 10 s")
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
		Director.roll(dir, 9, ctx(), 0, OLD)
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
		local started = Director.roll(dir, 2, ctx(), 0, OLD)
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

	case("NB2: biome beasts never leave their biome", function()
		local dir = Director.new({ random = always(0) })
		equal(select(2, Director.reserve(dir, 1, "Gargoyle", ctx(), 0, { force = true })), "Biome", "even forced")
		equal(select(2, Director.reserve(dir, 1, "Mire", ctx({ biomes = { Cemetery = true } }), 0, { force = true })), "Biome")
		local started = Director.roll(dir, 1, ctx(), 0)
		for _, enc in ipairs(started) do assert(Config.categoryOf(enc.beast) == "Global", enc.beast) end
	end)

	case("NB2: no queue of won rolls: a win without budget is discarded and logged, never retried", function()
		local dir = Director.new({ random = always(0) })
		Director.reserve(dir, 1, "Gargoyle", ctx({ biomes = BOTH }), 0, { force = true })
		-- Two points used: one more 1-point beast fits, then the other one finds no room: it is not rolled, nothing waits.
		local started, rejects = Director.roll(dir, 1, ctx({ biomes = BOTH }), 10, { "Viper", "Pouncer", "Root" })
		equal(#started, 1)
		local reasons = {}
		for _, r in ipairs(rejects) do reasons[r.beast] = r.reason end
		assert(reasons.Root == "Budget" or reasons.Root == "MaxActive", "Root refused: " .. tostring(reasons.Root))
		equal(#(dir.pending or {}), 0, "nothing waits for later")
		-- Next tick at a losing roll: nothing starts from the old win.
		dir.random = always(0.999)
		Director.release(dir, started[1].id, "Escape", 11)
		equal(#Director.roll(dir, 1, ctx({ biomes = BOTH }), 40, OLD), 0)
	end)

	case("NB2: two won rolls in one tick are assigned in a stable random order", function()
		-- First value shuffles, the rest roll. A seeded source gives the same order twice.
		local function run()
			local dir = Director.new({ random = sequence({ 0.9, 0.0, 0.0, 0.0, 0.0 }) })
			local started = Director.roll(dir, 1, ctx(), 0, OLD)
			local names = {}
			for _, enc in ipairs(started) do table.insert(names, enc.beast) end
			return table.concat(names, ",")
		end
		equal(run(), run(), "deterministic under the same seed")
		local dirA = Director.new({ random = sequence({ 0.0, 0.0, 0.0 }) })
		local dirB = Director.new({ random = sequence({ 0.99, 0.0, 0.0 }) })
		local a, b = Director.roll(dirA, 1, ctx(), 0, OLD), Director.roll(dirB, 1, ctx(), 0, OLD)
		assert(a[1].beast ~= b[1].beast, "the shuffle roll changes who is assigned first")
	end)

	case("S05: 1000 simulated rolls by day and by night land near the configured odds (no guarantee)", function()
		local function count(night, seed)
			local rng = Random.new(seed)
			local dir = Director.new({ random = function() return rng:NextNumber() end })
			local wins = 0
			for i = 1, 1000 do
				local started = Director.roll(dir, 1, ctx({ night = night }), i * 1000, OLD)
				for _, enc in ipairs(started) do
					if enc.beast == "Viper" then wins += 1 end
					Director.release(dir, enc.id, "Done", i * 1000)
				end
			end
			return wins
		end
		local day, night = count(false, 4242), count(true, 4242)
		-- Per 20 s roll (PF7: Viper 1/32 per 10 s): expected 61.5 by day (sd 7.6) and 123.0 by night (sd 10.4); 4 sd
		-- either side.
		assert(day >= 31 and day <= 92, "day wins " .. day)
		assert(night >= 81 and night <= 165, "night wins " .. night)
		assert(night > day, ("night %d should beat day %d"):format(night, day))
		result.messages.S05 = ("Viper wins in 1000 ticks: day %d, night %d"):format(day, night)
	end)

	-- Beast spawn P0 (docs/design/wildbound-beast-spawn.md sections 2, 5 and 6).
	case("BS-P0 config: every beast has a category from the taxonomy and a neutral risk modifier", function()
		equal(Config.BEASTS.Viper.category, "Global"); equal(Config.BEASTS.Pouncer.category, "Global")
		equal(Config.BEASTS.Gargoyle.category, "Biome"); equal(Config.BEASTS.Mire.category, "Biome")
		for _, name in ipairs(Config.ORDER) do
			local beast = Config.BEASTS[name]
			assert(Config.CATEGORIES[beast.category], name .. " category")
			equal(beast.riskModifier, 1, name .. " riskModifier")
			equal(beast.category == "Biome", beast.biome ~= nil, name .. ": a biome beast has a biome, a global one none")
		end
		equal(Config.NO_GLOBAL_BIOMES.Meadow, true, "Pradera")
		near(Director.chance("Viper", ctx()), p20(V10), "riskModifier 1 changes nothing")
		near(Director.chance("Viper", ctx(), { chance = 0.01, riskModifier = 2 }), 0.02, "a tuned modifier scales the base")
	end)

	case("BS-P0: carrying an egg raises the chance by the egg step and never past MAX_MULTIPLIER or MAX_CHANCE", function()
		local D = Config.DIRECTOR
		near(Director.multiplier(ctx({ carryingEgg = true })), 1.2)
		near(Director.chance("Viper", ctx({ carryingEgg = true })), 1.2 * p20(V10))
		near(Director.chance("Pouncer", ctx({ carryingEgg = true, night = true })), 2.4 * p20(P10))
		near(Director.multiplier(ctx({ carryingEgg = "yes" })), 1, "only true counts")
		near(Director.multiplier(ctx({ egg = true })), 1, "the context field is carryingEgg")
		local all = ctx({ carryingEgg = true, night = true, farFromBase = true, dangerousZone = true, longExpedition = true })
		near(Director.multiplier(all), D.MAX_MULTIPLIER, "capped at x4 with the egg")
		near(Director.multiplier(ctx({ carryingEgg = true, night = true, farFromBase = true, dangerousZone = true })), 4,
			"2 x 1.2 x 1.5 x 1.2 = 4.32, capped at 4")
		near(Director.chance("Viper", all, { chance = 0.12 }), D.MAX_CHANCE, "0.48 clamps to 0.36 with the egg")
		near(Director.chance("Viper", ctx({ carryingEgg = true }), { chance = 0.34 }), D.MAX_CHANCE, "0.408 clamps to 0.36")
		local dir = Director.new({ random = always(1.15 * p20(V10)) })
		equal(#Director.roll(dir, 1, ctx(), 0, OLD), 0, "without the egg a roll just over the base loses")
		local started = Director.roll(dir, 2, ctx({ carryingEgg = true }), 0, OLD)
		local viper = false
		for _, enc in ipairs(started) do viper = viper or enc.beast == "Viper" end
		assert(viper, "with the egg the same roll wins Viper")
	end)

	case("BS-P0: the dusk roll buff multiplies inside the cap, clamped to WildboundDusk's 1 to 1.5", function()
		near(Director.multiplier(ctx({ duskRoll = 1.25 })), 1.25)
		near(Director.chance("Viper", ctx({ duskRoll = 1.25 })), 1.25 * p20(V10))
		near(Director.multiplier(ctx({ duskRoll = 1 })), 1, "x1 outside Dusk")
		near(Director.multiplier(ctx({ duskRoll = 0.5 })), 1, "never a slowdown")
		near(Director.multiplier(ctx({ duskRoll = 9 })), 1.5, "never a big buff")
		near(Director.multiplier(ctx({ duskRoll = 0 / 0 })), 1, "NaN is ignored")
		near(Director.multiplier(ctx({ duskRoll = "1.25" })), 1, "only a number counts")
		near(Director.multiplier(ctx({ duskRoll = 1.25, carryingEgg = true, farFromBase = true, dangerousZone = true,
			longExpedition = true })), 3.51, "1.25 x 1.2 x 1.2 x 1.5 x 1.3")
		near(Director.multiplier(ctx({ duskRoll = 1.5, carryingEgg = true, farFromBase = true, dangerousZone = true,
			longExpedition = true })), 4, "capped at x4")
	end)

	case("BS-P0: no global beast rolls in Pradera or a safe zone; biome beasts are unaffected by the Pradera tag", function()
		local calls = 0
		local dir = Director.new({ random = function() calls += 1; return 0 end })
		local started = Director.roll(dir, 1, ctx({ biomes = { Meadow = true } }), 0)
		equal(#started, 0, "no global beast rolls in Pradera")
		equal(calls, 0, "no roll is spent on a barred beast")
		equal(select(2, Director.reserve(dir, 1, "Viper", ctx({ biomes = { Meadow = true } }), 0, { force = true })),
			"NoGlobalZone", "even forced")
		equal(select(2, Director.reserve(dir, 1, "Pouncer", ctx({ biomes = { Meadow = true } }), 0)), "NoGlobalZone")
		equal(#Director.roll(dir, 1, ctx({ safe = true }), 0), 0, "safe zone: nothing rolls")
		equal(select(2, Director.reserve(dir, 1, "Viper", ctx({ safe = true }), 0, { force = true })), "SafeZone")
		equal(Director.placeBlock("Gargoyle", ctx({ biomes = { Meadow = true, Cemetery = true } })), nil,
			"a biome beast only needs its own tag")
		equal(Director.placeBlock("Viper", ctx({ biomes = { Meadow = false } })), nil, "only a true tag bars")
		equal(Director.placeBlock("Viper", ctx()), nil, "the open forest is fine")
		equal(Director.budget(dir, 1), 0, "nothing was reserved")
	end)

	case("BS-P0: a biome beast never rolls without its biome tag in ctx.biomes", function()
		for _, biomes in ipairs({ {}, { Meadow = true }, { Cemetery = "yes" }, { Swamp = false } }) do
			local seen = {}
			local dir = Director.new({ random = always(0) })
			local started, refused = Director.roll(dir, 1, ctx({ biomes = biomes }), 0)
			for _, enc in ipairs(started) do seen[enc.beast] = true end
			for _, r in ipairs(refused) do seen[r.beast] = true end
			assert(not seen.Gargoyle and not seen.Mire, "a biome beast rolled without its tag")
		end
		local dir = Director.new({ random = always(0) })
		local started = Director.roll(dir, 1, ctx({ biomes = { Swamp = true } }), 0, { "Mire", "Root" })
		local root, mire = false, false
		for _, enc in ipairs(started) do root = root or enc.beast == "Root"; mire = mire or enc.beast == "Mire" end
		assert(root, "with its tag Root rolls")
		assert(not mire, "Mire has no behaviour yet: never rolled, even in the Pantano")
		equal(select(2, Director.reserve(dir, 2, "Mire", ctx({ biomes = { Cemetery = true } }), 0, { force = true })), "Biome")
	end)

	-- Kids biome (odd/tasks/wildbound-kids-beasts.md, KB-1): the summoned Pradera beasts.
	case("KB-1: summoned beasts are never rolled and never in ORDER or PLAYABLE", function()
		local KIDS = { "NubeGrunona", "AbejaReina" }
		for _, name in ipairs(KIDS) do
			equal(Config.SUMMONED[name], true, name); equal(Config.PLAYABLE[name], nil, name)
			for _, other in ipairs(Config.ORDER) do assert(other ~= name, name .. " in ORDER") end
			equal(Config.homeBiome(name), "Meadow", name .. " keeps its Meadow home while the switch is off")
		end
		equal(#Config.ORDER, 9, "the calendar holds only rolled beasts (SC1 added Scuttler)")
		local calls = 0
		local dir = Director.new({ random = function() calls += 1; return 0 end })
		local started, refused = Director.roll(dir, 1, ctx({ biomes = { Meadow = true } }), 0, KIDS)
		equal(#started, 0, "never rolled"); equal(#refused, 0, "not even skipped"); equal(calls, 0, "no roll spent")
		equal(#Director.due(dir, 2, 0), 0); equal(#Director.due(dir, 2, 100), 9, "only the ORDER beasts are ever due")
	end)

	case("KB-1: summon is refused outside Meadow (Biome) and for any non-summoned beast", function()
		local dir = Director.new({ random = always(0) })
		equal(select(2, Director.summon(dir, 1, "NubeGrunona", ctx(), 0)), "Biome", "the open forest")
		equal(select(2, Director.summon(dir, 1, "AbejaReina", ctx({ biomes = { Swamp = true } }), 0)), "Biome")
		equal(select(2, Director.summon(dir, 1, "Viper", ctx({ biomes = { Meadow = true } }), 0)), "NotSummoned")
		equal(select(2, Director.summon(dir, 1, "NubeGrunona", ctx({ biomes = { Meadow = true }, safe = true }), 0)), "SafeZone")
		equal(#dir.log, 0, "a refused summon is not logged (the script asks every poll)")
		local ok, enc = Director.summon(dir, 1, "NubeGrunona", ctx({ biomes = { Meadow = true } }), 0)
		assert(ok and enc.beast == "NubeGrunona", "summoned in the Pradera")
		equal(select(2, Director.summon(dir, 1, "NubeGrunona", ctx({ biomes = { Meadow = true } }), 1)), "AlreadyActive")
	end)

	-- Deliberately changed (PF1, odd/tasks/wildbound-caramelo-playfix.md): a points-0 summoned beast no longer counts
	-- toward MAX_ACTIVE (it used to: with Gomibu and one critter alive, every other Caramelo creature was refused).
	case("KB-1: points 0 never spend the budget; PF1: nor do they take a MAX_ACTIVE slot", function()
		local dir = Director.new({ random = always(0) })
		local meadow = ctx({ biomes = { Meadow = true } })
		assert(Director.summon(dir, 1, "NubeGrunona", meadow, 0), "Nube")
		assert(Director.summon(dir, 1, "AbejaReina", meadow, 0), "Abeja")
		local points, active = Director.budget(dir, 1)
		equal(points, 0, "no points spent"); equal(active, 2)
		equal((Director.reserve(dir, 1, "Viper", ctx(), 0, { force = true })), true, "two summoned beasts leave the cap free")
	end)

	-- PF1 (odd/tasks/wildbound-caramelo-playfix.md): every summoned points-0 beast (the Pradera and Caramelo creatures)
	-- is outside MAX_ACTIVE: it neither counts toward it nor is refused by it. The rolled beasts keep the cap among
	-- themselves; every other rule (one of a kind, Don Glaseon one per server, the Scuttler alone) stands.
	case("PF1: summoned points-0 beasts are neither counted by nor refused by MAX_ACTIVE; rolled beasts keep the cap", function()
		local dir = Director.new({ random = always(0) })
		local meadow = ctx({ biomes = { Meadow = true } })
		local candy = { "Gomibu", "Flanfuria", "Tortidragon", "Mochimiau", "Canelin", "Flanin", "Mielita", "GatoRepartidor",
			"NubeGrunona", "AbejaReina", "DonGlaseon" }
		for _, name in ipairs(candy) do
			equal(Config.BEASTS[name].points, 0, name .. " is a points-0 beast")
			local ok, why = Director.summon(dir, 1, name, meadow, 0)
			equal(ok, true, name .. " summoned beside the others (" .. tostring(why) .. ")")
		end
		local _, active = Director.budget(dir, 1)
		equal(active, #candy, "all of them at once")
		equal(select(2, Director.summon(dir, 1, "Gomibu", meadow, 1)), "AlreadyActive", "still one of a kind")
		equal(select(2, Director.summon(dir, 2, "DonGlaseon", meadow, 1)), "BossBusy", "still one boss per server")
		-- the rolled beasts: two at once, the summoned ones not counted
		local other = Director.new({ random = always(0) })
		assert(Director.summon(other, 1, "NubeGrunona", meadow, 0), "a summoned beast first")
		assert(Director.reserve(other, 1, "Viper", ctx(), 0, { force = true }), "Viper")
		assert(Director.reserve(other, 1, "Pouncer", ctx(), 0, { force = true }), "Pouncer")
		equal(select(2, Director.reserve(other, 1, "Streamer", ctx(), 0, { force = true })), "MaxActive", "the cap holds for rolled beasts")
		assert(Director.summon(other, 1, "AbejaReina", meadow, 0), "a summoned beast beside two rolled ones")
		-- the Scuttler still hunts alone
		local alone = Director.new({ random = always(0) })
		assert(Director.reserve(alone, 1, "Scuttler", ctx(), 0, { force = true }), "Scuttler")
		equal(select(2, Director.summon(alone, 1, "NubeGrunona", meadow, 0)), "Budget", "nothing beside the Scuttler")
	end)

	-- PF7 (odd/tasks/wildbound-caramelo-playfix.md, "more frequency of beasts"): every summoned beast comes back after a
	-- 5 s species rest (was 10 s; Don Glaseon 8 s); a reason-specific rest (the Nube's 60 s Bostezo nap) stays.
	case("PF7: summoned beasts rest 5 s between encounters; the global cooldown is 10 s", function()
		for name in pairs(Config.SUMMONED) do
			equal(Config.BEASTS[name].cooldown, 5, name .. " species rest")
		end
		equal(Config.BEASTS.NubeGrunona.endCooldowns.Yawn, 60, "the nap stays")
		local dir = Director.new({ random = always(0) })
		local meadow = ctx({ biomes = { Meadow = true } })
		local _, g = Director.summon(dir, 1, "Mochimiau", meadow, 0)
		Director.release(dir, g.id, "GiveUp", 10)
		equal(select(2, Director.summon(dir, 1, "Mochimiau", meadow, 14.9)), "SpeciesCooldown")
		assert(Director.summon(dir, 1, "Mochimiau", meadow, 15), "back after 5 s")
	end)

	-- PF1: the refusal reason of a summon is returned, so the beast script can write it to Beast_lastSummonRefusal.
	case("PF1: summon returns why it refused", function()
		local dir = Director.new({ random = always(0) })
		local meadow = ctx({ biomes = { Meadow = true } })
		assert(Director.summon(dir, 1, "Gomibu", meadow, 0))
		local ok, why = Director.summon(dir, 1, "Gomibu", meadow, 0.25)
		equal(ok, false); equal(why, "AlreadyActive")
		local fresh = Director.new({ random = always(0) })
		local _, g = Director.summon(fresh, 1, "Gomibu", meadow, 0)
		Director.release(fresh, g.id, "Idle", 10)
		equal(select(2, Director.summon(fresh, 1, "Gomibu", meadow, 11)), "SpeciesCooldown")
	end)

	case("KB-1: a summoned end sets no global cooldown; species 5 s (PF7, was 10), 60 s after Bostezo; respawn grace applies", function()
		local dir = Director.new({ random = always(0) })
		local meadow = ctx({ biomes = { Meadow = true } })
		local _, nube = Director.summon(dir, 1, "NubeGrunona", meadow, 0)
		Director.release(dir, nube.id, "GiveUp", 100)
		local started = Director.roll(dir, 1, ctx(), 101, { "Viper" })
		equal(#started, 1, "no global cooldown after a summoned end")
		assert(Director.summon(dir, 2, "AbejaReina", meadow, 0), "another player")
		equal(select(2, Director.summon(dir, 1, "NubeGrunona", meadow, 104.9)), "SpeciesCooldown")
		local again = Director.new({ random = always(0) })
		local _, viper = Director.reserve(again, 1, "Viper", ctx(), 0)
		Director.release(again, viper.id, "Done", 50)
		assert(Director.summon(again, 1, "AbejaReina", meadow, 51), "a global cooldown never blocks a summon")
		local napped = Director.new({ random = always(0) })
		local _, cloud = Director.summon(napped, 1, "NubeGrunona", meadow, 0)
		Director.release(napped, cloud.id, "Yawn", 10)
		equal(select(2, Director.summon(napped, 1, "NubeGrunona", meadow, 69)), "SpeciesCooldown", "the 60 s nap")
		assert(Director.summon(napped, 1, "NubeGrunona", meadow, 70.5), "awake again after 60 s")
		equal(select(2, Director.summon(napped, 3, "NubeGrunona", ctx({ biomes = { Meadow = true }, respawnedAt = 0 }), 5)),
			"RespawnGrace")
	end)

	case("KB-1: the globals stay NoGlobalZone in Meadow next to the summoned beasts", function()
		for name in pairs(Config.PLAYABLE) do
			equal(Director.placeBlock(name, ctx({ biomes = { Meadow = true } })), "NoGlobalZone", name)
		end
		equal(Director.placeBlock("NubeGrunona", ctx({ biomes = { Meadow = true } })), nil)
		equal(Director.placeBlock("AbejaReina", ctx({ biomes = { Meadow = true } })), nil)
	end)

	-- Scuttler SC1 (docs/design/wildbound-scuttler-plan.md sections 6 to 8): a global threat-3 beast that fills the whole
	-- per-player budget, rolls 1/60 per 10 s with a 75 s species cooldown, and has no biome preference.
	case("SC1 config: Scuttler's entry, section 6 numbers, ORDER ninth, playable and wave 2", function()
		local B = Config.BEASTS.Scuttler
		assert(type(B) == "table" and table.isfrozen(B), "BEASTS.Scuttler frozen")
		equal(B.category, "Global"); equal(B.biome, nil); equal(B.riskModifier, 1)
		equal(B.points, 3, "fills the budget alone"); equal(B.points, Config.DIRECTOR.MAX_POINTS)
		near(B.chance10, S10); near(B.chance, p20(S10), "1 - (1 - 1/45)^2"); near(B.chance, Config.perRoll(S10))
		assert(B.chance10 < Config.BEASTS.Viper.chance10, "still rarer than Viper")
		equal(B.cooldown, 75)
		equal(B.spawnMin, 40); equal(B.spawnMax, 75); equal(B.spawnSeconds, 1.0)
		equal(B.escapeDistance, 110); equal(B.escapeSeconds, 4); near(B.disengage, 1.2)
		equal(B.lockLead, 0.3); equal(B.laneWidth, 8); equal(B.hitHeight, 8); equal(B.damage, 30, "the charge")
		local T = B.tuning
		assert(type(T) == "table" and table.isfrozen(T), "tuning frozen")
		local expected = {
			EncounterTimeoutSeconds = 45, StalkMin = 20, StalkMax = 34, StalkSpeed = 14, ReadSeconds = 0.8,
			PredictSeconds = 1.2, InterceptMaxStuds = 30, InterceptSpeed = 21, InterceptMarginSeconds = 0.4,
			InterceptMinSpeed = 8, BlockSeconds = 2.5, ReplanCooldownSeconds = 0.6, MaxReplans = 1,
			SnapTelegraphSeconds = 0.9, SnapRadius = 10, SnapArc = 100, SnapDamage = 20, FeintSeconds = 0.9,
			FeintChance = 0.4, MaxFeintsWhileEgg = 1, ChargeTelegraphSeconds = 1.1, PunishTelegraphSeconds = 0.9,
			ChargeMaxRangeStuds = 40, ChargeSpeed = 46, ChargeDamage = 30, ChargeCooldownSeconds = 4.5,
			ChargeMissRecoverySeconds = 1.2, OverrunStuds = 8, FallStumbleSeconds = 2.2, FallCrashSeconds = 3.0,
			FallsToGiveUp = 2, PulseChargeSeconds = 1.3, PulseRadiusStuds = 16, PulseSlowMultiplier = 0.75,
			PulseSlowSeconds = 1.5, PulseCooldownSeconds = 5, PressureMemorySeconds = 8, PulseCanDropEgg = true,
		}
		for key, value in pairs(expected) do
			if type(value) == "number" then near(T[key], value, key) else equal(T[key], value, key) end
		end
		for key in pairs(T) do assert(expected[key] ~= nil, "unexpected tuning key " .. key) end
		equal(B.damage, T.ChargeDamage, "damage is the charge's")
		equal(Config.ORDER[9], "Scuttler", "ninth on the calendar")
		equal(Config.PLAYABLE.Scuttler, true); equal(Config.WAVE2.Scuttler, true)
		equal(Config.SUMMONED.Scuttler, nil); equal(Config.OBSERVERS.Scuttler, nil)
	end)

	case("SC1 config: every Scuttler tell is at least 0.8 s; the pulse slow fits applySlow; slower than a sprint", function()
		local B = Config.BEASTS.Scuttler
		assert(B, "BEASTS.Scuttler")
		local T = B.tuning
		for label, seconds in pairs({ snap = T.SnapTelegraphSeconds, charge = T.ChargeTelegraphSeconds,
			punish = T.PunishTelegraphSeconds, pulse = T.PulseChargeSeconds, read = T.ReadSeconds }) do
			assert(seconds >= Config.MIN_TELL - 1e-9, label .. " tell " .. seconds)
		end
		assert(T.ChargeTelegraphSeconds - B.lockLead > 0, "the lane follows before it locks")
		assert(T.PulseSlowMultiplier >= 0.5 and T.PulseSlowMultiplier <= 1, "applySlow clamps 0.5..1")
		assert(T.PulseSlowSeconds > 0 and T.PulseSlowSeconds <= 3, "applySlow lasts at most 3 s")
		-- WildboundStamina: a rested sprint is 16 x 1.45 = 23.2 studs/s; the intercept and the stalk never outrun it.
		assert(T.InterceptSpeed < 16 * 1.45, "intercept below a rested sprint")
		assert(T.StalkSpeed < 16 * 1.45, "stalk below a rested sprint")
		assert(T.StalkMin < T.StalkMax and T.StalkMax < B.spawnMin, "stalk ring inside the spawn ring")
	end)

	case("SC1: no biome preference: homeBiome nil, Global with the switch either way, no spawn bias", function()
		assert(Config.BEASTS.Scuttler, "BEASTS.Scuttler")
		equal(Config.BIOME_PREFERENCE, false)
		equal(Config.homeBiome("Scuttler"), nil); equal(Config.categoryOf("Scuttler"), "Global")
		equal(Config.homeBiome("Scuttler", true), nil, "no home biome even with the preference on")
		equal(Config.categoryOf("Scuttler", true), "Global")
		assert(Config.SPAWN_BIAS ~= true, "the return-route spawn bias stays off (plan section 8)")
	end)

	case("SC1: Scuttler never starts when any point is in use; no roll is spent on it", function()
		for _, other in ipairs({ "Viper", "Pouncer", "Streamer", "Gaze", "Lurker", "Root" }) do
			local calls = 0
			local dir = Director.new({ random = function() calls += 1; return 0 end })
			assert(Director.reserve(dir, 1, other, ctx(), 0, { force = true }), other)
			local before = calls
			local started, refused = Director.roll(dir, 1, ctx(), 0, { "Scuttler" })
			equal(#started, 0, other .. " active")
			assert(refused[1], "Scuttler is skipped, not ignored, while " .. other .. " hunts")
			equal(refused[1].reason, "Budget", other); equal(refused[1].rolled, false)
			equal(calls, before, "no roll spent while " .. other .. " hunts")
			equal(select(2, Director.reserve(dir, 1, "Scuttler", ctx(), 0, { force = true })), "Budget", "not even forced")
		end
	end)

	case("SC1: nothing else starts while Scuttler is active; release refunds 3 once; 75 s species cooldown", function()
		local dir = Director.new({ random = always(0) })
		local ok, enc = Director.reserve(dir, 1, "Scuttler", ctx(), 0)
		assert(ok, "Scuttler starts with 0 points in use: " .. tostring(enc))
		equal(Director.budget(dir, 1), 3)
		local started, refused = Director.roll(dir, 1, ctx(), 1)
		equal(#started, 0, "no other beast starts")
		for _, entry in ipairs(refused) do
			assert(entry.reason == "Budget" or entry.reason == "AlreadyActive", entry.beast .. " " .. entry.reason)
			equal(entry.rolled, false, entry.beast)
		end
		for _, other in ipairs({ "Viper", "Pouncer", "Streamer", "Root", "Gaze", "Lurker" }) do
			equal(select(2, Director.reserve(dir, 1, other, ctx(), 1, { force = true })), "Budget", other .. " forced")
		end
		equal(select(2, Director.reserve(dir, 1, "Scuttler", ctx(), 1, { force = true })), "AlreadyActive")
		equal(Director.release(dir, enc.id, "Done", 10), true)
		equal(Director.budget(dir, 1), 0, "refunded at once")
		equal(Director.release(dir, enc.id, "Done", 10), false, "exactly once")
		equal(select(2, Director.reserve(dir, 1, "Scuttler", ctx(), 84.9)), "SpeciesCooldown")
		assert(Director.reserve(dir, 1, "Scuttler", ctx(), 85), "75 s later")
	end)

	-- Correction (review finding 4): a summoned kids beast has 0 points, so the budget alone let one start beside
	-- Scuttler (the poll tick a hunted player steps into the Pradera) and let Scuttler start beside one. Scuttler fills
	-- the whole budget: nothing at all runs with it.
	case("SC1: Scuttler stays alone: no summoned kids beast beside it, and it never joins one", function()
		local dir = Director.new({ random = always(0) })
		local ok, enc = Director.reserve(dir, 1, "Scuttler", ctx(), 0)
		assert(ok, "Scuttler starts: " .. tostring(enc))
		local meadow = ctx({ biomes = { Meadow = true } })
		for _, kid in ipairs({ "NubeGrunona", "AbejaReina" }) do
			equal(select(2, Director.summon(dir, 1, kid, meadow, 1)), "Budget", kid .. " while Scuttler hunts")
			equal(select(2, Director.summon(dir, 1, kid, meadow, 1, { force = true })), "Budget", kid .. " forced")
		end
		equal(Director.release(dir, enc.id, "Pradera", 2), true)
		assert(Director.summon(dir, 1, "NubeGrunona", meadow, 3), "a kids beast once Scuttler is gone")
		local other = Director.new({ random = always(0) })
		assert(Director.summon(other, 1, "AbejaReina", meadow, 0), "a kids beast hunts")
		local started, refused = Director.roll(other, 1, ctx(), 1, { "Scuttler" })
		equal(#started, 0, "Scuttler never joins it")
		assert(refused[1], "Scuttler is skipped, not ignored")
		equal(refused[1].reason, "Budget"); equal(refused[1].rolled, false, "no roll spent")
		equal(select(2, Director.reserve(other, 1, "Scuttler", ctx(), 1, { force = true })), "Budget", "not even forced")
		assert(Director.summon(other, 1, "NubeGrunona", meadow, 1), "two kids beasts still share the Pradera")
	end)

	case("SC1: never in Pradera, a safe zone, while dead or while the Silueta hunts", function()
		equal(Director.placeBlock("Scuttler", ctx()), nil, "the open forest")
		for _, biomes in ipairs({ { Swamp = true }, { Cemetery = true } }) do
			equal(Director.placeBlock("Scuttler", ctx({ biomes = biomes })), nil, "any biome outside Pradera")
		end
		equal(Director.placeBlock("Scuttler", ctx({ biomes = { Meadow = true } })), "NoGlobalZone")
		local dir = Director.new({ random = always(0) })
		equal(#Director.roll(dir, 1, ctx({ biomes = { Meadow = true } }), 0, { "Scuttler" }), 0, "no roll in Pradera")
		equal(#Director.roll(dir, 1, ctx({ safe = true }), 0, { "Scuttler" }), 0, "no roll in a safe zone")
		for _, pair in ipairs({ { ctx({ biomes = { Meadow = true } }), "NoGlobalZone" }, { ctx({ safe = true }), "SafeZone" },
			{ ctx({ alive = false }), "Dead" }, { ctx({ siluetaActive = true }), "SiluetaActive" } }) do
			equal(select(2, Director.reserve(dir, 1, "Scuttler", pair[1], 0, { force = true })), pair[2], pair[2])
		end
		equal(Director.budget(dir, 1), 0, "nothing booked")
	end)

	case("SC1 calendar: Scuttler rolls 8 s after Viper, every 20 s, and its roll is the configured chance", function()
		local dir = Director.new({ random = always(0.999) })
		equal(#Director.due(dir, 5, 100), 0, "anchor")
		local function has(list, name)
			for _, value in ipairs(list) do if value == name then return true end end
			return false
		end
		assert(not has(Director.due(dir, 5, 127.9), "Scuttler"), "not before anchor + 28")
		assert(has(Director.due(dir, 5, 128), "Scuttler"), "anchor + 20 + 8 x 1 s")
		equal(Director.nextSlot(dir, 5, "Scuttler", 128.1), 148)
		near(Director.chance("Scuttler", ctx()), p20(S10), "day in the open")
		local roll = Director.new({ random = sequence({ p20(S10) - 1e-6 }) })
		local started = Director.roll(roll, 1, ctx(), 0, { "Scuttler" })
		equal(#started, 1, "a roll just under the chance wins"); equal(started[1].beast, "Scuttler")
		equal(started[1].points, 3)
	end)

	-- CG2 (F5, odd/tasks/wildbound-caramelo.md decision 50): a stolen Caramelo nest egg wakes the nest's guardian on the
	-- thief at once. Director.alarm skips only the timers (species rest, respawn grace); every other rule stands.
	case("CG2: a stolen Caramelo egg wakes its guardian on the thief through its rest (Director.alarm)", function()
		local dir = Director.new()
		local meadow = ctx({ biomes = { Meadow = true } })
		local ok, enc = Director.alarm(dir, 1, "Tortidragon", meadow, 0)
		equal(ok, true, "the guardian starts on the thief"); equal(enc.beast, "Tortidragon", "beast")
		equal(enc.userId, 1, "on the thief")
		equal(select(2, Director.alarm(dir, 1, "Tortidragon", meadow, 1)), "AlreadyActive", "one at a time")
		Director.release(dir, enc.id, "Lost", 2)
		equal(select(2, Director.summon(dir, 1, "Tortidragon", meadow, 3)), "SpeciesCooldown", "presence waits for its rest")
		equal((Director.alarm(dir, 1, "Tortidragon", meadow, 3)), true, "a steal wakes it through its rest")
		local fresh = Director.new()
		equal(select(2, Director.alarm(fresh, 1, "Gomibu", ctx({ biomes = { Meadow = true }, safe = true }), 0)), "SafeZone",
			"never in a safe zone")
		equal(select(2, Director.alarm(fresh, 1, "Gomibu", ctx(), 0)), "Biome", "never outside its home")
		equal(select(2, Director.alarm(fresh, 1, "Flanfuria", ctx({ biomes = { Meadow = true }, alive = false }), 0)), "Dead",
			"never on a dead thief")
		equal(select(2, Director.alarm(fresh, 1, "Viper", meadow, 0)), "NotSummoned", "only a summoned guardian")
		equal(select(2, Director.alarm(fresh, 1, "Flanfuria", ctx({ biomes = { Meadow = true }, siluetaActive = true }), 0)),
			"SiluetaActive", "La Silueta still wins")
	end)

	-- CH1 (owner request "more repeated creatures in the Caramelo kingdom"): a candy creature may also stand at extra
	-- posts (WildboundPraderaSites.EXTRA_POSTS). Each post is its own encounter: one of a kind per post (opts.post), its
	-- own species rest; the home post is post nil, exactly as before. A roar still never adds a second of a kind.
	case("CH1: a summoned beast at an extra post is its own encounter: one per post, its own rest; a roar stays one of a kind", function()
		local dir = Director.new()
		local meadow = ctx({ biomes = { Meadow = true } })
		local ok, home = Director.summon(dir, 1, "Gomibu", meadow, 0)
		equal(ok, true, "the home post"); equal(home.post, nil, "the home post has no key")
		local ok2, extra = Director.summon(dir, 1, "Gomibu", meadow, 0, { post = "candyPostC7" })
		equal(ok2, true, "a second Gomibu at its extra post (" .. tostring(extra) .. ")"); equal(extra.post, "candyPostC7", "post kept")
		equal(select(2, Director.summon(dir, 1, "Gomibu", meadow, 0.5, { post = "candyPostC7" })), "AlreadyActive", "one per post")
		equal(select(2, Director.summon(dir, 1, "Gomibu", meadow, 0.5)), "AlreadyActive", "the home post too")
		local _, active = Director.budget(dir, 1)
		equal(active, 2, "both live at once")
		-- each post rests on its own
		Director.release(dir, extra.id, "GiveUp", 10)
		equal(select(2, Director.summon(dir, 1, "Gomibu", meadow, 12, { post = "candyPostC7" })), "SpeciesCooldown", "the extra post rests")
		Director.release(dir, home.id, "GiveUp", 12)
		assert(Director.summon(dir, 1, "Gomibu", meadow, 15, { post = "candyPostC7" }), "the extra post back after its 5 s")
		equal(select(2, Director.summon(dir, 1, "Gomibu", meadow, 16)), "SpeciesCooldown", "the home post keeps its own rest")
		assert(Director.summon(dir, 1, "Gomibu", meadow, 17), "the home post back after its 5 s")
		-- a steal at an extra guardian's nest wakes that copy (Director.alarm with the post)
		local thief = Director.new()
		assert(Director.summon(thief, 1, "Tortidragon", meadow, 0), "the home Tortidragon is out")
		local okA, alarmed = Director.alarm(thief, 1, "Tortidragon", meadow, 1, "candyPostC8")
		equal(okA, true, "the extra guardian wakes beside the home one"); equal(alarmed.post, "candyPostC8", "at its post")
		equal(select(2, Director.alarm(thief, 1, "Tortidragon", meadow, 2, "candyPostC8")), "AlreadyActive", "one at a time")
		-- DG6: the roar never adds a second of a kind, whatever post the one already there came from
		local roar = Director.new()
		assert(Director.summon(roar, 1, "Gomibu", meadow, 0, { post = "candyPostC7" }), "an extra-post Gomibu")
		equal(select(2, Director.roar(roar, 1, "Gomibu", meadow, 1)), "AlreadyActive", "the roar adds no second Gomibu")
		-- a rolled beast is untouched by posts
		local rolled = Director.new()
		assert(Director.reserve(rolled, 1, "Viper", ctx(), 0, { force = true }), "Viper")
		equal(select(2, Director.reserve(rolled, 1, "Viper", ctx(), 0, { force = true })), "AlreadyActive", "Viper still one")
	end)

	case("NB2: the director is pure: no world, no clock, no global random", function()
		for _, banned in ipairs({ "game:", "workspace", "task.", "os.clock", "os.time", "math.random", "Random.new" }) do
			assert(not source:find(banned, 1, true), "director source uses " .. banned)
		end
		assert(not source:find("[^%.%w_]tick%("), "director source calls the global tick()")
	end)

	return result
end

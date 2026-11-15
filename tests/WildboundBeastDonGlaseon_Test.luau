-- Invoke with require(freshTestClone)(require(freshBeastEncountersClone), require(freshBeastDonGlaseonClone),
-- require(freshBeastConfigClone), require(freshCandyDonGlaseonAttackClone), require(freshBeastDirectorClone),
-- require(freshPraderaSitesClone)). The beast module reads its DataModel, so its clone must sit in ServerScriptService
-- while it is required.
-- Caramelo biome (odd/tasks/wildbound-caramelo.md, CA3; pack 03_PERSONAJES/04_DON_GLASEON_BOSS.md): Don Glaseon's state
-- machine (Dormant, Patrol, Suspicious, Roar, Chase, Search, Telegraph, Attack, Recover, LoseTarget, Return), the
-- one-boss-per-server rule in the director and the boss's territory and target choice in the sites. Pure: a fake world
-- with flat ground at y 0 and a target moved by the test. A new encounter faces +Z, so a target at +Z is in front.
return function(Enc, Boss, Config, Latigo, Director, Sites)
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
	local function near(actual, expected, label, tolerance)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-6),
			(label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	Enc.register("DonGlaseon", Boss)
	local C = Config.BEASTS.DonGlaseon
	local T = C and C.tuning
	local function fakeWorld(opts)
		local w = { telegraphs = {}, cancelled = {} }
		function w.ground() return 0 end
		function w.site() return nil end
		function w.telegraph(id) table.insert(w.telegraphs, id); return true end
		function w.resolve() return "Hit" end
		function w.cancel(id) table.insert(w.cancelled, id) end
		if opts and opts.blind then function w.lineOfSight() return false end end
		return w
	end
	local function target(x, z, extra)
		local tgt = { x = x, y = 3, z = z, vx = 0, vz = 0, alive = true, safe = false }
		for k, v in pairs(extra or {}) do tgt[k] = v end
		return tgt
	end
	local function run(e, w, tgt, from, to, move, watch)
		local all = {}
		for i = 0, math.floor((to - from) / 0.05 + 1e-6) do
			local t = from + i * 0.05
			if move then move(t, tgt, e) end
			for _, ev in ipairs(Enc.step(e, t, tgt, w)) do table.insert(all, ev) end
			if watch then watch(t, e) end
			if e.done then break end
		end
		return all
	end
	local function each(events, kind)
		local list = {}
		for _, ev in ipairs(events) do if ev.type == kind then table.insert(list, ev) end end
		return list
	end
	local function phases(events)
		local list = {}
		for _, ev in ipairs(each(events, "Phase")) do table.insert(list, ev.phase) end
		return table.concat(list, ",")
	end
	local function boss(id) return Enc.new("DonGlaseon", id, 1, 0, { x = 0, y = 0, z = 0 }) end
	-- A boss that saw a target 14 studs in front, stepped until its first lash tell.
	local function telegraphing(id, extra)
		local e, w, tgt = boss(id), fakeWorld(), target(0, 14, extra)
		local events, tell = {}, nil
		for i = 0, 80 do
			for _, ev in ipairs(Enc.step(e, i * 0.05, tgt, w)) do table.insert(events, ev) end
			tell = each(events, "Tell")[1]
			if tell then break end
		end
		assert(tell, "no tell after seeing a target in front (phases " .. phases(events) .. ")")
		return e, w, tgt, events, tell
	end

	case("config: one shared boss of the Caramelo, the pack's movement and senses, no damage, the egg drops (BeastHit)", function()
		assert(C and T, "no DonGlaseon in the config")
		equal(C.points, 0, "points"); equal(C.damage, 0, "damage"); equal(C.keepsEgg, false, "keepsEgg"); equal(C.grounded, true, "grounded")
		equal(C.chance, 0, "never rolled"); equal(C.serverUnique, true, "one per server"); equal(C.batImmune, true, "the bat never stuns it")
		equal(Config.SUMMONED.DonGlaseon, true, "summoned"); equal(Config.WAVE2.DonGlaseon, true, "behaviour module")
		near(T.PerceptionStuds, 36, "sight"); near(T.NoiseStuds, 45, "noise"); near(T.PatrolSpeedStudsPerSecond, 9, "patrol")
		near(T.ChaseSpeedStudsPerSecond, 17, "chase"); near(T.ChaseSeconds, 15, "chase time"); near(T.SearchSeconds, 3, "search")
		near(T.TerritoryRadiusStuds, 62, "the BossTerritory marker's radius")
		assert(T.CastRangeStuds < Latigo.LENGTH_STUDS, "it lashes at targets the lane cannot reach")
		assert(Boss.tellSeconds() >= Config.MIN_TELL, "the tell is shorter than the minimum")
	end)

	case("Dormant -> Suspicious -> Roar -> Chase -> Telegraph: a 22 x 5 lane in front, dodgeable, lock 0.60 s, strike 1.45 s", function()
		local e, w, _, events, tell = telegraphing("g1")
		equal(string.sub(phases(events), 1, #"Dormant,Suspicious,Roar,Chase,Telegraph"), "Dormant,Suspicious,Roar,Chase,Telegraph", "phases")
		equal(tell.shape.kind, "lane"); near(tell.shape.length, 22, "length"); near(tell.shape.width, 5, "width")
		assert(tell.shape.dz > 0.9, "the lane does not point at the target")
		near(tell.lockAt - tell.startAt, 0.6, "lock"); near(tell.strikeAt - tell.startAt, 1.45, "strike")
		equal(tell.dodgeable, true, "the perfect dodge works on it"); equal(#w.telegraphs, 1, "registered with the dodge")
		equal(e.phase, "Telegraph")
	end)

	case("senses: a still target at 40 studs is not seen, a running one is heard; a rare-egg carrier is seen further", function()
		local e = boss("g2")
		equal(Boss.sees(e, target(0, 40), fakeWorld(), T), false, "still at 40")
		equal(Boss.sees(e, target(0, 40, { vx = 16 }), fakeWorld(), T), true, "running at 40")
		equal(Boss.sees(e, target(0, 50, { vx = 16 }), fakeWorld(), T), false, "running at 50")
		equal(Boss.sees(e, target(0, 43, { eggRarity = "Rara" }), fakeWorld(), T), true, "a rare carrier at 43")
		equal(Boss.sees(e, target(0, 43, { eggRarity = "Comun" }), fakeWorld(), T), false, "a common carrier at 43")
		equal(Boss.sees(e, target(0, 20), fakeWorld({ blind = true }), T), false, "behind a wall")
	end)

	case("the lane locks at 0.60 s; sidestepping out of it after the lock dodges the lash (Strike miss, no Hit)", function()
		local e, w, tgt, _, tell = telegraphing("g3")
		local start = tell.startAt
		local events = run(e, w, tgt, start + 0.05, start + 1.6, function(t, target) if t > start + 0.65 then target.x = 4 end end)
		local locked
		for _, ev in ipairs(each(events, "Tell")) do if ev.locked then locked = locked or ev end end
		assert(locked, "no locked tell"); near(locked.at, start + 0.6, "lock time", 0.051)
		for _, ev in ipairs(each(events, "Tell")) do if ev.at > locked.at then error("the lane moved after the lock") end end
		equal(#each(events, "Hit"), 0, "hits")
		local strike = each(events, "Strike")[1]
		assert(strike and strike.hit == false, "no missed strike")
	end)

	case("standing in the lane: one Hit at 1.45 s, damage 0, a 12-stud push along the lash and a short slow; then Recover, Chase", function()
		local e, w, tgt, _, tell = telegraphing("g4")
		local start = tell.startAt
		local events = run(e, w, tgt, start + 0.05, start + 2.6)
		local hits = each(events, "Hit")
		equal(#hits, 1, "hits")
		local hit = hits[1]
		near(hit.at, start + 1.45, "impact"); equal(hit.damage, 0, "damage")
		near(hit.push.studs, 12, "push"); assert(hit.push.dz > 0.9, "the push does not follow the lash")
		near(hit.slow.multiplier, 0.85, "slow"); near(hit.slow.seconds, 0.7, "slow time")
		assert(string.find(phases(events), "Attack,Recover,Chase", 1, true), "phases " .. phases(events))
	end)

	case("an egg carrier in the lane gets the Hit (BeastHit drops the egg) and the push, but no slow", function()
		local e, w, tgt, _, tell = telegraphing("g5", { carryingEgg = true })
		local events = run(e, w, tgt, tell.startAt + 0.05, tell.startAt + 1.6)
		local hit = each(events, "Hit")[1]
		assert(hit, "no hit"); equal(hit.slow, nil, "slow"); near(hit.push.studs, 12, "push")
	end)

	case("cooldown: no second lash until 7 s after the cast ended", function()
		local e, w, tgt, _, tell = telegraphing("g6")
		local start = tell.startAt
		local events = run(e, w, tgt, start + 0.05, start + 2.45 + 6.9)
		for _, ev in ipairs(each(events, "Tell")) do if ev.tell ~= tell.tell then error("a second lash inside the cooldown") end end
		events = run(e, w, tgt, start + 2.45 + 6.95, start + 2.45 + 7.6)
		assert(#each(events, "Tell") >= 1, "no lash after the cooldown")
	end)

	case("a safe zone stops it at once: the open lash is called off, nothing lands, it walks home (no vanishing)", function()
		local e, w, tgt, _, tell = telegraphing("g7")
		tgt.safe = true
		local events = run(e, w, tgt, tell.startAt + 0.05, tell.startAt + 6)
		equal(#each(events, "Hit"), 0, "hits")
		assert(each(events, "TellEnd")[1], "the lash was not called off")
		assert(string.find(phases(events), "LoseTarget,Return", 1, true), "phases " .. phases(events))
		local ended = each(events, "End")[1]
		assert(ended and ended.reason == "Return", "it did not end at home")
		assert(math.sqrt(e.pos.x ^ 2 + e.pos.z ^ 2) <= T.HomeToleranceStuds + 1e-6, "it ended away from home")
	end)

	case("territory and no teleport: it never leaves the territory, moves at most its speed, and returns home", function()
		local e, w, tgt = boss("g8"), fakeWorld(), target(0, 14)
		local furthest, jump, last = 0, 0, { x = 0, z = 0 }
		local events = run(e, w, tgt, 0, 40, function(t, target) if t > 3 then target.z = 14 + (t - 3) * 18 end end, function(_, en)
			furthest = math.max(furthest, math.sqrt(en.pos.x ^ 2 + en.pos.z ^ 2))
			jump = math.max(jump, math.sqrt((en.pos.x - last.x) ^ 2 + (en.pos.z - last.z) ^ 2))
			last = { x = en.pos.x, z = en.pos.z }
		end)
		assert(furthest <= T.TerritoryRadiusStuds + 1e-6, "it went " .. furthest .. " studs from its territory's centre")
		assert(jump <= T.ChaseSpeedStudsPerSecond * 0.05 + 1e-6, "it jumped " .. jump .. " studs in one step")
		assert(string.find(phases(events), "LoseTarget,Return", 1, true), "phases " .. phases(events))
		local ended = each(events, "End")[1]
		assert(ended and ended.reason == "Return", "it never got home")
	end)

	case("lost from sight: it searches the last seen spot for 3 s, then gives up", function()
		local e, w, tgt = boss("g9"), fakeWorld(), target(0, 25)
		run(e, w, tgt, 0, 2.5)
		equal(e.phase, "Chase", "chasing")
		function w.lineOfSight() return false end
		local events = run(e, w, tgt, 2.55, 7)
		local list = phases(events)
		assert(string.find(list, "Search,LoseTarget", 1, true), "phases " .. list)
		local search, lose
		for _, ev in ipairs(each(events, "Phase")) do
			if ev.phase == "Search" then search = search or ev.at elseif ev.phase == "LoseTarget" then lose = lose or ev.at end
		end
		near(lose - search, T.SearchSeconds, "search time", 0.051)
	end)

	case("a chase lasts at most 15 s, then it gives up", function()
		local e, w, tgt = boss("g10"), fakeWorld(), target(0, 30)
		local chaseAt
		local events = run(e, w, tgt, 0, 25, function(_, target, en)
			-- the target keeps 30 studs ahead, out of reach of the lash, inside the territory
			target.z = en.pos.z + 30; target.x = 0
			if target.z > 55 then target.z = 55 end
		end)
		for _, ev in ipairs(each(events, "Phase")) do if ev.phase == "Chase" then chaseAt = chaseAt or ev.at end end
		local lose
		for _, ev in ipairs(each(events, "Phase")) do if ev.phase == "LoseTarget" then lose = lose or ev.at end end
		assert(chaseAt and lose, "phases " .. phases(events))
		assert(lose - chaseAt <= T.ChaseSeconds + 0.051, "it chased for " .. (lose - chaseAt) .. " s")
	end)

	case("director: one boss per server; another player waits while it lives and for its switch rest", function()
		local dir = Director.new()
		local ctx = { alive = true, safe = false, biomes = { Meadow = true } }
		local ok, value = Director.summon(dir, 1, "DonGlaseon", ctx, 100)
		assert(ok, "the first summon was refused: " .. tostring(value))
		local ok2, why = Director.summon(dir, 2, "DonGlaseon", ctx, 101)
		equal(ok2, false, "a second boss"); equal(why, "BossBusy")
		Director.release(dir, value.id, "Return", 110)
		local ok3, why3 = Director.summon(dir, 2, "DonGlaseon", ctx, 110 + C.switchSeconds - 0.5)
		equal(ok3, false, "inside the switch rest"); equal(why3, "BossResting")
		local ok4 = Director.summon(dir, 2, "DonGlaseon", ctx, 110 + C.switchSeconds + 0.1)
		equal(ok4, true, "another target after the rest")
	end)

	case("sites: it wakes for players inside its territory and picks a rare-egg carrier over a nearer player", function()
		local home, centre = Sites.world(nil, "bossHome"), Sites.world(nil, "bossTerritory")
		assert(home and centre, "no boss sites")
		near(home.x, 578, "BossHome x"); near(home.z, -3, "BossHome z"); near(centre.x, 612, "territory x"); near(centre.z, -3, "territory z")
		equal(Sites.HOME.DonGlaseon, "bossHome", "home")
		local base = { alive = true, safe = false, meadow = true }
		local function at(x, z, extra) local c = table.clone(base); c.x, c.z = x, z; for k, v in pairs(extra or {}) do c[k] = v end; return c end
		equal(Sites.wants("DonGlaseon", at(612, 40)), true, "inside the territory")
		equal(Sites.wants("DonGlaseon", at(612, 70)), false, "outside the territory")
		equal(Sites.wants("DonGlaseon", at(612, 40, { safe = true })), false, "in a safe zone")
		local pick = Sites.bossPick({ { userId = 1, ctx = at(585, -3) }, { userId = 2, ctx = at(612, 40, { rarity = "Epica" }) },
			{ userId = 3, ctx = at(612, 100, { rarity = "Legendaria" }) } })
		equal(pick, 2, "the rare carrier inside the territory")
		equal(Sites.bossPick({ { userId = 1, ctx = at(600, -3) }, { userId = 4, ctx = at(585, -3) } }), 4, "else the nearest to its home")
		equal(Sites.bossPick({ { userId = 1, ctx = at(612, 90) } }), nil, "nobody in the territory")
	end)

	return result
end

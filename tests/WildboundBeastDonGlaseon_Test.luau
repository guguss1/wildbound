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
		-- Deliberately changed (OF2, owner feedback 2): the boss's lash hurts (25 of 100, never a one-shot) and he chases
		-- faster than a walking player (17 -> 21).
		equal(C.points, 0, "points"); equal(C.damage, 25, "damage"); equal(C.keepsEgg, false, "keepsEgg"); equal(C.grounded, true, "grounded")
		equal(C.chance, 0, "never rolled"); equal(C.serverUnique, true, "one per server"); equal(C.batImmune, true, "the bat never stuns it")
		equal(Config.SUMMONED.DonGlaseon, true, "summoned"); equal(Config.WAVE2.DonGlaseon, true, "behaviour module")
		near(T.PerceptionStuds, 36, "sight"); near(T.NoiseStuds, 45, "noise"); near(T.PatrolSpeedStudsPerSecond, 9, "patrol")
		-- Deliberately changed (PF5, odd/tasks/wildbound-caramelo-playfix.md): longer timers so a chase lasts (chase 15 -> 30 s,
		-- search 3 -> 5 s, patrol before Bored 12 -> 25 s) and a 3 s grace before "Left" (a lash or a pull can shove the
		-- target out of the territory for a moment).
		near(T.ChaseSpeedStudsPerSecond, 21, "chase"); near(T.ChaseSeconds, 30, "chase time"); near(T.SearchSeconds, 5, "search")
		near(T.PatrolSeconds, 25, "patrol"); near(T.LeftGraceSeconds, 3, "left grace")
		near(T.LeftMarginStuds, 12, "PF5b: the ring past the edge that still counts as his (the lash's 12-stud shove)")
		near(T.TerritoryRadiusStuds, 62, "the BossTerritory marker's radius")
		assert(T.CastRangeStuds < Latigo.LENGTH_STUDS, "it lashes at targets the lane cannot reach")
		assert(Boss.tellSeconds() >= Config.MIN_TELL, "the tell is shorter than the minimum")
	end)

	-- Deliberately changed (DG1, user 2026-11-15): a combo of three lashes, left, right, centre, all drawn at the start.
	case("DG1: Dormant -> Suspicious -> Roar -> Chase -> Telegraph: three 22 x 5 lanes in front, lock 0.35 s, strikes 1.15 / 1.5 / 1.85 s", function()
		local e, w, _, events, tell = telegraphing("g1")
		equal(string.sub(phases(events), 1, #"Dormant,Suspicious,Roar,Chase,Telegraph"), "Dormant,Suspicious,Roar,Chase,Telegraph", "phases")
		local tells = each(events, "Tell")
		equal(#tells, 3, "one tell per lash, all at the start")
		for i, ev in ipairs(tells) do
			equal(ev.shape.kind, "lane", "lane " .. i); near(ev.shape.length, 22, "length"); near(ev.shape.width, 5, "width")
			assert(ev.shape.dz > 0.9, "lane " .. i .. " does not point at the target")
			near(ev.startAt, tell.startAt, "drawn at the start"); near(ev.lockAt - ev.startAt, 0.35, "lock")
			equal(ev.dodgeable, true, "the perfect dodge works on each")
		end
		near(tells[1].strikeAt - tell.startAt, 1.15, "first strike"); near(tells[2].strikeAt - tell.startAt, 1.5, "second strike")
		near(tells[3].strikeAt - tell.startAt, 1.85, "third strike")
		assert(math.abs(tells[3].shape.ox) < 1e-6, "the last lash is the centre")
		assert(tells[1].shape.ox * tells[2].shape.ox < 0, "the first two are on both sides")
		equal(#w.telegraphs, 3, "each registered with the dodge")
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

	case("DG1: the lanes lock at 0.35 s; stepping out of all three after the lock dodges the combo (three misses, no Hit)", function()
		local e, w, tgt, _, tell = telegraphing("g3")
		local start = tell.startAt
		local events = run(e, w, tgt, start + 0.05, start + 2.0, function(t, target) if t > start + 0.4 then target.x = 9 end end)
		local locked = {}
		for _, ev in ipairs(each(events, "Tell")) do if ev.locked then table.insert(locked, ev) end end
		equal(#locked, 3, "three locked tells"); near(locked[1].at, start + 0.35, "lock time", 0.051)
		for _, ev in ipairs(each(events, "Tell")) do if not ev.locked and ev.at > locked[1].at then error("a lane moved after the lock") end end
		equal(#each(events, "Hit"), 0, "hits")
		local strikes = each(events, "Strike")
		equal(#strikes, 3, "three strikes")
		for _, strike in ipairs(strikes) do assert(strike.hit == false, "a strike landed") end
	end)

	case("DG1: the left lash hits a target in the left lane; stepping into a lane after its lash is safe", function()
		local e, w, tgt, _, tell = telegraphing("g3b")
		local start = tell.startAt
		local events = run(e, w, tgt, start + 0.05, start + 2.0, function(t, target) if t > start + 0.4 then target.x = tell.shape.ox end end)
		local hits = each(events, "Hit")
		equal(#hits, 1, "one hit in the left lane"); near(hits[1].at, start + 1.15, "the first lash")
		local e2, w2, tgt2, _, tell2 = telegraphing("g3c")
		local s2 = tell2.startAt
		-- centre until the left lash has landed, then into the left lane: the centre lash comes last and misses
		local moved = run(e2, w2, tgt2, s2 + 0.05, s2 + 2.0, function(t, target) if t > s2 + 1.2 then target.x = tell2.shape.ox end end)
		equal(#each(moved, "Hit"), 0, "hit after stepping into a spent lane")
	end)

	case("DG1: standing in the centre lane: one Hit at 1.85 s (the last lash), damage 0, a 12-stud push and a short slow; then Recover, Chase", function()
		local e, w, tgt, _, tell = telegraphing("g4")
		local start = tell.startAt
		local events = run(e, w, tgt, start + 0.05, start + 3.2)
		local hits = each(events, "Hit")
		equal(#hits, 1, "hits")
		local hit = hits[1]
		near(hit.at, start + 1.85, "impact"); equal(hit.damage, C.damage, "damage (OF2)")
		near(hit.push.studs, 12, "push"); assert(hit.push.dz > 0.9, "the push does not follow the lash")
		near(hit.slow.multiplier, 0.85, "slow"); near(hit.slow.seconds, 0.7, "slow time")
		assert(string.find(phases(events), "Attack,Recover,Chase", 1, true), "phases " .. phases(events))
	end)

	case("an egg carrier in the lane gets the Hit (BeastHit drops the egg) and the push, but no slow", function()
		local e, w, tgt, _, tell = telegraphing("g5", { carryingEgg = true })
		local events = run(e, w, tgt, tell.startAt + 0.05, tell.startAt + 2.0)
		local hit = each(events, "Hit")[1]
		assert(hit, "no hit"); equal(hit.slow, nil, "slow"); near(hit.push.studs, 12, "push")
	end)

	case("cooldown: no second combo until 7 s after the combo ended", function()
		local e, w, tgt, _, tell = telegraphing("g6")
		local start = tell.startAt
		for _, ev in ipairs(each(run(e, w, tgt, start + 0.05, start + 2.85 + 6.9), "Tell")) do
			if ev.startAt > start + 1e-6 then error("a second combo inside the cooldown") end
		end
		local events = run(e, w, tgt, start + 2.85 + 6.95, start + 2.85 + 7.6)
		assert(#each(events, "Tell") >= 1, "no lash after the cooldown")
	end)

	-- DG2 (user 2026-11-15): Boca aspiradora, for a target kept out of the lash's reach.
	-- OF2: he chases at 21 now, so the target's cap moved 55 -> 68 (still inside the territory plus LeftMarginStuds) to
	-- stay out of reach for the 2 s before the inhale.
	case("DG2: a target kept out of the lash's reach is pulled: a fixed cone, Inhale 0.9 s, Vacuum 2 s, Pull toward him, then Recover", function()
		local e, w, tgt = boss("g11"), fakeWorld(), target(0, 24)
		local events = run(e, w, tgt, 0, 10, function(_, target, en) target.x = en.pos.x; target.z = math.min(en.pos.z + 24, 68) end)
		local cone
		for _, ev in ipairs(each(events, "Tell")) do if ev.shape.kind == "sector" then cone = cone or ev end end
		assert(cone, "no vacuum cone (phases " .. phases(events) .. ")")
		equal(cone.dodgeable, false, "nothing to dodge"); near(cone.shape.r, 30, "range"); near(cone.strikeAt - cone.startAt, 2.9, "the pull's end")
		assert(string.find(phases(events), "Inhale,Vacuum,Recover,Chase", 1, true), "phases " .. phases(events))
		local chase, inhale, vacuum
		for _, ev in ipairs(each(events, "Phase")) do
			if ev.phase == "Chase" then chase = chase or ev.at
			elseif ev.phase == "Inhale" then inhale = inhale or ev.at
			elseif ev.phase == "Vacuum" then vacuum = vacuum or ev.at end
		end
		assert(inhale - chase >= 2 - 1e-6, "it inhaled " .. (inhale - chase) .. " s into the chase")
		near(vacuum - inhale, 0.9, "tell", 1e-6)
		local pulls = each(events, "Pull")
		assert(#pulls >= 6, "pulls " .. #pulls)
		for _, p in ipairs(pulls) do
			near(p.speed, 7, "speed"); assert(p.dz < -0.9, "the pull goes toward him")
			assert(p.at >= vacuum - 1e-6 and p.at <= vacuum + 2 + 1e-6, "a pull outside the Vacuum phase")
			assert(p.untilAt > p.at and p.untilAt <= vacuum + 2 + 1e-6, "a pull past the Vacuum phase")
		end
		for _, hit in ipairs(each(events, "Hit")) do
			assert(hit.at < inhale or hit.at > vacuum + 2 + 1e-6, "the vacuum hit (a later lash may land)")
		end
		local cleared = false
		for _, ev in ipairs(each(events, "TellEnd")) do if ev.tell == cone.tell then cleared = true end end
		assert(cleared, "the cone was not cleared")
	end)

	case("DG2: behind cover the pull stops at once", function()
		local e, w, tgt = boss("g12"), fakeWorld(), target(0, 24)
		local blind = false
		function w.lineOfSight() return not blind end
		local events = run(e, w, tgt, 0, 10, function(_, target, en)
			target.x = en.pos.x; target.z = math.min(en.pos.z + 24, 68)
			if en.phase == "Vacuum" then blind = true end
		end)
		assert(string.find(phases(events), "Vacuum", 1, true), "phases " .. phases(events))
		assert(#each(events, "Pull") <= 1, "pulled behind cover: " .. #each(events, "Pull"))
	end)

	-- DG3 (user 2026-11-15): Muro de chocolate, for a target running away out of the lash's reach.
	case("DG3: a runner out of reach gets a chocolate wall: a crack line, then a ring with a sideways exit, gone after 3 s", function()
		local e, w, tgt = boss("g13"), fakeWorld(), target(0, 24, { vz = 15 })
		local castAt, castZ
		local events = run(e, w, tgt, 0, 9, function(_, target, en) target.x = en.pos.x; target.z = math.min(en.pos.z + 24, 55) end,
			function(t, en) if en.wall and not castAt then castAt, castZ = t, tgt.z end end)
		local wall
		for _, ev in ipairs(each(events, "Tell")) do if ev.shape.kind == "walls" then wall = wall or ev end end
		assert(wall, "no wall (phases " .. phases(events) .. ")")
		equal(wall.dodgeable, false, "nothing to dodge"); near(wall.strikeAt - wall.startAt, 1.0, "the crack line shows 1.0 s")
		near(wall.shape.r, 9, "radius"); assert(wall.shape.z > castZ, "the wall is not ahead of the runner")
		assert(math.abs(wall.shape.gz) < 1e-6, "the exit is not sideways to the route")
		assert(2 * wall.shape.r * math.sin(wall.shape.list[1].from) >= 16, "the exit is narrower than 16 studs")
		local chase
		for _, ev in ipairs(each(events, "Phase")) do if ev.phase == "Chase" then chase = chase or ev.at end end
		assert(wall.startAt - chase >= 1 - 1e-6, "the wall came " .. (wall.startAt - chase) .. " s into the chase")
		local ended
		for _, ev in ipairs(each(events, "TellEnd")) do if ev.tell == wall.tell then ended = ended or ev end end
		assert(ended, "the wall never went down"); near(ended.at - wall.strikeAt, 3, "up 3 s", 0.051)
		local walls = 0
		for _, ev in ipairs(each(events, "Tell")) do if ev.shape.kind == "walls" then walls += 1 end end
		equal(walls, 1, "one wall per cooldown")
	end)

	case("DG3: no wall for a target that does not run away", function()
		local e, w, tgt = boss("g14"), fakeWorld(), target(0, 24)
		local events = run(e, w, tgt, 0, 9, function(_, target, en) target.x = en.pos.x; target.z = math.min(en.pos.z + 24, 55) end)
		for _, ev in ipairs(each(events, "Tell")) do assert(ev.shape.kind ~= "walls", "a wall for a still target") end
	end)

	-- DG5 (decision taken for the user 2026-11-15): Rabia creciente, time carrying an egg in his territory plus dodges.
	case("DG5: a target carrying an egg fills his anger in 10 s; raging, his lash cooldown is halved; the clients hear it", function()
		local e, w, tgt = boss("g15"), fakeWorld(), target(0, 14, { carryingEgg = true })
		local gaps = {}
		local events = run(e, w, tgt, 0, 17, nil, function(t, en)
			if en.phase == "Recover" and en.cast and not gaps[en.cast] then gaps[en.cast] = { at = t, gap = en.readyAt - Latigo.endsAt(en.cast) } end
		end)
		local reports = each(events, "Anger")
		assert(#reports >= 5, "anger reports " .. #reports)
		local rage
		for _, r in ipairs(reports) do if r.rage == true then rage = rage or r end end
		assert(rage, "he never raged"); near(rage.value, 1, "full"); near(rage.at, 10, "full after 10 s of carrying", 0.11)
		local before, during = nil, nil
		for _, g in pairs(gaps) do
			if g.at < rage.at then before = g.gap else during = g.gap end
		end
		near(before, Latigo.COOLDOWN_SECONDS, "the normal cooldown before the rage", 1e-6)
		near(during, Latigo.COOLDOWN_SECONDS * 0.5, "halved while raging", 1e-6)
	end)

	case("DG5: the meter empties when the target stops carrying an egg", function()
		local e, w, tgt = boss("g16"), fakeWorld(), target(0, 14, { carryingEgg = true })
		local events = run(e, w, tgt, 0, 6, function(t, target) target.carryingEgg = t < 5 end)
		local last
		for _, r in ipairs(each(events, "Anger")) do last = r end
		assert(last, "no anger report"); equal(last.value, 0, "emptied"); equal(last.rage, false)
		assert(last.at >= 5 - 1e-6, "emptied before the egg was gone")
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
		-- Deliberately changed (OF3): his chase opens with a 25 studs/s sprint (WildboundCandySmarts), still no teleport
		assert(jump <= 25 * 0.05 + 1e-6, "it jumped " .. jump .. " studs in one step")
		assert(string.find(phases(events), "LoseTarget,Return", 1, true), "phases " .. phases(events))
		local ended = each(events, "End")[1]
		assert(ended and ended.reason == "Return", "it never got home")
	end)

	case("lost from sight: it searches the last seen spot for SearchSeconds, then gives up", function()
		local e, w, tgt = boss("g9"), fakeWorld(), target(0, 25)
		run(e, w, tgt, 0, 2.5)
		equal(e.phase, "Chase", "chasing")
		function w.lineOfSight() return false end
		local events = run(e, w, tgt, 2.55, 2.55 + T.SearchSeconds + 4)
		local list = phases(events)
		assert(string.find(list, "Search,LoseTarget", 1, true), "phases " .. list)
		local search, lose
		for _, ev in ipairs(each(events, "Phase")) do
			if ev.phase == "Search" then search = search or ev.at elseif ev.phase == "LoseTarget" then lose = lose or ev.at end
		end
		near(lose - search, T.SearchSeconds, "search time", 0.051)
	end)

	case("a chase lasts at most ChaseSeconds, then it gives up", function()
		local e, w, tgt = boss("g10"), fakeWorld(), target(0, 30)
		local chaseAt
		local events = run(e, w, tgt, 0, T.ChaseSeconds + 10, function(_, target, en)
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

	-- PF5 (odd/tasks/wildbound-caramelo-playfix.md): in a walked Play the lash shoved the player out of the territory and he
	-- went LoseTarget "Left" in the same step, ending every encounter in 5-8 s. Now the target must stay out of the
	-- territory LeftGraceSeconds in a row before he lets it go.
	case("PF5: a moment outside the territory (a lash's shove) keeps the chase; LeftGraceSeconds outside ends it", function()
		local e, w, tgt = boss("g20"), fakeWorld(), target(0, 30)
		local events = run(e, w, tgt, 0, 9, function(t, target)
			if t >= 4 and t < 4 + T.LeftGraceSeconds - 1 then target.z = T.TerritoryRadiusStuds + 4 else target.z = 30 end
		end)
		for _, ev in ipairs(each(events, "Phase")) do
			assert(ev.phase ~= "LoseTarget", "it let the target go at " .. ev.at .. " (" .. tostring(ev.reason) .. ")")
		end
		-- PF5b (walked Play): his lash shoves a target about 12 studs; one shoved just past the edge and standing there is
		-- still his (the ring of LeftMarginStuds round the territory), however long it stays
		local ring = run(e, w, tgt, 9.05, 9.05 + T.LeftGraceSeconds + 3, function(_, target)
			target.z = T.TerritoryRadiusStuds + T.LeftMarginStuds - 2
		end)
		for _, ev in ipairs(each(ring, "Phase")) do
			assert(ev.phase ~= "LoseTarget", "it let a target in the ring go at " .. ev.at .. " (" .. tostring(ev.reason) .. ")")
		end
		local outAt = 9.05 + T.LeftGraceSeconds + 3.05
		local later = run(e, w, tgt, outAt, outAt + T.LeftGraceSeconds + 1, function(_, target)
			target.z = T.TerritoryRadiusStuds + T.LeftMarginStuds + 4
		end)
		local lose
		for _, ev in ipairs(each(later, "Phase")) do if ev.phase == "LoseTarget" then lose = lose or ev end end
		assert(lose, "it never let a target that stayed outside go (phases " .. phases(later) .. ")")
		equal(lose.reason, "Left", "the reason")
		assert(lose.at >= outAt + T.LeftGraceSeconds - 0.051, "it let go after " .. (lose.at - outAt) .. " s outside")
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

	-- DG6 (user 2026-11-15): Rugido de guardianes.
	case("DG6: his roar at a rare-egg carrier summons fresh Gomibu, Flanfuria and Tortidragon round the thief, once", function()
		assert(type(Boss.ROAR_SUMMONS) == "table", "Boss.ROAR_SUMMONS")
		equal(table.concat(Boss.ROAR_SUMMONS, ","), "Gomibu,Flanfuria,Tortidragon")
		local e, w = boss("dg6a"), fakeWorld()
		local tgt = target(0, 14, { carryingEgg = true, eggRarity = "Epica" })
		local events = run(e, w, tgt, 0, 8)
		local summons = each(events, "Summon")
		equal(#summons, 1, "one roar summon per chase")
		local s = summons[1]
		equal(table.concat(s.names, ","), "Gomibu,Flanfuria,Tortidragon")
		near(s.x, tgt.x, "round the thief"); near(s.z, tgt.z)
		assert(s.ring and s.ring >= 8 and s.ring <= 16, "a ring a few strides away")
		local roar
		for _, ev in ipairs(each(events, "Phase")) do if ev.phase == "Roar" then roar = roar or ev end end
		assert(roar and math.abs(roar.at - s.at) < 1e-6, "with his roar")
	end)

	case("DG6: no summon for a common egg or no egg; a carrier who steals a rare egg mid-chase gets it once", function()
		local e1, w1 = boss("dg6b"), fakeWorld()
		equal(#each(run(e1, w1, target(0, 14, { carryingEgg = true, eggRarity = "Comun" }), 0, 6), "Summon"), 0, "a common egg")
		local e2, w2 = boss("dg6c"), fakeWorld()
		equal(#each(run(e2, w2, target(0, 14), 0, 6), "Summon"), 0, "no egg")
		local e3, w3 = boss("dg6d"), fakeWorld()
		local tgt = target(0, 14)
		local events = run(e3, w3, tgt, 0, 10, function(t, g) if t >= 3 then g.carryingEgg, g.eggRarity = true, "Rara" end end)
		local summons = each(events, "Summon")
		equal(#summons, 1, "once, when the rare egg shows")
		assert(summons[1].at >= 3, "after the steal")
		local roars = 0
		for _, ev in ipairs(each(events, "Phase")) do if ev.phase == "Roar" then roars += 1 end end
		equal(roars, 2, "the notice roar, then the guardians' roar")
	end)

	case("DG6: the director's roar reservation: beyond the per-player cap, never a second of a kind, only the three", function()
		local dir = Director.new()
		local ctx = { alive = true, safe = false, biomes = { Meadow = true } }
		local okBoss = Director.summon(dir, 1, "DonGlaseon", ctx, 100)
		assert(okBoss, "the boss")
		local first = Director.alarm(dir, 1, "Gomibu", ctx, 100)
		assert(first, "a guardian already on the thief")
		local okF, f = Director.roar(dir, 1, "Flanfuria", ctx, 101)
		equal(okF, true, "past MAX_ACTIVE (" .. tostring(f) .. ")")
		equal((Director.roar(dir, 1, "Tortidragon", ctx, 101)), true, "and the third")
		equal(select(2, Director.roar(dir, 1, "Gomibu", ctx, 101)), "AlreadyActive", "the one already present stays the only one")
		equal(select(2, Director.roar(dir, 1, "Viper", ctx, 101)), "NotRoarable")
		equal(select(2, Director.roar(dir, 2, "Flanfuria", { alive = true, safe = true, biomes = { Meadow = true } }, 101)), "SafeZone", "never in a safe zone")
		assert(Director.alarm(dir, 3, "Gomibu", ctx, 101) and Director.alarm(dir, 3, "Flanfuria", ctx, 101), "two on player 3")
		-- PF1 (odd/tasks/wildbound-caramelo-playfix.md): a points-0 guardian takes no MAX_ACTIVE slot, so a third alarm starts too
		equal((Director.alarm(dir, 3, "Tortidragon", ctx, 101)), true, "an alarm is not held back by the cap any more")
	end)

	return result
end

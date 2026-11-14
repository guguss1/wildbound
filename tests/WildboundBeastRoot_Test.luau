-- Invoke with require(freshTestClone)(require(freshBeastEncountersClone), require(freshBeastRootClone),
-- require(freshBeastConfigClone), freshBeastRootClone.Source).
-- Wave 2 (odd/tasks/wildbound-beasts-wave2.md, BW2-5): Root's state machine, pure, with a fake world (flat ground at
-- y 0) and a fake dodge. The target stands in the Pantano (biomes.Swamp) unless a case moves it out.
return function(Enc, Root, Config, source)
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
	Enc.register("Root", Root)
	local C = Config.BEASTS.Root
	local T = C.tuning

	local function fakeWorld()
		local w = { telegraphs = {}, resolved = {}, cancelled = {}, verdict = "Hit", gapOpen = true }
		function w.ground() return 0 end
		function w.landing() return 0 end
		function w.safe() return false end
		function w.gapClear() return w.gapOpen end
		function w.telegraph(id, beast, startAt, strikeAt)
			table.insert(w.telegraphs, { id = id, beast = beast, startAt = startAt, strikeAt = strikeAt })
			return true
		end
		function w.resolve(id) table.insert(w.resolved, id); return w.verdict end
		function w.cancel(id) table.insert(w.cancelled, id) end
		return w
	end
	local function target(x, z) return { x = x, y = 3, z = z, alive = true, safe = false, biomes = { Swamp = true } } end
	local function run(e, w, tgt, from, to, move)
		local all = {}
		-- Times from a step index, so 0.05 s steps never drift.
		for i = 0, math.floor((to - from) / 0.05 + 1e-6) do
			local t = from + i * 0.05
			if move then move(t, tgt) end
			for _, ev in ipairs(Enc.step(e, t, tgt, w)) do table.insert(all, ev) end
		end
		return all
	end
	local function find(events, kind, field, value)
		for _, ev in ipairs(events) do
			if ev.type == kind and (field == nil or ev[field] == value) then return ev end
		end
		return nil
	end
	local function tellOf(events, kind)
		for _, ev in ipairs(events) do
			if ev.type == "Tell" and ev.shape and ev.shape.kind == kind then return ev end
		end
		return nil
	end
	local function hitsFor(events, id)
		local list = {}
		for _, ev in ipairs(events) do if ev.type == "Hit" and ev.attack == id then table.insert(list, ev) end end
		return list
	end

	case("BW2 Root: rises, then the trap: fixed lanes 4 studs wide, at most 12 segments, 1.15 s before the eruption", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = Enc.new("Root", "beast:1", 1, 0, { x = 0, y = 0, z = -20 })
		local events = run(e, w, tgt, 0, 3, function(t, tg)
			if t > 1.5 then tg.x = 0.5 end -- a small step: the lanes never follow
		end)
		local rise = find(events, "Phase", "phase", "Rise")
		near(rise.untilAt - rise.at, C.spawnSeconds)
		local tell = tellOf(events, "multi")
		assert(tell, "the trap tell")
		near(tell.at, C.spawnSeconds, "after the rise", 0.051)
		near(tell.strikeAt - tell.startAt, T.TrapTelegraphSeconds)
		equal(#tell.shape.list, C.trapLanes)
		assert(#tell.shape.list * tell.shape.segments <= T.MaxActiveRootSegments, "segment budget")
		for _, lane in ipairs(tell.shape.list) do equal(lane.width, T.TrapLaneWidthStuds) end
		equal(w.telegraphs[1].id, tell.tell, "registered with the dodge")
		for _, ev in ipairs(events) do
			if ev.type == "Tell" and ev.tell == tell.tell then equal(ev.shape, tell.shape, "the lanes never move") end
		end
	end)

	case("BW2 Root: one eruption hit with damage and the slow, even standing in the lane for the whole window", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = Enc.new("Root", "beast:2", 1, 0, { x = 0, y = 0, z = -20 })
		local events = run(e, w, tgt, 0, 3)
		local tell = tellOf(events, "multi")
		local hits = hitsFor(events, tell.tell)
		equal(#hits, 1, "one hit per eruption")
		equal(hits[1].damage, T.TrapDamage)
		equal(hits[1].slow.multiplier, T.TrapSlowMultiplier); equal(hits[1].slow.seconds, T.TrapSlowSeconds)
		assert(hits[1].at >= tell.strikeAt - 1e-9 and hits[1].at <= tell.strikeAt + C.trapActiveSeconds + 1e-9, "inside the window")
		local recovery = find(events, "Phase", "phase", "Recovery")
		near(recovery.untilAt - recovery.at, T.AttackCooldownSeconds)
	end)

	case("BW2 Root: a validated perfect dodge avoids the damage and the slow", function()
		local w = fakeWorld()
		w.verdict = "Dodged"
		local tgt = target(0, 0)
		local e = Enc.new("Root", "beast:3", 1, 0, { x = 0, y = 0, z = -20 })
		local events = run(e, w, tgt, 0, 3)
		equal(#hitsFor(events, tellOf(events, "multi").tell), 0)
		equal(find(events, "Strike").dodged, true)
	end)

	case("BW2 Root: lanes stop before a safe zone", function()
		local w = fakeWorld()
		function w.safe(_, z) return z > 1 end
		local tgt = target(0, 0)
		local e = Enc.new("Root", "beast:4", 1, 0, { x = 0, y = 0, z = -20 })
		local events = run(e, w, tgt, 0, 1.2)
		local tell = tellOf(events, "multi")
		for _, lane in ipairs(tell.shape.list) do
			local endZ = lane.oz + lane.dz * lane.length
			assert(not w.safe(lane.ox + lane.dx * lane.length, endZ), "a lane reaches a safe zone at z " .. endZ)
		end
	end)

	case("BW2 Root: the enclosure leaves one gap of at least 9 studs, away from Root; the whip cannot reach it", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = Enc.new("Root", "beast:5", 1, 0, { x = 0, y = 0, z = -20 })
		local events = run(e, w, tgt, 0, 9)
		local walls = tellOf(events, "walls")
		assert(walls, "the walls tell")
		equal(walls.dodgeable, false, "walls never hit")
		near(walls.strikeAt - walls.startAt, T.WallTelegraphSeconds)
		local shape = walls.shape
		assert(Config.gapWidth(shape) >= T.SafeGapMinimumStuds - 1e-6, "gap " .. Config.gapWidth(shape))
		equal(Config.shapeHit(shape, shape.x, shape.z), false, "walls never deal damage")
		assert(shape.gz > 0.99, "the gap faces away from Root (which came from -z)")
		local burrow = find(events, "Move", "kind", "burrow")
		assert(burrow, "Root moves to the closed end")
		near(burrow.to.z, shape.z - shape.gz * C.enclosureRadius, "opposite the gap")
		local whip = tellOf(events, "sector")
		assert(whip and whip.dodgeable, "the whip tell, dodgeable")
		near(whip.strikeAt - whip.startAt, T.WhipTelegraphSeconds)
		equal(whip.shape.arc, T.WhipArcDegrees)
		near(whip.startAt, walls.strikeAt + C.whipDelay, "the whip winds up during the hold")
		assert(whip.strikeAt <= walls.strikeAt + T.WallHoldSeconds, "the whip strikes before the walls drop")
		-- Standing just outside the gap is out of the whip's reach; the centre is inside it.
		local outside = { x = shape.x + shape.gx * (shape.r + 1), z = shape.z + shape.gz * (shape.r + 1) }
		equal(Config.shapeHit(whip.shape, outside.x, outside.z), false, "the escape is safe")
		equal(Config.shapeHit(whip.shape, shape.x, shape.z), true, "staying inside is not")
	end)

	case("BW2 Root: leaving through the gap avoids the whip; staying is one hit", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = Enc.new("Root", "beast:6", 1, 0, { x = 0, y = 0, z = -20 })
		local events = run(e, w, tgt, 0, 12)
		local whip = tellOf(events, "sector")
		equal(#hitsFor(events, whip.tell), 1, "stayed inside: one hit")
		equal(hitsFor(events, whip.tell)[1].damage, T.WhipDamage)
		local w2 = fakeWorld()
		local tgt2 = target(0, 0)
		local e2 = Enc.new("Root", "beast:7", 1, 0, { x = 0, y = 0, z = -20 })
		local events2 = run(e2, w2, tgt2, 0, 12, function(_, tg)
			if e2.walls and e2.phase ~= "TelegraphTrap" then tg.z = 11 end -- out through the gap
		end)
		local whip2 = tellOf(events2, "sector")
		equal(#hitsFor(events2, whip2.tell), 0, "escaped")
		local tellEnd = find(events2, "TellEnd")
		assert(tellEnd and tellEnd.tell:find(":walls", 1, true), "the walls go down")
	end)

	case("BW2 Root: with every gap blocked the enclosure is skipped and the trap is used instead", function()
		local w = fakeWorld()
		w.gapOpen = false
		local tgt = target(0, 0)
		local e = Enc.new("Root", "beast:8", 1, 0, { x = 0, y = 0, z = -20 })
		local events = run(e, w, tgt, 0, 9)
		equal(tellOf(events, "walls"), nil, "no enclosure without a way out")
		local traps = 0
		for _, ev in ipairs(events) do if ev.type == "Tell" and ev.shape.kind == "multi" then traps += 1 end end
		equal(traps, 2, "two traps")
	end)

	case("BIOME-OFF Root: out of the Pantano it keeps hunting (no home biome); a safe zone ends it at once", function()
		equal(Config.homeBiome("Root"), nil, "BIOME_PREFERENCE off")
		local w = fakeWorld()
		local tgt = target(0, 0)
		tgt.biomes = {}
		local e = Enc.new("Root", "beast:9", 1, 0, { x = 0, y = 0, z = -20 })
		local events = run(e, w, tgt, 0, 6)
		equal(find(events, "Disengage"), nil, "no LeftBiome outside the swamp")
		equal(find(events, "End"), nil, "still hunting after 6 s")
		assert(find(events, "Tell"), "it attacks in the open forest")
		local w2 = fakeWorld()
		local e2 = Enc.new("Root", "beast:10", 1, 0, { x = 0, y = 0, z = -20 })
		local safe = target(0, 0)
		safe.safe = true
		equal(find(Enc.step(e2, 0.05, safe, w2), "End").reason, "SafeZone")
	end)

	case("BW2 Root: the module is pure and server-only", function()
		for _, banned in ipairs({ "workspace", "game:", "task.", "os.clock", "math.random", "Random.new", "Touched", "FireClient" }) do
			assert(not source:find(banned, 1, true), "source uses " .. banned)
		end
	end)

	return result
end

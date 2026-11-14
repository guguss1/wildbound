-- Invoke with require(freshTestClone)(require(freshBeastEncountersClone), require(freshBeastNubeClone),
-- require(freshBeastConfigClone), freshBeastNubeClone.Source, require(freshPraderaSitesClone)).
-- Kids biome (odd/tasks/wildbound-kids-beasts.md, KB-2): La Nube Gruñona's state machine, pure. A fake world (flat
-- ground at y 0, a gate site) and a target whose `covered`, `night` and `markedUntil` stand in for the server's sky
-- ray, day cycle and mark attribute.
return function(Enc, Nube, Config, source, Sites)
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
	Enc.register("NubeGrunona", Nube)
	local C = Config.BEASTS.NubeGrunona
	local T = C.tuning
	local GATE = { x = -186, z = 0 }

	local function fakeWorld()
		local w = { telegraphs = {}, cancelled = {} }
		function w.ground() return 0 end
		function w.site(key) if key == "gate" then return GATE end return nil end
		function w.telegraph(id) table.insert(w.telegraphs, id); return true end
		function w.resolve() return "Hit" end
		function w.cancel(id) table.insert(w.cancelled, id) end
		return w
	end
	local function target(x, z, extra)
		local tgt = { x = x, y = 3, z = z, alive = true, safe = false, covered = false, night = false }
		for k, v in pairs(extra or {}) do tgt[k] = v end
		return tgt
	end
	local function run(e, w, tgt, from, to, move)
		local all = {}
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
	local function phases(events)
		local list = {}
		for _, ev in ipairs(events) do if ev.type == "Phase" then table.insert(list, ev.phase) end end
		return table.concat(list, ",")
	end
	-- The pond at the origin; a cloud summoned there.
	local function nube(id)
		return Enc.new("NubeGrunona", id, 1, 0, { x = 0, y = 0, z = 0 })
	end

	case("KB-2 Nube config: summoned guardian, damage 0, points 0, never rolled", function()
		equal(Config.SUMMONED.NubeGrunona, true); equal(C.category, "Guardian"); equal(C.biome, "Meadow")
		equal(C.damage, 0, "kids rule"); equal(C.points, 0, "outside the budget")
		equal(Config.PLAYABLE.NubeGrunona, nil, "never rolled")
		for _, name in ipairs(Config.ORDER) do assert(name ~= "NubeGrunona", "not in ORDER") end
		assert(table.isfrozen(T), "tuning frozen")
		equal(T.LeashStuds, 90); equal(T.BoltRadiusStuds, 6); equal(T.DetectionRadiusStuds, 40)
		equal(T.NightDetectionRadiusStuds, 20); equal(T.EscapeDistanceStuds, 110); equal(C.endCooldowns.Yawn, 60)
		equal(C.cooldown, 10)
	end)

	case("KB-2 Nube: a notice needs open sky and range; a roof blocks it", function()
		local e = nube("beast:1")
		local events = run(e, fakeWorld(), target(30, 0), 0, 0.5)
		assert(find(events, "Phase", "phase", "Notice"), "open sky in 40: Gruñido")
		local e2 = nube("beast:2")
		events = run(e2, fakeWorld(), target(30, 0, { covered = true }), 0, 3)
		equal(find(events, "Phase", "phase", "Notice"), nil, "a roof over the target hides it")
		local e3 = nube("beast:3")
		events = run(e3, fakeWorld(), target(65, 0), 0, 3)
		equal(find(events, "Phase", "phase", "Notice"), nil, "out of range (it drifts at most 20 from the pond)")
	end)

	case("KB-2 Nube: at Night it sees 20 studs, and it is summoned only within 25 of the pond", function()
		local e = nube("beast:4")
		local events = run(e, fakeWorld(), target(46, 0, { night = true }), 0, 3)
		equal(find(events, "Phase", "phase", "Notice"), nil, "over 20 at Night (26 at the closest drift)")
		local e2 = nube("beast:5")
		events = run(e2, fakeWorld(), target(15, 0, { night = true }), 0, 0.5)
		assert(find(events, "Phase", "phase", "Notice"), "15 <= 20 at Night")
		local pond = Sites.world(nil, "pond")
		local ctx = { alive = true, safe = false, meadow = true, night = true, x = pond.x + 24, z = pond.z }
		equal(Sites.wants("NubeGrunona", ctx), true, "24 from the pond at Night")
		ctx.x = pond.x + 26
		equal(Sites.wants("NubeGrunona", ctx), false, "26 from the pond at Night")
		ctx.night, ctx.x = false, pond.x + 105
		equal(Sites.wants("NubeGrunona", ctx), true, "105 by day (110)")
		ctx.x = pond.x + 115
		equal(Sites.wants("NubeGrunona", ctx), false, "115 by day")
		ctx.x, ctx.meadow = pond.x, false
		equal(Sites.wants("NubeGrunona", ctx), false, "only inside the Pradera")
		ctx.meadow, ctx.safe = true, true
		equal(Sites.wants("NubeGrunona", ctx), false, "never in a safe zone")
	end)

	case("KB-2 Nube: Gruñido 1.5 s still, then a chase at 14 (slower than a 16 runner)", function()
		local e = nube("beast:6")
		local w = fakeWorld()
		local tgt = target(35, 0)
		local events = run(e, w, tgt, 0, 0.05)
		equal(e.phase, "Notice")
		local x0 = e.pos.x
		events = run(e, w, tgt, 0.1, T.GrowlSeconds - 0.05)
		near(e.pos.x, x0, "no movement while growling")
		assert(T.ChaseSpeedStudsPerSecond < 16, "slower than a walking player")
		events = run(e, w, tgt, T.GrowlSeconds, T.GrowlSeconds + 1)
		assert(find(events, "Phase", "phase", "Chase"), "it chases")
		near(e.pos.x - x0, T.ChaseSpeedStudsPerSecond * 1, "14 studs in 1 s", 0.8)
	end)

	case("KB-2 Nube: the leash keeps it within 90 of the pond", function()
		local e = nube("beast:7")
		local tgt = target(30, 0)
		local maxFromPond = 0
		run(e, fakeWorld(), tgt, 0, 11.5, function(t, tg)
			tg.x = math.min(30 + t * 12, 109) -- a runner just ahead, never past the escape ring
			maxFromPond = math.max(maxFromPond, Config.flat(e.pos.x, e.pos.z, 0, 0))
		end)
		assert(maxFromPond <= T.LeashStuds + 1e-6, "leash " .. maxFromPond)
	end)

	case("KB-2 Nube: Relámpago: a fixed ring r 6, tell 1.0 s (never under 0.8), hits only inside and uncovered", function()
		assert(T.BoltTelegraphSeconds >= Config.MIN_TELL, "the fair-strike floor")
		near(Nube.tellSeconds(T), 1.0)
		local e = nube("beast:8")
		local w = fakeWorld()
		local tgt = target(10, 0)
		local events = run(e, w, tgt, 0, T.GrowlSeconds + 0.1)
		local tell = find(events, "Tell")
		assert(tell, "a tell within 12")
		equal(tell.shape.kind, "circle"); equal(tell.shape.r, T.BoltRadiusStuds)
		near(tell.shape.x, 10); near(tell.strikeAt - tell.startAt, 1.0)
		assert(find(events, "Tell", "locked", true), "locked at once: the ring never follows")
		-- The target steps out of the ring before the strike.
		events = run(e, w, tgt, T.GrowlSeconds + 0.15, T.GrowlSeconds + 1.3, function(_, tg) tg.x = 20 end)
		equal(find(events, "Hit"), nil, "outside the ring: no hit")
		assert(find(events, "Strike", "hit", false), "a miss")
		-- Inside but under a roof at the strike: no hit.
		local e2 = nube("beast:9")
		local tgt2 = target(10, 0)
		run(e2, w, tgt2, 0, T.GrowlSeconds + 0.1)
		events = run(e2, w, tgt2, T.GrowlSeconds + 0.15, T.GrowlSeconds + 1.3, function(_, tg) tg.covered = true end)
		equal(find(events, "Hit"), nil, "covered at impact: no hit")
	end)

	case("KB-2 Nube: a hit deals 0 and marks; a second hit while marked is the Ráfaga toward the gate", function()
		local e = nube("beast:10")
		local w = fakeWorld()
		local tgt = target(10, 0)
		local events = run(e, w, tgt, 0, T.GrowlSeconds + 1.2)
		local hit = find(events, "Hit")
		assert(hit, "standing in the ring")
		equal(hit.damage, 0, "kids rule: no damage")
		equal(hit.mark, T.MarkSeconds, "the mark")
		equal(hit.knock, nil, "no push on the first hit")
		tgt.markedUntil = hit.at + T.MarkSeconds
		events = run(e, w, tgt, T.GrowlSeconds + 1.25, T.GrowlSeconds + 5)
		local second = find(events, "Hit")
		assert(second, "a second bolt")
		equal(second.damage, 0)
		assert(second.knock and second.knock.speed == T.GustStudsPerSecond, "the Ráfaga knock")
		assert(second.knock.dx < -0.99, "toward the gate (west)")
		equal(second.line, "Gust")
	end)

	case("KB-2 Nube: gives up after 12 s of chase or past 60 studs (Desinflada, End GiveUp)", function()
		local e = nube("beast:11")
		local w = fakeWorld()
		local tgt = target(30, 0)
		-- The target circles just out of bolt range, always seen.
		local events = run(e, w, tgt, 0, 17.5, function(t, tg)
			local a = t * 0.6
			tg.x, tg.z = e.pos.x + math.cos(a) * 20, e.pos.z + math.sin(a) * 20
		end)
		local giveUp = find(events, "Phase", "phase", "GiveUp")
		assert(giveUp, "Desinflada after the chase limit: " .. phases(events))
		near(giveUp.at, T.GrowlSeconds + T.ChaseGiveUpSeconds, "12 s after the chase began", 0.06)
		equal(find(events, "End").reason, "GiveUp")
		local e2 = nube("beast:12")
		local tgt2 = target(30, 0)
		run(e2, w, tgt2, 0, T.GrowlSeconds + 0.05)
		events = run(e2, w, tgt2, T.GrowlSeconds + 0.1, T.GrowlSeconds + 0.3, function(_, tg) tg.x = e2.pos.x + 65 end)
		assert(find(events, "Phase", "phase", "GiveUp"), "past 60 studs")
	end)

	case("KB-2 Nube: Bostezo after 3 roof losses in one chase (End Yawn, the 60 s nap)", function()
		local e = nube("beast:13")
		local w = fakeWorld()
		local tgt = target(25, 0)
		local events = run(e, w, tgt, 0, 8, function(t, tg)
			tg.x = e.pos.x + 25
			-- Under a roof for 0.3 s every second: seen again before the 2 s memory runs out.
			tg.covered = t > T.GrowlSeconds and (t % 1) < 0.3
		end)
		assert(find(events, "Phase", "phase", "Yawn"), "Bostezo: " .. phases(events))
		equal(find(events, "End").reason, "Yawn")
	end)

	case("KB-2 Nube: escape outside 110 of the pond for 2 s; death and safety end it at once", function()
		local e = nube("beast:14")
		local w = fakeWorld()
		local events = run(e, w, target(115, 0), 0, 3)
		local d = find(events, "Disengage")
		assert(d and d.reason == "Escape", "escape")
		near(d.at, T.EscapeSeconds, "after 2 s", 0.06)
		local e2 = nube("beast:15")
		events = run(e2, w, target(10, 0, { safe = true }), 0, 0.1)
		equal(find(events, "End").reason, "SafeZone")
		local e3 = nube("beast:16")
		events = run(e3, w, target(10, 0, { alive = false }), 0, 0.1)
		equal(find(events, "End").reason, "Death")
	end)

	case("KB-2 Nube: the module is pure and server-only", function()
		for _, banned in ipairs({ "workspace", "game:", "task.", "os.clock", "math.random", "Random.new", "Touched", "FireClient" }) do
			assert(not source:find(banned, 1, true), "source uses " .. banned)
		end
	end)

	return result
end

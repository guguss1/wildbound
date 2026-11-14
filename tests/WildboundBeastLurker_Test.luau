-- Invoke with require(freshTestClone)(require(freshBeastEncountersClone), require(freshBeastLurkerClone),
-- require(freshBeastConfigClone), freshBeastLurkerClone.Source).
-- Wave 2 (odd/tasks/wildbound-beasts-wave2.md, BW2-5): Lurker's state machine, pure. target.observe stands in for the
-- validated observation; a fake world (flat ground at y 0, every landing valid, open lines) and a fake dodge.
return function(Enc, Lurker, Config, source)
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
	Enc.register("Lurker", Lurker)
	local C = Config.BEASTS.Lurker
	local T = C.tuning

	local function fakeWorld()
		local w = { telegraphs = {}, resolved = {}, cancelled = {}, verdict = "Hit" }
		function w.ground() return 0 end
		function w.landing() return 0 end
		function w.lineOfSight() return true end
		function w.telegraph(id, beast, startAt, strikeAt)
			table.insert(w.telegraphs, { id = id, beast = beast, startAt = startAt, strikeAt = strikeAt })
			return true
		end
		function w.resolve(id) table.insert(w.resolved, id); return w.verdict end
		function w.cancel(id) table.insert(w.cancelled, id) end
		return w
	end
	local function target(looking)
		local tgt = { x = 0, y = 3, z = 0, alive = true, safe = false, biomes = {}, calls = {}, now = 0 }
		tgt.observe = function(point, halfAngle, maxDist, favour)
			table.insert(tgt.calls, { halfAngle = halfAngle, maxDist = maxDist, favour = favour })
			return looking(tgt.now)
		end
		return tgt
	end
	local function run(e, w, tgt, from, to, move)
		local all = {}
		for i = 0, math.floor((to - from) / 0.05 + 1e-6) do
			local t = from + i * 0.05
			tgt.now = t
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
	local function always(value) return function() return value end end
	local function flat(e, tgt) return Config.flat(e.pos.x, e.pos.z, tgt.x, tgt.z) end

	case("BW2 Lurker: presence is clues only: no leap even in range; the observation favours the player", function()
		local w = fakeWorld()
		local tgt = target(always(false))
		local e = Enc.new("Lurker", "beast:1", 1, 0, { x = 0, y = 0, z = -15 }) -- already in leap range
		local events = run(e, w, tgt, 0, C.presenceSeconds - 0.05)
		equal(find(events, "Tell"), nil, "no leap while present")
		near(flat(e, tgt), 15, "it keeps its distance")
		equal(tgt.calls[1].favour, true, "a short gap in the camera data reads as observed")
		equal(tgt.calls[1].halfAngle, C.observeCone)
	end)

	case("BW2 Lurker: unobserved it closes in by walking bursts, then a 0.8 s windup and a 0.55 s leap; one hit", function()
		local w = fakeWorld()
		local tgt = target(always(false))
		local e = Enc.new("Lurker", "beast:2", 1, 0, { x = 0, y = 0, z = -T.InitialSpawnDistanceStuds })
		local maxStep = 0
		local last, lastPhase = { x = e.pos.x, z = e.pos.z }, e.phase
		local events = run(e, w, tgt, 0, 9, function()
			-- Only steps that began and ended outside the leap: stalking never jumps.
			local stalking = { Presence = true, CoverApproach = true, StalkObserved = true }
			if stalking[lastPhase] and stalking[e.phase] then
				maxStep = math.max(maxStep, Config.flat(last.x, last.z, e.pos.x, e.pos.z))
			end
			last, lastPhase = { x = e.pos.x, z = e.pos.z }, e.phase
		end)
		assert(maxStep <= T.UnobservedApproachSpeedStudsPerSecond * 0.05 + 1e-6, "never a jump while stalking: " .. maxStep)
		local tell = find(events, "Tell")
		assert(tell and tell.shape.kind == "circle", "the landing circle")
		equal(tell.shape.r, C.leapRadius)
		near(tell.strikeAt - tell.startAt, T.LeapTelegraphSeconds + T.LeapTravelSeconds)
		near(tell.lockAt - tell.startAt, T.LeapTelegraphSeconds, "the spot freezes at the end of the windup")
		local reg = w.telegraphs[1]
		equal(reg.id, tell.tell); equal(reg.beast, "Lurker")
		local hits = 0
		for _, ev in ipairs(events) do if ev.type == "Hit" then hits += 1; equal(ev.damage, T.LeapDamage) end end
		equal(hits, 1, "one hit per leap")
		local arc = find(events, "Move", "kind", "arc")
		assert(arc, "the arc for the client")
		near(arc.landAt - arc.at, T.LeapTravelSeconds)
	end)

	case("BW2 Lurker: observed it freezes 1.4 s, then backs off; it never leaps while watched", function()
		local w = fakeWorld()
		local tgt = target(always(true))
		local e = Enc.new("Lurker", "beast:3", 1, 0, { x = 0, y = 0, z = -30 })
		run(e, w, tgt, 0, C.presenceSeconds)
		local d0 = flat(e, tgt)
		local events = run(e, w, tgt, C.presenceSeconds + 0.05, C.presenceSeconds + T.ObservedPauseSeconds - 0.05)
		equal(e.phase, "StalkObserved")
		near(flat(e, tgt), d0, "frozen during the pause")
		events = run(e, w, tgt, C.presenceSeconds + T.ObservedPauseSeconds + 0.05, 12)
		assert(flat(e, tgt) > d0 + 1, "it backs off while watched")
		equal(find(events, "Tell"), nil, "no leap while watched")
	end)

	case("BW2 Lurker: hysteresis: a flickering observation never flips its state", function()
		local w = fakeWorld()
		local flip = false
		local tgt = target(function() flip = not flip; return flip end)
		local e = Enc.new("Lurker", "beast:4", 1, 0, { x = 0, y = 0, z = -40 })
		local events = run(e, w, tgt, 0, 6)
		equal(find(events, "Phase", "phase", "StalkObserved"), nil)
		assert(find(events, "Phase", "phase", "CoverApproach"), "it keeps approaching")
	end)

	case("BW2 Lurker: a validated perfect dodge: no damage, an overrun of 7 studs and a 1.8 s stun", function()
		local w = fakeWorld()
		w.verdict = "Dodged"
		local tgt = target(always(false))
		local e = Enc.new("Lurker", "beast:5", 1, 0, { x = 0, y = 0, z = -T.InitialSpawnDistanceStuds })
		local events = run(e, w, tgt, 0, 9)
		equal(find(events, "Hit"), nil)
		local slide = find(events, "Move", "kind", "slide")
		assert(slide, "the overrun")
		near(Config.flat(slide.from.x, slide.from.z, slide.to.x, slide.to.z), T.LeapOverrunDistanceStuds)
		assert(slide.to.z > slide.from.z, "past the spot, along the leap")
		local stun = find(events, "Phase", "phase", "OverrunStunned")
		near(stun.untilAt - stun.at, T.PerfectDodgeStunSeconds)
	end)

	case("BW2 Lurker: a target that teleports during the windup calls the leap off; a safe zone ends it", function()
		local w = fakeWorld()
		local tgt = target(always(false))
		local e = Enc.new("Lurker", "beast:6", 1, 0, { x = 0, y = 0, z = -T.InitialSpawnDistanceStuds })
		local events = run(e, w, tgt, 0, 9, function(_, tg) if e.phase == "LeapWindup" then tg.x = 90 end end)
		local dropped = find(events, "TellEnd")
		assert(dropped and dropped.reason == "NoLanding", "no leap at a far spot")
		equal(w.cancelled[1], w.telegraphs[1].id, "the dodge registration is cancelled")
		equal(find(events, "Hit"), nil)
		local w2 = fakeWorld()
		local tgt2 = target(always(false))
		local e2 = Enc.new("Lurker", "beast:7", 1, 0, { x = 0, y = 0, z = -T.InitialSpawnDistanceStuds })
		local ended
		run(e2, w2, tgt2, 0, 9, function(_, tg)
			if e2.phase == "LeapWindup" and not ended then
				tg.safe = true
				ended = true
				assert(next(e2.open) ~= nil, "the leap is open when the target reaches safety")
			end
		end)
		equal(e2.endReason, "SafeZone")
	end)

	case("BW2 Lurker: the module is pure and server-only", function()
		for _, banned in ipairs({ "workspace", "game:", "task.", "os.clock", "math.random", "Random.new", "Touched", "FireClient" }) do
			assert(not source:find(banned, 1, true), "source uses " .. banned)
		end
	end)

	return result
end

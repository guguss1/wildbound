-- Invoke with require(freshTestClone)(require(freshBeastEncountersClone), require(freshBeastGazeClone),
-- require(freshBeastConfigClone), freshBeastGazeClone.Source).
-- Wave 2 (odd/tasks/wildbound-beasts-wave2.md, BW2-5): Gaze's state machine, pure. target.observe stands in for the
-- beast script's validated observation (WildboundBeastSight plus the server raycast); each case says when the target
-- looks. A fake world (flat ground at y 0) and a fake dodge.
return function(Enc, Gaze, Config, source)
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
	Enc.register("Gaze", Gaze)
	local C = Config.BEASTS.Gaze
	local T = C.tuning

	local function fakeWorld()
		local w = { telegraphs = {}, resolved = {}, cancelled = {}, verdict = "Hit" }
		function w.ground() return 0 end
		function w.telegraph(id, beast, startAt, strikeAt)
			table.insert(w.telegraphs, { id = id, beast = beast, startAt = startAt, strikeAt = strikeAt })
			return true
		end
		function w.resolve(id) table.insert(w.resolved, id); return w.verdict end
		function w.cancel(id) table.insert(w.cancelled, id) end
		return w
	end
	-- looking(t) says whether the target observes Gaze at time t; the arguments of every call are kept.
	local function target(looking)
		local tgt = { x = 0, y = 3, z = 0, alive = true, safe = false, biomes = {}, calls = {}, now = 0 }
		tgt.observe = function(point, halfAngle, maxDist, favour)
			table.insert(tgt.calls, { point = point, halfAngle = halfAngle, maxDist = maxDist, favour = favour })
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

	case("BW2 Gaze: manifests for a while with no tell, then builds exposure only while observed", function()
		local w = fakeWorld()
		local tgt = target(always(true))
		local e = Enc.new("Gaze", "beast:1", 1, 0, { x = 0, y = 0, z = -40 })
		local events = run(e, w, tgt, 0, C.manifestSeconds)
		local manifest = find(events, "Phase", "phase", "Manifest")
		near(manifest.untilAt - manifest.at, C.manifestSeconds)
		equal(find(events, "Tell"), nil, "no tell while manifesting")
		equal(#tgt.calls, 0, "the observation is not read while it manifests")
		run(e, w, tgt, C.manifestSeconds + 0.05, C.manifestSeconds + 1)
		local call = tgt.calls[1]
		equal(call.halfAngle, T.SightConeDegrees); equal(call.maxDist, T.MaxViewDistanceStuds)
		equal(call.favour, false, "lag never builds exposure")
		near(call.point.y, C.eyeHeight, "the cone aims at the eyes")
		assert(e.exposure > 0.9 and e.exposure < 1.1, "about 1 s of exposure: " .. e.exposure)
	end)

	case("BW2 Gaze: 3.5 s of exposure fixes a 7-stud zone on the target, 1.25 s, dodgeable; one hit", function()
		local w = fakeWorld()
		local tgt = target(always(true))
		local e = Enc.new("Gaze", "beast:2", 1, 0, { x = 0, y = 0, z = -40 })
		local events = run(e, w, tgt, 0, 8)
		local tell = find(events, "Tell")
		assert(tell, "the zone")
		equal(tell.shape.kind, "circle"); equal(tell.shape.r, T.ZoneRadiusStuds)
		near(tell.shape.x, 0); near(tell.shape.z, 0)
		near(tell.at, C.manifestSeconds + T.ExposureToAttackSeconds, "after 3.5 s of exposure", 0.11)
		near(tell.strikeAt - tell.startAt, T.ZoneTelegraphSeconds)
		equal(w.telegraphs[1].beast, "Gaze")
		local hits = 0
		for _, ev in ipairs(events) do
			if ev.type == "Hit" then hits += 1; equal(ev.damage, T.ZoneDamage) end
		end
		equal(hits, 1)
		local exposure = find(events, "Exposure")
		assert(exposure and exposure.value >= 0 and exposure.value <= 1, "a 0 to 1 meter")
	end)

	case("BW2 Gaze: looking away before the charge cancels it after the grace; no zone", function()
		local w = fakeWorld()
		local tgt = target(function(t) return t < 4 end)
		local e = Enc.new("Gaze", "beast:3", 1, 0, { x = 0, y = 0, z = -40 })
		local events = run(e, w, tgt, 0, 7)
		equal(find(events, "Tell"), nil, "no zone")
		local broken = find(events, "SightBreak")
		assert(broken, "the link breaks")
		-- About 2 s of exposure decays at 1.8 per second after the 0.25 s grace.
		near(broken.at, 4 + T.SightBreakGraceSeconds + 2 / T.ExposureDecayPerSecond, "decay time", 0.15)
	end)

	case("BW2 Gaze: a committed zone still strikes when the target looks away; leaving the circle avoids it", function()
		local w = fakeWorld()
		local looking = true
		local tgt = target(function() return looking end)
		local e = Enc.new("Gaze", "beast:4", 1, 0, { x = 0, y = 0, z = -40 })
		local events = run(e, w, tgt, 0, 8, function() if e.phase == "ChargeZone" then looking = false end end)
		local tell = find(events, "Tell")
		assert(find(events, "Hit"), "looking away does not erase the zone")
		local w2 = fakeWorld()
		local tgt2 = target(always(true))
		local e2 = Enc.new("Gaze", "beast:5", 1, 0, { x = 0, y = 0, z = -40 })
		local events2 = run(e2, w2, tgt2, 0, 8, function(_, tg) if e2.phase == "ChargeZone" then tg.x = 8 end end)
		equal(find(events2, "Hit"), nil, "8 studs out of a 7-stud circle")
		equal(w2.cancelled[1], w2.telegraphs[1].id)
		assert(tell and find(events2, "Phase", "phase", "Dissipate"), "it dissipates after the discharge")
	end)

	case("BW2 Gaze: a perfect dodge cancels the zone's damage", function()
		local w = fakeWorld()
		w.verdict = "Dodged"
		local tgt = target(always(true))
		local e = Enc.new("Gaze", "beast:6", 1, 0, { x = 0, y = 0, z = -40 })
		local events = run(e, w, tgt, 0, 8)
		equal(find(events, "Hit"), nil)
		equal(find(events, "Strike").dodged, true)
	end)

	case("BW2 Gaze: never observed for 6 s it leaves; the zone is fair for a walking player", function()
		local w = fakeWorld()
		local tgt = target(always(false))
		local e = Enc.new("Gaze", "beast:7", 1, 0, { x = 0, y = 0, z = -40 })
		local events = run(e, w, tgt, 0, 10)
		local dis = find(events, "Disengage")
		equal(dis.reason, "Unseen")
		near(dis.at, C.manifestSeconds + T.DisengageIfUnseenSeconds, "6 s after it could first be seen", 0.06)
		-- Pack: never a zone wider than a normal player can leave during its warning (16 studs per second walking).
		assert(T.ZoneRadiusStuds / T.ZoneTelegraphSeconds <= 16, "zone fairness")
		assert(T.MaxScreenBlurSize <= 4, "light blur only")
	end)

	case("BW2 Gaze: the module is pure and server-only", function()
		for _, banned in ipairs({ "workspace", "game:", "task.", "os.clock", "math.random", "Random.new", "Touched", "FireClient" }) do
			assert(not source:find(banned, 1, true), "source uses " .. banned)
		end
	end)

	return result
end

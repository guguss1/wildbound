-- Invoke with require(freshTestClone)(require(freshBeastEncountersClone), require(freshBeastGazeClone),
-- require(freshBeastConfigClone), freshBeastGazeClone.Source).
-- Beast revision BR5 (odd/tasks/wildbound-beast-revision.md): Gaze's accumulated-look defeat, pure. target.observe stands
-- in for the beast script's validated observation (WildboundBeastSight plus the server raycast line of sight); each
-- case says when the target looks (a wall is "observe returns false": the server raycast is part of observe).
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
		local w = { spots = 0 }
		function w.ground() return 0 end
		function w.reposition() w.spots += 1; return { x = 0, y = 0, z = -40 } end
		return w
	end
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
	local function count(events, kind)
		local n = 0
		for _, ev in ipairs(events) do if ev.type == kind then n += 1 end end
		return n
	end
	local function always(value) return function() return value end end
	local M = C.manifestSeconds

	case("BR5 Gaze: the threshold is 3 s (configurable) and the result is one 100-damage defeat", function()
		equal(C.killSeconds, 3); equal(C.killDamage, 100)
	end)

	case("BR5 Gaze: manifests first (nothing counts), then counts only while really observed, through the eyes", function()
		local w, tgt = fakeWorld(), target(always(true))
		local e = Enc.new("Gaze", "beast:1", 1, 0, { x = 0, y = 0, z = -40 })
		local events = run(e, w, tgt, 0, M)
		equal(#tgt.calls, 0, "not read while it manifests")
		equal(count(events, "Hit"), 0)
		run(e, w, tgt, M + 0.05, M + 1)
		local call = tgt.calls[1]
		equal(call.halfAngle, T.SightConeDegrees); equal(call.maxDist, T.MaxViewDistanceStuds)
		equal(call.favour, false, "lag never counts")
		near(call.point.y, C.eyeHeight, "the cone aims at the eyes")
		near(e.exposure, 1, "about 1 s", 0.06)
	end)

	case("BR5 Gaze: 3 s of continuous looking is exactly one instant defeat", function()
		local w, tgt = fakeWorld(), target(always(true))
		local e = Enc.new("Gaze", "beast:2", 1, 0, { x = 0, y = 0, z = -40 })
		local events = run(e, w, tgt, 0, M + 10)
		equal(count(events, "Hit"), 1, "once per encounter")
		local hit = find(events, "Hit")
		equal(hit.damage, C.killDamage); equal(hit.kill, true)
		near(hit.at, M + C.killSeconds, "at 3 s of looking", 0.06)
		equal(count(events, "Tell"), 0, "no zone, no gradual damage")
	end)

	case("BR5 Gaze: two separate looks add up; looking away pauses (never resets) the count", function()
		local w = fakeWorld()
		-- 2 s looking, 3 s away, then looking again: the defeat comes 1 s into the second look.
		local tgt = target(function(t) return (t >= M and t < M + 2) or t >= M + 5 end)
		local e = Enc.new("Gaze", "beast:3", 1, 0, { x = 0, y = 0, z = -40 })
		local events = run(e, w, tgt, 0, M + 4.9)
		near(e.exposure, 2, "held while away", 0.06)
		equal(count(events, "Hit"), 0)
		local paused = find(events, "Exposure", "paused", true)
		assert(paused and math.abs(paused.value - 2 / 3) < 0.05, "the meter shows a paused count")
		local later = run(e, w, tgt, M + 4.95, M + 8)
		local hit = find(later, "Hit")
		assert(hit, "the second look completes it")
		near(hit.at, M + 6, "2 s + 1 s", 0.06)
	end)

	case("BR5 Gaze: a wall (no line of sight, observe false) never counts", function()
		local w, tgt = fakeWorld(), target(always(false))
		local e = Enc.new("Gaze", "beast:4", 1, 0, { x = 0, y = 0, z = -40 })
		local events = run(e, w, tgt, 0, M + 20)
		near(e.exposure, 0, "nothing through the wall")
		equal(count(events, "Hit"), 0)
	end)

	case("BR5 Gaze: progressive feedback: the meter rises while looked at and says paused when not", function()
		local w = fakeWorld()
		local tgt = target(function(t) return t < M + 1.5 end)
		local e = Enc.new("Gaze", "beast:5", 1, 0, { x = 0, y = 0, z = -40 })
		local events = run(e, w, tgt, 0, M + 2.5)
		local last = -1
		for _, ev in ipairs(events) do
			if ev.type == "Exposure" and not ev.paused then
				assert(ev.value >= last - 1e-9, "never goes down"); last = ev.value
				assert(ev.value >= 0 and ev.value <= 1, "0 to 1")
			end
		end
		assert(last > 0.4, "it rose")
		assert(find(events, "Exposure", "paused", true), "paused once the look stopped")
		assert(find(events, "Phase", "phase", "ExposureBuild") and find(events, "SightBreak"), "posture and break cues")
	end)

	case("BR5 Gaze: spent after the defeat (normal mode keeps the target alive): no second strike, no exit", function()
		local w, tgt = fakeWorld(), target(always(true))
		local e = Enc.new("Gaze", "beast:6", 1, 0, { x = 0, y = 0, z = -40 })
		local events = run(e, w, tgt, 0, M + 60)
		equal(count(events, "Hit"), 1)
		equal(find(events, "Disengage"), nil); equal(find(events, "End"), nil)
	end)

	case("BR5 Gaze: a new encounter starts the count from zero; a safe zone ends it at once", function()
		local w, tgt = fakeWorld(), target(always(true))
		local e = Enc.new("Gaze", "beast:7", 1, 0, { x = 0, y = 0, z = -40 })
		run(e, w, tgt, 0, M + 2)
		tgt.safe = true
		equal(find(Enc.step(e, M + 2.05, tgt, w), "End").reason, "SafeZone")
		local e2 = Enc.new("Gaze", "beast:8", 1, 0, { x = 0, y = 0, z = -40 })
		equal(e2.exposure, 0, "fresh count")
	end)

	case("BR5 Gaze: unobserved and out of view range it reappears in range (persistent), at most every 3 s", function()
		local w, tgt = fakeWorld(), target(always(false))
		local e = Enc.new("Gaze", "beast:9", 1, 0, { x = 0, y = 0, z = -40 })
		run(e, w, tgt, 0, M + 0.1)
		tgt.z = 200
		local events = run(e, w, tgt, M + 0.15, M + 7, function(_, tg) tg.z = 200 end)
		local blinks = count(events, "Move")
		assert(blinks >= 1 and blinks <= 3, "repositioned, throttled: " .. blinks)
		equal(find(events, "Disengage"), nil, "never gives up")
	end)

	case("BR5 Gaze: the module is pure and server-only", function()
		for _, banned in ipairs({ "workspace", "game:", "task.", "os.clock", "math.random", "Random.new", "Touched", "FireClient" }) do
			assert(not source:find(banned, 1, true), "source uses " .. banned)
		end
	end)

	return result
end

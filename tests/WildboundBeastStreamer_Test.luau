-- Invoke with require(freshTestClone)(require(freshBeastEncountersClone), require(freshBeastStreamerClone),
-- require(freshBeastConfigClone), freshBeastStreamerClone.Source).
-- Wave 2 (odd/tasks/wildbound-beasts-wave2.md, BW2-5): Streamer's state machine, pure. A fake world (flat ground at
-- y 0, open lines unless a case closes them) and a fake dodge (world.resolve answers what the case sets) stand in for
-- the beast script; the target is a table moved by each case. No world is touched.
return function(Enc, Streamer, Config, source)
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
	Enc.register("Streamer", Streamer)
	local C = Config.BEASTS.Streamer
	local T = C.tuning

	local function fakeWorld()
		local w = { telegraphs = {}, resolved = {}, cancelled = {}, verdict = "Hit", los = true }
		function w.ground() return 0 end
		function w.lineOfSight() return w.los end
		function w.telegraph(id, beast, startAt, strikeAt)
			table.insert(w.telegraphs, { id = id, beast = beast, startAt = startAt, strikeAt = strikeAt })
			return strikeAt - startAt >= 0.8 - 1e-9
		end
		function w.resolve(id) table.insert(w.resolved, id); return w.verdict end
		function w.cancel(id) table.insert(w.cancelled, id) end
		return w
	end
	local function target(x, z) return { x = x, y = 3, z = z, vx = 0, vz = 0, alive = true, safe = false } end
	-- Steps from `from` to `to` at 20 Hz; move(t, tgt) may change the target. Returns every event.
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
	local function count(events, kind, field, value)
		local n = 0
		for _, ev in ipairs(events) do
			if ev.type == kind and (field == nil or ev[field] == value) then n += 1 end
		end
		return n
	end

	case("BW2 Streamer: walks in, warns at the aggro radius, then screams; no damage before the pulse", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = Enc.new("Streamer", "beast:1", 1, 0, { x = 0, y = 0, z = -40 })
		local events = run(e, w, tgt, 0, 6)
		local warn = find(events, "Phase", "phase", "Warn")
		assert(warn, "Warn")
		local dormant = find(events, "Phase", "phase", "Dormant")
		near(dormant.at, C.spawnSeconds, "dormant after the rise")
		-- It walked at WalkSpeed from 40 to the 17-stud radius: about 23 / 12 s after the rise.
		near(warn.at, C.spawnSeconds + (40 - T.AggroRadiusStuds) / T.WalkSpeedStudsPerSecond, "warn time", 0.1)
		local charge = find(events, "Phase", "phase", "ScreamCharge")
		near(charge.at - warn.at, T.WarningSeconds, "1.0 s of warning")
		local tell = find(events, "Tell", "dodgeable", false)
		assert(tell and tell.shape.kind == "circle", "the scream ring")
		equal(tell.shape.r, T.ScreamRadiusStuds)
		near(tell.strikeAt - tell.startAt, T.ScreamWindupSeconds)
		for _, ev in ipairs(events) do
			if ev.type == "Hit" then assert(ev.at >= tell.strikeAt - 1e-9, "a hit before the pulse") end
		end
		local strike = find(events, "Strike", "tell", tell.tell)
		assert(strike and strike.hit == false, "17 studs away: outside the 10-stud ring")
	end)

	case("BW2 Streamer: the scream hits once inside the ring, with a light push away from it", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = Enc.new("Streamer", "beast:2", 1, 0, { x = 0, y = 0, z = -40 })
		-- The target steps toward it once warned, so the pulse catches it at 8 studs.
		local events = run(e, w, tgt, 0, 6, function(_, t)
			if e.phase == "Warn" or e.phase == "ScreamCharge" then t.z = e.pos.z + 8 end
		end)
		local tell = find(events, "Tell", "dodgeable", false)
		local hits = 0
		for _, ev in ipairs(events) do
			if ev.type == "Hit" and ev.attack == tell.tell then
				hits += 1
				equal(ev.damage, T.ScreamDamage)
				assert(type(ev.knock) == "table", "a push")
				equal(ev.knock.speed, T.ScreamKnockbackStudsPerSecond)
				assert(ev.knock.dz > 0.9, "away from the beast")
			end
		end
		equal(hits, 1, "one hit per scream")
		for _, reg in ipairs(w.telegraphs) do
			assert(reg.id ~= tell.tell, "the scream is not a dodge registration (0.75 s is under the floor)")
		end
	end)

	local function toRush(w, tgt, id)
		local e = Enc.new("Streamer", id, 1, 0, { x = 0, y = 0, z = -20 })
		local events = run(e, w, tgt, 0, 3)
		assert(e.phase == "Pursue" or e.phase == "RushTelegraph", "pursuing after the scream: " .. e.phase)
		return e, events
	end

	case("BW2 Streamer: the rush lane follows until 0.25 s before the commit, then never moves; one hit", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = toRush(w, tgt, "beast:3")
		local lockSeen, dirAtLock
		local events = run(e, w, tgt, 3.05, 8, function(t, tg)
			if e.phase == "RushTelegraph" and e.rush and e.rush.locked and not lockSeen then
				lockSeen, dirAtLock = t, { e.dx, e.dz }
			end
			if e.phase == "RushCommit" then
				-- Too late to aim: the lane stays where it was locked.
				near(e.dx, dirAtLock[1], "dx held"); near(e.dz, dirAtLock[2], "dz held")
			end
		end)
		local rush = w.telegraphs[1]
		assert(rush and rush.beast == "Streamer", "the rush is registered with the dodge")
		assert(rush.strikeAt - rush.startAt >= T.RushTelegraphSeconds - 1e-9, "strike after the 0.9 s telegraph")
		local tell = find(events, "Tell", "tell", rush.id)
		near(tell.lockAt, tell.startAt + T.RushTelegraphSeconds - C.lockLead, "lock 0.25 s before the commit")
		equal(tell.shape.width, C.laneWidth)
		equal(count(events, "Hit", "attack", rush.id), 1, "one hit per rush")
		local hit = find(events, "Hit", "attack", rush.id)
		equal(hit.damage, T.RushDamage)
		assert(find(events, "Phase", "phase", "Recovery"), "recovery after the rush")
		assert(find(events, "Move", "kind", "dash"), "the dash move for the client")
	end)

	case("BW2 Streamer: stepping out of the locked lane is a miss and a 1.2 s recovery", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = toRush(w, tgt, "beast:4")
		local events = run(e, w, tgt, 3.05, 8, function(_, tg)
			if e.rush and e.rush.locked then tg.x = 12 end -- sideways, out of the 4.5-stud lane
		end)
		local rush = w.telegraphs[1]
		equal(count(events, "Hit", "attack", rush.id), 0)
		equal(w.cancelled[1], rush.id, "the dodge registration is cancelled")
		local recovery = find(events, "Phase", "phase", "Recovery")
		near(recovery.untilAt - recovery.at, T.RushMissRecoverySeconds)
	end)

	case("BW2 Streamer: a validated perfect dodge at contact: no damage and a 2.1 s stun", function()
		local w = fakeWorld()
		w.verdict = "Dodged"
		local tgt = target(0, 0)
		local e = toRush(w, tgt, "beast:5")
		local events = run(e, w, tgt, 3.05, 8)
		local rush = w.telegraphs[1]
		equal(count(events, "Hit", "attack", rush.id), 0, "no damage")
		local strike = find(events, "Strike", "tell", rush.id)
		equal(strike.dodged, true)
		local stun = find(events, "Phase", "phase", "Stunned")
		assert(stun, "stunned")
		near(stun.untilAt - stun.at, T.PerfectDodgeStunSeconds)
		equal(#w.resolved, 1, "asked once")
	end)

	case("BW2 Streamer: a safe zone or a death ends it at once; open attacks are left for closeAll", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = toRush(w, tgt, "beast:6")
		run(e, w, tgt, 3.05, 4.2)
		equal(e.phase, "RushTelegraph", "mid-telegraph")
		assert(next(e.open) ~= nil, "the rush is open")
		tgt.safe = true
		local events = Enc.step(e, 4.25, tgt, w)
		local ending = find(events, "End")
		equal(ending.reason, "SafeZone")
		equal(count(events, "Hit"), 0, "no hit on the way out")
		equal(#Enc.step(e, 4.3, target(0, 0), w), 0, "nothing after the end")
		local e2 = Enc.new("Streamer", "beast:7", 1, 0, { x = 0, y = 0, z = -20 })
		equal(find(Enc.step(e2, 0.05, nil, w), "End").reason, "Death", "no body: death")
	end)

	case("BW2 Streamer: timeout disengages, then ends", function()
		local w = fakeWorld()
		w.los = false -- never sees the target: stays dormant, walking
		local tgt = target(0, 0)
		local e = Enc.new("Streamer", "beast:8", 1, 0, { x = 0, y = 0, z = -60 })
		local events = run(e, w, tgt, 0, T.EncounterTimeoutSeconds + 2, function(_, tg) tg.z = e.pos.z + 30 end)
		local dis = find(events, "Disengage")
		equal(dis.reason, "Timeout")
		near(dis.at, T.EncounterTimeoutSeconds, "at the timeout", 0.06)
		assert(find(events, "End"), "ends after the retreat")
	end)

	case("BW2 Streamer: the module is pure and server-only", function()
		for _, banned in ipairs({ "workspace", "game:", "task.", "os.clock", "math.random", "Random.new", "Touched", "FireClient" }) do
			assert(not source:find(banned, 1, true), "source uses " .. banned)
		end
	end)

	return result
end

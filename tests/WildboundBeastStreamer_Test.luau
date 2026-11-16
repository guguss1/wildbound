-- Invoke with require(freshTestClone)(require(freshBeastEncountersClone), require(freshBeastStreamerClone),
-- require(freshBeastConfigClone), freshBeastStreamerClone.Source).
-- Beast revision BR3 (odd/tasks/wildbound-beast-revision.md): the Screamer (internal id Streamer), pure. A fake world
-- (flat ground at y 0, open lines unless a case closes them, nearSpot and safe answered by the case) and a fake dodge
-- stand in for the beast script; the target is a table moved by each case. No world is touched.
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

	local function fakeWorld()
		local w = { telegraphs = {}, resolved = {}, cancelled = {}, verdict = "Hit", los = true, spot = nil, safeX = math.huge }
		function w.ground() return 0 end
		function w.lineOfSight() return w.los end
		function w.nearSpot() return w.spot end
		function w.safe(x) return x >= w.safeX end
		function w.telegraph(id, beast, startAt, strikeAt)
			table.insert(w.telegraphs, { id = id, beast = beast, startAt = startAt, strikeAt = strikeAt })
			return strikeAt - startAt >= 0.8 - 1e-9
		end
		function w.resolve(id) table.insert(w.resolved, id); return w.verdict end
		function w.cancel(id) table.insert(w.cancelled, id) end
		return w
	end
	local function target(x, z) return { x = x, y = 3, z = z, vx = 0, vz = 0, alive = true, safe = false } end
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
	local function count(events, kind, field, value)
		local n = 0
		for _, ev in ipairs(events) do
			if ev.type == kind and (field == nil or ev[field] == value) then n += 1 end
		end
		return n
	end
	-- A Screamer woken at the origin: the target steps in at 10 studs, then the scream runs out.
	local function woken(w, tgt, id)
		local e = Enc.new("Streamer", id, 1, 0, { x = 0, y = 0, z = -10 })
		run(e, w, tgt, 0, C.screamSeconds + 0.1)
		equal(e.phase, "Pursue", "chasing after the scream")
		return e
	end

	case("BR3 Screamer: the display name is Screamer; the internal id stays Streamer", function()
		equal(C.displayName, "Screamer")
		assert(Config.PLAYABLE.Streamer and Config.WAVE2.Streamer, "the id still plugs in")
	end)

	case("BR3 Screamer: a statue until the activation distance: it never moves, tells or hits", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = Enc.new("Streamer", "beast:1", 1, 0, { x = 0, y = 0, z = -40 })
		local events = run(e, w, tgt, 0, 20)
		equal(e.phase, "Statue")
		near(e.pos.z, -40, "did not move"); near(e.pos.x, 0)
		equal(count(events, "Tell"), 0); equal(count(events, "Hit"), 0); equal(count(events, "Move"), 0)
		assert(C.activationDistance > 0, "configurable activation distance")
	end)

	case("BR3 Screamer: within the activation distance it screams (harmless), then chases", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = Enc.new("Streamer", "beast:2", 1, 0, { x = 0, y = 0, z = -40 })
		local events = run(e, w, tgt, 0, 8, function(t, tg)
			if t >= 2 then tg.z = -40 + C.activationDistance - 1 end
			if e.phase == "Scream" then tg.z = e.pos.z + 1 end -- right on top of it during the scream
		end)
		local scream = find(events, "Phase", "phase", "Scream")
		assert(scream, "it screams")
		near(scream.untilAt - scream.at, C.screamSeconds)
		local pursue = find(events, "Phase", "phase", "Pursue")
		near(pursue.at, scream.at + C.screamSeconds, "then chases")
		for _, ev in ipairs(events) do
			if ev.at < pursue.at then
				assert(ev.type ~= "Hit" and ev.type ~= "Tell", "the scream never hurts or tells: " .. ev.type)
			end
		end
	end)

	case("BR3 Screamer: the chase is very fast (chaseSpeed) and no rush exists", function()
		assert(C.chaseSpeed > 24, "faster than a trained runner")
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = woken(w, tgt, "beast:3")
		tgt.z = 30
		local z0 = e.pos.z
		run(e, w, tgt, 1.5, 2.0)
		near(e.pos.z - z0, C.chaseSpeed * 0.5, "26 studs a second", 0.6)
		local events = run(e, w, tgt, 2.05, 8)
		equal(find(events, "Move", "kind", "dash"), nil, "no rush")
	end)

	case("BR3 Screamer: reaching the target opens a dodgeable 0.8 s grab; standing still is one 28-damage hit", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = woken(w, tgt, "beast:4")
		local events = run(e, w, tgt, 1.5, 5)
		local tell = find(events, "Tell")
		assert(tell and tell.shape.kind == "circle", "the grab circle")
		equal(tell.shape.r, C.catchRadius)
		near(tell.strikeAt - tell.startAt, C.catchTell)
		assert(C.catchTell >= Config.MIN_TELL, "never under the 0.8 s floor")
		equal(w.telegraphs[1].beast, "Streamer", "registered with the dodge")
		equal(count(events, "Hit"), 1)
		equal(find(events, "Hit").damage, C.catchDamage)
		assert(find(events, "Phase", "phase", "Recovery"), "a recovery after the grab")
	end)

	case("BR3 Screamer: stepping out after the grab locks is a miss", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = woken(w, tgt, "beast:5")
		local events = run(e, w, tgt, 1.5, 5, function(_, tg)
			if e.catch and e.catch.lockedNow then tg.x = 9 end
		end)
		equal(count(events, "Hit"), 0)
		equal(w.cancelled[1], w.telegraphs[1].id, "the dodge registration is cancelled")
	end)

	case("BR3 Screamer: lost far away it teleports to a valid spot near the target, then waits the cooldown", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = woken(w, tgt, "beast:6")
		tgt.z = 200
		w.spot = { x = 0, y = 0, z = 200 - 18 }
		local events = run(e, w, tgt, 1.5, 1.6)
		local blink = find(events, "Move", "kind", "blink")
		assert(blink, "a teleport")
		near(blink.to.z, 182)
		near(e.pos.z, 182, "it moved there (then ran on a step or two)", 3)
		equal(count(events, "Hit"), 0, "a teleport never hits")
		assert(e.catchReadyAt >= blink.at + C.teleportGrabBlock - 1e-6, "the grab waits after a jump")
		-- Far again at once: no second jump before the cooldown.
		tgt.z = 600
		w.spot = { x = 0, y = 0, z = 600 - 18 }
		local later = run(e, w, tgt, 1.65, 1.5 + C.teleportCooldown - 0.2)
		equal(count(later, "Move", "kind", "blink"), 0, "cooldown")
	end)

	case("BR3 Screamer: no teleport into a safe zone, onto the target, under the map or with no spot; the chase goes on", function()
		for _, spec in ipairs({
			{ spot = { x = 0, y = 0, z = 182 }, safeX = -1, why = "Safe" },
			{ spot = { x = 0, y = 0, z = 198 }, why = "Near" },
			{ spot = { x = 0, y = 0 / 0, z = 182 }, why = "NoSpot" },
			{ spot = nil, why = "NoSpot" },
		}) do
			local w = fakeWorld()
			local tgt = target(0, 0)
			local e = woken(w, tgt, "beast:7" .. spec.why)
			tgt.z = 200
			w.spot, w.safeX = spec.spot, spec.safeX or math.huge
			local z0 = e.pos.z
			local events = run(e, w, tgt, 1.5, 3)
			equal(count(events, "Move", "kind", "blink"), 0, spec.why .. ": no jump")
			equal(find(events, "TeleportRefused").reason, spec.why)
			assert(e.pos.z > z0 + 10, spec.why .. ": it kept running")
			equal(e.phase, "Pursue")
		end
	end)

	case("BR3 Screamer: out of sight for 2 s it may reposition; never before it is chasing", function()
		local w = fakeWorld()
		w.los = false
		w.spot = { x = 0, y = 0, z = -40 }
		local tgt = target(0, 0)
		local e = Enc.new("Streamer", "beast:8", 1, 0, { x = 0, y = 0, z = -60 })
		local statue = run(e, w, tgt, 0, 5)
		equal(count(statue, "Move"), 0, "a statue never teleports")
		tgt.z = -60 + 10
		run(e, w, tgt, 5.05, 5.05 + C.screamSeconds + 0.1)
		tgt.z = -60 + 20
		w.spot = { x = 0, y = 0, z = tgt.z - 16 }
		local events = run(e, w, tgt, 6.6, 6.6 + C.teleportUnseenSeconds + 0.3, function(_, tg) tg.z = e.pos.z + 20; w.spot = { x = 0, y = 0, z = tg.z - 16 } end)
		assert(find(events, "Move", "kind", "blink"), "repositioned after 2 s unseen")
	end)

	case("BR3 Screamer: an unwoken statue ends quietly; a woken one never times out (persistent chase)", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = Enc.new("Streamer", "beast:9", 1, 0, { x = 0, y = 0, z = -60 })
		local events = run(e, w, tgt, 0, C.statueSeconds + 2)
		equal(find(events, "Disengage").reason, "Unwoken")
		assert(find(events, "End"), "it ends")
		local w2 = fakeWorld()
		local tgt2 = target(0, 0)
		local e2 = woken(w2, tgt2, "beast:10")
		local later = run(e2, w2, tgt2, 1.5, 100, function(_, tg) tg.z = e2.pos.z + 30 end)
		equal(find(later, "Disengage"), nil); equal(find(later, "End"), nil)
	end)

	case("BR3 Screamer: a safe zone or a death ends it at once; open attacks are left for closeAll", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = woken(w, tgt, "beast:11")
		run(e, w, tgt, 1.5, 1.7)
		equal(e.phase, "CatchTell", "mid-grab")
		tgt.safe = true
		local events = Enc.step(e, 1.75, tgt, w)
		equal(find(events, "End").reason, "SafeZone")
		equal(count(events, "Hit"), 0, "no hit on the way out")
		local e2 = Enc.new("Streamer", "beast:12", 1, 0, { x = 0, y = 0, z = -20 })
		equal(find(Enc.step(e2, 0.05, nil, w), "End").reason, "Death", "no body: death")
	end)

	case("BR3 Screamer: the module is pure and server-only", function()
		for _, banned in ipairs({ "workspace", "game:", "task.", "os.clock", "math.random", "Random.new", "Touched", "FireClient" }) do
			assert(not source:find(banned, 1, true), "source uses " .. banned)
		end
	end)

	return result
end

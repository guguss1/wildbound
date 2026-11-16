-- Invoke with require(freshTestClone)(require(freshBeastEncountersClone), require(freshBeastGomibuClone),
-- require(freshBeastConfigClone)).
-- Caramelo biome (odd/tasks/caramelo-bioma.md, T3; pack 03_PERSONAJES/01_GOMIBU.md): Gomibu's state machine, pure, on
-- the harness of WildboundBeastNube_Test: a fake world with flat ground at y 0 and a target moved by the test.
return function(Enc, Gomibu, Config)
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
	Enc.register("Gomibu", Gomibu)
	local C = Config.BEASTS.Gomibu
	local T = C and C.tuning
	local function fakeWorld()
		local w = { telegraphs = {}, cancelled = {} }
		function w.ground() return 0 end
		function w.site() return nil end
		function w.telegraph(id) table.insert(w.telegraphs, id); return true end
		function w.resolve() return "Hit" end
		function w.cancel(id) table.insert(w.cancelled, id) end
		return w
	end
	local function target(x, z, extra)
		local tgt = { x = x, y = 3, z = z, alive = true, safe = false }
		for k, v in pairs(extra or {}) do tgt[k] = v end
		return tgt
	end
	-- Steps the encounter every 0.05 s; move(t, tgt, e) may shift the target; watch(t, e) may record the beast.
	local function run(e, w, tgt, from, to, move, watch)
		local all = {}
		for i = 0, math.floor((to - from) / 0.05 + 1e-6) do
			local t = from + i * 0.05
			if move then move(t, tgt, e) end
			for _, ev in ipairs(Enc.step(e, t, tgt, w)) do table.insert(all, ev) end
			if watch then watch(t, e) end
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
	local function bear(id) return Enc.new("Gomibu", id, 1, 0, { x = 0, y = 0, z = 0 }) end
	-- A bear that has noticed a target standing at (8, 0), stepped until its first tell. Returns e, w, tgt, the events and the tell.
	local function telegraphing(id, move)
		local e, w, tgt = bear(id), fakeWorld(), target(8, 0)
		local events = run(e, w, tgt, 0, 1.2, move)
		local tell = each(events, "Tell")[1]
		assert(tell, "no tell after noticing a target in jump range (phases " .. phases(events) .. ")")
		return e, w, tgt, events, tell
	end

	case("config: a summoned guardian that never damages, keeps the egg, stays on the ground, with the sheet's numbers", function()
		assert(C, "no Gomibu entry in WildboundBeastConfig")
		equal(Config.SUMMONED.Gomibu, true); equal(C.category, "Guardian"); equal(C.biome, "Meadow")
		equal(Config.WAVE2.Gomibu, true, "without it the client ignores its phases and draws no tell")
		equal(T.PushStuds, 8, "push distance of the sheet")
		equal(C.damage, 0); equal(C.points, 0); equal(C.keepsEgg, true); equal(C.grounded, true)
		equal(Config.PLAYABLE.Gomibu, nil, "never rolled")
		for _, name in ipairs(Config.ORDER) do assert(name ~= "Gomibu", "not in ORDER") end
		assert(table.isfrozen(T), "tuning frozen")
		-- Deliberately changed (CF, user 2026-11-15): tell 0.9 -> 0.8 (the floor), lock 0.55 -> 0.45 (still 0.8 s from the
		-- lock to the landing), recover 0.7 -> 0.5, cooldown 5.5 -> 3.5.
		equal(T.TelegraphSeconds, 0.8); equal(T.LockSeconds, 0.45); equal(T.JumpSeconds, 0.45); equal(T.RadiusStuds, 4.5)
		equal(T.RecoverSeconds, 0.5); equal(T.AttackCooldownSeconds, 3.5); equal(T.SlowMultiplier, 0.8); equal(T.SlowSeconds, 1)
		equal(T.PerceptionStuds, 16); equal(T.AbandonStuds, 25); equal(T.PatrolSpeedStudsPerSecond, 7); equal(T.ChaseSpeedStudsPerSecond, 12)
		assert(Gomibu.tellSeconds(T) >= Config.MIN_TELL, "tell under the fairness floor")
		-- the two kids keep their own flags: nothing here leaks onto them
		equal(Config.BEASTS.NubeGrunona.keepsEgg, nil); equal(Config.BEASTS.AbejaReina.grounded, nil)
	end)

	case("it waits at its nest until the target is within 16 studs, alerts for 0.7 s, then chases", function()
		local e, w, tgt = bear("calm"), fakeWorld(), target(30, 0)
		equal(phases(run(e, w, tgt, 0, 1)), "Calm", "far target")
		equal(e.pos.x, 0, "moved while calm")
		tgt.x = 15.9
		local events = run(e, w, tgt, 1.05, 2.2)
		local list = each(events, "Phase")
		equal(list[1].phase, "Notice"); equal(list[2].phase, "Chase")
		near(list[2].at - list[1].at, T.AlertSeconds, "alert time", 1e-6)
	end)

	case("it chases at 12 studs per second and never goes past its leash, not even with a jump", function()
		local e, w, tgt = bear("chase"), fakeWorld(), target(15, 0)
		run(e, w, tgt, 0, 0.8)
		tgt.x = 24 -- still within the abandon distance, outside the jump range
		local x0
		run(e, w, tgt, 0.85, 1.35, nil, function(t, bearState) if not x0 then x0 = bearState.pos.x end end)
		near((e.pos.x - x0) / 0.5, T.ChaseSpeedStudsPerSecond, "chase speed", 0.6)
		local farthest = 0
		run(e, w, tgt, 1.4, 12, function(t, tg, bearState) tg.x = math.min(bearState.pos.x + 20, T.LeashStuds + 8) end,
			function(t, bearState) farthest = math.max(farthest, bearState.pos.x) end)
		assert(farthest <= T.LeashStuds + 1e-6, "went " .. farthest .. " studs from the nest")
		assert(farthest >= T.LeashStuds - 4, "never reached towards the leash: " .. farthest)
	end)

	case("Golpe de Goma: a 4.5 stud circle that follows the target until the lock and never again", function()
		-- the target starts walking as soon as the circle is drawn
		local e, w, tgt, events, tell = telegraphing("tell", function(t, tg, bearState) if bearState.phase == "Telegraph" then tg.x, tg.z = 8, 3 end end)
		equal(tell.shape.kind, "circle"); equal(tell.shape.r, T.RadiusStuds); equal(tell.shape.x, 8); equal(tell.shape.z, 0)
		near(tell.lockAt - tell.startAt, T.LockSeconds, "lock"); near(tell.strikeAt - tell.startAt, T.TelegraphSeconds + T.JumpSeconds, "landing")
		equal(tell.locked, false)
		local t0 = tell.startAt
		local later = run(e, w, tgt, 1.25, t0 + 1.2, function(t, tg)
			if t < t0 + T.LockSeconds - 0.01 then tg.x, tg.z = 8, 3 else tg.x, tg.z = 2, -6 end
		end)
		local followed, lock = false, nil
		for _, ev in ipairs(each(events, "Tell")) do
			if ev.locked ~= true and ev.shape.z == 3 then followed = true end
			-- CF: with the 0.45 s lock the locked tell can fall inside telegraphing's first 1.2 s.
			if ev.locked == true then lock = lock or ev end
		end
		for _, ev in ipairs(each(later, "Tell")) do
			if ev.locked ~= true and ev.shape.z == 3 then followed = true end
			if ev.locked == true then lock = lock or ev end
		end
		assert(followed, "the circle did not follow the target before the lock")
		assert(lock, "no locked tell")
		equal(lock.shape.x, 8, "locked x"); equal(lock.shape.z, 3, "the lock took a later position")
		near(lock.at, t0 + T.LockSeconds, "lock time", 0.051)
		for _, ev in ipairs(each(later, "Tell")) do
			if ev.at > lock.at then equal(ev.shape.z, 3, "the circle moved after the lock") end
		end
	end)

	case("the jump is one 0.45 s arc to the locked circle, and a target inside is slowed and pushed away, nothing else", function()
		local e, w, tgt, events, tell = telegraphing("hit")
		local takeOff, strikeAt = tell.startAt + T.TelegraphSeconds, tell.strikeAt
		local before, steps = nil, {}
		local later = run(e, w, tgt, 1.25, strikeAt + 0.1, function(t, tg) if t > tell.lockAt then tg.x = 10 end end, function(t, bearState)
			if before and t > takeOff and t <= strikeAt + 1e-6 then table.insert(steps, bearState.pos.x - before) end
			before = bearState.pos.x
		end)
		assert(string.find(phases(later), "Jump,Recover", 1, true), "phases " .. phases(later))
		near(e.pos.x, 8, "lands on the circle"); near(e.pos.z, 0, "lands on the circle z")
		assert(#steps >= 8, "the jump took " .. #steps .. " steps")
		for _, step in ipairs(steps) do
			assert(step >= -1e-9, "the jump went backwards")
			assert(step <= 8 / T.JumpSeconds * 0.05 * 1.6, "a step of " .. step .. " studs is a teleport")
		end
		local hits = each(later, "Hit")
		equal(#hits, 1, "hits")
		local hit = hits[1]
		near(hit.at, strikeAt, "hit time"); equal(hit.damage, 0, "damage")
		equal(hit.slow.multiplier, T.SlowMultiplier); equal(hit.slow.seconds, T.SlowSeconds)
		-- the push is the server's (a knock on the client moved a standing player half a stud in Play)
		equal(hit.knock, nil, "client-side knock")
		near(hit.push.dx, 1, "push away from the centre"); near(hit.push.dz, 0)
		equal(hit.push.studs, 8, "push distance"); equal(hit.push.seconds, T.PushSeconds, "push time")
		assert(T.PushSeconds > 0 and T.PushSeconds <= 0.5, "the push is not a quick shove")
		equal(hit.mark, nil, "no mark"); equal(hit.sticky, nil, "not sticky")
	end)

	case("stepping out of the locked circle is a miss", function()
		local e, w, tgt, events, tell = telegraphing("miss")
		local later = run(e, w, tgt, 1.25, tell.strikeAt + 0.1, function(t, tg) if t > tell.lockAt then tg.x, tg.z = 8, 4.6 end end)
		equal(#each(later, "Hit"), 0, "hit outside the circle")
		assert(string.find(phases(later), "Recover", 1, true), "no recovery after the miss")
	end)

	case("a target in a safe zone is never hit", function()
		local e, w, tgt, events, tell = telegraphing("safe")
		local later = run(e, w, tgt, 1.25, tell.strikeAt + 0.2, function(t, tg) if t > tell.lockAt then tg.safe = true end end)
		equal(#each(later, "Hit"), 0, "hit in a safe zone")
	end)

	case("it cannot chain jumps: after landing it recovers and waits its cooldown", function()
		local e, w, tgt, events, tell = telegraphing("cooldown")
		local later = run(e, w, tgt, 1.25, tell.strikeAt + 9)
		local second
		for _, ev in ipairs(each(later, "Tell")) do if ev.tell ~= tell.tell then second = second or ev end end
		assert(second, "it never attacked again")
		assert(second.startAt >= tell.strikeAt + T.RecoverSeconds + T.AttackCooldownSeconds - 1e-6,
			"second jump " .. (second.startAt - tell.strikeAt) .. " s after the first landed")
		assert(second.startAt <= tell.strikeAt + T.RecoverSeconds + T.AttackCooldownSeconds + 0.11, "it waited too long")
	end)

	case("it gives up when the target is 25 studs away", function()
		local e, w, tgt = bear("giveup"), fakeWorld(), target(15, 0)
		run(e, w, tgt, 0, 0.9)
		tgt.x = e.pos.x + T.AbandonStuds + 1
		local later = run(e, w, tgt, 0.95, 1.5)
		assert(string.find(phases(later), "GiveUp", 1, true), "phases " .. phases(later))
		equal(#each(later, "Tell"), 0, "it attacked while giving up")
	end)

	return result
end

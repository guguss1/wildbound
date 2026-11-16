-- Invoke with require(freshTestClone)(require(freshBeastEncountersClone), require(freshBeastFlanfuriaClone),
-- require(freshBeastConfigClone), require(freshCandyFlanfuriaAttackClone)). The beast module reads its DataModel, so
-- its clone must sit in ServerScriptService while it is required.
-- Caramelo biome (odd/tasks/caramelo-bioma.md, T4; pack 03_PERSONAJES/02_FLANFURIA.md): Flanfuria's state machine,
-- pure, on the harness of WildboundBeastGomibu_Test: a fake world with flat ground at y 0 and a target moved by the test.
return function(Enc, Flanfuria, Config, Onda)
	-- Deliberately changed (CF, user 2026-11-15): the cast times come from the rule (Onda) instead of literals, since
	-- the tell, the recovery and the cooldown were shortened. The rule's own suite pins the numbers.
	local TELL = Onda.TELEGRAPH_SECONDS
	local PUDDLE_AT = TELL + Onda.RELEASE_SECONDS
	local ENDS = PUDDLE_AT + Onda.RECOVER_SECONDS
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
	Enc.register("Flanfuria", Flanfuria)
	local C = Config.BEASTS.Flanfuria
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
	local function flan(id) return Enc.new("Flanfuria", id, 1, 0, { x = 0, y = 0, z = 0 }) end
	-- A flan that has noticed a target standing at (6, 0), stepped until its first tell. Returns e, w, tgt, the events
	-- and the tell. The flan has not moved: 6 studs is inside its cast range.
	local function telegraphing(id)
		local e, w, tgt = flan(id), fakeWorld(), target(6, 0)
		local events = run(e, w, tgt, 0, 1.2)
		local tell = each(events, "Tell")[1]
		assert(tell, "no tell after noticing a target in cast range (phases " .. phases(events) .. ")")
		return e, w, tgt, events, tell
	end
	local function ringSlows(events)
		local list = {}
		for _, ev in ipairs(each(events, "Afflict")) do if ev.puddle ~= true then table.insert(list, ev) end end
		return list
	end
	local function puddleSlows(events)
		local list = {}
		for _, ev in ipairs(each(events, "Afflict")) do if ev.puddle == true then table.insert(list, ev) end end
		return list
	end

	case("config: a summoned guardian that never damages, keeps the egg, stays on the ground, with the sheet's numbers", function()
		assert(C, "no Flanfuria entry in WildboundBeastConfig")
		equal(Config.SUMMONED.Flanfuria, true); equal(C.category, "Guardian"); equal(C.biome, "Meadow")
		equal(Config.WAVE2.Flanfuria, true, "without it the client ignores its phases and draws no tell")
		-- Deliberately changed (OF2, owner feedback 2): its ring hurts (15, through BeastHit with the egg kept) and it
		-- chases faster than a walking player (11 -> 17).
		equal(C.damage, 15); equal(C.points, 0); equal(C.keepsEgg, true); equal(C.grounded, true)
		equal(Config.PLAYABLE.Flanfuria, nil, "never rolled")
		for _, name in ipairs(Config.ORDER) do assert(name ~= "Flanfuria", "not in ORDER") end
		assert(table.isfrozen(T), "tuning frozen")
		equal(T.PerceptionStuds, 20); equal(T.PatrolSpeedStudsPerSecond, 6); equal(T.ChaseSpeedStudsPerSecond, 17)
		assert(T.CastRangeStuds < Onda.RING_TO_STUDS, "it casts at a target the ring cannot reach")
		equal(T.PuddleSlowSeconds, nil, "the attack's numbers live in WildboundCandyFlanfuriaAttack only"); equal(T.PuddleRepeatSeconds, nil)
		assert(Flanfuria.tellSeconds() >= Config.MIN_TELL, "tell under the fairness floor")
		-- the others keep their own entries: nothing here leaks onto them
		equal(Config.SUMMONED.Gomibu, true); equal(Config.WAVE2.Gomibu, true); equal(Config.SUMMONED.NubeGrunona, true)
		equal(Config.BEASTS.NubeGrunona.keepsEgg, nil); equal(Config.BEASTS.AbejaReina.grounded, nil)
	end)

	case("it waits at its nest until the target is within 20 studs, alerts for 0.8 s, then hops after it at 11 studs/s", function()
		local e, w, tgt = flan("calm"), fakeWorld(), target(34, 0)
		equal(phases(run(e, w, tgt, 0, 1)), "Calm", "far target")
		equal(e.pos.x, 0, "moved while calm")
		tgt.x = 19.9
		local events = run(e, w, tgt, 1.05, 2.4)
		local list = each(events, "Phase")
		equal(list[1].phase, "Notice"); equal(list[2].phase, "Chase")
		near(list[2].at - list[1].at, T.AlertSeconds, "alert time", 1e-6)
		tgt.x = e.pos.x + 25
		local x0 = e.pos.x
		-- OF2: 17 studs/s now, so the speed is read over 5 steps (0.25 s) before its 16-stud leash stops it
		run(e, w, tgt, 2.45, 2.65)
		near((e.pos.x - x0) / 0.25, T.ChaseSpeedStudsPerSecond, "chase speed", 1.2)
		local farthest = 0
		run(e, w, tgt, 3, 12, function(t, tg, state) tg.x = math.min(state.pos.x + 20, T.LeashStuds + 8) end,
			function(t, state) farthest = math.max(farthest, state.pos.x) end)
		assert(farthest <= T.LeashStuds + 1e-6, "went " .. farthest .. " studs from the nest")
	end)

	case("Onda de Caramelo: a fixed circle of radius 11 on the flan, a tell of Onda.TELEGRAPH_SECONDS, and the flan stands still through it", function()
		local e, w, tgt, events, tell = telegraphing("tell")
		equal(tell.shape.kind, "circle"); equal(tell.shape.r, 11); equal(tell.shape.x, 0); equal(tell.shape.z, 0)
		near(tell.strikeAt - tell.startAt, TELL, "the wave leaves when the tell ends")
		equal(tell.dodgeable, false)
		local locked = false
		for _, ev in ipairs(each(events, "Tell")) do if ev.locked == true then locked = true end end
		assert(locked, "the circle is not locked from the start")
		local later = run(e, w, tgt, 1.25, tell.startAt + 2.7, function(t, tg) tg.x, tg.z = 9, 5 end, function(t, state)
			if t < tell.startAt + ENDS - 0.05 then equal(state.pos.x, 0, "it moved during the cast at " .. t); equal(state.pos.z, 0) end
		end)
		for _, ev in ipairs(each(later, "Tell")) do equal(ev.shape.x, 0, "the circle followed the target") end
		local list = each(later, "Phase")
		equal(list[1].phase, "Release"); equal(list[2].phase, "Recover"); equal(list[3].phase, "Chase")
		near(list[1].at, tell.startAt + TELL, "release"); near(list[2].at, tell.startAt + PUDDLE_AT, "recover"); near(list[3].at, tell.startAt + ENDS, "chase again")
	end)

	case("the ring slows once, when its front reaches the target, with its damage on the slow, never a Hit", function()
		local e, w, tgt, events, tell = telegraphing("ring")
		local later = run(e, w, tgt, 1.25, tell.startAt + 2.7)
		local slows = ringSlows(later)
		equal(#slows, 1, "ring slows")
		-- the front is at 6 studs 0.356 s into the release, not at its start and not at its end
		near(slows[1].at, tell.startAt + TELL + Onda.RELEASE_SECONDS * 4 / 9, "the front reaches 6 studs", 0.051)
		-- OF2: the ring's slow carries the damage; the beast script sends it to BeastHit with the egg kept
		equal(slows[1].slow, 0.65); equal(slows[1].slowSeconds, 1.5); equal(slows[1].damage, C.damage)
		equal(#each(later, "Hit"), 0, "a Hit event would reach BeastHit: damage and the egg drop")
		local strikes = each(later, "Strike")
		equal(#strikes, 1, "strikes"); equal(strikes[1].hit, true)
	end)

	case("jumping the front, standing past radius 11 or standing in a safe zone is a miss", function()
		local e, w, tgt, events, tell = telegraphing("jump")
		local later = run(e, w, tgt, 1.25, tell.startAt + 2, function(t, tg)
			tg.y = (t >= tell.startAt + TELL + 0.25 and t <= tell.startAt + TELL + 0.5) and 9 or 3
		end)
		equal(#ringSlows(later), 0, "slowed in the air")
		local strikes = each(later, "Strike")
		equal(#strikes, 1, "strikes"); equal(strikes[1].hit, false)
		near(strikes[1].at, tell.startAt + PUDDLE_AT, "the miss is settled when the ring ends")
		local e2, w2, tgt2, _, tell2 = telegraphing("away")
		local away = run(e2, w2, tgt2, 1.25, tell2.startAt + 2, function(t, tg) tg.x = 11.6 end)
		equal(#ringSlows(away), 0, "slowed past the ring's reach")
		local e3, w3, tgt3, _, tell3 = telegraphing("safe")
		local safe = run(e3, w3, tgt3, 1.25, tell3.startAt + 2.2, function(t, tg) if t > tell3.startAt + 0.5 then tg.safe = true end end)
		equal(#each(safe, "Afflict"), 0, "slowed in a safe zone")
		equal(#each(safe, "Hit"), 0)
	end)

	case("the puddle: radius 4 where the flan stood, 3 s from the end of the release, x0.8 in short repeats, only while stood on", function()
		local e, w, tgt, events, tell = telegraphing("puddle")
		local puddleAt = tell.startAt + PUDDLE_AT
		-- out of reach until the ring is over (stepping in as it ends would be crossing its front), then into the puddle,
		-- then out of it again
		local later = run(e, w, tgt, 1.25, puddleAt + 4, function(t, tg)
			if t < puddleAt + 0.04 then tg.x = 11.6 elseif t < puddleAt + 1.5 then tg.x, tg.z = 0, 3 else tg.x, tg.z = 0, 4.3 end
		end)
		local slows = puddleSlows(later)
		assert(#slows >= 2, "the puddle slowed " .. #slows .. " times in 1.5 s")
		for i, ev in ipairs(slows) do
			equal(ev.slow, 0.8); equal(ev.slowSeconds, Onda.PUDDLE_PULSE_SECONDS); equal(ev.shake, nil, "the puddle shakes the screen")
			assert(ev.at >= puddleAt - 1e-6 and ev.at < puddleAt + 1.5, "puddle slow at " .. (ev.at - puddleAt) .. " s: outside the time stood on it")
			if i > 1 then assert(ev.at - slows[i - 1].at >= Onda.PUDDLE_REPEAT_SECONDS - 1e-6, "two puddle slows " .. (ev.at - slows[i - 1].at) .. " s apart") end
		end
		equal(#ringSlows(later), 0); equal(#each(later, "Hit"), 0)
		-- a dry puddle slows nobody
		local e2, w2, tgt2, _, tell2 = telegraphing("dry")
		local dry = run(e2, w2, tgt2, 1.25, tell2.startAt + 7, function(t, tg, state)
			if t < tell2.startAt + PUDDLE_AT + Onda.PUDDLE_SECONDS + 0.05 then tg.x = 11.6 else tg.x, tg.z = 0, 3 end
		end)
		for _, ev in ipairs(puddleSlows(dry)) do assert(ev.at < tell2.startAt + PUDDLE_AT + Onda.PUDDLE_SECONDS, "the puddle outlived its 3 s") end
		equal(#puddleSlows(dry), 0, "slowed by a dry puddle")
	end)

	case("the ring slows a target walking into it", function()
		local e, w, tgt, events, tell = telegraphing("inward")
		local rel = tell.startAt + TELL
		local later = run(e, w, tgt, 1.25, tell.startAt + 2, function(t, tg)
			tg.x = t < rel and 6.5 or math.max(6.5 - (t - rel) * 16, 0)
		end)
		equal(#ringSlows(later), 1, "ring slows")
	end)

	case("no slow of its own lands on another: the first puddle pulse waits until the ring slow has ended, and a gap more", function()
		local e, w, tgt, events, tell = telegraphing("overlap")
		-- 3 studs from the flan: caught by the ring early in the release, and standing on the puddle afterwards
		local later = run(e, w, tgt, 1.25, tell.startAt + 5, function(t, tg) tg.x, tg.z = 0, 3 end)
		local ring, puddle = ringSlows(later), puddleSlows(later)
		equal(#ring, 1, "ring slows")
		assert(#puddle >= 1, "the puddle never slowed a target standing on it")
		local free = ring[1].at + ring[1].slowSeconds
		assert(puddle[1].at >= free + Onda.SLOW_GAP_SECONDS - 1e-6, "a puddle pulse " .. (puddle[1].at - free) .. " s after the ring slow ended")
		for i = 2, #puddle do
			assert(puddle[i].at >= puddle[i - 1].at + puddle[i - 1].slowSeconds + Onda.SLOW_GAP_SECONDS - 1e-6, "two puddle pulses too close")
		end
	end)

	case("it cannot chain waves: Onda.COOLDOWN_SECONDS after the cast ends, so one puddle at most", function()
		local e, w, tgt, events, tell = telegraphing("cooldown")
		local later = run(e, w, tgt, 1.25, tell.startAt + 13, function(t, tg, state) tg.x, tg.z = state.pos.x + 5, state.pos.z end)
		local second
		for _, ev in ipairs(each(later, "Tell")) do if ev.tell ~= tell.tell then second = second or ev end end
		assert(second, "it never attacked again")
		assert(second.startAt >= tell.startAt + ENDS + Onda.COOLDOWN_SECONDS - 1e-6, "second wave " .. (second.startAt - tell.startAt) .. " s after the first began")
		assert(second.startAt <= tell.startAt + ENDS + Onda.COOLDOWN_SECONDS + 0.11, "it waited too long")
		assert(second.startAt > tell.startAt + PUDDLE_AT + Onda.PUDDLE_SECONDS, "the first puddle was still there")
	end)

	case("leaving combat removes the puddle: giving up, death and the safe zone end every slow", function()
		local e, w, tgt, events, tell = telegraphing("giveup")
		local puddleAt = tell.startAt + PUDDLE_AT
		-- the target leaves past the abandon distance as the cast recovers, then is put back on the puddle
		local later = run(e, w, tgt, 1.25, puddleAt + 2.9, function(t, tg)
			if t < puddleAt then tg.x = 11.6 elseif t < puddleAt + 1.2 then tg.x = T.AbandonStuds + 2 else tg.x, tg.z = 0, 2 end
		end)
		assert(string.find(phases(later), "GiveUp", 1, true), "phases " .. phases(later))
		equal(#puddleSlows(later), 0, "the puddle outlived the fight")
		local e2, w2, tgt2, _, tell2 = telegraphing("death")
		local dead = run(e2, w2, tgt2, 1.25, tell2.startAt + 4, function(t, tg)
			if t >= tell2.startAt + PUDDLE_AT + 0.05 then tg.alive = false; tg.x, tg.z = 0, 2 else tg.x = 11.6 end
		end)
		equal(#each(dead, "Afflict"), 0, "slowed after death")
		assert(#each(dead, "End") == 1, "the encounter did not end on death")
	end)

	return result
end

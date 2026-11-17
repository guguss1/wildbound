-- Invoke with require(freshTestClone)(require(freshCandySmartsClone), require(freshBeastEncountersClone),
-- require(freshBeastConfigClone), require(freshBeastCandyCritterClone), require(freshBeastGomibuClone),
-- require(freshBeastFlanfuriaClone), require(freshBeastTortidragonClone), require(freshBeastDonGlaseonClone),
-- require(freshCandyFrutillonClone), require(freshCandyDuquesaClone), require(freshCandyLayoutClone),
-- require(freshWorldRulesClone)).
-- Owner feedback 3 (odd/tasks/wildbound-caramelo-playfix.md, OF3): faster and smarter candy creatures (a sprint burst,
-- predictive aim, flanking, anti-stuck, a pause on the player's dodge, nest guarding and a call to allies) and a hard
-- but possible Gran Torta summit (Frutillon quicker, seeds and patrols that knock a climber off a tier, glaze steps, La
-- Duquesa throwing at the upper tiers). Pure, on the fake worlds of the brains' own suites.
-- RC (owner request 2026-11-16, "all the creatures keep chasing you, and fast, until you reach the base"): RC1-RC4 and
-- the RC7 runner model below.
-- V4-D9 / V4-D13 (owner 2026-11-17): the calm chaser cap ramps 1 -> 3 (one per 20 s), a steal's 60 s frenzy allows 5 and
-- calls the creatures within 150 studs; V4-D12: no creature step ends inside a house.
return function(Smarts, Enc, Config, Critter, Gomibu, Flanfuria, Tortidragon, Boss, Frut, Duq, Layout, Rules)
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
	local function within(value, lo, hi, label)
		assert(type(value) == "number" and value >= lo - 1e-9 and value <= hi + 1e-9,
			(label or "value") .. " " .. tostring(value) .. " outside " .. lo .. ".." .. hi)
	end
	local MIN_TELL = Config.MIN_TELL
	local CRITTERS = { "Mochimiau", "Canelin", "Flanin", "Mielita", "GatoRepartidor" }
	for _, name in ipairs(CRITTERS) do Enc.register(name, Critter) end
	Enc.register("Gomibu", Gomibu); Enc.register("Flanfuria", Flanfuria); Enc.register("Tortidragon", Tortidragon)
	Enc.register("DonGlaseon", Boss)

	local function fakeWorld(extra)
		local w = {}
		function w.ground() return 0 end
		function w.site() return nil end
		function w.telegraph() return true end
		function w.resolve() return "Hit" end
		function w.cancel() end
		for k, v in pairs(extra or {}) do w[k] = v end
		return w
	end
	-- A wall along x = wx (or z = wz) between -half and half on the other axis, cut by castLane like a trunk.
	local function wallX(wx, half)
		return function(ox, _, oz, dx, dz, length)
			if math.abs(dx) < 1e-6 then return nil end
			local t = (wx - ox) / dx
			if t < 0 or t > length then return nil end
			local z = oz + dz * t
			if math.abs(z) <= half then return t end
			return nil
		end
	end
	local function target(x, z, extra)
		local tgt = { x = x, y = 3, z = z, vx = 0, vz = 0, alive = true, safe = false }
		for k, v in pairs(extra or {}) do tgt[k] = v end
		return tgt
	end
	local function spawn(name, id, x, z) return Enc.new(name, name .. ":" .. id, 1, 0, { x = x or 0, y = 0, z = z or 0 }) end
	local function run(list, w, tgt, from, to, watch)
		local all = {}
		for i = 0, math.floor((to - from) / 0.05 + 1e-6) do
			local t = from + i * 0.05
			for _, e in ipairs(list) do
				if not e.done then
					for _, ev in ipairs(Enc.step(e, t, tgt, w)) do table.insert(all, ev) end
				end
			end
			if watch then watch(t) end
		end
		return all
	end
	local function each(events, kind, id)
		local out = {}
		for _, ev in ipairs(events) do if ev.type == kind and (not id or ev.id == id) then table.insert(out, ev) end end
		return out
	end
	local function phaseAt(events, id, phase)
		for _, ev in ipairs(events) do if ev.type == "Phase" and ev.id == id and ev.phase == phase then return ev.at end end
		return nil
	end

	-- Deliberately changed (CH2, owner request 2026-11-16 "make them go faster"): base chase 19-22 -> 21-23 (always under
	-- an untrained sprint's 23.2), sprint 24-27 -> 28-30 (same durations); Don Glaseon keeps his.
	case("OF3-1/CH2: base chase 21-23, a sprint of 28-30 for 1.5-2.5 s, never a one-shot, tells never under MIN_TELL", function()
		for _, name in ipairs({ "Mochimiau", "Canelin", "Flanin", "Mielita", "GatoRepartidor", "Gomibu", "Flanfuria", "Tortidragon" }) do
			local C = Config.BEASTS[name]
			within(C.tuning.ChaseSpeedStudsPerSecond, 21, 23, name .. " chase")
			local P = Smarts.profile(name)
			within(P.sprint, 28, 30, name .. " sprint"); within(P.sprintSeconds, 1.5, 2.5, name .. " sprint seconds")
			assert(C.damage < 34, name .. " could one-shot")
			if C.tuning.Attack then assert(Critter.tellSeconds(C.tuning.Attack) >= MIN_TELL, name .. " tell") end
		end
		equal(Config.BEASTS.DonGlaseon.tuning.ChaseSpeedStudsPerSecond, 21, "the boss keeps his Chase_Run stride")
		within(Smarts.profile("DonGlaseon").sprint, 24, 27, "boss sprint")
	end)

	case("OF3-1: a creature sprints after noticing, then cruises at its base speed", function()
		local e, w, tgt = spawn("Mochimiau", "sprint"), fakeWorld(), target(30, 0)
		local events = run({ e }, w, tgt, 0, 0.6)
		local chaseAt = phaseAt(events, e.id, "Chase")
		assert(chaseAt, "no chase")
		local x0 = e.pos.x
		run({ e }, w, tgt, 0.65, 1.1)
		-- Deliberately changed (CH2): Mochimiau's sprint 26 -> 30
		within(e.pos.x - x0, 30 * 0.5 - 1.5, 30 * 0.5 + 0.1, "studs in the first half second")
		equal(Smarts.speed(e, chaseAt + 3, 21), 21, "after the burst")
	end)

	-- CH2 (owner request 2026-11-16: faster creatures, "it must still be possible to escape by running or by dodging"). The
	-- escape, proved on the live numbers for every candy creature: an untrained player sprints 16 x 1.45 = 23.2 studs/s.
	--   1. after its burst every creature is slower than that sprint, so a running player never loses ground again;
	--   2. the burst's gain over the sprint ((sprint - 23.2) x sprintSeconds) never closes a sprinter it noticed at the
	--      edge of its sight into its attack range (the alert time, which helps the player, is left out);
	--   3. (RC1, was: the leash bounds the chase and a sprinter is safe within 8 s) it hunts until the base;
	--   4. a dodge close by stops it for dodgePause, in which a sprinter gains more than a body length.
	-- Against a trained walker (walk W, sprint 1.45 W) the chase (0.92 W, cap 36) stays under the sprint and the burst
	-- (1.1 W, cap 40) gains no more than against an untrained one.
	case("CH2: escape math, by running and by dodging, for every candy creature and a trained walker", function()
		local SPRINT = 16 * 1.45
		local REACH = { Gomibu = "JumpRangeStuds", Flanfuria = "CastRangeStuds", Tortidragon = "CastRangeStuds" }
		for _, name in ipairs({ "Mochimiau", "Canelin", "Flanin", "Mielita", "GatoRepartidor", "Gomibu", "Flanfuria", "Tortidragon" }) do
			local T, P = Config.BEASTS[name].tuning, Smarts.profile(name)
			local base = T.ChaseSpeedStudsPerSecond
			-- 1
			assert(base < SPRINT, name .. " chases at " .. base .. ", not under a sprint")
			local e = { beast = name, id = "esc" .. name, pos = { x = 0, y = 0, z = 0 } }
			local burst = Smarts.speed(e, 0, base, target(0, 0, { walk = 16 }))
			equal(burst, P.sprint, name .. " burst against an untrained walker")
			assert(Smarts.speed(e, P.sprintSeconds + 0.01, base, target(0, 0, { walk = 16 })) < SPRINT, name .. " after the burst")
			-- 2
			local range = T.Attack and T.Attack.RangeStuds or T[REACH[name]]
			assert(type(range) == "number", name .. " has no attack range")
			local gain = math.max(0, P.sprint - SPRINT) * P.sprintSeconds
			assert(gain < 15, name .. " gains " .. gain .. " studs in its burst")
			assert(T.PerceptionStuds - gain > range, name .. ": the burst closes a noticed sprinter into reach ("
				.. T.PerceptionStuds .. " - " .. gain .. " <= " .. range .. ")")
			-- 3. Deliberately changed (RC1, owner request 2026-11-16 "they keep chasing you until you reach the base"): the
			-- leash no longer bounds the chase ("the chase ends within 8 s" is gone); a hunt ends only at a safe zone, death,
			-- a leave or the hard limit, and the escape is reaching the base (RC7 holds that math).
			equal(P.relentless, true, name .. " is relentless")
			assert(base < SPRINT, name .. ": a sprinter still gains on it while its stamina lasts")
			-- 4
			assert(P.dodgePause * SPRINT >= 8, name .. ": a dodge buys only " .. P.dodgePause * SPRINT .. " studs")
			-- a trained walker
			for _, walk in ipairs({ 16, 20, 24, 28, 34, 40, 50 }) do
				local t = { beast = name, id = "esc" .. name .. walk, pos = { x = 0, y = 0, z = 0 } }
				local sprinted = Smarts.speed(t, 0, base, target(0, 0, { walk = walk }))
				local chased = Smarts.speed(t, P.sprintSeconds + 0.01, base, target(0, 0, { walk = walk }))
				assert(chased < 1.45 * walk, name .. " outruns a sprinter with walk " .. walk)
				assert(math.max(0, sprinted - 1.45 * walk) * P.sprintSeconds <= gain + 1e-9, name .. " gains more on walk " .. walk)
			end
		end
		equal(Smarts.CHASE_CAP, 36, "trained chase cap (CH2: 34 -> 36)"); equal(Smarts.SPRINT_CAP, 40, "trained sprint cap (CH2: 38 -> 40)")
	end)

	case("OF3-2a: predictive aim, the lead point and a leap aimed ahead of a moving target", function()
		local e = { beast = "Mochimiau", pos = { x = 0, y = 0, z = 0 } }
		local x, z = Smarts.lead(e, target(10, 0, { vx = 0, vz = 10 }), 1)
		equal(x, 10, "lead x"); within(z, 4.4, 4.6, "lead z")
		x, z = Smarts.lead(e, target(10, 0, { vx = 0, vz = 80 }), 1)
		within(z, 6.9, 7.1, "the lead is capped")
		local m, w = spawn("Mochimiau", "aim"), fakeWorld()
		local tgt = target(6, 0, { vz = 12 })
		local tell = each(run({ m }, w, tgt, 0, 1.5), "Tell")[1]
		assert(tell, "no tell")
		assert(tell.shape.z > 1, "the circle is not ahead of the runner: z " .. tostring(tell.shape.z))
		local g, gw = spawn("Gomibu", "aim"), fakeWorld()
		local gtell = each(run({ g }, gw, target(8, 0, { vz = 12 }), 0, 1.5), "Tell")[1]
		assert(gtell and gtell.shape.z > 1, "Gomibu's jump circle is not ahead of the runner")
	end)

	case("OF3-2a: the guardians run for or face the lead point", function()
		local f, fw = spawn("Flanfuria", "lead"), fakeWorld()
		run({ f }, fw, target(15, 0, { vz = 15 }), 0, 1.1)
		assert(f.pos.z > 0.2, "Flanfuria did not cut ahead: z " .. f.pos.z)
		local t, tw = spawn("Tortidragon", "lead"), fakeWorld()
		run({ t }, tw, target(18, 0, { vz = 15 }), 0, 1.0)
		assert(t.dz > 0.1, "Tortidragon does not face ahead of the runner: dz " .. tostring(t.dz))
		local b, bw = Enc.new("DonGlaseon", "lead", 1, 0, { x = 0, y = 0, z = 0 }), fakeWorld()
		local tgt = target(0, 25, { vx = 15 })
		local ahead = false
		run({ b }, bw, tgt, 0, 5, function() if b.phase == "Chase" and b.dx > 0.1 then ahead = true end end)
		assert(ahead, "Don Glaseon does not turn ahead of the runner (phase " .. tostring(b.phase) .. ")")
	end)

	case("OF3-2b: two creatures hunting the same player come from different sides", function()
		local w = fakeWorld()
		-- Deliberately changed (V4): the chaser cap ramps from 1 (V4-D9), so this player is put under a full minute of
		-- pressure first (the calm top, 3 since V4-D13): two hunters at once, as before.
		Smarts.press(w, 1, -60, 0)
		local a, b = spawn("Mochimiau", "a"), spawn("Mochimiau", "b", 0, 3)
		local tgt = target(28, 0)
		local bearing = {}
		run({ a, b }, w, tgt, 0, 3, function()
			for _, e in ipairs({ a, b }) do
				if not bearing[e.id] and e.phase == "Telegraph" then
					bearing[e.id] = math.atan2(e.pos.z - tgt.z, e.pos.x - tgt.x)
				end
			end
		end)
		assert(bearing[a.id] and bearing[b.id], "both did not reach the target")
		local delta = math.abs((bearing[a.id] - bearing[b.id] + math.pi) % (2 * math.pi) - math.pi)
		assert(delta >= math.rad(45), "same side: " .. math.deg(delta) .. " degrees apart")
		-- alone, one runs straight at its target
		local c, cw = spawn("Mochimiau", "solo"), fakeWorld()
		run({ c }, cw, target(28, 0), 0, 1.2)
		assert(math.abs(c.pos.z) < 0.5, "a lone creature swerved")
	end)

	case("OF3-2c: no creature walks through a wall; it side-steps round it", function()
		local function crosses(name, wx, half, tx, run_)
			local e, w = spawn(name, "wall"), fakeWorld({ castLane = wallX(wx, half) })
			local tgt = target(tx, 0)
			local px, pz, moved, bad = e.pos.x, e.pos.z, 0, false
			run({ e }, w, tgt, 0, run_, function()
				local x, z = e.pos.x, e.pos.z
				if (px - wx) * (x - wx) < 0 then
					local zc = pz + (z - pz) * (wx - px) / (x - px)
					if math.abs(zc) <= half then bad = true end
				end
				moved = math.max(moved, math.sqrt(x * x + z * z))
				px, pz = x, z
			end)
			assert(not bad, name .. " went through the wall")
			assert(moved >= 3, name .. " never moved (" .. moved .. ")")
			return e
		end
		local m = crosses("Mochimiau", 10, 6, 25, 3)
		assert(m.pos.x > 10, "Mochimiau never got round the wall: x " .. m.pos.x)
		crosses("Gomibu", 10, 6, 21, 3)
		crosses("Flanfuria", 6, 4, 15, 2.5)
		crosses("Tortidragon", 6, 4, 20, 2.5)
		local dx, dz = Smarts.steer({ beast = "Gomibu", pos = { x = 0, y = 0, z = 0 } }, { castLane = wallX(2, 3) }, 1, 0)
		assert(dx and math.abs(dz) > 0.5, "steer did not turn")
		local sx, sz = Smarts.steer({ beast = "Gomibu", pos = { x = 0, y = 0, z = 0 } }, {}, 1, 0)
		equal(sx, 1, "no cast: unchanged"); equal(sz, 0, "no cast: unchanged")
	end)

	case("OF3-2c: Don Glaseon walks round a wall too", function()
		local b = Enc.new("DonGlaseon", "wall", 1, 0, { x = 0, y = 0, z = 0 })
		local w = fakeWorld({ castLane = function(ox, _, oz, dx, dz, length)
			if math.abs(dz) < 1e-6 then return nil end
			local t = (4 - oz) / dz
			if t < 0 or t > length then return nil end
			return math.abs(ox + dx * t) <= 5 and t or nil
		end })
		local tgt = target(0, 30, { vx = 0, vz = 0 })
		local pz, px, bad = b.pos.z, b.pos.x, false
		run({ b }, w, tgt, 0, 6, function()
			if (pz - 4) * (b.pos.z - 4) < 0 then
				local xc = px + (b.pos.x - px) * (4 - pz) / (b.pos.z - pz)
				if math.abs(xc) <= 5 then bad = true end
			end
			px, pz = b.pos.x, b.pos.z
		end)
		assert(not bad, "the boss went through the wall")
	end)

	case("OF3-2d: a dodge makes it stop and re-aim for a moment", function()
		local dash = nil
		local e, w = spawn("Mochimiau", "dodge"), fakeWorld({ lastDash = function() return dash end })
		local tgt = target(30, 0)
		-- Deliberately changed (OF3 review): it only reacts to a dodge pressed close by, so the dash comes once it is
		-- within DODGE_REACT_STUDS (it was a dash at 0.9 s from 30 studs away).
		local t = 0
		while t < 3 and not dash do
			Enc.step(e, t, tgt, w)
			if e.phase == "Chase" and tgt.x - e.pos.x <= Smarts.DODGE_REACT_STUDS - 1 then dash = t end
			t += 0.05
		end
		assert(dash, "it never came close while chasing")
		run({ e }, w, tgt, t, t)
		local x0 = e.pos.x
		run({ e }, w, tgt, t + 0.05, t + 0.3)
		equal(e.pos.x, x0, "moved while reacting to the dodge")
		local p = Smarts.profile("Mochimiau")
		within(p.dodgePause, 0.3, 0.8, "pause")
	end)

	case("OF3 review: a far dodge is ignored and spamming dodge cannot keep a creature frozen", function()
		local dash = nil
		local w = fakeWorld({ lastDash = function() return dash end })
		local e = { beast = "Mochimiau", id = "spam", pos = { x = 0, y = 0, z = 0 } }
		local far, near = target(Smarts.DODGE_REACT_STUDS + 5, 0), target(6, 0)
		dash = 1
		equal(Smarts.dodged(e, w, 1.05, far), false, "reacted to a dodge pressed far away")
		dash = 2
		equal(Smarts.dodged(e, w, 2.05, near), true, "ignored a dodge close by")
		-- the server takes a missed dodge every 1.2 s: a second one inside the cooldown does nothing
		dash = 3.2
		equal(Smarts.dodged(e, w, 3.25, near), false, "frozen again inside the cooldown")
		assert(Smarts.DODGE_COOLDOWN_SECONDS >= 2.5, "cooldown " .. Smarts.DODGE_COOLDOWN_SECONDS)
		dash = 2 + Smarts.DODGE_COOLDOWN_SECONDS + 0.1
		equal(Smarts.dodged(e, w, dash + 0.05, near), true, "never reacts again after the cooldown")
		-- a press every 1.2 s for 12 s freezes it at most a small share of the time
		local f = { beast = "Mochimiau", id = "share", pos = { x = 0, y = 0, z = 0 } }
		local frozen, steps = 0, 0
		for i = 0, 240 do
			local now = i * 0.05
			dash = math.floor(now / 1.2) * 1.2
			if Smarts.dodged(f, w, now, near) then frozen += 1 end
			steps += 1
		end
		assert(frozen / steps <= 0.2, "frozen " .. math.floor(frozen / steps * 100) .. " % of the time")
	end)

	case("OF3 review: chase and sprint keep up with a trained walker, within caps", function()
		local e = { beast = "Mochimiau", id = "scale", pos = { x = 0, y = 0, z = 0 } }
		local P = Smarts.profile("Mochimiau")
		equal(Smarts.speed(e, 0, 21, target(0, 0, { walk = 16 })), P.sprint, "untrained: its own sprint")
		equal(Smarts.speed(e, 5, 21, target(0, 0, { walk = 16 })), 21, "untrained: its own chase")
		equal(Smarts.speed(e, 5, 21, target(0, 0)), 21, "no walk speed known: its own chase")
		local e2 = { beast = "Mochimiau", id = "scale2", pos = { x = 0, y = 0, z = 0 } }
		local s = Smarts.speed(e2, 0, 21, target(0, 0, { walk = 28 }))
		assert(s > 28, "the sprint does not beat a level-6 walker: " .. s)
		local c = Smarts.speed(e2, 5, 21, target(0, 0, { walk = 28 }))
		within(c, 0.85 * 28, 28, "chase against a level-6 walker")
		local capped = Smarts.speed(e2, 5, 21, target(0, 0, { walk = 50 }))
		equal(capped, Smarts.CHASE_CAP, "chase cap")
		local e3 = { beast = "Mochimiau", id = "scale3", pos = { x = 0, y = 0, z = 0 } }
		equal(Smarts.speed(e3, 0, 21, target(0, 0, { walk = 50 })), Smarts.SPRINT_CAP, "sprint cap")
		assert(Smarts.SPRINT_CAP >= Smarts.CHASE_CAP, "caps")
	end)

	case("OF3-2e: a guardian notices a target near its nest past its sight; a creature calls its calm allies", function()
		local g, gw = spawn("Gomibu", "guard"), fakeWorld()
		local T = Config.BEASTS.Gomibu.tuning
		local d = T.PerceptionStuds + 3
		assert(Smarts.profile("Gomibu").guard >= d, "guard radius under the test distance")
		local events = run({ g }, gw, target(d, 0), 0, 0.3)
		assert(phaseAt(events, g.id, "Notice"), "Gomibu ignored a target beside its nest")
		-- the call
		local w = fakeWorld()
		-- Deliberately changed (V4): a called ally obeys the chaser ramp too (V4-D9); under full pressure it comes at once,
		-- with no pressure it waits for the cap to rise (the next case pins that).
		Smarts.press(w, 1, -60, 0)
		local a, b = spawn("Mochimiau", "caller"), spawn("Mochimiau", "ally", 45, 0)
		local tgt = target(-10, 0)
		events = run({ a, b }, w, tgt, 0, 0.4)
		assert(phaseAt(events, a.id, "Notice"), "the caller did not notice")
		assert(phaseAt(events, b.id, "Notice"), "the ally was not called")
		local w2 = fakeWorld()
		local a2, b2 = spawn("Mochimiau", "caller2"), spawn("Mochimiau", "ally2", 45, 0)
		events = run({ a2, b2 }, w2, target(-10, 0), 0, 0.4)
		assert(phaseAt(events, a2.id, "Notice"), "the caller did not notice (no pressure)")
		assert(not Smarts.hunting(b2), "V4-D9: a called ally joined past the ramp's first cap")
		local c, cw = spawn("Mochimiau", "alone", 45, 0), fakeWorld()
		events = run({ c }, cw, target(-10, 0), 0, 0.4)
		assert(not phaseAt(events, c.id, "Notice"), "it noticed a target past its sight without a call")
	end)

	-- The summit (OF3-3).
	local summit = Frut.summit(Layout)
	local path = Frut.seedPath(Layout)
	local function player(id, x, y, z, extra)
		local p = { id = id, alive = true, x = x, y = y, z = z }
		for k, v in pairs(extra or {}) do p[k] = v end
		return p
	end
	local function radial(x, z)
		local dx, dz = x - summit.x, z - summit.z
		local l = math.sqrt(dx * dx + dz * dz)
		return dx / l, dz / l
	end

	case("OF3-3: Frutillon wakes and rolls sooner; his tell stays fair", function()
		assert(Frut.WAKE_SECONDS <= 1.7, "wake " .. Frut.WAKE_SECONDS)
		assert(Frut.RECOVER_SECONDS <= 0.7, "recover " .. Frut.RECOVER_SECONDS)
		assert(Frut.TELL_SECONDS >= MIN_TELL, "tell under MIN_TELL")
		assert(Frut.PUSH_STUDS >= 12, "his bump no longer throws off the summit")
	end)

	case("OF3-3: stair seeds come more often and knock a climber outward, off its tier", function()
		within(Frut.SEED_EVERY_SECONDS, 1.8, 2.2, "seed every")
		assert(Frut.SEED_PUSH_STUDS >= 9, "seed push " .. Frut.SEED_PUSH_STUDS)
		local state = Frut.new(0, summit)
		local s = path[math.floor(#path / 2)]
		local hit
		for i = 0, 200 do
			local t = i * 0.05
			for _, ev in ipairs(Frut.seedStep(state, t, { player(7, s.x, s.y + 3, s.z) }, path, summit)) do
				if ev.kind == "SeedHit" then hit = hit or ev end
			end
			if hit then break end
		end
		assert(hit, "no seed reached the climber")
		local rx, rz = radial(s.x, s.z)
		assert(hit.dx * rx + hit.dz * rz >= 0.5, "the seed's push is not outward")
	end)

	case("OF3-3: two patrols walk the stair with fair pauses and bump a climber outward", function()
		local defs = Frut.patrols(path)
		equal(#defs, 2, "patrols")
		assert(Frut.PATROL_PAUSE_SECONDS >= 1, "pause gap")
		assert(Frut.PATROL_TELL_SECONDS >= MIN_TELL and Frut.PATROL_TELL_SECONDS <= Frut.PATROL_PAUSE_SECONDS, "tell")
		-- a pause at both ends of every leg, and the tell before it sets off
		local d = defs[1]
		local pausing, telling = 0, 0
		for i = 0, 400 do
			local at = Frut.patrolAt(d, i * 0.05, path)
			if not at.moving then pausing += 1 end
			if at.tell then telling += 1 end
		end
		assert(pausing > 0 and telling > 0, "no pause or no tell")
		-- a climber standing in its way is bumped outward once per leg
		local state = Frut.new(0, summit)
		local hits = {}
		for i = 0, 600 do
			local t = i * 0.05
			local p = player(9, path[d.from + 1].x, path[d.from + 1].y + 3, path[d.from + 1].z)
			for _, ev in ipairs(Frut.patrolStep(state, t, { p }, path, summit)) do
				if ev.kind == "PatrolHit" then table.insert(hits, ev) end
			end
		end
		assert(#hits >= 1, "the patrol never bumped a climber on its steps")
		local s = path[d.from + 1]
		local rx, rz = radial(s.x, s.z)
		assert(hits[1].dx * rx + hits[1].dz * rz >= 0.5, "the patrol's bump is not outward")
		assert(hits[1].studs >= 8, "too weak to drop a tier")
		for _, ev in ipairs(hits) do assert(ev.damage == 0 or ev.damage == nil, "a patrol hurts") end
	end)

	case("OF3-3: glaze steps make a climber slip outward, never the top or bottom steps", function()
		local glaze = Frut.glazeSteps(path)
		assert(#glaze >= 3, "glaze steps " .. #glaze)
		for _, i in ipairs(glaze) do assert(i > 2 and i < #path - 1, "glaze on an end step " .. i) end
		local s = path[glaze[1]]
		local state = Frut.new(0, summit)
		local slips = {}
		-- walking over it (16 studs/s) is safe: the careful way up
		for i = 0, 60 do
			for _, ev in ipairs(Frut.glazeStep(state, i * 0.05, { player(3, s.x, s.y + 3, s.z, { vx = 16, vz = 0 }) }, path, summit)) do
				table.insert(slips, ev)
			end
		end
		equal(#slips, 0, "a walker slipped")
		-- running over it (16 x 1.45) slips
		for i = 61, 120 do
			for _, ev in ipairs(Frut.glazeStep(state, i * 0.05, { player(3, s.x, s.y + 3, s.z, { vx = 23.2, vz = 0 }) }, path, summit)) do
				table.insert(slips, ev)
			end
		end
		assert(#slips >= 1 and #slips <= 3, "slips " .. #slips)
		local rx, rz = radial(s.x, s.z)
		assert(slips[1].dx * rx + slips[1].dz * rz >= 0.5, "the slip is not outward")
		-- OF3 review: a trained walker (walk 22) walking at its own speed is safe; a sprinting one slips at any speed
		local trained = Frut.new(0, summit)
		local n = 0
		for i = 0, 60 do
			n += #Frut.glazeStep(trained, i * 0.05, { player(4, s.x, s.y + 3, s.z, { vx = 22, vz = 0, walk = 22, stance = "walk" }) }, path, summit)
		end
		equal(n, 0, "a trained walker slipped")
		for i = 61, 120 do
			n += #Frut.glazeStep(trained, i * 0.05, { player(4, s.x, s.y + 3, s.z, { vx = 16, vz = 0, walk = 22, stance = "sprint" }) }, path, summit)
		end
		assert(n >= 1, "a sprinting climber never slipped")
		-- a dash (a spike well above its own walk) still slips
		local dashing = Frut.new(0, summit)
		n = 0
		for i = 0, 10 do
			n += #Frut.glazeStep(dashing, i * 0.05, { player(6, s.x, s.y + 3, s.z, { vx = 40, vz = 0, walk = 22, stance = "walk" }) }, path, summit)
		end
		assert(n >= 1, "a dash over the glaze never slipped")
	end)

	case("OF3-3: La Duquesa throws at the upper tiers too, more often, ahead of a runner", function()
		local tiers = Layout.TOWER.tiers
		local upper = tiers[#tiers - 1]
		local y = Layout.FLOOR_TOP + upper.top + 3
		local x, z = summit.x + upper.radius - 2, summit.z
		local state = Duq.new()
		local charges = {}
		for i = 0, 40 do
			for _, ev in ipairs(Duq.step(state, i * 0.05, { player(5, x, y, z) }, summit)) do
				if ev.kind == "Charge" then table.insert(charges, ev) end
			end
		end
		assert(#charges >= 1, "no volley at a climber on the upper tier")
		assert(math.abs(charges[1].spots[1].y - (y - 3)) <= 0.5, "the ring is not on the climber's floor")
		assert(Duq.EVERY_SECONDS <= 6, "every " .. Duq.EVERY_SECONDS)
		assert(Duq.WINDUP_SECONDS + Duq.FLIGHT_SECONDS >= MIN_TELL, "tell")
		-- on the summit, two volleys within EVERY_SECONDS + 0.5
		state = Duq.new()
		local n = 0
		for i = 0, math.floor((Duq.EVERY_SECONDS + 0.5) / 0.05) do
			for _, ev in ipairs(Duq.step(state, i * 0.05, { player(5, summit.x + 3, summit.top + 3, summit.z) }, summit)) do
				if ev.kind == "Charge" then n += 1 end
			end
		end
		equal(n, 2, "summit volleys")
		-- ahead of a runner
		state = Duq.new()
		local first
		for _, ev in ipairs(Duq.step(state, 1, { player(5, summit.x + 3, summit.top + 3, summit.z, { vx = 0, vz = 8 }) }, summit)) do
			if ev.kind == "Charge" then first = ev end
		end
		for _, ev in ipairs(Duq.step(state, 1.5, { player(5, summit.x + 3, summit.top + 3, summit.z, { vx = 0, vz = 8 }) }, summit)) do
			if ev.kind == "Charge" then first = ev end
		end
		assert(first and first.spots[1].z > summit.z + 1, "the first bubble is not ahead of the runner")
		-- nobody on the tower: nothing
		state = Duq.new()
		for i = 0, 40 do
			for _, ev in ipairs(Duq.step(state, i * 0.05, { player(5, summit.x + 60, 3, summit.z) }, summit)) do
				assert(ev.kind ~= "Charge", "a volley at a player off the tower")
			end
		end
	end)

	-- RC: the relentless chase -------------------------------------------------------------------------------------------
	local CANDY = { "Mochimiau", "Canelin", "Flanin", "Mielita", "GatoRepartidor", "Gomibu", "Flanfuria", "Tortidragon" }
	local R = Smarts.RELENTLESS

	-- Deliberately changed (V7-D6, owner request 2026-11-17, "each creature has its zone and goes only so far"): the
	-- relentless chase no longer runs to the base: it ends where the hunter passes its zone (Smarts.PROFILES zone), and the
	-- creature walks home. The old leash, abandon and escape limits still do not end it inside the zone.
	case("RC1/V7-D6: a candy chase ends at the edge of the creature's zone (it walks home), the base, defeat or time", function()
		equal(R.hardSeconds, 180, "the safety end"); equal(R.fadeStuds, 120, "fade distance")
		assert(not Smarts.profile("DonGlaseon").relentless, "Don Glaseon stays territorial")
		assert(Smarts.profile("DonGlaseon").zone == nil, "Don Glaseon keeps his own territory")
		for _, name in ipairs(CANDY) do
			local T = Config.BEASTS[name].tuning
			local zone = Smarts.profile(name).zone
			assert(Smarts.profile(name).relentless, name .. " is not relentless")
			assert(type(zone) == "number" and zone >= 70 and zone <= 100, name .. " zone " .. tostring(zone))
			assert(zone < R.fadeStuds, name .. ": past its zone it walks home, never fades")
			local e, w = spawn(name, "rc1"), fakeWorld()
			local tgt = target(8, 0)
			run({ e }, w, tgt, 0, 1)
			assert(Smarts.hunting(e), name .. " does not hunt after noticing")
			-- the target runs straight out at 20 studs/s, far past every old limit and the zone
			local ended, endX
			for i = 1, 600 do
				local t = 1 + i * 0.05
				tgt.x, tgt.vx = 8 + (t - 1) * 20, 20
				local events = run({ e }, w, tgt, t, t)
				if phaseAt(events, e.id, "Return") then ended, endX = t, e.pos.x break end
				assert(#each(events, "End") == 0 and #each(events, "Disengage") == 0, name .. " ended before its zone")
			end
			assert(ended, name .. " never let go")
			assert(endX > math.max(T.AbandonStuds, T.LeashStuds), name .. " let go inside its old leash at " .. endX)
			-- (a leap or a roll in flight may carry it a few studs past the edge before the next step sees it)
			assert(endX > zone and endX <= zone + 12, name .. " let go at " .. endX .. " (zone " .. zone .. ")")
			-- the safe zone ends a hunt at once
			local s, sw = spawn(name, "rc1s"), fakeWorld()
			local st = target(8, 0)
			run({ s }, sw, st, 0, 1)
			st.safe = true
			local over = each(run({ s }, sw, st, 1.05, 1.1), "End")[1]
			assert(over and over.reason == "SafeZone", name .. " the base did not end it")
			-- death (no body) too
			local d, dw = spawn(name, "rc1d"), fakeWorld()
			run({ d }, dw, target(8, 0), 0, 1)
			over = each(run({ d }, dw, nil, 1.05, 1.1), "End")[1]
			assert(over and over.reason == "Death", name .. " death did not end it")
			-- the hard limit, inside the zone
			assert(not Smarts.overtime(s, s.huntFrom + R.hardSeconds - 0.01) and Smarts.overtime(s, s.huntFrom + R.hardSeconds),
				name .. " hard limit")
		end
	end)

	case("RC2: the second wind: windSeconds at the noticing sprint every windEvery, from windFirst seconds of a chase", function()
		equal(R.windFirst, 8); equal(R.windEvery, 8); equal(R.windSeconds, 1.5)
		assert(R.windFirst > 6, "only a chase longer than ~6 s gets it")
		for _, name in ipairs(CANDY) do
			local T, P = Config.BEASTS[name].tuning, Smarts.profile(name)
			local e = { beast = name, id = "wind" .. name, pos = { x = 0, y = 0, z = 0 } }
			local walker = target(0, 0, { walk = 16 })
			equal(Smarts.speed(e, 0, T.ChaseSpeedStudsPerSecond, walker), P.sprint, name .. " notices at a sprint")
			for _, s in ipairs({ 3, 7.9, 9.6, 15.9, 17.6 }) do
				equal(Smarts.speed(e, s, T.ChaseSpeedStudsPerSecond, walker), T.ChaseSpeedStudsPerSecond, name .. " base at " .. s)
			end
			for _, s in ipairs({ 8, 9.4, 16, 17.4, 24.1, 80.5 }) do
				equal(Smarts.speed(e, s, T.ChaseSpeedStudsPerSecond, walker), P.sprint, name .. " second wind at " .. s)
				assert(Smarts.secondWind(e, s), name .. " secondWind at " .. s)
			end
			assert(P.sprint >= 28 and P.sprint <= 30, name .. " wind speed " .. P.sprint)
			-- a sprinter (23.2) gains over a whole cycle: (base x 6.5 + sprint x 1.5) / 8 stays under 23.2 for an average
			local mean = (T.ChaseSpeedStudsPerSecond * (R.windEvery - R.windSeconds) + P.sprint * R.windSeconds) / R.windEvery
			assert(mean < 16 * 1.45 + 1.5, name .. " averages " .. mean .. " over a cycle")
			assert(mean > 16, name .. " never catches a walker")
		end
		local boss = { beast = "DonGlaseon", id = "windBoss", pos = { x = 0, y = 0, z = 0 } }
		Smarts.speed(boss, 0, 21, target(0, 0, { walk = 16 }))
		equal(Smarts.secondWind(boss, 9), false, "Don Glaseon has no second wind")
	end)

	case("RC3: far from home (past fadeStuds) an ending fades out; near home it walks back", function()
		local e = { beast = "Mochimiau", home = { x = 0, y = 0, z = 0 }, pos = { x = R.fadeStuds + 1, y = 0, z = 0 } }
		equal(Smarts.farFromHome(e), true, "far")
		e.pos.x = R.fadeStuds - 1
		equal(Smarts.farFromHome(e), false, "near")
		-- a Gomibu that hunted its target 150 studs away and hits the hard limit fades there (no 150-stud walk home)
		local g, w = spawn("Gomibu", "rc3"), fakeWorld()
		local tgt = target(8, 0)
		run({ g }, w, tgt, 0, 1)
		g.pos.x, tgt.x = 150, 190
		local events = run({ g }, w, tgt, g.huntFrom + R.hardSeconds - 0.05, g.huntFrom + R.hardSeconds + 1.5)
		local fade = each(events, "Disengage")[1]
		assert(fade and fade.reason == "Timeout", "no fade far from home")
		assert(not phaseAt(events, g.id, "Return"), "a long walk home")
		assert(each(events, "End")[1], "never ended")
	end)

	-- Deliberately changed (V4): the cap of five is reached only in a steal's frenzy (V4-D13); before any steal the calm
	-- ramp allows one hunter, one more every 20 s, at most three (was: five at once).
	case("RC4: at most maxChasers candy creatures hunt one player (V4: calm ramp to 3, a steal's frenzy 5); a freed place lets the next one in", function()
		equal(R.maxChasers, 5)
		local w = fakeWorld()
		local list = {}
		for i = 1, 6 do table.insert(list, spawn("Mochimiau", "cap" .. i, -4 * i, 6)) end
		local tgt = target(0, 0)
		local function count()
			local n = 0
			for _, e in ipairs(list) do if Smarts.hunting(e) then n += 1 end end
			return n
		end
		local most = {}
		run(list, w, tgt, 0, 60, function(t)
			-- the k-th 20 s slot, away from its edges (the first hunter engages on the first step, at 0)
			local slot = math.floor(t / R.rampEverySeconds)
			local into = t - slot * R.rampEverySeconds
			if into > 0.1 and into < R.rampEverySeconds - 0.1 then most[slot] = math.max(most[slot] or 0, count()) end
		end)
		equal(most[0], 1, "one hunter in the first 20 s")
		assert((most[1] or 0) <= 2, "20-40 s: " .. tostring(most[1]) .. " hunters")
		assert((most[2] or 0) <= 3, "40-60 s: " .. tostring(most[2]) .. " hunters")
		equal(count(), 3, "calm: three hunters after a minute, never more")
		-- a steal: the frenzy lets five hunt at once
		Smarts.frenzy(w, 1, 60, 0, 0)
		run(list, w, tgt, 60.05, 61.5)
		equal(count(), 5, "hunters on one player in the frenzy")
		equal(Smarts.chasers(w, 1, 61.5), 5, "chasers counted")
		equal(Smarts.cap(w, 1, 61.5), 5, "the cap")
		local waiting
		for _, e in ipairs(list) do if not Smarts.hunting(e) then waiting = e end end
		assert(waiting and (waiting.phase == "Patrol" or waiting.phase == "Calm"), "the sixth stays calm")
		-- one hunter leaves (its encounter ended): the sixth starts its hunt
		for _, e in ipairs(list) do if Smarts.hunting(e) then e.done = true break end end
		run(list, w, tgt, 61.55, 62)
		assert(Smarts.hunting(waiting), "the sixth never joined after a place freed")
		-- another player has its own ramp and its own cap
		local other = spawn("Mochimiau", "cap7", 10, 10)
		other.userId = 2
		run({ other }, w, target(12, 10), 62.05, 62.3)
		assert(Smarts.hunting(other), "another player's creature was capped by this player's hunters")
		-- the strike ledger: at most STRIKE_MAX strikes of different owners within STRIKE_WINDOW on one player
		equal(Smarts.STRIKE_WINDOW, 0.6); equal(Smarts.STRIKE_MAX, 2)
		equal(Smarts.claimStrike(901, "a", 10, 9), true, "first")
		equal(Smarts.claimStrike(901, "b", 10.3, 9), true, "a second within the window")
		equal(Smarts.claimStrike(901, "c", 10.5, 9), false, "a third within the window")
		equal(Smarts.claimStrike(902, "c", 10.5, 9), true, "another player's ledger")
		equal(Smarts.claimStrike(901, "c", 10.95, 9), true, "past the window of the first")
		equal(Smarts.claimStrike(904, "a", 5, 4), true); equal(Smarts.claimStrike(904, "a", 5.1, 4), true)
		equal(Smarts.claimStrike(904, "a", 5.2, 4), true, "an owner never blocks itself")
		Smarts.forgetStrikes(904)
		Smarts.releaseStrikes(901, "b")
		Smarts.forgetStrikes(901)
		equal(Smarts.claimStrike(901, "z", 10.3, 9), true, "forgotten")
		equal(Smarts.claimStrike(903, "x", 20, 9, true), true, "forced")
		equal(Smarts.claimStrike(903, "y", 20.1, 9, true), true, "forced")
		equal(Smarts.claimStrike(903, "z", 20.2, 9, true), true, "forced past the cap (an attack whose timing never changes)")
		Smarts.forgetStrikes(902); Smarts.forgetStrikes(903); Smarts.forgetStrikes(901)
	end)

	-- V4-D9 with the numbers of V4-D13 (owner 2026-11-17: "at first they must chase less, it progresses, and when you
	-- steal an egg it should rise a lot"): the calm cap starts at 1 when the first hunter engages and rises by one every
	-- 20 s, up to 3; 10 s with no hunter ends the pressure. Pure: fake encounters and an injected clock.
	case("V4-D13: the calm cap ramps 1 -> 3 by one every 20 s of pressure and resets after 10 s with no hunter", function()
		equal(R.rampStart, 1, "start"); equal(R.rampEverySeconds, 20, "every"); equal(R.rampMax, 3, "calm top")
		equal(R.rampResetSeconds, 10, "reset"); equal(R.maxChasers, 5, "the RC cap stays (a steal's frenzy)")
		local w = {}
		local made = {}
		local function hunter(id, user) local e = { beast = "Mochimiau", id = id, userId = user or 7, phase = "Chase" }; table.insert(made, e); return e end
		local function tick(t) for _, e in ipairs(made) do if not e.done then e.lastStep = t end end end
		equal(Smarts.cap(w, 7, 0), 1, "no pressure: the first cap")
		equal(Smarts.cap(nil, 7, 0), R.maxChasers, "no board: the old flat cap")
		equal(Smarts.cap(w, 7, 0 / 0), R.maxChasers, "no clock: the old flat cap")
		local h = {}
		for i = 1, 6 do h[i] = hunter("h" .. i) end
		tick(0)
		equal(Smarts.engage(h[1], w, 0), true, "the first hunter")
		equal(h[1].huntFrom, 0)
		equal(Smarts.engage(h[2], w, 0), false, "a second at once is held back")
		equal(h[2].huntFrom, nil, "held back: no hunt")
		tick(19.9)
		equal(Smarts.cap(w, 7, 19.9), 1); equal(Smarts.engage(h[2], w, 19.9), false, "still one before 20 s")
		for k = 2, 3 do
			local t = (k - 1) * 20
			tick(t)
			equal(Smarts.cap(w, 7, t), k, "the cap at " .. t .. " s")
			equal(Smarts.engage(h[k], w, t), true, "hunter " .. k .. " at " .. t .. " s")
			equal(Smarts.engage(h[k + 1], w, t), false, "hunter " .. (k + 1) .. " at " .. t .. " s")
		end
		tick(120)
		equal(Smarts.cap(w, 7, 120), 3, "calm: never past rampMax")
		equal(Smarts.engage(h[4], w, 120), false, "a fourth stays calm")
		-- a critter held back while it sees its player is not idle (its idle clock restarts)
		local critter = hunter("idle")
		critter.patrolSince = 100
		tick(120)
		equal(Smarts.engage(critter, w, 120), false); equal(critter.patrolSince, nil, "held back: its idle clock restarts")
		critter.done = true
		-- the hunters all leave at 130: under 10 s later the pressure (and the calm cap of 3) holds
		tick(130)
		for i = 1, 3 do h[i].done = true end
		equal(Smarts.cap(w, 7, 139.9), 3, "9.9 s without a hunter: the pressure holds")
		local back = hunter("back")
		tick(139.9)
		equal(Smarts.engage(back, w, 139.9), true, "a returning hunter")
		back.done = true
		-- 10 s with no hunter: the pressure ends, the next hunt starts at the first cap again
		equal(Smarts.cap(w, 7, 150), 1, "10 s without a hunter: back to 1")
		local a, b = hunter("a"), hunter("b")
		tick(150.5)
		equal(Smarts.engage(a, w, 150.5), true, "a fresh pressure")
		equal(Smarts.engage(b, w, 150.5), false, "one at a time again")
		tick(170.5)
		equal(Smarts.engage(b, w, 170.5), true, "20 s later the second")
		-- each player has its own ramp; a non-relentless creature never waits
		local other = hunter("o", 8)
		other.lastStep = 170.5
		equal(Smarts.engage(other, w, 170.5), true, "another player's first hunter")
		equal(Smarts.engage({ beast = "DonGlaseon", id = "boss", userId = 7, phase = "Chase", lastStep = 170.5 }, w, 170.5), true,
			"Don Glaseon is never held back")
		-- press: a player put under pressure from `from` has the cap of that much pressure
		local pw = {}
		Smarts.press(pw, 3, -20, 0)
		equal(Smarts.cap(pw, 3, 0), 2, "20 s of pressure: two")
	end)

	-- V4-D13: a steal sets a 60 s frenzy: the full cap at once and a call to every candy creature whose post lies within
	-- 150 studs of the nest; then the calm ramp again.
	case("V4-D13: a steal's frenzy: cap 5 at once for 60 s, a call within 150 studs of the nest, then the calm ramp", function()
		equal(R.frenzySeconds, 60); equal(R.frenzyStuds, 150)
		local w = {}
		equal(Smarts.frenzyAt(w, 5, 0), nil, "no frenzy before a steal")
		equal(Smarts.frenzy(w, 5, 100, 400, 20), true)
		equal(Smarts.cap(w, 5, 100), 5, "at once"); equal(Smarts.cap(w, 5, 159.9), 5, "for 60 s")
		local f = Smarts.frenzyAt(w, 5, 130)
		assert(f and f.x == 400 and f.z == 20 and f.studs == 150, "the frenzy point")
		local near = { beast = "Canelin", id = "n", userId = 5, home = { x = 400 + 149, z = 20 }, pos = { x = 0, y = 0, z = 0 } }
		local far = { beast = "Canelin", id = "f", userId = 5, home = { x = 400 + 151, z = 20 }, pos = { x = 0, y = 0, z = 0 } }
		local boss = { beast = "DonGlaseon", id = "b", userId = 5, home = { x = 400, z = 20 }, pos = { x = 0, y = 0, z = 0 } }
		local stranger = { beast = "Canelin", id = "s", userId = 6, home = { x = 400, z = 20 }, pos = { x = 0, y = 0, z = 0 } }
		equal(Smarts.called(near, w, 130), true, "a post within 150 studs is called")
		equal(Smarts.called(far, w, 130), false, "past 150 studs: not")
		equal(Smarts.called(boss, w, 130), false, "Don Glaseon stays territorial")
		equal(Smarts.called(stranger, w, 130), false, "another player's creatures are not")
		equal(Smarts.called(near, w, 160), false, "the call ends with the frenzy")
		equal(Smarts.frenzyAt(w, 5, 160), nil)
		-- after the frenzy: the calm ramp from the steal (60 s of pressure: its top, 3), while hunted
		local e = { beast = "Canelin", id = "h", userId = 5, phase = "Chase", lastStep = 160 }
		equal(Smarts.engage(e, w, 160), true)
		equal(Smarts.cap(w, 5, 160), 3, "back to the calm ramp")
		equal(Smarts.frenzy(w, 5, 0 / 0, 1, 1), false, "no clock, no frenzy")
	end)

	-- V4-D12 (owner 2026-11-17: "no creature may enter the houses"): a creature's move is kept outside every house disc
	-- (plus HOUSE_MARGIN_STUDS): it stops at the edge, slides round it and waits there.
	case("V4-D12: a creature's step never ends inside a house; it stops at the edge, slides round it and waits", function()
		local discs = { { id = "H1", x = 0, z = 0, r = 10 }, { id = "H2", x = 30, z = 0, r = 6 } }
		local m = Smarts.HOUSE_MARGIN_STUDS
		assert(m >= 1 and m <= 3, "margin " .. m)
		local function d(x, z, c) return math.sqrt((x - c.x) ^ 2 + (z - c.z) ^ 2) end
		-- outside to outside: untouched
		local x, z = Smarts.outsideHouses(-30, 0, -20, 0, discs)
		equal(x, -20); equal(z, 0)
		-- a step into the house stops at the edge, on the side it came from
		x, z = Smarts.outsideHouses(-12, 0, -8, 0, discs)
		assert(math.abs(d(x, z, discs[1]) - (10 + m)) < 0.01 and x < 0, ("stopped at %.2f, %.2f"):format(x, z))
		-- chasing a target inside, step after step, it waits at the edge (never closer)
		local px, pz = -20, 1
		for _ = 1, 40 do
			local nx, nz = px + 1, pz -- straight at the centre
			px, pz = Smarts.outsideHouses(px, pz, nx, nz, discs)
			assert(d(px, pz, discs[1]) >= 10 + m - 1e-6, "inside the house")
		end
		-- a step on the centre goes back out on its own side; one landing in a neighbour is pushed out of both
		x, z = Smarts.outsideHouses(-15, 0, 0, 0, discs)
		assert(x < 0 and math.abs(d(x, z, discs[1]) - (10 + m)) < 0.01, "centre")
		x, z = Smarts.outsideHouses(20, 0, 30, 0, discs)
		assert(d(x, z, discs[1]) >= 10 + m - 1e-6 and d(x, z, discs[2]) >= 6 + m - 1e-6, "between two houses")
		x, z = Smarts.outsideHouses(-20, 0, 0 / 0, 0, discs)
		assert(x ~= x, "a bad point is left to the caller")
		-- sheltered: inside the footprint itself
		equal(Smarts.inHouse(5, 5, discs).id, "H1"); equal(Smarts.inHouse(0, 10.5, discs), nil)
		equal(Smarts.inHouse(0, 10.5, discs, m).id, "H1", "with the margin"); equal(Smarts.inHouse(0, 0, nil), nil)
		-- a house's disc holds its whole bounding box, round its pivot
		local disc = Smarts.houseDisc("H3", 100, 50, 101, 50, 20, 30)
		equal(disc.id, "H3"); equal(disc.x, 100); equal(disc.z, 50); equal(disc.r, 16, "half the long side plus the offset")
		equal(Smarts.houseDisc("H4", 0 / 0, 0, 0, 0, 1, 1), nil)
		equal(#Smarts.houseDiscs(nil), 0, "no biome, no houses")
	end)

	-- RC7: the runner model. An untrained runner leaves a nest (E1 mid-biome, R6 deep) with full health and stamina,
	-- straight to the plot's entrance and on to the hub's safe edge (WildboundWorldRules HUB, the bases): it holds sprint
	-- all the way (WildboundStamina: pool 100, drain 25/s, a sprint starts at 10, after empty none until 30, regen 10/s
	-- 1.5 s after the last drain), 23.2 sprinting, 16 walking, slowed by the hits' slows (one at a time) and pushed on.
	-- Each creature notices it 12 studs behind (an egg thief at the nest), alerts, then chases at Smarts.speed (its
	-- sprint, base chase and second wind) and attacks within its range when ready, with the real tell to strike,
	-- recovery and cooldown (Follow chains included), booking its strike through the stagger (0.8 s from any other
	-- beast) and the ledger. A swarm wakes 12 studs behind, cruises at 26 and dives within 7 studs (tell 0.8 + dive 0.5,
	-- gap 0.9, tired gap 5 after 3 stings). Health regenerates 1 a second (Roblox's default Health script).
	-- "never": it never dodges and stays in every shape (a runner on the real map cannot count on outrunning a circle);
	-- "perfect": it presses dodge at every strike: a candy beast's attack is not registered, so the dash's i-frames
	-- cover it (BeastHit answers dodged) and the press costs the miss cooldown 1.2 s; a dive is registered (0.6 s). The
	-- dash carries it 52 x 0.22 studs on, and a creature within 12 studs pauses dodgePause.
	local DT = 0.05
	local LIT = { -- the guardians' attack modules (pinned in their own suites)
		Flanfuria = { strike = 0.8 + 0.8, recover = 0.6, ready = 0.6 + 5, damage = Config.BEASTS.Flanfuria.damage, push = 0,
			slow = { 0.65, 1.5 }, kind = "stay", range = Config.BEASTS.Flanfuria.tuning.CastRangeStuds, stand = 4 },
		Tortidragon = { strike = 0.8 + 0.65, recover = 0.6, ready = 0.6 + 4.5, damage = Config.BEASTS.Tortidragon.damage, push = 4,
			slow = { 0.85, 0.8 }, kind = "stay", range = Config.BEASTS.Tortidragon.tuning.CastRangeStuds, stand = 6 },
	}
	local function specOf(name)
		local C = Config.BEASTS[name]
		local T = C.tuning
		local s
		if LIT[name] then
			s = table.clone(LIT[name])
		elseif name == "Gomibu" then
			s = { strike = math.max(T.TelegraphSeconds, MIN_TELL) + T.JumpSeconds, recover = T.RecoverSeconds,
				ready = T.RecoverSeconds + T.AttackCooldownSeconds, damage = C.damage, push = T.PushStuds,
				slow = { T.SlowMultiplier, T.SlowSeconds }, kind = "leap", range = T.JumpRangeStuds, stand = 3 }
		else
			local A = T.Attack
			local F = T.Extras and T.Extras.Follow
			s = { strike = Critter.tellSeconds(A) + A.TravelSeconds, recover = A.RecoverSeconds, ready = A.CooldownSeconds,
				damage = C.damage, push = A.PushStuds or 0, slow = { A.SlowMultiplier, A.SlowSeconds },
				kind = (A.kind == "leap" or A.kind == "dash") and A.kind or "stay", range = A.RangeStuds,
				stand = T.StandOffStuds or (A.kind == "leap" and 3 or math.min(A.RangeStuds * 0.6, 4)),
				follow = F and { F.Max, F.RangeStuds } or nil }
		end
		s.base, s.alert = T.ChaseSpeedStudsPerSecond, T.AlertSeconds
		return s
	end
	local function legs(nest)
		local n
		for _, row in ipairs(Layout.NESTS) do if row.id == nest then n = row end end
		local p, gate = Layout.world(n), Layout.world(Layout.ENTRANCE)
		local d1 = Layout.flat(p.x, p.z, gate.x, gate.z)
		local d2 = Layout.flat(gate.x, gate.z, Rules.HUB_X, Rules.HUB_Z) - Rules.HUB_RADIUS
		return d1 + d2, d1, d2
	end
	local function model(names, swarms, D, policy)
		local r, hp, minhp = 0, 100, 100
		local st = { s = 100, stance = "walk", ex = false, last = -math.huge }
		local slowU, slowM, dodgeReady, dashAt = -math.huge, 1, -math.huge, nil
		local out = { hits = 0, opened = 0, dodged = 0, undodgeable = 0, strikes = {}, minhp = 100 }
		local crs, sws, claims, ledger = {}, {}, {}, {}
		for _, name in ipairs(names) do
			local s = specOf(name)
			table.insert(crs, { name = name, s = s, c = -12, alertEnd = s.alert, strikeAt = nil, recoverU = -math.huge,
				readyAt = -math.huge, e = { beast = name }, daze = -math.huge, dazeReady = -math.huge, followLeft = 0, following = false })
		end
		for i = 1, swarms do table.insert(sws, { id = "fly" .. i, s = -12, alertEnd = 1, strikeAt = nil, nextAt = -math.huge, stings = 0 }) end
		local function ledgerOk(owner, at, now)
			for i = #ledger, 1, -1 do if ledger[i].at < now - 1 then table.remove(ledger, i) end end
			local near = 0
			for _, c in ipairs(ledger) do if c.owner ~= owner and math.abs(c.at - at) < Smarts.STRIKE_WINDOW then near += 1 end end
			if near >= Smarts.STRIKE_MAX then return false end
			table.insert(ledger, { at = at, owner = owner })
			return true
		end
		local function beastClaim(owner, at, now)
			for i = #claims, 1, -1 do if claims[i].at < now - 1 then table.remove(claims, i) end end
			for _, c in ipairs(claims) do if c.owner ~= owner and math.abs(c.at - at) < Config.DIRECTOR.STRIKE_SEPARATION then return false end end
			if not ledgerOk(owner, at, now) then return false end
			table.insert(claims, { at = at, owner = owner })
			return true
		end
		local function strike(now, damage, push, slow, registered, who)
			table.insert(out.strikes, { at = now, who = who })
			if policy == "perfect" then
				if now >= dodgeReady then
					out.dodged += 1
					dodgeReady = now + (registered and 0.6 or 1.2)
					r += 52 * 0.22
					dashAt = now
					return false
				end
				out.undodgeable += 1
			end
			out.hits += 1
			hp -= damage
			minhp = math.min(minhp, hp)
			r += push
			if slow and now >= slowU then slowU, slowM = now + slow[2], slow[1] end
			return true
		end
		for i = 1, 4000 do
			local t = i * DT
			-- the runner (WildboundStamina.step, always asking to sprint, always moving)
			local threshold = st.stance == "sprint" and 1e-6 or 10 - 1e-6
			if st.ex and st.s >= 30 - 1e-6 then st.ex = false end
			if not st.ex and st.s >= threshold then
				st.stance, st.s, st.last = "sprint", st.s - 25 * DT, t
				if st.s <= 1e-6 then st.s, st.ex, st.stance = 0, true, "ex" end
			else
				st.stance = st.ex and "ex" or "walk"
				if t - st.last >= 1.5 - 1e-6 then st.s = math.min(100, st.s + 10 * DT) end
				if st.ex and st.s >= 30 - 1e-6 then st.ex, st.stance = false, "walk" end
			end
			r += (st.stance == "sprint" and 23.2 or 16) * (t < slowU and slowM or 1) * DT
			hp = math.min(100, hp + DT)
			if r >= D then out.arrive, out.minhp = t, minhp return out end
			for _, cr in ipairs(crs) do
				local s = cr.s
				if t >= cr.alertEnd then
					if dashAt and math.abs(t - dashAt) < 1e-9 and r - cr.c <= Smarts.DODGE_REACT_STUDS and t >= cr.dazeReady then
						cr.daze, cr.dazeReady = t + Smarts.profile(cr.name).dodgePause, t + Smarts.DODGE_COOLDOWN_SECONDS
					end
					if cr.strikeAt then
						if t >= cr.strikeAt - 1e-9 then
							local at = cr.strikeAt
							cr.strikeAt = nil
							if s.kind == "leap" then cr.c = math.max(cr.c, r - 1) elseif s.kind == "dash" then cr.c = math.min(cr.c + 14, r - 1) end
							strike(at, s.damage, s.push, s.slow, false, cr.name)
							cr.recoverU = at + s.recover
							if s.follow and cr.followLeft > 0 then cr.following, cr.readyAt = true, at + s.recover
							else cr.following, cr.readyAt = false, at + s.ready end
							cr.lastStrike = at
						end
					elseif t >= cr.recoverU then
						local gap = r - cr.c
						if cr.following and s.follow and gap > s.follow[2] then cr.following, cr.readyAt = false, cr.lastStrike + s.ready end
						if t >= cr.daze then
							local opened = false
							if gap <= s.range and t >= cr.readyAt and beastClaim(cr.name, t + s.strike, t) then
								cr.strikeAt, opened = t + s.strike, true
								out.opened += 1
								if s.follow then
									if cr.following then cr.followLeft -= 1 else cr.followLeft = s.follow[1] end
									cr.following = false
								end
							end
							if not opened and gap > s.stand then
								cr.c += math.min(Smarts.speed(cr.e, t, s.base, { walk = 16 }) * DT, gap - s.stand)
							end
						end
					end
				end
			end
			for _, sw in ipairs(sws) do
				if t >= sw.alertEnd then
					sw.s += math.min(26 * DT, math.max(r - sw.s, 0))
					if sw.strikeAt then
						if t >= sw.strikeAt - 1e-9 then
							local at = sw.strikeAt
							sw.strikeAt = nil
							if strike(at, 12, 6, nil, true, sw.id) then sw.stings += 1 end
							sw.nextAt = at + (sw.stings >= 3 and 5 or 0.9)
						end
					elseif r - sw.s <= 7 and t >= sw.nextAt and ledgerOk(sw.id, t + 1.3, t) then
						sw.strikeAt = t + 1.3
						out.opened += 1
					end
				end
			end
			if hp <= 0 then out.dead, out.minhp = t, minhp return out end
		end
		out.minhp = minhp
		return out
	end
	local function spaced(out, label)
		-- the stagger and the ledger: beasts' strikes 0.8 s apart, never three strikes within 0.6 s
		local list = out.strikes
		for i = 1, #list do
			for j = i + 1, #list do
				local a, b = list[i], list[j]
				local beasts = string.sub(a.who, 1, 3) ~= "fly" and string.sub(b.who, 1, 3) ~= "fly"
				if beasts and a.who ~= b.who then
					assert(math.abs(a.at - b.at) >= Config.DIRECTOR.STRIKE_SEPARATION - 1e-6, label .. ": two beast strikes " .. math.abs(a.at - b.at) .. " s apart")
				end
				for k = j + 1, #list do
					local lo = math.min(a.at, b.at, list[k].at)
					local hi = math.max(a.at, b.at, list[k].at)
					assert(hi - lo >= Smarts.STRIKE_WINDOW - 1e-6 or (a.who == b.who or b.who == list[k].who or a.who == list[k].who),
						label .. ": three strikes within " .. (hi - lo) .. " s")
				end
			end
		end
	end

	case("RC7: runner model to the base: one creature hurts but never defeats; several must be dodged; a dodger is unhurt", function()
		local D1 = legs("E1")
		local D6, to6, gate6 = legs("R6")
		assert(D1 > 150 and D1 < 260, "E1 to the base " .. D1)
		assert(D6 > D1 + 100, "R6 deeper " .. D6)
		assert(gate6 > 20 and gate6 < 80, "the plot's entrance to the hub's edge " .. gate6)
		assert(to6 > 250, "R6 to the entrance " .. to6)
		for _, D in ipairs({ D1, D6 }) do
			for _, name in ipairs(CANDY) do
				local never = model({ name }, 0, D, "never")
				assert(never.arrive and not never.dead, name .. ": a lone creature defeated a runner over " .. D)
				assert(never.hits >= 1, name .. ": never touched a runner who never dodges over " .. D)
				assert(never.minhp >= 40, name .. ": left " .. never.minhp .. " health over " .. D)
				local perfect = model({ name }, 0, D, "perfect")
				equal(perfect.hits, 0, name .. ": a perfect dodger was hurt over " .. D)
				assert(perfect.arrive, name .. ": a perfect dodger never arrived")
				spaced(never, name)
			end
			local swarm = model({}, 1, D, "never")
			assert(swarm.arrive and swarm.hits >= 1 and swarm.minhp >= 40, "one swarm: " .. swarm.hits .. " stings, " .. swarm.minhp)
			equal(model({}, 1, D, "perfect").hits, 0, "a perfect dodger and one swarm")
		end
		-- everything at once (the cap: five hunters and three swarms) from the deep nest: a runner who never dodges falls;
		-- one who dodges arrives, hurt less. V4-D13: five hunters at once only happen in a steal's 60 s frenzy (an egg
		-- thief, as modelled here); before any steal the calm cap is at most three.
		local five = { "Gomibu", "Flanfuria", "Tortidragon", "Mochimiau", "Mielita" }
		local never = model(five, 3, D6, "never")
		assert(never.dead, "five hunters and three swarms never defeated a runner who never dodges")
		local perfect = model(five, 3, D6, "perfect")
		assert(perfect.arrive and not perfect.dead, "a dodger never got through five hunters and three swarms")
		assert(perfect.hits < never.hits, "dodging did not help")
		spaced(never, "the crowd"); spaced(perfect, "the crowd dodged")
	end)

	return result
end

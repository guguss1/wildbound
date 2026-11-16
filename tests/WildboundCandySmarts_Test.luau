-- Invoke with require(freshTestClone)(require(freshCandySmartsClone), require(freshBeastEncountersClone),
-- require(freshBeastConfigClone), require(freshBeastCandyCritterClone), require(freshBeastGomibuClone),
-- require(freshBeastFlanfuriaClone), require(freshBeastTortidragonClone), require(freshBeastDonGlaseonClone),
-- require(freshCandyFrutillonClone), require(freshCandyDuquesaClone), require(freshCandyLayoutClone)).
-- Owner feedback 3 (odd/tasks/wildbound-caramelo-playfix.md, OF3): faster and smarter candy creatures (a sprint burst,
-- predictive aim, flanking, anti-stuck, a pause on the player's dodge, nest guarding and a call to allies) and a hard
-- but possible Gran Torta summit (Frutillon quicker, seeds and patrols that knock a climber off a tier, glaze steps, La
-- Duquesa throwing at the upper tiers). Pure, on the fake worlds of the brains' own suites.
return function(Smarts, Enc, Config, Critter, Gomibu, Flanfuria, Tortidragon, Boss, Frut, Duq, Layout)
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

	case("OF3-1: base chase 19-22, a sprint of 24-27 for 1.5-2.5 s, never a one-shot, tells never under MIN_TELL", function()
		for _, name in ipairs({ "Mochimiau", "Canelin", "Flanin", "Mielita", "GatoRepartidor", "Gomibu", "Flanfuria", "Tortidragon" }) do
			local C = Config.BEASTS[name]
			within(C.tuning.ChaseSpeedStudsPerSecond, 19, 22, name .. " chase")
			local P = Smarts.profile(name)
			within(P.sprint, 24, 27, name .. " sprint"); within(P.sprintSeconds, 1.5, 2.5, name .. " sprint seconds")
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
		within(e.pos.x - x0, 26 * 0.5 - 1.5, 26 * 0.5 + 0.1, "studs in the first half second")
		equal(Smarts.speed(e, chaseAt + 3, 21), 21, "after the burst")
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
		local a, b = spawn("Mochimiau", "caller"), spawn("Mochimiau", "ally", 45, 0)
		local tgt = target(-10, 0)
		events = run({ a, b }, w, tgt, 0, 0.4)
		assert(phaseAt(events, a.id, "Notice"), "the caller did not notice")
		assert(phaseAt(events, b.id, "Notice"), "the ally was not called")
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

	return result
end

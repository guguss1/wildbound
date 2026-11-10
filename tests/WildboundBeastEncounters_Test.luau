-- Invoke with require(freshTestClone)(require(freshBeastEncountersClone), freshBeastEncountersClone.Source,
-- require(freshBeastConfigClone), freshBeastConfigClone.Source).
-- Nest Heist phase 4a (NB3, docs/design/beast-pack/01_VIPER.md and 02_POUNCER.md): the two beasts' server state
-- machines, stepped with fake targets and a fake world. The lane and the circle the client draws come from the same
-- WildboundBeastConfig geometry the server checks hits with, so the tests check the shared functions and the
-- simulation together. Every attack has a tell of at least 0.8 s and a real dodge.
return function(Enc, source, Config, configSource)
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
	local V, P = Config.BEASTS.Viper, Config.BEASTS.Pouncer
	local DT = 0.05
	-- A target that stands still unless `move(now)` returns a new position.
	local function standing(x, z, move)
		local t = { x = x, y = 3, z = z, vx = 0, vz = 0, alive = true, safe = false }
		return function(now)
			if move then
				local nx, nz, extra = move(now, t)
				if nx then t.x, t.z = nx, nz end
				if extra then for k, v in pairs(extra) do t[k] = v end end
			end
			return t
		end
	end
	local OPEN = {}
	-- Steps an encounter from `from` to `to` and returns every event, by type, with the times.
	local function run(e, from, to, target, world)
		local events, byType = {}, {}
		local now = from
		while now <= to + 1e-9 do
			for _, ev in ipairs(Enc.step(e, now, target(now), world or OPEN)) do
				table.insert(events, ev)
				byType[ev.type] = byType[ev.type] or {}
				table.insert(byType[ev.type], ev)
			end
			now += DT
		end
		return events, byType
	end
	local function count(byType, kind) return byType[kind] and #byType[kind] or 0 end
	-- A Viper 25 studs north of a target at the origin: already in attack range.
	local function viperInRange(now) return Enc.new("Viper", "beast:1", 1, now or 0, { x = 0, y = 3, z = 25 }) end

	case("NB3 config: every tell is at least 0.8 s and leaves a real dodge window", function()
		assert(V.windup >= Config.MIN_TELL, "Viper windup")
		assert(V.windup - V.lockLead >= 0.5, "the lane follows the target for a while")
		near(V.lockLead, 0.45, "angle locked for the last 0.45 s")
		equal(V.laneLength, 32); equal(V.laneWidth, 4.5); equal(V.dashSpeed, 60); equal(V.damage, 35)
		local dash = V.laneLength / V.dashSpeed
		assert(dash >= 0.45 and dash <= 0.75, "dash lasts 0.45 to 0.75 s: " .. dash)
		equal(V.maxAttacks, 3); equal(V.maxSeconds, 32); equal(V.escapeDistance, 100); equal(V.escapeSeconds, 4)
		assert(P.telegraph >= Config.MIN_TELL, "Pouncer telegraph")
		assert(P.telegraph - P.freezeAfter + P.flight >= 1, "at least 1 s from the frozen circle to the landing")
		equal(P.radius, 6.5); equal(P.flight, 0.75); equal(P.arcHeight, 10); equal(P.damage, 40); equal(P.recover, 1.2)
		equal(P.jumps, 2); equal(P.maxJumps, 3); equal(P.maxSeconds, 33); equal(P.escapeDistance, 105)
	end)

	case("NB3 geometry: the drawn lane is exactly the hit rectangle", function()
		local lane = Config.lane(0, 0, 0, 1, 32, 4.5)
		near(lane.cx, 0); near(lane.cz, 16)
		local look = CFrame.Angles(0, lane.yaw, 0).LookVector
		near(look.X, 0, "look x"); near(look.Z, 1, "the part's LookVector runs along the lane")
		assert(Config.inLane(2.25, 10, 0, 0, 0, 1, 0, 32, 4.5), "edge is inside")
		assert(not Config.inLane(2.26, 10, 0, 0, 0, 1, 0, 32, 4.5), "just past the edge is out")
		assert(Config.inLane(0, 32, 0, 0, 0, 1, 0, 32, 4.5) and not Config.inLane(0, 32.01, 0, 0, 0, 1, 0, 32, 4.5), "far end")
		assert(not Config.inLane(0, -0.01, 0, 0, 0, 1, 0, 32, 4.5), "behind the origin")
		local dx, dz = Config.unit(3, 4)
		near(dx, 0.6); near(dz, 0.8)
		assert(Config.inLane(3 * 4 + 0.8 * 2, 4 * 4 - 0.6 * 2, 0, 0, dx, dz, 0, 32, 4.5), "rotated lane, 2 studs to the side")
		equal(Config.unit(0, 0), nil)
	end)

	case("NB3 geometry: the drawn circle is the hit circle; the arc peaks at the arc height", function()
		assert(Config.inCircle(6.5, 0, 0, 0, 6.5) and not Config.inCircle(6.51, 0, 0, 0, 6.5))
		local x, y, z = Config.arc(0, 3, 0, 20, 3, 0, 10, 0.5)
		near(x, 10); near(y, 13, "4 h t (1 - t) = h at the middle"); near(z, 0)
		local _, y0 = Config.arc(0, 3, 0, 20, 5, 0, 10, 0)
		local _, y1 = Config.arc(0, 3, 0, 20, 5, 0, 10, 1)
		near(y0, 3); near(y1, 5)
		local _, yc = Config.arc(0, 3, 0, 20, 5, 0, 10, 7)
		near(yc, 5, "t is clamped")
	end)

	case("NB3 Viper: spawn, stalk into 18 to 30 studs, then a 1.15 s windup before any dash", function()
		local e = Enc.new("Viper", "beast:1", 1, 0, { x = 0, y = 3, z = 60 })
		local _, by = run(e, 0, 6, standing(0, 0))
		assert(count(by, "Windup") >= 1, "a windup")
		local w = by.Windup[1]
		local d = Config.flat(w.origin.x, w.origin.z, 0, 0)
		assert(d >= V.attackMin - 1e-6 and d <= V.attackMax + 1e-6, "windup from 18 to 30 studs, got " .. d)
		assert(w.at >= V.spawnSeconds, "never during the spawn")
		near(w.dashAt - w.at, V.windup, "tell")
		near(w.lockAt - w.at, V.windup - V.lockLead, "lock")
		equal(w.length, 32); equal(w.width, 4.5)
		assert(by.Dash and by.Dash[1].at >= w.dashAt - 1e-6, "the dash starts at the end of the tell")
		if by.Hit then assert(by.Hit[1].at >= w.dashAt - 1e-6, "no damage before the tell ends") end
	end)

	case("NB3 Viper: staying in the lane is one 35 damage hit per dash", function()
		local e = viperInRange()
		local _, by = run(e, 0, 3, standing(0, 0))
		equal(count(by, "Dash"), 1, "one dash in 3 s")
		equal(count(by, "Hit"), 1)
		equal(by.Hit[1].damage, 35)
		local dash = by.Dash[1]
		assert(by.Hit[1].at >= dash.at and by.Hit[1].at <= dash.endAt + DT, "hit during the dash")
	end)

	case("NB3 Viper: the angle locks for the last 0.45 s; a sidestep after the lock dodges, and nothing re-aims", function()
		local e = viperInRange()
		local lockAt = V.spawnSeconds + V.windup - V.lockLead
		local _, by = run(e, 0, 3, standing(0, 0, function(now)
			if now >= lockAt + 0.1 then return 4, 0 end
		end))
		equal(count(by, "Lock"), 1)
		local lock = by.Lock[1]
		near(lock.dx, 0, "locked on the old spot", 1e-3); near(lock.dz, -1, "toward the origin", 1e-3)
		equal(count(by, "Hit"), 0, "stepped 4 studs to the side: out of a 4.5-stud lane")
		near(e.dx, lock.dx, "no homing after the lock"); near(e.dz, lock.dz)
	end)

	case("NB3 Viper: before the lock the lane follows the target", function()
		local e = viperInRange()
		local _, by = run(e, 0, V.spawnSeconds + 0.3, standing(10, 0))
		assert(count(by, "Windup") == 1 and count(by, "Lock") == 0, "inside the windup, not locked")
		local dx, dz = Config.unit(10 - 0, 0 - 25)
		near(e.dx, dx, "aims at the target", 1e-3); near(e.dz, dz, nil, 1e-3)
	end)

	case("NB3 Viper: the server hit uses the drawn width: 2.2 studs to the side is hit, 2.3 is not", function()
		for _, side in ipairs({ 2.2, 2.3 }) do
			local e = viperInRange()
			local lockAt = V.spawnSeconds + V.windup - V.lockLead
			local _, by = run(e, 0, 3, standing(0, 0, function(now)
				if now >= lockAt + 0.01 then return side, 0 end
			end))
			equal(count(by, "Hit"), side == 2.2 and 1 or 0, "side " .. side)
		end
	end)

	case("NB3 Viper: a wall cuts the dash: the lane is shortened at the lock, nothing is hit beyond it, longer recovery", function()
		local world = { castLane = function() return 12 end }
		local e = Enc.new("Viper", "beast:1", 1, 0, { x = 0, y = 3, z = 25 })
		local _, by = run(e, 0, 3.5, standing(0, 0), world)
		near(by.Lock[1].length, 11.5, "cut half a stud before the wall")
		equal(count(by, "Hit"), 0, "the target is 25 studs away, behind the wall")
		equal(by.Recover[1].crashed, true)
		near(by.Recover[1].untilAt - by.Recover[1].at, V.recoverCrash, "crash recovery")
	end)

	case("NB3 Viper: at most 3 attacks, then it disengages and ends", function()
		local e = viperInRange()
		local events, by = run(e, 0, 20, standing(0, 0))
		equal(count(by, "Dash"), 3)
		equal(count(by, "Hit"), 3, "one per dash")
		equal(by.Disengage[1].reason, "Done")
		equal(count(by, "End"), 1)
		equal(events[#events].type, "End")
		equal(#Enc.step(e, 21, standing(0, 0)(21), OPEN), 0, "nothing after the end")
	end)

	case("NB3 Viper: escape at 100 studs for 4 s, and the 32 s limit", function()
		local e = Enc.new("Viper", "beast:1", 1, 0, { x = 0, y = 3, z = 25 })
		local _, by = run(e, 0, 6, standing(0, 300))
		equal(by.Disengage and by.Disengage[1].reason, "Escape")
		assert(by.Disengage[1].at >= 4 - 1e-6, "after 4 s away")
		-- A target the beast never reaches: stalking ends, and at worst the clock ends the encounter.
		local slow = Enc.new("Viper", "beast:2", 1, 0, { x = 0, y = 3, z = 25 })
		local _, by2 = run(slow, 0, 40, standing(0, 0, function(now) return 0, -now * 0.1 end), { castLane = function() return 0.2 end })
		assert(by2.End, "it ends")
		assert(by2.End[1].at <= V.maxSeconds + V.disengage + 2 * DT, "within the 32 s limit plus the retreat")
	end)

	case("NB3 Viper: entering a safe zone or dying ends it at once, with no late hit", function()
		local lockAt = V.spawnSeconds + V.windup - V.lockLead
		for _, why in ipairs({ "SafeZone", "Death" }) do
			local e = viperInRange()
			local _, by = run(e, 0, 3, standing(0, 0, function(now)
				if now >= lockAt then return nil, nil, why == "SafeZone" and { safe = true } or { alive = false } end
			end))
			equal(count(by, "Hit"), 0, why)
			equal(by.End and by.End[1].reason, why)
			equal(count(by, "Disengage"), 0, why .. " skips the retreat")
		end
	end)

	case("NB3: finish is idempotent and cleanup is one End", function()
		local e = viperInRange()
		local first = Enc.finish(e, "Leave", 1)
		equal(first.type, "End"); equal(first.reason, "Leave")
		equal(Enc.finish(e, "Error", 2), nil)
		equal(e.done, true); equal(e.endReason, "Leave")
		equal(#Enc.step(e, 3, standing(0, 0)(3), OPEN), 0)
	end)

	case("NB3 Pouncer: a 6.5-stud circle, its centre frozen after 0.25 s, a 1.3 s telegraph then a 0.75 s leap", function()
		local e = Enc.new("Pouncer", "beast:3", 1, 0, { x = 0, y = 3, z = 25 })
		local _, by = run(e, 0, 1.2, standing(0, 0))
		equal(count(by, "Telegraph"), 1)
		local t = by.Telegraph[1]
		equal(t.radius, 6.5)
		near(t.freezeAt - t.at, 0.25); near(t.leapAt - t.at, 1.3); near(t.landAt - t.leapAt, 0.75)
		equal(count(by, "Freeze"), 1)
		-- After the freeze the target walks away: the centre stays.
		local f = by.Freeze[1]
		local e2 = Enc.new("Pouncer", "beast:4", 1, 0, { x = 0, y = 3, z = 25 })
		local _, by2 = run(e2, 0, 3, standing(0, 0, function(now)
			if now >= f.at + 0.1 then return 9, 0 end
		end))
		near(by2.Leap[1].to.x, by2.Freeze[1].center.x, "the leap aims at the frozen centre"); near(by2.Leap[1].to.z, by2.Freeze[1].center.z)
		near(e2.center.x, by2.Freeze[1].center.x, "never recentred")
		equal(count(by2, "Hit"), 0, "9 studs out of a 6.5 circle: no damage")
		equal(by2.Land[1].hit, false)
	end)

	case("NB3 Pouncer: before the freeze the circle follows the target's predicted spot", function()
		local e = Enc.new("Pouncer", "beast:3", 1, 0, { x = 0, y = 3, z = 25 })
		run(e, 0, P.spawnSeconds + 0.1, standing(0, 0))
		assert(e.phase == "Telegraph", "telegraphing, got " .. tostring(e.phase))
		Enc.step(e, P.spawnSeconds + 0.15, { x = 2, y = 3, z = 0, vx = 10, vz = 0, alive = true, safe = false }, OPEN)
		near(e.center.x, 2 + 10 * P.predictSeconds, "current + velocity x 0.3 s")
	end)

	case("NB3 Pouncer: staying inside is one 40 damage hit at the landing, timed by the server", function()
		local e = Enc.new("Pouncer", "beast:3", 1, 0, { x = 0, y = 3, z = 25 })
		local _, by = run(e, 0, 2.95, standing(0, 0))
		equal(count(by, "Land"), 1)
		equal(count(by, "Hit"), 1); equal(by.Hit[1].damage, 40)
		assert(by.Hit[1].at >= by.Telegraph[1].landAt - 1e-6, "never before the landing")
		near(e.pos.x, by.Telegraph[1].center.x, "it landed on the centre")
	end)

	case("NB3 Pouncer: mid-leap the body follows the server's parabola", function()
		local e = Enc.new("Pouncer", "beast:3", 1, 0, { x = 0, y = 3, z = 25 })
		local _, by = run(e, 0, 2.2, standing(0, 0))
		local leap = by.Leap[1]
		local mid = leap.at + P.flight / 2
		Enc.step(e, mid, { x = 0, y = 3, z = 0, vx = 0, vz = 0, alive = true, safe = false }, OPEN)
		local x, y, z = Config.arc(leap.from.x, leap.from.y, leap.from.z, leap.to.x, leap.to.y, leap.to.z, P.arcHeight, 0.5)
		near(e.pos.x, x, "x", 1e-6); near(e.pos.y, y, "y", 1e-6); near(e.pos.z, z, "z", 1e-6)
	end)

	case("NB3 Pouncer: no valid landing (void, wall, safe zone): no circle, then it gives up cleanly", function()
		local world = { landing = function() return nil end }
		local e = Enc.new("Pouncer", "beast:3", 1, 0, { x = 0, y = 3, z = 25 })
		local _, by = run(e, 0, 6, standing(0, 0), world)
		equal(count(by, "Telegraph"), 0)
		assert(count(by, "Cancel") >= 1, "a cancelled choice")
		equal(by.Disengage and by.Disengage[1].reason, "NoLanding")
		local blocked = { arcClear = function() return false end }
		local e2 = Enc.new("Pouncer", "beast:4", 1, 0, { x = 0, y = 3, z = 25 })
		local _, by2 = run(e2, 0, 6, standing(0, 0), blocked)
		equal(count(by2, "Leap"), 0, "a blocked arc never leaps")
		equal(count(by2, "Hit"), 0)
	end)

	case("NB3 Pouncer: two jumps, a recovery between them, then it leaves", function()
		local e = Enc.new("Pouncer", "beast:3", 1, 0, { x = 0, y = 3, z = 25 })
		local events, by = run(e, 0, 15, standing(0, 0))
		equal(count(by, "Leap"), 2)
		equal(count(by, "Hit"), 2, "one per jump")
		assert(by.Telegraph[2].at >= by.Land[1].at + P.recover - 1e-6, "the second circle waits for the recovery")
		equal(by.Disengage[1].reason, "Done")
		equal(events[#events].type, "End")
	end)

	case("NB3 Pouncer: a safe zone before the landing cancels the hit and ends it", function()
		local e = Enc.new("Pouncer", "beast:3", 1, 0, { x = 0, y = 3, z = 25 })
		local _, by = run(e, 0, 3, standing(0, 0, function(now)
			if now >= 1.8 then return nil, nil, { safe = true } end
		end))
		equal(count(by, "Hit"), 0)
		equal(by.End[1].reason, "SafeZone")
	end)

	case("NB3: the state machines and the geometry are pure", function()
		for _, banned in ipairs({ "game:", "workspace", "task.", "os.clock", "os.time", "math.random", "Random.new", "Touched" }) do
			assert(not source:find(banned, 1, true), "encounters use " .. banned)
			assert(not configSource:find(banned, 1, true), "config uses " .. banned)
		end
	end)

	return result
end

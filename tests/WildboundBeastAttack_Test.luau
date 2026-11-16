-- Invoke with require(freshTestClone)(require(freshBeastAttackClone), require(freshBeastConfigClone),
-- freshBeastAttackClone.Source).
-- Wave 2 (odd/tasks/wildbound-beasts-wave2.md, BW2-4): the shared attack layer and the shared shapes. One attack is one
-- telegraph and exactly one outcome; the dodge is asked once; closeAll leaves nothing open; the stagger waits. Pure.
return function(Attack, Config, source)
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
	local function near(actual, expected, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= 1e-6,
			(label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function fakeWorld()
		local w = { telegraphs = {}, resolved = {}, cancelled = {}, verdict = "Hit", claims = {} }
		function w.telegraph(id, beast, startAt, strikeAt)
			table.insert(w.telegraphs, id)
			return strikeAt - startAt >= 0.8 - 1e-9
		end
		function w.resolve(id) table.insert(w.resolved, id); return w.verdict end
		function w.cancel(id) table.insert(w.cancelled, id) end
		return w
	end
	local function encounter(id) return { id = id, beast = "Streamer", open = {}, startedAt = 0, phase = "Pursue",
		pos = { x = 0, y = 0, z = 0 }, dx = 0, dz = 1 } end
	local circle = { kind = "circle", x = 0, y = 0, z = 0, r = 5 }

	case("BW2 attack: open registers a dodgeable telegraph and emits the tell with the exact shape", function()
		local w, e, events = fakeWorld(), encounter("beast:1"), {}
		local attack = Attack.open(events, e, w, { key = "rush", startAt = 10, strikeAt = 11, shape = circle, dodgeable = true,
			damage = 20 })
		equal(attack.id, "beast:1:rush:1")
		equal(w.telegraphs[1], attack.id); equal(attack.registered, true)
		equal(events[1].type, "Tell"); equal(events[1].shape, circle); equal(events[1].strikeAt, 11)
		equal(e.open[attack.id], attack)
		local short = Attack.open(events, e, w, { key = "short", startAt = 10, strikeAt = 10.5, shape = circle, dodgeable = true })
		equal(short.registered, false, "a telegraph under 0.8 s cannot be dodged")
	end)

	case("BW2 attack: hit asks the dodge once and lands once; a second call is a no-op", function()
		local w, e, events = fakeWorld(), encounter("beast:2"), {}
		local attack = Attack.open(events, e, w, { key = "a", startAt = 0, strikeAt = 1, shape = circle, dodgeable = true, damage = 9 })
		equal(Attack.hit(events, e, w, attack, 1, { slow = { multiplier = 0.5, seconds = 1 } }), "Hit")
		equal(Attack.hit(events, e, w, attack, 1.05), nil, "settled")
		equal(Attack.miss(events, e, w, attack, 1.1), nil, "settled")
		equal(#w.resolved, 1)
		local hits = 0
		for _, ev in ipairs(events) do
			if ev.type == "Hit" then
				hits += 1
				equal(ev.damage, 9); equal(ev.attack, attack.id); equal(ev.slow.multiplier, 0.5)
			end
		end
		equal(hits, 1)
		equal(e.open[attack.id], nil, "closed")
	end)

	case("BW2 attack: a perfect dodge cancels the damage; a miss cancels the registration", function()
		local w, e, events = fakeWorld(), encounter("beast:3"), {}
		w.verdict = "Dodged"
		local a = Attack.open(events, e, w, { key = "a", startAt = 0, strikeAt = 1, shape = circle, dodgeable = true, damage = 9 })
		equal(Attack.hit(events, e, w, a, 1), "Dodged")
		for _, ev in ipairs(events) do assert(ev.type ~= "Hit", "no damage after a perfect dodge") end
		local b = Attack.open(events, e, w, { key = "b", startAt = 2, strikeAt = 3, shape = circle, dodgeable = true, damage = 9 })
		equal(Attack.miss(events, e, w, b, 3), "Miss")
		equal(w.cancelled[1], b.id)
		local c = Attack.open(events, e, w, { key = "c", startAt = 4, strikeAt = 5, shape = circle, dodgeable = false, damage = 9 })
		equal(Attack.hit(events, e, w, c, 5), "Hit")
		equal(#w.resolved, 1, "an undodgeable attack never asks the dodge")
	end)

	case("BW2 attack: closeAll cancels every open attack once and is idempotent", function()
		local w, e, events = fakeWorld(), encounter("beast:4"), {}
		local a = Attack.open(events, e, w, { key = "a", startAt = 0, strikeAt = 1, shape = circle, dodgeable = true })
		local b = Attack.open(events, e, w, { key = "b", startAt = 0, strikeAt = 1.2, shape = circle, dodgeable = true })
		local ids = Attack.openIds(e)
		equal(#ids, 2)
		Attack.closeAll(e, w)
		Attack.closeAll(e, w)
		equal(#w.cancelled, 2, "once each")
		equal(#Attack.openIds(e), 0)
		equal(Attack.hit(events, e, w, a, 1), nil, "no hit after the end")
		equal(Attack.miss(events, e, w, b, 1.2), nil)
	end)

	case("BW2 attack: the stagger refuses a strike too close to another encounter's, and the caller retries", function()
		local w, e, events = fakeWorld(), encounter("beast:5"), {}
		local taken = { at = 10, enc = "beast:other" }
		function w.claimStrike(encId, _, strikeAt)
			return not (encId ~= taken.enc and math.abs(strikeAt - taken.at) < Config.DIRECTOR.STRIKE_SEPARATION)
		end
		local attack, why = Attack.open(events, e, w, { key = "a", startAt = 9, strikeAt = 10.5, shape = circle, dodgeable = true })
		equal(attack, nil); equal(why, "Stagger")
		equal(#events, 0, "no tell for a refused attack"); equal(#w.telegraphs, 0, "no registration")
		attack = Attack.open(events, e, w, { key = "a", startAt = 9.1, strikeAt = 10.85, shape = circle, dodgeable = true })
		assert(attack, "0.85 s apart is allowed")
		equal(attack.id, "beast:5:a:1", "the refused try did not use a number")
	end)

	case("BW2 attack: aim re-sends at most every 0.1 s until locked; lock freezes the shape", function()
		local w, e, events = fakeWorld(), encounter("beast:6"), {}
		local attack = Attack.open(events, e, w, { key = "a", startAt = 0, strikeAt = 1, shape = circle, dodgeable = true })
		Attack.aim(events, e, attack, { kind = "circle", x = 1, y = 0, z = 0, r = 5 }, 0.05)
		Attack.aim(events, e, attack, { kind = "circle", x = 2, y = 0, z = 0, r = 5 }, 0.1)
		Attack.aim(events, e, attack, { kind = "circle", x = 3, y = 0, z = 0, r = 5 }, 0.15)
		local tells = 0
		for _, ev in ipairs(events) do if ev.type == "Tell" then tells += 1 end end
		equal(tells, 2, "the open and one re-aim inside 0.15 s")
		Attack.lock(events, e, attack, nil, 0.75)
		Attack.aim(events, e, attack, { kind = "circle", x = 9, y = 0, z = 0, r = 5 }, 0.8)
		equal(attack.shape.x, 3, "locked: no re-aim")
		equal(events[#events].locked, true)
	end)

	case("BW2 attack: guard ends on death and safe zone at once, retreats on escape and timeout", function()
		local e, events = encounter("beast:7"), {}
		equal(Attack.guard(events, e, 1, nil, {}), true); equal(events[1].reason, "Death")
		e, events = encounter("beast:8"), {}
		equal(Attack.guard(events, e, 1, { x = 0, y = 0, z = 0, alive = true, safe = true }, {}), true)
		equal(events[1].reason, "SafeZone")
		-- Escape and timeout are for the non-persistent beasts (Scuttler here); BR0 covers the six persistent ones below.
		e, events = encounter("beast:9"), {}
		e.beast = "Scuttler"
		local far = { x = 200, y = 0, z = 0, alive = true, safe = false }
		equal(Attack.guard(events, e, 1, far, { escapeDistance = 100, escapeSeconds = 4 }), false)
		equal(Attack.guard(events, e, 5, far, { escapeDistance = 100, escapeSeconds = 4 }), true)
		equal(events[1].type, "Disengage"); equal(events[1].reason, "Escape")
		e, events = encounter("beast:10"), {}
		e.beast = "Scuttler"
		local near0 = { x = 1, y = 0, z = 0, alive = true, safe = false }
		equal(Attack.guard(events, e, 45, near0, { timeout = 45, busy = true }), false, "a busy phase finishes first")
		equal(Attack.guard(events, e, 45.05, near0, { timeout = 45 }), true)
		equal(events[1].reason, "Timeout")
		equal(Attack.guard(events, e, 46, near0, { timeout = 45 }), true)
		equal(events[#events].type, "End", "the retreat ends")
	end)

	case("BR0 attack: a persistent beast never escapes or times out; death and a safe zone still end it", function()
		for _, name in ipairs({ "Streamer", "Root", "Gaze", "Lurker" }) do
			local e, events = encounter("beast:p" .. name), {}
			e.beast = name
			local far = { x = 500, y = 0, z = 0, alive = true, safe = false }
			for t = 0, 120, 5 do
				equal(Attack.guard(events, e, t, far, { escapeDistance = 100, escapeSeconds = 4, timeout = 45 }), false, name .. " at " .. t)
			end
			equal(#events, 0, name .. ": no retreat")
			far.safe = true
			equal(Attack.guard(events, e, 121, far, { timeout = 45 }), true)
			equal(events[1].type, "End"); equal(events[1].reason, "SafeZone")
		end
	end)

	case("BR0 attack: a persistent beast far behind walks at the catch-up speed, a near one at its own", function()
		local e = encounter("beast:walk")
		local tgt = { x = 0, y = 0, z = 200 }
		Attack.walk(e, tgt, 12, 1, 1, {})
		assert(math.abs(e.pos.z - 20) < 1e-6, "20 studs in 1 s, got " .. e.pos.z)
		e.pos.z = 190
		Attack.walk(e, tgt, 12, 1, 0.5, {})
		assert(math.abs(e.pos.z - 196) < 1e-6, "own 12 studs/s when near, got " .. e.pos.z)
		local s = encounter("beast:walk2")
		s.beast = "Scuttler"
		Attack.walk(s, tgt, 12, 1, 1, {})
		assert(math.abs(s.pos.z - 12) < 1e-6, "Scuttler keeps its own speed")
	end)

	case("BW2 shapes: sector, lanes and the enclosure are the drawn volumes", function()
		equal(Config.inSector(0, 10, 0, 0, 0, 1, 16, 125), true, "ahead")
		equal(Config.inSector(10, 6, 0, 0, 0, 1, 16, 125), true, "59 degrees off is inside a 125 degree arc")
		equal(Config.inSector(10, 3, 0, 0, 0, 1, 16, 125), false, "73 degrees off is outside")
		equal(Config.inSector(0, 17, 0, 0, 0, 1, 16, 125), false, "past the radius")
		local lanes = Config.rootLanes(0, 0, -20, 0, 0, 3, 20, 4, 34)
		equal(#lanes.list, 3)
		near(lanes.list[2].dz, 1, "the middle lane points at the target")
		equal(lanes.list[1].length, 24, "the target's distance plus a lane width")
		equal(Config.shapeHit(lanes, 0, 0), true); equal(Config.shapeHit(lanes, 3, 0), false, "between the lanes")
		local walls = Config.enclosure(0, 0, 0, 0, 1, 9, 9)
		near(Config.gapWidth(walls), 9, "the gap is the requested width")
		equal(Config.shapeHit(walls, 0, 0), false, "walls never hit")
		equal(Config.enclosure(0, 0, 0, 0, 1, 4, 9), nil, "a gap wider than the ring is refused")
		equal(Config.shapeHit({ kind = "lane", ox = 0, oy = 0, oz = 0, dx = 0, dz = 1, length = 10, width = 4 }, 1.9, 5), true)
		equal(Config.shapeHit({ kind = "lane", ox = 0, oy = 0, oz = 0, dx = 0, dz = 1, length = 10, width = 4 }, 2.1, 5), false)
	end)

	-- SC2 (odd/tasks/wildbound-scuttler.md): a non-damaging outcome. Same dodge resolution as Attack.hit, but it emits
	-- Strike + Afflict and never Hit, so the beast script can slow and shake without reaching BeastHit (egg drop).
	local function count(events, kind)
		local n = 0
		for _, ev in ipairs(events) do if ev.type == kind then n += 1 end end
		return n
	end
	local function find(events, kind)
		for _, ev in ipairs(events) do if ev.type == kind then return ev end end
		return nil
	end

	case("SC2 afflict: a landed affliction emits Strike + Afflict with the fields, never Hit", function()
		assert(type(Attack.afflict) == "function", "Attack.afflict exists")
		local w, e, events = fakeWorld(), encounter("beast:20"), {}
		e.beast = "Scuttler"
		local attack = Attack.open(events, e, w, { key = "pulse", startAt = 0, strikeAt = 1, shape = circle, dodgeable = true })
		local slow = { multiplier = 0.55, seconds = 2.5 }
		equal(Attack.afflict(events, e, w, attack, 1, { slow = slow, shake = true }), "Afflicted")
		equal(count(events, "Hit"), 0, "an affliction never emits Hit")
		equal(count(events, "Strike"), 1); equal(count(events, "Afflict"), 1)
		local strike, afflict = find(events, "Strike"), find(events, "Afflict")
		equal(strike.tell, attack.id); equal(strike.hit, true); equal(strike.dodged, nil)
		equal(afflict.attack, attack.id); equal(afflict.beast, "Scuttler"); equal(afflict.at, 1)
		equal(afflict.slow, slow); equal(afflict.shake, true)
		equal(afflict.damage, nil, "an affliction carries no damage")
		equal(#w.resolved, 1, "the dodge is asked once")
		equal(e.open[attack.id], nil, "closed")
	end)

	case("SC2 afflict: a perfect dodge cancels the effect (dodged Strike, no Afflict, no Hit)", function()
		local w, e, events = fakeWorld(), encounter("beast:21"), {}
		w.verdict = "Dodged"
		local attack = Attack.open(events, e, w, { key = "pulse", startAt = 0, strikeAt = 1, shape = circle, dodgeable = true })
		equal(Attack.afflict(events, e, w, attack, 1, { slow = { multiplier = 0.55, seconds = 2.5 } }), "Dodged")
		equal(count(events, "Afflict"), 0); equal(count(events, "Hit"), 0)
		local strike = find(events, "Strike")
		equal(strike.hit, false); equal(strike.dodged, true)
		equal(#w.resolved, 1)
	end)

	case("SC2 afflict: one outcome only; afflict, hit and miss after it are no-ops", function()
		local w, e, events = fakeWorld(), encounter("beast:22"), {}
		local a = Attack.open(events, e, w, { key = "pulse", startAt = 0, strikeAt = 1, shape = circle, dodgeable = true })
		equal(Attack.afflict(events, e, w, a, 1), "Afflicted")
		equal(Attack.afflict(events, e, w, a, 1.05), nil, "settled")
		equal(Attack.hit(events, e, w, a, 1.05), nil, "settled")
		equal(Attack.miss(events, e, w, a, 1.1), nil, "settled")
		equal(count(events, "Afflict"), 1); equal(count(events, "Strike"), 1); equal(count(events, "Hit"), 0)
		equal(#w.resolved, 1); equal(#w.cancelled, 0)
		local b = Attack.open(events, e, w, { key = "pulse", startAt = 2, strikeAt = 3, shape = circle, dodgeable = true, damage = 0 })
		equal(Attack.hit(events, e, w, b, 3), "Hit")
		equal(Attack.afflict(events, e, w, b, 3), nil, "a hit attack cannot also afflict")
		local c = Attack.open(events, e, w, { key = "pulse", startAt = 4, strikeAt = 5, shape = circle, dodgeable = true })
		equal(Attack.miss(events, e, w, c, 5), "Miss")
		equal(Attack.afflict(events, e, w, c, 5), nil, "a missed attack cannot afflict")
		equal(count(events, "Afflict"), 1)
	end)

	case("SC2 afflict: undodgeable never asks the dodge; nothing afflicts after closeAll", function()
		local w, e, events = fakeWorld(), encounter("beast:23"), {}
		local a = Attack.open(events, e, w, { key = "pulse", startAt = 0, strikeAt = 1, shape = circle, dodgeable = false })
		equal(Attack.afflict(events, e, w, a, 1), "Afflicted")
		equal(#w.resolved, 0, "an undodgeable attack never asks the dodge")
		local short = Attack.open(events, e, w, { key = "pulse", startAt = 2, strikeAt = 2.5, shape = circle, dodgeable = true })
		equal(short.registered, false)
		local b = Attack.open(events, e, w, { key = "pulse", startAt = 3, strikeAt = 4, shape = circle, dodgeable = true })
		Attack.closeAll(e, w)
		equal(Attack.afflict(events, e, w, b, 4), nil, "no affliction after the end")
		equal(count(events, "Afflict"), 1); equal(count(events, "Hit"), 0)
	end)

	case("BW2 attack: the layer is pure", function()
		for _, banned in ipairs({ "workspace", "game:", "task.", "os.clock", "math.random", "Random.new", "Touched" }) do
			assert(not source:find(banned, 1, true), "source uses " .. banned)
		end
	end)

	return result
end

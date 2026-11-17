-- Invoke with require(freshTestClone)(require(freshCandyDuquesaClone), require(freshCandyFrutillonClone),
--   require(freshCandyLayoutClone), { service = <WildboundCandyDuquesaService Source>,
--   anim = <WildboundCandyCritterAnim Source> }, require(freshBeastChaseClone), require(freshWorldRulesClone)).
-- A2 (odd/tasks/wildbound-caramelo-playfix.md): La Duquesa Burbuja stays seated on the Gran Torta's summit, but while a
-- player stands on the summit she throws "Bombas de chicle" (pack 6 sheet 01) every 10 s: three slow bubbles that pop
-- in small circles (each ring drawn on the floor from her windup, at least MIN_TELL before the pop); whoever is inside
-- a pop is slowed -30 % for 2 s and pushed 4 studs, once per volley. She plays her Charge and Whip clips. Damage 0.
-- Pure rules plus source pins of the service and the client animator. Changes nothing.
-- DR (owner request 2026-11-16): her rage when her own egg (the summit nest's) is stolen: red, a roar, a fast flying
-- chase, dodgeable lunges that hurt and drop her egg, its end conditions, her cooldown, and the escape math.
-- RC6 (owner request 2026-11-16, "they keep chasing you until you reach the base"): her rage no longer ends at the plot's
-- edge nor after 25 s; it lasts until the thief is safe (the hub, from WildboundWorldRules), dead, gone or without her
-- egg, with a 180 s safety end, and calmed outside the plot she vanishes back to her seat.
-- V4-D10 (owner request 2026-11-17): her scenery model sits on the moved summit (Duq.seatPivot), corrected at start.
return function(Duq, Frut, Layout, sources, Chase, Rules)
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
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-3),
			(label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function has(source, needle, label)
		assert(type(source) == "string" and string.find(source, needle, 1, true), (label or "missing") .. ": " .. needle)
	end
	local function each(events, kind)
		local out = {}
		for _, ev in ipairs(events) do if ev.kind == kind then table.insert(out, ev) end end
		return out
	end
	assert(type(Duq) == "table" and type(Frut) == "table" and type(Layout) == "table", "pass Duquesa, Frutillon and Layout")
	local summit = Frut.summit(Layout)
	-- A player on the summit, `dx` studs east of La Duquesa's seat (the summit's centre).
	local function onTop(dx, id) return { id = id or 1, alive = true, x = summit.x + dx, y = summit.top + 3, z = summit.z } end
	local function below(id) return { id = id or 2, alive = true, x = summit.x + 30, y = Layout.FLOOR_TOP + 3, z = summit.z } end
	local function run(state, from, to, players)
		local all = {}
		for i = 0, math.floor((to - from) / 0.1 + 1e-6) do
			local t = from + i * 0.1
			local list = type(players) == "function" and players(t) or players
			for _, ev in ipairs(Duq.step(state, t, list, summit)) do ev.t = t; table.insert(all, ev) end
		end
		return all
	end

	case("A2 numbers: three bubbles every 10 s, a tell of at least MIN_TELL, slow -30 % for 2 s, push 4, damage 0", function()
		equal(Duq.EVERY_SECONDS, 6, "every") -- Deliberately changed (OF3, a hard summit): 10 -> 6 s
		equal(Duq.BUBBLES, 3, "bubbles"); equal(Duq.DAMAGE, 0, "damage")
		near(Duq.SLOW_MULTIPLIER, 0.7, "slow"); near(Duq.SLOW_SECONDS, 2, "slow time"); near(Duq.PUSH_STUDS, 4, "push")
		assert(Duq.WINDUP_SECONDS + Duq.FLIGHT_SECONDS >= 0.8, "the ring shows at least 0.8 s before the pop")
		assert(Duq.FLIGHT_SECONDS >= 1, "the bubbles fly slowly")
		-- walked Play (A2): Frutillon bumped the climber off the summit about 1.5 s after arriving, before her first
		-- volley; she reacts at once
		assert(Duq.FIRST_SECONDS <= 0.5, "the first volley comes " .. Duq.FIRST_SECONDS .. " s after a player arrives")
		assert(Duq.POP_RADIUS_STUDS >= 2.5 and Duq.POP_RADIUS_STUDS <= 4.5, "small circles")
		if Chase then
			assert(Duq.SLOW_MULTIPLIER >= Chase.EFFECTS.slowMinMultiplier, "inside the shared slow cap")
			assert(Duq.SLOW_SECONDS <= Chase.EFFECTS.slowMaxSeconds, "inside the shared slow time cap")
		end
	end)

	case("A2: nobody on the summit (or only below it): she stays seated, no bubbles", function()
		local state = Duq.new()
		equal(#run(state, 0, 30, {}), 0, "empty")
		equal(#run(state, 30, 60, { below() }), 0, "a player below the summit")
	end)

	case("A2: a player reaches the summit: Charge with three rings, Whip, three pops; a hit once; again 10 s later", function()
		local state = Duq.new()
		local p = onTop(5)
		local events = run(state, 0, 14, function(t) return t >= 2 and { p } or { below() } end)
		local charges, throws, pops, hits = each(events, "Charge"), each(events, "Throw"), each(events, "Pop"), each(events, "Hit")
		assert(charges[1], "no Charge after reaching the summit")
		assert(charges[1].t >= 2 and charges[1].t <= 2 + Duq.FIRST_SECONDS + 0.11, "first volley at " .. charges[1].t)
		equal(#charges[1].spots, Duq.BUBBLES, "three rings")
		near(charges[1].spots[1].x, p.x, "one bubble on the player"); near(charges[1].spots[1].z, p.z, "z")
		for i, s in ipairs(charges[1].spots) do
			near(s.y, summit.top, "ring on the summit floor " .. i)
			if i > 1 then near(math.sqrt((s.x - p.x) ^ 2 + (s.z - p.z) ^ 2), Duq.SPREAD_STUDS, "side bubble " .. i) end
		end
		assert(throws[1] and throws[1].volley == charges[1].volley, "no Whip")
		near(throws[1].t - charges[1].t, Duq.WINDUP_SECONDS, "the Whip after the windup", 0.11)
		local first = {}
		for _, pop in ipairs(pops) do if pop.volley == charges[1].volley then table.insert(first, pop) end end
		equal(#first, Duq.BUBBLES, "three pops")
		assert(first[1].t - charges[1].t >= 0.8 - 1e-6, "the pop came " .. (first[1].t - charges[1].t) .. " s after its ring")
		local mine = {}
		for _, hit in ipairs(hits) do if hit.volley == charges[1].volley then table.insert(mine, hit) end end
		equal(#mine, 1, "a player inside a pop is hit once per volley")
		equal(mine[1].id, p.id, "the hit player"); near(mine[1].slow, Duq.SLOW_MULTIPLIER, "slow")
		near(mine[1].slowSeconds, Duq.SLOW_SECONDS, "slow time"); near(mine[1].studs, Duq.PUSH_STUDS, "push")
		near(math.sqrt(mine[1].dx ^ 2 + mine[1].dz ^ 2), 1, "a unit push direction"); equal(mine[1].damage, nil, "no damage field")
		assert(charges[2], "no second volley while the player stays")
		near(charges[2].t - charges[1].t, Duq.EVERY_SECONDS, "every 10 s", 0.11)
	end)

	case("A2: outside every pop circle nobody is hit; leaving the summit stops the volleys", function()
		local state = Duq.new()
		local p = onTop(5)
		local q = onTop(-6, 3) -- across the summit, far from every bubble aimed at p
		local events = run(state, 0, 5, { p, q })
		for _, hit in ipairs(each(events, "Hit")) do assert(hit.id ~= q.id, "a player outside every pop was hit") end
		local after = run(state, 5.1, 40, { below() })
		local charges = each(after, "Charge")
		equal(#charges, 0, "a volley with nobody on the summit")
	end)

	-- A2 review (walked Play): Frutillon rolled a climber off 0.8 s after arriving and her first pops (1.8 s after the
	-- Charge) found nobody. A climber walking onto the summit next to Frutillon's rest spot (his fastest bump) feels her
	-- first pop before his first roll can start.
	case("A2 review: a climber's first pop on the summit lands before Frutillon's first roll", function()
		local frut, duq = Frut.new(0, summit), Duq.new()
		local p = { id = 4, alive = true, x = summit.x + math.cos(Frut.REST_ANGLE) * Frut.RING_STUDS, y = summit.top + 3,
			z = summit.z + math.sin(Frut.REST_ANGLE) * Frut.RING_STUDS }
		local popAt, hitAt, rollAt
		local t = 2
		while t <= 8 and not rollAt do
			for _, ev in ipairs(Duq.step(duq, t, { p }, summit)) do
				if ev.kind == "Pop" then popAt = popAt or t end
				if ev.kind == "Hit" and ev.id == p.id then hitAt = hitAt or t end
			end
			for _, ev in ipairs(Frut.step(frut, t, { p }, summit)) do
				if ev.kind == "Roll" then rollAt = ev.at end
			end
			t += 0.05
		end
		assert(popAt and hitAt, "her first pop never hit the climber")
		assert(rollAt, "Frutillon never rolled")
		assert(hitAt + 0.3 <= rollAt + 1e-6, "her first pop at " .. hitAt .. " s, his first roll at " .. rollAt .. " s")
	end)

	case("A2 review: a short drop off the summit keeps her 10 s cadence; a long absence starts it again", function()
		local state = Duq.new()
		local p = onTop(5)
		-- on the summit 0-3 s, bumped down 3-5 s, back from 5 s
		local events = run(state, 0, 14, function(t) return (t < 3 or t >= 5) and { p } or { below() } end)
		local charges = each(events, "Charge")
		assert(charges[1] and charges[1].t <= Duq.FIRST_SECONDS + 0.11, "no first volley")
		assert(charges[2], "no second volley after climbing back")
		near(charges[2].t - charges[1].t, Duq.EVERY_SECONDS, "a short drop restarted the cadence", 0.11)
		-- away longer than REARM_SECONDS: she greets the next arrival at once again
		assert(type(Duq.REARM_SECONDS) == "number" and Duq.REARM_SECONDS >= 3 and Duq.REARM_SECONDS < Duq.EVERY_SECONDS, "REARM_SECONDS")
		local s2 = Duq.new()
		local away = 1 + Duq.REARM_SECONDS + 1
		local later = run(s2, 0, away + 3, function(t) return (t < 1 or t >= away) and { p } or { below() } end)
		local back
		for _, c in ipairs(each(later, "Charge")) do if c.t >= away then back = back or c end end
		assert(back and back.t <= away + Duq.FIRST_SECONDS + 0.11, "a fresh arrival waited for the old cadence")
	end)

	case("A2 wiring: the service throws on the summit through the beasts' slow and push slots; she plays Charge and Whip", function()
		local service, anim = sources and sources.service, sources and sources.anim
		has(service, 'require(ServerStorage:WaitForChild("WildboundCandyDuquesa"))', "the pure rules")
		has(service, "Frut.summit(Layout)", "the same summit as Frutillon")
		has(service, 'WaitForChild("WildboundNewCandyPreview"', "her seated model")
		has(service, 'SetAttribute("WildboundCritterCue", clip .. ":" .. volley)', "her clip cue")
		has(service, '"Charge"', "Charge"); has(service, '"Whip"', "Whip")
		has(service, "Chase.clampSlow(", "the shared slow cap")
		has(service, '"WildboundBeastSlowUntil"', "the one non-stacking slow slot")
		has(service, '"WildboundBeastPush"', "the one push slot")
		-- Deliberately re-pinned (DR): her rage lunge hurts, but only through the inventory server's BeastHit (DR9)
		assert(not string.find(service, "TakeDamage", 1, true) and not string.find(service, "%.Health%s*[-=]"), "no damage of its own")
		has(anim, 'GetAttributeChangedSignal("WildboundCritterCue")', "the preview animator plays a cued one-shot")
	end)

	-- DR: her rage. Every position comes from the layout (the Torta may move).
	local THIEF = 7
	local nestX, nestZ = Layout.CENTRE.x + Layout.TOWER.summit.x, Layout.CENTRE.z + Layout.TOWER.summit.z
	local function carrier(x, y, z, fields)
		local p = { id = THIEF, alive = true, x = x, y = y, z = z, carriesHerEgg = true, speed = 11 }
		for key, value in pairs(fields or {}) do p[key] = value end
		return p
	end
	local function atNest() return carrier(nestX, summit.top + 3, nestZ) end
	-- a carrier standing on the plot floor `west` studs west of the Torta
	local function onFloor(west, fields) return carrier(summit.x - west, Layout.FLOOR_TOP + 3, summit.z, fields) end
	-- steps every 0.1 s on whole tenths (t = i * 0.1), so consecutive calls never repeat a step
	local function steps(state, from, to, players, resolve)
		local all = {}
		for i = math.floor(from / 0.1 + 0.5), math.floor(to / 0.1 + 0.5) do
			local t = i * 0.1
			local list = type(players) == "function" and players(t) or players
			for _, ev in ipairs(Duq.step(state, t, list, summit, resolve)) do ev.t = t; table.insert(all, ev) end
		end
		return all
	end
	local function firstOf(events, kind, test)
		for _, ev in ipairs(events) do
			if ev.kind == kind and (not test or test(ev)) then return ev end
		end
		return nil
	end
	local function dodgeAll() return "Dodged" end

	case("DR1: stealing her egg starts the rage against that thief only; never another egg, a safe or an outside carrier", function()
		equal(Duq.herIsland(Layout), "CandyT1", "her island")
		local state = Duq.new()
		local rage = firstOf(steps(state, 0, 0, { atNest() }), "Rage")
		assert(rage, "no rage after the steal")
		equal(rage.id, THIEF, "the thief"); equal(Duq.phase(state), "Roar", "she roars first")
		near(rage.chaseAt - rage.at, Duq.ROAR_SECONDS, "the roar")
		-- one rage at a time: a second carrier (a refilled egg) is not chased while it lasts
		local later = steps(state, 0.1, 0.5, { atNest(), onFloor(40, { id = 8 }) })
		equal(firstOf(later, "Rage"), nil, "a second rage")
		equal(state.rage.id, THIEF, "still the first thief")
		equal(firstOf(steps(Duq.new(), 0, 1, { onFloor(40, { carriesHerEgg = false }) }), "Rage"), nil, "another egg")
		equal(firstOf(steps(Duq.new(), 0, 1, { onFloor(40, { safe = true }) }), "Rage"), nil, "in a safe zone")
		local outside = carrier(Layout.CENTRE.x - Layout.HALF - 2, Layout.FLOOR_TOP + 3, Layout.CENTRE.z)
		equal(firstOf(steps(Duq.new(), 0, 1, { outside }), "Rage"), nil, "outside the plot")
	end)

	case("DR2: she turns red and roars on her seat for ROAR_SECONDS (a tell of at least 0.8 s), then leaves it", function()
		assert(Duq.ROAR_SECONDS >= 0.8 and Duq.ROAR_SECONDS <= 1.5, "roar " .. Duq.ROAR_SECONDS)
		equal(Duq.TEXT.furious, "¡La Duquesa está furiosa!", "the notice")
		local state, seat = Duq.new(), Duq.seat(summit)
		local thief = onFloor(60)
		steps(state, 0, 0.9, { thief })
		equal(Duq.phase(state), "Roar", "still roaring at 0.9 s")
		local her = Duq.position(state)
		near(her.x, seat.x, "on her seat"); near(her.z, seat.z, "z"); near(her.y, seat.y, "y")
		steps(state, 1.0, 1.1, { thief })
		equal(Duq.phase(state), "Chase", "she chases after the roar")
		her = Duq.position(state)
		assert(Layout.flat(her.x, her.z, seat.x, seat.z) > 1, "she left her seat")
		local service = sources and sources.service
		has(service, 'Instance.new("Highlight")', "the red tint"); has(service, "Duq.TEXT.furious", "the notice over her head")
	end)

	case("DR3: she flies faster than any untrained runner, a little faster against a trained one, up to a cap", function()
		near(Duq.chaseSpeed(nil), Duq.CHASE_SPEED, "untrained")
		assert(Duq.CHASE_SPEED > 23.2, "faster than an untrained sprint (23.2)")
		for _, speed in ipairs({ 11, 16, 23.2, 26 }) do assert(Duq.chaseSpeed(speed) > speed, "she closes in on " .. speed) end
		near(Duq.chaseSpeed(26), 26 * Duq.CHASE_SCALE, "scaled to a trained runner")
		near(Duq.chaseSpeed(60), Duq.CHASE_CAP, "capped"); assert(Duq.CHASE_CAP <= 36, "cap " .. Duq.CHASE_CAP)
		local state = Duq.new()
		local thief = onFloor(60)
		steps(state, 0, 1.1, { thief })
		local a = table.clone(Duq.position(state))
		steps(state, 1.2, 1.5, { thief })
		local b = Duq.position(state)
		near(Layout.flat(a.x, a.z, b.x, b.z), 4 * 0.1 * Duq.CHASE_SPEED, "CHASE_SPEED studs a second", 0.05)
		-- she floats over the cake, then a few studs over the floor: 3 to 6 studs over the ground when she strikes
		local strike = firstOf(steps(state, 1.6, 4.5, { thief }), "Strike")
		assert(strike, "no lunge at a still thief")
		local over = strike.y - Layout.FLOOR_TOP
		assert(over >= 3 and over <= 6, "she strikes " .. over .. " studs over the floor")
	end)

	case("DR4: a lunge: a tell of at least 0.8 s, one hit per lunge, 25 damage (never a kill), a push, her egg drops", function()
		assert(Duq.LUNGE_TELL_SECONDS >= 0.8, "the fair-strike floor")
		assert(Duq.LUNGE_DAMAGE > 0 and Duq.LUNGE_DAMAGE < 100, "never a one-hit kill")
		local state = Duq.new()
		local thief = onFloor(60)
		local events = steps(state, 0, 8, { thief })
		local lunges, strikes = each(events, "Lunge"), each(events, "Strike")
		assert(#lunges >= 2 and #strikes >= 2, "lunges " .. #lunges .. ", strikes " .. #strikes)
		local seen = {}
		for _, s in ipairs(strikes) do
			assert(not seen[s.lunge], "lunge " .. s.lunge .. " struck twice")
			seen[s.lunge] = true
			local l = firstOf(lunges, "Lunge", function(ev) return ev.lunge == s.lunge end)
			assert(l, "a strike without its lunge")
			near(l.strikeAt - l.startAt, Duq.LUNGE_TELL_SECONDS, "tell")
			assert(s.t >= l.strikeAt - 1e-6 and s.t <= l.strikeAt + 0.11, "struck at " .. s.t)
			equal(s.outcome, "Hit", "a still thief is hit")
			equal(s.damage, Duq.LUNGE_DAMAGE, "damage"); equal(s.drop, true, "her egg drops")
			assert(s.studs >= 8, "a strong push"); near(math.sqrt(s.dx ^ 2 + s.dz ^ 2), 1, "a unit push")
			assert(Layout.flat(s.x, s.z, thief.x, thief.z) <= Duq.LUNGE_HIT_STUDS, "she lands on the thief")
		end
		-- after a lunge she recovers, and the next lunge waits LUNGE_GAP_SECONDS from the strike (D-1)
		assert(Duq.LUNGE_GAP_SECONDS >= Duq.RECOVER_SECONDS, "the gap covers the recovery")
		near(lunges[2].startAt - strikes[1].t, Duq.LUNGE_GAP_SECONDS, "the escape window", 0.11)
		-- her bubbles keep coming between lunges, faster than on the summit, rings on the thief's floor
		local volleys = {}
		for _, c in ipairs(each(events, "Charge")) do
			if c.rage then table.insert(volleys, c) end
		end
		assert(#volleys >= 2, "her bubbles during the chase: " .. #volleys)
		near(volleys[2].t - volleys[1].t, Duq.RAGE_EVERY_SECONDS, "every RAGE_EVERY_SECONDS", 0.11)
		assert(Duq.RAGE_EVERY_SECONDS < Duq.EVERY_SECONDS, "faster than on the summit")
		near(volleys[1].spots[1].y, thief.y - Duq.FEET_STUDS, "rings on the thief's floor")
		-- a bubble never hurts nor touches the egg
		for _, h in ipairs(each(events, "Hit")) do equal(h.damage, nil, "bubble damage"); equal(h.drop, nil, "bubble drop") end
	end)

	-- Deliberately changed (RC6): the plot's edge no longer ends the rage and the time limit is 180 s (a safety end).
	case("DR5: the rage ends: safe zone, death, gone, egg dropped (she calms first), or the 180 s safety limit", function()
		local function endsWith(change)
			local events = steps(Duq.new(), 0, 2, function(t) return t >= 1.5 and change() or { onFloor(60) } end)
			return firstOf(events, "Calm")
		end
		equal(endsWith(function() return { onFloor(60, { safe = true }) } end).reason, "Safe", "safe zone")
		equal(endsWith(function() return { onFloor(60, { alive = false }) } end).reason, "Dead", "dead")
		equal(endsWith(function() return {} end).reason, "Gone", "gone")
		local outside = carrier(Layout.CENTRE.x - Layout.HALF - Duq.LEAVE_MARGIN_STUDS - 1, Layout.FLOOR_TOP + 3, Layout.CENTRE.z)
		equal(endsWith(function() return { outside } end), nil, "past the edge she keeps chasing (RC6)")
		local margin = carrier(Layout.CENTRE.x - Layout.HALF - Duq.LEAVE_MARGIN_STUDS + 1, Layout.FLOOR_TOP + 3, Layout.CENTRE.z)
		equal(endsWith(function() return { margin } end), nil, "inside the margin she keeps chasing")
		-- an open lunge is called off
		local cut = steps(Duq.new(), 0, 3.3, function(t) return { onFloor(60, { safe = t >= 3.3 }) } end)
		local cancel = firstOf(cut, "LungeCancel")
		assert(cancel and cancel.lunge == 1, "an open lunge is called off")
		equal(firstOf(cut, "Strike"), nil, "no strike")
		-- her egg dropped: she hovers CALM_SECONDS where she is, then floats home and sits
		local state = Duq.new()
		local function list(t) return { onFloor(60, { carriesHerEgg = t < 1.5 }) } end
		local calm = firstOf(steps(state, 0, 1.5, list), "Calm")
		assert(calm and calm.reason == "Dropped", "dropped: " .. tostring(calm and calm.reason))
		near(calm.returnAt - calm.at, Duq.CALM_SECONDS, "she calms first")
		equal(Duq.phase(state), "Calm", "calm")
		local held = table.clone(Duq.position(state))
		steps(state, 1.6, 1.5 + Duq.CALM_SECONDS - 0.2, list)
		local still = Duq.position(state)
		near(still.x, held.x, "she hovers while she calms"); near(still.y, held.y, "y")
		assert(firstOf(steps(state, 1.5 + Duq.CALM_SECONDS - 0.1, 12, list), "Home"), "she never got home")
		equal(Duq.phase(state), "Seated", "seated again"); equal(Duq.position(state), nil, "on her seat")
		-- the time limit (a thief who dodges every lunge)
		equal(Duq.RAGE_SECONDS, 180, "the safety limit (RC6: 25 -> 180)")
		local timed = steps(Duq.new(), 0, Duq.RAGE_SECONDS + 0.3, { onFloor(60) }, dodgeAll)
		local over = firstOf(timed, "Calm")
		assert(over and over.reason == "Timeout", "time limit: " .. tostring(over and over.reason))
		assert(over.t >= Duq.RAGE_SECONDS - 1e-6 and over.t <= Duq.RAGE_SECONDS + 0.11, "ended at " .. over.t)
		for _, ev in ipairs(timed) do
			if ev.kind == "Strike" then assert(ev.t < over.t, "a strike after the end") end
		end
	end)

	case("DR6: a perfect dodge stuns her STUN_SECONDS (no damage, the egg stays); otherwise she recovers RECOVER_SECONDS", function()
		-- Deliberately re-pinned (D-1): the next lunge waits max(STUN_SECONDS, LUNGE_GAP_SECONDS) after the strike
		assert(Duq.STUN_SECONDS > Duq.RECOVER_SECONDS, "a dodge buys more time than a hit")
		local state = Duq.new()
		local thief = onFloor(60)
		local strike = firstOf(steps(state, 0, 3.9, { thief }, dodgeAll), "Strike")
		assert(strike and strike.outcome == "Dodged", "dodged: " .. tostring(strike and strike.outcome))
		equal(strike.damage, nil, "no damage"); equal(strike.drop, nil, "the egg stays")
		equal(Duq.phase(state), "Stunned", "stunned")
		local held = table.clone(Duq.position(state))
		local dizzy = steps(state, 4.0, strike.t + Duq.STUN_SECONDS - 0.1, { thief }, dodgeAll)
		equal(firstOf(dizzy, "Lunge"), nil, "a lunge while stunned")
		near(Duq.position(state).x, held.x, "she stays where she landed"); near(Duq.position(state).z, held.z, "z")
		local again = firstOf(steps(state, strike.t + Duq.STUN_SECONDS, strike.t + Duq.STUN_SECONDS + 1, { thief }, dodgeAll), "Lunge")
		assert(again, "she lunges again after the stun")
		near(again.startAt - strike.t, math.max(Duq.STUN_SECONDS, Duq.LUNGE_GAP_SECONDS), "after the stun", 0.11)
		-- the dodge is asked for the thief and the lunge it was told
		local asked
		steps(Duq.new(), 0, 3.9, { onFloor(60) }, function(id, lunge) asked = { id, lunge }; return "Hit" end)
		assert(asked and asked[1] == THIEF and asked[2] == 1, "resolve(id, lunge, now)")
	end)

	case("DR7: she floats home after the rage and cannot rage again for COOLDOWN_SECONDS after she sits", function()
		assert(Duq.COOLDOWN_SECONDS >= 15, "cooldown " .. Duq.COOLDOWN_SECONDS)
		local state = Duq.new()
		local function list(t) return { onFloor(60, { safe = t >= 1.5 and t < 4 }) } end
		local home = firstOf(steps(state, 0, 4, list), "Home")
		assert(home, "she never got home")
		local rage = firstOf(steps(state, 4.1, home.t + Duq.COOLDOWN_SECONDS + 0.5, list), "Rage")
		assert(rage, "no rage after the cooldown")
		local wait = rage.t - home.t
		assert(wait >= Duq.COOLDOWN_SECONDS - 1e-6 and wait <= Duq.COOLDOWN_SECONDS + 0.11, "raged again " .. wait .. " s after sitting")
	end)

	-- DR8: an untrained carrier steals her egg on the summit and goes (11 studs/s: WildboundLumipolWild.carrySpeed with
	-- one egg; 16 sprinting) down the stair (Frut.seedPath) and west across the plot past its edge. Her bubbles slow it as
	-- in play; the dodge's own dash and boost are left out (that only makes it harder). Its velocity (vx, vz) is what it
	-- moved in the last step. Policies (D-1): "never" keeps running straight and takes every lunge; "perfect" runs
	-- straight and perfect-dodges every lunge; "side" never presses dodge but steps sideways from the lock to the strike.
	-- K = the lunges a carrier avoided (dodged or missed) before it was free.
	local function escape(speed, policy)
		local path = { { x = nestX, y = summit.top + 3, z = nestZ } }
		for _, s in ipairs(Frut.seedPath(Layout)) do table.insert(path, { x = s.x, y = s.y + 3, z = s.z }) end
		-- Deliberately changed (RC6): on through the plot's entrance to the hub (the base), where the rage ends ("Safe")
		local gate = Layout.world(Layout.ENTRANCE)
		table.insert(path, { x = gate.x, y = Layout.FLOOR_TOP + 3, z = gate.z })
		table.insert(path, { x = Rules.HUB_X, y = Layout.FLOOR_TOP + 3, z = Rules.HUB_Z })
		local state, thief = Duq.new(), carrier(path[1].x, path[1].y, path[1].z, { speed = speed, vx = 0, vz = 0 })
		local leg, slowUntil, dodged = 1, -math.huge, 0
		local sideX, sideZ, sideUntil = nil, nil, -math.huge
		local function resolve() return policy == "perfect" and "Dodged" or "Hit" end
		for i = 0, math.floor((Duq.RAGE_SECONDS + 2) / 0.1) do
			local t = i * 0.1
			if i > 0 then
				local left = speed * (t < slowUntil and Duq.SLOW_MULTIPLIER or 1) * 0.1
				local ox, oz = thief.x, thief.z
				if sideX and t <= sideUntil + 1e-9 then
					thief.x, thief.z, left = thief.x + sideX * left, thief.z + sideZ * left, 0
				end
				while left > 0 and leg < #path do
					local to = path[leg + 1]
					local d = math.sqrt((to.x - thief.x) ^ 2 + (to.y - thief.y) ^ 2 + (to.z - thief.z) ^ 2)
					if d <= left then
						thief.x, thief.y, thief.z, leg, left = to.x, to.y, to.z, leg + 1, left - d
					else
						thief.x += (to.x - thief.x) / d * left
						thief.y += (to.y - thief.y) / d * left
						thief.z += (to.z - thief.z) / d * left
						left = 0
					end
				end
				thief.vx, thief.vz = (thief.x - ox) / 0.1, (thief.z - oz) / 0.1
				thief.safe = select(2, Rules.zone(thief.x, thief.z)) == true
			end
			for _, ev in ipairs(Duq.step(state, t, { thief }, summit, resolve)) do
				if ev.kind == "Hit" and ev.id == THIEF then slowUntil = t + ev.slowSeconds end
				if ev.kind == "Lock" and policy == "side" then
					local length = math.sqrt(thief.vx ^ 2 + thief.vz ^ 2)
					if length > 1e-6 then sideX, sideZ = -thief.vz / length, thief.vx / length else sideX, sideZ = 1, 0 end
					sideUntil = ev.strikeAt + 0.05
				end
				if ev.kind == "Strike" and (ev.outcome == "Dodged" or ev.outcome == "Miss") then dodged += 1 end
				if ev.kind == "Strike" and ev.outcome == "Hit" then return { caught = true, at = t, lunge = ev.lunge, dodged = dodged } end
				if ev.kind == "Calm" then return { caught = false, at = t, reason = ev.reason, dodged = dodged } end
			end
		end
		return { caught = false, at = math.huge, reason = "none", dodged = dodged }
	end

	-- Deliberately changed (RC6): the escape is the base now (she followed past the plot's edge), so a dodging carrier
	-- avoids more lunges on the way (K was 3 to 8 to the plot's edge).
	case("DR8: escape math: a carrier who never dodges is caught by her first lunge; one who dodges every lunge escapes", function()
		local never = escape(11, "never")
		assert(never.caught and never.lunge == 1, "a carrier who never dodges kept the egg past her first lunge")
		assert(never.at <= Duq.ROAR_SECONDS + 3, "caught at " .. never.at)
		-- Deliberately changed (GT, first Studio run 2026-11-17): the bigger Torta's longer stair lets a straight sprinter
		-- outrun her first lunge (a miss); her second one still catches it (at 5.8 s), so it must dodge all the same
		local sprinter = escape(16, "never")
		assert(sprinter.caught and sprinter.lunge <= 2, "a sprinter running straight kept the egg past her second lunge")
		for _, speed in ipairs({ 11, 16 }) do
			for _, policy in ipairs({ "perfect", "side" }) do
				local free = escape(speed, policy)
				local label = speed .. " " .. policy
				assert(not free.caught, label .. ": caught at lunge " .. tostring(free.lunge))
				equal(free.reason, "Safe", label .. ": she follows it to the base")
				assert(free.at < Duq.RAGE_SECONDS, label .. ": free at " .. free.at)
				assert(free.dodged >= 5 and free.dodged <= 40, label .. ": K = " .. free.dodged)
			end
		end
		-- hard: a walking carrier must avoid at least 5 lunges in a row (6 when tuned, by dodge or sidestep; sprinting all
		-- the way, 4 dodges or 6 sidesteps)
		assert(escape(11, "perfect").dodged >= 5, "K dodging = " .. escape(11, "perfect").dodged)
		assert(escape(11, "side").dodged >= 5, "K sidestepping = " .. escape(11, "side").dodged)
	end)

	case("DR10: the aim follows the thief until LUNGE_LOCK_SECONDS before the strike, then the dash goes to the locked spot", function()
		assert(math.abs(Duq.LUNGE_LOCK_SECONDS - 0.35) < 1e-6, "the lock opens the perfect dodge window")
		assert(Duq.LUNGE_REACH_STUDS >= Duq.LUNGE_START_STUDS + 16 * Duq.LUNGE_LOCK_SECONDS, "the dash covers a sprinting carrier")
		near(Duq.tellSpeed(nil), Duq.TELL_SPEED, "she slows during the tell"); assert(Duq.TELL_SPEED < Duq.CHASE_SPEED, "slower")
		-- a carrier running north on the floor at 11; "side" turns west at the lock
		local function runNorth(side)
			local state, thief = Duq.new(), onFloor(60, { vx = 0, vz = 11 })
			local turned, lock, lunge = false, nil, nil
			for i = 0, 80 do
				local t = i * 0.1
				if i > 0 then
					if turned then thief.x, thief.vx, thief.vz = thief.x - 1.1, -11, 0 else thief.z += 1.1 end
				end
				for _, ev in ipairs(Duq.step(state, t, { thief }, summit)) do
					if ev.kind == "Lunge" then lunge = lunge or ev end
					if ev.kind == "Lock" then
						lock = lock or ev
						lock.t, lock.tx, lock.tz = lock.t or t, lock.tx or thief.x, lock.tz or thief.z
						turned = side
					end
					if ev.kind == "Strike" then return ev, lock, lunge, thief end
				end
			end
			return nil, lock, lunge, thief
		end
		local strike, lock, lunge, thief = runNorth(false)
		assert(strike and lock and lunge, "no lunge at a runner")
		assert(lock.t >= lunge.strikeAt - Duq.LUNGE_LOCK_SECONDS - 1e-6 and lock.t <= lunge.strikeAt - Duq.LUNGE_LOCK_SECONDS + 0.11,
			"locked at " .. lock.t)
		near(lock.z - lock.tz, 11 * (lunge.strikeAt - lock.t), "aimed where a straight runner will be", 0.01)
		equal(strike.outcome, "Hit", "running straight is hit")
		assert(Layout.flat(strike.x, strike.z, lock.x, lock.z) < 0.01, "the dash goes to the locked spot")
		local dodge, dlock = runNorth(true)
		assert(dodge and dlock, "no lunge at the sidestepper")
		equal(dodge.outcome, "Miss", "a sidestep after the lock beats it"); equal(dodge.damage, nil, "no damage")
		assert(Layout.flat(dodge.x, dodge.z, dlock.x, dlock.z) < 0.01, "she still dashes to the locked spot")
		local service = sources and sources.service
		has(service, 'ev.kind == "Lock"', "the marker stays on the locked spot")
	end)

	case("DR9 wiring: the service knows her eggs, sends a landed lunge to BeastHit with the egg not kept, uses the shared dodge", function()
		local service = sources and sources.service
		has(service, "Duq.herIsland(Layout)", "her island from the layout")
		has(service, '"EncounterId"', "her nest's egg ids"); has(service, '"WildboundEggCarried"', "the egg on a thief's back")
		has(service, 'beastHit:Invoke(player, "DuquesaBurbuja", ev.damage, ev.drop ~= true)', "the one egg drop path")
		has(service, "DodgeService.telegraph(player, lungeKey(ev.id, ev.lunge), Duq.DODGE_SOURCE, ev.startAt, ev.strikeAt)",
			"a dodgeable lunge")
		has(service, "DodgeService.resolve(player, lungeKey(id, lunge), now)", "the dodge decides")
		has(service, "DodgeService.cancel(player, lungeKey(ev.id, ev.lunge))", "a called-off lunge")
		has(service, 'WaitForChild("WildboundDodgeService")', "the shared dodge states")
		has(service, "Rules.zone(", "the safe zones")
		has(service, "Duq.step(state, now, players, summit, resolve)", "one throttled step")
		assert(not string.find(service, "Raycast", 1, true), "no raycasts")
		equal(Duq.DODGE_SOURCE, "DonGlaseon", "an existing WildboundDodge source")
	end)

	case("RC6: her rage lasts out of the plot to the base; there she calms, vanishes and is back on her seat at once", function()
		local gate = Layout.world(Layout.ENTRANCE)
		-- the thief stands 30 studs outside the plot's west edge (between the plot and the hub), then reaches the hub
		local outside = carrier(gate.x - 30, Layout.FLOOR_TOP + 3, gate.z)
		assert(not select(2, Rules.zone(outside.x, outside.z)), "test setup: the spot outside the plot is not safe")
		local hub = carrier(Rules.HUB_X + Rules.HUB_RADIUS - 5, Layout.FLOOR_TOP + 3, Rules.HUB_Z, { safe = true })
		local state = Duq.new()
		local events = steps(state, 0, 30, function(t)
			if t < 1 then return { onFloor(60) } end
			return { outside }
		end, dodgeAll)
		equal(firstOf(events, "Calm"), nil, "she never calmed outside the plot within 30 s")
		equal(state.mode, "Rage", "still raging")
		local her = Duq.position(state)
		assert(Duq.plotDepth(summit, her.x, her.z) < 0, "she followed the thief out of the plot")
		local last = steps(state, 30.1, 30.1, { hub }, dodgeAll)
		local calm = firstOf(last, "Calm")
		assert(calm and calm.reason == "Safe", "the base ends it: " .. tostring(calm and calm.reason))
		local vanish, home = firstOf(last, "Vanish"), firstOf(last, "Home")
		assert(vanish and home and home.vanished == true, "outside the plot she vanishes home at once")
		near(vanish.x, her.x, "the vanish where she was", 1)
		equal(Duq.phase(state), "Seated", "seated again"); equal(Duq.position(state), nil, "on her seat")
		-- calmed inside the plot she still floats home (DR7 holds the cooldown)
		local inside = Duq.new()
		local ev2 = steps(inside, 0, 2, function(t) return { onFloor(60, { safe = t >= 1.5 }) } end)
		equal(firstOf(ev2, "Vanish"), nil, "inside the plot no vanish"); equal(Duq.phase(inside), "Return", "she floats home")
		local service = sources and sources.service
		has(service, 'ev.kind == "Vanish"', "the service draws her vanish")
	end)

	-- GT (cake move, owner request 2026-11-16 "the cake at the end, and much bigger"): the Torta's plaza is 28 studs from
	-- the plot's east edge, so her plot depth (where a rage may start, and where she vanishes after one: RC6) ignores
	-- that edge; the west, north and south edges still count.
	case("GT13: her plot depth ignores the east edge behind the Torta; the other edges still count", function()
		local far = Layout.HALF + 17
		near(Duq.plotDepth(summit, Layout.CENTRE.x + far, Layout.CENTRE.z), Layout.HALF, "east of the plot counts as inside")
		near(Duq.plotDepth(summit, Layout.CENTRE.x - far, Layout.CENTRE.z), -17, "west")
		near(Duq.plotDepth(summit, summit.x, Layout.CENTRE.z + far), -17, "north")
		near(Duq.plotDepth(summit, summit.x, Layout.CENTRE.z - far), -17, "south")
		near(Duq.plotDepth(summit, Layout.CENTRE.x, Layout.CENTRE.z + 50), Layout.HALF - 50, "inside")
		-- a thief who carried her egg just past the east edge (a few steps off the plaza) still starts her rage
		local east = carrier(Layout.CENTRE.x + Layout.HALF + 5, Layout.FLOOR_TOP + 3, Layout.CENTRE.z)
		assert(firstOf(steps(Duq.new(), 0, 0, { east }), "Rage"), "no rage for a thief just past the east edge")
	end)

	-- GT: the summit is about 65 studs up (it was 40): she still drops from her seat to the floor in about the time she
	-- needs to fly past the bottom tier's rim, so her first lunge comes as early as before.
	-- V4-D10 (owner request 2026-11-17, "the queen seated on top of the cake as before"): her scenery model sits on the
	-- moved summit again: the service pivots a model found off her seat onto Duq.seatPivot, facing the junction.
	case("V4-D10: her seated pivot is the summit floor's centre under her seat, facing the junction, clear of T1 and Frutillon", function()
		local junction = { x = Layout.CENTRE.x + Layout.JUNCTION.x, z = Layout.CENTRE.z + Layout.JUNCTION.z }
		local s = Duq.seatPivot(summit, junction)
		local seat = Duq.seat(summit)
		near(s.x, summit.x, "x"); near(s.z, summit.z, "z"); near(s.y, summit.top, "her base on the summit floor")
		near(seat.y - s.y, Duq.HOVER_STUDS, "her seat point HOVER_STUDS over her base (leaveSeat's offset)")
		-- facing the junction (west of the cake): CFrame.Angles(0, yaw, 0)'s LookVector is (-sin, 0, -cos)
		local lx, lz = -math.sin(s.yaw), -math.cos(s.yaw)
		local dx, dz = junction.x - summit.x, junction.z - summit.z
		local d = math.sqrt(dx * dx + dz * dz)
		near(lx, dx / d, "faces the junction (x)"); near(lz, dz / d, "faces the junction (z)")
		assert(lx < -0.99, "the junction lies west of the cake")
		near(Duq.seatPivot(summit).yaw, math.pi / 2, "no facing: west")
		-- off her seat: the old v2 spot (the plot's centre, 40.94 up) is; on it, a stud off, is not
		equal(Duq.offSeat({ x = 612, y = 40.94, z = -3 }, summit), true, "the old summit spot")
		equal(Duq.offSeat({ x = s.x + 1, y = s.y + 1, z = s.z }, summit), false, "a stud or so off")
		equal(Duq.offSeat({ x = s.x, y = s.y + Duq.SEAT_TOLERANCE_STUDS + 0.5, z = s.z }, summit), true, "floating over it")
		equal(Duq.offSeat(nil, summit), false, "no pivot: nothing to move")
		-- her 6-stud seat stays clear of the summit nest (T1, kit nest at its scale) and of Frutillon's ring
		local T1 = Layout.TOWER.summit
		local nestX, nestZ = Layout.CENTRE.x + T1.x, Layout.CENTRE.z + T1.z
		local gap = math.sqrt((nestX - s.x) ^ 2 + (nestZ - s.z) ^ 2) - 3 - 2.65 * T1.scale
		assert(gap >= 1, "her seat is " .. gap .. " studs from the summit nest")
		assert(Frut.RING_STUDS - Frut.RADIUS_STUDS - Frut.HIT_STUDS - 3 >= 1, "Frutillon's roll reaches her seat")
		assert(3 + 1 <= summit.radius, "her seat fits the summit")
	end)

	case("V4-D10 wiring: the service seats her model at start when it is off her seat", function()
		local service = sources.service
		has(service, "if Duq.offSeat({ x = at.X, y = at.Y, z = at.Z }, summit) then", "checks her pivot at start")
		has(service, "local junction = { x = Layout.CENTRE.x + Layout.JUNCTION.x, z = Layout.CENTRE.z + Layout.JUNCTION.z }",
			"towards the junction")
		has(service, "duquesa:PivotTo(CFrame.new(s.x, s.y, s.z) * CFrame.Angles(0, s.yaw, 0))", "onto her seat")
		local seatAt = service:find("if Duq.offSeat(", 1, true)
		assert(seatAt < service:find("local function leaveSeat()", 1, true), "before any rage reads her seat")
		assert(seatAt < service:find("RunService.Heartbeat:Connect", 1, true), "before the first step")
	end)

	-- V4-D12 (owner 2026-11-17: "no creature may enter the houses"): her rage flight stops at a house's edge and waits;
	-- a lunge never lands (no damage, no egg drop) on a thief inside a house.
	case("V4-D12 wiring: her flight is kept out of the houses and a sheltered thief is never struck", function()
		local service = sources.service
		has(service, 'local Smarts = require(ServerScriptService:WaitForChild("WildboundCandySmarts"))', "the shared helpers")
		has(service, "houses = Smarts.houseDiscs(workspace:FindFirstChild(Layout.ROOT_NAME))", "the live houses")
		has(service, "if her and wasX then her.x, her.z = Smarts.outsideHouses(wasX, wasZ, her.x, her.z, houseDiscs(now)) end",
			"after each step")
		assert(service:find("Smarts.outsideHouses(wasX", 1, true) < service:find("play(events, now)", 1, true), "before the events play")
		has(service, "if body and Smarts.inHouse(body.Position.X, body.Position.Z, houseDiscs(workspace:GetServerTimeNow())) then return end",
			"no lunge lands inside a house")
	end)

	case("GT14: her descent keeps up with the bigger Torta", function()
		local drop = summit.top - Layout.FLOOR_TOP
		local across = (Layout.TOWER.tiers[1].radius + 1) / Duq.CHASE_SPEED
		assert(drop / Duq.VERTICAL_SPEED <= across, ("a %.1f-stud drop takes %.2f s, the rim %.2f s"):format(drop,
			drop / Duq.VERTICAL_SPEED, across))
	end)

	return result
end

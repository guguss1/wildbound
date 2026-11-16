-- Invoke with require(freshTestClone)(require(freshCandyDuquesaClone), require(freshCandyFrutillonClone),
--   require(freshCandyLayoutClone), { service = <WildboundCandyDuquesaService Source>,
--   anim = <WildboundCandyCritterAnim Source> }, require(freshBeastChaseClone)).
-- A2 (odd/tasks/wildbound-caramelo-playfix.md): La Duquesa Burbuja stays seated on the Gran Torta's summit, but while a
-- player stands on the summit she throws "Bombas de chicle" (pack 6 sheet 01) every 10 s: three slow bubbles that pop
-- in small circles (each ring drawn on the floor from her windup, at least MIN_TELL before the pop); whoever is inside
-- a pop is slowed -30 % for 2 s and pushed 4 studs, once per volley. She plays her Charge and Whip clips. Damage 0.
-- Pure rules plus source pins of the service and the client animator. Changes nothing.
return function(Duq, Frut, Layout, sources, Chase)
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
		equal(Duq.EVERY_SECONDS, 10, "every"); equal(Duq.BUBBLES, 3, "bubbles"); equal(Duq.DAMAGE, 0, "damage")
		near(Duq.SLOW_MULTIPLIER, 0.7, "slow"); near(Duq.SLOW_SECONDS, 2, "slow time"); near(Duq.PUSH_STUDS, 4, "push")
		assert(Duq.WINDUP_SECONDS + Duq.FLIGHT_SECONDS >= 0.8, "the ring shows at least 0.8 s before the pop")
		assert(Duq.FLIGHT_SECONDS >= 1, "the bubbles fly slowly")
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
		assert(not string.find(service, "TakeDamage", 1, true) and not string.find(service, "%.Health%s*[-=]"), "no damage")
		has(anim, 'GetAttributeChangedSignal("WildboundCritterCue")', "the preview animator plays a cued one-shot")
	end)

	return result
end

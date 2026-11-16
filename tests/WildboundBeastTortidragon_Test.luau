-- Invoke with require(freshTestClone)(require(freshBeastEncountersClone), require(freshBeastTortidragonClone),
-- require(freshBeastConfigClone), require(freshCandyTortidragonAttackClone)). The beast module reads its DataModel, so
-- its clone must sit in ServerScriptService while it is required.
-- Caramelo biome (odd/tasks/wildbound-caramelo.md, CA2; pack 03_PERSONAJES/03_TORTIDRAGON.md): Tortidragon's state
-- machine, pure, on the harness of WildboundBeastFlanfuria_Test: a fake world with flat ground at y 0 and a target
-- moved by the test. A new encounter faces +Z, so a target at +Z is in front of it.
return function(Enc, Tortidragon, Config, Abanico)
	-- Deliberately changed (CF, user 2026-11-15): the cast times come from the rule (Abanico) instead of literals, since
	-- the aim, the lock, the recovery and the cooldown were shortened. The rule's own suite pins the numbers.
	local LOCK = Abanico.LOCK_SECONDS
	local IMPACT = Abanico.TELEGRAPH_SECONDS + Abanico.RELEASE_SECONDS
	local ENDS = IMPACT + Abanico.RECOVER_SECONDS
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
	Enc.register("Tortidragon", Tortidragon)
	local C = Config.BEASTS.Tortidragon
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
	local function dragon(id) return Enc.new("Tortidragon", id, 1, 0, { x = 0, y = 0, z = 0 }) end
	-- A dragon that noticed a target 6 studs in front, stepped until its first tell. Returns e, w, tgt, events, tell.
	local function telegraphing(id)
		local e, w, tgt = dragon(id), fakeWorld(), target(0, 6)
		local events = run(e, w, tgt, 0, 1.2)
		local tell = each(events, "Tell")[1]
		assert(tell, "no tell after noticing a target in front (phases " .. phases(events) .. ")")
		return e, w, tgt, events, tell
	end

	case("config: a summoned guardian with the pack's movement (patrol 10, chase 16, sight 22, leash 35), no damage, egg kept", function()
		assert(C and T, "no Tortidragon in the config")
		-- Deliberately changed (OF2, owner feedback 2): its volley hurts (12, BeastHit with the egg kept) and it chases
		-- faster than a walking player (16 -> 20).
		equal(C.points, 0, "points"); equal(C.damage, 12, "damage"); equal(C.keepsEgg, true, "keepsEgg"); equal(C.grounded, true, "grounded")
		equal(C.chance, 0, "never rolled"); equal(Config.SUMMONED.Tortidragon, true, "summoned"); equal(Config.WAVE2.Tortidragon, true, "behaviour module")
		near(T.PatrolSpeedStudsPerSecond, 10, "patrol"); near(T.ChaseSpeedStudsPerSecond, 20, "chase")
		near(T.PerceptionStuds, 22, "sight"); near(T.LeashStuds, 35, "leash")
		assert(T.CastRangeStuds <= Abanico.RANGE_STUDS, "it casts at targets the fan cannot reach")
		assert(Tortidragon.tellSeconds() >= Config.MIN_TELL, "the tell is shorter than the minimum")
	end)

	case("Calm -> Notice -> Chase -> Telegraph: the fan in front, 12 studs, 55 deg, undodgeable, impact when the aim and the flight end", function()
		local e, _, _, events, tell = telegraphing("t1")
		equal(string.sub(phases(events), 1, #"Calm,Notice,Chase,Telegraph"), "Calm,Notice,Chase,Telegraph", "phases")
		equal(tell.shape.kind, "sector", "the aim is a fan")
		near(tell.shape.r, 12, "range"); near(tell.shape.arc, 55, "arc"); assert(tell.shape.dz > 0.9, "the fan does not point at the target")
		near(tell.strikeAt - tell.startAt, IMPACT, "aim + flight"); near(tell.lockAt - tell.startAt, LOCK, "lock")
		equal(tell.dodgeable, false, "dodgeable"); equal(tell.locked, false, "locked at start")
		equal(e.phase, "Telegraph")
	end)

	case("a target behind is never fired at: the dragon turns first, and only fires once it is in the fan", function()
		local e, w, tgt = dragon("t2"), fakeWorld(), target(0, 6)
		run(e, w, tgt, 0, 0.7) -- noticed, facing +Z, still in Notice
		tgt.z = -6 -- now straight behind it
		local events, firstTellAt, facingAtTell = {}, nil, nil
		for _, ev in ipairs(run(e, w, tgt, 0.75, 3, nil, function(t, en)
			if not firstTellAt and en.phase == "Telegraph" then firstTellAt, facingAtTell = t, en.dz end
		end)) do table.insert(events, ev) end
		assert(firstTellAt, "it never fired after turning (phases " .. phases(events) .. ")")
		assert(firstTellAt > 0.9, "it fired on the first step at a target behind it")
		assert(facingAtTell < -0.85, "it fired before facing the target: dz " .. facingAtTell)
	end)

	case("the lock freezes three circles along the aim; moving afterwards never moves them", function()
		local e, w, tgt, _, tell = telegraphing("t3")
		local start = tell.startAt
		local events = run(e, w, tgt, start + 0.05, start + 0.95, function(t, target)
			if t > start + LOCK + 0.02 then target.x = 3 end -- sidestep after the lock
		end)
		local locked
		for _, ev in ipairs(each(events, "Tell")) do if ev.locked then locked = locked or ev end end
		assert(locked, "no locked tell")
		near(locked.at, start + LOCK, "lock time", 0.051)
		equal(locked.shape.kind, "multi"); equal(#locked.shape.list, 3, "circles")
		for _, c in ipairs(locked.shape.list) do near(c.r, 2.3, "radius") end
		near(locked.shape.list[2].x, 0, "middle circle on the aim", 1e-3)
		for _, ev in ipairs(each(events, "Tell")) do
			if ev.at > locked.at then error("the tell changed after the lock") end
		end
	end)

	case("standing in a circle at the impact: one Hit, damage 0, a light push away and a short stagger; then Recover, Chase", function()
		local e, w, tgt, _, tell = telegraphing("t4")
		local start = tell.startAt
		local events = run(e, w, tgt, start + 0.05, start + 2.6)
		local hits = each(events, "Hit")
		equal(#hits, 1, "hits")
		local hit = hits[1]
		near(hit.at, start + IMPACT, "impact time", 1e-6); equal(hit.damage, C.damage, "damage (OF2)")
		near(hit.push.studs, Abanico.PUSH_STUDS, "push"); assert(hit.push.dz > 0, "the push does not go away from the dragon")
		near(hit.slow.multiplier, 0.85, "stagger"); near(hit.slow.seconds, 0.8, "stagger time")
		local after = phases(events)
		assert(string.find(after, "Release,Recover,Chase", 1, true), "phases after the tell: " .. after)
		equal(#each(events, "Afflict"), 0, "afflictions")
	end)

	case("stepping out of the fan sideways after the lock dodges it: a Strike miss and no Hit", function()
		local e, w, tgt, _, tell = telegraphing("t5")
		local start = tell.startAt
		local events = run(e, w, tgt, start + 0.05, start + 1.8, function(t, target)
			if t > start + LOCK + 0.05 then target.x = 7 end
		end)
		equal(#each(events, "Hit"), 0, "hits")
		local strike = each(events, "Strike")[1]
		assert(strike and strike.hit == false, "no missed strike")
	end)

	case("cooldown: no second fan until Abanico.COOLDOWN_SECONDS after the cast ended", function()
		local e, w, tgt, _, tell = telegraphing("t6")
		local start = tell.startAt
		local events = run(e, w, tgt, start + 0.05, start + ENDS + Abanico.COOLDOWN_SECONDS - 0.1)
		local opened = 0
		for _, ev in ipairs(each(events, "Tell")) do if ev.tell ~= tell.tell then opened += 1 end end
		equal(opened, 0, "a second fan inside the cooldown")
		events = run(e, w, tgt, start + ENDS + Abanico.COOLDOWN_SECONDS - 0.05, start + ENDS + Abanico.COOLDOWN_SECONDS + 0.6)
		assert(#each(events, "Tell") >= 1, "no fan after the cooldown")
	end)

	case("a safe zone ends it at once and nothing lands", function()
		local e, w, tgt, _, tell = telegraphing("t7")
		local start = tell.startAt
		tgt.safe = true
		local events = run(e, w, tgt, start + 0.05, start + 2)
		local ended = each(events, "End")[1]
		assert(ended and ended.reason == "SafeZone", "no SafeZone end")
		equal(#each(events, "Hit"), 0, "hits")
	end)

	case("leash: it never leaves 35 studs from its nest; a target past AbandonStuds makes it give up", function()
		local e, w, tgt = dragon("t8"), fakeWorld(), target(0, 8)
		local furthest = 0
		run(e, w, tgt, 0, 12, function(t, target) target.z = 8 + t * 4 end, function(_, en)
			furthest = math.max(furthest, math.sqrt(en.pos.x ^ 2 + en.pos.z ^ 2))
		end)
		assert(furthest <= T.LeashStuds + 1e-6, "it went " .. furthest .. " studs from its nest")
		local e2, w2, tgt2 = dragon("t9"), fakeWorld(), target(0, 8)
		run(e2, w2, tgt2, 0, 1)
		local events = run(e2, w2, tgt2, 1.05, 4, function(_, target) target.z = 60 end)
		assert(string.find(phases(events), "GiveUp", 1, true) or each(events, "Disengage")[1], "it never gave up")
	end)

	return result
end

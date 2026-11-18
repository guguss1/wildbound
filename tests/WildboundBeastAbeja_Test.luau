-- Invoke with require(freshTestClone)(require(freshBeastEncountersClone), require(freshBeastAbejaClone),
-- require(freshBeastConfigClone), freshBeastAbejaClone.Source, require(freshPraderaSitesClone), freshPraderaSitesClone.Source).
-- Kids biome (odd/tasks/wildbound-kids-beasts.md, KB-3): La Abeja Reina's state machine and the Pradera sites, pure. A
-- fake world (flat ground at y 0, a plaza site) and a target whose `noise`, `eventOpen` and `stickyUntil` stand in for
-- the server's noise radius, the BiomeEvent window and the Pegajoso attribute.
return function(Enc, Abeja, Config, source, Sites, sitesSource)
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
	Enc.register("AbejaReina", Abeja)
	local C = Config.BEASTS.AbejaReina
	local T = C.tuning
	local PLAZA = { x = -40, z = 14 }

	local function fakeWorld()
		local w = { cancelled = {} }
		function w.ground() return 0 end
		function w.site(key) if key == "plaza" then return PLAZA end return nil end
		function w.telegraph() return true end
		function w.resolve() return "Hit" end
		function w.cancel(id) table.insert(w.cancelled, id) end
		return w
	end
	-- A loud target (running noise) at (x, z), the window open.
	local function target(x, z, extra)
		local tgt = { x = x, y = 3, z = z, alive = true, safe = false, eventOpen = true, noise = T.NoiseRunStuds }
		for k, v in pairs(extra or {}) do tgt[k] = v end
		return tgt
	end
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
	local function phases(events)
		local list = {}
		for _, ev in ipairs(events) do if ev.type == "Phase" then table.insert(list, ev.phase) end end
		return table.concat(list, ",")
	end
	-- La Colmena at the origin.
	local function abeja(id)
		return Enc.new("AbejaReina", id, 1, 0, { x = 0, y = 0, z = 0 })
	end

	case("KB-3 Abeja config: summoned event creature, damage 0, points 0, never rolled", function()
		equal(Config.SUMMONED.AbejaReina, true); equal(C.category, "Event"); equal(Config.CATEGORIES.Event, true)
		equal(C.biome, "Meadow"); equal(C.damage, 0); equal(C.points, 0)
		equal(Config.PLAYABLE.AbejaReina, nil)
		for _, name in ipairs(Config.ORDER) do assert(name ~= "AbejaReina", "not in ORDER") end
		equal(T.WakeSeconds, 3); equal(T.GuardRadiusStuds, 35); equal(T.LeashStuds, 45); equal(T.WakeRadiusStuds, 70)
	end)

	case("KB-3 Abeja: the 3 s wake has no notice and no strike", function()
		local e = abeja("beast:1")
		local events = run(e, fakeWorld(), target(5, 0), 0, T.WakeSeconds - 0.05)
		equal(find(events, "Phase", "phase", "Heard"), nil, "no notice while waking")
		equal(find(events, "Tell"), nil, "no strike while waking")
		local wake = find(events, "Phase", "phase", "Wake")
		assert(wake, "Despierta")
		near(wake.untilAt - wake.at, T.WakeSeconds)
	end)

	case("KB-3 Sites: noise radii 0 / 30 / 55 / 70 and the Night x0.5", function()
		equal(Sites.noiseRadius(0, false, false), 0, "still")
		equal(Sites.noiseRadius(0.5, false, false), 0, "under 1")
		equal(Sites.noiseRadius(10, false, false), 30, "walking")
		equal(Sites.noiseRadius(17, false, false), 30, "17 still walks")
		equal(Sites.noiseRadius(20, false, false), 55, "running")
		equal(Sites.noiseRadius(0, true, false), 70, "airborne")
		equal(Sites.noiseRadius(10, false, true), 15, "Night halves")
		equal(Sites.noiseRadius(0, true, true), 35, "Night halves the jump too")
		equal(Sites.noiseRadius(0 / 0, false, false), 0, "a broken speed is silent")
	end)

	case("KB-3 Abeja: a still player is silent; a noisy one inside the guard radius is heard", function()
		local e = abeja("beast:2")
		local events = run(e, fakeWorld(), target(8, 0, { noise = 0 }), 0, 6)
		equal(find(events, "Phase", "phase", "Heard"), nil, "si no te mueves, no te oye")
		local e2 = abeja("beast:3")
		events = run(e2, fakeWorld(), target(20, 0, { noise = T.NoiseWalkStuds }), 0, T.WakeSeconds + 0.2)
		assert(find(events, "Phase", "phase", "Heard"), "walking 20 away is heard: " .. phases(events))
		local e3 = abeja("beast:4")
		events = run(e3, fakeWorld(), target(40, 0), 0, T.WakeSeconds + 0.5)
		equal(find(events, "Phase", "phase", "Heard"), nil, "outside the 35 guard radius")
	end)

	case("KB-3 Abeja: ¡Zum!: a locked lane 6 x 12, tell 1.2 s; Picotazo only in the lane", function()
		near(Abeja.tellSeconds(T), 1.2)
		assert(T.DiveTelegraphSeconds >= Config.MIN_TELL)
		local e = abeja("beast:5")
		local w = fakeWorld()
		local tgt = target(6, 0)
		local events = run(e, w, tgt, 0, T.WakeSeconds + T.HeardSeconds + 0.2)
		local tell = find(events, "Tell")
		assert(tell, "a dive within 9: " .. phases(events))
		equal(tell.shape.kind, "lane"); equal(tell.shape.width, 6); equal(tell.shape.length, 12)
		near(tell.strikeAt - tell.startAt, 1.2)
		assert(find(events, "Tell", "locked", true), "locked")
		-- Sidestep out of the lane before the strike.
		events = run(e, w, tgt, T.WakeSeconds + T.HeardSeconds + 0.25, T.WakeSeconds + T.HeardSeconds + 1.6, function(_, tg)
			tg.z = 8
		end)
		equal(find(events, "Hit"), nil, "out of the lane: no sting")
		assert(find(events, "Strike", "hit", false), "a miss")
	end)

	case("KB-3 Abeja: a sting deals 0 and makes the target sticky; a second sticky sting flies it to the plaza", function()
		local e = abeja("beast:6")
		local w = fakeWorld()
		local tgt = target(6, 0)
		local events = run(e, w, tgt, 0, T.WakeSeconds + T.HeardSeconds + 1.5)
		local hit = find(events, "Hit")
		assert(hit, "in the lane: " .. phases(events))
		equal(hit.damage, 0)
		assert(hit.sticky and hit.sticky.walkSpeed == T.StickyWalkSpeed and hit.sticky.seconds == T.StickySeconds, "Pegajoso")
		assert(T.StickyWalkSpeed >= 9, "never below 9")
		equal(hit.line, "Sticky"); equal(hit.knock, nil)
		tgt.stickyUntil = hit.at + T.StickySeconds
		-- Keep the target next to her and loud.
		events = run(e, w, tgt, T.WakeSeconds + T.HeardSeconds + 1.55, T.WakeSeconds + 10, function(_, tg)
			tg.x, tg.z = e.pos.x + 5, e.pos.z
		end)
		local second = find(events, "Hit")
		assert(second, "a second sting: " .. phases(events))
		assert(second.knock and second.knock.speed == T.FlyBackStudsPerSecond, "Vuelo de vuelta")
		equal(second.sticky, nil, "no second slow")
	end)

	case("KB-3 Abeja: Te busca at 10 (slower than 16), leash 45; Te perdió after 3 s unheard", function()
		assert(T.SearchSpeedStudsPerSecond < 16)
		local e = abeja("beast:7")
		local w = fakeWorld()
		local tgt = target(30, 0)
		run(e, w, tgt, 0, T.WakeSeconds + T.HeardSeconds + 0.1)
		equal(e.phase, "Search")
		local x0 = e.pos.x
		run(e, w, tgt, T.WakeSeconds + T.HeardSeconds + 0.15, T.WakeSeconds + T.HeardSeconds + 1.1)
		near(math.abs(e.pos.x - x0), T.SearchSpeedStudsPerSecond * 1, "10 studs in 1 s", 1.2)
		-- The target goes silent at the guard edge; she never leaves the 45 leash and loses it after 3 s.
		local maxFromHive = 0
		local events = run(e, w, tgt, T.WakeSeconds + T.HeardSeconds + 1.15, T.WakeSeconds + 9, function(_, tg)
			tg.noise, tg.x = 0, 60
			maxFromHive = math.max(maxFromHive, Config.flat(e.pos.x, e.pos.z, 0, 0))
		end)
		assert(maxFromHive <= T.LeashStuds + 1e-6, "leash " .. maxFromHive)
		assert(find(events, "Phase", "phase", "Lost"), "Te perdió: " .. phases(events))
		assert(find(events, "Phase", "phase", "Guard"), "back on guard")
	end)

	case("KB-3 Abeja: the window closing cancels an open attack (Sleep, End EventEnded); escape beyond 70", function()
		local e = abeja("beast:8")
		local w = fakeWorld()
		local tgt = target(6, 0)
		run(e, w, tgt, 0, T.WakeSeconds + T.HeardSeconds + 0.2)
		assert(next(e.open) ~= nil, "a dive is open")
		local events = run(e, w, tgt, T.WakeSeconds + T.HeardSeconds + 0.25, T.WakeSeconds + 10, function(_, tg)
			tg.eventOpen = false
		end)
		equal(next(e.open), nil, "Attack.closeAll cancelled it")
		equal(find(events, "Hit"), nil, "no sting after the window")
		assert(find(events, "Phase", "phase", "Sleep"), "Vuelve a dormir")
		local d = find(events, "Disengage")
		near(d.untilAt - d.at, T.SleepSeconds)
		equal(find(events, "End").reason, "EventEnded")
		local e2 = abeja("beast:9")
		events = run(e2, w, target(75, 0), 0, 0.2)
		equal(find(events, "Disengage").reason, "Escape")
	end)

	case("KB-3 Sites: offsets, origin fallback, the Abeja wants the open window near La Colmena", function()
		-- Deliberately changed (V8-D1, owner request 2026-11-17 "make the Reino Caramelo map a bit bigger"): the default
		-- origin is the v8 plot centre (672, -3) (was 612, -3) and the offsets are x 1.3: pond (195, 52), colmena
		-- (-97.5, 97.5), gate (-241.8, 0), plaza (-52, 18.2). Was pond (762, 37), hive (-75, 75), gate x 426, plaza z 11.
		-- Within 1e-9: 430.2 and 15.2 are not exact in binary.
		local o = Sites.origin(nil)
		equal(o.x, 672); equal(o.z, -3)
		local pond = Sites.world(nil, "pond")
		equal(pond.x, 867); equal(pond.z, 49)
		local hive = Sites.world({ x = 0, z = 0 }, "colmena")
		equal(hive.x, -97.5); equal(hive.z, 97.5)
		near(Sites.world(nil, "gate").x, 430.2, "gate x", 1e-9); near(Sites.world(nil, "plaza").z, 15.2, "plaza z", 1e-9)
		local col = Sites.world(nil, "colmena")
		local ctx = { alive = true, safe = false, meadow = true, eventOpen = true, x = col.x + 60, z = col.z }
		equal(Sites.wants("AbejaReina", ctx), true)
		ctx.eventOpen = false
		equal(Sites.wants("AbejaReina", ctx), false, "closed window")
		ctx.eventOpen, ctx.x = true, col.x + 75
		equal(Sites.wants("AbejaReina", ctx), false, "beyond 70")
		equal(Sites.eventOpen(0, nil), false); equal(Sites.eventOpen(2, nil), true); equal(Sites.eventOpen(nil, nil), false)
		equal(Sites.eventOpen(0, true), true, "Studio override opens"); equal(Sites.eventOpen(3, false), false, "and closes")
	end)

	case("KB-3 Abeja and Sites: the modules are pure and server-only", function()
		for label, text in pairs({ abeja = source, sites = sitesSource }) do
			for _, banned in ipairs({ "workspace", "game:", "task.", "os.clock", "math.random", "Random.new", "Touched", "FireClient" }) do
				assert(not text:find(banned, 1, true), label .. " uses " .. banned)
			end
		end
	end)

	return result
end

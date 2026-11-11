-- Invoke with require(freshTestClone)(require(freshArrulloClone), freshArrulloClone.Source).
-- Arrullo (decision Q2b, docs/mechanics/wildbound-new-mechanics.md section 1): the rare-egg minigame. A vertical bar,
-- a calm zone that drifts on smooth noise, a marker the player raises by holding and lets fall by releasing, and a
-- progress meter that fills inside the zone and drains outside it. The server simulates; the client only sends
-- hold or release.
return function(Arrullo, source)
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
	local function near(actual, expected, tolerance, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-6),
			(label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	-- A tiny deterministic generator in (0, 1) (Park-Miller; every product stays exact in a double), so every run sees
	-- the same zone path.
	local function lcg(seed)
		local value = seed or 1
		return function()
			value = (value * 16807) % 2147483647
			return value / 2147483647
		end
	end
	local function constant(x) return function() return x end end

	case("A1: the defaults: rarities, a bar from 0 to 1, a start below the goal, a timeout", function()
		local C = Arrullo.CONSTANTS
		assert(type(C) == "table", "CONSTANTS")
		equal(C.GOAL, 100); equal(C.START, 35); equal(C.TIMEOUT, 18)
		for _, rarity in ipairs({ "Rara", "Epica", "Legendaria" }) do
			assert(type(Arrullo.RARITIES[rarity]) == "table", "a row for " .. rarity)
		end
		-- Rarer eggs: a smaller zone that moves faster.
		local r, e, l = Arrullo.RARITIES.Rara, Arrullo.RARITIES.Epica, Arrullo.RARITIES.Legendaria
		assert(r.zone > e.zone and e.zone > l.zone, "the zone shrinks with rarity")
		assert(r.segment > e.segment and e.segment > l.segment, "the zone moves faster with rarity")
		equal(Arrullo.live.TIMEOUT, 18, "live starts at the defaults")
	end)

	case("A2: new() refuses an unknown rarity; a new state starts running at START with the marker at the bottom", function()
		equal(select(2, Arrullo.new("Comun", constant(0.5))), "UnknownRarity", "normal eggs use the fast steal")
		equal(select(2, Arrullo.new("Rara", nil)), "NoRng")
		local state = Arrullo.new("Rara", constant(0.5))
		assert(type(state) == "table", "a state")
		equal(state.status, "running"); equal(state.progress, Arrullo.CONSTANTS.START)
		equal(state.marker, 0); equal(state.velocity, 0); equal(state.elapsed, 0)
		local low, high = Arrullo.zoneBounds(state)
		near(high - low, Arrullo.RARITIES.Rara.zone, 1e-9, "the zone has its rarity's size")
		assert(low >= 0 and high <= 1, "the zone stays on the bar")
	end)

	case("A3: holding raises the marker, releasing lets it fall; it never leaves the bar", function()
		local state = Arrullo.new("Rara", constant(0.5))
		for _ = 1, 20 do Arrullo.step(state, 0.05, true, constant(0.5)) end
		assert(state.marker > 0.2, "holding for 1 s lifts the marker")
		for _ = 1, 200 do Arrullo.step(state, 0.05, true, constant(0.5)) end
		assert(state.marker <= 1, "the top is a wall")
		local top = state.marker
		Arrullo.step(state, 0.05, false, constant(0.5))
		Arrullo.step(state, 0.05, false, constant(0.5))
		assert(state.marker < top, "releasing lets it fall")
		for _ = 1, 200 do Arrullo.step(state, 0.05, false, constant(0.5)) end
		assert(state.marker >= 0, "the bottom is a floor")
	end)

	case("A4: progress fills while the marker is inside the zone and drains outside", function()
		local inside = Arrullo.new("Rara", constant(0.5))
		inside.marker = 0.5; inside.velocity = 0
		local before = inside.progress
		local out = Arrullo.step(inside, 0.1, nil, constant(0.5))
		-- `nil` holding is a release: the marker starts falling but is still inside the centred zone for one step.
		equal(out.inside, true, "inside the centred zone")
		near(inside.progress, before + Arrullo.RARITIES.Rara.fill * 0.1, 1e-6, "fills at the rarity's rate")

		local outside = Arrullo.new("Rara", constant(0.5))
		outside.marker = 0; outside.velocity = 0
		local start = outside.progress
		local out2 = Arrullo.step(outside, 0.1, false, constant(0.5))
		equal(out2.inside, false)
		near(outside.progress, start - Arrullo.RARITIES.Rara.drain * 0.1, 1e-6, "drains at the rarity's rate")
	end)

	case("A5: win at the goal, lose at zero or at the timeout; a finished state never changes again", function()
		local win = Arrullo.new("Rara", constant(0.5))
		win.progress = 99.9; win.marker = 0.5
		local out = Arrullo.step(win, 0.1, true, constant(0.5))
		equal(out.status, "won"); equal(win.status, "won"); equal(win.progress, 100)
		local frozen = win.marker
		Arrullo.step(win, 1, false, constant(0.5))
		equal(win.marker, frozen, "a won state is final")

		local lose = Arrullo.new("Rara", constant(0.5))
		lose.progress = 0.5; lose.marker = 0
		equal(Arrullo.step(lose, 0.1, false, constant(0.5)).status, "lost"); equal(lose.reason, "Empty")

		local slow = Arrullo.new("Rara", constant(0.5))
		slow.elapsed = Arrullo.CONSTANTS.TIMEOUT - 0.05; slow.marker = 0.5; slow.progress = 50
		equal(Arrullo.step(slow, 0.1, true, constant(0.5)).status, "lost"); equal(slow.reason, "Timeout")
	end)

	case("A6: the zone drifts smoothly and deterministically: same seed, same path; never a jump", function()
		local a = Arrullo.new("Legendaria", lcg(7))
		local b = Arrullo.new("Legendaria", lcg(7))
		local ra, rb = lcg(99), lcg(99)
		local last = a.zoneCenter
		local maxJump = 0
		for _ = 1, 400 do
			Arrullo.step(a, 1 / 30, true, ra)
			Arrullo.step(b, 1 / 30, true, rb)
			equal(a.zoneCenter, b.zoneCenter, "deterministic")
			maxJump = math.max(maxJump, math.abs(a.zoneCenter - last))
			last = a.zoneCenter
			if a.status ~= "running" then break end
		end
		assert(maxJump < 0.08, "smooth: at most a small move per frame, got " .. maxJump)
	end)

	case("A7: the zone moves faster for rarer eggs", function()
		local function travel(rarity)
			local state = Arrullo.new(rarity, lcg(3))
			local rng = lcg(5)
			local total, last = 0, state.zoneCenter
			for _ = 1, 120 do
				Arrullo.step(state, 1 / 30, true, rng)
				state.progress, state.status = 50, "running" -- keep it running for the measure
				total += math.abs(state.zoneCenter - last)
				last = state.zoneCenter
			end
			return total
		end
		assert(travel("Legendaria") > travel("Rara"), "Legendaria travels further in the same time")
	end)

	case("A8: step ignores bad input: a non-finite or negative dt, a large dt is clamped", function()
		local state = Arrullo.new("Rara", constant(0.5))
		local before = state.progress
		Arrullo.step(state, 0 / 0, true, constant(0.5))
		Arrullo.step(state, -1, true, constant(0.5))
		equal(state.progress, before, "nothing changes")
		equal(state.elapsed, 0)
		Arrullo.step(state, 10, true, constant(0.5))
		assert(state.elapsed <= Arrullo.MAX_DT + 1e-9, "one step is at most MAX_DT")
	end)

	-- The server session: the client sends only "hold" or "release"; the server keeps the clock.
	case("A9: session input accepts only hold and release and rate-limits a flood", function()
		local session = Arrullo.session("Rara", constant(0.5), 10)
		assert(type(session) == "table", "a session")
		equal(Arrullo.input(session, "hold", 10.01), true)
		equal(session.holding, true)
		equal(Arrullo.input(session, "release", 10.02), true)
		equal(session.holding, false)
		local ok, reason = Arrullo.input(session, "win", 10.03)
		equal(ok, false); equal(reason, "BadInput", "the client never sends progress")
		equal(select(2, Arrullo.input(session, 1, 10.03)), "BadInput")
		local refused = 0
		for i = 1, 40 do
			if not Arrullo.input(session, i % 2 == 0 and "hold" or "release", 10.1 + i * 0.001) then refused += 1 end
		end
		assert(refused > 0, "a flood is refused")
		equal(select(2, Arrullo.input(session, "hold", 0 / 0)), "BadClock")
	end)

	case("A10: the server advances the session on its own clock in fixed substeps", function()
		local session = Arrullo.session("Rara", constant(0.5), 0)
		session.state.marker = 0.5
		Arrullo.input(session, "hold", 0)
		local out = Arrullo.advance(session, 0.5, constant(0.5))
		near(session.state.elapsed, 0.5, 1e-6, "simulated half a second")
		equal(out.status, "running")
		-- A server hitch: a long gap is capped, so a stall never decides the outcome.
		Arrullo.advance(session, 100, constant(0.5))
		assert(session.state.elapsed <= 0.5 + Arrullo.MAX_CATCHUP + 1e-6, "catch-up is capped")
		-- Time never runs backwards.
		local elapsed = session.state.elapsed
		Arrullo.advance(session, 1, constant(0.5))
		equal(session.state.elapsed, elapsed)
	end)

	case("A11: view() gives the client only what it draws", function()
		local state = Arrullo.new("Epica", constant(0.5))
		local view = Arrullo.view(state)
		for _, key in ipairs({ "zoneLow", "zoneHigh", "marker", "progress", "status", "remaining" }) do
			assert(view[key] ~= nil, "view has " .. key)
		end
		near(view.progress, Arrullo.CONSTANTS.START / Arrullo.CONSTANTS.GOAL, 1e-9, "progress as a fraction")
		equal(Arrullo.TEXT.title, "Arrullo")
		assert(type(Arrullo.TEXT.hint) == "string" and #Arrullo.TEXT.hint > 0, "a hint line")
	end)

	case("A12: tune() overrides a rarity row and clamps it to fair ranges; nil restores the defaults", function()
		Arrullo.tune({ ZONE_Rara = 0.5, FILL_Rara = 999, TIMEOUT = 1, bogus = 3, SEGMENT_Epica = 0 / 0 })
		near(Arrullo.live.RARITIES.Rara.zone, 0.5, 1e-9)
		assert(Arrullo.live.RARITIES.Rara.fill <= Arrullo.FILL_MAX, "fill clamped")
		assert(Arrullo.live.TIMEOUT >= Arrullo.TIMEOUT_MIN, "timeout floor")
		equal(Arrullo.live.RARITIES.Epica.segment, Arrullo.RARITIES.Epica.segment, "a NaN is ignored")
		Arrullo.tune(nil)
		equal(Arrullo.live.RARITIES.Rara.zone, Arrullo.RARITIES.Rara.zone)
		equal(Arrullo.live.TIMEOUT, Arrullo.CONSTANTS.TIMEOUT)
		local rows = Arrullo.tunable()
		assert(rows.ZONE_Legendaria ~= nil and rows.TIMEOUT ~= nil, "flat rows for the dev tuning schema")
	end)

	case("A13: the module is pure: no services, no wall clock, no global random", function()
		assert(type(source) == "string", "source")
		for _, needle in ipairs({ "GetService", "os.time", "os.clock", "math.random", "tick()", "workspace" }) do
			assert(not source:find(needle, 1, true), "source has " .. needle)
		end
	end)

	return result
end

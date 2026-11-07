-- Invoke with require(freshTestClone)(require(freshAwarenessClone), require(freshHuntClone),
-- require(freshRulesClone), freshAwarenessClone.Source) in Studio Edit/Server.
-- Inputs are by value; life is an opaque Character identity. Time is injected.
return function(Awareness, Hunt, Rules, source)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected)
		assert(actual == expected, "Expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local lifeA, lifeB, lifeC = {}, {}, {}
	local NAN, INF = 0 / 0, math.huge
	local function player(id, life, distance, extra)
		local entry = { id = id, life = life, alive = true, distance = distance, safe = false }
		for key, value in pairs(extra or {}) do entry[key] = value end
		return entry
	end
	local function aAt(distance, extra) return player(1, lifeA, distance, extra) end
	local function bAt(distance, extra) return player(2, lifeB, distance, extra) end
	local function seen(now, target, players, mode, telegraphEndsAt)
		return { now = now, mode = mode or "Hunt", targetId = target.id, targetLife = target.life,
			targetVisible = true, lastVisibleAt = now, telegraphEndsAt = telegraphEndsAt, players = players }
	end
	local function lost(now, target, lastVisibleAt, players)
		return { now = now, mode = "Hunt", targetId = target.id, targetLife = target.life,
			targetVisible = false, lastVisibleAt = lastVisibleAt, players = players }
	end
	local function idle(now, mode, players)
		return { now = now, mode = mode, players = players }
	end
	local function stateOf(out, id)
		local entry = out[id]
		assert(type(entry) == "table", "No result for player " .. tostring(id))
		return entry.state
	end
	local function expect(out, id, state)
		equal(stateOf(out, id), state)
	end
	local function step(state, frame) return Awareness.step(state, frame) end
	local function fresh() return Awareness.new() end
	local CONST = Awareness.CONSTANTS
	local HOLD, SEARCH = CONST.SEEN_HOLD_SECONDS, CONST.SEARCH_SECONDS
	local ENTER, EXIT = CONST.ALLY_ENTER_RANGE, CONST.ALLY_EXIT_RANGE

	-- The nine scenes of the M2 exit test, as far as a pure rule can carry them.
	case("scene 1: a target in sight is seen and a far player is none", function()
		local a, b = aAt(10), bAt(200)
		local out = step(fresh(), seen(0, a, { a, b }))
		expect(out, 1, "seen"); expect(out, 2, "none")
	end)

	case("scene 2: a nearby non-target shows ally", function()
		local a, b = aAt(10), bAt(20)
		local out = step(fresh(), seen(0, a, { a, b }))
		expect(out, 1, "seen"); expect(out, 2, "ally")
	end)

	case("scene 3: broken sight becomes searching with an absolute countdown", function()
		local state, a = fresh(), aAt(10)
		step(state, seen(0, a, { a }))
		local out = step(state, lost(HOLD, a, 0, { a }))
		expect(out, 1, "searching")
		equal(out[1].searchEndsAt, SEARCH)
	end)

	case("scene 4: search expiry ends the threat for target and ally at the exact boundary", function()
		local state, a, b = fresh(), aAt(10), bAt(20)
		step(state, seen(0, a, { a, b }))
		local out = step(state, lost(SEARCH - 0.01, a, 0, { a, b }))
		expect(out, 1, "searching"); expect(out, 2, "ally")
		out = step(state, lost(SEARCH, a, 0, { a, b }))
		expect(out, 1, "none"); expect(out, 2, "none")
		equal(out[1].searchEndsAt, nil)
	end)

	case("scene 5: only the target receives the attack deadline", function()
		local a, b, c = aAt(5), bAt(9), player(3, lifeC, 300)
		local out = step(fresh(), seen(10, a, { a, b, c }, "Telegraph", 11.4))
		expect(out, 1, "seen"); equal(out[1].attackEndsAt, 11.4)
		expect(out, 2, "ally"); equal(out[2].attackEndsAt, nil)
		expect(out, 3, "none"); equal(out[3].attackEndsAt, nil)
	end)

	case("scene 6: interface state cannot change awareness", function()
		local a, open = aAt(10), aAt(10, { inventoryOpen = true, hudHidden = true })
		local base = step(fresh(), seen(0, a, { a }))
		local withOpen = step(fresh(), seen(0, open, { open }))
		equal(withOpen[1].state, base[1].state); equal(withOpen[1].state, "seen")
	end)

	case("scene 7: retarget flips both players in the same step with one seen", function()
		local state, a, b = fresh(), aAt(20), bAt(10)
		step(state, seen(0, a, { a, b }))
		local out = step(state, seen(0.2, b, { a, b }))
		expect(out, 1, "ally"); expect(out, 2, "seen")
		equal(out[1].changed, true); equal(out[2].changed, true)
	end)

	case("scene 8: a closer body between does not unsee the target, sight is the only input", function()
		local a, b = aAt(20), bAt(10)
		local out = step(fresh(), seen(0, a, { a, b }))
		expect(out, 1, "seen"); expect(out, 2, "ally")
	end)

	case("scene 9: a nearby Retreat shows no threat, even with stale target fields", function()
		local state, a, b = fresh(), aAt(3), bAt(4)
		step(state, seen(0, a, { a, b }))
		local frame = seen(0.2, a, { a, b }, "Retreat")
		local out = step(state, frame)
		expect(out, 1, "none"); expect(out, 2, "none")
		out = step(state, idle(0.4, "Retreat", { a, b }))
		expect(out, 1, "none"); expect(out, 2, "none")
	end)

	case("patrol shows no threat", function()
		local a = aAt(2)
		expect(step(fresh(), idle(0, "Patrol", { a })), 1, "none")
	end)

	case("alert and telegraph count as seen at once", function()
		local a = aAt(10)
		expect(step(fresh(), seen(0, a, { a }, "Alert")), 1, "seen")
		expect(step(fresh(), seen(0, a, { a }, "Telegraph", 1.4)), 1, "seen")
	end)

	-- Entering seen is immediate from every other state.
	case("seen is entered in the first step from none, ally and searching", function()
		local state, a, b = fresh(), aAt(20), bAt(20)
		expect(step(state, idle(0, "Patrol", { a, b })), 1, "none")
		expect(step(state, seen(0.2, a, { a, b })), 1, "seen")
		expect(step(state, seen(0.4, b, { a, b })), 1, "ally")
		expect(step(state, seen(0.6, a, { a, b })), 1, "seen")
		expect(step(state, lost(0.6 + HOLD, a, 0.6, { a, b })), 1, "searching")
		expect(step(state, seen(0.6 + HOLD + 0.01, a, { a, b })), 1, "seen")
	end)

	-- Leaving seen is held only against sight flicker on the same target and life.
	case("the hold keeps seen just under its limit and leaves at the limit", function()
		local state, a = fresh(), aAt(10)
		step(state, seen(0, a, { a }))
		local out = step(state, lost(HOLD - 0.01, a, 0, { a }))
		expect(out, 1, "seen"); equal(out[1].searchEndsAt, nil); equal(out[1].changed, false)
		out = step(state, lost(HOLD, a, 0, { a }))
		expect(out, 1, "searching"); equal(out[1].changed, true)
	end)

	case("the fixed step dropping one or two samples does not flicker", function()
		local state, a = fresh(), aAt(10)
		local now = 100
		step(state, seen(now, a, { a }))
		for _ = 1, 20 do
			local lastVisibleAt = now
			now += 0.2
			expect(step(state, lost(now, a, lastVisibleAt, { a })), 1, "seen")
			now += 0.2
			expect(step(state, lost(now, a, lastVisibleAt, { a })), 1, "seen")
			now += 0.2
			local out = step(state, seen(now, a, { a }))
			expect(out, 1, "seen"); equal(out[1].changed, false)
		end
	end)

	case("the hold does not extend the search deadline", function()
		local state, a = fresh(), aAt(10)
		step(state, seen(50, a, { a }))
		local out = step(state, lost(50 + HOLD + 0.2, a, 50, { a }))
		equal(out[1].searchEndsAt, 50 + SEARCH)
		out = step(state, lost(50 + HOLD + 0.4, a, 50, { a }))
		equal(out[1].searchEndsAt, 50 + SEARCH); equal(out[1].changed, false)
	end)

	case("regained sight restarts the hold", function()
		local state, a = fresh(), aAt(10)
		step(state, seen(0, a, { a }))
		step(state, lost(0.4, a, 0, { a }))
		step(state, seen(0.5, a, { a }))
		expect(step(state, lost(0.5 + HOLD - 0.01, a, 0.5, { a })), 1, "seen")
		expect(step(state, lost(0.5 + HOLD, a, 0.5, { a })), 1, "searching")
	end)

	case("retreat ends seen at once with no hold", function()
		local state, a = fresh(), aAt(10)
		step(state, seen(0, a, { a }))
		local out = step(state, idle(0.2, "Retreat", { a }))
		expect(out, 1, "none"); equal(out[1].changed, true)
	end)

	case("a threat that ended cannot revive an old hold", function()
		local state, a = fresh(), aAt(10)
		step(state, seen(0, a, { a }))
		step(state, idle(0.1, "Retreat", { a }))
		expect(step(state, lost(0.2, a, 0, { a })), 1, "searching")
	end)

	case("retargeting away and back does not revive an old hold", function()
		local state, a, b = fresh(), aAt(20), bAt(10)
		step(state, seen(0, a, { a, b }))
		step(state, seen(0.2, b, { a, b }))
		expect(step(state, lost(0.4, a, 0.3, { a, b })), 1, "searching")
	end)

	case("a replaced character never inherits seen, ally or a hold", function()
		local state, a = fresh(), aAt(10)
		step(state, seen(0, a, { a }))
		local replaced = player(1, lifeC, 10)
		local out = step(state, lost(0.2, replaced, 0, { replaced }))
		expect(out, 1, "searching")
		-- Ally memory: the old life was inside enter range, the new one sits in the band.
		local holder, b = fresh(), bAt(5)
		expect(step(holder, seen(0, b, { b, player(1, lifeA, ENTER) })), 1, "ally")
		expect(step(holder, seen(0.2, b, { b, player(1, lifeC, ENTER + 1) })), 1, "none")
	end)

	case("a stale target life gives no threat to anyone", function()
		local a, b = player(1, lifeC, 10), bAt(5)
		local frame = seen(0, aAt(10), { a, b })
		local out = step(fresh(), frame)
		expect(out, 1, "none"); expect(out, 2, "none")
	end)

	-- Ally uses range hysteresis: entering is near, leaving is farther.
	case("ally enters at the inclusive enter range only", function()
		local a = aAt(10)
		expect(step(fresh(), seen(0, a, { a, bAt(ENTER) })), 2, "ally")
		expect(step(fresh(), seen(0, a, { a, bAt(ENTER + 0.01) })), 2, "none")
	end)

	case("ally stays through the band and leaves past the exit range", function()
		local state, a = fresh(), aAt(10)
		expect(step(state, seen(0, a, { a, bAt(ENTER) })), 2, "ally")
		expect(step(state, seen(0.2, a, { a, bAt(EXIT) })), 2, "ally")
		expect(step(state, seen(0.4, a, { a, bAt(EXIT + 0.01) })), 2, "none")
		expect(step(state, seen(0.6, a, { a, bAt(EXIT) })), 2, "none")
		expect(step(state, seen(0.8, a, { a, bAt(ENTER) })), 2, "ally")
	end)

	case("ally is steady while the target's sight flickers and searches", function()
		local state, a, b = fresh(), aAt(10), bAt(20)
		expect(step(state, seen(0, a, { a, b })), 2, "ally")
		local out = step(state, lost(0.2, a, 0, { a, b }))
		expect(out, 2, "ally"); equal(out[2].changed, false)
		out = step(state, lost(1, a, 0, { a, b }))
		expect(out, 1, "searching"); expect(out, 2, "ally"); equal(out[2].changed, false)
		equal(out[2].searchEndsAt, nil)
	end)

	case("a former target in the band falls back to ally, beyond it to none", function()
		local state, b = fresh(), bAt(10)
		local inBand = aAt(ENTER + 1)
		step(state, seen(0, inBand, { inBand, b }))
		expect(step(state, seen(0.2, b, { inBand, b })), 1, "ally")
		local other, beyond = fresh(), aAt(EXIT + 1)
		step(other, seen(0, beyond, { beyond, b }))
		expect(step(other, seen(0.2, b, { beyond, b })), 1, "none")
	end)

	case("the end of a threat clears ally memory", function()
		local state, a = fresh(), aAt(10)
		step(state, seen(0, a, { a, bAt(ENTER) }))
		step(state, idle(0.2, "Retreat", { a, bAt(ENTER) }))
		expect(step(state, seen(0.4, a, { a, bAt(ENTER + 1) })), 2, "none")
	end)

	case("a dead or safe player is never ally", function()
		local a = aAt(10)
		expect(step(fresh(), seen(0, a, { a, bAt(5, { alive = false }) })), 2, "none")
		expect(step(fresh(), seen(0, a, { a, bAt(5, { safe = true }) })), 2, "none")
		expect(step(fresh(), seen(0, a, { a, bAt(5, { alive = "true" }) })), 2, "none")
	end)

	-- Invalid input must never throw inside a server step, and fails closed to none.
	case("garbage state or input returns an empty result without an error", function()
		for _, garbage in ipairs({ 1, "x", true, { players = 3 } }) do
			equal(next(Awareness.step(fresh(), garbage)), nil)
			equal(next(Awareness.step(garbage, idle(0, "Patrol", { aAt(1) }))), nil)
		end
		equal(next(Awareness.step(fresh(), nil)), nil)
		equal(next(Awareness.step(nil, nil)), nil)
	end)

	case("garbage input does not disturb memory", function()
		local state, a = fresh(), aAt(10)
		step(state, seen(0, a, { a }))
		Awareness.step(state, nil)
		Awareness.step(state, { players = "x" })
		expect(step(state, lost(0.2, a, 0, { a })), 1, "seen")
	end)

	case("a non-finite clock gives none for everyone, then recovers", function()
		for _, bad in ipairs({ NAN, INF, -INF, "1", false }) do
			local state, a, b = fresh(), aAt(10), bAt(10)
			step(state, seen(0, a, { a, b }))
			local frame = seen(1, a, { a, b })
			frame.now = bad
			local out = step(state, frame)
			expect(out, 1, "none"); expect(out, 2, "none")
			expect(step(state, seen(2, a, { a, b })), 1, "seen")
		end
	end)

	case("an unknown or missing mode gives none", function()
		local a = aAt(5)
		for _, bad in ipairs({ "hunt", "Bogus", 3, false }) do
			local frame = seen(0, a, { a })
			frame.mode = bad
			expect(step(fresh(), frame), 1, "none")
		end
		local frame = seen(0, a, { a })
		frame.mode = nil
		expect(step(fresh(), frame), 1, "none")
	end)

	case("a bad distance is not near", function()
		local a = aAt(10)
		for _, bad in ipairs({ NAN, INF, -1, "5", false }) do
			expect(step(fresh(), seen(0, a, { a, bAt(bad) })), 2, "none")
		end
		expect(step(fresh(), seen(0, a, { a, player(2, lifeB, nil) })), 2, "none")
	end)

	case("a bad distance leaves a held ally and cannot throw", function()
		local state, a = fresh(), aAt(10)
		expect(step(state, seen(0, a, { a, bAt(10) })), 2, "ally")
		expect(step(state, seen(0.2, a, { a, bAt(NAN) })), 2, "none")
	end)

	case("a target's own distance never decides seen", function()
		for _, odd in ipairs({ NAN, 500, -1 }) do
			local a = aAt(odd)
			expect(step(fresh(), seen(0, a, { a })), 1, "seen")
		end
	end)

	case("a bad last visible time ends the search for everyone", function()
		local a, b = aAt(10), bAt(10)
		for _, bad in ipairs({ NAN, INF, -INF, "0", false }) do
			local out = step(fresh(), lost(1, a, bad, { a, b }))
			expect(out, 1, "none"); expect(out, 2, "none")
		end
		local out = step(fresh(), lost(1, a, nil, { a, b }))
		expect(out, 1, "none"); expect(out, 2, "none")
	end)

	case("a bad telegraph deadline stays seen without an attack deadline", function()
		local a = aAt(5)
		for _, bad in ipairs({ NAN, INF, -1, 0, "1", false }) do
			local out = step(fresh(), seen(0, a, { a }, "Telegraph", bad))
			expect(out, 1, "seen"); equal(out[1].attackEndsAt, nil)
		end
	end)

	case("the attack deadline exists only in Telegraph", function()
		local a = aAt(5)
		equal(step(fresh(), seen(0, a, { a }, "Hunt", 5))[1].attackEndsAt, nil)
	end)

	case("a bad target identity gives no threat to anyone", function()
		local a, b = aAt(10), bAt(5)
		for _, bad in ipairs({ NAN, INF, "1", 99 }) do
			local frame = seen(0, a, { a, b })
			frame.targetId = bad
			local out = step(fresh(), frame)
			expect(out, 1, "none"); expect(out, 2, "none")
		end
		local frame = seen(0, a, { a, b })
		frame.targetId = nil
		expect(step(fresh(), frame), 1, "none")
		frame = seen(0, a, { a, b })
		frame.targetLife = nil
		expect(step(fresh(), frame), 1, "none")
		local unknownLife = player(1, nil, 10)
		frame = seen(0, unknownLife, { unknownLife })
		expect(step(fresh(), frame), 1, "none")
	end)

	case("a dead target gives no threat to anyone", function()
		local a, b = aAt(10, { alive = false }), bAt(5)
		local out = step(fresh(), seen(0, a, { a, b }))
		expect(out, 1, "none"); expect(out, 2, "none")
	end)

	case("bad player entries are skipped and the first duplicate wins", function()
		local a = aAt(10)
		local out = step(fresh(), seen(0, a, { 7, "x", { id = NAN }, { id = "2" }, { id = INF }, {}, a,
			player(1, lifeC, 500), bAt(20) }))
		expect(out, 1, "seen"); expect(out, 2, "ally")
		local count = 0
		for _ in pairs(out) do count += 1 end
		equal(count, 2)
	end)

	case("negative Studio user ids are valid identities", function()
		local a, b = player(-1, lifeA, 10), player(-2, lifeB, 20)
		local out = step(fresh(), seen(0, a, { a, b }))
		expect(out, -1, "seen"); expect(out, -2, "ally")
	end)

	-- The server clock may step back; truth wins over any debounce.
	case("time going backward cancels the hold instead of stretching it", function()
		local state, a = fresh(), aAt(10)
		step(state, seen(10, a, { a }))
		expect(step(state, lost(10.2, a, 10, { a })), 1, "seen")
		expect(step(state, lost(9, a, 8.5, { a })), 1, "searching")
	end)

	case("a countdown is never longer than the search after time goes backward", function()
		local state, a = fresh(), aAt(10)
		step(state, seen(10, a, { a }))
		step(state, lost(11, a, 10, { a }))
		local out = step(state, lost(5, a, 10, { a }))
		expect(out, 1, "searching")
		equal(out[1].searchEndsAt, 5 + SEARCH)
	end)

	case("a future last visible time cannot lengthen the countdown", function()
		local a = aAt(10)
		local out = step(fresh(), lost(1, a, 100, { a }))
		expect(out, 1, "searching"); equal(out[1].searchEndsAt, 1 + SEARCH)
	end)

	case("seen remains correct after time goes backward", function()
		local state, a = fresh(), aAt(10)
		step(state, seen(10, a, { a }))
		expect(step(state, seen(4, a, { a })), 1, "seen")
		expect(step(state, lost(4 + HOLD - 0.01, a, 4, { a })), 1, "seen")
	end)

	-- Removal.
	case("a removed target ends the threat for those remaining", function()
		local state, a, b = fresh(), aAt(10), bAt(10)
		step(state, seen(0, a, { a, b }))
		local out = step(state, seen(0.2, a, { b }))
		equal(out[1], nil); expect(out, 2, "none"); equal(out[2].changed, true)
	end)

	case("removed players leave no memory and return clean", function()
		local state, a, b = fresh(), aAt(10), bAt(50)
		step(state, seen(0, a, { a, b }))
		step(state, seen(0.2, a, { a, b }))
		step(state, seen(0.4, a, { a }))
		equal(state.players[2], nil)
		local out = step(state, seen(0.6, a, { a, b }))
		expect(out, 2, "none"); equal(out[2].changed, false)
		step(state, idle(0.8, "Patrol", {}))
		equal(next(state.players), nil)
	end)

	-- Result shape.
	case("changed reports every visible difference and nothing else", function()
		local state, a, b = fresh(), aAt(10), bAt(200)
		local out = step(state, idle(0, "Patrol", { a, b }))
		equal(out[1].changed, false)
		out = step(state, seen(0.2, a, { a, b }))
		equal(out[1].changed, true); equal(out[2].changed, false)
		out = step(state, seen(0.4, a, { a, b }))
		equal(out[1].changed, false)
		out = step(state, seen(0.6, a, { a, b }, "Telegraph", 2))
		equal(out[1].state, "seen"); equal(out[1].changed, true)
		out = step(state, seen(0.8, a, { a, b }, "Telegraph", 2))
		equal(out[1].changed, false)
	end)

	case("the snapshot is minimal, flat and holds only strings and finite numbers", function()
		local state, a, b = fresh(), aAt(10), bAt(20)
		local function verify(entry, expected)
			local snapshot = Awareness.toSnapshot(entry)
			local count = 0
			for key, value in pairs(snapshot) do
				count += 1
				assert(type(key) == "string", "non-string key")
				assert(type(value) == "string" or (type(value) == "number" and value == value
					and value ~= INF and value ~= -INF), "unsafe value at " .. key)
			end
			equal(count, expected)
			return snapshot
		end
		local out = step(state, seen(0, a, { a, b }, "Telegraph", 1.4))
		local telegraph = verify(out[1], 2)
		equal(telegraph.state, "seen"); equal(telegraph.attackEndsAt, 1.4)
		equal(verify(out[2], 1).state, "ally")
		out = step(state, lost(HOLD, a, 0, { a, b }))
		local search = verify(out[1], 2)
		equal(search.state, "searching"); equal(search.searchEndsAt, SEARCH)
		out = step(state, idle(1, "Retreat", { a, b }))
		equal(verify(out[1], 1).state, "none")
	end)

	case("a garbage result still snapshots to none", function()
		for _, bad in ipairs({ 1, "seen", true, {}, { state = "owned" },
			{ state = 3 } }) do
			equal(Awareness.toSnapshot(bad).state, "none")
		end
		equal(Awareness.toSnapshot(nil).state, "none")
		local odd = Awareness.toSnapshot({ state = "searching", searchEndsAt = NAN, attackEndsAt = 3 })
		equal(odd.searchEndsAt, nil); equal(odd.attackEndsAt, nil)
		equal(Awareness.toSnapshot({ state = "ally", searchEndsAt = 3, attackEndsAt = 3 }).searchEndsAt, nil)
	end)

	case("a caller changing a result cannot change the rule", function()
		local state, a = fresh(), aAt(10)
		local out = step(state, seen(0, a, { a }))
		out[1].state, out[1].changed = "none", "x"
		out = step(state, seen(0.2, a, { a }))
		expect(out, 1, "seen"); equal(out[1].changed, false)
	end)

	-- Determinism.
	case("the same inputs give the same outputs, whatever the player order", function()
		local function run(order)
			local state, a, b = fresh(), aAt(10), bAt(50)
			local players = order and { a, b } or { b, a }
			local trace = {}
			for _, frame in ipairs({ seen(0, a, players), lost(0.3, a, 0, players), lost(0.8, a, 0, players),
				seen(0.9, b, players), idle(1.1, "Retreat", players) }) do
				local out = step(state, frame)
				table.insert(trace, out[1].state .. tostring(out[1].searchEndsAt) .. out[2].state)
			end
			return table.concat(trace, "|")
		end
		equal(run(true), run(false))
		equal(run(true), run(true))
	end)

	case("two rule states do not share memory", function()
		local first, second, a = fresh(), fresh(), aAt(10)
		step(first, seen(0, a, { a }))
		expect(step(second, lost(0.2, a, 0, { a })), 1, "searching")
		expect(step(first, lost(0.2, a, 0, { a })), 1, "seen")
	end)

	-- Contracts with the real modules and the constants table.
	case("constants live in one frozen table and stay coherent with the real rules", function()
		assert(table.isfrozen(CONST), "constants must be frozen")
		assert(type(HOLD) == "number" and HOLD > 0 and HOLD < SEARCH, "hold must be shorter than search")
		assert(HOLD >= 0.4 + 1e-3, "hold must absorb two 0.2 second samples")
		local night = Rules.resolveCreatureProfile("Silueta", "Night", true)
		assert(ENTER > night.detectionRange, "ally must arrive before a retarget is possible")
		assert(EXIT > ENTER, "exit must exceed enter")
		assert(EXIT <= Rules.CHASE_RANGE, "exit must stay inside chase range")
	end)

	case("the real Hunt expires exactly when the search deadline says", function()
		local state, a, b = fresh(), aAt(10), bAt(20)
		local hunt = Hunt.new({ id = 1, life = lifeA, position = Vector3.zero }, 0)
		local hidden = { id = 1, life = lifeA, valid = true, visible = false }
		step(state, seen(0, a, { a, b }))
		for _, now in ipairs({ 0.2, 0.4, 0.6, 0.8, 1, 1.2, 1.4, 1.49 }) do
			equal(Hunt.step(hunt, now, hidden, {}).expired, false)
			local out = step(state, lost(now, a, hunt.lastVisibleAt, { a, b }))
			expect(out, 1, now < HOLD and "seen" or "searching"); expect(out, 2, "ally")
			if now >= HOLD then equal(out[1].searchEndsAt, hunt.lastVisibleAt + SEARCH) end
		end
		equal(Hunt.step(hunt, 1.5, hidden, {}).expired, true)
		local out = step(state, lost(1.5, a, hunt.lastVisibleAt, { a, b }))
		expect(out, 1, "none"); expect(out, 2, "none")
	end)

	case("the real Hunt retarget flips both in the step it switches", function()
		local state, a, b = fresh(), aAt(20), bAt(16)
		local hunt = Hunt.new({ id = 1, life = lifeA, position = Vector3.zero }, 0)
		local current = { id = 1, life = lifeA, valid = true, visible = true, distance = 20,
			position = Vector3.zero }
		local challenger = { id = 2, life = lifeB, valid = true, visible = true, distance = 16,
			position = Vector3.one }
		local players = { a, b }
		for _, now in ipairs({ 0, 0.4, 0.8 }) do
			local decision = Hunt.step(hunt, now, current, { challenger })
			local frame = { now = now, mode = "Hunt", targetId = decision.id, targetLife = decision.life,
				targetVisible = true, lastVisibleAt = hunt.lastVisibleAt, players = players }
			local out = step(state, frame)
			if now < 0.8 then
				expect(out, 1, "seen"); expect(out, 2, "ally")
			else
				equal(decision.switched, true)
				expect(out, 1, "ally"); expect(out, 2, "seen")
			end
		end
	end)

	case("the module source stays pure", function()
		assert(type(source) == "string" and #source > 0, "module source is required")
		for _, token in ipairs({ "game", "workspace", "script", "Instance", "require", "task", "tick",
			"wait", "os", "time", "GetService", "Players", "RemoteEvent", "FireClient", "CFrame",
			"Vector3", "DateTime", "math%.random", "Random" }) do
			assert(not string.find(source, "%f[%w_]" .. token .. "%f[^%w_]"), "impure token: " .. token)
		end
	end)

	return result
end

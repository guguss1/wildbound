-- Invoke with require(freshTestClone)(require(freshStalkClone), freshStalkClone.Source).
-- AI rework (user, 2026-11-13, S1 "Te ronda": "Se va acercando a la zona donde estás y te sigue de lejos, apareciendo y
-- desapareciendo, hasta que decide atacar."). Pure: positions, the clock, the phase and one roll are passed in.
return function(Stalk, source)
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
	local C = Stalk.CONSTANTS
	local function away(out, x, z) return math.sqrt((out.x - x) ^ 2 + (out.z - z) ^ 2) end
	-- The owner stands at (40, -60); she is at (gx, gz).
	local function input(now, gx, gz, extra)
		local value = { now = now, phase = "Day", roll = 0, gx = gx, gz = gz, px = 40, pz = -60, present = true, hidden = false, quietUntil = 0 }
		for key, item in pairs(extra or {}) do value[key] = item end
		return value
	end

	case("constants are frozen; she stalks from beyond the reach of a strike and waits less at night", function()
		assert(table.isfrozen(C) and table.isfrozen(C.WAIT), "frozen")
		assert(C.RING > C.CLOSE and C.CLOSE > 7, "the ring is outside the commit distance, which is outside a strike")
		assert(C.WAIT.Night[2] < C.WAIT.Day[1], "night commits sooner than the quickest day")
		assert(C.QUIET > 0 and C.FAR > 0 and C.ARC > 0)
		for _, wait in pairs(C.WAIT) do assert(wait[1] > 0 and wait[2] >= wait[1]) end
	end)

	case("no owner in the forest, or the quiet after a chase: she does not stalk, and the wait starts over", function()
		local state = Stalk.new()
		assert(Stalk.step(state, input(0, 0, -85)) ~= nil)
		equal(Stalk.step(state, input(1, 0, -85, { present = false })), nil, "owner gone")
		equal(state.commitAt, nil, "the wait is forgotten")
		equal(Stalk.step(state, input(2, 0, -85, { quietUntil = 10 })), nil, "quiet")
		assert(Stalk.step(state, input(10, 0, -85, { quietUntil = 10 })) ~= nil, "the quiet is over")
	end)

	case("from far away she hurries to the ring round her owner, and does not attack yet", function()
		local out = Stalk.step(Stalk.new(), input(0, 0, -200))
		assert(math.abs(away(out, 40, -60) - C.RING) < 1e-6, "the goal is on the ring")
		equal(out.pace, "hunt"); equal(out.hold, true); equal(out.commit, false)
	end)

	case("on the ring she circles her owner at a walk, always to the same side", function()
		local state = Stalk.new()
		local gx, gz = 40 + C.RING, -60
		local out = Stalk.step(state, input(0, gx, gz))
		equal(out.pace, "investigate"); equal(out.hold, true)
		assert(math.abs(away(out, 40, -60) - C.RING) < 1e-6, "still on the ring")
		assert(math.sqrt((out.x - gx) ^ 2 + (out.z - gz) ^ 2) > 5, "the goal is farther round the ring, so she keeps moving")
		local first = math.atan2(out.z + 60, out.x - 40)
		local next = Stalk.step(state, input(0.2, out.x, out.z))
		local second = math.atan2(next.z + 60, next.x - 40)
		assert((first < 0) == (second - first < 0), "the same way round on the next step")
	end)

	case("when her wait is over she commits: she walks at her owner and may attack", function()
		local state = Stalk.new()
		Stalk.step(state, input(100, 40 + C.RING, -60))
		local before = Stalk.step(state, input(100 + C.WAIT.Day[1] - 0.2, 40 + C.RING, -60))
		equal(before.commit, false, "not yet")
		local out = Stalk.step(state, input(100 + C.WAIT.Day[1], 40 + C.RING, -60))
		equal(out.commit, true); equal(out.hold, false); equal(out.pace, "hunt")
		equal(out.x, 40); equal(out.z, -60)
		equal(Stalk.step(state, input(101 + C.WAIT.Day[1], 60, -60)).commit, true, "she stays committed")
	end)

	case("the roll spreads the wait, and night waits less than day", function()
		local long = Stalk.new()
		Stalk.step(long, input(0, 0, -200, { roll = 0.999 }))
		assert(long.commitAt > C.WAIT.Day[2] - 0.1 and long.commitAt <= C.WAIT.Day[2])
		local night = Stalk.new()
		Stalk.step(night, input(0, 0, -200, { roll = 0.999, phase = "Night" }))
		assert(night.commitAt <= C.WAIT.Night[2] and night.commitAt < long.commitAt)
	end)

	case("an owner who walks up to her ends the stalk at once", function()
		local out = Stalk.step(Stalk.new(), input(0, 40 + C.CLOSE - 1, -60))
		equal(out.commit, true); equal(out.hold, false)
	end)

	case("a hidden owner is never walked at: she circles where they were, and waits again when they come out", function()
		local state = Stalk.new()
		Stalk.step(state, input(0, 40 + C.RING, -60))
		local late = C.WAIT.Day[2] + 5
		-- the hide spot moved the owner to (44, -57); she keeps circling the place they stood at
		local out = Stalk.step(state, input(late, 40 + C.RING, -60, { hidden = true, px = 44, pz = -57 }))
		equal(out.commit, false, "no commit on a hidden owner, however long she waited"); equal(out.hold, true)
		assert(math.abs(away(out, 40, -60) - C.RING) < 1e-6, "round where they were, not the spot itself")
		local close = Stalk.step(state, input(late + 0.2, 40 + C.CLOSE - 1, -60, { hidden = true, px = 44, pz = -57 }))
		equal(close.commit, false, "not even from close by")
		local out2 = Stalk.step(state, input(late + 0.4, 40 + C.RING, -60))
		equal(out2.commit, false, "coming out does not trigger her at once")
		assert(state.commitAt > late + 0.4, "she waits a moment more")
	end)

	-- Verification finding: an owner she can never start a chase on (on the spawn pad, on a ledge above her) was
	-- walked into and stood in for as long as they stayed. A commit that brings no chase is given up and she waits again.
	case("a commit that never becomes a chase is given up after COMMIT_SECONDS, and she stalks again", function()
		local state = Stalk.new()
		Stalk.step(state, input(0, 40 + C.RING, -60))
		local at = C.WAIT.Day[1]
		equal(Stalk.step(state, input(at, 40 + C.RING, -60)).commit, true)
		equal(Stalk.step(state, input(at + C.COMMIT_SECONDS - 0.2, 60, -60)).commit, true, "still coming")
		local out = Stalk.step(state, input(at + C.COMMIT_SECONDS, 60, -60))
		equal(out.commit, false, "given up"); equal(out.hold, true)
		assert(state.commitAt > at + C.COMMIT_SECONDS, "a new wait")
		assert(C.COMMIT_SECONDS >= 6, "long enough to cross the ring and start a chase")
	end)

	case("bad numbers never stalk", function()
		local state = Stalk.new()
		equal(Stalk.step(state, input(0 / 0, 0, 0)), nil)
		equal(Stalk.step(state, input(0, 0 / 0, 0)), nil)
		equal(Stalk.step(state, input(0, 0, 0, { px = math.huge })), nil)
		equal(Stalk.step(nil, input(0, 0, 0)), nil)
	end)

	case("purity: no services, no clock, no randomness, no require", function()
		assert(type(source) == "string" and #source > 0, "source given")
		for _, banned in ipairs({ "game:", "workspace", "require(", "task.", "os.clock", "os.time", "tick(", "Random", "math.random" }) do
			assert(not source:find(banned, 1, true), "contains " .. banned)
		end
	end)

	return result
end

-- Invoke with require(freshTestClone)(require(freshCaptureClone), freshCaptureClone.Source) in Studio
-- Edit or Server. Time and positions are injected. CAP numbers refer to docs/mechanics/wildbound-capture.md.
-- Delivery A (H1): a full calm meter opens a timed seal step; only a press inside the band completes. The rule names
-- reasons only; the words live in WildboundText (tests/WildboundText_Test.luau).
return function(CaptureSession, source)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "Expected " .. tostring(expected)
			.. ", got " .. tostring(actual))
	end
	local function near(actual, expected, tolerance, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-6),
			(label and label .. ": " or "") .. "Expected about " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function count(map)
		local total = 0
		for _ in pairs(map) do total += 1 end
		return total
	end

	local C = CaptureSession.CONSTANTS
	local NAN, INF = 0 / 0, math.huge
	local lifeA, lifeB = {}, {}
	local ID, OTHER = "Creature:1", "Creature:2"

	-- Lumipol at the origin, player on its orbit, ring owned by player 1.
	local function input(extra)
		local entry = { playerKey = 1, encounterId = ID, dir = 1, lumipolX = 0, lumipolZ = 0, now = 0,
			alive = true, life = lifeA, distance = 7, x = 7, y = 3, z = 0, encounterStatus = "Open",
			bagRoom = true, collectionRoom = true }
		for key, value in pairs(extra or {}) do entry[key] = value end
		return entry
	end
	local function start(capture, extra)
		local ok, view = capture:begin(input(extra))
		assert(ok == true, "start refused: " .. tostring(view))
		return view
	end
	local function at(now, x, z, extra)
		local entry = { now = now, alive = true, life = lifeA, x = x, y = 3, z = z,
			bagRoom = true, collectionRoom = true }
		for key, value in pairs(extra or {}) do entry[key] = value end
		return entry
	end
	local function fresh() return CaptureSession.new() end
	local function center(view, now)
		return CaptureSession.ringCenter(view.ring, now - view.ring.startedAt)
	end
	-- The middle of an open seal band, in server seconds.
	local function sealMiddle(seal)
		return seal.startedAt + seal.sweep * (seal.lo + seal.hi) / 2
	end
	-- Presses the seal at the band's middle for the session's own player.
	local function hit(capture, token, seal, extra)
		local session = capture.sessions[token]
		local obs = { now = sealMiddle(seal), alive = true, life = session and session.life, bagRoom = true,
			collectionRoom = true }
		for key, value in pairs(extra or {}) do obs[key] = value end
		return capture:seal(token, session and session.playerKey, obs)
	end
	-- Samples at the fixed step from step `first`, placing the player with place(now). Stops on an ending. A full
	-- meter opens the seal step; run presses it at the band's middle and returns that ending with the calm time.
	local function run(capture, view, first, last, place)
		local out
		for k = first, last do
			local now = view.ring.startedAt + k * C.SAMPLE
			local x, z, extra = place(now, k)
			out = capture:sample(view.token, at(now, x, z, extra))
			if not out or out.phase ~= "Active" then return out, now end
			if out.stage == "Seal" then
				local _, ended = hit(capture, view.token, out.seal)
				return ended, now
			end
		end
		return out, view.ring.startedAt + last * C.SAMPLE
	end
	local function followRing(view)
		return function(now) return center(view, now) end
	end
	local function refused(capture, extra, reason, label)
		local ok, why = capture:begin(input(extra))
		equal(ok, false, label)
		equal(why, reason, label)
	end
	local function nothingHeld(capture)
		equal(count(capture.sessions), 0, "sessions")
		equal(count(capture.reservations), 0, "reservations")
		equal(count(capture.byPlayer), 0, "byPlayer")
	end

	-- Starting a capture.
	case("CAP-01: a valid start reserves the encounter and centers the ring on the player", function()
		local capture = fresh()
		local view = start(capture)
		equal(type(view.token), "string")
		equal(view.phase, "Active")
		equal(view.calm, 0)
		equal(view.deadline, C.TIME_LIMIT)
		equal(capture.reservations[ID], view.token)
		equal(capture:encounterState(ID, 0), "Reserved")
		local x, z = center(view, 0)
		near(x, 7); near(z, 0)
	end)

	case("CAP-02: bad context, NaN and infinite values refuse and reserve nothing", function()
		local bad = {
			{ alive = false }, { alive = 1 }, { alive = "true" },
			{ distance = C.START_RANGE + 0.01 }, { distance = NAN }, { distance = INF }, { distance = -1 },
			{ distance = "7" }, { x = NAN }, { x = INF }, { x = "7" }, { y = NAN }, { y = -INF }, { z = NAN },
			{ z = INF }, { now = NAN }, { now = INF }, { now = "0" }, { lumipolX = NAN }, { lumipolZ = INF },
			{ lumipolX = "0" }, { dir = 0 }, { dir = 2 }, { dir = NAN }, { dir = "1" }, { life = NAN },
		}
		for index, extra in ipairs(bad) do
			local capture = fresh()
			refused(capture, extra, "InvalidContext", "bad " .. index)
			nothingHeld(capture)
		end
		local missing = { "alive", "distance", "x", "y", "z", "now", "lumipolX", "lumipolZ", "dir", "life" }
		for _, field in ipairs(missing) do
			local capture, entry = fresh(), input()
			entry[field] = nil
			local ok, why = capture:begin(entry)
			equal(ok, false, field); equal(why, "InvalidContext", field)
			nothingHeld(capture)
		end
	end)

	case("start range is inclusive at the limit", function()
		start(fresh(), { distance = C.START_RANGE, x = C.START_RANGE })
	end)

	case("the real position must agree with the injected distance", function()
		local capture = fresh()
		refused(capture, { distance = 5, x = C.START_RANGE + 0.01 }, "InvalidContext")
		nothingHeld(capture)
	end)

	case("a non-table start and malformed keys refuse without an error", function()
		local capture = fresh()
		for _, garbage in ipairs({ 1, "x", true }) do
			local ok, why = capture:begin(garbage)
			equal(ok, false); equal(why, "InvalidContext")
		end
		equal((capture:begin(nil)), false)
		for _, key in ipairs({ NAN, INF, 1.5, "", string.rep("k", 129), {}, true }) do
			refused(capture, { playerKey = key }, "InvalidPlayer", tostring(key))
		end
		local noKey = input(); noKey.playerKey = nil
		equal(select(2, capture:begin(noKey)), "InvalidPlayer")
		for _, id in ipairs({ "", string.rep("e", 129), 7, {} }) do
			refused(capture, { encounterId = id }, "InvalidEncounter", tostring(id))
		end
		local noId = input(); noId.encounterId = nil
		equal(select(2, capture:begin(noId)), "InvalidEncounter")
		nothingHeld(capture)
	end)

	case("CAP-03: a second player on a reserved encounter gets Reserved and the first is unaffected", function()
		local capture = fresh()
		local first = start(capture)
		refused(capture, { playerKey = 2, life = lifeB }, "Reserved")
		equal(capture.reservations[ID], first.token)
		local out = capture:sample(first.token, at(0.2, center(first, 0.2)))
		equal(out.phase, "Active")
		near(out.calm, 0.2)
	end)

	case("CAP-04: the same player cannot hold two sessions", function()
		local capture = fresh()
		local view = start(capture)
		refused(capture, nil, "AlreadyCapturing", "same encounter")
		refused(capture, { encounterId = OTHER }, "AlreadyCapturing", "other encounter")
		equal(capture.reservations[OTHER], nil)
		equal(count(capture.sessions), 1)
		equal(capture.reservations[ID], view.token)
	end)

	case("encounter status comes from the server and fails closed", function()
		local capture = fresh()
		refused(capture, { encounterStatus = "Claimed" }, "AlreadyClaimed")
		for _, status in ipairs({ "Missing", "open", "", 1 }) do
			refused(capture, { encounterStatus = status }, "InvalidEncounter", tostring(status))
		end
		local entry = input(); entry.encounterStatus = nil
		equal(select(2, capture:begin(entry)), "InvalidEncounter")
		nothingHeld(capture)
	end)

	case("slot refusals pass through and unknown ones fail closed", function()
		local capture = fresh()
		refused(capture, { slotRefusal = "FirstCaptureOnly" }, "FirstCaptureOnly")
		refused(capture, { slotRefusal = "FirstCapturePending" }, "FirstCapturePending")
		refused(capture, { slotRefusal = "Anything" }, "InvalidContext")
		refused(capture, { slotRefusal = 1 }, "InvalidContext")
		nothingHeld(capture)
	end)

	case("bag and collection room must be an explicit true at start", function()
		local capture = fresh()
		refused(capture, { bagRoom = false }, "BackpackFull")
		refused(capture, { collectionRoom = false }, "CollectionFull")
		local noBag, noCollection = input(), input()
		noBag.bagRoom, noCollection.collectionRoom = nil, nil
		equal(select(2, capture:begin(noBag)), "BackpackFull")
		equal(select(2, capture:begin(noCollection)), "CollectionFull")
		nothingHeld(capture)
	end)

	case("start refusals follow the design order", function()
		local capture = fresh()
		start(capture, { playerKey = 9, life = lifeB, encounterId = OTHER })
		-- Each row breaks everything after it, so only the named check can answer.
		refused(capture, { playerKey = 9, alive = false }, "AlreadyCapturing")
		refused(capture, { alive = false, encounterStatus = "Claimed" }, "InvalidContext")
		refused(capture, { encounterStatus = "Claimed", encounterId = OTHER }, "AlreadyClaimed")
		refused(capture, { encounterId = OTHER, slotRefusal = "FirstCaptureOnly" }, "Reserved")
		refused(capture, { slotRefusal = "FirstCaptureOnly", bagRoom = false }, "FirstCaptureOnly")
		refused(capture, { bagRoom = false, collectionRoom = false }, "BackpackFull")
	end)

	-- The ring rule.
	case("CAP-05: standing still never completes from any start distance, either direction", function()
		for _, distance in ipairs({ 0, 0.5, 1, 2, 2.5, 3, 4, 5, 5.5, 7, 9, 9.5, 10 }) do
			for _, dir in ipairs({ 1, -1 }) do
				local capture = fresh()
				local view = start(capture, { distance = distance, x = distance, dir = dir })
				local out, ended = run(capture, view, 1, 80, function() return distance, 0 end)
				local label = distance .. "/" .. dir
				equal(out.reason, "LeftRing", label)
				equal(out.grant, false, label)
				assert(ended >= 5.6 and ended <= 6.4, label .. " ended at " .. ended)
			end
		end
	end)

	case("standing on the Lumipol from the start does not stay inside the ring", function()
		local capture = fresh()
		local view = start(capture, { distance = 0, x = 0 })
		local out = run(capture, view, 1, 80, function() return 0, 0 end)
		equal(out.reason, "LeftRing")
	end)

	case("no fixed spot stays inside forever: the orbit center is outside the ring", function()
		assert(C.ORBIT_MIN > C.RING_RADIUS_SERVER, "orbit must exceed the tested radius")
		for _, distance in ipairs({ 0, 3, C.ORBIT_MIN, 7, C.ORBIT_MAX, C.START_RANGE }) do
			local capture = fresh()
			local view = start(capture, { distance = distance, x = distance })
			local pivotX, pivotZ = view.ring.pivotX, view.ring.pivotZ
			-- Half a second, so the walk there reads as a walk and not as a jump.
			local out = capture:sample(view.token, at(0.5, pivotX, pivotZ))
			equal(out.phase, "Active", "start " .. distance)
			equal(out.inside, false, "start " .. distance)
		end
	end)

	case("CAP-06: one 3-stud step at 3 s completes between 4.5 and 6 s", function()
		for _, distance in ipairs({ C.ORBIT_MIN, 7, C.ORBIT_MAX }) do
			for _, dir in ipairs({ 1, -1 }) do
				local capture = fresh()
				local view = start(capture, { distance = distance, x = distance, dir = dir })
				local x, z = distance, 0
				local out, ended = run(capture, view, 1, 60, function(now, k)
					if k == 15 then
						local cx, cz = center(view, now)
						local length = math.sqrt((cx - x) ^ 2 + (cz - z) ^ 2)
						x, z = x + 3 * (cx - x) / length, z + 3 * (cz - z) / length
					end
					return x, z
				end)
				equal(out.reason, "Completed", distance .. "/" .. dir)
				equal(out.grant, true)
				assert(ended >= C.CALM_REQUIRED and ended <= 6, "completed at " .. ended)
			end
		end
	end)

	case("CAP-07: continuous fast movement inside the ring times out and the meter never grows", function()
		local capture = fresh()
		local view = start(capture)
		local sign = 1
		local out, ended = run(capture, view, 1, 80, function(now)
			sign = -sign
			local cx, cz = center(view, now)
			return cx + sign, cz
		end)
		equal(out.reason, "TimedOut")
		near(ended, C.TIME_LIMIT, C.SAMPLE + 1e-6)
		-- Never outside, so nothing could have drained: zero now means it never grew.
		equal(out.calm, 0)
		equal(out.outsideFor, 0)
	end)

	case("CAP-08: walking slowly with the ring still fills the meter", function()
		local capture = fresh()
		local view = start(capture)
		local out, ended = run(capture, view, 1, 40, followRing(view))
		equal(out.reason, "Completed")
		near(ended, C.CALM_REQUIRED, C.SAMPLE + 1e-6)
	end)

	case("the movement limit is exclusive at exactly the still speed", function()
		local capture = fresh()
		local view = start(capture)
		local out = capture:sample(view.token, at(0.2, 7 + C.STILL_SPEED * 0.2, 0))
		equal(out.moving, false); near(out.calm, 0.2)
		local other = fresh()
		local second = start(other)
		out = other:sample(second.token, at(0.2, 7 + C.STILL_SPEED * 0.2 + 0.01, 0))
		equal(out.moving, true); equal(out.calm, 0)
	end)

	-- Stillness over a short window (fix found in W5): shuffling a stud back and forth stays under the per-sample
	-- speed limit, so the path length over the last STILL_WINDOW seconds decides as well.
	local function shuffle(view, amplitude)
		return function(now, k)
			local cx, cz = center(view, now)
			return cx + (k % 2 == 0 and amplitude or -amplitude), cz
		end
	end
	case("CAP-38: constants for the stillness window", function()
		equal(C.STILL_WINDOW, 1); equal(C.STILL_PATH_RATE, 3)
	end)
	case("CAP-38: shuffling back and forth under the per-sample limit never fills the meter", function()
		local capture = fresh()
		local view = start(capture)
		local out = run(capture, view, 1, 70, shuffle(view, 0.35))
		equal(out.phase, "Failed"); equal(out.reason, "TimedOut")
	end)
	case("CAP-38: the shuffle reads as moving once the window holds three steps", function()
		local capture = fresh()
		local view = start(capture)
		local out = run(capture, view, 1, 10, shuffle(view, 0.35))
		equal(out.moving, true)
		assert(out.calm < 0.7, "calm was " .. tostring(out.calm))
	end)
	case("CAP-38: a small sway on top of following the ring still counts as still", function()
		local capture = fresh()
		local view = start(capture)
		local out, ended = run(capture, view, 1, 40, shuffle(view, 0.2))
		equal(out.reason, "Completed")
		near(ended, C.CALM_REQUIRED, C.SAMPLE + 1e-6)
	end)
	case("CAP-38: after the shuffle stops, stillness resumes once the window has passed", function()
		local capture = fresh()
		local view = start(capture)
		local out = run(capture, view, 1, 10, shuffle(view, 0.35))
		equal(out.moving, true)
		out = run(capture, view, 11, 18, followRing(view))
		equal(out.moving, false)
	end)

	case("CAP-09: 2.4 s outside survives, costs 1.2 of the meter, and resets on return", function()
		local capture = fresh()
		local view = start(capture)
		local out = run(capture, view, 1, 10, followRing(view))
		near(out.calm, 2)
		out = run(capture, view, 11, 22, function(now)
			local cx, cz = center(view, now)
			return cx + 6, cz
		end)
		equal(out.phase, "Active"); equal(out.inside, false)
		near(out.calm, 2 - 2.4 * C.OUTSIDE_DRAIN)
		near(out.outsideFor, 2.4)
		out = run(capture, view, 23, 23, followRing(view))
		equal(out.inside, true); equal(out.outsideFor, 0)
		near(out.calm, 2 - 2.4 * C.OUTSIDE_DRAIN)
	end)

	case("the meter drains no lower than zero and leaving ends at exactly the limit", function()
		local capture = fresh()
		local view = start(capture)
		local out = run(capture, view, 1, 12, function(now)
			local cx, cz = center(view, now)
			return cx + 6, cz
		end)
		equal(out.calm, 0)
		near(out.outsideFor, 2.4)
		local cx, cz = center(view, 2.5)
		out = capture:sample(view.token, at(2.5, cx + 6, cz))
		equal(out.reason, "LeftRing")
		equal(out.grant, false)
	end)

	case("CAP-10: an implausible jump is TooFar, and exactly the limit is not", function()
		local capture = fresh()
		local view = start(capture)
		equal(capture:sample(view.token, at(0.2, 7, 8)).phase, "Active")
		capture = fresh()
		view = start(capture)
		local out = capture:sample(view.token, at(0.2, 7, 8.01))
		equal(out.reason, "TooFar"); equal(out.grant, false)
	end)

	case("CAP-10: vertical distance from the start is TooFar past the limit, up and down", function()
		for _, offset in ipairs({ 8.01, -8.01 }) do
			local capture = fresh()
			local view = start(capture)
			equal(capture:sample(view.token, at(0.2, 7, 0, { y = 3 + offset })).reason, "TooFar")
		end
		for _, offset in ipairs({ 8, -8 }) do
			local capture = fresh()
			local view = start(capture)
			equal(capture:sample(view.token, at(0.2, 7, 0, { y = 3 + offset })).phase, "Active")
		end
	end)

	case("CAP-10: horizontal distance from the Lumipol is TooFar past the limit", function()
		local capture = fresh()
		local view = start(capture)
		for k, x in ipairs({ 13, 18 }) do
			equal(capture:sample(view.token, at(k * 0.2, x, 0)).phase, "Active", "x " .. x)
		end
		equal(capture:sample(view.token, at(0.6, 18.01, 0)).reason, "TooFar")
	end)

	case("CAP-11: a 5 s gap adds at most one capped sample and pushes the deadline", function()
		local capture = fresh()
		local view = start(capture)
		local x, z = center(view, 5)
		-- Stay put relative to the ring's new place: the gap makes this a slow move, not a jump.
		local out = capture:sample(view.token, at(5, x, z))
		equal(out.phase, "Active")
		near(out.calm, C.MAX_ELAPSED)
		near(out.deadline, C.TIME_LIMIT + C.MAX_STALL_EXTENSION)
	end)

	case("elapsed under the cap counts fully, so real step jitter loses no calm", function()
		assert(C.MAX_ELAPSED >= 0.217, "the guardian step reaches 0.217 s in the server source")
		local capture = fresh()
		local view = start(capture)
		local x, z = center(view, 0.217)
		near(capture:sample(view.token, at(0.217, x, z)).calm, 0.217)
	end)

	case("a stall under the threshold leaves the deadline alone and one over pushes it once", function()
		local capture = fresh()
		local view = start(capture)
		equal(capture:sample(view.token, at(C.STALL_AFTER, 7, 0)).deadline, C.TIME_LIMIT)
		local out = capture:sample(view.token, at(C.STALL_AFTER + 0.6, 7, 0))
		near(out.deadline, C.TIME_LIMIT + 0.6)
		out = capture:sample(view.token, at(C.STALL_AFTER + 0.8, 7, 0))
		near(out.deadline, C.TIME_LIMIT + 0.6)
	end)

	case("a walking player is not punished by a stall", function()
		local capture = fresh()
		local view = start(capture)
		equal(capture:sample(view.token, at(1, 7 - 16, 0)).phase, "Active")
	end)

	case("endless stalls cannot hold the encounter past the hard limit", function()
		local capture = fresh()
		local view = start(capture)
		local sign, out, ended = 1, nil, nil
		for k = 1, 40 do
			sign = -sign
			local cx, cz = center(view, k)
			out, ended = capture:sample(view.token, at(k, cx + sign * 3, cz)), k
			if out.phase ~= "Active" then break end
		end
		equal(out.reason, "TimedOut")
		assert(ended <= C.TIME_LIMIT + C.MAX_STALL_EXTENSION, "held until " .. ended)
		nothingHeld(capture)
	end)

	case("sample spam at one instant adds nothing", function()
		local capture = fresh()
		local view = start(capture)
		for _ = 1, 200 do
			local out = capture:sample(view.token, at(0, 7, 0))
			equal(out.phase, "Active"); equal(out.calm, 0)
		end
	end)

	case("the meter can never fill faster than real seconds", function()
		local capture = fresh()
		local view = start(capture)
		local out, ended
		for k = 1, 200 do
			ended = k * 0.05
			local x, z = center(view, ended)
			out = capture:sample(view.token, at(ended, x, z))
			if out.phase ~= "Active" or out.stage == "Seal" then break end
		end
		equal(out.stage, "Seal")
		assert(ended + 1e-6 >= C.CALM_REQUIRED, "the seal opened at " .. ended)
	end)

	-- Who may end what.
	case("CAP-12: wrong owner and stale or malformed tokens cancel nothing", function()
		local capture = fresh()
		local view = start(capture)
		for _, token in ipairs({ "", "cap:999", string.rep("t", 129), 1, NAN, {}, true }) do
			local ok, why = capture:cancel(token, 1, 0.2)
			equal(ok, false); equal(why, "InvalidToken")
		end
		equal((capture:cancel(nil, 1, 0.2)), false)
		local ok, why = capture:cancel(view.token, 2, 0.2)
		equal(ok, false); equal(why, "InvalidToken")
		equal((capture:cancel(view.token, nil, 0.2)), false)
		equal(capture.reservations[ID], view.token)
		equal(capture:sample(view.token, at(0.2, 7, 0)).phase, "Active")
	end)

	case("cancel by the owner ends once and spam does nothing", function()
		local capture = fresh()
		local view = start(capture)
		local ok, out = capture:cancel(view.token, 1, 1)
		equal(ok, true)
		equal(out.phase, "Cancelled"); equal(out.reason, "Cancelled"); equal(out.grant, false)
		equal(out.spook, true); equal(out.notice, nil)
		nothingHeld(capture)
		for _ = 1, 20 do
			local again, why = capture:cancel(view.token, 1, 1.1)
			equal(again, false); equal(why, "InvalidToken")
		end
		equal(capture:sample(view.token, at(1.2, 7, 0)), nil)
	end)

	case("cancel with a bad clock still ends and stamps from the last sample", function()
		for _, now in ipairs({ NAN, INF, -5 }) do
			local capture = fresh()
			local view = start(capture, { now = 10 })
			local ok, out = capture:cancel(view.token, 1, now)
			equal(ok, true)
			equal(out.spookUntil, 10 + C.SPOOK_SECONDS)
			equal(out.retryAt, 10 + C.RETRY_COOLDOWN)
		end
	end)

	case("CAP-13: a strike ends the capture on the next sample with no grant", function()
		local capture = fresh()
		local view = start(capture)
		equal(capture:notifyStruck(1), true)
		local out = capture:sample(view.token, at(0.2, 7, 0))
		equal(out.reason, "Struck"); equal(out.grant, false); equal(out.spook, true)
		nothingHeld(capture)
	end)

	case("a strike without a session is refused and does not carry into the next one", function()
		local capture = fresh()
		equal(capture:notifyStruck(1), false)
		equal(capture:notifyStruck(nil), false)
		equal(capture:notifyStruck(NAN), false)
		local view = start(capture)
		equal(capture:sample(view.token, at(0.2, 7, 0)).phase, "Active")
	end)

	case("a strike beats a full meter in the same sample", function()
		local capture = fresh()
		local view = start(capture)
		run(capture, view, 1, 22, followRing(view))
		capture:notifyStruck(1)
		local out = run(capture, view, 23, 23, followRing(view))
		equal(out.reason, "Struck"); equal(out.grant, false)
	end)

	case("the sample order holds: Defeated, then TooFar, then Struck, then TimedOut", function()
		local function strikeThenSample(extra, x, now)
			local capture = fresh()
			local view = start(capture)
			capture:notifyStruck(1)
			return capture:sample(view.token, at(now or 0.2, x or 7, 0, extra)).reason
		end
		equal(strikeThenSample({ alive = false }, 99), "Defeated")
		equal(strikeThenSample(nil, 99), "TooFar")
		-- Reach the deadline without a stall, so only the strike and the deadline compete.
		local capture = fresh()
		local view = start(capture)
		local out = run(capture, view, 1, C.TIME_LIMIT / C.SAMPLE - 1, function(now, k)
			local cx, cz = center(view, now)
			return cx + (k % 2 == 0 and 1 or -1), cz
		end)
		equal(out.phase, "Active")
		capture:notifyStruck(1)
		equal(capture:sample(view.token, at(C.TIME_LIMIT, center(view, C.TIME_LIMIT))).reason, "Struck")
	end)

	case("CAP-14: a changed life or a dead player ends as Defeated", function()
		for _, extra in ipairs({ { life = lifeB }, { alive = false }, { alive = 1 } }) do
			local capture = fresh()
			local view = start(capture)
			local out = capture:sample(view.token, at(0.2, 7, 0, extra))
			equal(out.reason, "Defeated"); equal(out.grant, false); equal(out.spook, true)
			nothingHeld(capture)
		end
		local capture = fresh()
		local view = start(capture)
		local entry = at(0.2, 7, 0); entry.alive = nil
		equal(capture:sample(view.token, entry).reason, "Defeated")
		capture = fresh()
		view = start(capture)
		entry = at(0.2, 7, 0); entry.life = nil
		equal(capture:sample(view.token, entry).reason, "Defeated")
	end)

	case("Defeated is reported even when the clock and position are unusable", function()
		local capture = fresh()
		local view = start(capture, { now = 10 })
		local out = capture:sample(view.token, { alive = false, now = NAN, x = NAN, y = NAN, z = NAN })
		equal(out.reason, "Defeated")
		equal(out.retryAt, 10 + C.RETRY_COOLDOWN)
	end)

	case("CAP-15: leaving frees the reservation at once with no grant, spook or retry", function()
		local capture = fresh()
		local view = start(capture)
		local out = capture:drop(1, 1)
		equal(out.reason, "Disconnected"); equal(out.phase, "Cancelled"); equal(out.grant, false)
		equal(out.spook, false); equal(out.notice, nil); equal(out.retryAt, nil)
		nothingHeld(capture)
		equal(capture:encounterState(ID, 1), "Free")
		start(capture, { playerKey = 2, life = lifeB, now = 1 })
	end)

	case("the same player rejoining gets a new token and the old one is dead", function()
		local capture = fresh()
		local view = start(capture)
		capture:drop(1, 1)
		local again = start(capture, { now = 1 })
		assert(again.token ~= view.token, "token reused")
		equal(capture:sample(view.token, at(1.2, 7, 0)), nil)
		equal((capture:cancel(view.token, 1, 1.2)), false)
		equal(capture.reservations[ID], again.token)
	end)

	case("drop without a session or with a bad key does nothing", function()
		local capture = fresh()
		equal(capture:drop(1, 0), nil)
		equal(capture:drop(nil, 0), nil)
		equal(capture:drop(NAN, 0), nil)
		start(capture)
		equal(capture:drop(2, 0), nil)
		equal(count(capture.sessions), 1)
		capture:drop(1, 0)
		equal(capture:drop(1, 0), nil)
	end)

	case("leaving and rejoining keeps the player's retry wait", function()
		local capture = fresh()
		local view = start(capture)
		capture:cancel(view.token, 1, 0)
		assert(capture.retries["n:1"] ~= nil, "retry should exist")
		equal(capture:drop(1, 1), nil)
		assert(capture.retries["n:1"] ~= nil, "leaving must not wipe the wait")
		refused(capture, { now = 3 }, "RetryWait")
		refused(capture, { now = C.RETRY_COOLDOWN - 0.01 }, "RetryWait")
		start(capture, { now = C.RETRY_COOLDOWN })
	end)

	case("leaving mid-session keeps an earlier wait on another encounter, and adds none of its own", function()
		local capture = fresh()
		local first = start(capture, { encounterId = OTHER })
		capture:cancel(first.token, 1, 0)
		start(capture, { now = 1 })
		local out = capture:drop(1, 2)
		equal(out.reason, "Disconnected"); equal(out.retryAt, nil)
		refused(capture, { encounterId = OTHER, now = 2 }, "RetryWait")
		start(capture, { now = 2 })
	end)

	case("CAP-16: a full bag or collection at completion refuses with its reason and no grant", function()
		for _, row in ipairs({ { field = "bagRoom", reason = "BackpackFull" },
			{ field = "collectionRoom", reason = "CollectionFull" } }) do
			for _, value in ipairs({ false, "yes" }) do
				local capture = fresh()
				local view = start(capture)
				run(capture, view, 1, 22, followRing(view))
				local x, z = center(view, 4.6)
				local out = capture:sample(view.token, at(4.6, x, z, { [row.field] = value }))
				equal(out.reason, row.reason); equal(out.grant, false); equal(out.spook, true)
				nothingHeld(capture)
				equal(capture:encounterState(ID, 4.6), "Spooked")
			end
			local capture = fresh()
			local view = start(capture)
			run(capture, view, 1, 22, followRing(view))
			local x, z = center(view, 4.6)
			local entry = at(4.6, x, z); entry[row.field] = nil
			equal(capture:sample(view.token, entry).reason, row.reason)
		end
	end)

	case("room is only read at completion, not on earlier samples", function()
		local capture = fresh()
		local view = start(capture)
		local x, z = center(view, 0.2)
		equal(capture:sample(view.token, at(0.2, x, z, { bagRoom = false })).phase, "Active")
	end)

	case("CAP-17: completion grants once and every replay does nothing", function()
		local capture = fresh()
		local view = start(capture)
		local out = run(capture, view, 1, 40, followRing(view))
		equal(out.reason, "Completed"); equal(out.phase, "Completed"); equal(out.grant, true)
		equal(out.encounterId, ID); equal(out.playerKey, 1); equal(out.spook, false); equal(out.retryAt, nil)
		equal(out.notice, nil)
		nothingHeld(capture)
		for _ = 1, 10 do
			equal(capture:sample(view.token, at(6, 7, 0)), nil)
		end
		equal((capture:cancel(view.token, 1, 6)), false)
		equal(capture:drop(1, 6), nil)
		equal(capture:encounterState(ID, 6), "Captured")
	end)

	case("a tap arriving after completion gets AlreadyClaimed, for anyone", function()
		local capture = fresh()
		local view = start(capture)
		run(capture, view, 1, 40, followRing(view))
		refused(capture, { playerKey = 2, life = lifeB, now = 6 }, "AlreadyClaimed", "loser")
		refused(capture, { now = 6 }, "AlreadyClaimed", "winner")
	end)

	-- One owner.
	case("CAP-30 pure: two racing clients yield one owner, 20 tries with roles swapped", function()
		for try = 1, 20 do
			local capture = fresh()
			local firstKey, secondKey = try % 2 + 1, (try + 1) % 2 + 1
			local ok1 = capture:begin(input({ playerKey = firstKey }))
			local ok2, why = capture:begin(input({ playerKey = secondKey }))
			equal(ok1, true); equal(ok2, false); equal(why, "Reserved")
			equal(count(capture.sessions), 1)
			equal(count(capture.reservations), 1)
			equal(capture.byPlayer["n:" .. secondKey], nil)
		end
	end)

	case("tokens are never reused in one server", function()
		local capture = fresh()
		local seen = {}
		for k = 1, 300 do
			local view = start(capture, { encounterId = "Creature:" .. k })
			assert(not seen[view.token], "reused " .. view.token)
			seen[view.token] = true
			capture:drop(1, 0)
		end
	end)

	case("a failure spooks for 2 s for everyone, then a different player may start", function()
		local capture = fresh()
		local view = start(capture)
		local ok, out = capture:cancel(view.token, 1, 10)
		equal(ok, true)
		equal(out.spookUntil, 10 + C.SPOOK_SECONDS)
		equal(capture:encounterState(ID, 10), "Spooked")
		refused(capture, { playerKey = 2, life = lifeB, now = 10 + C.SPOOK_SECONDS - 0.01 }, "Reserved")
		equal(capture:encounterState(ID, 10 + C.SPOOK_SECONDS), "Free")
		start(capture, { playerKey = 2, life = lifeB, now = 10 + C.SPOOK_SECONDS })
	end)

	case("the same player waits the retry cooldown on that encounter only", function()
		local capture = fresh()
		local view = start(capture)
		local _, out = capture:cancel(view.token, 1, 10)
		equal(out.retryAt, 10 + C.RETRY_COOLDOWN)
		refused(capture, { now = 10 + C.RETRY_COOLDOWN - 0.01 }, "RetryWait")
		start(capture, { now = 10, encounterId = OTHER })
		capture:drop(1, 10)
		capture = fresh()
		view = start(capture)
		capture:cancel(view.token, 1, 10)
		start(capture, { now = 10 + C.RETRY_COOLDOWN })
	end)

	case("a backward clock cannot lengthen a spook or a retry wait", function()
		local capture = fresh()
		local view = start(capture, { now = 100 })
		capture:cancel(view.token, 1, 100)
		equal(capture:encounterState(ID, 50), "Free")
		start(capture, { now = 50 })
	end)

	-- Failures count per player per encounter (audit, wave W5): one player cannot remove a Lumipol for others.
	local function failTooFar(capture, player, life, now)
		local ok, view = capture:begin(input({ playerKey = player, life = life, now = now }))
		assert(ok == true, "start refused: " .. tostring(view))
		local out = capture:sample(view.token, at(now + 0.2, 7, 99, { life = life }))
		equal(out.reason, "TooFar")
		return out
	end

	case("a player's third failure earns that player a long wait, and the Lumipol stays", function()
		local capture = fresh()
		local now = 0
		local first = failTooFar(capture, 1, lifeA, now)
		equal(first.leaves, false); equal(first.retryAt, now + 0.2 + C.RETRY_COOLDOWN)
		now += C.RETRY_COOLDOWN + 1
		local second = failTooFar(capture, 1, lifeA, now)
		equal(second.leaves, false); equal(second.retryAt, now + 0.2 + C.RETRY_COOLDOWN)
		now += C.RETRY_COOLDOWN + 1
		local third = failTooFar(capture, 1, lifeA, now)
		equal(third.leaves, false, "the Lumipol does not leave")
		equal(third.retryAt, now + 0.2 + C.LONG_COOLDOWN)
		refused(capture, { now = now + 0.2 + C.RETRY_COOLDOWN + 0.5 }, "RetryWait")
		refused(capture, { now = third.retryAt - 0.01 }, "RetryWait")
		start(capture, { now = third.retryAt })
	end)

	case("one player's failures never remove the Lumipol for anyone else", function()
		local capture = fresh()
		local now = 0
		for _ = 1, 3 do
			local out = failTooFar(capture, 1, lifeA, now)
			equal(out.leaves, false)
			now += C.LONG_COOLDOWN + 1
		end
		equal(capture:encounterState(ID, now), "Free")
		local ok, view = capture:begin(input({ playerKey = 2, life = lifeB, now = now }))
		equal(ok, true, "another player must still be able to start")
		local out = capture:sample(view.token, at(now + 0.2, 7, 99, { life = lifeB }))
		equal(out.leaves, false)
		equal(capture:encounterState(ID, now + 10), "Free")
	end)

	case("failures are counted per player on one encounter", function()
		local capture = fresh()
		local now = 0
		-- Two players alternate: each fails twice, nobody reaches three.
		for round = 1, 2 do
			for player = 1, 2 do
				local life = player == 1 and lifeA or lifeB
				local out = failTooFar(capture, player, life, now)
				equal(out.retryAt, now + 0.2 + C.RETRY_COOLDOWN, "player " .. player .. " round " .. round)
				now += C.RETRY_COOLDOWN + 1
			end
		end
		-- Player 1's third failure is the long one; player 2's count is untouched at two.
		local third = failTooFar(capture, 1, lifeA, now)
		equal(third.retryAt, now + 0.2 + C.LONG_COOLDOWN)
		now += C.RETRY_COOLDOWN + 1
		local other = failTooFar(capture, 2, lifeB, now)
		equal(other.retryAt, now + 0.2 + C.LONG_COOLDOWN, "player 2 reaches three on their own")
	end)

	case("the count starts over after the long wait", function()
		local capture = fresh()
		local now = 0
		for _ = 1, 3 do
			failTooFar(capture, 1, lifeA, now)
			now += C.LONG_COOLDOWN + 1
		end
		local again = failTooFar(capture, 1, lifeA, now)
		equal(again.retryAt, now + 0.2 + C.RETRY_COOLDOWN)
	end)

	case("cancels and leaving do not count toward the long wait", function()
		local capture = fresh()
		local now = 0
		for _ = 1, 6 do
			local view = start(capture, { now = now })
			capture:cancel(view.token, 1, now)
			now += C.RETRY_COOLDOWN + 1
			view = start(capture, { now = now })
			capture:drop(1, now)
		end
		local out = failTooFar(capture, 1, lifeA, now)
		equal(out.retryAt, now + 0.2 + C.RETRY_COOLDOWN)
	end)

	case("leaving and rejoining keeps the failure count and the long wait", function()
		local capture = fresh()
		local now = 0
		failTooFar(capture, 1, lifeA, now)
		capture:drop(1, now + 1)
		now += C.RETRY_COOLDOWN + 1
		failTooFar(capture, 1, lifeA, now)
		capture:drop(1, now + 1)
		now += C.RETRY_COOLDOWN + 1
		local third = failTooFar(capture, 1, lifeA, now)
		equal(third.retryAt, now + 0.2 + C.LONG_COOLDOWN, "the count survived two rejoins")
		capture:drop(1, now + 1)
		refused(capture, { now = now + 5 }, "RetryWait")
		refused(capture, { now = third.retryAt - 0.01 }, "RetryWait")
		start(capture, { now = third.retryAt })
	end)

	case("a backward clock cannot stretch a short wait toward the long one", function()
		local capture = fresh()
		local view = start(capture, { now = 100 })
		capture:cancel(view.token, 1, 100)
		start(capture, { now = 80 })
	end)

	case("a backward clock cannot lengthen the long wait either", function()
		local capture = fresh()
		local now = 100
		local third
		for _ = 1, 3 do
			third = failTooFar(capture, 1, lifeA, now)
			now += C.LONG_COOLDOWN + 1
		end
		start(capture, { now = third.retryAt - C.LONG_COOLDOWN - 15 })
	end)

	case("retiring an encounter forgets every player's failures and waits on it", function()
		local capture = fresh()
		failTooFar(capture, 1, lifeA, 0)
		failTooFar(capture, 2, lifeB, 10)
		assert(count(capture.failures) > 0, "failures expected")
		capture:retire(ID, 11)
		equal(count(capture.failures), 0)
		equal(count(capture.retries), 0)
	end)

	case("sweep forgets spent waits but not live failure counts, and retire clears those", function()
		local capture = fresh()
		failTooFar(capture, 1, lifeA, 0)
		capture:sweep(C.LONG_COOLDOWN + 5)
		equal(count(capture.retries), 0)
		assert(count(capture.failures) > 0, "the failure count must outlive the wait")
		capture:retire(ID, C.LONG_COOLDOWN + 6)
		equal(count(capture.failures), 0)
	end)

	case("the long wait is a frozen constant longer than the short one", function()
		assert(table.isfrozen(C), "constants")
		assert(C.LONG_COOLDOWN > C.RETRY_COOLDOWN, "long must be longer")
		equal(C.MAX_FAILS, 3)
		equal(C.LONG_COOLDOWN, 45)
	end)

	case("retire ends a holder as Lost and forgets the encounter", function()
		local capture = fresh()
		local view = start(capture)
		local out = capture:retire(ID, 1)
		equal(out.reason, "Lost"); equal(out.grant, false); equal(out.spook, false); equal(out.retryAt, nil)
		equal(out.notice, nil)
		nothingHeld(capture)
		equal(capture:sample(view.token, at(1.2, 7, 0)), nil)
		equal(capture.counters.anomaly, 0)
		equal(capture:encounterState(ID, 1), "Free")
		equal(capture:retire(ID, 1), nil)
		equal(capture:retire(nil, 1), nil)
		equal(capture:retire(7, 1), nil)
	end)

	case("retire clears captured, spook and retry records for that encounter", function()
		local capture = fresh()
		local view = start(capture)
		run(capture, view, 1, 40, followRing(view))
		capture:retire(ID, 6)
		equal(capture:encounterState(ID, 6), "Free")
		capture = fresh()
		view = start(capture)
		capture:cancel(view.token, 1, 0)
		capture:retire(ID, 0)
		start(capture, { now = 0 })
	end)

	case("a lost reservation ends as Lost and counts one anomaly", function()
		local capture = fresh()
		local view = start(capture)
		capture.reservations[ID] = nil
		local out = capture:sample(view.token, at(0.2, 7, 0))
		equal(out.reason, "Lost"); equal(out.grant, false)
		equal(capture.counters.anomaly, 1)
		nothingHeld(capture)
	end)

	case("a reservation stolen by another token never frees the thief's holding", function()
		local capture = fresh()
		local view = start(capture)
		capture.reservations[ID] = "cap:other"
		capture:sample(view.token, at(0.2, 7, 0))
		equal(capture.reservations[ID], "cap:other")
	end)

	-- Time and bad readings.
	case("time going backward makes no progress and leaves the deadline alone", function()
		local capture = fresh()
		local view = start(capture, { now = 10 })
		local x, z = center(view, 11)
		local out = capture:sample(view.token, at(11, x, z))
		local calm, deadline = out.calm, out.deadline
		out = capture:sample(view.token, at(10.5, x, z))
		equal(out.phase, "Active"); equal(out.calm, calm); equal(out.deadline, deadline)
		equal(out.bad, true)
	end)

	case("backward then forward credits at most one capped sample", function()
		local capture = fresh()
		local view = start(capture, { now = 10 })
		local x, z = center(view, 10.2)
		capture:sample(view.token, at(10.2, x, z))
		capture:sample(view.token, at(5, x, z))
		local before = capture:view(view.token).calm
		x, z = center(view, 10.4)
		local out = capture:sample(view.token, at(10.4, x, z))
		near(out.calm, before + 0.2)
	end)

	case("the deadline holds at its exact boundary", function()
		local capture = fresh()
		local view = start(capture)
		local out
		for k = 1, 24 do
			local cx, cz = center(view, k * 0.5)
			out = capture:sample(view.token, at(k * 0.5, cx + (k % 2 == 0 and 2 or -2), cz))
			if k < 24 then equal(out.phase, "Active", "step " .. k) end
		end
		equal(out.reason, "TimedOut")
	end)

	case("five bad samples in a row end as LostTrack, freeing everything with no penalty", function()
		local bad = {
			function(now) return { now = now - 5, alive = true, life = lifeA, x = 7, y = 3, z = 0 } end,
			function() return { now = NAN, alive = true, life = lifeA, x = 7, y = 3, z = 0 } end,
			function() return { now = INF, alive = true, life = lifeA, x = 7, y = 3, z = 0 } end,
			function() return { now = "1", alive = true, life = lifeA, x = 7, y = 3, z = 0 } end,
			function(now) return { now = now, alive = true, life = lifeA, x = NAN, y = 3, z = 0 } end,
			function(now) return { now = now, alive = true, life = lifeA, x = 7, y = INF, z = 0 } end,
			function(now) return { now = now, alive = true, life = lifeA, x = 7, y = 3, z = "0" } end,
			function(now) return { now = now, alive = true, life = lifeA, y = 3, z = 0 } end,
			function() return 42 end,
			function() return "obs" end,
		}
		for index, make in ipairs(bad) do
			local capture = fresh()
			local view = start(capture, { now = 10 })
			local out
			for k = 1, C.BAD_SAMPLE_LIMIT do
				out = capture:sample(view.token, make(10 + k * 0.2))
				if k < C.BAD_SAMPLE_LIMIT then equal(out.phase, "Active", "kind " .. index) end
			end
			equal(out.reason, "LostTrack", "kind " .. index)
			equal(out.grant, false); equal(out.spook, false); equal(out.retryAt, nil); equal(out.leaves, false)
			equal(capture.counters.anomaly, 1)
			nothingHeld(capture)
			equal(capture:encounterState(ID, 12), "Free")
		end
	end)

	case("a nil reading counts as a bad sample", function()
		local capture = fresh()
		local view = start(capture)
		local out
		for _ = 1, C.BAD_SAMPLE_LIMIT do out = capture:sample(view.token, nil) end
		equal(out.reason, "LostTrack")
	end)

	case("one good sample resets the bad count", function()
		local capture = fresh()
		local view = start(capture)
		for k = 1, 3 do
			for _ = 1, C.BAD_SAMPLE_LIMIT - 1 do capture:sample(view.token, at(NAN, 7, 0)) end
			equal(capture:sample(view.token, at(k * 0.2, 7, 0)).phase, "Active")
		end
	end)

	case("a bad position cannot delay the deadline", function()
		local capture = fresh()
		local view = start(capture)
		local out = capture:sample(view.token, at(C.TIME_LIMIT, NAN, 0))
		equal(out.reason, "TimedOut")
	end)

	case("a bad position adds no calm", function()
		local capture = fresh()
		local view = start(capture)
		local out = capture:sample(view.token, at(0.2, NAN, 0))
		equal(out.calm, 0); equal(out.bad, true)
	end)

	case("sampling an unknown or malformed token returns nil without an error", function()
		local capture = fresh()
		for _, token in ipairs({ "", "cap:1", 1, NAN, {}, true, string.rep("t", 200) }) do
			equal(capture:sample(token, at(0, 7, 0)), nil)
		end
		equal(capture:sample(nil, at(0, 7, 0)), nil)
	end)

	case("the watchdog frees a session nobody samples, once, at the deadline plus grace", function()
		local capture = fresh()
		local view = start(capture)
		equal(#capture:sweep(C.TIME_LIMIT + C.WATCHDOG_GRACE - 0.01), 0)
		equal(count(capture.sessions), 1)
		local ended = capture:sweep(C.TIME_LIMIT + C.WATCHDOG_GRACE)
		equal(#ended, 1)
		equal(ended[1].reason, "Watchdog"); equal(ended[1].grant, false); equal(ended[1].spook, false)
		equal(ended[1].retryAt, nil); equal(ended[1].leaves, false)
		equal(capture.counters.watchdog, 1)
		nothingHeld(capture)
		equal(#capture:sweep(C.TIME_LIMIT + C.WATCHDOG_GRACE + 1), 0)
		equal(capture.counters.watchdog, 1)
		equal(capture:sample(view.token, at(14, 7, 0)), nil)
	end)

	case("the watchdog respects a deadline pushed by a stall", function()
		local capture = fresh()
		local view = start(capture)
		local out = capture:sample(view.token, at(3, center(view, 3)))
		near(out.deadline, C.TIME_LIMIT + 3)
		equal(#capture:sweep(C.TIME_LIMIT + C.WATCHDOG_GRACE + 0.5), 0)
		equal(#capture:sweep(C.TIME_LIMIT + 3 + C.WATCHDOG_GRACE), 1)
	end)

	case("a bad clock on sweep does nothing", function()
		local capture = fresh()
		start(capture)
		for _, now in ipairs({ NAN, INF, -INF, "9" }) do
			equal(#capture:sweep(now), 0)
		end
		equal(#capture:sweep(nil), 0)
		equal(count(capture.sessions), 1)
	end)

	case("sweep forgets expired spooks and retries so memory stays bounded", function()
		local capture = fresh()
		for k = 1, 50 do
			local id = "Creature:" .. k
			local view = start(capture, { encounterId = id })
			capture:cancel(view.token, 1, 0)
		end
		assert(count(capture.encounters) == 50, "records expected")
		capture:sweep(C.RETRY_COOLDOWN + C.SPOOK_SECONDS)
		equal(count(capture.encounters), 0)
		equal(count(capture.retries), 0)
	end)

	-- Ring geometry.
	case("CAP-22: the ring from the view and from the snapshot agree at every moment", function()
		local capture = fresh()
		local view = start(capture, { dir = -1, now = 3 })
		local snapshot = CaptureSession.toSnapshot(view)
		for t = 0, 12, 0.37 do
			local x1, z1 = CaptureSession.ringCenter(view.ring, t)
			local x2, z2 = CaptureSession.ringCenter(snapshot.ring, t)
			equal(x1, x2); equal(z1, z2)
		end
	end)

	case("the ring starts on the player from every start distance and bearing", function()
		for _, distance in ipairs({ 0, 1, 2.57, 4, C.ORBIT_MIN, 7, C.ORBIT_MAX, 9.5, C.START_RANGE }) do
			for _, bearing in ipairs({ 0, 1, 2.5, -2 }) do
				local x, z = 3 + distance * math.cos(bearing), -4 + distance * math.sin(bearing)
				local capture = fresh()
				local view = start(capture, { lumipolX = 3, lumipolZ = -4, x = x, z = z, distance = distance })
				local cx, cz = CaptureSession.ringCenter(view.ring, 0)
				near(cx, x); near(cz, z)
			end
		end
	end)

	case("inside the orbit range the Lumipol is the orbit center and the orbit is the distance", function()
		for _, distance in ipairs({ C.ORBIT_MIN, 7, C.ORBIT_MAX }) do
			local view = start(fresh(), { lumipolX = 2, lumipolZ = 5, x = 2 + distance, z = 5, distance = distance })
			near(view.ring.pivotX, 2); near(view.ring.pivotZ, 5); near(view.ring.orbit, distance)
		end
	end)

	case("the orbit clamps to its range at both ends", function()
		near(start(fresh(), { x = 1, distance = 1 }).ring.orbit, C.ORBIT_MIN)
		near(start(fresh(), { x = 10, distance = 10 }).ring.orbit, C.ORBIT_MAX)
	end)

	case("the ring drifts at the ring speed in the injected direction", function()
		for _, distance in ipairs({ 0, C.ORBIT_MIN, 7, C.ORBIT_MAX, C.START_RANGE }) do
			local view = start(fresh(), { x = distance, distance = distance })
			local x1, z1 = CaptureSession.ringCenter(view.ring, 2)
			local x2, z2 = CaptureSession.ringCenter(view.ring, 2.01)
			near(math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2) / 0.01, C.RING_SPEED, 1e-3)
		end
		local plus = start(fresh(), { dir = 1 })
		local minus = start(fresh(), { dir = -1 })
		local _, zPlus = CaptureSession.ringCenter(plus.ring, 1)
		local _, zMinus = CaptureSession.ringCenter(minus.ring, 1)
		near(zPlus, -zMinus)
		assert(zPlus > 0, "dir +1 turns toward positive z from bearing zero")
	end)

	case("the stationary player reaches the ring edge after about 3 to 4 s", function()
		for _, distance in ipairs({ C.ORBIT_MIN, 7, C.ORBIT_MAX }) do
			local capture = fresh()
			local view = start(capture, { x = distance, distance = distance })
			local firstOutside
			for k = 1, 30 do
				local out = capture:sample(view.token, at(k * C.SAMPLE, distance, 0))
				if not out.inside then firstOutside = k * C.SAMPLE; break end
			end
			assert(firstOutside and firstOutside >= 3 and firstOutside <= 4, "edge at " .. tostring(firstOutside))
		end
	end)

	case("ringCenter refuses malformed input and clamps a negative moment", function()
		local view = start(fresh())
		for _, ring in ipairs({ 1, "ring", {}, { pivotX = NAN, pivotZ = 0, orbit = 7, a0 = 0, w = 1 } }) do
			equal((CaptureSession.ringCenter(ring, 1)), nil)
		end
		equal((CaptureSession.ringCenter(nil, 1)), nil)
		equal((CaptureSession.ringCenter(view.ring, NAN)), nil)
		equal((CaptureSession.ringCenter(view.ring, "1")), nil)
		local x0, z0 = CaptureSession.ringCenter(view.ring, 0)
		local xNeg, zNeg = CaptureSession.ringCenter(view.ring, -3)
		equal(xNeg, x0); equal(zNeg, z0)
	end)

	case("the same inputs give the same trace", function()
		local function trace()
			local capture = fresh()
			local view = start(capture, { dir = -1 })
			local log = { view.token }
			for k = 1, 40 do
				local out = capture:sample(view.token, at(k * 0.2, 7, 0))
				if not out then break end
				table.insert(log, string.format("%s %.9f %.9f", out.phase, out.calm, out.outsideFor))
			end
			return table.concat(log, "|")
		end
		equal(trace(), trace())
	end)

	-- Compact exposure.
	case("the active snapshot holds only whitelisted fields and hides who and what", function()
		local capture = fresh()
		local view = start(capture)
		local snapshot = CaptureSession.toSnapshot(view)
		local allowed = { token = true, phase = true, calm = true, inside = true, moving = true,
			outsideFor = true, deadline = true, ring = true, stage = true, required = true }
		for key in pairs(snapshot) do assert(allowed[key], "extra field " .. tostring(key)) end
		equal(snapshot.playerKey, nil); equal(snapshot.encounterId, nil)
		equal(snapshot.token, view.token); equal(snapshot.phase, "Active")
		local ring = { pivotX = true, pivotZ = true, y = true, orbit = true, a0 = true, w = true,
			startedAt = true, radius = true }
		for key, value in pairs(snapshot.ring) do
			assert(ring[key], "extra ring field " .. tostring(key))
			equal(type(value), "number", key)
			assert(value == value and math.abs(value) < INF, key .. " must be finite")
		end
		equal(snapshot.ring.radius, C.RING_RADIUS_VISIBLE)
		equal(count(snapshot.ring), 8)
	end)

	case("a per-sample snapshot omits the ring, which never changes", function()
		local capture = fresh()
		local view = start(capture)
		local out = capture:sample(view.token, at(0.2, 7, 0))
		local snapshot = CaptureSession.toSnapshot(out)
		equal(snapshot.ring, nil)
		equal(snapshot.moving, false); equal(snapshot.inside, true)
		near(snapshot.calm, 0.2)
		equal(snapshot.stage, "Calm")
		assert(count(snapshot) <= 9, "per-sample snapshot too large: " .. count(snapshot))
	end)

	case("the ending snapshot carries the phase, the reason, the text and the retry moment", function()
		local capture = fresh()
		local view = start(capture)
		local _, out = capture:cancel(view.token, 1, 1)
		local snapshot = CaptureSession.toSnapshot(out)
		equal(snapshot.phase, "Cancelled"); equal(snapshot.reason, "Cancelled")
		equal(snapshot.notice, nil)
		equal(snapshot.retryAt, 1 + C.RETRY_COOLDOWN)
		equal(snapshot.ring, nil); equal(snapshot.playerKey, nil); equal(snapshot.encounterId, nil)
		equal(snapshot.grant, nil)
	end)

	case("snapshots are detached copies", function()
		local capture = fresh()
		local view = start(capture)
		local snapshot = CaptureSession.toSnapshot(view)
		snapshot.ring.orbit = 999
		snapshot.calm = 999
		equal(capture:view(view.token).calm, 0)
		assert(capture:view(view.token).ring.orbit ~= 999, "ring leaked")
		local detached = capture:view(view.token)
		detached.calm = 999
		equal(capture:view(view.token).calm, 0)
	end)

	case("view returns the ring for a resync and nothing for a dead token", function()
		local capture = fresh()
		local view = start(capture)
		assert(capture:view(view.token).ring ~= nil, "ring expected")
		capture:cancel(view.token, 1, 0)
		equal(capture:view(view.token), nil)
		equal(capture:view(nil), nil)
		equal(capture:view(5), nil)
	end)

	case("toSnapshot refuses garbage", function()
		for _, garbage in ipairs({ 1, "x", {}, { phase = "Hacked" } }) do
			equal(CaptureSession.toSnapshot(garbage), nil)
		end
		equal(CaptureSession.toSnapshot(nil), nil)
	end)

	case("activeSessions lists each live session for the sampling loop, in start order", function()
		local capture = fresh()
		local a = start(capture, { encounterId = "Creature:1" })
		local b = start(capture, { playerKey = 2, life = lifeB, encounterId = "Creature:2" })
		local list = capture:activeSessions()
		equal(#list, 2)
		equal(list[1].token, a.token); equal(list[1].playerKey, 1); equal(list[1].encounterId, "Creature:1")
		equal(list[2].token, b.token); equal(list[2].playerKey, 2)
		capture:drop(1, 0)
		equal(#capture:activeSessions(), 1)
	end)

	case("encounterState tells the prompt what to do", function()
		local capture = fresh()
		equal(capture:encounterState(ID, 0), "Free")
		equal(capture:encounterState(nil, 0), nil)
		equal(capture:encounterState(5, 0), nil)
		local view = start(capture)
		equal(capture:encounterState(ID, 0), "Reserved")
		capture:cancel(view.token, 1, 0)
		equal(capture:encounterState(ID, 0), "Spooked")
		equal(capture:encounterState(ID, NAN), "Free")
	end)

	-- Reasons, not words (H3): the words live in WildboundText.
	case("H3: endings carry a reason and no words; the rule keeps no text table", function()
		equal(CaptureSession.NOTICES, nil)
		local capture = fresh()
		local view = start(capture)
		local _, out = capture:cancel(view.token, 1, 1)
		equal(out.reason, "Cancelled"); equal(out.notice, nil)
	end)

	-- The seal step (H1).
	local function calmFull(capture, view)
		for k = 1, 60 do
			local now = k * C.SAMPLE
			local x, z = center(view, now)
			local out = capture:sample(view.token, at(now, x, z))
			if out.phase ~= "Active" or out.stage == "Seal" then return out, now end
		end
		error("the meter never filled")
	end
	local function press(capture, token, now, extra, key)
		local obs = { now = now, alive = true, life = lifeA, bagRoom = true, collectionRoom = true }
		for name, value in pairs(extra or {}) do obs[name] = value end
		return capture:seal(token, key or 1, obs)
	end

	case("H1: seal constants: a short delay, a 1.6 s sweep, a wide Safe band and a documented latency allowance", function()
		equal(C.SEAL_DELAY, 0.4); equal(C.SEAL_SWEEP, 1.6); equal(C.SEAL_LATENCY, 0.15)
		equal(C.SEAL_BAND, 0.2); equal(C.SEAL_BAND_SAFE, 0.36)
		assert(C.SEAL_LO_MIN > 0 and C.SEAL_HI_MAX < 1 and C.SEAL_LO_MIN + C.SEAL_BAND_SAFE <= C.SEAL_HI_MAX, "band room")
	end)

	case("H1: a full meter opens the seal step instead of granting, and the encounter stays reserved", function()
		local capture = fresh()
		local view = start(capture)
		local out, calmAt = calmFull(capture, view)
		equal(out.phase, "Active"); equal(out.stage, "Seal"); equal(out.grant, nil)
		near(calmAt, C.CALM_REQUIRED, C.SAMPLE + 1e-6)
		local seal = out.seal
		assert(table.isfrozen(seal), "seal frozen")
		near(seal.startedAt, calmAt + C.SEAL_DELAY); equal(seal.sweep, C.SEAL_SWEEP)
		near(seal.hi - seal.lo, C.SEAL_BAND)
		assert(seal.lo >= C.SEAL_LO_MIN - 1e-9 and seal.hi <= C.SEAL_HI_MAX + 1e-9, "band inside the bar")
		equal(capture.reservations[ID], view.token)
		equal(capture:encounterState(ID, calmAt), "Reserved")
		assert(out.deadline + 1e-9 >= seal.startedAt + seal.sweep + C.SEAL_LATENCY, "deadline covers the sweep")
		local snapshot = CaptureSession.toSnapshot(out)
		equal(snapshot.stage, "Seal"); equal(snapshot.seal.lo, seal.lo)
		refused(capture, { playerKey = 2, life = lifeB, now = calmAt }, "Reserved", "a second player during the seal")
	end)

	case("H1: a press inside the band completes; both band edges count", function()
		for _, edge in ipairs({ "lo", "mid", "hi" }) do
			local capture = fresh()
			local view = start(capture)
			local out = calmFull(capture, view)
			local seal = out.seal
			local fraction = edge == "lo" and seal.lo or edge == "hi" and seal.hi or (seal.lo + seal.hi) / 2
			local ok, ended = press(capture, view.token, seal.startedAt + seal.sweep * fraction)
			equal(ok, true, edge)
			equal(ended.reason, "Completed", edge); equal(ended.grant, true); equal(ended.phase, "Completed")
			nothingHeld(capture)
			equal(capture:encounterState(ID, 9), "Captured")
		end
	end)

	case("H1: the latency allowance: a press up to SEAL_LATENCY after the band still hits, later misses", function()
		local capture = fresh()
		local view = start(capture)
		local seal = calmFull(capture, view).seal
		local bandEnd = seal.startedAt + seal.sweep * seal.hi
		local _, ended = press(capture, view.token, bandEnd + C.SEAL_LATENCY - 0.01)
		equal(ended.reason, "Completed")
		local other = fresh()
		local second = start(other)
		local late = calmFull(other, second).seal
		local _, missed = press(other, second.token, late.startedAt + late.sweep * late.hi + C.SEAL_LATENCY + 0.02)
		equal(missed.reason, "SealMissed")
	end)

	case("H1: a press before the band misses: the Lumipol flees, a retry wait starts and it counts as a failure", function()
		local capture = fresh()
		local view = start(capture)
		local seal = calmFull(capture, view).seal
		local ok, ended = press(capture, view.token, seal.startedAt + seal.sweep * seal.lo - 0.05)
		equal(ok, true)
		equal(ended.reason, "SealMissed"); equal(ended.phase, "Failed"); equal(ended.grant, false)
		equal(ended.spook, true)
		assert(ended.retryAt and ended.retryAt > seal.startedAt, "a retry wait")
		equal(capture.failures["n:1"][ID], 1)
		nothingHeld(capture)
		equal(capture:encounterState(ID, seal.startedAt + 1), "Spooked")
	end)

	case("H1: no press: the first sample after the sweep and its allowance ends SealMissed", function()
		local capture = fresh()
		local view = start(capture)
		local out, calmAt = calmFull(capture, view)
		local seal = out.seal
		local closeAt = seal.startedAt + seal.sweep + C.SEAL_LATENCY
		local now, ended = calmAt, nil
		while not ended do
			now += C.SAMPLE
			local result = capture:sample(view.token, at(now, center(view, now)))
			if result.phase ~= "Active" then ended = result else equal(result.stage, "Seal") end
		end
		equal(ended.reason, "SealMissed")
		assert(now > closeAt and now <= closeAt + C.SAMPLE + 1e-6, "ended at " .. now)
	end)

	case("H1: during the seal the ring no longer matters, but leaving, dying and a strike still end it", function()
		local capture = fresh()
		local view = start(capture)
		local _, calmAt = calmFull(capture, view)
		local cx, cz = center(view, calmAt + 0.2)
		local out = capture:sample(view.token, at(calmAt + 0.2, cx + 6, cz)) -- outside the ring, inside TooFar
		equal(out.phase, "Active"); equal(out.stage, "Seal"); equal(out.inside, true, "the ring stopped being judged")
		local far = capture:sample(view.token, at(calmAt + 0.4, 30, 0))
		equal(far.reason, "TooFar")
		for _, reason in ipairs({ "Defeated", "Struck" }) do
			local other = fresh()
			local second = start(other)
			local _, t = calmFull(other, second)
			local x, z = center(second, t + 0.2)
			if reason == "Struck" then other:notifyStruck(1) end
			local ended = other:sample(second.token, at(t + 0.2, x, z, reason == "Defeated" and { alive = false } or nil))
			equal(ended.reason, reason)
		end
	end)

	case("H1: a dead player's or a full bag's press does not complete", function()
		for _, row in ipairs({ { extra = { alive = false }, reason = "Defeated" }, { extra = { life = lifeB }, reason = "Defeated" },
			{ extra = { bagRoom = false }, reason = "BackpackFull" }, { extra = { collectionRoom = false }, reason = "CollectionFull" } }) do
			local capture = fresh()
			local view = start(capture)
			local seal = calmFull(capture, view).seal
			local _, ended = press(capture, view.token, sealMiddle(seal), row.extra)
			equal(ended.reason, row.reason); equal(ended.grant, false)
		end
	end)

	case("H1: only the owner's live token can seal; a press while calming or before the sweep is ignored", function()
		local capture = fresh()
		local view = start(capture)
		equal(select(2, press(capture, view.token, 1)), "NotReady", "still calming")
		local out = calmFull(capture, view)
		local seal = out.seal
		equal(select(2, press(capture, view.token, seal.startedAt - 0.1)), "NotReady", "before the marker moves")
		for _, token in ipairs({ "", "cap:99", 1, NAN, {}, string.rep("t", 200) }) do
			equal(select(2, press(capture, token, sealMiddle(seal))), "InvalidToken")
		end
		equal(select(2, press(capture, view.token, sealMiddle(seal), nil, 2)), "InvalidToken", "another player")
		equal(select(2, capture:seal(view.token, 1, nil)), "NotReady", "no observation")
		equal(select(2, press(capture, view.token, NAN)), "NotReady", "bad clock")
		equal(capture.reservations[ID], view.token, "nothing above ended the session")
		local ok, ended = press(capture, view.token, sealMiddle(seal))
		equal(ok, true); equal(ended.reason, "Completed")
		equal(select(2, press(capture, view.token, sealMiddle(seal))), "InvalidToken", "a replay")
	end)

	case("H1: two players, one Lumipol: one claim, and the loser cannot seal the winner's session", function()
		local capture = fresh()
		local view = start(capture)
		refused(capture, { playerKey = 2, life = lifeB }, "Reserved")
		local seal = calmFull(capture, view).seal
		equal(select(2, press(capture, view.token, sealMiddle(seal), { life = lifeB }, 2)), "InvalidToken")
		local _, ended = press(capture, view.token, sealMiddle(seal))
		equal(ended.grant, true)
		refused(capture, { playerKey = 2, life = lifeB, now = 9 }, "AlreadyClaimed")
	end)

	case("H1: the Safe tier gets the wide band; the roll places the band across the bar", function()
		local function band(extra)
			local capture = fresh()
			local view = start(capture, extra)
			return calmFull(capture, view).seal
		end
		local safe = band({ tier = "Safe" })
		near(safe.hi - safe.lo, C.SEAL_BAND_SAFE)
		near(band({ tier = "Territory" }).hi - band({ tier = "Territory" }).lo, C.SEAL_BAND)
		near(band({ sealRoll = 0 }).lo, C.SEAL_LO_MIN)
		near(band({ sealRoll = 0.999999 }).hi, C.SEAL_HI_MAX, 1e-5)
		local middle = band({ sealRoll = 0.5 })
		for _, roll in ipairs({ NAN, INF, -1, 2, "x" }) do
			near(band({ sealRoll = roll }).lo, middle.lo, 1e-9, "a bad roll reads as 0.5: " .. tostring(roll))
		end
	end)

	case("H1: the watchdog waits for the seal's own end", function()
		local capture = fresh()
		local view = start(capture)
		local out = calmFull(capture, view)
		equal(#capture:sweep(out.deadline + C.WATCHDOG_GRACE - 0.01), 0)
		equal(#capture:sweep(out.deadline + C.WATCHDOG_GRACE), 1)
	end)

	-- H2: the capture skills act on their owner's session only, inside fixed bounds.
	case("H2: skill bounds: the meter never drops to standing-still territory, the retry never below its floor", function()
		equal(C.CALM_MIN, 4); equal(C.RETRY_MIN, 3)
		assert(C.CALM_MIN < C.CALM_REQUIRED and C.RETRY_MIN < C.RETRY_COOLDOWN, "bounds sit under the defaults")
	end)

	case("H2: a shorter calm requirement opens the seal sooner and the view carries it", function()
		local capture = fresh()
		local view = start(capture, { calmRequired = 4 })
		equal(view.required, 4)
		local out, calmAt = calmFull(capture, view)
		equal(out.stage, "Seal"); equal(out.required, 4)
		near(calmAt, 4, C.SAMPLE + 1e-6)
		equal(CaptureSession.toSnapshot(out).required, 4)
		local plain = fresh()
		local second = start(plain)
		equal(second.required, C.CALM_REQUIRED)
		local _, plainAt = calmFull(plain, second)
		assert(plainAt > calmAt + 0.3, "the default stays 4.5 s")
	end)

	case("H2: skill values are clamped to their bounds and junk reads as the default", function()
		for value, expected in pairs({ [1] = C.CALM_MIN, [99] = C.CALM_REQUIRED, [4.2] = 4.2 }) do
			equal(start(fresh(), { calmRequired = value }).required, expected, tostring(value))
		end
		for _, junk in ipairs({ NAN, INF, -INF, "4" }) do
			equal(start(fresh(), { calmRequired = junk }).required, C.CALM_REQUIRED, tostring(junk))
		end
	end)

	case("H2: a shorter retry wait applies to its owner's failures only, and the third failure still costs the long wait", function()
		local capture = fresh()
		local view = start(capture, { retryCooldown = 3 })
		local _, out = capture:cancel(view.token, 1, 1)
		equal(out.retryAt, 1 + 3)
		local other = start(capture, { playerKey = 2, life = lifeB, encounterId = OTHER, now = 1 })
		local _, theirs = capture:cancel(other.token, 2, 2)
		equal(theirs.retryAt, 2 + C.RETRY_COOLDOWN, "another player keeps the default")
		for value, expected in pairs({ [0] = C.RETRY_MIN, [99] = C.RETRY_COOLDOWN }) do
			local again = fresh()
			local session = start(again, { retryCooldown = value })
			local _, ended = again:cancel(session.token, 1, 1)
			equal(ended.retryAt, 1 + expected, tostring(value))
		end
		local long = fresh()
		local now = 0
		for index = 1, C.MAX_FAILS do
			local session = start(long, { retryCooldown = 3, now = now })
			local endedAt = now + 0.2
			local ended = long:sample(session.token, at(endedAt, 40, 0))
			equal(ended.reason, "TooFar", "failure " .. index)
			near(ended.retryAt, endedAt + (index < C.MAX_FAILS and 3 or C.LONG_COOLDOWN), 1e-9, "failure " .. index)
			now = ended.retryAt + 0.01
		end
	end)

	case("A1: a wary Lumipol refuses a start after the claim checks, reserving nothing", function()
		local capture = fresh()
		refused(capture, { wary = true }, "Wary")
		nothingHeld(capture)
		start(capture, { wary = false })
		refused(capture, { playerKey = 2, life = lifeB, wary = true }, "Reserved", "a reserved one says Reserved")
	end)

	case("constants and tables are frozen", function()
		assert(table.isfrozen(C), "constants")
		local view = start(fresh())
		assert(table.isfrozen(view.ring), "ring")
	end)

	case("the meter target sits inside the D3 window", function()
		assert(C.CALM_REQUIRED >= 4 and C.CALM_REQUIRED <= 6, "D3 asks for about 4 to 6 s")
		assert(C.TIME_LIMIT > C.CALM_REQUIRED * 2, "a late step must still fit")
	end)

	-- Everything at once.
	case("fuzz: no duplicate owner, no double grant, no stuck reservation", function()
		local rng = Random.new(20261107)
		local capture = fresh()
		local serial, now = 2, 0
		local pool = { "E:1", "E:2" }
		local grants, grantTotal, refusedReserved = {}, 0, 0
		local tokens, seenTokens = {}, {}
		local positions = { {}, {}, {} }
		local function check()
			local holders = 0
			for encounterId, token in pairs(capture.reservations) do
				holders += 1
				local session = capture.sessions[token]
				assert(session, "reservation without a session: " .. encounterId)
				equal(session.encounterId, encounterId)
			end
			equal(holders, count(capture.sessions), "one reservation per session")
			equal(count(capture.byPlayer), holders, "one session per player")
		end
		local function ended(out)
			if type(out) ~= "table" or out.phase == "Active" then return end
			if out.grant then
				grants[out.encounterId] = (grants[out.encounterId] or 0) + 1
				equal(grants[out.encounterId], 1, "double grant on " .. out.encounterId)
				grantTotal += 1
			end
			tokens[out.playerKey] = nil
		end
		local function replace(id)
			for index, value in ipairs(pool) do
				if value == id then
					serial += 1
					pool[index] = "E:" .. serial
				end
			end
		end
		for _ = 1, 6000 do
			local player = rng:NextInteger(1, 3)
			local roll = rng:NextNumber()
			if rng:NextNumber() < 0.4 then now += C.SAMPLE end
			local token = tokens[player]
			if roll < 0.2 then
				local id = pool[rng:NextInteger(1, 2)]
				local x = rng:NextNumber(0, 9)
				local ok, view = capture:begin(input({ playerKey = player, encounterId = id, now = now,
					x = x, distance = x, dir = rng:NextInteger(0, 1) * 2 - 1 }))
				if ok then
					assert(not seenTokens[view.token], "token reused")
					seenTokens[view.token] = true
					tokens[player] = view.token
					positions[player] = view
				elseif view == "Reserved" then
					refusedReserved += 1
				end
			elseif roll < 0.8 then
				if token then
					local x, z = center(positions[player], now)
					local out = capture:sample(token, at(now, x, z))
					ended(out)
					if out and out.phase == "Active" and out.stage == "Seal" then
						local press = rng:NextNumber() < 0.6 and sealMiddle(out.seal) or now + rng:NextNumber(0, 3)
						local ok, sealed = capture:seal(token, player, { now = press, alive = true, life = lifeA,
							bagRoom = true, collectionRoom = true })
						if ok then ended(sealed) end
					end
				end
			elseif roll < 0.84 then
				local other = tokens[rng:NextInteger(1, 3)] or "cap:0"
				local ok, out = capture:cancel(other, player, now)
				if ok then ended(out) end
			elseif roll < 0.86 then
				capture:notifyStruck(player)
			elseif roll < 0.88 then
				ended(capture:drop(player, now))
			elseif roll < 0.92 then
				for _, out in ipairs(capture:sweep(now)) do ended(out) end
			elseif roll < 0.94 then
				local id = pool[rng:NextInteger(1, 2)]
				ended(capture:retire(id, now))
				replace(id)
			elseif token then
				capture:sample(token, ({ nil, 42, at(NAN, 0, 0), at(now - 3, 0, 0) })[rng:NextInteger(1, 4)])
			end
			for _, id in ipairs(pool) do
				if capture:encounterState(id, now) == "Captured" or capture:encounterState(id, now) == "Left" then
					ended(capture:retire(id, now))
					replace(id)
				end
			end
			check()
		end
		assert(grantTotal > 0, "the fuzz never completed a capture")
		assert(refusedReserved > 0, "the fuzz never raced")
		for key = 1, 3 do capture:drop(key, now) end
		nothingHeld(capture)
	end)

	case("the module source stays pure", function()
		assert(type(source) == "string" and #source > 0, "module source is required")
		for _, token in ipairs({ "game", "workspace", "script", "Instance", "require", "task", "tick", "wait",
			"os", "time", "GetService", "Players", "RemoteEvent", "FireClient", "CFrame", "Vector3", "DateTime",
			"math%.random", "Random", "HttpService", "GetServerTimeNow", "Heartbeat", "print", "warn" }) do
			assert(not string.find(source, "%f[%w_]" .. token .. "%f[^%w_]"), "impure token: " .. token)
		end
	end)

	return result
end

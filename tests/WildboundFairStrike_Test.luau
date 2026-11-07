-- Invoke with require(freshTestClone)(require(freshFairStrikeClone), require(freshFlagsClone),
-- freshFairStrikeClone.Source, WildboundWorld.Source). FS numbers refer to docs/mechanics/wildbound-fair-strike.md.
return function(FairStrike, Flags, source, worldSource)
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
	local PLACE = 122652861404212

	-- damageMode ---------------------------------------------------------------------------------------
	case("the shipped flag is off and lists no private place", function()
		equal(Flags.damageMode, "off")
		equal(type(Flags.privateTestPlaceIds), "table")
		equal(next(Flags.privateTestPlaceIds), nil)
		equal(FairStrike.effectiveMode(Flags, PLACE), "off")
	end)
	case("FS-04 private with an empty list is off and flagged misconfigured", function()
		local mode, misconfigured = FairStrike.effectiveMode({ damageMode = "private", privateTestPlaceIds = {} }, PLACE)
		equal(mode, "off"); equal(misconfigured, true)
		mode, misconfigured = FairStrike.effectiveMode({ damageMode = "private", privateTestPlaceIds = { 1 } }, PLACE)
		equal(mode, "off"); equal(misconfigured, true)
	end)
	case("private is real only for a listed place", function()
		local mode, misconfigured = FairStrike.effectiveMode({ damageMode = "private", privateTestPlaceIds = { PLACE } }, PLACE)
		equal(mode, "private"); equal(misconfigured, false)
	end)
	case("off and bad input never turn damage on", function()
		for _, flags in ipairs({ nil, 5, {}, { damageMode = "off", privateTestPlaceIds = { PLACE } },
			{ damageMode = "on", privateTestPlaceIds = { PLACE } }, { damageMode = "private" },
			{ damageMode = "private", privateTestPlaceIds = "122652861404212" },
			{ damageMode = "private", privateTestPlaceIds = { tostring(PLACE) } } }) do
			equal(FairStrike.effectiveMode(flags, PLACE), "off")
		end
		equal(FairStrike.effectiveMode({ damageMode = "private", privateTestPlaceIds = { PLACE } }, nil), "off")
		equal(FairStrike.effectiveMode({ damageMode = "private", privateTestPlaceIds = { PLACE } }, 0 / 0), "off")
	end)
	case("FS-05 the world never derives damage from streaming", function()
		assert(type(worldSource) == "string" and #worldSource > 1000, "world source missing")
		assert(not worldSource:find("StreamingEnabled", 1, true), "world reads StreamingEnabled")
		assert(not worldSource:find("local damageEnabled", 1, true), "world still derives damageEnabled")
		assert(worldSource:find("FairStrike.effectiveMode(", 1, true), "world must use effectiveMode")
	end)
	case("FS-03 TakeDamage is reachable only behind the private mode guard", function()
		local count = 0
		for _ in worldSource:gmatch("TakeDamage") do count += 1 end
		equal(count, 1, "TakeDamage occurrences")
		local body = worldSource:match("local function applyRealStrike%(.-\nend\n")
		assert(body, "applyRealStrike missing")
		assert(body:find("TakeDamage", 1, true), "TakeDamage must live in applyRealStrike")
		local first = body:match("^local function applyRealStrike%([^\n]*\n%s*([^\n]+)")
		equal(first, 'if damageMode ~= "private" then return false end', "first line of applyRealStrike")
		local calls = 0
		for _ in worldSource:gmatch("applyRealStrike%(") do calls += 1 end
		equal(calls, 2, "one definition and one call")
	end)
	case("the flag module and rules stay server-only and pure", function()
		assert(type(source) == "string" and #source > 100, "source missing")
		for _, banned in ipairs({ "game:", "workspace", "Instance.new", "os.clock", "tick(", "Random", "math.random",
			"RemoteEvent", "SetAttribute" }) do
			assert(not source:find(banned, 1, true), "fair-strike source uses " .. banned)
		end
		assert(table.isfrozen(Flags), "flags must be frozen")
	end)

	-- Ledger helpers ----------------------------------------------------------------------------------
	local C = FairStrike.CONSTANTS
	local A, B = 1, 2 -- user ids
	local LIFE_A, LIFE_A2, LIFE_B = { "lifeA" }, { "lifeA2" }, { "lifeB" }
	local ALL = { guardian = true, binding = true, geometry = true }
	-- A player who has stood near for long enough, is ready and alive on the network.
	local function honest(state, userId, life, now)
		FairStrike.dwellStep(state, userId, life, true, now - C.DWELL_SECONDS - 1)
		FairStrike.ready(state, userId, life, true, true)
		FairStrike.pulse(state, userId, life, now)
	end
	local function attack(state, now, userId, life, generation)
		userId, life = userId or A, life or LIFE_A
		local issued = FairStrike.issue(state, { userId = userId, life = life, guardianGeneration = generation or 1,
			now = now, endsAt = now + 1.4, dwellOk = FairStrike.dwellOk(state, userId, life, now) })
		FairStrike.warned(state, issued.attackId, now)
		return issued
	end
	local function fresh(now)
		local state = FairStrike.new()
		honest(state, A, LIFE_A, now)
		return state
	end
	local function count(state, key) return state.counters[key] end
	local function only(state, key)
		for name, value in pairs(state.counters) do
			if name ~= "attack.issued" then
				equal(value, name == key and 1 or 0, "counter " .. name)
			end
		end
	end

	case("constants match the decision record", function()
		equal(C.K, 2); equal(C.ACK_SECONDS, 1.0); equal(C.LIVENESS_SECONDS, 3); equal(C.DWELL_SECONDS, 3.0)
		equal(C.WARNING_LEAD, 1.2); equal(C.MAX_ID_BYTES, 64); equal(C.CLOSED_MEMORY, 8)
		equal(C.MARKED_HEALTH, 35); equal(C.REST_SECONDS, 5); equal(C.STALL_SECONDS, 0.5)
		assert(table.isfrozen(C), "constants must be frozen")
	end)
	case("a clean attack resolves as a shadow strike while off", function()
		local state = fresh(100)
		local issued = attack(state, 100)
		equal(FairStrike.acknowledge(state, A, LIFE_A, issued.attackId, 0, 100.3), "accepted")
		local out = FairStrike.resolve(state, issued, ALL, 101.4, "off")
		equal(out.outcome, "shadow"); equal(out.effect, nil)
		only(state, "shadow.wouldStrike")
		equal(FairStrike.lifeRecord(state, A, LIFE_A).marks, 0, "shadow never marks")
	end)
	case("FS-01 each gate failing alone cancels with exactly its counter", function()
		local function run(prepare, gates, key)
			local state = fresh(100)
			local issued = prepare and prepare(state) or attack(state, 100)
			if issued.ackedAt == nil and not issued.skipAck then FairStrike.acknowledge(state, A, LIFE_A, issued.attackId, 0, 100.3) end
			local out = FairStrike.resolve(state, issued, gates or ALL, issued.at or 101.4, "private")
			equal(out.outcome, "cancel", key); equal(out.counter, key)
			only(state, key)
		end
		-- 1 duplicate: resolving the same attack twice
		do
			local state = fresh(100)
			local issued = attack(state, 100)
			FairStrike.acknowledge(state, A, LIFE_A, issued.attackId, 0, 100.3)
			equal(FairStrike.resolve(state, issued, ALL, 101.4, "off").outcome, "shadow")
			local again = FairStrike.resolve(state, issued, ALL, 101.6, "private")
			equal(again.outcome, "cancel"); equal(again.counter, "cancel.duplicate")
			equal(count(state, "cancel.duplicate"), 1); equal(count(state, "strike.executed"), 0)
		end
		run(function(state)
			local issued = attack(state, 100)
			FairStrike.noteStep(state, 100.2); FairStrike.noteStep(state, 100.75)
			return issued
		end, nil, "cancel.stall")
		run(nil, { guardian = false, binding = true, geometry = true }, "cancel.guardian")
		run(nil, { guardian = true, binding = false, geometry = true }, "cancel.binding")
		run(nil, { guardian = true, binding = true, geometry = false }, "cancel.geometry")
		run(function(state)
			FairStrike.dwellStep(state, A, LIFE_A, false, 99.9)
			FairStrike.dwellStep(state, A, LIFE_A, true, 99)
			return attack(state, 100)
		end, nil, "cancel.dwell")
		run(function(state)
			local issued = FairStrike.issue(state, { userId = A, life = LIFE_A, guardianGeneration = 1, now = 100,
				endsAt = 101.4, dwellOk = true })
			return issued -- never warned
		end, nil, "cancel.warning")
		run(function(state)
			local issued = attack(state, 100)
			issued.at = 101.1 -- the warning stood under 1.2 s
			return issued
		end, nil, "cancel.warning")
		run(function(state)
			local other = FairStrike.new()
			state.lives = other.lives
			FairStrike.dwellStep(state, A, LIFE_A, true, 96)
			FairStrike.pulse(state, A, LIFE_A, 100)
			return attack(state, 100) -- never reported ready
		end, nil, "cancel.notReady")
		run(function(state)
			local issued = attack(state, 100); issued.skipAck = true
			return issued
		end, nil, "cancel.ackMissing")
		run(function(state)
			local issued = attack(state, 100); issued.skipAck = true
			equal(FairStrike.acknowledge(state, A, LIFE_A, issued.attackId, 0, 101.01), "late")
			state.counters["ack.late"] = 0
			return issued
		end, nil, "cancel.ackLate")
	end)
	case("FS-02 two failing gates count only the earlier one", function()
		local state = fresh(100)
		local issued = attack(state, 100)
		local out = FairStrike.resolve(state, issued, { guardian = true, binding = false, geometry = false }, 101.4, "private")
		equal(out.counter, "cancel.binding"); equal(count(state, "cancel.geometry"), 0)
		equal(count(state, "cancel.ackMissing"), 0)
		equal(FairStrike.lifeRecord(state, A, LIFE_A).kUsed, 0, "FS-25 a server gate never spends K")
	end)
	case("FS-03 and FS-04 a passing strike is real only in private mode", function()
		local state = fresh(100)
		local issued = attack(state, 100)
		FairStrike.acknowledge(state, A, LIFE_A, issued.attackId, 0, 100.3)
		local out = FairStrike.resolve(state, issued, ALL, 101.4, "private")
		equal(out.outcome, "strike"); equal(out.effect, "Marked"); equal(count(state, "strike.executed"), 1)
		equal(FairStrike.lifeRecord(state, A, LIFE_A).marks, 1)
		for _, mode in ipairs({ "off", "on", nil, 1 }) do
			local s = fresh(100)
			local i = attack(s, 100)
			FairStrike.acknowledge(s, A, LIFE_A, i.attackId, 0, 100.3)
			equal(FairStrike.resolve(s, i, ALL, 101.4, mode).outcome, "shadow")
		end
	end)
	case("FS-06 the counter identity holds after a random run", function()
		local rng = Random.new(6)
		local state = FairStrike.new()
		local now = 100
		for round = 1, 300 do
			local userId = rng:NextInteger(1, 3)
			local life = { round }
			if rng:NextNumber() < 0.8 then FairStrike.dwellStep(state, userId, life, true, now - 4) end
			if rng:NextNumber() < 0.8 then FairStrike.ready(state, userId, life, true, true) end
			if rng:NextNumber() < 0.7 then FairStrike.pulse(state, userId, life, now) end
			local issued = attack(state, now, userId, life)
			if rng:NextNumber() < 0.6 then FairStrike.acknowledge(state, userId, life, issued.attackId, 0, now + rng:NextNumber() * 1.5) end
			if rng:NextNumber() < 0.1 then FairStrike.noteStep(state, now); FairStrike.noteStep(state, now + 0.8) end
			if rng:NextNumber() < 0.15 then
				FairStrike.cancelEarly(state, "chase")
			else
				local gates = { guardian = rng:NextNumber() < 0.95, binding = rng:NextNumber() < 0.9, geometry = rng:NextNumber() < 0.8 }
				FairStrike.resolve(state, issued, gates, now + 1.4, rng:NextNumber() < 0.5 and "private" or "off")
				if rng:NextNumber() < 0.1 then FairStrike.resolve(state, issued, gates, now + 1.6, "private") end
			end
			now += 10
		end
		equal(count(state, "attack.issued"), 300)
		assert(FairStrike.identityHolds(state.counters), "identity broken")
		state.counters["cancel.geometry"] += 1
		assert(not FairStrike.identityHolds(state.counters), "identity must catch a stray count")
	end)

	-- Acknowledgement binding (FS-10 to FS-16) ---------------------------------------------------------
	case("FS-10 an on-time acknowledgement is accepted once", function()
		local state = fresh(100)
		local issued = attack(state, 100)
		equal(FairStrike.acknowledge(state, A, LIFE_A, issued.attackId, 0, 100.001), "accepted")
		equal(issued.ackedAt, 100.001)
		equal(FairStrike.acknowledge(state, A, LIFE_A, issued.attackId, 0, 101.0 + 1e-9 - 1e-9), "duplicate", "FS-14")
		equal(count(state, "ack.duplicate"), 1); equal(issued.ackedAt, 100.001, "first stands")
	end)
	case("FS-11 forged acknowledgements are ignored without error", function()
		local state = fresh(100)
		local issued = attack(state, 100)
		for _, id in ipairs({ "atk:nope", 5, string.rep("a", 65), {}, true, "" }) do
			equal(FairStrike.acknowledge(state, A, LIFE_A, id, 0, 100.2), "forged")
		end
		equal(FairStrike.acknowledge(state, A, LIFE_A, nil, 0, 100.2), "forged")
		equal(FairStrike.acknowledge(state, A, LIFE_A, issued.attackId, 1, 100.2), "forged", "extra arguments")
		equal(count(state, "ack.forged"), 8); equal(issued.ackedAt, nil)
		assert(#issued.attackId <= C.MAX_ID_BYTES, "ids fit the limit")
	end)
	case("FS-12 another player's acknowledgement has no effect", function()
		local state = fresh(100)
		honest(state, B, LIFE_B, 100)
		local issued = attack(state, 100)
		equal(FairStrike.acknowledge(state, B, LIFE_B, issued.attackId, 0, 100.2), "wrongOwner")
		equal(issued.ackedAt, nil); equal(count(state, "ack.wrongOwner"), 1)
	end)
	case("FS-13 a late acknowledgement leaves it missing at impact", function()
		local state = fresh(100)
		local issued = attack(state, 100)
		equal(FairStrike.acknowledge(state, A, LIFE_A, issued.attackId, 0, 101.01), "late")
		equal(FairStrike.acknowledge(state, A, LIFE_A, issued.attackId, 0, 102), "duplicate")
		equal(count(state, "ack.late"), 1); equal(issued.ackedAt, nil)
		equal(FairStrike.resolve(state, issued, ALL, 102, "private").counter, "cancel.ackLate")
		equal(FairStrike.acknowledge(state, A, LIFE_A, issued.attackId, 0, 102.1), "late", "FS-16 after resolution")
	end)
	case("FS-15 a prior life or prior guardian id is ignored and the new attack is unaffected", function()
		local state = fresh(100)
		local old = attack(state, 100)
		FairStrike.cancelEarly(state, "lifeChanged")
		honest(state, A, LIFE_A2, 110)
		local current = attack(state, 110, A, LIFE_A2)
		equal(FairStrike.acknowledge(state, A, LIFE_A2, old.attackId, 0, 110.1), "priorLife")
		equal(current.ackedAt, nil)
		FairStrike.cancelEarly(state, "guardian")
		local next = attack(state, 120, A, LIFE_A2, 2)
		equal(FairStrike.acknowledge(state, A, LIFE_A2, current.attackId, 0, 120.1), "forged")
		equal(next.ackedAt, nil)
		equal(count(state, "ack.priorLife"), 1); equal(count(state, "ack.forged"), 1)
		equal(count(state, "attack.cancelledEarly"), 2)
	end)
	case("an acknowledgement from the right player on a different character is a prior life", function()
		local state = fresh(100)
		local issued = attack(state, 100)
		equal(FairStrike.acknowledge(state, A, LIFE_A2, issued.attackId, 0, 100.2), "priorLife")
		equal(issued.ackedAt, nil)
	end)
	case("only the last eight closed ids are remembered", function()
		local state = fresh(100)
		local first = attack(state, 100)
		FairStrike.cancelEarly(state, "lifeChanged")
		for i = 1, C.CLOSED_MEMORY do attack(state, 100 + i); FairStrike.cancelEarly(state, "chase") end
		equal(FairStrike.acknowledge(state, A, LIFE_A, first.attackId, 0, 200), "forged")
		equal(#state.closed, C.CLOSED_MEMORY)
	end)
	case("attack ids are never reused", function()
		local state = fresh(100)
		local seen = {}
		for i = 1, 50 do
			local issued = attack(state, 100 + i)
			assert(not seen[issued.attackId], "reused id"); seen[issued.attackId] = true
			FairStrike.cancelEarly(state, "chase")
		end
	end)

	-- K and liveness (FS-20 to FS-25) ------------------------------------------------------------------
	case("FS-20 to FS-22 missing acks cancel twice, then strike while alive, then cancel without liveness", function()
		local state = fresh(100)
		local outs = {}
		for i = 1, 3 do
			FairStrike.pulse(state, A, LIFE_A, 100 + i * 10)
			table.insert(outs, FairStrike.resolve(state, attack(state, 100 + i * 10), ALL, 101.4 + i * 10, "off"))
		end
		equal(outs[1].counter, "cancel.ackMissing"); equal(outs[2].counter, "cancel.ackMissing")
		equal(outs[3].outcome, "shadow"); equal(outs[3].unacked, true)
		equal(count(state, "strike.unacked"), 1); equal(FairStrike.lifeRecord(state, A, LIFE_A).kUsed, 2)
		local stale = FairStrike.resolve(state, attack(state, 200), ALL, 201.4, "off")
		equal(stale.counter, "cancel.noLiveness"); equal(FairStrike.lifeRecord(state, A, LIFE_A).kUsed, 2)
	end)
	case("liveness is a three second window", function()
		local state = fresh(100)
		state.lives[A].kUsed = C.K
		FairStrike.pulse(state, A, LIFE_A, 98.5)
		equal(FairStrike.resolve(state, attack(state, 100), ALL, 101.5, "off").outcome, "shadow")
		local s2 = fresh(100); s2.lives[A].kUsed = C.K
		FairStrike.pulse(s2, A, LIFE_A, 98.49)
		equal(FairStrike.resolve(s2, attack(s2, 100), ALL, 101.5, "off").counter, "cancel.noLiveness")
	end)
	case("FS-23 not ready and missing ack spend one K", function()
		local state = FairStrike.new()
		FairStrike.dwellStep(state, A, LIFE_A, true, 90)
		FairStrike.pulse(state, A, LIFE_A, 100)
		local out = FairStrike.resolve(state, attack(state, 100), ALL, 101.4, "off")
		equal(out.counter, "cancel.notReady"); equal(FairStrike.lifeRecord(state, A, LIFE_A).kUsed, 1)
	end)
	case("FS-24 a new life resets marks, K, dwell and readiness", function()
		local state = fresh(100)
		local rec = FairStrike.lifeRecord(state, A, LIFE_A)
		rec.marks, rec.kUsed = 1, 2
		local new = FairStrike.lifeRecord(state, A, LIFE_A2)
		equal(new.marks, 0); equal(new.kUsed, 0); equal(new.clientReady, false); equal(new.nearSince, nil)
	end)
	case("readiness only moves from false to true and needs both reports", function()
		local state = FairStrike.new()
		equal(FairStrike.ready(state, A, LIFE_A, true, false), false)
		equal(FairStrike.lifeRecord(state, A, LIFE_A).clientReady, false)
		equal(FairStrike.ready(state, A, LIFE_A, "true", true), false)
		equal(FairStrike.ready(state, A, LIFE_A, true, true), true)
		equal(FairStrike.ready(state, A, LIFE_A, false, false), false)
		equal(FairStrike.ready(state, A, LIFE_A, true, true), false, "a repeat report is not a new transition")
		equal(FairStrike.lifeRecord(state, A, LIFE_A).clientReady, true)
	end)

	-- Dwell (FS-30, FS-31) ------------------------------------------------------------------------------
	case("FS-30 dwell needs three seconds near on the same life", function()
		local state = FairStrike.new()
		FairStrike.dwellStep(state, A, LIFE_A, true, 100)
		equal(FairStrike.dwellOk(state, A, LIFE_A, 102.9), false)
		equal(FairStrike.dwellOk(state, A, LIFE_A, 103.0), true)
		FairStrike.dwellStep(state, A, LIFE_A, true, 102) -- staying near keeps the start
		equal(FairStrike.dwellOk(state, A, LIFE_A, 103.0), true)
		FairStrike.dwellStep(state, A, LIFE_A, false, 103.2)
		FairStrike.dwellStep(state, A, LIFE_A, true, 103.4)
		equal(FairStrike.dwellOk(state, A, LIFE_A, 104), false, "left and returned")
		equal(FairStrike.dwellOk(state, A, LIFE_A2, 110), false, "character change")
		FairStrike.dwellStep(state, B, LIFE_B, true, 100)
		FairStrike.clearDwell(state)
		equal(FairStrike.dwellOk(state, B, LIFE_B, 110), false, "relocation")
		equal(FairStrike.dwellOk(state, 99, LIFE_B, 110), false, "unknown player")
	end)
	case("FS-31 an unreadable streaming radius fails the gate", function()
		equal(FairStrike.dwellRadius(64), 64)
		equal(FairStrike.dwellRadius(200), 64)
		equal(FairStrike.dwellRadius(40), 40)
		for _, bad in ipairs({ 0 / 0, math.huge, -1, 0, "64" }) do equal(FairStrike.dwellRadius(bad), nil) end
		equal(FairStrike.dwellRadius(nil), nil)
	end)

	-- Staged strike and rest (FS-42, FS-44) ------------------------------------------------------------
	case("FS-42 the second real strike defeats", function()
		local state = fresh(100)
		local function strike(now)
			FairStrike.pulse(state, A, LIFE_A, now)
			local issued = attack(state, now)
			FairStrike.acknowledge(state, A, LIFE_A, issued.attackId, 0, now + 0.2)
			return FairStrike.resolve(state, issued, ALL, now + 1.4, "private")
		end
		equal(strike(100).effect, "Marked"); equal(strike(110).effect, "Defeated")
		equal(count(state, "strike.executed"), 2)
	end)
	case("FS-44 the mark pins health until five seconds of rest", function()
		local state = fresh(100)
		equal(FairStrike.restStep(state, A, LIFE_A, false, 100), "none", "not marked")
		FairStrike.lifeRecord(state, A, LIFE_A).marks = 1
		equal(FairStrike.restStep(state, A, LIFE_A, false, 100), "pin")
		equal(FairStrike.restStep(state, A, LIFE_A, true, 101), "pin")
		equal(FairStrike.restStep(state, A, LIFE_A, true, 104), "pin", "3 s")
		equal(FairStrike.restStep(state, A, LIFE_A, false, 104.2), "pin", "left")
		equal(FairStrike.restStep(state, A, LIFE_A, true, 105), "pin")
		equal(FairStrike.restStep(state, A, LIFE_A, true, 109.9), "pin", "4.9 s")
		equal(FairStrike.restStep(state, A, LIFE_A, true, 110), "cleared", "5.0 s")
		equal(FairStrike.lifeRecord(state, A, LIFE_A).marks, 0)
		equal(FairStrike.restStep(state, A, LIFE_A, true, 111), "none")
	end)

	-- Rate limits and identity helpers -----------------------------------------------------------------
	case("the rate limiter drops excess inside its window", function()
		local bucket = {}
		for i = 1, 4 do equal(FairStrike.allow(bucket, 100 + i * 0.01, 4, 1), true) end
		equal(FairStrike.allow(bucket, 100.5, 4, 1), false)
		equal(FairStrike.allow(bucket, 101.02, 4, 1), true)
		equal(FairStrike.allow(nil, 100, 4, 1), false)
		equal(FairStrike.allow({}, 0 / 0, 4, 1), false)
	end)
	case("every documented counter starts at zero", function()
		local counters = FairStrike.new().counters
		for _, key in ipairs({ "attack.issued", "attack.cancelledEarly", "strike.executed", "shadow.wouldStrike",
			"strike.unacked", "cancel.duplicate", "cancel.stall", "cancel.guardian", "cancel.binding", "cancel.geometry",
			"cancel.dwell", "cancel.warning", "cancel.notReady", "cancel.ackMissing", "cancel.ackLate", "cancel.noLiveness",
			"ack.forged", "ack.wrongOwner", "ack.duplicate", "ack.priorLife", "ack.late", "flagMisconfigured",
			"effect.failed", "ambush.moved", "ambush.skipped" }) do
			equal(counters[key], 0, key)
		end
		local state = FairStrike.new()
		FairStrike.count(state, "effect.failed"); FairStrike.count(state, "not.a.counter")
		equal(state.counters["effect.failed"], 1); equal(state.counters["not.a.counter"], nil)
	end)

	return result
end

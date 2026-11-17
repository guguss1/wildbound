-- Invoke with require(freshTestClone)(require(freshCandyRaftClone), require(freshCandyV3LayoutClone),
--   require(freshCandyLayoutClone), require(freshTextClone),
--   { service = <WildboundCandyRaftService Source>, client = <WildboundCandyRaftClient Source> }).
-- Caramelo v3 raft, the Balsa Banana Split (owner request 2026-11-17: "a raft to cross to the other side", free for
-- now; docs/design/wildbound-caramelo-v3-plan.md V3-D13): the pure shuttle rules (dock to dock along the lane, speed,
-- boarding and leaving, one rider, respawn at its dock), the client request filter, the free rule, and source pins of
-- the server and client wiring. Changes nothing.
return function(Raft, V3, Layout, Text, sources)
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
	local function has(source, needle, label)
		assert(type(source) == "string" and string.find(source, needle, 1, true), (label or "missing") .. ": " .. needle)
	end
	local function hasNot(source, needle, label)
		assert(type(source) == "string" and not string.find(source, needle, 1, true), (label or "must not appear") .. ": " .. needle)
	end
	local service = type(sources) == "table" and sources.service or ""
	local client = type(sources) == "table" and sources.client or ""
	local lane = { { x = 0, z = 0 }, { x = 30, z = 0 }, { x = 30, z = 40 } } -- 70 studs
	-- Runs the raft until it docks or `limit` seconds pass; returns the events and the time it took.
	local function sail(state, t, limit, seated)
		local events, start = {}, t
		while t - start < limit do
			t += 1 / 30
			for _, e in ipairs(Raft.step(state, 1 / 30, t, seated)) do table.insert(events, e) end
			if state.status == "Docked" or state.status == "Adrift" and not seated then
				if state.status == "Docked" then break end
			end
		end
		return events, t - start, t
	end

	case("RF1: the lane, its length and points", function()
		near(Raft.laneLength(lane), 70, "length")
		equal(Raft.laneLength({ { x = 0, z = 0 } }), nil, "one point")
		equal(Raft.laneLength({ { x = 0, z = 0 }, { x = 0 / 0, z = 0 } }), nil, "a bad point")
		local x, z = Raft.pointAt(lane, 45)
		near(x, 30, "x on the second leg"); near(z, 15, "z on the second leg")
		local _, _, yaw = Raft.pointAt(lane, 10)
		near(-math.sin(yaw), 1, "looks along +x on the first leg", 1e-9)
		local ex, ez = Raft.pointAt(lane, 999)
		near(ex, 30); near(ez, 40, "clamped to the end")
		local world = V3.raftLane(Layout.CENTRE)
		assert(Raft.laneLength(world) and Raft.laneLength(world) >= 15, "the layout's lane is a real crossing")
		assert(Raft.new(nil) == nil, "no lane, no raft")
	end)

	case("RF2: one rider boards the docked raft from close by; everyone else waits", function()
		local s = Raft.new(lane, 1)
		equal(s.status, "Docked"); equal(s.dock, 1); near(s.s, 0)
		local ok, why = Raft.board(s, 1, Raft.BOARD_STUDS + 1, true, 0)
		assert(not ok and why == "TooFar", "too far: " .. tostring(why))
		ok, why = Raft.board(s, 1, 3, false, 0)
		assert(not ok and why == "Dead", "dead")
		ok, why = Raft.board(s, 1, 0 / 0, true, 0)
		assert(not ok and why == "Invalid", "bad distance")
		assert(Raft.board(s, 1, 3, true, 0), "boards")
		equal(s.status, "Boarding"); equal(s.rider, 1)
		ok, why = Raft.board(s, 2, 1, true, 0.1)
		assert(not ok and why == "Busy", "one rider")
	end)

	case("RF3: it departs after the wait, never passes its speed, brakes and docks on the far side", function()
		local s = Raft.new(lane, 1)
		Raft.board(s, 7, 2, true, 0)
		local events = Raft.step(s, 0.5, 0.5, true)
		equal(#events, 0, "still waiting")
		events = Raft.step(s, 0.6, Raft.DEPART_SECONDS + 0.1, true)
		equal(events[1] and events[1].kind, "Depart", "departs")
		local t, top, arrived = Raft.DEPART_SECONDS + 0.1, 0, nil
		for _ = 1, 30 * 60 do
			t += 1 / 30
			for _, e in ipairs(Raft.step(s, 1 / 30, t, true)) do if e.kind == "Arrived" then arrived = e end end
			top = math.max(top, s.speed)
			if arrived then break end
		end
		assert(arrived, "never arrived")
		equal(arrived.rider, 7, "the rider is set down")
		assert(top <= Raft.SPEED + 1e-9, "faster than SPEED")
		equal(s.status, "Docked"); equal(s.dock, 2, "the far dock"); near(s.s, 70); equal(s.rider, nil)
		-- and back: dock 2 sails towards dock 1
		assert(Raft.board(s, 8, 2, true, t), "boards at the far dock")
		local evs = sail(s, t, 60, true)
		local back = false
		for _, e in ipairs(evs) do if e.kind == "Arrived" then back = true end end
		assert(back and s.dock == 1 and s.s == 0, "back at dock 1")
	end)

	case("RF4: a rider who gets off mid-way leaves it adrift; it respawns at its home dock", function()
		local s = Raft.new(lane, 1)
		Raft.board(s, 3, 1, true, 0)
		local t = 0
		for _ = 1, 60 do
			t += 1 / 30
			Raft.step(s, 1 / 30, t, true)
		end
		equal(s.status, "Sailing", "sailing")
		local events = Raft.step(s, 1 / 30, t + 1 / 30, false)
		equal(events[1] and events[1].kind, "Left", "the rider left"); equal(events[1].rider, 3)
		equal(s.status, "Adrift", "adrift"); equal(s.rider, nil)
		t += 1 / 30
		local respawned = false
		while t < 30 do
			t += 1 / 30
			for _, e in ipairs(Raft.step(s, 1 / 30, t, false)) do if e.kind == "Respawn" then respawned = true end end
			if respawned then break end
		end
		assert(respawned, "never respawned")
		equal(s.status, "Docked"); equal(s.dock, 1, "home dock"); near(s.s, 0)
		-- leaving while boarding keeps it docked; only the rider may leave
		Raft.board(s, 4, 1, true, t)
		local ok, why = Raft.leave(s, 5, t)
		assert(not ok and why == "NotRider", "someone else cannot make the rider leave")
		assert(Raft.leave(s, 4, t), "the rider leaves")
		equal(s.status, "Docked", "still docked")
	end)

	case("RF5: client requests: only { action = \"Leave\" }, one every REQUEST_GAP seconds", function()
		equal(Raft.request({ action = "Leave" }), "Leave")
		equal(Raft.request({ action = "Buy" }), nil, "no other action")
		equal(Raft.request("Leave"), nil, "a string")
		equal(Raft.request({ action = 5 }), nil, "a number")
		equal(Raft.request({ action = string.rep("L", 100) }), nil, "too long")
		equal(Raft.request(nil), nil)
		equal(Raft.allowed(nil, 1), true, "the first request")
		equal(Raft.allowed(1, 1 + Raft.REQUEST_GAP / 2), false, "too soon")
		equal(Raft.allowed(1, 1 + Raft.REQUEST_GAP), true, "after the gap")
		equal(Raft.allowed(1, 0 / 0), false, "a bad clock")
	end)

	case("RF6: free, no purchase anywhere", function()
		equal(Raft.FREE, true, "FREE")
		for _, source in ipairs({ service, client }) do
			for _, banned in ipairs({ "MarketplaceService", "PromptProductPurchase", "PromptPurchase", "ProcessReceipt",
				"DevProduct", "GamePass" }) do
				hasNot(source, banned, "no purchase")
			end
		end
	end)

	case("RF7: server wiring: the v3 mark, the kit raft or a placeholder, a seat, the prompt, validated requests", function()
		has(service, "biome:GetAttribute(V3.MARK)", "waits for the migrated map")
		has(service, "V3.RAFT.asset", "the kit's raft")
		has(service, "Placeholder", "a placeholder when the kit lacks it")
		has(service, "Instance.new(\"Seat\")", "a seat")
		has(service, "raftSpec.seat", "at the kit's SeatAnchor")
		has(service, "CanTouch, seat.CanQuery = true, false, false, false", "nobody sits by touching it")
		has(service, "Raft.board(state, player.UserId, distance", "the server judges boarding")
		has(service, "seat:Sit(humanoid)", "the server seats the rider")
		has(service, "Raft.request(payload)", "requests are filtered")
		has(service, "Raft.allowed(lastRequest[player]", "requests are rate limited")
		has(service, "state.rider == player.UserId", "only the rider can ask to leave")
		has(service, "Raft.step(state, dt, t, seated)", "the rules step every frame")
		has(service, "model:PivotTo(", "the anchored raft moves")
		has(service, "PlayerRemoving", "a leaving player frees the raft")
		has(service, "Text.CANDY_RAFT.prompt", "the prompt's words")
		hasNot(service, "SistemaSonriente", "never touches the teammate's folders")
	end)

	case("RF8: client wiring and words", function()
		has(client, "remote:FireServer({ action = \"Leave\" })", "asks to leave")
		has(client, "remote.OnClientEvent:Connect", "listens")
		has(client, "ResetOnSpawn = false", "keeps its gui")
		has(client, "Text.CANDY_RAFT", "words from WildboundText")
		local T = Text.CANDY_RAFT
		for _, key in ipairs({ "prompt", "object", "boarded", "arrived", "left", "busy", "moving", "tooFar", "leave", "callPrompt",
			"called", "here" }) do
			assert(type(T[key]) == "string" and #T[key] > 0 and #T[key] <= 64, key)
		end
		for _, english in ipairs({ "raft", "Raft", "Leave", "Board" }) do
			for key, value in pairs(T) do
				if key ~= "object" then assert(not string.find(value, english, 1, true), key .. " reads English") end
			end
		end
	end)

	case("RF9: bob and the docked dock", function()
		for t = 0, 5, 0.3 do assert(math.abs(Raft.bob(t)) <= Raft.BOB.amplitude + 1e-9, "bob") end
		near(Raft.bob(0 / 0), 0, "a bad time is still")
		local s = Raft.new(lane, 2)
		equal(Raft.dockedAt(s), 2, "home dock 2"); near(s.s, 70)
		Raft.board(s, 1, 1, true, 0)
		equal(Raft.dockedAt(s), nil, "boarding is not docked")
	end)

	-- V3 review m6: call the raft over, set the rider on the deck, move only while under way.
	case("RF10: a player at the other dock calls the empty raft; it sails over with no rider", function()
		local s = Raft.new(lane, 1)
		local ok, why = Raft.call(s, 1, 0)
		assert(not ok and why == "Here", "already here")
		ok, why = Raft.call(s, 3, 0)
		assert(not ok and why == "Invalid", "no third dock")
		assert(Raft.call(s, 2, 0), "called to dock 2")
		equal(s.status, "Sailing"); equal(Raft.moving(s), true, "under way")
		ok, why = Raft.board(s, 1, 1, true, 0)
		assert(not ok and why == "Moving", "nobody boards a raft under way")
		local events = sail(s, 0, 60, false)
		local arrived
		for _, e in ipairs(events) do if e.kind == "Arrived" then arrived = e end end
		assert(arrived and arrived.rider == nil, "arrived empty")
		equal(s.dock, 2, "at dock 2"); equal(Raft.moving(s), false, "docked")
		Raft.board(s, 9, 1, true, 100)
		ok, why = Raft.call(s, 1, 100)
		assert(not ok and why == "Busy", "a ridden raft cannot be called")
	end)

	case("RF11: service wiring for the call, the set-down height and the quiet docked raft", function()
		has(service, "Raft.call(state, i, now())", "the server judges the call")
		has(service, "Text.CANDY_RAFT.callPrompt", "the call prompt's words")
		has(service, "surface + V3.DOCK.deckOver + 3", "the rider is set on the dock deck")
		has(service, "if wasMoving or Raft.moving(state) then place(t) end", "a docked raft is not moved every frame")
		has(client, "payload.kind == \"Called\"", "the client tells the caller")
		-- V3-D26 (Play 2026-11-17): a deferred move was snapped back onto the raft by the still-seated client; the rider
		-- is set down once the unseat has replicated, and again if it did not stick
		has(service, "task.delay(0.3, setDown)", "set down after the unseat replicates")
		has(service, "(root.Position - stand).Magnitude > 6 then setDown() end", "set down again if it did not stick")
	end)

	return result
end

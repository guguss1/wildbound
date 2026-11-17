-- Invoke with require(freshTestClone)(require(freshCandyRaftClone), require(freshCandyV3LayoutClone),
--   require(freshCandyLayoutClone), require(freshTextClone),
--   { service = <WildboundCandyRaftService Source>, client = <WildboundCandyRaftClient Source> }).
-- Caramelo raft, the Balsa Banana Split (owner request 2026-11-17: "a raft to cross to the other side", free for now,
-- docs/design/wildbound-caramelo-v3-plan.md V3-D13; Caramelo v4: "a raft you can steer", odd/tasks/
-- wildbound-caramelo-v2.md V4-D3): the pure steering rules (speed, turn, the chocolate area and its banks, never under
-- a bridge, docking at either dock, boarding and leaving, one rider, adrift and respawn at the home dock, the call),
-- the client request filter, the free rule, and source pins of the server and client wiring. The rules run against a
-- small fake river, so they do not depend on the exact layout; RF1 checks the real layout's docks. Changes nothing.
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

	-- The fake river (world coordinates): the rectangle x 0..100, z 0..40, with a bridge over x 45..55 that the raft
	-- never passes under. Dock 1's tip (10, 2) lies 2 studs off the south bank, its stand on the bank at (10, -10); dock
	-- 2's tip (30, 38) 2 studs off the north bank, its stand at (30, 50).
	local BRIDGE_X0, BRIDGE_X1 = 45, 55
	local function liquid(x, z) -- signed distance, negative inside
		return math.max(-x, x - 100, -z, z - 40)
	end
	local function underBridge(x, z, r)
		return x + r > BRIDGE_X0 and x - r < BRIDGE_X1 and z > -r - 8 and z < 40 + r + 8
	end
	local area = { inside = function(x, z, r)
		return liquid(x, z) <= -r and not underBridge(x, z, r)
	end }
	local fakeV3 = {
		DOCKS = { { id = "A", standX = 10, standZ = -10, tipX = 10, tipZ = 2 }, { id = "B", standX = 30, standZ = 50, tipX = 30, tipZ = 38 } },
		RAFT = { asset = "CV3_BananaRaft", homeDock = 1 },
		liquidDistance = liquid,
		nearBridge = function(x, z, reach) return underBridge(x, z, reach or 0) end,
	}
	local ORIGIN = { x = 0, z = 0 }
	local function docks() return Raft.docksFrom(fakeV3, ORIGIN) end
	local function look(yaw) return -math.sin(yaw), -math.cos(yaw) end
	local function flat(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
	-- Boards rider `id` at dock 1, waits out the departure and returns the state and the clock.
	local function launched(id)
		local s = Raft.new(docks(), 1)
		assert(Raft.board(s, id or 1, 2, true, 0), "boards")
		local t = 0
		for _ = 1, math.ceil(Raft.DEPART_SECONDS * 30) + 1 do
			t += 1 / 30
			Raft.step(s, 1 / 30, t, nil, true, area)
		end
		equal(s.status, "Sailing", "under way")
		return s, t
	end
	-- Steps `seconds` with one input; returns the events, the top speed and the clock.
	local function drive(s, t, seconds, input, seated)
		local events, top = {}, 0
		for _ = 1, math.floor(seconds * 30 + 0.5) do
			t += 1 / 30
			for _, e in ipairs(Raft.step(s, 1 / 30, t, input, seated ~= false, area)) do table.insert(events, e) end
			top = math.max(top, math.abs(s.speed))
			assert(liquid(s.x, s.z) <= 0, "left the chocolate at " .. s.x .. ", " .. s.z)
			assert(not underBridge(s.x, s.z, 0), "under the bridge at " .. s.x .. ", " .. s.z)
		end
		return events, top, t
	end
	local function kinds(events, kind)
		for _, e in ipairs(events) do if e.kind == kind then return e end end
		return nil
	end

	-- Deliberately changed (V4): RF1 was the fixed lane (laneLength, pointAt, V3.raftLane); V4-D3 steers freely, so it
	-- now checks the docks, the area built from the layout, and the real layout's dock tips.
	case("RF1: the docks, the area and the layout's docks", function()
		local d = docks()
		equal(#d, 2, "two docks")
		near(d[1].x, 10, "tip x"); near(d[1].z, 2, "tip z"); near(d[1].standX, 10); near(d[1].standZ, -10)
		local lx, lz = look(d[1].yaw)
		near(lx, 0, "dock 1 looks out over the river", 1e-9); near(lz, 1, "dock 1 looks out over the river", 1e-9)
		local shifted = Raft.docksFrom(fakeV3, { x = 612, z = -3 })
		near(shifted[2].x, 642, "world x"); near(shifted[2].z, 35, "world z")
		local built = Raft.area(fakeV3, { x = 100, z = 0 })
		equal(built.inside(120, 20, 3), true, "deep in the chocolate")
		equal(built.inside(101, 20, 3), false, "within the hull of the bank")
		equal(built.inside(150, 20, 0), false, "under the bridge")
		equal(built.inside(300, 20, 0), false, "on land")
		equal(Raft.new(nil), nil, "no docks, no raft")
		equal(Raft.new({ d[1] }), nil, "one dock is not a crossing")
		-- the real layout: two docks, each tip in the chocolate and off every bridge
		local real = Raft.docksFrom(V3, Layout.CENTRE)
		equal(real and #real, 2, "the layout has two docks")
		local realArea = Raft.area(V3, Layout.CENTRE)
		for i, dock in ipairs(real) do
			assert(realArea.inside(dock.x, dock.z, 0), "dock " .. i .. "'s tip is in the chocolate and off the bridges")
		end
		assert(flat(real[1].x, real[1].z, real[2].x, real[2].z) > 2 * Raft.DOCK_STUDS, "the docks are apart")
		equal(V3.RAFT.homeDock == 1 or V3.RAFT.homeDock == 2, true, "a home dock")
	end)

	case("RF2: one rider boards the docked raft from close by; everyone else waits", function()
		local s = Raft.new(docks(), 1)
		equal(s.status, "Docked"); equal(s.dock, 1); near(s.x, 10); near(s.z, 2)
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

	-- Deliberately changed (V4): RF3 was the lane's automatic crossing; the rider now drives it (V4-D3).
	case("RF3: the rider drives: throttle to at most SPEED, reverse to REVERSE, drag, turn rate by speed", function()
		local s = Raft.new(docks(), 1)
		Raft.board(s, 7, 2, true, 0)
		local events = Raft.step(s, 0.5, 0.5, { throttle = 1, steer = 0 }, true, area)
		equal(#events, 0, "still waiting")
		near(s.speed, 0, "no throttle while boarding")
		events = Raft.step(s, 0.6, Raft.DEPART_SECONDS + 0.1, nil, true, area)
		equal(events[1] and events[1].kind, "Depart", "departs")
		local t = Raft.DEPART_SECONDS + 0.1
		-- full ahead along +z (dock 1 looks north): it speeds up by ACCEL and never passes SPEED
		local z0 = s.z
		Raft.step(s, 1 / 30, t + 1 / 30, { throttle = 1, steer = 0 }, true, area)
		near(s.speed, Raft.ACCEL / 30, "speeds up by ACCEL", 1e-6)
		local _, top
		_, top, t = drive(s, t + 1 / 30, 1, { throttle = 1, steer = 0 })
		assert(s.z > z0 + 2, "it went forward")
		assert(top <= Raft.SPEED + 1e-9, "faster than SPEED")
		-- drag: no throttle slows it to a stop
		_, _, t = drive(s, t, 10, nil)
		near(s.speed, 0, "drag stops it")
		-- reverse, in open water (25, 20) looking north
		local back = Raft.new(docks(), 1)
		back.status, back.rider, back.armed, back.x, back.z = "Sailing", 7, true, 25, 20
		_, top = drive(back, 0, 2, { throttle = -1, steer = 0 })
		assert(back.speed < 0 and top <= Raft.REVERSE + 1e-9, "reverses at most REVERSE")
		assert(back.z < 20, "backs south")
		-- turning: D (steer +1) turns it to its right; at most TURN_RATE per second at speed, slower when still
		local still = Raft.new(docks(), 1)
		still.status, still.rider, still.x, still.z = "Sailing", 3, 20, 20
		local yaw0 = still.yaw
		Raft.step(still, 1, 1, { throttle = 0, steer = 1 }, true, area)
		local slowTurn = math.abs(still.yaw - yaw0)
		assert(slowTurn > 0 and slowTurn < Raft.TURN_RATE * 0.5, "turns slowly when still: " .. slowTurn)
		local moving = Raft.new(docks(), 1)
		moving.status, moving.rider, moving.x, moving.z, moving.speed = "Sailing", 3, 20, 20, Raft.SPEED
		local rx, rz = math.cos(moving.yaw), -math.sin(moving.yaw) -- its right
		local before = moving.yaw
		Raft.step(moving, 0.5, 1, { throttle = 1, steer = 1 }, true, area)
		local turned = math.abs(moving.yaw - before)
		assert(turned <= Raft.TURN_RATE * 0.5 + 1e-9 and turned > Raft.TURN_RATE * 0.4, "full turn rate at speed: " .. turned)
		local lx, lz = look(moving.yaw)
		assert(lx * rx + lz * rz > 0, "D turns it to the right")
	end)

	-- V4-D3: never out of the chocolate, never under a bridge; it slides along a bank met at an angle.
	case("RF4: the area: banks stop or slide it, the bridge is a wall", function()
		local s, t = launched(4)
		-- head-on into the north bank
		local events
		events, _, t = drive(s, t, 8, { throttle = 1, steer = 0 })
		assert(s.z <= 40 - Raft.HULL + 1e-6, "kept its hull off the bank: " .. s.z)
		near(s.speed, 0, "stopped at the bank", 1e-6)
		equal(kinds(events, "Arrived"), nil, "no dock there")
		-- slide: a raft heading north-east along the bank keeps moving east
		local slide = Raft.new(docks(), 1)
		slide.status, slide.rider, slide.armed = "Sailing", 5, true
		slide.x, slide.z, slide.yaw, slide.speed = 65, 40 - Raft.HULL - 0.1, math.atan2(-1, -1), 10 -- looks (+x, +z) / sqrt 2
		local x0 = slide.x
		Raft.step(slide, 0.2, 1, { throttle = 1, steer = 0 }, true, area)
		assert(slide.x > x0 + 0.5, "slid east along the bank")
		assert(slide.z <= 40 - Raft.HULL + 1e-6, "still off the bank")
		-- the bridge: driving east along the middle never gets under x 45..55
		local east = Raft.new(docks(), 1)
		east.status, east.rider, east.armed = "Sailing", 6, true
		east.x, east.z, east.yaw, east.speed = 30, 20, -math.pi / 2, 0 -- looks +x
		drive(east, 0, 10, { throttle = 1, steer = 0 })
		assert(east.x + Raft.HULL <= BRIDGE_X0 + 1e-6, "stopped before the bridge: " .. east.x)
		-- no area: it does not move at all
		local blind = Raft.new(docks(), 1)
		blind.status, blind.rider, blind.speed = "Sailing", 6, 10
		local bx, bz = blind.x, blind.z
		Raft.step(blind, 0.5, 1, { throttle = 1, steer = 0 }, true, nil)
		near(blind.x, bx); near(blind.z, bz, "no area, no move")
	end)

	case("RF5: client requests: only { action = \"Leave\" }, one every REQUEST_GAP seconds", function()
		equal(Raft.request({ action = "Leave" }), "Leave")
		equal(Raft.request({ action = "Buy" }), nil, "no other action")
		equal(Raft.request({ action = "Steer" }), nil, "steering is the seat's, never a request")
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

	-- Deliberately changed (V4): the seat is a VehicleSeat read on the server, the lane is gone, the area comes from
	-- the layout, and the step takes the seat's input and the area.
	case("RF7: server wiring: the v3 mark, the kit raft or a placeholder, a VehicleSeat, the prompt, validated requests", function()
		has(service, "biome:GetAttribute(V3.MARK)", "waits for the migrated map")
		has(service, "V3.RAFT.asset", "the kit's raft")
		has(service, "Placeholder", "a placeholder when the kit lacks it")
		has(service, "Instance.new(\"VehicleSeat\")", "a steerable seat")
		has(service, "raftSpec.seat", "at the kit's SeatAnchor")
		has(service, "CanTouch, seat.CanQuery = true, false, false, false", "nobody sits by touching it")
		has(service, "Raft.board(state, player.UserId, distance", "the server judges boarding")
		has(service, "seat:Sit(humanoid)", "the server seats the rider")
		has(service, "Raft.request(payload)", "requests are filtered")
		has(service, "Raft.allowed(lastRequest[player]", "requests are rate limited")
		has(service, "state.rider == player.UserId", "only the rider can ask to leave")
		has(service, "seat.ThrottleFloat", "the server reads the rider's throttle")
		has(service, "seat.SteerFloat", "the server reads the rider's steering")
		has(service, "seat.Occupant == humanoid", "only the seated rider steers")
		has(service, "Raft.step(state, dt, t, input, seated, area)", "the rules step every frame")
		has(service, "Raft.area(V3, Layout.CENTRE)", "the chocolate and the bridges from the layout")
		has(service, "Raft.docksFrom(V3, Layout.CENTRE)", "the docks from the layout")
		has(service, "model:PivotTo(", "the anchored raft moves")
		has(service, "PlayerRemoving", "a leaving player frees the raft")
		has(service, "Text.CANDY_RAFT.prompt", "the prompt's words")
		hasNot(service, "raftLane", "no fixed lane (V4-D3)")
		hasNot(service, "RAFT.lane", "no fixed lane (V4-D3)")
		hasNot(service, "SistemaSonriente", "never touches the teammate's folders")
		hasNot(service, "OnServerEvent:Connect(function(player, payload, ", "the client sends no steering")
	end)

	-- Deliberately changed (V4): the client also shows the steering hint, with a Spanish fallback until WildboundText
	-- carries CANDY_RAFT.steer and steerTouch.
	case("RF8: client wiring and words", function()
		has(client, "remote:FireServer({ action = \"Leave\" })", "asks to leave")
		has(client, "remote.OnClientEvent:Connect", "listens")
		has(client, "ResetOnSpawn = false", "keeps its gui")
		has(client, "Text.CANDY_RAFT", "words from WildboundText")
		has(client, "T.steer or ", "the steering hint, with a fallback")
		has(client, "T.steerTouch or ", "the touch hint, with a fallback")
		hasNot(client, "FireServer({ action = \"Steer\"", "the seat steers, the client sends no steering")
		local T = Text.CANDY_RAFT
		for _, key in ipairs({ "prompt", "object", "boarded", "arrived", "left", "busy", "moving", "tooFar", "leave", "callPrompt",
			"called", "here" }) do
			assert(type(T[key]) == "string" and #T[key] > 0 and #T[key] <= 64, key)
		end
		for _, key in ipairs({ "steer", "steerTouch" }) do
			assert(T[key] == nil or type(T[key]) == "string" and #T[key] > 0 and #T[key] <= 64, key)
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
		local s = Raft.new(docks(), 2)
		equal(Raft.dockedAt(s), 2, "home dock 2"); near(s.x, 30); near(s.z, 38)
		Raft.board(s, 1, 1, true, 0)
		equal(Raft.dockedAt(s), nil, "boarding is not docked")
	end)

	-- Deliberately changed (V4): the called raft no longer sails a lane; it is brought over CALL_SECONDS later
	-- (V4-D11-R1: a winding river and three bridges make a sailed path unsafe).
	case("RF10: a player at the other dock calls the empty raft; it comes over with no rider", function()
		local s = Raft.new(docks(), 1)
		local ok, why = Raft.call(s, 1, 0)
		assert(not ok and why == "Here", "already here")
		ok, why = Raft.call(s, 3, 0)
		assert(not ok and why == "Invalid", "no third dock")
		assert(Raft.call(s, 2, 0), "called to dock 2")
		equal(s.status, "Called")
		ok, why = Raft.board(s, 1, 1, true, 0)
		assert(not ok and why == "Moving", "nobody boards a called raft")
		ok, why = Raft.call(s, 2, 0.1)
		assert(not ok and why == "Moving", "one call at a time")
		local events = Raft.step(s, 1, Raft.CALL_SECONDS - 0.5, nil, false, area)
		equal(#events, 0, "not yet")
		events = Raft.step(s, 1, Raft.CALL_SECONDS + 0.01, nil, false, area)
		local arrived = kinds(events, "Arrived")
		assert(arrived and arrived.rider == nil and arrived.dock == 2, "arrived empty at dock 2")
		equal(s.status, "Docked"); equal(s.dock, 2, "at dock 2"); near(s.x, 30); near(s.z, 38)
		equal(Raft.moving(s), false, "docked")
		Raft.board(s, 9, 1, true, 100)
		ok, why = Raft.call(s, 1, 100)
		assert(not ok and why == "Busy", "a ridden raft cannot be called")
	end)

	-- Deliberately changed (V4): the "quiet docked raft" pin moved from wasMoving to a dirty flag set by every event,
	-- since a called or respawned raft jumps while not moving.
	case("RF11: service wiring for the call, the set-down height and the quiet docked raft", function()
		has(service, "Raft.call(state, i, now())", "the server judges the call")
		has(service, "Text.CANDY_RAFT.callPrompt", "the call prompt's words")
		has(service, "surface + V3.DOCK.deckOver + 3", "the rider is set on the dock deck")
		has(service, "if dirty or Raft.moving(state) then place(t) end", "a docked raft is not moved every frame")
		has(client, "payload.kind == \"Called\"", "the client tells the caller")
		-- V3-D26 (Play 2026-11-17): a deferred move was snapped back onto the raft by the still-seated client; the rider
		-- is set down once the unseat has replicated, and again if it did not stick
		has(service, "task.delay(0.3, setDown)", "set down after the unseat replicates")
		has(service, "(root.Position - stand).Magnitude > 6 then setDown() end", "set down again if it did not stick")
		has(service, "surface + bob", "it floats on the (deeper) surface")
		has(service, "HeadsUpDisplay = false", "no car speedometer")
	end)

	-- V4-D3: the rider docks by bringing it slowly to a dock tip, once it has left its own dock.
	case("RF12: docking at either dock: near the tip, slow, after leaving", function()
		local s, t = launched(11)
		-- creeping forward right after the departure never docks it back at once
		local events
		events, _, t = drive(s, t, 0.5, { throttle = 0.2, steer = 0 })
		equal(kinds(events, "Arrived"), nil, "no instant re-dock")
		-- a raft that left its dock and comes back slowly to dock 2's tip docks there
		local s2 = Raft.new(docks(), 1)
		s2.status, s2.rider, s2.armed = "Sailing", 12, true
		s2.x, s2.z, s2.yaw, s2.speed = 30, 30, math.pi, 2 -- 8 studs south of tip 2, looking north
		events, _, t = drive(s2, 0, 3, { throttle = 0.1, steer = 0 })
		local arrived = kinds(events, "Arrived")
		assert(arrived and arrived.rider == 12 and arrived.dock == 2, "docked at dock 2 with its rider set down")
		equal(s2.status, "Docked"); equal(s2.dock, 2); equal(s2.rider, nil)
		near(s2.x, 30); near(s2.z, 38, "laid at the tip"); near(s2.speed, 0)
		-- too fast past the tip: no docking
		local fast = Raft.new(docks(), 1)
		fast.status, fast.rider, fast.armed = "Sailing", 13, true
		fast.x, fast.z, fast.yaw, fast.speed = 22, 34, -math.pi / 2, Raft.SPEED -- looks +x, passes 4 studs from tip 2
		events = drive(fast, 0, 0.6, { throttle = 1, steer = 0 })
		equal(kinds(events, "Arrived"), nil, "too fast to dock")
		-- the dock it left counts again once it has been away
		local back = Raft.new(docks(), 1)
		back.status, back.rider, back.armed = "Sailing", 14, false
		back.x, back.z, back.yaw, back.speed = 10, 2 + Raft.ARM_STUDS + 1, 0, 0 -- away from dock 1, looking south
		events = drive(back, 0, 6, { throttle = 0.2, steer = 0 })
		arrived = kinds(events, "Arrived")
		assert(arrived and arrived.dock == 1, "back at dock 1")
	end)

	case("RF13: leaving: at a dock it docks, mid-river it drifts and respawns at home; only the rider leaves", function()
		local s, t = launched(3)
		local events
		events, _, t = drive(s, t, 2.5, { throttle = 1, steer = 0 })
		local x, z = s.x, s.z
		assert(flat(x, z, 10, 2) > Raft.DOCK_STUDS, "away from the dock")
		events = Raft.step(s, 1 / 30, t + 1 / 30, nil, false, area)
		t += 1 / 30
		local left = kinds(events, "Left")
		assert(left and left.rider == 3 and left.dock == nil, "the rider left mid-river")
		equal(s.status, "Adrift", "adrift"); equal(s.rider, nil)
		local respawned
		local drifted = false
		while t < 40 and not respawned do
			t += 1 / 30
			for _, e in ipairs(Raft.step(s, 1 / 30, t, nil, false, area)) do if e.kind == "Respawn" then respawned = e end end
			if not respawned and (s.x ~= x or s.z ~= z) then drifted = true end
		end
		assert(drifted, "it drifts on")
		assert(respawned, "never respawned")
		assert(t >= Raft.RESPAWN_SECONDS, "after RESPAWN_SECONDS")
		equal(s.status, "Docked"); equal(s.dock, 1, "home dock"); near(s.x, 10); near(s.z, 2)
		-- leaving near a dock docks it there and names the dock for the set-down
		local d = Raft.new(docks(), 1)
		d.status, d.rider, d.armed = "Sailing", 20, true
		d.x, d.z, d.speed = 30, 34, 5
		local ok, _, dock = Raft.leave(d, 20, 1)
		assert(ok and dock == 2, "docked at dock 2")
		equal(d.status, "Docked"); near(d.x, 30); near(d.z, 38)
		-- a drifting raft that stops near a dock waits there
		local a = Raft.new(docks(), 1)
		a.status, a.adriftAt = "Adrift", 0
		a.x, a.z, a.yaw, a.speed = 30, 33, math.pi, 1
		local docked
		for i = 1, 60 do
			for _, e in ipairs(Raft.step(a, 1 / 30, i / 30, nil, false, area)) do if e.kind == "Docked" then docked = e end end
		end
		assert(docked and docked.dock == 2 and a.status == "Docked", "a stopped drifting raft docks nearby")
		-- leaving while boarding keeps it docked; only the rider may leave
		local b = Raft.new(docks(), 1)
		Raft.board(b, 4, 1, true, 0)
		local no, why = Raft.leave(b, 5, 0)
		assert(not no and why == "NotRider", "someone else cannot make the rider leave")
		assert(Raft.leave(b, 4, 0), "the rider leaves")
		equal(b.status, "Docked", "still docked")
	end)

	case("RF14: the seat's input is clamped; junk is no input", function()
		local th, st = Raft.input(5, -7)
		equal(th, 1, "throttle clamped"); equal(st, -1, "steer clamped")
		th, st = Raft.input(0 / 0, math.huge)
		equal(th, 0, "NaN throttle"); equal(st, 0, "huge steer")
		th, st = Raft.input("1", nil)
		equal(th, 0); equal(st, 0)
		local s, t = launched(2)
		drive(s, t, 1, { throttle = 0 / 0, steer = 0 / 0 })
		near(s.speed, 0, "junk does not move it")
		assert(s.x == s.x and s.z == s.z and s.yaw == s.yaw, "no NaN in the state")
	end)

	-- V5-D5: a quarter faster, reverse by the same share. V5-D3: the area is the layout's, so it follows the wider river
	-- and the bigger lake: both lake discs' centres and every 24-wide river point float a hull, and the open water
	-- between the two dock tips is sailable in a straight line (the docks face each other across the lake).
	case("RF15: SPEED 20 and REVERSE 7.5; the real area follows the v5 lake and river", function()
		equal(Raft.SPEED, 20, "SPEED (V5-D5)")
		near(Raft.REVERSE, 7.5, "REVERSE (V5-D5)")
		near(Raft.REVERSE / Raft.SPEED, 6 / 16, "reverse keeps its share of SPEED")
		local realArea = Raft.area(V3, Layout.CENTRE)
		local C = Layout.CENTRE
		for i, disc in ipairs(V3.LAKE) do
			assert(realArea.inside(C.x + disc.x, C.z + disc.z, Raft.HULL), "lake disc " .. i .. "'s centre is not open water")
		end
		local wide = 0
		for i, p in ipairs(V3.RIVER) do
			if p[3] >= 24 and Layout.depth(p[1], p[2]) > p[3] then
				wide += 1
				if not V3.nearBridge(p[1], p[2], Raft.HULL) then
					assert(realArea.inside(C.x + p[1], C.z + p[2], Raft.HULL), "river point " .. i .. " is not open water")
				end
			end
		end
		assert(wide >= 6, "the river is 24 wide on its open legs: " .. wide)
		local real = Raft.docksFrom(V3, C)
		for s = 1, 19 do
			local x = real[1].x + (real[2].x - real[1].x) * s / 20
			local z = real[1].z + (real[2].z - real[1].z) * s / 20
			local nearTip = flat(x, z, real[1].x, real[1].z) <= Raft.ARM_STUDS or flat(x, z, real[2].x, real[2].z) <= Raft.ARM_STUDS
			assert(realArea.inside(x, z, nearTip and 0 or Raft.HULL), ("the crossing is blocked at %.1f, %.1f"):format(x, z))
		end
	end)

	return result
end

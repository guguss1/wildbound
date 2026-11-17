-- Invoke with require(freshTestClone)(require(freshCandyCurrentClone), require(freshCandyRaftClone),
--   require(freshCandyWadeClone), require(freshCandyV3LayoutClone), require(freshCandyLayoutClone),
--   { raftService = <WildboundCandyRaftService Source>, wadeService = <WildboundCandyWadeService Source>,
--   client = <WildboundCandyCurrentClient Source> }).
-- Caramelo v6, proposal 3: the river current (odd/tasks/wildbound-caramelo-v2.md V6-D3; docs/design/
-- wildbound-caramelo-v3-plan.md V6-D30 on). The flow field on the real layout (downstream along every river leg at 4
-- studs/s, 1.5 in the lake, 0 on dry ground, no jump in direction), the raft with the real area and the current
-- (faster downstream than upstream over the same distance, never out of the chocolate or under a bridge, a docked raft
-- stays put, docking at both docks, an abandoned raft drifts and respawns at home), the wader's push and its removal
-- rules (pure parts), and source pins of the raft service, the wade service and the client. Changes nothing.
return function(Current, Raft, Wade, V3, Layout, sources)
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
	local raftService = type(sources) == "table" and sources.raftService or ""
	local wadeService = type(sources) == "table" and sources.wadeService or ""
	local client = type(sources) == "table" and sources.client or ""

	local C = Layout.CENTRE
	local function flat(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
	local function speedOf(vx, vz) return math.sqrt(vx * vx + vz * vz) end
	local function lakeDistance(x, z)
		local best = math.huge
		for _, disc in ipairs(V3.LAKE) do best = math.min(best, flat(x, z, disc.x, disc.z) - disc.r) end
		return best
	end
	local function legDirection(i)
		local a, b = V3.RIVER[i], V3.RIVER[i + 1]
		local length = flat(a[1], a[2], b[1], b[2])
		return (b[1] - a[1]) / length, (b[2] - a[2]) / length, length
	end
	local function turn(ax, az, bx, bz) -- the angle between two non-zero vectors, degrees
		local cosine = (ax * bx + az * bz) / (speedOf(ax, az) * speedOf(bx, bz))
		return math.deg(math.acos(math.clamp(cosine, -1, 1)))
	end
	local area = Raft.area(V3, C, Current.flow)
	local still = Raft.area(V3, C)
	local docks = Raft.docksFrom(V3, C)
	-- A sailing raft with rider 1 at plot (x, z), looking along (ux, uz), at rest.
	local function sailing(x, z, ux, uz)
		local s = Raft.new(docks, V3.RAFT.homeDock)
		s.status, s.rider, s.armed = "Sailing", 1, true
		s.x, s.z, s.yaw, s.speed = C.x + x, C.z + z, math.atan2(-ux, -uz), 0
		return s
	end
	local function afloat(s, label)
		assert(area.inside(s.x, s.z, 0), (label or "") .. " left the chocolate at " .. s.x .. ", " .. s.z)
		assert(not V3.nearBridge(s.x - C.x, s.z - C.z, 0), (label or "") .. " under a bridge at " .. s.x .. ", " .. s.z)
	end

	case("CU1: the speeds, the attribute and junk", function()
		equal(Current.RIVER_SPEED, 4, "RIVER_SPEED (V6-D3)")
		near(Current.LAKE_SPEED, 1.5, "LAKE_SPEED (V6-D3)")
		near(Current.WADE_SPEED, 1.5, "WADE_SPEED (V6-D3)")
		equal(Current.PUSH_ATTRIBUTE, "WildboundCandyCurrent", "the push attribute")
		local vx, vz = Current.flow(nil, 0, 0)
		equal(vx, 0); equal(vz, 0, "no layout, no flow")
		vx, vz = Current.flow(V3, 0 / 0, 0)
		equal(vx, 0); equal(vz, 0, "NaN, no flow")
		vx, vz = Current.flow(V3, math.huge, 0)
		equal(vx, 0); equal(vz, 0, "huge, no flow")
		assert(Raft.CURRENT_MAX >= Current.RIVER_SPEED, "the raft's cap lets the river's current through")
	end)

	case("CU2: every river leg away from the lake flows downstream at 4", function()
		local checked = 0
		for i = 1, #V3.RIVER - 1 do
			local a, b = V3.RIVER[i], V3.RIVER[i + 1]
			local mx, mz = (a[1] + b[1]) / 2, (a[2] + b[2]) / 2
			if lakeDistance(mx, mz) >= 0 and V3.liquidDistance(mx, mz) <= -Current.EDGE then
				checked += 1
				local vx, vz = Current.flow(V3, mx, mz)
				near(speedOf(vx, vz), Current.RIVER_SPEED, "leg " .. i .. "'s speed", 1e-6)
				local ux, uz = legDirection(i)
				assert((vx * ux + vz * uz) / speedOf(vx, vz) >= 0.95, "leg " .. i .. " does not flow downstream")
			end
		end
		assert(checked >= 15, "most legs are open river: " .. checked)
		-- from the waterfall (north) to the south edge
		local first = V3.RIVER[1]
		local _, vz = Current.flow(V3, first[1], first[2])
		assert(vz < 0, "the waterfall's outlet flows south")
	end)

	case("CU3: the lake flows at 1.5, also at both dock tips; dry ground is still", function()
		for i, disc in ipairs(V3.LAKE) do
			local vx, vz = Current.flow(V3, disc.x, disc.z)
			near(speedOf(vx, vz), Current.LAKE_SPEED, "lake disc " .. i .. "'s centre", 1e-6)
			assert(vz < 0, "the lake drains south towards its outlet")
		end
		for _, d in ipairs(V3.DOCKS) do
			local vx, vz = Current.flow(V3, d.tipX, d.tipZ)
			near(speedOf(vx, vz), Current.LAKE_SPEED, "dock " .. d.id .. "'s tip", 1e-6)
			assert(speedOf(vx, vz) <= Raft.DOCK_SPEED, "a raft can hold against the current at a dock")
		end
		for _, p in ipairs({ { -150, 0 }, { 150, 100 }, { 100, -50 }, { -100, -50 }, { 60, 150 } }) do
			assert(V3.liquidDistance(p[1], p[2]) > 0, "a dry test point")
			local vx, vz = Current.flow(V3, p[1], p[2])
			equal(vx, 0, "dry x"); equal(vz, 0, "dry z")
		end
		-- the bank: 0 at the edge, full EDGE studs inside
		local a, b = V3.RIVER[6], V3.RIVER[7]
		local ux, uz = legDirection(6)
		local mx, mz = (a[1] + b[1]) / 2, (a[2] + b[2]) / 2
		local half = math.max(a[3], b[3]) / 2
		near(Current.speedAt(V3, mx - uz * (half - 0.01), mz + ux * (half - 0.01)), 0, "at the bank", 0.05)
		near(Current.speedAt(V3, mx - uz * (half - Current.EDGE), mz + ux * (half - Current.EDGE)), Current.RIVER_SPEED,
			"EDGE studs inside", 1e-6)
	end)

	case("CU4: the field is smooth: no jump in direction along the river or across the chocolate", function()
		local samples = V3.riverSamples(1)
		local px, pz = nil, nil
		for _, p in ipairs(samples) do
			local vx, vz = Current.flow(V3, p.x, p.z)
			if speedOf(vx, vz) > 0 then
				if px then assert(turn(px, pz, vx, vz) <= 15, ("the direction jumps at %.1f, %.1f"):format(p.x, p.z)) end
				px, pz = vx, vz
			else
				px, pz = nil, nil
			end
		end
		local checked = 0
		for x = -40, 60, 4 do
			for z = -210, 165, 4 do
				if V3.liquidDistance(x, z) <= -1 and V3.liquidDistance(x + 1, z) <= -1 and V3.liquidDistance(x, z + 1) <= -1 then
					local ax, az = Current.flow(V3, x, z)
					for _, q in ipairs({ { x + 1, z }, { x, z + 1 } }) do
						local bx, bz = Current.flow(V3, q[1], q[2])
						assert(turn(ax, az, bx, bz) <= 15, ("the direction jumps at %d, %d"):format(x, z))
						checked += 1
					end
					assert(speedOf(ax, az) <= Current.RIVER_SPEED + 1e-9, "never faster than the river")
				end
			end
		end
		assert(checked > 200, "the grid reached the chocolate: " .. checked)
	end)

	-- V6-D3: the same distance along a straight leg, full throttle from rest: downstream is faster than with still
	-- chocolate, upstream slower. Legs 6 (24 wide, north of the junction) and 18 (the narrow leg the raft reaches from
	-- the lake), 15 % to 85 % of each.
	case("CU5: the raft goes downstream faster than upstream over the same distance", function()
		local function run(withArea, ax, az, bx, bz)
			local ux, uz = bx - ax, bz - az
			local length = math.sqrt(ux * ux + uz * uz)
			ux, uz = ux / length, uz / length
			local s = sailing(ax, az, ux, uz)
			local sx, sz = s.x, s.z
			local t = 0
			while t < 20 do
				t += 1 / 30
				Raft.step(s, 1 / 30, t, { throttle = 1, steer = 0 }, true, withArea)
				afloat(s, "the run")
				if (s.x - sx) * ux + (s.z - sz) * uz >= length then return t end
			end
			return math.huge
		end
		for _, i in ipairs({ 6, 18 }) do
			local a, b = V3.RIVER[i], V3.RIVER[i + 1]
			local ax, az = a[1] + (b[1] - a[1]) * 0.15, a[2] + (b[2] - a[2]) * 0.15
			local bx, bz = a[1] + (b[1] - a[1]) * 0.85, a[2] + (b[2] - a[2]) * 0.85
			local down = run(area, ax, az, bx, bz)
			local flatWater = run(still, ax, az, bx, bz)
			local up = run(area, bx, bz, ax, az)
			assert(down < flatWater and flatWater < up, ("leg %d: down %.2f s, still %.2f s, up %.2f s"):format(i, down, flatWater, up))
			assert(up - down >= 0.8, ("leg %d: the current makes a difference: %.2f s"):format(i, up - down))
		end
	end)

	case("CU6: a docked, boarding or called raft stays put at its dock", function()
		for home = 1, 2 do
			local s = Raft.new(docks, home)
			for k = 1, 300 do Raft.step(s, 1 / 30, k / 30, nil, false, area) end
			equal(s.status, "Docked", "still docked")
			near(s.x, docks[home].x, "dock " .. home .. " x"); near(s.z, docks[home].z, "dock " .. home .. " z")
		end
		local b = Raft.new(docks, 1)
		assert(Raft.board(b, 5, 1, true, 0), "boards")
		for k = 1, math.floor(Raft.DEPART_SECONDS * 30) - 2 do Raft.step(b, 1 / 30, k / 30, nil, true, area) end
		equal(b.status, "Boarding")
		near(b.x, docks[1].x, "boarding stays at the tip"); near(b.z, docks[1].z)
		local c = Raft.new(docks, 1)
		assert(Raft.call(c, 2, 0), "called")
		for k = 1, math.ceil((Raft.CALL_SECONDS + 0.5) * 30) do Raft.step(c, 1 / 30, k / 30, nil, false, area) end
		equal(c.status, "Docked"); equal(c.dock, 2)
		near(c.x, docks[2].x, "laid at the tip"); near(c.z, docks[2].z)
	end)

	-- Docking still works against the lake's 1.5: the rider aims the bow at the tip at 15 % throttle (3 studs/s through
	-- the water, under DOCK_SPEED) from 10 studs out towards the other dock.
	case("CU7: docking at both docks with the current", function()
		for i = 1, 2 do
			local tip, other = docks[i], docks[3 - i]
			local dx, dz = other.x - tip.x, other.z - tip.z
			local length = math.sqrt(dx * dx + dz * dz)
			local s = sailing(tip.x - C.x + dx / length * 10, tip.z - C.z + dz / length * 10, -dx / length, -dz / length)
			s.rider = 40 + i
			local t, arrived = 0, nil
			while t < 15 and not arrived do
				t += 1 / 30
				local want = math.atan2(-(tip.x - s.x), -(tip.z - s.z))
				local diff = (want - s.yaw + math.pi) % (2 * math.pi) - math.pi
				local steer = math.clamp(-diff * 3, -1, 1)
				for _, e in ipairs(Raft.step(s, 1 / 30, t, { throttle = 0.15, steer = steer }, true, area)) do
					if e.kind == "Arrived" then arrived = e end
				end
				afloat(s, "the approach")
			end
			assert(arrived and arrived.dock == i and arrived.rider == 40 + i, "docked at dock " .. i)
			equal(s.status, "Docked"); near(s.x, tip.x); near(s.z, tip.z)
		end
	end)

	case("CU8: an abandoned raft drifts downstream, never out or under a bridge, and respawns at home", function()
		local a, b = V3.RIVER[18], V3.RIVER[19]
		local ux, uz = legDirection(18)
		local s = sailing((a[1] + b[1]) / 2, (a[2] + b[2]) / 2, ux, uz)
		s.rider = nil
		s.status, s.adriftAt = "Adrift", 0
		local sx, sz = s.x, s.z
		local t, respawned = 0, nil
		while t < 1 do
			t += 1 / 30
			Raft.step(s, 1 / 30, t, nil, false, area)
			afloat(s, "adrift")
		end
		assert((s.x - sx) * ux + (s.z - sz) * uz >= 2, "it drifted downstream")
		while t < Raft.RESPAWN_SECONDS + 1 and not respawned do
			t += 1 / 30
			for _, e in ipairs(Raft.step(s, 1 / 30, t, nil, false, area)) do if e.kind == "Respawn" then respawned = e end end
			if not respawned then afloat(s, "adrift") end
		end
		assert(respawned and respawned.dock == V3.RAFT.homeDock, "respawned at the home dock")
		equal(s.status, "Docked")
		near(s.x, docks[V3.RAFT.homeDock].x); near(s.z, docks[V3.RAFT.homeDock].z)
		-- a ridden raft left to the current upstream of the Top bridge and in the lake by the Bottom bridge: the bridges
		-- and the banks still stop it
		for _, p in ipairs({ { -10, 146 }, { 20, -110 }, { -5, -125 } }) do
			local r = sailing(p[1], p[2], 0, -1)
			assert(area.inside(r.x, r.z, Raft.HULL), "a sailable start")
			for k = 1, 20 * 30 do
				Raft.step(r, 1 / 30, k / 30, nil, true, area)
				afloat(r, ("from %d, %d"):format(p[1], p[2]))
			end
		end
	end)

	case("CU9: the wader's push: downstream, at most 1.5, rounded, and only while wading", function()
		local a, b = V3.RIVER[6], V3.RIVER[7]
		local ux, uz = legDirection(6)
		local px, pz = Current.push(V3, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2)
		near(speedOf(px, pz), Current.WADE_SPEED, "1.5 on a river leg", 1e-6)
		assert((px * ux + pz * uz) / speedOf(px, pz) >= 0.95, "downstream")
		px, pz = Current.push(V3, V3.LAKE[1].x, V3.LAKE[1].z)
		near(speedOf(px, pz), Current.WADE_SPEED, "1.5 in the lake", 1e-6)
		px, pz = Current.push(V3, -150, 0)
		equal(px, 0); equal(pz, 0, "dry ground")
		local v = Current.pushVector(true, 1.5, 0)
		assert(typeof(v) == "Vector3", "a Vector3")
		near(v.X, 1.5); near(v.Y, 0); near(v.Z, 0)
		v = Current.pushVector(true, 10, 0)
		near(v.Magnitude, Current.WADE_SPEED, "capped", 1e-6)
		v = Current.pushVector(true, 0.123, -1.234)
		near(v.X / Current.PUSH_STEP, math.floor(v.X / Current.PUSH_STEP + 0.5), "rounded x", 1e-6)
		near(v.Z / Current.PUSH_STEP, math.floor(v.Z / Current.PUSH_STEP + 0.5), "rounded z", 1e-6)
		equal(Current.pushVector(false, 1.5, 0), nil, "not wading: no push")
		equal(Current.pushVector(nil, 1.5, 0), nil, "unknown: no push")
		equal(Current.pushVector(true, 0.01, 0), nil, "too weak")
		equal(Current.pushVector(true, 0 / 0, 0), nil, "junk")
		-- the removal rules go through WildboundCandyWade.wading: out of the chocolate, dead, seated (the raft)
		local base = { liquid = -5, feetY = 0.5, surface = 4, airborne = false, seated = false, alive = true }
		local function with(changes)
			local info = table.clone(base)
			for k, value in pairs(changes) do info[k] = value end
			return info
		end
		assert(Current.pushVector(Wade.wading(false, base), 1.5, 0), "a wader is pushed")
		equal(Current.pushVector(Wade.wading(true, with({ liquid = 0.5 })), 1.5, 0), nil, "left the chocolate")
		equal(Current.pushVector(Wade.wading(true, with({ alive = false })), 1.5, 0), nil, "dead")
		equal(Current.pushVector(Wade.wading(true, with({ seated = true })), 1.5, 0), nil, "seated in the raft")
		equal(Current.pushVector(Wade.wading(true, with({ feetY = 4.5 })), 1.5, 0), nil, "on a deck over the surface")
		-- the client applies only a sane push to a live, unseated character
		equal(Current.applies(Vector3.new(1.5, 0, 0), true, false), true, "applied")
		equal(Current.applies(Vector3.new(1.5, 0, 0), true, true), false, "seated: never twice")
		equal(Current.applies(Vector3.new(1.5, 0, 0), false, false), false, "dead")
		equal(Current.applies(nil, true, false), false, "no push")
		equal(Current.applies(Vector3.new(9, 0, 0), true, false), false, "too strong")
		equal(Current.applies("1.5", true, false), false, "junk")
		-- the probe gives the root's plot point
		local info = Wade.probe(V3, C, Layout.FLOOR_TOP, Vector3.new(C.x + 5, 3, C.z + 82), 1, 2, false)
		near(info.x, 5, "plot x"); near(info.z, 82, "plot z")
	end)

	case("CU10: raft service wiring: the area carries the current", function()
		has(raftService, 'require(ReplicatedStorage:WaitForChild("WildboundCandyCurrent"))', "the current module")
		has(raftService, "Raft.area(V3, Layout.CENTRE, Current.flow)", "the raft's area flows")
		has(raftService, "Raft.step(state, dt, t, input, seated, area)", "the rules step with that area")
		has(raftService, "if dirty or Raft.moving(state) then place(t) end", "a docked raft is still not moved")
	end)

	case("CU11: wade service and client wiring: the server decides the push, the client only applies it", function()
		has(wadeService, 'require(ReplicatedStorage:WaitForChild("WildboundCandyCurrent"))', "the current module")
		has(wadeService, "if on then push = Current.pushVector(true, Current.push(V3, info.x, info.z)) end", "only while wading")
		has(wadeService, "setPush(player, push)", "set or cleared every probe")
		has(wadeService, "player:SetAttribute(Current.PUSH_ATTRIBUTE, push)", "the server-set attribute")
		has(wadeService, "player:SetAttribute(Current.PUSH_ATTRIBUTE, nil)", "a new character starts unpushed")
		has(wadeService, "Players:GetPlayers()", "players only")
		hasNot(wadeService, "OnServerEvent", "no client says anything")
		hasNot(wadeService, "WalkSpeed =", "applyCarry is still the one WalkSpeed writer")
		hasNot(wadeService, "LinearVelocity", "no constraint on the character")
		has(client, "Players.LocalPlayer", "its own character only")
		has(client, "player:GetAttribute(Current.PUSH_ATTRIBUTE)", "reads the server's push")
		has(client, "Current.applies(push, humanoid.Health > 0, humanoid.SeatPart ~= nil)", "alive and not seated")
		has(client, "root.CFrame += push * math.min(dt, MAX_DT)", "nudges its own root")
		hasNot(client, "FireServer", "sends nothing")
		hasNot(client, "InvokeServer", "asks nothing")
		for _, source in ipairs({ wadeService, client }) do
			for _, creature in ipairs({ "WildboundBeasts", "Flyers", "Duquesa", "CollectionService" }) do
				hasNot(source, creature, "the creatures are never pushed")
			end
		end
	end)

	return result
end

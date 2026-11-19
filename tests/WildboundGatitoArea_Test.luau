-- Invoke with require(freshTestClone)(require(freshGatitoAreaClone)).
-- Pueblo Gatito's place in the world (docs/design/wildbound-pueblo-gatito-move-plan.md PGM-D1; owner request 2026-11-18:
-- "Sí, movelo"): one park frame, the big4 south arm, exact world numbers, the old (V1) frame for the move.
-- Grown to 600 x 1200 (docs/design/wildbound-pueblo-gatito-long-plan.md GL-D1; owner request 2026-11-19: "hace el mapa
-- bastante mas largo"): GROWTH 600 along local +x, the floor 520 x 1120, the arm to z 1537 (GL-1).
return function(Area)
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

	case("GA1: the frame: south arm, origin (282, 600), yaw -90, a 520 x 1120 floor at the floor's top", function()
		assert(table.isfrozen(Area) and table.isfrozen(Area.ORIGIN) and table.isfrozen(Area.ARM), "frozen")
		-- Deliberately changed (GL-D1): the park grew 600 along local +x, so VERSION 3 (was 2), the arm ends at z 1537 (was
		-- 937), rect() at z 1460 (was 860) and rect(16) at z 1476 (was 876); the case name says 520 x 1120 (was a 520 square)
		equal(Area.VERSION, 3); equal(Area.ROOT_NAME, "PuebloGatito_v1")
		equal(Area.HALF, 260); near(Area.FLOOR_TOP, 0.5); equal(Area.YAW, -90)
		equal(Area.ORIGIN.x, 282); equal(Area.ORIGIN.z, 600)
		local A = Area.ARM
		equal(A.minX, -3); equal(A.maxX, 597); equal(A.minZ, 337); equal(A.maxZ, 1537)
		local r = Area.rect()
		equal(r.minX, 22, "floor min x"); equal(r.maxX, 542, "floor max x"); equal(r.minZ, 340, "floor min z"); equal(r.maxZ, 1460, "floor max z")
		assert(r.minX >= A.minX and r.maxX <= A.maxX and r.minZ >= A.minZ and r.maxZ <= A.maxZ, "the floor lies in the arm")
		local g = Area.rect(16)
		equal(g.minX, 6); equal(g.maxZ, 1476)
		-- the hub's safe disc (282, -3) r 90 and the Caramelo plot (x 412..932, z -263..257) are far from the floor
		assert(r.minZ - (-3) > 90 + 200, "far from the hub")
		assert(r.minZ > 257, "south of the Caramelo plot")
	end)

	case("GA2: world and localOf: local +x runs south from the gate, local +z west; exact numbers", function()
		local x, z = Area.world(0, 0)
		equal(x, 282); equal(z, 600)
		x, z = Area.world(-254, 0) -- the gate arch
		equal(x, 282, "arch x"); equal(z, 346, "arch z")
		assert(z - 324.5 <= 25 and z > 324.5, "the arch is just south of the big4 road's end (282, 324.5)")
		x, z = Area.world(100, 0)
		equal(x, 282); equal(z, 700, "+x is south")
		x, z = Area.world(0, 100)
		equal(x, 182, "+z is west"); equal(z, 600)
		for _, p in ipairs({ { -170, -55 }, { 150, 120 }, { -260, 260 }, { 33.5, -7.25 } }) do
			local wx, wz = Area.world(p[1], p[2])
			local lx, lz = Area.localOf(wx, wz)
			equal(lx, p[1], "round trip x"); equal(lz, p[2], "round trip z")
		end
		equal(Area.worldYaw(90), 0, "a local yaw of 90 is world 0"); equal(Area.worldYaw(0), -90)
	end)

	case("GA3: frame and pivot agree with world(); a local yaw turns with the frame", function()
		for _, p in ipairs({ { -170, -55 }, { 150, 120 }, { 0, 0 } }) do
			local cf = Area.pivot(p[1], p[2], 0)
			local wx, wz = Area.world(p[1], p[2])
			near(cf.X, wx, "pivot x", 1e-4); near(cf.Z, wz, "pivot z", 1e-4); near(cf.Y, Area.FLOOR_TOP, "on the floor", 1e-6)
		end
		-- an item turned by a local yaw of 90 faces local -x (toward the gate), which is world -z (toward the hub)
		local look = Area.pivot(0, 0, 90).LookVector
		near(look.Z, -1, "front toward the hub", 1e-6)
	end)

	case("GA4: V1, the frame the park was built in (east of the cloud wall), maps onto the arm", function()
		equal(Area.V1.x, 1208); equal(Area.V1.z, -3); equal(Area.V1.yaw, 0)
		local lx, lz = Area.localOfV1(1038, -58) -- nest K1 (K-D8)
		equal(lx, -170); equal(lz, -55)
		local x, z = Area.fromV1(1038, -58)
		equal(x, 337); equal(z, 430)
		x, z = Area.fromV1(954, -3) -- the arch
		equal(x, 282); equal(z, 346)
		x, z = Area.fromV1(1208, -3)
		equal(x, 282); equal(z, 600)
	end)

	case("GL-1: the growth: GROWTH 600, FAR = HALF + GROWTH = 860; rect() from the gate side to the far end; the floor's margins in the arm", function()
		equal(Area.GROWTH, 600, "GROWTH"); equal(Area.FAR, 860, "FAR"); equal(Area.FAR, Area.HALF + Area.GROWTH, "FAR = HALF + GROWTH")
		local r = Area.rect()
		local ax, az = Area.world(-260, -260)
		local bx, bz = Area.world(860, 260)
		equal(r.minX, math.min(ax, bx), "corner min x"); equal(r.maxX, math.max(ax, bx), "corner max x")
		equal(r.minZ, math.min(az, bz), "corner min z"); equal(r.maxZ, math.max(az, bz), "corner max z")
		equal(r.maxX - r.minX, 520, "520 across"); equal(r.maxZ - r.minZ, 1120, "1120 long")
		local A = Area.ARM
		equal(A.maxX - A.minX, 600, "the arm is 600 across"); equal(A.maxZ - A.minZ, 1200, "the arm is 1200 long")
		equal(r.minZ - A.minZ, 3, "the gate-side margin"); equal(r.minX - A.minX, 25, "the west margin")
		equal(A.maxX - r.maxX, 55, "the east margin"); equal(A.maxZ - r.maxZ, 77, "the far-end margin")
		local x, z = Area.world(860, 260)
		equal(x, 22, "the far corner x"); equal(z, 1460, "the far corner z")
		x, z = Area.world(937, -315)
		equal(x, 597, "the arm's far corner x"); equal(z, 1537, "the arm's far corner z")
		for _, p in ipairs({ { 860, 260 }, { 937, -315 } }) do
			local wx, wz = Area.world(p[1], p[2])
			local lx, lz = Area.localOf(wx, wz)
			equal(lx, p[1], "round trip x"); equal(lz, p[2], "round trip z")
		end
	end)

	return result
end

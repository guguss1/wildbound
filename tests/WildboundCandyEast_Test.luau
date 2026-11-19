-- Invoke with require(freshTestClone)(require(freshCandyEastClone), require(freshCandyLayoutClone),
-- require(freshCandySmartsClone), require(freshCandyV3LayoutClone), { client = WildboundCandyCloudWallClient.Source,
-- beasts = WildboundBeasts.Source, duquesa = WildboundCandyDuquesaService.Source, migrate = WildboundCaramelV8Migrate.Source }).
-- Caramelo v8 (owner request 2026-11-17: "another space of the same size, separated by clouds: an invisible wall with a
-- cloud texture that you can see through"; docs/design/wildbound-caramelo-v8-plan.md V8-D2 to V8-D4): Caramelo Este's
-- plan numbers from the layout, its floor and cloud wall built on a detached folder (twice: the second build changes
-- nothing), the creature clamp against the built wall, the big4 annex's moves and floor slabs, and source pins of the
-- cloud client, the two server clamps and the v8 migration tool. Changes nothing outside its own detached folders.
-- Pueblo Gatito (docs/design/wildbound-kitten-park-plan.md K-D1, K-D15): the gate splits the Collider into Collider and
-- ColliderSouth (14-stud gap at z -10..4) and the floor turns grass green.
-- PGM-D5 (docs/design/wildbound-pueblo-gatito-move-plan.md; owner request 2026-11-18, "Sí, movelo"): the park moved to
-- the big4 south arm, so the wall closes again: one whole Collider, no ColliderSouth, the floor under the band only, pink.
-- Caramelo v9 (docs/design/wildbound-caramelo-v9-plan.md CL-D1, CL-D13): the plot runs to Layout.EAST (world x 1532), the
-- band and the wall follow it (x 1532..1548), the floor is the band and the 64-stud tail to the arm's end (x 1612), the
-- caps end at the arm, and five new parts: SideWallNorth, SideWallSouth, EndWall, MouthGuard and MouthSheet (the last two
-- only when the river ends on the east edge); stripPlan resizes the big4 annex strips to the arm. The V3 layout may be
-- passed after Smarts: require(freshTestClone)(East, Layout, Smarts, require(freshCandyV3LayoutClone), sources); without
-- it a stand-in v9 river end (local (860, 195), 120 wide) is used, so the plan numbers stay pinned.
return function(East, Layout, Smarts, fourth, fifth)
	-- CL-D13: East.plan(L, V3) reads V3's last river point; the old call shape (sources fourth) still works
	local V3, sources
	if type(fourth) == "table" and type(fourth.RIVER) == "table" then
		V3, sources = fourth, fifth
	else
		sources = fourth
	end
	local V3Mouth = V3 or {
		RIVER = { { 470, 175, 60 }, { 860, 195, 120 } },
		LIQUID = { depth = 3.5, color = { 92, 52, 34 }, transparency = 0.08 },
	}
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
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-3),
			(label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function has(source, needle, label)
		assert(type(source) == "string" and string.find(source, needle, 1, true), (label or "missing") .. ": " .. needle)
	end
	local function hasNot(source, needle, label)
		assert(type(source) == "string" and not string.find(source, needle, 1, true), (label or "present") .. ": " .. needle)
	end
	local function rectIs(r, minX, maxX, minZ, maxZ, label)
		near(r.minX, minX, label .. " minX"); near(r.maxX, maxX, label .. " maxX")
		near(r.minZ, minZ, label .. " minZ"); near(r.maxZ, maxZ, label .. " maxZ")
	end
	assert(type(East) == "table" and type(Layout) == "table" and type(Smarts) == "table", "pass CandyEast, Layout and Smarts")
	sources = type(sources) == "table" and sources or {}
	local CollectionService = game:GetService("CollectionService")

	case("V8-D2: the plan's numbers come from the layout: the plot, the 16-stud band, the second space, the floor", function()
		local P = East.plan(Layout, V3Mouth)
		local cx, cz, half = Layout.CENTRE.x, Layout.CENTRE.z, Layout.HALF
		-- Deliberately changed (CL-D1): the plot runs from CENTRE.x - HALF to CENTRE.x + EAST (was CENTRE.x +- HALF)
		rectIs(P.plot, cx - half, cx + Layout.EAST, cz - half, cz + half, "plot from the layout")
		-- CL-D1: the v9 layout: CENTRE (672, -3), HALF 260, EAST 860 (was x 412..932)
		equal(Layout.EAST, 860, "Layout.EAST")
		rectIs(P.plot, 412, 1532, -263, 257, "plot")
		-- CL-D13: the band follows the plot's east edge (was x 932..948)
		rectIs(P.band, 1532, 1548, -271, 265, "band: 16 wide, the plot's length plus 8 at each end")
		-- CL-D13: the second space stays a legacy formula (2 * HALF east of the band) for annexMove, annexGround, the old
		-- tools and KittenPark's archive step (was x 948..1468, as big as the v8 plot)
		rectIs(P.space, 1548, 2068, -263, 257, "space: the legacy formula")
		near(P.space.maxX - P.space.minX, 2 * half, "legacy width 2 * HALF")
		near(P.space.maxZ - P.space.minZ, P.plot.maxZ - P.plot.minZ, "same length")
		near(P.centre.x, 1808, "space centre x"); near(P.centre.z, -3, "space centre z") -- CL-D13 (was 1208)
		-- Deliberately changed (CL-D13): the floor is the band and the 64-stud tail to the arm's end, the plot's z (was the
		-- band only, x 932..948, PGM-D5)
		rectIs(P.ground, 1532, 1612, -263, 257, "the floor under the band and the tail")
		equal(P.gate, nil, "no gate (PGM-D5)")
		-- CL-D13: the wall follows the band (was x 940)
		near(P.wallX, 1540, "the wall on the band's centre line"); near(East.wallX(Layout), 1540, "wallX")
		-- CL-D13: the legacy shift is space.minX - plot.minX (was 536)
		near(P.shift, 1136, "a plot point lands at the same spot of the legacy space"); near(P.floorTop, Layout.FLOOR_TOP, "floor top")
		equal(P.margin, East.WALL_MARGIN, "margin"); equal(East.WALL_MARGIN, 8, "half the band")
		equal(East.BAND, 16); equal(East.COLLIDER_THICK, 4); equal(East.HEIGHT, 80)
		equal(East.ROOT_NAME, "Candy_Este_v1"); equal(East.FOLDER, "CloudWall")
		-- Deliberately changed (PG-D2, Pueblo Gatito is its own biome, owner request 2026-11-18 "hacelo bioma aparte"): the
		-- key mirrors the WildboundBiomes row "pueblo-gatito"; the internal tag stays CandyEast (PG-D1) (was "caramelo-este")
		-- Deliberately changed (PGM-D5, "Sí, movelo"): the wall is Caramelo's, so East.TAG is gone (the CandyEast row is
		-- the south arm's, in WildboundBiomes) and the key names the wall (was TAG "CandyEast", KEY "pueblo-gatito")
		equal(East.TAG, nil, "no tag"); equal(East.KEY, "caramelo-nube")
		local byName = {}
		for _, spec in ipairs(P.parts) do byName[spec.name] = spec end
		local floor, collider, veil = byName.Floor, byName.Collider, byName.Veil
		assert(floor and collider and veil, "Floor, Collider and Veil")
		-- Deliberately changed (CL-D13): ten parts: the five of PGM-D5 and SideWallNorth, SideWallSouth, EndWall,
		-- MouthGuard and MouthSheet (was five, PGM-D5; six, K-D1; five, V8-D3 amendment; three before that)
		equal(#P.parts, 10, "ten parts, nothing else")
		local order = { "Floor", "Collider", "Veil", "CapNorth", "CapSouth", "SideWallNorth", "SideWallSouth", "EndWall",
			"MouthGuard", "MouthSheet" }
		for i, name in ipairs(order) do equal(P.parts[i].name, name, "part " .. i) end
		equal(byName.ColliderSouth, nil, "no ColliderSouth (PGM-D5)")
		equal(floor.folder, "Ground"); equal(collider.folder, "CloudWall"); equal(veil.folder, "CloudWall")
		-- Deliberately changed (CL-D13): the floor is the band's 16 and the tail's 64 by the plot's 520, x 1532..1612 (was
		-- the band's 16 at x 940, PGM-D5)
		near(floor.size[1], 80); near(floor.size[2], 1); near(floor.size[3], 520)
		near(floor.position[1], 1572); near(floor.position[2] + floor.size[2] / 2, Layout.FLOOR_TOP, "floor top"); near(floor.position[3], -3)
		-- PGM-D5: the Collider is the band's whole length, z -271..265
		near(collider.size[1], 4); near(collider.size[2], 80); near(collider.size[3], 536, "the band's whole length")
		near(veil.size[1], 16); near(veil.size[2], 80); near(veil.size[3], 536)
		-- Deliberately changed (CL-D13): the Collider and the Veil on the v9 band's centre line, x 1540 (was 940)
		near(collider.position[1], 1540, "Collider x"); near(collider.position[3], -3, "Collider z (the band's centre)")
		near(veil.position[1], 1540, "Veil x"); near(veil.position[3], -3, "Veil z")
		for _, spec in ipairs({ collider, veil }) do
			near(spec.position[2] - spec.size[2] / 2, Layout.FLOOR_TOP, spec.name .. " stands on the floor")
		end
		-- Deliberately changed (PGM-D5): the floor is the plot's pink SmoothPlastic again; the park lays its own grass (was
		-- K-D15's grass green 140, 201, 107, Material Grass)
		equal(floor.color[1], 255); equal(floor.color[2], 177); equal(floor.color[3], 209)
		equal(floor.material, "SmoothPlastic", "floor material")
		equal(veil.color[1], 255); equal(veil.color[2], 226); equal(veil.color[3], 240)
	end)

	case("V8-D3 amendment: two end caps close the band's ends, so nobody walks round the wall", function()
		local P = East.plan(Layout, V3Mouth)
		local byName = {}
		for _, spec in ipairs(P.parts) do byName[spec.name] = spec end
		local north, south = byName.CapNorth, byName.CapSouth
		assert(north and south, "CapNorth and CapSouth")
		-- Deliberately changed (CL-D13): from the v9 Collider's west face (1538) to the arm's end (1612), no longer to the
		-- second space's far edge (was 938..1468)
		rectIs(P.caps.north, 1538, 1612, 261, 265, "north cap: inside the band's north end, to the arm's end")
		rectIs(P.caps.south, 1538, 1612, -271, -267, "south cap: inside the band's south end")
		for _, spec in ipairs({ north, south }) do
			equal(spec.folder, "CloudWall", spec.name .. " folder"); equal(spec.role, "solid", spec.name .. " role")
			equal(spec.canCollide, true, spec.name .. " collides"); equal(spec.canQuery, true, spec.name .. " query")
			equal(spec.canTouch, false, spec.name .. " touch"); equal(spec.castShadow, false, spec.name .. " shadow")
			near(spec.transparency, 1, spec.name .. " invisible")
			near(spec.size[1], 74); near(spec.size[2], 80); near(spec.size[3], 4) -- CL-D13: 1538..1612 (was 530)
			near(spec.position[2] - spec.size[2] / 2, Layout.FLOOR_TOP, spec.name .. " stands on the floor")
		end
		-- each cap meets the Collider (inside its z run, from its west face) and stays out of the plot
		for _, r in ipairs({ P.caps.north, P.caps.south }) do
			assert(r.minZ >= P.band.minZ - 1e-6 and r.maxZ <= P.band.maxZ + 1e-6, "inside the band's z run")
			near(r.minX, P.wallX - East.COLLIDER_THICK / 2, "joined to the Collider")
			assert(r.minX >= P.plot.maxX, "out of the plot")
		end
		-- the ground past the band's ends: the annex strips (CL-D13: stretched to the arm's end, x 1612, z -303..-263 and
		-- 257..297); a cap runs to the arm's end, where the EndWall closes it (was past the Baseplate's x 1024, into void)
		near(P.caps.north.maxX, P.arm.maxX, "north cap to the arm's end"); near(P.caps.south.maxX, P.arm.maxX, "south cap to the arm's end")
		assert(P.caps.north.minZ >= P.plot.maxZ and P.caps.south.maxZ <= P.plot.minZ, "off the floor's z range")
	end)

	case("E-V9-1: the v9 plan: the arm, the tail, the side and end walls, the mouth parts; ten parts", function()
		local P = East.plan(Layout, V3Mouth)
		equal(East.TAIL, 64, "East.TAIL"); equal(East.EDGE_WALL, 4, "East.EDGE_WALL")
		rectIs(P.arm, 412, 1612, -303, 297, "the big4 arm: x 412..1612, z -303..297")
		near(P.arm.maxX - P.band.maxX, East.TAIL, "64 studs of arm past the band")
		equal(#P.parts, 10, "ten parts")
		local byName = {}
		for _, spec in ipairs(P.parts) do byName[spec.name] = spec end
		local function specRect(spec)
			return { minX = spec.position[1] - spec.size[1] / 2, maxX = spec.position[1] + spec.size[1] / 2,
				minZ = spec.position[3] - spec.size[3] / 2, maxZ = spec.position[3] + spec.size[3] / 2 }
		end
		rectIs(specRect(byName.Floor), 1532, 1612, -263, 257, "Ground.Floor: the band and the tail")
		rectIs(specRect(byName.Collider), 1538, 1542, -271, 265, "Collider")
		rectIs(specRect(byName.Veil), 1532, 1548, -271, 265, "Veil")
		rectIs(specRect(byName.CapNorth), 1538, 1612, 261, 265, "CapNorth")
		rectIs(specRect(byName.CapSouth), 1538, 1612, -271, -267, "CapSouth")
		rectIs(specRect(byName.SideWallNorth), 1020, 1616, 297, 301, "SideWallNorth: along the north strip's outer side")
		rectIs(specRect(byName.SideWallSouth), 1020, 1616, -307, -303, "SideWallSouth: along the south strip's outer side")
		rectIs(specRect(byName.EndWall), 1612, 1616, -307, 301, "EndWall: across the arm's end")
		rectIs(specRect(byName.MouthGuard), 1532, 1538, 132, 252, "MouthGuard: the plot edge to the Collider, across the mouth")
		rectIs(specRect(byName.MouthSheet), 1532, 1612, 132, 252, "MouthSheet: the river flows on under the cloud")
		-- the walls: invisible, solid, 80 tall on the floor, never touched, no shadow
		for _, name in ipairs({ "SideWallNorth", "SideWallSouth", "EndWall", "MouthGuard" }) do
			local spec = byName[name]
			equal(spec.folder, "CloudWall", name .. " folder"); equal(spec.role, "solid", name .. " role")
			equal(spec.canCollide, true, name .. " collides"); equal(spec.canQuery, true, name .. " query")
			equal(spec.canTouch, false, name .. " touch"); equal(spec.castShadow, false, name .. " shadow")
			near(spec.transparency, 1, name .. " invisible")
			near(spec.size[2], East.HEIGHT, name .. " height")
			near(spec.position[2] - spec.size[2] / 2, Layout.FLOOR_TOP, name .. " stands on the floor")
		end
		-- the side walls start over the big4 Baseplate (its east edge x 1024) and the corners meet the EndWall
		assert(specRect(byName.SideWallNorth).minX <= 1024 and specRect(byName.SideWallSouth).minX <= 1024, "from the Baseplate")
		near(specRect(byName.EndWall).maxZ, specRect(byName.SideWallNorth).maxZ, "the north corner closed")
		near(specRect(byName.EndWall).minZ, specRect(byName.SideWallSouth).minZ, "the south corner closed")
		-- the sheet: decor at the river's surface, the chocolate's colour, never collides, never answers rays
		local sheet = byName.MouthSheet
		equal(sheet.folder, "CloudWall", "sheet folder"); equal(sheet.role, "decor", "sheet role")
		equal(sheet.canCollide, false, "sheet collide"); equal(sheet.canQuery, false, "sheet query"); equal(sheet.canTouch, false, "sheet touch")
		near(sheet.size[2], V3Mouth.LIQUID.depth, "as thick as the chocolate")
		near(sheet.position[2] - sheet.size[2] / 2, Layout.FLOOR_TOP, "from the floor")
		near(sheet.position[2] + sheet.size[2] / 2, Layout.FLOOR_TOP + V3Mouth.LIQUID.depth, "to the river's surface")
		for i = 1, 3 do equal(sheet.color[i], V3Mouth.LIQUID.color[i], "sheet colour " .. i) end
		near(sheet.transparency, V3Mouth.LIQUID.transparency, "sheet transparency")
		-- the mouth from the river's last point: 195 +- 60 local, world 132..252
		assert(P.mouth, "the mouth rectangle")
		rectIs(P.mouth, 1532, 1612, 132, 252, "mouth")
	end)

	case("E-V9-2: stripPlan finds the two annex strips by geometry and resizes them to the arm (0 new parts)", function()
		local slabs = {
			{ name = "Floor_Big4_2", minX = 412, maxX = 1012, minZ = -303, maxZ = -263 },
			{ name = "Floor_Big4_3", minX = 411.5, maxX = 1012.6, minZ = 257, maxZ = 297 },
			{ name = "Elsewhere", minX = 412, maxX = 812, minZ = -100, maxZ = 0 },
		}
		local before = table.clone(slabs[2])
		local s = East.stripPlan(Layout, slabs)
		equal(s.ok, true, "both strips found")
		equal(#s.resize, 2, "two strips resized"); equal(#s.missing, 0, "none missing"); equal(#s.done, 0, "none already done")
		local bySide = {}
		for _, r in ipairs(s.resize) do bySide[r.side] = r end
		equal(bySide.south.name, "Floor_Big4_2", "south strip"); equal(bySide.north.name, "Floor_Big4_3", "north strip")
		rectIs(bySide.south.rect, 412, 1612, -303, -263, "south strip to the arm")
		rectIs(bySide.north.rect, 412, 1612, 257, 297, "north strip to the arm, its z kept")
		equal(s.create, nil, "0 new parts: only resizes")
		near(slabs[2].maxX, before.maxX, "pure: the input is untouched")
		-- one strip missing: refused (ok false), the missing side named
		local one = East.stripPlan(Layout, { slabs[1], slabs[3] })
		equal(one.ok, false, "one strip only"); equal(#one.missing, 1); equal(one.missing[1], "north")
		equal(#East.stripPlan(Layout, {}).missing, 2, "no slabs: both missing")
		-- already at the arm's length (a second plan after the real run): nothing to resize, still found
		local again = East.stripPlan(Layout, {
			{ name = "Floor_Big4_2", minX = 412, maxX = 1612, minZ = -303, maxZ = -263 },
			{ name = "Floor_Big4_3", minX = 412, maxX = 1612, minZ = 257, maxZ = 297 },
		})
		equal(again.ok, true, "found at the arm's length"); equal(#again.resize, 0, "nothing to resize"); equal(#again.done, 2, "both done")
		-- a slab off the strips' geometry by more than a stud is not a strip
		local off = East.stripPlan(Layout, { { name = "Wide", minX = 412, maxX = 1012, minZ = -310, maxZ = -263 } })
		equal(off.ok, false, "not a strip"); equal(#off.missing, 2)
	end)

	case("E-V9-3: the mouth parts appear only when the river ends on the east edge, their z from its last point", function()
		local function names(P)
			local set = {}
			for _, spec in ipairs(P.parts) do set[spec.name] = spec end
			return set
		end
		local liquid = V3Mouth.LIQUID
		-- the v8 river ended on the south edge: no mouth, eight parts
		local south = East.plan(Layout, { RIVER = { { 0, 0, 24 }, { 39, -260, 24 } }, LIQUID = liquid })
		equal(#south.parts, 8, "eight parts without a mouth"); equal(south.mouth, nil, "no mouth")
		equal(names(south).MouthGuard, nil, "no MouthGuard"); equal(names(south).MouthSheet, nil, "no MouthSheet")
		-- a river ending on the east edge at local z 100, 40 wide: world z 77..117
		local other = East.plan(Layout, { RIVER = { { 470, 0, 60 }, { Layout.EAST, 100, 40 } }, LIQUID = liquid })
		equal(#other.parts, 10, "ten parts with a mouth")
		local guard = names(other).MouthGuard
		near(guard.position[3] - guard.size[3] / 2, 77, "guard from z 77"); near(guard.position[3] + guard.size[3] / 2, 117, "to z 117")
		rectIs(other.mouth, 1532, 1612, 77, 117, "the mouth follows the last point")
		-- the real layout (when passed): its last point lies on the east edge, the mouth from it
		if V3 then
			local last = V3.RIVER[#V3.RIVER]
			near(last[1], Layout.EAST, "the river ends on the east edge")
			local P = East.plan(Layout, V3)
			near(P.mouth.minZ, Layout.CENTRE.z + last[2] - last[3] / 2, "real mouth minZ")
			near(P.mouth.maxZ, Layout.CENTRE.z + last[2] + last[3] / 2, "real mouth maxZ")
		end
		-- the MouthGuard closes the gap between the plot edge and the Collider all across the mouth
		local P = East.plan(Layout, V3Mouth)
		local g = names(P).MouthGuard
		near(g.position[1] - g.size[1] / 2, P.plot.maxX, "from the plot's east edge")
		near(g.position[1] + g.size[1] / 2, P.wallX - East.COLLIDER_THICK / 2, "to the Collider's west face")
	end)

	case("V8-D3: build lays the floor and the cloud wall with the right flags; a second build changes nothing", function()
		local holder = Instance.new("Folder")
		holder.Name = "CandyEastTest"
		local other = Instance.new("Part")
		other.Name = "SomethingElse"
		other.Parent = holder
		local root, report = East.build(holder, Layout, V3Mouth)
		equal(root.Parent, holder, "under the given parent"); equal(root.Name, East.ROOT_NAME); assert(root:IsA("Model"), "a Model")
		-- Deliberately changed (CL-D13): ten parts, the five new walls and mouth pieces too (was five, PGM-D5; six, K-D1)
		equal(report.parts, 10, "ten parts")
		assert(report.created >= 13, "root, two folders and ten parts made: " .. report.created)
		local floor = root.Ground.Floor
		local collider, veil = root.CloudWall.Collider, root.CloudWall.Veil
		-- the floor; Deliberately changed (PGM-D5): the plot's pink SmoothPlastic (was K-D15's green Grass)
		equal(floor:GetAttribute("Role"), "floor"); equal(floor.Anchored, true); equal(floor.CanCollide, true)
		equal(floor.Material, Enum.Material.SmoothPlastic, "the plot's material")
		near(floor.Color.R * 255, 255, "pink R", 0.6); near(floor.Color.G * 255, 177, "pink G", 0.6); near(floor.Color.B * 255, 209, "pink B", 0.6)
		near(floor.Position.Y + floor.Size.Y / 2, Layout.FLOOR_TOP, "the plot's floor top")
		-- Deliberately changed (CL-D13): the band and the tail, x 1532..1612 (was the band only, x 932..948, PGM-D5)
		near(floor.Position.X - floor.Size.X / 2, 1532, "from the plot's east edge"); near(floor.Position.X + floor.Size.X / 2, 1612, "to the arm's end")
		-- the collider: invisible, collides, answers rays, never touched, no shadow, solid, never a pass for creatures
		equal(collider.Anchored, true, "collider anchored"); equal(collider.CanCollide, true, "collider collides")
		equal(collider.CanQuery, true, "collider blocks sight"); equal(collider.CanTouch, false, "collider touch")
		equal(collider.CastShadow, false, "collider shadow"); near(collider.Transparency, 1, "invisible")
		equal(collider:GetAttribute("Role"), "solid", "collider role")
		equal(CollectionService:HasTag(collider, "WildboundBeastPass"), false, "never a pass")
		equal(CollectionService:HasTag(root, "WildboundBeastPass"), false, "the root is no pass either")
		equal(collider:GetAttribute("WallMargin"), East.WALL_MARGIN, "the clamp margin")
		near(collider.Size.X, 4); near(collider.Size.Y, 80); near(collider.Position.X, 1540) -- CL-D13 (was 940)
		near(collider.Size.Z, 536, "PGM-D5: the band's whole length"); near(collider.Position.Z, -3, "on the band's centre")
		-- the veil: ForceField cloud pink, never collides, never answers rays, never touched: the player sees through it
		equal(veil.Material, Enum.Material.ForceField, "ForceField")
		near(veil.Color.R * 255, 255, "pink R", 0.6); near(veil.Color.G * 255, 226, "pink G", 0.6); near(veil.Color.B * 255, 240, "pink B", 0.6)
		equal(veil.CanCollide, false, "veil collide"); equal(veil.CanQuery, false, "veil query"); equal(veil.CanTouch, false, "veil touch")
		near(veil.Size.X, 16); near(veil.Size.Y, 80)
		-- Deliberately changed (PGM-D5): the root attribute Key follows East.KEY, the wall's (was "pueblo-gatito", PG-D2;
		-- "caramelo-este" before it)
		-- CL-D13: the wall's x follows the band (was 940)
		equal(root:GetAttribute("WallX"), 1540); equal(root:GetAttribute("Key"), "caramelo-nube")
		-- idempotent
		local again, second = East.build(holder, Layout, V3Mouth)
		equal(again, root, "the same root")
		equal(second.created, 0, "nothing made the second time"); equal(second.changed, 0, "nothing changed the second time")
		local count = 0
		for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") then count += 1 end end
		-- Deliberately changed (CL-D13): ten (was five, PGM-D5; six, K-D1; five before it; three before that)
		equal(count, 10, "still ten parts")
		-- Deliberately changed (PGM-D5): no ColliderSouth is built (was built with the caps' flags, K-D1)
		equal(root.CloudWall:FindFirstChild("ColliderSouth"), nil, "no ColliderSouth")
		-- CL-D13: the mouth sheet is decor: walk-through, never answers rays, never touched
		local sheet = root.CloudWall:FindFirstChild("MouthSheet")
		assert(sheet, "MouthSheet built")
		equal(sheet.CanCollide, false, "sheet collide"); equal(sheet.CanQuery, false, "sheet query"); equal(sheet.CanTouch, false, "sheet touch")
		equal(sheet:GetAttribute("Role"), "decor", "sheet role")
		for _, name in ipairs({ "CapNorth", "CapSouth", "SideWallNorth", "SideWallSouth", "EndWall", "MouthGuard" }) do
			local cap = root.CloudWall:FindFirstChild(name)
			assert(cap, name .. " built")
			equal(cap.CanCollide, true, name .. " collides"); equal(cap.CanTouch, false, name .. " touch")
			near(cap.Transparency, 1, name .. " invisible"); equal(cap:GetAttribute("Role"), "solid", name .. " role")
			equal(CollectionService:HasTag(cap, "WildboundBeastPass"), false, name .. " never a pass")
		end
		equal(holder.SomethingElse, other, "nothing else under the parent is touched")
		-- a piece pushed off its plan is set back, then nothing changes again
		veil.CanQuery = true
		collider.Position = Vector3.new(1550, 40, 0) -- CL-D13 (was 950)
		local _, fixed = East.build(holder, Layout, V3Mouth)
		assert(fixed.changed >= 2 and fixed.created == 0, "set back: " .. fixed.changed)
		equal(veil.CanQuery, false, "the veil never blocks rays"); near(collider.Position.X, 1540, "the collider back")
		local _, third = East.build(holder, Layout, V3Mouth)
		equal(third.changed, 0, "settled")
		-- never inside SistemaSonriente
		local sonriente = Instance.new("Folder")
		sonriente.Name = "SistemaSonriente"
		local inner = Instance.new("Folder")
		inner.Parent = sonriente
		equal((pcall(East.build, inner, Layout, V3Mouth)), false, "refuses SistemaSonriente")
		equal(#inner:GetChildren(), 0, "nothing laid there")
		sonriente:Destroy()
		holder:Destroy()
	end)

	case("V8-D3: creatures from the plot stop on its east edge, out of the band; the wall is read from the built map", function()
		local holder = Instance.new("Folder")
		local root = East.build(holder, Layout, V3Mouth)
		local wall = Smarts.wallOf(root)
		assert(wall, "Smarts.wallOf reads the built wall")
		near(wall.x, East.wallX(Layout), "x"); equal(wall.margin, East.WALL_MARGIN, "margin")
		equal(Smarts.WALL_MARGIN_STUDS, East.WALL_MARGIN, "one margin on both sides")
		equal(Smarts.WALL_ROOT, East.ROOT_NAME, "one root name")
		local P = East.plan(Layout, V3Mouth)
		local x, z = Smarts.outsideWall(P.plot.maxX - 20, 0, P.space.minX + 30, 17, wall)
		near(x, P.plot.maxX, "stopped on the plot's east edge"); near(z, 17, "z kept")
		x = Smarts.outsideWall(P.plot.maxX - 20, 0, P.plot.maxX - 5, 0, wall)
		near(x, P.plot.maxX - 5, "inside the plot: untouched")
		x = Smarts.outsideWall(P.centre.x, 0, P.band.minX - 30, 0, wall)
		near(x, P.space.minX, "a creature of the second space stops on its west edge")
		equal(Smarts.wallOf(holder), nil, "the parent folder is no wall root")
		holder:Destroy()
	end)

	-- Deliberately changed (PGM-D5, owner request 2026-11-18 "Sí, movelo"): the park moved to the big4 south arm, so the
	-- wall closes; K-D1's gate case is now the closed wall case (was "K-D1: the gate: a 14-stud gap in the Collider at
	-- z -10..4; both pieces at x 940"); the creature clamp (x only) is unchanged.
	-- CL-D13: the band moved with the plot's east edge, so every x below is +600 (940 -> 1540, 938..942 -> 1538..1542,
	-- 932 -> 1532, 948 -> 1548).
	case("PGM-D5: the closed wall: no gate, no gap anywhere along the band; the clamp reads x 1540", function()
		equal(East.GATE, nil, "no GATE")
		local P = East.plan(Layout, V3Mouth)
		equal(P.gate, nil, "no gate in the plan")
		local byName = {}
		for _, spec in ipairs(P.parts) do byName[spec.name] = spec end
		local whole = byName.Collider
		assert(whole, "Collider")
		equal(byName.ColliderSouth, nil, "no ColliderSouth")
		near(whole.size[3], 536, "the band's whole length"); near(whole.position[3], -3, "the band's centre z")
		near(whole.position[3] - whole.size[3] / 2, -271, "from the band's south end"); near(whole.position[3] + whole.size[3] / 2, 265, "to its north end")
		near(whole.position[1], 1540, "Collider x"); near(whole.size[1], 4, "Collider thick"); near(whole.size[2], 80, "Collider tall")
		equal(whole.role, "solid", "Collider role"); equal(whole.canCollide, true, "Collider collides")
		equal(whole.canQuery, true, "Collider query"); equal(whole.canTouch, false, "Collider touch")
		near(whole.transparency, 1, "Collider invisible")
		-- built: at every z of the band (half-stud steps, -271..265), a colliding part rising above the floor covers x 1538..1542
		local holder = Instance.new("Folder")
		local root = East.build(holder, Layout, V3Mouth)
		local solids = {}
		for _, part in ipairs(root:GetDescendants()) do
			if part:IsA("BasePart") and part.CanCollide and part.Position.Y + part.Size.Y / 2 > Layout.FLOOR_TOP + 0.01 then
				table.insert(solids, part)
			end
		end
		for step = 0, 2 * (P.band.maxZ - P.band.minZ) do
			local z = P.band.minZ + step / 2
			local covered = false
			for _, part in ipairs(solids) do
				local p, s = part.Position, part.Size
				if p.X - s.X / 2 <= 1538 + 1e-3 and p.X + s.X / 2 >= 1542 - 1e-3
					and p.Z - s.Z / 2 <= z + 1e-3 and p.Z + s.Z / 2 >= z - 1e-3 then
					covered = true
					break
				end
			end
			assert(covered, "a gap in the wall at z " .. z)
		end
		equal(root.CloudWall.Collider:GetAttribute("WallMargin"), East.WALL_MARGIN, "the Collider carries WallMargin")
		local wall = Smarts.wallOf(root)
		assert(wall, "wallOf still finds the wall")
		near(wall.x, 1540, "wallOf x"); equal(wall.margin, East.WALL_MARGIN, "wallOf margin")
		near((Smarts.outsideWall(1600, -3, 1530, -3, wall)), 1548, "a creature east of the wall stops at x 1548")
		near((Smarts.outsideWall(1500, -3, 1550, -3, wall)), 1532, "a creature of the plot stops at x 1532")
		holder:Destroy()
		-- a live map off the plan (K-D1's north piece, a floor of another size): the Collider grows back, the floor is set to
		-- the band and the tail, and a leftover ColliderSouth is never removed (tools/wildbound-pueblo-gatito-move.luau
		-- archives it); then nothing changes again
		local live = Instance.new("Folder")
		local liveRoot = East.build(live, Layout, V3Mouth)
		local north, liveFloor = liveRoot.CloudWall.Collider, liveRoot.Ground.Floor
		north.Size = Vector3.new(4, 80, 261)
		north.Position = Vector3.new(1540, 40.5, 134.5)
		liveFloor.Size = Vector3.new(536, 1, 520)
		liveFloor.Position = Vector3.new(1200, 0, -3)
		liveFloor.Material = Enum.Material.Grass
		local south = Instance.new("Part")
		south.Name = "ColliderSouth"
		south.Parent = liveRoot.CloudWall
		local _, conformed = East.build(live, Layout, V3Mouth)
		equal(conformed.created, 0, "nothing made"); assert(conformed.changed >= 3, "conformed: " .. conformed.changed)
		near(north.Size.Z, 536, "the Collider grew back"); near(north.Position.Z, -3, "on the band's centre")
		-- CL-D13: the floor is the band and the tail, 80 wide at x 1572 (was the band's 16 at x 940)
		near(liveFloor.Size.X, 80, "the floor set to the band and the tail"); near(liveFloor.Position.X, 1572, "the floor's centre")
		equal(liveFloor.Material, Enum.Material.SmoothPlastic, "the plot's material again")
		equal(south.Parent, liveRoot.CloudWall, "ColliderSouth left in place")
		local _, settled = East.build(live, Layout, V3Mouth)
		equal(settled.created, 0, "settled: nothing made"); equal(settled.changed, 0, "settled: nothing changed")
		live:Destroy()
	end)

	-- CL-D13: annexMove and annexGround keep the legacy formulas; the plot is x 412..1532, the band 1532..1548 and the
	-- legacy shift 1136 (were 932, 932..948 and 536). The annex slabs give the same two strips.
	case("V8-D4: the annex: plot props move by (x + shift, z), band props are archived, the slabs become two strips", function()
		local kind, x, z = East.annexMove(Layout, 500, -250)
		equal(kind, "move"); near(x, 1636); near(z, -250)
		kind, x = East.annexMove(Layout, 900, 100)
		equal(kind, "move"); near(x, 2036)
		equal((East.annexMove(Layout, 1540, 0)), "band", "in the cloud band")
		equal((East.annexMove(Layout, 1540, -268)), "band", "the band's south overhang")
		equal((East.annexMove(Layout, 1580, 0)), "keep", "east of the band")
		equal((East.annexMove(Layout, 600, -290)), "keep", "the south strip")
		equal((East.annexMove(Layout, 600, 280)), "keep", "the north strip")
		-- the big4 annex's three slabs (WildboundBig4Annex.CANDY.floors), level with the new floors
		local slabs = {
			{ name = "Floor_Big4_1", minX = 812, maxX = 1012, minZ = -303, maxZ = 297 },
			{ name = "Floor_Big4_2", minX = 412, maxX = 812, minZ = -303, maxZ = -203 },
			{ name = "Floor_Big4_3", minX = 412, maxX = 812, minZ = 197, maxZ = 297 },
		}
		local g = East.annexGround(Layout, slabs)
		equal(#g.resize, 2, "two strips"); equal(#g.archive, 1, "one slab archived"); equal(g.archive[1], "Floor_Big4_1")
		local byName = {}
		for _, r in ipairs(g.resize) do byName[r.name] = r.rect end
		rectIs(byName.Floor_Big4_2, 412, 1012, -303, -263, "south strip")
		rectIs(byName.Floor_Big4_3, 412, 1012, 257, 297, "north strip")
		equal(#g.keep, 0); equal(#g.overlap, 0)
		-- no slabs, nothing to do; an annex the floors do not span: only whole-covered slabs go, the others are listed
		equal(#East.annexGround(Layout, {}).archive, 0)
		local odd = East.annexGround(Layout, {
			{ name = "A", minX = 300, maxX = 500, minZ = -300, maxZ = -200 },
			{ name = "B", minX = 500, maxX = 600, minZ = -100, maxZ = 0 },
		})
		equal(#odd.resize, 0, "no strips"); equal(odd.archive[1], "B", "covered whole"); equal(odd.keep[1], "A")
		equal(odd.overlap[1], "A", "still meets the floors")
	end)

	case("V8-D3 wiring: the cloud client: client-only, Heartbeat, the built-in smoke, Efectos suaves, cleanup", function()
		local client = sources.client
		has(client, "RunService.Heartbeat:Connect", "Heartbeat drives it")
		hasNot(client, "RenderStepped", "RenderStepped did not fire in Studio Play")
		has(client, '"rbxasset://textures/particles/smoke_main.dds"', "the built-in smoke texture")
		hasNot(client, "rbxassetid", "no uploaded asset")
		has(client, 'Instance.new("ParticleEmitter")', "particle puffs")
		has(client, '"' .. East.ROOT_NAME .. '", "' .. East.FOLDER .. '", "Veil"', "on Candy_Este_v1.CloudWall.Veil")
		has(client, 'gui:GetAttribute("Reduced") == true', "Efectos suaves")
		has(client, "REDUCED_SHARE", "a lower rate with Efectos suaves")
		has(client, 'FindFirstChild("WildboundWorldUI")', "the world gui")
		has(client, "script.Destroying:Connect", "cleaned up with the script")
		has(client, "local function teardown()", "one cleanup")
		for _, banned in ipairs({ "FireServer", "InvokeServer", "RemoteEvent", "SetAttribute", "CanCollide = true" }) do
			hasNot(client, banned, "client-only, no gameplay")
		end
	end)

	-- PG-D6 (docs/design/wildbound-pueblo-gatito-biome-plan.md; owner request 2026-11-18, "hacelo bioma aparte"): the
	-- cloud has two faces: pink and white from Caramelo, white and sky blue from Pueblo Gatito, picked by the camera's side
	-- of the Veil at the 2 Hz step; the Veil part itself is unchanged.
	case("PG-D6 wiring: the cloud client keeps both palettes and picks one by the camera's side of the Veil", function()
		local client = sources.client
		has(client, "colors = { Color3.fromRGB(255, 214, 234), Color3.fromRGB(255, 240, 248) }", "the Caramelo puffs kept")
		has(client, "colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 226, 240) }", "the Caramelo wisps kept")
		has(client, "parkColors = { Color3.fromRGB(240, 248, 255), Color3.fromRGB(199, 226, 245) }", "the park puffs")
		has(client, "parkColors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(214, 236, 250) }", "the park wisps")
		has(client, "local park = eye ~= nil and eye.X > veil.Position.X", "the side: east of the Veil is the park")
		has(client, "if park ~= side then paint(park) end", "painted only when the side changes")
		has(client, "local colors = park and LAYERS[i].parkColors or LAYERS[i].colors", "that side's palette")
		has(client, "emitter.Color = ColorSequence.new(colors[1], colors[2])", "on every emitter")
		has(client, "side = nil", "a new emitter is painted at once")
		hasNot(client, "RenderStepped", "still the 2 Hz Heartbeat step")
		hasNot(client, "veil.Color =", "the Veil part is unchanged")
	end)

	case("V8-D3 wiring: both server clamps read the wall and keep creatures on their side", function()
		local beasts = sources.beasts
		has(beasts, 'world.smarts.wallOf(workspace:FindFirstChild("Candy_Este_v1"))', "the beasts read the wall")
		has(beasts, "world.smarts.outsideWall(px, pz, e.pos.x, e.pos.z, world.cloudWall)", "every step clamped")
		local from = string.find(beasts, "function world.keepOut", 1, true)
		assert(from, "world.keepOut")
		local clamp = string.find(beasts, "world.smarts.outsideWall(", from, true)
		local early = string.find(beasts, "if #discs == 0 then return end", from, true)
		assert(clamp and early and clamp < early, "the wall clamp comes before the no-houses early return")
		local duquesa = sources.duquesa
		has(duquesa, 'Smarts.wallOf(workspace:FindFirstChild("Candy_Este_v1"))', "her service reads the wall")
		has(duquesa, "Smarts.outsideWall(wasX, wasZ, her.x, her.z, wall)", "her flight clamped")
	end)

	case("V8-D4 wiring: the v8 migration follows the v5 harness and the plan's steps", function()
		local tool = sources.migrate
		has(tool, "local DRY_RUN = true", "a dry run first")
		has(tool, 'assert(not RunService:IsRunning(), "Edit mode only: stop Play first")', "Edit mode only")
		has(tool, 'local MARK, NEEDS = "CaramelV8", "CaramelV5"', "needs v5, marks v8")
		has(tool, "root:GetAttribute(V3.V5_MARK or NEEDS) ~= nil", "refuses a map without CaramelV5")
		has(tool, "if root:GetAttribute(MARK) ~= nil then", "refuses a map already marked CaramelV8")
		has(tool, "root:SetAttribute(MARK, 1)", "the mark")
		has(tool, 'local BACKUP, ARCHIVED = "CaramelV8Backup", "CaramelV8Archived"', "backup and archive folders")
		has(tool, '"WildboundMapArchive"', "under ServerStorage.WildboundMapArchive")
		has(tool, 'ChangeHistoryService:TryBeginRecording("CaramelV8")', "one recording")
		has(tool, "task.delay(0.5, function()", "outside the caller's recording")
		has(tool, "Enum.FinishRecordingOperation.Cancel", "undone on a failure")
		has(tool, 'local SUMMARY_ATTRIBUTE = "WildboundCaramelV8Summary"', "the JSON summary attribute")
		has(tool, "ServerStorage:SetAttribute(SUMMARY_ATTRIBUTE, json)", "published")
		has(tool, "_G.WildboundCaramelV8Summary = summary", "and in _G")
		has(tool, "V3.VERSION == 4", "the v8 layouts only")
		has(tool, "Layout.fromV7World(pivot.X, pivot.Z)", "pieces move by pivot")
		has(tool, "CFrame.new(x - pivot.X, 0, z - pivot.Z) * pivot", "turn and height kept")
		has(tool, "floor.Size = Vector3.new(Layout.HALF * 2, floor.Size.Y, Layout.HALF * 2)", "the floor grows")
		has(tool, 'torta:SetAttribute("LayoutKey", Builder.layoutKey(Layout))', "the Torta's new key")
		has(tool, "Builder.layPaths(root, Layout)", "paths"); has(tool, "Builder.layBoss(root, Layout)", "boss and plaza")
		has(tool, "Builder.layMarkers(root, Layout)", "markers"); has(tool, "V3Builder.layWater(root, deps)", "water")
		has(tool, "Builder.syncTower(root, Layout, Kit, library)", "tower"); has(tool, "Builder.syncNestPositions(root, Layout)", "nests")
		has(tool, "Duq.seatPivot(Frut.summit(Layout)", "the queen on the new summit")
		has(tool, "East.annexMove(Layout, pivot.X, pivot.Z)", "annex props"); has(tool, "East.annexGround(Layout, slabs)", "annex slabs")
		has(tool, "East.build(Workspace, Layout)", "Caramelo Este laid")
		-- V8-D1 (fixer): the Pradera sector marker moves with the plot (WildboundPraderaSites' x 1.3 offsets need it),
		-- backed up first, once (the CaramelV8 mark)
		has(tool, 'local PRADERA = "WildboundPradera"', "the Pradera marker")
		has(tool, "Layout.fromV7World(pv.X, pv.Z)", "moved by fromV7World")
		has(tool, "if pm then pradera:PivotTo(pm.to) end", "moved in the real run")
		has(tool, "{ root, annex, queen, pradera }", "backed up")
		has(tool, "summary.pradera = pm.line", "reported in both runs")
		has(tool, "instance.Parent = archived", "archived, never destroyed")
		has(tool, '"SistemaSonriente"', "SistemaSonriente is never touched")
		-- the only Destroy is the dry run's detached scratch model
		local destroys = 0
		for _ in string.gmatch(tool, ":Destroy%(") do destroys += 1 end
		equal(destroys, 1, "one Destroy"); has(tool, "scratch:Destroy()", "the scratch model's")
	end)

	return result
end

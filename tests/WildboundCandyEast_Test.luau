-- Invoke with require(freshTestClone)(require(freshCandyEastClone), require(freshCandyLayoutClone),
-- require(freshCandySmartsClone), { client = WildboundCandyCloudWallClient.Source, beasts = WildboundBeasts.Source,
-- duquesa = WildboundCandyDuquesaService.Source, migrate = WildboundCaramelV8Migrate.Source }).
-- Caramelo v8 (owner request 2026-11-17: "another space of the same size, separated by clouds: an invisible wall with a
-- cloud texture that you can see through"; docs/design/wildbound-caramelo-v8-plan.md V8-D2 to V8-D4): Caramelo Este's
-- plan numbers from the layout, its floor and cloud wall built on a detached folder (twice: the second build changes
-- nothing), the creature clamp against the built wall, the big4 annex's moves and floor slabs, and source pins of the
-- cloud client, the two server clamps and the v8 migration tool. Changes nothing outside its own detached folders.
-- Pueblo Gatito (docs/design/wildbound-kitten-park-plan.md K-D1, K-D15): the gate splits the Collider into Collider and
-- ColliderSouth (14-stud gap at z -10..4) and the floor turns grass green.
-- PGM-D5 (docs/design/wildbound-pueblo-gatito-move-plan.md; owner request 2026-11-18, "Sí, movelo"): the park moved to
-- the big4 south arm, so the wall closes again: one whole Collider, no ColliderSouth, the floor under the band only, pink.
return function(East, Layout, Smarts, sources)
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
		local P = East.plan(Layout)
		local cx, cz, half = Layout.CENTRE.x, Layout.CENTRE.z, Layout.HALF
		rectIs(P.plot, cx - half, cx + half, cz - half, cz + half, "plot from the layout")
		-- the v8 layout (V8-D1): CENTRE (672, -3), HALF 260
		rectIs(P.plot, 412, 932, -263, 257, "plot")
		rectIs(P.band, 932, 948, -271, 265, "band: 16 wide, the plot's length plus 8 at each end")
		rectIs(P.space, 948, 1468, -263, 257, "space: as big as the plot")
		near(P.space.maxX - P.space.minX, P.plot.maxX - P.plot.minX, "same width")
		near(P.space.maxZ - P.space.minZ, P.plot.maxZ - P.plot.minZ, "same length")
		near(P.centre.x, 1208, "space centre x"); near(P.centre.z, -3, "space centre z")
		-- Deliberately changed (PGM-D5): the floor is under the band only, the plot's z (was x 932..1468, band and space)
		rectIs(P.ground, 932, 948, -263, 257, "the floor under the band only")
		equal(P.gate, nil, "no gate (PGM-D5)")
		near(P.wallX, 940, "the wall on the band's centre line"); near(East.wallX(Layout), 940, "wallX")
		near(P.shift, 536, "a plot point lands at the same spot of the space"); near(P.floorTop, Layout.FLOOR_TOP, "floor top")
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
		-- Deliberately changed (PGM-D5): five parts again, the Collider whole, no ColliderSouth (was six, K-D1; five
		-- before it, V8-D3 amendment; three before that)
		equal(#P.parts, 5, "five parts, nothing else")
		local order = { "Floor", "Collider", "Veil", "CapNorth", "CapSouth" }
		for i, name in ipairs(order) do equal(P.parts[i].name, name, "part " .. i) end
		equal(byName.ColliderSouth, nil, "no ColliderSouth (PGM-D5)")
		equal(floor.folder, "Ground"); equal(collider.folder, "CloudWall"); equal(veil.folder, "CloudWall")
		-- Deliberately changed (PGM-D5): the floor is the band's 16 by the plot's 520, centred on the wall (was 536 x 520
		-- at x 1200, under the band and the space)
		near(floor.size[1], 16); near(floor.size[2], 1); near(floor.size[3], 520)
		near(floor.position[1], 940); near(floor.position[2] + floor.size[2] / 2, Layout.FLOOR_TOP, "floor top"); near(floor.position[3], -3)
		-- Deliberately changed (PGM-D5): the Collider is the band's whole length again, z -271..265 (was K-D1's north
		-- piece, 261, z 4..265)
		near(collider.size[1], 4); near(collider.size[2], 80); near(collider.size[3], 536, "the band's whole length")
		near(veil.size[1], 16); near(veil.size[2], 80); near(veil.size[3], 536)
		-- Deliberately changed (PGM-D5): the Collider's centre z is the band's, -3, like the Veil (was 134.5, K-D1)
		near(collider.position[1], 940, "Collider x"); near(collider.position[3], -3, "Collider z (the band's centre)")
		near(veil.position[1], 940, "Veil x"); near(veil.position[3], -3, "Veil z")
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
		local P = East.plan(Layout)
		local byName = {}
		for _, spec in ipairs(P.parts) do byName[spec.name] = spec end
		local north, south = byName.CapNorth, byName.CapSouth
		assert(north and south, "CapNorth and CapSouth")
		rectIs(P.caps.north, 938, 1468, 261, 265, "north cap: inside the band's north end, to the space's far edge")
		rectIs(P.caps.south, 938, 1468, -271, -267, "south cap: inside the band's south end")
		for _, spec in ipairs({ north, south }) do
			equal(spec.folder, "CloudWall", spec.name .. " folder"); equal(spec.role, "solid", spec.name .. " role")
			equal(spec.canCollide, true, spec.name .. " collides"); equal(spec.canQuery, true, spec.name .. " query")
			equal(spec.canTouch, false, spec.name .. " touch"); equal(spec.castShadow, false, spec.name .. " shadow")
			near(spec.transparency, 1, spec.name .. " invisible")
			near(spec.size[1], 530); near(spec.size[2], 80); near(spec.size[3], 4)
			near(spec.position[2] - spec.size[2] / 2, Layout.FLOOR_TOP, spec.name .. " stands on the floor")
		end
		-- each cap meets the Collider (inside its z run, from its west face) and stays out of the plot
		for _, r in ipairs({ P.caps.north, P.caps.south }) do
			assert(r.minZ >= P.band.minZ - 1e-6 and r.maxZ <= P.band.maxZ + 1e-6, "inside the band's z run")
			near(r.minX, P.wallX - East.COLLIDER_THICK / 2, "joined to the Collider")
			assert(r.minX >= P.plot.maxX, "out of the plot")
		end
		-- the ground past the band's ends: the annex strips (V8-D4, to x 1012, z -303..-263 and 257..297) and the big4
		-- Baseplate (to x 1024 at every z); a cap runs past all of it, to where only void is left
		assert(P.caps.north.maxX > 1024 and P.caps.south.maxX > 1024, "past the walkable ground's east edge")
		assert(P.caps.north.minZ >= P.space.maxZ and P.caps.south.maxZ <= P.space.minZ, "off the second space's floor")
	end)

	case("V8-D3: build lays the floor and the cloud wall with the right flags; a second build changes nothing", function()
		local holder = Instance.new("Folder")
		holder.Name = "CandyEastTest"
		local other = Instance.new("Part")
		other.Name = "SomethingElse"
		other.Parent = holder
		local root, report = East.build(holder, Layout)
		equal(root.Parent, holder, "under the given parent"); equal(root.Name, East.ROOT_NAME); assert(root:IsA("Model"), "a Model")
		-- Deliberately changed (PGM-D5): five parts again, the Collider whole (was six, K-D1; created >= 9)
		equal(report.parts, 5, "five parts")
		assert(report.created >= 8, "root, two folders and five parts made: " .. report.created)
		local floor = root.Ground.Floor
		local collider, veil = root.CloudWall.Collider, root.CloudWall.Veil
		-- the floor; Deliberately changed (PGM-D5): the plot's pink SmoothPlastic (was K-D15's green Grass)
		equal(floor:GetAttribute("Role"), "floor"); equal(floor.Anchored, true); equal(floor.CanCollide, true)
		equal(floor.Material, Enum.Material.SmoothPlastic, "the plot's material")
		near(floor.Color.R * 255, 255, "pink R", 0.6); near(floor.Color.G * 255, 177, "pink G", 0.6); near(floor.Color.B * 255, 209, "pink B", 0.6)
		near(floor.Position.Y + floor.Size.Y / 2, Layout.FLOOR_TOP, "the plot's floor top")
		-- Deliberately changed (PGM-D5): the band only, x 932..948 (was to the space's far edge, 1468)
		near(floor.Position.X - floor.Size.X / 2, 932, "from the plot's east edge"); near(floor.Position.X + floor.Size.X / 2, 948, "to the band's")
		-- the collider: invisible, collides, answers rays, never touched, no shadow, solid, never a pass for creatures
		equal(collider.Anchored, true, "collider anchored"); equal(collider.CanCollide, true, "collider collides")
		equal(collider.CanQuery, true, "collider blocks sight"); equal(collider.CanTouch, false, "collider touch")
		equal(collider.CastShadow, false, "collider shadow"); near(collider.Transparency, 1, "invisible")
		equal(collider:GetAttribute("Role"), "solid", "collider role")
		equal(CollectionService:HasTag(collider, "WildboundBeastPass"), false, "never a pass")
		equal(CollectionService:HasTag(root, "WildboundBeastPass"), false, "the root is no pass either")
		equal(collider:GetAttribute("WallMargin"), East.WALL_MARGIN, "the clamp margin")
		near(collider.Size.X, 4); near(collider.Size.Y, 80); near(collider.Position.X, 940)
		near(collider.Size.Z, 536, "PGM-D5: the band's whole length"); near(collider.Position.Z, -3, "on the band's centre")
		-- the veil: ForceField cloud pink, never collides, never answers rays, never touched: the player sees through it
		equal(veil.Material, Enum.Material.ForceField, "ForceField")
		near(veil.Color.R * 255, 255, "pink R", 0.6); near(veil.Color.G * 255, 226, "pink G", 0.6); near(veil.Color.B * 255, 240, "pink B", 0.6)
		equal(veil.CanCollide, false, "veil collide"); equal(veil.CanQuery, false, "veil query"); equal(veil.CanTouch, false, "veil touch")
		near(veil.Size.X, 16); near(veil.Size.Y, 80)
		-- Deliberately changed (PGM-D5): the root attribute Key follows East.KEY, the wall's (was "pueblo-gatito", PG-D2;
		-- "caramelo-este" before it)
		equal(root:GetAttribute("WallX"), 940); equal(root:GetAttribute("Key"), "caramelo-nube")
		-- idempotent
		local again, second = East.build(holder, Layout)
		equal(again, root, "the same root")
		equal(second.created, 0, "nothing made the second time"); equal(second.changed, 0, "nothing changed the second time")
		local count = 0
		for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") then count += 1 end end
		equal(count, 5, "still five parts") -- Deliberately changed (PGM-D5): was six (K-D1), five before it, three before that
		-- Deliberately changed (PGM-D5): no ColliderSouth is built (was built with the caps' flags, K-D1)
		equal(root.CloudWall:FindFirstChild("ColliderSouth"), nil, "no ColliderSouth")
		for _, name in ipairs({ "CapNorth", "CapSouth" }) do
			local cap = root.CloudWall:FindFirstChild(name)
			assert(cap, name .. " built")
			equal(cap.CanCollide, true, name .. " collides"); equal(cap.CanTouch, false, name .. " touch")
			near(cap.Transparency, 1, name .. " invisible"); equal(cap:GetAttribute("Role"), "solid", name .. " role")
			equal(CollectionService:HasTag(cap, "WildboundBeastPass"), false, name .. " never a pass")
		end
		equal(holder.SomethingElse, other, "nothing else under the parent is touched")
		-- a piece pushed off its plan is set back, then nothing changes again
		veil.CanQuery = true
		collider.Position = Vector3.new(950, 40, 0)
		local _, fixed = East.build(holder, Layout)
		assert(fixed.changed >= 2 and fixed.created == 0, "set back: " .. fixed.changed)
		equal(veil.CanQuery, false, "the veil never blocks rays"); near(collider.Position.X, 940, "the collider back")
		local _, third = East.build(holder, Layout)
		equal(third.changed, 0, "settled")
		-- never inside SistemaSonriente
		local sonriente = Instance.new("Folder")
		sonriente.Name = "SistemaSonriente"
		local inner = Instance.new("Folder")
		inner.Parent = sonriente
		equal((pcall(East.build, inner, Layout)), false, "refuses SistemaSonriente")
		equal(#inner:GetChildren(), 0, "nothing laid there")
		sonriente:Destroy()
		holder:Destroy()
	end)

	case("V8-D3: creatures from the plot stop on its east edge, out of the band; the wall is read from the built map", function()
		local holder = Instance.new("Folder")
		local root = East.build(holder, Layout)
		local wall = Smarts.wallOf(root)
		assert(wall, "Smarts.wallOf reads the built wall")
		near(wall.x, East.wallX(Layout), "x"); equal(wall.margin, East.WALL_MARGIN, "margin")
		equal(Smarts.WALL_MARGIN_STUDS, East.WALL_MARGIN, "one margin on both sides")
		equal(Smarts.WALL_ROOT, East.ROOT_NAME, "one root name")
		local P = East.plan(Layout)
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
	case("PGM-D5: the closed wall: no gate, no gap anywhere along the band; the clamp still reads x 940", function()
		equal(East.GATE, nil, "no GATE")
		local P = East.plan(Layout)
		equal(P.gate, nil, "no gate in the plan")
		local byName = {}
		for _, spec in ipairs(P.parts) do byName[spec.name] = spec end
		local whole = byName.Collider
		assert(whole, "Collider")
		equal(byName.ColliderSouth, nil, "no ColliderSouth")
		near(whole.size[3], 536, "the band's whole length"); near(whole.position[3], -3, "the band's centre z")
		near(whole.position[3] - whole.size[3] / 2, -271, "from the band's south end"); near(whole.position[3] + whole.size[3] / 2, 265, "to its north end")
		near(whole.position[1], 940, "Collider x"); near(whole.size[1], 4, "Collider thick"); near(whole.size[2], 80, "Collider tall")
		equal(whole.role, "solid", "Collider role"); equal(whole.canCollide, true, "Collider collides")
		equal(whole.canQuery, true, "Collider query"); equal(whole.canTouch, false, "Collider touch")
		near(whole.transparency, 1, "Collider invisible")
		-- built: at every z of the band (half-stud steps, -271..265), a colliding part rising above the floor covers x 938..942
		local holder = Instance.new("Folder")
		local root = East.build(holder, Layout)
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
				if p.X - s.X / 2 <= 938 + 1e-3 and p.X + s.X / 2 >= 942 - 1e-3
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
		near(wall.x, 940, "wallOf x"); equal(wall.margin, East.WALL_MARGIN, "wallOf margin")
		near((Smarts.outsideWall(1000, -3, 930, -3, wall)), 948, "a creature east of the wall stops at x 948")
		near((Smarts.outsideWall(900, -3, 950, -3, wall)), 932, "a creature of the plot stops at x 932")
		holder:Destroy()
		-- a live K-D1 map: the north piece grows back, the floor shrinks to the band, and a leftover ColliderSouth is never
		-- removed (tools/wildbound-pueblo-gatito-move.luau archives it); then nothing changes again
		local live = Instance.new("Folder")
		local liveRoot = East.build(live, Layout)
		local north, liveFloor = liveRoot.CloudWall.Collider, liveRoot.Ground.Floor
		north.Size = Vector3.new(4, 80, 261)
		north.Position = Vector3.new(940, 40.5, 134.5)
		liveFloor.Size = Vector3.new(536, 1, 520)
		liveFloor.Position = Vector3.new(1200, 0, -3)
		liveFloor.Material = Enum.Material.Grass
		local south = Instance.new("Part")
		south.Name = "ColliderSouth"
		south.Parent = liveRoot.CloudWall
		local _, conformed = East.build(live, Layout)
		equal(conformed.created, 0, "nothing made"); assert(conformed.changed >= 3, "conformed: " .. conformed.changed)
		near(north.Size.Z, 536, "the Collider grew back"); near(north.Position.Z, -3, "on the band's centre")
		near(liveFloor.Size.X, 16, "the floor shrank to the band"); near(liveFloor.Position.X, 940, "the floor on the wall")
		equal(liveFloor.Material, Enum.Material.SmoothPlastic, "the plot's material again")
		equal(south.Parent, liveRoot.CloudWall, "ColliderSouth left in place")
		local _, settled = East.build(live, Layout)
		equal(settled.created, 0, "settled: nothing made"); equal(settled.changed, 0, "settled: nothing changed")
		live:Destroy()
	end)

	case("V8-D4: the annex: plot props move by (x + 536, z), band props are archived, the slabs become two strips", function()
		local kind, x, z = East.annexMove(Layout, 500, -250)
		equal(kind, "move"); near(x, 1036); near(z, -250)
		kind, x = East.annexMove(Layout, 900, 100)
		equal(kind, "move"); near(x, 1436)
		equal((East.annexMove(Layout, 940, 0)), "band", "in the cloud band")
		equal((East.annexMove(Layout, 940, -268)), "band", "the band's south overhang")
		equal((East.annexMove(Layout, 980, 0)), "keep", "already in the second space")
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

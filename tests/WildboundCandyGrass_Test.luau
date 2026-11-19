-- Invoke with require(freshTestClone)(require(freshCandyGrassClone), require(freshCandyHideSpotsClone),
--   require(freshCandyHidingClone), require(freshCandyLayoutClone), require(freshCandyV3LayoutClone),
--   require(freshBeastEncountersClone), require(freshBeastCandyCritterClone), { beasts = <WildboundBeasts Source>,
--   flyers = <WildboundCandyFlyersService Source>, duquesa = <WildboundCandyDuquesaService Source>,
--   nests = <WildboundCandyNests Source> }).
-- Caramelo v6 (odd/tasks/wildbound-caramelo-v2.md, V6-D1; V6-D10.. in docs/design/wildbound-caramelo-v3-plan.md): tall
-- licorice grass.
--   WildboundCandyGrass lays about 10 patches of tall black and red licorice blades in the open meadows beside the
--   routes, each a Grass_G<n> Model tagged WildboundCandyGrass with a Radius attribute, of thin non-colliding plain parts,
--   clear of the chocolate (read from the layout at sync time), the paths, nests, posts, houses, bridges and the v5 hide
--   spots (the live HideSpots folder). Every fixture is built detached (never parented to a service).
--   WildboundCandyHiding's grass rule: a player in a patch who is not sprinting is seen by a candy creature only within
--   10 studs; a calm creature never notices them farther out, a hunter loses them after the memory time (3 s) and
--   searches like for a hidden player. A real Mochimiau brain stepped with it, and the wiring of the beast server, the
--   bees, La Duquesa and the server start.
return function(Grass, Spots, Hiding, Layout, V3, Enc, Critter, sources)
	local CollectionService = game:GetService("CollectionService")
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
	local function flat(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
	assert(type(Grass) == "table" and type(Spots) == "table" and type(Hiding) == "table" and type(Layout) == "table"
		and type(V3) == "table", "pass Grass, HideSpots, Hiding, the layout and the V3 layout")
	sources = type(sources) == "table" and sources or {}

	-- A detached biome (as WildboundCandyHideSpots_Test builds it): the floor, the v3 mountains and houses (one colliding
	-- block each, the size of their footprint) and the live nests, all at their layout spots.
	local C = Layout.CENTRE
	local function biome()
		local root = Instance.new("Model")
		root.Name = Layout.ROOT_NAME
		local ground = Instance.new("Folder")
		ground.Name, ground.Parent = "Ground", root
		local floor = Instance.new("Part")
		-- CL-D13: the v9 floor is the rectangle x -HALF..EAST, z -HALF..HALF (1120 x 520, centre 300 east of CENTRE)
		floor.Name, floor.Anchored, floor.Size = "Floor", true, Vector3.new(Layout.HALF + Layout.EAST, 1, Layout.HALF * 2)
		floor.Position = Vector3.new(C.x + (Layout.EAST - Layout.HALF) / 2, Layout.FLOOR_TOP - 0.5, C.z)
		floor.Parent = ground
		local v3 = Instance.new("Folder")
		v3.Name, v3.Parent = V3.FOLDER, root
		local mountains = Instance.new("Folder")
		mountains.Name, mountains.Parent = "Mountains", v3
		for _, m in ipairs(V3.MOUNTAINS) do
			local model = Instance.new("Model")
			model.Name = "Mountain_" .. m.id
			local block = Instance.new("Part")
			block.Name, block.Anchored = "Collision_Body", true
			block.Size = Vector3.new(m.r * 1.4, m.height, m.r * 1.4)
			block.Position = Vector3.new(C.x + m.x, Layout.FLOOR_TOP + m.height / 2, C.z + m.z)
			block.Parent = model
			model.WorldPivot = CFrame.new(C.x + m.x, Layout.FLOOR_TOP, C.z + m.z)
			model:SetAttribute("MountainId", m.id)
			model.Parent = mountains
		end
		local houses = Instance.new("Folder")
		houses.Name, houses.Parent = "Houses", v3
		for _, h in ipairs(V3.HOUSES) do
			local model = Instance.new("Model")
			model.Name = "House_" .. h.id
			local block = Instance.new("Part")
			block.Name, block.Anchored = "Collision_Wall", true
			block.Size = Vector3.new(h.r * 1.4, 12, h.r * 1.4)
			block.Position = Vector3.new(C.x + h.x, Layout.FLOOR_TOP + 6, C.z + h.z)
			block.Parent = model
			model.WorldPivot = CFrame.new(C.x + h.x, Layout.FLOOR_TOP, C.z + h.z)
			model:SetAttribute("HouseId", h.id)
			model.Parent = houses
		end
		local nests = Instance.new("Folder")
		nests.Name, nests.Parent = "Nests", root
		for _, n in ipairs(Layout.NESTS) do
			local model = Instance.new("Model")
			model.Name = "Nest_" .. n.id
			model.WorldPivot = CFrame.new(C.x + n.x, Layout.FLOOR_TOP, C.z + n.z)
			model:SetAttribute("NestId", n.id)
			model.Parent = nests
		end
		return root
	end
	-- Deliberately changed (V7-D5): the grass is off on the map (Grass.ENABLED false); the suite lays it with opts.enabled
	local OPTS = { posts = {}, Spots = Spots, enabled = true }
	local function patchesOf(root)
		local folder = root:FindFirstChild(Grass.FOLDER)
		local list = {}
		for _, m in ipairs(folder and folder:GetChildren() or {}) do table.insert(list, m) end
		table.sort(list, function(a, b) return a.Name < b.Name end)
		return list
	end
	local function localOf(model)
		local p = model:GetPivot().Position
		return p.X - C.x, p.Z - C.z
	end
	-- the biome with its v5 hide spots laid first (as at server start), then the grass
	local function laid()
		local root = biome()
		Spots.sync(root, Layout, V3, { kit = false, posts = {} })
		local changed, skipped, count, parts = Grass.sync(root, Layout, V3, OPTS)
		return root, changed, skipped, count, parts
	end

	-- The rule -------------------------------------------------------------------------------------------------------
	case("V6-D1: the grass rule: covered unless sprinting, seen only within 10 studs", function()
		local G = Hiding.GRASS
		equal(G.seeStuds, 10, "seen only within 10 studs")
		equal(G.memorySeconds, 3, "the memory time (V6-D10)")
		equal(G.tag, Grass.TAG, "the patches' tag is the one the rules read")
		equal(G.radiusAttribute, "Radius", "the footprint attribute")
		equal(Hiding.covered(true, "walk"), true, "walking in the grass")
		equal(Hiding.covered(true, nil), true, "no stance yet: walking")
		equal(Hiding.covered(true, "sprint"), false, "sprinting gives you away")
		equal(Hiding.covered(nil, "walk"), false, "out of the grass")
		equal(Hiding.concealed(15, true, "walk"), true, "15 studs off: unseen")
		equal(Hiding.concealed(8, true, "walk"), false, "8 studs off: seen")
		equal(Hiding.concealed(10, true, "walk"), false, "10 studs off: seen")
		equal(Hiding.concealed(15, true, "sprint"), false, "a sprinter is seen")
		equal(Hiding.concealed(15, nil, "walk"), false, "out of the grass")
		equal(Hiding.concealed(nil, true, "walk"), true, "an unknown distance counts as far")
	end)

	case("V6-D1: which patch a player stands in comes from positions (centre and radius)", function()
		local patches = { { x = 100, z = 50, r = 9 }, { x = -40, z = 0, r = 9 } }
		equal(Hiding.inGrass(patches, 100, 50), patches[1], "the centre")
		equal(Hiding.inGrass(patches, 108.9, 50), patches[1], "inside the radius")
		equal(Hiding.inGrass(patches, 109.2, 50), nil, "just out")
		equal(Hiding.inGrass(patches, -40, 5), patches[2], "the other patch")
		equal(Hiding.inGrass(patches, 0 / 0, 5), nil, "no position, no grass")
		equal(Hiding.inGrass(nil, 0, 0), nil, "no patches")
		-- a tagged model's pivot and radius attribute; anything else is skipped
		local m = Instance.new("Model")
		local part = Instance.new("Part")
		part.Parent = m
		m.WorldPivot = CFrame.new(30, 0.5, -20)
		m:SetAttribute("Radius", 9)
		local bare = Instance.new("Model")
		local list = Hiding.grassPatches({ m, bare, part })
		equal(#list, 1, "one usable patch")
		near(list[1].x, 30); near(list[1].z, -20); equal(list[1].r, 9)
	end)

	case("V6-D1: the plan: a calm creature never notices; a hunter keeps them for 3 s, then searches", function()
		local memo = {}
		equal(Hiding.grassPlan({ phase = "Patrol" }, true, "Mochimiau", memo, 0), "far", "calm: never noticed")
		equal(memo.since, nil, "no memory for a calm creature")
		equal(Hiding.grassPlan({ phase = "Chase" }, false, "Mochimiau", memo, 0), "none", "seen")
		equal(Hiding.grassPlan({ phase = "Chase" }, true, "Viper", {}, 0), "none", "not a candy creature")
		local hunter = { phase = "Chase" }
		local m2 = {}
		equal(Hiding.grassPlan(hunter, true, "Mochimiau", m2, 10), "none", "just lost to the grass: still tracked")
		equal(Hiding.grassPlan(hunter, true, "Mochimiau", m2, 12.9), "none", "within the memory time")
		equal(Hiding.grassPlan(hunter, true, "Mochimiau", m2, 13), "search", "lost after 3 s: it searches")
		equal(Hiding.grassPlan(hunter, false, "Mochimiau", m2, 13.5), "none", "seen again (close, or sprinting)")
		equal(m2.since, nil, "the memory starts again")
		equal(Hiding.grassPlan(hunter, true, "Mochimiau", m2, 14), "none", "a new memory time")
		local m3 = {}
		Hiding.grassPlan({ phase = "Chase" }, true, "DonGlaseon", m3, 0)
		equal(Hiding.grassPlan({ phase = "Chase" }, true, "DonGlaseon", m3, 3), "under", "the boss searches by his own rule")
	end)

	-- The patches ----------------------------------------------------------------------------------------------------
	case("V6-D1: the pure clearance rule (chocolate, paths, posts, hide spots, the edge and the spacing)", function()
		local ctx = Grass.context(Layout, V3, Spots, {})
		equal(Grass.blocked(V3.LAKE[1].x, V3.LAKE[1].z, ctx), "liquid", "in the lake")
		assert(Grass.blocked(-150, 0, ctx) ~= nil, "on the main path")
		-- CL-D1: the east edge is at EAST now (HALF - 2 is deep in the grown plot)
		equal(Grass.blocked(Layout.EAST - 2, 60, ctx), "edge", "on the plot edge")
		local h = V3.HOUSES[1]
		assert(Grass.blocked(h.x, h.z, ctx) ~= nil, "inside a house")
		local n = Layout.NESTS[1]
		assert(Grass.blocked(n.x + 3, n.z, ctx) ~= nil, "beside a nest")
		-- a clear try, then a post, a hide spot and another patch beside it
		local free
		for _, c in ipairs(Grass.candidates(Layout)) do
			if Grass.blocked(c.x, c.z, ctx) == nil then free = c break end
		end
		assert(free, "no clear try at all")
		local withPost = Grass.context(Layout, V3, Spots, { posts = { { x = free.x + 3, z = free.z } } })
		equal(Grass.blocked(free.x, free.z, withPost), "post", "beside a creature post")
		local withHide = Grass.context(Layout, V3, Spots, { hides = { { x = free.x + 3, z = free.z } } })
		equal(Grass.blocked(free.x, free.z, withHide), "hide", "beside a v5 hide spot")
		table.insert(ctx.patches, { x = free.x + 10, z = free.z })
		equal(Grass.blocked(free.x, free.z, ctx), "spacing", "too near another patch")
	end)

	case("V6-D1: sync lays about 10 patches beside the routes, each of thin non-colliding blades", function()
		local root, changed, skipped, count, parts = laid()
		local list = patchesOf(root)
		equal(count, #list, "laid count")
		assert(#list >= 8 and #list <= Grass.TARGET, "about 10 patches, got " .. #list .. " (" .. table.concat(skipped, ",") .. ")")
		equal(changed, #list, "each new patch is a change")
		equal(parts, #list * Grass.BLADES, "the part count")
		assert(Grass.BLADES <= 40, "a modest part count per patch")
		local R = Grass.RADIUS
		local hides = {}
		for _, m in ipairs(root[Spots.FOLDER]:GetChildren()) do
			local x, z = localOf(m)
			table.insert(hides, { x = x, z = z, name = m.Name })
		end
		assert(#hides >= 10, "the v5 hide spots were laid first")
		local seen = {}
		for i, m in ipairs(list) do
			assert(m:IsA("Model") and m.Name:match("^Grass_G%d+$"), "a Grass_G<n> model: " .. m.Name)
			assert(not seen[m.Name], "a unique name"); seen[m.Name] = true
			assert(CollectionService:HasTag(m, Grass.TAG), m.Name .. " is tagged")
			equal(m:GetAttribute("Radius"), R, m.Name .. " radius")
			equal(m:GetAttribute("PatchId"), m.Name:sub(7), m.Name .. " id")
			equal(#m:GetChildren(), Grass.BLADES, m.Name .. " blades")
			local pivot = m:GetPivot().Position
			near(pivot.Y, Layout.FLOOR_TOP, m.Name .. " on the floor", 1e-3)
			local black, red = 0, 0
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					assert(d.Anchored and not d.CanCollide and not d.CanQuery and not d.CanTouch, d:GetFullName() .. " must be an anchored ghost")
					assert(d.Size.Y >= 5, "a tall blade (" .. d.Size.Y .. ")")
					assert(d.Size.X <= 0.6 and d.Size.Z <= 0.6, "a thin blade")
					assert(flat(d.Position.X, d.Position.Z, pivot.X, pivot.Z) <= R + 0.6, "a blade outside the footprint")
					if d.Color.R < 0.3 then black += 1 else red += 1 end
				end
			end
			assert(black > 0 and red > 0, "black and red licorice")
			local x, z = localOf(m)
			assert(V3.liquidDistance(x, z) >= R + Grass.LIQUID_MARGIN - 1e-6, m.Name .. " too near the chocolate")
			local road = Layout.routeDistance(x, z)
			assert(road >= Layout.PATH_WIDTH / 2 + Grass.ROUTE_MARGIN + R - 1e-6, m.Name .. " on a path")
			-- (no upper bound: Layout.routeDistance does not measure every leg of Layout.ROUTES, so a patch beside its own
			-- route may read farther; seen in Studio 2026-11-17 for Grass_G134)
			for _, n in ipairs(Layout.NESTS) do
				assert(flat(x, z, n.x, n.z) >= R + Grass.NEST_CLEAR - 1e-6, m.Name .. " beside nest " .. n.id)
			end
			for _, h in ipairs(V3.HOUSES) do
				assert(flat(x, z, h.x, h.z) >= h.r + R, m.Name .. " in house " .. h.id)
			end
			for _, h in ipairs(hides) do
				assert(flat(x, z, h.x, h.z) >= R + Grass.HIDE_CLEAR - 1e-6, m.Name .. " beside hide spot " .. h.name)
			end
			assert(not V3.nearBridge(x, z, R), m.Name .. " on a bridge")
			for j = i + 1, #list do
				local ox, oz = localOf(list[j])
				assert(flat(x, z, ox, oz) >= Grass.SPACING - 1e-6, m.Name .. " too near " .. list[j].Name)
			end
		end
		-- the rules read the laid patches: a player at a patch's centre is in the grass, one just past its edge is not
		local patches = Hiding.grassPatches(list)
		equal(#patches, #list, "every patch readable")
		local p = list[1]:GetPivot().Position
		assert(Hiding.inGrass(patches, p.X, p.Z), "in the grass at the centre")
		equal(Hiding.inGrass(patches, p.X + R + 0.5, p.Z), nil, "out past the edge")
	end)

	case("V6-D1: sync is idempotent, follows a wider river and removes a patch under a solid", function()
		local root = laid()
		local before = #patchesOf(root)
		local again, _, count = Grass.sync(root, Layout, V3, OPTS)
		equal(again, 0, "nothing changes on a second start")
		equal(count, before); equal(#patchesOf(root), before, "no duplicate")
		-- a solid rock dropped on a patch: that patch goes (another try may take its place)
		local first = patchesOf(root)[1]
		local where = first:GetPivot().Position
		local name = first.Name
		local rock = Instance.new("Part")
		rock.Name, rock.Anchored, rock.CanCollide = "Rock", true, true
		rock.Size, rock.Position = Vector3.new(6, 6, 6), where + Vector3.new(0, 3, 0)
		rock.Parent = root
		Grass.sync(root, Layout, V3, OPTS)
		local now = root[Grass.FOLDER]:FindFirstChild(name)
		assert(not now or (now:GetPivot().Position - where).Magnitude > 3, "a patch was left under a solid rock")
		-- the chocolate everywhere (read at sync time): every patch is removed
		local flooded = setmetatable({ liquidDistance = function() return -1 end }, { __index = V3 })
		local removed, _, left = Grass.sync(root, Layout, flooded, OPTS)
		equal(left, 0, "no patch in the chocolate")
		assert(removed >= before - 1, "the patches were removed")
		equal(#patchesOf(root), 0, "none left")
	end)

	case("V6-D1: nothing without the v3 biome; applyFlags lays the grass after the hide spots (guarded)", function()
		local bare = Instance.new("Model")
		local changed, skipped, count = Grass.sync(bare, Layout, V3, OPTS)
		equal(changed, 0); equal(count, 0); equal(#skipped, 0)
		equal(select(1, Grass.sync(nil, Layout, V3, OPTS)), 0, "no root: nothing, no error")
		local nests = sources.nests
		has(nests, 'FindFirstChild("WildboundCandyGrass")', "the module is looked up in ServerStorage (no wait)")
		has(nests, "pcall(G.sync, root, Layout)", "guarded")
		assert(nests:find("pcall(G.sync, root, Layout)", 1, true) > nests:find("pcall(S.sync, root, Layout)", 1, true),
			"after the hide spots (it keeps off them)")
		has(nests, "okGrass and tonumber(grass) or 0", "a sixth value: the patches changed")
	end)

	-- V7-D5 (owner request 2026-11-17, "take out the new grass"): off on the map; a laid map loses its patches at start
	case("V7-D5: the grass is off: the start's sync lays none and removes the patches already laid", function()
		equal(Grass.ENABLED, false, "the grass is off")
		local root, _, _, count = laid()
		assert(count >= 1 and #patchesOf(root) == count, "laid with opts.enabled")
		local removed, skipped, left, parts = Grass.sync(root, Layout, V3, { posts = {}, Spots = Spots })
		equal(removed, count, "every patch removed is a change")
		equal(left, 0); equal(parts, 0); equal(#skipped, 0)
		equal(root:FindFirstChild(Grass.FOLDER), nil, "the folder is gone")
		equal(select(1, Grass.sync(root, Layout, V3, { enabled = false })), 0, "a second sync: nothing to remove")
	end)

	-- A real brain --------------------------------------------------------------------------------------------------
	if type(Enc) == "table" and type(Critter) == "table" then
		Enc.register("Mochimiau", Critter)
		local function fakeWorld()
			local w = {}
			function w.ground() return 0 end
			function w.site() return nil end
			function w.telegraph() return true end
			function w.resolve() return "Hit" end
			function w.cancel() end
			function w.claimStrike() return true end
			function w.castLane() return nil end
			function w.safe() return false end
			return w
		end
		-- a player `d` studs from the creature (angle a), walking round it at 6 studs/s
		local function around(e, d, a)
			return { x = e.pos.x + d * math.cos(a), y = 3, z = e.pos.z + d * math.sin(a), vx = -6 * math.sin(a),
				vz = 6 * math.cos(a), alive = true, safe = false, walk = 16 }
		end
		-- steps a calm Mochimiau for `steps` with a player d studs off in the grass (stance); true when it noticed them
		local function noticed(id, d, stance, steps)
			local e = Enc.new("Mochimiau", id, 77, 0, { x = 0, y = 0, z = 0 })
			local w, memo, t = fakeWorld(), {}, 0
			for i = 1, steps do
				t += 0.05
				local target = around(e, d, i * 0.02)
				local plan = Hiding.grassPlan(e, Hiding.concealed(flat(e.pos.x, e.pos.z, target.x, target.z), true, stance),
					e.beast, memo, t)
				for _, ev in ipairs(Enc.step(e, t, Hiding.view(target, plan, e, nil, t), w)) do
					if ev.type == "Phase" and ev.phase == "Notice" then return true end
				end
			end
			return false
		end

		case("V6-D1: a calm Mochimiau never notices a walker 15 studs off in the grass; it does at 8, or a sprinter", function()
			equal(noticed("Mochimiau:grass1", 15, "walk", 160), false, "noticed a concealed walker 15 studs off")
			equal(noticed("Mochimiau:grass2", 8, "walk", 160), true, "missed a walker 8 studs off")
			equal(noticed("Mochimiau:grass3", 15, "sprint", 160), true, "missed a sprinter 15 studs off")
		end)

		case("V6-D1: a hunting Mochimiau keeps a player who slips into the grass for 3 s, then searches and never strikes", function()
			local e = Enc.new("Mochimiau", "Mochimiau:grass4", 77, 0, { x = 0, y = 0, z = 0 })
			local w = fakeWorld()
			local t = 0
			for _ = 1, 80 do
				t += 0.05
				Enc.step(e, t, around(e, 12, 0), w)
				if e.phase == "Chase" then break end
			end
			equal(e.phase, "Chase", "it hunts first")
			local memo, search, firstSearch, hits = {}, nil, nil, 0
			local from = t
			for _ = 1, 200 do
				t += 0.05
				-- the player keeps 15 studs ahead of it, walking in the grass
				local target = around(e, 15, 0)
				local plan = Hiding.grassPlan(e, Hiding.concealed(15, true, "walk"), e.beast, memo, t)
				if plan == "search" then
					firstSearch = firstSearch or t
					search = search or Hiding.newSearch(target.x, target.z, t, e.id)
				elseif plan == "none" then
					-- (once lost it either searches or, given up on its own, is calm: "far")
					assert(firstSearch == nil, "it saw them again at 15 studs")
				end
				-- Deliberately changed (V7-D6/V8-D1, "each creature has its zone"): this long straight run would pass the
				-- hunter's zone (80 studs) and end the hunt there; the zone is not under test, so its post follows it
				e.home.x, e.home.z = e.pos.x, e.pos.z
				for _, ev in ipairs(Enc.step(e, t, Hiding.view(target, plan, e, search, t), w)) do
					if ev.type == "Hit" or ev.type == "Afflict" or (ev.type == "Strike" and ev.hit) then hits += 1 end
				end
			end
			assert(firstSearch, "it never lost them")
			near(firstSearch - (from + 0.05), Hiding.GRASS.memorySeconds, "lost after the memory time", 0.06)
			equal(hits, 0, "never struck while concealed")
		end)
	end

	-- The wiring ----------------------------------------------------------------------------------------------------
	case("V6-D1 wiring: the beast server works out the grass from positions and shows each candy brain its view", function()
		local beasts = sources.beasts
		has(beasts, "hideLost = 0, grassLost = 0,", "the grass counter is seeded (count() errors on an unseeded key)")
		has(beasts, 'H.grassPatches(game:GetService("CollectionService"):GetTagged(H.GRASS.tag))', "the patches from their tagged models")
		has(beasts, 'H.covered(H.inGrass(world.grassPatches, x, z), player:GetAttribute("WildboundStance"))',
			"in a patch (server positions) and not sprinting")
		has(beasts, "H.concealed(Config.flat(e.pos.x, e.pos.z, target.x, target.z), true, nil)", "farther than 10 from this creature")
		has(beasts, "H.grassPlan(e, concealed == true, e.beast, entry.grass, at)", "calm: far; a hunter: memory, then search")
		has(beasts, "local pre = world.loseHunt(entry, at)", "the search's give-up is the shared one")
		has(beasts, "function world.loseHunt(entry, at)")
		has(beasts, 'count("grassLost")', "a search in the grass that runs out")
		local grassAt = beasts:find("target, pre = world.grassView(entry, target, at)", 1, true)
		assert(grassAt, "the grass view goes to the brain")
		assert(grassAt > beasts:find("target, pre = world.hideView(entry, target, at)", 1, true), "after the hide-spot view")
		assert(grassAt < beasts:find("local events = Enc.step(entry.e, at, target", 1, true), "before the brain steps")
		has(beasts, "if not pre and not (target and target.hidden) then target, pre = world.grassView(entry, target, at) end",
			"never over a hidden player's view")
		has(beasts, "if inGrass and not want.frenzy then return end", "no summon in the grass, except the frenzy's")
		has(beasts, "if inGrass then return end -- V6-D1: no ambush in the grass", "no ambush")
		has(beasts, "and not world.inCover(player, root.Position.X, root.Position.Z, at) then", "Don Glaseon never wakes for them")
	end)

	case("V6-D1 wiring: the bees and La Duquesa read the same rule, on the server", function()
		has(sources.flyers, "grassCover = grassCover(player, p.X, p.Z)", "the bees' input")
		has(sources.flyers, 'player:GetAttribute("WildboundStance")', "not sprinting")
		has(sources.duquesa, "Hiding.concealed(d, true, nil)", "farther than 10 from her")
		has(sources.duquesa, "Hiding.GRASS.memorySeconds", "her thief is kept for the memory time")
		has(sources.duquesa, 'GetTagged(Hiding.GRASS.tag)', "the patches from their tagged models")
	end)

	return result
end

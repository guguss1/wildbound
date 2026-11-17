-- Invoke with require(freshTestClone)(require(freshCandyTrapsClone), require(freshCandyTrapRulesClone),
--   require(freshCandyHideSpotsClone), require(freshCandyGrassClone), require(freshCandyHidingClone),
--   require(freshCandyLayoutClone), require(freshCandyV3LayoutClone), require(freshBeastEncountersClone),
--   require(freshBeastCandyCritterClone), require(freshBeastConfigClone), require(freshCandyNestsClone),
--   { beasts = <WildboundBeasts Source>, flyers = <WildboundCandyFlyersService Source>,
--   duquesa = <WildboundCandyDuquesaService Source>, nests = <WildboundCandyNests Source> }).
-- Caramelo v6 (odd/tasks/wildbound-caramelo-v2.md, V6-D5; V6-D40.. in docs/design/wildbound-caramelo-v3-plan.md): sticky
-- caramel traps.
--   WildboundCandyTraps lays about 8 flat caramel puddles on open ground beside the routes and near the houses, each a
--   Trap_<id> Model tagged WildboundCandyTrap with a Radius attribute, of flat non-colliding plain parts, clear of the
--   chocolate, the paths, nests, posts, houses, bridges, the v5 hide spots (the live HideSpots folder) and the v6
--   licorice grass (the live LicoriceGrass folder). Every fixture is built detached (never parented to a service).
--   WildboundCandyTrapRules: a candy creature on the ground in a puddle covers 40 % of its step while inside and for 2 s
--   after; flyers (Mielita, the bees, La Duquesa), forest beasts and players are never slowed. A real Mochimiau brain
--   chasing across a puddle, and the wiring of the beast server and the server start.
return function(Traps, Rules, Spots, Grass, Hiding, Layout, V3, Enc, Critter, Config, Nests, sources)
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
	assert(type(Traps) == "table" and type(Rules) == "table" and type(Spots) == "table" and type(Grass) == "table"
		and type(Hiding) == "table" and type(Layout) == "table" and type(V3) == "table",
		"pass Traps, the trap rules, HideSpots, Grass, Hiding, the layout and the V3 layout")
	sources = type(sources) == "table" and sources or {}

	-- A detached biome (as WildboundCandyGrass_Test builds it): the floor, the v3 mountains and houses (one colliding
	-- block each, the size of their footprint) and the live nests, all at their layout spots.
	local C = Layout.CENTRE
	local function biome()
		local root = Instance.new("Model")
		root.Name = Layout.ROOT_NAME
		local ground = Instance.new("Folder")
		ground.Name, ground.Parent = "Ground", root
		local floor = Instance.new("Part")
		floor.Name, floor.Anchored, floor.Size = "Floor", true, Vector3.new(Layout.HALF * 2, 1, Layout.HALF * 2)
		floor.Position = Vector3.new(C.x, Layout.FLOOR_TOP - 0.5, C.z)
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
	local function trapsOf(root)
		local folder = root:FindFirstChild(Traps.FOLDER)
		local list = {}
		for _, m in ipairs(folder and folder:GetChildren() or {}) do table.insert(list, m) end
		table.sort(list, function(a, b) return a.Name < b.Name end)
		return list
	end
	local function localOf(model)
		local p = model:GetPivot().Position
		return p.X - C.x, p.Z - C.z
	end
	-- the biome with its v5 hide spots and v6 grass laid first (as at server start), then the puddles
	local function laid()
		local root = biome()
		Spots.sync(root, Layout, V3, { kit = false, posts = {} })
		Grass.sync(root, Layout, V3, OPTS)
		local changed, skipped, count, parts = Traps.sync(root, Layout, V3, OPTS)
		return root, changed, skipped, count, parts
	end

	-- The rule -------------------------------------------------------------------------------------------------------
	case("V6-D5: the numbers: 40 % speed, 2 s after, the tag and radius the puddles carry", function()
		local T = Rules.TRAP
		equal(T.slow, 0.4, "40 % speed")
		equal(T.afterSeconds, 2, "for 2 s after leaving")
		equal(T.tag, Traps.TAG, "the puddles' tag is the one the rule reads")
		equal(T.radiusAttribute, "Radius", "the footprint attribute")
		equal(Rules.COMMITTED.Release, true, "a leap or roll in flight is not slowed")
		equal(Rules.COMMITTED.Jump, true, "Gomibu's jump in flight is not slowed")
		assert(Traps.TARGET >= 7 and Traps.TARGET <= 9, "about 8 puddles")
	end)

	case("V6-D5: which puddle a creature stands in comes from positions (centre and radius)", function()
		local patches = { { x = 100, z = 50, r = 6 }, { x = -40, z = 0, r = 6 } }
		equal(Rules.inTrap(patches, 100, 50), patches[1], "the centre")
		equal(Rules.inTrap(patches, 105.9, 50), patches[1], "inside the radius")
		equal(Rules.inTrap(patches, 106.2, 50), nil, "just out")
		equal(Rules.inTrap(patches, -40, 5), patches[2], "the other puddle")
		equal(Rules.inTrap(patches, 0 / 0, 5), nil, "no position, no puddle")
		equal(Rules.inTrap(nil, 0, 0), nil, "no puddles")
		local m = Instance.new("Model")
		local part = Instance.new("Part")
		part.Parent = m
		m.WorldPivot = CFrame.new(30, 0.5, -20)
		m:SetAttribute("Radius", 6)
		local bare = Instance.new("Model")
		local list = Rules.trapPatches({ m, bare, part })
		equal(#list, 1, "one usable puddle")
		near(list[1].x, 30); near(list[1].z, -20); equal(list[1].r, 6)
	end)

	case("V6-D5: who is slowed: candy creatures on the ground; never flyers, forest beasts or the bees and La Duquesa", function()
		for _, name in ipairs({ "Mochimiau", "Canelin", "Flanin", "GatoRepartidor", "Gomibu", "Flanfuria", "Tortidragon", "DonGlaseon" }) do
			equal(Rules.affects(Hiding.candy(name), Config.BEASTS[name]), true, name .. " walks: slowed")
		end
		equal(Rules.affects(Hiding.candy("Mielita"), Config.BEASTS.Mielita), false, "Mielita flies")
		equal(Config.BEASTS.Mielita.grounded, false, "Mielita is the flying critter")
		equal(Rules.affects(Hiding.candy("Viper"), Config.BEASTS.Viper), false, "a forest beast")
		-- the bees (Zumbidulces) and La Duquesa are not beast-server brains: no candy profile, no config entry
		equal(Rules.affects(Hiding.candy("Zumbidulce"), Config.BEASTS.Zumbidulce), false, "the bees")
		equal(Rules.affects(Hiding.candy("LaDuquesa"), Config.BEASTS.LaDuquesa), false, "La Duquesa")
		equal(Rules.affects(true, nil), false, "no config: not slowed")
	end)

	case("V6-D5: the sticky clock: stuck while inside and for 2 s after", function()
		local memo = {}
		equal(select(1, Rules.stuck(memo, false, 0)), false, "free before")
		local stuck, caught = Rules.stuck(memo, true, 10)
		equal(stuck, true, "inside"); equal(caught, true, "just caught")
		stuck, caught = Rules.stuck(memo, true, 10.5)
		equal(stuck, true, "still inside"); equal(caught, false, "not caught again")
		equal(select(1, Rules.stuck(memo, false, 11)), true, "0.5 s out")
		equal(select(1, Rules.stuck(memo, false, 12.45)), true, "1.95 s out")
		equal(select(1, Rules.stuck(memo, false, 12.55)), false, "past 2 s: free")
		equal(memo.untilAt, nil, "the tail ended")
		stuck, caught = Rules.stuck(memo, true, 20)
		equal(caught, true, "a new puddle catches it again")
	end)

	case("V6-D5: slowStep pulls the new spot back to 40 % of the step, only in or just after a puddle", function()
		local patches = { { x = 0, z = 0, r = 6 } }
		local e = { pos = { x = 2, y = 1, z = 0 }, phase = "Chase" }
		local memo = {}
		local slowed, caught = Rules.slowStep(e, 0, 0, 0, patches, memo, 1, "Chase")
		equal(slowed, true); equal(caught, true)
		near(e.pos.x, 0.8, "40 % of a 2-stud step"); near(e.pos.y, 0.4, "y follows"); near(e.pos.z, 0)
		-- out of the puddle, within the tail: still 40 %
		local out = { pos = { x = 12, y = 0, z = 0 }, phase = "Chase" }
		equal(select(1, Rules.slowStep(out, 10, 0, 0, patches, memo, 2.5, "Chase")), true, "in the 2 s tail")
		near(out.pos.x, 10.8)
		-- past the tail: untouched
		local free = { pos = { x = 22, y = 0, z = 0 }, phase = "Chase" }
		equal(select(1, Rules.slowStep(free, 20, 0, 0, patches, memo, 3.2, "Chase")), false, "free again")
		near(free.pos.x, 22)
		-- a step that only ends in the puddle is slowed too (it walked in)
		local enter = { pos = { x = 5, y = 0, z = 0 }, phase = "Chase" }
		equal(select(1, Rules.slowStep(enter, 7, 0, 0, patches, {}, 0, "Chase")), true, "walking in")
		near(enter.pos.x, 7 - 0.8)
		-- a committed leap or roll, or a placement, is kept
		local leap = { pos = { x = 3, y = 0, z = 0 }, phase = "Release" }
		equal(select(1, Rules.slowStep(leap, 0, 0, 0, patches, {}, 0, "Release")), false, "a leap in flight")
		near(leap.pos.x, 3)
		local landing = { pos = { x = 3, y = 0, z = 0 }, phase = "Recover" }
		equal(select(1, Rules.slowStep(landing, 0, 0, 0, patches, {}, 0, "Jump")), false, "the landing step of a jump")
		local placed = { pos = { x = 40, y = 0, z = 0 }, phase = "Chase" }
		equal(select(1, Rules.slowStep(placed, 0, 0, 0, patches, {}, 0, "Chase")), false, "a placement, not a walk")
		near(placed.pos.x, 40)
		local done = { pos = { x = 2, y = 0, z = 0 }, phase = "Ended", done = true }
		equal(select(1, Rules.slowStep(done, 0, 0, 0, patches, {}, 0, "Chase")), false, "an ended encounter")
		equal(select(1, Rules.slowStep({ pos = { x = 2, y = 0, z = 0 } }, 0 / 0, 0, 0, patches, {}, 0, "Chase")), false, "no start")
	end)

	-- The puddles ----------------------------------------------------------------------------------------------------
	case("V6-D5: the pure clearance rule (chocolate, paths, posts, hide spots, grass, the edge and the spacing)", function()
		local ctx = Traps.context(Layout, V3, Spots, {})
		equal(Traps.blocked(V3.LAKE[1].x, V3.LAKE[1].z, ctx), "liquid", "in the lake")
		assert(Traps.blocked(-150, 0, ctx) ~= nil, "on the main path")
		equal(Traps.blocked(Layout.HALF - 2, 60, ctx), "edge", "on the plot edge")
		local h = V3.HOUSES[1]
		assert(Traps.blocked(h.x, h.z, ctx) ~= nil, "inside a house")
		local n = Layout.NESTS[1]
		assert(Traps.blocked(n.x + 3, n.z, ctx) ~= nil, "beside a nest")
		local free
		for _, c in ipairs(Traps.routeCandidates(Layout)) do
			if Traps.blocked(c.x, c.z, ctx) == nil then free = c break end
		end
		assert(free, "no clear try at all")
		local withPost = Traps.context(Layout, V3, Spots, { posts = { { x = free.x + 3, z = free.z } } })
		equal(Traps.blocked(free.x, free.z, withPost), "post", "beside a creature post")
		local withHide = Traps.context(Layout, V3, Spots, { hides = { { x = free.x + 3, z = free.z } } })
		equal(Traps.blocked(free.x, free.z, withHide), "hide", "beside a v5 hide spot")
		local withGrass = Traps.context(Layout, V3, Spots, { grass = { { x = free.x + 15, z = free.z, r = 9 } } })
		equal(Traps.blocked(free.x, free.z, withGrass), "grass", "beside a licorice patch")
		table.insert(ctx.traps, { x = free.x + 10, z = free.z })
		equal(Traps.blocked(free.x, free.z, ctx), "spacing", "too near another puddle")
	end)

	case("V6-D5: sync lays about 8 flat non-colliding puddles beside the routes and near the houses, clear of everything", function()
		local root, changed, skipped, count, parts = laid()
		local list = trapsOf(root)
		equal(count, #list, "laid count")
		assert(#list >= 5 and #list <= Traps.TARGET, "about 8 puddles, got " .. #list .. " (" .. table.concat(skipped, ",") .. ")")
		equal(changed, #list, "each new puddle is a change")
		equal(parts, #list * Traps.PARTS, "the part count")
		local R = Traps.RADIUS
		local hides, grass = {}, {}
		for _, m in ipairs(root[Spots.FOLDER]:GetChildren()) do
			local x, z = localOf(m)
			table.insert(hides, { x = x, z = z, name = m.Name })
		end
		for _, m in ipairs(root[Grass.FOLDER]:GetChildren()) do
			local x, z = localOf(m)
			table.insert(grass, { x = x, z = z, r = m:GetAttribute("Radius"), name = m.Name })
		end
		assert(#hides >= 10, "the v5 hide spots were laid first")
		assert(#grass >= 1, "the v6 grass was laid first")
		local seen, houseNear = {}, 0
		for i, m in ipairs(list) do
			assert(m:IsA("Model") and m.Name:match("^Trap_[HR]%d+$"), "a Trap_<id> model: " .. m.Name)
			assert(not seen[m.Name], "a unique name"); seen[m.Name] = true
			assert(CollectionService:HasTag(m, Traps.TAG), m.Name .. " is tagged")
			equal(m:GetAttribute("Radius"), R, m.Name .. " radius")
			equal(m:GetAttribute("TrapId"), m.Name:sub(6), m.Name .. " id")
			equal(m:GetAttribute("CandyTrap"), true, m.Name .. " marked")
			equal(#m:GetChildren(), Traps.PARTS, m.Name .. " parts")
			if m.Name:match("^Trap_H") then houseNear += 1 end
			local pivot = m:GetPivot().Position
			near(pivot.Y, Layout.FLOOR_TOP, m.Name .. " on the floor", 1e-3)
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					assert(d.Anchored and not d.CanCollide and not d.CanQuery and not d.CanTouch and not d.CastShadow,
						d:GetFullName() .. " must be an anchored ghost")
					assert(d.Position.Y - pivot.Y < 0.6, "flat: " .. d:GetFullName())
					assert(d.Position.Y > pivot.Y, "over the floor: " .. d:GetFullName())
					local reach = math.max(d.Size.Y, d.Size.Z) / 2
					if d.Shape == Enum.PartType.Ball then reach = d.Size.X / 2 end
					assert(flat(d.Position.X, d.Position.Z, pivot.X, pivot.Z) + reach <= R + 1e-3, "a part outside the footprint: " .. d:GetFullName())
				end
			end
			local x, z = localOf(m)
			assert(V3.liquidDistance(x, z) >= R + Traps.LIQUID_MARGIN - 1e-6, m.Name .. " too near the chocolate")
			assert(Layout.routeDistance(x, z) >= Layout.PATH_WIDTH / 2 + Traps.ROUTE_MARGIN + R - 1e-6, m.Name .. " on a path")
			for _, n in ipairs(Layout.NESTS) do
				assert(flat(x, z, n.x, n.z) >= R + Traps.NEST_CLEAR - 1e-6, m.Name .. " beside nest " .. n.id)
			end
			for _, h in ipairs(V3.HOUSES) do
				assert(flat(x, z, h.x, h.z) >= h.r + R, m.Name .. " in house " .. h.id)
			end
			for _, h in ipairs(hides) do
				assert(flat(x, z, h.x, h.z) >= R + Traps.HIDE_CLEAR - 1e-6, m.Name .. " beside hide spot " .. h.name)
			end
			for _, g in ipairs(grass) do
				assert(flat(x, z, g.x, g.z) >= R + g.r + Traps.GRASS_MARGIN - 1e-6, m.Name .. " in the grass " .. g.name)
			end
			assert(not V3.nearBridge(x, z, R), m.Name .. " on a bridge")
			for j = i + 1, #list do
				local ox, oz = localOf(list[j])
				assert(flat(x, z, ox, oz) >= Traps.SPACING - 1e-6, m.Name .. " too near " .. list[j].Name)
			end
		end
		assert(houseNear >= 1 and houseNear <= Traps.MAX_HOUSE, "some near the houses (" .. houseNear .. ")")
		-- the rule reads the laid puddles: a creature at a puddle's centre is in it, one just past its edge is not
		local patches = Rules.trapPatches(list)
		equal(#patches, #list, "every puddle readable")
		local p = list[1]:GetPivot().Position
		assert(Rules.inTrap(patches, p.X, p.Z), "in the puddle at the centre")
		equal(Rules.inTrap(patches, p.X + R + 0.5, p.Z), nil, "out past the edge")
	end)

	case("V6-D5: sync is idempotent, removes a puddle under a solid, and lays none in the chocolate", function()
		local root = laid()
		local before = #trapsOf(root)
		local again, _, count = Traps.sync(root, Layout, V3, OPTS)
		equal(again, 0, "nothing changes on a second start")
		equal(count, before); equal(#trapsOf(root), before, "no duplicate")
		local first = trapsOf(root)[1]
		local where = first:GetPivot().Position
		local name = first.Name
		local rock = Instance.new("Part")
		rock.Name, rock.Anchored, rock.CanCollide = "Rock", true, true
		rock.Size, rock.Position = Vector3.new(6, 6, 6), where + Vector3.new(0, 3, 0)
		rock.Parent = root
		Traps.sync(root, Layout, V3, OPTS)
		local now = root[Traps.FOLDER]:FindFirstChild(name)
		assert(not now or (now:GetPivot().Position - where).Magnitude > 3, "a puddle was left under a solid rock")
		local flooded = setmetatable({ liquidDistance = function() return -1 end }, { __index = V3 })
		local _, _, left = Traps.sync(root, Layout, flooded, OPTS)
		equal(left, 0, "no puddle in the chocolate")
		equal(#trapsOf(root), 0, "none left")
	end)

	case("V6-D5: nothing without the v3 biome; applyFlags lays the traps after the grass (guarded, a seventh value)", function()
		local bare = Instance.new("Model")
		local changed, skipped, count = Traps.sync(bare, Layout, V3, OPTS)
		equal(changed, 0); equal(count, 0); equal(#skipped, 0)
		equal(select(1, Traps.sync(nil, Layout, V3, OPTS)), 0, "no root: nothing, no error")
		local nests = sources.nests
		has(nests, 'FindFirstChild("WildboundCandyTraps")', "the module is looked up in ServerStorage (no wait)")
		has(nests, "pcall(T.sync, root, Layout)", "guarded")
		assert(nests:find("pcall(T.sync, root, Layout)", 1, true) > nests:find("pcall(G.sync, root, Layout)", 1, true),
			"after the grass (it keeps off it)")
		has(nests, "okTraps and tonumber(traps) or 0", "a seventh value: the puddles changed")
		if type(Nests) == "table" then
			local root = Instance.new("Model")
			local fakeBuilder = { syncNests = function() return 0 end, syncPortal = function() return 0 end }
			local fake = { sync = function(r, L) assert(r == root and L == Layout, "the root and layout") return 5 end }
			equal(select(7, Nests.applyFlags(root, fakeBuilder, Layout, false, false, false, fake)), 5, "the seventh value")
			equal(select(7, Nests.applyFlags(root, fakeBuilder, Layout, false, false, false, false)), 0, "false: none")
			equal(select(7, Nests.applyFlags(root, fakeBuilder, Layout, false, false, false, { sync = function() error("boom") end })), 0,
				"an error is contained")
		end
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
		-- a still player `d` studs ahead of the creature along +x (out of its leap range: it only runs)
		local function ahead(e, d)
			return { x = e.pos.x + d, y = 3, z = e.pos.z, vx = 0, vz = 0, alive = true, safe = false, walk = 16 }
		end
		-- a Mochimiau noticing a player and chasing it along +x for `steps`, the server's post-step applied with
		-- `patches` (a function of where the chase started); returns the per-step lengths, whether each step was slowed,
		-- the times, and the ground covered
		local function chase(id, userId, patchesAt, steps)
			local e = Enc.new("Mochimiau", id, userId, 0, { x = 0, y = 0, z = 0 })
			local w = fakeWorld()
			local t = 0
			for _ = 1, 80 do
				t += 0.05
				Enc.step(e, t, ahead(e, 12), w)
				if e.phase == "Chase" then break end
			end
			equal(e.phase, "Chase", "it hunts first")
			local startX, startZ = e.pos.x, e.pos.z
			local patches = patchesAt(startX, startZ)
			local memo, lengths, slowed, times = {}, {}, {}, {}
			for i = 1, steps do
				t += 0.05
				local px, py, pz, phase = e.pos.x, e.pos.y, e.pos.z, e.phase
				Enc.step(e, t, ahead(e, 30), w)
				slowed[i] = Rules.slowStep(e, px, py, pz, patches, memo, t, phase)
				lengths[i] = flat(px, pz, e.pos.x, e.pos.z)
				times[i] = t
				equal(e.phase, "Chase", "it keeps running (step " .. i .. ")")
			end
			return lengths, slowed, times, flat(startX, startZ, e.pos.x, e.pos.z)
		end

		case("V6-D5: a Mochimiau chasing across a puddle covers less ground: 40 % inside and for 2 s after", function()
			local STEPS = 120
			local freeLengths, _, _, freeGround = chase("Mochimiau:trap1", 9101, function() return {} end, STEPS)
			local lengths, slowed, times, ground = chase("Mochimiau:trap2", 9102, function(x, z)
				return { { x = x + 15, z = z, r = 6 } }
			end, STEPS)
			assert(ground < freeGround - 15, ("covered %.1f against %.1f free"):format(ground, freeGround))
			local first, last, inside = nil, nil, 0
			for i = 1, STEPS do
				if slowed[i] then
					first = first or i
					last = i
					inside += 1
					near(lengths[i], freeLengths[i] * Rules.TRAP.slow, "step " .. i .. " at 40 %", 1e-3)
				elseif first then
					near(lengths[i], freeLengths[i], "step " .. i .. " free again", 1e-3)
				end
			end
			assert(first and last, "it was never slowed")
			-- slowed from walking in until about 2 s after the last step in the puddle
			local slowFor = times[last] - times[first]
			assert(slowFor >= Rules.TRAP.afterSeconds, ("slowed only %.2f s"):format(slowFor))
			assert(last < STEPS, "free again before the end")
			for i = first, last do equal(slowed[i], true, "no gap while stuck (step " .. i .. ")") end
		end)
	end

	-- The wiring ----------------------------------------------------------------------------------------------------
	case("V6-D5 wiring: the beast server slows a candy creature on the ground after each brain step", function()
		local beasts = sources.beasts
		has(beasts, "grassLost = 0, trapped = 0 }", "the trap counter is seeded (count() errors on an unseeded key)")
		has(beasts, 'local module = script.Parent:FindFirstChild("WildboundCandyTrapRules")', "no wait: a missing module changes nothing")
		has(beasts, "R.affects(world.hiding.candy(e.beast), Config.BEASTS[e.beast])", "candy and grounded only")
		has(beasts, "world.traps = R.trapPatches(CollectionService:GetTagged(R.TRAP.tag))", "the puddles from their tagged models")
		has(beasts, "local _, caught = R.slowStep(e, px, py, pz, world.traps, entry.trap, at, phase)", "the pure post-step")
		has(beasts, 'if caught then count("trapped") end', "telemetry once per catch")
		local startAt = beasts:find("local py, phase = entry.e.pos and entry.e.pos.y, entry.e.phase", 1, true)
		local stepAt = beasts:find("local events = Enc.step(entry.e, at, target", 1, true)
		local slowAt = beasts:find("world.trapSlow(entry, px, py, pz, phase, at) -- V6-D5", 1, true)
		local keepAt = beasts:find("world.keepOut(entry.e, px, pz, at) -- V4-D12", 1, true)
		assert(startAt and stepAt and slowAt and keepAt, "the step's start, the brain, the slow and the house refuge")
		assert(startAt < stepAt, "the start is read before the brain steps")
		assert(slowAt > stepAt and slowAt < keepAt, "after the brain, before the house refuge (which stays the last word)")
	end)

	case("V6-D5 wiring: players are never slowed; the bees and La Duquesa never read the traps", function()
		local beasts = sources.beasts
		local from = beasts:find("function world.trapSlow(", 1, true)
		assert(from, "world.trapSlow")
		local to = beasts:find("\nend[\r\n]", from)
		assert(to, "the end of world.trapSlow")
		local body = beasts:sub(from, to)
		for _, word in ipairs({ "WalkSpeed", "player", "Humanoid", "applySlow", "SetAttribute" }) do
			assert(not body:find(word, 1, true), "the trap step touches a player: " .. word)
		end
		assert(not tostring(sources.flyers):find("WildboundCandyTrap", 1, true), "the bees are not slowed")
		assert(not tostring(sources.duquesa):find("WildboundCandyTrap", 1, true), "La Duquesa is not slowed")
	end)

	return result
end

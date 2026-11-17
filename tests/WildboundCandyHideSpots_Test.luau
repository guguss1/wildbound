-- Invoke with require(freshTestClone)(require(freshCandyHideSpotsClone), require(freshCandyHidingClone),
--   require(freshHideClone), require(freshCandyLayoutClone), require(freshCandyV3LayoutClone),
--   require(freshBeastEncountersClone), require(freshBeastConfigClone), require(freshBeastCandyCritterClone),
--   require(freshBeastDonGlaseonClone), { beasts = <WildboundBeasts Source>, flyers = <WildboundCandyFlyersService Source>,
--   duquesa = <WildboundCandyDuquesaService Source>, world = <WildboundWorld Source>, nests = <WildboundCandyNests Source> }).
-- Caramelo v5 (odd/tasks/wildbound-caramelo-v2.md, V5-D1 and V5-D2): hiding places in the candy kingdom and candy
-- creatures that respect them.
--   V5-D1: WildboundCandyHideSpots lays about 14 hide spots in Candy_Bioma_v1 (a hollow at the foot of each ice-cream
--   mountain, on the side facing the play area, plus cotton-candy bushes and hollow cake stumps by the houses and the
--   routes), each a HideSpot_H<nn> Model tagged WildboundHideSpot with a HideZone part and its ProximityPrompt (the shape
--   WildboundWorld binds), clear of the chocolate (read from the layout at sync time), the paths, nests, posts, houses
--   and bridges. Every fixture is built detached (never parented to a service); no kit is used (kit = false).
--   V5-D2: WildboundCandyHiding's pure rules (what a candy creature sees of a hidden player, the search round the spot,
--   discovery by WildboundHide's own rule), two real brains stepped with them, and the wiring of the beast server, the
--   bees, La Duquesa and the world script (the HideFound report).
return function(Spots, Hiding, Hide, Layout, V3, Enc, Config, Critter, Boss, sources)
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
	local function lacks(source, needle, label)
		assert(type(source) == "string" and not string.find(source, needle, 1, true), (label or "present") .. ": " .. needle)
	end
	local function flat(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
	assert(type(Spots) == "table" and type(Hiding) == "table" and type(Hide) == "table" and type(Layout) == "table"
		and type(V3) == "table", "pass HideSpots, Hiding, Hide, the layout and the V3 layout")
	sources = type(sources) == "table" and sources or {}

	-- A detached biome: the floor, the v3 mountains and houses (one colliding block each, the size of their footprint,
	-- attributes as V3Builder sets them) and the live nests (Layout.NESTS as plain models), all at their layout spots.
	local C = Layout.CENTRE
	local function biome(opts)
		opts = opts or {}
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
			local x, z = C.x + m.x + ((opts.shift and opts.shift[m.id]) or 0), C.z + m.z
			block.Name, block.Anchored = "Collision_Body", true
			block.Size = Vector3.new(m.r * 1.4, m.height, m.r * 1.4)
			block.Position = Vector3.new(x, Layout.FLOOR_TOP + m.height / 2, z)
			block.Parent = model
			model.WorldPivot = CFrame.new(x, Layout.FLOOR_TOP, z)
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
	local OPTS = { kit = false, posts = {} }
	local function spotsOf(root)
		local folder = root:FindFirstChild(Spots.FOLDER)
		local list = {}
		for _, m in ipairs(folder and folder:GetChildren() or {}) do table.insert(list, m) end
		table.sort(list, function(a, b) return a.Name < b.Name end)
		return list
	end
	local function localOf(model)
		local p = model:GetPivot().Position
		return p.X - C.x, p.Z - C.z
	end

	-- V5-D1 ---------------------------------------------------------------------------------------------------------
	case("V5-D1: spot ids never meet the forest's (H01-H10) and match WildboundWorld's name pattern", function()
		for kind, first in pairs(Spots.ID) do
			assert(first >= 50, kind .. " ids start at " .. first)
			local id = Spots.spotId(kind, 1)
			assert(("HideSpot_" .. id):match("^HideSpot_(H%d+)$") == id, "not a WildboundWorld spot name: " .. id)
		end
		equal(Spots.spotId("cave", 1), "H51", "M1's cave")
		equal(Spots.spotId("house", 7), "H67", "H7's spot")
		equal(Spots.TAG, "WildboundHideSpot", "the world script's tag")
	end)

	case("V5-D1: the pure clearance rule (chocolate, paths, nests, posts, houses, bridges, the edge and the spacing)", function()
		local ctx = Spots.context(Layout, V3, { posts = { { x = 100, z = 100 } } })
		equal(Spots.blocked(V3.LAKE[1].x, V3.LAKE[1].z, ctx), "liquid", "in the lake")
		-- just past the margin from the river's band is fine as far as the chocolate goes
		local reason = Spots.blocked(0, 0, ctx)
		assert(reason ~= nil, "the junction is never a spot")
		equal(Spots.blocked(-150, 0, ctx), "route", "on the main path")
		local n
		for _, row in ipairs(Layout.NESTS) do if row.id == "C5" then n = row end end
		assert(n, "nest C5 (north, away from the paths)")
		equal(Spots.blocked(n.x + 3, n.z + 3, ctx), "nest", "beside nest " .. n.id)
		equal(Spots.blocked(103, 103, ctx), "post", "beside a creature post")
		local h = V3.HOUSES[1]
		assert(Spots.blocked(h.x, h.z, ctx) ~= nil, "inside a house")
		local B = V3.BRIDGES[1]
		assert(Spots.blocked(B.x, B.z, ctx) ~= nil, "on a bridge")
		equal(Spots.blocked(Layout.HALF - 2, 60, ctx), "edge", "on the plot edge")
		-- a free spot north-west, and the spacing rule against a spot already laid
		local fx, fz = -158.6, -54.6
		equal(Spots.blocked(fx, fz, ctx), nil, "an open spot by house H5")
		table.insert(ctx.spots, { x = fx + 10, z = fz })
		equal(Spots.blocked(fx, fz, ctx), "spacing", "too near another spot")
	end)

	case("V5-D1: the chocolate margin is read from the layout at sync time (a wider river moves the spots)", function()
		local ctx = Spots.context(Layout, V3, {})
		-- every laid spot keeps LIQUID_MARGIN past its reach from the chocolate of the layout it was given
		local wider = setmetatable({ liquidDistance = function(x, z) return V3.liquidDistance(x, z) - 8 end }, { __index = V3 })
		local wide = Spots.context(Layout, wider, {})
		local x, z = nil, nil
		for d = 0, 80 do
			-- a point that is clear for the old river and not for one 8 studs wider
			local px, pz = 34 + d * 0.5, 60
			if V3.liquidDistance(px, pz) >= Spots.LIQUID_MARGIN + Spots.REACH
				and wider.liquidDistance(px, pz) < Spots.LIQUID_MARGIN + Spots.REACH then x, z = px, pz break end
		end
		assert(x, "no test point beside the river")
		assert(Spots.blocked(x, z, ctx) ~= "liquid", "clear of today's river")
		equal(Spots.blocked(x, z, wide), "liquid", "blocked by the wider river")
		assert(Spots.LIQUID_MARGIN >= 6, "at least 6 studs off the chocolate")
	end)

	case("V5-D1: a cave faces the play area first, then turns round its mountain", function()
		local m = { id = "M3", x = 76, z = 187, r = 13.1 }
		local list = Spots.caveCandidates(m)
		assert(#list >= 10, "a few turns and gaps")
		local first = list[1]
		local ux, uz = -m.x / flat(m.x, m.z, 0, 0), -m.z / flat(m.x, m.z, 0, 0)
		local dx, dz = (first.x - m.x) / flat(first.x, first.z, m.x, m.z), (first.z - m.z) / flat(first.x, first.z, m.x, m.z)
		near(dx * ux + dz * uz, 1, "the first try looks at the plot centre", 1e-6)
		for _, c in ipairs(list) do
			assert(flat(c.x, c.z, m.x, m.z) >= m.r + Spots.REACH, "a cave's zone stands off the mountain by its reach")
		end
	end)

	case("V5-D1: sync lays about 14 spots in the live biome, each the shape WildboundWorld binds", function()
		local root = biome()
		local changed, skipped, laid = Spots.sync(root, Layout, V3, OPTS)
		local list = spotsOf(root)
		equal(laid, #list, "laid count")
		assert(#list >= 12 and #list <= Spots.TARGET, "about 14 spots, got " .. #list .. " (skipped " .. table.concat(skipped, ",") .. ")")
		equal(changed, #list, "each new spot is a change")
		local caves, seen = 0, {}
		for _, m in ipairs(list) do
			local id = m.Name:match("^HideSpot_(H%d+)$")
			assert(id and not seen[id], "a unique spot name: " .. m.Name)
			seen[id] = true
			assert(m:IsA("Model"), "a Model")
			assert(CollectionService:HasTag(m, Spots.TAG), m.Name .. " is tagged")
			local zone = m:FindFirstChild("HideZone")
			assert(zone and zone:IsA("BasePart"), m.Name .. " has a HideZone part")
			assert(zone.Anchored and not zone.CanCollide and zone.Transparency == 1, "the zone is an invisible anchored ghost")
			local prompt = zone:FindFirstChildOfClass("ProximityPrompt")
			assert(prompt, m.Name .. " has its prompt on the zone")
			equal(prompt.RequiresLineOfSight, false, "prompt line of sight")
			equal(m.PrimaryPart, zone, "the zone is the pivot part")
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then assert(not d.CanCollide, d:GetFullName() .. " collides (a player steps out 5.5 studs away)") end
			end
			if m:GetAttribute("Kind") == "cave" then caves += 1 end
			-- clear of the chocolate, the paths and every nest by the margins
			local x, z = localOf(m)
			assert(V3.liquidDistance(x, z) >= Spots.LIQUID_MARGIN + Spots.REACH - 1e-6, m.Name .. " too near the chocolate")
			assert(Layout.routeDistance(x, z) >= Layout.PATH_WIDTH / 2 + Spots.ROUTE_MARGIN + Spots.REACH - 1e-6, m.Name .. " on a path")
			for _, n in ipairs(Layout.NESTS) do
				assert(flat(x, z, n.x, n.z) >= Spots.NEST_CLEAR + Spots.REACH - 1e-6, m.Name .. " beside nest " .. n.id)
			end
			for _, h in ipairs(V3.HOUSES) do
				assert(flat(x, z, h.x, h.z) >= h.r + Spots.REACH, m.Name .. " in house " .. h.id)
			end
			assert(not V3.nearBridge(x, z, Spots.REACH), m.Name .. " on a bridge")
		end
		equal(caves, #V3.MOUNTAINS, "one hollow at the foot of each ice-cream mountain")
		-- a cave stands on the side of its mountain that faces the plot centre (within a right angle and a bit)
		for _, m in ipairs(V3.MOUNTAINS) do
			local spot = root[Spots.FOLDER]:FindFirstChild("HideSpot_" .. Spots.spotId("cave", tonumber(m.id:sub(2))))
			assert(spot, "no cave for " .. m.id)
			local x, z = localOf(spot)
			local toCentre = (-m.x * (x - m.x) - m.z * (z - m.z)) / (flat(m.x, m.z, 0, 0) * flat(x, z, m.x, m.z))
			assert(toCentre > -0.2, m.id .. "'s cave faces away from the play area")
		end
	end)

	case("V5-D1: sync is idempotent, follows a moved mountain and removes a spot that became blocked", function()
		local root = biome()
		Spots.sync(root, Layout, V3, OPTS)
		local before = #spotsOf(root)
		local again = Spots.sync(root, Layout, V3, OPTS)
		equal(again, 0, "nothing changes on a second start")
		equal(#spotsOf(root), before, "no duplicate")
		-- M2 moved 6 studs east: its cave (straight towards the plot centre) follows
		local cave = root[Spots.FOLDER]:FindFirstChild("HideSpot_H52")
		assert(cave, "M2's cave")
		local x0 = localOf(cave)
		local mountain = root[V3.FOLDER].Mountains.Mountain_M2
		mountain:PivotTo(mountain:GetPivot() * CFrame.new(6, 0, 0))
		local moved = Spots.sync(root, Layout, V3, OPTS)
		assert(moved >= 1, "the cave moved")
		near(localOf(root[Spots.FOLDER].HideSpot_H52) - x0, 6, "with its mountain", 0.6)
		-- a solid block dropped on a spot: that spot goes (the next candidate of its mountain may take its place)
		local spot = root[Spots.FOLDER]:FindFirstChild("HideSpot_H53")
		local where = spot:GetPivot().Position
		local rock = Instance.new("Part")
		rock.Name, rock.Anchored, rock.CanCollide = "Rock", true, true
		rock.Size, rock.Position = Vector3.new(6, 6, 6), where + Vector3.new(0, 3, 0)
		rock.Parent = root
		Spots.sync(root, Layout, V3, OPTS)
		local now = root[Spots.FOLDER]:FindFirstChild("HideSpot_H53")
		assert(not now or (now:GetPivot().Position - where).Magnitude > 3, "a spot was left under a solid rock")
	end)

	case("V5-D1: nothing without the v3 biome, and applyFlags lays the spots at server start (guarded)", function()
		local bare = Instance.new("Model")
		local changed, skipped, laid = Spots.sync(bare, Layout, V3, OPTS)
		equal(changed, 0); equal(laid, 0); equal(#skipped, 0)
		equal(select(1, Spots.sync(nil, Layout, V3, OPTS)), 0, "no root: nothing, no error")
		local nests = sources.nests
		has(nests, 'FindFirstChild("WildboundCandyHideSpots")', "the module is looked up in ServerStorage (no wait)")
		has(nests, "pcall(S.sync, root, Layout)", "guarded")
		assert(nests:find("pcall(S.sync, root, Layout)", 1, true) > nests:find("pcall(H.sync, root, Layout)", 1, true),
			"after the house nests (it keeps off them)")
	end)

	-- V5-D2: the pure rules ----------------------------------------------------------------------------------------
	case("V5-D2: what a candy creature makes of a hidden player (plan)", function()
		equal(Hiding.hidden(nil), false); equal(Hiding.hidden("H51"), true); equal(Hiding.hidden(""), false)
		equal(Hiding.plan({ phase = "Chase" }, false, "Mochimiau"), "none", "not hidden")
		equal(Hiding.plan({ phase = "Chase" }, true, "Viper"), "none", "not a candy creature")
		equal(Hiding.plan({ phase = "Patrol" }, true, "Mochimiau"), "far", "a calm creature never acquires")
		equal(Hiding.plan({ phase = "Calm" }, true, "Gomibu"), "far")
		equal(Hiding.plan({ phase = "Notice" }, true, "Mochimiau"), "search", "called by the frenzy: it searches")
		equal(Hiding.plan({ phase = "Chase" }, true, "Tortidragon"), "search", "a hunter loses the player and searches")
		equal(Hiding.plan({ phase = "Telegraph" }, true, "Canelin"), "search")
		equal(Hiding.plan({ phase = "Return" }, true, "Mochimiau"), "far", "walking home")
		equal(Hiding.plan({ phase = "Chase" }, true, "DonGlaseon"), "under", "the boss searches by his own rule")
	end)

	case("V5-D2: the search walks round the spot, a point every holdSeconds, and ends after its seconds", function()
		local S = Hiding.SEARCH
		local s = Hiding.newSearch(100, -50, 10, "enc:1")
		local seen = {}
		local t = 10
		while not Hiding.expired(s, t) do
			local x, z = Hiding.searchPoint(s, t)
			local d = flat(x, z, 100, -50)
			assert(d >= S.ringMin - 1e-6 and d <= S.ringMax + 1e-6, ("a point %.1f studs from the spot"):format(d))
			seen[("%.2f,%.2f"):format(x, z)] = true
			local x2, z2 = Hiding.searchPoint(s, t)
			equal(x2, x, "deterministic")
			t += 0.25
		end
		near(t - 10, S.seconds, "it gives up after its seconds", 0.26)
		local count = 0
		for _ in pairs(seen) do count += 1 end
		assert(count >= math.floor(S.seconds / S.holdSeconds) - 1, "several points round the spot: " .. count)
		-- V5-D6: the walk from one point to the next never crosses the discover radius round the spot
		local radius = Hide.CONFIG.DISCOVER.Day.radius
		for i = 0, 5 do
			local ax, az = Hiding.searchPoint(s, 10 + i * S.holdSeconds)
			local bx, bz = Hiding.searchPoint(s, 10 + (i + 1) * S.holdSeconds)
			for k = 0, 20 do
				local x, z = ax + (bx - ax) * k / 20, az + (bz - az) * k / 20
				assert(flat(x, z, 100, -50) > radius + 1, ("the walk from point %d crosses the spot (%.1f)"):format(i, flat(x, z, 100, -50)))
			end
		end
		local other = Hiding.newSearch(100, -50, 10, "enc:2")
		local ax = Hiding.searchPoint(s, 10)
		local bx = Hiding.searchPoint(other, 10)
		assert(ax ~= bx, "two hunters search different sides")
	end)

	case("V5-D2: the views: far from every sight, the search point lifted out of reach, the boss's under the floor", function()
		local target = { x = 5, y = 3, z = 7, vx = 12, vz = 0, alive = true, safe = false, walk = 16 }
		local e = { home = { x = 0, y = 0, z = 0 }, pos = { x = 2, y = 0, z = 2 } }
		local far = Hiding.view(target, "far", e, nil, 0)
		assert(flat(far.x, far.z, e.home.x, e.home.z) >= Hiding.FAR_STUDS, "far beyond its home")
		equal(far.alive, true); equal(far.safe, false); equal(far.vx, 0); equal(far.hidden, true)
		equal(target.x, 5, "the real target is never changed")
		local s = Hiding.newSearch(5, 7, 0, "e")
		local sx, sz = Hiding.searchPoint(s, 0)
		local v = Hiding.view(target, "search", e, s, 0)
		equal(v.x, sx); equal(v.z, sz); equal(v.walk, 16, "chases at its usual pace")
		assert(v.y - target.y >= 20, "lifted out of every strike's reach")
		local u = Hiding.view(target, "under", e, nil, 0)
		equal(u.x, 5); assert(target.y - u.y >= 20, "under the floor: no line of sight"); equal(u.vx, 0, "no noise")
		equal(Hiding.view(target, "none", e, nil, 0), target, "not hidden: the real target")
	end)

	case("V5-D2: discovery is WildboundHide's own rule (radius and dwell of the place's phase)", function()
		local rule = Hide.CONFIG.DISCOVER.Day
		local w = Hiding.newWatch()
		local found, t = false, 0
		while t < rule.dwell * 2 + 2 and not found do
			t += 0.05
			found = Hiding.finds(w, 0.05, rule.radius - 0.5, "Day")
		end
		assert(found, "never found standing inside the radius")
		-- V5-D6: FIND_SLOWER times the hide rule's dwell
		assert(Hiding.FIND_SLOWER >= 2, "a crowd must not find a hidden player at once")
		near(t, rule.dwell * Hiding.FIND_SLOWER, "after the slowed dwell time", 0.06)
		assert(Hiding.SEARCH.ringMin > rule.radius + 2, "the search ring keeps the hunters out of the discover radius")
		local w2 = Hiding.newWatch()
		for _ = 1, 200 do assert(not Hiding.finds(w2, 0.05, rule.radius + 0.5, "Day"), "found from outside the radius") end
		-- the numbers are WildboundHide's (tuning them there tunes the candy creatures too)
		equal(Hiding.Hide.CONFIG.DISCOVER.Day.radius, rule.radius, "WildboundHide's radius")
		equal(Hiding.Hide.CONFIG.DISCOVER.Day.dwell, rule.dwell, "WildboundHide's dwell")
	end)

	-- V5-D2: two real brains ----------------------------------------------------------------------------------------
	if type(Enc) == "table" and type(Config) == "table" and type(Critter) == "table" and type(Boss) == "table" then
		for _, name in ipairs({ "Mochimiau", "Canelin", "Flanin", "Mielita", "GatoRepartidor" }) do Enc.register(name, Critter) end
		Enc.register("DonGlaseon", Boss)
		local function fakeWorld(extra)
			local w = {}
			function w.ground() return 0 end
			function w.site() return nil end
			function w.telegraph() return true end
			function w.resolve() return "Hit" end
			function w.cancel() end
			function w.claimStrike() return true end
			function w.castLane() return nil end
			function w.safe() return false end
			for k, v in pairs(extra or {}) do w[k] = v end
			return w
		end
		local function real(x, z) return { x = x, y = 3, z = z, vx = 0, vz = 0, alive = true, safe = false, walk = 16 } end

		case("V5-D2: a calm Mochimiau never notices a hidden player standing beside it", function()
			local e = Enc.new("Mochimiau", "Mochimiau:hide1", 77, 0, { x = 0, y = 0, z = 0 })
			local w = fakeWorld()
			local t = 0
			for _ = 1, 100 do
				t += 0.05
				local v = Hiding.view(real(3, 0), Hiding.plan(e, true, e.beast), e, nil, t)
				for _, ev in ipairs(Enc.step(e, t, v, w)) do
					assert(not (ev.type == "Phase" and ev.phase == "Notice"), "it noticed a hidden player")
				end
			end
		end)

		case("V5-D2: a hunting Mochimiau loses a player who hides, searches round the spot and never strikes them", function()
			local e = Enc.new("Mochimiau", "Mochimiau:hide2", 77, 0, { x = 0, y = 0, z = 0 })
			local w = fakeWorld()
			local t = 0
			for _ = 1, 80 do
				t += 0.05
				Enc.step(e, t, real(12, 0), w)
				if e.phase == "Chase" then break end
			end
			equal(e.phase, "Chase", "it hunts first")
			local search, hits, near0 = nil, 0, math.huge
			for _ = 1, 200 do
				t += 0.05
				local plan = Hiding.plan(e, true, e.beast)
				if plan == "search" then search = search or Hiding.newSearch(12, 0, t, e.id) end
				local v = Hiding.view(real(12, 0), plan, e, search, t)
				for _, ev in ipairs(Enc.step(e, t, v, w)) do
					if ev.type == "Hit" or ev.type == "Afflict" or (ev.type == "Strike" and ev.hit) then hits += 1 end
				end
				near0 = math.min(near0, flat(e.pos.x, e.pos.z, 12, 0))
			end
			equal(hits, 0, "never struck while hidden")
			assert(search, "it searched")
			assert(near0 <= Hiding.SEARCH.ringMax + 4, ("it searched round the spot (closest %.1f)"):format(near0))
		end)

		case("V5-D2: Don Glaseon loses a hidden thief, searches where he last saw them, and goes home (Lost)", function()
			local e = Enc.new("DonGlaseon", "DonGlaseon:hide", 77, 0, { x = 0, y = 0, z = 0 })
			-- his eyes: a clear line unless the target is under the floor
			local w = fakeWorld({ lineOfSight = function(_, target) return target.y > -10 end })
			local t, chased = 0, false
			for _ = 1, 400 do
				t += 0.05
				Enc.step(e, t, real(10, 0), w)
				if e.phase == "Chase" then chased = true break end
			end
			assert(chased, "he chases first (phase " .. tostring(e.phase) .. ")")
			local searched, lost = false, false
			for _ = 1, 600 do
				t += 0.05
				local v = Hiding.view(real(10, 0), Hiding.plan(e, true, e.beast), e, nil, t)
				for _, ev in ipairs(Enc.step(e, t, v, w)) do
					if ev.type == "Phase" and ev.phase == "Search" then searched = true end
					if ev.type == "Phase" and ev.phase == "LoseTarget" and ev.reason == "Lost" then lost = true end
					assert(ev.type ~= "Hit", "struck while hidden")
				end
				if lost then break end
			end
			assert(searched, "he searched"); assert(lost, "he gave up (Lost)")
		end)
	end

	-- V5-D2: the wiring ---------------------------------------------------------------------------------------------
	case("V5-D2 wiring: the beast server shows each candy brain its view of a hidden player and reports a find", function()
		local beasts = sources.beasts
		has(beasts, "target, pre = world.hideView(entry, target, at) -- V5-D2", "before the brain steps")
		assert(beasts:find("world.hideView(entry, target, at)", 1, true) < beasts:find("local events = Enc.step(entry.e, at, target", 1, true),
			"the view goes to the brain")
		has(beasts, 'player:GetAttribute("WildboundHidden")', "the world script's hidden attribute")
		has(beasts, "world.hiding.finds(", "discovery by the hide rule")
		has(beasts, 'network:FindFirstChild("HideFound")', "a find goes to the world script")
		has(beasts, ":Fire(player, e.pos.x, e.pos.z)", "with where the finder stands")
		has(beasts, "world.hiding.plan(e, true, e.beast)", "only the candy creatures (the plan knows them)")
		-- count() adds to counts[key]: an unseeded key errors and ends the encounter (seen in Play 2026-11-17)
		-- (V6-D1 seeds grassLost after them on the same line)
		has(beasts, "sheltered = 0, hidden = 0, hideFound = 0, hideLost = 0,", "the new counters are seeded")
		-- V6-D1: the search's give-up is shared with the grass (world.loseHunt), still counted here
		has(beasts, "function world.loseHunt(entry, at)", "a search's give-up is shared")
		has(beasts, "local pre = world.loseHunt(entry, at)", "a hidden player's search ends through it")
		local _, guards = beasts:gsub('if world.hiddenNow%(entry.player%) then count%("hidden"%) return end', "")
		equal(guards, 2, "no hit and no affliction on a hidden player")
		has(beasts, 'count("hideLost")', "a search that runs out")
		has(beasts, "if hidden and not want.frenzy then return end", "no summon for a hidden player, except the frenzy's")
		has(beasts, "if hidden then return end -- V5-D2: no ambush on a hidden player", "no ambush")
		has(beasts, "and not world.hiddenNow(player)", "Don Glaseon never wakes for a hidden player")
	end)

	case("V5-D2 wiring: the bees give up on a hidden player like on a house; La Duquesa searches; the world script finds", function()
		has(sources.flyers, 'hidden = player:GetAttribute("WildboundHidden") ~= nil', "the bees' input")
		local duquesa = sources.duquesa
		has(duquesa, 'require(ServerScriptService:WaitForChild("WildboundCandyHiding"))', "the shared rules")
		has(duquesa, "Hiding.searchPoint(hideSearch, now)", "her thief's place is the search point")
		has(duquesa, "Hiding.finds(", "she finds by the hide rule")
		has(duquesa, 'FindFirstChild("HideFound")', "and reports it")
		local world = sources.world
		has(world, 'hideFound.Name = "HideFound"', "the world script owns the report")
		has(world, 'releaseHide(player, "found", workspace:GetServerTimeNow(), x, z)', "found as by La Silueta")
		has(world, "local function releaseHide(player, reason, now, fromX, fromZ)", "pulled out on the finder's side")
	end)

	return result
end

-- Invoke with require(freshTestClone)(require(freshCandyHouseNestsClone), require(freshCandyNestsClone),
--   require(freshCandyLayoutClone), require(freshCandyV3KitSpecClone), require(freshCandyV3LayoutClone),
--   { nests = <WildboundCandyNests Source> }).
-- Caramelo v4 (odd/tasks/wildbound-caramelo-v2.md, V4-D8, owner request 2026-11-17 "eggs inside the houses"): one egg
-- nest inside each Caramelo v3 house, laid from the live houses (pivot, kit, scale) at a per-kit interior floor spot
-- clear of the kit's colliders, read by the existing nest pipeline as a one-egg island nest that no creature post
-- binds. Every fixture is built detached (never parented to a service); the kit is a fake that records its calls.
return function(HouseNests, Nests, Layout, KitSpec, V3, sources)
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
	assert(type(HouseNests) == "table" and type(Nests) == "table" and type(Layout) == "table" and type(KitSpec) == "table"
		and type(V3) == "table", "pass HouseNests, Nests, Layout, the V3 kit spec and the V3 layout")

	-- The kit's colliders of `asset` at `scale` round `pivot`, the way WildboundCandyV3Builder's applySpec lays them.
	local function specBoxes(asset, pivot, scale)
		local list = {}
		for _, c in ipairs(KitSpec[asset].colliders) do
			local cf = pivot * CFrame.new(Vector3.new(c.pos[1], c.pos[2], c.pos[3]) * scale)
				* CFrame.fromOrientation(math.rad(c.orient[1]), math.rad(c.orient[2]), math.rad(c.orient[3]))
			local size = Vector3.new(c.size[1], c.size[2], c.size[3]) * scale
			if c.shape == "cylinder" then cf *= CFrame.Angles(0, 0, math.rad(90)) end
			table.insert(list, { name = c.name, cframe = cf, size = size })
		end
		return list
	end
	-- A detached house model: its spec colliders as Collision_ parts, attributes as V3Builder sets them.
	local function house(id, asset, scale, x, z, yaw)
		local m = Instance.new("Model")
		m.Name = "House_" .. id
		local pivot = CFrame.new(x, Layout.FLOOR_TOP, z) * CFrame.Angles(0, yaw or 0, 0)
		for _, box in ipairs(specBoxes(asset, pivot, scale)) do
			local p = Instance.new("Part")
			p.Name, p.Size, p.CFrame, p.Anchored, p.CanCollide = box.name, box.size, box.cframe, true, true
			p.Parent = m
		end
		m.WorldPivot = pivot
		m:SetAttribute("HouseId", id)
		m:SetAttribute("KitAsset", asset)
		m:SetAttribute("KitScale", scale)
		m:SetAttribute("Interior", true)
		m:SetAttribute("Placeholder", false)
		return m
	end
	local function biome()
		local root = Instance.new("Model")
		root.Name = Nests.ROOT_NAME
		local nests = Instance.new("Folder")
		nests.Name, nests.Parent = "Nests", root
		local v3 = Instance.new("Folder")
		v3.Name, v3.Parent = "CaramelV3", root
		local houses = Instance.new("Folder")
		houses.Name, houses.Parent = "Houses", v3
		return root, nests, houses
	end
	-- The fake kit: the Nest prefab as a bowl (Collision_Bowl, the kit's 5.3 x 2.2 cylinder at `scale`) and a ring.
	local function fakeKit()
		local placed = {}
		local kit = { LIBRARY_NAME = "CandyKit", place = function(library, name, cframe, scale)
			table.insert(placed, { library = library, name = name, scale = scale, cframe = cframe })
			local model = Instance.new("Model")
			local bowl = Instance.new("Part")
			bowl.Name, bowl.Shape, bowl.Anchored = "Collision_Bowl", Enum.PartType.Cylinder, true
			bowl.Size = Vector3.new(2.2, 5.3, 5.3) * scale
			bowl.CFrame = CFrame.new(0, 1.1 * scale, 0) * CFrame.Angles(0, 0, math.rad(90))
			bowl.Parent = model
			local ring = Instance.new("Part")
			ring.Name, ring.Anchored, ring.Parent = "RarityRing", true, model
			model.WorldPivot = CFrame.new()
			model:PivotTo(cframe)
			return model
		end }
		return kit, placed
	end
	-- Inside the walls, at kit scale 1 (kit units): the sweet house's room (|x| <= 12, |z| <= 10), the chocolate house's
	-- and the tower's octagons (inner wall radius 10.78; the tower's upper storey 8.33).
	local INSIDE = {
		CV3_SweetHouse = function(x, z, r) return math.abs(x) + r <= 12 and math.abs(z) + r <= 10 end,
		CV3_ChocoHouse = function(x, z, r) return math.sqrt(x * x + z * z) + r <= 10.78 end,
		CV3_CaramelTower = function(x, z, r) return math.sqrt(x * x + z * z) + r <= 8.33 end,
	}

	case("V4-D8: one spot per house kit, every v3 house has one; mostly Rara, one Epica (the big tower), no Legendaria", function()
		local count = { Comun = 0, Rara = 0, Epica = 0, Legendaria = 0 }
		local layoutIds = {}
		for _, spec in ipairs(Layout.NESTS) do layoutIds[spec.id] = true end
		layoutIds[Layout.TOWER.summit.id] = true
		for _, h in ipairs(V3.HOUSES) do
			assert(HouseNests.SPOTS[h.asset], h.id .. ": no spot for " .. h.asset)
			local id = HouseNests.nestId(h.id)
			assert(type(id) == "string" and not layoutIds[id], h.id .. ": nest id " .. tostring(id) .. " clashes with a layout nest")
			local rarity = HouseNests.rarity(h.id)
			assert(Nests.pick(rarity), h.id .. ": unknown rarity " .. tostring(rarity))
			count[rarity] += 1
		end
		equal(count.Epica, 1, "one Epica"); equal(count.Legendaria, 0, "no Legendaria")
		assert(count.Rara > #V3.HOUSES / 2, "mostly Rara: " .. count.Rara)
		equal(HouseNests.rarity("H5"), "Epica", "the big caramel tower (V4-D5)")
		equal(HouseNests.SPOTS.CV3_CaramelTower.floor, "upper", "the tower's egg is upstairs")
		near(HouseNests.NEST_SCALE, 0.8, "the nest at 80 %")
	end)

	case("V4-D8: each spot stands on the kit's floor, inside the walls, clear of every collider, at scale 1 and 1.4, any yaw", function()
		for asset, S in pairs(HouseNests.SPOTS) do
			assert(KitSpec[asset], "no kit spec for " .. asset)
			assert(INSIDE[asset](S.x, S.z, HouseNests.FOOTPRINT_STUDS), asset .. ": the nest pokes out of the room")
			for _, scale in ipairs({ 1, 1.4 }) do
				for _, yaw in ipairs({ 0, 0.7, math.pi, -2.1 }) do
					local pivot = CFrame.new(140, Layout.FLOOR_TOP, -60) * CFrame.Angles(0, yaw, 0)
					local boxes = specBoxes(asset, pivot, scale)
					local at = HouseNests.spot(pivot, asset, scale)
					local label = ("%s at %g, yaw %g"):format(asset, scale, yaw)
					equal(HouseNests.blocked(at, boxes), nil, label .. " blocked by")
					local top = HouseNests.floorTop(at, boxes)
					assert(top, label .. ": no floor under the nest")
					near(top, at.Position.Y, label .. " floor", 0.01)
					near(at.Position.Y, Layout.FLOOR_TOP + S.y * scale, label .. " height")
					local l = pivot:PointToObjectSpace(at.Position)
					near(l.X, S.x * scale, label .. " x"); near(l.Z, S.z * scale, label .. " z")
				end
			end
		end
		-- the clearance test bites: on the sweet house's table, or on the tower's ground floor beside the stair
		local pivot = CFrame.new(0, Layout.FLOOR_TOP, 0)
		local sweet = specBoxes("CV3_SweetHouse", pivot, 1)
		assert(HouseNests.blocked(pivot * CFrame.new(-4, 0.6, 2), sweet), "a nest on the table is not blocked")
		local tower = specBoxes("CV3_CaramelTower", pivot, 1)
		assert(HouseNests.blocked(pivot * CFrame.new(-7.8, 0.6, 0), tower), "the tower's ground ring fits a nest")
		equal(HouseNests.floorTop(pivot * CFrame.new(0, 30, 60), tower), nil, "no floor in the air")
		equal(HouseNests.spot(pivot, "CV3_Unknown", 1), nil, "no spot for another kit")
	end)

	case("V4-D8: sync lays one nest per live house at its spot, live and tagged; idempotent; follows a moved house", function()
		local root, folder, houses = biome()
		local h1 = house("H1", "CV3_SweetHouse", 1.4, -60, 160)
		local h5 = house("H5", "CV3_CaramelTower", 1.4, -80, 76, 2.4)
		local h6 = house("H6", "CV3_ChocoHouse", 1, 70, -176, -0.6)
		for _, m in ipairs({ h1, h5, h6 }) do m.Parent = houses end
		local placeholder = house("H2", "CV3_CaramelTower", 1, -20, 178)
		placeholder:SetAttribute("Placeholder", true)
		placeholder.Parent = houses
		local kit, placed = fakeKit()
		local library = Instance.new("Folder")
		local changed, skipped = HouseNests.sync(root, Layout, kit, library)
		equal(changed, 3, "three nests laid"); equal(#skipped, 0, "nothing skipped")
		equal(#placed, 3, "three prefabs")
		for _, p in ipairs(placed) do
			equal(p.name, "Nest", "the kit's Nest"); equal(p.library, library, "the library")
			near(p.scale, HouseNests.NEST_SCALE, "at NEST_SCALE")
		end
		equal(folder:FindFirstChild("Nest_H2"), nil, "a placeholder house gets no nest")
		for _, m in ipairs({ h1, h5, h6 }) do
			local id = m:GetAttribute("HouseId")
			local nest = folder:FindFirstChild("Nest_" .. id)
			assert(nest, id .. ": no nest")
			local at = HouseNests.spot(m:GetPivot(), m:GetAttribute("KitAsset"), m:GetAttribute("KitScale"))
			near((nest:GetPivot().Position - at.Position).Magnitude, 0, id .. " at its spot")
			equal(nest:GetAttribute("NestId"), id); equal(nest:GetAttribute("Rarity"), HouseNests.rarity(id), id .. " rarity")
			equal(nest:GetAttribute("Enabled"), Layout.NESTS_ENABLED == true, id .. " live")
			equal(nest:GetAttribute("EventOnly"), false); equal(nest:GetAttribute("Candidate"), true)
			equal(nest:GetAttribute("House"), true); equal(nest:GetAttribute("HouseId"), id)
			assert(CollectionService:HasTag(nest, "WildboundCandyNestCandidate"), id .. " tag")
			equal(nest.PrimaryPart and nest.PrimaryPart.Name, "Collision_Bowl", id .. " bowl")
			-- never outside its house: within the room, on the house floor's height
			local l = m:GetPivot():PointToObjectSpace(nest:GetPivot().Position) / m:GetAttribute("KitScale")
			assert(INSIDE[m:GetAttribute("KitAsset")](l.X, l.Z, 0), id .. " outside its house")
		end
		near(folder.Nest_H5:GetPivot().Position.Y, Layout.FLOOR_TOP + 16.6 * 1.4, "H5's nest on the tower's upper floor")
		local again = HouseNests.sync(root, Layout, kit, library)
		equal(again, 0, "a second sync changes nothing"); equal(#placed, 3, "and places nothing")
		-- the v4 migration moves a house: its nest follows on the next server start
		h6:PivotTo(h6:GetPivot() * CFrame.new(20, 0, 0))
		equal(HouseNests.sync(root, Layout, kit, library), 1, "the moved house's nest")
		local at = HouseNests.spot(h6:GetPivot(), "CV3_ChocoHouse", 1)
		near((folder.Nest_H6:GetPivot().Position - at.Position).Magnitude, 0, "H6's nest followed its house")
		-- the layout's nest flag
		equal(HouseNests.sync(root, { NESTS_ENABLED = false }, kit, library), 3, "the flag off")
		equal(folder.Nest_H1:GetAttribute("Enabled"), false)
		HouseNests.sync(root, Layout, kit, library)
		-- a house whose spot is taken by something solid is skipped, never a nest inside it
		local h7 = house("H7", "CV3_SweetHouse", 1, 20, 172)
		local junk = Instance.new("Part")
		junk.Name, junk.Size, junk.Anchored = "Barrel", Vector3.new(3, 3, 3), true
		junk.CFrame = HouseNests.spot(h7:GetPivot(), "CV3_SweetHouse", 1) * CFrame.new(0, 1.5, 0)
		junk.Parent = h7
		h7.Parent = houses
		local n7, skipped7 = HouseNests.sync(root, Layout, kit, library)
		equal(n7, 0, "a blocked spot lays nothing"); equal(skipped7[1], "H7", "and reports it")
		equal(folder:FindFirstChild("Nest_H7"), nil, "no nest in the barrel")
		-- no kit, no Nests folder, no houses: nothing, no error
		local bare, bareFolder, bareHouses = biome()
		house("H4", "CV3_SweetHouse", 1, 0, 0).Parent = bareHouses
		local none, missing = HouseNests.sync(bare, Layout, { LIBRARY_NAME = "CandyKit", place = function() error("no prefab") end }, library)
		equal(none, 0, "a kit that fails lays nothing"); equal(missing[1], "H4")
		equal(#bareFolder:GetChildren(), 0)
		equal(select(1, HouseNests.sync(nil, Layout, kit, library)), 0, "no biome")
		equal(select(1, HouseNests.sync(Instance.new("Model"), Layout, kit, library)), 0, "no Nests folder")
		root:Destroy(); bare:Destroy(); library:Destroy()
	end)

	case("V4-D8: the house nests are read as live markers with their bowl's height, become island nests, and no post binds them", function()
		local root, _, houses = biome()
		local h3 = house("H3", "CV3_ChocoHouse", 1.4, -100, -100)
		local h2 = house("H2", "CV3_CaramelTower", 1, -60, 178, 1)
		h3.Parent, h2.Parent = houses, houses
		local kit = fakeKit()
		equal(HouseNests.sync(root, Layout, kit, Instance.new("Folder")), 2)
		local read = Nests.read(root)
		equal(#read, 2, "two markers")
		local byId = {}
		for _, m in ipairs(read) do byId[m.id] = m end
		for id, m in pairs(byId) do
			local houseModel = id == "H3" and h3 or h2
			local at = HouseNests.spot(houseModel:GetPivot(), houseModel:GetAttribute("KitAsset"), houseModel:GetAttribute("KitScale"))
			equal(m.house, true, id .. " a house nest"); equal(m.enabled, Layout.NESTS_ENABLED == true, id .. " enabled")
			near(m.x, at.Position.X, id .. " x", 0.01); near(m.z, at.Position.Z, id .. " z", 0.01)
			near(m.top, at.Position.Y + 2.2 * HouseNests.NEST_SCALE, id .. " the bowl's top", 0.01)
		end
		-- a post standing right beside a house nest does not bind it; a floor nest beside the same post still is
		local posts = { { name = "Gomibu", x = byId.H3.x + 2, z = byId.H3.z } }
		local markers = table.clone(read)
		table.insert(markers, { id = "C1", rarity = "Comun", x = byId.H3.x + 9, z = byId.H3.z, top = 2.7, enabled = true })
		local binding = Nests.bind(markers, posts)
		equal(binding.H3, nil, "no guardian for a house nest"); equal(binding.C1, "Gomibu", "the floor nest keeps it")
		if Layout.NESTS_ENABLED == true then
			local list = Nests.islands(read, posts)
			equal(#list, 2, "two island nests")
			for _, entry in ipairs(list) do
				equal(entry.id, "Candy" .. entry.nestId); equal(entry.eggs, 1, entry.id .. " one egg")
				equal(entry.guard, nil, entry.id .. " unguarded")
				equal(entry.species, Nests.pick(entry.rarity).species, entry.id .. " species")
				assert(entry.nestTop and entry.nestTop > Layout.FLOOR_TOP, entry.id .. " egg height from its bowl")
			end
			local merged = Nests.merge({ islands = { { id = "I1" } } }, read, posts)
			equal(#merged.islands, 3, "merged after the others")
		end
		root:Destroy()
	end)

	case("V4-D8 wiring: applyFlags lays the house nests (guarded) before the nests are read", function()
		local calls = {}
		local fakeBuilder = { syncNests = function() return 0 end, syncPortal = function() return 0 end }
		local fake = { sync = function(r, L) table.insert(calls, { r = r, L = L }); return 2 end }
		local root = Instance.new("Model")
		local _, _, _, laid = Nests.applyFlags(root, fakeBuilder, Layout, fake)
		equal(laid, 2, "the fourth value: house nests changed"); equal(#calls, 1); equal(calls[1].r, root); equal(calls[1].L, Layout)
		local _, _, _, off = Nests.applyFlags(root, fakeBuilder, Layout, false)
		equal(off, 0, "false: no house nests"); equal(#calls, 1)
		local _, _, _, broken = Nests.applyFlags(root, fakeBuilder, Layout, { sync = function() error("boom") end })
		equal(broken, 0, "a failing step changes nothing else")
		root:Destroy()
		local src = sources.nests
		has(src, 'FindFirstChild("WildboundCandyHouseNests")', "looks the module up without waiting")
		has(src, "pcall(H.sync, root, Layout)", "guarded")
		assert(src:find("pcall(H.sync, root, Layout)", 1, true) > src:find("pcall(Builder.syncTower, root, Layout)", 1, true),
			"after the tower step")
		has(src, 'house = nest:GetAttribute("House") == true', "read marks house nests")
		has(src, "and m.house ~= true then", "bind skips them")
	end)

	return result
end

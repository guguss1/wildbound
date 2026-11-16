-- Invoke with require(freshTestClone)(require(freshMapModeSwitchClone), require(freshBig4AnnexClone),
-- require(freshBiomesClone), require(freshBiomeLightClone), require(freshCandyLayoutClone), require(freshPortalClone)).
-- Big4 map experiment (odd/tasks/wildbound-big4-map.md): the never-destroy switch between the classic map and the four
-- larger biomes, and the big4 geometry plan (scaled clones, annex slabs, seeded scatter, roads to the moved gates).
-- Its switch cases run on unparented stand-in folders, never on Workspace or ServerStorage.
return function(Switch, Annex, Biomes, BiomeLight, Layout, Portal)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got "
			.. tostring(actual))
	end
	local function near(actual, expected, label)
		assert(type(actual) == "number" and math.abs(actual - expected) < 1e-6,
			(label or "") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function square(list, tag)
		for _, area in ipairs(list) do
			if area.tag == tag and (area.kind == nil or area.kind == "square") then return area end
		end
		return nil
	end
	local function same(a, b, label)
		assert(a and b, label .. ": missing")
		for _, k in ipairs({ "minX", "maxX", "minZ", "maxZ" }) do near(a[k], b[k], label .. " " .. k) end
	end

	-- The five roots the big4 builder makes (WildboundBig4Annex); the switch refuses big4 without all of them.
	local BIG4_ROOTS = { "WildboundFrozenMountains_Big4", "WildboundVolcanicLands_Big4", "WildboundForestOuter_Big4",
		"WildboundCandyAnnex_Big4", "WildboundBig4Roads", "WildboundBig4Ground" }

	-- A stand-in Workspace with every classic-only path, two shared road slabs and a kept root; a stand-in ServerStorage
	-- with the five big4 roots already archived.
	local function fixture()
		local ws, storage = Instance.new("Folder"), Instance.new("Folder")
		ws.Name, storage.Name = "FakeWorkspace", "FakeServerStorage"
		local positions = {}
		local function ensure(path)
			local node = ws
			local parts = string.split(path, "/")
			for index = 1, #parts - 1 do
				local child = node:FindFirstChild(parts[index])
				if not child then
					child = Instance.new(index == 1 and "Model" or "Folder")
					child.Name = parts[index]
					child.Parent = node
				end
				node = child
			end
			return node, parts[#parts]
		end
		for index, path in ipairs(Switch.CLASSIC_ONLY) do
			local parent, leaf = ensure(path)
			local item
			if parent == ws then
				item = Instance.new("Model")
				local part = Instance.new("Part")
				part.Name = "Floor"
				part.Position = Vector3.new(index * 10, 0, -index * 10)
				part.Parent = item
			else
				item = Instance.new("Part")
				item.Position = Vector3.new(index * 10, 0.56, index * 7)
			end
			item.Name = leaf
			item.Parent = parent
			positions[path] = index
		end
		for _, path in ipairs({ "WildboundOpenWorldRoads/living-forest/Road_living-forest_1",
			"WildboundOpenWorldRoads/cryptic-ruins/Road_cryptic-ruins_1", "WildboundOpenWorldRoads/Gates/Gate_forest" }) do
			local parent, leaf = ensure(path)
			local part = Instance.new("Part")
			part.Name = leaf
			part.Parent = parent
		end
		local kept = Instance.new("Model")
		kept.Name = "Candy_Bioma_v1"
		kept.Parent = ws
		local archive = Instance.new("Folder")
		archive.Name = Switch.ARCHIVE
		archive.Parent = storage
		local big4 = Instance.new("Folder")
		big4.Name = Switch.BIG4_FOLDER
		big4.Parent = archive
		for _, name in ipairs(BIG4_ROOTS) do
			local root = Instance.new("Model")
			root.Name = name
			root:SetAttribute(Switch.ROOT_ATTRIBUTE, "big4")
			local part = Instance.new("Part")
			part.Position = Vector3.new(1, 2, 3)
			part.Parent = root
			root.Parent = big4
		end
		return ws, storage, { root = ws, storage = storage, running = false, history = false }
	end

	local function find(root, path)
		local node = root
		for _, name in ipairs(string.split(path, "/")) do node = node and node:FindFirstChild(name) end
		return node
	end

	case("BIG4 switch: a bad mode, Play or a lock refuses and changes nothing", function()
		local ws, storage, env = fixture()
		equal(pcall(Switch.apply, "huge", env), false, "bad mode")
		equal(pcall(Switch.apply, nil, env), false, "no mode")
		equal(pcall(Switch.apply, "big4", { root = ws, storage = storage, running = true, history = false }), false, "Play")
		storage:SetAttribute("WildboundPlayLock", "someone")
		equal(pcall(Switch.apply, "big4", env), false, "the Play lock")
		storage:SetAttribute("WildboundPlayLock", nil)
		storage:SetAttribute("WildboundImportLock", "someone")
		equal(pcall(Switch.apply, "big4", env), false, "the import lock")
		equal(ws:GetAttribute(Switch.ATTRIBUTE), nil, "mode untouched")
		assert(ws:FindFirstChild("WildboundRockCaves"), "nothing moved")
		ws:Destroy(); storage:Destroy()
	end)

	case("BIG4 switch: big4 archives every classic-only path, brings the big4 roots in, and keeps the shared slabs", function()
		local ws, storage, env = fixture()
		local cavesFloor = ws.WildboundRockCaves.Floor
		local before = cavesFloor.Position
		local report = Switch.apply("big4", env)
		equal(report.mode, "big4"); equal(#report.missing, 0, "nothing missing")
		equal(report.moved, #Switch.CLASSIC_ONLY + #BIG4_ROOTS, "every classic-only item and every big4 root")
		equal(ws:GetAttribute(Switch.ATTRIBUTE), "big4", "the replicated mode attribute")
		local classic = storage[Switch.ARCHIVE][Switch.CLASSIC_FOLDER]
		for _, path in ipairs(Switch.CLASSIC_ONLY) do
			equal(find(ws, path), nil, path .. " left Workspace")
			local leaf = string.split(path, "/")
			assert(classic:FindFirstChild(leaf[#leaf]), path .. " archived")
		end
		assert(find(ws, "WildboundOpenWorldRoads/living-forest/Road_living-forest_1"), "the N trunk slab stays")
		assert(find(ws, "WildboundOpenWorldRoads/cryptic-ruins/Road_cryptic-ruins_1"), "the S trunk slab stays")
		assert(find(ws, "WildboundOpenWorldRoads/Gates/Gate_forest"), "the forest gate marker stays")
		assert(ws:FindFirstChild("Candy_Bioma_v1"), "kept roots are never moved")
		assert(ws:FindFirstChild("WildboundFrozenMountains_Big4") and ws:FindFirstChild("WildboundBig4Roads"), "big4 roots in")
		equal(cavesFloor.Parent.Parent, classic, "the archived model is moved whole")
		equal(cavesFloor.Position, before, "never moved in space")
		local again = Switch.apply("big4", env)
		equal(again.moved, 0, "a second big4 apply moves nothing"); equal(#again.missing, 0)
		local status = Switch.status(env)
		equal(status.mode, "big4"); equal(status.classicInPlace, 0); equal(status.classicArchived, #Switch.CLASSIC_ONLY)
		equal(status.big4InPlace, #BIG4_ROOTS); equal(status.big4Archived, 0)
		ws:Destroy(); storage:Destroy()
	end)

	case("BIG4 switch: classic brings back exactly the classic tree and clears the attribute", function()
		local ws, storage, env = fixture()
		local function snapshot()
			local lines = {}
			for _, d in ipairs(ws:GetDescendants()) do
				local line = d:GetFullName():sub(#ws:GetFullName() + 2)
				if d:IsA("BasePart") then line ..= " " .. tostring(d.Position) end
				table.insert(lines, line)
			end
			table.sort(lines)
			return table.concat(lines, "\n")
		end
		local original = snapshot()
		Switch.apply("big4", env)
		assert(snapshot() ~= original, "big4 changes the tree")
		local report = Switch.apply("classic", env)
		equal(report.mode, "classic"); equal(#report.missing, 0)
		equal(report.moved, #Switch.CLASSIC_ONLY + #BIG4_ROOTS)
		equal(ws:GetAttribute(Switch.ATTRIBUTE), nil, "absent, as the place was")
		equal(snapshot(), original, "the same names, parents and positions")
		equal(#storage[Switch.ARCHIVE][Switch.BIG4_FOLDER]:GetChildren(), #BIG4_ROOTS, "big4 roots back in the archive")
		equal(#storage[Switch.ARCHIVE][Switch.CLASSIC_FOLDER]:GetChildren(), 0, "the classic archive is empty again")
		Switch.apply("big4", env); Switch.apply("classic", env)
		equal(snapshot(), original, "a second round trip too")
		equal(Switch.status(env).mode, "classic")
		ws:Destroy(); storage:Destroy()
	end)

	-- Counts what sits where, to prove a refused apply changed nothing.
	local function layout(ws, storage)
		local archive = storage:FindFirstChild(Switch.ARCHIVE)
		local classic = archive and archive:FindFirstChild(Switch.CLASSIC_FOLDER)
		local big4 = archive and archive:FindFirstChild(Switch.BIG4_FOLDER)
		local inPlace = 0
		for _, path in ipairs(Switch.CLASSIC_ONLY) do
			if find(ws, path) then inPlace += 1 end
		end
		local rootsIn = 0
		for _, child in ipairs(ws:GetChildren()) do
			if child:GetAttribute(Switch.ROOT_ATTRIBUTE) == "big4" then rootsIn += 1 end
		end
		return ("mode=%s classicIn=%d classicArchived=%d big4In=%d big4Archived=%d"):format(
			tostring(ws:GetAttribute(Switch.ATTRIBUTE)), inPlace, classic and #classic:GetChildren() or 0, rootsIn,
			big4 and #big4:GetChildren() or 0)
	end

	case("BIG4 switch: the expected big4 roots are the six the builder makes", function()
		assert(type(Switch.BIG4_ROOTS) == "table", "Switch.BIG4_ROOTS is a list")
		equal(#Switch.BIG4_ROOTS, #BIG4_ROOTS, "six roots")
		for index, name in ipairs(BIG4_ROOTS) do equal(Switch.BIG4_ROOTS[index], name, "root " .. index) end
		equal(Switch.BIG4_ROOTS[1], Annex.SCALED[1].name); equal(Switch.BIG4_ROOTS[2], Annex.SCALED[2].name)
		equal(Switch.BIG4_ROOTS[5], Annex.ROADS_NAME)
		equal(Switch.BIG4_ROOTS[6], Annex.GROUND and Annex.GROUND.name, "the ground cover root")
	end)

	-- The ground cover (WildboundBig4Ground): big flat visual-only slabs over the grey baseplate, a meadow everywhere
	-- and a themed apron around each big4 biome, all under the biome floors and roads (their tops are at 0.5 or more).
	case("BIG4 ground: a meadow covers the whole baseplate and a themed apron rings each big4 biome", function()
		assert(Annex.GROUND and type(Annex.groundSlabs) == "function", "Annex.GROUND and Annex.groundSlabs")
		local base = Annex.GROUND.baseplate
		same(base, { minX = -1024, maxX = 1024, minZ = -1024, maxZ = 1024 }, "baseplate")
		local slabs = Annex.groundSlabs()
		assert(#slabs >= 5 and #slabs <= 8, "a handful of big slabs, got " .. #slabs)
		same(slabs[1].rect, base, "the meadow covers the baseplate")
		local function clip(r, margin)
			return { minX = math.max(base.minX, r.minX - margin), maxX = math.min(base.maxX, r.maxX + margin),
				minZ = math.max(base.minZ, r.minZ - margin), maxZ = math.min(base.maxZ, r.maxZ + margin) }
		end
		local forest = table.clone(Annex.FOREST.floors); table.insert(forest, Annex.FOREST.kept)
		local candy = table.clone(Annex.CANDY.floors); table.insert(candy, Annex.CANDY.kept)
		local expected = {
			{ "Apron_Forest", Annex.bounds(forest), Enum.Material.Grass },
			{ "Apron_Volcanic", Annex.scaledSquare(Annex.SCALED[2]), Enum.Material.Basalt },
			{ "Apron_Frozen", Annex.scaledSquare(Annex.SCALED[1]), Enum.Material.Snow },
			{ "Apron_Candy", Annex.bounds(candy), Enum.Material.SmoothPlastic },
		}
		local byName, tops = {}, {}
		for _, s in ipairs(slabs) do
			byName[s.name] = s
			assert(s.top > 0.1 and s.top <= 0.45, s.name .. " top under the floors and roads: " .. s.top)
			assert(not tops[s.top], s.name .. " shares a top height (z-fighting)")
			tops[s.top] = true
			assert(s.rect.minX >= base.minX and s.rect.maxX <= base.maxX and s.rect.minZ >= base.minZ
				and s.rect.maxZ <= base.maxZ, s.name .. " inside the baseplate")
			local h, sat, v = s.color:ToHSV()
			assert(sat >= 0.1 or v >= 0.88, s.name .. " is not grey")
		end
		for _, e in ipairs(expected) do
			local s = byName[e[1]]
			assert(s, e[1] .. " missing")
			same(s.rect, clip(e[2], Annex.GROUND.margin), e[1] .. " rect")
			equal(s.material, e[3], e[1] .. " material")
		end
		equal(byName.Meadow and byName.Meadow.material, Enum.Material.Grass, "meadow grass")
		assert(byName.Apron_Candy.color.G < byName.Apron_Candy.color.R, "candy apron is pink")
		assert(Annex.GROUND.margin >= 16 and Annex.GROUND.margin <= 40, "apron margin")
		assert(type(Annex.buildGround) == "function", "Annex.buildGround")
	end)

	case("BIG4 candy: fluffCandyAnnex fluffs each cotton tree prop once through the kit and counts the blobs", function()
		assert(type(Annex.fluffCandyAnnex) == "function", "Annex.fluffCandyAnnex")
		local root = Instance.new("Model")
		local props = Instance.new("Folder")
		props.Name = "Props"
		props.Parent = root
		for _, name in ipairs({ "TreeCotton_S_B4_1", "TreeCookie_B4_2", "TreeCotton_L_B4_3", "RockSugar_B4_4" }) do
			local m = Instance.new("Model")
			m.Name = name
			m.Parent = props
		end
		local seen = {}
		local kit = { fluff = function(model) table.insert(seen, model.Name) return 5 end }
		equal(Annex.fluffCandyAnnex(root, kit), 10, "blobs added")
		equal(#seen, 2, "only cotton trees")
		equal(seen[1] == "TreeCotton_S_B4_1" or seen[2] == "TreeCotton_S_B4_1", true, "the small cotton tree")
	end)

	case("BIG4 switch: big4 with no big4 roots anywhere refuses and keeps every classic biome in place", function()
		local ws, storage, env = fixture()
		for _, root in ipairs(storage[Switch.ARCHIVE][Switch.BIG4_FOLDER]:GetChildren()) do root:Destroy() end
		local before = layout(ws, storage)
		local ok, problem = pcall(Switch.apply, "big4", env)
		equal(ok, false, "refused")
		assert(string.find(tostring(problem), "big4 roots", 1, true), "says why: " .. tostring(problem))
		equal(layout(ws, storage), before, "nothing moved")
		assert(ws:FindFirstChild("WildboundLivingForest") and ws:FindFirstChild("WildboundRockCaves"), "biomes stay")
		ws:Destroy(); storage:Destroy()
	end)

	case("BIG4 switch: big4 with one of the five roots missing refuses, names it and changes nothing", function()
		local ws, storage, env = fixture()
		storage[Switch.ARCHIVE][Switch.BIG4_FOLDER].WildboundCandyAnnex_Big4:Destroy()
		-- A same-named model in Workspace without the MapMode tag does not count as a big4 root.
		local impostor = Instance.new("Model")
		impostor.Name = "WildboundCandyAnnex_Big4"
		impostor.Parent = ws
		local before = layout(ws, storage)
		local ok, problem = pcall(Switch.apply, "big4", env)
		equal(ok, false, "refused")
		assert(string.find(tostring(problem), "WildboundCandyAnnex_Big4", 1, true), "names the root: " .. tostring(problem))
		equal(layout(ws, storage), before, "nothing moved")
		ws:Destroy(); storage:Destroy()
	end)

	case("BIG4 switch: big4 counts roots already in Workspace as available", function()
		local ws, storage, env = fixture()
		local big4 = storage[Switch.ARCHIVE][Switch.BIG4_FOLDER]
		big4.WildboundFrozenMountains_Big4.Parent = ws
		big4.WildboundBig4Roads.Parent = ws
		local report = Switch.apply("big4", env)
		equal(report.moved, #Switch.CLASSIC_ONLY + #BIG4_ROOTS - 2, "the archived roots and every classic item")
		equal(Switch.status(env).big4InPlace, #BIG4_ROOTS)
		ws:Destroy(); storage:Destroy()
	end)

	case("BIG4 switch: an item gone from both places is reported by big4, and classic refuses without it", function()
		local ws, storage, env = fixture()
		ws.WildboundDemonAbyss:Destroy()
		local report = Switch.apply("big4", env)
		equal(#report.missing, 1); equal(report.missing[1], "WildboundDemonAbyss")
		local before = layout(ws, storage)
		local ok, problem = pcall(Switch.apply, "classic", env)
		equal(ok, false, "classic refuses while a classic item is in neither place")
		assert(string.find(tostring(problem), "WildboundDemonAbyss", 1, true), "names it: " .. tostring(problem))
		equal(layout(ws, storage), before, "nothing moved: the big4 map stays whole")
		equal(ws:GetAttribute(Switch.ATTRIBUTE), "big4")
		ws:Destroy(); storage:Destroy()
	end)

	case("BIG4 switch: classic refuses when an archived item has no home folder to go back to", function()
		local ws, storage, env = fixture()
		Switch.apply("big4", env)
		ws.WildboundOpenWorldRoads.Gates:Destroy()
		local before = layout(ws, storage)
		local ok, problem = pcall(Switch.apply, "classic", env)
		equal(ok, false, "refused")
		assert(string.find(tostring(problem), "Gate_rock-caves", 1, true), "names it: " .. tostring(problem))
		equal(layout(ws, storage), before, "nothing moved")
		ws:Destroy(); storage:Destroy()
	end)

	case("BIG4 switch: the classic list names the four removed biomes, the two scaled originals and no kept root", function()
		local listed = {}
		for _, path in ipairs(Switch.CLASSIC_ONLY) do listed[path] = true end
		for _, name in ipairs({ "WildboundLivingForest", "WildboundCrypticRuins", "WildboundRockCaves", "WildboundDemonAbyss",
			"WildboundFrozenMountains", "WildboundVolcanicLands" }) do
			assert(listed[name], name .. " listed")
		end
		for path in pairs(listed) do
			for _, kept in ipairs({ "Candy_Bioma_v1", "WildboundP0", "WildboundPradera", "WildboundHub", "SistemaSonriente",
				"WildboundBeastGallery", "PatioEntrenamiento", "Road_living-forest_1", "Road_living-forest_2",
				"Road_cryptic-ruins_1", "Road_pradera_1", "Road_volcanic-lands_", "Gate_forest", "Gate_pradera" }) do
				assert(not string.find(path, kept, 1, true), path .. " is a kept item (" .. kept .. ")")
			end
		end
		equal(Switch.ATTRIBUTE, Biomes.MODE_ATTRIBUTE); equal(Switch.ATTRIBUTE, BiomeLight.MODE_ATTRIBUTE)
		equal(Switch.ROOT_ATTRIBUTE, Annex.ROOT_ATTRIBUTE)
	end)

	case("BIG4 geometry: the scaled clones fill exactly the Montañas and Volcán big4 squares, corners fixed", function()
		local byName = {}
		for _, spec in ipairs(Annex.SCALED) do byName[spec.source] = spec end
		local frozen, volcanic = byName.WildboundFrozenMountains, byName.WildboundVolcanicLands
		same(Annex.scaledSquare(frozen), square(Biomes.AREAS_BIG4, "Mountains"), "Montañas")
		same(Annex.scaledSquare(volcanic), square(Biomes.AREAS_BIG4, "Volcanic"), "Volcán")
		same(frozen.square, square(Biomes.AREAS, "Mountains"), "the classic Montañas square")
		same(volcanic.square, square(Biomes.AREAS, "Volcanic"), "the classic Volcán square")
		local x, z = Annex.scaledPoint(frozen.corner.x, frozen.corner.z, frozen)
		near(x, frozen.corner.x, "corner x"); near(z, frozen.corner.z, "corner z")
		x, z = Annex.scaledPoint(frozen.gate.x, frozen.gate.z, frozen)
		near(x, 285.75, "frozen gate x"); near(z, -336, "frozen gate z")
		x, z = Annex.scaledPoint(volcanic.gate.x, volcanic.gate.z, volcanic)
		near(x, 73, "volcanic gate x"); near(z, 370, "volcanic gate z")
	end)

	case("BIG4 geometry: each road runs from a kept road end outside the biome to its scaled gate inside", function()
		local gates = {}
		for _, spec in ipairs(Annex.SCALED) do
			local gx, gz = Annex.scaledPoint(spec.gate.x, spec.gate.z, spec)
			gates[spec.source] = { x = gx, z = gz }
		end
		local byBiome = {}
		for _, road in ipairs(Annex.ROADS) do byBiome[road.biome] = road end
		local frozen, volcanic = byBiome["frozen-mountains"], byBiome["volcanic-lands"]
		near(frozen.to.x, gates.WildboundFrozenMountains.x, "frozen road end x")
		near(frozen.to.z, gates.WildboundFrozenMountains.z, "frozen road end z")
		near(volcanic.to.x, gates.WildboundVolcanicLands.x, "volcanic road end x")
		near(volcanic.to.z, gates.WildboundVolcanicLands.z, "volcanic road end z")
		equal(Biomes.has(frozen.from.x, frozen.from.z, "Mountains", "big4"), false, "the N trunk node is outside")
		equal(Biomes.has(frozen.to.x, frozen.to.z, "Mountains", "big4"), true, "the frozen gate is inside")
		equal(Biomes.has(volcanic.to.x, volcanic.to.z, "Volcanic", "big4"), true, "the volcanic gate is inside")
		local cx, cz, length, yaw = Annex.slab({ x = 0, z = 0 }, { x = 0, z = -10 })
		near(cx, 0, "centre x"); near(cz, -5, "centre z"); near(length, 10 + Annex.ROAD_WIDTH, "length"); near(yaw, 0, "yaw north")
		local _, _, _, east = Annex.slab({ x = 0, z = 0 }, { x = 10, z = 0 })
		near(east, -90, "yaw east")
	end)

	case("BIG4 geometry: the annex slabs and the kept plot make up the forest and Caramelo big4 squares", function()
		for _, pair in ipairs({ { Annex.FOREST, "Forest" }, { Annex.CANDY, "Meadow" } }) do
			local spec, tag = pair[1], pair[2]
			same(spec.kept, square(Biomes.AREAS, tag), tag .. " kept = classic square")
			local all = table.clone(spec.floors)
			table.insert(all, spec.kept)
			same(Annex.bounds(all), square(Biomes.AREAS_BIG4, tag), tag .. " big4 square")
			local area = (spec.kept.maxX - spec.kept.minX) * (spec.kept.maxZ - spec.kept.minZ)
			for _, f in ipairs(spec.floors) do
				area += (f.maxX - f.minX) * (f.maxZ - f.minZ)
				assert(f.maxX <= spec.kept.minX or f.minX >= spec.kept.maxX or f.maxZ <= spec.kept.minZ
					or f.minZ >= spec.kept.maxZ, tag .. " slab never under the kept plot")
			end
			local big = square(Biomes.AREAS_BIG4, tag)
			near(area, (big.maxX - big.minX) * (big.maxZ - big.minZ), tag .. " no hole and no overlap")
			for _, p in ipairs(spec.props) do
				local inside = false
				for _, f in ipairs(spec.floors) do
					if p.minX >= f.minX + 12 and p.maxX <= f.maxX - 12 and p.minZ >= f.minZ + 12 and p.maxZ <= f.maxZ - 12 then
						inside = true
					end
				end
				assert(inside, tag .. " prop rect 12 studs inside a slab")
			end
		end
	end)

	case("BIG4 geometry: the seeded scatter is deterministic, spaced, inside its rects and clear of the kept plot", function()
		for _, spec in ipairs({ Annex.FOREST, Annex.CANDY }) do
			local avoid = { { x = spec.props[1].minX + 60, z = spec.props[1].minZ + 60, r = 30 } }
			local a, b = Annex.scatter(spec, avoid), Annex.scatter(spec, avoid)
			equal(#a, #b, spec.name .. " same count")
			assert(#a >= spec.target * 0.9, spec.name .. " reaches 90% of its target: " .. #a)
			assert(#a <= spec.target, spec.name .. " never over its target")
			local names = {}
			for _, w in ipairs(spec.weights) do names[w[1]] = w end
			for index, item in ipairs(a) do
				equal(item.x, b[index].x, "deterministic x"); equal(item.name, b[index].name, "deterministic name")
				assert(names[item.name], "a listed template")
				assert(item.scale >= names[item.name][3] and item.scale <= names[item.name][4], "scale in range")
				local inside = false
				for _, r in ipairs(spec.props) do if Annex.inRect(r, item.x, item.z) then inside = true end end
				assert(inside, spec.name .. " item inside a prop rect")
				assert(not Annex.inRect(spec.kept, item.x, item.z, 20), "20 studs clear of the kept plot")
				assert((item.x - avoid[1].x) ^ 2 + (item.z - avoid[1].z) ^ 2 >= 30 * 30, "clear of an avoid point")
			end
			for i = 1, #a do
				for j = i + 1, #a do
					assert((a[i].x - a[j].x) ^ 2 + (a[i].z - a[j].z) ^ 2 >= spec.spacing ^ 2, spec.name .. " spacing")
				end
			end
		end
	end)

	case("BIG4 map: the Caramelo plot, entrance and portal, and the forest portal stay inside their big4 biomes", function()
		local meadow = square(Biomes.AREAS_BIG4, "Meadow")
		near(meadow.minX, Layout.CENTRE.x - Layout.HALF, "the Caramelo west edge (its entrance) is unchanged")
		near(meadow.minZ, Layout.CENTRE.z - Layout.HALF, "the Caramelo north edge is unchanged")
		assert(meadow.maxX >= Layout.CENTRE.x + Layout.HALF and meadow.maxZ >= Layout.CENTRE.z + Layout.HALF, "contains the plot")
		equal(Biomes.has(Layout.CENTRE.x + Layout.ENTRANCE.x, Layout.CENTRE.z + Layout.ENTRANCE.z, "Meadow", "big4"), true)
		for _, station in ipairs(Portal.STATIONS) do
			local tag = station.id == "caramelo" and "Meadow" or "Forest"
			equal(Biomes.has(station.x, station.z, tag, "big4"), true, station.id .. " in its big4 biome")
			equal(Biomes.has(station.x, station.z, tag, "classic"), true, station.id .. " in its classic biome")
		end
		equal((BiomeLight.presetAt(Layout.CENTRE.x, Layout.CENTRE.z, "big4")), "Caramelo")
	end)

	return result
end

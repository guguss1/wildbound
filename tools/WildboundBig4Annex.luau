-- Big4 map experiment (odd/tasks/wildbound-big4-map.md): the data and the Edit-only builder of every big4 root.
-- Deployed as ServerStorage.WildboundBig4Annex. Pure data and planning (scatter, scaledPoint, slab) plus build(), which
-- writes ONLY into ServerStorage.WildboundMapArchive.Big4 (the switch, ServerStorage.WildboundMapModeSwitch, then moves
-- those roots into Workspace). It never edits or destroys anything that exists; it refuses outside Edit, under a lock,
-- in big4 mode, or when a big4 root already exists.
--
-- The roots (each with attribute MapMode = "big4"):
-- Layout (owner feedback 3, "los 4 iguales con la base al centro"): four equal 600 x 600 squares in a plus around the
-- hub, mirrored about x 297 (halfway between WildboundP0 and Candy_Bioma_v1, which never move) and z -3 (the hub row):
-- forest W (-418..182, -303..297), Caramelo E (412..1012, -303..297), Montañas N (-3..597, -943..-343), Volcán S
-- (-3..597, 337..937).
--   WildboundFrozenMountains_Big4  a clone of WildboundFrozenMountains scaled 1.2 and moved to the N square
--   WildboundVolcanicLands_Big4    a clone of WildboundVolcanicLands scaled 1.5 and moved to the S square
--   WildboundForestOuter_Big4      forest floor slabs west, north and south of WildboundP0, with a seeded scatter of
--                                  the forest's own dressed kit trees (WildboundP0.Decorations.ForestKit)
--   WildboundCandyAnnex_Big4       candy floor slabs east, north and south of Candy_Bioma_v1, with a seeded scatter of
--                                  ServerStorage.WildboundAssets.CandyKit props
--   WildboundBig4Roads             two equal-length axis-aligned roads from the hub's N and S trunks to the moved
--                                  Frozen and Volcanic gates, and their gate markers
--   WildboundBig4Ground            visual-only ground cover over the grey Baseplate: a meadow and four themed aprons
--                                  (forest grass, volcanic basalt, snow, candy pink); WildboundCandyAnnex_Big4's cotton
--                                  trees also get WildboundCandyKit.fluff canopy blobs, and its candy trees grow like
--                                  Candy_Bioma_v1's (WildboundCandyBuilder.growTree, growCandyAnnex)
-- Nothing is pinned inside the annexes: no nests, no eggs, no creature posts.
local Annex = {}

Annex.ROOT_ATTRIBUTE = "MapMode"
Annex.BUDGET = 6000 -- Workspace BaseParts in big4 (no phone measurement yet; odd/tasks/wildbound-big4-map.md)
Annex.YIELD_EVERY = 250 -- parts between task.wait() while building

local function rect(minX, maxX, minZ, maxZ)
	return table.freeze({ minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ })
end
Annex.rect = rect

-- Scaled clones: the classic square (spec.square) is scaled by spec.factor and its centre moved to spec.centre, with no
-- rotation (each gate keeps its classic approach side: Montañas from the west, Volcán from the east).
Annex.SCALED = table.freeze({
	table.freeze({ source = "WildboundFrozenMountains", name = "WildboundFrozenMountains_Big4", factor = 1.2,
		centre = table.freeze({ x = 297, z = -643 }), square = rect(522, 1022, -743, -243), gate = table.freeze({ x = 547, z = -303 }) }),
	table.freeze({ source = "WildboundVolcanicLands", name = "WildboundVolcanicLands_Big4", factor = 1.5,
		centre = table.freeze({ x = 297, z = 637 }), square = rect(-308, 92, 237, 637), gate = table.freeze({ x = 82, z = 307 }) }),
})

-- scaledPoint(x, z, spec) -> x, z of a classic point in the scaled, moved clone.
function Annex.scaledPoint(x, z, spec)
	local cx, cz = (spec.square.minX + spec.square.maxX) / 2, (spec.square.minZ + spec.square.maxZ) / 2
	return spec.centre.x + spec.factor * (x - cx), spec.centre.z + spec.factor * (z - cz)
end

function Annex.scaledSquare(spec)
	local ax, az = Annex.scaledPoint(spec.square.minX, spec.square.minZ, spec)
	local bx, bz = Annex.scaledPoint(spec.square.maxX, spec.square.maxZ, spec)
	return rect(math.min(ax, bx), math.max(ax, bx), math.min(az, bz), math.max(az, bz))
end

-- Annexes. floors: the slabs (their union with the kept plot is the big4 square). props: where scatter may land
-- (12+ studs inside the slab edges, 20+ studs from the kept plot so its own props and posts stay clear).
Annex.FOREST = table.freeze({
	name = "WildboundForestOuter_Big4", seed = 41, spacing = 26, target = 150,
	floorFrom = "WildboundP0/Floor",
	floors = table.freeze({ rect(-418, -218, -303, 297), rect(-218, 182, -303, -203), rect(-218, 182, 197, 297) }),
	props = table.freeze({ rect(-406, -230, -291, 285), rect(-206, 170, -291, -215), rect(-206, 170, 209, 285) }),
	kept = rect(-218, 182, -203, 197),
	-- name in WildboundP0.Decorations.ForestKit (a dressed exemplar, with its trunk core), weight, scale range
	weights = table.freeze({
		table.freeze({ "FK_Evergreen", 60, 0.85, 1.25 }), table.freeze({ "FK_DeadTree", 22, 0.85, 1.25 }),
		table.freeze({ "FK_FallenLog", 13, 0.9, 1.3 }), table.freeze({ "FK_RootArch", 3, 0.9, 1.1 }),
		table.freeze({ "FK_RuinDoorway", 2, 0.9, 1.1 }),
	}),
})
Annex.CANDY = table.freeze({
	name = "WildboundCandyAnnex_Big4", seed = 77, spacing = 22, target = 120,
	floorFrom = "Candy_Bioma_v1/Ground/Floor",
	floors = table.freeze({ rect(812, 1012, -303, 297), rect(412, 812, -303, -203), rect(412, 812, 197, 297) }),
	props = table.freeze({ rect(832, 1000, -291, 285), rect(424, 800, -291, -215), rect(424, 800, 209, 285) }),
	kept = rect(412, 812, -203, 197),
	-- name in ServerStorage.WildboundAssets.CandyKit, weight, scale range
	weights = table.freeze({
		table.freeze({ "TreeCotton_S", 10, 1, 1.6 }), table.freeze({ "TreeCotton_M", 12, 1, 1.5 }),
		table.freeze({ "TreeCotton_L", 10, 0.9, 1.3 }), table.freeze({ "TreeLollipop_Straight", 8, 0.9, 1.4 }),
		table.freeze({ "TreeLollipop_Tilted", 6, 0.9, 1.4 }), table.freeze({ "TreeCookie", 8, 1, 1.5 }),
		table.freeze({ "TreeCream", 8, 1, 1.5 }), table.freeze({ "CreamMushroom", 8, 1, 1.6 }),
		table.freeze({ "RockSugar", 6, 1, 1.6 }), table.freeze({ "RockChocolate", 6, 1, 1.6 }),
		table.freeze({ "GumdropBush_A", 6, 1.2, 2 }), table.freeze({ "GumdropBush_B", 6, 1.2, 2 }),
		table.freeze({ "ConfettiPile", 4, 1, 1.6 }), table.freeze({ "DonutArch", 2, 1, 1.3 }),
	}),
})

-- Roads to the moved gates, with the classic slab style: polylines of axis-aligned legs (one slab per leg) from the
-- kept hub trunk ends (Road_living-forest_1 at z -124, Road_cryptic-ruins_1 at z 118, mirrored about z -3) straight
-- out along x 282, then along the 40-stud gap between the plus arms, round the biome's outside to its gate's classic
-- approach side, and in. Both are 694 studs long (the frozen side leg runs 20 studs farther out to even them up).
Annex.ROADS_NAME = "WildboundBig4Roads"
Annex.ROAD_WIDTH, Annex.ROAD_THICK, Annex.ROAD_Y = 14, 0.12, 0.56
local function p(x, z) return table.freeze({ x = x, z = z }) end
Annex.ROADS = table.freeze({
	table.freeze({ name = "Road_big4_frozen-mountains", biome = "frozen-mountains",
		points = table.freeze({ p(282, -124), p(282, -323), p(-47, -323), p(-47, -415), p(27, -415) }) }),
	table.freeze({ name = "Road_big4_volcanic-lands", biome = "volcanic-lands",
		points = table.freeze({ p(282, 118), p(282, 317), p(617, 317), p(617, 442), p(582, 442) }) }),
})

-- roadLength(road) -> the sum of its legs' lengths (centre line).
function Annex.roadLength(road)
	local total = 0
	for index = 1, #road.points - 1 do
		local a, b = road.points[index], road.points[index + 1]
		total += math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
	end
	return total
end

-- Ground cover (owner, 2026-11-16: no grey parts on the map): the place's grey 2048-stud Baseplate shows wherever no
-- biome floor lies (around the hub, between the biomes, the gaps of the archived classic biomes). WildboundBig4Ground
-- lays big flat visual-only slabs over it: a meadow over the whole baseplate, and a themed apron (margin studs past
-- each big4 square, clipped to the baseplate) around each biome. Tops are distinct (no z-fighting) and under every
-- biome floor and road (tops 0.5 and up), so nothing that stands on the map is covered.
Annex.GROUND = table.freeze({
	name = "WildboundBig4Ground",
	baseplate = rect(-1024, 1024, -1024, 1024),
	margin = 24,
	thick = 0.4,
})

local function forestBounds()
	local all = table.clone(Annex.FOREST.floors)
	table.insert(all, Annex.FOREST.kept)
	return Annex.bounds(all)
end

-- groundSlabs() -> { { name, rect, top, material, color }, ... }: the meadow first, then the aprons.
function Annex.groundSlabs()
	local base, margin = Annex.GROUND.baseplate, Annex.GROUND.margin
	local function apron(r)
		return rect(math.max(base.minX, r.minX - margin), math.min(base.maxX, r.maxX + margin),
			math.max(base.minZ, r.minZ - margin), math.min(base.maxZ, r.maxZ + margin))
	end
	local candy = table.clone(Annex.CANDY.floors)
	table.insert(candy, Annex.CANDY.kept)
	return {
		{ name = "Meadow", rect = base, top = 0.2, material = Enum.Material.Grass, color = Color3.fromRGB(124, 168, 92) },
		{ name = "Apron_Forest", rect = apron(forestBounds()), top = 0.27, material = Enum.Material.Grass,
			color = Color3.fromRGB(96, 138, 78) },
		{ name = "Apron_Volcanic", rect = apron(Annex.scaledSquare(Annex.SCALED[2])), top = 0.32,
			material = Enum.Material.Basalt, color = Color3.fromRGB(104, 70, 58) },
		{ name = "Apron_Frozen", rect = apron(Annex.scaledSquare(Annex.SCALED[1])), top = 0.37,
			material = Enum.Material.Snow, color = Color3.fromRGB(232, 241, 248) },
		{ name = "Apron_Candy", rect = apron(Annex.bounds(candy)), top = 0.42, material = Enum.Material.SmoothPlastic,
			color = Color3.fromRGB(255, 190, 218) },
	}
end

-- slab(from, to) -> centre x, z, length (the classic legs overlap by one road width), yaw (degrees, CFrame.lookAt).
function Annex.slab(from, to)
	local dx, dz = to.x - from.x, to.z - from.z
	local length = math.sqrt(dx * dx + dz * dz)
	return (from.x + to.x) / 2, (from.z + to.z) / 2, length + Annex.ROAD_WIDTH, math.deg(math.atan2(-dx, -dz))
end

local function inRect(r, x, z, margin)
	margin = margin or 0
	return x >= r.minX - margin and x <= r.maxX + margin and z >= r.minZ - margin and z <= r.maxZ + margin
end
Annex.inRect = inRect

-- scatter(spec, avoidPoints) -> items { name, x, z, yaw, scale }: seeded (Random.new(spec.seed)), inside spec.props,
-- never within spec.spacing of another item, never within 20 studs of spec.kept, never within r of an avoid point
-- ({ x, z, r }). Deterministic for the same inputs.
function Annex.scatter(spec, avoidPoints)
	local rng = Random.new(spec.seed)
	local areas, totalArea = {}, 0
	for _, r in ipairs(spec.props) do
		local area = (r.maxX - r.minX) * (r.maxZ - r.minZ)
		totalArea += area
		table.insert(areas, area)
	end
	local totalWeight = 0
	for _, w in ipairs(spec.weights) do totalWeight += w[2] end
	local cell = spec.spacing
	local grid, items = {}, {}
	local function key(gx, gz) return gx .. ":" .. gz end
	local function free(x, z)
		if inRect(spec.kept, x, z, 20) then return false end
		for _, p in ipairs(avoidPoints or {}) do
			if (x - p.x) ^ 2 + (z - p.z) ^ 2 < p.r * p.r then return false end
		end
		local gx, gz = math.floor(x / cell), math.floor(z / cell)
		for ix = gx - 1, gx + 1 do
			for iz = gz - 1, gz + 1 do
				for _, other in ipairs(grid[key(ix, iz)] or {}) do
					if (x - other.x) ^ 2 + (z - other.z) ^ 2 < cell * cell then return false end
				end
			end
		end
		return true
	end
	local attempts = 0
	while #items < spec.target and attempts < spec.target * 40 do
		attempts += 1
		local pick, chosen = rng:NextNumber() * totalArea, spec.props[#spec.props]
		for index, r in ipairs(spec.props) do
			if pick <= areas[index] then chosen = r break end
			pick -= areas[index]
		end
		local x = rng:NextNumber(chosen.minX, chosen.maxX)
		local z = rng:NextNumber(chosen.minZ, chosen.maxZ)
		local roll, weight = rng:NextNumber() * totalWeight, spec.weights[1]
		for _, w in ipairs(spec.weights) do
			if roll <= w[2] then weight = w break end
			roll -= w[2]
		end
		local yaw, scale = rng:NextNumber(0, 360), rng:NextNumber(weight[3], weight[4])
		if free(x, z) then
			local item = { name = weight[1], x = x, z = z, yaw = yaw, scale = scale }
			table.insert(items, item)
			local k = key(math.floor(x / cell), math.floor(z / cell))
			grid[k] = grid[k] or {}
			table.insert(grid[k], item)
		end
	end
	return items
end

-- bounds(list of rects) -> one rect around them.
function Annex.bounds(list)
	local out = { minX = math.huge, maxX = -math.huge, minZ = math.huge, maxZ = -math.huge }
	for _, r in ipairs(list) do
		out.minX, out.maxX = math.min(out.minX, r.minX), math.max(out.maxX, r.maxX)
		out.minZ, out.maxZ = math.min(out.minZ, r.minZ), math.max(out.maxZ, r.maxZ)
	end
	return out
end

-- ===================================================================================================== Studio build
local function countParts(root)
	local n = root:IsA("BasePart") and 1 or 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then n += 1 end
	end
	return n
end
Annex.countParts = countParts

local function findPath(root, path)
	local node = root
	for _, name in ipairs(string.split(path, "/")) do
		node = node and node:FindFirstChild(name)
	end
	return node
end

-- A prop clone: visuals only (no scripts, prompts, sounds or tags), anchored, never touched.
local function clean(model)
	local CollectionService = game:GetService("CollectionService")
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("ClickDetector") or d:IsA("Sound") then
			d:Destroy()
		else
			for _, tag in ipairs(CollectionService:GetTags(d)) do CollectionService:RemoveTag(d, tag) end
			if d:IsA("BasePart") then
				d.Anchored, d.CanTouch = true, false
			end
		end
	end
	for _, tag in ipairs(CollectionService:GetTags(model)) do CollectionService:RemoveTag(model, tag) end
end

local function newRoot(name, parent)
	local root = Instance.new("Model")
	root.Name = name
	root:SetAttribute(Annex.ROOT_ATTRIBUTE, "big4")
	root.Parent = parent
	return root
end

local function checkEdit(storage)
	if game:GetService("RunService"):IsRunning() then error("WildboundBig4Annex: Edit only", 3) end
	for _, lock in ipairs({ "WildboundPlayLock", "WildboundImportLock" }) do
		if storage:GetAttribute(lock) ~= nil then error("WildboundBig4Annex: ServerStorage " .. lock .. " is set", 3) end
	end
	if game:GetService("Workspace"):GetAttribute("WildboundMapMode") == "big4" then
		error("WildboundBig4Annex: build in classic mode (apply(\"classic\") first)", 3)
	end
end

local function big4Folder(storage)
	local archive = storage:FindFirstChild("WildboundMapArchive")
	if not archive then
		archive = Instance.new("Folder")
		archive.Name = "WildboundMapArchive"
		archive.Parent = storage
	end
	local big4 = archive:FindFirstChild("Big4")
	if not big4 then
		big4 = Instance.new("Folder")
		big4.Name = "Big4"
		big4.Parent = archive
	end
	return big4
end

-- buildScaled(spec) -> root, parts: the source is cloned child by child (small subtrees, a yield every
-- YIELD_EVERY parts) into a new root in the archive, then scaled about its pivot and moved so spec.corner stays put.
function Annex.buildScaled(spec)
	local storage = game:GetService("ServerStorage")
	checkEdit(storage)
	local big4 = big4Folder(storage)
	assert(not big4:FindFirstChild(spec.name), spec.name .. " already exists")
	local source = game:GetService("Workspace"):FindFirstChild(spec.source)
	assert(source and source:IsA("Model"), spec.source .. " is not in Workspace")
	local root = newRoot(spec.name, big4)
	for key, value in pairs(source:GetAttributes()) do root:SetAttribute(key, value) end
	root:SetAttribute(Annex.ROOT_ATTRIBUTE, "big4")
	root:SetAttribute("Big4ScaledFrom", spec.source)
	root:SetAttribute("Big4ScaleFactor", spec.factor)
	local sinceYield = 0
	for _, child in ipairs(source:GetChildren()) do
		if (child:IsA("Folder") or child:IsA("Model")) and countParts(child) > Annex.YIELD_EVERY then
			local shell = child:Clone()
			shell:ClearAllChildren()
			shell.Parent = root
			for _, grand in ipairs(child:GetChildren()) do
				local copy = grand:Clone()
				copy.Parent = shell
				sinceYield += countParts(copy)
				if sinceYield >= Annex.YIELD_EVERY then sinceYield = 0 task.wait() end
			end
		else
			local copy = child:Clone()
			copy.Parent = root
			sinceYield += countParts(copy)
			if sinceYield >= Annex.YIELD_EVERY then sinceYield = 0 task.wait() end
		end
	end
	if source.PrimaryPart then root.PrimaryPart = root:FindFirstChild(source.PrimaryPart.Name) end
	if not root.PrimaryPart then root.WorldPivot = source:GetPivot() end
	task.wait()
	local pivot = root:GetPivot()
	root:ScaleTo(root:GetScale() * spec.factor)
	-- ScaleTo keeps the pivot: a point q lands on pivot + f (q - pivot); move the square's centre to spec.centre.
	local cx, cz = (spec.square.minX + spec.square.maxX) / 2, (spec.square.minZ + spec.square.maxZ) / 2
	local shift = Vector3.new(spec.centre.x - pivot.X - spec.factor * (cx - pivot.X), 0,
		spec.centre.z - pivot.Z - spec.factor * (cz - pivot.Z))
	root:PivotTo(root:GetPivot() + shift)
	return root, countParts(root)
end

local function slabFrom(template, r, name, parent)
	local floor = template:Clone()
	floor:ClearAllChildren()
	for key in pairs(floor:GetAttributes()) do floor:SetAttribute(key, nil) end
	floor.Name = name
	floor.Size = Vector3.new(r.maxX - r.minX, template.Size.Y, r.maxZ - r.minZ)
	floor.CFrame = CFrame.new((r.minX + r.maxX) / 2, template.Position.Y, (r.minZ + r.maxZ) / 2)
	floor.Anchored = true
	floor.Parent = parent
	return floor
end

-- buildAnnex(spec, templates, opts) -> root, parts, placed. templates: a folder of models by spec.weights name (the
-- first child whose name starts with it is the exemplar). opts.avoid: extra { x, z, r } points (computed from
-- SistemaSonriente by build()).
function Annex.buildAnnex(spec, templates, opts)
	opts = opts or {}
	local storage = game:GetService("ServerStorage")
	checkEdit(storage)
	local big4 = big4Folder(storage)
	assert(not big4:FindFirstChild(spec.name), spec.name .. " already exists")
	local floorTemplate = findPath(game:GetService("Workspace"), spec.floorFrom)
	assert(floorTemplate and floorTemplate:IsA("BasePart"), spec.floorFrom .. " is not a part")
	local exemplars = {}
	for _, w in ipairs(spec.weights) do
		for _, child in ipairs(templates:GetChildren()) do
			if child:IsA("Model") and (child.Name == w[1] or string.sub(child.Name, 1, #w[1] + 1) == w[1] .. "_")
				and (opts.groundY == nil or math.abs(child:GetPivot().Y - opts.groundY) < 0.05) then
				exemplars[w[1]] = child
				break
			end
		end
		assert(exemplars[w[1]], "no template for " .. w[1])
	end
	local root = newRoot(spec.name, big4)
	local floors = Instance.new("Folder")
	floors.Name = "Ground"
	floors.Parent = root
	for index, r in ipairs(spec.floors) do slabFrom(floorTemplate, r, "Floor_Big4_" .. index, floors) end
	local floorTop = floorTemplate.Position.Y + floorTemplate.Size.Y / 2
	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = root
	local items = Annex.scatter(spec, opts.avoid)
	local sinceYield = 0
	for index, item in ipairs(items) do
		local exemplar = exemplars[item.name]
		local model = exemplar:Clone()
		clean(model)
		model.Name = item.name .. "_B4_" .. index
		model:ScaleTo(exemplar:GetScale() * item.scale)
		-- Every kit model's pivot is its foot on the ground (the kit templates and the forest's flat-ground exemplars).
		model:PivotTo(CFrame.new(item.x, floorTop, item.z) * CFrame.Angles(0, math.rad(item.yaw), 0))
		model.Parent = props
		sinceYield += countParts(model)
		if sinceYield >= Annex.YIELD_EVERY then sinceYield = 0 task.wait() end
	end
	return root, countParts(root), #items
end

function Annex.buildRoads()
	local storage = game:GetService("ServerStorage")
	checkEdit(storage)
	local big4 = big4Folder(storage)
	assert(not big4:FindFirstChild(Annex.ROADS_NAME), Annex.ROADS_NAME .. " already exists")
	local roads = game:GetService("Workspace"):FindFirstChild("WildboundOpenWorldRoads")
	local styleRoad = roads and findPath(roads, "pradera/Road_pradera_1")
	local styleGate = roads and findPath(roads, "Gates/Gate_forest")
	assert(styleRoad and styleGate, "WildboundOpenWorldRoads style slabs missing")
	local root = newRoot(Annex.ROADS_NAME, big4)
	for _, road in ipairs(Annex.ROADS) do
		for index = 1, #road.points - 1 do
			local x, z, length, yaw = Annex.slab(road.points[index], road.points[index + 1])
			local slab = styleRoad:Clone()
			slab:ClearAllChildren()
			slab.Name = road.name .. "_" .. index
			slab:SetAttribute("Biome", road.biome)
			slab.Size = Vector3.new(Annex.ROAD_WIDTH, Annex.ROAD_THICK, length)
			slab.CFrame = CFrame.new(x, Annex.ROAD_Y, z) * CFrame.Angles(0, math.rad(yaw), 0)
			slab.Parent = root
		end
		local to = road.points[#road.points]
		local gate = styleGate:Clone()
		gate:ClearAllChildren()
		gate.Name = "Gate_big4_" .. road.biome
		gate:SetAttribute("Biome", road.biome)
		gate.CFrame = CFrame.new(to.x, styleGate.Position.Y, to.z)
		gate.Parent = root
	end
	return root, countParts(root)
end

-- buildGround() -> root, parts: the ground cover slabs (visual only: no collision, queries, touch or shadows).
function Annex.buildGround()
	local storage = game:GetService("ServerStorage")
	checkEdit(storage)
	local big4 = big4Folder(storage)
	assert(not big4:FindFirstChild(Annex.GROUND.name), Annex.GROUND.name .. " already exists")
	local root = newRoot(Annex.GROUND.name, big4)
	for _, s in ipairs(Annex.groundSlabs()) do
		local r = s.rect
		local slab = Instance.new("Part")
		slab.Name = s.name
		slab.Size = Vector3.new(r.maxX - r.minX, Annex.GROUND.thick, r.maxZ - r.minZ)
		slab.CFrame = CFrame.new((r.minX + r.maxX) / 2, s.top - Annex.GROUND.thick / 2, (r.minZ + r.maxZ) / 2)
		slab.Material, slab.Color = s.material, s.color
		slab.Anchored, slab.CanCollide, slab.CanQuery, slab.CanTouch, slab.CastShadow = true, false, false, false, false
		slab.TopSurface, slab.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		slab.Parent = root
	end
	return root, countParts(root)
end

-- fluffCandyAnnex(root, kit) -> blobs added: kit.fluff (WildboundCandyKit) on every TreeCotton_* prop of the candy
-- annex, so the scattered cotton trees match Candy_Bioma_v1's fuller canopies.
function Annex.fluffCandyAnnex(root, kit)
	local added = 0
	local props = root:FindFirstChild("Props")
	for _, model in ipairs(props and props:GetChildren() or {}) do
		if model:IsA("Model") and string.sub(model.Name, 1, 11) == "TreeCotton_" then added += kit.fluff(model) end
	end
	return added
end

-- sonrienteAvoid(workspace) -> { x, z, r } per SistemaSonriente part (r: its half size + 12), read only; none without it.
function Annex.sonrienteAvoid(workspace)
	local avoid = {}
	local sonriente = workspace:FindFirstChild("SistemaSonriente")
	if sonriente then
		for _, d in ipairs(sonriente:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(avoid, { x = d.Position.X, z = d.Position.Z, r = math.max(d.Size.X, d.Size.Z) / 2 + 12 })
			end
		end
	end
	return avoid
end

-- CH (owner, 2026-11-16: the Caramelo trees leafier and bigger). candyTreeFits(x, z, m, avoid, rules) -> ok, reason: a
-- candy annex tree measured m (WildboundCandyBuilder.measureTree, grown) at world (x, z), under the builder's
-- TREE_CLEAR (rules): its trunk collider stays trunkMargin out of the kept plot and its canopy reaches at most
-- KEPT_EDGE into it (the plot's own scatter keeps 10 studs off its edge); trunk and canopy keep the builder's route
-- rule to the big4 roads; the canopy stays off every SistemaSonriente part (avoid r is its half size + 12).
Annex.KEPT_EDGE = 10
function Annex.candyTreeFits(x, z, m, avoid, rules)
	local k = Annex.CANDY.kept
	local ox, oz = math.max(k.minX - x, 0, x - k.maxX), math.max(k.minZ - z, 0, z - k.maxZ)
	local out = math.sqrt(ox * ox + oz * oz)
	if out < m.trunk + rules.trunkMargin or out < m.canopy - Annex.KEPT_EDGE then return false, "over the kept plot" end
	local half = Annex.ROAD_WIDTH / 2
	local need = math.max(m.trunk + rules.trunkMargin, m.canopy - (m.bottom >= rules.headroom and rules.overhang or 0))
	for _, road in ipairs(Annex.ROADS) do
		for index = 1, #road.points - 1 do
			local a, b = road.points[index], road.points[index + 1]
			local dx, dz = b.x - a.x, b.z - a.z
			local t = math.clamp(((x - a.x) * dx + (z - a.z) * dz) / (dx * dx + dz * dz), 0, 1)
			if math.sqrt((x - a.x - t * dx) ^ 2 + (z - a.z - t * dz) ^ 2) < half + need then return false, "by " .. road.name end
		end
	end
	for _, p in ipairs(avoid or {}) do
		if math.sqrt((x - p.x) ^ 2 + (z - p.z) ^ 2) < p.r - 12 + m.canopy then return false, "over SistemaSonriente" end
	end
	return true
end

-- growCandyAnnex(root, builder, avoid, dryRun) -> report { found, grown, already, reduced, blocked, minFactor, maxFactor,
-- blockedList }: each tree prop of the candy annex (a Props child named "<asset>_B4_<n>" for an asset of
-- builder.TREE_SCALE) that does not carry builder.TREE_ATTRIBUTE yet is measured on a detached clone grown by its
-- factor, then grown (builder.growTree) to the largest factor down to TREE_CLEAR.minFactor that candyTreeFits where it
-- stands; one that fits at none is left as it is and listed. dryRun: report only. Never moves a prop.
function Annex.growCandyAnnex(root, builder, avoid, dryRun)
	local report = { found = 0, grown = 0, already = 0, reduced = 0, blocked = 0, blockedList = {} }
	local rules = builder.TREE_CLEAR
	local props = root:FindFirstChild("Props")
	for _, model in ipairs(props and props:GetChildren() or {}) do
		local asset = model:IsA("Model") and string.match(model.Name, "^(.-)_B4_%d+$") or nil
		local factor = asset and builder.TREE_SCALE[asset]
		if factor then
			report.found += 1
			if model:GetAttribute(builder.TREE_ATTRIBUTE) ~= nil then
				report.already += 1
			else
				local probe = model:Clone()
				builder.growTree(probe, asset, factor)
				local m = builder.measureTree(probe)
				probe:Destroy()
				local pivot = model:GetPivot()
				local f, why = factor, nil
				while f >= rules.minFactor - 1e-9 do
					local ok, reason = Annex.candyTreeFits(pivot.X, pivot.Z, builder.scaleMeasure(m, f / factor), avoid, rules)
					if ok then break end
					why = why or reason
					f = math.round((f - rules.step) * 1000) / 1000
				end
				if f < rules.minFactor - 1e-9 then
					report.blocked += 1
					table.insert(report.blockedList, model.Name .. ": " .. tostring(why))
				else
					if f < factor - 1e-6 then report.reduced += 1 end
					report.grown += 1
					report.minFactor = math.min(report.minFactor or f, f)
					report.maxFactor = math.max(report.maxFactor or f, f)
					if not dryRun then builder.growTree(model, asset, f) end
				end
			end
		end
	end
	return report
end

-- build() -> report: every big4 root, into the archive's Big4 folder. Then run the switch's apply("big4").
function Annex.build()
	local Workspace = game:GetService("Workspace")
	local report = {}
	for _, spec in ipairs(Annex.SCALED) do
		local root, parts = Annex.buildScaled(spec)
		table.insert(report, root.Name .. " " .. parts)
		task.wait()
	end
	local avoid = Annex.sonrienteAvoid(Workspace)
	local forestKit = findPath(Workspace, "WildboundP0/Decorations/ForestKit")
	assert(forestKit, "WildboundP0.Decorations.ForestKit missing")
	-- groundY: only exemplars standing on the forest's flat floor top (not on a relief hill) are cloned
	local p0Floor = findPath(Workspace, Annex.FOREST.floorFrom)
	local root, parts, placed = Annex.buildAnnex(Annex.FOREST, forestKit,
		{ avoid = avoid, groundY = p0Floor.Position.Y + p0Floor.Size.Y / 2 })
	table.insert(report, root.Name .. " " .. parts .. " (" .. placed .. " props)")
	task.wait()
	local candyKit = findPath(game:GetService("ServerStorage"), "WildboundAssets/CandyKit")
	assert(candyKit, "ServerStorage.WildboundAssets.CandyKit missing")
	root, parts, placed = Annex.buildAnnex(Annex.CANDY, candyKit, { avoid = avoid })
	local kit = game:GetService("ServerStorage"):FindFirstChild("WildboundCandyKit")
	if kit then parts += Annex.fluffCandyAnnex(root, require(kit)) end
	-- CH: the candy trees grow like Candy_Bioma_v1's, when the deployed builder has the tree rule (no part is added)
	local builder = game:GetService("ServerStorage"):FindFirstChild("WildboundCandyBuilder")
	local candyBuilder = builder and require(builder)
	if candyBuilder and type(candyBuilder.growTree) == "function" then Annex.growCandyAnnex(root, candyBuilder, avoid, false) end
	table.insert(report, root.Name .. " " .. parts .. " (" .. placed .. " props)")
	root, parts = Annex.buildRoads()
	table.insert(report, root.Name .. " " .. parts)
	root, parts = Annex.buildGround()
	table.insert(report, root.Name .. " " .. parts)
	return report
end

return Annex

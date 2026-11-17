-- Caramelo v4 (odd/tasks/wildbound-caramelo-v2.md, V4-D8, owner request 2026-11-17 "eggs inside the houses"): one egg
-- nest inside each Caramelo v3 house. Not in WildboundCandyLayout.NESTS (the 28 floor nests and their rules stay as
-- they are): this module lays them by READING the live houses (Workspace.Candy_Bioma_v1.CaramelV3.Houses.House_<id>,
-- attributes HouseId, KitAsset, KitScale; pivot = the house's ground centre, front -Z towards the junction), so a house
-- moved or rescaled by a later migration gets its nest where it now stands. Each nest is the kit's Nest prefab (the same
-- prefab, attributes and tag as WildboundCandyBuilder.addNest, plus House = true and HouseId) in the biome's Nests
-- folder, named Nest_<HouseId>, at a per-kit interior floor spot (SPOTS, kit units, scaled by KitScale, turned with
-- the house) clear of the kit's colliders (WildboundCandyV3KitSpec). WildboundCandyNests.read then makes them island
-- nests like any other; read marks them house nests so no creature post binds them (no new guardian: a steal raises
-- the usual alarm only). Called from WildboundCandyNests.applyFlags at server start; idempotent.
-- Pure helpers (spot, blocked, floorTop) plus sync, which only touches the Nests folder.
local CollectionService = game:GetService("CollectionService")

local HouseNests = {}

HouseNests.TAG = "WildboundCandyNestCandidate"
-- The kit nest at 80 %: a bowl 4.24 studs wide (the summit nest is 70 %), so it fits the tower's upper floor.
HouseNests.NEST_SCALE = 0.8
-- Clearance test radius and height round a nest's centre (the bowl 2.12 plus its rim and ring) at NEST_SCALE.
HouseNests.FOOTPRINT_STUDS = 2.4
HouseNests.HEIGHT_STUDS = 1.8
-- V4-D11-C1: per kit, the interior floor spot (kit units at kit scale 1, Roblox axes from the pivot; y = the floor's
-- top) clear of every collider of WildboundCandyV3KitSpec with FOOTPRINT_STUDS:
--   CV3_SweetHouse   (5.5, 0.6, 6): the back right of the room, away from the table and chairs (x -6..-1.8), the shelf
--                    (x >= 10.8) and the door leaf (z <= -3.15).
--   CV3_ChocoHouse   (5.5, 0.7, 4): the room's free half, away from the table and its chairs (x <= -0.05), the shelf
--                    (z >= 9), the door leaf and the towers.
--   CV3_CaramelTower (-1, 16.6, 4.6): the UPPER floor (the spiral stair ring r 1..6 leaves the ground floor too narrow),
--                    between the newel, the upper table, the upper shelf and the wall; the stair arrives at x -3.4, z < 0.
HouseNests.SPOTS = table.freeze({
	CV3_SweetHouse = table.freeze({ x = 5.5, y = 0.6, z = 6, floor = "ground" }),
	CV3_ChocoHouse = table.freeze({ x = 5.5, y = 0.7, z = 4, floor = "ground" }),
	CV3_CaramelTower = table.freeze({ x = -1, y = 16.6, z = 4.6, floor = "upper" }),
})
-- V4-D11-C2: rarities: mostly Rara; the two sweet houses nearest the routes' ends Comun; H5, the big caramel tower
-- (V4-D5, scale 1.4), Epica on its upper floor. An unknown house: DEFAULT_RARITY.
HouseNests.RARITY = table.freeze({ H1 = "Rara", H2 = "Rara", H3 = "Rara", H4 = "Comun", H5 = "Epica", H6 = "Rara", H7 = "Comun" })
HouseNests.DEFAULT_RARITY = "Rara"
local RARITY_COLOR = {
	Comun = Color3.fromRGB(88, 214, 220), Rara = Color3.fromRGB(251, 225, 94), Epica = Color3.fromRGB(117, 64, 121),
	Legendaria = Color3.fromRGB(255, 140, 40),
}

local function finite(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end

-- The nest id of a house: its HouseId ("H1".."H7"); never one of Layout.NESTS (C, R, E, L, T ids).
function HouseNests.nestId(houseId)
	return type(houseId) == "string" and houseId or nil
end

function HouseNests.rarity(houseId)
	return HouseNests.RARITY[houseId] or HouseNests.DEFAULT_RARITY
end

-- The world CFrame of a house's nest (its bowl's base centre on the floor), from the house's pivot, kit and scale;
-- nil for a kit without a spot or a bad scale.
function HouseNests.spot(pivot, asset, scale)
	local S = HouseNests.SPOTS[asset]
	if not S or typeof(pivot) ~= "CFrame" then return nil end
	scale = finite(scale) and scale > 0 and scale or 1
	return pivot * CFrame.new(S.x * scale, S.y * scale, S.z * scale)
end

-- The first box (of { { name, cframe, size } }) a nest standing on `at` (a CFrame on its floor) would overlap: its
-- axis sampled from just over the floor to HEIGHT_STUDS, each sample's nearest box point closer than FOOTPRINT_STUDS
-- across and at that sample's height. A box whose top is the nest's floor (within 0.25) is the floor, never a block.
-- Returns the box's name, or nil when clear.
function HouseNests.blocked(at, boxes, footprint, height)
	footprint = footprint or HouseNests.FOOTPRINT_STUDS
	height = height or HouseNests.HEIGHT_STUDS
	local base = at.Position
	for _, box in ipairs(boxes) do
		local half = box.size / 2
		for _, lift in ipairs({ 0.3, height / 2, height }) do
			local p = base + Vector3.new(0, lift, 0)
			local l = box.cframe:PointToObjectSpace(p)
			local q = box.cframe:PointToWorldSpace(Vector3.new(math.clamp(l.X, -half.X, half.X), math.clamp(l.Y, -half.Y, half.Y),
				math.clamp(l.Z, -half.Z, half.Z)))
			local across = Vector2.new(q.X - p.X, q.Z - p.Z).Magnitude
			if math.abs(q.Y - p.Y) < 1e-3 and across < footprint then return box.name end
		end
	end
	return nil
end

-- The top of the highest box under (x, z) of `at` whose top lies within `reach` of at's height, or nil (no floor).
function HouseNests.floorTop(at, boxes, reach)
	reach = reach or 0.25
	local base = at.Position
	local best = nil
	for _, box in ipairs(boxes) do
		local l = box.cframe:PointToObjectSpace(base)
		local half = box.size / 2
		if math.abs(l.X) <= half.X and math.abs(l.Z) <= half.Z then
			local top = box.cframe:PointToWorldSpace(Vector3.new(l.X, half.Y, l.Z)).Y
			if math.abs(top - base.Y) <= reach and (not best or top > best) then best = top end
		end
	end
	return best
end

-- A house model's colliders as boxes: its Collision_ parts (the spec colliders V3Builder adds), plus any other
-- colliding block part.
function HouseNests.boxes(house)
	local list = {}
	for _, d in ipairs(house:GetDescendants()) do
		if d:IsA("BasePart") and (d.CanCollide or string.sub(d.Name, 1, 10) == "Collision_") then
			table.insert(list, { name = d.Name, cframe = d.CFrame, size = d.Size })
		end
	end
	return list
end

-- The live houses under `root` (the Candy_Bioma_v1 model): Models under CaramelV3.Houses with a HouseId and a kit that
-- has a spot, never a placeholder (its interior is not the kit's), sorted by HouseId.
function HouseNests.houses(root)
	local v3 = typeof(root) == "Instance" and root:FindFirstChild("CaramelV3") or nil
	local folder = v3 and v3:FindFirstChild("Houses")
	local list = {}
	if not folder then return list end
	for _, house in ipairs(folder:GetChildren()) do
		local id = house:GetAttribute("HouseId")
		if house:IsA("Model") and type(id) == "string" and HouseNests.SPOTS[house:GetAttribute("KitAsset")]
			and house:GetAttribute("Placeholder") ~= true then
			table.insert(list, house)
		end
	end
	table.sort(list, function(a, b) return a:GetAttribute("HouseId") < b:GetAttribute("HouseId") end)
	return list
end

local function dress(nest, id, rarity, house, live)
	for _, d in ipairs(nest:GetChildren()) do
		if d:IsA("MeshPart") then
			d:SetAttribute("Role", "decor")
		elseif d:IsA("Part") then
			d:SetAttribute("Role", "solid")
		end
	end
	-- keep the model's pivot on the floor spot (a PrimaryPart moves GetPivot to its own CFrame otherwise)
	local pivot = nest:GetPivot()
	local bowl = nest:FindFirstChild("Collision_Bowl")
	nest.PrimaryPart = bowl
	if bowl then bowl.PivotOffset = bowl.CFrame:ToObjectSpace(pivot) end
	local ring = nest:FindFirstChild("RarityRing")
	if ring and ring:IsA("BasePart") then ring.Color = RARITY_COLOR[rarity] or RARITY_COLOR.Rara end
	nest.Name = "Nest_" .. id
	nest:SetAttribute("NestId", id)
	nest:SetAttribute("Rarity", rarity)
	nest:SetAttribute("EventOnly", false)
	nest:SetAttribute("Candidate", true)
	nest:SetAttribute("House", true)
	nest:SetAttribute("HouseId", house:GetAttribute("HouseId"))
	nest:SetAttribute("Enabled", live)
	CollectionService:AddTag(nest, HouseNests.TAG)
end

-- The server's start step (through WildboundCandyNests.applyFlags): for each live house, its nest in root.Nests, laid
-- once at the house's spot; one already there is moved onto the spot when the house moved (more than 0.5 studs) and
-- its Enabled follows the layout's NESTS_ENABLED. A spot inside a collider (blocked) or with no floor under it is
-- skipped (never a nest in a wall), and so is everything when the kit or its library is missing. kit and library
-- default to ServerStorage's (FindFirstChild only: no endless wait at server start). Returns how many nests changed
-- and the ids skipped.
function HouseNests.sync(root, Layout, kit, library)
	local folder = typeof(root) == "Instance" and root:FindFirstChild("Nests") or nil
	if not folder then return 0, {} end
	local live = type(Layout) == "table" and Layout.NESTS_ENABLED == true
	local changed, skipped = 0, {}
	local Kit, prefabs = kit, library
	for _, house in ipairs(HouseNests.houses(root)) do
		local houseId = house:GetAttribute("HouseId")
		local id = HouseNests.nestId(houseId)
		local at = HouseNests.spot(house:GetPivot(), house:GetAttribute("KitAsset"), house:GetAttribute("KitScale"))
		local boxes = at and HouseNests.boxes(house)
		if not at or HouseNests.blocked(at, boxes) or not HouseNests.floorTop(at, boxes) then
			table.insert(skipped, id)
		else
			local nest = folder:FindFirstChild("Nest_" .. id)
			if nest then
				if (nest:GetPivot().Position - at.Position).Magnitude > 0.5 then
					nest:PivotTo(at)
					changed += 1
				end
				if nest:GetAttribute("Enabled") ~= live then
					nest:SetAttribute("Enabled", live)
					changed += 1
				end
			else
				if not Kit then
					local SS = game:GetService("ServerStorage")
					local module = SS:FindFirstChild("WildboundCandyKit")
					Kit = module and require(module) or nil
				end
				if Kit and not prefabs then
					local assets = game:GetService("ServerStorage"):FindFirstChild("WildboundAssets")
					prefabs = assets and assets:FindFirstChild(Kit.LIBRARY_NAME) or nil
				end
				local ok, made = false, nil
				if Kit and prefabs then ok, made = pcall(Kit.place, prefabs, "Nest", at, HouseNests.NEST_SCALE) end
				if ok and made then
					dress(made, id, HouseNests.rarity(houseId), house, live)
					made.Parent = folder
					changed += 1
				else
					table.insert(skipped, id)
				end
			end
		end
	end
	return changed, skipped
end

return HouseNests

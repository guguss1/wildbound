-- Caramelo v8 on the live map (owner request 2026-11-17: "make the Reino Caramelo map a bit bigger, in width and in
-- length, so there is more space between things ... and another space of the same size, separated by clouds";
-- docs/design/wildbound-caramelo-v8-plan.md, V8-D1 to V8-D4). Studio Edit mode only: run it from the command bar or
-- execute_luau (or task.spawn + loadstring from a StringValue), first with DRY_RUN = true to read the plan, then with
-- DRY_RUN = false. Not deployed as a running script: a one-shot tool, the same pattern as
-- tools/wildbound-caramelo-v5-migrate.luau.
--
-- It runs once, on a map the v5 migration changed (root attribute CaramelV5) and not yet marked CaramelV8 (it returns
-- the summary "already" then). It needs, in ServerStorage: the v8 WildboundCandyLayout (Layout.V8, fromV7World, HALF
-- 260), WildboundCandyV3Layout VERSION 4, WildboundCandyV3Builder (layWater), WildboundCandyBuilder (layPaths, layBoss,
-- layMarkers, syncTower, syncNestPositions, layoutKey), WildboundCandyKit with WildboundAssets.CandyKit,
-- WildboundCandyEast, WildboundCandyDuquesa and WildboundCandyFrutillon. The modules are required from fresh clones.
--
-- The real run (one undo step, ChangeHistoryService recording "CaramelV8") runs in a deferred thread (task.delay),
-- because a call made from inside another recording (execute_luau is one) cannot open its own. Read the result from
-- ServerStorage's attribute WildboundCaramelV8Summary (JSON; "pending" until done) or _G.WildboundCaramelV8Summary.
-- In that thread, in this order (V8-D4):
--   0. backup: clones of Workspace.Candy_Bioma_v1, Workspace.WildboundCandyAnnex_Big4, the queen's preview model and the
--      Pradera marker Workspace.WildboundPradera into
--      ServerStorage.WildboundMapArchive.CaramelV8Backup (an existing one is kept and the summary warns);
--   1. Ground.Floor grows to 2 * HALF square at the new centre (0 new parts);
--   2. every saved model and part under Candy_Bioma_v1 moves by its pivot to Layout.fromV7World (rotation and height
--      kept). A piece the v3 layout names (MountainId, HouseId, PlatformIndex, a CrystalSpot hill, the LicoriceArch,
--      the CakeModular) goes to its v8 layout spot instead (M1 stays on the north edge, V8-D1), the waterfall moves
--      with M1, the GranTorta goes to the layout's Torta with its LayoutKey set to the new key, the Portal to the
--      layout's portal, and the nests are put on their layout spots (syncNestPositions). A piece that would land east of
--      the plot (in the cloud band or the second space: the v4 backdrop) is archived instead;
--   3. archived and laid again from the v8 layout: Paths, Boss with Ground.Plaza, Markers (layPaths, layBoss,
--      layMarkers), CaramelV3's River, Lake, Bridges and Docks (layWater), the Tower with the summit nest (syncTower);
--      runtime folders saved by mistake (HideSpots, LicoriceGrass, CaramelTraps, LakeIslands) are archived (the server
--      plans them again at start); the queen's preview model (Workspace.WildboundNewCandyPreview.DuquesaBurbuja) goes to
--      Duq.seatPivot of the new summit; an Edit raft goes to its home dock;
--   4. the big4 annex (Workspace.WildboundCandyAnnex_Big4): its props inside the bigger plot move into the second space
--      by (x + 536, z) (WildboundCandyEast.annexMove; one that would crowd another prop or stand over SistemaSonriente
--      is archived), props in the cloud band are archived, and its floor slabs, level with the new floors, become the two
--      strips north and south of them (WildboundCandyEast.annexGround: resized, the rest archived; 0 new parts);
--   5. WildboundCandyEast.build lays Workspace.Candy_Este_v1 (the floor and the cloud wall: Floor, Collider, Veil and
--      the two end caps, 5 parts);
--   5b. the Pradera sector marker Workspace.WildboundPradera (an empty Model, a root of its own, read by
--      WildboundBeasts.praderaOrigin) moves by its pivot to Layout.fromV7World (v7 (627, 107) -> (691.5, 140)), so
--      WildboundPraderaSites' x 1.3 OFFSETS put La Nube's pond and La Abeja's hive on the layout's KEEP_CLEAR spots
--      again (V8-D1, fixer); it is backed up with the rest and the dry run reports the move;
--   6. the root's CaramelV8 = 1 (so a second run never moves the marker again).
-- Everything archived is reparented into WildboundMapArchive.CaramelV8Archived (never destroyed). Anything named
-- SistemaSonriente, or under it, is never touched. The JSON summary lists every archive, the snapped pieces, the part
-- counts of the three roots before and after (and, in a dry run, an estimate) and the warnings.
local DRY_RUN = true -- true: only report; false: change the map (one undo step)

local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Edit mode only: stop Play first")
local ServerStorage, Workspace = game:GetService("ServerStorage"), game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local SUMMARY_ATTRIBUTE = "WildboundCaramelV8Summary"
local MARK, NEEDS = "CaramelV8", "CaramelV5"
local BACKUP, ARCHIVED = "CaramelV8Backup", "CaramelV8Archived"
local ANNEX_NAME = "WildboundCandyAnnex_Big4"
local PREVIEW, QUEEN = "WildboundNewCandyPreview", "DuquesaBurbuja"
local PRADERA = "WildboundPradera" -- the Pradera sector marker (WildboundBeasts.praderaOrigin)
local PRADERA_V7 = { x = 627, z = 107 } -- its v7 pivot (WildboundCandyBeastSites_Test S7 on the v7 map)
local RAFT_FOLDER, RAFT_MODEL = "WildboundCandyRaft", "BalsaBananaSplit"
local RELAID = { "Paths", "Boss", "Markers", "Tower" } -- root children archived and laid again
local RUNTIME = { HideSpots = true, LicoriceGrass = true, CaramelTraps = true, LakeIslands = true }
local HANDLED = { Ground = true, Paths = true, Boss = true, Markers = true, Tower = true, GranTorta = true, Portal = true,
	Nests = true, CaramelV3 = true }
local APART = 6 -- a moved annex prop keeps this far (flat, pivot to pivot) from every other prop of the second space

-- A fresh copy of a ModuleScript (never the session's cached require), or nil.
local function module(parent, name)
	local found = parent and parent:FindFirstChild(name)
	if not (found and found:IsA("ModuleScript")) then return nil end
	local ok, value = pcall(function() return require(found:Clone()) end)
	if ok then return value end
	return require(found)
end
local function forbidden(instance)
	return instance.Name == "SistemaSonriente" or instance:FindFirstAncestor("SistemaSonriente") ~= nil
end
local function countParts(instance)
	if not instance then return 0 end
	local n = 0
	for _, d in ipairs(instance:GetDescendants()) do
		if d:IsA("BasePart") then n += 1 end
	end
	return n
end
local function publish(summary)
	local json = HttpService:JSONEncode(summary)
	_G.WildboundCaramelV8Summary = summary
	pcall(function() ServerStorage:SetAttribute(SUMMARY_ATTRIBUTE, json) end)
	print("CaramelV8 " .. json)
	return json
end
local function sortedChildren(parent)
	local list = parent and parent:GetChildren() or {}
	table.sort(list, function(a, b) return a.Name < b.Name end)
	return list
end

local Layout = module(ServerStorage, "WildboundCandyLayout")
assert(Layout and type(Layout.V8) == "table" and type(Layout.fromV7World) == "function" and Layout.HALF == 260,
	"deploy the v8 WildboundCandyLayout (Layout.V8, fromV7World, HALF 260) first")
local V3 = module(ServerStorage, "WildboundCandyV3Layout")
assert(V3 and V3.VERSION == 4, "deploy the v8 ServerStorage.WildboundCandyV3Layout (VERSION 4) first")
local V3Builder = module(ServerStorage, "WildboundCandyV3Builder")
assert(V3Builder and type(V3Builder.layWater) == "function", "deploy ServerStorage.WildboundCandyV3Builder (layWater) first")
local Builder = module(ServerStorage, "WildboundCandyBuilder")
assert(Builder and type(Builder.layPaths) == "function" and type(Builder.layBoss) == "function"
	and type(Builder.layMarkers) == "function" and type(Builder.syncTower) == "function"
	and type(Builder.syncNestPositions) == "function" and type(Builder.layoutKey) == "function",
	"deploy ServerStorage.WildboundCandyBuilder (layPaths, layBoss, layMarkers, syncTower, syncNestPositions) first")
local Kit = module(ServerStorage, "WildboundCandyKit")
assert(Kit, "ServerStorage.WildboundCandyKit is missing")
local assets = ServerStorage:FindFirstChild("WildboundAssets")
local library = assets and assets:FindFirstChild(Kit.LIBRARY_NAME)
assert(library, "ServerStorage.WildboundAssets." .. Kit.LIBRARY_NAME .. " is missing")
local East = module(ServerStorage, "WildboundCandyEast")
assert(East and type(East.build) == "function" and type(East.annexGround) == "function", "deploy ServerStorage.WildboundCandyEast first")
local Duq = module(ServerStorage, "WildboundCandyDuquesa")
local Frut = module(ServerStorage, "WildboundCandyFrutillon")
assert(Duq and type(Duq.seatPivot) == "function" and Frut and type(Frut.summit) == "function",
	"ServerStorage.WildboundCandyDuquesa (seatPivot) and WildboundCandyFrutillon are needed")
local root = Workspace:FindFirstChild(Layout.ROOT_NAME)
assert(root, "Workspace." .. Layout.ROOT_NAME .. " is missing")
assert(not forbidden(root), "refusing to touch SistemaSonriente")
assert(root:GetAttribute(V3.MARK) ~= nil and root:FindFirstChild(V3.FOLDER),
	"run tools/wildbound-caramelo-v3-migrate.luau first (no CaramelV3 on the map)")
assert(root:GetAttribute(V3.V5_MARK or NEEDS) ~= nil, "run tools/wildbound-caramelo-v5-migrate.luau first (no CaramelV5 mark)")

local annex = Workspace:FindFirstChild(ANNEX_NAME)
if annex and forbidden(annex) then annex = nil end
local preview = Workspace:FindFirstChild(PREVIEW)
local queen = preview and preview:FindFirstChild(QUEEN)
if queen and (not queen:IsA("Model") or forbidden(queen)) then queen = nil end
local pradera = Workspace:FindFirstChild(PRADERA)
if pradera and (not (pradera:IsA("Model") or pradera:IsA("BasePart")) or forbidden(pradera)) then pradera = nil end

local deps = { Layout = Layout, V3 = V3 }
local P = East.plan(Layout)
local summary = { dryRun = DRY_RUN, already = false, version = V3.VERSION, half = Layout.HALF, archived = {}, snapped = {},
	moved = {}, warnings = {}, cap = V3.BIOME_PART_CAP,
	partsBefore = { bioma = countParts(root), annex = countParts(annex), east = countParts(Workspace:FindFirstChild(East.ROOT_NAME)) } }

if root:GetAttribute(MARK) ~= nil then
	summary.already = true
	summary.mark = root:GetAttribute(MARK)
	publish(summary)
	return summary
end

-- The plan (read only) ---------------------------------------------------------------------------------------------

-- A pivot moved to (x, z) in world studs, its turn and height kept.
local function slid(pivot, x, z)
	return CFrame.new(x - pivot.X, 0, z - pivot.Z) * pivot
end
local function byId(list, id)
	for _, s in ipairs(list) do
		if s.id == id then return s end
	end
	return nil
end
-- The v8 layout spot (plot coordinates) of a CaramelV3 piece the layout names, by its folder, or nil.
local SPOTS = {
	Mountains = function(m) return byId(V3.MOUNTAINS, m:GetAttribute("MountainId")) end,
	Houses = function(m) return byId(V3.HOUSES, m:GetAttribute("HouseId")) end,
	Platforms = function(m)
		local i = m:GetAttribute("PlatformIndex")
		return type(i) == "number" and V3.PLATFORMS[i] or nil
	end,
	EdgeHills = function(m) return m:GetAttribute("CrystalSpot") and byId(V3.CRYSTAL_HILLS, m.Name) or nil end,
	Licorice = function(m) return m.Name == "LicoriceArch" and V3.LICORICE or nil end,
	Cake = function(m) return m.Name == "CakeModular" and V3.CAKE or nil end,
}
local EAST_EDGE = Layout.CENTRE.x + Layout.HALF

local function makePlan()
	local plan = { moves = {}, archive = {}, snapped = {}, counts = {}, total = 0 }
	local function archive(instance, why)
		if not forbidden(instance) then table.insert(plan.archive, { instance = instance, why = why }) end
	end
	local function move(instance, cf, label)
		table.insert(plan.moves, { instance = instance, to = cf })
		plan.counts[label] = (plan.counts[label] or 0) + 1
		plan.total += 1
	end
	-- one piece: a layout spot when it has one (or a fixed target), else its scaled pivot; archived east of the plot
	local m1Delta = nil
	local function place(instance, label, spot, fixed)
		if forbidden(instance) or not (instance:IsA("Model") or instance:IsA("BasePart")) then return end
		local pivot = instance:GetPivot()
		local sx, sz = Layout.fromV7World(pivot.X, pivot.Z)
		local tx, tz = sx, sz
		local finder = spot and SPOTS[spot]
		local s = finder and finder(instance)
		if fixed then
			tx, tz = fixed.x, fixed.z
		elseif s then
			tx, tz = Layout.CENTRE.x + s.x, Layout.CENTRE.z + s.z
		end
		if fixed or s then
			table.insert(plan.snapped, ("%s -> layout spot (%.1f, %.1f), %.1f studs from its scaled pivot"):format(
				instance:GetFullName(), tx, tz, math.sqrt((tx - sx) ^ 2 + (tz - sz) ^ 2)))
		end
		if instance:GetAttribute("MountainId") == "M1" then m1Delta = { x = tx - pivot.X, z = tz - pivot.Z } end
		if tx > EAST_EDGE + 1e-6 then
			archive(instance, ("would stand east of the plot at x %.1f (the cloud band or the second space)"):format(tx))
			return
		end
		move(instance, slid(pivot, tx, tz), label)
	end
	local function walk(folder, label)
		for _, c in ipairs(sortedChildren(folder)) do
			if forbidden(c) then continue end
			if RUNTIME[c.Name] then
				archive(c, "planned again at server start")
			elseif c:IsA("Folder") then
				walk(c, label .. "." .. c.Name)
			else
				place(c, label, folder.Name)
			end
		end
	end
	-- the root's own children
	for _, c in ipairs(sortedChildren(root)) do
		if forbidden(c) or HANDLED[c.Name] then continue end
		if RUNTIME[c.Name] then
			archive(c, "planned again at server start")
		elseif c:IsA("Folder") then
			walk(c, c.Name)
		else
			place(c, "root")
		end
	end
	-- relaid: Paths, Boss, Markers, Tower, Ground.Plaza, the summit nest
	for _, name in ipairs(RELAID) do
		local old = root:FindFirstChild(name)
		if old then archive(old, "laid again for layout v8") end
	end
	local ground = root:FindFirstChild("Ground")
	for _, c in ipairs(sortedChildren(ground)) do
		if c.Name == "Plaza" then
			archive(c, "laid again for layout v8")
		elseif c.Name ~= "Floor" then
			place(c, "Ground")
		end
	end
	local summit = Layout.TOWER.summit
	local nests = root:FindFirstChild("Nests")
	for _, c in ipairs(sortedChildren(nests)) do
		if summit and c.Name == "Nest_" .. summit.id then
			archive(c, "laid again with the Tower (syncTower)")
		else
			place(c, "Nests")
		end
	end
	-- the GranTorta and the Portal: the layout's spots
	local torta = root:FindFirstChild("GranTorta")
	if torta then place(torta, "GranTorta", nil, { x = Layout.CENTRE.x + Layout.TORTA.x, z = Layout.CENTRE.z + Layout.TORTA.z }) end
	local portal = root:FindFirstChild("Portal")
	if portal then place(portal, "Portal", nil, { x = Layout.CENTRE.x + Layout.PORTAL.x, z = Layout.CENTRE.z + Layout.PORTAL.z }) end
	-- CaramelV3: the water is laid again; the mountains first (M1 carries the waterfall), then the rest
	local holder = root:FindFirstChild(V3.FOLDER)
	local water = {}
	for _, name in ipairs(V3Builder.WATER_FOLDERS or { "River", "Lake", "Bridges", "Docks" }) do water[name] = true end
	local mountains = holder and holder:FindFirstChild("Mountains")
	if mountains then walk(mountains, V3.FOLDER .. ".Mountains") end
	for _, c in ipairs(sortedChildren(holder)) do
		if forbidden(c) or c == mountains then continue end
		if water[c.Name] then
			archive(c, "laid again for layout v8 (layWater)")
		elseif RUNTIME[c.Name] then
			archive(c, "planned again at server start")
		elseif c.Name == "Waterfall" and (c:IsA("Model") or c:IsA("BasePart")) then
			local pivot = c:GetPivot()
			if m1Delta then
				place(c, V3.FOLDER, nil, { x = pivot.X + m1Delta.x, z = pivot.Z + m1Delta.z })
			else
				place(c, V3.FOLDER)
			end
		elseif c:IsA("Folder") then
			walk(c, V3.FOLDER .. "." .. c.Name)
		else
			place(c, V3.FOLDER)
		end
	end
	return plan
end

-- SistemaSonriente's parts as { x, z, r } (half their flat size plus 4), read only.
local function sonriente()
	local out = {}
	local s = Workspace:FindFirstChild("SistemaSonriente")
	for _, d in ipairs(s and s:GetDescendants() or {}) do
		if d:IsA("BasePart") then
			table.insert(out, { x = d.Position.X, z = d.Position.Z, r = math.max(d.Size.X, d.Size.Z) / 2 + 4, name = d:GetFullName() })
		end
	end
	return out
end

-- The big4 annex: its props and floor slabs (V8-D4 step 4).
local function annexPlan(avoid)
	local plan = { moves = {}, archive = {}, resize = {}, kept = 0, notes = {} }
	if not annex then return plan end
	local function archive(instance, why)
		if not forbidden(instance) then table.insert(plan.archive, { instance = instance, why = why }) end
	end
	-- floor slabs: axis-aligned parts of annex.Ground
	local slabs, byName = {}, {}
	local ground = annex:FindFirstChild("Ground")
	for _, part in ipairs(sortedChildren(ground)) do
		if part:IsA("BasePart") and not forbidden(part) then
			local o = part.Orientation
			if math.abs(o.X) > 0.01 or math.abs(o.Z) > 0.01 or math.abs(o.Y % 180) > 0.01 then
				table.insert(plan.notes, part:GetFullName() .. " is turned: left as it is")
			elseif byName[part.Name] then
				table.insert(plan.notes, part:GetFullName() .. " shares its name with another slab: left as it is")
			else
				local p, s = part.Position, part.Size
				local sx, sz = s.X, s.Z
				byName[part.Name] = part
				table.insert(slabs, { name = part.Name, minX = p.X - sx / 2, maxX = p.X + sx / 2, minZ = p.Z - sz / 2, maxZ = p.Z + sz / 2 })
			end
		end
	end
	local g = East.annexGround(Layout, slabs)
	for _, r in ipairs(g.resize) do table.insert(plan.resize, { instance = byName[r.name], rect = r.rect }) end
	for _, name in ipairs(g.archive) do archive(byName[name], "a floor slab the new floors cover") end
	for _, name in ipairs(g.overlap) do
		table.insert(plan.notes, byName[name]:GetFullName() .. " still meets the new floors (left as it is)")
	end
	-- props: the ones already in the second space stay; the ones in the plot move there; the band's are archived
	local taken, candidates = {}, {}
	local props = annex:FindFirstChild("Props")
	for _, c in ipairs(sortedChildren(props)) do
		if forbidden(c) or not (c:IsA("Model") or c:IsA("BasePart")) then continue end
		local pivot = c:GetPivot()
		local kind, nx, nz = East.annexMove(Layout, pivot.X, pivot.Z)
		if kind == "move" then
			table.insert(candidates, { instance = c, pivot = pivot, x = nx, z = nz })
		elseif kind == "band" then
			archive(c, "stands in the cloud band")
		else
			plan.kept += 1
			if East.inside(P.space, pivot.X, pivot.Z) then table.insert(taken, { x = pivot.X, z = pivot.Z }) end
		end
	end
	for _, item in ipairs(candidates) do
		local why = nil
		for _, a in ipairs(avoid) do
			if math.sqrt((item.x - a.x) ^ 2 + (item.z - a.z) ^ 2) < a.r then why = "would stand over " .. a.name break end
		end
		if not why then
			for _, t in ipairs(taken) do
				if math.sqrt((item.x - t.x) ^ 2 + (item.z - t.z) ^ 2) < APART then
					why = ("would crowd a prop at (%.1f, %.1f)"):format(t.x, t.z)
					break
				end
			end
		end
		if why then
			archive(item.instance, why)
		else
			table.insert(taken, { x = item.x, z = item.z })
			table.insert(plan.moves, { instance = item.instance, to = slid(item.pivot, item.x, item.z) })
		end
	end
	return plan
end

-- The queen's preview model on the new summit (Duq.seatPivot, facing the junction), as a CFrame, or nil.
local function queenFrame()
	if not queen then return nil end
	local s = Duq.seatPivot(Frut.summit(Layout), { x = Layout.CENTRE.x + Layout.JUNCTION.x, z = Layout.CENTRE.z + Layout.JUNCTION.z })
	return CFrame.new(s.x, s.y, s.z) * CFrame.Angles(0, s.yaw, 0)
end
-- The raft's home dock (the v5 rule on the v8 layout) and an Edit raft model, if one stands in the place.
local function homeDock()
	local d = V3.DOCKS[V3.RAFT.homeDock] or V3.DOCKS[1]
	local x, z = Layout.CENTRE.x + d.tipX, Layout.CENTRE.z + d.tipZ
	local yaw = math.atan2(-(d.tipX - d.standX), -(d.tipZ - d.standZ))
	return CFrame.new(x, V3.surfaceY(Layout.FLOOR_TOP), z) * CFrame.Angles(0, yaw, 0), d.id
end
local function raftModel()
	local f = Workspace:FindFirstChild(RAFT_FOLDER)
	local m = f and f:FindFirstChild(RAFT_MODEL)
	if m and m:IsA("Model") and not forbidden(m) then return m end
	return nil
end
-- V8-D1 (fixer): the Pradera sector marker's move, { to = CFrame, line } or nil (no marker). The offsets of
-- WildboundPraderaSites are x 1.3 and are added to this pivot, so it moves with the plot like any v7 world point.
local function praderaMove()
	if not pradera then return nil end
	local pv = pradera:GetPivot()
	local nx, nz = Layout.fromV7World(pv.X, pv.Z)
	return { to = slid(pv, nx, nz), line = ("(%.1f, %.1f) -> (%.1f, %.1f)"):format(pv.X, pv.Z, nx, nz),
		v7 = math.sqrt((pv.X - PRADERA_V7.x) ^ 2 + (pv.Z - PRADERA_V7.z) ^ 2) <= 1 }
end

-- What the summary says about a plan (the same lines in the dry run and the real run).
local function describe(plan, aPlan, avoid)
	summary.moved = plan.counts
	summary.movedTotal = plan.total
	summary.snapped = plan.snapped
	local archivedParts = 0
	for _, a in ipairs(plan.archive) do
		table.insert(summary.archived, a.instance:GetFullName() .. ": " .. a.why)
		archivedParts += countParts(a.instance)
	end
	summary.annex = { found = annex ~= nil, moved = #aPlan.moves, kept = aPlan.kept, archived = #aPlan.archive,
		resized = {}, notes = aPlan.notes }
	for _, a in ipairs(aPlan.archive) do table.insert(summary.archived, a.instance:GetFullName() .. ": " .. a.why) end
	for _, r in ipairs(aPlan.resize) do
		table.insert(summary.annex.resized, ("%s -> x %g..%g, z %g..%g"):format(r.instance:GetFullName(), r.rect.minX, r.rect.maxX,
			r.rect.minZ, r.rect.maxZ))
	end
	if not annex then table.insert(summary.warnings, "no Workspace." .. ANNEX_NAME .. ": the annex is left as it is") end
	local ground = root:FindFirstChild("Ground")
	local floor = ground and ground:FindFirstChild("Floor")
	if floor and floor:IsA("BasePart") then
		summary.floor = ("%g x %g at (%.1f, %.1f) -> %g x %g at (%g, %g)"):format(floor.Size.X, floor.Size.Z, floor.Position.X,
			floor.Position.Z, Layout.HALF * 2, Layout.HALF * 2, Layout.CENTRE.x, Layout.CENTRE.z)
	else
		table.insert(summary.warnings, "no Candy_Bioma_v1.Ground.Floor part: the floor is not grown")
	end
	local _, dockId = homeDock()
	summary.raft = raftModel() and ("an Edit raft: to dock " .. dockId) or ("none in Edit: the service builds it at dock " .. dockId)
	summary.queen = queen and "to the new summit (Duq.seatPivot)" or ("no Workspace." .. PREVIEW .. "." .. QUEEN)
	local pm = praderaMove()
	if pm then
		summary.pradera = pm.line
		if not pm.v7 then
			local text = "Workspace.%s is not at its v7 pivot (%g, %g): it still moves by fromV7World; check the Pradera sites (BeastSites S7)"
			table.insert(summary.warnings, text:format(PRADERA, PRADERA_V7.x, PRADERA_V7.z))
		end
	else
		summary.pradera = "no Workspace." .. PRADERA .. " marker"
		table.insert(summary.warnings, "no Workspace." .. PRADERA .. ": the Pradera sites fall back to Sites.MEADOW_CENTRE")
	end
	for _, a in ipairs(avoid) do
		if East.inside(P.ground, a.x, a.z) or East.inside(P.plot, a.x, a.z) then
			table.insert(summary.warnings, a.name .. " stands on the new floors (never touched)")
		end
	end
	return archivedParts
end

-- The relaid pieces of the v8 layout, laid into a detached scratch model (never parented: the map is untouched).
local function probe()
	local scratch = Instance.new("Model")
	local holder = Instance.new("Folder")
	holder.Name = V3.FOLDER
	holder.Parent = scratch
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = scratch
	local out = {}
	out.paths = select(2, Builder.layPaths(scratch, Layout))
	out.boss = select(2, Builder.layBoss(scratch, Layout))
	out.markers = select(2, Builder.layMarkers(scratch, Layout))
	out.water = V3Builder.layWater(scratch, deps).parts
	out.east = select(2, East.build(scratch, Layout)).parts
	scratch:Destroy()
	return out
end

if DRY_RUN then
	local plan = makePlan()
	local avoid = sonriente()
	local aPlan = annexPlan(avoid)
	local archivedParts = describe(plan, aPlan, avoid)
	local ok, laid = pcall(probe)
	if ok then
		summary.relaid = laid
		local tower = root:FindFirstChild("Tower")
		local towerParts = countParts(tower)
		local summitNest = root:FindFirstChild("Nests") and root.Nests:FindFirstChild("Nest_" .. Layout.TOWER.summit.id)
		towerParts += countParts(summitNest)
		summary.relaid.towerEstimate = towerParts
		summary.partsEstimate = {
			bioma = summary.partsBefore.bioma - archivedParts + laid.paths + laid.boss + laid.markers + laid.water + towerParts,
			east = laid.east,
		}
		summary.overCap = summary.partsEstimate.bioma > V3.BIOME_PART_CAP
	else
		summary.relaid = { error = tostring(laid) }
	end
	publish(summary)
	return summary
end

-- The real run, in its own thread and its own recording.
pcall(function() ServerStorage:SetAttribute(SUMMARY_ATTRIBUTE, "pending") end)
_G.WildboundCaramelV8Summary = nil
task.delay(0.5, function()
	local recording
	local opened = pcall(function() recording = ChangeHistoryService:TryBeginRecording("CaramelV8") end)
	if not (opened and recording) then
		summary.error = "could not open a ChangeHistoryService recording (another one open?): nothing was changed"
		publish(summary)
		return
	end
	local ok, failure = pcall(function()
		local archiveRoot = ServerStorage:FindFirstChild("WildboundMapArchive")
		if not archiveRoot then
			archiveRoot = Instance.new("Folder")
			archiveRoot.Name = "WildboundMapArchive"
			archiveRoot.Parent = ServerStorage
		end
		local archived = archiveRoot:FindFirstChild(ARCHIVED)
		if not archived then
			archived = Instance.new("Folder")
			archived.Name = ARCHIVED
			archived.Parent = archiveRoot
		end
		-- 0. backup
		if archiveRoot:FindFirstChild(BACKUP) then
			summary.backup = "kept the existing " .. BACKUP
			table.insert(summary.warnings, "an older " .. BACKUP .. " was kept: check it before any restore")
		else
			local holder = Instance.new("Folder")
			holder.Name = BACKUP
			for _, original in pairs({ root, annex, queen, pradera }) do -- pairs: annex, queen or pradera may be nil
				if original then
					local copy = original:Clone()
					if copy then copy.Parent = holder end
				end
			end
			holder.Parent = archiveRoot
			summary.backup = holder:GetFullName()
		end
		-- the plans, read before anything changes
		local plan = makePlan()
		local avoid = sonriente()
		local aPlan = annexPlan(avoid)
		describe(plan, aPlan, avoid)
		local function archive(instance)
			if instance and not forbidden(instance) then instance.Parent = archived end
		end
		-- 1. the floor
		local ground = root:FindFirstChild("Ground")
		local floor = ground and ground:FindFirstChild("Floor")
		if floor and floor:IsA("BasePart") then
			floor.Size = Vector3.new(Layout.HALF * 2, floor.Size.Y, Layout.HALF * 2)
			floor.CFrame = CFrame.new(Layout.CENTRE.x, floor.Position.Y, Layout.CENTRE.z)
		end
		-- 2 and 3. archive what is laid again (and runtime folders and pieces east of the plot), then move the rest
		for _, a in ipairs(plan.archive) do archive(a.instance) end
		for _, m in ipairs(plan.moves) do m.instance:PivotTo(m.to) end
		local torta = root:FindFirstChild("GranTorta")
		if torta then torta:SetAttribute("LayoutKey", Builder.layoutKey(Layout)) end
		local relaid = {}
		relaid.boss = select(2, Builder.layBoss(root, Layout))
		relaid.paths = select(2, Builder.layPaths(root, Layout))
		relaid.markers = select(2, Builder.layMarkers(root, Layout))
		relaid.water = V3Builder.layWater(root, deps).parts
		relaid.tower = torta and Builder.syncTower(root, Layout, Kit, library) or 0
		if not torta then table.insert(summary.warnings, "no GranTorta: the Tower was not laid again") end
		summary.relaid = relaid
		summary.nestsMoved = root:FindFirstChild("Nests") and Builder.syncNestPositions(root, Layout) or {}
		-- the queen's preview model and an Edit raft
		local qf = queenFrame()
		if qf then queen:PivotTo(qf) end
		local raft = raftModel()
		if raft then raft:PivotTo((homeDock())) end
		-- 4. the annex
		for _, a in ipairs(aPlan.archive) do archive(a.instance) end
		for _, m in ipairs(aPlan.moves) do m.instance:PivotTo(m.to) end
		for _, r in ipairs(aPlan.resize) do
			local part, rr = r.instance, r.rect
			part.Size = Vector3.new(rr.maxX - rr.minX, part.Size.Y, rr.maxZ - rr.minZ)
			part.CFrame = CFrame.new((rr.minX + rr.maxX) / 2, part.Position.Y, (rr.minZ + rr.maxZ) / 2)
		end
		-- 5. Caramelo Este
		local _, report = East.build(Workspace, Layout)
		summary.east = report
		-- 5b. the Pradera sector marker, with the plot (V8-D1, fixer)
		local pm = praderaMove()
		if pm then pradera:PivotTo(pm.to) end
		-- 6. mark
		root:SetAttribute(MARK, 1)
	end)
	ChangeHistoryService:FinishRecording(recording,
		ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
	if not ok then summary.error = "failed and undone: " .. tostring(failure) end
	summary.partsAfter = { bioma = countParts(root), annex = countParts(annex), east = countParts(Workspace:FindFirstChild(East.ROOT_NAME)) }
	summary.overCap = summary.partsAfter.bioma > V3.BIOME_PART_CAP
	publish(summary)
end)
print("CaramelV8: scheduled; read ServerStorage:GetAttribute(\"" .. SUMMARY_ATTRIBUTE .. "\") in a few seconds")
return { scheduled = true, dryRun = false, summaryAttribute = SUMMARY_ATTRIBUTE }

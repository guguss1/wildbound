-- Caramelo v9 on the live map (owner request 2026-11-18: "y agranda mas el bioma caramelo a lo largo, el rio necesito
-- qeu sea 5 veces su ancho asi es navegable por la balsa"; docs/design/wildbound-caramelo-v9-plan.md CL-D17 and its
-- "Migration" section). Studio Edit mode only: run it from the command bar or execute_luau (or task.spawn + loadstring
-- from a StringValue), first with DRY_RUN = true to read the plan, then with DRY_RUN = false. Kept in Studio as the
-- disabled Script ServerStorage.WildboundCaramelV9Migrate: a one-shot tool, the same pattern as
-- tools/wildbound-caramelo-v8-migrate.luau. Its source is pinned by WildboundCandyV9Migrate_Test.
--
-- It runs once, on a map the v8 migration changed (root attribute CaramelV8) and not yet marked CaramelV9 (it returns the
-- summary "already" then). It needs, in ServerStorage: the v9 WildboundCandyLayout (VERSION 3, EAST 860, HALF 260, the
-- Torta at local x 748.2), WildboundCandyV3Layout VERSION 5 (V9.EAST 860, V9_PART_TARGET), WildboundCandyV3Builder
-- (planV5, layAll, WATER_FOLDERS), WildboundCandyBuilder (layPaths, layBoss, layMarkers, syncTower, syncNests,
-- syncNestPositions, layoutKey, treeKeepOut), WildboundCandyV3KitSpec, WildboundCandyKit with WildboundAssets.CandyKit
-- (and CandyKitV3 for the kit pieces), WildboundCandyEast (build, stripPlan), WildboundCandyDuquesa (seatPivot) and
-- WildboundCandyFrutillon; and the v9 ServerScriptService.WildboundPraderaSites (FIXED.candyPostE4), so that
-- treeKeepOut keeps the fill off the new creature posts. The modules are required from fresh clones.
--
-- Refusals, in the dry run and the real run alike (nothing is changed, the summary lists them under "refused"):
--   any part of SistemaSonriente meets world x 932..1616, z -307..301 (the growth area, the stretched strips and their
--   walls); SistemaSonriente is never touched anywhere;
--   the two big4 annex strips (Workspace.WildboundCandyAnnex_Big4.Ground) are not both found (East.stripPlan);
--   the part estimate of Candy_Bioma_v1 is above V3.V9_PART_TARGET (or the probe failed).
--
-- The plan (read only; the dry run prints it):
--   P1. archive Paths, Boss, Markers, Tower, Ground.Plaza and the summit nest, and any runtime folder saved by mistake
--       (HideSpots, LicoriceGrass, CaramelTraps, LakeIslands);
--   P2. archive V3Builder.planV5(root, Layout, V3) under the v9 layout: the water folders, and every Trees, Filler or
--       EdgeFill model and old kit prop now standing in the v9 chocolate, on or by a bridge, or on a piece or hill;
--   P3. archive every other CaramelV3 child but Trees (the layAll relay lays them again);
--   P4. archive every annex prop whose pivot lies in the growth area (world x 932..1532, z -263..257);
--   P5. list anything else standing in the growth area as a warning (not touched);
--   P6. probe: lay Paths, Boss, Markers, layAll and Caramelo Este into a detached scratch model, count, destroy it (the
--       tool's only Destroy); estimate = partsBefore - archived + relaid + the Tower (its live count, else 126).
--
-- The real run (one undo step, ChangeHistoryService recording "CaramelV9") runs in a deferred thread (task.delay),
-- because a call made from inside another recording (execute_luau is one) cannot open its own. Read the result from
-- ServerStorage's attribute WildboundCaramelV9Summary (JSON; "pending" until done) or _G.WildboundCaramelV9Summary.
-- In that thread, after the same survey and refusals, in this order:
--   0. backup: clones of Workspace.Candy_Bioma_v1, Candy_Este_v1, WildboundCandyAnnex_Big4 and the queen's preview model
--      into ServerStorage.WildboundMapArchive.CaramelV9Backup (an existing one is kept and the summary warns);
--   1. Ground.Floor grows to (HALF + EAST) x 2 * HALF, world (1120, 1, 520) at (972, 0, -3) (0 new parts);
--   2. the plan's archive goes to WildboundMapArchive.CaramelV9Archived (reparented, never destroyed);
--   3. the GranTorta slides by its pivot to the layout's Torta, world (1420.2, -3), its LayoutKey set to the new key;
--   4. layBoss, layPaths (6 routes), layMarkers; V3Builder.layAll with relay = true (mountains with M1 at 0.75 and its
--      waterfall, the river with its pool, the lake and basins, 3 raised bridges with piers, 4 docks, 10 houses, the
--      licorice, the cake, the platforms, bank filler, pink hills, edge and interior fill; the old Trees are kept);
--      syncTower (Tower and T1); syncNestPositions (C6, C8, C10, C13); syncNests (the 17 new markers);
--   5. the queen's preview model goes to Duq.seatPivot of the new summit; an Edit raft goes to its home dock;
--   6. East.stripPlan: both annex strips are resized to x 412..1612, their z kept;
--   7. East.build(Workspace, Layout, V3): Caramelo Este's 5 parts conformed and 5 created;
--   8. the root's CaramelV9 = 1 and the summary (archived, relaid, created, partsBefore, partsAfter, estimate, target,
--      overCap); a second East.build must report created 0 and changed 0.
-- A failure is cancelled (FinishRecording Cancel); Ctrl+Z undoes a committed run in the same session.
--
-- RESTORE = true (with DRY_RUN = false): needs the CaramelV9 mark and CaramelV9Backup. In one recording,
-- "CaramelV9Restore", the live roots the backup holds move into WildboundMapArchive.CaramelV9Reverted and the backups
-- are cloned back in their place. It goes with a git revert of the v9 modules. With DRY_RUN = true it only reports.
-- Anything named SistemaSonriente, or under it, is never touched.

-- true: only report; false: change the map (one undo step)
local DRY_RUN = true
-- true: put CaramelV9Backup back instead of migrating (needs the CaramelV9 mark and the backup)
local RESTORE = false

local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Edit mode only: stop Play first")
local ServerStorage, Workspace = game:GetService("ServerStorage"), game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local SUMMARY_ATTRIBUTE = "WildboundCaramelV9Summary"
local MARK, NEEDS = "CaramelV9", "CaramelV8"
local BACKUP, ARCHIVED, REVERTED = "CaramelV9Backup", "CaramelV9Archived", "CaramelV9Reverted"
local ARCHIVE_ROOT = "WildboundMapArchive"
-- the roots RESTORE needs by name (it requires no module)
local ROOT_NAME = "Candy_Bioma_v1"
local ANNEX_NAME = "WildboundCandyAnnex_Big4"
local PREVIEW, QUEEN = "WildboundNewCandyPreview", "DuquesaBurbuja"
local RAFT_FOLDER, RAFT_MODEL = "WildboundCandyRaft", "BalsaBananaSplit"
local RELAID = { "Paths", "Boss", "Markers", "Tower" }
local RUNTIME = { HideSpots = true, LicoriceGrass = true, CaramelTraps = true, LakeIslands = true }
-- world box SistemaSonriente must stay out of: the growth area, the stretched strips and their side and end walls
local SONRIENTE_BOX = { minX = 932, maxX = 1616, minZ = -307, maxZ = 301 }
-- the Tower's part count when the map has none to measure (plan "Part budget")
local TOWER_PARTS = 126

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
	_G.WildboundCaramelV9Summary = summary
	pcall(function() ServerStorage:SetAttribute(SUMMARY_ATTRIBUTE, json) end)
	print("CaramelV9 " .. json)
	return json
end
local function sortedChildren(parent)
	local list = parent and parent:GetChildren() or {}
	table.sort(list, function(a, b) return a.Name < b.Name end)
	return list
end
local function folderIn(parent, name)
	local found = parent:FindFirstChild(name)
	if found then return found end
	local made = Instance.new("Folder")
	made.Name = name
	made.Parent = parent
	return made
end
-- A pivot moved to (x, z) in world studs, its turn and height kept.
local function slid(pivot, x, z)
	return CFrame.new(x - pivot.X, 0, z - pivot.Z) * pivot
end
local function inRect(r, x, z)
	return x >= r.minX and x <= r.maxX and z >= r.minZ and z <= r.maxZ
end

-- RESTORE: the backup back in place of the live roots (no module needed) ---------------------------------------------

if RESTORE then
	local summary = { restore = true, dryRun = DRY_RUN, restored = {}, reverted = {}, warnings = {} }
	local live = Workspace:FindFirstChild(ROOT_NAME)
	assert(live and not forbidden(live), "Workspace." .. ROOT_NAME .. " is missing")
	assert(live:GetAttribute(MARK) ~= nil, "RESTORE needs the " .. MARK .. " mark: this map was never migrated to v9")
	local archiveRoot = ServerStorage:FindFirstChild(ARCHIVE_ROOT)
	local backup = archiveRoot and archiveRoot:FindFirstChild(BACKUP)
	assert(backup and backup:FindFirstChild(ROOT_NAME),
		"RESTORE needs ServerStorage." .. ARCHIVE_ROOT .. "." .. BACKUP .. " holding " .. ROOT_NAME)
	-- where a backup copy goes back: the queen into her preview model, every other root into Workspace
	local function home(copy)
		if copy.Name == QUEEN then return Workspace:FindFirstChild(PREVIEW) end
		return Workspace
	end
	if DRY_RUN then
		for _, copy in ipairs(sortedChildren(backup)) do
			local parent = home(copy)
			if forbidden(copy) then
				table.insert(summary.warnings, copy:GetFullName() .. " is SistemaSonriente: left as it is")
			elseif parent then
				table.insert(summary.restored, copy.Name .. " -> " .. parent:GetFullName())
			else
				table.insert(summary.warnings, "no Workspace." .. PREVIEW .. ": " .. copy.Name .. " would not be restored")
			end
		end
		publish(summary)
		return summary
	end
	pcall(function() ServerStorage:SetAttribute(SUMMARY_ATTRIBUTE, "pending") end)
	_G.WildboundCaramelV9Summary = nil
	task.delay(0.5, function()
		local recording
		local opened = pcall(function() recording = ChangeHistoryService:TryBeginRecording("CaramelV9Restore") end)
		if not (opened and recording) then
			summary.error = "could not open a ChangeHistoryService recording (another one open?): nothing was changed"
			publish(summary)
			return
		end
		local ok, failure = pcall(function()
			local reverted = folderIn(archiveRoot, REVERTED)
			if #reverted:GetChildren() > 0 then
				table.insert(summary.warnings, "an older " .. REVERTED .. " was kept: this restore's roots are beside it")
			end
			for _, copy in ipairs(sortedChildren(backup)) do
				if forbidden(copy) then continue end
				local parent = home(copy)
				if not parent then
					table.insert(summary.warnings, "no Workspace." .. PREVIEW .. ": " .. copy.Name .. " was not restored")
					continue
				end
				local current = parent:FindFirstChild(copy.Name)
				assert(not (current and forbidden(current)), "refusing to touch SistemaSonriente")
				if current then
					table.insert(summary.reverted, current:GetFullName())
					current.Parent = reverted
				end
				local fresh = copy:Clone()
				fresh.Parent = parent
				table.insert(summary.restored, fresh:GetFullName())
			end
		end)
		ChangeHistoryService:FinishRecording(recording,
			ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
		if not ok then summary.error = "failed and undone: " .. tostring(failure) end
		publish(summary)
	end)
	print("CaramelV9Restore: scheduled; read ServerStorage:GetAttribute(\"" .. SUMMARY_ATTRIBUTE .. "\") in a few seconds")
	return { scheduled = true, restore = true, dryRun = false, summaryAttribute = SUMMARY_ATTRIBUTE }
end

-- Modules and guards -------------------------------------------------------------------------------------------------

local Layout = module(ServerStorage, "WildboundCandyLayout")
assert(Layout and Layout.VERSION == 3 and Layout.EAST == 860 and Layout.HALF == 260 and type(Layout.V9) == "table"
	and type(Layout.TORTA) == "table" and math.abs(Layout.TORTA.x - 748.2) < 1e-6,
	"deploy the v9 WildboundCandyLayout (VERSION 3, EAST 860, HALF 260, TORTA.x 748.2) first")
local V3 = module(ServerStorage, "WildboundCandyV3Layout")
assert(V3 and V3.VERSION == 5 and type(V3.V9) == "table" and V3.V9.EAST == 860 and type(V3.V9_PART_TARGET) == "number",
	"deploy the v9 ServerStorage.WildboundCandyV3Layout (VERSION 5, V9.EAST 860, V9_PART_TARGET) first")
local V3Builder = module(ServerStorage, "WildboundCandyV3Builder")
assert(V3Builder and type(V3Builder.layAll) == "function" and type(V3Builder.planV5) == "function"
	and type(V3Builder.WATER_FOLDERS) == "table" and type(V3Builder.existingProps) == "function",
	"deploy the v9 ServerStorage.WildboundCandyV3Builder (layAll, planV5, WATER_FOLDERS) first")
local Builder = module(ServerStorage, "WildboundCandyBuilder")
assert(Builder and type(Builder.layPaths) == "function" and type(Builder.layBoss) == "function"
	and type(Builder.layMarkers) == "function" and type(Builder.syncTower) == "function"
	and type(Builder.syncNests) == "function" and type(Builder.syncNestPositions) == "function"
	and type(Builder.layoutKey) == "function" and type(Builder.treeKeepOut) == "function",
	"deploy ServerStorage.WildboundCandyBuilder (layPaths, layBoss, layMarkers, syncTower, syncNests, syncNestPositions, layoutKey, treeKeepOut) first")
local KitSpec = module(ServerStorage, "WildboundCandyV3KitSpec")
assert(KitSpec, "deploy ServerStorage.WildboundCandyV3KitSpec first")
local Kit = module(ServerStorage, "WildboundCandyKit")
assert(Kit, "ServerStorage.WildboundCandyKit is missing")
local assets = ServerStorage:FindFirstChild("WildboundAssets")
local library = assets and assets:FindFirstChild(Kit.LIBRARY_NAME)
assert(library, "ServerStorage.WildboundAssets." .. Kit.LIBRARY_NAME .. " is missing")
local kitV3 = assets and assets:FindFirstChild(V3.KIT_FOLDER) or nil
local East = module(ServerStorage, "WildboundCandyEast")
assert(East and type(East.build) == "function" and type(East.stripPlan) == "function",
	"deploy the v9 ServerStorage.WildboundCandyEast (build, stripPlan) first")
local Duq = module(ServerStorage, "WildboundCandyDuquesa")
local Frut = module(ServerStorage, "WildboundCandyFrutillon")
assert(Duq and type(Duq.seatPivot) == "function" and Frut and type(Frut.summit) == "function",
	"ServerStorage.WildboundCandyDuquesa (seatPivot) and WildboundCandyFrutillon are needed")

-- The fill's keep-out must hold every creature post of the v9 sites, the new ones too (Builder.treeKeepOut requires the
-- deployed ServerScriptService.WildboundPraderaSites, so this checks the very module it reads).
local keepOut = Builder.treeKeepOut(Layout)
do
	local sites = ServerScriptService:FindFirstChild("WildboundPraderaSites")
	assert(sites and sites:IsA("ModuleScript") and ReplicatedStorage:FindFirstChild("WildboundBeastConfig"),
		"deploy ServerScriptService.WildboundPraderaSites and ReplicatedStorage.WildboundBeastConfig first")
	local Sites = require(sites)
	assert(type(Sites.FIXED) == "table" and Sites.FIXED.candyPostE4 ~= nil,
		"the required WildboundPraderaSites has no FIXED.candyPostE4: deploy the v9 sites (and reopen the place if an older copy is cached)")
	local want, got, e4 = 0, 0, false
	for _ in pairs(Sites.FIXED) do want += 1 end
	for _, k in ipairs(keepOut) do
		if string.sub(tostring(k.why), 1, 5) == "post " then got += 1 end
		if k.why == "post candyPostE4" then e4 = true end
	end
	assert(got == want and want > 0 and e4, ("the keep-out found %d of %d creature posts: refusing"):format(got, want))
end

local root = Workspace:FindFirstChild(Layout.ROOT_NAME)
assert(root, "Workspace." .. Layout.ROOT_NAME .. " is missing")
assert(not forbidden(root), "refusing to touch SistemaSonriente")
assert(root:GetAttribute(V3.MARK) ~= nil and root:FindFirstChild(V3.FOLDER),
	"run tools/wildbound-caramelo-v3-migrate.luau first (no CaramelV3 on the map)")
assert(root:GetAttribute(NEEDS) ~= nil, "run tools/wildbound-caramelo-v8-migrate.luau first (no CaramelV8 mark)")

local annex = Workspace:FindFirstChild(ANNEX_NAME)
if annex and forbidden(annex) then annex = nil end
local eastRoot = Workspace:FindFirstChild(East.ROOT_NAME)
if eastRoot and forbidden(eastRoot) then eastRoot = nil end
local preview = Workspace:FindFirstChild(PREVIEW)
local queen = preview and preview:FindFirstChild(QUEEN)
if queen and (not queen:IsA("Model") or forbidden(queen)) then queen = nil end

local deps = { Layout = Layout, V3 = V3, Builder = Builder, kitV3 = kitV3, kitSpec = KitSpec, Kit = Kit, library = library,
	keepOut = keepOut, relay = true }
-- the growth area: the old plot's east edge to the new one (world x 932..1532, z -263..257)
local GROWTH = { minX = Layout.CENTRE.x + Layout.V9.OLD_EAST, maxX = Layout.CENTRE.x + Layout.EAST,
	minZ = Layout.CENTRE.z - Layout.HALF, maxZ = Layout.CENTRE.z + Layout.HALF }
local summary = { dryRun = DRY_RUN, already = false, version = V3.VERSION, east = Layout.EAST, archived = {}, warnings = {},
	refused = {}, target = V3.V9_PART_TARGET, cap = V3.BIOME_PART_CAP, keepOut = #keepOut,
	kitFolder = kitV3 and kitV3:GetFullName() or "none (every piece a placeholder)",
	partsBefore = { bioma = countParts(root), annex = countParts(annex), east = countParts(eastRoot) } }

if root:GetAttribute(MARK) ~= nil then
	summary.already = true
	summary.mark = root:GetAttribute(MARK)
	publish(summary)
	return summary
end

-- The survey (read only) ---------------------------------------------------------------------------------------------

-- P1 to P5: { archive = { { instance, why } } (under the root), annex = { { instance, why } }, warnings, water, kept }.
local function makePlan()
	local entries = {}
	local function add(instance, why)
		if instance and not forbidden(instance) then table.insert(entries, { instance = instance, why = why }) end
	end
	-- P1: laid again from the v9 layout, and runtime folders saved by mistake
	for _, name in ipairs(RELAID) do add(root:FindFirstChild(name), "laid again for layout v9") end
	local ground = root:FindFirstChild("Ground")
	add(ground and ground:FindFirstChild("Plaza"), "laid again for layout v9 (layBoss)")
	local nests = root:FindFirstChild("Nests")
	local summit = type(Layout.TOWER) == "table" and Layout.TOWER.summit or nil
	add(summit and nests and nests:FindFirstChild("Nest_" .. summit.id), "laid again with the Tower (syncTower)")
	for _, c in ipairs(sortedChildren(root)) do
		if RUNTIME[c.Name] then add(c, "planned again at server start") end
	end
	-- P2: the water folders and whatever stands in the v9 chocolate or on a v9 piece
	local p5 = V3Builder.planV5(root, Layout, V3)
	for _, a in ipairs(p5.archive) do
		add(a.instance, a.why == "laid again by v5" and "laid again for layout v9 (layAll relay)" or a.why)
	end
	-- P3: every other CaramelV3 child but Trees, so that the layAll relay may run
	local holder = root:FindFirstChild(V3.FOLDER)
	for _, c in ipairs(sortedChildren(holder)) do
		if c.Name ~= "Trees" then
			add(c, RUNTIME[c.Name] and "planned again at server start" or "laid again for layout v9 (layAll relay)")
		end
	end
	-- each instance once, and none whose ancestor is archived too (P3 holds P2's Filler and EdgeFill models)
	local plan = { archive = {}, annex = {}, warnings = {}, water = p5.water, kept = p5.kept }
	local seen = {}
	for _, e in ipairs(entries) do
		local covered = seen[e.instance] == true
		for _, other in ipairs(entries) do
			if not covered and other.instance ~= e.instance and e.instance:IsDescendantOf(other.instance) then covered = true end
		end
		if not covered then
			seen[e.instance] = true
			table.insert(plan.archive, e)
		end
	end
	-- P4: annex props in the growth area
	local props = annex and annex:FindFirstChild("Props")
	for _, c in ipairs(sortedChildren(props)) do
		if forbidden(c) or not (c:IsA("Model") or c:IsA("BasePart")) then continue end
		local pivot = c:GetPivot()
		if inRect(GROWTH, pivot.X, pivot.Z) then
			table.insert(plan.annex, { instance = c, why = ("stands in the growth area at (%.1f, %.1f)"):format(pivot.X, pivot.Z) })
		end
	end
	-- P5 (warning only): a kept tree or old kit prop whose pivot stands on a v9 route (planV5 does not check routes)
	local kept = {}
	for _, name in ipairs(V3Builder.PROP_FOLDERS or {}) do
		for _, c in ipairs(sortedChildren(root:FindFirstChild(name))) do table.insert(kept, c) end
	end
	for _, c in ipairs(sortedChildren(holder and holder:FindFirstChild("Trees"))) do table.insert(kept, c) end
	for _, c in ipairs(kept) do
		if seen[c] or forbidden(c) or not c:IsA("Model") then continue end
		local pivot = c:GetPivot()
		local x, z = pivot.X - Layout.CENTRE.x, pivot.Z - Layout.CENTRE.z
		if Layout.routeDistance(x, z) < Layout.PATH_WIDTH / 2 + 1 then
			table.insert(plan.warnings, c:GetFullName() .. " stands on a v9 route (kept; check it in the dry run)")
		end
	end
	-- P5: anything else in the growth area, a warning only
	local function look(item)
		if forbidden(item) or not (item:IsA("Model") or item:IsA("BasePart")) then return end
		local ok, pivot = pcall(item.GetPivot, item)
		if ok and inRect(GROWTH, pivot.X, pivot.Z) then
			table.insert(plan.warnings, item:GetFullName() .. " stands in the growth area (not touched)")
		end
	end
	for _, c in ipairs(sortedChildren(Workspace)) do
		if c == root or c == eastRoot or c:IsA("Terrain") or c:IsA("Camera") or forbidden(c) then continue end
		if c == annex then
			for _, a in ipairs(sortedChildren(c)) do
				if a.Name == "Props" or a.Name == "Ground" then continue end
				if a:IsA("Folder") then
					for _, b in ipairs(sortedChildren(a)) do look(b) end
				else
					look(a)
				end
			end
		elseif c:IsA("Folder") then
			for _, b in ipairs(sortedChildren(c)) do look(b) end
		else
			look(c)
		end
	end
	return plan
end

-- The annex strips: its axis-aligned floor slabs, East.stripPlan's verdict and the parts to resize.
local function stripSurvey()
	local slabs, byName, notes = {}, {}, {}
	local ground = annex and annex:FindFirstChild("Ground")
	for _, part in ipairs(sortedChildren(ground)) do
		if part:IsA("BasePart") and not forbidden(part) then
			local o = part.Orientation
			if math.abs(o.X) > 0.01 or math.abs(o.Z) > 0.01 or math.abs(o.Y % 180) > 0.01 then
				table.insert(notes, part:GetFullName() .. " is turned: left as it is")
			elseif byName[part.Name] then
				table.insert(notes, part:GetFullName() .. " shares its name with another slab: left as it is")
			else
				local p, s = part.Position, part.Size
				byName[part.Name] = part
				table.insert(slabs, { name = part.Name, minX = p.X - s.X / 2, maxX = p.X + s.X / 2, minZ = p.Z - s.Z / 2,
					maxZ = p.Z + s.Z / 2 })
			end
		end
	end
	local g = East.stripPlan(Layout, slabs)
	local resize = {}
	for _, r in ipairs(g.resize) do table.insert(resize, { instance = byName[r.name], side = r.side, rect = r.rect }) end
	return { ok = g.ok == true, resize = resize, done = g.done, missing = g.missing, notes = notes }
end

-- Every SistemaSonriente part (anywhere in Workspace) whose flat bounds meet SONRIENTE_BOX: their full names. Read only.
local function sonrienteHits()
	local hits = {}
	local B = SONRIENTE_BOX
	for _, s in ipairs(Workspace:GetDescendants()) do
		if s.Name ~= "SistemaSonriente" then continue end
		local parts = s:GetDescendants()
		table.insert(parts, s)
		for _, d in ipairs(parts) do
			if d:IsA("BasePart") then
				local cf, h = d.CFrame, d.Size / 2
				local ex = math.abs(cf.XVector.X) * h.X + math.abs(cf.YVector.X) * h.Y + math.abs(cf.ZVector.X) * h.Z
				local ez = math.abs(cf.XVector.Z) * h.X + math.abs(cf.YVector.Z) * h.Y + math.abs(cf.ZVector.Z) * h.Z
				local p = d.Position
				if p.X + ex >= B.minX and p.X - ex <= B.maxX and p.Z + ez >= B.minZ and p.Z - ez <= B.maxZ then
					table.insert(hits, d:GetFullName())
				end
			end
		end
	end
	return hits
end

-- P6: the relaid pieces of the v9 layout, laid into a detached scratch model (never parented: the map is untouched),
-- counted, then destroyed. existing = the props still standing once the plan's archive is gone.
local function probe(existing)
	local scratch = Instance.new("Model")
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = scratch
	local out = {}
	local ok, failure = pcall(function()
		out.paths = select(2, Builder.layPaths(scratch, Layout))
		out.boss = select(2, Builder.layBoss(scratch, Layout))
		out.markers = select(2, Builder.layMarkers(scratch, Layout))
		local probeDeps = table.clone(deps)
		probeDeps.relay, probeDeps.existing = false, existing
		local laid = V3Builder.layAll(scratch, probeDeps)
		out.pieces, out.edge, out.placeholders = laid.parts, laid.edgeParts, laid.placeholders
		out.filler, out.hills, out.edgeTrees, out.edgeProps = laid.filler, laid.hills, laid.edgeTrees, laid.edgeProps
		out.east = select(2, East.build(scratch, Layout, V3)).parts
	end)
	scratch:Destroy()
	if not ok then error(failure, 0) end
	return out
end

-- The layout nests the map lacks and the parts they add (a live marker's count each; syncNests places them).
local function newNests()
	local nests = root:FindFirstChild("Nests")
	local missing, each = 0, 0
	for _, spec in ipairs(Layout.NESTS) do
		local nest = nests and nests:FindFirstChild("Nest_" .. spec.id)
		if nest then
			if each == 0 then each = countParts(nest) end
		else
			missing += 1
		end
	end
	return missing, missing * each
end

-- The queen's preview model on the new summit (Duq.seatPivot, facing the junction), as a CFrame, or nil.
local function queenFrame()
	if not queen then return nil end
	local s = Duq.seatPivot(Frut.summit(Layout), { x = Layout.CENTRE.x + Layout.JUNCTION.x, z = Layout.CENTRE.z + Layout.JUNCTION.z })
	return CFrame.new(s.x, s.y, s.z) * CFrame.Angles(0, s.yaw, 0)
end
-- The raft's home dock and an Edit raft model, if one stands in the place.
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

-- The whole survey: the plan, the strips, the refusals and the estimate, written into the summary (the same lines in
-- the dry run and the real run). Returns the plan and the strips.
local function survey()
	local plan = makePlan()
	local strips = stripSurvey()
	local archivedParts = 0
	for _, a in ipairs(plan.archive) do
		table.insert(summary.archived, a.instance:GetFullName() .. ": " .. a.why)
		archivedParts += countParts(a.instance)
	end
	for _, a in ipairs(plan.annex) do table.insert(summary.archived, a.instance:GetFullName() .. ": " .. a.why) end
	for _, w in ipairs(plan.warnings) do table.insert(summary.warnings, w) end
	summary.water, summary.treesKept, summary.archivedParts = plan.water, plan.kept, archivedParts
	summary.strips = { found = strips.ok, resized = {}, done = #strips.done, missing = strips.missing, notes = strips.notes }
	for _, r in ipairs(strips.resize) do
		table.insert(summary.strips.resized, ("%s (%s) -> x %g..%g, z %g..%g"):format(r.instance:GetFullName(), r.side,
			r.rect.minX, r.rect.maxX, r.rect.minZ, r.rect.maxZ))
	end
	if not annex then table.insert(summary.warnings, "no Workspace." .. ANNEX_NAME) end
	local ground = root:FindFirstChild("Ground")
	local floor = ground and ground:FindFirstChild("Floor")
	if floor and floor:IsA("BasePart") then
		summary.floor = ("%g x %g at (%.1f, %.1f) -> %g x %g at (%g, %g)"):format(floor.Size.X, floor.Size.Z, floor.Position.X,
			floor.Position.Z, Layout.HALF + Layout.EAST, 2 * Layout.HALF, Layout.CENTRE.x + (Layout.EAST - Layout.HALF) / 2,
			Layout.CENTRE.z)
	else
		table.insert(summary.warnings, "no Candy_Bioma_v1.Ground.Floor part: the floor is not grown")
	end
	local _, dockId = homeDock()
	summary.raft = raftModel() and ("an Edit raft: to dock " .. dockId) or ("none in Edit: the service builds it at dock " .. dockId)
	summary.queen = queen and "to the new summit (Duq.seatPivot)" or ("no Workspace." .. PREVIEW .. "." .. QUEEN)
	-- refusals
	local hits = sonrienteHits()
	if #hits > 0 then
		local B = SONRIENTE_BOX
		table.insert(summary.refused, ("SistemaSonriente meets world x %g..%g, z %g..%g (never touched): %s"):format(B.minX,
			B.maxX, B.minZ, B.maxZ, table.concat(hits, ", ")))
	end
	if not strips.ok then
		table.insert(summary.refused, "the two big4 annex strips were not both found (missing: " .. table.concat(strips.missing, ", ") .. ")")
	end
	-- P6: the probe and the estimate
	local existing = {}
	for _, e in ipairs(V3Builder.existingProps(root, Layout)) do
		local gone = false
		for _, a in ipairs(plan.archive) do
			local name = a.instance:GetFullName()
			if e.name == name or string.sub(e.name, 1, #name + 1) == name .. "." then
				gone = true
				break
			end
		end
		if not gone then table.insert(existing, e) end
	end
	local ok, laid = pcall(probe, existing)
	if ok then
		local tower = countParts(root:FindFirstChild("Tower"))
		local summit = type(Layout.TOWER) == "table" and Layout.TOWER.summit or nil
		local nests = root:FindFirstChild("Nests")
		if summit and nests then tower += countParts(nests:FindFirstChild("Nest_" .. summit.id)) end
		if tower == 0 then tower = TOWER_PARTS end
		local count, nestParts = newNests()
		laid.tower, laid.newNests, laid.nestParts = tower, count, nestParts
		summary.relaid = laid
		local relaid = laid.paths + laid.boss + laid.markers + laid.pieces + laid.edge + tower + nestParts
		summary.estimate = { bioma = summary.partsBefore.bioma - archivedParts + relaid, east = laid.east }
		summary.overCap = summary.estimate.bioma > V3.BIOME_PART_CAP
		if summary.estimate.bioma > V3.V9_PART_TARGET then
			table.insert(summary.refused, ("the estimate %d is above V3.V9_PART_TARGET %d"):format(summary.estimate.bioma,
				V3.V9_PART_TARGET))
		end
	else
		summary.relaid = { error = tostring(laid) }
		table.insert(summary.refused, "the probe failed, so the estimate is unknown: " .. tostring(laid))
	end
	return plan, strips
end

if DRY_RUN then
	survey()
	publish(summary)
	return summary
end

-- The real run, in its own thread and its own recording ----------------------------------------------------------------

pcall(function() ServerStorage:SetAttribute(SUMMARY_ATTRIBUTE, "pending") end)
_G.WildboundCaramelV9Summary = nil
task.delay(0.5, function()
	local surveyed, plan, strips = pcall(survey)
	if not surveyed then
		summary.error = "the survey failed, nothing was changed: " .. tostring(plan)
		publish(summary)
		return
	end
	if #summary.refused > 0 then
		summary.error = "refused, nothing was changed"
		publish(summary)
		return
	end
	local recording
	local opened = pcall(function() recording = ChangeHistoryService:TryBeginRecording("CaramelV9") end)
	if not (opened and recording) then
		summary.error = "could not open a ChangeHistoryService recording (another one open?): nothing was changed"
		publish(summary)
		return
	end
	local ok, failure = pcall(function()
		local archiveRoot = folderIn(ServerStorage, ARCHIVE_ROOT)
		local archived = folderIn(archiveRoot, ARCHIVED)
		-- 0. backup
		if archiveRoot:FindFirstChild(BACKUP) then
			summary.backup = "kept the existing " .. BACKUP
			table.insert(summary.warnings, "an older " .. BACKUP .. " was kept: check it before any restore")
		else
			local holder = Instance.new("Folder")
			holder.Name = BACKUP
			for _, original in pairs({ root, eastRoot, annex, queen }) do -- pairs: eastRoot, annex or queen may be nil
				if original then
					local copy = original:Clone()
					if copy then copy.Parent = holder end
				end
			end
			holder.Parent = archiveRoot
			summary.backup = holder:GetFullName()
		end
		local function archive(instance)
			if instance and not forbidden(instance) then instance.Parent = archived end
		end
		-- 1. the floor: (HALF + EAST) x 2 * HALF, from the west edge to the new east edge
		local ground = root:FindFirstChild("Ground")
		local floor = ground and ground:FindFirstChild("Floor")
		if floor and floor:IsA("BasePart") then
			floor.Size = Vector3.new(Layout.HALF + Layout.EAST, floor.Size.Y, 2 * Layout.HALF)
			floor.CFrame = CFrame.new(Layout.CENTRE.x + (Layout.EAST - Layout.HALF) / 2, floor.Position.Y, Layout.CENTRE.z)
		end
		-- 2. the archive (P1 to P4)
		for _, a in ipairs(plan.archive) do archive(a.instance) end
		for _, a in ipairs(plan.annex) do archive(a.instance) end
		-- 3. the Gran Torta to the layout's Torta, with the new key
		local torta = root:FindFirstChild("GranTorta")
		assert(torta and (torta:IsA("Model") or torta:IsA("BasePart")), "no GranTorta on the map")
		torta:PivotTo(slid(torta:GetPivot(), Layout.CENTRE.x + Layout.TORTA.x, Layout.CENTRE.z + Layout.TORTA.z))
		torta:SetAttribute("LayoutKey", Builder.layoutKey(Layout))
		-- 4. the relay
		local relaid = {}
		relaid.boss = select(2, Builder.layBoss(root, Layout))
		relaid.paths = select(2, Builder.layPaths(root, Layout))
		relaid.markers = select(2, Builder.layMarkers(root, Layout))
		local laid = V3Builder.layAll(root, deps)
		relaid.pieces, relaid.edge, relaid.placeholders = laid.parts, laid.edgeParts, laid.placeholders
		relaid.filler, relaid.hills, relaid.edgeTrees, relaid.edgeProps = laid.filler, laid.hills, laid.edgeTrees, laid.edgeProps
		relaid.tower = Builder.syncTower(root, Layout, Kit, library)
		summary.relaid = relaid
		summary.nestsMoved = Builder.syncNestPositions(root, Layout)
		summary.created = { nests = Builder.syncNests(root, Layout, Kit, library) }
		-- 5. the queen's preview model and an Edit raft
		local qf = queenFrame()
		if qf then queen:PivotTo(qf) end
		local raft = raftModel()
		if raft then raft:PivotTo((homeDock())) end
		-- 6. the annex strips to the arm
		for _, r in ipairs(strips.resize) do
			local part, rr = r.instance, r.rect
			part.Size = Vector3.new(rr.maxX - rr.minX, part.Size.Y, rr.maxZ - rr.minZ)
			part.CFrame = CFrame.new((rr.minX + rr.maxX) / 2, part.Position.Y, (rr.minZ + rr.maxZ) / 2)
		end
		-- 7. the cloud wall at the new east edge, with the river's mouth
		local _, report = East.build(Workspace, Layout, V3)
		summary.east = report
		summary.created.east = report.created
		-- 8. a second build changes nothing, then the mark
		local _, again = East.build(Workspace, Layout, V3)
		assert(again.created == 0 and again.changed == 0,
			("a second East.build still changed the wall (created %d, changed %d)"):format(again.created, again.changed))
		root:SetAttribute(MARK, 1)
	end)
	ChangeHistoryService:FinishRecording(recording,
		ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
	if not ok then summary.error = "failed and undone: " .. tostring(failure) end
	summary.partsAfter = { bioma = countParts(root), annex = countParts(annex),
		east = countParts(Workspace:FindFirstChild(East.ROOT_NAME)) }
	summary.overCap = summary.partsAfter.bioma > V3.BIOME_PART_CAP
	publish(summary)
end)
print("CaramelV9: scheduled; read ServerStorage:GetAttribute(\"" .. SUMMARY_ATTRIBUTE .. "\") in a few seconds")
return { scheduled = true, dryRun = false, summaryAttribute = SUMMARY_ATTRIBUTE }

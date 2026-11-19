-- Pueblo Gatito grows to 600 x 1200 (owner requests 2026-11-18 "que todos los biomas tengan el mismo tamaño, pero ahora
-- hacelos mas largos aun" and 2026-11-19 "hace el mapa bastante mas largo y si hace falta colocar mas bichos de distintas
-- zonas hazlo"; docs/design/wildbound-pueblo-gatito-long-plan.md GL-D1..GL-D17; this tool is GL-D14, parent decision
-- GL-PD9). Studio Edit mode only: kept in the place as the disabled Script ServerStorage.WildboundPuebloGatitoGrow and run
-- from the command bar or execute_luau (or task.spawn + loadstring of its Source), first with DRY_RUN = true to read the
-- plan, then with DRY_RUN = false. A one-shot tool on the skeleton of tools/wildbound-pueblo-gatito-move.luau and
-- tools/wildbound-caramelo-v9-migrate.luau. Its source is pinned by WildboundPuebloGatitoGrow_Test.
--
-- It runs once, on a map where the park was moved to the big4 south arm (Workspace.PuebloGatito_v1 marked
-- PuebloGatito = 2) and not yet grown (it returns the summary "already" when the mark is 3). It needs:
--   ReplicatedStorage.WildboundGatitoArea VERSION 3 (GROWTH 600, FAR 860, ARM to z 1537, GL-D1), the shared require the
--   park module reads too (reopen the place if an older copy is cached);
--   ServerStorage.WildboundKittenPark grown (VERSION 2, PART_CAP 2800, EDGE_PARTS 203, ROOT_CAP 3037, 16 NESTS, with
--   buildGround, build, edgePlan, buildEdge, syncNests and strays), WildboundCandyLayout and WildboundCandyEast (the
--   plan's signature still takes them, unused); all three from fresh clones;
--   the GL-D11 ServerScriptService.WildboundPraderaSites (16 park posts in EAST_FIXED, 12 EAST_EXTRA_POSTS rows) and the
--   hand-patched big4 biome rows (H1, H2: every CandyEast square of WildboundBiomes and WildboundBiomeLight to z 1537).
--
-- The survey (read only; the same lines in the dry run and the real run):
--   S1. refused when any SistemaSonriente part's turned flat bounds meet SONRIENTE_BOX, world x -7..601, z 324..1541
--       (the arm, its walls and the Approach); SistemaSonriente is never touched anywhere;
--   S2. refused unless the deployed WildboundPraderaSites holds every park nest's post key in EAST_FIXED at the nest's
--       post x, z (within 1e-3) and 12 EAST_EXTRA_POSTS rows;
--   S3. refused when a present AREAS or AREAS_BIG4 list of WildboundBiomes or WildboundBiomeLight (fresh clones) holds a
--       CandyEast square whose maxZ is not 1537, or when either has no AREAS_BIG4 in a big4 place (the big4 annex or a
--       Road_big4_ piece in Workspace: the classic repo copy was deployed over the big4 one);
--   S4. a warning (never touched) for every other Workspace piece (top-level, or a child of a top-level Folder or Model)
--       whose pivot lies in the box; Apron_Volcanic and the Road_big4_ pieces are listed under "known" instead; a
--       warning when the deployed WildboundPortal has no "parque2" station (GL-D13);
--   S5. the archive list, Park.strays: every Model or BasePart in a root.Park folder that the new plan does not keep
--       there (expected empty);
--   S6. the probe: the ground, the park, the edge and the nests laid into a detached scratch model, counted, then the
--       scratch model is destroyed (the tool's only Destroy); refused when the park folder is over Park.PART_CAP, the
--       root over Park.ROOT_CAP, or the probe fails. The estimate also counts the probe's parts past world z 1024 (no
--       baseplate there: streaming, R12).
--
-- The real run (one undo step, ChangeHistoryService recording "PuebloGatitoGrow") runs in a deferred thread (task.delay),
-- because a call made from inside another recording (execute_luau is one) cannot open its own. Read the result from
-- ServerStorage's attribute WildboundPuebloGatitoGrowSummary (JSON; "pending" until done) or
-- _G.WildboundPuebloGatitoGrowSummary. In that thread the survey runs again first and any refusal stops it; then:
--   1. backup: a clone of Workspace.PuebloGatito_v1 into ServerStorage.WildboundMapArchive.GatitoGrowBackup (an existing
--      one is kept and the summary warns);
--   2. the ground: Ground.Floor conformed in place to the whole arm, 600 x 1200 at (297, 0, 937); Ground.Approach made;
--   3. the S5 list reparented into WildboundMapArchive.GatitoGrowArchived (never destroyed);
--   4. the park: the six GL-D9 rows conformed (moved to the far end), the Jardín de Ovillos laid;
--   5. the edge: Edge.Walls (3 invisible walls) and Edge.Hedge (100 hedge models);
--   6. the nests: K4, K5, K7 and K8 re-flagged, K9..K16 made;
--   7. the rebuild: the ground, the park, the edge and the nests again must make and change nothing (asserted, so a
--      failure cancels the whole recording);
--   8. the mark PuebloGatito = Area.VERSION (3), last (Key stays "pueblo-gatito");
--   9. the JSON summary: the parts before and after (root and per folder), the estimate, the archive, what was made and
--      changed, the rebuild, the warnings and refusals, overCap (the root over Park.ROOT_CAP).
-- A failure is cancelled (FinishRecording Cancel); Ctrl+Z undoes a committed run in the same session.
--
-- RESTORE = true (with DRY_RUN = false): needs the mark 3 and GatitoGrowBackup. In one recording,
-- "PuebloGatitoGrowRestore", the live root moves into WildboundMapArchive.GatitoGrowReverted and the backup is cloned
-- back into Workspace. It goes with a git revert of the GL modules. With DRY_RUN = true it only reports.
-- Idempotent: a second run finds the mark and returns "already"; a second quick real run checks the mark again inside its
-- deferred thread. Everything is reparented, never destroyed (only the probe's detached scratch model is). Anything
-- named SistemaSonriente, or under it, or holding it, is never touched. No asset of any kind is uploaded or loaded.

-- true: only report; false: change the map (one undo step)
local DRY_RUN = true
-- true: put GatitoGrowBackup back instead of growing (needs the mark 3 and the backup)
local RESTORE = false

local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Edit mode only: stop Play first")
local ServerStorage, Workspace = game:GetService("ServerStorage"), game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local SUMMARY_ATTRIBUTE = "WildboundPuebloGatitoGrowSummary"
-- the root's mark: 2 after the move (PGM-D7), 3 once grown (Area.VERSION, GL-D1)
local MARK, NEEDS, GROWN = "PuebloGatito", 2, 3
local BACKUP, ARCHIVED, REVERTED = "GatitoGrowBackup", "GatitoGrowArchived", "GatitoGrowReverted"
local ARCHIVE_ROOT = "WildboundMapArchive"
-- the root RESTORE needs by name (it requires no module)
local ROOT_NAME = "PuebloGatito_v1"
-- world box SistemaSonriente must stay out of: the arm, its 4-stud walls and the Approach (GL-D14)
local SONRIENTE_BOX = { minX = -7, maxX = 601, minZ = 324, maxZ = 1541 }
-- GL-D11: the deployed sites' east extra posts (K5..K16)
local EXTRA_POSTS = 12
-- GL-D15, R7: the parts the K-D drop rules remove (TreeL_01 and the K-D scatter); any more is a dropped garden row
local KD_DROPPED_PARTS = 14
-- S4: pieces in the box that are expected there and never touched (GL-PD10: the volcanic apron; the big4 road)
local KNOWN = { Apron_Volcanic = true }
local KNOWN_PREFIX = "Road_big4_"

-- A fresh copy of a ModuleScript (never the session's cached require), or nil.
local function module(parent, name)
	local found = parent and parent:FindFirstChild(name)
	if not (found and found:IsA("ModuleScript")) then return nil end
	local ok, value = pcall(function() return require(found:Clone()) end)
	if ok then return value end
	return require(found)
end
-- SistemaSonriente is never touched: not the instance, not one of its ancestors, not one of its descendants (a whole
-- folder reparented here would carry a nested one along).
local function forbidden(instance)
	return instance.Name == "SistemaSonriente" or instance:FindFirstAncestor("SistemaSonriente") ~= nil
		or instance:FindFirstChild("SistemaSonriente", true) ~= nil
end
local function countParts(instance)
	if not instance then return 0 end
	local n = 0
	for _, d in ipairs(instance:GetDescendants()) do
		if d:IsA("BasePart") then n += 1 end
	end
	return n
end
-- BaseParts per child of a holder (the root's folders, or the park's nine).
local function countFolders(holder)
	local out = {}
	for _, c in ipairs(holder and holder:GetChildren() or {}) do out[c.Name] = countParts(c) + (c:IsA("BasePart") and 1 or 0) end
	return out
end
local function publish(summary)
	local json = HttpService:JSONEncode(summary)
	_G.WildboundPuebloGatitoGrowSummary = summary
	pcall(function() ServerStorage:SetAttribute(SUMMARY_ATTRIBUTE, json) end)
	print("PuebloGatitoGrow " .. json)
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
local function inRect(r, x, z)
	return x >= r.minX and x <= r.maxX and z >= r.minZ and z <= r.maxZ
end
-- Whether a root carries the grown mark (3 or later).
local function grown(root)
	return root ~= nil and (tonumber(root:GetAttribute(MARK)) or 0) >= GROWN
end

-- RESTORE: the backup back in place of the live root (no module needed) ---------------------------------------------

if RESTORE then
	local summary = { restore = true, dryRun = DRY_RUN, restored = {}, reverted = {}, warnings = {} }
	local live = Workspace:FindFirstChild(ROOT_NAME)
	assert(live and not forbidden(live), "Workspace." .. ROOT_NAME .. " is missing (or holds SistemaSonriente)")
	assert(grown(live), "RESTORE needs the mark " .. MARK .. " = " .. GROWN .. ": this park was never grown")
	local archiveRoot = ServerStorage:FindFirstChild(ARCHIVE_ROOT)
	local backup = archiveRoot and archiveRoot:FindFirstChild(BACKUP)
	local copy = backup and backup:FindFirstChild(ROOT_NAME)
	assert(copy and not forbidden(copy),
		"RESTORE needs ServerStorage." .. ARCHIVE_ROOT .. "." .. BACKUP .. " holding " .. ROOT_NAME)
	if DRY_RUN then
		table.insert(summary.reverted, live:GetFullName() .. " -> ServerStorage." .. ARCHIVE_ROOT .. "." .. REVERTED)
		table.insert(summary.restored, copy:GetFullName() .. " -> Workspace")
		publish(summary)
		return summary
	end
	pcall(function() ServerStorage:SetAttribute(SUMMARY_ATTRIBUTE, "pending") end)
	_G.WildboundPuebloGatitoGrowSummary = nil
	task.delay(0.5, function()
		local recording
		local opened = pcall(function() recording = ChangeHistoryService:TryBeginRecording("PuebloGatitoGrowRestore") end)
		if not (opened and recording) then
			summary.error = "could not open a ChangeHistoryService recording (another one open?): nothing was changed"
			publish(summary)
			return
		end
		local ok, failure = pcall(function()
			local reverted = folderIn(archiveRoot, REVERTED)
			if #reverted:GetChildren() > 0 then
				table.insert(summary.warnings, "an older " .. REVERTED .. " was kept: this restore's root is beside it")
			end
			local current = Workspace:FindFirstChild(ROOT_NAME)
			assert(not (current and forbidden(current)), "refusing to touch SistemaSonriente")
			if current then
				table.insert(summary.reverted, current:GetFullName())
				current.Parent = reverted
			end
			local fresh = copy:Clone()
			assert(fresh, "the backup could not be cloned (Archivable is off): undone")
			fresh.Parent = Workspace
			table.insert(summary.restored, fresh:GetFullName())
		end)
		ChangeHistoryService:FinishRecording(recording,
			ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
		if not ok then summary.error = "failed and undone: " .. tostring(failure) end
		publish(summary)
	end)
	print("PuebloGatitoGrowRestore: scheduled; read ServerStorage:GetAttribute(\"" .. SUMMARY_ATTRIBUTE .. "\") in a few seconds")
	return { scheduled = true, restore = true, dryRun = false, summaryAttribute = SUMMARY_ATTRIBUTE }
end

-- Modules and guards -------------------------------------------------------------------------------------------------

local areaModule = ReplicatedStorage:FindFirstChild("WildboundGatitoArea")
assert(areaModule and areaModule:IsA("ModuleScript"), "deploy ReplicatedStorage.WildboundGatitoArea (GL-D1) first")
local Area = require(areaModule)
assert(Area.VERSION == GROWN and Area.GROWTH == 600 and Area.FAR == 860 and type(Area.ARM) == "table"
	and Area.ARM.maxZ == 1537 and Area.ROOT_NAME == ROOT_NAME,
	"deploy the grown WildboundGatitoArea (VERSION 3, GROWTH 600, FAR 860, ARM.maxZ 1537, GL-D1) first; reopen the place if an older copy is cached")
local Layout = module(ServerStorage, "WildboundCandyLayout")
local East = module(ServerStorage, "WildboundCandyEast")
assert(type(Layout) == "table" and type(East) == "table",
	"ServerStorage.WildboundCandyLayout and WildboundCandyEast are needed (the park plan's signature takes them)")
local Park = module(ServerStorage, "WildboundKittenPark")
assert(type(Park) == "table" and type(Park.buildGround) == "function" and type(Park.build) == "function"
	and type(Park.edgePlan) == "function" and type(Park.buildEdge) == "function" and type(Park.syncNests) == "function"
	and type(Park.strays) == "function" and type(Park.NESTS) == "table" and type(Park.EDGE) == "table",
	"deploy the grown ServerStorage.WildboundKittenPark (buildGround, build, edgePlan, buildEdge, syncNests, strays, GL-D14) first")
assert(Park.VERSION == 2 and Park.PART_CAP == 2800 and #Park.NESTS == 16 and Park.EDGE_PARTS == 203
	and Park.ROOT_CAP == 3037 and Park.ROOT_CAP == Park.PART_CAP + Park.EDGE_PARTS + 2 + #Park.NESTS * Park.NEST_PARTS
	and Park.ROOT_NAME == Area.ROOT_NAME,
	"the deployed WildboundKittenPark is not the grown one (VERSION 2, PART_CAP 2800, 16 NESTS, EDGE_PARTS 203, ROOT_CAP 3037)")

local root = Workspace:FindFirstChild(ROOT_NAME)
assert(root, "Workspace." .. ROOT_NAME .. " is missing: run tools/wildbound-pueblo-gatito-move.luau first")
assert(not forbidden(root), "refusing to touch SistemaSonriente")
assert(root:IsA("Model"), "Workspace." .. ROOT_NAME .. " is a " .. root.ClassName .. ", not a Model")

local plan = Park.plan(Layout, East)
local summary = { dryRun = DRY_RUN, already = false, version = Area.VERSION, mark = root:GetAttribute(MARK),
	key = root:GetAttribute("Key"), warnings = {}, refused = {}, archived = {}, known = {}, dropped = {},
	partsBefore = { gatito = countParts(root), gatitoFolders = countFolders(root),
		park = countFolders(root:FindFirstChild(Park.FOLDER)) },
	planned = { budget = plan.budget, park = plan.parts, cap = Park.PART_CAP, rootCap = Park.ROOT_CAP,
		edge = Park.EDGE_PARTS, ground = 2, nests = #Park.NESTS * Park.NEST_PARTS } }

if grown(root) then
	summary.already = true
	publish(summary)
	return summary
end
assert(root:GetAttribute(MARK) == NEEDS, ("Workspace.%s needs %s = %d (run tools/wildbound-pueblo-gatito-move.luau first), found %s")
	:format(ROOT_NAME, MARK, NEEDS, tostring(root:GetAttribute(MARK))))
do
	local ground = root:FindFirstChild(Park.GROUND_FOLDER)
	local floor = ground and ground:FindFirstChild("Floor")
	assert(floor and floor:IsA("BasePart"), "Workspace." .. ROOT_NAME .. ".Ground.Floor is missing")
	assert(root:FindFirstChild(Park.FOLDER), "Workspace." .. ROOT_NAME .. "." .. Park.FOLDER .. " is missing")
	assert(root:FindFirstChild(Park.NESTS_FOLDER), "Workspace." .. ROOT_NAME .. "." .. Park.NESTS_FOLDER .. " is missing")
end

-- The survey (read only) ---------------------------------------------------------------------------------------------

-- S1: every SistemaSonriente part (anywhere in Workspace) whose turned flat bounds meet SONRIENTE_BOX: their full names.
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

-- S2: nil when the deployed sites hold the 16 park posts and the 12 extra rows, else the reason. The sites module reads
-- its services through its DataModel, so it is the deployed require (as the v9 tool's keep-out check).
local function sitesProblem()
	local sites = ServerScriptService:FindFirstChild("WildboundPraderaSites")
	if not (sites and sites:IsA("ModuleScript")) then return "no ServerScriptService.WildboundPraderaSites" end
	local ok, Sites = pcall(require, sites)
	if not ok or type(Sites) ~= "table" then
		return "ServerScriptService.WildboundPraderaSites did not load: " .. tostring(Sites)
	end
	local fixed, extra = Sites.EAST_FIXED, Sites.EAST_EXTRA_POSTS
	if type(fixed) ~= "table" or type(extra) ~= "table" then
		return "the deployed WildboundPraderaSites has no EAST_FIXED or EAST_EXTRA_POSTS"
	end
	local bad = {}
	for _, n in ipairs(Park.NESTS) do
		local p = fixed[n.post.key]
		if type(p) ~= "table" or type(p.x) ~= "number" or type(p.z) ~= "number" or math.abs(p.x - n.post.x) > 1e-3
			or math.abs(p.z - n.post.z) > 1e-3 then
			table.insert(bad, n.post.key)
		end
	end
	if #bad > 0 then
		return ("the deployed WildboundPraderaSites.EAST_FIXED lacks or misplaces %s: deploy the GL-D11 sites (and reopen the place if an older copy is cached)")
			:format(table.concat(bad, ", "))
	end
	if #extra ~= EXTRA_POSTS then
		return ("the deployed WildboundPraderaSites has %d EAST_EXTRA_POSTS rows, the GL-D11 sites have %d"):format(#extra,
			EXTRA_POSTS)
	end
	return nil
end

-- A big4 place: Workspace holds the big4 annex or a piece of the big4 road (KNOWN_PREFIX) at any depth.
local function isBig4()
	if Workspace:FindFirstChild("WildboundCandyAnnex_Big4") then return true end
	for _, d in ipairs(Workspace:GetDescendants()) do
		if string.sub(d.Name, 1, #KNOWN_PREFIX) == KNOWN_PREFIX then return true end
	end
	return false
end

-- S3: every CandyEast square of the biome lists (classic AREAS and the big4 AREAS_BIG4, where present) must end at the
-- arm's far end; a missing module or list is a warning, except a module with no AREAS_BIG4 in a big4 place: that is the
-- classic repo copy deployed over the big4 one, and it is refused.
local function biomeSurvey()
	local big4 = isBig4()
	local sources = { { ServerScriptService, "WildboundBiomes" }, { ReplicatedStorage, "WildboundBiomeLight" } }
	for _, source in ipairs(sources) do
		local name = source[1].Name .. "." .. source[2]
		local m = module(source[1], source[2])
		if type(m) ~= "table" then
			table.insert(summary.warnings, "no " .. name .. ": its CandyEast square was not checked")
			continue
		end
		local found = 0
		for _, list in ipairs({ "AREAS", "AREAS_BIG4" }) do
			local rows = m[list]
			if type(rows) ~= "table" then continue end
			for _, row in ipairs(rows) do
				if type(row) == "table" and row.tag == "CandyEast" and (row.kind == nil or row.kind == "square") then
					found += 1
					if type(row.maxZ) ~= "number" or math.abs(row.maxZ - Area.ARM.maxZ) > 1e-6 then
						table.insert(summary.refused, ("%s.%s holds a CandyEast square to z %s, not %d: patch it first (GL-D2, H1/H2)")
							:format(name, list, tostring(row.maxZ), Area.ARM.maxZ))
					end
				end
			end
		end
		if big4 and type(m.AREAS_BIG4) ~= "table" then
			table.insert(summary.refused, name .. " has no AREAS_BIG4 in a big4 place: restore the big4 copy and hand-patch it (H1/H2)")
		end
		if found == 0 then table.insert(summary.warnings, name .. " has no CandyEast square in AREAS or AREAS_BIG4") end
	end
end

-- S4: other Workspace pieces in the box (warnings only, never touched), and the second portal station.
local function lookAround()
	local function look(item)
		if forbidden(item) or not (item:IsA("Model") or item:IsA("BasePart")) then return false end
		local ok, pivot = pcall(item.GetPivot, item)
		if not (ok and inRect(SONRIENTE_BOX, pivot.X, pivot.Z)) then return false end
		if KNOWN[item.Name] or string.sub(item.Name, 1, #KNOWN_PREFIX) == KNOWN_PREFIX then
			table.insert(summary.known, item:GetFullName())
		else
			table.insert(summary.warnings, item:GetFullName() .. " stands in the arm's box (not touched)")
		end
		return true
	end
	for _, c in ipairs(sortedChildren(Workspace)) do
		if c == root or c:IsA("Terrain") or c:IsA("Camera") or forbidden(c) then continue end
		if c:IsA("Folder") then
			for _, b in ipairs(sortedChildren(c)) do look(b) end
		elseif c:IsA("Model") then
			-- a holder model standing outside the box is looked into (the big4 ground holds Apron_Volcanic)
			if not look(c) then
				for _, b in ipairs(sortedChildren(c)) do look(b) end
			end
		else
			look(c)
		end
	end
	local Portal = module(ServerScriptService, "WildboundPortal")
	if not (type(Portal) == "table" and type(Portal.station) == "function" and Portal.station("parque2") ~= nil) then
		table.insert(summary.warnings, "the deployed ServerScriptService.WildboundPortal has no \"parque2\" station (GL-D13): no way home from the far end")
	end
end

-- S6: the grown park laid into a detached scratch model (never parented: the map is untouched), counted, then destroyed.
local function probe()
	local scratch = Instance.new("Model")
	scratch.Name = "PuebloGatitoGrowProbe"
	local out = {}
	local ok, failure = pcall(function()
		Park.buildGround(scratch)
		Park.build(scratch, Layout, East)
		Park.buildEdge(scratch)
		Park.syncNests(scratch)
		out.park = countParts(scratch:FindFirstChild(Park.FOLDER))
		out.edge = countParts(scratch:FindFirstChild(Park.EDGE.folder))
		out.ground = countParts(scratch:FindFirstChild(Park.GROUND_FOLDER))
		out.nests = countParts(scratch:FindFirstChild(Park.NESTS_FOLDER))
		out.laid = countParts(scratch)
		local beyond = 0
		for _, d in ipairs(scratch:GetDescendants()) do
			if d:IsA("BasePart") and d.Position.Z > 1024 then beyond += 1 end
		end
		out.beyond1024 = beyond
	end)
	scratch:Destroy()
	if not ok then error(failure, 0) end
	return out
end

-- The live root's parts that the tool never lays (outside Ground, Park, Edge and Nests): they stay as they are.
local function outsideParts()
	local laid = { [Park.GROUND_FOLDER] = true, [Park.FOLDER] = true, [Park.EDGE.folder] = true, [Park.NESTS_FOLDER] = true }
	local n = 0
	for _, c in ipairs(root:GetChildren()) do
		if not laid[c.Name] then n += countParts(c) + (c:IsA("BasePart") and 1 or 0) end
	end
	return n
end

-- The whole survey, written into the summary (the same lines in the dry run and the real run). Returns the S5 list.
local function survey()
	-- the plan's drops (R7: the K-D drops only)
	local droppedParts = 0
	for _, d in ipairs(plan.dropped) do
		table.insert(summary.dropped, ("%s.%s: %s (%d parts)"):format(d.folder, d.id, d.reason, d.parts))
		droppedParts += d.parts
	end
	summary.droppedParts = droppedParts
	if droppedParts ~= KD_DROPPED_PARTS then
		table.insert(summary.warnings, ("the plan drops %d parts, the K-D drops are %d: a garden row is dropped, move it (R7)")
			:format(droppedParts, KD_DROPPED_PARTS))
	end
	local ground = root:FindFirstChild(Park.GROUND_FOLDER)
	local floor = ground and ground:FindFirstChild("Floor")
	if floor and floor:IsA("BasePart") then
		summary.floor = ("%g x %g at (%.1f, %.1f) -> %g x %g at (%g, %g)"):format(floor.Size.X, floor.Size.Z, floor.Position.X,
			floor.Position.Z, Park.FLOOR.size[1], Park.FLOOR.size[3], Park.FLOOR.centre.x, Park.FLOOR.centre.z)
	end
	summary.approach = (ground and ground:FindFirstChild("Approach")) and "conformed" or "made"
	summary.edge = root:FindFirstChild(Park.EDGE.folder) and "conformed" or "made"
	-- S1
	local hits = sonrienteHits()
	if #hits > 0 then
		local B = SONRIENTE_BOX
		table.insert(summary.refused, ("SistemaSonriente meets world x %g..%g, z %g..%g (never touched): %s"):format(B.minX,
			B.maxX, B.minZ, B.maxZ, table.concat(hits, ", ")))
	end
	-- S2
	local sites = sitesProblem()
	if sites then table.insert(summary.refused, sites) end
	-- S3
	biomeSurvey()
	-- S4
	lookAround()
	-- S5: the archive list
	local strays = Park.strays(root, Layout, East)
	local archivedParts = 0
	for _, entry in ipairs(strays) do
		table.insert(summary.archived, entry.path)
		archivedParts += countParts(entry.instance) + (entry.instance:IsA("BasePart") and 1 or 0)
	end
	summary.archivedParts = archivedParts
	-- S6: the probe and the estimate
	local ok, laid = pcall(probe)
	if ok then
		local outside = outsideParts()
		local estimate = { park = laid.park, edge = laid.edge, ground = laid.ground, nests = laid.nests,
			root = laid.laid + outside, outside = outside, beyond1024 = laid.beyond1024 }
		summary.estimate = estimate
		summary.overCap = estimate.root > Park.ROOT_CAP
		if estimate.edge ~= Park.EDGE_PARTS then
			table.insert(summary.warnings, ("the probe's edge has %d parts, Park.EDGE_PARTS is %d"):format(estimate.edge,
				Park.EDGE_PARTS))
		end
		if estimate.park > Park.PART_CAP then
			table.insert(summary.refused, ("the park folder's estimate %d is above Park.PART_CAP %d"):format(estimate.park,
				Park.PART_CAP))
		end
		if estimate.root > Park.ROOT_CAP then
			table.insert(summary.refused, ("the root's estimate %d is above Park.ROOT_CAP %d"):format(estimate.root,
				Park.ROOT_CAP))
		end
	else
		summary.estimate = { error = tostring(laid) }
		table.insert(summary.refused, "the probe failed, so the estimate is unknown: " .. tostring(laid))
	end
	return strays
end

if DRY_RUN then
	survey()
	publish(summary)
	return summary
end

-- The real run, in its own thread and its own recording ----------------------------------------------------------------

pcall(function() ServerStorage:SetAttribute(SUMMARY_ATTRIBUTE, "pending") end)
_G.WildboundPuebloGatitoGrowSummary = nil
task.delay(0.5, function()
	-- a second quick real run finds the first one's mark and changes nothing
	if grown(Workspace:FindFirstChild(ROOT_NAME)) then
		summary.already = true
		publish(summary)
		return
	end
	local surveyed, strays = pcall(survey)
	if not surveyed then
		summary.error = "the survey failed, nothing was changed: " .. tostring(strays)
		publish(summary)
		return
	end
	if #summary.refused > 0 then
		summary.error = "refused, nothing was changed"
		publish(summary)
		return
	end
	local recording
	local opened = pcall(function() recording = ChangeHistoryService:TryBeginRecording("PuebloGatitoGrow") end)
	if not (opened and recording) then
		summary.error = "could not open a ChangeHistoryService recording (another one open?): nothing was changed"
		publish(summary)
		return
	end
	local ok, failure = pcall(function()
		local archiveRoot = folderIn(ServerStorage, ARCHIVE_ROOT)
		-- 1. backup
		if archiveRoot:FindFirstChild(BACKUP) then
			summary.backup = "kept the existing " .. BACKUP
			table.insert(summary.warnings, "an older " .. BACKUP .. " was kept: check it before any restore")
		else
			local holder = Instance.new("Folder")
			holder.Name = BACKUP
			local copy = root:Clone()
			assert(copy, "Workspace." .. ROOT_NAME .. " could not be cloned (Archivable is off): undone")
			copy.Parent = holder
			holder.Parent = archiveRoot
			summary.backup = holder:GetFullName()
		end
		-- 2. the ground: the Floor conformed in place to the whole arm, the Approach made
		local groundReport = Park.buildGround(root)
		-- 3. the S5 list into the archive (reparented, never destroyed)
		local archived = folderIn(archiveRoot, ARCHIVED)
		summary.archivedTo = archived:GetFullName()
		for _, entry in ipairs(strays) do
			if entry.instance and not forbidden(entry.instance) then
				entry.instance:SetAttribute("GatitoGrowArchivedFrom", entry.path)
				entry.instance.Parent = archived
			end
		end
		-- 4. the park: the six GL-D9 rows moved, the Jardín de Ovillos laid
		local parkReport = Park.build(root, Layout, East)
		-- 5. the edge: the walls and the hedge
		local edgeReport = Park.buildEdge(root)
		-- 6. the nests: K4, K5, K7, K8 re-flagged, K9..K16 made
		local nestsReport = Park.syncNests(root)
		summary.created = { ground = groundReport.created, park = parkReport.created, edge = edgeReport.created,
			nests = nestsReport }
		summary.changed = { ground = groundReport.changed, park = parkReport.changed, edge = edgeReport.changed }
		summary.laid = { park = parkReport.parts, byFolder = parkReport.byFolder, edge = edgeReport.parts }
		-- 7. the rebuild: nothing left to make or change
		local groundAgain = Park.buildGround(root)
		local parkAgain = Park.build(root, Layout, East)
		local edgeAgain = Park.buildEdge(root)
		local nestsAgain = Park.syncNests(root)
		summary.rebuild = { ground = groundAgain, park = { created = parkAgain.created, changed = parkAgain.changed,
			parts = parkAgain.parts }, edge = { created = edgeAgain.created, changed = edgeAgain.changed,
			parts = edgeAgain.parts }, nests = nestsAgain }
		assert(groundAgain.created == 0 and groundAgain.changed == 0 and parkAgain.created == 0 and parkAgain.changed == 0
			and edgeAgain.created == 0 and edgeAgain.changed == 0 and nestsAgain == 0,
			("the rebuild still made or changed something (ground %d/%d, park %d/%d, edge %d/%d, nests %d): undone"):format(
				groundAgain.created, groundAgain.changed, parkAgain.created, parkAgain.changed, edgeAgain.created,
				edgeAgain.changed, nestsAgain))
		-- 8. the mark, last
		root:SetAttribute(MARK, Area.VERSION)
	end)
	ChangeHistoryService:FinishRecording(recording,
		ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
	if not ok then summary.error = "failed and undone: " .. tostring(failure) end
	local after = Workspace:FindFirstChild(ROOT_NAME)
	summary.mark = after and after:GetAttribute(MARK)
	summary.partsAfter = { gatito = countParts(after), gatitoFolders = countFolders(after),
		park = countFolders(after and after:FindFirstChild(Park.FOLDER)) }
	summary.overCap = summary.partsAfter.gatito > Park.ROOT_CAP
	publish(summary)
end)
print("PuebloGatitoGrow: scheduled; read ServerStorage:GetAttribute(\"" .. SUMMARY_ATTRIBUTE .. "\") in a few seconds")
return { scheduled = true, dryRun = false, summaryAttribute = SUMMARY_ATTRIBUTE }

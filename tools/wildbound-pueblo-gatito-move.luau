-- Pueblo Gatito moves to the big4 south arm (owner request 2026-11-18: "Sí, movelo";
-- docs/design/wildbound-pueblo-gatito-move-plan.md, PGM-D1 to PGM-D9; this tool is PGM-D7).
-- Studio Edit mode only: kept in the place as the disabled Script ServerStorage.WildboundPuebloGatitoMove and run from the
-- command bar or execute_luau (or task.spawn + loadstring of its Source), first with DRY_RUN = true to read the plan,
-- then with DRY_RUN = false. A one-shot tool, the same pattern as tools/wildbound-kitten-park-build.luau.
--
-- It runs once, on a map where the park was built (Workspace.Candy_Este_v1 marked KittenPark) and not yet moved (it
-- returns the summary "already" when Workspace.PuebloGatito_v1 is marked PuebloGatito). It needs, in ServerStorage: the
-- WildboundCandyLayout (HALF 260), WildboundCandyEast without the gate (PGM-D5) and the moved WildboundKittenPark with
-- buildGround (PGM-D2, PGM-D4); and ReplicatedStorage.WildboundGatitoArea VERSION 2 (PGM-D1). The ServerStorage modules
-- are required from fresh clones; the Area module is the shared require the park module reads too.
--
-- The real run (one undo step, ChangeHistoryService recording "PuebloGatitoMove") runs in a deferred thread (task.delay),
-- because a call made from inside another recording (execute_luau is one) cannot open its own. Read the result from
-- ServerStorage's attribute WildboundPuebloGatitoMoveSummary (JSON; "pending" until done) or
-- _G.WildboundPuebloGatitoMoveSummary. In that thread, in this order (PGM-D7):
--   1. backup: a clone of Workspace.Candy_Este_v1 into ServerStorage.WildboundMapArchive.GatitoMoveBackup (an existing one
--      is kept and the summary warns);
--   2. Workspace.PuebloGatito_v1 (a Model) is made and Candy_Este_v1.Park and Candy_Este_v1.Nests are reparented into it;
--   3. Park.buildGround (its own Ground.Floor), Park.build (conforms every moved part to the park frame), Park.syncNests;
--   4. Workspace.WildboundVolcanicLands_Big4 goes, whole, to WildboundMapArchive.GatitoSouthVolcanic (PGM-D6);
--   5. East.build(Workspace, Layout): Caramelo's cloud wall closes (PGM-D5), then Candy_Este_v1.CloudWall.ColliderSouth
--      goes to WildboundMapArchive.GatitoGate;
--   6. the marks: PuebloGatito_v1 PuebloGatito = Area.VERSION and Key = "pueblo-gatito", Candy_Este_v1 KittenParkMoved = 1;
--   7. a second Park.build, the "rebuild": it must report created 0 and changed 0;
--   8. one ChangeHistory entry, "PuebloGatitoMove" (cancelled, so undone, on any failure);
--   9. a JSON summary: the part counts before and after, what moved, the rebuild and the warnings.
-- Everything is reparented, never destroyed (only the dry run's detached scratch model is). Anything named
-- SistemaSonriente, or under it, is never touched.
local DRY_RUN = true -- true: only report; false: change the map (one undo step)

local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Edit mode only: stop Play first")
local ServerStorage, Workspace = game:GetService("ServerStorage"), game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local SUMMARY_ATTRIBUTE = "WildboundPuebloGatitoMoveSummary"
local MARK, NEEDS, MOVED_MARK, KEY = "PuebloGatito", "KittenPark", "KittenParkMoved", "pueblo-gatito"
local BACKUP, VOLCANIC_ARCHIVE, GATE_ARCHIVE = "GatitoMoveBackup", "GatitoSouthVolcanic", "GatitoGate"
local VOLCANIC_NAME = "WildboundVolcanicLands_Big4"

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
-- BaseParts per child folder of a holder (the park's nine folders, or a root's own folders).
local function countFolders(holder)
	local out = {}
	for _, c in ipairs(holder and holder:GetChildren() or {}) do out[c.Name] = countParts(c) end
	return out
end
local function publish(summary)
	local json = HttpService:JSONEncode(summary)
	_G.WildboundPuebloGatitoMoveSummary = summary
	pcall(function() ServerStorage:SetAttribute(SUMMARY_ATTRIBUTE, json) end)
	print("PuebloGatitoMove " .. json)
	return json
end

local Layout = module(ServerStorage, "WildboundCandyLayout")
assert(Layout and Layout.HALF == 260, "deploy the v8 WildboundCandyLayout (HALF 260) first")
local areaModule = ReplicatedStorage:FindFirstChild("WildboundGatitoArea")
assert(areaModule and areaModule:IsA("ModuleScript"), "deploy ReplicatedStorage.WildboundGatitoArea (PGM-D1) first")
local Area = require(areaModule)
assert(Area.VERSION == 2, "deploy the WildboundGatitoArea of the south arm (VERSION 2, PGM-D1) first")
local East = module(ServerStorage, "WildboundCandyEast")
assert(East and type(East.build) == "function" and East.GATE == nil,
	"deploy ServerStorage.WildboundCandyEast without the gate (PGM-D5) first")
local Park = module(ServerStorage, "WildboundKittenPark")
assert(Park and type(Park.buildGround) == "function" and type(Park.build) == "function"
	and type(Park.syncNests) == "function" and Park.ROOT_NAME == Area.ROOT_NAME,
	"deploy the moved ServerStorage.WildboundKittenPark (with buildGround, PGM-D2) first")
local eastRoot = Workspace:FindFirstChild(East.ROOT_NAME)
assert(eastRoot, "Workspace." .. East.ROOT_NAME .. " is missing")
assert(not forbidden(eastRoot), "refusing to touch SistemaSonriente")
assert(eastRoot:GetAttribute(NEEDS) ~= nil, "run tools/wildbound-kitten-park-build.luau first (no KittenPark mark)")
local WALL_FOLDER = East.FOLDER or "CloudWall"
local existing = Workspace:FindFirstChild(Area.ROOT_NAME)
if existing and forbidden(existing) then error("refusing to touch SistemaSonriente") end
local volcanic = Workspace:FindFirstChild(VOLCANIC_NAME)
if volcanic and forbidden(volcanic) then volcanic = nil end
local parkFolder = eastRoot:FindFirstChild(Park.FOLDER)
local nestsFolder = eastRoot:FindFirstChild(Park.NESTS_FOLDER)
local function colliderSouth()
	local wall = eastRoot:FindFirstChild(WALL_FOLDER)
	return wall and wall:FindFirstChild("ColliderSouth")
end

local plan = Park.plan(Layout, East)
local summary = { dryRun = DRY_RUN, already = false, version = Area.VERSION, warnings = {},
	moves = { park = countParts(parkFolder), parkFolders = countFolders(parkFolder),
		nests = nestsFolder and #nestsFolder:GetChildren() or 0, nestParts = countParts(nestsFolder),
		volcanic = countParts(volcanic), colliderSouth = colliderSouth() ~= nil },
	partsBefore = { east = countParts(eastRoot), eastFolders = countFolders(eastRoot), gatito = countParts(existing),
		volcanic = countParts(volcanic) },
	planned = { budget = plan.budget, park = plan.parts, cap = Park.PART_CAP, nests = #Park.NESTS * Park.NEST_PARTS } }
if plan.parts > Park.PART_CAP then table.insert(summary.warnings, "the park plan is over its cap") end
if not parkFolder then table.insert(summary.warnings, "no Workspace." .. East.ROOT_NAME .. "." .. Park.FOLDER .. " to move") end
if not nestsFolder then
	table.insert(summary.warnings, "no Workspace." .. East.ROOT_NAME .. "." .. Park.NESTS_FOLDER .. " to move")
end
if not volcanic then table.insert(summary.warnings, "no Workspace." .. VOLCANIC_NAME .. ": nothing to archive") end

-- Already moved: the new root is marked, or the old root says the park left it (a deleted PuebloGatito_v1 never makes
-- the tool lay a second park).
local function moved()
	local root = Workspace:FindFirstChild(Area.ROOT_NAME)
	return (root ~= nil and root:GetAttribute(MARK) ~= nil) or eastRoot:GetAttribute(MOVED_MARK) ~= nil
end
if moved() then
	summary.already = true
	summary.mark = existing and existing:GetAttribute(MARK) or eastRoot:GetAttribute(MOVED_MARK)
	publish(summary)
	return summary
end
if (parkFolder and forbidden(parkFolder)) or (nestsFolder and forbidden(nestsFolder)) then
	error("refusing to touch SistemaSonriente")
end
if existing then
	assert(existing:IsA("Model"), "Workspace." .. Area.ROOT_NAME .. " is a " .. existing.ClassName .. ", not a Model")
	table.insert(summary.warnings, "an unmarked Workspace." .. Area.ROOT_NAME .. " exists: the real run reuses it")
end

if DRY_RUN then
	-- the park laid into a detached scratch model (never parented: the map is untouched)
	local ok, laid = pcall(function()
		local scratch = Instance.new("Model")
		local out = {}
		out.ground = Park.buildGround(scratch)
		local report = Park.build(scratch, Layout, East)
		out.park, out.byFolder = report.parts, report.byFolder
		Park.syncNests(scratch)
		out.nests = countParts(scratch:FindFirstChild(Park.NESTS_FOLDER))
		out.total = countParts(scratch)
		scratch:Destroy()
		return out
	end)
	if ok then
		summary.partsEstimate = laid
		summary.overCap = laid.park > Park.PART_CAP
	else
		summary.partsEstimate = { error = tostring(laid) }
	end
	publish(summary)
	return summary
end

-- The real run, in its own thread and its own recording.
pcall(function() ServerStorage:SetAttribute(SUMMARY_ATTRIBUTE, "pending") end)
_G.WildboundPuebloGatitoMoveSummary = nil
task.delay(0.5, function()
	-- a second quick real run finds the first one's marks and changes nothing
	if moved() then
		summary.already = true
		publish(summary)
		return
	end
	local recording
	local opened = pcall(function() recording = ChangeHistoryService:TryBeginRecording("PuebloGatitoMove") end)
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
		local function folder(name)
			local f = archiveRoot:FindFirstChild(name)
			if not f then
				f = Instance.new("Folder")
				f.Name = name
				f.Parent = archiveRoot
			end
			return f
		end
		-- 1. backup
		if archiveRoot:FindFirstChild(BACKUP) then
			summary.backup = "kept the existing " .. BACKUP
			table.insert(summary.warnings, "an older " .. BACKUP .. " was kept: check it before any restore")
		else
			local holder = Instance.new("Folder")
			holder.Name = BACKUP
			local copy = eastRoot:Clone()
			if copy then copy.Parent = holder end
			holder.Parent = archiveRoot
			summary.backup = holder:GetFullName()
		end
		-- 2. the park's own root, the park and the nests moved into it
		local root = Workspace:FindFirstChild(Area.ROOT_NAME)
		if not root then
			root = Instance.new("Model")
			root.Name = Area.ROOT_NAME
			root.Parent = Workspace
		end
		assert(root:IsA("Model") and not forbidden(root), "Workspace." .. Area.ROOT_NAME .. " must be a Model")
		summary.moved = {}
		for _, name in ipairs({ Park.FOLDER, Park.NESTS_FOLDER }) do
			local f = eastRoot:FindFirstChild(name)
			if f then
				assert(not root:FindFirstChild(name), "Workspace." .. Area.ROOT_NAME .. "." .. name .. " already exists")
				f.Parent = root
				table.insert(summary.moved, f:GetFullName())
			end
		end
		-- 3. the floor, the park conformed to the park frame, the nests
		summary.ground = Park.buildGround(root)
		summary.park = Park.build(root, Layout, East)
		summary.nestsChanged = Park.syncNests(root)
		-- 4. the volcanic decor, whole
		local lands = Workspace:FindFirstChild(VOLCANIC_NAME)
		if lands and not forbidden(lands) then
			lands.Parent = folder(VOLCANIC_ARCHIVE)
			summary.volcanic = lands:GetFullName()
		else
			summary.volcanic = "none"
		end
		-- 5. Caramelo's cloud wall closes; the old south piece of the gate goes to the archive
		local _, eastReport = East.build(Workspace, Layout)
		summary.east = eastReport
		local south = colliderSouth()
		if south and not forbidden(south) then
			south.Parent = folder(GATE_ARCHIVE)
			summary.colliderSouth = south:GetFullName()
		else
			summary.colliderSouth = "none"
		end
		-- 6. marks
		root:SetAttribute(MARK, Area.VERSION)
		root:SetAttribute("Key", KEY)
		eastRoot:SetAttribute(MOVED_MARK, 1)
		-- 7. the rebuild: nothing left to make or change
		local again = Park.build(root, Layout, East)
		summary.rebuild = { created = again.created, changed = again.changed, parts = again.parts }
		if again.created ~= 0 or again.changed ~= 0 then
			table.insert(summary.warnings, ("the rebuild made %d and changed %d: expected 0 and 0"):format(again.created,
				again.changed))
		end
	end)
	ChangeHistoryService:FinishRecording(recording,
		ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
	if not ok then summary.error = "failed and undone: " .. tostring(failure) end
	local after = Workspace:FindFirstChild(East.ROOT_NAME)
	local gatito = Workspace:FindFirstChild(Area.ROOT_NAME)
	summary.partsAfter = { east = countParts(after), eastFolders = countFolders(after), gatito = countParts(gatito),
		gatitoFolders = countFolders(gatito), park = countFolders(gatito and gatito:FindFirstChild(Park.FOLDER)),
		volcanic = countParts(Workspace:FindFirstChild(VOLCANIC_NAME)) }
	summary.overCap = (summary.partsAfter.gatito or 0) > Park.PART_CAP + #Park.NESTS * Park.NEST_PARTS + 1
	publish(summary)
end)
print("PuebloGatitoMove: scheduled; read ServerStorage:GetAttribute(\"" .. SUMMARY_ATTRIBUTE .. "\") in a few seconds")
return { scheduled = true, dryRun = false, summaryAttribute = SUMMARY_ATTRIBUTE }

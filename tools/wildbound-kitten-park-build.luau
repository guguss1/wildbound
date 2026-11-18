-- Pueblo Gatito on the live map (owner request 2026-11-17: "es como el mundo de gatito: un parque verde lindo con las
-- criaturas gatitas, juguetes como rollos de papel, hisopos, papel, bolsas, tiendas de gatitos como que es su village
-- ... también tiene que haber huevos para robar"; docs/design/wildbound-kitten-park-plan.md, K-D1, K-D2, K-D15 to K-D19).
-- Studio Edit mode only: kept in the place as the disabled Script ServerStorage.WildboundKittenParkBuild and run from the
-- command bar or execute_luau (or task.spawn + loadstring of its Source), first with DRY_RUN = true to read the plan,
-- then with DRY_RUN = false. A one-shot tool, the same pattern as tools/wildbound-caramelo-v8-migrate.luau.
--
-- It runs once, on a map the v8 migration changed (Workspace.Candy_Bioma_v1 marked CaramelV8) and not yet marked
-- KittenPark on Workspace.Candy_Este_v1 (it returns the summary "already" then). It needs, in ServerStorage: the
-- WildboundCandyLayout with the K-D2 gate row, WildboundCandyEast with GATE (K-D1) and WildboundKittenPark. The
-- modules are required from fresh clones.
--
-- The real run (one undo step, ChangeHistoryService recording "KittenPark") runs in a deferred thread (task.delay),
-- because a call made from inside another recording (execute_luau is one) cannot open its own. Read the result from
-- ServerStorage's attribute WildboundKittenParkSummary (JSON; "pending" until done) or _G.WildboundKittenParkSummary.
-- In that thread, in this order (plan §3, Set A):
--   1. backup: a clone of Workspace.Candy_Este_v1 into ServerStorage.WildboundMapArchive.KittenParkBackup (an existing
--      one is kept and the summary warns);
--   2. East.build(Workspace, Layout): the gate split (Collider north, ColliderSouth), the green Grass floor (K-D1, K-D15);
--   3. Park.clearGate: the plot's colliding pieces in the gate corridor (x 896..932, z -17..11) go to
--      WildboundMapArchive.KittenGate (K-D2);
--   4. Park.archiveAnnex: the big4 annex props standing in the second space go to WildboundMapArchive.KittenParkAnnex
--      (K-D17);
--   5. Park.build(Workspace.Candy_Este_v1): the park (Candy_Este_v1.Park, K-D16, K-D18);
--   6. Park.syncNests: the eight nests Candy_Este_v1.Nests.Nest_K1..K8 (K-D8; the server repeats it at every start);
--   7. the root mark KittenPark = 1;
--   8. one ChangeHistory entry, "KittenPark" (cancelled, so undone, on any failure);
--   9. a JSON summary: the part counts per folder before and after, the archived pieces and the warnings.
-- Everything archived is reparented, never destroyed. Anything named SistemaSonriente, or under it, is never touched.
local DRY_RUN = true -- true: only report; false: change the map (one undo step)

local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Edit mode only: stop Play first")
local ServerStorage, Workspace = game:GetService("ServerStorage"), game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local SUMMARY_ATTRIBUTE = "WildboundKittenParkSummary"
local MARK, NEEDS = "KittenPark", "CaramelV8"
local BACKUP, GATE_ARCHIVE, ANNEX_ARCHIVE = "KittenParkBackup", "KittenGate", "KittenParkAnnex"
local ANNEX_NAME = "WildboundCandyAnnex_Big4"

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
-- BaseParts per child folder of a holder (Candy_Este_v1.Park's nine folders, or the root's own folders).
local function countFolders(holder)
	local out = {}
	for _, c in ipairs(holder and holder:GetChildren() or {}) do out[c.Name] = countParts(c) end
	return out
end
local function publish(summary)
	local json = HttpService:JSONEncode(summary)
	_G.WildboundKittenParkSummary = summary
	pcall(function() ServerStorage:SetAttribute(SUMMARY_ATTRIBUTE, json) end)
	print("KittenPark " .. json)
	return json
end

local Layout = module(ServerStorage, "WildboundCandyLayout")
assert(Layout and Layout.HALF == 260 and type(Layout.KEEP_CLEAR) == "table",
	"deploy the v8 WildboundCandyLayout (HALF 260, with the K-D2 gate row) first")
local gateRow = false
for _, spot in ipairs(Layout.KEEP_CLEAR) do
	if spot.why == "Cloud gate to Caramelo Este" then gateRow = true end
end
assert(gateRow, "deploy the WildboundCandyLayout with the K-D2 KEEP_CLEAR gate row first")
local East = module(ServerStorage, "WildboundCandyEast")
assert(East and type(East.build) == "function" and type(East.GATE) == "table", "deploy ServerStorage.WildboundCandyEast with GATE (K-D1) first")
local Park = module(ServerStorage, "WildboundKittenPark")
assert(Park and type(Park.build) == "function" and type(Park.syncNests) == "function" and type(Park.clearGate) == "function"
	and type(Park.archiveAnnex) == "function", "deploy ServerStorage.WildboundKittenPark first")
local bioma = Workspace:FindFirstChild(Layout.ROOT_NAME)
assert(bioma, "Workspace." .. Layout.ROOT_NAME .. " is missing")
assert(not forbidden(bioma), "refusing to touch SistemaSonriente")
assert(bioma:GetAttribute(NEEDS) ~= nil, "run tools/wildbound-caramelo-v8-migrate.luau first (no CaramelV8 mark)")
local annex = Workspace:FindFirstChild(ANNEX_NAME)
if annex and forbidden(annex) then annex = nil end
local eastRoot = Workspace:FindFirstChild(East.ROOT_NAME)
if eastRoot and forbidden(eastRoot) then error("refusing to touch SistemaSonriente") end

local plan = Park.plan(Layout, East)
local summary = { dryRun = DRY_RUN, already = false, version = Park.VERSION, warnings = {}, dropped = {},
	partsBefore = { bioma = countParts(bioma), annex = countParts(annex), east = countParts(eastRoot),
		eastFolders = countFolders(eastRoot), park = countFolders(eastRoot and eastRoot:FindFirstChild(Park.FOLDER)) },
	planned = { budget = plan.budget, park = plan.parts, cap = Park.PART_CAP, nests = #Park.NESTS * Park.NEST_PARTS } }
for _, d in ipairs(plan.dropped) do
	table.insert(summary.dropped, ("%s (%s, %d parts): %s"):format(d.id, d.folder, d.parts, d.reason))
end
if plan.parts > Park.PART_CAP then table.insert(summary.warnings, "the park plan is over its cap") end
if not annex then table.insert(summary.warnings, "no Workspace." .. ANNEX_NAME .. ": nothing to archive from the annex") end

if eastRoot and eastRoot:GetAttribute(MARK) ~= nil then
	summary.already = true
	summary.mark = eastRoot:GetAttribute(MARK)
	publish(summary)
	return summary
end

-- The lists the real run will archive (read only).
local function lists()
	return Park.clearGate(bioma, nil, true), Park.archiveAnnex(annex, nil, Layout, East, true)
end

if DRY_RUN then
	local gate, annexList = lists()
	summary.gate = gate
	summary.annex = annexList
	-- the park and the wall laid into a detached scratch model (never parented: the map is untouched)
	local ok, laid = pcall(function()
		local scratch = Instance.new("Model")
		local out = {}
		out.east = select(2, East.build(scratch, Layout)).parts
		local root = scratch:FindFirstChild(East.ROOT_NAME)
		local report = Park.build(root, Layout, East)
		out.park, out.byFolder = report.parts, report.byFolder
		Park.syncNests(root)
		out.nests = countParts(root:FindFirstChild(Park.NESTS_FOLDER))
		out.total = countParts(root)
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
_G.WildboundKittenParkSummary = nil
task.delay(0.5, function()
	local recording
	local opened = pcall(function() recording = ChangeHistoryService:TryBeginRecording("KittenPark") end)
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
		elseif eastRoot then
			local holder = Instance.new("Folder")
			holder.Name = BACKUP
			local copy = eastRoot:Clone()
			if copy then copy.Parent = holder end
			holder.Parent = archiveRoot
			summary.backup = holder:GetFullName()
		else
			summary.backup = "no Workspace." .. East.ROOT_NAME .. " to back up"
		end
		-- 2. the gate split and the green floor
		local root, report = East.build(Workspace, Layout)
		summary.east = report
		-- 3. the gate corridor of the plot
		summary.gate = Park.clearGate(bioma, folder(GATE_ARCHIVE), false)
		-- 4. the annex props in the second space
		summary.annex = Park.archiveAnnex(annex, folder(ANNEX_ARCHIVE), Layout, East, false)
		-- 5. the park
		summary.park = Park.build(root, Layout, East)
		-- 6. the nests
		summary.nestsChanged = Park.syncNests(root)
		-- 7. mark
		root:SetAttribute(MARK, 1)
	end)
	ChangeHistoryService:FinishRecording(recording,
		ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
	if not ok then summary.error = "failed and undone: " .. tostring(failure) end
	local after = Workspace:FindFirstChild(East.ROOT_NAME)
	summary.partsAfter = { bioma = countParts(bioma), annex = countParts(annex), east = countParts(after),
		eastFolders = countFolders(after), park = countFolders(after and after:FindFirstChild(Park.FOLDER)) }
	summary.overCap = (summary.partsAfter.east or 0) > Park.PART_CAP + #Park.NESTS * Park.NEST_PARTS + 6
	publish(summary)
end)
print("KittenPark: scheduled; read ServerStorage:GetAttribute(\"" .. SUMMARY_ATTRIBUTE .. "\") in a few seconds")
return { scheduled = true, dryRun = false, summaryAttribute = SUMMARY_ATTRIBUTE }

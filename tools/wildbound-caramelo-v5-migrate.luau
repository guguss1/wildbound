-- Caramelo v5 on the live map (owner's third round 2026-11-17; odd/tasks/wildbound-caramelo-v2.md "Caramelo v5",
-- V5-D3 to V5-D5; docs/design/wildbound-caramelo-v3-plan.md "Caramelo v5", V5-D10 on). Studio Edit mode only: run it
-- from the command bar or execute_luau (or task.spawn + loadstring from a StringValue), first with DRY_RUN = true to
-- read the plan, then with DRY_RUN = false. Not deployed: a one-shot tool, the same pattern as
-- tools/wildbound-caramelo-v4-migrate.luau.
--
-- It runs once, on a map the v4 migration changed (root attributes CaramelV3 and CaramelV4) and not yet marked
-- CaramelV5 (it returns the summary "already" then). It needs, in ServerStorage: WildboundCandyLayout VERSION 3,
-- WildboundCandyV3Layout VERSION 3 (the v5 data) and WildboundCandyV3Builder (planV5, layWater). The modules are
-- required from fresh clones.
--
-- The real run (one undo step, ChangeHistoryService recording "CaramelV5") runs in a deferred thread (task.delay),
-- because a call made from inside another recording (execute_luau is one) cannot open its own. Read the result from
-- ServerStorage's attribute WildboundCaramelV5Summary (JSON; "pending" until done) or _G.WildboundCaramelV5Summary.
-- In that thread, in this order:
--   1. backup: a clone of Workspace.Candy_Bioma_v1 into ServerStorage.WildboundMapArchive.CaramelV5Backup (an existing
--      one is kept and the summary warns);
--   2. V3Builder.planV5: CaramelV3's River, Lake, Bridges and Docks (laid again), and every tree, prop, hill or cookie
--      tree (the old kit's prop folders, CaramelV3.Trees, Filler and EdgeFill) now standing in the wider chocolate, on
--      or by a bridge, or on a dock or another piece, are archived (reparented, never destroyed) into
--      WildboundMapArchive.CaramelV5Archived. Nests, creature posts, houses, mountains, the cake, the licorice, the
--      waterfall, the cookie platforms and the pink hills never move;
--   3. V3Builder.layWater: the v5 river (24 wide on its open legs) with its pool, the two lake discs, the five bridges
--      (Top and Bottom longer) and the two docks, into the existing root.CaramelV3;
--   4. the raft: a raft model standing in the Edit place (Workspace.WildboundCandyRaft.BalsaBananaSplit) is moved to its
--      home dock's tip; normally there is none in Edit (WildboundCandyRaftService builds it at the home dock in Play,
--      from the same layout) and the summary says so;
--   5. the root's CaramelV5 = 1.
-- Anything named SistemaSonriente, or under it, is never touched. The JSON summary lists every archive, the part counts
-- before and after (and, in a dry run, an estimate) and what happened to the raft.
local DRY_RUN = true -- true: only report; false: change the map (one undo step)

local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Edit mode only: stop Play first")
local ServerStorage, Workspace = game:GetService("ServerStorage"), game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local SUMMARY_ATTRIBUTE = "WildboundCaramelV5Summary"
local RAFT_FOLDER, RAFT_MODEL = "WildboundCandyRaft", "BalsaBananaSplit"

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
	local n = 0
	for _, d in ipairs(instance:GetDescendants()) do
		if d:IsA("BasePart") then n += 1 end
	end
	return n
end
local function publish(summary)
	local json = HttpService:JSONEncode(summary)
	_G.WildboundCaramelV5Summary = summary
	pcall(function() ServerStorage:SetAttribute(SUMMARY_ATTRIBUTE, json) end)
	print("CaramelV5 " .. json)
	return json
end

local Layout = module(ServerStorage, "WildboundCandyLayout")
assert(Layout and Layout.VERSION == 3, "deploy the GT WildboundCandyLayout (VERSION 3) first")
local V3 = module(ServerStorage, "WildboundCandyV3Layout")
assert(V3 and V3.VERSION == 3 and V3.V5_MARK, "deploy the v5 ServerStorage.WildboundCandyV3Layout (VERSION 3) first")
local V3Builder = module(ServerStorage, "WildboundCandyV3Builder")
assert(V3Builder and type(V3Builder.planV5) == "function" and type(V3Builder.layWater) == "function",
	"deploy the v5 ServerStorage.WildboundCandyV3Builder first")
local root = Workspace:FindFirstChild(Layout.ROOT_NAME)
assert(root, "Workspace." .. Layout.ROOT_NAME .. " is missing")
assert(not forbidden(root), "refusing to touch SistemaSonriente")
assert(root:GetAttribute(V3.MARK) ~= nil and root:FindFirstChild(V3.FOLDER),
	"run tools/wildbound-caramelo-v3-migrate.luau first (no CaramelV3 on the map)")
assert(root:GetAttribute(V3.V4_MARK) ~= nil, "run tools/wildbound-caramelo-v4-migrate.luau first (no CaramelV4 mark)")

local deps = { Layout = Layout, V3 = V3 }
local summary = { dryRun = DRY_RUN, already = false, partsBefore = countParts(root), archived = {},
	cap = V3.BIOME_PART_CAP, version = V3.VERSION }

if root:GetAttribute(V3.V5_MARK) ~= nil then
	summary.already = true
	summary.mark = root:GetAttribute(V3.V5_MARK)
	publish(summary)
	return summary
end

-- The raft's home dock in world studs: the tip (where it waits), its yaw (looking out from the stand) and the surface.
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

-- The water of the current layout, laid into a detached copy of an empty CaramelV3 (never parented: the map is
-- untouched): its part count.
local function probeWater()
	local scratch = Instance.new("Model")
	local holder = Instance.new("Folder")
	holder.Name = V3.FOLDER
	holder.Parent = scratch
	local report = V3Builder.layWater(scratch, deps)
	scratch.Parent = nil
	return report.parts
end

if DRY_RUN then
	local plan = V3Builder.planV5(root, Layout, V3)
	local archivedParts = 0
	for _, a in ipairs(plan.archive) do
		table.insert(summary.archived, a.instance:GetFullName() .. ": " .. a.why)
		archivedParts += countParts(a.instance)
	end
	summary.kept, summary.water, summary.archivedParts = plan.kept, plan.water, archivedParts
	summary.pieces = #plan.archive - plan.water
	local _, dockId = homeDock()
	summary.raft = raftModel() and ("would move to dock " .. dockId) or ("none in Edit: the service builds it at dock " .. dockId)
	local ok, laid = pcall(probeWater)
	if ok then
		summary.waterParts = laid
		summary.partsEstimate = summary.partsBefore - archivedParts + laid
		summary.overCap = summary.partsEstimate > V3.BIOME_PART_CAP
	else
		summary.waterParts = { error = tostring(laid) }
	end
	publish(summary)
	return summary
end

-- The real run, in its own thread and its own recording.
pcall(function() ServerStorage:SetAttribute(SUMMARY_ATTRIBUTE, "pending") end)
_G.WildboundCaramelV5Summary = nil
task.delay(0.5, function()
	local recording
	local opened = pcall(function() recording = ChangeHistoryService:TryBeginRecording("CaramelV5") end)
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
		local archived = archiveRoot:FindFirstChild("CaramelV5Archived")
		if not archived then
			archived = Instance.new("Folder")
			archived.Name = "CaramelV5Archived"
			archived.Parent = archiveRoot
		end
		local function archive(instance, why)
			if forbidden(instance) then return end
			table.insert(summary.archived, instance:GetFullName() .. ": " .. why)
			instance.Parent = archived
		end
		-- 1. backup
		local old = archiveRoot:FindFirstChild("CaramelV5Backup")
		if old then
			summary.backup = "kept the existing CaramelV5Backup"
			summary.warning = "an older CaramelV5Backup was kept: check it before any restore"
		else
			local holder = Instance.new("Folder")
			holder.Name = "CaramelV5Backup"
			local copy = root:Clone()
			copy.Parent = holder
			holder.Parent = archiveRoot
			summary.backup = holder:GetFullName()
		end
		-- 2. the plan
		local plan = V3Builder.planV5(root, Layout, V3)
		for _, a in ipairs(plan.archive) do archive(a.instance, a.why) end
		summary.kept, summary.water, summary.pieces = plan.kept, plan.water, #plan.archive - plan.water
		-- 3. the water, laid again
		summary.waterParts = V3Builder.layWater(root, deps).parts
		-- 4. the raft to its home dock (only when a model stands in the Edit place)
		local cf, dockId = homeDock()
		local raft = raftModel()
		if raft then
			raft:PivotTo(cf)
			summary.raft = "moved to dock " .. dockId
		else
			summary.raft = "none in Edit: the service builds it at dock " .. dockId
		end
		-- 5. mark
		root:SetAttribute(V3.V5_MARK, 1)
	end)
	ChangeHistoryService:FinishRecording(recording,
		ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
	if not ok then summary.error = "failed and undone: " .. tostring(failure) end
	summary.partsAfter = countParts(root)
	summary.overCap = summary.partsAfter > V3.BIOME_PART_CAP
	publish(summary)
end)
print("CaramelV5: scheduled; read ServerStorage:GetAttribute(\"" .. SUMMARY_ATTRIBUTE .. "\") in a few seconds")
return { scheduled = true, dryRun = false, summaryAttribute = SUMMARY_ATTRIBUTE }

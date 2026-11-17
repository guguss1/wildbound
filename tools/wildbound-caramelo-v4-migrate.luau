-- Caramelo v4 on the live map (owner's second round 2026-11-17; odd/tasks/wildbound-caramelo-v2.md "Caramelo v4",
-- V4-D1 to V4-D17; docs/design/wildbound-caramelo-v3-plan.md "Caramelo v4"). Studio Edit mode only: run it from the
-- command bar or execute_luau, first with DRY_RUN = true to read the plan, then with DRY_RUN = false. Not deployed: a
-- one-shot tool, the same pattern as tools/wildbound-caramelo-v3-migrate.luau.
--
-- It runs once, on a map the v3 migration changed (root attribute CaramelV3) and not yet marked CaramelV4 (it returns
-- the summary "already" then). It needs, in ServerStorage: WildboundCandyLayout VERSION 3, WildboundCandyBuilder
-- (treeKeepOut, treeFits), WildboundCandyV3Layout VERSION 2 (the v4 data), WildboundCandyV3Builder (planV4, layAll with
-- relay, refitTrees, retagHouses), WildboundCandyV3KitSpec, WildboundCandyKit and WildboundAssets.CandyKit; and the
-- deployed ServerScriptService.WildboundPraderaSites with ReplicatedStorage.WildboundBeastConfig (the creature posts
-- must be in the keep-out, or it refuses). WildboundAssets.CandyKitV3 should hold the 16 CV3_* models (a missing one is
-- a placeholder; the summary lists kitMissing). The modules are required from fresh clones.
--
-- The real run (one undo step, ChangeHistoryService recording "CaramelV4") runs in a deferred thread (task.delay),
-- because a call made from inside another recording (execute_luau is one) cannot open its own. Read the result from
-- ServerStorage's attribute WildboundCaramelV4Summary (JSON; "pending" until done) or _G.WildboundCaramelV4Summary.
-- In that thread, in this order:
--   1. backup: a clone of Workspace.Candy_Bioma_v1 into ServerStorage.WildboundMapArchive.CaramelV4Backup (an existing
--      one is kept and the summary warns);
--   2. V3Builder.planV4: every child of root.CaramelV3 but Trees (the river, lake, waterfall, bridge, docks, mountains,
--      houses, licorice, cake, platforms, filler: all laid again), every yellow crystal (RockSugar), and every prop or
--      CaramelV3 tree in the new chocolate, on a bridge, on a v4 piece or on a pink hill, are archived (reparented,
--      never destroyed) into WildboundMapArchive.CaramelV4Archived;
--   3. V3Builder.refitTrees: the swapped trees grow 35 % (V4-D4), fitted; their La Nube Roof discs stay in the crown;
--   4. V3Builder.layAll with relay = true: the v4 river, lake, pool, waterfall streaks, bridges, docks, mountains,
--      houses (H1, H3, H5 at 1.4; towers turned, V4-D15; all tagged overhead, V4-D12), licorice, cake, platforms on
--      pedestals, filler, the pink hills at the crystal spots, the backdrop and the edge fill (its budget cut so the
--      biome stays at V3.V4_PART_TARGET), into the existing root.CaramelV3 (its Trees kept);
--   5. V3Builder.retagHouses (a no-op on fresh houses; kept for safety) and the root's CaramelV4 = 1.
-- Anything named SistemaSonriente, or under it, is never touched. The JSON summary lists every archive, refit and
-- placeholder, with the part counts before and after (and, in a dry run, an estimate).
local DRY_RUN = true -- true: only report; false: change the map (one undo step)

local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Edit mode only: stop Play first")
local ServerStorage, Workspace = game:GetService("ServerStorage"), game:GetService("Workspace")
local ServerScriptService, ReplicatedStorage = game:GetService("ServerScriptService"), game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local SUMMARY_ATTRIBUTE = "WildboundCaramelV4Summary"

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
	_G.WildboundCaramelV4Summary = summary
	pcall(function() ServerStorage:SetAttribute(SUMMARY_ATTRIBUTE, json) end)
	print("CaramelV4 " .. json)
	return json
end

local Layout = module(ServerStorage, "WildboundCandyLayout")
assert(Layout and Layout.VERSION == 3, "deploy the GT WildboundCandyLayout (VERSION 3) first")
local Builder = module(ServerStorage, "WildboundCandyBuilder")
assert(Builder and type(Builder.treeFits) == "function" and type(Builder.treeKeepOut) == "function",
	"ServerStorage.WildboundCandyBuilder has no tree rule (treeFits, treeKeepOut)")
local V3 = module(ServerStorage, "WildboundCandyV3Layout")
assert(V3 and V3.VERSION == 2 and V3.V4_MARK, "deploy the v4 ServerStorage.WildboundCandyV3Layout (VERSION 2) first")
local V3Builder = module(ServerStorage, "WildboundCandyV3Builder")
assert(V3Builder and type(V3Builder.layAll) == "function" and type(V3Builder.planV4) == "function"
	and type(V3Builder.refitTrees) == "function" and type(V3Builder.retagHouses) == "function",
	"deploy the v4 ServerStorage.WildboundCandyV3Builder first")
local KitSpec = module(ServerStorage, "WildboundCandyV3KitSpec")
assert(KitSpec, "deploy ServerStorage.WildboundCandyV3KitSpec first")
local Kit = module(ServerStorage, "WildboundCandyKit")
assert(Kit, "ServerStorage.WildboundCandyKit is missing")
local assets = ServerStorage:FindFirstChild("WildboundAssets")
local library = assets and assets:FindFirstChild(Kit.LIBRARY_NAME)
assert(library, "ServerStorage.WildboundAssets." .. Kit.LIBRARY_NAME .. " is missing")
local kitV3 = assets and assets:FindFirstChild(V3.KIT_FOLDER) or nil
local root = Workspace:FindFirstChild(Layout.ROOT_NAME)
assert(root, "Workspace." .. Layout.ROOT_NAME .. " is missing")
assert(not forbidden(root), "refusing to touch SistemaSonriente")
assert(root:GetAttribute(V3.MARK) ~= nil and root:FindFirstChild(V3.FOLDER),
	"run tools/wildbound-caramelo-v3-migrate.luau first (no CaramelV3 on the map)")

-- the keep-out must hold every creature post (and the trap cakes), or the edge fill could land on one
local keepOut = Builder.treeKeepOut(Layout)
do
	local sites = ServerScriptService:FindFirstChild("WildboundPraderaSites")
	assert(sites and ReplicatedStorage:FindFirstChild("WildboundBeastConfig"),
		"deploy ServerScriptService.WildboundPraderaSites and ReplicatedStorage.WildboundBeastConfig first")
	local Sites = require(sites)
	local want, got = 0, 0
	for _ in pairs(Sites.FIXED) do want += 1 end
	for _, k in ipairs(keepOut) do
		if string.sub(tostring(k.why), 1, 5) == "post " then got += 1 end
	end
	assert(got == want and want > 0, ("the keep-out found %d of %d creature posts: refusing"):format(got, want))
end

local deps = { Layout = Layout, V3 = V3, Builder = Builder, kitV3 = kitV3, kitSpec = KitSpec, Kit = Kit, library = library,
	keepOut = keepOut, relay = true }
local missing = {}
for _, asset in ipairs(V3.ASSETS) do
	if not (kitV3 and kitV3:FindFirstChild(asset)) then table.insert(missing, asset) end
end
local summary = { dryRun = DRY_RUN, already = false, partsBefore = countParts(root), archived = {}, kitMissing = missing,
	keepOut = #keepOut, target = V3.V4_PART_TARGET, cap = V3.BIOME_PART_CAP,
	kitFolder = kitV3 and kitV3:GetFullName() or "none (every piece a placeholder)" }

if root:GetAttribute(V3.V4_MARK) ~= nil then
	summary.already = true
	summary.version = root:GetAttribute(V3.V4_MARK)
	publish(summary)
	return summary
end

-- The edge fill's budget: what is left under V3.V4_PART_TARGET once everything else is counted (V4-D17).
local function edgeBudget(partsWithoutEdge)
	return math.max(0, math.min(V3.EDGE.maxParts, V3.V4_PART_TARGET - partsWithoutEdge))
end

-- A build of the v4 batch into a detached model (never parented: the map is untouched), off `existing`, with the edge
-- fill's budget: its report.
local function probe(existing, budget)
	local probeDeps = table.clone(deps)
	probeDeps.relay, probeDeps.existing, probeDeps.edgeBudget = false, existing, budget
	return V3Builder.layAll(Instance.new("Model"), probeDeps)
end

if DRY_RUN then
	local plan = V3Builder.planV4(root, Layout, V3)
	local archivedSet, archivedParts = {}, 0
	for _, a in ipairs(plan.archive) do
		table.insert(summary.archived, a.instance:GetFullName() .. ": " .. a.why)
		archivedSet[a.instance] = true
		archivedParts += countParts(a.instance)
	end
	summary.kept, summary.treesKept, summary.archivedParts = plan.kept, plan.trees, archivedParts
	local refit = V3Builder.refitTrees(root, deps, function() end, true)
	summary.refit = { refit = #refit.refit, kept = refit.kept }
	-- the props still standing once the plan's archive is gone
	local existing = {}
	for _, e in ipairs(V3Builder.existingProps(root, Layout)) do
		local gone = false
		for instance in pairs(archivedSet) do
			local name = instance:GetFullName()
			if e.name == name or string.sub(e.name, 1, #name + 1) == name .. "." then gone = true end
		end
		if not gone then table.insert(existing, e) end
	end
	local ok, result = pcall(function()
		local baseline = probe(existing, 0)
		local budget = edgeBudget(summary.partsBefore - archivedParts + baseline.parts + baseline.edgeParts)
		return { budget = budget, laid = probe(existing, budget) }
	end)
	if ok then
		local laid = result.laid
		summary.edgeBudget = result.budget
		summary.laid = { parts = laid.parts, edgeParts = laid.edgeParts, placeholders = laid.placeholders, filler = laid.filler,
			hills = laid.hills, edgeTrees = laid.edgeTrees, edgeProps = laid.edgeProps, edgeHills = laid.edgeHills }
		summary.partsEstimate = summary.partsBefore - archivedParts + laid.parts + laid.edgeParts
		summary.overCap = summary.partsEstimate > V3.BIOME_PART_CAP
		summary.overTarget = summary.partsEstimate > V3.V4_PART_TARGET
	else
		summary.laid = { error = tostring(result) }
		summary.overBatchBudget = true
	end
	publish(summary)
	return summary
end

-- The real run, in its own thread and its own recording.
pcall(function() ServerStorage:SetAttribute(SUMMARY_ATTRIBUTE, "pending") end)
_G.WildboundCaramelV4Summary = nil
task.delay(0.5, function()
	local recording
	local opened = pcall(function() recording = ChangeHistoryService:TryBeginRecording("CaramelV4") end)
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
		local archived = archiveRoot:FindFirstChild("CaramelV4Archived")
		if not archived then
			archived = Instance.new("Folder")
			archived.Name = "CaramelV4Archived"
			archived.Parent = archiveRoot
		end
		local function archive(instance, why)
			if forbidden(instance) then return end
			table.insert(summary.archived, instance:GetFullName() .. ": " .. why)
			instance.Parent = archived
		end
		-- 1. backup
		local old = archiveRoot:FindFirstChild("CaramelV4Backup")
		if old then
			summary.backup = "kept the existing CaramelV4Backup"
			summary.warning = "an older CaramelV4Backup was kept: check it before any restore"
		else
			local holder = Instance.new("Folder")
			holder.Name = "CaramelV4Backup"
			local copy = root:Clone()
			copy.Parent = holder
			holder.Parent = archiveRoot
			summary.backup = holder:GetFullName()
		end
		-- 2. the plan
		local plan = V3Builder.planV4(root, Layout, V3)
		for _, a in ipairs(plan.archive) do archive(a.instance, a.why) end
		summary.kept, summary.treesKept = plan.kept, plan.trees
		-- 3. the trees grow (before the filler and the edge fill, which then keep off them)
		local refit = V3Builder.refitTrees(root, deps, archive, false)
		summary.refit = { refit = refit.refit, kept = refit.kept }
		-- 4. the v4 batch, into the existing CaramelV3 (its trees kept); the edge fill's budget keeps the target
		local baseline = probe(V3Builder.existingProps(root, Layout), 0)
		local layDeps = table.clone(deps)
		layDeps.edgeBudget = edgeBudget(countParts(root) + baseline.parts + baseline.edgeParts)
		summary.edgeBudget = layDeps.edgeBudget
		local laid = V3Builder.layAll(root, layDeps)
		summary.laid = { parts = laid.parts, edgeParts = laid.edgeParts, placeholders = laid.placeholders, filler = laid.filler,
			fillerSkipped = laid.fillerSkipped, hills = laid.hills, edgeTrees = laid.edgeTrees, edgeProps = laid.edgeProps,
			edgeHills = laid.edgeHills }
		-- 5. retag and mark
		summary.retagged = V3Builder.retagHouses(root, V3)
		root:SetAttribute(V3.V4_MARK, 1)
	end)
	ChangeHistoryService:FinishRecording(recording,
		ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
	if not ok then summary.error = "failed and undone: " .. tostring(failure) end
	summary.partsAfter = countParts(root)
	summary.overCap = summary.partsAfter > V3.BIOME_PART_CAP
	summary.overTarget = summary.partsAfter > V3.V4_PART_TARGET
	publish(summary)
end)
print("CaramelV4: scheduled; read ServerStorage:GetAttribute(\"" .. SUMMARY_ATTRIBUTE .. "\") in a few seconds")
return { scheduled = true, dryRun = false, summaryAttribute = SUMMARY_ATTRIBUTE }

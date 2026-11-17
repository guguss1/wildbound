-- Caramelo v3 on the already-built live map (owner request 2026-11-17: the three new trees, the big chocolate river
-- from the ice-cream mountains with its waterfall, a bridge, the free raft's docks, houses with interiors, the rainbow
-- licorice, the modular cake, the cookie platforms; docs/design/wildbound-caramelo-v3-plan.md). Studio Edit mode only:
-- run it once from the command bar or execute_luau, first with DRY_RUN = true to read the plan, then with
-- DRY_RUN = false. Not deployed: a one-shot tool, the same pattern as tools/wildbound-caramelo-cake-move.luau.
--
-- Needs, in ServerStorage: WildboundCandyLayout VERSION 3 on a map already moved by the cake-move tool (root
-- attribute CakeMoveV1), WildboundCandyBuilder (treeKeepOut, treeFits), WildboundCandyV3Layout, WildboundCandyV3Builder,
-- WildboundCandyV3KitSpec, WildboundCandyKit and WildboundAssets.CandyKit; WildboundAssets.CandyKitV3 is optional
-- (every missing model is laid as a placeholder, swapped for the kit later by archiving CaramelV3 and running again
-- after clearing the mark). It refuses to run on older modules, in Play, or on a root already marked CaramelV3 (it
-- returns the summary "already").
--
-- The real run (one undo step, ChangeHistoryService recording "CaramelV3"): it runs in a deferred thread (task.delay),
-- because a call made from inside another recording (execute_luau is one) cannot open its own. The caller reads the
-- result afterwards from ServerStorage's attribute WildboundCaramelV3Summary (JSON; "pending" until done) or from
-- _G.WildboundCaramelV3Summary. In that thread, in this order:
--   1. backup: a clone of Workspace.Candy_Bioma_v1 into ServerStorage.WildboundMapArchive.CaramelV3Backup (skipped when
--      one is already there);
--   2. V3Builder.plan: kit props in the chocolate, on the bridge or on a v3 piece, and the old syrup discs and biscuit
--      bridge tiles, are archived (reparented, never destroyed) into ServerStorage.WildboundMapArchive.CaramelV3Archived;
--   3. V3Builder.layAll: the river, lake, waterfall streaks, bridge, docks, mountains, houses, licorice, cake, cookie
--      platforms and filler, into root.CaramelV3;
--   4. V3Builder.swapTrees: every old cotton, cream and cookie tree that fits takes its new kind (the old one archived;
--      a cotton tree's Roof moves into the new tree); a tree that does not fit stays;
--   5. the root's CaramelV3 = V3.VERSION.
-- Anything named SistemaSonriente, or under it, is never touched. The JSON summary lists every archive, swap and
-- placeholder, with the part counts before and after.
local DRY_RUN = true -- true: only report; false: lay Caramelo v3 (one undo step)

local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Edit mode only: stop Play first")
local ServerStorage, Workspace = game:GetService("ServerStorage"), game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local SUMMARY_ATTRIBUTE = "WildboundCaramelV3Summary"

local function module(parent, name)
	local found = parent and parent:FindFirstChild(name)
	return found and found:IsA("ModuleScript") and require(found) or nil
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
	_G.WildboundCaramelV3Summary = summary
	pcall(function() ServerStorage:SetAttribute(SUMMARY_ATTRIBUTE, json) end)
	print("CaramelV3 " .. json)
	return json
end

local Layout = module(ServerStorage, "WildboundCandyLayout")
assert(Layout and Layout.VERSION == 3, "deploy the GT WildboundCandyLayout (VERSION 3) first")
local Builder = module(ServerStorage, "WildboundCandyBuilder")
assert(Builder and type(Builder.treeFits) == "function" and type(Builder.treeKeepOut) == "function",
	"ServerStorage.WildboundCandyBuilder has no tree rule (treeFits, treeKeepOut)")
local V3 = module(ServerStorage, "WildboundCandyV3Layout")
assert(V3 and V3.VERSION == 1, "deploy ServerStorage.WildboundCandyV3Layout first")
local V3Builder = module(ServerStorage, "WildboundCandyV3Builder")
assert(V3Builder and type(V3Builder.layAll) == "function" and type(V3Builder.plan) == "function"
	and type(V3Builder.swapTrees) == "function", "deploy ServerStorage.WildboundCandyV3Builder first")
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
assert(root:GetAttribute("CakeMoveV1") == true and root:GetAttribute("LayoutVersion") == 3,
	"run tools/wildbound-caramelo-cake-move.luau first (the map is not on layout v3)")

if root:GetAttribute(V3.MARK) ~= nil then
	local done = { dryRun = DRY_RUN, already = true, version = root:GetAttribute(V3.MARK) }
	publish(done)
	return done
end

local keepOut = Builder.treeKeepOut(Layout)
local deps = { Layout = Layout, V3 = V3, Builder = Builder, kitV3 = kitV3, kitSpec = KitSpec, Kit = Kit, library = library,
	keepOut = keepOut }
local missing = {}
for _, asset in ipairs(V3.ASSETS) do
	if not (kitV3 and kitV3:FindFirstChild(asset)) then table.insert(missing, asset) end
end
local summary = { dryRun = DRY_RUN, already = false, partsBefore = countParts(root), archived = {}, kitMissing = missing,
	kitFolder = kitV3 and kitV3:GetFullName() or "none (every piece a placeholder)" }

if DRY_RUN then
	local plan = V3Builder.plan(root, Layout, V3)
	for _, a in ipairs(plan.archive) do table.insert(summary.archived, a.instance:GetFullName() .. ": " .. a.why) end
	summary.kept = plan.kept
	-- the swap is judged on the map as it stands (the trees the plan archives are counted as kept there)
	local swap = V3Builder.swapTrees(root, deps, function() end, true)
	summary.swap = { swapped = #swap.swapped, kept = swap.kept }
	publish(summary)
	return summary
end

-- The real run, in its own thread and its own recording.
pcall(function() ServerStorage:SetAttribute(SUMMARY_ATTRIBUTE, "pending") end)
_G.WildboundCaramelV3Summary = nil
task.delay(0.5, function()
	local recording
	local opened = pcall(function() recording = ChangeHistoryService:TryBeginRecording("CaramelV3") end)
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
		-- 1. backup
		if archiveRoot:FindFirstChild("CaramelV3Backup") then
			summary.backup = "kept the existing CaramelV3Backup"
		else
			local holder = Instance.new("Folder")
			holder.Name = "CaramelV3Backup"
			local copy = root:Clone()
			copy.Parent = holder
			holder.Parent = archiveRoot
			summary.backup = holder:GetFullName()
		end
		local archived = archiveRoot:FindFirstChild("CaramelV3Archived")
		if not archived then
			archived = Instance.new("Folder")
			archived.Name = "CaramelV3Archived"
			archived.Parent = archiveRoot
		end
		local function archive(instance, why)
			if forbidden(instance) then return end
			table.insert(summary.archived, instance:GetFullName() .. ": " .. why)
			instance.Parent = archived
		end
		-- 2. the plan
		local plan = V3Builder.plan(root, Layout, V3)
		for _, a in ipairs(plan.archive) do archive(a.instance, a.why) end
		summary.kept = plan.kept
		-- 3. the pieces
		local laid = V3Builder.layAll(root, deps)
		summary.laid = { parts = laid.parts, placeholders = laid.placeholders, filler = laid.filler,
			fillerSkipped = laid.fillerSkipped, hills = laid.hills }
		-- 4. the trees
		local swap = V3Builder.swapTrees(root, deps, archive, false)
		summary.swap = { swapped = swap.swapped, kept = swap.kept, parts = swap.parts, placeholders = swap.placeholders }
		-- 5. mark
		root:SetAttribute(V3.MARK, V3.VERSION)
	end)
	ChangeHistoryService:FinishRecording(recording,
		ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
	if not ok then summary.error = "failed and undone: " .. tostring(failure) end
	summary.partsAfter = countParts(root)
	summary.overCap = summary.partsAfter > V3.BIOME_PART_CAP
	publish(summary)
end)
print("CaramelV3: scheduled; read ServerStorage:GetAttribute(\"" .. SUMMARY_ATTRIBUTE .. "\") in a few seconds")
return { scheduled = true, dryRun = false, summaryAttribute = SUMMARY_ATTRIBUTE }

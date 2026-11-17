-- Caramelo v3 on the already-built live map (owner request 2026-11-17: the three new trees, the big chocolate river
-- from the ice-cream mountains with its waterfall, a bridge, the free raft's docks, houses with interiors, the rainbow
-- licorice, the modular cake, the cookie platforms; docs/design/wildbound-caramelo-v3-plan.md). Studio Edit mode only:
-- run it from the command bar or execute_luau, first with DRY_RUN = true to read the plan, then with DRY_RUN = false.
-- Not deployed: a one-shot tool, the same pattern as tools/wildbound-caramelo-cake-move.luau.
--
-- Two modes (MODE):
--   "first"   the first run on a map moved by the cake-move tool (root attribute CakeMoveV1). It refuses a root already
--             marked CaramelV3 (it returns the summary "already").
--   "upgrade" (review M2) after the kit models reach ServerStorage.WildboundAssets.CandyKitV3: every placeholder piece
--             whose kit model is now there (mountains, houses, licorice, cake, platforms, hills, trees) is laid again
--             from the kit at the same spot and the placeholder is archived; a tree keeps its spot, height and La
--             Nube's Roof. Idempotent: a second run upgrades nothing. Never archive CaramelV3 and run "first" again:
--             the swapped trees and their Roof discs live in it.
--
-- Needs, in ServerStorage: WildboundCandyLayout VERSION 3, WildboundCandyBuilder (treeKeepOut, treeFits),
-- WildboundCandyV3Layout, WildboundCandyV3Builder, WildboundCandyV3KitSpec, WildboundCandyKit and
-- WildboundAssets.CandyKit; and the deployed ServerScriptService.WildboundPraderaSites with
-- ReplicatedStorage.WildboundBeastConfig (review m1: the creature posts must be in the keep-out, or it refuses).
-- WildboundAssets.CandyKitV3 is optional: every missing model is laid as a placeholder. The modules are required from
-- fresh clones (review m4), so a deploy after a dry run in the same session is read, not a cached copy.
--
-- The real run (one undo step, ChangeHistoryService recording "CaramelV3"): it runs in a deferred thread (task.delay),
-- because a call made from inside another recording (execute_luau is one) cannot open its own. The caller reads the
-- result afterwards from ServerStorage's attribute WildboundCaramelV3Summary (JSON; "pending" until done) or from
-- _G.WildboundCaramelV3Summary. "first", in that thread, in this order:
--   1. backup: a clone of Workspace.Candy_Bioma_v1 into ServerStorage.WildboundMapArchive.CaramelV3Backup (an existing
--      one is kept and the summary warns, with its LayoutVersion and CakeMoveV1);
--   2. V3Builder.plan: kit props in the chocolate, on or by the bridge or on a v3 piece, and the old syrup discs and
--      biscuit bridge tiles, are archived (reparented, never destroyed) into WildboundMapArchive.CaramelV3Archived;
--   3. V3Builder.layAll: the river, lake, waterfall streaks, bridge, docks, mountains, houses, licorice, cake, cookie
--      platforms and filler (off every prop still standing), into root.CaramelV3;
--   4. V3Builder.swapTrees: every old cotton, cream and cookie tree that fits takes its new kind (the old one archived;
--      a cotton tree's Roof moves into the new tree); a tree that does not fit stays;
--   5. the root's CaramelV3 = V3.VERSION.
-- "upgrade": V3Builder.upgradePlaceholders, archiving into the same folder; the root's CaramelV3KitUpgrades counts the
-- pieces upgraded so far. Anything named SistemaSonriente, or under it, is never touched. The JSON summary lists every
-- archive, swap, upgrade and placeholder, with the part counts before and after (and, in a dry run, an estimate).
local DRY_RUN = true -- true: only report; false: change the map (one undo step)
local MODE = "first" -- "first" or "upgrade"

local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Edit mode only: stop Play first")
assert(MODE == "first" or MODE == "upgrade", "MODE is \"first\" or \"upgrade\"")
local ServerStorage, Workspace = game:GetService("ServerStorage"), game:GetService("Workspace")
local ServerScriptService, ReplicatedStorage = game:GetService("ServerScriptService"), game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local SUMMARY_ATTRIBUTE = "WildboundCaramelV3Summary"

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
	and type(V3Builder.swapTrees) == "function" and type(V3Builder.upgradePlaceholders) == "function",
	"deploy the reviewed ServerStorage.WildboundCandyV3Builder first")
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

-- review m1: the keep-out must hold every creature post (and the trap cakes), or filler and nudged trees could land on
-- one and WildboundCandyBeastSites_Test would fail on the live map.
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
	keepOut = keepOut }
local missing = {}
for _, asset in ipairs(V3.ASSETS) do
	if not (kitV3 and kitV3:FindFirstChild(asset)) then table.insert(missing, asset) end
end
local summary = { mode = MODE, dryRun = DRY_RUN, already = false, partsBefore = countParts(root), archived = {},
	kitMissing = missing, keepOut = #keepOut, kitFolder = kitV3 and kitV3:GetFullName() or "none (every piece a placeholder)" }

if MODE == "first" and root:GetAttribute(V3.MARK) ~= nil then
	summary.already = true
	summary.version = root:GetAttribute(V3.MARK)
	publish(summary)
	return summary
end
if MODE == "upgrade" then
	assert(root:GetAttribute(V3.MARK) ~= nil and root:FindFirstChild(V3.FOLDER), "run MODE = \"first\" first")
end

if DRY_RUN then
	if MODE == "first" then
		local plan = V3Builder.plan(root, Layout, V3)
		local archivedParts = 0
		for _, a in ipairs(plan.archive) do
			table.insert(summary.archived, a.instance:GetFullName() .. ": " .. a.why)
			archivedParts += countParts(a.instance)
		end
		summary.kept = plan.kept
		-- review m2: the whole batch is built into a detached model (never parented, so the map is untouched), off
		-- the props the plan keeps, to measure it
		local archivedSet = {}
		for _, a in ipairs(plan.archive) do archivedSet[a.instance:GetFullName()] = true end
		local existing = {}
		for _, e in ipairs(V3Builder.existingProps(root, Layout)) do
			if not archivedSet[e.name] then table.insert(existing, e) end
		end
		local probeDeps = table.clone(deps)
		probeDeps.existing = existing
		local ok, laid = pcall(V3Builder.layAll, Instance.new("Model"), probeDeps)
		summary.laid = ok and { parts = laid.parts, placeholders = #laid.placeholders, filler = laid.filler, hills = laid.hills }
			or { error = tostring(laid) }
		local swap = V3Builder.swapTrees(root, deps, function() end, true)
		summary.swap = { swapped = #swap.swapped, kept = swap.kept, oldParts = swap.oldParts, newPartsEstimate = swap.newPartsEstimate }
		local estimate = summary.partsBefore - archivedParts + (ok and laid.parts or 0) - swap.oldParts + swap.newPartsEstimate
		summary.partsEstimate = estimate
		summary.overCap = estimate > V3.BIOME_PART_CAP
		summary.overBatchBudget = not ok
	else
		local up = V3Builder.upgradePlaceholders(root, deps, function() end, true)
		summary.upgrade = { upgraded = up.upgraded, waiting = up.waiting }
	end
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
		if MODE == "upgrade" then
			local up = V3Builder.upgradePlaceholders(root, deps, archive, false)
			summary.upgrade = { upgraded = up.upgraded, waiting = up.waiting, parts = up.parts }
			root:SetAttribute("CaramelV3KitUpgrades", (root:GetAttribute("CaramelV3KitUpgrades") or 0) + #up.upgraded)
			return
		end
		-- 1. backup
		local old = archiveRoot:FindFirstChild("CaramelV3Backup")
		if old then
			local copy = old:FindFirstChildWhichIsA("Model")
			summary.backup = "kept the existing CaramelV3Backup"
			summary.warning = ("an older CaramelV3Backup was kept (LayoutVersion %s, CakeMoveV1 %s): check it before any restore")
				:format(tostring(copy and copy:GetAttribute("LayoutVersion")), tostring(copy and copy:GetAttribute("CakeMoveV1")))
		else
			local holder = Instance.new("Folder")
			holder.Name = "CaramelV3Backup"
			local copy = root:Clone()
			copy.Parent = holder
			holder.Parent = archiveRoot
			summary.backup = holder:GetFullName()
		end
		-- 2. the plan
		local plan = V3Builder.plan(root, Layout, V3)
		for _, a in ipairs(plan.archive) do archive(a.instance, a.why) end
		summary.kept = plan.kept
		-- 3. the pieces (off every prop still standing)
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
return { scheduled = true, dryRun = false, mode = MODE, summaryAttribute = SUMMARY_ATTRIBUTE }

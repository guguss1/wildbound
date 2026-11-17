-- Gran Torta at the east end, 1.6 times bigger (GT, owner request 2026-11-16: "the cake with the princess at the end,
-- and much bigger"; docs/design/wildbound-caramelo-cake-move-plan.md), and the eight GT2 nests ("more eggs and more
-- creatures"), on the already-built live map. Studio Edit mode only: run it once from the command bar or execute_luau,
-- first with DRY_RUN = true to read the plan, then with DRY_RUN = false. Not deployed: a one-shot tool.
--
-- Needs, in ServerStorage, the GT WildboundCandyBuilder (layPaths, layBoss, layMarkers, placeTorta, syncNestPositions,
-- syncCentre, cakeMovePlan), WildboundCandyLayout VERSION 3, WildboundCandyKit and WildboundAssets.CandyKit, and in
-- ServerScriptService the GT WildboundPraderaSites (the moved posts; it needs ReplicatedStorage.WildboundBeastConfig).
-- It refuses to run on older modules, on a root already marked CakeMoveV1 (it returns the summary "already"), or in Play.
--
-- The real run (one undo step, ChangeHistoryService recording "CaramelCakeMove"): it runs in a deferred thread
-- (task.delay), because a call made from inside another recording (execute_luau is one) cannot open its own. The caller
-- reads the result afterwards from ServerStorage's attribute WildboundCakeMoveSummary (JSON; "pending" until done) or
-- from _G.WildboundCakeMoveSummary. In that thread, in this order:
--   1. backup: a clone of Workspace.Candy_Bioma_v1 into ServerStorage.WildboundMapArchive.CakeMoveBackup (skipped when
--      one is already there);
--   2. the old GranTorta, Ground.Plaza, Boss, Paths and Markers are archived (reparented, never destroyed) into
--      ServerStorage.WildboundMapArchive.CakeMoveArchived, and laid again from the v3 layout (placeTorta: the bigger cake;
--      layBoss: plaza and boss ground; layPaths: the new legs and the avenue; layMarkers);
--   3. syncTower: the old Tower and summit nest (generated parts) give way to the bigger stair, turntables, glaze and the
--      summit nest (the GranTorta now carries the layout key);
--   4. the Portal model slides to the layout's portal (its height and turn kept);
--   5. syncNestPositions moves the five moved nests; syncNests places the GT2 nests the build lacks;
--   6. cakeMovePlan: props on the new ground (boss territory and plaza, the portal, the moved pond, moved nests and posts,
--      the new legs and the avenue) are archived; trees that only fail the tree rule there are refitted (fitTree:
--      smaller, or nudged a few studs);
--   7. syncCentre: the centre backfill round the junction;
--   8. the root's LayoutVersion = 3 and CakeMoveV1 = true.
-- Anything named SistemaSonriente, or under it, is never touched. The JSON summary lists every move, archive and add,
-- with the part counts before and after.
local DRY_RUN = true -- true: only report; false: move the cake (one undo step)

local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Edit mode only: stop Play first")
local ServerStorage, Workspace = game:GetService("ServerStorage"), game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local SUMMARY_ATTRIBUTE = "WildboundCakeMoveSummary"
local MARK = "CakeMoveV1"

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
	_G.WildboundCakeMoveSummary = summary
	pcall(function() ServerStorage:SetAttribute(SUMMARY_ATTRIBUTE, json) end)
	print("CaramelCakeMove " .. json)
	return json
end

local Builder = module(ServerStorage, "WildboundCandyBuilder")
assert(Builder and type(Builder.placeTorta) == "function" and type(Builder.cakeMovePlan) == "function"
	and type(Builder.syncCentre) == "function" and type(Builder.syncNestPositions) == "function",
	"ServerStorage.WildboundCandyBuilder has no GT cake-move helpers yet: deploy the builder first")
local Layout = module(ServerStorage, "WildboundCandyLayout")
assert(Layout and Layout.VERSION == 3, "deploy the GT WildboundCandyLayout (VERSION 3) first")
local Kit = module(ServerStorage, "WildboundCandyKit")
assert(Kit, "ServerStorage.WildboundCandyKit is missing")
local assets = ServerStorage:FindFirstChild("WildboundAssets")
local library = assets and assets:FindFirstChild(Kit.LIBRARY_NAME)
assert(library, "ServerStorage.WildboundAssets." .. Kit.LIBRARY_NAME .. " is missing")
local root = Workspace:FindFirstChild(Layout.ROOT_NAME)
assert(root, "Workspace." .. Layout.ROOT_NAME .. " is missing")
assert(not forbidden(root), "refusing to touch SistemaSonriente")
-- the keep-out comes from the deployed PraderaSites: refuse the old one (its boss posts would still be at the old cake)
local keepOut = Builder.treeKeepOut(Layout)
do
	local moved = false
	for _, k in ipairs(keepOut) do
		if k.why == "post bossTerritory" and math.abs(k.x - Layout.BOSS.x) < 1e-3 and math.abs(k.z - Layout.BOSS.z) < 1e-3 then
			moved = true
		end
	end
	assert(moved, "deploy the GT ServerScriptService.WildboundPraderaSites (posts moved with the cake) and "
		.. "ReplicatedStorage.WildboundBeastConfig first")
	local sites = module(ServerScriptService, "WildboundPraderaSites")
	assert(sites and sites.FIXED and sites.FIXED.candyPostR11, "deploy the GT2 WildboundPraderaSites (24 posts) first")
end

if root:GetAttribute(MARK) ~= nil then
	local done = { dryRun = DRY_RUN, already = true, layoutVersion = root:GetAttribute("LayoutVersion") }
	publish(done)
	return done
end

local summary = { dryRun = DRY_RUN, already = false, partsBefore = countParts(root), moved = {}, archived = {},
	refitted = {}, added = {}, nestsMoved = {}, nestsPlaced = 0 }

-- The plan, read only: which props go and which trees are refitted, measured on the map as it stands (the nests and
-- posts are judged at their v3 spots, so this is what step 6 will do, give or take the props the new nests displace).
local function describe(plan)
	local archive, refit = {}, {}
	for _, a in ipairs(plan.archive) do table.insert(archive, a.instance:GetFullName() .. ": " .. a.why) end
	for _, r in ipairs(plan.refit) do
		table.insert(refit, ("%s: x%.2f moved (%.2f, %.2f) (%s)"):format(r.instance:GetFullName(), r.factor, r.dx, r.dz, tostring(r.why)))
	end
	return archive, refit
end

if DRY_RUN then
	local plan = Builder.cakeMovePlan(root, Layout, keepOut)
	summary.archived, summary.refitted = describe(plan)
	summary.kept = plan.kept
	local nests = root:FindFirstChild("Nests")
	for _, spec in ipairs(Layout.NESTS) do
		local nest = nests and nests:FindFirstChild("Nest_" .. spec.id)
		if not nest then
			table.insert(summary.added, "Nests.Nest_" .. spec.id .. " (syncNests)")
		else
			local p = nest:GetPivot()
			if math.abs(p.X - (Layout.CENTRE.x + spec.x)) > 0.05 or math.abs(p.Z - (Layout.CENTRE.z + spec.z)) > 0.05 then
				table.insert(summary.nestsMoved, spec.id)
			end
		end
	end
	for _, name in ipairs({ "GranTorta", "Boss", "Paths", "Markers" }) do
		if root:FindFirstChild(name) then table.insert(summary.moved, name .. " (archived, laid again)") end
	end
	table.insert(summary.moved, "Portal -> (" .. Layout.PORTAL.x .. ", " .. Layout.PORTAL.z .. ")")
	summary.centre = "planned at run time (Builder.syncCentre, Layout.SEED + 2)"
	publish(summary)
	return summary
end

-- The real run, in its own thread and its own recording.
pcall(function() ServerStorage:SetAttribute(SUMMARY_ATTRIBUTE, "pending") end)
_G.WildboundCakeMoveSummary = nil
task.delay(0.5, function()
	local recording
	local opened = pcall(function() recording = ChangeHistoryService:TryBeginRecording("CaramelCakeMove") end)
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
		if archiveRoot:FindFirstChild("CakeMoveBackup") then
			summary.backup = "kept the existing CakeMoveBackup"
		else
			local holder = Instance.new("Folder")
			holder.Name = "CakeMoveBackup"
			local copy = root:Clone()
			copy.Parent = holder
			holder.Parent = archiveRoot
			summary.backup = holder:GetFullName()
		end
		local archived = archiveRoot:FindFirstChild("CakeMoveArchived")
		if not archived then
			archived = Instance.new("Folder")
			archived.Name = "CakeMoveArchived"
			archived.Parent = archiveRoot
		end
		local function archive(instance, why)
			if forbidden(instance) then return end
			table.insert(summary.archived, instance:GetFullName() .. ": " .. why)
			instance.Parent = archived
		end
		-- 2. the cake, the plaza, the boss ground, the paths and the markers
		for _, name in ipairs({ "GranTorta", "Boss", "Paths", "Markers" }) do
			local old = root:FindFirstChild(name)
			if old then archive(old, "laid again for layout v3") end
		end
		local ground = root:FindFirstChild("Ground")
		local plaza = ground and ground:FindFirstChild("Plaza")
		if plaza then archive(plaza, "laid again for layout v3") end
		local added = 0
		added += select(2, Builder.placeTorta(root, Layout, Kit, library))
		added += select(2, Builder.layBoss(root, Layout))
		added += select(2, Builder.layPaths(root, Layout))
		added += select(2, Builder.layMarkers(root, Layout))
		table.insert(summary.added, ("GranTorta (radius %g), Ground.Plaza, Boss, Paths, Markers: %d parts"):format(Layout.TORTA.radius, added))
		-- 3. the tower
		local tower = Builder.syncTower(root, Layout, Kit, library)
		table.insert(summary.added, ("Tower and summit nest: %d parts (%d steps)"):format(tower, #Layout.stairSteps()))
		-- 4. the portal
		local portal = root:FindFirstChild("Portal")
		if portal and portal:IsA("Model") then
			local pivot = portal:GetPivot()
			local x, z = Layout.CENTRE.x + Layout.PORTAL.x, Layout.CENTRE.z + Layout.PORTAL.z
			portal:PivotTo(CFrame.new(x - pivot.X, 0, z - pivot.Z) * pivot)
			table.insert(summary.moved, ("Portal (%.1f, %.1f) -> (%.1f, %.1f)"):format(pivot.X, pivot.Z, x, z))
		else
			summary.portal = "no Portal model"
		end
		-- 5. the nests
		summary.nestsMoved = Builder.syncNestPositions(root, Layout)
		local before = root:FindFirstChild("Nests") and #root.Nests:GetChildren() or 0
		Builder.syncNests(root, Layout, Kit, library)
		summary.nestsPlaced = (root:FindFirstChild("Nests") and #root.Nests:GetChildren() or 0) - before
		-- 6. props on the new ground
		local plan = Builder.cakeMovePlan(root, Layout, keepOut)
		for _, a in ipairs(plan.archive) do archive(a.instance, a.why) end
		for _, r in ipairs(plan.refit) do
			local model = r.instance
			if not forbidden(model) then
				table.insert(summary.refitted, ("%s: x%.2f moved (%.2f, %.2f) (%s)"):format(model:GetFullName(), r.factor, r.dx, r.dz, tostring(r.why)))
				if r.dx ~= 0 or r.dz ~= 0 then model:PivotTo(CFrame.new(r.dx, 0, r.dz) * model:GetPivot()) end
				Builder.growTree(model, r.asset, r.factor)
			end
		end
		summary.kept = plan.kept
		-- 7. the centre backfill
		local centre = Builder.syncCentre(root, Layout, Kit, library)
		summary.centre = { added = centre.added, parts = centre.parts, skipped = centre.skipped, already = centre.already,
			planned = centre.planned }
		-- 8. marks
		root:SetAttribute("LayoutVersion", Layout.VERSION)
		root:SetAttribute(MARK, true)
	end)
	ChangeHistoryService:FinishRecording(recording,
		ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
	if not ok then summary.error = "failed and undone: " .. tostring(failure) end
	summary.partsAfter = countParts(root)
	publish(summary)
end)
print("CaramelCakeMove: scheduled; read ServerStorage:GetAttribute(\"" .. SUMMARY_ATTRIBUTE .. "\") in a few seconds")
return { scheduled = true, dryRun = false, summaryAttribute = SUMMARY_ATTRIBUTE }

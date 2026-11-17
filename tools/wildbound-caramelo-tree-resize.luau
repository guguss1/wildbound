-- Caramelo trees leafier and bigger (owner, 2026-11-16), on the already-built live map. Studio Edit mode only: run it
-- once from the command bar (or execute_luau), first with DRY_RUN = true to read the report, then with false. Not
-- deployed: a one-shot tool.
--
-- Needs, in ServerStorage, the CH WildboundCandyBuilder (TREE_SCALE, growTree, measureTree, fitTree, treeKeepOut) and
-- WildboundCandyLayout; for the big4 annex also WildboundBig4Annex with growCandyAnnex (branch agus/big4-map). Without
-- that the annex is reported and left as it is.
--
-- Per tree model: a Model under Workspace.Candy_Bioma_v1 (CottonTrees, Lollipops, Entrance, Sweets) whose KitAsset
-- attribute is a key of Builder.TREE_SCALE.
--   * one that already carries Builder.TREE_ATTRIBUTE (CaramelTreeScaleV2) is left alone, so a second run changes
--     nothing;
--   * otherwise a detached clone is grown by its factor and measured; Builder.fitTree picks the largest factor (down to
--     TREE_CLEAR.minFactor, 1.5) that fits where it stands, else the smallest move (2 to 8 studs) that fits; the tree is
--     moved (when it must), grown about its pivot (the trunk's foot stays on the floor) with Builder.growTree and marked;
--   * one that fits nowhere is left as it is and listed in blockedList.
-- Then (ADD_TREES) Builder.syncTrees adds the extra trees (owner: "more trees", about +50 %) into those folders, under
-- the same rule, marked CaramelTreesAddedV2; a root already marked gets none, so a second run adds nothing.
-- In big4 (Workspace.WildboundCandyAnnex_Big4, or the same root in ServerStorage.WildboundMapArchive.Big4 in classic)
-- the annex's candy trees go through Annex.growCandyAnnex (never moved).
-- Changes nothing but those tree models, the new trees in the three tree folders and the root's CaramelTreesAddedV2
-- attribute (its PartCount attribute is not updated); anything named SistemaSonriente, or under it, is never touched (its parts
-- are only read for the annex's keep-out). Returns the summary table, and prints it.
local DRY_RUN = true -- true: only report; false: grow (one undo step)
local ADD_TREES = true -- also add the builder's extra trees (Builder.syncTrees), once
local INCLUDE_ANNEX = true -- also the big4 annex's candy trees

local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Edit mode only: stop Play first")
local ServerStorage, Workspace = game:GetService("ServerStorage"), game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local function module(parent, name)
	local found = parent and parent:FindFirstChild(name)
	return found and found:IsA("ModuleScript") and require(found) or nil
end
local Builder = module(ServerStorage, "WildboundCandyBuilder")
assert(Builder and type(Builder.TREE_SCALE) == "table" and type(Builder.growTree) == "function"
	and type(Builder.fitTree) == "function" and type(Builder.measureTree) == "function",
	"ServerStorage.WildboundCandyBuilder has no CH tree rule yet: apply the builder change first")
local Layout = module(ServerStorage, "WildboundCandyLayout")
assert(Layout, "ServerStorage.WildboundCandyLayout is missing")
local root = Workspace:FindFirstChild(Layout.ROOT_NAME)
assert(root, "Workspace." .. Layout.ROOT_NAME .. " is missing")
assert(root.Name ~= "SistemaSonriente", "refusing to touch SistemaSonriente")
-- The keep-out comes from the deployed Layout (nests) and PraderaSites (posts): refuse to run on the old ones, or a
-- tree could be moved onto a new nest or post and be marked done.
assert(#Layout.NESTS >= 20, "deploy the CH3 WildboundCandyLayout (20 nests) first")
do
	local postsSeen = false
	for _, k in ipairs(Builder.treeKeepOut(Layout)) do
		if k.why == "post candyPostC7" then postsSeen = true end
	end
	assert(postsSeen, "deploy the CH1 WildboundPraderaSites (extra posts) and WildboundBeastConfig first")
end

local ATTRIBUTE = Builder.TREE_ATTRIBUTE
local summary = { dryRun = DRY_RUN, found = 0, grown = 0, already = 0, reduced = 0, nudged = 0, blocked = 0,
	byFolder = {}, moved = {}, blockedList = {}, unknown = {}, annex = "not looked at" }

local function forbidden(instance)
	return instance.Name == "SistemaSonriente" or instance:FindFirstAncestor("SistemaSonriente") ~= nil
end
local function noteFactor(f)
	summary.minFactor = math.min(summary.minFactor or f, f)
	summary.maxFactor = math.max(summary.maxFactor or f, f)
end

-- The tree models, in a stable order; models that look like trees but are not in TREE_SCALE are only reported.
local candidates = {}
for _, d in ipairs(root:GetDescendants()) do
	if d:IsA("Model") and not forbidden(d) then
		local asset = d:GetAttribute("KitAsset")
		if type(asset) == "string" and Builder.TREE_SCALE[asset] then
			table.insert(candidates, d)
		elseif string.find(d.Name, "Tree", 1, true) or string.find(d.Name, "Lollipop", 1, true)
			or (type(asset) == "string" and (string.find(asset, "Tree", 1, true) or string.find(asset, "Lollipop", 1, true))) then
			table.insert(summary.unknown, d:GetFullName() .. " (KitAsset " .. tostring(asset) .. ")")
		end
	end
end
table.sort(candidates, function(a, b) return a:GetFullName() < b:GetFullName() end)

local recording
if not DRY_RUN then
	local ok, id = pcall(function() return ChangeHistoryService:TryBeginRecording("CaramelTreeResize") end)
	if ok then recording = id end
	-- without a recording a failure halfway could not be undone: change nothing
	assert(recording, "could not open a ChangeHistoryService recording (another one open, or no plugin rights): nothing "
		.. "was changed; run it again from the command bar or execute_luau once no recording is open")
end

local keepOut = Builder.treeKeepOut(Layout)
-- Every kit prop standing in the biome but the nests (they have their own rule): a tree moved by fitTree must not put
-- its trunk into another tree's trunk or into a prop. Trees count their trunk collider (crowns may mingle), other
-- props their whole reach. Entries follow the trees as they move and grow.
local taken, entryOf = {}, {}
for _, d in ipairs(root:GetDescendants()) do
	local asset = d:IsA("Model") and d:GetAttribute("KitAsset")
	if type(asset) == "string" and not d:FindFirstAncestor("Nests") and not forbidden(d) then
		local m, p = Builder.measureTree(d), d:GetPivot().Position
		local entry = { x = p.X - Layout.CENTRE.x, z = p.Z - Layout.CENTRE.z,
			reach = Builder.TREE_SCALE[asset] and m.trunk or math.max(m.trunk, m.canopy) }
		table.insert(taken, entry)
		entryOf[d] = entry
	end
end
local ok, failure = pcall(function()
	for _, model in ipairs(candidates) do
		summary.found += 1
		local folder = model.Parent and model.Parent.Name or "?"
		summary.byFolder[folder] = (summary.byFolder[folder] or 0) + 1
		local asset = model:GetAttribute("KitAsset")
		if model:GetAttribute(ATTRIBUTE) ~= nil then
			summary.already += 1
		else
			local factor = Builder.TREE_SCALE[asset]
			local probe = model:Clone()
			Builder.growTree(probe, asset, factor)
			local m = Builder.measureTree(probe)
			probe:Destroy()
			local pivot = model:GetPivot()
			local x0, z0 = pivot.X - Layout.CENTRE.x, pivot.Z - Layout.CENTRE.z
			local own = entryOf[model]
			local others = {}
			for _, entry in ipairs(taken) do
				if entry ~= own then table.insert(others, entry) end
			end
			-- where it stands it stays allowed (it was placed there); a moved spot must be open ground for its trunk
			local function also(px, pz)
				if px == x0 and pz == z0 then return true end
				return Builder.openGround(Layout, px, pz, 0, m.trunk + 1, others)
			end
			local f, dx, dz = Builder.fitTree(Layout, x0, z0, m, factor, keepOut, also)
			if not f then
				summary.blocked += 1
				table.insert(summary.blockedList, model:GetFullName() .. ": " .. tostring(dx))
			else
				summary.grown += 1
				noteFactor(f)
				if f < factor - 1e-6 then summary.reduced += 1 end
				local moves = dx ~= 0 or dz ~= 0
				if moves then
					summary.nudged += 1
					table.insert(summary.moved, ("%s moved (%.2f, %.2f) at %.2f"):format(model:GetFullName(), dx, dz, f))
				end
				if own then
					own.x, own.z, own.reach = x0 + dx, z0 + dz, m.trunk * f / factor
				end
				if not DRY_RUN then
					if moves then model:PivotTo(CFrame.new(dx, 0, dz) * pivot) end
					Builder.growTree(model, asset, f)
				end
			end
		end
	end
	-- More trees: the builder's EXTRA_TREES, added only to CottonTrees, Lollipops and Sweets (Builder.syncTrees: kit
	-- prefabs cloned and dressed like the build's, grown, marked; a root already marked gets none). In a dry run the
	-- trees above are not grown yet, so the plan spaces them by their present size: the real run may differ a little.
	if ADD_TREES then
		if type(Builder.syncTrees) ~= "function" then
			summary.extra = "ServerStorage.WildboundCandyBuilder has no syncTrees yet: no tree added"
		else
			local Kit = module(ServerStorage, "WildboundCandyKit")
			assert(Kit, "ServerStorage.WildboundCandyKit is missing")
			local assets = ServerStorage:FindFirstChild("WildboundAssets")
			local library = assets and assets:FindFirstChild(Kit.LIBRARY_NAME)
			assert(library, "ServerStorage.WildboundAssets." .. Kit.LIBRARY_NAME .. " is missing")
			summary.extra = Builder.syncTrees(root, Layout, Kit, library, DRY_RUN)
		end
	end
	if INCLUDE_ANNEX then
		local annex = Workspace:FindFirstChild("WildboundCandyAnnex_Big4")
		if not annex then
			local archive = ServerStorage:FindFirstChild("WildboundMapArchive")
			local big4 = archive and archive:FindFirstChild("Big4")
			annex = big4 and big4:FindFirstChild("WildboundCandyAnnex_Big4")
		end
		local Annex = module(ServerStorage, "WildboundBig4Annex")
		if not annex then
			summary.annex = "no WildboundCandyAnnex_Big4 in this place"
		elseif forbidden(annex) then
			summary.annex = "refused: the annex sits under SistemaSonriente"
		elseif not (Annex and type(Annex.growCandyAnnex) == "function" and type(Annex.sonrienteAvoid) == "function") then
			summary.annex = "ServerStorage.WildboundBig4Annex has no growCandyAnnex yet (agus/big4-map change): annex trees left as they are"
		else
			summary.annex = Annex.growCandyAnnex(annex, Builder, Annex.sonrienteAvoid(Workspace), DRY_RUN)
			summary.annex.root = annex:GetFullName()
		end
	end
end)
if recording then
	ChangeHistoryService:FinishRecording(recording,
		ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
elseif not DRY_RUN and ok then
	pcall(function() ChangeHistoryService:SetWaypoint("CaramelTreeResize") end)
end
if not ok then error("CaramelTreeResize failed (undone when recorded): " .. tostring(failure), 0) end
print("CaramelTreeResize " .. HttpService:JSONEncode(summary))
return summary

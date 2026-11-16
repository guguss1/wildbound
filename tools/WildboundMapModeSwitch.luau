-- Big4 map experiment (odd/tasks/wildbound-big4-map.md): the one-call, never-destroy switch between today's map
-- ("classic") and the four-larger-biomes map ("big4"). Deployed as ServerStorage.WildboundMapModeSwitch. Edit only.
--
--   require(game.ServerStorage.WildboundMapModeSwitch).apply("classic") -- today's map, exactly as it was
--   require(game.ServerStorage.WildboundMapModeSwitch).apply("big4")    -- the experiment
--
-- It only reparents instances between Workspace and ServerStorage.WildboundMapArchive (folders Classic and Big4) and
-- sets the replicated Workspace attribute WildboundMapMode ("big4"; nil in classic, as the place was). Positions,
-- properties and children are never changed, nothing is destroyed. It refuses while Play runs or while ServerStorage
-- has WildboundPlayLock or WildboundImportLock set. All of one apply is a single ChangeHistoryService recording.
--
-- Never touched: Candy_Bioma_v1, WildboundP0, WildboundPradera (the sector marker), WildboundHub, SistemaSonriente,
-- the beast gallery, PatioEntrenamiento, and the road slabs both maps share.
local Switch = {}

Switch.ATTRIBUTE = "WildboundMapMode"
Switch.ARCHIVE = "WildboundMapArchive"
Switch.CLASSIC_FOLDER = "Classic"
Switch.BIG4_FOLDER = "Big4"
-- Every big4 root carries MapMode = "big4" and lives directly under Workspace while big4 is on.
Switch.ROOT_ATTRIBUTE = "MapMode"
-- The five roots WildboundBig4Annex builds. apply("big4") refuses unless every one is available, either archived in
-- Big4 or already under Workspace with MapMode = "big4"; otherwise it would archive the classic biomes and leave
-- only the forest and Caramelo.
Switch.BIG4_ROOTS = table.freeze({
	"WildboundFrozenMountains_Big4",
	"WildboundVolcanicLands_Big4",
	"WildboundForestOuter_Big4",
	"WildboundCandyAnnex_Big4",
	"WildboundBig4Roads",
})
Switch.LOCKS = { "WildboundPlayLock", "WildboundImportLock" }

-- Workspace paths that belong to the classic map only ("/" separated, under Workspace). In big4 they wait in
-- Classic; the original Frozen and Volcanic roots are archived untouched (the big4 ones are scaled clones).
Switch.CLASSIC_ONLY = table.freeze({
	"WildboundLivingForest",
	"WildboundCrypticRuins",
	"WildboundRockCaves",
	"WildboundDemonAbyss",
	"WildboundFrozenMountains",
	"WildboundVolcanicLands",
	"WildboundOpenWorldRoads/living-forest/Road_living-forest_3",
	"WildboundOpenWorldRoads/cryptic-ruins/Road_cryptic-ruins_2",
	"WildboundOpenWorldRoads/cryptic-ruins/Road_cryptic-ruins_3",
	"WildboundOpenWorldRoads/rock-caves/Road_rock-caves_1",
	"WildboundOpenWorldRoads/rock-caves/Road_rock-caves_2",
	"WildboundOpenWorldRoads/demon-abyss/Road_demon-abyss_1",
	"WildboundOpenWorldRoads/demon-abyss/Road_demon-abyss_2",
	"WildboundOpenWorldRoads/demon-abyss/Road_demon-abyss_3",
	"WildboundOpenWorldRoads/frozen-mountains/Road_frozen-mountains_1",
	"WildboundOpenWorldRoads/frozen-mountains/Road_frozen-mountains_2",
	"WildboundOpenWorldRoads/frozen-mountains/Road_frozen-mountains_3",
	"WildboundOpenWorldRoads/Gates/Gate_living-forest",
	"WildboundOpenWorldRoads/Gates/Gate_cryptic-ruins",
	"WildboundOpenWorldRoads/Gates/Gate_rock-caves",
	"WildboundOpenWorldRoads/Gates/Gate_demon-abyss",
	"WildboundOpenWorldRoads/Gates/Gate_frozen-mountains",
	"WildboundOpenWorldRoads/Gates/Gate_volcanic-lands",
})

local function split(path)
	return string.split(path, "/")
end

local function lastName(path)
	local parts = split(path)
	return parts[#parts]
end

local function find(root, path)
	local node = root
	for _, name in ipairs(split(path)) do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local function parentOf(root, path)
	local parts = split(path)
	table.remove(parts)
	if #parts == 0 then return root end
	return find(root, table.concat(parts, "/"))
end

local function folder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing then return existing end
	local made = Instance.new("Folder")
	made.Name = name
	made.Parent = parent
	return made
end

-- env (tests): { root = <Workspace stand-in>, storage = <ServerStorage stand-in>, running = false, history = false }.
-- Without env the real services are used.
local function resolve(env)
	env = env or {}
	local root = env.root or game:GetService("Workspace")
	local storage = env.storage or game:GetService("ServerStorage")
	local running = env.running
	if running == nil then running = game:GetService("RunService"):IsRunning() end
	local history = env.history
	if history == nil then history = game:GetService("ChangeHistoryService") end
	return root, storage, running, history
end

function Switch.archive(env)
	local _, storage = resolve(env)
	local archive = folder(storage, Switch.ARCHIVE)
	return archive, folder(archive, Switch.CLASSIC_FOLDER), folder(archive, Switch.BIG4_FOLDER)
end

-- status(env) -> { mode, classicInPlace, classicArchived, big4InPlace, big4Archived }
function Switch.status(env)
	local root, storage = resolve(env)
	local archive = storage:FindFirstChild(Switch.ARCHIVE)
	local classic = archive and archive:FindFirstChild(Switch.CLASSIC_FOLDER)
	local big4 = archive and archive:FindFirstChild(Switch.BIG4_FOLDER)
	local report = { mode = root:GetAttribute(Switch.ATTRIBUTE) or "classic", classicInPlace = 0, classicArchived = 0,
		big4InPlace = 0, big4Archived = big4 and #big4:GetChildren() or 0 }
	for _, path in ipairs(Switch.CLASSIC_ONLY) do
		if find(root, path) then report.classicInPlace += 1 end
		if classic and classic:FindFirstChild(lastName(path)) then report.classicArchived += 1 end
	end
	for _, child in ipairs(root:GetChildren()) do
		if child:GetAttribute(Switch.ROOT_ATTRIBUTE) == "big4" then report.big4InPlace += 1 end
	end
	return report
end

local function isBig4Root(item, name)
	return item ~= nil and item.Name == name and item:GetAttribute(Switch.ROOT_ATTRIBUTE) == "big4"
end

-- The big4 roots that are neither in the Big4 archive nor tagged under Workspace.
local function missingBig4Roots(root, storage)
	local archive = storage:FindFirstChild(Switch.ARCHIVE)
	local big4 = archive and archive:FindFirstChild(Switch.BIG4_FOLDER)
	local missing = {}
	for _, name in ipairs(Switch.BIG4_ROOTS) do
		local found = false
		for _, place in ipairs({ root, big4 }) do
			for _, child in ipairs(place and place:GetChildren() or {}) do
				if isBig4Root(child, name) then found = true break end
			end
			if found then break end
		end
		if not found then table.insert(missing, name) end
	end
	return missing
end

-- The classic-only paths classic cannot put back: in neither Workspace nor the Classic archive, or archived with no
-- home folder left under Workspace.
local function unrestorableClassic(root, storage)
	local archive = storage:FindFirstChild(Switch.ARCHIVE)
	local classic = archive and archive:FindFirstChild(Switch.CLASSIC_FOLDER)
	local missing = {}
	for _, path in ipairs(Switch.CLASSIC_ONLY) do
		if not find(root, path) then
			local archived = classic and classic:FindFirstChild(lastName(path))
			if not archived or not parentOf(root, path) then table.insert(missing, path) end
		end
	end
	return missing
end

-- apply(mode, env) -> report { mode, moved, missing = { path, ... } }. Errors (and changes nothing) on a bad mode,
-- during Play, under a lock, for big4 when any of the BIG4_ROOTS is unavailable, and for classic when any classic-only
-- item cannot be put back (the error lists them). big4 still reports classic items already gone as `missing`.
function Switch.apply(mode, env)
	if mode ~= "big4" and mode ~= "classic" then
		error("WildboundMapModeSwitch.apply: mode must be \"big4\" or \"classic\", got " .. tostring(mode), 2)
	end
	local root, storage, running, history = resolve(env)
	if running then error("WildboundMapModeSwitch.apply: Edit only (stop Play first)", 2) end
	for _, lock in ipairs(Switch.LOCKS) do
		local holder = storage:GetAttribute(lock)
		if holder ~= nil then
			error(("WildboundMapModeSwitch.apply: ServerStorage %s is set (%s); try again when it clears"):format(lock,
				tostring(holder)), 2)
		end
	end
	if mode == "big4" then
		local absent = missingBig4Roots(root, storage)
		if #absent > 0 then
			error(("WildboundMapModeSwitch.apply: refusing big4, %d of %d big4 roots are in neither the Big4 archive nor "
				.. "Workspace (%s); nothing was changed"):format(#absent, #Switch.BIG4_ROOTS, table.concat(absent, ", ")), 2)
		end
	else
		local absent = unrestorableClassic(root, storage)
		if #absent > 0 then
			error(("WildboundMapModeSwitch.apply: refusing classic, %d classic item(s) cannot be put back (in neither "
				.. "Workspace nor the Classic archive, or no home folder): %s; nothing was changed"):format(#absent,
				table.concat(absent, ", ")), 2)
		end
	end
	local recording = nil
	if history then
		local began, id = pcall(history.TryBeginRecording, history, "WildboundMapMode " .. mode)
		recording = began and id or nil
	end
	local report = { mode = mode, moved = 0, missing = {} }
	local ok, problem = pcall(function()
		local _, classic, big4 = Switch.archive({ root = root, storage = storage, running = false, history = false })
		if mode == "big4" then
			for _, path in ipairs(Switch.CLASSIC_ONLY) do
				local item = find(root, path)
				if item then
					item.Parent = classic
					report.moved += 1
				elseif not classic:FindFirstChild(lastName(path)) then
					table.insert(report.missing, path)
				end
			end
			for _, item in ipairs(big4:GetChildren()) do
				item.Parent = root
				report.moved += 1
			end
			root:SetAttribute(Switch.ATTRIBUTE, "big4")
		else
			for _, item in ipairs(root:GetChildren()) do
				if item:GetAttribute(Switch.ROOT_ATTRIBUTE) == "big4" then
					item.Parent = big4
					report.moved += 1
				end
			end
			for _, path in ipairs(Switch.CLASSIC_ONLY) do
				local item = classic:FindFirstChild(lastName(path))
				local home = parentOf(root, path)
				if item and home then
					item.Parent = home
					report.moved += 1
				elseif not find(root, path) then
					table.insert(report.missing, path)
				end
			end
			root:SetAttribute(Switch.ATTRIBUTE, nil)
		end
	end)
	if recording then
		history:FinishRecording(recording, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
	end
	if not ok then error("WildboundMapModeSwitch.apply failed: " .. tostring(problem), 2) end
	return report
end

return Switch

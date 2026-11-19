-- Invoke with require(freshTestClone)({ migrate = WildboundCaramelV9Migrate.Source },
-- require(freshCandyV3BuilderClone), require(freshCandyBuilderClone), require(freshCandyEastClone),
-- require(freshCandyLayoutClone), require(freshCandyV3LayoutClone)).
-- Caramelo v9 (docs/design/wildbound-caramelo-v9-plan.md CL-D17 and its "Migration" section; owner request 2026-11-18:
-- "agranda mas el bioma caramelo a lo largo, el rio ... 5 veces su ancho"): source pins of the one-shot v9 migration tool
-- (tools/wildbound-caramelo-v9-migrate.luau, kept in Studio as the disabled Script ServerStorage.WildboundCaramelV9Migrate):
-- a dry run first, Edit mode only, CaramelV8 needed and CaramelV9 reported as "already", the backup, archive and
-- reverted folders with the two recordings, one Destroy (the probe's scratch model), the SistemaSonriente and part
-- target refusals, fresh module clones and the module names it calls. The five modules are optional: with them, MG9-5 and
-- MG9-6 also check that every name the tool calls exists and that its literal numbers match the layout. Changes nothing.
return function(sources, V3Builder, Builder, East, Layout, V3)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function near(actual, expected, label, tolerance)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-3),
			(label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function has(source, needle, label)
		assert(type(source) == "string" and string.find(source, needle, 1, true), (label or "missing") .. ": " .. needle)
	end
	local function hasNot(source, needle, label)
		assert(type(source) == "string" and not string.find(source, needle, 1, true), (label or "present") .. ": " .. needle)
	end
	-- where needle first appears (plain), asserted present
	local function at(source, needle, label)
		local i = type(source) == "string" and string.find(source, needle, 1, true)
		assert(i, (label or "missing") .. ": " .. needle)
		return i
	end
	local function count(source, pattern)
		local n = 0
		for _ in string.gmatch(source, pattern) do n += 1 end
		return n
	end
	sources = type(sources) == "table" and sources or {}
	local tool = sources.migrate

	case("MG9-1 (CL-D17): the tool ships as a dry run, not in RESTORE mode", function()
		assert(type(tool) == "string" and #tool > 0, "pass { migrate = WildboundCaramelV9Migrate.Source }")
		-- CL-D17: the two switches stand alone on their lines, exactly
		assert(string.find(tool, "\nlocal DRY_RUN = true\r?\n"), "the line 'local DRY_RUN = true'")
		assert(string.find(tool, "\nlocal RESTORE = false\r?\n"), "the line 'local RESTORE = false'")
		hasNot(tool, "local DRY_RUN = false", "shipped as a real run")
		hasNot(tool, "local RESTORE = true", "shipped in RESTORE mode")
		equal(count(tool, "local DRY_RUN ="), 1, "one DRY_RUN switch")
		equal(count(tool, "local RESTORE ="), 1, "one RESTORE switch")
		-- the dry run reports and returns before the real run is scheduled
		local dry = string.find(tool, "\nif DRY_RUN then\r?\n\tsurvey%(%)")
		assert(dry, "the dry run surveys, publishes and returns")
		local real = at(tool, 'TryBeginRecording("CaramelV9")', "the real run's recording")
		assert(dry < real, "the dry run returns before the real run")
	end)

	case("MG9-2 (CL-D17): Edit mode only, asserted before anything else runs", function()
		local edit = at(tool, 'assert(not RunService:IsRunning(), "Edit mode only: stop Play first")', "Edit mode only")
		assert(edit < at(tool, "if RESTORE then", "the RESTORE branch"), "before RESTORE")
		assert(edit < at(tool, 'module(ServerStorage, "WildboundCandyLayout")', "the layout clone"), "before the modules")
	end)

	case("MG9-3 (CL-D17): needs the CaramelV8 mark; a map marked CaramelV9 reports 'already' and stops", function()
		has(tool, 'local MARK, NEEDS = "CaramelV9", "CaramelV8"', "needs v8, marks v9")
		local needs = at(tool, "assert(root:GetAttribute(NEEDS) ~= nil", "refuses a map without CaramelV8")
		local already = at(tool, "if root:GetAttribute(MARK) ~= nil then", "a map already marked CaramelV9")
		has(tool, "summary.already = true", "reports already")
		local survey = at(tool, "local function makePlan()", "the survey")
		assert(needs < already and already < survey, "checked in that order, before any survey")
		-- the mark is the last step of the real run, after the second cloud-wall build
		local mark = at(tool, "root:SetAttribute(MARK, 1)", "the mark")
		local second = at(tool, "local _, again = East.build(Workspace, Layout, V3)", "the second build")
		assert(second < mark, "marked after the second build")
		has(tool, "again.created == 0 and again.changed == 0", "the second build changes nothing")
		-- RESTORE needs the mark and the backup
		has(tool, "live:GetAttribute(MARK) ~= nil", "RESTORE needs CaramelV9")
		has(tool, "backup:FindFirstChild(ROOT_NAME)", "RESTORE needs the backup's root")
	end)

	case("MG9-4 (CL-D2, CL-D17): backup, archive and reverted folders; the CaramelV9 and CaramelV9Restore recordings", function()
		has(tool, 'local BACKUP, ARCHIVED, REVERTED = "CaramelV9Backup", "CaramelV9Archived", "CaramelV9Reverted"', "the three folders")
		has(tool, 'local ARCHIVE_ROOT = "WildboundMapArchive"', "under ServerStorage.WildboundMapArchive")
		has(tool, 'ChangeHistoryService:TryBeginRecording("CaramelV9")', "the migration's recording")
		has(tool, 'ChangeHistoryService:TryBeginRecording("CaramelV9Restore")', "the restore's recording")
		equal(count(tool, "TryBeginRecording%("), 2, "one recording per mode")
		equal(count(tool, "task%.delay%(0%.5, function%(%)"), 2, "both outside the caller's recording")
		equal(count(tool, "Enum%.FinishRecordingOperation%.Cancel"), 2, "both undone on a failure")
		has(tool, 'local SUMMARY_ATTRIBUTE = "WildboundCaramelV9Summary"', "the JSON summary attribute")
		has(tool, "ServerStorage:SetAttribute(SUMMARY_ATTRIBUTE, json)", "published")
		has(tool, "_G.WildboundCaramelV9Summary = summary", "and in _G")
		-- step 0: the four roots backed up, an existing backup kept
		has(tool, "{ root, eastRoot, annex, queen }", "backed up")
		has(tool, "kept the existing", "an older backup kept")
		local backup = at(tool, "holder.Name = BACKUP", "the backup folder")
		local archive = at(tool, "for _, a in ipairs(plan.archive) do archive(a.instance) end", "the archive step")
		assert(backup < archive, "the backup comes before the archive")
		-- archived and reverted by reparenting, never destroyed
		has(tool, "instance.Parent = archived", "archived")
		has(tool, "current.Parent = reverted", "RESTORE moves the live roots aside")
		has(tool, "local fresh = copy:Clone()", "and clones the backups back")
		-- the summary's fields (plan step 8)
		for _, field in ipairs({ "summary.archived", "summary.relaid", "summary.created", "summary.partsBefore",
			"summary.partsAfter", "summary.estimate", "target = V3.V9_PART_TARGET", "summary.overCap" }) do
			has(tool, field, "the summary field")
		end
	end)

	case("MG9-5 (CL-D16, CL-D17): one Destroy (the probe); SistemaSonriente, strips and part target refusals", function()
		-- the only Destroy is the probe's detached scratch model
		equal(count(tool, ":Destroy%("), 1, "one Destroy")
		has(tool, "scratch:Destroy()", "the scratch model's")
		hasNot(tool, ":ClearAllChildren(", "nothing cleared")
		hasNot(tool, ":Remove(", "nothing removed")
		-- CL-D17: SistemaSonriente bounds, read only, refused in both runs
		has(tool, "local SONRIENTE_BOX = { minX = 932, maxX = 1616, minZ = -307, maxZ = 301 }", "the SistemaSonriente box")
		has(tool, '"SistemaSonriente"', "SistemaSonriente is never touched")
		has(tool, "local hits = sonrienteHits()", "its parts measured")
		has(tool, 'table.insert(summary.refused, ("SistemaSonriente meets', "refused when it meets the box")
		-- both annex strips found, or refused
		has(tool, "if not strips.ok then", "the strips refusal")
		-- the estimate above V3.V9_PART_TARGET (3100), or an unknown estimate, is refused
		has(tool, "if summary.estimate.bioma > V3.V9_PART_TARGET then", "the target refusal")
		has(tool, "the probe failed, so the estimate is unknown", "a failed probe refuses")
		has(tool, "summary.partsBefore.bioma - archivedParts + relaid", "estimate = partsBefore - archived + relaid")
		has(tool, "local TOWER_PARTS = 126", "the Tower's 126 when none can be measured")
		-- refused before the recording opens: nothing is changed
		local refused = at(tool, "if #summary.refused > 0 then", "the real run honours the refusals")
		assert(refused < at(tool, 'TryBeginRecording("CaramelV9")', "the recording"), "refused before the recording")
		if East and Layout and V3 then
			-- the box is the growth area's west edge, the arm's end and the strips' side walls
			local arm = East.plan(Layout, V3).arm
			near(Layout.CENTRE.x + Layout.V9.OLD_EAST, 932, "box minX: the old east edge")
			near(arm.maxX + East.EDGE_WALL, 1616, "box maxX: the end wall's far face")
			near(arm.minZ - East.EDGE_WALL, -307, "box minZ: the south side wall")
			near(arm.maxZ + East.EDGE_WALL, 301, "box maxZ: the north side wall")
			-- CL-D16: the target the tool refuses above
			equal(V3.V9_PART_TARGET, 3100, "V3.V9_PART_TARGET")
			equal(V3.BIOME_PART_CAP, 3400, "V3.BIOME_PART_CAP")
		end
	end)

	case("MG9-6 (CL-D17): fresh module clones, the v9 asserts, planV5, the layAll relay, stripPlan and East.build", function()
		has(tool, "local function module(parent, name)", "fresh copies")
		has(tool, "require(found:Clone())", "never the session's cached require")
		-- the VERSION and EAST asserts
		has(tool, "Layout.VERSION == 3 and Layout.EAST == 860 and Layout.HALF == 260", "the v9 layout")
		has(tool, "math.abs(Layout.TORTA.x - 748.2) < 1e-6", "the Torta at 748.2")
		has(tool, "V3.VERSION == 5", "V3 VERSION 5")
		has(tool, "V3.V9.EAST == 860", "V3's EAST copy")
		has(tool, "Sites.FIXED.candyPostE4 ~= nil", "the v9 posts, so the keep-out sees them")
		has(tool, 'k.why == "post candyPostE4"', "and the keep-out holds the new post")
		-- the plan and the relay
		has(tool, "V3Builder.planV5(root, Layout, V3)", "P2: planV5 under the v9 layout")
		has(tool, 'if c.Name ~= "Trees" then', "P3: every CaramelV3 child but Trees")
		has(tool, "inRect(GROWTH, pivot.X, pivot.Z)", "P4: annex props in the growth area")
		has(tool, "keepOut = keepOut, relay = true", "the layAll relay with the keep-out")
		has(tool, "local keepOut = Builder.treeKeepOut(Layout)", "the keep-out")
		has(tool, "V3Builder.layAll(root, deps)", "the relay on the map")
		has(tool, "V3Builder.layAll(scratch, probeDeps)", "and in the probe")
		has(tool, "Builder.layBoss(root, Layout)", "boss and plaza"); has(tool, "Builder.layPaths(root, Layout)", "paths")
		has(tool, "Builder.layMarkers(root, Layout)", "markers")
		has(tool, "Builder.syncTower(root, Layout, Kit, library)", "tower and T1")
		has(tool, "Builder.syncNestPositions(root, Layout)", "the four moved nests")
		has(tool, "Builder.syncNests(root, Layout, Kit, library)", "the 17 new nests")
		has(tool, 'torta:SetAttribute("LayoutKey", Builder.layoutKey(Layout))', "the Torta's new key")
		has(tool, "Layout.CENTRE.x + Layout.TORTA.x, Layout.CENTRE.z + Layout.TORTA.z", "the Torta to the layout's spot")
		has(tool, "Duq.seatPivot(Frut.summit(Layout)", "the queen on the new summit")
		-- CL-D13: the floor, the strips and the cloud wall with the fresh V3 (so the mouth parts are planned)
		has(tool, "floor.Size = Vector3.new(Layout.HALF + Layout.EAST, floor.Size.Y, 2 * Layout.HALF)", "the floor grows east")
		has(tool, "CFrame.new(Layout.CENTRE.x + (Layout.EAST - Layout.HALF) / 2, floor.Position.Y, Layout.CENTRE.z)", "centred on the new plot")
		has(tool, "East.stripPlan(Layout, slabs)", "the strips")
		has(tool, "East.build(Workspace, Layout, V3)", "the cloud wall")
		has(tool, "East.build(scratch, Layout, V3)", "and in the probe")
		-- nothing moves by the v8 scaling any more, and the water is laid by layAll, not layWater
		hasNot(tool, "fromV7World", "no v7 scaling")
		hasNot(tool, "layWater", "no layWater")
		if V3Builder then
			equal(type(V3Builder.planV5), "function", "V3Builder.planV5")
			equal(type(V3Builder.layAll), "function", "V3Builder.layAll")
			equal(type(V3Builder.existingProps), "function", "V3Builder.existingProps")
			equal(type(V3Builder.WATER_FOLDERS), "table", "V3Builder.WATER_FOLDERS")
		end
		if Builder then
			for _, name in ipairs({ "layPaths", "layBoss", "layMarkers", "syncTower", "syncNests", "syncNestPositions",
				"layoutKey", "treeKeepOut" }) do
				equal(type(Builder[name]), "function", "Builder." .. name)
			end
		end
		if Layout then
			equal(Layout.VERSION, 3, "Layout.VERSION"); equal(Layout.EAST, 860, "Layout.EAST"); equal(Layout.HALF, 260, "Layout.HALF")
			near(Layout.TORTA.x, 748.2, "Layout.TORTA.x", 1e-6)
			if Builder then equal(Builder.layoutKey(Layout), "748.2,0,42", "the Torta's layout key") end
			-- CL-D13: Ground.Floor (1120, 1, 520) at world (972, 0, -3)
			near(Layout.HALF + Layout.EAST, 1120, "floor size x"); near(2 * Layout.HALF, 520, "floor size z")
			near(Layout.CENTRE.x + (Layout.EAST - Layout.HALF) / 2, 972, "floor centre x"); near(Layout.CENTRE.z, -3, "floor centre z")
		end
		if V3 then
			equal(V3.VERSION, 5, "V3.VERSION"); equal(V3.V9.EAST, 860, "V3.V9.EAST")
			equal(V3.V9_MARK, "CaramelV9", "V3.V9_MARK is the tool's MARK")
		end
		if East and Layout then
			equal(type(East.build), "function", "East.build")
			-- the shape of stripPlan the tool reads: ok, missing, resize = { { name, side, rect } }
			local plan = East.stripPlan(Layout, {
				{ name = "StripSouth", minX = 412, maxX = 1012, minZ = -303, maxZ = -263 },
				{ name = "StripNorth", minX = 412, maxX = 1012, minZ = 257, maxZ = 297 },
			})
			equal(plan.ok, true, "both strips found")
			equal(#plan.missing, 0, "none missing")
			equal(#plan.resize, 2, "both resized")
			for _, r in ipairs(plan.resize) do
				assert(type(r.name) == "string" and (r.side == "south" or r.side == "north"), "a resize row names its slab and side")
				near(r.rect.minX, 412, r.name .. " minX"); near(r.rect.maxX, 1612, r.name .. " maxX")
			end
			local half = East.stripPlan(Layout, { { name = "StripSouth", minX = 412, maxX = 1012, minZ = -303, maxZ = -263 } })
			equal(half.ok, false, "one strip alone is refused")
		end
	end)

	return result
end

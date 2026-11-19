-- Invoke with require(freshTestClone)(require(freshKittenParkClone), require(freshGatitoAreaClone),
-- { grow = WildboundPuebloGatitoGrow.Source, move = WildboundPuebloGatitoMove.Source }).
-- Pueblo Gatito 600 x 1200 (docs/design/wildbound-pueblo-gatito-long-plan.md GL-D14, GL-D15; owner requests 2026-11-18
-- "hacelos mas largos aun" and 2026-11-19 "hace el mapa bastante mas largo"): source pins of the one-shot grow tool
-- (tools/wildbound-pueblo-gatito-grow.luau, kept in Studio as the disabled Script ServerStorage.WildboundPuebloGatitoGrow):
-- a dry run first, Edit mode only, the PuebloGatito mark 2 needed and 3 reported as "already", the backup, archive and
-- reverted folders with the two recordings, one Destroy (the probe's scratch model), the SistemaSonriente, sites, biome
-- and part-cap refusals, fresh module clones and the park calls in their order (GL-14); and the park module agreeing
-- with the tool's numbers (GL-15). The old move tool still refuses the grown frame. Changes nothing.
return function(Park, Area, sources)
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
	-- where needle first appears (plain) at or after init, asserted present
	local function at(source, needle, label, init)
		local i = type(source) == "string" and string.find(source, needle, init or 1, true)
		assert(i, (label or "missing") .. ": " .. needle)
		return i
	end
	local function count(source, pattern)
		local n = 0
		for _ in string.gmatch(source, pattern) do n += 1 end
		return n
	end
	sources = type(sources) == "table" and sources or {}
	local tool = sources.grow
	local move = sources.move

	case("GL-14 (GL-D14): the grow tool's source: dry run, Edit mode, marks, folders, recordings, refusals, the park calls in order", function()
		assert(type(tool) == "string" and #tool > 0, "pass { grow = WildboundPuebloGatitoGrow.Source }")
		-- the two switches stand alone on their lines, exactly
		assert(string.find(tool, "\nlocal DRY_RUN = true\r?\n"), "the line 'local DRY_RUN = true'")
		assert(string.find(tool, "\nlocal RESTORE = false\r?\n"), "the line 'local RESTORE = false'")
		hasNot(tool, "local DRY_RUN = false", "shipped as a real run")
		hasNot(tool, "local RESTORE = true", "shipped in RESTORE mode")
		equal(count(tool, "local DRY_RUN ="), 1, "one DRY_RUN switch")
		equal(count(tool, "local RESTORE ="), 1, "one RESTORE switch")
		-- Edit mode only, before the RESTORE branch and before any module
		local edit = at(tool, 'assert(not RunService:IsRunning(), "Edit mode only: stop Play first")', "Edit mode only")
		assert(edit < at(tool, "\nif RESTORE then", "the RESTORE branch"), "Edit mode asserted before RESTORE")
		assert(edit < at(tool, 'module(ServerStorage, "WildboundKittenPark")', "the park module's fresh clone"),
			"Edit mode asserted before the modules")
		-- the marks: needs 2 (the moved park), 3 is "already", the mark is Area.VERSION, set last
		has(tool, 'local MARK, NEEDS, GROWN = "PuebloGatito", 2, 3', "needs the move's mark 2, grows to 3")
		has(tool, 'local ROOT_NAME = "PuebloGatito_v1"', "the park's root")
		has(tool, "(tonumber(root:GetAttribute(MARK)) or 0) >= GROWN", "a grown root is recognised")
		local already = at(tool, "if grown(root) then", "a grown root reports already")
		local needs = at(tool, "assert(root:GetAttribute(MARK) == NEEDS", "a root without the mark 2 is refused")
		assert(already < needs, "already is checked before the mark 2 is required")
		has(tool, "summary.already = true", "reports already")
		equal(count(tool, "summary%.already = true"), 2, "at the top and again inside the real run's thread")
		has(tool, "if grown(Workspace:FindFirstChild(ROOT_NAME)) then", "a second quick real run checks the mark again")
		-- the guards: the grown Area (shared require) and the grown park module (fresh clone)
		has(tool, "local Area = require(areaModule)", "Area is the shared require the park module reads")
		has(tool, "Area.VERSION == GROWN and Area.GROWTH == 600 and Area.FAR == 860", "the grown frame")
		has(tool, "Area.ARM.maxZ == 1537", "the arm to z 1537")
		has(tool, "reopen the place if an older copy is cached", "the cache hint (R5)")
		for _, name in ipairs({ "buildGround", "build", "edgePlan", "buildEdge", "syncNests", "strays" }) do
			has(tool, 'type(Park.' .. name .. ') == "function"', "the park guard")
		end
		has(tool, "Park.PART_CAP == 2800", "PART_CAP 2800"); has(tool, "#Park.NESTS == 16", "16 nests")
		has(tool, "Park.EDGE_PARTS == 203", "EDGE_PARTS 203"); has(tool, "Park.ROOT_CAP == 3037", "ROOT_CAP 3037")
		has(tool, "Park.ROOT_CAP == Park.PART_CAP + Park.EDGE_PARTS + 2 + #Park.NESTS * Park.NEST_PARTS", "ROOT_CAP derived")
		has(tool, "local function module(parent, name)", "fresh copies")
		has(tool, "require(found:Clone())", "never the session's cached require")
		has(tool, 'module(ServerStorage, "WildboundCandyLayout")', "the layout clone")
		has(tool, 'module(ServerStorage, "WildboundCandyEast")', "the East clone")
		-- folders, recordings and the summary
		has(tool, 'local BACKUP, ARCHIVED, REVERTED = "GatitoGrowBackup", "GatitoGrowArchived", "GatitoGrowReverted"', "the three folders")
		has(tool, 'local ARCHIVE_ROOT = "WildboundMapArchive"', "under ServerStorage.WildboundMapArchive")
		has(tool, 'ChangeHistoryService:TryBeginRecording("PuebloGatitoGrow")', "the grow's recording")
		has(tool, 'ChangeHistoryService:TryBeginRecording("PuebloGatitoGrowRestore")', "the restore's recording")
		equal(count(tool, "TryBeginRecording%("), 2, "one recording per mode")
		equal(count(tool, "task%.delay%(0%.5, function%(%)"), 2, "both outside the caller's recording")
		equal(count(tool, "Enum%.FinishRecordingOperation%.Cancel"), 2, "both undone on a failure")
		has(tool, 'local SUMMARY_ATTRIBUTE = "WildboundPuebloGatitoGrowSummary"', "the JSON summary attribute")
		has(tool, "ServerStorage:SetAttribute(SUMMARY_ATTRIBUTE, json)", "published")
		has(tool, "_G.WildboundPuebloGatitoGrowSummary = summary", "and in _G")
		-- partsBefore is set in the summary's constructor, the other fields as summary.<field>
		for _, field in ipairs({ "partsBefore = { gatito = countParts(root)", "summary.partsAfter", "summary.estimate", "summary.archived",
			"summary.created", "summary.rebuild", "summary.overCap", "summary.dropped", "summary.known" }) do
			has(tool, field, "the summary field")
		end
		has(tool, "summary.partsAfter.gatito > Park.ROOT_CAP", "overCap is the root over ROOT_CAP")
		-- one Destroy (the probe's scratch model); nothing cleared or removed; no asset
		equal(count(tool, ":Destroy%("), 1, "one Destroy")
		has(tool, "scratch:Destroy()", "the scratch model's")
		hasNot(tool, ":ClearAllChildren(", "nothing cleared")
		hasNot(tool, ":Remove(", "nothing removed")
		hasNot(tool, "rbxassetid", "no asset")
		hasNot(tool, "InsertService", "no asset loaded")
		-- SistemaSonriente: never touched (the move tool's forbidden, descendants too), refused when it meets the box
		has(tool, "local SONRIENTE_BOX = { minX = -7, maxX = 601, minZ = 324, maxZ = 1541 }", "the SistemaSonriente box")
		has(tool, 'instance:FindFirstChild("SistemaSonriente", true) ~= nil', "a holder of SistemaSonriente is forbidden too")
		has(tool, "local hits = sonrienteHits()", "its parts measured")
		has(tool, 'table.insert(summary.refused, ("SistemaSonriente meets', "refused when it meets the box")
		-- the sites, the biome rows, the portal and the part caps
		has(tool, "local EXTRA_POSTS = 12", "12 east extra posts")
		has(tool, "math.abs(p.x - n.post.x) > 1e-3", "S2: every park post in the deployed EAST_FIXED")
		has(tool, '{ "AREAS", "AREAS_BIG4" }', "S3: classic and big4 lists")
		has(tool, 'row.tag == "CandyEast"', "S3: the CandyEast square")
		has(tool, "has no AREAS_BIG4 in a big4 place", "S3: a big4 place whose biome copy lost AREAS_BIG4 is refused")
		has(tool, 'Portal.station("parque2")', "S4: the second portal station")
		has(tool, "local KNOWN = { Apron_Volcanic = true }", "S4: the volcanic apron is known")
		has(tool, 'local KNOWN_PREFIX = "Road_big4_"', "S4: the big4 road is known")
		has(tool, "if estimate.park > Park.PART_CAP then", "S6: the park folder over PART_CAP is refused")
		has(tool, "if estimate.root > Park.ROOT_CAP then", "S6: the root over ROOT_CAP is refused")
		has(tool, "the probe failed, so the estimate is unknown", "S6: a failed probe refuses")
		has(tool, "d.Position.Z > 1024", "S6: the parts past the baseplate counted")
		has(tool, "local KD_DROPPED_PARTS = 14", "R7: the K-D drops")
		-- the probe lays the same four calls into the scratch model
		for _, call in ipairs({ "Park.buildGround(scratch)", "Park.build(scratch, Layout, East)", "Park.buildEdge(scratch)",
			"Park.syncNests(scratch)" }) do
			has(tool, call, "the probe")
		end
		-- the dry run surveys, publishes and returns before the real run is scheduled
		local dry = string.find(tool, "\nif DRY_RUN then\r?\n\tsurvey%(%)")
		assert(dry, "the dry run surveys, publishes and returns")
		local real = at(tool, 'TryBeginRecording("PuebloGatitoGrow")', "the real run's recording")
		assert(dry < real, "the dry run returns before the real run")
		-- the real run surveys again and honours the refusals before its recording opens
		local thread = at(tool, "local surveyed, strays = pcall(survey)", "the real run surveys again")
		local refused = at(tool, "if #summary.refused > 0 then", "the real run honours the refusals", thread)
		assert(thread < refused and refused < real, "refused before the recording: nothing changed")
		-- the real run's steps, in the GL-D14 order
		local order = {
			"holder.Name = BACKUP",
			"local copy = root:Clone()",
			"local groundReport = Park.buildGround(root)",
			"local archived = folderIn(archiveRoot, ARCHIVED)",
			"entry.instance.Parent = archived",
			"local parkReport = Park.build(root, Layout, East)",
			"local edgeReport = Park.buildEdge(root)",
			"local nestsReport = Park.syncNests(root)",
			"local groundAgain = Park.buildGround(root)",
			"local parkAgain = Park.build(root, Layout, East)",
			"local edgeAgain = Park.buildEdge(root)",
			"local nestsAgain = Park.syncNests(root)",
			"nestsAgain == 0",
			"root:SetAttribute(MARK, Area.VERSION)",
		}
		local last = real
		for _, needle in ipairs(order) do
			local i = at(tool, needle, "the real run's step", real)
			assert(i > last, "out of order: " .. needle)
			last = i
		end
		equal(count(tool, "root:SetAttribute%(MARK, Area%.VERSION%)"), 1, "one mark")
		has(tool, "kept the existing", "an older backup kept")
		has(tool, "local strays = Park.strays(root, Layout, East)", "S5: the archive list from the park module")
		has(tool, "groundAgain.created == 0 and groundAgain.changed == 0 and parkAgain.created == 0 and parkAgain.changed == 0",
			"the rebuild asserted")
		has(tool, "edgeAgain.created == 0 and edgeAgain.changed == 0", "the edge's rebuild asserted")
		-- RESTORE: needs the mark and the backup, moves the live root aside, clones the backup back
		has(tool, "assert(grown(live)", "RESTORE needs the mark 3")
		has(tool, "backup:FindFirstChild(ROOT_NAME)", "RESTORE needs the backup's root")
		has(tool, "current.Parent = reverted", "RESTORE moves the live root aside")
		has(tool, "local fresh = copy:Clone()", "and clones the backup back")
		-- the old move tool refuses the grown frame (it asserts VERSION 2 before its own "already")
		assert(type(move) == "string" and #move > 0, "pass { move = WildboundPuebloGatitoMove.Source }")
		has(move, "assert(Area.VERSION == 2, ", "the move tool asserts the move's frame")
	end)

	case("GL-15 (GL-D14, GL-D15): the park module agrees with the tool: caps, nests, the Approach, the box", function()
		assert(type(Park) == "table", "pass require(freshKittenParkClone)")
		assert(type(Area) == "table", "pass require(freshGatitoAreaClone)")
		-- the frame the tool asserts
		equal(Area.VERSION, 3, "Area.VERSION"); equal(Area.GROWTH, 600, "Area.GROWTH"); equal(Area.FAR, 860, "Area.FAR")
		equal(Area.ARM.maxZ, 1537, "Area.ARM.maxZ"); equal(Area.ROOT_NAME, "PuebloGatito_v1", "Area.ROOT_NAME")
		equal(Park.ROOT_NAME, Area.ROOT_NAME, "Park.ROOT_NAME")
		-- the park module the tool asserts
		equal(Park.VERSION, 2, "Park.VERSION")
		equal(Park.PART_CAP, 2800, "Park.PART_CAP")
		equal(Park.EDGE_PARTS, 203, "Park.EDGE_PARTS")
		equal(#Park.NESTS, 16, "#Park.NESTS")
		equal(Park.ROOT_CAP, 3037, "Park.ROOT_CAP")
		equal(Park.ROOT_CAP, Park.PART_CAP + Park.EDGE_PARTS + 2 + #Park.NESTS * Park.NEST_PARTS, "ROOT_CAP derived")
		for _, name in ipairs({ "buildGround", "build", "edgePlan", "buildEdge", "syncNests", "strays", "plan" }) do
			equal(type(Park[name]), "function", "Park." .. name)
		end
		local P = Park.APPROACH
		equal(P.minX, 272, "APPROACH.minX"); equal(P.maxX, 292, "APPROACH.maxX")
		equal(P.minZ, 324, "APPROACH.minZ"); equal(P.maxZ, 337, "APPROACH.maxZ")
		-- the tool's box: Area.ARM grown by the 4-stud walls, and down to the Approach at the gate side
		local A, wall = Area.ARM, Park.EDGE.wall
		equal(wall, 4, "Park.EDGE.wall")
		local minX, maxX, minZ, maxZ = string.match(tool or "",
			"local SONRIENTE_BOX = { minX = (%-?%d+), maxX = (%-?%d+), minZ = (%-?%d+), maxZ = (%-?%d+) }")
		assert(minX, "the tool's SONRIENTE_BOX literal")
		local box = { minX = tonumber(minX), maxX = tonumber(maxX), minZ = tonumber(minZ), maxZ = tonumber(maxZ) }
		near(box.minX, A.minX - wall, "box minX: the west wall's far face")
		near(box.maxX, A.maxX + wall, "box maxX: the east wall's far face")
		near(box.minZ, math.min(P.minZ, A.minZ), "box minZ: the Approach")
		near(box.maxZ, A.maxZ + wall, "box maxZ: the end wall's far face")
		local function inside(minX0, maxX0, minZ0, maxZ0, label)
			assert(minX0 >= box.minX - 1e-6 and maxX0 <= box.maxX + 1e-6 and minZ0 >= box.minZ - 1e-6 and maxZ0 <= box.maxZ + 1e-6,
				label .. (" (x %g..%g, z %g..%g) is outside the tool's box"):format(minX0, maxX0, minZ0, maxZ0))
		end
		inside(A.minX, A.maxX, A.minZ, A.maxZ, "the arm")
		inside(P.minX, P.maxX, P.minZ, P.maxZ, "the Approach")
		local space = Area.rect()
		inside(space.minX, space.maxX, space.minZ, space.maxZ, "the space")
		local edge = Park.edgePlan()
		equal(#edge.walls, 3, "three walls")
		equal(#edge.hedge, 100, "100 hedge puffs")
		for _, w in ipairs(edge.walls) do
			inside(w.x - w.size[1] / 2, w.x + w.size[1] / 2, w.z - w.size[3] / 2, w.z + w.size[3] / 2, w.name)
		end
		for _, h in ipairs(edge.hedge) do inside(h.x, h.x, h.z, h.z, h.id) end
		-- the floor the tool conforms: the whole arm
		near(Park.FLOOR.size[1], A.maxX - A.minX, "floor width"); near(Park.FLOOR.size[3], A.maxZ - A.minZ, "floor length")
		near(Park.FLOOR.centre.x, 297, "floor centre x"); near(Park.FLOOR.centre.z, 937, "floor centre z")
		-- every nest, post and chest the deployed sites must match, and the second portal, stand in the arm
		for _, n in ipairs(Park.NESTS) do
			for _, spot in ipairs({ { n.x, n.z, "nest" }, { n.post.x, n.post.z, "post" }, { n.chest.x, n.chest.z, "chest" } }) do
				assert(spot[1] >= A.minX and spot[1] <= A.maxX and spot[2] >= A.minZ and spot[2] <= A.maxZ,
					n.id .. " " .. spot[3] .. " outside the arm")
			end
			equal(n.post.key, "kittenPost" .. n.id, n.id .. " post key (S2 reads it)")
		end
		near(Park.PORTAL2.x, 227, "PORTAL2.x"); near(Park.PORTAL2.z, 1375, "PORTAL2.z")
		-- R7: the tool warns unless the plan drops exactly the K-D parts
		local wanted = tonumber(string.match(tool or "", "local KD_DROPPED_PARTS = (%d+)"))
		assert(wanted, "the tool's KD_DROPPED_PARTS literal")
		local plan = Park.plan(nil, nil)
		local dropped = 0
		for _, d in ipairs(plan.dropped) do dropped += d.parts end
		equal(dropped, wanted, "the plan's dropped parts")
		assert(plan.parts <= Park.PART_CAP, ("the plan's %d parts are over PART_CAP %d"):format(plan.parts, Park.PART_CAP))
	end)

	return result
end

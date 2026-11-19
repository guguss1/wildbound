-- Invoke with require(freshTestClone)(require(freshKittenParkClone), require(freshCandyEastClone),
-- require(freshCandyLayoutClone), { park = WildboundKittenPark.Source, build = WildboundKittenParkBuild.Source }).
-- Pueblo Gatito, the kitten park in Caramelo Este (owner request 2026-11-17: "es como el mundo de gatito: un parque verde
-- lindo con las criaturas gatitas, juguetes como rollos de papel, hisopos, papel, bolsas, tiendas de gatitos como que es
-- su village ... también tiene que haber huevos para robar"; docs/design/wildbound-kitten-park-plan.md, K-D1 to K-D21,
-- §4 Set A, KP1 to KP9): the park's plan, recipes and budget, a build into a detached model (twice: the second changes
-- nothing), the nest markers, the two archives on detached fixtures, the SistemaSonriente refusal and the one-shot
-- tool's source. Changes nothing outside its own detached instances.
-- Since the move (owner request 2026-11-18 "Sí, movelo"; docs/design/wildbound-pueblo-gatito-move-plan.md PGM-D2, PGM-D4)
-- the park stands in its own root Workspace.PuebloGatito_v1 on the big4 south arm, every position in the park frame of
-- ReplicatedStorage.WildboundGatitoArea (world(lx, lz) = (282 - lz, 600 + lx)); KP12 checks its own floor.
-- Grown to 600 x 1200 (owner requests 2026-11-18 "hacelos mas largos aun" and 2026-11-19 "hace el mapa bastante mas
-- largo"; docs/design/wildbound-pueblo-gatito-long-plan.md GL-D1..GL-D17): the Jardín de Ovillos (local x 260..860) on
-- its own generator, the far-end goal, sixteen nests, the second portal, the arm floor and the Approach, the edge walls
-- and the hedge, the strays list (GL-2..GL-10).
return function(Park, East, Layout, sources)
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
	local function flat(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
	local function segment(x, z, a, b)
		local dx, dz = b.x - a.x, b.z - a.z
		local l2 = dx * dx + dz * dz
		local t = l2 > 0 and math.clamp(((x - a.x) * dx + (z - a.z) * dz) / l2, 0, 1) or 0
		return flat(x, z, a.x + t * dx, a.z + t * dz)
	end
	local function pathDistance(path, x, z)
		local best = math.huge
		for i = 1, #path.points - 1 do best = math.min(best, segment(x, z, path.points[i], path.points[i + 1])) end
		return best
	end
	assert(type(Park) == "table" and type(East) == "table" and type(Layout) == "table", "pass KittenPark, CandyEast and Layout")
	sources = type(sources) == "table" and sources or {}
	local CollectionService = game:GetService("CollectionService")
	-- PGM-D1: the park frame (the module the park itself requires)
	local Area = require(game:GetService("ReplicatedStorage"):WaitForChild("WildboundGatitoArea"))

	-- K-D18: BaseParts per folder before the drop rules
	local KD18 = { Paths = 254, Gate = 8, Village = 310, ToyPark = 98, Toys = 160, Chests = 88, Trees = 208, Lanterns = 130,
		Scatter = 136 }
	-- GL-D8: the Jardín de Ovillos' BaseParts per folder before the drop rules (which drop none of it); Chests are
	-- Chest_K9..K16
	local GARDEN = { Paths = 288, Gate = 0, Village = 93, ToyPark = 119, Toys = 188, Chests = 88, Trees = 196, Lanterns = 105,
		Scatter = 134 }
	-- Appendix B: parts per recipe
	local EXPECT = {
		strip = 1, joint = 1, junction = 1, slab = 1, stone = 1, arch = 8,
		cafe = 38, bakery = 34, potter = 40, fishshop = 36, takoyaki = 39, taiyaki = 33, castle = 53, tower = 37,
		scratchCastle = 44, scratchTree = 33, boxTower = 21,
		yarn = 7, yarnSmall = 2, rollStand = 4, rollLying = 4, kitchen = 5, tunnel = 7, tube = 3, bundle = 4,
		swab = 3, swabCup = 10, swabCross = 6, paperBall = 2, sheet = 1, tent = 2, notebook = 4,
		paperBag = 6, plasticBag = 3, giantBag = 5, chest = 11,
		treeL = 6, treeS = 4, bush = 2, lanternTall = 5, lanternShort = 5, patch = 1, flower = 3, tuft = 2,
		-- Deliberately changed (GL-D5): the hedge puff of the edge border, a long low oval and a lighter top
		hedge = 2,
	}
	local ROLES = { floor = true, solid = true, decor = true }
	local SHAPES = { Block = true, Ball = true, Cylinder = true, Wedge = true }

	-- One detached build, shared by the cases that read the built park (destroyed at the end).
	local scratch = nil
	local function built()
		if not scratch then
			local root = Instance.new("Model")
			root.Name = "KittenParkTest"
			local report = Park.build(root, Layout, East)
			scratch = { root = root, report = report }
		end
		return scratch
	end
	-- the folder (directly under root.Park) a built part belongs to
	local function folderOf(park, part)
		local node = part
		while node.Parent and node.Parent ~= park do node = node.Parent end
		return node.Name
	end

	case("KP0: the interface: names, seed, the K-D18 budget, the sign strings (Latin only)", function()
		-- Deliberately changed (PGM-D2, owner request 2026-11-18 "Sí, movelo"): the park has its own root,
		-- Workspace.PuebloGatito_v1 = Area.ROOT_NAME (was "Candy_Este_v1" = East.ROOT_NAME)
		-- Deliberately changed (GL-D14, GL-D15): Park.VERSION 2 (was 1; the live Park folder's Version says it was grown)
		-- and PART_CAP 2800 (was 1400) for the K-D half and the Jardín de Ovillos; the K-D18 table and its 1392 stay
		equal(Park.VERSION, 2); equal(Park.ROOT_NAME, "PuebloGatito_v1"); equal(Park.ROOT_NAME, Area.ROOT_NAME, "one root")
		equal(Park.FOLDER, "Park"); equal(Park.NESTS_FOLDER, "Nests"); equal(Park.FORBIDDEN, "SistemaSonriente")
		equal(Park.SEED, 8128); equal(Park.PART_CAP, 2800); equal(Park.NEST_PARTS, 2)
		for folder, n in pairs(KD18) do equal(Park.BUDGET[folder], n, folder .. " budget") end
		local total = 0
		for _, n in pairs(Park.BUDGET) do total += n end
		equal(total, 1392, "the K-D18 park total")
		assert(table.isfrozen(Park.NESTS) and table.isfrozen(Park.NESTS[1]) and table.isfrozen(Park.NESTS[1].post)
			and table.isfrozen(Park.PORTAL) and table.isfrozen(Park.ARRIVAL) and table.isfrozen(Park.BUDGET), "frozen data")
		-- Deliberately changed (PGM-D4): the portal and the arrival disc in the park frame, world of local (-228, 43) and
		-- (-244, 0) (was (980, 40) and (964, -3))
		near(Park.PORTAL.x, 239); near(Park.PORTAL.z, 372)
		near(Park.ARRIVAL.x, 282); near(Park.ARRIVAL.z, 356); near(Park.ARRIVAL.r, 30)
		near(Park.PORTAL.lx, -228); near(Park.PORTAL.lz, 43); near(Park.ARRIVAL.lx, -244); near(Park.ARRIVAL.lz, 0)
		local wanted = { "Pueblo Gatito", "Café Cat", "Paws & Coffee", "Panadería Gatuna", "=^.^=", "Takoyaki", "Taiyaki", "Mochi" }
		equal(#Park.SIGNS, #wanted, "sign count")
		for i, text in ipairs(wanted) do equal(Park.SIGNS[i], text, "sign " .. i) end
		for _, text in ipairs(Park.SIGNS) do
			assert(utf8.len(text), text .. " is valid UTF-8")
			for _, code in utf8.codes(text) do assert(code < 0x2E80, text .. ": no CJK") end
		end
	end)

	case("KP1: every item and path point inside the space inset by 4; the arrival disc holds only the gate and paths; the portal disc is empty", function()
		local plan = Park.plan(Layout, East)
		-- Deliberately changed (PGM-D4, owner request 2026-11-18 "Sí, movelo"): the frame is Area's, the floor square
		-- x 22..542, z 340..860 round (282, 600), the arch at world (282, 346), the gate 14 wide (was East.plan's space,
		-- centre (1208, -3), the arch at (954, -3) and East.GATE.width)
		local space = Area.rect()
		near(plan.centre.x, 282, "centre x"); near(plan.centre.z, 600, "centre z"); near(plan.floorTop, 0.5, "floor top")
		-- Deliberately changed (GL-D1, GL-D13): the space runs to the far end, z 1460 (was 860), and every item also keeps
		-- out of the second portal's 12-stud disc (Park.PORTAL2, world (227, 1375))
		near(plan.space.minX, 22, "space minX"); near(plan.space.maxX, 542, "space maxX")
		near(plan.space.minZ, 340, "space minZ"); near(plan.space.maxZ, 1460, "space maxZ")
		assert(type(plan.portal2) == "table", "the plan names the second portal")
		near(plan.portal2.x, Park.PORTAL2.x, "portal2 x"); near(plan.portal2.z, Park.PORTAL2.z, "portal2 z")
		near(plan.gate.x, 282, "the arch's x"); near(plan.gate.z, 346, "the arch's z"); equal(plan.gate.width, 14, "gate width")
		local function inside(x, z, label)
			assert(x >= space.minX + 4 and x <= space.maxX - 4 and z >= space.minZ + 4 and z <= space.maxZ - 4,
				label .. (" at (%.1f, %.1f) is outside the space"):format(x, z))
		end
		for _, path in ipairs(plan.paths) do
			for i, p in ipairs(path.points) do inside(p.x, p.z, "path " .. path.id .. " point " .. i) end
		end
		local ids = {}
		for _, it in ipairs(plan.items) do
			inside(it.x, it.z, it.id)
			assert(not ids[it.id], "duplicate id " .. it.id)
			ids[it.id] = true
			assert(EXPECT[it.kind], it.id .. " has a known kind")
			local inArrival = flat(it.x, it.z, Park.ARRIVAL.x, Park.ARRIVAL.z) < Park.ARRIVAL.r
			assert(not inArrival or it.folder == "Gate" or it.folder == "Paths", it.id .. " stands in the arrival disc")
			assert(flat(it.x, it.z, Park.PORTAL.x, Park.PORTAL.z) >= 12, it.id .. " stands in the portal's clear disc")
			assert(flat(it.x, it.z, Park.PORTAL2.x, Park.PORTAL2.z) >= 12, it.id .. " stands in the second portal's clear disc")
		end
		-- the main path starts at the gate and runs on the gate's axis through the arrival point
		local main = plan.paths[1]
		equal(main.id, "M"); equal(main.width, 12, "the main path is 12 wide")
		-- Deliberately changed (PGM-D4): the first point is world of local (-252, 0), (282, 348), on the axis x 282 (was
		-- (956, -3) on the avenue's axis z -3)
		near(main.points[1].x, 282, "on the gate's axis"); near(main.points[1].z, 348, "starts just past the arch")
		for _, path in ipairs(plan.paths) do
			assert(path.width >= 8 and path.width <= 14, path.id .. " width")
		end
		-- the arch: its pillars leave the 14-stud gap clear and stand on the gate's axis
		-- Deliberately changed (PGM-D4): compared along the arch's local z, -7..7 round its pivot (was the world z of the
		-- gap, -10..4); the arch turns with the frame
		local arch = Park.recipe("arch")
		local pillars = 0
		local half = plan.gate.width / 2
		for _, spec in ipairs(arch) do
			if string.find(spec.name, "Pillar", 1, true) then
				pillars += 1
				local z = spec.offset[3]
				local r = spec.size[2] / 2
				assert(z - r >= half or z + r <= -half, spec.name .. " stands in the gap")
			end
		end
		equal(pillars, 2, "two pillars")
		-- PGM-D4: an item placed from the local tables with a yaw turns by Area.worldYaw (yaw - 90); the arch (local 0), the
		-- Café Cat at world of local (-170, -150) = (432, 430) with local 180, the tower (local 90), the giant bag (local -45)
		local byId = {}
		for _, it in ipairs(plan.items) do byId[it.id] = it end
		near(byId.ArcoDeNubes.yaw, -90, "the arch's yaw")
		near(byId.CafeCat.x, 432, "the café's x"); near(byId.CafeCat.z, 430, "the café's z"); near(byId.CafeCat.yaw, 90, "the café's yaw")
		near(byId.TorreGatoVigia.yaw, 0, "the tower's yaw")
		near(byId.GiantBag.yaw, -135, "the giant bag's yaw")
		-- deterministic
		local again = Park.plan(Layout, East)
		equal(#again.items, #plan.items, "same item count")
		for i, it in ipairs(plan.items) do
			local other = again.items[i]
			assert(other.id == it.id and other.x == it.x and other.z == it.z and other.yaw == it.yaw and other.variant == it.variant,
				it.id .. " differs between two plans")
		end
	end)

	case("KP2: sixteen nests K1..K16, 5 Comun 6 Rara 5 Epica; posts 12 from their nests and 85 apart; chests 7 behind", function()
		-- Deliberately changed (GL-D10, GL-D11): 16 nests K1..K16 (was 8), rarity by depth 5 Comun, 6 Rara, 5 Epica (was
		-- 3, 3, 2), the posts' band local x -170..760 (was -170..180), and the guard table holds the 8 new extra posts
		equal(#Park.NESTS, 16, "sixteen nests")
		local layoutIds = {}
		for _, n in ipairs(Layout.NESTS) do layoutIds[n.id] = true end
		local ids, counts = {}, { Comun = 0, Rara = 0, Epica = 0 }
		for i, n in ipairs(Park.NESTS) do
			equal(n.id, "K" .. i, "id " .. i)
			assert(not ids[n.id], "duplicate " .. n.id); ids[n.id] = true
			assert(not layoutIds[n.id], n.id .. " collides with a plot nest")
			assert(n.id ~= "T1", "La Duquesa's T1 stays hers")
			assert(counts[n.rarity] ~= nil, n.id .. " rarity " .. tostring(n.rarity))
			counts[n.rarity] += 1
			near(flat(n.x, n.z, n.post.x, n.post.z), 12, n.id .. " post distance", 0.01)
			-- Deliberately changed (PGM-D4): the posts' band in park-local terms, local x -170..180 and |local z| <= 180 (was
			-- world x 1038..1388, |z + 3| <= 180); the nest, post and chest carry local lx, lz that match their world x, z
			local plx, plz = Area.localOf(n.post.x, n.post.z)
			assert(plx >= -170 and plx <= 760 and math.abs(plz) <= 180, n.id .. " post inside the posts' band")
			near(n.post.lx, plx, n.id .. " post lx"); near(n.post.lz, plz, n.id .. " post lz")
			local nlx, nlz = Area.localOf(n.x, n.z)
			near(n.lx, nlx, n.id .. " lx"); near(n.lz, nlz, n.id .. " lz")
			local clx, clz = Area.localOf(n.chest.x, n.chest.z)
			near(n.chest.lx, clx, n.id .. " chest lx"); near(n.chest.lz, clz, n.id .. " chest lz")
			equal(n.post.key, "kittenPost" .. n.id, n.id .. " post key")
			near(flat(n.x, n.z, n.chest.x, n.chest.z), 7, n.id .. " chest distance", 0.01)
			local dot = (n.chest.x - n.x) * (n.post.x - n.x) + (n.chest.z - n.z) * (n.post.z - n.z)
			assert(dot < 0, n.id .. " chest on the far side from the post")
			assert(string.match(n.guard, "^%w+$") or string.match(n.guard, "^%w+@kittenPost%w+$"), n.id .. " guard " .. n.guard)
		end
		equal(counts.Comun, 5, "Comun"); equal(counts.Rara, 6, "Rara"); equal(counts.Epica, 5, "Epica")
		for i = 1, #Park.NESTS do
			for j = i + 1, #Park.NESTS do
				local a, b = Park.NESTS[i].post, Park.NESTS[j].post
				assert(flat(a.x, a.z, b.x, b.z) >= 85, ("posts %s and %s are %.1f apart"):format(a.key, b.key, flat(a.x, a.z, b.x, b.z)))
			end
		end
		-- the K-D8 table: home guards for K1..K4, "<name>@<post>" for the east extra posts K5..K8 and (GL-D10) K9..K16
		local guards = { "GatitoGuerrero", "GatitaBouquet", "GatitoActually", "GatitoLanudo", "GatitoGuerrero@kittenPostK5",
			"GatitaBouquet@kittenPostK6", "GatitoActually@kittenPostK7", "GatitoLanudo@kittenPostK8",
			"GatitoGuerrero@kittenPostK9", "GatitaBouquet@kittenPostK10", "GatitoActually@kittenPostK11",
			"GatitoLanudo@kittenPostK12", "GatitoGuerrero@kittenPostK13", "GatitaBouquet@kittenPostK14",
			"GatitoActually@kittenPostK15", "GatitoLanudo@kittenPostK16" }
		equal(#guards, #Park.NESTS, "a guard per nest")
		for i, g in ipairs(guards) do equal(Park.NESTS[i].guard, g, "K" .. i .. " guard") end
		-- Deliberately changed (PGM-D4): K1 and K8 in the park frame, world of local (-170, -55) and (150, 120) (was
		-- (1038, -58) and (1358, 117)); K1's post (325, 430) and chest (344, 430) (were (1038, -46) and (1038, -65))
		near(Park.NESTS[1].x, 337); near(Park.NESTS[1].z, 430); near(Park.NESTS[8].x, 162); near(Park.NESTS[8].z, 750)
		near(Park.NESTS[1].post.x, 325); near(Park.NESTS[1].post.z, 430)
		near(Park.NESTS[1].chest.x, 344); near(Park.NESTS[1].chest.z, 430)
		near(Park.NESTS[1].lx, -170); near(Park.NESTS[1].lz, -55); near(Park.NESTS[8].lx, 150); near(Park.NESTS[8].lz, 120)
	end)

	case("KP3: no solid or floor part within 8 of a nest, post or chest; solid parts keep 6 + half the width off every path", function()
		local plan = Park.plan(Layout, East)
		local park = built().root[Park.FOLDER]
		local checked = 0
		for _, part in ipairs(park:GetDescendants()) do
			if part:IsA("BasePart") then
				local role, folder = part:GetAttribute("Role"), folderOf(park, part)
				local p = part.Position
				if (role == "solid" or role == "floor") and folder ~= "Paths" and folder ~= "Chests" then
					for _, n in ipairs(Park.NESTS) do
						for _, spot in ipairs({ n, n.post, n.chest }) do
							assert(flat(p.X, p.Z, spot.x, spot.z) >= 8, ("%s.%s is %.1f from %s"):format(part.Parent.Name, part.Name,
								flat(p.X, p.Z, spot.x, spot.z), n.id))
						end
					end
					checked += 1
				end
				if role == "solid" and folder ~= "Paths" and folder ~= "Gate" and folder ~= "Lanterns" then
					for _, path in ipairs(plan.paths) do
						local d = pathDistance(path, p.X, p.Z)
						assert(d >= 6 + path.width / 2, ("%s.%s is %.1f from path %s"):format(part.Parent.Name, part.Name, d, path.id))
					end
				end
			end
		end
		assert(checked > 100, "solid and floor parts checked: " .. checked)
	end)

	case("KP4: per-folder counts are the K-D18 and garden tables minus the drops; the park stays under PART_CAP, the nests at 32", function()
		-- Deliberately changed (GL-D15): per folder = K-D18 + Park.GARDEN_BUDGET minus the drops (was K-D18 alone); "under
		-- 1400" is now Park.PART_CAP (2800); chests K1..K16 (was K1..K8); the nests 16 x 2 = 32 parts (was 16)
		local plan = Park.plan(Layout, East)
		local droppedParts = {}
		for folder in pairs(KD18) do droppedParts[folder] = 0 end
		for _, d in ipairs(plan.dropped) do
			assert(droppedParts[d.folder] ~= nil, d.id .. " dropped from an unknown folder")
			assert(d.folder ~= "Paths" and d.folder ~= "Gate" and d.folder ~= "Chests", d.id .. " is placed on purpose: " .. d.reason)
			equal(d.parts, EXPECT[d.kind], d.id .. " parts")
			droppedParts[d.folder] += d.parts
		end
		local sum = 0
		for folder, n in pairs(KD18) do
			equal(plan.budget[folder], n + GARDEN[folder] - droppedParts[folder], folder)
			sum += plan.budget[folder]
		end
		equal(plan.parts, sum, "the park total")
		assert(plan.parts <= Park.PART_CAP, "over the cap: " .. plan.parts)
		-- the drops the plan names (K-D16, Appendix A): the tree in the portal's disc, the patches on nests, the tuft on post K1
		local why = {}
		for _, d in ipairs(plan.dropped) do why[d.id] = d.reason end
		assert(why.TreeL_01, "the large tree at local (-235, 45) stands in the portal's clear disc")
		assert(why.Patch_03 and why.Patch_04 and why.Patch_05, "the patches at (-165, 95), (-60, 70), (-60, -60) lie on nests")
		assert(why.Tuft_03, "the tuft at (-175, -40) stands on post K1")
		-- every building and big toy is kept
		local kept = {}
		for _, it in ipairs(plan.items) do kept[it.id] = it end
		for _, id in ipairs({ "CafeCat", "PanaderiaGatuna", "CasaGatoAlfarero", "TiendaGloboPez", "TakoyakiGatuno", "TaiyakiMochi",
			"CastilloCarton", "TorreGatoVigia", "CastilloRascador", "ArbolRascador", "TorreDeCajas", "ArcoDeNubes",
			"CasaOvillera", "CastilloDeOvillos", "ArbolRascadorJardin", "TorreDeCajasJardin", "CastilloRascadorJardin",
			"TorreDeCajasMirador" }) do
			assert(kept[id], id .. " kept")
		end
		for i = 1, 16 do assert(kept["Chest_K" .. i], "chest K" .. i) end
		-- the built park has exactly the planned parts per folder
		local b = built()
		local park = b.root[Park.FOLDER]
		local total = 0
		for folder in pairs(KD18) do
			local n = 0
			for _, d in ipairs(park[folder]:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
			equal(n, plan.budget[folder], "built " .. folder)
			equal(b.report.byFolder[folder], plan.budget[folder], "reported " .. folder)
			total += n
		end
		equal(b.report.parts, total, "report.parts"); equal(total, plan.parts, "built total")
		-- the nests: 16 x 2
		local nestRoot = Instance.new("Model")
		Park.syncNests(nestRoot)
		local nests = 0
		for _, d in ipairs(nestRoot[Park.NESTS_FOLDER]:GetDescendants()) do if d:IsA("BasePart") then nests += 1 end end
		equal(nests, 32, "nest parts"); equal(nests, #Park.NESTS * Park.NEST_PARTS, "nests at 16 x NEST_PARTS")
		nestRoot:Destroy()
	end)

	case("KP5: build is idempotent; anchored parts with their roles' flags; primitives only; signs are SurfaceGui + TextLabel", function()
		local b = built()
		local root = b.root
		assert(b.report.created > 1000, "made the park: " .. b.report.created)
		local second = Park.build(root, Layout, East)
		equal(second.created, 0, "nothing made the second time"); equal(second.changed, 0, "nothing changed the second time")
		local park = root[Park.FOLDER]
		equal(park:GetAttribute("Version"), Park.VERSION, "version")
		local guis, lights, texts = 0, 0, {}
		for _, d in ipairs(root:GetDescendants()) do
			assert(not d:IsA("MeshPart"), "a MeshPart: " .. d:GetFullName())
			assert(not d:IsA("Decal") and not d:IsA("Texture"), "a decal: " .. d:GetFullName())
			assert(not d:IsA("ImageLabel") and not d:IsA("ImageButton") and not d:IsA("SurfaceAppearance"), "an image: " .. d:GetFullName())
			if d:IsA("BasePart") then
				equal(d.Anchored, true, d.Name .. " anchored")
				local role = d:GetAttribute("Role")
				assert(ROLES[role], d:GetFullName() .. " role " .. tostring(role))
				local solid = role ~= "decor"
				equal(d.CanCollide, solid, d.Name .. " CanCollide"); equal(d.CanQuery, solid, d.Name .. " CanQuery")
				equal(d.CanTouch, false, d.Name .. " CanTouch")
			elseif d:IsA("SpecialMesh") then
				equal(d.MeshType, Enum.MeshType.Sphere, "a Sphere mesh only")
				equal(d.MeshId, "", "no mesh id"); equal(d.TextureId, "", "no texture id")
			elseif d:IsA("SurfaceGui") then
				guis += 1
				local label = d:FindFirstChildOfClass("TextLabel")
				assert(label, d:GetFullName() .. " holds a TextLabel")
				texts[label.Text] = true
			elseif d:IsA("PointLight") then
				lights += 1
				equal(d.Shadows, false, "lights cast no shadow")
			end
		end
		assert(guis >= 8 and guis <= 14, "about 12 signs: " .. guis)
		-- Deliberately changed (GL-D8): 19 lights (was 12), the garden's 7 tall lanterns along M2 added
		equal(lights, 19, "8 tall lanterns + 7 in the garden + 4 on the Tower Plaza")
		for text in pairs(texts) do assert(table.find(Park.SIGNS, text), "sign text from Park.SIGNS: " .. text) end
		for _, text in ipairs(Park.SIGNS) do assert(texts[text], "sign shown: " .. text) end
		-- the sources
		for key, source in pairs({ park = sources.park, build = sources.build }) do
			for _, banned in ipairs({ "rbxassetid", "MeshId", "TextureID" }) do hasNot(source, banned, key .. " uploads nothing") end
		end
		-- a piece pushed off its plan is set back, then nothing changes
		local body = park.Village.CafeCat.Body
		local was = body.CFrame
		body.CFrame = was + Vector3.new(5, 0, 0)
		body.CanCollide = false
		local fixed = Park.build(root, Layout, East)
		assert(fixed.changed >= 2 and fixed.created == 0, "set back: " .. fixed.changed)
		assert(body.CFrame:FuzzyEq(was, 1e-4) and body.CanCollide, "the café's body is back")
		equal(Park.build(root, Layout, East).changed, 0, "settled")
	end)

	case("KP6: syncNests writes the sixteen Nest_K* markers with the full contract; idempotent; puts a moved nest back", function()
		-- Deliberately changed (GL-D10): syncNests makes 16 nests (was 8)
		local root = Instance.new("Model")
		root.Name = "NestTest"
		local nests = Instance.new("Folder")
		nests.Name = Park.NESTS_FOLDER
		nests.Parent = root
		local foreign = Instance.new("Model")
		foreign.Name = "Nest_Other"
		foreign:SetAttribute("NestId", "Z9")
		foreign.Parent = nests
		equal(Park.syncNests(root), 16, "sixteen nests made")
		equal(Park.syncNests(root), 0, "a second call changes nothing")
		equal(Park.syncNests(nil), 0, "no root, nothing")
		for _, n in ipairs(Park.NESTS) do
			local nest = nests:FindFirstChild("Nest_" .. n.id)
			assert(nest and nest:IsA("Model"), "Nest_" .. n.id)
			equal(nest:GetAttribute("NestId"), n.id); equal(nest:GetAttribute("Rarity"), n.rarity)
			equal(nest:GetAttribute("EventOnly"), false); equal(nest:GetAttribute("Candidate"), true)
			equal(nest:GetAttribute("Enabled"), true); equal(nest:GetAttribute("Park"), true); equal(nest:GetAttribute("Guard"), n.guard)
			assert(CollectionService:HasTag(nest, "WildboundCandyNestCandidate"), n.id .. " tag")
			local bowl, ring = nest:FindFirstChild("Collision_Bowl"), nest:FindFirstChild("RarityRing")
			assert(bowl and ring, n.id .. " bowl and ring")
			equal(nest.PrimaryPart, bowl, n.id .. " PrimaryPart")
			equal(bowl.Shape, Enum.PartType.Cylinder); equal(bowl.Material, Enum.Material.Wood)
			equal(bowl:GetAttribute("Role"), "solid"); equal(bowl.CanCollide, true); equal(bowl.Anchored, true)
			equal(ring.CanCollide, false, "the ring never collides"); equal(ring:GetAttribute("Role"), "decor")
			local c, s = bowl.CFrame, bowl.Size
			local top = bowl.Position.Y + (math.abs(c.RightVector.Y) * s.X + math.abs(c.UpVector.Y) * s.Y + math.abs(c.LookVector.Y) * s.Z) / 2
			near(top, 2.7, n.id .. " bowl top (the egg sits on it)")
			near(math.max(s.Y, s.Z), 6, n.id .. " bowl diameter")
			local pivot = nest:GetPivot()
			near(pivot.X, n.x, n.id .. " x"); near(pivot.Y, Park.FLOOR_TOP, n.id .. " on the floor"); near(pivot.Z, n.z, n.id .. " z")
			local color = Park.RING_COLORS[n.rarity]
			near(ring.Color.R * 255, color[1], n.id .. " ring R", 0.6); near(ring.Color.G * 255, color[2], n.id .. " ring G", 0.6)
		end
		-- a moved nest is put back; the foreign marker is never touched
		local k3 = nests.Nest_K3
		k3:PivotTo(CFrame.new(0, 10, 0))
		assert(Park.syncNests(root) >= 1, "the moved nest counted")
		local pivot = k3:GetPivot()
		near(pivot.X, Park.NESTS[3].x, "K3 back x"); near(pivot.Z, Park.NESTS[3].z, "K3 back z")
		equal(Park.syncNests(root), 0, "settled")
		equal(foreign.Parent, nests, "the foreign child stays"); equal(foreign:GetAttribute("NestId"), "Z9", "untouched")
		equal(#foreign:GetChildren(), 0, "nothing added to it")
		root:Destroy()
	end)

	-- a part at (x, y, z) under parent
	local function piece(parent, name, x, z, collide, role)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = collide ~= false
		p.Position = Vector3.new(x, 2, z)
		if role then p:SetAttribute("Role", role) end
		p.Parent = parent
		return p
	end

	case("KP7: archiveAnnex: the dry run lists exactly the pieces in the second space and moves nothing; the real run moves only those", function()
		local annex = Instance.new("Model")
		annex.Name = "AnnexTest"
		local props = Instance.new("Folder")
		props.Name = "Props"
		props.Parent = annex
		-- Deliberately changed (CL-D13): the second space moved east with the grown plot (x 1548..2068, was 948..1468)
		local a = piece(props, "A", 1600, 0)
		local bModel = Instance.new("Model")
		bModel.Name = "B"
		piece(bModel, "Trunk", 1800, 100)
		bModel.WorldPivot = CFrame.new(1800, 2, 100)
		bModel.Parent = props
		local c = piece(props, "C", 1500, 0) -- in the plot
		local d = piece(props, "D", 1600, -280) -- the annex's south strip
		local ground = Instance.new("Folder")
		ground.Name = "Ground"
		ground.Parent = annex
		local slab = piece(ground, "Floor_Big4_2", 712, -283)
		local archive = Instance.new("Folder")
		archive.Name = "KittenParkAnnex"
		local dry = Park.archiveAnnex(annex, nil, Layout, East, true)
		equal(dry.count, 2, "two pieces in the space")
		equal(dry.moved[1], "Props.A"); equal(dry.moved[2], "Props.B")
		equal(a.Parent, props, "the dry run moves nothing"); equal(bModel.Parent, props, "the dry run moves nothing")
		local real = Park.archiveAnnex(annex, archive, Layout, East, false)
		equal(real.count, 2, "two moved")
		equal(a.Parent, archive, "A archived"); equal(bModel.Parent, archive, "B archived")
		equal(c.Parent, props, "C stays"); equal(d.Parent, props, "D stays"); equal(slab.Parent, ground, "the strip stays")
		equal(Park.archiveAnnex(annex, archive, Layout, East, false).count, 0, "nothing left to move")
		equal(Park.archiveAnnex(nil, archive, Layout, East, false).count, 0, "no annex, nothing")
		annex:Destroy(); archive:Destroy()
	end)

	case("KP8: clearGate moves only the colliding pieces in the gate corridor; decor, floors, Ground and far pieces stay", function()
		local biome = Instance.new("Model")
		biome.Name = "BiomeTest"
		local fill = Instance.new("Folder")
		fill.Name = "EdgeFill"
		fill.Parent = biome
		local rock = piece(fill, "Rock", 920, -3)
		local flower = piece(fill, "Flower", 915, 0, false, "decor")
		local tree = Instance.new("Model")
		tree.Name = "Tree"
		piece(tree, "Trunk", 905, 5)
		tree.WorldPivot = CFrame.new(905, 2, 5)
		tree.Parent = fill
		local far = piece(fill, "Far", 880, -3)
		local north = piece(fill, "North", 920, 30)
		local step = piece(fill, "Step", 925, 0, true, "floor")
		local ground = Instance.new("Folder")
		ground.Name = "Ground"
		ground.Parent = biome
		local floor = piece(ground, "Floor", 920, 0)
		local archive = Instance.new("Folder")
		archive.Name = "KittenGate"
		local dry = Park.clearGate(biome, nil, true)
		equal(dry.count, 2, "the rock and the tree")
		equal(dry.moved[1], "EdgeFill.Rock"); equal(dry.moved[2], "EdgeFill.Tree")
		equal(rock.Parent, fill, "the dry run moves nothing")
		local real = Park.clearGate(biome, archive, false)
		equal(real.count, 2, "two moved")
		equal(rock.Parent, archive, "the rock archived"); equal(tree.Parent, archive, "the tree archived")
		equal(flower.Parent, fill, "decor stays"); equal(far.Parent, fill, "west of the corridor stays")
		equal(north.Parent, fill, "north of the corridor stays"); equal(step.Parent, fill, "a walkable floor stays")
		equal(floor.Parent, ground, "Ground is never walked")
		local C = Park.GATE_CORRIDOR
		equal(C.minX, 896); equal(C.maxX, 932); equal(C.minZ, -17); equal(C.maxZ, 11)
		biome:Destroy(); archive:Destroy()
	end)

	case("KP9: every builder refuses a parent inside SistemaSonriente", function()
		local sonriente = Instance.new("Folder")
		sonriente.Name = "SistemaSonriente"
		local inner = Instance.new("Folder")
		inner.Parent = sonriente
		equal((pcall(Park.build, inner, Layout, East)), false, "build refuses")
		equal((pcall(Park.syncNests, inner)), false, "syncNests refuses")
		equal((pcall(Park.buildGround, inner)), false, "buildGround refuses (PGM-D2)")
		equal((pcall(Park.archiveAnnex, inner, nil, Layout, East, true)), false, "archiveAnnex refuses")
		equal((pcall(Park.clearGate, inner, nil, true)), false, "clearGate refuses")
		-- Deliberately changed (GL-D5, GL-D14): the two new entry points refuse it too
		equal((pcall(Park.buildEdge, inner)), false, "buildEdge refuses (GL-D5)")
		equal((pcall(Park.strays, inner, Layout, East)), false, "strays refuses (GL-D14)")
		equal(#inner:GetChildren(), 0, "nothing laid there")
		-- nor archives into it
		local biome = Instance.new("Model")
		local fill = Instance.new("Folder")
		fill.Name = "EdgeFill"
		fill.Parent = biome
		local rock = piece(fill, "Rock", 920, -3)
		equal((pcall(Park.clearGate, biome, inner, false)), false, "no archive inside SistemaSonriente")
		equal(rock.Parent, fill, "nothing moved")
		biome:Destroy(); sonriente:Destroy()
	end)

	case("KP10: every recipe: the Appendix B part count, unique names, primitive shapes, Sphere meshes, valid roles and materials", function()
		local kinds = {}
		for _, kind in ipairs(Park.KINDS) do kinds[kind] = true end
		for kind, n in pairs(EXPECT) do
			assert(kinds[kind], "kind " .. kind)
			local list = Park.recipe(kind)
			equal(#list, n, kind .. " parts")
			local names = {}
			for _, spec in ipairs(list) do
				local label = kind .. "." .. tostring(spec.name)
				assert(type(spec.name) == "string" and not names[spec.name], label .. " unique name")
				names[spec.name] = true
				assert(SHAPES[spec.shape], label .. " shape " .. tostring(spec.shape))
				assert(spec.mesh == nil or spec.mesh == "Sphere", label .. " mesh")
				assert(ROLES[spec.role], label .. " role")
				assert(#spec.size == 3 and spec.size[1] > 0 and spec.size[2] > 0 and spec.size[3] > 0, label .. " size")
				assert(#spec.offset == 6, label .. " offset")
				assert(#spec.color == 3, label .. " colour")
				local ok, m = pcall(function() return Enum.Material[spec.material] end)
				assert(ok and m, label .. " material " .. tostring(spec.material))
				if spec.shape == "Ball" then
					assert(spec.size[1] == spec.size[2] and spec.size[2] == spec.size[3], label .. " a round ball")
				elseif spec.shape == "Cylinder" then
					equal(spec.size[2], spec.size[3], label .. " a round cylinder")
				end
			end
		end
		for kind in pairs(kinds) do assert(EXPECT[kind], "an unchecked kind " .. kind) end
		-- K-D18 composition: buildings 310, toy park 98, toys 160 (no laptop), trees 208, lanterns 130, scatter 136
		equal(EXPECT.cafe + EXPECT.bakery + EXPECT.potter + EXPECT.fishshop + EXPECT.takoyaki + EXPECT.taiyaki + EXPECT.castle
			+ EXPECT.tower, KD18.Village, "village")
		equal(EXPECT.scratchCastle + EXPECT.scratchTree + EXPECT.boxTower, KD18.ToyPark, "toy park")
		equal(7 * EXPECT.yarn + 7 * EXPECT.yarnSmall + EXPECT.rollStand + EXPECT.rollLying + EXPECT.kitchen + EXPECT.tunnel
			+ 2 * EXPECT.tube + EXPECT.bundle + 3 * EXPECT.swab + EXPECT.swabCup + EXPECT.swabCross + 6 * EXPECT.paperBall
			+ EXPECT.sheet + EXPECT.tent + EXPECT.notebook + 2 * EXPECT.paperBag + 2 * EXPECT.plasticBag + EXPECT.giantBag,
			KD18.Toys, "toys")
		equal(8 * EXPECT.chest, KD18.Chests, "chests")
		equal(18 * EXPECT.treeL + 19 * EXPECT.treeS + 12 * EXPECT.bush, KD18.Trees, "trees")
		equal(26 * EXPECT.lanternShort, KD18.Lanterns, "lanterns")
		equal(16 * EXPECT.patch + 24 * EXPECT.flower + 24 * EXPECT.tuft, KD18.Scatter, "scatter")
		-- the chest: only its base collides; the lid opens toward the front (the nest)
		local solid = 0
		for _, spec in ipairs(Park.recipe("chest")) do
			if spec.role ~= "decor" then solid += 1; equal(spec.name, "Base", "only the base is solid") end
		end
		equal(solid, 1, "one solid part")
		-- a pure function: a fresh table every call
		assert(Park.recipe("cafe") ~= Park.recipe("cafe"), "a fresh table")
		equal((pcall(Park.recipe, "laptop")), false, "no laptop (K-D18)")
	end)

	case("KP11 wiring: the one-shot tool follows the v8 harness and the plan's nine steps", function()
		local tool = sources.build
		has(tool, "local DRY_RUN = true", "a dry run first")
		has(tool, 'assert(not RunService:IsRunning(), "Edit mode only: stop Play first")', "Edit mode only")
		has(tool, 'local MARK, NEEDS = "KittenPark", "CaramelV8"', "needs v8, marks KittenPark")
		has(tool, "bioma:GetAttribute(NEEDS) ~= nil", "refuses a map without CaramelV8")
		has(tool, "eastRoot:GetAttribute(MARK) ~= nil", "returns early on a marked map")
		has(tool, '"KittenParkBackup"', "the backup"); has(tool, '"KittenGate"', "the corridor archive")
		has(tool, '"KittenParkAnnex"', "the annex archive"); has(tool, '"WildboundMapArchive"', "under WildboundMapArchive")
		has(tool, "East.build(Workspace, Layout)", "the gate split and the green floor")
		has(tool, "Park.clearGate(bioma, folder(GATE_ARCHIVE), false)", "the corridor")
		has(tool, "Park.archiveAnnex(annex, folder(ANNEX_ARCHIVE), Layout, East, false)", "the annex")
		has(tool, "Park.build(root, Layout, East)", "the park"); has(tool, "Park.syncNests(root)", "the nests")
		has(tool, "root:SetAttribute(MARK, 1)", "the mark")
		has(tool, 'ChangeHistoryService:TryBeginRecording("KittenPark")', "one recording")
		has(tool, "task.delay(0.5, function()", "outside the caller's recording")
		has(tool, "Enum.FinishRecordingOperation.Cancel", "undone on a failure")
		has(tool, 'local SUMMARY_ATTRIBUTE = "WildboundKittenParkSummary"', "the JSON summary")
		has(tool, "partsBefore", "counts before"); has(tool, "partsAfter", "counts after")
		has(tool, '"SistemaSonriente"', "SistemaSonriente is never touched")
		local destroys = 0
		for _ in string.gmatch(tool, ":Destroy%(") do destroys += 1 end
		equal(destroys, 1, "one Destroy"); has(tool, "scratch:Destroy()", "the dry run's scratch model")
	end)

	case("KP12: buildGround lays the park's own floor once (PGM-D2, GL-D3): Ground.Floor 600 x 1200 Grass green, top 0.5, at (297, 937)", function()
		-- Deliberately changed (GL-D3): the floor covers the whole arm, 600 x 1200 at (297, 937) (was 520 x 520 at
		-- (282, 600)), FLOOR.size[1] is the arm's width (was 2 * HALF); Ground holds the Floor and the Approach, so the
		-- first call makes 3 (was 2); syncNests stands 16 nests on it (was 8)
		equal(Park.GROUND_FOLDER, "Ground", "the ground folder")
		equal(Park.FLOOR.size[1], Area.ARM.maxX - Area.ARM.minX, "600 across"); equal(Park.FLOOR.material, "Grass", "the K-D15 grass")
		equal(Park.FLOOR.size[3], Area.ARM.maxZ - Area.ARM.minZ, "1200 long")
		near(Park.FLOOR.centre.x, 297, "FLOOR.centre x"); near(Park.FLOOR.centre.z, 937, "FLOOR.centre z")
		local root = Instance.new("Model")
		root.Name = "GroundTest"
		local first = Park.buildGround(root)
		equal(first.created, 3, "the Ground folder, its Floor and the Approach made"); equal(first.changed, 0, "nothing changed the first time")
		local second = Park.buildGround(root)
		equal(second.created, 0, "nothing made the second time"); equal(second.changed, 0, "nothing changed the second time")
		local ground = root:FindFirstChild("Ground")
		assert(ground and ground:IsA("Folder"), "root.Ground is a Folder")
		equal(#ground:GetChildren(), 2, "the floor and the Approach")
		local floor = ground:FindFirstChild("Floor")
		assert(floor and floor:IsA("Part"), "Ground.Floor is a Part")
		near(floor.Size.X, 600, "size x"); near(floor.Size.Y, 1, "size y"); near(floor.Size.Z, 1200, "size z")
		near(floor.Position.Y + floor.Size.Y / 2, 0.5, "top at Area.FLOOR_TOP")
		near(floor.Position.X, 297, "centre x"); near(floor.Position.Z, 937, "centre z")
		local A = Area.ARM
		near(floor.Position.X - floor.Size.X / 2, A.minX, "the floor's west edge is the arm's"); near(floor.Position.X + floor.Size.X / 2, A.maxX, "east edge")
		near(floor.Position.Z - floor.Size.Z / 2, A.minZ, "gate-side edge"); near(floor.Position.Z + floor.Size.Z / 2, A.maxZ, "far edge")
		equal(floor.Material, Enum.Material.Grass, "Grass")
		near(floor.Color.R * 255, 140, "R", 0.6); near(floor.Color.G * 255, 201, "G", 0.6); near(floor.Color.B * 255, 107, "B", 0.6)
		equal(floor:GetAttribute("Role"), "floor", "role floor"); equal(floor.Anchored, true, "anchored")
		equal(floor.CanCollide, true, "collides"); equal(floor.CanQuery, true, "answers queries")
		equal(floor.CanTouch, false, "never touched"); equal(floor.CastShadow, true, "casts a shadow")
		-- a floor pushed off is set back, then nothing changes
		floor.CFrame = CFrame.new(0, 0, 0)
		floor.Material = Enum.Material.Plastic
		local fixed = Park.buildGround(root)
		assert(fixed.changed >= 2 and fixed.created == 0, "set back: " .. fixed.changed)
		near(floor.Position.X, 297, "back at x"); near(floor.Position.Z, 937, "back at z")
		equal(Park.buildGround(root).changed, 0, "settled")
		-- syncNests stands the nests on this floor
		equal(Park.syncNests(root), 16, "sixteen nests on the floor")
		for _, n in ipairs(Park.NESTS) do near(root.Nests["Nest_" .. n.id]:GetPivot().Y, 0.5, n.id .. " on the floor's top") end
		root:Destroy()
	end)

	local function byIdOf(plan)
		local out = {}
		for _, it in ipairs(plan.items) do out[it.id] = it end
		return out
	end
	local function idSet(list)
		local out = {}
		for _, d in ipairs(list) do out[d.id] = true end
		return out
	end

	case("GL-2: the garden's budget: GARDEN_BUDGET per folder and 1211 in all, its recipe composition, GARDEN_SEED 8728; K-D18 + garden = 2603", function()
		assert(table.isfrozen(Park.GARDEN_BUDGET), "frozen")
		local total = 0
		for _, folder in ipairs(Park.FOLDERS) do
			equal(Park.GARDEN_BUDGET[folder], GARDEN[folder], folder .. " garden budget")
			total += Park.GARDEN_BUDGET[folder]
		end
		equal(total, 1211, "the garden total")
		local kd = 0
		for _, n in pairs(Park.BUDGET) do kd += n end
		equal(kd + total, 2603, "the park folder before the drops")
		assert(kd + total <= Park.PART_CAP, "under PART_CAP")
		equal(Park.GARDEN_SEED, 8728, "GARDEN_SEED"); equal(Park.GARDEN_SEED, Park.SEED + Area.GROWTH, "SEED + GROWTH")
		-- GL-D7: M2 (8 strips, 7 joints, 123 slabs), the forks' 19 + 17 + 55 + 55 stones, four junction discs
		equal(8 * EXPECT.strip + 7 * EXPECT.joint + 123 * EXPECT.slab + (19 + 17 + 55 + 55) * EXPECT.stone + 4 * EXPECT.junction,
			GARDEN.Paths, "paths")
		equal(GARDEN.Gate, 0, "no second gate")
		-- GL-D8: a potter and a castle; a scratch tree, two box towers and a scratch castle
		equal(EXPECT.potter + EXPECT.castle, GARDEN.Village, "village")
		equal(EXPECT.scratchTree + 2 * EXPECT.boxTower + EXPECT.scratchCastle, GARDEN.ToyPark, "toy park")
		equal(10 * EXPECT.yarn + 14 * EXPECT.yarnSmall + 2 * EXPECT.rollStand + EXPECT.rollLying + EXPECT.kitchen + 2 * EXPECT.tunnel
			+ 3 * EXPECT.tube + 2 * EXPECT.bundle + 3 * EXPECT.swab + EXPECT.swabCup + 6 * EXPECT.paperBall + EXPECT.paperBag
			+ EXPECT.giantBag, GARDEN.Toys, "toys")
		equal(8 * EXPECT.chest, GARDEN.Chests, "chests K9..K16")
		equal(16 * EXPECT.treeL + 18 * EXPECT.treeS + 14 * EXPECT.bush, GARDEN.Trees, "trees")
		equal(7 * EXPECT.lanternTall + 14 * EXPECT.lanternShort, GARDEN.Lanterns, "lanterns")
		equal(14 * EXPECT.patch + 24 * EXPECT.flower + 24 * EXPECT.tuft, GARDEN.Scatter, "scatter")
		-- GL-D15: the edge and the root's cap
		equal(Park.EDGE_PARTS, 3 + 100 * EXPECT.hedge, "EDGE_PARTS: 3 walls and 100 hedge puffs"); equal(Park.EDGE_PARTS, 203)
		equal(Park.ROOT_CAP, Park.PART_CAP + Park.EDGE_PARTS + 2 + 16 * Park.NEST_PARTS, "ROOT_CAP"); equal(Park.ROOT_CAP, 3037)
	end)

	case("GL-3: the garden never moves the K-D half: plan(L, East, { garden = false }) lies in the full plan unchanged; same drops", function()
		local full = Park.plan(Layout, East)
		local bare = Park.plan(Layout, East, { garden = false })
		local byId = byIdOf(full)
		-- the four lit lanterns face M2's end only in the full plan
		local lit = { LanternShort_15 = true, LanternShort_16 = true, LanternShort_17 = true, LanternShort_18 = true }
		for _, it in ipairs(bare.items) do
			local other = byId[it.id]
			assert(other, it.id .. " is missing from the full plan")
			equal(other.kind, it.kind, it.id .. " kind"); equal(other.folder, it.folder, it.id .. " folder")
			near(other.x, it.x, it.id .. " x", 1e-9); near(other.z, it.z, it.id .. " z", 1e-9)
			equal(other.variant, it.variant, it.id .. " variant")
			if not lit[it.id] then near(other.yaw, it.yaw, it.id .. " yaw", 1e-9) end
		end
		local a, b = idSet(bare.dropped), idSet(full.dropped)
		for id in pairs(a) do assert(b[id], id .. " is dropped only without the garden") end
		for id in pairs(b) do assert(a[id], id .. " is dropped only with the garden") end
		equal(#bare.paths, 7, "the K-D paths only"); equal(#full.paths, 12, "and the five garden paths")
		for i = 1, #bare.paths do equal(full.paths[i].id, bare.paths[i].id, "the K-D path " .. i .. " comes first") end
	end)

	case("GL-4: the far-end goal: TowerPlaza, the Torre Gato Vigía and its four lit lanterns moved +600; M2 ends at (282, 1400)", function()
		local plan = Park.plan(Layout, East)
		local byId = byIdOf(plan)
		for id, p in pairs({ Junction_TowerPlaza = { 282, 1415 }, TorreGatoVigia = { 282, 1420 }, LanternShort_15 = { 262, 1395 },
			LanternShort_16 = { 302, 1395 }, LanternShort_17 = { 262, 1435 }, LanternShort_18 = { 302, 1435 } }) do
			local it = byId[id]
			assert(it, id .. " kept")
			near(it.x, p[1], id .. " x"); near(it.z, p[2], id .. " z")
		end
		equal(byId.Junction_TowerPlaza.variant, 50, "the plaza keeps d 50")
		near(byId.TorreGatoVigia.yaw, 0, "the tower keeps its local yaw 90")
		for i = 15, 18 do equal(byId["LanternShort_" .. i].variant, "light", "LanternShort_" .. i .. " lit") end
		local m2 = nil
		for _, path in ipairs(plan.paths) do
			if path.id == "M2" then m2 = path end
		end
		assert(m2 and m2.main == true and m2.width == 12, "M2, the main path's continuation, 12 wide")
		local last = m2.points[#m2.points]
		near(last.x, 282, "M2's end x"); near(last.z, 1400, "M2's end z")
		local m = plan.paths[1]
		local mEnd = m.points[#m.points]
		near(m2.points[1].x, mEnd.x, "M2 starts where M ends (x)"); near(m2.points[1].z, mEnd.z, "M2 starts where M ends (z)")
		near(flat(byId.TorreGatoVigia.x, byId.TorreGatoVigia.z, last.x, last.z), 20, "the tower 20 from M2's end")
		-- the seam where TowerPlaza was is covered by PuertaJardin
		local seam = byId.Junction_PuertaJardin
		assert(seam, "PuertaJardin kept")
		near(seam.x, 282, "PuertaJardin x"); near(seam.z, 790, "PuertaJardin z"); equal(seam.variant, 24, "PuertaJardin d")
		-- the lit lanterns face their nearest point of M2 (their front toward it)
		for i = 15, 18 do
			local it = byId["LanternShort_" .. i]
			local _, px, pz = Park.pathDistance(m2, it.x, it.z)
			near(it.yaw, Park.yawToward(it.x, it.z, px, pz), "LanternShort_" .. i .. " faces M2", 1e-3)
		end
	end)

	case("GL-5: nests K9..K16 at their GL-D10 points; Rara deeper than Comun, Epica deeper than Rara, every Epica in the garden", function()
		-- { rarity, nest x, z, post x, z, chest x, z } (world)
		local want = {
			K9 = { "Rara", 204, 900, 216, 900, 197, 900 }, K10 = { "Rara", 362, 960, 350, 960, 369, 960 },
			K11 = { "Rara", 192, 1020, 204, 1020, 185, 1020 }, K12 = { "Epica", 377, 1070, 365, 1070, 384, 1070 },
			K13 = { "Epica", 197, 1160, 209, 1160, 190, 1160 }, K14 = { "Epica", 362, 1200, 350, 1200, 369, 1200 },
			K15 = { "Epica", 202, 1280, 214, 1280, 195, 1280 }, K16 = { "Epica", 357, 1330, 345, 1330, 364, 1330 },
		}
		local byId = {}
		for _, n in ipairs(Park.NESTS) do byId[n.id] = n end
		for id, w in pairs(want) do
			local n = byId[id]
			assert(n, id .. " exists")
			equal(n.rarity, w[1], id .. " rarity")
			near(n.x, w[2], id .. " x"); near(n.z, w[3], id .. " z")
			near(n.post.x, w[4], id .. " post x"); near(n.post.z, w[5], id .. " post z")
			near(n.chest.x, w[6], id .. " chest x"); near(n.chest.z, w[7], id .. " chest z")
			equal(n.post.key, "kittenPost" .. id, id .. " post key")
		end
		-- the four re-flagged K-D nests (in place)
		for id, rarity in pairs({ K4 = "Comun", K5 = "Comun", K7 = "Rara", K8 = "Rara" }) do equal(byId[id].rarity, rarity, id .. " re-flagged") end
		near(byId.K7.x, 402, "K7 stays x"); near(byId.K7.z, 750, "K7 stays z")
		local deepest = { Comun = -math.huge, Rara = -math.huge, Epica = -math.huge }
		local shallowest = { Comun = math.huge, Rara = math.huge, Epica = math.huge }
		for _, n in ipairs(Park.NESTS) do
			assert(deepest[n.rarity], n.id .. " rarity " .. tostring(n.rarity))
			deepest[n.rarity] = math.max(deepest[n.rarity], n.lx)
			shallowest[n.rarity] = math.min(shallowest[n.rarity], n.lx)
		end
		assert(shallowest.Rara > deepest.Comun, "every Rara deeper than every Comun")
		assert(shallowest.Epica > deepest.Rara, "every Epica deeper than every Rara")
		assert(shallowest.Epica >= 260, "every Epica in the garden (local x >= 260)")
	end)

	case("GL-6: no garden row is dropped; M2 has 8 strips, 7 joints and 123 slabs; GN 19, GS 17, GT 55, GV 55 stones", function()
		local full = Park.plan(Layout, East)
		local bare = Park.plan(Layout, East, { garden = false })
		local bareIds = idSet(bare.items)
		for _, d in ipairs(bare.dropped) do bareIds[d.id] = true end
		for _, d in ipairs(full.dropped) do assert(bareIds[d.id], "the garden's " .. d.id .. " is dropped: " .. d.reason) end
		local count, gardenItems, gardenParts = {}, 0, 0
		for _, it in ipairs(full.items) do
			if not bareIds[it.id] then
				gardenItems += 1
				gardenParts += EXPECT[it.kind]
			end
			local prefix = string.match(it.id, "^(Path_%w+_%a+)%d+$")
			if prefix then count[prefix] = (count[prefix] or 0) + 1 end
		end
		-- 288 path pieces, 6 buildings, 47 toys, 48 trees and bushes, 21 lanterns, 62 scatter items
		equal(gardenItems, 472, "garden items kept")
		equal(gardenParts, 1211 - GARDEN.Chests, "garden parts (its chests come with the nests)")
		equal(full.parts - bare.parts, 1211 - GARDEN.Chests, "the garden adds its parts, nothing else changes")
		equal(count.Path_M2_Strip, 8, "M2 strips"); equal(count.Path_M2_Joint, 7, "M2 joints"); equal(count.Path_M2_Slab, 123, "M2 slabs")
		equal(count.Path_GN_Stone, 19, "GN stones"); equal(count.Path_GS_Stone, 17, "GS stones")
		equal(count.Path_GT_Stone, 55, "GT stones"); equal(count.Path_GV_Stone, 55, "GV stones")
		equal(count.Path_M_Slab, 89, "M keeps its 89 slabs")
		-- R7: the drops are the K-D ones (TreeL_01 and the K-D scatter, 14 parts) and nothing else
		local droppedParts = 0
		for _, d in ipairs(full.dropped) do droppedParts += d.parts end
		equal(droppedParts, 14, "the K-D drops"); equal(full.parts, 2589, "the park folder planned")
	end)

	case("GL-7: the second portal PORTAL2 = world(775, 55) = (227, 1375), at least 85 from every post", function()
		assert(table.isfrozen(Park.PORTAL2), "frozen")
		local x, z = Area.world(775, 55)
		near(Park.PORTAL2.x, x, "x from the frame"); near(Park.PORTAL2.z, z, "z from the frame")
		near(Park.PORTAL2.x, 227, "x"); near(Park.PORTAL2.z, 1375, "z")
		near(Park.PORTAL2.lx, 775, "lx"); near(Park.PORTAL2.lz, 55, "lz")
		for _, n in ipairs(Park.NESTS) do
			local d = flat(Park.PORTAL2.x, Park.PORTAL2.z, n.post.x, n.post.z)
			assert(d >= 85, ("post %s is %.1f from the second portal"):format(n.post.key, d))
		end
	end)

	case("GL-8: edgePlan and buildEdge: three invisible solid walls, 100 hedge puffs on the margins; idempotent; a moved wall set back", function()
		equal(Park.EDGE.folder, "Edge"); equal(Park.EDGE.wall, 4); equal(Park.EDGE.height, 80); equal(Park.EDGE.wallFromZ, 937)
		local edge = Park.edgePlan()
		equal(#edge.walls, 3, "three walls")
		-- { centre x, centre z, size x, size z } (world)
		local WALLS = { SideWallWest = { -5, 1239, 4, 604 }, SideWallEast = { 599, 1239, 4, 604 }, EndWall = { 297, 1539, 608, 4 } }
		for _, w in ipairs(edge.walls) do
			local want = WALLS[w.name]
			assert(want, "a known wall: " .. tostring(w.name))
			near(w.x, want[1], w.name .. " x"); near(w.z, want[2], w.name .. " z")
			near(w.size[1], want[3], w.name .. " size x"); near(w.size[2], 80, w.name .. " height"); near(w.size[3], want[4], w.name .. " size z")
			equal(w.role, "solid", w.name .. " role"); equal(w.transparency, 1, w.name .. " invisible")
			equal(w.castShadow, false, w.name .. " no shadow"); equal(w.material, "SmoothPlastic", w.name .. " material")
		end
		equal(#edge.hedge, 100, "100 hedge puffs")
		local rows = { W = 0, E = 0, S = 0 }
		local A, r = Area.ARM, Area.rect()
		local ids = {}
		for _, it in ipairs(edge.hedge) do
			equal(it.kind, "hedge", it.id .. " kind")
			assert(not ids[it.id], "duplicate " .. it.id); ids[it.id] = true
			local row, digits = string.match(it.id, "^Hedge_(%u)(%d%d)$")
			assert(row and rows[row], it.id .. " is in a known row")
			rows[row] += 1
			local k = tonumber(digits)
			if row == "S" then
				near(it.z, 1533, it.id .. " z"); near(it.x, 282 - (277 - 29.2 * (k - 0.5)), it.id .. " x")
				near(it.variant, 33.2, it.id .. " length"); near(it.yaw, 0, it.id .. " yaw")
			else
				near(it.x, row == "W" and 1 or 593, it.id .. " x"); near(it.z, 600 - 256 + 29.75 * (k - 0.5), it.id .. " z")
				near(it.variant, 33.75, it.id .. " length"); near(it.yaw, -90, it.id .. " yaw")
			end
			assert(it.x >= A.minX and it.x <= A.maxX and it.z >= A.minZ and it.z <= A.maxZ, it.id .. " inside the arm")
			assert(not (it.x >= r.minX and it.x <= r.maxX and it.z >= r.minZ and it.z <= r.maxZ), it.id .. " outside the space")
		end
		equal(rows.W, 40, "west row"); equal(rows.E, 40, "east row"); equal(rows.S, 20, "far-end row")
		-- the build, twice
		local root = Instance.new("Model")
		root.Name = "EdgeTest"
		local first = Park.buildEdge(root)
		assert(first.created >= Park.EDGE_PARTS, "made the edge: " .. first.created)
		equal(first.parts, Park.EDGE_PARTS, "report.parts")
		local second = Park.buildEdge(root)
		equal(second.created, 0, "nothing made the second time"); equal(second.changed, 0, "nothing changed the second time")
		local folder = root:FindFirstChild(Park.EDGE.folder)
		assert(folder and folder:IsA("Folder"), "root.Edge is a Folder")
		local parts = 0
		for _, d in ipairs(folder:GetDescendants()) do
			assert(not d:IsA("MeshPart") and not d:IsA("Decal") and not d:IsA("Texture"), "primitives only: " .. d:GetFullName())
			if d:IsA("BasePart") then
				parts += 1
				equal(d.Anchored, true, d.Name .. " anchored"); equal(d.CanTouch, false, d.Name .. " never touched")
			end
		end
		equal(parts, 203, "203 BaseParts under Edge")
		local walls = folder:FindFirstChild("Walls")
		assert(walls, "Edge.Walls")
		for name, want in pairs(WALLS) do
			local part = walls:FindFirstChild(name)
			assert(part and part:IsA("Part"), "Edge.Walls." .. name)
			near(part.Position.X, want[1], name .. " x"); near(part.Position.Y, 40.5, name .. " y"); near(part.Position.Z, want[2], name .. " z")
			near(part.Size.X, want[3], name .. " size x"); near(part.Size.Y, 80, name .. " size y"); near(part.Size.Z, want[4], name .. " size z")
			near(part.Transparency, 1, name .. " invisible")
			equal(part.CanCollide, true, name .. " solid"); equal(part.CanQuery, true, name .. " answers queries")
			equal(part.CastShadow, false, name .. " casts no shadow"); equal(part:GetAttribute("Role"), "solid", name .. " role")
			equal(part.Material, Enum.Material.SmoothPlastic, name .. " material")
		end
		local hedge = folder:FindFirstChild("Hedge")
		assert(hedge, "Edge.Hedge")
		equal(#hedge:GetChildren(), 100, "100 hedge models")
		for _, m in ipairs(hedge:GetChildren()) do
			assert(m:IsA("Model"), m.Name .. " is a Model")
			equal(m:GetAttribute("Kind"), "hedge", m.Name .. " kind")
			local n = 0
			for _, p in ipairs(m:GetChildren()) do
				if p:IsA("BasePart") then
					n += 1
					equal(p:GetAttribute("Role"), "decor", m.Name .. "." .. p.Name .. " decor")
					equal(p.CanCollide, false, m.Name .. "." .. p.Name .. " never collides")
				end
			end
			equal(n, EXPECT.hedge, m.Name .. " parts")
		end
		-- a wall pushed off and shown is set back, then nothing changes
		local west = walls.SideWallWest
		local was = west.CFrame
		west.CFrame = was + Vector3.new(0, 0, 10)
		west.Transparency = 0
		local fixed = Park.buildEdge(root)
		assert(fixed.changed >= 2 and fixed.created == 0, "set back: " .. fixed.changed)
		assert(west.CFrame:FuzzyEq(was, 1e-4) and west.Transparency == 1, "the west wall is back")
		equal(Park.buildEdge(root).changed, 0, "settled")
		root:Destroy()
	end)

	case("GL-9: strays lists every Model or BasePart in a Park folder that the plan does not keep there; planned items are not listed", function()
		local root = Instance.new("Model")
		root.Name = "StraysTest"
		equal(#Park.strays(root, Layout, East), 0, "no Park folder, no strays")
		local park = Instance.new("Folder")
		park.Name = Park.FOLDER
		park.Parent = root
		local function folder(name)
			local f = Instance.new("Folder")
			f.Name = name
			f.Parent = park
			return f
		end
		local function model(parent, name)
			local m = Instance.new("Model")
			m.Name = name
			m.Parent = parent
			return m
		end
		local toys, trees = folder("Toys"), folder("Trees")
		local junk = piece(toys, "Junk", 300, 900) -- unknown
		model(toys, "Yarn_Rainbow") -- a kept K-D toy
		model(toys, "Yarn_G1") -- a kept garden toy
		local cafe = model(toys, "CafeCat") -- kept, but in the Village
		local tree = model(trees, "TreeL_01") -- a K-D drop (the portal's clear disc)
		model(trees, "TreeL_02") -- kept
		model(trees, "TreeL_G01") -- kept (garden)
		local loose = Instance.new("Folder")
		loose.Name = "Loose"
		loose.Parent = toys -- not a Model or a BasePart: never listed
		model(toys, Park.FORBIDDEN) -- never listed, so never archived
		local list = Park.strays(root, Layout, East)
		equal(#list, 3, "three strays")
		equal(list[1].path, "Toys.CafeCat"); equal(list[2].path, "Toys.Junk"); equal(list[3].path, "Trees.TreeL_01")
		equal(list[1].instance, cafe); equal(list[2].instance, junk); equal(list[3].instance, tree)
		equal(junk.Parent, toys, "strays moves nothing"); equal(tree.Parent, trees, "strays moves nothing")
		root:Destroy()
	end)

	case("GL-10: buildGround lays Ground.Approach, 20 x 1 x 13 at (282, 0, 330.5), top 0.5, role floor, from the road's end to the arm", function()
		local P = Park.APPROACH
		assert(table.isfrozen(P), "frozen")
		equal(P.minX, 272); equal(P.maxX, 292); equal(P.minZ, 324); equal(P.maxZ, 337)
		equal(P.maxZ, Area.ARM.minZ, "it meets the arm's gate side")
		local root = Instance.new("Model")
		root.Name = "ApproachTest"
		Park.buildGround(root)
		local part = root.Ground:FindFirstChild("Approach")
		assert(part and part:IsA("Part"), "Ground.Approach is a Part")
		near(part.Size.X, 20, "size x"); near(part.Size.Y, 1, "size y"); near(part.Size.Z, 13, "size z")
		near(part.Position.X, 282, "x"); near(part.Position.Y, 0, "y"); near(part.Position.Z, 330.5, "z")
		near(part.Position.Y + part.Size.Y / 2, 0.5, "top at Area.FLOOR_TOP")
		equal(part:GetAttribute("Role"), "floor", "role floor"); equal(part.Anchored, true, "anchored")
		equal(part.CanCollide, true, "collides"); equal(part.CanQuery, true, "answers queries")
		equal(part.CanTouch, false, "never touched"); equal(part.CastShadow, true, "casts a shadow")
		equal(part.Material, Enum.Material.Grass, "Grass")
		near(part.Color.G * 255, 201, "the park grass", 0.6)
		root:Destroy()
	end)

	if scratch then scratch.root:Destroy() end
	return result
end

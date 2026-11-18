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
	-- Appendix B: parts per recipe
	local EXPECT = {
		strip = 1, joint = 1, junction = 1, slab = 1, stone = 1, arch = 8,
		cafe = 38, bakery = 34, potter = 40, fishshop = 36, takoyaki = 39, taiyaki = 33, castle = 53, tower = 37,
		scratchCastle = 44, scratchTree = 33, boxTower = 21,
		yarn = 7, yarnSmall = 2, rollStand = 4, rollLying = 4, kitchen = 5, tunnel = 7, tube = 3, bundle = 4,
		swab = 3, swabCup = 10, swabCross = 6, paperBall = 2, sheet = 1, tent = 2, notebook = 4,
		paperBag = 6, plasticBag = 3, giantBag = 5, chest = 11,
		treeL = 6, treeS = 4, bush = 2, lanternTall = 5, lanternShort = 5, patch = 1, flower = 3, tuft = 2,
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
		equal(Park.VERSION, 1); equal(Park.ROOT_NAME, "PuebloGatito_v1"); equal(Park.ROOT_NAME, Area.ROOT_NAME, "one root")
		equal(Park.FOLDER, "Park"); equal(Park.NESTS_FOLDER, "Nests"); equal(Park.FORBIDDEN, "SistemaSonriente")
		equal(Park.SEED, 8128); equal(Park.PART_CAP, 1400); equal(Park.NEST_PARTS, 2)
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
		near(plan.space.minX, 22, "space minX"); near(plan.space.maxX, 542, "space maxX")
		near(plan.space.minZ, 340, "space minZ"); near(plan.space.maxZ, 860, "space maxZ")
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

	case("KP2: eight nests K1..K8, 3 Comun 3 Rara 2 Epica; posts 12 from their nests and 85 apart; chests 7 behind", function()
		equal(#Park.NESTS, 8, "eight nests")
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
			assert(plx >= -170 and plx <= 180 and math.abs(plz) <= 180, n.id .. " post inside the posts' band")
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
		equal(counts.Comun, 3, "Comun"); equal(counts.Rara, 3, "Rara"); equal(counts.Epica, 2, "Epica")
		for i = 1, #Park.NESTS do
			for j = i + 1, #Park.NESTS do
				local a, b = Park.NESTS[i].post, Park.NESTS[j].post
				assert(flat(a.x, a.z, b.x, b.z) >= 85, ("posts %s and %s are %.1f apart"):format(a.key, b.key, flat(a.x, a.z, b.x, b.z)))
			end
		end
		-- the K-D8 table: home guards for K1..K4, "<name>@<post>" for the east extra posts K5..K8
		local guards = { "GatitoGuerrero", "GatitaBouquet", "GatitoActually", "GatitoLanudo", "GatitoGuerrero@kittenPostK5",
			"GatitaBouquet@kittenPostK6", "GatitoActually@kittenPostK7", "GatitoLanudo@kittenPostK8" }
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

	case("KP4: per-folder counts are the K-D18 table minus the drops; the park stays under 1400, the nests at 16", function()
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
			equal(plan.budget[folder], n - droppedParts[folder], folder)
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
			"CastilloCarton", "TorreGatoVigia", "CastilloRascador", "ArbolRascador", "TorreDeCajas", "ArcoDeNubes" }) do
			assert(kept[id], id .. " kept")
		end
		for i = 1, 8 do assert(kept["Chest_K" .. i], "chest K" .. i) end
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
		-- the nests: 8 x 2
		local nestRoot = Instance.new("Model")
		Park.syncNests(nestRoot)
		local nests = 0
		for _, d in ipairs(nestRoot[Park.NESTS_FOLDER]:GetDescendants()) do if d:IsA("BasePart") then nests += 1 end end
		equal(nests, 16, "nest parts"); assert(nests <= 16, "nests at most 16")
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
		equal(lights, 12, "8 tall lanterns + 4 on the Tower Plaza")
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

	case("KP6: syncNests writes the eight Nest_K* markers with the full contract; idempotent; puts a moved nest back", function()
		local root = Instance.new("Model")
		root.Name = "NestTest"
		local nests = Instance.new("Folder")
		nests.Name = Park.NESTS_FOLDER
		nests.Parent = root
		local foreign = Instance.new("Model")
		foreign.Name = "Nest_Other"
		foreign:SetAttribute("NestId", "Z9")
		foreign.Parent = nests
		equal(Park.syncNests(root), 8, "eight nests made")
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
		local a = piece(props, "A", 1000, 0)
		local bModel = Instance.new("Model")
		bModel.Name = "B"
		piece(bModel, "Trunk", 1200, 100)
		bModel.WorldPivot = CFrame.new(1200, 2, 100)
		bModel.Parent = props
		local c = piece(props, "C", 900, 0) -- in the plot
		local d = piece(props, "D", 1000, -280) -- the annex's south strip
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

	case("KP12: buildGround lays the park's own floor once (PGM-D2): Ground.Floor 520 x 520 Grass green, top 0.5, at (282, 600)", function()
		equal(Park.GROUND_FOLDER, "Ground", "the ground folder")
		equal(Park.FLOOR.size[1], 2 * Area.HALF, "520 across"); equal(Park.FLOOR.material, "Grass", "the K-D15 grass")
		local root = Instance.new("Model")
		root.Name = "GroundTest"
		local first = Park.buildGround(root)
		equal(first.created, 2, "the Ground folder and its Floor made"); equal(first.changed, 0, "nothing changed the first time")
		local second = Park.buildGround(root)
		equal(second.created, 0, "nothing made the second time"); equal(second.changed, 0, "nothing changed the second time")
		local ground = root:FindFirstChild("Ground")
		assert(ground and ground:IsA("Folder"), "root.Ground is a Folder")
		equal(#ground:GetChildren(), 1, "one floor")
		local floor = ground:FindFirstChild("Floor")
		assert(floor and floor:IsA("Part"), "Ground.Floor is a Part")
		near(floor.Size.X, 520, "size x"); near(floor.Size.Y, 1, "size y"); near(floor.Size.Z, 520, "size z")
		near(floor.Position.Y + floor.Size.Y / 2, 0.5, "top at Area.FLOOR_TOP")
		near(floor.Position.X, 282, "centre x"); near(floor.Position.Z, 600, "centre z")
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
		near(floor.Position.X, 282, "back at x"); near(floor.Position.Z, 600, "back at z")
		equal(Park.buildGround(root).changed, 0, "settled")
		-- syncNests stands the nests on this floor
		equal(Park.syncNests(root), 8, "eight nests on the floor")
		for _, n in ipairs(Park.NESTS) do near(root.Nests["Nest_" .. n.id]:GetPivot().Y, 0.5, n.id .. " on the floor's top") end
		root:Destroy()
	end)

	if scratch then scratch.root:Destroy() end
	return result
end

-- Caramelo nests (odd/tasks/wildbound-caramelo.md, CE1): the Candy builder's nest markers become island nests of the one
-- island system (WildboundIsland, the server's nest slots, EggCarry, the 300 s wave refill), never a parallel one.
-- Server only and pure except `read`, which only reads the builder's markers. Each enabled, non-event marker
-- (Workspace.Candy_Bioma_v1.Nests.Nest_<id>, attributes NestId, Rarity, Enabled, EventOnly) becomes one island entry:
-- one egg (the pack's single-egg hollow), no sleeping parent (the Caramelo beasts guard the nests instead), the species
-- and reward tier of its rarity (POOL), and the guardian whose post stands beside it (bind). Decisions 23-27.
local Nests = {}

-- Decision 23 (pack 06_PROMPTS_CLAUDE/07 and 05_SISTEMAS/03: Gomibu Comun, Tortidragon Rara, Flanfuria Epica). The
-- legendary nest holds the best of the three, a Flanfuria. BP3 (balance pass 2026-11-15, simulator finding 4): the candy
-- nests have no sleeping parents, so they pay one reward tier under the random world's (SpawnClock.REWARD): Comun Safe
-- (4 Esencia), Rara Fog (10), Epica FogFar (16); they were Fog, FogFar and Territory. The event-only Legendaria keeps
-- Heart.
Nests.POOL = table.freeze({
	Comun = table.freeze({ species = "Gomibu", rewardTier = "Safe" }),
	Rara = table.freeze({ species = "Tortidragon", rewardTier = "Fog" }),
	Epica = table.freeze({ species = "Flanfuria", rewardTier = "FogFar" }),
	Legendaria = table.freeze({ species = "Flanfuria", rewardTier = "Heart" }),
})
-- BP3: the nest's risk tier (the island entry's `tier`: noise events, slot rules) stays what it was before the reward
-- moved down a tier, so only the pay changed.
Nests.RISK = table.freeze({ Comun = "Fog", Rara = "FogFar", Epica = "Territory", Legendaria = "Heart" })
-- The beasts that guard a candy nest from a post (WildboundPraderaSites.HOME), in a fixed order.
Nests.GUARDIANS = table.freeze({ "Gomibu", "Flanfuria", "Tortidragon" })
-- Decision 25: a post guards the nearest nest within BIND_RADIUS studs (each post at most one nest, each nest at most
-- one guardian). The posts stand 8 to 14 studs from their nests; the guardians wake within 40 and leash 16 to 35.
Nests.BIND_RADIUS = 20
Nests.EGGS = 1
Nests.ID_PREFIX = "Candy"
Nests.ROOT_NAME = "Candy_Bioma_v1"
-- K-D8, K-D9 (Pueblo Gatito, docs/design/wildbound-kitten-park-plan.md; owner request 2026-11-17, "es como el mundo de
-- gatito ... también tiene que haber huevos para robar"): the kitten park's eight nests K1..K8 live in the second
-- space's root (Workspace.Candy_Este_v1.Nests, laid by ServerStorage.WildboundKittenPark.syncNests). Their markers carry
-- Park = true and Guard (the kitten that guards them: "<name>" for a home post, "<name>@<post>" for an east extra post).
Nests.PARK_ROOT = "Candy_Este_v1"
-- K-D8: the same three species (no new egg art, pet or icon), paid one tier more than the plot's (the random world's
-- SpawnClock.REWARD) for the long walk home: Comun Fog (10), Rara FogFar (16), Epica Territory (24). No Legendaria: it
-- stays event-only, as in the plot. The risk tier stays Nests.RISK.
Nests.PARK_POOL = table.freeze({
	Comun = table.freeze({ species = "Gomibu", rewardTier = "Fog" }),
	Rara = table.freeze({ species = "Tortidragon", rewardTier = "FogFar" }),
	Epica = table.freeze({ species = "Flanfuria", rewardTier = "Territory" }),
})

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- The species, rarity, reward tier and risk tier of a nest of `rarity`, or nil for an unknown rarity.
-- K-D8: park (true for a kitten park nest) reads PARK_POOL instead, so a park Legendaria is unknown (nil).
function Nests.pick(rarity, park)
	local pool = park == true and Nests.PARK_POOL or Nests.POOL
	local row = type(rarity) == "string" and pool[rarity] or nil
	if not row then return nil end
	return { species = row.species, rarity = rarity, rewardTier = row.rewardTier, tier = Nests.RISK[rarity] }
end

-- The guardian posts in world coordinates, from WildboundPraderaSites: { { name, x, z } ... } in GUARDIANS order.
function Nests.posts(Sites)
	local list = {}
	if type(Sites) ~= "table" or type(Sites.HOME) ~= "table" or type(Sites.world) ~= "function" then return list end
	for _, name in ipairs(Nests.GUARDIANS) do
		local key = Sites.HOME[name]
		local site = key and Sites.world(nil, key)
		if site and finite(site.x) and finite(site.z) then table.insert(list, { name = name, x = site.x, z = site.z }) end
	end
	-- CH1 (owner request "more repeated creatures"): the guardians' extra posts (Sites.EXTRA_POSTS), after the home ones;
	-- each binds as "<name>@<post>" (guard), so a steal at its nest wakes that copy at its post.
	for _, extra in ipairs(type(Sites.EXTRA_POSTS) == "table" and Sites.EXTRA_POSTS or {}) do
		local site = table.find(Nests.GUARDIANS, extra.name) and Sites.world(nil, extra.key)
		if site and finite(site.x) and finite(site.z) then
			table.insert(list, { name = extra.name, x = site.x, z = site.z, guard = extra.name .. "@" .. extra.key })
		end
	end
	return list
end

-- { [nestId] = guardian name } for markers { { id, x, z } ... } and posts { { name, x, z } ... }.
function Nests.bind(markers, posts, radius)
	radius = finite(radius) and radius or Nests.BIND_RADIUS
	local binding, taken = {}, {}
	for _, post in ipairs(type(posts) == "table" and posts or {}) do
		local best, bestD = nil, math.huge
		for _, m in ipairs(type(markers) == "table" and markers or {}) do
			-- V4-D8: a house nest has no guardian post (a steal there raises the usual alarm only); V6-D4: nor has the
			-- lake island's nest
			if type(m) == "table" and type(m.id) == "string" and finite(m.x) and finite(m.z) and not taken[m.id]
				and m.island ~= true
				and m.house ~= true
				and m.park ~= true then -- K-D9: a park nest's guard is its own Guard attribute, never a plot post
				local d = math.sqrt((m.x - post.x) ^ 2 + (m.z - post.z) ^ 2)
				if d <= radius and d < bestD then best, bestD = m.id, d end
			end
		end
		if best then binding[best], taken[best] = post.guard or post.name, true end
	end
	return binding
end

-- The island entries for markers { { id, rarity, x, z, top, enabled, eventOnly } ... }: only enabled, non-event markers
-- of a known rarity, sorted by id.
-- K-D9: a park marker (park = true) pays from PARK_POOL, keeps its own guard (m.guard) and is marked park = true.
function Nests.islands(markers, posts)
	local kept = {}
	for _, m in ipairs(type(markers) == "table" and markers or {}) do
		if type(m) == "table" and m.enabled == true and m.eventOnly ~= true and type(m.id) == "string"
			and finite(m.x) and finite(m.z) and Nests.pick(m.rarity, m.park) then
			table.insert(kept, m)
		end
	end
	table.sort(kept, function(a, b) return a.id < b.id end)
	local binding = Nests.bind(kept, posts)
	local list = {}
	for _, m in ipairs(kept) do
		local park = m.park == true
		local pick = Nests.pick(m.rarity, park)
		table.insert(list, table.freeze({
			id = Nests.ID_PREFIX .. m.id, key = "caramelo_" .. string.lower(m.id), x = m.x, z = m.z,
			floorRadius = 6, zone = "outside", tier = pick.tier,
			rewardTier = pick.rewardTier, species = pick.species, rarity = pick.rarity, adults = 0,
			wakeDay = 12, wakeNight = 15, hideSpot = nil,
			adultPoints = table.freeze({}), content = "Egg", eggs = Nests.EGGS,
			biome = "Caramelo", nestId = m.id, nestTop = finite(m.top) and m.top or nil,
			guard = park and (type(m.guard) == "string" and m.guard or nil) or binding[m.id],
			park = park or nil,
		}))
	end
	return list
end

-- A copy of `layout` with the candy nests appended (an id already present is skipped); `layout` is never changed.
function Nests.merge(layout, markers, posts)
	local merged = {}
	if type(layout) == "table" then
		for key, value in pairs(layout) do merged[key] = value end
	end
	local list, present = {}, {}
	for _, entry in ipairs(type(merged.islands) == "table" and merged.islands or {}) do
		table.insert(list, entry)
		if type(entry) == "table" and entry.id then present[entry.id] = true end
	end
	for _, entry in ipairs(Nests.islands(markers, posts)) do
		if not present[entry.id] then table.insert(list, entry) end
	end
	merged.islands = list
	return merged
end

-- CG2 (F1, decision 48): the server's start step. It applies the layout's flags to the live biome through the builder's
-- own sync steps (Builder.syncNests, Builder.syncPortal: attributes only, no part moved), so a reopened or published
-- place has its nests and portal on without an Edit session. Each step is guarded: a missing Nests folder or Portal
-- model, or no builder, changes nothing. Returns how many nests and portals changed.
-- Caramelo v5 (V5-D1): HideSpots (the fifth argument, nil = ServerStorage.WildboundCandyHideSpots, false = none) lays
-- the candy kingdom's hiding places last, so they keep off the house nests too. A fifth value: the spots changed.
-- Caramelo v6 (V6-D1): Grass (the sixth argument, nil = ServerStorage.WildboundCandyGrass, false = none) lays the tall
-- licorice grass after the hide spots. A sixth value: the patches changed.
-- Caramelo v6 (V6-D5): Traps (the seventh argument, nil = ServerStorage.WildboundCandyTraps, false = none) lays the sticky
-- caramel puddles after the grass. A seventh value: the puddles changed.
-- Caramelo v6 (V6-D4): Island (the eighth argument, nil = ServerStorage.WildboundCandyIsland, false = none) lays the lake
-- island and its Epica nest after the traps, before the nests are read. An eighth value: the island's changes.
-- K-D9 (Pueblo Gatito): Park (the ninth argument, nil = ServerStorage.WildboundKittenPark, false = none) lays the kitten
-- park's nests (Park.syncNests) in the sibling root Candy_Este_v1 after the island, before the nests are read; an
-- unparented root or a missing sibling root calls nothing. A ninth value: the park nests changed.
function Nests.applyFlags(root, Builder, Layout, HouseNests, HideSpots, Grass, Traps, Island, Park)
	if typeof(root) ~= "Instance" or type(Builder) ~= "table" or type(Layout) ~= "table" then return 0, 0 end
	local okNests, nests = pcall(Builder.syncNests, root, Layout)
	local okPortal, portals = pcall(Builder.syncPortal, root, Layout)
	-- Caramelo v2 (CT1-CT3): the Gran Torta's tower (stair, turning tiers, summit nest) is added the same way, once,
	-- before the nests are read. A third value: the parts it added.
	local okTower, tower = false, 0
	if type(Builder.syncTower) == "function" then okTower, tower = pcall(Builder.syncTower, root, Layout) end
	-- V4-D8 (owner request 2026-11-17, "eggs inside the houses"): one nest inside each Caramelo v3 house, laid by
	-- WildboundCandyHouseNests from the live houses, before the nests are read. HouseNests: that module (nil = look it up
	-- in ServerStorage, FindFirstChild only; false = none). A fourth value: the house nests changed.
	local okHouse, house = false, 0
	local H = HouseNests
	if H == nil then
		local module = game:GetService("ServerStorage"):FindFirstChild("WildboundCandyHouseNests")
		if module and module:IsA("ModuleScript") then
			local okRequire, loaded = pcall(require, module)
			H = okRequire and loaded or nil
		end
	end
	if type(H) == "table" and type(H.sync) == "function" then okHouse, house = pcall(H.sync, root, Layout) end
	local okSpots, spots = false, 0
	local S = HideSpots
	if S == nil then
		local module = game:GetService("ServerStorage"):FindFirstChild("WildboundCandyHideSpots")
		if module and module:IsA("ModuleScript") then
			local okRequire, loaded = pcall(require, module)
			S = okRequire and loaded or nil
		end
	end
	if type(S) == "table" and type(S.sync) == "function" then okSpots, spots = pcall(S.sync, root, Layout) end
	-- Caramelo v6 (V6-D1): the tall licorice grass, after the hide spots (it keeps off them). Grass (the sixth argument,
	-- nil = ServerStorage.WildboundCandyGrass, false = none); a sixth value: the patches changed.
	local okGrass, grass = false, 0
	local G = Grass
	if G == nil then
		local module = game:GetService("ServerStorage"):FindFirstChild("WildboundCandyGrass")
		if module and module:IsA("ModuleScript") then
			local okRequire, loaded = pcall(require, module)
			G = okRequire and loaded or nil
		end
	end
	if type(G) == "table" and type(G.sync) == "function" then okGrass, grass = pcall(G.sync, root, Layout) end
	-- Caramelo v6 (V6-D5): the sticky caramel traps, after the grass (they keep off it and the hide spots). Traps (the
	-- seventh argument, nil = ServerStorage.WildboundCandyTraps, false = none); a seventh value: the puddles changed.
	local okTraps, traps = false, 0
	local T = Traps
	if T == nil then
		local module = game:GetService("ServerStorage"):FindFirstChild("WildboundCandyTraps")
		if module and module:IsA("ModuleScript") then
			local okRequire, loaded = pcall(require, module)
			T = okRequire and loaded or nil
		end
	end
	if type(T) == "table" and type(T.sync) == "function" then okTraps, traps = pcall(T.sync, root, Layout) end
	-- Caramelo v6 (V6-D4): the lake island and its Epica nest, after the traps and before the nests are read. Island (the
	-- eighth argument, nil = ServerStorage.WildboundCandyIsland, false = none); an eighth value: the island's changes.
	local okIsland, island = false, 0
	local I = Island
	if I == nil then
		local module = game:GetService("ServerStorage"):FindFirstChild("WildboundCandyIsland")
		if module and module:IsA("ModuleScript") then
			local okRequire, loaded = pcall(require, module)
			I = okRequire and loaded or nil
		end
	end
	if type(I) == "table" and type(I.sync) == "function" then okIsland, island = pcall(I.sync, root, Layout) end
	-- K-D9: the kitten park's nests, after the island (the sibling root only: a scratch root has no parent)
	local okPark, park = false, 0
	local parkRoot = root.Parent and root.Parent:FindFirstChild(Nests.PARK_ROOT)
	local P = Park
	if parkRoot and P == nil then
		local module = game:GetService("ServerStorage"):FindFirstChild("WildboundKittenPark")
		if module and module:IsA("ModuleScript") then
			local okRequire, loaded = pcall(require, module)
			P = okRequire and loaded or nil
		end
	end
	if parkRoot and type(P) == "table" and type(P.syncNests) == "function" then okPark, park = pcall(P.syncNests, parkRoot) end
	return okNests and tonumber(nests) or 0, okPortal and tonumber(portals) or 0, okTower and tonumber(tower) or 0,
		okHouse and tonumber(house) or 0, okSpots and tonumber(spots) or 0, okGrass and tonumber(grass) or 0,
		okTraps and tonumber(traps) or 0, okIsland and tonumber(island) or 0, okPark and tonumber(park) or 0
end

-- The builder's markers under `root` (the Candy_Bioma_v1 model): { { id, rarity, x, z, top, enabled, eventOnly } }.
-- K-D9 (Pueblo Gatito): when `root` is the live Candy_Bioma_v1 (named ROOT_NAME, parented), the kitten park's markers in
-- its sibling root (PARK_ROOT.Nests) are read too, each with park = true and guard (its Guard string attribute), so the
-- server's one read returns both roots. A scratch root has no parent and reads only itself.
local function readFolder(list, folder, park)
	for _, nest in ipairs(folder:GetChildren()) do
		local id = nest:GetAttribute("NestId")
		if nest:IsA("Model") and type(id) == "string" then
			local frame, size = nest:GetBoundingBox()
			local bowl = nest.PrimaryPart
			-- The bowl's top in the world, whichever axis its cylinder lies along.
			local top = frame.Position.Y + size.Y / 2
			if bowl then
				local c, s = bowl.CFrame, bowl.Size
				top = bowl.Position.Y + (math.abs(c.RightVector.Y) * s.X + math.abs(c.UpVector.Y) * s.Y
					+ math.abs(c.LookVector.Y) * s.Z) / 2
			end
			-- V4-D8: a house nest (WildboundCandyHouseNests, attribute House) is never bound to a creature post; V6-D4:
			-- nor is the lake island's nest (WildboundCandyIsland, attribute LakeIsland)
			table.insert(list, { id = id, rarity = nest:GetAttribute("Rarity"), x = frame.Position.X, z = frame.Position.Z,
				top = top, enabled = nest:GetAttribute("Enabled") == true, eventOnly = nest:GetAttribute("EventOnly") == true,
				house = nest:GetAttribute("House") == true,
				island = nest:GetAttribute("LakeIsland") == true,
				park = park,
				guard = park and type(nest:GetAttribute("Guard")) == "string" and nest:GetAttribute("Guard") or nil })
		end
	end
end
function Nests.read(root)
	local list = {}
	if typeof(root) ~= "Instance" then return list end
	local folder = root:FindFirstChild("Nests")
	if folder then readFolder(list, folder, false) end
	local parkRoot = root.Name == Nests.ROOT_NAME and root.Parent ~= nil and root.Parent:FindFirstChild(Nests.PARK_ROOT) or nil
	local parkFolder = parkRoot and parkRoot:FindFirstChild("Nests")
	if parkFolder then readFolder(list, parkFolder, true) end
	return list
end

return Nests

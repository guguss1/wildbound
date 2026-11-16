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

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- The species, rarity, reward tier and risk tier of a nest of `rarity`, or nil for an unknown rarity.
function Nests.pick(rarity)
	local row = type(rarity) == "string" and Nests.POOL[rarity] or nil
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
	return list
end

-- { [nestId] = guardian name } for markers { { id, x, z } ... } and posts { { name, x, z } ... }.
function Nests.bind(markers, posts, radius)
	radius = finite(radius) and radius or Nests.BIND_RADIUS
	local binding, taken = {}, {}
	for _, post in ipairs(type(posts) == "table" and posts or {}) do
		local best, bestD = nil, math.huge
		for _, m in ipairs(type(markers) == "table" and markers or {}) do
			if type(m) == "table" and type(m.id) == "string" and finite(m.x) and finite(m.z) and not taken[m.id] then
				local d = math.sqrt((m.x - post.x) ^ 2 + (m.z - post.z) ^ 2)
				if d <= radius and d < bestD then best, bestD = m.id, d end
			end
		end
		if best then binding[best], taken[best] = post.name, true end
	end
	return binding
end

-- The island entries for markers { { id, rarity, x, z, top, enabled, eventOnly } ... }: only enabled, non-event markers
-- of a known rarity, sorted by id.
function Nests.islands(markers, posts)
	local kept = {}
	for _, m in ipairs(type(markers) == "table" and markers or {}) do
		if type(m) == "table" and m.enabled == true and m.eventOnly ~= true and type(m.id) == "string"
			and finite(m.x) and finite(m.z) and Nests.pick(m.rarity) then
			table.insert(kept, m)
		end
	end
	table.sort(kept, function(a, b) return a.id < b.id end)
	local binding = Nests.bind(kept, posts)
	local list = {}
	for _, m in ipairs(kept) do
		local pick = Nests.pick(m.rarity)
		table.insert(list, table.freeze({
			id = Nests.ID_PREFIX .. m.id, key = "caramelo_" .. string.lower(m.id), x = m.x, z = m.z,
			floorRadius = 6, zone = "outside", tier = pick.tier,
			rewardTier = pick.rewardTier, species = pick.species, rarity = pick.rarity, adults = 0,
			wakeDay = 12, wakeNight = 15, hideSpot = nil,
			adultPoints = table.freeze({}), content = "Egg", eggs = Nests.EGGS,
			biome = "Caramelo", nestId = m.id, nestTop = finite(m.top) and m.top or nil, guard = binding[m.id],
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
function Nests.applyFlags(root, Builder, Layout)
	if typeof(root) ~= "Instance" or type(Builder) ~= "table" or type(Layout) ~= "table" then return 0, 0 end
	local okNests, nests = pcall(Builder.syncNests, root, Layout)
	local okPortal, portals = pcall(Builder.syncPortal, root, Layout)
	-- Caramelo v2 (CT1-CT3): the Gran Torta's tower (stair, turning tiers, summit nest) is added the same way, once,
	-- before the nests are read. A third value: the parts it added.
	local okTower, tower = false, 0
	if type(Builder.syncTower) == "function" then okTower, tower = pcall(Builder.syncTower, root, Layout) end
	return okNests and tonumber(nests) or 0, okPortal and tonumber(portals) or 0, okTower and tonumber(tower) or 0
end

-- The builder's markers under `root` (the Candy_Bioma_v1 model): { { id, rarity, x, z, top, enabled, eventOnly } }.
function Nests.read(root)
	local list = {}
	local folder = typeof(root) == "Instance" and root:FindFirstChild("Nests") or nil
	if not folder then return list end
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
			table.insert(list, { id = id, rarity = nest:GetAttribute("Rarity"), x = frame.Position.X, z = frame.Position.Z,
				top = top, enabled = nest:GetAttribute("Enabled") == true, eventOnly = nest:GetAttribute("EventOnly") == true })
		end
	end
	return list
end

return Nests

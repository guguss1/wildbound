-- Invoke with require(freshTestClone)(require(freshCandyNestsClone), require(freshCandyLayoutClone),
-- require(freshPraderaSitesClone), require(freshBeastConfigClone), require(freshIslandClone), require(freshSpeciesClone),
-- require(freshCandyBuilderClone), { server = WildboundServer.Source, text = require(freshTextClone),
-- beasts = WildboundBeasts.Source }).
-- CE1 (odd/tasks/wildbound-caramelo.md): the Caramelo nests are island nests with one egg of their rarity's species,
-- each guardian post bound to the nest beside it, refilled by the wave refresh, live through the builder's layout flag.
-- CG2: the server applies that flag itself at start (F1), and a guarded nest's steal wakes its guardian (F5).
-- Every fixture is built detached (never parented to a service).
return function(Nests, Layout, Sites, Config, Island, Species, Builder, sources)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "Expected " .. tostring(expected)
			.. ", got " .. tostring(actual))
	end
	local function has(source, needle, label)
		assert(type(source) == "string" and source:find(needle, 1, true), (label or needle) .. " missing")
	end
	local function flat(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
	-- The layout's nests as markers in world coordinates, live as the builder would set them.
	local function markers()
		local list = {}
		for _, spec in ipairs(Layout.NESTS) do
			local w = Layout.world(spec)
			table.insert(list, { id = spec.id, rarity = spec.rarity, x = w.x, z = w.z, top = 2.7,
				enabled = Builder.nestEnabled(spec, Layout), eventOnly = spec.eventOnly })
		end
		return list
	end

	case("CE1: each rarity holds its Caramelo species (Comun Gomibu, Rara Tortidragon, Epica and Legendaria Flanfuria)", function()
		-- Deliberately re-pinned (BP3, 2026-11-15, simulator finding 4): the unguarded candy nests pay one reward tier
		-- lower (Comun Safe 4, Rara Fog 10, Epica FogFar 16 Esencia; were Fog 10, FogFar 16, Territory 24). The event-only
		-- Legendaria nest keeps Heart. The nest's risk tier (noise, slot rules) is unchanged: Nests.RISK.
		local want = { Comun = { "Gomibu", "Safe", "Fog" }, Rara = { "Tortidragon", "Fog", "FogFar" },
			Epica = { "Flanfuria", "FogFar", "Territory" }, Legendaria = { "Flanfuria", "Heart", "Heart" } }
		for rarity, row in pairs(want) do
			local pick = Nests.pick(rarity)
			assert(pick, rarity)
			equal(pick.species, row[1], rarity .. " species"); equal(pick.rewardTier, row[2], rarity .. " reward")
			equal(pick.tier, row[3], rarity .. " risk tier"); equal(Nests.RISK[rarity], row[3], rarity .. " RISK")
			equal(pick.rarity, rarity, rarity .. " rarity")
		end
		equal(Nests.pick("Mitica"), nil, "unknown rarity"); equal(Nests.pick(nil), nil, "nil rarity")
		for _, name in ipairs(Nests.GUARDIANS) do
			local look = Species.LOOKS[name]
			assert(look, name .. " look")
			assert(Species.keepsOwn(name), name .. " keeps its own look")
			equal(Species.look(name).name, name, name .. " look while ONLY is " .. tostring(Species.ONLY))
			assert(type(look.tint) == "table", name .. " egg tint")
			assert(type(sources.text.CARD.species[name]) == "string", name .. " name")
		end
		equal(Species.LOOKS.Gomibu.rarity, "Comun"); equal(Species.LOOKS.Tortidragon.rarity, "Rara")
		equal(Species.LOOKS.Flanfuria.rarity, "Epica")
		equal(Species.look("Cortezon").name, "Lumipol", "the forest species keep the ONLY rule")
	end)

	case("CE1: each guardian's post is bound to the nest beside it, inside its wake radius and leash", function()
		local posts = Nests.posts(Sites)
		-- Deliberately changed (CH1, owner request "more repeated creatures"): each guardian also stands at one extra post
		-- (Sites.EXTRA_POSTS) beside a new nest, bound as "<name>@<post>" so a steal there wakes that copy (3 -> 6 posts).
		-- Deliberately changed again (GT2, owner request "more eggs and more creatures"): a second extra post per guardian
		-- beside a GT2 nest (6 -> 9 posts).
		equal(#posts, 9, "posts")
		local binding = Nests.bind(markers(), posts)
		local want = { C1 = "Gomibu", R1 = "Flanfuria", C3 = "Tortidragon", C7 = "Gomibu@candyPostC7",
			R6 = "Flanfuria@candyPostR6", C8 = "Tortidragon@candyPostC8", E3 = "Gomibu@candyPostE3",
			R8 = "Flanfuria@candyPostR8", R9 = "Tortidragon@candyPostR9" }
		local bound = 0
		for id, name in pairs(binding) do
			bound += 1
			equal(name, want[id], "guardian of " .. id)
		end
		equal(bound, 9, "bound nests")
		for _, post in ipairs(posts) do
			local nest
			for _, m in ipairs(markers()) do if binding[m.id] == (post.guard or post.name) then nest = m end end
			assert(nest, (post.guard or post.name) .. " guards no nest")
			local T = Config.BEASTS[post.name].tuning
			local d = flat(nest.x, nest.z, post.x, post.z)
			assert(d <= T.WakeRadiusStuds, post.name .. " wakes for a thief at its nest (" .. d .. ")")
			assert(d <= T.LeashStuds, post.name .. " reaches its nest on its leash (" .. d .. ")")
		end
	end)

	case("CE1: binding rules: a post too far binds nothing, and two posts never share a nest", function()
		local one = { { id = "A", x = 0, z = 0 } }
		local near = Nests.bind(one, { { name = "Gomibu", x = 5, z = 0 }, { name = "Flanfuria", x = 6, z = 0 } })
		equal(near.A, "Gomibu", "the first post takes the nest")
		local count = 0
		for _ in pairs(near) do count += 1 end
		equal(count, 1, "one nest, one guardian")
		local far = Nests.bind(one, { { name = "Gomibu", x = Nests.BIND_RADIUS + 1, z = 0 } })
		equal(far.A, nil, "out of the bind radius")
		local two = Nests.bind({ { id = "A", x = 0, z = 0 }, { id = "B", x = 10, z = 0 } }, { { name = "Gomibu", x = 9, z = 0 } })
		equal(two.B, "Gomibu", "the nearest nest"); equal(two.A, nil)
	end)

	case("CE1: the live nests become one-egg island nests with no sleeping parent; the event nest stays off", function()
		local list = Nests.islands(markers(), Nests.posts(Sites))
		equal(#list, #Layout.NESTS - 1, "every nest but L1")
		local seen = {}
		for i, entry in ipairs(list) do
			if i > 1 then assert(list[i - 1].id < entry.id, "sorted") end
			assert(not seen[entry.id], "unique " .. entry.id)
			seen[entry.id] = true
			equal(entry.id, "Candy" .. entry.nestId, "id")
			assert(entry.nestId ~= "L1", "the event-only nest is off")
			local pick = Nests.pick(entry.rarity)
			equal(entry.species, pick.species, entry.id .. " species"); equal(entry.rewardTier, pick.rewardTier)
			equal(entry.tier, Nests.RISK[entry.rarity], entry.id .. " keeps its risk tier (BP3)")
			equal(Island.nestCount(entry, 8), 1, entry.id .. " one egg, whatever the crowd")
			equal(Island.parentCount(entry), 0, entry.id .. " no sleeping parent")
			equal(Island.rollContent(entry, "Day", function() return 0.1 end), "Egg", entry.id .. " an egg")
			equal(entry.nestTop, 2.7, "the bowl top")
		end
		equal(seen.CandyC1 and list[1].id, "CandyC1")
		for _, entry in ipairs(list) do
			if entry.nestId == "C1" then equal(entry.guard, "Gomibu") end
			if entry.nestId == "R1" then equal(entry.guard, "Flanfuria") end
			if entry.nestId == "C3" then equal(entry.guard, "Tortidragon") end
			if entry.nestId == "R2" then equal(entry.guard, nil, "an unguarded nest") end
		end
		local off = Nests.islands({ { id = "Z", rarity = "Comun", x = 0, z = 0, enabled = false },
			{ id = "Y", rarity = "Mitica", x = 0, z = 0, enabled = true },
			{ id = "X", rarity = "Legendaria", x = 0, z = 0, enabled = true, eventOnly = true } }, {})
		equal(#off, 0, "disabled, unknown and event-only markers make no nest")
	end)

	case("CE1: merge appends after the forest islands, never changes the layout and never duplicates", function()
		local forest = table.freeze({ islands = table.freeze({ table.freeze({ id = "I1" }), table.freeze({ id = "T1" }) }),
			showCrest = "keep" })
		local merged = Nests.merge(forest, markers(), Nests.posts(Sites))
		equal(#forest.islands, 2, "the given layout is untouched")
		equal(merged.showCrest, "keep", "other fields kept")
		equal(merged.islands[1].id, "I1"); equal(merged.islands[2].id, "T1")
		equal(#merged.islands, 2 + #Layout.NESTS - 1, "candy nests appended")
		local again = Nests.merge(merged, markers(), Nests.posts(Sites))
		equal(#again.islands, #merged.islands, "a second merge adds nothing")
		equal(#Nests.merge(nil, {}, {}).islands, 0, "no layout, no markers")
	end)

	case("CE1: a taken Caramelo egg restocks at the wave refresh like a forest egg", function()
		local state, gen = { ["CandyC1:1"] = "wait_wave", ["CandyR1:1"] = "wait_wave", ["CandyE1:1"] = "Egg:7" }, {}
		local refilled, waiting = Island.waveRefill(state, gen, { CandyR1 = true })
		equal(#refilled, 1, "refilled"); equal(refilled[1], "CandyC1:1")
		equal(#waiting, 1, "waiting"); equal(waiting[1], "CandyR1:1")
		equal(state["CandyC1:1"], nil, "opened for ensureNests"); equal(state["CandyE1:1"], "Egg:7", "a lying egg stays")
	end)

	case("CE1: read takes the builder's markers, and the builder's layout flag turns them on", function()
		local root = Instance.new("Model")
		local folder = Instance.new("Folder")
		folder.Name, folder.Parent = "Nests", root
		for _, spec in ipairs(Layout.NESTS) do
			local nest = Instance.new("Model")
			nest.Name = "Nest_" .. spec.id
			local bowl = Instance.new("Part")
			bowl.Name, bowl.Shape, bowl.Size = "Collision_Bowl", Enum.PartType.Cylinder, Vector3.new(2.2, 5.3, 5.3)
			local w = Layout.world(spec)
			bowl.CFrame = CFrame.new(w.x, 1.6, w.z) * CFrame.Angles(0, 0, math.rad(90))
			bowl.Parent = nest
			nest.PrimaryPart = bowl
			nest:SetAttribute("NestId", spec.id); nest:SetAttribute("Rarity", spec.rarity)
			nest:SetAttribute("EventOnly", spec.eventOnly); nest:SetAttribute("Enabled", false)
			nest.Parent = folder
		end
		for _, m in ipairs(Nests.read(root)) do assert(not m.enabled, "off before the sync: " .. m.id) end
		equal(Builder.syncNests(root, Layout), #Layout.NESTS - 1, "changed nests")
		equal(Builder.syncNests(root, Layout), 0, "a second sync changes nothing")
		equal(root:GetAttribute("NestsEnabled"), true)
		local read = Nests.read(root)
		equal(#read, #Layout.NESTS, "every marker read")
		for _, m in ipairs(read) do
			local spec
			for _, s in ipairs(Layout.NESTS) do if s.id == m.id then spec = s end end
			equal(m.enabled, not spec.eventOnly, m.id .. " enabled")
			equal(m.rarity, spec.rarity, m.id .. " rarity")
			local w = Layout.world(spec)
			assert(math.abs(m.x - w.x) < 1e-3 and math.abs(m.z - w.z) < 1e-3, m.id .. " position")
			assert(math.abs(m.top - 2.7) < 1e-3, m.id .. " bowl top " .. m.top)
		end
		equal(#Nests.read(nil), 0, "no biome, no markers")
		root:Destroy()
	end)

	case("CE1: Don Glaseon still picks the carrier of the rarer Caramelo egg first", function()
		local home = Sites.world(nil, "bossHome")
		local function ctx(dx, rarity)
			return { alive = true, safe = false, meadow = true, x = home.x + dx, z = home.z, rarity = rarity }
		end
		local pick = Sites.bossPick({ { userId = 1, ctx = ctx(2, Nests.pick("Comun").rarity) },
			{ userId = 2, ctx = ctx(20, Nests.pick("Rara").rarity) } })
		equal(pick, 2, "the Tortidragon egg carrier, though farther")
	end)

	case("CE1: the server wires the candy nests into the one island list", function()
		local server = sources.server
		has(server, "CandyNests.merge(islandLayout, CandyNests.read(workspace:FindFirstChild(CandyNests.ROOT_NAME)),",
			"the merge after the trail nest")
		assert(server:find("Island.withTrailNest(islandLayout)", 1, true) < server:find("CandyNests.merge(", 1, true), "order")
		has(server, "rarity = spec.rarity or (spec.id == \"I3\" and \"Rara\")", "a nest's own rarity")
		has(server, "height = spec.nestTop and spec.nestTop - 0.8 - groundAt(", "the egg rests in the bowl")
		has(server, "if #island.adults == 0 then return end", "no parent, no scream or chase")
		has(server, "elseif Species.ONLY and not Species.keepsOwn(slot.species) then", "Caramelo eggs keep their species")
		has(server, "for index = 1, #spec.adultPoints > 0 and 3 or 0 do", "no sleep readout without a parent")
	end)

	-- CG2 (F1, decision 48): a reopened or published place has its Caramelo nests and portal on without an Edit session.
	case("CG2: applyFlags switches the live markers on from the layout (nests, never the event nest, and the portal)", function()
		local root = Instance.new("Model")
		root.Name = Nests.ROOT_NAME
		local folder = Instance.new("Folder")
		folder.Name = "Nests"
		folder.Parent = root
		for _, spec in ipairs(Layout.NESTS) do
			local nest = Instance.new("Model")
			nest.Name = "Nest_" .. spec.id
			nest:SetAttribute("NestId", spec.id)
			nest:SetAttribute("Enabled", false)
			nest.Parent = folder
		end
		local portal = Instance.new("Model")
		portal.Name = "Portal"
		portal:SetAttribute("Enabled", false)
		portal.Parent = root
		local nests, portals = Nests.applyFlags(root, Builder, Layout)
		local live = 0
		for _, spec in ipairs(Layout.NESTS) do
			local want = Builder.nestEnabled(spec, Layout)
			equal(folder["Nest_" .. spec.id]:GetAttribute("Enabled"), want, spec.id)
			if want then live += 1 end
			if spec.eventOnly then equal(want, false, spec.id .. " event-only stays off") end
		end
		equal(nests, live, "nests changed")
		equal(portals, Layout.PORTAL.enabled and 1 or 0, "portal changed")
		equal(portal:GetAttribute("Enabled"), Layout.PORTAL.enabled == true, "portal flag")
		equal(root:GetAttribute("NestsEnabled"), Layout.NESTS_ENABLED == true, "root flag")
		equal(select(1, Nests.applyFlags(root, Builder, Layout)), 0, "idempotent")
		portal:Destroy()
		local n2, p2 = Nests.applyFlags(root, Builder, Layout)
		equal(n2, 0, "no portal model: the nests still apply"); equal(p2, 0, "and no portal")
		equal(select(1, Nests.applyFlags(nil, Builder, Layout)), 0, "no biome: nothing, no error")
		equal(select(1, Nests.applyFlags(root, nil, Layout)), 0, "no builder: nothing, no error")
		root:Destroy()
	end)

	case("CG2: the server applies the layout flags before it reads the nests and before the portals bind", function()
		local server = sources.server
		local apply = server:find("CandyNests.applyFlags(", 1, true)
		assert(apply, "the server applies the flags")
		has(server, 'ServerStorage"):FindFirstChild("WildboundCandyBuilder")', "with the builder")
		has(server, 'ServerStorage"):FindFirstChild("WildboundCandyLayout")', "and the layout")
		assert(apply < server:find("CandyNests.merge(islandLayout, CandyNests.read(", 1, true), "before the read")
		assert(apply < server:find("PortalService.new(", 1, true), "before the portal service binds the arch")
	end)

	-- CG2 (F5, decision 50): the guard binding is used: a steal at a guarded nest wakes that guardian on the thief.
	case("CG2: a steal at a guarded nest raises the guard alarm; the beasts wake that guardian on the thief", function()
		local server, beasts = sources.server, sources.beasts
		local claim = server:find("entry.claimEgg = function(player)", 1, true)
		local alarm = server:find("if island and island.spec.guard then Heist.guardAlarm(island.spec.guard, player) end", 1,
			true)
		assert(claim and alarm and alarm > claim, "claimEgg raises the alarm for a guarded nest")
		has(server, "function Heist.guardAlarm(beast, player)", "the alarm")
		has(server, 'FindFirstChild("GuardAlarm")', "fires the beasts' server-only event")
		has(beasts, 'alarm.Name = "GuardAlarm"', "the beasts own the event")
		has(beasts, 'Instance.new("BindableEvent")', "a BindableEvent (never a remote)")
		-- Deliberately changed (CH1): the alarm passes the extra post of an "<name>@<post>" binding (nil for a home post)
		has(beasts, "Director.alarm(director, player.UserId, name, contextFor(player, at), at, key)", "through the director")
		for _, name in ipairs(Nests.GUARDIANS) do equal(Config.SUMMONED[name], true, name .. " is a summoned guardian") end
	end)

	-- CH1 (owner request "more repeated creatures in the Caramelo kingdom, harder to be in that biome"): every candy
	-- creature (the three guardians and the five critters) has one extra post, so a player crossing the biome meets about
	-- twice as many. The same rules as the home posts (WildboundCandyBeastSites_Test T4, CC4: beside a nest, leash on the
	-- plot, leash plus attack plus push off Don Glaseon's ground), except that an extra post stands near a route on
	-- purpose: off the path, yet within its wake radius, so a walker wakes it. Never near the hub entrance.
	case("CH1: one extra post per candy creature: fixed, beside its own nest, by a route, off the boss ground and the entrance", function()
		local NAMES = { "Gomibu", "Flanfuria", "Tortidragon", "Mochimiau", "Canelin", "Flanin", "Mielita", "GatoRepartidor" }
		assert(type(Sites.EXTRA_POSTS) == "table", "no Sites.EXTRA_POSTS")
		-- Deliberately changed (GT2, owner request "more eggs and more creatures"): two extra posts per creature (16 -> 24)
		local PER = 2
		equal(#Sites.EXTRA_POSTS, #NAMES * PER, "two extra posts per candy creature (16 -> 24 posts)")
		local C = Layout.CENTRE
		local count, keys, nestOf = {}, {}, {}
		for _, extra in ipairs(Sites.EXTRA_POSTS) do
			local name, key = extra.name, extra.key
			assert(table.find(NAMES, name) and Config.SUMMONED[name], tostring(name) .. " is not a candy creature")
			count[name] = (count[name] or 0) + 1
			assert(type(key) == "string" and not keys[key], tostring(key) .. " used twice"); keys[key] = true
			assert(string.match(key, "^%w+$"), key .. ": letters and digits only (an attribute name and a binding)")
			assert(Sites.FIXED[key], key .. " is not a fixed site")
			local w, moved = Sites.world(nil, key), Sites.world({ x = 0, z = 0 }, key)
			equal(moved.x, w.x, key .. " x moved with the origin"); equal(moved.z, w.z, key .. " z moved with the origin")
			local p = { x = w.x - C.x, z = w.z - C.z }
			local T = Config.BEASTS[name].tuning
			local nearest, nearestId = math.huge, nil
			for _, spec in ipairs(Layout.NESTS) do
				local d = flat(p.x, p.z, spec.x, spec.z)
				if d < nearest then nearest, nearestId = d, spec.id end
			end
			assert(nearest >= 8 and nearest <= 16, key .. " is " .. nearest .. " studs from nest " .. tostring(nearestId))
			assert(not nestOf[nearestId], key .. " shares nest " .. tostring(nearestId)); nestOf[nearestId] = key
			local toRoute = Layout.routeDistance(p.x, p.z)
			assert(toRoute >= Layout.PATH_WIDTH / 2 + 4, key .. " stands on a path (" .. toRoute .. ")")
			assert(toRoute <= T.WakeRadiusStuds, key .. ": a route walker never wakes it (" .. toRoute .. ")")
			assert(Layout.depth(p.x, p.z) >= T.LeashStuds, key .. ": its leash leaves the plot")
			local A = T.Attack or {}
			local reach = T.LeashStuds + (A.RadiusStuds or A.WidthStuds or 0) + (A.PushStuds or 0)
			local toBoss = flat(p.x, p.z, Layout.BOSS.x, Layout.BOSS.z)
			assert(toBoss >= Layout.BOSS.territoryRadius + reach, key .. " reaches the boss ground (" .. toBoss .. ")")
			assert(flat(p.x, p.z, Layout.ENTRANCE.x, Layout.ENTRANCE.z) >= 30 + reach, key .. " reaches the entrance")
			for _, disc in ipairs(Layout.LAKE) do assert(flat(p.x, p.z, disc.x, disc.z) >= disc.r + 2, key .. " in the syrup") end
			for _, spot in ipairs(Layout.KEEP_CLEAR) do assert(flat(p.x, p.z, spot.x, spot.z) >= spot.r, key .. " on " .. spot.why) end
			-- far from its own home post: each copy keeps its own ground, and a client tells their views apart by distance
			local home = Sites.world(nil, Sites.HOME[name])
			assert(flat(w.x, w.z, home.x, home.z) >= 100, key .. " is near " .. name .. "'s home post")
			local function wants(dx, more)
				local c = { alive = true, safe = false, meadow = true, x = w.x + dx, z = w.z }
				for k, v in pairs(more or {}) do c[k] = v end
				return Sites.wants(name, c, key)
			end
			equal(wants(0), true, key .. " at its post"); equal(wants(T.WakeRadiusStuds - 0.5), true, key .. " inside the wake radius")
			equal(wants(T.WakeRadiusStuds + 0.5), false, key .. " outside the wake radius")
			equal(wants(0, { safe = true }), false, key .. " for a safe player"); equal(wants(0, { meadow = false }), false, key .. " outside the biome")
			equal(wants(0, { alive = false }), false, key .. " for a dead player")
			equal(Sites.wants(name, { alive = true, safe = false, meadow = true, x = w.x, z = w.z }), false,
				key .. ": without the post the home post's rule holds")
		end
		for _, name in ipairs(NAMES) do equal(count[name], PER, name .. " extra posts") end
		local all = {}
		for _, name in ipairs(NAMES) do table.insert(all, Sites.world(nil, Sites.HOME[name])) end
		for _, extra in ipairs(Sites.EXTRA_POSTS) do table.insert(all, Sites.world(nil, extra.key)) end
		equal(#all, 8 + 8 * PER, "posts in all")
		for i = 1, #all do
			for j = i + 1, #all do
				assert(flat(all[i].x, all[i].z, all[j].x, all[j].z) >= 30, "posts " .. i .. " and " .. j .. " closer than 30 studs")
			end
		end
	end)

	-- CH3 (owner request "more eggs too"): 8 new floor nests (12 -> 20; 11 -> 19 live, the summit T1 apart), all live
	-- one-egg island nests; the three beside an extra guardian post are guarded by that copy.
	case("CH3: the new nests are live one-egg island nests; three are guarded by an extra guardian post", function()
		local list = Nests.islands(markers(), Nests.posts(Sites))
		equal(#list, 27, "live floor nests (11 -> 19; GT2: 19 -> 27)")
		local byId = {}
		for _, entry in ipairs(list) do byId[entry.nestId] = entry end
		for _, id in ipairs({ "C6", "C7", "C8", "C9", "C10", "R5", "R6", "R7" }) do
			local entry = byId[id]
			assert(entry, id .. " is not a live nest")
			equal(entry.id, "Candy" .. id, id .. " island id"); equal(entry.eggs, 1, id .. " one egg")
			equal(entry.species, Nests.pick(entry.rarity).species, id .. " species")
		end
		equal(byId.C7.guard, "Gomibu@candyPostC7", "C7 guard"); equal(byId.R6.guard, "Flanfuria@candyPostR6", "R6 guard")
		equal(byId.C8.guard, "Tortidragon@candyPostC8", "C8 guard")
		for _, id in ipairs({ "C6", "C9", "C10", "R5", "R7" }) do equal(byId[id].guard, nil, id .. " has a critter beside it, no guard") end
		equal(byId.C1.guard, "Gomibu", "the home guardians keep their nests")
		-- GT2: the eight newer nests, three of them guarded by a guardian's second extra post
		for _, id in ipairs({ "E3", "R8", "R9", "R10", "R11", "C11", "C12", "C13" }) do
			assert(byId[id], id .. " is not a live nest"); equal(byId[id].eggs, 1, id .. " one egg")
		end
		equal(byId.E3.guard, "Gomibu@candyPostE3", "E3 guard"); equal(byId.R8.guard, "Flanfuria@candyPostR8", "R8 guard")
		equal(byId.R9.guard, "Tortidragon@candyPostR9", "R9 guard")
		for _, id in ipairs({ "R10", "R11", "C11", "C12", "C13" }) do equal(byId[id].guard, nil, id .. " has a critter beside it") end
	end)

	-- CH3: the live place was built before the new nests existed; the server's start step (applyFlags -> syncNests) places
	-- a layout nest the build lacks, once, the way Builder.build does, so it is read as a live marker like any other.
	case("CH3: syncNests places a layout nest missing from an older build, once, as a live marker", function()
		local root = Instance.new("Model")
		local folder = Instance.new("Folder")
		folder.Name, folder.Parent = "Nests", root
		local want
		for _, spec in ipairs(Layout.NESTS) do
			if spec.id == "C9" then want = spec else
				local nest = Instance.new("Model")
				nest.Name = "Nest_" .. spec.id
				nest:SetAttribute("NestId", spec.id); nest:SetAttribute("Enabled", Builder.nestEnabled(spec, Layout))
				nest.Parent = folder
			end
		end
		assert(want, "no C9 in the layout")
		local placed = {}
		local kit = { LIBRARY_NAME = "CandyKit", place = function(library, name, cframe, scale)
			table.insert(placed, { library = library, name = name, scale = scale })
			local model = Instance.new("Model")
			for _, partName in ipairs({ "Collision_Bowl", "RarityRing" }) do
				local part = Instance.new("Part")
				part.Name, part.Anchored, part.Parent = partName, true, model
			end
			model:PivotTo(cframe)
			return model
		end }
		local library = Instance.new("Folder")
		equal(Builder.syncNests(root, Layout, kit, library), 1, "one nest placed")
		equal(#placed, 1, "one prefab"); equal(placed[1].name, "Nest", "the kit's Nest"); equal(placed[1].library, library, "library")
		local nest = folder:FindFirstChild("Nest_C9")
		assert(nest, "Nest_C9 not placed")
		local p = nest:GetPivot().Position
		assert(math.abs(p.X - (Layout.CENTRE.x + want.x)) < 1e-3 and math.abs(p.Z - (Layout.CENTRE.z + want.z)) < 1e-3, "position")
		assert(math.abs(p.Y - Layout.FLOOR_TOP) < 1e-3, "on the floor")
		equal(nest:GetAttribute("NestId"), "C9"); equal(nest:GetAttribute("Rarity"), "Comun")
		equal(nest:GetAttribute("Enabled"), true, "live"); equal(nest:GetAttribute("EventOnly"), false, "not event-only")
		equal(nest.PrimaryPart and nest.PrimaryPart.Name, "Collision_Bowl", "the bowl is the primary part")
		local read
		for _, m in ipairs(Nests.read(root)) do if m.id == "C9" then read = m end end
		assert(read and read.enabled and read.rarity == "Comun", "read as a live marker")
		equal(Builder.syncNests(root, Layout, kit, library), 0, "a second sync places nothing")
		local broken = Instance.new("Model")
		local empty = Instance.new("Folder")
		empty.Name, empty.Parent = "Nests", broken
		equal(Builder.syncNests(broken, Layout, { place = function() error("no prefab") end }, library), 0, "no kit: skipped, no error")
		root:Destroy(); library:Destroy(); broken:Destroy()
	end)

	-- CH4 (owner request 2026-11-16, "more creatures that appear in a random way"): besides the posts, an ambush roll
	-- every AMBUSH.everySeconds for each player inside the Caramelo plot starts a random candy critter on the ground near
	-- them (Sites.ambushRoll picks the kind and the spot; the beast server checks the ground and summons it through the
	-- director, post "ambush"). Never by the hub entrance, never on or near Don Glaseon's ground. A critter only: it sees
	-- as far as it appears, so it notices (and tells) at once; the guardians stay at their nests.
	case("CH4: the ambush roll: one tunable table, a random critter 25-40 studs away, never by the entrance or the boss ground", function()
		local A = Sites.AMBUSH
		assert(type(A) == "table" and type(Sites.ambushRoll) == "function", "no Sites.AMBUSH / Sites.ambushRoll")
		-- Deliberately changed (RC, owner request 2026-11-16 "all of them, more at once"): every 20 -> 15 s, at most 2 -> 3
		equal(A.everySeconds, 15, "every"); equal(A.chance, 0.75, "chance"); equal(A.maxActive, 3, "at most three at once")
		equal(A.minStuds, 25, "min"); equal(A.maxStuds, 40, "max"); equal(A.post, "ambush", "director post")
		-- a crossing of the plot (about 90 s with a nest or two) meets about 90 / 15 x 0.75 = 4.5 rolls won
		assert(90 / A.everySeconds * A.chance >= 3 and 90 / A.everySeconds * A.chance <= 5, "3-5 ambushes per crossing")
		for _, name in ipairs(A.names) do
			equal(Config.SUMMONED[name], true, name .. " summoned")
			assert(Config.BEASTS[name].tuning.PerceptionStuds - 2 > A.minStuds, name .. " would not see the player it ambushes")
			assert(not table.find(Nests.GUARDIANS, name), name .. ": the guardians stay at their nests")
		end
		local C, boss = Layout.CENTRE, Sites.world(nil, "bossTerritory")
		local function check(lx, lz)
			local spots, kinds = 0, {}
			for k = 0, 9 do
				for a = 0, 15 do
					for d = 0, 4 do
						local name, spot = Sites.ambushRoll(C.x + lx, C.z + lz, k / 10 + 0.05, a / 16, d / 4)
						if name then
							spots += 1
							kinds[name] = true
							assert(table.find(A.names, name), tostring(name) .. " is not an ambusher")
							local far = math.min(A.maxStuds, Config.BEASTS[name].tuning.PerceptionStuds - 2)
							local r = flat(spot.x, spot.z, C.x + lx, C.z + lz)
							assert(r >= A.minStuds - 1e-6 and r <= far + 1e-6, name .. " appears " .. r .. " studs away")
							local sx, sz = spot.x - C.x, spot.z - C.z
							assert(Layout.depth(sx, sz) >= A.edgeStuds, "a spot on the plot edge")
							assert(flat(sx, sz, Layout.ENTRANCE.x, Layout.ENTRANCE.z) >= A.entranceSpotStuds, "a spot by the entrance")
							assert(flat(spot.x, spot.z, boss.x, boss.z) >= A.bossClearStuds, "a spot by the boss ground")
						end
					end
				end
			end
			return spots, kinds
		end
		local spots, kinds = check(120, 100)
		assert(spots > 0, "a player in the open plot is never ambushed")
		for _, name in ipairs(A.names) do assert(kinds[name], name .. " never ambushes") end
		check(-120, -60); check(60, 0); check(0, 150)
		-- Deliberately changed (V8-D1): the plot is 1.3 times bigger (HALF 200 -> 260); the same two probes, re-anchored:
		-- 15 studs past the entrance (was (-185, 0), the entrance at -200) and 60 outside the east edge (was (260, 0))
		equal((check(Layout.ENTRANCE.x + 15, Layout.ENTRANCE.z)), 0, "never in the first steps past the entrance")
		equal((check(Layout.HALF + 60, 0)), 0, "never outside the Caramelo plot")
		-- Deliberately changed (GT): the plaza moved with the Torta to (BOSS.x, BOSS.z); (0, 30) is the junction now
		equal((check(Layout.BOSS.x, Layout.BOSS.z + 30)), 0, "never on the boss plaza or the tower")
		-- Deliberately changed (V8-D1): the entrance is Layout.ENTRANCE (-260, 0), was the literal (-200, 0)
		assert(flat(0, 0, Layout.ENTRANCE.x, Layout.ENTRANCE.z) > A.entranceSpotStuds
			and A.bossClearStuds >= Layout.BOSS.territoryRadius + 40, "clearances")
		equal(Sites.ambushRoll(0 / 0, 0, 0.5, 0.5, 0.5), nil, "a bad position")
		equal(Sites.ambushRoll(C.x + 120, C.z + 100, nil, 0.5, 0.5), nil, "no roll")
	end)

	case("CH4 wiring: the beast server rolls an ambush per player in Caramelo through the director", function()
		local beasts = sources.beasts
		has(beasts, "world.ambushAt = world.ambushAt or setmetatable({}, { __mode = \"k\" })", "a clock per player")
		has(beasts, "Sites.ambushRoll(p.X, p.Z, rng:NextNumber(), rng:NextNumber(), rng:NextNumber())", "the pure pick")
		has(beasts, "local y = spot and world.landing(spot.x, spot.z, p.Y)", "on the ground, out of safe zones and solid parts")
		has(beasts, "Director.summon(director, player.UserId, name, ctx, at, { post = A.post })", "through the director")
		-- Deliberately changed (V4): the at-most-at-once follows the chase ramp (V4-D9), min(maxActive, the chaser cap)
		has(beasts, "if active < Sites.ambushCap(world.smarts.cap(world, player.UserId, at)) and rng:NextNumber() < A.chance then",
			"the ramped cap and the chance")
		has(beasts, 'world.smarts = world.smarts or require(script.Parent:WaitForChild("WildboundCandySmarts"))', "the shared Smarts")
	end)

	-- V4-D9 (owner request 2026-11-17, "progressively, not all at once"): ambushes follow the chase ramp.
	case("V4-D9: the ambush cap is min(maxActive, the player's chaser cap), at least one", function()
		local A = Sites.AMBUSH
		assert(type(Sites.ambushCap) == "function", "no Sites.ambushCap")
		equal(Sites.ambushCap(1), 1, "no pressure: one ambush at most")
		equal(Sites.ambushCap(2), 2); equal(Sites.ambushCap(2.9), 2, "whole critters")
		equal(Sites.ambushCap(5), A.maxActive, "never past maxActive")
		equal(Sites.ambushCap(0), 1, "an ambush can always open the pressure")
		equal(Sites.ambushCap(nil), A.maxActive, "no cap: the old maxActive"); equal(Sites.ambushCap(0 / 0), A.maxActive)
	end)

	-- V4-D13: a steal's frenzy wakes every candy post within its reach of the nest (so the frenzy's call reaches it), past
	-- the post's own wake radius; Don Glaseon and posts out of reach keep their rule.
	case("V4-D13: during a frenzy the candy posts within reach of the robbed nest wake", function()
		local extra = Sites.EXTRA_POSTS[1]
		local site = Sites.world(nil, extra.key)
		local T = Config.BEASTS[extra.name].tuning
		local far = T.WakeRadiusStuds + 60
		local ctx = { alive = true, safe = false, meadow = true, x = site.x + far, z = site.z }
		equal(Sites.wants(extra.name, ctx, extra.key), false, "too far without a frenzy")
		ctx.frenzy = { x = site.x + 100, z = site.z, studs = 150 }
		equal(Sites.wants(extra.name, ctx, extra.key), true, "a frenzy 100 studs away wakes it")
		ctx.frenzy = { x = site.x + 151, z = site.z, studs = 150 }
		equal(Sites.wants(extra.name, ctx, extra.key), false, "out of the frenzy's reach")
		ctx.frenzy = { x = site.x, z = site.z, studs = 150 }
		ctx.safe = true
		equal(Sites.wants(extra.name, ctx, extra.key), false, "never for a safe player")
		local beasts = sources.beasts
		-- Deliberately changed (K-D11, Pueblo Gatito, owner request 2026-11-17 "también tiene que haber huevos para robar"):
		-- a steal in the kitten park (CandyEast) starts the frenzy too, so the check reads world.inCandy, not inMeadow
		has(beasts, "world.stealCheck(player, character, p, at, world.inCandy(p.X, p.Z))", "a steal is seen in the summon pass")
		has(beasts, "want.frenzy = world.smarts.frenzyAt(world, player.UserId, at)", "the frenzy reaches the posts")
		has(beasts, "world.smarts.frenzy(world, player.UserId, at, p.X, p.Z)", "a new carried egg starts it")
	end)

	-- V4-D12: the houses are a refuge: every beast step is kept outside them, and no hit lands on a player inside.
	case("V4-D12 wiring: the beast server keeps every creature out of the houses and shelters a player inside", function()
		local beasts = sources.beasts
		has(beasts, "world.keepOut(entry.e, px, pz, at) -- V4-D12: never inside a house", "after each step")
		assert(beasts:find("world.keepOut(entry.e, px, pz, at)", 1, true) > beasts:find("local events = Enc.step(entry.e, at, target", 1, true),
			"after the brain moved it")
		has(beasts, "e.pos.x, e.pos.z = world.smarts.outsideHouses(px, pz, e.pos.x, e.pos.z, discs)", "the pure clamp")
		has(beasts, 'world.houses = world.smarts.houseDiscs(workspace:FindFirstChild("Candy_Bioma_v1"))', "the live houses")
		local _, hits = beasts:gsub('if world.sheltered and world.sheltered%(entry.player%) then count%("sheltered"%) return end', "")
		equal(hits, 2, "no hit and no affliction on a sheltered player")
		-- count() adds to counts[key]: an unseeded key errors and ends the encounter (seen in Play 2026-11-17)
		-- V5-D2 (Caramelo v5): the hiding counters follow it on the same line
		-- V6-D1 (Caramelo v6): the grass counter follows them; V6-D5: then the caramel traps' counter
		has(beasts, "observeDropped = 0, afflicted = 0, sheltered = 0, hidden = 0, hideFound = 0, hideLost = 0, grassLost = 0, trapped = 0 }",
			"the sheltered, hiding, grass and trap counters are seeded")
	end)

	-- CH1 wiring: the beast server summons each extra post through the director (one per post) and starts it on the ground
	-- there; a steal at an extra guardian's nest wakes that copy at its post.
	case("CH1 wiring: the beast server summons the extra posts and wakes an extra guardian at its post", function()
		local beasts = sources.beasts
		has(beasts, "for _, extra in ipairs(Sites.EXTRA_POSTS) do", "summonPass walks the extra posts")
		has(beasts, "if Sites.wants(extra.name, want, extra.key) then", "the wake rule at that post")
		has(beasts, "Director.summon(director, player.UserId, extra.name, ctx, at, { post = extra.key })", "one per post")
		has(beasts, "function world.startAtPost(player, reservation, key, refY, at)", "started on the ground at the post")
		has(beasts, "reservation.near = { x = site.x, y = y, z = site.z }", "never at the home post")
		has(beasts, 'local key = string.match(name, "@(%w+)$")', "the alarm reads the post of the binding")
		has(beasts, "world.startAtPost(player, value, key, body and body.Position.Y or 0, at)", "an extra guardian wakes at its post")
	end)

	-- V8-D1 (owner request 2026-11-17, "make the Reino Caramelo map a bit bigger ... more space between things"): the
	-- sites' copies of the layout follow the 1.3 times bigger plot, and every post moved with its paired nest.
	case("V8-D1: the sites' layout copies equal the v8 layout; each post moved with its nest", function()
		local function near(actual, expected, label)
			assert(type(actual) == "number" and math.abs(actual - expected) <= 1e-6, label .. ": expected " .. tostring(expected)
				.. ", got " .. tostring(actual))
		end
		local C, A = Layout.CENTRE, Sites.AMBUSH
		near(Sites.MEADOW_CENTRE.x, C.x, "MEADOW_CENTRE x"); near(Sites.MEADOW_CENTRE.z, C.z, "MEADOW_CENTRE z")
		near(A.half, Layout.HALF, "AMBUSH.half"); near(A.entrance.x, Layout.ENTRANCE.x, "AMBUSH.entrance x")
		near(A.entrance.z, Layout.ENTRANCE.z, "AMBUSH.entrance z")
		local home, territory = Sites.world(nil, "bossHome"), Sites.world(nil, "bossTerritory")
		near(home.x, C.x + Layout.BOSS.home.x, "bossHome x"); near(home.z, C.z + Layout.BOSS.home.z, "bossHome z")
		near(territory.x, C.x + Layout.BOSS.x, "bossTerritory x"); near(territory.z, C.z + Layout.BOSS.z, "bossTerritory z")
		-- each post keeps its v7 offset from its paired nest (candyPostR10 alone was turned towards its route)
		local pairs7 = {
			candyNest = { "C1", -6, 6 }, candyNestR1 = { "R1", 8, -8 }, candyNestC3 = { "C3", -12, -8 },
			candyNestC2 = { "C2", -6, 13 }, candyNestR2 = { "R2", 5, 12 }, candyNestR3 = { "R3", 12, 10 },
			candyNestR4 = { "C5", 6, 14 }, candyNestC4 = { "C4", -8, 12 }, candyPostC7 = { "C7", 7, -9 },
			candyPostR6 = { "R6", 7, 5 }, candyPostC8 = { "C8", -5, 12 }, candyPostC9 = { "C9", 11, 4 },
			candyPostR7 = { "R7", -10, 8 }, candyPostR5 = { "R5", 8, 10 }, candyPostC6 = { "C6", -10, 8 },
			candyPostC10 = { "C10", 12, 8 }, candyPostE3 = { "E3", -12, 0 }, candyPostR8 = { "R8", 12, 0 },
			candyPostR9 = { "R9", 12, 0 }, candyPostR10 = { "R10", 9, 8 }, candyPostC11 = { "C11", 0, -12 },
			candyPostC12 = { "C12", 12, 0 }, candyPostC13 = { "C13", -12, 1 }, candyPostR11 = { "R11", -9, 8 },
		}
		local count = 0
		for key, row in pairs(pairs7) do
			count += 1
			local nest
			for _, spec in ipairs(Layout.NESTS) do if spec.id == row[1] then nest = spec end end
			assert(nest, key .. ": no nest " .. row[1])
			local w = Sites.world(nil, key)
			near(w.x, C.x + nest.x + row[2], key .. " x beside " .. row[1]); near(w.z, C.z + nest.z + row[3], key .. " z beside " .. row[1])
		end
		local fixed = 0
		for _ in pairs(Sites.FIXED) do fixed += 1 end
		equal(fixed, count + 2, "every fixed post is paired (plus Don Glaseon's home and territory)")
	end)

	-- K-D8, K-D9 (Pueblo Gatito, docs/design/wildbound-kitten-park-plan.md; owner request 2026-11-17, "es como el mundo de
	-- gatito ... también tiene que haber huevos para robar"): the kitten park's nests K1..K8 live in the sibling root
	-- Candy_Este_v1.Nests. The server's one read of Candy_Bioma_v1 returns them too (park = true, guard from the Guard
	-- attribute), they pay one tier more (PARK_POOL), no plot post ever binds them, and applyFlags lays them (Park.syncNests)
	-- as its ninth step. Every fixture is a detached scratch Folder.
	local function scratchNest(folder, id, rarity, x, z, guard)
		local nest = Instance.new("Model")
		nest.Name = "Nest_" .. id
		local bowl = Instance.new("Part")
		bowl.Name, bowl.Shape, bowl.Size = "Collision_Bowl", Enum.PartType.Cylinder, Vector3.new(2.2, 6, 6)
		bowl.CFrame = CFrame.new(x, 1.6, z) * CFrame.Angles(0, 0, math.rad(90))
		bowl.Parent = nest
		nest.PrimaryPart = bowl
		nest:SetAttribute("NestId", id); nest:SetAttribute("Rarity", rarity)
		nest:SetAttribute("EventOnly", false); nest:SetAttribute("Enabled", true)
		if guard ~= nil then
			nest:SetAttribute("Candidate", true); nest:SetAttribute("Park", true); nest:SetAttribute("Guard", guard)
		end
		nest.Parent = folder
		return nest
	end
	-- A scratch world: a parent Folder holding Candy_Bioma_v1 (one plot nest) and, unless noPark, Candy_Este_v1.Nests
	-- (two park markers: K1 Comun guarded from a home post, K7 Epica from an east extra post).
	local function scratchWorld(noPark)
		local world = Instance.new("Folder")
		world.Name = "KittenScratch"
		local bioma = Instance.new("Model")
		bioma.Name = Nests.ROOT_NAME
		local plot = Instance.new("Folder")
		plot.Name, plot.Parent = "Nests", bioma
		scratchNest(plot, "C1", "Comun", 450, -21, nil)
		bioma.Parent = world
		local park
		if not noPark then
			park = Instance.new("Model")
			park.Name = Nests.PARK_ROOT
			local folder = Instance.new("Folder")
			folder.Name, folder.Parent = "Nests", park
			scratchNest(folder, "K1", "Comun", 1038, -58, "GatitoGuerrero")
			scratchNest(folder, "K7", "Epica", 1358, -123, "GatitoActually@kittenPostK7")
			park.Parent = world
		end
		return world, bioma, park
	end

	case("PK1: the read of Candy_Bioma_v1 also returns the park markers of its sibling root, marked park with their guard", function()
		equal(Nests.PARK_ROOT, "Candy_Este_v1", "the park root")
		local world, bioma = scratchWorld()
		local read = Nests.read(bioma)
		equal(#read, 3, "one plot nest and two park nests")
		local byId = {}
		for _, m in ipairs(read) do byId[m.id] = m end
		assert(byId.C1 and byId.K1 and byId.K7, "C1, K1 and K7")
		equal(byId.C1.park, false, "C1 is a plot nest"); equal(byId.C1.guard, nil, "a plot nest's guard comes from its post")
		equal(byId.K1.park, true, "K1 park"); equal(byId.K1.guard, "GatitoGuerrero", "K1 guard")
		equal(byId.K7.park, true, "K7 park"); equal(byId.K7.guard, "GatitoActually@kittenPostK7", "K7 guard")
		equal(byId.K1.rarity, "Comun"); equal(byId.K7.rarity, "Epica"); equal(byId.K1.enabled, true)
		assert(math.abs(byId.K1.x - 1038) < 1e-3 and math.abs(byId.K1.z + 58) < 1e-3, "K1 position")
		assert(math.abs(byId.K1.top - 2.7) < 1e-3, "K1 bowl top " .. byId.K1.top)
		-- a scratch root (no parent) reads only itself; so does a parented one with no park sibling
		bioma.Parent = nil
		equal(#Nests.read(bioma), 1, "an unparented root reads only its own nests")
		world:Destroy(); bioma:Destroy()
		local lone, loneBioma = scratchWorld(true)
		equal(#Nests.read(loneBioma), 1, "no Candy_Este_v1: only the plot's nests")
		lone:Destroy()
	end)

	case("PK2: a park nest pays one tier more (Comun Fog Gomibu, Rara FogFar Tortidragon, Epica Territory Flanfuria); no park Legendaria", function()
		local want = { Comun = { "Gomibu", "Fog" }, Rara = { "Tortidragon", "FogFar" }, Epica = { "Flanfuria", "Territory" } }
		for rarity, row in pairs(want) do
			local pick = Nests.pick(rarity, true)
			assert(pick, rarity)
			equal(pick.species, row[1], rarity .. " species"); equal(pick.rewardTier, row[2], rarity .. " park reward")
			equal(pick.tier, Nests.RISK[rarity], rarity .. " the risk tier stays RISK")
		end
		equal(Nests.pick("Legendaria", true), nil, "a park Legendaria is unknown")
		equal(Nests.pick("Comun").rewardTier, "Safe", "the plot keeps its pay"); equal(Nests.pick("Legendaria").rewardTier, "Heart")
		assert(table.isfrozen(Nests.PARK_POOL), "frozen")
		local markers = {
			{ id = "C1", rarity = "Comun", x = 450, z = -21, top = 2.7, enabled = true },
			{ id = "K1", rarity = "Comun", x = 1038, z = -58, top = 2.7, enabled = true, park = true, guard = "GatitoGuerrero" },
			{ id = "K7", rarity = "Epica", x = 1358, z = -123, top = 2.7, enabled = true, park = true,
				guard = "GatitoActually@kittenPostK7" },
			{ id = "K9", rarity = "Legendaria", x = 1300, z = 0, top = 2.7, enabled = true, park = true, guard = "GatitoLanudo" },
		}
		local list = Nests.islands(markers, {})
		equal(#list, 3, "the park Legendaria is dropped")
		local byId = {}
		for _, entry in ipairs(list) do byId[entry.id] = entry end
		local k1, k7, c1 = byId.CandyK1, byId.CandyK7, byId.CandyC1
		assert(k1 and k7 and c1, "CandyK1, CandyK7 and CandyC1")
		equal(k1.species, "Gomibu"); equal(k1.rewardTier, "Fog"); equal(k1.rarity, "Comun"); equal(k1.tier, "Fog")
		equal(k1.park, true, "K1 marked park"); equal(k1.key, "caramelo_k1"); equal(k1.nestId, "K1")
		equal(k7.species, "Flanfuria"); equal(k7.rewardTier, "Territory"); equal(k7.rarity, "Epica"); equal(k7.tier, "Territory")
		equal(c1.rewardTier, "Safe", "a plot Comun still pays Safe"); equal(c1.park, nil, "a plot entry has no park mark")
		equal(byId.CandyK9, nil, "no park Legendaria")
		assert(table.isfrozen(k1), "frozen entry")
	end)

	case("PK3: a park nest's guard is its Guard attribute; a plot post 5 studs away never binds it", function()
		local markers = {
			{ id = "K1", rarity = "Comun", x = 1038, z = -58, enabled = true, park = true, guard = "GatitoGuerrero" },
			{ id = "K2", rarity = "Comun", x = 1043, z = 92, enabled = true, park = true },
		}
		local posts = { { name = "Gomibu", x = 1043, z = -58 }, { name = "Flanfuria", x = 1043, z = 97 } }
		local binding = Nests.bind(markers, posts)
		equal(binding.K1, nil, "a plot post never binds a park nest"); equal(binding.K2, nil, "nor K2")
		local byId = {}
		for _, entry in ipairs(Nests.islands(markers, posts)) do byId[entry.id] = entry end
		equal(byId.CandyK1.guard, "GatitoGuerrero", "the guard comes from the attribute")
		equal(byId.CandyK2.guard, nil, "no attribute, no guard (never the plot post beside it)")
		-- the plot's own guardian posts are unchanged (the kittens are not candy guardians)
		equal(#Nests.posts(Sites), 9, "still nine plot guardian posts")
		for _, post in ipairs(Nests.posts(Sites)) do
			assert(post.x < 932, post.name .. " post in the plot")
		end
	end)

	case("PK4: applyFlags lays the park nests ninth through Park.syncNests on the sibling root (guarded)", function()
		local fakeBuilder = { syncNests = function() return 0 end, syncPortal = function() return 0 end }
		local calls, seen = 0, nil
		local fake = { syncNests = function(r) calls += 1; seen = r; return 3 end }
		local world, bioma, park = scratchWorld()
		equal(select(9, Nests.applyFlags(bioma, fakeBuilder, Layout, false, false, false, false, false, fake)), 3, "the ninth value")
		equal(calls, 1, "called once"); equal(seen, park, "with the sibling Candy_Este_v1")
		equal(select(9, Nests.applyFlags(bioma, fakeBuilder, Layout, false, false, false, false, false, false)), 0, "false: none")
		equal(calls, 1, "false calls nothing")
		equal(select(9, Nests.applyFlags(bioma, fakeBuilder, Layout, false, false, false, false, false,
			{ syncNests = function() error("boom") end })), 0, "a failing sync counts 0")
		bioma.Parent = nil
		equal(select(9, Nests.applyFlags(bioma, fakeBuilder, Layout, false, false, false, false, false, fake)), 0, "unparented: 0")
		equal(calls, 1, "an unparented root calls nothing")
		world:Destroy(); bioma:Destroy()
		local lone, loneBioma = scratchWorld(true)
		equal(select(9, Nests.applyFlags(loneBioma, fakeBuilder, Layout, false, false, false, false, false, fake)), 0, "no park root: 0")
		equal(calls, 1, "no park root calls nothing")
		lone:Destroy()
	end)

	return result
end

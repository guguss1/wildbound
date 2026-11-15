-- Invoke with require(freshTestClone)(require(freshCandyNestsClone), require(freshCandyLayoutClone),
-- require(freshPraderaSitesClone), require(freshBeastConfigClone), require(freshIslandClone), require(freshSpeciesClone),
-- require(freshCandyBuilderClone), { server = WildboundServer.Source, text = require(freshTextClone) }).
-- CE1 (odd/tasks/wildbound-caramelo.md): the Caramelo nests are island nests with one egg of their rarity's species,
-- each guardian post bound to the nest beside it, refilled by the wave refresh, live through the builder's layout flag.
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
		local want = { Comun = { "Gomibu", "Fog" }, Rara = { "Tortidragon", "FogFar" }, Epica = { "Flanfuria", "Territory" },
			Legendaria = { "Flanfuria", "Heart" } }
		for rarity, row in pairs(want) do
			local pick = Nests.pick(rarity)
			assert(pick, rarity)
			equal(pick.species, row[1], rarity .. " species"); equal(pick.rewardTier, row[2], rarity .. " reward")
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
		equal(#posts, 3, "posts")
		local binding = Nests.bind(markers(), posts)
		local want = { C1 = "Gomibu", R1 = "Flanfuria", C3 = "Tortidragon" }
		local bound = 0
		for id, name in pairs(binding) do
			bound += 1
			equal(name, want[id], "guardian of " .. id)
		end
		equal(bound, 3, "bound nests")
		for _, post in ipairs(posts) do
			local nest
			for _, m in ipairs(markers()) do if binding[m.id] == post.name then nest = m end end
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

	return result
end

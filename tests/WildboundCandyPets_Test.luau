-- Invoke with require(freshTestClone)(require(freshCandyPetsClone), require(freshSpeciesClone), require(freshStateClone),
-- require(freshEconomyClone), require(freshConfigClone), require(freshRecordClone), require(freshIncubatorClone),
-- require(freshEggLoopClone), require(freshTextClone), ServerStorage.WildboundAssets, { Gomibu =
-- require(freshGomibuClipsClone), Flanfuria = require(freshFlanfuriaClipsClone), Tortidragon =
-- require(freshTortidragonClipsClone) }, { server = WildboundServer.Source }).
-- CE2 (odd/tasks/wildbound-caramelo.md): a banked Caramelo egg incubates by its rarity, hatches into its species, which
-- is saved like any creature, never follows the player and lives in the hotbar and the farm as a passive, scaled-down
-- copy of its real rig. Every model here stays detached (the assets folder is only cloned from).
return function(Pets, Species, State, Economy, Config, Record, Incubator, EggLoop, Text, assets, clips, sources)
	local HttpService = game:GetService("HttpService")
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
	local function near(actual, expected, tolerance, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= tolerance,
			("%s: expected %.2f +- %.2f, got %s"):format(label or "value", expected, tolerance, tostring(actual)))
	end
	local PETS = { "Gomibu", "Flanfuria", "Tortidragon" }
	local RARITY = { Gomibu = "Comun", Tortidragon = "Rara", Flanfuria = "Epica" }

	case("CP-1: the three Caramelo species are farm pets that never follow; Don Glaseon is none", function()
		assert(type(Pets.SPECIES) == "table", "Pets.SPECIES")
		local count = 0
		for _ in pairs(Pets.SPECIES) do count += 1 end
		equal(count, 3, "exactly three pets")
		for _, name in ipairs(PETS) do
			equal(Pets.isPet(name), true, name)
			local spec = Pets.SPECIES[name]
			assert(spec.height >= 2.5 and spec.height <= 4, name .. " farm height in 2.5..4 studs")
			equal(Species.LOOKS[name].rarity, RARITY[name], name .. " rarity (pack 06/07)")
			equal(Species.followsPlayer(name), false, name .. " never follows")
			equal(Species.FARM_ONLY[name], true, name .. " in Species.FARM_ONLY")
		end
		equal(Pets.isPet("DonGlaseon"), false, "the boss is never a pet")
		equal(Pets.isPet("Lumipol"), false)
		equal(Species.followsPlayer("Lumipol"), true, "a Lumipol still follows")
	end)

	case("CP-2: each pet's clips are its FarmIdle and walk ids when published, else none (rest pose)", function()
		local gomibu = Pets.clipIds("Gomibu", clips.Gomibu)
		equal(gomibu.idle, clips.Gomibu.animationId("FarmIdle"))
		equal(gomibu.walk, clips.Gomibu.animationId("Bounce_Move"))
		local flan = Pets.clipIds("Flanfuria", clips.Flanfuria)
		equal(flan.idle, clips.Flanfuria.animationId("FarmIdle"))
		equal(flan.walk, clips.Flanfuria.animationId("Hop_Move"))
		local torti = Pets.clipIds("Tortidragon", clips.Tortidragon)
		if next(clips.Tortidragon.IDS) == nil then
			equal(torti.idle, nil, "no published Tortidragon clip yet"); equal(torti.walk, nil)
		end
		local fake = { IDS = { FarmIdle = 11 }, animationId = function(name) return "rbxassetid://" .. ({ FarmIdle = 11 })[name] end }
		local partial = Pets.clipIds("Tortidragon", fake)
		equal(partial.idle, "rbxassetid://11", "a pasted id is used at once"); equal(partial.walk, nil)
		equal(Pets.clipIds("Lumipol", clips.Gomibu).idle, nil)
	end)

	case("CP-3: the farm model is the real rig, scaled down, feet on the spot, passive, without light", function()
		for index, name in ipairs(PETS) do
			local spot = Vector3.new(index * 20, 7, -5)
			local ids = Pets.clipIds(name, clips[name])
			local model, body = Pets.build(name, assets, spot, Vector3.new(1, 0, 0), ids)
			assert(model, name .. " has a farm model")
			equal(model.Parent, nil, name .. " is detached")
			assert(body and body:IsA("BasePart") and body:IsDescendantOf(model), name .. " has a body for the prompt")
			near(Pets.visibleHeight(model), Pets.SPECIES[name].height, 0.15, name .. " farm height")
			local pivot = model:GetPivot()
			near((pivot.Position - spot).Magnitude, 0, 0.01, name .. " pivot on the spot")
			near(pivot.LookVector:Dot(Vector3.new(1, 0, 0)), 1, 0.01, name .. " faces where it was told")
			local lowest = math.huge
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then
					equal(part.CanCollide, false, name .. "." .. part.Name .. " never blocks")
					equal(part.CanTouch, false, name .. "." .. part.Name .. " never touches")
					equal(part.Anchored, part == model.PrimaryPart, name .. "." .. part.Name .. " anchoring")
					if part.Transparency < 1 then lowest = math.min(lowest, part.Position.Y - part.Size.Y / 2) end
				end
				assert(not part:IsA("Light"), name .. " has no light of its own")
				assert(not part:IsA("LuaSourceContainer"), name .. " runs no script (no brain)")
			end
			near(lowest, spot.Y, 0.1, name .. " feet on the spot")
			equal(model:GetAttribute(Pets.PASSIVE), true, name .. " passive")
			equal(model:GetAttribute("Clip_Idle"), ids.idle, name .. " idle clip")
			equal(model:GetAttribute("Clip_Walk"), ids.walk, name .. " walk clip")
			local controller = model:FindFirstChildOfClass("AnimationController")
			assert(controller and controller:FindFirstChildOfClass("Animator"), name .. " can be animated")
			assert(assets[Pets.SPECIES[name].prefab]:GetScale() == 1, name .. " prefab untouched")
			model:Destroy()
		end
		equal(Pets.build("Lumipol", assets, Vector3.zero, Vector3.zAxis), nil, "not a pet")
		equal(Pets.build("Gomibu", Instance.new("Folder"), Vector3.zero, Vector3.zAxis), nil, "no prefab, no model")
	end)

	case("CP-4: the pet plays its idle clip, the walk clip while it walks, and nothing without ids", function()
		local model = Pets.build("Gomibu", assets, Vector3.zero, Vector3.zAxis, { idle = "rbxassetid://1", walk = "rbxassetid://2" })
		local log = {}
		local function load(_, id)
			local track = { id = id, Looped = false }
			function track:Play() table.insert(log, "play " .. id) end
			function track:Stop() table.insert(log, "stop " .. id) end
			return track
		end
		local tracks = Pets.animate(model, load)
		assert(tracks and tracks.idle and tracks.walk, "two tracks")
		equal(tracks.idle.Looped, true); equal(tracks.walk.Looped, true)
		equal(log[#log], "play rbxassetid://1", "idle at rest")
		model:SetAttribute(Pets.WALKING, true)
		task.wait()
		equal(log[#log], "play rbxassetid://2", "walk while walking")
		equal(log[#log - 1], "stop rbxassetid://1")
		model:SetAttribute(Pets.WALKING, false)
		task.wait()
		equal(log[#log], "play rbxassetid://1", "idle again")
		model:Destroy()
		local bare = Pets.build("Tortidragon", assets, Vector3.zero, Vector3.zAxis, {})
		equal(Pets.animate(bare, load), nil, "no published clip: rest pose")
		bare:Destroy()
	end)

	case("CP-5: a Caramelo egg banks by its nest tier, incubates by rarity and hatches into its species, not equipped", function()
		local state = State.new(Economy, Config)
		state.farmOnly = Species.FARM_ONLY
		state:addPlayer("Alice")
		local TIER = { Gomibu = "Fog", Tortidragon = "FogFar", Flanfuria = "Territory" }
		local SECONDS = { Comun = 15, Rara = 45, Epica = 60 }
		local now = 100
		for _, name in ipairs(PETS) do
			local id = "candy:" .. name
			assert(state:registerEncounter(id, "Egg"))
			local ok, egg = state:pickup("Alice", id, true, 0, { species = name, tier = TIER[name], island = "Candy" })
			equal(ok, true, name .. " picked up")
			local before = state:snapshot("Alice").ember
			equal(state:extract("Alice", true, 0), true, name .. " banked")
			equal(state:snapshot("Alice").ember - before, Config.earn.eggEmberByTier[TIER[name]], name .. " Esencia")
			local banked = state:snapshot("Alice").bankedEggs[1]
			equal(banked.species, name)
			local rarity = EggLoop.rarityOf(banked, Species.LOOKS)
			equal(rarity, RARITY[name], name .. " rarity from its species")
			local seconds = Incubator.hatchSeconds(rarity, Incubator.CONSTANTS.HATCH_SECONDS)
			equal(seconds, SECONDS[rarity], name .. " hatch time")
			equal((state:incubate("Alice", egg, true, 0, now, seconds, 1)), true, name .. " incubating")
			equal(#state:hatchReady("Alice", now + seconds - 0.5), 0, "not early")
			local born = state:hatchReady("Alice", now + seconds)
			equal(#born, 1); equal(born[1].species, name); equal(born[1].equipped, false, name .. " never auto-equipped")
			equal(state:snapshot("Alice").equippedUid, nil)
			local ok2, reason = state:equip("Alice", born[1].uid, true)
			equal(ok2, false); equal(reason, "FarmOnly", name .. " never follows")
			equal((state:placeInFarm("Alice", born[1].uid, true)), true, name .. " goes to the farm")
			now += 1000
		end
		local snap = state:snapshot("Alice")
		equal(#snap.registered, 3); equal(#snap.farm, 3)
		for _, name in ipairs(PETS) do equal(snap.discovered[name], true, name .. " in the collection") end
		-- a Lumipol keeps NS3 (the newborn is the companion when none is out)
		assert(state:registerEncounter("forest", "Egg"))
		local _, lumi = state:pickup("Alice", "forest", true, 0)
		state:extract("Alice", true, 0)
		state:incubate("Alice", lumi, true, 0, now, 15, 1)
		equal(state:hatchReady("Alice", now + 15)[1].equipped, true, "Lumipol unchanged")
	end)

	case("CP-6: a farmed Caramelo pet survives record -> JSON -> profile -> State with no schema change", function()
		local state = State.new(Economy, Config)
		state:addPlayer(1)
		local profile = state.players["n:1"]
		profile.registered = { { uid = "u1", species = "Gomibu" }, { uid = "u2", species = "Flanfuria" },
			{ uid = "u3", species = "Tortidragon" } }
		profile.discovered = { Gomibu = true, Flanfuria = true, Tortidragon = true }
		profile.farm = { "u2", "u3" }
		local base = Record.blank(); base.nextUid = 4
		local schema = Record.SCHEMA
		local record = assert(Record.fromProfile(profile, base, { nowUnix = 1 }, Economy, Config))
		local ok, problems = Record.validate(record, Economy, Config)
		assert(ok == true, table.concat(problems or {}, "; "))
		equal(record.schema, schema, "same schema")
		local _, again = Record.migrate(HttpService:JSONDecode(HttpService:JSONEncode(record)))
		local back = Record.toProfile(again, Economy, Config, 0)
		local fresh = State.new(Economy, Config)
		fresh.farmOnly = Species.FARM_ONLY
		equal(fresh:loadPlayer(1, back), true)
		local snap = fresh:snapshot(1)
		equal(#snap.registered, 3)
		local species = {}
		for _, pet in ipairs(snap.registered) do species[pet.uid] = pet.species end
		equal(species.u1, "Gomibu"); equal(species.u2, "Flanfuria"); equal(species.u3, "Tortidragon")
		equal(snap.farm[1], "u2"); equal(snap.farm[2], "u3")
		equal(select(2, fresh:equip(1, "u1", true)), "FarmOnly", "a loaded Gomibu never follows either")
	end)

	case("CP-7: Spanish names and the refusal words", function()
		equal(Text.CARD.species.Gomibu, "Gomibú"); equal(Text.CARD.species.Tortidragon, "Tortidragón")
		equal(Text.CARD.species.Flanfuria, "Flanfuria")
		assert(type(Text.NOTICES.FarmOnly) == "string" and #Text.NOTICES.FarmOnly <= 90, "Text.NOTICES.FarmOnly")
	end)

	case("CP-8: the server builds the farm pets, animates them and keeps them from following", function()
		local server = sources.server
		assert(server:find("state.farmOnly = Species.FARM_ONLY", 1, true), "State knows the farm-only species")
		assert(server:find("farmModel = function", 1, true), "the Toolbar gets the farm model builder")
		assert(server:find("CandyPets.build(", 1, true), "built from the real prefab")
		assert(server:find("pcall(CandyPets.animate, model)", 1, true), "animated on the server")
	end)

	return result
end

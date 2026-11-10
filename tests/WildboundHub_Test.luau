-- Invoke with require(freshTestClone)(require(freshBasesClone), freshBasesClone.Source, { hub = WildboundHub.Source,
-- stations = WildboundHubStations.Source, server = WildboundServer.Source, client = WildboundClient.Source,
-- rules = require(freshRulesClone), builder = require(freshHubBuilderClone), text = require(freshTextClone),
-- keys = require(freshKeysClone) }).
-- Nest Heist hub (the feature document's "Nest Heist hub", HB-T1 to HB-T5): where the hub is built, the walkable link
-- from the camp, the base slots, and the per-base delivery, incubator, display, glove and training stations. Pure
-- rules plus source contracts for the hub script, the stations module and the inventory server.
return function(Bases, source, sources)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "Expected " .. tostring(expected) .. ", got "
			.. tostring(actual))
	end
	local function near(actual, expected, tolerance, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-6),
			(label and label .. ": " or "") .. "Expected about " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function has(text, needle, label)
		assert(type(text) == "string" and text:find(needle, 1, true), (label or "missing") .. ": " .. needle)
	end
	local function lacks(text, needle, label)
		assert(type(text) == "string" and not text:find(needle, 1, true), (label or "present") .. ": " .. needle)
	end
	local Rules, Builder = sources.rules, sources.builder

	-- HB-T1 placement ----------------------------------------------------------------------------------------------
	case("HB-T1, HF-T3 (S1): the hub origin is one config value, east of the forest kit as the hub plan assumes", function()
		assert(Rules and Rules.finite(Rules.HUB_X) and Rules.finite(Rules.HUB_Z), "Rules.HUB_X and Rules.HUB_Z")
		-- The hub plan's frame puts the forest layout's (0, 0) at (-300, 0); the place builds the forest kit 18 studs
		-- west and 3 north of its layout (measured: Floor, CampCenter, every FK tree), so the hub centre in the place
		-- is the layout's (300, 0) moved the same way.
		equal(Rules.HUB_X, 282, "the forest shift S1: x")
		equal(Rules.HUB_Z, -3, "the forest shift S1: z")
		has(sources.hub, "CFrame.new(Rules.HUB_X, 0, Rules.HUB_Z)", "the hub script builds at the config origin")
	end)
	case("HB-T1: the hub script builds the hub once at server start, in workspace, never inside WildboundP0", function()
		local hub = sources.hub
		has(hub, 'ServerStorage:FindFirstChild("WildboundHubBuilder")', "the builder module from ServerStorage")
		has(hub, "Builder.build(workspace, ", "the parent is workspace")
		has(hub, 'workspace:FindFirstChild("WildboundHub")', "an existing hub is reused")
		lacks(hub, "Builder.build(map", "never inside the forest map")
		lacks(hub, ":PivotTo(", "the forest is not shifted here")
		lacks(hub, "SpawnLocation", "the place's SpawnLocation is kept")
		assert(hub:find('workspace:FindFirstChild("WildboundHub")', 1, true) < hub:find("Builder.build(workspace, ", 1, true),
			"the reuse check comes before the build")
	end)
	case("HB-T1: the builder is the generated one: 390 parts and 19 lights", function()
		equal(Builder.EXPECTED_PARTS, 390)
		equal(Builder.EXPECTED_LIGHTS, 19)
		local nw
		for _, row in ipairs(Builder.DATA.parts) do
			if row.n == "EntranceZone" and row.a and row.a.EntranceId == "NW" then nw = row end
		end
		assert(nw, "the NW entrance zone")
		equal(nw.a.Bearing, 225, "the NW gate looks towards the camp")
	end)
	case("HF-T3 (S1): with the hub beside the forest there is no camp link; a leftover link is removed", function()
		local hub = sources.hub
		equal(Bases.link, nil, "the link rule is gone")
		lacks(hub, "Bases.link(", "no link is built")
		lacks(hub, "buildLink", "no link is built")
		has(hub, 'workspace:FindFirstChild("WildboundHubLink")', "a link saved in the place")
		has(hub, "leftover:Destroy()", "is removed")
	end)
	case("HF-T3 (HB7): the NW and SW forest trails remove exactly the two forest edge trees", function()
		local hub = sources.hub
		assert(type(Bases.REMOVED_FOREST_PROPS) == "table", "Bases.REMOVED_FOREST_PROPS")
		equal(#Bases.REMOVED_FOREST_PROPS, 2)
		equal(Bases.REMOVED_FOREST_PROPS[1], "FK_Evergreen_095"); equal(Bases.REMOVED_FOREST_PROPS[2], "FK_Evergreen_101")
		has(hub, "for _, name in ipairs(Bases.REMOVED_FOREST_PROPS) do", "the hub script removes them")
		has(hub, 'workspace:FindFirstChild("WildboundP0")', "from the forest map")
		has(hub, "prop:Destroy()")
	end)
	case("HF-T3 (HB6): a new character starts on a hub spawn pad facing east, else at the camp", function()
		equal(Bases.spawnIndex(1, 4), 1); equal(Bases.spawnIndex(4, 4), 4); equal(Bases.spawnIndex(5, 4), 1)
		equal(Bases.spawnIndex(8, 4), 4); equal(Bases.spawnIndex(nil, 4), 1); equal(Bases.spawnIndex(0 / 0, 4), 1)
		equal(Bases.spawnIndex(2, 0), nil, "no pad, no index")
		local stations = sources.stations
		has(stations, 'CollectionService:GetTagged("WildboundHubSpawnPad")', "the hub's tagged pads")
		has(stations, 'player:GetAttribute("WildboundBaseSlot")', "the player's own slot picks the pad")
		has(stations, "CFrame.lookAt(at, at + Vector3.xAxis)", "facing east (+X)")
		local server = sources.server
		has(server, "local start = Heist.hub and Heist.hub:spawnFrame(player)", "the hub pad first")
		has(server, "character:PivotTo(start or CFrame.new(campCenter.Position + Vector3.new(0, 4, 10)))",
			"the camp stays the fallback")
	end)

	-- HB-T2 base assignment ---------------------------------------------------------------------------------------
	case("HB-T2: each player gets the lowest free slot, keeps it while present, and a ninth gets none", function()
		local reg = Bases.new(8)
		for index = 1, 8 do equal(Bases.assign(reg, 100 + index), index, "player " .. index) end
		equal(Bases.assign(reg, 103), 3, "the same player keeps the slot (respawn, rejoin in place)")
		equal(Bases.assign(reg, 999), nil, "a ninth player uses the camp")
		equal(Bases.slotOf(reg, 105), 5)
		equal(Bases.ownerOf(reg, 5), 105)
		equal(Bases.release(reg, 105), 5, "released on leave")
		equal(Bases.slotOf(reg, 105), nil)
		equal(Bases.ownerOf(reg, 5), nil)
		equal(Bases.release(reg, 105), nil, "a second release is a no-op")
		equal(Bases.assign(reg, 999), 5, "the next player takes the freed slot")
		equal(Bases.SLOTS, 8)
	end)
	case("HB-T2: invalid ids never take a slot", function()
		local reg = Bases.new(8)
		for _, bad in ipairs({ 0, 1.5, 0 / 0, math.huge, "7", nil }) do equal(Bases.assign(reg, bad), nil, tostring(bad)) end
		equal(Bases.release(reg, "7"), nil)
		equal(Bases.slotOf(reg, nil), nil)
	end)
	case("HB-T2: the sign reads Base libre when free and Base de <name> when owned", function()
		local Text = sources.text
		equal(Text.HUB.freeSign, "Base libre")
		equal(Bases.signText(Text, nil), "Base libre")
		equal(Bases.signText(Text, ""), "Base libre")
		equal(Bases.signText(Text, "Ana"), "Base de Ana")
	end)
	case("HB-T2: the hub script assigns on join, releases on leave and paints the base and the sign", function()
		local hub = sources.hub
		has(hub, "Players.PlayerAdded:Connect(", "join")
		has(hub, "Players.PlayerRemoving:Connect(", "leave")
		has(hub, "Players:GetPlayers()", "players already present at start")
		has(hub, "Bases.assign(registry, player.UserId)")
		has(hub, "Bases.release(registry, player.UserId)")
		has(hub, 'GetTagged("WildboundBaseSlot")', "the base models by tag")
		has(hub, 'GetTagged("WildboundBaseSign")', "the signs by tag")
		has(hub, 'model:SetAttribute("OwnerUserId", ', "the server writes the owner")
		has(hub, 'model:SetAttribute("OwnerName", ', "and the name")
		has(hub, "Bases.signText(Text, ", "the sign's words")
		has(hub, "player.DisplayName", "the display name, never the account name")
		has(hub, 'player:SetAttribute("WildboundBaseSlot", ', "the client can tell which base is its own")
	end)

	-- HB-T3 delivery per base owner -------------------------------------------------------------------------------
	local function between(text, from, to)
		assert(type(text) == "string", "source")
		local start = text:find(from, 1, true)
		assert(start, "missing block start: " .. from)
		local stop = text:find(to, start + #from, true)
		return text:sub(start, stop or #text)
	end
	case("HB-T3: only the owner, standing at the station, may use it; a free base refuses everyone", function()
		equal((Bases.mayUse(7, 7, 3, 8)), true, "the owner at 3 studs")
		equal((Bases.mayUse(7, 7, 8 + Bases.ALLOWANCE, 8)), true, "on the edge plus the latency allowance")
		local ok, why = Bases.mayUse(7, 8, 3, 8)
		equal(ok, false); equal(why, "NotYourBase", "another player's station")
		ok, why = Bases.mayUse(0, 8, 3, 8)
		equal(ok, false); equal(why, "NotYourBase", "a free base is nobody's")
		ok, why = Bases.mayUse(7, 7, 8 + Bases.ALLOWANCE + 0.01, 8)
		equal(ok, false); equal(why, "FarAway")
		for _, bad in ipairs({ 0 / 0, math.huge, -1, "3" }) do
			equal((Bases.mayUse(7, 7, bad, 8)), false, "distance " .. tostring(bad))
		end
		assert(Bases.ALLOWANCE > 0 and Bases.ALLOWANCE <= 2, "a small allowance")
	end)
	case("HB-T3: the hub prompts have their own inputs, distinct from each other, the Burst and the bat", function()
		local Keys = sources.keys
		assert(type(Keys.HUB) == "table", "Keys.HUB")
		local names = { "delivery", "incubator", "glove", "train" }
		for first = 1, #names do
			local a = Keys.HUB[names[first]]
			assert(a and a.key and a.pad and a.offset, names[first])
			assert(a.key ~= Keys.BURST.key and a.pad ~= Keys.BURST.pad and a.pad ~= Keys.BAT.pad, names[first] .. " vs actions")
			for second = first + 1, #names do
				local b = Keys.HUB[names[second]]
				assert(a.key ~= b.key and a.pad ~= b.pad, names[first] .. " and " .. names[second] .. " share an input")
				assert(a.offset[1] ~= b.offset[1] or a.offset[2] ~= b.offset[2], "offsets " .. names[first])
			end
		end
		equal(#Keys.conflicts(), 0, table.concat(Keys.conflicts(), "; "))
	end)
	case("HB-T3: the stations module binds every station by tag and measures the player on the server", function()
		local stations = sources.stations
		has(stations, "CollectionService:GetTagged(tag)", "the tagged stations at start")
		has(stations, "CollectionService:GetInstanceAddedSignal(tag)", "and any built later")
		has(stations, '"WildboundDeliveryStation"')
		has(stations, 'FindFirstAncestorWhichIsA("Model")', "the station's base model")
		has(stations, 'GetAttribute("OwnerUserId")', "the owner the server wrote")
		has(stations, "Bases.mayUse(", "the pure check")
		has(stations, "deps.rootOf(player)", "the server's own position of the player")
		has(stations, "deps.allowed(player, ", "the rate limit")
		has(stations, "Keys.HUB[", "the hub keys")
		lacks(stations, "OnServerEvent", "no remote: prompts only")
	end)
	case("HB-T3: the owner's pedestal banks and secures the egg in the arms; the camp chest still works", function()
		local server = sources.server
		has(server, 'require(script.Parent:WaitForChild("WildboundHubStations"))')
		local delivery = between(server, "delivery = function(player, distance)", "\n\t\t\tend,")
		local carried = delivery:find("EggCarry.carriedBy(eggs, player.UserId)", 1, true)
		local banked = delivery:find("state:extract(player.UserId, ", 1, true)
		local secured = delivery:find("Heist.secure(player)", 1, true)
		assert(carried and banked and secured and carried < banked and banked < secured,
			"carried by this player, then banked, then secured")
		has(delivery, "Text.HUB.noEgg", "no egg in the arms: told so")
		local chest = between(server, "extractPrompt.Triggered:Connect(function(player)", "\nend)")
		has(chest, "Heist.secure(player)", "the camp chest is unchanged")
		local Text = sources.text
		equal(Text.NOTICES.NotYourBase, "Esta no es tu base.")
		assert(type(Text.NOTICES.FarAway) == "string" and type(Text.HUB.noEgg) == "string"
			and type(Text.HUB.delivered) == "string" and type(Text.HUB.deliveryPrompt) == "string", "Spanish words")
	end)
	case("HB-T3: a Studio-only probe runs a station's real prompt path for the Play check", function()
		local server = sources.server
		local probe = between(server, "if RunService:IsStudio() then\n\t\tlocal hubProbe", "hubProbe.Parent = telemetry")
		has(probe, 'hubProbe.Name = "HubProbe"')
		has(probe, "Heist.hub:trigger(player, station)", "the same path as the prompt")
		has(sources.stations, "function Stations:find(kind, slot)")
	end)
	case("HB-T3: each client shows only its own base's station prompts", function()
		local client = sources.client
		has(client, 'GetAttribute("WildboundHubStation")', "the hub prompts are marked")
		has(client, 'GetAttribute("OwnerUserId")', "the base's owner")
		has(client, "Players.LocalPlayer.UserId")
		has(sources.stations, 'SetAttribute("WildboundHubStation", ', "the server marks them")
	end)

	-- HB-T4 incubator per base ------------------------------------------------------------------------------------
	case("HB-T4: the owner's base incubator runs the same incubation as the camp's (one slot, saved state)", function()
		local stations, server = sources.stations, sources.server
		has(stations, '["WildboundIncubatorStation"] = "incubator"', "one tag for every base incubator (HB3)")
		local block = between(server, "incubator = function(player, distance)", "\n\t\t\tend,")
		local carried = block:find("EggCarry.carriedBy(eggs, player.UserId)", 1, true)
		local banked = block:find("state:extract(player.UserId, ", 1, true)
		local secured = block:find("Heist.secure(player)", 1, true)
		local incubated = block:find("hatch(player, uid, distance)", 1, true)
		assert(carried and banked and secured and incubated and carried < banked and banked < secured
			and secured < incubated, "an egg in the arms is delivered, then incubated")
		has(block, "snapshot.bankedEggs[1]", "else the first banked egg")
		has(block, "hatch(player, egg.uid, distance)")
		has(block, "Text.INCUBATOR.noEgg")
		local hatch = between(server, "local function hatch(player, uid, measured)", "\nend\n")
		has(hatch, 'Heist.hub:distance(player, "WildboundIncubatorStation")', "the Bag's Incubar works at the own base too")
		has(hatch, "state:incubate(player.UserId, uid, alive, distance, workspace:GetServerTimeNow()",
			"the Phase 3 incubation on the server's clock")
		has(hatch, "Incubator.live.SLOTS", "still one slot")
		assert(type(sources.text.HUB.incubatorPrompt) == "string", "Text.HUB.incubatorPrompt")
	end)

	-- HB-T5 collection display, gloves and training ------------------------------------------------------------------
	case("HB-T5: the display shows up to three registered Lumipols, the companion first", function()
		local snapshot = { equippedUid = "u3", registered = {
			{ uid = "u1", species = "Lumipol" }, { uid = "u2", species = "Polvilla" }, { uid = "u3", species = "Lumipol" },
			{ uid = "u4", species = "Lumipol" }, { species = "Lumipol" }, { uid = "u5" } } }
		local picks = Bases.displayPicks(snapshot, 3)
		equal(#picks, 3)
		equal(picks[1].uid, "u3", "the companion first")
		equal(picks[2].uid, "u1"); equal(picks[3].uid, "u2")
		equal(#Bases.displayPicks({ registered = { { uid = "u9", species = "Lumipol" } } }, 3), 1)
		equal(#Bases.displayPicks(nil, 3), 0)
		equal(#Bases.displayPicks({ registered = {} }, 3), 0)
		equal(#Bases.displayPicks(snapshot, 0), 0)
	end)
	case("HB-T5: the stations module hovers the owner's Lumipols over the display slots and clears them", function()
		local stations = sources.stations
		has(stations, "function Stations:refreshDisplay(player)")
		has(stations, 'GetTagged("WildboundCollectionDisplay")', "the display platforms by tag")
		has(stations, '"DisplaySlot" .. index', "the builder's three slots")
		has(stations, "deps.Bases.displayPicks(", "the pure choice")
		has(stations, "deps.visual(", "the inventory server's creature look (MeshGen art when it loaded, else primitive)")
		has(stations, '"DisplayLumipol"', "the name the world client bobs")
		has(stations, 'SetAttribute("Base", ', "the hover frame the world client animates from")
		has(stations, 'GetAttributeChangedSignal("OwnerUserId")', "a new or freed owner refreshes the display")
		has(stations, "PlayerRemoving", "a leaving owner's display is cleared")
		has(sources.server, "Heist.hub:refreshDisplay(player)", "every reply refreshes it, like the camp display")
	end)
	case("HB-T5: the glove bench opens the glove screen and lets the owner craft gloves there", function()
		local stations, server = sources.stations, sources.server
		has(stations, '["WildboundGloveStation"] = "glove"')
		local glove = between(server, "glove = function(player)", "\n\t\t\tend,")
		has(glove, 'send(player, "OpenBoard", true, Text.HUB.gloves)', "the client opens the camp screen")
		local craft = between(server, 'if action == "CraftGear" then', 'elseif action == "EquipGlove" then')
		has(craft, 'Heist.hub:distance(player, "WildboundGloveStation")', "the own bench counts as a place to craft gloves")
		has(craft, 'spec.kind == "gloves"', "gloves only; the luck totem stays at the camp")
		has(sources.client, '"WildboundGloveStation"', "the camp screen's buttons work at the own bench")
	end)
	case("HB-T5: the base treadmill uses the Phase 3 training with the measured distance", function()
		local stations, server = sources.stations, sources.server
		has(stations, '["WildboundTrainingStation"] = "train"')
		local train = between(server, "train = function(player, distance, station)", "\n\t\t\tend,")
		has(train, "Heist.train(player, station, distance)")
		local rule = between(server, "function Heist.train(player, console, measured)", "\nend\n")
		has(rule, "if measured then distance = measured end", "the base station's own distance")
		has(rule, "state:train(player.UserId, \"walk\", alive, distance, price, C.MAX_LEVEL)", "the same purchase")
		local Text = sources.text
		assert(type(Text.HUB.glovePrompt) == "string" and type(Text.HUB.gloves) == "string"
			and type(Text.HUB.trainPrompt) == "string", "Spanish words")
	end)

	return result
end

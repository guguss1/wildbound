-- Invoke with require(freshTestClone)(require(freshFieldClone), require(freshConfigClone), require(freshSpawnClone),
-- freshFieldClone.Source, WildboundGather.Source, WildboundServer.Source). M5.3 world gather nodes. ECO numbers
-- refer to docs/mechanics/wildbound-economy-p0.md. Time and randomness are injected.
return function(Field, Config, Spawn, source, gatherSource, serverSource)
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
	local function newField() return Field.new(Config, Spawn) end
	local function sequence()
		local state = 0.137
		return function()
			state = (state * 9301 + 0.4929) % 1
			return state
		end
	end
	local function zoneOf(slotId) return Spawn.slot(Config, slotId).zone end
	-- Fills a field the way the server loop does: plan, then track what GatherSpawn would return.
	local function fill(field, players, now, rand, materialFor)
		local made = {}
		for _, slotId in ipairs(field:plan(players, now, rand)) do
			local slot = Spawn.slot(Config, slotId)
			local node = { id = "Gather:" .. (#made + 1 + (field.serial or 0)), slotId = slotId, zone = slot.zone,
				material = materialFor and materialFor(#made + 1) or "fogbark", heart = slot.heart == true }
			assert(field:track(node), "track " .. slotId)
			table.insert(made, node)
		end
		field.serial = (field.serial or 0) + #made
		return made
	end

	case("ECO-25 the hold follows the band for every slot, and the heart band is the longest", function()
		for _, slot in ipairs(Config.gather.slots) do
			local expected = Config.gather.holdSeconds[slot.heart and "heart" or slot.zone]
			equal(Field.holdFor(Config, slot), expected, slot.id)
		end
		equal(Field.holdFor(Config, Spawn.slot(Config, "O1")), 3)
		equal(Field.holdFor(Config, Spawn.slot(Config, "M1")), 4)
		equal(Field.holdFor(Config, Spawn.slot(Config, "T3")), 6)
		equal(Field.holdFor(Config, Spawn.slot(Config, "T1")), 9)
		equal(Field.holdFor(Config, nil), nil)
	end)

	case("ECO-25 moving during a hold breaks it; standing, small drift and bad numbers are decided exactly", function()
		equal(Field.holdBroken(10, 10, 10, 10), false)
		equal(Field.holdBroken(10, 10, 11, 11), false, "1.4 studs of drift")
		equal(Field.holdBroken(0, 0, Field.MOVE_TOLERANCE, 0), false, "exactly at the tolerance")
		equal(Field.holdBroken(0, 0, Field.MOVE_TOLERANCE + 0.01, 0), true)
		equal(Field.holdBroken(0, 0, 30, 40), true, "walked away")
		equal(Field.holdBroken(0, 0, 3, 0, 4), false, "an explicit tolerance")
		for _, bad in ipairs({ 0 / 0, math.huge, "1", false }) do
			equal(Field.holdBroken(0, 0, bad, 0), true, "bad current x")
			equal(Field.holdBroken(bad, 0, 0, 0), true, "bad start x")
		end
		equal(Field.holdBroken(nil, nil, 0, 0), true, "no hold was started")
		assert(Field.MOVE_TOLERANCE >= 1 and Field.MOVE_TOLERANCE <= 4, "small enough to mean standing still")
	end)

	case("each material reads from its shape as well as its colour, is low, and never blocks the route", function()
		local shapes, names = {}, {}
		for material in pairs(Config.materials) do
			local look = assert(Field.look(material, false), material)
			assert(not shapes[look.shape], "two materials share the shape " .. look.shape)
			shapes[look.shape] = material
			assert(not names[look.name], "two materials share a name")
			names[look.name] = true
			assert(look.size[2] <= 3, material .. " is under 3 studs tall, so nothing hides behind it")
			assert(look.size[1] <= 3 and look.size[3] <= 3, material .. " footprint stays small")
			equal(look.ring, false)
			equal(#look.color, 3)
		end
		equal(Field.look("moonstone", false), nil, "unknown materials have no look")
		local heart = Field.look("fogbark", true)
		equal(heart.ring, true, "a heart slot is marked by a ring, not only by its hold")
		assert(heart.ringDiameter > 6)
		local glowing = 0
		for material in pairs(Config.materials) do
			if Field.look(material, false).glow then glowing += 1 end
		end
		assert(glowing >= 1, "something can be found in the dark")
	end)

	case("ECO-30 the plan keeps the tuned number of nodes per zone for one, two and three players", function()
		for players, expected in pairs({ [1] = 6, [2] = 7, [3] = 8 }) do
			local field = newField()
			local made = fill(field, players, 0, sequence())
			local perZone, seen = { outside = 0, fog = 0, territory = 0 }, {}
			for _, node in ipairs(made) do
				perZone[node.zone] += 1
				assert(not seen[node.slotId], "two nodes in " .. node.slotId)
				seen[node.slotId] = true
			end
			for zone, count in pairs(perZone) do equal(count, expected, players .. " players, " .. zone) end
			equal(#field:plan(players, 0, sequence()), 0, "a full field plans nothing")
		end
	end)

	case("a claimed node frees its place only after the respawn time, then one node comes back", function()
		local field = newField()
		local made = fill(field, 1, 100, sequence())
		local gone = made[1]
		local released = field:release(gone.id, 200, "claimed")
		equal(released.id, gone.id)
		equal(#field:plan(1, 200, sequence()), 0, "nothing at once")
		equal(#field:plan(1, 274.9, sequence()), 0, "not at 74.9 s")
		local due = field:plan(1, 275, sequence())
		equal(#due, 1, "exactly the 75 s respawn")
		equal(zoneOf(due[1]), gone.zone, "a slot of the same zone")
		equal(Config.gather.respawnSeconds, 75)
		equal(#field:plan(1, 276, sequence()), 1, "still due until it is tracked")
		field:track({ id = "Gather:99", slotId = due[1], zone = gone.zone, material = "fogbark" })
		equal(#field:plan(1, 300, sequence()), 0)
	end)

	case("ECO-14 a node is released once: a second claim finds nothing, so it cannot pay twice", function()
		local field = newField()
		local made = fill(field, 1, 0, sequence())
		assert(field:release(made[1].id, 10, "claimed"))
		equal(field:release(made[1].id, 11, "claimed"), nil)
		equal(field:release("Gather:nope", 11, "claimed"), nil)
		equal(field:track({ id = made[2].id, slotId = "T5", zone = "territory" }), false, "an id is never tracked twice")
		equal(field:track({ id = "Gather:1000", slotId = made[2].slotId, zone = made[2].zone }), false, "one node per slot")
		equal(field:track("node"), false)
	end)

	case("the field never holds more than the tuned count in a zone over a long random run", function()
		local field, rand = newField(), sequence()
		local now, nextId = 0, 0
		local live = {}
		for step = 1, 600 do
			now += 7
			for _, slotId in ipairs(field:plan(2, now, rand)) do
				nextId += 1
				local slot = Spawn.slot(Config, slotId)
				local node = { id = "G" .. nextId, slotId = slotId, zone = slot.zone, material = "glowmoss" }
				assert(field:track(node))
				live[node.id] = true
			end
			for _, zone in ipairs(Field.ZONES) do
				assert(field:count(zone) <= Spawn.activeCount(Config, zone, 2), "too many in " .. zone)
			end
			if step % 3 == 0 then
				for id in pairs(live) do
					field:release(id, now, "claimed")
					live[id] = nil
					break
				end
			end
		end
		assert(nextId > 100, "the run really recycled nodes")
	end)

	case("ECO-31 only night-only nodes wilt, only when Night is over, and each wilts once", function()
		local field = newField()
		local made = fill(field, 1, 0, sequence(), function(index) return index <= 2 and "nightbloom" or "fogbark" end)
		equal(#made, 18)
		equal(#field:wilting("Night"), 0, "alive all Night")
		for _, phase in ipairs({ "Dawn", "Day", "Dusk" }) do
			local list = field:wilting(phase)
			equal(#list, 2, phase)
			equal(list[1], made[1].id); equal(list[2], made[2].id)
		end
		for _, id in ipairs(field:wilting("Dawn")) do assert(field:release(id, 50, "wilted")) end
		equal(#field:wilting("Dawn"), 0, "gone once")
		equal(field:count("outside") + field:count("fog") + field:count("territory"), 16, "the common nodes stay")
		equal(#field:plan(1, 51, sequence()), 0, "a wilted node is replaced only after the respawn time")
		equal(#field:plan(1, 125, sequence()), 2, "then both places refill")
	end)

	case("the gather script draws low non-colliding nodes and claims only from a prompt", function()
		assert(type(gatherSource) == "string" and #gatherSource > 1000, "gather source missing")
		for _, needle in ipairs({ "CanCollide = false", "CanQuery = false", "CanTouch = false", "ProximityPrompt",
			"HoldDuration", '"GatherSpawn"', '"GatherClaim"', '"GatherRetire"', "Field.look(", "Field.holdBroken(" }) do
			assert(gatherSource:find(needle, 1, true), "the gather script lacks " .. needle)
		end
		local claims = 0
		for _ in gatherSource:gmatch("gatherClaim:Invoke%(") do claims += 1 end
		equal(claims, 1, "one claim call")
		local before = gatherSource:match("^(.-)gatherClaim:Invoke%(")
		assert(before:find("Triggered:Connect(", 1, true), "the claim sits inside a prompt handler")
		local loop = gatherSource:match("task%.spawn%(function%(%)(.*)$")
		assert(loop, "the field loop is the last block")
		equal(loop:find("gatherClaim", 1, true), nil, "AFK-1 the timer loop never claims")
		assert(loop:find("gatherRetire:Invoke(", 1, true), "the loop only retires wilted nodes")
		for _, banned in ipairs({ "MarketplaceService", "DataStoreService", "ProcessReceipt", "state:" }) do
			equal(gatherSource:find(banned, 1, true), nil, "no " .. banned)
		end
		equal(gatherSource:find("Persistent", 1, true), nil, "nodes follow normal streaming")
	end)

	case("the field module is pure: no services, clock, randomness or persistence", function()
		for _, word in ipairs({ "game", "GetService", "os.", "tick", "Random", "math.random", "DataStore",
			"task.", "workspace", "Instance", "MarketplaceService", "Robux" }) do
			equal(source:find(word, 1, true), nil, "source mentions " .. word)
		end
	end)

	case("the server's claim seam accepts a moved flag and names the refusal for the player", function()
		assert(serverSource:find("function(player, nodeId, moved)", 1, true), "the claim takes the moved flag")
		assert(serverSource:find('"MovedAway"', 1, true), "the refusal is named")
		assert(serverSource:find("MovedAway = ", 1, true), "and has words")
	end)

	return result
end

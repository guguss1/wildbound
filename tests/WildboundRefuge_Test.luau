-- Invoke with require(freshTestClone)(require(freshRefugeClone), freshRefugeClone.Source, require(freshTextClone),
-- { server = WildboundServer.Source, world = WildboundWorldClient.Source, client = WildboundClient.Source,
-- worldServer = WildboundWorld.Source }).
-- Delivery B (B3 to B5): the camp's pure rules. The refuge deposit animation and presentation card, the display
-- spots and their idle motion, and the companion's follow offset. The server and the clients apply them.
return function(Refuge, source, Text, sources)
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
		assert(math.abs(actual - expected) <= (tolerance or 1e-6), (label or "") .. " expected " .. expected .. ", got " .. actual)
	end
	local function words(value, label, limit)
		assert(type(value) == "string" and #value > 0, label .. " missing")
		assert(#value <= limit, label .. " is " .. #value .. " bytes, over " .. limit .. ": " .. value)
		assert(utf8.len(value) ~= nil, label .. " is not valid UTF-8")
	end
	local K = Refuge.CONFIG
	sources = type(sources) == "table" and sources or {}

	case("B3: the deposit animation arcs into the refuge, shrinks and ends", function()
		local first, last = Refuge.depositPose(0), Refuge.depositPose(K.DEPOSIT_SECONDS)
		equal(first.alpha, 0); equal(first.lift, 0); equal(first.scale, 1); equal(first.done, false)
		equal(last.alpha, 1); near(last.lift, 0, 1e-9, "lands"); near(last.scale, K.DEPOSIT_END_SCALE); equal(last.done, true)
		local previous, highest = -1, 0
		for step = 0, 60 do
			local pose = Refuge.depositPose(step / 60 * K.DEPOSIT_SECONDS)
			assert(pose.alpha >= previous, "alpha never goes back")
			previous = pose.alpha
			highest = math.max(highest, pose.lift)
			assert(pose.lift <= K.DEPOSIT_LIFT + 1e-9 and pose.scale <= 1 and pose.scale >= K.DEPOSIT_END_SCALE - 1e-9)
		end
		near(highest, K.DEPOSIT_LIFT, 0.05, "peaks at the arc height")
		local bad = Refuge.depositPose(0 / 0)
		equal(bad.alpha, 0); equal(bad.done, false)
		equal(Refuge.depositPose(99).done, true)
		assert(K.DEPOSIT_SECONDS >= 0.8 and K.DEPOSIT_SECONDS <= 2, "short")
	end)

	case("B3: the presentation card shows a new creature, its collection entry and its Ember", function()
		local card = Refuge.card({ uid = "wb:4", species = "Lumipol", ember = 18, isNew = true, repeated = false }, Text)
		equal(card.title, Text.CARD.title); equal(card.name, Text.CARD.species.Lumipol)
		equal(card.entry, Text.CARD.entry); equal(card.ember, Text.CARD.ember:format(18)); equal(card.uid, "wb:4")
		equal(card.blurb, Text.CARD.blurb.Lumipol); equal(card.equip, Text.CARD.equip); equal(card.close, Text.CARD.close)
		local again = Refuge.card({ uid = "wb:9", species = "Lumipol", ember = 8, isNew = false, repeated = false }, Text)
		equal(again.title, Text.CARD.titleAgain); equal(again.entry, nil, "the entry unlocks only once")
		equal(Refuge.card({ uid = "wb:4", species = "Lumipol", ember = 0, isNew = false, repeated = true }, Text), nil,
			"a repeated registration shows no second card")
		equal(Refuge.card({ uid = "wb:5", species = "Lumipol", ember = 0, isNew = false }, Text).ember, nil, "no Ember line at 0")
		local unknown = Refuge.card({ uid = "wb:6", species = "Mothling", ember = 3, isNew = true }, Text)
		equal(unknown.name, "Mothling"); equal(unknown.blurb, nil)
		for _, bad in ipairs({ nil, {}, { uid = "", species = "Lumipol" }, { uid = "wb:1" } }) do
			equal(Refuge.card(bad, Text), nil)
		end
	end)

	case("B4: each player gets one display spot, first come first served, and never shares it", function()
		local spots = {}
		equal(Refuge.assignSpot(spots, 101, K.DISPLAY_SPOTS), 1)
		equal(Refuge.assignSpot(spots, 202, K.DISPLAY_SPOTS), 2)
		equal(Refuge.assignSpot(spots, 101, K.DISPLAY_SPOTS), 1, "idempotent")
		equal(Refuge.assignSpot(spots, 303, K.DISPLAY_SPOTS), 3)
		equal(Refuge.assignSpot(spots, 404, K.DISPLAY_SPOTS), 4)
		equal(Refuge.assignSpot(spots, 505, K.DISPLAY_SPOTS), nil, "full")
		Refuge.releaseSpot(spots, 202)
		equal(Refuge.assignSpot(spots, 505, K.DISPLAY_SPOTS), 2, "the freed spot is reused")
		local seen = {}
		for key, index in pairs(spots) do
			assert(not seen[index], "two owners on spot " .. index)
			seen[index] = key
		end
		equal(Refuge.assignSpot(spots, nil, K.DISPLAY_SPOTS), nil)
		equal(Refuge.assignSpot(spots, 606, 0), nil)
		equal(K.DISPLAY_SPOTS, 4)
	end)

	case("B4: the display shows the equipped Lumipol, else the first registered one, else nothing", function()
		local snapshot = { registered = { { uid = "a", species = "Lumipol" }, { uid = "b", species = "Lumipol" } }, equippedUid = "b" }
		equal(Refuge.displayChoice(snapshot).uid, "b")
		snapshot.equippedUid = nil
		equal(Refuge.displayChoice(snapshot).uid, "a")
		equal(Refuge.displayChoice({ registered = {} }), nil)
		equal(Refuge.displayChoice({ registered = { "junk", { uid = "c", species = 5 } } }), nil)
		equal(Refuge.displayChoice(nil), nil)
		equal(Refuge.displayChoice({ registered = { { uid = "d", species = "Lumipol" } }, equippedUid = "gone" }).uid, "d")
	end)

	case("B4: the display idle is a small bob and turn, deterministic per seed", function()
		for step = 0, 300 do
			local pose = Refuge.idlePose(step / 30, 1)
			assert(math.abs(pose.y) <= K.IDLE_BOB + 1e-9 and math.abs(pose.yaw) <= K.IDLE_TURN + 1e-9, "bounded")
		end
		local a, b = Refuge.idlePose(2.5, 3), Refuge.idlePose(2.5, 3)
		equal(a.y, b.y); equal(a.yaw, b.yaw)
		assert(Refuge.idlePose(2.5, 1).y ~= Refuge.idlePose(2.5, 2).y, "spots do not bob in step")
		local bad = Refuge.idlePose(0 / 0, 1)
		equal(bad.y, 0); equal(bad.yaw, 0)
	end)

	case("B3 and B4: camp words are Spanish and fit their prompts, signs and card", function()
		local C, D = Text.CAMP, Text.CARD
		for _, key in ipairs({ "register", "chest", "board" }) do words(C[key], key, 24) end
		for _, key in ipairs({ "refuge", "chestObject", "boardObject", "incubatorObject", "display", "incubator" }) do
			words(C[key], key, 28)
		end
		for _, key in ipairs({ "registered", "alreadyRegistered", "nothingCarried", "chestCreature", "chestEmpty", "stored",
			"boardOpen", "incubatorSoon", "equipped" }) do
			words(C[key], key, 72)
		end
		equal(C.register, "Registrar criatura")
		equal(C.incubator, "Deja tu huevo") -- deliberately changed in NB4: the incubator works now
		words(D.title, "card title", 28); words(D.titleAgain, "card again", 28); words(D.entry, "card entry", 40)
		words(D.equip, "equip", 12); words(D.close, "close", 12); words(D.blurb.Lumipol, "blurb", 80)
		assert(D.ember:find("%d", 1, true), "ember is a format")
		assert(C.stored:find("%d", 1, true), "stored is a format")
		words(Text.DISPLAY.owner, "owner", 16)
		assert(Text.DISPLAY.owner:find("%s", 1, true), "owner is a format")
	end)

	case("B3 and B4: the server owns registration, the chest, the board and the display", function()
		local server, client, world = sources.server, sources.client, sources.world
		assert(type(server) == "string" and type(client) == "string" and type(world) == "string", "sources missing")
		for _, needle in ipairs({ "WildboundRefuge", "state:register(", "analytics:registered(", "Keys.CAMP.register",
			"Keys.CAMP.board", "Text.CAMP.register", "Text.CAMP.chest", "Text.CAMP.board", "\"OpenBoard\"", "RefugeMarker",
			"BoardMarker", "Refuge.depositPose", "Refuge.assignSpot", "Refuge.displayChoice" }) do
			assert(server:find(needle, 1, true), "server lacks " .. needle)
		end
		assert(client:find("payload.card", 1, true) and client:find("Refuge.card", 1, true), "the client shows the card")
		assert(client:find("\"OpenBoard\"", 1, true), "the board opens the camp screen")
		assert(world:find("Refuge.idlePose", 1, true), "every client animates the display")
	end)

	case("B5: the companion hovers beside and behind its owner, and hops on a pulse", function()
		for step = 0, 300 do
			local offset = Refuge.companionOffset(step / 30, nil)
			equal(offset.x, K.HOVER_SIDE); equal(offset.z, K.HOVER_BACK)
			assert(math.abs(offset.y - K.HOVER_HEIGHT) <= K.HOVER_BOB + 1e-9, "hover bob bounded")
		end
		assert(K.HOVER_SIDE >= 2.5, "far enough to the side never to block the owner")
		local still = Refuge.companionOffset(1, nil).y
		near(Refuge.companionOffset(1, K.PULSE_SECONDS / 2).y - still, K.PULSE_HOP, 1e-9, "the hop peaks mid-pulse")
		equal(Refuge.companionOffset(1, K.PULSE_SECONDS).y, still, "the hop ends")
		equal(Refuge.companionOffset(1, -1).y, still, "a pulse from the future is ignored")
		local bad = Refuge.companionOffset(0 / 0, 0 / 0)
		equal(bad.y, K.HOVER_HEIGHT)
	end)

	case("B5: the companion is server-owned, replicated, non-colliding, kept through death, and pulses", function()
		local server, world, worldServer = sources.server, sources.world, sources.worldServer
		assert(type(server) == "string" and type(world) == "string" and type(worldServer) == "string", "sources missing")
		for _, needle in ipairs({ "\"WildboundCompanion\"", "AlignPosition", "SetNetworkOwner", "Massless", "CanCollide",
			"WildboundCompanionAnchor", "Refuge.companionOffset", "Text.CAMP.equipped" }) do
			assert(server:find(needle, 1, true), "server lacks " .. needle)
		end
		assert(not world:find("WildboundLocalLumipol", 1, true), "the client-only companion is gone")
		assert(world:find("WildboundCompanionAnchor", 1, true) and world:find("Refuge.companionOffset", 1, true),
			"the owner's client animates the follow point")
		assert(world:find("WildboundPulseAt", 1, true), "every client flashes a pulsing companion")
		assert(worldServer:find("SetAttribute(\"WildboundPulseAt\"", 1, true), "the world server marks an accepted pulse")
	end)

	case("the module source is pure", function()
		assert(type(source) == "string" and #source > 200, "source missing")
		for _, banned in ipairs({ "GetService", "require", "workspace", "game%.", "Instance", "os%.", "tick%(" }) do
			assert(not source:find(banned), "source uses " .. banned)
		end
	end)

	-- Expedition islands (K2): the first card pays the first-steal bonus once, names a new species, and teases the next
	-- island whose species the player has not registered.
	case("K2: the first card names the next unregistered island", function()
		local islands = {
			{ id = "I1", species = "Lumipol" }, { id = "I2", species = "Cortezon" }, { id = "I3", species = "Cestillo" },
		}
		local nextIsland = Refuge.nextIsland(islands, { Lumipol = true })
		equal(nextIsland.id, "I2")
		equal(Refuge.nextIsland(islands, { Lumipol = true, Cortezon = true }).id, "I3")
		equal(Refuge.nextIsland(islands, { Lumipol = true, Cortezon = true, Cestillo = true }), nil, "all found")
		equal(Refuge.nextIsland(nil, {}), nil)
		local card = Refuge.card({ uid = "wb:1", species = "Lumipol", ember = 10, isNew = true, firstEver = true,
			firstBonus = 4, nextIsland = "I2", nextSpecies = "Cortezon" }, Text)
		equal(card.title, Text.CARD.title, "the very first creature")
		equal(card.next, Text.CARD.next:format(Text.ISLAND.names.I2, Text.CARD.species.Cortezon))
		local species = Refuge.card({ uid = "wb:2", species = "Cortezon", ember = 10, isNew = true, firstEver = false, nextIsland = "I3",
			nextSpecies = "Cestillo" }, Text)
		equal(species.title, Text.CARD.newSpecies, "a new species after the first")
		equal(species.name, Text.CARD.species.Cortezon)
		equal(Refuge.card({ uid = "wb:3", species = "Lumipol", ember = 6, isNew = false }, Text).next, nil, "no tease")
	end)

	case("K2: the first-steal bonus is paid once", function()
		local first = Refuge.card({ uid = "wb:1", species = "Lumipol", ember = 10, isNew = true, firstEver = true,
			firstBonus = 4 }, Text)
		equal(first.bonus, Text.CARD.firstBonus:format(4))
		equal(first.ember, Text.CARD.ember:format(6), "the cria's own Ember, the bonus on its own line")
		local later = Refuge.card({ uid = "wb:2", species = "Lumipol", ember = 6, isNew = false, firstBonus = 0 }, Text)
		equal(later.bonus, nil)
		equal(later.ember, Text.CARD.ember:format(6))
	end)

	case("K2: the display shows any registered species", function()
		local snapshot = { registered = { { uid = "a", species = "Cortezon" }, { uid = "b", species = "Lumipol" } } }
		equal(Refuge.displayChoice(snapshot).uid, "a")
		snapshot.equippedUid = "b"
		equal(Refuge.displayChoice(snapshot).uid, "b")
	end)

	return result
end

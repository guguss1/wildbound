-- Invoke with require(freshTestClone)(require(freshRefugeClone), freshRefugeClone.Source, require(freshTextClone),
-- { server = WildboundServer.Source, world = WildboundWorldClient.Source, client = WildboundClient.Source }).
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
		equal(C.incubator, "Próximamente")
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

	case("the module source is pure", function()
		assert(type(source) == "string" and #source > 200, "source missing")
		for _, banned in ipairs({ "GetService", "require", "workspace", "game%.", "Instance", "os%.", "tick%(" }) do
			assert(not source:find(banned), "source uses " .. banned)
		end
	end)

	return result
end

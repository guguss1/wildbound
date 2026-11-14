-- Invoke with require(freshTestClone)(require(freshBaseZoneClone), freshBaseZoneClone.Source, { server =
-- WildboundServer.Source, guide = WildboundBaseGuideClient.Source, text = require(freshTextClone) }).
-- Hub expansion T8 (docs/design/wildbound-hub-expansion.md section 7): walking into your own base banks everything,
-- puts a carried egg in the incubator and says "¡Estás a salvo!". The pure zone rule (local-frame box, exit margin
-- hysteresis, banner limit, the saved line) and the source contracts for how the inventory server and the guide
-- client wire it.
return function(Zone, source, sources)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got "
			.. tostring(actual))
	end
	local function has(text, needle, label)
		assert(type(text) == "string" and text:find(needle, 1, true), (label or needle) .. " missing")
	end
	sources = type(sources) == "table" and sources or {}
	-- A base like the hub's: 30.2 x 12 x 24.2 box turned 90 degrees, centred at (100, 6, 50), exit margin 2.
	local zone = { frame = CFrame.new(100, 6, 50) * CFrame.Angles(0, math.rad(90), 0), size = Vector3.new(30.2, 12, 24.2),
		margin = 2 }

	case("BZ1: the defaults: a 4 Hz step, a 2-stud exit margin, a 2.5 s banner at most every 10 s", function()
		local C = Zone.CONSTANTS
		equal(C.STEP_HZ, 4); equal(C.EXIT_MARGIN, 2); equal(C.BANNER_SECONDS, 2.5); equal(C.BANNER_COOLDOWN, 10)
		assert(table.isfrozen(C), "frozen")
	end)

	case("BZ2: inside is measured in the zone's own frame, half extents and height", function()
		-- Turned 90 degrees: the 30.2 side runs along world Z.
		equal(Zone.contains(zone, Vector3.new(100, 3, 50 + 14)), true, "along the long side")
		equal(Zone.contains(zone, Vector3.new(100 + 14, 3, 50)), false, "past the short side")
		equal(Zone.contains(zone, Vector3.new(100, 13, 50)), false, "above the height")
		equal(Zone.contains(zone, Vector3.new(100 + 13, 3, 50), 2), true, "the margin widens it")
		equal(Zone.contains(nil, Vector3.new(100, 3, 50)), false, "no zone")
		equal(Zone.contains(zone, nil), false, "no position")
	end)

	case("BZ3: entering fires once; leaving needs the margin (hysteresis); re-entering fires again", function()
		local tracker = Zone.new()
		local inside, edge, out = Vector3.new(100, 3, 50), Vector3.new(100 + 13, 3, 50), Vector3.new(100 + 20, 3, 50)
		equal(Zone.step(tracker, 1, zone, out), nil, "outside")
		equal(Zone.step(tracker, 1, zone, inside), "Enter", "walk in")
		equal(Zone.step(tracker, 1, zone, inside), nil, "still inside: once per entry")
		equal(Zone.step(tracker, 1, zone, edge), nil, "on the edge, within the margin: still inside")
		equal(Zone.step(tracker, 1, zone, inside), nil, "back in: no second entry")
		equal(Zone.step(tracker, 1, zone, out), "Leave", "past the margin")
		equal(Zone.step(tracker, 1, zone, inside), "Enter", "a new entry")
		equal(Zone.step(tracker, 1, nil, inside), "Leave", "no own zone (another player's base): out")
		equal(Zone.step(tracker, 2, nil, inside), nil, "a player with no base never enters")
		Zone.forget(tracker, 1)
		equal(Zone.step(tracker, 1, zone, inside), "Enter", "forgotten on leave or respawn")
	end)

	case("BZ4: the banner shows at most every 10 s per player", function()
		local tracker = Zone.new()
		equal(Zone.banner(tracker, 1, 100), true, "first")
		equal(Zone.banner(tracker, 1, 105), false, "5 s later")
		equal(Zone.banner(tracker, 2, 105), true, "another player")
		equal(Zone.banner(tracker, 1, 110), true, "10 s later")
	end)

	case("BZ5: the saved line names the egg and the other items", function()
		local Text = sources.text
		assert(type(Text) == "table" and type(Text.HUB) == "table", "text module")
		local H = Text.HUB
		equal(Zone.line(H, "Incubating", 3), H.safeEgg .. H.safeJoin .. H.safeItems:format(3))
		equal(Zone.line(H, "Banked", 0), H.safeEggBanked)
		equal(Zone.line(H, nil, 2), H.safeItems:format(2))
		equal(Zone.line(H, nil, 0), "", "nothing saved")
		equal(H.safeBanner, "¡Estás a salvo!")
		equal(H.incubatorFull, "Tu incubadora está llena: guardamos el huevo")
		equal(H.dropHere, "Deja el huevo aquí")
		assert(#H.goBase:format(120) <= 48, "the hint fits the HUD")
	end)

	case("BZ9: isInside answers from the tracker (the hatch step's refill check)", function()
		local tracker = Zone.new()
		equal(Zone.isInside(tracker, 1), false, "never entered")
		Zone.step(tracker, 1, zone, Vector3.new(100, 3, 50))
		equal(Zone.isInside(tracker, 1), true, "inside")
		Zone.forget(tracker, 1)
		equal(Zone.isInside(tracker, 1), false, "forgotten")
		equal(Zone.isInside(nil, 1), false, "no tracker")
	end)

	case("BZ6: pure: no services, clock or world in the rule", function()
		for _, needle in ipairs({ "GetService", "os.time", "os.clock", "tick()", "workspace", "Touched" }) do
			assert(not source:find(needle, 1, true), "source has " .. needle)
		end
	end)

	case("BZ7: the server steps the zones at 4 Hz in the hub disc, only the owner's zone, egg first, never Touched", function()
		local server = sources.server
		assert(type(server) == "string" and #server > 1000, "server source")
		has(server, 'require(script.Parent:WaitForChild("WildboundBaseZone"))')
		has(server, "function Heist.stepBaseZones(now)")
		has(server, "function Heist.enterBase(player, now)")
		has(server, 'CollectionService:GetTagged("WildboundBaseZone")')
		has(server, "Heist.hub:ownerOf(part) == player.UserId", "only the owner's zone")
		has(server, "Rules.HUB_RADIUS", "the hub disc only")
		has(server, "1 / Heist.BaseZone.CONSTANTS.STEP_HZ", "the 4 Hz step")
		local enter = server:match("function Heist%.enterBase%(player, now%)(.-)\nend\n")
		assert(enter, "enterBase body")
		-- Deliberately changed (egg loop, docs/design/wildbound-egg-loop.md): the egg is banked into the collection
		-- first and the oldest stored egg then fills a free cradle (Heist.autoIncubate holds the state:incubate call).
		local carried = enter:find("EggCarry.carriedBy(eggs, player.UserId)", 1, true)
		local extract = enter:find("state:extract(", 1, true)
		local secure = enter:find("Heist.secure(player)", 1, true)
		local incubate = enter:find("Heist.autoIncubate(player", 1, true)
		assert(carried and extract and secure and incubate and carried < extract and extract < secure
			and secure < incubate, "carried egg read, banked with the bag, secured, then the cradle filled")
		local auto = server:match("function Heist%.autoIncubate%((.-)\nend\n")
		assert(auto and auto:find("state:incubate(", 1, true), "autoIncubate incubates")
		has(enter, "Text.HUB.incubatorFull", "a full incubator keeps the egg banked and says so")
		has(enter, "Heist.BaseZone.banner(", "the banner limit")
		has(enter, '"WildboundSafeBanner"', "the banner reaches the client as an attribute")
		local zones = server:match("function Heist%.stepBaseZones%(now%)(.-)\nend\n") or ""
		assert(not zones:find("Touched", 1, true) and not enter:find("Touched", 1, true), "never Touched")
	end)

	case("BZ8: the guide client shows the beacon, the billboard and the HUD hint only while carrying", function()
		local guide = sources.guide
		assert(type(guide) == "string" and #guide > 200, "guide source")
		has(guide, 'FindFirstChild("WildboundEggCarried")', "carrying = the server's backpack on the character")
		has(guide, "Text.HUB.dropHere"); has(guide, "Text.HUB.goBase"); has(guide, "Text.HUB.safeBanner")
		has(guide, '"WildboundSafeBanner"')
		has(guide, '"OwnerUserId"', "the own base")
		has(guide, "Highlight", "the own base pad stands out")
		assert(not guide:find("FireServer", 1, true) and not guide:find("InvokeServer", 1, true), "the client sends nothing")
	end)

	return result
end
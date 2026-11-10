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
	case("HB-T1: the hub origin is one config value in the world rules, a translation only", function()
		assert(Rules and Rules.finite(Rules.HUB_X) and Rules.finite(Rules.HUB_Z), "Rules.HUB_X and Rules.HUB_Z")
		equal(Rules.HUB_X, 0, "preview origin x (until the forest shift S1)")
		equal(Rules.HUB_Z, 600, "preview origin z (until the forest shift S1)")
		has(sources.hub, "CFrame.new(Rules.HUB_X, 0, Rules.HUB_Z)", "the hub script builds at the config origin")
	end)
	case("HB-T1: the hub script builds the hub once at server start, in workspace, never inside WildboundP0", function()
		local hub = sources.hub
		has(hub, 'ServerStorage:FindFirstChild("WildboundHubBuilder")', "the builder module from ServerStorage")
		has(hub, "Builder.build(workspace, ", "the parent is workspace")
		has(hub, 'workspace:FindFirstChild("WildboundHub")', "an existing hub is reused")
		lacks(hub, "Builder.build(map", "never inside the forest map")
		lacks(hub, ":PivotTo(", "the forest is not shifted here")
		lacks(hub, "SpawnLocation", "the spawn stays at the camp")
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
	case("HB-T1: the link runs from inside the camp circle to the NW trail's outer end, straight and wide", function()
		local camp = { x = Rules.CAMP_X, z = Rules.CAMP_Z, r = Rules.CAMP_RADIUS }
		local link = Bases.link(camp.x, camp.z, Rules.HUB_X, Rules.HUB_Z)
		assert(type(link) == "table", "a link")
		assert(Rules.distance(link.fromX, link.fromZ, camp.x, camp.z) < camp.r - 5, "starts inside the camp circle")
		near(Rules.distance(Bases.LINK_END.x, Bases.LINK_END.z, -112, -90), 0, 1e-6, "the plan's NW trail end")
		local endX, endZ = Rules.HUB_X + Bases.LINK_END.x, Rules.HUB_Z + Bases.LINK_END.z
		assert(Rules.distance(link.toX, link.toZ, endX, endZ) <= 5, "ends on the trail's outer end (overlapping it)")
		assert(Rules.distance(link.toX, link.toZ, Rules.HUB_X, Rules.HUB_Z) > 88, "outside the hedge, on the trail")
		local angle = math.deg(math.atan2(Bases.LINK_END.z, Bases.LINK_END.x)) % 360
		assert(math.abs(angle - 225) < 20, "beyond the NW gate (bearing 225), got " .. angle)
		assert(link.width >= 10, "wide enough for two players")
		near(link.length, Rules.distance(link.fromX, link.fromZ, link.toX, link.toZ), 1e-6, "length")
		-- The forest shift moves both ends with the one origin value.
		local moved = Bases.link(camp.x, camp.z, Rules.HUB_X - 300, Rules.HUB_Z)
		near(moved.toX - link.toX, -300, 4, "the end follows the origin")
	end)
	case("HB-T1: the hub script builds the link outside the forest map, with Spanish signs", function()
		local hub = sources.hub
		has(hub, "Bases.link(Rules.CAMP_X, Rules.CAMP_Z, Rules.HUB_X, Rules.HUB_Z)", "the link geometry is the pure rule's")
		equal(Rules.CAMP_X, -140); equal(Rules.CAMP_Z, 140); equal(Rules.CAMP_RADIUS, 35)
		has(hub, '"WildboundHubLink"', "its own model")
		has(hub, "link.Parent = workspace", "outside WildboundP0")
		has(hub, "Text.HUB.linkSign", "the sign's words come from the text module")
		assert(type(sources.text.HUB) == "table" and type(sources.text.HUB.linkSign) == "string", "Text.HUB.linkSign")
	end)

	return result
end

-- Invoke with require(freshTestClone)(require(freshBiomeLightClone), freshBiomeLightClone.Source,
-- { biomes = require(freshBiomesClone), atmosphere = require(freshAtmosphereClone),
-- worldClient = WildboundWorldClient.Source, world = WildboundWorld.Source }).
-- CA4 (user, 2026-11-15; Caramelo pack 05_SISTEMAS/02_ILUMINACION_POR_BIOMA.md): fixed light per biome and no global
-- day/night cycle. Caramelo is always day, the forest always night, the swamp a green dusk, the cemetery a violet
-- twilight; each client picks the preset of the biome it stands in and blends to it in about one second, changing only
-- its own Lighting.
return function(BiomeLight, source, sources)
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
		assert(type(text) == "string" and text:find(needle, 1, true), (label or "missing") .. ": " .. needle)
	end
	sources = type(sources) == "table" and sources or {}

	case("CA4: every preset has a mood, a clock and a label, and the table is frozen", function()
		assert(type(BiomeLight) == "table" and type(BiomeLight.PRESETS) == "table", "module missing")
		assert(table.isfrozen(BiomeLight.PRESETS), "frozen presets")
		local moods = { Day = true, Dusk = true, Night = true }
		for name, preset in pairs(BiomeLight.PRESETS) do
			assert(moods[preset.mood], name .. " mood")
			assert(type(preset.clockTime) == "number" and preset.clockTime >= 0 and preset.clockTime < 24, name .. " clock")
			assert(type(preset.label) == "string" and #preset.label > 0, name .. " label")
			assert(table.isfrozen(preset), name .. " frozen")
		end
		equal(BiomeLight.PRESETS.Caramelo.mood, "Day")
		equal(BiomeLight.PRESETS.Forest.mood, "Night")
		equal(BiomeLight.PRESETS.Swamp.mood, "Dusk")
		equal(BiomeLight.PRESETS.Cemetery.mood, "Dusk")
		equal(BiomeLight.PRESETS.Hub.mood, "Day")
	end)

	case("CA4: the preset follows the biome a point stands in", function()
		for _, sample in ipairs({ { 620, -7, "Caramelo" }, { 452, -21, "Caramelo" }, { 0, -85, "Forest" },
			{ -140, 140, "Forest" }, { 282, -3, "Hub" }, { 282, -443, "Swamp" }, { 282, 387, "Cemetery" },
			{ -108, -393, "Abyss" }, { 772, -493, "Mountains" }, { -108, 437, "Volcanic" }, { 622, 387, "Caves" },
			{ 115, 15, "Forest" }, { 5000, 5000, "Hub" } }) do
			local name, preset = BiomeLight.presetAt(sample[1], sample[2], "classic")
			equal(name, sample[3], ("at %d, %d"):format(sample[1], sample[2]))
			equal(preset, BiomeLight.PRESETS[sample[3]])
		end
		for _, bad in ipairs({ { 0 / 0, 0 }, { 0, math.huge }, { "1", 2 } }) do
			equal((BiomeLight.presetAt(bad[1], bad[2], "classic")), "Hub", "a bad point")
		end
	end)

	-- Big4 map experiment (odd/tasks/wildbound-big4-map.md): four larger biomes; the archived ones read as the hub.
	case("BIG4: the preset follows the four larger biomes, and the archived squares read as the hub", function()
		assert(type(BiomeLight.AREAS_BIG4) == "table" and table.isfrozen(BiomeLight.AREAS_BIG4), "frozen AREAS_BIG4")
		equal(#BiomeLight.AREAS_BIG4, 4, "four squares")
		for _, sample in ipairs({ { 620, -7, "Caramelo" }, { 452, -21, "Caramelo" }, { 0, -85, "Forest" },
			{ -140, 140, "Forest" }, { -500, -400, "Forest" }, { 100, -500, "Forest" }, { 900, 0, "Caramelo" },
			{ 600, 450, "Caramelo" }, { 1000, 530, "Caramelo" }, { 772, -493, "Mountains" }, { 300, -900, "Mountains" },
			{ 286, -336, "Mountains" }, { -108, 437, "Volcanic" }, { -600, 900, "Volcanic" }, { 73, 370, "Volcanic" },
			{ 282, -3, "Hub" }, { 282, 387, "Hub" }, { 115, 15, "Forest" }, { 5000, 5000, "Hub" },
			{ 200, 400, "Hub" }, { 200, -150, "Hub" } }) do
			local name, preset = BiomeLight.presetAt(sample[1], sample[2], "big4")
			equal(name, sample[3], ("big4 at %d, %d"):format(sample[1], sample[2]))
			equal(preset, BiomeLight.PRESETS[sample[3]])
		end
		-- The old Pantano, Cementerio, Abismo and Cuevas centres: Hub, or swallowed by a grown neighbour.
		equal((BiomeLight.presetAt(282, -443, "big4")), "Mountains", "old Pantano centre is now inside Montañas")
		equal((BiomeLight.presetAt(-108, -393, "big4")), "Forest", "old Abismo centre is now outer forest")
		equal((BiomeLight.presetAt(622, 387, "big4")), "Caramelo", "old Cuevas centre is now the Caramelo annex")
		equal((BiomeLight.presetAt(0 / 0, 0, "big4")), "Hub", "a bad point")
		equal((BiomeLight.phaseAt(-500, -400, "big4")), "Night", "the outer forest plays by Night rules")
		equal((BiomeLight.phaseAt(900, 400, "big4")), "Day", "the Caramelo annex plays by Day rules")
		equal((BiomeLight.phaseAt(-600, 900, "big4")), "Day", "Volcán keeps Day rules")
	end)

	case("BIG4: an unknown mode reads as classic, and areasFor picks the table", function()
		equal(BiomeLight.areasFor("classic"), BiomeLight.AREAS)
		equal(BiomeLight.areasFor("big4"), BiomeLight.AREAS_BIG4)
		equal(BiomeLight.areasFor("nonsense"), BiomeLight.AREAS)
		equal((BiomeLight.presetAt(282, -443, "nonsense")), "Swamp")
		equal(BiomeLight.MODE_ATTRIBUTE, "WildboundMapMode")
		local mode = BiomeLight.mode()
		assert(mode == "classic" or mode == "big4", "mode() is classic or big4, got " .. tostring(mode))
	end)

	case("BIG4: the big4 squares are the server's big4 squares (WildboundBiomes.AREAS_BIG4)", function()
		local Biomes = sources.biomes
		assert(type(Biomes) == "table" and type(Biomes.AREAS_BIG4) == "table", "biomes big4 not passed")
		local want, total = {}, 0
		for _, area in ipairs(Biomes.AREAS_BIG4) do
			if area.kind == "square" then
				want[area.tag] = ("%g,%g,%g,%g"):format(area.minX, area.maxX, area.minZ, area.maxZ)
				total += 1
			end
		end
		for _, area in ipairs(BiomeLight.AREAS_BIG4) do
			equal(("%g,%g,%g,%g"):format(area.minX, area.maxX, area.minZ, area.maxZ), want[area.tag], area.tag)
		end
		equal(#BiomeLight.AREAS_BIG4, total, "one square per server square")
		equal(Biomes.MODE_ATTRIBUTE, BiomeLight.MODE_ATTRIBUTE, "one attribute name")
	end)

	case("CA4: the squares are the server's biome squares (WildboundBiomes.AREAS)", function()
		local Biomes = sources.biomes
		assert(type(Biomes) == "table" and type(Biomes.AREAS) == "table", "biomes not passed")
		local want = {}
		for _, area in ipairs(Biomes.AREAS) do
			if area.kind == "square" then
				want[area.tag] = ("%g,%g,%g,%g"):format(area.minX, area.maxX, area.minZ, area.maxZ)
			end
		end
		local seen = 0
		for _, area in ipairs(BiomeLight.AREAS) do
			equal(("%g,%g,%g,%g"):format(area.minX, area.maxX, area.minZ, area.maxZ), want[area.tag], area.tag)
			seen += 1
		end
		local total = 0
		for _ in pairs(want) do total += 1 end
		equal(seen, total, "one square per server square")
	end)

	case("CA4: Caramelo is always bright and the forest always dark", function()
		local Atmos = sources.atmosphere
		assert(type(Atmos) == "table", "atmosphere not passed")
		local candy = BiomeLight.target(Atmos, "Caramelo", "open", false)
		equal(candy.brightness, 1, "Caramelo brightness")
		equal(candy.exposure, 0, "Caramelo exposure")
		equal(candy.ambientWeight, 0, "the place's own ambient")
		assert(candy.fogEnd >= 400, "a long view: " .. candy.fogEnd)
		assert(candy.density <= 0.4, "a light haze: " .. candy.density)
		equal(candy.tint.r, 255)
		assert(candy.saturation > 0 and candy.contrast > 0 and candy.lift > 0, "pastel grading")
		-- The wave's biome variant never reaches Caramelo, so a refresh never changes its light.
		local withVariant = BiomeLight.target(Atmos, "Caramelo", "open", false, "Ceniza")
		equal(withVariant.tint.g, 255, "no variant tint in Caramelo")
		equal(withVariant.fogEnd, candy.fogEnd)
		local forest = BiomeLight.target(Atmos, "Forest", "fog", false, "Niebla")
		assert(forest.brightness <= 0.4 and forest.exposure <= -0.5, "the forest is night")
		assert(forest.fogEnd < candy.fogEnd, "the forest is foggier")
		assert(forest.tint.r < 255, "the forest keeps the wave variant")
		local camp = BiomeLight.target(Atmos, "Forest", "camp", false)
		assert(camp.fogEnd > forest.fogEnd, "the camp inside the forest keeps its clearer fog")
		local unknown = BiomeLight.target(Atmos, "Nowhere", "open", false)
		equal(unknown.brightness, 1, "an unknown preset reads as the hub's day")
	end)

	case("CA4: the blend crosses a biome in 0.8 to 1.5 s", function()
		equal(BiomeLight.BLEND_SECONDS, 1)
		assert(BiomeLight.alpha(1) >= 0.95, "95% of the way after one second")
		assert(BiomeLight.alpha(0.5) < 0.95, "not instant")
		assert(BiomeLight.alpha(0.1) > 0 and BiomeLight.alpha(0.1) < 1)
		equal(BiomeLight.alpha(0 / 0), 0)
		equal(BiomeLight.alpha(-1), 0)
	end)

	case("CA4: the module is pure", function()
		assert(type(source) == "string" and #source > 0, "source")
		-- BIG4: the one allowed read of the place is the map mode block, and it only reads the mode attribute.
		local first, last = source:find("-- MAPMODE BEGIN", 1, true), source:find("-- MAPMODE END", 1, true)
		local rest = source
		if first then
			assert(last and last > first, "the map mode block is closed")
			local block = source:sub(first, last)
			has(block, 'game:GetService("Workspace")', "the mode block reads Workspace")
			has(block, "GetAttribute, modeRoot, BiomeLight.MODE_ATTRIBUTE", "the mode block reads only the attribute")
			for _, banned in ipairs({ "SetAttribute", "task.", "os.", "Lighting", "Players", "Changed" }) do
				assert(not block:find(banned, 1, true), "the mode block uses " .. banned)
			end
			assert(select(2, source:gsub("MAPMODE BEGIN", "")) == 1, "one mode block")
			rest = source:sub(1, first - 1) .. source:sub(last + #"-- MAPMODE END")
		end
		for _, banned in ipairs({ "game:", "workspace", "task.", "os.time", "os.clock", "math.random", "tick(", "Lighting" }) do
			assert(not rest:find(banned, 1, true), "reads " .. banned)
		end
	end)

	case("CA4: the world client applies the local biome preset, never the server's clock", function()
		local client = sources.worldClient or ""
		has(client, 'ReplicatedStorage:WaitForChild("WildboundBiomeLight", 10)')
		has(client, "BiomeLight.presetAt(root.Position.X, root.Position.Z)")
		has(client, "BiomeLight.target(Atmos, lightName,")
		has(client, "BiomeLight.alpha(step)")
		has(client, "light.clockTime - Lighting.ClockTime")
		has(client, 'gui:SetAttribute("Phase", light.mood)')
		assert(not client:find("state.clockTime", 1, true), "the server's clock no longer drives the sky")
		assert(not client:find('gui:SetAttribute("Phase", payload.phase)', 1, true), "the phase is the local biome's")
		has(client, "variantTint.Saturation", "the pastel grading")
		local world = sources.world or ""
		assert(not world:find("Lighting.ClockTime =", 1, true), "the server never changes everyone's light")
	end)

	return result
end

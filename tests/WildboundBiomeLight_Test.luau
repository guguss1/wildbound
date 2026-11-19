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
		-- Deliberately changed (PGM-D3, owner request 2026-11-18 "Sí, movelo"): the Cemetery sample moves north of the
		-- south arm (Pueblo Gatito's square, first, holds z 337..937) (was 282, 387)
		-- GL-D2 (owner request 2026-11-19 "hace el mapa bastante mas largo"): the arm holds z 337..1537 now; every sample
		-- here is outside it either way
		for _, sample in ipairs({ { 620, -7, "Caramelo" }, { 452, -21, "Caramelo" }, { 0, -85, "Forest" },
			{ -140, 140, "Forest" }, { 282, -3, "Hub" }, { 282, -443, "Swamp" }, { 282, 287, "Cemetery" },
			{ -108, -393, "Abyss" }, { 772, -493, "Mountains" }, { -108, 437, "Volcanic" }, { 622, 387, "Caves" },
			{ 115, 15, "Forest" }, { 5000, 5000, "Hub" } }) do
			local name, preset = BiomeLight.presetAt(sample[1], sample[2])
			equal(name, sample[3], ("at %d, %d"):format(sample[1], sample[2]))
			equal(preset, BiomeLight.PRESETS[sample[3]])
		end
		for _, bad in ipairs({ { 0 / 0, 0 }, { 0, math.huge }, { "1", 2 } }) do
			equal((BiomeLight.presetAt(bad[1], bad[2])), "Hub", "a bad point")
		end
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

	-- V8-D2 (owner request 2026-11-17, "another space of the same size, separated by clouds"): Caramelo Este (the cloud
	-- band and the second space east of the bigger plot) is its own square and tag, with Day rules. K-D14 gives it the
	-- kitten park's own light (it had the Caramelo light).
	case("V8-D2: Caramelo Este is its own square, lit as Pueblo Gatito (K-D14), played by Day", function()
		local row
		for _, area in ipairs(BiomeLight.AREAS) do
			if area.tag == "CandyEast" then
				assert(row == nil, "one CandyEast row")
				row = area
			end
		end
		assert(row, "no CandyEast row")
		-- Deliberately changed (PGM-D3, owner request 2026-11-18 "Sí, movelo"): the park moved to the big4 south arm, and
		-- the square is the whole arm (WildboundGatitoArea.ARM) (was "932,1468,-263,257", the band and the space)
		-- Deliberately changed (GL-D2, owner request 2026-11-19 "hace el mapa bastante mas largo"): the south arm is 600 x
		-- 1200 now, z 337..1537 (was "-3,597,337,937")
		equal(("%g,%g,%g,%g"):format(row.minX, row.maxX, row.minZ, row.maxZ), "-3,597,337,1537", "the south arm")
		-- Deliberately changed (K-D14): the owner's "es como el mundo de gatito: un parque verde lindo ..." gives Caramelo
		-- Este its own Gatuno preset (a blue sky and a long, clear view) in place of the Caramelo one.
		equal(BiomeLight.TAG_PRESET.CandyEast, "Gatuno", "the Gatuno preset")
		-- Deliberately changed (PGM-D3): samples inside the arm, the park's centre, a corner over the Volcanic square
		-- and the far corner (were 940, -3; 1208, -3; 1460, 250; 960, -240)
		-- Deliberately changed (GL-D2): a sample by the grown arm's far corner, (590, 1530)
		for _, sample in ipairs({ { 282, 600 }, { 30, 360 }, { 590, 930 }, { 590, 1530 } }) do
			local name, preset = BiomeLight.presetAt(sample[1], sample[2])
			equal(name, "Gatuno", ("at %d, %d"):format(sample[1], sample[2]))
			equal(preset, BiomeLight.PRESETS.Gatuno)
			equal((BiomeLight.phaseAt(sample[1], sample[2])), "Day", "Day rules")
		end
		-- Deliberately changed (PGM-D3): past the arm's far end, and the road north of it (was 1500, -3, "past the second
		-- space")
		-- Deliberately changed (GL-D2): the arm's far end is z 1537 now, so the probe moves past it (was 282, 940)
		assert((BiomeLight.presetAt(282, 1540)) ~= "Gatuno", "past the arm's far end is no Pueblo Gatito (Hub in classic)")
		assert((BiomeLight.presetAt(282, 300)) ~= "Gatuno", "north of the arm is no Pueblo Gatito")
		local Biomes = sources.biomes
		if type(Biomes) == "table" and type(Biomes.at) == "function" then
			-- Deliberately changed (PGM-D3): the park's centre (282, 600) (was 1208, -3)
			local tags = Biomes.at(282, 600)
			equal(tags.CandyEast, true, "the server's CandyEast tag")
			equal(tags.Meadow, nil, "no Meadow rules there")
			-- Deliberately changed (PGM-D3): the old west strip (960, 0) is no Pueblo Gatito now (was CandyEast true,
			-- Meadow nil); whether it is Meadow depends on the copy (big4's Meadow runs to x 1012, classic's to 812)
			equal(Biomes.at(960, 0).CandyEast, nil, "the old park's west strip is no CandyEast")
			equal(Biomes.at(900, 0).CandyEast, nil, "the plot west of the band is no CandyEast")
			equal(Biomes.at(612, -3).Meadow, true, "the plot keeps its Meadow tag")
		end
	end)

	-- GL-13 (GL-D2, docs/design/wildbound-pueblo-gatito-long-plan.md; owner request 2026-11-19 "hace el mapa bastante mas
	-- largo"): the grown arm's far half, past the old far end (z 937), is Pueblo Gatito too: its light, Day rules and the
	-- server's CandyEast tag (without it no kitten wakes there: world.inCandy reads that tag).
	case("GL-13: the grown arm's far half (297, 1500) is Pueblo Gatito: Gatuno light, Day rules, the CandyEast tag", function()
		local name, preset = BiomeLight.presetAt(297, 1500)
		equal(name, "Gatuno", "the far half's light")
		equal(preset, BiomeLight.PRESETS.Gatuno)
		equal((BiomeLight.phaseAt(297, 1500)), "Day", "Day rules")
		equal((BiomeLight.presetAt(297, 1500, "classic")), "Gatuno", "the classic copy")
		equal((BiomeLight.presetAt(297, 1000, "classic")), "Gatuno", "just past the old far end (z 937)")
		local Biomes = sources.biomes
		if type(Biomes) == "table" and type(Biomes.at) == "function" then
			local tags = Biomes.at(297, 1500)
			equal(tags.CandyEast, true, "the server's CandyEast tag")
			equal(tags.Meadow, nil, "no Meadow rules there")
			equal(Biomes.at(297, 1545).CandyEast, nil, "past the arm's far end (z 1537)")
		end
	end)

	-- K-D14 (owner request 2026-11-17, "es como el mundo de gatito: un parque verde lindo con las criaturas gatitas, ..."):
	-- Pueblo Gatito, the kitten park in Caramelo Este, has its own Gatuno preset: always day, the Atmosphere "park" zone
	-- (clear blue air, a long view), Day rules. Its square is the first row, so no overlapping square takes the cloud band.
	case("K-D14: Pueblo Gatito's Gatuno preset: a blue sky, a long clear view, Day rules, first in the squares", function()
		-- Deliberately changed (PGM-D3, owner request 2026-11-18 "Sí, movelo"): the park moved to the south arm; its old
		-- place (1200, 0) is in no classic square now, the hub's light (was "Gatuno", "the park")
		equal((BiomeLight.presetAt(1200, 0, "classic")), "Hub", "the old park's place")
		equal((BiomeLight.presetAt(282, 600, "classic")), "Gatuno", "the park")
		equal((BiomeLight.presetAt(620, -7, "classic")), "Caramelo", "the plot keeps Caramelo")
		local gatuno = BiomeLight.PRESETS.Gatuno
		assert(type(gatuno) == "table" and table.isfrozen(gatuno), "a frozen Gatuno preset")
		equal(gatuno.zone, "park", "the park zone")
		equal(gatuno.mood, "Day", "always day")
		equal(gatuno.variants, false, "the wave's variant never reaches the park")
		equal(gatuno.label, "Pueblo Gatito · siempre de día", "the HUD label")
		equal(BiomeLight.RULES.Gatuno, "Day", "Day rules")
		equal((BiomeLight.phaseAt(282, 600, "classic")), "Day", "played by Day") -- PGM-D3 (was 1200, 0)
		equal(BiomeLight.AREAS[1].tag, "CandyEast", "the park's square is the first row")
		local Atmos = sources.atmosphere
		assert(type(Atmos) == "table", "atmosphere not passed")
		local park = BiomeLight.target(Atmos, "Gatuno", "open", false)
		assert(park.fogEnd >= 900, "a long, clear view: " .. park.fogEnd)
		assert(park.density <= 0.3, "a thin haze: " .. park.density)
		equal(park.brightness, 1, "bright")
		local air = park.atmosphereColor
		assert(air.b > air.r and air.b > 200, "blue air, not pink: " .. air.r .. "," .. air.g .. "," .. air.b)
		local withVariant = BiomeLight.target(Atmos, "Gatuno", "open", false, "Ceniza")
		equal(withVariant.fogEnd, park.fogEnd, "no variant in the park")
		-- the big4 copy (Studio): the park's square is first there too. Deliberately changed (PGM-D3): it is the south arm
		-- (it replaces the Volcanic row), so the band east of the plot is Caramelo's again (was 960, 0 "Gatuno", "the
		-- park's west strip"; 1300, 0 "Gatuno", "the park")
		if type(BiomeLight.AREAS_BIG4) == "table" then
			equal(BiomeLight.AREAS_BIG4[1].tag, "CandyEast", "big4: the park's square is the first row")
			equal((BiomeLight.presetAt(282, 600, "big4")), "Gatuno", "big4: the park")
			equal((BiomeLight.presetAt(960, 0, "big4")), "Caramelo", "big4: the band is Caramelo's again")
			equal((BiomeLight.presetAt(900, 0, "big4")), "Caramelo", "big4: the plot west of the band")
		end
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
		for _, banned in ipairs({ "game:", "workspace", "task.", "os.time", "os.clock", "math.random", "tick(", "Lighting" }) do
			assert(not source:find(banned, 1, true), "reads " .. banned)
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

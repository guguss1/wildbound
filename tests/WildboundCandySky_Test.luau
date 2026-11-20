-- V7-D3 (owner request 2026-11-17, "a pink sky with clouds"; odd/tasks/wildbound-caramelo-v2.md): Caramelo's air and
-- fog are pink (WildboundAtmosphere's candy zone), its haze is strong enough to tint the sky, the other zones keep their
-- grey air, and a client-only script shows pink clouds and a pink sky decay inside the Caramelo biome only.
return function(Atmosphere, BiomeLight, sources)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function has(source, needle, label)
		assert(type(source) == "string" and string.find(source, needle, 1, true), (label or "missing") .. ": " .. needle)
	end
	local function pink(c, label)
		assert(c.r >= 240 and c.r > c.g + 30 and c.b > c.g and c.r > c.b, label .. " is not pink: " .. c.r .. "," .. c.g .. "," .. c.b)
	end

	case("V7-D3: Caramelo's light has pink air and fog and a haze that tints the sky", function()
		local candy = BiomeLight.target(Atmosphere, "Caramelo", "open", false)
		pink(candy.atmosphereColor, "the air")
		pink(candy.fogColor, "the fog")
		assert(candy.haze >= 1.2, "haze " .. candy.haze)
		assert(candy.density <= 0.4 and candy.fogEnd >= 400, "still a light, long view")
		local reduced = BiomeLight.target(Atmosphere, "Caramelo", "open", true)
		pink(reduced.atmosphereColor, "the air with reduced effects")
	end)

	case("V7-D3: the other zones and biomes keep their own grey air", function()
		local forest = BiomeLight.target(Atmosphere, "Forest", "open", false)
		local hub = BiomeLight.target(Atmosphere, "Hub", "open", false)
		for label, t in pairs({ forest = forest, hub = hub }) do
			local c = t.atmosphereColor
			assert(math.abs(c.r - c.g) < 20 and math.abs(c.r - c.b) < 30, label .. " turned pink")
		end
		local open = Atmosphere.at(14, "open", false)
		assert(open.atmosphereColor.r == 170 and open.atmosphereColor.g == 176, "the open day's air is unchanged")
	end)

	case("V7-D3 wiring: the client's clouds and decay only in Caramelo, local and never on the server", function()
		local client = sources.client
		has(client, 'Instance.new("Clouds")', "local clouds")
		has(client, "clouds.Parent = workspace.Terrain", "under Terrain")
		-- Deliberately changed (K-D14): SKY is keyed by preset (Caramelo's values unchanged, Gatuno for the kitten park),
		-- so the look follows the preset where the character stands, and a look without a decay keeps the place's own.
		-- Deliberately changed (OQ1, owner request 2026-11-19, "quiero que las nubes sean mas realistas, no una foto
		-- estirada"): Caramelo's real 3D clouds cover more of the sky and are thicker (was cover 0.62, density 0.55), and
		-- the pink skybox picture (a stretched photo of painted clouds) is no longer swapped in (was skybox = true): the
		-- pink comes from the clouds, the pink decay (unchanged) and the candy haze. Each look also drifts (wind).
		has(client, "Caramelo = table.freeze({ cover = 0.72, density = 0.6, cloudColour = Color3.fromRGB(255, 226, 240),",
			"Caramelo's clouds")
		-- Deliberately changed (TB-4, owner request 2026-11-20, "el cielo tenia que ser solo en reino caramelo y rosa"):
		-- Caramelo swaps in its own skybox again (now the Toolbox "Obby Sky" pictures in the WildboundCandySkybox
		-- template, tinted by the pink decay and haze); every other biome keeps the place's own Sky (was skybox = false)
		has(client, "decay = Color3.fromRGB(255, 140, 196), skybox = true, wind = Vector3.new(3, 0, 1) }),",
			"Caramelo's decay unchanged, its own skybox, a slow drift")
		has(client, "local BLEND_SECONDS = 1.5", "the same blend")
		has(client, "local name = root ~= nil and BiomeLight.presetAt(root.Position.X, root.Position.Z) or nil",
			"where the character stands")
		has(client, "local wanted = SKY[name] and name or nil", "a look per preset")
		has(client, "atmosphere.Decay = originalDecay:Lerp(look.decay or originalDecay, weight)", "the decay goes back outside")
		has(client, "RunService.Heartbeat:Connect", "Heartbeat drives it")
		-- the pink skybox in place of the place's own Sky, and the place's put back outside
		has(client, 'ReplicatedStorage:WaitForChild("WildboundCandySkybox", 10)', "the pink skybox template")
		has(client, "useCandySky(weight >= 0.5)", "swapped halfway through the blend")
		has(client, "if placeSky then placeSky.Parent = Lighting end", "the place's sky comes back outside")
		local template = game:GetService("ReplicatedStorage"):FindFirstChild("WildboundCandySkybox")
		assert(template and template:IsA("Sky") and #template:GetChildren() == 0, "the template is a bare Sky (no scripts)")
		assert(not client:find("RenderStepped:", 1, true), "RenderStepped did not fire in Studio Play")
		assert(not client:find("RemoteEvent", 1, true) and not client:find("FireServer", 1, true), "no network")
	end)

	-- K-D14 (owner request 2026-11-17, "es como el mundo de gatito: un parque verde lindo ..."): the kitten park (preset
	-- Gatuno) has a clear blue sky: white clouds, the place's own decay and the place's own Sky (no pink skybox), and
	-- light-blue air from the Atmosphere park zone.
	-- Deliberately changed (OQ1, owner request 2026-11-19, "quiero que las nubes sean mas realistas, no una foto
	-- estirada"): the park's white clouds are fluffier and cover more (was cover 0.45, density 0.4), and the park gets a
	-- sky-blue decay (was none: the place's own grey-blue), so the stronger park haze that fades the painted skybox
	-- reads as a clear blue sky gradient and not a grey one.
	case("K-D14: Gatuno has white clouds, a sky-blue decay and no skybox, under light-blue air", function()
		local client = sources.client
		local gatuno = string.match(client or "", "Gatuno = table%.freeze%(%b{}%)")
		assert(gatuno, "no Gatuno look in SKY")
		has(gatuno, "cover = 0.58, density = 0.62, cloudColour = Color3.fromRGB(255, 255, 255)", "white clouds")
		has(gatuno, "skybox = false", "no skybox swap")
		has(gatuno, "decay = Color3.fromRGB(120, 176, 236)", "a sky-blue decay in the park (OQ1)")
		has(client, "on = on and SKY[active] ~= nil and SKY[active].skybox == true", "only a skybox look swaps the Sky")
		has(client, "if wanted ~= active and weight == 0 then", "a new look waits for the old one to fade out")
		local park = BiomeLight.target(Atmosphere, "Gatuno", "open", false)
		local c = park.atmosphereColor
		assert(c.b > c.r and c.b > c.g and c.b >= 240, "the park's air is light blue: " .. c.r .. "," .. c.g .. "," .. c.b)
		assert(park.fogEnd >= 900, "a long view")
		-- Deliberately changed (PGM-D3, owner request 2026-11-18 "Sí, movelo"): the park's centre is in the big4 south
		-- arm now, WildboundGatitoArea.ORIGIN (was 1208, -3)
		local name = BiomeLight.presetAt(282, 600)
		assert(name == "Gatuno", "the park reads Gatuno, got " .. tostring(name))
	end)

	-- OQ1 (owner request 2026-11-19, "quiero que las nubes sean mas realistas, no una foto estirada"): the sky's clouds
	-- are real 3D clouds (the one local Terrain Clouds), a look in the two bright biomes: Caramelo pinkish, Pueblo Gatito
	-- white and fluffy; each drifts on a slow local wind. No look swaps in a painted skybox picture; the haze is raised
	-- over the place's own skybox. These cases check numbers and wiring only: whether the photo still shows overhead is
	-- the solo Play check (look straight up in Caramelo and in Pueblo Gatito), never proved by a passing suite.
	-- OQ1 review: the forest and the mountains have no look (their misty air already hides the sky; no clouds, no wind
	-- for nothing seen on a phone, and no swaying grass in the horror forest): they keep the place's own sky and wind.
	local function look(client, name)
		local row = string.match(client or "", name .. " = table%.freeze%(%b{}%)")
		assert(row, "no " .. name .. " look in SKY")
		local function number(key)
			local value = tonumber(string.match(row, key .. " = ([%d%.]+)"))
			assert(value, name .. " has no " .. key)
			return value
		end
		local r, g, b = string.match(row, "cloudColour = Color3%.fromRGB%((%d+), (%d+), (%d+)%)")
		assert(r, name .. " has no cloudColour")
		return { row = row, cover = number("cover"), density = number("density"),
			colour = { r = tonumber(r), g = tonumber(g), b = tonumber(b) } }
	end
	local LOOKS = { "Caramelo", "Gatuno" }

	case("OQ1-1: Caramelo and Pueblo Gatito have their own real 3D clouds and a slow drift; the misty biomes none", function()
		local client = sources.client
		local looks = {}
		for _, name in ipairs(LOOKS) do
			local l = look(client, name)
			assert(BiomeLight.PRESETS[name] ~= nil, name .. " is a BiomeLight preset, so presetAt can answer it")
			assert(l.cover > 0 and l.cover <= 0.9, name .. " cover " .. l.cover .. " (some sky always shows)")
			assert(l.density > 0 and l.density <= 1, name .. " density " .. l.density)
			local x, y, z = string.match(l.row, "wind = Vector3%.new%(([%d%.%-]+), ([%d%.%-]+), ([%d%.%-]+)%)")
			assert(x and y and z, name .. " has no wind")
			local speed = Vector3.new(tonumber(x), tonumber(y), tonumber(z)).Magnitude
			assert(speed > 0 and speed <= 8 and tonumber(y) == 0, name .. " drifts slowly and level: " .. speed)
			looks[name] = l
		end
		local candy, park = looks.Caramelo, looks.Gatuno
		local c = candy.colour
		assert(c.r == 255 and c.r > c.g and c.b > c.g, "Caramelo's clouds are pinkish: " .. c.r .. "," .. c.g .. "," .. c.b)
		c = park.colour
		assert(c.r == 255 and c.g == 255 and c.b == 255, "Pueblo Gatito's clouds are white")
		assert(park.density >= 0.55, "Pueblo Gatito's clouds are fluffy: " .. park.density)
		-- OQ1 review: no look where the misty air already hides the sky (the place's own sky and wind stay there)
		for _, name in ipairs({ "Forest", "Mountains", "Swamp", "Cemetery", "Abyss", "Volcanic", "Caves", "Hub" }) do
			assert(not string.match(client, "\n%s*" .. name .. " = table%.freeze%("), name .. " has no cloud look")
		end
		local rows = 0
		for _ in string.gmatch(client, "\n%s*%a+ = table%.freeze%({ cover = ") do rows += 1 end
		assert(rows == #LOOKS, "only Caramelo and Pueblo Gatito have a cloud look, got " .. rows)
		local made = 0
		for _ in string.gmatch(client, 'Instance%.new%("Clouds"%)') do made += 1 end
		assert(made == 1, "one local Clouds for every look, got " .. made)
		has(client, 'clouds.Name = "WildboundCandyClouds"', "the same local Clouds")
		has(client, "clouds.Density, clouds.Color = SKY[active].density, SKY[active].cloudColour", "each look's clouds")
		has(client, "clouds.Cover = look.cover * weight", "the cover fades in and out")
		has(client, "workspace.GlobalWind = originalWind:Lerp(look.wind or originalWind, weight)",
			"the drift is the engine's wind, local, and goes back to the place's own outside")
	end)

	case("OQ1-2: no painted skybox picture swapped in, the haze raised over the place's own, sun and moon kept", function()
		local client = sources.client
		-- Deliberately changed (TB-4, owner request 2026-11-20): only Caramelo swaps in its own skybox (the Toolbox Obby
		-- Sky in the WildboundCandySkybox template); Gatuno keeps the place's own (was: no look swaps)
		has(look(client, "Gatuno").row, "skybox = false", "Gatuno shows no skybox swap")
		has(look(client, "Caramelo").row, "skybox = true", "Caramelo swaps in its own skybox")
		-- the swap stays only as a one-flag rollback and still puts the place's own Sky back
		has(client, "on = on and SKY[active] ~= nil and SKY[active].skybox == true", "only a skybox look could swap")
		for _, banned in ipairs({ "CelestialBodiesShown", "SkyboxBk", "SkyboxUp", "SunTextureId", "MoonTextureId" }) do
			assert(not client:find(banned, 1, true), "the place's Sky, sun and moon are untouched: " .. banned)
		end
		local candy = BiomeLight.target(Atmosphere, "Caramelo", "open", false)
		local park = BiomeLight.target(Atmosphere, "Gatuno", "open", false)
		assert(candy.haze >= 2.6, "Caramelo's haze raised (was 1.6): " .. candy.haze)
		assert(park.haze >= 1.6, "the park's haze raised (was 0.6): " .. park.haze)
		assert(candy.haze <= Atmosphere.FLOORS.haze and park.haze <= Atmosphere.FLOORS.haze, "under the haze ceiling")
		assert(candy.density <= 0.4 and park.density <= 0.3, "haze, not density: the view stays long")
		local r, g, b = string.match(look(client, "Gatuno").row, "decay = Color3%.fromRGB%((%d+), (%d+), (%d+)%)")
		assert(r and tonumber(b) > tonumber(r) and tonumber(b) >= 220, "the park's sky gradient is blue")
		r, g, b = string.match(look(client, "Caramelo").row, "decay = Color3%.fromRGB%((%d+), (%d+), (%d+)%)")
		assert(r and tonumber(r) == 255 and tonumber(b) > tonumber(g), "Caramelo's sky gradient is pink")
	end)

	return result
end

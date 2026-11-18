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
		has(client, "Caramelo = table.freeze({ cover = 0.62, density = 0.55, cloudColour = Color3.fromRGB(255, 226, 240),",
			"Caramelo's clouds are unchanged")
		has(client, "decay = Color3.fromRGB(255, 140, 196), skybox = true }),", "Caramelo's decay and skybox are unchanged")
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
	case("K-D14: Gatuno has white clouds, no decay and no skybox, under light-blue air", function()
		local client = sources.client
		local gatuno = string.match(client or "", "Gatuno = table%.freeze%(%b{}%)")
		assert(gatuno, "no Gatuno look in SKY")
		has(gatuno, "cover = 0.45, density = 0.4, cloudColour = Color3.fromRGB(255, 255, 255)", "white clouds")
		has(gatuno, "skybox = false", "no skybox swap")
		assert(not gatuno:find("decay", 1, true), "no decay change in the park")
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

	return result
end

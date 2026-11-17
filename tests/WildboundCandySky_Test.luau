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
		has(client, 'preset = "Caramelo"', "Caramelo only")
		has(client, "BiomeLight.presetAt(root.Position.X, root.Position.Z) == SKY.preset", "where the character stands")
		has(client, "atmosphere.Decay = originalDecay:Lerp(SKY.decay, weight)", "the decay goes back outside")
		has(client, "RunService.Heartbeat:Connect", "Heartbeat drives it")
		assert(not client:find("RenderStepped:", 1, true), "RenderStepped did not fire in Studio Play")
		assert(not client:find("RemoteEvent", 1, true) and not client:find("FireServer", 1, true), "no network")
	end)

	return result
end

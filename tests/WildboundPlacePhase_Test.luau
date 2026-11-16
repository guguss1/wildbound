-- Invoke with require(freshTestClone)(require(freshBiomeLightClone), { rules = require(freshWorldRulesClone),
-- brain = require(freshGuardianBrainClone), director = require(freshBeastDirectorClone),
-- config = require(freshBeastConfigClone), island = require(freshIslandClone), layout = require(freshIslandLayoutClone),
-- ambush = require(freshAmbushClone) }, { world = WildboundWorld.Source, server = WildboundServer.Source,
-- beasts = WildboundBeasts.Source }).
-- CF1 (user, 2026-11-15, "Bosque siempre de noche"; odd/tasks/wildbound-caramelo.md): there is no global day/night
-- cycle, but the gameplay phase is per place. BiomeLight.phaseAt(x, z) is the one pure answer: the forest and the
-- other dark biomes (Abismo, Cuevas) play by Night rules always; Caramelo, the hub, Montañas and the dusk-looking
-- biomes (Pantano, Cementerio, Volcán) by Day rules. Every system that read the phase (La Silueta's profile and brain
-- row, the beast odds, the island parents, hide discovery, the ambush timer) keys it on the position of the player or
-- entity it concerns. Dusk never comes back.
return function(BiomeLight, deps, sources)
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
	deps = type(deps) == "table" and deps or {}
	sources = type(sources) == "table" and sources or {}
	local Rules, Brain, Director, Config = deps.rules, deps.brain, deps.director, deps.config
	local Island, Layout, Ambush = deps.island, deps.layout, deps.ambush

	-- Points inside each biome square (BiomeLight.AREAS), the fog rectangle and the hub.
	local FOREST_X, FOREST_Z = 60, -60 -- inside La Silueta's fog rectangle too
	local CARAMELO_X, CARAMELO_Z = 620, -7
	local PLACES = {
		{ "forest", FOREST_X, FOREST_Z, "Night" }, { "swamp island in the forest", 115, 15, "Night" },
		{ "abismo", -100, -400, "Night" }, { "cuevas", 600, 400, "Night" },
		{ "caramelo", CARAMELO_X, CARAMELO_Z, "Day" }, { "hub", 282, -3, "Day" }, { "montanas", 700, -500, "Day" },
		{ "pantano", 300, -400, "Day" }, { "cementerio", 300, 400, "Day" }, { "volcan", -100, 400, "Day" },
		{ "bad point", 0 / 0, 5, "Day" }, { "no point", nil, nil, "Day" },
	}

	-- The classic map (odd/tasks/wildbound-big4-map.md: the place may be left in the big4 mode, so these pin the mode).
	local function phaseAt(x, z)
		assert(type(BiomeLight) == "table" and type(BiomeLight.phaseAt) == "function", "BiomeLight.phaseAt missing")
		return BiomeLight.phaseAt(x, z, "classic")
	end

	case("BIG4: the four larger biomes keep their phases, and the forest's islands and home stay Night", function()
		for _, place in ipairs({
			{ "forest", FOREST_X, FOREST_Z, "Night" }, { "outer forest west", -500, 0, "Night" },
			{ "outer forest north", 0, -450, "Night" }, { "swamp island in the forest", 115, 15, "Night" },
			{ "caramelo", CARAMELO_X, CARAMELO_Z, "Day" }, { "caramelo annex east", 950, 0, "Day" },
			{ "caramelo annex south", 600, 450, "Day" }, { "hub", 282, -3, "Day" }, { "montanas", 400, -800, "Day" },
			{ "volcan", -500, 800, "Day" }, { "old cementerio", 282, 387, "Day" }, { "bad point", 0 / 0, 5, "Day" },
		}) do
			local phase, clock = BiomeLight.phaseAt(place[2], place[3], "big4")
			equal(phase, place[4], "big4 " .. place[1])
			assert(type(clock) == "number" and Island.sleepScale(clock) == 1, place[1] .. " clock outside the deep sleep")
		end
		for _, spec in ipairs(Layout.islands) do
			equal((BiomeLight.phaseAt(spec.x, spec.z, "big4")), "Night", "big4 " .. spec.id)
		end
		equal((BiomeLight.phaseAt(Rules.HOME_X, Rules.HOME_Z, "big4")), "Night", "big4 La Silueta's home")
	end)

	case("CF1: the phase is per place, forest and dark biomes Night, Caramelo and the rest Day", function()
		for _, place in ipairs(PLACES) do
			local phase, clock = phaseAt(place[2], place[3])
			equal(phase, place[4], place[1])
			assert(type(clock) == "number" and clock >= 0 and clock < 24, place[1] .. " clock")
		end
	end)

	case("CF1: no place resolves to Dusk or Dawn, and the rules clock is never the islands' deep sleep", function()
		assert(type(BiomeLight.RULES) == "table" and table.isfrozen(BiomeLight.RULES), "frozen RULES")
		for name in pairs(BiomeLight.PRESETS) do
			local phase = BiomeLight.RULES[name]
			assert(phase == "Day" or phase == "Night", name .. " has Day or Night rules, got " .. tostring(phase))
		end
		for _, place in ipairs(PLACES) do
			local _, clock = phaseAt(place[2], place[3])
			equal(Island.sleepScale(clock), 1, place[1] .. " outside the deep-sleep window")
		end
	end)

	case("CF1: La Silueta hunts with her Night profile in the forest, never with the Day one", function()
		local forest, caramelo = phaseAt(FOREST_X, FOREST_Z), phaseAt(CARAMELO_X, CARAMELO_Z)
		local fog = Rules.zone(FOREST_X, FOREST_Z)
		equal(fog, true, "the forest point is in the fog")
		local night = Rules.resolveCreatureProfile("Silueta", forest, fog)
		equal(night.speed, 8, "night speed"); equal(night.detectionRange, 38, "night detection")
		local day = Rules.resolveCreatureProfile("Silueta", caramelo, Rules.zone(CARAMELO_X, CARAMELO_Z))
		equal(day.speed, 6, "Caramelo base speed"); equal(day.detectionRange, 28, "Caramelo base detection")
		local brainForest, brainNight = Brain.profile(forest), Brain.profile("Night")
		for key, value in pairs(brainNight) do equal(brainForest[key], value, "forest brain row " .. key) end
		local brainCaramelo = Brain.profile(caramelo)
		equal(brainCaramelo.hunt, Brain.profile("Day").hunt, "Caramelo reads the Day row")
		assert(brainForest.hunt > brainCaramelo.hunt, "the night hunt is faster")
	end)

	case("CF1: beast odds double in the forest and stay single in Caramelo", function()
		local function ctxAt(x, z) return { night = phaseAt(x, z) == "Night" } end
		equal(Director.multiplier(ctxAt(FOREST_X, FOREST_Z)), Config.DIRECTOR.MULTIPLIERS.night, "forest night odds")
		equal(Config.DIRECTOR.MULTIPLIERS.night, 2)
		equal(Director.multiplier(ctxAt(CARAMELO_X, CARAMELO_Z)), 1, "Caramelo day odds")
		local name, beast
		for key, value in pairs(Config.BEASTS) do
			if type(value.chance) == "number" and value.chance > 0 and value.chance * 2 < Config.DIRECTOR.MAX_CHANCE then
				name, beast = key, value
				break
			end
		end
		assert(name and beast, "a beast with a chance")
		local forest = Director.chance(name, ctxAt(FOREST_X, FOREST_Z))
		local caramelo = Director.chance(name, ctxAt(CARAMELO_X, CARAMELO_Z))
		assert(math.abs(forest - 2 * caramelo) < 1e-9, name .. " forest " .. forest .. " vs Caramelo " .. caramelo)
	end)

	case("CF1: every island parent keeps its night pattern, and La Silueta's ambush its night timer", function()
		assert(#Layout.islands >= 5, "islands")
		for _, spec in ipairs(Layout.islands) do
			local phase = phaseAt(spec.x, spec.z)
			equal(phase, "Night", spec.id)
			equal(Island.wakeRadius(spec, phase), spec.wakeNight, spec.id .. " night wake radius")
		end
		local phase = phaseAt(Rules.HOME_X, Rules.HOME_Z)
		equal(Ambush.nextDelay(phase, 0), Ambush.CONSTANTS.NIGHT_MIN, "night ambush delay at home")
		equal(Ambush.nextDelay(phaseAt(CARAMELO_X, CARAMELO_Z), 0), Ambush.CONSTANTS.DAY_MIN, "day delay in Caramelo")
	end)

	case("CF1: the world script keys La Silueta's phase on her own position", function()
		local world = sources.world or ""
		has(world, 'require(ReplicatedStorage:WaitForChild("WildboundBiomeLight"))')
		has(world, "local phase, clockTime = PlaceRules.phaseAt(x, z)")
		has(world, "local cycle = cycleAt(now, h.body.Position.X, h.body.Position.Z)", "step: brain row and profile")
		has(world, "Brain.profile(cycleAt(now, h.body.Position.X, h.body.Position.Z).phase).memorySeconds", "memory")
		has(world, "local phase = cycleAt(now, position.X, position.Z).phase", "hearing")
		has(world, "local phase = cycleAt(now, hide.x, hide.z).phase", "hide discovery at the spot")
		has(world, "Ambush.nextDelay(cycleAt(now, body.Position.X, body.Position.Z).phase", "first ambush timer")
	end)

	case("CF1: the inventory server keys each island on its own nest, and Dusk stays on the fixed world phase", function()
		local server = sources.server or ""
		has(server, "local phase, clock = PlaceRules.phaseAt(spec.x, spec.z)")
		has(server, "Island.rollContent(island.spec, islandPhase(island.spec), rand)", "nest content")
		has(server, "Island.wakeRadius(spec, islandPhase(spec))", "wake radius")
		has(server, "local clock, phase = islandCycle(spec).clockTime, islandPhase(spec)", "deep sleep and meter")
		has(server, "local phase = islandPhase(spec)", "noise")
		has(server, "Heist.Dusk.step(Heist.dusk.state, islandCycle())", "Dusk reads the fixed world phase (inert)")
		assert(not server:find("local phase = islandPhase()", 1, true), "no island reads one world phase any more")
	end)

	case("CF1: the beast script keys night odds, Dusk and the Nube range on the player's position", function()
		local beasts = sources.beasts or ""
		has(beasts, 'require(ReplicatedStorage:WaitForChild("WildboundBiomeLight"))')
		has(beasts, "return (PlaceRules.phaseAt(x, z))")
		has(beasts, "local phase = phaseAt(p.X, p.Z)", "director context")
		has(beasts, 'local night = phaseAt(p.X, p.Z) == "Night"', "summoned kids")
		has(beasts, 'night = phaseAt(p.X, p.Z) == "Night", eventOpen', "summon pass")
		assert(not beasts:find("Rules.cycle()", 1, true), "no fixed world phase")
	end)

	return result
end

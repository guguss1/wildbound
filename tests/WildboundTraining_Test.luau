-- Invoke with require(freshTestClone)(require(freshTrainingClone), freshTrainingClone.Source, { state =
-- require(freshStateClone), economy = require(freshEconomyClone), config = require(freshConfigClone),
-- stamina = require(freshStaminaClone), schema = require(freshSchemaClone), keys = require(freshKeysClone),
-- text = require(freshTextClone), server = WildboundServer.Source, bridge = WildboundTuning.Source }).
-- Nest Heist Phase 3 (NS5): the camp's "Entrenamiento" treadmill. Esencia buys small walk-speed levels with a growing
-- price and an explicit cap; every speed keeps a ceiling so parents and new players still meet a trained player.
return function(Training, source, sources)
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
	local function near(actual, expected, label)
		assert(type(actual) == "number" and math.abs(actual - expected) < 1e-6,
			(label and label .. ": " or "") .. "Expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local State, Economy, Config, Stamina = sources.state, sources.economy, sources.config, sources.stamina

	case("TR-1: walk levels: a growing price, then nothing past the cap", function()
		local C = Training.CONSTANTS
		equal(C.WALK_STEP, 0.25); equal(C.MAX_LEVEL, 4); equal(C.WALK_CAP, 17.5)
		equal(Training.cost(0), 30); equal(Training.cost(1), 48); equal(Training.cost(2), 77); equal(Training.cost(3), 123)
		equal(Training.cost(4), nil, "no level past the cap")
		equal(Training.cost(-1), nil); equal(Training.cost(0 / 0), nil)
	end)

	case("TR-2: the walk bonus applies only unencumbered and never above WALK_CAP", function()
		near(Training.walkSpeed(16, 16, { walk = 4 }), 17, "four levels: +1")
		near(Training.walkSpeed(16, 16, { walk = 99 }), 17, "levels past the cap count as the cap")
		near(Training.walkSpeed(16, 16, { walk = 4 }, 5), 17.5, "with any other bonus, never above the cap")
		near(Training.walkSpeed(11, 16, { walk = 4 }), 11, "an egg in the arms gets nothing")
		near(Training.walkSpeed(16, 16, nil), 16); near(Training.walkSpeed(16, 16, { walk = -2 }), 16)
	end)

	case("TR-3: sprint and Burst keep their own caps over a trained walk", function()
		local walk = Training.walkSpeed(16, 16, { walk = 4 }, 5)
		assert(Stamina.speed(walk, "sprint") <= Stamina.CONSTANTS.SPEED_CAP, "sprint stays under its cap")
		assert(Stamina.speed(walk, "walk", true) <= Stamina.CONSTANTS.BURST_CAP, "the Burst stays under its cap")
		near(Stamina.speed(11, "walk", true), 18.7, "an egg carrier's Burst is unchanged (parents run 19)")
	end)

	case("TR-4: State:train pays Esencia at camp, one level at a time, and refuses past the cap", function()
		local state = State.new(Economy, Config)
		state:addPlayer("Ana")
		local profile = state.players["s:Ana"]
		profile.ember = 100
		local ok, reason = state:train("Ana", "walk", true, 999, 30, 4)
		equal(ok, false); equal(reason, "NotAtCamp")
		equal((state:train("Ana", "walk", false, 0, 30, 4)), false, "dead players do not train")
		equal((state:train("Ana", "run", true, 0, 30, 4)), false, "unknown training")
		local done, level = state:train("Ana", "walk", true, 0, 30, 4)
		equal(done, true); equal(level, 1); equal(profile.ember, 70)
		equal(state:snapshot("Ana").training.walk, 1, "the snapshot shows the level")
		local poor, why = state:train("Ana", "walk", true, 0, 100, 4)
		equal(poor, false); equal(why, "CannotAfford"); equal(profile.ember, 70, "a refusal costs nothing")
		profile.training.walk = 4
		local capped, because = state:train("Ana", "walk", true, 0, nil, 4)
		equal(capped, false); equal(because, "AtLimit")
		equal(state:snapshot("Ana").training.walk, 4)
	end)

	case("TR-5: the tuning schema carries every training number and the bridge tunes it", function()
		local schema = sources.schema
		assert(schema.MODULES.Training and schema.MODULES.Training.name == "WildboundTraining", "schema module")
		local keys = {}
		for _, system in ipairs(schema.SYSTEMS) do
			if system.id == "Training" then for _, entry in ipairs(system.entries) do keys[entry.key] = entry end end
		end
		for _, key in ipairs({ "WALK_STEP", "MAX_LEVEL", "WALK_CAP", "BASE_COST", "COST_GROWTH" }) do
			assert(keys[key], "schema entry " .. key)
			equal(keys[key].default, Training.CONSTANTS[key], key)
		end
		assert(keys.WALK_CAP.max <= 18, "the tuning can never push the walk cap past 18")
		assert(sources.bridge:find('Training = "WildboundTraining"', 1, true), "the bridge requires the module")
	end)

	case("TR-6: the server builds the treadmill, prices with Training and applies the walk to WalkSpeed", function()
		local server = sources.server
		assert(server:find('"WildboundTreadmill"', 1, true), "a treadmill model built from parts")
		assert(server:find("Keys.CAMP.train", 1, true), "its own prompt key")
		assert(server:find("Heist.Training.cost(", 1, true), "the price comes from the rule")
		assert(server:find("state:train(player.UserId", 1, true), "the purchase goes through State")
		assert(server:find("Heist.Training.walkSpeed(speed, EconomyConfig.carry.baseSpeed, snapshot.training", 1, true),
			"the walk speed passes through the training rule")
		local keys = sources.keys
		assert(keys.CAMP.train, "a camp key for the treadmill")
		equal(#keys.conflicts(), 0, table.concat(keys.conflicts(), "; "))
		local T = sources.text.TRAINING
		assert(T and T.prompt and T.object and T.trained and T.maxed and T.cannot, "Spanish words")
	end)

	case("TR-7: the module is pure: no services, clock or randomness, and no purchase path", function()
		for _, word in ipairs({ "game:", "GetService", "os.", "task.", "Random", "workspace", "Instance",
			"MarketplaceService", "Robux", "DataStore" }) do
			equal(source:find(word, 1, true), nil, "source mentions " .. word)
		end
	end)

	return result
end

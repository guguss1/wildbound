-- Invoke with require(freshTestClone)(require(freshTrainingClone), freshTrainingClone.Source, { state =
-- require(freshStateClone), economy = require(freshEconomyClone), config = require(freshConfigClone),
-- stamina = require(freshStaminaClone), schema = require(freshSchemaClone), keys = require(freshKeysClone),
-- text = require(freshTextClone), server = WildboundServer.Source, bridge = WildboundTuning.Source,
-- treadmill = WildboundTreadmillService.Source }).
-- Nest Heist Phase 3 (NS5): the camp's "Entrenamiento" treadmill. PF2 (user decision 2026-11-14, "como Steal an Egg,
-- muchísimo"): each level adds a large walk step, from 16 up to a walk cap of 50; laps on the belt grant the levels.
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
		equal(C.WALK_STEP, 2, "PF2: +2 walk per level"); equal(C.MAX_LEVEL, 17); equal(C.WALK_CAP, 50, "PF2: 16 -> 50")
		equal(Training.cost(0), 30); equal(Training.cost(1), 36); equal(Training.cost(2), 43); equal(Training.cost(16), 555)
		equal(Training.cost(17), nil, "no level past the cap")
		equal(Training.cost(-1), nil); equal(Training.cost(0 / 0), nil)
	end)

	-- Deliberately changed (PF2, user decision 2026-11-14; replaces HF-T4 / Q9's walk cap of 16): training must be felt.
	-- An unencumbered walk gains WALK_STEP per level up to WALK_CAP; a carrier (egg, creature, heavy pouch) keeps the
	-- same share of the trained walk that the carry leaves of the base walk, so carrying still costs speed.
	case("TR-2: the walk bonus is large, capped at WALK_CAP, and scaled by the carry share", function()
		near(Training.walkSpeed(16, 16, { walk = 4 }), 24, "four levels: +8")
		near(Training.walkSpeed(16, 16, { walk = 17 }), 50, "the top level reaches the cap")
		near(Training.walkSpeed(16, 16, { walk = 99 }), 50, "levels past the cap count as the cap")
		near(Training.walkSpeed(16, 16, { walk = 17 }, 5), 50, "with any other bonus, never above the cap")
		near(Training.walkSpeed(11, 16, { walk = 17 }), 34.375, "an egg carrier keeps 11/16 of the trained walk")
		near(Training.walkSpeed(11, 16, { walk = 4 }), 16.5, "four levels while carrying one egg")
		near(Training.walkSpeed(11, 16, nil), 11, "an untrained carrier is unchanged")
		near(Training.walkSpeed(16, 16, nil), 16); near(Training.walkSpeed(16, 16, { walk = -2 }), 16)
	end)

	case("TR-3: sprint and Burst never slow a trained walk; an untrained one keeps their caps", function()
		local walk = Training.walkSpeed(16, 16, { walk = 17 }, 5)
		near(Stamina.speed(walk, "sprint"), walk, "a sprint never slows a trained walk")
		near(Stamina.speed(walk, "walk", true), walk, "nor does the Burst")
		assert(Stamina.speed(16, "sprint") <= Stamina.CONSTANTS.SPEED_CAP, "an untrained sprint stays under its cap")
		near(Stamina.speed(11, "walk", true), 18.7, "an untrained egg carrier's Burst is unchanged (parents run 19)")
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
		assert(keys.WALK_CAP.min == 16 and keys.WALK_CAP.max >= 50, "PF2: the tuning reaches the trained top walk")
		assert(keys.MAX_LEVEL.max >= Training.CONSTANTS.MAX_LEVEL and keys.WALK_STEP.max >= Training.CONSTANTS.WALK_STEP,
			"PF2: the level count and step fit their tuning ranges")
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

	case("TR-8: a lap grants a level and names the new walk; dismounting restores the walk through applyCarry", function()
		local server, treadmill = sources.server, sources.treadmill
		local first = server:find("onLap = function(player, _belt, isHub)", 1, true)
		assert(first, "the live lap hook")
		local lap = server:sub(first, (server:find("}):start(network, Heist.treadmillBelt)", first, true)))
		assert(lap:find("state:trainByRunning(player.UserId, alive, distance, C.MAX_LEVEL, 5)", 1, true), "+1 level per lap")
		assert(lap:find("Heist.Training.walkSpeed(EconomyConfig.carry.baseSpeed, EconomyConfig.carry.baseSpeed", 1, true),
			"the lap prices the new walk with the training rule")
		assert(lap:find("Text.TRAINING.trained:format(res.level, C.MAX_LEVEL, Heist.speedText(", 1, true),
			"a level-up lap tells the new walk speed")
		assert(server:find("onDismount = function(player) applyCarry(player) end", 1, true), "dismount re-applies the walk")
		assert(server:find("if Heist.treadmillService and Heist.treadmillService:isMounted(player) then speed = 0 end", 1, true),
			"only a mounted player is held at 0")
		local body = treadmill:sub((treadmill:find("function Treadmill:dismount(player, nudgeBack)", 1, true)))
		local cleared, called = body:find("self.mounted[player] = nil", 1, true), body:find("self.deps.onDismount(player)", 1, true)
		assert(cleared and called and cleared < called, "the mount is cleared before applyCarry runs")
	end)

	case("TR-7: the module is pure: no services, clock or randomness, and no purchase path", function()
		for _, word in ipairs({ "game:", "GetService", "os.", "task.", "Random", "workspace", "Instance",
			"MarketplaceService", "Robux", "DataStore" }) do
			equal(source:find(word, 1, true), nil, "source mentions " .. word)
		end
	end)

	return result
end

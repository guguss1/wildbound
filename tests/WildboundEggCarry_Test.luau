-- Invoke with require(freshTestClone)(require(freshEggCarryClone), freshEggCarryClone.Source, { server =
-- WildboundServer.Source, worldClient = WildboundWorldClient.Source, text = require(freshTextClone),
-- state = require(freshStateClone), economy = require(freshEconomyClone), config = require(freshConfigClone),
-- keys = require(freshKeysClone), stamina = require(freshStaminaClone), island = require(freshIslandClone) }).
-- Nest Heist, phase 1 (docs/design/wildbound-combined-plan.md, tasks NH1 to NH8 in the feature document): the pure
-- egg-carry rules and the source contracts for how the inventory server wires them.
return function(EggCarry, source, sources)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function has(text, needle, label)
		assert(type(text) == "string" and text:find(needle, 1, true), (label or "source") .. " lacks " .. needle)
	end
	local function hasNot(text, needle, label)
		assert(type(text) == "string" and not text:find(needle, 1, true), (label or "source") .. " still has " .. needle)
	end
	local function block(text, startNeedle, endNeedle)
		local i = text:find(startNeedle, 1, true)
		assert(i, "block start missing: " .. startNeedle)
		local j = text:find(endNeedle, i + #startNeedle, true)
		assert(j, "block end missing: " .. endNeedle)
		return text:sub(i, j)
	end
	sources = type(sources) == "table" and sources or {}
	local server = sources.server or ""

	-- NH1 fast steal.
	case("NH1: a normal egg is stolen with a 0.8 s hold; a rare or special egg keeps its 1 s hold", function()
		equal(type(EggCarry.CONSTANTS), "table", "CONSTANTS")
		equal(EggCarry.CONSTANTS.STEAL_HOLD, 0.8, "steal hold")
		equal(EggCarry.CONSTANTS.RARE_HOLD, 1, "rare hold, as before")
		equal(EggCarry.holdFor("Comun"), 0.8)
		equal(EggCarry.holdFor("Rara"), 0.8)
		equal(EggCarry.holdFor("Epica"), 1)
		equal(EggCarry.holdFor("Legendaria"), 1)
		equal(EggCarry.holdFor("Comun", true), 1, "the biome event's egg")
		equal(EggCarry.holdFor(nil), 0.8, "an unknown tier is a normal egg")
	end)

	case("NH1: the steal hold stays inside 0.6 to 1 s and a rare hold is never shorter", function()
		EggCarry.tune({ STEAL_HOLD = 0.1 })
		equal(EggCarry.holdFor("Comun"), 0.6, "floor")
		EggCarry.tune({ STEAL_HOLD = 3 })
		equal(EggCarry.holdFor("Comun"), 1, "ceiling")
		EggCarry.tune({ STEAL_HOLD = 0.9, RARE_HOLD = 0.5 })
		equal(EggCarry.holdFor("Epica"), 0.9, "rare never under the steal hold")
		EggCarry.tune({ STEAL_HOLD = "x" })
		equal(EggCarry.holdFor("Comun"), 0.8, "a non-number is ignored")
		EggCarry.tune(nil)
		equal(EggCarry.holdFor("Comun"), 0.8, "nil restores the defaults")
	end)

	case("NH1: the server gives each egg prompt its hold from the rule and eggs never start a capture ring", function()
		has(server, 'WaitForChild("WildboundEggCarry")', "the server requires the rule")
		local spawn = block(server, "spawnEncounter = function(slot)", "\nend\n")
		has(spawn, "EggCarry.holdFor(rarity, slot.special)", "the egg prompt hold")
		hasNot(spawn, "isEgg and 1 or 0", "the old fixed 1 s hold")
		local egg = block(spawn, "if isEgg then", "\t\telse\n")
		hasNot(egg, "startCapture", "an egg never opens the ring")
	end)

	return result
end

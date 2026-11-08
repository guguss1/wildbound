-- Invoke with require(freshTestClone)(require(freshSpeciesClone), require(freshIslandLayoutClone), freshSpeciesClone.Source).
-- Expedition islands (I8, decision EI-4): the island species are primitive stand-ins in each species' colours until an
-- upload is approved. Every look lives in this one module, so a later swap to the exported rigs changes one place.
return function(Species, layout, source)
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
	local function rgb(value, label)
		assert(type(value) == "table" and #value == 3, label .. " colour")
		for _, channel in ipairs(value) do
			assert(type(channel) == "number" and channel >= 0 and channel <= 255 and channel % 1 == 0, label .. " channel")
		end
	end

	case("I8: every island species has a stand-in look", function()
		for _, island in ipairs(layout.islands) do
			local look = Species.look(island.species)
			assert(look and look.name == island.species, island.species)
			assert(#look.size == 3 and look.size[1] > 0 and look.size[2] > 0 and look.size[3] > 0, "size")
			rgb(look.body, island.species .. " body"); rgb(look.accent, island.species .. " accent")
			rgb(look.eye, island.species .. " eye"); rgb(look.glow, island.species .. " glow")
		end
		assert(table.isfrozen(Species.LOOKS), "frozen")
	end)

	case("I8: the looks follow each species' rig colours (tools/build-species-rigs.py)", function()
		equal(Species.hex(Species.look("Cortezon").body), "5B4630", "Cortezon shell")
		equal(Species.hex(Species.look("Cestillo").body), "B98E55", "Cestillo basket")
		equal(Species.hex(Species.look("Polvilla").accent), "B9AE98", "Polvilla wings")
		equal(Species.hex(Species.look("Tizoncillo").glow), "C8481A", "Tizoncillo ember")
	end)

	case("I8: a cria is smaller than an adult, and an unknown name falls back to Lumipol", function()
		assert(Species.CRIA_SCALE > 0.3 and Species.CRIA_SCALE < 1, "cria scale")
		equal(Species.look("Mothling").name, "Lumipol")
		equal(Species.look(nil).name, "Lumipol")
	end)

	case("I8: model references are centralized for a later swap", function()
		for _, name in ipairs({ "Cortezon", "Cestillo", "Polvilla", "Tizoncillo" }) do
			local look = Species.look(name)
			equal(look.asset, nil, "no uploaded asset yet (EI-4)")
			equal(look.rig, "assets/exports/species/SP_" .. name, "the exported rig to swap in")
		end
		assert(not source:find("rbxassetid", 1, true), "no asset ids")
		for _, word in ipairs({ "GetService", "Instance", "workspace" }) do
			assert(not source:find(word, 1, true), "pure: " .. word)
		end
	end)

	return result
end

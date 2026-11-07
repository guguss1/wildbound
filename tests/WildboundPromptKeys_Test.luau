-- Invoke with require(freshTestClone)(require(freshKeysClone), serverScriptSource, gatherScriptSource).
-- Camp prompts must not share an input, so the wrong one cannot fire next to the markers (found in W3b).
return function(Keys, serverSource, gatherSource)
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

	case("PK-1: extraction keeps E and ButtonX", function()
		equal(Keys.CAMP.extract.key, "E"); equal(Keys.CAMP.extract.pad, "ButtonX")
	end)
	case("PK-2: no two prompts that can be in reach together share a key or a pad button", function()
		local found = Keys.conflicts()
		equal(#found, 0, table.concat(found, "; "))
	end)
	case("PK-3: camp prompts have distinct screen offsets", function()
		local seen = {}
		for name, entry in pairs(Keys.CAMP) do
			local id = entry.offset[1] .. "," .. entry.offset[2]
			assert(not seen[id], name .. " repeats offset " .. id)
			seen[id] = true
		end
	end)
	case("PK-4: gather stays on G and ButtonY", function()
		equal(Keys.GATHER.key, "G"); equal(Keys.GATHER.pad, "ButtonY")
		assert(gatherSource:find("Enum.KeyCode.G", 1, true), "gather script no longer uses G")
	end)
	case("PK-5: the server script takes camp prompt inputs from this module", function()
		assert(serverSource:find("WildboundPromptKeys", 1, true), "server script does not require the module")
		for _, name in ipairs({ "extract", "hatch", "protect" }) do
			assert(serverSource:find("Keys.CAMP." .. name, 1, true), "no Keys.CAMP." .. name .. " in the server script")
		end
	end)
	case("B3 and B4: the refuge and the board have their own keys, and the server uses them", function()
		for _, name in ipairs({ "register", "board" }) do
			local entry = Keys.CAMP[name]
			assert(entry and Enum.KeyCode[entry.key] and Enum.KeyCode[entry.pad], name .. " has a key and a pad button")
			assert(serverSource:find("Keys.CAMP." .. name, 1, true), "no Keys.CAMP." .. name .. " in the server script")
		end
		local listed = table.concat(Keys.conflicts(), "; ")
		equal(#Keys.conflicts(), 0, listed)
	end)
	return result
end

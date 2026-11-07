-- Invoke with require(freshTestClone)(require(freshSettingsClone), freshSettingsClone.Source, require(freshTextClone),
-- { world = WildboundWorldClient.Source, audio = WildboundAudioClient.Source }).
-- Session-only settings (W9, M8.6). D11: Reduced effects is off by default and offered on the first start screen.
return function(Settings, source, Text, sources)
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

	case("SET-1: D11 Reduced effects starts off and tutorial hints start on", function()
		local s = Settings.new()
		equal(Settings.get(s, "reducedEffects"), false)
		equal(Settings.get(s, "hints"), true)
	end)
	case("SET-2: set accepts a boolean for a known key and nothing else", function()
		local s = Settings.new()
		equal(Settings.set(s, "reducedEffects", true), true)
		equal(Settings.get(s, "reducedEffects"), true)
		equal(Settings.set(s, "reducedEffects", "yes"), false)
		equal(Settings.set(s, "reducedEffects", nil), false)
		equal(Settings.set(s, "volume", true), false)
		equal(Settings.get(s, "volume"), nil)
		equal(Settings.get(s, "reducedEffects"), true, "a refused set changes nothing")
	end)
	case("SET-3: toggle flips and returns the new value; an unknown key returns nil", function()
		local s = Settings.new()
		equal(Settings.toggle(s, "hints"), false)
		equal(Settings.toggle(s, "hints"), true)
		equal(Settings.toggle(s, "nope"), nil)
	end)
	case("SET-4: two settings objects do not share state, and the defaults table is frozen", function()
		local a, b = Settings.new(), Settings.new()
		Settings.set(a, "reducedEffects", true)
		equal(Settings.get(b, "reducedEffects"), false)
		assert(table.isfrozen(Settings.DEFAULTS), "defaults must be frozen")
	end)
	case("SET-5: snapshot is a copy", function()
		local s = Settings.new()
		local copy = Settings.snapshot(s)
		copy.reducedEffects = true
		equal(Settings.get(s, "reducedEffects"), false)
	end)
	case("SET-6: every setting has a label and a description of plain words", function()
		for _, key in ipairs(Settings.ORDER) do
			assert(type(Settings.LABELS[key]) == "string" and #Settings.LABELS[key] > 0, key)
			assert(type(Settings.DESCRIPTIONS[key]) == "string" and #Settings.DESCRIPTIONS[key] <= 80, key)
			equal(type(Settings.DEFAULTS[key]), "boolean")
		end
		equal(#Settings.ORDER, 2)
	end)
	case("SET-7: stateText names the setting and its state in words", function()
		-- Deliberately changed in delivery D12: the settings words are Spanish now.
		equal(Settings.stateText(false), "No"); equal(Settings.stateText(true), "Sí")
		equal(Settings.buttonText("reducedEffects", false), "Efectos suaves: No")
	end)
	case("SET-8: session only: no persistence or services in the source", function()
		for _, word in ipairs({ "DataStore", "game", "GetService", "os.", "tick", "Instance", "Players", "MarketplaceService" }) do
			equal(source:find(word, 1, true), nil, "source mentions " .. word)
		end
	end)
	case("D12: reducedEffects text is Spanish", function()
		local words = type(Text) == "table" and Text.SETTINGS
		assert(type(words) == "table", "WildboundText.SETTINGS missing")
		equal(words.reducedEffects, "Efectos suaves")
		equal(Settings.LABELS.reducedEffects, words.reducedEffects)
		equal(Settings.DESCRIPTIONS.reducedEffects, words.reducedEffectsDescription)
		equal(Settings.LABELS.hints, words.hints)
		equal(Settings.DESCRIPTIONS.hints, words.hintsDescription)
		equal(Settings.stateText(true), words.on)
		equal(Settings.stateText(false), words.off)
		assert(not Settings.DESCRIPTIONS.reducedEffects:find("Softer", 1, true), "no English left")
	end)
	case("D12: all three consumers read one switch", function()
		sources = type(sources) == "table" and sources or {}
		local world, audio = sources.world or "", sources.audio or ""
		assert(world:find("Atmos.at(state.clockTime, zone, reduced)", 1, true), "fog and light read the switch")
		assert(world:find("View.hitFlash(payload.outcome, reduced)", 1, true), "the defeat fade reads the switch")
		assert(world:find('GetAttributeChangedSignal("Reduced")', 1, true), "the world client follows the one attribute")
		assert(audio:find('worldGui:GetAttribute("Reduced") == true', 1, true), "audio reads the same attribute")
		assert(not audio:find("ReducedAudio", 1, true) and not world:find("ReducedAudio", 1, true), "no second switch")
		assert(world:find("reducedText(", 1, true), "the world button shows the Spanish words")
	end)

	return result
end

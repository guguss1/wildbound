-- Invoke with require(freshTestClone)(require(freshTutorialClone), freshTutorialClone.Source).
-- First-run tutorial, rewritten for the expedition islands (K1, docs/mechanics/wildbound-expedition-islands.md
-- section 3): follow the lanterns to the clearing, take the cria, register it at the refuge. Pure state. The old
-- gather, extract and craft steps (W9, M8.5) were deliberately replaced; gathering moves to the board's hints.
return function(Tutorial, source)
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
	local none = { reachedClaro = false, carrying = false, registered = 0 }
	local function facts(extra)
		local value = table.clone(none)
		for key, item in pairs(extra or {}) do value[key] = item end
		return value
	end

	case("K1: three Spanish steps claro, cria, refugio", function()
		local t = Tutorial.new()
		equal(#Tutorial.STEPS, 3)
		equal(Tutorial.STEPS[1].id, "claro"); equal(Tutorial.STEPS[2].id, "cria"); equal(Tutorial.STEPS[3].id, "refugio")
		equal(Tutorial.STEPS[1].short, "1/3 Sigue los faroles hasta el claro.")
		equal(Tutorial.STEPS[2].short, "2/3 Acércate sin correr y toma la cría.")
		equal(Tutorial.STEPS[3].short, "3/3 Llévala al refugio y regístrala.")
		equal(Tutorial.DONE_TEXT, "¡Es tuya! Más adentro duermen criaturas más raras.")
		equal(Tutorial.step(t).id, "claro"); equal(Tutorial.state(t), "running")
		equal(Tutorial.progress(t), "Paso 1 de 3")
	end)

	case("K1: step 1 completes in the clearing", function()
		local t = Tutorial.new()
		equal(Tutorial.observe(t, facts()), false)
		equal(Tutorial.observe(t, facts({ reachedClaro = true })), true)
		equal(Tutorial.step(t).id, "cria")
		local near = Tutorial.factsFrom({}, false, { x = Tutorial.CLARO.x + 10, z = Tutorial.CLARO.z })
		equal(near.reachedClaro, true)
		local far = Tutorial.factsFrom({}, false, { x = Tutorial.CLARO.x + Tutorial.CLARO.radius + 1, z = Tutorial.CLARO.z })
		equal(far.reachedClaro, false)
	end)

	case("K1: step 2 completes on a carried cria", function()
		local t = Tutorial.new()
		Tutorial.observe(t, facts({ reachedClaro = true }))
		equal(Tutorial.observe(t, facts({ reachedClaro = true })), false)
		equal(Tutorial.observe(t, facts({ carrying = true })), true)
		equal(Tutorial.step(t).id, "refugio")
		local f = Tutorial.factsFrom({ carrying = { uid = "wb:1", kind = "Creature", stage = "Cria" } }, false, nil)
		equal(f.carrying, true); equal(f.reachedClaro, true, "carrying a cria means the clearing was reached")
	end)

	case("K1: step 3 completes on the first registration", function()
		local t = Tutorial.new()
		Tutorial.observe(t, facts({ carrying = true }))
		equal(Tutorial.step(t).id, "refugio", "a carried cria skips ahead in order")
		equal(Tutorial.observe(t, facts({ carrying = true })), false)
		equal(Tutorial.observe(t, facts({ registered = 1 })), true)
		equal(Tutorial.state(t), "done"); equal(Tutorial.step(t), nil)
		local f = Tutorial.factsFrom({ registered = { { uid = "a" } } }, false, nil)
		equal(f.registered, 1)
	end)

	case("TUT-6: being in the clearing early does not skip ahead", function()
		local t = Tutorial.new()
		Tutorial.observe(t, facts({ reachedClaro = true }))
		equal(Tutorial.step(t).id, "cria")
	end)

	case("TUT-7: skip ends it for good and later facts change nothing", function()
		local t = Tutorial.new()
		Tutorial.skip(t)
		equal(Tutorial.state(t), "skipped"); equal(Tutorial.step(t), nil)
		equal(Tutorial.observe(t, facts({ registered = 1 })), false)
		equal(Tutorial.state(t), "skipped")
	end)

	case("TUT-8: restart runs it again from the first step", function()
		local t = Tutorial.new()
		Tutorial.skip(t)
		Tutorial.restart(t)
		equal(Tutorial.state(t), "running"); equal(Tutorial.step(t).id, "claro")
	end)

	case("TUT-9: factsFrom reads a state snapshot and a position, tolerating missing fields", function()
		local empty = Tutorial.factsFrom(nil, false, nil)
		equal(empty.reachedClaro, false); equal(empty.carrying, false); equal(empty.registered, 0)
		equal(Tutorial.factsFrom({ registered = "x" }, false, { x = 0 / 0, z = 1 }).registered, 0)
		equal(Tutorial.factsFrom({}, false, { x = 0 / 0, z = 1 }).reachedClaro, false)
	end)

	case("TUT-10: the card text is short on phones, numbered, and in Spanish", function()
		local t = Tutorial.new()
		for index, step in ipairs(Tutorial.STEPS) do
			local compact, full = Tutorial.cardText(step, true), Tutorial.cardText(step, false)
			assert(#compact <= 46, compact)
			assert(#full <= 80 and #full > #compact, full)
			assert(compact:sub(1, 3) == index .. "/3", compact)
			assert(utf8.len(full) ~= nil, "valid UTF-8")
		end
		equal(Tutorial.progress(t), "Paso 1 de 3")
	end)

	case("TUT-11: the finish line is encouraging and short", function()
		-- Deliberately changed (K1): the Spanish line is 56 bytes with its accents; it was 50.
		assert(#Tutorial.DONE_TEXT <= 56, Tutorial.DONE_TEXT)
	end)

	case("TUT-12: pure: no services, clock, randomness or persistence", function()
		for _, word in ipairs({ "DataStore", "game", "GetService", "os.", "tick", "Instance", "Random", "task." }) do
			equal(source:find(word, 1, true), nil, "source mentions " .. word)
		end
	end)

	return result
end

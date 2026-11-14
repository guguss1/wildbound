-- Invoke with require(freshTestClone)(require(freshTutorialClone), freshTutorialClone.Source).
-- First-run guide, rewritten for the egg loop (docs/design/wildbound-egg-loop.md section 3): steal an egg, carry it
-- home, see it go into the incubator, wait for it to hatch. Pure state. The K1 cria steps (claro, cria, refugio) were
-- deliberately replaced; a returning player whose first facts finish everything is a silent "veteran".
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
	local none = { carryingEgg = false, stored = 0, incubating = 0, registered = 0 }
	local function facts(extra)
		local value = table.clone(none)
		for key, item in pairs(extra or {}) do value[key] = item end
		return value
	end
	-- A new player: the first observation sees nothing yet, so later ones advance normally.
	local function fresh()
		local t = Tutorial.new()
		Tutorial.observe(t, facts())
		return t
	end

	case("EL-G1: four Spanish steps robar, llevar, incubar, nacer", function()
		local t = Tutorial.new()
		equal(#Tutorial.STEPS, 4)
		local ids = {}
		for _, step in ipairs(Tutorial.STEPS) do table.insert(ids, step.id) end
		equal(table.concat(ids, ","), "robar,llevar,incubar,nacer")
		equal(Tutorial.STEPS[1].short, "1/4 Busca un nido y mantén E.")
		equal(Tutorial.STEPS[2].short, "2/4 Lleva el huevo a tu base.")
		equal(Tutorial.STEPS[3].short, "3/4 Tu huevo va a la incubadora.")
		equal(Tutorial.STEPS[4].short, "4/4 Espera a que nazca.")
		equal(Tutorial.DONE_TEXT, "¡Nuevo compañero! Roba más huevos para tu colección.")
		equal(Tutorial.step(t).id, "robar"); equal(Tutorial.state(t), "running")
		equal(Tutorial.progress(t), "Paso 1 de 4")
	end)

	case("EL-G2: one step at a time: steal, carry home, incubate, hatch", function()
		local t = fresh()
		equal(Tutorial.step(t).id, "robar", "nothing yet")
		equal(Tutorial.observe(t, facts({ carryingEgg = true })), true)
		equal(Tutorial.step(t).id, "llevar", "an egg in the backpack")
		equal(Tutorial.observe(t, facts({ carryingEgg = true })), false, "still carrying")
		equal(Tutorial.observe(t, facts({ stored = 1 })), true)
		equal(Tutorial.step(t).id, "incubar", "banked at the base")
		equal(Tutorial.observe(t, facts({ incubating = 1 })), true)
		equal(Tutorial.step(t).id, "nacer", "in the cradle")
		equal(Tutorial.observe(t, facts({ registered = 1 })), true)
		equal(Tutorial.state(t), "done"); equal(Tutorial.step(t), nil)
	end)

	case("EL-G3: a later fact completes the earlier steps in order (auto-fill skips the stored step)", function()
		local t = fresh()
		Tutorial.observe(t, facts({ incubating = 1 }))
		equal(Tutorial.step(t).id, "nacer", "an egg went straight into the cradle")
	end)

	case("EL-G4: losing the egg does not go back", function()
		local t = fresh()
		Tutorial.observe(t, facts({ carryingEgg = true }))
		equal(Tutorial.observe(t, facts()), false)
		equal(Tutorial.step(t).id, "llevar")
	end)

	case("EL-G5: a returning player is a veteran: no card, no closing line", function()
		local t = Tutorial.new()
		equal(Tutorial.observe(t, facts({ registered = 2 })), true)
		equal(Tutorial.state(t), "veteran"); equal(Tutorial.step(t), nil)
		local partial = Tutorial.new()
		Tutorial.observe(partial, facts({ stored = 1 }))
		equal(Tutorial.state(partial), "running", "a stored egg but nothing hatched: the guide resumes")
		equal(Tutorial.step(partial).id, "incubar")
	end)

	case("TUT-7: skip ends it for good and later facts change nothing", function()
		local t = fresh()
		Tutorial.skip(t)
		equal(Tutorial.state(t), "skipped"); equal(Tutorial.step(t), nil)
		equal(Tutorial.observe(t, facts({ registered = 1 })), false)
		equal(Tutorial.state(t), "skipped")
	end)

	case("TUT-8: restart runs it again from the first step, even for a veteran", function()
		local t = Tutorial.new()
		Tutorial.observe(t, facts({ registered = 1 }))
		Tutorial.restart(t)
		equal(Tutorial.state(t), "running"); equal(Tutorial.step(t).id, "robar")
		Tutorial.observe(t, facts({ registered = 1 }))
		equal(Tutorial.state(t), "done", "a replay ends with the closing line, not silently")
	end)

	case("TUT-9: factsFrom reads a state snapshot, tolerating missing fields", function()
		local empty = Tutorial.factsFrom(nil, false, nil)
		equal(empty.carryingEgg, false); equal(empty.stored, 0); equal(empty.incubating, 0); equal(empty.registered, 0)
		local f = Tutorial.factsFrom({ pending = { { kind = "Egg", inArms = true }, { kind = "Nightbloom" } },
			bankedEggs = { { uid = "a" }, { uid = "b" } }, incubating = { { uid = "c" } }, registered = "x" }, false, nil)
		equal(f.carryingEgg, true); equal(f.stored, 2); equal(f.incubating, 1); equal(f.registered, 0)
		equal(Tutorial.factsFrom({ pending = { { kind = "Egg", inArms = false } } }).carryingEgg, false,
			"an egg in the bag but not in the backpack slot")
	end)

	case("TUT-10: the card text is short on phones, numbered, and in Spanish", function()
		local t = Tutorial.new()
		for index, step in ipairs(Tutorial.STEPS) do
			local compact, full = Tutorial.cardText(step, true), Tutorial.cardText(step, false)
			assert(#compact <= 46, compact)
			assert(#full <= 80 and #full > #compact, full)
			assert(compact:sub(1, 3) == index .. "/4", compact)
			assert(utf8.len(full) ~= nil, "valid UTF-8")
		end
		equal(Tutorial.progress(t), "Paso 1 de 4")
	end)

	case("TUT-11: the finish line is encouraging and short", function()
		assert(#Tutorial.DONE_TEXT <= 56, Tutorial.DONE_TEXT)
	end)

	case("TUT-12: pure: no services, clock, randomness or persistence", function()
		for _, word in ipairs({ "DataStore", "game", "GetService", "os.", "tick", "Instance", "Random", "task." }) do
			equal(source:find(word, 1, true), nil, "source mentions " .. word)
		end
	end)

	return result
end

-- Invoke with require(freshTestClone)(require(freshTutorialClone), freshTutorialClone.Source).
-- First-run tutorial (W9, M8.5): gather, extract at camp, then look at what camp can craft. Pure state.
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
	local none = { carried = 0, pending = 0, banked = 0, ember = 0, campOpen = false }
	local function facts(extra)
		local value = table.clone(none)
		for key, item in pairs(extra or {}) do value[key] = item end
		return value
	end

	case("TUT-1: a new tutorial runs at the gather step", function()
		local t = Tutorial.new()
		equal(Tutorial.step(t).id, "gather"); equal(Tutorial.state(t), "running"); equal(#Tutorial.STEPS, 3)
	end)
	case("TUT-2: nothing happens until the player carries something", function()
		local t = Tutorial.new()
		equal(Tutorial.observe(t, facts()), false)
		equal(Tutorial.step(t).id, "gather")
		equal(Tutorial.observe(t, facts({ carried = 2 })), true)
		equal(Tutorial.step(t).id, "extract")
	end)
	case("TUT-3: a creature or egg in the bag also counts as gathering", function()
		local t = Tutorial.new()
		Tutorial.observe(t, facts({ pending = 1 }))
		equal(Tutorial.step(t).id, "extract")
	end)
	case("TUT-4: extract completes only when something is banked", function()
		local t = Tutorial.new()
		Tutorial.observe(t, facts({ carried = 3 }))
		equal(Tutorial.observe(t, facts({ carried = 3 })), false)
		Tutorial.observe(t, facts({ banked = 3 }))
		equal(Tutorial.step(t).id, "camp")
	end)
	case("TUT-5: the camp step needs the Camp tab opened, then the tutorial is done", function()
		local t = Tutorial.new()
		Tutorial.observe(t, facts({ banked = 5 }))
		equal(Tutorial.step(t).id, "camp", "banked facts skip ahead in order")
		equal(Tutorial.observe(t, facts({ banked = 5 })), false)
		equal(Tutorial.observe(t, facts({ banked = 5, campOpen = true })), true)
		equal(Tutorial.state(t), "done"); equal(Tutorial.step(t), nil)
	end)
	case("TUT-6: opening the camp early does not skip gather or extract", function()
		local t = Tutorial.new()
		Tutorial.observe(t, facts({ campOpen = true }))
		equal(Tutorial.step(t).id, "gather")
	end)
	case("TUT-7: skip ends it for good and later facts change nothing", function()
		local t = Tutorial.new()
		Tutorial.skip(t)
		equal(Tutorial.state(t), "skipped"); equal(Tutorial.step(t), nil)
		equal(Tutorial.observe(t, facts({ banked = 5, campOpen = true })), false)
		equal(Tutorial.state(t), "skipped")
	end)
	case("TUT-8: restart runs it again from the first step", function()
		local t = Tutorial.new()
		Tutorial.skip(t)
		Tutorial.restart(t)
		equal(Tutorial.state(t), "running"); equal(Tutorial.step(t).id, "gather")
	end)
	case("TUT-9: factsFrom reads a state snapshot, tolerating missing fields", function()
		local f = Tutorial.factsFrom({ carried = { fogbark = 2, glowmoss = 1 }, pending = { {}, {} },
			banked = { fogbark = 4, glowmoss = 0, nightbloom = 1 }, ember = 7 }, true)
		equal(f.carried, 3); equal(f.pending, 2); equal(f.banked, 5); equal(f.ember, 7); equal(f.campOpen, true)
		local empty = Tutorial.factsFrom(nil, false)
		equal(empty.carried, 0); equal(empty.pending, 0); equal(empty.banked, 0); equal(empty.ember, 0); equal(empty.campOpen, false)
		equal(Tutorial.factsFrom({ ember = 0 / 0 }, false).ember, 0)
	end)
	case("TUT-10: the card text is short on phones, numbered, and plain English", function()
		local t = Tutorial.new()
		for index, step in ipairs(Tutorial.STEPS) do
			local compact, full = Tutorial.cardText(step, true), Tutorial.cardText(step, false)
			assert(#compact <= 46, compact)
			assert(#full <= 80 and #full > #compact, full)
			assert(compact:sub(1, 3) == index .. "/3", compact)
		end
		equal(Tutorial.progress(t), "Step 1 of 3")
	end)
	case("TUT-11: the finish line is encouraging and short", function()
		assert(#Tutorial.DONE_TEXT <= 50, Tutorial.DONE_TEXT)
	end)
	case("TUT-12: pure: no services, clock, randomness or persistence", function()
		for _, word in ipairs({ "DataStore", "game", "GetService", "os.", "tick", "Instance", "Random", "task." }) do
			equal(source:find(word, 1, true), nil, "source mentions " .. word)
		end
	end)

	return result
end

-- Invoke with require(freshTestClone)(require(freshCandyDonGlaseonAngerClone)).
-- Caramelo v2 (odd/tasks/wildbound-caramelo-v2.md, DG5): Rabia creciente, Don Glaseon's rising anger, as pure rules.
-- The meter rises while his target carries an egg inside his territory, and each perfect dodge adds a chunk. Full, he
-- rages for 10 s (his cooldowns are halved); the meter resets when the target leaves or no longer carries an egg.
return function(Anger)
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
	local function near(actual, expected, label, tolerance)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-6),
			(label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function steps(s, from, to, building)
		local changes = {}
		for i = 0, math.floor((to - from) / 0.05 + 1e-6) do
			local change = Anger.step(s, from + i * 0.05, building)
			if change then table.insert(changes, change) end
		end
		return changes
	end

	case("DG5: the numbers: full after 10 s of carrying, a dodge adds a quarter, 10 s of rage, cooldowns halved", function()
		near(Anger.FILL_SECONDS, 10, "fill"); near(Anger.DODGE_CHUNK, 0.25, "dodge chunk"); near(Anger.RAGE_SECONDS, 10, "rage")
		near(Anger.COOLDOWN_SCALE, 0.5, "cooldowns in a rage"); near(Anger.REPORT_STEP, 0.1, "a report each tenth")
	end)

	case("DG5: it rises with time while the target carries an egg in his territory, and reports each tenth", function()
		local s = Anger.new()
		local changes = steps(s, 0, 5, true)
		near(s.value, 0.5, "half after 5 s", 0.006)
		assert(#changes >= 4 and #changes <= 6, "reports " .. #changes)
		for i = 2, #changes do assert(changes[i].value > changes[i - 1].value, "the reports rise") end
		equal(changes[#changes].rage, false, "no rage yet")
		equal(Anger.raging(s, 5), false); near(Anger.cooldownScale(s, 5), 1, "normal cooldowns")
	end)

	case("DG5: full, he rages 10 s with halved cooldowns, then the meter is empty again", function()
		local s = Anger.new()
		local changes = steps(s, 0, 10.5, true)
		local rage
		for _, c in ipairs(changes) do if c.rage and not rage then rage = c end end
		assert(rage, "no rage report"); near(rage.value, 1, "full")
		near(s.rageUntil, 10 + 10, "rage for 10 s", 0.06)
		equal(Anger.raging(s, 12), true); near(Anger.cooldownScale(s, 12), 0.5, "halved")
		local after = steps(s, 10.55, 21, true)
		equal(Anger.raging(s, 21), false, "the rage ended")
		local ended
		for _, c in ipairs(after) do if c.rage == false and c.value == 0 then ended = ended or c end end
		assert(ended, "no report of the rage's end")
		assert(s.value < 0.2, "the meter starts again from empty")
	end)

	case("DG5: a perfect dodge adds a chunk; four fill it", function()
		local s = Anger.new()
		steps(s, 0, 1, true)
		local c = Anger.dodge(s, 1)
		assert(c, "no report for a dodge"); near(c.value, 0.35, "0.1 + 0.25", 0.006)
		Anger.dodge(s, 1.1); Anger.dodge(s, 1.2)
		local full = Anger.dodge(s, 1.3)
		equal(full.rage, true, "the fourth dodge fills it"); near(s.rageUntil, 11.3, "rage from the dodge", 1e-6)
		equal(Anger.dodge(s, 2), nil, "no chunk during a rage")
	end)

	case("DG5: it resets when the target stops carrying or leaves, and a rage ends with it", function()
		local s = Anger.new()
		steps(s, 0, 6, true)
		local reset = Anger.step(s, 6.05, false)
		assert(reset, "no report of the reset"); equal(reset.value, 0); equal(reset.rage, false)
		equal(Anger.step(s, 6.1, false), nil, "nothing more to report")
		steps(s, 7, 17.5, true)
		equal(Anger.raging(s, 17.5), true, "raging again")
		local stop = Anger.step(s, 17.55, false)
		equal(stop.rage, false, "the rage ends when the target drops the egg"); equal(stop.value, 0)
		equal(Anger.raging(s, 17.6), false)
	end)

	return result
end

-- Invoke with require(freshTestClone)(require(freshHuntClone)) in Studio Edit/Server.
-- Inputs are server-filtered, visible, in-detection candidates; life is the Character identity.
return function(Hunt)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected)
		assert(actual == expected, "Expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local lifeA, lifeB, lifeC = {}, {}, {}
	local function seen(id, life, distance, position)
		return { id = id, life = life, distance = distance, visible = true, valid = true,
			position = position or Vector3.new(id, 0, 0) }
	end
	local function fixture()
		local current = seen(1, lifeA, 20)
		return Hunt.new(current, 0), current
	end
	local function tick(state, now, current, candidates)
		return Hunt.step(state, now, current, candidates or {})
	end

	case("retains target without both meaningful advantages", function()
		local state, current = fixture()
		for _, now in ipairs({ 0, 0.4, 0.8, 1.2 }) do
			local out = tick(state, now, current, { seen(2, lifeB, 16.1) })
			equal(out.id, 1); equal(out.switched, false)
		end
		current.distance = 10
		for _, now in ipairs({ 1.6, 2, 2.4 }) do
			equal(tick(state, now, current, { seen(2, lifeB, 7) }).id, 1)
		end
	end)

	case("clear sustained challenger changes target only after 0.6 seconds", function()
		local state, current = fixture()
		local challenger = seen(2, lifeB, 16)
		equal(tick(state, 0, current, { challenger }).id, 1)
		equal(tick(state, 0.4, current, { challenger }).id, 1)
		local out = tick(state, 0.8, current, { challenger })
		equal(out.id, 2); equal(out.life, lifeB); equal(out.switched, true)
	end)

	case("scan is limited to once per 0.4 seconds", function()
		local state, current = fixture()
		equal(tick(state, 0, current, { seen(2, lifeB, 10) }).scanned, true)
		equal(tick(state, 0.2, current, { seen(2, lifeB, 10) }).scanned, false)
		equal(tick(state, 0.4, current, { seen(2, lifeB, 10) }).scanned, true)
	end)

	case("switch cooldown blocks a second switch for one second", function()
		local state, current = fixture()
		local b = seen(2, lifeB, 16)
		for _, now in ipairs({ 0, 0.4, 0.8 }) do tick(state, now, current, { b }) end
		local c = seen(3, lifeC, 8)
		for _, now in ipairs({ 1.2, 1.6 }) do equal(tick(state, now, b, { c }).id, 2) end
		-- The challenger must itself persist across scans; cooldown cannot cause an early switch.
		local out = tick(state, 2, b, { c })
		equal(out.id, 3); equal(out.switched, true)
	end)

	case("challenger character replacement cancels accumulated evidence", function()
		local state, current = fixture()
		local oldB, newB = seen(2, lifeB, 10), seen(2, lifeC, 10)
		tick(state, 0, current, { oldB }); tick(state, 0.4, current, { oldB })
		equal(tick(state, 0.8, current, { newB }).id, 1)
		equal(tick(state, 1.2, current, { newB }).id, 1)
		equal(tick(state, 1.6, current, { newB }).id, 2)
	end)

	case("target replacement immediately invalidates its locked life", function()
		local state = fixture()
		local out = tick(state, 0, seen(1, lifeC, 20))
		equal(out.expired, true); equal(out.canAttack, false)
	end)

	case("last visible position is used while hidden and expires at 1.5 seconds", function()
		local state, current = fixture()
		local remembered = Vector3.new(9, 2, 4)
		current.position = remembered
		tick(state, 0, current)
		local hidden = setmetatable({ id = 1, life = lifeA, valid = true, visible = false }, {
			__index = function(_, key)
				if key == "position" then error("hidden current position read") end
			end,
		})
		local out = tick(state, 1.49, hidden)
		equal(out.destination, remembered); equal(out.canAttack, false); equal(out.expired, false)
		out = tick(state, 1.5, hidden)
		equal(out.expired, true); equal(out.canAttack, false)
	end)

	case("regained sight refreshes destination and permits normal attack checks", function()
		local state, current = fixture()
		tick(state, 0, current)
		tick(state, 1, { id = 1, life = lifeA, valid = true, visible = false })
		current.position = Vector3.new(3, 0, 8)
		local out = tick(state, 1.2, current)
		equal(out.destination, current.position); equal(out.canAttack, true); equal(out.expired, false)
	end)

	case("equal distance challengers resolve by stable ID", function()
		local state, current = fixture()
		local b, c = seen(2, lifeB, 10), seen(3, lifeC, 10)
		tick(state, 0, current, { c, b }); tick(state, 0.4, current, { b, c })
		equal(tick(state, 0.8, current, { c, b }).id, 2)
	end)
	return result
end

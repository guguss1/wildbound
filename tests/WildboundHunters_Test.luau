-- Invoke with require(freshTestClone)(require(freshHuntersClone), freshHuntersClone.Source).
-- Fix pass (FP2): one Silueta per player. The pure roster: a hunter per owner under the cap, the lowest free slot, a
-- hunter only ever considers its owner, and the per-slot stagger. The world wiring is in WildboundHunterWiring_Test.
return function(Hunters, source)
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

	case("FP2: two players get two hunters, each bound to its owner, in the lowest free slots", function()
		local roster = Hunters.new()
		equal(Hunters.count(roster), 0)
		local a = Hunters.add(roster, 101, 8)
		local b = Hunters.add(roster, 202, 8)
		assert(a and b, "two hunters")
		equal(a.owner, 101); equal(b.owner, 202)
		equal(a.slot, 1); equal(b.slot, 2)
		equal(Hunters.count(roster), 2)
		equal(Hunters.get(roster, 101), a); equal(Hunters.get(roster, 202), b)
		equal(Hunters.get(roster, 303), nil)
	end)

	case("FP2: the cap refuses a hunter past MAX_HUNTERS, and an owner never gets two", function()
		local roster = Hunters.new()
		assert(Hunters.add(roster, 1, 2) and Hunters.add(roster, 2, 2), "two under a cap of two")
		local third, reason = Hunters.add(roster, 3, 2)
		equal(third, nil); equal(reason, "Full")
		local again, why = Hunters.add(roster, 1, 8)
		equal(again, nil); equal(why, "Duplicate")
		equal(Hunters.count(roster), 2)
		for _, bad in ipairs({ nil, 0 / 0, math.huge, "5" }) do
			local record, cause = Hunters.add(roster, bad, 8)
			equal(record, nil); equal(cause, "BadOwner", tostring(bad))
		end
		local none, limitReason = Hunters.add(roster, 9, 0)
		equal(none, nil); equal(limitReason, "BadLimit")
		equal(select(2, Hunters.add(roster, 9, 0 / 0)), "BadLimit")
		equal(select(2, Hunters.add(nil, 9, 8)), "BadRoster")
	end)

	case("FP2: a player who leaves frees the slot and the next player reuses it", function()
		local roster = Hunters.new()
		Hunters.add(roster, 1, 8); Hunters.add(roster, 2, 8); Hunters.add(roster, 3, 8)
		local gone = Hunters.remove(roster, 2)
		equal(gone and gone.owner, 2); equal(Hunters.count(roster), 2); equal(Hunters.get(roster, 2), nil)
		equal(Hunters.remove(roster, 2), nil, "removing twice does nothing")
		equal(Hunters.remove(roster, 0 / 0), nil)
		local fresh = Hunters.add(roster, 4, 8)
		equal(fresh.slot, 2, "the freed slot is reused")
		equal(Hunters.count(roster), 3)
	end)

	case("FP2: hunter A never considers player B as quarry", function()
		local a = Hunters.add(Hunters.new(), 101, 8)
		local list = Hunters.quarry(a, { { id = 202, distance = 3 }, { id = 101, distance = 40 }, { id = 303 } })
		equal(#list, 1); equal(list[1].id, 101)
		equal(#Hunters.quarry(a, { { id = 202 }, { id = 303 } }), 0, "nobody else, however close")
		equal(#Hunters.quarry(a, {}), 0)
		equal(#Hunters.quarry(a, nil), 0)
		equal(#Hunters.quarry(nil, { { id = 101 } }), 0)
		equal(Hunters.owns(a, 101), true); equal(Hunters.owns(a, 202), false); equal(Hunters.owns(a, 0 / 0), false)
	end)

	case("FP2: slots are staggered over the patrol corners and the replan cadence", function()
		local seen = {}
		for slot = 1, 5 do
			local s = Hunters.stagger(slot)
			assert(s.patrolIndex >= 1 and s.patrolIndex <= 4, "a corner")
			assert(s.planDelay >= 0 and s.planDelay < 0.5, "under the plan interval")
			seen[slot] = s
		end
		equal(seen[1].patrolIndex, 1); equal(seen[2].patrolIndex, 2); equal(seen[4].patrolIndex, 4); equal(seen[5].patrolIndex, 1)
		equal(seen[1].planDelay, 0); assert(seen[2].planDelay > 0 and seen[3].planDelay > seen[2].planDelay, "spread")
		equal(Hunters.stagger(nil).patrolIndex, 1); equal(Hunters.stagger(-3).planDelay, 0)
	end)

	case("FP2: the module is pure", function()
		for _, banned in ipairs({ "game:", "workspace", "Instance.new", "os.clock", "tick(", "Random", "math.random",
			"RemoteEvent", "SetAttribute", "GetAttribute" }) do
			assert(not source:find(banned, 1, true), banned .. " found")
		end
	end)

	return result
end

-- Invoke with require(freshTestClone)(require(freshOwnershipClone), worldSource, guardSource).
-- Fakes stand in for CollectionService and instances. Found in W6, measured in W9: a destroyed Script's own
-- Destroying handler never runs, so cleanup moved to a guard that sweeps tagged objects.
return function(Ownership, worldSource, guardSource)
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
	local function fakeService()
		local service = { tagged = {} }
		function service:AddTag(instance, tag)
			self.tagged[tag] = self.tagged[tag] or {}
			table.insert(self.tagged[tag], instance)
		end
		function service:GetTagged(tag) return table.clone(self.tagged[tag] or {}) end
		return service
	end
	local function fakeInstance(name, failing)
		return { IsFakeInstance = true, Name = name, destroyed = 0, Destroy = function(self)
			if failing then error("cannot destroy") end
			self.destroyed += 1
		end }
	end

	case("OWN-1: claim tags the instance and returns it", function()
		local service, item = fakeService(), fakeInstance("a")
		equal(Ownership.claim(service, item), item)
		equal(#service:GetTagged(Ownership.TAG), 1)
	end)
	case("OWN-2: claim ignores values that are not instances", function()
		local service = fakeService()
		equal(Ownership.claim(service, nil), nil)
		equal(Ownership.claim(service, 5), 5)
		equal(Ownership.claim(service, {}) ~= nil, true)
		equal(#service:GetTagged(Ownership.TAG), 0)
	end)
	case("OWN-3: sweep destroys exactly the tagged instances", function()
		local service = fakeService()
		local a, b, other = fakeInstance("a"), fakeInstance("b"), fakeInstance("other")
		Ownership.claim(service, a); Ownership.claim(service, b)
		service:AddTag(other, "SomeoneElse")
		equal(Ownership.sweep(service), 2)
		equal(a.destroyed, 1); equal(b.destroyed, 1); equal(other.destroyed, 0)
	end)
	case("OWN-4: one instance that fails to destroy does not stop the sweep", function()
		local service = fakeService()
		local bad, good = fakeInstance("bad", true), fakeInstance("good")
		Ownership.claim(service, bad); Ownership.claim(service, good)
		equal(Ownership.sweep(service), 1)
		equal(good.destroyed, 1)
	end)
	case("OWN-5: sweeping with nothing tagged does nothing", function()
		equal(Ownership.sweep(fakeService()), 0)
	end)
	case("OWN-6: the world script tags its runtime folder and every remote it creates", function()
		assert(worldSource:find("WildboundOwnership", 1, true), "world script does not require the module")
		assert(worldSource:find("Ownership.claim(CollectionService, runtime)", 1, true), "runtime is not claimed")
		assert(worldSource:find("Ownership.claim(CollectionService, value)", 1, true), "remotes are not claimed")
	end)
	case("OWN-7: the guard watches the world script from its own thread and sweeps by tag", function()
		assert(guardSource:find("world.Destroying", 1, true), "no Destroying watch")
		assert(guardSource:find("AncestryChanged", 1, true), "no AncestryChanged watch")
		assert(guardSource:find("Ownership.sweep(CollectionService)", 1, true), "no sweep call")
		assert(not guardSource:find("Destroy()", 1, true), "the guard must not destroy anything itself")
	end)

	return result
end

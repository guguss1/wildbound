-- Invoke with require(freshTestClone)(require(freshAnalyticsClone), { server = WildboundServer.Source,
-- flags = freshFlagsClone.Source, capture = WildboundCaptureSession.Source }, require(freshFlagsClone),
-- require(freshConfigClone), require(freshWildClone)).
-- W16 wiring checks on source text and shared tables: the flag defaults to off, the server derives every event
-- itself (no remote reaches the seam, AN-3), nothing runs per frame except the camp observation, and the module's
-- lists cannot drift from the capture reasons, tiers and gather zones they describe. Behavior is in the Play check.
return function(Analytics, sources, Flags, Config, Wild)
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
	local server = sources.server
	local function count(text, pattern)
		local n = 0
		for _ in text:gmatch(pattern) do n += 1 end
		return n
	end
	local function between(text, from, to)
		local a = text:find(from, 1, true)
		assert(a, "missing marker " .. from)
		local b = text:find(to, a, true)
		assert(b, "missing marker " .. to)
		return text:sub(a, b)
	end

	case("the flag defaults to off and the damage flags are untouched", function()
		equal(Flags.analyticsMode, "off")
		equal(Flags.damageMode, "off")
		equal(next(Flags.privateTestPlaceIds), nil)
		assert(table.isfrozen(Flags), "frozen")
		assert(sources.flags:find('analyticsMode = "off"', 1, true), "flag source")
	end)
	case("the server reads the flag and builds the seam through fromMode", function()
		assert(server:find('script.Parent:WaitForChild("WildboundAnalytics")', 1, true), "requires the module")
		assert(server:find("WildboundFlags", 1, true), "reads the flags module")
		assert(server:find("Analytics.fromMode(", 1, true), "uses fromMode")
		assert(server:find("analyticsMode", 1, true), "reads analyticsMode")
	end)
	case("no source names an analytics, http or data store service (AN-7)", function()
		for _, text in pairs({ server, sources.flags }) do
			for _, word in ipairs({ "AnalyticsService", "HttpService:Post", "HttpService:Request", "DataStoreService" }) do
				assert(not text:find(word, 1, true), "found " .. word)
			end
		end
	end)
	case("no remote reaches the seam, and the action remote's handler never touches it (AN-3)", function()
		for line in server:gmatch("[^\n]+") do
			if line:find("Instance.new(\"Remote", 1, true) or line:find("Instance.new(\"Bindable", 1, true) then
				assert(not line:lower():find("analytics", 1, true), "an instance made for analytics: " .. line)
			end
		end
		-- The only analytics instance is the record-mode dump, a BindableFunction in ServerStorage, never replicated.
		assert(server:find("dump.Parent = telemetry", 1, true), "the dump must live in the server-only telemetry folder")
		local handler = between(server, "actionRemote.OnServerEvent:Connect", "local function bindCharacter")
		assert(not handler:find("analytics", 1, true), "handler mentions analytics")
		assert(not server:find("analytics:fromClient", 1, true), "fromClient is not wired in W16")
	end)
	case("spent is only ever called with a literal name", function()
		local calls = 0
		for args in server:gmatch("analytics:spent%(([^)]*)%)") do
			calls += 1
			assert(args:match('^[%w_.]+,%s*"%a+"$'), "not a literal: " .. args)
		end
		assert(calls >= 3, "expected the upgrade, skill and capsule hooks, found " .. calls)
	end)
	case("every moment is hooked once or more where the server already decides it", function()
		for _, call in ipairs({ "analytics:join(", "analytics:leave(", "analytics:closeAll(", "analytics:observeCamp(",
			'analytics:gain(player.UserId, "pickup")', 'analytics:gain(player.UserId, "gather"', "analytics:capture(",
			"analytics:extracted(", "analytics:crafted(", "analytics:noteStrike(", "analytics:death(",
			"analytics:registered(" }) do
			assert(server:find(call, 1, true), "missing " .. call)
		end
		assert(count(server, "analytics:death%(") >= 2, "both defeat boundaries")
	end)
	case("the heartbeat loop makes only the camp observation call", function()
		local loop = between(server, "RunService.Heartbeat:Connect", "-- Camp sinks and protections")
		equal(count(loop, "analytics:observeCamp%("), 1)
		equal(count(loop, "analytics:"), 1, "other calls in the loop")
	end)
	case("only the record mode creates the dump function, in server storage", function()
		local a = server:find("if recorder then", 1, true)
		assert(a, "guard")
		local b = server:find("AnalyticsDump", 1, true)
		assert(b and b > a, "dump after the guard")
		assert(server:find("telemetry", a, true), "lives with the telemetry folder")
	end)
	case("capture reasons in the module are exactly the capture rule's endings", function()
		local block = between(sources.capture, "local ENDINGS = table.freeze({", "\n})")
		local found = {}
		for name in block:gmatch("\n\t(%a+) = {") do table.insert(found, name) end
		table.sort(found)
		local mine = table.clone(Analytics.EVENTS.capture_end.fields.reason)
		table.sort(mine)
		equal(table.concat(mine, ","), table.concat(found, ","))
	end)
	case("capture tiers and gather zones all map onto the module's zones", function()
		for _, slot in ipairs(Wild.SLOTS) do
			if slot.tier then assert(Analytics.ZONE_OF_TIER[slot.tier], "tier " .. slot.tier) end
		end
		local zones = Analytics.EVENTS.first_gather.fields.zone
		local seen = 0
		for _, slot in ipairs(Config.gather.slots) do
			seen += 1
			assert(table.find(zones, slot.zone), "gather zone " .. tostring(slot.zone))
		end
		assert(seen > 0, "no gather slots found")
		for _, zone in pairs(Analytics.ZONE_OF_TIER) do assert(table.find(zones, zone), zone) end
	end)
	case("craftable recipes are all on the first_craft list", function()
		for name in pairs(Config.recipes) do
			assert(table.find(Analytics.EVENTS.first_craft.fields.recipe, name), "recipe " .. name)
		end
	end)

	return result
end

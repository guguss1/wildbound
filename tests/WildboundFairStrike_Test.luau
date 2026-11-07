-- Invoke with require(freshTestClone)(require(freshFairStrikeClone), require(freshFlagsClone),
-- freshFairStrikeClone.Source, WildboundWorld.Source). FS numbers refer to docs/mechanics/wildbound-fair-strike.md.
return function(FairStrike, Flags, source, worldSource)
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
	local PLACE = 122652861404212

	-- damageMode ---------------------------------------------------------------------------------------
	case("the shipped flag is off and lists no private place", function()
		equal(Flags.damageMode, "off")
		equal(type(Flags.privateTestPlaceIds), "table")
		equal(next(Flags.privateTestPlaceIds), nil)
		equal(FairStrike.effectiveMode(Flags, PLACE), "off")
	end)
	case("FS-04 private with an empty list is off and flagged misconfigured", function()
		local mode, misconfigured = FairStrike.effectiveMode({ damageMode = "private", privateTestPlaceIds = {} }, PLACE)
		equal(mode, "off"); equal(misconfigured, true)
		mode, misconfigured = FairStrike.effectiveMode({ damageMode = "private", privateTestPlaceIds = { 1 } }, PLACE)
		equal(mode, "off"); equal(misconfigured, true)
	end)
	case("private is real only for a listed place", function()
		local mode, misconfigured = FairStrike.effectiveMode({ damageMode = "private", privateTestPlaceIds = { PLACE } }, PLACE)
		equal(mode, "private"); equal(misconfigured, false)
	end)
	case("off and bad input never turn damage on", function()
		for _, flags in ipairs({ nil, 5, {}, { damageMode = "off", privateTestPlaceIds = { PLACE } },
			{ damageMode = "on", privateTestPlaceIds = { PLACE } }, { damageMode = "private" },
			{ damageMode = "private", privateTestPlaceIds = "122652861404212" },
			{ damageMode = "private", privateTestPlaceIds = { tostring(PLACE) } } }) do
			equal(FairStrike.effectiveMode(flags, PLACE), "off")
		end
		equal(FairStrike.effectiveMode({ damageMode = "private", privateTestPlaceIds = { PLACE } }, nil), "off")
		equal(FairStrike.effectiveMode({ damageMode = "private", privateTestPlaceIds = { PLACE } }, 0 / 0), "off")
	end)
	case("FS-05 the world never derives damage from streaming", function()
		assert(type(worldSource) == "string" and #worldSource > 1000, "world source missing")
		assert(not worldSource:find("StreamingEnabled", 1, true), "world reads StreamingEnabled")
		assert(not worldSource:find("local damageEnabled", 1, true), "world still derives damageEnabled")
		assert(worldSource:find("FairStrike.effectiveMode(", 1, true), "world must use effectiveMode")
	end)
	case("FS-03 TakeDamage is reachable only behind the private mode guard", function()
		local count = 0
		for _ in worldSource:gmatch("TakeDamage") do count += 1 end
		equal(count, 1, "TakeDamage occurrences")
		local body = worldSource:match("local function applyRealStrike%(.-\nend\n")
		assert(body, "applyRealStrike missing")
		assert(body:find("TakeDamage", 1, true), "TakeDamage must live in applyRealStrike")
		local first = body:match("^local function applyRealStrike%([^\n]*\n%s*([^\n]+)")
		equal(first, 'if damageMode ~= "private" then return false end', "first line of applyRealStrike")
		local calls = 0
		for _ in worldSource:gmatch("applyRealStrike%(") do calls += 1 end
		equal(calls, 2, "one definition and one call")
	end)
	case("the flag module and rules stay server-only and pure", function()
		assert(type(source) == "string" and #source > 100, "source missing")
		for _, banned in ipairs({ "game:", "workspace", "Instance.new", "os.clock", "tick(", "Random", "math.random",
			"RemoteEvent", "SetAttribute" }) do
			assert(not source:find(banned, 1, true), "fair-strike source uses " .. banned)
		end
		assert(table.isfrozen(Flags), "flags must be frozen")
	end)

	return result
end

-- Invoke with require(freshTestClone)(require(freshCandyCookieBridgeClone), require(freshCandyV3LayoutClone),
--   require(freshCandyLayoutClone), { service = <WildboundCandyCookieBridgeService Source> }).
-- Caramelo v6, proposal 2 (odd/tasks/wildbound-caramelo-v2.md V6-D2; docs/design/wildbound-caramelo-v3-plan.md V6-D20
-- on): the two long outer bridges (Top and Bottom) are cookie bridges. A player carrying an egg (the character child
-- WildboundEggCarried) who is being hunted (a creature's WildboundBeastEngagedAt stamp within HUNT_WINDOW seconds, or La
-- Silueta's WildboundThreatLevel Near or Chase) standing on one's deck cracks it: CRACK_SECONDS of cracks, crumbs and a
-- sound, then it falls into the chocolate for DOWN_SECONDS and rebuilds (once nobody stands in its footprint). The Main
-- bridge never breaks (CL-D7, Caramelo v9: three raised bridges, Top, Main and Bottom). The pure rules run with an injected clock; the deck footprint runs against the real
-- layout bridges; the wiring pins read the service's source. Changes nothing.
return function(Cookie, V3, Layout, sources)
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
	local function has(source, needle, label)
		assert(type(source) == "string" and string.find(source, needle, 1, true), (label or "missing") .. ": " .. needle)
	end
	local function hasNot(source, needle, label)
		assert(type(source) == "string" and not string.find(source, needle, 1, true), (label or "must not appear") .. ": " .. needle)
	end
	local service = type(sources) == "table" and sources.service or ""

	local function bridge(id)
		for _, B in ipairs(V3.BRIDGES) do
			if B.id == id then return B end
		end
		error("no layout bridge " .. id)
	end
	-- A plot point at `along` and `across` in a bridge's frame (the inverse of V3.bridgeFrame).
	local function at(B, along, across)
		return B.x + B.ux * along - B.uz * across, B.z + B.uz * along + B.ux * across
	end
	local FLOOR = Layout.FLOOR_TOP
	local function deckTop(B) return FLOOR + B.deck end
	-- A hunted egg carrier standing in the middle of the Top deck at t = 100.
	local NOW = 100
	local function carrier(changes)
		local B = bridge("Top")
		local x, z = at(B, 0, 0)
		local info = { x = x, z = z, feetY = deckTop(B), alive = true, carriesEgg = true, engagedAt = NOW - 1, threatLevel = nil }
		for k, v in pairs(changes or {}) do info[k] = v end
		return info
	end

	case("CB1: the numbers: 2 s of cracks, 45 s down, only Top and Bottom", function()
		equal(Cookie.CRACK_SECONDS, 2, "CRACK_SECONDS")
		equal(Cookie.DOWN_SECONDS, 45, "DOWN_SECONDS")
		equal(#Cookie.IDS, 2, "two cookie bridges")
		equal(Cookie.isCookie("Top"), true, "Top")
		equal(Cookie.isCookie("Bottom"), true, "Bottom")
		-- CL-D7: the v9 layout has three bridges (Top, Main, Bottom); Main is the one that never breaks
		for _, id in ipairs({ "Main" }) do equal(Cookie.isCookie(id), false, id .. " never breaks") end
		equal(Cookie.isCookie(nil), false, "junk")
		-- every cookie id is a real layout bridge, and Main is still in the layout
		for _, id in ipairs(Cookie.IDS) do assert(bridge(id).length >= 28, id .. " is a long outer bridge") end
		for _, id in ipairs({ "Main" }) do bridge(id) end
		-- CL-D7: RightLast and LeftLast are retired with the v8 water
		equal(#V3.BRIDGES, 3, "three v9 bridges")
		for _, B in ipairs(V3.BRIDGES) do
			assert(B.id ~= "RightLast" and B.id ~= "LeftLast", "a retired bridge is still in the layout: " .. B.id)
		end
		assert(Cookie.HUNT_WINDOW >= 1 and Cookie.HUNT_WINDOW <= 5, "a recent hunt, a few seconds")
		assert(Cookie.STEP > 0 and Cookie.STEP <= 0.2, "about 10 Hz")
	end)

	case("CB2: the state machine: Up -> Cracking (2 s) -> Down (45 s) -> Up", function()
		local st = Cookie.new("Top")
		equal(st.phase, "Up", "starts up")
		equal(Cookie.step(st, 10, false, false), nil, "nothing without a trigger")
		equal(st.phase, "Up")
		equal(Cookie.step(st, 10, true, false), "Crack", "a trigger cracks it")
		equal(st.phase, "Cracking")
		equal(Cookie.step(st, 11.99, true, false), nil, "still cracking at 1.99 s, a new trigger changes nothing")
		equal(st.phase, "Cracking")
		equal(Cookie.step(st, 12, false, false), "Fall", "falls at 2 s, even with nobody on it any more")
		equal(st.phase, "Down")
		equal(Cookie.step(st, 30, true, false), nil, "a fallen bridge cannot crack again")
		equal(Cookie.step(st, 56.99, false, false), nil, "still down at 44.99 s")
		equal(st.phase, "Down")
		equal(Cookie.step(st, 57, false, false), "Rebuild", "rebuilt at 45 s")
		equal(st.phase, "Up")
		equal(Cookie.step(st, 57.1, true, false), "Crack", "a rebuilt bridge can crack again")
	end)

	case("CB3: a rebuild waits while someone stands in the footprint, then happens at once", function()
		local st = Cookie.new("Bottom")
		Cookie.step(st, 0, true, false)
		Cookie.step(st, 2, false, false)
		equal(st.phase, "Down")
		equal(Cookie.step(st, 47, false, true), nil, "a wader under the deck blocks it")
		equal(Cookie.step(st, 60, false, true), nil, "still blocked")
		equal(Cookie.step(st, 60.1, false, false), "Rebuild", "free: rebuilt")
		equal(st.phase, "Up")
	end)

	case("CB4: a junction bridge never leaves Up; junk time changes nothing", function()
		-- CL-D7: Main is the only junction bridge left
		for _, id in ipairs({ "Main" }) do
			local st = Cookie.new(id)
			equal(Cookie.step(st, 5, true, false), nil, id)
			equal(st.phase, "Up", id)
		end
		local st = Cookie.new("Top")
		equal(Cookie.step(st, 0 / 0, true, false), nil, "NaN")
		equal(Cookie.step(st, "x", true, false), nil, "a string")
		equal(st.phase, "Up")
	end)

	case("CB5: hunted: a creature's stamp within the window, or La Silueta Near or Chase", function()
		equal(Cookie.hunted({ engagedAt = NOW - 1 }, NOW), true, "stamped 1 s ago")
		equal(Cookie.hunted({ engagedAt = NOW - Cookie.HUNT_WINDOW }, NOW), true, "at the window's edge")
		equal(Cookie.hunted({ engagedAt = NOW - Cookie.HUNT_WINDOW - 0.01 }, NOW), false, "an old stamp")
		equal(Cookie.hunted({ engagedAt = nil }, NOW), false, "never stamped")
		equal(Cookie.hunted({ engagedAt = "x" }, NOW), false, "junk")
		equal(Cookie.hunted({ threatLevel = "Chase" }, NOW), true, "La Silueta chasing")
		equal(Cookie.hunted({ threatLevel = "Near" }, NOW), true, "La Silueta near")
		equal(Cookie.hunted({ threatLevel = "Distant" }, NOW), false, "La Silueta far")
		equal(Cookie.hunted({ threatLevel = "Safe" }, NOW), false, "safe")
		equal(Cookie.hunted(nil, NOW), false, "no info")
	end)

	case("CB6: the trigger: egg + hunted on a Top or Bottom deck; never without an egg or a hunt", function()
		equal(Cookie.triggers(V3, FLOOR, carrier(), NOW), "Top", "egg + hunted on the Top deck breaks it")
		local B = bridge("Bottom")
		local bx, bz = at(B, 5, 3)
		equal(Cookie.triggers(V3, FLOOR, carrier({ x = bx, z = bz, feetY = deckTop(B) }), NOW), "Bottom", "and the Bottom deck")
		equal(Cookie.triggers(V3, FLOOR, carrier({ carriesEgg = false }), NOW), nil, "no egg")
		equal(Cookie.triggers(V3, FLOOR, carrier({ engagedAt = NOW - 30 }), NOW), nil, "not hunted (an old stamp)")
		-- (false, not nil: a nil in the changes table never overwrites the carrier's stamp)
		equal(Cookie.triggers(V3, FLOOR, carrier({ engagedAt = false }), NOW), nil, "not hunted (no stamp)")
		equal(Cookie.triggers(V3, FLOOR, carrier({ engagedAt = false, threatLevel = "Chase" }), NOW), "Top", "La Silueta's chase counts")
		equal(Cookie.triggers(V3, FLOOR, carrier({ alive = false }), NOW), nil, "dead")
		equal(Cookie.triggers(V3, FLOOR, carrier({ feetY = FLOOR }), NOW), nil, "wading under the deck is not crossing it")
		equal(Cookie.triggers(V3, FLOOR, carrier({ feetY = 0 / 0 }), NOW), nil, "junk height")
		equal(Cookie.triggers(V3, FLOOR, nil, NOW), nil, "no info")
	end)

	case("CB7: a junction bridge never triggers, whatever the player carries", function()
		-- CL-D7: Main is the only junction bridge left
		for _, id in ipairs({ "Main" }) do
			local B = bridge(id)
			local x, z = at(B, 0, 0)
			equal(Cookie.triggers(V3, FLOOR, carrier({ x = x, z = z, feetY = deckTop(B), threatLevel = "Chase" }), NOW), nil, id)
		end
	end)

	case("CB8: the deck footprint on the real layout: the deck only, not its end ramps or the banks", function()
		for _, id in ipairs(Cookie.IDS) do
			local B = bridge(id)
			local half, side = B.length / 2, B.width / 2
			for _, p in ipairs({ { 0, 0 }, { half - 0.1, 0 }, { -half + 0.1, side - 0.1 }, { 0, -side + 0.1 } }) do
				local x, z = at(B, p[1], p[2])
				local found = Cookie.deckBridge(V3, x, z)
				equal(found and found.id, id, id .. " deck at " .. p[1] .. ", " .. p[2])
			end
			for _, p in ipairs({ { half + 0.5, 0 }, { half + B.ramp / 2, 0 }, { 0, side + 0.5 }, { 0, side + B.sideRamp / 2 } }) do
				local x, z = at(B, p[1], p[2])
				equal(Cookie.deckBridge(V3, x, z), nil, id .. " off the deck at " .. p[1] .. ", " .. p[2])
			end
		end
		-- CL-D7: Main is the only junction bridge left
		for _, id in ipairs({ "Main" }) do
			local x, z = at(bridge(id), 0, 0)
			equal(Cookie.deckBridge(V3, x, z), nil, id .. " is no cookie deck")
		end
		-- the Top deck's centre lies over the river (the layout's chocolate), so a fall lands in it
		local B = bridge("Top")
		assert(V3.liquidDistance(B.x, B.z) < 0, "the Top deck stands over the chocolate")
		assert(V3.liquidDistance(bridge("Bottom").x, bridge("Bottom").z) < 0, "and the Bottom deck")
	end)

	case("CB9: the rebuild block: anyone in a deck footprint (with a body's margin), at any height", function()
		local B = bridge("Top")
		local x, z = at(B, 0, B.width / 2 + Cookie.BLOCK_MARGIN - 0.1)
		equal(Cookie.blocks(V3, "Top", x, z), true, "beside the deck's edge, inside the margin")
		x, z = at(B, 0, B.width / 2 + Cookie.BLOCK_MARGIN + 0.5)
		equal(Cookie.blocks(V3, "Top", x, z), false, "clear of it")
		x, z = at(B, 0, 0)
		equal(Cookie.blocks(V3, "Bottom", x, z), false, "the Top's middle does not block the Bottom")
		equal(Cookie.blocks(V3, "Main", x, z), false, "not a cookie bridge")
	end)

	case("CB10: the fall sinks the parts under the floor (into the chocolate) and the fx never collide", function()
		-- CL-D7: the raised decks stand 12.5 over the floor, so SINK 7 -> 14
		equal(Cookie.SINK, 14, "SINK")
		for _, id in ipairs(Cookie.IDS) do
			assert(Cookie.SINK > bridge(id).deck + 0.4, id .. ": the deck ends under the floor, out of sight")
		end
		assert(Cookie.FALL_SECONDS > 0 and Cookie.FALL_SECONDS < Cookie.DOWN_SECONDS, "a short fall")
		equal(Cookie.MODEL_PREFIX, "Bridge_", "the builder's model names (WildboundCandyV3Builder.layBridge)")
	end)

	case("CB11: the service: only Top and Bottom, from the live models, robust when one is missing", function()
		has(service, "for _, id in ipairs(Cookie.IDS) do", "only the cookie ids")
		has(service, "Cookie.MODEL_PREFIX .. id", "the builder's Bridge_<id> models")
		has(service, ":FindFirstChild(V3.FOLDER)", "Candy_Bioma_v1.CaramelV3")
		has(service, ':FindFirstChild("Bridges")', "CaramelV3.Bridges")
		has(service, "if not model then", "a missing bridge model is skipped")
		has(service, "biome:GetAttribute(V3.MARK)", "only on the migrated map")
		-- CL-D7: Main is the only junction bridge left
		for _, id in ipairs({ '"Main"' }) do hasNot(service, id, "never names a junction bridge") end
	end)

	case("CB12: the service: steps the pure rules with the server clock and the hunt stamps", function()
		has(service, "Cookie.step(", "the state machine")
		has(service, "Cookie.triggers(V3, Layout.FLOOR_TOP", "the trigger rule")
		has(service, "Cookie.blocks(V3, ", "the rebuild block")
		has(service, "workspace:GetServerTimeNow()", "the creatures' stamp clock")
		has(service, "task.wait(Cookie.STEP)", "about 10 Hz")
		has(service, 'GetAttribute("WildboundBeastEngagedAt")', "the creatures' and bees' hunt stamp")
		has(service, 'GetAttribute("WildboundThreatLevel")', "La Silueta's threat")
		has(service, 'FindFirstChild("WildboundEggCarried")', "the egg on the back")
		has(service, "Wade.probe(", "the feet height, the wading rule's way")
	end)

	case("CB13: the service: the fall turns collisions and queries off, the rebuild restores the original exactly", function()
		has(service, "cframe = part.CFrame", "the original CFrame kept")
		has(service, "part.CanCollide = false", "a fallen part never holds anyone")
		has(service, "part.CanQuery = false", "no creature ray lands on a fallen part")
		has(service, "part.CFrame = rec.cframe", "restored exactly")
		has(service, "part.Transparency = rec.transparency", "visible again")
		has(service, "part.CanCollide = rec.canCollide", "solid again")
		has(service, "part.CanQuery = rec.canQuery", "ground again for the creatures")
		has(service, "tween:Cancel()", "a rebuild stops a running fall")
	end)

	case("CB14: the service: server only, no damage, no speed, no client requests", function()
		hasNot(service, "OnServerEvent", "no client says a bridge breaks")
		hasNot(service, "TakeDamage", "a fall does no damage")
		hasNot(service, "Health =", "a fall does no damage")
		hasNot(service, "WalkSpeed", "the wading rule slows the player, not this service")
		hasNot(service, "SistemaSonriente", "never touches the teammate's folders")
	end)

	case("CB15: the service: the warning sign reads WildboundText.CANDY_BRIDGE with a Spanish fallback", function()
		has(service, "CANDY_BRIDGE", "the text table")
		has(service, '"¡El puente de galleta se rompe!"', "the fallback while the key is missing")
		has(service, "BillboardGui", "a sign over the deck, seen by everyone near (no client script)")
	end)

	return result
end

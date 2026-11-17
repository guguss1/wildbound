-- Invoke with require(freshTestClone)(require(freshCandyWadeClone), require(freshCandyV3LayoutClone),
--   require(freshCandyLayoutClone),
--   { service = <WildboundCandyWadeService Source>, server = <WildboundServer Source> }).
-- Caramelo v4 wading (odd/tasks/wildbound-caramelo-v2.md V4-D2): a player whose feet are in the chocolate (inside it
-- on the plot, under its surface, not on a bridge, dock or platform, not seated) walks at FACTOR (60 %) of their speed;
-- a jump keeps the state it took off with; the creatures are never slowed. The pure rule runs against a small fake
-- river; the wiring pins check that WildboundServer.applyCarry (the one WalkSpeed writer) multiplies its own fresh
-- speed by the server-only attribute, re-applies it when the attribute changes, and that the service only sets or
-- clears that attribute (no WalkSpeed of its own, no stacking, cleared on a new character). Changes nothing.
return function(Wade, V3, Layout, sources)
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
	local function has(source, needle, label)
		assert(type(source) == "string" and string.find(source, needle, 1, true), (label or "missing") .. ": " .. needle)
	end
	local function hasNot(source, needle, label)
		assert(type(source) == "string" and not string.find(source, needle, 1, true), (label or "must not appear") .. ": " .. needle)
	end
	local service = type(sources) == "table" and sources.service or ""
	local server = type(sources) == "table" and sources.server or ""

	-- A fake plot: the chocolate is the disc of radius 20 round the plot's local origin, 3.5 deep over a floor at 0.5.
	local fakeV3 = {
		LIQUID = { depth = 3.5 },
		liquidDistance = function(x, z) return math.sqrt(x * x + z * z) - 20 end,
		surfaceY = function(floorTop) return floorTop + 3.5 end,
	}
	local CENTRE = { x = 612, z = -3 }
	local SURFACE = 4

	case("WD1: 60 % in the chocolate, a server-only attribute", function()
		near(Wade.FACTOR, 0.6, "FACTOR")
		equal(type(Wade.ATTRIBUTE), "string", "ATTRIBUTE")
		equal(Wade.ATTRIBUTE, "WildboundCandyWade", "the attribute applyCarry reads")
		near(Wade.speed(20, Wade.FACTOR), 12, "20 -> 12")
		near(Wade.speed(20, nil), 20, "no attribute, no change")
		near(Wade.speed(20, 0 / 0), 20, "junk, no change")
		near(Wade.speed(20, 5), 20, "never faster")
		near(Wade.speed(20, 0.01), 20 * Wade.MIN_FACTOR, "never below MIN_FACTOR")
	end)

	case("WD2: feet in the chocolate wade; on a deck, seated, dead or outside do not", function()
		local base = { liquid = -5, feetY = 0.5, surface = SURFACE, airborne = false, seated = false, alive = true }
		local function with(changes)
			local info = table.clone(base)
			for k, v in pairs(changes) do info[k] = v end
			return info
		end
		equal(Wade.wading(false, base), true, "standing on the floor in the chocolate")
		equal(Wade.wading(false, with({ feetY = SURFACE + 0.4 })), false, "on a dock deck over the surface")
		equal(Wade.wading(false, with({ feetY = SURFACE + 2.2 })), false, "on a bridge deck")
		equal(Wade.wading(false, with({ feetY = SURFACE - Wade.FEET_UNDER + 0.01 })), false, "barely under is not wading")
		equal(Wade.wading(true, with({ liquid = 0.5 })), false, "out on the bank")
		equal(Wade.wading(true, with({ seated = true })), false, "on the raft")
		equal(Wade.wading(true, with({ alive = false })), false, "dead")
		equal(Wade.wading(true, with({ feetY = 0 / 0 })), false, "junk")
		equal(Wade.wading(true, with({ liquid = "x" })), false, "junk")
		-- a jump keeps the state it took off with, over the chocolate; landing decides again
		equal(Wade.wading(true, with({ airborne = true, feetY = SURFACE + 3 })), true, "jumping in the chocolate")
		equal(Wade.wading(false, with({ airborne = true, feetY = 1 })), false, "falling off a deck")
		equal(Wade.wading(true, with({ airborne = true, liquid = 2 })), false, "jumped out onto the bank")
	end)

	case("WD3: the probe works in plot coordinates and finds the feet of R15 and R6 rigs", function()
		local info = Wade.probe(fakeV3, CENTRE, 0.5, Vector3.new(612 + 5, 3.5, -3 + 5), 1, 2, false)
		assert(info.liquid < 0, "inside the fake chocolate at the plot centre")
		near(info.feetY, 0.5, "R15: root - half its height - hip height")
		near(info.surface, SURFACE, "the surface")
		local far = Wade.probe(fakeV3, CENTRE, 0.5, Vector3.new(612 + 40, 3.5, -3), 1, 2, false)
		assert(far.liquid > 0, "outside")
		local r6 = Wade.probe(fakeV3, CENTRE, 0.5, Vector3.new(612, 3.5, -3), 1, 0, true)
		near(r6.feetY, 0.5, "R6: the legs are 2 studs under the root's bottom")
	end)

	case("WD4: the real layout: the floor is under the surface, a dock deck over it", function()
		local surface = V3.surfaceY(Layout.FLOOR_TOP)
		near(surface - Layout.FLOOR_TOP, V3.LIQUID.depth, "surface = floor + depth")
		equal(Wade.wading(false, { liquid = -1, feetY = Layout.FLOOR_TOP, surface = surface, alive = true }), true,
			"walking the chocolate's floor is wading")
		equal(Wade.wading(false, { liquid = -1, feetY = surface + V3.DOCK.deckOver, surface = surface, alive = true }), false,
			"a dock deck is dry")
	end)

	case("WD5: applyCarry multiplies its own fresh speed (no stacking) and re-applies on a change", function()
		has(server, 'local wade = tonumber(player:GetAttribute("WildboundCandyWade"))', "applyCarry reads the factor")
		has(server, "if wade and wade < 1 then speed *= math.max(wade, 0.3) end", "slows the computed speed, never WalkSpeed")
		has(server, 'GetAttributeChangedSignal("WildboundCandyWade")', "re-applied when it starts and ends")
		hasNot(server, "humanoid.WalkSpeed * wade", "never scales the current WalkSpeed")
	end)

	case("WD6: the service: players only, sets or clears the attribute, never WalkSpeed, cleared on respawn", function()
		has(service, "Players:GetPlayers()", "players only: the creatures are never slowed")
		has(service, "Wade.wading(", "the pure rule decides")
		has(service, "Wade.probe(V3, Layout.CENTRE, Layout.FLOOR_TOP", "plot coordinates from the layout")
		has(service, "player:SetAttribute(Wade.ATTRIBUTE, ", "the server-only attribute")
		has(service, "CharacterAdded", "a new character starts dry")
		has(service, "PlayerRemoving", "no leak")
		has(service, "biome:GetAttribute(V3.MARK)", "only on the migrated map")
		hasNot(service, "WalkSpeed =", "applyCarry is the one WalkSpeed writer")
		hasNot(service, "SistemaSonriente", "never touches the teammate's folders")
		hasNot(service, "OnServerEvent", "no client says it is wading")
	end)

	return result
end

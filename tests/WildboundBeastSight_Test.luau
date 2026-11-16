-- Invoke with require(freshTestClone)(require(freshBeastSightClone), freshBeastSightClone.Source,
-- require(freshBiomesClone)).
-- Wave 2 (odd/tasks/wildbound-beasts-wave2.md, BW2-3 and BW2-6): the observation validator (rate, shape, unit vector,
-- freshness, the body fallback, the cone, the line of sight) and the biome tags the director reads. Pure.
return function(Sight, source, Biomes)
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
	local FORWARD = { x = 0, y = 0, z = -1 }

	case("BW2 sight: a finite unit vector is accepted at most every 0.1 s; the rest is dropped and counted", function()
		local s = Sight.new()
		equal(Sight.accept(s, 10, FORWARD), true)
		equal(select(2, Sight.accept(s, 10.05, FORWARD)), "Rate")
		equal(Sight.accept(s, 10.15, FORWARD), true)
		equal(s.dropped, 1); equal(s.accepted, 2)
		assert(Sight.SEND_INTERVAL >= Sight.MIN_INTERVAL, "the client sends slower than the server accepts")
	end)

	case("BW2 sight: bad payloads never become an observation", function()
		local s = Sight.new()
		for i, payload in ipairs({ false, "look", 5, { x = 0, y = 0 }, { x = 0 / 0, y = 0, z = -1 }, { x = math.huge, y = 0, z = 0 },
			{ x = 0, y = 0, z = -3 }, { x = 0, y = 0, z = 0 } }) do
			local ok = Sight.accept(s, i, payload)
			equal(ok, false, "payload " .. i)
		end
		equal(s.look, nil, "nothing stored")
		equal(Sight.accept(nil, 1, FORWARD), false)
		equal(select(2, Sight.accept(Sight.new(), 0 / 0, FORWARD)), "BadClock")
		-- A nearly unit vector is normalised.
		local t = Sight.new()
		equal(Sight.accept(t, 1, { x = 0, y = 0, z = -1.03 }), true)
		assert(math.abs(t.look.z + 1) < 1e-9, "normalised")
	end)

	case("BW2 sight: camera while fresh, a short gap is stale, then the body's facing", function()
		local s = Sight.new()
		local body = { x = 1, y = 0, z = 0 }
		equal(select(1, Sight.view(s, 5, body)), "body", "never sent: the body")
		Sight.accept(s, 10, FORWARD)
		local source1, dir = Sight.view(s, 10 + Sight.FRESH, body)
		equal(source1, "camera"); equal(dir.z, -1)
		equal(select(1, Sight.view(s, 10 + Sight.FRESH + 0.01, body)), "stale")
		equal(select(1, Sight.view(s, 10 + Sight.FALLBACK + 0.01, body)), "body")
	end)

	case("BW2 sight: the cone measures from the given origin, within the angle and the distance", function()
		local origin = { x = 0, y = 0, z = 0 }
		equal(Sight.inCone(origin, FORWARD, { x = 0, y = 0, z = -50 }, 17, 75), true)
		local off = math.tan(math.rad(16)) * 50
		equal(Sight.inCone(origin, FORWARD, { x = off, y = 0, z = -50 }, 17, 75), true, "16 degrees")
		off = math.tan(math.rad(18)) * 50
		equal(Sight.inCone(origin, FORWARD, { x = off, y = 0, z = -50 }, 17, 75), false, "18 degrees")
		equal(Sight.inCone(origin, FORWARD, { x = 0, y = 0, z = -80 }, 17, 75), false, "too far")
		equal(Sight.inCone(origin, FORWARD, { x = 0, y = 0, z = 50 }, 17, 75), false, "behind")
	end)

	case("BW2 sight: observes needs the server's line of sight; a stale gap gives the favoured answer", function()
		local s = Sight.new()
		Sight.accept(s, 10, FORWARD)
		local q = { origin = { x = 0, y = 0, z = 0 }, bodyLook = { x = 1, y = 0, z = 0 }, point = { x = 0, y = 0, z = -30 },
			halfAngle = 17, maxDist = 75, los = true, favour = false }
		equal(Sight.observes(s, 10.1, q), true, "looking at it")
		q.los = false
		equal(Sight.observes(s, 10.1, q), false, "a wall in between is never an observation")
		q.los = true
		equal(Sight.observes(s, 11, q), false, "stale, Gaze's favour: not looking")
		q.favour = true
		equal(Sight.observes(s, 11, q), true, "stale, Lurker's favour: observed")
		q.favour = false
		-- Long silence: the body looks along +x, so the point ahead in -z is not observed; one in +x is.
		equal(Sight.observes(s, 13, q), false)
		q.point = { x = 30, y = 0, z = 0 }
		equal(Sight.observes(s, 13, q), true, "not sending is never an advantage")
	end)

	case("BW2 biomes: the Pantano, Pradera and Cementerio squares, the forest swamp island, nothing for a bad point", function()
		-- The classic map (odd/tasks/wildbound-big4-map.md: the place may be left in the big4 mode, so these pin it).
		local C = "classic"
		equal(Biomes.has(282, -443, "Swamp", C), true, "Pantano centre")
		equal(Biomes.has(82, -243, "Swamp", C), true, "Pantano corner")
		equal(Biomes.has(81.9, -443, "Swamp", C), false)
		equal(Biomes.has(612, -3, "Meadow", C), true, "Pradera centre")
		equal(Biomes.has(282, 387, "Cemetery", C), true, "Cementerio centre")
		equal(Biomes.has(282, -3, "Swamp", C), false, "the hub is no biome")
		equal(next(Biomes.at(282, -3, C)), nil)
		local island = Biomes.at(115, 15, C)
		equal(island.Swamp, true, "Pantano de los Juncos (I3)"); equal(island.Forest, true)
		equal(Biomes.has(115, 32, "Swamp", C), false, "outside the island floor")
		equal(next(Biomes.at(0 / 0, 0, C)), nil); equal(next(Biomes.at(nil, 1, C)), nil)
		local a, b = Biomes.at(282, -443, C), Biomes.at(282, -443, C)
		assert(a ~= b, "a fresh table each call")
	end)

	case("BIG4 biomes: four larger squares, the I3 island kept, the archived biomes gone", function()
		local B = "big4"
		assert(type(Biomes.AREAS_BIG4) == "table" and table.isfrozen(Biomes.AREAS_BIG4), "frozen AREAS_BIG4")
		equal(Biomes.has(-500, -400, "Forest", B), true, "outer forest (old Abismo slot)")
		equal(Biomes.has(950, 0, "Meadow", B), true, "Caramelo east annex")
		equal(Biomes.has(622, 387, "Meadow", B), true, "Caramelo south annex (old Cuevas slot)")
		equal(Biomes.has(282, -443, "Mountains", B), true, "Montañas grew into the old Pantano slot")
		equal(Biomes.has(282, -443, "Swamp", B), false, "no Pantano square")
		equal(Biomes.has(-600, 900, "Volcanic", B), true, "Volcán grew west and south")
		equal(next(Biomes.at(282, 387, B)), nil, "old Cementerio slot is no biome")
		equal(next(Biomes.at(282, -3, B)), nil, "the hub is no biome")
		local island = Biomes.at(115, 15, B)
		equal(island.Swamp, true, "I3 kept"); equal(island.Forest, true)
		for _, tag in ipairs({ "Cemetery", "Abyss", "Caves" }) do
			for _, area in ipairs(Biomes.AREAS_BIG4) do assert(area.tag ~= tag, tag .. " is archived") end
		end
		equal(Biomes.areasFor(B), Biomes.AREAS_BIG4); equal(Biomes.areasFor("classic"), Biomes.AREAS)
		equal(Biomes.areasFor("nonsense"), Biomes.AREAS, "an unknown mode is classic")
		equal(next(Biomes.at(0 / 0, 0, B)), nil)
		-- The big4 squares never overlap each other and keep the hub disc (282, -3) r 90 clear.
		local squares = {}
		for _, area in ipairs(Biomes.AREAS_BIG4) do if area.kind == "square" then table.insert(squares, area) end end
		equal(#squares, 4)
		for i, p in ipairs(squares) do
			assert(p.minX > 282 + 90 or p.maxX < 282 - 90 or p.minZ > -3 + 90 or p.maxZ < -3 - 90, p.tag .. " clear of the hub")
			for j = i + 1, #squares do
				local q = squares[j]
				assert(p.maxX < q.minX or q.maxX < p.minX or p.maxZ < q.minZ or q.maxZ < p.minZ, p.tag .. " vs " .. q.tag)
			end
		end
	end)

	case("BW2 sight: the validator is pure", function()
		for _, banned in ipairs({ "workspace", "game:", "task.", "os.clock", "math.random", "Random.new", "Instance.new" }) do
			assert(not source:find(banned, 1, true), "source uses " .. banned)
		end
	end)

	return result
end

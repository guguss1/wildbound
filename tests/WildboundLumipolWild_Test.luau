-- Invoke with require(freshTestClone)(require(freshWildClone), require(freshRulesClone), freshWildClone.Source).
-- Pure rules for wild Lumipol: spawn slots, behavior, first-capture eligibility and egg carry cost.
-- Randomness is injected, so every case is deterministic. CAP numbers refer to docs/mechanics/wildbound-capture.md.
return function(Wild, Rules, source)
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
	local function near(actual, expected, tolerance, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-6),
			(label and label .. ": " or "") .. "Expected about " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function listEqual(actual, expected, label)
		assert(type(actual) == "table" and #actual == #expected, (label or "list") .. ": length "
			.. tostring(type(actual) == "table" and #actual or actual) .. " vs " .. #expected
			.. " (" .. table.concat(actual or {}, ",") .. ")")
		for index, value in ipairs(expected) do
			assert(actual[index] == value, (label or "list") .. "[" .. index .. "]: expected " .. tostring(value)
				.. ", got " .. tostring(actual[index]))
		end
	end

	local C = Wild.CONSTANTS
	local NAN, INF = 0 / 0, math.huge
	-- Park-Miller: small multiplier, so every product stays exact in a double.
	local function seeded(seed)
		local state = seed
		return function()
			state = (state * 48271) % 2147483647
			return state / 2147483647
		end
	end
	local function always(value) return function() return value end end
	local function dist(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
	local function brainAt(id, rand)
		return Wild.newBrain(Wild.slot(id), rand or seeded(7))
	end
	local DT = C.STEP

	-- Slots ---------------------------------------------------------------------------------------

	case("slots are the capture document's table, with unique ids", function()
		local expected = {
			S0a = { "Creature", "Safe", -95, 75 }, S0b = { "Creature", "Safe", -112, 92 },
			L1 = { "Creature", "Territory", -10, -60 }, L2 = { "Creature", "Territory", 30, -105 },
			L3 = { "Creature", "Territory", 65, -60 }, L4 = { "Creature", "Fog", 110, 5 },
			E1 = { "Egg", nil, 35, -99 }, E2 = { "Egg", nil, -38, -85 }, E3 = { "Egg", nil, 60, -125 },
		}
		equal(#Wild.SLOTS, 9)
		local seen = {}
		for _, entry in ipairs(Wild.SLOTS) do
			assert(not seen[entry.id], "duplicate id " .. entry.id)
			seen[entry.id] = true
			local row = expected[entry.id]
			assert(row, "unexpected slot " .. entry.id)
			equal(entry.kind, row[1], entry.id)
			equal(entry.tier, row[2], entry.id)
			equal(entry.x, row[3], entry.id)
			equal(entry.z, row[4], entry.id)
			equal(Wild.slot(entry.id), entry)
		end
		equal(Wild.slot("Z9"), nil)
		equal(Wild.slot(nil), nil)
	end)

	case("slots and constants are frozen", function()
		assert(table.isfrozen(Wild.SLOTS) and table.isfrozen(Wild.CONSTANTS), "tables must be frozen")
		for _, entry in ipairs(Wild.SLOTS) do
			assert(table.isfrozen(entry), entry.id .. " must be frozen")
			assert(not pcall(function() entry.x = 0 end), entry.id .. " must reject writes")
		end
		assert(not pcall(function() Wild.CONSTANTS.CURIOUS_RANGE = 99 end), "constants must reject writes")
	end)

	case("zones: safe slots outside fog, territory slots inside the leash, the fog slot outside it", function()
		for _, entry in ipairs(Wild.SLOTS) do
			local fog, safe = Rules.zone(entry.x, entry.z)
			equal(safe, false, entry.id .. " must not be in a safe zone")
			if entry.tier == "Safe" then
				equal(fog, false, entry.id .. " fog")
				equal(Rules.inTerritory(entry.x, entry.z), false, entry.id)
			elseif entry.tier == "Territory" then
				equal(Rules.inTerritory(entry.x, entry.z), true, entry.id)
			elseif entry.tier == "Fog" then
				equal(fog, true, entry.id .. " fog")
				equal(Rules.inTerritory(entry.x, entry.z), false, entry.id .. " must be outside the leash")
			else
				equal(entry.kind, "Egg", entry.id)
				equal(Rules.inTerritory(entry.x, entry.z), true, entry.id .. " egg slots sit in territory")
			end
		end
	end)

	case("one safe slot for one or two players, two from three players", function()
		local function safe(count)
			local total = 0
			for _, id in ipairs(Wild.activeSlotIds(count)) do
				if Wild.slot(id).tier == "Safe" then total += 1 end
			end
			return total
		end
		equal(safe(1), 1)
		equal(safe(2), 1)
		equal(safe(3), 2)
		equal(safe(4), 2)
		equal(safe(5), 2)
		equal(safe(20), 2)
	end)

	case("active slots scale with players as D4 says", function()
		listEqual(Wild.activeSlotIds(1), { "S0a", "L1", "L4", "E1" })
		listEqual(Wild.activeSlotIds(2), { "S0a", "L1", "L2", "L4", "E1", "E2" })
		listEqual(Wild.activeSlotIds(3), { "S0a", "S0b", "L1", "L2", "L3", "L4", "E1", "E2", "E3" })
		listEqual(Wild.activeSlotIds(4), Wild.activeSlotIds(3))
		listEqual(Wild.activeSlotIds(5), Wild.activeSlotIds(3))
		listEqual(Wild.activeSlotIds(100), Wild.activeSlotIds(3))
	end)

	case("every player count keeps a territory slot and the sets only grow", function()
		local previous = {}
		for count = 1, 8 do
			local ids = Wild.activeSlotIds(count)
			local territory, long = 0, 0
			local set = {}
			for _, id in ipairs(ids) do
				set[id] = true
				local entry = Wild.slot(id)
				if entry.tier == "Territory" then territory += 1 end
				if entry.id:sub(1, 1) == "L" then long += 1 end
			end
			assert(territory >= 1, "no territory slot at " .. count)
			assert(long >= 2 and long <= 4, "L slots out of range at " .. count)
			for id in pairs(previous) do assert(set[id], id .. " vanished at " .. count) end
			previous = set
		end
	end)

	case("bad player counts count as one player", function()
		local one = Wild.activeSlotIds(1)
		for _, bad in ipairs({ NAN, INF, -INF, -3, 0, 0.5, "3", {}, true }) do
			listEqual(Wild.activeSlotIds(bad), one, tostring(bad))
		end
		listEqual(Wild.activeSlotIds(nil), one)
		listEqual(Wild.activeSlotIds(2.9), Wild.activeSlotIds(2))
	end)

	case("respawn seconds: safe 8, long 45 or 30, eggs 60 or 40", function()
		equal(Wild.respawnSeconds(Wild.slot("S0a"), 1), 8)
		equal(Wild.respawnSeconds(Wild.slot("S0b"), 9), 8)
		equal(Wild.respawnSeconds(Wild.slot("L1"), 1), 45)
		equal(Wild.respawnSeconds(Wild.slot("L4"), 4), 45)
		equal(Wild.respawnSeconds(Wild.slot("L2"), 5), 30)
		equal(Wild.respawnSeconds(Wild.slot("E1"), 1), 60)
		equal(Wild.respawnSeconds(Wild.slot("E3"), 4), 60)
		equal(Wild.respawnSeconds(Wild.slot("E2"), 5), 40)
		equal(Wild.respawnSeconds(Wild.slot("L1"), NAN), 45)
		equal(Wild.respawnSeconds(nil, 1), nil)
		equal(Wild.respawnSeconds("L1", 1), nil)
	end)

	-- First capture and carrying ----------------------------------------------------------------

	case("CAP-21: safe slot allows a new player and refuses one who carries or owns a creature", function()
		local fresh = { registered = {}, pending = {} }
		local carrying = { registered = {}, pending = { { uid = "a", kind = "Creature" } } }
		local registered = { registered = { { uid = "b", species = "Lumipol" } }, pending = {} }
		local both = { registered = { { uid = "b" } }, pending = { { uid = "a", kind = "Creature" } } }
		local eggOnly = { registered = {}, pending = { { uid = "c", kind = "Egg" } } }
		equal(Wild.slotRefusal("Safe", fresh), nil)
		equal(Wild.slotRefusal("Safe", carrying), "FirstCapturePending")
		equal(Wild.slotRefusal("Safe", registered), "FirstCaptureOnly")
		equal(Wild.slotRefusal("Safe", both), "FirstCaptureOnly")
		equal(Wild.slotRefusal("Safe", eggOnly), nil)
	end)

	case("a player who lost the first catch can try again", function()
		-- Defeat clears the bag, so the snapshot is fresh again.
		equal(Wild.slotRefusal("Safe", { registered = {}, pending = {} }), nil)
	end)

	case("fog and territory slots never apply the first-capture rule", function()
		local registered = { registered = { { uid = "b" } }, pending = { { uid = "a", kind = "Creature" } } }
		for _, tier in ipairs({ "Territory", "Fog" }) do
			equal(Wild.slotRefusal(tier, registered), nil, tier)
			equal(Wild.slotRefusal(tier, nil), nil, tier)
		end
		equal(Wild.slotRefusal(nil, registered), nil)
	end)

	case("a safe slot fails closed on a bad snapshot", function()
		for _, bad in ipairs({ "x", 1, true }) do
			equal(Wild.slotRefusal("Safe", bad), "InvalidContext")
		end
		equal(Wild.slotRefusal("Safe", nil), "InvalidContext")
		equal(Wild.slotRefusal("Safe", {}), "InvalidContext")
		equal(Wild.slotRefusal("Safe", { registered = {} }), "InvalidContext")
		equal(Wild.slotRefusal("Safe", { pending = {} }), "InvalidContext")
		equal(Wild.slotRefusal("Safe", { registered = "x", pending = {} }), "InvalidContext")
	end)

	case("CAP-20: carry speed by eggs", function()
		equal(Wild.carrySpeed(0), 16)
		equal(Wild.carrySpeed(1), 11)
		equal(Wild.carrySpeed(2), 10)
		equal(Wild.carrySpeed(3), 9)
		equal(Wild.carrySpeed(4), 9)
		equal(Wild.carrySpeed(50), 9)
	end)

	case("CAP-20: carry speed stays above Silueta's fastest speed and never rises with load", function()
		local last = math.huge
		for eggs = 0, 300 do
			local speed = Wild.carrySpeed(eggs)
			assert(speed > C.SILUETA_FASTEST, "speed " .. speed .. " at " .. eggs .. " eggs")
			assert(speed <= last, "speed rose at " .. eggs)
			last = speed
		end
		assert(Wild.carrySpeed(INF) > C.SILUETA_FASTEST)
		equal(C.SILUETA_FASTEST, 8)
	end)

	case("carry speed treats unusable counts as no load", function()
		for _, bad in ipairs({ NAN, -1, -INF, "2", {}, true, 0.5 }) do
			equal(Wild.carrySpeed(bad), 16, tostring(bad))
		end
		equal(Wild.carrySpeed(nil), 16)
		equal(Wild.carrySpeed(1.5), 11)
	end)

	case("eggs carried counts only eggs in the bag and ignores junk", function()
		local snapshot = { pending = { { kind = "Egg" }, { kind = "Creature" }, { kind = "Egg" }, "x", { kind = 5 } } }
		equal(Wild.eggsCarried(snapshot), 2)
		equal(Wild.eggsCarried({ pending = {} }), 0)
		equal(Wild.eggsCarried({}), 0)
		equal(Wild.eggsCarried(nil), 0)
		equal(Wild.eggsCarried("x"), 0)
		equal(Wild.eggsCarried({ pending = { { kind = "Creature" } }, bankedEggs = { { kind = "Egg" } } }), 0)
	end)

	-- Behavior ------------------------------------------------------------------------------------

	case("a new brain wanders from its slot centre, facing a unit vector", function()
		local brain = brainAt("L1")
		equal(brain.mode, "Wander")
		equal(brain.x, -10)
		equal(brain.z, -60)
		near(dist(0, 0, brain.fx, brain.fz), 1, 1e-9)
		equal(brain.moved, false)
	end)

	case("wanderers stay within 6 studs of the slot and never exceed 2 studs per second", function()
		for _, seed in ipairs({ 1, 2, 3, 99 }) do
			local rand = seeded(seed)
			local brain = brainAt("S0a", rand)
			local px, pz = brain.x, brain.z
			for _ = 1, 6000 do
				Wild.step(brain, DT, nil, rand)
				assert(dist(brain.x, brain.z, -95, 75) <= C.WANDER_RADIUS + 1e-6, "left the radius")
				local moved = dist(brain.x, brain.z, px, pz)
				assert(moved <= C.WANDER_SPEED * DT + 1e-9, "stepped " .. moved)
				equal(brain.moved, moved > 0, "moved flag")
				px, pz = brain.x, brain.z
			end
		end
	end)

	case("a wanderer pauses 2 to 5 seconds between walks", function()
		local rand = seeded(11)
		local brain = brainAt("L1", rand)
		local still, pauses, walks = 0, {}, 0
		local wasMoving = false
		for _ = 1, 5000 do
			Wild.step(brain, DT, nil, rand)
			if brain.moved then
				if not wasMoving and walks > 0 then table.insert(pauses, still) end
				if not wasMoving then walks += 1 end
				still = 0
				wasMoving = true
			else
				still += DT
				wasMoving = false
			end
		end
		assert(walks >= 10, "too few walks: " .. walks)
		for _, seconds in ipairs(pauses) do
			assert(seconds >= C.PAUSE_MIN - 2 * DT and seconds <= C.PAUSE_MAX + 2 * DT, "pause of " .. seconds)
		end
	end)

	case("a walking wanderer moves at exactly the wander speed", function()
		local rand = seeded(5)
		local brain = brainAt("L2", rand)
		local full = 0
		for _ = 1, 400 do
			local px, pz = brain.x, brain.z
			Wild.step(brain, DT, nil, rand)
			if brain.moved and math.abs(dist(brain.x, brain.z, px, pz) - C.WANDER_SPEED * DT) < 1e-9 then full += 1 end
		end
		assert(full > 20, "too few full-speed steps: " .. full)
	end)

	case("a player within 12 studs makes it stop and face them; leaving lets it wander again", function()
		local rand = seeded(3)
		local brain = brainAt("L1", rand)
		for _ = 1, 100 do Wild.step(brain, DT, nil, rand) end
		local x, z = brain.x, brain.z
		local watcher = { x = x + 8, z = z }
		Wild.step(brain, DT, watcher, rand)
		equal(brain.mode, "Curious")
		equal(brain.moved, false)
		equal(brain.x, x)
		equal(brain.z, z)
		near(brain.fx, 1, 1e-9)
		near(brain.fz, 0, 1e-9)
		watcher.x, watcher.z = x, z + 8
		Wild.step(brain, DT, watcher, rand)
		near(brain.fx, 0, 1e-9)
		near(brain.fz, 1, 1e-9)
		equal(brain.mode, "Curious")
		Wild.step(brain, DT, { x = x + 40, z = z }, rand)
		equal(brain.mode, "Wander")
		local moved = false
		for _ = 1, 100 do
			Wild.step(brain, DT, { x = x + 40, z = z }, rand)
			moved = moved or brain.moved
		end
		assert(moved, "it never walked again")
	end)

	case("curiosity starts at exactly 12 studs", function()
		local rand = seeded(4)
		local brain = brainAt("L3", rand)
		Wild.step(brain, DT, { x = brain.x + 12, z = brain.z }, rand)
		equal(brain.mode, "Curious")
		local other = brainAt("L3", seeded(4))
		Wild.step(other, DT, { x = other.x + 12.01, z = other.z }, seeded(4))
		equal(other.mode, "Wander")
	end)

	case("a reserved Lumipol is frozen, ignores everyone and faces its owner", function()
		local rand = seeded(9)
		local brain = brainAt("L4", rand)
		for _ = 1, 60 do Wild.step(brain, DT, nil, rand) end
		local x, z = brain.x, brain.z
		Wild.reserve(brain, x, z + 7)
		equal(brain.mode, "Reserved")
		near(brain.fz, 1, 1e-9)
		for _ = 1, 500 do
			Wild.step(brain, DT, { x = x + 30, z = z - 2 }, rand)
			equal(brain.x, x)
			equal(brain.z, z)
			equal(brain.moved, false)
			equal(brain.mode, "Reserved")
		end
		near(brain.fx, 30 / dist(0, 0, 30, -2), 1e-9)
		Wild.step(brain, DT, nil, rand)
		equal(brain.mode, "Reserved")
	end)

	case("a spooked Lumipol backs away 8 to 12 studs at 10 studs per second, within 10 of its slot", function()
		for _, roll in ipairs({ 0, 0.5, 0.999999 }) do
			local brain = brainAt("L1", always(roll))
			Wild.spook(brain, brain.x - 6, brain.z, always(roll))
			equal(brain.mode, "Spooked")
			local sx, sz = brain.x, brain.z
			local steps, longest = 0, 0
			for _ = 1, 60 do
				local px, pz = brain.x, brain.z
				Wild.step(brain, DT, nil, always(roll))
				longest = math.max(longest, dist(brain.x, brain.z, px, pz))
				assert(dist(brain.x, brain.z, -10, -60) <= C.FLEE_LIMIT + 1e-6, "fled past the limit")
				steps += 1
				if brain.mode == "Wander" then break end
			end
			assert(longest <= C.FLEE_SPEED * DT + 1e-9, "fled faster than 10 studs per second")
			assert(brain.x > sx - 1e-9, "it ran toward the threat")
			assert(steps * DT >= C.SPOOK_SECONDS - 1e-9, "wandered before the spook ended")
			equal(brain.mode, "Wander")
		end
	end)

	case("a flee covers the whole 8 to 12 studs when the slot has room", function()
		local brain = brainAt("S0a", always(0))
		brain.x, brain.z = -95 - 2, 75
		Wild.spook(brain, brain.x + 5, brain.z, always(0))
		local travelled = 0
		for _ = 1, 20 do
			local px, pz = brain.x, brain.z
			Wild.step(brain, DT, nil, always(0))
			travelled += dist(brain.x, brain.z, px, pz)
		end
		assert(travelled >= 3, "it barely moved: " .. travelled)
		assert(travelled <= C.FLEE_MAX + 1e-6, "it fled too far: " .. travelled)
		assert(dist(brain.x, brain.z, -95, 75) <= C.FLEE_LIMIT + 1e-6)
	end)

	case("a flee from the slot edge is clamped inside the limit", function()
		local rand = seeded(21)
		local brain = brainAt("L1", rand)
		brain.x, brain.z = -10 + 6, -60
		Wild.spook(brain, brain.x - 3, brain.z, rand)
		for _ = 1, 40 do
			Wild.step(brain, DT, nil, rand)
			assert(dist(brain.x, brain.z, -10, -60) <= C.FLEE_LIMIT + 1e-6, "outside the limit")
		end
	end)

	case("a spook from the same spot still picks a direction", function()
		local brain = brainAt("L2", always(0.25))
		Wild.spook(brain, brain.x, brain.z, always(0.25))
		equal(brain.mode, "Spooked")
		for _ = 1, 20 do Wild.step(brain, DT, nil, always(0.25)) end
		assert(dist(brain.x, brain.z, 30, -105) > 1, "it did not move")
		assert(dist(brain.x, brain.z, 30, -105) <= C.FLEE_LIMIT + 1e-6)
	end)

	case("release returns to wandering with no flee and no jump", function()
		local rand = seeded(8)
		local brain = brainAt("L3", rand)
		Wild.reserve(brain, 0, 0)
		local x, z = brain.x, brain.z
		Wild.release(brain)
		equal(brain.mode, "Wander")
		equal(brain.x, x)
		equal(brain.z, z)
		for _ = 1, 10 do
			Wild.step(brain, DT, nil, rand)
			assert(dist(brain.x, brain.z, x, z) <= C.WANDER_SPEED * DT * 10, "it ran")
		end
	end)

	case("a new capture interrupts a flee at once", function()
		local rand = seeded(13)
		local brain = brainAt("L1", rand)
		Wild.spook(brain, brain.x - 4, brain.z, rand)
		Wild.step(brain, DT, nil, rand)
		local x, z = brain.x, brain.z
		Wild.reserve(brain, x - 5, z)
		for _ = 1, 30 do Wild.step(brain, DT, nil, rand) end
		equal(brain.x, x)
		equal(brain.z, z)
		equal(brain.mode, "Reserved")
	end)

	case("unusable step sizes and player positions change nothing", function()
		local rand = seeded(2)
		local brain = brainAt("L1", rand)
		for _ = 1, 100 do Wild.step(brain, DT, nil, rand) end
		local x, z, mode = brain.x, brain.z, brain.mode
		for _, bad in ipairs({ NAN, INF, -INF, -1, 0 }) do
			Wild.step(brain, bad, nil, rand)
			equal(brain.x, x, tostring(bad))
			equal(brain.z, z, tostring(bad))
			equal(brain.moved, false)
		end
		for _, bad in ipairs({ { x = NAN, z = 0 }, { x = 0 }, "x", 5, { x = INF, z = INF } }) do
			Wild.step(brain, DT, bad, rand)
			equal(brain.mode == "Curious", false, "bad position made it curious")
		end
		equal(brain.mode, mode)
		local before = brain.x
		Wild.step(brain, 1e9, nil, rand)
		assert(math.abs(brain.x - before) <= C.WANDER_SPEED * 0.5 + 1e-9, "a huge step moved too far")
	end)

	case("random operations never leave the slot's 10 studs or produce a bad number", function()
		local rand = seeded(77)
		local brain = brainAt("L1", rand)
		for index = 1, 8000 do
			local roll = rand()
			if roll < 0.01 then Wild.spook(brain, -10 + (rand() - 0.5) * 30, -60 + (rand() - 0.5) * 30, rand)
			elseif roll < 0.02 then Wild.reserve(brain, -10 + (rand() - 0.5) * 20, -60 + (rand() - 0.5) * 20)
			elseif roll < 0.03 then Wild.release(brain) end
			local watcher = rand() < 0.2 and { x = -10 + (rand() - 0.5) * 40, z = -60 + (rand() - 0.5) * 40 } or nil
			Wild.step(brain, DT, watcher, rand)
			assert(brain.x == brain.x and brain.z == brain.z and brain.fx == brain.fx and brain.fz == brain.fz,
				"NaN at step " .. index)
			assert(dist(brain.x, brain.z, -10, -60) <= C.FLEE_LIMIT + 1e-6, "outside 10 studs at step " .. index)
			near(dist(0, 0, brain.fx, brain.fz), 1, 1e-6, "facing at step " .. index)
		end
	end)

	case("the same seed gives the same walk", function()
		local function walk()
			local rand = seeded(31)
			local brain = brainAt("L1", rand)
			local x, z = 0, 0
			for _ = 1, 500 do
				Wild.step(brain, DT, nil, rand)
				x, z = x + brain.x, z + brain.z
			end
			return x, z
		end
		local ax, az = walk()
		local bx, bz = walk()
		equal(ax, bx)
		equal(az, bz)
	end)

	case("edge random values still give a valid walk", function()
		for _, roll in ipairs({ 0, 0.999999999 }) do
			local rand = always(roll)
			local brain = brainAt("S0b", rand)
			for _ = 1, 2000 do
				Wild.step(brain, DT, nil, rand)
				assert(dist(brain.x, brain.z, -112, 92) <= C.WANDER_RADIUS + 1e-6)
			end
		end
	end)

	case("the module reads no service, clock or random source", function()
		assert(type(source) == "string" and #source > 500, "source missing")
		for _, banned in ipairs({ "GetService", "os.clock", "os.time", "tick%(%)", "Random.new", "math.random", "workspace", "game%." }) do
			assert(not source:find(banned), "source uses " .. banned)
		end
	end)

	return result
end

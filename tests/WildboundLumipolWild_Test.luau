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

	-- Behavior (delivery A1) -------------------------------------------------------------------------
	-- Modes: Idle, Wander, Curious, Alert, Flee, Hide, Reserved, Captured. A watcher is { x, z, speed }, where speed
	-- is the player's horizontal speed in studs per second, read by the server.

	local PROFILES = Wild.PROFILES or {}
	local WILD, GENTLE = PROFILES.Wild or {}, PROFILES.Gentle or {}
	local function watcher(x, z, speed) return { x = x, z = z, speed = speed or 0 } end
	-- Steps a brain with a watcher that walks straight at its start position at `speed`, from `from` studs away
	-- along +X, until it is `to` studs away. Returns the list of modes seen, in order, without repeats.
	local function approachRun(brain, speed, from, to, rand)
		local ox, oz = brain.x, brain.z
		local seen, at = {}, from
		while at > to do
			Wild.step(brain, DT, watcher(ox + at, oz, speed), rand)
			if seen[#seen] ~= brain.mode then table.insert(seen, brain.mode) end
			at -= speed * DT
		end
		return seen
	end
	local function has(list, value)
		for _, item in ipairs(list) do if item == value then return true end end
		return false
	end
	local function indexOf(list, value)
		for index, item in ipairs(list) do if item == value then return index end end
		return nil
	end

	case("a new brain idles at its slot centre, facing a unit vector, with no alarm", function()
		local brain = brainAt("L1")
		equal(brain.mode, "Idle")
		equal(brain.x, -10)
		equal(brain.z, -60)
		equal(brain.alarm, 0)
		equal(brain.leash, C.LEASH)
		near(dist(0, 0, brain.fx, brain.fz), 1, 1e-9)
		equal(brain.moved, false)
	end)

	case("profiles: the tutorial Safe slots are gentle, every other tier uses the wild thresholds", function()
		equal(Wild.profileFor("Safe"), GENTLE)
		for _, tier in ipairs({ "Territory", "Fog", "Other" }) do equal(Wild.profileFor(tier), WILD, tier) end
		equal(Wild.profileFor(nil), WILD)
		assert(table.isfrozen(Wild.PROFILES) and table.isfrozen(GENTLE) and table.isfrozen(WILD), "profiles frozen")
		equal(WILD.calmSpeed, 8)
		assert(GENTLE.calmSpeed > WILD.calmSpeed, "gentle tolerates a faster walk")
		assert(GENTLE.alertRadius < WILD.alertRadius, "gentle notices a runner later")
		assert(GENTLE.alarmAlert > WILD.alarmAlert and GENTLE.alarmFlee > WILD.alarmFlee, "gentle needs a longer run")
		equal(brainAt("S0a").profile, GENTLE)
		equal(brainAt("S0b").profile, GENTLE)
		equal(brainAt("L4").profile, WILD)
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
				equal(brain.mode == "Wander" or brain.mode == "Idle", true, "mode " .. brain.mode)
				px, pz = brain.x, brain.z
			end
		end
	end)

	case("a wanderer idles 2 to 5 seconds between walks and is Wander only while it walks", function()
		local rand = seeded(11)
		local brain = brainAt("L1", rand)
		local still, pauses, walks = 0, {}, 0
		local wasMoving = false
		for _ = 1, 5000 do
			Wild.step(brain, DT, nil, rand)
			if brain.moved then
				equal(brain.mode, "Wander")
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

	case("a still player within 12 studs makes it stop and face them; leaving lets it wander again", function()
		local rand = seeded(3)
		local brain = brainAt("L1", rand)
		for _ = 1, 100 do Wild.step(brain, DT, nil, rand) end
		local x, z = brain.x, brain.z
		local w = watcher(x + 8, z)
		Wild.step(brain, DT, w, rand)
		equal(brain.mode, "Curious")
		equal(brain.moved, false)
		equal(brain.x, x)
		equal(brain.z, z)
		near(brain.fx, 1, 1e-9)
		near(brain.fz, 0, 1e-9)
		w.x, w.z = x, z + 8
		Wild.step(brain, DT, w, rand)
		near(brain.fx, 0, 1e-9)
		near(brain.fz, 1, 1e-9)
		equal(brain.mode, "Curious")
		Wild.step(brain, DT, watcher(x + 40, z), rand)
		equal(brain.mode, "Idle")
		local moved = false
		for _ = 1, 100 do
			Wild.step(brain, DT, watcher(x + 40, z), rand)
			moved = moved or brain.moved
		end
		assert(moved, "it never walked again")
	end)

	case("curiosity starts at exactly 12 studs", function()
		local rand = seeded(4)
		local brain = brainAt("L3", rand)
		Wild.step(brain, DT, watcher(brain.x + 12, brain.z), rand)
		equal(brain.mode, "Curious")
		local other = brainAt("L3", seeded(4))
		Wild.step(other, DT, watcher(other.x + 12.01, other.z), seeded(4))
		equal(other.mode, "Idle")
	end)

	case("A1: a slow approach (under 8 studs per second) keeps it Curious all the way in", function()
		for _, speed in ipairs({ 2, 6, WILD.calmSpeed }) do
			local rand = seeded(17)
			local brain = brainAt("L1", rand)
			local seen = approachRun(brain, speed, 20, 1.5, rand)
			assert(not has(seen, "Alert") and not has(seen, "Flee"), speed .. " studs/s alarmed it: " .. table.concat(seen, ","))
			equal(brain.mode, "Curious", "speed " .. speed)
			equal(brain.alarm, 0, "speed " .. speed)
		end
	end)

	case("A1: a fast approach raises Alert first, then Flee, and the Alert faces the runner", function()
		local rand = seeded(19)
		local brain = brainAt("L1", rand)
		local ox, oz = brain.x, brain.z
		local alertFacing
		local seen, at = {}, 20
		while at > 1 and brain.mode ~= "Flee" do
			Wild.step(brain, DT, watcher(ox + at, oz, 16), rand)
			if brain.mode == "Alert" and not alertFacing then alertFacing = { brain.fx, brain.fz, brain.moved } end
			if seen[#seen] ~= brain.mode then table.insert(seen, brain.mode) end
			at -= 16 * DT
		end
		local alert, flee = indexOf(seen, "Alert"), indexOf(seen, "Flee")
		assert(alert and flee and alert < flee, "expected Alert before Flee: " .. table.concat(seen, ","))
		near(alertFacing[1], 1, 1e-9)
		near(alertFacing[2], 0, 1e-9)
		equal(alertFacing[3], false, "an alert Lumipol freezes")
		assert(at + 16 * DT > 1, "it only fled once the runner was on top of it")
	end)

	case("A1: a sprint inside the alert radius alarms it even without coming closer", function()
		local rand = seeded(23)
		local brain = brainAt("L3", rand)
		local ox, oz = brain.x, brain.z
		local angle, radius = 0, WILD.alertRadius - 1
		local seen = {}
		for _ = 1, 30 do
			angle += 16 * DT / radius
			Wild.step(brain, DT, watcher(ox + radius * math.cos(angle), oz + radius * math.sin(angle), 16), rand)
			if seen[#seen] ~= brain.mode then table.insert(seen, brain.mode) end
		end
		assert(has(seen, "Alert") and has(seen, "Flee"), table.concat(seen, ","))
	end)

	case("A1: a runner outside the alert radius changes nothing", function()
		local rand = seeded(29)
		local brain = brainAt("L2", rand)
		for _ = 1, 50 do
			Wild.step(brain, DT, watcher(brain.cx + WILD.alertRadius + C.WANDER_RADIUS + 1, brain.cz, 16), rand)
			equal(brain.alarm, 0)
			assert(brain.mode == "Idle" or brain.mode == "Wander", brain.mode)
		end
	end)

	case("A1: an alerted Lumipol calms again once the runner stops, without fleeing", function()
		local rand = seeded(31)
		local brain = brainAt("L1", rand)
		local ox, oz = brain.x, brain.z
		Wild.step(brain, DT, watcher(ox + 13, oz, 16), rand)
		Wild.step(brain, DT, watcher(ox + 11, oz, 16), rand)
		equal(brain.mode, "Alert")
		local calmAt
		for index = 1, 40 do
			Wild.step(brain, DT, watcher(ox + 10, oz, 0), rand)
			assert(brain.mode ~= "Flee", "fled after the runner stopped")
			if brain.mode == "Curious" then calmAt = index * DT; break end
		end
		assert(calmAt, "never calmed")
		assert(calmAt >= C.ALERT_HOLD - 1e-9, "calmed before the alert hold: " .. calmAt)
	end)

	case("A1: Safe slots use gentle thresholds: a brisk 10 studs/s walk at 9 studs does not alarm S0a", function()
		local gentle = brainAt("S0a", seeded(2))
		local wild = brainAt("L4", seeded(2))
		local wildSeen = {}
		for _ = 1, 20 do
			Wild.step(gentle, DT, watcher(gentle.cx + 9, gentle.cz, 10), seeded(2))
			Wild.step(wild, DT, watcher(wild.cx + 9, wild.cz, 10), seeded(2))
			wildSeen[wild.mode] = true
		end
		equal(gentle.mode, "Curious")
		equal(gentle.alarm, 0)
		assert(wildSeen.Alert and wildSeen.Flee, "the wild slot did not alert and flee")
		local seen = approachRun(brainAt("S0b", seeded(3)), 16, 20, -6, seeded(3))
		assert(has(seen, "Flee"), "even a gentle Lumipol flees a sprint into it: " .. table.concat(seen, ","))
	end)

	-- Cover -----------------------------------------------------------------------------------------

	case("A1: coverPoints keeps finite props within the leash, nearest first, spaced and capped", function()
		local slot = Wild.slot("L2")
		local list = Wild.coverPoints(slot, {
			{ x = 30 + 10, z = -105, r = 2 }, { x = 30 + 10.5, z = -105, r = 2 }, -- too close to the first
			{ x = 30, z = -105 + 5, r = 6 }, { x = 30 + C.LEASH + 1, z = -105, r = 1 }, -- outside the leash
			{ x = NAN, z = 0 }, { x = 1 }, "trunk", { x = 30 - 20, z = -105, r = -1 },
		})
		equal(#list, 3)
		equal(list[1].z, -100)
		equal(list[2].x, 40)
		equal(list[3].x, 10)
		equal(list[1].r, C.COVER_RADIUS_MAX, "a wide prop counts at most COVER_RADIUS_MAX")
		equal(list[3].r, 0, "a negative radius counts as 0")
		local many = {}
		for index = 1, 40 do many[index] = { x = 30 + math.cos(index) * 15, z = -105 + math.sin(index) * 15, r = 1 } end
		assert(#Wild.coverPoints(slot, many) <= C.MAX_COVER, "capped")
		equal(#Wild.coverPoints(slot, nil), 0)
		equal(#Wild.coverPoints(nil, many), 0)
		equal(#Wild.coverPoints(slot, many, 3), 0, "a custom leash filters too")
	end)

	case("A1: a flee runs to the nearest cover away from the threat and hides behind it", function()
		local slot = Wild.slot("L1")
		local cover = { { x = -10 + 12, z = -60, r = 2 }, { x = -10 - 14, z = -60, r = 2 }, { x = -10, z = -60 + 20, r = 2 } }
		local brain = Wild.newBrain(slot, seeded(5), { cover = cover })
		Wild.spook(brain, -10 + 5, -60, seeded(5)) -- the threat is east; the east trunk is toward it
		equal(brain.mode, "Flee")
		-- Behind the west trunk, as seen from the threat: further west than the trunk itself.
		near(brain.hideX, -10 - 14 - (2 + C.COVER_OFFSET), 1e-9)
		near(brain.hideZ, -60, 1e-9)
		local steps, longest = 0, 0
		while brain.mode == "Flee" and steps < 100 do
			local px, pz = brain.x, brain.z
			Wild.step(brain, DT, nil, seeded(5))
			longest = math.max(longest, dist(brain.x, brain.z, px, pz))
			steps += 1
		end
		equal(brain.mode, "Hide")
		assert(longest <= C.FLEE_SPEED * DT + 1e-9, "fled faster than the flee speed")
		near(brain.x, brain.hideX, 1e-6)
		near(brain.z, brain.hideZ, 1e-6)
	end)

	case("A1: hiding lasts, then it peeks at the threat, then calms back to Idle", function()
		local brain = Wild.newBrain(Wild.slot("L1"), seeded(6), { cover = { { x = -10 - 8, z = -60, r = 1 } } })
		Wild.spook(brain, -10 + 4, -60, seeded(6))
		while brain.mode == "Flee" do Wild.step(brain, DT, nil, seeded(6)) end
		equal(brain.mode, "Hide")
		equal(brain.peek, false)
		local hidden, peeked = 0, 0
		local w = watcher(-10 + 15, -60, 0)
		while brain.mode == "Hide" and hidden + peeked < 30 do
			Wild.step(brain, DT, w, seeded(6))
			equal(brain.moved, false, "a hidden Lumipol does not move")
			if brain.mode == "Hide" then
				if brain.peek then
					peeked += DT
					near(brain.fx, 1, 1e-6, "peeks toward the watcher")
				else
					assert(peeked == 0, "hid again after peeking without a new scare")
					hidden += DT
				end
			end
		end
		equal(brain.mode, "Idle")
		near(hidden, C.HIDE_SECONDS, DT + 1e-6)
		near(peeked, C.PEEK_SECONDS, DT + 1e-6)
		equal(brain.alarm, 0)
	end)

	case("A1: a runner near a hidden Lumipol keeps it hidden and stops the peek", function()
		local brain = Wild.newBrain(Wild.slot("L1"), seeded(7), { cover = { { x = -10 - 8, z = -60, r = 1 } } })
		Wild.spook(brain, -10 + 4, -60, seeded(7))
		while brain.mode == "Flee" do Wild.step(brain, DT, nil, seeded(7)) end
		for _ = 1, math.ceil(C.HIDE_SECONDS / DT) + 2 do Wild.step(brain, DT, nil, seeded(7)) end
		equal(brain.peek, true)
		Wild.step(brain, DT, watcher(brain.x + 6, brain.z, 16), seeded(7))
		equal(brain.mode, "Hide")
		equal(brain.peek, false)
		near(brain.hideFor, 0, 1e-9)
	end)

	case("A1: with no cover a flee backs away 8 to 12 studs within the leash, then hides in place", function()
		for _, roll in ipairs({ 0, 0.5, 0.999999 }) do
			local brain = brainAt("L1", always(roll))
			Wild.spook(brain, brain.x - 6, brain.z, always(roll))
			equal(brain.mode, "Flee")
			local sx = brain.x
			local travelled = 0
			for _ = 1, 40 do
				local px, pz = brain.x, brain.z
				Wild.step(brain, DT, nil, always(roll))
				travelled += dist(brain.x, brain.z, px, pz)
				assert(dist(brain.x, brain.z, -10, -60) <= C.LEASH + 1e-6, "fled past the leash")
				if brain.mode ~= "Flee" then break end
			end
			equal(brain.mode, "Hide")
			assert(brain.x > sx - 1e-9, "it ran toward the threat")
			assert(travelled >= C.FLEE_MIN - 1e-6 and travelled <= C.FLEE_MAX + 1e-6, "travelled " .. travelled)
		end
	end)

	case("A1: cover outside the leash or toward the threat is never chosen", function()
		local slot = Wild.slot("L3")
		local brain = Wild.newBrain(slot, seeded(8), { leash = 10,
			cover = { { x = 65 - 9, z = -60, r = 3 }, { x = 65 + 3, z = -60 + 1, r = 1 } } })
		equal(brain.leash, 10)
		-- Behind the west prop is 13.5 studs out, past the 10 stud leash; the east prop lies toward the threat.
		Wild.spook(brain, 65 + 12, -60, seeded(8))
		equal(brain.coverIndex, nil)
		assert(brain.hideX < 65, "fell back to backing away west")
		assert(dist(brain.hideX, brain.hideZ, 65, -60) <= 10 + 1e-6, "inside the custom leash")
	end)

	case("A1: a spook from the same spot still picks a direction", function()
		local brain = brainAt("L2", always(0.25))
		Wild.spook(brain, brain.x, brain.z, always(0.25))
		equal(brain.mode, "Flee")
		for _ = 1, 20 do Wild.step(brain, DT, nil, always(0.25)) end
		assert(dist(brain.x, brain.z, 30, -105) > 1, "it did not move")
		assert(dist(brain.x, brain.z, 30, -105) <= C.LEASH + 1e-6)
	end)

	-- Capture hooks ---------------------------------------------------------------------------------

	case("wary: Alert, Flee and an unpeeking Hide refuse a capture; Idle, Wander, Curious and a peek allow it", function()
		local brain = brainAt("L1")
		for mode, expected in pairs({ Idle = false, Wander = false, Curious = false, Alert = true, Flee = true,
			Reserved = false, Captured = false }) do
			brain.mode, brain.peek = mode, false
			equal(Wild.wary(brain), expected, mode)
		end
		brain.mode, brain.peek = "Hide", false
		equal(Wild.wary(brain), true, "hiding")
		brain.peek = true
		equal(Wild.wary(brain), false, "peeking")
		equal(Wild.wary(nil), true, "no brain fails closed")
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
			Wild.step(brain, DT, watcher(x + 30, z - 2, 16), rand)
			equal(brain.x, x)
			equal(brain.z, z)
			equal(brain.moved, false)
			equal(brain.mode, "Reserved")
		end
		near(brain.fx, 30 / dist(0, 0, 30, -2), 1e-9)
		Wild.step(brain, DT, nil, rand)
		equal(brain.mode, "Reserved")
	end)

	case("a captured Lumipol never moves or changes mode again", function()
		local rand = seeded(10)
		local brain = brainAt("L2", rand)
		Wild.reserve(brain, brain.x + 3, brain.z)
		Wild.capture(brain)
		equal(brain.mode, "Captured")
		local x, z = brain.x, brain.z
		for _ = 1, 50 do Wild.step(brain, DT, watcher(x + 2, z, 16), rand) end
		equal(brain.mode, "Captured")
		equal(brain.x, x)
		equal(brain.z, z)
		Wild.spook(brain, x + 1, z, rand)
		Wild.release(brain)
		equal(brain.mode, "Captured", "spook and release cannot bring it back")
	end)

	case("release returns to idling with no flee and no jump", function()
		local rand = seeded(8)
		local brain = brainAt("L3", rand)
		Wild.reserve(brain, 0, 0)
		local x, z = brain.x, brain.z
		Wild.release(brain)
		equal(brain.mode, "Idle")
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

	case("unusable step sizes, positions and speeds change nothing", function()
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
		for _, speed in ipairs({ NAN, INF, -5, "fast" }) do
			local calm = brainAt("L2", seeded(4))
			Wild.step(calm, DT, { x = calm.x + 5, z = calm.z, speed = speed }, seeded(4))
			equal(calm.mode, "Curious", "a bad speed reads as still: " .. tostring(speed))
			equal(calm.alarm, 0)
		end
		equal(brain.mode == "Idle" or brain.mode == "Wander", mode == "Idle" or mode == "Wander")
		local before = brain.x
		Wild.step(brain, 1e9, nil, rand)
		assert(math.abs(brain.x - before) <= C.WANDER_SPEED * 0.5 + 1e-9, "a huge step moved too far")
	end)

	case("random operations never leave the leash or produce a bad number", function()
		local rand = seeded(77)
		local cover = { { x = -10 + 15, z = -60 + 5, r = 2 }, { x = -10 - 12, z = -60 - 9, r = 3 }, { x = -10, z = -60 + 20, r = 1 } }
		local brain = Wild.newBrain(Wild.slot("L1"), rand, { cover = cover })
		local modes = {}
		for index = 1, 8000 do
			local roll = rand()
			if roll < 0.01 then Wild.spook(brain, -10 + (rand() - 0.5) * 30, -60 + (rand() - 0.5) * 30, rand)
			elseif roll < 0.02 then Wild.reserve(brain, -10 + (rand() - 0.5) * 20, -60 + (rand() - 0.5) * 20)
			elseif roll < 0.03 then Wild.release(brain) end
			local w = rand() < 0.4 and watcher(-10 + (rand() - 0.5) * 40, -60 + (rand() - 0.5) * 40, rand() * 20) or nil
			Wild.step(brain, DT, w, rand)
			modes[brain.mode] = true
			assert(brain.x == brain.x and brain.z == brain.z and brain.fx == brain.fx and brain.fz == brain.fz,
				"NaN at step " .. index)
			assert(dist(brain.x, brain.z, -10, -60) <= C.LEASH + 1e-6, "outside the leash at step " .. index)
			near(dist(0, 0, brain.fx, brain.fz), 1, 1e-6, "facing at step " .. index)
			assert(brain.alarm >= 0 and brain.alarm == brain.alarm, "alarm at step " .. index)
		end
		for _, mode in ipairs({ "Idle", "Wander", "Curious", "Alert", "Flee", "Hide", "Reserved" }) do
			assert(modes[mode], "never reached " .. mode)
		end
	end)

	case("the same seed gives the same walk, threats included", function()
		local function walk()
			local rand = seeded(31)
			local brain = Wild.newBrain(Wild.slot("L1"), rand, { cover = { { x = -20, z = -50, r = 2 } } })
			local x, z = 0, 0
			for index = 1, 500 do
				local w = index % 50 < 10 and watcher(brain.cx + 8, brain.cz, index % 100 < 50 and 16 or 3) or nil
				Wild.step(brain, DT, w, rand)
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

-- Invoke with require(freshTestClone)(require(freshBeastChaseClone), freshBeastChaseClone.Source).
-- Beast revision 2026-11-16 (odd/tasks/wildbound-beast-revision.md, BR0): the shared chase rules, pure.
return function(Chase, source)
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

	case("BR0 Chase: exactly the six wave beasts chase persistently; guardians and Scuttler do not", function()
		for _, name in ipairs({ "Viper", "Pouncer", "Streamer", "Root", "Gaze", "Lurker" }) do
			equal(Chase.persistent(name), true, name)
		end
		for _, name in ipairs({ "Scuttler", "Gomibu", "Flanfuria", "Tortidragon", "DonGlaseon", "NubeGrunona", "AbejaReina",
			"CandyCritter", "nope" }) do
			equal(Chase.persistent(name), false, name)
		end
		assert(table.isfrozen(Chase.PERSISTENT), "frozen")
	end)

	case("BR0 Chase: the one end check is death (no body) or a safe zone, nothing else", function()
		equal(Chase.ended(nil), "Death")
		equal(Chase.ended({ alive = false }), "Death")
		equal(Chase.ended({ alive = true, safe = true }), "SafeZone")
		equal(Chase.ended({ alive = true, safe = false, x = 9999, z = 9999 }), nil, "far away is not an end")
	end)

	case("BR0 Chase: a persistent beast far behind closes in at the catch-up speed; near, or backing off, it keeps its own", function()
		local C = Chase.CATCHUP
		equal(Chase.walkSpeed("Viper", 14, C.distance + 1, 1), C.speed)
		equal(Chase.walkSpeed("Viper", 14, C.distance - 1, 1), 14)
		equal(Chase.walkSpeed("Viper", 30, C.distance + 50, 1), 30, "never slowed down")
		equal(Chase.walkSpeed("Viper", 14, C.distance + 50, -1), 14, "backing off is never sped up")
		equal(Chase.walkSpeed("Gomibu", 12, C.distance + 50, 1), 12, "a leashed guardian is untouched")
		assert(C.speed > 16, "faster than a base walk")
	end)

	case("BR0 Chase: slows and roots are clamped to the caps and broken input is refused", function()
		local m, s = Chase.clampSlow(0.1, 99)
		equal(m, Chase.EFFECTS.slowMinMultiplier)
		equal(s, Chase.EFFECTS.slowMaxSeconds)
		equal(Chase.clampSlow(0 / 0, 1), nil)
		equal(Chase.clampRoot(1), 1)
		equal(Chase.clampRoot(10), Chase.EFFECTS.rootMaxSeconds)
		equal(Chase.clampRoot(math.huge), nil)
	end)

	case("BR0 Chase: a reposition spot must be grounded, out of safe zones, between min and max, clear of the target", function()
		local target = { x = 0, y = 0, z = 0 }
		local opts = { min = 12, max = 30, clearance = 6, safe = function(x) return x > 100 end, clear = function(spot) return spot.z ~= 7 end }
		equal(Chase.validSpot({ x = 20, y = 0, z = 0 }, target, opts), true)
		equal(select(2, Chase.validSpot(nil, target, opts)), "NoSpot")
		equal(select(2, Chase.validSpot({ x = 20, y = 0 / 0, z = 0 }, target, opts)), "NoSpot", "under the map")
		equal(select(2, Chase.validSpot({ x = 3, y = 0, z = 0 }, target, opts)), "Near", "inside the target")
		equal(select(2, Chase.validSpot({ x = 31, y = 0, z = 0 }, target, opts)), "Far")
		equal(select(2, Chase.validSpot({ x = 20, y = 0, z = 7 }, target, opts)), "Blocked")
		equal(select(2, Chase.validSpot({ x = 120, y = 0, z = 0 }, { x = 100, y = 0, z = 0 }, opts)), "Safe")
	end)

	case("BR0 Chase: the module is pure", function()
		for _, banned in ipairs({ "workspace", "game:", "task.", "os.clock", "math.random", "Random.new", "FireClient" }) do
			assert(not source:find(banned, 1, true), "source uses " .. banned)
		end
	end)

	return result
end

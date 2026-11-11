-- Invoke with require(freshTestClone)(require(freshBatKnockClone), freshBatKnockClone.Source).
-- Bat knockback (decisions Q4 and Q4b, docs/mechanics/wildbound-new-mechanics.md section 3): a faster bat (5 s) whose
-- landed hit ragdolls the target about 1.2 s and pushes them away from the attacker with a capped impulse (no flinging
-- across the map), drops a carried egg, and leaves 3 s of immunity against chain stuns. Never in a safe zone (the hub).
-- WildboundBat keeps the hitbox (inReach, pickTarget); this module replaces its cooldown, stumble and immunity.
return function(Knock, source)
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
	local HUB = { { x = 0, z = 600, radius = 100 } }
	local function out(extra)
		local ctx = { alive = true, busy = false, x = 0, z = 0, zones = HUB }
		for k, v in pairs(extra or {}) do ctx[k] = v end
		return ctx
	end
	local FROM = { x = 0, y = 3, z = 0, lookX = 0, lookZ = 1 }
	local function at(x, z) return { x = x, y = 3, z = z } end

	case("K1: the numbers: 5 s cooldown, 1.2 s ragdoll, 3 s immunity, a capped impulse", function()
		local C = Knock.CONSTANTS
		assert(type(C) == "table", "CONSTANTS")
		equal(C.COOLDOWN, 5); equal(C.RAGDOLL_SECONDS, 1.2); equal(C.IMMUNITY, 3)
		equal(C.IMPULSE, 45); equal(C.LIFT, 20)
		equal(Knock.MAX_FLIGHT, 24, "studs a knock may carry a body through the air at most")
		equal(Knock.live.COOLDOWN, 5, "live starts at the defaults")
	end)

	case("K2: one swing per 5 s, spent on a miss; refused (and not spent) in a safe zone, dead, busy or ragdolled", function()
		local reg = Knock.new()
		local ok, readyAt = Knock.swing(reg, 1, 100, out())
		assert(ok, "first swing"); equal(readyAt, 105)
		equal(select(2, Knock.swing(reg, 1, 104.9, out())), "Cooldown")
		assert(Knock.swing(reg, 1, 105, out()), "after 5 s")
		equal(select(2, Knock.swing(reg, 2, 0, out({ x = 0, z = 560 }))), "SafeZone", "inside the hub")
		equal(select(2, Knock.swing(reg, 2, 0, out({ alive = false }))), "Dead")
		equal(select(2, Knock.swing(reg, 2, 0, out({ busy = true }))), "Busy")
		equal(select(2, Knock.swing(reg, 2, 0, nil)), "Dead", "no context is never a swing")
		equal(select(2, Knock.swing(reg, 2, 0, out({ x = 0 / 0 }))), "BadPosition", "an unknown position is never outside")
		assert(Knock.swing(reg, 2, 0, out()), "a refused swing never spends the cooldown")
		equal(select(2, Knock.swing(reg, nil, 0, out())), "InvalidPlayer")
		equal(select(2, Knock.swing(reg, 3, 0 / 0, out())), "BadClock")
	end)

	case("K3: a landed hit ragdolls the target, drops a carried egg and starts the immunity", function()
		local reg = Knock.new()
		local hit = Knock.knock(reg, FROM, "B", at(0, 5), 10, { carrying = true, zones = HUB })
		equal(hit.landed, true); equal(hit.drop, true)
		near(hit.ragdoll, 1.2, "ragdoll seconds"); near(hit.ragdollUntil, 11.2); near(hit.immuneUntil, 13)
		equal(Knock.ragdolled(reg, "B", 11.1), true); equal(Knock.ragdolled(reg, "B", 11.21), false)
		local other = Knock.knock(reg, FROM, "C", at(0, 5), 10, { carrying = false, zones = HUB })
		equal(other.landed, true); equal(other.drop, false, "nothing to drop")
	end)

	case("K4: no chain stuns: a second hit inside the 3 s immunity does nothing", function()
		local reg = Knock.new()
		Knock.knock(reg, FROM, "B", at(0, 5), 10, { carrying = true, zones = HUB })
		local again = Knock.knock(reg, FROM, "B", at(0, 5), 12.9, { carrying = true, zones = HUB })
		equal(again.landed, false); equal(again.reason, "Immune"); equal(again.drop, false)
		equal(Knock.knock(reg, FROM, "B", at(0, 5), 13, { carrying = true, zones = HUB }).landed, true, "after 3 s")
	end)

	case("K5: the push goes away from the attacker, flat and up, at the set strength", function()
		local reg = Knock.new()
		local hit = Knock.knock(reg, FROM, "B", at(3, 4), 0, { zones = HUB })
		local v = hit.impulse
		near(v.x, 45 * 0.6, "x away from the attacker"); near(v.z, 45 * 0.8, "z away from the attacker")
		near(v.y, 20, "a little lift")
		-- Standing on the attacker: pushed the way the attacker faces.
		local same = Knock.impulse(FROM, at(0, 0))
		near(same.x, 0); near(same.z, 45)
	end)

	case("K6: the push is capped: a tuned impulse never flings a body further than MAX_FLIGHT", function()
		Knock.tune({ IMPULSE = 9999, LIFT = 9999 })
		local v = Knock.impulse(FROM, at(0, 5))
		local flight = Knock.flight(v)
		assert(flight <= Knock.MAX_FLIGHT + 1e-6, "flight " .. flight .. " is over the cap")
		assert(v.y <= Knock.LIFT_MAX + 1e-9, "lift is clamped")
		Knock.tune(nil)
		assert(Knock.flight(Knock.impulse(FROM, at(0, 5))) <= Knock.MAX_FLIGHT, "the defaults are inside the cap")
		near(Knock.flight({ x = 0, y = 0, z = 50 }), 0, "no lift, no flight")
	end)

	case("K7: never inside a safe zone: a target in the hub is not knocked", function()
		local reg = Knock.new()
		local inside = Knock.knock(reg, { x = 0, y = 3, z = 495, lookX = 0, lookZ = 1 }, "B", at(0, 505), 0,
			{ carrying = true, zones = HUB })
		equal(inside.landed, false); equal(inside.reason, "SafeZone"); equal(inside.drop, false)
		equal(Knock.inSafe(0, 600, HUB), true); equal(Knock.inSafe(0, 499, HUB), false)
		equal(Knock.inSafe(0, 0, nil), false, "no zones, nothing is safe")
		equal(Knock.inSafe(0 / 0, 0, HUB), true, "an unknown position counts as safe for the target")
	end)

	case("K8: bad input never lands", function()
		local reg = Knock.new()
		equal(Knock.knock(reg, FROM, "B", { x = 0 / 0, y = 0, z = 0 }, 0, {}).landed, false)
		equal(Knock.knock(reg, nil, "B", at(0, 5), 0, {}).landed, false)
		equal(Knock.knock(reg, FROM, nil, at(0, 5), 0, {}).landed, false)
		equal(Knock.knock(reg, FROM, "B", at(0, 5), 0 / 0, {}).landed, false)
		equal(Knock.knock(nil, FROM, "B", at(0, 5), 0, {}).landed, false)
	end)

	case("K9: tune() keeps the safety floors: cooldown, a short ragdoll, immunity longer than the ragdoll", function()
		Knock.tune({ COOLDOWN = 0, RAGDOLL_SECONDS = 9, IMMUNITY = 0, bogus = 1 })
		assert(Knock.live.COOLDOWN >= Knock.COOLDOWN_MIN, "cooldown floor")
		assert(Knock.live.RAGDOLL_SECONDS <= 2, "ragdoll cap")
		assert(Knock.live.IMMUNITY >= Knock.live.RAGDOLL_SECONDS + 1, "immunity outlasts the ragdoll")
		Knock.tune(nil)
		equal(Knock.live.COOLDOWN, 5)
		equal(Knock.tunable().IMMUNITY, 3, "flat rows for the dev tuning schema")
	end)

	case("K10: forget clears a player; the module is pure", function()
		local reg = Knock.new()
		Knock.knock(reg, FROM, "B", at(0, 5), 0, { zones = HUB })
		Knock.forget(reg, "B")
		equal(Knock.ragdolled(reg, "B", 0.5), false)
		assert(type(source) == "string", "source")
		for _, needle in ipairs({ "GetService", "os.time", "os.clock", "math.random", "tick()", "workspace" }) do
			assert(not source:find(needle, 1, true), "source has " .. needle)
		end
	end)

	return result
end

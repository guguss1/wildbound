-- Invoke with require(freshTestClone)(require(freshAttackClone)).
-- Caramelo biome (odd/tasks/caramelo-bioma.md, T3, S6): Golpe de Goma, Gomibu's single attack, as server rules (pack
-- 03_PERSONAJES/01_GOMIBU.md and 05_SISTEMAS/04_BALANCE_INICIAL_CONFIG.md). Pure: time and positions come in, effects
-- come out; nothing here reads a clock, a client or an animation.
return function(Attack)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "Expected " .. tostring(expected) .. ", got "
			.. tostring(actual))
	end
	local function near(actual, expected, tolerance, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= tolerance,
			(label and label .. ": " or "") .. "Expected about " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function begin(target) return Attack.start(100, { x = 0, z = 0 }, target or { x = 6, z = 0 }, {}) end
	local function player(id, x, z, extra)
		local p = { id = id, x = x, z = z, alive = true, safe = false, carrying = true }
		for k, v in pairs(extra or {}) do p[k] = v end
		return p
	end

	case("S6: the sheet's numbers: tell 0.90, lock 0.55, jump 0.45, radius 4.5, push 8, slow x0.8 for 1 s, recover 0.70, cooldown 5.5", function()
		equal(Attack.TELEGRAPH_SECONDS, 0.9); equal(Attack.LOCK_SECONDS, 0.55); equal(Attack.JUMP_SECONDS, 0.45)
		equal(Attack.RADIUS_STUDS, 4.5); equal(Attack.PUSH_STUDS, 8); equal(Attack.SLOW_FACTOR, 0.8); equal(Attack.SLOW_SECONDS, 1)
		equal(Attack.RECOVER_SECONDS, 0.7); equal(Attack.COOLDOWN_SECONDS, 5.5)
		assert(Attack.TELEGRAPH_SECONDS >= 0.8, "the fairness contract wants a tell of at least 0.8 s")
	end)

	case("S6: phases by the server's clock", function()
		local a = begin()
		equal(Attack.phase(a, 100), "Telegraph"); equal(Attack.phase(a, 100.899), "Telegraph")
		equal(Attack.phase(a, 100.9), "Jump"); equal(Attack.phase(a, 101.349), "Jump")
		equal(Attack.phase(a, 101.35), "Recover"); equal(Attack.phase(a, 102.049), "Recover")
		equal(Attack.phase(a, 102.05), "Done")
		near(Attack.impactAt(a), 101.35, 1e-9, "impact time")
		near(Attack.endsAt(a), 102.05, 1e-9, "end time")
	end)

	case("S6: the circle follows the player until 0.55 s, then never again", function()
		local a = begin({ x = 6, z = 0 })
		Attack.aim(a, 100.3, { x = 5, z = 3 })
		equal(a.centre.x, 5); equal(a.centre.z, 3)
		Attack.aim(a, 100.549, { x = 4, z = 4 })
		equal(a.centre.x, 4); equal(a.centre.z, 4)
		equal(Attack.locked(a, 100.549), false)
		Attack.aim(a, 100.55, { x = -9, z = -9 })
		equal(a.centre.x, 4, "aim moved at the lock"); equal(a.centre.z, 4)
		equal(Attack.locked(a, 100.55), true)
		Attack.aim(a, 101.2, { x = 0, z = 9 })
		equal(a.centre.x, 4, "aim corrected after the lock"); equal(a.centre.z, 4)
	end)

	case("S6: a short jump: the aim never leaves the jump range", function()
		local a = begin({ x = 40, z = 0 })
		near(a.centre.x, Attack.MAX_JUMP_STUDS, 1e-9, "clamped on start")
		Attack.aim(a, 100.2, { x = 0, z = -50 })
		near(a.centre.z, -Attack.MAX_JUMP_STUDS, 1e-9, "clamped while following")
		near(a.centre.x, 0, 1e-9)
	end)

	case("S6: the jump is one arc from where it stood to the locked circle, no teleport", function()
		local a = begin({ x = 6, z = 0 })
		local p = Attack.position(a, 100.5)
		equal(p.x, 0, "moves during the tell"); equal(p.y, 0)
		p = Attack.position(a, 100.9)
		near(p.x, 0, 1e-9, "jump start x"); near(p.y, 0, 1e-9, "jump start height")
		local last, top = p, 0
		for i = 1, 45 do
			p = Attack.position(a, 100.9 + i * 0.01)
			assert(p.x >= last.x - 1e-9, "the jump goes backwards")
			assert(p.x - last.x <= 6 / 45 * 2.5, "a jump step of " .. (p.x - last.x) .. " studs is a teleport")
			top, last = math.max(top, p.y), p
		end
		near(last.x, 6, 1e-6, "lands on the circle"); near(last.y, 0, 1e-6, "lands on the ground")
		assert(top >= 1.5 and top <= 4, "arc height " .. top)
		p = Attack.position(a, 101.8)
		near(p.x, 6, 1e-9, "stays where it landed")
	end)

	case("S6: the server measures the hit: inside 4.5 studs of the circle, pushed 8 away and slowed, egg kept, no damage", function()
		local a = begin({ x = 6, z = 0 })
		local effects = Attack.resolve(a, 101.35, { player(1, 6 + 4.5, 0), player(2, 6 + 4.51, 0), player(3, 6, -3) })
		equal(#effects, 2, "players hit")
		local byId = {}
		for _, e in ipairs(effects) do byId[e.id] = e end
		assert(byId[1] and byId[3] and not byId[2], "wrong players hit")
		near(byId[1].push.x, 8, 1e-6, "push away along x"); near(byId[1].push.z, 0, 1e-6)
		near(byId[3].push.z, -8, 1e-6, "push away along z"); near(byId[3].push.x, 0, 1e-6)
		for _, e in pairs(byId) do
			equal(e.slowFactor, 0.8, "slow factor"); equal(e.slowSeconds, 1, "slow seconds")
			equal(e.damage, 0, "damage"); equal(e.dropEgg, false, "egg")
		end
	end)

	case("S6: nobody in a safe zone or already down is touched, and a player on the centre still gets a push", function()
		local a = begin({ x = 6, z = 0 })
		local effects = Attack.resolve(a, 101.35, { player(1, 6, 0, { safe = true }), player(2, 7, 0, { alive = false }), player(3, 6, 0) })
		equal(#effects, 1, "players hit")
		equal(effects[1].id, 3)
		near(math.sqrt(effects[1].push.x ^ 2 + effects[1].push.z ^ 2), 8, 1e-6, "push length from the centre")
	end)

	case("S6: one hit per attack, and only at the impact", function()
		local a = begin({ x = 6, z = 0 })
		equal(#Attack.resolve(a, 101.2, { player(1, 6, 0) }), 0, "hit before landing")
		equal(#Attack.resolve(a, 101.35, { player(1, 6, 0) }), 1, "hit at landing")
		equal(#Attack.resolve(a, 101.36, { player(1, 6, 0) }), 0, "hit twice")
	end)

	case("S6: it cannot chain jumps: 5.5 s of cooldown after an attack ends", function()
		equal(Attack.canStart(nil, 50), true, "first attack")
		equal(Attack.canStart(102.05, 102.05 + 5.49), false)
		equal(Attack.canStart(102.05, 102.05 + 5.5), true)
	end)

	case("S6: a stored pet never attacks", function()
		local state, why = Attack.start(100, { x = 0, z = 0 }, { x = 3, z = 0 }, { pet = true })
		equal(state, nil, "a pet started an attack")
		equal(why, "Pet")
		local wild = Attack.start(100, { x = 0, z = 0 }, { x = 3, z = 0 }, { pet = false })
		assert(wild ~= nil, "a wild Gomibu could not attack")
	end)

	return result
end

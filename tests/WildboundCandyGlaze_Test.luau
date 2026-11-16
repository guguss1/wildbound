-- Invoke with require(freshTestClone)(require(freshCandyGlazeClone), require(freshCandyLayoutClone),
--   require(freshCandyBuilderClone), { client = <WildboundCandyGlazeClient Source>, server = <WildboundServer Source> }).
-- Caramelo v2 (odd/tasks/wildbound-caramelo-v2.md, DG4): Glaseado resbaloso. Glaze puddles on Don Glaseon's plaza: the
-- player skates on them (no slowdown, little grip); a fast sharp turn makes them slip into a short ragdoll that the
-- server checks. Pure rules, the builder's puddles (into a detached model) and source pins. Changes nothing.
return function(Glaze, Layout, Builder, sources)
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
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-3),
			(label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function has(source, needle, label)
		assert(type(source) == "string" and string.find(source, needle, 1, true), (label or "missing") .. ": " .. needle)
	end
	local function speed(v) return math.sqrt(v.x * v.x + v.z * v.z) end

	case("DG4: the numbers: slip above 17 studs/s on a 75-degree turn, a 1 s fall, a 3 s cooldown", function()
		near(Glaze.SLIP_SPEED, 17, "above a 16 walk: a sprint or a trained walk"); near(Glaze.SLIP_DEGREES, 75)
		near(Glaze.FALL_SECONDS, 1.0, "short and readable"); near(Glaze.SLIP_COOLDOWN, 3)
		assert(Glaze.GRIP > 0 and Glaze.GRIP <= 2, "little grip"); assert(Glaze.COAST_GRIP < Glaze.GRIP, "coasting slides more")
		assert(Glaze.FALL_MAX <= 25 and Glaze.FALL_LIFT <= 10, "a short fall, never a fling")
	end)

	case("DG4: skating keeps the speed and turns slowly toward the steering", function()
		local v = { x = 16, z = 0 }
		local after = Glaze.skate(v, { x = 0, z = 16 }, 0.1, true)
		assert(after.x > 13 and after.z > 0 and after.z < 4, "it still slides mostly the old way")
		local w = v
		for _ = 1, 30 do w = Glaze.skate(w, { x = 0, z = 16 }, 0.1, true) end
		assert(w.z > 14, "after 3 s it has turned")
		local straight = Glaze.skate({ x = 16, z = 0 }, { x = 16, z = 0 }, 0.1, true)
		near(speed(straight), 16, "never slowed")
		local coast = Glaze.skate({ x = 16, z = 0 }, { x = 0, z = 0 }, 0.1, false)
		assert(speed(coast) > 15.5, "with no input it keeps sliding")
	end)

	case("DG4: a slip only when fast and turning sharply", function()
		equal(Glaze.slips({ x = 20, z = 0 }, { x = 0, z = 1 }), true, "fast, 90 degrees")
		equal(Glaze.slips({ x = 20, z = 0 }, { x = 1, z = 1 }), false, "45 degrees")
		equal(Glaze.slips({ x = 16, z = 0 }, { x = 0, z = 1 }), false, "a plain walk never slips")
		equal(Glaze.slips({ x = 20, z = 0 }, { x = 0, z = 0 }), false, "no steering")
	end)

	case("DG4: the server allows a slip only on glaze, fast, not down, once per cooldown", function()
		local ok = { alive = true, onGlaze = true, ragdolled = false, speed = 18, now = 10, lastAt = nil }
		equal(Glaze.serverAllows(ok), true)
		local function with(key, value) local c = table.clone(ok) c[key] = value return c end
		equal(Glaze.serverAllows(with("onGlaze", false)), false, "off the glaze")
		equal(Glaze.serverAllows(with("speed", 12)), false, "too slow on the server")
		equal(Glaze.serverAllows(with("speed", 13.5)), true, "within the tolerance for lag")
		equal(Glaze.serverAllows(with("ragdolled", true)), false, "already down")
		equal(Glaze.serverAllows(with("alive", false)), false)
		equal(Glaze.serverAllows(with("lastAt", 8)), false, "the cooldown")
		local push = Glaze.fallImpulse(30, 0)
		near(push.x, 24, "along the slide, 0.8 of it"); near(push.y, Glaze.FALL_LIFT); near(push.z, 0)
		near(Glaze.fallImpulse(100, 0).x, Glaze.FALL_MAX, "capped")
	end)

	case("DG4: the builder lays the puddles on the plaza, off the stair and the nests, as decor with Radius and Top", function()
		local glaze = Layout.TOWER.glaze
		assert(glaze and #glaze >= 3, "three puddles")
		local steps = Layout.stairSteps()
		for i, g in ipairs(glaze) do
			local r = Layout.flat(g.x, g.z, Layout.TORTA.x, Layout.TORTA.z)
			assert(r - g.r >= Layout.TORTA.radius + 2 and r <= Layout.BOSS.plazaRadius, "puddle " .. i .. " on the plaza, round the Torta")
			for _, s in ipairs(steps) do assert(Layout.flat(g.x, g.z, s.x, s.z) >= g.r + 3, "puddle " .. i .. " off the stair") end
			for _, n in ipairs(Layout.NESTS) do assert(Layout.flat(g.x, g.z, n.x, n.z) >= g.r + 6, "puddle " .. i .. " off nest " .. n.id) end
		end
		local root = Instance.new("Model")
		local torta = Instance.new("Model")
		torta.Name = "GranTorta"
		torta.Parent = root
		Builder.syncTower(root, Layout)
		local folder = root.Tower:FindFirstChild("Glaze")
		assert(folder, "a Glaze folder")
		local read = Glaze.read(folder)
		equal(#read, #glaze, "every puddle")
		for _, part in ipairs(folder:GetChildren()) do
			assert(not part.CanCollide and not part.CanQuery, "decor")
			assert(part:GetAttribute("Top") > Layout.FLOOR_TOP and part:GetAttribute("Top") < Layout.FLOOR_TOP + 0.3, "just over the plaza")
		end
		local p = read[1]
		assert(Glaze.inside(read, p.x + p.r - 0.5, p.top + 3, p.z), "standing on it")
		equal(Glaze.inside(read, p.x + p.r + 0.5, p.top + 3, p.z), nil, "beside it")
		equal(Glaze.inside(read, p.x, p.top + 20, p.z), nil, "far above it")
		root:Destroy()
	end)

	case("DG4 wiring: the client skates and asks; the server checks and ragdolls through the shared ragdoll", function()
		local client, server = sources.client, sources.server
		has(client, "Glaze.skate("); has(client, "Glaze.slips("); has(client, "remote:FireServer()")
		has(client, 'root:FindFirstChild("WildboundBeastPush")', "another push wins")
		has(server, 'slip.Name = "CandyGlazeSlip"'); has(server, "Glaze.serverAllows({")
		has(server, "Heist.Ragdoll.aplicar(player, Glaze.FALL_SECONDS,", "the shared ragdoll")
		local block = string.match(server, "%(DG4%).-\nend\n") or ""
		assert(not string.find(block, "dropEgg", 1, true) and not string.find(block, "TakeDamage", 1, true), "no egg drop, no damage")
	end)

	return result
end

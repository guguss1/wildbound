-- Invoke with require(freshTestClone)(require(freshBatClone), require(freshBatKnockClone), require(freshBeastConfigClone),
-- require(freshDonGlaseonClone), ServerStorage.WildboundAssets:FindFirstChild("DonGlaseon"), { beasts =
-- WildboundBeasts.Source, service = WildboundCandyDonGlaseonService.Source, server = WildboundServer.Source,
-- anim = WildboundCandyDonGlaseonAnim.Source }).
-- CF3 (odd/tasks/wildbound-caramelo.md): Don Glaseon's robustness. (a) batImmune is enforced by the bat's two hit
-- resolvers (WildboundBat.pickTarget, WildboundBatKnock.knock), not only written in the config; (b) the sleeping copy
-- on BossHome is hidden in the same server step as the summon (Beast_bossAwake is written when an encounter starts and
-- ends, not only at the next snapshot); (c) the sleeping copy stays on BossHome, so a summon never jumps, but nothing of
-- it collides, touches or blocks a ray while it sleeps, so it never walls the main approach lane. Changes nothing.
return function(Bat, Knock, Config, DonGlaseon, prefab, sources)
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
	local function has(text, needle, label)
		assert(type(text) == "string" and text:find(needle, 1, true), (label or "source") .. " lacks " .. needle)
	end
	-- the body of `local function <name>(` up to the next top-level `end`
	local function body(text, name)
		local from = text:find("local function " .. name .. "(", 1, true)
		assert(from, "no local function " .. name)
		local stop = text:find("\nend\n", from, true)
		assert(stop, "no end for " .. name)
		return text:sub(from, stop)
	end
	local function before(text, first, second, label)
		local a, b = text:find(first, 1, true), text:find(second, 1, true)
		assert(a and b and a < b, (label or "order") .. ": " .. first .. " must come before " .. second)
	end

	local BOSS = Config.BEASTS.DonGlaseon
	local FROM = { key = 1, x = 0, y = 3, z = 0, lookX = 0, lookZ = 1 }
	local function clear() return true end

	case("CF3a: Bat.immune reads the flag on a candidate or on its beast config", function()
		assert(type(Bat.immune) == "function", "Bat.immune missing")
		equal(BOSS.batImmune, true, "the config flag")
		equal(Bat.immune({ key = "DonGlaseon", config = BOSS }), true, "the boss by its config")
		equal(Bat.immune({ key = "x", batImmune = true }), true, "a flagged candidate")
		equal(Bat.immune({ key = 2 }), false, "a player")
		equal(Bat.immune({ key = "Viper", config = Config.BEASTS.Viper }), false, "a beast without the flag")
		equal(Bat.immune(nil), false, "bad input")
	end)

	case("CF3a: pickTarget never picks a bat-immune beast, even the nearest in reach", function()
		local boss = { key = "DonGlaseon", config = BOSS, x = 0, y = 3, z = 2, alive = true }
		local player = { key = 2, x = 0, y = 3, z = 5, alive = true }
		equal(Bat.pickTarget(FROM, { boss, player }, clear), player, "the player behind the boss is hit")
		local target, reason = Bat.pickTarget(FROM, { boss }, clear)
		equal(target, nil, "the boss alone")
		equal(reason, "NoTarget", "reason")
		local flagged = { key = "x", batImmune = true, x = 0, y = 3, z = 2, alive = true }
		equal(Bat.pickTarget(FROM, { flagged }, clear), nil, "a flagged candidate")
		local viper = { key = "Viper", config = Config.BEASTS.Viper, x = 0, y = 3, z = 2, alive = true }
		equal(Bat.pickTarget(FROM, { viper }, clear), viper, "control: a candidate without the flag is still picked")
	end)

	case("CF3a: Knock.knock refuses a bat-immune target without touching its record", function()
		local reg = Knock.new()
		local at = { x = 0, y = 3, z = 3 }
		for _, ctx in ipairs({ { batImmune = true }, { config = BOSS } }) do
			local effect = Knock.knock(reg, FROM, "DonGlaseon", at, 10, ctx)
			equal(effect.landed, false, "landed")
			equal(effect.reason, "BatImmune", "reason")
			equal(effect.drop, false, "drop")
		end
		equal(Knock.ragdolled(reg, "DonGlaseon", 10.1), false, "no ragdoll")
		equal(Knock.immune(reg, "DonGlaseon", 10.1), false, "no anti-chain immunity started")
		local control = Knock.knock(reg, FROM, "DonGlaseon", at, 10, {})
		equal(control.landed, true, "control: the same key lands without the flag")
	end)

	case("CF3a: the server passes the target's flag to the knock", function()
		has(sources.server, "local target = Bat.pickTarget(from, candidates, function(candidate)")
		has(sources.server, "carrying = EggCarry.carriedBy(eggs, target.key) ~= nil, zones = Heist.knockZones(), batImmune = Bat.immune(target) })")
	end)

	case("CF3b: Config.bossAwake answers from the live encounters, at once", function()
		assert(type(Config.bossAwake) == "function", "Config.bossAwake missing")
		local live = {}
		equal(Config.bossAwake(live), false, "none")
		live[1] = { e = { beast = "Viper" } }
		equal(Config.bossAwake(live), false, "another beast")
		live[2] = { e = { beast = "DonGlaseon" } }
		equal(Config.bossAwake(live), true, "the summon's own step")
		live[2] = nil
		equal(Config.bossAwake(live), false, "the close's own step")
		equal(Config.bossAwake({ { e = false }, { 3 } }), false, "malformed entries")
		equal(Config.bossAwake(nil), false, "bad input")
	end)

	case("CF3b: the beasts server writes Beast_bossAwake when an encounter starts and ends, before the Spawn message", function()
		local beasts = sources.beasts
		has(beasts, 'telemetry:SetAttribute("Beast_bossAwake", Config.bossAwake(live))')
		local start = body(beasts, "start")
		before(start, "live[reservation.id] = {", "publishBoss()", "start")
		before(start, "publishBoss()", 'send(player, { type = "Spawn"', "start")
		local close = body(beasts, "close")
		before(close, "live[id] = nil", "publishBoss()", "close")
		before(beasts, "local function publishBoss()", "local function close(", "declared first")
		has(sources.service, 'GetAttributeChangedSignal("Beast_bossAwake"):Connect(refresh)', "the service hides on the change")
	end)

	case("CF3c: DonGlaseon.asleep makes a copy pass-through and leaves the prefab alone", function()
		assert(type(DonGlaseon.asleep) == "function", "DonGlaseon.asleep missing")
		assert(prefab and prefab:IsA("Model"), "no DonGlaseon prefab")
		local copy = DonGlaseon.spawn(prefab, CFrame.new(578, 0.5, -3))
		equal(DonGlaseon.asleep(copy), copy, "returns the copy")
		local parts = 0
		for _, d in ipairs(copy:GetDescendants()) do
			if d:IsA("BasePart") then
				parts += 1
				equal(d.CanCollide, false, d.Name .. " CanCollide")
				equal(d.CanTouch, false, d.Name .. " CanTouch")
				equal(d.CanQuery, false, d.Name .. " CanQuery")
			end
		end
		assert(parts > 0, "no parts")
		equal(copy:GetAttribute("BeastSolid"), false, "marked asleep")
		copy:Destroy()
		local box = prefab:FindFirstChild("Collision")
		equal(box and box.CanCollide, true, "the prefab's hitbox still collides (the live boss keeps it)")
	end)

	case("CF3c: the service puts the sleeping copy to sleep and keeps it on BossHome", function()
		local service = sources.service
		has(service, 'require(ServerStorage:WaitForChild("WildboundCandyDonGlaseon"))')
		has(service, "local sleeper = DonGlaseon.asleep(dress(prefab:Clone()))")
		has(service, 'local home = Sites.world(nil, "bossHome")')
	end)

	-- PF5 (odd/tasks/wildbound-caramelo-playfix.md): with no published Idle_Breath clip the sleeping copy was a statue. The
	-- client now gives it a slow breath of its own (a chest bone's sway when the rig has one, else a small rise and fall of
	-- the whole copy), only while no published clip plays, and only once per model however often it is re-parented.
	case("PF5: the sleeping copy breathes on the client while no published clip plays", function()
		local anim = sources.anim
		assert(type(anim) == "string", "pass the Don Glaseon client animator source")
		has(anim, "local function breathe(model)", "the breathing fallback")
		has(anim, 'model:GetAttribute("Clip_Idle_Breath")', "only without a published breath clip")
		has(anim, "breathing[model] = true", "set up once per model")
		has(anim, 'if child.Name == "DonGlaseonDormant" then setup(child) breathe(child) end', "the sleeper breathes when it comes back")
	end)

	return result
end

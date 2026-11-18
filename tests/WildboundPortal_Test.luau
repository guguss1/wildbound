-- Invoke with require(freshTestClone)(require(freshPortalClone), require(freshBalanceClone), require(freshRulesClone),
-- require(freshCandyLayoutClone), require(freshBiomesClone), { portal = freshPortalClone.Source }).
-- CE3 / T08a + T08b (odd/tasks/wildbound-caramelo.md, odd/tasks/wildbound-2-0.md): the return portals' pure rules. A
-- portal sends its user to their own base after 5 s with no threat nearby and a 2 s channel, then rests 30 s for that
-- player (pack 04_ENTORNO/03 "Portal", Balance.portal). A threat, a hit, a beast on the player, death or stepping away
-- cuts the channel. CG2 (decision 47, supersedes 34): a player carrying an egg is refused (the egg goes home on foot,
-- past the beasts), and a station switched off during the channel cuts it. No services, no clock, no instances.
return function(Portal, Balance, Rules, Layout, Biomes, sources)
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
	local function near(actual, expected, label)
		assert(type(actual) == "number" and math.abs(actual - expected) < 1e-6,
			(label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local C = Portal.CONFIG
	local function ready(overrides)
		local ctx = { enabled = true, alive = true, ragdolled = false, distance = 3, hasDestination = true, station = "caramelo",
			x = 0, z = 0 }
		for key, value in pairs(overrides or {}) do ctx[key] = value end
		return ctx
	end

	case("PT-1: the numbers are the pack's (Balance.portal and the Caramelo layout): 5 s calm, 2 s channel, 30 s rest", function()
		equal(C.calmSeconds, 5, "calm"); equal(C.channelSeconds, 2, "channel"); equal(C.cooldown, 30, "cooldown")
		equal(C.calmSeconds, Balance.CONSTANTS.portal.calmSeconds, "Balance calm")
		equal(C.channelSeconds, Balance.CONSTANTS.portal.channelSeconds, "Balance channel")
		equal(C.cooldown, Balance.CONSTANTS.portal.cooldown, "Balance cooldown")
		equal(C.calmSeconds, Layout.PORTAL.quietSeconds, "layout quiet")
		equal(C.channelSeconds, Layout.PORTAL.channelSeconds, "layout channel")
		equal(C.cooldown, Layout.PORTAL.cooldownSeconds, "layout cooldown")
		assert(C.useRange >= 6 and C.useRange <= 14, "use range " .. tostring(C.useRange))
		assert(C.moveTolerance > 0 and C.moveTolerance < C.useRange, "move tolerance")
		assert(C.threatRadius >= 30, "threat radius")
		assert(C.hurtMin >= 2 and C.hurtMin < 20, "a hit is a drop of at least hurtMin health (regeneration dips are 1)")
		assert(table.isfrozen(C), "CONFIG frozen")
	end)

	case("PT-2: a calm player beside an open portal starts a 2 s channel", function()
		local st = Portal.new()
		equal(Portal.calmLeft(st, 100), 0, "a new player is calm")
		equal(Portal.cooldownLeft(st, 100), 0, "and rested")
		local ok, reason = Portal.request(st, ready(), 100)
		equal(ok, true, "ok"); equal(reason, nil, "reason")
		assert(st.channel, "channel open")
		near(st.channel.startedAt, 100, "startedAt"); near(st.channel.endsAt, 100 + C.channelSeconds, "endsAt")
		equal(st.channel.station, "caramelo", "station")
		equal(Portal.step(st, { alive = true, x = 0, z = 0, distance = 3 }, 101), "Channeling", "half way")
	end)

	case("PT-3: every refusal has its reason, checked in a fixed order", function()
		local function refuse(ctx, expected, st, now)
			local ok, reason = Portal.request(st or Portal.new(), ctx, now or 50)
			equal(ok, false, expected .. " ok"); equal(reason, expected, expected)
		end
		refuse(ready({ enabled = false, alive = false }), "Disabled")
		refuse(ready({ alive = false, distance = 99 }), "Dead")
		refuse(ready({ ragdolled = true }), "Dead")
		refuse(ready({ distance = C.useRange + C.allowance + 0.1 }), "TooFar")
		refuse(ready({ distance = 0 / 0 }), "TooFar")
		local missing = ready()
		missing.distance = nil
		refuse(missing, "TooFar")
		local busy = Portal.new()
		assert(Portal.request(busy, ready(), 50))
		refuse(ready(), "Busy", busy, 50.5)
		refuse(ready({ carrying = true }), "Busy", busy, 50.5)
		local rested = Portal.new()
		Portal.complete(rested, 40)
		refuse(ready({ carrying = true, hasDestination = false }), "Carrying", rested, 50)
		refuse(ready({ hasDestination = false }), "Cooldown", rested, 50)
		local hunted = Portal.new()
		Portal.noteThreat(hunted, 49)
		refuse(ready({ hasDestination = false }), "Threat", hunted, 50)
		refuse(ready({ hasDestination = false }), "NoBase")
		equal(Portal.request(Portal.new(), nil, 50), false, "no context")
		equal(Portal.request(nil, ready(), 50), false, "no state")
	end)

	case("PT-4: the calm clock: refused until 5 s after the last threat, then allowed", function()
		local st = Portal.new()
		Portal.noteThreat(st, 10)
		Portal.noteThreat(st, 8) -- an older stamp never moves the clock back
		near(Portal.calmLeft(st, 12), 3, "3 s left")
		equal(select(2, Portal.request(st, ready(), 14.99)), "Threat", "at 4.99 s")
		equal(Portal.request(st, ready(), 15), true, "at 5 s")
		Portal.noteThreat(st, 0 / 0) -- bad stamps are ignored
		equal(st.lastThreatAt, 10, "NaN ignored")
	end)

	case("PT-5: the channel completes at 2 s and the portal rests 30 s for that player", function()
		local st = Portal.new()
		assert(Portal.request(st, ready(), 0))
		local here = { alive = true, x = 0, z = 0, distance = 3 }
		equal(Portal.step(st, here, 1.99), "Channeling", "1.99 s")
		equal(Portal.step(st, here, 2), "Ready", "2 s")
		equal(Portal.step(st, here, 2.5), "Ready", "still ready until the server moves them")
		Portal.complete(st, 2.5)
		equal(st.channel, nil, "channel closed")
		near(Portal.cooldownLeft(st, 12.5), 20, "20 s left")
		equal(select(2, Portal.request(st, ready(), 32.49)), "Cooldown", "29.99 s")
		equal(Portal.request(st, ready(), 32.5), true, "30 s")
		equal(Portal.step(Portal.new(), here, 1), "Idle", "no channel")
	end)

	case("PT-6: a threat, stepping away, leaving the portal or dying cuts the channel, with no rest", function()
		local function cut(change, expected)
			local st = Portal.new()
			assert(Portal.request(st, ready(), 0))
			local ctx = { alive = true, x = 0, z = 0, distance = 3 }
			change(st, ctx)
			local status, reason = Portal.step(st, ctx, 1)
			equal(status, "Interrupted", expected); equal(reason, expected, expected .. " reason")
			equal(st.channel, nil, expected .. " channel closed")
			equal(Portal.cooldownLeft(st, 1), 0, expected .. " no rest")
		end
		cut(function(st) Portal.noteThreat(st, 0.5) end, "Threat")
		cut(function(st) Portal.noteThreat(st, 0) end, "Threat") -- a threat in the very tick it started
		cut(function(_, ctx) ctx.x = C.moveTolerance + 0.1 end, "Moved")
		cut(function(_, ctx) ctx.distance = C.useRange + C.allowance + 1 end, "Moved")
		cut(function(_, ctx) ctx.alive = false end, "Dead")
		cut(function(_, ctx) ctx.x = 0 / 0 end, "Moved")
		-- CG2 (F6): the station switched off mid-channel, or an egg picked up during it, cuts with no teleport.
		cut(function(_, ctx) ctx.enabled = false end, "Disabled")
		cut(function(_, ctx) ctx.carrying = true end, "Carrying")
		local st = Portal.new()
		assert(Portal.request(st, ready(), 0))
		equal(Portal.step(st, { alive = true, x = C.moveTolerance - 0.1, z = 0, distance = 3 }, 1), "Channeling",
			"a small shuffle is fine")
		Portal.noteThreat(st, -1) -- a threat older than the channel's start is not a cut
		equal(Portal.step(st, { alive = true, x = 0, z = 0, distance = 3 }, 1.5), "Channeling", "old threat")
		Portal.cancel(st)
		equal(st.channel, nil, "cancel")
	end)

	case("PT-7: what counts as a threat nearby", function()
		local now = 100
		local function threat(signals) return Portal.threatened(signals, now) end
		equal(threat({ x = 0, z = 0 }), false, "nothing")
		equal(threat({ x = 0, z = 0, siluetaLevel = "Chase" }), true, "La Silueta hunting me")
		equal(threat({ x = 0, z = 0, siluetaLevel = "Near" }), true, "La Silueta near")
		equal(threat({ x = 0, z = 0, siluetaLevel = "Distant" }), false, "La Silueta far")
		equal(threat({ x = 0, z = 0, beastEngagedAt = now - 0.5 }), true, "a beast on me")
		equal(threat({ x = 0, z = 0, beastEngagedAt = now - C.signalSeconds - 0.1 }), false, "an old beast stamp")
		equal(threat({ x = 0, z = 0, batHitAt = now - 0.2 }), true, "a bat hit")
		equal(threat({ x = 0, z = 0, ragdollUntil = now + 0.4 }), true, "ragdolled")
		equal(threat({ x = 0, z = 0, hurt = true }), true, "health dropped")
		equal(threat({ x = 0, z = 0, adults = { { x = C.threatRadius - 1, z = 0 } } }), true, "an awake parent near")
		equal(threat({ x = 0, z = 0, adults = { { x = C.threatRadius + 1, z = 0 } } }), false, "an awake parent far")
		equal(threat({ x = 0, z = 0, adults = { { x = 0 / 0, z = 0 } } }), false, "a bad parent point")
		local yes, why = Portal.threatened({ x = 0, z = 0, siluetaLevel = "Chase" }, now)
		equal(yes, true); equal(why, "Silueta", "reason")
		equal(Portal.threatened(nil, now), false, "no signals")
		equal(Portal.threatened({ x = 0, z = 0, beastEngagedAt = "soon" }, now), false, "bad stamp")
	end)

	case("PT-8: three stations, the Caramelo arch, the forest and the kitten park, outside every safe zone, the forest one far from La Silueta", function()
		-- Deliberately changed (K-D3, Pueblo Gatito, owner request 2026-11-17 "un parque verde lindo con las criaturas
		-- gatitas"): a third station, "parque", in Caramelo Este (2 -> 3); see PT-K1.
		equal(#Portal.STATIONS, 3, "three stations")
		local byId = {}
		for _, s in ipairs(Portal.STATIONS) do byId[s.id] = s end
		local candy, forest = byId.caramelo, byId.bosque
		assert(candy and forest, "caramelo and bosque")
		equal(candy.source, "candy", "the Candy builder places the Caramelo arch")
		equal(forest.source, "build", "the service builds the forest station")
		near(candy.x, Layout.CENTRE.x + Layout.PORTAL.x, "caramelo x = layout Portal marker")
		near(candy.z, Layout.CENTRE.z + Layout.PORTAL.z, "caramelo z")
		equal(Biomes.has(candy.x, candy.z, "Meadow"), true, "caramelo in the candy plot")
		equal(Biomes.has(forest.x, forest.z, "Forest"), true, "bosque in the forest")
		for _, s in ipairs(Portal.STATIONS) do
			local _, safe = Rules.zone(s.x, s.z)
			equal(safe, false, s.id .. " outside every safe zone")
			assert(Rules.distance(s.x, s.z, Rules.HUB_X, Rules.HUB_Z) >= 300, s.id .. " far from the hub")
		end
		-- CG2 (F4, decision 49): the forest arch stands away from La Silueta's home, outside her fog, on clear floor.
		assert(Rules.distance(forest.x, forest.z, Rules.HOME_X, Rules.HOME_Z) >= 120, "bosque at least 120 studs from her home")
		equal((Rules.zone(forest.x, forest.z)), false, "bosque outside the deep fog")
		equal(Portal.station("bosque"), forest, "lookup"); equal(Portal.station("nope"), nil, "unknown")
		assert(table.isfrozen(Portal.STATIONS), "frozen")
	end)

	-- K-D3 (Pueblo Gatito, docs/design/wildbound-kitten-park-plan.md): the kitten park's return station, built by the
	-- service in Caramelo Este (CandyEast), far from the hub, outside every safe zone, on the park floor, walked through
	-- along world z; a carrier is still refused there (Portal.CARRY, decision 47).
	-- Deliberately changed (PGM-D4, owner request 2026-11-18 "Sí, movelo"): the park moved to the big4 south arm; the
	-- station is park-local (-228, 43) with local yaw 90, world (239, 372) with yaw 0 (was x 980, z 40, yaw 90)
	case("PT-K1: the parque station stands in Pueblo Gatito, built, yaw 0 at y 0.5, far from the hub, outside every safe zone", function()
		local park = Portal.station("parque")
		assert(park, "no parque station")
		assert(table.isfrozen(park), "frozen")
		equal(park.source, "build", "the service builds it")
		near(park.x, 239, "x"); near(park.z, 372, "z")
		near(park.y, 0.5, "on the park floor (top 0.5)"); equal(park.yaw, 0, "walked through along world z")
		-- PGM-D1: the park frame, world(lx, lz) = (282 - lz, 600 + lx): local (-228, 43), yaw 90 - 90 = 0
		near(park.z - 600, -228, "park-local lx"); near(282 - park.x, 43, "park-local lz")
		local shared = game:GetService("ReplicatedStorage"):FindFirstChild("WildboundGatitoArea")
		if shared then
			local Area = require(shared)
			local ax, az = Area.world(-228, 43)
			near(park.x, ax, "Area.world x"); near(park.z, az, "Area.world z")
			equal(park.yaw, Area.worldYaw(90), "Area.worldYaw(90)"); near(park.y, Area.FLOOR_TOP, "Area.FLOOR_TOP")
		end
		equal(Biomes.has(park.x, park.z, "CandyEast"), true, "parque in Pueblo Gatito (CandyEast)")
		equal(Biomes.has(park.x, park.z, "Meadow"), false, "never in the candy plot")
		local _, safe = Rules.zone(park.x, park.z)
		equal(safe, false, "parque outside every safe zone")
		assert(Rules.distance(park.x, park.z, Rules.HUB_X, Rules.HUB_Z) >= 300, "parque far from the hub")
		equal(Portal.CARRY, "refuse", "a carrier is still refused (decision 47)")
	end)

	case("PT-9: CG2 (decision 47): a player carrying an egg cannot use a portal", function()
		equal(Portal.CARRY, "refuse", "carry rule")
		local st = Portal.new()
		local ok, reason = Portal.request(st, ready({ carrying = true }), 0)
		equal(ok, false, "a carrier is refused"); equal(reason, "Carrying", "reason")
		equal(st.channel, nil, "no channel")
		equal(Portal.request(st, ready({ carrying = false }), 0), true, "empty arms may use it")
	end)

	case("PT-11: CH1 (decision 53): a beast only calm or present is no threat; noticing, chasing or attacking is", function()
		assert(type(Portal.engaging) == "function", "Portal.engaging exists")
		-- Present but not on the player: the Nube drifting at its pond, a sleeping or patrolling guardian, a hive guard,
		-- a beast walking home, an encounter winding down.
		for _, phase in ipairs({ "Spawn", "Calm", "Dormant", "Patrol", "Guard", "Wake", "Return", "Disengage", "Ended" }) do
			equal(Portal.engaging(phase), false, phase .. " is calm")
			equal(Portal.CALM_PHASES[phase], true, phase .. " listed")
		end
		-- On the player: every phase that noticed, follows, telegraphs, strikes or recovers from a strike.
		for _, phase in ipairs({ "Notice", "Chase", "Telegraph", "Recover", "Stalk", "Pursue", "Watch", "Presence",
			"Suspicious", "Heard", "Search", "Attack", "Charge", "Snap", "Pulse", "Stunned" }) do
			equal(Portal.engaging(phase), true, phase .. " engages")
		end
		-- Fail safe: a phase a future beast adds counts as a threat until it is listed as calm.
		equal(Portal.engaging("SomeNewPhase"), true, "an unknown phase engages")
		equal(Portal.engaging(nil), false, "no phase"); equal(Portal.engaging(12), false, "not a phase name")
		assert(table.isfrozen(Portal.CALM_PHASES), "frozen")
		-- The portal then sees only the engaging beasts' stamps: a Calm Nube near the arch writes none, so the calm clock
		-- runs and the channel opens; a Nube that noticed the player stamps and the portal refuses Threat.
		local st = Portal.new()
		local stamp = nil
		for t = 0, 6, 0.5 do
			if Portal.engaging("Calm") then stamp = t end
			if Portal.threatened({ x = 0, z = 0, beastEngagedAt = stamp }, t) then Portal.noteThreat(st, t) end
		end
		equal((Portal.request(st, ready(), 6)), true, "a Calm beast near the arch lets the channel open")
		st = Portal.new()
		stamp = nil
		for t = 0, 6, 0.5 do
			if Portal.engaging("Notice") then stamp = t end
			if Portal.threatened({ x = 0, z = 0, beastEngagedAt = stamp }, t) then Portal.noteThreat(st, t) end
		end
		local ok, reason = Portal.request(st, ready(), 6)
		equal(ok, false, "a noticing beast"); equal(reason, "Threat", "refused as a threat")
	end)

	case("PT-10: pure: no services, no instances, no clock", function()
		local src = sources.portal
		for _, banned in ipairs({ "GetService", "Instance.new", "os.clock", "tick()", "workspace", "task." }) do
			assert(not string.find(src, banned, 1, true), "uses " .. banned)
		end
	end)

	return result
end

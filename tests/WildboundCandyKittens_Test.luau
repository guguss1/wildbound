-- Invoke with require(freshTestClone)(require(freshBeastEncountersClone), require(freshBeastCandyCritterClone),
-- require(freshBeastConfigClone), require(freshPraderaSitesClone), require(freshCandySmartsClone),
-- require(freshBeastDirectorClone), require(freshBeastChaseClone), require(freshCandyNestsClone),
-- require(freshKittenParkClone), require(freshPortalClone), require(freshBiomesClone), { beasts = WildboundBeasts.Source,
-- client = WildboundBeastsClient.Source, resting = WildboundCandyRestingService.Source,
-- restingClient = WildboundCandyRestingClient.Source }).
-- Pueblo Gatito (docs/design/wildbound-kitten-park-plan.md, K-D4..K-D11; owner request 2026-11-17, "es como el mundo de
-- gatito: un parque verde lindo con las criaturas gatitas, juguetes como rollos de papel, hisopos, papel, bolsas, tiendas
-- de gatitos como que es su village, otra canción que tenga que ver más con gatitos, también tiene que haber huevos para
-- robar"): the four kittens of Caramelo Este (GatitoLanudo, GatitoGuerrero, GatitaBouquet, GatitoActually) are four rows
-- on the candy critters' one data-driven brain (WildboundBeastCandyCritter), summoned at eight park posts
-- (WildboundPraderaSites.EAST_FIXED) beside the park's nests. Pure, on the harness of WildboundBeastCandyCritter_Test: a
-- fake world with flat ground at y 0 and a target moved by the test; the wiring cases read the sources.
return function(Enc, Critter, Config, Sites, Smarts, Director, Chase, Nests, Park, Portal, Biomes, sources)
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
		assert(type(source) == "string" and source:find(needle, 1, true), (label or needle) .. " missing")
	end
	local function flat(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end

	-- The K-D5 sheet: attack kind, damage, chase, reach, tell, cooldown, push and slow, wake/sight/abandon/leash.
	local SHEET = {
		GatitoLanudo = { kind = "leap", damage = 8, chase = 21, range = 7, tell = 0.8, cooldown = 4, push = 6, slow = 0.8,
			slowSeconds = 2, wake = 40, sight = 36, abandon = 46, leash = 30, hex = "6FE3CF", post = "kittenPostK4",
			extra = "kittenPostK8" },
		GatitoGuerrero = { kind = "dash", damage = 10, chase = 21.5, range = 10, tell = 0.9, cooldown = 5.5, push = 8, slow = 0.75,
			slowSeconds = 2.5, wake = 40, sight = 36, abandon = 48, leash = 32, hex = "FF9F43", post = "kittenPostK1",
			extra = "kittenPostK5" },
		GatitaBouquet = { kind = "lob", damage = 7, chase = 20.5, range = 15, tell = 1.0, cooldown = 4.5, push = 5, slow = 0.8,
			slowSeconds = 2, wake = 42, sight = 38, abandon = 50, leash = 34, standOff = 9, hex = "FF8FB8", post = "kittenPostK2",
			extra = "kittenPostK6" },
		GatitoActually = { kind = "burst", damage = 9, chase = 20, range = 7, tell = 1.2, cooldown = 6.5, push = 6, slow = 0.75,
			slowSeconds = 2.5, wake = 38, sight = 34, abandon = 46, leash = 30, hex = "7FB8FF", post = "kittenPostK3",
			extra = "kittenPostK7" },
	}
	local NAMES = { "GatitoLanudo", "GatitoGuerrero", "GatitaBouquet", "GatitoActually" }
	-- The K-D7 table (world coordinates).
	local POSTS = {
		kittenPostK1 = { 1038, -46 }, kittenPostK2 = { 1043, 104 }, kittenPostK3 = { 1143, -53 }, kittenPostK4 = { 1158, 55 },
		kittenPostK5 = { 1228, -61 }, kittenPostK6 = { 1243, 60 }, kittenPostK7 = { 1358, -111 }, kittenPostK8 = { 1358, 105 },
	}
	-- The second space (WildboundCandyEast plan) and the cloud wall's Collider (centre x 940, face at 938, margin 8).
	local SPACE = { minX = 948, maxX = 1468, minZ = -263, maxZ = 257 }
	local WALL = { x = 940, margin = 8 }
	local FAR = 70 -- a target this far from home is never seen
	for _, name in ipairs(NAMES) do
		if Config.WAVE2[name] or Config.SUMMONED[name] then Enc.register(name, Critter) end
	end

	local function fakeWorld()
		local w = { telegraphs = {}, cancelled = {} }
		function w.ground() return 0 end
		function w.site() return nil end
		function w.telegraph(id) table.insert(w.telegraphs, id); return true end
		function w.resolve() return "Hit" end
		function w.cancel(id) table.insert(w.cancelled, id) end
		return w
	end
	local function target(x, z, extra)
		local tgt = { x = x, y = 3, z = z, vx = 0, vz = 0, alive = true, safe = false }
		for k, v in pairs(extra or {}) do tgt[k] = v end
		return tgt
	end
	local function run(e, w, tgt, from, to, move, watch)
		local all = {}
		for i = 0, math.floor((to - from) / 0.05 + 1e-6) do
			local t = from + i * 0.05
			if move then move(t, tgt, e) end
			if not e.done then
				for _, ev in ipairs(Enc.step(e, t, tgt, w)) do table.insert(all, ev) end
			end
			if watch then watch(t, e) end
		end
		return all
	end
	local function each(events, kind)
		local list = {}
		for _, ev in ipairs(events) do if ev.type == kind then table.insert(list, ev) end end
		return list
	end
	local function phases(events)
		local list = {}
		for _, ev in ipairs(each(events, "Phase")) do table.insert(list, ev.phase) end
		return table.concat(list, ",")
	end
	local function spawn(name, id, x, z) return Enc.new(name, name .. ":" .. id, 1, 0, { x = x or 0, y = 0, z = z or 0 }) end
	local function tuning(name) return Config.BEASTS[name].tuning end
	-- The distance a target stands at so the kitten notices it and attacks from where it stands.
	local function close(name)
		local T = tuning(name)
		return math.min(T.Attack.RangeStuds, T.PerceptionStuds) - 1
	end
	-- A kitten that noticed a target standing at close(name), stepped until its first tell.
	local function telegraphing(name, id)
		local e, w, tgt = spawn(name, id), fakeWorld(), target(close(name), 0)
		local events = run(e, w, tgt, 0, 1.5)
		local tell = each(events, "Tell")[1]
		assert(tell, name .. ": no tell after noticing a target in range (phases " .. phases(events) .. ")")
		return e, w, tgt, events, tell
	end
	local function mainTell(ev, A) return string.find(ev.tell, ":" .. A.kind .. ":", 1, true) ~= nil end

	-- KK1 (K-D4, K-D5): four summoned guardians of Caramelo Este on the critters' brain, light hurt, the egg kept.
	case("KK1 config: four summoned CandyEast guardians, never rolled, 5 s rest, chase 16..23.2, fair tells, light hurt", function()
		equal(Config.NO_GLOBAL_BIOMES.CandyEast, true, "K-D10: no Global beast in Caramelo Este")
		equal(Config.NO_GLOBAL_BIOMES.Meadow, true, "the Pradera rule stays")
		for _, name in ipairs(NAMES) do
			local C, sheet = Config.BEASTS[name], SHEET[name]
			assert(C, "no " .. name .. " entry in WildboundBeastConfig")
			assert(not string.find(name, "_", 1, true), name .. ": no underscore (RestingPost_<name>_<post>)")
			local T, A = C.tuning, C.tuning.Attack
			assert(table.isfrozen(C) and table.isfrozen(T) and table.isfrozen(A), name .. " frozen")
			equal(C.category, "Guardian", name); equal(C.biome, "CandyEast", name); equal(Config.homeBiome(name), "CandyEast", name)
			equal(C.points, 0, name); equal(C.chance, 0, name); equal(C.chance10, 0, name); equal(C.riskModifier, 1, name)
			equal(Config.SUMMONED[name], true, name .. " summoned"); equal(Config.WAVE2[name], true, name .. " behaviour module")
			equal(Config.PLAYABLE[name], nil, name .. " never rolled")
			for _, other in ipairs(Config.ORDER) do assert(other ~= name, name .. " in ORDER") end
			equal(C.cooldown, 5, name .. " species rest (SUMMONED_REST)")
			equal(C.keepsEgg, true, name .. " keeps the egg"); equal(C.grounded, true, name .. " walks")
			equal(C.hitHeight, 8, name); near(C.disengage, 0.9, name)
			equal(C.damage, sheet.damage, name .. " damage")
			assert(C.damage >= 7 and C.damage <= 10, name .. " damage outside 7..10")
			equal(A.kind, sheet.kind, name .. " attack kind"); equal(A.RangeStuds, sheet.range, name .. " range")
			near(A.TelegraphSeconds, sheet.tell, name .. " tell"); near(A.CooldownSeconds, sheet.cooldown, name .. " cooldown")
			near(T.ChaseSpeedStudsPerSecond, sheet.chase, name .. " chase")
			assert(T.ChaseSpeedStudsPerSecond > 16 and T.ChaseSpeedStudsPerSecond < 23.2, name .. " chase outside walk..run")
			equal(T.WakeRadiusStuds, sheet.wake, name .. " wake"); equal(T.PerceptionStuds, sheet.sight, name .. " sight")
			equal(T.AbandonStuds, sheet.abandon, name .. " abandon"); equal(T.LeashStuds, sheet.leash, name .. " leash")
			equal(T.StandOffStuds, sheet.standOff, name .. " stand-off")
			equal(T.EscapeDistanceStuds, 90, name); equal(T.EscapeSeconds, 2, name); near(T.GiveUpSeconds, 4.5, name)
			equal(T.IdleSeconds, 25, name)
			assert(T.PerceptionStuds < T.WakeRadiusStuds and T.PerceptionStuds < T.AbandonStuds, name .. " sight inside wake and abandon")
			assert(T.PatrolRadiusStuds <= T.LeashStuds, name .. " patrols inside its leash")
			-- the tell: at least MIN_TELL from its start to the strike and from its lock to the strike
			assert(A.TelegraphSeconds >= Config.MIN_TELL, name .. " telegraph under MIN_TELL")
			assert(Critter.tellSeconds(A) >= Config.MIN_TELL, name .. " tell under the fairness floor")
			local lock = A.kind == "burst" and 0 or A.LockSeconds
			assert(Critter.tellSeconds(A) + A.TravelSeconds - lock >= Config.MIN_TELL - 1e-9, name .. " locks too late")
			-- the slows stay inside the server's caps (WildboundBeastChase.EFFECTS)
			assert(type(Chase) == "table" and type(Chase.EFFECTS) == "table", "no WildboundBeastChase given")
			near(A.SlowMultiplier, sheet.slow, name .. " slow"); near(A.SlowSeconds, sheet.slowSeconds, name .. " slow seconds")
			assert(A.SlowSeconds <= Chase.EFFECTS.slowMaxSeconds, name .. " slow past the server's cap")
			assert(A.SlowMultiplier >= Chase.EFFECTS.slowMinMultiplier and A.SlowMultiplier < 1, name .. " slow multiplier")
			equal(A.PushStuds, sheet.push, name .. " push"); assert(A.PushSeconds > 0 and A.PushSeconds <= 0.5, name .. " a quick shove")
			-- never the Gato's golden order or its helper call (the server writes their text)
			local X = T.Extras or {}
			equal(X.Gift, nil, name .. " Gift"); equal(X.Call, nil, name .. " Call")
		end
		local F = tuning("GatitoLanudo").Extras.Follow
		assert(F and table.isfrozen(F), "Lanudo bounces like yarn (Extras.Follow)")
		equal(F.Max, 1, "one more bounce"); equal(F.RangeStuds, 9, "follow range")
		assert(F.RangeStuds >= tuning("GatitoLanudo").Attack.PushStuds, "a bounce reaches a target its hop just pushed")
		equal(tuning("GatitoGuerrero").Attack.LengthStuds, 13, "Guerrero's lane"); near(tuning("GatitoGuerrero").Attack.WidthStuds, 4.5)
		near(tuning("GatitaBouquet").Attack.RadiusStuds, 4.5, "Bouquet's petals"); equal(tuning("GatitoActually").Attack.RadiusStuds, 9)
	end)

	-- KK2: each kitten patrols its post, notices, chases, telegraphs fairly, hits with a slow and a push, then rests.
	case("KK2 behaviour: patrol and calm at the post, Notice then Chase, a fair tell, a hit with slow and push, the cooldown", function()
		for _, name in ipairs(NAMES) do
			local T, A, sheet = tuning(name), tuning(name).Attack, SHEET[name]
			-- the patrol walks and pauses round its post, never past its patrol radius; every idle phase is calm
			local e, w, tgt = spawn(name, "loop"), fakeWorld(), target(FAR, 0)
			local farthest = 0
			local idle = run(e, w, tgt, 0, 14, nil, function(_, c) farthest = math.max(farthest, math.sqrt(c.pos.x ^ 2 + c.pos.z ^ 2)) end)
			assert(string.find(phases(idle), "Patrol,Calm,Patrol", 1, true), name .. " phases " .. phases(idle))
			assert(farthest <= T.PatrolRadiusStuds + 1e-6, name .. " wandered " .. farthest .. " studs from home")
			for _, ev in ipairs(each(idle, "Phase")) do equal(Portal.CALM_PHASES[ev.phase], true, name .. " idle phase " .. ev.phase) end
			-- a target at its perception: Notice, then Chase after AlertSeconds
			local n, nw, nt = spawn(name, "notice"), fakeWorld(), target(T.PerceptionStuds + T.PatrolRadiusStuds + 2, 0)
			run(n, nw, nt, 0, 0.5)
			assert(n.phase == "Patrol" or n.phase == "Calm", name .. " noticed a target outside its perception")
			nt.x, nt.z = n.pos.x + T.PerceptionStuds - 0.5, n.pos.z
			local list = each(run(n, nw, nt, 0.55, 0.55 + T.AlertSeconds + 0.2), "Phase")
			equal(list[1] and list[1].phase, "Notice", name)
			equal(list[2] and list[2].phase, "Chase", name)
			near(list[2].at - list[1].at, T.AlertSeconds, name .. " alert time")
			-- the tell: at least MIN_TELL before the strike, locked at least MIN_TELL before it, of the right shape
			local a, aw, at, events, tell = telegraphing(name, "tell")
			assert(tell.strikeAt - tell.startAt >= Config.MIN_TELL - 1e-9, name .. " strikes " .. (tell.strikeAt - tell.startAt) .. " s after the tell")
			local later = run(a, aw, at, 1.55, tell.strikeAt + 0.1)
			local lock
			for _, list2 in ipairs({ events, later }) do
				for _, ev in ipairs(each(list2, "Tell")) do if ev.locked == true then lock = lock or ev end end
			end
			assert(lock, name .. " never locked its tell")
			assert(tell.strikeAt - lock.at >= Config.MIN_TELL - 1e-9, name .. " locks " .. (tell.strikeAt - lock.at) .. " s before the strike")
			local shape = tell.shape
			if A.kind == "dash" then
				equal(shape.kind, "lane", name); near(shape.dx, 1, name .. " toward the target"); equal(shape.width, A.WidthStuds, name)
			else
				equal(shape.kind, "circle", name); equal(shape.r, A.RadiusStuds, name .. " radius")
				near(shape.x, A.kind == "burst" and 0 or close(name), name .. (A.kind == "burst" and " round itself" or " on the target"))
			end
			-- the hit: its damage, the slow and the push of the sheet
			local hits = {}
			for _, list2 in ipairs({ events, later }) do for _, ev in ipairs(each(list2, "Hit")) do table.insert(hits, ev) end end
			equal(#hits, 1, name .. " hits")
			local hit = hits[1]
			near(hit.at, tell.strikeAt, name .. " hit time"); equal(hit.damage, sheet.damage, name .. " damage")
			near(hit.slow.multiplier, sheet.slow, name .. " slow"); near(hit.slow.seconds, sheet.slowSeconds, name .. " slow time")
			assert(hit.push and hit.push.studs > 0, name .. " the hit does not push")
			equal(hit.push.studs, sheet.push, name .. " push studs")
			equal(hit.knock, nil, name); equal(hit.mark, nil, name); equal(hit.sticky, nil, name)
			-- the cooldown: the next attack of its own kind waits CooldownSeconds after the strike (Lanudo's one bounce
			-- comes right after the recovery first, then the cooldown)
			local F = T.Extras and T.Extras.Follow
			local rest = run(a, aw, at, tell.strikeAt + 0.15, tell.strikeAt + A.CooldownSeconds + 12)
			local mine, seen = { tell }, { [tell.tell] = true }
			for _, ev in ipairs(each(rest, "Tell")) do
				if mainTell(ev, A) and not seen[ev.tell] then seen[ev.tell] = true; table.insert(mine, ev) end
			end
			local follow = F and F.Max or 0
			assert(#mine >= follow + 2, name .. " only " .. #mine .. " attacks")
			for i = 2, follow + 1 do
				local gap = mine[i].startAt - mine[i - 1].strikeAt
				assert(gap >= A.RecoverSeconds - 1e-6 and gap <= A.RecoverSeconds + 0.2, name .. " bounce " .. (i - 1) .. " came " .. gap .. " s after")
			end
			local gap = mine[follow + 2].startAt - mine[follow + 1].strikeAt
			assert(gap >= A.CooldownSeconds - 1e-6, name .. " attacked again " .. gap .. " s after the strike")
		end
	end)

	-- KK3 (K-D6, the RC1 pattern of WildboundCandySmarts_Test): a kitten's hunt keeps to a zone of 60 round its post.
	case("KK3 zone: a hunt ends with a walk home just past its zone of 60; relentless; the sprint gains under 15 studs", function()
		local R = Smarts.RELENTLESS
		for _, name in ipairs(NAMES) do
			local T, P = tuning(name), Smarts.profile(name)
			assert(Smarts.PROFILES[name], name .. " has no Smarts.PROFILES row")
			assert(P.relentless == true, name .. " is not relentless")
			equal(P.zone, 60, name .. " zone"); equal(P.guard, 24, name .. " guard"); near(P.sprintSeconds, 1.5, name)
			assert(P.sprint > T.ChaseSpeedStudsPerSecond, name .. " sprint over its chase")
			assert((P.sprint - 23.2) * P.sprintSeconds < 15, name .. " sprint gain " .. (P.sprint - 23.2) * P.sprintSeconds)
			assert(P.zone < R.fadeStuds, name .. ": past its zone it walks home, never fades")
			local e, w, tgt = spawn(name, "zone"), fakeWorld(), target(8, 0)
			run(e, w, tgt, 0, 1)
			assert(Smarts.hunting(e), name .. " does not hunt after noticing")
			local endX
			for i = 1, 600 do
				local t = 1 + i * 0.05
				tgt.x, tgt.vx = 8 + (t - 1) * 20, 20
				local events = Enc.step(e, t, tgt, w)
				local back = false
				for _, ev in ipairs(events) do if ev.type == "Phase" and ev.phase == "Return" then back = true end end
				if back then endX = e.pos.x break end
				assert(#each(events, "End") == 0 and #each(events, "Disengage") == 0, name .. " ended before its zone")
			end
			assert(endX, name .. " never let go")
			assert(endX > math.max(T.AbandonStuds, T.LeashStuds), name .. " let go inside its old leash at " .. endX)
			assert(endX > P.zone and endX <= P.zone + 12, name .. " let go at " .. endX .. " (zone " .. P.zone .. ")")
		end
	end)

	-- KK4 (V8-D3 wall, K-D7): a kitten never crosses the cloud wall west of the park (the server clamps every step).
	case("KK4 wall: a kitten chasing west from (960, -3) stays at x >= 948", function()
		local x, z = Smarts.outsideWall(950, -3, 900, -3, { x = 940 })
		near(x, 948, "a step from (950, -3) toward x 900 stops at the wall plus its margin"); near(z, -3, "z is never changed")
		near((Smarts.outsideWall(1000, -3, 930, -3, WALL)), 948, "from the east")
		for _, name in ipairs(NAMES) do
			local e, w = spawn(name, "wall", 960, -3), fakeWorld()
			local tgt = target(930, -3)
			local least = math.huge
			for i = 0, 160 do
				local t = i * 0.05
				local px, pz = e.pos.x, e.pos.z
				if not e.done then Enc.step(e, t, tgt, w) end
				e.pos.x, e.pos.z = Smarts.outsideWall(px, pz, e.pos.x, e.pos.z, WALL) -- as world.keepOut does
				least = math.min(least, e.pos.x)
			end
			assert(least >= 948 - 1e-9, name .. " reached x " .. least)
		end
	end)

	-- KK5 (K-D7, K-D11): the eight posts, their wake rule, their spacing and their reach inside the space.
	case("KK5 sites: eight fixed kitten posts, the wake rule and the frenzy, inside the space, 85 apart, agreeing with the park", function()
		assert(type(Sites.EAST_FIXED) == "table" and table.isfrozen(Sites.EAST_FIXED), "Sites.EAST_FIXED frozen")
		assert(type(Sites.EAST_EXTRA_POSTS) == "table" and table.isfrozen(Sites.EAST_EXTRA_POSTS), "Sites.EAST_EXTRA_POSTS frozen")
		local count = 0
		for key, p in pairs(Sites.EAST_FIXED) do
			count += 1
			local want = POSTS[key]
			assert(want, key .. " is not a K-D7 post")
			equal(Sites.FIXED[key], nil, key .. " stays out of FIXED")
			assert(string.match(key, "^%w+$"), key .. ": letters and digits only")
			local w, moved = Sites.world(nil, key), Sites.world({ x = 0, z = 0 }, key)
			near(w.x, want[1], key .. " x"); near(w.z, want[2], key .. " z"); near(p.x, want[1]); near(p.z, want[2])
			near(moved.x, w.x, key .. " never moves with the origin"); near(moved.z, w.z)
			equal(Biomes.has(w.x, w.z, "CandyEast"), true, key .. " in Caramelo Este"); equal(Biomes.has(w.x, w.z, "Meadow"), false, key)
		end
		equal(count, 8, "eight kitten posts")
		equal(#Sites.EAST_EXTRA_POSTS, 4, "one east extra post per kitten")
		local extraOf = {}
		for _, extra in ipairs(Sites.EAST_EXTRA_POSTS) do
			assert(table.isfrozen(extra), "frozen row")
			assert(SHEET[extra.name], tostring(extra.name) .. " is not a kitten")
			assert(not extraOf[extra.name], extra.name .. " has two east extra posts"); extraOf[extra.name] = extra.key
		end
		-- every post: the wake radius, death, a safe zone, outside the biome, the frenzy's call
		local all = {}
		for _, name in ipairs(NAMES) do
			local sheet, T = SHEET[name], tuning(name)
			equal(Sites.HOME[name], sheet.post, name .. " home post"); equal(extraOf[name], sheet.extra, name .. " east extra post")
			for _, key in ipairs({ sheet.post, sheet.extra }) do
				local w = Sites.world(nil, key)
				table.insert(all, { key = key, x = w.x, z = w.z, name = name })
				local post = key ~= sheet.post and key or nil
				local function wants(dx, more)
					local c = { alive = true, safe = false, meadow = true, x = w.x + dx, z = w.z }
					for k, v in pairs(more or {}) do c[k] = v end
					return Sites.wants(name, c, post)
				end
				equal(wants(T.WakeRadiusStuds - 1), true, key .. " 1 stud inside the wake radius")
				equal(wants(T.WakeRadiusStuds + 1), false, key .. " 1 stud outside the wake radius")
				equal(wants(0, { alive = false }), false, key .. " for a dead player"); equal(wants(0, { safe = true }), false, key .. " safe")
				equal(wants(0, { meadow = false }), false, key .. " outside a summoning biome")
				equal(wants(T.WakeRadiusStuds + 60, { frenzy = { x = w.x + 100, z = w.z, studs = 150 } }), true, key .. " a frenzy within 150")
				equal(wants(T.WakeRadiusStuds + 60, { frenzy = { x = w.x + 151, z = w.z, studs = 150 } }), false, key .. " a frenzy out of reach")
				-- the reach: a hunt (zone + 12), its attack and its push stay off the void edges by 10, and west of it the
				-- wall clamp line (948, the Collider's face 938 plus its margin side) is never passed
				local A = T.Attack
				local reach = Smarts.profile(name).zone + 12 + A.RangeStuds + A.PushStuds
				assert(w.x + reach <= SPACE.maxX - 10, key .. " reaches the east edge")
				assert(w.z + reach <= SPACE.maxZ - 10 and w.z - reach >= SPACE.minZ + 10, key .. " reaches a north or south edge")
				assert(w.x - reach >= WALL.x + WALL.margin, key .. " reaches past the wall clamp (" .. (w.x - reach) .. ")")
				assert(w.x - 84 >= 938, key .. " two wake circles from the Collider's face")
				assert(w.x >= 1038 and w.x <= 1388 and math.abs(w.z + 3) <= 180, key .. " outside the K-D7 window")
			end
		end
		equal(#all, 8, "posts in all")
		for i = 1, #all do
			for j = i + 1, #all do
				local d = flat(all[i].x, all[i].z, all[j].x, all[j].z)
				assert(d >= 85, all[i].key .. " and " .. all[j].key .. " only " .. d .. " apart")
			end
		end
		-- With Set A: the park's nest table (WildboundKittenPark.NESTS) agrees with the posts and the guards
		assert(type(Park) == "table" and type(Park.NESTS) == "table", "no WildboundKittenPark.NESTS given")
		equal(#Park.NESTS, 8, "eight park nests")
		local markers = {}
		for _, nest in ipairs(Park.NESTS) do
			local key = nest.post and nest.post.key
			local fixed = key and Sites.EAST_FIXED[key]
			assert(fixed, nest.id .. ": post " .. tostring(key) .. " is not in EAST_FIXED")
			near(nest.post.x, fixed.x, nest.id .. " post x"); near(nest.post.z, fixed.z, nest.id .. " post z")
			near(flat(nest.x, nest.z, fixed.x, fixed.z), 12, nest.id .. " post 12 studs from its nest", 0.01)
			assert(type(nest.guard) == "string", nest.id .. " has no guard string")
			local name, extra = string.match(nest.guard, "^(%w+)@(%w+)$")
			if name then
				equal(extra, key, nest.id .. " guard names its own post")
				equal(extraOf[name], key, nest.id .. " guard is an EAST_EXTRA_POSTS row")
			else
				assert(string.match(nest.guard, "^%w+$"), nest.id .. " guard " .. tostring(nest.guard))
				equal(Sites.HOME[nest.guard], key, nest.id .. " guard's home post")
			end
			table.insert(markers, { id = nest.id, rarity = nest.rarity, x = nest.x, z = nest.z, top = 2.7, enabled = true,
				park = true, guard = nest.guard })
		end
		-- and the server's island list keeps those guards and pays one tier more (WildboundCandyNests, K-D8, K-D9)
		local islands = Nests.islands(markers, Nests.posts(Sites))
		equal(#islands, 8, "every park nest becomes an island nest")
		for _, entry in ipairs(islands) do
			local nest
			for _, n in ipairs(Park.NESTS) do if Nests.ID_PREFIX .. n.id == entry.id then nest = n end end
			assert(nest, entry.id .. " is not a park nest")
			equal(entry.guard, nest.guard, entry.id .. " guard"); equal(entry.park, true, entry.id .. " park")
			equal(entry.rewardTier, Nests.PARK_POOL[nest.rarity].rewardTier, entry.id .. " pay")
		end
	end)

	-- KK6 (K-D10): the director keeps the kittens in Caramelo Este and every other set out of it.
	case("KK6 director: kittens only in CandyEast; Mochimiau refused there (Biome), Viper too (NoGlobalZone); an east post books", function()
		local function ctx(biomes)
			return { alive = true, safe = false, night = false, respawnedAt = -1000, biomes = biomes }
		end
		local function always(value) return function() return value end end
		for _, name in ipairs(NAMES) do
			local dir = Director.new({ random = always(0) })
			local ok, why = Director.summon(dir, 1, name, ctx({ CandyEast = true }), 0)
			equal(ok, true, name .. " accepted in Caramelo Este (" .. tostring(why) .. ")")
			equal(select(2, Director.summon(dir, 2, name, ctx({ Meadow = true }), 0)), "Biome", name .. " refused in the plot")
			equal(Director.placeBlock(name, ctx({ CandyEast = true })), nil, name)
		end
		equal(select(2, Director.summon(Director.new({ random = always(0) }), 1, "Mochimiau", ctx({ CandyEast = true }), 0)), "Biome",
			"a plot critter never in the park")
		equal(Director.placeBlock("Viper", ctx({ CandyEast = true })), "NoGlobalZone", "no Global beast in the park")
		equal(select(2, Director.reserve(Director.new({ random = always(0) }), 1, "Viper", ctx({ CandyEast = true }), 0, { force = true })),
			"NoGlobalZone", "even forced")
		local dir = Director.new({ random = always(0) })
		local ok, enc = Director.alarm(dir, 1, "GatitoGuerrero", ctx({ CandyEast = true }), 0, "kittenPostK5")
		assert(ok and type(enc) == "table", "the alarm for GatitoGuerrero@kittenPostK5 was refused: " .. tostring(enc))
		equal(enc.post, "kittenPostK5", "it books post kittenPostK5")
		assert(Director.uncapped("GatitoGuerrero"), "a kitten stands outside MAX_ACTIVE (points 0, summoned)")
	end)

	-- KK7: the wiring, by source (each hunk small and anchored, K-D11).
	case("KK7 wiring: KIDS rows, world.inCandy, the summon pass, the east posts, the resting copies and the tell colours", function()
		assert(type(sources) == "table", "no sources given")
		local beasts, client, resting, restingClient = sources.beasts, sources.client, sources.resting, sources.restingClient
		for _, name in ipairs(NAMES) do
			has(beasts, '{ name = "' .. name .. '", module = "WildboundBeastCandyCritter" }', name .. " KIDS row")
			has(resting, '"' .. name .. '"', name .. " resting service NAMES")
			has(restingClient, '"' .. name .. '"', name .. " resting client NAMES")
			has(client, name .. ' = Color3.fromHex("' .. SHEET[name].hex .. '")', name .. " TELL_COLOR")
		end
		assert(beasts:find('{ name = "GatitoActually", module = "WildboundBeastCandyCritter" }', 1, true)
			< beasts:find('{ name = "DonGlaseon", module = "WildboundBeastDonGlaseon", boss = true }', 1, true), "before the boss row")
		has(beasts, "function world.inCandy(", "world.inCandy")
		has(beasts, 'Biomes.has(x, z, "CandyEast")', "inCandy reads the CandyEast tag")
		assert(beasts:find("function world.inCandy(", 1, true) < beasts:find("local function targetOf(", 1, true), "defined before use")
		has(beasts, "meadow = world.inCandy(p.X, p.Z) }", "targetOf: a forest beast closes in the park")
		has(beasts, "meadow = inMeadow(", "the audience refresh keeps its meadow rule")
		has(beasts, "world.stealCheck(player, character, p, at, world.inCandy(p.X, p.Z))", "a park steal starts the frenzy")
		has(beasts, "if not world.inCandy(p.X, p.Z) then", "park players reach the KIDS loop")
		for label, source in pairs({ beasts = beasts, resting = resting }) do
			has(source, "for _, extra in ipairs(Sites.EXTRA_POSTS) do", label .. ": the plot's extra posts")
			has(source, "for _, extra in ipairs(Sites.EAST_EXTRA_POSTS) do", label .. ": the east extra posts")
			assert(source:find("for _, extra in ipairs(Sites.EXTRA_POSTS) do", 1, true)
				< source:find("for _, extra in ipairs(Sites.EAST_EXTRA_POSTS) do", 1, true), label .. ": after the plot's loop")
		end
		local _, summons = beasts:gsub("Director%.summon%(director, player%.UserId, extra%.name, ctx, at, { post = extra%.key }%)", "")
		equal(summons, 2, "both extra-post loops summon one per post")
		local _, starts = beasts:gsub("world%.startAtPost%(player, value, extra%.key, p%.Y, at%)", "")
		equal(starts, 2, "both start on the ground at the post")
		has(resting, "Candy_Este_v1", "the resting rays hit the park floor")
		has(resting, 'root:SetAttribute("RestingPost_" .. extra.name .. "_" .. extra.key', "published as RestingPost_<name>_<post>")
		has(resting, "Sites.world(nil, Sites.HOME[name])", "the post is the beast's own home site")
		for _, source in ipairs({ beasts, client, resting, restingClient }) do
			assert(not source:find("SistemaSonriente", 1, true), "a kitten script names SistemaSonriente")
		end
	end)

	return result
end

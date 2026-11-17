-- Invoke with require(freshTestClone)(require(freshBeastEncountersClone), require(freshBeastCandyCritterClone),
-- require(freshBeastConfigClone), require(freshPortalClone), { beasts = WildboundBeasts.Source,
-- service = WildboundCandyCritterService.Source, client = WildboundBeastsClient.Source,
-- resting = WildboundCandyRestingService.Source, restingClient = WildboundCandyRestingClient.Source,
-- server = WildboundServer.Source, cake = WildboundCandyCakeClient.Source, text = require(freshTextClone),
-- spec = require(freshCandyCritterAnimSpecClone) }, require(freshBeastChaseClone)).
-- Caramelo biome (odd/tasks/wildbound-candy-critters.md, CC1-CC3): the five small candy creatures (Mochimiau, Canelin,
-- Flanin, Mielita, GatoRepartidor) share one data-driven brain, WildboundBeastCandyCritter, which reads
-- Config.BEASTS[name].tuning (and its Attack table). Pure, on the harness of WildboundBeastGomibu_Test: a fake world with
-- flat ground at y 0 and a target moved by the test.
return function(Enc, Critter, Config, Portal, sources, Chase)
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

	-- The creature sheet: attack kind, cooldown and the outcome the brief asked for (push studs or nil, slow multiplier,
	-- slow seconds), and whether it flies.
	-- Deliberately changed (PF2, odd/tasks/wildbound-caramelo-playfix.md): every hit must read for a walking player, so
	-- each one now pushes 6-10 studs and slows to 0.7 (the Gato, the friendliest, 0.8) for 2-3 s.
	-- Deliberately changed (OF2, owner feedback 2, odd/tasks/wildbound-caramelo-playfix.md): they hurt (damage through
	-- BeastHit, the egg kept) and each has its own personality: chase speed, reach, cooldown, tell and damage. Canelin's
	-- attack is the owner's favourite and stays exactly as it was (only its damage is new).
	-- Deliberately changed (OF3, owner feedback 3): every base chase raised again (19-22, still under a running player's
	-- 23.2; the burst over it is WildboundCandySmarts' sprint).
	-- Deliberately changed (CH2, owner request 2026-11-16 "make them go faster"): about +2 each, still distinct and under
	-- 23.2: Mochimiau 21 -> 22.5, Canelin 20 -> 22, Flanin 19 -> 21.5, Mielita 22 -> 23, Gato 19.5 -> 21.8.
	-- Deliberately changed (CH5, owner request "do more damage"): each hit about +40-50 %, still under 35 (never a
	-- one-shot): Mochimiau 8 -> 12, Canelin 12 -> 17, Flanin 16 -> 23, Mielita 10 -> 14, Gato 9 -> 13.
	local SHEET = {
		Mochimiau = { kind = "leap", cooldown = 3.5, push = true, pushStuds = 8, slow = 0.7, slowSeconds = 2.5, flies = false,
			chase = 22.5, range = 7, tell = 0.8, damage = 12 },
		Canelin = { kind = "dash", cooldown = 6, push = true, pushStuds = 8, slow = 0.7, slowSeconds = 2.5, flies = false,
			chase = 22, range = 10, tell = 0.9, damage = 17 },
		Flanin = { kind = "burst", cooldown = 7, push = true, pushStuds = 6, slow = 0.7, slowSeconds = 3, radius = 10, flies = false,
			chase = 21.5, range = 7, tell = 1.2, damage = 23 },
		Mielita = { kind = "lob", cooldown = 5, push = true, pushStuds = 6, slow = 0.7, slowSeconds = 3, radius = 6, flies = true,
			chase = 23, range = 18, tell = 0.9, damage = 14, standOff = 10 },
		GatoRepartidor = { kind = "lob", cooldown = 4.5, pushStuds = 6, push = true, slow = 0.8, slowSeconds = 2, radius = 4,
			flies = false, chase = 21.8, range = 15, tell = 1, damage = 13, standOff = 8 },
	}
	local FAR = 70 -- a target this far from home is never seen, yet still inside its escape distance
	local NAMES = { "Mochimiau", "Canelin", "Flanin", "Mielita", "GatoRepartidor" }
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
		local tgt = { x = x, y = 3, z = z, alive = true, safe = false }
		for k, v in pairs(extra or {}) do tgt[k] = v end
		return tgt
	end
	local function run(e, w, tgt, from, to, move, watch)
		local all = {}
		for i = 0, math.floor((to - from) / 0.05 + 1e-6) do
			local t = from + i * 0.05
			if move then move(t, tgt, e) end
			for _, ev in ipairs(Enc.step(e, t, tgt, w)) do table.insert(all, ev) end
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
	local function spawn(name, id) return Enc.new(name, name .. ":" .. id, 1, 0, { x = 0, y = 0, z = 0 }) end
	local function tuning(name) return Config.BEASTS[name].tuning end
	-- The distance a target stands at so the creature notices it and attacks from where it stands.
	local function close(name)
		local T = tuning(name)
		return math.min(T.Attack.RangeStuds, T.PerceptionStuds) - 1
	end
	-- A creature that noticed a target standing at close(name), stepped until its first tell.
	local function telegraphing(name, id, move)
		local e, w, tgt = spawn(name, id), fakeWorld(), target(close(name), 0)
		local events = run(e, w, tgt, 0, 1.5, move)
		local tell = each(events, "Tell")[1]
		assert(tell, name .. ": no tell after noticing a target in range (phases " .. phases(events) .. ")")
		return e, w, tgt, events, tell
	end

	-- OF2 (owner feedback 2): a walking player (16) is caught, a running one (16 x 1.45 = 23.2) still gets away; every hit
	-- hurts a little (8-20 of 100, never a one-shot); no two creatures share a chase speed or a damage; Canelin's attack is
	-- byte for byte the old one.
	case("OF2: each creature has its own speed, reach, cooldown, tell and damage; Canelin's attack is unchanged", function()
		local speeds, damages = {}, {}
		for _, name in ipairs(NAMES) do
			local C, sheet = Config.BEASTS[name], SHEET[name]
			local T, A = C.tuning, C.tuning.Attack
			equal(T.ChaseSpeedStudsPerSecond, sheet.chase, name .. " chase")
			assert(sheet.chase > 16 and sheet.chase < 16 * 1.45, name .. " chase outside walk..run")
			equal(A.RangeStuds, sheet.range, name .. " range"); equal(A.TelegraphSeconds, sheet.tell, name .. " tell")
			equal(C.damage, sheet.damage, name .. " damage")
			assert(C.damage >= 8 and C.damage < 35, name .. " damage outside 8-34 (CH5: was 8-20)")
			equal(T.StandOffStuds, sheet.standOff, name .. " stand-off")
			assert(not speeds[sheet.chase], name .. " shares a chase speed"); speeds[sheet.chase] = true
			assert(not damages[C.damage], name .. " shares a damage"); damages[C.damage] = true
		end
		local A = Config.BEASTS.Canelin.tuning.Attack
		local was = { kind = "dash", RangeStuds = 10, TelegraphSeconds = 0.9, LockSeconds = 0.5, TravelSeconds = 0.6,
			LengthStuds = 14, WidthStuds = 5, RecoverSeconds = 0.7, CooldownSeconds = 6, PushStuds = 8, PushSeconds = 0.35,
			SlowMultiplier = 0.7, SlowSeconds = 2.5 }
		for k, v in pairs(was) do equal(A[k], v, "Canelin " .. k) end
		for k in pairs(A) do assert(was[k] ~= nil, "Canelin attack gained " .. k) end
		local Tr = Config.BEASTS.Canelin.tuning.Extras.Trail
		equal(Tr.Phase, "Release"); equal(Tr.SpacingStuds, 2.5); equal(Tr.SlowMultiplier, 0.8)
	end)

	-- OF2: a thrower stops StandOffStuds from its target and throws from there.
	case("OF2: Mielita and the Gato keep their distance and throw from there", function()
		for _, name in ipairs({ "Mielita", "GatoRepartidor" }) do
			local T = tuning(name)
			local e, w, tgt = spawn(name, "far"), fakeWorld(), target(30, 0)
			local nearest = math.huge
			local events = run(e, w, tgt, 0, 6, nil, function(_, c)
				if c.phase == "Chase" then nearest = math.min(nearest, math.sqrt((c.pos.x - tgt.x) ^ 2 + c.pos.z ^ 2)) end
			end)
			assert(nearest >= T.StandOffStuds - 0.05, name .. " came " .. nearest .. " studs close")
			assert(#each(events, "Hit") >= 1, name .. " never hit from its stand-off (phases " .. phases(events) .. ")")
		end
	end)

	case("CC1 config: five summoned guardians that keep the egg and are never rolled", function()
		equal(#Config.ORDER, 9, "ORDER keeps the rolled beasts only")
		for _, name in ipairs(NAMES) do
			local C, sheet = Config.BEASTS[name], SHEET[name]
			assert(C, "no " .. name .. " entry in WildboundBeastConfig")
			local T = C.tuning
			equal(Config.SUMMONED[name], true, name .. " summoned"); equal(Config.WAVE2[name], true, name .. " behaviour module")
			equal(Config.PLAYABLE[name], nil, name .. " never rolled")
			for _, other in ipairs(Config.ORDER) do assert(other ~= name, name .. " in ORDER") end
			equal(C.category, "Guardian", name); equal(C.biome, "Meadow", name); equal(C.chance, 0, name); equal(C.chance10, 0, name)
			equal(C.points, 0, name); equal(C.damage, sheet.damage, name .. " damage"); equal(C.keepsEgg, true, name .. " keepsEgg")
			equal(C.grounded, not sheet.flies, name .. " grounded")
			assert(type(C.hitHeight) == "number" and C.hitHeight > 0, name .. " hitHeight")
			assert(type(C.disengage) == "number" and C.disengage > 0, name .. " disengage")
			assert(table.isfrozen(C) and table.isfrozen(T) and table.isfrozen(T.Attack), name .. " frozen")
			equal(T.Attack.kind, sheet.kind, name .. " attack kind")
			equal(T.Attack.CooldownSeconds, sheet.cooldown, name .. " cooldown")
			assert(T.PatrolSpeedStudsPerSecond >= 5 and T.PatrolSpeedStudsPerSecond <= 8, name .. " patrol speed")
			-- OF2: faster than a walking player's 16, slower than a running one's 23.2 (was 11-15, PF2)
			assert(T.ChaseSpeedStudsPerSecond > 16 and T.ChaseSpeedStudsPerSecond < 23.2, name .. " chase speed")
			-- PF2 (walked Play: a moving player never triggered them): it sees about as far as it wakes, chases far,
			-- holds on a few seconds, and only a long run away ends it
			assert(T.WakeRadiusStuds >= 40 and T.WakeRadiusStuds <= 50, name .. " wake radius " .. T.WakeRadiusStuds)
			assert(T.PerceptionStuds >= T.WakeRadiusStuds - 8, name .. " perception " .. T.PerceptionStuds .. " far under its wake radius")
			assert(T.LeashStuds >= 30 and T.LeashStuds <= 40, name .. " leash " .. T.LeashStuds)
			assert(T.AbandonStuds >= 45 and T.AbandonStuds <= 55, name .. " abandon " .. T.AbandonStuds)
			assert(T.GiveUpSeconds >= 4 and T.GiveUpSeconds <= 5, name .. " give-up " .. T.GiveUpSeconds)
			assert(T.EscapeDistanceStuds >= 85 and T.EscapeDistanceStuds <= 95, name .. " escape " .. T.EscapeDistanceStuds)
			assert(T.PatrolRadiusStuds >= 8, name .. " patrols a visible loop round its post")
			assert(type(T.IdleSeconds) == "number" and T.IdleSeconds >= 15, name .. " idle timeout")
			assert(type(T.Attack.PushStuds) == "number" and T.Attack.PushStuds >= 6 and T.Attack.PushStuds <= 10, name .. " push 6-10")
			assert(T.Attack.SlowMultiplier <= 0.8 and T.Attack.SlowSeconds >= 2 and T.Attack.SlowSeconds <= 3, name .. " slow")
			assert(T.PerceptionStuds < T.AbandonStuds and T.PerceptionStuds < T.WakeRadiusStuds, name .. " sight inside wake and abandon")
			assert(T.PatrolRadiusStuds <= T.LeashStuds, name .. " patrols inside its leash")
			assert(Critter.tellSeconds(T.Attack) >= Config.MIN_TELL, name .. " tell under the fairness floor")
			-- the server clamps every slow (WildboundBeastChase.EFFECTS, applySlow): the sheet never asks for more
			assert(type(Chase) == "table" and type(Chase.EFFECTS) == "table", "no WildboundBeastChase given")
			assert(T.Attack.SlowSeconds <= Chase.EFFECTS.slowMaxSeconds, name .. " slow " .. T.Attack.SlowSeconds .. " s is past the server's " .. Chase.EFFECTS.slowMaxSeconds .. " s cap")
			assert(T.Attack.SlowMultiplier >= Chase.EFFECTS.slowMinMultiplier and T.Attack.SlowMultiplier < 1, name .. " slow multiplier outside the server's range")
		end
		-- the friendly one: short sight, short leash
		local gato = tuning("GatoRepartidor")
		for _, name in ipairs(NAMES) do
			if name ~= "GatoRepartidor" then
				assert(gato.PerceptionStuds < tuning(name).PerceptionStuds, "Gato sees less than " .. name)
				assert(gato.LeashStuds < tuning(name).LeashStuds, "Gato chases less far than " .. name)
			end
		end
		equal(tuning("Mielita").HoverStuds, 2.5, "Mielita hovers")
		equal(Config.BEASTS.DuquesaBurbuja, nil, "the Duquesa stays scenery: no brain")
		equal(Config.SUMMONED.DuquesaBurbuja, nil, "the Duquesa is never summoned")
	end)

	case("CC2: idle phases are the portal's calm phases; Notice, Chase and the attack phases are not", function()
		for _, phase in ipairs({ "Spawn", "Patrol", "Return", "Disengage", "Ended" }) do
			equal(Portal.CALM_PHASES[phase], true, phase .. " calm")
		end
		for _, phase in ipairs({ "Notice", "Chase", "Telegraph", "Release", "Recover", "GiveUp" }) do
			equal(Portal.CALM_PHASES[phase], nil, phase .. " engaging")
		end
		for _, name in ipairs(NAMES) do
			local e, w, tgt = spawn(name, "calm"), fakeWorld(), target(FAR, 0)
			local events = run(e, w, tgt, 0, 6)
			for _, ev in ipairs(each(events, "Phase")) do
				equal(Portal.CALM_PHASES[ev.phase], true, name .. " idle phase " .. ev.phase)
			end
			assert(e.phase == "Patrol" or e.phase == "Calm", name .. " patrols while nobody is near (" .. tostring(e.phase) .. ")")
		end
	end)

	-- PF2: the patrol reads: it walks ("Patrol", the walk clip) between points and stands ("Calm", the idle loop) at each.
	case("PF2: the patrol walks (Patrol) and pauses (Calm) in turn round its post", function()
		for _, name in ipairs(NAMES) do
			local e, w, tgt = spawn(name, "loop"), fakeWorld(), target(FAR, 0)
			local list = phases(run(e, w, tgt, 0, 14))
			assert(string.find(list, "Patrol,Calm,Patrol", 1, true), name .. " phases " .. list)
		end
	end)

	case("CC2: it wanders near home while calm, never past its patrol radius", function()
		for _, name in ipairs(NAMES) do
			local T = tuning(name)
			local e, w, tgt = spawn(name, "patrol"), fakeWorld(), target(FAR, 0)
			local farthest, moved = 0, 0
			local last = { x = 0, z = 0 }
			run(e, w, tgt, 0, 20, nil, function(_, c)
				farthest = math.max(farthest, math.sqrt(c.pos.x ^ 2 + c.pos.z ^ 2))
				moved += math.sqrt((c.pos.x - last.x) ^ 2 + (c.pos.z - last.z) ^ 2)
				last = { x = c.pos.x, z = c.pos.z }
			end)
			assert(moved > 2, name .. " never wandered (" .. moved .. " studs)")
			assert(farthest <= T.PatrolRadiusStuds + 1e-6, name .. " wandered " .. farthest .. " studs from home")
		end
	end)

	case("CC2: it notices a target inside its perception, alerts, then chases", function()
		for _, name in ipairs(NAMES) do
			local T = tuning(name)
			local e, w, tgt = spawn(name, "notice"), fakeWorld(), target(T.PerceptionStuds + T.PatrolRadiusStuds + 2, 0)
			run(e, w, tgt, 0, 0.5)
			assert(e.phase == "Patrol" or e.phase == "Calm", name .. " noticed a target outside its perception")
			tgt.x, tgt.z = e.pos.x + T.PerceptionStuds - 0.5, e.pos.z
			local events = run(e, w, tgt, 0.55, 0.55 + T.AlertSeconds + 0.2)
			local list = each(events, "Phase")
			equal(list[1] and list[1].phase, "Notice", name)
			equal(list[2] and list[2].phase, "Chase", name)
			near(list[2].at - list[1].at, T.AlertSeconds, name .. " alert time", 1e-6)
		end
	end)

	case("CC3: each attack has a fair tell (>= MIN_TELL before the strike and after the lock) and the right shape", function()
		for _, name in ipairs(NAMES) do
			local T, A = tuning(name), tuning(name).Attack
			local e, w, tgt, events, tell = telegraphing(name, "tell")
			assert(tell.strikeAt - tell.startAt >= Config.MIN_TELL - 1e-9, name .. " strikes " .. (tell.strikeAt - tell.startAt) .. " s after the tell")
			local lock
			for _, ev in ipairs(each(events, "Tell")) do if ev.locked == true then lock = lock or ev end end
			local later = run(e, w, tgt, 1.55, tell.strikeAt + 0.1)
			for _, ev in ipairs(each(later, "Tell")) do if ev.locked == true then lock = lock or ev end end
			assert(lock, name .. " never locked its tell")
			assert(tell.strikeAt - lock.at >= Config.MIN_TELL - 1e-9, name .. " locks " .. (tell.strikeAt - lock.at) .. " s before the strike")
			local shape = tell.shape
			if A.kind == "leap" or A.kind == "lob" then
				equal(shape.kind, "circle", name); near(shape.x, close(name), name .. " circle on the target"); near(shape.z, 0, name)
				equal(shape.r, A.RadiusStuds, name .. " radius")
			elseif A.kind == "burst" then
				equal(shape.kind, "circle", name); near(shape.x, 0, name .. " circle on itself"); near(shape.z, 0, name)
				equal(shape.r, A.RadiusStuds, name .. " radius")
			elseif A.kind == "dash" then
				equal(shape.kind, "lane", name); near(shape.ox, 0, name .. " lane from itself"); near(shape.dx, 1, name .. " toward the target")
				equal(shape.width, A.WidthStuds, name .. " width"); assert(shape.length >= close(name), name .. " lane too short")
			end
			if SHEET[name].radius then equal(A.RadiusStuds, SHEET[name].radius, name .. " sheet radius") end
			equal(shape.y or shape.oy, 0, name .. " the shape lies on the ground")
			local all = phases(events) .. "," .. phases(later)
			assert(string.find(all, "Telegraph,Release,Recover", 1, true), name .. " phases " .. all)
		end
	end)

	case("CC3: a target inside is slowed (and pushed when the sheet says so), with its damage and nothing else", function()
		for _, name in ipairs(NAMES) do
			local A, sheet = tuning(name).Attack, SHEET[name]
			local e, w, tgt, events, tell = telegraphing(name, "hit")
			local later = run(e, w, tgt, 1.55, tell.strikeAt + 0.1)
			local hits = {}
			for _, ev in ipairs(each(events, "Hit")) do table.insert(hits, ev) end
			for _, ev in ipairs(each(later, "Hit")) do table.insert(hits, ev) end
			equal(#hits, 1, name .. " hits")
			local hit = hits[1]
			near(hit.at, tell.strikeAt, name .. " hit time"); equal(hit.damage, sheet.damage, name .. " damage (OF2)")
			equal(hit.slow.multiplier, sheet.slow, name .. " slow"); equal(hit.slow.seconds, sheet.slowSeconds, name .. " slow time")
			equal(A.SlowMultiplier, sheet.slow, name); equal(A.SlowSeconds, sheet.slowSeconds, name)
			if sheet.push then
				assert(hit.push and hit.push.studs > 0 and hit.push.studs <= 12, name .. " push")
				if sheet.pushStuds then equal(hit.push.studs, sheet.pushStuds, name .. " push studs") end
				assert(hit.push.seconds > 0 and hit.push.seconds <= 0.5, name .. " the push is a quick shove")
			else
				equal(hit.push, nil, name .. " pushes")
			end
			equal(hit.knock, nil, name); equal(hit.mark, nil, name); equal(hit.sticky, nil, name)
			assert(string.find(phases(later), "Recover", 1, true), name .. " no recovery")
		end
	end)

	case("CC3: stepping out of the locked shape is a miss", function()
		for _, name in ipairs(NAMES) do
			local A = tuning(name).Attack
			local e, w, tgt, events, tell = telegraphing(name, "miss")
			local away = (A.RadiusStuds or A.LengthStuds or 10) + 30
			local later = run(e, w, tgt, 1.55, tell.strikeAt + 0.1, function(t, tg)
				if t > (tell.lockAt or tell.startAt) + 0.05 then tg.x, tg.z = close(name), away end
			end)
			equal(#each(events, "Hit") + #each(later, "Hit"), 0, name .. " hit outside its shape")
		end
	end)

	-- Deliberately changed (A2, odd/tasks/wildbound-caramelo-playfix.md): Mochimiau's second hop and Flanin's bounces
	-- (Extras.Follow) come right after the recovery; their cooldown rule is checked by the A2 Follow case instead.
	case("CC3: it waits its cooldown after a strike before the next tell", function()
		for _, name in ipairs(NAMES) do
			if tuning(name).Extras and tuning(name).Extras.Follow then continue end
			local A = tuning(name).Attack
			local e, w, tgt, events, tell = telegraphing(name, "cooldown")
			local later = run(e, w, tgt, 1.55, tell.strikeAt + A.CooldownSeconds + 3)
			local second
			-- A2: only its own attack counts (Mielita's swarm and the Gato's helper are side attacks with their own clocks)
			for _, ev in ipairs(each(later, "Tell")) do
				if ev.tell ~= tell.tell and string.find(ev.tell, ":" .. A.kind .. ":", 1, true) then second = second or ev end
			end
			assert(second, name .. " never attacked again")
			assert(second.startAt >= tell.strikeAt + A.CooldownSeconds - 1e-6,
				name .. " attacked again " .. (second.startAt - tell.strikeAt) .. " s after the strike")
		end
	end)

	-- Deliberately changed (RC1, relentless chases): once it hunts there is no leash; it follows its target past it.
	case("RC1: hunting, it goes past its old leash after the target", function()
		for _, name in ipairs(NAMES) do
			local T = tuning(name)
			local e, w, tgt = spawn(name, "leash"), fakeWorld(), target(close(name), 0)
			run(e, w, tgt, 0, 1)
			local farthest = 0
			run(e, w, tgt, 1.05, 20, function(_, tg) tg.x = T.LeashStuds + 25 end,
				function(_, c) farthest = math.max(farthest, math.sqrt(c.pos.x ^ 2 + c.pos.z ^ 2)) end)
			assert(farthest > T.LeashStuds + 1, name .. " held at its old leash: " .. farthest)
		end
	end)

	-- Deliberately changed (PF3, odd/tasks/wildbound-caramelo-playfix.md): it used to fade out where it gave up (Disengage,
	-- then End), so it vanished into nothing. Now it walks home (Return, a calm phase) and the encounter ends there with no
	-- fade, where the resting copy of it stands between encounters. No beast slot is held either way (PF1).
	local function quietEnd(name, events, reason, e)
		local back
		for _, ev in ipairs(each(events, "Phase")) do if ev.phase == "Return" then back = back or ev end end
		assert(back, name .. " never walked home (phases " .. phases(events) .. ")")
		equal(back.reason, reason, name .. " the Return's reason")
		equal(#each(events, "Disengage"), 0, name .. " faded out instead of walking home")
		local over = each(events, "End")[1]
		equal(over and over.reason, reason, name .. " the encounter ends")
		assert(over.at > back.at, name .. " ended before walking home")
		equal(e.done, true, name .. " done")
		assert(math.sqrt(e.pos.x ^ 2 + e.pos.z ^ 2) <= 0.5, name .. " ended " .. math.sqrt(e.pos.x ^ 2 + e.pos.z ^ 2) .. " studs from its post")
		for _, ev in ipairs(each(events, "Tell")) do
			assert(ev.startAt < back.at, name .. " opened an attack while walking home")
		end
		return back, over
	end

	-- Deliberately changed (RC1/RC3): a hunting creature no longer gives up past its abandon distance; its own end is the
	-- hard limit (WildboundCandySmarts.RELENTLESS.hardSeconds, 180 s): near home (under fadeStuds, 120) the quiet walk
	-- home (reason Timeout), far from home a fade where it stands (Disengage, then End), never a 600-stud walk back.
	case("RC1/RC3: past its abandon distance it keeps hunting; the hard limit walks it home near it, fades it far away", function()
		local HARD, FADE = 180, 120
		for _, name in ipairs(NAMES) do
			local T = tuning(name)
			local e, w, tgt = spawn(name, "giveup"), fakeWorld(), target(close(name), 0)
			run(e, w, tgt, 0, 0.9)
			tgt.x = T.LeashStuds + T.AbandonStuds + 1 -- past the abandon distance even from the end of its leash
			local chased = run(e, w, tgt, 0.95, 0.95 + T.GiveUpSeconds + 4)
			equal(#each(chased, "End"), 0, name .. " ended past its abandon distance")
			assert(not string.find(phases(chased), "Return", 1, true), name .. " walked home: " .. phases(chased))
			local later = run(e, w, tgt, HARD - 0.05, HARD + 15)
			quietEnd(name, later, "Timeout", e)
			-- far from home: a fade where it stands
			local f, fw, ft = spawn(name, "fade"), fakeWorld(), target(close(name), 0)
			run(f, fw, ft, 0, 0.9)
			f.pos.x = FADE + 30
			ft.x = f.pos.x + 60
			local far = run(f, fw, ft, HARD - 0.05, HARD + 2)
			local fade = each(far, "Disengage")[1]
			assert(fade and fade.reason == "Timeout", name .. " no fade far from home (phases " .. phases(far) .. ")")
			local over = each(far, "End")[1]
			assert(over and over.reason == "Timeout", name .. " never ended after the fade")
			assert(not string.find(phases(far), "Return", 1, true), name .. " began a long walk home")
		end
	end)

	-- PF2: nobody came near for IdleSeconds: it walks home and ends quietly (the resting copy takes over).
	case("PF2: an idle patrol ends quietly at home after IdleSeconds", function()
		for _, name in ipairs(NAMES) do
			local T = tuning(name)
			local e, w, tgt = spawn(name, "idle"), fakeWorld(), target(FAR, 0)
			local events = run(e, w, tgt, 0, T.IdleSeconds + 8)
			local back = quietEnd(name, events, "Idle", e)
			assert(back.at >= T.IdleSeconds - 1e-6, name .. " left its patrol after " .. back.at .. " s")
		end
	end)

	-- PF2: the walked Play check, as a pure case. A player walks (16 studs/s) from 60 studs straight at the post, stops
	-- 12 studs from it for 6 s, then walks away. The critter notices well before the player arrives, chases, strikes at
	-- least once (and the strike lands on a player who stands still), then walks home quietly when the player leaves.
	-- Deliberately changed (RC1): the player who walks away is followed to its base (a safe zone at 140 studs here),
	-- where the encounter ends at once; it used to be left with a quiet walk home.
	case("PF2: a walking player is noticed early, chased, hit, and followed to its base", function()
		for _, name in ipairs(NAMES) do
			local T = tuning(name)
			local e, w, tgt = spawn(name, "walk"), fakeWorld(), target(60, 0)
			local noticedAt
			local events = run(e, w, tgt, 0, 32, function(t, tg)
				if t < 3 then tg.x = math.max(60 - 16 * t, 12)
				elseif t < 9 then tg.x = 12
				else tg.x = math.min(12 + 16 * (t - 9), 140) end
				tg.safe = tg.x >= 140
			end, function(t, c)
				if not noticedAt and c.phase == "Notice" then noticedAt = { t = t, x = tgt.x } end
			end)
			assert(noticedAt, name .. " never noticed the walking player (phases " .. phases(events) .. ")")
			assert(noticedAt.x >= 24, name .. " noticed the player only " .. noticedAt.x .. " studs from its post")
			assert(#each(events, "Tell") >= 1, name .. " never attacked")
			local hits = each(events, "Hit")
			assert(#hits >= 1, name .. " never hit a player standing 12 studs from its post")
			equal(hits[1].damage, Config.BEASTS[name].damage, name .. " damage")
			assert(hits[1].push and hits[1].push.studs >= 6, name .. " the hit does not push")
			local over = each(events, "End")[1]
			assert(over, name .. " never ended after the player left (phases " .. phases(events) .. ")")
			equal(over.reason, "SafeZone", name .. " the base ends the hunt")
			assert(over.at >= 9 + (140 - 12) / 16 - 0.06, name .. " ended before the player reached its base")
		end
	end)

	-- Review fix: a target standing past its leash plus its attack range (but inside its abandon distance from the end
	-- of the leash) used to keep it in Chase for ever, clamped at the leash. Held there out of reach for GiveUpSeconds,
	-- it gives up.
	-- Deliberately changed (RC1): hunting, nothing holds it at a leash, so the stall spot past it is simply reached.
	case("RC1: a target standing past its old leash plus its reach is reached, never stalled at the leash", function()
		for _, name in ipairs(NAMES) do
			local T, A = tuning(name), tuning(name).Attack
			local stand = T.LeashStuds + A.RangeStuds + 2
			local e, w, tgt = spawn(name, "stall"), fakeWorld(), target(close(name), 0)
			run(e, w, tgt, 0, 0.9)
			local farthest = 0
			local later = run(e, w, tgt, 0.95, 12, function(_, tg) tg.x = stand end,
				function(_, c) farthest = math.max(farthest, math.sqrt(c.pos.x ^ 2 + c.pos.z ^ 2)) end)
			equal(#each(later, "End"), 0, name .. " ended")
			assert(farthest > T.LeashStuds + 1, name .. " stalled at its old leash: " .. farthest)
			assert(#each(later, "Tell") >= 1, name .. " never attacked the target past its old leash")
		end
	end)

	case("CC2: Mielita hovers HoverStuds over the ground; the others stand on it", function()
		for _, name in ipairs(NAMES) do
			local e, w, tgt = spawn(name, "hover"), fakeWorld(), target(FAR, 0)
			run(e, w, tgt, 0, 2)
			local expected = SHEET[name].flies and tuning(name).HoverStuds or 0
			near(e.pos.y, expected, name .. " height")
		end
	end)

	-- Deliberately changed (RC1): a target that runs far away no longer ends a hunt (it is followed to a safe zone).
	case("CC2: a safe zone or death ends it at once; a target that runs far away is still hunted", function()
		for _, name in ipairs(NAMES) do
			local T = tuning(name)
			local e, w, tgt = spawn(name, "safe"), fakeWorld(), target(close(name), 0)
			run(e, w, tgt, 0, 0.9)
			tgt.safe = true
			local ends = each(run(e, w, tgt, 0.95, 1.0), "End")
			equal(ends[1] and ends[1].reason, "SafeZone", name .. " safe")
			local e2, w2, tgt2 = spawn(name, "escape"), fakeWorld(), target(close(name), 0)
			run(e2, w2, tgt2, 0, 0.9)
			tgt2.x = T.EscapeDistanceStuds + 5
			local later = run(e2, w2, tgt2, 0.95, 0.95 + T.EscapeSeconds + 3)
			equal(#each(later, "End"), 0, name .. " a target far away ended the hunt")
			assert(not string.find(phases(later), "Return", 1, true), name .. " walked home: " .. phases(later))
		end
	end)

	case("CC5 wiring: the beast server registers the five with the one brain; the model service parks their rigs", function()
		assert(type(sources) == "table" and type(sources.beasts) == "string" and type(sources.service) == "string", "no sources given")
		for _, name in ipairs(NAMES) do
			assert(string.find(sources.beasts, '{ name = "' .. name .. '", module = "WildboundBeastCandyCritter" }', 1, true), name .. " has no KIDS row")
			assert(string.find(sources.service, '"' .. name .. '"', 1, true), name .. " is not in the model service")
		end
		local service = sources.service
		assert(string.find(service, "WildboundNewCandyImports", 1, true), "the service reads the rig imports")
		assert(string.find(service, 'if d:IsA("PackageLink") then d:Destroy() end', 1, true), "the PackageLink stays")
		assert(string.find(service, "model.PrimaryPart = root", 1, true), "PrimaryPart")
		-- the guarded clip line (WildboundCandyTortidragonService): an empty IDS never asserts
		assert(string.find(service, 'if Clips.IDS[clip] then model:SetAttribute("Clip_" .. clip, animationId(Clips, clip)) end', 1, true), "unguarded clip ids")
		assert(not string.find(service, "DuquesaBurbuja = {", 1, true), "the Duquesa stays scenery")
	end)

	-- PF3 (odd/tasks/wildbound-caramelo-playfix.md): between encounters each critter (and Gomibu, Flanfuria, Tortidragon)
	-- rests at its post as a client copy, so a creature never appears from nothing or vanishes into nothing. The server
	-- publishes each post (ground point, plus the hover of a flier) on ReplicatedStorage.WildboundBeasts; each client
	-- keeps a resting clone of Models.<name> there (in WildboundBeastsLocal, phase Calm, so the existing animators play
	-- its idle) and drops it while a live view of that beast exists.
	case("PF3 wiring: resting copies at the posts, hidden while that beast's live view exists", function()
		local server, client = sources.resting, sources.restingClient
		assert(type(server) == "string" and type(client) == "string", "pass the resting service and client sources")
		for _, name in ipairs({ "Mochimiau", "Canelin", "Flanin", "Mielita", "GatoRepartidor", "Gomibu", "Flanfuria", "Tortidragon" }) do
			assert(string.find(server, '"' .. name .. '"', 1, true), name .. " has no resting post")
		end
		assert(not string.find(server, '"DonGlaseon"', 1, true), "Don Glaseon keeps his own dormant copy")
		assert(string.find(server, "Sites.world(nil, Sites.HOME[name])", 1, true), "the post is the beast's own home site")
		assert(string.find(server, 'SetAttribute("RestingPost_" .. name', 1, true), "the post is published")
		assert(string.find(server, "HoverStuds", 1, true), "a flier rests at its hover height")
		assert(string.find(client, 'GetAttribute("RestingPost_" .. name)', 1, true), "the client reads the post")
		assert(string.find(client, 'WaitForChild("WildboundBeastsLocal"', 1, true), "the copy lives with the live views")
		assert(string.find(client, 'SetAttribute("WildboundResting", true)', 1, true), "the copy is tagged")
		assert(string.find(client, 'SetAttribute("BeastPhase", "Calm")', 1, true), "the copy idles")
		assert(string.find(client, 'child:GetAttribute("WildboundResting") ~= true', 1, true), "a live view is told apart")
	end)

	-- CH1 (owner request "more repeated creatures"): a creature also rests at its extra posts (WildboundPraderaSites
	-- .EXTRA_POSTS), published as RestingPost_<name>_<post>. A live view hides only the copy of the post it started on
	-- (the nearest post of its beast within BIND_STUDS), so the other copies of that creature stay at their posts.
	case("CH1 wiring: resting copies at the extra posts too; a live view hides only its own post's copy", function()
		local server, client = sources.resting, sources.restingClient
		assert(type(server) == "string" and type(client) == "string", "pass the resting service and client sources")
		assert(string.find(server, "for _, extra in ipairs(Sites.EXTRA_POSTS) do", 1, true), "the extra posts are published")
		assert(string.find(server, 'root:SetAttribute("RestingPost_" .. extra.name .. "_" .. extra.key', 1, true), "as RestingPost_<name>_<post>")
		assert(string.find(client, "local function postsOf(name)", 1, true), "the client reads every post of a beast")
		assert(string.find(client, 'local prefix = "RestingPost_" .. name .. "_"', 1, true), "its extra posts by prefix")
		assert(string.find(client, "bound[view] = best", 1, true), "a live view belongs to one post")
		-- Deliberately changed (CH1 review, MINOR 2): 50 -> 12 studs, so an ambush critter or a roar copy near a post never
		-- hides that post's copy; the first look waits 0.1 s for the beast client to place the new model
		assert(string.find(client, "local BIND_STUDS, BIND_TRIES, BIND_SECONDS = 12, 8, 0.25", 1, true), "within 12 studs, a few tries")
		assert(string.find(client, "task.delay(FIRST_SECONDS, bind, child, BIND_TRIES)", 1, true), "the first look after the model is placed")
		assert(string.find(client, "root.AttributeChanged:Connect(", 1, true), "a post published later is shown")
	end)

	-- PF2: the target's client shows the beast's own hit line (Text.BEAST[beast].hit) when the Hit carries no line of its
	-- own, on top of the hit sound and the shake it already played.
	case("PF2 wiring: a landed hit shows the beast's hit line on the target's screen", function()
		local client = sources.client
		assert(type(client) == "string", "pass the beast client source")
		assert(string.find(client, 'elseif said and type(said.hit) == "string" then showLine(said.hit, ev.at + 1.5) end', 1, true),
			"the Hit handler never shows Text.BEAST[beast].hit")
	end)

	-- PF1 (odd/tasks/wildbound-caramelo-playfix.md): a refused summon is no longer silent; its reason goes to telemetry.
	case("PF1 wiring: summonPass writes every summon refusal to Beast_lastSummonRefusal", function()
		local beasts = sources.beasts
		assert(string.find(beasts, 'local ok, value = Director.summon(director, player.UserId, kid.name, ctx, at)', 1, true), "summonPass summons")
		assert(string.find(beasts, 'telemetry:SetAttribute("Beast_lastSummonRefusal", kid.name .. ":" .. tostring(value))', 1, true),
			"summonPass drops the refusal")
		assert(string.find(beasts, 'telemetry:SetAttribute("Beast_lastSummonRefusal", "DonGlaseon:" .. tostring(value))', 1, true),
			"bossPass drops the refusal")
	end)

	-- A2 (odd/tasks/wildbound-caramelo-playfix.md): the "Otras habilidades" of each creature sheet (pack 6), as data on its
	-- tuning (Extras) read by the same brain. Damage stays 0. Patches (puddles and trails) are "Patch" events the server
	-- lays as fading parts; their slow is the brain's own Afflict while the target's root is inside one, never stacked.
	local EXTRAS = {
		Mochimiau = { Puddle = { life = 2, slow = 0.75 }, Follow = 1 },
		Canelin = { Trail = { phase = "Release", slow = 0.8 } },
		Flanin = { Trail = { phase = "Chase", slow = 0.8 }, Follow = 2 },
		Mielita = { Trail = { phase = "Chase", slow = 0.85 }, Swarm = true },
		GatoRepartidor = { Gift = true, Call = true },
	}
	local function mainTell(ev, A) return string.find(ev.tell, ":" .. A.kind .. ":", 1, true) ~= nil end
	-- Steps one creature by hand: before(t) runs before each step, and every event goes to onEvent(ev).
	local function drive(e, w, tgt, from, to, before, onEvent)
		local all = {}
		for i = 0, math.floor((to - from) / 0.05 + 1e-6) do
			local t = from + i * 0.05
			if before then before(t) end
			for _, ev in ipairs(Enc.step(e, t, tgt, w)) do
				table.insert(all, ev)
				if onEvent then onEvent(ev) end
			end
		end
		return all
	end

	case("A2 config: each sheet's extra abilities are frozen data on its tuning, inside the server's slow caps", function()
		for _, name in ipairs(NAMES) do
			local T, want = tuning(name), EXTRAS[name]
			local X = T.Extras
			assert(type(X) == "table" and table.isfrozen(X), name .. " has no frozen Extras")
			local function slowOk(S, label)
				assert(type(S) == "table" and table.isfrozen(S), label .. " missing or not frozen")
				assert(S.SlowMultiplier >= Chase.EFFECTS.slowMinMultiplier and S.SlowMultiplier < 1, label .. " slow multiplier")
				assert(S.SlowSeconds > 0 and S.SlowSeconds <= Chase.EFFECTS.slowMaxSeconds, label .. " slow seconds")
			end
			if want.Puddle then
				slowOk(X.Puddle, name .. " Puddle")
				equal(X.Puddle.LifeSeconds, want.Puddle.life, name .. " puddle life")
				equal(X.Puddle.SlowMultiplier, want.Puddle.slow, name .. " puddle slow")
				assert(X.Puddle.RadiusStuds >= 2, name .. " puddle radius")
			else equal(X.Puddle, nil, name .. " Puddle") end
			if want.Trail then
				slowOk(X.Trail, name .. " Trail")
				equal(X.Trail.Phase, want.Trail.phase, name .. " trail phase")
				equal(X.Trail.LifeSeconds, 2, name .. " trail life")
				equal(X.Trail.SlowMultiplier, want.Trail.slow, name .. " trail slow")
				equal(X.Trail.SlowSeconds, 2, name .. " trail slow seconds")
				assert(X.Trail.SpacingStuds >= 1.5 and X.Trail.RadiusStuds >= 1.5, name .. " trail spacing and radius")
			else equal(X.Trail, nil, name .. " Trail") end
			if want.Follow then
				equal(X.Follow and X.Follow.Max, want.Follow, name .. " follow-ups")
				assert(table.isfrozen(X.Follow) and X.Follow.RangeStuds > 0, name .. " follow range")
				-- walked Play (A2): Flanin's burst pushed the player 6 studs out of a 7-stud follow range, so it never
				-- bounced again; a follow-up must reach a target its own hit just pushed away
				local A = T.Attack
				local pushedTo = (A.kind == "burst" and A.RadiusStuds or 0) + A.PushStuds
				assert(X.Follow.RangeStuds >= pushedTo, name .. " follow range " .. X.Follow.RangeStuds .. " under " .. pushedTo)
			else equal(X.Follow, nil, name .. " Follow") end
			if want.Swarm then
				slowOk(X.Swarm, name .. " Swarm")
				equal(X.Swarm.EverySeconds, 18, name .. " swarm every"); equal(X.Swarm.Puffs, 2, name .. " puffs")
				assert(X.Swarm.TellSeconds >= Config.MIN_TELL, name .. " swarm tell")
				assert(X.Swarm.OffsetStuds > X.Swarm.RadiusStuds, name .. " the puffs land beside the target, not on it")
			else equal(X.Swarm, nil, name .. " Swarm") end
			if want.Gift then
				assert(type(X.Gift) == "table" and table.isfrozen(X.Gift), name .. " Gift")
				equal(X.Gift.Every, 4, name .. " one encounter in four"); equal(X.Gift.Multiplier, 1.15, name .. " +15 %")
				equal(X.Gift.Seconds, 10, name .. " for 10 s")
			else equal(X.Gift, nil, name .. " Gift") end
			if want.Call then
				slowOk(X.Call, name .. " Call")
				equal(X.Call.EverySeconds, 20, name .. " call every")
				assert(X.Call.TellSeconds >= Config.MIN_TELL, name .. " call tell")
				assert(X.Call.PushStuds > 0 and X.Call.PushStuds <= 8, name .. " call push")
			else equal(X.Call, nil, name .. " Call") end
		end
	end)

	case("A2 Mochimiau: its leap leaves a cream puddle for 2 s that slows whoever stands in it, never stacked", function()
		local P = tuning("Mochimiau").Extras.Puddle
		local e, w, tgt, events, tell = telegraphing("Mochimiau", "puddle")
		local later = run(e, w, tgt, 1.55, tell.strikeAt + 8)
		local patches = each(later, "Patch")
		local patch = patches[1]
		assert(patch, "no puddle after the leap")
		near(patch.at, tell.strikeAt, "the puddle comes with the landing", 1e-6)
		near(patch.x, close("Mochimiau"), "the puddle lies where it landed", 1e-6); near(patch.z, 0, "puddle z", 1e-6)
		near(patch.y, 0, "on the ground"); equal(patch.r, P.RadiusStuds, "radius")
		near(patch.untilAt, tell.strikeAt + P.LifeSeconds, "life", 1e-6)
		equal(patch.damage, nil, "a puddle never damages")
		local lastEnd = 0
		for _, p in ipairs(patches) do lastEnd = math.max(lastEnd, p.untilAt) end
		local slows = {}
		for _, ev in ipairs(each(later, "Afflict")) do if ev.patch then table.insert(slows, ev) end end
		assert(#slows >= 1, "standing in the puddle never slowed")
		equal(slows[1].slow, P.SlowMultiplier, "-25 %"); equal(slows[1].slowSeconds, P.SlowSeconds, "slow time")
		for i, ev in ipairs(slows) do
			assert(ev.at <= lastEnd + 1e-6, "a puddle slowed after it dried")
			if i > 1 then assert(ev.at - slows[i - 1].at >= P.SlowSeconds - 1e-6, "puddle slows stacked") end
		end
	end)

	case("A2 Follow: Mochimiau hops once more, Flanin bounces twice more, right after the recovery; then the cooldown", function()
		for _, name in ipairs({ "Mochimiau", "Flanin" }) do
			local A, F = tuning(name).Attack, tuning(name).Extras.Follow
			local e, w, tgt, events, tell = telegraphing(name, "follow")
			local later = run(e, w, tgt, 1.55, 30)
			local mine, seen = {}, {}
			for _, list in ipairs({ events, later }) do
				for _, ev in ipairs(each(list, "Tell")) do
					if mainTell(ev, A) and not seen[ev.tell] then seen[ev.tell] = true; table.insert(mine, ev) end
				end
			end
			assert(#mine >= F.Max + 2, name .. " only " .. #mine .. " attacks in 30 s")
			for i = 2, F.Max + 1 do
				local gap = mine[i].startAt - mine[i - 1].strikeAt
				assert(gap >= A.RecoverSeconds - 1e-6 and gap <= A.RecoverSeconds + 0.2, name .. " follow-up " .. (i - 1) .. " came " .. gap .. " s after the strike")
				assert(mine[i].strikeAt - mine[i].startAt >= Config.MIN_TELL - 1e-9, name .. " a follow-up skipped the tell")
			end
			local gap = mine[F.Max + 2].startAt - mine[F.Max + 1].strikeAt
			assert(gap >= A.CooldownSeconds - 1e-6, name .. " chained more than " .. F.Max .. " follow-ups (" .. gap .. " s)")
			-- out of reach after the first strike: no follow-up, the plain cooldown
			local e2, w2, tgt2, _, tell2 = telegraphing(name, "nofollow")
			local after = run(e2, w2, tgt2, 1.55, 25, function(t, tg)
				if t > tell2.strikeAt + 0.02 then tg.x = close(name) + F.RangeStuds + 6 end
			end)
			for _, ev in ipairs(each(after, "Tell")) do
				if ev.tell ~= tell2.tell and mainTell(ev, A) then
					assert(ev.startAt >= tell2.strikeAt + A.CooldownSeconds - 1e-6, name .. " followed a target out of reach")
				end
			end
		end
	end)

	case("A2 Canelin: it spins before rolling; the roll leaves a glaze trail along its lane that slows -20 % for 2 s", function()
		local A, X = tuning("Canelin").Attack, tuning("Canelin").Extras.Trail
		local e, w, tgt, events, tell = telegraphing("Canelin", "trail")
		local later = run(e, w, tgt, 1.55, tell.strikeAt + 3)
		local releaseAt = tell.strikeAt - A.TravelSeconds
		local patches = {}
		for _, list in ipairs({ events, later }) do
			for _, ev in ipairs(each(list, "Patch")) do table.insert(patches, ev) end
		end
		assert(#patches >= 3, "the roll left " .. #patches .. " glaze patches")
		for i, p in ipairs(patches) do
			assert(p.at >= releaseAt - 1e-6 and p.at <= tell.strikeAt + 1e-6, "a glaze patch outside the roll at " .. p.at)
			near(p.z, 0, "on the lane", 1e-6); assert(p.x >= -1e-6 and p.x <= A.LengthStuds + 1e-6, "on the lane: x " .. p.x)
			near(p.untilAt - p.at, X.LifeSeconds, "life"); equal(p.r, X.RadiusStuds, "radius")
			if i > 1 then
				local d = math.abs(p.x - patches[i - 1].x)
				assert(d >= X.SpacingStuds - 1e-6 and d <= X.SpacingStuds + 1.5, "spacing " .. d)
			end
		end
		local slowed
		for _, ev in ipairs(each(later, "Afflict")) do if ev.patch then slowed = slowed or ev end end
		assert(slowed, "standing on the glaze never slowed")
		equal(slowed.slow, X.SlowMultiplier, "-20 %"); equal(slowed.slowSeconds, X.SlowSeconds, "2 s")
	end)

	-- A2 review (walked Play): Canelin's first glaze piece lay where it started, beside the player it rolled into; the
	-- patch's -20 % took the one slow slot 0.1 s before the roll's -30 %, so every roll hit landed as -20 %. A patch never
	-- slows while the creature's own attack is open: the strike settles first.
	case("A2 Canelin: a target on its lane gets the roll's -30 %, not its own glaze's -20 %, first", function()
		local A = tuning("Canelin").Attack
		local e, w, tgt = spawn("Canelin", "lanefirst"), fakeWorld(), target(1, 0)
		local events = run(e, w, tgt, 0, 8)
		local hit = each(events, "Hit")[1]
		assert(hit, "the roll never hit a target on its lane (phases " .. phases(events) .. ")")
		equal(hit.slow and hit.slow.multiplier, A.SlowMultiplier, "the roll's slow")
		for _, ev in ipairs(each(events, "Afflict")) do
			assert(not (ev.patch and ev.at <= hit.at + 1e-6), "a glaze patch slowed at " .. ev.at .. ", before the roll's hit at " .. hit.at)
		end
	end)

	case("A2 Flanin and Mielita: a trail while they chase that slows; nobody leaves one on a quiet patrol", function()
		for _, name in ipairs({ "Flanin", "Mielita" }) do
			local X = tuning(name).Extras.Trail
			local e, w, tgt = spawn(name, "chasetrail"), fakeWorld(), target(30, 0)
			local events = run(e, w, tgt, 0, 4)
			local patches = each(events, "Patch")
			assert(#patches >= 2, name .. " left no trail while chasing (phases " .. phases(events) .. ")")
			for i, p in ipairs(patches) do
				near(p.y, 0, name .. " the trail lies on the ground")
				near(p.untilAt - p.at, X.LifeSeconds, name .. " life")
				if i > 1 then
					local d = math.sqrt((p.x - patches[i - 1].x) ^ 2 + (p.z - patches[i - 1].z) ^ 2)
					assert(d >= X.SpacingStuds - 1e-6 and d <= X.SpacingStuds + 1.5, name .. " spacing " .. d)
				end
			end
			-- the target steps onto the first patch as it is laid: the server's slow
			local e2, w2, tgt2 = spawn(name, "steptrail"), fakeWorld(), target(30, 0)
			local first
			local all = drive(e2, w2, tgt2, 0, 5, function()
				if first then tgt2.x, tgt2.z = first.x, first.z end
			end, function(ev) if ev.type == "Patch" then first = first or ev end end)
			local slowed
			for _, ev in ipairs(each(all, "Afflict")) do if ev.patch then slowed = slowed or ev end end
			assert(slowed, name .. " its trail never slowed")
			equal(slowed.slow, X.SlowMultiplier, name .. " trail slow"); equal(slowed.slowSeconds, X.SlowSeconds, name)
		end
		for _, name in ipairs(NAMES) do
			local e, w, tgt = spawn(name, "quiet"), fakeWorld(), target(FAR, 0)
			equal(#each(run(e, w, tgt, 0, 12), "Patch"), 0, name .. " left patches on a quiet patrol")
		end
	end)

	case("A2 Mielita: every 18 s of a chase, two pollen puffs beside the target with a fair tell; slows -15 %", function()
		local S = tuning("Mielita").Extras.Swarm
		local e, w, tgt = spawn("Mielita", "puffs"), fakeWorld(), target(close("Mielita"), 0)
		local swarms = {}
		local all = drive(e, w, tgt, 0, 30, function(t)
			local first = swarms[1]
			if first and t > first.startAt and t < first.strikeAt then
				tgt.x, tgt.z = first.shape.list[1].x, first.shape.list[1].z
			end
		end, function(ev)
			if ev.type == "Tell" and string.find(ev.tell, ":swarm:", 1, true) and (#swarms == 0 or swarms[#swarms].tell ~= ev.tell) then
				table.insert(swarms, ev)
			end
		end)
		local first = swarms[1]
		assert(first, "no swarm in 30 s of chase")
		equal(first.shape.kind, "multi", "puffs"); equal(#first.shape.list, S.Puffs, "two puffs")
		for _, puff in ipairs(first.shape.list) do
			equal(puff.r, S.RadiusStuds, "puff radius")
			near(math.sqrt((puff.x - close("Mielita")) ^ 2 + puff.z ^ 2), S.OffsetStuds, "beside the target", 1e-6)
		end
		near(first.lockAt, first.startAt, "locked at once", 1e-9)
		assert(first.strikeAt - first.startAt >= Config.MIN_TELL - 1e-9, "the swarm's tell is under MIN_TELL")
		local slowed
		for _, ev in ipairs(each(all, "Afflict")) do if ev.attack == first.tell then slowed = ev end end
		assert(slowed, "a target inside a puff was not slowed")
		near(slowed.at, first.strikeAt, "at the pop", 1e-6)
		equal(slowed.slow, S.SlowMultiplier, "-15 %"); equal(slowed.slowSeconds, S.SlowSeconds, "slow time")
		assert(swarms[2], "no second swarm")
		assert(swarms[2].startAt >= first.strikeAt + S.EverySeconds - 1e-6, "swarms closer than EverySeconds")
		for _, ev in ipairs(each(all, "Hit")) do equal(ev.damage, Config.BEASTS.Mielita.damage, "damage") end
	end)

	case("A2 Gato: every 20 s a helper Gato appears beside the target, throws fries once (a fair tell) and leaves", function()
		local K = tuning("GatoRepartidor").Extras.Call
		local e, w, tgt = spawn("GatoRepartidor", "helper"), fakeWorld(), target(close("GatoRepartidor"), 0)
		local calls, helpers = {}, {}
		local all = drive(e, w, tgt, 0, 30, nil, function(ev)
			if ev.type == "Tell" and string.find(ev.tell, ":call:", 1, true) and (#calls == 0 or calls[#calls].tell ~= ev.tell) then
				table.insert(calls, ev)
			elseif ev.type == "Helper" then
				table.insert(helpers, ev)
			end
		end)
		local first = calls[1]
		assert(first, "no call in 30 s of chase")
		assert(helpers[1], "no helper Gato")
		near(helpers[1].at, first.startAt, "the helper comes with the throw's tell", 1e-6)
		near(math.sqrt((helpers[1].x - tgt.x) ^ 2 + (helpers[1].z - tgt.z) ^ 2), K.RingStuds, "the helper stands RingStuds away", 1e-6)
		assert(helpers[1].untilAt > first.strikeAt, "the helper leaves before it throws")
		equal(first.shape.kind, "circle", "fries circle"); equal(first.shape.r, K.RadiusStuds, "radius")
		near(first.shape.x, close("GatoRepartidor"), "on the target", 1e-6)
		near(first.lockAt, first.startAt, "locked at once", 1e-9)
		assert(first.strikeAt - first.startAt >= Config.MIN_TELL - 1e-9, "the call's tell is under MIN_TELL")
		local hit
		for _, ev in ipairs(each(all, "Hit")) do if ev.attack == first.tell then hit = ev end end
		assert(hit, "the helper's fries never landed on a target standing still")
		equal(hit.damage, 0, "damage"); equal(hit.push.studs, K.PushStuds, "push"); equal(hit.slow.multiplier, K.SlowMultiplier, "slow")
		assert(calls[2], "no second call")
		assert(calls[2].startAt >= first.strikeAt + K.EverySeconds - 1e-6, "calls closer than EverySeconds")
	end)

	case("A2 Gato: one encounter in four it walks up, hands a golden order (+15 % for 10 s) and walks home, no attack", function()
		local G = tuning("GatoRepartidor").Extras.Gift
		local e, w, tgt = spawn("GatoRepartidor", "8"), fakeWorld(), target(20, 0)
		local events = run(e, w, tgt, 0, 20)
		local list = phases(events)
		assert(string.find(list, "Notice,Chase,Deliver", 1, true), "phases " .. list)
		local gift = each(events, "Gift")[1]
		assert(gift, "no golden order (phases " .. list .. ")")
		equal(gift.multiplier, G.Multiplier, "+15 %"); equal(gift.seconds, G.Seconds, "10 s")
		equal(#each(events, "Tell"), 0, "a delivering Gato never attacks")
		equal(#each(events, "Hit"), 0, "a delivering Gato never hits")
		local deliver
		for _, ev in ipairs(each(events, "Phase")) do if ev.phase == "Deliver" then deliver = deliver or ev end end
		near(gift.at - deliver.at, G.HandSeconds, "it hands the order over after HandSeconds", 0.051)
		quietEnd("GatoRepartidor", events, "Delivered", e)
		local e2, w2, tgt2 = spawn("GatoRepartidor", "7"), fakeWorld(), target(close("GatoRepartidor"), 0)
		local others = run(e2, w2, tgt2, 0, 3)
		equal(#each(others, "Gift"), 0, "only one encounter in four delivers")
		assert(#each(others, "Tell") >= 1, "an ordinary Gato stopped attacking")
	end)

	case("A2 wiring: the server lays the patches, the helper and the golden order; the client shows the order", function()
		local beasts, server, cake, Text, Spec = sources.beasts, sources.server, sources.cake, sources.text, sources.spec
		assert(type(server) == "string" and type(cake) == "string" and type(Text) == "table" and type(Spec) == "table",
			"pass server, cake, text and spec")
		local function has(src, text, label) assert(string.find(src, text, 1, true), label .. " (" .. text .. ")") end
		has(beasts, 'if event.type == "Patch" then world.candyPatch(entry, event) end', "the beast server lays patches")
		has(beasts, 'if event.type == "Helper" then world.candyHelper(entry, event) end', "the helper Gato")
		has(beasts, 'if event.type == "Gift" then world.candyGift(entry, event) end', "the golden order")
		has(beasts, "{ Transparency = 1 }", "a patch fades out")
		has(beasts, 'player:SetAttribute("WildboundCandyOrderUntil"', "the order's clock")
		has(beasts, '"order:"', "the order line cue")
		has(server, 'GetAttribute("WildboundCandyOrderUntil")', "applyCarry reads the order")
		has(server, "speed * 1.15", "the order is +15 %")
		has(server, 'GetAttributeChangedSignal("WildboundCandyOrderUntil")', "the walk speed is re-applied when it starts and ends")
		has(cake, 'what == "order"', "the client shows the order with the rush's chime")
		assert(type(Text.CANDY_CAKE.order) == "string", "Text.CANDY_CAKE.order")
		assert(type(Text.BEAST.GatoRepartidor.phases.Deliver) == "string", "the Deliver line")
		equal(Spec.SPEC.Canelin.phase.Telegraph, "Spin", "Canelín spins in place before rolling")
		equal(Spec.SPEC.GatoRepartidor.phase.Deliver, "Deliver", "the Gato's hand-over clip")
		assert(table.find(Spec.BRAIN_PHASES, "Deliver"), "Deliver is a brain phase")
	end)

	return result
end

-- Invoke with require(freshTestClone)(require(freshBeastEncountersClone), require(freshBeastCandyCritterClone),
-- require(freshBeastConfigClone), require(freshPortalClone), { beasts = WildboundBeasts.Source,
-- service = WildboundCandyCritterService.Source }, require(freshBeastChaseClone)).
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
	local SHEET = {
		Mochimiau = { kind = "leap", cooldown = 6, push = true, slow = 0.75, slowSeconds = 2.5, flies = false },
		Canelin = { kind = "dash", cooldown = 6, push = false, slow = 0.8, slowSeconds = 2, flies = false },
		Flanin = { kind = "burst", cooldown = 7, push = false, slow = 0.7, slowSeconds = 3, radius = 10, flies = false },
		Mielita = { kind = "lob", cooldown = 9, push = false, slow = 0.75, slowSeconds = 3, radius = 6, flies = true },
		GatoRepartidor = { kind = "lob", cooldown = 8, pushStuds = 2, push = true, slow = 0.9, slowSeconds = 1.5, radius = 4,
			flies = false },
	}
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

	case("CC1 config: five summoned guardians that never damage, keep the egg and are never rolled", function()
		equal(#Config.ORDER, 9, "ORDER keeps the rolled beasts only")
		for _, name in ipairs(NAMES) do
			local C, sheet = Config.BEASTS[name], SHEET[name]
			assert(C, "no " .. name .. " entry in WildboundBeastConfig")
			local T = C.tuning
			equal(Config.SUMMONED[name], true, name .. " summoned"); equal(Config.WAVE2[name], true, name .. " behaviour module")
			equal(Config.PLAYABLE[name], nil, name .. " never rolled")
			for _, other in ipairs(Config.ORDER) do assert(other ~= name, name .. " in ORDER") end
			equal(C.category, "Guardian", name); equal(C.biome, "Meadow", name); equal(C.chance, 0, name); equal(C.chance10, 0, name)
			equal(C.points, 0, name); equal(C.damage, 0, name .. " damage"); equal(C.keepsEgg, true, name .. " keepsEgg")
			equal(C.grounded, not sheet.flies, name .. " grounded")
			assert(type(C.hitHeight) == "number" and C.hitHeight > 0, name .. " hitHeight")
			assert(type(C.disengage) == "number" and C.disengage > 0, name .. " disengage")
			assert(table.isfrozen(C) and table.isfrozen(T) and table.isfrozen(T.Attack), name .. " frozen")
			equal(T.Attack.kind, sheet.kind, name .. " attack kind")
			equal(T.Attack.CooldownSeconds, sheet.cooldown, name .. " cooldown")
			assert(T.PatrolSpeedStudsPerSecond >= 5 and T.PatrolSpeedStudsPerSecond <= 8, name .. " patrol speed")
			assert(T.ChaseSpeedStudsPerSecond >= 9 and T.ChaseSpeedStudsPerSecond <= 13, name .. " chase speed")
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
			local e, w, tgt = spawn(name, "calm"), fakeWorld(), target(40, 0)
			local events = run(e, w, tgt, 0, 6)
			for _, ev in ipairs(each(events, "Phase")) do
				equal(Portal.CALM_PHASES[ev.phase], true, name .. " idle phase " .. ev.phase)
			end
			equal(e.phase, "Patrol", name .. " patrols while nobody is near")
		end
	end)

	case("CC2: it wanders near home while calm, never past its patrol radius", function()
		for _, name in ipairs(NAMES) do
			local T = tuning(name)
			local e, w, tgt = spawn(name, "patrol"), fakeWorld(), target(40, 0)
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
			equal(e.phase, "Patrol", name .. " noticed a target outside its perception")
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

	case("CC3: a target inside is slowed (and pushed when the sheet says so), with damage 0 and nothing else", function()
		for _, name in ipairs(NAMES) do
			local A, sheet = tuning(name).Attack, SHEET[name]
			local e, w, tgt, events, tell = telegraphing(name, "hit")
			local later = run(e, w, tgt, 1.55, tell.strikeAt + 0.1)
			local hits = {}
			for _, ev in ipairs(each(events, "Hit")) do table.insert(hits, ev) end
			for _, ev in ipairs(each(later, "Hit")) do table.insert(hits, ev) end
			equal(#hits, 1, name .. " hits")
			local hit = hits[1]
			near(hit.at, tell.strikeAt, name .. " hit time"); equal(hit.damage, 0, name .. " damage")
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

	case("CC3: it waits its cooldown after a strike before the next tell", function()
		for _, name in ipairs(NAMES) do
			local A = tuning(name).Attack
			local e, w, tgt, events, tell = telegraphing(name, "cooldown")
			local later = run(e, w, tgt, 1.55, tell.strikeAt + A.CooldownSeconds + 3)
			local second
			for _, ev in ipairs(each(later, "Tell")) do if ev.tell ~= tell.tell then second = second or ev end end
			assert(second, name .. " never attacked again")
			assert(second.startAt >= tell.strikeAt + A.CooldownSeconds - 1e-6,
				name .. " attacked again " .. (second.startAt - tell.strikeAt) .. " s after the strike")
		end
	end)

	case("CC2: it never goes past its leash, not even with a leap or a dash", function()
		for _, name in ipairs(NAMES) do
			local T = tuning(name)
			local e, w, tgt = spawn(name, "leash"), fakeWorld(), target(close(name), 0)
			run(e, w, tgt, 0, 1)
			local farthest = 0
			run(e, w, tgt, 1.05, 20, function(_, tg) tg.x = T.LeashStuds + 5 end,
				function(_, c) farthest = math.max(farthest, math.sqrt(c.pos.x ^ 2 + c.pos.z ^ 2)) end)
			assert(farthest <= T.LeashStuds + 1e-6, name .. " went " .. farthest .. " studs from home")
		end
	end)

	-- Review fix: giving up ends the encounter like Gomibu (Disengage "GiveUp" for GiveUpSeconds, then End), so an idle
	-- critter never keeps one of the director's MAX_ACTIVE slots (which would block Don Glaseon or a guardian alarm).
	case("CC2: past its abandon distance it gives up and the encounter ends, holding no beast slot", function()
		for _, name in ipairs(NAMES) do
			local T = tuning(name)
			local e, w, tgt = spawn(name, "giveup"), fakeWorld(), target(close(name), 0)
			run(e, w, tgt, 0, 0.9)
			tgt.x = T.LeashStuds + T.AbandonStuds + 1 -- past the abandon distance even from the end of its leash
			local later = run(e, w, tgt, 0.95, 0.95 + T.GiveUpSeconds + 8)
			local off = each(later, "Disengage")[1]
			equal(off and off.reason, "GiveUp", name .. " gives up (phases " .. phases(later) .. ")")
			local over = each(later, "End")[1]
			equal(over and over.reason, "GiveUp", name .. " the encounter ends")
			near(over.at - off.at, T.GiveUpSeconds, name .. " the retreat lasts GiveUpSeconds", 1e-6)
			equal(e.done, true, name .. " done")
			for _, ev in ipairs(each(later, "Tell")) do
				assert(ev.startAt < off.at, name .. " opened an attack while giving up")
			end
			assert(not string.find(phases(later), "Return", 1, true), name .. " walked home inside the encounter")
		end
	end)

	-- Review fix: a target standing past its leash plus its attack range (but inside its abandon distance from the end
	-- of the leash) used to keep it in Chase for ever, clamped at the leash. Held there out of reach for GiveUpSeconds,
	-- it gives up.
	case("CC2: held at its leash with the target out of reach, it gives up instead of chasing for ever", function()
		for _, name in ipairs(NAMES) do
			local T, A = tuning(name), tuning(name).Attack
			local stand = T.LeashStuds + A.RangeStuds + 2
			assert(stand < T.LeashStuds + T.AbandonStuds - 1, name .. ": the stall spot is past the abandon distance (test setup)")
			local e, w, tgt = spawn(name, "stall"), fakeWorld(), target(close(name), 0)
			run(e, w, tgt, 0, 0.9)
			local farthest = 0
			local later = run(e, w, tgt, 0.95, 20, function(_, tg) tg.x = stand end,
				function(_, c) farthest = math.max(farthest, math.sqrt(c.pos.x ^ 2 + c.pos.z ^ 2)) end)
			local off = each(later, "Disengage")[1]
			equal(off and off.reason, "GiveUp", name .. " never gave up at its leash (phases " .. phases(later) .. ")")
			equal(e.done, true, name .. " done")
			assert(farthest <= T.LeashStuds + 1e-6, name .. " went " .. farthest .. " studs from home")
		end
	end)

	case("CC2: Mielita hovers HoverStuds over the ground; the others stand on it", function()
		for _, name in ipairs(NAMES) do
			local e, w, tgt = spawn(name, "hover"), fakeWorld(), target(40, 0)
			run(e, w, tgt, 0, 2)
			local expected = SHEET[name].flies and tuning(name).HoverStuds or 0
			near(e.pos.y, expected, name .. " height")
		end
	end)

	case("CC2: a safe zone or death ends it at once; a target that runs far away ends it", function()
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
			local over = each(later, "End")
			-- the abandon distance (GiveUp) usually comes first; Escape stays as the backstop for the attack phases
			local reason = over[1] and over[1].reason
			assert(reason == "Escape" or reason == "GiveUp", name .. " escape: expected Escape or GiveUp, got " .. tostring(reason))
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

	return result
end

-- Invoke with require(freshTestClone)(require(freshBeastEncountersClone), require(freshBeastScuttlerClone),
-- require(freshBeastConfigClone), require(freshBeastAttackClone), freshBeastScuttlerClone.Source).
-- Scuttler (docs/design/wildbound-scuttler-plan.md, SC3 to SC6): the brain, pure. SC4 adds the feint (Finta de caza),
-- SC5 the route intercept (Ruta predictiva), SC6 the panic pulse (Pulso de panico). Spawn, Stalk, the committed charge,
-- Recovery, Castigo y caida (stumble or crash against a wall) and Disengage (Escape, Timeout, Outplayed after two
-- falls). A fake world (flat ground at y 0, open lines unless a case closes them, an optional wall plane) and a fake
-- dodge (world.resolve answers what the case sets) stand in for the beast script; the target is a table moved by each
-- case. No world is touched.
return function(Enc, Scuttler, Config, Attack, source)
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
	Enc.register("Scuttler", Scuttler)
	local C = Config.BEASTS.Scuttler
	local T = C.tuning

	local function fakeWorld()
		local w = { telegraphs = {}, resolved = {}, cancelled = {}, verdict = "Hit", los = true, claim = true, wallZ = nil }
		function w.ground() return 0 end
		function w.lineOfSight() return w.los end
		function w.claimStrike() return w.claim end
		function w.telegraph(id, beast, startAt, strikeAt)
			local accepted = strikeAt - startAt >= Config.MIN_TELL - 1e-9
			table.insert(w.telegraphs, { id = id, beast = beast, startAt = startAt, strikeAt = strikeAt, accepted = accepted })
			return accepted
		end
		function w.resolve(id) table.insert(w.resolved, id); return w.verdict end
		function w.cancel(id) table.insert(w.cancelled, id) end
		-- A wall plane at z = wallZ, seen only by casts heading toward it.
		function w.castLane(_, _, oz, _, dz, length)
			if not w.wallZ or math.abs(dz) < 1e-6 then return nil end
			local d = (w.wallZ - oz) / dz
			if d >= 0 and d <= length then return d end
			return nil
		end
		return w
	end
	local function target(x, z) return { x = x, y = 3, z = z, vx = 0, vz = 0, alive = true, safe = false } end
	-- Steps from `from` to `to` at 20 Hz; move(t, tgt) may change the target. Returns every event.
	local function run(e, w, tgt, from, to, move)
		local all = {}
		for i = 0, math.floor((to - from) / 0.05 + 1e-6) do
			local t = from + i * 0.05
			if move then move(t, tgt) end
			for _, ev in ipairs(Enc.step(e, t, tgt, w)) do table.insert(all, ev) end
			if e.done then break end
		end
		return all
	end
	local function find(events, kind, field, value)
		for _, ev in ipairs(events) do
			if ev.type == kind and (field == nil or ev[field] == value) then return ev end
		end
		return nil
	end
	local function count(events, kind, field, value)
		local n = 0
		for _, ev in ipairs(events) do
			if ev.type == kind and (field == nil or ev[field] == value) then n += 1 end
		end
		return n
	end
	-- Spawned 30 studs in front of a still target: inside the stalk band and the charge range.
	local function spawn(id, z)
		return Enc.new("Scuttler", id, 1, 0, { x = 0, y = 0, z = z or -30 })
	end

	case("SC3 Scuttler: rises, stalks, then its first move is a committed charge registered with the dodge", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = spawn("beast:1")
		local events = run(e, w, tgt, 0, 3.5)
		local stalk = find(events, "Phase", "phase", "Stalk")
		assert(stalk, "Stalk")
		near(stalk.at, C.spawnSeconds, "stalk after the rise")
		local tell = find(events, "Phase", "phase", "ChargeTell")
		assert(tell, "a charge tell")
		assert(tell.at >= stalk.at - 1e-9, "the tell follows the rise")
		local reg = w.telegraphs[1]
		assert(reg and reg.beast == "Scuttler", "the charge is registered with the dodge")
		equal(reg.accepted, true, "never refused as ShortTelegraph")
		assert(reg.strikeAt - reg.startAt >= Config.MIN_TELL, "tell at least 0.8 s")
		assert(reg.strikeAt - reg.startAt >= T.ChargeTelegraphSeconds - 1e-9, "strike after the 1.1 s telegraph")
		local shown = find(events, "Tell", "tell", reg.id)
		equal(shown.shape.kind, "lane")
		equal(shown.shape.width, C.laneWidth)
		equal(shown.dodgeable, true)
		near(shown.lockAt, reg.startAt + T.ChargeTelegraphSeconds - C.lockLead, "lock 0.3 s before the commit")
		for _, ev in ipairs(events) do
			if ev.type == "Hit" then assert(ev.at >= reg.startAt + T.ChargeTelegraphSeconds - 1e-9, "a hit before the commit") end
		end
	end)

	case("SC3 Scuttler: stalk keeps 20..34 studs (closes in from afar, backs off when too close)", function()
		local w = fakeWorld()
		w.los = false -- no charge: only the stalk
		local tgt = target(0, 0)
		local far = spawn("beast:2", -60)
		run(far, w, tgt, 0, 6)
		local d = Attack.distance(far, tgt)
		assert(d <= T.StalkMax + 1e-6 and d >= T.StalkMin - 1e-6, "closed to the band: " .. d)
		local close = spawn("beast:3", -8)
		run(close, w, tgt, 0, 4)
		local d2 = Attack.distance(close, tgt)
		assert(d2 >= T.StalkMin - 1e-6, "backed off to the band: " .. d2)
		equal(count(w.telegraphs), 0, "no line of sight, no charge")
	end)

	local function toLock(w, tgt, id)
		local e = spawn(id)
		local events = run(e, w, tgt, 0, 1.9) -- the lock is at 1.8, the commit at 2.1
		equal(e.phase, "ChargeTell", "in the telegraph")
		return e, events
	end

	case("SC3 Scuttler: the lane follows until the lock, then never moves; the head runs straight, one hit", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = spawn("beast:4")
		local dirAtLock, lockedShape
		local events = run(e, w, tgt, 0, 6, function(t, tg)
			if e.phase == "ChargeTell" and e.charge and not e.charge.locked then tg.x = 2 * math.sin(t * 3) end
			if e.charge and e.charge.locked and not dirAtLock then dirAtLock = { e.dx, e.dz } end
			if e.phase == "Charge" then
				near(e.dx, dirAtLock[1], "dx held"); near(e.dz, dirAtLock[2], "dz held")
			end
		end)
		local reg = w.telegraphs[1]
		for _, ev in ipairs(events) do
			if ev.type == "Tell" and ev.tell == reg.id then
				if ev.locked then lockedShape = lockedShape or ev.shape
				else assert(not lockedShape, "no unlocked redraw after the lock") end
			end
		end
		assert(lockedShape, "a locked tell")
		near(lockedShape.dx, dirAtLock[1], "locked lane = held direction")
		equal(count(events, "Hit", "attack", reg.id), 1, "one hit per charge")
		equal(find(events, "Hit", "attack", reg.id).damage, T.ChargeDamage)
		assert(find(events, "Move", "kind", "dash"), "the charge move for the client")
		assert(find(events, "Phase", "phase", "Recovery"), "recovery after a landed charge")
		equal(count(events, "Phase", "phase", "Fallen"), 0, "a landed charge never falls")
	end)

	case("SC3 Scuttler: stepping out of the locked lane is a miss and the short recovery", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = toLock(w, tgt, "beast:5")
		local events = run(e, w, tgt, 1.95, 6, function(_, tg)
			if e.charge and e.charge.locked then tg.x = 12 end -- sideways, out of the 8-stud lane
		end)
		local reg = w.telegraphs[1]
		equal(count(events, "Hit"), 0)
		equal(w.cancelled[1], reg.id, "the dodge registration is cancelled")
		local recovery = find(events, "Phase", "phase", "Recovery")
		near(recovery.untilAt - recovery.at, T.ChargeMissRecoverySeconds)
		assert(find(events, "Phase", "phase", "Stalk"), "back to the stalk after the recovery")
	end)

	case("SC3 Scuttler: a perfect dodge in open ground: overrun and a stumble, no damage", function()
		local w = fakeWorld()
		w.verdict = "Dodged"
		local tgt = target(0, 0)
		local e = spawn("beast:6")
		local events = run(e, w, tgt, 0, 5.0) -- still fallen (until about 5.34)
		local reg = w.telegraphs[1]
		equal(count(events, "Hit"), 0, "no damage")
		equal(find(events, "Strike", "tell", reg.id).dodged, true)
		equal(#w.resolved, 1, "asked once")
		local fallen = find(events, "Phase", "phase", "Fallen")
		assert(fallen, "fallen")
		equal(fallen.fall, "Stumble")
		near(fallen.overrun, T.OverrunStuds, "the full overrun")
		near(fallen.untilAt - fallen.at, T.OverrunStuds / T.ChargeSpeed + T.FallStumbleSeconds, "stumble time")
		-- The overrun runs on along the same line (no homing), past the lane's end.
		local laneEnd = -30 + T.ChargeMaxRangeStuds
		near(e.pos.z, laneEnd + T.OverrunStuds, "overrun distance", 1e-3)
		near(e.pos.x, 0, "straight", 1e-3)
		equal(e.falls, 1)
		for _, ev in ipairs(events) do
			if ev.type == "Tell" then assert(ev.at < fallen.at or ev.at >= fallen.untilAt, "no tell while fallen") end
		end
		equal(next(e.open), nil, "nothing open while fallen")
	end)

	case("SC3 Scuttler: a perfect dodge with a wall inside the overrun: it crashes (longer fall)", function()
		local w = fakeWorld()
		w.verdict = "Dodged"
		w.wallZ = 14 -- 4 studs past the lane's end (z = 10), inside the 8-stud overrun
		local tgt = target(0, 0)
		local e = spawn("beast:7")
		local events = run(e, w, tgt, 0, 6)
		local fallen = find(events, "Phase", "phase", "Fallen")
		assert(fallen, "fallen")
		equal(fallen.fall, "Crash")
		assert(fallen.overrun < T.OverrunStuds and fallen.overrun <= 4, "stopped at the wall: " .. tostring(fallen.overrun))
		near(fallen.untilAt - fallen.at, fallen.overrun / T.ChargeSpeed + T.FallCrashSeconds, "crash time")
		assert(e.pos.z < 14, "never through the wall")
	end)

	case("SC3 Scuttler: a wall that cuts the lane itself also ends a dodged charge in a crash", function()
		local w = fakeWorld()
		w.verdict = "Dodged"
		w.wallZ = 5 -- inside the 40-stud lane (origin z = -30)
		local tgt = target(0, 0)
		local e = spawn("beast:8")
		local events = run(e, w, tgt, 0, 5.5) -- still fallen (until about 5.85)
		local reg = w.telegraphs[1]
		local locked
		for _, ev in ipairs(events) do if ev.type == "Tell" and ev.tell == reg.id and ev.locked then locked = ev end end
		assert(locked.shape.length < T.ChargeMaxRangeStuds, "the lane is cut at the wall")
		local fallen = find(events, "Phase", "phase", "Fallen")
		equal(fallen.fall, "Crash")
		assert(e.pos.z < 5, "never through the wall")
	end)

	case("SC3 Scuttler: two falls in one encounter: it disengages Outplayed, then ends", function()
		local w = fakeWorld()
		w.verdict = "Dodged"
		local tgt = target(0, 0)
		local e = spawn("beast:9")
		local events = run(e, w, tgt, 0, 30)
		equal(count(events, "Phase", "phase", "Fallen"), 2, "two falls")
		local dis = find(events, "Disengage")
		assert(dis, "disengage")
		equal(dis.reason, "Outplayed")
		local falls = {}
		for _, ev in ipairs(events) do if ev.type == "Phase" and ev.phase == "Fallen" then table.insert(falls, ev) end end
		near(dis.at, falls[2].untilAt, "after the second fall ends")
		local ending = find(events, "End")
		equal(ending.reason, "Outplayed")
		near(ending.at, dis.at + C.disengage, "the retreat")
		equal(count(events, "Hit"), 0)
		equal(#w.telegraphs, 2, "no third charge")
	end)

	case("SC3 Scuttler: a staggered charge waits; nothing opens until the strike slot is free", function()
		local w = fakeWorld()
		w.claim = false
		local tgt = target(0, 0)
		local e = spawn("beast:10")
		local events = run(e, w, tgt, 0, 2)
		equal(count(events, "Tell"), 0, "no tell while staggered")
		equal(#w.telegraphs, 0)
		equal(e.phase, "Stalk")
		w.claim = true
		events = run(e, w, tgt, 2.05, 2.5)
		assert(find(events, "Phase", "phase", "ChargeTell"), "opens once the slot is free")
	end)

	case("SC3 Scuttler: a safe zone mid-tell ends it at once; closeAll on End cancels the open charge", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = toLock(w, tgt, "beast:11")
		assert(next(e.open) ~= nil, "the charge is open")
		tgt.safe = true
		local events = Enc.step(e, 1.95, tgt, w)
		equal(find(events, "End").reason, "SafeZone")
		equal(count(events, "Hit"), 0, "no hit on the way out")
		Attack.closeAll(e, w)
		equal(w.cancelled[1], w.telegraphs[1].id, "the registration is cancelled")
		equal(next(e.open), nil, "nothing open after closeAll")
		equal(#Enc.step(e, 2.0, target(0, 0), w), 0, "nothing after the end")
		local e2 = spawn("beast:12")
		equal(find(Enc.step(e2, 0.05, nil, w), "End").reason, "Death", "no body: death")
	end)

	case("SC3 Scuttler: escape (far for 4 s) and timeout disengage, then end", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = spawn("beast:13")
		local events = run(e, w, tgt, 0, 8, function(_, tg) tg.z = e.pos.z + C.escapeDistance + 10 end)
		local dis = find(events, "Disengage")
		equal(dis.reason, "Escape")
		near(dis.at, C.escapeSeconds, "after 4 s far", 0.06)
		assert(find(events, "End"), "ends after the retreat")
		local w2 = fakeWorld()
		w2.los = false -- never charges
		local tgt2 = target(0, 0)
		local e2 = spawn("beast:14", -27)
		local events2 = run(e2, w2, tgt2, 0, T.EncounterTimeoutSeconds + 2)
		local dis2 = find(events2, "Disengage")
		equal(dis2.reason, "Timeout")
		near(dis2.at, T.EncounterTimeoutSeconds, "at the timeout", 0.06)
		assert(find(events2, "End"), "ends after the retreat")
	end)

	-- SC4 Finta de caza. world.random answers the feint roll (a feint when below FeintChance); world.lastDash answers the
	-- target's server attribute WildboundDash (the last validated press time, set by WildboundDodgeService.press).
	local function feintWorld(roll)
		local w = fakeWorld()
		w.roll, w.dash, w.rolls = roll, nil, 0
		function w.random() w.rolls += 1; return w.roll end
		function w.lastDash() return w.dash end
		return w
	end
	local function phases(events)
		local list = {}
		for _, ev in ipairs(events) do if ev.type == "Phase" then table.insert(list, ev) end end
		return list
	end
	local function isRegistered(w, id)
		for _, reg in ipairs(w.telegraphs) do if reg.id == id then return true end end
		return false
	end

	case("SC4 Scuttler: the first charge of an encounter is never a feint, even when every roll says feint", function()
		local w = feintWorld(0)
		local tgt = target(0, 0)
		local e = spawn("beast:20")
		local events = run(e, w, tgt, 0, 3.5)
		equal(count(events, "Phase", "phase", "FeintTell"), 0, "no feint before the first charge")
		local tell = find(events, "Phase", "phase", "ChargeTell")
		assert(tell, "the first move is a committed charge")
		equal(#w.telegraphs, 1, "registered with the dodge")
	end)

	case("SC4 Scuttler: a feint never registers, never strikes or hits, never moves the body; a real charge follows", function()
		local w = feintWorld(0)
		local tgt = target(0, 0)
		local e = spawn("beast:21")
		local feintPos, feint
		local events = run(e, w, tgt, 0, 12, function()
			if e.phase == "FeintTell" then
				feintPos = feintPos or Attack.copy(e.pos)
				near(e.pos.x, feintPos.x, "the body holds still (x)"); near(e.pos.z, feintPos.z, "the body holds still (z)")
			end
		end)
		local list = phases(events)
		local at
		for i, ev in ipairs(list) do if ev.phase == "FeintTell" then feint, at = ev, i; break end end
		assert(feint, "a feint on the second move")
		near(feint.untilAt - feint.at, T.FeintSeconds, "the feint lasts FeintSeconds")
		local shown
		for _, ev in ipairs(events) do if ev.type == "Tell" and ev.feint == true then shown = shown or ev end end
		assert(shown, "the feint lane is drawn")
		equal(shown.shape.kind, "lane"); equal(shown.shape.width, C.laneWidth)
		equal(shown.dodgeable, false, "a feint is never dodgeable")
		equal(isRegistered(w, shown.tell), false, "a feint never registers with the dodge")
		for _, ev in ipairs(events) do
			if ev.type == "Strike" or ev.type == "Hit" or ev.type == "Afflict" then
				assert(ev.tell ~= shown.tell and ev.attack ~= shown.tell, "the feint never strikes or hits")
			end
		end
		local ended = find(events, "TellEnd", "tell", shown.tell)
		assert(ended, "the feint lane goes away")
		equal(ended.reason, "Feint")
		local nextPhase = list[at + 1]
		assert(nextPhase and (nextPhase.phase == "ChargeTell" or nextPhase.phase == "PunishTell"), "a real charge follows")
		equal(#w.telegraphs, 2, "only the two real charges registered")
	end)

	case("SC4 Scuttler: never two feints in a row over a whole encounter, every feint followed by a registered charge", function()
		local w = feintWorld(0)
		local tgt = target(0, 0)
		local e = spawn("beast:22")
		local events = run(e, w, tgt, 0, T.EncounterTimeoutSeconds + 2)
		local moves = {}
		for _, ev in ipairs(phases(events)) do
			if ev.phase == "FeintTell" or ev.phase == "ChargeTell" or ev.phase == "PunishTell" then table.insert(moves, ev.phase) end
		end
		local feints = 0
		for i, m in ipairs(moves) do
			if m == "FeintTell" then
				feints += 1
				assert(moves[i - 1] ~= "FeintTell", "two feints in a row at move " .. i)
				assert(moves[i + 1] == nil or moves[i + 1] ~= "FeintTell", "two feints in a row after move " .. i)
			end
		end
		assert(feints >= 2, "several feints without an egg: " .. feints)
		equal(moves[1], "ChargeTell", "the first move is real")
		equal(count(events, "Hit"), #moves - feints, "only real charges hit")
	end)

	case("SC4 Scuttler: a press inside the feint window: a re-aimed punish charge with a tell of at least 0.9 s", function()
		local w = feintWorld(0)
		w.verdict = "Dodged" -- the punish charge can end in a fall too
		local tgt = target(0, 0)
		local e = spawn("beast:23")
		local pressed, punish
		local events = run(e, w, tgt, 0, 14, function(t, tg)
			if e.phase == "FeintTell" and not pressed and t >= e.phaseAt + 0.3 then
				pressed = t
				w.dash = t -- the bait: an early press during the feint
				tg.x = 9 -- the dash moved the player
			end
		end)
		for _, ev in ipairs(phases(events)) do if ev.phase == "PunishTell" then punish = punish or ev end end
		assert(pressed, "the feint happened")
		assert(punish, "the bait was taken: a punish charge")
		assert(punish.at >= pressed - 1e-9, "the punish charge follows the press")
		local reg = w.telegraphs[#w.telegraphs]
		assert(reg.startAt >= pressed - 1e-9, "the punish charge is the last registration")
		equal(reg.accepted, true, "never refused as ShortTelegraph")
		assert(reg.strikeAt - reg.startAt >= T.PunishTelegraphSeconds - 1e-9, "tell at least 0.9 s")
		assert(reg.strikeAt - reg.startAt >= Config.MIN_TELL, "tell above the 0.8 s floor")
		near(punish.untilAt - punish.at, T.PunishTelegraphSeconds, "the punish telegraph")
		local tell = find(events, "Tell", "tell", reg.id)
		assert(tell.shape.dx > 0, "re-aimed at the target's new position")
		assert(find(events, "Strike", "tell", reg.id), "the punish charge settles")
		local fallen
		for _, ev in ipairs(events) do if ev.type == "Phase" and ev.phase == "Fallen" and ev.at > punish.at then fallen = ev end end
		assert(fallen, "a perfect dodge of the punish charge is a fall")
	end)

	case("SC4 Scuttler: no press in the feint window: a committed charge with the full telegraph", function()
		local w = feintWorld(0)
		local tgt = target(0, 0)
		local e = spawn("beast:24")
		local feintAt
		local events = run(e, w, tgt, 0, 12, function(t)
			if e.phase == "FeintTell" and not feintAt then
				feintAt = e.phaseAt
				w.dash = feintAt - 0.2 -- a press before the feint started is not the bait
			end
		end)
		assert(feintAt, "the feint happened")
		equal(count(events, "Phase", "phase", "PunishTell"), 0, "no punish without the bait")
		local committed
		for _, ev in ipairs(phases(events)) do
			if ev.phase == "ChargeTell" and ev.at > feintAt then committed = committed or ev end
		end
		assert(committed, "a committed charge after the feint")
		near(committed.at, feintAt + T.FeintSeconds, "at the feint's end", 0.051)
		near(committed.untilAt - committed.at, T.ChargeTelegraphSeconds, "the full telegraph")
		local reg = w.telegraphs[2]
		assert(reg.strikeAt - reg.startAt >= T.ChargeTelegraphSeconds - 1e-9, "registered with the full tell")
	end)

	case("SC4 Scuttler: while the target carries an egg, at most MaxFeintsWhileEgg feints per encounter", function()
		local w = feintWorld(0)
		local tgt = target(0, 0)
		tgt.carryingEgg = true
		local e = spawn("beast:25")
		-- The target steps out of every locked lane: a landed charge would drop the egg and end the hunt (SC6, EggDropped).
		local events = run(e, w, tgt, 0, T.EncounterTimeoutSeconds + 2, function(_, tg)
			tg.x = (e.charge and e.charge.locked) and 12 or 0
		end)
		equal(count(events, "Hit"), 0, "every charge missed")
		equal(count(events, "Phase", "phase", "FeintTell"), T.MaxFeintsWhileEgg, "the egg cap")
		assert(count(events, "Phase", "phase", "ChargeTell") >= 3, "it keeps charging for real")
	end)

	case("SC4 Scuttler: a roll at or above FeintChance, or no roll at all, is always a real charge", function()
		local w = feintWorld(T.FeintChance)
		local tgt = target(0, 0)
		local events = run(spawn("beast:26"), w, tgt, 0, 20)
		equal(count(events, "Phase", "phase", "FeintTell"), 0, "roll >= FeintChance")
		assert(w.rolls >= 1, "the later charges rolled")
		local w2 = fakeWorld() -- no world.random
		local events2 = run(spawn("beast:27"), w2, target(0, 0), 0, 20)
		equal(count(events2, "Phase", "phase", "FeintTell"), 0, "no roll, no feint")
		assert(count(events2, "Phase", "phase", "ChargeTell") >= 2, "real charges only")
	end)

	case("SC4 Scuttler: a safe zone mid-feint ends at once with nothing to cancel", function()
		local w = feintWorld(0)
		local tgt = target(0, 0)
		local e = spawn("beast:28")
		run(e, w, tgt, 0, 12, function(_, tg) if e.phase == "FeintTell" then tg.safe = true end end)
		equal(e.endReason, "SafeZone")
		equal(next(e.open), nil, "a feint is never an open attack")
		equal(#w.cancelled, 0, "no registration to cancel")
	end)

	-- SC5 Ruta predictiva. The first charge (a still target at the origin) lands and leaves Scuttler about (0, 20); the
	-- next move is free at 6.6 s (commit 2.1 + ChargeCooldownSeconds). At 6.0 s the target appears at (-30, z) running
	-- along +x at `speed`; `after(t, tg)` may change it later. world.safe and world.landing mirror the beast script's.
	local RESTED_SPRINT = 16 * 1.45 -- WildboundStamina: base walk 16 x SPRINT_MULTIPLIER 1.45 = 23.2 studs/s
	local flat = Config.flat
	local function routeWorld()
		local w = feintWorld(1) -- never a feint
		w.unsafe = nil
		function w.safe(x, z) return w.unsafe ~= nil and w.unsafe(x, z) == true end
		function w.landing(x, z) if w.safe(x, z) then return nil end return 0 end
		return w
	end
	local function runRoute(e, w, tgt, to, z, speed, after)
		local log = { reads = {}, steps = {} }
		local events = run(e, w, tgt, 0, to, function(t, tg)
			if t >= 6.0 - 1e-9 then
				if not log.started then
					log.started = true
					tg.x, tg.z, tg.vx, tg.vz = -30, z, speed, 0
				else
					tg.x += tg.vx * 0.05
					tg.z += tg.vz * 0.05
				end
				if after then after(t, tg) end
			end
			if e.phase == "Read" then log.read = { t = t, s = Attack.copy(e.pos), x = tg.x, z = tg.z, vx = tg.vx, vz = tg.vz } end
			table.insert(log.steps, { t = t, phase = e.phase, s = Attack.copy(e.pos), x = tg.x, z = tg.z })
		end)
		return events, log
	end
	local function zones(events)
		local list = {}
		for _, ev in ipairs(events) do if ev.type == "Tell" and ev.zone == true then table.insert(list, ev) end end
		return list
	end

	case("SC5 Scuttler: a route it reaches first: Read, then Intercept to the predicted point only when it arrives first", function()
		local w = routeWorld()
		local tgt = target(0, 0)
		local e = spawn("beast:30")
		local events, log = runRoute(e, w, tgt, 8.2, 10, 16)
		local read = find(events, "Phase", "phase", "Read")
		assert(read, "a route read")
		near(read.untilAt - read.at, T.ReadSeconds, "the read lasts ReadSeconds")
		local inter = find(events, "Phase", "phase", "Intercept")
		assert(inter, "it intercepts")
		near(inter.at, read.untilAt, "at the read's end", 0.051)
		-- The point is the target's lead (velocity x PredictSeconds, at most InterceptMaxStuds) at the choice.
		local r = log.read
		near(inter.to.x, r.x + r.vx * T.PredictSeconds, "P.x = target + v * PredictSeconds", 1e-3)
		near(inter.to.z, r.z, "P.z", 1e-3)
		local mine = flat(r.s.x, r.s.z, inter.to.x, inter.to.z) / T.InterceptSpeed
		local theirs = flat(r.x, r.z, inter.to.x, inter.to.z) / math.sqrt(r.vx * r.vx + r.vz * r.vz)
		assert(mine + T.InterceptMarginSeconds < theirs, ("commits only when it arrives first: %.3f vs %.3f"):format(mine, theirs))
		near(inter.eta, mine, "the reported ETA", 1e-3)
		local zone = zones(events)[1]
		assert(zone, "the intercept zone is drawn")
		near(zone.startAt, inter.at, "from the start of the phase")
		equal(zone.shape.kind, "circle"); equal(zone.shape.r, T.SnapRadius)
		near(zone.shape.x, inter.to.x, "the zone is at P", 1e-3)
		equal(zone.dodgeable, false, "the zone itself never hits")
		equal(isRegistered(w, zone.tell), false, "the zone is not an attack")
		for _, ev in ipairs(events) do assert(ev.type ~= "Hit" or ev.at < 6.0, "the read and the run never hit") end
	end)

	case("SC5 Scuttler: a route it cannot reach first (the target runs away): no intercept, it pursues, never teleports", function()
		local w = routeWorld()
		local tgt = target(0, 0)
		local e = spawn("beast:31")
		local events, log = runRoute(e, w, tgt, 9, 0, 0, function(t, tg)
			if t < 6.05 then tg.x, tg.z, tg.vx, tg.vz = 0, 0, 0, -RESTED_SPRINT end -- straight away from Scuttler
		end)
		assert(find(events, "Phase", "phase", "Read"), "it read the route")
		equal(count(events, "Phase", "phase", "Intercept"), 0, "no intercept it cannot win")
		equal(#zones(events), 0, "no zone drawn")
		local back
		for _, ev in ipairs(events) do if ev.type == "Phase" and ev.phase == "Stalk" and ev.fallback == "Pursue" then back = ev end end
		assert(back, "falls back to the pursuit")
		for i = 2, #log.steps do
			local a, b = log.steps[i - 1].s, log.steps[i].s
			assert(flat(a.x, a.z, b.x, b.z) <= math.max(T.StalkSpeed, T.ChargeSpeed) * 0.05 + 1e-6, "never a teleport at " .. log.steps[i].t)
		end
	end)

	case("SC5 Scuttler: the intercept run is slower than a rested sprint and goes straight to P", function()
		assert(T.InterceptSpeed < RESTED_SPRINT, "InterceptSpeed below 23.2")
		local w = routeWorld()
		local tgt = target(0, 0)
		local e = spawn("beast:32")
		local events, log = runRoute(e, w, tgt, 8.2, 10, 16)
		local inter = find(events, "Phase", "phase", "Intercept")
		assert(inter, "it intercepts")
		local moved = 0
		for i = 2, #log.steps do
			local a, b = log.steps[i - 1], log.steps[i]
			if b.phase == "Intercept" or (a.phase == "Intercept" and b.phase == "Block") then
				local d = flat(a.s.x, a.s.z, b.s.x, b.s.z)
				assert(d <= T.InterceptSpeed * 0.05 + 1e-6, "faster than InterceptSpeed: " .. d)
				moved += d
			end
		end
		assert(moved > 1, "it ran")
		local block = find(events, "Phase", "phase", "Block")
		assert(block, "it blocks at P")
		near(e.pos.x, inter.to.x, "stands at P (x)", 1e-3); near(e.pos.z, inter.to.z, "stands at P (z)", 1e-3)
		near(block.untilAt - block.at, T.BlockSeconds, "BlockSeconds")
	end)

	case("SC5 Scuttler: entering the zone opens a registered Snap, never before the zone was drawn MIN_TELL", function()
		local w = routeWorld()
		local tgt = target(0, 0)
		local e = spawn("beast:33")
		local events, log = runRoute(e, w, tgt, 11, 10, 16)
		local zone = zones(events)[1]
		assert(zone, "zone")
		local snap = find(events, "Phase", "phase", "Snap")
		assert(snap, "the target ran into the zone: a Snap")
		assert(snap.at >= zone.startAt + Config.MIN_TELL - 1e-9, "the zone was drawn at least MIN_TELL before the Snap")
		local reg
		for _, r in ipairs(w.telegraphs) do if r.id:find(":snap:", 1, true) then reg = reg or r end end
		assert(reg, "the Snap is registered with the dodge")
		near(reg.startAt, snap.at, "registered when it opens")
		equal(reg.accepted, true, "never refused as ShortTelegraph")
		assert(reg.strikeAt - reg.startAt >= T.SnapTelegraphSeconds - 1e-9, "tell at least 0.9 s")
		local tell = find(events, "Tell", "tell", reg.id)
		equal(tell.shape.kind, "sector"); equal(tell.shape.r, T.SnapRadius); equal(tell.shape.arc, T.SnapArc)
		local lockedAt
		for _, ev in ipairs(events) do
			if ev.type == "Tell" and ev.tell == reg.id then
				if ev.locked then lockedAt = lockedAt or ev.at else assert(not lockedAt, "no unlocked redraw after the lock") end
			end
		end
		near(lockedAt, snap.at, "the swipe is fixed when drawn")
		-- At the open the target was inside the zone.
		local at
		for _, s in ipairs(log.steps) do if math.abs(s.t - snap.at) < 1e-6 then at = s end end
		assert(at and flat(at.x, at.z, zone.shape.x, zone.shape.z) <= zone.shape.r + 1e-6, "only when the target enters")
		assert(find(events, "Strike", "tell", reg.id), "the Snap settles once")
		local ended = find(events, "TellEnd", "tell", zone.tell)
		assert(ended, "the zone goes away")
		local after
		for _, ev in ipairs(phases(events)) do if ev.phase == "Stalk" and ev.at > snap.at then after = after or ev end end
		assert(after, "back to the stalk after the Snap")
	end)

	case("SC5 Scuttler: a target that never enters the zone is never snapped; the block ends after BlockSeconds", function()
		local w = routeWorld()
		local tgt = target(0, 0)
		local e = spawn("beast:34")
		local events = runRoute(e, w, tgt, 12, 10, 16, function(_, tg)
			if e.phase == "Intercept" then tg.vx = 0 end -- it stops short, outside the zone
		end)
		local zone = zones(events)[1]
		assert(zone, "zone")
		equal(count(events, "Phase", "phase", "Snap"), 0, "no Snap without entering")
		for _, reg in ipairs(w.telegraphs) do assert(not reg.id:find(":snap:", 1, true), "no Snap registered") end
		local block = find(events, "Phase", "phase", "Block")
		local ended = find(events, "TellEnd", "tell", zone.tell)
		assert(ended, "the zone goes away")
		near(ended.at, block.untilAt, "at the block's end", 0.051)
	end)

	case("SC5 Scuttler: an early dash during the run re-plans once with the new velocity, after ReplanCooldownSeconds", function()
		local w = routeWorld()
		local tgt = target(0, 0)
		local e = spawn("beast:35")
		local pressed, second
		local events, log = runRoute(e, w, tgt, 11, 10, 16, function(t, tg)
			if e.phase == "Intercept" and not pressed then
				pressed = t
				w.dash = t
				tg.vx = 18 -- the dash changed the route
			elseif pressed and not second and t >= pressed + 0.3 then
				second = t
				w.dash = t -- a second press never re-plans again
			end
		end)
		assert(pressed, "pressed during the intercept")
		local list = zones(events)
		local replans = {}
		for _, ev in ipairs(events) do if ev.type == "TellEnd" and ev.reason == "Replan" then table.insert(replans, ev) end end
		equal(#replans, 1, "exactly one re-plan")
		local inter
		for _, ev in ipairs(phases(events)) do if ev.phase == "Intercept" and ev.replan == true then inter = ev end end
		assert(inter, "a re-planned intercept")
		local first = find(events, "Phase", "phase", "Intercept")
		assert(inter.at >= first.at + T.ReplanCooldownSeconds - 1e-9, "not before ReplanCooldownSeconds")
		local s
		for _, st in ipairs(log.steps) do if math.abs(st.t - inter.at) < 1e-6 then s = st end end
		near(inter.to.x, s.x + 18 * T.PredictSeconds, "planned with the new velocity", 1e-3)
		equal(#list, 2, "the new zone is drawn")
		near(list[2].startAt, inter.at, "from the re-plan")
		local snap = find(events, "Phase", "phase", "Snap")
		if snap then assert(snap.at >= list[2].startAt + Config.MIN_TELL - 1e-9, "the new zone is drawn MIN_TELL first") end
	end)

	case("SC5 Scuttler: a press during the read is the one re-plan: presses in the run never re-plan", function()
		local w = routeWorld()
		local tgt = target(0, 0)
		local e = spawn("beast:36")
		local used
		local events = runRoute(e, w, tgt, 11, 10, 16, function(t)
			if e.phase == "Read" or e.phase == "Intercept" or e.phase == "Block" then w.dash = t end -- spam
			if e.phase == "Intercept" then used = e.replans end -- a later move (a pulse, a new read) starts afresh
		end)
		assert(find(events, "Phase", "phase", "Intercept"), "it intercepts")
		equal(count(events, "TellEnd", "reason", "Replan"), 0, "the read already used the re-plan")
		equal(used, T.MaxReplans, "MaxReplans used")
	end)

	case("SC5 Scuttler: never targets a safe zone, a void or a point it cannot see", function()
		for i, setup in ipairs({
			function(w) w.unsafe = function(x) return x > 5 end end, -- P (x about 11.6) is in a safe zone
			function(w) function w.landing() return nil end end, -- no ground at P
			function(w) function w.lineOfSight(_, p) return not (p.x > 5) end end, -- the target is visible, P is not
		}) do
			local w = routeWorld()
			setup(w)
			local tgt = target(0, 0)
			local e = spawn("beast:4" .. i)
			local events = runRoute(e, w, tgt, 9, 10, 16)
			assert(find(events, "Phase", "phase", "Read"), "case " .. i .. ": it read the route")
			equal(count(events, "Phase", "phase", "Intercept"), 0, "case " .. i .. ": no intercept")
			equal(#zones(events), 0, "case " .. i .. ": no zone")
		end
		-- A re-plan into a safe zone falls back to the pursuit.
		local w = routeWorld()
		local tgt = target(0, 0)
		local e = spawn("beast:45")
		local pressed
		local events = runRoute(e, w, tgt, 10, 10, 16, function(t, tg)
			if e.phase == "Intercept" and not pressed then
				pressed = t
				w.dash = t
				w.unsafe = function(x) return x > 14 end
			end
		end)
		assert(pressed, "pressed")
		local zone = zones(events)[1]
		local ended = find(events, "TellEnd", "tell", zone.tell)
		equal(ended.reason, "Replan")
		equal(#zones(events), 1, "no new zone in the safe zone")
		local back
		for _, ev in ipairs(events) do if ev.type == "Phase" and ev.phase == "Stalk" and ev.fallback == "Pursue" then back = ev end end
		assert(back, "falls back to the pursuit")
		equal(count(events, "Phase", "phase", "Block"), 0, "never blocks there")
	end)

	-- Correction (review finding 3): the straight run to P must not cross a safe zone, the Pradera or a wall. The run
	-- goes from about (0, 20) to P (x about 11.6, z 10); a strip at 4 < x < 8 crosses it while P itself stays clear.
	case("SC5 Scuttler: never runs through a safe zone, the Pradera or a wall on the way to P", function()
		for i, setup in ipairs({
			function(w) w.unsafe = function(x) return x > 4 and x < 8 end end, -- a safe zone between Scuttler and P
			function(w) function w.meadow(x) return x > 4 and x < 8 end end, -- the Pradera between Scuttler and P
			function(w) w.wallFrom = 6.0 end, -- a wall at z = 15 across the run, put up after the first charge
		}) do
			local w = routeWorld()
			setup(w)
			local tgt = target(0, 0)
			local e = spawn("beast:47" .. i)
			local events = runRoute(e, w, tgt, 9, 10, 16, function(t)
				if w.wallFrom and t >= w.wallFrom - 1e-9 then w.wallZ = 15 end
			end)
			assert(find(events, "Phase", "phase", "Read"), "case " .. i .. ": it read the route")
			equal(count(events, "Phase", "phase", "Intercept"), 0, "case " .. i .. ": no intercept through it")
			equal(#zones(events), 0, "case " .. i .. ": no zone")
			local back
			for _, ev in ipairs(events) do if ev.type == "Phase" and ev.phase == "Stalk" and ev.fallback == "Pursue" then back = ev end end
			assert(back, "case " .. i .. ": falls back to the pursuit")
		end
	end)

	case("SC5 Scuttler: the first move is still a committed charge, even for a running target", function()
		local w = routeWorld()
		local tgt = target(-20, 0)
		tgt.vx = 16
		local e = spawn("beast:46")
		local events = run(e, w, tgt, 0, 2.5, function(_, tg) tg.x = math.min(tg.x + 0.8, 5) end)
		equal(count(events, "Phase", "phase", "Read"), 0, "no read before the first charge")
		assert(find(events, "Phase", "phase", "ChargeTell"), "the first move is a charge")
	end)

	-- SC6 Pulso de panico. The first charge lands on a still target at the origin and Scuttler backs off to about
	-- (0, 20); the next move is free at 6.6 s. From 6.0 s the target keeps gap(t) studs in front of Scuttler (toward -z),
	-- inside PulseRadiusStuds + 4, so the pulse is that move. `after(t, tg)` may change the target or the world later.
	local function pulseRun(e, w, tgt, to, gap, after)
		local log = { pulses = {} }
		local events = run(e, w, tgt, 0, to, function(t, tg)
			if t >= 6.0 - 1e-9 and gap then
				local g = gap(t)
				if g then tg.x, tg.z = e.pos.x, e.pos.z - g end
			end
			if e.phase == "PulseCharge" then
				local last = log.pulses[#log.pulses]
				if not last or last.at ~= e.phaseAt then
					table.insert(log.pulses, { at = e.phaseAt, s = Attack.copy(e.pos) })
				else
					near(e.pos.x, last.s.x, "the body holds still (x)"); near(e.pos.z, last.s.z, "the body holds still (z)")
				end
			end
			if after then after(t, tg) end
		end)
		return events, log
	end
	local function pulseIds(w)
		local list = {}
		for _, reg in ipairs(w.telegraphs) do if reg.id:find(":pulse:", 1, true) then table.insert(list, reg) end end
		return list
	end
	local function always(g) return function() return g end end
	-- Blocks the line of sight (no charge, no pulse) from the first pulse's release until `seconds` after it.
	local function holdAfterFirstPulse(e, w, seconds)
		local s1
		return function(t)
			if e.phase == "Pulse" and not s1 then s1 = e.phaseAt end
			w.los = not (s1 and t < s1 + seconds - 1e-9)
		end
	end

	case("SC6 Scuttler: the pulse ring is drawn at its real radius from the charge start, registered, and never moves", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = spawn("beast:50")
		local events, log = pulseRun(e, w, tgt, 8.5, always(12))
		local charge = find(events, "Phase", "phase", "PulseCharge")
		assert(charge, "a pulse once the target is close")
		near(charge.at, 6.6, "the move after the first charge's cooldown", 0.051)
		near(charge.untilAt - charge.at, T.PulseChargeSeconds, "PulseChargeSeconds")
		local reg = pulseIds(w)[1]
		assert(reg, "the pulse is registered with the dodge")
		equal(reg.accepted, true, "never refused as ShortTelegraph")
		near(reg.startAt, charge.at, "registered at the charge start")
		near(reg.strikeAt - reg.startAt, T.PulseChargeSeconds, "the strike at the charge's end")
		assert(reg.strikeAt - reg.startAt >= Config.MIN_TELL, "tell at least 0.8 s")
		local first, n = nil, 0
		for _, ev in ipairs(events) do
			if ev.type == "Tell" and ev.tell == reg.id then
				n += 1
				first = first or ev
				equal(ev.shape.kind, "circle"); equal(ev.shape.r, T.PulseRadiusStuds, "the real radius")
				near(ev.shape.x, log.pulses[1].s.x, "centred on Scuttler (x)"); near(ev.shape.z, log.pulses[1].s.z, "centred (z)")
				equal(ev.dodgeable, true)
				near(ev.startAt, charge.at, "the ring's start")
			end
		end
		assert(first and n >= 1, "the ring is drawn")
		near(first.at, charge.at, "drawn from the charge start")
		local locked
		for _, ev in ipairs(events) do if ev.type == "Tell" and ev.tell == reg.id and ev.locked then locked = locked or ev end end
		assert(locked, "the ring is fixed")
		near(locked.at, charge.at, "fixed when drawn")
	end)

	case("SC6 Scuttler: a target outside the ring at the release gets nothing", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = spawn("beast:51")
		local events = pulseRun(e, w, tgt, 8.5, function()
			if e.phase == "PulseCharge" or e.phase == "Pulse" then return T.PulseRadiusStuds + 2 end -- it steps out
			return 12
		end)
		local reg = pulseIds(w)[1]
		assert(reg, "a pulse")
		local strike = find(events, "Strike", "tell", reg.id)
		assert(strike, "the pulse settles once")
		equal(strike.hit, false, "nobody inside")
		near(strike.at, reg.strikeAt, "at the release")
		equal(count(events, "Afflict"), 0, "no slow")
		for _, ev in ipairs(events) do assert(ev.type ~= "Hit" or ev.at < 6.0, "no hit") end
		equal(w.cancelled[#w.cancelled], reg.id, "the registration is cancelled")
		equal(e.lastPulseAt, nil, "an empty ring is no pressure")
	end)

	case("SC6 Scuttler: a target inside the ring is slowed (Afflict), never damaged, even with an egg on the first pulse", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = spawn("beast:52")
		local events = pulseRun(e, w, tgt, 8.5, always(12), function(t, tg) if t >= 6.0 then tg.carryingEgg = true end end)
		local reg = pulseIds(w)[1]
		assert(reg, "a pulse")
		local strike = find(events, "Strike", "tell", reg.id)
		equal(strike.hit, true, "landed")
		local afflict = find(events, "Afflict", "attack", reg.id)
		assert(afflict, "an Afflict, the non-hit outcome")
		near(afflict.at, reg.strikeAt, "at the release")
		near(afflict.slow, T.PulseSlowMultiplier, "the slow multiplier")
		near(afflict.slowSeconds, T.PulseSlowSeconds, "the slow time")
		equal(afflict.shake, true, "the client shakes")
		equal(afflict.pulse, true)
		equal(afflict.damage, nil, "no damage field")
		for _, ev in ipairs(events) do assert(ev.type ~= "Hit" or ev.at < 6.0, "the first pulse never hits") end
		equal(count(events, "Disengage"), 0, "the hunt goes on")
		local release = find(events, "Phase", "phase", "Pulse")
		assert(release, "the release")
		near(release.at, reg.strikeAt)
		local back
		for _, ev in ipairs(phases(events)) do if ev.phase == "Stalk" and ev.at > release.at - 1e-9 then back = back or ev end end
		assert(back, "back to the stalk")
		near(back.at, release.untilAt, "after the release")
	end)

	case("SC6 Scuttler: a perfect press cancels the pulse: no slow, no fall, no pressure", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = spawn("beast:53")
		local events = pulseRun(e, w, tgt, 8.5, always(12), function(t) if t >= 6.0 then w.verdict = "Dodged" end end)
		local reg = pulseIds(w)[1]
		assert(reg, "a pulse")
		equal(find(events, "Strike", "tell", reg.id).dodged, true, "dodged")
		local asked = false
		for _, id in ipairs(w.resolved) do if id == reg.id then asked = true end end
		assert(asked, "the dodge decides")
		equal(count(events, "Afflict"), 0, "no slow")
		for _, ev in ipairs(events) do
			assert(not (ev.type == "Phase" and ev.phase == "Fallen" and ev.at >= 6.0), "the pulse never ends in a fall")
		end
		equal(e.lastPulseAt, nil, "a dodged pulse is no pressure")
	end)

	case("SC6 Scuttler: a second landed pulse inside PressureMemorySeconds with an egg is a damage-0 Hit, then EggDropped", function()
		assert(T.PulseCooldownSeconds + T.PulseChargeSeconds < T.PressureMemorySeconds,
			"the second pulse can land inside the memory")
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = spawn("beast:54")
		local hold = holdAfterFirstPulse(e, w, T.PulseCooldownSeconds)
		local events = pulseRun(e, w, tgt, 20, always(12), function(t, tg)
			if t >= 6.0 then tg.carryingEgg = true end
			hold(t)
		end)
		local regs = pulseIds(w)
		equal(#regs, 2, "two pulses")
		assert(regs[2].startAt >= regs[1].strikeAt + T.PulseCooldownSeconds - 1e-9, "the cooldown holds")
		assert(regs[2].strikeAt - regs[1].strikeAt <= T.PressureMemorySeconds, "inside the memory")
		assert(find(events, "Afflict", "attack", regs[1].id), "the first pulse only slows")
		local hit = find(events, "Hit", "attack", regs[2].id)
		assert(hit, "the second pulse is a Hit (the one egg drop path)")
		equal(hit.damage, 0, "never damage")
		equal(hit.escalated, true); equal(hit.pulse, true)
		-- Correction (review finding 2): the worst pulse still slows. The beast script's landHit applies only the Hit
		-- form of a slow (a table), so the escalated pulse carries that form and no Afflict-only field.
		equal(type(hit.slow), "table", "the Hit form of the slow")
		near(hit.slow.multiplier, T.PulseSlowMultiplier, "the escalated pulse still slows")
		near(hit.slow.seconds, T.PulseSlowSeconds, "for the pulse's slow time")
		equal(hit.slowSeconds, nil, "no stray Afflict-form field on the Hit")
		equal(hit.shake, true, "the client still shakes")
		near(hit.at, regs[2].strikeAt)
		equal(find(events, "Afflict", "attack", regs[2].id), nil, "one outcome")
		local dis = find(events, "Disengage")
		assert(dis, "it disengages")
		equal(dis.reason, "EggDropped")
		near(dis.at, hit.at, "right after the drop")
		local ending = find(events, "End")
		equal(ending.reason, "EggDropped")
		near(ending.at, dis.at + C.disengage, "the retreat")
		for _, reg in ipairs(w.telegraphs) do assert(reg.startAt <= hit.at + 1e-9, "nothing opens after the drop") end
	end)

	case("SC6 Scuttler: no escalation without an egg, with PulseCanDropEgg off, or after the memory ran out", function()
		for i, setup in ipairs({
			{ egg = false, hold = T.PulseCooldownSeconds },
			{ egg = true, hold = T.PulseCooldownSeconds, off = true },
			{ egg = true, hold = T.PressureMemorySeconds - T.PulseChargeSeconds + 0.5 },
		}) do
			local w = fakeWorld()
			local tgt = target(0, 0)
			local e = spawn("beast:6" .. i)
			if setup.off then e.pulseCanDropEgg = false end
			local hold = holdAfterFirstPulse(e, w, setup.hold)
			local events = pulseRun(e, w, tgt, 6.6 + T.PulseChargeSeconds + setup.hold + T.PulseChargeSeconds + 0.6,
				always(12), function(t, tg)
					if t >= 6.0 then tg.carryingEgg = setup.egg end
					hold(t)
				end)
			local regs = pulseIds(w)
			equal(#regs, 2, "case " .. i .. ": two pulses")
			assert(find(events, "Afflict", "attack", regs[2].id), "case " .. i .. ": the second pulse only slows")
			for _, ev in ipairs(events) do assert(ev.type ~= "Hit" or ev.at < 6.0, "case " .. i .. ": no Hit") end
			equal(count(events, "Disengage"), 0, "case " .. i .. ": no disengage")
		end
		equal(T.PulseCanDropEgg, true, "the switch is on (Q2)")
		equal(spawn("beast:69").pulseCanDropEgg, true, "each encounter starts from the switch")
	end)

	case("SC6 Scuttler: the first move is never a pulse, and a target at the stalk band's edge is never pulsed", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = spawn("beast:70", -10) -- spawned well inside the ring's reach
		local events = run(e, w, tgt, 0, 12)
		local list = phases(events)
		local firstMove
		for _, ev in ipairs(list) do
			if ev.phase == "ChargeTell" or ev.phase == "PulseCharge" then firstMove = firstMove or ev.phase end
		end
		equal(firstMove, "ChargeTell", "the first move is a committed charge")
		equal(count(events, "Phase", "phase", "PulseCharge"), 0, "a still target the stalk keeps at 20 studs is out of reach")
	end)

	case("SC6 Scuttler: a landed charge on an egg carrier also ends the hunt (EggDropped), no recovery", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		tgt.carryingEgg = true
		local e = spawn("beast:71")
		local events = run(e, w, tgt, 0, 8)
		local hit = find(events, "Hit")
		assert(hit, "the charge landed")
		local dis = find(events, "Disengage")
		assert(dis, "it disengages")
		equal(dis.reason, "EggDropped")
		assert(dis.at >= hit.at - 1e-9, "after the drop")
		equal(count(events, "Phase", "phase", "Recovery"), 0, "no recovery")
		equal(find(events, "End").reason, "EggDropped")
		equal(#w.telegraphs, 1, "nothing else opens")
	end)

	case("SC6 Scuttler: a safe zone mid-pulse ends it at once; closeAll cancels the ring's registration", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = spawn("beast:72")
		pulseRun(e, w, tgt, 8.5, always(12), function(_, tg) if e.phase == "PulseCharge" then tg.safe = true end end)
		equal(e.endReason, "SafeZone")
		local reg = pulseIds(w)[1]
		assert(reg, "the pulse had opened")
		Attack.closeAll(e, w)
		equal(w.cancelled[#w.cancelled], reg.id, "the registration is cancelled")
		equal(next(e.open), nil, "nothing open")
	end)

	-- SC7 (plan section 7 rule 6): the beast script passes target.siluetaActive (the player's own Silueta hunts or
	-- telegraphs). Scuttler opens no new attack and disengages (reason Silueta) once any open attack has resolved.
	case("SC7 Scuttler: La Silueta mid-tell: the open charge resolves first, then Disengage Silueta; nothing new opens", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		local e = spawn("beast:80")
		local events = run(e, w, tgt, 0, 8, function(_, tg) if e.phase == "ChargeTell" then tg.siluetaActive = true end end)
		local hit = find(events, "Hit")
		assert(hit, "the open charge still resolves")
		local dis = find(events, "Disengage")
		assert(dis, "it yields")
		equal(dis.reason, "Silueta")
		assert(dis.at >= hit.at - 1e-9, "only after the open attack resolved")
		equal(#w.telegraphs, 1, "no new attack opens")
		equal(next(e.open), nil, "nothing left open")
		local ending = find(events, "End")
		assert(ending, "it ends")
		equal(ending.reason, "Silueta")
		near(ending.at, dis.untilAt, "after the retreat", 0.051)
	end)

	case("SC7 Scuttler: La Silueta already hunting: it disengages at once, never opens an attack", function()
		local w = fakeWorld()
		local tgt = target(0, 0)
		tgt.siluetaActive = true
		local e = spawn("beast:81")
		local events = run(e, w, tgt, 0, 3)
		equal(#w.telegraphs, 0, "no attack")
		equal(count(events, "Tell"), 0, "no tell")
		local dis = find(events, "Disengage")
		assert(dis, "it yields")
		equal(dis.reason, "Silueta")
		near(dis.at, 0, "at once")
		equal(e.endReason, "Silueta")
	end)

	case("SC7 Scuttler: La Silueta during an intercept ends the zone (TellEnd Silueta) and disengages", function()
		local w = routeWorld()
		local tgt = target(0, 0)
		local e = spawn("beast:82")
		local events = runRoute(e, w, tgt, 12, 10, 16, function(_, tg)
			if e.phase == "Intercept" then tg.siluetaActive = true end
		end)
		local zone = zones(events)[1]
		assert(zone, "zone")
		local ended = find(events, "TellEnd", "tell", zone.tell)
		assert(ended, "the zone goes away")
		equal(ended.reason, "Silueta")
		equal(find(events, "Disengage").reason, "Silueta")
		equal(count(events, "Phase", "phase", "Snap"), 0, "no Snap opens")
	end)

	case("SC3 Scuttler: the module is pure and server-only", function()
		for _, banned in ipairs({ "workspace", "game:", "task.", "os.clock", "math.random", "Random.new", "Touched", "FireClient" }) do
			assert(not source:find(banned, 1, true), "source uses " .. banned)
		end
	end)

	return result
end

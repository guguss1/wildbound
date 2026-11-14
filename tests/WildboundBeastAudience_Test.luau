-- Invoke with require(freshTestClone)(require(freshBeastAudienceClone), require(freshBeastConfigClone)).
-- SC0 (odd/tasks/wildbound-scuttler.md, docs/design/wildbound-scuttler-plan.md Q4): shared beast visibility. The pure
-- rules that decide which clients see an encounter (the target always; bystanders within Config.AUDIENCE.RADIUS, at
-- most MAX_PER_CLIENT each, La Silueta never) and what a bystander receives (visual events only, effect fields
-- stripped, movement throttled to SNAP_SECONDS). A simulated second player stands in for the two-client check.
return function(Audience, Config)
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
	assert(type(Audience) == "table", "WildboundBeastAudience module")
	local A = Config and Config.AUDIENCE
	local function settings() return A end
	local function enc(id, beast, x, z, target) return { id = id, beast = beast, x = x, z = z, target = target } end
	local function viewer(userId, x, z) return { userId = userId, x = x, z = z } end
	local function pairsOf(list)
		local out = {}
		for _, item in ipairs(list) do table.insert(out, item.id .. "@" .. tostring(item.userId)) end
		table.sort(out)
		return table.concat(out, ",")
	end

	case("SC0 config: the visibility radius is 150 studs with a leave margin, a per-client cap and a 5 Hz bystander snap", function()
		assert(type(A) == "table", "Config.AUDIENCE")
		equal(A.RADIUS, 150, "RADIUS")
		assert(type(A.LEAVE_MARGIN) == "number" and A.LEAVE_MARGIN > 0 and A.LEAVE_MARGIN <= 30, "LEAVE_MARGIN")
		assert(type(A.MAX_PER_CLIENT) == "number" and A.MAX_PER_CLIENT >= 1 and A.MAX_PER_CLIENT <= 8, "MAX_PER_CLIENT")
		equal(A.SNAP_SECONDS, 0.2, "SNAP_SECONDS (5 Hz)")
		assert(type(A.REFRESH_SECONDS) == "number" and A.REFRESH_SECONDS > 0 and A.REFRESH_SECONDS <= 1, "REFRESH_SECONDS")
		assert(table.isfrozen(A), "frozen like the rest of the config")
	end)

	case("SC0 classify: posture, tells, moves and ends are visual; hits and HUD-only events stay with the target", function()
		for _, kind in ipairs({ "Spawn", "Snap", "Phase", "Tell", "TellEnd", "Strike", "Move", "Windup", "Lock", "Dash",
			"Recover", "Telegraph", "Freeze", "Leap", "Land", "Cancel", "Disengage", "End", "Stalk", "Hunt" }) do
			equal(Audience.kind({ type = kind }), "visual", kind)
		end
		for _, kind in ipairs({ "Hit", "Afflict", "Exposure", "SightBreak", "Notice", "Whatever" }) do
			equal(Audience.kind({ type = kind }), "target", kind)
		end
		equal(Audience.kind(nil), "target", "not a table")
		equal(Audience.kind({}), "target", "no type")
	end)

	case("SC0 payload: a bystander copy drops every effect field, is marked, and never changes the target's event", function()
		local event = { type = "Strike", id = "e1", beast = "Root", at = 5, tell = "t1", dodged = true, damage = 20,
			knock = { dx = 1, dz = 0, speed = 30 }, slow = { multiplier = 0.6, seconds = 2 }, sticky = { walkSpeed = 9, seconds = 3 },
			mark = 8, eggDropped = true, line = "Rafaga", hit = true }
		local copy = Audience.forBystander(event)
		assert(copy and copy ~= event, "a copy")
		equal(copy.bystander, true)
		equal(copy.type, "Strike"); equal(copy.id, "e1"); equal(copy.tell, "t1"); equal(copy.at, 5)
		for _, field in ipairs({ "dodged", "damage", "knock", "slow", "sticky", "mark", "eggDropped", "line", "hit" }) do
			equal(copy[field], nil, field)
		end
		equal(event.dodged, true, "the target's event is untouched"); equal(event.bystander, nil)
		equal(Audience.forBystander({ type = "Hit", id = "e1", damage = 20 }), nil, "a hit is never copied")
		equal(Audience.forBystander({ type = "Exposure", id = "e1", value = 0.5 }), nil, "the Gaze meter is the target's HUD")
	end)

	case("SC0 refresh: a second player within 150 studs enters with one spawn; beyond the radius nothing is sent", function()
		local s = Audience.new()
		local encounters = { enc("e1", "Streamer", 0, 0, 1) }
		local enters, leaves = Audience.refresh(s, encounters, { viewer(1, 10, 0), viewer(2, 100, 0), viewer(3, 160, 0) }, settings())
		equal(pairsOf(enters), "e1@2", "only the bystander in range enters")
		equal(#leaves, 0)
		equal(table.concat(Audience.recipients(s, "e1"), ","), "2")
		enters = Audience.refresh(s, encounters, { viewer(1, 10, 0), viewer(2, 100, 0), viewer(3, 160, 0) }, settings())
		equal(#enters, 0, "an existing member never gets a second spawn")
	end)

	case("SC0 refresh: the target is never its own bystander, and La Silueta is personal", function()
		local s = Audience.new()
		local enters = Audience.refresh(s, { enc("e1", "Viper", 0, 0, 1), enc("s1", "Silueta", 0, 0, 1) },
			{ viewer(1, 0, 0), viewer(2, 5, 0) }, settings())
		equal(pairsOf(enters), "e1@2")
		equal(#Audience.recipients(s, "s1"), 0, "Silueta stays target-only")
		equal(Audience.shared("Silueta"), false); equal(Audience.shared("Viper"), true); equal(Audience.shared(nil), false)
	end)

	case("SC0 refresh: a member keeps the beast inside the leave margin and gets one cleanup past it", function()
		local s = Audience.new()
		local encounters = { enc("e1", "Pouncer", 0, 0, 1) }
		Audience.refresh(s, encounters, { viewer(2, 140, 0) }, settings())
		local enters, leaves = Audience.refresh(s, encounters, { viewer(2, A.RADIUS + A.LEAVE_MARGIN - 1, 0) }, settings())
		equal(#enters + #leaves, 0, "inside the margin: no flicker")
		enters, leaves = Audience.refresh(s, encounters, { viewer(2, A.RADIUS + A.LEAVE_MARGIN + 1, 0) }, settings())
		equal(#enters, 0); equal(pairsOf(leaves), "e1@2")
		equal(#Audience.recipients(s, "e1"), 0)
		enters, leaves = Audience.refresh(s, encounters, { viewer(2, A.RADIUS + 5, 0) }, settings())
		equal(#enters + #leaves, 0, "a non-member past the radius does not re-enter")
	end)

	case("SC0 refresh: each client sees at most MAX_PER_CLIENT other beasts, the nearest first", function()
		local s = Audience.new()
		local encounters = {}
		for i = 1, A.MAX_PER_CLIENT + 2 do table.insert(encounters, enc("e" .. i, "Lurker", i * 10, 0, 100 + i)) end
		local enters = Audience.refresh(s, encounters, { viewer(2, 0, 0) }, settings())
		equal(#enters, A.MAX_PER_CLIENT)
		for i = 1, A.MAX_PER_CLIENT do equal(#Audience.recipients(s, "e" .. i), 1, "e" .. i) end
		equal(#Audience.recipients(s, "e" .. (A.MAX_PER_CLIENT + 1)), 0, "the farthest wait")
		-- A nearer beast appearing swaps out the farthest member.
		table.insert(encounters, enc("near", "Root", 1, 0, 999))
		local more, leaves = Audience.refresh(s, encounters, { viewer(2, 0, 0) }, settings())
		equal(pairsOf(more), "near@2"); equal(pairsOf(leaves), "e" .. A.MAX_PER_CLIENT .. "@2")
	end)

	case("SC0 refresh: a viewer who is gone (dead or no body) and an encounter that is gone both clean up", function()
		local s = Audience.new()
		Audience.refresh(s, { enc("e1", "Gaze", 0, 0, 1), enc("e2", "Gaze", 20, 0, 3) }, { viewer(2, 0, 0) }, settings())
		local _, leaves = Audience.refresh(s, { enc("e1", "Gaze", 0, 0, 1) }, {}, settings())
		equal(pairsOf(leaves), "e1@2,e2@2")
		equal(#Audience.recipients(s, "e1") + #Audience.recipients(s, "e2"), 0)
	end)

	case("SC0 close and forget: close returns the bystanders once; a leaving player is dropped everywhere", function()
		local s = Audience.new()
		Audience.refresh(s, { enc("e1", "Viper", 0, 0, 1), enc("e2", "Viper", 5, 0, 1) }, { viewer(2, 0, 0), viewer(3, 0, 0) }, settings())
		equal(table.concat(Audience.close(s, "e1"), ","), "2,3")
		equal(#Audience.close(s, "e1"), 0, "a second close sends nothing")
		Audience.forgetViewer(s, 2)
		equal(table.concat(Audience.recipients(s, "e2"), ","), "3")
	end)

	case("SC0 throttle: a bystander's snapshots run at SNAP_SECONDS, never for a non-member", function()
		local s = Audience.new()
		Audience.refresh(s, { enc("e1", "Streamer", 0, 0, 1) }, { viewer(2, 0, 0) }, settings())
		local sent = 0
		for i = 0, 9 do if Audience.snapDue(s, "e1", 2, 10 + i * 0.1, A.SNAP_SECONDS) then sent += 1 end end
		equal(sent, 5, "1 s of 10 Hz snapshots -> 5 for a bystander")
		equal(Audience.snapDue(s, "e1", 7, 20, A.SNAP_SECONDS), false, "not a member")
		Audience.close(s, "e1")
		equal(Audience.snapDue(s, "e1", 2, 30, A.SNAP_SECONDS), false, "closed")
	end)

	case("SC0 spawn snapshot: a late joiner gets the beast where it is now, in its current phase, marked bystander", function()
		local ev = Audience.spawnFor({ id = "e1", beast = "Root", phase = "Erupt", pos = { x = 1, y = 2, z = 3 }, dx = 0, dz = 1 }, 42)
		equal(ev.type, "Spawn"); equal(ev.id, "e1"); equal(ev.beast, "Root"); equal(ev.at, 42); equal(ev.phase, "Erupt")
		equal(ev.pos.x, 1); equal(ev.pos.y, 2); equal(ev.pos.z, 3); equal(ev.dx, 0); equal(ev.dz, 1)
		equal(ev.bystander, true)
		local leave = Audience.leaveFor("e1", 43)
		equal(leave.type, "End"); equal(leave.id, "e1"); equal(leave.reason, "OutOfRange"); equal(leave.bystander, true)
	end)

	case("SC0 two players (simulated): B near A's beast sees spawn, tells and phases, and never a hit, slow or knock", function()
		local s = Audience.new()
		local inbox = { [1] = {}, [2] = {} }
		local function deliver(event)
			table.insert(inbox[1], event) -- the target always gets the full event
			local copy = Audience.forBystander(event)
			if copy then for _, uid in ipairs(Audience.recipients(s, "e1")) do table.insert(inbox[uid], copy) end end
		end
		local encounters = { enc("e1", "Root", 0, 0, 1) }
		local enters = Audience.refresh(s, encounters, { viewer(1, 0, 10), viewer(2, 60, 0) }, settings())
		for _, item in ipairs(enters) do table.insert(inbox[item.userId], Audience.spawnFor({ id = item.id, beast = "Root",
			phase = "Rise", pos = { x = 0, y = 0, z = 0 }, dx = 0, dz = 1 }, 1)) end
		deliver({ type = "Phase", id = "e1", phase = "TelegraphTrap", at = 2 })
		deliver({ type = "Tell", id = "e1", tell = "t1", shape = { kind = "circle", x = 0, y = 0, z = 0, r = 6 }, at = 2 })
		deliver({ type = "Strike", id = "e1", tell = "t1", at = 3, dodged = false })
		deliver({ type = "Hit", id = "e1", at = 3, damage = 15, slow = { multiplier = 0.6, seconds = 2 } })
		deliver({ type = "End", id = "e1", at = 9, reason = "Done" })
		local kinds = {}
		for _, ev in ipairs(inbox[2]) do
			table.insert(kinds, ev.type)
			equal(ev.bystander, true, ev.type)
			equal(ev.slow, nil); equal(ev.knock, nil); equal(ev.damage, nil)
		end
		equal(table.concat(kinds, ","), "Spawn,Phase,Tell,Strike,End")
		equal(#inbox[1], 5, "the target got every event but its own spawn snapshot")
		equal(inbox[1][4].type, "Hit")
	end)

	-- SC0 correction (review findings 1, 2, 4, 6 and a dead target).
	local function summoned(id, beast, x, z, target)
		local e = enc(id, beast, x, z, target)
		e.summoned = true
		return e
	end
	local function zoned(userId, x, z, fields)
		local v = viewer(userId, x, z)
		for k, value in pairs(fields) do v[k] = value end
		return v
	end

	case("SC0 Pradera: a meadow viewer never gets a forest beast, only a summoned one; a safe-zone viewer gets none", function()
		local s = Audience.new()
		local encounters = { enc("forest", "Viper", 0, 0, 1), summoned("kid", "Nube", 5, 0, 1) }
		local enters = Audience.refresh(s, encounters, { zoned(2, 10, 0, { meadow = true }), zoned(3, 10, 0, { safe = true }),
			viewer(4, 10, 0) }, settings())
		equal(pairsOf(enters), "forest@4,kid@2,kid@4", "the meadow viewer sees the kid beast only; the safe viewer nothing")
		-- A member who walks into the Pradera loses the forest beast at once (no leave margin there).
		local _, leaves = Audience.refresh(s, encounters, { zoned(2, 10, 0, { meadow = true }), zoned(3, 10, 0, { safe = true }),
			zoned(4, 10, 0, { meadow = true }) }, settings())
		equal(pairsOf(leaves), "forest@4")
		equal(table.concat(Audience.recipients(s, "kid"), ","), "2,4", "the summoned beast stays")
		-- And into the safe zone: everything goes.
		_, leaves = Audience.refresh(s, encounters, { zoned(2, 10, 0, { safe = true }), zoned(4, 10, 0, { meadow = true }) }, settings())
		equal(pairsOf(leaves), "kid@2")
	end)

	case("SC0 cap hysteresis: current members keep their place unless a newcomer is nearer by more than the leave margin", function()
		local s = Audience.new()
		local encounters = {}
		for i = 1, A.MAX_PER_CLIENT do table.insert(encounters, enc("m" .. i, "Lurker", 10 * i, 0, 100 + i)) end
		Audience.refresh(s, encounters, { viewer(2, 0, 0) }, settings())
		local far = A.MAX_PER_CLIENT * 10
		-- A non-member slightly nearer than the farthest member: no swap, no End plus Spawn churn.
		table.insert(encounters, enc("close", "Lurker", far - A.LEAVE_MARGIN / 2, 0, 900))
		for _ = 1, 3 do
			local enters, leaves = Audience.refresh(s, encounters, { viewer(2, 0, 0) }, settings())
			equal(#enters + #leaves, 0, "the 4th and 5th trading places never churn")
		end
		-- The order flips back and forth by a stud: still nothing.
		encounters[#encounters].x = far - 1
		local enters, leaves = Audience.refresh(s, encounters, { viewer(2, 0, 0) }, settings())
		equal(#enters + #leaves, 0)
		-- A clearly nearer newcomer does swap out the farthest member.
		table.insert(encounters, enc("near", "Root", 1, 0, 901))
		enters, leaves = Audience.refresh(s, encounters, { viewer(2, 0, 0) }, settings())
		equal(pairsOf(enters), "near@2"); equal(pairsOf(leaves), "m" .. A.MAX_PER_CLIENT .. "@2")
	end)

	case("SC0 late joiner: the replay carries the live tells, lane, circle, walls and move, never an ended one", function()
		local s = Audience.new()
		local function seen(event) Audience.remember(s, "e1", Audience.forBystander(event)) end
		seen({ type = "Phase", id = "e1", phase = "TelegraphWalls", at = 1, untilAt = 3 })
		seen({ type = "Tell", id = "e1", tell = "e1:walls", shape = { kind = "walls" }, startAt = 1, strikeAt = 3, at = 1 })
		seen({ type = "Tell", id = "e1", tell = "e1:trap", shape = { kind = "circle", r = 6 }, startAt = 1, strikeAt = 2, at = 1 })
		seen({ type = "Strike", id = "e1", tell = "e1:trap", at = 2, hit = true })
		seen({ type = "Tell", id = "e1", tell = "e1:gone", shape = { kind = "lane" }, at = 1 })
		seen({ type = "TellEnd", id = "e1", tell = "e1:gone", at = 2 })
		seen({ type = "Windup", id = "e1", origin = { x = 0, y = 0, z = 0 }, dx = 1, dz = 0, length = 20, width = 4, dashAt = 5, at = 4 })
		seen({ type = "Lock", id = "e1", dx = 1, dz = 0, length = 22, at = 4.5 })
		seen({ type = "Telegraph", id = "e1", center = { x = 1, y = 0, z = 1 }, radius = 6, landAt = 6, at = 4 })
		seen({ type = "Move", id = "e1", kind = "slide", from = { x = 0, y = 0, z = 0 }, to = { x = 5, y = 0, z = 0 }, untilAt = 9, at = 4 })
		seen({ type = "Hit", id = "e1", damage = 20, at = 4 }) -- never remembered (not visual)
		local list = Audience.replay(s, "e1", 5)
		local kinds = {}
		for _, ev in ipairs(list) do
			table.insert(kinds, ev.type .. (ev.tell and (":" .. ev.tell) or ""))
			equal(ev.bystander, true, ev.type)
			equal(ev.damage, nil); equal(ev.hit, nil)
		end
		equal(table.concat(kinds, ","), "Phase,Windup,Lock,Telegraph,Tell:e1:walls,Move")
		-- A move that already ended is not replayed (the spawn position is already where it ended).
		equal(#Audience.replay(s, "e1", 10), 5, "the slide ended at 9")
		-- The lane goes on Recover, the circle on Land, everything on Disengage (which itself is replayed).
		seen({ type = "Recover", id = "e1", at = 6 })
		seen({ type = "Land", id = "e1", center = { x = 1, y = 0, z = 1 }, at = 6 })
		kinds = {}
		for _, ev in ipairs(Audience.replay(s, "e1", 6)) do table.insert(kinds, ev.type) end
		equal(table.concat(kinds, ","), "Phase,Tell,Move")
		seen({ type = "Disengage", id = "e1", untilAt = 8, at = 7 })
		kinds = {}
		for _, ev in ipairs(Audience.replay(s, "e1", 7)) do table.insert(kinds, ev.type) end
		equal(table.concat(kinds, ","), "Phase,Disengage", "Disengage clears the tells and the move")
		-- An ended encounter is forgotten.
		Audience.close(s, "e1")
		equal(#Audience.replay(s, "e1", 7), 0)
		-- The server delivers the replay through refresh: spawn first, then the replay.
		seen({ type = "Phase", id = "e1", phase = "Rise", at = 8 })
		local sent = {}
		Audience.refresh(s, { enc("e1", "Root", 0, 0, 1) }, { viewer(2, 0, 0) }, settings(), function(item)
			table.insert(sent, "Spawn")
			for _, ev in ipairs(Audience.replay(s, item.id, 8)) do table.insert(sent, ev.type) end
			return true
		end)
		equal(table.concat(sent, ","), "Spawn,Phase")
	end)

	case("SC0 dead target: bystanders keep the view until the encounter closes, then get one End; the target never joins", function()
		local s = Audience.new()
		local encounters = { enc("e1", "Streamer", 0, 0, 1) }
		Audience.refresh(s, encounters, { viewer(1, 0, 0), viewer(2, 30, 0) }, settings())
		-- The target dies: no living body, so it is no viewer; the encounter is still live until the beast script ends it.
		local enters, leaves = Audience.refresh(s, encounters, { viewer(2, 30, 0) }, settings())
		equal(#enters + #leaves, 0, "the bystander keeps the view")
		equal(table.concat(Audience.close(s, "e1"), ","), "2", "the Death end reaches the bystander once")
		-- The target respawns next to a beast that is not its own: it is a bystander of that one, never of its own.
		enters = Audience.refresh(s, { enc("e1", "Streamer", 0, 0, 1), enc("e2", "Viper", 0, 0, 2) },
			{ viewer(1, 0, 0), viewer(2, 30, 0) }, settings())
		equal(pairsOf(enters), "e1@2,e2@1")
	end)

	case("SC0 commit after send: a member is recorded only after its spawn was delivered; a failed one retries", function()
		local s = Audience.new()
		local encounters = { enc("e1", "Gaze", 0, 0, 1), enc("e2", "Gaze", 5, 0, 1) }
		local enters = Audience.refresh(s, encounters, { viewer(2, 0, 0) }, settings(), function(item)
			if item.id == "e1" then error("send failed") end
			return false -- e2: the viewer was gone
		end)
		equal(#enters, 0, "nothing committed")
		equal(#Audience.recipients(s, "e1") + #Audience.recipients(s, "e2"), 0)
		enters = Audience.refresh(s, encounters, { viewer(2, 0, 0) }, settings(), function() return true end)
		equal(pairsOf(enters), "e1@2,e2@2", "retried on the next refresh")
		equal(table.concat(Audience.recipients(s, "e1"), ","), "2")
	end)

	return result
end

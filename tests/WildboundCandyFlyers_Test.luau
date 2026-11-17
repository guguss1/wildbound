-- Invoke with require(freshTestClone)(require(freshCandyFlyersClone), require(freshCandyLayoutClone), require(freshDodgeClone),
--   { service = <WildboundCandyFlyersService Source>, client = <WildboundCandyFlyersClient Source> }).
-- Caramelo (owner request 2026-11-16, "bichos voladores que te persiguen"): the Zumbidulces, small striped candy bugs
-- with wings that nest in a few hives beside the biome's routes. They hover; a player near a hive wakes the swarm (a
-- tell of at least 0.8 s), it flies at them through the air faster than a sprint, dives one bug at a time after a
-- telegraphed pull-up (a perfect dodge stuns the bug), stings once per dive, recovers, and gives up at the leash, a safe
-- zone, death, leaving the biome, the chase timer or its sting cap; then a cooldown. Damage only through the beasts'
-- BeastHit with the egg kept. Pure rules plus source pins of the service and the client. Changes nothing.
return function(F, Layout, Dodge, sources)
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
	local function lacks(source, needle, label)
		assert(type(source) == "string" and not string.find(source, needle, 1, true), (label or "must not have") .. ": " .. needle)
	end
	local function count(source, needle)
		local n, from = 0, 1
		while true do
			local i = string.find(source, needle, from, true)
			if not i then return n end
			n, from = n + 1, i + #needle
		end
	end
	local function flat(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
	local function kinds(events)
		local out = {}
		for _, e in ipairs(events) do table.insert(out, e.kind) end
		return table.concat(out, ",")
	end
	local function only(events, kind)
		local out = {}
		for _, e in ipairs(events) do if e.kind == kind then table.insert(out, e) end end
		return out
	end

	local FLOOR = 0.5
	local BIG = { x = 0, z = 0, half = 1000 }
	local function hive(id, x, z, n) return { id = id, x = x, z = z, floor = FLOOR, count = n or 3 } end
	local function P(id, x, z, extra)
		local p = { id = id, alive = true, x = x, y = FLOOR + F.ROOT_HEIGHT_STUDS, z = z, vx = 0, vz = 0, safe = false }
		for k, v in pairs(extra or {}) do p[k] = v end
		return p
	end
	local function hitAll() return "Hit" end
	-- A swarm at the origin awake and chasing player 1 standing at (x, z); returns world, the chase time.
	local function chasing(x, z, bounds, noGo)
		local world = F.new({ hive("A", 0, 0) }, 0, bounds or BIG, noGo)
		local wake = F.step(world, 0.1, { P(1, x or 10, z or 0) })
		equal(kinds(wake), "Wake", "woke")
		local t = wake[1].chaseAt
		local go = F.step(world, t, { P(1, x or 10, z or 0) })
		equal(kinds(go), "Chase", "chasing")
		return world, t
	end
	-- Steps the world from `from` by dt until `stop(e, t)` is true for an event or `to` passes. players(t) -> list.
	local function run(world, from, to, dt, players, hooks, stop)
		local t, all = from, {}
		while t < to - 1e-9 do
			t += dt
			for _, e in ipairs(F.step(world, t, players(t), hooks)) do
				table.insert(all, e)
				if stop and stop(e, t) then return all, t end
			end
		end
		return all, t
	end

	case("FL1: numbers and the fair tell", function()
		assert(F.WAKE_TELL_SECONDS >= 0.8, "the wake tell keeps the fair-strike floor")
		assert(F.DIVE_TELL_SECONDS >= 0.8, "the dive tell keeps the fair-strike floor")
		assert(F.DIVE_TELL_SECONDS + F.DIVE_SECONDS >= Dodge.MIN_TELEGRAPH, "the dodge accepts the dive")
		near(F.CRUISE_STUDS_PER_SECOND, 25) -- Deliberately changed (hard tune): 24 -> 25
		near(F.DIVE_GAP_SECONDS, 0.9) -- Deliberately changed (hard tune): 0.5 -> 0.9
		assert(F.CRUISE_STUDS_PER_SECOND > 23.2, "faster than an untrained sprint (23.2)")
		local diveSpeed = F.DIVE_REACH_STUDS / F.DIVE_SECONDS
		assert(diveSpeed > F.CRUISE_STUDS_PER_SECOND and diveSpeed <= 34, "a dive is a short lunge of about 30 studs/s")
		equal(F.MIN_HEIGHT_STUDS, 4); equal(F.MAX_HEIGHT_STUDS, 9)
		for _, h in ipairs({ F.IDLE_HEIGHT_STUDS - F.IDLE_BOB_STUDS, F.IDLE_HEIGHT_STUDS + F.IDLE_BOB_STUDS, F.CHASE_HEIGHT_STUDS,
			F.AIM_HEIGHT_STUDS }) do
			assert(h >= F.MIN_HEIGHT_STUDS and h <= F.MAX_HEIGHT_STUDS, "flies 4 to 9 studs over the floor: " .. h)
		end
		-- Deliberately changed (hard tune): leash 70 -> 110
		near(F.NOTICE_STUDS, 35); near(F.LEASH_STUDS, 110); near(F.CHASE_SECONDS, 14); near(F.COOLDOWN_SECONDS, 12)
		assert(F.LEASH_STUDS > F.NOTICE_STUDS + 20, "the leash leaves room to chase")
		equal(F.DAMAGE, 12); near(F.RECOVER_SECONDS, 1.5); near(F.STUN_SECONDS, 2); near(F.HIT_STUDS, 3)
		assert(F.PUSH_STUDS > 0 and F.PUSH_STUDS <= 12 and F.PUSH_SECONDS >= 0.1 and F.PUSH_SECONDS <= 1, "within the push clamp")
		equal(F.MAX_AWAKE_PER_PLAYER, 2)
		assert(F.MIN_BUGS_PER_HIVE >= 2 and F.MAX_BUGS_PER_HIVE <= 3, "swarms of 2 or 3")
		assert(F.MAX_HIVES * F.MAX_BUGS_PER_HIVE <= F.MAX_BUGS and F.MAX_BUGS <= 15, "a server-wide cap of 15 bugs")
		assert(F.PARTS_PER_BUG <= 8, "each bug at most 8 parts")
		assert(F.STEP_SECONDS >= 1 / 15 - 1e-9 and F.STEP_SECONDS <= 0.1 + 1e-9, "a throttled 10-15 Hz step")
		assert(F.MAX_STINGS * F.DAMAGE * F.MAX_AWAKE_PER_PLAYER < 100, "two swarms cannot defeat a full-health player")
		equal(F.KEEPS_EGG, true, "the egg is never dropped")
		equal(F.BEAST_NAME, "Zumbidulce")
		for _, key in ipairs({ "name", "wake", "home" }) do
			assert(type(F.TEXT[key]) == "string" and #F.TEXT[key] > 0, "TEXT." .. key)
		end
		assert(table.isfrozen(F.TEXT), "TEXT is frozen")
	end)

	case("FL2: the hives: beside the routes, clear of the entrance, the plaza, the tower, the nests and the portal", function()
		local hives = F.hives(Layout, Layout.CENTRE)
		assert(#hives >= 3 and #hives <= F.MAX_HIVES, "a handful of hives: " .. #hives)
		local steps, total = Layout.stairSteps(), 0
		for i, h in ipairs(hives) do
			local lx, lz = h.x - Layout.CENTRE.x, h.z - Layout.CENTRE.z
			near(h.lx, lx, h.id .. " local x"); near(h.lz, lz, h.id .. " local z")
			assert(h.count >= F.MIN_BUGS_PER_HIVE and h.count <= F.MAX_BUGS_PER_HIVE, h.id .. " count")
			total += h.count
			assert(Layout.depth(lx, lz) >= F.EDGE_STUDS, h.id .. " inside the biome")
			assert(flat(lx, lz, Layout.ENTRANCE.x, Layout.ENTRANCE.z) >= math.max(30, F.ENTRANCE_CLEAR_STUDS), h.id .. " entrance")
			assert(flat(lx, lz, Layout.BOSS.x, Layout.BOSS.z) >= Layout.BOSS.plazaRadius + F.PLAZA_MARGIN_STUDS, h.id .. " plaza")
			assert(flat(lx, lz, Layout.TORTA.x, Layout.TORTA.z) >= Layout.TORTA.radius + F.TOWER_CLEAR_STUDS, h.id .. " tower")
			for _, s in ipairs(steps) do assert(flat(lx, lz, s.x, s.z) >= F.STAIR_CLEAR_STUDS, h.id .. " stair") end
			for _, k in ipairs(Layout.KEEP_CLEAR) do assert(flat(lx, lz, k.x, k.z) >= k.r + F.KEEP_CLEAR_MARGIN_STUDS, h.id .. " " .. k.why) end
			assert(flat(lx, lz, Layout.PORTAL.x, Layout.PORTAL.z) >= math.max(40, F.PORTAL_CLEAR_STUDS), h.id .. " portal's quiet area")
			for _, n in ipairs(Layout.NESTS) do assert(flat(lx, lz, n.x, n.z) >= 15, h.id .. " nest " .. n.id) end
			for _, w in ipairs(Layout.LAKE) do assert(flat(lx, lz, w.x, w.z) >= w.r + F.LAKE_MARGIN_STUDS, h.id .. " off the syrup lake") end
			local r = Layout.routeDistance(lx, lz)
			assert(r >= Layout.PATH_WIDTH / 2 + 3 and r <= F.ROUTE_MAX_STUDS, h.id .. " beside a route, off the path: " .. r)
			for j = 1, i - 1 do
				assert(flat(h.x, h.z, hives[j].x, hives[j].z) >= F.HIVE_SPACING_STUDS, h.id .. " spread from " .. hives[j].id)
			end
			equal(h.floor, Layout.FLOOR_TOP, h.id .. " floor")
		end
		assert(total <= F.MAX_BUGS, "the bug cap")
		local again = F.hives(Layout, Layout.CENTRE)
		equal(#again, #hives, "deterministic")
		for i, h in ipairs(hives) do near(again[i].x, h.x); near(again[i].z, h.z) end
		local moved = F.hives(Layout, { x = 0, z = 0 })
		for i, h in ipairs(hives) do near(moved[i].x, h.lx, "a plot centred elsewhere"); near(moved[i].z, h.lz) end
		equal(#F.hives(Layout, Layout.CENTRE, { safe = function() return true end }), 0, "never in a safe zone")
	end)

	case("FL2b: the hives read the layout at run time (new nests, a moved Gran Torta)", function()
		local hives = F.hives(Layout, Layout.CENTRE)
		local first = hives[1]
		local nests = table.clone(Layout.NESTS)
		table.insert(nests, { id = "X1", rarity = "Comun", x = first.lx, z = first.lz })
		local withNest = setmetatable({ NESTS = nests }, { __index = Layout })
		for _, h in ipairs(F.hives(withNest, Layout.CENTRE)) do
			assert(flat(h.lx, h.lz, first.lx, first.lz) >= F.NEST_CLEAR_STUDS, "a new nest pushes the hive away")
		end
		local boss = table.clone(Layout.BOSS)
		boss.x, boss.z = first.lx, first.lz
		local torta = { x = first.lx, z = first.lz, radius = Layout.TORTA.radius * 1.5 }
		local movedTower = setmetatable({ BOSS = boss, TORTA = torta }, { __index = Layout })
		for _, h in ipairs(F.hives(movedTower, Layout.CENTRE)) do
			assert(flat(h.lx, h.lz, boss.x, boss.z) >= boss.plazaRadius + F.PLAZA_MARGIN_STUDS, "off the moved plaza")
			assert(flat(h.lx, h.lz, torta.x, torta.z) >= torta.radius + F.TOWER_CLEAR_STUDS, "off the enlarged tower")
		end
	end)

	case("FL3: idle: they hover and drift round the hive, alive, and wake nobody far away", function()
		local world = F.new({ hive("A", 100, 50, 3) }, 0, BIG)
		local swarm = world.swarms[1]
		equal(#swarm.bugs, 3); equal(swarm.phase, "Idle")
		local before = { x = swarm.bugs[1].x, z = swarm.bugs[1].z }
		for t = 0.1, 3, 0.1 do
			equal(#F.step(world, t, { P(1, 100 + F.NOTICE_STUDS + 5, 50) }), 0, "nothing happens")
			for _, bug in ipairs(swarm.bugs) do
				assert(flat(bug.x, bug.z, 100, 50) <= F.IDLE_RADIUS_STUDS + 1e-6, "round the hive")
				local h = bug.y - FLOOR
				assert(h >= F.MIN_HEIGHT_STUDS and h <= F.MAX_HEIGHT_STUDS, "hovering " .. h)
			end
		end
		assert(flat(before.x, before.z, swarm.bugs[1].x, swarm.bugs[1].z) > 0.5, "it drifts")
	end)

	case("FL4: a player near the hive wakes the swarm: a tell of at least 0.8 s before they fly", function()
		local world = F.new({ hive("A", 0, 0) }, 0, BIG)
		equal(#F.step(world, 0.05, { P(1, F.NOTICE_STUDS + 1, 0) }), 0, "outside the notice radius")
		equal(#F.step(world, 0.1, { P(1, 5, 0, { safe = true }) }), 0, "never on a player in a safe zone")
		equal(#F.step(world, 0.15, { P(1, 5, 0, { alive = false }) }), 0, "never on the dead")
		local wake = F.step(world, 0.2, { P(1, F.NOTICE_STUDS - 1, 0) })
		equal(kinds(wake), "Wake"); equal(wake[1].id, 1); equal(wake[1].swarm, "A")
		near(wake[1].chaseAt - wake[1].at, F.WAKE_TELL_SECONDS, "the tell")
		assert(wake[1].chaseAt - wake[1].at >= 0.8, "fair-strike floor")
		equal(world.swarms[1].phase, "Alert")
		equal(#F.step(world, wake[1].chaseAt - 0.05, { P(1, F.NOTICE_STUDS - 1, 0) }), 0, "still the tell")
		for _, bug in ipairs(world.swarms[1].bugs) do
			assert(flat(bug.x, bug.z, 0, 0) <= F.IDLE_RADIUS_STUDS + 1e-6, "they stay at the hive during the tell")
		end
		equal(kinds(F.step(world, wake[1].chaseAt, { P(1, F.NOTICE_STUDS - 1, 0) })), "Chase")
		equal(world.swarms[1].phase, "Chase")
	end)

	case("FL5: the chase flies through the air at cruise speed, 4 to 9 studs over the floor", function()
		local world, t = chasing(20, 0)
		local dt = 0.05
		for _ = 1, 12 do
			local last = {}
			for i, bug in ipairs(world.swarms[1].bugs) do last[i] = { x = bug.x, y = bug.y, z = bug.z, phase = bug.phase } end
			t += dt
			F.step(world, t, { P(1, 20, 0) }, { resolve = hitAll })
			for i, bug in ipairs(world.swarms[1].bugs) do
				if last[i].phase == "Fly" and bug.phase == "Fly" then
					local moved = math.sqrt((bug.x - last[i].x) ^ 2 + (bug.y - last[i].y) ^ 2 + (bug.z - last[i].z) ^ 2)
					assert(moved <= F.CRUISE_STUDS_PER_SECOND * dt + 1e-6, "cruise speed at most: " .. moved)
				end
				if bug.phase == "Fly" or bug.phase == "Aim" then
					local h = bug.y - FLOOR
					assert(h >= F.MIN_HEIGHT_STUDS - 1e-6 and h <= F.MAX_HEIGHT_STUDS + 1e-6, "flight height " .. h)
				end
			end
		end
		local closest = math.huge
		for _, bug in ipairs(world.swarms[1].bugs) do closest = math.min(closest, flat(bug.x, bug.z, 20, 0)) end
		assert(closest < 10, "they close in on the player")
		-- review F-7: a jump (the root 6 studs up, its grounded height unchanged) never lifts the bugs or the marker
		local before = {}
		for i, bug in ipairs(world.swarms[1].bugs) do before[i] = bug.y end
		t += 0.05
		F.step(world, t, { P(1, 20, 0, { y = FLOOR + F.ROOT_HEIGHT_STUDS + 6, groundY = FLOOR + F.ROOT_HEIGHT_STUDS }) }, { resolve = hitAll })
		for i, bug in ipairs(world.swarms[1].bugs) do
			if bug.phase == "Fly" or bug.phase == "Aim" then
				assert(bug.y - FLOOR <= F.MAX_HEIGHT_STUDS + 1e-6 and bug.y - before[i] <= F.CRUISE_STUDS_PER_SECOND * 0.05 + 1e-6,
					"no snap up on a jump")
			end
			if bug.markY then near(bug.markY, FLOOR, "the marker stays on the floor") end
		end
	end)

	case("FL6: one bug at a time pulls up and telegraphs its dive, stings once, then recovers slowly", function()
		local world, t = chasing(10, 0)
		local resolved = {}
		local hooks = { resolve = function(id, key, at) table.insert(resolved, { id = id, key = key, at = at }) return "Hit" end }
		local tell
		local function busy()
			local n = 0
			for _, bug in ipairs(world.swarms[1].bugs) do if bug.phase == "Aim" or bug.phase == "Dive" then n += 1 end end
			return n
		end
		local events
		events, t = run(world, t, t + 6, 0.05, function() assert(busy() <= 1, "one dive at a time") return { P(1, 10, 0) } end,
			hooks, function(e) return e.kind == "DiveTell" end)
		tell = only(events, "DiveTell")[1]
		assert(tell, "a dive is telegraphed")
		equal(tell.id, 1); equal(tell.swarm, "A")
		near(tell.strikeAt - tell.startAt, F.DIVE_TELL_SECONDS + F.DIVE_SECONDS, "tell then dive")
		assert(tell.strikeAt - tell.startAt >= 0.8, "fair-strike floor")
		local bug = world.swarms[1].bugs[tell.bug]
		equal(bug.phase, "Aim")
		assert(type(bug.markX) == "number" and type(bug.markZ) == "number", "a marker on the floor")
		local pulled = 0
		events, t = run(world, t, t + 3, 0.05, function()
			assert(busy() <= 1, "one dive at a time")
			if bug.phase == "Aim" then pulled = math.max(pulled, bug.y - FLOOR) end
			return { P(1, 10, 0) }
		end, hooks, function(e) return (e.kind == "Hit" or e.kind == "Miss") and e.key == tell.key end)
		assert(pulled >= F.AIM_HEIGHT_STUDS - 0.5, "it pulls up before the dive: " .. pulled)
		assert(only(events, "Dive")[1] and only(events, "Dive")[1].key == tell.key, "the dive follows its tell")
		local hit = only(events, "Hit")[1]
		assert(hit and hit.key == tell.key, "a standing player is stung")
		equal(hit.id, 1); equal(hit.damage, F.DAMAGE); near(hit.studs, F.PUSH_STUDS); near(hit.seconds, F.PUSH_SECONDS)
		equal(hit.keepsEgg, true, "the egg stays")
		assert(hit.at >= tell.strikeAt - 1e-6, "never before the strike time")
		equal(#resolved, 1, "the dodge is asked once"); equal(resolved[1].key, tell.key); equal(resolved[1].id, 1)
		equal(world.swarms[1].stings, 1)
		equal(bug.phase, "Recover"); near(bug.recoverEndsAt, hit.at + F.RECOVER_SECONDS)
		local x, z, y, hits = bug.x, bug.z, bug.y, 0
		while t < bug.recoverEndsAt - 0.06 do
			t += 0.05
			for _, e in ipairs(F.step(world, t, { P(1, 10, 0) }, hooks)) do
				if e.kind == "Hit" and e.key == tell.key then hits += 1 end
			end
			equal(bug.phase, "Recover")
			near(bug.x, x, "no chase while recovering", 1e-6); near(bug.z, z, "", 1e-6)
			assert(bug.y >= y - 1e-6 and bug.y - y <= F.RECOVER_CLIMB_STUDS_PER_SECOND * 0.05 + 1e-6, "a slow climb")
			y = bug.y
		end
		equal(hits, 0, "one sting per dive")
		t = bug.recoverEndsAt + 0.01
		F.step(world, t, { P(1, 10, 0) }, hooks)
		assert(bug.phase ~= "Recover", "recovered")
	end)

	case("FL7: a perfect dodge stuns the bug for 2 s and stings nobody", function()
		local world, t = chasing(10, 0)
		local events
		events, t = run(world, t, t + 8, 0.05, function() return { P(1, 10, 0) } end, { resolve = function() return "Dodged" end },
			function(e) return e.kind == "Dodged" end)
		local dodged = only(events, "Dodged")[1]
		assert(dodged, "the dodge is reported"); equal(dodged.id, 1)
		equal(#only(events, "Hit"), 0, "no sting")
		equal(world.swarms[1].stings, 0)
		local bug = world.swarms[1].bugs[dodged.bug]
		equal(bug.phase, "Stunned"); near(bug.stunEndsAt, dodged.at + F.STUN_SECONDS)
		local x, z = bug.x, bug.z
		F.step(world, dodged.at + F.STUN_SECONDS - 0.05, { P(1, 10, 0) }, { resolve = function() return "Dodged" end })
		equal(bug.phase, "Stunned"); near(bug.x, x, "dizzy in place", 1e-6); near(bug.z, z, "", 1e-6)
		F.step(world, dodged.at + F.STUN_SECONDS + 0.01, { P(1, 10, 0) }, { resolve = function() return "Dodged" end })
		assert(bug.phase == "Fly" or bug.phase == "Aim", "back in the chase: " .. bug.phase)
	end)

	case("FL8: the dive leads a runner; turning back after it locks makes it miss", function()
		local world, t = chasing(10, 0)
		local resolved = 0
		local hooks = { resolve = function() resolved += 1 return "Hit" end }
		local px, vx, key = 10, 0, nil
		local dt, outcome = 0.05, nil
		while t < 20 and not outcome do
			t += dt
			px += vx * dt
			for _, e in ipairs(F.step(world, t, { P(1, px, 0, { vx = vx }) }, hooks)) do
				if e.kind == "DiveTell" and not key then key, vx = e.key, 16 end
				if e.kind == "Dive" and e.key == key then
					near(e.x, px + 16 * F.DIVE_SECONDS, "locked where the runner will be", 0.05)
					vx = -16
				end
				if (e.kind == "Hit" or e.kind == "Miss") and e.key == key then outcome = e end
			end
		end
		assert(outcome, "the dive ended")
		equal(outcome.kind, "Miss", "a juke beats the dive")
		equal(resolved, 0, "a miss never asks the dodge (the service cancels it)")
	end)

	case("FL9: they give up at the leash, a safe zone, death, a leave, the biome's edge, the timer and the sting cap", function()
		local function reasonOf(events) local g = only(events, "GiveUp")[1] return g and g.reason end
		local world, t = chasing(10, 0)
		equal(reasonOf(F.step(world, t + 0.1, { P(1, F.LEASH_STUDS + 1, 0) })), "Leash"); equal(world.swarms[1].phase, "Return")
		world, t = chasing(10, 0)
		equal(reasonOf(F.step(world, t + 0.1, { P(1, 10, 0, { safe = true }) })), "SafeZone")
		world, t = chasing(10, 0)
		equal(reasonOf(F.step(world, t + 0.1, { P(1, 10, 0, { alive = false }) })), "Death")
		world, t = chasing(10, 0)
		equal(reasonOf(F.step(world, t + 0.1, {})), "Gone")
		world, t = chasing(10, 0, { x = 0, z = 0, half = 50 })
		equal(reasonOf(F.step(world, t + 0.1, { P(1, 55, 0) })), "LeftBiome")
		-- never into the boss plaza or the tower (well inside the 110-stud leash), and never woken on someone in there
		local noGo = { { x = 40, z = 0, r = 12 } }
		world, t = chasing(10, 0, nil, noGo)
		equal(reasonOf(F.step(world, t + 0.1, { P(1, 32, 0) })), "NoGoZone")
		local quiet = F.new({ hive("A", 0, 0) }, 0, BIG, noGo)
		equal(#F.step(quiet, 0.1, { P(1, 30, 0) }), 0, "no wake on a player inside a no-go zone")
		-- the real zones follow the Layout: the plaza and the tower with its stair, moved with a moved Torta
		local zones = F.noGoZones(Layout, Layout.CENTRE)
		near(zones[1].x, Layout.CENTRE.x + Layout.BOSS.x); near(zones[1].r, Layout.BOSS.plazaRadius)
		near(zones[2].z, Layout.CENTRE.z + Layout.TORTA.z)
		local stairOut = 0
		for _, s in ipairs(Layout.stairSteps()) do stairOut = math.max(stairOut, flat(s.x, s.z, Layout.TORTA.x, Layout.TORTA.z)) end
		assert(zones[2].r >= stairOut, "the tower's zone covers its stair")
		local moved = F.noGoZones(setmetatable({ TORTA = { x = 50, z = 60, radius = 40 } }, { __index = Layout }), { x = 0, z = 0 })
		near(moved[2].x, 50); near(moved[2].z, 60); near(moved[2].r, 40 + F.TOWER_NO_GO_MARGIN_STUDS)
		-- the timer: every dive dodged, so no sting ends it first
		world, t = chasing(10, 0)
		local chaseAt = t
		local events = run(world, t, t + F.CHASE_SECONDS + 1, 0.05, function() return { P(1, 10, 0) } end,
			{ resolve = function() return "Dodged" end }, function(e) return e.kind == "GiveUp" end)
		local g = only(events, "GiveUp")[1]
		assert(g, "the timer ends it"); equal(g.reason, "Timeout"); near(g.at, chaseAt + F.CHASE_SECONDS, "after 14 s", 0.06)
		-- the sting cap
		world, t = chasing(10, 0)
		events, t = run(world, t, t + F.CHASE_SECONDS, 0.05, function() return { P(1, 10, 0) } end, { resolve = hitAll },
			function(e) return e.kind == "GiveUp" end)
		equal(reasonOf(events), "Satisfied"); equal(#only(events, "Hit"), F.MAX_STINGS, "at most MAX_STINGS per chase")
		-- home, then the cooldown
		local gaveUpAt = only(events, "GiveUp")[1].at
		events, t = run(world, t, t + 10, 0.05, function() return {} end, nil, function(e) return e.kind == "Home" end)
		assert(only(events, "Home")[1], "they fly home"); equal(world.swarms[1].phase, "Cooldown")
		for _, bug in ipairs(world.swarms[1].bugs) do assert(flat(bug.x, bug.z, 0, 0) <= F.IDLE_RADIUS_STUDS + 1, "at the hive") end
		equal(#only(F.step(world, gaveUpAt + F.COOLDOWN_SECONDS - 0.1, { P(1, 10, 0) }), "Wake"), 0, "the cooldown")
		equal(#only(F.step(world, gaveUpAt + F.COOLDOWN_SECONDS + 0.05, { P(1, 10, 0) }), "Wake"), 1, "awake again")
		-- a give-up during a dive's tell cancels it
		world, t = chasing(10, 0)
		events, t = run(world, t, t + 6, 0.05, function() return { P(1, 10, 0) } end, { resolve = hitAll },
			function(e) return e.kind == "DiveTell" end)
		local tell = only(events, "DiveTell")[1]
		assert(tell, "a dive was telegraphed")
		local cancel = F.step(world, t + 0.05, { P(1, 10, 0, { safe = true }) }, { resolve = hitAll })
		local c = only(cancel, "DiveCancel")[1]
		assert(c and c.key == tell.key and c.id == 1, "the open dive is cancelled")
		equal(#only(cancel, "Hit"), 0)
	end)

	-- Escape math, at the service's step. An untrained runner from (ox, oz) along (dx, dz): sprinting 23.2 for
	-- F.UNTRAINED_SPRINT_SECONDS (WildboundStamina's pool), then walking 16; or walking 16 throughout; speed 0 stands.
	local function escape(ox, oz, dx, dz, mode, resolve)
		local world = F.new({ hive("A", 0, 0) }, 0, BIG)
		local dt = F.STEP_SECONDS
		local hits, reason, t = 0, nil, 0
		local S = F.UNTRAINED_SPRINT_SECONDS
		while t < 80 and not reason do
			t += dt
			local s = t - dt -- seconds since the first step
			local d, v = 0, 0
			if mode == "sprint" then
				d, v = 23.2 * math.min(s, S) + 16 * math.max(0, s - S), s < S and 23.2 or 16
			elseif mode == "walk" then
				d, v = 16 * s, 16
			end
			local p = P(1, ox + dx * d, oz + dz * d, { vx = dx * v, vz = dz * v })
			for _, e in ipairs(F.step(world, t, { p }, { resolve = resolve or hitAll })) do
				if e.kind == "Hit" then hits += 1 end
				if e.kind == "GiveUp" then reason = e.reason end
			end
		end
		return hits, reason
	end

	case("FL10: escape math (hard tune): a sprinter passing a hive takes 1-2 stings, 0 with perfect dodges, a walker the cap", function()
		-- a route 16 studs from the hive; the runner is noticed on it and keeps going past
		local off = 16
		local start = -math.sqrt((F.NOTICE_STUDS - 0.5) ^ 2 - off ^ 2)
		local hits, reason = escape(off, start, 0, 1, "sprint")
		assert(hits >= 1 and hits <= F.ESCAPE_MAX_STINGS, "an untrained sprinter passing by: " .. hits .. " stings")
		equal(reason, "Leash")
		hits, reason = escape(off, start, 0, 1, "sprint", function() return "Dodged" end)
		equal(hits, 0, "a sprinter who perfect-dodges every dive"); equal(reason, "Leash")
		hits = escape(off, start, 0, 1, "walk")
		assert(hits >= 2 and hits <= F.MAX_STINGS, "a walker passing by: " .. hits)
		-- running straight away from the notice radius still breaks the 110-stud leash first (the escape that remains)
		hits, reason = escape(F.NOTICE_STUDS - 0.5, 0, 1, 0, "sprint")
		equal(hits, 0, "a straight sprint away from the notice radius"); equal(reason, "Leash")
		-- standing still by the hive: the sting cap
		hits, reason = escape(10, 0, 1, 0, "stand")
		equal(hits, F.MAX_STINGS); equal(reason, "Satisfied")
		assert(100 - F.MAX_AWAKE_PER_PLAYER * F.MAX_STINGS * F.DAMAGE > 0, "even two swarms leave the player standing")
	end)

	case("FL11: caps: two swarms awake per player, five hives and fifteen bugs on the server", function()
		local world = F.new({ hive("A", 0, 0), hive("B", 10, 0), hive("C", 0, 10) }, 0, BIG)
		local first = F.step(world, 0.1, { P(1, 5, 5) })
		equal(#only(first, "Wake"), 2, "at most two swarms on one player")
		equal(world.swarms[3].phase, "Idle")
		local second = F.step(world, 0.2, { P(1, 5, 5), P(2, 5, 5) })
		local w = only(second, "Wake")
		equal(#w, 1); equal(w[1].swarm, "C"); equal(w[1].id, 2, "the third wakes on the other player")
		-- overlapping leashes: a player chased by two swarms runs past a third hive; it stays asleep
		local overlap = F.new({ hive("A", 0, 0), hive("B", 20, 0), hive("C", 80, 0) }, 0, BIG)
		equal(#only(F.step(overlap, 0.1, { P(1, 10, 0) }), "Wake"), 2)
		for t = 0.2, 4, 0.1 do
			equal(#only(F.step(overlap, t, { P(1, 10 + (t - 0.1) * 18, 0) }, { resolve = function() return "Dodged" end }), "Wake"), 0,
				"never a third swarm on one player")
		end
		equal(overlap.swarms[3].phase, "Idle")
		local many = {}
		for i = 1, 7 do table.insert(many, hive("H" .. i, i * 100, 0, 9)) end
		local capped = F.new(many, 0, BIG)
		equal(#capped.swarms, F.MAX_HIVES, "five hives at most")
		local bugs = 0
		for _, s in ipairs(capped.swarms) do
			assert(#s.bugs <= F.MAX_BUGS_PER_HIVE, "three bugs a hive at most")
			bugs += #s.bugs
		end
		assert(bugs <= F.MAX_BUGS, "fifteen bugs at most"); equal(capped.bugs, bugs)
	end)

	case("FL12: wiring: parts, the throttled step, the beasts' damage gate and push, the dodge, the safe zones, no egg path", function()
		local service = sources.service
		has(service, 'require(ServerStorage:WaitForChild("WildboundCandyFlyers"))')
		has(service, 'require(ServerStorage:WaitForChild("WildboundCandyLayout"))')
		has(service, "F.hives(Layout, centre"); has(service, "F.new("); has(service, "F.step(")
		has(service, "F.noGoZones(Layout, centre)", "never into the plaza or the tower")
		-- review F-1 / F-3 / F-4 / F-7
		has(service, "watched(swarm, players)", "idle hives nobody is near do not replicate")
		has(service, "clock - F.STEP_SECONDS", "a real 12 Hz step"); has(service, "task.spawn(sting, player, e)", "a sting never stalls the step")
		has(service, "FloorMaterial", "the grounded height for a jumping player"); has(service, "groundY = ")
		has(service, "workspace:WaitForChild(Layout.ROOT_NAME", "the built biome in big4 and classic")
		has(service, 'Instance.new("Part")', "built from plain parts"); has(service, "Anchored = true")
		has(service, "F.STEP_SECONDS", "the throttled step")
		equal(count(service, "Raycast("), 1, "one floor ray per hive at start, none per step")
		has(service, 'WaitForChild("WildboundNetwork"'); has(service, '"BeastHit"')
		has(service, ":Invoke(player, F.BEAST_NAME, e.damage, F.KEEPS_EGG)", "the damage gate with the egg kept")
		has(service, '"WildboundBeastPush"', "the beasts' one push slot")
		has(service, "Rules.zone(", "safe zones"); has(service, "DodgeService.telegraph("); has(service, "DodgeService.resolve(")
		has(service, "DodgeService.cancel(")
		has(service, "PlayerRemoving"); has(service, "Destroying"); has(service, "BindToClose")
		has(service, '"WildboundBeastEngagedAt"', "the return portal sees the chase")
		lacks(service, "dropEgg"); lacks(service, "StrikeEffect"); lacks(service, "TakeDamage"); lacks(service, "Health -")
		lacks(service, "WildboundBeasts.server"); lacks(service, "SistemaSonriente")
		local client = sources.client
		has(client, "RenderStepped", "client smoothing and wings")
		has(client, 'WaitForChild("WildboundCandyFlyers"')
		lacks(client, "FireServer"); lacks(client, "InvokeServer"); lacks(client, "TakeDamage")
		-- review F-2 / F-5 / F-8 / F-9
		has(client, "local EXTRAPOLATE = 0.35"); has(client, "if not rec.body.Parent then", "re-track a streamed-back body")
		has(client, "sound.SoundGroup = ", "the buzz follows the game's volume"); has(client, "CurrentCamera", "far bugs skipped")
	end)

	case("FL13: the perfect dodge knows the Zumbidulce's dive", function()
		equal(Dodge.SOURCES[F.DODGE_SOURCE], true, "a dodge source")
		local state = Dodge.new()
		equal(Dodge.telegraph(state, F.attackKey("H1", 2, 7), F.DODGE_SOURCE, 10, 10 + F.DIVE_TELL_SECONDS + F.DIVE_SECONDS), true)
		assert(#F.attackKey("H5", 3, 99999) <= 64, "a valid dodge id")
	end)

	return result
end

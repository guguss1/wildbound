-- Caramelo v2 (odd/tasks/wildbound-caramelo-v2.md, CT4): Frutillon, the giant strawberry that guards the Gran Torta's
-- summit (the best egg, CT3). Pure rules: no services, no clock. It sleeps on its rest spot until a player stands on
-- the summit, then rolls round a ring between La Duquesa's seat (the centre) and the edge: a squash and a line on the
-- floor along the arc it will roll (TELL_SECONDS, the fair-strike floor), then the roll toward the player's angle and a
-- little past it, bumping whoever it rolls over outward, off the summit (once per roll); a short recovery and again.
-- Alone for SLEEP_SECONDS it goes back to its rest spot and sleeps. Seeds: while anyone climbs the stair it throws a
-- seed every SEED_EVERY_SECONDS that bounces down the stair step by step, bumping a climber down the stair once.
-- Knockback only: DAMAGE is 0 and nothing here touches the egg. WildboundCandyFrutillonService runs it.
local Frut = {}

-- OF3 (odd/tasks/wildbound-caramelo-playfix.md, owner feedback 3: "sea dificil llegar a la cima de la torta"): a hard
-- but possible climb. Frutillon gets up sooner (wake 2 -> 1.7 s) and rolls again sooner (recover 1 -> 0.7 s); the stair
-- seeds come more often (every 2.5 -> 1.6 s, up to 3 -> 5) and push harder and outward (6 -> 9 studs, off the step:
-- the tier below); two sugar patrols walk stretches of the stair (pausing PATROL_PAUSE_SECONDS at each end, glowing
-- for PATROL_TELL_SECONDS before setting off) and bump a climber outward; a few glaze steps make a climber slip
-- outward. All knockback, damage 0, every tell >= MIN_TELL (0.8 s) and every hazard leaves a gap.
Frut.TELL_SECONDS = 0.8
Frut.RECOVER_SECONDS = 0.7
Frut.SLEEP_SECONDS = 6
-- A2 review (walked Play): woken, he takes this long to get up before his first tell, so La Duquesa's first bubbles
-- (FIRST + WINDUP + FLIGHT = 2.1 s after arriving) pop before his first roll. OF3: 2 -> 1.7 s (his first roll at 2.5 s,
-- still 0.4 s after that pop).
Frut.WAKE_SECONDS = 1.7
Frut.RADIUS_STUDS = 2
Frut.RING_STUDS = 6.3
Frut.REST_ANGLE = math.pi
Frut.ROLL_STUDS_PER_SECOND = 18
Frut.OVERSHOOT_RADIANS = 0.6
Frut.HIT_STUDS = 3
Frut.PUSH_STUDS = 12
Frut.PUSH_SECONDS = 0.4
Frut.SEED_EVERY_SECONDS = 1.6
Frut.SEED_STEPS_PER_SECOND = 8
Frut.SEED_HIT_STUDS = 2
Frut.SEED_PUSH_STUDS = 9
Frut.SEED_PUSH_SECONDS = 0.35
Frut.SEED_OUTWARD = 0.85 -- OF3: the share of a seed's push that goes outward, off the step (the rest down the stair)
Frut.SEED_BOUNCE_STUDS = 1
Frut.MAX_SEEDS = 5
Frut.DAMAGE = 0
-- OF3 patrols: two sugar drops, each on its stretch of the stair (fractions of the path from the top), out of phase.
Frut.PATROL_STRETCHES = table.freeze({ table.freeze({ 0.12, 0.38 }), table.freeze({ 0.55, 0.82 }) })
Frut.PATROL_STEPS_PER_SECOND = 4
Frut.PATROL_PAUSE_SECONDS = 1.4
Frut.PATROL_TELL_SECONDS = 0.8
Frut.PATROL_HIT_STUDS = 2.2
Frut.PATROL_PUSH_STUDS = 9
Frut.PATROL_PUSH_SECONDS = 0.35
-- OF3 glaze: every GLAZE_EVERY-th step from GLAZE_FIRST (never the two top or bottom steps) is glazed; standing on one
-- slips the climber outward (once per GLAZE_COOLDOWN_SECONDS).
Frut.GLAZE_FIRST = 6
Frut.GLAZE_EVERY = 7
Frut.GLAZE_SLIP_STUDS = 5
Frut.GLAZE_SLIP_SECONDS = 0.3
Frut.GLAZE_COOLDOWN_SECONDS = 1.5
Frut.GLAZE_HIT_STUDS = 2

local function flat(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
local function wrap(a) return (a + math.pi) % (2 * math.pi) - math.pi end
-- OF3: the unit direction from the tower's centre to (x, z): off a step, over its ledge, onto the tier below.
local function outward(summit, x, z)
	local dx, dz = x - summit.x, z - summit.z
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-3 then return 1, 0 end
	return dx / length, dz / length
end

-- The summit in world coordinates: { x, z, top (its floor), radius }.
function Frut.summit(Layout)
	local tiers = Layout.TOWER.tiers
	local top = tiers[#tiers]
	return { x = Layout.CENTRE.x + Layout.TORTA.x, z = Layout.CENTRE.z + Layout.TORTA.z, top = Layout.FLOOR_TOP + top.top,
		radius = top.radius, Layout = Layout }
end

-- The stair from the top step down to the floor: { { x, y (the step's top), z } }.
function Frut.seedPath(Layout)
	local steps, path = Layout.stairSteps(), {}
	for i = #steps, 1, -1 do
		local s = steps[i]
		table.insert(path, { x = Layout.CENTRE.x + s.x, y = Layout.FLOOR_TOP + s.top, z = Layout.CENTRE.z + s.z })
	end
	return path
end

function Frut.new(now, summit)
	return { phase = "Asleep", angle = Frut.REST_ANGLE, at = now, seeds = {}, seedCount = 0, nextSeedAt = -math.huge,
		summit = summit }
end

function Frut.position(state, summit)
	return summit.x + math.cos(state.angle) * Frut.RING_STUDS, summit.z + math.sin(state.angle) * Frut.RING_STUDS
end

local function onSummit(p, summit)
	return p.alive == true and type(p.x) == "number" and flat(p.x, p.z, summit.x, summit.z) <= summit.radius + 0.5
		and p.y >= summit.top + 0.5 and p.y <= summit.top + 8
end

local function telegraph(state, now, target, summit, events)
	local wanted = math.atan2(target.z - summit.z, target.x - summit.x)
	local delta = wrap(wanted - state.angle)
	local from = state.angle
	local to = from + delta + (delta >= 0 and 1 or -1) * Frut.OVERSHOOT_RADIANS
	local duration = math.abs(to - from) * Frut.RING_STUDS / Frut.ROLL_STUDS_PER_SECOND
	state.phase, state.fromAngle, state.toAngle = "Telegraph", from, to
	state.rollAt, state.rollEndsAt, state.hit = now + Frut.TELL_SECONDS, now + Frut.TELL_SECONDS + duration, {}
	table.insert(events, { kind = "Telegraph", at = now, fromAngle = from, toAngle = to, rollAt = state.rollAt,
		rollEndsAt = state.rollEndsAt })
end

-- One step of the summit guard. players = { { id, alive, x, y, z } }. Events: Wake, Telegraph, Roll, Hit { id, dx, dz,
-- studs, seconds, damage }, Recover, Sleep.
function Frut.step(state, now, players, summitArg)
	local summit = summitArg or state.summit
	local events = {}
	local fx, fz = Frut.position(state, summit)
	local target, best
	for _, p in ipairs(players) do
		if onSummit(p, summit) then
			local d = flat(p.x, p.z, fx, fz)
			if not best or d < best then target, best = p, d end
		end
	end
	if target then state.lastSeenAt = now end
	if state.phase == "Asleep" then
		if target then
			table.insert(events, { kind = "Wake", at = now })
			state.phase, state.wokeAt = "Waking", now + Frut.WAKE_SECONDS
		end
		return events
	end
	if state.phase == "Waking" then
		if now < state.wokeAt then return events end
		-- awake: the first tell if someone is up there, otherwise he waits (and sleeps again after SLEEP_SECONDS)
		state.phase, state.recoverEndsAt = "Recover", state.wokeAt
	end
	if state.phase == "Telegraph" then
		if now < state.rollAt then return events end
		state.phase = "Roll"
		table.insert(events, { kind = "Roll", at = state.rollAt })
	end
	if state.phase == "Roll" then
		local duration = state.rollEndsAt - state.rollAt
		local t = duration > 0 and math.clamp((now - state.rollAt) / duration, 0, 1) or 1
		state.angle = state.fromAngle + (state.toAngle - state.fromAngle) * t
		local x, z = Frut.position(state, summit)
		for _, p in ipairs(players) do
			if not state.hit[p.id] and onSummit(p, summit) and flat(p.x, p.z, x, z) <= Frut.HIT_STUDS then
				state.hit[p.id] = true
				local ox, oz = p.x - summit.x, p.z - summit.z
				local length = math.sqrt(ox * ox + oz * oz)
				if length < 1e-3 then ox, oz, length = math.cos(state.angle), math.sin(state.angle), 1 end
				table.insert(events, { kind = "Hit", at = now, id = p.id, dx = ox / length, dz = oz / length,
					studs = Frut.PUSH_STUDS, seconds = Frut.PUSH_SECONDS, damage = Frut.DAMAGE })
			end
		end
		if t >= 1 then
			state.angle = wrap(state.toAngle)
			state.phase, state.recoverEndsAt = "Recover", state.rollEndsAt + Frut.RECOVER_SECONDS
			table.insert(events, { kind = "Recover", at = state.rollEndsAt })
		end
		return events
	end
	if state.phase == "Recover" then
		if now < state.recoverEndsAt then return events end
		if target then
			telegraph(state, now, target, summit, events)
		elseif now - (state.lastSeenAt or -math.huge) >= Frut.SLEEP_SECONDS then
			state.phase, state.angle = "Asleep", Frut.REST_ANGLE
			table.insert(events, { kind = "Sleep", at = now })
		end
	end
	return events
end

local function seedAt(seed, now, path)
	local progress = (now - seed.at) * Frut.SEED_STEPS_PER_SECOND + 1
	local i = math.floor(progress)
	if i >= #path then return nil, progress end
	local a, b, f = path[i], path[i + 1], progress - i
	local hop = 4 * f * (1 - f) * Frut.SEED_BOUNCE_STUDS
	return { x = a.x + (b.x - a.x) * f, y = a.y + (b.y - a.y) * f + hop + 0.4, z = a.z + (b.z - a.z) * f, i = i }, progress
end
Frut.seedAt = seedAt

local function onStair(p, path)
	if p.alive ~= true or type(p.x) ~= "number" then return false end
	for _, s in ipairs(path) do
		if flat(p.x, p.z, s.x, s.z) <= 3 and p.y >= s.y - 1 and p.y <= s.y + 6 then return true end
	end
	return false
end

-- The seeds. path = Frut.seedPath(Layout). Events: Seed { seed }, SeedHit { seed, id, dx, dz, studs, seconds, damage },
-- SeedGone { seed }. state.seeds holds the live seeds { id, at, hit }. OF3: with `summit`, the push goes mostly outward.
function Frut.seedStep(state, now, players, path, summit)
	local events = {}
	local climbing = false
	for _, p in ipairs(players) do if onStair(p, path) then climbing = true break end end
	if climbing and now >= state.nextSeedAt and #state.seeds < Frut.MAX_SEEDS then
		state.seedCount += 1
		table.insert(state.seeds, { id = state.seedCount, at = now, hit = {} })
		state.nextSeedAt = now + Frut.SEED_EVERY_SECONDS
		table.insert(events, { kind = "Seed", at = now, seed = state.seedCount })
	end
	local kept = {}
	for _, seed in ipairs(state.seeds) do
		local at = seedAt(seed, now, path)
		if not at then
			table.insert(events, { kind = "SeedGone", at = now, seed = seed.id })
		else
			table.insert(kept, seed)
			for _, p in ipairs(players) do
				if not seed.hit[p.id] and p.alive == true and type(p.x) == "number" and flat(p.x, p.z, at.x, at.z) <= Frut.SEED_HIT_STUDS
					and math.abs(p.y - at.y) <= 4 then
					seed.hit[p.id] = true
					local a, b = path[at.i], path[at.i + 1]
					local dx, dz = b.x - a.x, b.z - a.z
					local length = math.sqrt(dx * dx + dz * dz)
					if length < 1e-3 then dx, dz, length = 1, 0, 1 end
					if summit then -- OF3: mostly outward, off the step (onto the tier below)
						local ox, oz = outward(summit, p.x, p.z)
						dx = dx / length * (1 - Frut.SEED_OUTWARD) + ox * Frut.SEED_OUTWARD
						dz = dz / length * (1 - Frut.SEED_OUTWARD) + oz * Frut.SEED_OUTWARD
						length = math.max(math.sqrt(dx * dx + dz * dz), 1e-3)
					end
					table.insert(events, { kind = "SeedHit", at = now, seed = seed.id, id = p.id, dx = dx / length, dz = dz / length,
						studs = Frut.SEED_PUSH_STUDS, seconds = Frut.SEED_PUSH_SECONDS, damage = Frut.DAMAGE })
				end
			end
		end
	end
	state.seeds = kept
	return events
end

-- OF3 patrols: { id, from, to (path indices, from < to), offset (seconds) }. path = Frut.seedPath(Layout).
function Frut.patrols(path)
	local list = {}
	for i, stretch in ipairs(Frut.PATROL_STRETCHES) do
		local from = math.max(1, math.floor(#path * stretch[1]))
		local to = math.min(#path, math.max(from + 2, math.floor(#path * stretch[2])))
		local leg = (to - from) / Frut.PATROL_STEPS_PER_SECOND
		table.insert(list, { id = i, from = from, to = to, offset = (i - 1) * (leg + Frut.PATROL_PAUSE_SECONDS) })
	end
	return list
end

-- Where patrol `def` is at `now`: { x, y, z, moving, tell (glowing before it sets off), leg (a number per leg) }. A
-- cycle: pause at `from`, walk to `to`, pause, walk back.
function Frut.patrolAt(def, now, path)
	local leg = (def.to - def.from) / Frut.PATROL_STEPS_PER_SECOND
	local half = Frut.PATROL_PAUSE_SECONDS + leg
	local t = now + def.offset
	local n = math.floor(t / half)
	local f = t - n * half
	local forward = n % 2 == 0
	local index, moving, tell
	if f < Frut.PATROL_PAUSE_SECONDS then
		index = forward and def.from or def.to
		moving, tell = false, f >= Frut.PATROL_PAUSE_SECONDS - Frut.PATROL_TELL_SECONDS
	else
		local k = (f - Frut.PATROL_PAUSE_SECONDS) * Frut.PATROL_STEPS_PER_SECOND
		index = forward and def.from + k or def.to - k
		moving, tell = true, false
	end
	local i = math.clamp(math.floor(index), 1, #path)
	local j = math.min(i + 1, #path)
	local u = index - math.floor(index)
	local a, b = path[i], path[j]
	return { x = a.x + (b.x - a.x) * u, y = a.y + (b.y - a.y) * u + 0.9, z = a.z + (b.z - a.z) * u, moving = moving,
		tell = tell, leg = n }
end

-- One step of the patrols. Events: PatrolHit { patrol, id, dx, dz, studs, seconds, damage } (once per leg per player).
function Frut.patrolStep(state, now, players, path, summit)
	local events = {}
	state.patrolHits = state.patrolHits or {}
	state.patrolDefs = state.patrolDefs or Frut.patrols(path)
	for _, def in ipairs(state.patrolDefs) do
		local at = Frut.patrolAt(def, now, path)
		if at.moving then
			for _, p in ipairs(players) do
				local key = def.id .. ":" .. at.leg .. ":" .. tostring(p.id)
				if not state.patrolHits[key] and p.alive == true and type(p.x) == "number"
					and flat(p.x, p.z, at.x, at.z) <= Frut.PATROL_HIT_STUDS and math.abs(p.y - at.y) <= 4 then
					state.patrolHits[key] = true
					local dx, dz = outward(summit, p.x, p.z)
					table.insert(events, { kind = "PatrolHit", at = now, patrol = def.id, id = p.id, dx = dx, dz = dz,
						studs = Frut.PATROL_PUSH_STUDS, seconds = Frut.PATROL_PUSH_SECONDS, damage = Frut.DAMAGE })
				end
			end
		end
	end
	return events
end

-- OF3 glaze: the glazed step indices of the path (never the two top or bottom steps).
function Frut.glazeSteps(path)
	local list = {}
	for i = Frut.GLAZE_FIRST, #path - 2, Frut.GLAZE_EVERY do
		if i > 2 then table.insert(list, i) end
	end
	return list
end

-- One step of the glaze. Events: Slip { step, id, dx, dz, studs, seconds } (once per GLAZE_COOLDOWN_SECONDS per player).
function Frut.glazeStep(state, now, players, path, summit)
	local events = {}
	state.slipFree = state.slipFree or {}
	state.glazed = state.glazed or Frut.glazeSteps(path)
	for _, p in ipairs(players) do
		if p.alive == true and type(p.x) == "number" and now >= (state.slipFree[p.id] or -math.huge) then
			for _, i in ipairs(state.glazed) do
				local s = path[i]
				if flat(p.x, p.z, s.x, s.z) <= Frut.GLAZE_HIT_STUDS and p.y >= s.y - 1 and p.y <= s.y + 5 then
					state.slipFree[p.id] = now + Frut.GLAZE_COOLDOWN_SECONDS
					local dx, dz = outward(summit, p.x, p.z)
					table.insert(events, { kind = "Slip", at = now, step = i, id = p.id, dx = dx, dz = dz,
						studs = Frut.GLAZE_SLIP_STUDS, seconds = Frut.GLAZE_SLIP_SECONDS })
					break
				end
			end
		end
	end
	return events
end

return Frut

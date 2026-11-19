-- A2 (odd/tasks/wildbound-caramelo-playfix.md): La Duquesa Burbuja, seated on the Gran Torta's summit (pack 6 sheet 01,
-- "Bombas de chicle"). Pure rules: no services, no clock. She stays seated; while a player stands on the summit (the
-- same rule as Frutillon) she throws a volley every EVERY_SECONDS (the first FIRST_SECONDS after someone arrives): a
-- Charge (her windup; three rings appear on the summit floor, one on the target and two SPREAD_STUDS beside it, across
-- her line to the target), a Whip WINDUP_SECONDS later (the three bubbles leave her hands and fly slowly), and the pops
-- FLIGHT_SECONDS after that. Whoever stands inside a pop is slowed and pushed away from it, once per volley. Damage 0,
-- nothing about the egg. WildboundCandyDuquesaService runs it.
-- DR (owner request 2026-11-16, "if you take her egg she gets very angry, turns red and chases you very fast"): her
-- RAGE. A player carrying her own egg (the summit nest's, island ISLAND_PREFIX .. Layout.TOWER.summit.id) inside the
-- Caramelo plot makes her roar (ROAR_SECONDS, red), then leave her seat and fly after that one thief at chaseSpeed,
-- HOVER_STUDS over the cake or the floor (never through the tiers). Close enough she opens a lunge (a tell of
-- LUNGE_TELL_SECONDS, never under the fair-strike 0.8 s, dodgeable through the perfect dodge; its aim locks
-- LUNGE_LOCK_SECONDS before the end, D-1): at its end she dashes up to LUNGE_REACH_STUDS to the locked spot; a thief
-- still within LUNGE_HIT_STUDS of where she lands is hit once (LUNGE_DAMAGE, a push, and her egg drops); a
-- perfect dodge stuns her STUN_SECONDS, anything else costs her RECOVER_SECONDS. Between lunges her bubbles keep coming
-- every RAGE_EVERY_SECONDS (the same volley rules). The rage ends when the thief is gone, dead, in a safe zone, without
-- her egg (she calms CALM_SECONDS first), or after RAGE_SECONDS (RC6: 180, a safety end; leaving the plot no longer ends
-- it, she follows the thief to the base); then she floats home (RC6: outside the plot she vanishes and is back on her seat
-- at once) and cannot rage again for COOLDOWN_SECONDS after she sits. One rage at a time: nobody else is chased meanwhile.
-- OQ2 (owner request 2026-11-19, "que la reina de caramelo se enoje y no te deje de perseguir cuando robas el huevo";
-- odd/tasks/wildbound-owner-queue.md): no time limit (RAGE_SECONDS) and no zone margin (V7-D6's LEAVE_MARGIN_STUDS) any
-- more. The rage ends only when the thief is safe (a safe zone or the base: the service's Rules.zone), goes through a
-- portal (p.portal: only the portal service's server stamp, the service's Duq.travelled), no longer carries her egg, or
-- is defeated (dead, or out of the game). Every thief who stole in the plot is remembered (state.thieves), so one who
-- stole while she chased another is chased, anywhere, once she is free again.
local Duq = {}

-- OF3 (owner feedback 3, a hard summit): every 10 -> 6 s on the summit; she also throws at a climber on the upper
-- tiers (UPPER_FROM_TIER and up, within the tower) every UPPER_EVERY_SECONDS, rings on the climber's floor; the rings go
-- where the target will be (LEAD_SECONDS of its velocity, at most LEAD_MAX_STUDS ahead).
Duq.EVERY_SECONDS = 6
Duq.UPPER_EVERY_SECONDS = 8
Duq.UPPER_FROM_TIER = 2 -- the ledge of this tier (from the floor) and everything above it, the summit apart
Duq.UPPER_MARGIN_STUDS = 4 -- past the tower's widest tier: the stair runs outside each tier
Duq.LEAD_SECONDS = 0.5
Duq.LEAD_MAX_STUDS = 5
Duq.FEET_STUDS = 3 -- a root stands this far over its floor
Duq.FIRST_SECONDS = 0.3 -- walked Play: Frutillon bumps a climber off the summit about 1.5 s after arriving
-- A2 review: a short drop off the summit (a Frutillon bump) keeps the 10 s cadence; only REARM_SECONDS with nobody up
-- there starts it again, so the next arrival gets a volley FIRST_SECONDS after arriving
Duq.REARM_SECONDS = 5
Duq.WINDUP_SECONDS = 0.6
Duq.FLIGHT_SECONDS = 1.2
Duq.BUBBLES = 3
Duq.SPREAD_STUDS = 4.5
Duq.POP_RADIUS_STUDS = 3.5
Duq.SLOW_MULTIPLIER = 0.7
Duq.SLOW_SECONDS = 2
Duq.PUSH_STUDS = 4
Duq.PUSH_SECONDS = 0.3
Duq.HANDS_STUDS = 4 -- the bubbles leave her hands this far over her seated base (V7-D1: on the cake's cherry)
Duq.HIT_HEIGHT_STUDS = 8
Duq.DAMAGE = 0

-- DR: the rage. Speeds in studs per second; an untrained egg carrier walks 11 (WildboundLumipolWild.carrySpeed) and
-- sprints 16 (x1.45) for 4 s at most, an untrained runner without an egg sprints 23.2.
Duq.ISLAND_PREFIX = "Candy" -- WildboundCandyNests.ID_PREFIX: her nest is island "CandyT1"
Duq.ROAR_SECONDS = 1 -- red and roaring on her seat before she flies: the thief's head start
Duq.CHASE_SPEED = 27 -- faster than any untrained sprint, so she always closes in
Duq.CHASE_SCALE = 1.25 -- of the thief's own speed when that is faster (a trained player), up to CHASE_CAP
Duq.CHASE_CAP = 34
Duq.HOVER_STUDS = 4 -- over the cake tier or the floor under her (her seat is HOVER_STUDS over the summit)
Duq.RIDE_STUDS = 1.5 -- over the thief's root while she follows (4.5 over its floor)
Duq.VERTICAL_SPEED = 48 -- GT (cake move): 24 -> 48, the summit is 65 studs up (was 40): she still lands on time
Duq.LOOKAHEAD_STUDS = 6 -- she rises for the tier ahead before she reaches its edge
Duq.HOLD_STUDS = 3 -- she never flies closer than this to the thief (flat)
Duq.LUNGE_START_STUDS = 6 -- flat; and within LUNGE_HIT_HEIGHT in height
Duq.LUNGE_TELL_SECONDS = 0.9 -- the fair-strike floor is 0.8 (WildboundDodge.MIN_TELEGRAPH)
-- D-1 (review, decided for the owner): like Don Glaseon's lash lanes, her aim follows the thief during the tell and
-- locks LUNGE_LOCK_SECONDS before the strike, on where a straight runner will be (its velocity, at most
-- LUNGE_LEAD_MAX_STUDS ahead); the dash goes to that locked spot. A sidestep after the lock (or a perfect dodge) beats it.
-- Until the lock she follows at tellSpeed (TELL_SPEED or the thief's own speed, never over chaseSpeed), then she hangs.
Duq.LUNGE_LOCK_SECONDS = 0.35 -- the perfect dodge window (WildboundDodge WINDOW 0.35)
Duq.LUNGE_LEAD_MAX_STUDS = 8
Duq.TELL_SPEED = 12
Duq.LUNGE_REACH_STUDS = 14 -- covers a carrier running straight at up to ~22 studs/s
Duq.LUNGE_HIT_STUDS = 3.5 -- a carrier (11) who stops or turns at the lock ends 3.85+ studs from the locked spot
Duq.LUNGE_HIT_HEIGHT = 8
Duq.LUNGE_DAMAGE = 25 -- never a one-hit kill (MaxHealth 100); damage only where the game allows it (BeastHit)
Duq.LUNGE_PUSH_STUDS = 10
Duq.LUNGE_PUSH_SECONDS = 0.4
Duq.RECOVER_SECONDS = 1.2 -- after a lunge that hit or missed: the escape window
-- D-1: from one strike to the next lunge's start at least this long (she chases and throws meanwhile), so a carrier who
-- sidesteps every lunge needs about as many as one who perfect-dodges them (6 walking; OQ2: no RAGE_SECONDS any more)
Duq.LUNGE_GAP_SECONDS = 3
Duq.STUN_SECONDS = 2.5 -- after a perfect dodge (1.5 asked: frozen, no chase nor bubbles; a walking dodger needs 6)
Duq.RAGE_EVERY_SECONDS = 2.5 -- her bubbles at the thief between lunges (6 s on the summit)
Duq.RAGE_FIRST_VOLLEY_SECONDS = 0.5 -- after she leaves her seat
-- RC6 (owner request 2026-11-16, "they keep chasing you until you reach the base"): RAGE_SECONDS 25 -> 180 is only the
-- safety end now, and leaving the plot no longer ends the rage: she follows her egg's thief to the base (a safe zone).
-- OQ2 (owner request 2026-11-19): RAGE_SECONDS (180) and V7-D6's LEAVE_MARGIN_STUDS (12 past the plot's edge, "Left")
-- are gone: no time limit and no zone margin.
Duq.CALM_SECONDS = 3 -- after her egg dropped, before she floats home
Duq.RETURN_SPEED = 18
Duq.COOLDOWN_SECONDS = 20 -- after she sits again
Duq.DODGE_SOURCE = "DonGlaseon" -- an existing WildboundDodge source (the Caramelo boss family), so that module stays as is

-- Player-facing words (neutral Spanish).
Duq.TEXT = table.freeze({
	furious = "¡La Duquesa está furiosa!",
	calm = "La Duquesa se calmó",
})

local function flat(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
local function unit(x, z)
	local length = math.sqrt(x * x + z * z)
	if length < 1e-6 then return nil end
	return x / length, z / length
end

function Duq.new()
	return { nextAt = nil, volley = 0, pending = nil, mode = nil, rage = nil, her = nil, cooldownUntil = nil, lastAt = nil,
		thieves = {} }
end

-- DR: the island id of her nest (the summit nest of WildboundCandyLayout.TOWER).
function Duq.herIsland(Layout)
	return Duq.ISLAND_PREFIX .. Layout.TOWER.summit.id
end

-- V7-D1 (owner request 2026-11-17, "the princess seated on top of the cake as before, now a red ball covers her"): the
-- GranTorta mesh carries a big cherry on the summit's centre (no collision; its top 11.7 studs over the summit floor,
-- radius about 5.5). She sits on that cherry: her seated base CHERRY_STUDS over the summit floor (her dress rests on it).
Duq.CHERRY_STUDS = 11.4

-- DR: her seat, as a point (world): HOVER_STUDS over her seated base on the cherry (V7-D1), on the summit's centre.
function Duq.seat(summit)
	return { x = summit.x, y = summit.top + Duq.CHERRY_STUDS + Duq.HOVER_STUDS, z = summit.z }
end

-- V4-D10 (owner request 2026-11-17, "the queen seated on top of the cake as before"; the GT cake move left her scenery
-- model over the old summit): her model's pivot is her seated base on the summit floor, HOVER_STUDS under her seat (as
-- placed on the v2 cake: pivot (612, 40.94, -3), the old summit floor at its centre), turned so her front (-Z, the
-- model's LookVector, which the service's flight turns from) faces `facing` ({ x, z } world; nil: west, towards the
-- junction and the plot's entrance). Returns { x, y, z, yaw } (yaw for CFrame.Angles(0, yaw, 0)).
Duq.SEAT_TOLERANCE_STUDS = 3 -- the service re-seats her when her pivot is farther than this from seatPivot
function Duq.seatPivot(summit, facing)
	local seat = Duq.seat(summit)
	local dx, dz = -1, 0
	if type(facing) == "table" and type(facing.x) == "number" and type(facing.z) == "number" then
		local ux, uz = unit(facing.x - seat.x, facing.z - seat.z)
		if ux then dx, dz = ux, uz end
	end
	return { x = seat.x, y = seat.y - Duq.HOVER_STUDS, z = seat.z, yaw = math.atan2(-dx, -dz) }
end
-- V4-D10: whether a model pivot { x, y, z } (world) is off her seat (farther than SEAT_TOLERANCE_STUDS from seatPivot).
function Duq.offSeat(pivot, summit)
	local s = Duq.seatPivot(summit)
	if type(pivot) ~= "table" or type(pivot.x) ~= "number" or type(pivot.y) ~= "number" or type(pivot.z) ~= "number" then
		return false
	end
	return math.sqrt((pivot.x - s.x) ^ 2 + (pivot.y - s.y) ^ 2 + (pivot.z - s.z) ^ 2) > Duq.SEAT_TOLERANCE_STUDS
end

-- DR: the top of the highest cake tier under a world point, else the plot floor (from summit.Layout).
function Duq.floorUnder(summit, x, z)
	local Layout = summit.Layout
	local tiers = Layout.TOWER.tiers
	local r = flat(x, z, summit.x, summit.z)
	for i = #tiers, 1, -1 do
		if r <= tiers[i].radius + 1 then return Layout.FLOOR_TOP + tiers[i].top end
	end
	return Layout.FLOOR_TOP
end

-- DR: studs inside the Caramelo plot from its nearest edge (negative outside), for a world point. GT (cake move) had
-- left the east edge out (the Torta's plaza was 28 studs from it). V8-D3 (owner request 2026-11-17, "another space of
-- the same size, separated by clouds"): every edge counts again; the plaza now ends 54 studs from the east edge
-- (Layout.HALF 260) and the second space lies past it, behind the cloud wall.
-- CL-D15 (Caramelo v9, owner request 2026-11-18, "agranda mas el bioma caramelo a lo largo"): the plot is the rectangle
-- x -HALF..EAST, |z| <= HALF (world x 412..1532), so her depth is Layout.depth of the plot-local point; with the v8
-- square she would "Vanish" east of world x 932. The Torta moved +600 with the east edge: the plaza still ends 53.8
-- studs from it.
function Duq.plotDepth(summit, x, z)
	local Layout = summit.Layout
	return Layout.depth(x - Layout.CENTRE.x, z - Layout.CENTRE.z)
end

-- DR: her chase speed against a thief moving at `thiefSpeed` (its walk speed; nil = untrained).
function Duq.chaseSpeed(thiefSpeed)
	local speed = Duq.CHASE_SPEED
	if type(thiefSpeed) == "number" and thiefSpeed == thiefSpeed then speed = math.max(speed, thiefSpeed * Duq.CHASE_SCALE) end
	return math.min(speed, Duq.CHASE_CAP)
end

-- OQ2: whether her thief went through a portal since `mark`, its last sample { readyAt } (nil: none yet). readyAt is
-- the thief's WildboundPortalReadyAt now: only the portal service writes it, on the server, right after it moves a
-- player home, so a new value is a portal. A jump of the thief's root is never one: that root is moved by the thief's
-- own client (a lag snap or an exploit), and the owner's list names only a portal. Pure; the service samples on the
-- server only.
function Duq.travelled(mark, readyAt)
	if type(mark) ~= "table" then return false end
	return readyAt ~= mark.readyAt
end

-- D-1: her speed during a lunge's tell, until the lock: TELL_SPEED, or the thief's own speed when faster.
function Duq.tellSpeed(thiefSpeed)
	local speed = Duq.TELL_SPEED
	if type(thiefSpeed) == "number" and thiefSpeed == thiefSpeed then speed = math.max(speed, thiefSpeed) end
	return math.min(speed, Duq.chaseSpeed(thiefSpeed))
end

-- DR: "Seated", "Roar", "Chase", "Tell", "Recover", "Stunned", "Calm" or "Return".
function Duq.phase(state)
	if state.mode == "Rage" and state.rage then return state.rage.phase end
	return state.mode or "Seated"
end

-- DR: where she is while away from her seat ({ x, y, z }, world), else nil (seated).
function Duq.position(state)
	return state.her
end

-- The summit rule of WildboundCandyFrutillon: on the top tier's floor, within its radius.
function Duq.onSummit(p, summit)
	return p.alive == true and type(p.x) == "number" and flat(p.x, p.z, summit.x, summit.z) <= summit.radius + 0.5
		and p.y >= summit.top + 0.5 and p.y <= summit.top + 8
end

-- OF3: on the upper tiers of the tower (summit.Layout's TOWER), not on the summit.
function Duq.onUpper(p, summit)
	local Layout = summit.Layout
	if not Layout or p.alive ~= true or type(p.x) ~= "number" then return false end
	local tiers = Layout.TOWER.tiers
	local from = tiers[Duq.UPPER_FROM_TIER]
	return flat(p.x, p.z, summit.x, summit.z) <= tiers[1].radius + Duq.UPPER_MARGIN_STUDS
		and p.y >= Layout.FLOOR_TOP + from.top - 1 and p.y <= summit.top + 8
end

-- One volley at `target`, its rings on floorY, spread across the line from (fromX, fromZ). OF3: aimed where the
-- target will be.
local function throw(state, now, events, target, floorY, fromX, fromZ, rage)
	state.volley += 1
	local tx, tz = target.x, target.z
	if type(target.vx) == "number" and type(target.vz) == "number" then
		local ox, oz = target.vx * Duq.LEAD_SECONDS, target.vz * Duq.LEAD_SECONDS
		local l = math.sqrt(ox * ox + oz * oz)
		if l > Duq.LEAD_MAX_STUDS then ox, oz = ox / l * Duq.LEAD_MAX_STUDS, oz / l * Duq.LEAD_MAX_STUDS end
		tx, tz = tx + ox, tz + oz
	end
	local dx, dz = unit(tx - fromX, tz - fromZ)
	if not dx then dx, dz = 1, 0 end
	local px, pz = -dz, dx
	local spots = { { x = tx, y = floorY, z = tz } }
	for i = 2, Duq.BUBBLES do
		local away = Duq.SPREAD_STUDS * math.ceil((i - 1) / 2) * ((i % 2 == 0) and 1 or -1)
		table.insert(spots, { x = tx + px * away, y = floorY, z = tz + pz * away })
	end
	state.pending = { volley = state.volley, spots = spots, throwAt = now + Duq.WINDUP_SECONDS,
		popAt = now + Duq.WINDUP_SECONDS + Duq.FLIGHT_SECONDS, thrown = false }
	table.insert(events, { kind = "Charge", volley = state.volley, spots = spots, throwAt = state.pending.throwAt,
		popAt = state.pending.popAt, rage = rage })
end

-- DR: she flies toward (tx, ty, tz): flat at `speed` but never closer than `keep`; her height toward the higher of ty
-- and HOVER_STUDS over the cake under her and LOOKAHEAD_STUDS ahead, at VERTICAL_SPEED.
local function fly(summit, her, tx, ty, tz, speed, keep, dt)
	local d = flat(her.x, her.z, tx, tz)
	local move = math.min(speed * dt, math.max(d - keep, 0))
	local ux, uz = unit(tx - her.x, tz - her.z)
	if ux and move > 0 then her.x, her.z = her.x + ux * move, her.z + uz * move end
	local floor = Duq.floorUnder(summit, her.x, her.z)
	if ux and d - move > 0.5 then
		local ahead = math.min(Duq.LOOKAHEAD_STUDS, d - move)
		floor = math.max(floor, Duq.floorUnder(summit, her.x + ux * ahead, her.z + uz * ahead))
	end
	local want = math.max(ty, floor + Duq.HOVER_STUDS)
	local rise = Duq.VERTICAL_SPEED * dt
	her.y += math.clamp(want - her.y, -rise, rise)
end

local function find(players, id)
	for _, p in ipairs(players) do
		if p.id == id then return p end
	end
	return nil
end

-- DR: the rage ends; an open lunge is called off. After her egg dropped she calms CALM_SECONDS first.
local function calm(state, now, events, reason)
	local r = state.rage
	if r.lunge then table.insert(events, { kind = "LungeCancel", lunge = r.lunge.n, id = r.id }) end
	state.mode, state.rage = "Calm", nil
	state.calmUntil = now + (reason == "Dropped" and Duq.CALM_SECONDS or 0)
	table.insert(events, { kind = "Calm", id = r.id, reason = reason, at = now, returnAt = state.calmUntil })
end

-- OQ2 (owner request 2026-11-19): she remembers every thief, not only the one she chases. A carrier of her egg seen
-- alive and not safe inside the plot is marked (state.thieves[id]); the mark goes when that player is seen without her
-- egg, dead, safe or through a portal. A player left out of the step (hidden, concealed in the grass, dead or out of the
-- game) keeps the mark until it is seen again (a respawned or rejoined player carries no egg, so the mark goes).
local function noteThieves(state, players, summit)
	if type(state.thieves) ~= "table" then state.thieves = {} end
	local thieves = state.thieves
	for _, p in ipairs(players) do
		if p.carriesHerEgg == true and p.alive == true and type(p.x) == "number" and p.safe ~= true and p.portal ~= true
			and Duq.plotDepth(summit, p.x, p.z) >= 0 then
			thieves[p.id] = true
		elseif thieves[p.id] and (p.carriesHerEgg ~= true or p.alive ~= true or p.safe == true or p.portal == true) then
			thieves[p.id] = nil
		end
	end
end

-- DR: a carrier of her egg, alive, out of every safe zone, inside the plot, while she sits and her cooldown is over.
-- V5-D2 (Caramelo v5): never a thief hidden in a hide spot (p.hidden).
-- OQ2: or a marked thief anywhere (noteThieves): one who stole while she chased another is chased once she is free.
local function startRage(state, now, events, players, summit)
	if state.mode ~= nil or now < (state.cooldownUntil or -math.huge) then return end
	for _, p in ipairs(players) do
		if p.carriesHerEgg == true and p.alive == true and type(p.x) == "number" and p.safe ~= true and p.hidden ~= true
			and (Duq.plotDepth(summit, p.x, p.z) >= 0 or state.thieves[p.id] == true) then
			state.mode, state.her, state.nextAt = "Rage", Duq.seat(summit), nil
			state.rage = { id = p.id, startAt = now, phase = "Roar", phaseUntil = now + Duq.ROAR_SECONDS, lunges = 0 }
			table.insert(events, { kind = "Rage", id = p.id, at = now, chaseAt = now + Duq.ROAR_SECONDS })
			return
		end
	end
end

local function rageStep(state, now, events, players, summit, resolve, dt)
	local r, her = state.rage, state.her
	local p = find(players, r.id)
	local reason
	if not p then reason = "Gone"
	elseif p.alive ~= true or type(p.x) ~= "number" then reason = "Dead"
	-- OQ2: through a portal (it lands the thief on the base, so it is asked before the safe zone)
	elseif p.portal == true then reason = "Portal"
	elseif p.safe == true then reason = "Safe"
	-- OQ2 (owner request 2026-11-19): no zone end (V7-D6's "Left") and no time end ("Timeout") any more
	elseif p.carriesHerEgg ~= true then reason = "Dropped" end
	if reason then
		calm(state, now, events, reason)
		return
	end
	if r.phase == "Roar" and now >= r.phaseUntil then
		r.phase, r.nextVolleyAt = "Chase", now + Duq.RAGE_FIRST_VOLLEY_SECONDS
	elseif (r.phase == "Recover" or r.phase == "Stunned") and now >= r.phaseUntil then
		r.phase = "Chase"
	end
	local speed, ty = Duq.chaseSpeed(p.speed), p.y + Duq.RIDE_STUDS
	if r.phase == "Chase" then
		fly(summit, her, p.x, ty, p.z, speed, Duq.HOLD_STUDS, dt)
		if now >= (r.nextLungeAt or -math.huge) and flat(her.x, her.z, p.x, p.z) <= Duq.LUNGE_START_STUDS
			and math.abs(her.y - ty) <= Duq.LUNGE_HIT_HEIGHT and p.hidden ~= true then -- V5-D2: no lunge at a hidden thief
			r.lunges += 1
			r.lunge = { n = r.lunges, startAt = now, strikeAt = now + Duq.LUNGE_TELL_SECONDS }
			r.phase = "Tell"
			table.insert(events, { kind = "Lunge", lunge = r.lunge.n, id = p.id, startAt = now, strikeAt = r.lunge.strikeAt,
				x = her.x, y = her.y, z = her.z })
		end
	elseif r.phase == "Tell" then
		local l = r.lunge
		if not l.aimX then
			fly(summit, her, p.x, ty, p.z, Duq.tellSpeed(p.speed), Duq.HOLD_STUDS, dt)
			if now >= l.strikeAt - Duq.LUNGE_LOCK_SECONDS then
				-- D-1: the aim locks on where a straight runner will be at the strike
				local lead, ox, oz = math.max(l.strikeAt - now, 0), 0, 0
				if type(p.vx) == "number" and type(p.vz) == "number" then ox, oz = p.vx * lead, p.vz * lead end
				local length = math.sqrt(ox * ox + oz * oz)
				if length > Duq.LUNGE_LEAD_MAX_STUDS then
					ox, oz = ox / length * Duq.LUNGE_LEAD_MAX_STUDS, oz / length * Duq.LUNGE_LEAD_MAX_STUDS
				end
				l.aimX, l.aimZ, l.aimY = p.x + ox, p.z + oz, ty
				table.insert(events, { kind = "Lock", lunge = l.n, id = p.id, x = l.aimX, y = p.y - Duq.FEET_STUDS, z = l.aimZ,
					strikeAt = l.strikeAt })
			end
		else
			fly(summit, her, her.x, l.aimY, her.z, 0, 0, dt) -- locked: she hangs in the air, only her height settles
		end
		if now >= l.strikeAt then
			local ax, az = l.aimX or p.x, l.aimZ or p.z
			local ux, uz = unit(ax - her.x, az - her.z)
			if not ux then ux, uz = 1, 0 end
			local reach = math.min(Duq.LUNGE_REACH_STUDS, flat(her.x, her.z, ax, az))
			her.x, her.z = her.x + ux * reach, her.z + uz * reach
			-- D-1: the thief is hit only where the dash ends (a sidestep after the lock leaves it there)
			-- V5-D2: a lunge told before the thief hid lands on nothing
			local inReach = flat(her.x, her.z, p.x, p.z) <= Duq.LUNGE_HIT_STUDS and math.abs(her.y - ty) <= Duq.LUNGE_HIT_HEIGHT
				and p.hidden ~= true
			-- the dodge is asked first: a perfect press stuns her even when its dash carried the thief out of reach
			local dodged = resolve ~= nil and resolve(p.id, r.lunge.n, now) == "Dodged"
			local outcome = dodged and "Dodged" or (inReach and "Hit" or "Miss")
			local ev = { kind = "Strike", lunge = r.lunge.n, id = p.id, outcome = outcome, x = her.x, y = her.y, z = her.z }
			if outcome == "Hit" then
				ev.damage, ev.drop = Duq.LUNGE_DAMAGE, true
				ev.dx, ev.dz, ev.studs, ev.seconds = ux, uz, Duq.LUNGE_PUSH_STUDS, Duq.LUNGE_PUSH_SECONDS
			end
			table.insert(events, ev)
			r.lunge = nil
			r.phase = dodged and "Stunned" or "Recover"
			r.phaseUntil = now + (dodged and Duq.STUN_SECONDS or Duq.RECOVER_SECONDS)
			r.nextLungeAt = now + Duq.LUNGE_GAP_SECONDS
		end
	end
	-- her bubbles between lunges (never while she tells a lunge, roars or is stunned)
	if (r.phase == "Chase" or r.phase == "Recover") and r.nextVolleyAt and now >= r.nextVolleyAt and not state.pending
		and p.hidden ~= true then -- V5-D2: no bubbles at a hidden thief
		throw(state, now, events, p, p.y - Duq.FEET_STUDS, her.x, her.z, true)
		r.nextVolleyAt = now + Duq.RAGE_EVERY_SECONDS
	end
end

local function homeStep(state, now, events, summit, dt)
	if state.mode == "Calm" and now >= state.calmUntil then
		state.mode = "Return"
		-- RC6: calmed outside the plot (she chased the thief to the base) she vanishes there (Vanish) and is back on her
		-- seat at once, instead of a long flight home; inside the plot she floats home as before
		local her = state.her
		if her and Duq.plotDepth(summit, her.x, her.z) < 0 then
			table.insert(events, { kind = "Vanish", at = now, x = her.x, y = her.y, z = her.z })
			state.mode, state.her, state.nextAt, state.leftAt = nil, nil, nil, nil
			state.cooldownUntil = now + Duq.COOLDOWN_SECONDS
			table.insert(events, { kind = "Home", at = now, vanished = true })
			return
		end
	end
	if state.mode ~= "Return" then return end
	local seat, her = Duq.seat(summit), state.her
	fly(summit, her, seat.x, seat.y, seat.z, Duq.RETURN_SPEED, 0, dt)
	if flat(her.x, her.z, seat.x, seat.z) <= 0.5 and math.abs(her.y - seat.y) <= 0.6 then
		state.mode, state.her, state.nextAt, state.leftAt = nil, nil, nil, nil
		state.cooldownUntil = now + Duq.COOLDOWN_SECONDS
		table.insert(events, { kind = "Home", at = now })
	end
end

-- One step. players = { { id, alive, x, y, z, vx?, vz?, carriesHerEgg?, safe?, speed?, hidden?, portal? } };
-- summit = Frut.summit(Layout). OQ2: portal = true when the server saw her thief go through a portal (Duq.travelled).
-- V5-D2: a hidden player (hidden = true) never starts a rage and gets no lunge, no bubbles and no hit; her thief who
-- hides is given by the service at the search point round the spot (WildboundCandyHiding), so she searches there.
-- resolve(id, lunge, now) (optional, DR) answers "Dodged" for a lunge the thief perfect-dodged. Events (field kind):
--   Charge { volley, spots = { { x, y, z } }, throwAt, popAt, rage? }   Throw { volley, spots, popAt }
--   Pop { volley, index, x, y, z }   Hit { volley, id, dx, dz, studs, seconds, slow, slowSeconds }
--   DR: Rage { id, at, chaseAt }   Lunge { lunge, id, startAt, strikeAt, x, y, z }   LungeCancel { lunge, id }
--   Lock { lunge, id, x, y, z (the locked spot on the thief's floor), strikeAt }
--   Strike { lunge, id, outcome = "Hit" | "Dodged" | "Miss", x, y, z, and on a Hit: damage, drop, dx, dz, studs, seconds }
--   Calm { id, reason, at, returnAt }   Home { at }
--   OQ2: Calm's reason is "Gone", "Dead", "Portal", "Safe" or "Dropped" (no "Left", no "Timeout")
function Duq.step(state, now, players, summit, resolve)
	local events = {}
	local dt = state.lastAt and math.clamp(now - state.lastAt, 0, 0.25) or 0
	state.lastAt = now
	noteThieves(state, players, summit)
	startRage(state, now, events, players, summit)
	if state.mode == "Rage" then rageStep(state, now, events, players, summit, resolve, dt) end
	if state.mode == "Calm" or state.mode == "Return" then homeStep(state, now, events, summit, dt) end
	if state.mode == nil then
		local target, upper
		-- V5-D2: never at a hidden player
		for _, p in ipairs(players) do
			if p.hidden ~= true and Duq.onSummit(p, summit) then target = target or p end
		end
		if not target then
			for _, p in ipairs(players) do
				if p.hidden ~= true and Duq.onUpper(p, summit) then target, upper = target or p, true end
			end
		end
		if not target then
			state.leftAt = state.leftAt or now
			if now - state.leftAt >= Duq.REARM_SECONDS then state.nextAt = nil end
		else
			state.leftAt = nil
			state.nextAt = state.nextAt or now + Duq.FIRST_SECONDS
			if now >= state.nextAt and not state.pending then
				-- OF3: aimed where the target will be, on its own floor when it climbs the upper tiers
				throw(state, now, events, target, upper and target.y - Duq.FEET_STUDS or summit.top, summit.x, summit.z, nil)
				state.nextAt = now + (upper and Duq.UPPER_EVERY_SECONDS or Duq.EVERY_SECONDS)
			end
		end
	end
	local pending = state.pending
	if pending and not pending.thrown and now >= pending.throwAt then
		pending.thrown = true
		table.insert(events, { kind = "Throw", volley = pending.volley, spots = pending.spots, popAt = pending.popAt })
	end
	if pending and now >= pending.popAt then
		state.pending = nil
		for index, s in ipairs(pending.spots) do
			table.insert(events, { kind = "Pop", volley = pending.volley, index = index, x = s.x, y = s.y, z = s.z })
		end
		for _, p in ipairs(players) do
			if p.alive == true and type(p.x) == "number" and p.hidden ~= true then -- V5-D2: a pop never reaches a hidden player
				for _, s in ipairs(pending.spots) do
					if flat(p.x, p.z, s.x, s.z) <= Duq.POP_RADIUS_STUDS and math.abs(p.y - s.y) <= Duq.HIT_HEIGHT_STUDS then
						local dx, dz = unit(p.x - s.x, p.z - s.z)
						if not dx then dx, dz = unit(p.x - summit.x, p.z - summit.z) end
						if not dx then dx, dz = 1, 0 end
						table.insert(events, { kind = "Hit", volley = pending.volley, id = p.id, dx = dx, dz = dz,
							studs = Duq.PUSH_STUDS, seconds = Duq.PUSH_SECONDS, slow = Duq.SLOW_MULTIPLIER,
							slowSeconds = Duq.SLOW_SECONDS })
						break -- once per volley
					end
				end
			end
		end
	end
	return events
end

return Duq

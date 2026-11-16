-- A2 (odd/tasks/wildbound-caramelo-playfix.md): La Duquesa Burbuja, seated on the Gran Torta's summit (pack 6 sheet 01,
-- "Bombas de chicle"). Pure rules: no services, no clock. She stays seated; while a player stands on the summit (the
-- same rule as Frutillon) she throws a volley every EVERY_SECONDS (the first FIRST_SECONDS after someone arrives): a
-- Charge (her windup; three rings appear on the summit floor, one on the target and two SPREAD_STUDS beside it, across
-- her line to the target), a Whip WINDUP_SECONDS later (the three bubbles leave her hands and fly slowly), and the pops
-- FLIGHT_SECONDS after that. Whoever stands inside a pop is slowed and pushed away from it, once per volley. Damage 0,
-- nothing about the egg. WildboundCandyDuquesaService runs it.
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
Duq.HANDS_STUDS = 4 -- the bubbles leave her hands this far over the summit floor
Duq.HIT_HEIGHT_STUDS = 8
Duq.DAMAGE = 0

local function flat(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
local function unit(x, z)
	local length = math.sqrt(x * x + z * z)
	if length < 1e-6 then return nil end
	return x / length, z / length
end

function Duq.new()
	return { nextAt = nil, volley = 0, pending = nil }
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

-- One step. players = { { id, alive, x, y, z, vx?, vz? } }; summit = Frut.summit(Layout). Events (field kind):
--   Charge { volley, spots = { { x, y, z } }, throwAt, popAt }   Throw { volley, spots, popAt }
--   Pop { volley, index, x, y, z }   Hit { volley, id, dx, dz, studs, seconds, slow, slowSeconds }
function Duq.step(state, now, players, summit)
	local events = {}
	local target, upper
	for _, p in ipairs(players) do
		if Duq.onSummit(p, summit) then target = target or p end
	end
	if not target then
		for _, p in ipairs(players) do
			if Duq.onUpper(p, summit) then target, upper = target or p, true end
		end
	end
	if not target then
		state.leftAt = state.leftAt or now
		if now - state.leftAt >= Duq.REARM_SECONDS then state.nextAt = nil end
	else
		state.leftAt = nil
		state.nextAt = state.nextAt or now + Duq.FIRST_SECONDS
		if now >= state.nextAt and not state.pending then
			state.volley += 1
			-- OF3: aimed where the target will be, on its own floor when it climbs the upper tiers
			local tx, tz = target.x, target.z
			if type(target.vx) == "number" and type(target.vz) == "number" then
				local ox, oz = target.vx * Duq.LEAD_SECONDS, target.vz * Duq.LEAD_SECONDS
				local l = math.sqrt(ox * ox + oz * oz)
				if l > Duq.LEAD_MAX_STUDS then ox, oz = ox / l * Duq.LEAD_MAX_STUDS, oz / l * Duq.LEAD_MAX_STUDS end
				tx, tz = tx + ox, tz + oz
			end
			local floorY = upper and target.y - Duq.FEET_STUDS or summit.top
			local dx, dz = unit(tx - summit.x, tz - summit.z)
			if not dx then dx, dz = 1, 0 end
			local px, pz = -dz, dx
			local spots = { { x = tx, y = floorY, z = tz } }
			for i = 2, Duq.BUBBLES do
				local away = Duq.SPREAD_STUDS * math.ceil((i - 1) / 2) * ((i % 2 == 0) and 1 or -1)
				table.insert(spots, { x = tx + px * away, y = floorY, z = tz + pz * away })
			end
			state.pending = { volley = state.volley, spots = spots, throwAt = now + Duq.WINDUP_SECONDS,
				popAt = now + Duq.WINDUP_SECONDS + Duq.FLIGHT_SECONDS, thrown = false }
			state.nextAt = now + (upper and Duq.UPPER_EVERY_SECONDS or Duq.EVERY_SECONDS)
			table.insert(events, { kind = "Charge", volley = state.volley, spots = spots, throwAt = state.pending.throwAt,
				popAt = state.pending.popAt })
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
			if p.alive == true and type(p.x) == "number" then
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

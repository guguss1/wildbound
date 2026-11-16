-- Muro de chocolate, Don Glaseon's chocolate wall (odd/tasks/wildbound-caramelo-v2.md, DG3; user decision 2026-11-15).
-- Pure server rules. When a target runs away from him out of the lash's reach, he raises a ring of chocolate wall around
-- the spot it is running to (LEAD_SECONDS ahead, at most MAX_LEAD_STUDS), with one wide exit sideways to the route, on
-- the side away from him. The ring is the shared "walls" shape (WildboundBeastConfig.enclosure's layout): the beast
-- client draws it flat as a crack line from the start, raises it at upAt, makes it solid on the target's own client only
-- and leaves open any piece that would rise inside the player, so nobody is ever sealed in. It never hits.
-- Timeline from Wall.start: 1.0 s of crack line; 3 s up; then 14 s of cooldown.
-- Every number is a starting proposal to tune in play. Rules: WildboundCandyDonGlaseonWall_Test.
local Wall = {}
Wall.TELEGRAPH_SECONDS = 1.0
Wall.HOLD_SECONDS = 3
Wall.COOLDOWN_SECONDS = 14
Wall.RADIUS_STUDS = 9
Wall.GAP_DEGREES = 140 -- the exit's full opening, seen from the ring's centre
Wall.LEAD_SECONDS = 0.5
Wall.MAX_LEAD_STUDS = 8
Wall.MIN_SPEED = 10 -- only on a runner
Wall.AWAY_COSINE = 0.5 -- the run must point away from him at least this much
Wall.OUT_OF_REACH_SECONDS = 1
Wall.RANGE_STUDS = 30
local EPSILON = 1e-6

local function unit(dx, dz)
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-9 then return nil end
	return dx / length, dz / length
end

function Wall.start(now, creature)
	if type(creature) == "table" and creature.pet == true then return nil, "Pet" end
	return { startedAt = now }
end

function Wall.upAt(state) return state.startedAt + Wall.TELEGRAPH_SECONDS end
function Wall.downAt(state) return Wall.upAt(state) + Wall.HOLD_SECONDS end

function Wall.phase(state, now)
	if now < Wall.upAt(state) - EPSILON then return "Crack" end
	if now < Wall.downAt(state) - EPSILON then return "Up" end
	return "Done"
end

-- The ring for a target running away from a boss standing on origin, or nil when the target is not a runner (too slow,
-- not running away, dead or in a safe zone). target = { x, y, z, vx, vz, alive, safe }.
function Wall.place(origin, target)
	if not target or target.alive ~= true or target.safe == true then return nil end
	local vx, vz = target.vx or 0, target.vz or 0
	local speed = math.sqrt(vx * vx + vz * vz)
	if speed < Wall.MIN_SPEED then return nil end
	local rx, rz = unit(vx, vz)
	local ax, az = unit(target.x - origin.x, target.z - origin.z)
	if not ax or rx * ax + rz * az < Wall.AWAY_COSINE - EPSILON then return nil end
	local lead = math.min(speed * Wall.LEAD_SECONDS, Wall.MAX_LEAD_STUDS)
	local cx, cz = target.x + rx * lead, target.z + rz * lead
	-- the exit: sideways to the route, on the side away from him
	local gx, gz = -rz, rx
	if gx * (origin.x - cx) + gz * (origin.z - cz) > 0 then gx, gz = -gx, -gz end
	local half = math.rad(Wall.GAP_DEGREES / 2)
	-- y is the boss's ground; the beast module puts it on the ground under the ring
	return { kind = "walls", x = cx, y = origin.y or 0, z = cz, r = Wall.RADIUS_STUDS, gx = gx, gz = gz,
		gap = 2 * Wall.RADIUS_STUDS * math.sin(half),
		list = { { from = half, to = math.pi }, { from = math.pi, to = 2 * math.pi - half } } }
end

-- The exit's real width: the chord between the two wall ends.
function Wall.exitWidth(shape)
	return 2 * shape.r * math.sin(shape.list[1].from)
end

-- Whether a new wall may rise: never before the cooldown since the last one went down.
function Wall.canStart(lastDownAt, now)
	return lastDownAt == nil or now - lastDownAt >= Wall.COOLDOWN_SECONDS - EPSILON
end

return Wall

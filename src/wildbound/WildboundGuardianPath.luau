-- Pure route following for La Silueta (delivery C2, docs/mechanics/wildbound-guardian.md). The world script asks
-- PathfindingService for a route around the solid trunk cores and hands the waypoints in; this module decides when a
-- new plan is worth asking for, which waypoint to steer to, and when the guardian has stalled. Positions are plain
-- numbers and the clock is injected. Numbers are hypotheses to tune in play.
local Path = {}

Path.CONSTANTS = table.freeze({
	REPATH_DISTANCE = 3, -- the goal moved this far from the planned goal: plan again
	MIN_INTERVAL = 0.5, -- never ask for plans more often than this
	RETRY_SECONDS = 1, -- wait after a failed plan
	REACH = 2, -- a waypoint this close counts as reached
	STALL_SECONDS = 1.5, -- no progress toward the current waypoint for this long is a stall
	PROGRESS = 0.5, -- studs of progress that count
})
local C = Path.CONSTANTS

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function distance(ax, az, bx, bz)
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

function Path.new()
	return { serial = 0, pending = false, points = nil, index = 1, goal = nil, request = nil,
		plannedAt = -math.huge, failedAt = -math.huge, best = math.huge, progressAt = 0,
		counters = { plans = 0, failures = 0, stalls = 0, arrivals = 0 } }
end

-- Whether to ask for a new route to (goalX, goalZ) now.
function Path.needsPlan(state, goalX, goalZ, now)
	if state.pending or not finite(goalX) or not finite(goalZ) or not finite(now) then return false end
	if now - state.plannedAt < C.MIN_INTERVAL or now - state.failedAt < C.RETRY_SECONDS then return false end
	if not state.points then return true end
	return distance(goalX, goalZ, state.goal.x, state.goal.z) > C.REPATH_DISTANCE
end

-- A plan was requested. Returns its serial; only that serial's result is accepted.
function Path.begin(state, goalX, goalZ, now)
	state.serial += 1
	state.pending, state.plannedAt, state.request = true, now, { x = goalX, z = goalZ }
	state.counters.plans += 1
	return state.serial
end

-- The planner answered. points = { { x, z }, ... } in walking order. Returns whether the answer was current.
function Path.finish(state, serial, ok, points, now)
	if serial ~= state.serial or not state.pending then return false end
	state.pending = false
	local valid = ok == true and type(points) == "table" and #points > 0
	if valid then
		for _, point in ipairs(points) do
			if type(point) ~= "table" or not finite(point.x) or not finite(point.z) then valid = false break end
		end
	end
	if not valid then
		state.counters.failures += 1
		state.failedAt, state.points = finite(now) and now or state.failedAt, nil
		return true
	end
	state.points, state.index, state.goal = points, 1, state.request
	state.best, state.progressAt = math.huge, finite(now) and now or 0
	return true
end

-- Drops the route and any answer still on its way.
function Path.clear(state)
	state.serial += 1
	state.pending, state.points, state.goal = false, nil, nil
end

-- The point to walk toward this step, or nil when there is no route, it has arrived, or it has just stalled.
function Path.steer(state, gx, gz, now)
	local points = state.points
	if not points or not finite(gx) or not finite(gz) or not finite(now) then return nil end
	while state.index <= #points and distance(gx, gz, points[state.index].x, points[state.index].z) <= C.REACH do
		state.index += 1
		state.best, state.progressAt = math.huge, now
	end
	if state.index > #points then
		state.counters.arrivals += 1
		state.points = nil
		return nil
	end
	local point = points[state.index]
	local away = distance(gx, gz, point.x, point.z)
	if away < state.best - C.PROGRESS then
		state.best, state.progressAt = away, now
	elseif now - state.progressAt >= C.STALL_SECONDS then
		state.counters.stalls += 1
		state.points, state.plannedAt = nil, -math.huge
		return nil
	end
	return point.x, point.z
end

-- Expedition relief (R5): the body's height over the ground at (x, z). `ground` is a function (x, z) -> Y, usually
-- WildboundRelief's heightAt; without one, or with a broken reading, the floor top 0.5 is used.
local FLOOR_TOP = 0.5
function Path.lift(ground, x, z, offset)
	local y = type(ground) == "function" and ground(x, z) or FLOOR_TOP
	if not finite(y) then y = FLOOR_TOP end
	return y + (finite(offset) and offset or 0)
end

-- One step of `length` studs measured on the ground plane from (x, z) along (dirX, dirZ), lifted to the ground at
-- its end. A slope never shortens or refuses a step here: only colliding geometry, cast by the world script with
-- the relief excluded, can block it. Returns nil for a bad start or no direction.
function Path.groundStep(x, z, dirX, dirZ, length, ground, offset)
	if not finite(x) or not finite(z) or not finite(dirX) or not finite(dirZ) or not finite(length) then return nil end
	local size = math.sqrt(dirX * dirX + dirZ * dirZ)
	if size < 1e-9 then return nil end
	local nx, nz = x + dirX / size * length, z + dirZ / size * length
	return nx, Path.lift(ground, nx, nz, offset), nz
end

return Path

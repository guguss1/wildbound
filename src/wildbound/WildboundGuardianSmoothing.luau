-- Pure client presentation smoothing for a pose the server moves in fixed steps. It never decides
-- gameplay: the server keeps the real position. See docs/ui/wildbound-world.md for how it is applied.
local Smoothing = {}

-- Hypotheses. DEFAULT_INTERVAL is the server step (WildboundWorld.server.luau fixed 0.2 s step).
-- SNAP_DISTANCE is above two night hunt steps (1.6 studs each) and far below any teleport.
Smoothing.CONSTANTS = table.freeze({
	DEFAULT_INTERVAL = 0.2,
	MIN_INTERVAL = 0.1,
	MAX_INTERVAL = 0.4,
	MAX_GAP = 0.6,
	BLEND = 0.5,
	SNAP_DISTANCE = 6,
})

local CONSTANTS = Smoothing.CONSTANTS

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function Smoothing.new()
	return {}
end

function Smoothing.reset(state)
	if type(state) ~= "table" then return end
	state.from, state.to, state.startedAt, state.duration = nil, nil, nil, nil
	state.lastAt, state.interval = nil, nil
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- Shortest way round, so a turn across the wrap never spins through zero.
local function lerpAngle(a, b, t)
	local delta = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + delta * t
end

-- Returns x, y, z, yaw, or nothing before the first pose. A bad clock shows the latest pose.
function Smoothing.sample(state, now)
	if type(state) ~= "table" or type(state.to) ~= "table" then return nil end
	local from, to = state.from, state.to
	local fraction = 1
	if finite(now) and state.duration > 0 then
		fraction = math.clamp((now - state.startedAt) / state.duration, 0, 1)
	end
	return lerp(from.x, to.x, fraction), lerp(from.y, to.y, fraction), lerp(from.z, to.z, fraction),
		lerpAngle(from.yaw, to.yaw, fraction)
end

-- Record a pose the server just applied. Returns false when the input is unusable or the pose is
-- the one already held, so a repeated sample can never restart the slide.
function Smoothing.observe(state, now, x, y, z, yaw)
	if type(state) ~= "table" or not (finite(now) and finite(x) and finite(y) and finite(z) and finite(yaw)) then
		return false
	end
	local pose = { x = x, y = y, z = z, yaw = yaw }
	local held = state.to
	if not held then
		state.from, state.to, state.startedAt = pose, pose, now
		state.duration, state.interval, state.lastAt = CONSTANTS.DEFAULT_INTERVAL, CONSTANTS.DEFAULT_INTERVAL, now
		return true
	end
	if held.x == x and held.y == y and held.z == z and held.yaw == yaw then return false end
	local gap = now - state.lastAt
	state.lastAt = now
	if gap > 0 and gap <= CONSTANTS.MAX_GAP then
		local target = math.clamp(gap, CONSTANTS.MIN_INTERVAL, CONSTANTS.MAX_INTERVAL)
		state.interval = state.interval + (target - state.interval) * CONSTANTS.BLEND
	else
		-- A pause, a clock that stepped back or a repeated instant: start again from the server step.
		state.interval = CONSTANTS.DEFAULT_INTERVAL
	end
	local cx, cy, cz, cyaw = Smoothing.sample(state, now)
	local reach = math.sqrt((cx - x) ^ 2 + (cz - z) ^ 2)
	if reach > CONSTANTS.SNAP_DISTANCE then
		state.from = pose
	else
		state.from = { x = cx, y = cy, z = cz, yaw = cyaw }
	end
	state.to, state.startedAt, state.duration = pose, now, state.interval
	return true
end

return Smoothing

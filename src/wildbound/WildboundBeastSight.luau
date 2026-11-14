-- Wave 2 (odd/tasks/wildbound-beasts-wave2.md, BW2-6): the camera observation Gaze and Lurker read. The camera is local
-- to each client, so the target's client sends its look direction over BeastObserve, at most every SEND_INTERVAL and
-- only while it draws a Gaze or a Lurker. The server keeps one state per player and checks everything here: the rate,
-- the payload's shape and a unit vector. The cone starts at the server's own head position (never a client position),
-- the line of sight is the server's raycast, and the answer only steers a beast's behaviour (Gaze's exposure, Lurker's
-- pause): it never deals damage and never grants a perfect dodge (WildboundDodgeService decides that from the press).
-- When the data is briefly stale (lag, a dropped frame) the caller passes the answer that favours the player; when no
-- data has arrived for FALLBACK seconds the server uses the body's facing, so not sending is never an advantage.
-- Shared and pure: plain { x, y, z } tables, no services, the clock is passed in.
local Sight = {}

Sight.SEND_INTERVAL = 0.2 -- the client sends at most 5 per second
Sight.MIN_INTERVAL = 0.1 -- the server accepts at most 10 per second; the rest are dropped and counted
Sight.FRESH = 0.6 -- seconds a camera observation stays current
Sight.FALLBACK = 2 -- seconds without a current observation before the body's facing is used
Sight.UNIT_TOLERANCE = 0.05

local function finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Sight.new()
	return { look = nil, lastAt = -math.huge, dropped = 0, bad = 0, accepted = 0 }
end

-- One client message. Returns true, or false and "BadState", "BadClock", "Rate", "BadPayload" or "BadVector".
function Sight.accept(state, now, payload)
	if type(state) ~= "table" then return false, "BadState" end
	if not finite(now) then return false, "BadClock" end
	if now - state.lastAt < Sight.MIN_INTERVAL then
		state.dropped += 1
		return false, "Rate"
	end
	if type(payload) ~= "table" then
		state.bad += 1
		return false, "BadPayload"
	end
	local x, y, z = payload.x, payload.y, payload.z
	if not finite(x) or not finite(y) or not finite(z) then
		state.bad += 1
		return false, "BadVector"
	end
	local length = math.sqrt(x * x + y * y + z * z)
	if math.abs(length - 1) > Sight.UNIT_TOLERANCE then
		state.bad += 1
		return false, "BadVector"
	end
	state.look = { x = x / length, y = y / length, z = z / length }
	state.lastAt = now
	state.accepted += 1
	return true
end

-- The view direction to use now: ("camera", look) while the client's is current; ("stale", nil) for a short gap, when
-- the caller picks the answer that favours the player; ("body", bodyLook) after FALLBACK seconds with no current data.
function Sight.view(state, now, bodyLook)
	if type(state) == "table" and state.look and finite(now) and now - state.lastAt <= Sight.FRESH then
		return "camera", state.look
	end
	local since = type(state) == "table" and finite(now) and now - state.lastAt or math.huge
	if since <= Sight.FALLBACK then return "stale", nil end
	return "body", bodyLook
end

-- Whether a point is within halfAngle degrees of the direction from origin, and within maxDist studs.
function Sight.inCone(origin, dir, point, halfAngle, maxDist)
	if type(origin) ~= "table" or type(dir) ~= "table" or type(point) ~= "table" then return false end
	local vx, vy, vz = point.x - origin.x, point.y - origin.y, point.z - origin.z
	local distance = math.sqrt(vx * vx + vy * vy + vz * vz)
	if not finite(distance) or distance > maxDist then return false end
	if distance < 1e-6 then return true end
	local dl = math.sqrt(dir.x * dir.x + dir.y * dir.y + dir.z * dir.z)
	if not finite(dl) or dl < 1e-6 then return false end
	local cosine = (vx * dir.x + vy * dir.y + vz * dir.z) / (distance * dl)
	return math.deg(math.acos(math.clamp(cosine, -1, 1))) <= halfAngle + 1e-9
end

-- Whether the player observes the point now. q = { origin (the server's head), bodyLook, point, halfAngle, maxDist,
-- los (the server's line of sight, boolean), favour (the answer during a short gap) }. Returns the answer and its
-- source ("camera", "stale" or "body"). No line of sight is never an observation.
function Sight.observes(state, now, q)
	if type(q) ~= "table" then return false, "none" end
	local source, dir = Sight.view(state, now, q.bodyLook)
	if source == "stale" then return q.favour == true and q.los == true, source end
	if q.los ~= true or not dir then return false, source end
	return Sight.inCone(q.origin, dir, q.point, q.halfAngle, q.maxDist), source
end

return Sight

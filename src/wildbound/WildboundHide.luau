-- Pure hiding rules (delivery D5), server only. A hidden player cannot be acquired or struck; the guardian
-- finds one only by standing near the spot for a dwell time. Numbers are hypotheses from
-- docs/mechanics/wildbound-delivery-d.md section 3. No services, no clock: time and positions are injected.
local Hide = {}

Hide.CONFIG = table.freeze({
	DISCOVER = table.freeze({
		Day = table.freeze({ radius = 4, dwell = 2.0 }),
		Dusk = table.freeze({ radius = 5, dwell = 1.6 }),
		Dawn = table.freeze({ radius = 5, dwell = 1.6 }),
		Night = table.freeze({ radius = 6, dwell = 1.2 }),
	}),
	DECAY = 2, -- outside the radius the dwell timer falls this many times faster than it grows
	MAX_STAY = 45,
	COOLDOWN = 8,
	EXIT_DISTANCE = 5.5, -- half the 5-stud zone plus 3 studs
	PROMPT_DISTANCE = 7,
	PROMPT_HOLD = 0.4,
})
local C = Hide.CONFIG
-- Modes that walk around and can stumble on a spot. Alert, Hunt and Telegraph count only when the quarry is
-- someone else: a hunt on this player has already lost sight of them.
local WANDER = { Patrol = true, Suspicious = true, Investigate = true, Search = true, Retreat = true }
local COMBAT = { Alert = true, Hunt = true, Telegraph = true }

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- canEnter({ alive, capturing, occupied, seen, cooldownUntil, now }) -> true | false, reason
function Hide.canEnter(ctx)
	if type(ctx) ~= "table" or ctx.alive ~= true then return false, "Dead" end
	if ctx.capturing == true then return false, "Capturing" end
	if ctx.occupied == true then return false, "Occupied" end
	if ctx.seen == true then return false, "Seen" end
	if finite(ctx.cooldownUntil) and finite(ctx.now) and ctx.now < ctx.cooldownUntil then return false, "Cooldown" end
	return true, nil
end

function Hide.newDwell()
	return { dwell = 0 }
end

-- discover(state, { dt, mode, distance, phase, targetIsMe }) -> true when the hidden player is found.
function Hide.discover(state, input)
	if type(state) ~= "table" or type(input) ~= "table" then return false end
	local dt, distance = input.dt, input.distance
	if not finite(dt) or dt <= 0 or dt > 5 then return false end
	if not finite(state.dwell) then state.dwell = 0 end
	local looking = WANDER[input.mode] or (COMBAT[input.mode] and input.targetIsMe ~= true)
	local rule = C.DISCOVER[input.phase] or C.DISCOVER.Day
	if looking and finite(distance) and distance >= 0 and distance <= rule.radius then
		state.dwell += dt
	else
		state.dwell = math.max(0, state.dwell - C.DECAY * dt)
	end
	return state.dwell >= rule.dwell - 1e-6
end

function Hide.tooLong(enteredAt, now)
	return finite(enteredAt) and finite(now) and now - enteredAt >= C.MAX_STAY
end

function Hide.cooldownUntil(now)
	return (finite(now) and now or 0) + C.COOLDOWN
end

-- Where to stand on leaving: EXIT_DISTANCE from the spot centre, on the side away from the guardian.
function Hide.exitPoint(x, z, guardianX, guardianZ)
	local dx, dz = 1, 0
	if finite(guardianX) and finite(guardianZ) then
		local ax, az = x - guardianX, z - guardianZ
		local length = math.sqrt(ax * ax + az * az)
		if length > 1e-3 then dx, dz = ax / length, az / length end
	end
	return { x = x + dx * C.EXIT_DISTANCE, z = z + dz * C.EXIT_DISTANCE, faceX = dx, faceZ = dz }
end

return Hide

-- Delivery A3: how the client draws a wild Lumipol between the server's 0.2 s steps, and how its mood reads on the
-- provisional primitive model (decision H4: no uploads). Pure: the caller passes positions, modes and time.
-- The server stays the truth; this only smooths and decorates a local copy. Numbers are hypotheses.
local Look = {}

Look.CONSTANTS = table.freeze({
	-- Exponential follow: the gap left after dt seconds is exp(-FOLLOW_RATE * dt).
	FOLLOW_RATE = 12,
	-- A jump this long (respawn, streaming back in) is drawn at once instead of slid.
	SNAP_DISTANCE = 16,
	-- Curious: a small hop every HOP_EVERY seconds lasting HOP_SECONDS, and an ear twitch every TWITCH_EVERY seconds.
	HOP_HEIGHT = 0.35,
	HOP_EVERY = 1.2,
	HOP_SECONDS = 0.3,
	TWITCH_ANGLE = 0.4,
	TWITCH_EVERY = 1.7,
	TWITCH_SECONDS = 0.2,
	-- Light brightness: calm, alert (pulsing around it), hidden and peeking.
	GLOW = 0.7,
	ALERT_GLOW = 1.8,
	ALERT_PULSE = 0.5,
	HIDE_GLOW = 0.15,
	PEEK_GLOW = 0.3,
})
local K = Look.CONSTANTS

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function valid(p)
	return type(p) == "table" and finite(p.x) and finite(p.z) and finite(p.fx) and finite(p.fz)
end

local function copy(p)
	return { x = p.x, z = p.z, fx = p.fx, fz = p.fz }
end

-- current and target = { x, z, fx, fz }. Returns a fresh pose a frame closer to the target.
function Look.follow(current, target, dt)
	if not valid(target) then return nil end
	if not valid(current) then return copy(target) end
	if not finite(dt) or dt <= 0 then return copy(current) end
	local dx, dz = target.x - current.x, target.z - current.z
	if math.sqrt(dx * dx + dz * dz) > K.SNAP_DISTANCE then return copy(target) end
	local alpha = 1 - math.exp(-K.FOLLOW_RATE * dt)
	local fx = current.fx + (target.fx - current.fx) * alpha
	local fz = current.fz + (target.fz - current.fz) * alpha
	local length = math.sqrt(fx * fx + fz * fz)
	if length < 1e-6 then
		fx, fz, length = target.fx, target.fz, math.sqrt(target.fx * target.fx + target.fz * target.fz)
	end
	if length < 1e-6 then fx, fz, length = 0, -1, 1 end
	return { x = current.x + dx * alpha, z = current.z + dz * alpha, fx = fx / length, fz = fz / length }
end

-- A bump that rises and falls once over `seconds`, starting every `every` seconds from `offset`.
local function bump(t, every, seconds, offset)
	local phase = (t + offset) % every
	if phase >= seconds then return 0 end
	return math.sin(math.pi * phase / seconds)
end

-- mode is the replicated brain mode, peek the Peek attribute, t seconds of local time, reduced the Reduced effects
-- setting. Returns { hop = studs up, ear = radians of twitch, glow = light brightness, mark = show "!", dim = hidden }.
function Look.pose(mode, peek, t, reduced)
	local out = { hop = 0, ear = 0, glow = K.GLOW, mark = false, dim = false }
	local moving = reduced ~= true and finite(t)
	if mode == "Curious" then
		if moving then
			out.hop = K.HOP_HEIGHT * bump(t, K.HOP_EVERY, K.HOP_SECONDS, 0)
			out.ear = K.TWITCH_ANGLE * bump(t, K.TWITCH_EVERY, K.TWITCH_SECONDS, 0.6)
		end
	elseif mode == "Alert" then
		out.mark = true
		out.glow = moving and K.ALERT_GLOW * (0.8 + 0.2 * math.sin(2 * math.pi * t / K.ALERT_PULSE)) or K.ALERT_GLOW
	elseif mode == "Hide" then
		out.dim = true
		out.glow = peek == true and K.PEEK_GLOW or K.HIDE_GLOW
	end
	return out
end

return Look

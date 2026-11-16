-- Caramelo v2 (odd/tasks/wildbound-caramelo-v2.md, DG4 Glaseado resbaloso): Don Glaseon's glaze puddles on his plaza.
-- Pure rules shared by the player's client (which owns its character's physics) and the server (which checks a slip
-- and ragdolls). On glaze the player skates: their speed is kept (never slowed) but they lose grip, so their velocity
-- only turns slowly toward where they steer (GRIP per second; less with no input, so they coast). Above SLIP_SPEED (a
-- sprint or a trained walk), a sharp turn (SLIP_DEGREES or more between their velocity and their steering) makes them
-- slip: the client asks the server, which checks the player is on glaze, fast enough and not already down, then
-- ragdolls them FALL_SECONDS through the shared server ragdoll, carried a little along their slide. No damage, the egg
-- stays. The puddles are parts the Candy builder lays (Workspace.Candy_Bioma_v1.Tower.Glaze, attributes Radius, Top).
local Glaze = {}

Glaze.GRIP = 1.5
Glaze.COAST_GRIP = 0.5
Glaze.SLIP_SPEED = 17
Glaze.SLIP_DEGREES = 75
Glaze.FALL_SECONDS = 1.0
Glaze.FALL_CARRY = 0.8
Glaze.FALL_MAX = 25
Glaze.FALL_LIFT = 8
Glaze.SLIP_COOLDOWN = 3
Glaze.SERVER_TOLERANCE = 4
Glaze.ABOVE_STUDS = 5

local function finite(n) return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge end

-- The puddles as data from the builder's parts under `folder` ({ x, z, r, top }).
function Glaze.read(folder)
	local list = {}
	if typeof(folder) ~= "Instance" then return list end
	for _, part in ipairs(folder:GetChildren()) do
		local r, top = part:GetAttribute("Radius"), part:GetAttribute("Top")
		if part:IsA("BasePart") and finite(r) and finite(top) then
			table.insert(list, { x = part.Position.X, z = part.Position.Z, r = r, top = top })
		end
	end
	return list
end

-- The puddle under (x, y, z) (a body standing on it: its root up to ABOVE_STUDS over the glaze), or nil.
function Glaze.inside(puddles, x, y, z)
	if not finite(x) or not finite(y) or not finite(z) then return nil end
	for _, p in ipairs(puddles) do
		if (x - p.x) ^ 2 + (z - p.z) ^ 2 <= p.r * p.r and y >= p.top - 1 and y <= p.top + Glaze.ABOVE_STUDS then return p end
	end
	return nil
end

-- One frame of skating: the flat velocity v = { x, z } turns toward desired = { x, z } (the steering times the walk
-- speed) by GRIP (COAST_GRIP with no input) per second. Returns the new velocity.
function Glaze.skate(v, desired, dt, steering)
	local k = math.min(1, (steering and Glaze.GRIP or Glaze.COAST_GRIP) * math.max(0, dt))
	if not steering then
		-- coasting: keep sliding, losing only a little speed
		return { x = v.x - v.x * k * 0.2, z = v.z - v.z * k * 0.2 }
	end
	return { x = v.x + (desired.x - v.x) * k, z = v.z + (desired.z - v.z) * k }
end

-- Whether this frame is a slip: fast enough, steering, and turning sharply against the slide.
function Glaze.slips(v, steer)
	local speed = math.sqrt(v.x * v.x + v.z * v.z)
	local length = math.sqrt(steer.x * steer.x + steer.z * steer.z)
	if speed < Glaze.SLIP_SPEED or length < 0.5 then return false end
	local cos = (v.x * steer.x + v.z * steer.z) / (speed * length)
	return cos <= math.cos(math.rad(Glaze.SLIP_DEGREES))
end

-- The server's check of a slip request. ctx = { alive, onGlaze, ragdolled, speed (server-side flat), now, lastAt }.
function Glaze.serverAllows(ctx)
	if type(ctx) ~= "table" or ctx.alive ~= true or not ctx.onGlaze or ctx.ragdolled == true then return false end
	if not finite(ctx.speed) or ctx.speed < Glaze.SLIP_SPEED - Glaze.SERVER_TOLERANCE then return false end
	if finite(ctx.lastAt) and ctx.now - ctx.lastAt < Glaze.SLIP_COOLDOWN then return false end
	return true
end

-- The fall's push: along the slide, FALL_CARRY of its speed (at most FALL_MAX), and a small lift.
function Glaze.fallImpulse(vx, vz)
	local speed = math.sqrt(vx * vx + vz * vz)
	if speed < 1e-3 then return { x = 0, y = Glaze.FALL_LIFT, z = 0 } end
	local s = math.min(speed * Glaze.FALL_CARRY, Glaze.FALL_MAX) / speed
	return { x = vx * s, y = Glaze.FALL_LIFT, z = vz * s }
end

return Glaze

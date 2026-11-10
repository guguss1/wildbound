-- Bat knockback (decisions Q4 and Q4b, docs/mechanics/wildbound-new-mechanics.md section 3): pure server rules for the
-- faster bat with a ragdoll push. WildboundBat keeps the hitbox (inReach, pickTarget: the server chooses the target
-- from the attacker's own body and facing); this module replaces its cooldown, stumble and immunity once wired. A
-- landed hit ragdolls the target RAGDOLL_SECONDS, pushes them away from the attacker with a capped impulse (never a
-- fling across the map), drops a carried egg (anyone may pick it up) and starts IMMUNITY seconds in which no new hit
-- lands (no chain stuns). Nothing happens inside a safe zone (the hub, a base): neither swinging nor being knocked.
-- Positions, zones and the clock are passed in; nothing here reads the world. Every number is a hypothesis to tune.
local Knock = {}

Knock.CONSTANTS = table.freeze({
	COOLDOWN = 5, -- seconds from one swing to the next, spent on a miss too (was 12)
	RAGDOLL_SECONDS = 1.2, -- the target is down and cannot act (was a 0.45 s stumble)
	IMMUNITY = 3, -- seconds from a landed hit in which no new hit lands (Q4b: 3, not 4)
	IMPULSE = 45, -- studs per second, flat, away from the attacker
	LIFT = 20, -- studs per second up, so the body leaves the ground briefly
})
-- Safety floors and caps: a tune never allows continuous attacks, a long ragdoll or a fling.
Knock.COOLDOWN_MIN = 3
Knock.IMPULSE_MAX = 60
Knock.LIFT_MAX = 35
Knock.GRAVITY = 196.2 -- Workspace.Gravity default, studs per second squared
Knock.MAX_FLIGHT = 24 -- studs of ballistic travel a knock may give at most

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end
local function validKey(value)
	return (type(value) == "number" and finite(value)) or (type(value) == "string" and #value > 0 and #value <= 64)
end

-- Dev tuning (docs/testing/wildbound-tuning.md): CONSTANTS stay the defaults the tests pin; the rules read `live`.
local C = {}
Knock.live = C

function Knock.tunable()
	return table.clone(Knock.CONSTANTS)
end

function Knock.tune(overrides)
	for key, value in pairs(Knock.CONSTANTS) do C[key] = value end
	if type(overrides) == "table" then
		for key, value in pairs(overrides) do
			if Knock.CONSTANTS[key] ~= nil and finite(value) then C[key] = value end
		end
	end
	C.COOLDOWN = math.clamp(C.COOLDOWN, Knock.COOLDOWN_MIN, 30)
	C.RAGDOLL_SECONDS = math.clamp(C.RAGDOLL_SECONDS, 0.5, 2)
	C.IMMUNITY = math.clamp(C.IMMUNITY, C.RAGDOLL_SECONDS + 1, 15)
	C.IMPULSE = math.clamp(C.IMPULSE, 10, Knock.IMPULSE_MAX)
	C.LIFT = math.clamp(C.LIFT, 0, Knock.LIFT_MAX)
end
Knock.tune(nil)

-- True when (x, z) lies in any zone { x, z, radius }. An unknown position counts as safe: a target we cannot place is
-- never knocked.
function Knock.inSafe(x, z, zones)
	if not finite(x) or not finite(z) then return true end
	if type(zones) ~= "table" then return false end
	for _, zone in ipairs(zones) do
		if type(zone) == "table" and finite(zone.x) and finite(zone.z) and finite(zone.radius) then
			local dx, dz = x - zone.x, z - zone.z
			if dx * dx + dz * dz <= zone.radius * zone.radius then return true end
		end
	end
	return false
end

-- Ballistic travel on flat ground: horizontal speed times the time in the air.
function Knock.flight(v)
	if type(v) ~= "table" or not finite(v.x) or not finite(v.y) or not finite(v.z) or v.y <= 0 then return 0 end
	return math.sqrt(v.x * v.x + v.z * v.z) * (2 * v.y / Knock.GRAVITY)
end

-- The push for a target at `to` hit from `from` ({ x, z, lookX, lookZ }): flat away from the attacker (the attacker's
-- facing when they overlap, +Z when that is unknown too), plus LIFT up, scaled down if it would fly past MAX_FLIGHT.
function Knock.impulse(from, to)
	local dx, dz = to.x - from.x, to.z - from.z
	local flat = math.sqrt(dx * dx + dz * dz)
	if flat < 1e-6 then
		dx, dz = finite(from.lookX) and from.lookX or 0, finite(from.lookZ) and from.lookZ or 0
		flat = math.sqrt(dx * dx + dz * dz)
		if flat < 1e-6 then dx, dz, flat = 0, 1, 1 end
	end
	local speed = C.IMPULSE
	local v = { x = dx / flat * speed, y = C.LIFT, z = dz / flat * speed }
	local travel = Knock.flight(v)
	if travel > Knock.MAX_FLIGHT then
		local scale = Knock.MAX_FLIGHT / travel
		v.x *= scale
		v.z *= scale
	end
	return v
end

-- One record per player key: { readyAt, ragdollUntil, immuneUntil }.
function Knock.new()
	return { players = {} }
end

local function record(registry, key)
	local players = registry.players
	local value = players[key]
	if not value then
		value = { readyAt = -math.huge, ragdollUntil = -math.huge, immuneUntil = -math.huge }
		players[key] = value
	end
	return value
end

-- ctx = { alive, busy (capturing or hidden), x, z (the attacker's root), zones }. Returns true and when the next swing
-- is ready, or false and a reason. A refused swing never spends the cooldown.
function Knock.swing(registry, key, now, ctx)
	if type(registry) ~= "table" or not validKey(key) then return false, "InvalidPlayer" end
	if not finite(now) then return false, "BadClock" end
	if type(ctx) ~= "table" or ctx.alive ~= true then return false, "Dead" end
	if ctx.busy == true then return false, "Busy" end
	if not finite(ctx.x) or not finite(ctx.z) then return false, "BadPosition" end
	if Knock.inSafe(ctx.x, ctx.z, ctx.zones) then return false, "SafeZone" end
	local rec = record(registry, key)
	if now < rec.ragdollUntil then return false, "Ragdolled" end
	if now < rec.readyAt then return false, "Cooldown" end
	rec.readyAt = now + C.COOLDOWN
	return true, rec.readyAt
end

local function point(value, withLook)
	if type(value) ~= "table" then return false end
	if not finite(value.x) or not finite(value.y) or not finite(value.z) then return false end
	return not withLook or (value.lookX == nil or finite(value.lookX)) and (value.lookZ == nil or finite(value.lookZ))
end

-- A landed swing from `from` on `key` standing at `to`. ctx = { carrying, zones }. Returns { landed = false, reason,
-- drop = false } ("Invalid", "SafeZone", "Immune") or { landed = true, drop, ragdoll, ragdollUntil, immuneUntil,
-- impulse = { x, y, z } }. The server applies the impulse to the target's root and its ragdoll state.
function Knock.knock(registry, from, key, to, now, ctx)
	local miss = function(reason) return { landed = false, reason = reason, drop = false } end
	if type(registry) ~= "table" or not validKey(key) or not finite(now) then return miss("Invalid") end
	if not point(from, true) or not point(to, false) then return miss("Invalid") end
	ctx = type(ctx) == "table" and ctx or {}
	if Knock.inSafe(to.x, to.z, ctx.zones) then return miss("SafeZone") end
	local rec = record(registry, key)
	if now < rec.immuneUntil then return miss("Immune") end
	rec.ragdollUntil = now + C.RAGDOLL_SECONDS
	rec.immuneUntil = now + C.IMMUNITY
	return {
		landed = true, drop = ctx.carrying == true, ragdoll = C.RAGDOLL_SECONDS,
		ragdollUntil = rec.ragdollUntil, immuneUntil = rec.immuneUntil, impulse = Knock.impulse(from, to),
	}
end

function Knock.ragdolled(registry, key, now)
	local rec = type(registry) == "table" and registry.players[key]
	return rec ~= nil and rec ~= false and finite(now) and now < rec.ragdollUntil
end

function Knock.immune(registry, key, now)
	local rec = type(registry) == "table" and registry.players[key]
	return rec ~= nil and rec ~= false and finite(now) and now < rec.immuneUntil
end

-- A player left: their cooldown, ragdoll and immunity go with them.
function Knock.forget(registry, key)
	if type(registry) == "table" then registry.players[key] = nil end
end

return Knock

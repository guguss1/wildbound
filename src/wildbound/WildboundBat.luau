-- Nest Heist, phase 2 (docs/design/wildbound-combined-plan.md sections 1, 2 and 4): pure server rules for the basic
-- bat every player carries. Positions, time and the line-of-sight answer are passed in; nothing here reads the world.
-- The client only asks to swing: the server decides the target from the attacker's own body and facing, so no hit is
-- ever chosen by a client. A carrier who is hit stumbles and drops the egg (anyone may pick it up); anyone else only
-- taps (a tiny stumble), so PvP stays a way to contest an egg, not the main loop. After any landed hit the target is
-- immune to a new one for IMMUNITY seconds (no stun chains). Every number is a hypothesis to tune in play.
local Bat = {}

Bat.CONSTANTS = table.freeze({
	COOLDOWN = 12, -- seconds from one swing to the next, spent on a miss too (no continuous attacks)
	REACH = 6, -- studs from the attacker's root to the target's root: an arm and a bat on a 5-stud avatar
	HALF_ANGLE = 60, -- degrees either side of where the attacker faces
	HEIGHT = 4, -- studs of height difference at most
	STUMBLE_SECONDS = 0.45, -- an egg carrier hit
	TAP_SECONDS = 0.2, -- anyone else hit: a tiny stumble only
	STUMBLE_SPEED = 2, -- walk speed while stumbling (never faster than the player already was)
	IMMUNITY = 6, -- seconds after a landed hit during which no new PvP stumble lands
	SWING_SECONDS = 0.3, -- the swing's animation on the clients (presentation only)
})
-- Safety floors: a tuned value never allows continuous attacks, a long reach or a stun longer than its immunity.
Bat.COOLDOWN_MIN = 3
Bat.REACH_MIN, Bat.REACH_MAX = 3, 8

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end
local function validKey(value)
	return (type(value) == "number" and finite(value)) or (type(value) == "string" and #value > 0 and #value <= 64)
end

-- Dev tuning (docs/testing/wildbound-tuning.md): CONSTANTS stay the defaults the tests pin; the server's tuning bridge
-- overrides `live`. No override, no change.
local C = {}
Bat.live = C

function Bat.tunable()
	return table.clone(Bat.CONSTANTS)
end

function Bat.tune(overrides)
	for key, value in pairs(Bat.CONSTANTS) do C[key] = value end
	if type(overrides) == "table" then
		for key, value in pairs(overrides) do
			if Bat.CONSTANTS[key] ~= nil and finite(value) then C[key] = value end
		end
	end
	C.COOLDOWN = math.max(C.COOLDOWN, Bat.COOLDOWN_MIN)
	C.REACH = math.clamp(C.REACH, Bat.REACH_MIN, Bat.REACH_MAX)
	C.HALF_ANGLE = math.clamp(C.HALF_ANGLE, 15, 90)
	C.HEIGHT = math.clamp(C.HEIGHT, 1, 8)
	C.STUMBLE_SECONDS = math.clamp(C.STUMBLE_SECONDS, 0.1, 1)
	C.TAP_SECONDS = math.clamp(C.TAP_SECONDS, 0, C.STUMBLE_SECONDS)
	C.STUMBLE_SPEED = math.clamp(C.STUMBLE_SPEED, 0, 16)
	C.IMMUNITY = math.max(C.IMMUNITY, C.STUMBLE_SECONDS + 1)
	C.SWING_SECONDS = math.clamp(C.SWING_SECONDS, 0.1, 1)
end
Bat.tune(nil)

-- One record per player key: { readyAt, stumbleUntil, immuneUntil }.
function Bat.new()
	return { players = {} }
end

local function record(registry, key)
	local players = registry.players
	local value = players[key]
	if not value then
		value = { readyAt = -math.huge, stumbleUntil = -math.huge, immuneUntil = -math.huge }
		players[key] = value
	end
	return value
end

-- ctx = { alive, safe (the attacker stands in the camp, the shelter or a Refugio), busy (capturing or hidden) }.
-- Returns true and when the next swing is ready, or false and a reason. A refused swing never spends the cooldown.
function Bat.swing(registry, key, now, ctx)
	if type(registry) ~= "table" or not validKey(key) then return false, "InvalidPlayer" end
	if not finite(now) then return false, "BadClock" end
	if type(ctx) ~= "table" or ctx.alive ~= true then return false, "Dead" end
	if ctx.safe == true then return false, "SafeZone" end
	if ctx.busy == true then return false, "Busy" end
	local rec = record(registry, key)
	if now < rec.readyAt then return false, "Cooldown" end
	rec.readyAt = now + C.COOLDOWN
	return true, rec.readyAt
end

-- from = { x, y, z, lookX, lookZ } (the attacker's root and facing); to = { x, y, z } (the target's root). Only these
-- fields are read: nothing a player owns changes the reach.
function Bat.inReach(from, to)
	if type(from) ~= "table" or type(to) ~= "table" then return false end
	for _, value in ipairs({ from.x, from.y, from.z, from.lookX, from.lookZ, to.x, to.y, to.z }) do
		if not finite(value) then return false end
	end
	local dx, dz = to.x - from.x, to.z - from.z
	if math.abs(to.y - from.y) > C.HEIGHT then return false end
	local flat = math.sqrt(dx * dx + dz * dz)
	if flat > C.REACH + 1e-9 then return false end
	local look = math.sqrt(from.lookX * from.lookX + from.lookZ * from.lookZ)
	if look < 1e-6 then return false end
	if flat < 1e-6 then return true end
	local dot = (dx * from.lookX + dz * from.lookZ) / (flat * look)
	return dot >= math.cos(math.rad(C.HALF_ANGLE)) - 1e-9, flat
end

-- candidates = { { key, x, y, z, alive, safe, hidden } }; clear(candidate) answers the server's line-of-sight ray from
-- the attacker to that target. The nearest valid target with a clear line is hit. Returns the candidate, or nil and
-- "NoTarget" (nobody valid in reach) or "Blocked" (only through a wall). Without a clear function nothing is hit.
function Bat.pickTarget(attacker, candidates, clear)
	if type(attacker) ~= "table" or type(candidates) ~= "table" then return nil, "NoTarget" end
	local valid = {}
	for _, candidate in ipairs(candidates) do
		if type(candidate) == "table" and candidate.key ~= attacker.key and candidate.alive == true
			and candidate.safe ~= true and candidate.hidden ~= true then
			local inside, distance = Bat.inReach(attacker, candidate)
			if inside then table.insert(valid, { candidate = candidate, distance = distance or 0 }) end
		end
	end
	if #valid == 0 then return nil, "NoTarget" end
	if type(clear) ~= "function" then return nil, "Blocked" end
	table.sort(valid, function(a, b) return a.distance < b.distance end)
	for _, item in ipairs(valid) do
		if clear(item.candidate) == true then return item.candidate end
	end
	return nil, "Blocked"
end

-- A landed swing on `key`. carrying: the target holds an egg in the arms. Returns { immune, drop, stumble }: an immune
-- target is untouched; otherwise a carrier stumbles STUMBLE_SECONDS and drops the egg, anyone else taps for
-- TAP_SECONDS, and the immunity starts.
function Bat.hit(registry, key, now, carrying)
	if type(registry) ~= "table" or not validKey(key) or not finite(now) then
		return { immune = true, drop = false, stumble = 0 }
	end
	local rec = record(registry, key)
	if now < rec.immuneUntil then return { immune = true, drop = false, stumble = 0 } end
	local stumble = carrying == true and C.STUMBLE_SECONDS or C.TAP_SECONDS
	rec.stumbleUntil = now + stumble
	rec.immuneUntil = now + C.IMMUNITY
	return { immune = false, drop = carrying == true, stumble = stumble, immuneUntil = rec.immuneUntil }
end

function Bat.stumbling(registry, key, now)
	local rec = type(registry) == "table" and registry.players[key]
	return rec ~= nil and rec ~= false and finite(now) and now < rec.stumbleUntil
end

-- The walk speed while stumbling: never faster than the given speed.
function Bat.speed(speed, registry, key, now)
	if Bat.stumbling(registry, key, now) then return math.min(speed, C.STUMBLE_SPEED) end
	return speed
end

-- A player left: their cooldown and immunity go with them.
function Bat.forget(registry, key)
	if type(registry) == "table" then registry.players[key] = nil end
end

return Bat

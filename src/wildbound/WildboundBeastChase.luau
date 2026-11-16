-- Beast revision 2026-11-16 (docs/design/wildbound-beast-revision-2026-11-16.md section 1, odd/tasks/wildbound-beast-revision.md):
-- the global chase rules of the six wave beasts, in one shared pure module so no beast keeps its own copy.
--   1.1 Persistent chase: a PERSISTENT beast keeps its target until the target dies (or its body is replaced) or stands
--       in a valid safe zone. No escape distance, no timeout, no attack count, no "unseen" or "no approach" exit.
--   1.2 One safe-zone check: Chase.ended reads target.safe, which the beast script fills from WildboundWorldRules.zone
--       (the same call world.safe and world.landing use), so every beast ends on exactly the same boundary.
--   1.3 A stable target: an encounter belongs to one player for its whole life (the beast script never retargets).
--   1.4 Capped status effects: EFFECTS is the one table of caps the beast script clamps every slow and root with.
-- CATCHUP keeps a persistent chase meaningful: a beast that fell far behind closes in at least at CATCHUP.speed, which
-- is faster than a base walk (16) but slower than a trained or sprinting runner, so reaching a safe zone stays possible.
-- Pure: no services, no clock, no random. Every number is a PROPUESTA to tune in Play.
local Chase = {}

Chase.PERSISTENT = table.freeze({ Viper = true, Pouncer = true, Streamer = true, Root = true, Gaze = true, Lurker = true })

Chase.CATCHUP = table.freeze({ distance = 45, speed = 20 })

Chase.EFFECTS = table.freeze({
	slowMinMultiplier = 0.5, -- a slow never takes more than half the walk speed
	slowMaxSeconds = 3, -- and never lasts longer than this
	rootMaxSeconds = 1.5, -- an immobilisation never lasts longer than this
})

local function finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Chase.persistent(name)
	return Chase.PERSISTENT[name] == true
end

-- The one end check: "Death" when there is no live body (dead, left, or a new character after a respawn), "SafeZone"
-- when the target stands in a safe zone, nil while the chase goes on.
function Chase.ended(target)
	if type(target) ~= "table" or target.alive ~= true then return "Death" end
	if target.safe == true then return "SafeZone" end
	return nil
end

-- The speed a beast walks toward its target: its own, or at least CATCHUP.speed when a persistent beast is farther
-- than CATCHUP.distance. Walking away (sign -1) is never sped up.
function Chase.walkSpeed(name, speed, distance, sign)
	if not finite(speed) then return 0 end
	if sign == -1 or not Chase.persistent(name) or not finite(distance) then return speed end
	if distance > Chase.CATCHUP.distance then return math.max(speed, Chase.CATCHUP.speed) end
	return speed
end

-- Clamps a slow to the caps. Returns multiplier, seconds (nil when the input is broken).
function Chase.clampSlow(multiplier, seconds)
	if not finite(multiplier) or not finite(seconds) then return nil end
	return math.clamp(multiplier, Chase.EFFECTS.slowMinMultiplier, 1), math.clamp(seconds, 0, Chase.EFFECTS.slowMaxSeconds)
end

-- Clamps an immobilisation to the cap (nil when broken).
function Chase.clampRoot(seconds)
	if not finite(seconds) then return nil end
	return math.clamp(seconds, 0, Chase.EFFECTS.rootMaxSeconds)
end

-- Whether a repositioning spot is valid (Screamer's teleport, section 4). spot = { x, y, z } or nil (no ground found);
-- target = { x, y, z }; opts = { min, max, clearance, safe = function(x, z) -> bool, clear = function(spot) -> bool,
-- lineOfStrike = function(spot) -> bool }. Returns true, or false and the reason:
--   NoSpot (no ground, under the map or outside the playable area), Safe (inside a safe zone), Near (closer than min,
--   or inside the clearance around the target, which covers its hitbox), Far (beyond max), Blocked (a solid part).
function Chase.validSpot(spot, target, opts)
	if type(spot) ~= "table" or not finite(spot.x) or not finite(spot.y) or not finite(spot.z) then return false, "NoSpot" end
	if type(target) ~= "table" or not finite(target.x) or not finite(target.z) then return false, "NoSpot" end
	opts = opts or {}
	if opts.safe and opts.safe(spot.x, spot.z) == true then return false, "Safe" end
	local distance = math.sqrt((spot.x - target.x) ^ 2 + (spot.z - target.z) ^ 2)
	if finite(opts.min) and distance < opts.min then return false, "Near" end
	if finite(opts.clearance) and distance < opts.clearance then return false, "Near" end
	if finite(opts.max) and distance > opts.max then return false, "Far" end
	if opts.clear and opts.clear(spot) ~= true then return false, "Blocked" end
	return true
end

return Chase

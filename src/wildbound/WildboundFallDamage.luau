-- Fall damage (owner request 2026-11-19, "que haya daño de caida desde esa torre y de otras torres altas": the Gran
-- Torta in Caramelo and the other tall towers). Pure rules for WildboundFallDamageService: no services, no clock (time
-- is passed in), no require. Server only (ServerScriptService). Rules: WildboundFallDamage_Test.
--
-- What a fall is: the service samples each character on the server every frame (the root's position, a short ground
-- ray under the feet, a few server-written attributes) and passes one sample to step(). While the ray finds no ground
-- the player is in the air; the fall's height is the standing root height at the takeoff (a jump's rise never counts)
-- minus the standing root height where the ray finds ground again. A landing below SAFE_STUDS never hurts, so a jump
-- off anything up to SAFE_STUDS high is free. The highest root height in the air (a jump's top) only times the fall.
--
-- Damage: floor((height - SAFE_STUDS) * DAMAGE_PER_STUD), capped at MAX_DAMAGE, so no fall kills from full health
-- (earlier owner decision, "Ningún golpe mata de una y todos avisan antes"); a second fall can still defeat a hurt
-- player, like any other hit. The damage goes through the inventory server's BeastHit (beast "Fall", the egg kept), so
-- it obeys the same switch as creature damage (WildboundFlags, this exact place, WildboundFairStrike.effectiveMode), the
-- same paid-trip rule and the same dodge window.
--
-- A landing never hurts (its reason says why):
--   Calm    the first landing after a respawn, a portal trip, a jump of the root between two samples (any server
--           teleport), or a time held by the server (anchored, seated, on the raft, hidden, swimming, climbing, dead).
--   Shoved  a creature push (WildboundBeastPush), a hit that took health, the bat (WildboundBatHit) or a ragdoll within
--           SHOVE_GRACE_SECONDS before or during the fall: a hit never brings a surprise second hit.
--   Bridge  decision: a crumbling cookie bridge (Cracking or Down) under the player while in the air or at the landing.
--           Its crumble is the game's own warned trap, and its deck ends stand over dry floor (12.5 studs).
--   Soft    the landing is in the chocolate (the wading rule's test, WildboundCandyWade).
--   Slow    the way down took far longer than a free fall from that height (a walk down a ramp the ground ray cannot
--           see, a climb down): only a real fall hurts.
--   Low     under SAFE_STUDS, or under 1 point of damage.
local Fall = {}

Fall.CONSTANTS = table.freeze({
	-- A landing at or under this many studs below the takeoff's standing height never hurts. About four times a
	-- character's height: a jump off anything up to 20 studs is free, walked off or jumped off (the jump's rise is not
	-- counted): the raised bridge decks (12.5) and their rails (14.7), the Gran Torta's one-ledge drops (11.6 to 17.5),
	-- the Pueblo Gatito boxes, ledges and canopies (10.5 to 15.4).
	SAFE_STUDS = 20,
	-- Points of damage per stud over SAFE_STUDS: the Gran Torta's first tier (21) costs 1, walked off or jumped off;
	-- the H5 balcony (23.2) 4, the Seta Trueno cap (26) 9, the second tier (38.5) 27.
	DAMAGE_PER_STUD = 1.5,
	-- The hardest creature hit (WildboundBeastConfig, 40), reached at 46.7 studs: from full health a fall always leaves
	-- at least MAX_HEALTH - MAX_DAMAGE = 60.
	MAX_DAMAGE = 40,
	MAX_HEALTH = 100, -- WildboundServer bindCharacter's MaxHealth
	-- The ground ray reaches this far under the feet: down a 1-stud stair step a walker stays on the ground.
	GROUND_SLACK = 1.5,
	-- A root that moves more than this between two samples was moved by the server (a portal, a respawn, a hide spot,
	-- the raft's drop-off), never by a fall (113 studs/s after the full Gran Torta is under 2 studs a frame).
	TELEPORT_STUDS = 20,
	-- A push, a hit or the bat within this long before or during a fall makes it free (pushes last at most 1 s).
	SHOVE_GRACE_SECONDS = 1.5,
	-- Health this far down between two server reads is a hit (regeneration and the mark pin move about 1 point a second,
	-- WildboundPortal.CONFIG.hurtMin).
	HURT_MIN = 3,
	-- In the air without moving more than this for this long: standing on something the ground ray cannot see (the fall
	-- ends there without a hit; a stalled network may look the same, so it never hurts).
	REST_STUDS = 0.1,
	REST_SECONDS = 0.3,
	-- The fall's top is the last time the root was this close to its highest point (a wait on an edge is no fall time).
	PEAK_STUDS = 0.25,
	-- A real fall: from its top to the landing in at most FALL_TIME_FACTOR times the free-fall time plus FALL_TIME_SLACK
	-- (sampling and replication). A 21-stud fall takes 0.46 s and may take up to 0.99 s.
	FALL_TIME_FACTOR = 1.6,
	FALL_TIME_SLACK = 0.25,
	DEFAULT_GRAVITY = 196.2, -- Roblox's default; the service passes workspace.Gravity
})
local C = Fall.CONSTANTS

Fall.REASONS = table.freeze({ "Hurt", "Low", "Calm", "Shoved", "Bridge", "Soft", "Slow" })

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- damageFor(height) -> whole points of damage for a fall of this many studs (0 at or under SAFE_STUDS, junk 0).
function Fall.damageFor(height)
	if not finite(height) or height <= C.SAFE_STUDS then return 0 end
	return math.min(C.MAX_DAMAGE, math.floor((height - C.SAFE_STUDS) * C.DAMAGE_PER_STUD))
end

-- freefallSeconds(height, gravity) -> the time a free fall from rest takes for this height (junk gravity: the default).
function Fall.freefallSeconds(height, gravity)
	local g = finite(gravity) and gravity > 0 and gravity or C.DEFAULT_GRAVITY
	if not finite(height) or height <= 0 then return 0 end
	return math.sqrt(2 * height / g)
end

-- hurt(last, health) -> whether health fell by at least HURT_MIN between two reads.
function Fall.hurt(last, health)
	return finite(last) and finite(health) and health <= last - C.HURT_MIN
end

-- shoved(shovedAt, ragdollUntil, now) -> whether a push, hit or ragdoll makes a fall free right now.
function Fall.shoved(shovedAt, ragdollUntil, now)
	if not finite(now) then return false end
	if finite(ragdollUntil) and ragdollUntil > now then return true end
	return finite(shovedAt) and now - shovedAt <= C.SHOVE_GRACE_SECONDS
end

-- groundHeight(hitY, rootHalfHeight, hipHeight, isR6) -> the root's standing height over a ground point (an R6 rig's
-- legs are 2 studs under its root, an R15 rig stands HipHeight under it, as WildboundCandyWade.probe), or nil.
function Fall.groundHeight(hitY, rootHalfHeight, hipHeight, isR6)
	if not finite(hitY) then return nil end
	local legs = isR6 == true and 2 or (finite(hipHeight) and hipHeight or 2)
	local half = finite(rootHalfHeight) and rootHalfHeight or 1
	return hitY + half + legs
end

-- rayLength(rootHalfHeight, hipHeight, isR6) -> how far under the root the ground ray reaches.
function Fall.rayLength(rootHalfHeight, hipHeight, isR6)
	local legs = isR6 == true and 2 or (finite(hipHeight) and hipHeight or 2)
	local half = finite(rootHalfHeight) and rootHalfHeight or 1
	return half + legs + C.GROUND_SLACK
end

-- A fresh record for one player. The service keeps one per player; a new character is seen through sample.life.
function Fall.new()
	return { life = nil, portal = nil, lx = nil, ly = nil, lz = nil, calm = true, air = nil, standY = nil }
end

-- inAir(track) -> whether a fall is being measured (the service then checks the chocolate for a grounded sample).
function Fall.inAir(track)
	return type(track) == "table" and track.air ~= nil
end

local function settle(track)
	track.air, track.calm, track.standY = nil, true, nil
end

local function judge(air, groundY, sample, now, shovedNow)
	local drop = air.base - groundY
	local out = { drop = drop, peak = air.peak, y = groundY, x = sample.x, z = sample.z, damage = 0, reason = "Low",
		seconds = now - air.peakAt }
	local damage = Fall.damageFor(drop)
	if damage < 1 then return out end
	if air.calm then
		out.reason = "Calm"
	elseif air.shoved or shovedNow then
		out.reason = "Shoved"
	elseif air.bridge or sample.crumbling == true then
		out.reason = "Bridge"
	elseif sample.soft == true then
		out.reason = "Soft"
	elseif now - air.peakAt > C.FALL_TIME_FACTOR * Fall.freefallSeconds(air.peak - groundY, sample.gravity) + C.FALL_TIME_SLACK then
		out.reason = "Slow"
	else
		out.reason, out.damage = "Hurt", damage
	end
	return out
end

-- step(track, sample, now) -> a landing { drop, peak, y, x, z, damage, reason, seconds } or nil. sample = {
--   life       the character (any value; a new one is a respawn),
--   x, y, z    the root's position,
--   groundY    the root's standing height over the ground the ray found (groundHeight), nil while in the air,
--   alive      true while the humanoid lives,
--   held       true while the server holds the body (anchored, seated, hidden, swimming, climbing),
--   portal     the player's WildboundPortalReadyAt (a change is a portal trip),
--   shovedAt, ragdollUntil   the latest push / hit / bat time and the ragdoll's end (shoved()),
--   crumbling  true inside a crumbling cookie bridge's footprint,
--   soft       true when this grounded sample's feet are in the chocolate,
--   gravity    workspace.Gravity }. nil (no character) forgets the fall and makes the next landing free.
function Fall.step(track, sample, now)
	if type(track) ~= "table" then return nil end
	if type(sample) ~= "table" or not finite(now) or not finite(sample.x) or not finite(sample.y) or not finite(sample.z) then
		track.life, track.lx, track.ly, track.lz = nil, nil, nil, nil
		settle(track)
		return nil
	end
	local x, y, z = sample.x, sample.y, sample.z
	local jumped = false
	if track.lx ~= nil then
		local dx, dy, dz = x - track.lx, y - track.ly, z - track.lz
		jumped = dx * dx + dy * dy + dz * dz > C.TELEPORT_STUDS * C.TELEPORT_STUDS
	end
	track.lx, track.ly, track.lz = x, y, z
	if sample.life ~= track.life or sample.portal ~= track.portal or jumped then
		track.life, track.portal = sample.life, sample.portal
		settle(track)
	end
	if sample.alive ~= true or sample.held == true then
		settle(track)
		return nil
	end
	local shovedNow = Fall.shoved(sample.shovedAt, sample.ragdollUntil, now)
	local air = track.air
	local groundY = finite(sample.groundY) and sample.groundY or nil
	if groundY == nil and air ~= nil then
		if math.abs(y - air.restY) <= C.REST_STUDS then
			-- standing on something the ground ray cannot see: the fall ends there, never with a hit
			if now - air.restSince >= C.REST_SECONDS then
				track.air, track.standY = nil, y
				return nil
			end
		else
			air.restY, air.restSince = y, now
		end
	end
	if groundY ~= nil then
		track.air, track.calm, track.standY = nil, false, groundY
		if air == nil then return nil end
		return judge(air, groundY, sample, now, shovedNow)
	end
	if air == nil then
		-- the takeoff: the drop is measured from the height the player stood at (base; a jump's rise never adds to it), and
		-- the fall's top (peak, for its timing only) starts there too (a walk off a ledge drops all of it)
		local base = track.standY ~= nil and track.standY or y
		local peak = math.max(y, base)
		air = { base = base, peak = peak, peakAt = now, restY = y, restSince = now, calm = track.calm, shoved = false,
			bridge = false }
		track.air = air
	end
	if y >= air.peak - C.PEAK_STUDS then
		if y > air.peak then air.peak = y end
		air.peakAt = now
	end
	if shovedNow then air.shoved = true end
	if sample.crumbling == true then air.bridge = true end
	return nil
end

return table.freeze(Fall)

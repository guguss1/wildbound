-- Pure guardian brain (delivery C1, docs/mechanics/wildbound-guardian.md). La Silueta's states besides the fight:
-- Patrol, Suspicious (a faint noise: stop and face it), Investigate (walk to a noise), Search (look around the last
-- known spot), Retreat (return to its territory). The world script keeps Alert, Hunt and Telegraph, which the
-- fair-strike rules guard, and asks this module for speeds, wind-up times and the day and night profile.
-- Positions are plain numbers, the clock is injected, and the territory clamp is passed in. All numbers are
-- hypotheses to tune in play.
local Brain = {}

local function freeze(value)
	if type(value) == "table" and not table.isfrozen(value) then
		for _, child in pairs(value) do freeze(child) end
		table.freeze(value)
	end
	return value
end

Brain.CONSTANTS = freeze({
	SUSPICIOUS_SECONDS = 1.2, -- a faint noise: it stops and faces the sound this long before walking to it
	LOUD = 0.5, -- a noise at least this strong (1 at the source, 0 at the edge of its radius) skips suspicion
	INVESTIGATE_MAX_SECONDS = 14, -- gives up walking to a noise it cannot reach
	STALK_SECONDS = 10, -- I4: a scream from beyond the territory: it stands at the edge facing it this long
	ARRIVE_RADIUS = 3, -- this close to a point counts as there
	SEARCH_RADIUS = 7, -- look-around points circle the last known spot at this distance
	REACQUIRE_ALERT_SECONDS = 0.4, -- spotting its quarry again while searching needs a shorter wind-up (chase pass: was 0.6)
	RECOVERY_SECONDS = 1.5, -- after an attack that ends the hunt, no detection for this long (chase pass: was 3)
})
local C = Brain.CONSTANTS

-- Studs per second, seconds and studs. Day is the least aggressive phase, Night the most active. Chase pass (CP-D2,
-- user: "walks faster, chases more"): a rested sprinter (16 x 1.45 = 23.2) outruns every hunt by at least 5 studs/s,
-- but a walker (16) is caught at night and a carrier (14) at dusk and night; a loaded pouch must hide. detection is
-- the sight radius for a new target, deliberately shorter than before (Day 26, Dusk 32, Night 38): it notices you a
-- little later in the mist, and that keeps the economy simulator's greedy median at its floor (CP-R1); the Day patrol
-- is 5 (not more) for the same reason: the simulator's exposure grows fastest with the Day patrol speed. memorySeconds:
-- how long a hunt keeps walking to where it last saw its quarry before it searches.
local DAY = { patrol = 5, investigate = 9, hunt = 13, search = 8, retreat = 8, hearing = 0.8,
	searchSeconds = 12, chaseSeconds = 30, alertSeconds = 0.8, detection = 21, memorySeconds = 4 }
local TWILIGHT = { patrol = 6, investigate = 10, hunt = 15, search = 9, retreat = 8.5, hearing = 1.0,
	searchSeconds = 16, chaseSeconds = 40, alertSeconds = 0.65, detection = 26, memorySeconds = 5 }
Brain.PROFILES = freeze({
	Day = DAY, Dusk = TWILIGHT, Dawn = table.clone(TWILIGHT),
	Night = { patrol = 7, investigate = 11, hunt = 17, search = 10, retreat = 9, hearing = 1.3,
		searchSeconds = 20, chaseSeconds = 50, alertSeconds = 0.5, detection = 30, memorySeconds = 6 },
})

-- Capture noise (C1): base hearing radius in studs per capture step, scaled by the slot's tier and the phase.
-- Delivery D5 adds sprinting and the rustle of entering a hiding spot (10). The dread pass (D-D5) raised sprint from
-- 16 to 30 so a night sprint in the fog is heard from beyond the night sight radius: speed has a price.
-- Expedition islands (I4): a woken island's scream (EI-5) and a carried cria's cry (EI-6).
Brain.NOISE = freeze({ ring = 32, seal = 48, sprint = 30, rustle = 10, scream = 70, cry = 18 })
Brain.TIER_NOISE = freeze({ Safe = 0.5, Fog = 1.0, Territory = 1.4 })

local SPEED_KEY = { Patrol = "patrol", Investigate = "investigate", Hunt = "hunt", Search = "search", Retreat = "retreat" }
local COMBAT = { Alert = true, Hunt = true, Telegraph = true }

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function distance(ax, az, bx, bz)
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

function Brain.profile(phase)
	return table.clone(Brain.PROFILES[phase] or DAY)
end

function Brain.speed(mode, phase)
	local key = SPEED_KEY[mode]
	if not key then return 0 end
	return (Brain.PROFILES[phase] or DAY)[key]
end

function Brain.noiseRadius(kind, tier, phase)
	local base = Brain.NOISE[kind]
	if not base then return 0 end
	return base * (Brain.TIER_NOISE[tier] or Brain.TIER_NOISE.Fog) * (Brain.PROFILES[phase] or DAY).hearing
end

function Brain.new(now)
	return { mode = "Retreat", since = finite(now) and now or 0, point = nil, untilAt = 0, lookIndex = 0 }
end

function Brain.set(state, mode, now)
	state.mode, state.since = mode, finite(now) and now or state.since
end

local function place(x, z, clamp)
	if clamp then x, z = clamp(x, z) end
	return { x = x, z = z }
end

local function startSearch(state, x, z, now, phase, clamp)
	state.stalk = nil
	state.point = place(x, z, clamp)
	state.lookIndex = 0
	state.untilAt = now + (Brain.PROFILES[phase] or DAY).searchSeconds
	Brain.set(state, "Search", now)
end

-- A capture noise. Returns whether it was heard and how strong it was where the guardian stands. It never
-- interrupts a fight. A faint noise makes it suspicious; a loud one, or any noise while it is already looking for
-- someone, sends it to investigate.
function Brain.hear(state, noise, gx, gz, now, phase, clamp)
	if type(state) ~= "table" or type(noise) ~= "table" or COMBAT[state.mode] then return false end
	if not finite(noise.x) or not finite(noise.z) or not finite(gx) or not finite(gz) or not finite(now) then return false end
	local radius = Brain.noiseRadius(noise.kind, noise.tier, phase)
	local away = distance(noise.x, noise.z, gx, gz)
	if radius <= 0 or away > radius then return false end
	local strength = 1 - away / radius
	state.point = place(noise.x, noise.z, clamp)
	-- I4: a scream the territory clamp moved came from beyond the leash; the guardian will only stalk the edge.
	local moved = distance(state.point.x, state.point.z, noise.x, noise.z) > 1
	state.stalk = noise.kind == "scream" and moved and { x = noise.x, z = noise.z } or nil
	state.heardAt = now
	if state.mode == "Investigate" or state.mode == "Search" or strength >= C.LOUD then
		state.untilAt = now + C.INVESTIGATE_MAX_SECONDS
		Brain.set(state, "Investigate", now)
	else
		state.untilAt = now + C.SUSPICIOUS_SECONDS
		Brain.set(state, "Suspicious", now)
	end
	return true, strength
end

-- The chase lost its quarry: search where it was last seen.
function Brain.lostSight(state, x, z, now, phase, clamp)
	if type(state) ~= "table" or not finite(x) or not finite(z) or not finite(now) then return end
	startSearch(state, x, z, now, phase, clamp)
end

-- A player was detected. Returns the wind-up before the chase; spotting someone again during a search is quicker.
function Brain.engage(state, now, phase)
	local seconds = state.mode == "Search" and C.REACQUIRE_ALERT_SECONDS or (Brain.PROFILES[phase] or DAY).alertSeconds
	Brain.set(state, "Alert", now)
	return seconds
end

-- Whether to look for players this step. While it recovers after an attack it does not.
function Brain.canDetect(state, now, recoveryEndsAt)
	local mode = state.mode
	if mode == "Retreat" then return finite(now) and finite(recoveryEndsAt) and now >= recoveryEndsAt end
	return mode == "Patrol" or mode == "Suspicious" or mode == "Investigate" or mode == "Search"
end

function Brain.chaseExpired(startedAt, now, phase)
	return finite(startedAt) and finite(now) and now - startedAt >= (Brain.PROFILES[phase] or DAY).chaseSeconds
end

-- The look-around point for this step of a search: the last known spot first, then around it.
local function lookPoint(state, clamp)
	local point = state.point
	if state.lookIndex == 0 then return point end
	local angle = (state.lookIndex - 1) * math.pi / 2 + math.pi / 4
	return place(point.x + math.cos(angle) * C.SEARCH_RADIUS, point.z + math.sin(angle) * C.SEARCH_RADIUS, clamp)
end

-- One step of the non-combat states. Returns { mode, speed, destination = {x, z}?, face = {x, z}? }. Patrol and
-- Retreat routes stay with the world script (its patrol diamond and its current anchor).
function Brain.step(state, now, gx, gz, phase, clamp)
	local mode = state.mode
	if not finite(now) or not finite(gx) or not finite(gz) then return { mode = mode, speed = 0 } end
	if mode == "Suspicious" then
		if now < state.untilAt then return { mode = mode, speed = 0, face = state.point } end
		state.untilAt = now + C.INVESTIGATE_MAX_SECONDS
		Brain.set(state, "Investigate", now)
		mode = "Investigate"
	end
	if mode == "Investigate" then
		local point = state.point
		if distance(gx, gz, point.x, point.z) <= C.ARRIVE_RADIUS or now >= state.untilAt then
			local stalk = state.stalk
			startSearch(state, point.x, point.z, now, phase, nil)
			if stalk then
				state.stalk, state.untilAt = stalk, now + C.STALK_SECONDS
			end
			mode = "Search"
		else
			return { mode = mode, speed = Brain.speed(mode, phase), destination = point }
		end
	end
	if mode == "Search" then
		if now >= state.untilAt then
			Brain.set(state, "Retreat", now)
			return { mode = "Retreat", speed = Brain.speed("Retreat", phase) }
		end
		if state.stalk then
			return { mode = mode, speed = Brain.speed(mode, phase), destination = state.point, face = state.stalk }
		end
		local look = lookPoint(state, clamp)
		if distance(gx, gz, look.x, look.z) <= C.ARRIVE_RADIUS then
			state.lookIndex = state.lookIndex % 4 + 1
			look = lookPoint(state, clamp)
		end
		return { mode = mode, speed = Brain.speed(mode, phase), destination = look }
	end
	return { mode = mode, speed = Brain.speed(mode, phase) }
end

return Brain

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
	ARRIVE_RADIUS = 3, -- this close to a point counts as there
	SEARCH_RADIUS = 7, -- look-around points circle the last known spot at this distance
	REACQUIRE_ALERT_SECONDS = 0.6, -- spotting its quarry again while searching needs a shorter wind-up
})
local C = Brain.CONSTANTS

-- Studs per second, seconds and studs. Day is the least aggressive phase, Night the most active. Every hunt speed
-- stays below a carrying player's 14 (WildboundLumipolWild.CONSTANTS.CREATURE_CARRY_SPEED) and below the slowest
-- loaded-pouch walk, 11 (the economy simulator checks it), so running away always works; detection is the sight
-- radius for a new target and stays inside the chase range (65).
local DAY = { patrol = 4, investigate = 6, hunt = 7, search = 5, retreat = 6, hearing = 0.8,
	searchSeconds = 6, chaseSeconds = 10, alertSeconds = 1.2, detection = 26 }
local TWILIGHT = { patrol = 4.5, investigate = 7, hunt = 9, search = 5.5, retreat = 6.5, hearing = 1.0,
	searchSeconds = 9, chaseSeconds = 12, alertSeconds = 1.0, detection = 32 }
Brain.PROFILES = freeze({
	Day = DAY, Dusk = TWILIGHT, Dawn = table.clone(TWILIGHT),
	Night = { patrol = 5, investigate = 8, hunt = 10, search = 6, retreat = 7, hearing = 1.3,
		searchSeconds = 12, chaseSeconds = 15, alertSeconds = 0.9, detection = 38 },
})

-- Capture noise (C1): base hearing radius in studs per capture step, scaled by the slot's tier and the phase.
-- Delivery D5 adds sprinting (16) and the rustle of entering a hiding spot (10).
Brain.NOISE = freeze({ ring = 32, seal = 48, sprint = 16, rustle = 10 })
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
			startSearch(state, point.x, point.z, now, phase, nil)
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

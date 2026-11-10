-- Arrullo (decision Q2b, docs/mechanics/wildbound-new-mechanics.md section 1): the rare-egg minigame that replaces the
-- capture ring for Rara, Epica and Legendaria eggs. A vertical bar from 0 (bottom) to 1 (top) holds a calm zone that
-- drifts on smooth noise, faster and smaller for rarer eggs. The player holds to raise a marker and releases to let it
-- fall; while the marker is inside the zone the egg calms (progress fills), outside it the egg frets (progress drains).
-- Win at GOAL, lose at zero or at the timeout. Original naming and look: a lullaby meter, not any other game's art.
-- Pure: the time step and the rolls are passed in. The server owns a session and simulates it on its own clock; the
-- client sends only "hold" or "release" and draws `view()`. Every number is a hypothesis to tune in play.
local Arrullo = {}

Arrullo.CONSTANTS = table.freeze({
	GOAL = 100, -- progress needed to win
	START = 35, -- progress at the start: a few seconds of grace before an empty meter loses
	TIMEOUT = 18, -- simulated seconds before the egg gives up
	LIFT = 2.4, -- bar units per second squared while holding
	GRAVITY = 2.0, -- bar units per second squared while released
	MAX_SPEED = 0.9, -- bar units per second, either way
})
-- Per rarity: zone (its height on the bar), segment (seconds the zone takes to glide to its next spot, varied by
-- +-25 %), fill and drain (progress per second inside and outside).
Arrullo.RARITIES = table.freeze({
	Rara = table.freeze({ zone = 0.30, segment = 1.6, fill = 22, drain = 12 }),
	Epica = table.freeze({ zone = 0.24, segment = 1.2, fill = 20, drain = 14 }),
	Legendaria = table.freeze({ zone = 0.18, segment = 0.9, fill = 18, drain = 16 }),
})
local FIELDS = table.freeze({ ZONE = "zone", SEGMENT = "segment", FILL = "fill", DRAIN = "drain" })
-- Fair ranges for any tuned value.
Arrullo.FILL_MAX = 60
Arrullo.TIMEOUT_MIN, Arrullo.TIMEOUT_MAX = 8, 60
local RANGES = table.freeze({
	zone = { 0.1, 0.6 }, segment = { 0.4, 4 }, fill = { 5, Arrullo.FILL_MAX }, drain = { 2, 60 },
})
-- Simulation limits: one step is at most MAX_DT; the server advances in SUBSTEP slices and never catches up more than
-- MAX_CATCHUP at once (a server hitch never decides the outcome). INPUT_RATE: client messages per second at most.
Arrullo.MAX_DT = 0.1
Arrullo.SUBSTEP = 1 / 30
Arrullo.MAX_CATCHUP = 0.5
Arrullo.INPUT_RATE = 20

-- Neutral Spanish player strings (the Studio writer may move them into WildboundText).
Arrullo.TEXT = table.freeze({
	title = "Arrullo",
	hint = "Mantén presionado para subir y suelta para bajar. Deja la marca dentro de la zona tranquila.",
	won = "¡El huevo se calmó! Es tuyo.",
	lost = "El huevo se asustó. Inténtalo otra vez.",
	timeout = "El huevo no se calmó a tiempo.",
})

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- Dev tuning (docs/testing/wildbound-tuning.md): CONSTANTS and RARITIES stay the defaults the tests pin; the rules read
-- `live`, which the server's tuning bridge may override with flat keys (TIMEOUT, ZONE_Rara, FILL_Epica, ...).
local live = { RARITIES = {} }
Arrullo.live = live

function Arrullo.tunable()
	local rows = table.clone(Arrullo.CONSTANTS)
	for rarity, row in pairs(Arrullo.RARITIES) do
		for prefix, field in pairs(FIELDS) do rows[prefix .. "_" .. rarity] = row[field] end
	end
	return rows
end

function Arrullo.tune(overrides)
	for key, value in pairs(Arrullo.CONSTANTS) do live[key] = value end
	for rarity, row in pairs(Arrullo.RARITIES) do live.RARITIES[rarity] = table.clone(row) end
	if type(overrides) == "table" then
		for key, value in pairs(overrides) do
			if type(key) == "string" and finite(value) then
				if Arrullo.CONSTANTS[key] ~= nil then
					live[key] = value
				else
					local prefix, rarity = string.match(key, "^(%u+)_(%a+)$")
					local field = prefix and FIELDS[prefix]
					if field and live.RARITIES[rarity] then
						local range = RANGES[field]
						live.RARITIES[rarity][field] = math.clamp(value, range[1], range[2])
					end
				end
			end
		end
	end
	live.GOAL = Arrullo.CONSTANTS.GOAL -- the goal is the meter's scale, never tuned
	live.TIMEOUT = math.clamp(live.TIMEOUT, Arrullo.TIMEOUT_MIN, Arrullo.TIMEOUT_MAX)
	live.START = math.clamp(live.START, 5, live.GOAL - 5)
	live.LIFT = math.clamp(live.LIFT, 0.5, 8)
	live.GRAVITY = math.clamp(live.GRAVITY, 0.5, 8)
	live.MAX_SPEED = math.clamp(live.MAX_SPEED, 0.2, 3)
end
Arrullo.tune(nil)

-- A roll in [0, 1) from a function or a Random-like object (`:NextNumber()`); nil when there is none.
local function roll(rng)
	local value
	if type(rng) == "function" then
		value = rng()
	elseif (type(rng) == "table" or type(rng) == "userdata") and rng.NextNumber then
		value = rng:NextNumber()
	end
	if not finite(value) then return nil end
	return math.clamp(value, 0, 0.999999)
end

local function hasRng(rng)
	return type(rng) == "function" or ((type(rng) == "table" or type(rng) == "userdata") and rng.NextNumber ~= nil)
end

local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- The zone's centre for a normalised spot u in [0, 1]: the zone always fits on the bar.
local function centreOf(u, zone)
	local half = zone / 2
	return half + u * (1 - zone)
end

local function segmentLength(row, rng)
	local r = roll(rng) or 0.5
	return row.segment * (0.75 + 0.5 * r)
end

function Arrullo.new(rarity, rng)
	local row = type(rarity) == "string" and live.RARITIES[rarity]
	if not row then return nil, "UnknownRarity" end
	if not hasRng(rng) then return nil, "NoRng" end
	local from = roll(rng) or 0.5
	local to = roll(rng) or from
	return {
		rarity = rarity, status = "running", reason = nil,
		progress = live.START, marker = 0, velocity = 0, elapsed = 0,
		zoneFrom = from, zoneTo = to, zoneT = 0, zoneSegment = segmentLength(row, rng),
		zoneCenter = centreOf(from, row.zone),
	}
end

function Arrullo.zoneBounds(state)
	local row = live.RARITIES[state.rarity]
	local half = row.zone / 2
	return state.zoneCenter - half, state.zoneCenter + half
end

-- One step of `dt` seconds. holding: true raises the marker, anything else lets it fall. Returns { status, inside,
-- progress }. A finished state never changes again.
function Arrullo.step(state, dt, holding, rng)
	local out = { status = type(state) == "table" and state.status or "invalid", inside = false,
		progress = type(state) == "table" and state.progress or 0 }
	if type(state) ~= "table" or state.status ~= "running" then return out end
	if not finite(dt) or dt <= 0 then return out end
	dt = math.min(dt, Arrullo.MAX_DT)
	local row = live.RARITIES[state.rarity]

	-- The zone glides from one spot to the next with an eased curve, so its speed is zero at each spot: no jumps.
	state.zoneT += dt
	if state.zoneT >= state.zoneSegment then
		state.zoneT -= state.zoneSegment
		state.zoneFrom = state.zoneTo
		local nextSpot = roll(rng)
		if nextSpot then state.zoneTo = nextSpot end
		state.zoneSegment = segmentLength(row, rng)
		state.zoneT = math.min(state.zoneT, state.zoneSegment)
	end
	local u = state.zoneFrom + (state.zoneTo - state.zoneFrom) * smooth(state.zoneT / state.zoneSegment)
	state.zoneCenter = centreOf(u, row.zone)

	-- The marker: lift while holding, gravity otherwise; the ends of the bar are walls.
	if holding == true then state.velocity += live.LIFT * dt else state.velocity -= live.GRAVITY * dt end
	state.velocity = math.clamp(state.velocity, -live.MAX_SPEED, live.MAX_SPEED)
	state.marker += state.velocity * dt
	if state.marker >= 1 then
		state.marker = 1
		if state.velocity > 0 then state.velocity = 0 end
	elseif state.marker <= 0 then
		state.marker = 0
		if state.velocity < 0 then state.velocity = 0 end
	end

	local low, high = Arrullo.zoneBounds(state)
	local inside = state.marker >= low and state.marker <= high
	if inside then state.progress += row.fill * dt else state.progress -= row.drain * dt end
	state.elapsed += dt

	if state.progress >= live.GOAL then
		state.progress, state.status, state.reason = live.GOAL, "won", "Calm"
	elseif state.progress <= 0 then
		state.progress, state.status, state.reason = 0, "lost", "Empty"
	elseif state.elapsed >= live.TIMEOUT then
		state.status, state.reason = "lost", "Timeout"
	end
	out.status, out.inside, out.progress = state.status, inside, state.progress
	return out
end

-- The server's session. The client's only words are "hold" and "release".
local INPUTS = table.freeze({ hold = true, release = false })

function Arrullo.session(rarity, rng, now)
	if not finite(now) then return nil, "BadClock" end
	local state, reason = Arrullo.new(rarity, rng)
	if not state then return nil, reason end
	return { state = state, holding = false, lastAt = now, rng = rng, windowAt = now, windowCount = 0 }
end

-- Simulates from the last update to `now` in SUBSTEP slices, at most MAX_CATCHUP. Time never runs backwards.
function Arrullo.advance(session, now, rng)
	if type(session) ~= "table" or not finite(now) then return { status = "invalid" } end
	rng = rng or session.rng
	local gap = now - session.lastAt
	if gap <= 0 then return { status = session.state.status, progress = session.state.progress } end
	session.lastAt = now
	local remaining = math.min(gap, Arrullo.MAX_CATCHUP)
	local out = { status = session.state.status, progress = session.state.progress }
	while remaining > 1e-9 and session.state.status == "running" do
		local dt = math.min(Arrullo.SUBSTEP, remaining)
		out = Arrullo.step(session.state, dt, session.holding, rng)
		remaining -= dt
	end
	return out
end

-- A client message. Returns true, or false and "Invalid", "BadInput", "BadClock", "RateLimited" or "Finished". The
-- server first simulates up to `now` with the old input, so a press counts from the moment it arrives.
function Arrullo.input(session, value, now)
	if type(session) ~= "table" then return false, "Invalid" end
	if type(value) ~= "string" or INPUTS[value] == nil then return false, "BadInput" end
	if not finite(now) then return false, "BadClock" end
	if session.state.status ~= "running" then return false, "Finished" end
	if now - session.windowAt >= 1 then session.windowAt, session.windowCount = now, 0 end
	if session.windowCount >= Arrullo.INPUT_RATE then return false, "RateLimited" end
	session.windowCount += 1
	Arrullo.advance(session, now)
	session.holding = INPUTS[value]
	return true
end

-- What the client draws: the zone, the marker, progress as a fraction, the status and the time left.
function Arrullo.view(state)
	local low, high = Arrullo.zoneBounds(state)
	return {
		zoneLow = low, zoneHigh = high, marker = state.marker,
		progress = state.progress / live.GOAL, status = state.status, reason = state.reason,
		remaining = math.max(0, live.TIMEOUT - state.elapsed),
	}
end

return Arrullo

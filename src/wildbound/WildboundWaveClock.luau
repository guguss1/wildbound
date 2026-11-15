-- Random world (plan Part 6, RW3): the server's wave clock, pure. A wave lasts WAVE_SECONDS (300); the first starts the
-- moment the server opens. Each wave start rerolls the random spawns, reshuffles the Refugios and resets the wave board
-- (who banked the most Esencia this wave, session only). The WorldEvent remote carries what clients draw: the wave,
-- the board's top 3 and the biome events. Messages are built and read here, so the server only sends well-formed tables
-- and the client drops anything else. The clock is passed in; nothing here reads a service.
local WaveClock = {}

local function freeze(value)
	if type(value) == "table" and not table.isfrozen(value) then
		for _, child in pairs(value) do freeze(child) end
		table.freeze(value)
	end
	return value
end

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- WAVE_SECONDS: one wave. BOARD_SIZE: names on the board. FIRST_EGG_RADIUS: studs from camp for the first wave's
-- guaranteed common egg. NAME_BYTES: a board name is cut to this many bytes.
WaveClock.CONSTANTS = freeze({
	WAVE_SECONDS = 300,
	BOARD_SIZE = 3,
	FIRST_EGG_RADIUS = 70,
	NAME_BYTES = 20,
	-- RW4: Refugios per wave, their radius in studs and the stamina regeneration inside.
	REFUGE_MIN = 2, REFUGE_MAX = 3, REFUGE_RADIUS = 12, REFUGE_REGEN = 2,
	-- RW5: the biome event: the first at minute 5, then every 20 minutes, visible 5 minutes, at a Legendaria point
	-- within EVENT_RADIUS of La Silueta's home.
	EVENT_FIRST = 300, EVENT_EVERY = 1200, EVENT_SECONDS = 300, EVENT_RADIUS = 45,
	-- RW6: the biome variant changes every this many waves (not by nights: no mechanic is gated by nights survived).
	VARIANT_EVERY_WAVES = 1,
	-- CA4 (pack 05_SISTEMAS/01): the last WARNING_SECONDS of a wave are its Warning window (no new steal hold).
	WARNING_SECONDS = 10,
})
-- CA4: the seconds before a refresh at which every client shows the countdown notice.
WaveClock.ALERTS = freeze({ 10, 5, 3, 2, 1 })
-- RW6: the variants in rotation order, and how each weights the spawn points' kinds (WildboundSpawnClock.setWeights).
WaveClock.VARIANTS = freeze({ "Niebla", "Escarcha", "Ceniza", "Floracion" })
WaveClock.VARIANT_WEIGHTS = freeze({
	Niebla = {},
	Escarcha = { canopy = 0.5, rock = 1.5, log = 1.5 },
	Ceniza = { rock = 2, log = 2, root = 2, canopy = 0.5 },
	Floracion = { canopy = 2, treeBase = 1.5, trail = 1.5 },
})
WaveClock.REMOTE = "WorldEvent"
WaveClock.KINDS = freeze({ wave = true, board = true, event = true })

local TUNABLE = { "WAVE_SECONDS", "FIRST_EGG_RADIUS", "REFUGE_MIN", "REFUGE_MAX", "REFUGE_RADIUS", "REFUGE_REGEN",
	"EVENT_FIRST", "EVENT_EVERY", "EVENT_SECONDS", "EVENT_RADIUS", "VARIANT_EVERY_WAVES" }
local FLOORS = { WAVE_SECONDS = 10, FIRST_EGG_RADIUS = 20, REFUGE_RADIUS = 4, REFUGE_REGEN = 1, EVENT_EVERY = 30,
	EVENT_SECONDS = 10, EVENT_RADIUS = 10, VARIANT_EVERY_WAVES = 1 }
WaveClock.live = {}

function WaveClock.tunable()
	local defaults = {}
	for _, key in ipairs(TUNABLE) do defaults[key] = WaveClock.CONSTANTS[key] end
	return defaults
end

-- Dev tuning: CONSTANTS stays the default; the bridge overrides at runtime. No override, no change.
function WaveClock.tune(overrides)
	table.clear(WaveClock.live)
	for key, value in pairs(WaveClock.CONSTANTS) do WaveClock.live[key] = value end
	if type(overrides) ~= "table" then return end
	for _, key in ipairs(TUNABLE) do
		local value = overrides[key]
		if finite(value) and value >= (FLOORS[key] or 0) then WaveClock.live[key] = value end
	end
end
WaveClock.tune(nil)

function WaveClock.new(startedAt)
	startedAt = finite(startedAt) and startedAt or 0
	return { startedAt = startedAt, wave = 0, waveStartedAt = nil, board = {}, order = 0,
		nextEventAt = startedAt + WaveClock.live.EVENT_FIRST, eventIndex = 0, event = nil }
end

-- The wave a clock is in at `now` (1 from the start). A tuned length counts from the current wave's own start, so a
-- live change never jumps back.
local function due(state, now)
	if state.wave == 0 then return true end
	return now >= state.waveStartedAt + WaveClock.live.WAVE_SECONDS
end

-- Returns the events this step, in order: { type = "waveStarted", wave, startedAt, endsAt }. A long gap starts one
-- wave, not a backlog.
function WaveClock.step(state, now)
	local events = {}
	if type(state) ~= "table" or not finite(now) then return events end
	if due(state, now) then
		state.wave += 1
		state.waveStartedAt = now
		table.clear(state.board)
		state.order = 0
		table.insert(events, { type = "waveStarted", wave = state.wave, startedAt = now,
			endsAt = now + WaveClock.live.WAVE_SECONDS })
	end
	-- RW5: one biome event at a time; it ends after EVENT_SECONDS, claimed or not.
	if state.event and now >= state.event.endsAt then
		table.insert(events, { type = "eventEnded", index = state.event.index, claimed = state.event.claimant ~= nil })
		state.event = nil
	end
	-- The first event counts from the server's start with the live EVENT_FIRST, so a tuned value reaches it.
	local dueAt = state.eventIndex == 0 and state.startedAt + WaveClock.live.EVENT_FIRST or state.nextEventAt
	if not state.event and now >= dueAt then
		state.eventIndex += 1
		state.nextEventAt = now + WaveClock.live.EVENT_EVERY
		state.event = { index = state.eventIndex, startedAt = now, endsAt = now + WaveClock.live.EVENT_SECONDS }
		table.insert(events, { type = "eventStarted", index = state.eventIndex, endsAt = state.event.endsAt })
	end
	return events
end

-- RW6: the biome variant of a wave (1 = the first). Anything that is not a wave number reads as the first.
function WaveClock.variantFor(wave)
	if not finite(wave) or wave < 1 then wave = 1 end
	local every = math.max(1, math.floor(WaveClock.live.VARIANT_EVERY_WAVES + 0.5))
	local index = math.floor((math.floor(wave) - 1) / every) % #WaveClock.VARIANTS + 1
	return WaveClock.VARIANTS[index]
end

-- RW5: the event egg's one claimant. Returns true for the first claim of a live event only.
function WaveClock.claimEvent(state, key)
	local event = type(state) == "table" and state.event or nil
	if not event or event.claimant ~= nil or key == nil then return false end
	event.claimant = key
	return true
end

-- CA4 (user, 2026-11-15; Caramelo pack 05_SISTEMAS/01): this clock is the only world clock (no day/night cycle). The
-- warning lasts WARNING_SECONDS, at most half a (tuned) wave.
local function warningSeconds()
	return math.min(WaveClock.CONSTANTS.WARNING_SECONDS, WaveClock.live.WAVE_SECONDS * 0.5)
end

-- The window at `now`: { name = "Collect" | "Warning" | "Idle", wave, endsAt, remaining }. "Collect" from the wave's
-- start to WARNING_SECONDS before its end, then "Warning" until the refresh (the next step's waveStarted); "Idle"
-- before the first wave or for a bad clock.
function WaveClock.window(state, now)
	if type(state) ~= "table" or not finite(now) or state.wave == 0 or not finite(state.waveStartedAt) then
		return { name = "Idle", wave = 0 }
	end
	local endsAt = state.waveStartedAt + WaveClock.live.WAVE_SECONDS
	local remaining = math.max(0, endsAt - now)
	return { name = now >= endsAt - warningSeconds() and "Warning" or "Collect", wave = state.wave, endsAt = endsAt,
		remaining = remaining }
end

-- Whether a steal hold that began at `startedAt` may complete: not when it began inside a Warning window, the current
-- wave's or the one just before the refresh, so a hold begun at 295 is still refused after the refresh at 300 while a
-- hold begun at 289 resolves across it. True before the first wave; false for a bad time.
function WaveClock.holdAllowed(state, startedAt)
	if not finite(startedAt) then return false end
	if type(state) ~= "table" or state.wave == 0 or not finite(state.waveStartedAt) then return true end
	local warning = warningSeconds()
	local endsAt = state.waveStartedAt + WaveClock.live.WAVE_SECONDS
	if startedAt >= endsAt - warning and startedAt < endsAt then return false end
	if startedAt >= state.waveStartedAt - warning and startedAt < state.waveStartedAt then return false end
	return true
end

function WaveClock.endsAt(state)
	if type(state) ~= "table" or not finite(state.waveStartedAt) then return nil end
	return state.waveStartedAt + WaveClock.live.WAVE_SECONDS
end

local function cleanName(name)
	if type(name) ~= "string" then return "?" end
	name = name:gsub("[%c]", "")
	if #name > WaveClock.CONSTANTS.NAME_BYTES then name = name:sub(1, WaveClock.CONSTANTS.NAME_BYTES) end
	return #name > 0 and name or "?"
end

-- A player banked `amount` Esencia this wave. Returns true when it counted.
function WaveClock.bank(state, key, name, amount)
	if type(state) ~= "table" or key == nil or not finite(amount) or amount <= 0 then return false end
	local row = state.board[key]
	if not row then
		state.order += 1
		row = { name = cleanName(name), amount = 0, order = state.order }
		state.board[key] = row
	end
	row.amount += amount
	return true
end

-- The board's top `n` (default BOARD_SIZE): { { name, amount } } by amount, ties to whoever banked first.
function WaveClock.top(state, n)
	n = finite(n) and n or WaveClock.CONSTANTS.BOARD_SIZE
	local rows = {}
	if type(state) == "table" then
		for _, row in pairs(state.board) do table.insert(rows, row) end
	end
	table.sort(rows, function(a, b)
		if a.amount ~= b.amount then return a.amount > b.amount end
		return a.order < b.order
	end)
	local out = {}
	for i = 1, math.min(n, #rows) do out[i] = { name = rows[i].name, amount = math.floor(rows[i].amount + 0.5) } end
	return out
end

-- What the WorldEvent remote carries. kind "wave": { wave, endsAt, variant?, variantChanged?, board };
-- "board": { board }; "event": { phase = "start"|"end"|"claimed", species, endsAt? }. Anything else is nil.
local function cleanBoard(board)
	local out = {}
	if type(board) ~= "table" then return out end
	for i = 1, math.min(#board, WaveClock.CONSTANTS.BOARD_SIZE) do
		local row = board[i]
		if type(row) ~= "table" or type(row.name) ~= "string" or not finite(row.amount) then return nil end
		out[i] = { name = cleanName(row.name), amount = math.max(0, math.floor(row.amount + 0.5)) }
	end
	if #board > WaveClock.CONSTANTS.BOARD_SIZE then return nil end
	return out
end

local PHASES = { start = true, ["end"] = true, claimed = true }

function WaveClock.message(kind, data)
	if not WaveClock.KINDS[kind] or type(data) ~= "table" then return nil end
	if kind == "wave" then
		if not finite(data.wave) or data.wave < 1 or not finite(data.endsAt) then return nil end
		local board = cleanBoard(data.board)
		if not board then return nil end
		local variant = data.variant
		if variant ~= nil and (type(variant) ~= "string" or #variant > 16) then return nil end
		return { kind = "wave", wave = math.floor(data.wave), endsAt = data.endsAt, variant = variant,
			variantChanged = data.variantChanged == true, board = board }
	elseif kind == "board" then
		local board = cleanBoard(data.board)
		if not board then return nil end
		return { kind = "board", board = board }
	else
		if not PHASES[data.phase] or type(data.species) ~= "string" or #data.species > 32 then return nil end
		if data.endsAt ~= nil and not finite(data.endsAt) then return nil end
		if data.by ~= nil and type(data.by) ~= "string" then return nil end
		return { kind = "event", phase = data.phase, species = data.species, endsAt = data.endsAt,
			by = data.by ~= nil and cleanName(data.by) or nil }
	end
end

local function roll(rand)
	if type(rand) == "table" or typeof(rand) == "Random" then
		local ok, value = pcall(function() return rand:NextNumber() end)
		if ok and finite(value) then return math.clamp(value, 0, 0.999999) end
	end
	return 0
end

-- RW4: this wave's Refugios: REFUGE_MIN to REFUGE_MAX distinct candidates (WildboundSpawnGraph.refugeCandidates), new
-- ones first, so the set moves every wave when it can.
function WaveClock.pickRefuges(candidates, rand, previous)
	local out = {}
	if type(candidates) ~= "table" then return out end
	local old = {}
	for _, refuge in ipairs(type(previous) == "table" and previous or {}) do
		if type(refuge) == "table" and refuge.id ~= nil then old[refuge.id] = true end
	end
	local fresh, used = {}, {}
	for _, candidate in ipairs(candidates) do
		if type(candidate) == "table" and type(candidate.id) == "string" and finite(candidate.x) and finite(candidate.z) then
			table.insert(old[candidate.id] and used or fresh, candidate)
		end
	end
	local low = math.max(0, math.floor(WaveClock.live.REFUGE_MIN + 0.5))
	local high = math.max(low, math.floor(WaveClock.live.REFUGE_MAX + 0.5))
	local count = math.min(low + math.floor(roll(rand) * (high - low + 1)), #fresh + #used)
	for _, pool in ipairs({ fresh, used }) do
		while #out < count and #pool > 0 do
			local index = math.floor(roll(rand) * #pool) + 1
			local candidate = table.remove(pool, index)
			table.insert(out, { id = candidate.id, x = candidate.x, z = candidate.z, ground = candidate.ground })
		end
	end
	return out
end

-- The client's check: a message is read only when it rebuilds to itself through WaveClock.message.
function WaveClock.read(message)
	if type(message) ~= "table" then return nil end
	return WaveClock.message(message.kind, message)
end

return WaveClock

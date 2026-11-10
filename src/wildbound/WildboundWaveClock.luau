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
})
WaveClock.REMOTE = "WorldEvent"
WaveClock.KINDS = freeze({ wave = true, board = true, event = true })

local TUNABLE = { "WAVE_SECONDS", "FIRST_EGG_RADIUS", "REFUGE_MIN", "REFUGE_MAX", "REFUGE_RADIUS", "REFUGE_REGEN",
	"EVENT_FIRST", "EVENT_EVERY", "EVENT_SECONDS", "EVENT_RADIUS" }
local FLOORS = { WAVE_SECONDS = 10, FIRST_EGG_RADIUS = 20, REFUGE_RADIUS = 4, REFUGE_REGEN = 1, EVENT_EVERY = 30,
	EVENT_SECONDS = 10, EVENT_RADIUS = 10 }
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

-- RW5: the event egg's one claimant. Returns true for the first claim of a live event only.
function WaveClock.claimEvent(state, key)
	local event = type(state) == "table" and state.event or nil
	if not event or event.claimant ~= nil or key == nil then return false end
	event.claimant = key
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

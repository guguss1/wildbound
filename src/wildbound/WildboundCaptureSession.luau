-- Pure capture rule: one session per player, one owner per encounter, skill read from server positions.
-- Inputs are server-read values passed by value and the clock is injected. Clients supply nothing here
-- except an untrusted token on cancel and on seal. See docs/mechanics/wildbound-capture.md for states and wiring.
-- Delivery A (H1): a full calm meter opens a timed seal step judged by the server's clock alone. The rule names
-- reasons only; the words a player reads live in WildboundText (H3).
local CaptureSession = {}
CaptureSession.__index = CaptureSession

-- All hypotheses. Shared with the client, which draws the ring from RING_RADIUS_VISIBLE and ringCenter.
CaptureSession.CONSTANTS = table.freeze({
	START_RANGE = 10,
	CALM_REQUIRED = 4.5,
	RING_RADIUS_VISIBLE = 4.5,
	RING_RADIUS_SERVER = 5,
	RING_SPEED = 1.5,
	-- Above the tested radius, so no fixed spot can stay inside the ring for the whole orbit.
	ORBIT_MIN = 5.5,
	ORBIT_MAX = 9,
	STILL_SPEED = 5,
	-- Stillness is also judged over a short window (found in W5): shuffling a stud back and forth stays under
	-- STILL_SPEED on every sample. Path length over the last STILL_WINDOW seconds, divided by its span in seconds,
	-- must stay at or under STILL_PATH_RATE, twice the ring's own speed, so following the ring or swaying a
	-- little is still, and shuffling is not. Needs STILL_MIN_SPAN seconds of history; stopping after real
	-- movement waits for the window to pass.
	STILL_WINDOW = 1,
	STILL_PATH_RATE = 3,
	STILL_MIN_SPAN = 0.55,
	JUMP_SPEED = 40,
	OUTSIDE_DRAIN = 0.5,
	OUTSIDE_LIMIT = 2.5,
	TIME_LIMIT = 12,
	TOO_FAR_HORIZONTAL = 18,
	TOO_FAR_VERTICAL = 8,
	SAMPLE = 0.2,
	-- Over the sample length, because the real fixed step runs 0.2 to about 0.217 s.
	MAX_ELAPSED = 0.25,
	STALL_AFTER = 0.5,
	MAX_STALL_EXTENSION = 4,
	BAD_SAMPLE_LIMIT = 5,
	WATCHDOG_GRACE = 1,
	RETRY_COOLDOWN = 6,
	-- A player's MAX_FAILS-th failure on one encounter costs that player this hold-off. Nobody else is affected.
	LONG_COOLDOWN = 45,
	SPOOK_SECONDS = 2,
	MAX_FAILS = 3,
	-- H1 seal step. The marker waits SEAL_DELAY after the meter fills, then sweeps the bar from 0 to 1 in SEAL_SWEEP
	-- seconds. The band is SEAL_BAND of the bar wide (SEAL_BAND_SAFE on Safe slots), placed by a server roll inside
	-- [SEAL_LO_MIN, SEAL_HI_MAX]. A press counts when it arrives while the marker is in the band or up to SEAL_LATENCY
	-- seconds after it left: the latency allowance for the trip from the player's tap to the server. The client sends
	-- no timing; the server judges by its own clock when the request arrives.
	SEAL_DELAY = 0.4,
	SEAL_SWEEP = 1.6,
	SEAL_BAND = 0.2,
	SEAL_BAND_SAFE = 0.36,
	SEAL_LO_MIN = 0.3,
	SEAL_HI_MAX = 0.95,
	SEAL_LATENCY = 0.15,
})

-- How each reason ends a session. `fail` counts toward MAX_FAILS. A server fault costs the player nothing.
local ENDINGS = table.freeze({
	Completed = { phase = "Completed" },
	LeftRing = { phase = "Failed", spook = true, retry = true, fail = true },
	TimedOut = { phase = "Failed", spook = true, retry = true, fail = true },
	TooFar = { phase = "Failed", spook = true, retry = true, fail = true },
	Struck = { phase = "Failed", spook = true, retry = true, fail = true },
	Defeated = { phase = "Failed", spook = true, retry = true, fail = true },
	BackpackFull = { phase = "Failed", spook = true, retry = true },
	CollectionFull = { phase = "Failed", spook = true, retry = true },
	Cancelled = { phase = "Cancelled", spook = true, retry = true },
	Disconnected = { phase = "Cancelled" },
	Lost = { phase = "Failed" },
	LostTrack = { phase = "Failed" },
	Watchdog = { phase = "Failed" },
	SealMissed = { phase = "Failed", spook = true, retry = true, fail = true },
})

local C = CaptureSession.CONSTANTS
local EPSILON = 1e-7
local PHASES = table.freeze({ Active = true, Completed = true, Failed = true, Cancelled = true })
local SLOT_REFUSALS = table.freeze({ FirstCaptureOnly = true, FirstCapturePending = true })

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function validId(value)
	return type(value) == "string" and #value > 0 and #value <= 128
end

-- Same identity rule as WildboundState: the engine-provided user id, or a string in contracts.
local function playerKey(value)
	if validId(value) then return "s:" .. value end
	if finite(value) and value % 1 == 0 then return "n:" .. tostring(value) end
	return nil
end

local function length(x, z)
	return math.sqrt(x * x + z * z)
end

-- True only while a stamped delay is running. A clock that stepped back cannot stretch one past its length.
local function waiting(untilAt, now, span)
	return untilAt ~= nil and finite(now) and now < untilAt and untilAt - now <= span + EPSILON
end

function CaptureSession.new()
	return setmetatable({
		sessions = {}, -- token -> session
		byPlayer = {}, -- normalized key -> token
		reservations = {}, -- encounter id -> token
		encounters = {}, -- encounter id -> { spookedUntil, gone }
		retries = {}, -- normalized key -> { [encounter id] = { untilAt, span } }; survives leaving and rejoining
		failures = {}, -- normalized key -> { [encounter id] = count of that player's failures }
		serial = 0,
		counters = { anomaly = 0, watchdog = 0 },
	}, CaptureSession)
end

-- The ring always starts centered on the player, so standing still is the same chord from any start.
-- Inside the orbit range the Lumipol is the orbit center; outside it, the center shifts along their line.
local function buildRing(input)
	local a0 = math.atan2(input.z - input.lumipolZ, input.x - input.lumipolX)
	local distance = length(input.x - input.lumipolX, input.z - input.lumipolZ)
	local orbit = math.clamp(distance, C.ORBIT_MIN, C.ORBIT_MAX)
	return table.freeze({
		pivotX = input.x - orbit * math.cos(a0),
		pivotZ = input.z - orbit * math.sin(a0),
		y = input.y,
		orbit = orbit,
		a0 = a0,
		w = input.dir * C.RING_SPEED / orbit,
		startedAt = input.now,
		radius = C.RING_RADIUS_VISIBLE,
	})
end

-- t is seconds since the session began. Shared with the client, so no position stream is needed.
function CaptureSession.ringCenter(ring, t)
	if type(ring) ~= "table" or not finite(t) or not finite(ring.pivotX) or not finite(ring.pivotZ)
		or not finite(ring.orbit) or not finite(ring.a0) or not finite(ring.w) then
		return nil, nil
	end
	local angle = ring.a0 + ring.w * math.max(t, 0)
	return ring.pivotX + ring.orbit * math.cos(angle), ring.pivotZ + ring.orbit * math.sin(angle)
end

local function validStart(input)
	if input.alive ~= true or input.life == nil or input.life ~= input.life then return false end
	if not finite(input.distance) or input.distance < 0 or input.distance > C.START_RANGE then return false end
	if not (finite(input.x) and finite(input.y) and finite(input.z) and finite(input.now)
		and finite(input.lumipolX) and finite(input.lumipolZ)) then return false end
	if input.dir ~= 1 and input.dir ~= -1 then return false end
	return length(input.x - input.lumipolX, input.z - input.lumipolZ) <= C.START_RANGE + EPSILON
end

-- Checks run in the order of the capture document, with no yield before the reservation.
-- input = { playerKey, encounterId, dir, lumipolX, lumipolZ, now, alive, life, distance, x, y, z,
--           encounterStatus = "Open" | "Claimed" | other, slotRefusal?, bagRoom, collectionRoom,
--           wary?, tier?, sealRoll? (0 to 1, a server roll for the band's place) }
-- Returns true, view or false, reason.
function CaptureSession:begin(input)
	if type(input) ~= "table" then return false, "InvalidContext" end
	local key = playerKey(input.playerKey)
	if not key then return false, "InvalidPlayer" end
	local encounterId = input.encounterId
	if not validId(encounterId) then return false, "InvalidEncounter" end
	if self.byPlayer[key] then return false, "AlreadyCapturing" end
	if not validStart(input) then return false, "InvalidContext" end
	if input.encounterStatus == "Claimed" then return false, "AlreadyClaimed" end
	if input.encounterStatus ~= "Open" then return false, "InvalidEncounter" end
	local now = input.now
	local record = self.encounters[encounterId]
	if record and record.gone == "Captured" then return false, "AlreadyClaimed" end
	if self.reservations[encounterId] or (record and waiting(record.spookedUntil, now, C.SPOOK_SECONDS)) then
		return false, "Reserved"
	end
	local playerRetries = self.retries[key]
	local hold = playerRetries and playerRetries[encounterId]
	if hold and waiting(hold.untilAt, now, hold.span) then return false, "RetryWait" end
	-- A1: the server's brain says it is too scared to be calmed (Alert, Flee, or hiding before it peeks).
	if input.wary == true then return false, "Wary" end
	if input.slotRefusal ~= nil then
		return false, SLOT_REFUSALS[input.slotRefusal] and input.slotRefusal or "InvalidContext"
	end
	if input.bagRoom ~= true then return false, "BackpackFull" end
	if input.collectionRoom ~= true then return false, "CollectionFull" end

	self.serial += 1
	local token = "cap:" .. self.serial
	local session = {
		token = token, serial = self.serial, key = key, playerKey = input.playerKey, encounterId = encounterId,
		life = input.life, lumipolX = input.lumipolX, lumipolZ = input.lumipolZ, startY = input.y,
		ring = buildRing(input), startedAt = now, deadline = now + C.TIME_LIMIT,
		hardDeadline = now + C.TIME_LIMIT + C.MAX_STALL_EXTENSION, lastSample = now,
		lastX = input.x, lastZ = input.z, pathTotal = 0, trail = { { t = now, c = 0 } }, calm = 0, outsideFor = 0, inside = true, moving = false,
		struck = false, badSamples = 0, stage = "Calm", tier = input.tier, sealRoll = input.sealRoll, seal = nil,
	}
	self.sessions[token] = session
	self.byPlayer[key] = token
	self.reservations[encounterId] = token
	return true, self:view(token)
end

local function activeView(session)
	return { token = session.token, phase = "Active", calm = session.calm, inside = session.inside,
		moving = session.moving, outsideFor = session.outsideFor, deadline = session.deadline, stage = session.stage,
		seal = session.seal }
end

-- H1: the band for this session. A missing or unusable roll places it in the middle of its range.
local function openSeal(session, now)
	local width = session.tier == "Safe" and C.SEAL_BAND_SAFE or C.SEAL_BAND
	local roll = session.sealRoll
	if not finite(roll) or roll < 0 or roll > 1 then roll = 0.5 end
	local lo = C.SEAL_LO_MIN + roll * (C.SEAL_HI_MAX - C.SEAL_LO_MIN - width)
	session.stage = "Seal"
	session.seal = table.freeze({ startedAt = now + C.SEAL_DELAY, sweep = C.SEAL_SWEEP, lo = lo, hi = lo + width })
	local closes = session.seal.startedAt + C.SEAL_SWEEP + C.SEAL_LATENCY
	session.deadline = math.max(session.deadline, closes)
	session.hardDeadline = math.max(session.hardDeadline, closes)
end

local function sealCloses(session)
	return session.seal.startedAt + session.seal.sweep + C.SEAL_LATENCY
end

-- The current state with the ring, for the first push and for a resync. Fresh table on every call.
function CaptureSession:view(token)
	local session = validId(token) and self.sessions[token]
	if not session then return nil end
	local view = activeView(session)
	view.ring = session.ring
	return view
end

-- Every ending passes through here, so the reservation cannot outlive the session on any path.
local function finish(self, session, reason, now)
	local rule = ENDINGS[reason]
	local at = finite(now) and now >= session.lastSample and now or session.lastSample
	self.sessions[session.token] = nil
	self.byPlayer[session.key] = nil
	if self.reservations[session.encounterId] == session.token then
		self.reservations[session.encounterId] = nil
	end
	local record = self.encounters[session.encounterId]
	if reason == "Completed" or rule.spook then
		record = record or {}
		self.encounters[session.encounterId] = record
	end
	if reason == "Completed" then record.gone = "Captured" end
	if rule.spook then record.spookedUntil = at + C.SPOOK_SECONDS end
	-- Failures belong to the player who failed, so one player cannot make a Lumipol leave for everyone.
	-- The MAX_FAILS-th failure costs that player the long hold-off, and then the count starts over.
	local span = C.RETRY_COOLDOWN
	if rule.fail then
		local counts = self.failures[session.key] or {}
		self.failures[session.key] = counts
		local total = (counts[session.encounterId] or 0) + 1
		if total >= C.MAX_FAILS then
			total, span = 0, C.LONG_COOLDOWN
		end
		counts[session.encounterId] = total > 0 and total or nil
		if next(counts) == nil then self.failures[session.key] = nil end
	end
	local retryAt = rule.retry and at + span or nil
	if retryAt then
		self.retries[session.key] = self.retries[session.key] or {}
		self.retries[session.key][session.encounterId] = { untilAt = retryAt, span = span }
	end
	local out = activeView(session)
	out.phase, out.reason = rule.phase, reason
	-- Kept for the adapter's sake: a failure never removes a Lumipol any more. Only retire() does.
	out.grant, out.leaves, out.spook = reason == "Completed", false, rule.spook == true
	out.spookUntil, out.retryAt = rule.spook and at + C.SPOOK_SECONDS or nil, retryAt
	out.encounterId, out.playerKey = session.encounterId, session.playerKey
	return out
end

-- An unusable reading makes no progress. A run of them ends the session, so nothing can stay stuck.
local function badSample(self, session, now)
	session.badSamples += 1
	if session.badSamples >= C.BAD_SAMPLE_LIMIT then
		self.counters.anomaly += 1
		return finish(self, session, "LostTrack", now)
	end
	local view = activeView(session)
	view.bad = true
	return view
end

-- Path length per second over the last STILL_WINDOW seconds, or 0 while the history is shorter than STILL_MIN_SPAN.
local function windowedRate(session, now, displacement)
	session.pathTotal += displacement
	local trail = session.trail
	table.insert(trail, { t = now, c = session.pathTotal })
	-- The newest entry at or before the window start stays as the anchor.
	while #trail > 2 and trail[2].t <= now - C.STILL_WINDOW + EPSILON do table.remove(trail, 1) end
	local span = now - trail[1].t
	if span < C.STILL_MIN_SPAN - EPSILON then return 0 end
	return (session.pathTotal - trail[1].c) / span
end

-- obs = { now, alive, life, x, y, z, bagRoom, collectionRoom }, all read by the server.
-- Returns nil for a dead or malformed token. First match ends the session, in the document's order.
function CaptureSession:sample(token, obs)
	local session = validId(token) and self.sessions[token]
	if not session then return nil end
	if type(obs) ~= "table" then return badSample(self, session, nil) end
	local now = obs.now
	if obs.alive ~= true or obs.life ~= session.life then return finish(self, session, "Defeated", now) end
	if self.reservations[session.encounterId] ~= token then
		self.counters.anomaly += 1
		return finish(self, session, "Lost", now)
	end
	local clockOk = finite(now) and now >= session.lastSample
	local placed = finite(obs.x) and finite(obs.y) and finite(obs.z)
	local dt = clockOk and now - session.lastSample or 0
	local paced = math.max(dt, C.SAMPLE)
	local displacement = 0
	if placed then
		displacement = length(obs.x - session.lastX, obs.z - session.lastZ)
		if length(obs.x - session.lumipolX, obs.z - session.lumipolZ) > C.TOO_FAR_HORIZONTAL + EPSILON
			or math.abs(obs.y - session.startY) > C.TOO_FAR_VERTICAL + EPSILON
			or (clockOk and displacement / paced > C.JUMP_SPEED + EPSILON) then
			return finish(self, session, "TooFar", now)
		end
	end
	if session.struck then return finish(self, session, "Struck", now) end
	-- H1: while the seal is open only the clock matters; the ring and the meter are done.
	if session.stage == "Seal" then
		if not clockOk or not placed then return badSample(self, session, now) end
		session.badSamples = 0
		session.lastSample, session.lastX, session.lastZ = now, obs.x, obs.z
		if now > sealCloses(session) + EPSILON then return finish(self, session, "SealMissed", now) end
		return activeView(session)
	end
	-- A server hitch cannot end the session early, but repeated hitches cannot hold the Lumipol forever.
	if clockOk and placed and dt > C.STALL_AFTER + EPSILON then
		session.deadline = math.min(session.deadline + dt, session.hardDeadline)
	end
	if clockOk and now + EPSILON >= session.deadline then return finish(self, session, "TimedOut", now) end
	if not clockOk or not placed then return badSample(self, session, now) end

	session.badSamples = 0
	local elapsed = math.min(dt, C.MAX_ELAPSED)
	local cx, cz = CaptureSession.ringCenter(session.ring, now - session.startedAt)
	local inside = length(obs.x - cx, obs.z - cz) <= C.RING_RADIUS_SERVER + EPSILON
	local moving = displacement / paced > C.STILL_SPEED + EPSILON
		or windowedRate(session, now, displacement) > C.STILL_PATH_RATE + EPSILON
	session.lastSample, session.lastX, session.lastZ = now, obs.x, obs.z
	session.inside, session.moving = inside, moving
	if not inside then
		session.calm = math.max(0, session.calm - C.OUTSIDE_DRAIN * elapsed)
		session.outsideFor += elapsed
		if session.outsideFor + EPSILON >= C.OUTSIDE_LIMIT then return finish(self, session, "LeftRing", now) end
		return activeView(session)
	end
	session.outsideFor = 0
	if not moving then session.calm += elapsed end
	if session.calm + EPSILON >= C.CALM_REQUIRED then
		if obs.bagRoom ~= true then return finish(self, session, "BackpackFull", now) end
		if obs.collectionRoom ~= true then return finish(self, session, "CollectionFull", now) end
		openSeal(session, now)
	end
	return activeView(session)
end

-- H1: the owner pressed Seal. obs = { now, alive, life, bagRoom, collectionRoom }, all read by the server when the
-- request arrived; the client sends only the token. Returns false, "InvalidToken" for a wrong owner, a stale or a
-- malformed token, false, "NotReady" while calming or before the marker moves (no penalty), else true, ending.
function CaptureSession:seal(token, key, obs)
	local session = validId(token) and self.sessions[token]
	if not session or session.key ~= playerKey(key) then return false, "InvalidToken" end
	if session.stage ~= "Seal" or type(obs) ~= "table" or not finite(obs.now) then return false, "NotReady" end
	local now = obs.now
	local seal = session.seal
	if now < seal.startedAt then return false, "NotReady" end
	if obs.alive ~= true or obs.life ~= session.life then return true, finish(self, session, "Defeated", now) end
	if self.reservations[session.encounterId] ~= token then
		self.counters.anomaly += 1
		return true, finish(self, session, "Lost", now)
	end
	local reached = (now - seal.startedAt) / seal.sweep
	local left = (now - C.SEAL_LATENCY - seal.startedAt) / seal.sweep
	if reached + EPSILON < seal.lo or left > seal.hi + EPSILON then return true, finish(self, session, "SealMissed", now) end
	if obs.bagRoom ~= true then return true, finish(self, session, "BackpackFull", now) end
	if obs.collectionRoom ~= true then return true, finish(self, session, "CollectionFull", now) end
	return true, finish(self, session, "Completed", now)
end

-- A strike applies only to a session already running when it lands. Returns whether one was marked.
function CaptureSession:notifyStruck(key)
	local normalized = playerKey(key)
	local session = normalized and self.sessions[self.byPlayer[normalized] or ""]
	if not session then return false end
	session.struck = true
	return true
end

-- The only call that takes a client value. Wrong owner, stale and malformed all read the same.
function CaptureSession:cancel(token, key, now)
	local session = validId(token) and self.sessions[token]
	if not session or session.key ~= playerKey(key) then return false, "InvalidToken" end
	return true, finish(self, session, "Cancelled", now)
end

-- PlayerRemoving: no grant, no spook, no penalty. Hold-offs and failure counts stay, so leaving and
-- rejoining resets nothing; sweep forgets spent hold-offs and retire forgets a gone encounter's counts.
function CaptureSession:drop(key, now)
	local normalized = playerKey(key)
	if not normalized then return nil end
	local session = self.sessions[self.byPlayer[normalized] or ""]
	return session and finish(self, session, "Disconnected", now) or nil
end

-- The encounter left the world. Its id must never be reused, so all memory of it goes.
function CaptureSession:retire(encounterId, now)
	if not validId(encounterId) then return nil end
	local session = self.sessions[self.reservations[encounterId] or ""]
	local out = session and finish(self, session, "Lost", now) or nil
	self.encounters[encounterId] = nil
	for _, book in ipairs({ self.retries, self.failures }) do
		for key, perEncounter in pairs(book) do
			perEncounter[encounterId] = nil
			if next(perEncounter) == nil then book[key] = nil end
		end
	end
	return out
end

-- Run after the sampling pass. Frees anything nobody sampled past its deadline and forgets spent waits.
function CaptureSession:sweep(now)
	local ended = {}
	if not finite(now) then return ended end
	local overdue = {}
	for _, session in pairs(self.sessions) do
		if now >= session.deadline + C.WATCHDOG_GRACE then table.insert(overdue, session) end
	end
	table.sort(overdue, function(a, b) return a.serial < b.serial end)
	for _, session in ipairs(overdue) do
		self.counters.watchdog += 1
		table.insert(ended, finish(self, session, "Watchdog", now))
	end
	for id, record in pairs(self.encounters) do
		if not waiting(record.spookedUntil, now, C.SPOOK_SECONDS) then record.spookedUntil = nil end
		if not record.gone and not record.spookedUntil then self.encounters[id] = nil end
	end
	for key, playerRetries in pairs(self.retries) do
		for id, hold in pairs(playerRetries) do
			if not waiting(hold.untilAt, now, hold.span) then playerRetries[id] = nil end
		end
		if next(playerRetries) == nil then self.retries[key] = nil end
	end
	return ended
end

-- The sampling loop's list: { token, playerKey, encounterId } in start order.
function CaptureSession:activeSessions()
	local list = {}
	for _, session in pairs(self.sessions) do table.insert(list, session) end
	table.sort(list, function(a, b) return a.serial < b.serial end)
	for index, session in ipairs(list) do
		list[index] = { token = session.token, playerKey = session.playerKey, encounterId = session.encounterId }
	end
	return list
end

-- "Free" | "Reserved" | "Spooked" | "Captured", for the prompt and the Lumipol's behavior.
function CaptureSession:encounterState(encounterId, now)
	if not validId(encounterId) then return nil end
	local record = self.encounters[encounterId]
	if record and record.gone then return record.gone end
	if self.reservations[encounterId] then return "Reserved" end
	if record and waiting(record.spookedUntil, now, C.SPOOK_SECONDS) then return "Spooked" end
	return "Free"
end

-- The value for the owner's snapshot. Never names the player or the encounter. Detached copy.
-- Active: eight fields with the stage, plus the ring only from view(), since the ring never changes during a
-- session, and the seal once it is open. Ended: adds reason and retryAt; the server adds the notice's words.
function CaptureSession.toSnapshot(view)
	if type(view) ~= "table" or not PHASES[view.phase] then return nil end
	return { token = view.token, phase = view.phase, calm = view.calm, inside = view.inside,
		moving = view.moving, outsideFor = view.outsideFor, deadline = view.deadline, stage = view.stage,
		ring = view.ring and table.clone(view.ring) or nil, seal = view.seal and table.clone(view.seal) or nil,
		reason = view.reason, notice = view.notice, retryAt = view.retryAt }
end

return CaptureSession

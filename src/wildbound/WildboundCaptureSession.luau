-- Pure capture rule: one session per player, one owner per encounter, skill read from server positions.
-- Inputs are server-read values passed by value and the clock is injected. Clients supply nothing here
-- except an untrusted token on cancel. See docs/mechanics/wildbound-capture.md for states and wiring.
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
	SPOOK_SECONDS = 2,
	MAX_FAILS = 3,
})

-- Text is authoritative: a player should be able to repeat back why a capture ended.
CaptureSession.NOTICES = table.freeze({
	Completed = "Caught! Lumipol is in your bag. Extract at camp to keep it.",
	LeftRing = "You left the ring. Step back in when it drifts.",
	TimedOut = "Too restless. Stand still inside the ring.",
	TooFar = "You moved too far from the Lumipol.",
	Struck = "Silueta struck you. The Lumipol fled.",
	Defeated = "You were defeated. The Lumipol fled.",
	Cancelled = "You stopped. The Lumipol backed away.",
	Disconnected = "",
	Lost = "The Lumipol is gone.",
	LostTrack = "Lost track of you. The Lumipol is free again.",
	Watchdog = "The capture stopped. Try again.",
	BackpackFull = "Bag full. Return to camp to extract.",
	CollectionFull = "Session collection limit reached (100 items).",
	AlreadyCapturing = "Finish calming this Lumipol first.",
	InvalidContext = "Move closer while alive and try again.",
	InvalidEncounter = "This encounter is no longer available.",
	InvalidPlayer = "That action is not available.",
	AlreadyClaimed = "Someone collected this encounter.",
	Reserved = "Another player is calming this Lumipol.",
	RetryWait = "It is still wary. Try again in a few seconds.",
	FirstCaptureOnly = "This one is too shy now. Look for Lumipols in the fog.",
	FirstCapturePending = "Extract the Lumipol you are carrying first.",
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
		encounters = {}, -- encounter id -> { spookedUntil, fails, gone }
		retries = {}, -- normalized key -> { [encounter id] = retry moment }
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
--           encounterStatus = "Open" | "Claimed" | other, slotRefusal?, bagRoom, collectionRoom }
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
	if record and record.gone == "Left" then return false, "InvalidEncounter" end
	if self.reservations[encounterId] or (record and waiting(record.spookedUntil, now, C.SPOOK_SECONDS)) then
		return false, "Reserved"
	end
	local playerRetries = self.retries[key]
	if playerRetries and waiting(playerRetries[encounterId], now, C.RETRY_COOLDOWN) then
		return false, "RetryWait"
	end
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
		lastX = input.x, lastZ = input.z, calm = 0, outsideFor = 0, inside = true, moving = false,
		struck = false, badSamples = 0,
	}
	self.sessions[token] = session
	self.byPlayer[key] = token
	self.reservations[encounterId] = token
	return true, self:view(token)
end

local function activeView(session)
	return { token = session.token, phase = "Active", calm = session.calm, inside = session.inside,
		moving = session.moving, outsideFor = session.outsideFor, deadline = session.deadline }
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
		record = record or { fails = 0 }
		self.encounters[session.encounterId] = record
	end
	local leaves = false
	if reason == "Completed" then record.gone = "Captured" end
	if rule.spook then record.spookedUntil = at + C.SPOOK_SECONDS end
	if rule.fail then
		record.fails += 1
		if record.fails >= C.MAX_FAILS then
			record.gone, leaves = "Left", true
		end
	end
	local retryAt = rule.retry and at + C.RETRY_COOLDOWN or nil
	if retryAt then
		self.retries[session.key] = self.retries[session.key] or {}
		self.retries[session.key][session.encounterId] = retryAt
	end
	local out = activeView(session)
	out.phase, out.reason, out.notice = rule.phase, reason, CaptureSession.NOTICES[reason]
	out.grant, out.leaves, out.spook = reason == "Completed", leaves, rule.spook == true
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
		return finish(self, session, "Completed", now)
	end
	return activeView(session)
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

-- PlayerRemoving: no grant, no spook, no penalty, and the player's retry memory goes with them.
function CaptureSession:drop(key, now)
	local normalized = playerKey(key)
	if not normalized then return nil end
	self.retries[normalized] = nil
	local session = self.sessions[self.byPlayer[normalized] or ""]
	return session and finish(self, session, "Disconnected", now) or nil
end

-- The encounter left the world. Its id must never be reused, so all memory of it goes.
function CaptureSession:retire(encounterId, now)
	if not validId(encounterId) then return nil end
	local session = self.sessions[self.reservations[encounterId] or ""]
	local out = session and finish(self, session, "Lost", now) or nil
	self.encounters[encounterId] = nil
	for key, playerRetries in pairs(self.retries) do
		playerRetries[encounterId] = nil
		if next(playerRetries) == nil then self.retries[key] = nil end
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
		if not record.gone and record.fails == 0 and not record.spookedUntil then self.encounters[id] = nil end
	end
	for key, playerRetries in pairs(self.retries) do
		for id, retryAt in pairs(playerRetries) do
			if not waiting(retryAt, now, C.RETRY_COOLDOWN) then playerRetries[id] = nil end
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

-- "Free" | "Reserved" | "Spooked" | "Captured" | "Left", for the prompt and the Lumipol's behavior.
function CaptureSession:encounterState(encounterId, now)
	if not validId(encounterId) then return nil end
	local record = self.encounters[encounterId]
	if record and record.gone then return record.gone end
	if self.reservations[encounterId] then return "Reserved" end
	if record and waiting(record.spookedUntil, now, C.SPOOK_SECONDS) then return "Spooked" end
	return "Free"
end

-- The value for the owner's snapshot. Never names the player or the encounter. Detached copy.
-- Active: seven fields, plus the ring only from view(), since the ring never changes during a session.
-- Ended: adds reason, notice and retryAt.
function CaptureSession.toSnapshot(view)
	if type(view) ~= "table" or not PHASES[view.phase] then return nil end
	return { token = view.token, phase = view.phase, calm = view.calm, inside = view.inside,
		moving = view.moving, outsideFor = view.outsideFor, deadline = view.deadline,
		ring = view.ring and table.clone(view.ring) or nil, reason = view.reason, notice = view.notice,
		retryAt = view.retryAt }
end

return CaptureSession

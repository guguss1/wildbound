-- Saved-progress sessions (W10, M6.2): claim with a session lock, load guard, autosave, leave, close and the
-- write-first commit with its ledger. Design: docs/mechanics/wildbound-persistence.md sections 4 to 7.
-- It never names a data store: the caller injects a store port (update/read), the clock, waits and randomness.
-- This wave wires nothing: no live script requires this module, and only the in-memory fake has been used.
--
-- The failed-load guard is structural: only a claim that returned New or Loaded creates a session, and every
-- write path needs a session. Unavailable, LockedElsewhere, Quarantined and TooNew leave none, so nothing a
-- player does while playing unsaved can ever be written over the real record.
local HttpService = game:GetService("HttpService")

local Persistence = {}
Persistence.__index = Persistence

Persistence.LOCK_EXPIRY = 300 -- seconds since the store last updated the key
Persistence.AUTOSAVE = 60
Persistence.REFRESH_AFTER = 150 -- a clean profile still writes once its lock is this old
Persistence.MAX_ATTEMPTS = 3
Persistence.BACKOFF_BASE = 1
Persistence.BACKOFF_CAP = 8
Persistence.CLOSE_BUDGET = 25
Persistence.MAX_CHARS = 4194304

local RETRYABLE = table.freeze({ Error = true, Timeout = true, Throttled = true })
local REVOKING = table.freeze({ LockLost = true, Diverged = true, Missing = true })

function Persistence.new(options)
	assert(type(options) == "table", "Persistence.new needs options")
	local store = options.store
	assert(type(store) == "table" and type(store.update) == "function" and type(store.read) == "function",
		"Persistence.new needs a store port with update and read")
	assert(type(options.serverId) == "string" and #options.serverId > 0, "Persistence.new needs a server id")
	assert(type(options.record) == "table" and type(options.economy) == "table" and type(options.config) == "table",
		"Persistence.new needs the Record module, the Economy rules and the tuning")
	return setmetatable({
		store = store, serverId = options.serverId, Record = options.record,
		economy = options.economy, config = options.config, migrations = options.migrations,
		clock = options.clock or os.time, wait = options.wait or task.wait, random = options.random or math.random,
		spawn = options.spawn or task.spawn, onStatus = options.onStatus or function() end,
		encode = options.encode or function(value) return HttpService:JSONEncode(value) end,
		maxAttempts = options.maxAttempts or Persistence.MAX_ATTEMPTS,
		maxChars = options.maxChars or Persistence.MAX_CHARS,
		entries = {}, writeSeq = 0,
		counters = { quarantined = 0, lockLost = 0, diverged = 0, operationConflicts = 0, invalidWrites = 0 },
	}, Persistence)
end

local function backoff(self, attempt)
	return math.min(Persistence.BACKOFF_CAP, Persistence.BACKOFF_BASE * 2 ^ (attempt - 1)) + self.random()
end

local function setStatus(self, key, entry, status)
	if entry.saveStatus ~= status then
		entry.saveStatus = status
		self.onStatus(key, status)
	end
end

local function liveEntry(self, key)
	local entry = self.entries[key]
	if entry and entry.session and not entry.revoked then return entry end
	return nil
end

local function revoke(self, key, entry, verdict)
	entry.revoked = true
	entry.session = nil
	entry.busy = false
	if verdict == "LockLost" then self.counters.lockLost += 1 else self.counters.diverged += 1 end
	setStatus(self, key, entry, "Off")
end

-- Claim: read, migrate, validate and take the lock in one update. Retries store errors and a fresh foreign lock.
function Persistence:load(key, sessionNow)
	if liveEntry(self, key) then return "AlreadyLoaded", nil end
	local Record, lockId = self.Record, self.serverId
	local outcome, claimed = "Unavailable", nil
	for attempt = 1, self.maxAttempts do
		local verdict, value
		local ok = self.store:update(key, function(current, info)
			verdict, value = nil, nil
			if current == nil then
				verdict, value = "New", Record.blank()
				return value, { LockId = lockId }
			end
			local holder = info and info.metadata and info.metadata.LockId
			if holder ~= nil and holder ~= lockId then
				local age = info.updatedAt and (self.clock() - info.updatedAt) or 0
				if age < Persistence.LOCK_EXPIRY then verdict = "LockedElsewhere"; return nil end
			end
			local status, migrated = Record.migrate(current, self.migrations)
			if status == "TooNew" or status == "Quarantined" then verdict = status; return nil end
			if not Record.validate(migrated, self.economy, self.config) then verdict = "Quarantined"; return nil end
			verdict, value = "Loaded", migrated
			return migrated, { LockId = lockId }
		end)
		if ok then
			outcome = verdict
			if verdict == "New" or verdict == "Loaded" then claimed = value; break end
			if verdict ~= "LockedElsewhere" then break end
		else
			outcome = "Unavailable"
		end
		if attempt < self.maxAttempts then self.wait(backoff(self, attempt)) end
	end
	if claimed then
		local now = self.clock()
		self.entries[key] = {
			outcome = outcome, saveStatus = "Saved", dirty = false, busy = false, revoked = false,
			session = { lockId = lockId, record = claimed, nextUid = claimed.nextUid, nextOp = claimed.nextOp },
			lastWriteAt = now, nextAutosave = now + self.random() * Persistence.AUTOSAVE,
		}
		return outcome, Record.toProfile(claimed, self.economy, self.config, sessionNow)
	end
	if outcome == "Quarantined" then self.counters.quarantined += 1 end
	local entry = { outcome = outcome, saveStatus = nil, dirty = false, revoked = false }
	self.entries[key] = entry
	setStatus(self, key, entry, "Off")
	return outcome, nil
end

function Persistence:info(key)
	local entry = self.entries[key]
	if not entry then return nil end
	return { loaded = entry.session ~= nil and not entry.revoked, outcome = entry.outcome,
		saveStatus = entry.saveStatus, dirty = entry.dirty, revoked = entry.revoked == true }
end

function Persistence:markDirty(key)
	local entry = liveEntry(self, key)
	if entry then entry.dirty = true end
end

-- Durable item IDs come from the saved counter (B17). Never reused in this session, even if never written.
function Persistence:allocateUid(key)
	local entry = liveEntry(self, key)
	if not entry then return nil end
	local session = entry.session
	local uid = "u" .. session.nextUid
	session.nextUid += 1
	return uid
end

-- A write-first operation gets its ID and payload once, here; retries reuse both and never allocate.
function Persistence:newOp(key, kind, build)
	local entry = liveEntry(self, key)
	if not entry or type(kind) ~= "string" then return nil end
	local session = entry.session
	local id = kind .. ":" .. session.nextOp
	session.nextOp += 1
	local payload = table.freeze(build(function() return self:allocateUid(key) end) or {})
	return table.freeze({ id = id, kind = kind, payload = payload, digest = self.Record.digest(kind, payload) })
end

local function stamp(self, entry, record)
	local session = entry.session
	record.nextUid = math.max(record.nextUid, session.nextUid)
	record.nextOp = math.max(record.nextOp, session.nextOp)
	record.revision = session.record.revision + 1
	self.writeSeq += 1
	record.lastWriteId = session.lockId .. ":" .. self.writeSeq
end

local function fits(self, record)
	local ok, text = pcall(self.encode, record)
	return ok and type(text) == "string" and #text <= self.maxChars, ok
end

-- One guarded write. Our own landed write is recognised by lastWriteId, before the lock, so a lost reply to a
-- release is not mistaken for a lost lock.
local function writeOnce(self, key, entry, candidate, release)
	local session = entry.session
	local verdict
	local ok, failure = self.store:update(key, function(current, info)
		verdict = nil
		if current == nil then verdict = "Missing"; return nil end
		if current.lastWriteId == candidate.lastWriteId then verdict = "Saved"; return nil end
		local holder = info and info.metadata and info.metadata.LockId
		if holder ~= session.lockId then verdict = "LockLost"; return nil end
		if current.revision ~= session.record.revision then verdict = "Diverged"; return nil end
		verdict = "Saved"
		return candidate, release and {} or { LockId = session.lockId }
	end)
	if not ok then return failure end
	return verdict
end

-- Serializes the profile, validates it, checks the size, then writes. attempts and deadline bound the retries.
local function save(self, key, entry, profile, meta, release, attempts, deadline)
	local Record = self.Record
	meta = table.clone(meta or {})
	meta.nowUnix = meta.nowUnix or self.clock()
	local candidate = Record.fromProfile(profile, entry.session.record, meta, self.economy, self.config)
	if candidate then
		stamp(self, entry, candidate)
		if not Record.validate(candidate, self.economy, self.config) then candidate = nil end
	end
	if not candidate then
		self.counters.invalidWrites += 1
		setStatus(self, key, entry, "Paused")
		return "Invalid"
	end
	local fitsBudget, encoded = fits(self, candidate)
	if not fitsBudget then
		setStatus(self, key, entry, "Paused")
		return encoded and "TooLarge" or "Invalid"
	end
	entry.busy = true
	local wasDirty = entry.dirty
	entry.dirty = false
	local result
	local attempt = 0
	while true do
		attempt += 1
		result = writeOnce(self, key, entry, candidate, release)
		if not RETRYABLE[result] then break end
		if attempts and attempt >= attempts then break end
		local delay = backoff(self, attempt)
		if deadline then
			local remaining = deadline - self.clock()
			if remaining <= 0 then break end
			delay = math.min(delay, remaining)
		end
		self.wait(delay)
		if deadline and self.clock() >= deadline then
			attempt += 1
			result = writeOnce(self, key, entry, candidate, release)
			break
		end
	end
	entry.busy = false
	if result == "Saved" then
		entry.session.record = candidate
		entry.lastWriteAt = self.clock()
		setStatus(self, key, entry, "Saved")
		return "Saved"
	end
	entry.dirty = entry.dirty or wasDirty
	if REVOKING[result] then
		revoke(self, key, entry, result)
		return result
	end
	setStatus(self, key, entry, "Paused")
	return "Failed"
end

-- A bag change or other checkpoint: one attempt now; a failure leaves it to the next autosave.
function Persistence:checkpoint(key, profile, meta)
	local entry = liveEntry(self, key)
	if not entry then return "NotLoaded" end
	if entry.saveStatus == "Unknown" then return "Unknown" end
	if entry.busy then return "Busy" end
	return save(self, key, entry, profile, meta, false, 1)
end

-- provider(key) -> profile, meta. Due profiles write if dirty, or if the lock is getting old.
function Persistence:tick(provider)
	local now = self.clock()
	local saved = {}
	for key, entry in pairs(self.entries) do
		if entry.session and not entry.revoked and now >= entry.nextAutosave
			and not entry.busy and entry.saveStatus ~= "Unknown" then
			entry.nextAutosave += Persistence.AUTOSAVE
			if entry.nextAutosave <= now then entry.nextAutosave = now + Persistence.AUTOSAVE end
			if entry.dirty or now - entry.lastWriteAt >= Persistence.REFRESH_AFTER then
				local profile, meta = provider(key)
				if profile and save(self, key, entry, profile, meta, false, 1) == "Saved" then
					table.insert(saved, key)
				end
			end
		end
	end
	return saved
end

local function drain(self, entry)
	for _ = 1, 100 do
		if not entry.busy then return end
		self.wait(0.1)
	end
end

-- Leaving: one final write that releases the lock; the leave time is stamped only when something is at risk.
-- The player is gone from this server whatever the result; a failed release self-heals at the lock expiry.
function Persistence:release(key, profile, meta)
	local entry = liveEntry(self, key)
	if not entry then
		self.entries[key] = nil
		return "NotLoaded"
	end
	drain(self, entry)
	meta = table.clone(meta or {})
	meta.nowUnix = meta.nowUnix or self.clock()
	meta.leftAtUnix = meta.nowUnix
	local result = save(self, key, entry, profile, meta, true, self.maxAttempts)
	self.entries[key] = nil
	if result == "Saved" then return "Released" end
	if REVOKING[result] then return result end
	return "Failed"
end

-- BindToClose: every loaded player at once, one final write each within the budget. No leave time is stamped,
-- so a trip resumes whenever the player returns (choice 7).
function Persistence:closeAll(provider, budget)
	local deadline = self.clock() + (budget or Persistence.CLOSE_BUDGET)
	local report = { saved = 0, failed = {} }
	local keys = {}
	for key, entry in pairs(self.entries) do
		if entry.session and not entry.revoked then table.insert(keys, key) end
	end
	local pending = #keys
	for _, key in ipairs(keys) do
		local entry = self.entries[key]
		self.spawn(function()
			local profile, meta = provider(key)
			local result = profile and save(self, key, entry, profile, meta, true, nil, deadline) or "NoProfile"
			if result == "Saved" then report.saved += 1 else table.insert(report.failed, key) end
			self.entries[key] = nil
			pending -= 1
		end)
	end
	while pending > 0 and self.clock() < deadline do self.wait(0.1) end
	return report
end

local function adopt(self, key, entry, record, alreadyApplied)
	local session = entry.session
	session.record = record
	session.nextUid = math.max(session.nextUid, record.nextUid)
	session.nextOp = math.max(session.nextOp, record.nextOp)
	entry.unknownOpId = nil
	entry.busy = false
	entry.lastWriteAt = self.clock()
	setStatus(self, key, entry, "Saved")
	return "Committed", self.Record.copy(record), alreadyApplied
end

-- Write first: reduce(copy of the saved record, op) -> next record, pure and without yields. Memory and the
-- player's notice change only after "Committed". The caller then rebuilds its State profile from the record.
function Persistence:commit(key, op, reduce)
	local entry = liveEntry(self, key)
	if not entry then return "NotLoaded" end
	if type(op) ~= "table" or type(op.id) ~= "string" or type(op.digest) ~= "string" then return "InvalidOp" end
	if entry.saveStatus == "Unknown" and entry.unknownOpId ~= op.id then return "Unknown" end
	if entry.busy then return "Busy" end
	local Record, session = self.Record, entry.session
	local known = Record.findLedger(session.record, op.id)
	if known then
		if known.digest == op.digest then return "Committed", Record.copy(session.record), true end
		self.counters.operationConflicts += 1
		return "OperationConflict"
	end
	local nextRecord = reduce(Record.copy(session.record), op)
	if type(nextRecord) ~= "table" then return "Rejected" end
	Record.appendLedger(nextRecord, op)
	nextRecord.lastCommitId = op.id
	stamp(self, entry, nextRecord)
	if not Record.validate(nextRecord, self.economy, self.config) then
		self.counters.invalidWrites += 1
		return "Invalid"
	end
	local fitsBudget, encoded = fits(self, nextRecord)
	if not fitsBudget then return encoded and "TooLarge" or "Invalid" end

	entry.busy = true
	setStatus(self, key, entry, "Saving")
	for attempt = 1, self.maxAttempts do
		local verdict, adopted
		local ok = self.store:update(key, function(current, info)
			verdict, adopted = nil, nil
			if current == nil then verdict = "Missing"; return nil end
			local holder = info and info.metadata and info.metadata.LockId
			if holder ~= session.lockId then verdict = "LockLost"; return nil end
			local found = type(current.ledger) == "table" and Record.findLedger(current, op.id) or nil
			if found then
				if found.digest == op.digest then verdict, adopted = "AlreadyApplied", current
				else verdict = "OperationConflict" end
				return nil
			end
			if current.revision ~= session.record.revision then verdict = "Diverged"; return nil end
			verdict = "Committed"
			return nextRecord, { LockId = session.lockId }
		end)
		if ok then
			if verdict == "Committed" then return adopt(self, key, entry, nextRecord, false) end
			if verdict == "AlreadyApplied" then return adopt(self, key, entry, adopted, true) end
			entry.busy = false
			if verdict == "OperationConflict" then
				self.counters.operationConflicts += 1
				setStatus(self, key, entry, "Paused")
				return "OperationConflict"
			end
			revoke(self, key, entry, verdict)
			return verdict
		end
		if attempt < self.maxAttempts then self.wait(backoff(self, attempt)) end
	end

	-- Attempts ran out: read back without trusting the reply.
	local okRead, current, info = self.store:read(key)
	if not okRead then
		entry.busy = false
		entry.unknownOpId = op.id
		setStatus(self, key, entry, "Unknown")
		return "Unknown"
	end
	local found = type(current) == "table" and type(current.ledger) == "table" and Record.findLedger(current, op.id)
	if found and found.digest == op.digest then return adopt(self, key, entry, current, true) end
	entry.busy = false
	local holder = info and info.metadata and info.metadata.LockId
	if current ~= nil and holder ~= session.lockId then
		revoke(self, key, entry, "LockLost")
		return "LockLost"
	end
	entry.unknownOpId = nil
	setStatus(self, key, entry, "Paused")
	return "NotWritten"
end

return Persistence

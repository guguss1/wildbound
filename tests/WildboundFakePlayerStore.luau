-- In-memory test double for the persistence store port (W10, M6.2). It is never used by the live game.
-- Port: update(key, transform) -> true, value, info | false, errorKind; read(key) -> true, value, info | false,
-- errorKind. transform(current, info) returns the new value and its metadata, or nil to cancel. info holds
-- updatedAt (seconds on the injected clock) and metadata (a copy). Values are stored as JSON text, so reads are
-- byte exact and every value handed out is a detached copy. Deterministic: faults, latency and interleavings are
-- scripted, the clock is injected, and the transform runs twice per call as a defensive assumption
-- (docs/mechanics/wildbound-persistence.md section 5).
local HttpService = game:GetService("HttpService")

local Fake = {}
Fake.__index = Fake
Fake.MAX_CHARS = 4194304

-- Scripted fault -> the error kind the caller sees. commitThenThrow writes first, then reports "Error".
local FAULTS = table.freeze({ throwBefore = "Error", commitThenThrow = "Error", timeout = "Timeout", throttle = "Throttled" })

local function encode(value) return HttpService:JSONEncode(value) end
local function decode(bytes) return HttpService:JSONDecode(bytes) end
local function copyMeta(metadata)
	local out = {}
	for k, v in pairs(metadata or {}) do out[k] = v end
	return out
end

function Fake.new(options)
	options = options or {}
	assert(type(options.clock) == "function", "Fake.new needs an injected clock")
	return setmetatable({
		clock = options.clock, wait = options.wait or function() end,
		maxChars = options.maxChars or Fake.MAX_CHARS, writesPerMinute = options.writesPerMinute,
		entries = {}, updateSteps = {}, readSteps = {}, failing = nil, recent = {},
		writes = {}, calls = 0, transformRuns = 0,
	}, Fake)
end

function Fake:seed(key, value, metadata, updatedAt)
	self:seedRaw(key, encode(value), metadata, updatedAt)
end

function Fake:seedRaw(key, bytes, metadata, updatedAt)
	self.entries[key] = { bytes = bytes, metadata = copyMeta(metadata), updatedAt = updatedAt or self.clock() }
end

function Fake:raw(key)
	local entry = self.entries[key]
	return entry and entry.bytes or nil
end

function Fake:metadata(key)
	local entry = self.entries[key]
	return entry and copyMeta(entry.metadata) or nil
end

local function queue(list, steps)
	for _, step in ipairs(steps) do
		table.insert(list, type(step) == "string" and { fault = step } or step)
	end
end

-- Steps for the next update calls, in order: a fault name, or { fault, delay, before }.
function Fake:script(steps) queue(self.updateSteps, steps) end
-- Steps for the next read calls, kept apart so a read never uses an update's fault.
function Fake:scriptReads(steps) queue(self.readSteps, steps) end
-- Every call fails with this error kind until cleared with nil.
function Fake:failAll(kind) self.failing = kind end

local function begin(self, steps)
	self.calls += 1
	local step = table.remove(steps, 1) or {}
	if step.delay then self.wait(step.delay) end
	if step.before then step.before() end
	if self.failing then return step, self.failing end
	if step.fault and step.fault ~= "commitThenThrow" then return step, FAULTS[step.fault] or "Error" end
	return step, nil
end

local function budgetFull(self, now)
	if not self.writesPerMinute then return false end
	local kept = {}
	for _, at in ipairs(self.recent) do
		if now - at < 60 then table.insert(kept, at) end
	end
	self.recent = kept
	return #kept >= self.writesPerMinute
end

function Fake:update(key, transform)
	local step, failure = begin(self, self.updateSteps)
	if failure then return false, failure end
	local now = self.clock()
	if budgetFull(self, now) then return false, "Throttled" end
	local entry = self.entries[key]
	local updatedAt = entry and entry.updatedAt or nil
	local value, metadata
	for _ = 1, 2 do
		self.transformRuns += 1
		local current = entry and decode(entry.bytes) or nil
		value, metadata = transform(current, { updatedAt = updatedAt, metadata = copyMeta(entry and entry.metadata) })
	end
	if value == nil then
		return true, entry and decode(entry.bytes) or nil,
			{ updatedAt = updatedAt, metadata = copyMeta(entry and entry.metadata), cancelled = true }
	end
	local ok, bytes = pcall(encode, value)
	if not ok then return false, "Error" end
	if #bytes > self.maxChars then return false, "TooLarge" end
	if self.writesPerMinute then table.insert(self.recent, now) end
	self.entries[key] = { bytes = bytes, metadata = copyMeta(metadata), updatedAt = now }
	table.insert(self.writes, { key = key, bytes = bytes, metadata = copyMeta(metadata), at = now })
	if step.fault == "commitThenThrow" then return false, "Error" end
	return true, decode(bytes), { updatedAt = now, metadata = copyMeta(metadata) }
end

function Fake:read(key)
	local _, failure = begin(self, self.readSteps)
	if failure then return false, failure end
	local entry = self.entries[key]
	if not entry then return true, nil, nil end
	return true, decode(entry.bytes), { updatedAt = entry.updatedAt, metadata = copyMeta(entry.metadata) }
end

return Fake
